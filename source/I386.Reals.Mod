(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Reals;	(** portable, except where noted *)
(** AUTHOR "bmoesli"; PURPOSE "Real number manipulation"; *)

(** Implementation of the non-portable components of IEEE REAL and
LONGREAL manipulation. The routines here are required to do conversion
of reals to strings and back.
Implemented by Bernd Moesli, Seminar for Applied Mathematics,
Swiss Federal Institute of Technology Zürich.
*)

IMPORT SYSTEM, Machine;

(* Bernd Moesli
	Seminar for Applied Mathematics
	Swiss Federal Institute of Technology Zurich
	Copyright 1993

	Support module for IEEE floating-point numbers

	Please change constant definitions of H, L depending on byte ordering
	Use bm.TestReals.Do for testing the implementation.

	Expo, ExpoL return the shifted binary exponent (0 <= e < 256 (2048 resp.))
	SetExpo, SetExpoL set the shifted binary exponent
	Real, RealL convert hexadecimals to reals
	Int, IntL convert reals to hexadecimals
	Ten returns 10^e (e <= 308, 308 < e delivers NaN)

	1993.4.22	IEEE format only, 32-bits LONGINTs only
	30.8.1993	mh: changed RealX to avoid compiler warnings;
	7.11.1995	jt: dynamic endianess test
	22.01.97	pjm: NaN stuff (using quiet NaNs only to avoid traps)
	05.01.98	prk: NaN with INF support
*)

VAR
	DefaultFCR*: SET;
	tene: ARRAY 23 OF LONGREAL; (* e = 0..22: exact values of 10^e *)
	ten: ARRAY 27 OF LONGREAL;
	eq, gr: ARRAY 20 OF SET;
	H, L: INTEGER;

(** Returns the shifted binary exponent (0 <= e < 256). *)
PROCEDURE Expo* (x: REAL): LONGINT;
BEGIN
	RETURN ASH(SYSTEM.VAL(LONGINT, x), -23) MOD 256
END Expo;

(** Returns the shifted binary exponent (0 <= e < 2048). *)
PROCEDURE ExpoL* (x: LONGREAL): LONGINT;
	VAR i: LONGINT;
BEGIN
	SYSTEM.GET(ADDRESSOF(x) + H, i); RETURN ASH(i, -20) MOD 2048
END ExpoL;

(** Sets the shifted binary exponent. *)
PROCEDURE SetExpo* (e: LONGINT; VAR x: REAL);
	VAR i: LONGINT;
BEGIN
	SYSTEM.GET(ADDRESSOF(x), i);
	i:= ASH(ASH(ASH(i, -31), 8) + e MOD 256, 23) + i MOD ASH(1, 23);
	SYSTEM.PUT(ADDRESSOF(x), i)
END SetExpo;

(** Sets the shifted binary exponent. *)
PROCEDURE SetExpoL* (e: LONGINT; VAR x: LONGREAL);
	VAR i: LONGINT;
BEGIN
	SYSTEM.GET(ADDRESSOF(x) + H, i);
	i:= ASH(ASH(ASH(i, -31), 11) + e MOD 2048, 20) + i MOD ASH(1, 20);
	SYSTEM.PUT(ADDRESSOF(x) + H, i)
END SetExpoL;

(** Convert hexadecimal to REAL. *)
PROCEDURE Real* (h: LONGINT): REAL;
	VAR x: REAL;
BEGIN SYSTEM.PUT(ADDRESSOF(x), h); RETURN x
END Real;

(** Convert hexadecimal to LONGREAL. h and l are the high and low parts.*)
PROCEDURE RealL* (h, l: LONGINT): LONGREAL;
	VAR x: LONGREAL;
BEGIN SYSTEM.PUT(ADDRESSOF(x) + H, h); SYSTEM.PUT(ADDRESSOF(x) + L, l); RETURN x
END RealL;

(** Convert REAL to hexadecimal. *)
PROCEDURE Int* (x: REAL): LONGINT;
	VAR i: LONGINT;
BEGIN SYSTEM.PUT(ADDRESSOF(i), x); RETURN i
END Int;

(** Convert LONGREAL to hexadecimal. h and l are the high and low parts. *)
PROCEDURE IntL* (x: LONGREAL; VAR h, l: LONGINT);
BEGIN SYSTEM.GET(ADDRESSOF(x) + H, h); SYSTEM.GET(ADDRESSOF(x) + L, l)
END IntL;

(** Returns 10^e (e <= 308, 308 < e delivers IEEE-code +INF). *)
PROCEDURE Ten* (e: LONGINT): LONGREAL;
	VAR E: LONGINT; r: LONGREAL;
BEGIN
	IF e < -307 THEN RETURN 0 ELSIF 308 < e THEN RETURN RealL(2146435072, 0) END;
	INC(e, 307); r:= ten[e DIV 23] * tene[e MOD 23];
	IF e MOD 32 IN eq[e DIV 32] THEN RETURN r
	ELSE
		E:= ExpoL(r); SetExpoL(1023+52, r);
		IF e MOD 32 IN gr[e DIV 32] THEN r:= r-1 ELSE r:= r+1 END;
		SetExpoL(E, r); RETURN r
	END
END Ten;

(** Returns the NaN code (0 <= c < 8399608) or -1 if not NaN/Infinite. *)
PROCEDURE NaNCode* (x: REAL): LONGINT;
BEGIN
	IF ASH(SYSTEM.VAL(LONGINT, x), -23) MOD 256 = 255 THEN	(* Infinite or NaN *)
		RETURN SYSTEM.VAL(LONGINT, x) MOD 800000H	(* lowest 23 bits *)
	ELSE
		RETURN -1
	END
END NaNCode;

(** Returns the NaN code (0 <= h < 1048576, MIN(LONGINT) <= l <= MAX(LONGINT)) or (-1,-1) if not NaN/Infinite. *)
PROCEDURE NaNCodeL* (x: LONGREAL;  VAR h, l: LONGINT);
BEGIN
	SYSTEM.GET(ADDRESSOF(x) + H, h); SYSTEM.GET(ADDRESSOF(x) + L, l);
	IF ASH(h, -20) MOD 2048 = 2047 THEN	(* Infinite or NaN *)
		h := h MOD 100000H	(* lowest 20 bits *)
	ELSE
		h := -1;  l := -1
	END
END NaNCodeL;

(** Returns TRUE iff x is NaN/Infinite. *)
PROCEDURE IsNaN* (x: REAL): BOOLEAN;
BEGIN
	RETURN ASH(SYSTEM.VAL(LONGINT, x), -23) MOD 256 = 255
END IsNaN;

(** Returns TRUE iff x is NaN/Infinite. *)
PROCEDURE IsNaNL* (x: LONGREAL): BOOLEAN;
VAR h: LONGINT;
BEGIN
	SYSTEM.GET(ADDRESSOF(x) + H, h);
	RETURN ASH(h, -20) MOD 2048 = 2047
END IsNaNL;

(** Returns NaN with specified code (0 <= l < 8399608). *)
PROCEDURE NaN* (l: LONGINT): REAL;
VAR x: REAL;
BEGIN
	SYSTEM.PUT(ADDRESSOF(x), (l MOD 800000H) + 7F800000H);
	RETURN x
END NaN;

(** Returns NaN with specified code (0 <= h < 1048576, MIN(LONGINT) <= l <= MAX(LONGINT)). *)
PROCEDURE NaNL* (h, l: LONGINT): LONGREAL;
VAR x: LONGREAL;
BEGIN
	h := (h MOD 100000H) + 7FF00000H;
	SYSTEM.PUT(ADDRESSOF(x) + H, h);
	SYSTEM.PUT(ADDRESSOF(x) + L, l);
	RETURN x
END NaNL;

(*
PROCEDURE fcr(): SET;
CODE {SYSTEM.i386, SYSTEM.FPU}
	PUSH 0
	FSTCW [ESP]
	FWAIT
	POP EAX
END fcr;
*)

(** Return state of the floating-point control register. *)
PROCEDURE FCR*(): SET;
CODE {SYSTEM.i386, SYSTEM.FPU}
	PUSH 0
	FSTCW [ESP]
	FWAIT
	POP EAX
END FCR;

(** Set state of floating-point control register.  Traps reset this to the default.  Note that changing the rounding mode affects rounding of imprecise results as well as the ENTIER operation. *)

PROCEDURE SetFCR*(s: SET);
CODE {SYSTEM.i386, SYSTEM.FPU}
	FLDCW [EBP+s]
END SetFCR;

(** Round x to an integer using the current rounding mode. *)

PROCEDURE -Round*(x: REAL): LONGINT;	(** non-portable *)
CODE {SYSTEM.i386, SYSTEM.FPU}
	FLD DWORD [ESP]
	FISTP DWORD [ESP]	; store integer using current rounding mode
	FWAIT
	POP EAX	; return value
END Round;

(** Round x to an integer using the current rounding mode. *)

PROCEDURE -RoundL*(x: LONGREAL): LONGINT;	(** non-portable *)
CODE {SYSTEM.i386, SYSTEM.FPU}
	FLD QWORD [ESP]
	FISTP DWORD [ESP]	; store integer using current rounding mode
	FWAIT
	POP EAX	; return value
	POP EBX	; drop rest of parameter
END RoundL;

PROCEDURE RealX (hh, hl: HUGEINT; adr: ADDRESS);
VAR h,l: LONGINT;
BEGIN
	h := SHORT(hh); l := SHORT(hl);
	SYSTEM.PUT(adr + H, h); SYSTEM.PUT(adr + L, l);
END RealX;

PROCEDURE InitHL;
	VAR i: ADDRESS; dmy: INTEGER; littleEndian: BOOLEAN;
BEGIN
	DefaultFCR := Machine.fcr;

	dmy := 1; i := ADDRESSOF(dmy);
	SYSTEM.GET(i, littleEndian);	(* indirection via i avoids warning on SUN cc -O *)
	IF littleEndian THEN H := 4; L := 0 ELSE H := 0; L := 4 END
END InitHL;

BEGIN InitHL;
	RealX(03FF00000H, 0, ADDRESSOF(tene[0]));
	RealX(040240000H, 0, ADDRESSOF(tene[1])); (* 1 *)
	RealX(040590000H, 0, ADDRESSOF(tene[2])); (* 2 *)
	RealX(0408F4000H, 0, ADDRESSOF(tene[3])); (* 3 *)
	RealX(040C38800H, 0, ADDRESSOF(tene[4])); (* 4 *)
	RealX(040F86A00H, 0, ADDRESSOF(tene[5])); (* 5 *)
	RealX(0412E8480H, 0, ADDRESSOF(tene[6])); (* 6 *)
	RealX(0416312D0H, 0, ADDRESSOF(tene[7])); (* 7 *)
	RealX(04197D784H, 0, ADDRESSOF(tene[8])); (* 8 *)
	RealX(041CDCD65H, 0, ADDRESSOF(tene[9])); (* 9 *)
	RealX(04202A05FH, 020000000H, ADDRESSOF(tene[10])); (* 10 *)
	RealX(042374876H, 0E8000000H, ADDRESSOF(tene[11])); (* 11 *)
	RealX(0426D1A94H, 0A2000000H, ADDRESSOF(tene[12])); (* 12 *)
	RealX(042A2309CH, 0E5400000H, ADDRESSOF(tene[13])); (* 13 *)
	RealX(042D6BCC4H, 01E900000H, ADDRESSOF(tene[14])); (* 14 *)
	RealX(0430C6BF5H, 026340000H, ADDRESSOF(tene[15])); (* 15 *)
	RealX(04341C379H, 037E08000H, ADDRESSOF(tene[16])); (* 16 *)
	RealX(043763457H, 085D8A000H, ADDRESSOF(tene[17])); (* 17 *)
	RealX(043ABC16DH, 0674EC800H, ADDRESSOF(tene[18])); (* 18 *)
	RealX(043E158E4H, 060913D00H, ADDRESSOF(tene[19])); (* 19 *)
	RealX(04415AF1DH, 078B58C40H, ADDRESSOF(tene[20])); (* 20 *)
	RealX(0444B1AE4H, 0D6E2EF50H, ADDRESSOF(tene[21])); (* 21 *)
	RealX(04480F0CFH, 064DD592H, ADDRESSOF(tene[22])); (* 22 *)

	RealX(031FA18H, 02C40C60DH, ADDRESSOF(ten[0])); (* -307 *)
	RealX(04F7CAD2H, 03DE82D7BH, ADDRESSOF(ten[1])); (* -284 *)
	RealX(09BF7D22H, 08322BAF5H, ADDRESSOF(ten[2])); (* -261 *)
	RealX(0E84D669H, 05B193BF8H, ADDRESSOF(ten[3])); (* -238 *)
	RealX(0134B9408H, 0EEFEA839H, ADDRESSOF(ten[4])); (* -215 *)
	RealX(018123FF0H, 06EEA847AH, ADDRESSOF(ten[5])); (* -192 *)
	RealX(01CD82742H, 091C6065BH, ADDRESSOF(ten[6])); (* -169 *)
	RealX(0219FF779H, 0FD329CB9H, ADDRESSOF(ten[7])); (* -146 *)
	RealX(02665275EH, 0D8D8F36CH, ADDRESSOF(ten[8])); (* -123 *)
	RealX(02B2BFF2EH, 0E48E0530H, ADDRESSOF(ten[9])); (* -100 *)
	RealX(02FF286D8H, 0EC190DCH, ADDRESSOF(ten[10])); (* -77 *)
	RealX(034B8851AH, 0B548EA4H, ADDRESSOF(ten[11])); (* -54 *)
	RealX(0398039D6H, 065896880H, ADDRESSOF(ten[12])); (* -31 *)
	RealX(03E45798EH, 0E2308C3AH, ADDRESSOF(ten[13])); (* -8 *)
	RealX(0430C6BF5H, 026340000H, ADDRESSOF(ten[14])); (* 15 *)
	RealX(047D2CED3H, 02A16A1B1H, ADDRESSOF(ten[15])); (* 38 *)
	RealX(04C98E45EH, 01DF3B015H, ADDRESSOF(ten[16])); (* 61 *)
	RealX(0516078E1H, 011C3556DH, ADDRESSOF(ten[17])); (* 84 *)
	RealX(05625CCFEH, 03D35D80EH, ADDRESSOF(ten[18])); (* 107 *)
	RealX(05AECDA62H, 055B2D9EH, ADDRESSOF(ten[19])); (* 130 *)
	RealX(05FB317E5H, 0EF3AB327H, ADDRESSOF(ten[20])); (* 153 *)
	RealX(064794514H, 05230B378H, ADDRESSOF(ten[21])); (* 176 *)
	RealX(06940B8E0H, 0ACAC4EAFH, ADDRESSOF(ten[22])); (* 199 *)
	RealX(06E0621B1H, 0C28AC20CH, ADDRESSOF(ten[23])); (* 222 *)
	RealX(072CD4A7BH, 0EBFA31ABH, ADDRESSOF(ten[24])); (* 245 *)
	RealX(077936214H, 09CBD3226H, ADDRESSOF(ten[25])); (* 268 *)
	RealX(07C59A742H, 0461887F6H, ADDRESSOF(ten[26])); (* 291 *)

	eq[0]:= {0, 3, 4, 5, 9, 16, 23, 25, 26, 28, 31};
	eq[1]:= {2, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 27, 28, 29, 30, 31};
	eq[2]:= {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28};
	eq[3]:= {0, 1, 2, 3, 5, 6, 7, 8, 9, 11, 14, 15, 16, 17, 18, 19, 20, 22, 27, 28, 29, 30, 31};
	eq[4]:= {0, 6, 7, 10, 11, 12, 13, 14, 15, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31};
	eq[5]:= {0, 1, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31};
	eq[6]:= {0, 1, 4, 5, 7, 8, 10, 14, 15, 16, 18, 20, 21, 23, 24, 25, 26, 28, 29, 30, 31};
	eq[7]:= {0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 23, 24, 26, 28, 29, 30, 31};
	eq[8]:= {0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 14, 16, 17, 18, 19, 20, 21, 24, 25, 26, 29};
	eq[9]:= {1, 2, 4, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31};
	eq[10]:= {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30};
	eq[11]:= {0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 13, 14, 15, 16, 19, 20, 21, 22, 23, 27, 28, 29, 30};
	eq[12]:= {0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 14, 15, 16, 17, 18, 19, 20, 21, 23, 26, 27, 29, 30, 31};
	eq[13]:= {0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 23, 24, 27, 28, 29, 30, 31};
	eq[14]:= {0, 1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31};
	eq[15]:= {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 28};
	eq[16]:= {1, 2, 4, 11, 13, 16, 17, 18, 19, 22, 24, 25, 26, 27, 28, 29, 30, 31};
	eq[17]:= {1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 14, 15, 18, 19, 20, 21, 23, 25, 26, 27, 28, 29, 31};
	eq[18]:= {0, 2, 4, 5, 6, 8, 9, 11, 12, 13, 14, 16, 17, 19, 20, 22, 23, 24, 26, 27, 28, 29};
	eq[19]:= {2, 3, 4, 5, 6, 7};

	gr[0]:= {24, 27, 29, 30};
	gr[1]:= {0, 1, 3, 4, 7};
	gr[2]:= {29, 30, 31};
	gr[3]:= {4, 10, 12, 13, 21, 23, 24, 25, 26};
	gr[4]:= {1, 2, 3, 4, 5, 8, 9, 16, 17};
	gr[5]:= {2, 3, 4, 18};
	gr[6]:= {2, 3, 6, 9, 11, 12, 13, 17, 19, 22, 27};
	gr[7]:= {2};
	gr[8]:= {7, 12, 13, 15, 22, 23, 27, 28, 30, 31};
	gr[9]:= {0, 3, 5, 7, 8};
	gr[10]:= {};
	gr[11]:= {};
	gr[12]:= {11, 13, 22, 24, 25, 28};
	gr[13]:= {22, 25, 26};
	gr[14]:= {4, 5};
	gr[15]:= {10, 14, 27, 29, 30, 31};
	gr[16]:= {0, 3, 5, 6, 7, 8, 9, 10, 12, 14, 15, 20, 21, 23};
	gr[17]:= {0, 10, 12, 13, 16, 17, 22, 24, 30};
	gr[18]:= {};
	gr[19]:= {}
END Reals.