(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE Array1dRat;   (** AUTHOR "adf, fof"; PURPOSE "Basic operations on type ARRAY OF Rational"; *)

IMPORT SYSTEM, Array1dBytes, NbrRat, DataErrors, NbrInt, Array1dInt,NbrRe;

TYPE
	Value* = NbrRat.Rational;

	Array* = POINTER TO ARRAY OF Value;
	Index* = LONGINT;

CONST
	sz = SIZEOF( Value );

	(**
		defined operations (a,b: Array; i: Integer; arr: ARRAY OF Integer) :
		negate	-a;
		copy	a := arr , a := b^
		fill	a := i;
		plus:	a+b, a+i = i+a
		minus	a-b, a-i, i-a
		mult	a*b, a*i = i*a
		mod	a MOD i
		div	a DIV i
			*)
TYPE
	Map* = PROCEDURE {DELEGATE} ( VAR i: Value );


	(** fast access routines *)


	PROCEDURE Copy*( VAR x: ARRAY OF Value;  VAR res: ARRAY OF Value;  srcoffset, destoffset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( srcoffset, len, LEN( x ) );  Array1dBytes.RangeCheck( destoffset, len, LEN( res ) );

		Array1dBytes.MoveB( ADDRESSOF( x[srcoffset] ), ADDRESSOF( res[destoffset] ), len * sz );
	END Copy;

	PROCEDURE CreateCopy*( VAR x: ARRAY OF Value ): Array;
	VAR a: Array;
	BEGIN
		NEW( a, LEN( x ) );  Copy( x, a^, 0, 0, LEN( x ) );  RETURN a;
	END CreateCopy;

	PROCEDURE CopyPat*( VAR x: ARRAY OF Value;  VAR res: ARRAY OF Value;
									    srcoffset, srcstep, destoffset, deststep, piecelen, pieces: Index );
	BEGIN
		Array1dBytes.PatRangeCheck( srcoffset, srcstep, piecelen, pieces, LEN( x ) );
		Array1dBytes.PatRangeCheck( destoffset, deststep, piecelen, pieces, LEN( res ) );

		Array1dBytes.MoveBPat( ADDRESSOF( x[srcoffset] ), ADDRESSOF( res[destoffset] ), srcstep * sz, deststep * sz,
												 piecelen * sz, pieces );
	END CopyPat;

	PROCEDURE CreateCopyPat*( VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: Index ): Array;
	VAR a: Array;
	BEGIN
		(* range check done in copy pat *)

		NEW( a, piecelen * pieces );  CopyPat( x, a^, offset, step, 0, piecelen, piecelen, pieces );  RETURN a;
	END CreateCopyPat;

	PROCEDURE Fill*( x: Value;  VAR res: ARRAY OF Value;  offset, len: Index );
		(* fills in dyadic steps *)
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		Array1dBytes.Fill( ADDRESSOF( res[offset] ), x, len );
		(* implicitly selects the right version of Fill in  Array1dBytes  *)
	END Fill;

	PROCEDURE FillPat*( x: Value;  VAR res: ARRAY OF Value;  offset, step, piecelen, pieces: Index );
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( res ) );

		Array1dBytes.FillPat( ADDRESSOF( res[offset] ), x, step, piecelen, pieces );
		(* implicitly selects the right version of FillPat in  Array1dBytes  *)
	END FillPat;

(** monadic operations *)

	PROCEDURE Negate*( VAR x: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		INC( len, offset );
		WHILE (offset < len) DO x[offset] := -x[offset];  INC( offset ) END;
	END Negate;

	PROCEDURE NegatePat*( VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: Index );
	VAR idx: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( x ) );

		WHILE (pieces > 0) DO
			idx := offset;  INC( offset, piecelen );
			WHILE (idx < offset) DO x[idx] := -x[idx];  INC( idx ) END;
			INC( offset, step - piecelen );  DEC( pieces )
		END;
	END NegatePat;

	PROCEDURE Abs*( VAR x: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		INC( len, offset );
		WHILE (offset < len) DO x[offset] := NbrRat.Abs( x[offset] );  INC( offset ) END;
	END Abs;

	PROCEDURE AbsPat*( VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: Index );
	VAR idx: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( x ) );

		WHILE (pieces > 0) DO
			idx := offset;  INC( offset, piecelen );
			WHILE (idx < offset) DO x[idx] := NbrRat.Abs( x[idx] );  INC( idx ) END;
			INC( offset, step - piecelen );  DEC( pieces )
		END;
	END AbsPat;


(* Array Array operations *)

	PROCEDURE AddAA*( VAR x, y: ARRAY OF Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( y ) );
		Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x[offset] + y[offset];  INC( offset ) END;
	END AddAA;

	PROCEDURE SubtractAA*( VAR x, y: ARRAY OF Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( y ) );
		Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x[offset] - y[offset];  INC( offset ) END;
	END SubtractAA;

	PROCEDURE MultAA*( VAR x, y: ARRAY OF Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( y ) );
		Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x[offset] * y[offset];  INC( offset ) END;
	END MultAA;

	PROCEDURE ScalarProduct*( VAR x, y: ARRAY OF Value;  VAR res: Value;  xoffset, yoffset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( xoffset, len, LEN( x ) );  Array1dBytes.RangeCheck( yoffset, len, LEN( y ) );

		res := 0;  INC( len, xoffset );
		WHILE (xoffset < len) DO res := res + x[xoffset] * y[yoffset];  INC( xoffset );  INC( yoffset ) END;
	END ScalarProduct;

	PROCEDURE ScalarProductPat*( VAR x, y: ARRAY OF Value;  VAR res: Value;
													   xoffset, yoffset, xstep, ystep, piecelen, pieces: Index );
	VAR xidx, yidx: LONGINT;
	BEGIN
		Array1dBytes.PatRangeCheck( xoffset, xstep, piecelen, pieces, LEN( x ) );
		Array1dBytes.PatRangeCheck( yoffset, ystep, piecelen, pieces, LEN( y ) );

		res := 0;  xidx := xoffset;  yidx := yoffset;
		WHILE (pieces > 0) DO
			INC( xoffset, piecelen );  INC( yoffset, piecelen );
			WHILE (xidx < xoffset) DO res := res + x[xidx] * y[yidx];  INC( xidx );  INC( yidx );  END;
			INC( xoffset, xstep - piecelen );  INC( yoffset, ystep - piecelen );  DEC( pieces );
		END;
	END ScalarProductPat;

(*
	PROCEDURE ModAA*( VAR x, y: ARRAY OF Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	(** no checks for y[..] # 0, programmers responsibility *)
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( y ) );
		Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x[offset] MOD y[offset];  INC( offset ) END;
	END ModAA;
*)

	PROCEDURE DivAA*( VAR x, y: ARRAY OF Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	(** no checks for y[..] # 0, programmers responsibility *)
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( y ) );
		Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x[offset] / y[offset];  INC( offset ) END;
	END DivAA;

	PROCEDURE EqualsAA*( VAR x, y: ARRAY OF Value;  offset, len: Index ): BOOLEAN;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( y ) );

		INC( len, offset );
		WHILE (offset < len) DO
			IF x[offset] # y[offset] THEN RETURN FALSE END;
			INC( offset )
		END;
		RETURN TRUE;
	END EqualsAA;

(** Array - Value operations *)

	PROCEDURE AddAV*( VAR x: ARRAY OF Value;  y: Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x[offset] + y;  INC( offset ) END;
	END AddAV;

	PROCEDURE AddAVPat*( VAR x: ARRAY OF Value;  y: Value;  VAR res: ARRAY OF Value;
										   srcoffset, srcstep, destoffset, deststep, piecelen, pieces: Index );
	VAR si, di, end, endpiece: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( srcoffset, srcstep, piecelen, pieces, LEN( x ) );
		Array1dBytes.PatRangeCheck( destoffset, deststep, piecelen, pieces, LEN( res ) );

		si := srcoffset;  di := destoffset;  end := srcoffset + srcstep * pieces;  srcstep := srcstep - piecelen;
		deststep := deststep - piecelen;
		WHILE si < end DO
			endpiece := si + piecelen;
			WHILE si < endpiece DO res[di] := x[si] + y;  INC( si );  INC( di );  END;
			INC( si, srcstep );  INC( di, deststep );
		END;
	END AddAVPat;

	PROCEDURE SubtractAV*( VAR x: ARRAY OF Value;  y: Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x[offset] - y;  INC( offset ) END;
	END SubtractAV;

	PROCEDURE SubtractAVPat*( VAR x: ARRAY OF Value;  y: Value;  VAR res: ARRAY OF Value;
												  srcoffset, srcstep, destoffset, deststep, piecelen, pieces: Index );
	VAR si, di, end, endpiece: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( srcoffset, srcstep, piecelen, pieces, LEN( x ) );
		Array1dBytes.PatRangeCheck( destoffset, deststep, piecelen, pieces, LEN( res ) );

		si := srcoffset;  di := destoffset;  end := srcoffset + srcstep * pieces;  srcstep := srcstep - piecelen;
		deststep := deststep - piecelen;
		WHILE si < end DO
			endpiece := si + piecelen;
			WHILE si < endpiece DO res[di] := x[si] - y;  INC( si );  INC( di );  END;
			INC( si, srcstep );  INC( di, deststep );
		END;
	END SubtractAVPat;

	PROCEDURE SubtractVA*( VAR x: Value;  VAR y: ARRAY OF Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( y ) );  Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x - y[offset];  INC( offset ) END;
	END SubtractVA;

	PROCEDURE SubtractVAPat*( x: Value;  VAR y: ARRAY OF Value;  VAR res: ARRAY OF Value;
												  srcoffset, srcstep, destoffset, deststep, piecelen, pieces: Index );
	VAR si, di, end, endpiece: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( srcoffset, srcstep, piecelen, pieces, LEN( y ) );
		Array1dBytes.PatRangeCheck( destoffset, deststep, piecelen, pieces, LEN( res ) );

		si := srcoffset;  di := destoffset;  end := srcoffset + srcstep * pieces;  srcstep := srcstep - piecelen;
		deststep := deststep - piecelen;
		WHILE si < end DO
			endpiece := si + piecelen;
			WHILE si < endpiece DO res[di] := y[si] - x;  INC( si );  INC( di );  END;
			INC( si, srcstep );  INC( di, deststep );
		END;
	END SubtractVAPat;

	PROCEDURE MultAV*( VAR x: ARRAY OF Value;  y: Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x[offset] * y;  INC( offset ) END;
	END MultAV;

	PROCEDURE MultAVPat*( VAR x: ARRAY OF Value;  y: Value;  VAR res: ARRAY OF Value;
											 srcoffset, srcstep, destoffset, deststep, piecelen, pieces: Index );
	VAR si, di, end, endpiece: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( srcoffset, srcstep, piecelen, pieces, LEN( x ) );
		Array1dBytes.PatRangeCheck( destoffset, deststep, piecelen, pieces, LEN( res ) );

		si := srcoffset;  di := destoffset;  end := srcoffset + srcstep * pieces;  srcstep := srcstep - piecelen;
		deststep := deststep - piecelen;
		WHILE si < end DO
			endpiece := si + piecelen;
			WHILE si < endpiece DO res[di] := x[si] * y;  INC( si );  INC( di );  END;
			INC( si, srcstep );  INC( di, deststep );
		END;
	END MultAVPat;

	PROCEDURE DivAV*( VAR x: ARRAY OF Value;  y: Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x[offset] / y;  INC( offset ) END;
	END DivAV;

	PROCEDURE DivAVPat*( VAR x: ARRAY OF Value;  y: Value;  VAR res: ARRAY OF Value;
										  srcoffset, srcstep, destoffset, deststep, piecelen, pieces: Index );
	VAR si, di, end, endpiece: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( srcoffset, srcstep, piecelen, pieces, LEN( x ) );
		Array1dBytes.PatRangeCheck( destoffset, deststep, piecelen, pieces, LEN( res ) );

		si := srcoffset;  di := destoffset;  end := srcoffset + srcstep * pieces;  srcstep := srcstep - piecelen;
		deststep := deststep - piecelen;
		WHILE si < end DO
			endpiece := si + piecelen;
			WHILE si < endpiece DO res[di] := x[si] / y;  INC( si );  INC( di );  END;
			INC( si, srcstep );  INC( di, deststep );
		END;
	END DivAVPat;

	PROCEDURE DivVA*( x: Value;  VAR y: ARRAY OF Value;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( y ) );  Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO res[offset] := x / y[offset];  INC( offset ) END;
	END DivVA;

	PROCEDURE DivVAPat*( x: Value;  VAR y: ARRAY OF Value;  VAR res: ARRAY OF Value;
										  srcoffset, srcstep, destoffset, deststep, piecelen, pieces: Index );
	VAR si, di, end, endpiece: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( srcoffset, srcstep, piecelen, pieces, LEN( y ) );
		Array1dBytes.PatRangeCheck( destoffset, deststep, piecelen, pieces, LEN( res ) );

		si := srcoffset;  di := destoffset;  end := srcoffset + srcstep * pieces;  srcstep := srcstep - piecelen;
		deststep := deststep - piecelen;
		WHILE si < end DO
			endpiece := si + piecelen;
			WHILE si < endpiece DO res[di] := x / y[si];  INC( si );  INC( di );  END;
			INC( si, srcstep );  INC( di, deststep );
		END;
	END DivVAPat;

(** mappings *)

	PROCEDURE ApplyMap*( map: Map;  VAR res: ARRAY OF Value;  offset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( res ) );

		INC( len, offset );
		WHILE (offset < len) DO map( res[offset] );  INC( offset );  END;
	END ApplyMap;

	PROCEDURE ApplyMapPat*( map: Map;  VAR res: ARRAY OF Value;  offset, step, piecelen, pieces: Index );
	VAR i, end, endpiece: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( res ) );

		i := offset;  end := offset + step * pieces;  step := step - piecelen;
		WHILE i < end DO
			endpiece := i + piecelen;
			WHILE i < endpiece DO map( res[i] );  INC( i );  END;
			INC( i, step );
		END;
	END ApplyMapPat;

(** characteristics *)

	PROCEDURE Min*( VAR x: ARRAY OF Value;  offset, len: Index;  VAR minpos: Index ): Value;
	VAR min: Value;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		min := x[offset];  minpos := -1;  INC( len, offset );
		WHILE offset < len DO
			IF x[offset] < min THEN min := x[offset];  minpos := offset END;
			INC( offset )
		END;
		RETURN min;
	END Min;

	PROCEDURE Max*( VAR x: ARRAY OF Value;  offset, len: Index;  VAR maxpos: Index ): Value;
	VAR max: Value;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		max := x[offset];  maxpos := -1;  INC( len, offset );
		WHILE offset < len DO
			IF x[offset] > max THEN max := x[offset];  maxpos := offset END;
			INC( offset )
		END;
		RETURN max;
	END Max;

	PROCEDURE MinMax*( VAR x: ARRAY OF Value;  offset, len: Index;  VAR min, max: Value;  minpos, maxpos: Index );
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		max := x[offset];  maxpos := offset;  min := x[offset];  minpos := offset;  INC( len, offset );  INC( offset );
		WHILE offset < len DO
			IF x[offset] > max THEN max := x[offset];  maxpos := offset
			ELSIF x[offset] < min THEN min := x[offset];  minpos := offset
			END;
			INC( offset )
		END;
	END MinMax;

	PROCEDURE MinMaxPat*( map: Map;  VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: Index;  VAR min, max: Value;
											  minpos, maxpos: Index );
	VAR i, end, endpiece: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( x ) );

		i := offset;  end := offset + step * pieces;  step := step - piecelen;  max := x[offset];  maxpos := offset;  min := x[offset];
		minpos := offset;
		WHILE i < end DO
			endpiece := i + piecelen;
			WHILE i < endpiece DO
				IF x[i] > max THEN max := x[i];  maxpos := offset
				ELSIF x[i] < min THEN min := x[i];  minpos := offset
				END;
				INC( i );
			END;
			INC( i, step );
		END;
	END MinMaxPat;

	PROCEDURE MeanSsq*( VAR x: ARRAY OF Value;  offset, len: Index;  VAR mean, ssq: Value );
	(* mean and ssq distance of mean by provisional means algorithm *)
	VAR d: Value;  val: Value;  i: Index;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		mean := 0;  ssq := 0;  i := offset;  INC( len, offset );
		WHILE i < len DO val := x[i];  d := val - mean;  mean := mean + d / (i + 1 - offset);  ssq := ssq + d * (val - mean);  INC( i ) END
	END MeanSsq;

	PROCEDURE kSmallestModify*( k: Index;  VAR a: ARRAY OF Value;  len: LONGINT ): Value;
	(* algorithm of Nikolaus Wirth, array is modified ! *)
	VAR i, j, l, m: Index;  x: Value;

		PROCEDURE swap( VAR x, y: Value );
		VAR z: Value;
		BEGIN
			z := x;  x := y;  y := z
		END swap;

	BEGIN
		Array1dBytes.RangeCheck( 0, len, LEN( a ) );

		l := 0;  m := len - 1;
		WHILE (l < m) DO
			x := a[k];  i := l;  j := m;
			REPEAT
				WHILE (a[i] < x) DO INC( i ) END;
				WHILE (x < a[j]) DO DEC( j ) END;
				IF i <= j THEN swap( a[i], a[j] );  INC( i );  DEC( j ) END
			UNTIL i > j;
			IF j < k THEN l := i END;
			IF k < i THEN m := j END
		END;
		RETURN a[k]
	END kSmallestModify;

	PROCEDURE kSmallest*( k: Index;  VAR a: ARRAY OF Value;  len: LONGINT ): Value;
	(** avoids modification by creatning a copy of a, not for frequent use *)
	VAR copy: Array;
	BEGIN
		Array1dBytes.RangeCheck( 0, len, LEN( a ) );

		NEW( copy, len );  Copy( a, copy^, 0, 0, len );  RETURN kSmallestModify( k, copy^, len );
	END kSmallest;

	PROCEDURE Median*( VAR a: ARRAY OF Value;  len: LONGINT ): Value;
	BEGIN
		RETURN kSmallest( len DIV 2, a, len );
	END Median;

(** norms and distances*)

	PROCEDURE HammingWeight*( VAR x: ARRAY OF Value;  offset, len: Index ): Index;
	VAR res: Index;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		INC( len, offset );  res := 0;
		WHILE offset < len DO
			IF x[offset] # 0 THEN INC( res ) END;
			INC( offset );
		END;
		RETURN res;
	END HammingWeight;

	PROCEDURE HammingWeightPat*( VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: Index ): Index;
	VAR i, end, endpiece: Index;  res: Index;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( x ) );

		i := offset;  end := offset + step * pieces;  step := step - piecelen;  res := 0;
		WHILE i < end DO
			endpiece := i + piecelen;
			WHILE i < endpiece DO
				IF x[i] # 0 THEN INC( res ) END;
				INC( i );
			END;
			INC( i, step );
		END;
		RETURN res;

	END HammingWeightPat;

	PROCEDURE HammingDist*( VAR x, y: ARRAY OF Value;  xoffset, yoffset, len: Index ): Index;
	VAR res: Index;
	BEGIN
		Array1dBytes.RangeCheck( xoffset, len, LEN( x ) );  Array1dBytes.RangeCheck( yoffset, len, LEN( y ) );

		INC( len, xoffset );  res := 0;
		WHILE xoffset < len DO
			IF x[xoffset] # y[yoffset] THEN INC( res ) END;
			INC( xoffset );  INC( yoffset );
		END;
		RETURN res;
	END HammingDist;

	PROCEDURE L1Norm*( VAR x: ARRAY OF Value;  offset, len: Index ): Value;
	(** caution: routine does not check overflows *)
	VAR res: Value;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		INC( len, offset );  res := 0;
		WHILE offset < len DO res := res + NbrRat.Abs( x[offset] );  INC( offset );  END;
		RETURN res;
	END L1Norm;

	PROCEDURE L1NormPat*( map: Map;  VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: Index ): Value;
	VAR i, end, endpiece: Index;  res: Value;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( x ) );

		i := offset;  end := offset + step * pieces;  step := step - piecelen;  res := 0;
		WHILE i < end DO
			endpiece := i + piecelen;
			WHILE i < endpiece DO res := res + NbrRat.Abs( x[i] );  INC( i );  END;
			INC( i, step );
		END;
		RETURN res;

	END L1NormPat;

	PROCEDURE L1Dist*( VAR x, y: ARRAY OF Value;  xoffset, yoffset, len: Index ): Value;
	VAR res: Value;
	BEGIN
		Array1dBytes.RangeCheck( xoffset, len, LEN( x ) );  Array1dBytes.RangeCheck( yoffset, len, LEN( y ) );

		INC( len, xoffset );  res := 0;
		WHILE xoffset < len DO res := res + NbrRat.Abs( x[xoffset] - y[yoffset] );  INC( xoffset );  INC( yoffset );  END;
		RETURN res;
	END L1Dist;



	PROCEDURE L2NormSq*( VAR x: ARRAY OF Value;  offset, len: Index ): NbrRe.Real;
	(** caution: routine does not check overflow *)
	VAR res: NbrRe.Real;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		INC( len, offset );  res := 0;
		WHILE offset < len DO res := res + x[offset] * x[offset];  INC( offset );  END;
		RETURN res;
	END L2NormSq;

	PROCEDURE L2Norm*( VAR x: ARRAY OF Value;  offset, len: Index ): NbrRe.Real;
	BEGIN
		RETURN NbrRe.Sqrt( L2NormSq( x, offset, len ) );
	END L2Norm;

	PROCEDURE L2NormPatSq*( VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: Index ): NbrRe.Real;
	VAR i, end, endpiece: Index;  res: NbrRe.Real;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( x ) );

		i := offset;  end := offset + step * pieces;  step := step - piecelen;  res := 0;
		WHILE i < end DO
			endpiece := i + piecelen;
			WHILE i < endpiece DO res := res + (x[i] * x[i]);  INC( i );  END;
			INC( i, step );
		END;
		RETURN res;
	END L2NormPatSq;

	PROCEDURE L2NormPat*( VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: Index ): NbrRe.Real;
	BEGIN
		RETURN NbrRe.Sqrt( L2NormPatSq( x, offset, step, piecelen, pieces ) );
	END L2NormPat;

	PROCEDURE L2DistSq*( VAR x, y: ARRAY OF Value;  xoffset, yoffset, len: Index ): NbrRe.Real;
	VAR res: NbrRe.Real;  mult: Value;
	BEGIN
		Array1dBytes.RangeCheck( xoffset, len, LEN( x ) );  Array1dBytes.RangeCheck( yoffset, len, LEN( y ) );

		INC( len, xoffset );  res := 0;
		WHILE xoffset < len DO mult := x[xoffset] - y[yoffset];  res := res + mult * mult;  INC( xoffset );  INC( yoffset );  END;
		RETURN res;
	END L2DistSq;

	PROCEDURE L2Dist*( VAR x, y: ARRAY OF Value;  xoffset, yoffset, len: Index ): NbrRe.Real;
	BEGIN
		RETURN NbrRe.Sqrt( L2DistSq( x, y, xoffset, yoffset, len ) );
	END L2Dist;


	PROCEDURE LInftyNorm*( VAR x: ARRAY OF Value;  offset, len: Index ): Value;
	(** caution: routine does not check overflow *)
	VAR res, val: Value;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		INC( len, offset );  res := 0;
		WHILE offset < len DO
			val := NbrRat.Abs( x[offset] );
			IF val > res THEN res := val END;
			INC( offset );
		END;
		RETURN res;
	END LInftyNorm;

	PROCEDURE LInftyNormPat*( VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: Index ): Value;
	VAR i, end, endpiece: Index;  res, val: Value;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( x ) );

		i := offset;  end := offset + step * pieces;  step := step - piecelen;  res := 0;
		WHILE i < end DO
			endpiece := i + piecelen;
			WHILE i < endpiece DO
				val := NbrRat.Abs( x[i] );
				IF val > res THEN res := val END;
				INC( i );
			END;
			INC( i, step );
		END;
		RETURN res;

	END LInftyNormPat;

	PROCEDURE LInftyDist*( VAR x, y: ARRAY OF Value;  xoffset, yoffset, len: Index ): Value;
	VAR res, val: Value;
	BEGIN
		Array1dBytes.RangeCheck( xoffset, len, LEN( x ) );  Array1dBytes.RangeCheck( yoffset, len, LEN( y ) );

		INC( len, xoffset );  res := 0;
		WHILE xoffset < len DO
			val := NbrRat.Abs( x[xoffset] - y[yoffset] );
			IF val > res THEN res := val END;
			INC( xoffset );  INC( yoffset );
		END;
		RETURN res;
	END LInftyDist;

	PROCEDURE MinIndex( x, y: Index ): Index;
	BEGIN
		IF x < y THEN RETURN x ELSE RETURN y END;
	END MinIndex;

	PROCEDURE SetLen*( VAR a: Array;  len: Index );
	(** extend: append zeros, shrink: simple cut *)
	VAR res: Array;
	BEGIN
		NEW( res, len );  Copy( a^, res^, 0, 0, MinIndex( LEN( a ), len ) );
	END SetLen;

(** index operations *)
	PROCEDURE RemoveBlock*( VAR x: ARRAY OF Value;  offset, len: Index );
	(* remove block [offset,offset+len), fill rest with 0  *)
	VAR restlen: Index;  null: Value;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		null := 0;  restlen := LEN( x ) - offset - len;  Copy( x, x, offset + len, offset, restlen );  Fill( null, x, offset + len, restlen )
	END RemoveBlock;

	PROCEDURE InsertBlock*( VAR x: ARRAY OF Value;  offset, len: Index );
	(* insert (empty) block [offset,offset+len), content formerly in [offset,offset+len) is shifted upwards !*)
	VAR restlen: Index;  null: Value;
	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );

		null := 0;  restlen := LEN( x ) - offset - len;  Copy( x, x, offset, offset + len, restlen );  Fill( null, x, offset, len );
	END InsertBlock;

	PROCEDURE ShiftBlock*( VAR x: ARRAY OF Value;  from, to, len: Index );
	(** memory allocation by far not optimized, not intended for very frequent use*)
	VAR temp: Array;
	BEGIN
		Array1dBytes.RangeCheck( from, len, LEN( x ) );  Array1dBytes.RangeCheck( to, len, LEN( x ) );

		NEW( temp, len );  Copy( x, temp^, from, 0, len );  RemoveBlock( x, from, len );  InsertBlock( x, to, len );
		Copy( temp^, x, 0, to, len );
	END ShiftBlock;

	PROCEDURE RemovePat*( VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: LONGINT ): Array;
	(* for example: remove row or col from matrix *)
	VAR srcidx, destidx: LONGINT;  res: Array;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( x ) );

		NEW( res, LEN( x ) - pieces * piecelen );  srcidx := 0;  destidx := 0;
		WHILE (srcidx < offset) DO res[destidx] := x[srcidx];  INC( srcidx );  INC( destidx );  END;
		WHILE (pieces) > 0 DO
			INC( offset, piecelen );
			WHILE (srcidx < offset) DO INC( srcidx );  END;
			INC( offset, step - piecelen );
			IF (offset > LEN( x )) THEN offset := LEN( x ) END;
			WHILE (srcidx < offset) DO res[destidx] := x[srcidx];  INC( srcidx );  INC( destidx );  END;
			DEC( pieces );
		END;
		offset := LEN( x );
		WHILE (srcidx < offset) DO res[destidx] := x[srcidx];  INC( srcidx );  INC( destidx );  END;
		ASSERT ( destidx = LEN( res ) );
		RETURN res;
	END RemovePat;

	PROCEDURE Remove*( VAR x: ARRAY OF Value;  offset, len: LONGINT ): Array;   (* optimize if necessary *)
	BEGIN
		RETURN RemovePat( x, offset, len, len, 1 );
	END Remove;

	PROCEDURE InsertPat*( VAR x: ARRAY OF Value;  offset, step, piecelen, pieces: LONGINT ): Array;
	(* for example: insert row or col in matrix *)

	VAR srcidx, destidx: LONGINT;  res: Array;  null: Value;
	BEGIN
		Array1dBytes.PatRangeCheck( offset, step, piecelen, pieces, LEN( x ) + pieces * piecelen );

		null := 0;  NEW( res, LEN( x ) + pieces * piecelen );  srcidx := 0;  destidx := 0;
		WHILE (srcidx < offset) DO res[destidx] := x[srcidx];  INC( srcidx );  INC( destidx );  END;
		WHILE (pieces) > 0 DO
			INC( offset, piecelen );
			WHILE (destidx < offset) DO res[destidx] := null;  INC( destidx );  END;
			INC( offset, step - piecelen );
			WHILE ((destidx < offset) & (srcidx < LEN( x ))) DO res[destidx] := x[srcidx];  INC( srcidx );  INC( destidx );  END;
			DEC( pieces );
		END;
		offset := LEN( x );
		WHILE (srcidx < offset) DO res[destidx] := x[srcidx];  INC( srcidx );  INC( destidx );  END;
		ASSERT ( destidx = LEN( res ) );
		RETURN res;
	END InsertPat;

	PROCEDURE Insert*( VAR x: ARRAY OF Value;  offset, len: LONGINT ): Array;   (* optimize if necessary *)
	BEGIN
		RETURN InsertPat( x, offset, len, len, 1 );
	END Insert;

	PROCEDURE GetPieces*( VAR a: ARRAY OF Value;  offset, step, piecelen: LONGINT ): LONGINT;
	BEGIN
		IF (LEN( a ) - offset) MOD step >= piecelen THEN RETURN (LEN( a ) - offset) DIV step + 1 ELSE RETURN (LEN( a ) - offset) DIV step END;
	END GetPieces;

(** sorting *)
	PROCEDURE Sort*( VAR x: ARRAY OF Value;  offset, len: Index );

		PROCEDURE ThreeSort( l, c, r: Index );
		VAR sort: Value;
		BEGIN
			IF x[l] > x[c] THEN sort := x[l];  x[l] := x[c];  x[c] := sort END;
			IF x[l] > x[r] THEN sort := x[l];  x[l] := x[r];  x[r] := sort END;
			IF x[c] > x[r] THEN sort := x[c];  x[c] := x[r];  x[r] := sort END
		END ThreeSort;

		PROCEDURE InsertionSort( l, r: Index );
		VAR i, j: Index;  sort: Value;
		BEGIN
			FOR i := l + 1 TO r DO
				sort := x[i];  j := i;
				WHILE (j > 0) & (x[j - 1] > sort) DO x[j] := x[j - 1];  DEC( j ) END;
				x[j] := sort
			END
		END InsertionSort;

		PROCEDURE QuickSort( l, r: Index );
		CONST short = 7;   (* Short vectors sort faster with insertion. *)
		VAR c, i, j: Index;  sort, temp: Value;
		BEGIN
			IF r - l > short THEN  (* quick sort *)
				c := (l + r) DIV 2;  ThreeSort( l, c, r );  sort := x[r];  i := l - 1;  j := r;
				REPEAT
					REPEAT INC( i ) UNTIL x[i] >= sort;
					REPEAT DEC( j ) UNTIL x[j] <= sort;
					temp := x[i];  x[i] := x[j];  x[j] := temp
				UNTIL j < i;
				x[j] := x[i];  x[i] := x[r];  x[r] := temp;  QuickSort( l, j );  QuickSort( i + 1, r )
			ELSIF r > l THEN InsertionSort( l, r )
			ELSE  (* Nothing to sort. *)
			END
		END QuickSort;

	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );
		IF len <= 1 THEN RETURN END;
		QuickSort( offset, offset + len - 1 );
	END Sort;

	PROCEDURE SortWithIndex*( VAR x: ARRAY OF Value;  VAR index: ARRAY OF Index;  offset, len: Index );

		PROCEDURE ThreeSort( l, c, r: Index );
		VAR sort: Value;  ind: Index;
		BEGIN
			IF x[l] > x[c] THEN sort := x[l];  x[l] := x[c];  x[c] := sort;  ind := index[l];  index[l] := index[c];  index[c] := ind;  END;
			IF x[l] > x[r] THEN sort := x[l];  x[l] := x[r];  x[r] := sort;  ind := index[l];  index[l] := index[r];  index[r] := ind;  END;
			IF x[c] > x[r] THEN sort := x[c];  x[c] := x[r];  x[r] := sort;  ind := index[c];  index[c] := index[r];  index[r] := ind;  END
		END ThreeSort;

		PROCEDURE InsertionSort( l, r: Index );
		VAR i, j: Index;  sort: Value;  ind: Index;
		BEGIN
			FOR i := l + 1 TO r DO
				sort := x[i];  ind := index[i];  j := i;
				WHILE (j > 0) & (x[j - 1] > sort) DO x[j] := x[j - 1];  index[j] := index[j - 1];  DEC( j ) END;
				x[j] := sort;  index[j] := ind;
			END
		END InsertionSort;

		PROCEDURE QuickSort( l, r: Index );
		CONST short = 7;   (* Short vectors sort faster with insertion. *)
		VAR c, i, j: Index;  sort, temp: Value;  ind: Index;
		BEGIN
			IF r - l > short THEN  (* quick sort *)
				c := (l + r) DIV 2;  ThreeSort( l, c, r );  sort := x[r];  ind := index[r];  i := l - 1;  j := r;
				REPEAT
					REPEAT INC( i ) UNTIL x[i] >= sort;
					REPEAT DEC( j ) UNTIL x[j] <= sort;
					temp := x[i];  x[i] := x[j];  x[j] := temp;  ind := index[i];  index[i] := index[j];  index[j] := ind;

				UNTIL j < i;
				x[j] := x[i];  x[i] := x[r];  x[r] := temp;  index[j] := index[i];  index[i] := index[r];  index[r] := ind;  QuickSort( l, j );
				QuickSort( i + 1, r )
			ELSIF r > l THEN InsertionSort( l, r )
			ELSE  (* Nothing to sort. *)
			END
		END QuickSort;

	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( index ) );
		IF len <= 1 THEN RETURN END;
		QuickSort( offset, offset + len - 1 );
	END SortWithIndex;

	PROCEDURE SortByIndex*( VAR x: ARRAY OF Value;  VAR index: ARRAY OF Index;  offset, len: Index );

		PROCEDURE ThreeSort( l, c, r: Index );
		VAR sort: Value;  ind: Index;
		BEGIN
			IF index[l] > index[c] THEN
				sort := x[l];  x[l] := x[c];  x[c] := sort;  ind := index[l];  index[l] := index[c];  index[c] := ind;
			END;
			IF index[l] > index[r] THEN sort := x[l];  x[l] := x[r];  x[r] := sort;  ind := index[l];  index[l] := index[r];  index[r] := ind;  END;
			IF index[c] > index[r] THEN
				sort := x[c];  x[c] := x[r];  x[r] := sort;  ind := index[c];  index[c] := index[r];  index[r] := ind;
			END
		END ThreeSort;

		PROCEDURE InsertionSort( l, r: Index );
		VAR i, j: Index;  sort: Value;  ind: Index;
		BEGIN
			FOR i := l + 1 TO r DO
				sort := x[i];  ind := index[i];  j := i;
				WHILE (j > 0) & (index[j - 1] > ind) DO x[j] := x[j - 1];  index[j] := index[j - 1];  DEC( j ) END;
				x[j] := sort;  index[j] := ind;
			END
		END InsertionSort;

		PROCEDURE QuickSort( l, r: Index );
		CONST short = 7;   (* Short vectors sort faster with insertion. *)
		VAR c, i, j, ind: Index;  sort, temp: Value;
		BEGIN
			IF r - l > short THEN  (* quick sort *)
				c := (l + r) DIV 2;  ThreeSort( l, c, r );  sort := x[r];  ind := index[r];  i := l - 1;  j := r;
				REPEAT
					REPEAT INC( i ) UNTIL index[i] >= ind;
					REPEAT DEC( j ) UNTIL index[j] <= ind;
					temp := x[i];  x[i] := x[j];  x[j] := temp;  ind := index[i];  index[i] := index[j];  index[j] := ind;

				UNTIL j < i;
				x[j] := x[i];  x[i] := x[r];  x[r] := temp;  index[j] := index[i];  index[i] := index[r];  index[r] := ind;  QuickSort( l, j );
				QuickSort( i + 1, r )
			ELSIF r > l THEN InsertionSort( l, r )
			ELSE  (* Nothing to sort. *)
			END
		END QuickSort;

	BEGIN
		Array1dBytes.RangeCheck( offset, len, LEN( x ) );  Array1dBytes.RangeCheck( offset, len, LEN( index ) );

		IF len <= 1 THEN RETURN
		END;
		QuickSort( offset, offset + len - 1 );
	END SortByIndex;


	(** Overloaded operators for type:  Array. *)
(** Monadic Operator -  does not overwrite the argument *)
	PROCEDURE "-"*( x: Array ): Array;
	VAR minus: Array;
	BEGIN
		IF x # NIL THEN minus := CreateCopy( x^ );  Negate( minus^, 0, LEN( minus ) );  ELSE DataErrors.Error( "The supplied vector was NIL." ) END;
		RETURN minus
	END "-";


(** Dyadic Operators *)

	PROCEDURE ":="*( VAR l: Array;  VAR r: ARRAY OF Value );
	BEGIN
		IF l = NIL THEN NEW( l, LEN( r ) )
		ELSIF LEN( l ) # LEN( r ) THEN NEW( l, LEN( r ) )
		ELSE  (* vector l is properly dimensioned *)
		END;
		Copy( l^, r, 0, 0, LEN( r ) );
	END ":=";

	PROCEDURE ":="*( VAR l: Array;  r: Array1dInt.Array );
	VAR i: Index;
	BEGIN
		IF r # NIL THEN
			IF l = NIL THEN NEW( l, LEN( r ) )
			ELSIF LEN( l ) # LEN( r ) THEN NEW( l, LEN( r ) )
			ELSE  (* vector l is properly dimensioned *)
			END;
			FOR i := 0 TO LEN( r ) - 1 DO l[i] := r[i] END
		ELSE DataErrors.Error( "The supplied instance of Array1dInt.Array was NIL." )
		END
	END ":=";

	PROCEDURE ":="*( VAR l: Array;  VAR r: ARRAY OF NbrInt.Integer );
	VAR i: Index;
	BEGIN
		IF l = NIL THEN NEW( l, LEN( r ) )
		ELSIF LEN( l ) # LEN( r ) THEN NEW( l, LEN( r ) )
		ELSE  (* vector l is properly dimensioned *)
		END;
		FOR i := 0 TO LEN( r ) - 1 DO l[i] := r[i] END
	END ":=";

	PROCEDURE "="*( l: Array;  VAR r: ARRAY OF Value ): BOOLEAN;
	BEGIN
		IF (l # NIL ) & (LEN( l ) = LEN( r )) THEN RETURN EqualsAA( l^, r, 0, LEN( l ) );  ELSE DataErrors.Error( "The lengths of the two supplied Array vectors were not equal." );  END;
		RETURN FALSE;
	END "=";

	PROCEDURE "="*( VAR l: ARRAY OF Value;  r: Array ): BOOLEAN;
	BEGIN
		IF (r # NIL ) & (LEN( l ) = LEN( r )) THEN RETURN EqualsAA( r^, l, 0, LEN( r ) );  ELSE DataErrors.Error( "The lengths of the two supplied Array vectors were not equal." );  END;
		RETURN FALSE;
	END "=";


(* filling *)
	PROCEDURE ":="*( VAR l: Array;  r: Value );
	BEGIN
		IF l = NIL THEN RETURN END;
		Fill( r, l^, 0, LEN( l ) );
	END ":=";

(** Arithmetic. Operators do not overwrite the arguments. *)
	PROCEDURE "+"*( l, r: Array ): Array;
	VAR len: Index;  sum: Array;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r ) THEN len := LEN( l );  NEW( sum, len );  AddAA( l^, r^, sum^, 0, len );  ELSE DataErrors.Error( "The lengths of the two supplied Array vectors were not equal." ) END
		ELSE DataErrors.Error( "One or both of the two supplied Array vectors was NIL." )
		END;
		RETURN sum
	END "+";

	PROCEDURE "+"*( l: Array;  r: Value ): Array;
	VAR sum: Array;
	BEGIN
		IF (l # NIL ) THEN NEW( sum, LEN( l ) );  AddAV( l^, r, sum^, 0, LEN( l ) );  ELSE DataErrors.Error( "Supplied Array was NIL" );  END;
		RETURN sum
	END "+";

	PROCEDURE "+"*( r: Value;  l: Array ): Array;
	VAR sum: Array;
	BEGIN
		IF (l # NIL ) THEN NEW( sum, LEN( l ) );  AddAV( l^, r, sum^, 0, LEN( l ) );  ELSE DataErrors.Error( "Supplied Array was NIL" );  END;
		RETURN sum
	END "+";

	PROCEDURE "+"*( l: Array;  r: Array1dInt.Array ): Array;
	VAR i, len: NbrInt.Integer;  sum: Array;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r ) THEN
				len := LEN( l );  NEW( sum, len );
				FOR i := 0 TO len - 1 DO sum[i] := l[i] + r[i] END
			ELSE DataErrors.Error( "The lengths of the two supplied mixed-type vectors were not equal." )
			END
		ELSE DataErrors.Error( "One or both of the two supplied mixed-type vectors was NIL." )
		END;
		RETURN sum
	END "+";

	PROCEDURE "+"*( l: Array1dInt.Array;  r: Array ): Array;
	VAR i, len: NbrInt.Integer;  sum: Array;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r ) THEN
				len := LEN( l );  NEW( sum, len );
				FOR i := 0 TO len - 1 DO sum[i] := l[i] + r[i] END
			ELSE DataErrors.Error( "The lengths of the two supplied mixed-type vectors were not equal." )
			END
		ELSE DataErrors.Error( "One or both of the two supplied mixed-type vectors was NIL." )
		END;
		RETURN sum
	END "+";

	PROCEDURE "-"*( l: Array;  r: Value ): Array;
	VAR sum: Array;
	BEGIN
		IF (l # NIL ) THEN NEW( sum, LEN( l ) );  SubtractAV( l^, r, sum^, 0, LEN( l ) );  ELSE DataErrors.Error( "Supplied Array was NIL" );  END;
		RETURN sum
	END "-";

	PROCEDURE "-"*( l: Value;  r: Array ): Array;
	VAR sum: Array;
	BEGIN
		IF (r # NIL ) THEN NEW( sum, LEN( r ) );  SubtractVA( l, r^, sum^, 0, LEN( r ) );  ELSE DataErrors.Error( "Supplied Array was NIL" );  END;
		RETURN sum
	END "-";

	PROCEDURE "-"*( l, r: Array ): Array;
	VAR len: Index;  diff: Array;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r ) THEN len := LEN( l );  NEW( diff, len );  SubtractAA( l^, r^, diff^, 0, len ) ELSE DataErrors.Error( "The lengths of the two supplied Array vectors were not equal." ) END
		ELSE DataErrors.Error( "One or both of the two supplied Array vectors was NIL." )
		END;
		RETURN diff
	END "-";

	PROCEDURE "-"*( l: Array;  r: Array1dInt.Array ): Array;
	VAR i, len: NbrInt.Integer;  diff: Array;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r ) THEN
				len := LEN( l );  NEW( diff, len );
				FOR i := 0 TO len - 1 DO diff[i] := l[i] - r[i] END
			ELSE DataErrors.Error( "The lengths of the two supplied mixed-type vectors were not equal." )
			END
		ELSE DataErrors.Error( "One or both of the two supplied mixed-type vectors was NIL." )
		END;
		RETURN diff
	END "-";

	PROCEDURE "-"*( l: Array1dInt.Array;  r: Array ): Array;
	VAR i, len: NbrInt.Integer;  diff: Array;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r ) THEN
				len := LEN( l );  NEW( diff, len );
				FOR i := 0 TO len - 1 DO diff[i] := l[i] - r[i] END
			ELSE DataErrors.Error( "The lengths of the two supplied mixed-type vectors were not equal." )
			END
		ELSE DataErrors.Error( "One or both of the two supplied mixed-type vectors was NIL." )
		END;
		RETURN diff
	END "-";

(** Array dot product *)
	PROCEDURE "*"*( l, r: Array ): Value;
	VAR len: Index;  dot: Value;
	BEGIN
		dot := 0;
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r ) THEN len := LEN( l );  ScalarProduct( l^, r^, dot, 0, 0, len );  ELSE DataErrors.Error( "The lengths of the two supplied Array vectors were not equal." ) END
		ELSE DataErrors.Error( "One or both of the two supplied Array vectors was NIL." )
		END;
		RETURN dot
	END "*";

	PROCEDURE "*"*( l: Array;  r: Array1dInt.Array ): NbrRat.Rational;
	VAR i, len: NbrInt.Integer;  dot: NbrRat.Rational;
	BEGIN
		dot := 0;
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r ) THEN
				len := LEN( l );
				FOR i := 0 TO len - 1 DO dot := dot + l[i] * r[i] END
			ELSE DataErrors.Error( "The lengths of the two supplied mixed-type vectors were not equal." )
			END
		ELSE DataErrors.Error( "One or both of the two supplied mixed-type vectors was NIL." )
		END;
		RETURN dot
	END "*";

	PROCEDURE "*"*( l: Array1dInt.Array;  r: Array ): NbrRat.Rational;
	VAR i, len: NbrInt.Integer;  dot: NbrRat.Rational;
	BEGIN
		dot := 0;
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r ) THEN
				len := LEN( l );
				FOR i := 0 TO len - 1 DO dot := dot + l[i] * r[i] END
			ELSE DataErrors.Error( "The lengths of the two supplied mixed-type vectors were not equal." )
			END
		ELSE DataErrors.Error( "One or both of the two supplied mixed-type vectors was NIL." )
		END;
		RETURN dot
	END "*";

(** Scalar multiplication *)
	PROCEDURE "*"*( l: Value;  r: Array ): Array;
	VAR len: Index;  prod: Array;
	BEGIN
		IF r # NIL THEN len := LEN( r );  NEW( prod, len );  MultAV( r^, l, prod^, 0, len );  ELSE DataErrors.Error( "The supplied Array vector was NIL." ) END;
		RETURN prod
	END "*";

	PROCEDURE "*"*( l: Array;  r: Value ): Array;
	VAR len: Index;  prod: Array;
	BEGIN
		IF l # NIL THEN len := LEN( l );  NEW( prod, len );  MultAV( l^, r, prod^, 0, len );  ELSE DataErrors.Error( "The supplied Array vector was NIL." ) END;
		RETURN prod
	END "*";

	PROCEDURE "*"*( l: NbrInt.Integer;  r: Array ): Array;
	VAR i, len: NbrInt.Integer;  left: NbrRat.Rational;  prod: Array;
	BEGIN
		IF r # NIL THEN
			len := LEN( r );  NEW( prod, len );  left := l;
			FOR i := 0 TO len - 1 DO prod[i] := left * r[i] END
		ELSE DataErrors.Error( "The supplied Array vector was NIL." )
		END;
		RETURN prod
	END "*";

	PROCEDURE "*"*( l: Array;  r: NbrInt.Integer ): Array;
	VAR i, len: NbrInt.Integer;  right: NbrRat.Rational;  prod: Array;
	BEGIN
		IF l # NIL THEN
			len := LEN( l );  NEW( prod, len );  right := r;
			FOR i := 0 TO len - 1 DO prod[i] := l[i] * right END
		ELSE DataErrors.Error( "The supplied Array vector was NIL." )
		END;
		RETURN prod
	END "*";

(** Scalar division *)
	PROCEDURE "/"*( l: Array;  r: Value ): Array;
	VAR len: Index;  div: Array;
	BEGIN
		IF l # NIL THEN
			IF r # 0 THEN len := LEN( l );  NEW( div, len );  DivAV( l^, r, div^, 0, len );  ELSE DataErrors.Error( "Division by zero." ) END
		ELSE DataErrors.Error( "The supplied Array vector was NIL." )
		END;
		RETURN div
	END "/";

	PROCEDURE "/"*( l: Array;  r: NbrInt.Integer ): Array;
	VAR i, len: NbrInt.Integer;  right: NbrRat.Rational;  div: Array;
	BEGIN
		IF l # NIL THEN
			  right := r;
			IF right # 0 THEN
				len := LEN( l );  NEW( div, len );
				FOR i := 0 TO len - 1 DO div[i] := l[i] / right END
			ELSE DataErrors.Error( "Division by Integer zero." )
			END
		ELSE DataErrors.Error( "The supplied Array vector was NIL." )
		END;
		RETURN div
	END "/";

END Array1dRat.

