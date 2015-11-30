(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMOptCompiler;	(** PRK **)


IMPORT
		SYSTEM,
		AosBoot, BIT,
		PCT, PCBT, StringPool,
		jjlObject,
		JC := JVMConsole,
		JS := JVMSystem, JT := JVMTypes, JVMRefs, JB := JVMBase, JC0 := JVMCompiler0;


CONST
	BenchTiming = FALSE;

	TraceMethods = FALSE;

	TraceBorders = FALSE;
	TraceEmit = FALSE;
	TraceRegisters = FALSE;
	TraceMethodNames = FALSE;
	DoCheckRegs = FALSE;
	
	FlushStackAfterEachOp = FALSE;
	
	ShowWarnings = 1;
		(*
			0 - none
			1 - critical
			2 - non critical
		*)
	
	StackConsistencyCheck = TRUE;
	
		(* before making true... this enables one FlushStack. Check with ScanBasicBlocks *)
	OptimizeBooleanExp = FALSE;
	SuppressCheckInitOptimization = FALSE;
	EnableStackFlushDetection = TRUE;
	
	PreloadShorts = TRUE;
		(* no SHORT/CHAR/BYTE allowed on the stack; preload them into a register *)

		(* java opcodes *)
	nop = 00; aconstnull = 01; iconstm1 = 02; iconst0 = 03; iconst1 = 04; iconst2 = 05; iconst3 = 06; 
	iconst4 = 07; iconst5 = 08; lconst0 = 09; lconst1 = 10; fconst0 = 11; fconst1 = 12; fconst2 = 13; 
	dconst0 = 14; dconst1 = 15; bipush = 16; sipush = 17; ldc = 18; ldcw = 19; ldc2w = 20; iload = 21; 
	lload = 22; fload = 23; dload = 24; aload = 25; iload0 = 26; iload1 = 27; iload2 = 28; iload3 = 29; 
	lload0 = 30; lload1 = 31; lload2 = 32; lload3 = 33; fload0 = 34; fload1 = 35; fload2 = 36; fload3 = 37; 
	dload0 = 38; dload1 = 39; dload2 = 40; dload3 = 41; aload0 = 42; aload1 = 43; aload2 = 44; 
	aload3 = 45; iaload = 46; laload = 47; faload = 48; daload = 49; aaload = 50; baload = 51; 
	caload = 52; saload = 53; istore = 54; lstore = 55; fstore = 56; dstore = 57; astore = 58; istore0 = 59; 
	istore1 = 60; istore2 = 61; istore3 = 62; lstore0 = 63; lstore1 = 64; lstore2 = 65; lstore3 = 66; 
	fstore0 = 67; fstore1 = 68; fstore2 = 69; fstore3 = 70; dstore0 = 71; dstore1 = 72; dstore2 = 73; 
	dstore3 = 74; astore0 = 75; astore1 = 76; astore2 = 77; astore3 = 78; iastore = 79; lastore = 80; 
	fastore = 81; dastore = 82; aastore = 83; bastore = 84; castore = 85; sastore = 86; pop = 87; 
	pop2 = 88; dup = 089; dupx1 = 090; dupx2 = 091; dup2 = 092; dup2x1 = 093; dup2x2 = 094; 
	swap = 095; iadd = 096; ladd = 097; fadd = 098; dadd = 099; isub = 100; lsub = 101; fsub = 102; 
	dsub = 103; imul = 104; lmul = 105; fmul = 106; dmul = 107; idiv = 108; ldiv = 109; fdiv = 110; 
	ddiv = 111; irem = 112; lrem = 113; frem = 114; drem = 115; ineg = 116; lneg = 117; fneg = 118; 
	dneg = 119; ishl = 120; lshl = 121; ishr = 122; lshr = 123; iushr = 124; lushr = 125; iand = 126; 
	land = 127; ior = 128; lor = 129; ixor = 130; lxor = 131; iinc = 132; i2l = 133; i2f = 134; i2d = 135; 
	l2i = 136; l2f = 137; l2d = 138; f2i = 139; f2l = 140; f2d = 141; d2i = 142; d2l = 143; d2f = 144; 
	i2b = 145; i2c = 146; i2s = 147; lcmp = 148; fcmpl = 149; fcmpg = 150; dcmpl = 151; dcmpg = 152; 
	ifeq = 153; ifne = 154; iflt = 155; ifge = 156; ifgt = 157; ifle = 158; ificmpeq = 159; ificmpne = 160; 
	ificmplt = 161; ificmpge = 162; ificmpgt = 163; ificmple = 164; ifacmpeq = 165; ifacmpne = 166; 
	goto = 167; jsr = 168; ret = 169; tableswitch = 170; lookupswitch = 171; ireturn = 172; lreturn = 173; 
	freturn = 174; dreturn = 175; areturn = 176; return = 177; getstatic = 178; putstatic = 179; 
	getfield = 180; putfield = 181; invokevirtual = 182; invokespecial = 183; invokestatic = 184; 
	invokeinterface = 185; new = 187; newarray = 188; anewarray = 189; arraylength = 190; 
	athrow = 191; checkcast = 192; instanceof = 193; monitorenter = 194; monitorexit = 195; 
	wide = 196; multianewarray = 197; ifnull = 198; ifnonnull = 199; gotow = 200; jsrw = 201; 
	breakpoint = 202; impdep1 = 254; impdep2 = 255;  


		(*registers and other Compiler0 constants*)
	noBase = JC0.noBase; noInx = JC0.noInx; noScale = JC0.noScale;
	noDisp = JC0.noDisp; noImm = JC0.noImm;
	ESP = JC0.ESP; EBP = JC0.EBP; EAX = JC0.EAX; EBX = JC0.EBX; ECX = JC0.ECX; EDX = JC0.EDX;
	ESI = JC0.ESI; EDI = JC0.EDI;
	AX = JC0.AX;
	AL = JC0.AL;
	
	(* Empty - the set of no registers *)
	Empty = {};
	
	Free = 0;

	Allocable = {EAX, EBX, ECX, EDX, ESI, EDI};

		(*special values*)
	JMP = -1; CALL = -2;
	
		(*data types*)
	JavaINT = 0; JavaLONG = 1; JavaFLOAT = 2; JavaDOUBLE = 3; JavaREF = 4;
	JavaBYTE = 5; JavaCHAR = 6; JavaSHORT = 7;
	JavaBOOL = 8;
	
	JavaShorts = {JavaBYTE, JavaCHAR, JavaSHORT, JavaBOOL};
	JavaInts = {JavaINT, JavaBYTE, JavaCHAR, JavaSHORT, JavaBOOL};
	JavaInt4 = {JavaINT, JavaREF};
	Java1 = {JavaINT, JavaFLOAT, JavaREF};	(* 1 word types *)
	Java2 = {JavaLONG, JavaDOUBLE};	(* 2 word types *)
	
CONST
	(* Item Modes *)
	Immediate = 1;  Register = 2;  FRegister = 3;  Field = 4;  Array = 5;  Static =  6;  Stack = 7;  Local = 8;  Constant = 9;
	Memory = {Field, Array, Static, Stack, Local, Constant};
	
	(* Basic Block Mode *)
	Jump = 0;	(* jumped to *)
	Fall = 1;		(* fall through *)
	Sub = 2;	(* begin of  a subroutine *)
	Catch = 3;	(* begin of a catch clause *)
	
TYPE
	BasicBlock = POINTER TO BasicBlockDesc;
	StackItem = RECORD
		type: SHORTINT;
		pc: LONGINT;
		block: BasicBlock		(* NIL if multiple creators *)
	END;

	BasicBlockDesc = RECORD
		mode: SET;
		nr, begin, end: LONGINT;	(* pc address *)
		tos: LONGINT;
		minTos: LONGINT;	(* deprecated *)
		stack: ARRAY 8 OF StackItem;	(* Stack upon entering the bb; JavaTypes or -1 *)
		creator: ARRAY 8 OF LONGINT;	(* Upon leaving block: pc of instruction that generated the stack item *)
		mustPush: ARRAY 8 OF BOOLEAN;	(* whether an item must be pushed before leaving the block *)
		next: BasicBlock;
		succ: POINTER TO ARRAY OF BasicBlock;	(* successor list *)
		new: BOOLEAN;	(* to be processed *)
	END;
		
	Item = RECORD
		type, mode: SHORTINT;
		val, val2: LONGINT;
		base, base2, index: INTEGER;	(* Register Mode *)
		disp: LONGINT;	(* Local mode *)
		scale: SHORTINT;
	END;
	
	FOp = PROCEDURE(mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);


VAR
	ArrayDim, ArrayPtrOffset, FirstArrayElem: LONGINT;
	
	(* tables *)
	fconst: ARRAY 3 OF LONGINT;
	dconst: ARRAY 2 OF HUGEINT;
	jcc: ARRAY 6 OF SHORTINT;
	Typ1Op: ARRAY 6 OF SHORTINT;
	Typ1Fold: ARRAY 6 OF PROCEDURE(a, b: LONGINT): LONGINT;
	FTyp1Op: ARRAY 4,2 OF FOp;
	Mode: ARRAY 10 OF SHORTINT;
	
	Size, Scale, FSize: ARRAY 8 OF SHORTINT;
	
	(*
		Keep tract of allocated registers.
		Reg[i] = j  ==> register i is allocated j times
	*)
	Regs: ARRAY 8 OF LONGINT;
	stack: ARRAY 32 OF Item;
	tos: LONGINT;
	
	Type: ARRAY 9, 8 OF CHAR;
	T: ARRAY 8 OF CHAR;
	R, M: ARRAY 10, 5 OF CHAR;
	
	(* code patterns *)
	trueexp, falseexp: ARRAY 5 OF CHAR;

	(* counters *)
	Ainvoke, AoptInvoke, AsInvoke, AvInvoke, AiInvoke,
	AinitCheckAsked, AinitCheckEmitted,
	AboolExp0, AboolExp1,
	ALoad2XCHG, ALoad2Skip, ALoad2Sup1, ALoad2Sup2,
	AoptCmpT, AoptCmpF, AspilItem: LONGINT;
	Aopcodes: ARRAY 256 OF LONGINT;
	
	debugInfo, warningInfo, infoInfo, statusInfo, errorInfo, failureInfo: JC.LoggingInfo;
	
	TraceLines: BOOLEAN;
	
(* ---------- Debug ----------------- *)

PROCEDURE DumpBBMode(m: SET);
BEGIN
	JC.String(debugInfo, "{");
	IF Jump IN m THEN JC.String(debugInfo, " Jump") END;
	IF Fall IN m THEN JC.String(debugInfo, " Fall") END;
	IF Catch IN m THEN JC.String(debugInfo, " Catch") END;
	IF Sub IN m THEN JC.String(debugInfo, " Sub") END;
	JC.String(debugInfo, "}")
END DumpBBMode;

PROCEDURE DumpBasicBlocks(p: BasicBlock);
	VAR i: LONGINT;
BEGIN
	JC.String(debugInfo, "Basic Blocks:"); JC.Ln(debugInfo);
	WHILE (p # NIL) DO
		JC.Int(debugInfo, p.nr, 3); JC.String(debugInfo, ": ["); JC.Int(debugInfo, p.begin, 3);
		JC.String(debugInfo, "; "); JC.Int(debugInfo, p.end, 3); JC.String(debugInfo, "] ");
		JC.Int(debugInfo, p.tos, 3); JC.String(debugInfo, "/"); JC.Int(debugInfo, p.minTos, 3);
		DumpBBMode(p.mode);
		IF p.succ # NIL THEN
			JC.String(debugInfo, "  Succ: ");
			FOR i := 0 TO LEN(p.succ)-1 DO
				JC.Int(debugInfo, p.succ[i].nr, 0); JC.String(debugInfo, "; ")
			END;
			JC.String(debugInfo, "  Creator:  ");
			FOR i := p.minTos TO p.succ[0].tos-1 DO
				IF p.mustPush[i] THEN JC.String(debugInfo, "^") END;
				JC.Int(debugInfo, i, 0); JC.String(debugInfo, ":"); JC.Int(debugInfo, p.creator[i], 0); JC.String(debugInfo, " ")
			END;
		END;
		JC.Ln(debugInfo);
		p := p.next
	END;
	JC.Ln(debugInfo)
END DumpBasicBlocks;

PROCEDURE DumpTypes(VAR info: JC.LoggingInfo; t: SET);
	VAR i: LONGINT;
BEGIN
	JC.String(info, "{");
	FOR i := JavaINT TO JavaBOOL DO
		IF i IN t THEN JC.String(info, Type[i]) END
	END;
	JC.String(info, "}");
END DumpTypes;

PROCEDURE ToDo;
BEGIN
	HALT(MAX(INTEGER));
	JC.String(failureInfo, "ToDo"); JC.Ln(failureInfo);
END ToDo;

(* ---------- Helper Procedures --------- *)

PROCEDURE OberonToJavaType(type: PCT.Struct): LONGINT;
	VAR t: LONGINT;
BEGIN
	IF type = PCT.Int8 THEN
		t := JavaBYTE
	ELSIF type = PCT.Int16 THEN
		t := JavaSHORT
	ELSIF type = PCT.Int32 THEN
		t := JavaINT
	ELSIF type = PCT.Int64 THEN
		t := JavaLONG
	ELSIF type = PCT.Float32 THEN
		t := JavaFLOAT
	ELSIF type = PCT.Float64 THEN
		t := JavaDOUBLE
	ELSIF type = PCT.Char16 THEN
		t := JavaCHAR
	ELSIF type = PCT.Bool THEN
		t := JavaBOOL
	ELSE
		ASSERT(PCT.IsPointer(type));
		t := JavaREF
	END;
	RETURN t
END OberonToJavaType;

PROCEDURE GetClass(ci :JB.CInfo): JB.Class;
VAR class: JB.CClassInfo;
BEGIN
	class := ci(JB.CClassInfo);
	IF class.class = NIL THEN class.class := JB.ThisClass(class.index.str, TRUE) END;
	RETURN class.class
END GetClass;
	
(* ---------- Register Allocation --------- *)

PROCEDURE ReleaseReg(reg: INTEGER);
BEGIN
	IF TraceRegisters THEN JC.String(debugInfo, " R"); JC.Int(debugInfo, reg, 0) END;
	IF (reg >= 0) & (reg IN Allocable) THEN
		ASSERT(Regs[reg] > 0);
		DEC(Regs[reg])
	ELSIF (reg >= AX) THEN
		HALT(99)
	END
END ReleaseReg;

PROCEDURE AllocateThisReg(reg: INTEGER; protect: SET; unique: BOOLEAN);
	VAR new: INTEGER;  i, c: LONGINT;
BEGIN
	IF TraceRegisters THEN JC.String(debugInfo, " A"); JC.Int(debugInfo, reg, 0) END;
	IF (reg >= EAX) & (reg IN Allocable) THEN
		IF unique & (Regs[reg] # Free) THEN
			new := AllocateReg(protect);
			c := Regs[reg];
			Regs[new] := c;
			Regs[reg] := Free;
			IF ShowWarnings >= 2 THEN
				JC.String(warningInfo, "  move "); JC.Int(warningInfo, reg, 0); JC.String(warningInfo, " -> ");
				JC.Int(warningInfo, new, 0); JC.Ln(warningInfo);
			END;
			JC0.GenMOV(JC0.RegReg, new, reg, noInx, noScale, noDisp, noImm);
			FOR i := 0 TO tos-1 DO
				IF stack[i].base = reg THEN stack[i].base := new; DEC(c) END;
				IF stack[i].base2 = reg THEN stack[i].base2 := new;
					IF (stack[i].type = JavaLONG) & (stack[i].mode = Register) THEN DEC(c) END
				END;
				IF stack[i].index = reg THEN stack[i].index := new; DEC(c) END;
			END;
			ASSERT(c = Free);	(* may be decrease twice for 32bit registers *)
		END;
		INC(Regs[reg]);
	ELSE
		HALT(99)
	END
END AllocateThisReg;


(* AllocateReg - Allocates one free reg, regs in mask are not allocated *)

PROCEDURE AllocateReg(protect: SET): INTEGER;
	VAR i, j: LONGINT; allocable: SET;	
BEGIN
	allocable := Allocable - protect;
	ASSERT(allocable # {});
	REPEAT
		FOR i := EAX TO EDI DO
			IF (i IN allocable) & (Regs[i] = Free) THEN
				Regs[i] := 1;
				IF TraceRegisters THEN JC.String(debugInfo, " a"); JC.Int(debugInfo, i, 0) END;
				RETURN SHORT(i)
			END
		END;
		i := 0;
		WHILE (i < tos) & (stack[i].mode = Stack) DO INC(i) END;
		IF i < tos THEN
			ASSERT(~(stack[i].type IN JavaShorts));
			j := i;
			WHILE (j < tos) DO
				ASSERT(stack[j].mode # Stack);		(* fatal error, incontiguos stack *)
				INC(j)
			END;
			JC.String(warningInfo, "Warning: Item spilled"); JC.Ln(warningInfo);
			INC(AspilItem);
			GenPushItem(stack[i])
		END
	UNTIL i = tos;
	HALT(99)
END AllocateReg;

PROCEDURE RegCount(reg: INTEGER): LONGINT;
BEGIN
	IF reg = noBase THEN
		RETURN Free
	ELSIF reg IN Allocable THEN
		RETURN Regs[reg]
	END;
	HALT(99);
END RegCount;

PROCEDURE ResetRegs;
	VAR i: LONGINT;
BEGIN
	FOR i := 0 TO 7 DO
		Regs[i] := Free;
	END
END ResetRegs;

PROCEDURE AllRegsFree(): BOOLEAN;
	VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE (i < 8) & (Regs[i] = Free) DO  INC(i)  END;
	RETURN (i = 8)
END AllRegsFree;

PROCEDURE CheckRegs;
BEGIN
	ASSERT(AllRegsFree());
END CheckRegs;

(* MakeMask - Create a set containing the registers present in item *)
PROCEDURE MakeMask(VAR i: Item): SET;
	VAR s: SET;
BEGIN
	IF i.base >= 0 THEN s := s + {i.base} END;
	IF i.base2 >= 0 THEN s := s + {i.base2} END;
	IF i.index >= 0 THEN s := s + {i.index} END;
	RETURN s
END MakeMask;

(* ---------- Stack Checking --------- *)

	PROCEDURE DumpItem(VAR info: JC.LoggingInfo; VAR i: Item);
		PROCEDURE OutReg(i: LONGINT);
		BEGIN
			IF i = noBase THEN JC.String(info, "---") ELSE JC.String(info, R[i]) END;
			JC.String(info, "  ");
		END OutReg;
	BEGIN
		JC.String(info, Type[i.type]);
		JC.String(info, M[i.mode]);
		OutReg(i.base); OutReg(i.base2); OutReg(i.index);
		JC.Int(info, i.disp, 4);
		JC.Int(info, i.val, 4);
		JC.Ln(info);
	END DumpItem;

	PROCEDURE DumpStack(VAR info: JC.LoggingInfo);
		VAR i: LONGINT;
	BEGIN
		FOR i := tos TO 0 BY -1 DO
			JC.Int(info, i, 2); JC.String(info, ": ");
			DumpItem(info, stack[i]);
		END
	END DumpStack;
		
PROCEDURE CheckStackConsistency;
	VAR reg, i: LONGINT; c: ARRAY 8 OF LONGINT;
BEGIN
	FOR i := 0 TO tos-1 DO
		reg := stack[i].base;
		IF reg # noBase THEN INC(c[reg]) END;
		reg := stack[i].base2;
		IF (reg # noBase) & (stack[i].mode = Register) & (stack[i].type = JavaLONG) THEN INC(c[reg]) END;
		reg := stack[i].index;
		IF reg # noBase THEN INC(c[reg]) END
	END;
	
	FOR i := 0 TO 7 DO
		IF ~((i IN {ESP, EBP}) OR (c[i] = Regs[i])) THEN
			DumpStack(debugInfo);
			HALT(99)
		END
	END
END CheckStackConsistency;

(* ---------- Code Generation --------- *)

PROCEDURE CheckPattern(VAR c, pattern: ARRAY OF CHAR; pc0: LONGINT; map: JB.Map): BOOLEAN;
	VAR i: LONGINT; res: BOOLEAN;
BEGIN
	i := 0;
	res := TRUE;
	WHILE res & (i < LEN(pattern)) DO
		res := (c[pc0] = pattern[i]) & (map[pc0] = 0);
		INC(pc0); INC(i)
	END;
	RETURN res
END CheckPattern;

PROCEDURE FixupFwdJmps(addr: LONGINT);
VAR next: LONGINT;
BEGIN
	WHILE addr # 0 DO
		JC0.GetDWord(addr, next); JC0.PutDWordAt(addr, JC0.pc-addr-4);
		addr := next-10000H
	END
END FixupFwdJmps;
	
PROCEDURE Jcc(cc :SHORTINT; pc0, offset: LONGINT; map: JB.Map);
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
	
PROCEDURE SystemCall(VAR fixadr: LONGINT);
BEGIN
	JC0.GenCALL(JC0.Imme, 0, noBase, noInx, noScale, fixadr+10000H);
	fixadr := JC0.pc - 4
END SystemCall;
	
PROCEDURE ReleaseItem(VAR it: Item);
BEGIN
	ReleaseReg(it.index);
	ReleaseReg(it.base);
	IF it.base # it.base2 THEN ReleaseReg(it.base2) END
END ReleaseItem;

PROCEDURE SetItem(VAR it: Item; mode: SHORTINT; val, val2, disp: LONGINT; base, base2, index: INTEGER; scale: SHORTINT);
BEGIN
	it.mode := mode;
	it.val := val;
	it.val2 := val2;
	it.disp := disp;
	it.base := base;
	it.base2 := base2;
	it.index := index;
	it.scale := scale;
END SetItem;

PROCEDURE LoadItemToReg(VAR item: Item; reg: INTEGER);
	VAR mode, type: LONGINT;
BEGIN
	ASSERT(item.type IN {JavaINT, JavaREF});
	IF (item.mode = Register) & (item.base = reg) THEN RETURN END;	(* already loaded into reg *)
	IF item.mode = FRegister THEN GenPushItem(item) END;
	ReleaseItem(item);
	AllocateThisReg(reg, MakeMask(item), TRUE);
	CASE item.mode OF
	| Register, Immediate, Local, Field, Static, Array:
			JC0.GenMOV(Mode[item.mode], reg, item.base, item.index, item.scale, item.disp, item.val);
	| Stack:
			JC0.GenPOP(JC0.Regs, reg, noBase, noInx, noScale, noDisp)
	END;
	SetItem(item, Register, noImm, noImm, noDisp, reg, noBase, noInx, noScale)
END LoadItemToReg;

PROCEDURE LoadItemToReg2(VAR item: Item; reg1, reg2: INTEGER);
	VAR mode, type: LONGINT; protect: SET;
BEGIN
	ASSERT(item.type = JavaLONG);
	IF (item.mode = Register) & (item.base = reg1) & (item.base2 = reg2) THEN INC(ALoad2Skip); RETURN END;	(* already loaded into reg *)
	IF item.mode = FRegister THEN GenPushItem(item) END;
	ReleaseItem(item);
	protect := MakeMask(item);
	AllocateThisReg(reg1, protect, TRUE);
	AllocateThisReg(reg2, protect, TRUE);
	CASE item.mode OF
	| Register:
			IF (item.base = reg2) & (item.base2 = reg1) THEN
				INC(ALoad2XCHG);
				JC0.GenXCHG(JC0.RegReg, reg1, reg2, noInx, noScale, noDisp)
			ELSIF item.base2 = reg1 THEN
				JC0.GenMOV(JC0.RegReg, reg2, item.base2, noInx, noScale, noDisp, noImm);
				JC0.GenMOV(JC0.RegReg, reg1, item.base, noInx, noScale, noDisp, noImm)
			ELSE
				IF item.base # reg1 THEN
					JC0.GenMOV(JC0.RegReg, reg1, item.base, noInx, noScale, noDisp, noImm)
				ELSE INC(ALoad2Sup1) END;
				IF item.base2 # reg2 THEN
					JC0.GenMOV(JC0.RegReg, reg2, item.base2, noInx, noScale, noDisp, noImm)
				ELSE INC(ALoad2Sup2) END
			END
	| Immediate, Local, Field, Static, Array:
			IF (reg1 # item.base) & (reg1 # item.index) THEN
				JC0.GenMOV(Mode[item.mode], reg1, item.base, item.index, item.scale, item.disp, item.val);
				JC0.GenMOV(Mode[item.mode], reg2, item.base2, item.index, item.scale, item.disp+4, item.val)
			ELSIF (reg2 # item.base) & (reg2 # item.index) THEN
				JC0.GenMOV(Mode[item.mode], reg2, item.base2, item.index, item.scale, item.disp+4, item.val);
				JC0.GenMOV(Mode[item.mode], reg1, item.base, item.index, item.scale, item.disp, item.val)
			ELSE
				HALT(99);	(* not implemented yet *)
			END;
	| Stack:
			JC0.GenPOP(JC0.Regs, reg1, noBase, noInx, noScale, noDisp);
			JC0.GenPOP(JC0.Regs, reg2, noBase, noInx, noScale, noDisp)
	END;
	SetItem(item, Register, noImm, noImm, noDisp, reg1, reg2, noInx, noScale)
END LoadItemToReg2;

PROCEDURE LoadItemToST(VAR item: Item);
BEGIN
	IF (item.mode = FRegister) THEN RETURN END;
	IF item.mode IN {Register, Immediate} THEN
		GenPushItem(item)	(* releases item *)
	ELSE
		ReleaseItem(item);
	END;
	
	CASE item.mode OF
	| Local, Field, Static, Array:
			JC0.GenFLD(JC0.Mem, FSize[item.type], item.base, item.index, Scale[item.type], item.disp)
	| Stack:
			JC0.GenFLD(JC0.Mem, FSize[item.type], ESP, noInx, noScale, 0);
			JC0.GenTyp1(JC0.ADD, JC0.ImmReg, ESP, noBase, noInx, noScale, noDisp, Size[item.type])
	END;
	SetItem(item, FRegister, noImm, noImm, noDisp, noBase, noBase, noInx, noScale)
END LoadItemToST;

PROCEDURE LoadItem(VAR item: Item);
	VAR reg, reg2: INTEGER;
		mode, type: LONGINT;
		
	PROCEDURE Allocate2;
	BEGIN
		reg := AllocateReg(Empty);
		IF RegCount(EDX) = 0 THEN
			AllocateThisReg(EDX, Empty, TRUE); reg2 := EDX
		ELSE
			reg2 := AllocateReg(Empty)
		END;
	END Allocate2;

(* no need to protect allocation: FreeItem is always done after the mov,
because the destination register can be freely choosed *)
	
BEGIN
	mode := item.mode; type := item.type;
	IF type IN {JavaFLOAT, JavaDOUBLE} THEN
		LoadItemToST(item);
		RETURN
	END;
	reg := noBase; reg2 := noBase;
	CASE item.mode OF
	| Register:
			ASSERT(type IN JavaInt4 + {JavaLONG});
			reg := item.base;
			reg2 := item.base2;
			IF (RegCount(item.base) > 1) THEN
				reg := AllocateReg(Empty);
				ReleaseReg(item.base);
				JC0.GenMOV(JC0.RegReg, reg, item.base, noInx, noScale, noDisp, item.val)
			END;
			IF (RegCount(item.base2) > 1) THEN
				reg2 := AllocateReg(Empty);
				ReleaseReg(item.base2);
				JC0.GenMOV(JC0.RegReg, reg2, item.base2, noInx, noScale, noDisp, item.val)
			END
	| FRegister:
			CASE item.type OF
			| JavaINT, JavaLONG, JavaREF:
				IF ShowWarnings >= 2 THEN
					JC.String(warningInfo, " ST -> Reg"); JC.Ln(warningInfo);
					END;
				GenPushItem(item);
				LoadItem(item);
				RETURN
			END
	| Immediate:
			CASE item.type OF
			| JavaINT, JavaREF:
				reg := AllocateReg(Empty);
				JC0.GenMOV(JC0.ImmReg, reg, noBase, noInx, noScale, noDisp, item.val)
			| JavaLONG:
				Allocate2;
				JC0.GenMOV(JC0.ImmReg, reg, noBase, noInx, noScale, noDisp, item.val);
				JC0.GenMOV(JC0.ImmReg, reg2, noBase, noInx, noScale, noDisp, item.val2)
			END
	| Local, Field, Static, Array:
			CASE item.type OF
			| JavaBOOL:
				reg := AllocateReg(Empty);
				JC0.GenTyp1(JC0.XOR, JC0.RegReg, reg, reg, noInx, noScale, noDisp, noImm);
				JC0.GenMOV(JC0.MemReg, reg+AL, item.base, item.index, JC0.Scale2, item.disp, noImm);
				item.type := JavaINT
			| JavaBYTE:
				reg := AllocateReg(Empty);
				JC0.GenMOVSX(JC0.MemReg, 0, reg, item.base, item.index, JC0.Scale1, item.disp);
				item.type := JavaINT
			| JavaSHORT:
				reg := AllocateReg(Empty);
				JC0.GenMOVSX(JC0.MemReg, 1, reg, item.base, item.index, JC0.Scale2, item.disp);
				item.type := JavaINT
			| JavaCHAR:
				reg := AllocateReg(Empty);
				JC0.GenTyp1(JC0.XOR, JC0.RegReg, reg, reg, noInx, noScale, noDisp, noImm);
				JC0.GenMOV(JC0.MemReg, reg+AX, item.base, item.index, JC0.Scale2, item.disp, noImm);
				item.type := JavaINT
			| JavaINT, JavaREF:
				reg := AllocateReg(Empty);
				JC0.GenMOV(JC0.MemReg, reg, item.base, item.index, JC0.Scale4, item.disp, noImm)
			| JavaLONG:
				Allocate2;
				JC0.GenMOV(JC0.MemReg, reg, item.base, item.index, JC0.Scale8, item.disp, noImm);
				JC0.GenMOV(JC0.MemReg, reg2, item.base2, item.index, JC0.Scale8, item.disp+4, noImm)
			END;
			ReleaseItem(item);
	| Stack:
			CASE item.type OF
			| JavaINT, JavaREF, JavaBOOL:
				reg := AllocateReg(Empty);
				JC0.GenPOP(JC0.Regs, reg, noBase, noInx, noScale, noDisp)
			| JavaLONG:
				Allocate2;
				JC0.GenPOP(JC0.Regs, reg, noBase, noInx, noScale, noDisp);
				JC0.GenPOP(JC0.Regs, reg2, noBase, noInx, noScale, noDisp)
			END
	END;
	
	IF item.type IN {JavaSHORT, JavaCHAR, JavaBYTE} THEN item.type := JavaINT END;
	
	IF item.type IN {JavaINT, JavaREF, JavaLONG} THEN
		SetItem(item, Register, noImm, noImm, noDisp, reg, reg2, noInx, noScale)
	ELSE
		HALT(99)
	END
END LoadItem;

PROCEDURE CheckStack(off: LONGINT; local: BOOLEAN);
	VAR i, j, c: LONGINT; mode: SET;
BEGIN
	i := tos-1;
	IF local THEN
		mode := {Local}
	ELSE
		mode := {Field, Array, Static}
	END;
	WHILE (i >= 0) & ~((stack[i].mode IN mode) & (stack[i].disp = off)) DO DEC(i) END;
	IF i >= 0 THEN
(*
		LoadItem(stack[i]);
		WHILE (i >= 0) & ~((stack[i].mode IN mode) & (stack[i].disp = off)) DO DEC(i) END;
		IF i >= 0 THEN
			JC.String("CheckStack. Error"); JC.Ln
		END;
		ASSERT(i < 0);
*)
		j := 0; WHILE (stack[j].mode = Stack) DO INC(j) END;
		IF ShowWarnings >= 2 THEN JC.String(warningInfo, "  CheckStack, alias found"); JC.Ln(warningInfo) END;
		FOR c := j TO i DO GenPushItem(stack[c]) END
	END
END CheckStack;

PROCEDURE StoreItem(type: LONGINT; base, index: INTEGER; scale: SHORTINT; disp: LONGINT; item: Item);
BEGIN
	IF ~(item.mode IN {Register, FRegister, Immediate, Stack}) OR 
		((item.mode = Stack) & ((item.type IN JavaShorts)OR(type IN JavaShorts))) THEN
		LoadItem(item)
	END;
		(* check for aliases on the stack *)
	CheckStack(disp, base = EBP);
	
	IF item.mode = Register THEN
		ASSERT(item.base IN {EAX..EDI});
		ASSERT((item.base2 = noBase) OR (item.base2 IN {EAX..EDI}));
		CASE type OF
		| JavaBYTE, JavaBOOL:
				JC0.GenMOV(JC0.RegMem, item.base+AL, base, index, scale, disp, noImm);
		| JavaCHAR, JavaSHORT:
				JC0.GenMOV(JC0.RegMem, item.base+AX, base, index, scale, disp, noImm);
		| JavaINT, JavaREF:
				JC0.GenMOV(JC0.RegMem, item.base, base, index, scale, disp, noImm);
		| JavaLONG:
				JC0.GenMOV(JC0.RegMem, item.base, base, index, scale, disp, noImm);
				JC0.GenMOV(JC0.RegMem, item.base2, base, index, scale, disp+4, noImm);
		END
	ELSIF item.mode = FRegister THEN
		ASSERT(type IN {JavaFLOAT, JavaDOUBLE, JavaINT, JavaREF, JavaLONG});
		ASSERT(type = item.type);
		IF item.type IN JavaInts+{JavaLONG} THEN
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, JS.RCHOP);
			JC0.GenFLDCW(ESP, noInx, noScale, noDisp);
			JC0.GenTyp1(JC0.ADD, JC0.ImmReg, ESP, noBase, noInx, noScale, noDisp, 4)
		END;
		JC0.GenFSTP(JC0.RegMem, FSize[type], base, index, scale, disp);
		IF item.type IN JavaInts+{JavaLONG} THEN
			JC0.GenFLDCW(noBase, noInx, noScale, SYSTEM.ADR(AosBoot.fcr));
		END;
	ELSIF item.mode = Immediate THEN
		CASE type OF
		| JavaBYTE, JavaBOOL:
				JC0.GenMOV(JC0.ImmMem, AL, base, index, scale, disp, item.val)
		| JavaCHAR, JavaSHORT:
				JC0.GenMOV(JC0.ImmMem, AX, base, index, scale, disp, item.val)
		| JavaINT, JavaREF, JavaFLOAT:
				JC0.GenMOV(JC0.ImmMem, EAX, base, index, scale, disp, item.val)
		| JavaLONG, JavaDOUBLE:
				JC0.GenMOV(JC0.ImmMem, EAX, base, index, scale, disp+0, item.val);
				JC0.GenMOV(JC0.ImmMem, EAX, base, index, scale, disp+4, item.val2)
		END
	ELSIF item.mode = Stack THEN
		CASE type OF
		| JavaINT, JavaREF, JavaFLOAT:
				JC0.GenPOP(JC0.Mem, EAX, base, index, scale, disp+0)
		| JavaLONG, JavaDOUBLE:
				JC0.GenPOP(JC0.Mem, EAX, base, index, scale, disp+0);
				JC0.GenPOP(JC0.Mem, EAX, base, index, scale, disp+4)
		END
	ELSE
		HALT(99)
	END;
	ReleaseItem(item);
	ReleaseReg(base);
	ReleaseReg(index)
END StoreItem;

PROCEDURE GenPushItem(VAR it: Item);
	VAR mode: LONGINT;
BEGIN
	IF (it.type IN {JavaBYTE, JavaSHORT, JavaCHAR}) & (it.mode # Register) THEN
		LoadItem(it)
	END;
	mode := it.mode;
	CASE it.mode OF
	| Register, Local, Immediate, Static, Field, Array:
			IF it.type IN {JavaLONG, JavaDOUBLE} THEN
				JC0.GenPUSH(Mode[it.mode], it.base2, it.base2, it.index, it.scale, it.disp+4, it.val2)
			END;
			JC0.GenPUSH(Mode[it.mode], it.base, it.base, it.index, it.scale, it.disp, it.val);
			ReleaseItem(it)
	| FRegister:
			IF it.type IN JavaInts+{JavaLONG} THEN
				JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, JS.RCHOP);
				JC0.GenFLDCW(ESP, noInx, noScale, noDisp);
				JC0.GenTyp1(JC0.ADD, JC0.ImmReg, ESP, noBase, noInx, noScale, noDisp, 4)
			END;
			JC0.GenTyp1(JC0.SUB, JC0.ImmReg, ESP, noBase, noInx, noScale, noDisp, Size[it.type]);
			JC0.GenFSTP(JC0.RegMem, FSize[it.type], ESP, noInx, noScale, 0);
			IF it.type IN JavaInts+{JavaLONG} THEN
				JC0.GenFLDCW(noBase, noInx, noScale, SYSTEM.ADR(AosBoot.fcr));
			END;
	END;
	SetItem(it, Stack, noImm, noImm, noDisp, noBase, noBase, noInx, noScale)
END GenPushItem;

PROCEDURE DuplicateItem(VAR it1, it2: Item);
	VAR reg, reg2: INTEGER; mode: SHORTINT; mask: SET;
BEGIN
	mode := it1.mode;
	CASE mode OF
	| Register:
			mask := MakeMask(it1);
			reg := AllocateReg(mask); reg2 := noBase;
			JC0.GenMOV(JC0.RegReg, reg, it1.base, noInx, noScale, noDisp, noImm);
			IF it1.type IN Java2 THEN
				reg2 := AllocateReg(mask+{reg});
				JC0.GenMOV(JC0.RegReg, reg2, it1.base2, noInx, noScale, noDisp, noImm)
			END;
			SetItem(it2, Register, noImm, noImm, noDisp, reg, reg2, noInx, noScale);
			it2.type := it1.type
	| FRegister:
			JC0.GenFLD(JC0.Regs, FSize[it1.type], 0, noInx, noScale, noDisp);	(* FLD ST(0) *)
			it2 := it1
	| Local, Static, Immediate, Constant:
			it2 := it1
	| Field:
			it2 := it1;
			AllocateThisReg(it1.base, Empty, FALSE)
	| Array:
			it2 := it1;
			AllocateThisReg(it1.base, Empty, FALSE);
			AllocateThisReg(it1.index, Empty, FALSE)
	END
END DuplicateItem;

PROCEDURE ScanBasicBlocks(c: JB.RefClass; code: JB.ACodeInfo): BasicBlock;
	VAR
		root, p, q, s0, s1: BasicBlock;	(* first element is empty (sentinel) *)
		blockCount, op, tos, minTos, i, nextCount: LONGINT;
		stack: ARRAY 16 OF StackItem;
		creator: ARRAY 16 OF LONGINT;
		high, low, pc, pc0, val, idx, off, tag, count, s, t, r, v1, v2, v3: LONGINT;
		b, Wide: BOOLEAN;
		cf: JB.RefClass;
		flushLevel: LONGINT;	(* stack is flushed up to this level (consider only external elements) *)
		
	PROCEDURE Push(i: LONGINT);
	BEGIN
		stack[tos].type := SHORT(SHORT(i));
		stack[tos].pc := pc0;
		stack[tos].block := p;
		creator[tos] := pc0;
		INC(tos)
	END Push;
	
	PROCEDURE Pop(i: LONGINT);
	BEGIN
		DEC(tos);
		IF tos < minTos THEN minTos := tos END;
		IF tos < flushLevel THEN flushLevel := tos END;
		ASSERT(stack[tos].type = i);
	END Pop;
	
	PROCEDURE PopType(t: SET; VAR type: LONGINT);
	BEGIN
		DEC(tos);
		type := stack[tos].type;
		IF tos < minTos THEN minTos := tos END;
		IF tos < flushLevel THEN flushLevel := tos END;
		ASSERT(type IN t);
	END PopType;
	
	PROCEDURE GetInfo(index: LONGINT; VAR t: LONGINT; VAR flush: BOOLEAN);
		VAR ref: JB.CRefInfo; cf: JB.RefClass;
	BEGIN
		ref := c.constPool[index](JB.CRefInfo);
		ASSERT(~(ref.obj IS PCT.Value));
		t := OberonToJavaType(ref.obj.type);
		
		cf := ref.effectiveClass(JB.RefClass);
		flush := (cf.state < JB.Initialized) & (cf # c)
	END GetInfo;
	
	PROCEDURE InsertBasicBlock(mode, pc, tos: LONGINT; VAR stack: ARRAY OF StackItem): BasicBlock;
		VAR p, q, b: BasicBlock; i: LONGINT;
	BEGIN
(*
		JC.String(debugInfo, ">"); JC.Int(debugInfo, pc,0); JC.Ln(debugInfo);
*)
		p := root; q := p.next;
		WHILE (q # NIL) & (q.begin < pc) DO  p := q; q := q.next  END;
		IF (q = NIL) OR (q.begin # pc) THEN
			(* new *)
			IF ((p.end = 0) & (pc <= pc0)) OR (p.end > pc) THEN	(* jump in the middle of the current block *)
				JC.String(debugInfo, "Reparsing forced. Current block split at "); JC.Int(debugInfo, pc, 0); 
				JC.String(debugInfo, "/"); JC.Int(debugInfo, pc0, 0); JC.Ln(debugInfo);
				ASSERT(p # root);
				IF ~p.new THEN
					p.new := TRUE;	(* force reparsing of this block *)
					INC(nextCount)
				END
			END;
			NEW(b); INC(nextCount);
			b.nr := blockCount; INC(blockCount);
			b.next := p.next; p.next := b;
			b.begin := pc; b.tos := tos;
			b.new := TRUE;
			FOR i := 0 TO tos-1 DO  b.stack[i] := stack[i] END;
			INCL(b.mode, mode)
		ELSE
			(* existing *)
			ASSERT(q.tos = tos);
			FOR i := 0 TO tos-1 DO
				ASSERT(q.stack[i].type = stack[i].type);
				IF q.stack[i].block # stack[i].block THEN
					b := q.stack[i].block;
					IF b # NIL THEN  b.mustPush[i] := TRUE END;
					b := stack[i].block;
					IF b # NIL THEN  b.mustPush[i] := TRUE END;
					q.stack[i].block := NIL;	(* mark as having multiple creators *)
				END;
			END;
			INCL(q.mode, mode);
			b := q
		END;
		RETURN b
	END InsertBasicBlock;
	
	PROCEDURE CommitBasicBlock(p: BasicBlock; end, tos, minTos, flushLevel: LONGINT; VAR creator: ARRAY OF LONGINT);
		VAR i: LONGINT;
	BEGIN
		p.end := end;
		p.minTos := minTos;
		p.succ := NIL;
		FOR i := 0 TO tos-1 DO  p.creator[i] := creator[i]  END;
		IF EnableStackFlushDetection THEN
			FOR i := 0 TO flushLevel-1 DO p.mustPush[i] := TRUE END;
			IF flushLevel > 0 THEN
				JC.Int(debugInfo, end, 3); JC.String(debugInfo, ": Commit: Flush ");
				JC.Int(debugInfo, flushLevel, 0); JC.Ln(debugInfo)
			END
		END
	END CommitBasicBlock;
	
	PROCEDURE CommitBasicBlock1(p: BasicBlock; end, tos, minTos, flushLevel: LONGINT; VAR creator: ARRAY OF LONGINT; succ: BasicBlock);
	BEGIN
		CommitBasicBlock(p, end, tos, minTos, flushLevel, creator);
		NEW(p.succ, 1);
		p.succ[0] := succ;
	END CommitBasicBlock1;
	
	PROCEDURE CommitBasicBlock2(p: BasicBlock; end, tos, minTos, flushLevel: LONGINT; VAR creator: ARRAY OF LONGINT; succ0, succ1: BasicBlock);
	BEGIN
		CommitBasicBlock(p, end, tos, minTos, flushLevel, creator);
		NEW(p.succ, 2);
		p.succ[0] := succ0;
		p.succ[1] := succ1;
	END CommitBasicBlock2;
	
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
	
	PROCEDURE FlushStack;
	BEGIN
		IF EnableStackFlushDetection THEN
			i := 0;
			WHILE (i < tos-1) & (stack[i].block # p) DO
				IF ~stack[i].block.mustPush[i] THEN
					JC.Int(debugInfo, pc0, 3); JC.String(debugInfo, ": MustPush ");
					JC.Int(debugInfo, stack[i].block.creator[i], 0); JC.Ln(debugInfo)
				END;
				stack[i].block.mustPush[i] := TRUE;
				INC(i)
			END
		END;
		flushLevel := tos
	END FlushStack;
	
	PROCEDURE Invoke(op, idx: LONGINT);
		VAR ref: JB.CRefInfo; obj: JB.Method; proc: PCT.Proc; cf: JB.Class; super: BOOLEAN; t: LONGINT;
	BEGIN
		ref := c.constPool[idx](JB.CRefInfo);
		cf := ref.cindex.class;
		obj := ref.ref(JB.Method);
		proc := obj.p;
		FOR i := 0 TO proc.scope.parCount-1 DO  DEC(tos)  END;
		IF tos < flushLevel THEN flushLevel := tos END;
		FlushStack;
		IF tos < minTos THEN minTos := tos END;
		IF proc.type # PCT.NoType THEN
			t := OberonToJavaType(proc.type);
			IF ~(t IN Java1+Java2) THEN t := JavaINT END;
			Push(t);
		END
	END Invoke;
	
BEGIN
	(* init bb list *)
	(* init next to scan list *)
	nextCount := 0;
	NEW(root); root.next := NIL; root.end := -1; root.new := FALSE;
	p := InsertBasicBlock(Jump, 0, 0, stack);
	
	Push(JavaREF);
	IF code.exceptions # NIL THEN
		FOR i := 0 TO LEN(code.exceptions)-1 DO
			p := InsertBasicBlock(Catch, code.exceptions[i].handler, 1, stack)
		END
	END;
	
	(* foreach entry in next list *)
	WHILE nextCount > 0 DO
		p := root.next;
		WHILE ~p.new DO p := p.next END;
		p.new := FALSE; DEC(nextCount);
		
		(* restore stack *)
		tos := p.tos; pc := p.begin; minTos := tos;
		flushLevel := 0;
		FOR i := 0 TO tos-1 DO  stack[i] := p.stack[i]  END;
		
		LOOP  (* loop *)
			(* if pc in bb -> check stack consistency *)
			IF (p.next # NIL) & (p.next.begin = pc) THEN
				q := InsertBasicBlock(Fall, pc, tos, stack);	(* this implicitly performs the stack equivalence check *)
				ASSERT(q = p.next);	(*sanity check*)
				CommitBasicBlock1(p, pc, tos, minTos, flushLevel, creator, q);
				p := q;
				IF p.new THEN DEC(nextCount); p.new := FALSE END;
				minTos := tos;
				flushLevel := 0;
			END;
			
			(* process stack *)
			pc0 := pc;
			op := ORD(code.code[pc]); INC(pc);
(*
			JC.Int(pc0, 4); JC.Int(op, 4); JC.Int(tos, 4); JC.Ln;
*)
			CASE op OF
			| nop:
			| aconstnull:
					Push(JavaREF)
			| iconstm1 .. iconst5:
					Push(JavaINT)
			| lconst0 .. lconst1:
					Push(JavaLONG)
			| fconst0 .. fconst2:
					Push(JavaFLOAT)
			| dconst0 .. dconst1:
					Push(JavaDOUBLE)
			| bipush:
					val := Value(1);
					Push(JavaINT)
			| sipush:
					val := Value(2);
					Push(JavaINT)
			| ldc, ldcw, ldc2w:
					idx := Index(op # ldc);	(* ldc -> 1, ldcw/ldc2w -> 2 *)
					tag := c.constPool[idx].tag;
					CASE tag OF
					|  JB.CInteger:  Push(JavaINT)
					|  JB.CFloat:  Push(JavaFLOAT)
					|  JB.CString:  Push(JavaREF)
					|  JB.CLong:  Push(JavaLONG)
					|  JB.CDouble:  Push(JavaDOUBLE)
					END
			| iload .. aload:
					idx := Index(Wide); Wide := FALSE;
					Push(op-iload)
			| iload0 .. iload3, lload0 .. lload3, fload0 .. fload3, dload0 .. dload3, aload0 .. aload3:
					Push((op - iload0) DIV 4)
			| iaload .. saload:
					Pop(JavaINT);
					Pop(JavaREF);
					t := op - iaload;
					IF ~(t IN Java1+Java2) THEN t := JavaINT END;
					Push(t)
			| istore .. astore:
					idx := Index(Wide); Wide := FALSE;
					Pop(op - istore);
			| istore0 .. istore3, lstore0 .. lstore3, fstore0 .. fstore3, dstore0 .. dstore3, astore0 .. astore3:
					Pop((op - istore0) DIV 4);
			| iastore .. sastore:
					t := op - iastore;
					IF t IN JavaShorts THEN Pop(JavaINT) ELSE Pop(t) END;
					Pop(JavaINT);
					Pop(JavaREF);
			| pop:
					PopType(Java1, t);
			| pop2:
					PopType(Java2, t);
			| dupx1:
					PopType(Java1, t); PopType(Java1, s);
					Push(t); Push(s); Push(t)
			| dupx2:
					PopType(Java1, t); PopType(Java1, s); PopType(Java1, r);
					Push(t); Push(r); Push(s); Push(t)
			| dup, dup2:
					PopType(Java1+Java2, t);
					ASSERT((t IN Java1) OR (op # dup));	(* check: dup => t in Java1 *)
					IF (op = dup) OR (t IN Java2) THEN
						Push(t); Push(t)
					ELSE
						PopType(Java1, s);
						Push(s); Push(t); Push(s); Push(t)
					END
			| dup2x1:
					PopType(Java2, v1);
					PopType(Java1, v2);
					Push(v1); Push(v2); Push(v1)
(*
					PopType(Java1+Java2, v1);
					ASSERT((v1 IN Java1) OR (op # dupx1));	(* check: dupx1 => t in Java1 *)
					IF (op = dupx1) OR (v1 IN Java2) THEN
						(* DUP_X1 : ..., v2, v1 => ..., v1, v2, v1 *)
						(* DUP2_X1 form 1 (v1 has computational type 2): ..., v2, v1 => ..., v1, v2, v1 *)
						PopType(Java1, v2);
						Push(v1); Push(v2); Push(v1)
					ELSE
						(* DUP2_X1 form 2 (v1 has computational type 1): ..., v3, v2, v1 => v2, v1, v3, v2, v1 *)
						PopType(Java1, v2); PopType(Java1, v3);
						Push(v2); Push(v1); Push(v3); Push(v2); Push(v1)
					END
*)
			| dup2x2:
					PopType(Java2, t); PopType(Java1, s); PopType(Java1, r);
					Push(t); Push(r); Push(s); Push(t)
			| swap:
					PopType(Java1, t); PopType(Java1, s);
					Push(t); Push(s)
			| iadd .. drem:
					t := (op - iadd) MOD 4;
					Pop(t); Pop(t); Push(t)
			| ineg .. dneg:
					t := (op - ineg);
					Pop(t); Push(t)
			| ishl, ishr, iushr, iand, ior, ixor:
					Pop(JavaINT); Pop(JavaINT); Push(JavaINT);
			| lshl, lshr, lushr:
					Pop(JavaINT); Pop(JavaLONG); Push(JavaLONG);
			| land, lor, lxor:
					Pop(JavaLONG); Pop(JavaLONG); Push(JavaLONG);
			| iinc:
					idx := Index(Wide);
					IF Wide THEN Wide := FALSE; val := Value(2) ELSE val := Value(1) END;
			| i2f, i2d, l2f, l2d:
					t := (op - i2l) DIV 3;
					s := (op - i2l) MOD 3 + JavaLONG;
					Pop(t); Push(s)
			| f2i, d2i, f2l, d2l:
					t := (op - f2i) DIV 3 + JavaFLOAT;
					s := (op - f2i) MOD 3 + JavaINT;
					Pop(t); Push(s)
			| l2i:
					Pop(JavaLONG); Push(JavaINT);
			| i2l:
					Pop(JavaINT); Push(JavaLONG);
			| d2f:
					Pop(JavaDOUBLE); Push(JavaFLOAT);
			| f2d:
					Pop(JavaFLOAT); Push(JavaDOUBLE);
			| i2b, i2c, i2s:
					Pop(JavaINT); Push(JavaINT);
			| lcmp:
					Pop(JavaLONG); Pop(JavaLONG); Push(JavaINT);
			| fcmpl, fcmpg:
					Pop(JavaFLOAT); Pop(JavaFLOAT); Push(JavaINT);
			| dcmpl, dcmpg:
					Pop(JavaDOUBLE); Pop(JavaDOUBLE); Push(JavaINT);
			| ifeq .. ifle:	(* jump *)
					Pop(JavaINT);
					val := Value(2);
					s0 := InsertBasicBlock(Fall, pc, tos, stack);
					s1 := InsertBasicBlock(Jump, pc0+val, tos, stack);
					CommitBasicBlock2(p, pc, tos, minTos, flushLevel, creator, s0, s1);
					EXIT
			| ificmpeq .. ificmple:	(* jump *)
					Pop(JavaINT); Pop(JavaINT);
					val := Value(2);
					s0 := InsertBasicBlock(Fall, pc, tos, stack);
					s1 := InsertBasicBlock(Jump, pc0+val, tos, stack);
					CommitBasicBlock2(p, pc, tos, minTos, flushLevel, creator, s0, s1);
					EXIT
			| ifacmpeq .. ifacmpne:	(* jump *)
					Pop(JavaREF); Pop(JavaREF);
					val := Value(2);
					s0 := InsertBasicBlock(Fall, pc, tos, stack);
					s1 := InsertBasicBlock(Jump, pc0+val, tos, stack);
					CommitBasicBlock2(p, pc, tos, minTos, flushLevel, creator, s0, s1);
					EXIT
			| goto:	(* jump *)
					val := Value(2);
					s0 := InsertBasicBlock(Jump, pc0+val, tos, stack);
					CommitBasicBlock1(p, pc, tos, minTos, flushLevel, creator, s0);
					EXIT
			| jsr:	(* jump *)
					val := Value(2);
					Push(JavaREF);
					s0 := InsertBasicBlock(Sub, pc0+val, tos, stack);
					Pop(JavaREF);
			| ret:
					idx := Index(Wide); Wide := FALSE;
					(*p.end := pc; p.minTos := minTos;*)	(*Commit*)
					CommitBasicBlock(p, pc, tos, minTos, flushLevel, creator);
					EXIT
			| tableswitch:
					INC(pc, (-pc) MOD 4);
					off := Value(4);	(* default *)
					low := Value(4);	(* low *)
					high := Value(4);	(* high *)
					count := high - low + 1;
					Pop(JavaINT);
					NEW(p.succ, count+1);
					p.succ[0] := InsertBasicBlock(Jump, pc0+off, tos, stack);
					WHILE count > 0 DO
						off := Value(4); 												(* table consist of a sequence of jmp instructions *)			
						p.succ[count] := InsertBasicBlock(Jump, pc0+off, tos, stack);
						DEC(count) 
					END;
					CommitBasicBlock(p, pc, tos, minTos, flushLevel, creator);
					EXIT
			| lookupswitch:
					INC(pc, (-pc) MOD 4);
					Pop(JavaINT);
					idx := Value(4);
					count := Value(4);
					NEW(p.succ, count+1);
					p.succ[count] := InsertBasicBlock(Jump, pc0+idx, tos, stack);
					FOR i := 0 TO count-1 DO
						val := Value(4);	(* key *)
						off := Value(4);	(* label *)
						p.succ[i] := InsertBasicBlock(Jump, pc0+off, tos, stack);
					END;
					CommitBasicBlock(p, pc, tos, minTos, flushLevel, creator);
					EXIT
			| ireturn .. areturn, return:
					IF op # return THEN 
						s := op - ireturn;
						Pop(s);
					END;
					CommitBasicBlock(p, pc, tos, minTos, flushLevel, creator);
					EXIT
			| getstatic:
					idx := Index(TRUE);
					GetInfo(idx, t, b);
					IF b THEN FlushStack END;
					IF t IN JavaShorts THEN s := JavaINT ELSE s := t END;
					Push(s)
			| putstatic:
					idx := Index(TRUE);
					GetInfo(idx, t, b);
					IF b THEN FlushStack END;
					IF t IN JavaShorts THEN s := JavaINT ELSE s := t END;
					Pop(s);
			| getfield:
					idx := Index(TRUE);
					GetInfo(idx, t, b);
					IF t IN JavaShorts THEN s := JavaINT ELSE s := t END;
					Pop(JavaREF);
					Push(s)
			| putfield:
					idx := Index(TRUE);
					GetInfo(idx, t, b);
					IF t IN JavaShorts THEN s := JavaINT ELSE s := t END;
					Pop(s);
					Pop(JavaREF)
			| invokevirtual, invokespecial, invokestatic, invokeinterface:
					idx := Index(TRUE);
					IF op = invokeinterface THEN INC(pc, 2);	(*skip count, 0 *)  END;
					Invoke(op, idx)
			| newarray:
					Pop(JavaINT);	(* consume count from virtual stack *)
					FlushStack;
					idx := Index(FALSE);
					Push(JavaREF)
			| new, anewarray, multianewarray:
					idx := Index(TRUE);
					IF op = anewarray THEN
						Pop(JavaINT);	(* consume count from virtual stack *)
					ELSIF op = multianewarray THEN
						val := Index(FALSE);	(* n *)
						WHILE val > 0 DO
							Pop(JavaINT); DEC(val)		(* remove count from virtual stack *)
						END
					END;
					FlushStack;
					Push(JavaREF)
			| arraylength:
					Pop(JavaREF);
					Push(JavaINT);	(* array dim is 1 pos before first elem *)
			| athrow:
					Pop(JavaREF);
					p.end := pc;
					EXIT
			| checkcast:
					FlushStack;
					idx := Index(TRUE);
			| instanceof:
					FlushStack;
					Pop(JavaREF);
					idx := Index(TRUE);
					Push(JavaINT);
			| monitorenter, monitorexit:
					Pop(JavaREF);	(* consume parameter *)
					FlushStack;
			| wide:
					Wide := TRUE
			| ifnull, ifnonnull:	(* jump *)
					Pop(JavaREF);
					val := Value(2);
					s0 := InsertBasicBlock(Fall, pc, tos, stack);
					s1 := InsertBasicBlock(Jump, pc0+val, tos, stack);
					CommitBasicBlock2(p, pc, tos, minTos, flushLevel, creator, s0, s1);
					EXIT
			| gotow:	(* jump *)
					val := Value(4);
					s0 := InsertBasicBlock(Jump,pc0+val, tos, stack);
					CommitBasicBlock1(p, pc, tos, minTos, flushLevel, creator, s0);
					EXIT;
			| jsrw:	(* jump *)
					val := Value(4);
					Push(JavaREF);
					s0 := InsertBasicBlock(Sub, pc0+val, tos, stack);
					Pop(JavaREF);
			END
		END; (* end-loop *)
	END; (* end-foreach *)
	IF TraceBorders THEN DumpBasicBlocks(root.next) END;
	RETURN root.next
END ScanBasicBlocks;

PROCEDURE Traverse(c: JB.RefClass; m: JB.Method; block: BasicBlock; code: JB.ACodeInfo;
							nofParams, nofLocals: LONGINT; VAR map: JB.Map);
	VAR
		i, j, pc, pc0, op, s, t, u, tag, curException: LONGINT;
		val, idx, off, count, low, high: LONGINT;
		dead, Wide: BOOLEAN;
		cf: JB.RefClass;
		con: PCT.Const;
		it, ita, itb, itc: Item;
		v1, v1c, v2, v2c, v3: Item;
		pc3: LONGINT;
		reg1: INTEGER;
		
	PROCEDURE FpOffset(index: LONGINT): LONGINT;
	BEGIN
		IF JB.AFStatic IN m.flags THEN
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
	
	PROCEDURE FlushStack;
		VAR i, j: LONGINT; warn: BOOLEAN;
	BEGIN
		IF TraceEmit THEN JC.String(debugInfo, "FlushStack 0 - "); JC.Int(debugInfo, tos-1, 0); JC.Ln(debugInfo) END;
		warn := FALSE;
		i := 0;
		WHILE (i < tos) & (stack[i].mode = Stack) DO INC(i) END;
		
		j := tos-1;
		WHILE (j > i) DO
			IF stack[j].mode = Stack THEN
				LoadItem(stack[j]);
				warn := TRUE
			END;
			DEC(j)
		END;
		IF (ShowWarnings >= 2) & warn THEN
			JC.String(warningInfo, "  FlushStack, non-contiguous stack"); JC.Ln(warningInfo)
		END;
		
		WHILE (i < tos) DO
			ASSERT(stack[i].mode # Stack);
			GenPushItem(stack[i]);
			INC(i)
		END
	END FlushStack;
	
	PROCEDURE CheckInitialized(cf: JB.Class);
	BEGIN
		INC(AinitCheckAsked);
		IF (SuppressCheckInitOptimization OR (cf.state < JB.Initialized)) & (cf # c) THEN
			INC(AinitCheckEmitted);
			FlushStack;
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, cf));
			SystemCall(c.fixsyscalls[JB.SCCheckInitialized])
		END;
	END CheckInitialized;
	
	PROCEDURE Pop(t: LONGINT);
	BEGIN
		DEC(tos);
		IF TraceEmit THEN JC.String(debugInfo, " ^"); JC.Char(debugInfo, T[stack[tos].type]) END;
		IF stack[tos].type # t THEN
			JC.String(errorInfo, "Pop Error at "); JC.Int(errorInfo, pc0, 0);
			JC.String(errorInfo, " / expected = "); JC.String(errorInfo, Type[t]); JC.Ln(errorInfo);
			DumpStack(errorInfo);
		END
	END Pop;
	
	PROCEDURE PopItem(t: SET; VAR i: Item);
		VAR type: LONGINT;
	BEGIN
		DEC(tos);
		type := stack[tos].type;
		IF TraceEmit THEN JC.String(debugInfo, " ^"); JC.Char(debugInfo, T[stack[tos].type]) END;
		IF ~PreloadShorts & (stack[tos].type IN JavaShorts) THEN LoadItem(stack[tos]) END;
		IF ~((type IN t) OR ((type = JavaINT) & (t = {JavaBOOL}))) THEN
			JC.String(errorInfo, "Pop Error at "); JC.Int(errorInfo, pc0, 0);
			JC.String(errorInfo, " / expected = "); DumpTypes(errorInfo, t); JC.Ln(errorInfo);
			DumpStack(errorInfo);
		END;
		i := stack[tos];
	END PopItem;
	
	PROCEDURE Push(t: LONGINT);
	BEGIN
		IF TraceEmit THEN JC.String(debugInfo, " !"); JC.Char(debugInfo, T[t]) END;
		stack[tos].type := SHORT(SHORT(t));
		INC(tos)
	END Push;
	
	PROCEDURE PushItem(VAR it: Item);
	BEGIN
		stack[tos] := it;
		Push(it.type)
	END PushItem;
	
	PROCEDURE PushRegister(type: LONGINT; reg, reg2: INTEGER);
	BEGIN
		SetItem(stack[tos], Register, noImm, noImm, noDisp, reg, reg2, noInx, noScale);
		Push(type)
	END PushRegister;
	
	PROCEDURE PushFRegister(type: LONGINT);
	BEGIN
		SetItem(stack[tos], FRegister, noImm, noImm, noDisp, noBase, noBase, noInx, noScale);
		Push(type)
	END PushFRegister;
	
	PROCEDURE PushImmediate(type, val: LONGINT);
	BEGIN
		SetItem(stack[tos], Immediate, val, noImm, noDisp, noBase, noBase, noInx, noScale);
		Push(type)
	END PushImmediate;
	
	PROCEDURE PushImmediate2(type: LONGINT; val: HUGEINT);
	BEGIN
		SetItem(stack[tos], Immediate, SHORT(val), SHORT(ASH(val, -32)), noDisp, noBase, noBase, noInx, noScale);
		Push(type)
	END PushImmediate2;
	
	PROCEDURE PushLocal(type, n: LONGINT);	(* xload-n *)
	BEGIN
		SetItem(stack[tos], Local, noImm, noImm, FpOffset(n), EBP, EBP, noInx, noScale);
		Push(type)
	END PushLocal;
	
	PROCEDURE PushStatic(type, abs: LONGINT);
	BEGIN
		SetItem(stack[tos], Static, noImm, noImm, abs, noBase, noBase, noInx, noScale);
		IF PreloadShorts & (type IN JavaShorts) THEN
			stack[tos].type := SHORT(SHORT(type));
			LoadItem(stack[tos]);
			type := JavaINT;
		END;
		Push(type)
	END PushStatic;
	
	PROCEDURE PushField(type: LONGINT; base: INTEGER; offset: LONGINT);
	BEGIN
		SetItem(stack[tos], Field, noImm, noImm, offset, base, base, noInx, noScale);
		IF PreloadShorts & (type IN JavaShorts) THEN
			stack[tos].type := SHORT(SHORT(type));
			LoadItem(stack[tos]);
			type := JavaINT;
		END;
		Push(type)
	END PushField;
	
	PROCEDURE PushArray(type: LONGINT; base, inx: INTEGER; offset: LONGINT);
	BEGIN
		IF inx = noInx THEN
			SetItem(stack[tos], Field, noImm, noImm, Size[type]*offset+FirstArrayElem, base, base, noInx, noScale)
		ELSE
			SetItem(stack[tos], Array, noImm, noImm, Size[type]*offset+FirstArrayElem, base, base, inx, Scale[type])
		END;
		IF PreloadShorts & (type IN JavaShorts) THEN
			stack[tos].type := SHORT(SHORT(type));
			LoadItem(stack[tos]);
			type := JavaINT;
		END;
		Push(type);
	END PushArray;
	
	PROCEDURE PushStack(type: LONGINT);
	BEGIN
		SetItem(stack[tos], Stack, noImm, noImm, noDisp, noBase, noBase, noInx, noScale);
		Push(type);
	END PushStack;
	
	PROCEDURE PopAndLoadItem(type: LONGINT; VAR it: Item);
		CONST
			Int = JavaInts+{JavaLONG, JavaREF};
			Float = {JavaFLOAT, JavaDOUBLE};
	BEGIN
		PopItem({type}, it);
		IF (type IN Int) & (it.mode # Register) OR (type IN Float) & (it.mode # FRegister) THEN LoadItem(it) END
	END PopAndLoadItem;
	
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
	
	PROCEDURE Synchronize(lock: BOOLEAN);
	BEGIN
		FlushStack;
		Pop(JavaREF);	(* consume parameter *)
		IF lock THEN SystemCall(c.fixsyscalls[JB.SCLock]) ELSE SystemCall(c.fixsyscalls[JB.SCUnlock]) END
	END Synchronize;
	
	PROCEDURE OptimizeCmp(op: SHORTINT);	(* op = intel condition code *)
		VAR
			val: LONGINT;
			
		PROCEDURE Set(op: LONGINT);
			VAR  reg: INTEGER;
		BEGIN
			reg := AllocateReg(Empty);
			JC0.GenMOV(JC0.ImmReg, reg, noBase, noInx, noScale, noDisp, 0);
			JC0.GenSetcc(SHORT(SHORT(op)), JC0.Regs, reg+AL, noInx, noScale, noDisp);
			PushRegister(JavaINT, reg, noBase)
		END Set;
		
	BEGIN
		val := Value(2);
		IF (val = 7) & CheckPattern(code.code^, trueexp, pc, map) THEN
			INC(AoptCmpT);
			Set(op);
			INC(pc, LEN(trueexp));
			WHILE (block # NIL) & (block.begin <= pc) DO block := block.next END;
		ELSIF (val = 7) & CheckPattern(code.code^, falseexp, pc, map) THEN
			INC(AoptCmpT);
			op := BIT.SXOR(op, 1);
			Set(op);
			INC(pc, LEN(falseexp));
			WHILE (block # NIL) & (block.begin <= pc) DO block := block.next END;
		ELSE
			IF ~AllRegsFree() THEN FlushStack END;
			(* CheckRegs; *)
			INC(AoptCmpF);
			Jcc(op, pc0, val, map);
		END;
	END OptimizeCmp;
	
	PROCEDURE LongCmp;
		VAR a, b: Item; reg: INTEGER; pc1, pc2, pc3, pc4, pc5: LONGINT;
	BEGIN
		PopAndLoadItem(JavaLONG, a);
		PopAndLoadItem(JavaLONG, b);
		ReleaseItem(a); ReleaseItem(b);
		reg := AllocateReg(Empty);
		
		JC0.GenTyp1(JC0.CMP, JC0.RegReg, a.base2, b.base2, noInx, noScale, noDisp, noImm);
		JC0.GenJcc(JC0.JL, 0);	(*L+*)
		pc1 := JC0.pc;
		JC0.GenJcc(JC0.JG, 0);	(*L-*)																					(* 2 Bytes *)
		pc2 := JC0.pc;
		JC0.GenTyp1(JC0.CMP, JC0.RegReg, a.base, b.base, noInx, noScale, noDisp, noImm);	(* 2 Bytes *)	
		JC0.GenJcc(JC0.JB, 0);	(*L+*)																					(* 2 Bytes *)
		pc3 := JC0.pc;
		JC0.GenJcc(JC0.JA, 0);	(*L-*)																					(* 2 Bytes *)
		pc4 := JC0.pc;

		JC0.GenTyp1(JC0.XOR, JC0.RegReg, reg, reg, noInx, noScale, noDisp, noImm);	(* 2 bytes *)
		JC0.GenJMP(JC0.Imme, noBase, noBase, noInx, noScale, 12, FALSE);					(* 2 bytes *)
(* L- *)
		JC0.PutByteAt(pc2-1, SHORT(JC0.pc-pc2));
		JC0.PutByteAt(pc4-1, SHORT(JC0.pc-pc4));
		JC0.GenMOV(JC0.ImmReg, reg, noBase, noInx, noScale, noDisp, -1);					(* 5 bytes *)
		JC0.GenJMP(JC0.Imme, noBase, noBase, noInx, noScale, 0, FALSE);						(* 2 bytes *)
		pc5 := JC0.pc;
(* L+ *)		
		JC0.PutByteAt(pc1-1, SHORT(JC0.pc-pc1));
		JC0.PutByteAt(pc3-1, SHORT(JC0.pc-pc3));
		JC0.GenMOV(JC0.ImmReg, reg, noBase, noInx, noScale, noDisp, 1);					(* 5 bytes *)
(* exit *)
		JC0.PutByteAt(pc5-1, SHORT(JC0.pc-pc5));
		PushRegister(JavaINT, reg, noBase);
	END LongCmp;
	
	PROCEDURE FloatCmp(type: LONGINT; NaNis1: BOOLEAN);
		VAR pc1, pc2, pc3, pc4, pc5: LONGINT; reg: INTEGER; swap: BOOLEAN;
	BEGIN
		reg := AllocateReg(Empty);
		PopItem({type}, ita);
		PopItem({type}, itb);
		swap := itb.mode = FRegister;
		LoadItemToST(ita);
		LoadItemToST(itb);
		IF swap THEN JC0.GenFop2(JC0.FXCH, 1) END;
		JC0.GenFop1(JC0.FCOMPP);
		JC0.GenFop1(JC0.FSTSW);																			(* store status word in ax *)
		JC0.PutByte(JC0.SAHF);																				(* set condition codes *)
		pc1 := JC0.pc;
		JC0.GenJcc(JC0.JP, 0);																					(* if unorderd *)
		pc2 := JC0.pc;
		JC0.GenJcc(JC0.JA, 0);																					(* if greater *)
		pc3 := JC0.pc;
		JC0.GenJcc(JC0.JB, 0);																				   (* if less *)
		(* else equal *)
		JC0.GenTyp1(JC0.XOR, JC0.RegReg, reg, reg, noInx, noScale, noDisp, 0);	(* result = 0 *)
		pc4 := JC0.pc;
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 0, FALSE);					(* goto end *)
		JC0.PutByteAt(pc1+1, SHORT(JC0.pc-pc1-2));

		IF NaNis1 THEN JC0.PutByteAt(pc1+1, SHORT(JC0.pc-pc2-2)) END;
		JC0.PutByteAt(pc2+1, SHORT(JC0.pc-pc2-2));
		(* greater *)
		JC0.GenMOV(JC0.ImmReg, reg, noBase, noInx, noScale, noDisp, 1);			  (* result = 1 *)
		pc5 := JC0.pc;
		JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, 0, FALSE); 				 (* goto end *)
		(* less *)
		IF ~NaNis1 THEN JC0.PutByteAt(pc1+1, SHORT(JC0.pc-pc2-2)) END;
		JC0.PutByteAt(pc3+1, SHORT(JC0.pc-pc3-2));
		JC0.GenMOV(JC0.ImmReg, reg, noBase, noInx, noScale, noDisp, -1);				(* result = -1 *)
		
		JC0.PutByteAt(pc4+1, SHORT(JC0.pc-pc4-2));
		JC0.PutByteAt(pc5+1, SHORT(JC0.pc-pc5-2));
		(* exit *)		
		PushRegister(JavaINT, reg, noBase);
	END FloatCmp;
	
	PROCEDURE CheckIndex(VAR ref, idx: Item);
		VAR pc: LONGINT;
	BEGIN
		ASSERT(ref.mode = Register);
		IF idx.mode = Register THEN
			JC0.GenTyp1(JC0.CMP, JC0.RegMem, idx.base, ref.base, noInx, noScale, ArrayDim, noImm)
		ELSE
			ASSERT(idx.mode = Immediate);
			JC0.GenTyp1(JC0.CMP, JC0.ImmMem, EAX, ref.base, noInx, noScale, ArrayDim, idx.val)
		END;
		pc := JC0.pc;
		JC0.GenJcc(JC0.JAE, 0);		
		JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, 7);
		JC0.GenINT(3);
		JC0.PutByteAt(pc+1, SHORT(JC0.pc-pc-2))
	END CheckIndex;

	PROCEDURE GetInfo(index: LONGINT; VAR cf: JB.RefClass;  VAR off: LONGINT;  VAR t: LONGINT);
		VAR ref: JB.CRefInfo; type: PCT.Struct;
	BEGIN
		ref := c.constPool[index](JB.CRefInfo);
		ASSERT(~(ref.obj IS PCT.Value));
		cf := ref.effectiveClass(JB.RefClass);
		type := ref.obj.type;
		t := OberonToJavaType(type);
		off := ref.obj.adr(PCBT.Variable).offset;
	END GetInfo;
	
	PROCEDURE Invoke(op, idx: LONGINT);
		VAR ref: JB.CRefInfo; obj: JB.Method; proc: PCT.Proc; cf: JB.Class; super: BOOLEAN; t, count: LONGINT;
		optimized: BOOLEAN; self: Item; reg: INTEGER;
	BEGIN
		ref := c.constPool[idx](JB.CRefInfo);
		cf := ref.cindex.class;
		obj := ref.ref(JB.Method);
		proc := obj.p;
		INC(Ainvoke);
		optimized := FALSE;
		count := proc.scope.parCount;
		(* if possible, move stack items to avoid copying self pointer *)
		IF (op # invokestatic) THEN
			i := 0;
			WHILE (i < count) & (stack[tos-i-1].mode # Stack) DO INC(i) END;
			IF i = count THEN
				(* if no parameter is already pushed to the stack, items can be moved *)
				INC(AoptInvoke);
				optimized := TRUE;
				self := stack[tos-count];
				FOR i := tos-count TO tos-2 DO  stack[i] := stack[i+1]  END;
				stack[tos-1] := self;
				IF (op = invokevirtual) OR (op = invokeinterface) THEN
					PopAndLoadItem(JavaREF, self);
					DEC(count);
				END
			END
		END;
		FlushStack;
		IF TraceEmit THEN
			FOR i := 0 TO proc.scope.parCount-1 DO JC.String(debugInfo, " ^"); JC.Char(debugInfo, T[stack[tos].type]) END
		END;
		DEC(tos, count);
		IF op = invokestatic THEN
			INC(AsInvoke);
			IF ref.next = NIL THEN
				IF (c # cf) & (cf.state < JB.Compiled) THEN
					WITH cf: JB.ObjectClass DO
						ASSERT(cf.fixlist # NIL); 
						ref.next := cf.fixlist; cf.fixlist := ref
					END
				ELSE
					ASSERT(c.fixlist # NIL); ref.next := c.fixlist; c.fixlist := ref
				END
			END;
			CheckInitialized(cf); (* runtime call *)
				(*call is relative and the code gets relocated -> always fix *)
			JC0.GenCALL(JC0.Imme, 0, noBase, noInx, noScale, 10000H + ref.fixup);
			ref.fixup := JC0.pc-4;
		ELSIF (op = invokevirtual) OR (op = invokespecial) THEN
			INC(AvInvoke);
			super := (op=invokespecial) & ~JT.Equal0(ref.ntindex.name.str, LEN(ref.ntindex.name.str), "<init>") & (JB.AFSuper IN c.flags) & ~(JB.AFPrivate IN obj.flags);
			IF optimized THEN
				IF super THEN	(*supercall*)
					reg := AllocateReg({self.base});
					JC0.GenMOV(JC0.ImmReg, reg, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, c.superClass.typedesc.tag));
				ELSIF op = invokespecial THEN (* <init> *)
					reg := AllocateReg({self.base});
					JC0.GenMOV(JC0.ImmReg, reg, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, cf(JB.ObjectClass).typedesc.tag))
				ELSE (* invokevirtual *)
					ASSERT(self.mode = Register);
					reg := self.base;
					JC0.GenPUSH(JC0.Regs, reg, noBase, noInx, noScale, noDisp, noImm);
					JC0.GenMOV(JC0.MemReg, reg, reg, noInx, noScale, -4, noImm);	 (*get td*)
				END;
				JC0.GenMOV(JC0.MemReg, reg, reg, noInx, noScale, JS.MethodOffset(obj.mno), noImm);	(*get mth*)
				JC0.GenCALL(JC0.Regs, reg, noBase, noInx, noScale, noDisp);
				ReleaseReg(reg)
			ELSE
				IF super THEN	(*supercall*)
					JC0.GenPUSH(JC0.Mem, EAX, ESP, noInx, noScale, obj.parsize-4, noImm);
					JC0.GenMOV(JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, c.superClass.typedesc.tag));
				ELSIF op = invokespecial THEN (* <init> *)
					JC0.GenPUSH(JC0.Mem, EAX, ESP, noInx, noScale, obj.parsize-4, noImm);
					JC0.GenMOV(JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, cf(JB.ObjectClass).typedesc.tag))
				ELSE (* invokevirtual *)
					JC0.GenMOV(JC0.MemReg, EAX, ESP, noInx, noScale, obj.parsize-4, noImm);
					JC0.GenPUSH(JC0.Regs, EAX, noBase, noInx, noScale, noDisp, noImm);
					JC0.GenMOV(JC0.MemReg, EAX, EAX, noInx, noScale, -4, noImm);	 (*get td*)
				END;
				JC0.GenMOV(JC0.MemReg, EAX, EAX, noInx, noScale, JS.MethodOffset(obj.mno), noImm);	(*get mth*)
				JC0.GenCALL(JC0.Regs, EAX, noBase, noInx, noScale, noDisp);
				JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);		(*remove objref*)
			END
		ELSE
			INC(AiInvoke);
			IF optimized THEN
				reg  := self.base;
			ELSE
				reg := AllocateReg({self.base});
				JC0.GenMOV(JC0.MemReg, reg, ESP, noInx, noScale, obj.parsize-4, noImm);
			END;
			JC0.GenPUSH(JC0.Regs, reg, noBase, noInx, noScale, noDisp, noImm);
			JC0.GenPUSH(JC0.Mem, EAX, reg, noInx, noScale, -4, noImm);
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, cf(JB.InterfaceClass).typedesc.tag));
			SystemCall(c.fixsyscalls[JB.SCILookup]);
			JC0.GenMOV(JC0.MemReg, EAX, EAX, noInx, noScale, 4+obj.p.adr(PCBT.Method).mthNo*4, noImm);
			JC0.GenCALL(JC0.Regs, EAX, noBase, noInx, noScale, noDisp);
			ReleaseReg(reg);
			IF ~optimized THEN
				JC0.GenPOP(JC0.Regs, EBX, noBase, noInx, noScale, noDisp);
			END
		END;
		CheckRegs;
		IF proc.type = PCT.NoType THEN
			(* no return type *)
		ELSE
			t := OberonToJavaType(proc.type);
			CASE t OF
			| JavaBOOL:
					AllocateThisReg(EAX, Empty, TRUE);
					JC0.GenTyp1(JC0.AND, JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, 01H);
					PushRegister(JavaINT, EAX, noBase)
			| JavaBYTE:
					AllocateThisReg(EAX, Empty, TRUE);
					JC0.GenMOVSX(JC0.RegReg, 0, EAX, AL, noInx, noScale, noDisp);
					PushRegister(JavaINT, EAX, noBase)
			| JavaSHORT:
					AllocateThisReg(EAX, Empty, TRUE);
					JC0.GenMOVSX(JC0.RegReg, 1, EAX, AX, noInx, noScale, noDisp);
					PushRegister(JavaINT, EAX, noBase)
			| JavaCHAR:
					AllocateThisReg(EAX, Empty, TRUE);
					JC0.GenTyp1(JC0.AND, JC0.ImmReg, EAX, noBase, noInx, noScale, noDisp, 0FFFFH);
					PushRegister(JavaINT, EAX, noBase)
			| JavaINT, JavaREF:
					AllocateThisReg(EAX, Empty, TRUE);
					PushRegister(t, EAX, noBase)
			| JavaLONG:
					AllocateThisReg(EAX, {EDX}, TRUE);
					AllocateThisReg(EDX, Empty, TRUE);
					PushRegister(t, EAX, EDX)
			| JavaFLOAT, JavaDOUBLE:
					PushFRegister(t)
			END
		END
	END Invoke;
	
	PROCEDURE CheckEmpty;
	BEGIN
		IF tos # 0 THEN
			JC.String(warningInfo, "  TOS # 0 "); JC.Int(warningInfo, tos, 0); JC.Ln(warningInfo);
			tos := 0
		END;
		CheckRegs;
	END CheckEmpty;
	
	(* commit change to local var, check aliasing *)
	PROCEDURE I2(type: LONGINT; op: SHORTINT);
		VAR v2, v1: Item; mode: LONGINT;
	BEGIN
		PopItem({type}, v2);
		IF v2.mode IN {Stack, FRegister} THEN LoadItem(v2) END;
		mode := v2.mode;
		ASSERT(mode IN {Register, Immediate, Local, Field, Static, Array, Constant});
		PopAndLoadItem(type, v1);
		ReleaseItem(v2);
		ASSERT(RegCount(v1.base) = 1);
		JC0.GenTyp1(op, Mode[mode], v1.base, v2.base, v2.index, v2.scale, v2.disp, v2.val);
		IF op # JC0.CMP THEN PushItem(v1) ELSE ReleaseItem(v1) END
	END I2;
	
	PROCEDURE PowerOf2(val: LONGINT;  VAR exp: LONGINT): BOOLEAN;
	BEGIN
		IF val <= 0 THEN  RETURN FALSE END;
		exp := 0;
		WHILE ~ODD(val) DO
			val := val DIV 2;
			INC(exp)
		END;
		RETURN val = 1
	END PowerOf2;
	
	PROCEDURE IMul;
		VAR v2, v1: Item; mode, exp: LONGINT;
	BEGIN
		PopItem({JavaINT}, v2);
		IF v2.mode = Stack THEN LoadItem(v2) END;
		PopAndLoadItem(JavaINT, v1);
		ReleaseItem(v2);
		mode := v2.mode;
		ASSERT(mode IN {Register, Immediate, Local, Field, Static, Array});
		ASSERT(RegCount(v1.base) = 1);
		IF mode # Immediate THEN
			JC0.GenIMUL(Mode[v2.mode], FALSE, v1.base, v2.base, v2.index, v2.scale, v2.disp, v2.val)
		ELSIF PowerOf2(v2.val, exp) THEN
			JC0.GenShiftRot(JC0.SHL, JC0.ImmReg, v1.base, noBase, noInx, noScale, noDisp, exp)
		ELSE
			JC0.GenIMUL(JC0.ImmReg, FALSE, v1.base, v1.base, noInx, noScale, noDisp, v2.val);
		END;
		PushItem(v1)
	END IMul;
	
	PROCEDURE IDivRem(op: LONGINT);
		(* res = v2 op v1 *)
		VAR v1, v2: Item; reg: INTEGER;
	BEGIN
		AllocateThisReg(EDX, {EAX}, TRUE);
		PopItem({JavaINT}, v1);
		PopItem({JavaINT}, v2);
		
		IF v1.mode IN {Immediate, Stack} THEN
			reg := AllocateReg({EAX}); ReleaseReg(reg);	(* get register, but not EAX *)
			LoadItemToReg(v1, reg)
		END;

		PushItem(v1);	(* hack: make visible to register allocation, in case EAX has to be spilled *)
		
		LoadItemToReg(v2, EAX);
		PopItem({JavaINT}, v1);
(*
		IF v1.mode IN {Immediate, Stack} THEN LoadItem(v1) END;
*)
		JC0.PutByte(JC0.CWD);	(* sign-expand EAX into EDX *)
		JC0.GenIDIV(Mode[v1.mode], v1.base, v1.base, v1.index, v1.scale, v1.disp);
		IF op = idiv THEN
			PushRegister(JavaINT, EAX, noBase);
			ReleaseReg(EDX)
		ELSE
			PushRegister(JavaINT, EDX, noBase);
			ReleaseReg(EAX)
		END;
		ReleaseItem(v1)
	END IDivRem;
	
	PROCEDURE IShift(op: SHORTINT);
		VAR value, shift: Item;
	BEGIN
		PopItem({JavaINT}, shift);	(* shift offset *)
		IF shift.mode # Immediate THEN LoadItemToReg(shift, ECX) END;
		PopAndLoadItem(JavaINT, value);	(* shift value *)
		ASSERT(shift.mode IN {Register, Immediate});
		ASSERT(RegCount(value.base) = 1);
		JC0.GenShiftRot(op, Mode[shift.mode], value.base, noBase, noInx, noScale, noDisp, shift.val);
		ReleaseItem(shift);
		PushItem(value)
	END IShift;
	
	PROCEDURE L2(opl, oph: SHORTINT);
		VAR v2, v1: Item;
	BEGIN
		PopItem({JavaLONG}, v2);
		IF v2.mode = Stack THEN LoadItem(v2) END;
		PopItem({JavaLONG}, v1);
		LoadItem(v1); ReleaseItem(v2);
		ASSERT(v2.mode IN {Register, Immediate, Local, Field, Array, Static});
		ASSERT(RegCount(v1.base) = 1);
		ASSERT(RegCount(v1.base2) = 1);
		ASSERT((v1.base # v2.base2) & (v1.base # v2.index));
		JC0.GenTyp1(opl, Mode[v2.mode], v1.base, v2.base, v2.index, v2.scale, v2.disp, v2.val);
		JC0.GenTyp1(oph, Mode[v2.mode], v1.base2, v2.base2, v2.index, v2.scale, v2.disp+4, v2.val2);
		PushRegister(JavaLONG, v1.base, v1.base2);
	END L2;
	
	PROCEDURE LMul;
		VAR v1, v2: Item;
	BEGIN
		AllocateThisReg(EAX, {EDX}, TRUE);
		AllocateThisReg(EDX, Empty, TRUE);
		
		PopItem({JavaLONG}, v1);
		PopItem({JavaLONG}, v2);
		
		IF v1.mode # Register THEN LoadItem(v1) END;
		IF v2.mode IN {FRegister, Immediate, Stack} THEN LoadItem(v2) END;
		
		JC0.GenMOV(JC0.RegReg, EAX, v1.base, noInx, noScale, noDisp, noImm);
		JC0.GenMUL(Mode[v2.mode], EAX, v2.base, v2.index, v2.scale, v2.disp);
		JC0.GenIMUL(Mode[v2.mode], FALSE, v1.base, v2.base2, v2.index, v2.scale, v2.disp+4, noImm);
		JC0.GenTyp1(JC0.ADD, JC0.RegReg, EDX, v1.base, noInx, noScale, noDisp, noImm);
		JC0.GenIMUL(Mode[v2.mode], FALSE, v1.base2, v2.base, v2.index, v2.scale, v2.disp, noImm);
		JC0.GenTyp1(JC0.ADD, JC0.RegReg, EDX, v1.base2, noInx, noScale, noDisp, noImm);
		ReleaseItem(v1);
		ReleaseItem(v2);
		PushRegister(JavaLONG, EAX, EDX);
	END LMul;
	
	PROCEDURE LShift(op: LONGINT);
		VAR value, shift: Item; pc1, pc2, pc3, pc4: LONGINT;
	BEGIN
		PopItem({JavaINT}, shift);	(* shift offset *)
		(*IF shift.mode # Immediate THEN*) LoadItemToReg(shift, ECX) (*END*);
		PopAndLoadItem(JavaLONG, value);	(* shift value *)
		ASSERT(RegCount(value.base) = 1);
		ASSERT(RegCount(value.base2) = 1);
		JC0.GenTyp1(JC0.CMP, JC0.ImmReg, ECX, noBase, noInx, noScale, noDisp, 32);
		JC0.GenJcc(JC0.JB, 0);
		pc1 := JC0.pc;
		JC0.GenTyp1(JC0.CMP, JC0.ImmReg, ECX, noBase, noInx, noScale, noDisp, 64);
		JC0.GenJcc(JC0.JB, 0);
		pc2 := JC0.pc;
		IF op = lshl THEN
				(* shift >= 64 *)
			JC0.GenTyp1(JC0.XOR, JC0.RegReg, value.base, value.base, noInx, noScale, noDisp, noImm);
			JC0.GenTyp1(JC0.XOR, JC0.RegReg, value.base2, value.base2, noInx, noScale, noDisp, noImm);
			JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, val, FALSE);
			pc3 := JC0.pc;
				(* shift >= 32 *)
			JC0.PutByteAt(pc2-1, SHORT(JC0.pc - pc2));
			JC0.GenTyp1(JC0.AND, JC0.ImmReg, shift.base, noBase, noInx, noScale, noDisp, 01FH);
			JC0.GenMOV(JC0.RegReg, value.base2, value.base, noInx, noScale, noDisp, noImm);
			JC0.GenShiftRot(JC0.SAL, Mode[shift.mode], value.base2, shift.base, noInx, noScale, noDisp, shift.val);
			JC0.GenTyp1(JC0.XOR, JC0.RegReg, value.base, value.base, noInx, noScale, noDisp, noImm);
			JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, val, FALSE);
			pc4 := JC0.pc;
				(* shift < 32 *)
			JC0.PutByteAt(pc1-1, SHORT(JC0.pc - pc1));
			JC0.GenSHDouble(JC0.Left, JC0.RegReg, shift.mode = Register, value.base, value.base2, noInx, noScale, noDisp, shift.val);
			JC0.GenShiftRot(JC0.SAL, Mode[shift.mode], value.base, shift.base, noInx, noScale, noDisp, shift.val);
		ELSIF op = lshr THEN
				(* shift >= 64 *)
			JC0.GenShiftRot(JC0.SAR, JC0.ImmReg, value.base2, noBase, noInx, noScale, noDisp, 31);
			JC0.GenMOV(JC0.RegReg, value.base, value.base2, noInx, noScale, noDisp, noImm);
			JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, val, FALSE);
			pc3 := JC0.pc;
				(* shift >= 32 *)
			JC0.PutByteAt(pc2-1, SHORT(JC0.pc - pc2));
			JC0.GenTyp1(JC0.AND, JC0.ImmReg, shift.base, noBase, noInx, noScale, noDisp, 01FH);
			JC0.GenMOV(JC0.RegReg, value.base, value.base2, noInx, noScale, noDisp, noImm);
			JC0.GenShiftRot(JC0.SAR, JC0.ImmReg, value.base2, noBase, noInx, noScale, noDisp, 31);
			JC0.GenShiftRot(JC0.SAR, Mode[shift.mode], value.base, noBase, noInx, noScale, noDisp, shift.val);
			JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, val, FALSE);
			pc4 := JC0.pc;
				(* shift < 32 *)
			JC0.PutByteAt(pc1-1, SHORT(JC0.pc - pc1));
			JC0.GenSHDouble(JC0.Right, JC0.RegReg, shift.mode = Register, value.base2, value.base, noInx, noScale, noDisp, shift.val);
			JC0.GenShiftRot(JC0.SAR, Mode[shift.mode], value.base2, noBase, noInx, noScale, noDisp, shift.val)
		ELSIF op = lushr THEN
				(* shift >= 64 *)
			JC0.GenTyp1(JC0.XOR, JC0.RegReg, value.base, value.base, noInx, noScale, noDisp, noImm);
			JC0.GenTyp1(JC0.XOR, JC0.RegReg, value.base2, value.base2, noInx, noScale, noDisp, noImm);
			JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, val, FALSE);
			pc3 := JC0.pc;
				(* shift >= 32 *)
			JC0.PutByteAt(pc2-1, SHORT(JC0.pc - pc2));
			JC0.GenTyp1(JC0.AND, JC0.ImmReg, shift.base, noBase, noInx, noScale, noDisp, 01FH);
			JC0.GenMOV(JC0.RegReg, value.base, value.base2, noInx, noScale, noDisp, noImm);
			JC0.GenShiftRot(JC0.SHR, Mode[shift.mode], value.base, shift.base, noInx, noScale, noDisp, shift.val);
			JC0.GenTyp1(JC0.XOR, JC0.RegReg, value.base2, value.base2, noInx, noScale, noDisp, noImm);
			JC0.GenJMP(JC0.Imme, 0, noBase, noInx, noScale, val, FALSE);
			pc4 := JC0.pc;
				(* shift < 32 *)
			JC0.PutByteAt(pc1-1, SHORT(JC0.pc - pc1));
			JC0.GenSHDouble(JC0.Right, JC0.RegReg, shift.mode = Register, value.base2, value.base, noInx, noScale, noDisp, shift.val);
			JC0.GenShiftRot(JC0.SHR, Mode[shift.mode], value.base2, shift.base, noInx, noScale, noDisp, shift.val)
		ELSE
			HALT(99)
		END;
		JC0.PutByteAt(pc3-1, SHORT(JC0.pc - pc3));
		JC0.PutByteAt(pc4-1, SHORT(JC0.pc - pc4));
		ReleaseItem(shift);
		PushItem(value)
	END LShift;
	
	PROCEDURE F2(type: LONGINT; op: LONGINT);
		VAR a, b: Item; size: SHORTINT; bsize, Sp: LONGINT; reversed: BOOLEAN; dir: LONGINT;
	BEGIN
		reversed := FALSE;
		size := FSize[type];
		bsize := Size[type];
		PopItem({type}, a);
		PopItem({type}, b);
		
		Sp := 0;
		IF a.mode = Stack THEN INC(Sp, bsize) END;
		IF b.mode = Stack THEN
			reversed := a.mode = FRegister;
			JC0.GenFLD(JC0.Mem, size, ESP, noInx, noScale, Sp);
			INC(Sp, bsize)
		ELSIF b.mode # FRegister THEN
			reversed := a.mode = FRegister;
			LoadItemToST(b)
		END;
		
		IF reversed THEN dir := 1 ELSE dir := 0 END;
		IF dir = 1 THEN
			JC.String(debugInfo, "Reversed op"); JC.Ln(debugInfo)
		END;
		
		IF (a.mode = Stack) & (a.type = JavaLONG) THEN	(* LoadItemtoST increments the SP pointer, avoid it!*)
			JC0.GenFLD(JC0.Mem, FSize[JavaLONG], ESP, noInx, noScale, 0);
			a.mode := FRegister;
		ELSIF (a.mode IN {Register, Immediate}) OR (a.type = JavaLONG) THEN LoadItemToST(a)
		END;
		IF a.mode = FRegister THEN 
			FTyp1Op[op, dir](JC0.StRegP, size, 1, noInx, noScale, noDisp)
		ELSIF a.mode = Stack THEN
			FTyp1Op[op, dir](JC0.MemSt, size, ESP, noInx, noScale, 0)
		ELSE
			FTyp1Op[op, dir](JC0.MemSt, size, a.base, a.index, a.scale, a.disp)
		END;
		ReleaseItem(a);
		IF Sp # 0 THEN
			JC0.GenTyp1(JC0.ADD, JC0.ImmReg, ESP, noBase, noInx, noScale, noDisp, Sp)
		END;
		
		PushFRegister(type);
	END F2;
	
	PROCEDURE F2Rem(type: LONGINT);
		VAR v1, v2: Item; swap: BOOLEAN;
	BEGIN
		PopItem({type}, v2);
		PopItem({type}, v1);
		swap := (v1.mode = FRegister) & (v2.mode # FRegister);
		LoadItemToST(v2);
		LoadItemToST(v1);
		IF swap THEN JC0.GenFop2(JC0.FXCH, 1) END;
		ASSERT(v1.mode = FRegister);
		ASSERT(v2.mode = FRegister);
		IF v1.type IN JavaInts+{JavaLONG} THEN
			JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, JS.RCHOP);
			JC0.GenFLDCW(ESP, noInx, noScale, noDisp);
			JC0.GenTyp1(JC0.ADD, JC0.ImmReg, ESP, noBase, noInx, noScale, noDisp, 4)
		END;
		JC0.GenFop1(JC0.FPREM);
		IF v1.type IN JavaInts+{JavaLONG} THEN
			JC0.GenFLDCW(noBase, noInx, noScale, SYSTEM.ADR(AosBoot.fcr));
		END;
		JC0.PutByte(0DDH); JC0.PutByte(0D9H);	(* FSTP ST(1) *)
		PushFRegister(type);
	END F2Rem;
	
BEGIN
	ResetRegs;
	(*tos := 0;*)
	ASSERT(tos = 0);
	
	IF (map = NIL) OR (LEN(map^) < LEN(code.code^)+1) THEN
		NEW(map, LEN(code.code^)+1)
	END;
	FOR i := 0 TO LEN(map^)-1 DO  map[i] := 0  END;
	
	JC0.GenPUSH(JC0.Regs, EBP, noBase, noInx, noScale, noDisp, noImm);
	JC0.GenMOV(JC0.RegReg, EBP, ESP, noInx, noScale, noDisp, noImm);
	IF nofLocals # 0 THEN
		JC0.GenTyp1(JC0.SUB, JC0.ImmReg, ESP, noBase, noInx, noScale, noDisp, nofLocals*4)
	END;
	
	IF TraceMethods THEN
		SystemCall(c.fixsyscalls[JB.SCTrace])
	END;
	
	IF JB.AFSynchronized IN m.flags THEN
		IF JB.AFStatic IN m.flags THEN
			PushImmediate(JavaREF, SYSTEM.VAL(LONGINT, c))
		ELSE
			PushLocal(JavaREF, 0)
		END;
		Synchronize(TRUE)
	END;
	
	dead := FALSE;
	ASSERT(block.begin = 0);

	WHILE block # NIL DO	
		pc := block.begin;
		IF block.mode * {Sub, Catch} # {} THEN
			tos := 0; PushStack(JavaREF);
			ASSERT(block.tos = 1)
		ELSE
			tos := block.tos
		END;
		
		FOR i := 0 TO tos-1 DO
			ASSERT(stack[i].type = block.stack[i].type);
		END;
		j := LEN(block.mustPush)-1;
		WHILE (j >= 0) & ~block.mustPush[j] DO DEC(j) END;
		IF j # -1 THEN
(*
			JC.String("Block at "); JC.Int(pc, 0); JC.String("  must push from 0 to "); JC.Int(j, 0); JC.Ln;
*)
			FOR i :=  0 TO j-1 DO block.mustPush[i] := TRUE END;
		END;
		WHILE pc # block.end DO
			IF TraceEmit OR TraceLines THEN JC.Char(debugInfo, 9X); JC.Int(debugInfo, pc, 0) END;
			FixupFwdJmps(map[pc]);
			map[pc] := JC0.pc;
			pc0 := pc;
			op := ORD(code.code[pc]);
			IF TraceEmit OR TraceLines THEN JC.Char(debugInfo, 9X); JC.Int(debugInfo, op, 0) END;
			INC(Aopcodes[op]);
			INC(pc);
			CASE op OF
			| nop:
			| aconstnull:
					PushImmediate(JavaREF, 0)
			| iconstm1 .. iconst5:
					PushImmediate(JavaINT, op - iconst0)
			| lconst0 .. lconst1:
					PushImmediate2(JavaLONG, op - lconst0)
			| fconst0 .. fconst2:
					PushImmediate(JavaFLOAT, fconst[op-fconst0])
			| dconst0 .. dconst1:
					PushImmediate2(JavaDOUBLE, dconst[op-dconst0])
			| bipush:
					val := Value(1);
					PushImmediate(JavaINT, val)
			| sipush:
					val := Value(2);
					PushImmediate(JavaINT, val)
			| ldc, ldcw, ldc2w:
					idx := Index(op # ldc);	(* ldc -> 1, ldcw/ldc2w -> 2 *)
					tag := c.constPool[idx].tag;
					con := c.constPool[idx](JB.CConstInfo).c;
					CASE tag OF
					|  JB.CInteger:  PushImmediate(JavaINT, con.int)
					|  JB.CFloat:  PushImmediate(JavaFLOAT, SYSTEM.VAL(LONGINT, SHORT(con.real)))
					|  JB.CString:  PushImmediate(JavaREF, SYSTEM.VAL(LONGINT, con.ptr))
					|  JB.CLong:  PushImmediate2(JavaLONG, con.long)
					|  JB.CDouble:  PushImmediate2(JavaDOUBLE, SYSTEM.VAL(HUGEINT, con.real))
					END
			| iload .. aload:
					idx := Index(Wide); Wide := FALSE;
					t := op-iload;
					IF t IN {JavaLONG, JavaDOUBLE} THEN INC(idx) END;	(* get to the LSB *)
					PushLocal(t, idx)
			| iload0 .. iload3, lload0 .. lload3, fload0 .. fload3, dload0 .. dload3, aload0 .. aload3:
					t := (op - iload0) DIV 4;
					val := (op - iload0) MOD 4;
					IF t IN {JavaLONG, JavaDOUBLE} THEN INC(val) END;	(* get to the LSB *)
					PushLocal(t, val)
			| iaload .. saload:
					t := op - iaload;
					PopItem({JavaINT}, itb);
					PopItem({JavaREF}, ita);
					IF ~(itb.mode IN {Register, Immediate}) THEN LoadItem(itb) END;
					LoadItem(ita);
					ASSERT(RegCount(ita.base) = 1);
					JC0.GenMOV(JC0.MemReg, ita.base, ita.base, noInx, noScale, ArrayPtrOffset, noImm);	(* defer obj.p *)
					
					CheckIndex(ita, itb);
					
					PushArray(t, ita.base, itb.base, itb.val);
			| istore .. astore:
					idx := Index(Wide); Wide := FALSE;
					val := op - istore;	(* type *)
					IF val IN {JavaLONG, JavaDOUBLE} THEN INC(idx) END;	(* get to the LSB *)
	(*
					CheckStack(idx);
	*)
					PopItem({val}, it);
					StoreItem(val, EBP, noInx, noScale, FpOffset(idx), it);
			| istore0 .. istore3, lstore0 .. lstore3, fstore0 .. fstore3, dstore0 .. dstore3, astore0 .. astore3:
					idx := (op - istore0) MOD 4;
					val := (op - istore0) DIV 4;
					IF val IN {JavaLONG, JavaDOUBLE} THEN INC(idx) END;	(* get to the LSB *)
	(*
					CheckStack(idx);
	*)
					PopItem({val}, it);
					StoreItem(val, EBP, noInx, noScale, FpOffset(idx), it);
			| iastore .. sastore:
					t := op - iastore;
					IF t IN JavaShorts THEN PopItem({JavaINT}, itc) ELSE PopItem({t}, itc) END;
	(*
					IF t IN JavaShorts THEN t := JavaINT END;
					PopItem({t}, itc);
	*)
					PopItem({JavaINT}, itb);
					PopItem({JavaREF}, ita);
					IF itc.mode = Stack THEN LoadItem(itc) END;
					IF ~(itb.mode IN {Register, Immediate}) THEN LoadItem(itb) END;
					LoadItem(ita);
					ASSERT(RegCount(ita.base) = 1);
					JC0.GenMOV(JC0.MemReg, ita.base, ita.base, noInx, noScale, ArrayPtrOffset, noImm);	(* defer obj.p *)
					
					CheckIndex(ita, itb);
					StoreItem(t, ita.base, itb.base, Scale[t], FirstArrayElem+Size[op -iastore]*itb.val, itc);
			| pop:
					PopItem(Java1, it);
					IF it.mode = Stack THEN
						JC0.GenTyp1(JC0.ADD, JC0.ImmReg, ESP, noBase, noInx, noScale, noDisp, 4)
					ELSIF it.mode = FRegister THEN
						JC0.GenFop2(JC0.FFREE, 0);
						JC0.GenFop1(JC0.FINCSTP);
					END;
					ReleaseItem(it)
			| pop2:
					PopItem(Java2, it);
					IF it.mode = Stack THEN
						JC0.GenTyp1(JC0.ADD, JC0.ImmReg, ESP, noBase, noInx, noScale, noDisp, 8)
					ELSIF it.mode = FRegister THEN
						JC0.GenFop2(JC0.FFREE, 0);
						JC0.GenFop1(JC0.FINCSTP);
					END;
					ReleaseItem(it)
			| dupx1:
					PopItem(Java1, it); PopItem(Java1, itb);
					IF it.mode = Stack THEN LoadItem(it) END;
					IF itb.mode = Stack THEN LoadItem(itb) END;
					IF (it.mode = FRegister) & (itb.mode = FRegister) THEN 
						JC0.PutByte(0D9H); JC0.PutByte(0C9H);	(* FXCH ST(1) *)
						JC0.PutByte(0D9H); JC0.PutByte(0C1H);	(* FLD ST(1) *)
						ita := it;
					ELSIF (it.mode = FRegister) THEN
						JC0.PutByte(0D9H); JC0.PutByte(0C0H);	(* FLD ST(0) *)
						ita := it;
					ELSIF (itb.mode = FRegister) THEN
						DuplicateItem(it, ita);
					ELSE
						DuplicateItem(it, ita);
					END;
					PushItem(it); PushItem(itb); PushItem(ita)
			| dupx2:
					PopItem(Java1, it); PopItem(Java1, itb); PopItem(Java1, itc);
					IF it.mode = Stack THEN LoadItem(it) END;
					IF itb.mode = Stack THEN LoadItem(itb) END;
					IF itc.mode = Stack THEN LoadItem(itc) END;
					ASSERT(it.mode # FRegister);
					ASSERT(itb.mode # FRegister);
					ASSERT(itc.mode # FRegister);
					DuplicateItem(it, ita);
					PushItem(it); PushItem(itc); PushItem(itb); PushItem(ita)
			| dup, dup2:
					PopItem(Java1+Java2, v1);
					ASSERT((v1.type IN Java1) OR (op # dup));	(* check: dup => t in Java1 *)
					IF (op = dup) OR (v1.type IN Java2) THEN
						IF v1.mode = Stack THEN LoadItem(v1) END;
						DuplicateItem(v1, v1c);
						PushItem(v1);
						PushItem(v1c)
					ELSE
						IF v1.mode = Stack THEN LoadItem(v1) END;
						PopItem(Java1, v2);
						IF v2.mode = Stack THEN LoadItem(v2) END;
						IF (v1.mode = FRegister) & (v2.mode = FRegister) THEN
							JC0.GenFLD(JC0.Regs, FSize[v1.type], 1, noInx, noScale, noDisp);	(* FLD ST(1) *)
							JC0.GenFLD(JC0.Regs, FSize[v2.type], 1, noInx, noScale, noDisp);	(* FLD ST(1) *)
							PushItem(v2); PushItem(v1);
							PushItem(v2); PushItem(v1);
						ELSE
							DuplicateItem(v1, v1c);
							DuplicateItem(v2, v2c);
							PushItem(v2); PushItem(v1);
							PushItem(v2c); PushItem(v1c);
						END
					END;
			| dup2x1:
					PopItem(Java2, v1);
					(* ..., v2, v1 => ..., v1, v2, v1 *)
					PopItem(Java1, v2);
					IF v1.mode = Stack THEN LoadItem(v1) END;
					IF v2.mode = Stack THEN LoadItem(v2) END;
					IF (it.mode = FRegister) & (itb.mode = FRegister) THEN
							(* ..., v2, v1 *)
						JC0.PutByte(0D9H); JC0.PutByte(0C9H);	(* FXCH ST(1) *)
							(* ..., v1, v2 *)
						JC0.PutByte(0D9H); JC0.PutByte(0C1H);	(* FLD ST(1) *)
							(* ..., v1, v2, v1 *)
						v1c := v1;
					ELSIF (v1.mode = FRegister) THEN
						JC0.PutByte(0D9H); JC0.PutByte(0C0H);	(* FLD ST(0) *)
						v1c := v1;
					ELSIF (itb.mode = FRegister) THEN
						DuplicateItem(v1, v1c);
					ELSE
						DuplicateItem(v1, v1c);
					END;
					PushItem(v1); PushItem(v2); PushItem(v1c)
				
			| dup2x2:
					PopItem(Java2, it); PopItem(Java1, itb); PopItem(Java1, itc);
					IF it.mode = Stack THEN LoadItem(it) END;
					IF itb.mode = Stack THEN LoadItem(itb) END;
					IF itc.mode = Stack THEN LoadItem(itc) END;
					ASSERT(it.mode # FRegister);
					ASSERT(itb.mode # FRegister);
					ASSERT(itc.mode # FRegister);
					DuplicateItem(it, ita);
					PushItem(it); PushItem(itc); PushItem(itb); PushItem(ita)
			| swap:
					PopItem(Java1, ita); PopItem(Java1, itb);
					IF ita.mode = Stack THEN LoadItem(ita) END;
					IF itb.mode = Stack THEN LoadItem(itb) END;
					ASSERT(it.mode # FRegister);
					ASSERT(itb.mode # FRegister);
					PushItem(ita); PushItem(itb)
			| iadd:
					I2(JavaINT, JC0.ADD)
			| isub:
					I2(JavaINT, JC0.SUB)
			| ladd:
					L2(JC0.ADD, JC0.ADC)
			| lsub:
					L2(JC0.SUB, JC0.SBB)
			| ldiv, fadd .. dadd, fsub .. dsub, fmul .. dmul, fdiv .. ddiv:
					t := (op - iadd) MOD 4;
					u := (op - iadd) DIV 4;
					F2(t, u)
			| lrem .. drem:	(*LONG/FLOAT/DOUBLE*)
					t := (op - iadd) MOD 4;
					F2Rem(t);
			| imul:
					IMul;
			| idiv, irem: 
					IDivRem(op)
			| lmul:
					LMul
			| ineg .. dneg:
					t := (op - ineg);
					PopAndLoadItem(t, it);
					IF op = ineg THEN
						ASSERT(RegCount(it.base) = 1);
						JC0.GenNEG(JC0.Regs, it.base, noBase, noInx, noScale, noDisp);
						PushRegister(t, it.base, noBase)
					ELSIF op = lneg THEN
						ASSERT(RegCount(it.base) = 1);
						ASSERT(RegCount(it.base2) = 1);
						ASSERT(it.base # it.base2);
						JC0.GenNEG(JC0.Regs, it.base, noBase, noInx, noScale, noDisp);
						JC0.GenTyp1(JC0.ADC, JC0.ImmReg, it.base2, noBase, noInx, noScale, noDisp, 0);
						JC0.GenNEG(JC0.Regs, it.base2, noBase, noInx, noScale, noDisp);
						PushRegister(t, it.base, it.base2)
					ELSE
						JC0.GenFop1(JC0.FCHS);
						PushFRegister(t)
					END
			| ishl:
					IShift(JC0.SAL)
			| ishr:
					IShift(JC0.SAR)
			| iushr:
					IShift(JC0.SHR)
			| lshl, lshr, lushr:
					LShift(op)
			| iand:
					I2(JavaINT, JC0.AND)
			| ior:
					I2(JavaINT, JC0.Or)
			| ixor:
					I2(JavaINT, JC0.XOR)
			| land:
					L2(JC0.AND, JC0.AND)
			| lor:
					L2(JC0.Or, JC0.Or)
			| lxor:
					L2(JC0.XOR, JC0.XOR)
			| iinc:
					idx := Index(Wide);
					IF Wide THEN Wide := FALSE; val := Value(2) ELSE val := Value(1) END;
	(*
					CheckStack(idx);
	*)
					CheckStack(FpOffset(idx), TRUE);
					IF val = 1 THEN
						JC0.GenINC(JC0.Mem, EAX, EBP, noInx, noScale, FpOffset(idx))
					ELSIF val = -1 THEN
						JC0.GenDEC(JC0.Mem, EAX, EBP, noInx, noScale, FpOffset(idx))
					ELSE
						JC0.GenTyp1(JC0.ADD, JC0.ImmMem, EAX, EBP, noInx, noScale, FpOffset(idx), val)
					END
			| i2f, i2d, l2f, l2d:
					t := (op - i2l) DIV 3;
					s := (op - i2l) MOD 3 + JavaLONG;
					PopItem({t}, it);
					LoadItemToST(it);
					PushFRegister(s);
			| f2i, d2i, f2l, d2l:
					t := (op - f2i) DIV 3 + JavaFLOAT;
					s := (op - f2i) MOD 3 + JavaINT;
					PopItem({t}, it);
					LoadItemToST(it);
					it.type := SHORT(SHORT(s));
	(*
					GenPushItem(it);
	*)
					PushItem(it)
			| l2i:
					PopItem({JavaLONG}, it);
					IF it.mode = Stack THEN LoadItem(it) END;
					IF it.mode = Register THEN
						ReleaseReg(it.base2); it.base2 := noBase
					ELSE
						ASSERT(it.mode IN Memory+{FRegister});
						(* SHORT of a LONG has the same address on little-endian CPU (is the LSB) *)
					END;
					it.type := JavaINT;
					PushItem(it)
			| i2l:
					PopAndLoadItem(JavaINT, it);
					IF (it.base = EAX) & (RegCount(EDX) = Free) THEN
						AllocateThisReg(EDX, Empty, TRUE);
						JC0.PutByte(JC0.CWD);
						it.base2 := EDX
					ELSE
						(*
							CMP reg, 0
							XOR reg2, reg2
							SETGE reg2	(* reg2 = 1 <==> reg >= 0 *)
							DEC reg2
						*)
						it.base2 := AllocateReg(Empty);
						JC0.GenTyp1(JC0.XOR, JC0.RegReg, it.base2, it.base2, noInx, noScale, noDisp, noImm);
						JC0.GenTyp1(JC0.CMP, JC0.ImmReg, it.base, noBase, noInx, noScale, noDisp, 0);
						JC0.GenSetcc(JC0.JGE, JC0.Regs, it.base2, noInx, noScale, noDisp);
						JC0.GenDEC(JC0.ImmReg, it.base2, noBase, noInx, noScale, noDisp)
					END;
					it.type := JavaLONG;
					PushItem(it);
			| d2f:
					PopAndLoadItem(JavaDOUBLE, it);
					it.type := JavaFLOAT;
					PushItem(it)
			| f2d:
					PopAndLoadItem(JavaFLOAT, it);
					it.type := JavaDOUBLE;
					PushItem(it)
			| i2b, i2c, i2s:
					PopAndLoadItem(JavaINT, it);
					ASSERT(RegCount(it.base) = 1);
					IF op = i2b THEN
						JC0.GenMOVSX(JC0.RegReg, 0, it.base, it.base+AL, noInx, noScale, noDisp)
					ELSIF op = i2c THEN
						JC0.GenTyp1(JC0.AND, JC0.ImmReg, it.base, noBase, noInx, noScale, noDisp, 0FFFFH)
					ELSIF op = i2s THEN
						JC0.GenMOVSX(JC0.RegReg, 1, it.base, it.base+AX, noInx, noScale, noDisp)
					END;
					PushItem(it)
			| lcmp:
					LongCmp;
			| fcmpl, fcmpg:
					FloatCmp(JavaFLOAT, op = fcmpg)
			| dcmpl, dcmpg:
					FloatCmp(JavaDOUBLE, op = dcmpg)
			| ifeq .. ifle:	(* jump *)
					PushImmediate(JavaINT, 0);
					I2(JavaINT, JC0.CMP);
					IF OptimizeBooleanExp THEN
						OptimizeCmp(jcc[op - ifeq])
					ELSE
						val := Value(2);
						Jcc(jcc[op - ifeq], pc0, val, map);
						IF DoCheckRegs THEN CheckRegs END;
					END;
			| ificmpeq .. ificmple:	(* jump *)
					I2(JavaINT, JC0.CMP);
					IF OptimizeBooleanExp THEN
						OptimizeCmp(jcc[op - ificmpeq])
					ELSE
						val := Value(2);
						Jcc(jcc[op - ificmpeq], pc0, val, map);
						IF ~AllRegsFree() THEN
							DumpStack(debugInfo);
						END;
						IF DoCheckRegs THEN CheckRegs END;
					END;
			| ifacmpeq .. ifacmpne:	(* jump *)
					I2(JavaREF, JC0.CMP);
					IF OptimizeBooleanExp THEN
						OptimizeCmp(jcc[op - ifacmpeq])
					ELSE
						val := Value(2);
						Jcc(jcc[op - ifacmpeq], pc0, val, map);
						IF DoCheckRegs THEN CheckRegs END;
					END;
			| goto:	(* jump *)
					val := Value(2);
					Jcc(JMP, pc0, val, map);
					dead := TRUE;
			| jsr:	(* jump *)
					CheckEmpty;
					val := Value(2);
					Jcc(CALL, pc0, val, map);
					(* pushes address on stack! *)
			| ret:
					idx := Index(Wide); Wide := FALSE;
					JC0.GenJMP(JC0.Mem, JC0.Bit32, EBP, noInx, noScale, FpOffset(idx), FALSE);
	(*
					JC0.GenPUSH(JC0.Mem, 0, EBP, noInx, noScale, FpOffset(idx), noImm);
					JC0.GenRET(0);
	*)
					CheckEmpty;
					dead := TRUE;
			| tableswitch:
					INC(pc, (-pc) MOD 4);
					off := Value(4);	(* default *)
					low := Value(4);	(* low *)
					high := Value(4);	(* high *)
					PopAndLoadItem(JavaINT, it);
					JC0.GenTyp1(JC0.SUB, JC0.ImmReg, it.base, noBase, noInx, noScale, noDisp, low);             (* index into jump table *)
					JC0.GenTyp1(JC0.CMP, JC0.ImmReg, it.base, noBase, noInx, noScale, noDisp, high-low); 	(* compare to high *)		
					Jcc(JC0.JNBE, pc0, off, map);
					pc3 := JC0.pc;
					reg1 := AllocateReg(Empty);
					JC0.GenCALL(JC0.Imme, 0, noBase, noInx, noScale, 0);												(* get the current pc *)
					JC0.GenPOP(JC0.Regs, reg1, noBase, noInx, noScale, noDisp);	
					JC0.GenIMUL(JC0.ImmReg, FALSE, it.base, it.base, noInx, noScale, noDisp, 5);
					JC0.GenLEA(it.base, it.base, reg1, noScale, JC0.pc-pc3+1);
					
					JC0.GenJMP(JC0.Regs, it.base, noBase, noInx, noScale, noDisp, FALSE);	(* now jump into the table *)
					count := high - low + 1;
					WHILE count > 0 DO
						off := Value(4); 												(* table consist of a sequence of jmp instructions *)			
						Jcc(JMP, pc0, off, map);
						DEC(count) 
					END;
					ReleaseReg(reg1);
					ReleaseItem(it);
					CheckEmpty;
					dead := TRUE;
			| lookupswitch:
					INC(pc, (-pc) MOD 4);
					PopAndLoadItem(JavaINT, it);
					idx := Value(4);
					count := Value(4);
					FOR i := 0 TO count-1 DO
						val := Value(4);	(* key *)
						off := Value(4);	(* label *)
						JC0.GenTyp1(JC0.CMP, JC0.ImmReg, it.base, noBase, noInx, noScale, noDisp, val);
						Jcc(JC0.JE, pc0, off, map)
					END;
					Jcc(JMP, pc0, idx, map);
					ReleaseItem(it);
					CheckEmpty;
					CheckRegs;
					dead := TRUE;
			| ireturn .. areturn, return:
					IF JB.AFSynchronized IN m.flags THEN
						IF JB.AFStatic IN m.flags THEN
							PushImmediate(JavaREF, SYSTEM.VAL(LONGINT, c))
						ELSE
							PushLocal(JavaREF, 0)
						END;
						Synchronize(FALSE)
					END;
					IF op # return THEN 
						s := op - ireturn;
						PopItem({s}, it);
						IF s IN {JavaINT, JavaREF} THEN
							LoadItemToReg(it, EAX)
						ELSIF s IN {JavaFLOAT, JavaDOUBLE} THEN
							LoadItemToST(it)
						ELSIF s = JavaLONG THEN
							LoadItemToReg2(it, EAX, EDX)
						ELSE
							HALT(99)
						END;
						ReleaseItem(it);
					END;
					JC0.GenMOV(JC0.RegReg, ESP, EBP, noInx, noScale, noDisp, noImm);
					JC0.GenPOP(JC0.Regs, EBP, noBase, noInx, noScale, noDisp);
					JC0.GenRET(nofParams*4);
					CheckEmpty;
					dead := TRUE;
			| getstatic:
					idx := Index(TRUE);
					GetInfo(idx, cf, off, t);
					CheckInitialized(cf);
					PushStatic(t, cf.ownModule.sb+off)
			| putstatic:
					idx := Index(TRUE);
					GetInfo(idx, cf, off, t);
					IF t IN JavaShorts THEN s := JavaINT ELSE s := t END;
					CheckInitialized(cf);
					PopItem({s}, it);
					StoreItem(t, noBase, noInx, noScale, cf.ownModule.sb+off, it)
			| getfield:
					idx := Index(TRUE);
					GetInfo(idx, cf, off, t);
					PopAndLoadItem(JavaREF, it);
					PushField(t, it.base, off)
			| putfield:
					idx := Index(TRUE);
					GetInfo(idx, cf, off, t);
					IF t IN JavaShorts THEN s := JavaINT ELSE s := t END;
					PopItem({s}, it);
					IF (it.mode = Stack) & (stack[tos-1].mode = Stack) THEN LoadItem(it) END;
					PopAndLoadItem(JavaREF, ita);
					StoreItem(t, ita.base, noInx, noScale, off, it);
			| invokevirtual, invokespecial, invokestatic:
					idx := Index(TRUE);
					Invoke(op, idx)
			| invokeinterface:
					idx := Index(TRUE);
					INC(pc, 2);	(*skip count, 0 *)
					Invoke(op, idx)
			| newarray:
					FlushStack;
					PopItem({JavaINT}, it);	(* consume count from virtual stack *)
					idx := Index(FALSE);
					JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, idx);
					SystemCall(c.fixsyscalls[JB.SCNewArray]);
					AllocateThisReg(EAX, Empty, TRUE);
					PushRegister(JavaREF, EAX, noBase);
			| new, anewarray, multianewarray:
					FlushStack;
					idx := Index(TRUE);
					IF op = new THEN
						JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, GetClass(c.constPool[idx])));
						SystemCall(c.fixsyscalls[JB.SCNew])
					ELSIF op = anewarray THEN
						PopItem({JavaINT}, it);	(* consume count from virtual stack *)
						JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, GetClass(c.constPool[idx])));
						SystemCall(c.fixsyscalls[JB.SCNewArrayA])
					ELSE (* multianewarray *)
						val := Index(FALSE);	(* n *)
						JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, GetClass(c.constPool[idx])));
						JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, val);
						SystemCall(c.fixsyscalls[JB.SCMultianewArray]);
						JC0.GenTyp1(JC0.ADD, JC0.ImmReg, ESP, 0, noInx, noScale, noDisp, val*4);
						WHILE val > 0 DO
							Pop(JavaINT); DEC(val)		(* remove count from virtual stack *)
						END
					END;
					AllocateThisReg(EAX, Empty, TRUE);
					PushRegister(JavaREF, EAX, noBase);
			| arraylength:
					PopAndLoadItem(JavaREF, it);
					ASSERT(RegCount(it.base) = 1);
					JC0.GenMOV(JC0.MemReg, it.base, it.base, noInx, noScale, ArrayPtrOffset, noImm);
					PushArray(JavaINT, it.base, noInx, -1);	(* array dim is 1 pos before first elem *)
			| athrow:
					PopItem({JavaREF}, it);
					IF it.mode # Stack THEN GenPushItem(it) END;
					SystemCall(c.fixsyscalls[JB.SCThrow]);
					CheckRegs;
	(*
					CheckEmpty;
	*)
					dead := TRUE;
			| checkcast:
					FlushStack;
					ASSERT(stack[tos-1].type = JavaREF);
					idx := Index(TRUE);
					JC0.GenPUSH(JC0.Mem, EAX, ESP, noInx, noScale, 0, noImm);	(* copy of tos *)
					JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, GetClass(c.constPool[idx])));
					SystemCall(c.fixsyscalls[JB.SCInstanceOf]);
			| instanceof:
					FlushStack;
					Pop(JavaREF);
					idx := Index(TRUE);
					JC0.GenPUSH(JC0.Imme, 0, noBase, noInx, noScale, noDisp, SYSTEM.VAL(LONGINT, GetClass(c.constPool[idx])));
					SystemCall(c.fixsyscalls[JB.SCInstanceOf]);
					AllocateThisReg(EAX, Empty, TRUE);
					PushRegister(JavaINT, EAX, noBase);
			| monitorenter:
					Synchronize(TRUE)
			| monitorexit:
					Synchronize(FALSE)
			| wide:
					Wide := TRUE
			| ifnull, ifnonnull:	(* jump *)
					PushImmediate(JavaREF, 0);
					I2(JavaREF, JC0.CMP);
					IF OptimizeBooleanExp THEN
						OptimizeCmp(jcc[op - ifnull])
					ELSE
						val := Value(2);
						Jcc(jcc[op - ifnull], pc0, val, map);
						IF DoCheckRegs THEN CheckRegs END;
					END
			| gotow:	(* jump *)
					val := Value(4);
					Jcc(JMP, pc0, val, map);
					dead := TRUE;
			| jsrw:	(* jump *)
					CheckEmpty;
					val := Value(4);
					Jcc(CALL, pc0, val, map);
			END;
			
			IF (tos > 0) & (tos < LEN(block.creator)) & (block.creator[tos-1] = pc0) & (block.mustPush[tos-1]) THEN
				FOR i := 0 TO tos-1 DO	(* dup & Co have the same creator *)
					IF block.creator[i] = pc0 THEN
(*
						JC.String("Push tos item "); JC.Int(i,0); JC.Ln;
*)
						GenPushItem(stack[i])
					END
				END
			END;
			
			IF FlushStackAfterEachOp THEN
				FlushStack;
			END;
			IF TraceEmit OR TraceLines THEN JC.Ln(debugInfo) END;
			dead := FALSE;
			IF StackConsistencyCheck THEN CheckStackConsistency END;
		END;
		IF block.succ = NIL THEN
			CheckEmpty;
			CheckRegs
		END;
		block := block.next
	END;
	(*IF map[pc] = 0 THEN*) map[pc] := JC0.pc (*END*);
	CheckEmpty
END Traverse;
	
PROCEDURE EncodeMethod*(c: JB.RefClass; mno: LONGINT; code: JB.ACodeInfo; VAR moffset: LONGINT; VAR map: JB.Map);
	VAR module, method: ARRAY 256 OF CHAR; m: JB.Method;
		oberonName: JT.StringBuffer;
		name: ARRAY 128 OF CHAR;
		nofParams, nofLocals: LONGINT;
		time1, time2, time3: HUGEINT;
		b: BasicBlock;
		
BEGIN
	moffset := JC0.pc;
	m := c.methods[mno];
	nofParams := m.parsize DIV 4;
	IF (JB.AFStatic IN m.flags)&(code.maxLocals-nofParams > 0) THEN
		nofLocals := code.maxLocals-nofParams 
	ELSE
		nofLocals := code.maxLocals-nofParams + 1
	END;
	
	JT.MakeMethodName(m.name.value.p, m.descriptor, m.try = 0, oberonName);
	JT.MakeRefName(c.obobj, oberonName, (JB.AFStatic IN m.flags), name);
	JVMRefs.NewMethod(name, m.p, JC0.pc, nofParams, nofLocals);
	
	IF TraceMethodNames OR BenchTiming THEN
		JT.JavaToOberonString(c.name, 0, LEN(c.name^), module);
		StringPool.GetString(c.methods[mno].p.name, method);
	END;
	
	IF TraceMethodNames THEN
		JC.String(debugInfo, "Encode ");
		JC.String(debugInfo, module); JC.Char(debugInfo, ".");
		JC.String(debugInfo, method); 
		JC.String(debugInfo, "  "); JC.Int(debugInfo, JC0.pc, 0);
		JC.Ln(debugInfo);
		TraceLines := FALSE (*str = "testDiv"*);
	END;
	
	IF BenchTiming THEN
		time1 := AosBoot.GetTimer();
	END;
	
	b := ScanBasicBlocks(c, code);
	
	IF BenchTiming THEN
		time2 := AosBoot.GetTimer();
	END;
	
	Traverse(c, c.methods[mno], b, code, nofParams, nofLocals, map);
	
	IF BenchTiming THEN
		time3 := AosBoot.GetTimer();
		JC.String(debugInfo, module); JC.Char(debugInfo, "."); JC.String(debugInfo, name);
		JC.String(debugInfo, 9X);
		JC.Int(debugInfo, LEN(code.code), 0);
		JC.String(debugInfo, 9X);
		JC.Int(debugInfo, JC0.pc - moffset, 0);
		JC.String(debugInfo, 9X);
		JC.Int(debugInfo, SHORT(time2 - time1), 0);
		JC.String(debugInfo, 9X);
		JC.Int(debugInfo, SHORT(time3 - time2), 0);
		JC.Ln(debugInfo);
		ASSERT(time2 - time1 <= MAX(LONGINT));
		ASSERT(time3 - time2 <= MAX(LONGINT));
	END;
	
	IF TraceMethodNames THEN
		JC.Char(debugInfo, "<"); JC.Ln(debugInfo)
	END
END EncodeMethod;

PROCEDURE ShowStats*;
	VAR i: LONGINT;
BEGIN
	FOR i := 0 TO 255 DO
		JC.Int(statusInfo, i, 4); JC.String(statusInfo, ":  "); JC.Int(statusInfo, Aopcodes[i], 4); JC.Ln(statusInfo);
	END
END ShowStats;

PROCEDURE Init*(s: PCT.ModScope);
BEGIN
	JC0.pc := 0; JC0.dsize := 0; JC0.csize := 0; JVMRefs.refsize := 0;
	JC0.CodeErr := FALSE; JVMRefs.NewModule(s.firstVar, 0);
	JC0.PutByte(90H);
END Init;

PROCEDURE InitModule;
	VAR r: REAL; lr: LONGREAL; a: jjlObject.ByteArray;
	
	PROCEDURE SetSize(type, size, scale, fsize: SHORTINT);
	BEGIN
		Size[type] := size;
		Scale[type] := scale;
		FSize[type] := fsize;
	END SetSize;
	
BEGIN
	ArrayDim := 12;
	FirstArrayElem := 16;
	ArrayPtrOffset := SYSTEM.ADR(a.p) - SYSTEM.VAL(LONGINT, a);
	r := 0.0; fconst[0] := SYSTEM.VAL(LONGINT, r);
	r := 1.0; fconst[1] := SYSTEM.VAL(LONGINT, r);
	r := 2.0; fconst[2] := SYSTEM.VAL(LONGINT, r);
	lr := 0.0E0; SYSTEM.MOVE(SYSTEM.ADR(lr), SYSTEM.ADR(dconst[0]), 8);
	lr := 1.0E0; SYSTEM.MOVE(SYSTEM.ADR(lr), SYSTEM.ADR(dconst[1]), 8);
	Typ1Op[0] := JC0.ADD;
	Typ1Op[2] := JC0.SUB;
	Typ1Op[3] := JC0.AND;
	Typ1Op[4] := JC0.Or;
	Typ1Op[5] := JC0.XOR;
	
	FTyp1Op[0, 0] := JC0.GenFADD;
	FTyp1Op[1, 0] := JC0.GenFSUB;
	FTyp1Op[2, 0] := JC0.GenFMUL;
	FTyp1Op[3, 0] := JC0.GenFDIV;
	FTyp1Op[0, 1] := JC0.GenFADD;
	FTyp1Op[1, 1] := JC0.GenFSUBR;
	FTyp1Op[2, 1] := JC0.GenFMUL;
	FTyp1Op[3, 1] := JC0.GenFDIVR;
(*
	FTyp1Op[0] := JC0.GenFADD;
	FTyp1Op[1] := JC0.GenFSUB;
	FTyp1Op[2] := JC0.GenFMUL;
	FTyp1Op[3] := JC0.GenFDIV;
*)	
	SetSize(JavaBYTE, 1, JC0.Scale1, -1);
	SetSize(JavaCHAR, 2, JC0.Scale2, -1);
	SetSize(JavaSHORT, 2, JC0.Scale2, -1);
	SetSize(JavaINT, 4, JC0.Scale4, JC0.sInt);
	SetSize(JavaREF, 4, JC0.Scale4, JC0.sInt);
	SetSize(JavaLONG, 8, JC0.Scale8, JC0.lInt);
	SetSize(JavaFLOAT, 4, JC0.Scale4, JC0.sReal);
	SetSize(JavaDOUBLE, 8, JC0.Scale8, JC0.lReal);
	
	jcc[0] := JC0.JE; jcc[1] := JC0.JNE; jcc[2] := JC0.JL;
	jcc[3] := JC0.JGE; jcc[4] := JC0.JG; jcc[5] := JC0.JLE;
	Mode[Immediate] := JC0.ImmReg;
	Mode[Register] := JC0.RegReg;
	Mode[Field] := JC0.MemReg;
	Mode[Array] := JC0.MemReg;
	Mode[Static] := JC0.MemReg;
	Mode[Stack] := JC0.MemReg;
	Mode[Local] := JC0.MemReg;
	Mode[Constant] := JC0.MemReg;
	T[JavaINT] := "I";
	T[JavaLONG] := "L";
	T[JavaFLOAT] := "F";
	T[JavaDOUBLE] := "D";
	T[JavaREF] := "A";
	T[JavaBYTE] := "B";
	T[JavaCHAR] := "C";
	T[JavaSHORT] := "S";
	
	Type[JavaINT] := "INT";
	Type[JavaLONG] := "LONG";
	Type[JavaFLOAT] := "FLOAT";
	Type[JavaDOUBLE] := "DOUBLE";
	Type[JavaREF] := "REF";
	Type[JavaBYTE] := "BYTE";
	Type[JavaCHAR] := "CHAR";
	Type[JavaSHORT] := "SHORT";
	Type[JavaBOOL] := "BOOL";
	
	R[EAX] := "EAX";
	R[EBX] := "EBX";
	R[ECX] := "ECX";
	R[EDX] := "EDX";
	R[ESP] := "ESP";
	R[EBP] := "EBP";
	R[EDI] := "EDI";
	R[ESI] := "ESI";
	
	M[Immediate] := "Imm";
	M[Register] := "Reg";
	M[FRegister] := "FReg";
	M[Field] := "Fld";
	M[Array] := "Arr";
	M[Static] := "Stat";
	M[Stack] := "Stk";
	M[Local] := "Loc";
	M[Constant] := "Con";

	trueexp[0] := CHR(iconst0);
	trueexp[1] := CHR(goto);
	trueexp[2] := CHR(0);
	trueexp[3] := CHR(4);
	trueexp[4] := CHR(iconst1);
	
	falseexp[0] := CHR(iconst1);
	falseexp[1] := CHR(goto);
	falseexp[2] := CHR(0);
	falseexp[3] := CHR(4);
	falseexp[4] := CHR(iconst0);

	debugInfo.kind := JC.Debug; debugInfo.source := JC.Compiler;
	warningInfo.kind := JC.Warning; debugInfo.source := JC.Compiler;
	infoInfo.kind := JC.Info; infoInfo.source := JC.Compiler;
	statusInfo.kind := JC.Status; statusInfo.source := JC.Compiler;
	errorInfo.kind := JC.Error; errorInfo.source := JC.Compiler;
	failureInfo.kind := JC.Failure; failureInfo.source := JC.Compiler;
END InitModule;

BEGIN
	InitModule
END JVMOptCompiler.


(*

ToDo:
	(done) Check Register overwriting
	Check Aliasing
	Check out of order items on stack
	Check out of order items on ST
	Drop: load or push?
	
Improve:
2 remove 8/16 bit register support

	Allocate fpu consts in const section, load from memory
	
	Invoke: avoid double push when no parameters
	Invoke: push self as last if stack allows it
	
	FlushStack: push only parameters or non-local values
	
	f/d/l cmp followed by ifx
	
	optimize code pattern:
		ifx
		iconst0
		ireturn
		iconst1
		ireturn
	
	i2b/i2c/i2s, operate on place for stack ops
	i2b/i2c/i2s ignore if followed by b/c/s astore
	
	lmul: optimize case where v2 = register
	
	allow CMP R/M, IMM
	
	LongCmp: support for memory operands
	
	long shift: optimize const mode
*)

System.Free JVMDebug JVMOptCompiler ~

JVMOptCompiler.ShowStats
System.State JVMOptCompiler ~

