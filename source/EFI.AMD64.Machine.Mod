MODULE Machine;	(** AUTHOR "pjm"; PURPOSE "Bootstrapping, configuration and machine interface"; *)

(* The code of this module body must be the first in the statically linked boot file. *)

IMPORT SYSTEM, Trace;

CONST
	Version = "A2 Revision 2958 (26.02.2010)";

	MaxCPU* = 8;	(** maximum number of processors (up to 16) *)

	DefaultObjectFileExtension* = ".Abx";

	(** bits in features variable *)
	MTTR* = 12; MMX* = 23; HTT* = 28;

	MaxDisks = 2;	(* maximum number of disks with BIOS parameters *)

	HeapAdr = 100000H;

	MaxMemTop = 4000000H * 4000000H; (* maximal 52bit wide physical address (architectural limit) *)

	DefaultDMASize = 20;	(* default size of ISA DMA area in KB *)

CONST
	StrongChecks = FALSE;	(* perform strong checks *)
	Stats* = FALSE;	(* acquire statistics *)
	TimeCount = 0	(* 100000 *);	(* number of lock tries before checking timeout - 0 to disable *)

	(** standard lock levels (in order) *)	(* also refer to Traps.Show *)
	TraceOutput* = 0;		(* Trace output *)
	Memory* = 1;			(* Virtual memory management, stack and page allocation *)
	Heaps* = 2;				(* Storage allocation and Garbage collection *)
	Interrupts* = 3	;		(* Interrupt handling. *)
	Modules* = 4;			(* Module list *)
	Objects* = 5;			(* Ready queue *)
	Processors* = 6;	(* Interprocessor interrupts *)
	KernelLog* = 7;			(* Atomic output *)
	(** highest level is all object locks *)

	Preemption* = 31;	(** flag for BreakAll *)

	MaxLocks = 8;	(* { <= 32 } *)

	LowestLock = 0; HighestLock = MaxLocks-1;

CONST
	TraceVerbose = FALSE;	(* write out verbose trace info *)

	AddressSize = SIZEOF(ADDRESS);
	SetSize = MAX (SET) + 1;

	(** error codes *)
	Ok* = 0;

	(* standard multipliers *)
	K = 1024; M = 100000H; (* 1K, 1M *)

	(* paging sizes *)
	PS = 4096;			(* page size in bytes *)
	PSlog2 = 12;		(* ASH(1, PSlog2) = PS *)
	TPS = 4096;			(* translation page size *)
	PTEs = TPS DIV AddressSize;	(* number of entries per translation page table *)
	RS = PTEs * PS;		(* region covered by a page table in bytes *)

	ReservedPages = 8;	(* pages reserved on page heap (not for normal heap use) *)

	NilAdr* = -1;		(** nil value for addresses (not same as pointer NIL value) *)

	(* free page stack page node layout *)
	NodeSP = 0;
	NodeNext = AddressSize;
	NodePrev = AddressSize*2;
	MinSP = AddressSize*3; MaxSP = PS;

(*
0				sp
AddressSize		nextAdr
AddressSize*2	prevAdr
AddressSize*3	first entry
4092			last entry
*)

	(* virtual memory layout. no area will cross the 2G boundary, to avoid LONGINT sign problems. *)
	MapAreaAdr = SHORT(80000000H);	(* dynamic mappings: bottom part of 2G..4G *)
	MapAreaSize = 64*M;
	IntelAreaAdr = SHORT(0FEE00000H);	(* reserved by Intel for APIC: 4G-18M..4G-18M+4K *)
	IntelAreaSize = 00001000H;
	StackAreaAdr = MapAreaAdr+MapAreaSize;	(* stacks: middle part of 2G..4G *)
	StackAreaSize = IntelAreaAdr-StackAreaAdr;

	(* stack sizes *)
	KernelStackSize = 2*PS;		(* multiple of PS *)
	MaxUserStackSize = 128*K;	(* multiple of PS *)
	InitUserStackSize = PS;		(* must be PS (or change NewStack) *)
	UserStackGuardSize = PS;	(* multiple of PS left unallocated at bottom of stack virtual area *)
	MaxUserStacks = StackAreaSize DIV MaxUserStackSize;

	(* physical memory layout *)
	LowAdr = PS;				(* lowest physical address used *)
	LinkAdr = M;				(* address where kernel is linked, also address where heap begins *)
	StaticBlockSize = 32;		(* static heap block size *)
	BlockHeaderSize = 2 * AddressSize;
	RecordDescSize = 3 * AddressSize;  (* needs to be adapted in case Heaps.RecordDesc is changed *)

	(* gdt indices *)
	TSSOfs = 8;					(* offset in GDT of TSSs *)
	StackOfs = TSSOfs + MaxCPU;	(* offset in GDT of stacks *)
	GDTSize = TSSOfs + MaxCPU * 2; (* TSS descriptors need 16 bytes each *)

	(* gdt selectors *)
	Kernel32CodeSel = 1*8;		(* selector 1 in gdt, RPL 0 *)
	Kernel64CodeSel = 2*8;		(* selector 2 in gdt, RPL 0 *)
	User32CodeSel = 3*8 + 3;	(* selector 3 in gdt, RPL 3 *)
	User64CodeSel = 4*8 + 3;	(* selector 4 in gdt, RPL 3 *)
	KernelStackSel = 5*8;		(* selector 5 in gdt, RPL 0 *)
	UserStackSel = 6*8 + 3;		(* selector 6 in gdt, RPL 3 *)
	DataSel = 7*8;				(* selector 7 in gdt, RPL 0 *)
	KernelTR = TSSOfs*8;		(* selector in gdt, RPL 0 *)

	(* paging flags *)
	PageNotPresent = 0;		(* not present page *)
	KernelPage = 3;				(* supervisor, present, r/w *)
	UserPage = 7;				(* user, present, r/w *)

	HeapMin = 50;				(* "minimum" heap size as percentage of total memory size (used for heap expansion in scope of GC ) *)
	HeapMax = 95;				(* "maximum" heap size as percentage of total memory size (used for heap expansion in scope of GC) *)
	ExpandRate = 1;				(* always extend heap with at least this percentage of total memory size *)
	Threshold = 10;				(* periodic GC initiated when this percentage of total memory size bytes has "passed through" NewBlock *)
	InitialHeapIncrement = 4096;

	HeaderSize = 40H; (* cf. Linker0 *)
	EndBlockOfs = 38H;	(* cf. Linker0 *)
	MemoryBlockOfs = BlockHeaderSize + RecordDescSize + BlockHeaderSize; (* memory block (including header) starts at offset HeaderSize *)

CONST
	(** pre-defined interrupts 0-31, used with InstallHandler *)
	DE* = 0; DB* = 1; NMI* = 2; BP* = 3; OVF* = 4; BR* = 5; UD* = 6; NM* = 7;
	DF* = 8; TS* = 10; NP* = 11; SSF* = 12; GP* = 13; PF* = 14; MF*= 16; AC*= 17; MC* = 18;

	IRQ0* = 32;			(* {IRQ0 MOD 8 = 0} *)
	IRQ2 = IRQ0 + 2;
	IRQ7 = IRQ0 + 7;
	IRQ8 = IRQ0 + 8;
	IRQ15 = 47;
	MaxIRQ* = IRQ15;	(** hardware interrupt numbers *)

	MPKC* = 49;		(** SMP: kernel call *)
	SoftInt* = 58;		(** temporary software interrupt *)
	MPIPCLocal* = 59;	(** SMP: local interprocessor interrupt *)
	MPTMR* = 60;		(** SMP: timer interrupt *)
	MPIPC* = 61;		(** SMP: interprocessor interrupt *)
	MPERR* = 62;		(** SMP: error interrupt *)
	MPSPU* = 63;		(** SMP: spurious interrupt {MOD 16 = 15} *)

	IDTSize = 64;
	MaxNumHandlers = 16;

	TraceSpurious = FALSE;						(* no message on spurious hardware interrupts *)
	HandleSpurious = TRUE OR TraceSpurious;	(* do not trap on spurious interrupts *)

	IntA0 = 020H;	IntA1 = 021H;	(* Interrupt Controller 1 *)
	IntB0 = 0A0H;	IntB1 = 0A1H;	(* Interrupt Controller 2 *)

	(** RFLAGS bits *)
	IFBit* = 9; VMBit* = 17;

	KernelLevel* = 0; UserLevel* = 3;	(** CS MOD 4 *)

	Second* = 1000; (* frequency of ticks increments in Hz *)

CONST
	Self* = 0; FrontBarrier* = 1; BackBarrier* = 2;	(** Broadcast flags. *)

	TraceApic = FALSE;
	TraceProcessor = FALSE;	(* remove this hack! *)

	ClockRateDelay = 50;	(* ms - delay when timing bus clock rate *)

	TimerClock = 1193180;	(* timer clock is 1.19318 MHz *)

CONST
	(* low level tracing *)
	TraceV24 = 2; TraceScreen = 0;
	TraceWidth = 80; TraceHeight = 25;
	TraceLen = TraceWidth * SIZEOF (INTEGER);
	TraceSize = TraceLen * TraceHeight;

TYPE
	Vendor* = ARRAY 13 OF CHAR;

	IDMap* = ARRAY 16 OF SHORTINT;

TYPE
	Stack* = RECORD	(** values are read-only *)
		low: ADDRESS;		(* lowest virtual address that may be allocated for stack *)
		adr*: ADDRESS;		(* lowest address on allocated stack *)	(* exported for Objects only *)
		high*: ADDRESS;	(* next virtual address after stack *)	(* exported for Objects only *)
	END;

	(* task state segment *)
	TSSDesc = RECORD	(* 1, p. 485 and p. 612 for required fields *)
		Reserved1: LONGINT;
		RSP0 {ALIGNED(4)}, RSP1{ALIGNED(4)}, RSP2{ALIGNED(4)}: HUGEINT;
		Reserved2, Reserved3: LONGINT;
		IST1 {ALIGNED(4)}, IST2 {ALIGNED(4)}, IST3 {ALIGNED(4)}, IST4{ALIGNED(4)}, IST5{ALIGNED(4)}, IST6{ALIGNED(4)}, IST7{ALIGNED(4)}: HUGEINT;
		Reserved4, Reserved5: LONGINT;
		Reserved6, IOMapBaseAddress: INTEGER;
	(* Implicit: IOBitmap: ARRAY 8192 DIV 4 OF SET *)
	END;

	Startup* = PROCEDURE;	(** can not be a method *)

	(* global descriptor table *)
	SegDesc = RECORD
		low, high: LONGINT
	END;
	GDT = ARRAY GDTSize OF SegDesc;

	Range* = RECORD
		adr*: ADDRESS; size*: SIZE;
	END;

TYPE
	(** processor state, ordering of record fields is predefined! *)
	State* = RECORD					(* offsets used in FieldInterrupt, FieldIRQ and Objects.RestoreState *)
		R15*, R14*, R13*, R12*, R11*, R10*, R9*, R8*: HUGEINT;
		RDI*, RSI*, ERR*, RSP0*, RBX*, RDX*, RCX*, RAX*: HUGEINT;	(** RSP0 = ADR(s.INT) *)
		INT*, BP*, PC*, CS*: HUGEINT;	(* RBP and ERR are exchanged by glue code, for procedure link *)
		FLAGS*: SET;
		SP*, SS*: HUGEINT;
	END;

	(** exception state, ordering of record fields is predefined! *)
	ExceptionState* = RECORD
		halt*: ADDRESS;	(** halt code *)
		pf*: ADDRESS;	(** page fault address *)
		locks*: SET;	(** active locks *)
		SP*: ADDRESS;	(** actual RSP value at time of interrupt *)
		CR*: ARRAY 16 OF HUGEINT;	(** control registers *)
		DR*: ARRAY 16 OF HUGEINT;	(** debug registers *)
		FPU*: ARRAY 7 OF SET	(** floating-point state *)
	END;

	Handler* = PROCEDURE {DELEGATE} (VAR state: State);

	HandlerRec = RECORD
		valid: BOOLEAN;	(* offset 0 *)
		handler {ALIGNED(4)}: Handler	(* offset 4 *)
	END;

	GateDescriptor = RECORD
		offsetBits0to15: INTEGER;
		selector: INTEGER;
		gateType: INTEGER;
		offsetBits16to31: INTEGER;
		offsetBits32to63: LONGINT;
		reserved: LONGINT;
	END;
	IDT = ARRAY IDTSize OF GateDescriptor;

	SSEState* = ARRAY (512+16) OF CHAR;

TYPE
	MemoryBlock* = POINTER TO MemoryBlockDesc;
	MemoryBlockDesc* = RECORD
		next- {UNTRACED}: MemoryBlock;
		startAdr-: ADDRESS; 		(* unused field for I386 *)
		size-: SIZE; 					(* unused field for I386 *)
		beginBlockAdr-, endBlockAdr-: ADDRESS
	END;

TYPE
	EventHandler = PROCEDURE (id: LONGINT; CONST state: State);

	Message* = POINTER TO RECORD END;	(** Broadcast message. *)
	BroadcastHandler = PROCEDURE (id: LONGINT; CONST state: State; msg: Message);

	TimeArray = ARRAY MaxCPU OF HUGEINT;

	Address32* = LONGINT;

VAR
	lowTop*: ADDRESS;	(** top of low memory *)
	memTop*: ADDRESS;	(** top of memory *)
	dmaSize*: SIZE;	(** size of ISA dma area, above lowTop (for use in Aos.Diskettes) *)

	configMP: ADDRESS;	(** MP spec config table physical address (outside reported RAM) *)
	revMP: CHAR;					(** MP spec revision *)
	featureMP: ARRAY 5 OF CHAR;	(** MP spec feature bytes 1-5 *)

	version-: ARRAY 64 OF CHAR;	(** Aos version *)

	SSESupport-: BOOLEAN;
	SSE2Support-: BOOLEAN;

	features-, features2-: SET;	(** processor features *)
	fcr*: SET;	(** default floating-point control register value (default rounding mode is towards -infinity, for ENTIER) *)
	mhz*: HUGEINT;	(** clock rate of GetTimer in MHz, or 0 if not known *)

	chs: ARRAY MaxDisks OF RECORD cyls, hds, spt: LONGINT END;
	initRegs0, initRegs1: HUGEINT;
	fbadr*, fbInfoPtr*: ADDRESS; 
	initRegs: ARRAY 2 OF HUGEINT;	(* kernel parameters *)
	config: ARRAY 2048 OF CHAR;	(* config strings *)
	bootFlag: ADDRESS;

	idAdr: ADDRESS;	(* address of processor ID register *)
	map: IDMap;
	bootID: LONGINT;	(* ID of boot processor (0) *)

	numberOfProcessors: LONGINT; (* number of processors installed during start up *)
	coresPerProcessor : LONGINT; (* number of cores per physical package *)
	threadsPerCore : LONGINT; (* number of threads per core *)

CONST
	CacheLineSize = 128;

TYPE
	(* Synchronization variables should reside in own cache line. This data structure should be aligned to CacheLineSize. *)
	Lock = RECORD
		locked : BOOLEAN;
		filler : ARRAY CacheLineSize - 1 OF CHAR;
	END;

VAR
	lock: ARRAY MaxLocks OF Lock;	(** all locks *)

(*
Every element in the proc array belongs to one processor. It is therefore sufficient to disable interrupts to protect the consistency of these elements. Race conditions with interrupts handled on the same processor are avoided by disabling interrupts for the entire time that a lock is held (using locksHeld & state). The data structures  are padded to CacheLineSize to separate the locks out on cache lines of their own, to avoid false sharing.
*)
	proc-, trapState-: ARRAY MaxCPU OF RECORD
		locksHeld-: SET;	(** locks held by a processor *)
		state-: SET;	(** processor flags (interrupt state) at entry to its first lock *)
		preemptCount-: LONGINT;	(** if 0, preemption is allowed *)
		padding : ARRAY CacheLineSize - 20 OF CHAR;
	END;

	(* the data structures above should be aligned to CacheLineSize *)
	padding : ARRAY 92 OF CHAR;

	trapLocksBusy-: SET;
	maxTime: HUGEINT;

VAR
	gdt: GDT;					(* global descriptor table *)
	procm: ARRAY MaxCPU OF RECORD	(* indexed by ID () *)
		tss: TSSDesc;
		sp: ADDRESS;	(* snapshot for GC *)
		stack: Stack
	END;
	kernelPML4: ADDRESS;	(* physical address of page directory *)

	freeLowPage: ADDRESS;	(* free low page stack pointer (link at offset 0 in page). All addresses physical. NIL = -1 *)
	freeLowPages, freeHighPages, totalPages: HUGEINT;	(* number of free pages and total number of pages *)

	mapTop: ADDRESS;	(* virtual address of end of memory mapping area *)
	heapEndAdr: ADDRESS;	(* virtual address of end of heap (page aligned) *)

	topPageNum: HUGEINT;		(* page containing byte memTop-1 *)
	pageHeapAdr: ADDRESS;	(* address (physical and virtual) of bottom of page heap area *)
	pageStackAdr: ADDRESS;	(* virtual address of top page of free page stack *)

	freeStack: ARRAY (MaxUserStacks+SetSize-1) DIV SetSize OF SET;	(* free stack bitmap *)
	freeStackIndex: HUGEINT;	(* current position in bitmap (rotates) *)

	Nbigskips-: LONGINT;	(* number of times a stack was extended leaving a hole *)
	Nfilled-: LONGINT;	(* number of times a "hole" in a stack was filled *)
	NnewStacks-, NnewStackLoops-, NnewStackInnerLoops-, NdisposeStacks-,
	NlostPages-, NreservePagesUsed-, NmaxUserStacks-: HUGEINT;

VAR
	idt: IDT;	(* interrupt descriptor table *)
	glue: ARRAY IDTSize OF ARRAY 15 OF CHAR;	(* code *)
	intHandler: ARRAY IDTSize, MaxNumHandlers OF HandlerRec; (* array of handlers for interrupts, the table is only filled up to MaxNumHandlers - 1, the last element in each row acts as a sentinel *)
	stateTag: ADDRESS;
	default: HandlerRec;
	i, j, ticks*: LONGINT;	(** timer ticks. Use Kernel.GetTicks() to read, don't write *)

VAR
	ipcBusy, ipcFlags, ipcFrontBarrier, ipcBackBarrier: SET;
	ipcHandler: BroadcastHandler;
	ipcMessage: Message;
	numProcessors-: LONGINT;	(* number of processors we attempted to boot (some may have failed) *)
	maxProcessors: LONGINT;	(* max number of processors we are allowed to boot (-1 for uni) *)
	allProcessors-: SET;	(* IDs of all successfully booted processors *)
	localAPIC: ADDRESS;	(* address of local APIC, 0 if not present *)
	apicVer: ARRAY MaxCPU OF LONGINT;	(* APIC version *)
	started: ARRAY MaxCPU OF BOOLEAN;	(* CPU started successfully / CPU halted *)
	busHz0, busHz1: ARRAY MaxCPU OF LONGINT;	(* unrounded and rounded bus speed in Hz *)
	timer: EventHandler;
	timerRate: LONGINT;	(* Hz - rate at which CPU timers run - for timeslicing and profiling *)
	stopped: BOOLEAN;	(* StopAll was called *)
	idMap: IDMap;
	revIDmap: ARRAY MaxCPU OF SHORTINT;
	time: TimeArray;
	eventCount, eventMax: LONGINT;
	event: Handler;
	expandMin, heapMinKB, heapMaxKB : SIZE;

	gcThreshold-: SIZE;
	memBlockHead-{UNTRACED}, memBlockTail-{UNTRACED}: MemoryBlock; (* refer to the same memory block for I386, not traced by GC *)
	initialMemBlock: MemoryBlockDesc;

	traceProcessorProc*: EventHandler;	(** temp tracing *)
	traceProcessor: BOOLEAN;

	Timeslice*: Handler;

	start*: PROCEDURE;

VAR
	traceMode: SET;	(* tracing mode: Screen or V24 *)
	traceBase: ADDRESS;	(* screen buffer base address *)
	tracePos: SIZE;	(* current screen cursor *)
	tracePort: LONGINT;	(* serial base port *)
	traceColor: SHORTINT;	(* current screen tracing color *)

(** -- Processor identification -- *)

(** Return current processor ID (0 to MaxNum-1). *)
PROCEDURE ID* (): LONGINT;
CODE {SYSTEM.AMD64}
	; todo: use MOV instead of LEA as soon as assembler returns address for global variables

	LEA RAX, idAdr	; get address of idAdr
	MOV RAX, [RAX]	; get value of idAdr
	MOV EAX, [RAX]	; dereference idAdr
	LEA RBX, map	; address of map
	SHR EAX, 24
	AND EAX, 15
	MOV AL, [RBX + RAX]
END ID;

(** -- Miscellaneous -- *)

(** This procedure should be called in all spin loops as a hint to the processor (e.g. Pentium 4). *)
PROCEDURE -SpinHint*;
CODE {SYSTEM.AMD64}
	PAUSE
END SpinHint;

(** Fill "size" bytes at "destAdr" with "filler". "size" must be multiple of 4. *)
PROCEDURE Fill32* (destAdr: ADDRESS; size: SIZE; filler: LONGINT);
CODE {SYSTEM.AMD64}
	MOV RDI, [RBP + destAdr]
	MOV RCX, [RBP + size]
	MOV EAX, [RBP + filler]
	TEST RCX, 3
	JZ ok
	PUSH 8	; ASSERT failure
	INT 3
ok:
	SHR RCX, 2
	CLD
	REP STOSD
END Fill32;

(** Return timer value of the current processor, or 0 if not available. *)

(* e.g. ARM does not have a fine-grained timer *)
PROCEDURE -GetTimer* (): HUGEINT;
CODE {SYSTEM.AMD64}
	XOR RAX, RAX
	RDTSC	; set EDX:EAX
	SHL RDX, 32
	OR RAX, RDX
END GetTimer;

(** Disable interrupts and return old interrupt state. *)
PROCEDURE -DisableInterrupts* (): SET;
CODE {SYSTEM.AMD64}
	PUSHFQ
	CLI
	POP RAX
END DisableInterrupts;

(** Restore interrupt state. Parameter s must be return value of earlier DisableInterrupts call on same processor. *)
PROCEDURE -RestoreInterrupts* (s: SET);
CODE {SYSTEM.AMD64}
	POPFQ
END RestoreInterrupts;

(** Return TRUE iff interrupts are enabled on the current processor. *)
PROCEDURE -InterruptsEnabled* (): BOOLEAN;
CODE {SYSTEM.AMD64}
	PUSHFQ
	POP RAX
	SHR RAX, 9
	AND AL, 1
END InterruptsEnabled;

(** -- Processor initialization -- *)
PROCEDURE -SetFCR (s: SET);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	FLDCW WORD [RSP]	; parameter s
	POP RAX
END SetFCR;

PROCEDURE -FCR (): SET;
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	PUSH 0
	FNSTCW WORD [RSP]
	FWAIT
	POP RAX
END FCR;

PROCEDURE -InitFPU;
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	FNINIT
END InitFPU;

(** Setup FPU control word of current processor. *)

PROCEDURE SetupFPU*;
BEGIN
	InitFPU; SetFCR(fcr)
END SetupFPU;

(* Set up flags (3, p. 20)
	Bit
	1,3,5,15,19..31 - no change
	0,2,4,6..7,11 - CF,PF,AF,ZF,SF,OF off
	8 - TF off
	9 - IF off (no interrupts)
	10 - DF off
	12..13 - IOPL = 3
	14 - NT off (no Windows)
	16 - RF off (no Interference)
	17- VM off (no virtual 8086 mode)
	18 - AC off (no 486 alignment checks) *)

PROCEDURE -SetupFlags;
CODE {SYSTEM.AMD64}
	PUSHFD
	AND DWORD [RSP], 0FFF8802AH
	OR DWORD [RSP], 3000H
	POPFD
END SetupFlags;

(* Set up various 486-specific flags (3, p. 23)
	1. Enable exception 16 on math errors.
	2. Disable supervisor mode faults on write to read-only pages
		(386-compatible for stack checking).
	3. Enable the Alignment Check field in RFLAGS *)

PROCEDURE -Setup486Flags;
CODE {SYSTEM.486, SYSTEM.Privileged}
	MOV EAX, CR0
	OR EAX, 00040020H
	AND EAX, 0FFFEFFFFH
	MOV CR0, EAX
END Setup486Flags;

(* Set up 586-specific things *)
PROCEDURE -Setup586Flags;
CODE {SYSTEM.586, SYSTEM.Privileged}
	MOV EAX, CR4
	BTR EAX, 2		; clear TSD
	MOV CR4, EAX
END Setup586Flags;

(* Disable exceptions caused by math in new task. (1, p. 479) *)
PROCEDURE -DisableMathTaskEx;
CODE {SYSTEM.386, SYSTEM.Privileged}
	MOV EAX,CR0
	AND AL, 0F5H
	MOV CR0, EAX
END DisableMathTaskEx;

(* Disable math emulation (1, p. 479) , bit 2 of CR0 *)
PROCEDURE -DisableEmulation;
CODE {SYSTEM.386, SYSTEM.Privileged}
	MOV EAX, CR0
	AND AL, 0FBH
	MOV CR0, EAX
END DisableEmulation;

(** CPU identification *)
PROCEDURE CPUID*(function : LONGINT; VAR eax, ebx, ecx, edx : SET);
CODE {SYSTEM.AMD64}
	MOV EAX, [RBP+function]	; CPUID function parameter

	MOV RSI, [RBP+ecx]		; copy ecx into ECX (sometimes used as input parameter)
	MOV ECX, [RSI]

	CPUID					; execute CPUID

	MOV RSI, [RBP+eax]		; copy EAX into eax;
	MOV [RSI], EAX
	MOV RSI, [RBP+ebx]		; copy EBX into ebx
	MOV [RSI], EBX
	MOV RSI, [RBP+ecx]		; copy ECX into ecx
	MOV [RSI], ECX
	MOV RSI, [RBP+edx]		; copy EDX into edx
	MOV [RSI], EDX
END CPUID;

(* If the CPUID instruction is supported, the ID flag (bit 21) of the EFLAGS register is r/w *)
PROCEDURE CpuIdSupported*() : BOOLEAN;
CODE {SYSTEM.AMD64}
	PUSHFQ					; save RFLAGS
	POP RAX				; store RFLAGS in RAX
	MOV EBX, EAX			; save EBX for later testing
	XOR EAX, 00200000H	; toggle bit 21
	PUSH RAX				; push to stack
	POPFQ					; save changed RAX to RFLAGS
	PUSHFQ					; push RFLAGS to TOS
	POP RAX				; store RFLAGS in RAX
	CMP EAX, EBX			; see if bit 21 has changed
	SETNE AL;				; return TRUE if bit 21 has changed, FALSE otherwise
END CpuIdSupported;

(** Initialise current processor. Must be called by every processor. *)
PROCEDURE InitProcessor*;
BEGIN
	SetupFlags;
	Setup486Flags;
	Setup586Flags;
	DisableMathTaskEx;
	DisableEmulation;
	SetupFPU;
END InitProcessor;

(** Initialize APIC ID address. *)
PROCEDURE InitAPICIDAdr* (adr: ADDRESS; CONST m: IDMap);
VAR s: SET;
BEGIN
	s := DisableInterrupts ();
	idAdr := adr; map := m;
	RestoreInterrupts (s)
END InitAPICIDAdr;

PROCEDURE InitBoot;
VAR
	largestFunction, i: LONGINT;
	eax, ebx, ecx, edx : SET;
	logicalProcessorCount : LONGINT;
	u: ARRAY 8 OF CHAR; vendor : Vendor;

	PROCEDURE GetString(VAR string : ARRAY OF CHAR; offset : LONGINT; register : SET);
	BEGIN
		string[offset] :=CHR(SYSTEM.VAL(LONGINT, register * {0..7}));
		string[offset+1] := CHR(SYSTEM.VAL(LONGINT, LSH(register * {8..15}, -8)));
		string[offset+2] := CHR(SYSTEM.VAL(LONGINT, LSH(register * {16..23}, -16)));
		string[offset+3] := CHR(SYSTEM.VAL(LONGINT, LSH(register * {24..31}, -24)));
	END GetString;

BEGIN
	vendor := "Unknown"; features := {}; features2 := {};
	coresPerProcessor := 1; threadsPerCore := 1;
	IF CpuIdSupported() THEN
		(* Assume that all processors are the same *)

		(* CPUID standard function 0 returns:  eax: largest CPUID standard function supported, ebx, edx, ecx: vendor string *)
		CPUID(0, eax, ebx, ecx, edx);
		largestFunction := SYSTEM.VAL(LONGINT, eax);
		ASSERT(LEN(vendor) >= 13);
		GetString(vendor, 0, ebx); GetString(vendor, 4, edx); GetString(vendor, 8, ecx); vendor[12] := 0X;

		IF (largestFunction >= 1) THEN

			(* CPUID standard function 1 returns: CPU features in ecx & edx *)
			CPUID(1, eax, ebx, ecx, edx);
			features := SYSTEM.VAL(SET, edx);
			features2 := SYSTEM.VAL(SET, ecx);

			(* 	The code below is used to determine the number of threads per processor core (hyperthreading). This is required
				since processors supporting hyperthreading are listed only once in the MP tables, so we need to know the
				exact number of threads per processor to start the processor correctly *)

			IF (HTT IN features) THEN (* multithreading supported by CPU *)
				(* logical processor count = number of cores * number of threads per core = total number of threads supported *)
				logicalProcessorCount := SYSTEM.VAL(LONGINT, LSH(ebx * {16..23}, -16));
				IF (vendor = "GenuineIntel") THEN
					IF (largestFunction >= 4) THEN
						(* CPUID standard function 4 returns: number of processor cores -1 on this die eax[26.31] *)
						ecx := SYSTEM.VAL(SET, 0); (* input parameter - must be set to 0 *)
						CPUID(4, eax, ebx, ecx, edx);
						coresPerProcessor := SYSTEM.VAL(LONGINT, LSH(eax * {26..31}, -26)) + 1;
						threadsPerCore := logicalProcessorCount DIV coresPerProcessor;
					ELSE
						threadsPerCore := logicalProcessorCount;
					END;
				ELSIF (vendor = "AuthenticAMD") THEN
					(* CPUID extended function 1 returns: largest extended function *)
					CPUID(SHORT(80000000H), eax, ebx, ecx, edx);
					largestFunction := SYSTEM.VAL(LONGINT, eax - {31}); (* remove sign *)
					IF (largestFunction >= 8) THEN
						(* CPUID extended function 8 returns: *)
						CPUID(SHORT(80000008H), eax, ebx, ecx, edx);
						coresPerProcessor := SYSTEM.VAL(LONGINT, ecx * {0..7}) + 1;
						threadsPerCore := logicalProcessorCount DIV coresPerProcessor;
					ELSIF (largestFunction >= 1) THEN
						(* CPUID extended function 1 returns CmpLegacy bit in ecx *)
						CPUID(SHORT(80000001H), eax, ebx, ecx, edx);
						IF 1 IN ecx THEN (* CmpLegacy bit set -> no hyperthreading *)
							coresPerProcessor := logicalProcessorCount;
							threadsPerCore := 1;
						END;
					ELSE
						(* single-core, single-thread *)
					END;
				ELSE
					Trace.String("Machine: "); Trace.Yellow; Trace.String("Warning: Cannot detect hyperthreading, unknown CPU vendor ");
					Trace.String(vendor); Trace.Ln; Trace.Default;
				END;
			END;
		END;
	END;
	Trace.String("Machine: "); Trace.Int(coresPerProcessor, 0); Trace.String(" cores per physical package, ");
	Trace.Int(threadsPerCore, 0); Trace.String(" threads per core.");
	Trace.Ln;
	InitFPU;
	fcr := (FCR () - {0, 2, 3, 10, 11}) + {0 .. 5, 8, 9};	(* default FCR RC=00B *)
	bootID := 0; map[0] := 0;
	idAdr := ADDRESSOF (bootID);
	(* allow user to specify GetTimer rate, for tracing purposes *)
	GetConfig ("MHz", u);
	i := 0; mhz := StrToInt (i, u);
END InitBoot;

(** -- Configuration and bootstrapping -- *)

(** Return the value of the configuration string specified by parameter name in parameter val. Returns val = "" if the string was not found, or has an empty value. *)
PROCEDURE GetConfig* (CONST name: ARRAY OF CHAR; VAR val: ARRAY OF CHAR);
VAR i, src: LONGINT; ch: CHAR;
BEGIN
	ASSERT (name[0] # "=");	(* no longer supported, use GetInit instead *)
	src := 0;
	LOOP
		ch := config[src];
		IF ch = 0X THEN EXIT END;
		i := 0;
		LOOP
			ch := config[src];
			IF (ch # name[i]) OR (name[i] = 0X) THEN EXIT END;
			INC (i); INC (src)
		END;
		IF (ch = 0X) & (name[i] = 0X) THEN	(* found: (src^ = 0X) & (name[i] = 0X) *)
			i := 0;
			REPEAT
				INC (src); ch := config[src]; val[i] := ch; INC (i);
				IF i = LEN(val) THEN val[i - 1] := 0X; RETURN END	(* val too short *)
			UNTIL ch = 0X;
			val[i] := 0X; RETURN
		ELSE
			WHILE ch # 0X DO	(* skip to end of name *)
				INC (src); ch := config[src]
			END;
			INC (src);
			REPEAT	(* skip to end of value *)
				ch := config[src]; INC (src)
			UNTIL ch = 0X
		END
	END;
	val[0] := 0X
END GetConfig;

(** Get CHS parameters of first two BIOS-supported hard disks. *)
PROCEDURE GetDiskCHS* (d: LONGINT; VAR cyls, hds, spt: LONGINT);
BEGIN
	cyls := chs[d].cyls; hds := chs[d].hds; spt := chs[d].spt
END GetDiskCHS;

(** Get parameter values from Init string. If n = 0, return val = ASH(bx, 16) + ax, and if n = 1, return val = ASH(dx, 16) + cx, where ax, bx, cx, dx are the register values after the OBL boot loader or noboot.exe have executed the 16-bit x86 code in the Init string. *)
PROCEDURE GetInit* (n: LONGINT; VAR val: HUGEINT);
BEGIN
	val := initRegs[n]
END GetInit;

(** Convert a string to an integer. Parameter i specifies where in the string scanning should begin (usually 0 in the first call). Scanning stops at the first non-valid character, and i returns the updated position. Parameter s is the string to be scanned. The value is returned as result, or 0 if not valid. Syntax: number = ["-"] digit {digit} ["H" | "h"] . digit = "0" | ... "9" | "A" .. "F" | "a" .. "f" . If the number contains any hexdecimal letter, or if it ends in "H" or "h", it is interpreted as hexadecimal. *)
PROCEDURE StrToInt* (VAR i: LONGINT; CONST s: ARRAY OF CHAR): LONGINT;
VAR vd, vh, sgn, d: LONGINT; hex: BOOLEAN;
BEGIN
	vd := 0; vh := 0; hex := FALSE;
	IF s[i] = "-" THEN sgn := -1; INC (i) ELSE sgn := 1 END;
	LOOP
		IF (s[i] >= "0") & (s[i] <= "9") THEN d := ORD (s[i])-ORD ("0")
		ELSIF (CAP (s[i]) >= "A") & (CAP (s[i]) <= "F") THEN d := ORD (CAP (s[i]))-ORD ("A") + 10; hex := TRUE
		ELSE EXIT
		END;
		vd := 10*vd + d; vh := 16*vh + d;
		INC (i)
	END;
	IF CAP (s[i]) = "H" THEN hex := TRUE; INC (i) END;	(* optional H *)
	IF hex THEN vd := vh END;
	RETURN sgn * vd
END StrToInt;

(* Delay for IO *)
PROCEDURE -Wait*;
CODE {SYSTEM.AMD64}
	JMP N1
N1:	JMP N2
N2:	JMP N3
N3:
END Wait;

(* Reset processor by causing a double fault. *)
PROCEDURE Reboot;
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	PUSH DWORD 0
	PUSH DWORD 0
	LIDT [RSP]
	INT 3
END Reboot;

(** Shut down the system. If parameter reboot is set, attempt to reboot the system. *)
PROCEDURE Shutdown* (reboot: BOOLEAN);
VAR i: LONGINT;
BEGIN
	Cli;
	IF reboot THEN	(* attempt reboot *)
		Portout8 (70H, 8FX);			(* Reset type: p. 5-37 AT Tech. Ref. *)
		Wait; Portout8 (71H, 0X);		(* Note: soft boot flag was set in InitMemory *)
		Wait; Portout8 (70H, 0DX);
		Wait; Portout8 (64H, 0FEX);	(* reset CPU *)
		FOR i := 1 TO 10000 DO END;
		Reboot
	END;
	LOOP END
END Shutdown;

(* Get hard disk parameters. *)
PROCEDURE GetPar (p: ADDRESS; ofs: LONGINT): LONGINT;
VAR ch: CHAR;
BEGIN
	SYSTEM.GET (p + 12 + ofs, ch);
	RETURN ORD (ch)
END GetPar;

(* Read boot table. *)
PROCEDURE ReadBootTable (bt: ADDRESS);
VAR i, p: ADDRESS; j, d, type, addr, size, heapSize: LONGINT; ch: CHAR;
BEGIN
	heapSize := 0; lowTop := 0;
	p := bt; d := 0;
	LOOP
		SYSTEM.GET (p, type);
		IF type = -1 THEN
			EXIT	(* end *)
		ELSIF type = 3 THEN	(* boot memory/top of low memory *)
			SYSTEM.GET (p + 8, addr); SYSTEM.GET (p + 12, size);
			lowTop := addr + size
		ELSIF type = 4 THEN	(* free memory/extended memory size *)
			SYSTEM.GET (p + 8, addr); SYSTEM.GET (p + 12, size);
			IF addr = HeapAdr THEN heapSize := size END
		ELSIF type = 5 THEN	(* HD config *)
			IF d < MaxDisks THEN
				chs[d].cyls := GetPar (p, 0) + 100H * GetPar (p, 1);
				chs[d].hds := GetPar (p, 2); chs[d].spt := GetPar (p, 14);
				INC (d)
			END
		ELSIF type = 8 THEN	(* config strings *)
			i := p + 8; j := 0;	(* copy the config strings over *)
			LOOP
				SYSTEM.GET (i, ch); config[j] := ch; INC (i); INC (j);
				IF ch = 0X THEN EXIT END;
				REPEAT SYSTEM.GET (i, ch); config[j] := ch; INC (i); INC (j) UNTIL ch = 0X;	(* end of name *)
				REPEAT SYSTEM.GET (i, ch); config[j] := ch; INC (i); INC (j) UNTIL ch = 0X	(* end of value *)
			END
		END;
		SYSTEM.GET (p + 4, size); INC (p, size)
	END;
	ASSERT((heapSize # 0) & (lowTop # 0));
	memTop := HeapAdr + heapSize
END ReadBootTable;

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

(** Compute a checksum for the Intel SMP spec floating pointer structure. *)
PROCEDURE ChecksumMP* (adr: ADDRESS; size: SIZE): LONGINT;
VAR sum: LONGINT; x: ADDRESS; ch: CHAR;
BEGIN
	sum := 0;
	FOR x := adr TO adr + size-1 DO
		SYSTEM.GET (x, ch);
		sum := (sum + ORD(ch)) MOD 256
	END;
	RETURN sum
END ChecksumMP;

(* Search for MP floating pointer structure. *)
PROCEDURE SearchMem (adr: ADDRESS; size: SIZE): ADDRESS;
VAR x, len: LONGINT; ch: CHAR;
BEGIN
	WHILE size > 0 DO
		SYSTEM.GET (adr, x);
		IF x = 05F504D5FH THEN	(* "_MP_" found *)
			SYSTEM.GET (adr + 8, ch); len := ORD(ch)*16;
			IF len > 0 THEN
				SYSTEM.GET (adr + 9, ch);
				IF (ch = 1X) OR (ch >= 4X) THEN	(* version 1.1 or 1.4 or higher *)
					IF ChecksumMP(adr, len) = 0 THEN
						RETURN adr		(* found *)
					END
				END
			END
		END;
		INC (adr, 16); DEC (size, 16)
	END;
	RETURN NilAdr	(* not found *)
END SearchMem;

(* Search for MP spec info. *)
PROCEDURE SearchMP;
VAR adr: ADDRESS;
BEGIN
	adr := 0;
	SYSTEM.GET (040EH, SYSTEM.VAL (INTEGER, adr));	(* EBDA address *)
	adr := adr*16;
	IF adr < 100000H THEN adr := SearchMem(adr, 1024)	(* 1. look in EBDA *)
	ELSE adr := NilAdr
	END;
	IF adr = NilAdr THEN	(* 2. look in last kb of base memory *)
		adr := SearchMem(lowTop + (-lowTop) MOD 10000H - 1024, 1024);
		IF adr = NilAdr THEN	(* 3. look at top of physical memory *)
			adr := SearchMem(memTop - 1024, 1024);
			IF adr = NilAdr THEN	(* 4. look in BIOS ROM space *)
				adr := SearchMem(0E0000H, 20000H)
			END
		END
	END;
	IF adr = NilAdr THEN
		revMP := 0X; configMP := NilAdr
	ELSE
		SYSTEM.GET (adr + 9, revMP);
		SYSTEM.MOVE(adr + 11, ADDRESSOF(featureMP[0]), 5);	(* feature bytes *)
		configMP := SYSTEM.GET32 (adr + 4);	(* physical address outside reported RAM (spec 1.4 p. 4-2) *)
		IF configMP = 0 THEN configMP := NilAdr END
	END
END SearchMP;

(* Allocate area for ISA DMA. *)
PROCEDURE AllocateDMA;
VAR old: ADDRESS;
BEGIN
	old := lowTop;
	dmaSize := DefaultDMASize*1024;
	ASSERT((dmaSize >= 0) & (dmaSize <= 65536));
	IF (lowTop-dmaSize) DIV 65536 # (lowTop-1) DIV 65536 THEN	(* crosses 64KB boundary *)
		DEC (lowTop, lowTop MOD 65536)	(* round down to 64KB boundary *)
	END;
	DEC (lowTop, dmaSize);	(* allocate memory *)
	dmaSize := old - lowTop	(* how much was allocated (including rounding) *)
END AllocateDMA;

(* Check if the specified address is RAM. *)
PROCEDURE IsRAM(adr: ADDRESS): BOOLEAN;
CONST Pattern1 = SHORT(0BEEFC0DEH); Pattern2 = SHORT(0AA55FF00H);
VAR save, x: LONGINT; ok: BOOLEAN;
BEGIN
	ok := FALSE;
	SYSTEM.GET (adr, save);
	SYSTEM.PUT (adr, Pattern1);	(* attempt 1st write *)
	x := Pattern2;				(* write something else *)
	SYSTEM.GET (adr, x);		(* attempt 1st read *)
	IF x = Pattern1 THEN		(* first test passed *)
		SYSTEM.PUT (adr, Pattern2);	(* attempt 2nd write *)
		x := Pattern1;			(* write something else *)
		SYSTEM.GET (adr, x);	(* attempt 2nd read *)
		ok := (x = Pattern2)
	END;
	SYSTEM.PUT (adr, save);
	RETURN ok
END IsRAM;

(* Map the physical address in the second virtual page *)
PROCEDURE -InvalidateTLB (address: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	POP RAX
	INVLPG [RAX]
END InvalidateTLB;

PROCEDURE -GetPML4Base (): ADDRESS;
CODE {SYSTEM.AMD64}
	MOV RAX, CR3
END GetPML4Base;

PROCEDURE -INVLPG (adr: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	POP RAX
	INVLPG [RAX]
END INVLPG;

(* Check amount of memory available and update memTop. *)
PROCEDURE CheckMemory;
CONST K = 1024; M = K * K; PS = 2 * M; ExtMemAdr = M;
	TPS = 4 * K; UserPage = 7; PageNotPresent = 0;
VAR s: ARRAY 16 OF CHAR; i: LONGINT;

	physicalAddress, pml4Base, pdpBase, pdBase: ADDRESS;
	pml4e, pdpe, pde, lastTable: ADDRESS;

	PROCEDURE AllocateTranslationTable (VAR baseAddress, firstEntry: ADDRESS);
	BEGIN
		baseAddress := lastTable;
		firstEntry := baseAddress;
		INC (lastTable, TPS);

		Fill32 (baseAddress, TPS, PageNotPresent)
	END AllocateTranslationTable;

BEGIN

	GetConfig("ExtMemSize", s);	(* in MB *)
	IF s[0] # 0X THEN	(* override detection *)
		i := 0;
		memTop := ExtMemAdr + LONG (StrToInt(i, s)) * M
	END;

	pml4Base := GetPML4Base ();
	DEC (pml4Base, pml4Base MOD TPS);

	SYSTEM.GET (pml4Base, pdpBase);
	DEC (pdpBase, pdpBase MOD TPS);

	SYSTEM.GET (pdpBase, pdBase);
	DEC (pdBase, pdBase MOD TPS);

	physicalAddress := PS;

	lastTable := pdBase + TPS;

	pml4e := pml4Base;
	pdpe := pdpBase;
	pde := pdBase;

	WHILE (pml4e < pml4Base + TPS) DO
		WHILE (pdpe < pdpBase + TPS) DO
			WHILE (pde < pdBase + TPS) DO
				INC (pde, 8);
				SYSTEM.PUT (pde, physicalAddress + UserPage + 80H);
				INVLPG (physicalAddress);
				INC (physicalAddress, PS);
				IF physicalAddress >= memTop THEN RETURN END;
			END;
			INC (pdpe, 8);
			AllocateTranslationTable (pdBase, pde);
			SYSTEM.PUT (pdpe, pde + UserPage);
		END;
		INC (pml4e, 8);
		AllocateTranslationTable (pdpBase, pdpe);
		SYSTEM.PUT (pml4e, pdpe + UserPage);
	END;

	HALT (99);
END CheckMemory;

(* Initialize locks. *)
PROCEDURE InitLocks;
VAR i: LONGINT; s: ARRAY 12 OF CHAR;
BEGIN
	IF TimeCount # 0 THEN
		GetConfig("LockTimeout", s);
		i := 0; maxTime := StrToInt(i, s);
		IF maxTime > MAX(LONGINT) DIV 1000000 THEN
			maxTime := MAX(LONGINT)
		ELSE
			maxTime := maxTime * 1000000
		END
	END;
	FOR i := 0 TO MaxCPU-1 DO
		proc[i].locksHeld := {}; proc[i].preemptCount := 0
	END;
	FOR i := 0 TO MaxLocks-1 DO
		lock[i].locked := FALSE
	END
END InitLocks;

(* Return flags state. *)
PROCEDURE -GetFlags (): SET;
CODE {SYSTEM.AMD64}
	PUSHFQ
	POP RAX
END GetFlags;

(* Set flags state. *)
PROCEDURE -SetFlags (s: SET);
CODE {SYSTEM.AMD64}
	POPFQ
END SetFlags;

PROCEDURE -PushFlags*;
CODE {SYSTEM.AMD64}
	PUSHFQ
END PushFlags;

PROCEDURE -PopFlags*;
CODE {SYSTEM.AMD64}
	POPFQ
END PopFlags;

(** Disable preemption on the current processor (increment the preemption counter). Returns the current processor ID as side effect. *)
PROCEDURE AcquirePreemption* (): LONGINT;
VAR id: LONGINT;
BEGIN
	PushFlags; Cli;
	id := ID ();
	INC (proc[id].preemptCount);
	PopFlags;
	RETURN id
END AcquirePreemption;

(** Enable preemption on the current processor (decrement the preemption counter). *)
PROCEDURE ReleasePreemption*;
VAR id: LONGINT;
BEGIN
	PushFlags; Cli;
	id := ID ();
	IF StrongChecks THEN
		ASSERT(proc[id].preemptCount > 0)
	END;
	DEC (proc[id].preemptCount);
	PopFlags
END ReleasePreemption;

(** Return the preemption counter of the current processor (specified in parameter). *)
PROCEDURE PreemptCount* (id: LONGINT): LONGINT;
BEGIN
	IF StrongChecks THEN
		(*ASSERT(~(9 IN GetFlags ()));*)	(* interrupts off *)	(* commented out because check is too strong *)
		ASSERT(id = ID ())	(* caller must specify current processor *)
	END;
	RETURN proc[id].preemptCount
END PreemptCount;

(* Spin waiting for a lock. Return AL = 1X iff timed out. *)
PROCEDURE AcquireSpinTimeout(VAR locked: BOOLEAN; count: LONGINT; flags: SET): CHAR;
CODE {SYSTEM.AMD64}
	MOV RSI, [RBP + flags]	; RSI := flags
	MOV EDI, [RBP + count]	; RDI := count
	MOV RBX, [RBP + locked]	; RBX := ADR(locked)
	MOV AL, 1	; AL := 1
	CLI	; switch interrupts off before acquiring lock

test:
	CMP [RBX], AL	; locked? { AL = 1 }
	JE wait	; yes, go wait
	XCHG [RBX], AL	; set and read the lock atomically.  LOCK prefix implicit.
	CMP AL, 1	; was locked?
	JNE exit	; no, we have it now, interrupts are off, and AL # 1

wait:
; ASSERT(AL = 1)
	XOR RCX, RCX	; just in case some processor interprets REP this way
	REP NOP	; PAUSE instruction (* see SpinHint *)

	TEST RSI, 200H	; bit 9 - IF
	JZ intoff
	STI	; restore interrupt state quickly to allow pending interrupts (e.g. AosProcessors.StopAll/Broadcast)
	NOP	; NOP required, otherwise STI; CLI not interruptable
	CLI	; disable interrupts
intoff:

	DEC EDI	; counter
	JNZ test	; not timed out yet
	OR EDI, [RBP + count]	; re-fetch original value & set flags
	JZ test	; if count = 0, retry forever
; timed out (AL = 1)

exit:
END AcquireSpinTimeout;

(** Acquire a spin-lock and disable interrupts. *)
PROCEDURE Acquire* (level: LONGINT);
VAR id, i: LONGINT; flags: SET; start: HUGEINT;
BEGIN
	id := AcquirePreemption ();
	flags := GetFlags ();	(* store state of interrupt flag *)
	IF StrongChecks THEN
		ASSERT(~(9 IN flags) OR (proc[id].locksHeld = {}));	(* interrupts enabled => no locks held *)
		ASSERT(~(level IN proc[id].locksHeld))	(* recursive locks not allowed *)
	END;
	IF (TimeCount = 0) OR (maxTime = 0) THEN
		IF AcquireSpinTimeout(lock[level].locked, 0, flags) = 0X THEN END;	(* {interrupts off} *)
	ELSE
		start := GetTimer ();
		WHILE AcquireSpinTimeout(lock[level].locked, TimeCount, flags) = 1X DO
			IF GetTimer () - start > maxTime THEN
				trapState := proc;
				trapLocksBusy := {};
				FOR i := 0 TO MaxLocks-1 DO
					IF lock[i].locked THEN INCL(trapLocksBusy, i) END
				END;
				HALT(1301)	(* Lock timeout - see Traps *)
			END
		END
	END;
	IF proc[id].locksHeld = {} THEN
		proc[id].state := flags
	END;
	INCL(proc[id].locksHeld, level);	(* we now hold the lock *)
	IF StrongChecks THEN	(* no lower-level locks currently held by this processor *)
		ASSERT((level = 0) OR (proc[id].locksHeld * {0..level-1} = {}))
	END
END Acquire;

(** Release a spin-lock. Switch on interrupts when last lock released. *)
PROCEDURE Release* (level: LONGINT);
VAR id: LONGINT; flags: SET;
BEGIN	(* {interrupts off} *)
	id := ID ();
	IF StrongChecks THEN
		ASSERT(~(9 IN GetFlags ()));	(* {interrupts off} *)
		ASSERT(lock[level].locked);
		ASSERT(level IN proc[id].locksHeld)
	END;
	EXCL(proc[id].locksHeld, level);
	IF proc[id].locksHeld = {} THEN
		flags := proc[id].state ELSE flags := GetFlags ()
	END;
	lock[level].locked := FALSE;
	SetFlags(flags);
	ReleasePreemption
END Release;

(** Acquire all locks. Only for exceptional cases. *)
PROCEDURE AcquireAll*;
VAR lock: LONGINT;
BEGIN
	FOR lock := HighestLock TO LowestLock BY -1 DO Acquire(lock) END
END AcquireAll;

(** Release all locks. Reverse of AcquireAll. *)
PROCEDURE ReleaseAll*;
VAR lock: LONGINT;
BEGIN
	FOR lock := LowestLock TO HighestLock DO Release(lock) END
END ReleaseAll;

(** Break all locks held by current processor (for exception handling). Returns levels released. *)
PROCEDURE BreakAll* (): SET;
VAR id, level: LONGINT; released: SET;
BEGIN
	id := AcquirePreemption ();
	PushFlags; Cli;
	released := {};
	FOR level := 0 TO MaxLocks-1 DO
		IF level IN proc[id].locksHeld THEN
			lock[level].locked := FALSE;	(* break the lock *)
			EXCL(proc[id].locksHeld, level);
			INCL(released, level)
		END
	END;
	IF proc[id].preemptCount > 1 THEN INCL(released, Preemption) END;
	proc[id].preemptCount := 0;	(* clear preemption flag *)
	PopFlags;
	RETURN released
END BreakAll;

(** Acquire a fine-grained lock on an active object. *)
PROCEDURE AcquireObject* (VAR locked: BOOLEAN);
CODE {SYSTEM.AMD64}
	PUSHFQ
	MOV RBX, [RBP + locked]	; RBX := ADR(locked)
	MOV AL, 1
test:
	CMP [RBX], AL	; locked? { AL = 1 }
	JNE try
	STI
	PAUSE	; PAUSE instruction (* see SpinHint *)
	CLI
	JMP test
try:
	XCHG [RBX], AL	; set and read the lock atomically.  LOCK prefix implicit.
	CMP AL, 1	; was locked?
	JE test	; yes, try again
	POPFQ
END AcquireObject;

(** Release an active object lock. *)
PROCEDURE ReleaseObject* (VAR locked: BOOLEAN);
CODE {SYSTEM.AMD64}
	MOV RBX, [RBP + locked]	; RBX := ADR(locked)
	MOV BYTE [RBX], 0
END ReleaseObject;

(* Load global descriptor table *)
PROCEDURE LoadGDT(base: ADDRESS; size: SIZE);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	; LGDT needs 10 bytes: 2 for the 16-bit limit and 8 for the 64-bit base address in this order
	; Assumption: size argument in front of base -> promote size value to upper 48 bits of size
	SHL QWORD [RBP + size], 64-16
	LGDT [RBP + size + (64-16) / 8]
END LoadGDT;

(* Load segment registers *)
PROCEDURE LoadSegRegs(data: INTEGER);
CODE {SYSTEM.AMD64}
	MOV AX, [RBP + data]
	MOV DS, AX
	XOR AX, AX
	MOV ES, AX
	MOV FS, AX
	MOV GS, AX
END LoadSegRegs;

(* Return CS. *)
PROCEDURE -CS* (): INTEGER;
CODE {SYSTEM.AMD64}
	MOV AX, CS
END CS;

(** -- Memory management -- *)

(* Allocate a physical page below 1M. Parameter adr returns physical and virtual address (or NilAdr).*)
PROCEDURE NewLowPage(VAR adr: ADDRESS);
BEGIN
	adr := freeLowPage;
	IF freeLowPage # NilAdr THEN
		SYSTEM.GET (freeLowPage, freeLowPage);	(* freeLowPage := freeLowPage.next *)
		DEC(freeLowPages)
	END
END NewLowPage;

(* Allocate a directly-mapped page. Parameter adr returns physical and virtual address (or NilAdr). *)
PROCEDURE NewDirectPage(VAR adr: ADDRESS);
BEGIN
	IF pageHeapAdr # heapEndAdr THEN
		DEC(pageHeapAdr, PS); adr := pageHeapAdr;
		DEC(freeHighPages)
	ELSE
		adr := NilAdr
	END
END NewDirectPage;

(* Allocate a physical page. *)
PROCEDURE NewPage(VAR physAdr: ADDRESS);
VAR sp, prev: ADDRESS;
BEGIN
	SYSTEM.GET(pageStackAdr + NodeSP, sp);
	ASSERT((sp >= MinSP) & (sp <= MaxSP) & (sp MOD AddressSize = 0));	(* index check *)
	IF sp > MinSP THEN	(* stack not empty, pop entry *)
		DEC(sp, AddressSize);
		SYSTEM.GET (pageStackAdr+sp, physAdr);
		SYSTEM.PUT (pageStackAdr+NodeSP, sp);
		SYSTEM.GET (pageStackAdr+NodePrev, prev);
		IF (sp = MinSP) & (prev # NilAdr) THEN
			pageStackAdr := prev
		END;
		DEC(freeHighPages)
	ELSE
		NewDirectPage(physAdr)
	END
END NewPage;

(* Deallocate a physical page. *)
PROCEDURE DisposePage(physAdr: ADDRESS);
VAR sp, next, newAdr: ADDRESS;
BEGIN
	SYSTEM.GET (pageStackAdr + NodeSP, sp);
	ASSERT((sp >= MinSP) & (sp <= MaxSP) & (sp MOD AddressSize = 0));	(* index check *)
	IF sp = MaxSP THEN	(* current stack full *)
		SYSTEM.GET (pageStackAdr + NodeNext, next);
		IF next # NilAdr THEN	(* next stack exists, make it current *)
			pageStackAdr := next;
			SYSTEM.GET (pageStackAdr+NodeSP, sp);
			ASSERT(sp = MinSP)	(* must be empty *)
		ELSE	(* allocate next stack *)
			NewDirectPage(newAdr);
			IF newAdr = NilAdr THEN
				NewLowPage(newAdr);	(* try again from reserve *)
				IF newAdr = NilAdr THEN
					IF Stats THEN INC(NlostPages) END;
					RETURN	(* give up (the disposed page is lost) *)
				ELSE
					IF Stats THEN INC(NreservePagesUsed) END
				END
			END;
			sp := MinSP;	(* will be written to NodeSP below *)
			SYSTEM.PUT (newAdr + NodeNext, next);
			SYSTEM.PUT (newAdr + NodePrev, pageStackAdr);
			pageStackAdr := newAdr
		END
	END;
		(* push entry on current stack *)
	SYSTEM.PUT (pageStackAdr + sp, physAdr);
	SYSTEM.PUT (pageStackAdr + NodeSP, sp + AddressSize);
	INC(freeHighPages)
END DisposePage;

(* Allocate virtual address space for mapping. Parameter size must be multiple of page size. Parameter virtAdr returns virtual address or NilAdr on failure. *)
PROCEDURE NewVirtual(VAR virtAdr: ADDRESS; size: SIZE);
BEGIN
	ASSERT(size MOD PS = 0);
(*
	IF mapTop+size > MapAreaAdr+MapAreaSize THEN
		virtAdr := NilAdr	(* out of virtual space *)
	ELSE
		virtAdr := mapTop;
		INC(mapTop, size)
	END
*)

	(*  this code is commented because PACO produces weird behaviour when used with
	64-bit ADDRESS*)

	virtAdr := mapTop;
	INC(mapTop, size)
END NewVirtual;

PROCEDURE DisposeVirtual(virtAdr: ADDRESS; size: SIZE);
	(* to do *)
END DisposeVirtual;

(* Map a physical page into the virtual address space. Parameter virtAdr is mapped address and phys is mapping value. Returns TRUE iff mapping successful. *)
PROCEDURE MapTable (base, index: ADDRESS): ADDRESS;
VAR pt: ADDRESS;
BEGIN
	SYSTEM.GET (base + index * AddressSize, pt);
	IF ODD (pt) THEN	(* pt present *)
		DEC (pt, pt MOD TPS)
	ELSE
		NewPage(pt);
		IF pt = NilAdr THEN RETURN NilAdr END;
		SYSTEM.PUT (base + index * AddressSize, pt + UserPage);
		Fill32 (pt, TPS, PageNotPresent)
	END;
	RETURN pt;
END MapTable;

PROCEDURE MapPage(virtAdr, phys: ADDRESS): BOOLEAN;
VAR i, pt: ADDRESS;
	pml4e, pdpe, pde, pte: ADDRESS;
BEGIN
	virtAdr := virtAdr DIV PS;
	pte := virtAdr MOD PTEs; virtAdr := virtAdr DIV PTEs;
	pde := virtAdr MOD PTEs; virtAdr := virtAdr DIV PTEs;
	pdpe := virtAdr MOD PTEs; virtAdr := virtAdr DIV PTEs;
	pml4e := virtAdr MOD PTEs;

	pt := MapTable (kernelPML4, pml4e);
	IF pt = NilAdr THEN RETURN FALSE END;

	pt := MapTable (pt, pdpe);
	IF pt = NilAdr THEN RETURN FALSE END;

	pt := MapTable (pt, pde);
	IF pt = NilAdr THEN RETURN FALSE END;

	SYSTEM.PUT(pt + pte * AddressSize, phys);

	RETURN TRUE;
END MapPage;

(* Return mapped page address for a given virtual address (ODD if mapped) *)
PROCEDURE MappedPage(virtAdr: ADDRESS): ADDRESS;
VAR pt: ADDRESS;
	pml4e, pdpe, pde, pte: ADDRESS;
BEGIN
	virtAdr := virtAdr DIV PS;
	pte := virtAdr MOD PTEs; virtAdr := virtAdr DIV PTEs;
	pde := virtAdr MOD PTEs; virtAdr := virtAdr DIV PTEs;
	pdpe := virtAdr MOD PTEs; virtAdr := virtAdr DIV PTEs;
	pml4e := virtAdr MOD PTEs;

	SYSTEM.GET(kernelPML4 + pml4e * AddressSize, pt);
	IF ~ODD(pt) THEN RETURN 0 END;

	DEC (pt, pt MOD 1000H);

	SYSTEM.GET(pt + pdpe * AddressSize, pt);
	IF ~ODD(pt) THEN RETURN 0 END;

	DEC (pt, pt MOD 1000H);

	SYSTEM.GET(pt + pde * AddressSize, pt);
	IF ~ODD(pt) THEN RETURN 0 END;

	DEC (pt, pt MOD 1000H);

	SYSTEM.GET (pt + pte * AddressSize, pt);
	RETURN pt;
END MappedPage;

(* Unmap a page and return the previous mapping, like MappedPage (). Caller must flush TLB. *)
PROCEDURE UnmapPage(virtAdr: ADDRESS): ADDRESS;
VAR t, pt: ADDRESS;
	pml4e, pdpe, pde, pte: ADDRESS;
BEGIN
	virtAdr := virtAdr DIV PS;
	pte := virtAdr MOD PTEs; virtAdr := virtAdr DIV PTEs;
	pde := virtAdr MOD PTEs; virtAdr := virtAdr DIV PTEs;
	pdpe := virtAdr MOD PTEs; virtAdr := virtAdr DIV PTEs;
	pml4e := virtAdr MOD PTEs;

	SYSTEM.GET(kernelPML4 + pml4e * AddressSize, pt);
	IF ~ODD(pt) THEN RETURN 0 END;

	DEC (pt, pt MOD 1000H);

	SYSTEM.GET(pt + pdpe * AddressSize, pt);
	IF ~ODD(pt) THEN RETURN 0 END;

	DEC (pt, pt MOD 1000H);

	SYSTEM.GET(pt + pde * AddressSize, pt);
	IF ~ODD(pt) THEN RETURN 0 END;

	DEC (pt, pt MOD 1000H);

	SYSTEM.GET(pt + pte * AddressSize, t);
	SYSTEM.PUT(pt + pte * AddressSize, NIL);

	INVLPG (t);

	RETURN t;
END UnmapPage;

(* Map area [virtAdr..virtAdr+size) directly to area [Adr(phys)..Adr(phys)+size). Returns TRUE iff successful. *)
PROCEDURE MapDirect(virtAdr: ADDRESS; size: SIZE; phys: ADDRESS): BOOLEAN;
BEGIN
(*
	Trace.String("MapDirect "); Trace.Address (virtAdr); Trace.Char(' '); Trace.Address (phys); Trace.Char (' '); Trace.Int (size, 0);
	Trace.Int(size DIV PS, 8); Trace.Ln;
*)
	ASSERT((virtAdr MOD PS = 0) & (size MOD PS = 0));
	WHILE size # 0 DO
		IF ~ODD(MappedPage(virtAdr)) THEN
			IF ~MapPage(virtAdr, phys) THEN RETURN FALSE END
		END;
		INC(virtAdr, PS); INC(phys, PS); DEC(size, PS)
	END;
	RETURN TRUE
END MapDirect;

(* Policy decision for heap expansion. NewBlock for the same block has failed try times. *)
PROCEDURE ExpandNow(try: LONGINT): BOOLEAN;
VAR size: SIZE;
BEGIN
	size := LSH(memBlockTail.endBlockAdr - memBlockHead.beginBlockAdr, -10);	(* heap size in KB *)
	RETURN (~ODD(try) OR (size < heapMinKB)) & (size < heapMaxKB)
END ExpandNow;

(* Try to expand the heap by at least "size" bytes *)
PROCEDURE ExpandHeap*(try: LONGINT; size: SIZE; VAR memBlock: MemoryBlock; VAR beginBlockAdr, endBlockAdr: ADDRESS);
BEGIN
	IF ExpandNow(try) THEN
		IF size < expandMin THEN size := expandMin END;
		beginBlockAdr := memBlockHead.endBlockAdr;
		endBlockAdr := beginBlockAdr;
		INC(endBlockAdr, size);
		SetHeapEndAdr(endBlockAdr);	(* in/out parameter *)
		memBlock := memBlockHead;
		(* endBlockAdr of memory block is set by caller after free block has been set in memory block - this process is part of lock-free heap expansion *)
	ELSE
		beginBlockAdr := memBlockHead.endBlockAdr;
		endBlockAdr := memBlockHead.endBlockAdr;
		memBlock := NIL
	END
END ExpandHeap;

(* Set memory block end address *)
PROCEDURE SetMemoryBlockEndAddress*(memBlock: MemoryBlock; endBlockAdr: ADDRESS);
BEGIN
	ASSERT(endBlockAdr >= memBlock.beginBlockAdr);
	memBlock.endBlockAdr := endBlockAdr
END SetMemoryBlockEndAddress;

(* Free unused memory block *)
PROCEDURE FreeMemBlock*(memBlock: MemoryBlock);
BEGIN
	HALT(515) (* impossible to free heap in I386 native A2 version *)
END FreeMemBlock;

(** Attempt to set the heap end address to the specified address. The returned value is the actual new end address (never smaller than previous value). *)
PROCEDURE SetHeapEndAdr(VAR endAdr: ADDRESS);
VAR n, m: SIZE;
BEGIN
	Acquire(Memory);
	n := LSH(endAdr+(PS-1), -PSlog2) - LSH(heapEndAdr, -PSlog2);	(* pages requested *)
	m := LSH(pageHeapAdr, -PSlog2) - LSH(heapEndAdr, -PSlog2) - ReservedPages;	(* max pages *)
	IF n > m THEN n := m END;
	IF n > 0 THEN INC(heapEndAdr, n*PS); DEC(freeHighPages, n) END;
	endAdr := heapEndAdr;
	Release(Memory)
END SetHeapEndAdr;

(** Map a physical memory area (physAdr..physAdr+size-1) into the virtual address space. Parameter virtAdr returns the virtual address of mapped region, or NilAdr on failure. *)
PROCEDURE MapPhysical*(physAdr: ADDRESS; size: SIZE; VAR virtAdr: ADDRESS);
VAR ofs: ADDRESS;
BEGIN
	IF (LSH(physAdr, -PSlog2) <= topPageNum) &
			(LSH(physAdr+size-1, -PSlog2) <= topPageNum) &
			(LSH(physAdr, -PSlog2) >= LSH(LowAdr, -PSlog2)) THEN
		virtAdr := physAdr	(* directly mapped *)
	ELSE
		ofs := physAdr MOD PS;
		DEC(physAdr, ofs); INC(size, ofs);	(* align start to page boundary *)
		INC(size, (-size) MOD PS);	(* align end to page boundary *)
		Acquire(Memory);
		NewVirtual(virtAdr, size);
		IF virtAdr # NilAdr THEN
			IF ~MapDirect(virtAdr, size, physAdr + UserPage) THEN
				DisposeVirtual(virtAdr, size);
				virtAdr := NilAdr
			END
		END;
		Release(Memory);
		IF TraceVerbose THEN
			Acquire (TraceOutput);
			Trace.String("Mapping ");
			Trace.IntSuffix(SHORT(size), 1, "B"); Trace.String(" at ");
			Trace.Address (physAdr); Trace.String (" - "); Trace.Address (physAdr+size-1);
			IF virtAdr = NilAdr THEN
				Trace.String(" failed")
			ELSE
				Trace.String (" to "); Trace.Address (virtAdr);
				IF ofs # 0 THEN Trace.String (", offset "); Trace.Int(SHORT(ofs), 0) END
			END;
			Trace.Ln;
			Release (TraceOutput);
		END;
		IF virtAdr # NilAdr THEN INC(virtAdr, ofs) END	(* adapt virtual address to correct offset *)
	END
END MapPhysical;

(** Unmap an area previously mapped with MapPhysical. *)
PROCEDURE UnmapPhysical*(virtAdr: ADDRESS; size: SIZE);
	(* to do *)
END UnmapPhysical;

(** Return the physical address of the specified range of memory, or NilAdr if the range is not contiguous. It is the caller's responsibility to assure the range remains allocated during the time it is in use. *)
PROCEDURE PhysicalAdr*(adr: ADDRESS; size: SIZE): ADDRESS;
VAR physAdr, mapped, expected: ADDRESS;
BEGIN
	IF (LSH(adr, -PSlog2) <= topPageNum) & (LSH(adr+size-1, -PSlog2) <= topPageNum) THEN
		RETURN adr	(* directly mapped *)
	ELSE
		Acquire(Memory);
		mapped := MappedPage(adr);
		Release(Memory);
		IF ODD(mapped) & (size > 0) THEN	(* mapped, and range not empty or too big *)
			physAdr := mapped - mapped MOD PS + adr MOD PS;	(* strip paging bits and add page offset *)
			(* now check if whole range is physically contiguous *)
			DEC(size, PS - adr MOD PS);	(* subtract distance to current page end *)
			IF size > 0 THEN	(* range crosses current page end *)
				expected := LSH(mapped, -PSlog2)+1;	(* expected physical page *)
				LOOP
					INC(adr, PS);	(* step to next page *)
					Acquire(Memory);
					mapped := MappedPage(adr);
					Release(Memory);
					IF ~ODD(mapped) OR (LSH(mapped, -PSlog2) # expected) THEN
						physAdr := NilAdr; EXIT
					END;
					DEC(size, PS);
					IF size <= 0 THEN EXIT END;	(* ok *)
					INC(expected)
				END
			ELSE
				(* ok, skip *)
			END
		ELSE
			physAdr := NilAdr
		END;
		RETURN physAdr
	END
END PhysicalAdr;

(** Translate a virtual address range to num ranges of physical address. num returns 0 on error. *)
PROCEDURE TranslateVirtual*(virtAdr: ADDRESS; size: SIZE;  VAR num: LONGINT; VAR physAdr: ARRAY OF Range);
VAR ofs, phys1: ADDRESS; size1: SIZE;
BEGIN
	Acquire(Memory);
	num := 0;
	LOOP
		IF size = 0 THEN EXIT END;
		IF num = LEN(physAdr) THEN num := 0; EXIT END;	(* index check *)
		ofs := virtAdr MOD PS;	(* offset in page *)
		size1 := PS - ofs;	(* distance to next page boundary *)
		IF size1 > size THEN size1 := size END;
		phys1 := MappedPage(virtAdr);
		IF ~ODD(phys1) THEN num := 0; EXIT END;	(* page not present *)
		physAdr[num].adr := phys1 - phys1 MOD PS + ofs;
		physAdr[num].size := size1; INC(num);
		INC(virtAdr, size1); DEC(size, size1)
	END;
	IF num = 0 THEN physAdr[0].adr := NilAdr; physAdr[0].size := 0 END;
	Release(Memory)
END TranslateVirtual;

(** Return information on free memory in Kbytes. *)
PROCEDURE GetFreeK*(VAR total, lowFree, highFree: SIZE);
CONST KperPage = PS DIV 1024;
BEGIN
	Acquire(Memory);
	total := totalPages * KperPage;
	lowFree := freeLowPages * KperPage;
	highFree := freeHighPages * KperPage;
	Release(Memory)
END GetFreeK;

(** -- Stack -- *)

(** Extend the stack to include the specified address, if possible. Returns TRUE iff ok. *)
PROCEDURE ExtendStack*(VAR s: Stack; virtAdr: ADDRESS): BOOLEAN;
VAR phys: ADDRESS; ok: BOOLEAN;
BEGIN
	Acquire(Memory);
	ok := FALSE;
	IF (virtAdr < s.high) & (virtAdr >= s.low) THEN
		DEC(virtAdr, virtAdr MOD PS);	(* round down to page boundary *)
		IF Stats & (virtAdr < s.adr-PS) THEN INC(Nbigskips) END;
		IF ODD(MappedPage(virtAdr)) THEN	(* already mapped *)
			ok := TRUE
		ELSE
			NewPage(phys);
			IF phys # NilAdr THEN
				IF MapPage(virtAdr, phys + UserPage) THEN
					IF virtAdr < s.adr THEN
						s.adr := virtAdr
					ELSE
						IF Stats THEN INC(Nfilled) END
					END;
					ok := TRUE
				ELSE
					DisposePage(phys)
				END
			END
		END
	END;
	Release(Memory);
	RETURN ok
END ExtendStack;

(** Allocate a stack. Parameter initSP returns initial stack pointer value. *)
PROCEDURE NewStack*(VAR s: Stack; process: ANY; VAR initSP: ADDRESS);
VAR adr, phys: ADDRESS; old: HUGEINT; free: SET;
BEGIN
	ASSERT(InitUserStackSize = PS);	(* for now *)
	Acquire(Memory);
	IF Stats THEN INC(NnewStacks) END;
	old := freeStackIndex;
	LOOP
		IF Stats THEN INC(NnewStackLoops) END;
		free := freeStack[freeStackIndex];
		IF free # {} THEN
			adr := 0; WHILE ~(adr IN free) DO INC(adr) END;	(* BTW: BSF instruction is not faster *)
			IF Stats THEN INC(NnewStackInnerLoops, adr+1) END;
			EXCL(freeStack[freeStackIndex], adr);
			adr := 10000000H + (freeStackIndex*SetSize + adr)*MaxUserStackSize; (*StackAreaAdr *)
			EXIT
		END;
		INC(freeStackIndex);
		IF freeStackIndex = LEN(freeStack) THEN freeStackIndex := 0 END;
		IF freeStackIndex = old THEN HALT(1503) END	(* out of stack space *)
	END;
	NewPage(phys); ASSERT(phys # NilAdr);	(* allocate one physical page at first *)
	s.high := adr + MaxUserStackSize; s.low := adr + UserStackGuardSize;
	s.adr := s.high - InitUserStackSize;	(* at the top of the virtual area *)
	initSP := s.high-AddressSize;
	IF ~MapPage(s.adr, phys + UserPage) THEN HALT(99) END;
	SYSTEM.PUT (initSP, process);
	Release(Memory)
END NewStack;

(** Return the process pointer set when the current user stack was created (must be running on user stack). *)
PROCEDURE -GetProcessPtr* (): ANY;
CODE {SYSTEM.AMD64}
	MOV RAX, -MaxUserStackSize
	AND RAX, RSP
	MOV RAX, [RAX + MaxUserStackSize - 8]
	POP RBX; pointer return passed via stack
	MOV [RBX], RAX
END GetProcessPtr;

(** True iff current process works on a kernel stack *)
PROCEDURE WorkingOnKernelStack* (): BOOLEAN;
VAR id: LONGINT; sp: ADDRESS;
BEGIN
	ASSERT(KernelStackSize # MaxUserStackSize - UserStackGuardSize); (* detection does only work with this assumption *)
	sp := CurrentSP ();
	id := ID ();
	RETURN (sp >= procm[id].stack.low) & (sp <= procm[id].stack.high)
END WorkingOnKernelStack;

(** Deallocate a stack. Current thread should not dispose its own stack. Uses privileged instructions. *)
PROCEDURE DisposeStack*(CONST s: Stack);
VAR adr, phys: ADDRESS;
BEGIN
	(* First make sure there are no references to virtual addresses of the old stack in the TLBs. This is required because we are freeing the pages, and they could be remapped later at different virtual addresses. DisposeStack will only be called from the thread finalizer, which ensures that the user will no longer be referencing this memory. Therefore we can make this upcall from outside the locked region, avoiding potential deadlock. *)
	GlobalFlushTLB;	(* finalizers are only called after Processors has initialized this upcall *)
	Acquire(Memory);
	IF Stats THEN INC(NdisposeStacks) END;
	adr := s.adr;	(* unmap and deallocate all pages of stack *)
	REPEAT
		phys := UnmapPage(adr);	(* TLB was flushed and no intermediate references possible to unreachable stack *)
		IF ODD(phys) THEN DisposePage(phys - phys MOD PS) END;
		INC(adr, PS)
	UNTIL adr = s.high;
	adr := (adr - MaxUserStackSize - StackAreaAdr) DIV MaxUserStackSize;
	INCL(freeStack[adr DIV 32], adr MOD 32);
	Release(Memory)
END DisposeStack;

(** Check if the specified stack is valid. *)
PROCEDURE ValidStack*(CONST s: Stack; sp: ADDRESS): BOOLEAN;
VAR valid: BOOLEAN;
BEGIN
	Acquire(Memory);
	valid := (sp MOD 4 = 0) & (sp >= s.adr) & (sp <= s.high);
	WHILE valid & (sp < s.high) DO
		valid := ODD(MappedPage(sp));
		INC(sp, PS)
	END;
	Release(Memory);
	RETURN valid
END ValidStack;

(** Update the stack snapshot of the current processor. (for Processors) *)
PROCEDURE UpdateState*;
VAR id: LONGINT;
BEGIN
	ASSERT(CS () MOD 4 = 0);	(* to get kernel stack pointer *)
	id := ID ();
	ASSERT(procm[id].stack.high # 0);	(* current processor stack has been assigned *)
	procm[id].sp := CurrentBP ()	(* instead of ESP, just fetch EBP of current procedure (does not contain pointers) *)
END UpdateState;

(** Get kernel stack regions for garbage collection. (for Heaps) *)
PROCEDURE GetKernelStacks*(VAR stack: ARRAY OF Stack);
VAR i: LONGINT;
BEGIN	(* {UpdateState has been called by each processor} *)
	FOR i := 0 TO MaxCPU-1 DO
		stack[i].adr := procm[i].sp;
		stack[i].high := procm[i].stack.high
	END
END GetKernelStacks;

(* Init page tables (paging still disabled until EnableMM is called). *)
PROCEDURE InitPages;
VAR i, j: HUGEINT; phys, lTop, mTop: ADDRESS;
BEGIN
	(* get top of high and low memory *)
	mTop := memTop;
	DEC(mTop, mTop MOD PS);	(* mTop MOD PS = 0 *)
	topPageNum := LSH(mTop-1, -PSlog2);
	lTop := lowTop;
	DEC(lTop, lTop MOD PS);	(* lTop MOD PS = 0 *)
	(* initialize NewDirectPage and SetHeapEndAdr (get kernel range) *)
	SYSTEM.GET (LinkAdr + EndBlockOfs, heapEndAdr);
(* ug *) (*
	SYSTEM.PUT (heapEndAdr, NIL);	(* set tag to NIL *)
	INC(heapEndAdr, AddressSize);	(* space for NIL *)
*)
(* ug: not needed, extension of heap done in GetStaticHeap anyway
	INC(heapEndAdr, K); (* space for free heap block descriptor of type Heaps.HeapBlockDesc at heapEndAdr, initialization is done in Heaps *)
	INC(heapEndAdr, (-heapEndAdr) MOD PS);	(* round up to page size *)
*)
	pageHeapAdr := mTop;
	freeHighPages := LSH(pageHeapAdr, -PSlog2) - LSH(heapEndAdr, -PSlog2);
	IF TraceVerbose THEN
		Trace.String("Kernel: "); Trace.Address (LinkAdr); Trace.String(" .. ");
		Trace.Address (heapEndAdr-1); Trace.Ln;
		Trace.String ("High: "); Trace.Address (heapEndAdr); Trace.String(" .. ");
		Trace.Address (pageHeapAdr-1); Trace.String(" = "); Trace.Int (SHORT(freeHighPages),0);
		Trace.StringLn (" free pages")
	END;
	(* initialize empty free page stack *)
	NewDirectPage(pageStackAdr); ASSERT(pageStackAdr # NilAdr);
	SYSTEM.PUT (pageStackAdr+NodeSP, SYSTEM.VAL (ADDRESS, MinSP));
	SYSTEM.PUT (pageStackAdr+NodeNext, SYSTEM.VAL (ADDRESS, NilAdr));
	SYSTEM.PUT (pageStackAdr+NodePrev, SYSTEM.VAL (ADDRESS, NilAdr));
	(* free low pages *)
	freeLowPage := NilAdr; freeLowPages := 0;
	i := lTop DIV PS; j := LowAdr DIV PS;
	IF TraceVerbose THEN
		Trace.String("Low: "); Trace.Address (j*PS); Trace.String (".."); Trace.Address (i*PS-1)
	END;
	REPEAT
		DEC(i); phys := i*PS;
		SYSTEM.PUT (phys, freeLowPage);	(* phys.next := freeLowPage *)
		freeLowPage := phys; INC(freeLowPages)
	UNTIL i = j;
	IF TraceVerbose THEN
		Trace.String(" = "); Trace.Int(SHORT(freeLowPages), 1); Trace.StringLn (" free pages")
	END;
	totalPages := LSH(memTop - M + lowTop + dmaSize + PS, -PSlog2);	(* what BIOS gave us *)
	(* stacks *)
	ASSERT((StackAreaAdr MOD MaxUserStackSize = 0) & (StackAreaSize MOD MaxUserStackSize = 0));
	FOR i := 0 TO LEN(freeStack)-1 DO freeStack[i] := {0..SetSize-1} END;
	FOR i := MaxUserStacks TO LEN(freeStack)*SetSize-1 DO EXCL(freeStack[i DIV SetSize], i MOD SetSize) END;
	freeStackIndex := 0;
	(* mappings *)
	mapTop := MapAreaAdr;
	(* create the address space *)
	NewPage(kernelPML4); ASSERT(kernelPML4 # NilAdr);
	Fill32(kernelPML4, TPS, PageNotPresent);
	IF ~MapDirect(LowAdr, memTop-LowAdr, LowAdr + UserPage) THEN HALT(99) END	(* map heap direct *)
END InitPages;

(* Generate a memory segment descriptor. type IN {0..7} & dpl IN {0..3}.

type
0	data, expand-up, read-only
1	data, expand-up, read-write
2	data, expand-down, read-only
3	data, expand-down, read-write
4	code, non-conforming, execute-only
5	code, non-conforming, execute-read
6	code, conforming, execute-only
7	code, conforming, execute-read
*)

PROCEDURE GenCodeSegDesc (dpl, base, limit: LONGINT;  conforming, longmode: BOOLEAN;  VAR sd: SegDesc);
VAR s: SET;
BEGIN
	sd.low := ASH(base MOD 10000H, 16) + limit MOD 10000H;
	s := SYSTEM.VAL(SET, ASH(ASH(base, -24), 24) + ASH(ASH(limit, -16), 16) +
		ASH(dpl, 13) + ASH(base, -16) MOD 100H);
	s := s + {9, 11, 12, 15, 23};	(* present=1, D = 0*)
	IF conforming THEN INCL(s, 10) END;
	IF longmode THEN INCL(s, 21) ELSE INCL (s, 22) END;	(* long mode flag or default 32-bit operand *)
	sd.high := SYSTEM.VAL(LONGINT, s)
END GenCodeSegDesc;

PROCEDURE GenDataSegDesc (dpl, base, limit: LONGINT; VAR sd: SegDesc);
VAR s: SET;
BEGIN
	sd.low := ASH(base MOD 10000H, 16) + limit MOD 10000H;
	s := SYSTEM.VAL(SET, ASH(ASH(base, -24), 24) + ASH(ASH(limit, -16), 16) +
		ASH(dpl, 13) + ASH(base, -16) MOD 100H);
	s := s +  {9, 12, 15, 22, 23};	(* present=1 *)
	sd.high := SYSTEM.VAL(LONGINT, s)
END GenDataSegDesc;

(* Generate a 64-bit TSS descriptor (16bytes). *)
PROCEDURE GenTSSDesc(base: ADDRESS; limit, dpl: LONGINT;  VAR sdl, sdh: SegDesc);
VAR s: SET;
BEGIN
	sdl.low := SYSTEM.VAL(LONGINT, ASH(base MOD 10000H, 16) + limit MOD 10000H);
	s := SYSTEM.VAL(SET, ASH(ASH(base, -24), 24) + ASH(ASH(limit, -16), 16) +
		ASH(dpl, 13) + ASH(base, -16) MOD 100H);
	s := s + {8, 11, 15};	(* type=non-busy TSS, present=1, AVL=0, 32-bit=0 *)
	sdl.high := SYSTEM.VAL(LONGINT, s);
	sdh.low := SYSTEM.VAL(LONGINT, base DIV 10000000H);
	sdh.high := 0;
END GenTSSDesc;

(* Initialize segmentation. *)
PROCEDURE InitSegments;
VAR i: LONGINT;
BEGIN
	(* limits and bases are ignored in 64-bit mode *)

	(* GDT 0: Null segment *)
	gdt[0].low := 0;  gdt[0].high := 0;
	(* GDT 1: 32-bit Kernel code: non-conforming, execute-read, base 0, limit 4G, PL 0 *)
	GenCodeSegDesc(0, 0, M-1, FALSE, FALSE, gdt[1]);
	(* GDT 2: 64-bit Kernel code: non-conforming, execute-read, base 0, limit 4G, PL 0 *)
	GenCodeSegDesc(0, 0, M-1, FALSE, TRUE, gdt[2]);
	(* GDT 3: 32-bit User code: non-conforming, execute-read, base 0, limit 4G, PL 0 *)
	GenCodeSegDesc(0, 0, M-1, TRUE, FALSE, gdt[3]);
	(* GDT 4: 64-bit User code: conforming, execute-read, base 0, limit 4G, PL 0 *)
	GenCodeSegDesc(0, 0, M-1, TRUE, TRUE, gdt[4]);
	(* GDT 5: Kernel stack: read-write, base 0, limit 4G, PL 0 *)
	GenDataSegDesc(0, 0, M-1, gdt[5]);
	(* GDT 6: User stack: read-write, base 0, limit 4G, PL 3 *)
	GenDataSegDesc(3, 0, M-1, gdt[6]);
	(* GDT 7: User/Kernel data: expand-up, read-write, base 0, limit 4G, PL 3 *)
	GenDataSegDesc(3, 0, M-1, gdt[7]);

	FOR i := 0 TO MaxCPU-1 DO
		GenTSSDesc(ADDRESSOF(procm[i].tss), SIZEOF(TSSDesc)-1, 0, gdt[TSSOfs+i*2], gdt[TSSOfs+i*2 + 1]);
		procm[i].sp := 0;  procm[i].stack.high := 0
	END
END InitSegments;

(* Enable segmentation on the current processor. *)
PROCEDURE EnableSegments;
BEGIN
	LoadGDT(ADDRESSOF(gdt[0]), SIZEOF(GDT)-1);
	LoadSegRegs(DataSel)
END EnableSegments;

(* Allocate a kernel stack. *)
PROCEDURE NewKernelStack(VAR stack: Stack);
VAR phys, virt: ADDRESS; size: SIZE;
BEGIN
	size := KernelStackSize;
	NewVirtual(virt, size + PS);	(* add one page for overflow protection *)
	ASSERT(virt # NilAdr, 1502);
	INC(virt, PS);	(* leave page open at bottom *)
	stack.low := virt;
	stack.adr := virt;	(* return stack *)
	REPEAT
		NewPage(phys); ASSERT(phys # NilAdr);
		IF ~MapPage(virt, phys + KernelPage) THEN HALT(99) END;
		DEC(size, PS); INC(virt, PS)
	UNTIL size = 0;
	stack.high := virt
END NewKernelStack;

(* Set task register *)
PROCEDURE -SetTR(tr: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	POP RAX
	LTR AX
END SetTR;

(* Enable memory management and switch to new stack in virtual space.

	Stack layout:
			caller1 return
			caller1 RBP	<-- caller0 RBP
			[caller0 locals]
	04	caller0 return
	00	caller0 RBP	<-- RBP
			locals	<-- RSP
*)

PROCEDURE -EnableMM(pml4Base, rsp: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	POP RBX
	POP RAX

	MOV RCX, [RBP + 8]		; caller0 return
	MOV RDX, [RBP]		; caller0 RBP
	MOV RDX, [RDX + 8]	; caller 1 return

	MOV CR3, RAX			; pml4 page translation base address

	XOR RAX, RAX
	MOV [RBX - 8], RAX	; not UserStackSel (cf. GetUserStack)
	MOV [RBX - 16], RDX	; caller1 return on new stack
	MOV [RBX - 24], RAX	; caller1 RBP on new stack

	LEA RBP, [RBX - 24]		; new stack top
	MOV RSP, RBP

	JMP RCX
END EnableMM;

(** -- Initialization -- *)

(** Initialize memory management.
	o every processor calls this once during initialization
	o mutual exclusion with other processors must be guaranteed by the caller
	o interrupts must be off
	o segmentation and paging is enabled
	o return is on the new stack => caller must have no local variables
*)

PROCEDURE InitMemory*;
VAR id: LONGINT;
BEGIN
	EnableSegments;
	(* allocate stack *)
	id := ID ();
	NewKernelStack(procm[id].stack);
	procm[id].sp := 0;
	(* initialize TSS *)
	Fill32(ADDRESSOF(procm[id].tss), SIZEOF(TSSDesc), 0);
	procm[id].tss.RSP0 := procm[id].stack.high;	(* kernel stack org *)
	procm[id].tss.IOMapBaseAddress := -1;	(* no bitmap *)
	(* enable paging and switch stack *)
	SetTR(KernelTR + id*16);
	EnableMM(kernelPML4, procm[id].tss.RSP0)
END InitMemory;

(** Initialize a boot page for MP booting. Parameter physAdr returns the physical address of a low page. *)
PROCEDURE InitBootPage*(start: Startup; VAR physAdr: ADDRESS);
CONST BootOfs = 800H;
VAR adr, a: ADDRESS;
BEGIN
	Acquire(Memory);
	NewLowPage(physAdr);
	Release(Memory);
	ASSERT((physAdr # NilAdr) & (physAdr >= 0) & (physAdr < M) & (physAdr MOD PS = 0));
	adr := physAdr + BootOfs;
	a := adr;


(* put binary code copy of SMP.Bin to address a (cf. BinToCode.Mod ) *)

SYSTEM.PUT32(a, 0002F10EBH); INC (a, 4);

SYSTEM.PUT32(a, 000000000H); INC (a, 4);

SYSTEM.PUT32(a, 000000000H); INC (a, 4);

SYSTEM.PUT32(a, 000000000H); INC (a, 4);

SYSTEM.PUT32(a, 031660000H); INC (a, 4);

SYSTEM.PUT32(a, 066C88CC0H); INC (a, 4);

SYSTEM.PUT32(a, 02E04E0C1H); INC (a, 4);

SYSTEM.PUT32(a, 04A060966H); INC (a, 4);

SYSTEM.PUT32(a, 0010F2E08H); INC (a, 4);

SYSTEM.PUT32(a, 02E08081EH); INC (a, 4);

SYSTEM.PUT32(a, 00216010FH); INC (a, 4);

SYSTEM.PUT32(a, 0C4896608H); INC (a, 4);

SYSTEM.PUT32(a, 000C48166H); INC (a, 4);

SYSTEM.PUT32(a, 00F000008H); INC (a, 4);

SYSTEM.PUT32(a, 00F66C020H); INC (a, 4);

SYSTEM.PUT32(a, 00F00E8BAH); INC (a, 4);

SYSTEM.PUT32(a, 0662EC022H); INC (a, 4);

SYSTEM.PUT32(a, 0080E1E8BH); INC (a, 4);

SYSTEM.PUT32(a, 00850EA66H); INC (a, 4);

SYSTEM.PUT32(a, 000080000H); INC (a, 4);

SYSTEM.PUT32(a, 00FE0200FH); INC (a, 4);

SYSTEM.PUT32(a, 00F05E8BAH); INC (a, 4);

SYSTEM.PUT32(a, 0220FE022H); INC (a, 4);

SYSTEM.PUT32(a, 00080B9DBH); INC (a, 4);

SYSTEM.PUT32(a, 0320FC000H); INC (a, 4);

SYSTEM.PUT32(a, 008E8BA0FH); INC (a, 4);

SYSTEM.PUT32(a, 0200F300FH); INC (a, 4);

SYSTEM.PUT32(a, 0E8BA0FC0H); INC (a, 4);

SYSTEM.PUT32(a, 0C0220F1FH); INC (a, 4);

SYSTEM.PUT32(a, 0000000EAH); INC (a, 4);

SYSTEM.PUT16(a, 01000H); INC (a, 2);

SYSTEM.PUT8(a, 000H); INC (a);

(* the following offsets must be patched and can be reported
   by the assembler when assembling SMP.S with: PCAAMD64.Assemble SMP.S l~ *)

	SYSTEM.PUT32 (adr+14, SYSTEM.VAL (LONGINT, kernelPML4));		(* cf. label PML4BASE *)

	SYSTEM.PUT32 (adr+117, SYSTEM.VAL (LONGINT, start));	(* not a method *) (* cf. label KENTRY *)

	SYSTEM.PUT32 (adr+4, SYSTEM.VAL (LONGINT, ADDRESSOF(gdt[0]))); (* cf. label GDT *)


	(* jump at start *)
	SYSTEM.PUT8(physAdr, 0EAX);	(* jmp far *)
	SYSTEM.PUT32(physAdr + 1, ASH(physAdr, 16-4) + BootOfs)	(* seg:ofs *)
END InitBootPage;

(** The BP in a MP system calls this to map the APIC physical address directly. *)
PROCEDURE InitAPICArea*(adr: ADDRESS; size: SIZE);
BEGIN
(*	ASSERT((size = PS) & (adr >= IntelAreaAdr) & (adr+size-1 < IntelAreaAdr+IntelAreaSize)); *)
	IF ~MapDirect(adr, size, adr + UserPage) THEN HALT(99) END
END InitAPICArea;

(* Set machine-dependent parameters gcThreshold, expandMin, heapMinKB and heapMaxKB *)
PROCEDURE SetGCParams*;
VAR size, t: SIZE;
BEGIN
	GetFreeK(size, t, t);	(* size is total memory size in KB *)
	heapMinKB := size * HeapMin DIV 100;
	heapMaxKB := size * HeapMax DIV 100;
	expandMin := size * ExpandRate DIV 100 * 1024;
	IF expandMin < 0 THEN expandMin := MAX(LONGINT) END;
	gcThreshold := size * Threshold DIV 100 * 1024;
	IF gcThreshold < 0 THEN gcThreshold := MAX(LONGINT) END
END SetGCParams;

(** Get first memory block and first free address, heap area in first memory block is automatically expanded to account for the first
      few calls to NEW  *)
PROCEDURE GetStaticHeap*(VAR beginBlockAdr, endBlockAdr, freeBlockAdr: ADDRESS);
BEGIN
	beginBlockAdr := initialMemBlock.beginBlockAdr;
	endBlockAdr := initialMemBlock.endBlockAdr;
	freeBlockAdr := beginBlockAdr;
END GetStaticHeap;

(* returns if an address is a currently allocated heap address *)
PROCEDURE ValidHeapAddress*(p: ADDRESS): BOOLEAN;
BEGIN
	RETURN (p >= memBlockHead.beginBlockAdr) & (p <= memBlockTail.endBlockAdr)
		OR (p>=401000H) & (p<=500000H) (*! guess until kernel size known *)
END ValidHeapAddress;

(** Jump from kernel to user mode. Every processor calls this during initialization. *)
PROCEDURE JumpToUserLevel*(userRBP: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	PUSH UserStackSel	; SS3
	PUSH QWORD [RBP + userRBP]	; RSP3
	PUSHFQ	; RFLAGS3
	PUSH User64CodeSel	; CS3
	CALL DWORD L1	; PUSH L1 (RIP3)
L1:
	ADD QWORD [RSP], BYTE 7	; adjust RIP3 to L2 (L2-L1 should be 7)
	IRETQ	; switch to level 3 and continue at following instruction
L2:
	POP RBP	; from level 3 stack (refer to AosActive.NewProcess)
	RET	; jump to body of first active object; cf. Objects.NewProcess
END JumpToUserLevel;

(* should ensure that a given address can be represented in the legacy 4GB address space
	replacement for unsafe: x := SYSTEM.VAL (LONGINT, y) with y of type ADDRESS
	-> better rewrite client code! this procedure should be redundant and removable in the end! *)

PROCEDURE Ensure32BitAddress*(adr: ADDRESS): Address32;
BEGIN
	(* TODO *)
	ASSERT (Is32BitAddress (adr), 9876);
	RETURN SYSTEM.VAL (Address32, adr)
END Ensure32BitAddress;

PROCEDURE Is32BitAddress*(adr: ADDRESS): BOOLEAN;
BEGIN RETURN SYSTEM.VAL (Address32, adr) = adr;
END Is32BitAddress;

(**
 * Flush Data Cache for the specified virtual address range. If len is negative, flushes the whole cache.
 * This is used on some architecture to interact with DMA hardware (e.g. Ethernet and USB. It can be
 * left empty on Intel architecture.
 *)
PROCEDURE FlushDCacheRange * (adr: ADDRESS; len: LONGINT);
END FlushDCacheRange;

(**
 * Invalidate Data Cache for the specified virtual address range. If len is negative, flushes the whole cache.
 * This is used on some architecture to interact with DMA hardware (e.g. Ethernet and USB. It can be
 * left empty on Intel architecture.
 *)
PROCEDURE InvalidateDCacheRange * (adr: ADDRESS; len: LONGINT);
END InvalidateDCacheRange;

(**
 * Invalidate Instruction Cache for the specified virtual address range. If len is negative, flushes the whole cache.
 * This is used on some architecture to interact with DMA hardware (e.g. Ethernet and USB. It can be
 * left empty on Intel architecture.
 *)
PROCEDURE InvalidateICacheRange * (adr: ADDRESS; len: LONGINT);
END InvalidateICacheRange;

(* Unexpected - Default interrupt handler *)
PROCEDURE Unexpected(VAR state: State);
VAR int: HUGEINT; isr, irr: CHAR;
BEGIN
	int := state.INT;
	IF HandleSpurious & ((int >= IRQ0) & (int <= MaxIRQ) OR (int = MPSPU)) THEN	(* unexpected IRQ, get more info *)
		IF (int >= IRQ8) & (int <= IRQ15) THEN
			Portout8 (IntB0, 0BX); Portin8(IntB0, isr);
			Portout8 (IntB0, 0AX); Portin8(IntB0, irr)
		ELSIF (int >= IRQ0) & (int <= IRQ7) THEN
			Portout8 (IntA0, 0BX); Portin8(IntA0, isr);
			Portout8 (IntA0, 0AX); Portin8(IntA0, irr)
		ELSE
			isr := 0X; irr := 0X
		END;
		IF TraceSpurious THEN
			Acquire (TraceOutput);
			Trace.String("INT"); Trace.Int(SHORT(int), 1);
			Trace.Hex(ORD(isr), -3); Trace.Hex(ORD(irr), -2); Trace.Ln;
			Release (TraceOutput);
		END
	ELSE
		Acquire (TraceOutput);
		Trace.StringLn ("Unexpected interrupt");
		Trace.Memory(ADDRESSOF(state), SIZEOF(State)-4*8);	(* exclude last 4 fields *)
		IF int = 3 THEN	(* was a HALT or ASSERT *)
			(* It seems that no trap handler is installed (Traps not linked), so wait endlessly, while holding trace lock. This should quiten down the system, although other processors may possibly still run processes. *)
			LOOP END
		ELSE
			Release (TraceOutput);
			SetRAX(int);
			HALT(1801)	(* unexpected interrupt *)
		END
	END
END Unexpected;

(* InEnableIRQ - Enable a hardware interrupt (caller must hold module lock). *)
PROCEDURE -InEnableIRQ (int: HUGEINT);
CODE {SYSTEM.AMD64}
	POP RBX
	CMP RBX, IRQ7
	JG cont2
	IN AL, IntA1
	SUB RBX, IRQ0
	BTR RAX, RBX
	OUT IntA1, AL
	JMP end
cont2:
	IN AL, IntB1
	SUB RBX, IRQ8
	BTR RAX, RBX
	OUT IntB1, AL
end:
END InEnableIRQ;

(* InDisableIRQ - Disable a hardware interrupt (caller must hold module lock). *)
PROCEDURE -InDisableIRQ (int: HUGEINT);
CODE {SYSTEM.AMD64}
	POP RBX
	CMP RBX, IRQ7
	JG cont2
	IN AL, IntA1
	SUB RBX, IRQ0
	BTS RAX, RBX
	OUT IntA1, AL
	JMP end
cont2:
	IN AL, IntB1
	SUB RBX, IRQ8
	BTS RAX, RBX
	OUT IntB1, AL
end:
END InDisableIRQ;

(** EnableIRQ - Enable a hardware interrupt (also done automatically by InstallHandler). *)
PROCEDURE EnableIRQ* (int: HUGEINT);
BEGIN
(*	ASSERT((int >= IRQ0) & (int <= IRQ15) & (int # IRQ2)); *)
	Acquire(Interrupts);	(* protect interrupt mask register *)
	InEnableIRQ(int);
	Release(Interrupts)
END EnableIRQ;

(** DisableIRQ - Disable a hardware interrupt. *)
PROCEDURE DisableIRQ* (int: HUGEINT);
BEGIN
	ASSERT((int >= IRQ0) & (int <= IRQ15) & (int # IRQ2));
	Acquire(Interrupts);	(* protect interrupt mask register *)
	InDisableIRQ(int);
	Release(Interrupts)
END DisableIRQ;

(** InstallHandler - Install interrupt handler & enable IRQ if necessary.
	On entry to h interrupts are disabled and may be enabled with Sti. After handling the interrupt
	the state of interrupts are restored. The acknowledgement of a hardware interrupt is done automatically.
	IRQs are mapped from IRQ0 to MaxIRQ. *)
PROCEDURE InstallHandler* (h: Handler; int: LONGINT);
VAR (* n: HandlerList; *) i: LONGINT; unexpected: Handler;
BEGIN
	ASSERT(default.valid);	(* initialized *)
	ASSERT(int # IRQ2);	(* IRQ2 is used for cascading and remapped to IRQ9 *)
	Acquire(Interrupts);
		(* FieldInterrupt may traverse list while it is being modified *)
	i := 0;
	unexpected := Unexpected;
	IF intHandler[int, 0].handler # unexpected THEN
		WHILE (i < MaxNumHandlers - 1) & intHandler[int, i].valid DO
			INC(i)
		END;
		IF i < MaxNumHandlers - 1 THEN
			intHandler[int, i].valid := TRUE;
			intHandler[int, i].handler := h;
		ELSE
			Acquire(TraceOutput);
			Trace.String("Machine.InstallHandler: handler could not be installed for interrupt "); Trace.Int(int,  0);
			Trace.String(" - too many handlers per interrupt number"); Trace.Ln;
			Release(TraceOutput)
		END
	ELSE
		intHandler[int, 0].handler := h;
		IF (int >= IRQ0) & (int <= IRQ15) THEN InEnableIRQ(int) END
	END;
	Release(Interrupts)
END InstallHandler;

(** RemoveHandler - Uninstall interrupt handler & disable IRQ if necessary *)
PROCEDURE RemoveHandler* (h: Handler; int: LONGINT);
VAR (* p, c: HandlerList; *) i, j, foundIndex: LONGINT;
BEGIN
	ASSERT(default.valid);	(* initialized *)
	Acquire(Interrupts);
	(* find h *)
	i := 0;
	foundIndex := -1;
	WHILE  (i < MaxNumHandlers - 1) & intHandler[int, i].valid DO
		IF intHandler[int, i].handler = h THEN foundIndex := i END;
		INC(i)
	END;
	IF foundIndex # -1 THEN
		(* h found -> copy interrupt handlers higher than foundIndex *)
		FOR j := foundIndex TO i - 2 DO
			intHandler[int, j] := intHandler[int, j + 1]
		END
	END;
	IF ~intHandler[int, 0].valid THEN
		(* handler h was the only interrupt handler for interrupt int -> install the default handler *)
		intHandler[int, 0] := default;
		IF (int >= IRQ0) & (int <= IRQ15) THEN DisableIRQ(int) END
	END;
	Release(Interrupts)
END RemoveHandler;

(* Get control registers. *)
PROCEDURE GetCR0to4(VAR cr: ARRAY OF HUGEINT);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	MOV RDI, [RBP + cr]
	MOV RAX, CR0
	XOR RBX, RBX	; CR1 is not documented
	MOV RCX, CR2
	MOV RDX, CR3
	MOV [RDI + 0], RAX
	MOV [RDI + 8], RBX
	MOV [RDI + 16], RCX
	MOV [RDI + 24], RDX
	MOV RAX, CR4	; Pentium only
	MOV [RDI + 32], RAX
END GetCR0to4;

(* GetDR0to7 - Get debug registers. *)
PROCEDURE GetDR0to7(VAR dr: ARRAY OF HUGEINT);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	MOV RDI, [RBP + dr]
	MOV RAX, DR0
	MOV RBX, DR1
	MOV RCX, DR2
	MOV RDX, DR3
	MOV [RDI + 0], RAX
	MOV [RDI + 8], RBX
	MOV [RDI + 16], RCX
	MOV [RDI + 24], RDX
	XOR RAX, RAX	; DR4 is not documented
	XOR RBX, RBX	; DR5 is not documented
	MOV RCX, DR6
	MOV RDX, DR7
	MOV [RDI + 32], RAX
	MOV [RDI + 40], RBX
	MOV [RDI + 48], RCX
	MOV [RDI + 56], RDX
END GetDR0to7;

(* CLTS - Clear task-switched flag. *)
PROCEDURE -CLTS;
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	CLTS
END CLTS;

(* GetFPU - Store floating-point environment (28 bytes) and mask all floating-point exceptions. *)
PROCEDURE -GetFPU(adr: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	POP RBX
	FNSTENV [RBX]	; also masks all exceptions
	FWAIT
END GetFPU;

(* CR2 - Get page fault address. *)
PROCEDURE -CR2* (): ADDRESS;
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	MOV RAX, CR2
END CR2;

(** GetExceptionState - Get exception state from interrupt state (and switch on interrupts). *)
PROCEDURE GetExceptionState* (VAR int: State; VAR exc: ExceptionState);
VAR id: LONGINT; level0: BOOLEAN;
BEGIN
	(* save all state information while interrupts are still disabled *)
	exc.halt := -int.INT; id := ID ();
	IF int.INT = PF THEN exc.pf := CR2 () ELSE exc.pf := 0 END;
	GetCR0to4(exc.CR);
	GetDR0to7(exc.DR);
	CLTS;	(* ignore task switch flag *)
	IF int.INT = MF THEN
		GetFPU(ADDRESSOF(exc.FPU[0]));
		int.PC := SYSTEM.VAL (ADDRESS, exc.FPU[3]);	(* modify PC according to FPU info *)
		(* set halt code according to FPU info *)
		IF 2 IN exc.FPU[1] THEN exc.halt := -32		(* division by 0 *)
		ELSIF 3 IN exc.FPU[1] THEN exc.halt := -33	(* overflow *)
		ELSIF 0 IN exc.FPU[1] THEN exc.halt := -34	(* operation invalid *)
		ELSIF 6 IN exc.FPU[1] THEN exc.halt := -35	(* stack fault *)
		ELSIF 1 IN exc.FPU[1] THEN exc.halt := -36	(* denormalized *)
		ELSIF 4 IN exc.FPU[1] THEN exc.halt := -37	(* underflow *)
		ELSIF 5 IN exc.FPU[1] THEN exc.halt := -38	(* precision loss *)
		ELSE	(* {exc.halt = -16} *)
		END
	ELSE
		Fill32(ADDRESSOF(exc.FPU[0]), LEN(exc.FPU)*SIZEOF(SET), 0)
	END;
	SetupFPU;
	level0 := (int.CS MOD 4 = KernelLevel);
	IF int.INT = BP THEN	(* breakpoint (HALT) *)
		IF level0 THEN
			exc.halt := int.SP	(* get halt code *)
			(* if HALT(MAX(INTEGER)), leave halt code on stack when returning, but not serious problem.*)
		ELSE
			SYSTEM.GET (int.SP, exc.halt);	(* get halt code from outer stack *)
			IF exc.halt >= MAX(INTEGER) THEN INC (int.SP, AddressSize) END	(* pop halt code from outer stack *)
		END;
		IF exc.halt < MAX(INTEGER) THEN DEC (int.PC) END;	(* point to the INT 3 instruction (assume 0CCX, not 0CDX 3X) *)
	ELSIF int.INT = OVF THEN	(* overflow *)
		DEC (int.PC)	(* point to the INTO instruction (assume 0CEX, not 0CDX 4X) *)
	ELSIF int.INT = PF THEN	(* page fault *)
		IF int.PC = 0 THEN	(* reset PC to return address of indirect CALL to 0 *)
			IF level0 THEN int.PC := int.SP (* ret adr *) ELSE SYSTEM.GET (int.SP, int.PC) END
		END
	END;
	(* get segment registers *)
	IF level0 THEN	(* from same level, no ESP, SS etc. on stack *)
		exc.SP := ADDRESSOF(int.SP)	(* stack was here when interrupt happened *)
	ELSE	(* from outer level *)
		exc.SP := int.SP
	END
END GetExceptionState;

(* FieldInterrupt and FieldIRQ *)

(*
	At entry to a Handler procedure the stack is as follows:
		-- if (VMBit IN .RFLAGS) --
		176	--	.SS
		168	--	.RSP	; or haltcode
		-- (VMBit IN .RFLAGS) OR (CS MOD 4 < .CS MOD 4) --
		160	--	.RFLAGS
		152	--	.CS
		144	--	.RIP	; rest popped by IRETD
		136	--	.ERR/RBP	; pushed by processor or glue code, popped by POP RBP
		128	--	.INT	<-- .RSP0	; pushed by glue code, popped by POP RBP
		120	--	.RAX
		112	--	.RCX
		104	--	.RDX
		96	--	.RBX
		88	--	.RSP0
		80	--	.RBP/ERR	; exchanged by glue code
		72	--	.RSI
		64	--	.RDI
		56	--	.R8
		48	--	.R9
		40	--	.R10
		32	--	.R11
		24	--	.R12
		16	--	.R13
		08	--	.R14
		00	48	.R15	<--- state: State
		--	40	ptr
		--	32	object pointer for DELEGATE
		--	24	TAG(state)
		--	16	ADR(state)
		--	08	RIP'	(RET to FieldInterrupt)
		--	00	RBP'	<-- RBP
		--	--	locals	<-- RSP
*)

PROCEDURE {NOPAF} FieldInterrupt;
CONST SizeOfHandlerRec = SIZEOF(HandlerRec);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
entry:

	; fake PUSHAD (not available in 64-bit mode)
	PUSH RAX
	PUSH RCX
	PUSH RDX
	PUSH RBX	; (error code)
	LEA RAX, [RSP - 4 * 8]	; (RSP minus the four pushed 64-bit registers)
	PUSH RAX	; original value of RSP
	PUSH RBP
	PUSH RSI
	PUSH RDI
	PUSH R8
	PUSH R9
	PUSH R10
	PUSH R11
	PUSH R12
	PUSH R13
	PUSH R14
	PUSH R15

	LEA RBP, [RSP + 136]
	MOV RBX, [RSP + 128]	; RBX = int number
	
	IMUL RBX, RBX, MaxNumHandlers
	IMUL RBX, RBX, SizeOfHandlerRec
	; todo: replace LEA by MOV when compiler supports this
	LEA RAX, intHandler
	ADD RAX, RBX		; address of intHandler[int, 0]

	; todo: replace LEA by MOV when compiler supports this
	LEA RDX, stateTag

loop:	; call all handlers for the interrupt
	MOV RCX, RSP
	PUSH RAX	; save ptr for table
	PUSH QWORD [RAX + 12]	; delegate
	PUSH RDX	; TAG(state)
	PUSH RCX	; ADR(state)
	CALL QWORD [RAX + 4]	; call handler
	ADD RSP, 24
	CLI	; handler may have re-enabled interrupts
	POP RAX
	ADD RAX, SizeOfHandlerRec
	MOV RBX, [RAX]
	CMP RBX, 0
	JNE loop

	; fake POPAD (not available in 64-bit mode)
	POP R15
	POP R14
	POP R13
	POP R12
	POP R11
	POP R10
	POP R9
	POP R8
	POP RDI
	POP RSI
	POP RBP
	ADD RSP, 8		;POP RSP
	POP RBX
	POP RDX
	POP RCX
	POP RAX	; now EBP = error code

	POP RBP	; now EBP = INT
	POP RBP	; now EBP = caller RBP

	IRETQ
END FieldInterrupt;

PROCEDURE {NOPAF} FieldIRQ;
CONST SizeOfHandlerRec = SIZEOF(HandlerRec);
CODE {SYSTEM.AMD64}
entry:

	; fake PUSHAD (not available in 64-bit mode)
	PUSH RAX
	PUSH RCX
	PUSH RDX
	PUSH RBX	; (error code)
	LEA RAX, [RSP - 4 * 8]	; (RSP minus the four pushed 64-bit registers)
	PUSH RAX	; original value of RSP
	PUSH RBP
	PUSH RSI
	PUSH RDI
	PUSH R8
	PUSH R9
	PUSH R10
	PUSH R11
	PUSH R12
	PUSH R13
	PUSH R14
	PUSH R15

	LEA RBP, [RSP + 136]

;;	PUSH 32[ESP]	; int number
;;	CALL traceInterruptIn

	MOV RBX, [RSP + 128]	; RBX = int number

	IMUL RBX, RBX, MaxNumHandlers
	IMUL RBX, RBX, SizeOfHandlerRec
	; todo: replace LEA by MOV when compiler supports this
	LEA RAX, intHandler
	ADD RAX, RBX		; address of intHandler[int, 0]

	; todo: replace LEA by MOV when compiler supports this
	LEA RDX, stateTag

loop:	; call all handlers for the interrupt
	MOV RCX, RSP
	PUSH RAX	; save ptr for linked list
	PUSH QWORD [RAX + 12]	; delegate
	PUSH RDX	; TAG(state)
	PUSH RCX	; ADR(state)
	CALL QWORD [RAX + 4]	; call handler
	ADD RSP, 24
	CLI	; handler may have re-enabled interrupts
	POP RAX
	ADD RAX, SizeOfHandlerRec
	MOV RBX, [RAX]
	CMP RBX, 0
	JNE loop

;;	PUSH 32[ESP]	; int number
;;	CALL traceInterruptOut

; ack interrupt
	MOV AL, 20H	; undoc PC ed. 2 p. 1018
	CMP BYTE [RSP + 128], IRQ8
	JB irq0
	OUT IntB0, AL	; 2nd controller
irq0:
	OUT IntA0, AL	; 1st controller

	; fake POPAD (not available in 64-bit mode)
	POP R15
	POP R14
	POP R13
	POP R12
	POP R11
	POP R10
	POP R9
	POP R8
	POP RDI
	POP RSI
	POP RBP
	ADD RSP, 8		;POP RSP
	POP RBX
	POP RDX
	POP RCX
	POP RAX	; now RBP = error code

	POP RBP	; now RBP = INT
	POP RBP	; now RBP = caller RBP

	IRETQ
END FieldIRQ;

(* LoadIDT - Load interrupt descriptor table *)
PROCEDURE LoadIDT(base: ADDRESS; size: SIZE);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	; LIDT needs 10 bytes: 2 for the 16-bit limit and 8 for the 64-bit base address
	; Assumption: size in front of base -> promote size value to upper 48 bits of size
	SHL QWORD [RBP + size], 64-16
	LIDT [RBP + size + (64-16) / 8]
END LoadIDT;

(** Init - Initialize interrupt handling. Called once during initialization. Uses NEW. *)

(*
	The glue code is:
	entry0:	; entry point for interrupts without error code
		PUSH 0	; fake error code
	entry1:	; entry point for interrupts with error code
		XCHG [ESP], EBP	; exchange error code and caller EBP
		PUSH int	; interrupt number
		JMP FieldInterrupt:entry
*)

PROCEDURE InitInterrupts*;
VAR a: ADDRESS; o, i: LONGINT; p: PROCEDURE; mask: SET;
BEGIN
	stateTag := SYSTEM.TYPECODE(State);
	(* initialise 8259 interrupt controller chips *)
	Portout8 (IntA0, 11X); Portout8 (IntA1, CHR(IRQ0));
	Portout8 (IntA1, 4X); Portout8 (IntA1, 1X); Portout8 (IntA1, 0FFX);
	Portout8 (IntB0, 11X); Portout8 (IntB1, CHR(IRQ8));
	Portout8 (IntB1, 2X); Portout8 (IntB1, 1X); Portout8 (IntB1, 0FFX);
	(* enable interrupts from second interrupt controller, chained to line 2 of controller 1 *)
	Portin8(IntA1, SYSTEM.VAL (CHAR, mask));
	EXCL(mask, IRQ2-IRQ0);
	Portout8 (IntA1, SYSTEM.VAL (CHAR, mask));

(*
	NEW(default); default.next := NIL; default.handler := Unexpected;
*)
(*
	newrec (SYSTEM.VAL (ANY, default), SYSTEM.TYPECODE (HandlerList));
*)
(*	default.next := NIL; default.handler := Unexpected; *)
	default.valid := TRUE; default.handler := Unexpected;

	FOR i := 0 TO IDTSize-1 DO	(* set up glue code *)
		intHandler[i, 0] := default; o := 0;
		(* PUSH error code, int num & regs *)
		glue[i][o] := 6AX; INC (o); glue[i][o] := 0X; INC (o);	(* PUSH 0	; {o = 2} *)
		glue[i][o] := 48X; INC(o); glue[i][o] := 87X; INC(o); glue[i][o] := 2CX; INC(o); glue[i][o] := 24X; INC(o);	(* XCHG [RSP], RBP *)
		glue[i][o] := 6AX; INC (o); glue[i][o] := CHR(i); INC (o);	(* PUSH i *)
		IF (i >= IRQ0) & (i <= IRQ15) THEN p := FieldIRQ ELSE p := FieldInterrupt END;

		a := SYSTEM.VAL(ADDRESS, p) - (ADDRESSOF(glue[i][o])+5);

		(* a must be a 32-bit offset to be used with the followingjump instruction, ensured since
		    both the glue code array and the interrupt functions are inside this module *)

		glue[i][o] := 0E9X; INC (o);	(* JMP FieldInterrupt.entry *)
		SYSTEM.PUT32 (ADDRESSOF(glue[i][o]), a);

		(* set up IDT entry *)
		IF (i > 31) OR ~(i IN {8, 10..14, 17}) THEN a := ADDRESSOF(glue[i][0])	(* include PUSH 0 *)
		ELSE a := ADDRESSOF(glue[i][2])	(* skip PUSH 0, processor supplies error code *)
		END;
		idt[i].offsetBits0to15 := SHORT (SHORT(a MOD 10000H));
		(* IRQ0 must be at level 0 because time slicing in Objects needs to set interrupted process' ESP *)
		(* all irq's are handled at level 0, because of priority experiment in Objects.FieldIRQ *)
		IF TRUE (* (i < IRQ0) OR (i > IRQ15) OR (i = IRQ0) OR (i = IRQ0 + 1)*) THEN
			idt[i].selector := Kernel64CodeSel;	(* gdt[1] -> non-conformant segment => level 0 *)
			idt[i].gateType := SYSTEM.VAL(INTEGER, 0EE00H)	(* present, DPL 3, system, 64-bit interrupt gate *)
		ELSE	(* {IRQ0..IRQ15} - {IRQ0 + 1} *)
			idt[i].selector := User64CodeSel;	(* gdt[3] -> conformant segment => level 0 or 3 *)
			idt[i].gateType := SYSTEM.VAL(INTEGER, 08E00H)	(* present, DPL 0, system, 64-bit interrupt gate *)
		END;
		idt[i].offsetBits16to31 := SHORT (SHORT(a DIV 10000H));
		idt[i].offsetBits32to63 := SHORT(a DIV 100000000H);
		idt[i].reserved := 0;
	END
END InitInterrupts;

(** Start - Start handling interrupts. Every processor calls this once during initialization. *)
PROCEDURE Start*;
BEGIN
	ASSERT(default.valid);	(* initialized *)
	LoadIDT(ADDRESSOF(idt[0]), SIZEOF(IDT)-1);
	Sti
END Start;

(* Return current instruction pointer *)
PROCEDURE CurrentPC* (): ADDRESS;
CODE {SYSTEM.AMD64}
	MOV RAX, [RBP + 8]
END CurrentPC;

(* Return current frame pointer *)
PROCEDURE -CurrentBP* (): ADDRESS;
CODE {SYSTEM.AMD64}
	MOV RAX, RBP
END CurrentBP;

(* Set current frame pointer *)
PROCEDURE -SetBP* (bp: ADDRESS);
CODE {SYSTEM.AMD64}
	POP RBP
END SetBP;

(* Return current stack pointer *)
PROCEDURE -CurrentSP* (): ADDRESS;
CODE {SYSTEM.AMD64}
	MOV RAX, RSP
END CurrentSP;

(* Set current stack pointer *)
PROCEDURE -SetSP* (sp: ADDRESS);
CODE {SYSTEM.AMD64}
	POP RSP
END SetSP;

PROCEDURE -GetRAX*(): HUGEINT;
CODE{SYSTEM.AMD64}
END GetRAX;

PROCEDURE -GetRCX*(): HUGEINT;
CODE{SYSTEM.AMD64}
	MOV RAX,RCX
END GetRCX;

PROCEDURE -GetRSI*(): HUGEINT;
CODE{SYSTEM.AMD64}
	MOV RAX,RSI
END GetRSI;

PROCEDURE -GetRDI*(): HUGEINT;
CODE{SYSTEM.AMD64}
	MOV RAX,RDI
END GetRDI;


PROCEDURE -SetRAX*(n: HUGEINT);
CODE{SYSTEM.AMD64}	
	NOP
	POP RAX
END SetRAX;

PROCEDURE -SetRBX*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	NOP
	POP RBX
END SetRBX;

PROCEDURE -SetRCX*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	POP RCX
END SetRCX;

PROCEDURE -SetRDX*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	POP RDX
END SetRDX;

PROCEDURE -SetRSI*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	POP RSI
END SetRSI;

PROCEDURE -SetRDI*(n: HUGEINT);
CODE{SYSTEM.AMD64}
	POP RDI
END SetRDI;

PROCEDURE  Portin8*(port: LONGINT; VAR val: CHAR);
CODE{SYSTEM.AMD64}
	MOV EDX,[RBP+port]
	IN AL, DX
	MOV RCX, [RBP+val]
	MOV [RCX], AL
END Portin8;

PROCEDURE  Portin16*(port: LONGINT; VAR val: INTEGER);
CODE{SYSTEM.AMD64}
	MOV EDX,[RBP+port]
	IN AX, DX
	MOV RCX, [RBP+val]
	MOV [RCX], AX
END Portin16;

PROCEDURE  Portin32*(port: LONGINT; VAR val: LONGINT);
CODE{SYSTEM.AMD64}
	MOV EDX,[RBP+port]
	IN EAX, DX
	MOV RCX, [RBP+val]
	MOV [RCX], EAX
END Portin32;

PROCEDURE  Portout8*(port: LONGINT; val: CHAR);
CODE{SYSTEM.AMD64}
	MOV AL,[RBP+val]
	MOV EDX,[RBP+port]
	OUT DX,AL
END Portout8;

PROCEDURE  Portout16*(port: LONGINT; val: INTEGER);
CODE{SYSTEM.AMD64}
	MOV AX,[RBP+val]
	MOV EDX,[RBP+port]
	OUT DX,AX
END Portout16;

PROCEDURE  Portout32*(port: LONGINT; val: LONGINT);
CODE{SYSTEM.AMD64}
	MOV EAX,[RBP+val]
	MOV EDX,[RBP+port]
	OUT DX,EAX
END Portout32;

PROCEDURE -Cli*;
CODE{SYSTEM.AMD64}
	CLI
END Cli;

PROCEDURE -Sti*;
CODE{SYSTEM.AMD64}
	STI
END Sti;

(* Save minimal FPU state (for synchronous process switches). *)
(* saving FPU state takes 108 bytes memory space, no alignment required *)
PROCEDURE -FPUSaveMin* (VAR state: SSEState);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	POP RAX
	FNSTCW [RAX]	; control word is at state[0]
	FWAIT
END FPUSaveMin;

(* Restore minimal FPU state. *)
PROCEDURE -FPURestoreMin* (VAR state: SSEState);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	POP RAX
	FLDCW [RAX]	; control word is at state[0]
END FPURestoreMin;

(* Save full FPU state (for asynchronous process switches). *)
PROCEDURE -FPUSaveFull* (VAR state: SSEState);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	POP RAX
	FSAVE [RAX]
END FPUSaveFull;

(* Restore full FPU state. *)
PROCEDURE -FPURestoreFull* (VAR state: SSEState);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	POP RAX
	FRSTOR [RAX]
END FPURestoreFull;

(* stateAdr must be the address of a 16-byte aligned memory area of at least 512 bytes *)
PROCEDURE -SSESaveFull* (stateAdr: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	POP RAX
	FXSAVE [RAX]
	FWAIT
	FNINIT
END SSESaveFull;

PROCEDURE -SSERestoreFull* (stateAdr: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	POP RAX
	FXRSTOR [RAX]
END SSERestoreFull;

PROCEDURE -SSESaveMin* (stateAdr: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	POP RAX
	FNSTCW [RAX]
	FWAIT
	STMXCSR [RAX + 24]
END SSESaveMin;

PROCEDURE -SSERestoreMin* (stateAdr: ADDRESS);
CODE {SYSTEM.AMD64, SYSTEM.FPU}
	POP RAX
	FLDCW [RAX]
	LDMXCSR [RAX + 24]
END SSERestoreMin;

(* Helper functions for SwitchTo. *)
PROCEDURE -PushState* (CONST state: State);
CODE {SYSTEM.AMD64}
	POP RAX	; ADR (state)
	POP RBX	; TYPECODE (state), ignored
	PUSH QWORD [RAX + 176]	; SS
	PUSH QWORD [RAX + 168]	; SP
	PUSH QWORD [RAX + 160]	; FLAGS
	PUSH QWORD [RAX + 152]	; CS
	PUSH QWORD [RAX + 144]	; PC
	PUSH QWORD [RAX + 120]	; RAX
	PUSH QWORD [RAX + 112]	; RCX
	PUSH QWORD [RAX + 104]	; RDX
	PUSH QWORD [RAX + 96]	; RBX
	PUSH DWORD 0; ignored
	PUSH QWORD [RAX + 136]	; RBP
	PUSH QWORD [RAX + 72]	; RSI
	PUSH QWORD [RAX + 64]	; RDI
	PUSH QWORD [RAX + 56]	; R8
	PUSH QWORD [RAX + 48]	; R9
	PUSH QWORD [RAX + 40]	; R10
	PUSH QWORD [RAX + 32]	; R11
	PUSH QWORD [RAX + 24]	; R12
	PUSH QWORD [RAX + 16]	; R13
	PUSH QWORD [RAX + 8]	; R14
	PUSH QWORD [RAX + 0]	; R15
END PushState;

PROCEDURE -JumpState*;
CODE {SYSTEM.AMD64}
	POP R15
	POP R14
	POP R13
	POP R12
	POP R11
	POP R10
	POP R9
	POP R8
	POP RDI
	POP RSI
	POP RBP
	POP RBX; ignored
	POP RBX
	POP RDX
	POP RCX
	POP RAX
	IRETQ
END JumpState;

PROCEDURE -CallLocalIPC*;
CODE {SYSTEM.AMD64}
	INT MPIPCLocal
END CallLocalIPC;

PROCEDURE -HLT*;
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	STI	; (* required according to ACPI 2.0 spec section 8.2.2 *)
	HLT
END HLT;

(* Kernel mode upcall to perform global processor halt. *)
PROCEDURE KernelCallHLT*;
CODE {SYSTEM.AMD64}
	MOV EAX, 2
	INT MPKC
END KernelCallHLT;

(* Parse processor entry in MP config table. *)
PROCEDURE CPUID1*(): LONGINT;
CODE {SYSTEM.AMD64}
	MOV EAX, 1
	CPUID
	MOV EAX, EBX
END CPUID1;

(** -- Atomic operations -- *)

(** Atomic INC(x). *)
PROCEDURE -AtomicInc*(VAR x: LONGINT);
CODE {SYSTEM.AMD64}
	POP RAX
	LOCK
	INC DWORD [RAX]
END AtomicInc;

(** Atomic DEC(x). *)
PROCEDURE -AtomicDec*(VAR x: LONGINT);
CODE {SYSTEM.AMD64}
	POP RAX
	LOCK
	DEC DWORD [RAX]
END AtomicDec;

(** Atomic EXCL. *)
PROCEDURE AtomicExcl* (VAR s: SET; bit: LONGINT);
CODE {SYSTEM.AMD64}
	MOV EAX, [RBP + bit]
	MOV RBX, [RBP + s]
	LOCK
	BTR [RBX], EAX
END AtomicExcl;

(** Atomic INC(x, y). *)
PROCEDURE -AtomicAdd*(VAR x: LONGINT; y: LONGINT);
CODE {SYSTEM.AMD64}
	POP EBX
	POP RAX
	LOCK
	ADD DWORD [RAX], EBX
END AtomicAdd;

(** Atomic test-and-set. Set x = TRUE and return old value of x. *)
PROCEDURE -AtomicTestSet*(VAR x: BOOLEAN): BOOLEAN;
CODE {SYSTEM.AMD64}
	POP RBX
	MOV AL, 1
	XCHG [RBX], AL
END AtomicTestSet;

(* Atomic compare-and-swap. Set x = new if x = old and return old value of x *)
PROCEDURE -AtomicCAS* (VAR x: LONGINT; old, new: LONGINT): LONGINT;
CODE {SYSTEM.AMD64}
	POP EBX		; new
	POP EAX		; old
	POP RCX		; address of x
	LOCK CMPXCHG [RCX], EBX	; atomicly compare x with old and set it to new if equal
END AtomicCAS;

PROCEDURE CopyState* (CONST from: State; VAR to: State);
BEGIN
	to.R15 := from.R15;
	to.R14 := from.R14;
	to.R13 := from.R13;
	to.R12 := from.R12;
	to.R11 := from.R11;
	to.R10 := from.R10;
	to.R9 := from.R9;
	to.R8 := from.R8;
	to.RDI := from.RDI;
	to.RSI := from.RSI;
	to.RBX := from.RBX;
	to.RDX := from.RDX;
	to.RCX := from.RCX;
	to.RAX := from.RAX;
	to.BP := from.BP;
	to.PC := from.PC;
	to.CS := from.CS;
	to.SP := from.SP;
	to.SS := from.SS;

	to.FLAGS := from.FLAGS;
END CopyState;


(* function returning the number of processors that are available to Aos *)
PROCEDURE NumberOfProcessors*( ): LONGINT;
BEGIN
	RETURN numberOfProcessors
END NumberOfProcessors;

(*! non portable code, for native Aos only *)
PROCEDURE SetNumberOfProcessors*(num: LONGINT);
BEGIN
	numberOfProcessors := num;
END SetNumberOfProcessors;

(* function for changing byte order *)
PROCEDURE ChangeByteOrder* (n: LONGINT): LONGINT;
CODE {SYSTEM.AMD64}
	MOV EAX, [RBP + n]				; load n in eax
	BSWAP EAX						; swap byte order
END ChangeByteOrder;

(* Write a value to the APIC. *)
PROCEDURE  ApicPut(ofs: SIZE; val: SET);
BEGIN
	IF TraceApic THEN
		Acquire(TraceOutput);
		Trace.Hex(ofs, SIZEOF(SIZE)*2); Trace.String(" := "); Trace.Hex(SYSTEM.VAL (LONGINT, val), 9); Trace.Ln;
		Release(TraceOutput);
	END;
	SYSTEM.PUT(localAPIC+ofs, SYSTEM.VAL (LONGINT, val))
END ApicPut;

(* Read a value from the APIC. *)
PROCEDURE ApicGet(ofs: SIZE): SET;
VAR val: SET;
BEGIN
	SYSTEM.GET(localAPIC+ofs, SYSTEM.VAL (LONGINT, val));
	IF TraceApic THEN
		Acquire(TraceOutput);
		Trace.String(" ("); Trace.Hex(ofs, SIZEOF(SIZE)*2); Trace.String(" = ");
		Trace.Hex(SYSTEM.VAL(LONGINT, val), 9); Trace.StringLn (")");
		Release(TraceOutput);
	END;
	RETURN val
END ApicGet;

(* Handle interprocessor interrupt. During upcall interrupts are off and processor is at kernel level. *)
PROCEDURE HandleIPC(VAR state: State);
VAR id: LONGINT;
BEGIN
	id := ID();
	IF ~TraceProcessor OR (id IN allProcessors) THEN
		IF FrontBarrier IN ipcFlags THEN
			AtomicExcl(ipcFrontBarrier, id);
			WHILE ipcFrontBarrier # {} DO SpinHint END	(* wait for all *)
		END;
		ipcHandler(id, state, ipcMessage);	(* interrupts off and at kernel level *)
		IF BackBarrier IN ipcFlags THEN
			AtomicExcl(ipcBackBarrier, id);
			WHILE ipcBackBarrier # {} DO SpinHint END	(* wait for all *)
		END;
		AtomicExcl(ipcBusy, id)	(* ack - after this point we do not access shared variables for this broadcast *)
	END;
	IF state.INT = MPIPC THEN
		ApicPut(0B0H, {})	(* EOI (not needed for NMI or local call, see 7.4.10.6) *)
	END
END HandleIPC;

(* Handle MP error interrupt. *)
PROCEDURE HandleError(VAR state: State);
VAR esr: SET; (* int: LONGINT; *)
BEGIN
	(* int := state.INT; *) esr := ApicGet(280H);
	ApicPut(0B0H, {});	(* EOI *)
	HALT(2302)	(* SMP error *)
END HandleError;

(* Interprocessor broadcasting. Lock level SMP. *)
PROCEDURE LocalBroadcast(h: BroadcastHandler; msg: Message; flags: SET);
BEGIN
	IF Self IN flags THEN ipcBusy := allProcessors
	ELSE ipcBusy := allProcessors - {ID()}
	END;
	ipcFrontBarrier := ipcBusy; ipcBackBarrier := ipcBusy;
	ipcHandler := h; ipcMessage := msg; ipcFlags := flags;
	IF numProcessors > 1 THEN	(* ICR: Fixed, Physical, Edge, All Excl. Self, INT IPC *)
		ApicPut(300H, {18..19} + SYSTEM.VAL (SET, MPIPC));
		(*REPEAT UNTIL ~(12 IN ApicGet(300H))*)	(* wait for send to finish *)
	END;
	IF Self IN flags THEN CallLocalIPC END;	(* "send" to self also *)
	WHILE ipcBusy # {} DO SpinHint END;	(* wait for all to ack before we release locks *)
	ipcHandler := NIL; ipcMessage := NIL	(* no race, because we have IPC lock *)
END LocalBroadcast;

(** Broadcast an operation to all processors. *)
PROCEDURE Broadcast* (h: BroadcastHandler; msg: Message; flags: SET);
BEGIN
	Acquire(Processors);
	LocalBroadcast(h, msg, flags);
	Release(Processors)
END Broadcast;

(* Start all halted processors. *)	(* Lock level Processors. *)
PROCEDURE StartAll*;
BEGIN
	Acquire(Processors);	(* wait for any pending Stops to finish, and disallow further Stops *)
	ASSERT(stopped & (ipcBusy = {}));
	ipcBusy := allProcessors - {ID()};
	stopped := FALSE;
	WHILE ipcBusy # {} DO SpinHint END;	(* wait for all to ack *)
	Release(Processors)
END StartAll;

PROCEDURE HandleFlushTLB(id: LONGINT; CONST state: State; msg: Message);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	MOV EAX, CR3
	MOV CR3, EAX
END HandleFlushTLB;

(** Flush the TLBs on all processors (multiprocessor-safe). *)
PROCEDURE GlobalFlushTLB;
BEGIN
	Acquire(Processors);
	LocalBroadcast(HandleFlushTLB, NIL, {Self, FrontBarrier, BackBarrier});
	Release(Processors)
END GlobalFlushTLB;

PROCEDURE HandleFlushCache(id: LONGINT; CONST state: State; msg: Message);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	WBINVD	; write back and invalidate internal cache and initiate write back and invalidation of external caches
END HandleFlushCache;

(** Flush the caches on all processors (multiprocessor-safe). *)
PROCEDURE GlobalFlushCache;
BEGIN
	Acquire(Processors);
	LocalBroadcast(HandleFlushCache, NIL, {Self, FrontBarrier, BackBarrier});
	Release(Processors)
END GlobalFlushCache;

(* Activate the garbage collector in single-processor mode. Lock level ALL. *)
PROCEDURE HandleKernelCall(VAR state: State);
BEGIN	(* level 0 *)
	IF IFBit IN state.FLAGS THEN
		Sti	(* re-enable interrupts *)
	END;
	CASE state.RAX OF	(* see KernelCall* *)
		|2:	(* HLT *)
			IF IFBit IN state.FLAGS THEN
				HLT
			END
	END
END HandleKernelCall;

(*
(** Activate the garbage collector immediately (multiprocessor-safe). *)
PROCEDURE GlobalGC*;
BEGIN
	Acquire(Processors);
	gcBarrier := allProcessors;
	LocalBroadcast(HandleGC, NIL, {Self, BackBarrier});
	Release(Processors);
END GlobalGC;
*)

PROCEDURE HandleGetTimestamp(id: LONGINT; CONST state: State; msg: Message);
BEGIN
	time[id] := GetTimer()
END HandleGetTimestamp;

(** Get timestamp on all processors (for testing). *)
PROCEDURE GlobalGetTimestamp;
VAR t: TimeArray; i: LONGINT; mean, var, n: HUGEINT;
BEGIN
	Acquire(Processors);
	LocalBroadcast(HandleGetTimestamp, NIL, {Self, FrontBarrier});
	LocalBroadcast(HandleGetTimestamp, NIL, {Self, FrontBarrier});
	t := time;
	Release(Processors);
	Acquire (TraceOutput);
	FOR i := 0 TO numProcessors-1 DO Trace.HIntHex(t[i], 17) END;
	IF numProcessors > 1 THEN
		mean := 0;
		n := numProcessors;
		FOR i := 0 TO numProcessors-1 DO
			INC (mean, t[i])
		END;
		mean := mean DIV n;
		var := 0;
		FOR i := 0 TO numProcessors-1 DO
			n := t[i] - mean;
			INC (var, n * n)
		END;
		var := var DIV (numProcessors - 1);
		Trace.String(" mean="); Trace.HIntHex(mean, 16);
		Trace.String(" var="); Trace.HIntHex(var, 16);
		Trace.String(" var="); Trace.Int(SHORT (var), 1);
		Trace.String(" diff:");
		FOR i := 0 TO numProcessors-1 DO
			Trace.Int(SHORT (t[i] - mean), 1); Trace.Char(" ")
		END
	END;
	Release (TraceOutput);
END GlobalGetTimestamp;

PROCEDURE ParseProcessor(adr: ADDRESS);
VAR id, idx, signature, family, feat, ver, log: LONGINT; flags: SET; string : ARRAY 8 OF CHAR;
BEGIN
	SYSTEM.GET(adr, SYSTEM.VAL (LONGINT, flags));
	id := ASH(SYSTEM.VAL (LONGINT, flags * {8..15}), -8);
	ver := ASH(SYSTEM.VAL (LONGINT, flags * {16..23}), -16);
	SYSTEM.GET (adr+4, signature);
	family := ASH(signature, -8) MOD 10H;
	SYSTEM.GET (adr+8, feat);
	idx := -1;
	IF (family # 0) & (signature MOD 1000H # 0FFFH) & (24 IN flags) & (id < LEN(idMap)) & (idMap[id] = -1) THEN
		IF 25 IN flags THEN idx := 0	(* boot processor *)
		ELSIF numProcessors < maxProcessors THEN idx := numProcessors; INC(numProcessors)
		ELSE	(* skip *)
		END
	END;
	IF idx # -1 THEN apicVer[idx] := ver; idMap[id] := SHORT(SHORT(idx)) END;
	Trace.String("   Processor "); Trace.Int(id, 1);
	Trace.String(", APIC"); Trace.Hex(ver, -3);
	Trace.String(", ver "); Trace.Int(family, 1);
	Trace.Char("."); Trace.Int(ASH(signature, -4) MOD 10H, 1);
	Trace.Char("."); Trace.Int(signature MOD 10H, 1);
	Trace.String(", features "); Trace.Hex(feat, 9);
	Trace.String(", ID "); Trace.Int(idx, 1);
	IF (threadsPerCore > 1) THEN Trace.String(" ("); Trace.Int(threadsPerCore, 0); Trace.String(" threads)"); END;
	Trace.Ln;
	IF (threadsPerCore > 1)  THEN
		GetConfig("DisableHyperthreading", string);
		IF (string = "1") THEN
			Trace.String("Machine: Hyperthreading disabled."); Trace.Ln;
			RETURN;
		END;
		log := (LSH(CPUID1(), -16) MOD 256);
		WHILE log > 1 DO
			INC(id); DEC(log);
			IF numProcessors < maxProcessors THEN
				idx := numProcessors; INC(numProcessors);
				apicVer[idx] := ver; idMap[id] := SHORT(SHORT(idx))
			END
		END
	END
END ParseProcessor;

(* Parse MP configuration table. *)
PROCEDURE ParseMPConfig;
VAR adr, x: ADDRESS; i: LONGINT; entries: INTEGER; ch: CHAR; s: SET; str: ARRAY 8 OF CHAR;
BEGIN
	localAPIC := 0; numProcessors := 1; allProcessors := {0};
	FOR i := 0 TO LEN(idMap)-1 DO idMap[i] := -1 END;	(* all unassigned *)
	FOR i := 0 TO MaxCPU-1 DO started[i] := FALSE END;
	adr := configMP;
	GetConfig("MaxProcs", str);
	i := 0; maxProcessors := StrToInt(i, str);
	IF maxProcessors = 0 THEN maxProcessors := MaxCPU END;
	IF (maxProcessors > 0) & (adr # NilAdr) THEN	(* MP config table present, possible multi-processor *)
		Trace.String("Machine: Intel MP Spec "); Trace.Int(ORD(revMP) DIV 10H + 1, 1);
		Trace.Char("."); Trace.Int(ORD(revMP) MOD 10H, 1); Trace.Ln;
		IF TraceVerbose THEN
			IF ODD(ASH(ORD(featureMP[1]), -7)) THEN
				Trace.StringLn (" PIC mode");
				(* to do: enable SymIO *)
			ELSE
				Trace.StringLn (" Virtual wire mode");
			END
		END;
		IF featureMP[0] # 0X THEN	(* pre-defined configuration *)
			Trace.String("   Default config "); Trace.Int(ORD(featureMP[0]), 1); Trace.Ln;
			localAPIC := SHORT(0FEE00000H);
			apicVer[0] := 0; apicVer[1] := 0
		ELSE	(* configuration defined in table *)
			MapPhysical(adr, 68*1024, adr);	(* 64K + 4K header *)
			SYSTEM.GET (adr, i); ASSERT(i = 504D4350H);	(* check signature *)
			SYSTEM.GET (adr+4, i);	(* length *)
			ASSERT(ChecksumMP(adr, i MOD 10000H) = 0);
			IF TraceVerbose THEN
				Trace.String(" ID: ");
				FOR x := adr+8 TO adr+27 DO
					SYSTEM.GET (x, ch); Trace.Char(ch);
					IF x = adr+15 THEN Trace.Char(" ") END
				END;
				Trace.Ln
			END;
			localAPIC := 0; SYSTEM.GET(adr+36, SYSTEM.VAL (LONGINT, localAPIC));
			IF TraceVerbose THEN Trace.String("  Local APIC:"); Trace.Address (localAPIC); Trace.Ln END;
			SYSTEM.GET (adr+34, entries);
			INC(adr, 44);	(* skip header *)
			WHILE entries > 0 DO
				SYSTEM.GET (adr, ch);	(* type *)
				CASE ORD(ch) OF
					0:	(* processor *)
						ParseProcessor(adr);
						INC(adr, 20)
					|1:	(* bus *)
						IF TraceVerbose THEN
							SYSTEM.GET (adr+1, ch);
							Trace.String(" Bus "); Trace.Int(ORD(ch), 1); Trace.String(": ");
							FOR x := adr+2 TO adr+7 DO SYSTEM.GET (x, ch); Trace.Char(ch) END;
							Trace.Ln
						END;
						INC(adr, 8)
					|2:	(* IO APIC *)
						IF TraceVerbose THEN
							SYSTEM.GET (adr+1, ch); Trace.String(" IO APIC ID:"); Trace.Hex(ORD(ch), -3);
							SYSTEM.GET (adr+2, ch); Trace.String(", version "); Trace.Int(ORD(ch), 1);
							SYSTEM.GET(adr, SYSTEM.VAL (LONGINT, s)); IF ~(24 IN s) THEN Trace.String(" (disabled)") END;
							Trace.Ln
						END;
						INC(adr, 8)
					|3:	(* IO interrupt assignment *)
						INC(adr, 8)
					|4:	(* Local interrupt assignment *)
						INC(adr, 8)
				END;	(* CASE *)
				DEC(entries)
			END
		END
	END;
	IF localAPIC = 0 THEN	(* single processor *)
		Trace.StringLn ("Machine: Single-processor");
		apicVer[0] := 0
	END;
	started[0] := TRUE;
	FOR i := 0 TO MaxCPU-1 DO revIDmap[i] := -1 END;
	FOR i := 0 TO LEN(idMap)-1 DO
		x := idMap[i];
		IF x # -1 THEN
			ASSERT(revIDmap[x] = -1);	(* no duplicate APIC ids *)
			revIDmap[x] := SHORT(SHORT(i))
		END
	END;
	(* timer configuration *)
	GetConfig("TimerRate", str);
	i := 0; timerRate := StrToInt(i, str);
	IF timerRate = 0 THEN timerRate := 1000 END;
	IF TraceProcessor THEN
		GetConfig("TraceProc", str);
		i := 0; traceProcessor := StrToInt(i, str) # 0
	END
END ParseMPConfig;

(* Return the current average measured bus clock speed in Hz. *)
PROCEDURE GetBusClockRate(): LONGINT;
VAR timer: LONGINT; t: LONGINT;
BEGIN
	t := ticks;
	REPEAT UNTIL ticks # t;	(* wait for edge *)
	timer := ticks + ClockRateDelay;
	ApicPut(380H, SYSTEM.VAL (SET, MAX(LONGINT)));	(* initial count *)
	REPEAT UNTIL timer - ticks <= 0;
	t := MAX(LONGINT) - SYSTEM.VAL (LONGINT, ApicGet(390H));	(* current count *)
	IF t <= MAX(LONGINT) DIV 1000 THEN
		RETURN 1000 * t DIV ClockRateDelay
	ELSE
		RETURN t DIV ClockRateDelay * 1000
	END
END GetBusClockRate;

(* Initialize APIC timer for timeslicing. *)
PROCEDURE InitMPTimer;
VAR rate: LONGINT;
BEGIN
	IF timerRate > 0 THEN
		ApicPut(3E0H, {0,1,3});	(* divide by 1 *)
		ApicPut(320H, {16} + SYSTEM.VAL (SET, MPTMR));	(* masked, one-shot *)
		rate := GetBusClockRate();
		busHz0[ID()] := rate;
		rate := (rate+500000) DIV 1000000 * 1000000;	(* round to nearest MHz *)
		busHz1[ID()] := rate;
		ApicPut(320H, {17} + SYSTEM.VAL (SET, MPTMR));	(* unmasked, periodic *)
		ApicPut(380H, SYSTEM.VAL (SET, rate DIV timerRate))	(* initial count *)
	END
END InitMPTimer;

(* Handle multiprocessor timer interrupt. *)
PROCEDURE HandleMPTimer(VAR state: State);
BEGIN	(* {interrupts off} *)
	timer(ID(), state);
	ApicPut(0B0H, {});	(* EOI *)
	Sti;	(* enable interrupts before acquiring locks below - to avoid deadlock with StopAll. *)
	Timeslice(state)	(* fixme: check recursive interrupt *)
END HandleMPTimer;

(* Handle uniprocessor timer interrupt. *)
PROCEDURE HandleUPTimer(VAR state: State);
BEGIN	(* {interrupts off} *)
	timer(0, state);
	Sti;	(* enable interrupts before acquiring locks below - to avoid deadlock with StopAll. *)
	Timeslice(state)
END HandleUPTimer;

PROCEDURE DummyEvent(id: LONGINT; CONST state: State);
END DummyEvent;

(** Install a processor timer event handler. *)
PROCEDURE InstallEventHandler* (h: EventHandler);
BEGIN
	IF h # NIL THEN timer := h ELSE timer := DummyEvent END
END InstallEventHandler;

(* Initialize APIC for current processor. *)
PROCEDURE InitAPIC;
BEGIN
	(* enable APIC, set focus checking & set spurious interrupt handler *)
	ASSERT(MPSPU MOD 16 = 15);	(* low 4 bits set, p. 7-29 *)
	ApicPut(0F0H, {8} + SYSTEM.VAL (SET, MPSPU));
	(* set error interrupt handler *)
	ApicPut(370H, SYSTEM.VAL (SET, MPERR));
	InitMPTimer
END InitAPIC;

(* Start processor activity. *)
PROCEDURE StartMP;
VAR id: LONGINT; state: State;
BEGIN	(* running at kernel level with interrupts on *)
	InitAPIC;
	id := ID();	(* timeslicing is disabled, as we are running at kernel level *)
	Acquire (TraceOutput);
	Trace.String ("   P"); Trace.Int(id, 1); Trace.StringLn (" running");
	Release (TraceOutput);
	IF TraceProcessor & traceProcessor & (id = numProcessors-1) THEN
		DEC(numProcessors)	(* exclude from rest of activity *)
	ELSE
		INCL(allProcessors, id)
	END;
	(* synchronize with boot processor - end of mutual exclusion *)
	started[id] := TRUE;
	IF TraceProcessor & ~(id IN allProcessors) THEN
		Acquire (TraceOutput);
		Trace.String ("   P"); Trace.Int(id, 1); Trace.StringLn (" tracing");
		Release (TraceOutput);
		LOOP
			IF traceProcessorProc # NIL THEN traceProcessorProc(id, state) END;
			SpinHint
		END
	END;
	(* wait until woken up *)
	WHILE stopped DO SpinHint END;
	(* now fully functional, including storage allocation *)
	AtomicExcl(ipcBusy, id);	(* ack *)
	Acquire (TraceOutput);
	Trace.String ("   P"); Trace.Int(id, 1); Trace.StringLn(" scheduling");
	Release (TraceOutput);
	ASSERT(id = ID());	(* still running on same processor *)
	start;
END StartMP;

(* Subsequent processors start executing here. *)
PROCEDURE EnterMP;
(* no local variables allowed, because stack is switched. *)
BEGIN	(* running at kernel level with interrupts off *)
	InitProcessor;
	InitMemory;	(* switch stack *)
	Start;
	StartMP
END EnterMP;

(* Start another processor. *)
PROCEDURE StartProcessor(phys: ADDRESS; apicid: LONGINT; startup: BOOLEAN);
VAR j, k: LONGINT; s: SET; timer: LONGINT;
BEGIN
	(* clear APIC errors *)
	ApicPut(280H, {}); s := ApicGet(280H);
	(* assert INIT *)
	ApicPut(310H, SYSTEM.VAL (SET, ASH(apicid, 24)));	(* set destination *)
	ApicPut(300H, {8, 10, 14, 15});	(* set Dest, INIT, Phys, Assert, Level *)
	timer := ticks + 5;		(* > 200us *)
	REPEAT UNTIL timer - ticks <= 0;
	(* deassert INIT *)
	ApicPut(310H, SYSTEM.VAL (SET, ASH(apicid, 24)));	(* set destination *)
	ApicPut(300H, {8, 10, 15});	(* set Dest, INIT, Deassert, Phys, Level *)
	IF startup THEN	(* send STARTUP if required *)
		j := 0; k := 2;
		WHILE j # k DO
			ApicPut(280H, {});
			ApicPut(310H, SYSTEM.VAL (SET, ASH(apicid, 24)));	(* set destination *)
			(* set Dest, Startup, Deassert, Phys, Edge *)
			ApicPut(300H, {9, 10} + SYSTEM.VAL (SET, phys DIV 4096 MOD 256));
			timer := ticks + 10;	(* ~10ms *)
			REPEAT UNTIL timer - ticks <= 0;
			IF ~(12 IN ApicGet(300H)) THEN	(* idle *)
				IF ApicGet(280H) * {0..3, 5..7} = {} THEN k := j	(* ESR success, exit *)
				ELSE INC(j)	(* retry *)
				END
			ELSE INC(j)	(* retry *)
			END
		END
	END
END StartProcessor;

(* Boot other processors, one at a time. *)
PROCEDURE BootMP;
VAR phys, page0Adr: ADDRESS; i: LONGINT; timer: LONGINT;
BEGIN
	stopped := TRUE; ipcBusy := {};	(* other processors can be woken with StartAll *)
	InitBootPage(EnterMP, phys);
	MapPhysical(0, 4096, page0Adr);	(* map in BIOS data area *)
	Acquire(TraceOutput); Trace.String("Machine: Booting processors... "); Trace.Ln; Release(TraceOutput);
	FOR i := 1 TO numProcessors-1 DO
		(* set up booting for old processor types that reset on INIT & don't understand STARTUP *)
		SYSTEM.PUT (page0Adr + 467H, ASH(phys, 16-4));
		PutNVByte(15, 0AX);	(* shutdown status byte *)
		(* attempt to start another processor *)
		Acquire(TraceOutput); Trace.String("   P0 starting P"); Trace.Int(i, 1); Trace.Ln; Release(TraceOutput);
		StartProcessor(phys, revIDmap[i], apicVer[i] >= 10H);	(* try booting processor i *)
		(* wait for CPU to become active *)
		timer := ticks + 5000;	(* ~5s timeout *)
		REPEAT SpinHint UNTIL started[i] OR (timer - ticks <= 0);
		(* end of mutual exclusion *)
		Acquire(TraceOutput);
		IF started[i] THEN
			Trace.String("   P0 recognized P"); Trace.Int(i, 1);
		ELSE
			Trace.String("   P0 timeout on P"); Trace.Int(i, 1);
		END;
		Trace.Ln;
		Release(TraceOutput);
	END;
	SYSTEM.PUT (page0Adr + 467H, SYSTEM.VAL (LONGINT, 0));
	UnmapPhysical(page0Adr, 4096);
	PutNVByte(15, 0X)	(* restore shutdown status *)
END BootMP;

(* Timer interrupt handler. *)
PROCEDURE TimerInterruptHandler(VAR state: State);
BEGIN
	INC(ticks);
	DEC(eventCount);
	IF eventCount = 0 THEN
		eventCount := eventMax; event(state)
	END
END TimerInterruptHandler;

PROCEDURE Dummy(VAR state: State);
END Dummy;

PROCEDURE InitTicks;
CONST Div = (2*TimerClock + Second) DIV (2*Second);	(* timer clock divisor *)
BEGIN
	eventCount := 0; eventMax := 0; event := Dummy;
	(* initialize timer hardware *)
	ASSERT(Div <= 65535);
	Portout8(43H, 34X); Wait;	(* mode 2, rate generator *)
	Portout8(40H, CHR(Div MOD 100H)); Wait;
	Portout8(40H, CHR(ASH(Div, -8)));
	InstallHandler(TimerInterruptHandler, IRQ0)
END InitTicks;

(* Set timer upcall. The handler procedure will be called at a rate of Second/divisor Hz. *)
PROCEDURE InstallTickHandler(handler: Handler; divisor: LONGINT);
BEGIN
	eventMax := divisor; event := handler;
	eventCount := eventMax
END InstallTickHandler;

(* Initialize processors *)
PROCEDURE InitProcessors*;
BEGIN
	traceProcessor := FALSE; traceProcessorProc := NIL;
	ASSERT(Second = 1000);	(* use of Machine.ticks *)
	InitTicks;
	timer := DummyEvent;
	ParseMPConfig;
	InstallHandler(HandleIPC, MPIPCLocal);
	IF localAPIC # 0 THEN	(* APIC present *)
		InitAPICArea(localAPIC, 4096);
		InitAPICIDAdr(localAPIC+20H, idMap);
		ASSERT(MPSPU MOD 16 = 15);	(* use default handler (see 7.4.11.1) *)
		InstallHandler(HandleError, MPERR);
		InstallHandler(HandleMPTimer, MPTMR);
		InstallHandler(HandleIPC, MPIPC);
		InitAPIC;
		IF numProcessors > 1 THEN BootMP END
	ELSE
		IF timerRate > 0 THEN
			InstallTickHandler(HandleUPTimer, Second DIV timerRate)
		END
	END;
	InstallHandler(HandleKernelCall, MPKC);
END InitProcessors;

(* Send and print character *)
PROCEDURE TraceChar (c: CHAR);
VAR status: SHORTINT;

	(* Scroll the screen by one line. *)
	PROCEDURE Scroll;
	VAR adr: ADDRESS; off: SIZE;
	BEGIN
		adr := traceBase + TraceLen;
		SYSTEM.MOVE (adr, adr - TraceLen, TraceSize - TraceLen);
		adr := traceBase + TraceSize - TraceLen;
		FOR off := 0 TO TraceLen - SIZEOF(INTEGER) BY SIZEOF(INTEGER) DO SYSTEM.PUT16 (adr + off, 100H * 7H + 32) END
	END Scroll;

BEGIN
	IF TraceV24 IN traceMode THEN
		REPEAT	(* wait until port is ready to accept a character *)
		Portin8 (tracePort + 5, SYSTEM.VAL(CHAR,status))
		UNTIL ODD (status DIV 20H);	(* THR empty *)
		Portout8 (tracePort, c);
	END;
	IF TraceScreen IN traceMode THEN
		IF c = 9X THEN c := 20X END;
		IF c = 0DX THEN	(* CR *)
			DEC (tracePos, tracePos MOD TraceLen)
		ELSIF c = 0AX THEN	(* LF *)
			IF tracePos < TraceSize THEN
				INC (tracePos, TraceLen)	(* down to next line *)
			ELSE
				Scroll
			END
		ELSE
			IF tracePos >= TraceSize THEN
				Scroll;
				DEC (tracePos, TraceLen)
			END;
			SYSTEM.PUT16 (traceBase + tracePos, 100H * traceColor + ORD (c));
			INC (tracePos, SIZEOF(INTEGER))
		END
	END
END TraceChar;

(* Change color *)
PROCEDURE TraceColor (c: SHORTINT);
BEGIN traceColor := c;
END TraceColor;

(* Initialise tracing. *)
PROCEDURE InitTrace;
CONST MaxPorts = 8;
VAR i, p, bps: LONGINT; off: SIZE; s, name: ARRAY 32 OF CHAR;
	baselist: ARRAY MaxPorts OF LONGINT;
BEGIN
	GetConfig ("TraceMode", s);
	p := 0; traceMode := SYSTEM.VAL (SET, StrToInt (p, s));
	IF TraceScreen IN traceMode THEN
		GetConfig ("TraceMem", s);
		p := 0; traceBase := SYSTEM.VAL (ADDRESS, StrToInt (p, s));
		IF traceBase = 0 THEN traceBase := 0B8000H END;	(* default screen buffer *)
		FOR off := 0 TO TraceSize - SIZEOF(INTEGER) BY SIZEOF(INTEGER) DO SYSTEM.PUT16 (traceBase + off, 100H * 7H + 32) END;
		tracePos := 0;
		Portout8(3D4H, 0EX);
		Portout8(3D5H, CHR((TraceWidth*TraceHeight) DIV 100H));
		Portout8(3D4H, 0FX);
		Portout8(3D5H, CHR((TraceWidth*TraceHeight) MOD 100H))
	END;
	IF TraceV24 IN traceMode THEN
		FOR i := 0 TO MaxPorts - 1 DO
			COPY ("COMx", name); name[3] := CHR (ORD ("1") + i);
			GetConfig (name, s); p := 0; baselist[i] := StrToInt (p, s);
		END;
		IF baselist[0] = 0 THEN baselist[0] := 3F8H END;	(* COM1 port default values *)
		IF baselist[1] = 0 THEN baselist[1] := 2F8H END;	(* COM2 port default values *)
		GetConfig("TracePort", s); p := 0; p := StrToInt(p, s); DEC(p);
		IF (p >= 0) & (p < MaxPorts) THEN tracePort := baselist[p] ELSE tracePort := baselist[0] END;
		ASSERT(tracePort > 0);
		GetConfig("TraceBPS", s); p := 0; bps := StrToInt(p, s);
		IF bps <= 0 THEN bps := 38400 END;
		Portout8 (tracePort + 3, 80X);	(* Set the Divisor Latch Bit - DLAB = 1 *)
		bps := 115200 DIV bps;	(* compiler DIV/PORTOUT bug workaround *)
		Portout8 (tracePort + 1, CHR (bps DIV 100H));	(* Set the Divisor Latch MSB *)
		Portout8 (tracePort, CHR (bps MOD 100H));	(* Set the Divisor Latch LSB *)
		Portout8 (tracePort + 3, 3X);	(* 8N1 *)
		Portout8 (tracePort + 4, 3X);	(* Set DTR, RTS on in the MCR *)
		Portout8 (tracePort + 1, 0X);	(* Disable receive interrupts *)
	END;
	traceColor := 7; Trace.Char := TraceChar; Trace.Color := TraceColor;
END InitTrace;


(* The following procedure is linked as the first block in the bootfile *)
PROCEDURE {NOPAF, FIXED(01000000H)} FirstAddress;
CODE{SYSTEM.AMD64}
	; save arguments passed by bootloader
	MOV bootFlag, RAX
	MOV initRegs0,RSI
	MOV initRegs1, RDI
	
	MOV fbadr, RDI
	MOV fbInfoPtr, RCX

END FirstAddress;

(*
(* The following procedure is linked as the first block in the bootfile *)
PROCEDURE {NOPAF, FIXED(0100000H)} FirstAddress;
CODE{SYSTEM.AMD64}
	; relocate the bootfile from 0x1000 to target address 0x100000

	
	
	PUSH RAX
	PUSH RSI
	PUSH RDI

	
	MOV RSI,1000H
	MOV RDI,100000H
	MOV RCX, LastAddress
	SUB RCX, RDI
	
	; CLD
	; REP MOVSB
	
	ADD RSI, RCX
	ADD RDI, RCX
	STD
	REP MOVSB 
	
	POP RDI
	POP RSI
	POP RAX	



	; continue in relocated bootfile
	JMP DWORD 100000H - 1000H + Skip
Skip:


	; save arguments passed by bootloader
	MOV bootFlag, RAX
	MOV initRegs0,RSI
	MOV initRegs1, RDI

END FirstAddress;
*)

(* empty section allocated at end of bootfile *)
PROCEDURE {NOPAF} LastAddress;
CODE {SYSTEM.AMD64}
END LastAddress;

(* Init code called from OBL. EAX = boot table offset. ESI, EDI=initRegs. 2k stack is available. No trap handling. *)
BEGIN
	initRegs[0] := initRegs0;
	initRegs[1] := initRegs1;
	(* registers 6 and 7 get converted to 32 bit, cf. PCB.Assigne
	SYSTEM.GETREG(6, initRegs[0]); SYSTEM.GETREG(7, initRegs[1]);	(* initRegs0 & initRegs1 *)
	*)
	SYSTEM.PUT16(0472H, 01234H);	(* soft boot flag, for when we reboot *)
	ReadBootTable(bootFlag);

	InitTrace;
	Trace.String("Machine: "); Trace.Blue;Trace.StringLn (Version); Trace.Default;

	CheckMemory;
	SearchMP;
	AllocateDMA;	(* must be called after SearchMP, as lowTop is modified *)
	version := Version;
	InitBoot;
	InitProcessor;

	InitLocks;

	NmaxUserStacks := MaxUserStacks;
	ASSERT(ASH(1, PSlog2) = PS);
	Trace.String("Machine: Enabling MMU... ");
	InitSegments;	(* enable flat segments *)
	InitPages;	(* create page tables *)
	InitMemory;	(* switch on segmentation, paging and switch stack *)
	Trace.Green; Trace.StringLn("Ok"); Trace.Default;

	(* allocate empty memory block with enough space for at least one free block *)
	memBlockHead := SYSTEM.VAL (MemoryBlock, ADDRESSOF (initialMemBlock));
	memBlockTail := memBlockHead;
	initialMemBlock.beginBlockAdr := SYSTEM.VAL (ADDRESS, LastAddress);
	initialMemBlock.endBlockAdr := initialMemBlock.beginBlockAdr + StaticBlockSize;
	initialMemBlock.size := initialMemBlock.endBlockAdr - initialMemBlock.beginBlockAdr;

	FOR i := 0 TO IDTSize - 1 DO
		FOR j := 0 TO MaxNumHandlers - 1 DO
			intHandler[i, j].valid := FALSE;
			intHandler[i, j].handler := NIL
		END
	END;
	default.valid := FALSE;	(* initialized later *)
END Machine.

(*
03.03.1998	pjm	First version
30.06.1999	pjm	ProcessorID moved to AosProcessor
*)

(**
Notes

This module defines an interface to the boot environment of the system. The facilities provided here are only intended for the lowest levels of the system, and should never be directly imported by user modules (exceptions are noted below). They are highly specific to the system hardware and firmware architecture.

Typically a machine has some type of firmware that performs initial testing and setup of the system. The firmware initiates the operating system bootstrap loader, which loads the boot file. This module is the first module in the statically linked boot file that gets control.

There are two more-or-less general procedures in this module: GetConfig and StrToInt. GetConfig is used to query low-level system settings, e.g., the location of the boot file system. StrToInt is a utility procedure that parses numeric strings.

Config strings:

ExtMemSize	Specifies size of extended memory (above 1MB) in MB. This value is not checked for validity. Setting it false may cause the system to fail, possible after running for some time. The memory size is usually detected automatically, but if the detection does not work for some reason, or if you want to limit the amount of memory detected, this string can be set. For example, if the machine has 64MB of memory, this value can be set as ExtMemSize="63".
*)

