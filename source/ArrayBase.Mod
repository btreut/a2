MODULE ArrayBase;   (**  AUTHOR "fof"; PURPOSE "runtime array operators";  **)
(*** Runtime support for array operators *
	naming convention: see fofPCArrays.Mod
	to display all currently implemented operators execute fofPCArrays.Report

	Provided are

	1.) unary operators:

		a) array -> scalar:
			min ("MIN(A)")
			max ("MAX(A)")
			sum ("SUM(A)")

		b) array -> array:
			minus ("-A") , not ("~A");
			abs ("ABS(A)")
			conversion (used to cast operators. Additionally "SHORT(A)","LONG(A)","ENTIER(A)" supported)
				SHORTINT -> {INTEGER,LONGINT,REAL,LONGREAL},
				INTEGER->{SHORTINT,LONGINT,REAL,LONGREAL},
				LONGINT->{INTEGER,REAL,LONGREAL},
				REAL -> {LONGINT,LONGREAL}
				LONGREAL->{REAL,LONGINT}
			transpose ("A`")

	2.) binary operators
		a) array x array -> array:
			minus ("A-B"),
			plus("A+B"),
			elementwise multiply ("A .* B"),
			elementwise division ("A ./ B"),
			div ("A DIV B"),
			mod ("A MOD B")
			array multiplication A*B (dimA=2,dimB=2)
			cross product A*B (dimA=1,dimB=1)
			array-vec & vec-array multiplication A*B (dimA=1,dimB=2 or dimA=2,dimB=1)
			elementwise comparisons ("A .= B", "A .# B", "A .< B", "A .> B", "A .<= B", "A .>= B");
			logical operators ("A OR B", "A & B");

		b) array x scalar -> array, scalar x array -> array
			minus ("A-s", "s-A");
			plus ("A+s","s+A");
			multiply("A*s","s*A")
			division ("A/s","s/A")
			div ("A DIV s","s DIV A")
			mod ("A MOD s","s MOD A")
			assignment ("A := s") (implemented in the form dest x scalar -> dest)
			elementwise comparisons ("A .= b", "A .# b", "A .< b", "A .> b", "A .<= b", "A .>= b", "a .= B", "a .# B", "a .< B", "a .> B", "a .<= B", "a .>= B");

		c) array x array -> scalar
			scalar product ("A +* B");

		d) array x array -> boolean
			equal ("A=B");
			nequal("A#B");
			comparison ("A<B","A<=B","A>B","A>=B","A<b","A<=b","A>b","A>=b","a<B","a<=B","a>B","a>=B");

		e) scalar x scalar -> scalar
			min ("MIN(a,b)");
			max ("MAX(a,b)");
*)

(*
	allocation convention
	IF Adr(dest)=-1 THEN
		empty descriptor allocated on stack
	END;

	IF Ptr(dest)=0 THEN
		(* open array *)
		must be allocated
	ELSIF Ptr(dest)>0 THEN
		(* open array *)
		check geomerty, may be alloacted if necessary
	ELSIF Ptr(dest) =-1 THEN
		(* static array or range of array *)
		must NOT be allocated, check geometry , trap if wrong geometry
	END;
*)


 (** frequent errors: wrong input type, wrong destination type, wrong loop called, wrong entry in PCArrays.Mod *)

IMPORT KernelLog, SYSTEM, Heaps;

TYPE
	Address = LONGINT;

	UnaryAALoop = PROCEDURE ( ladr, dadr, linc, dinc, len: Address );
	UnaryASLoop = PROCEDURE ( ladr, dadr, linc, len: Address );
	BinaryAAALoop = PROCEDURE ( ladr, radr, dadr, linc, rinc, dinc, len: Address );
	BinaryASALoop = PROCEDURE ( ladr, radr, dadr, linc, dinc, len: Address );
	BinaryAASLoop = PROCEDURE ( ladr, radr, dadr, linc, rinc, len: Address );
	BinaryAABLoop = PROCEDURE ( ladr, radr, linc, rinc, len: Address ): BOOLEAN;
	BinaryASBLoop = PROCEDURE ( ladr, radr, linc, len: Address ): BOOLEAN;

CONST
	debug = FALSE;   (* warning: debug=true -> a lot of output is generated -> traps are not displayed in Oberon (Kernel overflow) *)
	conservative = FALSE;  statistics = TRUE;  ptroffs = 0;  adroffs = 4;  flagoffs = 8;
	dimoffs = 12;  sizeoffs = 16;  lenoffs = 20;  incoffs = 24;

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

TYPE
	FastMatMul* = PROCEDURE ( matrixA, matrixB, matrixC, IncA, StrideA, IncB, StrideB, IncC, StrideC, RowsA, ColsA, RowsB, ColsB: LONGINT ): BOOLEAN;
	TransposeP* = PROCEDURE ( ladr, dadr, lstride, linc, dstride, dinc, rows, cols: LONGINT );
	(*
	TensorType = RECORD
		ptr: ANY;
		tag: LONGINT
	END;
	*)

	(* tensor shape descriptors, statically typed, maximal dimension of a tensor limited to 32 for the time being *)
	T0 = POINTER TO RECORD ptr: ANY; a: ARRAY lenoffs + 0* 8 OF CHAR END;
	T1 = POINTER TO RECORD ptr: ANY; a:ARRAY lenoffs + 1 * 8 OF CHAR END;
	T2 = POINTER TO RECORD ptr: ANY; a:ARRAY lenoffs + 2 * 8 OF CHAR END;
	T3 = POINTER TO RECORD ptr: ANY; a:ARRAY lenoffs + 3 * 8 OF CHAR END;
	T4 = POINTER TO RECORD ptr: ANY; a:ARRAY lenoffs + 4 * 8 OF CHAR END;
	T5 = POINTER TO RECORD ptr: ANY; a:ARRAY lenoffs + 5 * 8 OF CHAR END;
	T6 = POINTER TO RECORD ptr: ANY; a:ARRAY lenoffs + 6 * 8 OF CHAR END;
	T7 = POINTER TO RECORD ptr: ANY; a:ARRAY lenoffs + 7 * 8 OF CHAR END;
	T8 = POINTER TO RECORD ptr: ANY; a:ARRAY lenoffs + 8 * 8 OF CHAR END;
	T9 = POINTER TO RECORD ptr: ANY; a:ARRAY lenoffs + 9 * 8 OF CHAR END;
	T10 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 10 * 8 OF CHAR END;
	T11 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 11 * 8 OF CHAR END;
	T12 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 12 * 8 OF CHAR END;
	T13 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 13 * 8 OF CHAR END;
	T14 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 14 * 8 OF CHAR END;
	T15 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 15 * 8 OF CHAR END;
	T16 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 16 * 8 OF CHAR END;
	T17 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 17 * 8 OF CHAR END;
	T18 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 18 * 8 OF CHAR END;
	T19 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 19 * 8 OF CHAR END;
	T20 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 20 * 8 OF CHAR END;
	T21 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 21 * 8 OF CHAR END;
	T22 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 22 * 8 OF CHAR END;
	T23 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 23 * 8 OF CHAR END;
	T24 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 24 * 8 OF CHAR END;
	T25 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 25 * 8 OF CHAR END;
	T26 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 26 * 8 OF CHAR END;
	T27 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 27 * 8 OF CHAR END;
	T28 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 28 * 8 OF CHAR END;
	T29 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 29 * 8 OF CHAR END;
	T30 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 30 * 8 OF CHAR END;
	T31 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 31 * 8 OF CHAR END;
	T32 =POINTER TO  RECORD ptr: ANY;a: ARRAY lenoffs + 32 * 8 OF CHAR END;

	(* used for optimizations of MatMul with small sizes (Alexey Morozov) *)
	SmallMatMul* = PROCEDURE(dadr, ladr, radr: LONGINT);

VAR
	alloc*: LONGINT;   (* statistics *)
	allocTemp*: LONGINT;   (* statistics *)

	(* procedures that might be replaced by ASM methods *)
	loopSPAXAX*, loopSPARAR*: BinaryAASLoop;
	loopAddAXAX*, loopAddARAR*: BinaryAAALoop;
	loopMatMulAXAX*, loopMatMulARAR*: BinaryAASLoop;
	loopMatMulIncAXAX*, loopMatMulIncARAR*: BinaryAASLoop;
	loopMulAXSX*, loopMulARSR*: BinaryASALoop;
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
		loopAddARAR := AddARARLoop;  loopMatMulAXAX := MatMulAXAXLoop;
		loopMatMulIncAXAX := MatMulIncAXAXLoop;
		loopMatMulARAR := MatMulARARLoop;  loopMulAXSX := MulAXSXLoop;
		loopIncMulAXSX := IncMulAXSXLoop;
		loopMatMulIncARAR := MatMulIncARARLoop;
		loopMulARSR := MulARSRLoop;  loopIncMulARSR := IncMulARSRLoop;
		matMulX := NIL;  matMulR := NIL;  matMulIncX := NIL;  matMulIncR := NIL;
	END SetDefaults;

	PROCEDURE Err(CONST s: ARRAY OF CHAR );
	BEGIN
		KernelLog.String( "Runtime Error: " );  KernelLog.String( s );  KernelLog.Ln;  HALT( 100 );
	END Err;

	(*
	PROCEDURE NewTensorType( dim: LONGINT;  VAR t: TensorType );
	VAR tp: ANY;  tag: LONGINT;
	BEGIN
		Heaps.NewType( tp, lenoffs + dim * 8, 1, 0, "ArrayDescriptor", NIL , {} );
		tag := SYSTEM.VAL( LONGINT, tp );   (* type desc base adr *)
		tag := SYSTEM.GET32( tag + 8 );   (* self pointer pointing to start of record descriptor *)
		SYSTEM.PUT( tag + 4, 0 );   (* offset of pointer to array data in array descriptor is 0 *)
		t.ptr := tp;  t.tag := tag;
	END NewTensorType;
	*)

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

	(*
	PROCEDURE CreateTypePool;
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN( TensorTypePool ) - 1 DO
			NewTensorType( i, TensorTypePool[i] );
		END;
	END CreateTypePool;
	*)

	(*** helping procedures ********************************************************************)

	 (** access to geometry , caution: reverse dimension ordering compared to SYSTEM.INCR(..)  and LEN(..) *)

	(*
	A[x,y,z];
		GetInc(A,i):
			i=0: x
			i=1: y
			i=2: z
			etc.
			note that in general inc(x)>inc(y)>inc(z), i.e. z-dimension is in most cases continuous
	*)
(*
machine code equivalents:

(* get increment of dimension dim *)
	PROCEDURE -GetInc( base, dim: Address ): LONGINT;
	CODE {SYSTEM.i386}
		MOV	EBX, 4[ESP] (* base *)
		MOV	EDX, [ESP] (* dim *)
		MOV	EAX, incoffs[EBX+EDX*8] (* return base + 8 + 8*dim *)
		ADD	ESP, 8
	END GetInc;

(* set increment of dimension dim *)
	PROCEDURE -PutInc( base, dim, val: Address );
	CODE {SYSTEM.i386}
		MOV	EBX, 8[ESP] (*base *)
		MOV	EDX, 4[ESP] (* dim *)
		MOV	ECX, [ESP] (* val *)
		MOV	incoffs[EBX+EDX*8], ECX (* [base+8+8*dim] := val *)
		ADD	ESP, 12
	END PutInc;

(* get len of dimension dim *)
	PROCEDURE -GetLen( base, dim: Address ): LONGINT;
	CODE {SYSTEM.i386}
		MOV	EBX, 4[ESP] (* base *)
		MOV	EDX, [ESP] (* dim *)
		MOV	EAX, lenoffs[EBX+EDX*8] (* return base + 4 + 8*dim *)
		ADD	ESP, 8
	END GetLen;

(* set len of dimension dim *)
	PROCEDURE -PutLen( base, dim, val: Address );
	CODE {SYSTEM.i386}
		MOV	EBX, 8[ESP] (*base *)
		MOV	EDX, 4[ESP] (* dim *)
		MOV	ECX, [ESP] (* val *)
		MOV	lenoffs[EBX+EDX*8], ECX (* [base+4+8*dim] := val *)
		ADD	ESP, 12
	END PutLen;

(* get data address *)
	PROCEDURE -GetAdr( base: Address ): LONGINT;
	CODE {SYSTEM.i386}
		MOV	EBX, [ESP] (*base *)
		MOV	EAX, adroffs[EBX]
		ADD	ESP, 4
	END GetAdr;

(* set data address *)
	PROCEDURE -PutAdr( base, val: Address );
	CODE {SYSTEM.i386}
		MOV	EBX, 4[ESP] (*base *)
		MOV	EDX, [ESP] (* val *)
		MOV	adroffs[EBX], EDX (* [base] := val *)
		ADD	ESP, 8
	END PutAdr;

(* get data address *)
	PROCEDURE -GetPtr( base: Address ): LONGINT;
	CODE {SYSTEM.i386}
		MOV	EBX, [ESP] (*base *)
		MOV	EAX, ptroffs[EBX]
		ADD	ESP, 4
	END GetPtr;

(* set data address *)
	PROCEDURE -PutPtr( base, val: Address );
	CODE {SYSTEM.i386}
		MOV	EBX, 4[ESP] (*base *)
		MOV	EDX, [ESP] (* val *)
		MOV	ptroffs[EBX], EDX (* protector := val *)
		ADD	ESP, 8
	END PutPtr;
*)

	(* get increment of dimension dim *)
	PROCEDURE GetInc(base,dim: Address): LONGINT;
	VAR result: LONGINT;
	BEGIN
		SYSTEM.GET(base+incoffs+8*dim,result);
		RETURN result
	END GetInc;

	(* set increment of dimension dim *)
	PROCEDURE PutInc(base,dim,val: Address);
	BEGIN
		SYSTEM.PUT(base+incoffs+8*dim,val)
	END PutInc;

	(* get length of dimension dim *)
	PROCEDURE GetLen(base,dim: Address): LONGINT;
	VAR result: LONGINT;
	BEGIN
		SYSTEM.GET(base+lenoffs+8*dim,result);
		RETURN result
	END GetLen;

	(* set length of dimension dim *)
	PROCEDURE PutLen(base,dim,val: Address);
	BEGIN
		SYSTEM.PUT(base+lenoffs+8*dim,val)
	END PutLen;

	(* get data address *)
	PROCEDURE GetAdr(base: Address): Address;
	VAR result: LONGINT;
	BEGIN
		SYSTEM.GET(base+adroffs,result);
		RETURN result
	END GetAdr;

	(* set data address *)
	PROCEDURE PutAdr(base,value: Address);
	BEGIN
		SYSTEM.PUT(base+adroffs,value)
	END PutAdr;

	(* get data base pointer (GC protection) *)
	PROCEDURE GetPtr(base: Address): Address;
	VAR result: LONGINT;
	BEGIN
		SYSTEM.GET(base+ptroffs,result);
		RETURN result
	END GetPtr;

	(* set data base pointer (GC protection) *)
	PROCEDURE PutPtr(base,value: Address);
	BEGIN
		SYSTEM.PUT(base+ptroffs,value)
	END PutPtr;

	PROCEDURE GetSize( base: Address ): LONGINT;
	VAR dim: LONGINT;
	BEGIN
		IF base = 0 THEN RETURN 0 ELSE SYSTEM.GET( base + sizeoffs, dim );  RETURN dim;  END;
	END GetSize;

	PROCEDURE PutSize( base: Address;  dim: LONGINT );
	BEGIN
		SYSTEM.PUT( base + sizeoffs, dim );
	END PutSize;

	PROCEDURE GetDim( base: Address ): LONGINT;
	VAR dim: LONGINT;
	BEGIN
		IF base = 0 THEN RETURN 0 ELSE SYSTEM.GET( base + dimoffs, dim );  RETURN dim;  END;
	END GetDim;

	PROCEDURE GetFlags( base: Address ): SET;
	VAR set: SET;
	BEGIN
		SYSTEM.GET( base + flagoffs, set );  RETURN set;
	END GetFlags;

	PROCEDURE PutDim( base: Address;  dim: LONGINT );
	BEGIN
		SYSTEM.PUT( base + dimoffs, dim );
	END PutDim;

	PROCEDURE PutFlags( base: Address;  flags: SET );
	BEGIN
		SYSTEM.PUT( base + flagoffs, flags );
	END PutFlags;


(*
(* report geometry of array passed via address s *)
	PROCEDURE Report( name: ARRAY OF CHAR;  s: LONGINT );
	VAR i: LONGINT;  ldim, inc, len: LONGINT;  dim: LONGINT;
	BEGIN
		KernelLog.String( name );  KernelLog.String( " at adr " );  KernelLog.Int( s, 1 );
		KernelLog.String( "; ptr= " );  KernelLog.Int( GetPtr( s ), 1 );  KernelLog.String( "; adr= " );
		KernelLog.Int( GetAdr( s ), 1 );  KernelLog.Ln;
		FOR i := 0 TO dim - 1 DO
			KernelLog.String( "dim (rev)=" );  KernelLog.Int( i, 1 );  KernelLog.String( ", len=" );
			KernelLog.Int( GetLen( s, i ), 1 );  KernelLog.String( ", inc=" );
			KernelLog.Int( GetInc( s, i ), 1 );  KernelLog.Ln;
		END;
		FindPattern1( s, dim, ldim, len, inc );  KernelLog.String( "increment: " );
		KernelLog.Int( inc, 10 );  KernelLog.Ln;  KernelLog.String( "longest dim:" );  KernelLog.Int( ldim, 10 );
		KernelLog.Ln;  KernelLog.String( "len:" );  KernelLog.Int( len, 10 );  KernelLog.Ln;
	END Report;
	*)


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
		linc := GetInc( left, d );  DEC( d );
		WHILE (d >= 0) & (GetInc( left, d ) = len * linc) DO
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
		linc := GetInc( left, d );  ri := GetInc( right, d );  DEC( d );
		WHILE (d >= 0) & (GetInc( left, d ) = len * linc) & (GetInc( right, d ) = len * ri) DO
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
		linc := GetInc( left, d );  ri := GetInc( right, d );  di := GetInc( dest, d );
		DEC( d );
		WHILE (d >= 0) & (GetInc( left, d ) = len * linc) &
				    (GetInc( right, d ) = len * ri) & (GetInc( dest, d ) = len * di) DO
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
			INC( sr, GetInc( src, d ) * (GetLen( src, d ) - 1) );
			PutInc( src, d, -GetInc( src, d ) );  INC( d );
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
			INC( sr, GetInc( src, d ) * (GetLen( src, d ) - 1) );
			INC( dr, GetInc( dest, d ) * (GetLen( dest, d ) - 1) );  INC( d );
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
		INC( len, 2 * dim * SIZEOF( LONGINT ) + lenoffs );  SYSTEM.NEW( p, len );
		dest := SYSTEM.VAL( LONGINT, p );
		PutAdr( dest, dest + dim * 2 * SIZEOF( LONGINT ) + lenoffs );
		PutPtr( dest, dest );  PutDim( dest, dim );  len := Size;
		FOR i := 0 TO dim - 1 DO
			PutInc( dest, i, len );  PutLen( dest, i, GetLen( src, i ) );
			len := len * GetLen( src, i );
		END;
		(* Report("allocdest",dest,dim); *)
		RETURN p;
	END AllocateTemp;


	(*** procedures to traverse arrays and apply operators *)

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
				len := GetLen( left, dim );  linc := GetInc( left, dim );
				dinc := GetInc( dest, dim );  INC( dim );
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
				len := GetLen( left, dim );  linc := GetInc( left, dim );  INC( dim );
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
				len := GetLen( left, dim );  linc := GetInc( left, dim );
				rinc := GetInc( right, dim );  dinc := GetInc( dest, dim );  INC( dim );
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
				origdest := dest;  p :=
				AllocateTemp( dest, origdest, elementSize );   (* 1d field ? *)
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
				len := GetLen( left, dim );  linc := GetInc( left, dim );
				dinc := GetInc( dest, dim );  INC( dim );
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
				len := GetLen( left, dim );  linc := GetInc( left, dim );
				rinc := GetInc( right, dim );  INC( dim );
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
														    Loop: BinaryAABLoop ): BOOLEAN;
	VAR loopd, looplen, loopli, loopri: LONGINT;  left, right, dim: LONGINT;

		PROCEDURE Traverse( dim: LONGINT;  ladr, radr: Address ): BOOLEAN;
		VAR len: LONGINT;  linc, rinc: LONGINT;
		BEGIN
			IF dim = loopd THEN RETURN Loop( ladr, radr, loopli, loopri, looplen );
			ELSE
				len := GetLen( left, dim );  linc := GetInc( left, dim );
				rinc := GetInc( right, dim );  INC( dim );
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
			Report( "left", left );  Report( "right", right );
			Halt( GeometryMismatch, left, right, 0 )
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
				len := GetLen( left, dim );  linc := GetInc( left, dim );  INC( dim );
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
				len := GetLen( src, dim );  linc := GetInc( src, dim );
				dinc := GetInc( dest, dim );  INC( dim );
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
			SYSTEM.GET( src - 4, tag );  Heaps.NewRec( ptr, tag, FALSE );
			dest := SYSTEM.VAL( LONGINT, ptr );
		END UseDescriptor;

		PROCEDURE NewData;
		VAR dim, len, size: LONGINT;
		BEGIN
			dim := GetDim( src );  size := elementsize;  PutDim( dest, dim );
			PutSize( dest, elementsize );
			WHILE (dim > 0) DO
				DEC( dim );  len := GetLen( src, dim );  PutLen( dest, dim, len );
				PutInc( dest, dim, size );  size := size * len;
			END;
			SYSTEM.NEW( data, size );  PutAdr( dest, SYSTEM.VAL( LONGINT, data ) );
			PutPtr( dest, SYSTEM.VAL( LONGINT, data ) );
		END NewData;

	BEGIN
		IF dest # 0 THEN Size := GetSize( dest );  ASSERT( Size = elementsize );  END;
		IF debug THEN KernelLog.String( "Allocate same " );  Report( "allocation source", src );  Report( "allocation des", dest );  END;
		IF dest = 0 THEN  (* NIL pointer, guaranteed to be tensor *)
			IF TensorFlag IN GetFlags( src ) THEN UseDescriptor();
			ELSE ptr := GetArrayDesc( GetDim( src ) );  dest := SYSTEM.VAL( LONGINT, ptr );
			END;
			NewData();  RETURN ptr;
		ELSIF GetDim( dest ) # GetDim( src ) THEN  (* different dimension *)
			(* check if re-allocation of descriptor is allowed *)
			IF ~(TensorFlag IN GetFlags( dest )) &
				~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				HALT( 100 );
			END;
			UseDescriptor();  NewData();  RETURN ptr;
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
		dim := GetDim( src );  SYSTEM.NEW( p, dim * 8 + lenoffs );
		SYSTEM.MOVE( src, SYSTEM.VAL( LONGINT, p ), dim * 8 + lenoffs );  PutAdr( src, 0 );
		PutPtr( src, 0 );  PutFlags( src, {} );  RETURN p;
	END TempDescCopy;

	PROCEDURE CopyArraySelf*( dest, src: Address;  elementsize: LONGINT );
	VAR p: ANY;
	BEGIN
		ASSERT( src = dest );  p := TempDescCopy( src );
		CopyArray( dest, SYSTEM.VAL( LONGINT, p ), elementsize );
	END CopyArraySelf;

	PROCEDURE CopyArray*( dest: Address;  src: Address;
											  elementsize: LONGINT );
	VAR p: ANY;
	BEGIN
		(* IF dest = 0 THEN Helper.ViewFrame END;  *)
		ASSERT( dest # 0 );   (* impossible *)
		IF GetDim( src ) # GetDim( dest ) THEN  (* not allowed but possible (tensor) *)
			HALT( 100 );
		ELSIF src = dest THEN  (* self copy *)
			CopyArraySelf( dest, src, elementsize );
		ELSE
			p := AllocateSame( dest, src, elementsize );
			CopyContent( dest, src, elementsize )
		END;
	END CopyArray;

	PROCEDURE CopyTensorSelf*( VAR dest: Address;  src: Address;
													    elementsize: LONGINT );
	BEGIN
		dest := 0;  CopyTensor( dest, src, elementsize );
	END CopyTensorSelf;

	PROCEDURE CopyTensor*( VAR dest: Address;  src: Address;
												 elementsize: LONGINT );
	VAR p: ANY;
	BEGIN
		IF (dest = 0) OR ~(SameShape( dest, src )) OR (GetAdr( dest ) = 0) THEN
			p := AllocateSame( dest, src, elementsize );   (* includes check if allocation is allowed *)
			CopyContent( dest, src, elementsize );
		ELSIF dest = src THEN CopyTensorSelf( dest, src, elementsize );
		ELSE CopyContent( dest, src, elementsize )
		END;
	END CopyTensor;

	(* copy descriptor of src to that of dest. If not existent then create.*)
	PROCEDURE ShallowCopy*(VAR dest: Address; src: Address);
	VAR ptr: ANY;

		PROCEDURE UseTypeDescriptor;
		VAR tag: LONGINT;  ptr: ANY;
		BEGIN
			SYSTEM.GET( src + Heaps.TypeDescOffset, tag );  Heaps.NewRec( ptr, tag, FALSE );
			dest := SYSTEM.VAL( LONGINT, ptr );
		END UseTypeDescriptor;

		PROCEDURE CopyDescriptor;
		BEGIN
			SYSTEM.MOVE( src , dest, lenoffs + SIZEOF(Address) *  GetDim( src ) *2 );
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
		ELSIF GetDim( dest ) # GetDim( src ) THEN  (* different dimension *)
			(* check if re-allocation of descriptor is allowed *)
			IF ~(TensorFlag IN GetFlags( dest )) & ~(TemporaryFlag IN GetFlags( dest )) THEN  (* no, not allowed*)
				Halt(DimensionMismatch,src,0,dest);
			END;

			(* create a new descriptor!!! (added by Alexey) *)
			ptr := GetArrayDesc( GetDim( src ) );  dest := SYSTEM.VAL( LONGINT, ptr );

			CopyDescriptor();
		ELSE
			(* check if re-allocation of array data is allowed *)
			IF RangeFlag IN GetFlags( dest ) THEN  (* no! not allowed *)
				Halt(AllocationForbidden,src,0,dest);
			END;
			CopyDescriptor();
		END;

	END ShallowCopy;


	PROCEDURE DescriptorCopy( src, dest: LONGINT );
	BEGIN
		IF debug THEN
			KernelLog.String( "DescriptorCopy from " );  KernelLog.Int( src, 1 );  KernelLog.String( " to " );
			KernelLog.Int( dest, 1 );  KernelLog.Ln;
		END;
		SYSTEM.MOVE( src, dest, 2*SIZEOF(Address) );   (* adr and ptr *)
		SYSTEM.MOVE( src + lenoffs, dest + lenoffs, SIZEOF(Address) *  GetDim( src ) *2 );   (* lens and increments *)
	END DescriptorCopy;

	PROCEDURE ZeroCopyArray*( dest: Address;  src: Address;
													 elementsize: LONGINT );
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

	PROCEDURE ZeroCopyTensor*( VAR dest: Address;  src: Address;
														elementsize: LONGINT );
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
				KernelLog.Int( GetInc( s, i ), 1 );  KernelLog.Ln;
			END;
			(*
		FindPattern1( s, dim, ldim, len, inc );  KernelLog.String( "increment: " );
		KernelLog.Int( inc, 10 );  KernelLog.Ln;  KernelLog.String( "longest dim:" );  KernelLog.Int( ldim, 10 );
		KernelLog.Ln;  KernelLog.String( "len:" );  KernelLog.Int( len, 10 );  KernelLog.Ln;
		*)
		END;
	END Report;


(*
	PROCEDURE AddALAL*( VAR dest: ARRAY [?] OF LONGINT;  left, right: ARRAY [?] OF LONGINT );
	VAR d: LONGINT;  i, j: LONGINT;  adrd, adrl: LONGINT;
	BEGIN
		ApplyBinaryAAAOpx( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGINT ),
										    AddALALLoop );
	END AddALAL;
	*)

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
				PutInc( dest, i, GetInc( left, i ) );  PutLen( dest, i, GetLen( left, i ) );
			END;
		END;
	END ZeroCopy;

	(*** array conversions ********************************************************************)

(** SHORTINT -> INTEGER  *)

	PROCEDURE ConvertASAILoop( ladr, dadr, linc, dinc, len: LONGINT );
	BEGIN
		WHILE (len > 0) DO  (* SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval ); *)
			SYSTEM.PUT16( dadr, SYSTEM.GET8( ladr ) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END ConvertASAILoop;

	PROCEDURE ConvertASAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
												  CONST src: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( INTEGER ),
									   ConvertASAILoop );
	END ConvertASAI;

(** SHORTINT -> LONGINT *)
	PROCEDURE ConvertLoopSL( ladr, dadr, linc, dinc, len: LONGINT );
	BEGIN
		WHILE (len > 0) DO  (* SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval ); *)
			SYSTEM.PUT32( dadr, SYSTEM.GET8( ladr ) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END ConvertLoopSL;

	PROCEDURE ConvertASAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
												  CONST src: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGINT ),
									   ConvertLoopSL );
	END ConvertASAL;

(** SHORTINT -> REAL *)
	PROCEDURE ConvertLoopSR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: SHORTINT;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopSR;

	PROCEDURE ConvertASAR*( VAR dest: ARRAY [ ? ] OF REAL;
												   CONST src: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( REAL ), ConvertLoopSR );
	END ConvertASAR;

(** SHORTINT -> LONGREAL *)
	PROCEDURE ConvertLoopSX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: SHORTINT;  dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopSX;

	PROCEDURE ConvertASAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												  CONST src: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGREAL ),
									   ConvertLoopSX );
	END ConvertASAX;

(** INTEGER -> SHORTINT (SHORT) *)
	PROCEDURE ConvertLoopIS( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;  dval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := SHORT( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopIS;

	PROCEDURE ConvertAIAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
												  CONST src: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( SHORTINT ),
									   ConvertLoopIS );
	END ConvertAIAS;

	(** INTEGER -> LONGINT *)
(*
	PROCEDURE ItoL(s,d: LONGINT);
	CODE{SYSTEM.i386, SYSTEM.FPU}
		MOVSX   EBX,WORD ANY s[EBP]
	MOV d[EBP],EBX
	END ItoL;
*)


	PROCEDURE ConvertLoopIL( ladr, dadr, linc, dinc, len: LONGINT );
	BEGIN
		WHILE (len > 0) DO  (* SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  *)
			SYSTEM.PUT32( dadr, SYSTEM.GET16( ladr ) );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END ConvertLoopIL;

	PROCEDURE ConvertAIAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
												 CONST src: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGINT ),
									   ConvertLoopIL );
	END ConvertAIAL;

(** INTEGER -> REAL *)
	PROCEDURE ConvertLoopIR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopIR;

	PROCEDURE ConvertAIAR*( VAR dest: ARRAY [ ? ] OF REAL;
												  CONST src: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( REAL ), ConvertLoopIR );
	END ConvertAIAR;

(** INTEGER -> LONGREAL *)
	PROCEDURE ConvertLoopIX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;  dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopIX;

	PROCEDURE ConvertAIAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												  CONST src: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGREAL ),
									   ConvertLoopIX );
	END ConvertAIAX;

(** LONGINT -> INTEGER (SHORT) *)
	PROCEDURE ConvertLoopLI( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;  dval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := SHORT( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLI;

	PROCEDURE ConvertALAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
												 CONST src: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( INTEGER ),
									   ConvertLoopLI );
	END ConvertALAI;

(** LONGINT -> REAL *)
	PROCEDURE ConvertLoopLR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLR;

	PROCEDURE ConvertALAR*( VAR dest: ARRAY [ ? ] OF REAL;
												  CONST src: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( REAL ), ConvertLoopLR );
	END ConvertALAR;

(** LONGINT -> LONGREAL *)
	PROCEDURE ConvertLoopLX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;  dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopLX;

	PROCEDURE ConvertALAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												  CONST src: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGREAL ),
									   ConvertLoopLX );
	END ConvertALAX;

(** REAL -> LONGINT (ENTIER) *)
	PROCEDURE ConvertLoopRL( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: REAL;  dval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := ENTIER( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopRL;

	PROCEDURE ConvertARAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
												  CONST src: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGINT ),
									   ConvertLoopRL );
	END ConvertARAL;

(** REAL -> LONGREAL *)
	PROCEDURE ConvertLoopRX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: REAL;  dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopRX;

	PROCEDURE ConvertARAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												   CONST src: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGREAL ),
									   ConvertLoopRX );
	END ConvertARAX;

(** LONGREAL -> REAL (SHORT) *)
	PROCEDURE ConvertLoopXR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGREAL;  dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := SHORT( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopXR;

	PROCEDURE ConvertAXAR*( VAR dest: ARRAY [ ? ] OF REAL;
												   CONST src: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( REAL ), ConvertLoopXR );
	END ConvertAXAR;

(** LONGREAL -> LONGINT (ENTIER) *)
	PROCEDURE ConvertLoopXL( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGREAL;  dval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := ENTIER( lval );  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ConvertLoopXL;

	PROCEDURE ConvertAXAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
												  CONST src: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGINT ),
									   ConvertLoopXL );
	END ConvertAXAL;

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

	PROCEDURE NotAB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
										 CONST src: ARRAY [ ? ] OF BOOLEAN );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( BOOLEAN ), NotLoopAB );
	END NotAB;


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

	PROCEDURE MinusAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											 CONST src: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( SHORTINT ), MinusLoopS );
	END MinusAS;

(** INTEGER *)
	PROCEDURE MinusLoopI( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopI;

	PROCEDURE MinusAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
										    CONST src: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( INTEGER ), MinusLoopI );
	END MinusAI;

(** LONGINT *)
	PROCEDURE MinusLoopL( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopL;

	PROCEDURE MinusAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
											CONST src: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGINT ), MinusLoopL );
	END MinusAL;

(** REAL *)
	PROCEDURE MinusLoopR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopR;

	PROCEDURE MinusAR*( VAR dest: ARRAY [ ? ] OF REAL;
											 CONST src: ARRAY [ ? ] OF REAL );
	BEGIN
		IF debug THEN KernelLog.String( "MinusAR" );  KernelLog.Ln;  END;
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( REAL ), MinusLoopR );
	END MinusAR;

(** LONGREAL *)
	PROCEDURE MinusLoopX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, -lval );  INC( ladr, linc );  INC( dadr, dinc );
			DEC( len );
		END;
	END MinusLoopX;

	PROCEDURE MinusAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											 CONST src: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGREAL ),
									   MinusLoopX );
	END MinusAX;

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

	PROCEDURE AddASAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), AddASASLoop );
	END AddASAS;

(** INTEGER *)
	PROCEDURE AddAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAIAILoop;

	PROCEDURE AddAIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
										   CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), AddAIAILoop );
	END AddAIAI;

(** LONGINT *)
	PROCEDURE AddALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddALALLoop;

	PROCEDURE AddALAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
										    CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		(*
		 Report("dest",SYSTEM.VAL(LONGINT,dest)); Report("left",SYSTEM.VAL(LONGINT,left));Report("right",SYSTEM.VAL(LONGINT,right));
		KernelLog.Int(ADDRESSOF(dest),10); KernelLog.Int(ADDRESSOF(left),10); KernelLog.Int(ADDRESSOF(right),10); KernelLog.Ln;
		*)

		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), AddALALLoop );
	END AddALAL;

(** REAL *)
	PROCEDURE AddARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddARARLoop;

	PROCEDURE AddARAR*( VAR dest: ARRAY [ ? ] OF REAL;
											 CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopAddARAR );
	END AddARAR;

	PROCEDURE AddAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END AddAXAXLoop;

	PROCEDURE AddAXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopAddAXAX );
	END AddAXAX;

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

	PROCEDURE AddASSS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											CONST left: ARRAY [ ? ] OF SHORTINT;
											right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), AddASSSLoop );
	END AddASSS;

	PROCEDURE AddSSAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;  left: SHORTINT;
											CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), AddASSSLoop );
	END AddSSAS;

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

	PROCEDURE AddAISI*( VAR dest: ARRAY [ ? ] OF INTEGER;
										   CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), AddAISILoop );
	END AddAISI;

	PROCEDURE AddSIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;  left: INTEGER;
										   CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), AddAISILoop );
	END AddSIAI;

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

	PROCEDURE AddALSL*( VAR dest: ARRAY [ ? ] OF LONGINT;
										    CONST left: ARRAY [ ? ] OF LONGINT;  right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), AddALSLLoop );
	END AddALSL;

	PROCEDURE AddSLAL*( VAR dest: ARRAY [ ? ] OF LONGINT;  left: LONGINT;
										    CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), AddALSLLoop );
	END AddSLAL;

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

	PROCEDURE AddARSR*( VAR dest: ARRAY [ ? ] OF REAL;
											 CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  AddARSRLoop );
	END AddARSR;

	PROCEDURE AddSRAR*( VAR dest: ARRAY [ ? ] OF REAL;  left: REAL;
											 CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  AddARSRLoop );
	END AddSRAR;

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

	PROCEDURE AddAXSX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											CONST left: ARRAY [ ? ] OF LONGREAL;
											right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), AddAXSXLoop );
	END AddAXSX;

	PROCEDURE AddSXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											left: LONGREAL;
											CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), AddAXSXLoop );
	END AddSXAX;

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

	PROCEDURE SubASAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), SubASASLoop );
	END SubASAS;

(** INTEGER *)
	PROCEDURE SubAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubAIAILoop;

	PROCEDURE SubAIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
										   CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), SubAIAILoop );
	END SubAIAI;

(** LONGINT *)
	PROCEDURE SubALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubALALLoop;

	PROCEDURE SubALAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
										    CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), SubALALLoop );
	END SubALAL;

(** REAL *)
	PROCEDURE SubARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubARARLoop;

	PROCEDURE SubARAR*( VAR dest: ARRAY [ ? ] OF REAL;
											 CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  SubARARLoop );
	END SubARAR;

(** LONGREAL *)
	PROCEDURE SubAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval - rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END SubAXAXLoop;

	PROCEDURE SubAXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), SubAXAXLoop );
	END SubAXAX;

	(*** subtraction array-scalar -> array  ********************************************************************)

(** SHORTINT *)
	PROCEDURE SubASSS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											CONST left: ARRAY [ ? ] OF SHORTINT;
											right: SHORTINT );   (* a: left, b: right, c: dest *)
	BEGIN
		AddASSS( dest, left, -right );
	END SubASSS;

(** INTEGER *)
	PROCEDURE SubAISI*( VAR dest: ARRAY [ ? ] OF INTEGER;
										   CONST left: ARRAY [ ? ] OF INTEGER;
	right: INTEGER );   (* a: left, b: right, c: dest *)
	BEGIN
		AddAISI( dest, left, -right );
	END SubAISI;

(** LONGINT *)
	PROCEDURE SubALSL*( VAR dest: ARRAY [ ? ] OF LONGINT;
										    CONST left: ARRAY [ ? ] OF LONGINT;
	right: LONGINT );   (* a: left, b: right, c: dest *)
	BEGIN
		AddALSL( dest, left, -right );
	END SubALSL;

(** REAL *)
	PROCEDURE SubARSR*( VAR dest: ARRAY [ ? ] OF REAL;
											 CONST left: ARRAY [ ? ] OF REAL;
	right: REAL );   (* a: left, b: right, c: dest *)
	BEGIN
		AddARSR( dest, left, -right );
	END SubARSR;

(** LONGREAL *)
	PROCEDURE SubAXSX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											CONST left: ARRAY [ ? ] OF LONGREAL;
											right: LONGREAL );   (* a: left, b: right, c: dest *)
	BEGIN
		AddAXSX( dest, left, -right );
	END SubAXSX;

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

	PROCEDURE SubSSAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;  left: SHORTINT;
											CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), SubSSASLoop );
	END SubSSAS;

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

	PROCEDURE SubSIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;  left: INTEGER;
										   CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), SubSIAILoop );
	END SubSIAI;

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

	PROCEDURE SubSLAL*( VAR dest: ARRAY [ ? ] OF LONGINT;  left: LONGINT;
										    CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), SubSLALLoop );
	END SubSLAL;

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

	PROCEDURE SubSRAR*( VAR dest: ARRAY [ ? ] OF REAL;  left: REAL;
											 CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  SubSRARLoop );
	END SubSRAR;

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

	PROCEDURE SubSXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											left: LONGREAL;
											CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), SubSXAXLoop );
	END SubSXAX;



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

	PROCEDURE EMulASAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											   CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), EMulASASLoop );
	END EMulASAS;

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

	PROCEDURE EMulAIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
											 CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), EMulAIAILoop );
	END EMulAIAI;

(** LONGINT *)
	PROCEDURE EMulALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulALALLoop;

	PROCEDURE EMulALAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
											  CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), EMulALALLoop );
	END EMulALAL;

(** REAL *)
	PROCEDURE EMulARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulARARLoop;

	PROCEDURE EMulARAR*( VAR dest: ARRAY [ ? ] OF REAL;
											   CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EMulARARLoop );
	END EMulARAR;

(** LONGREAL *)
	PROCEDURE EMulAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulAXAXLoop;

	PROCEDURE EMulAXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											   CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), EMulAXAXLoop );
	END EMulAXAX;

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

	PROCEDURE EMulIncASAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											   CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), EMulIncASASLoop );
	END EMulIncASAS;

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

	PROCEDURE EMulIncAIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
											 CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), EMulIncAIAILoop );
	END EMulIncAIAI;

(** LONGINT *)
	PROCEDURE EMulIncALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval,dval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.GET(dadr,dval); SYSTEM.PUT( dadr, dval+ lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncALALLoop;

	PROCEDURE EMulIncALAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
											  CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), EMulIncALALLoop );
	END EMulIncALAL;

(** REAL *)
	PROCEDURE EMulIncARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval,dval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.GET(dadr,dval);  SYSTEM.PUT( dadr, dval+  lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncARARLoop;

	PROCEDURE EMulIncARAR*( VAR dest: ARRAY [ ? ] OF REAL;
											   CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EMulIncARARLoop );
	END EMulIncARAR;

(** LONGREAL *)
	PROCEDURE EMulIncAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval,dval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval ); SYSTEM.GET(dadr,dval);  SYSTEM.PUT( dadr,dval+ lval * rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EMulIncAXAXLoop;

	PROCEDURE EMulIncAXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											   CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), EMulIncAXAXLoop );
	END EMulIncAXAX;
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

	PROCEDURE MulASSS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											 CONST left: ARRAY [ ? ] OF SHORTINT;
											 right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), MulASSSLoop );
	END MulASSS;

	PROCEDURE MulSSAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;  left: SHORTINT;
											 CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), MulASSSLoop );
	END MulSSAS;

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

	PROCEDURE MulAISI*( VAR dest: ARRAY [ ? ] OF INTEGER;
										   CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), MulAISILoop );
	END MulAISI;

	PROCEDURE MulSIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;  left: INTEGER;
										   CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), MulAISILoop );
	END MulSIAI;

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

	PROCEDURE MulALSL*( VAR dest: ARRAY [ ? ] OF LONGINT;
										    CONST left: ARRAY [ ? ] OF LONGINT;
										    right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), MulALSLLoop );
	END MulALSL;

	PROCEDURE MulSLAL*( VAR dest: ARRAY [ ? ] OF LONGINT;  left: LONGINT;
										    CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), MulALSLLoop );
	END MulSLAL;

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

	PROCEDURE MulARSR*( VAR dest: ARRAY [ ? ] OF REAL;
											 CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopMulARSR );
	END MulARSR;

	PROCEDURE MulSRAR*( VAR dest: ARRAY [ ? ] OF REAL;  left: REAL;
											 CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  loopMulARSR );
	END MulSRAR;

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

	PROCEDURE MulAXSX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											 CONST left: ARRAY [ ? ] OF LONGREAL;
											 right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopMulAXSX );
	END MulAXSX;

	PROCEDURE MulSXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
											 left: LONGREAL;
											 CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), loopMulAXSX );
	END MulSXAX;

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

	PROCEDURE IncMulASSS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
												  CONST left: ARRAY [ ? ] OF SHORTINT;
												  right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), IncMulASSSLoop );
	END IncMulASSS;

	PROCEDURE IncMulSSAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
												  left: SHORTINT;
												  CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), IncMulASSSLoop );
	END IncMulSSAS;


	PROCEDURE DecMulASSS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
												  CONST left: ARRAY [ ? ] OF SHORTINT;
												  right: SHORTINT );
	BEGIN
		MinusAS(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), IncMulASSSLoop );
		MinusAS(dest,dest);
	END DecMulASSS;

	PROCEDURE DecMulSSAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
												  left: SHORTINT;
												  CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		MinusAS(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), IncMulASSSLoop );
		MinusAS(dest,dest);
	END DecMulSSAS;



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

	PROCEDURE IncMulAISI*( VAR dest: ARRAY [ ? ] OF INTEGER;
												 CONST left: ARRAY [ ? ] OF INTEGER;
												 right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), IncMulAISILoop );
	END IncMulAISI;

	PROCEDURE IncMulSIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;  left: INTEGER;
												 CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), IncMulAISILoop );
	END IncMulSIAI;

	PROCEDURE DecMulAISI*( VAR dest: ARRAY [ ? ] OF INTEGER;
												 CONST left: ARRAY [ ? ] OF INTEGER;
												 right: INTEGER );
	BEGIN
		MinusAI(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), IncMulAISILoop );
		MinusAI(dest,dest);
	END DecMulAISI;

	PROCEDURE DecMulSIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;  left: INTEGER;
												 CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		MinusAI(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), IncMulAISILoop );
		MinusAI(dest,dest);
	END DecMulSIAI;

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

	PROCEDURE IncMulALSL*( VAR dest: ARRAY [ ? ] OF LONGINT;
												 CONST left: ARRAY [ ? ] OF LONGINT;
												 right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), IncMulALSLLoop );
	END IncMulALSL;

	PROCEDURE IncMulSLAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
												 left: LONGINT;
												 CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), IncMulALSLLoop );
	END IncMulSLAL;


	PROCEDURE DecMulALSL*( VAR dest: ARRAY [ ? ] OF LONGINT;
												 CONST left: ARRAY [ ? ] OF LONGINT;
												 right: LONGINT );
	BEGIN
		MinusAL(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), IncMulALSLLoop );
		MinusAL(dest,dest);
	END DecMulALSL;

	PROCEDURE DecMulSLAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
												 left: LONGINT;
												 CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		MinusAL(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), IncMulALSLLoop );
		MinusAL(dest,dest);
	END DecMulSLAL;

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

	PROCEDURE IncMulARSR*( VAR dest: ARRAY [ ? ] OF REAL;
												   CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopIncMulARSR );
	END IncMulARSR;

	PROCEDURE IncMulSRAR*( VAR dest: ARRAY [ ? ] OF REAL;  left: REAL;
												   CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  loopIncMulARSR );
	END IncMulSRAR;

	PROCEDURE DecMulARSR*( VAR dest: ARRAY [ ? ] OF REAL;
												   CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		MinusAR(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopIncMulARSR );
		MinusAR(dest,dest);
	END DecMulARSR;

	PROCEDURE DecMulSRAR*( VAR dest: ARRAY [ ? ] OF REAL;  left: REAL;
												   CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		MinusAR(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  loopIncMulARSR );
		MinusAR(dest,dest);
	END DecMulSRAR;

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

	PROCEDURE IncMulAXSX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												  CONST left: ARRAY [ ? ] OF LONGREAL;
												  right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopIncMulAXSX );
	END IncMulAXSX;

	PROCEDURE IncMulSXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												  left: LONGREAL;
												  CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), loopIncMulAXSX );
	END IncMulSXAX;

	PROCEDURE DecMulAXSX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												  CONST left: ARRAY [ ? ] OF LONGREAL;
												  right: LONGREAL );
	BEGIN
		MinusAX(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopIncMulAXSX );
		MinusAX(dest,dest);
	END DecMulAXSX;

	PROCEDURE DecMulSXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												  left: LONGREAL;
												  CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		MinusAX(dest,dest);
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), loopIncMulAXSX );
		MinusAX(dest,dest);
	END DecMulSXAX;

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

	PROCEDURE EDivideASAS*( VAR dest: ARRAY [ ? ] OF REAL;
												   CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EDivideASASLoop );
	END EDivideASAS;

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

	PROCEDURE EDivideAIAI*( VAR dest: ARRAY [ ? ] OF REAL;
												  CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EDivideAIAILoop );
	END EDivideAIAI;

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

	PROCEDURE EDivideALAL*( VAR dest: ARRAY [ ? ] OF REAL;
												  CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EDivideALALLoop );
	END EDivideALAL;

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

	PROCEDURE EDivideARAR*( VAR dest: ARRAY [ ? ] OF REAL;
												    CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  EDivideARARLoop );
	END EDivideARAR;

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

	PROCEDURE EDivideAXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												   CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), EDivideAXAXLoop );
	END EDivideAXAX;

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

	PROCEDURE DivideASSS*( VAR dest: ARRAY [ ? ] OF REAL;
												 CONST left: ARRAY [ ? ] OF SHORTINT;
												 right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  DivideASSSLoop );
	END DivideASSS;

	PROCEDURE DivideSSASLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSSASLoop;

	PROCEDURE DivideSSAS*( VAR dest: ARRAY [ ? ] OF REAL;  left: SHORTINT;
												 CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  DivideSSASLoop );
	END DivideSSAS;

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

	PROCEDURE DivideAISI*( VAR dest: ARRAY [ ? ] OF REAL;
											    CONST left: ARRAY [ ? ] OF INTEGER;
											    right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  DivideAISILoop );
	END DivideAISI;

	PROCEDURE DivideSIAILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSIAILoop;

	PROCEDURE DivideSIAI*( VAR dest: ARRAY [ ? ] OF REAL;  left: INTEGER;
											    CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  DivideSIAILoop );
	END DivideSIAI;

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

	PROCEDURE DivideALSL*( VAR dest: ARRAY [ ? ] OF REAL;
												CONST left: ARRAY [ ? ] OF LONGINT;
												right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  DivideALSLLoop );
	END DivideALSL;

	PROCEDURE DivideSLALLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSLALLoop;

	PROCEDURE DivideSLAL*( VAR dest: ARRAY [ ? ] OF REAL;  left: LONGINT;
												CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  DivideSLALLoop );
	END DivideSLAL;

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

	PROCEDURE DivideARSR*( VAR dest: ARRAY [ ? ] OF REAL;
												  CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  DivideARSRLoop );
	END DivideARSR;

	PROCEDURE DivideSRARLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: REAL;  dval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSRARLoop;

	PROCEDURE DivideSRAR*( VAR dest: ARRAY [ ? ] OF REAL;  left: REAL;
												  CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ), SIZEOF( REAL ),
										  DivideSRARLoop );
	END DivideSRAR;

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

	PROCEDURE DivideAXSX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												 CONST left: ARRAY [ ? ] OF LONGREAL;
												 right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), DivideAXSXLoop );
	END DivideAXSX;

	PROCEDURE DivideSXAXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;  dval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval / lval;  SYSTEM.PUT( dadr, dval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END DivideSXAXLoop;

	PROCEDURE DivideSXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												 left: LONGREAL;
												 CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGREAL ), DivideSXAXLoop );
	END DivideSXAX;


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

	PROCEDURE EDivASAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											  CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), EDivASASLoop );
	END EDivASAS;

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

	PROCEDURE EDivAIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
											CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), EDivAIAILoop );
	END EDivAIAI;

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

	PROCEDURE EDivALAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
											 CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), EDivALALLoop );
	END EDivALAL;


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

	PROCEDURE DivASSS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
										    CONST left: ARRAY [ ? ] OF SHORTINT;
										    right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), DivASSSLoop );
	END DivASSS;

	PROCEDURE DivSSASLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSSASLoop;

	PROCEDURE DivSSAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;  left: SHORTINT;
										    CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), DivSSASLoop );
	END DivSSAS;

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

	PROCEDURE DivAISI*( VAR dest: ARRAY [ ? ] OF INTEGER;
										  CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), DivAISILoop );
	END DivAISI;

	PROCEDURE DivSIAILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSIAILoop;

	PROCEDURE DivSIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;  left: INTEGER;
										  CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), DivSIAILoop );
	END DivSIAI;

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

	PROCEDURE DivALSL*( VAR dest: ARRAY [ ? ] OF LONGINT;
										   CONST left: ARRAY [ ? ] OF LONGINT;  right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), DivALSLLoop );
	END DivALSL;

	PROCEDURE DivSLALLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval DIV lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END DivSLALLoop;

	PROCEDURE DivSLAL*( VAR dest: ARRAY [ ? ] OF LONGINT;  left: LONGINT;
										   CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), DivSLALLoop );
	END DivSLAL;

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

	PROCEDURE EModASAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											   CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), EModASASLoop );
	END EModASAS;

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

	PROCEDURE EModAIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
											  CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), EModAIAILoop );
	END EModAIAI;

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

	PROCEDURE EModALAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
											   CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), EModALALLoop );
	END EModALAL;


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

	PROCEDURE ModASSS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
											 CONST left: ARRAY [ ? ] OF SHORTINT;
											 right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), ModASSSLoop );
	END ModASSS;

	PROCEDURE ModSSASLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;  dval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSSASLoop;

	PROCEDURE ModSSAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;  left: SHORTINT;
											 CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( SHORTINT ), ModSSASLoop );
	END ModSSAS;

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

	PROCEDURE ModAISI*( VAR dest: ARRAY [ ? ] OF INTEGER;
										    CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), ModAISILoop );
	END ModAISI;

	PROCEDURE ModSIAILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;  dval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSIAILoop;

	PROCEDURE ModSIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;  left: INTEGER;
										    CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( INTEGER ), ModSIAILoop );
	END ModSIAI;

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

	PROCEDURE ModALSL*( VAR dest: ARRAY [ ? ] OF LONGINT;
											 CONST left: ARRAY [ ? ] OF LONGINT;
											 right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), ModALSLLoop );
	END ModALSL;

	PROCEDURE ModSLALLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;  dval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  dval := rval MOD lval;  SYSTEM.PUT( dadr, dval );
			INC( ladr, linc );  INC( dadr, dinc );  DEC( len );
		END;
	END ModSLALLoop;

	PROCEDURE ModSLAL*( VAR dest: ARRAY [ ? ] OF LONGINT;  left: LONGINT;
											 CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( LONGINT ), ModSLALLoop );
	END ModSLAL;

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

	PROCEDURE SPASAS*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): LONGINT;
	VAR dest: LONGINT;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SPASASLoop );
		RETURN dest;
	END SPASAS;

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

	PROCEDURE SPAIAI*( CONST left, right: ARRAY [ ? ] OF INTEGER ): LONGINT;
	VAR dest: LONGINT;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SPAIAILoop );
		RETURN dest;
	END SPAIAI;

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

	PROCEDURE SPALAL*( CONST left, right: ARRAY [ ? ] OF LONGINT ): LONGINT;
	VAR dest: LONGINT;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SPALALLoop );
		RETURN dest;
	END SPALAL;

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

	PROCEDURE SPARAR*( CONST left, right: ARRAY [ ? ] OF REAL ): REAL;
	VAR dest: REAL;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), loopSPARAR );
		RETURN dest;
	END SPARAR;

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

	PROCEDURE SPAXAX*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): LONGREAL;
	VAR dest: LONGREAL;
	BEGIN
		dest := 0;
		ApplyBinaryAASOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), loopSPAXAX );
		RETURN dest;
	END SPAXAX;

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

	PROCEDURE EEqlABAB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF BOOLEAN );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlABABLoop );
	END EEqlABAB;

(** SHORTINT *)

	PROCEDURE EEqlASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlASASLoop;

	PROCEDURE EEqlASAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlASASLoop );
	END EEqlASAS;

(** INTEGER *)

	PROCEDURE EEqlAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAIAILoop;

	PROCEDURE EEqlAIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlAIAILoop );
	END EEqlAIAI;

(** LONGINT *)

	PROCEDURE EEqlALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlALALLoop;

	PROCEDURE EEqlALAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlALALLoop );
	END EEqlALAL;

(** REAL *)
	PROCEDURE EEqlARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlARARLoop;

	PROCEDURE EEqlARAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlARARLoop );
	END EEqlARAR;

(** LONGREAL *)
	PROCEDURE EEqlAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval = rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EEqlAXAXLoop;

	PROCEDURE EEqlAXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlAXAXLoop );
	END EEqlAXAX;

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

	PROCEDURE EEqlABSB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF BOOLEAN;
											  right: BOOLEAN );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlABSBLoop );
	END EEqlABSB;

	PROCEDURE EEqlSBAB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  left: BOOLEAN;
											  CONST right: ARRAY [ ? ] OF BOOLEAN );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlABSBLoop );
	END EEqlSBAB;

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

	PROCEDURE EEqlASSS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF SHORTINT;
											  right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlASSSLoop );
	END EEqlASSS;

	PROCEDURE EEqlSSAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  left: SHORTINT;
											  CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlASSSLoop );
	END EEqlSSAS;

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

	PROCEDURE EEqlAISI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlAISILoop );
	END EEqlAISI;

	PROCEDURE EEqlSIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: INTEGER;
											CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlAISILoop );
	END EEqlSIAI;

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

	PROCEDURE EEqlALSL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left: ARRAY [ ? ] OF LONGINT;
											 right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlALSLLoop );
	END EEqlALSL;

	PROCEDURE EEqlSLAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: LONGINT;
											 CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlALSLLoop );
	END EEqlSLAL;

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

	PROCEDURE EEqlARSR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlARSRLoop );
	END EEqlARSR;

	PROCEDURE EEqlSRAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: REAL;
											  CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlARSRLoop );
	END EEqlSRAR;

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

	PROCEDURE EEqlAXSX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF LONGREAL;
											  right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EEqlAXSXLoop );
	END EEqlAXSX;

	PROCEDURE EEqlSXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  left: LONGREAL;
											  CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EEqlAXSXLoop );
	END EEqlSXAX;

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

	PROCEDURE ENeqABAB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											    CONST left, right: ARRAY [ ? ] OF BOOLEAN );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqABABLoop );
	END ENeqABAB;

(** SHORTINT *)
	PROCEDURE ENeqASASLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: SHORTINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqASASLoop;

	PROCEDURE ENeqASAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqASASLoop );
	END ENeqASAS;

(** INTEGER*)
	PROCEDURE ENeqAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAIAILoop;

	PROCEDURE ENeqAIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqAIAILoop );
	END ENeqAIAI;

(** LONGINT*)
	PROCEDURE ENeqALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqALALLoop;

	PROCEDURE ENeqALAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqALALLoop );
	END ENeqALAL;

(** REAL *)
	PROCEDURE ENeqARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqARARLoop;

	PROCEDURE ENeqARAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											    CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqARARLoop );
	END ENeqARAR;

(** LONGREAL *)
	PROCEDURE ENeqAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval # rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ENeqAXAXLoop;

	PROCEDURE ENeqAXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqAXAXLoop );
	END ENeqAXAX;

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

	PROCEDURE ENeqABSB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											    CONST left: ARRAY [ ? ] OF BOOLEAN;
											    right: BOOLEAN );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqABSBLoop );
	END ENeqABSB;

	PROCEDURE ENeqSBAB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											    left: BOOLEAN;
											    CONST right: ARRAY [ ? ] OF BOOLEAN );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqABSBLoop );
	END ENeqSBAB;

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

	PROCEDURE ENeqASSS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left: ARRAY [ ? ] OF SHORTINT;
											   right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqASSSLoop );
	END ENeqASSS;

	PROCEDURE ENeqSSAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   left: SHORTINT;
											   CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqASSSLoop );
	END ENeqSSAS;

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

	PROCEDURE ENeqAISI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqAISILoop );
	END ENeqAISI;

	PROCEDURE ENeqSIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: INTEGER;
											  CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqAISILoop );
	END ENeqSIAI;

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

	PROCEDURE ENeqALSL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF LONGINT;
											  right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqALSLLoop );
	END ENeqALSL;

	PROCEDURE ENeqSLAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: LONGINT;
											  CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqALSLLoop );
	END ENeqSLAL;

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

	PROCEDURE ENeqARSR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											    CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqARSRLoop );
	END ENeqARSR;

	PROCEDURE ENeqSRAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: REAL;
											    CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqARSRLoop );
	END ENeqSRAR;

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

	PROCEDURE ENeqAXSX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left: ARRAY [ ? ] OF LONGREAL;
											   right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ENeqAXSXLoop );
	END ENeqAXSX;

	PROCEDURE ENeqSXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   left: LONGREAL;
											   CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ENeqAXSXLoop );
	END ENeqSXAX;


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

	PROCEDURE EGtrASAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrASASLoop );
	END EGtrASAS;

(** INTEGER *)
	PROCEDURE EGtrAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAIAILoop;

	PROCEDURE EGtrAIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
										    CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrAIAILoop );
	END EGtrAIAI;

(** LONGINT *)
	PROCEDURE EGtrALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrALALLoop;

	PROCEDURE EGtrALAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrALALLoop );
	END EGtrALAL;

(** REAL *)
	PROCEDURE EGtrARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrARARLoop;

	PROCEDURE EGtrARAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrARARLoop );
	END EGtrARAR;

(** LONGREAL *)
	PROCEDURE EGtrAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval > rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGtrAXAXLoop;

	PROCEDURE EGtrAXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrAXAXLoop );
	END EGtrAXAX;

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

	PROCEDURE EGtrASSS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left: ARRAY [ ? ] OF SHORTINT;
											 right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrASSSLoop );
	END EGtrASSS;

	PROCEDURE ELssSSAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  left: SHORTINT;
											  CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrASSSLoop );
	END ELssSSAS;

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

	PROCEDURE EGtrAISI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
										    CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrAISILoop );
	END EGtrAISI;

	PROCEDURE ELssSIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: INTEGER;
											 CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrAISILoop );
	END ELssSIAI;

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

	PROCEDURE EGtrALSL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left: ARRAY [ ? ] OF LONGINT;
											 right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrALSLLoop );
	END EGtrALSL;

	PROCEDURE ELssSLAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: LONGINT;
											 CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrALSLLoop );
	END ELssSLAL;

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

	PROCEDURE EGtrARSR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrARSRLoop );
	END EGtrARSR;

	PROCEDURE ELssSRAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: REAL;
											   CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrARSRLoop );
	END ELssSRAR;

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

	PROCEDURE EGtrAXSX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left: ARRAY [ ? ] OF LONGREAL;
											 right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGtrAXSXLoop );
	END EGtrAXSX;

	PROCEDURE ELssSXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  left: LONGREAL;
											  CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGtrAXSXLoop );
	END ELssSXAX;


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

	PROCEDURE EGeqASAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqASASLoop );
	END EGeqASAS;

(** INTEGER *)
	PROCEDURE EGeqAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAIAILoop;

	PROCEDURE EGeqAIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqAIAILoop );
	END EGeqAIAI;

(** LONGINT *)
	PROCEDURE EGeqALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqALALLoop;

	PROCEDURE EGeqALAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqALALLoop );
	END EGeqALAL;

(** REAL *)
	PROCEDURE EGeqARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqARARLoop;

	PROCEDURE EGeqARAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqARARLoop );
	END EGeqARAR;

(** LONGREAL *)
	PROCEDURE EGeqAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval >= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END EGeqAXAXLoop;

	PROCEDURE EGeqAXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqAXAXLoop );
	END EGeqAXAX;

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

	PROCEDURE EGeqASSS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left: ARRAY [ ? ] OF SHORTINT;
											   right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqASSSLoop );
	END EGeqASSS;

	PROCEDURE ELeqSSAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  left: SHORTINT;
											  CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqASSSLoop );
	END ELeqSSAS;

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

	PROCEDURE EGeqAISI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqAISILoop );
	END EGeqAISI;

	PROCEDURE ELeqSIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: INTEGER;
											 CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqAISILoop );
	END ELeqSIAI;

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

	PROCEDURE EGeqALSL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF LONGINT;
											  right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqALSLLoop );
	END EGeqALSL;

	PROCEDURE ELeqSLAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: LONGINT;
											 CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqALSLLoop );
	END ELeqSLAL;

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

	PROCEDURE EGeqARSR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqARSRLoop );
	END EGeqARSR;

	PROCEDURE ELeqSRAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: REAL;
											   CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqARSRLoop );
	END ELeqSRAR;

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

	PROCEDURE EGeqAXSX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left: ARRAY [ ? ] OF LONGREAL;
											   right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), EGeqAXSXLoop );
	END EGeqAXSX;

	PROCEDURE ELeqSXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  left: LONGREAL;
											  CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), EGeqAXSXLoop );
	END ELeqSXAX;

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

	PROCEDURE ELssASAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssASASLoop );
	END ELssASAS;

(** INTEGER *)
	PROCEDURE ELssAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssAIAILoop;

	PROCEDURE ELssAIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssAIAILoop );
	END ELssAIAI;

(** LONGINT*)
	PROCEDURE ELssALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssALALLoop;

	PROCEDURE ELssALAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssALALLoop );
	END ELssALAL;

(** REAL *)
	PROCEDURE ELssARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssARARLoop;

	PROCEDURE ELssARAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssARARLoop );
	END ELssARAR;

(** LONGREAL *)
	PROCEDURE ELssAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval < rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELssAXAXLoop;

	PROCEDURE ELssAXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssAXAXLoop );
	END ELssAXAX;

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

	PROCEDURE ELssASSS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF SHORTINT;
											  right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssASSSLoop );
	END ELssASSS;

	PROCEDURE EGtrSSAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 left: SHORTINT;
											 CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssASSSLoop );
	END EGtrSSAS;

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

	PROCEDURE ELssAISI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssAISILoop );
	END ELssAISI;

	PROCEDURE EGtrSIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: INTEGER;
										    CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssAISILoop );
	END EGtrSIAI;

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

	PROCEDURE ELssALSL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left: ARRAY [ ? ] OF LONGINT;
											 right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssALSLLoop );
	END ELssALSL;

	PROCEDURE EGtrSLAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: LONGINT;
											 CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssALSLLoop );
	END EGtrSLAL;

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

	PROCEDURE ELssARSR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssARSRLoop );
	END ELssARSR;

	PROCEDURE EGtrSRAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: REAL;
											  CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssARSRLoop );
	END EGtrSRAR;

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

	PROCEDURE ELssAXSX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF LONGREAL;
											  right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELssAXSXLoop );
	END ELssAXSX;

	PROCEDURE EGtrSXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 left: LONGREAL;
											 CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELssAXSXLoop );
	END EGtrSXAX;


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

	PROCEDURE ELeqASAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqASASLoop );
	END ELeqASAS;

(** INTEGER *)
	PROCEDURE ELeqAIAILoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAIAILoop;

	PROCEDURE ELeqAIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqAIAILoop );
	END ELeqAIAI;

(** LONGINT *)
	PROCEDURE ELeqALALLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqALALLoop;

	PROCEDURE ELeqALAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqALALLoop );
	END ELeqALAL;

(** REAL  *)
	PROCEDURE ELeqARARLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqARARLoop;

	PROCEDURE ELeqARAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqARARLoop );
	END ELeqARAR;

(** LONGREAL*)
	PROCEDURE ELeqAXAXLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval <= rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ELeqAXAXLoop;

	PROCEDURE ELeqAXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqAXAXLoop );
	END ELeqAXAX;

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

	PROCEDURE ELeqASSS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF SHORTINT;
											  right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqASSSLoop );
	END ELeqASSS;

	PROCEDURE EGeqSSAS*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   left: SHORTINT;
											   CONST right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqASSSLoop );
	END EGeqSSAS;

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

	PROCEDURE ELeqAISI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left: ARRAY [ ? ] OF INTEGER;  right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqAISILoop );
	END ELeqAISI;

	PROCEDURE EGeqSIAI*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: INTEGER;
											 CONST right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqAISILoop );
	END EGeqSIAI;

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

	PROCEDURE ELeqALSL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											 CONST left: ARRAY [ ? ] OF LONGINT;
											 right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqALSLLoop );
	END ELeqALSL;

	PROCEDURE EGeqSLAL*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: LONGINT;
											  CONST right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqALSLLoop );
	END EGeqSLAL;

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

	PROCEDURE ELeqARSR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqARSRLoop );
	END ELeqARSR;

	PROCEDURE EGeqSRAR*( VAR dest: ARRAY [ ? ] OF BOOLEAN;  left: REAL;
											   CONST right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqARSRLoop );
	END EGeqSRAR;

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

	PROCEDURE ELeqAXSX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF LONGREAL;
											  right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ELeqAXSXLoop );
	END ELeqAXSX;

	PROCEDURE EGeqSXAX*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											   left: LONGREAL;
											   CONST right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ELeqAXSXLoop );
	END EGeqSXAX;


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

	PROCEDURE ElOrABAB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left, right: ARRAY [ ? ] OF BOOLEAN );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ElOrABABLoop );
	END ElOrABAB;

	PROCEDURE ElAndABABLoop( ladr, radr, dadr, linc, rinc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval & rval );
			INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );
		END;
	END ElAndABABLoop;

	PROCEDURE ElAndABAB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
												CONST left, right: ARRAY [ ? ] OF BOOLEAN );
	BEGIN
		ApplyBinaryAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ElAndABABLoop );
	END ElAndABAB;

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

	PROCEDURE ElOrABSB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  CONST left: ARRAY [ ? ] OF BOOLEAN;
											  right: BOOLEAN );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ElOrABSBLoop );
	END ElOrABSB;

	PROCEDURE ElOrSBAB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
											  left: BOOLEAN;
											  CONST right: ARRAY [ ? ] OF BOOLEAN );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ElOrABSBLoop );
	END ElOrSBAB;

	PROCEDURE ElAndABSBLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR lval, rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, lval & rval );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END ElAndABSBLoop;

	PROCEDURE ElAndABSB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
												CONST left: ARRAY [ ? ] OF BOOLEAN;
												right: BOOLEAN );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( BOOLEAN ), ElAndABSBLoop );
	END ElAndABSB;

	PROCEDURE ElAndSBAB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
												left: BOOLEAN;
												CONST right: ARRAY [ ? ] OF BOOLEAN );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( right ), ADDRESSOF( left ),
										  SIZEOF( BOOLEAN ), ElAndABSBLoop );
	END ElAndSBAB;


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

	PROCEDURE LssASAS*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssASASLoop );
	END LssASAS;

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

	PROCEDURE GeqASAS*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqASASLoop );
	END GeqASAS;

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

	PROCEDURE LssAIAI*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssAIAILoop );
	END LssAIAI;

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

	PROCEDURE GeqAIAI*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqAIAILoop );
	END GeqAIAI;

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

	PROCEDURE LssALAL*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssALALLoop );
	END LssALAL;

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

	PROCEDURE GeqALAL*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqALALLoop );
	END GeqALAL;

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

	PROCEDURE LssARAR*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssARARLoop );
	END LssARAR;

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

	PROCEDURE GeqARAR*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqARARLoop );
	END GeqARAR;

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

	PROCEDURE LssAXAX*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LssAXAXLoop );
	END LssAXAX;

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

	PROCEDURE GeqAXAX*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqAXAXLoop );
	END GeqAXAX;

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

	PROCEDURE GtrASAS*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrASASLoop );
	END GtrASAS;

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

	PROCEDURE LeqASAS*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqASASLoop );
	END LeqASAS;

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

	PROCEDURE GtrAIAI*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrAIAILoop );
	END GtrAIAI;

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

	PROCEDURE LeqAIAI*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqAIAILoop );
	END LeqAIAI;

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

	PROCEDURE GtrALAL*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrALALLoop );
	END GtrALAL;

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

	PROCEDURE LeqALAL*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqALALLoop );
	END LeqALAL;

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

	PROCEDURE GtrARAR*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrARARLoop );
	END GtrARAR;

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

	PROCEDURE LeqARAR*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqARARLoop );
	END LeqARAR;

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

	PROCEDURE GtrAXAX*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrAXAXLoop );
	END GtrAXAX;

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

	PROCEDURE LeqAXAX*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqAXAXLoop );
	END LeqAXAX;


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

	PROCEDURE EqlABAB*( CONST left, right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlABABLoop );
	END EqlABAB;

	PROCEDURE NeqABAB*( CONST left, right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlABABLoop );
	END NeqABAB;

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

	PROCEDURE EqlASAS*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlASASLoop );
	END EqlASAS;

	PROCEDURE NeqASAS*( CONST left, right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlASASLoop );
	END NeqASAS;

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

	PROCEDURE EqlAIAI*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAIAILoop );
	END EqlAIAI;

	PROCEDURE NeqAIAI*( CONST left, right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAIAILoop );
	END NeqAIAI;

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

	PROCEDURE EqlALAL*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlALALLoop );
	END EqlALAL;

	PROCEDURE NeqALAL*( CONST left, right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlALALLoop );
	END NeqALAL;

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

	PROCEDURE EqlARAR*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlARARLoop );
	END EqlARAR;

	PROCEDURE NeqARAR*( CONST left, right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlARARLoop );
	END NeqARAR;

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

	PROCEDURE EqlAXAX*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAXAXLoop );
	END EqlAXAX;

	PROCEDURE NeqAXAX*( CONST left, right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ~ApplyBinaryAABOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAXAXLoop );
	END NeqAXAX;

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

	PROCEDURE EqlABSB*( CONST left: ARRAY [ ? ] OF BOOLEAN;
											right: BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlABSBLoop );
	END EqlABSB;

	PROCEDURE EqlSBAB*( left: BOOLEAN;
											CONST right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlABSBLoop );
	END EqlSBAB;

	PROCEDURE NeqABSB*( CONST left: ARRAY [ ? ] OF BOOLEAN;
											  right: BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ~EqlABSB( left, right );
	END NeqABSB;

	PROCEDURE NeqSBAB*( left: BOOLEAN;
											  CONST right: ARRAY [ ? ] OF BOOLEAN ): BOOLEAN;
	BEGIN
		RETURN ~EqlSBAB( left, right );
	END NeqSBAB;

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

	PROCEDURE EqlASSS*( CONST left: ARRAY [ ? ] OF SHORTINT;
										    right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlASSSLoop );
	END EqlASSS;

	PROCEDURE EqlSSAS*( left: SHORTINT;
										    CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlASSSLoop );
	END EqlSSAS;

	PROCEDURE NeqASSS*( CONST left: ARRAY [ ? ] OF SHORTINT;
											 right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ~EqlASSS( left, right );
	END NeqASSS;

	PROCEDURE NeqSSAS*( left: SHORTINT;
											 CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ~EqlSSAS( left, right );
	END NeqSSAS;

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

	PROCEDURE EqlAISI*( CONST left: ARRAY [ ? ] OF INTEGER;
										  right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAISILoop );
	END EqlAISI;

	PROCEDURE EqlSIAI*( left: INTEGER;
										  CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlAISILoop );
	END EqlSIAI;

	PROCEDURE NeqAISI*( CONST left: ARRAY [ ? ] OF INTEGER;
										    right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ~EqlAISI( left, right );
	END NeqAISI;

	PROCEDURE NeqSIAI*( left: INTEGER;
										    CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ~EqlSIAI( left, right );
	END NeqSIAI;

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

	PROCEDURE EqlALSL*( CONST left: ARRAY [ ? ] OF LONGINT;
										   right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlALSLLoop );
	END EqlALSL;

	PROCEDURE EqlSLAL*( left: LONGINT;
										   CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlALSLLoop );
	END EqlSLAL;

	PROCEDURE NeqALSL*( CONST left: ARRAY [ ? ] OF LONGINT;
											right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ~EqlALSL( left, right );
	END NeqALSL;

	PROCEDURE NeqSLAL*( left: LONGINT;
											CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ~EqlSLAL( left, right );
	END NeqSLAL;

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

	PROCEDURE EqlARSR*( CONST left: ARRAY [ ? ] OF REAL;
											right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlARSRLoop );
	END EqlARSR;

	PROCEDURE EqlSRAR*( left: REAL;
											CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlARSRLoop );
	END EqlSRAR;

	PROCEDURE NeqARSR*( CONST left: ARRAY [ ? ] OF REAL;
											  right: REAL ): BOOLEAN;
	BEGIN
		RETURN ~EqlARSR( left, right );
	END NeqARSR;

	PROCEDURE NeqSRAR*( left: REAL;
											  CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ~EqlSRAR( left, right );
	END NeqSRAR;

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

	PROCEDURE EqlAXSX*( CONST left: ARRAY [ ? ] OF LONGREAL;
										    right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), EqlAXSXLoop );
	END EqlAXSX;

	PROCEDURE EqlSXAX*( left: LONGREAL;
										    CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), EqlAXSXLoop );
	END EqlSXAX;

	PROCEDURE NeqAXSX*( CONST left: ARRAY [ ? ] OF LONGREAL;
											 right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ~EqlAXSX( left, right );
	END NeqAXSX;

	PROCEDURE NeqSXAX*( left: LONGREAL;
											 CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ~EqlSXAX( left, right );
	END NeqSXAX;


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

	PROCEDURE GtrASSS*( CONST left: ARRAY [ ? ] OF SHORTINT;
										   right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrASSSLoop );
	END GtrASSS;

	PROCEDURE LssSSAS*( left: SHORTINT;
										    CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrASSSLoop );
	END LssSSAS;

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

	PROCEDURE GtrAISI*( CONST left: ARRAY [ ? ] OF INTEGER;
										  right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrAISILoop );
	END GtrAISI;

	PROCEDURE LssSIAI*( left: INTEGER;
										   CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrAISILoop );
	END LssSIAI;

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

	PROCEDURE GtrALSL*( CONST left: ARRAY [ ? ] OF LONGINT;
										   right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrALSLLoop );
	END GtrALSL;

	PROCEDURE LssSLAL*( left: LONGINT;
										   CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrALSLLoop );
	END LssSLAL;

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

	PROCEDURE GtrARSR*( CONST left: ARRAY [ ? ] OF REAL;
										    right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrARSRLoop );
	END GtrARSR;

	PROCEDURE LssSRAR*( left: REAL;
											 CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrARSRLoop );
	END LssSRAR;

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

	PROCEDURE GtrAXSX*( CONST left: ARRAY [ ? ] OF LONGREAL;
										   right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GtrAXSXLoop );
	END GtrAXSX;

	PROCEDURE LssSXAX*( left: LONGREAL;
										    CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GtrAXSXLoop );
	END LssSXAX;

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

	PROCEDURE GeqASSS*( CONST left: ARRAY [ ? ] OF SHORTINT;
											 right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqASSSLoop );
	END GeqASSS;

	PROCEDURE LeqSSAS*( left: SHORTINT;
										    CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqASSSLoop );
	END LeqSSAS;

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

	PROCEDURE GeqAISI*( CONST left: ARRAY [ ? ] OF INTEGER;
										   right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqAISILoop );
	END GeqAISI;

	PROCEDURE LeqSIAI*( left: INTEGER;
										   CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqAISILoop );
	END LeqSIAI;

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

	PROCEDURE GeqALSL*( CONST left: ARRAY [ ? ] OF LONGINT;
										    right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqALSLLoop );
	END GeqALSL;

	PROCEDURE LeqSLAL*( left: LONGINT;
										   CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqALSLLoop );
	END LeqSLAL;

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

	PROCEDURE GeqARSR*( CONST left: ARRAY [ ? ] OF REAL;
											 right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqARSRLoop );
	END GeqARSR;

	PROCEDURE LeqSRAR*( left: REAL;
											 CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqARSRLoop );
	END LeqSRAR;

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

	PROCEDURE GeqAXSX*( CONST left: ARRAY [ ? ] OF LONGREAL;
											 right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), GeqAXSXLoop );
	END GeqAXSX;

	PROCEDURE LeqSXAX*( left: LONGREAL;
										    CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), GeqAXSXLoop );
	END LeqSXAX;

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

	PROCEDURE LeqASSS*( CONST left: ARRAY [ ? ] OF SHORTINT;
										    right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqASSSLoop );
	END LeqASSS;

	PROCEDURE GeqSSAS*( left: SHORTINT;
											 CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqASSSLoop );
	END GeqSSAS;

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

	PROCEDURE LeqAISI*( CONST left: ARRAY [ ? ] OF INTEGER;
										   right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqAISILoop );
	END LeqAISI;

	PROCEDURE GeqSIAI*( left: INTEGER;
										   CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqAISILoop );
	END GeqSIAI;

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

	PROCEDURE LeqALSL*( CONST left: ARRAY [ ? ] OF LONGINT;
										   right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqALSLLoop );
	END LeqALSL;

	PROCEDURE GeqSLAL*( left: LONGINT;
										    CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqALSLLoop );
	END GeqSLAL;

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

	PROCEDURE LeqARSR*( CONST left: ARRAY [ ? ] OF REAL;
											 right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqARSRLoop );
	END LeqARSR;

	PROCEDURE GeqSRAR*( left: REAL;
											 CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqARSRLoop );
	END GeqSRAR;

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

	PROCEDURE LeqAXSX*( CONST left: ARRAY [ ? ] OF LONGREAL;
										    right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LeqAXSXLoop );
	END LeqAXSX;

	PROCEDURE GeqSXAX*( left: LONGREAL;
											 CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LeqAXSXLoop );
	END GeqSXAX;



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

	PROCEDURE LssASSS*( CONST left: ARRAY [ ? ] OF SHORTINT;
										    right: SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssASSSLoop );
	END LssASSS;

	PROCEDURE GtrSSAS*( left: SHORTINT;
										   CONST right: ARRAY [ ? ] OF SHORTINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssASSSLoop );
	END GtrSSAS;

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

	PROCEDURE LssAISI*( CONST left: ARRAY [ ? ] OF INTEGER;
										   right: INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssAISILoop );
	END LssAISI;

	PROCEDURE GtrSIAI*( left: INTEGER;
										  CONST right: ARRAY [ ? ] OF INTEGER ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssAISILoop );
	END GtrSIAI;

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

	PROCEDURE LssALSL*( CONST left: ARRAY [ ? ] OF LONGINT;
										   right: LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssALSLLoop );
	END LssALSL;

	PROCEDURE GtrSLAL*( left: LONGINT;
										   CONST right: ARRAY [ ? ] OF LONGINT ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssALSLLoop );
	END GtrSLAL;

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

	PROCEDURE LssARSR*( CONST left: ARRAY [ ? ] OF REAL;
											 right: REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssARSRLoop );
	END LssARSR;

	PROCEDURE GtrSRAR*( left: REAL;
										    CONST right: ARRAY [ ? ] OF REAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssARSRLoop );
	END GtrSRAR;

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

	PROCEDURE LssAXSX*( CONST left: ARRAY [ ? ] OF LONGREAL;
										    right: LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( left ), ADDRESSOF( right ), LssAXSXLoop );
	END LssAXSX;

	PROCEDURE GtrSXAX*( left: LONGREAL;
										   CONST right: ARRAY [ ? ] OF LONGREAL ): BOOLEAN;
	BEGIN
		RETURN ApplyBinaryASBOp( ADDRESSOF( right ), ADDRESSOF( left ), LssAXSXLoop );
	END GtrSXAX;

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

	PROCEDURE MinAS*( CONST left: ARRAY [ ? ] OF SHORTINT ): SHORTINT;
	TYPE Type = SHORTINT;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinASLoop );  RETURN val;
	END MinAS;

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

	PROCEDURE MinAI*( CONST left: ARRAY [ ? ] OF INTEGER ): INTEGER;
	TYPE Type = INTEGER;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinAILoop );  RETURN val;
	END MinAI;

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

	PROCEDURE MinAL*( CONST left: ARRAY [ ? ] OF LONGINT ): LONGINT;
	TYPE Type = LONGINT;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinALLoop );  RETURN val;
	END MinAL;

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

	PROCEDURE MinAR*( CONST left: ARRAY [ ? ] OF REAL ): REAL;
	TYPE Type = REAL;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinARLoop );  RETURN val;
	END MinAR;

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

	PROCEDURE MinAX*( CONST left: ARRAY [ ? ] OF LONGREAL ): LONGREAL;
	TYPE Type = LONGREAL;
	VAR val: Type;
	BEGIN
		val := MAX( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MinAXLoop );  RETURN val;
	END MinAX;

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

	PROCEDURE MaxAS*( CONST left: ARRAY [ ? ] OF SHORTINT ): SHORTINT;
	TYPE Type = SHORTINT;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxASLoop );  RETURN val;
	END MaxAS;

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

	PROCEDURE MaxAI*( CONST left: ARRAY [ ? ] OF INTEGER ): INTEGER;
	TYPE Type = INTEGER;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxAILoop );  RETURN val;
	END MaxAI;

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

	PROCEDURE MaxAL*( CONST left: ARRAY [ ? ] OF LONGINT ): LONGINT;
	TYPE Type = LONGINT;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxALLoop );  RETURN val;
	END MaxAL;

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

	PROCEDURE MaxAR*( CONST left: ARRAY [ ? ] OF REAL ): REAL;
	TYPE Type = REAL;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxARLoop );  RETURN val;
	END MaxAR;

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

	PROCEDURE MaxAX*( CONST left: ARRAY [ ? ] OF LONGREAL ): LONGREAL;
	TYPE Type = LONGREAL;
	VAR val: Type;
	BEGIN
		val := MIN( Type );
		ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), MaxAXLoop );  RETURN val;
	END MaxAX;

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

	PROCEDURE SumAS*( CONST left: ARRAY [ ? ] OF SHORTINT ): SHORTINT;
	TYPE Type = SHORTINT;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumASLoop );
		RETURN val;
	END SumAS;

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

	PROCEDURE SumAI*( CONST left: ARRAY [ ? ] OF INTEGER ): INTEGER;
	TYPE Type = INTEGER;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumAILoop );
		RETURN val;
	END SumAI;

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

	PROCEDURE SumAL*( CONST left: ARRAY [ ? ] OF LONGINT ): LONGINT;
	TYPE Type = LONGINT;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumALLoop );
		RETURN val;
	END SumAL;

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

	PROCEDURE SumAR*( CONST left: ARRAY [ ? ] OF REAL ): REAL;
	TYPE Type = REAL;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumARLoop );
		RETURN val;
	END SumAR;

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

	PROCEDURE SumAX*( CONST left: ARRAY [ ? ] OF LONGREAL ): LONGREAL;
	TYPE Type = LONGREAL;
	VAR val: Type;
	BEGIN
		val := 0;  ApplyUnaryASOp( ADDRESSOF( val ), ADDRESSOF( left ), SumAXLoop );
		RETURN val;
	END SumAX;



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

	PROCEDURE AbsAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
										CONST src: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( SHORTINT ), AbsLoopS );
	END AbsAS;

(** INTEGER *)
	PROCEDURE AbsLoopI( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: INTEGER;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopI;

	PROCEDURE AbsAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
									    CONST src: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( INTEGER ), AbsLoopI );
	END AbsAI;

(** LONGINT *)
	PROCEDURE AbsLoopL( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGINT;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopL;

	PROCEDURE AbsAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
									    CONST src: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGINT ), AbsLoopL );
	END AbsAL;

(** REAL *)
	PROCEDURE AbsLoopR( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: REAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopR;

	PROCEDURE AbsAR*( VAR dest: ARRAY [ ? ] OF REAL;
										 CONST src: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( REAL ), AbsLoopR );
	END AbsAR;

(** LONGREAL *)
	PROCEDURE AbsLoopX( ladr, dadr, linc, dinc, len: LONGINT );
	VAR lval: LONGREAL;
	BEGIN
		WHILE (len > 0) DO
			SYSTEM.GET( ladr, lval );  SYSTEM.PUT( dadr, ABS( lval ) );  INC( ladr, linc );
			INC( dadr, dinc );  DEC( len );
		END;
	END AbsLoopX;

	PROCEDURE AbsAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
										CONST src: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyUnaryAAOp( ADDRESSOF( dest ), ADDRESSOF( src ), SIZEOF( LONGREAL ), AbsLoopX );
	END AbsAX;

	(*** assign number to array  (initialisation) ********************************************************************)

(** BOOLEAN *)
	PROCEDURE AssignABSBLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR rval: BOOLEAN;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, rval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignABSBLoop;

	PROCEDURE AssignABSB*( VAR dest: ARRAY [ ? ] OF BOOLEAN;
												  CONST left: ARRAY [ ? ] OF BOOLEAN;
												  right: BOOLEAN );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), AssignABSBLoop );
	END AssignABSB;


(** SHORTINT*)
	PROCEDURE AssignASSSLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR rval: SHORTINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, rval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignASSSLoop;

	PROCEDURE AssignASSS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
												  CONST left: ARRAY [ ? ] OF SHORTINT;
												  right: SHORTINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), AssignASSSLoop );
	END AssignASSS;

(**INTEGER *)
	PROCEDURE AssignAISILoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR rval: INTEGER;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, rval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignAISILoop;

	PROCEDURE AssignAISI*( VAR dest: ARRAY [ ? ] OF INTEGER;
												CONST left: ARRAY [ ? ] OF INTEGER;
												right: INTEGER );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), AssignAISILoop );
	END AssignAISI;

(** LONGINT *)
	PROCEDURE AssignALSLLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR rval: LONGINT;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, rval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignALSLLoop;

	PROCEDURE AssignALSL*( VAR dest: ARRAY [ ? ] OF LONGINT;
												 CONST left: ARRAY [ ? ] OF LONGINT;
												 right: LONGINT );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), AssignALSLLoop );
	END AssignALSL;

(** REAL *)
	PROCEDURE AssignARSRLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR rval: REAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, rval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignARSRLoop;

	PROCEDURE AssignARSR*( VAR dest: ARRAY [ ? ] OF REAL;
												  CONST left: ARRAY [ ? ] OF REAL;  right: REAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  AssignARSRLoop );
	END AssignARSR;

(** LONGREAL *)
	PROCEDURE AssignAXSXLoop( ladr, radr, dadr, linc, dinc, len: LONGINT );
	VAR rval: LONGREAL;
	BEGIN
		SYSTEM.GET( radr, rval );
		WHILE (len > 0) DO SYSTEM.PUT( dadr, rval );  INC( dadr, dinc );  DEC( len );  END;
	END AssignAXSXLoop;

	PROCEDURE AssignAXSX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
												  CONST left: ARRAY [ ? ] OF LONGREAL;
												  right: LONGREAL );
	BEGIN
		ApplyBinaryASAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), AssignAXSXLoop );
	END AssignAXSX;

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

		incL := GetInc( left, 1 );  strideL := GetInc( left, 0 );   (* increment and stride of left matrix *)
		incR := GetInc( right, 1 );  strideR := GetInc( right, 0 );   (* increment and stride of right matrix *)
		incD := GetInc( dest, 1 );  strideD := GetInc( dest, 0 );   (* increment and stride of dest matrix *)

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
		li0 := GetInc( left, 1 );  li1 := GetInc( left, 0 );  ri0 := GetInc( right, 0 );
		di0 := GetInc( dest, 0 );

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
		li0 := GetInc( left, 0 );  ri0 := GetInc( right, 1 );  ri1 := GetInc( right, 0 );
		di0 := GetInc( dest, 0 );

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

	PROCEDURE MatMulASAS*( VAR dest: ARRAY [ * , * ] OF SHORTINT;
												   CONST left, right: ARRAY [ * , * ] OF SHORTINT );
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( SHORTINT ), MatMulASASLoop, NIL );
	END MatMulASAS;

	PROCEDURE MatVecMulASAS*( VAR dest: ARRAY [ * ] OF SHORTINT;
														 CONST left: ARRAY [ * , * ] OF SHORTINT;
														 CONST right: ARRAY [ * ] OF SHORTINT );
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulASASLoop, NIL );
	END MatVecMulASAS;

	PROCEDURE VecMatMulASAS*( VAR dest: ARRAY [ * ] OF SHORTINT;
														 CONST left: ARRAY [ * ] OF SHORTINT;
														 CONST right: ARRAY [ * , * ] OF SHORTINT );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulASASLoop, NIL );
	END VecMatMulASAS;

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

	PROCEDURE MatMulAIAI*( VAR dest: ARRAY [ * , * ] OF INTEGER;
												  CONST left, right: ARRAY [ * , * ] OF INTEGER );
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( INTEGER ), MatMulAIAILoop, NIL );
	END MatMulAIAI;

	PROCEDURE MatVecMulAIAI*( VAR dest: ARRAY [ * ] OF INTEGER;
													    CONST left: ARRAY [ * , * ] OF INTEGER;
													    CONST right: ARRAY [ * ] OF INTEGER );
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulAIAILoop, NIL );
	END MatVecMulAIAI;

	PROCEDURE VecMatMulAIAI*( VAR dest: ARRAY [ * ] OF INTEGER;
													    CONST left: ARRAY [ * ] OF INTEGER;
													    CONST right: ARRAY [ * , * ] OF INTEGER );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulAIAILoop, NIL );
	END VecMatMulAIAI;

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

	PROCEDURE MatMulALAL*( VAR dest: ARRAY [ * , * ] OF LONGINT;
												  CONST left, right: ARRAY [ * , * ] OF LONGINT );
	BEGIN
		(*
		KernelLog.String("MatMulALAL");
		KernelLog.Int(SYSTEM.VAL(LONGINT,dest),10);
		KernelLog.Int(SYSTEM.VAL(LONGINT,left),10);
		KernelLog.Int(SYSTEM.VAL(LONGINT,right),10);
		KernelLog.Ln;
		*)

		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGINT ), MatMulALALLoop, NIL );
	END MatMulALAL;

	PROCEDURE MatVecMulALAL*( VAR dest: ARRAY [ * ] OF LONGINT;
														CONST left: ARRAY [ * , * ] OF LONGINT;
														CONST right: ARRAY [ * ] OF LONGINT );
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulALALLoop, NIL );
	END MatVecMulALAL;

	PROCEDURE VecMatMulALAL*( VAR dest: ARRAY [ * ] OF LONGINT;
														CONST left: ARRAY [ * ] OF LONGINT;
														CONST right: ARRAY [ * , * ] OF LONGINT );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulALALLoop, NIL );
	END VecMatMulALAL;

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
	PROCEDURE MatMulARAR*( VAR dest: ARRAY [ * , * ] OF REAL;
										   CONST left, right: ARRAY [ * , * ] OF REAL );
	VAR flags: SET; dadr, ladr, radr: LONGINT;
	BEGIN

		dadr := SYSTEM.GET32(ADDRESSOF(dest)+adroffs);
		ladr := SYSTEM.GET32(ADDRESSOF(left)+adroffs);
		radr := SYSTEM.GET32(ADDRESSOF(right)+adroffs);

		(* account possible inplace left := left*right, right := left*right, left := left*left, right := right*right *)
		IF (ladr # dadr) & (radr # dadr) THEN

			flags := SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(left)+flagoffs)) * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(right)+flagoffs));

			CASE SYSTEM.VAL(LONGINT,flags) OF

				Mat2x2:
					IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Mat2x2 THEN
						IF dadr = 0 THEN NEW(dest,2,2);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulR2x2 # NIL THEN matMulR2x2(dadr,ladr,radr);
					ELSE
						dest[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0];
						dest[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1];
						dest[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0];
						dest[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1];
					END;

				|Mat3x3:
					IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Mat3x3 THEN
						IF dadr = 0 THEN NEW(dest,3,3);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulR3x3 # NIL THEN matMulR3x3(dadr,ladr,radr);
					ELSE
						dest[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0];
						dest[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1];
						dest[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2];

						dest[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0];
						dest[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1];
						dest[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2];

						dest[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0];
						dest[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1];
						dest[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2];
					END;


				|Mat4x4:
					IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Mat4x4 THEN
						IF dadr = 0 THEN NEW(dest,4,4);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulR4x4 # NIL THEN matMulR4x4(dadr,ladr,radr);
					ELSE
						dest[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0] + left[0,3]*right[3,0];
						dest[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1] + left[0,3]*right[3,1];
						dest[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2] + left[0,3]*right[3,2];
						dest[0,3] := left[0,0]*right[0,3] + left[0,1]*right[1,3] + left[0,2]*right[2,3] + left[0,3]*right[3,3];

						dest[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0] + left[1,3]*right[3,0];
						dest[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1] + left[1,3]*right[3,1];
						dest[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2] + left[1,3]*right[3,2];
						dest[1,3] := left[1,0]*right[0,3] + left[1,1]*right[1,3] + left[1,2]*right[2,3] + left[1,3]*right[3,3];

						dest[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0] + left[2,3]*right[3,0];
						dest[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1] + left[2,3]*right[3,1];
						dest[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2] + left[2,3]*right[3,2];
						dest[2,3] := left[2,0]*right[0,3] + left[2,1]*right[1,3] + left[2,2]*right[2,3] + left[2,3]*right[3,3];

						dest[3,0] := left[3,0]*right[0,0] + left[3,1]*right[1,0] + left[3,2]*right[2,0] + left[3,3]*right[3,0];
						dest[3,1] := left[3,0]*right[0,1] + left[3,1]*right[1,1] + left[3,2]*right[2,1] + left[3,3]*right[3,1];
						dest[3,2] := left[3,0]*right[0,2] + left[3,1]*right[1,2] + left[3,2]*right[2,2] + left[3,3]*right[3,2];
						dest[3,3] := left[3,0]*right[0,3] + left[3,1]*right[1,3] + left[3,2]*right[2,3] + left[3,3]*right[3,3];
					END;
			ELSE
				ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
									    loopMatMulARAR, matMulR );
			END;
		ELSE
			ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
									    loopMatMulARAR, matMulR );
		END;
	END MatMulARAR;

	(*
		Optimized for small arrays (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	PROCEDURE MatVecMulARAR*( VAR dest: ARRAY [ * ] OF REAL;
												CONST left: ARRAY [ * , * ] OF REAL;
												CONST right: ARRAY [ * ] OF REAL );
	VAR
		flags: SET; dadr, ladr, radr: LONGINT;
		v0, v1, v2: REAL;
	BEGIN

		dadr := SYSTEM.GET32(ADDRESSOF(dest)+adroffs);
		ladr := SYSTEM.GET32(ADDRESSOF(left)+adroffs);
		radr := SYSTEM.GET32(ADDRESSOF(right)+adroffs);

		flags := SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(left)+flagoffs)) * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(right)+flagoffs));

		CASE SYSTEM.VAL(LONGINT,flags) OF

			MatVec2x2:
				IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Vec2 THEN
					IF dadr = 0 THEN NEW(dest,2);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulR2x2 # NIL THEN matVecMulR2x2(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0];
					dest[0] := left[0,0]*v0 + left[0,1]*right[1];
					dest[1] := left[1,0]*v0 + left[1,1]*right[1];
				END;

			|MatVec3x3:
				IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Vec3 THEN
					IF dadr = 0 THEN NEW(dest,3);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulR3x3 # NIL THEN matVecMulR3x3(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1];
					dest[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*right[2];
					dest[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*right[2];
					dest[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*right[2];
				END;

			|MatVec4x4:
				IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Vec4 THEN
					IF dadr = 0 THEN NEW(dest,4);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulR4x4 # NIL THEN matVecMulR4x4(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1]; v2 := right[2];
					dest[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*v2 + left[0,3]*right[3];
					dest[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*v2 + left[1,3]*right[3];
					dest[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*v2 + left[2,3]*right[3];
					dest[3] := left[3,0]*v0 + left[3,1]*v1 + left[3,2]*v2 + left[3,3]*right[3];
				END;

		ELSE
			ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulARAR, matMulR );
		END;
	END MatVecMulARAR;

	PROCEDURE VecMatMulARAR*( VAR dest: ARRAY [ * ] OF REAL;
														  CONST left: ARRAY [ * ] OF REAL;
														  CONST right: ARRAY [ * , * ] OF REAL );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulARAR, matMulR );
	END VecMatMulARAR;

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
	PROCEDURE MatMulAXAX*( VAR dest: ARRAY [ * , * ] OF LONGREAL;
										   CONST left, right: ARRAY [ * , * ] OF LONGREAL );
	VAR
		flags: SET; dadr, ladr, radr: LONGINT;
	BEGIN

		dadr := SYSTEM.GET32(ADDRESSOF(dest)+adroffs);
		ladr := SYSTEM.GET32(ADDRESSOF(left)+adroffs);
		radr := SYSTEM.GET32(ADDRESSOF(right)+adroffs);

		IF (ladr # dadr) & (radr # dadr) THEN

			flags := SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(left)+flagoffs)) * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(right)+flagoffs));

			CASE SYSTEM.VAL(LONGINT,flags) OF
				Mat2x2:
					IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Mat2x2 THEN
						IF dadr = 0 THEN NEW(dest,2,2);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulLR2x2 # NIL THEN matMulLR2x2(dadr,ladr,radr);
					ELSE
						dest[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0];
						dest[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1];
						dest[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0];
						dest[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1];
					END;

				|Mat3x3:
					IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Mat3x3 THEN
						IF dadr = 0 THEN NEW(dest,3,3);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulLR3x3 # NIL THEN matMulLR3x3(dadr,ladr,radr);
					ELSE
						dest[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0];
						dest[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1];
						dest[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2];

						dest[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0];
						dest[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1];
						dest[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2];

						dest[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0];
						dest[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1];
						dest[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2];
					END;


				|Mat4x4:
					IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Mat4x4 THEN
						IF dadr = 0 THEN NEW(dest,4,4);
						ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
						END;
					END;

					IF matMulLR4x4 # NIL THEN matMulLR4x4(dadr,ladr,radr);
					ELSE
						dest[0,0] := left[0,0]*right[0,0] + left[0,1]*right[1,0] + left[0,2]*right[2,0] + left[0,3]*right[3,0];
						dest[0,1] := left[0,0]*right[0,1] + left[0,1]*right[1,1] + left[0,2]*right[2,1] + left[0,3]*right[3,1];
						dest[0,2] := left[0,0]*right[0,2] + left[0,1]*right[1,2] + left[0,2]*right[2,2] + left[0,3]*right[3,2];
						dest[0,3] := left[0,0]*right[0,3] + left[0,1]*right[1,3] + left[0,2]*right[2,3] + left[0,3]*right[3,3];

						dest[1,0] := left[1,0]*right[0,0] + left[1,1]*right[1,0] + left[1,2]*right[2,0] + left[1,3]*right[3,0];
						dest[1,1] := left[1,0]*right[0,1] + left[1,1]*right[1,1] + left[1,2]*right[2,1] + left[1,3]*right[3,1];
						dest[1,2] := left[1,0]*right[0,2] + left[1,1]*right[1,2] + left[1,2]*right[2,2] + left[1,3]*right[3,2];
						dest[1,3] := left[1,0]*right[0,3] + left[1,1]*right[1,3] + left[1,2]*right[2,3] + left[1,3]*right[3,3];

						dest[2,0] := left[2,0]*right[0,0] + left[2,1]*right[1,0] + left[2,2]*right[2,0] + left[2,3]*right[3,0];
						dest[2,1] := left[2,0]*right[0,1] + left[2,1]*right[1,1] + left[2,2]*right[2,1] + left[2,3]*right[3,1];
						dest[2,2] := left[2,0]*right[0,2] + left[2,1]*right[1,2] + left[2,2]*right[2,2] + left[2,3]*right[3,2];
						dest[2,3] := left[2,0]*right[0,3] + left[2,1]*right[1,3] + left[2,2]*right[2,3] + left[2,3]*right[3,3];

						dest[3,0] := left[3,0]*right[0,0] + left[3,1]*right[1,0] + left[3,2]*right[2,0] + left[3,3]*right[3,0];
						dest[3,1] := left[3,0]*right[0,1] + left[3,1]*right[1,1] + left[3,2]*right[2,1] + left[3,3]*right[3,1];
						dest[3,2] := left[3,0]*right[0,2] + left[3,1]*right[1,2] + left[3,2]*right[2,2] + left[3,3]*right[3,2];
						dest[3,3] := left[3,0]*right[0,3] + left[3,1]*right[1,3] + left[3,2]*right[2,3] + left[3,3]*right[3,3];
					END;
			ELSE
				ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGREAL ),
									    loopMatMulAXAX, matMulX );
			END;
		ELSE
			ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( LONGREAL ),
									    loopMatMulAXAX, matMulX );
		END;
	END MatMulAXAX;

	(*
		Optimized for small arrays (Alexey Morozov)

		use of CONST for left, right makes execution slower, it seems that a new descriptor is created in this case
	*)
	PROCEDURE MatVecMulAXAX*( VAR dest: ARRAY [ * ] OF LONGREAL;
												CONST left: ARRAY [ * , * ] OF LONGREAL;
												CONST right: ARRAY [ * ] OF LONGREAL );
	VAR
		flags: SET; dadr, ladr, radr: LONGINT;
		v0, v1, v2: LONGREAL;
	BEGIN

		dadr := SYSTEM.GET32(ADDRESSOF(dest)+adroffs);
		ladr := SYSTEM.GET32(ADDRESSOF(left)+adroffs);
		radr := SYSTEM.GET32(ADDRESSOF(right)+adroffs);

		flags := SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(left)+flagoffs)) * SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(right)+flagoffs));

		CASE SYSTEM.VAL(LONGINT,flags) OF

			MatVec2x2:
				IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Vec2 THEN
					IF dadr = 0 THEN NEW(dest,2);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulLR2x2 # NIL THEN matVecMulLR2x2(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0];
					dest[0] := left[0,0]*v0 + left[0,1]*right[1];
					dest[1] := left[1,0]*v0 + left[1,1]*right[1];
				END;

			|MatVec3x3:
				IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Vec3 THEN
					IF dadr = 0 THEN NEW(dest,3);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulLR3x3 # NIL THEN matVecMulLR3x3(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1];
					dest[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*right[2];
					dest[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*right[2];
					dest[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*right[2];
				END;

			|MatVec4x4:
				IF SYSTEM.GET32(ADDRESSOF(dest)+flagoffs) # Vec4 THEN
					IF dadr = 0 THEN NEW(dest,4);
					ELSE Halt(GeometryMismatch,ADDRESSOF(left),ADDRESSOF(right),0);
					END;
				END;

				IF matVecMulLR4x4 # NIL THEN matVecMulLR4x4(dadr,ladr,radr);
				ELSE
					(* account possible overlapping *)
					v0 := right[0]; v1 := right[1]; v2 := right[2];
					dest[0] := left[0,0]*v0 + left[0,1]*v1 + left[0,2]*v2 + left[0,3]*right[3];
					dest[1] := left[1,0]*v0 + left[1,1]*v1 + left[1,2]*v2 + left[1,3]*right[3];
					dest[2] := left[2,0]*v0 + left[2,1]*v1 + left[2,2]*v2 + left[2,3]*right[3];
					dest[3] := left[3,0]*v0 + left[3,1]*v1 + left[3,2]*v2 + left[3,3]*right[3];
				END;

		ELSE
			ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulAXAX, matMulX );
		END;
	END MatVecMulAXAX;

	PROCEDURE VecMatMulAXAX*( VAR dest: ARRAY [ * ] OF LONGREAL;
														 CONST left: ARRAY [ * ] OF LONGREAL;
														 CONST right: ARRAY [ * , * ] OF LONGREAL );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulAXAX, matMulX );
	END VecMatMulAXAX;


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

	PROCEDURE MatMulIncASAS*( VAR dest: ARRAY [ * , * ] OF SHORTINT;
														CONST left, right: ARRAY [ * , * ] OF SHORTINT );
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
	END MatMulIncASAS;

	PROCEDURE MatVecMulIncASAS*( VAR dest: ARRAY [ * ] OF SHORTINT;
															  CONST left: ARRAY [ * , * ] OF SHORTINT;
															  CONST right: ARRAY [ * ] OF SHORTINT );
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
	END MatVecMulIncASAS;

	PROCEDURE VecMatMulIncASAS*( VAR dest: ARRAY [ * ] OF SHORTINT;
															  CONST left: ARRAY [ * ] OF SHORTINT;
															  CONST right: ARRAY [ * , * ] OF SHORTINT );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
	END VecMatMulIncASAS;

	PROCEDURE MatMulDecASAS*( VAR dest: ARRAY [ * , * ] OF SHORTINT;
														CONST left, right: ARRAY [ * , * ] OF SHORTINT );
	BEGIN
		MinusAS(dest,dest);
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
		MinusAS(dest,dest);
	END MatMulDecASAS;

	PROCEDURE MatVecMulDecASAS*( VAR dest: ARRAY [ * ] OF SHORTINT;
															  CONST left: ARRAY [ * , * ] OF SHORTINT;
															  CONST right: ARRAY [ * ] OF SHORTINT );
	BEGIN
		MinusAS(dest,dest);
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
		MinusAS(dest,dest);
	END MatVecMulDecASAS;

	PROCEDURE VecMatMulDecASAS*( VAR dest: ARRAY [ * ] OF SHORTINT;
															  CONST left: ARRAY [ * ] OF SHORTINT;
															  CONST right: ARRAY [ * , * ] OF SHORTINT );
	BEGIN
		MinusAS(dest,dest);
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( SHORTINT ), MatMulIncASASLoop, NIL );
		MinusAS(dest,dest);
	END VecMatMulDecASAS;

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

	PROCEDURE MatMulIncAIAI*( VAR dest: ARRAY [ * , * ] OF INTEGER;
													   CONST left, right: ARRAY [ * , * ] OF INTEGER );
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
	END MatMulIncAIAI;

	PROCEDURE MatVecMulIncAIAI*( VAR dest: ARRAY [ * ] OF INTEGER;
															 CONST left: ARRAY [ * , * ] OF INTEGER;
															 CONST right: ARRAY [ * ] OF INTEGER );
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
	END MatVecMulIncAIAI;

	PROCEDURE VecMatMulIncAIAI*( VAR dest: ARRAY [ * ] OF INTEGER;
															 CONST left: ARRAY [ * ] OF INTEGER;
															 CONST right: ARRAY [ * , * ] OF INTEGER );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
	END VecMatMulIncAIAI;

	PROCEDURE MatMulDecAIAI*( VAR dest: ARRAY [ * , * ] OF INTEGER;
													   CONST left, right: ARRAY [ * , * ] OF INTEGER );
	BEGIN
		MinusAI(dest,dest);
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
		MinusAI(dest,dest);
	END MatMulDecAIAI;

	PROCEDURE MatVecMulDecAIAI*( VAR dest: ARRAY [ * ] OF INTEGER;
															 CONST left: ARRAY [ * , * ] OF INTEGER;
															 CONST right: ARRAY [ * ] OF INTEGER );
	BEGIN
		MinusAI(dest,dest);
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
		MinusAI(dest,dest);
	END MatVecMulDecAIAI;

	PROCEDURE VecMatMulDecAIAI*( VAR dest: ARRAY [ * ] OF INTEGER;
															 CONST left: ARRAY [ * ] OF INTEGER;
															 CONST right: ARRAY [ * , * ] OF INTEGER );
	BEGIN
		MinusAI(dest,dest);
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( INTEGER ), MatMulIncAIAILoop, NIL );
		MinusAI(dest,dest);
	END VecMatMulDecAIAI;

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

	PROCEDURE MatMulIncALAL*( VAR dest: ARRAY [ * , * ] OF LONGINT;
													    CONST left, right: ARRAY [ * , * ] OF LONGINT );
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
	END MatMulIncALAL;

	PROCEDURE MatVecMulIncALAL*( VAR dest: ARRAY [ * ] OF LONGINT;
															  CONST left: ARRAY [ * , * ] OF LONGINT;
															  CONST right: ARRAY [ * ] OF LONGINT );
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
	END MatVecMulIncALAL;

	PROCEDURE VecMatMulIncALAL*( VAR dest: ARRAY [ * ] OF LONGINT;
															  CONST left: ARRAY [ * ] OF LONGINT;
															  CONST right: ARRAY [ * , * ] OF LONGINT );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
	END VecMatMulIncALAL;

	PROCEDURE MatMulDecALAL*( VAR dest: ARRAY [ * , * ] OF LONGINT;
													    CONST left, right: ARRAY [ * , * ] OF LONGINT );
	BEGIN
		MinusAL(dest,dest);
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
		MinusAL(dest,dest);
	END MatMulDecALAL;

	PROCEDURE MatVecMulDecALAL*( VAR dest: ARRAY [ * ] OF LONGINT;
															  CONST left: ARRAY [ * , * ] OF LONGINT;
															  CONST right: ARRAY [ * ] OF LONGINT );
	BEGIN
		MinusAL(dest,dest);
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
		MinusAL(dest,dest);
	END MatVecMulDecALAL;

	PROCEDURE VecMatMulDecALAL*( VAR dest: ARRAY [ * ] OF LONGINT;
															  CONST left: ARRAY [ * ] OF LONGINT;
															  CONST right: ARRAY [ * , * ] OF LONGINT );
	BEGIN
		MinusAL(dest,dest);
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGINT ), MatMulIncALALLoop, NIL );
		MinusAL(dest,dest);
	END VecMatMulDecALAL;

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

	PROCEDURE MatMulIncARAR*( VAR dest: ARRAY [ * , * ] OF REAL;
														 CONST left, right: ARRAY [ * , * ] OF REAL );
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
									    loopMatMulIncARAR, matMulIncR );
	END MatMulIncARAR;

	PROCEDURE MatVecMulIncARAR*( VAR dest: ARRAY [ * ] OF REAL;
															   CONST left: ARRAY [ * , * ] OF REAL;
															   CONST right: ARRAY [ * ] OF REAL );
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulIncARAR, matMulIncR );
	END MatVecMulIncARAR;

	PROCEDURE VecMatMulIncARAR*( VAR dest: ARRAY [ * ] OF REAL;
															   CONST left: ARRAY [ * ] OF REAL;
															   CONST right: ARRAY [ * , * ] OF REAL );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulIncARAR, matMulIncR );
	END VecMatMulIncARAR;

	PROCEDURE MatMulDecARAR*( VAR dest: ARRAY [ * , * ] OF REAL;
														 CONST left, right: ARRAY [ * , * ] OF REAL );
	BEGIN
		MinusAR(dest,dest);
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
									    loopMatMulIncARAR, matMulIncR );
		MinusAR(dest,dest);
	END MatMulDecARAR;

	PROCEDURE MatVecMulDecARAR*( VAR dest: ARRAY [ * ] OF REAL;
															   CONST left: ARRAY [ * , * ] OF REAL;
															   CONST right: ARRAY [ * ] OF REAL );
	BEGIN
		MinusAR(dest,dest);
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulIncARAR, matMulIncR );
		MinusAR(dest,dest);
	END MatVecMulDecARAR;

	PROCEDURE VecMatMulDecARAR*( VAR dest: ARRAY [ * ] OF REAL;
															   CONST left: ARRAY [ * ] OF REAL;
															   CONST right: ARRAY [ * , * ] OF REAL );
	BEGIN
		MinusAR(dest,dest);
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( REAL ), loopMatMulIncARAR, matMulIncR );
		MinusAR(dest,dest);
	END VecMatMulDecARAR;
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

	PROCEDURE MatMulIncAXAX*( VAR dest: ARRAY [ * , * ] OF LONGREAL;
														CONST left, right: ARRAY [ * , * ] OF LONGREAL );
	BEGIN
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
	END MatMulIncAXAX;

	PROCEDURE MatVecMulIncAXAX*( VAR dest: ARRAY [ * ] OF LONGREAL;
															  CONST left: ARRAY [ * , * ] OF LONGREAL;
															  CONST right: ARRAY [ * ] OF LONGREAL );
	BEGIN
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
	END MatVecMulIncAXAX;

	PROCEDURE VecMatMulIncAXAX*( VAR dest: ARRAY [ * ] OF LONGREAL;
															  CONST left: ARRAY [ * ] OF LONGREAL;
															  CONST right: ARRAY [ * , * ] OF LONGREAL );
	BEGIN
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
	END VecMatMulIncAXAX;


	PROCEDURE MatMulDecAXAX*( VAR dest: ARRAY [ * , * ] OF LONGREAL;
														CONST left, right: ARRAY [ * , * ] OF LONGREAL );
	BEGIN
		MinusAX(dest,dest);
		ApplyMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
									    SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
		MinusAX(dest,dest);
	END MatMulDecAXAX;

	PROCEDURE MatVecMulDecAXAX*( VAR dest: ARRAY [ * ] OF LONGREAL;
															  CONST left: ARRAY [ * , * ] OF LONGREAL;
															  CONST right: ARRAY [ * ] OF LONGREAL );
	BEGIN
		MinusAX(dest,dest);
		ApplyMatVecMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
		MinusAX(dest,dest);
	END MatVecMulDecAXAX;

	PROCEDURE VecMatMulDecAXAX*( VAR dest: ARRAY [ * ] OF LONGREAL;
															  CONST left: ARRAY [ * ] OF LONGREAL;
															  CONST right: ARRAY [ * , * ] OF LONGREAL );
	BEGIN
		MinusAX(dest,dest);
		ApplyVecMatMulLoop( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
											 SIZEOF( LONGREAL ), loopMatMulIncAXAX, matMulIncX );
		MinusAX(dest,dest);
	END VecMatMulDecAXAX;

(*** Cross product ********************************************************************)

	PROCEDURE CrossProductASAS*( VAR dest: ARRAY [ * ] OF SHORTINT;
														    CONST left, right: ARRAY [ * ] OF SHORTINT );
	VAR vl1, vl2, vl3, vr1, vr2, vr3: SHORTINT;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( dest,0 ) # 3 THEN NEW( dest, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  dest[0] := vl2 * vr3 - vl3 * vr2;
		dest[1] := vl3 * vr1 - vl1 * vr3;  dest[2] := vl1 * vr2 - vl2 * vr1;
	END CrossProductASAS;

	PROCEDURE CrossProductAIAI*( VAR dest: ARRAY [ * ] OF INTEGER;
														   CONST left, right: ARRAY [ * ] OF INTEGER );
	VAR vl1, vl2, vl3, vr1, vr2, vr3: INTEGER;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( dest,0 ) # 3 THEN NEW( dest, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  dest[0] := vl2 * vr3 - vl3 * vr2;
		dest[1] := vl3 * vr1 - vl1 * vr3;  dest[2] := vl1 * vr2 - vl2 * vr1;
	END CrossProductAIAI;

	PROCEDURE CrossProductALAL*( VAR dest: ARRAY [ * ] OF LONGINT;
														   CONST left, right: ARRAY [ * ] OF LONGINT );
	VAR vl1, vl2, vl3, vr1, vr2, vr3: LONGINT;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( dest,0 ) # 3 THEN NEW( dest, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  dest[0] := vl2 * vr3 - vl3 * vr2;
		dest[1] := vl3 * vr1 - vl1 * vr3;  dest[2] := vl1 * vr2 - vl2 * vr1;
	END CrossProductALAL;

	PROCEDURE CrossProductARAR*( VAR dest: ARRAY [ * ] OF REAL;
															 CONST left, right: ARRAY [ * ] OF REAL );
	VAR vl1, vl2, vl3, vr1, vr2, vr3: REAL;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ), 0 )
		END;
		IF LEN( dest,0 ) # 3 THEN NEW( dest, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  dest[0] := vl2 * vr3 - vl3 * vr2;
		dest[1] := vl3 * vr1 - vl1 * vr3;  dest[2] := vl1 * vr2 - vl2 * vr1;
	END CrossProductARAR;

	PROCEDURE CrossProductAXAX*( VAR dest: ARRAY [ * ] OF LONGREAL;
														    CONST left, right: ARRAY [ * ] OF LONGREAL );
	VAR vl1, vl2, vl3, vr1, vr2, vr3: LONGREAL;
	BEGIN
		IF (LEN( left,0 ) # 3) OR (LEN( right,0 ) # 3) THEN
			Halt( GeometryMismatch, ADDRESSOF( left ), ADDRESSOF( right ),  0 )
		END;
		IF LEN( dest,0 ) # 3 THEN NEW( dest, 3 ) END;   (* will trap if not allowed *)
		vl1 := left[0];  vl2 := left[1];  vl3 := left[2];  vr1 := right[0];  vr2 := right[1];
		vr3 := right[2];  dest[0] := vl2 * vr3 - vl3 * vr2;
		dest[1] := vl3 * vr1 - vl1 * vr3;  dest[2] := vl1 * vr2 - vl2 * vr1;
	END CrossProductAXAX;

(** Transpose  ********************************************************************)



	PROCEDURE Overlap( src1, src2: Address ): BOOLEAN;
	VAR from1, from2, to1, to2: Address;  dim: LONGINT;
	BEGIN
		from1 := GetAdr( src1 );  from2 := GetAdr( src2 );  to1 := from1;  to2 := from2;
		dim := GetDim( src1 ) - 1;
		WHILE (dim > 0) DO
			to1 := to1 + (GetLen( src1, dim ) - 1) * GetInc( src1, dim );  DEC( dim );
		END;
		dim := GetDim( src2 ) - 1;
		WHILE (dim > 0) DO
			to2 := to2 + (GetLen( src2, dim ) - 1) * GetInc( src2, dim );  DEC( dim );
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
			to1 := to1 + (GetLen( src1, dim ) - 1) * GetInc( src1, dim );
			to2 := to2 + (GetLen( src2, dim ) - 1) * GetInc( src2, dim );  DEC( dim );
		END;
		IF from1 < from2 THEN RETURN to1 >= from2;
		ELSIF from2 < from1 THEN RETURN to2 >= from1;
		ELSE RETURN TRUE;
		END;
	END Overlap;
	*)

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
			PutInc( dest, 1, GetInc( left, 0 ) );  PutInc( dest, 0, GetInc( left, 1 ) );
		ELSE
			len0 := GetLen( left, 0 );  len1 := GetLen( left, 1 );
			IF (len0 # GetLen( dest, 1 )) OR (len1 # GetLen( dest, 0 )) THEN
				Halt( GeometryMismatch, left, 0, dest )
			END;
			IF Overlap( left, dest ) THEN  (* copy data first, then transpose *)
				SYSTEM.NEW( p, len0 * len1 * Size );  dinc0 := Size;  dinc1 := len0 * Size;
				dadr := SYSTEM.VAL( LONGINT, p );  linc0 := GetInc( left, 0 );
				linc1 := GetInc( left, 1 );  ladr := GetAdr( left );
				WHILE (len0 > 0) DO
					CopyLoop( ladr, dadr, linc1, dinc1, len1 );  INC( ladr, linc0 );
					INC( dadr, dinc0 );  DEC( len0 );
				END;
				len0 := GetLen( left, 0 );  linc0 := Size;  linc1 := len0 * Size;
				ladr := SYSTEM.VAL( LONGINT, p );
			ELSE
				linc0 := GetInc( left, 0 );  linc1 := GetInc( left, 1 );  ladr := GetAdr( left );
			END;
			dinc0 := GetInc( dest, 0 );  dinc1 := GetInc( dest, 1 );
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

	PROCEDURE TransposeAS*( VAR dest: ARRAY [ * , * ] OF SHORTINT;
												    CONST left: ARRAY [ * , * ] OF SHORTINT );
	BEGIN
		Transpose( ADDRESSOF( dest ), ADDRESSOF( left ), SIZEOF( SHORTINT ) );
	END TransposeAS;

	PROCEDURE TransposeAI*( VAR dest: ARRAY [ * , * ] OF INTEGER;
												   CONST left: ARRAY [ * , * ] OF INTEGER );
	BEGIN
		Transpose( ADDRESSOF( dest ), ADDRESSOF( left ), SIZEOF( INTEGER ) );
	END TransposeAI;

	PROCEDURE TransposeAL*( VAR dest: ARRAY [ * , * ] OF LONGINT;
												   CONST left: ARRAY [ * , * ] OF LONGINT );
	BEGIN
		Transpose( ADDRESSOF( dest ), ADDRESSOF( left ), SIZEOF( LONGINT ) );
	END TransposeAL;

	PROCEDURE TransposeAR*( VAR dest: ARRAY [ * , * ] OF REAL;
												    CONST left: ARRAY [ * , * ] OF REAL );
	BEGIN
		Transpose( ADDRESSOF( dest ), ADDRESSOF( left ), SIZEOF( REAL ) );
	END TransposeAR;

	PROCEDURE TransposeAX*( VAR dest: ARRAY [ * , * ] OF LONGREAL;
												    CONST left: ARRAY [ * , * ] OF LONGREAL );
	BEGIN
		Transpose( ADDRESSOF( dest ), ADDRESSOF( left ), SIZEOF( LONGREAL ) );
	END TransposeAX;

	PROCEDURE CheckTensorGeometry( left, right, dest: Address;
															    ldim, rdim: LONGINT ): BOOLEAN;
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
	PROCEDURE Reshape*( VAR dest: LONGINT;  src: LONGINT;
											 CONST shape: ARRAY [ * ] OF LONGINT );
	VAR i, Size: LONGINT;  ptr, data: ANY;  new: LONGINT;

		oldSize, newSize: LONGINT;  oldDim, newDim: LONGINT;

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
				RETURN FALSE;
			END;

			RETURN (i = oldDim) & (j = newDim);
		END SqueezingReshape;

		(* Added by Alexey *)
		PROCEDURE NewDescriptorForSameData;
		VAR len, size, i, j: LONGINT;
		BEGIN
			ptr := GetArrayDesc( newDim );  new := SYSTEM.VAL( LONGINT, ptr );

			IF ~(RangeFlag IN GetFlags(src)) THEN
				size := Size;
				FOR i := newDim - 1 TO 0 BY -1 DO
					len := shape[i];  PutInc( new, i, size );  PutLen( new, i, len );
					size := size * len;
				END;
			ELSE (* squeezing reshape *)
				j := 0; len := shape[j];
				FOR i := 0 TO oldDim-1 DO
					IF GetLen(src,i) = len THEN
						PutInc(new,j,GetInc(src,i)); PutLen(new,j,len);
						INC(j);
						IF j < newDim THEN len := shape[j]; END;
					END;
				END;
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
					inc := GetInc( src, dim );  len := GetLen( src, dim );
					FOR i := 0 TO len - 1 DO
						SYSTEM.MOVE( sadr, dadr, s );  INC( dadr, s );  INC( sadr, inc );
					END;
				ELSE
					inc := GetInc( src, dim );  len := GetLen( src, dim );  INC( dim );
					FOR i := 0 TO len - 1 DO Loop( dim, sadr );  INC( sadr, inc );  END;
				END;
			END Loop;

		BEGIN
			s := Size;  ASSERT( GetSize( src ) = s );  d := GetDim( src ) - 1;
			WHILE (d >= 0) & (GetInc( src, d ) = s) DO
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
					inc := GetInc( dest, dim );  len := GetLen( dest, dim );
					FOR i := 0 TO len - 1 DO
						SYSTEM.MOVE( sadr, dadr, s );  INC( dadr, inc );  INC( sadr, s );
					END;
				ELSE
					inc := GetInc( dest, dim );  len := GetLen( dest, dim );  INC( dim );
					FOR i := 0 TO len - 1 DO Loop( dim, dadr );  INC( dadr, inc );  END;
				END;
			END Loop;

		BEGIN
			s := Size;  ASSERT( GetSize( dest ) = s );  d := GetDim( dest ) - 1;
			WHILE (d >= 0) & (GetInc( dest, d ) = s) DO
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
			SYSTEM.MOVE( src, dest, lenoffs + GetDim( src ) * 8 );
		END CopyDescriptor;

		PROCEDURE ShapeDiffers( ): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			ASSERT( oldDim = newDim );
			FOR i := 0 TO oldDim - 1 DO
				IF GetLen( dest, i ) # shape[i] THEN RETURN TRUE END;
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
			IF ~(RangeFlag IN GetFlags(dest)) OR SqueezingReshape() THEN
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
	END Reshape;

	PROCEDURE AllocateTensorX*( VAR dest: LONGINT;
														  CONST a: ARRAY [ * ] OF LONGINT;
														  Size: LONGINT );
	VAR descr, data: ANY;  same: BOOLEAN;  i: LONGINT;  dim: LONGINT;

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
			SYSTEM.NEW( data, size );   (* Zero(data,size*Size); *)
			PutAdr( dest, SYSTEM.VAL( LONGINT, data ) );
			PutPtr( dest, SYSTEM.VAL( LONGINT, data ) );  PutSize( dest, Size );
		END NewData;

		PROCEDURE ClearData;
			(*! todo *)
		END ClearData;

	BEGIN
		dim := LEN( a,0 );

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
		FOR i := 0 TO dim - 1 DO dest[i] := GetInc( src, i );  END;
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
			RETURN GetInc(src,d);
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
		linc := GetInc( left, ldim );  ri := GetInc( right, rdim );  DEC( rdim );
		DEC( ldim );
		WHILE (ldim >= 0) & (rdim >= 0) & (GetInc( left, ldim ) = len * linc) &
				    (GetInc( right, rdim ) = len * ri) DO
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
				len := GetLen( left, ldim );  linc := GetInc( left, ldim );
				dinc := GetInc( dest, ldim + rdim );  INC( ldim );
				WHILE (len > 0) DO
					Traverse( ladr, radr, dadr, ldim, rdim );  INC( ladr, linc );
					INC( dadr, dinc );  DEC( len );
				END;
			ELSIF (rdim # loopd) THEN
				len := GetLen( right, rdim );  rinc := GetInc( right, rdim );
				dinc := GetInc( dest, ldim + rdim );  INC( rdim );
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

	PROCEDURE TensorProdASAS*( VAR dest: ARRAY [ ? ] OF SHORTINT;
														 CONST left, right: ARRAY [ ? ] OF SHORTINT );
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( SHORTINT ), MulASSSLoop );
	END TensorProdASAS;

	PROCEDURE TensorProdAIAI*( VAR dest: ARRAY [ ? ] OF INTEGER;
													    CONST left, right: ARRAY [ ? ] OF INTEGER );
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( INTEGER ), MulAISILoop );
	END TensorProdAIAI;

	PROCEDURE TensorProdALAL*( VAR dest: ARRAY [ ? ] OF LONGINT;
														CONST left, right: ARRAY [ ? ] OF LONGINT );
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGINT ), MulALSLLoop );
	END TensorProdALAL;

	PROCEDURE TensorProdARAR*( VAR dest: ARRAY [ ? ] OF REAL;
														  CONST left, right: ARRAY [ ? ] OF REAL );
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ), SIZEOF( REAL ),
										  loopMulARSR );
	END TensorProdARAR;

	PROCEDURE TensorProdAXAX*( VAR dest: ARRAY [ ? ] OF LONGREAL;
														 CONST left, right: ARRAY [ ? ] OF LONGREAL );
	BEGIN
		ApplyTensorAAAOp( ADDRESSOF( dest ), ADDRESSOF( left ), ADDRESSOF( right ),
										  SIZEOF( LONGREAL ), loopMulAXSX );
	END TensorProdAXAX;

(** minimum and maximum of two numbers  ********************************************************************)

	PROCEDURE MinSXSX*( l, r: LONGREAL ): LONGREAL;
	BEGIN
		IF l < r THEN RETURN l ELSE RETURN r END;
	END MinSXSX;

	PROCEDURE MaxSXSX*( l, r: LONGREAL ): LONGREAL;
	BEGIN
		IF l > r THEN RETURN l ELSE RETURN r END;
	END MaxSXSX;

	PROCEDURE MinSRSR*( l, r: REAL ): REAL;
	BEGIN
		IF l < r THEN RETURN l ELSE RETURN r END;
	END MinSRSR;

	PROCEDURE MaxSRSR*( l, r: REAL ): REAL;
	BEGIN
		IF l > r THEN RETURN l ELSE RETURN r END;
	END MaxSRSR;

	PROCEDURE InitOptimization;
	VAR p: PROCEDURE;
	BEGIN
		GETPROCEDURE("ArrayBaseOptimized","Install",p);
		IF p # NIL THEN
			p;
		ELSE
			KernelLog.String( "Warning: ArrayBase runtime library optimizer not installed." );
		END;
	END InitOptimization;

BEGIN
	alloc := 0;  SetDefaults();  InitOptimization();  (* CreateTypePool;  *)
END ArrayBase.



(* old *)
(*
	without loop idea:

	PROCEDURE AddALAL*( left, right, dest, dim: LONGINT );   (* a: left, b: right, c: dest *)
	TYPE Type = LONGINT;
	VAR lval, rval, dval: Type;
	CONST Size = SIZEOF( Type );

	VAR x, i: LONGINT;  p: ANY;  len: LONGINT;

		PROCEDURE Traverse( dim, ladr, radr, dadr: LONGINT );
		VAR len: LONGINT;  linc, rinc, dinc: LONGINT;
		BEGIN
			DEC( dim );
			IF dim < 0 THEN SYSTEM.GET( ladr, lval );  SYSTEM.GET( radr, rval );  SYSTEM.PUT( dadr, lval + rval );  ELSE len := GetLen( left, dim );
				ASSERT ( len = GetLen( right, dim ) );
				ASSERT ( len = GetLen( dest, dim ) );
				linc := GetInc( left, dim );  rinc := GetInc( right, dim );  dinc := GetInc( dest, dim );
				WHILE (len > 0) DO Traverse( dim, ladr, radr, dadr );  INC( ladr, linc );  INC( radr, rinc );  INC( dadr, dinc );  DEC( len );  END;
			END;
		END Traverse;

	BEGIN
		IF GetAdr( dest ) = -1 THEN p := Allocate( left, dest, dim, Size );  END;
		(*Report( "left", left, dim );  Report( "right", right, dim );  Report( "dest", dest, dim );  *)
		Traverse( dim, GetAdr( left ), GetAdr( right ), GetAdr( dest ) );
	END AddALAL;
*)

(*PROCEDURE ConvertALAX*( left, dest, dim: LONGINT );
	TYPE sType = LONGINT;  dType = LONGREAL;
	VAR lval: sType;  dval: dType;
	CONST sSize = SIZEOF( sType );  dSize = SIZEOF( dType );

	VAR p: ANY;  len, inc, i: LONGINT;  dadr: LONGINT;

		PROCEDURE Traverse( dim, adr: LONGINT );
		VAR len, inc: LONGINT;
		BEGIN
			DEC( dim );
			IF dim < 0 THEN SYSTEM.GET( adr, lval );  dval := lval;  SYSTEM.PUT( dadr, dval );  INC( dadr, dSize );
			ELSE
				len := GetLen( left, dim );  inc := GetInc( left, dim );
				WHILE (len > 0) DO Traverse( dim, adr );  INC( adr, inc );  DEC( len );  END;
			END;
		END Traverse;

	BEGIN
		Report( "conv: left", left, dim );  Report( "conv: dest", dest, dim );

		len := 1;
		FOR i := 0 TO dim - 1 DO len := len * GetLen( left, i );  END;
		SYSTEM.NEW( p, len * dSize );  dadr := SYSTEM.VAL( LONGINT, p );

		Traverse( dim, GetAdr( left ) );

		PutAdr( dest, SYSTEM.VAL( LONGINT, p ) );  inc := dSize;
		FOR i := 0 TO dim - 1 DO len := GetLen( left, i );  PutInc( dest, i, inc );  PutLen( dest, i, len );  inc := inc * len;  END;
		Report( "conv: dest", dest, dim );
	END ConvertALAX;
	*)
	(*
supported base types: SHORTINT, INTEGER, LONGINT, REAL, LONGREAL -> 16 (10 commutative) Functions per operator
type commutative AAA operators: +(10),.*(10),*(10), .= (elementwise equal)
non type commuatative AAA operators: -(16),/(16), MOD(4),DIV(4)
type commutative ASA operators: +(10),*(10)
non type commutative ASA operators: -(16),/(16),MOD(4),DIV(4)
AAS operator: +* (16)
AAB operator: = (16)
AA assignment := (builtin:4, here: 6)
-> ca. 150 operators
simplification: conversion for operators on different types -> discourage users to use different types. reduces number of operators to 42

ArArAr: Array real Array real -> Array real
AxAxAb: Array longreal Array longreal -> Array bool
AxAxSb: Array longreal Array longreal -> bool
*)
