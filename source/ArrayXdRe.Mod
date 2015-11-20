(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE ArrayXdRe;   (** AUTHOR "fof"; PURPOSE "Basic operations on an X-dimensional array of Real"; *)
 (** any item containing the string "dbg"  is for debugging purposes only and will be removed from this module, do NOT use *)

IMPORT SYSTEM, NbrInt, NbrRe, ArrayXdBytes, Array1d := Array1dRe, dbgOut := KernelLog, DataErrors, Array1dInt,
	ArrayXdRat, DataIO;

CONST
	generic* = 0;  vector* = 1;  matrix* = 2;  cube* = 3;  hcube* = 4;
	(** The version used when reading/writing an arbitrary dimensional array to file. *)
	VERSION* = 1;

	StrictBoundaryC* = 0;   (* data beyond limit -> TRAP *)
	AbsorbingBoundaryC* = 1;   (* data beyond limit = zero*)
	PeriodicBoundaryC* = 2;   (* data[x] =data[x MOD LEN(data)], torus *)
	SymmetricOnBoundaryC* = 3;   (*  mirror boundaries, using border point once; W= reflection centered on point N *)
	SymmetricOffBoundaryC* = 4;   (* mirror boundaries, using border point twice; reflection centered between point N and point N+1 *)
	AntisymmetricOnBoundaryC* = 5;   (* like SymmetricOnBoundaryC but with additional change of sign if out of bounds *)
	AntisymmetricOffBoundaryC* = 6;   (* like SymmetricOffBoundaryC but with additional change of sign if out of bounds *)
TYPE
	Value* = Array1d.Value;  Index* = LONGINT;  Array1* = Array1d.Array;  IntValue* = Array1dInt.Value;
	Array2* = POINTER TO ARRAY OF ARRAY OF Value;
	Array3* = POINTER TO ARRAY OF ARRAY OF ARRAY OF Value;
	Array4* = POINTER TO ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;
	Map* = Array1d.Map;

	(** Class Array has been DataIO registered, and therefore, any instance of it can be made persistent
	by using the DataIO Reader and Writer, or more simply, by calling procedures Load and Store below. *)

	Array* = OBJECT (ArrayXdBytes.Array)
	VAR data-: Array1;   (*! will probably be removed, do not use ! *)

		(** override *)
		PROCEDURE Allocate( size: LONGINT;  VAR adr: Index;  VAR ptr: ANY );
		BEGIN
			NEW( data, size );  adr := ADDRESSOF( data[0] );  ptr := data;
		END Allocate;

		PROCEDURE GetInfo( VAR elementsize: Index );
		BEGIN
			elementsize := SIZEOF( Value );
		END GetInfo;

		PROCEDURE AlikeX( ): ArrayXdBytes.Array;
		VAR copy: Array;
		BEGIN
			NEW( copy, origin, len );  RETURN copy;
		END AlikeX;

		(** new *)

	(** Read and Write are for internal use only.
		Exporting them permits extensible, persistent, data types to be constructed. *)
		PROCEDURE Read*( R: DataIO.Reader );
		BEGIN {EXCLUSIVE}
			LoadXd( R )
		END Read;

		PROCEDURE Write*( W: DataIO.Writer );
		BEGIN
			StoreXd( W, TRUE )
		END Write;

		PROCEDURE Type*( ): SHORTINT;
		(* generic, vector, matrix, cube, hcube *)
		BEGIN
			IF dim < 5 THEN RETURN SHORT( SHORT( dim ) ) ELSE RETURN 0 END;
		END Type;

		PROCEDURE Get1*( x: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get1( SELF, x, v );  RETURN v;
		END Get1;

		PROCEDURE Set1*( x: Index;  v: Value );
		BEGIN
			ArrayXdBytes.Set1( SELF, x, v );
		END Set1;

		PROCEDURE Get2*( x, y: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get2( SELF, x, y, v );  RETURN v;
		END Get2;

		PROCEDURE Set2*( x, y: Index;  v: Value );
		BEGIN
			ArrayXdBytes.Set2( SELF, x, y, v );
		END Set2;

		PROCEDURE Get3*( x, y, z: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get3( SELF, x, y, z, v );  RETURN v;
		END Get3;

		PROCEDURE Set3*( x, y, z: Index;  v: Value );
		BEGIN
			ArrayXdBytes.Set3( SELF, x, y, z, v );
		END Set3;

		PROCEDURE Get4*( x, y, z, t: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get4( SELF, x, y, z, t, v );  RETURN v;
		END Get4;

		PROCEDURE Set4*( x, y, z, t: Index;  v: Value );
		BEGIN
			ArrayXdBytes.Set4( SELF, x, y, z, t, v );
		END Set4;

		PROCEDURE GetX*( VAR x: ARRAY OF Index;  dim: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.GetX( SELF, x, dim, v );  RETURN v;
		END GetX;

		PROCEDURE SetX*( VAR x: ARRAY OF Index;  dim: Index;  v: Value );
		BEGIN
			ArrayXdBytes.SetX( SELF, x, dim, v );
		END SetX;

		(*** Get  with boundary conditions *)

	(** absorbing: data beyond limit = zero *)
		PROCEDURE Get1BAbsorbing*( x: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) THEN ArrayXdBytes.Get1( SELF, x, v );  RETURN v ELSE RETURN 0 END;
		END Get1BAbsorbing;

		PROCEDURE Get2BAbsorbing*( x, y: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) & ArrayXdBytes.InBounds( o1, l1, y ) THEN
				ArrayXdBytes.Get2( SELF, x, y, v );  RETURN v
			ELSE RETURN 0
			END;
		END Get2BAbsorbing;

		PROCEDURE Get3BAbsorbing*( x, y, z: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) & ArrayXdBytes.InBounds( o1, l1, y ) & ArrayXdBytes.InBounds( o2, l2, z ) THEN
				ArrayXdBytes.Get3( SELF, x, y, z, v );  RETURN v
			ELSE RETURN 0
			END;
		END Get3BAbsorbing;

		PROCEDURE Get4BAbsorbing*( x, y, z, t: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) & ArrayXdBytes.InBounds( o1, l1, y ) & ArrayXdBytes.InBounds( o2, l2, z ) &
			    ArrayXdBytes.InBounds( o3, l3, t ) THEN
				ArrayXdBytes.Get4( SELF, x, y, z, t, v );  RETURN v
			ELSE RETURN 0
			END;
		END Get4BAbsorbing;

		PROCEDURE GetXBAbsorbing*( b: ARRAY OF Index;  dim: Index ): Value;
		VAR v: Value;  i: Index;
		BEGIN
			i := 0;
			WHILE (i < dim) DO
				IF ~ArrayXdBytes.InBounds( origin[i], len[i], b[i] ) THEN RETURN 0 END;
				INC( i );
			END;
			ArrayXdBytes.GetX( SELF, b, dim, v );  RETURN v
		END GetXBAbsorbing;

	(** periodic: data[x] =data[x MOD LEN(data)]  *)

		PROCEDURE Get1BPeriodic*( x: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get1( SELF, ArrayXdBytes.PeriodicBounds( o0, l0, x ), v );  RETURN v
		END Get1BPeriodic;

		PROCEDURE Get2BPeriodic*( x, y: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get2( SELF, ArrayXdBytes.PeriodicBounds( o0, l0, x ), ArrayXdBytes.PeriodicBounds( o1, l1, y ), v );
			RETURN v
		END Get2BPeriodic;

		PROCEDURE Get3BPeriodic*( x, y, z: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get3( SELF, ArrayXdBytes.PeriodicBounds( o0, l0, x ), ArrayXdBytes.PeriodicBounds( o1, l1, y ),
											 ArrayXdBytes.PeriodicBounds( o2, l2, z ), v );
			RETURN v
		END Get3BPeriodic;

		PROCEDURE Get4BPeriodic*( x, y, z, t: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get4( SELF, ArrayXdBytes.PeriodicBounds( o0, l0, x ), ArrayXdBytes.PeriodicBounds( o1, l1, y ),
											 ArrayXdBytes.PeriodicBounds( o2, l2, z ), ArrayXdBytes.PeriodicBounds( o3, l3, z ), v );
			RETURN v
		END Get4BPeriodic;

		PROCEDURE GetXBPeriodic*( b: ARRAY OF Index;  dim: Index ): Value;
		VAR v: Value;  i: Index;
		BEGIN
			i := 0;
			WHILE (i < dim) DO b[i] := ArrayXdBytes.PeriodicBounds( origin[i], len[i], b[i] );  INC( i ) END;
			ArrayXdBytes.GetX( SELF, b, dim, v );  RETURN v
		END GetXBPeriodic;

	(** mirror boundaries, using border point twice;   reflection centered between point N and point N+1 *)
		PROCEDURE Get1BSymmetricOffB*( x: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get1( SELF, ArrayXdBytes.MirrorOffB( o0, l0, x ), v );  RETURN v
		END Get1BSymmetricOffB;

		PROCEDURE Get2BSymmetricOffB*( x, y: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get2( SELF, ArrayXdBytes.MirrorOffB( o0, l0, x ), ArrayXdBytes.MirrorOffB( o1, l1, y ), v );  RETURN v
		END Get2BSymmetricOffB;

		PROCEDURE Get3BSymmetricOffB*( x, y, z: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get3( SELF, ArrayXdBytes.MirrorOffB( o0, l0, x ), ArrayXdBytes.MirrorOffB( o1, l1, y ),
											 ArrayXdBytes.MirrorOffB( o2, l2, z ), v );
			RETURN v
		END Get3BSymmetricOffB;

		PROCEDURE Get4BSymmetricOffB*( x, y, z, t: Index ): Value;
		VAR v: Value;
		BEGIN
			ArrayXdBytes.Get4( SELF, ArrayXdBytes.MirrorOffB( o0, l0, x ), ArrayXdBytes.MirrorOffB( o1, l1, y ),
											 ArrayXdBytes.MirrorOffB( o2, l2, z ), ArrayXdBytes.MirrorOffB( o3, l3, z ), v );
			RETURN v
		END Get4BSymmetricOffB;

		PROCEDURE GetXBSymmetricOffB*( b: ARRAY OF Index;  dim: Index ): Value;
		VAR v: Value;  i: Index;
		BEGIN
			i := 0;
			WHILE (i < dim) DO b[i] := ArrayXdBytes.MirrorOffB( origin[i], len[i], b[i] );  INC( i ) END;
			ArrayXdBytes.GetX( SELF, b, dim, v );  RETURN v
		END GetXBSymmetricOffB;

	(** mirror boundaries, using border point once;   reflection centered on point N*)
		PROCEDURE Get1BSymmetricOnB*( x: Index ): Value;
		VAR v: Value;
		BEGIN
			x := ArrayXdBytes.MirrorOnB( o0, l0, x );  ArrayXdBytes.Get1( SELF, x, v );  RETURN v
		END Get1BSymmetricOnB;

		PROCEDURE Get2BSymmetricOnB*( x, y: Index ): Value;
		VAR v: Value;
		BEGIN
			x := ArrayXdBytes.MirrorOnB( o0, l0, x );  y := ArrayXdBytes.MirrorOnB( o1, l1, y );
			ArrayXdBytes.Get2( SELF, x, y, v );  RETURN v
		END Get2BSymmetricOnB;

		PROCEDURE Get3BSymmetricOnB*( x, y, z: Index ): Value;
		VAR v: Value;
		BEGIN
			x := ArrayXdBytes.MirrorOnB( o0, l0, x );  y := ArrayXdBytes.MirrorOnB( o1, l1, y );
			z := ArrayXdBytes.MirrorOnB( o2, l2, z );  ArrayXdBytes.Get3( SELF, x, y, z, v );  RETURN v
		END Get3BSymmetricOnB;

		PROCEDURE Get4BSymmetricOnB*( x, y, z, t: Index ): Value;
		VAR v: Value;
		BEGIN
			x := ArrayXdBytes.MirrorOnB( o0, l0, x );  y := ArrayXdBytes.MirrorOnB( o1, l1, y );
			z := ArrayXdBytes.MirrorOnB( o2, l2, z );  t := ArrayXdBytes.MirrorOnB( o3, l3, z );
			ArrayXdBytes.Get4( SELF, x, y, z, t, v );  RETURN v
		END Get4BSymmetricOnB;

		PROCEDURE GetXBSymmetricOnB*( b: ARRAY OF Index;  dim: Index ): Value;
		VAR v: Value;  i: Index;
		BEGIN
			i := 0;
			WHILE (i < dim) DO b[i] := ArrayXdBytes.MirrorOnB( origin[i], len[i], b[i] );  INC( i ) END;
			ArrayXdBytes.GetX( SELF, b, dim, v );  RETURN v
		END GetXBSymmetricOnB;

	(* like SymmetricOffB but with change of sign  if not in range *)
		PROCEDURE Get1BAntisymmetricOffB*( x: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) THEN ArrayXdBytes.Get1( SELF, x, v );  RETURN v
			ELSE ArrayXdBytes.Get1( SELF, ArrayXdBytes.MirrorOffB( o0, l0, x ), v );  RETURN -v;
			END;
		END Get1BAntisymmetricOffB;

		PROCEDURE Get2BAntisymmetricOffB*( x, y: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) & ArrayXdBytes.InBounds( o1, l1, y ) THEN
				ArrayXdBytes.Get2( SELF, x, y, v );  RETURN v
			ELSE
				ArrayXdBytes.Get2( SELF, ArrayXdBytes.MirrorOffB( o0, l0, x ), ArrayXdBytes.MirrorOffB( o1, l1, y ), v );  RETURN -v
			END;
		END Get2BAntisymmetricOffB;

		PROCEDURE Get3BAntisymmetricOffB*( x, y, z: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) & ArrayXdBytes.InBounds( o1, l1, y ) & ArrayXdBytes.InBounds( o2, l2, z ) THEN
				ArrayXdBytes.Get3( SELF, x, y, z, v );  RETURN v
			ELSE
				ArrayXdBytes.Get3( SELF, ArrayXdBytes.MirrorOffB( o0, l0, x ), ArrayXdBytes.MirrorOffB( o1, l1, y ),
												 ArrayXdBytes.MirrorOffB( o2, l2, z ), v );
				RETURN -v
			END;
		END Get3BAntisymmetricOffB;

		PROCEDURE Get4BAntisymmetricOffB*( x, y, z, t: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) & ArrayXdBytes.InBounds( o1, l1, y ) & ArrayXdBytes.InBounds( o2, l2, z ) &
			    ArrayXdBytes.InBounds( o3, l3, t ) THEN
				ArrayXdBytes.Get4( SELF, x, y, z, t, v );  RETURN v
			ELSE
				ArrayXdBytes.Get4( SELF, ArrayXdBytes.MirrorOffB( o0, l0, x ), ArrayXdBytes.MirrorOffB( o1, l1, y ),
												 ArrayXdBytes.MirrorOffB( o2, l2, z ), ArrayXdBytes.MirrorOffB( o3, l3, t ), v );
				RETURN -v
			END;
		END Get4BAntisymmetricOffB;

		PROCEDURE GetXBAntisymmetricOffB*( b: ARRAY OF Index;  dim: Index ): Value;
		VAR v: Value;  i: Index;  inv: BOOLEAN;
		BEGIN
			i := 0;  inv := FALSE;
			WHILE (i < dim) DO
				inv := inv OR (~ArrayXdBytes.InBounds( origin[i], len[i], b[i] ));
				b[i] := ArrayXdBytes.MirrorOffB( origin[i], len[i], b[i] );  INC( i );
			END;
			ArrayXdBytes.GetX( SELF, b, dim, v );
			IF inv THEN RETURN -v ELSE RETURN v END;
		END GetXBAntisymmetricOffB;

	(** like SymmetricOnB but with change of sign  if not in range *)
		PROCEDURE Get1BAntisymmetricOnB*( x: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) THEN ArrayXdBytes.Get1( SELF, x, v );  RETURN v
			ELSE ArrayXdBytes.Get1( SELF, ArrayXdBytes.MirrorOnB( o0, l0, x ), v );  RETURN -v;
			END;
		END Get1BAntisymmetricOnB;

		PROCEDURE Get2BAntisymmetricOnB*( x, y: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) & ArrayXdBytes.InBounds( o1, l1, y ) THEN
				ArrayXdBytes.Get2( SELF, x, y, v );  RETURN v
			ELSE
				ArrayXdBytes.Get2( SELF, ArrayXdBytes.MirrorOnB( o0, l0, x ), ArrayXdBytes.MirrorOnB( o1, l1, y ), v );  RETURN -v
			END;
		END Get2BAntisymmetricOnB;

		PROCEDURE Get3BAntisymmetricOnB*( x, y, z: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) & ArrayXdBytes.InBounds( o1, l1, y ) & ArrayXdBytes.InBounds( o2, l2, z ) THEN
				ArrayXdBytes.Get3( SELF, x, y, z, v );  RETURN v
			ELSE
				ArrayXdBytes.Get3( SELF, ArrayXdBytes.MirrorOnB( o0, l0, x ), ArrayXdBytes.MirrorOnB( o1, l1, y ),
												 ArrayXdBytes.MirrorOnB( o2, l2, z ), v );
				RETURN -v
			END;
		END Get3BAntisymmetricOnB;

		PROCEDURE Get4BAntisymmetricOnB*( x, y, z, t: Index ): Value;
		VAR v: Value;
		BEGIN
			IF ArrayXdBytes.InBounds( o0, l0, x ) & ArrayXdBytes.InBounds( o1, l1, y ) & ArrayXdBytes.InBounds( o2, l2, z ) &
			    ArrayXdBytes.InBounds( o3, l3, t ) THEN
				ArrayXdBytes.Get4( SELF, x, y, z, t, v );  RETURN v
			ELSE
				ArrayXdBytes.Get4( SELF, ArrayXdBytes.MirrorOnB( o0, l0, x ), ArrayXdBytes.MirrorOnB( o1, l1, y ),
												 ArrayXdBytes.MirrorOnB( o2, l2, z ), ArrayXdBytes.MirrorOnB( o3, l3, t ), v );
				RETURN -v
			END;
		END Get4BAntisymmetricOnB;

		PROCEDURE GetXBAntisymmetricOnB*( b: ARRAY OF Index;  dim: Index ): Value;
		VAR v: Value;  i: Index;  inv: BOOLEAN;
		BEGIN
			i := 0;  inv := FALSE;
			WHILE (i < dim) DO
				inv := inv OR (~ArrayXdBytes.InBounds( origin[i], len[i], b[i] ));
				b[i] := ArrayXdBytes.MirrorOnB( origin[i], len[i], b[i] );  INC( i );
			END;
			ArrayXdBytes.GetX( SELF, b, dim, v );
			IF inv THEN RETURN -v ELSE RETURN v END;
		END GetXBAntisymmetricOnB;

	(** copy using the current boundary condition SELF:bc*)
		PROCEDURE CopyToArray*( dest: Array;  srcpos, srclen, destpos, destlen: ArrayXdBytes.IndexArray );
		BEGIN
			CopyArrayToArrayPartB( SELF, dest, bc, srcpos, srclen, destpos, destlen );
		END CopyToArray;

	(** apply map m to all entries, dimension ordering is not necessarily preserved! *)
		PROCEDURE MapAll*( m: Array1d.Map );
		BEGIN
			IF m # NIL THEN Array1d.ApplyMap( m, data^, 0, LEN( data ) );  ELSE DataErrors.Error( "A NIL mapping function was supplied." ) END
		END MapAll;

		PROCEDURE Negate*;
		BEGIN {EXCLUSIVE}
			Array1d.Negate( data^, 0, LEN( data ) );
			(*
				FOR i := 0 TO len - 1 DO vec[i] := -vec[i] END
				*)
		END Negate;

	(** arr := arr+x *)
		PROCEDURE Add*( x: Array );
		BEGIN
			IF x # NIL THEN
				IF LEN( data ) = LEN( x.data ) THEN
					BEGIN {EXCLUSIVE}
					(*FOR i := 0 TO len - 1 DO vec[i] := vec[i] - x.vec[i] END*)
						Array1d.AddAA( data^, x.data^, data^, 0, len[0] );
					END
				ELSE DataErrors.Error( "Lengths of the two arrays were not equal." )
				END
			ELSE DataErrors.Error( "The supplied array to be subtracted was NIL." )
			END
		END Add;

	(** arr := arr-x *)
		PROCEDURE Subtract*( x: Array );
		BEGIN
			IF x # NIL THEN
				IF LEN( data ) = LEN( x.data ) THEN
					BEGIN {EXCLUSIVE}
					(*FOR i := 0 TO len - 1 DO vec[i] := vec[i] - x.vec[i] END*)
						Array1d.SubtractAA( data^, x.data^, data^, 0, len[0] );
					END
				ELSE DataErrors.Error( "Lengths of the two arrays were not equal." )
				END
			ELSE DataErrors.Error( "The supplied array to be subtracted was NIL." )
			END
		END Subtract;

	(* arr[i] := a*arr[i]  forall i*)
		PROCEDURE Multiply*( a: Value );
		VAR i: Index;
		BEGIN {EXCLUSIVE}
			FOR i := 0 TO LEN( data ) - 1 DO data[i] := a * data[i] END
		END Multiply;

	(** arr[i] :=arr[i] / a forall i *)
		PROCEDURE Divide*( a: Value );
		VAR i: Index;
		BEGIN
			IF a # 0 THEN
				BEGIN {EXCLUSIVE}
					FOR i := 0 TO LEN( data ) - 1 DO data[i] := data[i] / a;  END
				END;
			ELSE DataErrors.Error( "Division by zero." )
			END
		END Divide;

		PROCEDURE dbgWrite*;
		VAR x, y, z: LONGINT;
		BEGIN
			IF Type() = vector THEN
				FOR x := origin[0] TO origin[0] + len[0] - 1 DO (*dbgOut.LongReal( Get1( x ), 12 );  *)dbgOut.String( "|" );  END;
				dbgOut.Ln;
			ELSIF Type() = matrix THEN
				FOR y := origin[1] TO origin[1] + len[1] - 1 DO
					FOR x := origin[0] TO origin[0] + len[0] - 1 DO (*dbgOut.LongReal( Get2( x, y ), 12 );  *)dbgOut.String( "|" );  END;
					dbgOut.Ln;
				END;
				dbgOut.Ln;
			ELSIF Type() = cube THEN
				FOR z := origin[2] TO origin[2] + len[2] - 1 DO
					FOR y := origin[1] TO origin[1] + len[1] - 1 DO
						FOR x := origin[0] TO origin[0] + len[0] - 1 DO (*dbgOut.LongReal( Get2( x, y ), 12 );  *)dbgOut.String( "|" );  END;
						dbgOut.Ln;
					END;
					dbgOut.Ln;
				END;
			END;

		END dbgWrite;

	END Array;

	PROCEDURE New1d*( ox, w: Index ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, ArrayXdBytes.Array1( ox ), ArrayXdBytes.Array1( w ) );  RETURN res;
	END New1d;

	PROCEDURE New2d*( ox, w, oy, h: Index ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, ArrayXdBytes.Array2( ox, oy ), ArrayXdBytes.Array2( w, h ) );  RETURN res;
	END New2d;

	PROCEDURE New3d*( ox, w, oy, h, oz, d: Index ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, ArrayXdBytes.Array3( ox, oy, oz ), ArrayXdBytes.Array3( w, h, d ) );  RETURN res;
	END New3d;

	PROCEDURE New4d*( ox, w, oy, h, oz, d, ot, dt: Index ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, ArrayXdBytes.Array4( ox, oy, oz, ot ), ArrayXdBytes.Array4( w, h, d, dt ) );  RETURN res;
	END New4d;

	PROCEDURE CopyVecToVec*( src, dest: Array;  srcx, destx, len: Index );
	BEGIN
		IF (src.dim # 1) OR (dest.dim # 1) THEN HALT( 1001 ) END;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index1( srcx ), ArrayXdBytes.Index1( len ),
																		   ArrayXdBytes.Index1( destx ), ArrayXdBytes.Index1( len ) );
	END CopyVecToVec;

	PROCEDURE CopyMtxToVec*( src, dest: Array;  dim: Index;  srcx, srcy, destx, len: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 2) OR (dest.dim # 1) THEN HALT( 1002 ) END;
		slen := ArrayXdBytes.Index2( 1, 1 );  slen[dim] := len;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index2( srcx, srcy ), slen,
																		   ArrayXdBytes.Index1( destx ), ArrayXdBytes.Index1( len ) );
	END CopyMtxToVec;

	PROCEDURE CopyVecToMtx*( src, dest: Array;  dim: Index;  srcx, destx, desty, len: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 1) OR (dest.dim # 2) THEN HALT( 1002 ) END;
		slen := ArrayXdBytes.Index2( 1, 1 );  slen[dim] := len;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index1( srcx ), ArrayXdBytes.Index1( len ),
																		   ArrayXdBytes.Index2( destx, desty ), slen );
	END CopyVecToMtx;

	PROCEDURE CopyCubeToVec*( src, dest: Array;  dim: Index;  srcx, srcy, srcz, destx, len: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 3) OR (dest.dim # 1) THEN HALT( 1003 ) END;
		slen := ArrayXdBytes.Index3( 1, 1, 1 );  slen[dim] := len;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index3( srcx, srcy, srcz ), slen,
																		   ArrayXdBytes.Index1( destx ), ArrayXdBytes.Index1( len ) );
	END CopyCubeToVec;

	PROCEDURE CopyVecToCube*( src, dest: Array;  dim: Index;  srcx, destx, desty, destz, len: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 1) OR (dest.dim # 3) THEN HALT( 1002 ) END;
		slen := ArrayXdBytes.Index3( 1, 1, 1 );  slen[dim] := len;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index1( srcx ), ArrayXdBytes.Index1( len ),
																		   ArrayXdBytes.Index3( destx, desty, destz ), slen );
	END CopyVecToCube;

	PROCEDURE CopyHCubeToVec*( src, dest: Array;  dim: Index;  srcx, srcy, srcz, srct, destx, len: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 4) OR (dest.dim # 1) THEN HALT( 1004 ) END;
		slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dim] := len;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ), slen,
																		   ArrayXdBytes.Index1( destx ), ArrayXdBytes.Index1( len ) );
	END CopyHCubeToVec;

	PROCEDURE CopyVecToHCube*( src, dest: Array;  dim: Index;  srcx, destx, desty, destz, destt, len: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 1) OR (dest.dim # 4) THEN HALT( 1002 ) END;
		slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dim] := len;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index1( srcx ), ArrayXdBytes.Index1( len ),
																		   ArrayXdBytes.Index4( destx, desty, destz, destt ), slen );
	END CopyVecToHCube;

	PROCEDURE CopyMtxToMtx*( src, dest: Array;  srcx, srcy, destx, desty, lenx, leny: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 2) OR (dest.dim # 2) THEN HALT( 1005 ) END;
		slen := ArrayXdBytes.Index2( lenx, leny );
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index2( srcx, srcy ), slen,
																		   ArrayXdBytes.Index2( destx, desty ), slen );
	END CopyMtxToMtx;

	PROCEDURE CopyCubeToMtx*( src, dest: Array;  dimx, dimy: Index;  srcx, srcy, srcz, destx, desty, lenx, leny: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 3) OR (dest.dim # 2) THEN HALT( 1005 ) END;
		slen := ArrayXdBytes.Index3( 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index3( srcx, srcy, srcz ), slen,
																		   ArrayXdBytes.Index2( destx, desty ), ArrayXdBytes.Index2( lenx, leny ) );
	END CopyCubeToMtx;

	PROCEDURE CopyMtxToCube*( src, dest: Array;  dimx, dimy: Index;  srcx, srcy, destx, desty, destz, lenx, leny: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 2) OR (dest.dim # 3) THEN HALT( 1005 ) END;
		slen := ArrayXdBytes.Index3( 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index2( srcx, srcy ), ArrayXdBytes.Index2( lenx, leny ),
																		   ArrayXdBytes.Index3( destx, desty, destz ), slen );
	END CopyMtxToCube;

	PROCEDURE CopyHCubeToMtx*( src, dest: Array;  dimx, dimy: Index;  srcx, srcy, srcz, srct, destx, desty, lenx, leny: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 4) OR (dest.dim # 2) THEN HALT( 1005 ) END;
		slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ), slen,
																		   ArrayXdBytes.Index2( destx, desty ), ArrayXdBytes.Index2( lenx, leny ) );
	END CopyHCubeToMtx;

	PROCEDURE CopyMtxToHCube*( src, dest: Array;  dimx, dimy: Index;
														 srcx, srcy, destx, desty, destz, destt, lenx, leny: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 2) OR (dest.dim # 4) THEN HALT( 1005 ) END;
		slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index2( srcx, srcy ), ArrayXdBytes.Index2( lenx, leny ),
																		   ArrayXdBytes.Index4( destx, desty, destz, destt ), slen );
	END CopyMtxToHCube;

	PROCEDURE CopyCubeToCube*( src, dest: Array;  srcx, srcy, srcz, destx, desty, destz, lenx, leny, lenz: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 3) OR (dest.dim # 3) THEN HALT( 1005 ) END;
		slen := ArrayXdBytes.Index3( lenx, leny, lenz );
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index3( srcx, srcy, srcz ), slen,
																		   ArrayXdBytes.Index3( destx, desty, destz ), slen );
	END CopyCubeToCube;

	PROCEDURE CopyHCubeToCube*( src, dest: Array;  dimx, dimy, dimz: Index;
														  srcx, srcy, srcz, srct, destx, desty, destz, lenx, leny, lenz: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 4) OR (dest.dim # 3) THEN HALT( 1005 ) END;
		slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;  slen[dimz] := lenz;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ), slen,
																		   ArrayXdBytes.Index3( destx, desty, destz ),
																		   ArrayXdBytes.Index3( lenx, leny, lenz ) );
	END CopyHCubeToCube;

	PROCEDURE CopyCubeToHCube*( src, dest: Array;  dimx, dimy, dimz: Index;
														  srcx, srcy, srcz, destx, desty, destz, destt, lenx, leny, lenz: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 3) OR (dest.dim # 4) THEN HALT( 1005 ) END;
		slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;  slen[dimz] := lenz;
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index3( srcx, srcy, srcz ),
																		   ArrayXdBytes.Index3( lenx, leny, lenz ),
																		   ArrayXdBytes.Index4( destx, desty, destz, destt ), slen );
	END CopyCubeToHCube;

	PROCEDURE CopyHCubeToHCube*( src, dest: Array;
															 srcx, srcy, srcz, srct, destx, desty, destz, destt, lenx, leny, lenz, lent: Index );
	VAR slen: ArrayXdBytes.IndexArray;
	BEGIN
		IF (src.dim # 4) OR (dest.dim # 4) THEN HALT( 1005 ) END;
		slen := ArrayXdBytes.Index4( lenx, leny, lenz, lent );
		ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ), slen,
																		   ArrayXdBytes.Index4( destx, desty, destz, destt ), slen );
	END CopyHCubeToHCube;

	PROCEDURE CopyArrayToVec*( VAR src: ARRAY OF Value;  dest: Array;  srcx, destx, len: Index );
	BEGIN
		IF dest.dim # 1 THEN HALT( 1005 ) END;
		ArrayXdBytes.CheckLEQ( 0, srcx );  ArrayXdBytes.CheckLE( srcx + len, LEN( src ) );
		ArrayXdBytes.CopyMemoryToArrayPart( ADDRESSOF( src[srcx] ), dest, len, ArrayXdBytes.Index1( destx ),
																		 ArrayXdBytes.Index1( len ) );
	END CopyArrayToVec;

	PROCEDURE CopyVecToArray*( src: Array;  VAR dest: ARRAY OF Value;  srcx, destx, len: Index );
	BEGIN
		IF src.dim # 1 THEN HALT( 1005 ) END;
		ArrayXdBytes.CheckLEQ( 0, destx );  ArrayXdBytes.CheckLE( destx + len, LEN( dest ) );
		ArrayXdBytes.CopyArrayPartToMemory( src, ADDRESSOF( dest[destx] ), ArrayXdBytes.Index1( srcx ),
																		 ArrayXdBytes.Index1( len ), len );
	END CopyVecToArray;

	PROCEDURE CopyArrayToMtx*( VAR src: ARRAY OF ARRAY OF Value;  dest: Array;  srcx, srcy, destx, desty, lenx, leny: Index );
	VAR srcmem: ArrayXdBytes.ArrayMemoryStructure;
	BEGIN
		IF dest.dim # 2 THEN HALT( 1005 ) END;
		srcmem :=
			ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( src, 1 ), LEN( src, 0 ) ),
																		  SIZEOF( Value ), ADDRESSOF( src[0, 0] ) );
		ArrayXdBytes.CopyArrayPartToArrayPart( srcmem, dest, ArrayXdBytes.Index2( srcx, srcy ),
																		   ArrayXdBytes.Index2( lenx, leny ), ArrayXdBytes.Index2( destx, desty ),
																		   ArrayXdBytes.Index2( lenx, leny ) );
	END CopyArrayToMtx;

	PROCEDURE CopyMtxToArray*( src: Array;  VAR dest: ARRAY OF ARRAY OF Value;  srcx, srcy, destx, desty, lenx, leny: Index );
	VAR destmem: ArrayXdBytes.ArrayMemoryStructure;
	BEGIN
		IF src.dim # 2 THEN HALT( 1005 ) END;
		destmem :=
			ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( dest, 1 ), LEN( dest, 0 ) ),
																		  SIZEOF( Value ), ADDRESSOF( dest[0, 0] ) );
		ArrayXdBytes.CopyArrayPartToArrayPart( src, destmem, ArrayXdBytes.Index2( srcx, srcy ),
																		   ArrayXdBytes.Index2( lenx, leny ), ArrayXdBytes.Index2( destx, desty ),
																		   ArrayXdBytes.Index2( lenx, leny ) );
	END CopyMtxToArray;

	PROCEDURE CopyArrayToCube*( VAR src: ARRAY OF ARRAY OF ARRAY OF Value;  dest: Array;
													    srcx, srcy, srcz, destx, desty, destz, lenx, leny, lenz: Index );
	VAR srcmem: ArrayXdBytes.ArrayMemoryStructure;
	BEGIN
		IF dest.dim # 3 THEN HALT( 1005 ) END;
		srcmem :=
			ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																		  ArrayXdBytes.Index3( LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																		  ADDRESSOF( src[0, 0, 0] ) );
		ArrayXdBytes.CopyArrayPartToArrayPart( srcmem, dest, ArrayXdBytes.Index3( srcx, srcy, srcz ),
																		   ArrayXdBytes.Index3( lenx, leny, lenz ),
																		   ArrayXdBytes.Index3( destx, desty, destz ),
																		   ArrayXdBytes.Index3( lenx, leny, lenz ) );
	END CopyArrayToCube;

	PROCEDURE CopyCubeToArray*( src: Array;  VAR dest: ARRAY OF ARRAY OF ARRAY OF Value;
													    srcx, srcy, srcz, destx, desty, destz, lenx, leny, lenz: Index );
	VAR destmem: ArrayXdBytes.ArrayMemoryStructure;
	BEGIN
		IF src.dim # 3 THEN HALT( 1005 ) END;
		destmem :=
			ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																		  ArrayXdBytes.Index3( LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																		  ADDRESSOF( dest[0, 0, 0] ) );
		ArrayXdBytes.CopyArrayPartToArrayPart( src, destmem, ArrayXdBytes.Index3( srcx, srcy, srcz ),
																		   ArrayXdBytes.Index3( lenx, leny, lenz ),
																		   ArrayXdBytes.Index3( destx, desty, destz ),
																		   ArrayXdBytes.Index3( lenx, leny, lenz ) );
	END CopyCubeToArray;

	PROCEDURE CopyArrayToHCube*( VAR src: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;  dest: Array;
														  srcx, srcy, srcz, srct, destx, desty, destz, destt, lenx, leny, lenz, lent: Index );
	VAR srcmem: ArrayXdBytes.ArrayMemoryStructure;
	BEGIN
		IF dest.dim # 4 THEN HALT( 1005 ) END;
		srcmem :=
			ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																		  ArrayXdBytes.Index4( LEN( src, 3 ), LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																		  ADDRESSOF( src[0, 0, 0] ) );
		ArrayXdBytes.CopyArrayPartToArrayPart( srcmem, dest, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ),
																		   ArrayXdBytes.Index4( lenx, leny, lenz, lent ),
																		   ArrayXdBytes.Index4( destx, desty, destz, destt ),
																		   ArrayXdBytes.Index4( lenx, leny, lenz, lent ) );
	END CopyArrayToHCube;

	PROCEDURE CopyHCubeToArray*( src: Array;  VAR dest: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;
														  srcx, srcy, srcz, srct, destx, desty, destz, destt, lenx, leny, lenz, lent: Index );
	VAR destmem: ArrayXdBytes.ArrayMemoryStructure;
	BEGIN
		IF src.dim # 4 THEN HALT( 1005 ) END;
		destmem :=
			ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																		  ArrayXdBytes.Index4( LEN( dest, 3 ), LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																		  ADDRESSOF( dest[0, 0, 0] ) );
		ArrayXdBytes.CopyArrayPartToArrayPart( src, destmem, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ),
																		   ArrayXdBytes.Index4( lenx, leny, lenz, lent ),
																		   ArrayXdBytes.Index4( destx, desty, destz, destt ),
																		   ArrayXdBytes.Index4( lenx, leny, lenz, lent ) );
	END CopyHCubeToArray;

	PROCEDURE CopyArrayToArrayPartB*( src: Array;  dest: ArrayXdBytes.ArrayMemoryStructure;  boundaryCondition: SHORTINT;
																 srcpos, srclen, destpos, destlen: ArrayXdBytes.IndexArray );

	VAR temp: ArrayXdBytes.ArrayMemoryStructure;
		spos, dpos, last, borigin, blen, srcposcut, srclencut, destoffset: ArrayXdBytes.IndexArray;  i, dim: LONGINT;
		val: Value;  temp2: Array;  enumB: ArrayXdBytes.BoundaryEnum;
		Get: PROCEDURE {DELEGATE} ( x: ARRAY OF Index;
																																													 dim: Index ): Value;
		noinbound: BOOLEAN;  v: Value;

		(* for debugging
			PROCEDURE OutIndex( idx: ArrayXdBytes.IndexArray;  name: ARRAY OF CHAR );
		VAR i: LONGINT;
		BEGIN
			dbgOut.String( name );
			FOR i := 0 TO LEN( idx ) - 1 DO dbgOut.Int( idx[i], 1 );  dbgOut.String( "," );  END;
			dbgOut.Ln;
		END OutIndex;
		*)

		PROCEDURE Same( a, b: ArrayXdBytes.IndexArray ): BOOLEAN;
		BEGIN
			IF LEN( a ) # LEN( b ) THEN RETURN FALSE END;
			FOR i := 0 TO LEN( a ) - 1 DO
				IF a[i] # b[i] THEN RETURN FALSE END;
			END;
			RETURN TRUE;
		END Same;

	BEGIN
		dim := src.dim;
		IF boundaryCondition = StrictBoundaryC THEN
			ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, srcpos, srclen, destpos, destlen );   (* checks are done there *)
		ELSE
			srcposcut := ArrayXdBytes.IndexCpy( srcpos );  srclencut := ArrayXdBytes.IndexCpy( srclen );
			NEW( enumB, src, srcposcut, srclencut );
			IF (Same( srcposcut, srcpos )) & (Same( srclencut, srclen )) THEN  (* no boundaries *)
				ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, srcpos, srclen, destpos, destlen );  RETURN;
			ELSE
				CASE boundaryCondition OF
				PeriodicBoundaryC:
						Get := src.GetXBPeriodic;
				| SymmetricOnBoundaryC:
						Get := src.GetXBSymmetricOnB;
				| SymmetricOffBoundaryC:
						Get := src.GetXBSymmetricOffB;
				| AntisymmetricOnBoundaryC:
						Get := src.GetXBAntisymmetricOnB;
				| AntisymmetricOffBoundaryC:
						Get := src.GetXBAntisymmetricOffB;
				| AbsorbingBoundaryC:
						ArrayXdBytes.FillArrayPart( dest, destpos, destlen, val );   (* fill with 0 first *)
						Get := NIL;
				END;
				NEW( destoffset, dim );  noinbound := FALSE;
				IF Same( srclen, destlen ) THEN  (* same geometry, direct copy to boundary rects can be used*)
					FOR i := 0 TO dim - 1 DO
						destoffset[i] := destpos[i] + srcposcut[i] - srcpos[i];
						IF srclencut[i] = 0 THEN noinbound := TRUE END;
					END;
					IF ~noinbound THEN
						ArrayXdBytes.CopyArrayPartToArrayPart( src, dest, srcposcut, srclencut, destoffset, srclencut );
					END;
					FOR i := 0 TO dim - 1 DO destoffset[i] := destpos[i] - srcpos[i];  END;
					temp := dest;
				ELSE  (* not the same geometry, direct copy using rectangles cannot be used *)
					NEW( temp2, srcpos, srclen );  temp := temp2;
					FOR i := 0 TO dim - 1 DO
						destoffset[i] := 0;
						IF srclencut[i] = 0 THEN noinbound := TRUE END;
					END;
					IF ~noinbound THEN
						ArrayXdBytes.CopyArrayPartToArrayPart( src, temp, srcposcut, srclencut, srcposcut, srclencut );
					END;
				END;

				IF Get # NIL THEN
					NEW( spos, dim );  NEW( dpos, dim );  NEW( last, dim );

					WHILE (enumB.Get( borigin, blen )) DO  (* enumeration of rects describing the region out of range *)
						FOR i := 0 TO dim - 1 DO spos[i] := borigin[i];  last[i] := spos[i] + blen[i];  dpos[i] := spos[i] + destoffset[i] END;
						REPEAT
							v := Get( spos^, dim );
							SYSTEM.MOVE( ADDRESSOF( v ), ArrayXdBytes.AdrX( temp, dpos^, dim ), SIZEOF( Value ) );   (* optimize adress handling of destination, compute here ! *)

							(*temp.SetX( dpos^, dim, Get( spos^, dim ) );*) i := 0;  INC( spos[i] );  INC( dpos[i] );
							WHILE (i < dim - 1) & (spos[i] = last[i]) DO
								spos[i] := borigin[i];  dpos[i] := destoffset[i] + borigin[i];  INC( i );  INC( spos[i] );  INC( dpos[i] );
							END;
						UNTIL spos[i] = last[i];
					END;
				END;

				IF temp # dest THEN ArrayXdBytes.CopyArrayPartToArrayPart( temp, dest, srcpos, srclen, destpos, destlen );
				END;

			END;
		END;
	END CopyArrayToArrayPartB;

	PROCEDURE ":="*( VAR l: Array;  VAR r: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value );
	BEGIN
		(* IF r = NIL THEN l := NIL;  RETURN END;  *)
		IF l = NIL THEN l := New4d( 0, LEN( r, 3 ), 0, LEN( r, 2 ), 0, LEN( r, 1 ), 0, LEN( r, 0 ) );
		ELSE l.NewRangeX( ArrayXdBytes.Array4( 0, 0, 0, 0 ), ArrayXdBytes.Array4( LEN( r, 3 ), LEN( r, 2 ), LEN( r, 1 ), LEN( r, 0 ) ), FALSE )
		END;
		ArrayXdBytes.CopyMemoryToArray( ADDRESSOF( r[0, 0, 0, 0] ), l, LEN( r, 0 ) * LEN( r, 1 ) * LEN( r, 2 ) * LEN( r, 3 ) );
	END ":=";

	PROCEDURE ":="*( VAR l: Array;  VAR r: ARRAY OF ARRAY OF ARRAY OF Value );
	BEGIN
		(*	IF r = NIL THEN l := NIL;  RETURN END;  *)
		IF l = NIL THEN l := New3d( 0, LEN( r, 2 ), 0, LEN( r, 1 ), 0, LEN( r, 0 ) );
		ELSE l.NewRangeX( ArrayXdBytes.Array3( 0, 0, 0 ), ArrayXdBytes.Array3( LEN( r, 2 ), LEN( r, 1 ), LEN( r, 0 ) ), FALSE );
		END;
		ArrayXdBytes.CopyMemoryToArray( ADDRESSOF( r[0, 0, 0] ), l, LEN( r, 0 ) * LEN( r, 1 ) * LEN( r, 2 ) );
	END ":=";

(*
	PROCEDURE ":="( VAR l: Array;  VAR r: ARRAY OF ARRAY OF Value );
	BEGIN
		(*		IF r = NIL THEN l := NIL;  RETURN END;  *)
		IF l = NIL THEN l := New2d( 0, LEN( r, 1 ), 0, LEN( r, 0 ) )
		ELSE l.NewRangeX( ArrayXdBytes.Array2( 0, 0 ), ArrayXdBytes.Array2( LEN( r, 1 ), LEN( r, 0 ) ), FALSE );
		END;
		ArrayXdBytes.CopyMemoryToArray( ADDRESSOF( r[0, 0] ), l, LEN( r, 0 ) * LEN( r, 1 ) );
	END ":=";

	PROCEDURE ":="( VAR l: Array;  VAR r: ARRAY OF Value );
	BEGIN
		(*		IF r = NIL THEN l := NIL;  RETURN END;  *)
		IF l = NIL THEN l := New1d( 0, LEN( r, 0 ) )
		ELSE l.NewRangeX( ArrayXdBytes.Array1( 0 ), ArrayXdBytes.Array1( LEN( r, 0 ) ), FALSE );
		END;
		ArrayXdBytes.CopyMemoryToArray( ADDRESSOF( r[0] ), l, LEN( r, 0 ) );
	END ":=";

	PROCEDURE ":="( VAR l: Array;  r: ArrayXdInt.Array );
	VAR i, last: LONGINT;
	BEGIN
		IF r = NIL THEN l := NIL ELSE
			IF l = NIL THEN NEW( l, r.origin^, r.len^ );  END;
			last := LEN( r.data ) - 1;
			FOR i := 0 TO last DO l.data[i] := r.data[i];  END;
		END;
	END ":=";

	PROCEDURE ":="( VAR l: Array;  r: ArrayXdRat.Array );
	VAR i, last: LONGINT;
	BEGIN
		IF r = NIL THEN l := NIL ELSE
			IF l = NIL THEN NEW( l, r.origin^, r.len^ );  END;
			last := LEN( r.data ) - 1;
			FOR i := 0 TO last DO l.data[i] := r.data[i];  END;
		END;
	END ":=";
*)

(***!never do this : *

		PROCEDURE ":="( VAR l: Array;  r: Vector );
	BEGIN
		IF r = NIL THEN l := NIL;  RETURN END;
		IF l = NIL THEN NEW( l, r.origin^, r.len^ ) ELSE l.NewRangeX( r.origin^, r.len^, TRUE );  END;
		r.CopyElements( r.origin^, r.len^, l, l.origin^, l.len^ );
	END ":=";
 *)
	PROCEDURE ":="*( VAR l: Array1;  r: Array );
	BEGIN
		IF r = NIL THEN l := NIL;  RETURN END;
		ArrayXdBytes.CheckEQ( 1, r.dim );   (*ArrayXdBytes.CheckEQ( r.origin[0], 0 );  *)
		IF (l = NIL ) OR (LEN( l ) # r.len[0]) THEN NEW( l, r.len[0] );  END;
		ArrayXdBytes.CopyArrayToMemory( r, ADDRESSOF( l[0] ), LEN( l, 0 ) );
	END ":=";

	PROCEDURE ":="*( VAR l: Array2;  r: Array );
	BEGIN
		IF r = NIL THEN l := NIL;  RETURN END;
		ArrayXdBytes.CheckEQ( 2, r.dim );   (*ArrayXdBytes.CheckEQ( r.origin[0], 0 );  ArrayXdBytes.CheckEQ( r.origin[1], 0 );  *)
		IF (l = NIL ) OR (LEN( l, 1 ) # r.len[0]) OR (LEN( l, 0 ) # r.len[1]) THEN NEW( l, r.len[1], r.len[0] );  END;
		ArrayXdBytes.CopyArrayToMemory( r, ADDRESSOF( l[0, 0] ), LEN( l, 0 ) * LEN( l, 1 ) );
	END ":=";

	PROCEDURE ":="*( VAR l: Array3;  r: Array );
	BEGIN
		IF r = NIL THEN l := NIL;  RETURN END;
		ArrayXdBytes.CheckEQ( 3, r.dim );   (*ArrayXdBytes.CheckEQ( r.origin[0], 0 );  ArrayXdBytes.CheckEQ( r.origin[1], 0 );  ArrayXdBytes.CheckEQ( r.origin[2], 0 );  *)
		IF (l = NIL ) OR (LEN( l, 2 ) # r.len[0]) OR (LEN( l, 1 ) # r.len[1]) OR (LEN( l, 0 ) # r.len[2]) THEN NEW( l, r.len[2], r.len[1], r.len[0] );  END;
		ArrayXdBytes.CopyArrayToMemory( r, ADDRESSOF( l[0, 0, 0] ), LEN( l, 0 ) * LEN( l, 1 ) * LEN( l, 2 ) );
	END ":=";

(*
	PROCEDURE ":="( VAR l: Array4;  r: Array );
	BEGIN
		IF r = NIL THEN l := NIL;  RETURN END;
		ArrayXdBytes.CheckEQ( 4, r.dim );   (* ArrayXdBytes.CheckEQ( r.origin[0], 0 );  ArrayXdBytes.CheckEQ( r.origin[1], 0 );  ArrayXdBytes.CheckEQ( r.origin[2], 0 );
		ArrayXdBytes.CheckEQ( r.origin[3], 0 );  *)
		IF (l = NIL ) OR (LEN( l, 3 ) # r.len[0]) OR (LEN( l, 2 ) # r.len[1]) OR (LEN( l, 1 ) # r.len[2]) OR (LEN( l, 0 ) # r.len[3]) THEN
			NEW( l, r.len[3], r.len[2], r.len[1], r.len[0] );
		END;
		ArrayXdBytes.CopyArrayToMemory( r, ADDRESSOF( l[0, 0, 0, 0] ), LEN( l, 0 ) * LEN( l, 1 ) * LEN( l, 2 ) * LEN( l, 3 ) );
	END ":=";
*)

	PROCEDURE Fill*( l: Array;  r: Value );
	BEGIN
		Array1d.Fill( r, l.data^, 0, LEN( l.data ) );
	END Fill;

	PROCEDURE ":="*( VAR l: Array;  r: Value );
	BEGIN
		IF l # NIL THEN Fill( l, r ) END;
	END ":=";

	PROCEDURE ":="*( VAR l: Array;  r: ArrayXdRat.Value );
	VAR r1: Value;
	BEGIN
		r1 := r;  l := r1;
	END ":=";

	PROCEDURE ":="*( VAR l: Array;  r: IntValue );
	VAR r1: Value;
	BEGIN
		r1 := r;  l := r1;
	END ":=";

	PROCEDURE Add*( l, r, res: Array );
	BEGIN
		ArrayXdBytes.CheckEqDimensions( l, r );  Array1d.AddAA( l.data^, r.data^, res.data^, 0, LEN( res.data ) );
	END Add;

	PROCEDURE "+"*( l, r: Array ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin, l.len );  Add( l, r, res );  RETURN res;
	END "+";

	PROCEDURE Sub*( l, r, res: Array );
	BEGIN
		ArrayXdBytes.CheckEqDimensions( l, r );  Array1d.SubtractAA( l.data^, r.data^, res.data^, 0, LEN( res.data ) );
	END Sub;

	PROCEDURE "-"*( l, r: Array ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin, l.len );  Sub( l, r, res );  RETURN res;
	END "-";

	PROCEDURE Mul*( l, r, res: Array );
	BEGIN
		ArrayXdBytes.CheckEqDimensions( l, r );  Array1d.MultAA( l.data^, r.data^, res.data^, 0, LEN( res.data ) );
	END Mul;

	PROCEDURE Div*( l, r, res: Array );
	BEGIN
		ArrayXdBytes.CheckEqDimensions( l, r );  Array1d.DivAA( l.data^, r.data^, res.data^, 0, LEN( res.data ) );
	END Div;

(*
	PROCEDURE Mod*( l, r, res: Array );
	BEGIN
		ArrayXdBytes.CheckEqDimensions( l, r );  Array1d.ModAA( l.data^, r.data^, res.data^, 0, LEN( res.data ) );
	END Mod;
*)

	PROCEDURE AddAV*( l: Array;  r: Value;  res: Array );
	BEGIN
		Array1d.AddAV( l.data^, r, res.data^, 0, LEN( res.data ) );
	END AddAV;

	PROCEDURE "+"( l: Array;  r: Value ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin, l.len );  AddAV( l, r, res );  RETURN res;
	END "+";

(*
	PROCEDURE "+"( l: Array;  r: IntValue ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin^, l.len^ );  AddAV( l, r, res );  RETURN res;
	END "+";
*)

	PROCEDURE "+"( l: Value;  r: Array ): Array;
	BEGIN
		RETURN r + l
	END "+";

(*
	PROCEDURE "+"( l: IntValue;  r: Array ): Array;
	BEGIN
		RETURN r + l
	END "+";
*)

	PROCEDURE MulAV*( l: Array;  r: Value;  res: Array );
	BEGIN
		Array1d.MultAV( l.data^, r, res.data^, 0, LEN( res.data ) );
	END MulAV;

	PROCEDURE "*"( l: Array;  r: Value ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin, l.len );  MulAV( l, r, res );  RETURN res;
	END "*";

	PROCEDURE "*"( l: Value;  r: Array ): Array;
	BEGIN
		RETURN r * l
	END "*";

(*
	PROCEDURE "*"( l: Array;  r: IntValue ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin^, l.len^ );  MulAV( l, r, res );  RETURN res;
	END "*";

	PROCEDURE "*"( l: IntValue;  r: Array ): Array;
	BEGIN
		RETURN r * l
	END "*";
*)

	PROCEDURE DivAV*( l: Array;  r: Value;  res: Array );
	BEGIN
		Array1d.DivAV( l.data^, r, res.data^, 0, LEN( res.data ) );
	END DivAV;

(*
	PROCEDURE "/"( l: Array;  r: Value ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin^, l.len^ );  DivAV( l, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"( l: Array;  r: IntValue ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin^, l.len^ );  DivAV( l, r, res );  RETURN res;
	END "/";
*)

	PROCEDURE DivVA*( l: Value;  r: Array;  res: Array );
	BEGIN
		Array1d.DivVA( l, r.data^, res.data^, 0, LEN( res.data ) );
	END DivVA;

(*
	PROCEDURE "/"( l: Value;  r: Array ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, r.origin^, r.len^ );  DivVA( l, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"( l: IntValue;  r: Array ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, r.origin^, r.len^ );  DivVA( l, r, res );  RETURN res;
	END "/";
*)

(*
	PROCEDURE ModAV*( l: Array;  r: Value;  res: Array );
	BEGIN
		Array1d.ModAV( l.data^, r, res.data^, 0, LEN( res.data ) );
	END ModAV;

	PROCEDURE "MOD"( l: Array;  r: Value ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin^, l.len^ );  ModAV( l, r, res );  RETURN res;
	END "MOD";

	PROCEDURE ModVA*( l: Value;  r: Array;  res: Array );
	BEGIN
		Array1d.ModVA( l, r.data^, res.data^, 0, LEN( res.data ) );
	END ModVA;

	PROCEDURE "MOD"( l: Value;  r: Array ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, r.origin^, r.len^ );  ModVA( l, r, res );  RETURN res;
	END "MOD";
*)

	PROCEDURE SubAV*( l: Array;  r: Value;  res: Array );
	BEGIN
		Array1d.SubtractAV( l.data^, r, res.data^, 0, LEN( res.data ) );
	END SubAV;

(*
	PROCEDURE "-"( l: Array;  r: Value ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin^, l.len^ );  SubAV( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"( l: Array;  r: IntValue ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, l.origin^, l.len^ );  SubAV( l, r, res );  RETURN res;
	END "-";
*)

	PROCEDURE SubVA*( l: Value;  r: Array;  res: Array );
	BEGIN
		Array1d.SubtractVA( l, r.data^, res.data^, 0, LEN( res.data ) );
	END SubVA;

	PROCEDURE "-"*( l: Value;  r: Array ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, r.origin, r.len );  SubVA( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: IntValue;  r: Array ): Array;
	VAR res: Array;
	BEGIN
		NEW( res, r.origin, r.len );  SubVA( l, r, res );  RETURN res;
	END "-";

(* The procedures needed to register an arbitrary Array so that its instances can be made persistent. *)
	PROCEDURE LoadArray( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR a: Array;  version: SHORTINT;  ver: NbrInt.Integer;
	BEGIN
		R.RawSInt( version );
		IF version = -1 THEN
			obj := NIL  (* Version tag is -1 for NIL. *)
		ELSE
			IF version = VERSION THEN NEW( a, ArrayXdBytes.Array1( 0 ), ArrayXdBytes.Array1( 0 ) );  a.LoadXd( R );  obj := a
					ELSE  (* Encountered an unknown version number. *)
				ver := version;  DataErrors.IntError( ver, "Alien version number encountered." );  HALT( 1000 )
			END
		END
	END LoadArray;

	PROCEDURE StoreArray( W: DataIO.Writer;  obj: OBJECT );
	VAR old: Array;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  old := obj( Array );  old.StoreXd( W, TRUE ) END
	END StoreArray;

	PROCEDURE Register;
	VAR a: Array;
	BEGIN
		NEW( a, ArrayXdBytes.Array1( 0 ), ArrayXdBytes.Array1( 0 ) );  DataIO.PlugIn( a, LoadArray, StoreArray )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of an arbitrary array from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: Array );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( Array )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: Array );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Register
END ArrayXdRe.

