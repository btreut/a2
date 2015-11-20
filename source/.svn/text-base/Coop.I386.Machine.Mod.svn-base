MODULE Machine;

IMPORT CPU, Environment, Trace, Mutexes, Processors;

CONST
	Version = "A2 Cooperative Revision 5791";

	MaxCPU* = Processors.Maximum;	(* dummy definition to make GC for both Win32 and I386 work *)

	DefaultObjectFileExtension* = ".Obw";

	(** bits in features variable *)
	MTTR* = 12;  MMX* = 23;

	debug* = FALSE;   (** display more debug output during booting *)

	IsCooperative*= TRUE;

CONST
(** standard lock levels (in order) *)  (* also refer to Traps.Show *)
	TraceOutput* = 0;   (* Trace output *)
	Memory* = 1;   (* Virtual memory management, stack and page allocation *)
	Heaps* = 2;   (* Storage allocation and Garbage collection *)
	Interrupts* = 3;   (* Interrupt handling. *)
	Modules* = 4;   (* Module list *)
	Objects* = 5;   (* Ready queue *)
	KernelLog* = 7;   (* Atomic output *)
	GC* = 8;
	MaxLocks = 9;   (* { <= 32 } *)

	(* error codes *)
	Ok* = 0;
	NilAdr* = -1;	(* nil value for addresses (not same as pointer NIL value) *)

	IRQ0* = CPU.IRQ0;
	MaxIRQ* = CPU.IRQ15;

TYPE
	Vendor* = ARRAY 13 OF CHAR;
	IDMap* = ARRAY 16 OF SHORTINT;

	Range* = RECORD
		adr*, size*: LONGINT
	END;

	MemoryBlock* = POINTER TO MemoryBlockDesc;
	MemoryBlockDesc* = RECORD
		next- {UNTRACED}: MemoryBlock;
		startAdr-: ADDRESS; 		(* sort key in linked list of memory blocks *)
		size-: SIZE;
		beginBlockAdr-, endBlockAdr-: ADDRESS
	END;

	(* dummy definition to make GC work for both I386 and Win32 - copied from I386.Machine.Mod, but not really used *)
	Stack* = RECORD	(** values are read-only *)
			low: ADDRESS;		(* lowest virtual address that may be allocated for stack *)
		adr*: ADDRESS;		(* lowest address on allocated stack *)	(* exported for Objects only *)
		high*: ADDRESS;	(* next virtual address after stack *)	(* exported for Objects only *)
	END;
	
	Address32* = LONGINT;

VAR



	MMXSupport*: BOOLEAN;
	SSESupport*: BOOLEAN;
	SSE2Support*: BOOLEAN;
	SSE3Support-: BOOLEAN; (* PH 04/11*)
	SSSE3Support-: BOOLEAN;
	SSE41Support-: BOOLEAN;
	SSE42Support-: BOOLEAN;
	SSE5Support-: BOOLEAN;
	AVXSupport-: BOOLEAN;

	version*: ARRAY 64 OF CHAR;   (** Aos version *)
	features*,features2*: SET;   (** processor features *)
	fcr*: SET;   (** default floating-point control register value (default rounding mode is towards -infinity, for ENTIER) *)
	mhz*: HUGEINT;   (** clock rate of GetTimer() in MHz, or 0 if not known *)
	boottime-: HUGEINT; (** in timer units *)

VAR
	lock-: ARRAY MaxLocks OF CHAR;  (* not implemented as SET because of shared access *)
	mutex: ARRAY MaxLocks OF Mutexes.Mutex;

	memBlockHead-{UNTRACED}, memBlockTail-{UNTRACED}: MemoryBlock; (* head and tail of sorted list of memory blocks *)


	(** Convert a string to an integer.  Parameter i specifies where in the string scanning should begin (usually 0 in the first call).  Scanning stops at the first non-valid character, and i returns the updated position.  Parameter s is the string to be scanned.  The value is returned as result, or 0 if not valid.  Syntax: number = ["-"] digit {digit} ["H" | "h"] .  digit = "0" | ... "9" | "A" .. "F" | "a" .. "f" .  If the number contains any hexdecimal letter, or if it ends in "H" or "h", it is interpreted as hexadecimal. *)

	PROCEDURE StrToInt*( VAR i: LONGINT;  CONST s: ARRAY OF CHAR ): LONGINT;
	VAR vd, vh, sgn, d: LONGINT;  hex: BOOLEAN;
	BEGIN
		vd := 0;  vh := 0;  hex := FALSE;
		IF s[i] = "-" THEN sgn := -1;  INC( i ) ELSE sgn := 1 END;
		LOOP
			IF (s[i] >= "0") & (s[i] <= "9") THEN d := ORD( s[i] ) - ORD( "0" )
			ELSIF (CAP( s[i] ) >= "A") & (CAP( s[i] ) <= "F") THEN d := ORD( CAP( s[i] ) ) - ORD( "A" ) + 10;  hex := TRUE
			ELSE EXIT
			END;
			vd := 10 * vd + d;  vh := 16 * vh + d;  INC( i )
		END;
		IF CAP( s[i] ) = "H" THEN hex := TRUE;  INC( i ) END;   (* optional H *)
		IF hex THEN vd := vh END;
		RETURN sgn * vd
	END StrToInt;
	(** -- Atomic operations -- *)

(** This procedure should be called in all spin loops as a hint to the processor (e.g. Pentium 4). *)

	PROCEDURE -SpinHint*;
	CODE {SYSTEM.i386}
		REP	NOP	;  PAUSE instruction (* NOP on pre-P4 processors, Spin Loop Hint on P4 and after *)
	END SpinHint;

(* Return current instruction pointer *)
PROCEDURE CurrentPC* (): ADDRESS;
CODE {SYSTEM.i386}
	MOV EAX, [EBP+4]
END CurrentPC;

(* Return current frame pointer *)
PROCEDURE -CurrentBP* (): ADDRESS;
CODE {SYSTEM.i386}
	MOV EAX, EBP
END CurrentBP;

(* Return current stack pointer *)
PROCEDURE -CurrentSP* (): ADDRESS;
CODE {SYSTEM.i386}
	MOV EAX, ESP
END CurrentSP;

PROCEDURE MapPhysical*(physAdr: ADDRESS; size: SIZE; VAR virtAdr: ADDRESS);
BEGIN
	virtAdr := physAdr;
END MapPhysical;

(** Unmap an area previously mapped with MapPhysical. *)
PROCEDURE UnmapPhysical*(virtAdr: ADDRESS; size: SIZE);
END UnmapPhysical;

(** Translate a virtual address range to num ranges of physical address. num returns 0 on error. *)
PROCEDURE TranslateVirtual*(virtAdr: ADDRESS; size: SIZE;  VAR num: LONGINT; VAR physAdr: ARRAY OF Range);
CONST PS = 4096;
VAR ofs, phys1: ADDRESS; size1: SIZE;
BEGIN
	num := 0;
	LOOP
		IF size = 0 THEN EXIT END;
		IF num = LEN(physAdr) THEN num := 0; EXIT END;	(* index check *)
		ofs := virtAdr MOD PS;	(* offset in page *)
		size1 := PS - ofs;	(* distance to next page boundary *)
		IF size1 > size THEN size1 := size END;
		phys1 := virtAdr - ofs;
		physAdr[num].adr := phys1 - phys1 MOD PS + ofs;
		physAdr[num].size := size1; INC(num);
		INC(virtAdr, size1); DEC(size, size1)
	END;
	IF num = 0 THEN physAdr[0].adr := NilAdr; physAdr[0].size := 0 END;
END TranslateVirtual;

PROCEDURE Ensure32BitAddress*(adr: ADDRESS): Address32;
BEGIN
	ASSERT (Address32 (adr) = adr);
	RETURN Address32 (adr);
END Ensure32BitAddress;

PROCEDURE Is32BitAddress*(adr: ADDRESS): BOOLEAN;
BEGIN RETURN Address32 (adr) = adr;
END Is32BitAddress;

(** Get parameter values from Init string. If n = 0, return val = ASH(bx, 16) + ax, and if n = 1, return val = ASH(dx, 16) + cx, where ax, bx, cx, dx are the register values after the OBL boot loader or noboot.exe have executed the 16-bit x86 code in the Init string. *)
PROCEDURE GetInit* (n: LONGINT; VAR val: LONGINT);
BEGIN Environment.GetInit (n, val);
END GetInit;

(** Fill "size" bytes at "destAdr" with "filler".  "size" must be multiple of 4. *)

	PROCEDURE Fill32*(destAdr: ADDRESS; size: SIZE; filler: LONGINT);
	CODE {SYSTEM.i386}
		PUSH	ECX
		MOV	EDI, [EBP+destAdr]
		MOV	ECX, [EBP+size]
		MOV	EAX, [EBP+filler]
		TEST	ECX, 3
		JZ	ok
		PUSH	8	;  ASSERT failure
		INT	3
		ok:
		SHR	ECX, 2
		CLD
		REP	STOSD
		POP	ECX
	END Fill32;

(** -- Processor initialization -- *)

	PROCEDURE -SetFCR( s: SET );
	CODE {SYSTEM.i386, SYSTEM.FPU}
		FLDCW	[ESP]	;  parameter s
		POP	EAX
	END SetFCR;

	PROCEDURE -FCR( ): SET;
	CODE {SYSTEM.i386, SYSTEM.FPU}
		PUSH	0
		FNSTCW	[ESP]
		FWAIT
		POP	EAX
	END FCR;

	PROCEDURE -InitFPU;
	CODE {SYSTEM.i386, SYSTEM.FPU}
		FNINIT
	END InitFPU;

(** CPU identification. *)

	PROCEDURE CPUID*( VAR vendor: Vendor;  VAR version: LONGINT;  VAR features1,features2: SET );
	CODE {SYSTEM.i386, SYSTEM.Pentium}
		PUSH	ECX
		MOV	EAX, 0
		CPUID
		CMP	EAX, 0
		JNE	ok
		MOV	ESI, [EBP+vendor]
		MOV	[ESI], AL	;  AL = 0
		MOV	ESI, [EBP+version]
		MOV	[ESI], EAX	;  EAX = 0
		MOV	ESI, [EBP+features1]
		MOV	[ESI], EAX
		MOV	ESI, [EBP+features2]
		MOV	[ESI], EAX
		JMP	end
		ok:
		MOV	ESI, [EBP+vendor]
		MOV	[ESI], EBX
		MOV	[ESI+4], EDX
		MOV	[ESI+8], ECX
		MOV	BYTE [ESI+12], 0
		MOV	EAX, 1
		CPUID
		MOV	ESI, [EBP+version]
		MOV	[ESI], EAX
		MOV	ESI, [EBP+features1]
		MOV	[ESI], EDX
		MOV	ESI, [EBP+features2]
		MOV	[ESI], ECX
		end:
		POP	ECX
	END CPUID;

	PROCEDURE GetConfig* ( CONST name: ARRAY OF CHAR;  VAR val: ARRAY OF CHAR );
	PROCEDURE GetString EXTERN "Environment.GetString" ( CONST name: ARRAY OF CHAR;  VAR val: ARRAY OF CHAR );
	BEGIN GetString (name, val);
	END GetConfig;

	PROCEDURE Shutdown*( restart: BOOLEAN );
	BEGIN
		IF restart THEN Environment.Reboot ELSE Environment.Shutdown END;
	END Shutdown;

PROCEDURE Cli*;
BEGIN HALT (1234);
END Cli;

PROCEDURE Sti*;
BEGIN HALT (1234);
END Sti;

(* Dan: from new Machine *)
PROCEDURE -GetTimer*(): HUGEINT;
CODE {SYSTEM.Pentium}
	RDTSC	; set EDX:EAX
END GetTimer;

(** Disable interrupts and return old interrupt state. *)
PROCEDURE -DisableInterrupts* (): SET;
CODE {SYSTEM.i386}
	PUSHFD
	CLI
	POP EAX
END DisableInterrupts;

(** Restore interrupt state. Parameter s must be return value of earlier DisableInterrupts call on same processor. *)
PROCEDURE -RestoreInterrupts* (s: SET);
CODE {SYSTEM.i386}
	POPFD
END RestoreInterrupts;

PROCEDURE ID*(): LONGINT;
BEGIN
	RETURN Processors.GetCurrentIndex ();
END ID;

(* setup MMX, SSE and SSE2..SSE5 and AVX extension *)

PROCEDURE -InitSSE;
CODE {SYSTEM.Pentium, SYSTEM.Privileged}
	MOV	EAX, CR4
	OR	EAX, 00000200H		; set bit 9 (OSFXSR)
	AND	EAX, 0FFFFFBFFH	; delete bit 10 (OSXMMEXCPT)
	MOV	CR4, EAX
END InitSSE;

PROCEDURE InitBootProcessor-;
CONST
	MMXFlag=23;(*IN features from EBX*)
	FXSRFlag = 24;
	SSEFlag = 25;
	SSE2Flag = 26;
	SSE3Flag = 0; (*IN features2 from ECX*) (*PH 04/11*)
	SSSE3Flag =9;
	SSE41Flag =19;
	SSE42Flag =20;
	SSE5Flag = 11;
	AVXFlag = 28;
VAR vendor: Vendor; ver: LONGINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CPUID(vendor, ver, features,features2);
	MMXSupport := MMXFlag IN features;
	SSESupport := SSEFlag IN features;
	SSE2Support := SSESupport & (SSE2Flag IN features);
	SSE3Support := SSE2Support & (SSE3Flag IN features2);
	SSSE3Support := SSE3Support & (SSSE3Flag IN features2); (* PH 04/11*)
	SSE41Support := SSE3Support & (SSE41Flag IN features2);
	SSE42Support := SSE3Support & (SSE42Flag IN features2);
	SSE5Support := SSE3Support & (SSE5Flag IN features2);
	AVXSupport := SSE3Support & (AVXFlag IN features2);
	fcr := (FCR() - {0,2,3,10,11}) + {0..5,8,9};	(* default FCR RC=00B *)
	InitApplicationProcessor;
END InitBootProcessor;

PROCEDURE InitApplicationProcessor-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	InitFPU;  SetFCR( fcr );
	IF Environment.IsNative & SSESupport THEN
		InitSSE();
	END;
END InitApplicationProcessor;

(** Acquire a spin-lock. *)
	PROCEDURE Acquire*( level: LONGINT );   (* non reentrant lock  (non reentrance "ensured" by ASSERT statement ), CriticalSections are reentrant *)
	BEGIN
		Mutexes.Acquire (mutex[level]);
	END Acquire;

(** Release a spin-lock. *)
	PROCEDURE Release*( level: LONGINT );   (* release lock *)
	BEGIN
		Mutexes.Release (mutex[level]);
	END Release;

(* returns if an address is a currently allocated heap address *)
PROCEDURE ValidHeapAddress*(p: ADDRESS): BOOLEAN;
BEGIN
	RETURN p # NIL;
END ValidHeapAddress;

PROCEDURE GetFreeK* (VAR total, lowFree, highFree: SIZE);
BEGIN
	total := 0; lowFree := 0; highFree := 0;
END GetFreeK;

PROCEDURE PhysicalAdr*(adr: ADDRESS; size: SIZE): ADDRESS;
BEGIN RETURN adr;
END PhysicalAdr;

	(** -- Atomic operations -- *)

(** Atomic INC(x). *)

	PROCEDURE -AtomicInc*( VAR x: LONGINT );
	CODE {SYSTEM.i386}
		POP	EAX
		LOCK
		INC	DWORD[EAX]
	END AtomicInc;

(** Atomic DEC(x). *)

	PROCEDURE -AtomicDec*( VAR x: LONGINT );
	CODE {SYSTEM.i386}
		POP	EAX
		LOCK
		DEC	DWORD[EAX]
	END AtomicDec;

(** Atomic INC(x, y). *)

	PROCEDURE -AtomicAdd*( VAR x: LONGINT;  y: LONGINT );
	CODE {SYSTEM.i386}
		POP	EBX
		POP	EAX
		LOCK
		ADD	DWORD[EAX], EBX
	END AtomicAdd;

(** Atomic test-and-set.  Set x = TRUE and return old value of x. *)

	PROCEDURE -AtomicTestSet*( VAR x: BOOLEAN ): BOOLEAN;
	CODE {SYSTEM.i386}
		POP	EBX
		MOV	AL, 1
		XCHG	[EBX], AL
	END AtomicTestSet;

(* Atomic compare-and-swap. Set x = new if x = old and return old value of x *)

	PROCEDURE -AtomicCAS* (VAR x: LONGINT; old, new: LONGINT): LONGINT;
	CODE {SYSTEM.i386}
		POP EBX		; new
		POP EAX		; old
		POP EDX		; address of x
		DB 0F0X, 00FX, 0B1X, 01AX	; LOCK CMPXCHG [EDX], EBX; atomicly compare x with old and set it to new if equal
	END AtomicCAS;

(* function returning the number of processors that are available to Aos *)
PROCEDURE NumberOfProcessors*( ): LONGINT;
BEGIN
	RETURN Processors.count;
END NumberOfProcessors;

(* function for changing byte order *)
PROCEDURE ChangeByteOrder* (n: LONGINT): LONGINT;
CODE { SYSTEM.Pentium }
	MOV EAX, [EBP+n]				; load n in eax
	BSWAP EAX						; swap byte order
END ChangeByteOrder;

PROCEDURE -GetEAX*(): LONGINT;
CODE{SYSTEM.i386}
END GetEAX;

PROCEDURE -GetECX*(): LONGINT;
CODE{SYSTEM.i386}
	MOV EAX,ECX
END GetECX;

PROCEDURE -SetEAX*(n: LONGINT);
CODE{SYSTEM.i386}	POP EAX
END SetEAX;

PROCEDURE -SetEBX*(n: LONGINT);
CODE{SYSTEM.i386}
	POP EBX
END SetEBX;

PROCEDURE -SetECX*(n: LONGINT);
CODE{SYSTEM.i386}
	POP ECX
END SetECX;

PROCEDURE -SetEDX*(n: LONGINT);
CODE{SYSTEM.i386}
	POP EDX
END SetEDX;

PROCEDURE -SetESI*(n: LONGINT);
CODE{SYSTEM.i386}
	POP ESI
END SetESI;

PROCEDURE -SetEDI*(n: LONGINT);
CODE{SYSTEM.i386}
	POP EDI
END SetEDI;

PROCEDURE Portin8*(port: LONGINT; VAR val: CHAR);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN AL, DX
	MOV EBX, [EBP+val]
	MOV [EBX], AL
END Portin8;

PROCEDURE Portin16*(port: LONGINT; VAR val: INTEGER);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN AX, DX
	MOV EBX, [EBP+val]
	MOV [EBX], AX
END Portin16;

PROCEDURE Portin32*(port: LONGINT; VAR val: LONGINT);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN EAX, DX
	MOV EBX, [EBP+val]
	MOV [EBX], EAX
END Portin32;

PROCEDURE Portout8*(port: LONGINT; val: CHAR);
CODE{SYSTEM.i386}
	MOV AL,[EBP+val]
	MOV EDX,[EBP+port]
	OUT DX,AL
END Portout8;

PROCEDURE Portout16*(port: LONGINT; val: INTEGER);
CODE{SYSTEM.i386}
	MOV AX,[EBP+val]
	MOV EDX,[EBP+port]
	OUT DX,AX
END Portout16;

PROCEDURE Portout32*(port: LONGINT; val: LONGINT);
CODE{SYSTEM.i386}
	MOV EAX,[EBP+val]
	MOV EDX,[EBP+port]
	OUT DX,EAX
END Portout32;

(* Delay for IO *)
PROCEDURE -Wait*;
CODE {SYSTEM.i386}
	JMP 0
	JMP 0
	JMP 0
END Wait;

(** Read a byte from the non-volatile setup memory. *)
PROCEDURE GetNVByte* (ofs: LONGINT): CHAR;
VAR c: CHAR;
BEGIN
	Portout8 (70H, CHR(ofs)); Wait; Portin8(71H, c);
	RETURN c
END GetNVByte;

(** Write a byte to the non-volatile setup memory. *)
PROCEDURE PutNVByte* (ofs: LONGINT; val: CHAR);
BEGIN
	Portout8 (70H, CHR(ofs)); Wait; Portout8 (71H, val)
END PutNVByte;

PROCEDURE InvalidateDCacheRange*(a: ADDRESS; s: SIZE);
BEGIN
	
END InvalidateDCacheRange;

PROCEDURE FlushDCacheRange*(a: ADDRESS; s: SIZE);
BEGIN
	
END FlushDCacheRange;


BEGIN
	Trace.String("Machine: "); Trace.Blue; Trace.StringLn (Version); Trace.Default;
	boottime:=GetTimer();
	COPY( Version, version );
END Machine.
