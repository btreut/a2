MODULE EFIMachine; (** AUTHOR ""; PURPOSE ""; *)

IMPORT SYSTEM, EFI;

VAR p0, p1: ADDRESS;

(*  I386.Machine.Mod uses following registers as arguments:
	eax	: bootFlag (= address of boot table)
	esi	: ?
	edi	: address of frame buffer
*)

(*GO: Changed this to also do the move

	esi	: kernelSize

		PUSH DWORD 0
	PUSH DWORD 0
	LIDT [RSP]
	INT 3

*)
PROCEDURE JumpTo*(adr : ADDRESS; btAddr, kernelSize, fbAddr, memmapAddr : HUGEINT);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	MOV R15, [RBP+fbAddr];  fbAddr
	MOV R14, [RBP+kernelSize]; kernelSize
	MOV R13, [RBP+btAddr]; btAddr
	MOV R12, [RBP+adr]; kernelAddr
	MOV R11, [RBP+memmapAddr]; memmapAddr;
	MOV R10, 1H; flag to notifiy we are coming from efi
NT:	CALL NZ
NZ: 	
	POP RCX
	ADD RCX, NX-NZ; we copy the currently executing code to page 0 (1 page of code)
	MOV RDI, 1000H
	MOV RSI, RCX
	MOV RCX, 512
	CLD
	REP MOVSQ
	
	MOV RCX, 1000H
	JMP RCX ;then we jump to it - we do this to make sure we dont overwrite our running code with the image we are going to move


NX:
	MOV RCX, R14  ; move the image
	MOV RDI, 2000H ; to 1000 hex
	MOV RSI, R12
	CLD
	REP MOVSB


	XOR RCX,RCX
	XOR RDX,RDX
	MOV RDI, R15;
	MOV RSI, R14;
	MOV RAX, R13;
	MOV RBX, 2000H; ;start the image
	CALL RBX

END JumpTo;
(*
	MOV R15, [RBP+fbAddr];  fbAddr
	MOV R14, [RBP+kernelSize]; kernelSize
	MOV R13, [RBP+btAddr]; btAddr
	MOV R12, [RBP+kernelAddr]; kernelAddr

NT:	CALL NZ
NZ: 	POP RCX
	MOV RDI, 0
	MOV RSI, RCX
	MOV RCX, 512
	CLD
	REP MOVSQ
	MOV RCX, 0
	ADD RCX, NX-NZ

	JMP RCX


NX:

	MOV RCX, R14
	MOV RDI, 1000H
	MOV RSI, R12
	CLD
	REP MOVSB


	XOR RCX,RCX
	XOR RDX,RDX
	MOV RDI, R15;
	MOV RSI, R14;
	MOV RAX, R13;
	MOV RBX, 1000H;
	CALL RBX
END JumpTo;
*)

PROCEDURE {NOPAF, FIXED(401000H)} EntryPoint;
CODE {SYSTEM.AMD64}
	MOV QWORD EFI.imageHandle, RCX;
	MOV QWORD EFI.table, RDX
END EntryPoint;

END EFIMachine.


