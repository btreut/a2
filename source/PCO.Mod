(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCO; (** AUTHOR "prk / be"; PURPOSE "Parallel Compiler: Intel 386 code patterns"; *)

(*
	Based on the OPO module for OP2 by N. Mannhart
*)

	IMPORT SYSTEM, PCM, PCLIR, Diagnostics;


	CONST

	(** mode and scale factors *)
	noScale* = 0; Scale1* = 0; Scale2* = 1; Scale4* = 2; Scale8* = 3;	(** scale factors *)
	RegReg* 	= 0;	(** register to register *)
	RegMem* 	= 1;	(** register to memory *)
	MemReg* 	= 2;	(** memory to register *)
	ImmReg* 	= 3;	(** immediate to register *)
	ImmMem* 	= 4;	(** immediate to memory *)
	RegSt* 	= 5; 	(** floating point st, reg *)
	StReg* 	= 6; 	(** floating point reg, st *)
	StRegP* 	= 7;	(** floating point ...p reg, st (with pop *)
	MemSt* 	= 8; 	(** floating point st, mem *)
	ForceDisp32*	= 20;	(** modes >= Disp32 have always a disp of 32-bits, don't overlap with Reg, Abs, RegRel, Coc *)
	RegMemA*	= RegMem+ForceDisp32;	(** register to memory, disp is 32-bit *)
	MemAReg*	= MemReg+ForceDisp32;	(** memory to register, disp is 32-bit *)
	ImmAReg*	= ImmReg+ForceDisp32;	(** immediate to memory, disp is 32-bit *)
	ImmMemA*	= ImmMem+ForceDisp32;	(** immediate to memory, disp is 32-bit *)
	MemASt* 	= MemSt+ForceDisp32; 	(** floating point st, mem *)

	(** item modes for Intel i386 (must not overlap item basemodes, > 13 *)
		Reg* = 15; Abs* = 16; RegRel* = 17; Coc* = 18;

	(** aliases used for instructions with one register like not, neg etc. *)
	Regs* 	= RegReg;
	Mem* 	= MemReg;
	Imme* 	= ImmReg;
	MemA*	= MemAReg;
	ImmeA*	= ImmAReg;

	(** i387 *)
	sReal* 	= 0; 	(** short real 32 bit = Bit32 *)
	lReal* 	= 2; 	(** long real 64 bit *)
	eReal* 	= 4;	(** extended real 80 bit, only valid in GenFLD, GenFSTP *)
	dInt* 	= 1;	(* double integer 32 bit *)
	wInt* = 3; 	(** word integer 16 bit *)
	qInt* = 5; 	(** quad integer 64 bit *)
(* !not implemented! and probably never used
	wInt = 1 	(** word integer 16 bit *)
	lInt = 5; 	(** long integer 64 bit *)
*)

	(* code and data length per module *)
	MaxCodeLength* = 2147483647;	(* 2^31 - 1, i.e. the maximum positive LONGINT number *)
	InitialCodeLength = 65536;
	(*MaxConstLength*	= 2147483647;	(* Max Const size allowed, limited by Object File Format, see PCBT.Mod*)*)

	(** i386 Register *)
		EAX* = 0; ECX* = 1; EDX* = 2; EBX* = 3; ESP* = 4; EBP* = 5; ESI* = 6; EDI* = 7; (** 32 bit register *)
		AX* = 8; CX* = 9; DX* = 10; BX* = 11; SP* =  12; BP* = 13; SI* = 14; DI* = 15; (** 16 bit register *)
		AL* = 16; CL* = 17; DL* = 18; BL* = 19; AH* = 20; CH* = 21; DH* = 22; BH* = 23; (** 8 bit register *)

	(** register/memory size (8,16, 32 or 64 bit) *)
	Bit8* = AL; Bit16* = AX; Bit32* = EAX (* must be 0 *); Bit64* = Bit32 + 8;


	noDisp* = 0; Disp8* = 1; Disp32* = 2; none = -1;
	noBase* = none; noInx* = none; noImm* = 0;

	BUG = 42;

	(** opcodes used for generating i386 code *)

		(**  GenShiftRot *)
		ROL* = 0; Ror* = 1; RCL* = 2; RCR* = 3; SHL* = 4; SAL* = 4; SHR* = 5; SAR*= 7;

		(** GenSHDouble *)
		Left* = 0; Right* = 1;

		(**  GenString, GenRepString, GenRepCmpsScas *)
		CMPS* = 53H; INS* = 36H; LODS* = 56H; MOVS* = 52H; OUTS* = 37H; SCAS* = 57H; STOS* = 55H;

		(** GenJcc *)
		JO* = 0; JNO* = 1; JB* = 2; JC* = 2; JNAE* = 2; JNB* = 3; JNC* = 3; JAE* = 3; JE* = 4; JZ* = 4;
		JNE* = 5; JNZ* = 5; JBE* = 6; JNA* = 6; JNBE* =7; JA* = 7; JS* = 8; JNS* = 9; JP* = 10; JPE* = 10;
		JNP* = 11; JPO* = 11; JL* = 12; JNGE* = 12; JNL* = 13; JGE* = 13; JLE* = 14; JNG* = 14;
		JNLE* = 15; JG* = 15;

		(** GenGroup3 *)
		NOT* = 2; NEG* = 3;

		(** GenTyp1 *)
		ADD* = 0; ADC* = 10H; SUB* = 28H; SBB* = 18H; CMP* = 38H; AND* = 20H; Or* = 8H; XOR* = 30H;

		(** Wait *)
		wWAIT* = 9BH;

		(** GenFop1 *)
		FCOMPP* = 0; FTST* = 1; FLDZ* = 2; FLD1* = 3; FABS* = 4; FCHS* = 5; FSTSW* = 6; FINCSTP* = 7; FDECSTP* = 8;

		(** GenB *)
		BT* = 4; BTR* = 6; BTS* = 5;

		(** general *)
		SAHF* = 9EH; CLD* = 0FCH; STD* = 0FDH; CBW* = 98H; CWD* = 99H (* = CDQ *);
		CLI* = 0FAH; STI* = 0FBH;


	VAR
	pc*, dsize*: LONGINT; 		(* code size, data size *)
	lastImmSize*: SHORTINT;		(* last immediate Size *)
	code*: PCLIR.CodeArray;	(* i386/i387 code area *)
	codeLength : LONGINT;
	errpos*: LONGINT;
	CodeErr*: BOOLEAN;

(* i386 Code Generator *)

   	PROCEDURE PutByteAt* (pos: LONGINT; b: INTEGER);
   	VAR c: PCLIR.CodeArray;
   	BEGIN
       	IF pos >= codeLength THEN
          		IF codeLength + InitialCodeLength <= MaxCodeLength THEN
               		codeLength := codeLength + InitialCodeLength;
               		NEW(c, codeLength);
               		SYSTEM.MOVE(ADDRESSOF(code[0]), ADDRESSOF(c[0]), LEN(code));
               		code := c;
               		code[pos] := CHR(b); (*fof*)
           		ELSE
               		IF ~CodeErr THEN  PCM.Error(210, Diagnostics.Invalid, ""); CodeErr:= TRUE  END;
               		pc:= 0
           		END
       	ELSE
           		code[pos]:= CHR (b)
       	END
   	END PutByteAt;

	PROCEDURE PutByte* (b: INTEGER);
	BEGIN
		PutByteAt(pc, b); INC(pc);
		IF pc >= PCM.breakpc THEN PCM.Error(400, errpos, ""); PCM.breakpc := MAX(LONGINT) END; (* << mh 30.8.94 *)
	END PutByte;

	PROCEDURE PutWord (w: LONGINT);
	BEGIN
		PutByteAt(pc, SHORT( w MOD 100H)); INC(pc);
		PutByteAt(pc, SHORT((w DIV 100H) MOD 100H)); INC(pc);
		IF pc >= PCM.breakpc THEN PCM.Error(400, errpos, ""); PCM.breakpc := MAX(LONGINT) END; (* << mh 30.8.94 *)
	END PutWord;

  	 PROCEDURE PutDWordAt* (pos, dw: LONGINT);
  	 VAR c: PCLIR.CodeArray;
  	 BEGIN
      		 IF pos >= codeLength - 4 THEN
          		 IF codeLength + InitialCodeLength <= MaxCodeLength THEN
               		codeLength := codeLength + InitialCodeLength;
               		NEW(c, codeLength);
               		SYSTEM.MOVE(ADDRESSOF(code[0]), ADDRESSOF(c[0]), LEN(code));
               		code := c;
               		 (*fof>>*)
                		code[pos]:= CHR ( dw MOD 100H); INC (pos); (* low byte first *)
               		code[pos]:= CHR ( ( dw DIV 100H) MOD 100H); INC (pos);
               		code[pos]:= CHR ( ( dw DIV 10000H) MOD 100H); INC (pos);
               		code[pos]:= CHR (dw DIV 1000000H)
              		 (*fof<<*)
           		ELSE
              		 IF ~CodeErr THEN  PCM.Error(210, Diagnostics.Invalid, ""); CodeErr:= TRUE  END;
               		pc:= 0
           		END
       	ELSE
           		code[pos]:= CHR ( dw MOD 100H); INC (pos); (* low byte first *)
           		code[pos]:= CHR ( ( dw DIV 100H) MOD 100H); INC (pos);
           		code[pos]:= CHR ( ( dw DIV 10000H) MOD 100H); INC (pos);
          		code[pos]:= CHR (dw DIV 1000000H)
       	END
  	END PutDWordAt;

	PROCEDURE PutDWord* (dw: LONGINT);
	BEGIN
		PutDWordAt(pc, dw); INC(pc, 4);
		IF pc >= PCM.breakpc THEN PCM.Error(400, errpos, ""); PCM.breakpc := MAX(LONGINT) END; (* << mh 30.8.94 *)
	END PutDWord;

	PROCEDURE GetDWord* (pos: LONGINT; VAR dw: LONGINT);
		VAR byte: INTEGER;
	BEGIN
		dw:= ORD (code[pos]) + LONG (ORD (code[pos+1])) * 100H + LONG (ORD (code[pos+2])) * 10000H;
		byte:= ORD (code[pos+3]);
		IF byte >= 128 THEN byte:= byte - 256 END;
		dw:= LONG (byte) * 1000000H + dw
	END GetDWord;

	PROCEDURE PutReg (reg1, reg2: INTEGER);
	(* encodes register register addressing mode *)
	BEGIN
		reg1:= reg1 MOD 8; reg2:= reg2 MOD 8;
		PutByte (3 * 40H + reg1 * 8+ reg2)
	END PutReg;

	PROCEDURE PutRMInx (reg, base, inx, scale: INTEGER; disp: LONGINT;  disp32: BOOLEAN);
	(* put register memory with index *)
	BEGIN
		reg:= reg MOD 8; inx:= inx MOD 8;
		IF base = noBase (*mode = Abs*) THEN
			PutByte (noDisp * 40H + reg * 8 + 4); (* s-i-b is present *)
			PutByte (scale * 40H + inx * 8+ 5);	(* DS:[d32 + inx*scale] *)
			PutDWord (disp)
		ELSE (* RegRel *)
			base:= base MOD 8;
			IF (disp = 0) & (base # EBP) THEN
				PutByte (noDisp * 40H + reg * 8 + 4);	(* s-i-b is present *)
				PutByte (scale * 40H + inx * 8 + base)	(* DS:[base + inx*scale] *)
			ELSIF (disp <= 127) & (disp >= -128) & ~disp32 THEN
				PutByte (Disp8 * 40H + reg * 8 + 4); 	(* s-i-b is present + disp8*)
				PutByte (scale * 40H + inx * 8 + base);	(* DS:[base + inx*scale] *)
				PutByte (SHORT (disp))
			ELSE
				PutByte (Disp32 * 40H + reg * 8 + 4);	(* s-i-b is present + disp32*)
				PutByte (scale * 40H + inx * 8 + base);	(* DS:[base + inx*scale] *)
				PutDWord (disp)
			END
		END
	END PutRMInx;

	PROCEDURE PutRegMem ((*mode: SHORTINT;*) reg, base: INTEGER; disp: LONGINT;  disp32: BOOLEAN);
	(* put register memory *)
	BEGIN
		reg:= reg MOD 8;
		IF base = noBase (*mode = Abs*) THEN
			PutByte (noDisp * 40H + reg * 8 + 5);	(* DS:d32 *)
			PutDWord (disp)
		ELSE (* mode = RegRel *)
			base:= base MOD 8;
			IF base = ESP THEN (* 2 bytes address encoding necessary *)
				PutRMInx (reg, base, 4, Scale1, disp, disp32) (* no index register: reg, disp[ESP] *)
			ELSIF (disp = 0) & (base # EBP) & ~disp32 THEN (* no displacement *)
				PutByte (noDisp * 40H + reg * 8 + base)	(*  DS:[base] *)
			ELSIF (disp <= 127) & (disp >= -128) & ~disp32 THEN
				PutByte (Disp8 * 40H + reg * 8 + base);	(*  DS:[base + d8] *)
				PutByte (SHORT (disp))
			ELSE
				PutByte (Disp32 * 40H + reg * 8 + base);	(*  DS:[base + d32] *)
				PutDWord (disp)
			END
		END
	END PutRegMem;

	PROCEDURE PutMem (reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT;  disp32: BOOLEAN);
	(* put memory *)
	BEGIN
		IF inx = noInx THEN PutRegMem (reg, base, disp, disp32)
		ELSE PutRMInx (reg, base, inx, scale, disp, disp32)
		END
	END PutMem;

	PROCEDURE PutDisp (disp: LONGINT; size: INTEGER);
	BEGIN
		lastImmSize:= SHORT (size);
		IF size >= Bit8 THEN PutByte (SHORT (disp))
		ELSIF size >= Bit16 THEN PutWord (disp)
		ELSE PutDWord (disp) (* size =  Bit32 *)
		END
	END PutDisp;

	PROCEDURE Prefix* (reg: INTEGER; VAR w: SHORTINT);
	(* put out the Operand Size Prefix if necessary
		w = 0 : 8 bit data w= 1: 16/32 bit data *)
	BEGIN
		IF reg IN {AX..DI} THEN
			PutByte (66H); w:= 1 (* Operand Size Prefix *)
		ELSIF reg IN {EAX..EDI} THEN w:= 1
		ELSE w:= 0
		END
	END Prefix;

	PROCEDURE GenMOV* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp, imm: LONGINT);
		VAR w: SHORTINT; r: INTEGER;
	BEGIN
		Prefix (reg, w);
		CASE mode OF
			RegReg:
				(* reg = destination, base = source *)
				PutByte (8AH + w); PutReg (reg, base)
		  | RegMem, RegMemA:
				IF ( (reg = EAX) OR (reg = AX) OR (reg = AL) ) & (inx = noInx) & (base = none) THEN
					PutByte (0A2H + w); PutDWord (disp)
				ELSE
					PutByte (88H + w); PutMem (reg, base, inx, scale, disp, mode = RegMemA)
				END
		  | MemReg, MemAReg:
				IF ( (reg = EAX) OR (reg = AX) OR (reg = AL) ) & (inx = noInx) & (base = none) THEN
					PutByte (0A0H + w); PutDWord (disp)
				ELSE
					PutByte (8AH + w); PutMem (reg, base, inx, scale, disp, mode = MemAReg)
				END
		  | ImmReg:
				r:= reg; reg:= reg MOD 8;
				IF imm = 0 THEN
					PutByte (30H + 2H + w); PutReg(r, r)	(*use XOR reg, reg*)
				ELSE
					PutByte (0B0H + w * 8 + reg); PutDisp (imm, r)
				END
		  | ImmAReg:
				r:= reg; reg:= reg MOD 8;
				PutByte (0B0H + w * 8 + reg); PutDisp (imm, r)
		  | ImmMem, ImmMemA:
				PutByte (0C6H + w); PutMem (reg, base, inx, scale, disp, mode = ImmMemA); PutDisp (imm, reg)
		ELSE HALT (BUG)
		END
	END GenMOV;

	PROCEDURE GenMOVSX* (mode, s: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
		VAR w: SHORTINT; (* s = 0: 8 bit; s = 1: 16/32 bit *)
	BEGIN
		Prefix (reg, w);
		PutByte (0FH); PutByte (0BEH + s);
		CASE mode OF
			RegReg:
				(* reg = destination, base = source *)
				PutReg (reg, base)
		  | MemReg, MemAReg:
				PutMem (reg, base, inx, scale, disp, mode = MemAReg)
		ELSE HALT (BUG)
		END
	END GenMOVSX;

	PROCEDURE GenMOVZX* (mode, s: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
		VAR w: SHORTINT; (* s = 0: 8 bit; s = 1: 16/32 bit *)
	BEGIN
		Prefix (reg, w);
		PutByte (0FH); PutByte (0B6H+s);
		CASE mode OF
			RegReg: (* reg = destination, base = source *)
				PutReg (reg, base)
		  | MemReg, MemAReg:
				PutMem (reg, base, inx, scale, disp, mode = MemAReg)
		ELSE HALT (BUG)
		END
	END GenMOVZX;

	PROCEDURE GenIN* (size: INTEGER);
	BEGIN
		CASE size OF
		    Bit32: PutByte(0EDH)		(* IN EAX, DX *)
		 | Bit16: PutWord(0ED66H)   (* IN AX, DX *)
		 | Bit8: PutByte(0ECH);	    (* IN AL, DX *)
		 END
	END GenIN;

	PROCEDURE GenOUT* (size: INTEGER);
	BEGIN
		CASE size OF
		    Bit32: PutByte(0EFH)		(* OUT DX, EAX *)
		 | Bit16: PutWord(0EF66H)   (* OUT DX, AX *)
		 | Bit8: PutByte(0EEH);	    (* OUT DX, AL *)
		 END
	END GenOUT;

	PROCEDURE GenPUSH* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp, imm: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		IF (mode = Imme) & (reg = AX) THEN  reg := EAX  END;	(*16bit immediate -> push 32 bit *)
		Prefix (reg, w);
		CASE mode OF
			Regs:
				reg:= reg MOD 8;
				PutByte (50H + reg)
		  | Mem, MemA: (* push memory *)
				reg:= ESI; PutByte (0FFH); PutMem (reg, base, inx, scale, disp, mode = MemA)
		  | Imme: (* push immediate *)
				IF (imm <= 127) & (imm >= -128) THEN
					PutByte (6AH); PutByte (SHORT (imm))
				ELSE
					PutByte (68H); PutDWord (imm)
				END
		  | ImmeA: (* push immediate *)
		  		PutByte (68H); PutDWord (imm)
		ELSE HALT (BUG)
		END
	END GenPUSH;

	PROCEDURE GenPOP* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		Prefix (reg, w);
		CASE mode OF
			Regs:
				reg:= reg MOD 8; PutByte (58H + reg)
		  | Mem, MemA: (* pop memory *)
				reg:= EAX; PutByte (8FH); PutMem (reg, base, inx, scale, disp, mode = MemA)
		ELSE HALT (BUG)
		END
	END GenPOP;

	PROCEDURE GenXCHG* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		Prefix (reg, w);
		CASE mode OF
			RegReg:
				IF (reg = EAX) OR (reg = AX) THEN
					base:= base MOD 8;
					PutByte (90H + base)
				ELSE
					PutByte (86H + w); PutReg (reg, base)
				END
		  | RegMem, RegMemA:
				PutByte (86H + w); PutMem (reg, base, inx, scale, disp, mode = RegMemA)
		ELSE HALT (BUG)
		END
	END GenXCHG;

	PROCEDURE GenLEA* (disp32: BOOLEAN; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		(* no prefix necessary, addressing mode is always 32 bit *)
		IF (reg = base) & (inx = noInx) & (disp = 0) THEN
			(* skip: LEA reg, 0[reg] has no effect *)
		ELSE
			PutByte (8DH); PutMem (reg, base, inx, scale, disp, disp32)
		END
	END GenLEA;

	PROCEDURE GenTyp1* (op, mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp, imm: LONGINT);
	(* general code generator procedure for ADD, ADC, AND, XOR, OR, SBB, SUB, CMP *)
		VAR w, wImm: SHORTINT;
	BEGIN
		Prefix (reg, w);
		CASE mode OF
			RegReg: (* reg = destination, base = source *)
				PutByte (op + 2H + w); PutReg (reg, base);
		  | RegMem, RegMemA:
				PutByte (op + w); PutMem (reg, base, inx, scale, disp, mode = RegMemA)
		  | MemReg, MemAReg:
				PutByte (op + 2H + w); PutMem (reg,base, inx, scale, disp, mode = MemAReg)
		  | ImmReg, ImmAReg:
				IF (reg = EAX) OR (reg = AX) OR (reg = AL) THEN
					PutByte (op + 4H + w); PutDisp (imm, reg)
				ELSE
					IF reg >= AL THEN (* 8 bit *)
						PutByte (80H); wImm:= Bit8
					ELSIF (mode = ImmReg) & (imm <= 127) & (imm >= -128) THEN (* sign extended *)
						PutByte (83H); wImm:= Bit8
					ELSE (* 16/32 bit immediate *)
						PutByte (81H); wImm:= SHORT (reg) (* 16/32 bit *)
					END;
					PutReg (op DIV 8, reg); (* op DIV 8 is code for op *)
					PutDisp (imm, wImm)
				END
		  | ImmMem, ImmMemA:
				IF reg >= AL THEN (* byte ptr *)
					PutByte (80H); wImm:= Bit8
				ELSIF (imm <= 127) & (imm >= -128) THEN (* sign extended *)
					PutByte (83H); wImm:= Bit8 (* 16/32 bit *)
				ELSE (* 16/32 bit immediate *)
					PutByte (81H); wImm:= SHORT (reg) (* 16/32 bit *)
				END;
				PutMem (op DIV 8, base, inx, scale, disp, mode = ImmMemA);
				PutDisp (imm, wImm)
		ELSE HALT (BUG)
		END
	END GenTyp1;

	PROCEDURE GenGroup3* (op, mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	(* generic code generator for NEG, NOT *)
		VAR w: SHORTINT;
	BEGIN
		Prefix (reg, w); PutByte (0F6H + w);
		IF mode = Regs THEN PutReg (op, reg)
		ELSE PutMem (op, base, inx, scale, disp, FALSE)
		END
	END GenGroup3;

	PROCEDURE GenINC* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		Prefix (reg, w);
		IF mode = ImmReg THEN
			IF w # 0 THEN
				reg:= reg MOD 8; PutByte (40H + reg)
			ELSE
				PutByte (0FEH + w); PutReg (0, reg)
			END
		ELSE
			PutByte (0FEH + w); PutMem (0, base, inx, scale, disp, FALSE)
		END
	END GenINC;

	PROCEDURE GenDEC* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		Prefix (reg, w);
		IF mode = ImmReg THEN
			IF w # 0 THEN
				reg:= reg MOD 8; PutByte (48H + reg)
			ELSE
				PutByte (0FEH + w); PutReg (1, reg)
			END
		ELSE
			PutByte (0FEH + w); PutMem (1, base, inx, scale, disp, FALSE)
		END
	END GenDEC;

	PROCEDURE GenMUL* (disp32: BOOLEAN; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		ASSERT(reg MOD 8 = EAX);	(*EAX or AX or AL *)
		Prefix(reg, w);
		PutByte(0F6H + w); PutMem (4, base, inx, scale, disp, disp32)
	END GenMUL;

	PROCEDURE GenIMUL* (mode: SHORTINT; shortform: BOOLEAN; reg, base, inx: INTEGER; scale: SHORTINT;
									disp, imm: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		Prefix (reg, w);
		CASE mode OF
			RegReg: (* reg := reg * base *)
				IF shortform THEN
					PutByte (0F6H + w); PutReg (5, base)
				ELSE
					PutByte (0FH); PutByte (0AFH); PutReg (reg, base)
				END
		  | MemReg, MemAReg: (* reg := reg * mem *)
				IF shortform THEN
					PutByte (0F6H + w); PutMem (5, base, inx, scale, disp, mode = MemAReg)
				ELSE
					PutByte (0FH); PutByte (0AFH); PutMem (reg, base, inx, scale, disp, mode = MemAReg)
				END
		  | ImmReg: (* reg := base * imm *)
				IF (imm <= 127) & (imm >= -128) THEN
					PutByte (6BH); PutReg (reg, base); PutByte (SHORT (imm))
				ELSE
					PutByte (69H); PutReg (reg, base); PutDisp (imm, base)
				END
		  | ImmMem, ImmMemA:
				IF (imm <= 127) & (imm >= -128) THEN
					PutByte (6BH); PutMem (reg, base, inx, scale, disp, mode = ImmMemA); PutByte (SHORT (imm))
				ELSE
					PutByte (69H); PutMem (reg, base, inx, scale, disp, mode = ImmMemA); PutDisp (imm, base)
				END
		ELSE HALT (BUG)
		END
	END GenIMUL;

	PROCEDURE GenIDIV* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		Prefix (reg, w); PutByte (0F6H + w);
		IF mode = RegReg THEN PutReg (7, reg)
		ELSE PutMem (7, base, inx, scale, disp, mode >= ForceDisp32)
		END
	END GenIDIV;

	PROCEDURE GenShiftRot* (op, mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp, imm: LONGINT);
	(* Generates code for ROL, ROR, SAL, SAR, SHL and SHR *)
		VAR w: SHORTINT;
	BEGIN
		Prefix (reg, w);
		CASE mode OF
			RegReg: (* reg by  base, base = CL *)
				PutByte (0D2H + w); PutReg (op, reg)
		  | RegMem, RegMemA: (* mem by reg; reg = CL *)
				PutByte (0D2H + w); PutMem (op, base, inx, scale, disp, mode = RegMemA)
		  | ImmReg: (* register by immediate *)
				IF imm = 1 THEN
					PutByte (0D0H + w); PutReg (op, reg)
				ELSE
					PutByte (0C0H + w); PutReg (op, reg); PutByte (SHORT (imm))
				END
		  | ImmMem, ImmMemA: (* memory by immediate *)
				IF imm = 1 THEN
					PutByte (0D0H + w); PutMem (op, base, inx, scale, disp, mode = ImmMemA)
				ELSE
					PutByte (0C0H + w); PutMem (op, base, inx, scale, disp, mode = ImmMemA); PutByte (SHORT (imm))
				END
		ELSE HALT (BUG)
		END
	END GenShiftRot;

	PROCEDURE GenSHDouble* (op, mode: SHORTINT; shortform: BOOLEAN; reg, base, inx: INTEGER; scale: SHORTINT; disp, imm: LONGINT);
	VAR w : SHORTINT;
	BEGIN
		ASSERT((op = Left) OR (op = Right), 200);
		Prefix (reg, w);
		CASE mode OF
		| RegReg:
				IF shortform THEN
					PutByte(0FH); PutByte(0A5H + op*8); PutReg (reg, base)
				ELSE
					PutByte(0FH); PutByte(0A4H + op*8); PutReg (reg, base); PutByte (SHORT (imm))
				END
		| RegMem:
				IF shortform THEN
					PutByte(0FH); PutByte(0A5H + op*8); PutMem(reg, base, inx, scale, disp, FALSE)
				ELSE
					PutByte(0FH); PutByte(0A4H + op*8); PutMem(reg, base, inx, scale, disp, FALSE); PutByte (SHORT (imm))
				END
		ELSE HALT(BUG)
		END;
	END GenSHDouble;

	PROCEDURE GenString* (op, size: INTEGER);
		VAR w: SHORTINT;
	BEGIN
		Prefix (size, w);
		PutByte (op * 2 + w)
	END GenString;

	PROCEDURE GenRepString* (op, size: INTEGER); (* without REPE CMPS, REPE SCAS *)
		VAR w: SHORTINT;
	BEGIN
		Prefix (size, w);
		PutByte (0F3H); PutByte (op * 2 + w)
	END GenRepString;

	PROCEDURE GenRepCmpsScas* (op, size: INTEGER);
	(* REPE CMPS, REPE SCAS *)
		VAR w: SHORTINT;
	BEGIN
		Prefix (size, w);
		PutByte (0F3H); PutByte (op * 2 + w)
	END GenRepCmpsScas;

	PROCEDURE GenTEST* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp, imm: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		Prefix(reg, w);
		CASE mode OF
		| RegReg:	(* TEST reg, base *)
				PutByte(84H+w); PutReg(base, reg)
		| RegMem, RegMemA:	(* TEST mem, reg *)
				PutByte(84H+w); PutMem (reg, base, inx, scale, disp, mode = RegMemA)
		| ImmReg:	(* TEST reg, imm *)
				IF reg IN {EAX, AX, AL} THEN
					PutByte(0A8H+w); PutDisp(imm, (reg DIV 8) * 8)
				ELSE
					PutByte(0F6H+w); PutReg(0, reg);  PutDisp(imm, (reg DIV 8) * 8)
				END
		| ImmMem, ImmMemA:	(* TEST mem, imm *)
				PutByte(0F6H+w);
				PutMem(0, base, inx, scale, disp, mode = ImmMemA);  PutDisp(imm, (reg DIV 8) * 8)
		ELSE HALT (BUG)
		END
	END GenTEST;

	PROCEDURE GenB* (op: SHORTINT; mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp, imm: LONGINT);
		VAR w: SHORTINT;
	BEGIN
		Prefix (reg, w); PutByte (0FH);
		CASE mode OF
			RegReg: (* BT reg, base *)
				PutByte (083H + 8*op); PutReg (base, reg)
		  | RegMem, RegMemA: (* BT mem, reg *)
				PutByte (083H + 8*op); PutMem (reg, base, inx, scale, disp, mode = RegMemA)
		  | ImmReg: (* BT reg, imm *)
				PutByte (0BAH); PutReg (op, reg); PutByte (SHORT (imm))
		  | ImmMem, ImmMemA: (* BT mem, imm *)
				PutByte (0BAH); PutMem (op, base, inx, scale, disp, mode = ImmMemA); PutByte (SHORT (imm))
		ELSE HALT (BUG)
		END
	END GenB;

	PROCEDURE GenCALL* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	(* no intersegment call implemented yet *)
	BEGIN
		IF (mode = Imme) OR (mode = ImmeA) THEN  (* direct call within segment *)
			PutByte (0E8H); PutDWord (disp)
		ELSE
			PutByte (0FFH);
			IF mode = Regs THEN PutReg (2, reg) (* call reg *)
			ELSE PutMem (2, base, inx, scale, disp, TRUE) (* Memory call, displacement must be 32-bit wide as it will need a fix-up *)
			END
		END
	END GenCALL;

	PROCEDURE GenJMP* (mode: SHORTINT; reg, base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	(* no intersegment jmp implemented yet *)
	BEGIN
		IF mode =  Imme THEN (* direct jmp whithin segment *)
			IF (disp <= 127) & (disp >= -128) THEN (* short jump *)
				PutByte (0EBH); PutByte (SHORT (disp))
			ELSE
				PutByte (0E9H); PutDWord (disp)
			END
		ELSIF mode =  ImmeA THEN (* direct jmp whithin segment *)
			PutByte (0E9H); PutDWord (disp)
		ELSE
			PutByte (0FFH);
			IF mode = Regs THEN PutReg (4, reg) (* jmp reg *)
			ELSE PutMem (4, base, inx, scale, disp, mode >= ForceDisp32) (* jmp memory *)
			END
		END
	END GenJMP;

	PROCEDURE GenRET* (size: LONGINT);
	(* no intersegemt return implemented yet *)
	BEGIN
		IF size = 0 THEN PutByte (0C3H)
		ELSIF size > 0FFFFH THEN
			(* ret takes only 16bit operands, thus returning more than 10000H bytes must be done by hand*)
			(* POP EBX *)
			(* ADD ESP, size*)
			(* JMP EBX*)
			GenPOP(Regs, EBX, noBase, noInx, noScale, noDisp);
			GenTyp1(ADD, ImmReg, ESP, noBase, noInx, noScale, noDisp, size);
			GenJMP(Regs, EBX, noBase, noInx, noScale, noDisp)
		ELSE
			PutByte (0C2H); PutWord (size)
		END
	END GenRET;

	PROCEDURE GenJcc* (op: SHORTINT; disp: LONGINT);
	(*
		jo, jno, jb/jnae, jnb/jae, je/jz, jne/jnz, jbe/jna, jnbe/ja, js, jns, jp/jpe, jnp/jpo, jl/jnge, jnl/jge, jnle/jg
		disp must lie within the segment!
	*)
	BEGIN
		IF (disp <= 127) & (disp >= -128) THEN (* short jmp *)
			PutByte (70H + op); PutByte (SHORT (disp))
		ELSE (* near jmp, always 32 bit wide *)
			PutByte (0FH); PutByte (80H + op); PutDWord (disp)
		END
	END GenJcc;

	PROCEDURE GenSetcc* (op, mode: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	(*
		seto, setno, setb/setna, setnb, sete/setz, setne/setnz, setnbe/seta, sets, setns, setp/setpe, setnp/setpo,
		setl/setnge, setnl/setge, setle/setng, setnle/setg
		target register/memory is always 8 bit!
	*)
	BEGIN
		PutByte (0FH); PutByte (90H + op);
		IF mode = Regs THEN PutReg (0, base) (* setcc reg *)
		ELSE PutMem (0, base, inx, scale, disp, mode >= ForceDisp32)
		END
	END GenSetcc;

	PROCEDURE GenINT* (intNumber: INTEGER);
	(* int intNumber *)
	BEGIN
		PutByte (0CDH); PutByte (intNumber)
	END GenINT;

	PROCEDURE InlineCode* (VAR code: ARRAY OF CHAR; parSize: INTEGER);
		VAR i, n: INTEGER;
	BEGIN
		n := ORD(code[0]); i := 1;
		WHILE i <= n DO PutByte(ORD(code[i])); INC(i) END;
	END InlineCode;

(* floating point encoding *)

	PROCEDURE GenFLD* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		CASE mode OF
			Regs: (* fload st(0), st (i) ; st(i) = base *)
				PutByte (0D9H); PutByte (0C0H + base)
		  | Mem, MemA: (* fload st(0), mem *)
				IF size = eReal THEN
					PutByte (0DBH); PutMem (5, base, inx, scale, disp, mode = MemA)
				ELSIF size = qInt THEN
					PutByte (0DFH); PutMem (5, base, inx, scale, disp, mode = MemA)
				ELSE
					PutByte (0D9H + size * 2); PutMem (0, base, inx, scale, disp, mode = MemA)
				END
		ELSE HALT (BUG)
		END
	END GenFLD;

	PROCEDURE GenFST* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		CASE mode OF
			Regs: (* fstore st(0), st(i); st(i) = base *)
				PutByte (0DDH); PutByte (0D0H + base)
		  | RegMem, RegMemA: (* fstore mem, st(0) *)
				PutByte (0D9H + size * 2); PutMem (2, base, inx, scale, disp, mode = RegMemA)
		ELSE HALT (BUG)
		END
	END GenFST;

	PROCEDURE GenFSTP* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		CASE mode OF
			Regs: (* fstore st(0), st(i); st(i) = base *)
				PutByte (0DDH); PutByte (0D8H + base)
		  | RegMem, RegMemA:
				IF size = eReal THEN
					PutByte (0DBH); PutMem (7, base, inx, scale, disp, mode = RegMemA)
				ELSIF size = qInt THEN
					PutByte (0DFH); PutMem (7, base, inx, scale, disp, mode = RegMemA)
				ELSE
					PutByte (0D9H + size * 2); PutMem (3, base, inx, scale, disp, mode = RegMemA)
				END
		ELSE HALT (BUG)
		END
	END GenFSTP;

	PROCEDURE GenFCOM* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		CASE mode OF
			Regs: (* fcom st(0), st(i) *)
				PutByte (0D8H); PutByte (0D0H + base)
		  | Mem, MemA: (* fcom st(0), mem *)
				PutByte (0D8H + size * 2); PutMem (2, base, inx, scale, disp, mode = MemA)
		ELSE HALT (BUG)
		END
	END GenFCOM;

	PROCEDURE GenFCOMP* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		CASE mode OF
			Regs: (* fcomp st(0), st(i) *)
				PutByte (0D8H); PutByte (0D8H+ base)
		  | Mem, MemA: (* fcomp st(0), mem *)
				PutByte (0D8H + size * 2); PutMem (3, base, inx, scale, disp, mode = MemA)
		ELSE HALT (BUG)
		END
	END GenFCOMP;

	PROCEDURE GenFtyp1* (op, mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		CASE mode OF
			RegSt: (* op st, base and pop not possible*)
				PutByte (0D8H); PutByte (0C0H + LONG (op) * 8 + base)
		  | StReg: (* op base, st *)
				PutByte (0DCH); PutByte (0C0H + LONG (op) * 8 + base)
		  | StRegP: (* op base, st *)
				PutByte (0DEH); PutByte (0C0H + LONG (op) * 8 + base)
		  | MemSt, MemASt:
				PutByte (0D8H + size * 2); PutMem (op, base, inx, scale, disp, mode = MemASt)
		ELSE HALT (BUG)
		END
	END GenFtyp1;

	PROCEDURE GenFADD* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		GenFtyp1 (0, mode, size, base, inx, scale, disp)
	END GenFADD;

	PROCEDURE GenFSUB* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		IF (mode = StReg) OR (mode = StRegP) THEN GenFtyp1 (5, mode, size, base, inx, scale, disp)
		ELSE GenFtyp1 (4, mode, size, base, inx, scale, disp)
		END
	END GenFSUB;

	PROCEDURE GenFSUBR* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		IF (mode = StReg) OR (mode = StRegP) THEN GenFtyp1 (4, mode, size, base, inx, scale, disp)
		ELSE GenFtyp1 (5, mode, size, base, inx, scale, disp)
		END
	END GenFSUBR;

	PROCEDURE GenFMUL* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		GenFtyp1 (1, mode, size, base, inx, scale, disp)
	END GenFMUL;

	PROCEDURE GenFDIV* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		IF (mode = StReg) OR (mode = StRegP) THEN GenFtyp1 (7, mode, size, base, inx, scale, disp)
		ELSE GenFtyp1 (6, mode, size, base, inx, scale, disp)
		END
	END GenFDIV;

	PROCEDURE GenFDIVR* (mode, size: SHORTINT; base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		IF (mode = StReg) OR (mode = StRegP) THEN GenFtyp1 (6, mode, size, base, inx, scale, disp)
		ELSE GenFtyp1 (7, mode, size, base, inx, scale, disp)
		END
	END GenFDIVR;

	PROCEDURE GenFFREE* (freg: INTEGER);
	BEGIN
		PutByte (0DDH); PutByte (0C0H + freg)
	END GenFFREE;

	PROCEDURE GenFop1* (op: INTEGER);
	BEGIN
		CASE op OF
			FCOMPP:
				PutByte (0DEH); PutByte (0D9H)
		  | FTST:
				PutByte (0D9H); PutByte (0E4H)
		  | FLDZ:
				PutByte (0D9H); PutByte (0EEH)
		  | FLD1:
				PutByte (0D9H); PutByte (0E8H)
		  | FABS:
				PutByte (0D9H); PutByte (0E1H)
		  | FCHS:
				PutByte (0D9H); PutByte (0E0H)
		  | FSTSW:
				PutByte (0DFH); PutByte (0E0H)
		  | FINCSTP:
				PutByte (0D9H); PutByte (0F7H)
		  | FDECSTP:
				PutByte (0D9H); PutByte (0F6H)
		ELSE HALT (BUG)
		END
	END GenFop1;

	PROCEDURE GenFSTCW* (base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		PutByte (0D9H); PutMem (7, base, inx, scale, disp, FALSE)
	END GenFSTCW;

	PROCEDURE GenFLDCW* (base, inx: INTEGER; scale: SHORTINT; disp: LONGINT);
	BEGIN
		PutByte (0D9H); PutMem (5, base, inx, scale, disp, FALSE)
	END GenFLDCW;

BEGIN
	codeLength := InitialCodeLength;
	NEW(code, codeLength)
END PCO.


(*
	15.11.06	ug	code length not limited to 64K, can be extended by chunks of 64K
	04.07.01	prk	intel's ret can only free 2^16 bytes of stack, fixed
	07.05.01	prk	Installable code generators moved to PCLIR; debug function added
	03.05.01	be	Installable code generators
	26.04.01	prk	PCLIR.lea partly removed
*)
