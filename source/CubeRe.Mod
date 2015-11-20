(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE CubeRe;   (** AUTHOR "fof"; PURPOSE "3D matrix object of type Real."; *)

IMPORT SYSTEM, NbrInt, ArrayXdBytes, ArrayXd := ArrayXdRe, NbrRe, DataErrors, NbrRat, CubeInt, CubeRat, DataIO;

CONST
	(** The version number used when reading/writing a cube to file. *)
	VERSION* = 1;

TYPE
	Value* = ArrayXd.Value;  Index* = LONGINT;  Array* = ArrayXd.Array;  IntValue = ArrayXd.IntValue;
	RatValue = NbrRat.Rational;  ArrayC* = ArrayXd.Array3;  Map* = ArrayXd.Map;

	(** Type Cube is DataIO registered, instances of it can therefore be made persistent. *)

	Cube* = OBJECT (ArrayXd.Array)
	VAR lenx-, leny-, lenz-: LONGINT;   (* lenx = nr.Columns, leny = nr.Rows *)
		ox-, oy-, oz-: LONGINT;
		Get-: PROCEDURE {DELEGATE} ( x, y, z: Index ): Value;

		(* override *)
		PROCEDURE AlikeX( ): ArrayXdBytes.Array;
		VAR copy: Cube;
		BEGIN
			NEW( copy, origin[0], len[0], origin[1], len[1], origin[2], len[2] );  RETURN copy;
		END AlikeX;

		PROCEDURE NewRangeX( neworigin, newlen:ArrayXdBytes.IndexArray;  copydata: BOOLEAN );
		BEGIN
			IF LEN( newlen ) # 3 THEN HALT( 1001 ) END;
			NewRangeX^( neworigin, newlen, copydata );
		END NewRangeX;

		PROCEDURE ValidateCache;
		BEGIN
			ValidateCache^;
			IF dim # 3 THEN HALT( 100 ) END;
			lenx := len[0];  leny := len[1];  lenz := len[2];  ox := origin[0];  oy := origin[1];  oz := origin[2];
		END ValidateCache;

		PROCEDURE SetBoundaryCondition*( c: SHORTINT );   (* called by new, load and directly *)
		BEGIN
			SetBoundaryCondition^( c );
			CASE c OF
			ArrayXd.StrictBoundaryC:
					Get := Get3;
			| ArrayXd.AbsorbingBoundaryC:
					Get := Get3BAbsorbing;
			| ArrayXd.PeriodicBoundaryC:
					Get := Get3BPeriodic;
			| ArrayXd.SymmetricOnBoundaryC:
					Get := Get3BSymmetricOnB
			| ArrayXd.SymmetricOffBoundaryC:
					Get := Get3BSymmetricOffB
			| ArrayXd.AntisymmetricOnBoundaryC:
					Get := Get3BAntisymmetricOnB
			| ArrayXd.AntisymmetricOffBoundaryC:
					Get := Get3BAntisymmetricOffB
			END;
		END SetBoundaryCondition;

	(** new *)
		PROCEDURE & New*( ox, w, oy, h, oz, d: LONGINT );
		BEGIN
			NewXdB( ArrayXdBytes.Array3( ox, oy, oz ), ArrayXdBytes.Array3( w, h, d ) );
		END New;

		PROCEDURE Alike*( ): Cube;
		VAR copy: ArrayXdBytes.Array;
		BEGIN
			copy := AlikeX();  RETURN copy( Cube );
		END Alike;

		PROCEDURE NewRange*( ox, w, oy, h, oz, d: LONGINT;  copydata: BOOLEAN );
		BEGIN
			IF (w # len[0]) OR (h # len[1]) OR (d # len[2]) OR (ox # origin[0]) OR (oy # origin[1]) OR (oz # origin[2]) THEN
				NewRangeX^( ArrayXdBytes.Array3( ox, oy, oz ), ArrayXdBytes.Array3( w, h, d ), copydata )
			END;
		END NewRange;

		PROCEDURE Copy*( ): Cube;
		VAR res: ArrayXdBytes.Array;
		BEGIN
			res := CopyX();  RETURN res( Cube );
		END Copy;

		PROCEDURE Set*( x, y, z: Index;  v: Value );
		BEGIN
			ArrayXdBytes.Set3( SELF, x, y, z, v );
		END Set;

	(** copy methods using the current boundary condition SELF.bc*)
		PROCEDURE CopyToVec*( dest: Array;  dim: Index;  srcx, srcy, srcz, destx, len: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 1) THEN HALT( 1003 ) END;
			slen := ArrayXdBytes.Index3( 1, 1, 1 );  slen[dim] := len;
			CopyToArray( dest, ArrayXdBytes.Index3( srcx, srcy, srcz ), slen, ArrayXdBytes.Index1( destx ),
								   ArrayXdBytes.Index1( len ) );
		END CopyToVec;

		PROCEDURE CopyToMtx*( dest: Array;  dimx, dimy: Index;  srcx, srcy, srcz, destx, desty, lenx, leny: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 2) OR (dimx >= dimy) THEN HALT( 1005 ) END;
			slen := ArrayXdBytes.Index3( 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;
			CopyToArray( dest, ArrayXdBytes.Index3( srcx, srcy, srcz ), slen, ArrayXdBytes.Index2( destx, desty ),
								   ArrayXdBytes.Index2( lenx, leny ) );
		END CopyToMtx;

		PROCEDURE CopyToCube*( dest: Array;  srcx, srcy, srcz, destx, desty, destz, lenx, leny, lenz: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 3) THEN HALT( 1005 ) END;
			slen := ArrayXdBytes.Index3( lenx, leny, lenz );
			CopyToArray( dest, ArrayXdBytes.Index3( srcx, srcy, srcz ), slen, ArrayXdBytes.Index3( destx, desty, destz ), slen );
		END CopyToCube;

		PROCEDURE CopyToHCube*( dest: Array;  dimx, dimy, dimz: Index;
													  srcx, srcy, srcz, destx, desty, destz, destt, lenx, leny, lenz: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 4) OR (dimx >= dimy) OR (dimy >= dimz) THEN HALT( 1005 ) END;
			slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;  slen[dimz] := lenz;
			CopyToArray( dest, ArrayXdBytes.Index3( srcx, srcy, srcz ), ArrayXdBytes.Index3( lenx, leny, lenz ),
								   ArrayXdBytes.Index4( destx, desty, destz, destt ), slen );
		END CopyToHCube;

		PROCEDURE CopyTo1dArray*( VAR dest: ARRAY OF Value;  sx, sy, sz, slenx, sleny, slenz: Index;  dpos, dlen: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 1, ArrayXdBytes.Index1( 0 ), ArrayXdBytes.Index1( LEN( dest ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index3( sx, sy, sz ),
																  ArrayXdBytes.Index3( slenx, sleny, slenz ), ArrayXdBytes.Index1( dpos ),
																  ArrayXdBytes.Index1( dlen ) );
		END CopyTo1dArray;

		PROCEDURE CopyTo2dArray*( VAR dest: ARRAY OF ARRAY OF Value;  sx, sy, sz, slenx, sleny, slenz: Index;
													   dposx, dposy, dlenx, dleny: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( dest, 1 ), LEN( dest, 0 ) ),
																			  SIZEOF( Value ), ADDRESSOF( dest[0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index3( sx, sy, sz ),
																  ArrayXdBytes.Index3( slenx, sleny, slenz ), ArrayXdBytes.Index2( dposx, dposy ),
																  ArrayXdBytes.Index2( dlenx, dleny ) );
		END CopyTo2dArray;

		PROCEDURE CopyTo3dArray*( VAR dest: ARRAY OF ARRAY OF ARRAY OF Value;  sx, sy, sz, slenx, sleny, slenz: Index;
													   dposx, dposy, dposz, dlenx, dleny, dlenz: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																			  ArrayXdBytes.Index3( LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0, 0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index3( sx, sy, sz ),
																  ArrayXdBytes.Index3( slenx, sleny, slenz ),
																  ArrayXdBytes.Index3( dposx, dposy, dposz ),
																  ArrayXdBytes.Index3( dlenx, dleny, dlenz ) );
		END CopyTo3dArray;

		PROCEDURE CopyTo4dArray*( VAR dest: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;  sx, sy, sz, slenx, sleny, slenz: Index;
													   dposx, dposy, dposz, dpost, dlenx, dleny, dlenz, dlent: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																			  ArrayXdBytes.Index4( LEN( dest, 3 ), LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0, 0, 0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index3( sx, sy, sz ),
																  ArrayXdBytes.Index3( slenx, sleny, slenz ),
																  ArrayXdBytes.Index4( dposx, dposy, dposz, dpost ),
																  ArrayXdBytes.Index4( dlenx, dleny, dlenz, dlent ) );
		END CopyTo4dArray;

	(** copy from without boundary conditions *)
		PROCEDURE CopyFrom1dArray*( VAR src: ARRAY OF Value;  spos, slen: Index;  dx, dy, dz, dlenx, dleny, dlenz: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 1, ArrayXdBytes.Index1( 0 ), ArrayXdBytes.Index1( LEN( src ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index1( spos ), ArrayXdBytes.Index1( slen ),
																			   ArrayXdBytes.Index3( dx, dy, dz ),
																			   ArrayXdBytes.Index3( dlenx, dleny, dlenz ) );
		END CopyFrom1dArray;

		PROCEDURE CopyFrom2dArray*( VAR src: ARRAY OF ARRAY OF Value;  sposx, spoxy, slenx, sleny: Index;
														    dx, dy, dz, dlenx, dleny, dlenz: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( src, 1 ), LEN( src, 0 ) ),
																			  SIZEOF( Value ), ADDRESSOF( src[0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index2( sposx, spoxy ),
																			   ArrayXdBytes.Index2( slenx, sleny ), ArrayXdBytes.Index3( dx, dy, dz ),
																			   ArrayXdBytes.Index3( dlenx, dleny, dlenz ) );
		END CopyFrom2dArray;

		PROCEDURE CopyFrom3dArray*( VAR src: ARRAY OF ARRAY OF ARRAY OF Value;  sposx, spoxy, sposz, slenx, sleny, slenz: Index;
														    dx, dy, dz, dlenx, dleny, dlenz: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																			  ArrayXdBytes.Index3( LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0, 0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index3( sposx, spoxy, sposz ),
																			   ArrayXdBytes.Index3( slenx, sleny, slenz ),
																			   ArrayXdBytes.Index3( dx, dy, dz ),
																			   ArrayXdBytes.Index3( dlenx, dleny, dlenz ) );
		END CopyFrom3dArray;

		PROCEDURE CopyFrom4dArray*( VAR src: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;
														    sposx, spoxy, sposz, spost, slenx, sleny, slenz, slent: Index;
														    dx, dy, dz, dlenx, dleny, dlenz: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																			  ArrayXdBytes.Index4( LEN( src, 3 ), LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0, 0, 0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index4( sposx, spoxy, sposz, spost ),
																			   ArrayXdBytes.Index4( slenx, sleny, slenz, slent ),
																			   ArrayXdBytes.Index3( dx, dy, dz ),
																			   ArrayXdBytes.Index3( dlenx, dleny, dlenz ) );
		END CopyFrom4dArray;

	END Cube;

	PROCEDURE ":="*( VAR l: Cube;  VAR r: ARRAY OF ARRAY OF ARRAY OF Value );
	BEGIN
		(*	IF r = NIL THEN l := NIL;  RETURN END;  *)
		IF l = NIL THEN NEW( l, 0, LEN( r, 2 ), 0, LEN( r, 1 ), 0, LEN( r, 0 ) );  ELSE l.NewRange( 0, LEN( r, 2 ), 0, LEN( r, 1 ), 0, LEN( r, 0 ), FALSE );  END;
		ArrayXdBytes.CopyMemoryToArrayPart( ADDRESSOF( r[0, 0, 0] ), l, LEN( r, 0 ) * LEN( r, 1 ) * LEN( r, 2 ), NIL , NIL );
	END ":=";

	PROCEDURE ":="*( VAR l: Cube;  r: CubeInt.Cube );
	VAR i, last: LONGINT;
	BEGIN
		IF r = NIL THEN l := NIL ELSE
			IF l = NIL THEN NEW( l, r.origin[0], r.len[0], r.origin[1], r.len[1], r.origin[2], r.len[2] );  END;
			last := LEN( r.data ) - 1;
			FOR i := 0 TO last DO l.data[i] := r.data[i];  END;
		END;
	END ":=";

	PROCEDURE ":="*( VAR l: Cube;  r: CubeRat.Cube );
	VAR i, last: LONGINT;
	BEGIN
		IF r = NIL THEN l := NIL ELSE
			IF l = NIL THEN NEW( l, r.origin[0], r.len[0], r.origin[1], r.len[1], r.origin[2], r.len[2] );  END;
			last := LEN( r.data ) - 1;
			FOR i := 0 TO last DO l.data[i] := r.data[i];  END;
		END;
	END ":=";

	PROCEDURE ":="*( VAR l: Cube;  r: Value );
	BEGIN
		IF l # NIL THEN ArrayXd.Fill( l, r );  END;
	END ":=";

	PROCEDURE ":="*( VAR l: Cube;  r: RatValue );
	VAR r1: Value;
	BEGIN
		r1 := r;  l := r1;
	END ":=";

	PROCEDURE ":="*( VAR l: Cube;  r: IntValue );
	VAR r1: Value;
	BEGIN
		r1 := r;  l := r1;
	END ":=";

	PROCEDURE "+"*( l, r: Cube ): Cube;
	VAR res: Cube;
	BEGIN
		res := l.Alike();  ArrayXd.Add( l, r, res );  RETURN res;
	END "+";

	PROCEDURE "-"*( l, r: Cube ): Cube;
	VAR res: Cube;
	BEGIN
		res := l.Alike();  ArrayXd.Sub( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "+"*( l: Cube;  r: Value ): Cube;
	VAR res: Cube;
	BEGIN
		res := l.Alike();  ArrayXd.AddAV( l, r, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Cube;  r: IntValue ): Cube;
	VAR res: Cube;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.AddAV( l, r1, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Cube;  r: RatValue ): Cube;
	VAR res: Cube;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.AddAV( l, r1, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Value;  r: Cube ): Cube;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "+"*( l: RatValue;  r: Cube ): Cube;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "+"*( l: IntValue;  r: Cube ): Cube;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "-"*( l: Cube;  r: Value ): Cube;
	VAR res: Cube;
	BEGIN
		res := l.Alike();  ArrayXd.SubAV( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Cube;  r: RatValue ): Cube;
	VAR res: Cube;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.SubAV( l, r1, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Cube;  r: IntValue ): Cube;
	VAR res: Cube;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.SubAV( l, r1, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Value;  r: Cube ): Cube;
	VAR res: Cube;
	BEGIN
		res := r.Alike();  ArrayXd.SubVA( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: RatValue;  r: Cube ): Cube;
	VAR res: Cube;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.SubVA( l1, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: IntValue;  r: Cube ): Cube;
	VAR res: Cube;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.SubVA( l1, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Cube ): Cube;
	BEGIN
		RETURN 0 - l;
	END "-";

	PROCEDURE "*"*( l: Cube;  r: Value ): Cube;
	VAR res: Cube;
	BEGIN
		res := l.Alike();  ArrayXd.MulAV( l, r, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Cube;  r: RatValue ): Cube;
	VAR res: Cube;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.MulAV( l, r1, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Cube;  r: IntValue ): Cube;
	VAR res: Cube;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.MulAV( l, r1, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Value;  r: Cube ): Cube;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "*"*( l: RatValue;  r: Cube ): Cube;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "*"*( l: IntValue;  r: Cube ): Cube;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "/"*( l: Cube;  r: Value ): Cube;
	VAR res: Cube;
	BEGIN
		res := l.Alike();  ArrayXd.DivAV( l, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: Cube;  r: RatValue ): Cube;
	VAR res: Cube;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.DivAV( l, r1, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: Cube;  r: IntValue ): Cube;
	VAR res: Cube;  r1: Value;
	BEGIN
		res := l.Alike();  r1 := r;  ArrayXd.DivAV( l, r1, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: Value;  r: Cube ): Cube;
	VAR res: Cube;
	BEGIN
		res := r.Alike();  ArrayXd.DivVA( l, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: RatValue;  r: Cube ): Cube;
	VAR res: Cube;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.DivVA( l1, r, res );  RETURN res;
	END "/";

	PROCEDURE "/"*( l: IntValue;  r: Cube ): Cube;
	VAR res: Cube;  l1: Value;
	BEGIN
		res := r.Alike();  l1 := l;  ArrayXd.DivVA( l1, r, res );  RETURN res;
	END "/";

(* The procedures needed to register type Cube so that its instances can be made persistent. *)
	PROCEDURE LoadCube( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR a: Cube;  version: SHORTINT;  ver: NbrInt.Integer;
	BEGIN
		R.RawSInt( version );
		IF version = -1 THEN
			obj := NIL  (* Version tag is -1 for NIL. *)
		ELSIF version = VERSION THEN NEW( a, 0, 0, 0, 0, 0, 0 );  a.Read( R );  obj := a
		ELSE ver := version;  DataErrors.IntError( ver, "Alien version number encountered." );  HALT( 1000 )
		END
	END LoadCube;

	PROCEDURE StoreCube( W: DataIO.Writer;  obj: OBJECT );
	VAR a: Cube;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  a := obj( Cube );  a.Write( W ) END
	END StoreCube;

	PROCEDURE Register;
	VAR a: Cube;
	BEGIN
		NEW( a, 0, 0, 0, 0, 0, 0 );  DataIO.PlugIn( a, LoadCube, StoreCube )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of Cube from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: Cube );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( Cube )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: Cube );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Register
END CubeRe.
