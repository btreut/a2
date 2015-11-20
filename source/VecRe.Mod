(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE VecRe;   (** AUTHOR "fof"; PURPOSE "Vector objects of type Real."; *)

IMPORT SYSTEM, NbrInt, ArrayXdBytes, ArrayXd := ArrayXdRe, Array1d := Array1dRe, NbrRat, NbrRe, DataErrors, DataIO;

CONST
	(** The version used when reading/writing a vector to file. *)
	VERSION* = 1;

TYPE
	Value* = ArrayXd.Value;  Index* = LONGINT;  IntValue = ArrayXd.IntValue;  RatValue = NbrRat.Rational;
	Array* = ArrayXd.Array1;  Map* = ArrayXd.Map;

	(** Class Vector has been DataIO registered. *)
	Vector* = OBJECT (ArrayXd.Array)
	VAR lenx-: LONGINT;
		ox-: LONGINT;
		Get-: PROCEDURE {DELEGATE} ( x: Index ): Value;

		(** overrride *)
		PROCEDURE AlikeX( ): ArrayXdBytes.Array;
		VAR copy: Vector;
		BEGIN
			NEW( copy, origin[0], len[0] );  RETURN copy;
		END AlikeX;

		PROCEDURE NewRangeX( neworigin, newlen: ArrayXdBytes.IndexArray;  copydata: BOOLEAN );
		BEGIN
			IF LEN( newlen ) # 1 THEN HALT( 1001 ) END;
			NewRangeX^( neworigin, newlen, copydata );
		END NewRangeX;

		PROCEDURE ValidateCache;
		BEGIN
			ValidateCache^;
			IF dim # 1 THEN HALT( 100 ) END;
			lenx := len[0];  ox := origin[0];
		END ValidateCache;

		PROCEDURE SetBoundaryCondition*( c: SHORTINT );   (* called by new, load and directly *)
		BEGIN
			SetBoundaryCondition^( c );
			CASE c OF
			ArrayXd.StrictBoundaryC:
					Get := Get1;
			| ArrayXd.AbsorbingBoundaryC:
					Get := Get1BAbsorbing;
			| ArrayXd.PeriodicBoundaryC:
					Get := Get1BPeriodic;
			| ArrayXd.SymmetricOnBoundaryC:
					Get := Get1BSymmetricOnB
			| ArrayXd.SymmetricOffBoundaryC:
					Get := Get1BSymmetricOffB
			| ArrayXd.AntisymmetricOnBoundaryC:
					Get := Get1BAntisymmetricOnB
			| ArrayXd.AntisymmetricOffBoundaryC:
					Get := Get1BAntisymmetricOffB
			END;
		END SetBoundaryCondition;

	(** new *)
		PROCEDURE & New*( ox, w: LONGINT );   (** ox is the offset and w is the width (or length) of the array. *)
		BEGIN
			NewXdB( ArrayXdBytes.Array1( ox ), ArrayXdBytes.Array1( w ) );
		END New;

		PROCEDURE NewRange*( ox, w: LONGINT;  copydata: BOOLEAN );
		BEGIN
			IF (w # len[0]) OR (ox # origin[0]) THEN
				NewRangeX^( ArrayXdBytes.Array1( ox ), ArrayXdBytes.Array1( w ), copydata );
			END;
		END NewRange;

		PROCEDURE Alike*( ): Vector;
		VAR copy: ArrayXdBytes.Array;
		BEGIN
			copy := AlikeX();  RETURN copy( Vector );
		END Alike;

		PROCEDURE Copy*( ): Vector;
		VAR res: ArrayXdBytes.Array;
		BEGIN
			res := CopyX();  RETURN res( Vector );
		END Copy;

		PROCEDURE Set*( x: Index;  v: Value );
		BEGIN
			ArrayXdBytes.Set1( SELF, x, v );
		END Set;

	(** vec[beginAtRow] := array[0] ... vec[beginAtRow+LEN(array)-1] := array[LEN(array)-1] *)
		PROCEDURE SetArray*( beginAtRow: Index;  VAR array: ARRAY OF Value );
		BEGIN
			ArrayXdBytes.CopyMemoryToArrayPart( ADDRESSOF( array[0] ), SELF, LEN( array ), ArrayXdBytes.Index1( beginAtRow ),
																			 NIL );
		END SetArray;

		PROCEDURE GetArray*( beginAtRow: Index;  VAR array: ARRAY OF Value );
		BEGIN
			ArrayXdBytes.CopyArrayPartToMemory( SELF, ADDRESSOF( array[0] ), ArrayXdBytes.Index1( beginAtRow ), NIL ,
																			 LEN( array ) );
		END GetArray;

	(** Exchanges values held by vec[row1] and vec[row2] *)
		PROCEDURE Swap*( row1, row2: Index );
		BEGIN
			ToggleElements( 0, row1, row2 );
		END Swap;

	(** Rearranges entries so that vec[0] # vec[1] # ... # vec[len-1] *)
		PROCEDURE Sort*;
		BEGIN {EXCLUSIVE}
			Array1d.Sort( data^, 0, len[0] );
		END Sort;

		PROCEDURE Insert*( x: Index;  v: Value );
		BEGIN
			InsertElements( 0, x, 1 );  ArrayXdBytes.Set1( SELF, x, v );
		END Insert;

		PROCEDURE Delete*( x: Index );
		BEGIN
			DeleteElements( 0, x, 1 );
		END Delete;

	(** copy methods using the current boundary condition SELF.bc*)
		PROCEDURE CopyToVec*( dest: ArrayXd.Array;  srcx, destx, len: Index );
		BEGIN
			IF (dest.dim # 1) THEN HALT( 1001 ) END;
			CopyToArray( dest, ArrayXdBytes.Index1( srcx ), ArrayXdBytes.Index1( len ), ArrayXdBytes.Index1( destx ),
								   ArrayXdBytes.Index1( len ) );
		END CopyToVec;

		PROCEDURE CopyToMtx*( dest: ArrayXd.Array;  dim: Index;  srcx, destx, desty, len: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 2) THEN HALT( 1002 ) END;
			slen := ArrayXdBytes.Index2( 1, 1 );  slen[dim] := len;
			CopyToArray( dest, ArrayXdBytes.Index1( srcx ), ArrayXdBytes.Index1( len ), ArrayXdBytes.Index2( destx, desty ),
								   slen );
		END CopyToMtx;

		PROCEDURE CopyToCube*( dest: ArrayXd.Array;  dim: Index;  srcx, destx, desty, destz, len: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 3) THEN HALT( 1002 ) END;
			slen := ArrayXdBytes.Index3( 1, 1, 1 );  slen[dim] := len;
			CopyToArray( dest, ArrayXdBytes.Index1( srcx ), ArrayXdBytes.Index1( len ),
								   ArrayXdBytes.Index3( destx, desty, destz ), slen );
		END CopyToCube;

		PROCEDURE CopyToHCube*( dest: ArrayXd.Array;  dim: Index;  srcx, destx, desty, destz, destt, len: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 4) THEN HALT( 1002 ) END;
			slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dim] := len;
			CopyToArray( dest, ArrayXdBytes.Index1( srcx ), ArrayXdBytes.Index1( len ),
								   ArrayXdBytes.Index4( destx, desty, destz, destt ), slen );
		END CopyToHCube;

		PROCEDURE CopyTo1dArray*( VAR dest: ARRAY OF Value;  srcpos, srclen: Index;  dpos, dlen: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 1, ArrayXdBytes.Index1( 0 ), ArrayXdBytes.Index1( LEN( dest ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index1( srcpos ), ArrayXdBytes.Index1( srclen ),
																  ArrayXdBytes.Index1( dpos ), ArrayXdBytes.Index1( dlen ) );
		END CopyTo1dArray;

		PROCEDURE CopyTo2dArray*( VAR dest: ARRAY OF ARRAY OF Value;  srcpos, srclen: Index;  dposx, dposy, dlenx, dleny: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( dest, 1 ), LEN( dest, 0 ) ),
																			  SIZEOF( Value ), ADDRESSOF( dest[0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index1( srcpos ), ArrayXdBytes.Index1( srclen ),
																  ArrayXdBytes.Index2( dposx, dposy ), ArrayXdBytes.Index2( dlenx, dleny ) );
		END CopyTo2dArray;

		PROCEDURE CopyTo3dArray*( VAR dest: ARRAY OF ARRAY OF ARRAY OF Value;  srcpos, srclen: Index;
													   dposx, dposy, dposz, dlenx, dleny, dlenz: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																			  ArrayXdBytes.Index3( LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0, 0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index1( srcpos ), ArrayXdBytes.Index1( srclen ),
																  ArrayXdBytes.Index3( dposx, dposy, dposz ),
																  ArrayXdBytes.Index3( dlenx, dleny, dlenz ) );
		END CopyTo3dArray;

		PROCEDURE CopyTo4dArray*( VAR dest: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;  srcpos, srclen: Index;
													   dposx, dposy, dposz, dpost, dlenx, dleny, dlenz, dlent: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																			  ArrayXdBytes.Index4( LEN( dest, 3 ), LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0, 0, 0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index1( srcpos ), ArrayXdBytes.Index1( srclen ),
																  ArrayXdBytes.Index4( dposx, dposy, dposz, dpost ),
																  ArrayXdBytes.Index4( dlenx, dleny, dlenz, dlent ) );
		END CopyTo4dArray;

	(** copy from without boundary conditions *)
		PROCEDURE CopyFrom1dArray*( VAR src: ARRAY OF Value;  spos, slen: Index;  destpos, destlen: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 1, ArrayXdBytes.Index1( 0 ), ArrayXdBytes.Index1( LEN( src ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index1( spos ), ArrayXdBytes.Index1( slen ),
																			   ArrayXdBytes.Index1( destpos ), ArrayXdBytes.Index1( destlen ) );
		END CopyFrom1dArray;

		PROCEDURE CopyFrom2dArray*( VAR src: ARRAY OF ARRAY OF Value;  sposx, spoxy, slenx, sleny: Index;
														    destpos, destlen: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( src, 1 ), LEN( src, 0 ) ),
																			  SIZEOF( Value ), ADDRESSOF( src[0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index2( sposx, spoxy ),
																			   ArrayXdBytes.Index2( slenx, sleny ), ArrayXdBytes.Index1( destpos ),
																			   ArrayXdBytes.Index1( destlen ) );
		END CopyFrom2dArray;

		PROCEDURE CopyFrom3dArray*( VAR src: ARRAY OF ARRAY OF ARRAY OF Value;  sposx, spoxy, sposz, slenx, sleny, slenz: Index;
														    destpos, destlen: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																			  ArrayXdBytes.Index3( LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0, 0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index3( sposx, spoxy, sposz ),
																			   ArrayXdBytes.Index3( slenx, sleny, slenz ), ArrayXdBytes.Index1( destpos ),
																			   ArrayXdBytes.Index1( destlen ) );
		END CopyFrom3dArray;

		PROCEDURE CopyFrom4dArray*( VAR src: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;
														    sposx, spoxy, sposz, spost, slenx, sleny, slenz, slent: Index;  destpos, destlen: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																			  ArrayXdBytes.Index4( LEN( src, 3 ), LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0, 0, 0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index4( sposx, spoxy, sposz, spost ),
																			   ArrayXdBytes.Index4( slenx, sleny, slenz, slent ),
																			   ArrayXdBytes.Index1( destpos ), ArrayXdBytes.Index1( destlen ) );
		END CopyFrom4dArray;

	END Vector;

	PROCEDURE ":="*( VAR l: Vector;  VAR r: ARRAY OF Value );
	BEGIN
		(*		IF r = NIL THEN l := NIL;  RETURN END;  *)
		IF l = NIL THEN NEW( l, 0, LEN( r, 0 ) ) ELSE l.NewRange( 0, LEN( r, 0 ), FALSE );  END;
		ArrayXdBytes.CopyMemoryToArray( ADDRESSOF( r[0] ), l, LEN( r, 0 ) );
	END ":=";

	PROCEDURE ":="*( VAR l: Vector;  r: Value );
	BEGIN
		IF l # NIL THEN ArrayXd.Fill( l, r );  END;
	END ":=";

	PROCEDURE ":="*( VAR l: Vector;  r: RatValue );
	VAR r1: Value;
	BEGIN
		r1 := r;  l := r1;
	END ":=";

	PROCEDURE ":="*( VAR l: Vector;  r: IntValue );
	VAR r1: Value;
	BEGIN
		r1 := r;  l := r1;
	END ":=";

	PROCEDURE "+"*( l, r: Vector ): Vector;
	VAR res: Vector;
	BEGIN
		res := l.Alike();  ArrayXd.Add( l, r, res );  RETURN res;
	END "+";

	PROCEDURE "-"*( l, r: Vector ): Vector;
	VAR res: Vector;
	BEGIN
		res := l.Alike();  ArrayXd.Sub( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "+"*( l: Vector;  r: Value ): Vector;
	VAR res: Vector;
	BEGIN
		res := l.Alike();  ArrayXd.AddAV( l, r, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Vector;  r: RatValue ): Vector;
	VAR res: Vector;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.AddAV( l, r1, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Vector;  r: IntValue ): Vector;
	VAR res: Vector;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.AddAV( l, r1, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Value;  r: Vector ): Vector;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "+"*( l: RatValue;  r: Vector ): Vector;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "+"*( l: IntValue;  r: Vector ): Vector;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "-"*( l: Vector;  r: Value ): Vector;
	VAR res: Vector;
	BEGIN
		res := l.Alike();  ArrayXd.SubAV( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Vector;  r: RatValue ): Vector;
	VAR res: Vector;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.SubAV( l, r1, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Vector;  r: IntValue ): Vector;
	VAR res: Vector;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.SubAV( l, r1, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Value;  r: Vector ): Vector;
	VAR res: Vector;
	BEGIN
		res := r.Alike();  ArrayXd.SubVA( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: RatValue;  r: Vector ): Vector;
	VAR res: Vector;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.SubVA( l1, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: IntValue;  r: Vector ): Vector;
	VAR res: Vector;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.SubVA( l1, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Vector ): Vector;
	BEGIN
		RETURN 0 - l;
	END "-";

	PROCEDURE "*"*( l: Vector;  r: Value ): Vector;
	VAR res: Vector;
	BEGIN
		res := l.Alike();  ArrayXd.MulAV( l, r, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Vector;  r: RatValue ): Vector;
	VAR res: Vector;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.MulAV( l, r1, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Vector;  r: IntValue ): Vector;
	VAR res: Vector;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.MulAV( l, r1, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Value;  r: Vector ): Vector;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "*"*( l: RatValue;  r: Vector ): Vector;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "*"*( l: IntValue;  r: Vector ): Vector;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "/"*( l: Vector;  r: Value ): Vector;
	VAR res: Vector;
	BEGIN
		res := l.Alike();  ArrayXd.DivAV( l, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: Vector;  r: RatValue ): Vector;
	VAR res: Vector;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.DivAV( l, r1, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: Vector;  r: IntValue ): Vector;
	VAR res: Vector;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.DivAV( l, r1, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: Value;  r: Vector ): Vector;
	VAR res: Vector;
	BEGIN
		res := r.Alike();  ArrayXd.DivVA( l, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: RatValue;  r: Vector ): Vector;
	VAR res: Vector;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.DivVA( l1, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: IntValue;  r: Vector ): Vector;
	VAR res: Vector;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.DivVA( l1, r, res );  RETURN res;
	END "/";

(*

	PROCEDURE "MOD"*( l: Vector;  r: Value ): Vector;
	VAR res: Vector;
	BEGIN
		res := l.Alike();  ArrayXd.ModAV( l, r, res );  RETURN res;
	END "MOD";

	PROCEDURE "MOD"*( l: Value;  r: Vector ): Vector;
	VAR res: Vector;
	BEGIN
		res := r.Alike();  ArrayXd.ModVA( l, r, res );  RETURN res;
	END "MOD";
*)

	PROCEDURE "*"*( l, r: Vector ): Value;   (* scalar product *)
	(*! replace by operation on memory *)
	VAR res: Value;  i: LONGINT;
	BEGIN
		ArrayXdBytes.CheckEqDimensions( l, r );  res := 0;
		FOR i := l.ox TO l.ox + l.lenx - 1 DO res := res + l.Get( i ) * r.Get( i );  END;
		RETURN res;
	END "*";

	PROCEDURE L1Norm*( l: Vector ): Value;
	(*! todo: replace by operation on memory *)
	VAR norm: Value;  i: LONGINT;
	BEGIN
		norm := 0;
		FOR i := l.ox TO l.ox + l.lenx - 1 DO norm := norm + ABS( l.Get( i ) );  END;
		RETURN norm;
	END L1Norm;

	PROCEDURE L2Norm*( l: Vector ): Value;
	(*! todo: replace by operation on memory *)
	VAR norm,cur: Value;  i: LONGINT;
	BEGIN
		norm := 0;
		FOR i := l.ox TO l.ox + l.lenx - 1 DO cur := l.Get( i ); norm := norm + cur*cur;  END;
		RETURN NbrRe.Sqrt(norm);
	END L2Norm;


	PROCEDURE LInftyNorm*( l: Vector ): Value;
	(*! todo: replace by operation on memory *)
	VAR norm, abs: Value;  i: LONGINT;
	BEGIN
		norm := ABS( l.Get( l.ox ) );
		FOR i := l.ox + 1 TO l.ox + l.lenx - 1 DO
			abs := ABS( l.Get( i ) );
			IF abs > norm THEN norm := abs END;
		END;
		RETURN norm;
	END LInftyNorm;

(* The procedures needed to register type Vector so that its instances can be made persistent. *)
	PROCEDURE LoadVector( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR a: Vector;  version: SHORTINT;  ver: NbrInt.Integer;
	BEGIN
		R.RawSInt( version );
		IF version = -1 THEN
			obj := NIL  (* Version tag is -1 for NIL. *)
		ELSE
			IF version = VERSION THEN NEW( a, 0, 0 );  a.Read( R );  obj := a
					ELSE  (* Encountered an unknown version number. *)
				ver := version;  DataErrors.IntError( ver, "Alien version number encountered." );  HALT( 1000 )
			END
		END
	END LoadVector;

	PROCEDURE StoreVector( W: DataIO.Writer;  obj: OBJECT );
	VAR a: Vector;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  a := obj( Vector );  a.Write( W ) END
	END StoreVector;

	PROCEDURE Register;
	VAR a: Vector;
	BEGIN
		NEW( a, 0, 0 );  DataIO.PlugIn( a, LoadVector, StoreVector )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of Vector from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: Vector );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( Vector )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: Vector );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Register
END VecRe.
