MODULE FPE64;

	IMPORT SYSTEM;

	CONST
		B = 1023; M = 40000000H; C = 100000H; E = 800H; K = 400H;

	TYPE
		Float64* = RECORD
			low*, high*: LONGINT
		END;

	PROCEDURE Addd(VAR x1, x0: LONGINT; y1, y0: LONGINT);
	CODE
		LDR R2, [FP, #+x1]; R2 := address of x1
		LDR R3, [FP, #+x0]; R3 := address of x0
		LDR R0, [FP, #+y1]; R0 := y1
		LDR R1, [FP, #+y0]; R1 := y0

		LDR R4, [R2, #+0]; R4 := value of x1
		LDR R5, [R3, #+0]; R5 := value of x0
		ADDS R5, R5, R1;
		ADCS R4, R4, R0;
		STR R5, [R3, #+0]; store new value at x0
		STR R4, [R2, #+0]; store new value at x1
	END Addd;

	PROCEDURE Subd(VAR x1, x0: LONGINT; y1, y0: LONGINT);
	CODE
		LDR R2, [FP, #+x1]; R2 := address of x1
		LDR R3, [FP, #+x0]; R3 := address of x0
		LDR R0, [FP, #+y1]; R0 := y1
		LDR R1, [FP, #+y0]; R1 := y0

		LDR R4, [R2, #+0]; R4 := value of x1
		LDR R5, [R3, #+0]; R5 := value of x0
		SUBS R5, R5, R1;
		SBCS R4, R4, R0;
		STR R5, [R3, #+0]; store new value at x0
		STR R4, [R2, #+0]; store new value at x1
	END Subd;

	PROCEDURE Muld(x0, y0: LONGINT; VAR z1, z0: LONGINT);
	CODE
		LDR R2, [FP, #+z0]; R2 := address of resultLow
		LDR R3, [FP, #+z1]; R3: = address of resultHigh
		LDR R4, [FP, #+x0] ; R4 := left
		LDR R5, [FP, #+y0] ; R5: = right
		UMULL R0, R1, R4, R5
		STR R0, [R2, #+0]
		STR R1, [R3, #+0]
	END Muld;

	PROCEDURE AddFloat64Sigs(CONST a, b: Float64; VAR z: Float64);	(* (a >= 0 & b >= 0) OR (a <= 0 & b <= 0) *)
		VAR x0, x1, xe, s, y0, y1, ye: LONGINT;
	BEGIN
		x0 := a.low;
		x1 := a.high;
		y0 := b.low;
		y1 := b.high;
		IF ((x0 # 0) OR (x1 # 0)) & ((y0 # 0) OR (y1 # 0)) THEN
			s := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, a.high) * {31});
			xe := x1 DIV C MOD E; (* exponent with bias *)
			x1 := x1 MOD C + C;
			ye := y1 DIV C MOD E; (* exponent with bias *)
			y1 := y1 MOD C + C;
			IF xe < ye THEN
				ye := ye - xe;
				xe := xe + ye; (* exponent with bias *)
				IF ye < 32 THEN
					x0 := LSH(x0, -ye) + LSH(x1, 32 - ye);
					x1 := LSH(x1, -ye)
				ELSIF ye < 64 THEN
					x0 := LSH(x1, 32 - ye);
					x1 := 0
				ELSE
					x0 := 0;
					x1 := 0
				END
			ELSIF ye < xe THEN
				ye := xe - ye;
				IF ye < 32 THEN
					y0 := LSH(y0, -ye) + LSH(y1, 32 - ye);
					y1 := LSH(y1, -ye)
				ELSIF ye < 64 THEN
					y0 := LSH(y1, 32 - ye);
					y1 := 0
				ELSE
					y0 := 0;
					y1 := 0
				END
			END;
			Addd(x1, x0, y1, y0);
			IF x1 >= 2*C THEN
				x0 := x0 DIV 2 + LSH(x1, 31);
				x1 := x1 DIV 2;
				INC(xe)
			END;
			IF xe > 7FEH THEN	(* check overflow and underflow *)
				z.high := LONGINT(7FEFFFFFH) + s;
				z.low := -1;
			ELSIF xe < 0 THEN
				z.high := 0;
				z.low := 0
			ELSE
				z.high := xe*C + (x1 - C) + s;
				z.low := x0;
			END
		ELSIF (x0 = 0) & (x1 = 0) THEN
			z.high := y1;
			z.low := y0
		ELSE
			z.high := x1;
			z.low := x0;
		END;
	END AddFloat64Sigs;

	PROCEDURE SubFloat64Sigs(CONST a, b: Float64; VAR z: Float64);	(* (a >= 0 & b <= 0) OR (a <= 0 & b >= 0) *)
		VAR x0, x1, s, y0, y1, xe, ye, z0, z1: LONGINT;
	BEGIN
		x0 := a.low;
		x1 := a.high;
		y0 := b.low;
		y1 := b.high;
		IF ((x0 # 0) OR (x1 # 0)) & ((y0 # 0) OR (y1 # 0)) THEN
			s := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, a.high) * {31});
			xe := x1 DIV C MOD E; (* exponent with bias *)
			x1 := x1 MOD C + C;
			ye := y1 DIV C MOD E; (* exponent with bias *)
			y1 := y1 MOD C + C;
			IF xe < ye THEN
				ye := ye - xe;
				xe := xe + ye; (* exponent with bias *)
				IF ye < 32 THEN
					x0 := LSH(x0, -ye) + LSH(x1, 32 - ye);
					x1 := LSH(x1, -ye)
				ELSIF ye < 64 THEN
					x0 := LSH(x1, 32 - ye);
					x1 := 0
				ELSE
					x0 := 0;
					x1 := 0
				END;
				(* swap x and y *)
				z0 := x0; x0 := y0; y0 := z0;
				z1 := x1; x1 := y1; y1 := z1;
				(* result has inversed sign of x *)
				s := SYSTEM.XOR(s, LONGINT(80000000H))
			ELSIF ye < xe THEN
				ye := xe - ye;
				IF ye < 32 THEN
					y0 := LSH(y0, -ye) + LSH(y1, 32 - ye);
					y1 := LSH(y1, -ye)
				ELSIF ye < 64 THEN
					y0 := LSH(y1, 32 - ye);
					y1 := 0
				ELSE
					y0 := 0;
					y1 := 0
				END
			ELSE (* xe = ye, check if x > y *)
				IF LessThanUH(x0, x1, y0, y1) THEN (* x < y, swap x and y *)
					z0 := x0; x0 := y0; y0 := z0;
					z1 := x1; x1 := y1; y1 := z1;
					(* result has inversed sign of x *)
					s := SYSTEM.XOR(s, LONGINT(80000000H))
				END;
			END;
			Subd(x1, x0, y1, y0);
			IF (x0 # 0) OR (x1 # 0) THEN
				WHILE x1 < C DO x1 := 2*x1 + LSH(x0, -31); x0 := x0*2; DEC(xe) END;
				IF xe > 7FEH THEN	(* check overflow and underflow *)
					z.high := LONGINT(7FEFFFFFH) + s;
					z.low := -1;
				ELSIF xe < 0 THEN
					z.high := 0;
					z.low := 0
				ELSE
					z.high := xe*C + (x1 - C) + s;
					z.low := x0;
				END
			ELSE
				z.low := 0;
				z.high := 0;
			END
		ELSIF (x0 = 0) & (x1 = 0) & ((y0 # 0) OR (y1 # 0)) THEN
			z.low := y0;
			z.high := SYSTEM.XOR(y1, LONGINT(80000000H))	(* inverse sign *)
		ELSE
			z.low := x0;
			z.high := x1
		END
	END SubFloat64Sigs;

	PROCEDURE Neg*(CONST a: Float64; VAR z: Float64);
	BEGIN
		z.low := a.low;
		z.high := SYSTEM.XOR(a.high, LONGINT(80000000H));
	END Neg;

	PROCEDURE Abs*(CONST a: Float64; VAR z: Float64);
	BEGIN
		z.low := a.low;
		z.high := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, a.high)-{31});
	END Abs;

	PROCEDURE Add*(CONST a, b: Float64; VAR z: Float64);
		VAR t: Float64;
	BEGIN
		IF SYSTEM.XOR(a.high, b.high) < 0 THEN
			t.high := SYSTEM.XOR(b.high, LONGINT(80000000H));
			t.low := b.low;
			SubFloat64Sigs(a, t, z)
		ELSE
			AddFloat64Sigs(a, b, z)
		END
	END Add;

	PROCEDURE Sub*(CONST a, b: Float64; VAR z: Float64);
		VAR t: Float64;
	BEGIN
		IF SYSTEM.XOR(a.high, b.high) < 0 THEN
			t.high := SYSTEM.XOR(b.high, LONGINT(80000000H));
			t.low := b.low;
			AddFloat64Sigs(a, t, z)
		ELSE
			SubFloat64Sigs(a, b, z)
		END
	END Sub;

	PROCEDURE Addd0(x1, x0, y1, y0: LONGINT; VAR z1, z0: LONGINT);
	CODE
		LDR R2, [FP, #+z1]; R2 := address of z1
		LDR R3, [FP, #+z0]; R3 := address of z0
		LDR R0, [FP, #+y1]; R0 := y1
		LDR R1, [FP, #+y0]; R1 := y0
		LDR R4, [FP, #+x1]; R4 := x1
		LDR R5, [FP, #+x0]; R5 := x0

		ADDS R5, R5, R1;
		ADCS R4, R4, R0;
		STR R5, [R3, #+0]; store new value at x0
		STR R4, [R2, #+0]; store new value at x1
	END Addd0;

	PROCEDURE Mul64To128(a1, a0, b1, b0: LONGINT; VAR z3, z2, z1, z0: LONGINT);
		VAR more1, more2: LONGINT;
	BEGIN
		Muld(a0, b0, z1, z0);
		Muld(a0, b1, z2, more2);
		Addd0(z2, more2, 0, z1, z2, z1);
		Muld(a1, b1, z3, more1);
		Addd0(z3, more1, 0, z2, z3, z2);
		Muld(a1, b0, more1, more2);
		Addd0(more1, more2, 0, z1, more1, z1);
		Addd0(z3, z2, 0, more1, z3, z2)
	END Mul64To128;

	PROCEDURE Mul*(CONST x, y: Float64; VAR z: Float64);
		VAR x0, x1, xe, y0, y1, ye, s, z0, z1, z2, z3: LONGINT;
	BEGIN
		x0 := x.low;
		x1 := x.high;
		y0 := y.low;
		y1 := y.high;
		(* sign of result *)
		s := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.XOR(x1,y1)) * {31});
		IF ((x0 # 0) OR (x1 # 0)) & ((y0 # 0) OR (y1 # 0)) THEN
			xe := x1 DIV C MOD E; (* exponent with bias *)
			x1 := x1 MOD C + C;
			ye := y1 DIV C MOD E; (* exponent with bias *)
			y1 := y1 MOD C + C;
			xe := xe + ye - B; (* exponent with bias *)
			Mul64To128(x1, x0, y1, y0, z3, z2, z1, z0);
			IF z3 < 200H THEN
				z3 := z3*1000H + LSH(z2, -20);
				z2 := z2*1000H + LSH(z1, -20);
			ELSE
				z3 := z3*800H + LSH(z2, -21);
				z2 := z2*800H + LSH(z1, -21);
				INC(xe)
			END;
			IF xe > 7FEH THEN	(* overflow *)
				z.high := LONGINT(7FEFFFFFH) + s;
				z.low := -1;
			ELSIF xe < 0 THEN (* underflow *)
				z.high := 0;
				z.low := 0;
			ELSE
				z.high := xe*C + (z3 - C) + s;
				z.low := z2;
			END
		ELSE
			z.high := 0;
			z.low := 0;
		END;
	END Mul;

	(* Less than unsigned LONGINT *)
	PROCEDURE LessThanUL(CONST x, y: LONGINT): BOOLEAN;
	BEGIN
		RETURN (LSH(x, -1) < LSH(y, -1)) OR ((LSH(x, -1) = LSH(y, -1)) & ODD(x) & ~ODD(y));
	END LessThanUL;

	(* Less than unsigned HUGEINT *)
	PROCEDURE LessThanUH(CONST x1, x0, y1, y0: LONGINT): BOOLEAN;
	BEGIN
		RETURN LessThanUL(x1, y1) OR ((x1 = y1) & LessThanUL(x0, y0));
	END LessThanUH;

	PROCEDURE LessThan*(CONST x, y: Float64): BOOLEAN;
		VAR z: Float64;
	BEGIN
		Sub(x, y, z);
		RETURN LSH(z.high, -31) # 0;
	END LessThan;

	PROCEDURE Div*(CONST x, y: Float64; VAR z: Float64);
		VAR x0, x1, y0, y1, s, xe, ye, q1, q0: LONGINT;
	BEGIN
		x0 := x.low;
		x1 := x.high;
		y0 := y.low;
		y1 := y.high;
		(* sign of result *)
		s := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.XOR(x1,y1)) * {31});
		IF (x0 = 0) & (x1 = 0) THEN
			(* 0/y = 0 *)
			(* 0/0, 0/inf, 0/NaN, -0/... not handled *)
			z.high := 0;
			z.low := 0;
		ELSIF (y0 = 0) & (y1 = 0) THEN
			(* inf/0, NaN/0, .../-0 not handled *)
			z.high := LONGINT(7FEFFFFFH) + s;
			z.low := -1;
		ELSE
			xe := x1 DIV C MOD E; (* exponent with bias *)
			ye := y1 DIV C MOD E; (* exponent with bias *)
			xe := xe - ye + B; (* exponent with bias *)
			x1 := x1 MOD C + C;
			y1 := y1 MOD C + C;
			IF LessThanUH(x1, x0, y1, y0) THEN
				(* x < y *)
				(* x := 2x *)
				x1 := 2*x1 + LSH(x0, -31);
				x0 := 2*x0;
				DEC(xe);
			END;
			IF xe < 0 THEN (* underflow *)
				z.high := 0;
				z.low := 0;
			ELSIF xe > 7FEH THEN (* overflow *)
				z.high := LONGINT(7FEFFFFFH) + s;
				z.low := -1;
			ELSE (* divide *)
				q1 := 0;
				q0 := 0;
				WHILE q1 < LONGINT(200000H) DO
					(* q := 2q *)
					q1 := 2*q1 + LSH(q0, -31);
					q0 := 2*q0;
					IF ((y1 = x1) & (y0 = x0)) OR LessThanUH(y1, y0, x1, x0) THEN
						(* y <= x *)
						(* x := x - y *)
						x1 := x1 - y1; (* no underflow since x1 >= y1 *)
						IF LessThanUL(x0, y0) THEN
							DEC(x1);
						END;
						x0 := x0 - y0; (* underflow is handled above *)
						(* INC(q) *)
						INC(q0); (* no overflow since bit0 is always 0 *)
					END;
					(* x := 2x *)
					x1 := 2*x1 + LSH(x0, -31);
					x0 := 2*x0;
				END;
				(** round **)
				(* INC(q) *)
				INC(q0);
				IF q0 = 0 THEN (* overflow *)
					INC(q1);
				END;
				(* q := q DIV 2 *)
				q0 := LSH(q0, -1) + LSH(q1, 31);
				q1 := LSH(q1, -1);
				z.low := q0;
				z.high := xe*C + (q1 - C) + s;
			END;
		END;
	END Div;

	PROCEDURE FloatInt64*(i: HUGEINT; VAR z: Float64);
		VAR x0, x1, xe: HUGEINT;
	BEGIN
		x1 := i;
		x0 := 0;
		IF x1 # 0 THEN
			IF x1 = HUGEINT(8000000000000000H) THEN
				x1 := HUGEINT(4000000000000000H);
				xe := 63+B;
			ELSE
				IF x1 < 0 THEN
					x1 := -x1
				END;
				xe := 62+B;
				WHILE x1 < HUGEINT(4000000000000000H) DO x1 := x1*2; DEC(xe) END;
			END;
			x1 := ASH(x1, -32); (*x1 DIV 100000000H;*)
			z.low := LONGINT(x1)*400000H;
			x1 := LSH(x1, -10);
			z.high := LONGINT(xe*C) + (LONGINT(x1)-C) + SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(i, -32)) * {31});
		ELSE
			z.low := LONGINT(x0);
			z.high := LONGINT(x1)
		END
	END FloatInt64;

	PROCEDURE Float*(i: LONGINT; VAR z: Float64);
		VAR x0, x1, xe: LONGINT;
	BEGIN
		x1 := i;
		x0 := 0;
		IF x1 # 0 THEN
			IF x1 = LONGINT(80000000H) THEN
				x1 := LONGINT(40000000H);
				xe := 31+B;
			ELSE
				IF x1 < 0 THEN
					x1 := -x1
				END;
				xe := 30+B;
				WHILE x1 < LONGINT(40000000H) DO x1 := x1*2; DEC(xe) END;
			END;
			z.low := x1*400000H;
			x1 := LSH(x1, -10);
			z.high := xe*C + (x1-C) + SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, i) * {31});
		ELSE
			z.low := x0;
			z.high := x1
		END
	END Float;

	PROCEDURE FixInt64*(CONST a: Float64): HUGEINT;
	(*VAR x0, x1, xe: LONGINT;
		x: LONGINT;
	BEGIN
		x0 := a.low;
		x1 := a.high;
		IF (x0 # 0) OR (x1 # 0) THEN
			xe := x1 DIV C MOD E - B;
			IF x1 > 0 THEN
				x := (x1 MOD C + C)*K;
				x := LSH(x0, -22) + x
			ELSE
				x := -(x1 MOD C + C)*K;
				x := x - LSH(x0, -22)
			END;
			IF xe < 0 THEN x := ASH(x, -31)
			ELSIF xe <= 30 THEN x := ASH(x, xe - 30)
			ELSIF x > 0 THEN x := HUGEINT(7FFFFFFFFFFFFFFFH)
			ELSE x := HUGEINT(8000000000000000H)
			END
		END;
		RETURN x1*)
	VAR
		x: HUGEINT;
		xe: LONGINT;
	BEGIN
		x := SYSTEM.GET64(ADDRESSOF(a));
		IF x # 0 THEN
			xe := LONGINT(LSH(x, -32)) DIV C MOD E - B;
			x := LSH(LSH(x, 12), -12) + 10000000000000H;
			IF a.high < 0 THEN
				x := -x
			END;
			IF xe < 0 THEN x := ASH(x, -53)
			ELSIF xe <= 52 THEN x := ASH(x, xe -52)
			ELSIF x > 0 THEN x := HUGEINT(7FFFFFFFFFFFFFFFH)
			ELSE x := HUGEINT(8000000000000000H)
			END
		END;
		RETURN x
	END FixInt64;

	PROCEDURE Fix*(CONST a: Float64): LONGINT;
		VAR x0, x1, xe: LONGINT;
	BEGIN
		x0 := a.low;
		x1 := a.high;
		IF (x0 # 0) OR (x1 # 0) THEN
			xe := x1 DIV C MOD E - B;
			IF x1 > 0 THEN
				x1 := (x1 MOD C + C)*K;
				x1 := LSH(x0, -22) + x1
			ELSE
				x1 := -(x1 MOD C + C)*K;
				x1 := x1 - LSH(x0, -22)
			END;
			IF xe < 0 THEN x1 := ASH(x1, -31)
			ELSIF xe <= 30 THEN x1 := ASH(x1, xe - 30)
			ELSIF x1 > 0 THEN x1 := LONGINT(7FFFFFFFH)
			ELSE x1 := LONGINT(80000000H)
			END
		END;
		RETURN x1
	END Fix;

	PROCEDURE Single*(VAR a: Float64): REAL;
		VAR x0, x1, s, xe, m, i: LONGINT; x: REAL;
	BEGIN
		x0 := a.low;
		x1 := a.high;
		s := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, x1) * {31});
		xe := x1 DIV C MOD E - B + 127; (* exponent with bias *)
		IF xe > 0FEH THEN (* overflow *)
			i := LONGINT(7F7FFFFFH) + s;
		ELSIF xe < 0 THEN (* underflow *)
			i := 0;
		ELSE
			(* extract mantissa and compute 1 + mantissa *)
			m := (x1 MOD C)*10H + x0 DIV 10000000H MOD 10H;
			INC(m);
			m := m DIV 2;
			(* make short float value *)
			i := xe*800000H + m + s;
		END;
		SYSTEM.PUT32(ADDRESSOF(x), i);
		RETURN x
	END Single;

	PROCEDURE Double*(x: REAL; VAR z: Float64);
		VAR i, m, xe: LONGINT;
	BEGIN
		SYSTEM.GET(ADDRESSOF(x), i);
		IF i = 0 THEN
			z.high := 0;
			z.low := 0;
		ELSE
			m := i MOD 800000H;
			xe := i DIV 800000H MOD 100H - 127 + B;
			z.high := xe*C + LSH(m, -3) + SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, i) * {31});
			z.low := m*20000000H;
		END
	END Double;

END FPE64.

nan = FFF8'0000'0000'0000
inf = 7FF0'0000'0000'0000
max = 7FEF'FFFF'FFFF'FFFF

1.5 = 3FF8'0000'0000'0000

