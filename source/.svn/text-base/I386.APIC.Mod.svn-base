(* Runtime support for APIC *)
(* Copyright (C) Florian Negele *)

(** Represents all logical processors of the system. *)
MODULE APIC;

IMPORT SYSTEM, CPU;

CONST Processors* = 32;
CONST ReservedArea* = Processors * CPU.StackSize;

CONST NMI* = {10}; INIT* = {8, 10}; STARTUP* = {9, 10};
CONST Assert* = {14}; AllExcludingSelf* = {18, 19};

CONST BootCodeSize = 119;

VAR baseAddress: ADDRESS;

PROCEDURE AwaitInterrupt-;
CODE
	HLT;
END AwaitInterrupt;

PROCEDURE SendInterrupt- (low, high: SET);
CONST ICRL = 300H; ICRH = 310H; Status = 12;
CODE
	MOV	EDX, baseAddress
	MOV	EAX, [EBP + high]
	MOV	[EDX + ICRH], EAX
	MOV	EAX, [EBP + low]
	MOV	[EDX + ICRL], EAX
wait:
	PAUSE
	BT		DWORD [EDX + ICRL], Status
	JC		wait
END SendInterrupt;

PROCEDURE CopyBootCode- (start: PROCEDURE {NORETURN});
CODE
	; copy bootstrap code
	PUSH	ECX
	MOV	EDI, 0
	MOV	ESI, BootCode
	MOV	ECX, BootCodeSize
	CLD
	REP MOVSB
	POP	ECX

	; patch start procedure
	MOV	EAX, [EBP + start]
	SUB	EAX, EDI
	MOV	[EDI - 4], EAX
END CopyBootCode;

PROCEDURE {NOPAF} BootCode;
CONST ID = 20H; Interrupts = CPU.Interrupts;
CODE
bootcodebegin:
	BITS	16
	
	; enter protected mode
	CLI
	DB		00fh, 001h, 016h, gdt32 - bootcodebegin, 000H
	MOV	EAX, CR0
	OR		EAX, 1
	MOV	CR0, EAX
	
	; prepare segment registers
	MOV	BX, 16
	MOV	DS, BX
	MOV	ES, BX
	MOV	FS, BX
	MOV	GS, BX
	MOV	SS, BX

	; activate protected mode
	DB		066h, 0eah, protected - bootcodebegin, 000h, 000h, 000h, 008h, 000h

gdt32:
	DW	gdt32end - gdt32begin
	DD		gdt32begin - bootcodebegin

gdt32begin:
	DD		0, 0
code32:	DB	0ffh, 0ffh, 000h, 000h, 000h, 09eh, 0cfh, 000h
data32:		DB	0ffh, 0ffh, 000h, 000h, 000h, 092h, 0cfh, 000h
gdt32end:
	
protected:
	BITS	32

	; create unique stack pointer
	MOV	EAX, baseAddress
	MOV	EAX, [EAX + ID]
	SHR	EAX, 24
	INC	EAX
	MOV	EBX, (ReservedArea - (bootcodeend - bootcodebegin)) / Processors / 4 * 4
	MUL	EBX
	MOV	ESP, EAX
	ADD	ESP, (bootcodeend - bootcodebegin) / 4 * 4
	LEA	EAX, CPU.idt
	PUSH	EAX
	MOV	AX, Interrupts * 8
	PUSH	AX
	LIDT	[ESP]

	; jump to start procedure
	JMP	DWORD 0

bootcodeend:
	; "static assert"
	MOV AL, (bootcodeend - bootcodebegin - BootCodeSize) * 256
END BootCode;

PROCEDURE Initialize-;
CODE
	; check APIC availability
	PUSH	ECX
	MOV	EAX, 0
	CPUID
	CMP	EAX, 1
	JL		skip
	MOV	EAX, 1
	CPUID
	BT		EDX, 9
	JNC	skip

	; get APIC base address
	MOV	ECX, 0000001BH
	RDMSR
	AND	EAX, 0FFFFF000H
	MOV	EDX, EAX
	MOV	baseAddress, EDX
skip:
	POP	ECX
END Initialize;

END APIC.
