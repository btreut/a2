MODULE Runtime; (** AUTHOR "fof"; PURPOSE "runtime support for the Active Obero compiler"; *)
IMPORT SYSTEM;

VAR
	kernelModule-: ARRAY 32 OF ADDRESS;
	modules-: LONGINT;

PROCEDURE InsertModule*(a: ADDRESS): BOOLEAN;
BEGIN {UNCOOPERATIVE}
	kernelModule[modules] := a;
	INC(modules);
	RETURN TRUE
END InsertModule;


PROCEDURE DivHA(l,r: HUGEINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	; divides two signed 64-bit numbers and delivers the quotient
	;
	; In: [EBP+20]:[EBP+16] = dividend (l)
	; [EBP+12]:[EBP+8] = divisor (r)
	; Out: EDX:EAX = quotient of division
	MOV EDX, [EBP+20] 	    ; dividend_hi
	MOV EAX, [EBP+16] 		; dividend_lo
	MOV ECX, [EBP+12] 	    ; divisor_hi
	MOV EBX, [EBP+8] 	    ; divisor_lo
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
BEGIN {UNCOOPERATIVE}
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
	; In: [EBP+20]:[EBP+16] = multiplicand (l)
	; [EBP+12]:[EBP+8] = multiplier (r)
	; Out: EDX:EAX = (multiplicand * multiplier) % 2^64
	; Destroys: EAX, ECX, EDX, EFlags
	MOV EDX, [EBP+12] 		; multiplicand_hi
	MOV ECX, [EBP+20] 		; multiplier_hi
	OR EDX,ECX 				; One operand >= 2^32?
	MOV EDX, [EBP+16] 		; multiplier_lo
	MOV EAX, [EBP+8] 		; multiplicand_lo
	JNZ twomul 				; Yes, need two multiplies.
	MUL EDX 					; multiplicand_lo * multiplier_lo
	JMP done 					; Done, return to caller.
	twomul:
	IMUL EDX, [EBP+12]		; p3_lo = multiplicand_hi * multiplier_lo
	IMUL ECX,EAX 			; p2_lo = multiplier_hi * multiplicand_lo
	ADD ECX, EDX 			; p2_lo + p3_lo
	MUL DWORD [EBP+16] 	; p1 = multiplicand_lo * multiplier_lo
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
	; IN: [EBP+20]:[EBP+16] = DIVIDEND
	; [EBP+12]:[EBP+8] = DIVISOR
	;
	; OUT: EDX:EAX = REMAINDER OF DIVISION
	;
	; DESTROYS: EAX, ECX, EDX, EFLAGS
	MOV EDX, [EBP+20]           	; DIVIDEND-HI
	MOV EAX, [EBP+16]            	; DIVIDEND-LO
	MOV ECX, [EBP+12]           	; DIVISOR-HI
	MOV EBX, [EBP+8]           	; DIVISOR-LO
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
BEGIN {UNCOOPERATIVE}
	res := ModHA(l,r);
	IF res < 0 THEN INC(res,r) END;
	RETURN res
END ModH;

PROCEDURE AbsH*(l: HUGEINT): HUGEINT;
BEGIN {UNCOOPERATIVE}
	IF l< 0 THEN RETURN -l ELSE RETURN l END;
END AbsH;

PROCEDURE AslH*(l: HUGEINT; r: LONGINT): HUGEINT; (*! coincides with Logic Shift, remove ? *)
BEGIN {UNCOOPERATIVE}
	RETURN LslH(l,r)
END AslH;

PROCEDURE LslH*(l: HUGEINT; r: LONGINT): HUGEINT;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+8]
	MOV EAX,[EBP+12]
	MOV EDX,[EBP+16]
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
	MOV ECX,[EBP+8]
	MOV EAX,[EBP+12]
	MOV EDX,[EBP+16]
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
	MOV ECX,[EBP+8]
	MOV EAX,[EBP+12]
	MOV EDX,[EBP+16]
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
	MOV ECX,[EBP+8]
	MOV EAX,[EBP+12]
	MOV EDX,[EBP+16]
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
	MOV ECX,[EBP+8]
	MOV EAX,[EBP+12]
	MOV EDX,[EBP+16]
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




(* compare strings,
	returns 0 if strings are equal,
	returns +1 if left is lexicographic greater than right,
	returns -1 if left is lexicographics smaller than right
	traps if src or destination is not 0X terminated and comparison is not finished
*)
PROCEDURE CompareString*(CONST left,right: ARRAY OF CHAR): SHORTINT;
VAR i: LONGINT; res: SHORTINT; l,r: CHAR;
BEGIN {UNCOOPERATIVE}
	i := 0; res := 0;
	LOOP
		l := left[i]; 		(* index check included *)
		r := right[i];		(* index check included *)
		IF (res = 0) THEN
			IF (l > r) THEN
				res := 1; EXIT
			ELSIF (l<r) THEN
				res := -1; EXIT
			ELSIF l=0X THEN
				EXIT
			END;
		END;
		INC(i);
	END;
	RETURN res
END CompareString;

(* copy string from src to dest, emits trap if not 0X terminated or destination too short *)
PROCEDURE CopyString*(VAR dest: ARRAY OF CHAR; CONST src: ARRAY OF CHAR);
VAR i: LONGINT; ch :CHAR; l1,l2: LONGINT;
BEGIN {UNCOOPERATIVE}
	(*
	i := 0;
	REPEAT
		ch := src[i];		(* index check included *)
		dest[i] := ch;	(* index check included *)
		INC(i);
	UNTIL ch=0X;
	*)

	(*! currently implemented: old PACO semantics *)
	l1 := LEN(dest);
	l2 := LEN(src);
	IF l2 < l1 THEN l1 := l2 END;
	SYSTEM.MOVE(ADDRESSOF(src[0]),ADDRESSOF(dest[0]),l1);
	dest[l1-1] := 0X; (* this implies that COPY assumes a string *)
END CopyString;

PROCEDURE EnsureAllocatedStack*(size: SIZE);
VAR i: ADDRESS; temp: ADDRESS;
BEGIN {UNCOOPERATIVE}
	FOR i := 0 TO size BY 4096 DO
		SYSTEM.GET(ADDRESSOF(i)-i,temp);
		(*
		SYSTEM.PUT(ADDRESSOF(val)-i,0);
		*)
	END;
(*
CODE{SYSTEM.i386}
	MOV EAX, [EBP+size]
	SHR EAX,12 ; divide by 4096
	MOV ECX,-4
start:
	MOV EDX,[EBP+ECX]
	SUB ECX,4096
	TST EAX
	DEC EAX
	JNZ start
*)
END EnsureAllocatedStack;


BEGIN
	(*! assumed that modules = 0, implicit call of InsertModule *)
END Runtime.


Runtime.Obw