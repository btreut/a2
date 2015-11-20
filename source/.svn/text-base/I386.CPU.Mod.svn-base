(* Runtime support for CPU internals *)
(* Copyright (C) Florian Negele *)

MODULE CPU;

IMPORT SYSTEM;

CONST StackSize* = 1024 *  SIZEOF(ADDRESS);
CONST Quantum* = 1000000;
CONST CacheLineSize* = 64;
CONST StackDisplacement* = 0;

PROCEDURE Backoff-;
CODE
	MOV	EBX, 80000H
loop:
	DEC	EBX
	JNZ		loop
END Backoff;

(* cpu control *)
PROCEDURE {NORETURN} Reset-;
CODE
	CLI
	PUSH	0
	PUSH	0
	LIDT	[ESP]
	INT3
END Reset;

PROCEDURE {NORETURN} Halt-;
CODE
	CLI
end:
	HLT
	JMP	end
END Halt;

(* input / output ports *)
PROCEDURE OutChar- (port: SIZE; value: CHAR);
CODE
	MOV	AL, [EBP + value]
	MOV	DX, [EBP + port]
	OUT	DX, AL
END OutChar;

PROCEDURE OutByte- (port: SIZE; value: SIZE);
CODE
	MOV	AL, [EBP + value]
	MOV	DX, [EBP + port]
	OUT	DX, AL
END OutByte;

PROCEDURE OutSet- (port: SIZE; value: SET);
CODE
	MOV	AL, [EBP + value]
	MOV	DX, [EBP + port]
	OUT	DX, AL
END OutSet;

PROCEDURE InChar- (port: SIZE): CHAR;
CODE
	MOV	DX, [EBP + port]
	IN		AL, DX
END InChar;

PROCEDURE InByte- (port: SIZE): SIZE;
CODE
	MOV	DX, [EBP + port]
	IN		AL, DX
	MOVZX	EAX, AL
END InByte;

PROCEDURE InSet- (port: SIZE): SET;
CODE
	MOV	DX, [EBP + port]
	IN		AL, DX
	MOVZX	EAX, AL
END InSet;

PROCEDURE -SaveResult-;
CODE
	PUSH EAX
	PUSH EDX
END SaveResult;

PROCEDURE -RestoreResultAndReturn-;
CODE
	POP EDX
	POP EAX
	LEA ESP, [EBP+4]
	POP EBP
	RET
END RestoreResultAndReturn;



PROCEDURE Mask- (port: SIZE; value: SET);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	OutSet (port, InSet (port) + value);
END Mask;

PROCEDURE Unmask- (port: SIZE; value: SET);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	OutSet (port, InSet (port) - value);
END Unmask;

(* interrupt handling *)
CONST Interrupts* = 48;
CONST IRQ0* = 32; IRQ1* = 33; IRQ2* = 34; IRQ3* = 35; IRQ4* = 36; IRQ5* = 37; IRQ6* = 38; IRQ7* = 39;
CONST IRQ8* = 40; IRQ9* = 41; IRQ10* = 42; IRQ11* = 43; IRQ12* = 44; IRQ13* = 45; IRQ14* = 46; IRQ15* = 47;

CONST PIC1CommandPort = 020H; PIC1DataPort = 021H; PIC2CommandPort = 0A0H; PIC2DataPort = 0A1H;
CONST ICW1_ICW4 = 001H; ICW1_INIT = 010H; ICW4_8086 = 001H; PIC_EOI = 020H; PIC_READ_ISR = 00AH;

TYPE InterruptHandler* = PROCEDURE (index: SIZE);

VAR handlers: ARRAY Interrupts OF InterruptHandler;

PROCEDURE InstallInterrupt- (handler: InterruptHandler; index: SIZE): InterruptHandler;
VAR previous: InterruptHandler;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (handler # NIL); ASSERT (index < Interrupts);
	REPEAT previous := CAS (handlers[index], NIL, NIL) UNTIL CAS (handlers[index], previous, handler) = previous;
	IF previous = NIL THEN EnableIRQ (index) END;
	RETURN previous;
END InstallInterrupt;

PROCEDURE HandleInterrupt (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CODE PUSHAD END;
	SYSTEM.SetActivity (NIL);

	IF handlers[index] # NIL THEN handlers[index] (index) ELSE HALT (1234) END;
	
	IF index >= IRQ8 THEN
		OutByte (PIC2CommandPort, PIC_EOI); OutByte (PIC1CommandPort, PIC_EOI);
	ELSIF index >= IRQ0 THEN
		OutByte (PIC1CommandPort, PIC_EOI);
	END;

	CODE POPAD END;
END HandleInterrupt;

PROCEDURE DisableInterrupt- (index: SIZE);
VAR previous: InterruptHandler;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (index < Interrupts);
	IF previous = NIL THEN DisableIRQ (index) END;
	REPEAT previous := CAS (handlers[index], NIL, NIL) UNTIL CAS (handlers[index], previous, NIL) = previous;
END DisableInterrupt;

PROCEDURE EnableIRQ- (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (index < Interrupts);
	IF (index >= IRQ0) & (index <= IRQ7) THEN Unmask (PIC1DataPort, {index - IRQ0}) END;
	IF (index >= IRQ8) & (index <= IRQ15) THEN Unmask (PIC2DataPort, {index - IRQ8}) END;
END EnableIRQ;

PROCEDURE DisableIRQ- (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (index < Interrupts);
	IF (index >= IRQ0) & (index <= IRQ7) THEN Mask (PIC1DataPort, {index - IRQ0}) END;
	IF (index >= IRQ8) & (index <= IRQ15) THEN Mask (PIC2DataPort, {index - IRQ8}) END;
END DisableIRQ;

VAR idt-: ARRAY Interrupts OF ARRAY 4 OF INTEGER;
VAR wrapper: ARRAY Interrupts OF ARRAY 16 OF CHAR;

PROCEDURE Initialize-;
CONST IRETD = 0CFX; PUSH = 06AX; CALL = 0E8X; ADD = 083X; ESP = 0C4X;
VAR i, c: SIZE; address: ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* ICW1: initialization *)
	OutByte (PIC1CommandPort, ICW1_INIT + ICW1_ICW4);
	OutByte (PIC2CommandPort, ICW1_INIT + ICW1_ICW4);

	(* ICW2: vector offsets *)
	OutByte (PIC1DataPort, IRQ0);
	OutByte (PIC2DataPort, IRQ8);

	(* ICW3: cascading *)
	OutByte (PIC1DataPort, 4);
	OutByte (PIC2DataPort, 2);

	(* ICW4: mode *)
	OutByte (PIC1DataPort, ICW4_8086);
	OutByte (PIC2DataPort, ICW4_8086);

	(* mask all maskable interrupts *)
	OutChar (PIC1DataPort, 0FBX);
	OutChar (PIC2DataPort, 0FFX);
	
	FOR i := 0 TO Interrupts - 1 DO
		IF (i # 9) & (i # 15) & ((i < 20) OR (i > 29)) & (i # 31) THEN
			idt[i][0] := INTEGER (ADDRESS OF wrapper[i] MOD 10000H);
			idt[i][1] := INTEGER(8H);
			idt[i][2] := INTEGER(8E00H);
			idt[i][3] := INTEGER(ADDRESS OF wrapper[i] DIV 10000H);

			c := 0;
			IF i # 2 THEN
				IF (i = 8) OR (i >= 10) & (i <= 14) OR (i = 17) THEN
					wrapper[i][c] := ADD; INC (c);
					wrapper[i][c] := ESP; INC (c);
					wrapper[i][c] := CHR (4); INC (c);
				END;
				wrapper[i][c] := PUSH; INC (c);
				wrapper[i][c] := CHR (i); INC (c);
				wrapper[i][c] := CALL; INC (c);
				address := ADDRESS OF HandleInterrupt - ADDRESS OF wrapper[i][c + 4];
				wrapper[i][c] := CHR (address DIV 1H); INC (c);
				wrapper[i][c] := CHR (address DIV 100H); INC (c);
				wrapper[i][c] := CHR (address DIV 10000H); INC (c);
				wrapper[i][c] := CHR (address DIV 1000000H); INC (c);
				wrapper[i][c] := ADD; INC (c);
				wrapper[i][c] := ESP; INC (c);
				wrapper[i][c] := CHR (4); INC (c);
			END;
			wrapper[i][c] := IRETD;
		ELSE
			idt[i][0] := 0;
			idt[i][1] := 0;
			idt[i][2] := 0;
			idt[i][3] := 0;
		END;
	END;
	
	CODE
		LEA	EAX, idt
		PUSH	EAX
		MOV	AX, Interrupts * 8
		PUSH	AX
		LIDT	[ESP]
		STI
	END;
END Initialize;

(* compiler intrinsic *)
PROCEDURE DivHA(l,r: HUGEINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	; divides two signed 64-bit numbers and delivers the quotient
	;
	; In: [EBP+20]:[EBP+16] = dividend (l)
	; [EBP+12]:[EBP+8] = divisor (r)
	; Out: EDX:EAX = quotient of division
	MOV EDX, [EBP+l+4] 	    ; dividend_hi
	MOV EAX, [EBP+l+0] 		; dividend_lo
	MOV ECX, [EBP+r+4] 	    ; divisor_hi
	MOV EBX, [EBP+r+0] 	    ; divisor_lo
	MOV ESI, ECX 			; divisor_hi
	XOR ESI, EDX 			; divisor_hi ^ dividend_hi
	SAR ESI, 31 				; (quotient < 0) ? -1 : 0
	MOV EDI, EDX 			; dividend_hi
	SAR EDI, 31 				; (dividend < 0) ? -1 : 0
	XOR EAX, EDI 			; If (dividend < 0),
	XOR EDX, EDI 			; compute 1's complement of dividend.
	SUB EAX, EDI 			; If (dividend < 0),
	SBB EDX, EDI 			; compute 2's complement of dividend.
	MOV EDI, ECX 			; divisor_hi
	SAR EDI, 31 				; (divisor < 0) ? -1 : 0
	XOR EBX, EDI 			; If (divisor < 0),
	XOR ECX, EDI 			; compute 1's complement of divisor.
	SUB EBX, EDI 			; If (divisor < 0),
	SBB ECX, EDI 			; compute 2's complement of divisor.
	JNZ BIGDIVISOR 			; divisor > 2^32 - 1
	CMP EDX, EBX 			; Only one division needed (ECX = 0)?
	JAE TWODIVS 			; Need two divisions.
	DIV EBX 				; EAX = quotient_lo
	MOV EDX, ECX 			; EDX = quotient_hi = 0 (quotient in EDX:EAX)
	XOR EAX, ESI 			; If (quotient < 0),
	XOR EDX, ESI 			; compute 1's complement of result.
	SUB EAX, ESI 			; If (quotient < 0),
	SBB EDX, ESI 			; compute 2's complement of result.
	JMP DONE
	TWODIVS:
	MOV ECX, EAX 			; Save dividend_lo in ECX.
	MOV EAX, EDX 			; Get dividend_hi.
	XOR EDX, EDX 			; Zero-extend it into EDX:EAX.
	DIV EBX 				; QUOtient_hi in EAX
	XCHG EAX, ECX 			; ECX = quotient_hi, EAX = dividend_lo
	DIV EBX 				; EAX = quotient_lo
	MOV EDX, ECX 			; EDX = quotient_hi (quotient in EDX:EAX)
	JMP MAKESIGN 		; Make quotient signed.
	BIGDIVISOR:
	SUB ESP, 12 			; Create three local variables.
	MOV [ESP], EAX 		; dividend_lo
	MOV [ESP+4], EBX 		; divisor_lo
	MOV [ESP+8], EDX 		; dividend_hi
	MOV EDI, ECX 			; Save divisor_hi.
	SHR EDX, 1 				; Shift both
	RCR EAX, 1 				; divisor and
	ROR EDI, 1 				; and dividend
	RCR EBX, 1 				; right by 1 bit.
	BSR ECX, ECX 			; ECX = number of remaining shifts
	SHRD EBX, EDI, CL 		; Scale down divisor and
	SHRD EAX, EDX, CL 		; dividend such that divisor is
	SHR EDX, CL 				; less than 2^32 (that is, fits in EBX).
	ROL EDI, 1 				; Restore original divisor_hi.
	DIV EBX 				; COMpute quotient.
	MOV EBX, [ESP] 		; dividend_lo
	MOV ECX, EAX 			; Save quotient.
	IMUL EDI, EAX 			; quotient * divisor high word (low only)
	MUL DWORD [ESP+4] ; quotient * divisor low word
	ADD EDX, EDI 			; EDX:EAX = quotient * divisor
	SUB EBX, EAX 			; dividend_lo - (quot.*divisor)_lo
	MOV EAX, ECX 			; Get quotient.
	MOV ECX, [ESP+8] 		; dividend_hi
	SBB ECX, EDX 			; Subtract (divisor * quot.) from dividend
	SBB EAX, 0 				; Adjust quotient if remainder is negative.
	XOR EDX, EDX 			; Clear high word of quotient.
	ADD ESP, 12 			; Remove local variables.
	MAKESIGN:
	XOR EAX, ESI 			; If (quotient < 0),
	XOR EDX, ESI 			; compute 1's complement of result.
	SUB EAX, ESI 			; If (quotient < 0),
	SBB EDX, ESI 			; compute 2's complement of result.
	DONE:
	POP	ECX
END DivHA;

PROCEDURE DivH*(l,r: HUGEINT): HUGEINT;
VAR result: HUGEINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF l > 0 THEN RETURN DivHA(l,r)
	ELSIF l< 0 THEN
		result :=  -DivHA(-l,r);
		IF result * r # l THEN DEC(result) END; (* mathematical definition of DIV and MOD, to be optimized in DivHA *)
		RETURN result
	ELSE RETURN 0
	END;
END DivH;

PROCEDURE MulH*(l,r: HUGEINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	; computes the low-order half of the product of its
	; arguments, two 64-bit integers.
	;
	; In: [EBP+12]:[EBP+8] = multiplicand (l)
	; [EBP+20]:[EBP+16] = multiplier (r)
	; Out: EDX:EAX = (multiplicand * multiplier) % 2^64
	; Destroys: EAX, ECX, EDX, EFlags
	MOV EDX, [EBP+l+4] 		; multiplicand_hi
	MOV ECX, [EBP+r+4] 		; multiplier_hi
	OR EDX,ECX 				; One operand >= 2^32?
	MOV EDX, [EBP+l+0] 		; multiplier_lo
	MOV EAX, [EBP+r+0] 		; multiplicand_lo
	JNZ twomul 				; Yes, need two multiplies.
	MUL EDX 					; multiplicand_lo * multiplier_lo
	JMP done 					; Done, return to caller.
	twomul:
	IMUL EDX, [EBP+l+4]		; p3_lo = multiplicand_hi * multiplier_lo
	IMUL ECX,EAX 			; p2_lo = multiplier_hi * multiplicand_lo
	ADD ECX, EDX 			; p2_lo + p3_lo
	MUL DWORD [EBP+r+0] 	; p1 = multiplicand_lo * multiplier_lo
	ADD EDX,ECX 			; p1 + p2_lo + p3_lo = result in EDX:EAX
	done:
	POP	ECX
END MulH;

PROCEDURE ModHA(l,r: HUGEINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	; DIVIDES TWO SIGNED 64-BIT NUMBERS AND RETURNS THE REMAINDER.
	;
	; IN: [EBP+20]:[EBP+16] = DIVIDEND (l)
	; [EBP+12]:[EBP+8] = DIVISOR (r)
	;
	; OUT: EDX:EAX = REMAINDER OF DIVISION
	;
	; DESTROYS: EAX, ECX, EDX, EFLAGS
	MOV EDX, [EBP+l+4]           	; DIVIDEND-HI
	MOV EAX, [EBP+l+0]            	; DIVIDEND-LO
	MOV ECX, [EBP+r+4]           	; DIVISOR-HI
	MOV EBX, [EBP+r+0]           	; DIVISOR-LO
	MOV ESI, EDX	                	; SIGN(REMAINDER) == SIGN(DIVIDEND)
	SAR ESI, 31 		               	; (REMAINDER < 0) ? -1 : 0
	MOV EDI, EDX	                	; DIVIDEND-HI
	SAR EDI, 31 	                	; (DIVIDEND < 0) ? -1 : 0
	XOR EAX, EDI	                	; IF (DIVIDEND < 0),
	XOR EDX, EDI	                	; COMPUTE 1'S COMPLEMENT OF DIVIDEND.
	SUB EAX, EDI	                	; IF (DIVIDEND < 0),
	SBB EDX, EDI	                	; COMPUTE 2'S COMPLEMENT OF DIVIDEND.
	MOV EDI, ECX	                	; DIVISOR-HI
	SAR EDI, 31 	                	; (DIVISOR < 0) ? -1 : 0
	XOR EBX, EDI	                	; IF (DIVISOR < 0),
	XOR ECX, EDI	                	; COMPUTE 1'S COMPLEMENT OF DIVISOR.
	SUB EBX, EDI	                	; IF (DIVISOR < 0),
	SBB ECX, EDI	                	; COMPUTE 2'S COMPLEMENT OF DIVISOR.
	JNZ SRBIGDIVISOR          	; DIVISOR > 2^32 - 1
	CMP EDX, EBX				; ONLY ONE DIVISION NEEDED (ECX = 0)?
	JAE SRTWODIVS             		; NO, NEED TWO DIVISIONS.
	DIV EBX      		               	; EAX = QUOTIENT_LO
	MOV EAX, EDX                	; EAX = REMAINDER_LO
	MOV EDX, ECX                	; EDX = REMAINDER_LO = 0
	XOR EAX, ESI                		; IF (REMAINDER < 0),
	XOR EDX, ESI                		; COMPUTE 1'S COMPLEMENT OF RESULT.
	SUB EAX, ESI                		; IF (REMAINDER < 0),
	SBB EDX, ESI                		; COMPUTE 2'S COMPLEMENT OF RESULT.
	JMP done                 			; DONE, RETURN TO CALLER.
	SRTWODIVS:
	MOV ECX, EAX                	; SAVE DIVIDEND_LO IN ECX.
	MOV EAX, EDX                	; GET DIVIDEND_HI.
	XOR EDX, EDX                	; ZERO-EXTEND IT INTO EDX:EAX.
	DIV EBX                     		; EAX = QUOTIENT_HI, EDX = INTERMEDIATE REMAINDER
	MOV EAX, ECX                	; EAX = DIVIDEND_LO
	DIV EBX                     		; EAX = QUOTIENT_LO
	MOV EAX, EDX                	; REMAINDER_LO
	XOR EDX, EDX                	; REMAINDER_HI = 0
	JMP SRMAKESIGN 			;MAKE REMAINDER SIGNED.
	SRBIGDIVISOR:
	SUB ESP, 16 			 	;CREATE THREE LOCAL VARIABLES.
	MOV [ESP], EAX 			; DIVIDEND_LO
	MOV [ESP+4], EBX 			; DIVISOR_LO
	MOV [ESP+8], EDX 			; DIVIDEND_HI
	MOV [ESP+12], ECX 			; DIVISOR_HI
	MOV EDI, ECX 				; SAVE DIVISOR_HI.
	SHR EDX, 1 					; SHIFT BOTH
	RCR EAX, 1 					; DIVISOR AND
	ROR EDI, 1 					; AND DIVIDEND
	RCR EBX, 1 					; RIGHT BY 1 BIT.
	BSR ECX, ECX 				; ECX = NUMBER OF REMAINING SHIFTS
	SHRD EBX, EDI, CL 			; SCALE DOWN DIVISOR AND
	SHRD EAX, EDX, CL 			; DIVIDEND SUCH THAT DIVISOR IS
	SHR EDX, CL 				; LESS THAN 2^32 (THAT IS, FITS IN EBX).
	ROL EDI, 1 					; RESTORE ORIGINAL DIVISOR_HI.
	DIV EBX 					; COMPUTE QUOTIENT.
	MOV EBX, [ESP] 			; DIVIDEND_LO
	MOV ECX, EAX 				; SAVE QUOTIENT.
	IMUL EDI, EAX 				; QUOTIENT * DIVISOR HIGH WORD (LOW ONLY)
	MUL DWORD [ESP+4] 		; QUOTIENT * DIVISOR LOW WORD
	ADD EDX, EDI 				; EDX:EAX = QUOTIENT * DIVISOR
	SUB EBX, EAX 				; DIVIDEND_LO - (QUOT.*DIVISOR)_LO
	MOV ECX, [ESP+8] 			; DIVIDEND_HI
	SBB ECX, EDX 				; SUBTRACT DIVISOR * QUOT. FROM DIVIDEND.
	SBB EAX, EAX 				; REMAINDER < 0 ? 0XFFFFFFFF : 0
	MOV EDX, [ESP+12] 		; DIVISOR_HI
	AND EDX, EAX 				; REMAINDER < 0 ? DIVISOR_HI : 0
	AND EAX, [ESP+4] 			; REMAINDER < 0 ? DIVISOR_LO : 0
	ADD EAX, EBX 				; REMAINDER_LO
	ADD EDX, ECX 				; REMAINDER_HI
	ADD ESP, 16 				; REMOVE LOCAL VARIABLES.
	SRMAKESIGN:
	XOR EAX, ESI 				; IF (REMAINDER < 0),
	XOR EDX, ESI 				; COMPUTE 1'S COMPLEMENT OF RESULT.
	SUB EAX, ESI 				; IF (REMAINDER < 0),
	SBB EDX, ESI 				; COMPUTE 2'S COMPLEMENT OF RESULT.
	done:
	POP	ECX
END ModHA;

PROCEDURE ModH*(l,r: HUGEINT): HUGEINT;
VAR res: HUGEINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	res := ModHA(l,r);
	IF res < 0 THEN INC(res,r) END;
	RETURN res
END ModH;

PROCEDURE AbsH*(l: HUGEINT): HUGEINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF l< 0 THEN RETURN -l ELSE RETURN l END;
END AbsH;

PROCEDURE AslH*(l: HUGEINT; r: LONGINT): HUGEINT; (*! coincides with Logic Shift, remove ? *)
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN LslH(l,r)
END AslH;

PROCEDURE LslH*(l: HUGEINT; r: LONGINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; Shift EDX:EAX left, shift count in ECX (count
	; applied modulo 64).
	SHLD EDX,EAX,CL		; First apply shift count.
	SHL EAX,CL 			; mod 32 to EDX:EAX
	TEST ECX,32 			; Need to shift by another 32?
	JZ lshiftdone 			; No, done.
	MOV EDX,EAX			; Left shift EDX:EAX
	XOR EAX,EAX 			; by 32 bits
	lshiftdone:
	POP	ECX
END LslH;

PROCEDURE AsrH*(l: HUGEINT; r: LONGINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; Shift EDX:EAX right, shift count in ECX (count
	; applied modulo 64).
	SHRD EAX,EDX,CL		; First apply shift count.
	SAR EDX,CL 			; mod 32 to EDX:EAX
	TEST ECX,32 			; Need to shift by another 32?
	JZ rshiftdone 			; No, done.
	MOV EAX,EDX			; Left shift EDX:EAX
	SAR EDX,31 			; by 32 bits (fill EDX with sign bits)
	rshiftdone:
	POP	ECX
END AsrH;

PROCEDURE LsrH*(l: HUGEINT; r: LONGINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; Shift EDX:EAX right, shift count in ECX (count
	; applied modulo 64).
	SHRD EAX,EDX,CL		; First apply shift count.
	SHR EDX,CL 			; mod 32 to EDX:EAX
	TEST ECX,32 			; Need to shift by another 32?
	JZ rshiftdone 			; No, done.
	MOV EAX,EDX			; Left shift EDX:EAX
	XOR EDX,EDX 			; by 32 bits (clear EDX)
	rshiftdone:
	POP	ECX
END LsrH;

PROCEDURE RorH*(l: HUGEINT; r: LONGINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; EBX (initially=EAX) -> EDX -> EAX
	; Shift EDX:EAX right, shift count in ECX (count
	; applied modulo 64).
	MOV EBX,EAX
	SHRD EAX,EDX,CL		; First apply shift count.
	SHRD EDX,EBX,CL 		; mod 32 to EDX:EAX
	TEST ECX,32 			; Need to shift by another 32?
	JZ rshiftdone 			; No, done.
	MOV EBX,EAX
	SHRD EAX,EDX,CL
	SHRD EDX,EBX,CL
	rshiftdone:
	POP	ECX
END RorH;

PROCEDURE RolH*(l: HUGEINT; r: LONGINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; EDX <- EAX <- EBX (intially=EDX)
	; Shift EDX:EAX left, shift count in ECX (count
	; applied modulo 64).
	MOV EBX,EDX
	SHLD EDX,EAX,CL		; First apply shift count.
	SHLD EAX, EBX, CL
	TEST ECX,32 			; Need to shift by another 32?
	JZ lshiftdone 			; No, done.
	MOV EBX,EDX
	SHLD EDX,EAX,CL
	SHLD EAX, EBX, CL
	lshiftdone:
	POP	ECX
END RolH;

PROCEDURE CasH*(VAR value: HUGEINT; old, new: HUGEINT): HUGEINT;
CODE{SYSTEM.Pentium}
	PUSH	ECX
	MOV	EAX, [EBP + old + 0]
	MOV	EDX, [EBP + old + 4]
	MOV	EBX, [EBP + new + 0]
	MOV	ECX, [EBP + new + 4]
	MOV	EDI, [EBP + value]
	LOCK CMPXCHG8B [EDI]
	POP	ECX
END CasH;

PROCEDURE EntierXH*(x: LONGREAL): HUGEINT;
CODE
	FLD	QWORD [EBP+x]
	SUB	ESP, 12
	FNSTCW	[ESP]
	FWAIT
	MOV	ESI, [ESP]
	AND	ESI, 0000F3FFH
	OR	ESI, 00000400H
	MOV	[ESP+4], ESI
	FLDCW	[ESP+4]
	FISTP	QWORD [ESP+4]
	FWAIT
	FLDCW	[ESP]
	POP	EDI
	POP	EAX
	POP	EDX
END EntierXH;

PROCEDURE EntierRH*(x: REAL): HUGEINT;
CODE
	FLD DWORD [EBP+x]
	SUB	ESP, 12
	FNSTCW	[ESP]
	FWAIT
	MOV	ESI, [ESP]
	AND	ESI, 0000F3FFH
	OR	ESI, 00000400H
	MOV	[ESP+4], ESI
	FLDCW	[ESP+4]
	FISTP	QWORD [ESP+4]
	FWAIT
	FLDCW	[ESP]
	POP	EDI
	POP	EAX
	POP	EDX
END EntierRH;

END CPU.