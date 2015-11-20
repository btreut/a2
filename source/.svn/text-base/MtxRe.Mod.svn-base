(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE MtxRe;   (** AUTHOR "fof"; PURPOSE "Matrix objects of type Real."; *)
(** caution:
since common indexing order in linear algebra
is row then column, the x coordinate corresponds to row
and y coordinate corresponds to column in this module.
Do not assume x to be horizontal and y to be vertical for
matrices when you use it for linear algebraic computation.
*)


IMPORT SYSTEM, NbrInt, ArrayXdBytes, ArrayXd := ArrayXdRe, Array1d := Array1dRe, DataErrors, Vec := VecRe, NbrRat, MtxInt, MtxRat, DataIO, NbrRe;

CONST
	(** The version number used when reading/writing a matrix to file. *)
	VERSION* = 1;

TYPE
	Value* = ArrayXd.Value;  Index* = LONGINT;  IntValue = ArrayXd.IntValue;  RatValue = NbrRat.Rational;
	Array* = ArrayXd.Array2;  Map* = ArrayXd.Map;

	Matrix* = OBJECT (ArrayXd.Array)
	VAR lenx-, leny-: LONGINT;
		rows-, cols-: LONGINT;   (* lenx = nr.Rows, leny = nr.Columns *)
	VAR ox-, oy-: LONGINT;
		Get-: PROCEDURE {DELEGATE} ( x, y: Index ): Value;

		(* override *)
		PROCEDURE AlikeX( ): ArrayXdBytes.Array;
		VAR copy: Matrix;
		BEGIN
			NEW( copy, origin[0], len[0], origin[1], len[1] );  RETURN copy;
		END AlikeX;

		PROCEDURE NewRangeX( neworigin, newlen: ArrayXdBytes.IndexArray;  copydata: BOOLEAN );
		BEGIN
			IF LEN( newlen ) # 2 THEN HALT( 1001 ) END;
			NewRangeX^( neworigin, newlen, copydata );
		END NewRangeX;

		PROCEDURE ValidateCache;
		BEGIN
			ValidateCache^;
			IF dim # 2 THEN HALT( 100 ) END;
			lenx := len[0];  leny := len[1];  ox := origin[0];  oy := origin[1];  rows := lenx;  cols := leny;
		END ValidateCache;

		PROCEDURE SetBoundaryCondition*( c: SHORTINT );   (* called by new, load and directly *)
		BEGIN
			SetBoundaryCondition^( c );
			CASE c OF
			ArrayXd.StrictBoundaryC:
					Get := Get2;
			| ArrayXd.AbsorbingBoundaryC:
					Get := Get2BAbsorbing;
			| ArrayXd.PeriodicBoundaryC:
					Get := Get2BPeriodic;
			| ArrayXd.SymmetricOnBoundaryC:
					Get := Get2BSymmetricOnB
			| ArrayXd.SymmetricOffBoundaryC:
					Get := Get2BSymmetricOffB
			| ArrayXd.AntisymmetricOnBoundaryC:
					Get := Get2BAntisymmetricOnB
			| ArrayXd.AntisymmetricOffBoundaryC:
					Get := Get2BAntisymmetricOffB
			END;
		END SetBoundaryCondition;

	(** new*)
		PROCEDURE & New*( ox, rowsORw, oy, colsORh: LONGINT );
		BEGIN
			NewXdB( ArrayXdBytes.Array2( ox, oy ), ArrayXdBytes.Array2( rowsORw, colsORh ) );
		END New;

		PROCEDURE Alike*( ): Matrix;
		VAR copy: ArrayXdBytes.Array;
		BEGIN
			copy := AlikeX();  RETURN copy( Matrix );
		END Alike;

		PROCEDURE NewRange*( ox, rowsORw, oy, colsORh: LONGINT;  copydata: BOOLEAN );
		BEGIN
			IF (rowsORw # len[0]) OR (colsORh # len[1]) OR (ox # origin[0]) OR (oy # origin[1]) THEN
				NewRangeX^( ArrayXdBytes.Array2( ox, oy ), ArrayXdBytes.Array2( rowsORw, colsORh ), copydata )
			END;
		END NewRange;

		PROCEDURE Copy*( ): Matrix;
		VAR res: ArrayXdBytes.Array;
		BEGIN
			res := CopyX();  RETURN res( Matrix );
		END Copy;

		PROCEDURE Set*( rowORx (**= row or x coordinate*) , colORy (**= column or y coordinate *) : Index;  v: Value );
		BEGIN
			ArrayXdBytes.Set2( SELF, rowORx, colORy, v );
		END Set;

	(** Exchanges values held by  mtx[row1, k]  and  mtx[row2, k],  0 # k < cols. *)
		PROCEDURE SwapRows*( row1, row2: Index );
		BEGIN
			ToggleElements( 0, row1, row2 )
		END SwapRows;

	(** Exchanges values held by  mtx[k, col1]  and  mtx[k, col2],  0 # k < rows. *)
		PROCEDURE SwapColumns*( col1, col2: Index );
		BEGIN
			ToggleElements( 1, col1, col2 )
		END SwapColumns;

		PROCEDURE Transpose*;
		BEGIN
			PermuteDimensions( ArrayXdBytes.Array2( 1, 0 ), TRUE );
		END Transpose;


	(** Stores mtx := mtx * x  which requires  x  to be square and to have dimension  cols X cols *)

		PROCEDURE Dot*( x: Matrix );
		VAR res: Matrix;
		BEGIN
			IF x # NIL THEN
				IF x.len[0] = x.len[1] THEN
					IF len[0] # len[1] THEN
						IF len[0] = x.len[0] THEN
							res := SELF * x;  ArrayXdBytes.CopyArrayPartToArrayPart( res, SELF, res.origin, res.len, origin, len );
						ELSE DataErrors.Error( "The two matrices were not compatible" )
						END;
					ELSE DataErrors.Error( "This  matrix in not square." )
					END
				ELSE DataErrors.Error( "The supplied matrix was not square." )
				END
			ELSE DataErrors.Error( "The supplied matrix to be doted was NIL." )
			END
		END Dot;

	(** Stores mtx := mtxT * x  which requires both matrices to be square and have equal dimensions  *)
		PROCEDURE LeftDot*( x: Matrix );
		BEGIN
			Transpose;  Dot( x );
		END LeftDot;

	(** Stores mtx := mtx * xT  which requires both matrices to be square and have equal dimensions  *)
		PROCEDURE RightDot*( x: Matrix );
		BEGIN
			x.Transpose;  Dot( x );  x.Transpose;
		END RightDot;

		PROCEDURE Row*( row: Index ): Vec.Vector;
		VAR v: Vec.Vector;
		BEGIN
			NEW( v, 0, len[1] );  ArrayXd.CopyMtxToVec( SELF, v, 1, row, 0, 0, len[1] );  RETURN v;
		END Row;

		PROCEDURE InsertRow*( at: Index );
		BEGIN
			InsertElements( 0, at, 1 ) (* insert elements in each  col *)
		END InsertRow;

		PROCEDURE DeleteRow*( x: Index );
		BEGIN
			DeleteElements( 0, x, 1 );   (* delete elements from each  col *)
		END DeleteRow;

		PROCEDURE Col*( col: Index ): Vec.Vector;
		VAR v: Vec.Vector;
		BEGIN
			NEW( v, 0, len[0] );  ArrayXd.CopyMtxToVec( SELF, v, 0, 0, col, 0, len[0] );  RETURN v;
		END Col;

		PROCEDURE InsertCol*( at: Index );
		BEGIN
			InsertElements( 1, at, 1 )
		END InsertCol;

		PROCEDURE DeleteCol*( x: Index );
		BEGIN
			DeleteElements( 1, x, 1 );
		END DeleteCol;

	(** copy methods using the current boundary condition SELF.bc*)
		PROCEDURE CopyToVec*( dest: ArrayXd.Array;  dim: Index;  srcx, srcy, destx, len: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 1) THEN HALT( 1002 ) END;
			slen := ArrayXdBytes.Index2( 1, 1 );  slen[dim] := len;
			CopyToArray( dest, ArrayXdBytes.Index2( srcx, srcy ), slen, ArrayXdBytes.Index1( destx ), ArrayXdBytes.Index1( len ) );
		END CopyToVec;

		PROCEDURE CopyToMtx*( dest: ArrayXd.Array;  srcx, srcy, destx, desty, lenx, leny: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 2) THEN HALT( 1005 ) END;
			slen := ArrayXdBytes.Index2( lenx, leny );
			CopyToArray( dest, ArrayXdBytes.Index2( srcx, srcy ), slen, ArrayXdBytes.Index2( destx, desty ), slen );
		END CopyToMtx;

		PROCEDURE CopyToCube*( dest: ArrayXd.Array;  dimx, dimy: Index;  srcx, srcy, destx, desty, destz, lenx, leny: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 3) OR (dimx >= dimy) THEN HALT( 1005 ) END;
			slen := ArrayXdBytes.Index3( 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;
			CopyToArray( dest, ArrayXdBytes.Index2( srcx, srcy ), ArrayXdBytes.Index2( lenx, leny ),
								   ArrayXdBytes.Index3( destx, desty, destz ), slen );
		END CopyToCube;

		PROCEDURE CopyToHCube*( dest: ArrayXd.Array;  dimx, dimy: Index;
													  srcx, srcy, destx, desty, destz, destt, lenx, leny: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 4) OR (dimx >= dimy) THEN HALT( 1005 ) END;
			slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;
			CopyToArray( dest, ArrayXdBytes.Index2( srcx, srcy ), ArrayXdBytes.Index2( lenx, leny ),
								   ArrayXdBytes.Index4( destx, desty, destz, destt ), slen );
		END CopyToHCube;

		PROCEDURE CopyTo1dArray*( VAR dest: ARRAY OF Value;  sx, sy, slenx, sleny: Index;  dpos, dlen: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 1, ArrayXdBytes.Index1( 0 ), ArrayXdBytes.Index1( LEN( dest ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index2( sx, sy ), ArrayXdBytes.Index2( slenx, sleny ),
																  ArrayXdBytes.Index1( dpos ), ArrayXdBytes.Index1( dlen ) );
		END CopyTo1dArray;

		PROCEDURE CopyTo2dArray*( VAR dest: ARRAY OF ARRAY OF Value;  sx, sy, slenx, sleny: Index;  dposx, dposy, dlenx, dleny: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( dest, 1 ), LEN( dest, 0 ) ),
																			  SIZEOF( Value ), ADDRESSOF( dest[0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index2( sx, sy ), ArrayXdBytes.Index2( slenx, sleny ),
																  ArrayXdBytes.Index2( dposx, dposy ), ArrayXdBytes.Index2( dlenx, dleny ) );
		END CopyTo2dArray;

		PROCEDURE CopyTo3dArray*( VAR dest: ARRAY OF ARRAY OF ARRAY OF Value;  sx, sy, slenx, sleny: Index;
													   dposx, dposy, dposz, dlenx, dleny, dlenz: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																			  ArrayXdBytes.Index3( LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0, 0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index2( sx, sy ), ArrayXdBytes.Index2( slenx, sleny ),
																  ArrayXdBytes.Index3( dposx, dposy, dposz ),
																  ArrayXdBytes.Index3( dlenx, dleny, dlenz ) );
		END CopyTo3dArray;

		PROCEDURE CopyTo4dArray*( VAR dest: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;  sx, sy, slenx, sleny: Index;
													   dposx, dposy, dposz, dpost, dlenx, dleny, dlenz, dlent: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																			  ArrayXdBytes.Index4( LEN( dest, 3 ), LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0, 0, 0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index2( sx, sy ), ArrayXdBytes.Index2( slenx, sleny ),
																  ArrayXdBytes.Index4( dposx, dposy, dposz, dpost ),
																  ArrayXdBytes.Index4( dlenx, dleny, dlenz, dlent ) );
		END CopyTo4dArray;

	(** copy from without boundary conditions *)
		PROCEDURE CopyFrom1dArray*( VAR src: ARRAY OF Value;  spos, slen: Index;  dx, dy, dlenx, dleny: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 1, ArrayXdBytes.Index1( 0 ), ArrayXdBytes.Index1( LEN( src ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index1( spos ), ArrayXdBytes.Index1( slen ),
																			   ArrayXdBytes.Index2( dx, dy ), ArrayXdBytes.Index2( dlenx, dleny ) );
		END CopyFrom1dArray;

		PROCEDURE CopyFrom2dArray*( VAR src: ARRAY OF ARRAY OF Value;  sposx, spoxy, slenx, sleny: Index;
														    dx, dy, dlenx, dleny: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( src, 1 ), LEN( src, 0 ) ),
																			  SIZEOF( Value ), ADDRESSOF( src[0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index2( sposx, spoxy ),
																			   ArrayXdBytes.Index2( slenx, sleny ), ArrayXdBytes.Index2( dx, dy ),
																			   ArrayXdBytes.Index2( dlenx, dleny ) );
		END CopyFrom2dArray;

		PROCEDURE CopyFrom3dArray*( VAR src: ARRAY OF ARRAY OF ARRAY OF Value;  sposx, spoxy, sposz, slenx, sleny, slenz: Index;
														    dx, dy, dlenx, dleny: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																			  ArrayXdBytes.Index3( LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0, 0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index3( sposx, spoxy, sposz ),
																			   ArrayXdBytes.Index3( slenx, sleny, slenz ), ArrayXdBytes.Index2( dx, dy ),
																			   ArrayXdBytes.Index2( dlenx, dleny ) );
		END CopyFrom3dArray;

		PROCEDURE CopyFrom4dArray*( VAR src: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;
														    sposx, spoxy, sposz, spost, slenx, sleny, slenz, slent: Index;  dx, dy, dlenx, dleny: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																			  ArrayXdBytes.Index4( LEN( src, 3 ), LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0, 0, 0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index4( sposx, spoxy, sposz, spost ),
																			   ArrayXdBytes.Index4( slenx, sleny, slenz, slent ),
																			   ArrayXdBytes.Index2( dx, dy ), ArrayXdBytes.Index2( dlenx, dleny ) );
		END CopyFrom4dArray;

	END Matrix;

	PROCEDURE FrobeniusNorm*( m: Matrix ): NbrRe.Real;
	BEGIN
		RETURN Array1d.L2Norm( m.data^, 0, LEN( m.data ) );
	END FrobeniusNorm;


	PROCEDURE Transpose*( u: Matrix ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := u.Copy();  res.Transpose;  RETURN res;
	END Transpose;

	PROCEDURE ":="*( VAR l: Matrix;  VAR r: ARRAY OF ARRAY OF Value );
	BEGIN
		(*		IF r = NIL THEN l := NIL;  RETURN END;  *)
		IF l = NIL THEN NEW( l, 0, LEN( r, 1 ), 0, LEN( r, 0 ) ) ELSE l.NewRange( 0, LEN( r, 1 ), 0, LEN( r, 0 ), FALSE );  END;

		ArrayXdBytes.CopyMemoryToArrayPart( ADDRESSOF( r[0, 0] ), l, LEN( r, 1 ) * LEN( r, 0 ), NIL , NIL );
	END ":=";

	PROCEDURE ":="*( VAR l: Matrix;  r: Vec.Vector );
	BEGIN
		(*		IF r = NIL THEN l := NIL;  RETURN END;  *)
		IF l = NIL THEN NEW( l, 0, 1, 0, r.len[0] ) ELSE l.NewRange( 0, 1, 0, r.len[0], FALSE );  END;
		ArrayXdBytes.CopyDataRaw( r, l );
	END ":=";

	PROCEDURE ":="*( VAR l: Matrix;  r: MtxInt.Matrix );
	VAR i, last: LONGINT;
	BEGIN
		IF r = NIL THEN l := NIL ELSE
			IF l = NIL THEN NEW( l, r.origin[0], r.len[0], r.origin[1], r.len[1] );  END;
			last := LEN( r.data ) - 1;
			FOR i := 0 TO last DO l.data[i] := r.data[i];  END;
		END;
	END ":=";

	PROCEDURE ":="*( VAR l: Matrix;  r: MtxRat.Matrix );
	VAR i, last: LONGINT;
	BEGIN
		IF r = NIL THEN l := NIL ELSE
			IF l = NIL THEN NEW( l, r.origin[0], r.len[0], r.origin[1], r.len[1] );  END;
			last := LEN( r.data ) - 1;
			FOR i := 0 TO last DO l.data[i] := r.data[i];  END;
		END;
	END ":=";

	PROCEDURE ":="*( VAR l: Matrix;  r: Value );
	BEGIN
		IF l # NIL THEN ArrayXd.Fill( l, r );  END;
	END ":=";

	PROCEDURE ":="*( VAR l: Matrix;  r: RatValue );
	VAR r1: Value;
	BEGIN
		r1 := r;  l := r1;
	END ":=";

	PROCEDURE ":="*( VAR l: Matrix;  r: IntValue );
	VAR r1: Value;
	BEGIN
		r1 := r;  l := r1;
	END ":=";

	PROCEDURE "+"*( l, r: Matrix ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := l.Alike();  ArrayXd.Add( l, r, res );  RETURN res;
	END "+";

	PROCEDURE "-"*( l, r: Matrix ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := l.Alike();  ArrayXd.Sub( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "+"*( l: Matrix;  r: Value ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := l.Alike();  ArrayXd.AddAV( l, r, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Matrix;  r: RatValue ): Matrix;
	VAR res: Matrix;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.AddAV( l, r1, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Matrix;  r: IntValue ): Matrix;
	VAR res: Matrix;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.AddAV( l, r1, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Value;  r: Matrix ): Matrix;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "+"*( l: RatValue;  r: Matrix ): Matrix;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "+"*( l: IntValue;  r: Matrix ): Matrix;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "-"*( l: Matrix;  r: Value ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := l.Alike();  ArrayXd.SubAV( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Matrix;  r: RatValue ): Matrix;
	VAR res: Matrix;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.SubAV( l, r1, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Matrix;  r: IntValue ): Matrix;
	VAR res: Matrix;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.SubAV( l, r1, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Value;  r: Matrix ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := r.Alike();  ArrayXd.SubVA( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: RatValue;  r: Matrix ): Matrix;
	VAR res: Matrix;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.SubVA( l1, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: IntValue;  r: Matrix ): Matrix;
	VAR res: Matrix;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.SubVA( l1, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Matrix ): Matrix;
	BEGIN
		RETURN 0 - l;
	END "-";

	PROCEDURE "*"*( l: Matrix;  r: Value ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := l.Alike();  ArrayXd.MulAV( l, r, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Matrix;  r: RatValue ): Matrix;
	VAR res: Matrix;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.MulAV( l, r1, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Matrix;  r: IntValue ): Matrix;
	VAR res: Matrix;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.MulAV( l, r1, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Value;  r: Matrix ): Matrix;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "*"*( l: RatValue;  r: Matrix ): Matrix;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "*"*( l: IntValue;  r: Matrix ): Matrix;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "/"*( l: Matrix;  r: Value ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := l.Alike();  ArrayXd.DivAV( l, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: Matrix;  r: RatValue ): Matrix;
	VAR res: Matrix;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.DivAV( l, r1, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: Matrix;  r: IntValue ): Matrix;
	VAR res: Matrix;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.DivAV( l, r1, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: Value;  r: Matrix ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := r.Alike();  ArrayXd.DivVA( l, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: RatValue;  r: Matrix ): Matrix;
	VAR res: Matrix;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.DivVA( l1, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: IntValue;  r: Matrix ): Matrix;
	VAR res: Matrix;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.DivVA( l1, r, res );  RETURN res;
	END "/";


(*
	PROCEDURE "MOD"*( l: Matrix;  r: Value ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := l.Alike();  ArrayXd.ModAV( l, r, res );  RETURN res;
	END "MOD";

	PROCEDURE "MOD"*( l: Value;  r: Matrix ): Matrix;
	VAR res: Matrix;
	BEGIN
		res := r.Alike();  ArrayXd.ModVA( l, r, res );  RETURN res;
	END "MOD";
*)

	PROCEDURE "*"*( l: Vec.Vector;  r: Matrix ): Vec.Vector;
	VAR res: Vec.Vector;  rc, rr, lc, i, j: LONGINT;  sum: Value;
	BEGIN
		rc := r.cols;  rr := r.rows;  lc := l.lenx;

		IF lc # rr THEN DataErrors.Error( "The supplied matrix / vector were incompatible." );  HALT( 100 );
		ELSE
			NEW( res, 0, rc );
			FOR i := 0 TO rc - 1 DO  (* right columns *)
				sum := 0;
				FOR j := 0 TO lc - 1 DO sum := sum + l.Get( j ) * r.Get( j, i );  END;
				res.Set( i, sum );
			END;
		END;
		RETURN res;
	END "*";

	PROCEDURE "*"*( l: Matrix;  r: Vec.Vector ): Vec.Vector;
	VAR res: Vec.Vector;  lr, lc, rr, i, j: LONGINT;  sum: Value;
	BEGIN
		lr := l.rows;  lc := l.cols;  rr := r.lenx;
		IF lc # rr THEN DataErrors.Error( "The supplied matrix / vector were incompatible." );  HALT( 100 );
		ELSE
			NEW( res, 0, lr );
			FOR i := 0 TO lr - 1 DO
				sum := 0;
				FOR j := 0 TO lc - 1 DO sum := sum + l.Get( i, j ) * r.Get( j );  END;
				res.Set( i, sum );
			END;
		END;
		RETURN res;
	END "*";

	PROCEDURE "*"*( l, r: Matrix ): Matrix;
	VAR res: Matrix;  rr, rc, lr, lc, i, j, k: LONGINT;  sum: Value;
		(**! far from opimal: use internal routines of ArrayXdBytes *)
	BEGIN
		rc := r.cols;   (* columns of right matrix *)
		rr := r.rows;   (* rows of right matrix *)
		lr := l.rows;  lc := l.cols;
		IF lc # rr THEN DataErrors.Error( "The supplied matrices were incompatible." );  HALT( 100 )
		ELSE
			NEW( res, 0, lr, 0, rc );

			FOR i := 0 TO lr - 1 DO  (* left rows*)
				FOR j := 0 TO rc - 1 DO  (* right columns *)
					sum := 0;
					FOR k := 0 TO lc - 1 (* = rr -1 *) DO sum := sum + l.Get( i, k ) * r.Get( k, j );  END;
					res.Set( i, j, sum );
				END;
			END;
		END;
		RETURN res;
	END "*";

(* The procedures needed to register type Matrix so that its instances can be made persistent. *)
	PROCEDURE LoadMatrix( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR a: Matrix;  version: SHORTINT;  ver: NbrInt.Integer;
	BEGIN
		R.RawSInt( version );
		IF version = -1 THEN
			obj := NIL  (* Version tag is -1 for NIL. *)
		ELSIF version = VERSION THEN NEW( a, 0, 0, 0, 0 );  a.Read( R );  obj := a
		ELSE  (* Encountered an unknown version number. *)
			ver := version;  DataErrors.IntError( ver, "Alien version number encountered." );  HALT( 1000 )
		END
	END LoadMatrix;

	PROCEDURE StoreMatrix( W: DataIO.Writer;  obj: OBJECT );
	VAR a: Matrix;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  a := obj( Matrix );  a.Write( W ) END
	END StoreMatrix;

	PROCEDURE Register;
	VAR a: Matrix;
	BEGIN
		NEW( a, 0, 0, 0, 0 );  DataIO.PlugIn( a, LoadMatrix, StoreMatrix )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of Matrix from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: Matrix );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( Matrix )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: Matrix );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Register
END MtxRe.
