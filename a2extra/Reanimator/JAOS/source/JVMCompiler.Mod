(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMCompiler;	(** prk, rl **)

(*
	Compile a Class into i386 code
	
	References:
	[1]	The Java Virtual Machine Specification, Ed. 1
	
*)


IMPORT
		AosBoot, AosKernel,
		StringPool, PCT, PCBT,
		JC := JVMConsole,
		jjlObject, jjlString, jjlThrowable, JVMExceptions, JVMRefs,
		SYSTEM, JC0 := JVMCompiler0, JT := JVMTypes, JB := JVMBase, JS := JVMSystem;

CONST
	BenchTiming = FALSE;
	TraceMethods* = FALSE;

	NULL = JT.NULL;	(* NIL Value *)

		(*registers and other Compiler0 constants*)
	noBase = JC0.noBase; noInx = JC0.noInx; noScale = JC0.noScale;
	noDisp = JC0.noDisp; noImm = JC0.noImm;
	SP = JC0.ESP; FP = JC0.EBP; EAX = JC0.EAX; EBX = JC0.EBX; ECX = JC0.ECX; EDX = JC0.EDX;
	AX = JC0.AX;
	AL = JC0.AL;
	
		(*special values*)
	JMP = -1; CALL = -2;
	
		(*data types*)
	JavaINT = 0; JavaLONG = 1; JavaFLOAT = 2; JavaDOUBLE = 3; JavaREF = 4;
	JavaBYTE = 5; JavaCHAR = 6; JavaSHORT = 7;
	
	ByteSize = 1; 	(* must be sign-extended *)
	ShortSize = 2;	(* must be sign-extended *)
	CharSize = 3;	(* different from short: char must be zero extended *)
	IntSize = 4;  LongSize = 8;
	FloatSize = 4;  DoubleSize = 8;
	RefSize = 4;
	
		(*memory layout*)
	
	ArrayDim = 12;	(* 1-dim array, dimension offset *)
	FirstArrayElem = 16;	(* 1-dim array, first element offset *)
	
VAR
	fconst: ARRAY 3 OF LONGINT;
	dconst: ARRAY 2, 2 OF LONGINT;
	jcc: ARRAY 6 OF SHORTINT;
	Size: ARRAY 8 OF SHORTINT;
	
	NjavaBytes, NintelBytes, Nticks, Nmethods: ARRAY 10 OF LONGINT;
	NtotTicks, NtotJavaBytes, NtotIntelBytes, NtotMethods: LONGINT;
	
	failureInfo: JC.LoggingInfo;

PROCEDURE Init*(s: PCT.ModScope);
BEGIN
	JC0.pc := 0; JC0.dsize := 0; JC0.csize := 0; JVMRefs.refsize := 0;
	JC0.CodeErr := FALSE; JVMRefs.NewModule(s.firstVar, 0);
	JC0.PutByte(90H);
END Init;

PROCEDURE ArrayPtrOffset():LONGINT;
VAR a: jjlObject.ByteArray;										(* all arrays must have the pointer at the first place *)
BEGIN
	RETURN SYSTEM.ADR(a.p) - SYSTEM.VAL(LONGINT, a);
END ArrayPtrOffset;

(* write the reference section; this information is required for the trap handling *)
PROCEDURE NewMethod(c: JB.RefClass; m: JB.Method; nofParams, nofLocals: LONGINT);
VAR oberonName: JT.StringBuffer;
		name: ARRAY 128 OF CHAR;
		offset: LONGINT; 	
		retType: CHAR;	
BEGIN
	JT.MakeMethodName(m.name.value.p, m.descriptor, m.try = 0, oberonName);
	JT.MakeRefName(c.obobj, oberonName, (JB.AFStatic IN m.flags), name);
	JVMRefs.NewMethod(name, m.p, JC0.pc, nofParams, nofLocals);
END NewMethod;

(* very common code pattern *)
PROCEDURE Pop(wide: BOOLEAN);	(* pop to [EDX:]EAX *)
BEGIN
	JC0.GenPOP(JC0.Regs, EAX, noBase, noInx, noScale, noDisp);
	IF wide THEN
		JC0.GenPOP(JC0.Regs, EDX, noBase, noInx, noScale, noDisp)
	END
END Pop;

PROCEDURE Push(wide: BOOLEAN);	(* push [EDX:]EAX *)
BEGIN
	IF wide THEN
		JC0.GenPUSH(JC0.Regs, EDX, noBase, noInx, noScale, noDisp, noImm)
	END;
	JC0.GenPUSH(JC0.Regs, EAX, noBase, noInx, noScale, noDisp, noImm)
END Push;

PROCEDURE PushF(wide: BOOLEAN);	(* push ST *)
VAR	size: SHORTINT;
BEGIN
	Push(wide);	(*allocate space*)
	IF wide THEN  size := JC0.lReal  ELSE  size := JC0.sReal  END;
	JC0.GenFSTP(JC0.RegMem, size, SP, noInx, noScale, 0);
END PushF;

PROCEDURE PushRetValue(t: PCT.Struct);
BEGIN
	IF t = PCT.NoType THEN
		(* skip, no returned value *)
	ELSIF t = PCT.Float32 THEN
		PushF(FALSE)
	ELSIF t = PCT.Float64 THEN
		PushF(TRUE)
	ELSIF (t = PCT.Bool) OR (t = PCT.Int8) THEN
		JC0.GenMOVSX(JC0.RegReg, 0, EAX, EAX, noInx, noScale, noDisp);
		Push(FALSE)
	ELSIF (t = PCT.Int16) THEN
		JC0.GenMOVSX(JC0.RegReg, 1, EAX, EAX, noInx, noScale, noDisp);
		Push(FALSE)
	ELSIF (t = PCT.Char16) THEN
		JC0.GenMOVZX(JC0.RegReg, 1, EAX, EAX, noInx, noScale, noDisp);
		Push(FALSE)
	ELSE
		Push(t = PCT.Int64)
	END
END PushRetValue;

PROCEDURE PushConst(c: PCT.Const);
	VAR long: JB.Long;
BEGIN
	IF c.type = PCT.Float64 THEN
		long := SYSTEM.VAL(JB.Long, c.real);
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, long.h);
	ELSIF c.type = PCT.Int64 THEN
		long := SYSTEM.VAL(JB.Long, c.long);
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, long.h);
	ELSIF c.type = PCT.Float32 THEN
		long.l := SYSTEM.VAL(LONGINT, SHORT(c.real))
	ELSIF PCT.IsCardinalType(c.type) THEN
		long.l := c.int
	ELSIF c.type = PCT.Ptr THEN
		long.l := SYSTEM.VAL(LONGINT, c.ptr)
	ELSE
		JC.String(failureInfo, "JVMCompiler.PushConst, unknown type"); JC.Ln(failureInfo);
		HALT(99)
	END;
	JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, long.l)
END PushConst;

PROCEDURE Load(base: INTEGER; offset, size: LONGINT);	(* MOV [EDX:]EAX, offset[base] *)
BEGIN
	IF size = ByteSize THEN
		JC0.GenMOVSX(JC0.MemReg, 0, EAX, base, noInx, noScale, offset)
	ELSIF size = ShortSize THEN
		JC0.GenMOVSX(JC0.MemReg, 1, EAX, base, noInx, noScale, offset)
	ELSIF size = CharSize THEN
		JC0.GenTyp1(JC0.XOR, JC0.RegReg, EAX, EAX, noInx, noScale, noDisp, noImm);
		JC0.GenMOV(JC0.MemReg, AX, base, noInx, noScale, offset, noImm)
	ELSIF size = 4 THEN
		JC0.GenMOV(JC0.MemReg, EAX, base, noInx, noScale, offset, noImm)
	ELSIF size = 8 THEN
		JC0.GenMOV(JC0.MemReg, EAX, base, noInx, noScale, offset, noImm);
		JC0.GenMOV(JC0.MemReg, EDX, base, noInx, noScale, offset+4, noImm)
	ELSE
		HALT(99)
	END
END Load;

PROCEDURE Store(base: INTEGER; offset, size: LONGINT);	(* MOV offset[base], [EDX:]EAX *)
BEGIN
	IF size = ByteSize THEN
		JC0.GenMOV(JC0.RegMem, AL, base, noInx, noScale, offset, noImm)
	ELSIF (size = ShortSize) OR (size = CharSize) THEN
		JC0.GenMOV(JC0.RegMem, AX, base, noInx, noScale, offset, noImm)
	ELSIF size = 4 THEN
		JC0.GenMOV(JC0.RegMem, EAX, base, noInx, noScale, offset, noImm)
	ELSIF size = 8 THEN
		JC0.GenMOV(JC0.RegMem, EAX, base, noInx, noScale, offset, noImm);
		JC0.GenMOV(JC0.RegMem, EDX, base, noInx, noScale, offset+4, noImm)
	ELSE
		HALT(99)
	END
END Store;

PROCEDURE LoadScaled(base, index: INTEGER; offset, size: LONGINT);	(* MOV [EDX:]EAX, offset[base][index*size] *)
BEGIN
	IF size = ByteSize THEN
		JC0.GenMOVSX(JC0.MemReg, 0, EAX, base, index, JC0.Scale1, offset)
	ELSIF size = ShortSize THEN
		JC0.GenMOVSX(JC0.MemReg, 1, EAX, base, index, JC0.Scale2, offset)
	ELSIF size = CharSize THEN
		JC0.GenTyp1(JC0.XOR, JC0.RegReg, EAX, EAX, noInx, noScale, noDisp, noImm);
		JC0.GenMOV(JC0.MemReg, AX, base, index, JC0.Scale2, offset, noImm)
	ELSIF size = 4 THEN
		JC0.GenMOV(JC0.MemReg, EAX, base, index, JC0.Scale4, offset, noImm)
	ELSIF size = 8 THEN
		JC0.GenMOV(JC0.MemReg, EAX, base, index, JC0.Scale8, offset, noImm);
		JC0.GenMOV(JC0.MemReg, EDX, base, index, JC0.Scale8, 4+offset, noImm)
	ELSE
		HALT(99)
	END
END LoadScaled;

PROCEDURE StoreScaled(base, index: INTEGER; offset, size: LONGINT);	(* MOV offset[base][index*size], [EDX:]EAX *)
BEGIN
	IF size = ByteSize THEN
		JC0.GenMOV(JC0.RegMem, AL, base, index, JC0.Scale1, offset, noImm)
	ELSIF (size = ShortSize) OR (size = CharSize) THEN
		JC0.GenMOV(JC0.RegMem, AX, base, index, JC0.Scale2, offset, noImm)
	ELSIF size = 4 THEN
		JC0.GenMOV(JC0.RegMem, EAX, base, index, JC0.Scale4, offset, noImm)
	ELSIF size = 8 THEN
		JC0.GenMOV(JC0.RegMem, EAX, base, index, JC0.Scale8, offset, noImm);
		JC0.GenMOV(JC0.RegMem, EDX, base, index, JC0.Scale8, 4+offset, noImm)
	ELSE
		HALT(99)
	END
END StoreScaled;

PROCEDURE LoadST(base: INTEGER; offset, type: LONGINT);
BEGIN
	JC0.GenFop2(JC0.FFREE, 7);
	IF type = JavaINT THEN
		JC0.GenFLD(JC0.Mem, JC0.sInt, base, noInx, noScale, offset)
	ELSIF type = JavaLONG THEN
		JC0.GenFLD(JC0.Mem, JC0.lInt, base, noInx, noScale, offset)
	ELSIF type = JavaFLOAT THEN
		JC0.GenFLD(JC0.Mem, JC0.sReal, base, noInx, noScale, offset)
	ELSIF type = JavaDOUBLE THEN
		JC0.GenFLD(JC0.Mem, JC0.lReal, base, noInx, noScale, offset)
	ELSE
		HALT(99)
	END
END LoadST;

PROCEDURE StoreST(base: INTEGER; offset, type: LONGINT);
BEGIN
	IF type = JavaINT THEN
		JC0.GenFSTP(JC0.RegMem, JC0.sInt, base, noInx, noScale, offset)
	ELSIF type = JavaLONG THEN
		JC0.GenFSTP(JC0.RegMem, JC0.lInt, base, noInx, noScale, offset)
	ELSIF type = JavaFLOAT THEN
		JC0.GenFSTP(JC0.RegMem, JC0.sReal, base, noInx, noScale, offset)
	ELSIF type = JavaDOUBLE THEN
		JC0.GenFSTP(JC0.RegMem, JC0.lReal, base, noInx, noScale, offset)
	ELSE
		HALT(99)
	END
END StoreST;

(* EncodeMethod - compile a method from byte-code to i386 code
		(* in *) c: class containing the method
		(* in *) mno: method number (c.methods[mno])
		(* in *) code: byte-code
		(* out *) moffset: method entry point
		(* out *) map: table for mapping byte-code to native code offsets
*)

PROCEDURE EncodeMethod*(c: JB.RefClass; mno: LONGINT; code: JB.ACodeInfo; VAR moffset: LONGINT; VAR map: JB.Map);
VAR pc, pc0, op, index, val, offset, type, dummy, s, off: LONGINT; opc, size: SHORTINT;
	long: (*JT.*)JB.Long; wide, super, noPars: BOOLEAN;
	cf: JB.Class; of: JB.ObjectClass; ref: JB.CRefInfo; m: JB.Method;
	rf: JB.RefClass;
	const: JB.ConstPool; nofParams, nofLocals: LONGINT;	(*cached values*)
	default, npairs, match: LONGINT;
	stop, bytes, i: LONGINT; start: AosKernel.MilliTimer;
	ticks: HUGEINT;
	module, method: ARRAY 256 OF CHAR;

	PROCEDURE GetClass(ci :JB.CInfo): JB.Class;
	VAR class: JB.CClassInfo;
	BEGIN
		class := ci(JB.CClassInfo);
		IF class.class = NIL THEN class.class := JB.ThisClass(class.index.str, TRUE) END;
		RETURN class.class
	END GetClass;
	
	PROCEDURE Undef(opcode: LONGINT);
	BEGIN
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, 10000 + opcode);
		JC0.PutByte(0CCH);	(*HALT*)
		JC.String(failureInfo, "Compiler: Undefined opcode "); JC.Int(failureInfo, op, 0); JC.Ln(failureInfo)
	END Undef;

	PROCEDURE Index(wide: BOOLEAN): LONGINT;	(* get 8/16 bit unsigned index *)
	VAR i: LONGINT;
	BEGIN
		i := ORD(code.code[pc]); INC(pc);
		IF wide THEN i := 100H*i + ORD(code.code[pc]); INC(pc) END;
		RETURN i
	END Index;
	
	PROCEDURE Value(size: LONGINT): LONGINT;	(* get 1/2/4 bytes signed value *)
	VAR i, cnt: LONGINT;
	BEGIN
		
		cnt := size-1; i := ORD(code.code[pc]); INC(pc);		
		IF i >= 128 THEN i := i -256  END; 	(*mac bug: internal representation always 32bit*)
		WHILE cnt > 0 DO			
			DEC(cnt); i := ASH(i, 8) + ORD(code.code[pc]); INC(pc)
		END;
		RETURN i
	END Value;

	PROCEDURE FpOffset(index: LONGINT): LONGINT;
	BEGIN
		IF JB.AFStatic IN c.methods[mno].flags THEN
			IF index >= nofParams THEN	(*local var*)
				RETURN 4*(nofParams - index) - 4
			ELSE
				RETURN 4*(nofParams - index) + 4
			END
		ELSE
			IF index >= nofParams THEN	(*local var*)
				RETURN 4*(nofParams - index) - 4
			ELSIF index = 0 THEN
				RETURN 8
			ELSE
				RETURN 4*(nofParams - index) + 8
			END
		END;
	END FpOffset;
	
	
	
	PROCEDURE FixupFwdJmps(addr: LONGINT);
	VAR next: LONGINT;
	BEGIN
		WHILE addr # 0 DO
			JC0.GetDWord(addr, next); JC0.PutDWordAt(addr, JC0.pc-addr-4);
			addr := next-10000H
		END
	END FixupFwdJmps;
	
	PROCEDURE Jcc(cc :SHORTINT; offset: LONGINT);
	VAR  val: LONGINT;
	BEGIN
		IF offset <= 0 THEN
			val := map[pc0+offset]-(JC0.pc+2);
			IF cc = JMP THEN
				DEC(val, 3)	(*always 32 bit*)
			ELSIF val < -128 THEN
				IF (cc = CALL) THEN DEC(val, 3) 	(* disp32 - disp8 *)
				ELSE DEC(val, 4) END;	(* disp32 - disp8 + add.opcode *)
			END
		ELSE
			val := map[pc0+offset]+10000H;
		END;
		IF cc = JMP THEN
			JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, val, TRUE)
		ELSIF cc = CALL THEN
			JC0.GenCALL(JC0.Imme, 0, noBase, noInx, noScale, val)
		ELSE
			JC0.GenJcc(cc, val)
		END;
		IF offset > 0 THEN  map[pc0+offset] := JC0.pc-4  END
	END Jcc;
	
	PROCEDURE SystemCall(call: LONGINT);
	BEGIN
		JC0.GenCALL(JC0.Imme, 0, noBase, noInx, noScale, c.fixsyscalls[call]+10000H);
		c.fixsyscalls[call] := JC0.pc - 4
	END SystemCall;
	
	PROCEDURE ThrowExceptionClass(c: JB.Class);
	BEGIN
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, c));
		SystemCall(JB.SCNew);
		Push(FALSE);
		SystemCall(JB.SCThrow)
	END ThrowExceptionClass;
	
	PROCEDURE Throw(nr: LONGINT);	(*generate code to throw an exception*)
	BEGIN		
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, nr);
		JC0.GenINT(3)
	END Throw;
	
	PROCEDURE IndexCheck(ref, len: SHORTINT);
	VAR pc: LONGINT;
	BEGIN
		JC0.GenTyp1(JC0.CMP, JC0.MemReg, len, ref, noInx, noScale, ArrayDim, noImm);
		pc := JC0.pc;
		JC0.GenJcc(JC0.JNAE, 0);		
		Throw(7);		
		JC0.PutByteAt(pc+1, SHORT(JC0.pc-pc-2))
	END IndexCheck;
	
	PROCEDURE Monitor(lock: BOOLEAN);
	BEGIN
		(* the paremeter is already on the stack; the other one has to be pushed *)
		IF lock THEN SystemCall(JB.SCLock) ELSE SystemCall(JB.SCUnlock) END
	END Monitor;
	
	PROCEDURE CheckInitialized(cf: JB.Class);
	BEGIN
		IF cf.state < JB.Initialized THEN
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, cf));
			SystemCall(JB.SCCheckInitialized);			
		END;
	END CheckInitialized;
	
	PROCEDURE MultianewArray(cf: JB.Class; dim: LONGINT);
	BEGIN
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, cf));	(*push parameters for syscall *)
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, dim));
		SystemCall(JB.SCMultianewArray);
		JC0.GenTyp1(JC0.ADD, JC0.ImmReg, SP, 0, noInx, noScale, noDisp, dim*4); 	(* remove dimensions of array *)
		Push(FALSE);																									   (* push array reference on the stack *)
	END MultianewArray;
	
	PROCEDURE InvokeInterface(index, count :LONGINT);
	VAR ref: JB.CRefInfo; mth: JB.Method; cls: JB.InterfaceClass; inttd, offset: LONGINT; m: JB.Method;
	BEGIN
		IF (index >= LEN(const^)) 								  OR
			(const[index].tag#JB.CInterfaceMethodref) 	OR
			(const[index](JB.CRefInfo).ref = NIL) 			THEN (* Throw("java/lang/NoSuchMethodError") *)
		END;
		ref := const[index](JB.CRefInfo); cls := ref.cindex.class(JB.InterfaceClass);
		mth := ref.ref(JB.Method);
		inttd := SYSTEM.VAL(LONGINT, cls.typedesc.tag);							(* here the effective typedesriptor is required; not the  tag *)
		(*Load(SP, mth.parsize, 4); NilCheck(EAX); *)
		(* self to invoke interface procedure *)
		Load(SP, mth.parsize-4, 4); (*NilCheck(EAX); *)
		Push(FALSE);																				(*push self as last parameter, oberon calling convention*)	
		(* parameters to invoke InterfaceLookup *)
		JC0.GenPUSH(JC0.Mem, 0, EAX, noInx, noScale, -4, noImm);   		 (* typedescriptor of object as first parameter *) 
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, inttd); (* typedescriptor of interface as second parameter *)											
		SystemCall(JB.SCILookup); 																(* invoke Lookup procedure *)
		(* after this call, the adress of the v-table is in eax *)			
		offset := mth.p.adr(PCBT.Method).mthNo*4;
		Load(EAX, offset+4, 4);							 		(* get Method in vtbl *)
		JC0.GenCALL(JC0.Regs, EAX, noBase, noInx, noScale, noDisp);	     (* now invoke the interface procedure *)
		m := ref.ref(JB.Method);
		JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);
		PushRetValue(m.p.type);
	END InvokeInterface;
	
	PROCEDURE LShiftLeft;
	VAR pc1, pc2: LONGINT;
	BEGIN
		JC0.GenPOP(JC0.Regs, ECX, noBase, noInx, noScale, noDisp); 							(* pop shift count *)
		JC0.GenTyp1(JC0.AND, JC0.ImmReg, ECX, noBase, noInx, noScale, noDisp, 03FH); (* [1], lshl notes, p.305 *)
		JC0.GenPOP(JC0.Regs, EAX, noBase, noInx, noScale, noDisp); 							(* pop low *)
		(* long shift may shift over 64 bits, but the shld shifts only 32 bits 
			long values may be shifted more than 31 *)
		JC0.GenTyp1(JC0.CMP, JC0.ImmReg, ECX, noBase, noInx, noScale, noDisp, 31); 
		pc1 := JC0.pc;
		JC0.GenJcc(JC0.JG, 0); 	
		(* if less or equal 31 *)
		JC0.GenSHDouble(JC0.Left, JC0.RegMem, TRUE, EAX, SP, noInx, noScale, noDisp, noImm);										(* high word is shifted *)
		JC0.GenShiftRot(JC0.SAL, JC0.RegReg, EAX, noBase, noInx, noScale, 0, noImm); (* low word is shifted *)
		Push(FALSE); pc2 := JC0.pc; 																				  (* low word is pushed *)		
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 0, FALSE);							   (* jump to the end *)
		JC0.PutByteAt(pc1+1, SHORT(JC0.pc-pc1-2));
		(* if greater then 31 *)
		JC0.GenPOP(JC0.Regs, EDX, noBase, noInx, noScale, noDisp); 							(* pop high *)
		JC0.GenTyp1(JC0.SUB, JC0.ImmReg, ECX, noBase, noInx, noScale, 0, 32);		    (* reduce shift count *)
		JC0.GenShiftRot(JC0.SAL, JC0.RegReg, EAX, noBase, noInx, noScale, 0, noImm); (* shift high word *)
		JC0.GenTyp1(JC0.XOR, JC0.RegReg, EDX, EDX, noInx, noScale, noDisp, noImm); (* low word becomes 0 *)
		(* push result *)
		JC0.GenPUSH(JC0.Regs, EAX, noBase, noInx, noScale, noDisp, noImm);			 (* eax becomes high word *)
		JC0.GenPUSH(JC0.Regs, EDX, noBase, noInx, noScale, noDisp, noImm);			 (* low word is zero *)																										  
		JC0.PutByteAt(pc2+1, SHORT(JC0.pc-pc2-2));
	END LShiftLeft;
	
	PROCEDURE LShiftRight(arithmetic: BOOLEAN);
	VAR pc1, pc2: LONGINT;
			op: SHORTINT;
	BEGIN
		IF arithmetic THEN op := JC0.SAR ELSE op := JC0.SHR END;				(* arithmetic or logical shift *)
		JC0.GenPOP(JC0.Regs, ECX, noBase, noInx, noScale, noDisp); 							(* pop shift count *)		
		JC0.GenTyp1(JC0.AND, JC0.ImmReg, ECX, noBase, noInx, noScale, noDisp, 03FH); (* [1], lshr notes, p.306 *)
		JC0.GenMOV(JC0.MemReg, EDX, SP, noInx, noScale, 4, noImm);      				(* load high into EDX => op2 *)
		(* long shift may shift over 64 bits, but the shld shifts only 32 bits 
			long values may be shifted more than 31 *)
		JC0.GenTyp1(JC0.CMP, JC0.ImmReg, ECX, noBase, noInx, noScale, noDisp, 31); 
		pc1 := JC0.pc;
		JC0.GenJcc(JC0.JG, 0); 
		JC0.GenSHDouble(JC0.Right, JC0.RegMem, TRUE, EDX, SP, noInx, noScale, noDisp, noImm);						  (* low word is shifted *)																						
		JC0.GenShiftRot(op, JC0.RegReg, EDX, noBase, noInx, noScale, 0, noImm);		(* high word is shifted *)
		JC0.GenMOV(JC0.RegMem, EDX, SP, noInx, noScale, 4, noImm);				 		(* high word is stored back *)
		pc2 := JC0.pc;		
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 0, FALSE);
		JC0.PutByteAt(pc1+1, SHORT(JC0.pc-pc1-2));
		(* if greater then 31 *)
		JC0.GenTyp1(JC0.SUB, JC0.ImmReg, ECX, noBase, noInx, noScale, 0, 32);		    	(* reduce shift count *)		
		JC0.GenMOV(JC0.RegReg, EAX, EDX, noInx, noScale, noDisp, noImm);
		JC0.GenShiftRot(op, JC0.RegReg, EAX, noBase, noInx, noScale, noDisp, noImm);	(* shift out high word *)		
		JC0.PutByte(JC0.CWD);
		
		(* store result *)
		JC0.GenMOV(JC0.RegMem, EAX, SP, noInx, noScale, noDisp, noImm);					(* high word is   zero      *)
		JC0.GenMOV(JC0.RegMem, EDX, SP, noInx, noScale, 4, noImm);							(* low word is shifted eax *)
		JC0.PutByteAt(pc2+1, SHORT(JC0.pc-pc2-2));																												
	END LShiftRight;
	
	PROCEDURE FloatCompare(type: SHORTINT; flag: BOOLEAN);
	VAR pc1, pc2, pc3, pc4, pc5, pc6, imm: LONGINT;
	BEGIN
		JC0.GenFLD(JC0.Mem, type, SP, noInx, noScale, 0);		 							(* load into floating point unit *)		
		Pop(type = JC0.lReal);  																				(* and remove from stack *)		
		JC0.GenFLD(JC0.Mem, type, SP, noInx, noScale, 0); 									(* load into floating point unit *)
		Pop(type = JC0.lReal);	  																			(* and remove from stack *)
		JC0.GenFop1(JC0.FCOMPP);																		 (* compare *)
		JC0.GenFop1(JC0.FSTSW);																			(* store status word in ax *)
		JC0.PutByte(JC0.SAHF);																				(* set condition codes *)
		pc1 := JC0.pc;
		JC0.GenJcc(JC0.JP, 0);																					(* if unorderd *)
		pc2 := JC0.pc;
		JC0.GenJcc(JC0.JA, 0);																					(* if greater *)
		pc3 := JC0.pc;
		JC0.GenJcc(JC0.JB, 0);																				   (* if less *)
		(* else equal *)
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, 0);				 (* result = 0 *)
		pc4 := JC0.pc;
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 0, FALSE);					(* goto end *)
(*
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 10, FALSE);					(* goto end *)
*)
		JC0.PutByteAt(pc1+1, SHORT(JC0.pc-pc1-2));
		(* error *)
		IF flag THEN imm := 1 ELSE imm := -1 END;
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, imm);
		pc5 := JC0.pc;
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 0, FALSE); 				(* goto end *)
(*
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 6, FALSE); 				(* goto end *)
*)
		JC0.PutByteAt(pc2+1, SHORT(JC0.pc-pc2-2));										(* 4 bytes *)
		(* greater *)
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, 1);			  (* result = 1 *)
		pc6 := JC0.pc;
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 0, FALSE); 				(* goto end *)
(*
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 2, FALSE); 				 (* goto end *)
*)
		JC0.PutByteAt(pc3+1, SHORT(JC0.pc-pc3-2));								(* 4 bytes *)
		(* less *)
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, -1);				(* result = -1 *)
																													(* 2 bytes *)		
		(* exit *)		
		JC0.PutByteAt(pc4+1, SHORT(JC0.pc-pc4-2));
		JC0.PutByteAt(pc5+1, SHORT(JC0.pc-pc5-2));
		JC0.PutByteAt(pc6+1, SHORT(JC0.pc-pc6-2));
	END FloatCompare;	
	
	PROCEDURE RetFinally(index: LONGINT);
	BEGIN
		JC0.GenPUSH(JC0.Mem, 0, FP, noInx, noScale, FpOffset(index), noImm);
		JC0.GenRET(0)
	END RetFinally;
	
	PROCEDURE TableSwitch;
	VAR count, default, low, high, i,  pc2, pc3: LONGINT;
	BEGIN
		INC(pc, 1+(-pc-1) MOD 4);	(*padding*)
		default := Value(4); low := Value(4); high := Value(4);
		count := high - low + 1; 
		Pop(FALSE);																			  								           (* load index into eax *)			
		JC0.GenTyp1(JC0.SUB, JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, low);             (* index into jump table *)
		JC0.GenTyp1(JC0.CMP, JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, high-low); 	(* compare to high *)		
		pc2 := JC0.pc;
		JC0.GenJcc(JC0.JNBE, 0);
		pc3 := JC0.pc;
		JC0.GenCALL(JC0.Imme, 0, noBase, noInx, noScale, 0);												(* get the current pc *)
		JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);	
		
		JC0.GenMOV(JC0.RegReg, ECX, EAX, noInx, noScale, noDisp, noImm);						(* avoid mul *)
		JC0.GenShiftRot(JC0.SAL, JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, 2);        (* index* 4 *)
		JC0.GenTyp1(JC0.ADD, JC0.RegReg, EAX, ECX, noInx, noScale, noDisp, noImm);         (* + index   *)
	
		JC0.GenTyp1(JC0.ADD, JC0.RegReg, EAX, EBX, noInx, noScale, noDisp, noImm);
		JC0.GenTyp1(JC0.ADD, JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, JC0.pc-pc3+2); (* get the absolut adress *)
		
		JC0.GenJMP(JC0.Regs, EAX, noBase, noInx, noScale, noDisp, FALSE);	(* now jump into the table *)
		WHILE i < count DO offset := Value(4); 												(* table consist of a sequence of jmp instructions *)			
			Jcc(JMP, offset);
			INC(i) 
		END;		
		JC0.PutByteAt(pc2+1, SHORT(JC0.pc-pc2-2));
		Jcc(JMP, default)																			(* default *)
	END TableSwitch;
	
	PROCEDURE Synchronize(c: JB.Class; enter: BOOLEAN);	
	BEGIN
		(* push parameters for system call; first parameter = object to lock*)
		IF c # NIL THEN	(* static => lock class object *)
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, 
			SYSTEM.VAL(LONGINT, c));												
		ELSE 					(* non static => lock self *)
			JC0.GenPUSH(JC0.Mem, 0, FP, noInx, noScale, FpOffset(0), noImm);
		END;		
		IF enter THEN SystemCall(JB.SCLock)
		ELSE SystemCall(JB.SCUnlock)
		END				
	END Synchronize;
	
	PROCEDURE LongDiv(op: LONGINT);
	VAR pc1, pc2: LONGINT; 
	BEGIN		
	(* explicit test for division by zero
		the frem instruction does not throw any exception *)
		JC0.GenTyp1(JC0.CMP, JC0.ImmMem, 0, SP, noInx, noScale, noDisp, 0);
		pc1 := JC0.pc;
		JC0.GenJcc(JC0.JNE, 0);		
		JC0.GenTyp1(JC0.CMP, JC0.ImmMem, 0, SP, noInx, noScale, 4, 0);
		pc2 := JC0.pc;
		JC0.GenJcc(JC0.JNE, 0);
		Throw(jjlThrowable.LDivZero);
		JC0.PutByteAt(pc1+1, SHORT(JC0.pc-pc1-2));
		JC0.PutByteAt(pc2+1, SHORT(JC0.pc-pc2-2));
		(* set rounding to truncate;  division by zero is checked expicitly *)
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, JS.RCHOP);		
		JC0.GenFLDCW(SP, noInx, noScale, noDisp);
		Pop(FALSE);		
		LoadST(SP, 0, JavaLONG);	(*first 8 bytes *)
		IF op = 109 THEN
			Pop(FALSE); Pop(FALSE);			
			LoadST(SP, 0, JavaLONG);						 
			(* ldiv *) JC0.GenFtyp1(6,JC0.StRegP, 0, 1, noInx, noScale, 0);
			StoreST(SP, 0, JavaLONG);
		ELSE (*lrem *) 
			LoadST(SP, 8, JavaLONG);
			JC0.GenFop1(JC0.FPREM) ;
			StoreST(SP, 8, JavaLONG);
			StoreST(SP, 0, JavaLONG);
			Pop(FALSE); Pop(FALSE)
		END;
		JC0.GenFLDCW(noBase, noInx, noScale, SYSTEM.ADR(AosBoot.fcr));
	END LongDiv;
	
BEGIN
	AosKernel.SetTimer(start, 0);
	moffset := JC0.pc;
	
	IF (map = NIL) OR (LEN(code.code^) > LEN(map)) THEN
		NEW(map, LEN(code.code^))
	END;
	FOR pc := 0 TO LEN(map)-1 DO  map[pc] := 0  END;
	pc := 0; wide := FALSE;
	const := c.constPool; 
	nofParams := c.methods[mno].parsize DIV 4;
	IF (JB.AFStatic IN c.methods[mno].flags)&(code.maxLocals-nofParams > 0) THEN
		nofLocals := code.maxLocals-nofParams 
	ELSE nofLocals := code.maxLocals-nofParams + 1
	END;
	
	IF (JB.AFStatic IN c.methods[mno].flags) THEN
		NewMethod(c, c.methods[mno], nofParams, nofLocals)
	ELSE
		NewMethod(c, c.methods[mno], nofParams, nofLocals)
	END;
	
	IF BenchTiming THEN
		ticks := AosBoot.GetTimer();
	END;

	JC0.GenPUSH(JC0.Regs, FP, noBase, noInx, noScale, noDisp, noImm);
	JC0.GenMOV(JC0.RegReg, FP, SP, noInx, noScale, noDisp, noImm);
	
	IF nofLocals > 0 THEN JC0.SubSPIMM32(4*nofLocals)
		(*JC0.GenTyp1(JC0.SUB, JC0.ImmReg, SP, noBase, noInx, noScale, noDisp, 4*nofLocals)*)
	END;
	
	(* abstract methods have a default body -> runtime exception in case of invokation*)
	IF JB.AFAbstract IN c.methods[mno].flags THEN
		Throw(jjlThrowable.AbstractMethodError);
		JC0.GenMOV(JC0.RegReg, SP, FP, noInx, noScale, noDisp, noImm);
		JC0.GenPOP(JC0.Regs, FP, noBase, noInx, noScale, noDisp);
		JC0.GenRET(nofParams*4);
		RETURN
	END;
	
	IF  TraceMethods THEN SystemCall(JB.SCTrace) END;

	(* if the method is synchronized *)
	IF JB.AFSynchronized IN c.methods[mno].flags THEN (* lock the object or the class*)
		IF JB.AFStatic IN c.methods[mno].flags THEN
			Synchronize(c, TRUE)
		ELSE
			Synchronize(NIL, TRUE)
		END
	END;
	
	
	WHILE pc < LEN(code.code^) DO
		INC(bytes);
		pc0 := pc; op := ORD(code.code[pc]);
		ASSERT(~wide OR ((op>=26)&(op<=45)OR(op>=54)&(op<=78)OR(op=132)OR(op=189)));
		FixupFwdJmps(map[pc]); 
		map[pc] := JC0.pc;
		CASE op OF
		  0: (* nop *)
			INC(pc)
		| 1: (* aconst-null *)
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, NULL);
			INC(pc)
		| 2..8: (* iconst-<n> *)
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, op-3);
			INC(pc)
		| 9..10: (* lconst-<n> *)
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, 0);
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, op-9);
			INC(pc)
		| 11..13: (* fconst_<n> *)
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, fconst[op-11]);
			INC(pc)
		| 14..15: (* dconst-<n> *)
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, dconst[op-14,1]);
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, dconst[op-14,0]);
			INC(pc)
		| 16: (* bipush *)
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(SHORTINT, code.code[pc+1]));
			INC(pc, 2)
		| 17: (* sipush *)
			INC(pc); val := Value(2);
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(INTEGER, val));
		| 18, 19, 20: (* ldc/ldc-w/ldc2 *)
			INC(pc); index := Index(op#18);
			PushConst(const[index](JB.CConstInfo).c)
		| 21..25, (* iload / lload / fload / dload / aload  *)
		  26..45: (* iload-<n> / lload-<n> / fload-<n> / dload-<n> / aload-<n> *)
			INC(pc); 
			IF op <= 25 THEN
				index := Index(wide); type := op-21; wide := FALSE
			ELSE
				index := (op-26) MOD 4; type := (op-26) DIV 4
			END;
			JC0.GenPUSH(JC0.Mem, 0, FP, noInx, noScale, FpOffset(index), noImm);
			IF type IN {JavaLONG, JavaDOUBLE} THEN
				JC0.GenPUSH(JC0.Mem, 0, FP, noInx, noScale, FpOffset(index+1), noImm)
			END
		| 46..53, 79..86: (* ?aload / ?astore *)
			size := Size[(op-46) MOD (79-46)];
			IF op>=79 THEN  Pop(size=8)  END;
			JC0.GenPOP(JC0.Regs, ECX, noBase, noInx, noScale, noDisp);	(*index*)
			JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);	(*reference*)
			(*NilCheck(EBX);	*)	(* EBX: Pointer to Record...*)
			JC0.GenMOV(JC0.MemReg, EBX, EBX, noInx, noScale, ArrayPtrOffset(), noImm);    (* deref obj.p *)		
			IndexCheck(EBX, ECX);
			IF op <= 53 THEN
				LoadScaled(EBX, ECX, FirstArrayElem, size); Push(size=8)
			ELSE
				StoreScaled(EBX, ECX, FirstArrayElem, size)
			END;
			INC(pc);
		| 54..78 : (* ?store / ?store-<n>  *)                                                 
			INC(pc);
			IF op <= 58 THEN
				index := Index(wide); type := op-54; wide := FALSE
			ELSE
				index := (op-59) MOD 4; type := (op-59) DIV 4
			END;
			(* JC0.GenPOP(JC0.Mem, 0, FP, noInx, noScale, FpOffset(index)); *)
			IF type IN {JavaLONG, JavaDOUBLE} THEN
				JC0.GenPOP(JC0.Mem, 0, FP, noInx, noScale, FpOffset(index+1));
			END;
			JC0.GenPOP(JC0.Mem, 0, FP, noInx, noScale, FpOffset(index))
		| 87, 88: (* pop / pop2 *)
			Pop(op=88); INC(pc)
		| 89: (* dup *)
			JC0.GenPUSH(JC0.Mem, 0, SP, noInx, noScale, 0, noImm);
			INC(pc)
		| 90: (* dup-x1 *)
			Pop(TRUE); Push(FALSE); Push(TRUE);
			INC(pc)
		| 91, 93: (* dup-x2 / dup2-x1 *)
			Pop(TRUE);	(*EDX:EAX*)
			JC0.GenPOP(JC0.Regs, ECX, noBase, noInx, noScale, noDisp);
			Push(op = 93);	(*[EDX:]EAX*)
			JC0.GenPUSH(JC0.Regs, ECX, noBase, noInx, noScale, noDisp, noImm);
			Push(TRUE);	(*EDX:EAX*)
			INC(pc)
		| 92: (* dup2 *)
			JC0.GenPUSH(JC0.Mem, 0, SP, noInx, noScale, 4, noImm);
			JC0.GenPUSH(JC0.Mem, 0, SP, noInx, noScale, 4, noImm);
			INC(pc)
		| 94: (* dup2-x2 *)
			Pop(TRUE);
			JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);
			JC0.GenPOP(JC0.Regs, ECX, noBase, noInx, noScale, noDisp);
			Push(TRUE);
			JC0.GenPUSH(JC0.Regs, ECX, noBase, noInx, noScale, noDisp, noImm);
			JC0.GenPUSH(JC0.Regs, EBX, noBase, noInx, noScale, noDisp, noImm);
			Push(TRUE);
			INC(pc)
		| 95: (* swap *)
			JC0.GenPOP(JC0.Regs, EAX, noBase, noInx, noScale, noDisp);
			JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);
			JC0.GenPUSH(JC0.Regs, EAX, noBase, noInx, noScale, noDisp, noImm);
			JC0.GenPUSH(JC0.Regs, EBX, noBase, noInx, noScale, noDisp, noImm);
			INC(pc)
		| 96, 100, 104,126, 128, 130 :
			(* iadd / isub / imul / iand / ior /ixor *)
			Pop(FALSE);
			IF op = 96 THEN	JC0.GenTyp1(JC0.ADD, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm);
			ELSIF op = 100 THEN	JC0.GenTyp1(JC0.SUB, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm);
			ELSIF op = 126 THEN	JC0.GenTyp1(JC0.AND, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm);
			ELSIF op = 128 THEN	JC0.GenTyp1(JC0.Or, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm);
			ELSIF op = 130 THEN	JC0.GenTyp1(JC0.XOR, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm);
			ELSIF op = 104 THEN
				JC0.GenIMUL(JC0.MemReg, TRUE, 0, SP, noInx, noScale, 0, noImm);
				Store(SP, 0, 4)		(* only lsb *)
			END;
			INC(pc)
		| 108, 112 :	(* idiv / irem corrected rl 04.01.01*)
			INC(pc);
			JC0.GenPOP(JC0.Regs, ECX, noBase, noInx, noScale, noDisp);	(*divisor*)
			Pop(FALSE); JC0.PutByte(JC0.CWD);	(* dividend, EAX -> EDX:EAX *)
			JC0.GenIDIV(JC0.RegReg, ECX, EAX, noInx, noScale, noDisp);
			IF op = 108 THEN	Push(FALSE)	(*quotient*)
			ELSE JC0.GenPUSH(JC0.Regs, EDX, noBase, noInx, noScale, noDisp, noImm)	(*reminder*)
			END
		| 97, 101:  (* ladd / lsub *)
			Pop(TRUE);	(*value1 -> EDX:EAX*)
			IF op = 97 THEN
				JC0.GenTyp1(JC0.ADD, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm);
				JC0.GenTyp1(JC0.ADC, JC0.RegMem, EDX, SP, noInx, noScale, 4, noImm)
			ELSE
				JC0.GenTyp1(JC0.SUB, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm);
				JC0.GenTyp1(JC0.SBB, JC0.RegMem, EDX, SP, noInx, noScale, 4, noImm)
			END;
			INC(pc)
		| 98,99, 102,103, 106,107, 110, 111: (* ?add / ?sub / ?mul / ?div / ?neg *)
			type := (op-96) MOD 4;
			IF type = JavaFLOAT THEN size := 0 ELSE size := 2 END;
			LoadST(SP, 0, type);
			Pop(FALSE);	(*adjust stack; corrected *)
			IF Size[type] = 8 THEN Pop(FALSE) END;
			op := (op-97) DIV 4;
			CASE op OF
			| 0 (*?add*): JC0.GenFADD(JC0.MemSt, size, SP, noInx, noScale, 0)
			| 1 (*?sub*): JC0.GenFSUB(JC0.MemSt, size, SP, noInx, noScale, 0)
			| 2 (*?mul*): JC0.GenFMUL(JC0.MemSt, size, SP, noInx, noScale, 0)
			| 3 (*?div*): JC0.GenFDIVR(JC0.MemSt, size, SP, noInx, noScale, 0)																										
			END;
			StoreST(SP, 0, type);
			JC0.PutByte(JC0.WAIT); 
			INC(pc)		
		| 105: (* can not be done in the fpu because of the overflow handling *)
			JC0.GenMOV(JC0.MemReg, EAX, SP, noInx, noScale, 8, noImm);
			JC0.GenMOV(JC0.MemReg, ECX, SP, noInx, noScale, 12, noImm);
			JC0.PutByte(0F7H); JC0.PutByte(24H); JC0.PutByte(24H); (* MUL 0[ESP] *)
			JC0.GenIMUL(JC0.MemReg, FALSE, ECX, SP, noInx, noScale, noDisp, noImm);
			JC0.GenTyp1(JC0.ADD, JC0.RegReg, EDX, ECX, noInx, noScale, noDisp, noImm);
			JC0.GenMOV(JC0.MemReg, ECX, SP, noInx, noScale, 4, noImm);
			JC0.GenIMUL(JC0.MemReg, FALSE, ECX, SP, noInx, noScale, 8, noImm);
			JC0.GenTyp1(JC0.ADD, JC0.RegReg, EDX, ECX, noInx, noScale, noDisp, noImm);
			JC0.GenTyp1(JC0.ADD, JC0.ImmReg, SP, 0, noInx, noScale, noDisp, 8);
			JC0.GenMOV(JC0.RegMem, EAX, SP, noInx, noScale, 0 ,noImm);
			JC0.GenMOV(JC0.RegMem, EDX, SP, noInx, noScale, 4, noImm);
			INC(pc)
		|  109, 113: (*ldiv, lrem -> since a MOD 0 has to throw an exception *)			
			LongDiv(op);
			INC(pc)
		| 114, 115: (*frem, drem *)		
			type := (op-96) MOD 4;		
			LoadST(SP, 0, type);	LoadST(SP, 8, type);
			JC0.GenFop1(JC0.FPREM);
			StoreST(SP, 8, type);  StoreST(SP, 0, type);			
			JC0.PutByte(JC0.WAIT);
			Pop(Size[type] = 8);
			INC(pc)
		| 116: (* ineg *)
			JC0.GenNEG(JC0.Mem, 0, SP, noInx, noScale, 0);
			INC(pc)
		| 117: (* lneg *)
			JC0.GenNEG(JC0.Mem, 0, SP, noInx, noScale, 4);
			JC0.GenNEG(JC0.Mem, 0, SP, noInx, noScale, 0);
			JC0.GenTyp1(JC0.SBB, JC0.ImmMem, 0, SP, noInx, noScale, 4, 0);
			INC(pc)
		|118,119:(*?neg*)
			type := (op-96) MOD 4;
			LoadST(SP, 0, type);
			JC0.GenFop1(JC0.FCHS);
			StoreST(SP, 0, type);
			JC0.PutByte(JC0.WAIT);
			INC(pc)
		| 120, 122, 124: (*i?shift; corrected rl 04.01.01*)			
			JC0.GenPOP(JC0.Regs, ECX, noBase, noInx, noScale, noDisp); (* shift operand must be in cl *)
			IF op = 120 THEN	JC0.GenShiftRot(JC0.SAL, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm);
			ELSIF op = 122 THEN	JC0.GenShiftRot(JC0.SAR, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm)
			ELSIF op = 124 THEN	JC0.GenShiftRot(JC0.SHR, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm)
			END;
			INC(pc)
		| 121: (* lshl *)
			INC(pc);
			LShiftLeft;
		| 123: (* lshr *)
			INC(pc);
			LShiftRight(FALSE);
		| 125: (* lushr *)
			INC(pc);
			LShiftRight(TRUE);
		| 127, 129, 131: (* land / lor / lxor *)
			Pop(TRUE);
			IF op = 127 THEN  opc := JC0.AND  ELSIF op = 129 THEN opc := JC0.Or ELSE opc := JC0.XOR END;
			JC0.GenTyp1(opc, JC0.RegMem, EAX, SP, noInx, noScale, 0, noImm);
			JC0.GenTyp1(opc, JC0.RegMem, EDX, SP, noInx, noScale, 4, noImm);
			INC(pc)
		| 132: (* iinc *)
			INC(pc); index := Index(wide);
			IF wide THEN  val := Value(2); wide := FALSE  ELSE val := Value(1)  END;
			JC0.GenTyp1(JC0.ADD, JC0.ImmMem, 0, FP, noInx, noScale, FpOffset(index), val)
		| 133, 136 : (* i2l / l2i *)
			Pop(op=136);
			IF op=133 THEN  JC0.PutByte(JC0.CWD)  END;
			Push(op=133);
			INC(pc)
		| 134..135, 137..144 : (* x2x w/o integer only ops *)
			CASE (op-133) DIV 3 OF
			|  0:  (*133..135, i2x *)  size := JC0.sInt; val := 1
			|  1:  (*136..138, l2x *)  size := JC0.lInt; val := 2
			|  2:  (*139..141, f2x *)  size := JC0.sReal; val := 1
			|  3:  (*142..144, d2x *)  size := JC0.lReal; val := 2
			END;
			JC0.GenFLD(JC0.Mem, size, SP, noInx, noScale, 0);	(* load*)
			CASE op OF
			| 136, 139, 142: (* x2i*)  size := JC0.sInt; DEC(val, 1)
			| 133, 140, 143: (* x2l*)  size := JC0.lInt; DEC(val, 2)
			| 134, 137, 144: (* x2f*)  size := JC0.sReal; DEC(val, 1)
			| 135, 138, 141: (* x2d*)  size := JC0.lReal; DEC(val, 2)
			END;
				(* correct stack size *)
			IF val = 1 THEN JC0.GenPOP(JC0.Regs, EAX, noBase, noInx, noScale, noDisp)
			ELSIF val = -1 THEN JC0.GenPUSH(JC0.Regs, EAX, noBase, noInx, noScale, noDisp, noImm)
			END;
			JC0.GenFSTP(JC0.RegMem, size, SP, noInx, noScale, 0);
			INC(pc)
		| 146: (* i2c *)
			JC0.GenTyp1(JC0.AND, JC0.ImmMem, EAX, SP, noInx, noScale, 0, 0FFFFH);
			INC(pc)
		| 145,147 : (* i2b / i2s *)
			Load(SP, 0, Size[op-145+JavaBYTE]);	(*because of the sign-extensions*)
			Store(SP, 0, 4);
			INC(pc)
		| 148: (* lcmp *)
			INC(pc);
			Pop(TRUE);	(* value2 -> EDX:EAX *)
			JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);	(* value1 -> ECX:EBX *)
			JC0.GenPOP(JC0.Regs, ECX, noBase, noInx, noScale, noDisp);
			JC0.GenTyp1(JC0.CMP, JC0.RegReg, EDX, ECX, noInx, noScale, noDisp, noImm);
			JC0.GenJcc(JC0.JL, 16);	(*L+*)
			JC0.GenJcc(JC0.JG, 10);	(*L-*)																					(* 2 Bytes *)
			JC0.GenTyp1(JC0.CMP, JC0.RegReg, EAX, EBX, noInx, noScale, noDisp, noImm);	(* 2 Bytes *)	
			JC0.GenJcc(JC0.JB, 10);	(*L+*)																					(* 2 Bytes *)
			JC0.GenJcc(JC0.JA, 4);	(*L-*)																					(* 2 Bytes *)
(* L=: v1 = v2 *)
			JC0.GenPUSH(JC0.Imme, EAX, noBase, noInx, noScale, noDisp, 0);							(* 2 Bytes *)
			JC0.GenJMP(JC0.Imme, noBase, noBase, noInx, noScale, 6, FALSE);							(* 2 Bytes *)
(* L-: v1 < v2 *)
			JC0.GenPUSH(JC0.Imme, EAX, noBase, noInx, noScale, noDisp, -1);						(* 2 Bytes *)
			JC0.GenJMP(JC0.Imme, noBase, noBase, noInx, noScale, 2, FALSE);						(* 2 Bytes *)
(* L+: v1 > v2 *)
			JC0.GenPUSH(JC0.Imme, EAX, noBase, noInx, noScale, noDisp, 1);							(* 2 Bytes *)
(* Exit: *)
		| 149, 150: (* fcmpl / fcmpg *)
			INC(pc);
			FloatCompare(JC0.sReal, op = 150)
		| 151, 152: (* dcmpl / dcmpg*)
			INC(pc);
			FloatCompare(JC0.lReal, op = 152)
		| 153..158,	(* ifeq / ifne / iflt / ifge / ifgt / igle *)
		  159..164,	(* if-icmpeq / if-icmpne / if-icmplt / if-icmpge / if-icmpgt / if-icmple *)
		  165..166:	(* if-acmpeq / if-acmpne *)
			INC(pc); offset := Value(2);
			Pop(op > 158);
			IF op <= 158 THEN
				JC0.GenTyp1(JC0.CMP, JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, 0)
			ELSE
				JC0.GenTyp1(JC0.CMP, JC0.RegReg, EDX, EAX, noInx, noScale, noDisp, noImm)
			END;
			Jcc(jcc[(op-153) MOD 6], offset);
		| 167, 168: (* goto / jsr *)
			INC(pc); offset := Value(2);
			IF op=167 THEN  Jcc(JMP, offset)  ELSE  Jcc(CALL, offset)  END
		| 169: (* ret*)
			INC(pc);
			index := Index(FALSE); RetFinally(index)
		| 170: TableSwitch
		| 171: (* lookupswitch *)
			INC(pc, 1+(-pc-1) MOD 4);	(*padding*)
			default := Value(4); npairs := Value(4);
			Pop(FALSE);	(* key -> EAX *)
			ASSERT(npairs >= 0);
			WHILE npairs > 0 DO
				match := Value(4); offset := Value(4);
				JC0.GenTyp1(JC0.CMP, JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, match);
				Jcc(JC0.JE, offset);
				DEC(npairs)
			END;
			Jcc(JMP, default)
		| 172..177: (* ireturn / lreturn / freturn / dreturn / areturn / return *)
			IF (JB.AFSynchronized IN c.methods[mno].flags) THEN
				IF (JB.AFStatic IN c.methods[mno].flags)THEN
					Synchronize(c, FALSE)
				ELSE
					Synchronize(NIL, FALSE)
				END
			END;
			type := op-172;
			IF type IN {JavaFLOAT, JavaDOUBLE} THEN
				LoadST(SP, 0, type)
			ELSIF op # 177 THEN	(*type 5 is no type in this case*)
				Pop(type = JavaLONG)
			END;
				(*exit frame*)
			JC0.GenMOV(JC0.RegReg, SP, FP, noInx, noScale, noDisp, noImm);
			JC0.GenPOP(JC0.Regs, FP, noBase, noInx, noScale, noDisp);
			JC0.GenRET(nofParams*4);
			INC(pc)
		| 178, 179, 180, 181: (* getstatic / putstatic / getfield / putfield *)
			INC(pc); index := Index(TRUE);
			IF (index >= LEN(const^)) OR ~(const[index].tag = JB.CFieldref) THEN HALT(99)
			ELSE
				ref := const[index](JB.CRefInfo);
				cf := ref.cindex.class;
				ASSERT(cf.state >= JB.Allocated);
				rf := cf(JB.RefClass);
				IF ref.obj IS PCT.Value THEN
					ASSERT(op = 178);
					PushConst(ref.obj(PCT.Value).const)
				ELSE
					s := ref.obj.type.size(PCBT.Size).size;
					off := ref.obj.adr(PCBT.Variable).offset;
					IF op = 178 THEN	(* getstatic *)
						ASSERT(ref.obj IS PCT.GlobalVar);
						CheckInitialized(rf); (* runtime call *)
						Load(noBase, rf.ownModule.sb+off, s);
						Push(s = 8)
					ELSIF op = 179 THEN	(* putstatic *)
						ASSERT(ref.obj IS PCT.GlobalVar);
						CheckInitialized(rf); (* runtime call *)
						Pop(s = 8);
						Store(noBase, rf.ownModule.sb+off, s)
					ELSIF op = 180 THEN	(* getfield *)
						ASSERT(ref.obj IS PCT.Field);
						JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);	(*objref*)
						Load(EBX, off, s);
						Push(s = 8)
					ELSIF op = 181 THEN	(* putfield *)
						ASSERT(ref.obj IS PCT.Field);
						Pop(s = 8);
						JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);	(*objref*)
						Store(EBX, off, s)
					END
				END
			END
		| 182, 183: (* invoke virtual / special *)
			INC(pc); index := Index(TRUE);			
			IF (index >= LEN(const^)) THEN HALT(99)
			ELSIF (op = 182) & ~(const[index].tag = JB.CMethodref) THEN HALT(99)			
			ELSE
				ref := const[index](JB.CRefInfo); cf := ref.cindex.class;
				ASSERT(cf.state >= JB.Allocated);
				(* linkage errors *)
				IF ref.ref = NIL THEN HALT(99)
				ELSE (* ok *)
					m := ref.ref(JB.Method);
					ASSERT(~(JB.AFStatic IN m.flags));
					super := (op=183) & ~JT.Equal0(ref.ntindex.name.str, LEN(ref.ntindex.name.str), "<init>") & (JB.AFSuper IN c.flags) & ~(JB.AFPrivate IN m.flags);
					noPars := m.parsize = 4;	(* self is the only argument *)
					IF ~noPars THEN
						Load(SP, m.parsize-4, 4);	(* the objref is pushed before the params *)
						Push(FALSE);	(*push self as last parameter, oberon calling convention*)
					END;
						(*call*)
					IF super THEN	(*supercall*)
						JC0.GenMOV(JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, c.superClass.typedesc.tag));
					ELSIF op = 183 THEN (* <init> *)
						JC0.GenMOV(JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, cf(JB.ObjectClass).typedesc.tag))
					ELSE (* invokevirtual *)
						IF noPars THEN Load(SP, 0, 4) END;
						Load(EAX, -4, 4);	 (*get td*)
					END;
					Load(EAX, JS.MethodOffset(m.mno), 4); (*get mth*)
					JC0.GenCALL(JC0.Regs, EAX, noBase, noInx, noScale, noDisp);
						(*remove objref*)
					IF ~noPars THEN JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp) END;
					PushRetValue(m.p.type);
				END
			END		
		| 184: (*invoke static *)
			INC(pc); index := Index(TRUE);
			IF (index >= LEN(const^)) OR ~(const[index].tag = JB.CMethodref) THEN HALT(99)
			(*
				Throw("java/lang/NoSuchMethodError")
			*)
			ELSE
				ref := const[index](JB.CRefInfo);
				m := ref.ref(JB.Method);
				cf := ref.cindex.class;
				ASSERT(cf.state >= JB.Allocated);
				IF ~(JB.AFStatic IN m.flags) THEN HALT(99)
				(*
					Throw("java/lang/IncompatibleClassChangeError")
				*)
				ELSIF (JB.AFAbstract IN m.flags) THEN HALT(99)
				(*
					Throw("java/lang/AbstractMethodError")
				*)
				END;
				IF ref.next = NIL THEN
					INC(JB.AloadStaticMth);
					IF (c # cf) & (cf.state < JB.Compiled) THEN
						of := cf(JB.ObjectClass);
						ASSERT(of.fixlist # NIL); 
						ref.next := of.fixlist; of.fixlist := ref
					ELSE
						ASSERT(c.fixlist # NIL); ref.next := c.fixlist; c.fixlist := ref
					END
				END;
				CheckInitialized(cf); (* runtime call *)
					(*call is relative and the code gets relocated -> always fix *)
				JC0.GenCALL(JC0.Imme, 0, noBase, noInx, noScale, 10000H + ref.fixup);
				ref.fixup := JC0.pc-4;
				PushRetValue(m.p.type);
			END
		| 185: (*invoke interface *) INC(pc);
			index:= Index(TRUE); val := Value(1); dummy := Value(1);
			InvokeInterface(index, val)			
		| 186: (* not used *)	
			INC(pc);
			Undef(186)
		| 187: (* new *)
			INC(pc); index := Index(TRUE);
			(**)
			cf := GetClass(c.constPool[index]);
			IF (cf(JB.ObjectClass).flags * {JB.AFAbstract, JB.AFInterface} # {}) THEN HALT(99)
			(*
				Throw("java/lang/InstantiationError")
			*)
			ELSE
				JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, cf));
				SystemCall(JB.SCNew);
				Push(FALSE)
			END
		| 188: (* newarray *)
			INC(pc);  index := Value(1);
			(*count already on the stack*)
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, index(*size*));
			SystemCall(JB.SCNewArray);
			Push(FALSE)
		| 189: (* anewarray *)
			INC(pc);  index := Index(TRUE); wide := FALSE;
			IF const[index].tag = JB.CClass THEN
				(*count already on the stack*)
				JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, GetClass(const[index])));
				SystemCall(JB.SCNewArrayA);
				Push(FALSE)
			ELSE 
				
				HALT(99)
			(*
				Throw("java/lang/NoClassDefFoundError")
			*)
			END
		| 190: (* arraylength *)
			Pop(FALSE);  (* NilCheck(EAX); *)
			Load(EAX, ArrayPtrOffset(), 4); (* NilCheck(EAX); *)
			JC0.GenPUSH(JC0.Mem, 0, EAX, noInx, noScale, ArrayDim, noImm);
			INC(pc);
		| 191: (* athrow *)
			(* Load(SP, 0, 4); NilCheck(EAX); *)
			SystemCall(JB.SCThrow);
			INC(pc);
		| 192: (* checkcast *)
			INC(pc);  index := Index(TRUE);
			Load(SP, 0, 4); (* NilCheck(EAX); *)
			Push(FALSE);
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, GetClass(const[index])));
			SystemCall(JB.SCCheckCast)
		| 193: (* instanceof *)
			INC(pc);  index := Index(TRUE);
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, GetClass(const[index])));
			SystemCall(JB.SCInstanceOf);
			Push(FALSE);	(*result*)
		| 194, 195: (* monitorenter / monitorexit *)
			INC(pc);
			Monitor(op=194)
		| 196: (* wide *)
			wide := TRUE; INC(pc)
		| 197: (* multianewarray *)
			INC(pc); index := Index(TRUE);
			cf := GetClass(c.constPool[index]); 	(* at this moment, the class is already created *)
			MultianewArray(cf, Value(1));
		| 198, 199: (* ifnull / ifnonull *)
			INC(pc); offset := Value(2);
			Pop(FALSE);
			JC0.GenTyp1(JC0.CMP, JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, NULL);
			Jcc(jcc[op-198], offset);
		| 200, 201: (* goto-w / jsr-w *)
			INC(pc); offset := Value(4);
			IF op=200 THEN  Jcc(JMP, offset)  ELSE  Jcc(CALL, offset)  END
		ELSE Undef(op)
		END;	(*CASE code *)
	END;	(* WHILE pc *)
	IF BenchTiming THEN
		ticks := AosBoot.GetTimer() - ticks;
		JT.JavaToOberonString(c.name, 0, LEN(c.name^), module);
		StringPool.GetString(c.methods[mno].p.name, method);
		JC.String(module); JC.Char("."); JC.String(method);
		JC.Char(9X);
		JC.Int(LEN(code.code), 0);
		JC.Char(9X);
		JC.Int(JC0.pc - c.methods[mno].offset, 0);
		JC.Char(9X);
		JC.Int(SHORT(ticks), 0);
		JC.Ln;
		ASSERT(ticks < MAX(LONGINT));
	END;
	stop := AosKernel.Elapsed(start);
	i := bytes DIV 50;
	IF i >= LEN(Nticks) THEN i := LEN(Nticks)-1 END;
	INC(NtotTicks, stop);
	INC(Nticks[i], stop);
	INC(NtotJavaBytes, bytes);
	INC(NjavaBytes[i], bytes);
	INC(NtotIntelBytes, JC0.pc - c.methods[mno].offset);
	INC(NintelBytes[i], JC0.pc - c.methods[mno].offset);
	INC(NtotMethods);
	INC(Nmethods[i]);
END EncodeMethod;

PROCEDURE InitModule;
VAR	r: REAL; lr: LONGREAL; tmp: jjlObject.RefArray;
BEGIN
	r := 0.0; fconst[0] := SYSTEM.VAL(LONGINT, r);
	r := 1.0; fconst[1] := SYSTEM.VAL(LONGINT, r);
	r := 2.0; fconst[2] := SYSTEM.VAL(LONGINT, r);
	lr := 0.0E0; SYSTEM.MOVE(SYSTEM.ADR(lr), SYSTEM.ADR(dconst[0]), 8);
	lr := 1.0E0; SYSTEM.MOVE(SYSTEM.ADR(lr), SYSTEM.ADR(dconst[1]), 8);
	jcc[0] := JC0.JE; jcc[1] := JC0.JNE; jcc[2] := JC0.JL;
	jcc[3] := JC0.JGE; jcc[4] := JC0.JG; jcc[5] := JC0.JLE;
	Size[JavaINT] := IntSize;  Size[JavaLONG] := LongSize; Size[JavaFLOAT] := FloatSize;
	Size[JavaDOUBLE] := DoubleSize;  Size[JavaREF] := RefSize;  Size[JavaBYTE] := ByteSize;
	Size[JavaCHAR] := CharSize; Size[JavaSHORT] := ShortSize;
	tmp := NIL (*SYSTEM.VAL(jjlObject.RefArray, 0)*);
	ASSERT(ArrayPtrOffset() = SYSTEM.ADR(tmp.p));		(* hack, SIZE is no constant *)
END InitModule;

BEGIN
	failureInfo.kind := JC.Failure; failureInfo.source := JC.Compiler;
	InitModule;
END JVMCompiler.

(*
	12.02.03	prk	Logging functions, use same interface as AosOut
	25.04.02	prk	reorganization; unified compiler interface for creating plugins
	19.03.02	prk	export mapping information, allow compilation step to generate map
	19.03.02	prk	method call tracing
	03.12.01	prk	option to force jump offset to 4 bytes
	03.12.01	prk	fpu rounding control changed
	15.11.01	prk	use fields and vars from PCT instead of JB.Field	
	09.11.01	prk	PushSelfTD removed
	18.10.01	prk	create a first entry in the reference section with the list of the global variables
	18.10.01	prk	fixup map dynamically allocated
	18.09.01	prk	expand returned values smaller than 4 bytes to 4 bytes
	05.09.01	prk	make class loading and initializing more efficient
	16.08.01	prk	take procedure information from PCT+PCBT
	27.05.01	prk	Logging improved
	21.05.01	prk	don't trap when a method/field is referenced, generate run-time exception
	09.05.01	prk	compiler: when call returns boolean, expand it to int
	08.05.01	prk	JVMSystem.PushSelfTD
	04.04.01	prk	merge with classpath-0.00 release, prepare for update with 0.01, minimize differencies
	29.03.01	prk	lshl lshr lushr - mask value2 with 03FH to avoid wraparound
	26.03.01	prk	Adapted for Paco
*)