MODULE CPUID; (** AUTHOR "staubesv"; PURPOSE "Intel/AMD CPUID Information"; *)
(**
 * The purpose of this module is to dump processor information provided by the CPUID instruction in a human readable format.
 * It is not part (and not intended to be part) of the kernel.
 *
 * Usage:
 *
 *	CPUID.Show ~ 	displays the processor name and the most relevant features
 *	CPUID.ShowDetailed ~ displays all information provided by CPUID
 *
 *	SystemTools.Free CPUID ~
 *
 * Notes:
 *	- The CPUID instruction is supported by CPUs >= 80486
 *
 * References:
 *
 *	[1] Intel Processor Identification and the CPUID Instruction, Application Note 485, December 2007
 *	[2] AMD CPUID Specification, Revision 2.18, January 2006
 *)


IMPORT
	SYSTEM, Streams, Commands, Options;

CONST

	(** CpuInformation.type encoding *)
	Intel* = 0;
	Amd* = 1;
	Other* = 2;

	(* CpuInformation.features encoding *)
	PBE* = 31;					(** INTEL: Pending Break Enable *)
	IA64* = 30;					(** INTEL: IA64 Capabilities *)
	TM* = 29;					(** INTEL: Thermal Monitor supported *)
	HTT* = 28;					(** Hyper-Threading Technology *)
	SS* = 27;					(** INTEL: Self-Snoop *)
	SSE2* = 26;					(** SSE2 extensions *)
	SSE* = 25;					(** SSE extensions *)
	FXSR* = 24;					(** FXSAVE and FXRSTOR instructions *)
	MMX* = 23;					(** MMX instructions *)
	ACPI* = 22;					(** INTEL: Thermal Monitor and Software Controlled Clock Facilities supported *)
	DS* = 21;					(** INTEL: Debug Store *)
	CLFLUSH* = 19;				(** CLFLUSH instruction *)
	PSN* = 18;					(** INTEL: Processor serial number is present and enabled *)
	PSE36* = 17;				(** Page-size extension *)
	PAT* = 16;					(** Page attribute table *)
	CMOV* = 15;				(** CMOV & FCMOV conditional move instructions *)
	MCA* = 14;					(** Machine check architecture *)
	PGE* = 13;					(**	Page global extension *)
	MTRR* = 12;				(** Memory-type range registers *)
	SysEnterSysExit* = 11;		(** SYSENTER & SYSEXIT instructions *)
	APIC* = 9;					(** APIC exists and is enabled *)
	CMPXCH8B* = 8;			(** CMPXCHGB8 instruction *)
	MCE* = 7;					(** Machine check exception *)
	PAE* = 6;					(** Physical-address extendions (support for physical addresss > 32b) *)
	MSR* = 5;					(** Model-specific registers with RDMSR & WRMSR instructions *)
	TSC* = 4;					(** Time stamp counter with RDTSC and RDTSCP instruction support *)
	PSE* = 3;					(** Page-size extensions (4MB pages) *)
	DE* = 2;					(** Debugging extensions, I/O breakpoints *)
	VME* = 1;					(** Virtual-mode enhancements *)
	FPU* = 0;					(** Floating point unit on chip *)

	(** CpuIformation.features2 encoding *)
	SSE4_2* = 20;  				(** INTEL: Streaming SIMD Extensions 4.2*)
    	SSE4_1* = 19;  				(** INTEL: Streaming SIMD Extensions 4.1*)

	DCA* = 18;					(** INTEL: Direct Access Cache *)
	PDCM* =15; 				(** INTEL: Performance Capabilities MSR*)
	XTPR* = 14;					(** INTEL: Send Task Priority Messages *)
	CMPXCHG16B* = 13;		(** CMPXCHG16B instruction *)
	CID* = 10;					(** INTEL: Context ID *)
	SSSE3* = 9;					(** INTEL: Supplemental Streaming SIMD Extensions 3 *)
	TM2* = 8;					(** INTEL: Thermal Monitor 2 *)
	EST* = 7;					(** INTEL: Enhanced Intel SpeedStep Technology *)
	SMX* = 6; 					(** INTEL: Safer Mode Extensions *)
	VMX* = 5;					(** INTEL: Virtual Machine Extensions *)
	DS_CPL* = 4;				(** INTEL: CPL Qualified Debug Store *)
	MONITOR* = 3;				(** INTEL: Monitor/MWAIT *)
	DTES64* = 2;  				(** INTEL: 64-Bit Debug Store *)
	SSE3* = 0;					(** SSE3 extensions *)

	(** CpuInformation.extFeatures encoding (AMD) *)
	Amd3DNow* = 31;			(** AMD: 3DNow! instructions *)
	Amd3DNowExt* = 32;		(** AMD: AMD extensions to 3DNow! *)
	LM* = 29; 					(** Long Mode supported (64bit support), IA-32e*)
	RDTSCP* = 27;				(** AMD: RDTSCP instruction *)
	FFXSR* = 25;				(** AMD: FXSAVE & FXRSTOR instruction optimizations *)
	MmxExt* = 22;				(** AMD: AMD extensions to MMX instructins *)
	NX* = 20;					(** No-execute page protection *)
	SysCallSysRet* = 11;			(** SYSCALL & SYSRET instructions *)
	(** Bits 24..23, 17..12, 9..0 contain the same information as cpuInfo.features *)

	(** CpuInformation.extFeatures2 encoding (AMD) *)
	AltMovCr8* = 4; 			(** AMD: LOCK MOV CR0 means MOV CR8 *)
	SVM* = 2; 					(** AMD: Secure virtual machine feature *)
	CmpLegacy* = 1; 			(** AMD: Core multi-processing legacy mode *)
	LahfSahf* = 0; 				(** LAHF & SAHF instruction support in 64-bit mode *)

	(** CpuInformation.powerManagement encoding (AMD) *)
	AMD7_TscInvariant* = 8;		(** TSC rate is ensured to be invariant across all P-States, C-States and stop-grant transitions *)
	AMD7_STC* = 5;				(** Software Thermal Control is supported *)
	AMD7_TM* = 4;				(** Hardware Thermal Control is supported *)
	AMD7_TTP* = 3;				(** THERMTRIP is supported *)
	AMD7_VID* = 2;				(** Voltage ID control is supported *)
	AMD7_FID* = 1;				(** Frequency ID control is supported *)
	AMD7_TS* = 0;				(** Temperature sensor *)

TYPE

	CpuInformation* = RECORD

		cputype- : LONGINT; (* Intel, Amd or Other *)

		(** Standard Function 0: Processor Vendor and Largest Standard Function *)
		largestStandardFunction- : LONGINT;
		vendor- : ARRAY 13 OF CHAR;

		(** Standard Function 1: Family, Model, Stepping Identifiers *)
		family-, model-, stepping- : LONGINT;
		type- : LONGINT; (* INTEL *)

		features-, features2- : SET;

		localApicId-, logicalProcessorCount- : LONGINT;
		clflushSize- : LONGINT; (* specifies the size of a cache line flushed by the CLFLUSH instruction [in bytes] *)
		brandId- : LONGINT;

		(** Extended Function 0: Largest Extended Function *)
		largestExtendedFunction- : LONGINT;

		(** Extended Function 1: Features *)
		extFeatures-, extFeatures2- : SET;

		(** Extended Function 2-4: Processor name *)
		processorName- : ARRAY 48 OF CHAR;


		(** AMD-Specific *)

		(** Level 1 Cache and TLB *)

		(** L1 2M/4M pages TLB associativity & size *)
		l1DataTlbAssociativity2M4M- : LONGINT;
		l1DataTlbSize2M4M- : LONGINT;
		l1InstrTlbAssociativity2M4M- : LONGINT;
		l1InstrTlbSize2M4M- : LONGINT;

		(** L1 4K pages TLB associativity & size *)
		l1DataTlbAssociativity4K- : LONGINT;
		l1DataTlbSize4K- : LONGINT;
		l1InstrTlbAssociativity4K- : LONGINT;
		l1InstrTlbSize4K- : LONGINT;

		(** L1 data cache characteristics *)
		l1DcSize- : LONGINT; (* KB *)
		l1DcAssociativity- : LONGINT;
		l1DcLinesPerTag- : LONGINT; (* AMD *)
		l1DcLineSize- : LONGINT;

		(** L1 instruction  cache characteristics *)
		l1IcSize- : LONGINT; (* KB *)
		l1IcAssociativity- : LONGINT;
		l1IcLinesPerTag- : LONGINT; (* AMD *)
		l1IcLineSize- : LONGINT;

		(** Level 2 Cache and TLB *)

		unifiedTlb- : BOOLEAN; (* if TRUE, one TLB for all  4K/2M/4M pages *)

		(** L2 2M/4M pages TLB associativity & size *)
		l2DataTlbAssociativity2M4M- : LONGINT;
		l2DataTlbSize2M4M- : LONGINT;
		l2InstrTlbAssociativity2M4M- : LONGINT;
		l2InstrTlbSize2M4M- : LONGINT;

		(** L2 4K pages TLB associativity & size *)
		l2DataTlbAssociativity4K- : LONGINT;
		l2DataTlbSize4K- : LONGINT;
		l2InstrTlbAssociativity4K- : LONGINT;
		l2InstrTlbSize4K- : LONGINT;

		l2CacheSize- : LONGINT; (* KB *)
		l2Associativity- : LONGINT; (* encoded *)
		l2LinesPerTag- : LONGINT; (* AMD *)
		l2LineSize- : LONGINT;

		(** Extended function 7: Advanced Power Management Information *)
		powerManagement- : SET; (* AMD *)

		(** Extended function 8: Long Mode Address Size Identifiers *)
		linAddrSize- : LONGINT; (* maximum linear byte address size in bits *)
		physAddrSize- : LONGINT; (* maximum physical byte address size in bits *)
		apicIdCoreIdSize- : LONGINT; (* AMD *)
		numberOfCores- : LONGINT; (* AMD *)

		(** Extended function A: SVM Revision and Feature Identification *)
		svmRev- : LONGINT; (* AMD *)
		nasid- : LONGINT; (** AMD: Number of address space identifiers *)

	END;

(** CPU identification *)
PROCEDURE CPUID(function : LONGINT; VAR eax, ebx, ecx, edx : SET);
CODE {SYSTEM.i386, SYSTEM.Pentium}
	MOV EAX, [EBP+function]	; CPUID function parameter
	MOV ESI, [EBP+ecx]   	; required for INTEL standard function4.
	MOV ECX, [ESI]
	CPUID					; execute CPUID
	MOV ESI, [EBP+eax]		; copy EAX into eax
	MOV [ESI], EAX
	MOV ESI, [EBP+ebx]		; copy EBX into ebx
	MOV [ESI], EBX
	MOV ESI, [EBP+ecx]		; copy ECX into ecx
	MOV [ESI], ECX
	MOV ESI, [EBP+edx]		; copy EDX into edx
	MOV [ESI], EDX
END CPUID;

(* If the CPUID instruction is supported, the ID flag (bit 21) of the EFLAGS register is r/w *)
PROCEDURE CpuIdSupported() : BOOLEAN;
CODE {SYSTEM.i386}
	PUSHFD					; save EFLAGS
	POP EAX				; store EFLAGS in EAX
	MOV EBX, EAX			; save EBX for later testing
	XOR EAX, 00200000H	; toggle bit 21
	PUSH EAX				; push to stack
	POPFD					; save changed EAX to EFLAGS
	PUSHFD					; push EFLAGS to TOS
	POP EAX				; store EFLAGS in EAX
	CMP EAX, EBX			; see if bit 21 has changed
	SETNE AL;				; return TRUE if bit 21 has changed, FALSE otherwise
END CpuIdSupported;

(* Standard Function 0: Processor Vendor and Largest Standard Function Number *)
PROCEDURE StandardFunction0(VAR cpuInfo: CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(0H, eax, ebx, ecx, edx);
	cpuInfo.largestStandardFunction := SYSTEM.VAL(LONGINT, eax);
	GetString(cpuInfo.vendor, 0, ebx);
	GetString(cpuInfo.vendor, 4, edx);
	GetString(cpuInfo.vendor, 8, ecx);
	cpuInfo.vendor[12] := 0X;
	IF cpuInfo.vendor = "GenuineIntel" THEN cpuInfo.cputype := Intel;
	ELSIF cpuInfo.vendor = "AuthenticAMD" THEN cpuInfo.cputype := Amd;
	ELSE cpuInfo.cputype := Other;
	END;
END StandardFunction0;

(* Standard Function 1: Family, Model, Stepping Identifiers *)
PROCEDURE StandardFunction1(VAR cpuInfo : CpuInformation);
CONST
	ExtendedFamily = {20..27}; ExtendedModel = {16..19};
	BaseFamily = {8..11}; BaseModel = {4..7}; BaseStepping = {0..3};
	LocalApicId = {24..31}; LogicalProcessorCount = {16..23}; CLFlush = {8..15}; BrandId = {0..7};
VAR
	eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(1H, eax, ebx, ecx, edx);
	(* EAX *)
	cpuInfo.stepping := SYSTEM.VAL(LONGINT, eax * BaseStepping);
	cpuInfo.model := SYSTEM.VAL(LONGINT, LSH(eax * BaseModel, -4));
	cpuInfo.family := SYSTEM.VAL(LONGINT, LSH(eax * BaseFamily, -8));
	IF cpuInfo.family < 0FH THEN
		cpuInfo.family := cpuInfo.family + SYSTEM.VAL(LONGINT, LSH(eax * ExtendedFamily, -20));
		cpuInfo.model := cpuInfo.model + SYSTEM.VAL(LONGINT, LSH(eax * ExtendedModel, -12));
	END;
	(* EBX *)
	cpuInfo.localApicId := SYSTEM.VAL(LONGINT, LSH(ebx * LocalApicId, -24));
	cpuInfo.logicalProcessorCount := SYSTEM.VAL(LONGINT, LSH(ebx * LogicalProcessorCount, - 16));
	cpuInfo.clflushSize := SYSTEM.VAL(LONGINT, LSH(ebx * CLFlush, -8)) * 8;
	cpuInfo.brandId := SYSTEM.VAL(LONGINT, ebx * BrandId);
	(* ECX *)
	cpuInfo.features2 := ecx;
	(* EDX *)
	cpuInfo.features := edx;

	IF cpuInfo.cputype = Intel THEN
		cpuInfo.type := SYSTEM.VAL(LONGINT, LSH(edx * {12..13}, -12));
	END;
END StandardFunction1;

(** INTEL: Standard Function 4: deterministic cache parameters
Cache Type: eax*{0..4}
0 = Null, no more caches
1 = Data Cache
2 = Instruction Cache
3 = Unified Cache
4-31 = Reserved
*)
PROCEDURE IntelStandardFunction4(wr: Streams.Writer );
  VAR
	eax, ebx, ecx, edx : SET;
	cores, threads, cachelevel, cachetype: LONGINT;
	 selfinit, fullassoc, waysofassoc, physlinepart, syscoherline,  numofsets, prefetchstride: LONGINT;
	cachesize: LONGINT;
	k: LONGINT;
BEGIN
 k := 0;
 LOOP   (* iterate over ecx = 0,1,2,3..  until eax*{0..4}=0 *)

			ecx := SYSTEM.VAL(SET,k) ;
			CPUID(4H, eax, ebx,ecx, edx);

			cachetype := SYSTEM.VAL(LONGINT, eax *{0..4});

			IF cachetype=0 THEN EXIT; END;

			wr.String("CacheType: "); wr.Int(cachetype,0);
			IF cachetype=1 THEN wr.String(" [Data Cache]");
			ELSIF cachetype=2 THEN wr.String(" [Instruction Cache]");
			ELSIF cachetype=3 THEN wr.String(" [Unified Cache]");
			ELSIF cachetype=4 THEN wr.String(" [Reserved]");
			END;
			wr.Ln;

			cachelevel := SYSTEM.VAL(LONGINT, LSH(eax *{5..7} , -5));
			wr.String("Cache Level: "); wr.Int(cachelevel,0); wr.Ln;

			cores := SYSTEM.VAL(LONGINT, LSH(eax *{26..31}, -26)) + 1;
			threads := SYSTEM.VAL(LONGINT, LSH(eax *{14..25} , -14)) +1;

			fullassoc := SYSTEM.VAL(LONGINT, LSH(eax *{9},-9));
			selfinit := SYSTEM.VAL(LONGINT, LSH(eax *{8},-8));
			waysofassoc := SYSTEM.VAL(LONGINT, LSH(ebx *{22..31},-22)) +1;
			physlinepart := SYSTEM.VAL(LONGINT, LSH(ebx *{12..21},-12)) +1;
			syscoherline := SYSTEM.VAL(LONGINT, ebx *{0..11}) +1 ;
			numofsets := SYSTEM.VAL(LONGINT, ecx ) +1;
			prefetchstride := SYSTEM.VAL(LONGINT, edx*{0..9} );


			wr.String("Maximum number of  processor cores per package: "); wr.Int(cores,0); wr.Ln;
			wr.String("Maximum number of threads sharing this cache: "); wr.Int(threads,0); wr.Ln;

			wr.String("Full Associative cache: ");	 wr.Int(fullassoc,0); wr.Ln;
			wr.String("Self initializing cache: "); wr.Int(selfinit,0); wr.Ln;

			wr.String("Ways of associativity: "); wr.Int(waysofassoc,0); wr.Ln;
			wr.String("Physical line partitions: "); wr.Int(physlinepart,0); wr.Ln;
			wr.String("System coherency line: "); wr.Int(syscoherline,0); wr.Ln;
			wr.String("Number of sets: "); wr.Int(numofsets,0); wr.Ln;
			wr.String("Prefetch stride: "); wr.Int(prefetchstride,0); wr.Ln;

			cachesize:= waysofassoc * physlinepart * syscoherline * numofsets;

			wr.String("This Cache Size (Bytes) : "); wr.Int(cachesize,0); wr.Ln;
			wr.String("****************************"); wr.Ln;
			wr.Update;
			INC(k);
 END;
END IntelStandardFunction4;

(**  INTEL: MONITOR/ MWAIT  Parameters *)
PROCEDURE IntelStandardFunction5(w: Streams.Writer);
VAR
  eax, ebx, ecx, edx : SET;
  smallestMon, largestMon : LONGINT;
  supporttreatingInterrup, supportMonMwait: BOOLEAN;
  numofC0, numofC1, numofC2, numofC3, numofC4: LONGINT;

BEGIN

CPUID(5H, eax, ebx,ecx, edx);

smallestMon := SYSTEM.VAL(LONGINT, eax*{0..15});
largestMon := SYSTEM.VAL(LONGINT, ebx*{0..15} );

supporttreatingInterrup := SYSTEM.VAL(BOOLEAN,LSH(ecx*{1},-1));
supportMonMwait :=  SYSTEM.VAL(BOOLEAN,ecx*{0});

numofC4 := SYSTEM.VAL(LONGINT,LSH(edx*{16..19},-16));
numofC3 := SYSTEM.VAL(LONGINT,LSH(edx*{12..15},-12));
numofC2 := SYSTEM.VAL(LONGINT,LSH(edx*{8..11},-8));
numofC1 := SYSTEM.VAL(LONGINT,LSH(edx*{4..7},-4));
numofC0 := SYSTEM.VAL(LONGINT, edx*{0..3});

w.String("Smallest Monitor size (bytes) = "); w.Int(smallestMon, 0 ); w.Ln;
w.String("Largest Monitor size (bytes) = "); w.Int(largestMon, 0 ); w.Ln;

w.String("Support treating Interrupt as break-events for MOITOR/MWAIT : ");
IF supporttreatingInterrup THEN  w.String("TRUE") ELSE w.String("FALSE") END;
 w.Ln;

 w.String(" MOITOR/MWAIT extensions supported : ");
 IF supportMonMwait THEN w.String("TRUE") ELSE w.String("FALSE") END;
 w.Ln;

w.String(" Number of C4 sub states supported : "); w.Int(numofC4, 0); w.Ln;
w.String(" Number of C3 sub states supported : "); w.Int(numofC3, 0); w.Ln;
w.String(" Number of C2 sub states supported : "); w.Int(numofC2, 0); w.Ln;
w.String(" Number of C1 sub states supported : "); w.Int(numofC1, 0); w.Ln;
w.String(" Number of C0 sub states supported : "); w.Int(numofC0, 0); w.Ln;

 w.Update;

END IntelStandardFunction5;

(**  INTEL: Digital Termal Sensor and Power Management Parameters *)
PROCEDURE IntelStandardFunction6(w: Streams.Writer);
VAR
  eax, ebx, ecx, edx : SET;
 digitalTermalSensorCapabilitiy: LONGINT;
  numberofInterruptThreshold: LONGINT;
  hardwareCoordFeedbackCap: LONGINT;
BEGIN

CPUID(6H, eax, ebx,ecx, edx);

digitalTermalSensorCapabilitiy := SYSTEM.VAL(LONGINT, eax*{0});
numberofInterruptThreshold := SYSTEM.VAL(LONGINT, ebx*{0..3} );
hardwareCoordFeedbackCap := SYSTEM.VAL(LONGINT, ecx*{0});
w.String("Digital termal Sensor Capabilitiy = "); w.Int(digitalTermalSensorCapabilitiy,0 ); w.Ln;
w.String("Number of Interrupt Thresholds = "); w.Int(numberofInterruptThreshold,0 ); w.Ln;
w.String("Hardware Coordination  Feedback Capablity = "); w.Int(hardwareCoordFeedbackCap,0 ); w.Ln;
w.Update;
END IntelStandardFunction6;

(**  INTEL: Direct Cache Access (DCA) Parameters *)
PROCEDURE IntelStandardFunction9(w: Streams.Writer);
VAR
  eax, ebx, ecx, edx : SET;
BEGIN
CPUID(9H, eax, ebx,ecx, edx);
w.String("Value of PLATFORM_DCA_CAP MSR Bits : "); w.Set(eax); w.Ln;
(* w.String("ebx: RESERVED: "); w.Set(ebx); w.Ln;
w.String("ecx: RESERVED: "); w.Set(ecx); w.Ln;
w.String("edx: RESERVED: "); w.Set(edx); w.Ln;
*)
w.Update;
END IntelStandardFunction9;

(**  INTEL: Architectural Performance Monitor Features *)
PROCEDURE IntelStandardFunction0A(w: Streams.Writer);
VAR
  eax, ebx, ecx, edx : SET;

 lenEBX: LONGINT;
  bitwidthCounter: LONGINT;
  numberofCountCore: LONGINT;
  verID: LONGINT;
  brachMispredict: LONGINT;
  branchInstruct: LONGINT;
  cacheMisses: LONGINT;
  cacheReference: LONGINT;
  referenceCycle: LONGINT;
  instructionRetired: LONGINT;
  CoreCycle: LONGINT;
  bitwidthFunction: LONGINT;
  numberofFunction: LONGINT;

BEGIN
CPUID(0AH, eax, ebx,ecx, edx);

lenEBX := SYSTEM.VAL(LONGINT, LSH(eax * {24..31}, -24));
bitwidthCounter:=SYSTEM.VAL(LONGINT, LSH(eax * {16..23}, -16));
numberofCountCore:=SYSTEM.VAL(LONGINT, LSH(eax * {8..15}, -8));
verID := SYSTEM.VAL(LONGINT,eax*{0..7});
brachMispredict:=SYSTEM.VAL(LONGINT,LSH(ebx*{6},-6) );
branchInstruct:=SYSTEM.VAL(LONGINT,LSH(ebx*{5},-5) );
cacheMisses:=SYSTEM.VAL(LONGINT,LSH(ebx*{4},-4) );
cacheReference := SYSTEM.VAL(LONGINT,LSH(ebx*{3},-3) );
referenceCycle := SYSTEM.VAL(LONGINT,LSH(ebx*{2},-2) );
instructionRetired := SYSTEM.VAL(LONGINT,LSH(ebx*{1},-1) );
CoreCycle := SYSTEM.VAL(LONGINT,ebx*{0} );
bitwidthFunction := SYSTEM.VAL(LONGINT,LSH(ecx*{5..12},-5) );
numberofFunction :=SYSTEM.VAL(LONGINT,ecx*{0..4} );

w.String("Length of EBX bit vector  = "); w.Int(lenEBX ,0 ); w.Ln;
w.String("Bit width of counter = "); w.Int(bitwidthCounter,0 ); w.Ln;
w.String("Number of counter per logical processor = "); w.Int(numberofCountCore,0 );w.Ln;
w.String("Version ID = "); w.Int(verID ,0 );w.Ln;

w.String("Branch mispredict retired event = "); w.Int(brachMispredict,0 );w.Ln;
w.String("Branch Instruction retired event = "); w.Int(branchInstruct,0 );w.Ln;
w.String("Last-level cache misses event = "); w.Int(cacheMisses,0 );w.Ln;
w.String("Last-level cache reference event = "); w.Int(cacheReference ,0 );w.Ln;
w.String("Reference cycles event = "); w.Int(referenceCycle ,0 );w.Ln;
w.String("Instruction retired event = "); w.Int(instructionRetired ,0 );w.Ln;
w.String("Core cycle event = "); w.Int(CoreCycle ,0 );w.Ln;
w.String("Bit width of fixed-function performance counters = "); w.Int(bitwidthFunction ,0 );w.Ln;
w.String("Number of fixed-function performance counters ="); w.Int(numberofFunction ,0 );w.Ln;

w.Update;

END IntelStandardFunction0A;

PROCEDURE ExtendedFunction0(VAR cpuInfo : CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	eax := {};
	CPUID(LONGINT(80000000H), eax, ebx, ecx, edx);
	(* The largest extended function as value from offset 8000000H. Since we don't have unsigned integers, ignore the MSB *)
	cpuInfo.largestExtendedFunction := SYSTEM.VAL(LONGINT, eax - {31});
	(* ebx, ecx & edx contain the same information as in standard function 0 *)
END ExtendedFunction0;

PROCEDURE ExtendedFunction1(VAR cpuInfo : CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(LONGINT(80000001H), eax, ebx, ecx, edx);
	(* eax contains the same information as in standard function 1 *)
	(* ebx: brandid, ignore so far*)
	cpuInfo.extFeatures2 := ecx;
	cpuInfo.extFeatures := edx;
END ExtendedFunction1;

PROCEDURE ExtendedFunction2to4(VAR cpuInfo : CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(LONGINT(80000002H), eax, ebx, ecx, edx);
	GetString(cpuInfo.processorName, 0, eax);
	GetString(cpuInfo.processorName, 4, ebx);
	GetString(cpuInfo.processorName, 8, ecx);
	GetString(cpuInfo.processorName, 12, edx);
	IF cpuInfo.largestExtendedFunction < 3 THEN RETURN END;
	CPUID(LONGINT(80000003H), eax, ebx, ecx, edx);
	GetString(cpuInfo.processorName, 16, eax);
	GetString(cpuInfo.processorName, 20, ebx);
	GetString(cpuInfo.processorName, 24, ecx);
	GetString(cpuInfo.processorName, 28, edx);
	IF cpuInfo.largestExtendedFunction < 4 THEN RETURN END;
	CPUID(LONGINT(80000004H), eax, ebx, ecx, edx);
	GetString(cpuInfo.processorName, 32, eax);
	GetString(cpuInfo.processorName, 36, ebx);
	GetString(cpuInfo.processorName, 40, ecx);
	GetString(cpuInfo.processorName, 44, edx);
END ExtendedFunction2to4;

PROCEDURE AmdExtendedFunction5(VAR cpuInfo : CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(LONGINT(80000005H), eax, ebx, ecx, edx);
	(* EAX *)
	cpuInfo.l1DataTlbAssociativity2M4M := SYSTEM.VAL(LONGINT, LSH(eax * {24..31}, -24));
	cpuInfo.l1DataTlbSize2M4M := SYSTEM.VAL(LONGINT, LSH(eax * {16..23}, -16));
	cpuInfo.	l1InstrTlbAssociativity2M4M := SYSTEM.VAL(LONGINT, LSH(eax * {8..15}, -8));
	cpuInfo.	l1InstrTlbSize2M4M := SYSTEM.VAL(LONGINT, eax * {0..7});
	(* EBX *)
	cpuInfo.l1DataTlbAssociativity4K := SYSTEM.VAL(LONGINT, LSH(ebx * {24..31}, -24));
	cpuInfo.l1DataTlbSize4K := SYSTEM.VAL(LONGINT, LSH(ebx * {16..23}, -16));
	cpuInfo.l1InstrTlbAssociativity4K := SYSTEM.VAL(LONGINT, LSH(ebx * {8..15}, -8));
	cpuInfo.l1InstrTlbSize4K := SYSTEM.VAL(LONGINT, ebx * {0..7});
	(* ECX *)
	cpuInfo.l1DcSize := SYSTEM.VAL(LONGINT, LSH(ecx * {24..31}, -24));
	cpuInfo.l1DcAssociativity := SYSTEM.VAL(LONGINT, LSH(ecx * {16..23}, -16));
	cpuInfo.l1DcLinesPerTag := SYSTEM.VAL(LONGINT, LSH(ecx * {8..15}, -8));
	cpuInfo.l1DcLineSize := SYSTEM.VAL(LONGINT, ecx * {0..7});
	(* EDX *)
	cpuInfo.l1IcSize := SYSTEM.VAL(LONGINT, LSH(edx * {24..31}, -24));
	cpuInfo.l1IcAssociativity := SYSTEM.VAL(LONGINT, LSH(edx * {16..23}, -16));
	cpuInfo.l1IcLinesPerTag := SYSTEM.VAL(LONGINT, LSH(edx * {8..15}, -8));
	cpuInfo.l1IcLineSize := SYSTEM.VAL(LONGINT, edx * {0..7});
END AmdExtendedFunction5;

(** AMD: L2 Cache and TLB Identifiers *)
PROCEDURE AmdExtendedFunction6(VAR cpuInfo : CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(LONGINT(80000006H), eax, ebx, ecx, edx);
	cpuInfo.unifiedTlb := (eax * {16..31} = {}) & (ebx * {16..31} = {});

	IF ~cpuInfo.unifiedTlb THEN
		cpuInfo.l2DataTlbAssociativity2M4M := SYSTEM.VAL(LONGINT, LSH(eax * {28..31}, -28));
		cpuInfo.l2DataTlbSize2M4M := SYSTEM.VAL(LONGINT, LSH(eax * {16..27}, -16));
		cpuInfo.l2InstrTlbAssociativity2M4M := SYSTEM.VAL(LONGINT, LSH(eax * {12..15}, -12));
		cpuInfo.l2InstrTlbSize2M4M := SYSTEM.VAL(LONGINT, eax * {0..11});
	END;

	cpuInfo.l2DataTlbAssociativity4K := SYSTEM.VAL(LONGINT, LSH(ebx * {28..31}, -28));
	cpuInfo.l2DataTlbSize4K := SYSTEM.VAL(LONGINT, LSH(ebx * {16..27}, -16));
	cpuInfo.l2InstrTlbAssociativity4K := SYSTEM.VAL(LONGINT, LSH(ebx * {12..15}, -12));
	cpuInfo.l2InstrTlbSize4K := SYSTEM.VAL(LONGINT, ebx * {0..11});

	cpuInfo.l2CacheSize := SYSTEM.VAL(LONGINT, LSH(ecx * {16..31}, -16));
	cpuInfo.l2Associativity := SYSTEM.VAL(LONGINT, LSH(ecx * {12..15}, -12));
	cpuInfo.l2LinesPerTag := SYSTEM.VAL(LONGINT, LSH(ecx * {8..11}, -8));
	cpuInfo.l2LineSize := SYSTEM.VAL(LONGINT, ecx * {0..7});
END AmdExtendedFunction6;

(* INTEL: Extended L2 Cache Features *)
PROCEDURE IntelExtendedFunction6(VAR cpuInfo : CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(LONGINT(80000006H), eax, ebx, ecx, edx);
	cpuInfo.l2CacheSize := SYSTEM.VAL(LONGINT, LSH(ecx * {16..31}, -16));
	cpuInfo.l2Associativity := SYSTEM.VAL(LONGINT, LSH(ecx * {12..15}, -12));
	cpuInfo.l2LineSize := SYSTEM.VAL(LONGINT, ecx * {0..7});
END IntelExtendedFunction6;

(* AMD: Advanced Power Management Information *)
PROCEDURE AmdExtendedFunction7(VAR cpuInfo : CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(LONGINT(80000007H), eax, ebx, ecx, edx);
	cpuInfo.powerManagement := edx;
END AmdExtendedFunction7;

(* Long Mode Address Size Identifiers *)
PROCEDURE ExtendedFunction8(VAR cpuInfo : CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(LONGINT(80000008H), eax, ebx, ecx, edx);
	cpuInfo.linAddrSize := SYSTEM.VAL(LONGINT, LSH(eax * {8..15}, -8));
	cpuInfo.physAddrSize := SYSTEM.VAL(LONGINT, eax * {0..7});
	IF cpuInfo.cputype = Amd THEN
		cpuInfo.apicIdCoreIdSize := SYSTEM.VAL(LONGINT, LSH(ecx * {12..15}, -12));
		cpuInfo.numberOfCores := SYSTEM.VAL(LONGINT, ecx * {0..7}) + 1;
	END;
END ExtendedFunction8;

(* AMD: SVM Revision and Feature Identification *)
PROCEDURE AmdExtendedFunctionA(VAR cpuInfo : CpuInformation);
VAR eax, ebx, ecx, edx : SET;
BEGIN
	CPUID(LONGINT(8000000AH), eax, ebx, ecx, edx);
	cpuInfo.svmRev := SYSTEM.VAL(LONGINT, eax * {0..7});
	cpuInfo.nasid := SYSTEM.VAL(LONGINT, ebx);
END AmdExtendedFunctionA;

PROCEDURE GetString(VAR string : ARRAY OF CHAR; offset : LONGINT; register : SET);
BEGIN
	string[offset] :=CHR(SYSTEM.VAL(LONGINT, register * {0..7}));
	string[offset+1] := CHR(SYSTEM.VAL(LONGINT, LSH(register * {8..15}, -8)));
	string[offset+2] := CHR(SYSTEM.VAL(LONGINT, LSH(register * {16..23}, -16)));
	string[offset+3] := CHR(SYSTEM.VAL(LONGINT, LSH(register * {24..31}, -24)));
END GetString;

PROCEDURE GetCpuInformation(VAR cpuInfo : CpuInformation);
BEGIN
	StandardFunction0(cpuInfo);
	IF cpuInfo.largestStandardFunction >= 1 THEN StandardFunction1(cpuInfo); END;
	ExtendedFunction0(cpuInfo);
	IF cpuInfo.largestExtendedFunction >= 1 THEN
		ExtendedFunction1(cpuInfo);
		IF cpuInfo.largestExtendedFunction >= 2 THEN
			ExtendedFunction2to4(cpuInfo);
			IF cpuInfo.largestExtendedFunction >= 5 THEN
				IF cpuInfo.cputype = Amd THEN AmdExtendedFunction5(cpuInfo); END;
				IF cpuInfo.largestExtendedFunction >= 6 THEN
					IF cpuInfo.cputype = Amd THEN
						AmdExtendedFunction6(cpuInfo);
					ELSE
						IntelExtendedFunction6(cpuInfo);
					END;

					IF cpuInfo.largestExtendedFunction >= 7 THEN
						IF cpuInfo.cputype = Amd THEN AmdExtendedFunction7(cpuInfo); END;
						IF cpuInfo.largestExtendedFunction >= 8 THEN
							ExtendedFunction8(cpuInfo);
							IF cpuInfo.largestExtendedFunction >= 0AH THEN
								IF cpuInfo.cputype = Amd THEN AmdExtendedFunctionA(cpuInfo); END;
							END;
						END;
					END;
				END;
			END;
		END;
	END;
END GetCpuInformation;

PROCEDURE ShowExtFeatures2Amd(w : Streams.Writer; register : SET);
BEGIN
	IF AltMovCr8 IN register THEN w.String("[AltMovCR8]"); END;
	IF SVM IN register THEN w.String("[SVM]"); END;
	IF CmpLegacy IN register THEN w.String("[CMP legacy]"); END;
	IF LahfSahf IN register THEN w.String("[LahfSahf]"); END;
END ShowExtFeatures2Amd;

PROCEDURE ShowExtFeaturesAmd(w : Streams.Writer; register : SET);
BEGIN
	IF Amd3DNow IN register THEN w.String("[3DNow!]"); END;
	IF Amd3DNowExt IN register THEN w.String("[3DNow!Ext]"); END;
	IF LM IN register THEN w.String("[LongMode]"); END;
	IF RDTSCP IN register THEN w.String("[RDTSCP]"); END;
	IF FFXSR IN register THEN w.String("[FFXSR]"); END;
	IF MmxExt IN register THEN w.String("[MMXExt]"); END;
	IF NX IN register THEN w.String("[NX]"); END;
	IF SysCallSysRet IN register THEN w.String("[SysCallSysRet]"); END;
END ShowExtFeaturesAmd;

PROCEDURE ShowPowerManagementAmd(w : Streams.Writer; register : SET);
BEGIN
	IF AMD7_TscInvariant IN register THEN w.String("[TSCInvariant]"); END;
	IF AMD7_STC IN register THEN w.String("[STC]"); END;
	IF AMD7_TM IN register THEN w.String("[TM]"); END;
	IF AMD7_TTP IN register THEN w.String("[TTP]"); END;
	IF AMD7_VID IN register THEN w.String("[VID]"); END;
	IF AMD7_FID IN register THEN w.String("[FID]"); END;
	IF AMD7_TS IN register THEN w.String("[TS]"); END;
END ShowPowerManagementAmd;

PROCEDURE ShowLongModeAS(w : Streams.Writer; cpuInfo : CpuInformation);
BEGIN
	w.String("   Maximum linear byte address size: "); w.Int(cpuInfo.linAddrSize, 0); w.String(" bits"); w.Ln;
	w.String("   Maximum physical byte address size: "); w.Int(cpuInfo.physAddrSize, 0); w.String(" bits"); w.Ln;
	IF cpuInfo.cputype = Amd THEN
		w.String("   APIC ID Core ID Size: "); w.Int(cpuInfo.apicIdCoreIdSize, 0); w.String(" bits"); w.Ln;
		w.String("   Number of CPU cores: "); w.Int(cpuInfo.numberOfCores, 0);
	END;
END ShowLongModeAS;

PROCEDURE ShowFeatures2(w : Streams.Writer; register : SET);
BEGIN
	IF DCA IN register THEN w.String("[DCA]"); END; (* INTEL *)
	IF XTPR IN register THEN w.String("[xTPR]"); END; (* INTEL *)
	IF CMPXCHG16B IN register THEN w.String("[CMPXCHG16B]"); END;
	IF CID IN register THEN w.String("[CID]"); END; (* INTEL *)
	IF SSSE3 IN register THEN w.String("[SSSE3]"); END; (* INTEL *)
	IF TM2 IN register THEN w.String("[TM2]"); END; (* INTEL *)
	IF EST IN register THEN w.String("[EST]"); END; (* INTEL *)
	IF VMX IN register THEN w.String("[VMX]"); END; (* INTEL *)
	IF DS_CPL IN register THEN w.String("[DS_CPL]"); END; (* INTEL *)
	IF MONITOR IN register THEN w.String("[MONITOR]"); END; (* INTEL *)
	IF SSE3 IN register THEN w.String("[SSE3]"); END;
	IF DTES64 IN register THEN w.String("[DTES64]"); END;  (* INTEL *)
	IF SSE4_2 IN register THEN w.String("[SSE4_2]"); END;  (* INTEL *)
	IF SSE4_1 IN register THEN w.String("[SSE4_1]"); END; (* INTEL *)
	IF PDCM IN register THEN w.String("[PDCM]"); END; (* INTEL *)
	IF SMX IN register THEN w.String("[SMX]"); END; (* INTEL *)
END ShowFeatures2;

PROCEDURE ShowFeatures(w : Streams.Writer; register : SET);
BEGIN
	IF PBE IN register THEN w.String("[PBE]"); END; (* INTEL *)
	IF IA64 IN register THEN w.String("[IA64]"); END; (* INTEL *)
	IF TM IN register THEN w.String("[TM]"); END; (* INTEL *)
	IF HTT IN register THEN w.String("[HTT]"); END;
	IF SS IN register THEN w.String("[SelfSnoop]"); END; (* INTEL *)
	IF SSE2 IN register THEN w.String("[SSE2]"); END;
	IF SSE IN register THEN w.String("[SSE]"); END;
	IF FXSR IN register THEN w.String("[FXSR]"); END;
	IF MMX IN register THEN w.String("[MMX]"); END;
	IF ACPI IN register THEN w.String("[ACPI]"); END; (* INTEL *)
	IF DS IN register THEN w.String("[DebugStore]"); END; (* INTEL *)
	IF CLFLUSH IN register THEN w.String("[CLFLUSH]"); END;
	IF PSN IN register THEN w.String("[ProcessorSerialNumber]"); END; (* INTEL *)
	IF PSE36 IN register THEN w.String("[PSE36]"); END;
	IF PAT IN register THEN w.String("[PAT]"); END;
	IF CMOV IN register THEN w.String("[CMOV]"); END;
	IF MCA IN register THEN w.String("[MCA]"); END;
	IF PGE IN register THEN w.String("[PGE]"); END;
	IF MTRR IN register THEN w.String("[MTRR]"); END;
	IF SysEnterSysExit IN register THEN w.String("[SysEnterSysExit]"); END;
	IF APIC IN register THEN w.String("[APIC]"); END;
	IF CMPXCH8B IN register THEN w.String("[CMPXCH8B]"); END;
	IF MCE IN register THEN w.String("[MCE]"); END;
	IF PAE IN register THEN w.String("[PAE]"); END;
	IF MSR IN register THEN w.String("[MSR]"); END;
	IF TSC IN register THEN w.String("[TSC]"); END;
	IF PSE IN register THEN w.String("[PSE]"); END;
	IF DE IN register THEN w.String("[DE]"); END;
	IF VME IN register THEN w.String("[VME]"); END;
	IF FPU IN register THEN w.String("[FPU]"); END;
END ShowFeatures;

PROCEDURE ShowL1Associativity(w : Streams.Writer; value : LONGINT);
BEGIN
	IF value = 0 THEN w.String("Reserved");
	ELSIF value = 1 THEN w.String("Direct mapped");
	ELSIF value = 0FFH THEN w.String("Fully associative");
	ELSE
		w.Int(value, 0); w.String("-way associative");
	END;
END ShowL1Associativity;

PROCEDURE ShowL2Associativity(w : Streams.Writer; value : LONGINT);
BEGIN
	IF value = 0 THEN w.String("disabled");
	ELSIF value = 1 THEN w.String("Direct mapped");
	ELSIF value = 2 THEN w.String("2-way associative");
	ELSIF value = 4 THEN w.String("4-way associative");
	ELSIF value = 6 THEN w.String("8-way associative");
	ELSIF value = 8 THEN w.String("16-way associative");
	ELSIF value = 0FH THEN w.String("Fully associative");
	ELSE w.String("unknown");
	END;
END ShowL2Associativity;

PROCEDURE AmdShowL1TlbAndCache(w : Streams.Writer; cpuInfo : CpuInformation);
BEGIN
	w.String("   TLB: "); w.Ln;
	w.String("      2M/4M Data TLB: "); w.Int(cpuInfo.l1DataTlbSize2M4M, 0); w.String(" entries, ");
	ShowL1Associativity(w, cpuInfo.l1DataTlbAssociativity2M4M);
	w.Ln;
	w.String("      2M/4M Instr TLB: "); w.Int(cpuInfo.l1InstrTlbSize2M4M, 0); w.String(" entries, ");
	ShowL1Associativity(w, cpuInfo.l1InstrTlbAssociativity2M4M);
	w.Ln;
	w.String("      4K Data TLB: "); w.Int(cpuInfo.l1DataTlbSize4K, 0); w.String(" entries, ");
	ShowL1Associativity(w, cpuInfo.l1DataTlbAssociativity4K);
	w.Ln;
	w.String("      4K Instr TLB: ");  w.Int(cpuInfo.l1InstrTlbSize4K, 0); w.String(" entries, ");
	ShowL1Associativity(w, cpuInfo.l1InstrTlbAssociativity4K);
	w.Ln;
	w.String("   Level 1 cache: "); w.Ln;
	w.String("      Data: "); w.Int(cpuInfo.l1DcSize, 0); w.String("KB, "); ShowL1Associativity(w, cpuInfo.l1DcAssociativity);
	w.String(", Lines per Tag: "); w.Int(cpuInfo.l1DcLinesPerTag, 0); w.String(", Line size: "); w.Int(cpuInfo.l1DcLineSize, 0);
	w.String(" Bytes");
	w.Ln;
	w.String("      Instr: "); w.Int(cpuInfo.l1IcSize, 0); w.String("KB, "); ShowL1Associativity(w, cpuInfo.l1IcAssociativity);
	w.String(", Lines per Tag: "); w.Int(cpuInfo.l1IcLinesPerTag, 0);
	w.String(", Line size: "); w.Int(cpuInfo.l1IcLineSize, 0); w.String(" Bytes");
END AmdShowL1TlbAndCache;

PROCEDURE AmdShowL2TlbAndCache(w : Streams.Writer; cpuInfo : CpuInformation);
BEGIN
	w.String("   TLB: "); w.Ln;
	IF ~cpuInfo.unifiedTlb THEN
		w.String("      2M/4M Data TLB: "); w.Int(cpuInfo.l2DataTlbSize2M4M, 0); w.String(" entries, ");
		ShowL2Associativity(w, cpuInfo.l2DataTlbAssociativity2M4M);
		w.Ln;
		w.String("      2M/4M Instr TLB: "); w.Int(cpuInfo.l2InstrTlbSize2M4M, 0); w.String(" entries, ");
		ShowL2Associativity(w, cpuInfo.l2InstrTlbAssociativity2M4M);
		w.Ln;
	ELSE
		w.String("Unified TLB for 4K/2M/4M: "); w.Ln;
	END;
	w.String("      4K Data TLB: "); w.Int(cpuInfo.l2DataTlbSize4K, 0); w.String(" entries, ");
	ShowL2Associativity(w, cpuInfo.l2DataTlbAssociativity4K);
	w.Ln;
	w.String("      4K Instr TLB: "); w.Int(cpuInfo.l2InstrTlbSize4K, 0); w.String(" entries, ");
	ShowL2Associativity(w, cpuInfo.l2InstrTlbAssociativity4K);
	w.Ln;
	w.String("   Level 2 cache: "); w.Ln;
	w.String("      Size: "); w.Int(cpuInfo.l2CacheSize, 0); w.String("KB, ");
	ShowL2Associativity(w, cpuInfo.l2Associativity);
	IF cpuInfo.cputype = Amd THEN
		w.String(", Lines per Tag: "); w.Int(cpuInfo.l2LinesPerTag, 0);
	END;
	w.String(", Line size: "); w.Int(cpuInfo.l2LineSize, 0); w.String(" Bytes");
END AmdShowL2TlbAndCache;

PROCEDURE AmdShowSVM(w : Streams.Writer; cpuInfo : CpuInformation);
BEGIN
	w.String("   SVM Revision: "); w.Hex(cpuInfo.svmRev, -2); w.String("H"); w.Ln;
	w.String("   Number of address space identifiers (ASID): "); w.Int(cpuInfo.nasid, 0); w.Ln;
END AmdShowSVM;

PROCEDURE IntelShowCacheDescriptors(w : Streams.Writer);
VAR eax, ebx, ecx, edx : SET; i : LONGINT;

	PROCEDURE ShowReg(reg : SET; isEax : BOOLEAN);
	VAR s: ARRAY 128 OF CHAR;
	BEGIN
		IF ~(31 IN reg )THEN
			IF ~isEax THEN
				IF reg * {0..7} # {} THEN GetCacheIntel(w, SYSTEM.VAL(LONGINT, reg * {0..7}), s); w.String(s); w.Ln; END;
			END;
			IF reg * {8..15} # {} THEN GetCacheIntel(w, SYSTEM.VAL(LONGINT, LSH(reg * {8..15},-8)), s); w.String(s); w.Ln; END;
			IF reg * {16..23} # {} THEN GetCacheIntel(w, SYSTEM.VAL(LONGINT,LSH( reg * {16..23},-16)), s); w.String(s); w.Ln; END;
			IF reg * {24..31} # {} THEN GetCacheIntel(w, SYSTEM.VAL(LONGINT, LSH(reg * {24..31},-24)), s); w.String(s); w.Ln; END;
		END;
	END ShowReg;

BEGIN
	CPUID(2H, eax, ebx, ecx, edx);
	ShowReg(eax, TRUE);
	ShowReg(ebx, FALSE);
	ShowReg(ecx, FALSE);
	ShowReg(edx, FALSE);

	i := SYSTEM.VAL(LONGINT, eax * {0..7}) - 1;

	WHILE (i > 0) DO
		CPUID(2H, eax, ebx, ecx, edx);
		ShowReg(eax, TRUE);
		ShowReg(ebx, FALSE);
		ShowReg(ecx, FALSE);
		ShowReg(edx, FALSE);
		DEC(i);
	END;
END IntelShowCacheDescriptors;

PROCEDURE GetCacheIntel*(w : Streams.Writer; value : LONGINT; VAR s:  ARRAY OF CHAR);
BEGIN
	CASE value OF
		|00H:	s := "Null";
		|01H:	s := "Instruction TLB: 4KB Pages, 4-way set associative, 32 entries";
		|02H:	s := "Instruction TLB: 4MB Pages, fully associative, 2 entries";
		|03H:	s := "Data TLB: 4KB Pages, 4-way set associative, 64 entries";
		|04H:	s := "Data TLB: 4MB Pages, 4-way set associative, 8 entries";
		|05H:	s := "DataTLB: 4MB Pages, 4-way set associative, 32 entries";
		|06H:	s := "L1 instruction cache, 8KB, 4-way set associative, 32 byte line size";
		|08H:	s := "L1 instruction cache, 16KB, 4-way set associative, 32-byte line size";
		|0AH:	s := "L1 data cache, 8KB, 2-way set associative, 32-byte line size";
		|0CH:	s := "L1 data cache, 16KB, 4-way set associative, 32-byte line size";
		|22H:	s := "L3 cache, 512KB, 4-way set associative, sectored cache, 64-byte line size";
		|23H:	s := "L3 cache, 1MB, 8-way set associative, sectored cache, 64-byte line size";
		|25H:	s := "L3 cache, 2MB, 8-way set associative, sectored cache, 64-byte line size";
		|29H:	s := "L3 cache, 4MB, 8-way set associative, sectored cache, 64-byte line size";
		|2CH:	s := "L1 data cache, 32KB, 8-way set associative, 64-byte line size";
		|30H:	s := "L1 instruction cache, 32KB, 8-way set associative, 64-byte line size";
		|39H:	s := "L2 cache, 128KB, 4-way set associative, sectored cache, 64-byte line size";
		|3AH:	s := "L2 cache, 192KB, 6-way set associative, sectored cache, 64-byte line size";
		|3BH:	s := "L2 cache, 128KB, 2-way set associative, sectored cache, 64-byte line size";
		|3CH:	s := "L2 cache, 256KB, 4-way set associative, sectored cache, 64-byte line size";
		|3DH:	s := "L2 cache, 384KB, 6-way set associative, sectored cache, 64-byte line size";
		|3EH:	s := "L2 cache, 512KB, 4-way set associative, sectored cache, 64-byte line size";
		|40H:	s := "No L2 cache or, if processor contains valid L2 cache, no L2 cache";
		|41H:	s := "L2 cache, 128KB, 4-way set associative, 32-byte line size";
		|42H:	s := "L2 cache, 256KB, 4-way set associative, 32-byte line size";
		|43H:	s := "L2 cache, 512KB, 4-way set associative, 32-byte line size";
		|44H:	s := "L2 cache, 1MB, 4-way set associative, 32-byte line size";
		|45H:	s := "L2 cache, 2MB, 4-way set associative, 32-byte line size";
		|46H:	s := "L3 cache, 4MB, 4-way set associative, 64-byte line size";
		|47H:	s := "L3 cache, 8MB, 8-way set associative, 64-byte line size";
		|49H:	s := "L2 cache, 4MB, 16-way set associative, 64-byte line size";
		|4AH:	s := "L3 cache, 6MB, 12-way set associative, 64-byte line size";
		|4BH:	s := "L3 cache, 8MB, 16-way set associative, 64-byte line size";
		|4CH:	s := "L3 cache, 12MB, 12-way set associative, 64-byte line size";
		|4DH:	s := "L3 cache, 16MB, 16-way set associative, 64-byte line size";
		|4EH:	s:="2nd-level cache: 6MB, 24-way set associative, 64-byte line size";
		|50H:	s := "Instruction TLB: 4KB, 2MB or 4MB pages, fully associative, 64 entries";
		|51H:	s := "Instruction TLB: 4KB, 2MB or 4MB pages, fully associative, 128 entries";
		|52H:	s := "Instruction TLB: 4KB, 2MB or 4MB pages, fully associative, 256 entries";
		|56H:	s := "L0 Data TLB: 4MB pages, 4-way set associative, 16 entries";
		|57H:	s := "L0 Data TLB: 4KB pages, 4-way set associative, 16 entries";
		|5BH:	s := "Data TLB: 4KB or 4MB pages, fully associative, 64 entries";
		|5CH:	s := "Data TLB: 4KB or 4MB pages, fully associative, 128 entries";
		|5DH:	s := "Data TLB: 4KB or 4MB pages, fully associative, 256 entries";
		|60H:	s := "L1 data cache, 16KB, 8-way set associative, sectored cache, 64-byte line size";
		|66H:	s := "L1 data cache, 8KB, 4-way set associative, sectored cache, 64-byte line size";
		|67H:	s := "L1 data cache, 16KB, 4-way set associative, sectored cache, 64-byte line size";
		|68H:	s := "L1 data cache, 32KB, 4-way set associative, sectored cache, 64-byte line size";
		|70H:	s := "Trace cache: 12 Kuops, 8-way set associative";
		|71H:	s := "Trace cache: 16 Kuops, 8-way set associative";
		|72H:	s := "Trace cache: 32 Kuops, 8-way set associative";
		|73H:	s := "Trace cache: 64 Kuops, 8-way set associative";
		|78H:	s := "L2 cache, 1MB, 4-way set associative, 64-byte line size";
		|79H:	s := "L2 cache, 128KB, 8-way set associative, sectored cache, 64-byte line size";
		|7AH:	s := "L2 cache, 256KB, 8-way set associative, sectored cache, 64-byte line size";
		|7BH:	s := "L2 cache, 512KB, 8-way set associative, sectored cache, 64-byte line size";
		|7CH:	s := "L2 cache, 1MB, 8-way set associative, sectored cache, 64-byte line size";
		|7DH:	s := "L2 cache, 2MB, 8-way set associative, 64-byte line size";
		|7FH:	s := "L2 cache, 512KB, 2-way set associative, 64-byte line size";
		|82H:	s := "L2 cache, 256KB, 8-way set associative, 32-byte line size";
		|83H:	s := "L2 cache, 512KB, 8-way set associative, 32-byte line size";
		|84H:	s := "L2 cache, 1MB, 8-way set associative, 32-byte line size";
		|85H:	s := "L2 cache, 2MB, 8-way set associative, 32-byte line size";
		|86H:	s := "L2 cache, 512KB, 4-way set associative, 64-byte line size";
		|87H:	s := "L2 cache, 1MB, 8-way set associative, 64-byte line size";
		|0B0H:	s := "Instruction TLB: 4KB Pages, 4-way set associative, 128 entries";
		|0B1H:	s := "Instruction TLB: 2M/4M pages, 4-way set associative, 2M: 4 entries, 4M: 8 entries";
		|0B3H:	s := "Data TLB: 4KB pages, 4-way set associative, 128 entries";
		|0B4H:	s := "Data TLB: 4KB pages, 4-way set associative, 256 entries";
		|0F0H:	s := "64-byte Prefetching";
		|0F1H:	s := "128-byte Prefetching";
	ELSE
		s := "Entry not defined";
	END;
END GetCacheIntel;

PROCEDURE IntelShowL2TlbAndCache(w : Streams.Writer; cpuInfo : CpuInformation);
BEGIN

	w.String("   Level 2 cache: "); w.Ln;
	w.String("      Size: "); w.Int(cpuInfo.l2CacheSize, 0); w.String("KB, ");
	ShowL2Associativity(w, cpuInfo.l2Associativity);
	w.String(", Line size: "); w.Int(cpuInfo.l2LineSize, 0); w.String(" Bytes"); w.Ln;
END IntelShowL2TlbAndCache;

PROCEDURE ShowDetailedCpuInformation(w : Streams.Writer; cpuInfo : CpuInformation);
BEGIN
	w.String("Standard Function 0: Processor Vendor and Largest Standard Function: "); w.Ln;
	w.String("   Vendor: "); w.String(cpuInfo.vendor); w.Ln;
	w.String("   Largest Standard Function: "); w.Int(cpuInfo.largestStandardFunction, 0); w.Ln;
	w.Ln;
	IF cpuInfo.largestStandardFunction >= 1 THEN
		w.String("Standard Function 1: Family, Model, Stepping Identifiers: "); w.Ln;
		w.String("   Family: "); w.Hex(cpuInfo.family, -2); w.String("H, Model: "); w.Hex(cpuInfo.model, -2);
		w.String("H, Stepping: "); w.Hex(cpuInfo.stepping, -2); w.Char("H");
		IF cpuInfo.cputype = Intel THEN
			w.String(", type: "); w.Int(cpuInfo.type, 0);
			CASE cpuInfo.type OF
				|0: w.String(" (Original OEM processor)");
				|1: w.String(" (OverDrive processor)");
				|2: w.String(" (Dual processor)");
				|3: w.String(" (Intel reserved)");
			ELSE
				w.String(" (Out of range)");
			END;
		END;
		w.Ln;
		w.String("   Local APIC Initial ID: "); w.Int(cpuInfo.localApicId, 0);
		w.String(", Logical processor count: "); w.Int(cpuInfo.logicalProcessorCount, 0);
		w.Ln;
		w.String("   CLFLUSH line size: "); w.Int(cpuInfo.clflushSize, 0); w.String(" Bytes");
		w.String(", BrandId: "); w.Int(cpuInfo.brandId, 0);
		w.Ln;
		w.String("   Features: "); ShowFeatures2(w, cpuInfo.features2); ShowFeatures(w, cpuInfo.features); w.Ln;
		w.Ln;
	END;

	IF (cpuInfo.largestStandardFunction >= 2) & (cpuInfo.cputype = Intel) THEN
		w.String("Standard Function 2: Cache Descriptors: "); w.Ln;
		IntelShowCacheDescriptors(w);
		w.Ln;
	END;

	IF (cpuInfo.largestStandardFunction >=4)  THEN
	     IF cpuInfo.cputype=Intel THEN
		w.String("INTEL Standard Function 4: Deterministic Cache Parameters : "); w.Ln;
			IntelStandardFunction4(w);
		w.Ln;
		END;
	END;

	IF (cpuInfo.largestStandardFunction >=5)  THEN
	     IF cpuInfo.cputype=Intel THEN
		w.String("INTEL Standard Function 5:  MONITOR/ MWAIT  Parameters  : "); w.Ln;
			IntelStandardFunction5(w);
		w.Ln;
		END;
	END;

	IF (cpuInfo.largestStandardFunction >=6)  THEN
	     IF cpuInfo.cputype=Intel THEN
		w.String("INTEL Standard Function 6: Digital Termal Sensor and Power Management Parameters : "); w.Ln;
			IntelStandardFunction6(w);
		w.Ln;
		END;
	END;

	IF (cpuInfo.largestStandardFunction >=9)  THEN
	     IF cpuInfo.cputype=Intel THEN
		w.String("INTEL: Direct Cache Access (DCA) Parameters : "); w.Ln;
			IntelStandardFunction9(w);
		w.Ln;
		END;
	END;
	IF (cpuInfo.largestStandardFunction >9)  THEN
		IF  cpuInfo.cputype=Intel THEN
		w.String("INTEL Standard Function 0A: Architectural Performance Monitor Features: "); w.Ln;
		IntelStandardFunction0A(w);
		w.Ln;
	   END;
	END;

	w.String("Extended Function 0: Largest Extended Function: "); w.Ln;
	w.String("   Largest Extended Function: "); w.Int(cpuInfo.largestExtendedFunction, 0); w.Ln;
	w.Ln;

	IF cpuInfo.largestExtendedFunction >= 1 THEN
		w.String("Extended Function 1: Features: "); w.Ln;
		w.String("   Extended features: "); ShowExtFeatures2Amd(w, cpuInfo.extFeatures2); ShowExtFeaturesAmd(w, cpuInfo.extFeatures); w.Ln;
		w.Ln;
	END;

	IF cpuInfo.largestExtendedFunction >= 2 THEN
		w.String("Extended Function 2-4: Processor Name: "); w.Ln;
		w.String("   Processor Name: "); w.String(cpuInfo.processorName); w.Ln;
		w.Ln;
	END;

	IF cpuInfo.largestExtendedFunction < 5 THEN RETURN; END;

	IF cpuInfo.cputype = Amd THEN
		w.String("AMD Extended Function 5: L1 Cache and TLB Identifiers: "); w.Ln;
		AmdShowL1TlbAndCache(w, cpuInfo); w.Ln;
		w.Ln;
	END;

	IF cpuInfo.largestExtendedFunction < 6 THEN RETURN; END;

	IF cpuInfo.cputype = Amd THEN
		w.String("AMD Extended Function 6: L2 Cache and TLB Identifiers: "); w.Ln;
		AmdShowL2TlbAndCache(w, cpuInfo); w.Ln;
		w.Ln;
	ELSIF cpuInfo.cputype=Intel THEN
		w.String("INTEL Extended Function 6: L2 Cache  Features: "); w.Ln;
		IntelShowL2TlbAndCache(w, cpuInfo);
		w.Ln;
	END;

	IF cpuInfo.largestExtendedFunction < 7 THEN RETURN END;

	IF cpuInfo.cputype = Amd THEN
		w.String("AMD Extended Function 7: Advanced Power Management Information: "); w.Ln;
		w.String("   Features: "); ShowPowerManagementAmd(w, cpuInfo.powerManagement); w.Ln;
		w.Ln;
	END;

	IF cpuInfo.largestExtendedFunction < 8 THEN RETURN; END;

	IF (cpuInfo.cputype = Amd) OR (cpuInfo.cputype=Intel) THEN
		w.String("Extended Function 8: Long Mode Address Size Identifiers: "); w.Ln;
		ShowLongModeAS(w, cpuInfo); w.Ln;
		w.Ln;
	END;

	IF cpuInfo.largestExtendedFunction < 0AH THEN RETURN END;

	IF cpuInfo.cputype = Amd THEN
		w.String("AMD Extended Function A: SVM Revision and Feature Identification: "); w.Ln;
		AmdShowSVM(w, cpuInfo); w.Ln;
		w.Ln;
	END;

END ShowDetailedCpuInformation;

PROCEDURE ShowCpuInformation(w : Streams.Writer; cpuInfo : CpuInformation);

	PROCEDURE ShowFlag(flag : LONGINT; register : SET);
	BEGIN
		IF flag IN register THEN w.String("Yes"); ELSE w.String("No"); END;
	END ShowFlag;

BEGIN
	IF cpuInfo.largestExtendedFunction >= 2 THEN
		w.String("Prozessor: "); w.String(cpuInfo.processorName); w.Ln;
	END;
	w.String("   Vendor: "); w.String(cpuInfo.vendor);
	IF cpuInfo.largestStandardFunction >= 1 THEN
		w.String(", Family: "); w.Hex(cpuInfo.family, -2); w.Char("H");
		w.String(", Model: "); w.Hex(cpuInfo.model, -2); w.Char("H");
		w.String(", Stepping: "); w.Hex(cpuInfo.stepping, -2); w.Char("H");
		w.Ln;
		IF HTT IN cpuInfo.features THEN
			w.String("Logical processor count: "); w.Int(cpuInfo.logicalProcessorCount, 0); w.Ln;
		END;
		w.String("Features: "); w.Ln;
		w.String("   MMX: "); ShowFlag(MMX, cpuInfo.features);
		w.String(", SSE: "); ShowFlag(SSE, cpuInfo.features);
		w.String(", SSE2: "); ShowFlag(SSE2, cpuInfo.features);
		w.String(", SSE3: "); ShowFlag(SSE3, cpuInfo.features2);
		w.String(", Supplemental SSE3: "); ShowFlag(SSSE3, cpuInfo.features2);
	END;
	w.Ln;
	IF cpuInfo.largestExtendedFunction >= 1 THEN
		w.String("   Extended 3DNow!: "); ShowFlag(Amd3DNowExt, cpuInfo.extFeatures);
		w.String(", 3DNow!: "); ShowFlag(Amd3DNow, cpuInfo.extFeatures);
		w.String(", AMD MMX Extensions: "); ShowFlag(MmxExt, cpuInfo.extFeatures);
		w.Ln;
		w.String("   64bit instructions: "); ShowFlag(LM, cpuInfo.extFeatures);
		w.Ln;
	END;
	IF (cpuInfo.cputype = Amd) & (cpuInfo.largestExtendedFunction >= 8) THEN
		w.String("   Number of CPU cores: "); w.Int(cpuInfo.numberOfCores, 0); w.Ln;
	END;
END ShowCpuInformation;

PROCEDURE Show*(context : Commands.Context); (** ["-d"|"--details"] ~ *)
VAR cpuInfo : CpuInformation; options : Options.Options;
BEGIN
	NEW(options);
	options.Add("d", "details", Options.Flag);
	IF options.Parse(context.arg, context.out) THEN
		IF CpuIdSupported() THEN
			GetCpuInformation(cpuInfo);
			IF options.GetFlag("details") THEN
				ShowDetailedCpuInformation(context.out, cpuInfo);
			ELSE
				ShowCpuInformation(context.out, cpuInfo);
			END;
		ELSE
			context.out.String("CPUID instruction is not supported."); context.out.Ln;
		END;
	END;
END Show;

END CPUID.

SystemTools.Free CPUID ~

CPUID.Show ~