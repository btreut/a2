MODULE ARMRuntime;
IMPORT SYSTEM, FPE64;

CONST
	B = 127;
	C = 800000H;
	E = 100H;
	S = LONGINT(80000000H); (* used by VFP unit emulation *)
	MAXREAL = LONGINT(7F7FFFFFH);

TYPE
	ULONGINT = LONGINT; (* alias to make distinction between signed and unsigned more clear *)
	UHUGEINT = HUGEINT;
	FLOAT32 = LONGINT; (* alias to make clear that the integer actually contains a IEEE 32 bit float *)
	FLOAT64= HUGEINT;

	PROCEDURE DivS8*(left, right: SHORTINT): SHORTINT;
	VAR result, dummy: LONGINT;
	BEGIN	 DivModS32(left, right, result, dummy); RETURN SHORTINT(result)
	END DivS8;

	PROCEDURE DivS16*(left, right: INTEGER): INTEGER;
	VAR result, dummy: LONGINT;
	BEGIN	 DivModS32(left, right, result, dummy); RETURN INTEGER(result)
	END DivS16;

	PROCEDURE DivS32*(left, right: LONGINT): LONGINT;
	VAR result, dummy: LONGINT;
	BEGIN	 DivModS32(left, right, result, dummy); RETURN result
	END DivS32;

	PROCEDURE DivU32*(left, right: ULONGINT): ULONGINT;
	VAR result, dummy: LONGINT;
	BEGIN DivModU32(left, right, result, dummy); RETURN result
	END DivU32;

	PROCEDURE DivS64*(left, right: HUGEINT): HUGEINT;
	VAR result, dummy: HUGEINT;
	BEGIN
		DivModS64(left, right, result, dummy); RETURN result
	END DivS64;

	PROCEDURE ModS8*(left, right: SHORTINT): SHORTINT;
	VAR result, dummy: LONGINT;
	BEGIN DivModS32(left, right, dummy, result); RETURN SHORTINT(result)
	END ModS8;

	PROCEDURE ModS16*(left, right: INTEGER): INTEGER;
	VAR result, dummy: LONGINT;
	BEGIN DivModS32(left, right, dummy, result); RETURN INTEGER(result)
	END ModS16;

	PROCEDURE ModS32*(left, right: LONGINT): LONGINT;
	VAR result, dummy: LONGINT;
	BEGIN DivModS32(left, right, dummy, result); RETURN result
	END ModS32;

	PROCEDURE ModU32*(left, right: ULONGINT): ULONGINT;
	VAR result, dummy: LONGINT;
	BEGIN DivModU32(left, right, dummy, result); RETURN result
	END ModU32;

	PROCEDURE ModS64*(left, right: HUGEINT): HUGEINT;
	VAR result, dummy: HUGEINT;
	BEGIN
			DivModS64(left, right, dummy, result); RETURN result
	END ModS64;

	PROCEDURE RolS64*(source: HUGEINT; amount: ULONGINT): HUGEINT;
	CODE
		LDR R2, [FP, #+8] ; R2 := amount
		LDR R3, [FP, #+12] ; R3 := source[Low]
		LDR R4, [FP, #+16] ; R4 := source[High]

		; source = R4:R3

		AND R2, R2, #3FH ; R2 := R2 MOD 64

		CMP R2, #32

		; IF R2 < 32:
		MOVLT R0, R3, LSL R2
		MOVLT R1, R4, LSL R2
		RSBLT R2, R2, #32 ; R2 := 32 - R2
		ORRLT R0, R0, R4, LSR R2
		ORRLT R1, R1, R3, LSR R2

		; IF R2 >= 32:
		SUBGE R2, R2, #32 ; R2 := R2 - 32
		MOVGE R0, R4, LSL R2
		MOVGE R1, R3, LSL R2
		RSBGE R2, R2, #32 ; R2 := 32 - R2
		ORRGE R0, R0, R3, LSR R2
		ORRGE R1, R1, R4, LSR R2

		; result = R1:R0
	END RolS64;

	PROCEDURE RolU64*(source: HUGEINT; amount: ULONGINT): HUGEINT;
	BEGIN RETURN RolS64(source, amount)
	END RolU64;

	PROCEDURE RorS64*(source: HUGEINT; amount: ULONGINT): HUGEINT;
	BEGIN RETURN RolS64(source, 64 - (amount MOD 64))
	END RorS64;
	
	PROCEDURE RorU64*(source: HUGEINT; amount: ULONGINT): HUGEINT;
	BEGIN RETURN RolS64(source, 64 - (amount MOD 64))
	END RorU64;

	(* signed division and modulus
	- note: this implements the mathematical definition of DIV and MOD in contrast to the symmetric one
	*)
	PROCEDURE DivModS32(dividend, divisor: LONGINT; VAR quotient, remainder: LONGINT);
	BEGIN
		ASSERT(divisor > 0);
		IF dividend >= 0 THEN
			DivModU32(dividend, divisor, quotient, remainder)
		ELSE
			dividend := -dividend;
			DivModU32(dividend, divisor, quotient, remainder);
			quotient := -quotient;
			IF remainder # 0 THEN
				DEC(quotient);
				remainder := divisor - remainder
			END
		END
	END DivModS32;

	(*
		Fast 32-bit unsigned integer division/modulo (author Alexey Morozov)
	*)
	PROCEDURE DivModU32*(dividend, divisor: ULONGINT; VAR quotient, remainder: ULONGINT);
	CODE
		MOV R2, #0 ; quotient will be stored in R2

		LDR R0, [FP,#dividend] ; R0 := dividend
		LDR R1, [FP,#divisor] ; R1 := divisor

		; check for the case dividend < divisor
		CMP R0, R1
		BEQ Equal
		BLS Exit ; nothing to do than setting quotient to 0 and remainder to dividend (R0)
	
		CLZ R3, R0 ; R3 := clz(dividend)
		CLZ R4, R1 ; R4 := clz(divisor)

		SUB R3, R4, R3 ; R2 := clz(divisor) - clz(dividend) , R2 >= 0
		LSL R1, R1, R3 ; scale divisor: divisor := LSH(divisor,clz(divisor)-clz(dividend))

	Loop:
		CMP R0, R1
		ADC R2, R2, R2
		SUBCS R0, R0, R1
		LSR R1, R1, #1
		SUBS R3, R3, #1
		BPL Loop

		; R0 holds the remainder
		
		B Exit
		
	Equal:
		MOV R2, #1
		MOV R0, #0
		
	Exit:
		LDR R1, [FP,#quotient] ; R1 := address of quotient
		LDR R3, [FP,#remainder] ; R3 := address of remainder

		STR R2, [R1,#0] ; quotient := R2
		STR R0, [R3,#0] ; remainder := R0
	END DivModU32;

	(**
		Signed 64-bit multiplication. Adapted version based on the original code
		from "Runtime ABI for the ARM Cortex-M0" (https://github.com/bobbl/libaeabi-cortexm0/blob/master/lmul.S)

		/* Runtime ABI for the ARM Cortex-M0
		 * lmul.S: 64 bit multiplication
		 *
		 * Copyright (c) 2013 Jörg Mische <bobbl@gmx.de>
		 *
		 * Permission to use, copy, modify, and/or distribute this software for any
		 * purpose with or without fee is hereby granted, provided that the above
		 * copyright notice and this permission notice appear in all copies.
		 *
		 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
		 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
		 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
		 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
		 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
		 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
		 * OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
		 */

		Multiply r1:r0 and r3:r2 and return the product in r1:r0
		Can also be used for unsigned long product
	*)
	PROCEDURE MulS64*(x, y: HUGEINT): HUGEINT;
	CODE
		ldr r0, [FP,#x]
		ldr r1, [FP,#x+4]

		ldr r2, [FP,#y]
		ldr r3, [FP,#y+4]

		muls	r1, r1, r2
		muls	r3, r3, r0
		adds	r1, r1, r3

		lsrs	r3, r0, #16
		lsrs	r4, r2, #16
		muls	r3, r3, r4
		adds	r1, r1, r3

		lsrs	r3, r0, #16
		uxth	r0, r0
		uxth	r2, r2
		muls	r3, r3, r2
		muls	r4, r4, r0
		muls	r0, r0, r2

		movs	r2, #0
		adds	r3, r3, r4
		adcs	r2, r2, r2
		lsls	r2, r2, #16
		adds	r1, r1, r2

		lsls	r2, r3, #16
		lsrs	r3, r3, #16
		adds	r0, r0, r2
		adcs	r1, r1, r3

	END MulS64;

	(* signed division and modulus
	- note: this implements the mathematical definition of DIV and MOD in contrast to the symmetric one
	*)
	PROCEDURE DivModS64*(dividend, divisor: HUGEINT; VAR quotient, remainder: HUGEINT);
	BEGIN
		ASSERT(divisor > 0);
		IF dividend >= 0 THEN
			DivModU64(dividend, divisor, quotient, remainder)
		ELSE
			dividend := -dividend;
			DivModU64(dividend, divisor, quotient, remainder);
			quotient := -quotient;
			IF remainder # 0 THEN
				DEC(quotient);
				remainder := divisor - remainder
			END
		END
	END DivModS64;

	(* Count leading zeros in a binary representation of a given 64-bit integer number *)
	PROCEDURE Clz64*(x: UHUGEINT): LONGINT;
	CODE
		; high-half
		LDR R1, [FP,#x+4]
		CMP R1, #0 ; if high-half is zero count leading zeros of the low-half
		BEQ LowHalf

		CLZ R0, R1
		B Exit

		; low-half
	LowHalf:
		LDR R1, [FP,#x]
		CLZ R0, R1
		ADD R0, R0, #32 ; add 32 zeros from the high-half

	Exit:
	END Clz64;

	(*
		Fast 64-bit unsigned integer division/modulo (Alexey Morozov)
	*)
	PROCEDURE DivModU64*(dividend, divisor: UHUGEINT; VAR quotient, remainder: UHUGEINT);
	VAR m: LONGINT;
	BEGIN
		quotient := 0;

		IF dividend = 0 THEN remainder := 0; RETURN; END;
		IF dividend < divisor THEN remainder := dividend; RETURN; END;

		m := Clz64(divisor) - Clz64(dividend);
		ASSERT(m >= 0);

		divisor := LSH(divisor,m);
		WHILE m >= 0 DO
			quotient := LSH(quotient,1);
			IF dividend >= divisor THEN
				INC(quotient);
				DEC(dividend,divisor);
			END;
			divisor := LSH(divisor,-1);
			DEC(m);
		END;

		remainder := dividend;
	(*
	CODE

		ldr r0, [FP,#dividend]
		ldr r1, [FP,#dividend+4]

		ldr r2, [FP,#divisor]
		ldr r3, [FP,#divisor+4]




		ldr r5, [FP,#quotient]
		ldr r6, [FP,#remainder]

		str r0, [r5,#0]
		str r1, [r5,#4]

		str r2, [r6,#0]
		str r3, [r6,#4]
	*)
	END DivModU64;

	PROCEDURE NegF32*(float: FLOAT32): FLOAT32;
	CODE
		LDR R0, [FP, #+float] ; R0 := float
		EOR R0, R0, #S ; invert only the sign bit
	END NegF32;

	PROCEDURE AbsF32*(float: FLOAT32): FLOAT32;
	CODE
		LDR R0, [FP, #+float] ; R0 := float
		BIC R0, R0, #S ; clear the sign bit
	END AbsF32;

	PROCEDURE AddF32*(x, y: FLOAT32): FLOAT32;
	VAR xe, ye, s: LONGINT;
	BEGIN
		IF SYSTEM.NULL(x) = TRUE THEN x := y
		ELSIF SYSTEM.NULL(y) = FALSE THEN
			xe := x DIV C MOD E; (* exponent with bias *)
			IF x >= 0 THEN x := (x MOD C + C)*2 ELSE x := -(x MOD C + C)*2 END ;
			ye := y DIV C MOD E; (* exponent with bias *)
			IF y >= 0 THEN y := (y MOD C + C)*2 ELSE y := -(y MOD C + C)*2 END ;
			IF xe < ye THEN
				ye := ye - xe; xe := xe + ye; (*denorm x*)
				IF ye <= 25 THEN x := ASH(x, -ye) ELSE x := 0 END
			ELSIF ye < xe THEN
				ye := xe - ye;  (*denorm y*)
				IF ye <= 25 THEN y := ASH(y, -ye) ELSE y := 0 END
			END ;
			s := x + y; x := ABS(s);
			s := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, s)*{31});
			IF x # 0 THEN
				IF x >= 4*C THEN x := (x+2) DIV 4; INC(xe)
				ELSIF x >= 2*C THEN x := (x+1) DIV 2
				ELSE DEC(xe);
					WHILE x < C DO x := 2*x; DEC(xe) END
				END ;
				IF xe < 0 THEN x := 0  (*underflow*)
				ELSIF xe > 0FEH THEN x := MAXREAL + s; (* overflow *)
				ELSE x := xe*C + (x - C) + s;
				END;
			END
		END ;
		RETURN x
	END AddF32;
	
	PROCEDURE AddF64*(x,y: FLOAT64): FLOAT64;
	VAR z: FLOAT64;
	BEGIN FPE64.Add(SYSTEM.VAL(FPE64.Float64,x),SYSTEM.VAL(FPE64.Float64,y),SYSTEM.VAL(FPE64.Float64,z)); RETURN z
	END AddF64;

	PROCEDURE MulF64*(x,y: FLOAT64): FLOAT64;
	VAR z: FLOAT64;
	BEGIN FPE64.Mul(SYSTEM.VAL(FPE64.Float64,x),SYSTEM.VAL(FPE64.Float64,y),SYSTEM.VAL(FPE64.Float64,z)); RETURN z
	END MulF64;

	PROCEDURE DivF64*(x,y: FLOAT64): FLOAT64;
	VAR z: FLOAT64;
	BEGIN FPE64.Div(SYSTEM.VAL(FPE64.Float64,x),SYSTEM.VAL(FPE64.Float64,y),SYSTEM.VAL(FPE64.Float64,z)); RETURN z
	END DivF64;

	PROCEDURE SubF64*(x,y: FLOAT64): FLOAT64;
	VAR z: FLOAT64;
	BEGIN FPE64.Sub(SYSTEM.VAL(FPE64.Float64,x),SYSTEM.VAL(FPE64.Float64,y),SYSTEM.VAL(FPE64.Float64,z)); RETURN z
	END SubF64;

	PROCEDURE AbsF64*(x: FLOAT64): FLOAT64;
	VAR z: FLOAT64;
	BEGIN FPE64.Abs(SYSTEM.VAL(FPE64.Float64,x),SYSTEM.VAL(FPE64.Float64,z)); RETURN z
	END AbsF64;

	PROCEDURE NegF64*(x: FLOAT64): FLOAT64;
	VAR z: FLOAT64;
	BEGIN FPE64.Neg(SYSTEM.VAL(FPE64.Float64,x),SYSTEM.VAL(FPE64.Float64,z)); RETURN z
	END NegF64;

	PROCEDURE ConvS32F64*(x: FLOAT64): LONGINT;
	BEGIN RETURN FPE64.Fix(SYSTEM.VAL(FPE64.Float64,x))
	END ConvS32F64;

	PROCEDURE ConvS64F64*(x: FLOAT64): HUGEINT;
	BEGIN RETURN FPE64.FixInt64(SYSTEM.VAL(FPE64.Float64,x))
	END ConvS64F64;

	PROCEDURE ConvF32F64*(x: FLOAT64): FLOAT32;
	BEGIN RETURN SYSTEM.VAL(FLOAT32, FPE64.Single(SYSTEM.VAL(FPE64.Float64,x)))
	END ConvF32F64;

	PROCEDURE ConvF64F32*(x: REAL): FLOAT64;
	VAR z: FLOAT64;
	BEGIN FPE64.Double(x,SYSTEM.VAL(FPE64.Float64,z)); RETURN z
	END ConvF64F32;

	PROCEDURE ConvF64S64*(x: HUGEINT): FLOAT64;
	VAR flt: FLOAT64;
	BEGIN
		FPE64.FloatInt64(x, SYSTEM.VAL(FPE64.Float64, flt)); RETURN flt
	END ConvF64S64;

	PROCEDURE ConvF64S32*(x: LONGINT): FLOAT64;
	VAR flt: FLOAT64;
	BEGIN FPE64.Float(x, SYSTEM.VAL(FPE64.Float64,flt)); RETURN flt
	END ConvF64S32;

	PROCEDURE ConvF64S16*(x: INTEGER): FLOAT64;
	VAR flt: FLOAT64;
	BEGIN FPE64.Float(x, SYSTEM.VAL(FPE64.Float64,flt)); RETURN flt
	END ConvF64S16;

	PROCEDURE ConvF32S16*(x: INTEGER): REAL;
	BEGIN
		RETURN ConvF32S32(LONGINT(x))
	END ConvF32S16;
	
	PROCEDURE ConvF32S8*(x: SHORTINT): REAL;
	BEGIN
		RETURN ConvF32S16(INTEGER(x))
	END ConvF32S8;
	
	PROCEDURE ConvF64S8*(x: SHORTINT): FLOAT64;
	BEGIN
		RETURN ConvF64S16(INTEGER(x))
	END ConvF64S8;

	PROCEDURE SubF32*(left, right: FLOAT32): FLOAT32;
	BEGIN RETURN AddF32(left, NegF32(right))
	END SubF32;

	PROCEDURE MulF32*(x, y: FLOAT32): FLOAT32;
	VAR xe, zh, ye, s: LONGINT;  (*zh, ye in this order; ye used as zh in MULD*)
	BEGIN
		IF SYSTEM.NULL(y) = TRUE THEN x := 0
		ELSIF SYSTEM.NULL(y) = FALSE THEN
			s := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.XOR(x, y))*{31});
			xe := x DIV C MOD E; (* exponent with bias *)
			ye := y DIV C MOD E; (* exponent with bias *)
			x := (x MOD C + C) * 20H;
			y := (y MOD C + C) * 20H;
			xe := xe + ye - B; (* exponent with bias *)
			
			SYSTEM.MULD(ye, x, y); (* note that this implicitly changes zh *)
			
			IF zh >= 4*C THEN
				x := (zh+2) DIV 4;
				INC(xe);
			ELSE
				x := (zh+1) DIV 2;
			END;
			IF xe < 0 THEN (* underflow *)
				x := 0;
			ELSIF xe > 0FEH THEN (* overflow *)
				x := MAXREAL + s;
			ELSE
				x := xe*C + (x-C) + s;
			END;
		END ;
		RETURN x
	END MulF32;
	
	PROCEDURE DivF32*(x, y: FLOAT32): FLOAT32;
	VAR xe, ye, q, s: LONGINT;
	BEGIN
		s := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.XOR(x, y))*{31});
		IF SYSTEM.NULL(y) = TRUE THEN
			x := MAXREAL + s;
		ELSIF SYSTEM.NULL(x) = FALSE THEN
			xe := x DIV C MOD E; (* exponent with bias *)
			ye := y DIV C MOD E; (* exponent with bias *)
			x := x MOD C + C;
			y := y MOD C + C;
			xe := xe - ye + B; (* exponent with bias *)
			IF x < y THEN
				x := x*2; DEC(xe);
			END ;
			IF xe < 0 THEN (* underflow *)
				x := 0;
			ELSIF xe > 0FEH THEN (* overflow *)
				x := MAXREAL + s;
			ELSE (* divide *)
				q := 0;
				WHILE q < LONGINT(1000000H) DO (* 2*C *)
					q := 2*q;
					IF x >= y THEN
						x := x - y;
						INC(q);
					END;
					x := 2*x;
				END;
				q := (q+1) DIV 2;  (*round*)
				x := xe*C + (q-C) + s;
			END;
		END;
		RETURN x
	END DivF32;

	(** converts a float into an integer, ignores the fractional part
	- corresponds to ENTIER(x) **)
	PROCEDURE ConvS32F32*(x: FLOAT32): LONGINT;
	VAR xe, s: LONGINT;
	BEGIN
		IF SYSTEM.NULL(x) = TRUE THEN
			x := 0
		ELSE
			s := x; xe := x DIV C MOD E - B; x := x MOD C + C;
			IF s < 0 THEN x := -x END ;
			IF xe < 24 THEN x := ASH(x, xe - 23)
			ELSIF xe < 31 THEN x := LSH(x, xe - 23)
			ELSIF s < 0 THEN x := LONGINT(80000000H);
			ELSE x := LONGINT(7FFFFFFFH);
			END;
		END ;
		RETURN x
	END ConvS32F32;
	
	(** converts an integer into a float, ignores the non-integer part
	- corresponds to REAL(int)
	- note that no rounding occurs
	**)
	PROCEDURE ConvF32S32*(x: LONGINT): FLOAT32;
	VAR xe, s: LONGINT;
	BEGIN
		IF x = LONGINT(80000000H) THEN (* ABS cannot handle the most negative LONGINT number! *)
			x := LONGINT(0CF000000H);
		ELSIF x # 0 THEN
			s := x;
			x := ABS(x); xe := 23;
			WHILE x >= 2*C DO
				x := x DIV 2; INC(xe);
			END;
			WHILE x < C DO
				x := 2*x; DEC(xe);
			END;
			x := (xe + B)*C - C + x;
			IF s < 0 THEN x := x+S END
		END ;
		RETURN x
	END ConvF32S32;

	PROCEDURE ConvF32S64*(x: HUGEINT): FLOAT32;
	BEGIN
		RETURN ConvF32F64(ConvF64S64(x))
	END ConvF32S64;

	(* ---- STRING OPERATIONS ---- *)

	(** compare two strings
	- returns 0 if both strings are lexicographically equal
	- returns +1 if 'left' is lexicographically greater than 'right'
	- returns -1 if 'left' is lexicographically less than 'right'
	**)
	PROCEDURE CompareString*(CONST left, right: ARRAY OF CHAR): SHORTINT;
	VAR
		result: SHORTINT;
		i: LONGINT;
		leftChar, rightChar: CHAR;
	BEGIN
		result := 0;
		i := 0;
		REPEAT
			leftChar := left[i]; rightChar := right[i];
			IF leftChar < rightChar THEN result := -1
			ELSIF leftChar > rightChar THEN result := +1
			END;
			INC(i)
		UNTIL (result # 0) OR (leftChar = 0X) OR (rightChar = 0X);
		RETURN result
	END CompareString;

	(** copy a string from 'source' to 'destination'
	- note that PACO semantics are used **)
	PROCEDURE CopyString*(VAR destination: ARRAY OF CHAR; CONST source: ARRAY OF CHAR);
	VAR
		sourceLength, destinationLength: LONGINT;
	BEGIN
		destinationLength := LEN(destination);
		sourceLength := LEN(source);
		IF destinationLength < sourceLength THEN sourceLength := destinationLength END;
		SYSTEM.MOVE(ADDRESSOF(source[0]), ADDRESSOF(destination[0]), sourceLength)
	END CopyString;

END ARMRuntime.