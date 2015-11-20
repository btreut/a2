(** AUTHOR "Michael Szediwy";
	PURPOSE "Inverse Discrete CosineTransformation for Aos based on
		- Intel's AP-945: Using Streaming SMID Extensions 2(SSE2) to Implement an Inverse Discrete Cosine Transform";
*)
MODULE IDCT;

IMPORT
	SYSTEM, Commands, Machine, KernelLog;

CONST
	NrBlocks=4;
	BITSINVACC = 4;
	SHIFTINVROW = 16 - BITSINVACC;
	SHIFTINVCOL = 1 + BITSINVACC;

	(* Const for idct *)
	W1 = 2841;                (* 2048*sqrt(2)*cos(1*pi/16) *)
	W2 = 2676;                (* 2048*sqrt(2)*cos(2*pi/16) *)
	W3 = 2408;                 (* 2048*sqrt(2)*cos(3*pi/16) *)
	W5 = 1609;                 (* 2048*sqrt(2)*cos(5*pi/16) *)
	W6 = 1108;                 (* 2048*sqrt(2)*cos(6*pi/16) *)
	W7 = 565;                  (* 2048*sqrt(2)*cos(7*pi/16) *)

	INT* = 0;
	SSE* = 1;
	SSE2* = 2;

VAR
	RNDINVROW, RNDINVCOL, RNDINVCORR: INTEGER;
	M128onecorr, M128roundinvrow, M128roundinvcol, M128roundinvcorr, M128tg116, M128tg216, M128tg316, M128cos416: POINTER TO ARRAY OF INTEGER;
	M128tabi04, M128tabi17, M128tabi26, M128tabi35: POINTER TO ARRAY OF INTEGER;
	tabi04adr, tabi17adr, tabi26adr, tabi35adr, onecorradr, roundinvrowadr, roundinvcoladr, roundinvcorradr, tg116adr, tg216adr, tg316adr, cos416adr: LONGINT;
	Transform*: PROCEDURE (src, dst: LONGINT);
	intTab: POINTER TO ARRAY OF INTEGER;
	status*: LONGINT;


PROCEDURE -MOVDQA1;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX, SYSTEM.SSE2}
	MOVDQA	XMM0, [EAX]
	MOVDQA	XMM4, [EAX+32]
END MOVDQA1;

PROCEDURE -MOVDQA2;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX, SYSTEM.SSE2}
	MOVDQA	[EDX], XMM0
	MOVDQA	[EDX+32], XMM4
	MOVDQA	XMM0, [EAX+64]
	MOVDQA	XMM4, [EAX+96]
END MOVDQA2;

PROCEDURE -MOVDQA3;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX, SYSTEM.SSE2}
	MOVDQA	[EDX+64], XMM0
	MOVDQA	[EDX+96], XMM4
	MOVDQA	XMM0, [EAX+48]
	MOVDQA	XMM4, [EAX+16]
END MOVDQA3;

PROCEDURE -MOVDQA4;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX, SYSTEM.SSE2}
	MOVDQA	[EDX+48], XMM0
	MOVDQA	[EDX+16], XMM4
	MOVDQA	XMM0, [EAX+80]
	MOVDQA	XMM4, [EAX+112]
END MOVDQA4;

PROCEDURE -MOVDQA5;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX, SYSTEM.SSE2}
	MOVDQA	[EDX+80], XMM0
	MOVDQA	XMM0, [EDX+80] ; necessary ?
	MOVDQA	[EDX+112], XMM4
	MOVDQA	XMM4, [EDX+112] ; necessary ?
END MOVDQA5;

(* Pay attention if you change local varss. In the inline procedures there are direct address variable *)
PROCEDURE TransformSSE2*(src, dst: LONGINT);
VAR tg116, tg216, tg316, cos416, onecorr, roundinvcol, roundinvcorr, ecx: LONGINT;
BEGIN {UNCOOPERATIVE}

	tg116 := tg116adr;
	tg216 := tg216adr;
	tg316 := tg316adr;
	cos416 := cos416adr;
	onecorr := onecorradr;
	roundinvcol := roundinvcoladr;
	roundinvcorr := roundinvcorradr;
	ecx := Machine.GetECX();
	Machine.SetEAX(src);
	Machine.SetEDX(dst);
	Machine.SetECX(roundinvrowadr);
	MOVDQA1;

	Machine.SetESI(tabi04adr );
	Machine.SetECX(tabi26adr );
	DCT8INVROWSSE2;
	MOVDQA2;
(*	Machine.SetESI(tabi04adr );
	Machine.SetECX(tabi26adr );*)
	DCT8INVROWSSE2;
	MOVDQA3;
	Machine.SetESI(tabi35adr );
	Machine.SetECX(tabi17adr );
	DCT8INVROWSSE2;
	MOVDQA4;
(*	Machine.SetESI(tabi35adr );
	Machine.SetECX(tabi17adr ); *)
	DCT8INVROWSSE2;
	MOVDQA5;
	DCT8INVCOLSSE2;
	Machine.SetECX (ecx);
END TransformSSE2;



PROCEDURE -DCT8INVROWSSE2;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX, SYSTEM.SSE2}
	PSHUFLW	XMM0, XMM0, 0D8H
	PSHUFD		XMM1, XMM0, 0
	PMADDWD	XMM1, [ESI]
	PSHUFD		XMM3, XMM0, 055H
	PSHUFHW	XMM0, XMM0, 0D8H
	PMADDWD	XMM3, [ESI+32]
	PSHUFD		XMM2, XMM0, 0AAH
	PSHUFD		XMM0, XMM0, 0FFH
	PMADDWD	XMM2, [ESI+16]
	PSHUFHW	XMM4, XMM4, 0D8H
	PADDD		XMM1, [EBX]
	PSHUFLW	XMM4, XMM4, 0D8H
	PMADDWD	XMM0, [ESI+48]
	PSHUFD		XMM5, XMM4, 0
	PSHUFD		XMM6, XMM4, 0AAH
	PMADDWD	XMM5, [ECX]
	PADDD		XMM1, XMM2
	MOVDQA	XMM2, XMM1
	PSHUFD		XMM7, XMM4, 055H
	PMADDWD	XMM6, [ECX+16]
	PADDD		XMM0, XMM3
	PSHUFD		XMM4, XMM4, 0FFH
	PSUBD		XMM2, XMM0
	PMADDWD	XMM7, [ECX+32]
	PADDD		XMM0, XMM1
	PSRAD		XMM2, 12
	PADDD		XMM5, [EBX]
	PMADDWD	XMM4, [ECX+48]
	PADDD		XMM5, XMM6
	MOVDQA	XMM6, XMM5
	PSRAD		XMM0, 12
	PSHUFD		XMM2, XMM2, 01BH
	PACKSSDW	XMM0, XMM2
	PADDD		XMM4, XMM7
	PSUBD		XMM6, XMM4
	PADDD		XMM4, XMM5
	PSRAD		XMM6, 12
	PSRAD		XMM4, 12
	PSHUFD		XMM6, XMM6, 01BH
	PACKSSDW	XMM4, XMM6
END DCT8INVROWSSE2;



PROCEDURE -DCT8INVCOLSSE2;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX, SYSTEM.SSE2}
	MOV		EDI, [EBP-12]
	MOVDQA	XMM1, [EDI]
	MOVDQA	XMM2, XMM0
	MOVDQA	XMM3, [EDX+48]
	PMULHW	XMM0, XMM1
	PMULHW	XMM1, XMM3
	MOV		EDI, [EBP-4]
	MOVDQA	XMM5, [EDI]
	MOVDQA	XMM6, XMM4
	PMULHW	XMM4, XMM5
	PADDSW	XMM0, XMM2
	PMULHW	XMM5, [EDX+16]
	PADDSW	XMM1, XMM3
	MOVDQA	XMM7, [EDX+96]
	PADDSW	XMM0, XMM3
	MOV		EDI, [EBP-8]
	MOVDQA	XMM3, [EDI]
	PSUBSW	XMM2, XMM1
	PMULHW	XMM7, XMM3
	MOVDQA	XMM1, XMM0
	PMULHW	XMM3, [EDX+32]
	PSUBSW	XMM5, XMM6
	PADDSW	XMM4, [EDX+16]
	PADDSW	XMM0, XMM4
	MOV		EDI, [EBP-20]
	PADDSW	XMM0, [EDI]
	PSUBSW	XMM4, XMM1
	MOVDQA	XMM6, XMM5
	PSUBSW	XMM5, XMM2
	MOV		EDI, [EBP-20]
	PADDSW	XMM5, [EDI]
	PADDSW	XMM6, XMM2
	MOVDQA	[EDX+112], XMM0
	MOVDQA	XMM1, XMM4
	MOV		EDI, [EBP-16]
	MOVDQA	XMM0, [EDI]
	PADDSW	XMM4, XMM5
	MOV		EDI, [EBP-16]
	MOVDQA	XMM2, [EDI]
	PMULHW	XMM2, XMM4
	MOVDQA	[EDX+48], XMM6
	PSUBSW	XMM1, XMM5
	PADDSW	XMM7, [EDX+32]
	PSUBSW	XMM3, [EDX+96]
	MOVDQA	XMM6, [EDX]
	PMULHW	XMM0, XMM1
	MOVDQA	XMM5, [EDX+64]
	PADDSW	XMM5, XMM6
	PSUBSW	XMM6, [EDX+64]
	PADDSW	XMM4, XMM2
	MOV		EDI, [EBP-20]
	POR		XMM4, [EDI]
	PADDSW	XMM0, XMM1
	MOV		EDI, [EBP-20]
	POR		XMM0, [EDI]
	MOVDQA	XMM2, XMM5
	PADDSW	XMM5, XMM7
	MOVDQA	XMM1, XMM6
	MOV		EDI, [EBP-24]
	PADDSW	XMM5, [EDI]
	PSUBSW	XMM2, XMM7
	MOVDQA	XMM7, [EDX+112]
	PADDSW	XMM6, XMM3
	MOV		EDI, [EBP-24]
	PADDSW	XMM6, [EDI]
	PADDSW	XMM7, XMM5
	PSRAW		XMM7, SHIFTINVCOL
	PSUBSW	XMM1, XMM3
	MOV		EDI, [EBP-28]
	PADDSW	XMM1, [EDI]
	MOVDQA	XMM3, XMM6
	MOV		EDI, [EBP-28]
	PADDSW	XMM2, [EDI]
	PADDSW	XMM6, XMM4
	MOVDQA	[EDX], XMM7
	PSRAW		XMM6, SHIFTINVCOL
	MOVDQA	XMM7, XMM1
	PADDSW	XMM1, XMM0
	MOVDQA	[EDX+16], XMM6
	PSRAW		XMM1, SHIFTINVCOL
	MOVDQA	XMM6, [EDX+48]
	PSUBSW	XMM7, XMM0
	PSRAW		XMM7, SHIFTINVCOL
	MOVDQA	[EDX+32], XMM1
	PSUBSW	XMM5, [EDX+112]
	PSRAW		XMM5, SHIFTINVCOL
	MOVDQA	[EDX+112], XMM5
	PSUBSW	XMM3, XMM4
	PADDSW	XMM6, XMM2
	PSUBSW	XMM2, [EDX+48]
	PSRAW		XMM6, SHIFTINVCOL
	PSRAW		XMM2, SHIFTINVCOL
	MOVDQA	[EDX+48], XMM6
	PSRAW		XMM3, SHIFTINVCOL
	MOVDQA	[EDX+64], XMM2
	MOVDQA	[EDX+80], XMM7
	MOVDQA	[EDX+96], XMM3
END DCT8INVCOLSSE2;

PROCEDURE -MOVQ1;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		MMX0, [ECX]
	MOVQ		MMX1, [ECX+8]
END MOVQ1;

PROCEDURE -MOVQ2;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		MMX0, [ECX+16]
	MOVQ		[EDX], MMX3
	MOVQ		MMX1, [ECX+24]
	MOVQ		[EDX+8], MMX7
END MOVQ2;

PROCEDURE -MOVQ3;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		MMX0, [ECX+32]
	MOVQ		[EDX+16], MMX3
	MOVQ		MMX1, [ECX+40]
	MOVQ		[EDX+24], MMX7
END MOVQ3;

PROCEDURE -MOVQ4;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		MMX0, [ECX+48]
	MOVQ		[EDX+32], MMX3
	MOVQ		MMX1, [ECX+56]
	MOVQ		[EDX+40], MMX7
END MOVQ4;

PROCEDURE -MOVQ5;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		MMX0, [ECX+64]
	MOVQ		[EDX+48], MMX3
	MOVQ		MMX1, [ECX+72]
	MOVQ		[EDX+56], MMX7
END MOVQ5;

PROCEDURE -MOVQ6;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		MMX0, [ECX+80]
	MOVQ		[EDX+64], MMX3
	MOVQ		MMX1, [ECX+88]
	MOVQ		[EDX+72], MMX7
END MOVQ6;

PROCEDURE -MOVQ7;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		MMX0, [ECX+96]
	MOVQ		[EDX+80], MMX3
	MOVQ		MMX1, [ECX+104]
	MOVQ		[EDX+88], MMX7
END MOVQ7;

PROCEDURE -MOVQ8;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		MMX0, [ECX+112]
	MOVQ		[EDX+96], MMX3
	MOVQ		MMX1, [ECX+120]
	MOVQ		[EDX+104], MMX7
END MOVQ8;

PROCEDURE -MOVQ9;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		[EDX+112], MMX3
	MOVQ		MMX0, [EDX+80]
	MOVQ		[EDX+120], MMX7
END MOVQ9;

PROCEDURE -MOVQ10;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOVQ		MMX0, [EDX+88]
	ADD		EDX, 8
END MOVQ10;

(* Pay attention if you change local varss. In the inline procedures there are direct address variable *)
PROCEDURE TransformSSE*(src, dst: LONGINT);
VAR tg116, tg216, tg316, cos416, onecorr, roundinvcol, roundinvcorr, ecx: LONGINT;
BEGIN {UNCOOPERATIVE}

	tg116 := tg116adr;
	tg216 := tg216adr;
	tg316 := tg316adr;
	cos416 := cos416adr;
	onecorr := onecorradr;
	roundinvcol := roundinvcoladr;
	roundinvcorr := roundinvcorradr;

	ecx := Machine.GetECX ();
	Machine.SetECX(src);
	Machine.SetEDX(dst);	(* MOV EDX, dst *)
	Machine.SetEBX(roundinvrowadr );
	MOVQ1;
	Machine.SetESI(tabi04adr );
	DCT8INVROWSSE;
	MOVQ2;
	Machine.SetESI(tabi17adr );
	DCT8INVROWSSE;
	MOVQ3;
	Machine.SetESI(tabi26adr );
	DCT8INVROWSSE;
	MOVQ4;
	Machine.SetESI(tabi35adr );
	DCT8INVROWSSE;
	MOVQ5;
	Machine.SetESI(tabi04adr );
	DCT8INVROWSSE;
	MOVQ6;
	Machine.SetESI(tabi35adr );
	DCT8INVROWSSE;
	MOVQ7;
	Machine.SetESI(tabi26adr );
	DCT8INVROWSSE;
	MOVQ8;
	Machine.SetESI(tabi17adr );
	DCT8INVROWSSE;
	MOVQ9;
	DCT8INVCOLSSE;
	MOVQ10;
	DCT8INVCOLSSE;
	Machine.SetECX(ecx);

END TransformSSE;

PROCEDURE -DCT8INVROWSSE;
CODE{SYSTEM.i386, SYSTEM.SSE2, SYSTEM.MMX}
	MOVQ		MMX2, MMX0
	MOVQ		MMX3, [ESI]
	PSHUFW	MMX0, MMX0, 88H
	MOVQ		MMX4, [ESI+8]
	MOVQ		MMX5, MMX1
	PMADDWD	MMX3, MMX0
	MOVQ		MMX6, [ESI+32]
	PSHUFW	MMX1, MMX1,  88H
	PMADDWD	MMX4, MMX1
	MOVQ		MMX7, [ESI+40]
	PSHUFW	MMX2, MMX2,  0DDH
	PMADDWD	MMX6, MMX2
	PSHUFW	MMX5, MMX5,  0DDH
	PMADDWD	MMX7, MMX5
	PADDD		MMX3, [EBX]				; [EBX] = roundinvrowadr
	PMADDWD	MMX0, [ESI+16]
	PADDD		MMX3, MMX4
	PMADDWD	MMX1, [ESI+24]
	MOVQ		MMX4, MMX3
	PMADDWD	MMX2, [ESI+48]
	PADDD		MMX6, MMX7
	PMADDWD	MMX5, [ESI+56]
	PADDD		MMX3, MMX6
	PADDD		MMX0, [EBX]				; [EBX] = roundinvrowadr
	PSRAD		MMX3, SHIFTINVROW
	PADDD		MMX0, MMX1
	PSUBD		MMX4, MMX6
	MOVQ		MMX7, MMX0
	PADDD		MMX2, MMX5
	PADDD		MMX0, MMX2
	PSRAD		MMX4, SHIFTINVROW
	PSUBD		MMX7, MMX2
	PSRAD		MMX0, SHIFTINVROW
	PSRAD		MMX7, SHIFTINVROW
	PACKSSDW	MMX3, MMX0
	PACKSSDW	MMX7, MMX4
	PSHUFW	MMX7, MMX7,  0B1H
END DCT8INVROWSSE;

PROCEDURE -DCT8INVCOLSSE;
CODE{SYSTEM.i386, SYSTEM.SSE, SYSTEM.MMX}
	MOV		EDI, [EBP-12]
	MOVQ		MMX1, [EDI]
	MOVQ		MMX2, MMX0
	MOVQ		MMX3, [EDX+48]
	PMULHW	MMX0, MMX1
	MOVQ		MMX4, [EDX+112]
	PMULHW	MMX1, MMX3
	MOV		EDI, [EBP-4]
	MOVQ		MMX5, [EDI]
	MOVQ		MMX6, MMX4
	PMULHW	MMX4, MMX5
	PADDSW	MMX0, MMX2
	PMULHW	MMX5, [EDX+16]
	PADDSW	MMX1, MMX3
	MOVQ		MMX7, [EDX+96]
	PADDSW	MMX0, MMX3
	MOV		EDI, [EBP-8]
	MOVQ		MMX3, [EDI]
	PSUBSW	MMX2, MMX1
	PMULHW	MMX7, MMX3
	MOVQ		MMX1, MMX0
	PMULHW	MMX3, [EDX-32]
	PSUBSW	MMX5, MMX6
	PADDSW	MMX4, [EDX+16]
	PADDSW	MMX0, MMX4
	MOV		EDI, [EBP-20]
	PADDSW	MMX0, [EDI]
	PSUBSW	MMX4, MMX1
	PADDSW	MMX7, [EDX+32]
	MOVQ		MMX6, MMX5
	PSUBSW	MMX3, [EDX+96]
	PSUBSW	MMX5, MMX2
	MOV		EDI, [EBP-20]
	PADDSW	MMX5, [EDI]
	PADDSW	MMX6, MMX2
	MOVQ		[EDX+112], MMX0
	MOVQ		MMX1, MMX4
	MOV		EDI, [EBP-16]
	MOVQ		MMX2, [EDI]
	PADDSW	MMX4, MMX5
	MOV		EDI, [EBP]
	MOVQ		MMX0, [EDI-16]
	PMULHW	MMX2, MMX4
	MOVQ		[EDX+48], MMX6
	PSUBSW	MMX1, MMX5
	MOVQ		MMX6, [EDX]
	PMULHW	MMX0, MMX1
	MOVQ		MMX5, [EDX+64]
	PADDSW	MMX4, MMX2
	MOV		EDI, [EBP-20]
	POR		MMX4, [EDI]
	PADDSW	MMX5, MMX6
	PSUBSW	MMX6, [EDX+64]
	PADDSW	MMX0, MMX1
	MOV		EDI, [EBP-20]
	POR		MMX0, [EDI]
	MOVQ		MMX2, MMX5
	PADDSW	MMX5, MMX7
	MOVQ		MMX1, MMX6
	MOV		EDI, [EBP-24]
	PADDSW	MMX5, [EDI]
	PSUBSW	MMX2, MMX7
	MOVQ		MMX7, [EDX+112]
	PADDSW	MMX6, MMX3
	MOV		EDI, [EBP-24]
	PADDSW	MMX6, [EDI]
	PADDSW	MMX7, MMX5
	PSRAW		MMX7, SHIFTINVCOL
	PSUBSW	MMX1, MMX3
	MOV		EDI, [EBP-28]
	PADDSW	MMX2, [EDI]
	MOVQ		MMX3, MMX6
	MOV		EDI, [EBP-28]
	PADDSW	MMX1, [EDI]
	PADDSW	MMX6, MMX4
	MOVQ		[EDX], MMX7
	PSRAW		MMX6, SHIFTINVCOL
	MOVQ		MMX7, MMX1
	PADDSW	MMX1, MMX0
	MOVQ		[EDX+16], MMX6
	PSRAW		MMX1, SHIFTINVCOL
	MOVQ		MMX6, [EDX+48]
	PSUBSW	MMX7, MMX0
	PADDSW	MMX6, MMX2
	PSUBSW	MMX2, [EDX+48]
	PSRAW		MMX7, SHIFTINVCOL
	MOVQ		[EDX+32], MMX1
	PSRAW		MMX6, SHIFTINVCOL
	PSUBSW	MMX5, [EDX+112]
	PSRAW		MMX2, SHIFTINVCOL
	MOVQ		[EDX+48], MMX6
	PSUBSW	MMX3, MMX4
	MOVQ		[EDX+64], MMX2
	PSRAW		MMX3, SHIFTINVCOL
	MOVQ		[EDX+80], MMX7
	PSRAW		MMX5, SHIFTINVCOL
	MOVQ		[EDX+96], MMX3
	MOVQ		[EDX+112], MMX5
END DCT8INVCOLSSE;

PROCEDURE TransformINT*(src, dst: LONGINT);
VAR i: LONGINT;
BEGIN

	Row(src + 0);
	Row(src + 16);
	Row(src + 32);
	Row(src + 48);
	Row(src + 64);
	Row(src + 80);
	Row(src + 96);
	Row(src + 112);

	Col( src +  0);
	Col( src +  2);
	Col( src +  4);
	Col( src +  6);
	Col( src +  8);
	Col( src +  10);
	Col( src +  12);
	Col( src +  14);

	FOR i := 0 TO 63 DO
		SYSTEM.PUT16(dst + SIZEOF(INTEGER) * i, SYSTEM.GET16(src + SIZEOF(INTEGER) * i) )
	END

END TransformINT;




(* row (horizontal) IDCT

  7                       pi         1 dst[k] = sum c[l] * src[l] * cos( -- *
  	( k + - ) * l ) l=0                      8          2

  		where: c[0]    = 128 c[1..7] = 128*sqrt(2)
*)


PROCEDURE Row( src: LONGINT);
VAR
	x0, x1, x2, x3, x4, x5, x6, x7, x8: LONGINT;
	adr, tempAdr: LONGINT;
BEGIN
	adr := src;

	(* shortcut *)
	x1 := LONG(SYSTEM.GET16( adr + 4*SIZEOF(INTEGER))) * 2048;
	x2 := LONG(SYSTEM.GET16( adr + 6*SIZEOF(INTEGER)));
	x3 := LONG(SYSTEM.GET16( adr + 2*SIZEOF(INTEGER)));
	x4 := LONG(SYSTEM.GET16( adr + 1*SIZEOF(INTEGER)));
	x5 := LONG(SYSTEM.GET16( adr + 7*SIZEOF(INTEGER)));
	x6 := LONG(SYSTEM.GET16( adr + 5*SIZEOF(INTEGER)));
	x7 := LONG(SYSTEM.GET16( adr + 3*SIZEOF(INTEGER)));

	IF ( x1 = 0 ) & ( x2 = 0 ) & ( x3 = 0 ) & ( x4 = 0 ) & ( x5 = 0 ) & ( x6 = 0 ) & ( x7 = 0 )  THEN
		x0 := SYSTEM.GET16( adr ) * 8;
		SYSTEM.PUT16( adr , x0 );
		tempAdr := adr + SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr, SHORT(x0));
		tempAdr := tempAdr + SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr, SHORT(x0));
		tempAdr := tempAdr + SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr, SHORT(x0));
		tempAdr := tempAdr + SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr, SHORT(x0));
		tempAdr := tempAdr + SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr, SHORT(x0));
		tempAdr := tempAdr + SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr, SHORT(x0));
		tempAdr := tempAdr + SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr, SHORT(x0));
		RETURN
	END;
	x0 := ( LONG(SYSTEM.GET16( adr )) * 2048 ) + 128;    (* for proper rounding in the fourth stage *)

	(* first stage *)
	x8 := W7 * ( x4 + x5 );
	x4 := x8 + ( W1 - W7 ) * x4;
	x5 := x8 - ( W1 + W7 ) * x5;
	x8 := W3 * ( x6 + x7 );
	x6 := x8 - ( W3 - W5 ) * x6;
	x7 := x8 - ( W3 + W5 ) * x7;

	(* second stage *)
	x8 := x0 + x1;
	x0 := x0 - x1;
	x1 := W6 * ( x3 + x2 );
	x2 := x1 - ( W2 + W6 ) * x2;
	x3 := x1 + ( W2 - W6 ) * x3;
	x1 := x4 + x6;
	x4 := x4 - x6;
	x6 := x5 + x7;
	x5 := x5 - x7;

	(* third stage *)
	x7 := x8 + x3;
	x8 := x8 - x3;
	x3 := x0 + x2;
	x0 := x0 - x2;
	x2 := ( 181 * ( x4 + x5 ) + 128 ) DIV 256;
	x4 := ( 181 * ( x4 - x5 ) + 128 ) DIV 256;




	(* fourth stage *)
	SYSTEM.PUT16( adr, SHORT(( x7 + x1 ) DIV 256));
	tempAdr := adr + SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SHORT(( x3 + x2 ) DIV 256));
	tempAdr := tempAdr + SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SHORT(( x0 + x4 ) DIV 256));
	tempAdr := tempAdr + SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SHORT(( x8 + x6 ) DIV 256));
	tempAdr := tempAdr + SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SHORT(( x8 - x6 ) DIV 256));
	tempAdr := tempAdr + SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SHORT(( x0 - x4 ) DIV 256));
	tempAdr := tempAdr + SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SHORT(( x3 - x2 ) DIV 256));
	tempAdr := tempAdr + SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SHORT(( x7 - x1 ) DIV 256))
END Row;

(* column (vertical) IDCT

 	 7                         pi         1 dst[8*k] = sum c[l] * src[8*l] *
 	 cos( -- * ( k + - ) * l ) l=0                        8          2

 	 where: c[0]    = 1/1024 c[1..7] = (1/1024)*sqrt(2)
*)
PROCEDURE Col( src: LONGINT);
VAR
	x0, x1, x2, x3, x4, x5, x6, x7, x8: LONGINT;
	adr, tempAdr, sourceAdr: LONGINT;
BEGIN
	adr := src;

	(* shortcut *)
	x1 := LONG(SYSTEM.GET16( adr + 32*SIZEOF(INTEGER))) * 256;
	x2 := LONG(SYSTEM.GET16( adr + 48*SIZEOF(INTEGER)));
	x3 := LONG(SYSTEM.GET16( adr + 16*SIZEOF(INTEGER)));
	x4 := LONG(SYSTEM.GET16( adr + 8*SIZEOF(INTEGER)));
	x5 := LONG(SYSTEM.GET16( adr + 56*SIZEOF(INTEGER)));
	x6 := LONG(SYSTEM.GET16( adr + 40*SIZEOF(INTEGER)));
	x7 := LONG(SYSTEM.GET16( adr + 24*SIZEOF(INTEGER)));

	IF ( x1 = 0 ) & ( x2 = 0 ) & ( x3 = 0 ) & ( x4 = 0 ) & ( x5 = 0 ) & ( x6 = 0 ) & ( x7 = 0 )  THEN
		x0 := LONG(intTab[(( SYSTEM.GET16(adr) + 32 ) DIV 64 ) + 512]);
		SYSTEM.PUT16( adr , SHORT(x0));
		tempAdr := adr + 8*SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr , SHORT(x0));
		tempAdr := tempAdr + 8*SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr , SHORT(x0));
		tempAdr := tempAdr + 8*SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr , SHORT(x0));
		tempAdr := tempAdr + 8*SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr , SHORT(x0));
		tempAdr := tempAdr + 8*SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr , SHORT(x0));
		tempAdr := tempAdr + 8*SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr , SHORT(x0));
		tempAdr := tempAdr + 8*SIZEOF( INTEGER );
		SYSTEM.PUT16( tempAdr , SHORT(x0));
		RETURN
	END;

	 x0 := (LONG(SYSTEM.GET16( adr))* 256) + 8192;

	(* first stage *)
	x8 := W7 * ( x4 + x5 ) + 4;
	x4 := ( x8 + ( W1 - W7 ) * x4 ) DIV 8;
	x5 := ( x8 - ( W1 + W7) * x5 ) DIV 8;
	x8 := W3 * ( x6 + x7 ) + 4;
	x6 := ( x8 - ( W3 - W5 ) * x6 )DIV 8;
	x7 := ( x8 - ( W3 + W5 ) * x7 ) DIV 8;

	(* second stage *)
	x8 := x0 + x1;
	x0 := x0 - x1;
	x1 := W6 * ( x3 + x2 ) + 4;
	x2 := ( x1 - ( W2 + W6 ) * x2 ) DIV 8;
	x3 := ( x1 + ( W2 - W6 ) * x3 ) DIV 8;
	x1 := x4 + x6;
	x4 := x4 - x6;
	x6 := x5 + x7;
	x5 := x5 - x7;

	(* third stage *)
	x7 := x8 + x3;
	x8 := x8 - x3;
	x3 := x0 + x2;
	x0 := x0 - x2;
	x2 := ( 181 * ( x4 + x5 ) + 128 ) DIV 256;
	x4 := ( 181 * ( x4 - x5 ) + 128 ) DIV 256;



	(* fourth stage *)
	tempAdr := adr;
	sourceAdr := ADDRESSOF( intTab[512] );
	SYSTEM.PUT16( tempAdr, SYSTEM.GET16( ( ( ( x7 + x1 ) DIV 16384 )*SIZEOF(INTEGER) ) + sourceAdr ));
	tempAdr := tempAdr + 8*SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SYSTEM.GET16( ( ( ( x3 + x2 ) DIV 16384 )*SIZEOF(INTEGER) ) + sourceAdr ));
	tempAdr := tempAdr + 8*SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SYSTEM.GET16( ( ( ( x0 + x4 ) DIV 16384 )*SIZEOF(INTEGER) ) + sourceAdr ));
	tempAdr := tempAdr + 8*SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SYSTEM.GET16( ( ( ( x8 + x6 ) DIV 16384 )*SIZEOF(INTEGER) ) + sourceAdr ));
	tempAdr := tempAdr + 8*SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SYSTEM.GET16( ( ( ( x8 - x6 ) DIV 16384 )*SIZEOF(INTEGER) ) + sourceAdr ));
	tempAdr := tempAdr + 8*SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SYSTEM.GET16( ( ( ( x0 - x4 ) DIV 16384 )*SIZEOF(INTEGER) ) + sourceAdr ));
	tempAdr := tempAdr + 8*SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SYSTEM.GET16( ( ( ( x3 - x2 ) DIV 16384 )*SIZEOF(INTEGER) ) + sourceAdr ));
	tempAdr := tempAdr + 8*SIZEOF( INTEGER );
	SYSTEM.PUT16( tempAdr, SYSTEM.GET16( ( ( ( x7 - x1 ) DIV 16384 )*SIZEOF(INTEGER) ) + sourceAdr ))
END Col;

PROCEDURE FillTablesSSE2;
VAR i: LONGINT;
BEGIN
	NEW(M128onecorr, 12);
	FOR i := 4 TO 11 DO M128onecorr[i] := 1 END;
	onecorradr := ADDRESSOF(M128onecorr[4]);

	NEW(M128roundinvrow, 12);
	M128roundinvrow[4] := RNDINVROW; M128roundinvrow[5] := 0; M128roundinvrow[6] := RNDINVROW; M128roundinvrow[7] := 0;
	M128roundinvrow[8] := RNDINVROW; M128roundinvrow[9] := 0; M128roundinvrow[10] := RNDINVROW; M128roundinvrow[11] := 0;
	roundinvrowadr := ADDRESSOF(M128roundinvrow[4]);

	NEW(M128roundinvcol, 12);
	FOR i := 4 TO 11 DO M128roundinvcol[i] := RNDINVCOL END;
	roundinvcoladr := ADDRESSOF(M128roundinvcol[4]);

	NEW(M128roundinvcorr, 12);
	FOR i := 4 TO 11 DO M128roundinvcorr[i] := RNDINVCORR END;
	roundinvcorradr := ADDRESSOF(M128roundinvcorr[4]);

	NEW(M128tg116, 12);
	FOR i := 4 TO 11 DO M128tg116[i] := 13036 END;
	tg116adr := ADDRESSOF(M128tg116[4]);

	NEW(M128tg216, 12);
	FOR i := 4 TO 11 DO M128tg216[i] := 21746 END;
	tg216adr := ADDRESSOF(M128tg216[4]);

	NEW(M128tg316, 12);
	FOR i := 4 TO 11 DO M128tg316[i] := -21746 END;
	tg316adr := ADDRESSOF(M128tg316[4]);

	NEW(M128cos416, 12);
	FOR i := 4 TO 11 DO M128cos416[i] := -19195 END;
	cos416adr := ADDRESSOF(M128cos416[4]);

	NEW(M128tabi04, 36);
	M128tabi04[4] 	:= 16384; 	M128tabi04[5] 	:= 21407; 	M128tabi04[6] 	:= 16384; 	M128tabi04[7] := 8867;
	M128tabi04[8] 	:= 16384; 	M128tabi04[9] 	:= -8867; 	M128tabi04[10]	:= 16384; 	M128tabi04[11] := -21407;
	M128tabi04[12] := 16384; 	M128tabi04[13]	:= 8867; 	M128tabi04[14] := -16384; 	M128tabi04[15] := -21407;
	M128tabi04[16] := -16384; 	M128tabi04[17] := 21407; 	M128tabi04[18] := 16384; 	M128tabi04[19] := -8867;
	M128tabi04[20] := 22725; 	M128tabi04[21]	:= 19266; 	M128tabi04[22]	:= 19266; 	M128tabi04[23] := -4520;
	M128tabi04[24] := 12873; 	M128tabi04[25]	:= -22725; 	M128tabi04[26]	:= 4520; 	M128tabi04[27] := -12873;
	M128tabi04[28] := 12873; 	M128tabi04[29]	:= 4520; 	M128tabi04[30] := -22725; 	M128tabi04[31] := -12873;
	M128tabi04[32] := 4520; 	M128tabi04[33] := 19266; 	M128tabi04[34] := 19266; 	M128tabi04[35] := -22725;
	tabi04adr := ADDRESSOF(M128tabi04[4]);

	NEW(M128tabi17, 36);
	M128tabi17[4] 	:= 22725; 	M128tabi17[5] 	:= 29692; 	M128tabi17[6] 	:= 22725; 	M128tabi17[7] := 12299;
	M128tabi17[8] 	:= 22725; 	M128tabi17[9] 	:= -12299; 	M128tabi17[10] := 22725; 	M128tabi17[11] := -29692;
	M128tabi17[12] := 22725; 	M128tabi17[13] := 12299; 	M128tabi17[14] := -22725; 	M128tabi17[15] := -29692;
	M128tabi17[16] := -22725; 	M128tabi17[17] := 29692; 	M128tabi17[18] := 22725; 	M128tabi17[19] := -12299;
	M128tabi17[20] := 31521; 	M128tabi17[21]	:= 26722; 	M128tabi17[22]	:= 26722; 	M128tabi17[23] := -6270;
	M128tabi17[24] := 17855; 	M128tabi17[25]	:= -31521; 	M128tabi17[26]	:= 6270; 	M128tabi17[27] := -17855;
	M128tabi17[28] := 17855; 	M128tabi17[29]	:= 6270; 	M128tabi17[30] := -31521; 	M128tabi17[31] := -17855;
	M128tabi17[32] := 6270; 	M128tabi17[33] := 26722; 	M128tabi17[34] := 26722; 	M128tabi17[35] := -31521;
	tabi17adr := ADDRESSOF(M128tabi17[4]);

	NEW(M128tabi26, 36);
	M128tabi26[4] 	:= 21407; 	M128tabi26[5] 	:= 27969; 	M128tabi26[6] 	:= 21407; 	M128tabi26[7] := 11585;
	M128tabi26[8] 	:= 21407; 	M128tabi26[9] 	:= -11585; 	M128tabi26[10] := 21407; 	M128tabi26[11] := -27969;
	M128tabi26[12] := 21407; 	M128tabi26[13] := 11585; 	M128tabi26[14] := -21407; 	M128tabi26[15] := -27969;
	M128tabi26[16] := -21407; 	M128tabi26[17] := 27969; 	M128tabi26[18] := 21407; 	M128tabi26[19] := -11585;
	M128tabi26[20] := 29692; 	M128tabi26[21]	:= 25172; 	M128tabi26[22]	:= 25172; 	M128tabi26[23] := -5906;
	M128tabi26[24] := 16819; 	M128tabi26[25]	:= -29692; 	M128tabi26[26]	:= 5906; 	M128tabi26[27] := -16819;
	M128tabi26[28] := 16819; 	M128tabi26[29]	:= 5906; 	M128tabi26[30] := -29692; 	M128tabi26[31] := -16819;
	M128tabi26[32] := 5906; 	M128tabi26[33] := 25172; 	M128tabi26[34] := 25172; 	M128tabi26[35] := -29692;
	tabi26adr := ADDRESSOF(M128tabi26[4]);

	NEW(M128tabi35, 36);
	M128tabi35[4] 	:= 19266; 	M128tabi35[5] 	:= 25172; 	M128tabi35[6] 	:= 19266; 	M128tabi35[7] := 10426;
	M128tabi35[8] 	:= 19266; 	M128tabi35[9] 	:= -10426; 	M128tabi35[10] := 19266; 	M128tabi35[11] := -25172;
	M128tabi35[12] := 19266; 	M128tabi35[13]	:= 10426; 	M128tabi35[14] := -19266; 	M128tabi35[15] := -25172;
	M128tabi35[16] := -19266; 	M128tabi35[17] := 25172; 	M128tabi35[18] := 19266; 	M128tabi35[19] := -10426;
	M128tabi35[20] := 26722; 	M128tabi35[21]	:= 22654; 	M128tabi35[22]	:= 22654; 	M128tabi35[23] := -5315;
	M128tabi35[24] := 15137; 	M128tabi35[25]	:= -26722; 	M128tabi35[26]	:= 5315; 	M128tabi35[27] := -15137;
	M128tabi35[28] := 15137; 	M128tabi35[29]	:= 5315; 	M128tabi35[30] := -26722; 	M128tabi35[31] := -15137;
	M128tabi35[32] := 5315; 	M128tabi35[33] := 22654; 	M128tabi35[34] := 22654; 	M128tabi35[35] := -26722;
	tabi35adr := ADDRESSOF(M128tabi35[4]);

END FillTablesSSE2;

PROCEDURE FillTablesSSE;
VAR i: LONGINT;
BEGIN
	NEW(M128onecorr, 4);
	FOR i := 0 TO 3 DO M128onecorr[i] := 1 END;
	onecorradr := ADDRESSOF(M128onecorr[0]);

	NEW(M128roundinvrow, 4);
	M128roundinvrow[0] := RNDINVROW; M128roundinvrow[1] := 0; M128roundinvrow[2] := RNDINVROW; M128roundinvrow[3] := 0;
	roundinvrowadr := ADDRESSOF(M128roundinvrow[0]);

	NEW(M128roundinvcol, 4);
	FOR i := 0 TO 3 DO M128roundinvcol[i] := RNDINVCOL END;
	roundinvcoladr := ADDRESSOF(M128roundinvcol[0]);

	NEW(M128roundinvcorr, 4);
	FOR i := 0 TO 3 DO M128roundinvcorr[i] := RNDINVCORR END;
	roundinvcorradr := ADDRESSOF(M128roundinvcorr[0]);

	NEW(M128tg116, 4);
	FOR i := 0 TO 3 DO M128tg116[i] := 13036 END;
	tg116adr := ADDRESSOF(M128tg116[0]);

	NEW(M128tg216, 4);
	FOR i := 0 TO 3 DO M128tg216[i] := 21746 END;
	tg216adr := ADDRESSOF(M128tg216[0]);

	NEW(M128tg316, 4);
	FOR i := 0 TO 3 DO M128tg316[i] := -21746 END;
	tg316adr := ADDRESSOF(M128tg316[0]);

	NEW(M128cos416, 4);
	FOR i := 0 TO 3 DO M128cos416[i] := -19195 END;
	cos416adr := ADDRESSOF(M128cos416[0]);

	NEW(M128tabi04, 32);
	M128tabi04[0] 	:= 16384; 	M128tabi04[1] 	:= 21407; 	M128tabi04[2] 	:= 16384; 	M128tabi04[3] 	:= 8867;
	M128tabi04[4] 	:= 16384; 	M128tabi04[5] 	:= 8867; 	M128tabi04[6]	:= -16384; 	M128tabi04[7] 	:= -21407;
	M128tabi04[8] 	:= 16384; 	M128tabi04[9]	:= -8867; 	M128tabi04[10] := 16384; 	M128tabi04[11] := -21407;
	M128tabi04[12] := -16384; 	M128tabi04[13] := 21407; 	M128tabi04[14] := 16384; 	M128tabi04[15] := -8867;
	M128tabi04[16] := 22725; 	M128tabi04[17]	:= 19266; 	M128tabi04[18]	:= 19266; 	M128tabi04[19] := -4520;
	M128tabi04[20] := 12873; 	M128tabi04[21]	:= 4520; 	M128tabi04[22]	:= -22725; 	M128tabi04[23] := -12873;
	M128tabi04[24] := 12873; 	M128tabi04[25]	:= -22725; 	M128tabi04[26] := 4520; 	M128tabi04[27] := -12873;
	M128tabi04[28] := 4520; 	M128tabi04[29] := 19266; 	M128tabi04[30] := 19266; 	M128tabi04[31] := -22725;
	tabi04adr := ADDRESSOF(M128tabi04[0]);

	NEW(M128tabi17, 32);
	M128tabi17[0] 	:= 22725; 	M128tabi17[1] 	:= 29692; 	M128tabi17[2] 	:= 22725; 	M128tabi17[3] 	:= 12299;
	M128tabi17[4] 	:= 22725; 	M128tabi17[5] 	:= 12299; 	M128tabi17[6] := -22725; 	M128tabi17[7] 	:= -29692;
	M128tabi17[8] 	:= 22725; 	M128tabi17[9] 	:= -12299; 	M128tabi17[10] := 22725; 	M128tabi17[11] := -29692;
	M128tabi17[12] := -22725; 	M128tabi17[13] := 29692; 	M128tabi17[14] := 22725; 	M128tabi17[15] := -12299;
	M128tabi17[16] := 31521; 	M128tabi17[17]	:= 26722; 	M128tabi17[18]	:= 26722; 	M128tabi17[19] := -6270;
	M128tabi17[20] := 17855; 	M128tabi17[21]	:= 6270; 	M128tabi17[22]	:= -31521; 	M128tabi17[23] := -17855;
	M128tabi17[24] := 17855; 	M128tabi17[25]	:= -31521; 	M128tabi17[26] := 6270; 	M128tabi17[27] := -17855;
	M128tabi17[28] := 6270; 	M128tabi17[29] := 26722; 	M128tabi17[30] := 26722; 	M128tabi17[31] := -31521;
	tabi17adr := ADDRESSOF(M128tabi17[0]);

	NEW(M128tabi26, 32);
	M128tabi26[0] 	:= 21407; 	M128tabi26[1] 	:= 27969; 	M128tabi26[2] 	:= 21407; 	M128tabi26[3] 	:= 11585;
	M128tabi26[4] 	:= 21407; 	M128tabi26[5] 	:= 11585; 	M128tabi26[6] := -21407; 	M128tabi26[7] 	:= -27969;
	M128tabi26[8] 	:= 21407; 	M128tabi26[9] 	:= -11585; 	M128tabi26[10] := 21407; 	M128tabi26[11] := -27969;
	M128tabi26[12] := -21407; 	M128tabi26[13] := 27969; 	M128tabi26[14] := 21407; 	M128tabi26[15] := -11585;
	M128tabi26[16] := 29692; 	M128tabi26[17]	:= 25172; 	M128tabi26[18]	:= 25172; 	M128tabi26[19] := -5906;
	M128tabi26[20] := 16819; 	M128tabi26[21]	:= 5906; 	M128tabi26[22]	:= -29692; 	M128tabi26[23] := -16819;
	M128tabi26[24] := 16819; 	M128tabi26[25]	:= -29692; 	M128tabi26[26] := 5906; 	M128tabi26[27] := -16819;
	M128tabi26[28] := 5906; 	M128tabi26[29] := 25172; 	M128tabi26[30] := 25172; 	M128tabi26[31] := -29692;
	tabi26adr := ADDRESSOF(M128tabi26[0]);

	NEW(M128tabi35, 32);
	M128tabi35[0] 	:= 19266; 	M128tabi35[1] 	:= 25172; 	M128tabi35[2] 	:= 19266; 	M128tabi35[3] 	:= 10426;
	M128tabi35[4] 	:= 19266; 	M128tabi35[5] 	:= 10426; 	M128tabi35[6] 	:= -19266; 	M128tabi35[7] 	:= -25172;
	M128tabi35[8] 	:= 19266; 	M128tabi35[9]	:= -10426; 	M128tabi35[10] := 19266; 	M128tabi35[11] := -25172;
	M128tabi35[12] := -19266; 	M128tabi35[13] := 25172; 	M128tabi35[14] := 19266; 	M128tabi35[15] := -10426;
	M128tabi35[16] := 26722; 	M128tabi35[17]	:= 22654; 	M128tabi35[18]	:= 22654; 	M128tabi35[19] := -5315;
	M128tabi35[20] := 15137; 	M128tabi35[21]	:= 5315; 	M128tabi35[22]	:= -26722; 	M128tabi35[23] := -15137;
	M128tabi35[24] := 15137; 	M128tabi35[25]	:= -26722; 	M128tabi35[26] := 5315; 	M128tabi35[27] := -15137;
	M128tabi35[28] := 5315; 	M128tabi35[29] := 22654; 	M128tabi35[30] := 22654; 	M128tabi35[31] := -26722;
	tabi35adr := ADDRESSOF(M128tabi35[0]);
END FillTablesSSE;

PROCEDURE FillTablesINT;
VAR i: INTEGER;
BEGIN
	NEW(intTab, 1024);
	FOR i := -512 TO 511 DO
		IF i < -256 THEN
			intTab[i + 512] := -256
		ELSIF i > 255 THEN
			intTab[i + 512] := 255
		ELSE
			intTab[i + 512] := i
		END;
	END;
END FillTablesINT;



PROCEDURE CheckFeatures;
BEGIN

	(* SSE requires special alignment of data blocks which has changed
	since new heap datastructures were introduced in revision 1620 *)

	IF FALSE & Machine.SSE2Support THEN
		FillTablesSSE2;
		Transform := TransformSSE2;
		status := SSE2;
		KernelLog.String("IDCT: SSE2 method"); KernelLog.Ln;
	ELSIF FALSE & Machine.SSESupport THEN
		FillTablesSSE;
		Transform := TransformSSE;
		status := SSE;
		KernelLog.String("IDCT: SSE method"); KernelLog.Ln;
	ELSE
		FillTablesINT;
		Transform := TransformINT;
		status := INT;
		KernelLog.String("IDCT: INT method"); KernelLog.Ln;
	END
END CheckFeatures;

(* !!! Unsafe *)
PROCEDURE Change*(context : Commands.Context);
VAR name: ARRAY 12 OF CHAR;
BEGIN
	context.arg.String(name);

	IF name = "SSE2" THEN
		FillTablesSSE2;
		Transform := TransformSSE2;
		status := SSE2;
		context.out.String("IDCT: SSE2 method"); context.out.Ln;
	ELSIF name = "SSE" THEN
		FillTablesSSE;
		Transform := TransformSSE;
		status := SSE;
		context.out.String("IDCT: SSE method"); context.out.Ln;
	ELSIF name = "INT" THEN
		FillTablesINT;
		Transform := TransformINT;
		status := INT;
		context.out.String("IDCT: INT method"); context.out.Ln;
	ELSE
		CheckFeatures;
	END;
END Change;

BEGIN
	RNDINVROW := 1024 * (6 - BITSINVACC);
	RNDINVCOL := 16 * (BITSINVACC - 3);
	RNDINVCORR := RNDINVCOL - 1;
	CheckFeatures;
END IDCT.

IDCT.Change INT ~
IDCT.Change SSE ~
IDCT.Change SSE2 ~

IDCT.Obx ~
SystemTools.Free IDCT ~