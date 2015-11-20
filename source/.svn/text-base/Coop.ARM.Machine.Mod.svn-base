MODULE Machine;

IMPORT CPU, Environment, Trace, Mutexes, Processors, Timer;

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
	CODE
	END SpinHint;

(* Return current instruction pointer *)
PROCEDURE CurrentPC* (): ADDRESS;
CODE
	MOV R0, PC
END CurrentPC;

(* Return current frame pointer *)
PROCEDURE -CurrentBP* (): ADDRESS;
CODE
	MOV R0, FP
END CurrentBP;

(* Return current stack pointer *)
PROCEDURE -CurrentSP* (): ADDRESS;
CODE
	MOV R0, SP
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

(** Fill "size" bytes at "destAdr" with "filler".  "size" must be multiple of 4. *)

	PROCEDURE Fill32*(destAdr: ADDRESS; size: SIZE; filler: LONGINT);
	CODE
		LDR R0, [FP, #filler]
		LDR R1, [FP, #size]
		LDR R3, [FP, #destAdr]
		MOV R4, #0; counter

		(* Check size MOD 4 = 0 *)
		LSR R5, R1, #2
		LSL R5, R5, #2
		CMP R5, R1
		BEQ Loop
		SWI #8

	Loop:
		CMP R4, R1
		BGE Exit
		ADD R5, R3, R4
		STR R0, [R5, #0]; put(destAdr + counter, filler)
		ADD R4, R4, #4; INC(counter, 4)
		B Loop
	Exit:
	END Fill32;

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
PROCEDURE GetTimer*(): HUGEINT;
BEGIN RETURN Timer.GetCounter ();
END GetTimer;

PROCEDURE ID*(): LONGINT;
BEGIN
	RETURN Processors.GetCurrentIndex ();
END ID;

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
	CODE
		LDR	R0, [SP], #4
	loop:
		LDREX	R1, R0
		ADD	R1, R1, #1
		STREX	R2, R1, R0
		CMP	R2, #0
		BNE	loop
	END AtomicInc;

(** Atomic DEC(x). *)

	PROCEDURE -AtomicDec*( VAR x: LONGINT );
	CODE
		LDR	R0, [SP], #4
	loop:
		LDREX	R1, R0
		SUB	R1, R1, #1
		STREX	R2, R1, R0
		CMP	R2, #0
		BNE	loop
	END AtomicDec;

(** Atomic INC(x, y). *)

	PROCEDURE -AtomicAdd*( VAR x: LONGINT;  y: LONGINT );
	CODE
		LDR R3, [SP], #4	; R3 := y
		LDR R0, [SP], #4	; R0 := ADR(x)
	loop:
		LDREX R1, R0		; R1 := x
		ADD R1, R1, R3	; increment x
		STREX R2, R1, R0
		CMP R2, #0
		BNE loop			; if store failed, try again, else exit
	END AtomicAdd;

(** Atomic test-and-set.  Set x = TRUE and return old value of x. *)

	PROCEDURE AtomicTestSet*( VAR x: BOOLEAN ): BOOLEAN;
	CODE
		MOV	R2, #1					; R2 := TRUE
		MOV	R1, #0					; R1 := FALSE
		LDR	R3, [SP], #4			; R3 := ADDRESSOF(x)

	loop:
		LDREX	R0, R3					; load excl x
		CMP	R0, R1
		BNE	exit						; x # old -> exit
		STREX	R4, R2, R3				; x = old -> store excl new -> x
		CMP	R4, #0
		BNE	loop					; store exclusive failed: retry

	exit:
	END AtomicTestSet;

(* Atomic compare-and-swap. Set x = new if x = old and return old value of x *)

	PROCEDURE -AtomicCAS* (VAR x: LONGINT; old, new: LONGINT): LONGINT;
	CODE
		LDR	R2, [SP], #4			; R2 := new
		LDR	R1, [SP], #4			; R1 := old
		LDR	R3, [SP], #4			; R3 := ADDRESSOF(x)

	loop:
		LDREX	R0, R3					; load excl x
		CMP	R0, R1
		BNE	exit						; x # old -> exit
		STREX	R4, R2, R3				; x = old -> store excl new -> x
		CMP	R4, #0
		BNE	loop					; store exclusive failed: retry

	exit:
	END AtomicCAS;

(* function returning the number of processors that are available to Aos *)
PROCEDURE NumberOfProcessors*( ): LONGINT;
BEGIN
	RETURN Processors.count;
END NumberOfProcessors;

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
