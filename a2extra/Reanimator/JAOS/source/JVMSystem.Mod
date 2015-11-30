(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMSystem;	(** PRK, rl **)
(*
	LowLevel system interface with pc Aos oberon
	NON PORTABLE
*)

IMPORT
		SYSTEM,
		AosOut, AosBoot,
		AosHeap, AosModules, AosActive;


CONST
	RCHOP* = 0F7FH;				(* fpu control word with round chop *)
	RNEAREST* = 037FH;		  (* fpu control word with round to nearest -> default *)
	
	Trace = FALSE;

	ExtTabWordSize = 16;
	Tag0WordOffset = -2;
	Mth0WordOffset = Tag0WordOffset - ExtTabWordSize;
	TypeNameOffset = 16;
	
	
	MPO = 0C0000000H;

TYPE
	Module* = AosModules.Module;
	Descriptor* = AosModules.TypeDesc;
	Data* = POINTER TO ARRAY OF CHAR;

VAR
	fcr: SET;	(*cached value of AosBoot.fcr, for use in assembly code *)
	NewRec*: PROCEDURE (VAR p: PTR; tag: PTR );	(* AosHeap.NewRec *)
	InstallTermHandler* : PROCEDURE( h : AosModules.TerminationHandler );
	InstallTrapHandler* : PROCEDURE( h : AosActive.ExceptionHandler );
	
	
	Unimplemented: PROCEDURE;

PROCEDURE UnimplProc;
BEGIN	HALT(99)
END UnimplProc;

(** retrieves low and high from a HUGEINT *)
PROCEDURE -GetLowHigh*( h : HUGEINT; VAR low, high : LONGINT );
CODE{SYSTEM.i386}
	POP EAX
	POP EBX
	POP ECX
	MOV [EBX],ECX 
	POP ECX
	MOV [EAX], ECX
END GetLowHigh;		

(** 64 integer Multiplication that overflows-> no traps *)
PROCEDURE -Mul*( op1, op2 : HUGEINT ):HUGEINT;
CODE{SYSTEM.i386}	
	MOV EAX, 8[ESP]
	MOV ECX, 12[ESP]				  
	MUL DWORD 0[ESP]	   (* low1*low2 *)
	IMUL ECX, [ESP] 			  (* high1*low2 *)
	ADD EDX, ECX
	MOV ECX, 4[ESP]
	IMUL ECX, 8[ESP]			 (* high2 * low1 *)
	ADD EDX, ECX
	ADD ESP,16
END Mul;

(** HUGEINT division; uses FPU result is truncated to HUGEINT*)
PROCEDURE div( a, op2 :HUGEINT):HUGEINT;
VAR cw0: INTEGER;
CODE{SYSTEM.i386, SYSTEM.FPU}	
		
	MOV	cw0[EBP], RCHOP;      			; rounding to CHOP INT	
	FLDCW	cw0[EBP]					;set rounding to 01, round down
	
	FILD QWORD 16[EBP]			
	FILD QWORD 8[EBP]	
	FDIVP 
	FISTP QWORD 8[EBP]	
	;FNINIT					;reset rounding (* without this, there happens strange things *)
	;WAIT
	FLDCW	fcr
	MOV EAX, 8[EBP]
	MOV EDX, 12[EBP]
END div;

PROCEDURE Div*( a, op2 :HUGEINT):HUGEINT;
BEGIN
	RETURN div(a, op2)
END Div;


(** modulo operation of a hugeint; this does not correspond to the java semantics
      a mod 0 should trap. in the aos compiler an explicit check is introduced *)
PROCEDURE -Mod*( a, b : HUGEINT ):HUGEINT;
CODE {SYSTEM.i386, SYSTEM.FPU}
	FILD QWORD 0[ESP]		
	FILD QWORD 8[ESP]	
	ADD ESP, 8
	FPREM
	FISTP QWORD 0[ESP]
	POP EAX
	POP EDX
END Mod;

(* funktions for Java Math; the cpu makes exacly what i want *)
(** round with mode specified in cw *)
PROCEDURE Round*( x : LONGREAL; cw : INTEGER ):LONGREAL;
VAR cw0 :INTEGER;
CODE{SYSTEM.i386, SYSTEM.FPU}
	FLD QWORD x[EBP]
	FSTCW cw0[EBP]
	FLDCW cw[EBP]
	FRNDINT								; the rounding mode is nearest
	FLDCW cw0[EBP]
END Round;


PROCEDURE IEEEReminder*( x, y : LONGREAL):LONGREAL;
VAR stw : INTEGER;
CODE{SYSTEM.i386, SYSTEM.FPU}
	FLD QWORD 8[EBP]
	FLD QWORD 16[EBP]
Loop:
	FPREM1
	FSTSW  stw[EBP]
	MOV AX, stw[EBP]
	SAHF
	JP Loop
END IEEEReminder;

PROCEDURE InitFPU*;
CODE{SYSTEM.i386, SYSTEM.FPU}	
	FNINIT
	;PUSH	RNEAREST		; java uses nearest rounding
	;FLDCW	0[ESP]
	;ADD	ESP, 4
END InitFPU;
	

(** stack manipulation *)
(*
PROCEDURE -Ret*( n, val : LONGINT ):LONGINT;
CODE{SYSTEM.i386}
	POP EAX
	POP ECX
	MOV ESP, EBP	(* reset stack pointer *)
	POP EBP			(* restore frame pointer *)
	POP EBX			(* restore address where computation continues *)
	ADD ESP, EAX   (* remove parameters from stack *)
	MOV EAX, ECX  (* store return in eax *)
	JMP EBX			(* resume *)	
END Ret;
*)
(** this is needed in the creation of new multidimesional arrays
      gets the n-th parameter from the stack *)
PROCEDURE -Adr*( n : LONGINT ):LONGINT;
CODE{ SYSTEM.i386}
	POP EAX
	MOV EBX,EBP
	ADD EBX, EAX
	MOV EAX, EBX
END Adr;	


		
(** Type Descriptor Handling *)	
PROCEDURE GetDescriptor*( p : LONGINT ): Descriptor;
VAR td : LONGINT;
BEGIN
	SYSTEM.GET( p-4, td ); SYSTEM.GET( td-4, td );
	RETURN SYSTEM.VAL( Descriptor, td )
END GetDescriptor;

(* made for debugging *)
PROCEDURE GetTypeName*( d : Descriptor; VAR name :  ARRAY OF CHAR );
VAR adr1, adr2 : LONGINT;
BEGIN
	adr2 := SYSTEM.ADR( name[0] );
	adr1 := SYSTEM.ADR( d.name[0] );
	SYSTEM.MOVE( adr1, adr2, 32 );		
END GetTypeName;

(* retrieves the number in the method table of a method with a given address *)
PROCEDURE GetMno*( td : Descriptor; adr : LONGINT ):LONGINT;
VAR adr0, t, count : LONGINT;
BEGIN 
	adr0 := SYSTEM.VAL( LONGINT, td.tag ) + (Mth0WordOffset*4);
	count := -1; 		
	REPEAT
		 INC( count ); SYSTEM.GET( adr0, t ); DEC( adr0, 4 )
	UNTIL (t=0) OR (t=adr);
	IF t = 0 THEN RETURN -1
	ELSE RETURN count END
END GetMno;

(** GetTypeSize - return the type size in bytes *)
PROCEDURE GetSize*(td: Descriptor; VAR size: LONGINT);
BEGIN
	IF td = NIL THEN size := 0 ELSE SYSTEM.GET( td.tag, size ) END
END GetSize;


(** GetNofPtrs - return the number of pointer fields in this type *)

PROCEDURE GetNofPtrs*(td: Descriptor; VAR count: LONGINT);
VAR p, t: LONGINT;
BEGIN
	IF td # NIL THEN
		t := SYSTEM.VAL( LONGINT, td.tag )+ AosModules.Ptr0Ofs;
		count := -1;
		REPEAT
			INC(count);
			SYSTEM.GET(t, p); INC( t, 4 );
		UNTIL p < 0;
(*
		UNTIL p <= MPO;
		ASSERT(count = (MPO-p) DIV 4 - 1)
*)
	ELSE
		count := 0
	END
END GetNofPtrs;

(** PatchPtr - insert ptr offset into the td *)

PROCEDURE PatchPtr*(td: Descriptor; pos, off: LONGINT);
VAR count: LONGINT;
BEGIN
	IF Trace THEN AosOut.String("PatchPtr"); AosOut.Int(pos, 4); AosOut.Int(off, 4); AosOut.Ln  END;
	ASSERT(td # NIL, 100);
	ASSERT(pos >= 0, 101);
	GetNofPtrs(td, count);
	ASSERT(pos < count, 102);
	ASSERT(off >= 0, 103);
	GetSize(td, count);
	ASSERT(off < count, 104);
	ASSERT(off MOD 4 = 0, 105);
	SYSTEM.PUT( SYSTEM.VAL(LONGINT, td.tag) + AosModules.Ptr0Ofs + 4 * pos, off)
END PatchPtr;

(** MethodOffset - Offset of method mno in the type descriptor *)

PROCEDURE MethodOffset*(mno: LONGINT): LONGINT;
BEGIN RETURN (Mth0WordOffset - mno)*4
END MethodOffset;

(** GetMethod - return method entry point *)

PROCEDURE GetMethod*(td: Descriptor; mno: LONGINT): LONGINT;
VAR adr: LONGINT;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(LONGINT, td.tag) + (Mth0WordOffset - mno)*4, adr);
	RETURN adr
END GetMethod;

(** PatchMethod - overwrite a method, insert forwarding jump *)

PROCEDURE PatchMethod*(td: Descriptor; mno, adr: LONGINT);
VAR pos, old, codebase: LONGINT;
BEGIN
	pos := SYSTEM.VAL(LONGINT, td.tag) + (Mth0WordOffset - mno)*4;
	SYSTEM.GET(pos, old);
	SYSTEM.PUT(pos, adr);
(*
	IF (old # 0) THEN
		codebase := SYSTEM.ADR(td.mod.code[0]);
		IF (codebase <= old) & (old < codebase + LEN(td.mod.code)) THEN
			PatchStaticMethod(old, adr);	(*jmp, because this td may have been already copied in an extention*)
		END
	END
*)
END PatchMethod;

(** count the number of methods in the typedescriptor; the loop stops at the sentinel *)
PROCEDURE CountDynamics*( td: Descriptor ):LONGINT;
VAR adr,  pos : LONGINT;
BEGIN
	pos := 0;
	REPEAT
		SYSTEM.GET( SYSTEM.VAL( LONGINT, td.tag ) + (Mth0WordOffset - pos)*4, adr );
		INC( pos )
	UNTIL adr = 0;
	RETURN (pos-1)
END CountDynamics;

(** PatchMethod - overwrite a static method *)

PROCEDURE PatchStaticMethod*(adr, jadr: LONGINT);
BEGIN
	SYSTEM.PUT(adr, 0E9X);	(*jmp*)
	SYSTEM.PUT(adr+1, jadr-adr-5);
END PatchStaticMethod;

(** NewType - create a new type descriptor; adapted to AOS 11.01.2001 rl*)

PROCEDURE NewType*(VAR ptd: Descriptor; std: Descriptor; size, nofPtr, 
										nofMth: LONGINT; name : ARRAY OF CHAR; 
										mod : Module; isObject : BOOLEAN);
VAR root, baseRoot, baseTag, tagaddr, extLevel, i, j, t: LONGINT;  flags : SET;
BEGIN
	IF isObject THEN flags := {AosModules.ProtTypeBit};
	ELSE flags := {} END;
	AosHeap.NewType( SYSTEM.VAL(PTR, ptd), size, nofPtr, AosModules.MaxTags+nofMth, name, mod, flags );
	ASSERT( (ptd#NIL) & ( SYSTEM.VAL(LONGINT, ptd) MOD 32 = 0) );	
	(* now initialize --> see AosLoader.Mod *)
	root := SYSTEM.VAL( LONGINT, ptd.tag );				
	(* copy superclass table / extlev this *)
	extLevel := 0;
	IF std # NIL THEN
		(* copy super class table *)
		baseTag := root + AosModules.Tag0Ofs;
		tagaddr := SYSTEM.VAL(LONGINT, std.tag) + AosModules.Tag0Ofs; 		
		SYSTEM.GET(tagaddr, t);
		WHILE t#0 DO
			SYSTEM.PUT( baseTag - 4*extLevel, t ); INC( extLevel ); 
			DEC( tagaddr, 4 ); SYSTEM.GET(tagaddr, t);
		END;
		ptd.flags := ptd.flags + SYSTEM.VAL(SET, extLevel);		
		ASSERT(extLevel < AosModules.MaxTags);
						
		baseRoot := SYSTEM.VAL(LONGINT, std.tag)+Mth0WordOffset*4;
		root := SYSTEM.VAL(LONGINT, ptd.tag)+Mth0WordOffset*4;

		SYSTEM.GET( baseRoot, t );
		(* copy adresses of inherited methods (sentinel in typedescriptor)*)
		WHILE t # 0 DO
			SYSTEM.PUT( root, t ); 
(*
			SYSTEM.PUT( root, LONG(LONG(0)) ); 
*)
			DEC( baseRoot, 4 ); DEC( root, 4 );			
			SYSTEM.GET( baseRoot, t);
		END;

		(* copy pointer table *)
		GetNofPtrs(std, j);
		root := SYSTEM.VAL(LONGINT, ptd.tag) + AosModules.Ptr0Ofs;
		baseRoot := SYSTEM.VAL(LONGINT, std.tag) + AosModules.Ptr0Ofs;
		SYSTEM.GET(baseRoot, t);
		i := 0;
		WHILE t >= 0 DO
			ASSERT(i DIV 4 < j, 500);
			ASSERT(i DIV 4 < nofPtr, 501);
			SYSTEM.PUT(root+i, t);
			INC(i, 4);
			SYSTEM.GET(baseRoot+i, t);
		END;
	END;	
	SYSTEM.PUT(baseTag - 4*extLevel, ptd.tag);	(* self *)
	(*
	root := SYSTEM.VAL( LONGINT, ptd.tag ) + AosModules.Ptr0Ofs + nofPtr*4;
	ofs := -36;  SYSTEM.PUT(root, ofs);  INC(root, 4);	(* awaitingLock.head *)
	ofs := -32;  SYSTEM.PUT(root, ofs);  INC(root, 4);	(* awaitingLock.tail *)
	ofs := -28;  SYSTEM.PUT(root, ofs);  INC(root, 4);	(* awaitingCond.head *)
	ofs := -24;  SYSTEM.PUT(root, ofs);  INC(root, 4);	(* awaitingCond.tail *)
	ofs := -20;  SYSTEM.PUT(root, ofs)	(* lockedBy *)
	*)
END NewType;


(** Module Handling *)

PROCEDURE GetCodeBase*( m : Module ):LONGINT;
BEGIN RETURN SYSTEM.ADR( m.code[0] );
END GetCodeBase;

PROCEDURE GetClass*(m: Module;  name: ARRAY OF CHAR;  VAR d: Descriptor);
BEGIN
	d := AosModules.ThisType( m, name )
END GetClass;
	

PROCEDURE CreateStaticData*(m: Module; size, nofPtrs: LONGINT);
BEGIN
	IF Trace THEN AosOut.String("CreateStaticData "); AosOut.Int(size, 4); AosOut.Int(nofPtrs, 4); AosOut.Ln  END;
	INC(size, (-size-24) MOD 16);
	m.dataSize := size;
	NEW(m.data, size);
	m.sb := SYSTEM.ADR(m.data[0]) + size;  ASSERT(m.sb MOD 16 = 0);
	NEW(m.ptrAdr, nofPtrs)
END CreateStaticData;

PROCEDURE CreateCode*(m: Module; VAR code: ARRAY OF CHAR; csize: LONGINT);
BEGIN
	NEW(m.code, csize);
	m.codeSize := csize;
	SYSTEM.MOVE(SYSTEM.ADR(code[0]), SYSTEM.ADR(m.code[0]), csize);
END CreateCode;

PROCEDURE CreateRefs*(m: Module; VAR refs: ARRAY OF CHAR; rsize: LONGINT);
BEGIN
	m.refSize := rsize+1;
	NEW(m.refs, rsize+1);
	SYSTEM.MOVE(SYSTEM.ADR(refs[0]), SYSTEM.ADR(m.refs[0]), rsize);
	m.refs[rsize] := 0X
END CreateRefs;

PROCEDURE PatchStaticPtr*(m: Module; nr, off: LONGINT);
BEGIN	m.ptrAdr[nr] := m.sb+off;
	IF Trace THEN  AosOut.String("PatchStaticPtr"); AosOut.Int(nr, 4); AosOut.Int(off, 4); AosOut.Ln  END;
END PatchStaticPtr;

(** IsEmptyMethod - check if method has an empty body *)

PROCEDURE IsEmptyMethod*(adr: LONGINT): BOOLEAN;
VAR byte: CHAR;
BEGIN
	(* an empty method has just an enter and exit but no code
		0H push ebp
		1H mov ebp, esp
		3H mov esp, ebp
		5H pop ebp	( = 5D )
		6H ret x
		
		0H push ebp
		1H mov ebp, esp
		3H push 3
		5H int 3		( = CC )
	*)
	IF adr # 0 THEN
		SYSTEM.GET(adr, byte); ASSERT((byte = 55X) OR (byte = 0E9X));	(*push ebp / forwarding jump*)
		SYSTEM.GET(adr+5, byte);
		IF Trace & (byte # 05DX) & (byte # 0CCX) THEN AosOut.String("Non-empty method! "); AosOut.Int(adr, 0); AosOut.Int(ORD(byte), 4); AosOut.Ln END;
		RETURN (byte = 05DX) OR (byte = 0CCX)
	END;
	RETURN TRUE
END IsEmptyMethod;

PROCEDURE NewModule*(VAR m: Module;  stub: Module);
VAR p: Module; res : LONGINT; msg : ARRAY 64 OF CHAR;
BEGIN NEW(m);
	p := AosModules.ThisModule("JVMEmpty", res, msg );  m^ := p^;  m.next := NIL;
	IF stub # NIL THEN
		m.sb := stub.sb;  m.data := stub.data
	END;
END NewModule;

PROCEDURE Insert*(m: Module);
VAR new : BOOLEAN;
BEGIN
	AosModules.Publish( m, new )
END Insert;

PROCEDURE FreeModule*( m : Module );
VAR res : LONGINT; msg : ARRAY 64 OF CHAR;
BEGIN
	AosModules.FreeModule( m.name, res, msg )
END FreeModule;

(** Call the subroutine at adr *)
PROCEDURE Execute*(adr: LONGINT);
CODE {SYSTEM.i386}
	MOV EAX, adr[EBP]
	CALL EAX
END Execute;

PROCEDURE -GetSP*():LONGINT;
CODE{SYSTEM.i386}
	MOV EAX, ESP
END GetSP;
	
PROCEDURE -GetFP*():LONGINT;
CODE{SYSTEM.i386}
	MOV EAX, EBP
END GetFP;

PROCEDURE -PreviousFP*(fp :LONGINT ):LONGINT;
CODE{SYSTEM.i386}
	POP EAX
	MOV EAX, [EAX]
END PreviousFP;

PROCEDURE -GetRetPC*( fp : LONGINT ):LONGINT;
CODE{SYSTEM.i386}
	POP EAX
	MOV EAX, 4[EAX]
END GetRetPC;
						
(** resume execution at a specified pc and adjust pc and fp
*)
PROCEDURE -Resume*( sp, fp, pc, edx, eax :LONGINT);
CODE{SYSTEM.i386}
	POP EAX
	POP EDX
	POP ECX 
	POP EBX
	POP ESP
	MOV EBP, EBX
	PUSH ECX
	RET
END Resume;

(** Call the PROCEDURE at adress adr with size parametrs in stack[]:
		eax, edx hold the return value of the function call;
		in case of retfp = 1, st(0) is stored to [eax]
*)
PROCEDURE InvokeMethod*( adr, stack : LONGINT; size : LONGINT; retfp : BOOLEAN;
												VAR eax, edx : LONGINT );											
CODE{SYSTEM.i386, SYSTEM.FPU}
	
	MOV ECX, size[EBP]
	CMP ECX, 0										; (* no parameters *)
	JLE  invoke
	MOV EBX, stack[EBP]
	copy:												;(* copy parameters onto the stack *)
	PUSH [EBX]
	ADD EBX, 4
	LOOP copy  
	invoke:											;(* invoke procedure *)
	MOV EAX, adr[EBP]
	CALL EAX
	
	;MOV ECX, retfp[EBP]					;(* returns floating point? *)
	;CMP ECX, 0
	CMP  retfp[EBP], 0
	JLE retint	
	MOV EBX, eax[EBP]					 ;(* get floating point result *)
	FST QWORD [EBX]
	WAIT
	JMP ret
	retint:
	MOV EBX, eax[EBP]					;(* get others *)
	MOV [EBX], EAX
	MOV EBX, edx[EBP]
	MOV [EBX], EDX
	ret:	
													
END InvokeMethod;												
												

(** Get PC of caller (for the caller of this procedure) *)

PROCEDURE GetPC*(VAR adr: LONGINT);
CODE {SYSTEM.i386}
	MOV EAX, 0[EBP]
	MOV EAX, 4[EAX]
	MOV EBX, adr[EBP]
	MOV 0[EBX], EAX
END GetPC;

PROCEDURE ClearCall*(pc: LONGINT);
BEGIN
	SYSTEM.PUT(pc-4, 90909090H);
	SYSTEM.PUT(pc-5, 90X);
	SYSTEM.PUT(pc-9, 90909090H);
	SYSTEM.PUT(pc-10, 90X);
END ClearCall;

PROCEDURE Init;
BEGIN
	Unimplemented := UnimplProc;
	InstallTermHandler := AosModules.InstallTermHandler;
	InstallTrapHandler := AosActive.SetExceptionHandler;
	SYSTEM.PUT(SYSTEM.ADR(NewRec), AosModules.kernelProc[0]) ;
	fcr := AosBoot.fcr
END Init;

BEGIN
	Init;
END JVMSystem.

(*
	09.03.03	prk	clear CheckInitialized call
	03.12.01	prk	fpu rounding control changed
	09.11.01	prk	PushSelfTD removed
	05.09.01	prk	XOR removed, use BIT.LXOR instead
	08.05.01	prk	JVMSystem.PushSelfTD
	08.05.01	prk	InvokeMethod improved
	12.04.01	prk	PatchMethod, insert forwarding jump in code
*)