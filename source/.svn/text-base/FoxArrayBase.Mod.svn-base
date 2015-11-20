MODULE FoxArrayBase; (* stubs for array base runtime - can only be compiled by oc compiler *)
(* (c) fof, fn, ETH Zürich, 2008 *)


(*! do  do: MAX(array,scalar) and MAX(array,array) for all datatypes*)

IMPORT SYSTEM, KernelLog, Heaps, Math, MathL;

TYPE
	Address = LONGINT;
	
	GenericUnaryAALoopS = PROCEDURE ( ladr, dadr, linc, dinc, len: Address; op: PROCEDURE(x: SHORTINT): SHORTINT );
	GenericUnaryAALoopI = PROCEDURE ( ladr, dadr, linc, dinc, len: Address; op: PROCEDURE(x: INTEGER): INTEGER );
	GenericUnaryAALoopL = PROCEDURE ( ladr, dadr, linc, dinc, len: Address; op: PROCEDURE(x: LONGINT): LONGINT );
	GenericUnaryAALoopH = PROCEDURE ( ladr, dadr, linc, dinc, len: Address; op: PROCEDURE(x: HUGEINT): HUGEINT );
	GenericUnaryAALoopR = PROCEDURE ( ladr, dadr, linc, dinc, len: Address; op: PROCEDURE(x: REAL): REAL );
	GenericUnaryAALoopX = PROCEDURE ( ladr, dadr, linc, dinc, len: Address; op: PROCEDURE(x: LONGREAL): LONGREAL );
	GenericUnaryAALoopZ = PROCEDURE ( ladr, dadr, linc, dinc, len: Address; op: PROCEDURE(x: COMPLEX): COMPLEX );
	GenericUnaryAALoopLZ = PROCEDURE ( ladr, dadr, linc, dinc, len: Address; op: PROCEDURE(x: LONGCOMPLEX): LONGCOMPLEX );
	UnaryAALoop = PROCEDURE ( ladr, dadr, linc, dinc, len: Address );
	UnaryASLoop = PROCEDURE ( ladr, dadr, linc, len: Address );
	UnarySALoop = PROCEDURE ( ladr, dadr, dinc, len: Address );
	BinaryAAALoop = PROCEDURE ( ladr, radr, dadr, linc, rinc, dinc, len: Address );
	BinaryASALoop = PROCEDURE ( ladr, radr, dadr, linc, dinc, len: Address );
	BinaryAASLoop = PROCEDURE ( ladr, radr, dadr, linc, rinc, len: Address );
	BinaryAABLoop = PROCEDURE ( ladr, radr, linc, rinc, len: Address ): BOOLEAN;
	BinaryASBLoop = PROCEDURE ( ladr, radr, linc, len: Address ): BOOLEAN;
CONST
	debug = FALSE;   (* warning: debug=true -> a lot of output is generated -> traps are not displayed in Oberon (Kernel overflow) *)
	statistics= FALSE;
	conservative=TRUE;

	ArrDataArrayOffset=16; (* offset of data in array with pointers *)

	AddressSize=SIZEOF(Address);
	MathPtrOffset=0*AddressSize;
	MathAdrOffset=1*AddressSize;
	MathFlagsOffset=2*AddressSize;
	MathDimOffset=3*AddressSize;
	MathElementSizeOffset=4*AddressSize;
	MathLenOffset=5*AddressSize;
	MathIncrOffset=6*AddressSize;

	GeometryMismatch = 400;
	DimensionMismatch=401;
	AllocationForbidden=402;

	TensorFlag = 0;  RangeFlag = 1;  TemporaryFlag = 2;

	down = 0;  up = 1;   (* memory copy modes *)

	(* flags for optimizations with small matricies and vectors (Alexey Morozov) *)
	SmallMatrixFlag = 3; (* flag for identification of a small matrix *)
	SmallVectorFlag = 3; (* flag for identification of a small vector *)
	Size2Flag = 4; (* size = 2 *)
	Size3Flag = 5; (* size = 3 *)
	Size4Flag = 6; (* size = 4 *)
	Size5Flag = 7; (* size = 5 *)
	Size6Flag = 8; (* size = 6 *)
	Size7Flag = 9; (* size = 7 *)
	Size8Flag = 10; (* size = 8 *)

	Mat2x2 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,Size2Flag});
	Mat3x3 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,Size3Flag});
	Mat4x4 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,Size4Flag});
	Mat5x5 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,Size5Flag});
	Mat6x6 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,Size6Flag});
	Mat7x7 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,Size7Flag});
	Mat8x8 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,Size8Flag});

	Vec2 = SYSTEM.VAL(LONGINT,{SmallVectorFlag,Size2Flag});
	Vec3 = SYSTEM.VAL(LONGINT,{SmallVectorFlag,Size3Flag});
	Vec4 = SYSTEM.VAL(LONGINT,{SmallVectorFlag,Size4Flag});
	Vec5 = SYSTEM.VAL(LONGINT,{SmallVectorFlag,Size5Flag});
	Vec6 = SYSTEM.VAL(LONGINT,{SmallVectorFlag,Size6Flag});
	Vec7 = SYSTEM.VAL(LONGINT,{SmallVectorFlag,Size7Flag});
	Vec8 = SYSTEM.VAL(LONGINT,{SmallVectorFlag,Size8Flag});

	MatVec2x2 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,SmallVectorFlag,Size2Flag});
	MatVec3x3 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,SmallVectorFlag,Size3Flag});
	MatVec4x4 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,SmallVectorFlag,Size4Flag});
	MatVec5x5 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,SmallVectorFlag,Size5Flag});
	MatVec6x6 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,SmallVectorFlag,Size6Flag});
	MatVec7x7 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,SmallVectorFlag,Size7Flag});
	MatVec8x8 = SYSTEM.VAL(LONGINT,{SmallMatrixFlag,SmallVectorFlag,Size8Flag});

	SmallArrayMask = {SmallMatrixFlag,SmallVectorFlag,Size2Flag,Size3Flag,Size4Flag,Size5Flag,Size6Flag,Size7Flag,Size8Flag};

TYPE
	FastMatMul* = PROCEDURE ( matrixA, matrixB, matrixC, IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: LONGINT ): BOOLEAN;
	TransposeP* = PROCEDURE ( ladr, dadr, lstride, linc, dstride, dinc, rows, cols: LONGINT );

	(* tensor shape descriptors, statically typed, maximal dimension of a tensor limited to 32 for the time being *)
	T0 = POINTER TO RECORD ptr: ANY; a: ARRAY MathLenOffset + 0* 8 OF CHAR END;
	T1 = POINTER TO RECORD ptr: ANY; a:ARRAY MathLenOffset + 1 * 8 OF CHAR END;
	T2 = POINTER TO RECORD ptr: ANY; a:ARRAY MathLenOffset + 2 * 8 OF CHAR END;
	T3 = POINTER TO RECORD ptr: ANY; a:ARRAY MathLenOffset + 3 * 8 OF CHAR END;
	T4 = POINTER TO RECORD ptr: ANY; a:ARRAY MathLenOffset + 4 * 8 OF CHAR END;
	T5 = POINTER TO RECORD ptr: ANY; a:ARRAY MathLenOffset + 5 * 8 OF CHAR END;
	T6 = POINTER TO RECORD ptr: ANY; a:ARRAY MathLenOffset + 6 * 8 OF CHAR END;
	T7 = POINTER TO RECORD ptr: ANY; a:ARRAY MathLenOffset + 7 * 8 OF CHAR END;
	T8 = POINTER TO RECORD ptr: ANY; a:ARRAY MathLenOffset + 8 * 8 OF CHAR END;
	T9 = POINTER TO RECORD ptr: ANY; a:ARRAY MathLenOffset + 9 * 8 OF CHAR END;
	T10 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 10 * 8 OF CHAR END;
	T11 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 11 * 8 OF CHAR END;
	T12 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 12 * 8 OF CHAR END;
	T13 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 13 * 8 OF CHAR END;
	T14 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 14 * 8 OF CHAR END;
	T15 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 15 * 8 OF CHAR END;
	T16 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 16 * 8 OF CHAR END;
	T17 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 17 * 8 OF CHAR END;
	T18 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 18 * 8 OF CHAR END;
	T19 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 19 * 8 OF CHAR END;
	T20 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 20 * 8 OF CHAR END;
	T21 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 21 * 8 OF CHAR END;
	T22 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 22 * 8 OF CHAR END;
	T23 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 23 * 8 OF CHAR END;
	T24 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 24 * 8 OF CHAR END;
	T25 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 25 * 8 OF CHAR END;
	T26 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 26 * 8 OF CHAR END;
	T27 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 27 * 8 OF CHAR END;
	T28 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 28 * 8 OF CHAR END;
	T29 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 29 * 8 OF CHAR END;
	T30 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 30 * 8 OF CHAR END;
	T31 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 31 * 8 OF CHAR END;
	T32 =POINTER TO  RECORD ptr: ANY;a: ARRAY MathLenOffset + 32 * 8 OF CHAR END;

	(* used for optimizations of MatMul with small sizes (Alexey Morozov) *)
	SmallMatMul* = PROCEDURE(dadr, ladr, radr: LONGINT);


VAR
	alloc*: LONGINT;   (* statistics *)
	allocTemp*: LONGINT;   (* statistics *)

	(* procedures that might be replaced by ASM methods *)
	loopSPAXAX*, loopSPARAR*: BinaryAASLoop;
	loopSPAZAZ, loopSPALZALZ: BinaryAASLoop;
	loopAddAXAX*, loopAddARAR*, loopAddAZAZ*, loopAddALZALZ*: BinaryAAALoop;
	loopMatMulAXAX*, loopMatMulARAR*: BinaryAASLoop;
	loopMatMulIncAXAX*, loopMatMulIncARAR*: BinaryAASLoop;
	loopMulAXSX*, loopMulARSR*, loopMulAZSZ*, loopMulALZSLZ*: BinaryASALoop;
	loopIncMulAXSX*, loopIncMulARSR*: BinaryASALoop;
	matMulX*, matMulR*: FastMatMul;  matMulIncX*, matMulIncR*: FastMatMul;
	transpose4*: TransposeP;  transpose8*: TransposeP;

	(* optimizations for small arrays (Alexey Morozov) *)
	matMulR2x2*: SmallMatMul;
	matMulR3x3*: SmallMatMul;
	matMulR4x4*: SmallMatMul;

	matVecMulR2x2*: SmallMatMul;
	matVecMulR3x3*: SmallMatMul;
	matVecMulR4x4*: SmallMatMul;

	matMulLR2x2*: SmallMatMul;
	matMulLR3x3*: SmallMatMul;
	matMulLR4x4*: SmallMatMul;

	matVecMulLR2x2*: SmallMatMul;
	matVecMulLR3x3*: SmallMatMul;
	matVecMulLR4x4*: SmallMatMul;

	(*
	TensorTypePool: ARRAY 32 OF TensorType;
	*)

	PROCEDURE SetDefaults*;   (* set standard procedures *)
	BEGIN
		KernelLog.String( "ArrayBase: setting runtime library (semi-optimized) default methods." );  KernelLog.Ln;  loopSPAXAX := SPAXAXLoop;
		loopSPARAR := SPARARLoop;  loopAddAXAX := AddAXAXLoop;
		loopSPAZAZ := SPAZAZLoop; loopSPALZALZ := SPALZALZLoop;
		loopAddARAR := AddARARLoop;  loopMatMulAXAX := MatMulAXAXLoop;
		loopAddAZAZ := AddAZAZLoop; loopAddALZALZ := AddALZALZLoop;
		loopMatMulIncAXAX := MatMulIncAXAXLoop;
		loopMatMulARAR := MatMulARARLoop;  loopMulAXSX := MulAXSXLoop;
		loopIncMulAXSX := IncMulAXSXLoop;
		loopMatMulIncARAR := MatMulIncARARLoop;
		loopMulARSR := MulARSRLoop;  loopIncMulARSR := IncMulARSRLoop;
		matMulX := NIL;  matMulR := NIL;  matMulIncX := NIL;  matMulIncR := NIL;

		loopMulAZSZ := MulAZSZLoop;
		loopMulALZSLZ := MulALZSLZLoop;
	END SetDefaults;

	PROCEDURE Err(CONST s: ARRAY OF CHAR );
	BEGIN
		KernelLog.String( "Runtime Error: " );  KernelLog.String( s );  KernelLog.Ln;  HALT( 100 );
	END Err;

	(* get increment of dimension dim *)
	PROCEDURE GetIncr(base,dim: Address): LONGINT;
	VAR result: LONGINT;
	BEGIN
		SYSTEM.GET(base+MathIncrOffset+8*dim,result);
		RETURN result
	END GetIncr;

	(* set increment of dimension dim *)
	PROCEDURE PutInc(base,dim,val: Address);
	BEGIN
		SYSTEM.PUT(base+MathIncrOffset+8*dim,val)
	END PutInc;

	(* get length of dimension dim *)
	PROCEDURE GetLen(base,dim: Address): LONGINT;
	VAR result: LONGINT;
	BEGIN
		SYSTEM.GET(base+MathLenOffset+8*dim,result);
		RETURN result
	END GetLen;

	(* set length of dimension dim *)
	PROCEDURE PutLen(base,dim,val: Address);
	BEGIN
		SYSTEM.PUT(base+MathLenOffset+8*dim,val)
	END PutLen;

	(* get data address *)
	PROCEDURE GetAdr(base: Address): Address;
	VAR result: LONGINT;
	BEGIN
		SYSTEM.GET(base+MathAdrOffset,result);
		RETURN result
	END GetAdr;

	(* set data address *)
	PROCEDURE PutAdr(base,value: Address);
	BEGIN
		SYSTEM.PUT(base+MathAdrOffset,value)
	END PutAdr;

	(* get data base pointer (GC protection) *)
	PROCEDURE GetPtr(base: Address): Address;
	VAR result: LONGINT;
	BEGIN
		SYSTEM.GET(base+MathPtrOffset,result);
		RETURN result
	END GetPtr;

	(* set data base pointer (GC protection) *)
	PROCEDURE PutPtr(base,value: Address);
	BEGIN
		SYSTEM.PUT(base+MathPtrOffset,value)
	END PutPtr;

	PROCEDURE GetSize( base: Address ): LONGINT;
	VAR dim: LONGINT;
	BEGIN
		IF base = 0 THEN RETURN 0 ELSE SYSTEM.GET( base + MathElementSizeOffset, dim );  RETURN dim;  END;
	END GetSize;

	PROCEDURE PutSize( base: Address;  dim: LONGINT );
	BEGIN
		SYSTEM.PUT( base + MathElementSizeOffset, dim );
	END PutSize;

	PROCEDURE GetDim( base: Address ): LONGINT;
	VAR dim: LONGINT;
	BEGIN
		IF base = 0 THEN RETURN 0 ELSE SYSTEM.GET( base + MathDimOffset, dim );  RETURN dim;  END;
	END GetDim;

	PROCEDURE GetFlags( base: Address ): SET;
	VAR set: SET;
	BEGIN
		SYSTEM.GET( base + MathFlagsOffset, set );  RETURN set;
	END GetFlags;

	PROCEDURE PutDim( base: Address;  dim: LONGINT );
	BEGIN
		SYSTEM.PUT( base + MathDimOffset, dim );
	END PutDim;

	PROCEDURE PutFlags( base: Address;  flags: SET );
	BEGIN
		SYSTEM.PUT( base + MathFlagsOffset, flags );
	END PutFlags;

(* report geometry of array passed via address s *)
	PROCEDURE Report(CONST name: ARRAY OF CHAR;  s: LONGINT );
	VAR i: LONGINT;  dim: LONGINT;

		PROCEDURE Set( s: SET );
		VAR i: LONGINT;  first: BOOLEAN;
		BEGIN
			KernelLog.String( "{" );  first := TRUE;
			FOR i := 31 TO 0 BY -1 DO
				IF i IN s THEN
					IF ~first THEN KernelLog.String( "," );  ELSE first := FALSE END;
					KernelLog.Int( i, 1 );
				END;
			END;
			KernelLog.String( "}" );
		END Set;

	BEGIN
		KernelLog.String( name );
		IF s = 0 THEN KernelLog.String( " : NIL " );  KernelLog.Ln;
		ELSE
			KernelLog.String( " at adr " );  KernelLog.Int( s, 1 );  KernelLog.String( "; ptr= " );
			KernelLog.Int( GetPtr( s ), 1 );  KernelLog.String( "; adr= " );
			KernelLog.Int( GetAdr( s ), 1 );  KernelLog.String( "; dim=" );
			KernelLog.Int( GetDim( s ), 1 );  KernelLog.String( "; flags=" );  Set( GetFlags( s ) );
			KernelLog.Ln;  dim := GetDim( s );
			IF dim > 32 THEN dim := 0 END;
			FOR i := 0 TO dim - 1 DO
				KernelLog.String( "dim (rev)=" );  KernelLog.Int( i, 1 );  KernelLog.String( ", len=" );
				KernelLog.Int( GetLen( s, i ), 1 );  KernelLog.String( ", inc=" );
				KernelLog.Int( GetIncr( s, i ), 1 );  KernelLog.Ln;
			END;
			(*
		FindPattern1( s, dim, ldim, len, inc );  KernelLog.String( "increment: " );
		KernelLog.Int( inc, 10 );  KernelLog.Ln;  KernelLog.String( "longest dim:" );  KernelLog.Int( ldim, 10 );
		KernelLog.Ln;  KernelLog.String( "len:" );  KernelLog.Int( len, 10 );  KernelLog.Ln;
		*)
		END;
	END Report;

	PROCEDURE GetArrayDesc( dim: LONGINT ): ANY;
	VAR (* t: TensorType;  *) ptr: ANY;
		p0: T0;
		p1: T1; p2: T2; p3: T3; p4: T4; p5: T5; p6: T6; p7: T7; p8: T8; p9: T9;
		p10: T10; p11: T11; p12: T12; p13: T13; p14: T14; p15: T15; p16: T16; p17: T17; p18: T18; p19: T19;
		p20: T20; p21: T21; p22: T22; p23: T23; p24: T24; p25: T25; p26: T26; p27: T27; p28: T28; p29: T29;
		p30: T30; p31: T31; p32: T32;

	BEGIN
		(*
		IF dim < LEN( TensorTypePool ) THEN t := TensorTypePool[dim]
		ELSE NewTensorType( dim, t );
		END;
		Heaps.NewRec( ptr, t.tag );
		*)

		CASE dim OF
		|0: NEW(p0); ptr := p0;
		|1:NEW(p1); ptr := p1;
		|2:NEW(p2); ptr := p2;
		|3:NEW(p3); ptr := p3;
		|4:NEW(p4); ptr := p4;
		|5:NEW(p5); ptr := p5;
		|6:NEW(p6); ptr := p6;
		|7:NEW(p7); ptr := p7;
		|8:NEW(p8); ptr := p8;
		|9:NEW(p9); ptr := p9;
		|10:NEW(p10); ptr := p10;
		|11:NEW(p11); ptr := p11;
		|12:NEW(p12); ptr := p12;
		|13:NEW(p13); ptr := p13;
		|14:NEW(p14); ptr := p14;
		|15:NEW(p15); ptr := p15;
		|16:NEW(p16); ptr := p16;
		|17:NEW(p17); ptr := p17;
		|18:NEW(p18); ptr := p18;
		|19:NEW(p19); ptr := p19;
		|20:NEW(p20); ptr := p20;
		|21:NEW(p21); ptr := p21;
		|22:NEW(p22); ptr := p22;
		|23:NEW(p23); ptr := p23;
		|24:NEW(p24); ptr := p24;
		|25:NEW(p25); ptr := p25;
		|26:NEW(p26); ptr := p26;
		|27:NEW(p27); ptr := p27;
		|28:NEW(p28); ptr := p28;
		|29:NEW(p29); ptr := p29;
		|30:NEW(p30); ptr := p30;
		|31:NEW(p31); ptr := p31;
		|32:NEW(p32); ptr := p32;
		END;

		PutDim( SYSTEM.VAL( LONGINT, ptr ), dim );
		PutFlags( SYSTEM.VAL( LONGINT, ptr ), {TensorFlag} );  RETURN ptr;
	END GetArrayDesc;

	PROCEDURE Halt( code: LONGINT;  left, right, dest: LONGINT );
	VAR reason: ARRAY 64 OF CHAR;
	BEGIN
		IF left # 0 THEN Report( "Source operand ", left ) END;
		IF right # 0 THEN Report( "Source operand 2 ", right ) END;
		IF dest # 0 THEN Report( "Dest operand ", dest ) END;

		IF code = GeometryMismatch THEN reason := "Geometry mismatch";
		ELSIF code = DimensionMismatch THEN reason := "Dimension mismatch";
		ELSIF code = AllocationForbidden THEN reason := "Allocation forbidden for dest";
		ELSE reason := "unknown";
		END;

		KernelLog.String( "ArrayBase Halt. Reason= " );  KernelLog.String( reason );  KernelLog.Ln;

		HALT( 400 );
	END Halt;

	(** patterns  ********************************************************************)

 (* find the largest block with a regular pattern of the form offset+{i*li: 0<=i<len}. d is dimension applying to the resulting loop *)

	PROCEDURE FindPattern1( left, dim: Address;  VAR d, len, linc: LONGINT );
	BEGIN
		d := dim - 1;  len := GetLen( left, d );
		WHILE (len = 1) & (d > 0) DO DEC( d );  len := GetLen( left, d );
			END;   (* skip lower dimensions with len=1, in most cases d=0 *)
		linc := GetIncr( left, d );  DEC( d );
		WHILE (d >= 0) & (GetIncr( left, d ) = len * linc) DO
			len := len * GetLen( left, d );  DEC( d );
		END;   (* find dimension where pattern does not work any more *)
		INC( d );
		IF debug THEN
			KernelLog.String( "FindPattern1: " );  KernelLog.Int( len, 10 );  KernelLog.Int( linc, 10 );
			KernelLog.Ln;
		END;
	END FindPattern1;

(* find the largest block with a regular pattern of the form offset+{i*linc: 0<=i<len} for two arrays simultaneously. d is dimension applying to the resulting loop *)
	PROCEDURE FindPattern2( left, right: Address;  dim: LONGINT;
												 VAR d, len, linc, ri: LONGINT );
	(* geometric precondition: lengths must coincide *)
	BEGIN
		d := dim - 1;  len := GetLen( left, d );  ASSERT( len = GetLen( right, d ) );
		WHILE (len = 1) & (d > 0) DO DEC( d );  len := GetLen( left, d );  END;
		linc := GetIncr( left, d );  ri := GetIncr( right, d );  DEC( d );
		WHILE (d >= 0) & (GetIncr( left, d ) = len * linc) & (GetIncr( right, d ) = len * ri) DO
			len := len * GetLen( left, d );  DEC( d );
		END;
		INC( d );
		IF debug THEN
			KernelLog.String( "FindPattern2: " );  KernelLog.Int( d, 10 );  KernelLog.Int( len, 10 );
			KernelLog.Int( linc, 10 );  KernelLog.Int( ri, 10 );  KernelLog.Ln;
		END;
	END FindPattern2;

(* find the largest block with a regular pattern of the form offset+{i*linc: 0<=i<len} for three arrays simultaneously. d is dimension applying to the resulting loop *)
	PROCEDURE FindPattern3( left, right, dest: Address;  dim: LONGINT;
												 VAR d, len, linc, ri, di: LONGINT );
	(* geometric precondition: lengths must coincide *)
	BEGIN
		d := dim - 1;  len := GetLen( left, d );

		WHILE (len = 1) & (d > 0) DO DEC( d );  len := GetLen( left, d );
		END;
		linc := GetIncr( left, d );  ri := GetIncr( right, d );  di := GetIncr( dest, d );
		DEC( d );
		WHILE (d >= 0) & (GetIncr( left, d ) = len * linc) &
				    (GetIncr( right, d ) = len * ri) & (GetIncr( dest, d ) = len * di) DO
			len := len * GetLen( left, d );  DEC( d );
		END;
		INC( d );
		IF debug THEN
			KernelLog.String( "FindPattern3: " );  KernelLog.Int( len, 10 );  KernelLog.Int( linc, 10 );
			KernelLog.Int( ri, 10 );  KernelLog.Int( di, 10 );  KernelLog.Ln;
		END;
	END FindPattern3;

	PROCEDURE Reverse( src: Address;  dim: LONGINT );
	VAR d, sl, sr: LONGINT;
	BEGIN
		d := 0;  sl := GetAdr( src );
		WHILE (d < dim) DO
			INC( sr, GetIncr( src, d ) * (GetLen( src, d ) - 1) );
			PutInc( src, d, -GetIncr( src, d ) );  INC( d );
		END;
		PutAdr( src, sl + sr );
	END Reverse;

(* check if forward copy may be performed *)
	PROCEDURE CopyUpCompatible( dest, src: Address;  VAR modes: SET );
	VAR d, sl, sr, dl, dr: LONGINT;  dim: LONGINT;
		(* precondition: len(src,i)=len(dest,i) *)
		(* for forward src -> dest copy compatibility src must not be overwritten before src is copied.
Sufficient (but not necessary) conditions:
	1.) no overlap: src right < dest left or src left > dest right  or
    2.) same geometry and src left >= dest left
    same geometry if ginc(s)=ginc(d) with
    ginc(s)=inc(s,0)*len(s,0)+inc(s,1)*len(s,1)+...
    ginc(d)=inc(d,0)*len(d,0)+inc(d,1)*len(d,1)+...
   *)
	BEGIN
		d := 0;  sl := GetAdr( src );  sr := sl;  dl := GetAdr( dest );  dr := dl;
		dim := GetDim( src );
		WHILE (d < dim) DO
			INC( sr, GetIncr( src, d ) * (GetLen( src, d ) - 1) );
			INC( dr, GetIncr( dest, d ) * (GetLen( dest, d ) - 1) );  INC( d );
		END;

		IF (sr < dl) OR (sl > dr) THEN  (* no overlap, both directions possible *)
		ELSIF ((sr - sl) = (dr - dl)) THEN
			IF (sl = dl) THEN  (* same memory region, both directions possible *)
			ELSIF (sl > dl) THEN
				EXCL( modes, down ) (* only copy up possible *)
			ELSE  (*sl < dl*)
				EXCL( modes, up ) (* only copy down possible *)
			END;
		ELSE
			modes := modes - {down, up};   (* neither nor *)
		END;
	END CopyUpCompatible;

	PROCEDURE AllocateTemp( VAR dest: Address;  src: Address;
												  Size: LONGINT ): ANY;
	(* allocate a temporary block containing both descriptor and data *)
	VAR d, len, i: LONGINT;  p: ANY;  dim: LONGINT;
	BEGIN
		IF statistics THEN INC( allocTemp ) END;
		d := 0;  len := Size;  dim := GetDim( src );
		WHILE (d < dim) DO len := len * GetLen( src, d );  INC( d );  END;
		INC( len, 2 * dim * SIZEOF( LONGINT ) + MathLenOffset );  SYSTEM.NEW( p, len );
		dest := SYSTEM.VAL( LONGINT, p );
		PutAdr( dest, dest + dim * 2 * SIZEOF( LONGINT ) + MathLenOffset );
		PutPtr( dest, dest );  PutDim( dest, dim );  len := Size;
		FOR i := 0 TO dim - 1 DO
			PutInc( dest, i, len );  PutLen( dest, i, GetLen( src, i ) );
			len := len * GetLen( src, i );
		END;
		(* Report("allocdest",dest,dim); *)
		RETURN p;
	END AllocateTemp;


	(*** procedures to traverse arrays and apply operators *)
	
	(** apply unary operator to array:  array SHORTINT -> array SHORTINT *)
	PROCEDURE ApplyGenericUnaryAAOpS( d, l: Address;  elementSize: LONGINT; Loop: GenericUnaryAALoopS; op: PROCEDURE(x: SHORTINT): SHORTINT );
		VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
			origdest: LONGINT;  modes: SET;
			dest, left, dim: LONGINT;
			
		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;
		
	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(* allocate destination, if necessary *)
		(*IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyGenericUnaryAAOpS;

	(** apply unary operator to array:  array INTEGER -> array INTEGER *)
	PROCEDURE ApplyGenericUnaryAAOpI( d, l: Address;  elementSize: LONGINT; Loop: GenericUnaryAALoopI; op: PROCEDURE(x: INTEGER): INTEGER );
		VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
			origdest: LONGINT;  modes: SET;
			dest, left, dim: LONGINT;
			
		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;
		
	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(* allocate destination, if necessary *)
		(*IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyGenericUnaryAAOpI;

	(** apply unary operator to array:  array LONGINT -> array LONGINT *)
	PROCEDURE ApplyGenericUnaryAAOpL( d, l: Address;  elementSize: LONGINT; Loop: GenericUnaryAALoopL; op: PROCEDURE(x: LONGINT): LONGINT );
		VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
			origdest: LONGINT;  modes: SET;
			dest, left, dim: LONGINT;
			
		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;
		
	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(* allocate destination, if necessary *)
		(*IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyGenericUnaryAAOpL;
	
	(** apply unary operator to array:  array HUGEINT -> array HUGEINT *)
	PROCEDURE ApplyGenericUnaryAAOpH( d, l: Address;  elementSize: LONGINT; Loop: GenericUnaryAALoopH; op: PROCEDURE(x: HUGEINT): HUGEINT );
	VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
		origdest: LONGINT;  modes: SET;
	VAR dest, left, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(*
		(* allocate destination, if necessary *)
		IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;
		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyGenericUnaryAAOpH;

	(** apply unary operator to array:  array REAL -> array REAL *)
	PROCEDURE ApplyGenericUnaryAAOpR( d, l: Address;  elementSize: LONGINT; Loop: GenericUnaryAALoopR; op: PROCEDURE(x: REAL): REAL );
		VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
			origdest: LONGINT;  modes: SET;
			dest, left, dim: LONGINT;
			
		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc ); DEC( len );
				END;
			END;
		END Traverse;
		
	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(* allocate destination, if necessary *)
		(*IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyGenericUnaryAAOpR;
	
	(** apply unary operator to array:  array LONGREAL -> array LONGREAL *)
	PROCEDURE ApplyGenericUnaryAAOpX( d, l: Address;  elementSize: LONGINT; Loop: GenericUnaryAALoopX; op: PROCEDURE(x: LONGREAL): LONGREAL );
	VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
		origdest: LONGINT;  modes: SET;
	VAR dest, left, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(*
		(* allocate destination, if necessary *)
		IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;
		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyGenericUnaryAAOpX;
	
	(** apply unary operator to array:  array COMPLEX -> array COMPLEX *)
	PROCEDURE ApplyGenericUnaryAAOpZ( d, l: Address;  elementSize: LONGINT; Loop: GenericUnaryAALoopZ; op: PROCEDURE(x: COMPLEX): COMPLEX );
	VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
		origdest: LONGINT;  modes: SET;
	VAR dest, left, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(*
		(* allocate destination, if necessary *)
		IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;
		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyGenericUnaryAAOpZ;
	
	(** apply unary operator to array:  array LONGCOMPLEX -> array LONGCOMPLEX *)
	PROCEDURE ApplyGenericUnaryAAOpLZ( d, l: Address;  elementSize: LONGINT; Loop: GenericUnaryAALoopLZ; op: PROCEDURE(x: LONGCOMPLEX): LONGCOMPLEX );
	VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
		origdest: LONGINT;  modes: SET;
	VAR dest, left, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen, op );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );
		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(*
		(* allocate destination, if necessary *)
		IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;
		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyGenericUnaryAAOpLZ;

(** apply unary operator to array:  array -> array *)
	PROCEDURE ApplyUnaryAAOp( d, l: Address;  elementSize: LONGINT;
														Loop: UnaryAALoop );
	VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
		origdest: LONGINT;  modes: SET;
	VAR dest, left, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );

		origdest := 0;  modes := {up, down};
		(* allocate destination, if necessary *)
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(*
		(* allocate destination, if necessary *)
		IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, elementSize )
		ELSIF CheckGeometry( left, dest, dim )
		END;
		*)
		IF debug THEN Report( "AA: left", left );  Report( "AA: dest", dest );  END;

		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyUnaryAAOp;

(** apply unary operator to array:  array -> scalar *)
	PROCEDURE ApplyUnaryASOp( dest, l: Address;  Loop: UnaryASLoop );
	VAR loopd, looplen, loopli: LONGINT;  glen: LONGINT;
	VAR left, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr: Address );
		VAR len: LONGINT;  linc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dest, loopli, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );  INC( dim );
				WHILE (len > 0) DO Traverse( dim, ladr );  INC( ladr, linc );  DEC( len );  END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( l, left );  dim := GetDim( left );
		IF debug THEN Report( "AS: left", left );  END;
		(* check pattern: longest piece that can be done with a loop *)
		IF conservative THEN glen := 0 END;
		FindPattern1( left, dim, loopd, looplen, loopli );  Traverse( 0, GetAdr( left ) );
		IF conservative THEN
			looplen := 1;
			WHILE (dim > 0) DO
				looplen := looplen * GetLen( left, dim - 1 );  DEC( dim );
			END;
			ASSERT( looplen = glen );
		END;
	END ApplyUnaryASOp;

(** apply unary operator to array:  scalar -> array *)
	PROCEDURE ApplyUnarySAOp( d, right: Address;  Loop: UnarySALoop );
	VAR loopd, looplen, loopdi: LONGINT;  glen: LONGINT;
	VAR dest, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  dadr: Address );
		VAR len: LONGINT;  dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( right, dadr, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( dest, dim );  dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO Traverse( dim, dadr );  INC( dadr, dinc );  DEC( len );  END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( d, dest );  dim := GetDim( dest );
		IF debug THEN Report( "AS: dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		IF conservative THEN glen := 0 END;
		FindPattern1( dest, dim, loopd, looplen, loopdi );  Traverse( 0, GetAdr( dest ) );
		IF conservative THEN
			looplen := 1;
			WHILE (dim > 0) DO
				looplen := looplen * GetLen( dest, dim - 1 );  DEC( dim );
			END;
			ASSERT( looplen = glen );
		END;
	END ApplyUnarySAOp;

(** apply binary operator : array x array -> array *)


	PROCEDURE ApplyBinaryAAAOp( d, l, r: Address;  elementSize: LONGINT;
														    Loop: BinaryAAALoop );
	VAR loopd, looplen, loopli, loopri, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
		origdest: LONGINT;  modes: SET;  left, right, dest: Address;  dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, radr, dadr: Address );
		VAR len: LONGINT;  linc, rinc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, radr, dadr, loopli, loopri, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				rinc := GetIncr( right, dim );  dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, radr, dadr );  INC( ladr, linc );  INC( radr, rinc );
					INC( dadr, dinc );  DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  SYSTEM.GET( r, right );  dim := GetDim( left );

		(* allocate destination, if necessary *)
		IF ~SameShape( left, right ) THEN
			Halt( GeometryMismatch, left, right, 0 )
		END;
		origdest := 0;  modes := {up, down};
		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			CopyUpCompatible( dest, right, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN
				Reverse( left, dim );  Reverse( dest, dim );  Reverse( right, dim );
			ELSE
				origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );   (* 1d field ? *)
			END;
		END;

		(* debugging *)
		IF debug THEN Report( "AAA:left", left );  Report( "AAA:right", right );  Report( "AAA:dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern3( left, right, dest, dim, loopd, looplen, loopli, loopri, loopdi );
		(*  run through dimensions  *)
		Traverse( 0, GetAdr( left ), GetAdr( right ), GetAdr( dest ) );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN
			Reverse( left, dim );  Reverse( dest, dim );  Reverse( right, dim );
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyBinaryAAAOp;

(** apply binary operator: array x scalar -> array *)

	PROCEDURE ApplyBinaryASAOp( d, l, right: Address;
														   elementSize: LONGINT;
														   Loop: BinaryASALoop );
	VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
		origdest: LONGINT;  modes: SET;  dest, left, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, right, dadr, loopli, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  dim := GetDim( left );
		(* allocate destination, if necessary *)
		origdest := 0;  modes := {up, down};

		p := AllocateSame( dest, left, elementSize );
		IF p = NIL THEN
			CopyUpCompatible( dest, left, modes );
			IF up IN modes THEN  (* nothing to be done *)
			ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
			ELSE origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
			END;
		END;
		(* debugging *)
		IF debug THEN Report( "ASA:left", left );  Report( "ASA:dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, dest, dim, loopd, looplen, loopli, loopdi );
		(*  run through dimensions  *)
		IF conservative THEN glen := 0 END;
		Traverse( 0, GetAdr( left ), GetAdr( dest ) );
		IF conservative THEN
			looplen := 1;
			WHILE (dim > 0) DO
				looplen := looplen * GetLen( left, dim - 1 );  DEC( dim );
			END;
			ASSERT( looplen = glen );
		END;
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( left, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
		SYSTEM.PUT( d, dest );
	END ApplyBinaryASAOp;

(** apply binary operator: array x array -> scalar *)

	PROCEDURE ApplyBinaryAASOp( dest, l, r: Address;  Loop: BinaryAASLoop );
	VAR loopd, looplen, loopli, loopri: LONGINT;  glen: LONGINT;
		left, right, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, radr: Address );
		VAR len: LONGINT;  linc, rinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, radr, dest, loopli, loopri, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				rinc := GetIncr( right, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, radr );  INC( ladr, linc );  INC( radr, rinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( l, left );  SYSTEM.GET( r, right );  dim := GetDim( left );
		(* check array lengths *)
		IF ~SameShape( left, right ) THEN
			Halt( GeometryMismatch, left, right, 0 )
		END;
		IF debug THEN Report( "AAS:left", left );  Report( "AAS:right", right );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, right, dim, loopd, looplen, loopli, loopri );
		(*  run through dimensions  *)
		IF conservative THEN glen := 0 END;
		Traverse( 0, GetAdr( left ), GetAdr( right ) );
		IF conservative THEN
			looplen := 1;
			WHILE (dim > 0) DO
				looplen := looplen * GetLen( left, dim - 1 );  DEC( dim );
			END;
			ASSERT( looplen = glen );
		END;
	END ApplyBinaryAASOp;

(** special binary operator: array x array -> boolean *)

	PROCEDURE ApplyBinaryAABOp( l, r: Address;
														    Loop: BinaryAABLoop; geometryMismatchDefault: BOOLEAN ): BOOLEAN;
	VAR loopd, looplen, loopli, loopri: LONGINT;  left, right, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, radr: Address ): BOOLEAN;
		VAR len: LONGINT;  linc, rinc: LONGINT;
		BEGIN
			IF dim = loopd THEN RETURN Loop( ladr, radr, loopli, loopri, looplen );
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );
				rinc := GetIncr( right, dim );  INC( dim );
				WHILE (len > 0) DO
					IF ~Traverse( dim, ladr, radr ) THEN RETURN FALSE END;
					INC( ladr, linc );  INC( radr, rinc );  DEC( len );
				END;
				RETURN TRUE;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( l, left );  SYSTEM.GET( r, right );  dim := GetDim( left );
		(* check array lengths *)
		IF ~SameShape( left, right ) THEN
			RETURN geometryMismatchDefault
		END;
		(* is destination already allocated? (might be a temporary result) *)
		IF debug THEN Report( "AAB:left", left );  Report( "AAB:right", right );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( left, right, dim, loopd, looplen, loopli, loopri );
		(*  run through dimensions  *)
		RETURN Traverse( 0, GetAdr( left ), GetAdr( right ) );
	END ApplyBinaryAABOp;

(** special binary operator: array x scalar -> boolean *)

	PROCEDURE ApplyBinaryASBOp( l, right: Address;
														   Loop: BinaryASBLoop ): BOOLEAN;
	VAR loopd, looplen, loopli: LONGINT;  left, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr: Address ): BOOLEAN;
		VAR len: LONGINT;  linc: LONGINT;
		BEGIN
			IF dim = loopd THEN RETURN Loop( ladr, right, loopli, looplen );
			ELSE
				len := GetLen( left, dim );  linc := GetIncr( left, dim );  INC( dim );
				WHILE (len > 0) DO
					IF ~Traverse( dim, ladr ) THEN RETURN FALSE END;
					INC( ladr, linc );  DEC( len );
				END;
				RETURN TRUE;
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( l, left );  dim := GetDim( left );
		IF debug THEN Report( "AAB:left", left );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPattern1( left, dim, loopd, looplen, loopli );
		(*  run through dimensions  *)
		RETURN Traverse( 0, GetAdr( left ) );
	END ApplyBinaryASBOp;



	(**** operators *)

(*** copy *)
	PROCEDURE Copy4( ladr, dadr, linc, dinc, len: LONGINT );
	CODE {SYSTEM.i386}
		MOV	ECX, [EBP+ladr]	;  ECX := ladr
		MOV	EDX, [EBP+dadr]	;  EDX := dadr
		MOV	EBX, [EBP+len]	;  EBX := len
		start:
		CMP	EBX, 0	;
		JLE	end	;  WHILE EBX > 0 DO
		MOV	EAX, [ECX]	;  EAX := SYSTEM.GET32(ECX)
		MOV	[EDX], EAX	;  SYSTEM.PUT32(EDX, EAX))
		ADD	ECX, [EBP+linc]	;  INC(ECX, linc)
		ADD	EDX, [EBP+dinc]	;  INC(EDX, rinc)
		DEC	EBX	;  DEC(EBX)
		JMP	start
		end:
	END Copy4;

	PROCEDURE Copy2( ladr, dadr, linc, dinc, len: LONGINT );
	CODE {SYSTEM.i386}
		MOV	ECX, [EBP+ladr]	;  ECX := ladr
		MOV	EDX, [EBP+dadr]	;  EDX := dadr
		MOV	EBX, [EBP+len]	;  EBX := len
		start:
		CMP	EBX, 0	;
		JLE	end	;  WHILE EBX > 0 DO
		MOV	AX, [ECX]	;  EAX := SYSTEM.GET32(ECX)
		MOV	[EDX], AX	;  SYSTEM.PUT32(EDX, EAX))
		ADD	ECX, [EBP+linc]	;  INC(ECX, linc)
		ADD	EDX, [EBP+dinc]	;  INC(EDX, rinc)
		DEC	EBX	;  DEC(EBX)
		JMP	start
		end:
	END Copy2;

	PROCEDURE Copy1( ladr, dadr, linc, dinc, len: LONGINT );
	CODE {SYSTEM.i386}
		MOV	ECX, [EBP+ladr]	;  ECX := ladr
		MOV	EDX, [EBP+dadr]	;  EDX := dadr
		MOV	EBX, [EBP+len]	;  EBX := len
		start:
		CMP	EBX, 0	;
		JLE	end	;  WHILE EBX > 0 DO
		MOV	AL, [ECX]	;  EAX := SYSTEM.GET32(ECX)
		MOV	[EDX], AL	;  SYSTEM.PUT32(EDX, EAX))
		ADD	ECX, [EBP+linc]	;  INC(ECX, linc)
		ADD	EDX, [EBP+dinc]	;  INC(EDX, rinc)
		DEC	EBX	;  DEC(EBX)
		JMP	start
		end:
	END Copy1;

	PROCEDURE Copy8( ladr, dadr, linc, dinc, len: LONGINT );
	CODE {SYSTEM.i386}
		MOV	ECX, [EBP+ladr]	;  ECX := ladr
		MOV	EDX, [EBP+dadr]	;  EDX := dadr
		MOV	EBX, [EBP+len]	;  EBX := len
		start:
		CMP	EBX, 0	;
		JLE	end	;  WHILE EBX > 0 DO
		MOV	EAX, [ECX]	;  EAX := SYSTEM.GET32(ECX)
		MOV	[EDX], EAX	;  SYSTEM.PUT32(EDX, EAX))
		MOV	EAX, [ECX+4]	;  EAX := SYSTEM.GET32(ECX+4)
		MOV	[EDX+4], EAX	;  SYSTEM.PUT32(EDX+4, EAX))
		ADD	ECX, [EBP+linc]	;  INC(ECX, linc)
		ADD	EDX, [EBP+dinc]	;  INC(EDX, rinc)
		DEC	EBX	;  DEC(EBX)
		JMP	start
		end:
	END Copy8;

	PROCEDURE -MoveB*( srcadr, destadr, len: LONGINT );
	(** Correct move if overlap, might be important for some array operations,
		do not use SYSTEM.MOVE.  *)
	CODE {SYSTEM.i386}
		MOV	ECX, [ESP]	;  len
		MOV	EDI, [ESP+4]	;  destadr
		MOV	ESI, [ESP+8]	;  srcadr
		CMP	ESI, EDI
		JAE	moveup	;  src adr greater then dest adr, no problem with moving up
		MOV	EAX, ESI
		ADD	EAX, ECX
		CMP	EAX, EDI
		JBE	moveup	;  no overlap, no problem, move up
		MOV	ESI, EAX
		ADD	EDI, ECX
		DEC	ESI
		DEC	EDI
		STD	;  move down since overlap occured
		REP
		MOVSB
		JMP	done
		moveup:
		CLD
		MOV	BL, CL
		SHR	ECX, 2
		AND	BL, 00000003H	;  rest to move after 4 byte move
		REP
		MOVSD	;  move 4 bytes each step
		MOV	CL, BL
		REP
		MOVSB	;  move rest in one byte steps
		done:
		ADD	ESP, 12	;  adjust stack pointer(inline procedure!)
	END MoveB;

	PROCEDURE CopyContent( dest, src, elementSize: LONGINT );   (**! optimize *)
	VAR loopd, looplen, loopli, loopdi: LONGINT;  p: ANY;  glen: LONGINT;
		origdest: LONGINT;  modes: SET;  dim: LONGINT;

		PROCEDURE Loop( ladr, dadr, linc, dinc, len: LONGINT );
		BEGIN
			IF (dinc = elementSize) & (linc = elementSize) THEN
				MoveB( ladr, dadr, len * elementSize );
				(*
				SYSTEM.MOVE( ladr, dadr, elementSize * len );
				*)
			ELSIF (dinc = -elementSize) & (linc = -elementSize) THEN
				len := len * elementSize;
				MoveB( ladr - len + elementSize, dadr - len + elementSize, len );
			ELSIF elementSize = 1 THEN
				Copy1( ladr, dadr, linc, dinc, len );
				(*
						WHILE (len > 0) DO
					SYSTEM.PUT8( dadr, SYSTEM.GET8( ladr ) );  DEC( len );  INC( ladr, linc );  INC( dadr, dinc );
				END;
				*)
			ELSIF elementSize = 2 THEN
				Copy2( ladr, dadr, linc, dinc, len );
				(*
				WHILE (len > 0) DO
					SYSTEM.PUT16( dadr, SYSTEM.GET16( ladr ) );  DEC( len );  INC( ladr, linc );  INC( dadr, dinc );
				END;
				*)
			ELSIF elementSize = 4 THEN
				Copy4( ladr, dadr, linc, dinc, len );
				(*
				WHILE (len > 0) DO
					SYSTEM.PUT32( dadr, SYSTEM.GET32( ladr ) );  DEC( len );  INC( ladr, linc );  INC( dadr, dinc );
				END;
				*)
			ELSIF elementSize = 8 THEN
				Copy8( ladr, dadr, linc, dinc, len );
				(*
				WHILE (len > 0) DO
					SYSTEM.PUT32( dadr, SYSTEM.GET32( ladr ) );
					SYSTEM.PUT32( dadr + 4, SYSTEM.GET32( ladr + 4 ) );  DEC( len );  INC( ladr, linc );
					INC( dadr, dinc );
				END;
				*)
			ELSE  (* SYSTEM.MOVE is expensive ! *)
				WHILE (len > 0) DO
					SYSTEM.MOVE( ladr, dadr, elementSize );  DEC( len );  INC( ladr, linc );
					INC( dadr, dinc );
				END;
			END;
		END Loop;

		PROCEDURE Traverse( dim: LONGINT;  ladr, dadr: Address );
		VAR len: LONGINT;  linc, dinc: LONGINT;
		BEGIN
			IF dim = loopd THEN
				Loop( ladr, dadr, loopli, loopdi, looplen );
				IF conservative THEN INC( glen, looplen ) END;
			ELSE
				len := GetLen( src, dim );  linc := GetIncr( src, dim );
				dinc := GetIncr( dest, dim );  INC( dim );
				WHILE (len > 0) DO
					Traverse( dim, ladr, dadr );  INC( ladr, linc );  INC( dadr, dinc );
					DEC( len );
				END;
			END;
		END Traverse;

	BEGIN
		dim := GetDim( src );

		origdest := 0;  modes := {up, down};   (* copy modes *)
		ASSERT( SameShape( src, dest ) );   (* must be ensured by caller *)

		CopyUpCompatible( dest, src, modes );
		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN  (* can only copy from top to bottom *)
			Reverse( src, dim );  Reverse( dest, dim )
		ELSE  (* can only copy via double buffer *)
			origdest := dest;  p := AllocateTemp( dest, origdest, elementSize );
		END;

		IF debug THEN Report( "AA: src", src );  Report( "AA: dest", dest );
		END;

		(* check pattern: longest piece that can be done with a loop *)
		FindPattern2( src, dest, dim, loopd, looplen, loopli, loopdi );
		Traverse( 0, GetAdr( src ), GetAdr( dest ) );

		IF up IN modes THEN  (* nothing to be done *)
		ELSIF down IN modes THEN Reverse( src, dim );  Reverse( dest, dim )
		ELSE CopyContent( origdest, dest, elementSize );
		END;
	END CopyContent;

	PROCEDURE AllocateSame( VAR dest: LONGINT;  src: LONGINT;
												   elementsize: LONGINT ): ANY;
	VAR ptr, data: ANY;  Size: LONGINT;
		(* allocate a structure in dest compatible with src, if necessary. returns if allocation has taken place *)

		PROCEDURE UseDescriptor;
		VAR tag: LONGINT;
		BEGIN
			SYSTEM.GET( src - 4, tag );
			Heaps.NewRec( ptr, tag, FALSE );
			dest := SYSTEM.VAL( LONGINT, ptr );
		END UseDescriptor;

		PROCEDURE NewData;
		VAR dim, len, size: LONGINT;
		BEGIN
			dim := GetDim( src );  size := elementsize;
			PutDim( dest, dim );
			PutSize( dest, elementsize );
			WHILE (dim > 0) DO
				DEC( dim );  len := GetLen( src, dim );  PutLen( dest, dim, len );
				PutInc( dest, dim, size );  size := size * len;
			END;
			SYSTEM.NEW( data, size );
			PutAdr( dest, SYSTEM.VAL( LONGINT, data ) );
			PutPtr( dest, SYSTEM.VAL( LONGINT, data ) );
		END NewData;

	BEGIN
		IF dest # 0 THEN Size := GetSize( dest );  ASSERT( Size = elementsize );  END;
		IF debug THEN KernelLog.String( "Allocate same " );  Report( "allocation source", src );  Report( "allocation des", dest );  END;
		IF dest = 0 THEN  (* NIL pointer, guaranteed to be tensor *)
			IF TensorFlag IN GetFlags( src ) THEN UseDescriptor();
			ELSE ptr := GetArrayDesc( GetDim( src ) );  dest := SYSTEM.VAL( LONGINT, ptr );
			END;
			PutFlags(dest, {TensorFlag});
			NewData();  RETURN ptr;
		ELSIF GetDim( dest ) # GetDim( src ) THEN  (* different dimension *)
			(* check if re-allocation of descriptor is allowed *)
			IF ~(TensorFlag IN GetFlags( dest )) &
				~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				HALT( 100 );
			END;
			UseDescriptor();
			PutFlags(dest, {TensorFlag});
			NewData();  RETURN ptr;
		ELSIF (GetAdr( dest ) = 0) OR ~SameShape( dest, src ) THEN
			(* check if re-allocation of array data is allowed *)
			IF RangeFlag IN GetFlags( dest ) THEN  (* no! not allowed *)
				HALT( 100 );
			END;
			NewData();

			RETURN data;
		ELSE  (* nothing to do *)
			RETURN NIL;
		END;
	END AllocateSame;

	PROCEDURE TempDescCopy( src: Address ): ANY;
	VAR p: ANY;  dim: LONGINT;
	BEGIN
		dim := GetDim( src );  SYSTEM.NEW( p, dim * 8 + MathLenOffset );
		SYSTEM.MOVE( src, SYSTEM.VAL( LONGINT, p ), dim * 8 + MathLenOffset );  PutAdr( src, 0 );
		PutPtr( src, 0 );  PutFlags( src, {} );  RETURN p;
	END TempDescCopy;

	PROCEDURE CopyArraySelf*( dest, src: Address;  elementsize: LONGINT );
	VAR p: ANY;
	BEGIN
		ASSERT( src = dest );  p := TempDescCopy( src );
		CopyArray( dest, SYSTEM.VAL( LONGINT, p ), elementsize );
	END CopyArraySelf;

	PROCEDURE CopyArray*( dest: Address;  src: Address; elementsize: LONGINT );
	VAR p: ANY; srcdim, destdim: LONGINT;
	BEGIN
		ASSERT( dest # 0 );   (* impossible unless compiler error *)
		IF GetDim( src ) # GetDim( dest ) THEN  (* not allowed but possible (tensor) *)
			srcdim := GetDim(src);
			destdim := GetDim(dest);
			(*
			Debugging.Stack("copy array");
			*)
			Report( "copy array source", src );  Report( "copy array  des", dest );
			HALT(100);
		ELSIF src = dest THEN  (* self copy *)
			CopyArraySelf( dest, src, elementsize );
		ELSE
			p := AllocateSame( dest, src, elementsize );
			CopyContent( dest, src, elementsize )
		END;
	END CopyArray;

	PROCEDURE CopyTensorSelf*( VAR dest: Address; src: Address; elementsize: LONGINT );
	BEGIN
		dest := 0;  CopyTensor( dest, src, elementsize );
	END CopyTensorSelf;

	PROCEDURE CopyTensor*( VAR dest: Address;  src: Address;
												 elementsize: LONGINT );
	VAR p: ANY;
	BEGIN
		(* Report("dest",dest); Report("src",src); *)
		IF (dest = 0) OR ~(SameShape( dest, src )) OR (GetAdr( dest ) = 0) THEN
			p := AllocateSame( dest, src, elementsize );   (* includes check if allocation is allowed *)
			CopyContent( dest, src, elementsize );
		ELSIF dest = src THEN CopyTensorSelf( dest, src, elementsize );
		ELSE CopyContent( dest, src, elementsize )
		END;
	END CopyTensor;

	(* copy descriptor of src to that of dest. If not existent then create.*)
	PROCEDURE ShallowCopy*(VAR dest: Address; src: Address);
	VAR ptr: ANY; flags: SET;

		PROCEDURE UseTypeDescriptor;
		VAR tag: LONGINT;  ptr: ANY;
		BEGIN
			SYSTEM.GET( src + Heaps.TypeDescOffset, tag );  Heaps.NewRec( ptr, tag, FALSE );
			dest := SYSTEM.VAL( LONGINT, ptr );
		END UseTypeDescriptor;

		PROCEDURE CopyDescriptor;
		BEGIN
			SYSTEM.MOVE( src , dest, MathLenOffset + SIZEOF(Address) *  GetDim( src ) *2 );
		END CopyDescriptor;

	BEGIN
		(*
		KernelLog.String("ShallowCopy called with ");
		KernelLog.Int(src,10); KernelLog.Int(dest,10);
		KernelLog.Ln;
		Report( "scopy source", src );  Report( "scopy dest", dest );
		*)

		IF dest = 0 THEN  (* NIL pointer, guaranteed to be tensor *)
			IF TensorFlag IN GetFlags( src ) THEN UseTypeDescriptor();
			ELSE
				ptr := GetArrayDesc( GetDim( src ) );  dest := SYSTEM.VAL( LONGINT, ptr );  (* ??? *)
			END;
			CopyDescriptor();
			PutFlags(dest, {TensorFlag});
		ELSIF GetDim( dest ) # GetDim( src ) THEN  (* different dimension *)
			flags := GetFlags(dest);
			(* check if re-allocation of descriptor is allowed *)
			IF ~(TensorFlag IN GetFlags( dest )) & ~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				Halt(DimensionMismatch,src,0,dest);
			END;

			(* create a new descriptor!!! (added by Alexey) *)
			ptr := GetArrayDesc( GetDim( src ) );  dest := SYSTEM.VAL( LONGINT, ptr );

			CopyDescriptor();
			PutFlags(dest, flags);
		ELSE
			flags := GetFlags(dest);
			(* check if re-allocation of array data is allowed *)
			IF RangeFlag IN GetFlags( dest ) THEN  (* no! not allowed *)
				Halt(AllocationForbidden,src,0,dest);
			END;
			CopyDescriptor();
			PutFlags(dest, flags);
		END;

	END ShallowCopy;


	PROCEDURE DescriptorCopy( src, dest: LONGINT );
	BEGIN
		IF debug THEN
			KernelLog.String( "DescriptorCopy from " );  KernelLog.Int( src, 1 );  KernelLog.String( " to " );
			KernelLog.Int( dest, 1 );  KernelLog.Ln;
		END;
		SYSTEM.MOVE( src, dest, 2*SIZEOF(Address) );   (* adr and ptr *)
		SYSTEM.MOVE( src + MathLenOffset, dest + MathLenOffset, SIZEOF(Address) *  GetDim( src ) *2 );   (* lens and increments *)
	END DescriptorCopy;

	PROCEDURE ZeroCopy*(CONST src: ARRAY [?]; VAR dest: ARRAY [?]);
	VAR s,d: LONGINT;
	BEGIN
		s := SYSTEM.VAL(LONGINT,src); d := SYSTEM.VAL(LONGINT,dest);
		ShallowCopy(d,s);
		SYSTEM.PUT(ADDRESSOF(dest),d);
	END ZeroCopy;

	OPERATOR "ALIAS"*(CONST src: ARRAY [?]): ARRAY[?];
	BEGIN
		ZeroCopy(src, RESULT);
		RETURN RESULT
	END "ALIAS";

	PROCEDURE SameShape( l, r: LONGINT ): BOOLEAN;
	VAR dim: LONGINT;
	BEGIN
		dim := GetDim( l );
		IF dim # GetDim( r ) THEN RETURN FALSE END;
		WHILE (dim > 0) DO
			DEC( dim );
			IF GetLen( l, dim ) # GetLen( r, dim ) THEN RETURN FALSE END;
		END;
		RETURN TRUE;
	END SameShape;

	(*
	PROCEDURE ZeroCopyArray*( dest: Address;  src: Address; elementsize: LONGINT );
	(*
		called as ZeroCopy(A,B,Size) with enhanced arrays A,B
		check if deep copy can be avoided and if so then do a shallow copy
	*)
	BEGIN
		ASSERT( dest # 0 );   (* impossible *)
		IF GetDim( src ) # GetDim( dest ) THEN  (* not allowed but possible (tensor) *)
			HALT( 100 );
		ELSIF (RangeFlag IN GetFlags( src )) THEN
			(* must copy (and allocate) *)
			CopyArray( dest, src, elementsize );
		ELSIF (RangeFlag IN GetFlags( dest )) THEN  (* copy only allowed if shape matches *)
			IF ~SameShape( dest, src ) THEN HALT( 100 );
			ELSE CopyContent( dest, src, elementsize )
			END;
		ELSE DescriptorCopy( src, dest )
		END;
	END ZeroCopyArray;

	PROCEDURE ZeroCopyTensor*( VAR dest: Address;  src: Address; elementsize: LONGINT );
	(*
		called as ZeroCopy(A,B,Size) with A,B: ARRAY [?] OF ...
		check if deep copy can be avoided and if so then do a shallow copy
	*)
	BEGIN
		IF debug THEN
			KernelLog.String( "ZeroCopy2: " );  KernelLog.String( "ADDRESSOF(dest) " );  KernelLog.Int( ADDRESSOF( dest ), 10 );
			KernelLog.Ln;  KernelLog.String( "ADDRESSOF(src) " );  KernelLog.Int( ADDRESSOF( src ), 10 );  KernelLog.Ln;
			KernelLog.String( "dest " );  KernelLog.Int( dest, 10 );  KernelLog.Ln;  KernelLog.String( "src " );
			KernelLog.Int( src, 10 );  KernelLog.Ln;  KernelLog.String( "elementsize" );
			KernelLog.Int( elementsize, 10 );  KernelLog.Ln;
		END;

		IF (dest = 0) OR (TensorFlag IN GetFlags( dest )) THEN  (* descriptor allocation allowed *)
			IF (TensorFlag IN GetFlags( src )) THEN dest := src;
			ELSE
				CopyTensor( dest, src, elementsize );   (* allocate freshly *)
			END;
		ELSIF (RangeFlag IN GetFlags( src )) THEN
			(* must copy (and allocate) *)
			CopyTensor( dest, src, elementsize );
		ELSIF (RangeFlag IN GetFlags( dest )) THEN  (* descriptor copy forbidden *)
			IF SameShape( src, dest ) THEN CopyContent( dest, src, elementsize )
			ELSE
				HALT( 100 );   (* copy forbidden *)
			END;
		ELSIF GetDim( src ) = GetDim( dest ) THEN  (* descriptor copy allowed *)
			DescriptorCopy( src, dest );
		ELSE
			HALT( 100 );   (* different shapes: not allowed *)
		END;
	END ZeroCopyTensor;



	PROCEDURE ZeroCopy*( left, elementSize, dest, dim: LONGINT );   (**! optimize *)
	VAR i: LONGINT;
	BEGIN
		IF GetPtr( dest ) = -1 THEN  (* zero copy forbidden, try data copy *)
			CopyContent( dest, left, elementSize )
		ELSE
			IF debug THEN
				KernelLog.String( "Zero Copy" );  KernelLog.Int( left, 10 );  KernelLog.Int( dest, 10 );
				KernelLog.Ln;
			END;
			PutPtr( dest, GetPtr( left ) );  PutAdr( dest, GetAdr( left ) );
			FOR i := 0 TO dim - 1 DO
				PutInc( dest, i, GetIncr( left, i ) );  PutLen( dest, i, GetLen( left, i ) );
			END;
		END;
	END ZeroCopy;
	*)
	(*** conversions ****)

(** SHORTINT -> INTEGER *)
	PROCEDURE ConvertASAILoop( ladr, dadr, linc, dinc, len: LONGINT );
	BEGIN
		WHILE (len > 0) DO  (* SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval ); *)
			SYSTEM.PUT16( dadr, SYSTEM.GET8( ladr ) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END ConvertASAILoop;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SHORTINT ): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( INTEGER ),ConvertASAILoop );
		RETURN RESULT
	END "@Convert";

	OPERATOR "LONG"*(CONST src: ARRAY [ ? ] OF SHORTINT ): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( INTEGER ),ConvertASAILoop );
		RETURN RESULT
	END "LONG";

(** SHORTINT -> LONGINT *)
	PROCEDURE ConvertLoopSL( ladr, dadr, linc, dinc, len: LONGINT );
	BEGIN
		WHILE (len > 0) DO  (* SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval ); *)
			SYSTEM.PUT32( dadr, SYSTEM.GET8( ladr ) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END ConvertLoopSL;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SHORTINT ): ARRAY [?] OF LONGINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGINT ),ConvertLoopSL );
		RETURN RESULT
	END "@Convert";

(** SHORTINT -> REAL *)
	PROCEDURE ConvertLoopSR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: SHORTINT;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopSR;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SHORTINT ): ARRAY [?] OF REAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( REAL ), ConvertLoopSR );
		RETURN RESULT
	END "@Convert";

(** SHORTINT -> LONGREAL *)
	PROCEDURE ConvertLoopSX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: SHORTINT;  dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopSX;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF SHORTINT ):  ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGREAL ), ConvertLoopSX );
		RETURN RESULT
	END "@Convert";

(** INTEGER -> SHORTINT (SHORT) *)
	PROCEDURE ConvertLoopIS( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;  dval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := SHORT( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopIS;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( SHORTINT ), ConvertLoopIS );
		RETURN RESULT
	END "@Convert";

	OPERATOR "SHORT"*(CONST src: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( SHORTINT ), ConvertLoopIS );
		RETURN RESULT
	END "SHORT";

	(** INTEGER -> LONGINT *)

	PROCEDURE ConvertLoopIL( ladr, dadr, linc, dinc, len: LONGINT );
	BEGIN
		WHILE (len > 0) DO  (* SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  *)
			SYSTEM.PUT32( dadr, SYSTEM.GET16( ladr ) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END ConvertLoopIL;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGINT ), ConvertLoopIL );
		RETURN RESULT
	END "@Convert";

	OPERATOR "LONG"*(CONST src: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGINT ), ConvertLoopIL );
		RETURN RESULT
	END "LONG";

(** INTEGER -> REAL *)
	PROCEDURE ConvertLoopIR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopIR;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF INTEGER ):  ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( REAL ), ConvertLoopIR );
		RETURN RESULT
	END "@Convert";

(** INTEGER -> LONGREAL *)
	PROCEDURE ConvertLoopIX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;  dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopIX;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF INTEGER ):  ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGREAL ), ConvertLoopIX );
		RETURN RESULT
	END "@Convert";

(** LONGINT -> INTEGER (SHORT) *)
	PROCEDURE ConvertLoopLI( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;  dval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := SHORT( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLI;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( INTEGER ),ConvertLoopLI );
		RETURN RESULT
	END "@Convert";

	OPERATOR "SHORT"*(CONST src: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( INTEGER ),ConvertLoopLI );
		RETURN RESULT
	END "SHORT";

(** LONGINT -> REAL *)
	PROCEDURE ConvertLoopLR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLR;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( REAL ), ConvertLoopLR );
		RETURN RESULT
	END "@Convert";

(** LONGINT -> LONGREAL *)
	PROCEDURE ConvertLoopLX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;  dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLX;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGREAL ), ConvertLoopLX );
		RETURN RESULT
	END "@Convert";

(** REAL -> LONGINT (ENTIER) *)
	PROCEDURE ConvertLoopRL( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: REAL;  dval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := ENTIER( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopRL;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF REAL ):  ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGINT ), ConvertLoopRL );
		RETURN RESULT
	END "@Convert";

	OPERATOR "ENTIER"*(CONST src: ARRAY [ ? ] OF REAL ):  ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGINT ), ConvertLoopRL );
		RETURN RESULT
	END "ENTIER";

(** REAL -> LONGREAL *)
	PROCEDURE ConvertLoopRX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: REAL;  dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopRX;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF REAL ):  ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGREAL ), ConvertLoopRX );
		RETURN RESULT
	END "@Convert";

	OPERATOR "LONG"*(CONST src: ARRAY [ ? ] OF REAL ):  ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGREAL ), ConvertLoopRX );
		RETURN RESULT
	END "LONG";

(** LONGREAL -> REAL (SHORT) *)
	PROCEDURE ConvertLoopXR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGREAL;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := SHORT( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopXR;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF LONGREAL ):  ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( REAL ), ConvertLoopXR );
		RETURN RESULT
	END "@Convert";

	OPERATOR "SHORT"*(CONST src: ARRAY [ ? ] OF LONGREAL ):  ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( REAL ), ConvertLoopXR );
		RETURN RESULT
	END "SHORT";

(** LONGREAL -> LONGINT (ENTIER) *)
	PROCEDURE ConvertLoopXL( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGREAL;  dval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := ENTIER( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopXL;

	OPERATOR "@Convert"*(CONST src: ARRAY [ ? ] OF LONGREAL ):  ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGINT ),ConvertLoopXL );
		RETURN RESULT
	END "@Convert";

	OPERATOR "ENTIER"*(CONST src: ARRAY [ ? ] OF LONGREAL ):  ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGINT ),ConvertLoopXL );
		RETURN RESULT
	END "ENTIER";

	(*** monadic not A -> ~A ********************************************************************)

(** BOOLEAN *)
	PROCEDURE NotLoopAB( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ~lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END NotLoopAB;

	OPERATOR "~"*(CONST src: ARRAY [ ? ] OF BOOLEAN): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( BOOLEAN ), NotLoopAB );
		RETURN RESULT
	END "~";
	
	(*** monadic generic (A) -> -A  ********************************************************************)

(** SHORTINT *)
	PROCEDURE GenericLoopS( ladr, dadr, linc, dinc, len: LONGINT; op: PROCEDURE(x: SHORTINT): SHORTINT );
	VAR lval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopS;
	
(** INTEGER *)
	PROCEDURE GenericLoopI( ladr, dadr, linc, dinc, len: LONGINT; op: PROCEDURE(x: INTEGER): INTEGER );
	VAR lval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopI;

(** LONGINT *)
	PROCEDURE GenericLoopL( ladr, dadr, linc, dinc, len: LONGINT; op: PROCEDURE(x: LONGINT): LONGINT );
	VAR lval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopL;

(** HUGEINT *)
	PROCEDURE GenericLoopH( ladr, dadr, linc, dinc, len: LONGINT; op: PROCEDURE(x: HUGEINT): HUGEINT );
	VAR lval: HUGEINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopH;

(** REAL *)
	PROCEDURE GenericLoopR( ladr, dadr, linc, dinc, len: LONGINT; op: PROCEDURE(x: REAL): REAL );
	VAR lval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopR;

(** LONGREAL *)
	PROCEDURE GenericLoopX( ladr, dadr, linc, dinc, len: LONGINT; op: PROCEDURE(x: LONGREAL): LONGREAL );
	VAR lval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopX;
	
(** COMPLEX *)
	PROCEDURE GenericLoopZ( ladr, dadr, linc, dinc, len: LONGINT; op: PROCEDURE(x: COMPLEX): COMPLEX );
	VAR lval: COMPLEX;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopZ;
(*
(** LONGCOMPLEX *)
	PROCEDURE GenericLoopLZ( ladr, dadr, linc, dinc, len: LONGINT; op: PROCEDURE(x: LONGCOMPLEX): LONGCOMPLEX );
	VAR lval: LONGCOMPLEX;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, op(lval) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END GenericLoopLZ;
*)
	(*** monadic minus A -> -A  ********************************************************************)

(** SHORTINT *)
	PROCEDURE MinusLoopS( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopS;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( SHORTINT ), MinusLoopS );
		RETURN RESULT
	END "-";

(** INTEGER *)
	PROCEDURE MinusLoopI( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopI;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( INTEGER ), MinusLoopI );
		RETURN RESULT
	END "-";

(** LONGINT *)
	PROCEDURE MinusLoopL( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopL;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGINT ), MinusLoopL );
		RETURN RESULT
	END "-";

(** REAL *)
	PROCEDURE MinusLoopR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopR;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF REAL;
	BEGIN
		IF debug THEN KernelLog.String( "MinusAR" );  KernelLog.Ln;  END;
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( REAL ), MinusLoopR );
		RETURN RESULT
	END "-";

(** LONGREAL *)
	PROCEDURE MinusLoopX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopX;

	OPERATOR "-"*(CONST src: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGREAL ),
									   MinusLoopX );
		RETURN RESULT
	END "-";

	(*** add array + array -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE AddASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddASASLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF SHORTINT): ARRAY [?] OF SHORTINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), AddASASLoop );
		RETURN RESULT
	END "+";

(** INTEGER *)
	PROCEDURE AddAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAIAILoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF INTEGER): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), AddAIAILoop );
		RETURN RESULT
	END "+";

(** LONGINT *)
	PROCEDURE AddALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddALALLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF LONGINT): ARRAY [?] OF LONGINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), AddALALLoop );
		RETURN RESULT
	END "+";

(** REAL *)
	PROCEDURE AddARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddARARLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF REAL): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopAddARAR );
		RETURN RESULT
	END "+";

(** LONGREAL *)
	PROCEDURE AddAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAXAXLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF LONGREAL): ARRAY [?] OF LONGREAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopAddAXAX );
		RETURN RESULT
	END "+";

(** COMPLEX *)
	PROCEDURE AddAZAZLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: COMPLEX;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAZAZLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF COMPLEX): ARRAY [?] OF COMPLEX;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( COMPLEX ), loopAddAZAZ );
		RETURN RESULT
	END "+";


(** LONGCOMPLEX *)
	PROCEDURE AddALZALZLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
			SYSTEM.PUT( dadr, lvalRe+rvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), lvalIm+rvalIm );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END AddALZALZLoop;

	OPERATOR "+"*(CONST left,right: ARRAY [?] OF LONGCOMPLEX): ARRAY [?] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGCOMPLEX ), loopAddALZALZ );
		RETURN RESULT
	END "+";

	(*** add array + scalar -> array and scalar + array -> array ********************************************************************)

(** SHORTINT *)
	PROCEDURE AddASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddASSSLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), AddASSSLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), AddASSSLoop );
		RETURN RESULT
	END "+";

(** INTEGER *)
	PROCEDURE AddAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddAISILoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), AddAISILoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), AddAISILoop );
		RETURN RESULT
	END "+";

(** LONGINT *)
	PROCEDURE AddALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddALSLLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), AddALSLLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), AddALSLLoop );
		RETURN RESULT
	END "+";

(** REAL *)
	PROCEDURE AddARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddARSRLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  AddARSRLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  AddARSRLoop );
		RETURN RESULT
	END "+";

(** LONGREAL *)
	PROCEDURE AddAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddAXSXLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), AddAXSXLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), AddAXSXLoop );
		RETURN RESULT
	END "+";


(** COMPLEX *)
	PROCEDURE AddAZSZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: COMPLEX;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval + rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddAZSZLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF COMPLEX; right: COMPLEX ): ARRAY [ ? ] OF COMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( COMPLEX ),
										  AddAZSZLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: COMPLEX; CONST right: ARRAY [ ? ] OF COMPLEX): ARRAY [ ? ] OF COMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( COMPLEX ),
										  AddAZSZLoop );
		RETURN RESULT
	END "+";

(** LONGCOMPLEX *)
	PROCEDURE AddALZSLZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.PUT( dadr, lvalRe + rvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), lvalIm + rvalIm );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AddALZSLZLoop;

	OPERATOR "+"*(CONST left: ARRAY [ ? ] OF LONGCOMPLEX; right: LONGCOMPLEX ): ARRAY [ ? ] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGCOMPLEX ),
										  AddALZSLZLoop );
		RETURN RESULT
	END "+";

	OPERATOR "+"*(left: LONGCOMPLEX; CONST right: ARRAY [ ? ] OF LONGCOMPLEX): ARRAY [ ? ] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( LONGCOMPLEX ),
										  AddALZSLZLoop );
		RETURN RESULT
	END "+";

	(*** subtraction array - array -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE SubASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubASASLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF SHORTINT): ARRAY [?] OF SHORTINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), SubASASLoop );
		RETURN RESULT
	END "-";

(** INTEGER *)
	PROCEDURE SubAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubAIAILoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF INTEGER): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), SubAIAILoop );
		RETURN RESULT
	END "-";

(** LONGINT *)
	PROCEDURE SubALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubALALLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF LONGINT): ARRAY [?] OF LONGINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), SubALALLoop );
		RETURN RESULT
	END "-";

(** REAL *)
	PROCEDURE SubARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubARARLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF REAL): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  SubARARLoop );
		RETURN RESULT
	END "-";

(** LONGREAL *)
	PROCEDURE SubAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubAXAXLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF LONGREAL): ARRAY [?] OF LONGREAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), SubAXAXLoop );
		RETURN RESULT
	END "-";

(** COMPLEX *)
	PROCEDURE SubAZAZLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: COMPLEX;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubAZAZLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF COMPLEX): ARRAY [?] OF COMPLEX;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( COMPLEX ), SubAZAZLoop );
		RETURN RESULT
	END "-";

(** LONGCOMPLEX *)
	PROCEDURE SubALZALZLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
			SYSTEM.PUT( dadr, lvalRe-rvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), lvalIm-rvalIm );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END SubALZALZLoop;

	OPERATOR "-"*(CONST left,right: ARRAY [?] OF LONGCOMPLEX): ARRAY [?] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGCOMPLEX ), SubALZALZLoop );
		RETURN RESULT
	END "-";

	(*** subtraction array-scalar -> array  ********************************************************************)

(** SHORTINT *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF SHORTINT;   (* a: left, b: right, c: dest *)
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** INTEGER *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF INTEGER;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** LONGINT *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF LONGINT;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** REAL *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF REAL;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** LONGREAL *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** COMPLEX *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF COMPLEX; right: COMPLEX ): ARRAY [ ? ] OF COMPLEX;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

(** LONGCOMPLEX *)
	OPERATOR "-"*(CONST left: ARRAY [ ? ] OF LONGCOMPLEX; right: LONGCOMPLEX ): ARRAY [ ? ] OF LONGCOMPLEX;
	BEGIN
		RESULT := left + (-right);
		RETURN RESULT
	END "-";

	(*** subtraction scalar-array -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE SubSSASLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSSASLoop;

	OPERATOR "-"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), SubSSASLoop );
		RETURN RESULT
	END "-";

(** INTEGER *)
	PROCEDURE SubSIAILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSIAILoop;

	OPERATOR "-"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), SubSIAILoop );
		RETURN RESULT
	END "-";

(** LONGINT *)
	PROCEDURE SubSLALLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSLALLoop;

	OPERATOR "-"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), SubSLALLoop );
		RETURN RESULT
	END "-";

(** REAL *)
	PROCEDURE SubSRARLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSRARLoop;

	OPERATOR "-"*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  SubSRARLoop );
		RETURN RESULT
	END "-";

(** LONGREAL *)
	PROCEDURE SubSXAXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSXAXLoop;

	OPERATOR "-"*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), SubSXAXLoop );
		RETURN RESULT
	END "-";


(** COMPLEX *)
	PROCEDURE SubSZAZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: COMPLEX;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval - lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSZAZLoop;

	OPERATOR "-"*(left: COMPLEX; CONST right: ARRAY [ ? ] OF COMPLEX): ARRAY [ ? ] OF COMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( COMPLEX ), SubSZAZLoop );
		RETURN RESULT
	END "-";

(** LONGCOMPLEX *)
	PROCEDURE SubSLZALZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.PUT( dadr, rvalRe-lvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), rvalIm-lvalIm );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END SubSLZALZLoop;

	OPERATOR "-"*(left: LONGCOMPLEX; CONST right: ARRAY [ ? ] OF LONGCOMPLEX): ARRAY [ ? ] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGCOMPLEX ), SubSLZALZLoop );
		RETURN RESULT
	END "-";

	(*** element-wise multiply array x array -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE EMulASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulASASLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF SHORTINT): ARRAY [?] OF SHORTINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), EMulASASLoop );
		RETURN RESULT
	END ".*";

(** INTEGER *)
	PROCEDURE EMulAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval * rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EMulAIAILoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF INTEGER): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), EMulAIAILoop );
		RETURN RESULT
	END ".*";

(** LONGINT *)
	PROCEDURE EMulALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulALALLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF LONGINT): ARRAY [?] OF LONGINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), EMulALALLoop );
		RETURN RESULT
	END ".*";

(** REAL *)
	PROCEDURE EMulARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulARARLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF REAL): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EMulARARLoop );
		RETURN RESULT
	END ".*";

(** LONGREAL *)
	PROCEDURE EMulAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulAXAXLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF LONGREAL): ARRAY [?] OF LONGREAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), EMulAXAXLoop );
		RETURN RESULT
	END ".*";


(** COMPLEX *)
	PROCEDURE EMulAZAZLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: COMPLEX;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulAZAZLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF COMPLEX): ARRAY [?] OF COMPLEX;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( COMPLEX ), EMulAZAZLoop );
		RETURN RESULT
	END ".*";

(** LONGCOMPLEX *)
	PROCEDURE EMulALZALZLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
			SYSTEM.PUT( dadr, lvalRe*rvalRe - lvalIm*rvalIm ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), lvalRe*rvalIm + lvalIm*rvalRe );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EMulALZALZLoop;

	OPERATOR ".*"*(CONST left,right: ARRAY [?] OF LONGCOMPLEX): ARRAY [?] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGCOMPLEX ), EMulALZALZLoop );
		RETURN RESULT
	END ".*";

	(*** element-wise multiply and add array x array -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE EMulIncASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval,dval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.GET(dadr,dval); SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncASASLoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF SHORTINT): ARRAY [?] OF SHORTINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), EMulIncASASLoop );
	END  ".*+";

(** INTEGER *)
	PROCEDURE EMulIncAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval,dval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );SYSTEM.GET(dadr,dval);  dval := dval + lval * rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EMulIncAIAILoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF INTEGER): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), EMulIncAIAILoop );
	END  ".*+";

(** LONGINT *)
	PROCEDURE EMulIncALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval,dval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.GET(dadr,dval); SYSTEM.PUT( dadr, dval+ lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncALALLoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF LONGINT): ARRAY [?] OF LONGINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), EMulIncALALLoop );
	END  ".*+";

(** REAL *)
	PROCEDURE EMulIncARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval,dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.GET(dadr,dval);  SYSTEM.PUT( dadr, dval+  lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncARARLoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF REAL): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EMulIncARARLoop );
	END  ".*+";

(** LONGREAL *)
	PROCEDURE EMulIncAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval,dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval ); SYSTEM.GET(dadr,dval);  SYSTEM.PUT( dadr,dval+ lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncAXAXLoop;

	OPERATOR ".*+"*(CONST left,right: ARRAY [?] OF LONGREAL): ARRAY [?] OF LONGREAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), EMulIncAXAXLoop );
	END  ".*+";
	(*** multiply array x scalar -> array and scalar + array -> array ********************************************************************)

(** SHORTINT *)
	PROCEDURE MulASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulASSSLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), MulASSSLoop );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), MulASSSLoop );
		RETURN RESULT
	END "*";

(** INTEGER *)
	PROCEDURE MulAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulAISILoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), MulAISILoop );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), MulAISILoop );
		RETURN RESULT
	END "*";

(** LONGINT *)
	PROCEDURE MulALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulALSLLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), MulALSLLoop );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), MulALSLLoop );
		RETURN RESULT
	END "*";

(** REAL *)
	PROCEDURE MulARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulARSRLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopMulARSR );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  loopMulARSR );
		RETURN RESULT
	END "*";

(** LONGREAL *)
	PROCEDURE MulAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		IF debug THEN
			KernelLog.String( "MulAXSXLoop, ladr,radr,dadr,linc,dinc,len= " );  KernelLog.Int( ladr, 10 );  KernelLog.Int( radr, 10 );
			KernelLog.Int( dadr, 10 );  KernelLog.Int( linc, 10 );  KernelLog.Int( dinc, 10 );
			KernelLog.Int( len, 10 );  KernelLog.Ln;
		END;

		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulAXSXLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopMulAXSX );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), loopMulAXSX );
		RETURN RESULT
	END "*";


(** COMPLEX *)
	PROCEDURE MulAZSZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: COMPLEX;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval * rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulAZSZLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF COMPLEX; right: COMPLEX ): ARRAY [ ? ] OF COMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( COMPLEX ),
										  loopMulAZSZ );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: COMPLEX; CONST right: ARRAY [ ? ] OF COMPLEX): ARRAY [ ? ] OF COMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( COMPLEX ),
										  loopMulAZSZ );
		RETURN RESULT
	END "*";

(** LONGCOMPLEX *)
	PROCEDURE MulALZSLZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.PUT( dadr, lvalRe * rvalRe - lvalIm*rvalIm ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), lvalRe * rvalIm + lvalIm*rvalRe );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END MulALZSLZLoop;

	OPERATOR "*"*(CONST left: ARRAY [ ? ] OF LONGCOMPLEX; right: LONGCOMPLEX ): ARRAY [ ? ] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGCOMPLEX ),
										  loopMulALZSLZ );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(left: LONGCOMPLEX; CONST right: ARRAY [ ? ] OF LONGCOMPLEX): ARRAY [ ? ] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( LONGCOMPLEX ),
										  loopMulALZSLZ );
		RETURN RESULT
	END "*";

	(*** multiply and add array * scalar -> array and scalar *  array -> array ********************************************************************)

(** SHORTINT *)
	PROCEDURE IncMulASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulASSSLoop;

	OPERATOR "IncMul"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), IncMulASSSLoop );
	END "IncMul";

	OPERATOR "IncMul"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), IncMulASSSLoop );
		RETURN RESULT
	END "IncMul";


	OPERATOR "DecMul"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), IncMulASSSLoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";

	OPERATOR "DecMul"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), IncMulASSSLoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";



(** INTEGER *)
	PROCEDURE IncMulAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulAISILoop;

	OPERATOR "IncMul"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), IncMulAISILoop );
		RETURN RESULT
	END "IncMul";

	OPERATOR "IncMul"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), IncMulAISILoop );
		RETURN RESULT
	END "IncMul";

	OPERATOR "DecMul"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF INTEGER;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), IncMulAISILoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";

	OPERATOR "DecMul"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF INTEGER;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), IncMulAISILoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";

(** LONGINT *)
	PROCEDURE IncMulALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulALSLLoop;

	OPERATOR "IncMul"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), IncMulALSLLoop );
		RETURN RESULT
	END "IncMul";

	OPERATOR "IncMul"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), IncMulALSLLoop );
		RETURN RESULT
	END "IncMul";


	OPERATOR "DecMul"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF LONGINT;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), IncMulALSLLoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";

	OPERATOR "DecMul"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF LONGINT;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), IncMulALSLLoop );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";

(** REAL *)
	PROCEDURE IncMulARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulARSRLoop;

	OPERATOR "IncMul"*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopIncMulARSR );
		RETURN RESULT
	END "IncMul";

	OPERATOR "IncMul"*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  loopIncMulARSR );
		RETURN RESULT
	END "IncMul";

	OPERATOR "DecMul"*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF REAL;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopIncMulARSR );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";

	OPERATOR "DecMul"*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF REAL;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  loopIncMulARSR );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";

(** LONGREAL *)
	PROCEDURE IncMulAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval, dval: LONGREAL;
	BEGIN
		IF debug THEN
			KernelLog.String( "IncMulAXSXLoop, ladr,radr,dadr,linc,dinc,len= " );  KernelLog.Int( ladr, 10 );  KernelLog.Int( radr, 10 );
			KernelLog.Int( dadr, 10 );  KernelLog.Int( linc, 10 );  KernelLog.Int( dinc, 10 );
			KernelLog.Int( len, 10 );  KernelLog.Ln;
		END;

		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( dadr, dval );  SYSTEM.PUT( dadr, dval + lval * rval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END IncMulAXSXLoop;

	OPERATOR "IncMul"*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopIncMulAXSX );
		RETURN RESULT
	END "IncMul";

	OPERATOR "IncMul"*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), loopIncMulAXSX );
		RETURN RESULT
	END "IncMul";

	OPERATOR "DecMul"*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopIncMulAXSX );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";

	OPERATOR "DecMul"*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		RESULT := -RESULT;
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), loopIncMulAXSX );
		RESULT := -RESULT;
		RETURN RESULT
	END "DecMul";

	(*** element-wise division array / array -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE EDivideASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideASASLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF SHORTINT): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EDivideASASLoop );
		RETURN RESULT
	END "./";

(** INTEGER *)
	PROCEDURE EDivideAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideAIAILoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF INTEGER): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EDivideAIAILoop );
		RETURN RESULT
	END "./";

(** LONGINT *)
	PROCEDURE EDivideALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideALALLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF LONGINT): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EDivideALALLoop );
		RETURN RESULT
	END "./";

(** REAL *)
	PROCEDURE EDivideARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideARARLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF REAL): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EDivideARARLoop );
		RETURN RESULT
	END "./";

(** LONGREAL *)
	PROCEDURE EDivideAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;  dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideAXAXLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF LONGREAL): ARRAY [?] OF LONGREAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), EDivideAXAXLoop );
		RETURN RESULT
	END "./";

(** COMPLEX *)
	PROCEDURE EDivideAZAZLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: COMPLEX;  dval: COMPLEX;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval / rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideAZAZLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF COMPLEX): ARRAY [?] OF COMPLEX;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( COMPLEX ), EDivideAZAZLoop );
		RETURN RESULT
	END "./";


(** LONGCOMPLEX *)
	PROCEDURE EDivideALZALZLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;  dvalRe, dvalIm: LONGREAL; v: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
			IF rvalIm # 0.0D0 THEN
				v := 1.0D0/(rvalRe*rvalRe + rvalIm*rvalIm);
				dvalRe := v*(lvalRe*rvalRe+lvalIm*rvalIm);
				dvalIm := v*(lvalIm*rvalRe-lvalRe*rvalIm);
			ELSE
				dvalRe := lvalRe/rvalRe;
				dvalIm := lvalIm/rvalRe;
			END;
			SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), dvalIm );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivideALZALZLoop;

	OPERATOR "./"*(CONST left,right: ARRAY [?] OF LONGCOMPLEX): ARRAY [?] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGCOMPLEX ), EDivideALZALZLoop );
		RETURN RESULT
	END "./";


	(*** division array / scalar -> array and scalar / array -> array ********************************************************************)

(** SHORTINT *)
	PROCEDURE DivideASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideASSSLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  DivideASSSLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSSASLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSSASLoop;

	OPERATOR "/"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  DivideSSASLoop );
		RETURN RESULT
	END "/";

(** INTEGER *)
	PROCEDURE DivideAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideAISILoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  DivideAISILoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSIAILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSIAILoop;

	OPERATOR "/"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  DivideSIAILoop );
		RETURN RESULT
	END "/";

(** LONGINT *)
	PROCEDURE DivideALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideALSLLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  DivideALSLLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSLALLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSLALLoop;

	OPERATOR "/"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  DivideSLALLoop );
		RETURN RESULT
	END "/";

(** REAL *)
	PROCEDURE DivideARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideARSRLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  DivideARSRLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSRARLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSRARLoop;

	OPERATOR "/"*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  DivideSRARLoop );
		RETURN RESULT
	END "/";

(** LONGREAL *)
	PROCEDURE DivideAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;  dval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideAXSXLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), DivideAXSXLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSXAXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;  dval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSXAXLoop;

	OPERATOR "/"*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), DivideSXAXLoop );
		RETURN RESULT
	END "/";


(** COMPLEX *)
	PROCEDURE DivideAZSZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: COMPLEX;  dval: COMPLEX;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval / rval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideAZSZLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF COMPLEX; right: COMPLEX ): ARRAY [ ? ] OF COMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( COMPLEX ), DivideAZSZLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSZAZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: COMPLEX;  dval: COMPLEX;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSZAZLoop;

	OPERATOR "/"*(left: COMPLEX; CONST right: ARRAY [ ? ] OF COMPLEX): ARRAY [ ? ] OF COMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( COMPLEX ), DivideSZAZLoop );
		RETURN RESULT
	END "/";


(** LONGCOMPLEX *)
	PROCEDURE DivideALZSLZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;  dvalRe, dvalIm: LONGREAL; v: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );

		IF rvalIm # 0.0D0 THEN
			v := 1.0D0/(rvalRe*rvalRe + rvalIm*rvalIm);
			WHILE (len > 0) DO
				SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
				dvalRe := v*(lvalRe*rvalRe+lvalIm*rvalIm);
				dvalIm := v*(lvalIm*rvalRe-lvalRe*rvalIm);
				SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), dvalIm );
				INC( ladr, linc );
				INC( dadr, dinc );  DEC( len );
			END;
		ELSE
			WHILE (len > 0) DO
				SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
				dvalRe := lvalRe / rvalRe; dvalIm := lvalIm / rvalRe;
				SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), dvalIm );
				INC( ladr, linc );
				INC( dadr, dinc );  DEC( len );
			END;
		END;
	END DivideALZSLZLoop;

	OPERATOR "/"*(CONST left: ARRAY [ ? ] OF LONGCOMPLEX; right: LONGCOMPLEX ): ARRAY [ ? ] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGCOMPLEX ), DivideALZSLZLoop );
		RETURN RESULT
	END "/";

	PROCEDURE DivideSLZALZLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;  dvalRe, dvalIm: LONGREAL; v: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			v := 1.0D0/(lvalRe*lvalRe + lvalIm*lvalIm);
			dvalRe := v*(rvalRe*lvalRe+rvalIm*lvalIm);
			dvalIm := v*(rvalIm*lvalRe-rvalRe*lvalIm);
			SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), dvalIm );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSLZALZLoop;

	OPERATOR "/"*(left: LONGCOMPLEX; CONST right: ARRAY [ ? ] OF LONGCOMPLEX): ARRAY [ ? ] OF LONGCOMPLEX;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGCOMPLEX ), DivideSLZALZLoop );
		RETURN RESULT
	END "/";

	(*** element-wise DIV array DIV array -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE EDivASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval DIV rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivASASLoop;

	OPERATOR "DIV"*(CONST left,right: ARRAY [?] OF SHORTINT): ARRAY [?] OF SHORTINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), EDivASASLoop );
		RETURN RESULT
	END "DIV";

(** INTEGER *)
	PROCEDURE EDivAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval DIV rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivAIAILoop;

	OPERATOR "DIV"*(CONST left,right: ARRAY [?] OF INTEGER): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), EDivAIAILoop );
		RETURN RESULT
	END "DIV";

(** LONGINT *)
	PROCEDURE EDivALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval DIV rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EDivALALLoop;

	OPERATOR "DIV"*(CONST left,right: ARRAY [?] OF LONGINT): ARRAY [?] OF LONGINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), EDivALALLoop );
		RETURN RESULT
	END "DIV";


	(*** division array DIV scalar -> array and scalar DIV  array -> array ********************************************************************)

(** SHORTINT *)
	PROCEDURE DivASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval DIV rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivASSSLoop;

	OPERATOR "DIV"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), DivASSSLoop );
		RETURN RESULT
	END "DIV";

	PROCEDURE DivSSASLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSSASLoop;

	OPERATOR "DIV"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), DivSSASLoop );
		RETURN RESULT
	END "DIV";

(** INTEGER *)
	PROCEDURE DivAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval DIV rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivAISILoop;

	OPERATOR "DIV"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), DivAISILoop );
		RETURN RESULT
	END "DIV";

	PROCEDURE DivSIAILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSIAILoop;

	OPERATOR "DIV"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), DivSIAILoop );
		RETURN RESULT
	END "DIV";

(** LONGINT *)
	PROCEDURE DivALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval DIV rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivALSLLoop;

	OPERATOR "DIV"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), DivALSLLoop );
		RETURN RESULT
	END "DIV";

	PROCEDURE DivSLALLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSLALLoop;

	OPERATOR "DIV"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), DivSLALLoop );
		RETURN RESULT
	END "DIV";

	(*** element-wise modulus array MOD array -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE EModASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval MOD rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EModASASLoop;

	OPERATOR "MOD"*(CONST left,right: ARRAY [?] OF SHORTINT): ARRAY [?] OF SHORTINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), EModASASLoop );
		RETURN RESULT
	END "MOD";

(** INTEGER *)
	PROCEDURE EModAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval MOD rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EModAIAILoop;

	OPERATOR "MOD"*(CONST left,right: ARRAY [?] OF INTEGER): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), EModAIAILoop );
		RETURN RESULT
	END "MOD";

(** LONGINT *)
	PROCEDURE EModALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := lval MOD rval;
			SYSTEM.PUT( dadr, dval );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );
			DEC( len );
		END;
	END EModALALLoop;

	OPERATOR "MOD"*(CONST left,right: ARRAY [?] OF LONGINT): ARRAY [?] OF LONGINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), EModALALLoop );
		RETURN RESULT
	END "MOD";


	(*** modulus array MOD scalar -> array and scalar MOD  array -> array ********************************************************************)

(** SHORTINT *)
	PROCEDURE ModASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval MOD rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModASSSLoop;

	OPERATOR "MOD"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), ModASSSLoop );
		RETURN RESULT
	END "MOD";

	PROCEDURE ModSSASLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSSASLoop;

	OPERATOR "MOD"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), ModSSASLoop );
		RETURN RESULT
	END "MOD";

(** INTEGER *)
	PROCEDURE ModAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval MOD rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModAISILoop;

	OPERATOR "MOD"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), ModAISILoop );
		RETURN RESULT
	END "MOD";

	PROCEDURE ModSIAILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSIAILoop;

	OPERATOR "MOD"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), ModSIAILoop );
		RETURN RESULT
	END "MOD";

(** LONGINT *)
	PROCEDURE ModALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval MOD rval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModALSLLoop;

	OPERATOR "MOD"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), ModALSLLoop );
		RETURN RESULT
	END "MOD";

	PROCEDURE ModSLALLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSLALLoop;

	OPERATOR "MOD"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), ModSLALLoop );
		RETURN RESULT
	END "MOD";

	(*** scalar product <array,array> -> scalar  ********************************************************************)

(** SHORTINT *)
	PROCEDURE SPASASLoop( ladr, radr, dadr, linc, rinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: LONGINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + rval * lval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPASASLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): LONGINT;
	VAR dest: LONGINT;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SPASASLoop );
		RETURN dest;
	END "+*";

(** INTEGER *)
	PROCEDURE SPAIAILoop( ladr, radr, dadr, linc, rinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: LONGINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + rval * lval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPAIAILoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF INTEGER ): LONGINT;
	VAR dest: LONGINT;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SPAIAILoop );
		RETURN dest;
	END "+*";

(** LONGINT *)
	PROCEDURE SPALALLoop( ladr, radr, dadr, linc, rinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: LONGINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + rval * lval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPALALLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF LONGINT ): LONGINT;
	VAR dest: LONGINT;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SPALALLoop );
		RETURN dest;
	END "+*";

(** REAL *)
	PROCEDURE SPARARLoop( ladr, radr, dadr, linc, rinc, len: LONGINT );
	VAR lval, rval: REAL;  dval: REAL;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + rval * lval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPARARLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF REAL ): REAL;
	VAR dest: REAL;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), loopSPARAR );
		RETURN dest;
	END "+*";

	PROCEDURE SPAXAXLoop( ladr, radr, dadr, linc, rinc, len: LONGINT );
	VAR lval, rval, dval: LONGREAL;
	BEGIN
		IF debug THEN
			KernelLog.String( "SPAXAX, ladr,radr,dadr,linc,rinc,len= " );  KernelLog.Int( ladr, 10 );  KernelLog.Int( radr, 10 );
			KernelLog.Int( dadr, 10 );  KernelLog.Int( linc, 10 );  KernelLog.Int( rinc, 10 );
			KernelLog.Int( len, 10 );  KernelLog.Ln;
		END;

		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  INC( ladr, linc );  SYSTEM.GET( radr, rval );  INC( radr, rinc );
			dval := dval + rval * lval;  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPAXAXLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): LONGREAL;
	VAR dest: LONGREAL;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), loopSPAXAX );
		RETURN dest;
	END "+*";

(** COMPLEX *)
	PROCEDURE SPAZAZLoop( ladr, radr, dadr, linc, rinc, len: LONGINT );
	VAR lval, rval: COMPLEX;  dval: COMPLEX;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			RE(dval) := RE(dval) + RE(lval) * RE(rval) + IM(lval) * IM(rval);
			IM(dval) := IM(dval) - RE(lval) * IM(rval) + IM(lval) * RE(rval);
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SPAZAZLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF COMPLEX ): COMPLEX;
	VAR dest: COMPLEX;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), loopSPAZAZ );
		RETURN dest;
	END "+*";

	(** COMPLEX *)
	PROCEDURE SPALZALZLoop( ladr, radr, dadr, linc, rinc, len: LONGINT );
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;  dvalRe, dvalIm: LONGREAL;
	BEGIN
		SYSTEM.GET( dadr, dvalRe ); SYSTEM.GET( dadr+SIZEOF(LONGREAL), dvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
			dvalRe := dvalRe + lvalRe * rvalRe + lvalIm * rvalIm;
			dvalIm := dvalIm - lvalRe * rvalIm + lvalIm * rvalRe;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), dvalIm );
	END SPALZALZLoop;

	OPERATOR "+*"*( CONST left, right: ARRAY [ ? ] OF LONGCOMPLEX ): LONGCOMPLEX;
	VAR dest: LONGCOMPLEX;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), loopSPALZALZ );
		RETURN dest;
	END "+*";

	(*** element-wise equal: array x array -> array of boolean  ********************************************************************)

(** BOOLEAN *)

	PROCEDURE EEqlABABLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlABABLoop;

	OPERATOR ".="*(CONST left,right : ARRAY [?] OF BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlABABLoop );
		RETURN RESULT
	END ".=";

(** SHORTINT *)

	PROCEDURE EEqlASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlASASLoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlASASLoop );
		RETURN RESULT
	END ".=";

(** INTEGER *)

	PROCEDURE EEqlAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAIAILoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlAIAILoop );
		RETURN RESULT
	END ".=";

(** LONGINT *)

	PROCEDURE EEqlALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlALALLoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlALALLoop );
		RETURN RESULT
	END ".=";

(** REAL *)
	PROCEDURE EEqlARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlARARLoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlARARLoop );
		RETURN RESULT
	END ".=";

(** LONGREAL *)
	PROCEDURE EEqlAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAXAXLoop;

	OPERATOR ".="*(CONST left, right: ARRAY [ ? ] OF LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlAXAXLoop );
		RETURN RESULT
	END ".=";

	(*** elementwise equal  array x scalar ->  array of boolean ********************************************************************)

(** BOOLEAN *)
	PROCEDURE EEqlABSBLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlABSBLoop;

	OPERATOR ".="*(CONST left : ARRAY [?] OF BOOLEAN; right: BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlABSBLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: BOOLEAN; CONST right : ARRAY [?] OF BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlABSBLoop );
		RETURN RESULT
	END ".=";

(** SHORTINT *)
	PROCEDURE EEqlASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlASSSLoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlASSSLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlASSSLoop );
		RETURN RESULT
	END ".=";

(** INTEGER *)
	PROCEDURE EEqlAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAISILoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlAISILoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlAISILoop );
		RETURN RESULT
	END ".=";

(** LONGINT *)
	PROCEDURE EEqlALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlALSLLoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlALSLLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlALSLLoop );
		RETURN RESULT
	END ".=";

(** REAL *)
	PROCEDURE EEqlARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlARSRLoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlARSRLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlARSRLoop );
		RETURN RESULT
	END ".=";

(** LONGREAL *)
	PROCEDURE EEqlAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval = rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAXSXLoop;

	OPERATOR ".="*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlAXSXLoop );
		RETURN RESULT
	END ".=";

	OPERATOR ".="*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlAXSXLoop );
		RETURN RESULT
	END ".=";

	(*** elementwise nequal: array x array -> array of boolean  ********************************************************************)

(** BOOLEAN *)
	PROCEDURE ENeqABABLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqABABLoop;

	OPERATOR ".#"*(CONST left,right : ARRAY [?] OF BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqABABLoop );
		RETURN RESULT
	END ".#";

(** SHORTINT *)
	PROCEDURE ENeqASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqASASLoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqASASLoop );
		RETURN RESULT
	END ".#";

(** INTEGER*)
	PROCEDURE ENeqAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAIAILoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqAIAILoop );
		RETURN RESULT
	END ".#";

(** LONGINT*)
	PROCEDURE ENeqALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqALALLoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqALALLoop );
		RETURN RESULT
	END ".#";

(** REAL *)
	PROCEDURE ENeqARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqARARLoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqARARLoop );
		RETURN RESULT
	END ".#";

(** LONGREAL *)
	PROCEDURE ENeqAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAXAXLoop;

	OPERATOR ".#"*(CONST left, right: ARRAY [ ? ] OF LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqAXAXLoop );
		RETURN RESULT
	END ".#";

	(*** elementwise nequal  array x scalar ->  array of boolean ********************************************************************)

(** BOOLEAN *)
	PROCEDURE ENeqABSBLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqABSBLoop;

	OPERATOR ".#"*(CONST left : ARRAY [?] OF BOOLEAN; right: BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqABSBLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: BOOLEAN; CONST right : ARRAY [?] OF BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqABSBLoop );
		RETURN RESULT
	END ".#";

(** SHORTINT *)
	PROCEDURE ENeqASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqASSSLoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqASSSLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqASSSLoop );
		RETURN RESULT
	END ".#";

(** INTEGER *)
	PROCEDURE ENeqAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAISILoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqAISILoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqAISILoop );
		RETURN RESULT
	END ".#";

(** LONGINT *)
	PROCEDURE ENeqALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqALSLLoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqALSLLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqALSLLoop );
		RETURN RESULT
	END ".#";

(** REAL *)
	PROCEDURE ENeqARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqARSRLoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqARSRLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqARSRLoop );
		RETURN RESULT
	END ".#";

(** LONGREAL *)
	PROCEDURE ENeqAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval # rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAXSXLoop;

	OPERATOR ".#"*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqAXSXLoop );
		RETURN RESULT
	END ".#";

	OPERATOR ".#"*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqAXSXLoop );
		RETURN RESULT
	END ".#";


	(*** elementwise greater than: array x array -> array of boolean  ********************************************************************)

(** SHORTINT *)
	PROCEDURE EGtrASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrASASLoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrASASLoop );
		RETURN RESULT
	END ".>";

(** INTEGER *)
	PROCEDURE EGtrAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAIAILoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrAIAILoop );
		RETURN RESULT
	END ".>";

(** LONGINT *)
	PROCEDURE EGtrALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrALALLoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrALALLoop );
		RETURN RESULT
	END ".>";

(** REAL *)
	PROCEDURE EGtrARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrARARLoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrARARLoop );
		RETURN RESULT
	END ".>";

(** LONGREAL *)
	PROCEDURE EGtrAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAXAXLoop;

	OPERATOR ".>"*(CONST left, right: ARRAY [ ? ] OF LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrAXAXLoop );
		RETURN RESULT
	END ".>";

	(*** elementwise greater  array x scalar ->  array of boolean ********************************************************************)

(** SHORTINT *)
	PROCEDURE EGtrASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrASSSLoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrASSSLoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrASSSLoop );
		RETURN RESULT
	END ".<";

(** INTEGER *)
	PROCEDURE EGtrAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAISILoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrAISILoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrAISILoop );
		RETURN RESULT
	END ".<";

(** LONGINT *)
	PROCEDURE EGtrALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrALSLLoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrALSLLoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrALSLLoop );
		RETURN RESULT
	END ".<";

(** REAL *)
	PROCEDURE EGtrARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrARSRLoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrARSRLoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrARSRLoop );
		RETURN RESULT
	END ".<";

(** LONGREAL *)
	PROCEDURE EGtrAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval > rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAXSXLoop;

	OPERATOR ".>"*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrAXSXLoop );
		RETURN RESULT
	END ".>";

	OPERATOR ".<"*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrAXSXLoop );
		RETURN RESULT
	END ".<";


	(*** elementwise greater or equal: array x array -> array of boolean  ********************************************************************)

(** SHORTINT *)
	PROCEDURE EGeqASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqASASLoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqASASLoop );
		RETURN RESULT
	END ".>=";

(** INTEGER *)
	PROCEDURE EGeqAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAIAILoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqAIAILoop );
		RETURN RESULT
	END ".>=";

(** LONGINT *)
	PROCEDURE EGeqALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqALALLoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqALALLoop );
		RETURN RESULT
	END ".>=";

(** REAL *)
	PROCEDURE EGeqARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqARARLoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqARARLoop );
		RETURN RESULT
	END ".>=";

(** LONGREAL *)
	PROCEDURE EGeqAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAXAXLoop;

	OPERATOR ".>="*(CONST left, right: ARRAY [ ? ] OF LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqAXAXLoop );
		RETURN RESULT
	END ".>=";

	(*** elementwise geq  array x scalar ->  array of boolean ********************************************************************)

(** SHORTINT *)
	PROCEDURE EGeqASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqASSSLoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqASSSLoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqASSSLoop );
		RETURN RESULT
	END ".<=";

(** INTEGER *)
	PROCEDURE EGeqAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAISILoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqAISILoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqAISILoop );
		RETURN RESULT
	END ".<=";

(** LONGINT *)
	PROCEDURE EGeqALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqALSLLoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqALSLLoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqALSLLoop );
		RETURN RESULT
	END ".<=";

(** REAL *)
	PROCEDURE EGeqARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqARSRLoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqARSRLoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqARSRLoop );
		RETURN RESULT
	END ".<=";

(** LONGREAL *)
	PROCEDURE EGeqAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval >= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAXSXLoop;

	OPERATOR ".>="*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqAXSXLoop );
		RETURN RESULT
	END ".>=";

	OPERATOR ".<="*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqAXSXLoop );
		RETURN RESULT
	END ".<=";

	(*** elementwise less than: array x array -> array of boolean  ********************************************************************)

(** SHORTINT *)
	PROCEDURE ELssASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssASASLoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssASASLoop );
		RETURN RESULT
	END ".<";

(** INTEGER *)
	PROCEDURE ELssAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssAIAILoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssAIAILoop );
		RETURN RESULT
	END ".<";

(** LONGINT*)
	PROCEDURE ELssALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssALALLoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssALALLoop );
		RETURN RESULT
	END ".<";

(** REAL *)
	PROCEDURE ELssARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssARARLoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssARARLoop );
		RETURN RESULT
	END ".<";

(** LONGREAL *)
	PROCEDURE ELssAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssAXAXLoop;

	OPERATOR ".<"*(CONST left, right: ARRAY [ ? ] OF LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssAXAXLoop );
		RETURN RESULT
	END ".<";

	(*** elementwise less  array x scalar ->  array of boolean ********************************************************************)

(** SHORTINT *)
	PROCEDURE ELssASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssASSSLoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssASSSLoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssASSSLoop );
		RETURN RESULT
	END ".>";

(** INTEGER *)
	PROCEDURE ELssAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssAISILoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssAISILoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssAISILoop );
		RETURN RESULT
	END ".>";

(** LONGINT *)
	PROCEDURE ELssALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssALSLLoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssALSLLoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssALSLLoop );
		RETURN RESULT
	END ".>";

(** REAL *)
	PROCEDURE ELssARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssARSRLoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssARSRLoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssARSRLoop );
		RETURN RESULT
	END ".>";

(** LONGREAL *)
	PROCEDURE ELssAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval < rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELssAXSXLoop;

	OPERATOR ".<"*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssAXSXLoop );
		RETURN RESULT
	END ".<";

	OPERATOR ".>"*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssAXSXLoop );
		RETURN RESULT
	END ".>";


	(*** elementwise less or equal: array x array -> array of boolean ********************************************************************)

(** SHORTINT *)
	PROCEDURE ELeqASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqASASLoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqASASLoop );
		RETURN RESULT
	END ".<=";

(** INTEGER *)
	PROCEDURE ELeqAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAIAILoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqAIAILoop );
		RETURN RESULT
	END ".<=";

(** LONGINT *)
	PROCEDURE ELeqALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqALALLoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqALALLoop );
		RETURN RESULT
	END ".<=";

(** REAL  *)
	PROCEDURE ELeqARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqARARLoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqARARLoop );
		RETURN RESULT
	END ".<=";

(** LONGREAL*)
	PROCEDURE ELeqAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAXAXLoop;

	OPERATOR ".<="*(CONST left, right: ARRAY [ ? ] OF LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqAXAXLoop );
		RETURN RESULT
	END ".<=";

	(*** elementwise leq  array x scalar ->  array of boolean ********************************************************************)

(** SHORTINT *)
	PROCEDURE ELeqASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqASSSLoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqASSSLoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqASSSLoop );
		RETURN RESULT
	END ".>=";

(** INTEGER *)
	PROCEDURE ELeqAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAISILoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqAISILoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqAISILoop );
		RETURN RESULT
	END ".>=";

(** LONGINT *)
	PROCEDURE ELeqALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqALSLLoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqALSLLoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqALSLLoop );
		RETURN RESULT
	END ".>=";

(** REAL *)
	PROCEDURE ELeqARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqARSRLoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF REAL; right: REAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqARSRLoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: REAL; CONST right: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqARSRLoop );
		RETURN RESULT
	END ".>=";

(** LONGREAL *)
	PROCEDURE ELeqAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval <= rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAXSXLoop;

	OPERATOR ".<="*(CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqAXSXLoop );
		RETURN RESULT
	END ".<=";

	OPERATOR ".>="*(left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqAXSXLoop );
		RETURN RESULT
	END ".>=";


	(*** elementwise or, elementwise and  ********************************************************************)

(** array x array *)
	PROCEDURE ElOrABABLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, (lval OR rval) );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ElOrABABLoop;

	OPERATOR "OR"*(CONST left,right : ARRAY [?] OF BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ElOrABABLoop );
		RETURN RESULT
	END "OR";

	PROCEDURE ElAndABABLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval & rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ElAndABABLoop;

	OPERATOR "&"*(CONST left,right : ARRAY [?] OF BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ElAndABABLoop );
		RETURN RESULT
	END "&";

(** array x boolean *)
	PROCEDURE ElOrABSBLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval OR rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ElOrABSBLoop;

	OPERATOR "OR"*(CONST left : ARRAY [?] OF BOOLEAN; right: BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ElOrABSBLoop );
		RETURN RESULT
	END "OR";

	OPERATOR "OR"*(left: BOOLEAN; CONST right : ARRAY [?] OF BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ElOrABSBLoop );
		RETURN RESULT
	END "OR";

	PROCEDURE ElAndABSBLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval & rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ElAndABSBLoop;

	OPERATOR "&"*(CONST left : ARRAY [?] OF BOOLEAN; right: BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ElAndABSBLoop );
		RETURN RESULT
	END "&";

	OPERATOR "&"*(left: BOOLEAN; CONST right : ARRAY [?] OF BOOLEAN):ARRAY [ ? ] OF BOOLEAN;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ElAndABSBLoop );
		RETURN RESULT
	END "&";


	(*** less than, greater or equal: array x array -> boolean  ********************************************************************)

(** SHORTINT *)
	PROCEDURE LssASASLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssASASLoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssASASLoop , FALSE);
	END "<";

	PROCEDURE GeqASASLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqASASLoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqASASLoop , FALSE);
	END ">=";

(** INTEGER *)
	PROCEDURE LssAIAILoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAIAILoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssAIAILoop , FALSE);
	END "<";

	PROCEDURE GeqAIAILoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAIAILoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqAIAILoop , FALSE);
	END ">=";

(** LONGINT *)
	PROCEDURE LssALALLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssALALLoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssALALLoop , FALSE);
	END "<";

	PROCEDURE GeqALALLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqALALLoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqALALLoop , FALSE);
	END ">=";

(** REAL *)
	PROCEDURE LssARARLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssARARLoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssARARLoop , FALSE);
	END "<";

	PROCEDURE GeqARARLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqARARLoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqARARLoop , FALSE);
	END ">=";

(** LONGREAL *)
	PROCEDURE LssAXAXLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval <= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAXAXLoop;

	OPERATOR "<"*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssAXAXLoop , FALSE);
	END "<";

	PROCEDURE GeqAXAXLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval > lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAXAXLoop;

	OPERATOR ">="*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqAXAXLoop , FALSE);
	END ">=";

	(*** less than, greater or equal: array x array -> boolean  ********************************************************************)

(** SHORTINT *)
	PROCEDURE GtrASASLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrASASLoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrASASLoop , FALSE);
	END ">";

	PROCEDURE LeqASASLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqASASLoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqASASLoop , FALSE);
	END "<=";

(** INTEGER *)
	PROCEDURE GtrAIAILoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAIAILoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrAIAILoop , FALSE);
	END ">";

	PROCEDURE LeqAIAILoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAIAILoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqAIAILoop ,FALSE);
	END "<=";

(** LONGINT *)
	PROCEDURE GtrALALLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrALALLoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrALALLoop , FALSE);
	END ">";

	PROCEDURE LeqALALLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqALALLoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqALALLoop , FALSE);
	END "<=";

(** REAL *)
	PROCEDURE GtrARARLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrARARLoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrARARLoop , FALSE);
	END ">";

	PROCEDURE LeqARARLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqARARLoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqARARLoop , FALSE);
	END "<=";

(** LONGREAL *)
	PROCEDURE GtrAXAXLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval >= lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAXAXLoop;

	OPERATOR ">"*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrAXAXLoop , FALSE);
	END ">";

	PROCEDURE LeqAXAXLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval < lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAXAXLoop;

	OPERATOR "<="*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqAXAXLoop , FALSE);
	END "<=";


	(*** equals: array x array -> boolean  ********************************************************************)

(** BOOLEAN *)
	PROCEDURE EqlABABLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlABABLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlABABLoop, FALSE);
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlABABLoop, FALSE);
	END "#";

(** SHORTINT *)
	PROCEDURE EqlASASLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlASASLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlASASLoop , FALSE);
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlASASLoop, FALSE );
	END "#";

(** INTEGER *)
	PROCEDURE EqlAIAILoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAIAILoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAIAILoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAIAILoop, FALSE );
	END "#";

(** LONGINT *)
	PROCEDURE EqlALALLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlALALLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlALALLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlALALLoop, FALSE );
	END "#";

(** REAL *)
	PROCEDURE EqlARARLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlARARLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlARARLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlARARLoop, FALSE );
	END "#";

(** LONGREAL *)
	PROCEDURE EqlAXAXLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAXAXLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAXAXLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAXAXLoop, FALSE );
	END "#";

(** COMPLEX *)
	PROCEDURE EqlAZAZLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: COMPLEX;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );
			IF rval # lval THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAZAZLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF COMPLEX ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAZAZLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF COMPLEX ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAZAZLoop, FALSE );
	END "#";

(** LONGCOMPLEX *)
	PROCEDURE EqlALZALZLoop( ladr, radr, linc, rinc, len: LONGINT ): BOOLEAN;
	VAR lvalRe, lvalIm, rvalRe, rvalIm: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.GET( radr, rvalRe ); SYSTEM.GET( radr+SIZEOF(LONGREAL), rvalIm );
			IF (rvalRe # lvalRe) OR (rvalIm # lvalIm) THEN RETURN FALSE END;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlALZALZLoop;

	OPERATOR "="*( CONST left, right: ARRAY [ ? ] OF LONGCOMPLEX ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlALZALZLoop, FALSE );
	END "=";

	OPERATOR "#"*( CONST left, right: ARRAY [ ? ] OF LONGCOMPLEX ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlALZALZLoop, FALSE );
	END "#";

	(*** equals: array x scalar -> boolean  ********************************************************************)

(** BOOLEAN *)
	PROCEDURE EqlABSBLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlABSBLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF BOOLEAN;
											right: BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlABSBLoop );
	END "=";

	OPERATOR "="*( left: BOOLEAN;
											CONST right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlABSBLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF BOOLEAN;
											  right: BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ~(left = right);
	END "#";

	OPERATOR "#"*( left: BOOLEAN;
											  CONST right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

(** SHORTINT *)
	PROCEDURE EqlASSSLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlASSSLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF SHORTINT;right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlASSSLoop );
	END "=";

	OPERATOR "="*( left: SHORTINT;CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlASSSLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ~( left= right );
	END "#";

	OPERATOR "#"*( left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ~( left= right );
	END "#";

(** INTEGER *)
	PROCEDURE EqlAISILoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAISILoop;

	OPERATOR "="*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAISILoop );
	END "=";

	OPERATOR "="*( left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlAISILoop );
	END "=";

	OPERATOR "#"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

	OPERATOR "#"*( left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

(** LONGINT *)
	PROCEDURE EqlALSLLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlALSLLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF LONGINT;
										   right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlALSLLoop );
	END "=";

	OPERATOR "="*( left: LONGINT;
										   CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlALSLLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF LONGINT;
											right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ~(left = right);
	END "#";

	OPERATOR "#"*( left: LONGINT;
											CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ~(left = right);
	END "#";

(** REAL *)
	PROCEDURE EqlARSRLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlARSRLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF REAL;
											right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlARSRLoop );
	END "=";

	OPERATOR "="*( left: REAL;
											CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlARSRLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF REAL;
											  right: REAL ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

	OPERATOR "#"*( left: REAL;
											  CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

(** LONGREAL *)
	PROCEDURE EqlAXSXLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval # rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END EqlAXSXLoop;

	OPERATOR "="*( CONST left: ARRAY [ ? ] OF LONGREAL;
										    right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAXSXLoop );
	END "=";

	OPERATOR "="*( left: LONGREAL;
										    CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlAXSXLoop );
	END "=";

	OPERATOR "#"*( CONST left: ARRAY [ ? ] OF LONGREAL;
											 right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ~( left = right );
	END "#";

	OPERATOR "#"*( left: LONGREAL;CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ~( left= right );
	END "#";


	(*** gtr : array x scalar -> boolean  ********************************************************************)


(** SHORTINT *)
	PROCEDURE GtrASSSLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrASSSLoop;

	OPERATOR ">"*( CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrASSSLoop );
	END ">";

	OPERATOR "<"*( left: SHORTINT;CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrASSSLoop );
	END "<";

(** INTEGER *)
	PROCEDURE GtrAISILoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAISILoop;

	OPERATOR ">"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrAISILoop );
	END ">";

	OPERATOR "<"*( left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrAISILoop );
	END "<";

(** LONGINT *)
	PROCEDURE GtrALSLLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrALSLLoop;

	OPERATOR ">"*( CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrALSLLoop );
	END ">";

	OPERATOR "<"*( left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrALSLLoop );
	END "<";

(** REAL *)
	PROCEDURE GtrARSRLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrARSRLoop;

	OPERATOR ">"*( CONST left: ARRAY [ ? ] OF REAL;
										    right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrARSRLoop );
	END ">";

	OPERATOR "<"*( left: REAL;
											 CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrARSRLoop );
	END "<";

(** LONGREAL *)
	PROCEDURE GtrAXSXLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval <= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GtrAXSXLoop;

	OPERATOR ">"*( CONST left: ARRAY [ ? ] OF LONGREAL;
										   right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrAXSXLoop );
	END ">";

	OPERATOR "<"*( left: LONGREAL;
										    CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrAXSXLoop );
	END "<";

	(*** geq : array x scalar -> boolean  ********************************************************************)


(** SHORTINT *)
	PROCEDURE GeqASSSLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqASSSLoop;

	OPERATOR ">="*( CONST left: ARRAY [ ? ] OF SHORTINT;
											 right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqASSSLoop );
	END ">=";

	OPERATOR "<="*( left: SHORTINT;
										    CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqASSSLoop );
	END "<=";

(** INTEGER *)
	PROCEDURE GeqAISILoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAISILoop;

	OPERATOR ">="*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqAISILoop );
	END ">=";

	OPERATOR "<="*( left: INTEGER;
										   CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqAISILoop );
	END "<=";

(** LONGINT *)
	PROCEDURE GeqALSLLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqALSLLoop;

	OPERATOR ">="*( CONST left: ARRAY [ ? ] OF LONGINT;
										    right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqALSLLoop );
	END ">=";

	OPERATOR "<="*( left: LONGINT;
										   CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqALSLLoop );
	END "<=";

(** REAL *)
	PROCEDURE GeqARSRLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqARSRLoop;

	OPERATOR ">="*( CONST left: ARRAY [ ? ] OF REAL;
											 right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqARSRLoop );
	END ">=";

	OPERATOR "<="*( left: REAL; CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqARSRLoop );
	END "<=";

(** LONGREAL *)
	PROCEDURE GeqAXSXLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END GeqAXSXLoop;

	OPERATOR ">="*( CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqAXSXLoop );
	END ">=";

	OPERATOR "<="*( left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqAXSXLoop );
	END "<=";

	(*** leq : array x scalar -> boolean  ********************************************************************)


(** SHORTINT *)
	PROCEDURE LeqASSSLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqASSSLoop;

	OPERATOR "<="*( CONST left: ARRAY [ ? ] OF SHORTINT;right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqASSSLoop );
	END "<=";

	OPERATOR ">="*( left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqASSSLoop );
	END ">=";

(** INTEGER *)
	PROCEDURE LeqAISILoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAISILoop;

	OPERATOR "<="*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqAISILoop );
	END "<=";

	OPERATOR ">="*( left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqAISILoop );
	END ">=";

(** LONGINT *)
	PROCEDURE LeqALSLLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqALSLLoop;

	OPERATOR "<="*( CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqALSLLoop );
	END "<=";

	OPERATOR ">="*( left: LONGINT; CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqALSLLoop );
	END ">=";

(** REAL *)
	PROCEDURE LeqARSRLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqARSRLoop;

	OPERATOR "<="*( CONST left: ARRAY [ ? ] OF REAL; right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqARSRLoop );
	END "<=";

	OPERATOR ">="*( left: REAL; CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqARSRLoop );
	END ">=";

(** LONGREAL *)
	PROCEDURE LeqAXSXLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LeqAXSXLoop;

	OPERATOR "<="*( CONST left: ARRAY [ ? ] OF LONGREAL; right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqAXSXLoop );
	END "<=";

	OPERATOR ">="*( left: LONGREAL; CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqAXSXLoop );
	END ">=";



	(*** lss: array x scalar -> boolean  ********************************************************************)


(** SHORTINT *)
	PROCEDURE LssASSSLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssASSSLoop;

	OPERATOR "<"*( CONST left: ARRAY [ ? ] OF SHORTINT; right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssASSSLoop );
	END "<";

	OPERATOR ">"*( left: SHORTINT; CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssASSSLoop );
	END ">";

(** INTEGER *)
	PROCEDURE LssAISILoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAISILoop;

	OPERATOR "<"*(CONST left: ARRAY [ ? ] OF INTEGER; right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssAISILoop );
	END "<";

	OPERATOR ">"*( left: INTEGER; CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssAISILoop );
	END ">";

(** LONGINT *)
	PROCEDURE LssALSLLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssALSLLoop;

	OPERATOR "<"*( CONST left: ARRAY [ ? ] OF LONGINT; right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssALSLLoop );
	END "<";

	OPERATOR ">"*( left: LONGINT;CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssALSLLoop );
	END ">";

(** REAL *)
	PROCEDURE LssARSRLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssARSRLoop;

	OPERATOR "<"*( CONST left: ARRAY [ ? ] OF REAL;
											 right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssARSRLoop );
	END "<";

	OPERATOR ">"*( left: REAL;
										    CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssARSRLoop );
	END ">";

(** LONGREAL *)
	PROCEDURE LssAXSXLoop( ladr, radr, linc, len: LONGINT ): BOOLEAN;
	VAR lval, rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval >= rval THEN RETURN FALSE END;
			INC( ladr, linc );  DEC( len );
		END;
		RETURN TRUE;
	END LssAXSXLoop;

	OPERATOR "<"*( CONST left: ARRAY [ ? ] OF LONGREAL;
										    right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssAXSXLoop );
	END "<";

	OPERATOR ">"*( left: LONGREAL;
										   CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssAXSXLoop );
	END ">";

	(**** binary max/min operators array x scalar-> array ********************************************************************)
	
	PROCEDURE MaxAXSXLoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;;
			INC(dadr,dinc); 
		END;
	END MaxAXSXLoop;
	
	OPERATOR "MAX"*(CONST left: ARRAY [?] OF LONGREAL; right: LONGREAL): ARRAY [?] OF LONGREAL;
	TYPE Type = LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MaxAXSXLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxARSRLoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: REAL;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;;
			INC(dadr,dinc); 
		END;
	END MaxARSRLoop;
	
	OPERATOR "MAX"*(CONST left: ARRAY [?] OF REAL; right: REAL): ARRAY [?] OF REAL;
	TYPE Type = REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MaxARSRLoop );
		RETURN RESULT
	END "MAX";
	
	
	PROCEDURE MaxALSLLoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: LONGINT;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc); 
		END;
	END MaxALSLLoop;
	
	OPERATOR "MAX"*(CONST left: ARRAY [?] OF LONGINT; right: LONGINT): ARRAY [?] OF LONGINT;
	TYPE Type = LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MaxALSLLoop );
		RETURN RESULT
	END "MAX";
	

	PROCEDURE MaxAISILoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: INTEGER;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc); 
		END;
	END MaxAISILoop;
	
	OPERATOR "MAX"*(CONST left: ARRAY [?] OF INTEGER; right: INTEGER): ARRAY [?] OF INTEGER;
	TYPE Type = INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MaxAISILoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxASSSLoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval>val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc); 
		END;
	END MaxASSSLoop;
	
	OPERATOR "MAX"*(CONST left: ARRAY [?] OF SHORTINT; right: SHORTINT): ARRAY [?] OF SHORTINT;
	TYPE Type = SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MaxASSSLoop );
		RETURN RESULT
	END "MAX";
	

	PROCEDURE MinAXSXLoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;;
			INC(dadr,dinc); 
		END;
	END MinAXSXLoop;
	
	OPERATOR "MIN"*(CONST left: ARRAY [?] OF LONGREAL; right: LONGREAL): ARRAY [?] OF LONGREAL;
	TYPE Type = LONGREAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MinAXSXLoop );
		RETURN RESULT
	END "MIN";
	

	PROCEDURE MinARSRLoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: REAL;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;;
			INC(dadr,dinc); 
		END;
	END MinARSRLoop;
	
	OPERATOR "MIN"*(CONST left: ARRAY [?] OF REAL; right: REAL): ARRAY [?] OF REAL;
	TYPE Type = REAL;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MinARSRLoop );
		RETURN RESULT
	END "MIN";
	
	PROCEDURE MinALSLLoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: LONGINT;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc); 
		END;
	END MinALSLLoop;
	
	OPERATOR "MIN"*(CONST left: ARRAY [?] OF LONGINT; right: LONGINT): ARRAY [?] OF LONGINT;
	TYPE Type = LONGINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MinALSLLoop );
		RETURN RESULT
	END "MIN";

	PROCEDURE MinAISILoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: INTEGER;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc); 
		END;
	END MinAISILoop;
	
	OPERATOR "MIN"*(CONST left: ARRAY [?] OF INTEGER; right: INTEGER): ARRAY [?] OF INTEGER;
	TYPE Type = INTEGER;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MinAISILoop );
		RETURN RESULT
	END "MIN";
	
	PROCEDURE MinASSSLoop( ladr, radr, dadr, linc, dinc, len: Address ); 
	VAR lval, val: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, val );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			INC( ladr, linc ); DEC( len );
			IF lval<val THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT(dadr, val) END;
			INC(dadr,dinc); 
		END;
	END MinASSSLoop;
	
	OPERATOR "MIN"*(CONST left: ARRAY [?] OF SHORTINT; right: SHORTINT): ARRAY [?] OF SHORTINT;
	TYPE Type = SHORTINT;
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( Type ), MinASSSLoop );
		RETURN RESULT
	END "MIN";

	(**** binary max/min operators array x array -> array ********************************************************************)

	PROCEDURE MaxAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval ); 
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MaxAXAXLoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF LONGREAL): ARRAY [?] OF LONGREAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGREAL ), MaxAXAXLoop );
		RETURN RESULT
	END "MAX";
	

	PROCEDURE MaxARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: REAL ;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval ); 
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MaxARARLoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF REAL): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ), MaxARARLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MaxALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval ); 
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MaxALALLoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF LONGINT): ARRAY [?] OF LONGINT ;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGINT ), MaxALALLoop );
		RETURN RESULT
	END "MAX";
	
		PROCEDURE MaxAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval ); 
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MaxAIAILoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF INTEGER): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( INTEGER ), MaxAIAILoop );
		RETURN RESULT
	END "MAX";
	
	PROCEDURE MaxASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval ); 
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval>rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MaxASASLoop;

	OPERATOR "MAX"*(CONST left, right: ARRAY [?] OF SHORTINT): ARRAY [?] OF SHORTINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( SHORTINT ), MaxASASLoop );
		RETURN RESULT
	END "MAX";

	PROCEDURE MinAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval );
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MinAXAXLoop;
	
	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF LONGREAL): ARRAY [?] OF LONGREAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGREAL ), MinAXAXLoop );
		RETURN RESULT
	END "MIN";
		

	PROCEDURE MinARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: REAL ;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval ); 
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MinARARLoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF REAL): ARRAY [?] OF REAL;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ), MinARARLoop );
		RETURN RESULT
	END "MIN";

	PROCEDURE MinALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval ); 
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MinALALLoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF LONGINT): ARRAY [?] OF LONGINT ;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGINT ), MinALALLoop );
		RETURN RESULT
	END "MIN";
	
	PROCEDURE MinAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval ); 
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MinAIAILoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF INTEGER): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( INTEGER ), MinAIAILoop );
		RETURN RESULT
	END "MIN";
	
	PROCEDURE MinASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: Address ); 
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval ); SYSTEM.GET( radr, rval ); 
			INC( ladr, linc ); INC(radr,rinc ); DEC( len );
			IF lval<rval THEN SYSTEM.PUT( dadr, lval) ELSE SYSTEM.PUT (dadr,rval) END;
			INC(dadr,dinc); 
		END;
	END MinASASLoop;

	OPERATOR "MIN"*(CONST left, right: ARRAY [?] OF SHORTINT): ARRAY [?] OF SHORTINT;
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( SHORTINT ), MinASASLoop );
		RETURN RESULT
	END "MIN";

	(**** unary operators array -> scalar ********************************************************************)

	(*** min: array -> scalar ****************************************)

(** SHORTINT *)
	PROCEDURE MinASLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: SHORTINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinASLoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF SHORTINT ): SHORTINT;
	TYPE Type = SHORTINT;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinASLoop );  RETURN val;
	END "MIN";

(** INTEGER *)
	PROCEDURE MinAILoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: INTEGER;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinAILoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF INTEGER ): INTEGER;
	TYPE Type = INTEGER;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinAILoop );  RETURN val;
	END "MIN";

(** LONGINT *)
	PROCEDURE MinALLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: LONGINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinALLoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF LONGINT ): LONGINT;
	TYPE Type = LONGINT;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinALLoop );  RETURN val;
	END "MIN";

(** REAL *)
	PROCEDURE MinARLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: REAL;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinARLoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF REAL ): REAL;
	TYPE Type = REAL;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinARLoop );  RETURN val;
	END "MIN";

(** LONGREAL *)
	PROCEDURE MinAXLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: LONGREAL;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval < dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MinAXLoop;

	OPERATOR "MIN"*( CONST left: ARRAY [ ? ] OF LONGREAL ): LONGREAL;
	TYPE Type = LONGREAL;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinAXLoop );  RETURN val;
	END "MIN";

	(*** max: array -> scalar  ********************************************************************)

(** SHORTINT *)
	PROCEDURE MaxASLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: SHORTINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxASLoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF SHORTINT ): SHORTINT;
	TYPE Type = SHORTINT;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxASLoop );  RETURN val;
	END "MAX";

(** INTEGER *)
	PROCEDURE MaxAILoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: INTEGER;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxAILoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF INTEGER ): INTEGER;
	TYPE Type = INTEGER;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxAILoop );  RETURN val;
	END "MAX";

(** LONGINT *)
	PROCEDURE MaxALLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: LONGINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxALLoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF LONGINT ): LONGINT;
	TYPE Type = LONGINT;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxALLoop );  RETURN val;
	END "MAX";

(** REAL *)
	PROCEDURE MaxARLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: REAL;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxARLoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF REAL ): REAL;
	TYPE Type = REAL;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxARLoop );  RETURN val;
	END "MAX";

(** LONGREAL *)
	PROCEDURE MaxAXLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: LONGREAL;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );
			IF lval > dval THEN dval := lval END;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MaxAXLoop;

	OPERATOR "MAX"*( CONST left: ARRAY [ ? ] OF LONGREAL ): LONGREAL;
	TYPE Type = LONGREAL;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxAXLoop );  RETURN val;
	END "MAX";

	(*** LEN: array -> array **)

	OPERATOR "LEN"*(CONST left: ARRAY [?]): ARRAY [*] OF LONGINT;
	VAR src,dim,i: LONGINT;
	BEGIN
		src := SYSTEM.VAL(LONGINT,left);
		dim := GetDim( src );
		IF (DIM(RESULT)#1) OR (LEN(RESULT,0) # dim) THEN NEW(RESULT,dim) END;
		FOR i := 0 TO dim-1 DO RESULT[i] := GetLen(src,i) END;
		RETURN RESULT
	END "LEN";


	(*** SUM: array -> scalar  ********************************************************************)

(** SHORTINT *)
	PROCEDURE SumASLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: SHORTINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumASLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF SHORTINT ): SHORTINT;
	TYPE Type = SHORTINT;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumASLoop );
		RETURN val;
	END "SUM";

(** INTEGER *)
	PROCEDURE SumAILoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: INTEGER;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumAILoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF INTEGER ): INTEGER;
	TYPE Type = INTEGER;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumAILoop );
		RETURN val;
	END "SUM";

(** LONGINT *)
	PROCEDURE SumALLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: LONGINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumALLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF LONGINT ): LONGINT;
	TYPE Type = LONGINT;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumALLoop );
		RETURN val;
	END "SUM";

(** REAL *)
	PROCEDURE SumARLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: REAL;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumARLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF REAL ): REAL;
	TYPE Type = REAL;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumARLoop );
		RETURN val;
	END "SUM";

(** LONGREAL *)
	PROCEDURE SumAXLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: LONGREAL;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumAXLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF LONGREAL ): LONGREAL;
	TYPE Type = LONGREAL;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumAXLoop );
		RETURN val;
	END "SUM";


(** COMPLEX *)
	PROCEDURE SumAZLoop( ladr, dadr, linc, len: LONGINT );
	VAR lval, dval: COMPLEX;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := dval + lval;  INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END SumAZLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF COMPLEX ): COMPLEX;
	TYPE Type = COMPLEX;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumAZLoop );
		RETURN val;
	END "SUM";

(** LONGCOMPLEX *)
	PROCEDURE SumALZLoop( ladr, dadr, linc, len: LONGINT );
	VAR lvalRe, lvalIm, dvalRe, dvalIm: LONGREAL;
	BEGIN
		SYSTEM.GET( dadr, dvalRe ); SYSTEM.GET( dadr+SIZEOF(LONGREAL), dvalIm );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			dvalRe := dvalRe + lvalRe; dvalIm := dvalIm + lvalIm;
			INC( ladr, linc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), dvalIm );
	END SumALZLoop;

	OPERATOR "SUM"*( CONST left: ARRAY [ ? ] OF LONGCOMPLEX ): LONGCOMPLEX;
	TYPE Type = LONGCOMPLEX;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumALZLoop );
		RETURN val;
	END "SUM";

	(*** monadic ABS array -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE AbsLoopS( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopS;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF SHORTINT): ARRAY [ ? ] OF SHORTINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( SHORTINT ), AbsLoopS );
		RETURN RESULT
	END "ABS";

(** INTEGER *)
	PROCEDURE AbsLoopI( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopI;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF INTEGER): ARRAY [ ? ] OF INTEGER;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( INTEGER ), AbsLoopI );
		RETURN RESULT
	END "ABS";

(** LONGINT *)
	PROCEDURE AbsLoopL( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopL;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF LONGINT): ARRAY [ ? ] OF LONGINT;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGINT ), AbsLoopL );
		RETURN RESULT
	END "ABS";

(** REAL *)
	PROCEDURE AbsLoopR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopR;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF REAL): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( REAL ), AbsLoopR );
		RETURN RESULT
	END "ABS";

(** LONGREAL *)
	PROCEDURE AbsLoopX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopX;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF LONGREAL): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGREAL ), AbsLoopX );
		RETURN RESULT
	END "ABS";

(** COMPLEX *)
	PROCEDURE AbsLoopZ( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: COMPLEX;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS(lval) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopZ;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF COMPLEX): ARRAY [ ? ] OF REAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( REAL ), AbsLoopZ );
		RETURN RESULT
	END "ABS";

(** LONGCOMPLEX *)
	PROCEDURE AbsLoopLZ( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lvalRe, lvalIm: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
			SYSTEM.PUT( dadr, MathL.sqrt(lvalRe*lvalRe + lvalIm*lvalIm) );
			INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopLZ;

	OPERATOR "ABS"*(CONST src: ARRAY [ ? ] OF LONGCOMPLEX): ARRAY [ ? ] OF LONGREAL;
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( RESULT ), ADDRESSOF( src ), SIZEOF( LONGREAL ), AbsLoopLZ );
		RETURN RESULT
	END "ABS";

	(*** assign number to array  (initialisation) ********************************************************************)

(** BOOLEAN *)
	PROCEDURE AssignSBABLoop( ladr, dadr, dinc, len: LONGINT );
	VAR lval: BOOLEAN;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSBABLoop;

	OPERATOR ":="*(VAR dest: ARRAY [?] OF BOOLEAN; right: BOOLEAN);
	BEGIN
		ApplyUnarySAOp( ADDRESSOF( dest ), ADDRESSOF( right ), AssignSBABLoop );
	END ":=";

(** SHORTINT*)
	PROCEDURE AssignSSASLoop( ladr, dadr, dinc, len: LONGINT );
	VAR lval: SHORTINT;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSSASLoop;

	OPERATOR ":="*(VAR dest: ARRAY [?] OF SHORTINT; right: SHORTINT);
	BEGIN
		ApplyUnarySAOp( ADDRESSOF( dest ), ADDRESSOF( right ), AssignSSASLoop );
	END ":=";

(**INTEGER *)
	PROCEDURE AssignSIAILoop( ladr, dadr, dinc, len: LONGINT );
	VAR lval: INTEGER;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSIAILoop;

	OPERATOR ":="*(VAR dest: ARRAY [?] OF INTEGER; right: INTEGER);
	BEGIN
		ApplyUnarySAOp( ADDRESSOF( dest ), ADDRESSOF( right ), AssignSIAILoop );
	END ":=";


(** LONGINT *)
	PROCEDURE AssignSLALLoop( ladr, dadr, dinc, len: LONGINT );
	VAR lval: LONGINT;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSLALLoop;

	OPERATOR ":="*(VAR dest: ARRAY [?] OF LONGINT; right: LONGINT);
	BEGIN
		ApplyUnarySAOp( ADDRESSOF( dest ), ADDRESSOF( right ), AssignSLALLoop );
	END ":=";


(** REAL *)
	PROCEDURE AssignSRARLoop( ladr, dadr, dinc, len: LONGINT );
	VAR lval: REAL;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSRARLoop;

	OPERATOR ":="*(VAR dest: ARRAY [?] OF REAL; right: REAL);
	BEGIN
		ApplyUnarySAOp( ADDRESSOF( dest ), ADDRESSOF( right ), AssignSRARLoop );
	END ":=";


(** LONGREAL *)
	PROCEDURE AssignSXAXLoop( ladr, dadr, dinc, len: LONGINT );
	VAR lval: LONGREAL;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSXAXLoop;

	OPERATOR ":="*(VAR dest: ARRAY [?] OF LONGREAL; right: LONGREAL);
	BEGIN
		ApplyUnarySAOp( ADDRESSOF( dest ), ADDRESSOF( right ), AssignSXAXLoop );
	END ":=";

(** COMPLEX *)
	PROCEDURE AssignSZAZLoop( ladr, dadr, dinc, len: LONGINT );
	VAR lval: COMPLEX;
	BEGIN
		SYSTEM.GET( ladr, lval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignSZAZLoop;

	OPERATOR ":="*(VAR dest: ARRAY [?] OF COMPLEX; right: COMPLEX);
	BEGIN
		ApplyUnarySAOp( ADDRESSOF( dest ), ADDRESSOF( right ), AssignSZAZLoop );
	END ":=";

(** LONGCOMPLEX *)
	PROCEDURE AssignSLZALZLoop( ladr, dadr, dinc, len: LONGINT );
	VAR lvalRe, lvalIm: LONGREAL;
	BEGIN
		SYSTEM.GET( ladr, lvalRe ); SYSTEM.GET( ladr+SIZEOF(LONGREAL), lvalIm );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, lvalRe ); SYSTEM.PUT( dadr+SIZEOF(LONGREAL), lvalIm ); INC( dadr, dinc );  DEC( len );  END;
	END AssignSLZALZLoop;

	OPERATOR ":="*(VAR dest: ARRAY [?] OF LONGCOMPLEX; right: LONGCOMPLEX);
	BEGIN
		ApplyUnarySAOp( ADDRESSOF( dest ), ADDRESSOF( right ), AssignSLZALZLoop );
	END ":=";


(*** matrix multipliation ********************************************************************)

	PROCEDURE AllocateMatrix( dest: Address;
													rows, cols, elementsize: LONGINT ): ANY;
	VAR p: ANY;
	BEGIN
		(*
		KernelLog.String( "ALLOCATE MATRIX WAS CALLED" );  KernelLog.Ln;
		*)
		SYSTEM.NEW( p, rows * cols * elementsize );  PutLen( dest, 1, cols );
		PutLen( dest, 0, rows );  PutInc( dest, 1, elementsize );
		PutInc( dest, 0, elementsize * cols );  PutAdr( dest, SYSTEM.VAL( LONGINT, p ) );
		PutPtr( dest, SYSTEM.VAL( LONGINT, p ) );  RETURN p;
	END AllocateMatrix;

	PROCEDURE AllocateVector( dest: Address;  l0, elementsize: LONGINT ): ANY;
	VAR p: ANY;
	BEGIN
		SYSTEM.NEW( p, l0 * elementsize );  PutLen( dest, 0, l0 );
		PutInc( dest, 0, elementsize );  PutAdr( dest, SYSTEM.VAL( LONGINT, p ) );
		PutPtr( dest, SYSTEM.VAL( LONGINT, p ) );  RETURN p;
	END AllocateVector;

	PROCEDURE ApplyMatMulLoop( dest, left, right: Address;  Size: LONGINT;
														 loop: BinaryAASLoop;
	fast: FastMatMul );   (* Size= element-size *)
	VAR ladr, radr, dadr, dadri, radri, rowsL, colsL, rowsR, colsR, incL, incR, incD, strideR, strideL, strideD, colsRi: LONGINT;
		p: ANY;  overlap: BOOLEAN;  destOld, destNew: LONGINT;
	BEGIN
	(*
				<- 1 ->
			xxx  xxxx  ->  xxxx
	^	  xxx  xxxx        xxxx
	0	  xxx  xxxx        xxxx
	v	   xxx                  xxxx
			xxx                  xxxx

			Len(..,1): #columns ; Inc(..,1): inc in rows
			Len(..,0): #rows ; Inc(..,0): inc between rows

	*)

		(* apply multiplication D = L * R *)

		rowsL := GetLen( left, 0 );   (* # left rows  = # dest rows*)
		colsL := GetLen( left, 1 );   (* # left columns  *)
		rowsR := GetLen( right, 0 );   (* # right rows  =!= left columns *)
		colsR := GetLen( right, 1 );   (* # right columns = # dest columns*)

		(* check geometric restriction *)
		IF colsL # rowsR THEN Halt( GeometryMismatch, left, right, 0 );  END;

		IF GetAdr( dest ) = 0 THEN p := AllocateMatrix( dest, rowsL, colsR, Size );
		ELSIF (GetLen( dest, 0 ) # rowsL) OR (GetLen( dest, 1 ) # colsR) THEN
			IF RangeFlag IN GetFlags( dest ) THEN
				Halt( GeometryMismatch, left, right, dest )
			ELSE p := AllocateMatrix( dest, rowsL, colsR, Size );
			END;
		END;

		overlap := Overlap( left, dest ) OR Overlap( right, dest );
		IF overlap THEN
			destOld := dest;  destNew := 0;
			p := AllocateSame( destNew, destOld, Size );
			CopyContent( destNew, destOld, Size );   (* for INCMUL ! *)
			dest := destNew;
		END;

		IF (GetLen( dest, 0 ) # rowsL) OR (GetLen( dest, 1 ) # colsR) THEN
			HALT( 9999 )
		END;

		ladr := GetAdr( left );  radr := GetAdr( right );  dadr := GetAdr( dest );

		incL := GetIncr( left, 1 );  strideL := GetIncr( left, 0 );   (* increment and stride of left matrix *)
		incR := GetIncr( right, 1 );  strideR := GetIncr( right, 0 );   (* increment and stride of right matrix *)
		incD := GetIncr( dest, 1 );  strideD := GetIncr( dest, 0 );   (* increment and stride of dest matrix *)

		(*
		KernelLog.String("incD="); KernelLog.Int(incD,10); KernelLog.Ln;
		KernelLog.String("strideD="); KernelLog.Int(strideD,10); KernelLog.Ln;
		KernelLog.String("Len(dest,0) [rows]="); KernelLog.Int(GetLen(dest,0),10); KernelLog.Ln;
		KernelLog.String("Len(dest,1) [cols]="); KernelLog.Int(GetLen(dest,1),10); KernelLog.Ln;
		*)

		IF rowsL = 0 THEN RETURN
		ELSIF colsL=0 THEN RETURN
		ELSIF colsR=0 THEN RETURN
		ELSIF (fast = NIL ) OR
		    ~(fast( ladr, radr, dadr, incL, strideL, incR, strideR, incD, strideD, rowsL, colsL, rowsR, colsR )) THEN
			WHILE (rowsL > 0) DO  (* outer loop: traverse rows of left matrix *)
				radri := radr;  dadri := dadr;  colsRi := colsR;
				WHILE (colsRi > 0) DO  (* inner loop: traverse columns of right matrix *)
					loop( ladr, radri, dadri, incL, strideR, colsL );  INC( radri, incR );
					INC( dadri, incD );  DEC( colsRi );
				END;
				INC( ladr, strideL );  INC( dadr, strideD );  DEC( rowsL );
			END;
		END;

		IF overlap THEN CopyContent( destOld, dest, Size );
		END;
	END ApplyMatMulLoop;

	PROCEDURE ApplyMatVecMulLoop( dest, left, right: Address;
															   Size: LONGINT;  loop: BinaryAASLoop;
															   fast: FastMatMul );   (* Size= element-size *)
	VAR ladr, radr, dadr, li1, li0, ri0, di0, l1, l2: LONGINT;  p: ANY;
		overlap: BOOLEAN;  destOld, destNew: LONGINT;

	BEGIN
	(*
				<- 0 ->
			xxx  T(xxx)  ->  T(xxxxx)
			xxx
	1	  xxx
			xxx
			xxx

			Len(..,0): #columns ; Inc(..,0): inc in rows
			Len(..,1): #rows ; Inc(..,1): inc between rows

	*)
		(* check geometric restriction *)
		IF GetLen( left, 1 ) # GetLen( right, 0 ) THEN
			Halt( GeometryMismatch, left, right,0 );
		END;

		l1 := GetLen( left, 0 );   (* number of destination's rows *)
		l2 := GetLen( left, 1 );   (* inner loop len *)
		IF GetAdr( dest ) = 0 THEN p := AllocateVector( dest, l1, Size );
		ELSIF (GetLen( dest, 0 ) # l1) THEN
			IF RangeFlag IN GetFlags( dest ) THEN
				Halt( GeometryMismatch, left, right, dest );
			ELSE p := AllocateVector( dest, l1, Size );
			END;
		END;

		overlap := Overlap( left, dest ) OR Overlap( right, dest );
		IF overlap THEN
			destOld := dest;  destNew := 0;
			p := AllocateSame( destNew, destOld, Size );
			CopyContent( destNew, destOld, Size );   (* for INCMUL ! *)
			dest := destNew;
		END;


		(*
		IF GetAdr( dest ) = -1 THEN p := AllocateVector( dest, l1, Size );  ELSE
			IF (GetLen( dest, 0 ) # l1) THEN HALT( 102 ) END;
		END;
*)
		ladr := GetAdr( left );  radr := GetAdr( right );  dadr := GetAdr( dest );
		li0 := GetIncr( left, 1 );  li1 := GetIncr( left, 0 );  ri0 := GetIncr( right, 0 );
		di0 := GetIncr( dest, 0 );

		IF l1=0 THEN RETURN
		ELSIF l2=0 THEN RETURN
		ELSIF (fast = NIL ) OR
		    ~(fast( ladr, radr, dadr, li0, li1, ri0, ri0, di0, di0, l1, l2, l2, 1 )) THEN
			WHILE (l1 > 0) DO  (* inner loop: traverse columns of right matrix *)
				loop( ladr, radr, dadr, li0, ri0, l2 );  INC( ladr, li1 );  INC( dadr, di0 );
				DEC( l1 );
			END;
		END;

		IF overlap THEN CopyContent( destOld, dest, Size );
		END;

	END ApplyMatVecMulLoop;

	PROCEDURE ApplyVecMatMulLoop( dest, left, right: Address;
															   Size: LONGINT;  loop: BinaryAASLoop;
															   fast: FastMatMul );   (* Size= element-size *)
	VAR ladr, radr, dadr, li0, ri1, ri0, di0, l0, l2: LONGINT;  p: ANY;
		overlap: BOOLEAN;  destOld, destNew: LONGINT;

	BEGIN
	(*
				<- 0 ->
			xxx  xxxx  ->  xxxx
			       xxxx
	1	         xxxx

			Len(..,0): #columns ; Inc(..,0): inc in rows
			Len(..,1): #rows ; Inc(..,1): inc between rows

	*)
		(* check geometric restriction *)
		IF GetLen( left, 0 ) # GetLen( right, 0 ) THEN HALT( GeometryMismatch );  END;

		l0 := GetLen( right, 1 );   (* number of destination's column *)
		l2 := GetLen( right, 0 );   (* inner loop len *)
		IF GetAdr( dest ) = 0 THEN p := AllocateVector( dest, l0, Size );
		ELSIF (GetLen( dest, 0 ) # l0) THEN
			IF RangeFlag IN GetFlags( dest ) THEN HALT( GeometryMismatch )
			ELSE p := AllocateVector( dest, l0, Size );
			END;
		END;

		overlap := Overlap( left, dest ) OR Overlap( right, dest );
		IF overlap THEN
			destOld := dest;  destNew := 0;
			p := AllocateSame( destNew, destOld, Size );
			CopyContent( destNew, destOld, Size );   (* for INCMUL ! *)
			dest := destNew;
		END;


		(*
			IF GetAdr( dest ) = -1 THEN p := AllocateVector( dest, l0, Size );  ELSE
			IF (GetLen( dest, 0 ) # l0) THEN HALT( 102 ) END;
		END;
		*)

		ladr := GetAdr( left );  radr := GetAdr( right );  dadr := GetAdr( dest );
		li0 := GetIncr( left, 0 );  ri0 := GetIncr( right, 1 );  ri1 := GetIncr( right, 0 );
		di0 := GetIncr( dest, 0 );

		IF l2=0 THEN RETURN
		ELSIF l0=0 THEN RETURN
		ELSIF (fast = NIL ) OR ~fast( ladr, radr, dadr, li0, li0, ri0, ri1, di0, di0, 1, l2, l2, l0 ) THEN
			WHILE (l0 > 0) DO  (* inner loop: traverse columns of right matrix *)
				loop( ladr, radr, dadr, li0, ri1, l2 );  INC( radr, ri0 );  INC( dadr, di0 );
				DEC( l0 );
			END;
		END;

		IF overlap THEN CopyContent( destOld, dest, Size );
		END;
	END ApplyVecMatMulLoop;


(** SHORTINT *)
	PROCEDURE MatMulASASLoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: SHORTINT;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			(* KernelLog.String("mul with: "); KernelLog.Int(lval,10); KernelLog.Int(rval,10); KernelLog.Ln; *)
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulASASLoop;

	OPERATOR "*"*(CONST left, right: ARRAY [ * , * ] OF SHORTINT ): ARRAY [ * , * ] OF SHORTINT;
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( SHORTINT ), MatMulASASLoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF SHORTINT; CONST right: ARRAY [ * ] OF SHORTINT): ARRAY [ * ] OF SHORTINT;
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulASASLoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*( CONST left: ARRAY [ * ] OF SHORTINT; CONST right: ARRAY [ * , * ] OF SHORTINT  ): ARRAY [ * ] OF SHORTINT;
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulASASLoop, NIL );
		RETURN RESULT
	END "*";

(** INTEGER *)
	PROCEDURE MatMulAIAILoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: INTEGER;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulAIAILoop;

	OPERATOR "*"*(  CONST left, right: ARRAY [ * , * ] OF INTEGER ): ARRAY [ * , * ] OF INTEGER;
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( INTEGER ), MatMulAIAILoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF INTEGER;
													    CONST right: ARRAY [ * ] OF INTEGER  ): ARRAY [ * ] OF INTEGER;
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulAIAILoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * ] OF INTEGER;
													    CONST right: ARRAY [ * , * ] OF INTEGER ): ARRAY [ * ] OF INTEGER;
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulAIAILoop, NIL );
		RETURN RESULT
	END "*";

(** LONGINT *)
	PROCEDURE MatMulALALLoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: LONGINT;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulALALLoop;

	OPERATOR "*"*(CONST left, right: ARRAY [ * , * ] OF LONGINT ): ARRAY [ * , * ] OF LONGINT;
	BEGIN
		(*
		KernelLog.String("MatMulALAL");
		KernelLog.Int(SYSTEM.VAL(LONGINT,dest),10);
		KernelLog.Int(SYSTEM.VAL(LONGINT,left),10);
		KernelLog.Int(SYSTEM.VAL(LONGINT,right),10);
		KernelLog.Ln;
		*)

		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGINT ), MatMulALALLoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF LONGINT; CONST right: ARRAY [ * ] OF LONGINT  ): ARRAY [ * ] OF LONGINT;
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulALALLoop, NIL );
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left: ARRAY [ * ] OF LONGINT;
														CONST right: ARRAY [ * , * ] OF LONGINT): ARRAY [ * ] OF LONGINT;
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulALALLoop, NIL );
		RETURN RESULT
	END "*";

(** REAL *)
	PROCEDURE MatMulARARLoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: REAL;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulARARLoop;

	(*
		Optimized for small matrices (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	OPERATOR "*"*(CONST left, right: ARRAY [ * , * ] OF REAL ): ARRAY [ * , * ] OF REAL;
	VAR flags: SET; dadr, ladr, radr: LONGINT;
	BEGIN

		dadr := GetAdr(ADDRESSOF(RESULT));
		ladr := GetAdr(ADDRESSOF(left));
		radr := GetAdr(ADDRESSOF(right));

		(* account possible inplace left := left*right, right := left*right, left := left*left, right := right*right *)
		IF (ladr # dadr) & (radr # dadr) THEN

			flags := SmallArrayMask * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(left)+MathFlagsOffset)) * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(right)+MathFlagsOffset));

			CASE SYSTEM.VAL(LONGINT,flags) OF

				Mat2x2:
					IF SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset)) * SmallArrayMask) # Mat2x2 THEN
						IF dadr = 0 THEN NEW(RESULT,2,2);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulR2x2 # NIL THEN matMulR2x2(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1];
						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1];
					END;

				|Mat3x3:
					IF SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset)) * SmallArrayMask) # Mat3x3 THEN
						IF dadr = 0 THEN NEW(RESULT,3,3);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulR3x3 # NIL THEN matMulR3x3(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1];
						RESULT[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2];

						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1];
						RESULT[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2];

						RESULT[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0];
						RESULT[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1];
						RESULT[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2];
					END;


				|Mat4x4:
					IF SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset)) * SmallArrayMask) # Mat4x4 THEN
						IF dadr = 0 THEN NEW(RESULT,4,4);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulR4x4 # NIL THEN matMulR4x4(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0] + left[0,3]*right[3,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1] + left[0,3]*right[3,1];
						RESULT[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2] + left[0,3]*right[3,2];
						RESULT[0,3] := left[0,0]*right[0,3] + left[0,1]*right[1,3] + left[0,2]*right[2,3] + left[0,3]*right[3,3];

						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0] + left[1,3]*right[3,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1] + left[1,3]*right[3,1];
						RESULT[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2] + left[1,3]*right[3,2];
						RESULT[1,3] := left[1,0]*right[0,3] + left[1,1]*right[1,3] + left[1,2]*right[2,3] + left[1,3]*right[3,3];

						RESULT[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0] + left[2,3]*right[3,0];
						RESULT[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1] + left[2,3]*right[3,1];
						RESULT[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2] + left[2,3]*right[3,2];
						RESULT[2,3] := left[2,0]*right[0,3] + left[2,1]*right[1,3] + left[2,2]*right[2,3] + left[2,3]*right[3,3];

						RESULT[3,0] := left[3,0]*right[0,0] + left[3,1]*right[1,0] + left[3,2]*right[2,0] + left[3,3]*right[3,0];
						RESULT[3,1] := left[3,0]*right[0,1] + left[3,1]*right[1,1] + left[3,2]*right[2,1] + left[3,3]*right[3,1];
						RESULT[3,2] := left[3,0]*right[0,2] + left[3,1]*right[1,2] + left[3,2]*right[2,2] + left[3,3]*right[3,2];
						RESULT[3,3] := left[3,0]*right[0,3] + left[3,1]*right[1,3] + left[3,2]*right[2,3] + left[3,3]*right[3,3];
					END;
			ELSE
				ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
									    loopMatMulARAR, matMulR );
			END;
		ELSE
			ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
									    loopMatMulARAR, matMulR );
		END;
		RETURN RESULT
	END "*";

	(*
		Optimized for small arrays (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF REAL; CONST right: ARRAY [ * ] OF REAL ): ARRAY [ * ] OF REAL;
	VAR
		flags: SET; dadr, ladr, radr: LONGINT;
		v0, v1, v2: REAL;
	BEGIN

		dadr := GetAdr(ADDRESSOF(RESULT));
		ladr := GetAdr(ADDRESSOF(left));
		radr := GetAdr(ADDRESSOF(right));

		flags := SmallArrayMask * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(left)+MathFlagsOffset)) * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(right)+MathFlagsOffset));

		CASE SYSTEM.VAL(LONGINT,flags) OF

			MatVec2x2:
				IF SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset)) * SmallArrayMask) # Vec2 THEN
					IF dadr = 0 THEN NEW(RESULT,2);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulR2x2 # NIL THEN matVecMulR2x2(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0];
					RESULT[0] := left[0,0]*v0 + left[0,1]*right[1];
					RESULT[1] := left[1,0]*v0 + left[1,1]*right[1];
				END;

			|MatVec3x3:
				IF SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset)) * SmallArrayMask) # Vec3 THEN
					IF dadr = 0 THEN NEW(RESULT,3);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulR3x3 # NIL THEN matVecMulR3x3(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1];
					RESULT[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*right[2];
					RESULT[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*right[2];
					RESULT[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*right[2];
				END;

			|MatVec4x4:
				IF SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset)) * SmallArrayMask) # Vec4 THEN
					IF dadr = 0 THEN NEW(RESULT,4);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulR4x4 # NIL THEN matVecMulR4x4(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1]; v2 := right[2];
					RESULT[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*v2 + left[0,3]*right[3];
					RESULT[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*v2 + left[1,3]*right[3];
					RESULT[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*v2 + left[2,3]*right[3];
					RESULT[3] := left[3,0]*v0 + left[3,1]*v1 + left[3,2]*v2 + left[3,3]*right[3];
				END;

		ELSE
			ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulARAR, matMulR );
		END;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(  CONST left: ARRAY [ * ] OF REAL;
														  CONST right: ARRAY [ * , * ] OF REAL  ): ARRAY [ * ] OF REAL;
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulARAR, matMulR );
		RETURN RESULT
	END "*";

(** LONGREAL *)

	PROCEDURE MatMulAXAXLoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: LONGREAL;
	BEGIN
		dval := 0;
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulAXAXLoop;

	(*
		Optimized for small matrices (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	OPERATOR "*"*( CONST left, right: ARRAY [ * , * ] OF LONGREAL): ARRAY [ * , * ] OF LONGREAL;
	VAR
		flags: SET; dadr, ladr, radr: LONGINT;
	BEGIN

		dadr := GetAdr(ADDRESSOF(RESULT));
		ladr := GetAdr(ADDRESSOF(left));
		radr := GetAdr(ADDRESSOF(right));


		IF (ladr # dadr) & (radr # dadr) THEN

			flags := SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(left)+MathFlagsOffset)) * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(right)+MathFlagsOffset));

			CASE SYSTEM.VAL(LONGINT,flags) OF
				Mat2x2:
					IF SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset) # Mat2x2 THEN
						IF dadr = 0 THEN NEW(RESULT,2,2);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulLR2x2 # NIL THEN matMulLR2x2(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1];
						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1];
					END;

				|Mat3x3:
					IF SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset) # Mat3x3 THEN
						IF dadr = 0 THEN NEW(RESULT,3,3);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulLR3x3 # NIL THEN matMulLR3x3(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1];
						RESULT[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2];

						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1];
						RESULT[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2];

						RESULT[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0];
						RESULT[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1];
						RESULT[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2];
					END;


				|Mat4x4:
					IF SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset) # Mat4x4 THEN
						IF dadr = 0 THEN NEW(RESULT,4,4);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulLR4x4 # NIL THEN matMulLR4x4(dadr,ladr,radr);
					ELSE
						RESULT[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0] + left[0,3]*right[3,0];
						RESULT[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1] + left[0,3]*right[3,1];
						RESULT[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2] + left[0,3]*right[3,2];
						RESULT[0,3] := left[0,0]*right[0,3] + left[0,1]*right[1,3] + left[0,2]*right[2,3] + left[0,3]*right[3,3];

						RESULT[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0] + left[1,3]*right[3,0];
						RESULT[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1] + left[1,3]*right[3,1];
						RESULT[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2] + left[1,3]*right[3,2];
						RESULT[1,3] := left[1,0]*right[0,3] + left[1,1]*right[1,3] + left[1,2]*right[2,3] + left[1,3]*right[3,3];

						RESULT[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0] + left[2,3]*right[3,0];
						RESULT[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1] + left[2,3]*right[3,1];
						RESULT[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2] + left[2,3]*right[3,2];
						RESULT[2,3] := left[2,0]*right[0,3] + left[2,1]*right[1,3] + left[2,2]*right[2,3] + left[2,3]*right[3,3];

						RESULT[3,0] := left[3,0]*right[0,0] + left[3,1]*right[1,0] + left[3,2]*right[2,0] + left[3,3]*right[3,0];
						RESULT[3,1] := left[3,0]*right[0,1] + left[3,1]*right[1,1] + left[3,2]*right[2,1] + left[3,3]*right[3,1];
						RESULT[3,2] := left[3,0]*right[0,2] + left[3,1]*right[1,2] + left[3,2]*right[2,2] + left[3,3]*right[3,2];
						RESULT[3,3] := left[3,0]*right[0,3] + left[3,1]*right[1,3] + left[3,2]*right[2,3] + left[3,3]*right[3,3];
					END;
			ELSE
				ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGREAL ),
									    loopMatMulAXAX, matMulX );
			END;
		ELSE
			ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGREAL ),
									    loopMatMulAXAX, matMulX );
		END;
		RETURN RESULT
	END "*";

	(*
		Optimized for small arrays (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	OPERATOR "*"*(CONST left: ARRAY [ * , * ] OF LONGREAL;
												CONST right: ARRAY [ * ] OF LONGREAL  ): ARRAY [ * ] OF LONGREAL;
	VAR
		flags: SET; dadr, ladr, radr: LONGINT;
		v0, v1, v2: LONGREAL;
	BEGIN

		dadr := GetAdr(ADDRESSOF(RESULT));
		ladr := GetAdr(ADDRESSOF(left));
		radr := GetAdr(ADDRESSOF(right));


		flags := SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(left)+MathFlagsOffset)) * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(right)+MathFlagsOffset));

		CASE SYSTEM.VAL(LONGINT,flags) OF

			MatVec2x2:
				IF SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset) # Vec2 THEN
					IF dadr = 0 THEN NEW(RESULT,2);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulLR2x2 # NIL THEN matVecMulLR2x2(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0];
					RESULT[0] := left[0,0]*v0 + left[0,1]*right[1];
					RESULT[1] := left[1,0]*v0 + left[1,1]*right[1];
				END;

			|MatVec3x3:
				IF SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset) # Vec3 THEN
					IF dadr = 0 THEN NEW(RESULT,3);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulLR3x3 # NIL THEN matVecMulLR3x3(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1];
					RESULT[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*right[2];
					RESULT[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*right[2];
					RESULT[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*right[2];
				END;

			|MatVec4x4:
				IF SYSTEM.GET32(ADDRESSOF(RESULT)+MathFlagsOffset) # Vec4 THEN
					IF dadr = 0 THEN NEW(RESULT,4);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulLR4x4 # NIL THEN matVecMulLR4x4(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1]; v2 := right[2];
					RESULT[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*v2 + left[0,3]*right[3];
					RESULT[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*v2 + left[1,3]*right[3];
					RESULT[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*v2 + left[2,3]*right[3];
					RESULT[3] := left[3,0]*v0 + left[3,1]*v1 + left[3,2]*v2 + left[3,3]*right[3];
				END;

		ELSE
			ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulAXAX, matMulX );
		END;
		RETURN RESULT
	END "*";

	OPERATOR "*"*( CONST left: ARRAY [ * ] OF LONGREAL;
														 CONST right: ARRAY [ * , * ] OF LONGREAL  ): ARRAY [ * ] OF LONGREAL;
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulAXAX, matMulX );
		RETURN RESULT
	END "*";


(** SHORTINT *)
	PROCEDURE MatMulIncASASLoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: SHORTINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			(* KernelLog.String("mul with: "); KernelLog.Int(lval,10); KernelLog.Int(rval,10); KernelLog.Ln; *)
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncASASLoop;

	OPERATOR "@MulInc"*(CONST left, right: ARRAY [ * , * ] OF SHORTINT ): ARRAY [ * , * ] OF SHORTINT;
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*(CONST left: ARRAY [ * , * ] OF SHORTINT;
															  CONST right: ARRAY [ * ] OF SHORTINT  ): ARRAY [ * ] OF SHORTINT;
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*( CONST left: ARRAY [ * ] OF SHORTINT;
															  CONST right: ARRAY [ * , * ] OF SHORTINT  ): ARRAY [ * ] OF SHORTINT;
		BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulDec"*(CONST left, right: ARRAY [ * , * ] OF SHORTINT  ): ARRAY [ * , * ] OF SHORTINT;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*(CONST left: ARRAY [ * , * ] OF SHORTINT;
															  CONST right: ARRAY [ * ] OF SHORTINT  ): ARRAY [ * ] OF SHORTINT;
	BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*( CONST left: ARRAY [ * ] OF SHORTINT;
															  CONST right: ARRAY [ * , * ] OF SHORTINT ): ARRAY [ * ] OF SHORTINT;
	BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

(** INTEGER *)
	PROCEDURE MatMulIncAIAILoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: INTEGER;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncAIAILoop;

	OPERATOR "@MulInc"*(CONST left, right: ARRAY [ * , * ] OF INTEGER ): ARRAY [ * , * ] OF INTEGER;
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*(CONST left: ARRAY [ * , * ] OF INTEGER; CONST right: ARRAY [ * ] OF INTEGER): ARRAY [ * ] OF INTEGER;
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*( CONST left: ARRAY [ * ] OF INTEGER; CONST right: ARRAY [ * , * ] OF INTEGER ): ARRAY [ * ] OF INTEGER;
		BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulDec"*(CONST left, right: ARRAY [ * , * ] OF INTEGER ): ARRAY [ * , * ] OF INTEGER;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*( CONST left: ARRAY [ * , * ] OF INTEGER; CONST right: ARRAY [ * ] OF INTEGER ): ARRAY [ * ] OF INTEGER;
		BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*( CONST left: ARRAY [ * ] OF INTEGER; CONST right: ARRAY [ * , * ] OF INTEGER  ): ARRAY [ * ] OF INTEGER;
		BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

(** LONGINT *)
	PROCEDURE MatMulIncALALLoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: LONGINT;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncALALLoop;

	OPERATOR "@MulInc"*(CONST left, right: ARRAY [ * , * ] OF LONGINT ): ARRAY [ * , * ] OF LONGINT;
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*(CONST left: ARRAY [ * , * ] OF LONGINT; CONST right: ARRAY [ * ] OF LONGINT ): ARRAY [ * ] OF LONGINT;
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*( CONST left: ARRAY [ * ] OF LONGINT; CONST right: ARRAY [ * , * ] OF LONGINT ): ARRAY [ * ] OF LONGINT;
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulDec"*( CONST left, right: ARRAY [ * , * ] OF LONGINT  ): ARRAY [ * , * ] OF LONGINT;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*(CONST left: ARRAY [ * , * ] OF LONGINT; CONST right: ARRAY [ * ] OF LONGINT ): ARRAY [ * ] OF LONGINT;
	BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*(CONST left: ARRAY [ * ] OF LONGINT; CONST right: ARRAY [ * , * ] OF LONGINT  ): ARRAY [ * ] OF LONGINT;
	BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	(** REAL *)
	PROCEDURE MatMulIncARARLoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: REAL;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncARARLoop;

	OPERATOR "@MulInc"*(CONST left, right: ARRAY [ * , * ] OF REAL ): ARRAY [ * , * ] OF REAL;
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
									    loopMatMulIncARAR, matMulIncR );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*(CONST left: ARRAY [ * , * ] OF REAL;CONST right: ARRAY [ * ] OF REAL ): ARRAY [ * ] OF REAL;
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulIncARAR, matMulIncR );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*( CONST left: ARRAY [ * ] OF REAL; CONST right: ARRAY [ * , * ] OF REAL ): ARRAY [ * ] OF REAL;
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulIncARAR, matMulIncR );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulDec"*(CONST left, right: ARRAY [ * , * ] OF REAL ): ARRAY [ * , * ] OF REAL;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
									    loopMatMulIncARAR, matMulIncR );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*( CONST left: ARRAY [ * , * ] OF REAL; CONST right: ARRAY [ * ] OF REAL ): ARRAY [ * ] OF REAL;
	BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulIncARAR, matMulIncR );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*(CONST left: ARRAY [ * ] OF REAL; CONST right: ARRAY [ * , * ] OF REAL ): ARRAY [ * ] OF REAL;
	BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulIncARAR, matMulIncR );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";
(** LONGREAL *)

	PROCEDURE MatMulIncAXAXLoop( ladr, radr, dadr, linc, rinc, len: Address );
	VAR lval, rval, dval: LONGREAL;
	BEGIN
		SYSTEM.GET( dadr, dval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  dval := dval + lval * rval;
			INC( ladr, linc );  INC( radr, rinc );  DEC( len );
		END;
		SYSTEM.PUT( dadr, dval );
	END MatMulIncAXAXLoop;

	OPERATOR "@MulInc"*(CONST left, right: ARRAY [ * , * ] OF LONGREAL  ): ARRAY [ * , * ] OF LONGREAL;
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*(CONST left: ARRAY [ * , * ] OF LONGREAL; CONST right: ARRAY [ * ] OF LONGREAL  ): ARRAY [ * ] OF LONGREAL;
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
		RETURN RESULT
	END "@MulInc";

	OPERATOR "@MulInc"*( CONST left: ARRAY [ * ] OF LONGREAL; CONST right: ARRAY [ * , * ] OF LONGREAL ): ARRAY [ * ] OF LONGREAL;
		BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
		RETURN RESULT
	END "@MulInc";


	OPERATOR "@MulDec"*(CONST left, right: ARRAY [ * , * ] OF LONGREAL ): ARRAY [ * , * ] OF LONGREAL;
	BEGIN
		RESULT := -RESULT;
		ApplyMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*( CONST left: ARRAY [ * , * ] OF LONGREAL; CONST right: ARRAY [ * ] OF LONGREAL ): ARRAY [ * ] OF LONGREAL;
	BEGIN
		RESULT := -RESULT;
		ApplyMatVecMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

	OPERATOR "@MulDec"*( CONST left: ARRAY [ * ] OF LONGREAL; CONST right: ARRAY [ * , * ] OF LONGREAL ): ARRAY [ * ] OF LONGREAL;
	BEGIN
		RESULT := -RESULT;
		ApplyVecMatMulLoop( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
		RESULT := -RESULT;
		RETURN RESULT
	END "@MulDec";

(*** Cross product ********************************************************************)

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF SHORTINT  ): ARRAY [ * ] OF SHORTINT;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: SHORTINT;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF INTEGER ): ARRAY [ * ] OF INTEGER;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: INTEGER;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF LONGINT ): ARRAY [ * ] OF LONGINT;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: LONGINT;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF REAL ): ARRAY [ * ] OF REAL;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: REAL;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ), 0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

	OPERATOR "*"*(CONST left, right: ARRAY [ * ] OF LONGREAL ): ARRAY [ * ] OF LONGREAL;
	VAR vl1, vl2, vl3, vr1, vr2, vr3: LONGREAL;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( RESULT,0 ) # 3 THEN NEW( RESULT, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  RESULT[0] := vl2 * vr3 - vl3 * vr2;
		RESULT[1] := vl3 * vr1 - vl1 * vr3;  RESULT[2] := vl1 * vr2 - vl2 * vr1;
		RETURN RESULT
	END "*";

(** Transpose  ********************************************************************)



	PROCEDURE Overlap( src1, src2: Address ): BOOLEAN;
	VAR from1, from2, to1, to2: Address;  dim: LONGINT;
	BEGIN
		from1 := GetAdr( src1 );  from2 := GetAdr( src2 );  to1 := from1;  to2 := from2;
		dim := GetDim( src1 ) - 1;
		WHILE (dim > 0) DO
			to1 := to1 + (GetLen( src1, dim ) - 1) * GetIncr( src1, dim );  DEC( dim );
		END;
		dim := GetDim( src2 ) - 1;
		WHILE (dim > 0) DO
			to2 := to2 + (GetLen( src2, dim ) - 1) * GetIncr( src2, dim );  DEC( dim );
		END;
		IF from1 < from2 THEN RETURN to1 >= from2;
		ELSIF from2 < from1 THEN RETURN to2 >= from1;
		ELSE RETURN TRUE;
		END;
	END Overlap;


(*
	PROCEDURE Overlap( src1, src2, dim: Address ): BOOLEAN;
	VAR from1, from2, to1, to2: Address;
	BEGIN
		from1 := GetAdr( src1 );  from2 := GetAdr( src2 );  to1 := from1;  to2 := from2;
		DEC( dim );
		WHILE (dim > 0) DO
			to1 := to1 + (GetLen( src1, dim ) - 1) * GetIncr( src1, dim );
			to2 := to2 + (GetLen( src2, dim ) - 1) * GetIncr( src2, dim );  DEC( dim );
		END;
		IF from1 < from2 THEN RETURN to1 >= from2;
		ELSIF from2 < from1 THEN RETURN to2 >= from1;
		ELSE RETURN TRUE;
		END;
	END Overlap;
	*)

	PROCEDURE AllocateTransposed( VAR dest: LONGINT;  src: LONGINT;
												   elementsize: LONGINT ): ANY;
	VAR ptr, data: ANY;  Size: LONGINT;
		(* allocate a structure in dest compatible with src, if necessary. returns if allocation has taken place *)

		PROCEDURE TransposedShape( l, r: LONGINT ): BOOLEAN;
		VAR dim,max: LONGINT;
		BEGIN
			dim := GetDim( l );
			IF dim # GetDim( r ) THEN RETURN FALSE END;
			max := dim-1;
			WHILE (dim > 0) DO
				DEC( dim );
				IF GetLen( l, max-dim ) # GetLen( r, dim ) THEN RETURN FALSE END;
			END;
			RETURN TRUE;
		END TransposedShape;

		PROCEDURE UseDescriptor;
		VAR tag: LONGINT;
		BEGIN
			SYSTEM.GET( src - 4, tag );
			Heaps.NewRec( ptr, tag, FALSE );
			dest := SYSTEM.VAL( LONGINT, ptr );
		END UseDescriptor;

		PROCEDURE NewData;
		VAR max,dim, len, size: LONGINT;
		BEGIN
			dim := GetDim( src );  size := elementsize;
			PutDim( dest, dim );
			PutSize( dest, elementsize );
			max := dim-1;
			WHILE (dim > 0) DO
				DEC( dim );
				len := GetLen( src, max-dim );  PutLen( dest, dim, len );
				PutInc( dest, dim, size );  size := size * len;
			END;
			SYSTEM.NEW( data, size );
			PutAdr( dest, SYSTEM.VAL( LONGINT, data ) );
			PutPtr( dest, SYSTEM.VAL( LONGINT, data ) );
		END NewData;

	BEGIN
		IF dest # 0 THEN Size := GetSize( dest );  ASSERT( Size = elementsize );  END;
		IF debug THEN KernelLog.String( "Allocate same " );  Report( "allocation source", src );  Report( "allocation des", dest );  END;
		IF dest = 0 THEN  (* NIL pointer, guaranteed to be tensor *)
			IF TensorFlag IN GetFlags( src ) THEN UseDescriptor();
			ELSE ptr := GetArrayDesc( GetDim( src ) );  dest := SYSTEM.VAL( LONGINT, ptr );
			END;
			PutFlags(dest, {TensorFlag});
			NewData();  RETURN ptr;
		ELSIF GetDim( dest ) # GetDim( src ) THEN  (* different dimension *)
			(* check if re-allocation of descriptor is allowed *)
			IF ~(TensorFlag IN GetFlags( dest )) &
				~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				HALT( 100 );
			END;
			UseDescriptor();
			PutFlags(dest, {TensorFlag});
			NewData();  RETURN ptr;
		ELSIF (GetAdr( dest ) = 0) OR ~TransposedShape( dest, src ) THEN
			(* check if re-allocation of array data is allowed *)
			IF RangeFlag IN GetFlags( dest ) THEN  (* no! not allowed *)
				HALT( 100 );
			END;
			NewData();

			RETURN data;
		ELSE  (* nothing to do *)
			RETURN NIL;
		END;
	END AllocateTransposed;


	PROCEDURE Transpose*( dest, left: Address;  Size: LONGINT );
	VAR len0, len1, linc0, linc1, dinc0, dinc1, ladr, dadr: LONGINT;  p: ANY;

		PROCEDURE CopyLoop( src, dest, srcinc, destinc, len: LONGINT );
		BEGIN
			WHILE (len > 0) DO
				SYSTEM.MOVE( src, dest, Size );  INC( src, srcinc );  INC( dest, destinc );
				DEC( len );
			END;
		END CopyLoop;

	BEGIN
		IF TemporaryFlag IN GetFlags( dest ) THEN  (* destination is on the stack: can optimize transposition *)
			PutAdr( dest, GetAdr( left ) );  PutPtr( dest, GetPtr( left ) );
			PutLen( dest, 1, GetLen( left, 0 ) );  PutLen( dest, 0, GetLen( left, 1 ) );
			PutInc( dest, 1, GetIncr( left, 0 ) );  PutInc( dest, 0, GetIncr( left, 1 ) );
		ELSE
			len0 := GetLen( left, 0 );  len1 := GetLen( left, 1 );
			p := AllocateTransposed(dest,left,Size);
			IF Overlap( left, dest ) THEN  (* copy data first, then transpose *)
				SYSTEM.NEW( p, len0 * len1 * Size );  dinc0 := Size;  dinc1 := len0 * Size;
				dadr := SYSTEM.VAL( LONGINT, p );  linc0 := GetIncr( left, 0 );
				linc1 := GetIncr( left, 1 );  ladr := GetAdr( left );
				WHILE (len0 > 0) DO
					CopyLoop( ladr, dadr, linc1, dinc1, len1 );  INC( ladr, linc0 );
					INC( dadr, dinc0 );  DEC( len0 );
				END;
				len0 := GetLen( left, 0 );  linc0 := Size;  linc1 := len0 * Size;
				ladr := SYSTEM.VAL( LONGINT, p );
			ELSE
				linc0 := GetIncr( left, 0 );  linc1 := GetIncr( left, 1 );  ladr := GetAdr( left );
			END;
			dinc0 := GetIncr( dest, 0 );  dinc1 := GetIncr( dest, 1 );
			dadr := GetAdr( dest );
			IF (Size = 4) & (transpose4 # NIL ) THEN
				transpose4( ladr, dadr, linc0, linc1, dinc0, dinc1, len0, len1 );
			ELSIF (Size = 8) & (transpose8 # NIL ) THEN
				transpose8( ladr, dadr, linc0, linc1, dinc0, dinc1, len0, len1 );
			ELSE
				WHILE (len0 > 0) DO
					CopyLoop( ladr, dadr, linc1, dinc0, len1 );  INC( ladr, linc0 );
					INC( dadr, dinc1 );  DEC( len0 );
				END;
			END;
		END;
	END Transpose;

	OPERATOR "`"*(CONST left: ARRAY [ * , * ] OF SHORTINT): ARRAY [ * , * ] OF SHORTINT;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( SHORTINT ) );
		RETURN RESULT
	END "`";

	OPERATOR "`"*( CONST left: ARRAY [ * , * ] OF INTEGER ):ARRAY [ * , * ] OF INTEGER ;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( INTEGER ) );
		RETURN RESULT
	END "`";

	OPERATOR "`"*( CONST left: ARRAY [ * , * ] OF LONGINT ): ARRAY [ * , * ] OF LONGINT;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( LONGINT ) );
		RETURN RESULT
	END "`";

	OPERATOR "`"*( CONST left: ARRAY [ * , * ] OF REAL ): ARRAY [ * , * ] OF REAL;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( REAL ) );
		RETURN RESULT
	END "`";

	OPERATOR "`"*( CONST left: ARRAY [ * , * ] OF LONGREAL ): ARRAY [ * , * ] OF LONGREAL;
	BEGIN
		Transpose( ADDRESSOF( RESULT ), ADDRESSOF( left ), SIZEOF( LONGREAL ) );
		RETURN RESULT
	END "`";

	PROCEDURE CheckTensorGeometry( left, right, dest: Address; ldim, rdim: LONGINT ): BOOLEAN;
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO rdim - 1 DO
			IF GetLen( right, i ) # GetLen( dest, i ) THEN RETURN FALSE END;
		END;
		FOR i := 0 TO ldim - 1 DO
			IF GetLen( left, i ) # GetLen( dest, rdim + i ) THEN RETURN FALSE END;
		END;
		RETURN TRUE;
	END CheckTensorGeometry;

(*
	PROCEDURE Zero(p: ANY; size: LONGINT);
	VAR adr: LONGINT;
	BEGIN
		adr := SYSTEM.VAL(LONGINT,p);
		WHILE(size>0) DO
			SYSTEM.PUT8(adr,0); DEC(size);INC(adr);
		END;
	END Zero;
*)


	PROCEDURE DoReshape*( VAR dest: LONGINT;  src: LONGINT; CONST shape: ARRAY [ * ] OF LONGINT );
	VAR i, Size: LONGINT;  ptr, data: ANY;  new: LONGINT;

		oldSize, newSize: LONGINT;  oldDim, newDim: LONGINT;

		squeezingReshape: BOOLEAN;

		PROCEDURE NewDescriptor;
		BEGIN
			ptr := GetArrayDesc( newDim );  new := SYSTEM.VAL( LONGINT, ptr );
		END NewDescriptor;

		(* 	Added by Alexey
			Returns TRUE if the new shape is the result of squeezing (removing of singleton dimensions)
		*)
		PROCEDURE SqueezingReshape(): BOOLEAN;
		VAR
			i, j, n: LONGINT;
		BEGIN
			IF oldDim > newDim THEN
				i := 0; j := 0;
				WHILE (i < oldDim) & (j < newDim) DO
					n := GetLen(src,i);
					IF n = shape[j] THEN INC(j); END;
					INC(i);
				END;
				WHILE (i < oldDim) & (GetLen(src,i) = 1) DO INC(i); END; (* account for a trailing sequence of 1 *)
			ELSE
				squeezingReshape := FALSE;
			END;

			squeezingReshape := (i = oldDim) & (j = newDim);

			RETURN squeezingReshape;
		END SqueezingReshape;

		(* returns TRUE if reshape preserves contiguity pattern and thus is valid even for subranged arrays *)
		PROCEDURE PreservesContiguity(): BOOLEAN;
		VAR
			i, n: LONGINT;
			continue: BOOLEAN;
		BEGIN
			i := oldDim-1; n := GetIncr(src,i);
			continue := TRUE;
			WHILE (i > 0) & continue DO
				n := n * GetLen(src,i);
				DEC(i);
				continue := GetIncr(src,i) = n;
			END;

			IF (i = 0) & continue THEN (* array can be fully linearized and, therefore, can be reshaped to any size *)
				RETURN TRUE;
			ELSE Err("Not yet implemented!");
			END;
		END PreservesContiguity;


		(* Added by Alexey *)
		PROCEDURE NewDescriptorForSameData;
		VAR len, size, i, j: LONGINT;
		BEGIN
			ptr := GetArrayDesc( newDim );  new := SYSTEM.VAL( LONGINT, ptr );

			IF ~squeezingReshape THEN
				size := Size;
				FOR i := newDim - 1 TO 0 BY -1 DO
					len := shape[i];  PutInc( new, i, size );  PutLen( new, i, len );
					size := size * len;
				END;
			ELSE (* squeezing reshape *)
				j := 0; len := shape[j];
				FOR i := 0 TO oldDim-1 DO
					IF GetLen(src,i) = len THEN
						PutInc(new,j,GetIncr(src,i)); PutLen(new,j,len);
						INC(j);
						IF j < newDim THEN len := shape[j]; END;
					END;
				END;
			END;

			IF RangeFlag IN GetFlags(src) THEN (* keep range awareness for case of squeezing reshape and preservation of contiguity *)
				PutFlags(new,GetFlags(new)+{RangeFlag});
			END;

			PutAdr( new, GetAdr(src) );
			PutPtr( new, GetPtr(src) );  PutDim( new, newDim );
			PutSize( new, Size );
		END NewDescriptorForSameData;

		PROCEDURE NewData;
		VAR len, size, i: LONGINT;
		BEGIN
			size := Size;
			FOR i := newDim - 1 TO 0 BY -1 DO
				len := shape[i];  PutInc( new, i, size );  PutLen( new, i, len );
				size := size * len;
			END;
			SYSTEM.NEW( data, size );   (* Zero(data,size*Size); *)
			PutAdr( new, SYSTEM.VAL( LONGINT, data ) );
			PutPtr( new, SYSTEM.VAL( LONGINT, data ) );  PutDim( new, newDim );
			PutSize( new, Size );
		END NewData;

		PROCEDURE CopyData;
		VAR d, s, dadr: LONGINT;

			PROCEDURE Loop( dim: LONGINT;  sadr: LONGINT );
			VAR inc, len, i: LONGINT;
			BEGIN
				IF dim = d THEN
					inc := GetIncr( src, dim );  len := GetLen( src, dim );
					FOR i := 0 TO len - 1 DO
						SYSTEM.MOVE( sadr, dadr, s );  INC( dadr, s );  INC( sadr, inc );
					END;
				ELSE
					inc := GetIncr( src, dim );  len := GetLen( src, dim );  INC( dim );
					FOR i := 0 TO len - 1 DO Loop( dim, sadr );  INC( sadr, inc );  END;
				END;
			END Loop;

		BEGIN
			s := Size;  ASSERT( GetSize( src ) = s );  d := GetDim( src ) - 1;
			WHILE (d >= 0) & (GetIncr( src, d ) = s) DO
				s := s * GetLen( src, d );  DEC( d );
			END;
			IF d = -1 THEN  (* special case: both continuous *)
				SYSTEM.MOVE( GetAdr( src ), GetAdr( new ), s );
			ELSE dadr := GetAdr( new );  Loop( 0, GetAdr( src ) );
			END;
		END CopyData;

		PROCEDURE CopyDataBack;
		VAR d, s: LONGINT;  sadr: LONGINT;

			PROCEDURE Loop( dim: LONGINT;  dadr: LONGINT );
			VAR inc, len, i: LONGINT;
			BEGIN
				IF dim = d THEN
					inc := GetIncr( dest, dim );  len := GetLen( dest, dim );
					FOR i := 0 TO len - 1 DO
						SYSTEM.MOVE( sadr, dadr, s );  INC( dadr, inc );  INC( sadr, s );
					END;
				ELSE
					inc := GetIncr( dest, dim );  len := GetLen( dest, dim );  INC( dim );
					FOR i := 0 TO len - 1 DO Loop( dim, dadr );  INC( dadr, inc );  END;
				END;
			END Loop;

		BEGIN
			s := Size;  ASSERT( GetSize( dest ) = s );  d := GetDim( dest ) - 1;
			WHILE (d >= 0) & (GetIncr( dest, d ) = s) DO
				s := s * GetLen( dest, d );  DEC( d );
			END;
			IF d = -1 THEN  (* special case: both continuous *)
				SYSTEM.MOVE( GetAdr( new ), GetAdr( dest ), s );
			ELSE sadr := GetAdr( new );  Loop( 0, GetAdr( dest ) );
			END;
		END CopyDataBack;

		PROCEDURE CopyDescriptor( src, dest: LONGINT );
		BEGIN
			ASSERT( GetDim( src ) = GetDim( dest ) );
			SYSTEM.MOVE( src, dest, MathLenOffset + GetDim( src ) * 8 );
		END CopyDescriptor;

		PROCEDURE ShapeDiffers( ): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			ASSERT(GetDim(dest) = newDim);
			FOR i := 0 TO newDim - 1 DO
				IF GetLen(dest,i) # shape[i] THEN RETURN TRUE END;
			END;
			RETURN FALSE;
		END ShapeDiffers;

	BEGIN
	(*
			cases
			1.) descriptor may be replaced = dimension may vary: dest = TENSOR
			2.) descriptor may be reshaped: dest = ARRAY but no RANGE
			3.) descriptor may not be reshaped: dest = RANGE
		*)
		(* first check invariants *)
		oldDim := GetDim( src );
		IF oldDim = 0 THEN oldSize := 0
		ELSE
			oldSize := 1;
			FOR i := 0 TO oldDim - 1 DO oldSize := oldSize * GetLen( src, i );  END;
		END;
		newDim := LEN( shape, 0 );
		IF newDim = 0 THEN newSize := 0
		ELSE
			newSize := 1;
			FOR i := 0 TO newDim - 1 DO newSize := newSize * shape[i];  END;
		END;
		IF oldSize # newSize THEN Err( "RESHAPE: Total length mismatch" );  END;

		Size := GetSize( src );
		ASSERT( (Size > 0) & (Size < 128) );   (*! heuristic, remove upper bound *)

		IF dest = src THEN (* added by Alexey *)
			IF ~(RangeFlag IN GetFlags(dest)) OR PreservesContiguity() OR SqueezingReshape() THEN
				NewDescriptorForSameData;
				dest := new;
			ELSIF ((newDim = oldDim) & ~ShapeDiffers()) THEN
				(* create a copy of the original descriptor *)
				ptr := GetArrayDesc(newDim);  dest := SYSTEM.VAL(LONGINT,ptr); CopyDescriptor(src,dest);
			ELSE
				Err( "RESHAPE: given RANGE array can not be reshaped!" );
			END;
		ELSIF (dest = 0) THEN  (* is tensor for sure *)
			NewDescriptor;  NewData;  CopyData;  dest := new;
		ELSIF (newDim # GetDim( dest )) THEN  (* must be tensor *)
			IF ~(TensorFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				Err( "RESHAPE: new dimension only allowed for TENSOR" );
			END;
			NewDescriptor;  NewData;  CopyData;  dest := new;
		ELSIF ShapeDiffers() THEN  (* same dim but shape of destination does not match *)
			IF RangeFlag IN GetFlags( dest ) THEN Err( "RESHAPE: new shape not allowed for RANGE" );  END;
			NewDescriptor;  NewData;  CopyData;  CopyDescriptor( new, dest );
		ELSIF ~SameShape( src, dest ) THEN  (* shape for destination matches but that of src is different *)
			NewDescriptor;  NewData;  CopyData;  CopyDataBack;
		ELSE  (* same shape, just copy *)
			CopyContent( src, dest, Size );  RETURN;
		END;
	END DoReshape;

	PROCEDURE AllocateTensorX*( VAR destA: ARRAY [?]; CONST a: ARRAY [ * ] OF LONGINT;  Size: LONGINT; tag: LONGINT );
	VAR descr, data: ANY;  same: BOOLEAN;  i: LONGINT;  dim: LONGINT; dest: Address;

		PROCEDURE NewData;
		VAR len, size, i: LONGINT;
		BEGIN
			size := Size;
			FOR i := dim - 1 TO 0 BY -1 DO
				len := a[i];
				(*
				KernelLog.Int(len,10); KernelLog.Ln;
				*)
				PutInc( dest, i, size );  PutLen( dest, i, len );  size := size * len;
			END;
			IF tag = 0 THEN
				SYSTEM.NEW( data, size );   (* Zero(data,size*Size); *)
				PutAdr( dest, SYSTEM.VAL( LONGINT, data ) );
			ELSE
				Heaps.NewArr(data, tag, size DIV Size,1,FALSE);
				PutAdr( dest, SYSTEM.VAL( LONGINT, data ) + ArrDataArrayOffset );
			END;
			PutPtr( dest, SYSTEM.VAL( LONGINT, data ) );  PutSize( dest, Size );
		END NewData;

		PROCEDURE ClearData;
			(*! todo *)
		END ClearData;

	BEGIN
		dim := LEN( a,0 );
		dest := SYSTEM.VAL(Address,destA);

		(*! check range flag! *)

		IF (dest = 0) OR (dim # GetDim( dest )) THEN
			IF dest # 0 THEN
				IF (~(TensorFlag IN GetFlags( dest ))) THEN Err( "Array's number of dimension must not be modified (no TENSOR !)" );  END;
			END;
			descr := GetArrayDesc( LEN( a,0 ) );  dest := SYSTEM.VAL( LONGINT, descr );
			NewData;
		ELSE
			i := 0;
			WHILE (i < dim) & same DO
				IF GetLen( dest, i ) # a[i] THEN same := FALSE;  END;
				INC( i );
			END;
			IF ~same THEN
				IF (RangeFlag IN GetFlags( dest )) THEN Err( "Array's shape must not be modified (is RANGE !) " );  END;
				NewData
			ELSE ClearData
			END;
		END;
		SYSTEM.PUT(ADDRESSOF(destA),dest);
	END AllocateTensorX;

	PROCEDURE LenA*( VAR dest: ARRAY [ * ] OF LONGINT;  src: Address );
	VAR dim, i: LONGINT;
	BEGIN
		dim := GetDim( src );
		IF LEN( dest, 0 ) # dim THEN NEW( dest, dim );  END;
		FOR i := 0 TO dim - 1 DO dest[i] := GetLen( src, i );  END;
	END LenA;



	PROCEDURE IncrA*( VAR dest: ARRAY [ * ] OF LONGINT;  src: Address );
	VAR dim, i, len: LONGINT;
	BEGIN
		dim := GetDim( src );  len := LEN( dest, 0 );
		IF len # dim THEN NEW( dest, dim );  END;
		FOR i := 0 TO dim - 1 DO dest[i] := GetIncr( src, i );  END;
	END IncrA;

	PROCEDURE Len*(src: Address; d: LONGINT): LONGINT;
	VAR dim: LONGINT;
	BEGIN
		dim := GetDim(src);
		IF (d<0) OR (d>=dim) THEN HALT(100)
		ELSE
			RETURN GetLen(src,d);
		END;
	END Len;

	PROCEDURE Incr*(src: Address; d: LONGINT): LONGINT;
	VAR dim: LONGINT;
	BEGIN
		dim := GetDim(src);
		IF (d<0) OR (d>=dim) THEN HALT(100)
		ELSE
			RETURN GetIncr(src,d);
		END;
	END Incr;


	PROCEDURE AllocateTensor( VAR dest: LONGINT;  left, right: Address;
												    Size: LONGINT ): ANY;
	VAR ldim, rdim: LONGINT;  ptr, data: ANY;

		PROCEDURE NewData;
		VAR len, size, i: LONGINT;
		BEGIN
			size := 1;
			FOR i := 0 TO ldim - 1 DO
				len := GetLen( left, i );  size := size * len;  PutLen( dest, i, len );
			END;
			FOR i := 0 TO rdim - 1 DO
				len := GetLen( right, i );  size := size * len;  PutLen( dest, ldim + i, len );
			END;
			SYSTEM.NEW( data, size * Size );   (* Zero(data,size*Size); *)
			(*
			KernelLog.String("adr data="); KernelLog.Int(SYSTEM.VAL(LONGINT,data),10); KernelLog.Ln;
			KernelLog.String("adr dest="); KernelLog.Int(dest,10); KernelLog.Ln;
			*)
			size := Size;
			FOR i := ldim + rdim - 1 TO 0 BY -1 DO
				PutInc( dest, i, size );  size := size * GetLen( dest, i );
			END;
			PutAdr( dest, SYSTEM.VAL( LONGINT, data ) );
			PutPtr( dest, SYSTEM.VAL( LONGINT, data ) );
		END NewData;

	BEGIN
		ldim := GetDim( left );  rdim := GetDim( right );
		IF dest = 0 THEN  (* NIL pointer, guaranteed to be tensor *)
			ptr := GetArrayDesc( ldim + rdim );  dest := SYSTEM.VAL( LONGINT, ptr );
			NewData();  RETURN ptr;
		ELSIF (ldim + rdim # GetDim( dest )) THEN
			IF ~(TensorFlag IN GetFlags( dest )) &
				~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				HALT( 100 );
			END;
			ptr := GetArrayDesc( ldim + rdim );  dest := SYSTEM.VAL( LONGINT, ptr );
			NewData();  RETURN ptr;
		ELSIF ~CheckTensorGeometry( left, right, dest, ldim, rdim ) THEN  (* dimension matches but not geometry *)
			IF RangeFlag IN GetFlags( dest ) THEN  (* no! not allowed *)
				HALT( 100 );
			END;
			NewData();  RETURN data;
		END;
		RETURN NIL;
	END AllocateTensor;

(* find the largest block with a regular pattern of the form offset+{i*linc: 0<=i<len} for two arrays simultaneously. d is dimension applying to the resulting loop *)
	PROCEDURE FindPatternTensor( left, right: Address;
														 VAR rdim, len, linc, ri: LONGINT );
	(* geometric precondition: lengths must coincide *)
	VAR ldim: LONGINT;
	BEGIN
		ldim := GetDim( left ) - 1;  rdim := GetDim( right ) - 1;
		len := GetLen( left, ldim );  ASSERT( len = GetLen( right, rdim ) );
		WHILE (len = 1) & (ldim > 0) & (rdim > 0) DO
			DEC( ldim );  DEC( rdim );  len := GetLen( left, ldim );
			ASSERT( GetLen( left, ldim ) = GetLen( right, rdim ) );
		END;
		linc := GetIncr( left, ldim );  ri := GetIncr( right, rdim );  DEC( rdim );
		DEC( ldim );
		WHILE (ldim >= 0) & (rdim >= 0) & (GetIncr( left, ldim ) = len * linc) &
				    (GetIncr( right, rdim ) = len * ri) DO
			len := len * GetLen( left, ldim );
			ASSERT( GetLen( left, ldim ) = GetLen( right, rdim ) );  DEC( rdim );
			DEC( ldim );
		END;
		INC( ldim );  INC( rdim );
		IF debug THEN
			KernelLog.String( "FindPatternTensor: " );  KernelLog.Int( rdim, 10 );  KernelLog.Int( len, 10 );
			KernelLog.Int( linc, 10 );  KernelLog.Int( ri, 10 );  KernelLog.Ln;
		END;
	END FindPatternTensor;

	PROCEDURE ApplyTensorAAAOp( d, l, r: Address;  elementSize: LONGINT;
														    Loop: BinaryASALoop );
	VAR loopd, looplen, loopri, loopdi, lDim, rDim: LONGINT;  p: ANY;
		origdest: LONGINT;  left, right, dest: Address;

		PROCEDURE Traverse( ladr, radr, dadr: Address;  ldim, rdim: LONGINT );
		VAR len: LONGINT;  linc, rinc, dinc: LONGINT;
		BEGIN
			IF (ldim < lDim) THEN
				len := GetLen( left, ldim );  linc := GetIncr( left, ldim );
				dinc := GetIncr( dest, ldim + rdim );  INC( ldim );
				WHILE (len > 0) DO
					Traverse( ladr, radr, dadr, ldim, rdim );  INC( ladr, linc );
					INC( dadr, dinc );  DEC( len );
				END;
			ELSIF (rdim # loopd) THEN
				len := GetLen( right, rdim );  rinc := GetIncr( right, rdim );
				dinc := GetIncr( dest, ldim + rdim );  INC( rdim );
				WHILE (len > 0) DO
					Traverse( ladr, radr, dadr, ldim, rdim );  INC( radr, rinc );
					INC( dadr, dinc );  DEC( len );
				END;
			ELSE
				(*
				KernelLog.String("MulALSLLoop"); KernelLog.Int(dadr,10); KernelLog.Int(loopdi,10); KernelLog.Int(looplen,10);
				KernelLog.Int(GetAdr(dest),10);
				KernelLog.Int(GetAdr(dest)+clen,10);
				KernelLog.Ln;
				*)
				Loop( radr, ladr, dadr, loopri, loopdi, looplen );

				(* loop over right matrix and destination highest continuous dimension D[x,y,z,..] := L[x,y] ** R[z,..] *)
			END;
		END Traverse;

	BEGIN
		SYSTEM.GET( d, dest );  SYSTEM.GET( l, left );  SYSTEM.GET( r, right );
		(* check array lengths *)
		origdest := 0;  lDim := GetDim( left );  rDim := GetDim( right );
		p := AllocateTensor( dest, left, right, elementSize );
		(*
		IF (dest = 0) OR (GetPtr( dest ) = 0) THEN
			p := AllocateTensor( left, right, dest, elementSize )
		ELSIF ~CheckTensorGeometry( left, right, dest, lDim, rDim ) THEN
			IF GetPtr( dest ) = -1 THEN HALT( GeometryMismatch )
			ELSE p := AllocateTensor( left, right, dest, elementSize );
			END;
			(*! to be done: treat overlapping memory *)
		END;
		*)

		(* debugging *)
		IF debug THEN Report( "AAA:left", left );  Report( "AAA:right", right );  Report( "AAA:dest", dest );  END;
		(* check pattern: longest piece that can be done with a loop *)
		FindPatternTensor( dest, right, loopd, looplen, loopri, loopdi );
		(*  run through dimensions  *)

		Traverse( GetAdr( left ), GetAdr( right ), GetAdr( dest ), 0, 0 );

		SYSTEM.PUT( d, dest );
	END ApplyTensorAAAOp;

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF SHORTINT): ARRAY [?] OF SHORTINT;
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), MulASSSLoop );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF INTEGER): ARRAY [?] OF INTEGER;
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), MulAISILoop );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF LONGINT): ARRAY [?] OF LONGINT;
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), MulALSLLoop );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF REAL): ARRAY [?] OF REAL;
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopMulARSR );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF LONGREAL): ARRAY [?] OF LONGREAL;
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopMulAXSX );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF COMPLEX): ARRAY [?] OF COMPLEX;
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( COMPLEX ),
										  loopMulAZSZ );
		RETURN RESULT
	END "**";

	OPERATOR "**"*(CONST left,right: ARRAY [?] OF LONGCOMPLEX): ARRAY [?] OF LONGCOMPLEX;
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( RESULT ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGCOMPLEX ),
										  loopMulALZSLZ );
		RETURN RESULT
	END "**";

	PROCEDURE InitOptimization;
	VAR p: PROCEDURE;
	BEGIN
		GETPROCEDURE("FoxArrayBaseOptimized","Install",p);
		IF p # NIL THEN
			p;
		ELSE
			KernelLog.String( "Warning: ArrayBase runtime library optimizer not installed." ); KernelLog.Ln;
		END;
	END InitOptimization;

	PROCEDURE CopyDescriptor*(VAR destPtr: ANY; src: LONGINT; prefixIndices, prefixRanges, suffixIndices, suffixRanges: LONGINT);
	VAR size: SIZE; srcDim, destDim,i,len,incr: LONGINT; dest: Address;
	BEGIN
		IF src = 0 THEN
			HALT(100);
		ELSE
			srcDim := GetDim(src);
			destDim := srcDim - prefixIndices - suffixIndices;
			(*
			KernelLog.String("srcDim "); KernelLog.Int(srcDim,1); KernelLog.Ln;
			KernelLog.String("prefixIndices "); KernelLog.Int(prefixIndices,1); KernelLog.Ln;
			KernelLog.String("prefixRanges "); KernelLog.Int(prefixRanges,1); KernelLog.Ln;
			KernelLog.String("suffixIndices "); KernelLog.Int(suffixIndices,1); KernelLog.Ln;
			KernelLog.String("suffixRanges "); KernelLog.Int(suffixRanges,1); KernelLog.Ln;
			KernelLog.String("destDim "); KernelLog.Int(destDim,1); KernelLog.Ln;
			*)

			destPtr := GetArrayDesc(destDim);
			dest := SYSTEM.VAL(LONGINT,destPtr);
			(* SYSTEM.MOVE(src,dest,MathLenOffset); *)
			PutAdr(dest,GetAdr(src));
			PutPtr(dest,GetPtr(src));
			PutFlags(dest,GetFlags(src));
			PutSize(dest,GetSize(src));

			FOR i := 0 TO srcDim-suffixIndices-suffixRanges-prefixIndices-prefixRanges-1 DO
				srcDim := i + prefixIndices + prefixRanges;
				destDim := i + prefixRanges;
				len := GetLen(src,srcDim);
				incr := GetIncr(src,srcDim);
				PutLen(dest,destDim,len);
				PutInc(dest,destDim,incr);
			END;
			(*
			Report("copy descriptor src",src);
			Report("copy descriptor dest",dest);
			*)
		END;
	END CopyDescriptor;

	(* when Reshape is called by a compiler, the arguments are - for the compiler - replaced as follows, this makes them compatible
		VAR dest: ARRAY [?] OF basetype
		CONST src: ARRAY [?] OF basetype
		CONST shape: ARRAY [*] OF LONGINT
	*)
	PROCEDURE Reshape*(CONST left: ARRAY [?]; CONST right: ARRAY [*] OF LONGINT): ARRAY [?];
	BEGIN
		DoReshape(SYSTEM.VAL(LONGINT,RESULT), SYSTEM.VAL(LONGINT,left), right);
		RETURN RESULT
	END Reshape;

	(* OLIVIER *)
	(** creates a degenerated range from an integer.
		- makes it possible to convert the result of an integer-valued procedure F() into a range
		without executing the procedure twice as it would happen in "(F() .. F() BY 1)"
	**)
	PROCEDURE RangeFromInteger*(CONST integer: LONGINT): RANGE;
	BEGIN RETURN (integer .. integer BY 1)
	END RangeFromInteger;

	(* OLIVIER *)
	(** create an array with the same data but with more dimensions
		- each element in the array 'keptDimensions' corresponds to a dimension in the resulting array
		- if element = TRUE: use a dimension from the source array, i.e. reuse length and increment
		- if element = FALSE: insert a new dimension having length = 1 and increment = 0

		e.g.:
			ExpandDimensions(array, [FALSE, TRUE, FALSE, FALSE, TRUE])
			performs the following type transformation:
			ARRAY [10, 20] OF REAL -> ARRAY [1, 10, 1, 1, 20] OF REAL

	**)
	PROCEDURE ExpandDimensions*(CONST sourceArray: ARRAY [?]; CONST keptDimensions: ARRAY [*] OF BOOLEAN): ARRAY [?];
	VAR
		targetDimensionality, sourceIndex, targetIndex: LONGINT;
		sourceAddress, targetAddress: LONGINT;
		targetArrayDescriptor: ANY;
	BEGIN
		sourceAddress := SYSTEM.VAL(LONGINT, sourceArray);
		targetDimensionality := LEN(keptDimensions, 0);
		targetArrayDescriptor := GetArrayDesc(targetDimensionality); (* create a new array descriptor *)
		SYSTEM.PUT(ADDRESSOF(RESULT), targetArrayDescriptor);
		targetAddress := SYSTEM.VAL(LONGINT, RESULT);

		PutAdr(targetAddress, GetAdr(sourceAddress));
		PutPtr(targetAddress, GetPtr(sourceAddress));
		PutFlags(targetAddress, {TensorFlag});
		PutSize(targetAddress, GetSize(sourceAddress));

		(* set increments and lengths *)
		sourceIndex := 0;
		FOR targetIndex := 0 TO targetDimensionality - 1 DO
			IF keptDimensions[targetIndex] THEN
				(* reuse length and increment from source array *)
				ASSERT(sourceIndex < DIM(sourceArray));
				PutLen(targetAddress, targetIndex, GetLen(sourceAddress, sourceIndex));
				PutInc(targetAddress, targetIndex, GetIncr(sourceAddress, sourceIndex));
				INC(sourceIndex)
			ELSE
				(* set length = 1 and increment = 0 *)
				PutLen(targetAddress, targetIndex, 1);
				PutInc(targetAddress, targetIndex, 0);
			END
		END;

		(* Report("expand dimensions: ", targetAddress); *)
		RETURN RESULT
	END ExpandDimensions;

	(* index ranges *)

	(* the length of a range, i.e. the number of indices that it stands for *)
	OPERATOR "LEN"*(CONST range: RANGE): LONGINT;
	VAR
		temp, result: LONGINT;
	BEGIN
		IF (LAST(range) < FIRST(range)) OR (FIRST(range) < 0) OR (STEP(range) < 1) THEN
			(* invalid range *)
			result := 0
		ELSIF LAST(range) = MAX(LONGINT) THEN
			(* open-ended range *)
			result := MAX(LONGINT)
		ELSE
			temp := 1 + LAST(range) - FIRST(range);
			result := temp DIV STEP(range);
			IF (temp MOD STEP(range)) # 0 THEN
				INC(result)
			END
		END;
		RETURN result
	END "LEN";

	(* complex numbers *)

	OPERATOR "+"*(CONST left, right: COMPLEX): COMPLEX;
	VAR result: COMPLEX;
	BEGIN
		RE(result) := RE(left) + RE(right);
		IM(result) := IM(left) + IM(right);
		RETURN result
	END "+";

	OPERATOR "+"*(CONST left, right: LONGCOMPLEX): LONGCOMPLEX;
	VAR result: LONGCOMPLEX;
	BEGIN
		RE(result) := RE(left) + RE(right);
		IM(result) := IM(left) + IM(right);
		RETURN result
	END "+";

	OPERATOR "-"*(CONST left, right: COMPLEX): COMPLEX;
	VAR result: COMPLEX;
	BEGIN
		RE(result) := RE(left) - RE(right);
		IM(result) := IM(left) - IM(right);
		RETURN result
	END "-";

	OPERATOR "-"*(CONST left, right: LONGCOMPLEX): LONGCOMPLEX;
	VAR result: LONGCOMPLEX;
	BEGIN
		RE(result) := RE(left) - RE(right);
		IM(result) := IM(left) - IM(right);
		RETURN result
	END "-";

	OPERATOR "*"*(CONST left, right: COMPLEX): COMPLEX;
	VAR result: COMPLEX;
	BEGIN
		RE(result) := RE(left) * RE(right) - IM(left) * IM(right);
		IM(result) := RE(left) * IM(right) + IM(left) * RE(right);
		RETURN result
	END "*";

	OPERATOR "*"*(CONST left, right: LONGCOMPLEX): LONGCOMPLEX;
	VAR result: LONGCOMPLEX;
	BEGIN
		RE(result) := RE(left) * RE(right) - IM(left) * IM(right);
		IM(result) := RE(left) * IM(right) + IM(left) * RE(right);
		RETURN result
	END "*";

	OPERATOR "/"*(CONST left, right: COMPLEX): COMPLEX;
	VAR result: COMPLEX; iDivisor: REAL;
	BEGIN
		iDivisor := 1.0 / (RE(right) * RE(right) + IM(right) * IM(right));
		RE(result) := (RE(left) * RE(right) + IM(left) * IM(right)) * iDivisor;
		IM(result) := (IM(left) * RE(right) - RE(left) * IM(right)) * iDivisor;
		RETURN result
	END "/";

	OPERATOR "/"*(CONST left, right: LONGCOMPLEX): LONGCOMPLEX;
	VAR result: LONGCOMPLEX; iDivisor: LONGREAL;
	BEGIN
		iDivisor := 1.0D0 / (RE(right) * RE(right) + IM(right) * IM(right));
		RE(result) := (RE(left) * RE(right) + IM(left) * IM(right)) * iDivisor;
		IM(result) := (IM(left) * RE(right) - RE(left) * IM(right)) * iDivisor;
		RETURN result
	END "/";

	OPERATOR "ABS"*(CONST arg: COMPLEX): REAL;
	BEGIN RETURN Math.sqrt(RE(arg) * RE(arg) + IM(arg) * IM(arg))
	END "ABS";

	OPERATOR "ABS"*(CONST arg: LONGCOMPLEX): LONGREAL;
	BEGIN RETURN MathL.sqrt(RE(arg) * RE(arg) + IM(arg) * IM(arg))
	END "ABS";

	OPERATOR "~"*(CONST left: COMPLEX): COMPLEX;
	BEGIN
		RETURN RE(left) - IM(left) * IMAG
	END "~";

	OPERATOR "~"*(CONST left: LONGCOMPLEX): LONGCOMPLEX;
	BEGIN
		RETURN RE(left) - IM(left) * IMAG
	END "~";

	OPERATOR "<="*(CONST x, y: COMPLEX): BOOLEAN; BEGIN RETURN ABS(x) <= ABS(y); END "<=";
	OPERATOR ">="*(CONST x, y: COMPLEX): BOOLEAN; BEGIN RETURN ABS(x) >= ABS(y); END ">=";
	OPERATOR "<"*(CONST x, y: COMPLEX): BOOLEAN; BEGIN RETURN ABS(x) < ABS(y); END "<";
	OPERATOR ">"*(CONST x, y: COMPLEX): BOOLEAN; BEGIN RETURN ABS(x) > ABS(y); END ">";

	OPERATOR "<="*(CONST x, y: LONGCOMPLEX): BOOLEAN; BEGIN RETURN ABS(x) <= ABS(y); END "<=";
	OPERATOR ">="*(CONST x, y: LONGCOMPLEX): BOOLEAN; BEGIN RETURN ABS(x) >= ABS(y); END ">=";
	OPERATOR "<"*(CONST x, y: LONGCOMPLEX): BOOLEAN; BEGIN RETURN ABS(x) < ABS(y); END "<";
	OPERATOR ">"*(CONST x, y: LONGCOMPLEX): BOOLEAN; BEGIN RETURN ABS(x) > ABS(y); END ">";
	
	OPERATOR "ALL"*(CONST x: ARRAY [?] OF SHORTINT; op: PROCEDURE(x: SHORTINT): SHORTINT): ARRAY[?] OF SHORTINT; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpS(ADDRESSOF(RESULT),ADDRESSOF(x),SIZEOF(SHORTINT),GenericLoopS,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF INTEGER; op: PROCEDURE(x: INTEGER): INTEGER): ARRAY[?] OF INTEGER; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpI(ADDRESSOF(RESULT),ADDRESSOF(x),SIZEOF(INTEGER),GenericLoopI,op);
		RETURN RESULT;
	END "ALL";
	
	OPERATOR "ALL"*(CONST x: ARRAY [?] OF LONGINT; op: PROCEDURE(x: LONGINT): LONGINT): ARRAY[?] OF LONGINT; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpL(ADDRESSOF(RESULT),ADDRESSOF(x),SIZEOF(LONGINT),GenericLoopL,op);
		RETURN RESULT;
	END "ALL";
	
	OPERATOR "ALL"*(CONST x: ARRAY [?] OF HUGEINT; op: PROCEDURE(x: HUGEINT): HUGEINT): ARRAY[?] OF HUGEINT; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpH(ADDRESSOF(RESULT),ADDRESSOF(x),SIZEOF(HUGEINT),GenericLoopH,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF REAL; op: PROCEDURE(x: REAL): REAL): ARRAY[?] OF REAL; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpR(ADDRESSOF(RESULT),ADDRESSOF(x),SIZEOF(REAL),GenericLoopR,op);
		RETURN RESULT;
	END "ALL";

	OPERATOR "ALL"*(CONST x: ARRAY [?] OF LONGREAL; op: PROCEDURE(x: LONGREAL): LONGREAL): ARRAY[?] OF LONGREAL; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpX(ADDRESSOF(RESULT),ADDRESSOF(x),SIZEOF(LONGREAL),GenericLoopX,op);
		RETURN RESULT;
	END "ALL";
	
	OPERATOR "ALL"*(CONST x: ARRAY [?] OF COMPLEX; op: PROCEDURE(x: COMPLEX): COMPLEX): ARRAY[?] OF COMPLEX; (*should also accept operator ?*)
	BEGIN
		ApplyGenericUnaryAAOpZ(ADDRESSOF(RESULT),ADDRESSOF(x),SIZEOF(COMPLEX),GenericLoopZ,op);
		RETURN RESULT;
	END "ALL";

BEGIN
	alloc := 0;  SetDefaults();  InitOptimization();  (* CreateTypePool;  *)
END FoxArrayBase.

Compiler.Compile FoxArrayBase.Mod ~

SystemTools.ListModules 