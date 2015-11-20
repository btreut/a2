MODULE Machine;
(** AUTHOR "pjm,fof"; PURPOSE "Bootstrapping, configuration and machine interface, adaption to windows fof"; *)
(* red marked parts are WinAos specific *)

IMPORT SYSTEM, Trace, Kernel32;

CONST
	Version = "WinAos Revision 5614 (04.07.2014)";

	DefaultConfigFile = "aos.ini";
	UserConfigFile = "myaos.ini";

	MaxCPU* = 8;	(* dummy definition to make GC for both Win32 and I386 work *)

	DefaultObjectFileExtension* = ".Obw";

	(** bits in features variable *)
	MTTR* = 12;  MMX* = 23;

	debug* = FALSE;   (** display more debug output during booting *)

CONST
	AddressSize = SIZEOF(ADDRESS);
	StaticBlockSize = 32;		(* static heap block size *)
	BlockHeaderSize = 2 * AddressSize;
	RecordDescSize = 4 * AddressSize;  (* needs to be adapted in case Heaps.RecordBlockDesc is changed *)

(** standard lock levels (in order) *)  (* also refer to Traps.Show *)
	TraceOutput* = 0;   (* Trace output *)
	Memory* = 1;   (* Virtual memory management, stack and page allocation *)
	Heaps* = 2;   (* Storage allocation and Garbage collection *)
	Interrupts* = 3;   (* Interrupt handling. *)
	Modules* = 4;   (* Module list *)
	Objects* = 5;   (* Ready queue *)
	Processors* = 6;   (* Interprocessor interrupts *)
	KernelLog* = 7;   (* Atomic output *)
	GC* = 8;
	MaxLocks = 9;   (* { <= 32 } *)

	StrongChecks = FALSE;

	HeaderSize = 40H; (* cf. Linker0 *)
	EndBlockOfs = 38H;	(* cf. Linker0 *)
	MemoryBlockOfs = BlockHeaderSize + RecordDescSize + BlockHeaderSize; (* memory block (including header) starts at offset HeaderSize *)

	MemBlockSize = 4*1024*1024; (* must be multiple of StaticBlockSize *)
	MinMemBlockSize = 4*1024*1024;

	NilVal = 0;

	Second* = 1000; (* frequency of ticks increments in Hz *)


CONST
		(* error codes *)
		Ok* = 0;
		NilAdr* = -1;	(* nil value for addresses (not same as pointer NIL value) *)
		IsCooperative* = FALSE;
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

	commandLine-: ARRAY 256 OF CHAR;
	hin, hout: Kernel32.HANDLE;

VAR
	lock-: ARRAY MaxLocks OF CHAR;  (* not implemented as SET because of shared access *)
	cs: ARRAY MaxLocks OF Kernel32.CriticalSection;
	trace: ARRAY 2 OF CHAR;
	defaultConfigFile, userConfigFile, traceName: ARRAY Kernel32.MaxPath OF CHAR;

	gcThreshold-: SIZE;
	bootHeapAdr: ADDRESS; 	(* initialized by linker, variable name must not be changed, see Win32.Aos.Link *)
	bootHeapSize: SIZE; 			(* initialized by linker, variable name must not be changed, see Win32.Aos.Link *)
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

(** Atomic INC with one parameter. *)

	PROCEDURE -Inc*( VAR x: LONGINT );
	CODE {SYSTEM.i386}
		POP	EAX
		LOCK
		INC	DWORD[EAX]
	END Inc;

(** Atomic EXCL. *)

	PROCEDURE Excl*( VAR s: SET;  bit: LONGINT );
	CODE {SYSTEM.i386}
		MOV	EAX, [EBP+bit]
		MOV	EBX, [EBP+s]
		LOCK
		BTR	[EBX], EAX
	END Excl;
	(** -- Miscellaneous -- *)

(** This procedure should be called in all spin loops as a hint to the processor (e.g. Pentium 4). *)

	PROCEDURE -SpinHint*;
	CODE {SYSTEM.i386}
		XOR	ECX, ECX	;  just in case some processor interprets REP this way
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

(* Set current frame pointer *)
PROCEDURE -SetBP* (bp: ADDRESS);
CODE {SYSTEM.i386}
	POP EBP
END SetBP;

(* Return current stack pointer *)
PROCEDURE -CurrentSP* (): ADDRESS;
CODE {SYSTEM.i386}
	MOV EAX, ESP
END CurrentSP;

(* Set current stack pointer *)
PROCEDURE -SetSP* (sp: ADDRESS);
CODE {SYSTEM.i386}
	POP ESP
END SetSP;

(** Fill "size" bytes at "destAdr" with "filler".  "size" must be multiple of 4. *)

	PROCEDURE Fill32*( destAdr, size, filler: LONGINT );
	CODE {SYSTEM.i386}
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

(** Setup FPU control word of current processor. *)

	PROCEDURE SetupFPU*;
	BEGIN
		InitFPU;  SetFCR( fcr )
	END SetupFPU;

(** CPU identification. *)

	PROCEDURE CPUID*( VAR vendor: Vendor;  VAR version: LONGINT;  VAR features1,features2: SET );
	CODE {SYSTEM.i386, SYSTEM.Pentium}
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
	END CPUID;

	PROCEDURE GetConfig*( CONST name: ARRAY OF CHAR;  VAR val: ARRAY OF CHAR );
	CONST ConfigKey = "Configuration";
	BEGIN
		COPY ("", val);
		IF Kernel32.GetPrivateProfileString (ConfigKey, name, "", val, LEN (val), userConfigFile) # 0 THEN
		ELSIF Kernel32.GetPrivateProfileString (ConfigKey, name, "", val, LEN (val), defaultConfigFile) # 0 THEN
		END;
	END GetConfig;

	PROCEDURE Shutdown*( restart: BOOLEAN );
	BEGIN
		RemoveTraceFile;
		Kernel32.Shutdown( 0 );   (* calls the finalizer of Heaps *)
	END Shutdown;

(* Dan: from new Machine *)
PROCEDURE -GetTimer*(): HUGEINT;
CODE {SYSTEM.Pentium}
	RDTSC	; set EDX:EAX
END GetTimer;

(* Dan:  mono CPU PCs *)
PROCEDURE ID*(): LONGINT;
BEGIN
	RETURN 0
END ID;


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


(* setup MMX, SSE and SSE2..SSE5 and AVX extension *)

PROCEDURE SetupSSE2Ext;
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
BEGIN
	MMXSupport := MMXFlag IN features;
	SSESupport := SSEFlag IN features;
	SSE2Support := SSESupport & (SSE2Flag IN features);
	SSE3Support := SSE2Support & (SSE3Flag IN features2);
	SSSE3Support := SSE3Support & (SSSE3Flag IN features2); (* PH 04/11*)
	SSE41Support := SSE3Support & (SSE41Flag IN features2);
	SSE42Support := SSE3Support & (SSE42Flag IN features2);
	SSE5Support := SSE3Support & (SSE5Flag IN features2);
	AVXSupport := SSE3Support & (AVXFlag IN features2);

	IF SSESupport & (FXSRFlag IN features) THEN
		(* InitSSE(); *) (*! not privileged mode in Windows not allowed *)
	END;
END SetupSSE2Ext;

PROCEDURE ReadCommandLine(VAR commandLine: ARRAY OF CHAR);
VAR adr: ADDRESS; i: LONGINT; ch: CHAR;
BEGIN
	adr := Kernel32.GetCommandLine();
	SYSTEM.GET(adr,ch);
	i := 0;
	WHILE (i<LEN(commandLine)-1) & (ch # 0X) DO
		commandLine[i] := ch;
		INC(adr); INC(i);
		SYSTEM.GET(adr,ch);
	END;
END ReadCommandLine;

PROCEDURE ParseLine(VAR c: ARRAY OF CHAR; VAR iniFile: ARRAY OF CHAR);
VAR i: LONGINT;

	PROCEDURE SkipSpaces;
	BEGIN
		WHILE (c[i] <= " ") & (c[i] # 0X) DO INC(i) END;
	END SkipSpaces;

	PROCEDURE SkipName;
	BEGIN
		WHILE (c[i] > " ") DO INC(i) END;
	END SkipName;

	PROCEDURE CheckName(CONST name: ARRAY OF CHAR): BOOLEAN;
	VAR j: LONGINT;
	BEGIN
		j := 0;
		WHILE (c[i] = name[j]) & (c[i] # 0X) & (name[j] # 0X) DO
			INC(i); INC(j);
		END;
		RETURN (name[j] = 0X);
	END CheckName;

	PROCEDURE ReadName(VAR name: ARRAY OF CHAR);
	VAR j: LONGINT;
	BEGIN
		SkipSpaces;
		j := 0;
		WHILE (c[i] > " ") & (j < LEN(name)-1) DO
			name[j] := c[i];
			INC(i); INC(j);
		END;
		name[j] := 0X;
	END ReadName;

BEGIN
	c[LEN(c)-1] := 0X;
	i := 0;
	SkipSpaces;
	SkipName;
	SkipSpaces;
	IF c[i] = "-" THEN (* option *)
		INC(i);
		IF CheckName("ini") THEN SkipSpaces; ReadName(iniFile) END;
	END;
END ParseLine;

PROCEDURE TraceChar(c: CHAR);
VAR len: LONGINT;
BEGIN
	len := 1;
	Kernel32.WriteFile(hout,c,len,len,NIL);
END TraceChar;

PROCEDURE SetTraceFile(VAR filename: ARRAY OF CHAR);
BEGIN
	Trace.String("trace -> file "); Trace.String(filename); Trace.Ln;
	hout := Kernel32.CreateFile(filename, {Kernel32.GenericWrite}, {Kernel32.FileShareRead}, NIL, Kernel32.CreateAlways, {Kernel32.FileAttributeNormal}, Kernel32.NULL);
	Kernel32.GetFullPathName(filename, LEN(filename), filename, NIL);
	Trace.Char := TraceChar;
END SetTraceFile;

PROCEDURE SetTraceConsole;
VAR res: LONGINT;
BEGIN
	Trace.String("trace -> console"); Trace.Ln;
	res := Kernel32.AllocConsole ();
	hin := Kernel32.GetStdHandle (Kernel32.STDInput);
	hout := Kernel32.GetStdHandle (Kernel32.STDOutput);
	Trace.Char := TraceChar;
END SetTraceConsole;

PROCEDURE SetupTraceName(VAR traceName: ARRAY OF CHAR);
VAR
	ext: ARRAY 256 OF CHAR;
	extPos,i,j: LONGINT;
	systemTime: Kernel32.SystemTime;
	ch: CHAR;

	PROCEDURE AppendDecimals(int: LONGINT; from, to: LONGINT);
	VAR ten: LONGINT;
	BEGIN
		WHILE to >= from DO
			traceName[i] := CHR(ORD("0")+ int DIV to MOD 10); INC(i);
			to := to DIV 10;
		END;
	END AppendDecimals;

BEGIN
	Kernel32.GetLocalTime(systemTime);

	extPos := 0;
	REPEAT
		ch := traceName[i];

		IF ch = "." THEN j := 0; extPos := i END;

		ext[j] := ch;
		INC(j); INC(i);
	UNTIL ch = 0X;

	IF extPos > 0 THEN i := extPos END;
	ext[j] := 0X;

	AppendDecimals(systemTime.wYear,1,1000);
	AppendDecimals(systemTime.wMonth,1,10);
	AppendDecimals(systemTime.wDay,1,10);
	traceName[i] := "_"; INC(i);
	AppendDecimals(systemTime.wHour,1,10);
	AppendDecimals(systemTime.wMinute,1,10);
	AppendDecimals(systemTime.wSecond,1,10);
	traceName[i] := "_"; INC(i);
	AppendDecimals(systemTime.wMilliseconds,10,100);
	j := 0;
	REPEAT
		ch := ext[j];
		traceName[i] := ch;
		INC(i); INC(j);
	UNTIL ch = 0X;

END SetupTraceName;

PROCEDURE RemoveTraceFile;
VAR res: LONGINT;
BEGIN
	IF traceName[0] # 0X THEN
		Trace.String("removing "); Trace.String(traceName); Trace.Ln;
		Trace.Char := LogChar;
		res := Kernel32.CloseHandle(hout);
		IF res = 0 THEN
			res := Kernel32.GetLastError();
			Trace.String("could not close "); Trace.String("; res = "); Trace.Int(res,1); Trace.Ln;
		END;
		res := Kernel32.DeleteFile(traceName);
		IF res = 0 THEN
			res := Kernel32.GetLastError();
			Trace.String("could not delete "); Trace.String(traceName); Trace.String("; res = "); Trace.Int(res,1); Trace.Ln;
		END;

	END;
END RemoveTraceFile;

PROCEDURE ToExecutablePath(CONST name: ARRAY OF CHAR; VAR fullName: ARRAY OF CHAR);
VAR i,j: LONGINT;
BEGIN
	Kernel32.GetModuleFileName(Kernel32.hInstance, fullName, LEN( fullName ) );
	j := -1; i := 0;
	WHILE fullName[i] # 0X DO
		IF fullName[i] = '\' THEN j := i END;
		INC( i )
	END;
	i := 0; INC(j);
	WHILE name[i] # 0X DO
		fullName[j] := name[i]; INC(i); INC(j);
	END;
	fullName[j] := 0X;
END ToExecutablePath;

PROCEDURE Init*;
VAR vendor: Vendor; ver: LONGINT; hfile: Kernel32.HANDLE;
BEGIN
	Kernel32.Init;
	trace[1] := 0X; Trace.Char := LogChar; Trace.Color := TraceColor;
	InitLocks();
	Trace.String("Machine");
	boottime:=GetTimer();

	COPY( Version, version );
	CPUID(vendor, ver, features,features2);	 SetupSSE2Ext;
	fcr := (FCR() - {0,2,3,10,11}) + {0..5,8,9};	(* default FCR RC=00B *)

	ReadCommandLine(commandLine);

	ToExecutablePath(DefaultConfigFile, defaultConfigFile);
	COPY(UserConfigFile, userConfigFile);
	hfile := Kernel32.CreateFile( userConfigFile, {Kernel32.GenericRead}, {Kernel32.FileShareRead}, NIL , Kernel32.OpenExisting, {Kernel32.FileAttributeNormal}, 0 );
	IF hfile = Kernel32.InvalidHandleValue THEN
		ToExecutablePath(UserConfigFile, userConfigFile);
	ELSE
		Kernel32.CloseHandle(hfile)
	END;

	(* ever used ? *)
	ParseLine(commandLine, userConfigFile);
	userConfigFile[Kernel32.GetFullPathName (userConfigFile, Kernel32.MaxPath, userConfigFile, 0)] := 0X;

	Trace.String("config file = "); Trace.String(defaultConfigFile); Trace.Ln;
	Trace.String("user config file = "); Trace.String(userConfigFile); Trace.Ln;

	traceName[0] := 0X;
	GetConfig("Trace",traceName);
	IF traceName = "File" THEN
		traceName := "SystemTrace.txt";
		SetupTraceName(traceName);
		SetTraceFile(traceName);
	ELSIF traceName = "Console" THEN SetTraceConsole
	(* else trace is on kernel log *)
	END;
END Init;

	(* Initialize locks. *)
	PROCEDURE InitLocks;
	VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE i < MaxLocks DO Kernel32.InitializeCriticalSection( cs[i] ); lock[i] := "N"; INC( i ) END;
	END InitLocks;

	PROCEDURE CleanupLocks*;
	VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE i < MaxLocks DO Kernel32.DeleteCriticalSection( cs[i] );  INC( i ) END;
	END CleanupLocks;

(** Acquire a spin-lock. *)
	PROCEDURE Acquire*( level: LONGINT );   (* non reentrant lock  (non reentrance "ensured" by ASSERT statement ), CriticalSections are reentrant *)
	BEGIN
		Kernel32.EnterCriticalSection( cs[level] );
		IF StrongChecks THEN
			ASSERT ( lock[level] = "N", 1001 );
		ELSIF lock[level] # "N" THEN
			Trace.String("warning: reentered non-reentrant lock"); Trace.Ln;
		END;
		lock[level] := "Y";
	END Acquire;

(** Release a spin-lock. *)
	PROCEDURE Release*( level: LONGINT );   (* release lock *)
	BEGIN
		IF StrongChecks THEN
			ASSERT ( lock[level] ="Y", 1002 );
		ELSIF lock[level] # "Y" THEN
			Trace.String("warning: reentered non-reentrant lock"); Trace.Ln;
		END;
		lock[level] := "N";
		Kernel32.LeaveCriticalSection( cs[level] )
	END Release;


	(* added by Alexey *)
	PROCEDURE GetMemStatus(VAR stat: Kernel32.MemoryStatusEx): BOOLEAN;
	BEGIN
		stat.dwLength := 64;
		IF Kernel32.GlobalMemoryStatusEx(stat) = 1 THEN
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END;
	END GetMemStatus;

(** dummy procedure to make GC work for both I386 and Win32 *)
PROCEDURE GetKernelStacks*(VAR stack: ARRAY OF Stack);
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO MaxCPU-1 DO
		stack[i].adr := NilVal;
		stack[i].high := NilVal
	END
END GetKernelStacks;

(* Set machine-dependent parameter gcThreshold *)
PROCEDURE SetGCParams*;
BEGIN
	gcThreshold := 10*1024*1024; (* 10 MB *)
END SetGCParams;

(* expand heap by allocating a new memory block - called during GC *)
PROCEDURE InitHeap(VAR memoryBlock: MemoryBlock; VAR beginBlockAdr, endBlockAdr: ADDRESS);
CONST MemBlockHeaderSize = BlockHeaderSize + RecordDescSize + BlockHeaderSize;
	TypeDescOffset = -AddressSize; (* see Heaps.Mod *)
	HeapBlockOffset = - 2 * AddressSize; (* see Heaps.Mod *)
	DataAdrOffset = AddressSize; (* offset of dataAdr field in Heaps.HeapBlockDesc *)
VAR memDescSize, memBlkSize, alignOffset: SIZE; adr, memHeaderAdr, memBlockAdr, memBlockHeadAdr: ADDRESS;
	memBlock {UNTRACED}: MemoryBlock; i: LONGINT; ch: CHAR; h: HUGEINT; size: LONGINT;
	initVal: LONGINT;
BEGIN

	(*
		HeapBlockPtr -- bootHeapAdr
	4	Type
	8	Mark
	12	DataAdr
	16	Size
	20	HeapBlockPtr
	24	Type
	28	next  -- MemoryBlock
	32	startAdr
	36	size
	40	beginBlockAdr
	44	endBlockAdr
	48		--beginBlockAdr
	....
			--endBlockAdr

	*)
	size := 1;
	memDescSize := MemBlockHeaderSize + SIZEOF(MemoryBlockDesc);
	INC(memDescSize, (-memDescSize) MOD StaticBlockSize); 	(* round up to multiple of StaticBlockSize *)
	INC(size, (-size) MOD StaticBlockSize); (* round up to multiple of StaticBlockSize *)
	memBlkSize := memDescSize + size + StaticBlockSize; 		(* add StaticBlockSize to account for alignments different from multiples of StaticBlockSize *)
	IF memBlkSize < MemBlockSize THEN memBlkSize := MemBlockSize END; 	(* MemBlockSize implicitly multiple of StaticBlockSize *)

	initVal := 8*1024*1024;
	adr := Kernel32.VirtualAlloc(initVal, memBlkSize, {Kernel32.MEMCommit, Kernel32.MEMReserve}, {Kernel32.PageExecuteReadWrite});
	IF adr = NilVal THEN (* allocation failed *)
		adr := Kernel32.VirtualAlloc(NilVal, memBlkSize, {Kernel32.MEMCommit}, {Kernel32.PageExecuteReadWrite});
	END;
	Trace.String("first heap block intVal "); Trace.Int(initVal,1); Trace.Ln;
	Trace.String("first heap block memBlkSize "); Trace.Int(memBlkSize,1); Trace.Ln;
	Trace.String("first heap block adr "); Trace.Int(adr,1); Trace.Ln;
	ASSERT(adr # 0);

	alignOffset := (-adr) MOD StaticBlockSize;

	memHeaderAdr := adr + alignOffset;  	(* force alignment of memory block start *)
	memBlockAdr := memHeaderAdr + MemBlockHeaderSize;
	memBlock := SYSTEM.VAL(MemoryBlock, memBlockAdr);
	beginBlockAdr := memHeaderAdr + memDescSize;

	memBlock.next := NIL;
	memBlock.startAdr := adr;
	memBlock.size := memBlkSize;

	beginBlockAdr := memHeaderAdr + memDescSize;
	endBlockAdr := adr + memBlkSize - alignOffset;
	memBlock.beginBlockAdr := beginBlockAdr;
	memBlock.endBlockAdr := endBlockAdr;

	(* correct fields *)
	SYSTEM.PUT(memBlockAdr + HeapBlockOffset, memHeaderAdr + BlockHeaderSize);	(* set reference to header part of memory block correctly *)
	SYSTEM.PUT(memBlockAdr + TypeDescOffset, 0);										(* set type descriptor field of memory block to default value, memory blocks are not traced by GC *)
	SYSTEM.PUT(memHeaderAdr + BlockHeaderSize + DataAdrOffset, memBlockAdr);		(* set dataAdr of RecordBlockDesc to correct value *)
	SYSTEM.PUT(memHeaderAdr + BlockHeaderSize + 2*AddressSize , memBlkSize);

	(* fill first heap block *)
	SYSTEM.PUT(beginBlockAdr,0);
	SYSTEM.PUT(beginBlockAdr+AddressSize,0);
	SYSTEM.PUT(beginBlockAdr+2*AddressSize,0);
	SYSTEM.PUT(beginBlockAdr+3*AddressSize,beginBlockAdr+7*AddressSize);
	SYSTEM.PUT(beginBlockAdr+4*AddressSize,endBlockAdr-beginBlockAdr);
	SYSTEM.PUT(beginBlockAdr+5*AddressSize,beginBlockAdr+2*AddressSize);
	SYSTEM.PUT(beginBlockAdr+6*AddressSize,0);

	memoryBlock := memBlock;
END InitHeap;

(** Get first memory block and first free address, the first free address is identical to memBlockHead.endBlockAdr *)
PROCEDURE GetStaticHeap*(VAR beginBlockAdr, endBlockAdr, freeBlockAdr: ADDRESS);
VAR memBlockAdr: ADDRESS;
BEGIN
	InitHeap(memBlockHead,beginBlockAdr, endBlockAdr);
	memBlockTail := memBlockHead;

	(*
	SYSTEM.GET(bootHeapAdr + EndBlockOfs, freeBlockAdr);
	ASSERT(freeBlockAdr MOD StaticBlockSize = 0);
	memBlockAdr := bootHeapAdr + HeaderSize + MemoryBlockOfs;


	memBlockHead := SYSTEM.VAL(MemoryBlock, memBlockAdr); (* this block will never be freed since there is a global reference (initBlock in Heaps.Mod) to it *)
	memBlockHead.startAdr := bootHeapAdr;
	memBlockHead.size := bootHeapSize;
	ASSERT(memBlockHead.beginBlockAdr MOD StaticBlockSize = 0);
	ASSERT((memBlockHead.endBlockAdr - memBlockHead.beginBlockAdr) MOD StaticBlockSize = 0);
	memBlockTail := memBlockHead;
	*)
	beginBlockAdr := memBlockHead.beginBlockAdr;
	endBlockAdr := memBlockHead.endBlockAdr;
	freeBlockAdr := beginBlockAdr;
END GetStaticHeap;

(* returns if an address is a currently allocated heap address *)
PROCEDURE ValidHeapAddress*(p: ADDRESS): BOOLEAN;
BEGIN
	RETURN (p >= memBlockHead.beginBlockAdr) & (p <= memBlockTail.endBlockAdr)

		OR (p>=401000H) & (p<=500000H) (*! guess until kernel size known *)

END ValidHeapAddress;


PROCEDURE GetFreeK* (VAR total, lowFree, highFree: SIZE);
VAR
	stat: Kernel32.MemoryStatusEx;
BEGIN
	total := MAX(LONGINT); lowFree := 0; highFree := total;
	(*<< added by Alexey *)
	IF GetMemStatus(stat) THEN
		total := SHORT(stat.ullTotalVirtual DIV 1024);
		lowFree := 0;
		highFree := SHORT(stat.ullAvailVirtual DIV 1024);
	END;
	(* added by Alexey >>*)
END GetFreeK;

(* ug *)
PROCEDURE TraceMemBlocks*;
VAR memBlock {UNTRACED}: MemoryBlock; i : LONGINT;
BEGIN
	memBlock := memBlockHead;
	i := 0;
	WHILE memBlock # NIL DO
		Trace.String("block "); Trace.Int(i, 0); Trace.String(": startAdr = "); Trace.Hex(memBlock.startAdr, 0);
		Trace.String(" size = "); Trace.Hex(memBlock.size, 0);
		Trace.String(" beginBlockAdr = "); Trace.Hex(memBlock.beginBlockAdr, 0);
		Trace.String(" endBlockAdr = "); Trace.Hex(memBlock.endBlockAdr, 0); Trace.Ln;
		memBlock := memBlock.next;
		INC(i)
	END
END TraceMemBlocks;

(* insert given memory block in sorted list of memory blocks, sort key is startAdr field - called during GC *)
PROCEDURE InsertMemoryBlock(memBlock: MemoryBlock);
VAR cur {UNTRACED}, prev {UNTRACED}: MemoryBlock;
BEGIN
	cur := memBlockHead;
	prev := NIL;
	WHILE (cur # NIL) & (cur.startAdr < memBlock.startAdr) DO
		prev := cur;
		cur := cur.next
	END;
	IF prev = NIL THEN (* insert at head of list *)
		memBlock.next := memBlockHead;
		memBlockHead := memBlock
	ELSE (* insert in middle or at end of list *)
		memBlock.next := cur;
		prev.next := memBlock;
		IF cur = NIL THEN
			memBlockTail := memBlock
		END
	END
END InsertMemoryBlock;

(* expand heap by allocating a new memory block - called during GC *)
PROCEDURE ExpandHeap*(dummy: LONGINT; size: SIZE; VAR memoryBlock: MemoryBlock; VAR beginBlockAdr, endBlockAdr: ADDRESS);
CONST MemBlockHeaderSize = BlockHeaderSize + RecordDescSize + BlockHeaderSize;
	TypeDescOffset = -AddressSize; (* see Heaps.Mod *)
	HeapBlockOffset = - 2 * AddressSize; (* see Heaps.Mod *)
	DataAdrOffset = AddressSize; (* offset of dataAdr field in Heaps.HeapBlockDesc *)
VAR memDescSize, memBlkSize, alignOffset: SIZE; adr, memHeaderAdr, memBlockAdr, memBlockHeadAdr: ADDRESS;
	memBlock {UNTRACED}: MemoryBlock; i: LONGINT; ch: CHAR; h: HUGEINT; initVal: LONGINT;
	continue: BOOLEAN;
BEGIN
	memDescSize := MemBlockHeaderSize + SIZEOF(MemoryBlockDesc);
	INC(memDescSize, (-memDescSize) MOD StaticBlockSize); 	(* round up to multiple of StaticBlockSize *)
	INC(size, (-size) MOD StaticBlockSize); (* round up to multiple of StaticBlockSize *)
	memBlkSize := memDescSize + size + StaticBlockSize; 		(* add StaticBlockSize to account for alignments different from multiples of StaticBlockSize *)
	INC(memBlkSize, (-memBlkSize) MOD MemBlockSize);
	initVal := memBlockTail.startAdr + memBlockTail.size;
	adr := Kernel32.VirtualAlloc(initVal, memBlkSize, {Kernel32.MEMCommit, Kernel32.MEMReserve}, {Kernel32.PageExecuteReadWrite});
	IF adr = NilVal THEN (* allocation failed *)
		adr := Kernel32.VirtualAlloc(NilVal, memBlkSize, {Kernel32.MEMCommit}, {Kernel32.PageExecuteReadWrite});
	END;
	continue := adr = initVal;
	Trace.String("expand heap block intVal "); Trace.Int(initVal,1); Trace.Ln;
	Trace.String("expand heap block memBlkSize "); Trace.Int(memBlkSize,1); Trace.Ln;
	Trace.String("expand heap block adr "); Trace.Int(adr,1); Trace.Ln;
	ASSERT(adr # 0);

	IF adr # 0 THEN

		alignOffset := (-adr) MOD StaticBlockSize;

		IF continue THEN
			memBlock := memBlockTail;
			memBlock.size := memBlock.size + memBlkSize;

			beginBlockAdr := memBlockTail.endBlockAdr;
			endBlockAdr := beginBlockAdr;
			INC(endBlockAdr, memBlkSize);
		ELSE
			memHeaderAdr := adr + alignOffset;  	(* force alignment of memory block start *)
			memBlockAdr := memHeaderAdr + MemBlockHeaderSize;
			memBlock := SYSTEM.VAL(MemoryBlock, memBlockAdr);
			memBlock.next := NIL;
			memBlock.startAdr := adr;
			memBlock.size := memBlkSize;

			beginBlockAdr := memHeaderAdr + memDescSize;
			endBlockAdr := adr + memBlkSize - alignOffset;
			memBlock.beginBlockAdr := beginBlockAdr;
			memBlock.endBlockAdr := beginBlockAdr;
			(* upon memory block insertion memBlock.beginBlockAdr = memBlock.endBlockAdr to denote that the memory block has no valid heap blocks yet
			     - necessary for real-time GC. Memory block end address is set by caller by using SetMemBlockEndAddress after fitting free block in. *)

			(* copy header of memBlockHead to header of memBlock - byte by byte *)
			memBlockHeadAdr := SYSTEM.VAL(ADDRESS, memBlockHead);
			FOR i := 0 TO MemBlockHeaderSize - 1 DO
				SYSTEM.GET(memBlockHeadAdr - MemBlockHeaderSize + i, ch);
				SYSTEM.PUT(memBlockAdr - MemBlockHeaderSize + i, ch)
			END;

			(* correct fields *)
			SYSTEM.PUT(memBlockAdr + HeapBlockOffset, memHeaderAdr + BlockHeaderSize);	(* set reference to header part of memory block correctly *)
			SYSTEM.PUT(memBlockAdr + TypeDescOffset, 0);										(* set type descriptor field of memory block to default value, memory blocks are not traced by GC *)
			SYSTEM.PUT(memHeaderAdr + BlockHeaderSize + DataAdrOffset, memBlockAdr);		(* set dataAdr of RecordBlockDesc to correct value *)

			InsertMemoryBlock(memBlock);
		END;

		memoryBlock := memBlock;
	ELSE
		beginBlockAdr := 0; endBlockAdr := 0;
	END;
END ExpandHeap;

(* Set memory block end address *)
PROCEDURE SetMemoryBlockEndAddress*(memBlock: MemoryBlock; endBlockAdr: ADDRESS);
BEGIN
	ASSERT(endBlockAdr >= memBlock.beginBlockAdr);
	memBlock.endBlockAdr := endBlockAdr
END SetMemoryBlockEndAddress;

(* Free unused memory block - called during GC *)
PROCEDURE FreeMemBlock*(memBlock: MemoryBlock);
VAR cur {UNTRACED}, prev {UNTRACED}: MemoryBlock;
	startAdr: ADDRESS;
BEGIN
	cur := memBlockHead;
	prev := NIL;
	WHILE (cur # NIL) & (cur # memBlock) DO
		prev := cur;
		cur := cur.next
	END;
	IF cur = memBlock THEN
		IF prev = NIL THEN
			memBlockHead := cur.next;
		ELSE
			prev.next := cur.next;
			IF prev.next = NIL THEN
				memBlockTail := prev
			END
		END;
		memBlock.next := NIL;
		startAdr := memBlock.startAdr; (* this value must be cached for the second call of Kernel32.VirtualFree *)
		Kernel32.VirtualFree(SYSTEM.VAL(LONGINT, memBlock.startAdr), memBlock.size, {Kernel32.MEMDecommit});
		Kernel32.VirtualFree(SYSTEM.VAL(LONGINT, startAdr ), 0, {Kernel32.MEMRelease});
	ELSE
		HALT(535)	(* error in memory block management *)
	END;
END FreeMemBlock;

PROCEDURE PhysicalAdr*(adr: ADDRESS; size: SIZE): ADDRESS;
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
		POP ECX		; address of x
		DB 0F0X, 00FX, 0B1X, 019X	; LOCK CMPXCHG [ECX], EBX; atomicly compare x with old and set it to new if equal
	END AtomicCAS;

(* function returning the number of processors that are available to Aos *)
PROCEDURE NumberOfProcessors*( ): LONGINT;
VAR info: Kernel32.SystemInfo;
BEGIN
	Kernel32.GetSystemInfo( info );
	RETURN info.dwNumberOfProcessors
END NumberOfProcessors;

(* function for changing byte order *)
PROCEDURE ChangeByteOrder* (n: LONGINT): LONGINT;
CODE { SYSTEM.Pentium }
	MOV EAX, [EBP+n]				; load n in eax
	BSWAP EAX						; swap byte order
END ChangeByteOrder;

PROCEDURE TraceColor (c: SHORTINT);
END TraceColor;

PROCEDURE LogChar (c: CHAR);
BEGIN trace[0] := c; Kernel32.OutputString (trace);
END LogChar;

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
	MOV ECX, [EBP+val]
	MOV [ECX], AL
END Portin8;

PROCEDURE Portin16*(port: LONGINT; VAR val: INTEGER);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN AX, DX
	MOV ECX, [EBP+val]
	MOV [ECX], AX
END Portin16;

PROCEDURE Portin32*(port: LONGINT; VAR val: LONGINT);
CODE{SYSTEM.i386}
	MOV EDX,[EBP+port]
	IN EAX, DX
	MOV ECX, [EBP+val]
	MOV [ECX], EAX
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

BEGIN
	IF ~Kernel32.Generic THEN
		Init
	END;
END Machine.
