MODULE EFIMachine; (** AUTHOR ""; PURPOSE ""; *)

IMPORT SYSTEM, EFI;

(*  I386.Machine.Mod uses following registers as arguments:
	eax	: bootFlag (= address of boot table)
	esi	: ?
	edi	: address of frame buffer
*)
PROCEDURE JumpTo*(adr : ADDRESS; eax,esi,edi, ecx : LONGINT);
CODE {SYSTEM.i386}
	XOR ECX,ECX
	XOR EDX,EDX
	MOV EDI, [EBP+edi];
	MOV ESI, [EBP+esi];
	MOV EAX, [EBP+eax];
	MOV EBX, [EBP+adr];
	MOV ECX, [EBP+ecx];
	CALL EBX
END JumpTo;

PROCEDURE  Portin8*(port: LONGINT; VAR val: CHAR);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN AL, DX
	MOV ECX, [EBP+val]
	MOV [ECX], AL
END Portin8;

PROCEDURE  Portin16*(port: LONGINT; VAR val: INTEGER);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN AX, DX
	MOV ECX, [EBP+val]
	MOV [ECX], AX
END Portin16;

PROCEDURE  Portin32*(port: LONGINT; VAR val: LONGINT);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN EAX, DX
	MOV ECX, [EBP+val]
	MOV [ECX], EAX
END Portin32;

PROCEDURE  Portout8*(port: LONGINT; val: CHAR);
CODE{SYSTEM.i386}
	MOV AL,[EBP+val]
	MOV EDX,[EBP+port]
	OUT DX,AL
END Portout8;

PROCEDURE  Portout16*(port: LONGINT; val: INTEGER);
CODE{SYSTEM.i386}
	MOV AX,[EBP+val]
	MOV EDX,[EBP+port]
	OUT DX,AX
END Portout16;

PROCEDURE  Portout32*(port: LONGINT; val: LONGINT);
CODE{SYSTEM.i386}
	MOV EAX,[EBP+val]
	MOV EDX,[EBP+port]
	OUT DX,EAX
END Portout32;

PROCEDURE -GetParameter (offset: LONGINT): LONGINT;
CODE {SYSTEM.i386}
	POP EAX
	MOV EAX, [EBP+EAX]
END GetParameter;

BEGIN
	SYSTEM.PUT32 (ADDRESSOF (EFI.imageHandle), GetParameter (12));
	SYSTEM.PUT32 (ADDRESSOF (EFI.table), GetParameter (16));
END EFIMachine.
