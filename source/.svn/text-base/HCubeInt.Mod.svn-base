(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE HCubeInt;   (** AUTHOR "fof"; PURPOSE "3D matrix object of type Integer."; *)

IMPORT SYSTEM, NbrInt, ArrayXdBytes, ArrayXd := ArrayXdInt, DataErrors, DataIO;

CONST
	(** The version number used when reading/writing a hypercube to file. *)
	VERSION* = 1;

TYPE
	Value* = ArrayXd.Value;  Index* = LONGINT;  Array* = ArrayXd.Array;  Map* = ArrayXd.Map;  ArrayH* = ArrayXd.Array4;

	(** Type HCube is DataIO registered, instances of it can therefore be made persistent. *)

	HCube* = OBJECT (ArrayXd.Array)
	VAR lenx-, leny-, lenz-, lent-: LONGINT;   (* lenx = nr.Columns, leny = nr.Rows *)
		ox-, oy-, oz-, ot-: LONGINT;
		Get-: PROCEDURE {DELEGATE} ( x, y, z, t: Index ): Value;

		(** override *)
		PROCEDURE AlikeX( ): ArrayXdBytes.Array;
		VAR copy: HCube;
		BEGIN
			NEW( copy, origin[0], len[0], origin[1], len[1], origin[2], len[2], origin[3], len[3] );  RETURN copy;
		END AlikeX;

		PROCEDURE NewRangeX( neworigin, newlen: ArrayXdBytes.IndexArray;  copydata: BOOLEAN );
		BEGIN
			IF LEN( newlen ) # 4 THEN HALT( 1001 ) END;
			NewRangeX^( neworigin, newlen, copydata );
		END NewRangeX;

		PROCEDURE ValidateCache;
		BEGIN
			ValidateCache^;
			IF dim # 4 THEN HALT( 100 ) END;

			lenx := len[0];  leny := len[1];  lenz := len[2];  lent := len[3];  ox := origin[0];  oy := origin[1];  oz := origin[2];
			ot := origin[2];
		END ValidateCache;

		PROCEDURE SetBoundaryCondition*( c: SHORTINT );   (* called by new, load and directly *)
		BEGIN
			SetBoundaryCondition^( c );
			CASE c OF
			ArrayXd.StrictBoundaryC:
					Get := Get4;
			| ArrayXd.AbsorbingBoundaryC:
					Get := Get4BAbsorbing;
			| ArrayXd.PeriodicBoundaryC:
					Get := Get4BPeriodic;
			| ArrayXd.SymmetricOnBoundaryC:
					Get := Get4BSymmetricOnB
			| ArrayXd.SymmetricOffBoundaryC:
					Get := Get4BSymmetricOffB
			| ArrayXd.AntisymmetricOnBoundaryC:
					Get := Get4BAntisymmetricOnB
			| ArrayXd.AntisymmetricOffBoundaryC:
					Get := Get4BAntisymmetricOffB
			END;
		END SetBoundaryCondition;

	(** new *)
		PROCEDURE & New*( ox, w, oy, h, oz, d, ot, td: LONGINT );
		BEGIN
			NewXdB( ArrayXdBytes.Array4( ox, oy, oz, ot ), ArrayXdBytes.Array4( w, h, d, td ) );
		END New;

		PROCEDURE Alike*( ): HCube;
		VAR copy: ArrayXdBytes.Array;
		BEGIN
			copy := AlikeX();  RETURN copy( HCube );
		END Alike;

		PROCEDURE NewRange*( ox, w, oy, h, oz, d, ot, td: LONGINT;  copydata: BOOLEAN );
		BEGIN
			IF (w # len[0]) OR (h # len[1]) OR (d # len[2]) OR (td # len[3]) OR (ox # origin[0]) OR (oy # origin[1]) OR
			    (oz # origin[2]) OR (ot # origin[3]) THEN
				NewRangeX^( ArrayXdBytes.Array4( ox, oy, oz, ot ), ArrayXdBytes.Array4( w, h, d, td ), copydata )
			END;
		END NewRange;

		PROCEDURE Copy*( ): HCube;
		VAR res: ArrayXdBytes.Array;
		BEGIN
			res := CopyX();  RETURN res( HCube );
		END Copy;

		PROCEDURE Set*( x, y, z, t: Index;  v: Value );
		BEGIN
			ArrayXdBytes.Set4( SELF, x, y, z, t, v );
		END Set;

	(** copy methods using the current boundary condition SELF.bc*)
		PROCEDURE CopyToVec*( dest: Array;  dim: Index;  srcx, srcy, srcz, srct, destx, len: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 1) THEN HALT( 1004 ) END;
			slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dim] := len;
			CopyToArray( dest, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ), slen, ArrayXdBytes.Index1( destx ),
								   ArrayXdBytes.Index1( len ) );
		END CopyToVec;

		PROCEDURE CopyToMtx*( dest: Array;  dimx, dimy: Index;  srcx, srcy, srcz, srct, destx, desty, lenx, leny: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 2) OR (dimx >= dimy) THEN HALT( 1005 ) END;
			slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;
			CopyToArray( dest, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ), slen, ArrayXdBytes.Index2( destx, desty ),
								   ArrayXdBytes.Index2( lenx, leny ) );
		END CopyToMtx;

		PROCEDURE CopyToCube*( dest: Array;  dimx, dimy, dimz: Index;
												   srcx, srcy, srcz, srct, destx, desty, destz, lenx, leny, lenz: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 3) OR (dimx >= dimy) OR (dimy >= dimz) THEN HALT( 1005 ) END;
			slen := ArrayXdBytes.Index4( 1, 1, 1, 1 );  slen[dimx] := lenx;  slen[dimy] := leny;  slen[dimz] := lenz;
			CopyToArray( dest, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ), slen, ArrayXdBytes.Index3( destx, desty, destz ),
								   ArrayXdBytes.Index3( lenx, leny, lenz ) );
		END CopyToCube;

		PROCEDURE CopyToHCube*( dest: Array;  srcx, srcy, srcz, srct, destx, desty, destz, destt, lenx, leny, lenz, lent: Index );
		VAR slen: ArrayXdBytes.IndexArray;
		BEGIN
			IF (dest.dim # 4) THEN HALT( 1005 ) END;
			slen := ArrayXdBytes.Index4( lenx, leny, lenz, lent );
			CopyToArray( dest, ArrayXdBytes.Index4( srcx, srcy, srcz, srct ), slen, ArrayXdBytes.Index4( destx, desty, destz, destt ),
								   slen );
		END CopyToHCube;

		PROCEDURE CopyTo1dArray*( VAR dest: ARRAY OF Value;  sx, sy, sz, st, slenx, sleny, slenz, slent: Index;  dpos, dlen: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 1, ArrayXdBytes.Index1( 0 ), ArrayXdBytes.Index1( LEN( dest ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index4( sx, sy, sz, st ),
																  ArrayXdBytes.Index4( slenx, sleny, slenz, slent ), ArrayXdBytes.Index1( dpos ),
																  ArrayXdBytes.Index1( dlen ) );
		END CopyTo1dArray;

		PROCEDURE CopyTo2dArray*( VAR dest: ARRAY OF ARRAY OF Value;  sx, sy, sz, st, slenx, sleny, slenz, slent: Index;
													   dposx, dposy, dlenx, dleny: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( dest, 1 ), LEN( dest, 0 ) ),
																			  SIZEOF( Value ), ADDRESSOF( dest[0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index4( sx, sy, sz, st ),
																  ArrayXdBytes.Index4( slenx, sleny, slenz, slent ),
																  ArrayXdBytes.Index2( dposx, dposy ), ArrayXdBytes.Index2( dlenx, dleny ) );
		END CopyTo2dArray;

		PROCEDURE CopyTo3dArray*( VAR dest: ARRAY OF ARRAY OF ARRAY OF Value;  sx, sy, sz, st, slenx, sleny, slenz, slent: Index;
													   dposx, dposy, dposz, dlenx, dleny, dlenz: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																			  ArrayXdBytes.Index3( LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0, 0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index4( sx, sy, sz, st ),
																  ArrayXdBytes.Index4( slenx, sleny, slenz, slent ),
																  ArrayXdBytes.Index3( dposx, dposy, dposz ),
																  ArrayXdBytes.Index3( dlenx, dleny, dlenz ) );
		END CopyTo3dArray;

		PROCEDURE CopyTo4dArray*( VAR dest: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;
													   sx, sy, sz, st, slenx, sleny, slenz, slent: Index;
													   dposx, dposy, dposz, dpost, dlenx, dleny, dlenz, dlent: LONGINT );
		VAR destm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			destm :=
				ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																			  ArrayXdBytes.Index4( LEN( dest, 3 ), LEN( dest, 2 ), LEN( dest, 1 ), LEN( dest, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( dest[0, 0, 0, 0] ) );
			ArrayXd.CopyArrayToArrayPartB( SELF, destm, bc, ArrayXdBytes.Index4( sx, sy, sz, st ),
																  ArrayXdBytes.Index4( slenx, sleny, slenz, slent ),
																  ArrayXdBytes.Index4( dposx, dposy, dposz, dpost ),
																  ArrayXdBytes.Index4( dlenx, dleny, dlenz, dlent ) );
		END CopyTo4dArray;

	(** copy from without boundary conditions *)
		PROCEDURE CopyFrom1dArray*( VAR src: ARRAY OF Value;  spos, slen: Index;
														    dx, dy, dz, dt, dlenx, dleny, dlenz, dlent: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 1, ArrayXdBytes.Index1( 0 ), ArrayXdBytes.Index1( LEN( src ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index1( spos ), ArrayXdBytes.Index1( slen ),
																			   ArrayXdBytes.Index4( dx, dy, dz, dt ),
																			   ArrayXdBytes.Index4( dlenx, dleny, dlenz, dlent ) );
		END CopyFrom1dArray;

		PROCEDURE CopyFrom2dArray*( VAR src: ARRAY OF ARRAY OF Value;  sposx, spoxy, slenx, sleny: Index;
														    dx, dy, dz, dt, dlenx, dleny, dlenz, dlent: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 2, ArrayXdBytes.Index2( 0, 0 ), ArrayXdBytes.Index2( LEN( src, 1 ), LEN( src, 0 ) ),
																			  SIZEOF( Value ), ADDRESSOF( src[0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index2( sposx, spoxy ),
																			   ArrayXdBytes.Index2( slenx, sleny ), ArrayXdBytes.Index4( dx, dy, dz, dt ),
																			   ArrayXdBytes.Index4( dlenx, dleny, dlenz, dlent ) );
		END CopyFrom2dArray;

		PROCEDURE CopyFrom3dArray*( VAR src: ARRAY OF ARRAY OF ARRAY OF Value;  sposx, spoxy, sposz, slenx, sleny, slenz: Index;
														    dx, dy, dz, dt, dlenx, dleny, dlenz, dlent: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 3, ArrayXdBytes.Index3( 0, 0, 0 ),
																			  ArrayXdBytes.Index3( LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0, 0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index3( sposx, spoxy, sposz ),
																			   ArrayXdBytes.Index3( slenx, sleny, slenz ),
																			   ArrayXdBytes.Index4( dx, dy, dz, dt ),
																			   ArrayXdBytes.Index4( dlenx, dleny, dlenz, dlent ) );
		END CopyFrom3dArray;

		PROCEDURE CopyFrom4dArray*( VAR src: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value;
														    sposx, spoxy, sposz, spost, slenx, sleny, slenz, slent: Index;
														    dx, dy, dz, dt, dlenx, dleny, dlenz, dlent: Index );
		VAR srcm: ArrayXdBytes.ArrayMemoryStructure;
		BEGIN
			srcm :=
				ArrayXdBytes.MakeMemoryStructure( 4, ArrayXdBytes.Index4( 0, 0, 0, 0 ),
																			  ArrayXdBytes.Index4( LEN( src, 3 ), LEN( src, 2 ), LEN( src, 1 ), LEN( src, 0 ) ), SIZEOF( Value ),
																			  ADDRESSOF( src[0, 0, 0, 0] ) );
			ArrayXdBytes.CopyArrayPartToArrayPart( srcm, SELF, ArrayXdBytes.Index4( sposx, spoxy, sposz, spost ),
																			   ArrayXdBytes.Index4( slenx, sleny, slenz, slent ),
																			   ArrayXdBytes.Index4( dx, dy, dz, dt ),
																			   ArrayXdBytes.Index4( dlenx, dleny, dlenz, dlent ) );
		END CopyFrom4dArray;

	END HCube;

	PROCEDURE ":="*( VAR l: HCube;  VAR r: ARRAY OF ARRAY OF ARRAY OF ARRAY OF Value );
	BEGIN
		(* IF r = NIL THEN l := NIL;  RETURN END;  *)
		IF l = NIL THEN NEW( l, 0, LEN( r, 3 ), 0, LEN( r, 2 ), 0, LEN( r, 1 ), 0, LEN( r, 0 ) )
		ELSE l.NewRange( 0, LEN( r, 3 ), 0, LEN( r, 2 ), 0, LEN( r, 1 ), 0, LEN( r, 0 ), FALSE )
		END;
		ArrayXdBytes.CopyMemoryToArrayPart( ADDRESSOF( r[0, 0, 0, 0] ), l, LEN( r, 0 ) * LEN( r, 1 ) * LEN( r, 2 ) * LEN( r, 3 ), NIL , NIL );
	END ":=";

	PROCEDURE ":="*( VAR l: HCube;  r: Value );
	BEGIN
		IF l # NIL THEN ArrayXd.Fill( l, r );  END;
	END ":=";

	PROCEDURE "+"*( l, r: HCube ): HCube;
	VAR res: HCube;
	BEGIN
		res := l.Alike();  ArrayXd.Add( l, r, res );  RETURN res;
	END "+";

	PROCEDURE "-"*( l, r: HCube ): HCube;
	VAR res: HCube;
	BEGIN
		res := l.Alike();  ArrayXd.Sub( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "+"*( l: HCube;  r: Value ): HCube;
	VAR res: HCube;
	BEGIN
		res := l.Alike();  ArrayXd.AddAV( l, r, res );  RETURN res;
	END "+";

	PROCEDURE "+"*( l: Value;  r: HCube ): HCube;
	BEGIN
		RETURN r + l
	END "+";

	PROCEDURE "-"*( l: HCube;  r: Value ): HCube;
	VAR res: HCube;
	BEGIN
		res := l.Alike();  ArrayXd.SubAV( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: Value;  r: HCube ): HCube;
	VAR res: HCube;
	BEGIN
		res := r.Alike();  ArrayXd.SubVA( l, r, res );  RETURN res;
	END "-";

	PROCEDURE "-"*( l: HCube ): HCube;
	BEGIN
		RETURN 0 - l;
	END "-";

	PROCEDURE "*"*( l: HCube;  r: Value ): HCube;
	VAR res: HCube;
	BEGIN
		res := l.Alike();  ArrayXd.MulAV( l, r, res );  RETURN res;
	END "*";

	PROCEDURE "*"*( l: Value;  r: HCube ): HCube;
	BEGIN
		RETURN r * l;
	END "*";

	PROCEDURE "DIV"*( l: HCube;  r: Value ): HCube;
	VAR res: HCube;
	BEGIN
		res := l.Alike();  ArrayXd.DivAV( l, r, res );  RETURN res;
	END "DIV";

	PROCEDURE "DIV"*( l: Value;  r: HCube ): HCube;
	VAR res: HCube;
	BEGIN
		res := r.Alike();  ArrayXd.DivVA( l, r, res );  RETURN res;
	END "DIV";

	PROCEDURE "MOD"*( l: HCube;  r: Value ): HCube;
	VAR res: HCube;
	BEGIN
		res := l.Alike();  ArrayXd.ModAV( l, r, res );  RETURN res;
	END "MOD";

	PROCEDURE "MOD"*( l: Value;  r: HCube ): HCube;
	VAR res: HCube;
	BEGIN
		res := r.Alike();  ArrayXd.ModVA( l, r, res );  RETURN res;
	END "MOD";

(* The procedures needed to register type HCube so that its instances can be made persistent. *)
	PROCEDURE LoadHCube( R: DataIO.Reader;  VAR obj: OBJECT );
	VAR a: HCube;  version: SHORTINT;  ver: NbrInt.Integer;
	BEGIN
		R.RawSInt( version );
		IF version = -1 THEN
			obj := NIL  (* Version tag is -1 for NIL. *)
		ELSIF version = VERSION THEN NEW( a, 0, 0, 0, 0, 0, 0, 0, 0 );  a.Read( R );  obj := a
		ELSE ver := version;  DataErrors.IntError( ver, "Alien version number encountered." );  HALT( 1000 )
		END
	END LoadHCube;

	PROCEDURE StoreHCube( W: DataIO.Writer;  obj: OBJECT );
	VAR a: HCube;
	BEGIN
		IF obj = NIL THEN W.RawSInt( -1 ) ELSE W.RawSInt( VERSION );  a := obj( HCube );  a.Write( W ) END
	END StoreHCube;

	PROCEDURE Register;
	VAR a: HCube;
	BEGIN
		NEW( a, 0, 0, 0, 0, 0, 0, 0, 0 );  DataIO.PlugIn( a, LoadHCube, StoreHCube )
	END Register;

(** Load and Store are procedures for external use that read/write an instance of HCube from/to a file. *)
	PROCEDURE Load*( R: DataIO.Reader;  VAR obj: HCube );
	VAR ptr: OBJECT;
	BEGIN
		R.Object( ptr );  obj := ptr( HCube )
	END Load;

	PROCEDURE Store*( W: DataIO.Writer;  obj: HCube );
	BEGIN
		W.Object( obj )
	END Store;

BEGIN
	Register

END HCubeInt.
