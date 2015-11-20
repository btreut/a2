(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE Array2dInt;   (**AUTHOR "adf, fof"; PURPOSE "Basic operations on type ARRAY OF ARRAY OF Int **)

IMPORT SYSTEM, Array1dBytes, NbrInt, NbrRe, ArrayXd := ArrayXdInt, Array1d := Array1dInt, DataErrors;

TYPE
	Value* = ArrayXd.Value;  RealValue* = NbrRe.Real;
	Array* = POINTER TO ARRAY OF ARRAY OF Value;
	Index* = NbrInt.Integer;

	PROCEDURE Copy*( VAR src: ARRAY OF ARRAY OF Value;  VAR dest: ARRAY OF ARRAY OF Value;  srcx, srcy, destx, desty, w, h: Index );
	(** ccordinates: A[y,x] *)
	VAR y: Index;
	BEGIN
		Array1dBytes.RangeCheck2( srcx, srcy, w, h, LEN( src[0] ), LEN( src ) );
		Array1dBytes.RangeCheck2( destx, desty, w, h, LEN( dest[0] ), LEN( dest ) );

		IF (ADDRESSOF( src[0] ) = ADDRESSOF( dest[0] )) (* same array *) & (srcy < desty) THEN  (*reverse copy order *)
			y := h - 1;
			WHILE (y >= 0) DO Array1d.Copy( src[srcy + y], dest[desty + y], srcx, destx, w );  DEC( y ) END;
		ELSE
			y := 0;
			WHILE (y < h) DO Array1d.Copy( src[srcy + y], dest[desty + y], srcx, destx, w );  INC( y );  END;
		END;
	END Copy;

	PROCEDURE Fill*( val: Value;  VAR res: ARRAY OF ARRAY OF Value;  x, y, w, h: Index );
	VAR i: Index;
	BEGIN
		Array1dBytes.RangeCheck2( x, y, w, h, LEN( res[0] ), LEN( res ) );

		i := 0;
		WHILE (i < h) DO Array1d.Fill( val, res[i + y], x, w );  INC( i );  END;
	END Fill;

	PROCEDURE MinMax*( VAR s: ARRAY OF ARRAY OF Value;  x, y, w, h: Index;  VAR min, max: Value;
										 VAR minx, miny, maxx, maxy: Index );
	VAR cmin, cmax: Value;  cminpos, cmaxpos, i: Index;
	BEGIN
		Array1dBytes.RangeCheck2( x, y, w, h, LEN( s[0] ), LEN( s ) );

		min := s[y, x];  max := s[y, x];  minx := x;  miny := y;  maxx := x;  maxy := y;
		FOR i := y TO y + h - 1 DO
			Array1d.MinMax( s[i], x, w, cmin, cmax, cminpos, cmaxpos );
			IF cmin < min THEN min := cmin;  minx := cminpos;  miny := i;  END;
			IF cmax > max THEN max := cmax;  maxx := cmaxpos;  maxy := i;  END
		END
	END MinMax;

	PROCEDURE kSmallest*( k: Index;  VAR s: ARRAY OF ARRAY OF Value;  x, y, w, h: Index ): Value;
	(** does not modify S*)
	VAR values: ArrayXd.Array1;  i: Index;
	BEGIN
		Array1dBytes.RangeCheck2( x, y, w, h, LEN( s[0] ), LEN( s ) );

		NEW( values, w * h );
		FOR i := y TO y + h - 1 DO Array1d.Copy( s[i], values^, x, i * w, w );  END;
		RETURN Array1d.kSmallestModify( k, values^, w * h )
	END kSmallest;

	PROCEDURE Median*( VAR s: ARRAY OF ARRAY OF Value;  x, y, w, h: Index ): Value;
	BEGIN
		RETURN kSmallest( w * h DIV 2, s, x, y, w, h )
	END Median;

	PROCEDURE MeanSsq*( VAR s: ARRAY OF ARRAY OF Value;  x, y, w, h: Index;  VAR mean, ssq: RealValue );
	(* mean and ssq distance of mean by provisional means algorithm *)
	VAR d: RealValue;  val: Value;  i, j: Index;
	BEGIN
		Array1dBytes.RangeCheck2( x, y, w, h, LEN( s[0] ), LEN( s ) );

		mean := 0;  ssq := 0;
		FOR i := 0 TO h - 1 DO
			FOR j := 0 TO w - 1 DO
				val := s[i + y, j + x];  d := val - mean;  mean := mean + d / ((i * w + j) + 1);  ssq := ssq + d * (val - mean);
			END
		END;
	END MeanSsq;

	PROCEDURE CopyRow*( y: Index;  VAR s: ARRAY OF ARRAY OF Value;  VAR res: ARRAY OF Value;  srcoffset, destoffset, len: Index );
	BEGIN
		(* range check Array1d *)
		Array1d.Copy( s[y], res, srcoffset, destoffset, len );
	END CopyRow;

	PROCEDURE CopyCol*( x: Index;  VAR s: ARRAY OF ARRAY OF Value;  VAR res: ARRAY OF Value;  srcoffset, destoffset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck2( x, srcoffset, 1, len, LEN( s[0] ), LEN( s ) );  Array1dBytes.RangeCheck( destoffset, len, LEN( res ) );

		INC( len, srcoffset );
		WHILE (srcoffset < len) DO res[destoffset] := s[srcoffset, x];  INC( srcoffset );  INC( destoffset );  END;
	END CopyCol;

	PROCEDURE CopyToRow*( VAR s: ARRAY OF Value;  y: Index;  VAR res: ARRAY OF ARRAY OF Value;
											  srcoffset, destoffset, len: Index );
	BEGIN
		(* asserts in Array1d *)
		Array1d.Copy( s, res[y], srcoffset, destoffset, len );
	END CopyToRow;

	PROCEDURE CopyToCol*( VAR s: ARRAY OF Value;  x: Index;  VAR res: ARRAY OF ARRAY OF Value;  srcoffset, destoffset, len: Index );
	BEGIN
		Array1dBytes.RangeCheck2( x, destoffset, 1, len, LEN( res[0] ), LEN( res ) );  Array1dBytes.RangeCheck( srcoffset, len, LEN( s ) );

		INC( len, srcoffset );
		WHILE (srcoffset < len) DO res[destoffset, x] := s[srcoffset];  INC( srcoffset );  INC( destoffset );  END;
	END CopyToCol;

	PROCEDURE Row*( y: Index;  VAR s: ARRAY OF ARRAY OF Value ): ArrayXd.Array1;
	VAR res: ArrayXd.Array1;  len: Index;
	BEGIN
		len := LEN( s[0] );  NEW( res, len );  CopyRow( y, s, res^, 0, 0, len );  RETURN res;
	END Row;

	PROCEDURE Col*( x: Index;  VAR s: ARRAY OF ARRAY OF Value ): ArrayXd.Array1;
	VAR res: ArrayXd.Array1;  len: Index;
	BEGIN
		len := LEN( s );  NEW( res, len );  CopyCol( x, s, res^, 0, 0, len );  RETURN res;
	END Col;

	PROCEDURE Transposed*( VAR s: ARRAY OF ARRAY OF Value ): Array;
	VAR res: Array;  x, y, w, h: Index;
	BEGIN
		h := LEN( s );  w := LEN( s[0] );  NEW( res, w, h );
		FOR y := 0 TO h - 1 DO
			FOR x := 0 TO w - 1 DO res[x, y] := s[y, x];  END;
		END;
		RETURN res;
	END Transposed;

	PROCEDURE SwapRows*( VAR s: ARRAY OF ARRAY OF Value;  y1, y2: Index );
	VAR temp: Value;  w, i: Index;
	BEGIN
		Array1dBytes.RangeCheck2( y1, y2, 0, 0, LEN( s ), LEN( s ) );

		w := LEN( s[0] );
		FOR i := 0 TO w - 1 DO temp := s[y1, i];  s[y1, i] := s[y2, i];  s[y2, i] := temp END
	END SwapRows;

	PROCEDURE SwapCols*( VAR s: ARRAY OF ARRAY OF Value;  x1, x2: Index );
	VAR temp: Value;  h, i: Index;
	BEGIN
		Array1dBytes.RangeCheck2( x1, x2, 0, 0, LEN( s[0] ), LEN( s[0] ) );

		h := LEN( s );
		FOR i := 0 TO h - 1 DO temp := s[i, x1];  s[i, x1] := s[i, x2];  s[i, x2] := temp END
	END SwapCols;


(** Monadic Operator - does not overwrite the argument *)
	PROCEDURE "-"*( x: Array ): Array;
	VAR i, k, cols, rows: Index;  minus: Array;
	BEGIN
		IF x # NIL THEN
			rows := LEN( x, 0 );  cols := LEN( x, 1 );  NEW( minus, rows, cols );
			FOR i := 0 TO rows - 1 DO
				FOR k := 0 TO cols - 1 DO minus[i, k] := -x[i, k] END
			END
		ELSE DataErrors.Error( "The supplied Array matrix was NIL." )
		END;
		RETURN minus
	END "-";

	PROCEDURE ":="*( VAR l: Array;  r: Value );
	BEGIN
		IF l # NIL THEN Fill( r, l^, 0, 0, LEN( l[0] ), LEN( l ) );  ELSE DataErrors.Error( "The supplied instance of Array2dInt.Array was NIL." ) END
	END ":=";

	PROCEDURE ":="*( VAR l: Array;  VAR r: ARRAY OF ARRAY OF Value );
	VAR i, k, cols, rows: Index;
	BEGIN
		rows := LEN( r, 0 );  cols := LEN( r, 1 );
		IF l = NIL THEN NEW( l, rows, cols )
		ELSIF (LEN( l, 0 ) # rows) OR (LEN( l, 1 ) # cols) THEN NEW( l, rows, cols )
		ELSE  (* matrix l is properly dimensioned *)
		END;
		FOR i := 0 TO rows - 1 DO
			FOR k := 0 TO cols - 1 DO l[i, k] := r[i, k] END
		END
	END ":=";

(** Arithmetic. Operators do not overwrite the arguments. *)
	PROCEDURE "+"*( l, r: Array ): Array;
	VAR i, k, cols, rows: Index;  sum: Array;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF (LEN( l, 0 ) = LEN( r, 0 )) & (LEN( l, 1 ) = LEN( r, 1 )) THEN
				rows := LEN( r, 0 );  cols := LEN( r, 1 );  NEW( sum, rows, cols );
				FOR i := 0 TO rows - 1 DO
					FOR k := 0 TO cols - 1 DO sum[i, k] := l[i, k] + r[i, k] END
				END
			ELSE DataErrors.Error( "The sizes of the two supplied Array matrices were not equal." )
			END
		ELSE DataErrors.Error( "One or both of the two supplied Array matrices was NIL." )
		END;
		RETURN sum
	END "+";

	PROCEDURE "-"*( l, r: Array ): Array;
	VAR i, k, cols, rows: Index;  diff: Array;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF (LEN( l, 0 ) = LEN( r, 0 )) & (LEN( l, 1 ) = LEN( r, 1 )) THEN
				rows := LEN( r, 0 );  cols := LEN( r, 1 );  NEW( diff, rows, cols );
				FOR i := 0 TO rows - 1 DO
					FOR k := 0 TO cols - 1 DO diff[i, k] := l[i, k] - r[i, k] END
				END
			ELSE DataErrors.Error( "The sizes of the two supplied Array matrices were not equal." )
			END
		ELSE DataErrors.Error( "One or both of the two supplied Array matrices was NIL." )
		END;
		RETURN diff
	END "-";

(** Array dot product *)
	PROCEDURE "*"*( l, r: Array ): Array;
	(** Caution:  Use brackets to ensure proper matrix multiplication when contracting three or more matrices,
				e.g., A*(B*C) is correct, whereas A*B*C is not.  This is because matrix multiplician is from right to left;
				whereas, the Oberon programming languages multiplies from left to right. *)
	VAR i, j, k, cols, dummy, rows, sum: Index;  dot: Array;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l, 1 ) = LEN( r, 0 ) THEN
				rows := LEN( l, 0 );  cols := LEN( r, 1 );  dummy := LEN( r, 0 );  NEW( dot, rows, cols );
				FOR i := 0 TO rows - 1 DO
					FOR j := 0 TO cols - 1 DO
						sum := 0;
						FOR k := 0 TO dummy - 1 DO sum := sum + l[i, k] * r[k, j] END;
						dot[i, j] := sum
					END
				END
			ELSE DataErrors.Error( "The sizes were incompatible, i.e., LEN(l,1) # LEN(r,0)." )
			END
		ELSE DataErrors.Error( "One or both of the two supplied Array matrices was NIL." )
		END;
		RETURN dot
	END "*";

(** Array-Vector contraction,  returns  x = A v  or x[i] = A[i, k] v[k] *)
	PROCEDURE "*"*( l: Array;  r: ArrayXd.Array1 ): ArrayXd.Array1;
	VAR i, k, dummy, rows, sum: Index;  dot: ArrayXd.Array1;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l, 1 ) = LEN( r ) THEN
				rows := LEN( l, 0 );  dummy := LEN( l, 1 );  NEW( dot, rows );
				FOR i := 0 TO rows - 1 DO
					sum := 0;
					FOR k := 0 TO dummy - 1 DO sum := sum + l[i, k] * r[k] END;
					dot[i] := sum
				END
			ELSE DataErrors.Error( "The sizes were incompatible, i.e., LEN(l,1) # LEN(r)." )
			END
		ELSE DataErrors.Error( "Either the Array matrix or Vector vector supplied was NIL." )
		END;
		RETURN dot
	END "*";

(** Vector-Array contraction,  returns  x = ATv = vTA  or x[i] = A[k, i] v[k] = v[k] A[k, i]  *)
	PROCEDURE "*"*( l: ArrayXd.Array1;  r: Array ): ArrayXd.Array1;
	VAR i, k, cols, dummy, sum: Index;  dot: ArrayXd.Array1;
	BEGIN
		IF (l # NIL ) & (r # NIL ) THEN
			IF LEN( l ) = LEN( r, 0 ) THEN
				cols := LEN( r, 1 );  dummy := LEN( r, 0 );  NEW( dot, cols );
				FOR i := 0 TO cols - 1 DO
					sum := 0;
					FOR k := 0 TO dummy - 1 DO sum := sum + l[k] * r[k, i] END;
					dot[i] := sum
				END
			ELSE DataErrors.Error( "The sizes were incompatible, i.e., LEN(l,0) # LEN(r)." )
			END
		ELSE DataErrors.Error( "Either the Vector vector or Array matrix supplied was NIL." )
		END;
		RETURN dot
	END "*";

(** Scalar multiplication *)
	PROCEDURE "*"*( l: Value;  r: Array ): Array;
	VAR i, k, cols, rows: Index;  prod: Array;
	BEGIN
		IF r # NIL THEN
			rows := LEN( r, 0 );  cols := LEN( r, 1 );  NEW( prod, rows, cols );
			FOR i := 0 TO rows - 1 DO
				FOR k := 0 TO cols - 1 DO prod[i, k] := l * r[i, k] END
			END
		ELSE DataErrors.Error( "The supplied Array matrix was NIL." )
		END;
		RETURN prod
	END "*";

	PROCEDURE "*"*( l: Array;  r: Value ): Array;
	VAR i, k, cols, rows: Index;  prod: Array;
	BEGIN
		IF l # NIL THEN
			rows := LEN( l, 0 );  cols := LEN( l, 1 );  NEW( prod, rows, cols );
			FOR i := 0 TO rows - 1 DO
				FOR k := 0 TO cols - 1 DO prod[i, k] := l[i, k] * r END
			END
		ELSE DataErrors.Error( "The supplied Array matrix was NIL." )
		END;
		RETURN prod
	END "*";

(** Scalar division *)
	PROCEDURE "DIV"*( l: Array;  r: Value ): Array;
	VAR i, k, cols, rows: Index;  div: Array;
	BEGIN
		IF l # NIL THEN
			IF r # 0 THEN
				rows := LEN( l, 0 );  cols := LEN( l, 1 );  NEW( div, rows, cols );
				FOR i := 0 TO rows - 1 DO
					FOR k := 0 TO cols - 1 DO div[i, k] := l[i, k] DIV r END
				END
			ELSE DataErrors.Error( "Division by zero." )
			END
		ELSE DataErrors.Error( "The supplied Array matrix was NIL." )
		END;
		RETURN div
	END "DIV";

	PROCEDURE "MOD"*( l: Array;  r: Value ): Array;
	VAR i, k, cols, rows: Index;  mod: Array;
	BEGIN
		IF l # NIL THEN
			IF r # 0 THEN
				rows := LEN( l, 0 );  cols := LEN( l, 1 );  NEW( mod, rows, cols );
				FOR i := 0 TO rows - 1 DO
					FOR k := 0 TO cols - 1 DO mod[i, k] := l[i, k] MOD r END
				END
			ELSE DataErrors.Error( "Division by zero." )
			END
		ELSE DataErrors.Error( "The supplied Array matrix was NIL." )
		END;
		RETURN mod
	END "MOD";

END Array2dInt.
