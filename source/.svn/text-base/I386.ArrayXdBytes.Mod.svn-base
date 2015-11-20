(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)
MODULE ArrayXdBytes;   (**  AUTHOR "fof"; PURPOSE "Collection of all generic procedures on Xd arrays.";  **)

(* collection of all generic procedures on arbitrary dimenional arrays with arbitrary origin
to increase speed, this module may be compiled with the \x option (index checks disabled) <- not yet *)

(* any item containing the string "dbg" will be removed from this module, do NOT use *)

IMPORT SYSTEM, Array1dBytes, dbgOut := KernelLog, DataIO;

CONST

	strongIndexChecking = TRUE;  debug = FALSE;

TYPE
	Index* = LONGINT;
	IndexArray* = POINTER TO ARRAY OF Index;
	Address* = LONGINT;

TYPE
	(** basic memory structure for arrays with arbitrary dimension  *)

	ArrayMemoryStructure* = OBJECT
	VAR
	(* do not change the interface -> asm routines *)
		(** contiuous memory block *)
		baseadr: Index;   (* lowest byte allocated for "MemoryDesc" = included *)
		bytes-: Index;   (* size of memory used in BYTES (8bit) *)
		(** xd array description*)
		dim-: Index;   (* dimension= LEN(len)=LEN(diminc) *)
		len-: IndexArray;   (* length per dimension*)
		diminc-: IndexArray;   (* dimincrease factor per dimension, do NOT expect diminc[0] < diminc[1] < ... ! *)
		elementsize: Index;   (* length of basic element in bytes *)
		origin-: IndexArray;
		adrwoffset: Index;   (* starting adress calculated with offset *)
	END ArrayMemoryStructure;

TYPE

	(** element enumerator:
		if block = FALSE then traverses memory elementwise respecting dimension orders, 	e.g. a[0,0,0],a[0,0,1], ... , a[l3,l2,l1-1],a[l3,l2,l1] ,
		if block = TRUE then traverses memory blockwise with largest continuous blocks, 	e.g. (a[0,0,0]-a[0,l2,l1]), (a[1,0,0]-a[1,l2,l1]), ... , (a[l3,0,0]-a[l3,l2,1])*)

	Enumerator* = OBJECT
	VAR dim: LONGINT;
		mem: ArrayMemoryStructure;
		adr-, size-: LONGINT;
		lncdim: LONGINT;   (* lowest not continuous dimension *)
		pos-, origin, len: IndexArray;

		PROCEDURE & Init*( mem: ArrayMemoryStructure;  enumorigin, enumlen: IndexArray;  block: BOOLEAN );
		VAR i: LONGINT;
		BEGIN
			SELF.mem := mem;
			IF enumorigin = NIL THEN enumorigin := mem.origin END;
			IF enumlen = NIL THEN enumlen := mem.len END;
			(* range checks must be done in higher level *)

			dim := LEN( enumorigin );  lncdim := 0;  CheckIndexArray( dim, pos );  origin := enumorigin;  len := enumlen;
			size := mem.elementsize;  adr := mem.baseadr;  i := 0;
			WHILE (i < dim) DO
				pos[i] := origin[i];  INC( adr, (origin[i] - mem.origin[i]) * mem.diminc[i] );
				IF block & (len[i] = mem.len[i]) & (size = mem.diminc[i]) THEN size := size * len[i];  INC( lncdim )
				ELSE block := FALSE;   (* stop at lowest continuous block *)
				END;
				INC( i );
			END;
			IF debug THEN dbgOut.String( "Enumerator.init, lncdim:" );  dbgOut.Int( lncdim, 0 );  dbgOut.Ln;  END;
			ASSERT ( size # 0 );
		END Init;

		PROCEDURE Next*( ): BOOLEAN;
		VAR i, j: LONGINT;  org, length: LONGINT;
		BEGIN
			IF lncdim = dim THEN
				IF debug THEN dbgOut.String( "Enumerator.next: all continuous, dim=" );  dbgOut.Int( lncdim, 0 );  dbgOut.Ln;  END;
				RETURN FALSE
			END;   (* all continuous *)
			i := lncdim;  INC( pos[i] );  INC( adr, mem.diminc[i] );  org := origin[i];  length := len[i];
			WHILE (i < dim - 1) & (pos[i] = org + length) DO  (* find next dimension to increase *)
				pos[i] := org;  DEC( adr, mem.diminc[i] * length );  INC( i );  INC( pos[i] );  INC( adr, mem.diminc[i] );  org := origin[i];
				length := len[i];
			END;
			IF debug THEN
				j := 0;  dbgOut.String( "Enumerator.next:" );
				WHILE (j < dim) DO dbgOut.Int( pos[j], 0 );  dbgOut.String( "|" );  INC( j );  END;
				dbgOut.Ln;
			END;
			RETURN (pos[i] # org + length);
		END Next;

	END Enumerator;

TYPE
	Array* = OBJECT (ArrayMemoryStructure)
	VAR  (**)
		protector: ANY;   (* temporary pointer to protect data from being garbage collected *)
		permutation-: IndexArray;   (* permutation used for INTERNALLY accessing the data. *)
		bc-: SHORTINT;   (* boundary condition, abstract *)
		(** public values *)
		(* boundaryCondition-: SHORTINT;   *)
		(* used-: IndexArray;   (*  in preparation *)*)

		(** cache variables for faster access *)
		f0, f1, f2, f3: Index;   (* cache data for dimensions 1-4 *)
		o0-, o1-, o2-, o3-, l0-, l1-, l2-, l3-: Index;   (* cache data for dimensions 1-4 *)
		(* generally: range checks are done on 1d array only, not for each dimension *)

		PROCEDURE dbgWriteInfo*;
		BEGIN
			dbgWriteMemoryInfo( SELF );
		END dbgWriteInfo;


	(** get information about elementsize, must be provided by each implementation of Array *)
		PROCEDURE GetInfo*( VAR elementsize: LONGINT );
		BEGIN
			HALT( 1001 );   (* abstract *)
		END GetInfo;

		PROCEDURE SetBoundaryCondition*( c: SHORTINT );   (* to be overridden in higher level modules to determine access methods*)
		BEGIN
			bc := c;
		END SetBoundaryCondition;

	(** Allocate memory, should be provided by each implementation of Arrays but can also be done here *)
		PROCEDURE Allocate*( size: LONGINT;  VAR baseadr: LONGINT;  VAR protector: ANY );
		VAR alloc: POINTER TO ARRAY OF SYSTEM.BYTE;
		BEGIN
			NEW( alloc, size * elementsize );  baseadr := ADDRESSOF( alloc[0] );  protector := alloc;
		END Allocate;

		PROCEDURE ValidateCache*;
		VAR i: LONGINT;
		BEGIN
			IF dim > 3 THEN f3 := diminc[3];  o3 := origin[3];  l3 := len[3];  ELSE f3 := 0;  l3 := 0;  END;
			IF dim > 2 THEN f2 := diminc[2];  o2 := origin[2];  l2 := len[2];  ELSE f2 := 0;  l2 := 0;  END;
			IF dim > 1 THEN f1 := diminc[1];  o1 := origin[1];  l1 := len[1];  ELSE f1 := 0;  l1 := 0;  END;
			IF dim > 0 THEN f0 := diminc[0];  o0 := origin[0];  l0 := len[0];  ELSE f0 := 0;  l0 := 0;  END;
			i := 0;  adrwoffset := baseadr;
			WHILE (i < dim) DO adrwoffset := adrwoffset - origin[i] * diminc[i];  INC( i );  END;
		END ValidateCache;

		PROCEDURE Init( newdim: LONGINT );
		BEGIN
			dim := newdim;  CheckIndexArray( dim, len );  CheckIndexArray( dim, origin );
			CheckIndexArray( dim, permutation );  CheckIndexArray( dim, diminc );
		END Init;

	(** NewXdb, allocate memory for the array,  should be called by any constructors of an implementation of array *)
		PROCEDURE & NewXdB*( neworigin, newlen: IndexArray);
		VAR i, size: LONGINT;
		BEGIN
			Init( LEN( newlen ) );
			IF newlen[0] = 0 THEN RETURN END;   (* newlen[0]=0: create empty array for load procedure *)
			GetInfo( elementsize );  size := elementsize;
			FOR i := 0 TO dim - 1 DO size := size * newlen[i];  len[i] := newlen[i];  origin[i] := neworigin[i];  permutation[i] := i END;
			Allocate( size DIV elementsize, baseadr, protector );  ComputeIncrease( len, permutation, elementsize, diminc );
			bytes := diminc[dim - 1] * len[dim - 1];  ValidateCache;  SetBoundaryCondition( bc );
		END NewXdB;

	(** AlikeX, return Array with same geometry, abstract, must be provided by any implementation of Array*)
		PROCEDURE AlikeX*( ): Array;
		BEGIN
			HALT( 2002 );   (* abstract *)
		END AlikeX;

	(** Copy: returns a deep copy of Array *)
		PROCEDURE CopyX*( ): Array;
		VAR copy: Array;  i: Index;
		BEGIN
			copy := AlikeX();
			ASSERT ( bytes = copy.bytes ) (* should never happen, for dbgging  only *) ;
			SYSTEM.MOVE( baseadr, copy.baseadr, bytes );  i := 0;  RETURN copy;
		END CopyX;

	(** resize and / or shift origin, if copydata=TRUE then all data at same positions are kept *)
		PROCEDURE NewRangeX*( neworigin, newlen: IndexArray;  preservedata: BOOLEAN );
		(* reduce or extend dimensions with copy *)
		VAR same: BOOLEAN;  i: LONGINT;  olddata: ArrayMemoryStructure;

		BEGIN
			IF LEN( newlen ) # LEN( neworigin ) THEN HALT( 1001 ) END;

			(* check if len equals old len*)
			IF LEN( newlen ) = dim THEN
				same := TRUE;  i := 0;
				WHILE (i < dim) & same DO
					IF (newlen[i] # len[i]) OR (neworigin[i] # origin[i]) THEN same := FALSE END;
					INC( i );
				END;
				IF same THEN RETURN END;
			END;

			IF preservedata THEN NEW( olddata );  AMSCopyDescr( SELF, olddata );
			END;
			NewXdB( neworigin, newlen );
			IF preservedata THEN CopyDataPositionPreserving( olddata, SELF ) END;
			(* now setting new values *)
		END NewRangeX;

	(** optimize access for the dimensions ordered as given in "order". modifies the internal representation of the data *)
		PROCEDURE OptimizeForAccess*( order: ARRAY OF Index;  preservedata: BOOLEAN );
		VAR old: ArrayMemoryStructure;
		BEGIN
			IF preservedata THEN NEW( old );  AMSCopyDescr( SELF, old ) END;
			IF CompletePermutation( order, permutation^ ) THEN
				ComputeIncrease( len, permutation, elementsize, diminc );  ValidateCache;
				IF preservedata THEN
					Allocate( bytes DIV elementsize, baseadr, protector );  ValidateCache;
					CopyDataByCoordinateTraversal( old, SELF );
				END;
			END;
		END OptimizeForAccess;

	(** optimize access for the dimensions ordered as given in "order". modifies the internal representation of the data but does NOT affect SELF.permutation! *)
		PROCEDURE PermuteDimensions*( permutation: IndexArray;  rearrangeMemory: BOOLEAN );
		VAR old: ArrayMemoryStructure;
		BEGIN
			IF CheckPermutation( dim, permutation ^) THEN
				ApplyPermutation( permutation^, origin^ );  ApplyPermutation( permutation^, len^ );
				ApplyPermutation( permutation^, diminc^ );  ApplyPermutation( permutation^, SELF.permutation^ );
				ValidateCache;
				IF rearrangeMemory THEN
					NEW( old );  AMSCopyDescr( SELF, old );  NewXdB( origin, len );  CopyDataByCoordinateTraversal( old, SELF );
				END;
			END;
		END PermuteDimensions;

		(** delete  <lenght> elements in dimension <dimension> at position <first> *)
	(** example:delete columns from matrix, remove data to vector etc. *)
		PROCEDURE DeleteElements*( dimension, first, length: Index );
		VAR old: ArrayMemoryStructure;  srco, desto, destlen: IndexArray;
		BEGIN
			(** index checks: *)
			IF (dimension < 0) OR (dimension >= dim) THEN HALT( 1001 ) END;
			IF (first < origin[dimension]) OR (first + length > origin[dimension] + len[dimension]) THEN HALT( 1002 ) END;

			(** computation *)
			NEW( old );  AMSCopyDescr( SELF, old );  DEC( len[dimension], length );  NewXdB( origin, len );

			NEW( destlen, dim );  CopyIndexArray( old.len^, destlen );  NEW( srco, dim );  CopyIndexArray( old.origin^, srco );
			NEW( desto, dim );  CopyIndexArray( origin^, desto );

			IF first > srco[dimension] THEN
				destlen[dimension] := first - srco[dimension];
				CopyArrayPartToArrayPart( old, SELF, old.origin, destlen, origin, destlen );
			END;
			IF (first + length) < (old.origin[dimension] + old.len[dimension]) THEN
				desto[dimension] := first;  srco[dimension] := first + length;
				destlen[dimension] := (old.origin[dimension] + old.len[dimension]) - (first + length);
				CopyArrayPartToArrayPart( old, SELF, srco, destlen, desto, destlen );
			END;
		END DeleteElements;

		(** insert <lenght> elements in dimension <dimension> at position <first> *)
	(** example: insert new columns in matrix, append data to vector etc. *)
		PROCEDURE InsertElements*( dimension, first, length: Index );
		VAR old: ArrayMemoryStructure;  srco, desto, destlen: IndexArray;
		BEGIN
			(** index checks: *)
			IF (dimension < 0) OR (dimension >= dim) THEN HALT( 1001 ) END;
			IF (first < origin[dimension]) OR (first > origin[dimension] + len[dimension]) THEN HALT( 1002 ) END;

			NEW( old );  AMSCopyDescr( SELF, old );  INC( len[dimension], length );  NewXdB( origin, len );

			NEW( destlen, dim );  CopyIndexArray( old.len^, destlen );  NEW( srco, dim );  CopyIndexArray( old.origin^, srco );
			NEW( desto, dim );  CopyIndexArray( origin^, desto );

			IF first > srco[dimension] THEN
				destlen[dimension] := first - srco[dimension];
				CopyArrayPartToArrayPart( old, SELF, old.origin, destlen, origin, destlen );
			END;
			IF (first) < (old.origin[dimension] + old.len[dimension]) THEN
				desto[dimension] := first + length;  srco[dimension] := first;
				destlen[dimension] := (old.origin[dimension] + old.len[dimension]) - (first);
				CopyArrayPartToArrayPart( old, SELF, srco, destlen, desto, destlen );
			END;

		END InsertElements;

	(** exchange elements at pos1 and pos2 in dimension <dimension>. *)
		PROCEDURE ToggleElements*( dimension: Index;  pos1, pos2: Index );
		VAR offset1, offset2, swaplen, diminclen, srcadr, stop, dataadr: LONGINT;  swapcache: IndexArray;
		BEGIN
			IF (dimension < 0) OR (dimension >= dim) THEN HALT( 1001 );  END;
			IF (pos1 < origin[dimension]) OR (pos1 >= origin[dimension] + len[dimension]) THEN HALT( 1002 ) END;
			IF (pos2 < origin[dimension]) OR (pos2 >= origin[dimension] + len[dimension]) THEN HALT( 1002 ) END;

			offset1 := diminc[dimension] * (pos1 - origin[dimension]);
			offset2 := diminc[dimension] * (pos2 - origin[dimension]);  swaplen := diminc[dimension];
			diminclen := diminc[dimension] * len[dimension];

			NEW( swapcache, swaplen );  dataadr := ADDRESSOF( swapcache[0] );  stop := baseadr + bytes;  srcadr := baseadr;

			WHILE (srcadr < stop) DO
				Array1dBytes.MoveB( srcadr + offset2, dataadr, swaplen );
				Array1dBytes.MoveB( srcadr + offset1, srcadr + offset2, swaplen );
				Array1dBytes.MoveB( dataadr, srcadr + offset1, swaplen );  INC( srcadr, diminclen );
			END;

		END ToggleElements;
	(** permute elements in dimension <dimension>, permutation must have length len[dimension] *)
		PROCEDURE PermuteElements*( dimension: Index;  permutation: ARRAY OF Index );
		VAR i, swaplen, diminclen, stop, srcadr, dataadr: LONGINT;  swapcache: IndexArray;
		BEGIN
			(** index checks: *)
			IF (dimension < 0) OR (dimension >= dim) THEN HALT( 1001 );  END;
			IF LEN( permutation ) # len[dimension] THEN HALT( 1002 ) END;
			IF LEN( permutation ) = 1 THEN RETURN END;
			WHILE (i < LEN( permutation )) DO
				permutation[i] := permutation[i] - origin[dimension];
				IF permutation[i] >= LEN( permutation ) THEN HALT( 1003 ) END;
				INC( i );
			END;
			(** computation *)

			swaplen := diminc[dimension];  diminclen := diminc[dimension] * len[dimension];  NEW( swapcache, diminclen );
			dataadr := ADDRESSOF( swapcache[0] );  stop := baseadr + bytes;  srcadr := baseadr;

			WHILE (srcadr < stop) DO
				i := 0;
				WHILE (i < len[dimension]) DO
					Array1dBytes.MoveB( srcadr + swaplen * permutation[i], dataadr + swaplen * i, swaplen );  INC( i );
				END;
				Array1dBytes.MoveB( dataadr, srcadr, diminclen );  INC( srcadr, diminclen );
			END;
		END PermuteElements;

	(** reverse order of elements in dimension <dimension> *)
		PROCEDURE MirrorDimension*( dimension: Index );
		VAR swaplen, diminclen, srcadr, stop, i, stop2: LONGINT;  dataadr: LONGINT;  swapcache: IndexArray;
		BEGIN
			IF (dimension < 0) OR (dimension >= dim) THEN HALT( 1001 );  END;

			swaplen := diminc[dimension];
			IF dimension < dim - 1 THEN diminclen := diminc[dimension + 1] ELSE diminclen := bytes END;
			stop := baseadr + bytes;  srcadr := baseadr;  stop2 := len[dimension] DIV 2;  NEW( swapcache, swaplen );
			dataadr := ADDRESSOF( swapcache[0] );

			WHILE (srcadr < stop) DO
				i := 0;
				WHILE (i < stop2) DO
					Array1dBytes.MoveB( srcadr + diminclen - (i + 1) * swaplen, dataadr, swaplen );
					Array1dBytes.MoveB( srcadr + i * swaplen, srcadr + diminclen - (i + 1) * swaplen, swaplen );
					Array1dBytes.MoveB( dataadr, srcadr + i * swaplen, swaplen );  INC( i );
				END;
				INC( srcadr, diminclen );
			END;
		END MirrorDimension;
	(** copy block of data within dimension <dimension> from <from> to <to> *)
		PROCEDURE BlockCopy*( dimension, from, to, length: Index );
		VAR swaplen, diminclen, stop: LONGINT;
			(*! todo: handle used *)
		BEGIN
			IF (dimension < 0) OR (dimension >= dim) THEN HALT( 1001 );  END;

			from := (from - origin[dimension]);  to := (to - origin[dimension]);

			IF (from < origin[dimension]) OR (from + length > origin[dimension] + len[dimension]) THEN HALT( 1002 )
			END;
			IF (to < origin[dimension]) OR (to + length > origin[dimension] + len[dimension]) THEN HALT( 1002 ) END;

			IF from = to THEN RETURN
			END;

			from := from * diminc[dimension];  to := to * diminc[dimension];  swaplen := diminc[dimension] * length;
			diminclen := diminc[dimension] * len[dimension];

			stop := baseadr + bytes;  INC( from, baseadr );  INC( to, baseadr );
			WHILE (from < stop) DO Array1dBytes.MoveB( from, to, swaplen );  INC( from, diminclen );  INC( to, diminclen );  END;

		END BlockCopy;
	(** move block of data within dimension <dimension> from <from> to <to> *)
		PROCEDURE BlockMove*( dimension, from, to, length: Index );
		VAR swaplen, diminclen, stop: LONGINT;  movefrom, moveto, movelen, dataadr: LONGINT;  swapcache: IndexArray;
			(*! todo: handle used *)
		BEGIN
			IF (dimension < 0) OR (dimension >= dim) THEN HALT( 1001 );  END;

			from := (from - origin[dimension]);  to := (to - origin[dimension]);

			IF (from < 0) OR (from + length > len[dimension]) THEN HALT( 1002 )
			END;
			IF (to < 0) OR (to + length > len[dimension]) THEN HALT( 1002 ) END;

			IF from = to THEN RETURN
			END;

			from := from * diminc[dimension];  to := to * diminc[dimension];  swaplen := diminc[dimension] * length;
			diminclen := diminc[dimension] * len[dimension];

			NEW( swapcache, swaplen );  dataadr := ADDRESSOF( swapcache[0] );

			IF from < to THEN movefrom := (from + swaplen);  movelen := (to - from);  moveto := from;
			ELSE  (* to < from *)
				movefrom := to;  movelen := (from - to);  moveto := to + swaplen;
			END;

			stop := baseadr + bytes;  INC( from, baseadr );  INC( to, baseadr );  INC( movefrom, baseadr );  INC( moveto, baseadr );

			WHILE (from < stop) DO
				Array1dBytes.MoveB( from, dataadr, swaplen );  Array1dBytes.MoveB( movefrom, moveto, movelen );
				Array1dBytes.MoveB( dataadr, to, swaplen );  INC( from, diminclen );  INC( to, diminclen );  INC( movefrom, diminclen );
				INC( moveto, diminclen );
			END;

		END BlockMove;

		PROCEDURE LoadXd*( VAR R: DataIO.Reader );
		VAR version, i, size: LONGINT;  readRawData: BOOLEAN;  readbytes: LONGINT;
		BEGIN
			R.RawLInt( version );  R.RawLInt( dim );  NEW( len, dim );  NEW( diminc, dim );  NEW( origin, dim );  NEW( permutation, dim );
			GetInfo( elementsize );  size := 1;
			FOR i := 0 TO dim - 1 DO R.RawLInt( len[i] );  size := size * len[i];  END;
			Allocate( size, baseadr, protector );  bytes := size * elementsize;
			FOR i := 0 TO dim - 1 DO R.RawLInt( diminc[i] );  END;
			(* elementsize already set via GetInfo *)
			FOR i := 0 TO dim - 1 DO R.RawLInt( origin[i] );  END;
			(* protector set via Allocate *)
			FOR i := 0 TO dim - 1 DO R.RawLInt( permutation[i] );  END;
			ValidateCache;  R.RawSInt( bc );  SetBoundaryCondition( bc );
			(* cache variables set via ValidateCache *)
			R.RawBool( readRawData );
			IF readRawData THEN R.RawLInt( readbytes );
				ASSERT ( readbytes = bytes );
				ASSERT ( bytes # 0 );
				ReadMemory( R, baseadr, bytes, readbytes );
				ASSERT ( readbytes = bytes )
			END;
		END LoadXd;

		PROCEDURE StoreXd*( VAR W: DataIO.Writer;  storeRawData: BOOLEAN );
		CONST version = 0;
		VAR i: LONGINT;
		BEGIN
			W.RawLInt( version );
			(* baseadr+bytes set while Allocation *)
			W.RawLInt( dim );
			FOR i := 0 TO dim - 1 DO W.RawLInt( len[i] );  END;
			FOR i := 0 TO dim - 1 DO W.RawLInt( diminc[i] );  END;
			(* elementsize set via GetInfo *)
			FOR i := 0 TO dim - 1 DO W.RawLInt( origin[i] );  END;
			(* protector set via Allocate *)
			FOR i := 0 TO dim - 1 DO W.RawLInt( permutation[i] );  END;
			(* cache variables set via ValidateCache *)
			W.RawSInt( bc );  W.RawBool( storeRawData );
			IF storeRawData THEN
				ASSERT ( bytes # 0 );
				W.RawLInt( bytes );  StoreMemory( W, baseadr, bytes );
			END;
		END StoreXd;

	END Array;

	Rectangle = OBJECT
	VAR origin, len, destpos, destlen: IndexArray;
		next: Rectangle;
	END Rectangle;

	BoundaryEnum* = OBJECT  (* object for enumeration of boundaries of a w.r.t (origin,len), additionally destination*)
	VAR root: Rectangle;

		PROCEDURE & Init*( a: Array;  origin, len: IndexArray );
		VAR dim, this: LONGINT;  rect: Rectangle;  rectorigin, rectlen: IndexArray;  i: LONGINT;  done: BOOLEAN;

			PROCEDURE Min( x, y: Index ): Index;
			BEGIN
				IF x < y THEN RETURN x ELSE RETURN y END;
			END Min;

			PROCEDURE Max( x, y: Index ): Index;
			BEGIN
				IF x > y THEN RETURN x ELSE RETURN y END;
			END Max;

			PROCEDURE CutLower( VAR outero, outerlen: Index;  innero, innerlen: Index ): BOOLEAN;
			BEGIN
				IF outero < innero THEN INC( outerlen, outero );  outerlen := Min( outerlen, innero ) - outero;  RETURN TRUE
				ELSE RETURN FALSE
				END;
			END CutLower;

			PROCEDURE CutHigher( VAR outero, outerlen: Index;  innero, innerlen: Index ): BOOLEAN;
			BEGIN
				IF outero + outerlen > innero + innerlen THEN
					INC( outerlen, outero );  outero := Max( innero + innerlen, outero );  outerlen := outerlen - outero;  RETURN TRUE
				ELSE RETURN FALSE
				END;
			END CutHigher;

		BEGIN
			dim := LEN( origin );
			ASSERT ( dim = a.dim );
			ASSERT ( LEN( origin ) = LEN( len ) );

			done := FALSE;  this := dim - 1;

			WHILE (this >= 0) & (~done) DO  (* look for largest blocks in highest dimension *)

				IF rectlen = NIL THEN NEW( rectorigin, dim );  NEW( rectlen, dim );  END;
				FOR i := 0 TO dim - 1 DO rectorigin[i] := origin[i];  rectlen[i] := len[i];  END;
				IF CutLower( rectorigin[this], rectlen[this], a.origin[this], a.len[this] ) THEN
					INC( origin[this], rectlen[this] );  DEC( len[this], rectlen[this] );
					IF len[this] = 0 THEN done := TRUE END;
					NEW( rect );  rect.next := root;  root := rect;  rect.len := rectlen;  rect.origin := rectorigin;  rectorigin := NIL;
					rectlen := NIL;
				END;
				IF ~done THEN
					IF rectlen = NIL THEN NEW( rectorigin, dim );  NEW( rectlen, dim );  END;
					FOR i := 0 TO dim - 1 DO rectorigin[i] := origin[i];  rectlen[i] := len[i];  END;
					IF CutHigher( rectorigin[this], rectlen[this], a.origin[this], a.len[this] ) THEN
						DEC( len[this], rectlen[this] );
						IF len[this] = 0 THEN done := TRUE END;
						NEW( rect );  rect.next := root;  root := rect;  rect.len := rectlen;  rect.origin := rectorigin;  rectorigin := NIL;
						rectlen := NIL;
					END;
				END;
				DEC( this );
			END;
		END Init;

		PROCEDURE Get*( VAR origin, len: IndexArray ): BOOLEAN;
		BEGIN
			IF root # NIL THEN origin := root.origin;  len := root.len;  root := root.next;  RETURN TRUE ELSE RETURN FALSE END;
		END Get;

	END BoundaryEnum;

	(* The in-line assember code works in WinAos, but not in Aos.  Why?  We don't know yet.
	(** store memory to Writer as if it was ARRAY OF CHAR *)
	PROCEDURE StoreMemory( W: DataIO.Writer;  baseadr: LONGINT;  len: LONGINT );
	VAR proc: PROCEDURE {DELEGATE} ( VAR x: ARRAY OF CHAR;  ofs, len: LONGINT );

		PROCEDURE PushAndCall( writer: LONGINT;  call: LONGINT;  baseadr: LONGINT;  len: LONGINT );
		CODE {SYSTEM.i386}
			PUSH	len[EBP]	;  array length
			PUSH	baseadr[EBP]	;  array position array[0]
			XOR	EAX, EAX	;
			PUSH	EAX	;  offset
			PUSH	len[EBP]	;  len
			PUSH	writer[EBP]	;  writer
			CALL	call[EBP]	;  now call W.Bytes
		END PushAndCall;

	BEGIN
		proc := W.Bytes;  PushAndCall( SYSTEM.VAL( LONGINT, W ), SYSTEM.VAL( LONGINT, proc ), baseadr, len );
	END StoreMemory;


(** read memory from reader as if it was ARRAY OF CHAR *)
	PROCEDURE ReadMemory( R: DataIO.Reader;  baseadr: LONGINT;  size: LONGINT;  VAR len: LONGINT );
	VAR proc: PROCEDURE {DELEGATE} ( VAR x: ARRAY OF CHAR;  ofs, size: LONGINT;  VAR len: LONGINT );

		PROCEDURE PushAndCall( reader: LONGINT;  call: LONGINT;  baseadr: LONGINT;  size: LONGINT;  lenadr: LONGINT );
		CODE {SYSTEM.i386}
			PUSH	len[EBP]	;
			PUSH	baseadr[EBP]
			XOR	EAX, EAX
			PUSH	EAX
			PUSH	size[EBP]
			PUSH	lenadr[EBP]
			PUSH	reader[EBP]
			CALL	call[EBP]
		END PushAndCall;

	BEGIN
		proc := R.Bytes;  PushAndCall( SYSTEM.VAL( LONGINT, R ), SYSTEM.VAL( LONGINT, proc ), baseadr, size, ADDRESSOF( len ) );
	END ReadMemory;
*)

	(** oberon versions of Store and Read Memory: *)
	PROCEDURE StoreMemory( W: DataIO.Writer;  baseadr: LONGINT;  len: LONGINT );   (* store memory to Writer  *)
	VAR adr: LONGINT;  char: CHAR;
	BEGIN
		adr := baseadr;  INC( len, baseadr );
		WHILE (adr < len) DO SYSTEM.GET( adr, char );  W.Char( char );  INC( adr );  END;
	END StoreMemory;

	PROCEDURE ReadMemory( R: DataIO.Reader;  baseadr: LONGINT;  size: LONGINT;  VAR len: LONGINT );   (* read memory from reader *)
	VAR adr: LONGINT;  char: CHAR;
	BEGIN
		adr := baseadr;  INC( size, baseadr );  len := 0;
		WHILE (adr < size) DO R.Char( char );  SYSTEM.PUT( adr, char );  INC( adr );  INC( len );  END;
	END ReadMemory;


(** helper procedures , should be in-lined some time*)

	PROCEDURE Min( l, r: LONGINT ): LONGINT;
	BEGIN
		IF l < r THEN RETURN l ELSE RETURN r END;
	END Min;

	PROCEDURE CheckIndexArray( dim: Index;  VAR a: IndexArray );
	BEGIN
		IF (a = NIL ) OR (LEN( a ) # dim) THEN NEW( a, dim ) END;
	END CheckIndexArray;

	PROCEDURE CopyIndexArray( src: ARRAY OF Index;  dest: IndexArray );
	VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < LEN( dest )) DO dest[i] := src[i];  INC( i );  END;
	END CopyIndexArray;

	PROCEDURE Intersect*( org1, len1, org2, len2: IndexArray;  VAR org, len: IndexArray ): BOOLEAN;
	VAR i, dim: LONGINT;  o1, o2, l1, l2: LONGINT;
	BEGIN
		IF (LEN( org1 ) # LEN( len1 )) OR (LEN( org2 ) # LEN( len2 )) THEN HALT( 1000 ) END;
		dim := Min( LEN( org1 ), LEN( org2 ) );  NEW( org, dim );  NEW( len, dim );  i := 0;
		(*dbgSISISI("Intersection, from dims ",LEN(org1)," & ",LEN(org2)," to ",dim); *)
		WHILE (i < dim) DO
			o1 := org1[i];  o2 := org2[i];  l1 := len1[i] + o1;  l2 := len2[i] + o2;
			IF o1 > o2 THEN org[i] := o1 ELSE org[i] := o2 END;
			IF l1 < l2 THEN len[i] := l1 - org[i] ELSE len[i] := l2 - org[i] END;
			IF len[i] <= 0 THEN RETURN FALSE END;
			(*
			dbgSISISI("o1=",o1," o2=",o2," o=",org[i]);
			dbgSISISI("l1= ",len1[i]," l2= ",len2[i]," l=",len[i]);
			*)
			INC( i );

		END;

		RETURN TRUE;
	END Intersect;

	PROCEDURE -CheckLEQ*( lesseq, than: LONGINT );
	(* invoke trap  INDEX OUT OF RANGE   if lesseq > than *)
	CODE {SYSTEM.i386}
		MOV	ECX, [ESP]	;  than
		MOV	EBX, [ESP+4]	;  less
		CMP	EBX, ECX
		JLE	ok
		PUSH	7
		INT	3
		ok:
		ADD	ESP, 8
	END CheckLEQ;

	PROCEDURE -CheckLE*( lesseq, than: LONGINT );
	(* invoke trap  INDEX OUT OF RANGE   if lesseq > than *)
	CODE {SYSTEM.i386}
		MOV	ECX, [ESP]	;  than
		MOV	EBX, [ESP+4]	;  less
		CMP	EBX, ECX
		JL	ok
		PUSH	7
		INT	3
		ok:
		ADD	ESP, 8
	END CheckLE;

	PROCEDURE -CheckEQ*( equals, this: LONGINT );
	(* invoke trap  INDEX OUT OF RANGE   if equals # this *)
	(*
		Oberon code for CheckEQ:
		PROCEDURE CheckEQ*(lesseq,than: LONGINT)
		BEGIN IF this=equals THEN HALT(100) (* in asm:  invoke trap  INDEX OUT OF RANGE *)  END; END CheckEQ;
	*)
	CODE {SYSTEM.i386}
		MOV	ECX, [ESP]	;  this
		MOV	EBX, [ESP+4]	;  equals
		CMP	EBX, ECX
		JE	ok
		PUSH	7
		INT	3
		ok:
		ADD	ESP, 8
	END CheckEQ;

(** chck permutation for validity, precondition: permutation has less  than 2^31 entries since bit 31 is used for marking *)
	PROCEDURE CheckPermutation( dim: LONGINT;  VAR permutation: ARRAY OF LONGINT ): BOOLEAN;
	VAR i, j: LONGINT;  valid: BOOLEAN;  set: SET;
	BEGIN
		IF LEN( permutation ) # dim THEN RETURN FALSE END;
		i := 0;
		WHILE (i < dim) DO
			j := SYSTEM.VAL( LONGINT, SYSTEM.VAL( SET, permutation[i] ) - {31} );  INCL( SYSTEM.VAL( SET, permutation[j] ), 31 );  INC( i );
		END;
		i := 0;  valid := TRUE;
		WHILE (i < dim) DO
			set := SYSTEM.VAL( SET, permutation[i] );
			IF 31 IN set THEN EXCL( set, 31 ) ELSE valid := FALSE END;
			permutation[i] := SYSTEM.VAL( LONGINT, set );  INC( i );
		END;
		RETURN valid;
	END CheckPermutation;

(** make a valid permutation from firstpart of permutation, i.e. extend to len LEN(permutation) and check for validity
	example: beginning = (3,4), full = (1,2,3,4,5) -> full = (3,4,1,2,5)
	*)
	PROCEDURE CompletePermutation( beginning: ARRAY OF LONGINT;  full: ARRAY OF LONGINT ): BOOLEAN;
	VAR srcdim, destdim, i, j, val, this, next: LONGINT;
	BEGIN
		srcdim := LEN( beginning );  destdim := LEN( full );
		IF srcdim > destdim THEN HALT( 100 ) END;
		i := 0;
		WHILE (i < destdim) DO full[i] := i;  INC( i );  END;
		i := 0;
		WHILE (i < srcdim) DO  (* check and insert, when possible *)
			val := beginning[i];  j := i;  this := full[i];  full[i] := val;
			WHILE (j < destdim - 1) & (this # val) DO  (* search *)
				INC( j );  next := full[j];  full[j] := this;  this := next;
			END;
			IF (j = destdim - 1) & (this # val) THEN  (* value not found in rest, i.e. no valid permutation ! *)
				RETURN FALSE;
			END;
			INC( i );
		END;
		RETURN TRUE;
	END CompletePermutation;

	PROCEDURE ApplyPermutation( permutation: ARRAY OF Index;  VAR array: ARRAY OF Index );
	VAR i, dim: LONGINT;
	BEGIN
		dim := LEN( permutation );  i := 0;
		WHILE (i < dim) DO permutation[i] := array[permutation[i]];  INC( i );  END;
		i := 0;
		WHILE (i < dim) DO array[i] := permutation[i];  INC( i );  END;
	END ApplyPermutation;

	PROCEDURE IdentityPermutation( dim: LONGINT ): IndexArray;
	VAR a: IndexArray;  i: LONGINT;
	BEGIN
		NEW( a, dim );  i := 0;
		WHILE (i < dim) DO a[i] := i;  INC( i );  END;
		RETURN a;
	END IdentityPermutation;

	PROCEDURE ComputeIncrease( len: IndexArray;  permutation: IndexArray;  elementsize: LONGINT;  diminc: IndexArray );
	VAR i: LONGINT;
	BEGIN
		IF permutation # NIL THEN
			i := 1;  diminc[permutation[0]] := elementsize;
			WHILE (i < LEN( len )) DO diminc[permutation[i]] := diminc[permutation[i - 1]] * len[permutation[i - 1]];  INC( i );  END;
		ELSE
			i := 1;  diminc[0] := elementsize;
			WHILE (i < LEN( len )) DO diminc[i] := diminc[i - 1] * len[i - 1];  INC( i );  END;
		END;
	END ComputeIncrease;

(*
(** shallow copy: any field of ArrayMemoryStructure is copied shallow *)
	PROCEDURE AMSCopyShallow( src: ArrayMemoryStructure;  dest: ArrayMemoryStructure );
	BEGIN
		dest^ := src^;
	END AMSCopyShallow;
*)

(** description copy: fields of ArrayMemoryStructure are copied deep but not data *)
	PROCEDURE AMSCopyDescr( src: ArrayMemoryStructure;  dest: ArrayMemoryStructure );
	BEGIN
		dest^ := src^;  NEW( dest.len, src.dim );  CopyIndexArray( src.len^, dest.len );  NEW( dest.diminc, src.dim );
		CopyIndexArray( src.diminc^, dest.diminc );  NEW( dest.origin, src.dim );  CopyIndexArray( src.origin^, dest.origin );
	END AMSCopyDescr;

	PROCEDURE EnumArrayPart( mem: ArrayMemoryStructure;  pos, len: IndexArray;  chunks: BOOLEAN ): Enumerator;
	VAR enum: Enumerator;  i: LONGINT;  check: BOOLEAN;
	BEGIN
		check := FALSE;
		IF pos = NIL THEN pos := mem.origin ELSE check := TRUE;  END;
		IF len = NIL THEN len := mem.len ELSE check := TRUE;  END;
		(* consistency check *)
		IF check THEN
			IF (LEN( pos ) # mem.dim) OR (LEN( len ) # mem.dim) THEN HALT( 1000 ) END;
			i := 0;
			WHILE (i < mem.dim) DO
				IF (pos[i] < mem.origin[i]) OR (pos[i] + len[i] > mem.origin[i] + mem.len[i]) THEN HALT( 1001 ) END;
				INC( i );
			END;
		END;

		NEW( enum, mem, pos, len, chunks );  RETURN enum;
	END EnumArrayPart;

	(*
(* included in EnumArrayPart with: pos=NIL,len=NIL but slightly faster: *)
	PROCEDURE EnumArray( mem: ArrayMemoryStructure;  chunks: BOOLEAN ): Enumerator;
	VAR enum: Enumerator;
	BEGIN
		NEW( enum, mem, mem.origin, mem.len, chunks );  RETURN enum;
	END EnumArray;
*)

(** Traverse memory elementwise with a function proc, proc must be the adress of a  PROCEDURE (VAR l: (elementtype) );
		example with basic type LONGREAL:  TraverseMemory(ADDRESSOF(p),mem); with p := PROCEDURE (VAR l: LONGREAL); *)
	PROCEDURE TraverseMemory*( proc: Address;  mem: ArrayMemoryStructure );
	VAR enum: Enumerator;  len, diminclen, adr: LONGINT;

		PROCEDURE PushAdrAndCall( adr: LONGINT;  calladr: LONGINT );
		CODE {SYSTEM.i386}
			PUSH	[EBP+adr]	;
			CALL	[EBP+calladr]	;
			ADD	ESP, 4
		END PushAdrAndCall;

	BEGIN
		enum := EnumArrayPart( mem, NIL , NIL , FALSE );  diminclen := mem.elementsize;
		REPEAT
			len := enum.size;  adr := enum.adr;
			WHILE (len > 0) DO PushAdrAndCall( adr, proc );  DEC( len, diminclen );  INC( adr, diminclen );  END;
		UNTIL ~enum.Next();
	END TraverseMemory;

(** Traverse memory elementwise with a function proc, proc must be the adress of a  PROCEDURE (VAR l,r: (elementtype) );
	example with basic type LONGREAL;  TraverseMemory(ADDRESSOF(p),left,right); with p := PROCEDURE (VAR l,r: LONGREAL); *)
	PROCEDURE TraverseMemory2*( proc: Address;  srcmem, destmem: ArrayMemoryStructure );
	VAR src, dest: Enumerator;

		PROCEDURE PushAdrAndCall2( src, dest: LONGINT;  calladr: LONGINT );
		CODE {SYSTEM.i386}
			PUSH	[EBP+src]	;
			PUSH	[EBP+dest]
			CALL	[EBP+calladr]	;
			ADD	ESP, 8
		END PushAdrAndCall2;

	BEGIN
		ASSERT ( srcmem.elementsize = destmem.elementsize );
		src := EnumArrayPart( srcmem, NIL , NIL , FALSE );  dest := EnumArrayPart( destmem, NIL , NIL , FALSE );
		REPEAT PushAdrAndCall2( src.adr, dest.adr, proc );  UNTIL ~(src.Next() & dest.Next());
	END TraverseMemory2;

(** Traverse memory elementwise with a function proc, proc must be the adress of a  PROCEDURE (VAR l,r: (elementtype) );
	example with basic type LONGREAL;  TraverseMemory(ADDRESSOF(p),left,right,dest); with p := PROCEDURE (VAR l,r,d: LONGREAL); *)
	PROCEDURE TraverseMemory3*( proc: Address;  leftmem, rightmem, destmem: ArrayMemoryStructure );
	VAR left, right, dest: Enumerator;

		PROCEDURE PushAdrAndCall3( left, right, dest: LONGINT;  calladr: LONGINT );
		CODE {SYSTEM.i386}
			PUSH	[EBP+left]	;
			PUSH	[EBP+right]	;
			PUSH	[EBP+dest]	;
			CALL	[EBP+calladr]	;
			ADD	ESP, 12
		END PushAdrAndCall3;

	BEGIN
		ASSERT ( leftmem.elementsize = rightmem.elementsize );
		ASSERT ( rightmem.elementsize = destmem.elementsize );
		left := EnumArrayPart( leftmem, NIL , NIL , FALSE );  right := EnumArrayPart( rightmem, NIL , NIL , FALSE );
		dest := EnumArrayPart( destmem, NIL , NIL , FALSE );
		REPEAT PushAdrAndCall3( left.adr, right.adr, dest.adr, proc );  UNTIL ~(left.Next() & right.Next() & dest.Next());
	END TraverseMemory3;

	PROCEDURE TraverseAndCopy( src, dest: Enumerator );
	VAR srcdiminclen, destdiminclen, diminclen, srcadr, destadr: LONGINT;
	BEGIN
		srcadr := src.adr;  destadr := dest.adr;  srcdiminclen := src.size;  destdiminclen := dest.size;
		IF (srcdiminclen < destdiminclen) THEN diminclen := srcdiminclen ELSE diminclen := destdiminclen END;
		REPEAT
			IF debug THEN dbgSISISI( "Traverse and copy: ", srcadr, ",", destadr, ",", diminclen );  END;
			SYSTEM.MOVE( srcadr, destadr, diminclen );  DEC( srcdiminclen, diminclen );  DEC( destdiminclen, diminclen );
			INC( srcadr, diminclen );  INC( destadr, diminclen );
			IF srcdiminclen = 0 THEN
				IF src.Next() THEN srcdiminclen := src.size;  srcadr := src.adr END;
			END;
			IF destdiminclen = 0 THEN
				IF dest.Next() THEN destdiminclen := dest.size;  destadr := dest.adr END;
			END;
		UNTIL (srcdiminclen = 0) OR (destdiminclen = 0);
		IF (srcdiminclen # 0) OR (destdiminclen # 0) THEN
			dbgS( "WARNING: Traverse and Copy: DIFFERENT SIZES " );
			IF debug THEN HALT( 1003 ) END;
		END;
	END TraverseAndCopy;

(** copy procedure, copies data from srcmem to destmem going through src and dest elementwise.
	This procedure does NOT check for same dimensions and does NOT observe limits in each dimension but it respects global limits
	example: copying two dimensional 3x2-Matrix to one dimensional vector with length 5 yields:
	a[0,0] -> v[0], a[0,1] -> v[1], a[1,0] -> v[2], a[1,1] -> v[3], a[2,0] -> v[4]
	*)
	PROCEDURE CopyDataByCoordinateTraversal*( srcmem, destmem: ArrayMemoryStructure );
	VAR src, dest: Enumerator;
	BEGIN
		IF srcmem.elementsize # destmem.elementsize THEN HALT( 100 ) END;
		src := EnumArrayPart( srcmem, NIL , NIL , TRUE );  dest := EnumArrayPart( destmem, NIL , NIL , TRUE );
		TraverseAndCopy( src, dest );
	END CopyDataByCoordinateTraversal;

	PROCEDURE CopyDataRaw*( srcmem, destmem: ArrayMemoryStructure );
	VAR len: LONGINT;
	BEGIN
		len := Min( srcmem.bytes, destmem.bytes );  SYSTEM.MOVE( srcmem.baseadr, destmem.baseadr, len );
	END CopyDataRaw;

	PROCEDURE CopyDataPositionPreserving*( srcmem, destmem: ArrayMemoryStructure );
	VAR pos, len: IndexArray;  src, dest: Enumerator;
	BEGIN
		IF Intersect( srcmem.origin, srcmem.len, destmem.origin, destmem.len, pos, len ) THEN
			src := EnumArrayPart( srcmem, pos, len, TRUE );  dest := EnumArrayPart( destmem, pos, len, TRUE );
			TraverseAndCopy( src, dest );
		END;
	END CopyDataPositionPreserving;

	PROCEDURE MakeMemoryStructure*( dim: LONGINT;  origin, len: IndexArray;  elementsize: Index;
																 baseadr: Address ): ArrayMemoryStructure;
	VAR memory: ArrayMemoryStructure;
	BEGIN
		NEW( memory );  memory.dim := dim;  NEW( memory.len, dim );  NEW( memory.diminc, dim );  NEW( memory.origin, dim );
		memory.elementsize := elementsize;  memory.baseadr := baseadr;  memory.adrwoffset := baseadr;

		Array1dBytes.MoveB( ADDRESSOF( len[0] ), ADDRESSOF( memory.len[0] ), SIZEOF( LONGINT ) * dim );
		Array1dBytes.MoveB( ADDRESSOF( origin[0] ), ADDRESSOF( memory.origin[0] ), SIZEOF( LONGINT ) * dim );
		ComputeIncrease( memory.len, NIL , elementsize, memory.diminc );

		(*  (* bug fixed in Vs 1.1 *)	(** check: *)
		i := 0;  uadr := 0;
		WHILE (i < dim) DO INC( uadr, (memory.len[i] - 1) * memory.diminc[i] );  INC( i );  END;
		memory.bytes := uadr;  *)

		memory.bytes := memory.diminc[dim - 1] * memory.len[dim - 1];  RETURN memory;
	END MakeMemoryStructure;

	PROCEDURE MakeContinuousMemStruct*( adr, elements, elementsize: LONGINT;  VAR memory: ArrayMemoryStructure );
	BEGIN
		IF memory = NIL THEN NEW( memory ) END;
		IF memory.dim # 1 THEN memory.dim := 1;  NEW( memory.len, 1 );  NEW( memory.diminc, 1 );  NEW( memory.origin, 1 );  END;
		memory.len[0] := elements;  memory.diminc[0] := elementsize;  memory.origin[0] := 0;
		memory.elementsize := elementsize;  memory.bytes := elements * elementsize;  memory.baseadr := adr;
	END MakeContinuousMemStruct;

	PROCEDURE CheckEqDimensions*( l, r: Array );
	(*! optimzie -> inline:  *)
	VAR i: LONGINT;
	BEGIN
		CheckEQ( l.dim, r.dim );  CheckEQ( l.elementsize, r.elementsize );
		FOR i := 0 TO l.dim - 1 DO CheckEQ( l.len[i], r.len[i] );  CheckEQ( l.origin[i], r.origin[i] );  END;
	END CheckEqDimensions;

	PROCEDURE ToggleDimensions*( a: Array;  d1, d2: LONGINT;  rearrangeMemory: BOOLEAN );
	VAR permutation: IndexArray;
	BEGIN
		permutation := IdentityPermutation( a.dim );  permutation[d1] := d2;  permutation[d2] := d1;
		a.PermuteDimensions( permutation, rearrangeMemory );
	END ToggleDimensions;

	PROCEDURE dbgS( s: ARRAY OF CHAR );
	BEGIN
		dbgOut.String( s );  dbgOut.Ln;
	END dbgS;

	PROCEDURE dbgSI( s: ARRAY OF CHAR;  i: LONGINT );
	BEGIN
		dbgOut.String( s );  dbgOut.Int( i, 10 );  dbgOut.Ln;
	END dbgSI;

	PROCEDURE dbgSISI( s: ARRAY OF CHAR;  i: LONGINT;  s2: ARRAY OF CHAR;  i2: LONGINT );
	BEGIN
		dbgOut.String( s );  dbgOut.Int( i, 1 );  dbgOut.String( s2 );  dbgOut.Int( i2, 1 );  dbgOut.Ln;
	END dbgSISI;

	PROCEDURE dbgSISISI( s: ARRAY OF CHAR;  i: LONGINT;  s2: ARRAY OF CHAR;  i2: LONGINT;  s3: ARRAY OF CHAR;  i3: LONGINT );
	BEGIN
		dbgOut.String( s );  dbgOut.Int( i, 1 );  dbgOut.String( s2 );  dbgOut.Int( i2, 1 );  dbgOut.String( s3 );
		dbgOut.Int( i3, 1 );  dbgOut.Ln;
	END dbgSISISI;

	PROCEDURE dbgWriteMemoryInfo*( a: ArrayMemoryStructure );
	VAR i: LONGINT;
	BEGIN
		dbgS( "---------------------------------" );  dbgS( "DebugInfo for ArrayXdBytes.Array: " );  dbgSISI( "Array with dimension", a.dim, " and elementsize: ", a.elementsize );  dbgSISI( "Adress:", a.baseadr, "; bytes used:", a.bytes );  dbgSI( "Adr with offset:", a.adrwoffset );

		FOR i := 0 TO a.dim - 1 DO dbgS( "----------" );  dbgSI( "Index: ", i );  dbgSISISI( "origin= ", a.origin[i], ",len=", a.len[i], "diminc= ", a.diminc[i] );  END;

		IF a IS Array THEN
			WITH a: Array DO dbgS( "----------" );  dbgSISI( "f0=", a.f0, "; f1=", a.f1 );  dbgSISI( "f2=", a.f2, "; f3=", a.f3 );
			END;
		END;
		dbgS( "---------------------------------" );

	END dbgWriteMemoryInfo;

	PROCEDURE Adr1*( a: Array;  x: Index ): Index;
	(*! optimzie -> inline:  *)
	VAR adr: Index;
	BEGIN
		adr := a.adrwoffset + x * a.f0;  Array1dBytes.AdrCheck( adr, a.baseadr, a.bytes );  RETURN adr;
	END Adr1;

	PROCEDURE Adr2*( a: Array;  x, y: Index ): Index;
	(*! optimzie -> inline:  *)
	VAR adr: Index;
	BEGIN
		adr := a.adrwoffset + x * a.f0 + y * a.f1;  Array1dBytes.AdrCheck( adr, a.baseadr, a.bytes );  RETURN adr;
	END Adr2;

	PROCEDURE Adr3*( a: Array;  x, y, z: Index ): Index;
	(*! optimzie -> inline:  *)
	VAR adr: Index;
	BEGIN
		adr := a.adrwoffset + x * a.f0 + y * a.f1 + z * a.f2;  Array1dBytes.AdrCheck( adr, a.baseadr, a.bytes );  RETURN adr;
	END Adr3;

	PROCEDURE Adr4*( a: Array;  x, y, z, t: Index ): Index;
	(*! optimzie -> inline:  *)
	VAR adr: Index;
	BEGIN
		adr := a.adrwoffset + x * a.f0 + y * a.f1 + z * a.f2 + t * a.f3;  Array1dBytes.AdrCheck( adr, a.baseadr, a.bytes );
		RETURN adr;
	END Adr4;

	PROCEDURE AdrX*( a: ArrayMemoryStructure;  VAR b: ARRAY OF Index;  dim: Index ): Index;
	(*! optimzie -> inline:  *)
	VAR adr, i: Index;
	BEGIN
		CheckLEQ( dim, a.dim );  adr := a.adrwoffset;  i := 0;
		WHILE (i < dim) DO adr := adr + a.diminc[i] * b[i];   (* a.IncUsage( i, b[i] + 1 ); *) INC( i );  END;
		Array1dBytes.AdrCheck( adr, a.baseadr, a.bytes );  RETURN adr;
	END AdrX;

	(*
	fof 080728: open array return value not allowed any more
	PROCEDURE Array1*( x: LONGINT ): ARRAY OF LONGINT;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 1 );  index[0] := x;  RETURN index^;
	END Array1;
	*)


	PROCEDURE Index1*( x: LONGINT ): IndexArray;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 1 );  index[0] := x;  RETURN index;
	END Index1;

	PROCEDURE Array1*( x: LONGINT ): IndexArray;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 1 );  index[0] := x;  RETURN index;
	END Array1;


	(*
fof 080728: open array return value not allowed any more	PROCEDURE Array2*( x, y: LONGINT ): ARRAY OF LONGINT;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 2 );  index[0] := x;  index[1] := y;  RETURN index^
	END Array2;
	*)

	PROCEDURE Index2*( x, y: LONGINT ): IndexArray;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 2 );  index[0] := x;  index[1] := y;  RETURN index
	END Index2;

	PROCEDURE Array2*( x, y: LONGINT ): IndexArray;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 2 );  index[0] := x;  index[1] := y;  RETURN index
	END Array2;

	(*
fof 080728: open array return value not allowed any more	PROCEDURE Array3*( x, y, z: LONGINT ): ARRAY OF LONGINT;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 3 );  index[0] := x;  index[1] := y;  index[2] := z;  RETURN index^;
	END Array3;
	*)
	PROCEDURE Array3*( x, y, z: LONGINT ): IndexArray;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 3 );  index[0] := x;  index[1] := y;  index[2] := z;  RETURN index;
	END Array3;


	PROCEDURE Index3*( x, y, z: LONGINT ): IndexArray;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 3 );  index[0] := x;  index[1] := y;  index[2] := z;  RETURN index;
	END Index3;

	(*
	fof 080728: open array return value not allowed any more
	PROCEDURE Array4*( x, y, z, t: LONGINT ): ARRAY OF LONGINT;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 4 );  index[0] := x;  index[1] := y;  index[2] := z;  index[3] := t;  RETURN index^;
	END Array4;
	*)

	PROCEDURE Index4*( x, y, z, t: LONGINT ): IndexArray;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 4 );  index[0] := x;  index[1] := y;  index[2] := z;  index[3] := t;  RETURN index;
	END Index4;

	PROCEDURE Array4*( x, y, z, t: LONGINT ): IndexArray;
	(*! optimzie -> inline:  *)
	VAR index: IndexArray;
	BEGIN
		NEW( index, 4 );  index[0] := x;  index[1] := y;  index[2] := z;  index[3] := t;  RETURN index;
	END Array4;

	PROCEDURE IndexX*( VAR a: ARRAY OF LONGINT ): IndexArray;
	VAR index: IndexArray;
	BEGIN
		NEW( index, LEN( a ) );  SYSTEM.MOVE( ADDRESSOF( a[0] ), ADDRESSOF( index[0] ), LEN( a ) * SIZEOF( LONGINT ) );  RETURN index;
	END IndexX;

	PROCEDURE IndexCpy*( src: IndexArray ): IndexArray;
	VAR dest: IndexArray;  i: LONGINT;
	BEGIN
		NEW( dest, LEN( src ) );  i := 0;
		WHILE (i < LEN( dest )) DO dest[i] := src[i];  INC( i );  END;
		RETURN dest;
	END IndexCpy;

	PROCEDURE Get1*( a: Array;  x: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		SYSTEM.MOVE( Adr1( a, x ), ADDRESSOF( v ), a.elementsize );
	END Get1;

	PROCEDURE Get2*( a: Array;  x, y: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		SYSTEM.MOVE( Adr2( a, x, y ), ADDRESSOF( v ), a.elementsize );
	END Get2;

	PROCEDURE Get3*( a: Array;  x, y, z: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		SYSTEM.MOVE( Adr3( a, x, y, z ), ADDRESSOF( v ), a.elementsize );
	END Get3;

	PROCEDURE Get4*( a: Array;  x, y, z, t: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		SYSTEM.MOVE( Adr4( a, x, y, z, t ), ADDRESSOF( v ), a.elementsize );
	END Get4;

	PROCEDURE GetX*( a: Array;  VAR b: ARRAY OF Index;  dim: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		(* dimension is checked in AdrX *)
		SYSTEM.MOVE( AdrX( a, b, dim ), ADDRESSOF( v ), a.elementsize );
	END GetX;

	PROCEDURE Set1*( a: Array;  x: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		SYSTEM.MOVE( ADDRESSOF( v ), Adr1( a, x ), a.elementsize );
	END Set1;

	PROCEDURE Set2*( a: Array;  x, y: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		SYSTEM.MOVE( ADDRESSOF( v ), Adr2( a, x, y ), a.elementsize );
	END Set2;

	PROCEDURE Set3*( a: Array;  x, y, z: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		SYSTEM.MOVE( ADDRESSOF( v ), Adr3( a, x, y, z ), a.elementsize );
	END Set3;

	PROCEDURE Set4*( a: Array;  x, y, z, t: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		SYSTEM.MOVE( ADDRESSOF( v ), Adr4( a, x, y, z, t ), a.elementsize );
	END Set4;

	PROCEDURE SetX*( a: Array;  VAR b: ARRAY OF Index;  dim: Index;  VAR v: ARRAY OF SYSTEM.BYTE );
	(*! optimzie -> inline:  *)
	BEGIN
		IF LEN( v ) # a.elementsize THEN HALT( 100 ) END;
		SYSTEM.MOVE( ADDRESSOF( v ), AdrX( a, b, dim ), a.elementsize );
	END SetX;

	(*
	PROCEDURE SubArrayMemoryStructure*( a: Array;  pos: ARRAY OF Index;  dims, len: ARRAY OF Index;  VAR memory: ArrayMemoryStructure );
	(* dimension of Memory LEN(origin)=LEN(len) *)
	VAR dim, i, thisdim: LONGINT;
	BEGIN
		dim := LEN( dims );
		IF (dim # LEN( len )) THEN HALT( 100 ) END;
		IF (LEN( pos ) # a.dim) THEN HALT( 101 ) END;
		CheckLEQ( dim, a.dim );
		WHILE (i < dim) DO thisdim := dims[i];  dims[i] := a.diminc[thisdim];  INC( i );  END;
		MakeMemoryStructure( dim, len, dims, AdrX( a, pos, a.dim ), a.baseadr + a.bytes, a.elementsize, memory );
	END SubArrayMemoryStructure;
	*)

(** copy part of one array to another, may also be used to extract dimensions from array a to b,
	example: a= 3x4 matrix , v= vector with len 10
	CopyArrayParts(a,v,(1,1),(1,4),(2),(4)) copies elements 1-4 of column 1 to vector beginning at position 2 *)
	PROCEDURE CopyArrayPartToArrayPart*( srcmem, destmem: ArrayMemoryStructure;
																	  srcpos, srclen, destpos, destlen: IndexArray );
	VAR src, dest: Enumerator;
	BEGIN
		src := EnumArrayPart( srcmem, srcpos, srclen, TRUE );  dest := EnumArrayPart( destmem, destpos, destlen, TRUE );
		TraverseAndCopy( src, dest );
	END CopyArrayPartToArrayPart;

	PROCEDURE FillArrayPart*( mem: ArrayMemoryStructure;  pos, len: IndexArray;  val: ARRAY OF SYSTEM.BYTE );
	VAR src: Enumerator;  nrElems: LONGINT;
	BEGIN
		IF LEN( val ) # mem.elementsize THEN HALT( 1001 ) END;
		src := EnumArrayPart( mem, pos, len, TRUE );  nrElems := src.size DIV mem.elementsize;
		REPEAT Array1dBytes.Fill( src.adr, val, nrElems );  UNTIL ~src.Next();

	END FillArrayPart;

	PROCEDURE CopyArrayToMemory*( srcmem: ArrayMemoryStructure;  destadr: Index;  nrelems: Index );
	VAR destmem: ArrayMemoryStructure;
	BEGIN
		IF nrelems * srcmem.elementsize > srcmem.bytes THEN HALT( 1001 ) END;
		MakeContinuousMemStruct( destadr, nrelems, srcmem.elementsize, destmem );
		CopyDataByCoordinateTraversal( srcmem, destmem );
	END CopyArrayToMemory;

(** copy memory fromadr -> adr, bytes *)
	PROCEDURE CopyMemoryToArray*( srcadr: Index;  destmem: ArrayMemoryStructure;  nrelems: Index );
	VAR srcmem: ArrayMemoryStructure;
	BEGIN
		IF nrelems * destmem.elementsize > destmem.bytes THEN HALT( 1001 ) END;
		MakeContinuousMemStruct( srcadr, nrelems, destmem.elementsize, srcmem );
		CopyDataByCoordinateTraversal( srcmem, destmem );
	END CopyMemoryToArray;

	PROCEDURE CopyArrayPartToMemory*( srcmem: ArrayMemoryStructure;  destadr: Index;  srcpos, srclen: IndexArray;
																	destlen: Index );
	VAR src, dest: Enumerator;  destmem: ArrayMemoryStructure;
	BEGIN
		MakeContinuousMemStruct( destadr, destlen, srcmem.elementsize, destmem );
		src := EnumArrayPart( srcmem, srcpos, srclen, TRUE );  dest := EnumArrayPart( destmem, NIL , NIL , TRUE );
		TraverseAndCopy( src, dest );

	END CopyArrayPartToMemory;

	PROCEDURE CopyMemoryToArrayPart*( srcadr: Index;  destmem: ArrayMemoryStructure;  srclen: Index;
																	destpos, destlen: IndexArray );
	VAR src, dest: Enumerator;  srcmem: ArrayMemoryStructure;
	BEGIN
		MakeContinuousMemStruct( srcadr, srclen, destmem.elementsize, srcmem );
		src := EnumArrayPart( srcmem, NIL , NIL , TRUE );  dest := EnumArrayPart( destmem, destpos, destlen, TRUE );
		TraverseAndCopy( src, dest );
	END CopyMemoryToArrayPart;

	PROCEDURE -InBounds*( origin, len: Index;  idx: Index ): BOOLEAN;
	CODE {SYSTEM.i386}
		; if (idx < origin) or (idx-origin >= len) then return false end;
		; return true;
		; AL=1 : TRUE; AL=0: FALSE
		MOV	EAX, [ESP]	;  EAX := idx
		MOV	EBX, [ESP+4]	;  EBX := len
		MOV	ECX, [ESP+8]	;  ECX := origin
		CMP	EAX, ECX	;
		JL	outbound	;  idx < origin: outbound
		SUB	EAX, ECX
		CMP	EAX, EBX
		JGE	outbound	;  (idx-origin) >= len
		MOV	AL, 1
		JMP	done	;
		outbound:
		MOV	AL, 0
		done:
		ADD	ESP, 12
	END InBounds;

	PROCEDURE -PeriodicBounds*( origin, len: Index;  idx: Index ): Index;
	CODE {SYSTEM.i386}
		; DEC( idx, origin );  idx := idx MOD len;  INC( idx, origin );

		; modulus:
		; a := b MOD c; 	c -> EBX	; b -> EAX

		; CDQ
		; IDIV EBX
		; CMP     EDX,0
		; JNL     2
		; ADD     EDX,EBX

		; EDX -> a

		MOV	EAX, [ESP]	;  EAX := idx
		SUB	EAX, [ESP+8]	;  EAX := EAX-origin
		MOV	EBX, [ESP+4]	;  EBX := len
		CDQ
		IDIV	EBX
		CMP	EDX, 0
		JNL	2
		ADD	EDX, EBX
		MOV	EAX, EDX
		ADD	EAX, [ESP+8]
		ADD	ESP, 12
	END PeriodicBounds;

	PROCEDURE MirrorOnB*( origin, len: Index;  idx: Index ): Index;   (* mirror on origin / origin + len, infinite domain*)
	(*! optimize -> inline *)
	BEGIN
		IF len = 1 THEN RETURN idx END;
		DEC( idx, origin );  DEC( len );
		IF ODD( idx DIV (len) ) THEN RETURN origin + len - idx MOD (len);  ELSE RETURN origin + idx MOD (len) END;
	END MirrorOnB;

	PROCEDURE MirrorOffB*( origin, len: Index;  idx: Index ): Index;   (* mirror between origin and origin -1  / origin + len and origin +len+1, infinite domain*)
	(*! optimize -> inline *)
	BEGIN
		DEC( idx, origin );
		IF ODD( idx DIV len ) THEN RETURN origin + (-idx - 1) MOD (len) ELSE RETURN origin + idx MOD len;  END;
	END MirrorOffB;

	PROCEDURE TestB*;
	VAR i: Index;
	BEGIN
		FOR i := -30 TO 30 DO dbgOut.Int( i, 1 );  dbgOut.String( ":" );  dbgOut.Int( MirrorOffB( 2, 7, i ), 1 );  dbgOut.Ln;  END;
		FOR i := -30 TO 30 DO dbgOut.Int( i, 1 );  dbgOut.String( ":" );  dbgOut.Int( MirrorOnB( 2, 7, i ), 1 );  dbgOut.Ln;  END;

	END TestB;

END ArrayXdBytes.
ArrayXdBytes.TestB ~
