(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Math;	(** portable *)
(** AUTHOR "?"; PURPOSE "Math utility module (REAL)"; *)

(* Aos version - requires floating-point instruction support. *)

(**
	Commonly needed Math for REALs.
*)

IMPORT SYSTEM;

CONST
	e* = 2.7182818284590452354E0;
	pi* = 3.14159265358979323846E0;

PROCEDURE -Sin(x: REAL):REAL;
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	FLD [RSP]
	FSIN
	FST [RSP]
	POP EAX
END Sin;

PROCEDURE -Cos(x: REAL):REAL;
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	FLD [RSP]
	FCOS
	FST [RSP]
	POP EAX
END Cos;

PROCEDURE -Arctan(x: REAL):REAL;
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	FLD [RSP]
	FLD1
	FPATAN
	FST [RSP]
	POP EAX
END Arctan;

PROCEDURE -Sqrt(x: REAL):REAL;
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	FLD [RSP]
	FSQRT
	FST [RSP]
	POP EAX
END Sqrt;

PROCEDURE -Ln(x: REAL):REAL;
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	FLD1
	FLDL2E
	FDIVP
	FLD [RSP]
	FYL2X
	FST [RSP]
	POP EAX
END Ln;

PROCEDURE -Exp(x: REAL):REAL;
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	FLD [RSP]
	FLDL2E
	FMULP
	FLD ST0
	FRNDINT
	FXCH ST1
	FSUB ST0, ST1
	F2XM1
	FLD1
	FADDP
	FSCALE
	FSTP ST1
	FST [RSP]
	POP EAX
END Exp;

PROCEDURE sin*(x: REAL): REAL;
BEGIN
	IF x < 0.0 THEN RETURN -Sin(-x) ELSE RETURN Sin(x) END
END sin;

PROCEDURE cos*(x: REAL): REAL;
BEGIN
	IF x < 0.0 THEN RETURN Cos(-x) ELSE RETURN Cos(x) END
END cos;

PROCEDURE arctan*(x: REAL): REAL;
BEGIN
	RETURN Arctan(x)
END arctan;

PROCEDURE sqrt*(x: REAL): REAL;
BEGIN
	IF x <= 0 THEN
		IF x = 0 THEN RETURN 0 ELSE HALT(80) END
	ELSE
		RETURN Sqrt(x)
	END
END sqrt;

PROCEDURE ln*(x: REAL): REAL;
BEGIN
	IF x <= 0 THEN HALT(80)
	ELSE
		RETURN Ln(x)
	END
END ln;

PROCEDURE exp*(x: REAL): REAL;
BEGIN
	RETURN Exp(x)
END exp;

END Math.
