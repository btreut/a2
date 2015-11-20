MODULE BT848;	(** AUTHOR "fr@felix.shacknet.nu"; PURPOSE "BT848 video chip driver"; *)
									(** added code for VBI processing by Olivier Jeger, oljeger@student.ethz.ch *)

IMPORT SYSTEM, Objects, Kernel, Machine, Modules, KernelLog, Plugins, PCI, TVDriver;

CONST
	DebugOff = 0;
	DebugLow = 1;
	DebugMed = 2;
	DebugHigh = 3;
	DEBUG = DebugLow;

	PluginName = "";
	PluginDesc = "Hauppauge BT848/878 compatible TV-card";

	Brooktree848 = 1;
	Brooktree848A = 2;
	Brooktree849A = 3;
	Brooktree878 = 4;
	Brooktree879 = 5;

	PCIVendorBrooktree = 109EH;	(* Brooktree *)
	PCIVendorHauppauge = 0070H;	(* Hauppauge *)

	PCIProductBrooktreeBt848 = 0350H;	(* Bt848 Video Capture *)
	PCIProductBrooktreeBt849 = 0351H;	(* Bt849 Video Capture *)
	PCIProductBrooktreeBt878 = 036EH;	(* Bt878 Video Capture *)
	PCIProductBrooktreeBt879 = 036FH;	(* Bt879 Video Capture *)

	PCILatencyTimer = 000CH;	(* PCI timer register *)

	NoTuner = 0;
	TemicNTSC = 1;
	TemicPAL = 2;
	TemicSECAM = 3;
	PhilipsNTSC = 4;
	PhilipsPAL = 5;
	PhilipsSECAM = 6;
	TemicPALI = 7;
	PhilipsPALI = 8;
	PhilipsFR1236NTSC = 9;
	PhilipsFR1216PAL = 10;
	PhilipsFR1236SECAM = 11;
	AlpsTSCH5 = 12;
	AlpsTSBH1 = 13;
	LGPALBG = 14;

	NoOfTuners = 15;

	TunerTypeXXX = 0;
	TunerTypeNTSC = 1;
	TunerTypeNTSCJ = 2;
	TunerTypePAL = 3;
	TunerTypePALM = 4;
	TunerTypePALN = 5;
	TunerTypeSECAM = 6;

	TSA552xCbMSB = {7};
	TSA552xCbCP = {6};	(* set this for fast tuning *)
	TSA552xCbT2 = {5};	(* test mode - normally set to 0 *)
	TSA552xCbT1 = {4};	(* test mode - normally set to 0 *)
	TSA552xCbT0 = {3};	(* test mode - normaly set to 1 *)
	TSA552xCbRSA = {2};	(* 0 for 31.25 kHz, 1 for 62.5 kHz *)
	TSA552xCbRSB = {1};	(* 0 for FM 50 kHz steps, 1 = use RSA *)
	TSA552xCbOS = {0};	(* set to 0 for normal operation *)
	TSA552xRadio = SYSTEM.VAL(LONGINT, TSA552xCbMSB + TSA552xCbT0);

	(* raise the charge pump voltage for fast tuning *)
	TSA552xFControl = SYSTEM.VAL(LONGINT,
		TSA552xCbMSB + TSA552xCbCP + TSA552xCbT0 + TSA552xCbRSA + TSA552xCbRSB);
	(* lower the charge pump voltage for better residual oscillater FM *)
	TSA552xSControl = SYSTEM.VAL(LONGINT,
		TSA552xCbMSB + TSA552xCbT0 + TSA552xCbRSA + TSA552xCbRSB);
	TSCH5FControl = 0082H;	(* ALPS TSCH5 tuner *)
	TSCH5Radio = 0086H;
	TSBH1FControl = 00CEH;	(* ALPS TSBH1 tuner *)

	Bt848UseXTALS = 0;
	Bt848UsePLL = 1;

	(* register addresses of memory-mapped local registers *)
	BktrDStatus = 0000H;
	BktrIForm = 0004H;
	BktrTDec = 0008H;
	BktrECrop = 000CH;
	BktrOCrop = 008CH;
	BktrEVDelayLo = 0090H;
	BktrOVDelayLo = 0010H;
	BktrEVActiveLo = 0014H;
	BktrOVActiveLo = 0094H;
	BktrEDelayLo = 0018H;
	BktrODelayLo = 0098H;
	BktrEHActiveLo = 001CH;
	BktrOHActiveLo = 009CH;
	BktrEHScaleHi = 0020H;
	BktrOHScaleHi = 00A0H;
	BktrEHScaleLo = 0024H;
	BktrOHScaleLo = 00A4H;
	BktrBright = 0028H;
	BktrEControl = 002CH;
	BktrOControl = 00ACH;
	BktrContrastLo = 0030H;
	BktrSatULo = 0034H;
	BktrSatVLo = 0038H;
	BktrHue = 003CH;
	BktrESCLoop = 0040H;
	BktrOSCLoop = 00C0H;
	BktrWCUp = 0044H;
	BktrOForm = 0048H;
	BktrEVScaleHi = 004CH;
	BktrOVScaleHi = 00CCH;
	BktrEVScaleLo = 0050H;
	BktrOVScaleLo = 00D0H;
	BktrTest = 0054H;
	BktrADelay = 0060H;
	BktrBDelay = 0064H;
	BktrADC = 0068H;
	BktrEVTC = 006CH;
	BktrOVTC = 00ECH;
	BktrSReset = 007CH;
	BktrColorFmt = 00D4H;
	BktrColorCtl = 00D8H;
	BktrCapCtl = 00DCH;
	BktrVBIPackSize = 00E0H;
	BktrVBIPackDel = 00E4H;
	BktrIntStat = 0100H;
	BktrIntMask = 0104H;
	BktrRISCCount = 0120H;
	BktrRISCStrtAdd = 0114H;
	BktrGPIODmaCtl = 010CH;
	BktrGPIOOutEn = 0118H;
	BktrGPIORegInp = 011CH;
	BktrGPIOData = 0200H;
	BktrI2CDataCtl = 0110H;
	BktrTGCtrl = 0084H;
	BktrPLLFLo = 00F0H;
	BktrPLLFHi = 00F4H;
	BktrPLLFXCI = 00F8H;

	(* Bt848 registers *)
	Bt848DStatusPres = {7};
	Bt848DStatusHLoc = {6};
	Bt848DStatusField = {5};
	Bt848DStatusNumL = {4};
	Bt848DStatusCSel = {3};
	Bt848DStatusPLock = {2};
	Bt848DStatusLOF = {1};
	Bt848DStatusCOF = {0};
	Bt848IFormMUXSel = {5,6};
	Bt848IFormMMUX1 = {5,6};
	Bt848IFormMMUX0 = {6};
	Bt848IFormMMUX2 = {5};
	Bt848IFormMMUX3 = {};
	Bt848IFormMRSVD = {};
	Bt848IFormXtSel = {3,4};
	Bt848IFormXAuto = {3,4};
	Bt848IFormXXT1 = {4};
	Bt848IFormXXT0 = {3};
	Bt848IFormXRSVD = {};
	Bt848EControlLNotch = {7};
	Bt848EControlComp = {6};
	Bt848EControlLDec = {5};
	Bt848EControlCBSense = {4};
	Bt848EControlRSVD = {3};
	Bt848EControlConMSB = {2};
	Bt848EControlSatUMSB = {1};
	Bt848EControlSatVMSB = {1};
	Bt848ESCLoopRSVD1 = {7};
	Bt848ESCLoopCAGC = {6};
	Bt848ESCLoopCKill = {5};
	Bt848ESCLoopHFilt = {3,4};
	Bt848ESCLoopHFiltICON = {3,4};
	Bt848ESCLoopHFiltQCIF = {4};
	Bt848ESCLoopHFiltCIF = {3};
	Bt848ESCLoopHFiltAuto = {};
	Bt848ESCLoopRSVD0 = {0..3};
	Bt848ADCReserved = {7};
	Bt848ADCSyncT = {5};
	Bt848ADCAGCEn = {4};
	Bt848ADCClkSleep = {3};
	Bt848ADCYSleep = {2};
	Bt848ADCCSleep = {1};
	Bt848ADCCRush = {0};
	Bt848TGCtrlTGCKI = {3,4};
	Bt848TGCtrlTGCKIXTAL = {};
	Bt848TGCtrlTGCKIPLL = {3};
	Bt848TGCtrlTGCKIGPClk = {3,4};
	Bt848OControlLNotch = {7};
	Bt848OControlComp = {6};
	Bt848OControlLDec = {5};
	Bt848OControlCBSense = {4};
	Bt848OControlRSVD = {3};
	Bt848OControlConMSB = {2};
	Bt848OControlSatUMSB = {1};
	Bt848OControlSatVMSB = {0};
	Bt848OControlSCLoopRSVD1 = {7};
	Bt848OControlSCLoopCAGC = {6};
	Bt848OControlSCLoopCKill = {5};
	Bt848OControlSCLoopHFilt = {3,4};
	Bt848OControlSCLoopHFiltICON = {3,4};
	Bt848OControlSCLoopHFiltQCIF = {4};
	Bt848OControlSCLoopHFiltCIF = {3};
	Bt848OControlSCLoopAuto = {};
	Bt848OControlSCLoopRSVD0 = {0..3};
	Bt848ColorCtlWSwapOdd = {3};
	Bt848ColorCtlWSwapEven = {2};
	Bt848ColorCtlBSwapOdd = {1};
	Bt848ColorCtlBSwapEven = {0};
	Bt848ColorCtlGamma = {4};
	Bt848ColorCtlRGBDed = {5};
	Bt848ColorCtlColorBars = {6};
	Bt848ColorCtlExtFrmRate = {7};
	Bt848CapCtlDithFrame = {4};
	Bt848CapCtlVBIOdd = {3};
	Bt848CapCtlVBIEven = {2};
	Bt848CapCtlOdd = {1};
	Bt848CapCtlEven = {0};
	Bt848PLLFC = {6};
	Bt848PLLFX = {7};
	Bt848IntRiscs = {28, 29, 30, 31};
	Bt848IntRiscEn = {27};
	Bt848IntRAck = {25};
	Bt848IntField = {24};
	Bt848IntMysteryBit = {23};
	Bt848IntSCErr = {19};
	Bt848IntOCErr = {18};
	Bt848IntPAbort = {17};
	Bt848IntRipErr = {16};
	Bt848IntPPErr = {15};
	Bt848IntFDSR = {14};
	Bt848IntFTrgt = {13};
	Bt848IntFBus = {12};
	Bt848IntRiscI = {11};
	Bt848IntGPInt = {9};
	Bt848IntI2CDone = {8};
	Bt848IntRSV1 = {7};
	Bt848IntRSV0 = {6};
	Bt848IntVPres = {5};
	Bt848IntHLock = {4};
	Bt848IntOFlow = {3};
	Bt848IntHSync = {2};
	Bt848IntVSync = {1};
	Bt848IntFmtChg = {0};
	Bt848DmaCtlPL23TP4 = {};	(* planar1 trigger 4 *)
	Bt848DmaCtlPL23TP8 = {6};	(* planar1 trigger 8 *)
	Bt848DmaCtlPL23TP16 = {7};	(* planar1 trigger 16 *)
	Bt848DmaCtlPL23TP32 = {6,7};	(* planar1 trigger 32 *)
	Bt848DmaCtlPL1TP4 = {};	(* planar1 trigger 4 *)
	Bt848DmaCtlPL1TP8 = {4};	(* planar1 trigger 8 *)
	Bt848DmaCtlPL1TP16 = {5};	(* planar1 trigger 16 *)
	Bt848DmaCtlPL1TP32 = {4,5};	(* planar1 trigger 32 *)
	Bt848DmaCtlPKTP4 = {};	(* packed trigger 4 *)
	Bt848DmaCtlPKTP8 = {2};	(* packed trigger 8 *)
	Bt848DmaCtlPKTP16 = {3};	(* packed trigger 16 *)
	Bt848DmaCtlPKTP32 = {2,3};	(* packed trigger 32 *)
	Bt848DmaCtlRiscEn = {1};
	Bt848DmaCtlFifoEn = {};
	Bt848DataCtlI2CDiv = {4,5,6,7};
	Bt848DataCtlI2CSync = {3};
	Bt848DataCtlI2CW3B = {2};
	Bt848DataCtlI2CSCL = {1};
	Bt848DataCtlI2CSDA = {0};

	Bt848IFormFormat = {0..2};
	Bt848IFormFAuto = 0;
	Bt848IFormFNTSCM = 1;
	Bt848IFormFNTSCJ = 2;
	Bt848IFormFPalBDGHI = 3;
	Bt848IFormFPalM = 4;
	Bt848IFormFPalN = 5;
	Bt848IFormFSecam = 6;
	Bt848IFormFRSVD = 7;

	AosPixTypeRGB = 0;
	AosPixTypeYUV = 1;
	AosPixTypeYUVPacked = 2;
	AosPixTypeYUV12 = 3;

	(* RISC programming routines *)
	BktrFM1 = {1,2};	(* packed data to follow *)
	BktrFM2 = {1,2,3};	(* planar data to follow *)
	BktrVRE = {2};	(* marks the end of the even field *)
	BktrVRO = {2,3};	(* marks the end of the odd field *)
	BktrPXV = {};	(* valid word (never used) *)
	BktrEOL = {0};	(* last dword, 4 bytes *)
	BktrSOL = {1};	(* first dword *)

	OpWrite = {28};
	OpSkip = {29};
	OpWriteC = {28, 30};
	OpJump = {28, 29, 30};
	OpSync = {31};
	OpWrite123 = {28, 31};
	OpWriteS123 = {28, 29, 31};
	OpSOL = {27};
	OpEOL = {26};

	BktrResync = {15};
	BktrGenIRQ = {24};

	BktrSetRISCStatusBit0 = {16};
	BktrSetRISCStatusBit1 = {17};
	BktrSetRISCStatusBit2 = {18};
	BktrSetRISCStatusBit3 = {19};

	BktrClearRISCStatusBit0 = {20};
	BktrClearRISCStatusBit1 = {21};
	BktrClearRISCStatusBit2 = {22};
	BktrClearRISCStatusBit3 = {23};

	BktrTestRISCStatusBit0 = {28};
	BktrTestRISCStatusBit1 = {29};
	BktrTestRISCStatusBit2 = {30};
	BktrTestRISCStatusBit3 = {31};

	(* Definitions for VBI capture. *)
	(* There are 16 VBI lines in a PAL video field (32 in a frame), *)
	(* and we take 2044 samples from each line (placed in a 2048 byte buffer *)
	(* for alignment). *)
	(* VBI lines are held in a circular buffer before being read by a user program. *)
	VbiMaxLines = TVDriver.VbiMaxLines;	(* maximum for all video formats *)
	VbiLineSize = TVDriver.VbiLineSize;	(* store up to 2048 bytes per line *)
	VbiDataSize = TVDriver.VbiDataSize;
	VbiBufferSize = TVDriver.VbiBufferSize;

	AosEvenField = 1;
	AosOddField = 2;
	AosInterlaced = 3;

	AosInitialized = {0};
	FileHandlers = {1};
	AosSingle = {5};
	AosContin = {6};
	AosSynCap = {7};
	AosCapMask = {4..7};
	AosNTSC = {8};
	AosPAL = {9};
	AosSECAM = {10};
	AosAutoMode = {11};
	AosFormMask = {8..11};
	AosDev0 = {12};
	AosDev1 = {13};
	AosDev2 = {14};
	AosDevSVideo = {13, 14};
	AosDev3 = {15};

	AosDevMask = {12..15};
	AosWantEven = {20};
	AosWantOdd = {21};
	AosWantMask = {20,21};
	AosOnlyEvenFields* = {24};
	AosOnlyOddFields* = {25};
	AosOnlyFieldsMask = {24, 25};

	VbiInitialized = {0};
	VbiOpen = {1};
	VbiCapture = {2};

	(* When to split a DMA transfer, the bt848 has timing as well as *)
	(* DMA transfer size limitations so that we have to split DMA *)
	(* transfers into two DMA requests. *)
	DmaBt848Split = 319 * 2;

	(* registers in the TDA9850 BTSC/dbx chip *)
	Con1Addr = 0004H;
	Con2Addr = 0005H;
	Con3Addr = 0006H;
	Con4Addr = 0007H;
	Ali1Addr = 0008H;
	Ali2Addr = 0009H;
	Ali3Addr = 000AH;

	EEPromBlockSize = 32;
	PFC8582WAddr = 00A0H;	(* EEProm on Hauppauge card *)
	PFC8582RAddr = 00A1H;
	TDA9850WAddr = 00B6H;	(* address of BTSC/SAP decoder chip *)
	TDA9850RAddr = 00B7H;
	MSP3400CWAddr = 0080H;	(* address of MSP3400C chip *)
	MSP3400CRAddr = 0081H;
	DPL3518AWAddr = 0084H;	(* address of DPL3518A chip *)
	DPL3518ARAddr = 0085H;
	HaupRemoteIntWAddr = 0030H;	(* Hauppauge remote control *)
	HaupRemoteIntRAddr = 0031H;
	HaupRemoteExtWAddr = 0034H;
	HaupRemoteExtRAddr = 0035H;

	FifoEnabled = Bt848DmaCtlFifoEn;
	RiscEnabled = Bt848DmaCtlRiscEn;
	FifoRiscEnabled = Bt848DmaCtlFifoEn + Bt848DmaCtlRiscEn;
	FifoRiscDisabled = {};

	AllIntsDisabled = {};
	AllIntsCleared = {0..31};
	CaptureOff = {};

	I2CBits = Bt848IntRAck + Bt848IntI2CDone;
	TDecBits = Bt848IntFDSR + Bt848IntFBus;

	SyncLevel = Bt848IntRAck + Bt848ADCSyncT;	(* threshold ~75mV *)

	CardUnknown = 0;
	CardHauppauge = 1;

	NoOfCards = 2;

	AudioTuner = 0000H;
	AudioExtern = 0001H;
	AudioIntern = 0002H;
	LowBand = 0;
	MidBand = 1;
	HighBand = 2;
	FMRadioBand = 3;

	RadioMinFreq = 8750;
	RadioMaxFreq = 10800;

VAR
	nOfInstalledDevices: LONGINT;

TYPE
	CardType = RECORD
		cardID: LONGINT;
		name: ARRAY 32 OF CHAR;
		tuner: Tuner;
		tunerPLLAddr: LONGINT;
		dbx: BOOLEAN;
		msp3400c: BOOLEAN;
		dpl3518a: BOOLEAN;
		eepromAddr: LONGINT;
		eepromSize: LONGINT;
		audioMUXs: ARRAY 5 OF LONGINT;
		gpioMUXBits: LONGINT;
	END;

	Tuner = RECORD
		name: ARRAY 32 OF CHAR;
		type: LONGINT;
		pllControl: ARRAY 4 OF LONGINT;
		bandLimits: ARRAY 2 OF LONGINT;
		bandAddrs: ARRAY 4 OF LONGINT;
	END;

	Channel = RECORD
		baseChnl: LONGINT;	(* base channel *)
		baseChnlFreq: LONGINT;	(* frequency of base channel expressed as fb[MHz] * 16 *)
		offsetFreq: LONGINT;	(* offset frequency between channels, expressed as fo[MHz] * 16 *)
	END;

	ChannelSet = RECORD
		maxChnl: LONGINT;	(* max legal channel *)
		ifFreq: LONGINT;	(* IF frequency expressed as fi[MHz] * 16 *)
		chnls: POINTER TO ARRAY OF Channel;
	END;

	FormatParams = POINTER TO FormatParamsDesc;
	FormatParamsDesc = RECORD
		(* total lines, lines before image, image lines *)
		vTotal, vDelay, vActive: LONGINT;
		(* total unscaled horizontal pixels, pixels before image, image pixels *)
		hTotal, hDelay, hActive: LONGINT;
		(* scaled horizontal image pixels, total scaled horizontal pixels *)
		scaledHActive, scaledHTotal: LONGINT;
		(* frame rate (for NTSC: 30 frames per second) *)
		frameRate: LONGINT;
		(* A-delay, B-delay *)
		aDelay, bDelay: LONGINT;
		(* Iform XTSEL value *)
		iformXTSel: LONGINT;
		(* VBI number of lines per field, and number of samples per line *)
		vbiNumLines, vbiNumSamples: LONGINT;
	END;

	PixelFormat = POINTER TO PixelFormatDesc;
	PixelFormatDesc = RECORD
		index: LONGINT;	(* index in supported pixfmt list *)
		type: LONGINT;	(* what the board is gonna feed us *)
		bpp: LONGINT;	(* bytes per pixel *)
		masks: ARRAY 3 OF LONGINT;	(* R,G,B or Y,U,V masks, respectively *)
		swapBytes: BOOLEAN;	(* bytes swapped within shorts *)
		swapShorts: BOOLEAN;	(* shorts swapped within longs *)
		colorFormat: LONGINT;
	END;

CONST
	FreqFactor = 16;
	NoOfChnlSets = 1;
	WesternEuropeanChnlSet* = 0;
	DefaultChnlSet = WesternEuropeanChnlSet;
	NoOfFormatParams = 8;
	NoOfPixelFormats = 12;


TYPE
	(** The TVTuner objects represents the tuning facilities of a video capture card. *)
	TVTuner* = OBJECT (TVDriver.TVTuner)
	VAR
		vcd: VideoCaptureDevice;
		chnlSet: LONGINT;
		chnl: LONGINT;
		band: LONGINT;
		afc: LONGINT;
		radioMode: LONGINT;

	(** Initialize the tuner object. *)
	PROCEDURE &Init*(vcd: TVDriver.VideoCaptureDevice);
	BEGIN
		ASSERT (vcd IS VideoCaptureDevice);
		SELF.vcd := vcd (VideoCaptureDevice);
	END Init;

	(** Open the VBI device. *)
	(** return value:	-1 if the device is already open, otherwise 0 *)
	PROCEDURE OpenVbi*(): LONGINT;
	BEGIN
		IF vcd.vbiFlags * VbiOpen # {} THEN
			IF DEBUG # DebugOff THEN KernelLog.String("{BT848} vbi device already open."); KernelLog.Ln; END;
			RETURN -1;
		END;
		vcd.vbiFlags := vcd.vbiFlags + VbiOpen;
		BEGIN {EXCLUSIVE}
			vcd.vbiBuffer.insertPos := 0;
			vcd.vbiBuffer.readPos := 0;
			vcd.vbiBuffer.vbiSize := 0;
			RETURN 0
		END
	END OpenVbi;

	(** Close the VBI device. *)
	PROCEDURE CloseVbi*;
	BEGIN
		IF VbiOpen * vcd.vbiFlags # {} THEN
			IF DEBUG # DebugOff THEN KernelLog.String("{BT848} vbi device ."); KernelLog.Ln; END;
		END;
		vcd.vbiFlags := vcd.vbiFlags - VbiOpen;
	END CloseVbi;

	(** Open the tuner. *)
	PROCEDURE Open*;
	VAR temp: SET;
	BEGIN
		frequency := 0;
		chnl := 0;
		chnlSet := DefaultChnlSet;
		afc := 0;
		radioMode := 0;
		(* enable drivers on the GPIO port that control the MUXes *)
		temp := SYSTEM.VAL(SET, SYSTEM.GET32(vcd.base + BktrGPIOOutEn)) + SYSTEM.VAL(SET, vcd.card.gpioMUXBits);
		SYSTEM.PUT32(vcd.base + BktrGPIOOutEn, SYSTEM.VAL(LONGINT, temp));
		SetTVFrequency(2810);	(* Hack for proper radio reception *)
		vcd.audio.InitAudioDevices;
		vcd.audio.SetAudioUnmute;
	END Open;

	(** Close the tuner. *)
	PROCEDURE Close*;
	VAR temp: SET;
	BEGIN
		vcd.audio.SetAudioMute;
		temp := SYSTEM.VAL(SET, SYSTEM.GET32(vcd.base + BktrGPIOOutEn)) * (-SYSTEM.VAL(SET, vcd.card.gpioMUXBits));
		SYSTEM.PUT32(vcd.base + BktrGPIOOutEn, SYSTEM.VAL(LONGINT, temp));
	END Close;

	(** Set the channel set. *)
	(** chnlSet:	channel set (only WesternEuropeanChnlSet available at the moment). *)
	PROCEDURE SetChannelSet*(chnlSet: LONGINT);
	BEGIN
		ASSERT((chnlSet >= 0) & (chnlSet < NoOfChnlSets));
		SELF.chnlSet := chnlSet;
	END SetChannelSet;

	(** Get the channel set. *)
	PROCEDURE GetChannelSet*(): LONGINT;
	BEGIN
		RETURN chnlSet;
	END GetChannelSet;

	(** Set a channel. *)
	(** chnl:	channel to set (see range of channel set). *)
	PROCEDURE SetChannel*(chnl: LONGINT);
	VAR
		i: LONGINT;
		freq: LONGINT;
	BEGIN
		ASSERT(chnl <= freqTable[chnlSet].maxChnl);
		freq := 0;
		FOR i := LEN(freqTable[chnlSet].chnls)-1 TO 0 BY -1 DO
			IF chnl >= freqTable[chnlSet].chnls[i].baseChnl THEN
				freq := freqTable[chnlSet].chnls[i].baseChnlFreq +
					((chnl - freqTable[chnlSet].chnls[i].baseChnl) * freqTable[chnlSet].chnls[i].offsetFreq);
				IF DEBUG = DebugHigh THEN
					KernelLog.String("{BT848} baseChnl = "); KernelLog.Int(freqTable[chnlSet].chnls[i].baseChnl, 0); KernelLog.Ln
				END;
			END;
		END;
		IF freq # 0 THEN
			SetTVFrequency(freq);
			SELF.chnl := chnl;
			IF DEBUG # DebugOff THEN
				KernelLog.String("{BT848} channel set to "); KernelLog.Int(chnl, 0); KernelLog.String(" with frequency ");
				KernelLog.Int(freq, 0); KernelLog.Ln;
			END;
		ELSE
			IF DEBUG # DebugOff THEN
				KernelLog.String("{BT848} failed to set channel"); KernelLog.Ln;
			END;
		END;
	END SetChannel;

	(** Get channel. *)
	(** return value:	channel *)
	PROCEDURE GetChannel*(): LONGINT;
	BEGIN
		RETURN chnl;
	END GetChannel;

	(* Get maximum channel number of selected channel set. *)
	(* return value:	maximum channel number of channel set *)
	PROCEDURE GetMaxChannel*(): LONGINT;
	BEGIN
		RETURN freqTable[chnlSet].maxChnl;
	END GetMaxChannel;

	(** Set TV frequency. *)
	(** freq:	frequency expressed as frequency * 16. *)
	PROCEDURE SetTVFrequencyImpl (freq: LONGINT);
	VAR
		bandSelect, n: LONGINT;
		addr, control, band: LONGINT;
		isMute: BOOLEAN;
	BEGIN {EXCLUSIVE}
		IF DEBUG >= DebugLow THEN KernelLog.String("{BT848} setting frequency to "); KernelLog.Int(freq, 0); KernelLog.Ln; END;
		isMute := vcd.audio.IsAudioMute();
		vcd.audio.SetAudioMute;
		IF (freq < (vcd.card.tuner.bandLimits[0])) THEN
			bandSelect := LowBand;
			IF DEBUG >= DebugMed THEN KernelLog.String("{BT848} low band"); KernelLog.Ln; END;
		ELSIF (freq < (vcd.card.tuner.bandLimits[1])) THEN
			bandSelect := MidBand;
			IF DEBUG >= DebugMed THEN KernelLog.String("{BT848} mid band"); KernelLog.Ln; END;
		ELSE
			bandSelect := HighBand;
			IF DEBUG >= DebugMed THEN KernelLog.String("{BT848} high band"); KernelLog.Ln; END;
		END;
		n := freq + freqTable[chnlSet].ifFreq;
		addr := vcd.card.tunerPLLAddr;
		control := vcd.card.tuner.pllControl[bandSelect];
		band := vcd.card.tuner.bandAddrs[bandSelect];
		ASSERT((band # 0) & (control # 0));
		IF (freq > frequency) THEN
			ASSERT(vcd.i2cBus.I2CWrite(addr, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(n, -8)) * {0..6}),
				SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, n) * {0..7})) = 0);
			ASSERT(vcd.i2cBus.I2CWrite(addr, control, band) = 0);
		ELSE
			ASSERT(vcd.i2cBus.I2CWrite(addr, control, band) = 0);
			ASSERT(vcd.i2cBus.I2CWrite(addr, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(n, -8)) * {0..6}),
				SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, n) * {0..7})) = 0);
		END;
		frequency := freq;
		IF (vcd.card.msp3400c) THEN vcd.audio.MspAutoDetect; END;
		IF (vcd.card.dpl3518a) THEN vcd.audio.DplAutoDetect; END;
		IF isMute THEN
			vcd.audio.SetAudioMute;
		ELSE
			vcd.audio.SetAudioUnmute;
		END;
	END SetTVFrequencyImpl;

	(** Set radio frequency. *)
	(** freq:	frequency expressed as frequency * 100. *)
	PROCEDURE SetRadioFrequency*(freq: LONGINT);
	VAR
		bandSelect, n: LONGINT;
		addr, control, band: LONGINT;
		isMute: BOOLEAN;
	BEGIN {EXCLUSIVE}
		IF DEBUG # DebugOff THEN
			KernelLog.String("{BT848} setting radio freqency to: ");
			KernelLog.Int(freq, 0); KernelLog.Ln;
		END;
		ASSERT((freq >= RadioMinFreq) & (freq <= RadioMaxFreq));
		isMute := vcd.audio.IsAudioMute();
		vcd.audio.SetAudioMute;
		bandSelect := FMRadioBand;
		n := (freq + 1070) DIV 5;
		addr := vcd.card.tunerPLLAddr;
		control := vcd.card.tuner.pllControl[bandSelect];
		band := vcd.card.tuner.bandAddrs[bandSelect];
		ASSERT((band # 0) & (control # 0));	(* don't try to set unsupported modes *)
		band := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, band) + SYSTEM.VAL(SET, radioMode));
		ASSERT(vcd.i2cBus.I2CWrite(addr, control, band) = 0);
		ASSERT(vcd.i2cBus.I2CWrite(addr, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(n, -8)) * {0..6}),
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, n) * {0..7})) = 0);
		frequency := (n * 5) - 1070;
		IF (vcd.card.msp3400c) THEN vcd.audio.MspAutoDetect; END;
		IF (vcd.card.dpl3518a) THEN vcd.audio.DplAutoDetect; END;
		IF isMute THEN
			vcd.audio.SetAudioMute;
		ELSE
			vcd.audio.SetAudioUnmute;
		END;
	END SetRadioFrequency;

	(** Get the tuner status. *)
	(** return value:	tuner status *)
	PROCEDURE GetTunerStatus*(): LONGINT;
	BEGIN
		RETURN vcd.i2cBus.I2CRead(vcd.card.tunerPLLAddr + 1);
	END GetTunerStatus;

	(** Calculates the field strength of the radio signal. *)
	(** return value:	field strength (3-bit value) *)
	PROCEDURE CalcFieldStrength*(): LONGINT;
	BEGIN
		RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, GetTunerStatus()) * {0..2});
	END CalcFieldStrength;

	(** Returns wether tuner is locked to a stable video signal or not. *)
	(** return value:	TRUE if tuner is locked to a stable video signal, otherwise FALSE *)
	PROCEDURE IsLocked*(): BOOLEAN;
	BEGIN
		RETURN SYSTEM.VAL(SET, vcd.GetStatus()) * Bt848DStatusHLoc # {};
	END IsLocked;

	(** Returns wether the sound is received in stereo or mono. *)
	(** return value:	TRUE if stereo is enabled, otherwise FALSE *)
	PROCEDURE IsStereo*(): BOOLEAN;
	BEGIN
		RETURN SYSTEM.VAL(SET, GetTunerStatus()) * {16} # {};
	END IsStereo;

	(** Set the hue. *)
	(** Hue adjustment involves the addition of a two's complement *)
	(** number to the demodulating subcarrier phase. Hue can be adjusted in *)
	(** 256 steps in the range -90 dgr to +89.3 dgr, in increments of 0.7 dgr. *)
	(** Note: not applicable to PAL/SECAM, or digital video *)
	(** hue:	a value between 0x7F and 0x80 results in a hue adjustment by -89 and +90% *)
	PROCEDURE SetHue*(hue: LONGINT);
	BEGIN
		SYSTEM.PUT8(vcd.base + BktrHue, hue);
	END SetHue;

	(** Get the hue *)
	(** return value:	the hue offset *)
	PROCEDURE GetHue*(): LONGINT;
	BEGIN
		RETURN SYSTEM.GET8(vcd.base + BktrHue);
	END GetHue;

	(** Set the brightness. *)
	(** The brightness control involves the addition of a two's complement *)
	(** number to the luma channel. Brightness can be adjusted in 255 *)
	(** steps, from -128 to +127. The resolution of brightness change is *)
	(** one LSB (0.39% with respect to the full luma range). *)
	(** brightness:	a value between 0x7F and 0x80 results in a brightness adjustment of +49 and -50% of full scale *)
	PROCEDURE SetBrightness*(brightness: LONGINT);
	BEGIN
		SYSTEM.PUT8(vcd.base + BktrBright, brightness);
	END SetBrightness;

	(** Get the brightness. *)
	(** return value:	the brightness offset *)
	PROCEDURE GetBrightness*(): LONGINT;
	BEGIN
		RETURN SYSTEM.GET8(vcd.base + BktrBright);
	END GetBrightness;

	(** Set the chroma saturation. *)
	(** Adds a gain adjustment to the U- and V-component of the video signal. *)
	(** saturation:	a value between 0x000 and 0x1FF adjusts the saturation in the range of 0 to 200% *)
	PROCEDURE SetChromaSaturation*(saturation: LONGINT);
	VAR temp1, temp2: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrEControl);
		temp2 := SYSTEM.GET8(vcd.base + BktrOControl);
		IF (SYSTEM.VAL(SET, saturation) * {8} # {}) THEN
			temp1 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848EControlSatUMSB
				+ Bt848EControlSatVMSB);
			temp2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) + Bt848OControlSatUMSB
				+ Bt848OControlSatVMSB);
		ELSE
			temp1 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-(Bt848EControlSatUMSB
				+ Bt848EControlSatVMSB)));
			temp2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * (-(Bt848OControlSatUMSB
				+ Bt848OControlSatVMSB)));
		END;
		SYSTEM.PUT8(vcd.base + BktrSatULo, saturation);
		SYSTEM.PUT8(vcd.base + BktrSatVLo, saturation);
		SYSTEM.PUT8(vcd.base + BktrEControl, temp1);
		SYSTEM.PUT8(vcd.base + BktrOControl, temp2);
	END SetChromaSaturation;

	(** Get chroma saturation. *)
	(** return value:	the chroma saturation *)
	PROCEDURE GetChromaSaturation*(): LONGINT;
	VAR temp1, temp2: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrSatVLo);
		temp2 := SYSTEM.GET8(vcd.base + BktrEControl);
		IF SYSTEM.VAL(SET, temp2) * Bt848EControlSatVMSB # {} THEN
			RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + {8});
		ELSE
			RETURN temp1;
		END;
	END GetChromaSaturation;

	(** Set chroma V saturation *)
	(** Adds a gain adjustment to the V-component of the video signal. *)
	(** saturation:	a value between 0x000 and 0x1FF adjusts the V saturation in the range of 0 to 200% *)
	PROCEDURE SetChromaVSaturation*(saturation: LONGINT);
	VAR temp1, temp2: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrEControl);
		temp2 := SYSTEM.GET8(vcd.base + BktrOControl);
		IF (SYSTEM.VAL(SET, saturation) * {8} # {}) THEN
			temp1 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848EControlSatVMSB);
			temp2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) + Bt848OControlSatVMSB);
		ELSE
			temp1 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848EControlSatVMSB));
			temp2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * (-Bt848OControlSatVMSB));
		END;
		SYSTEM.PUT8(vcd.base + BktrSatVLo, saturation);
		SYSTEM.PUT8(vcd.base + BktrEControl, temp1);
		SYSTEM.PUT8(vcd.base + BktrOControl, temp2);
	END SetChromaVSaturation;

	(** Get the chroma V saturation. *)
	(** return value:	the chroma V saturation *)
	PROCEDURE GetChromaVSaturation*(): LONGINT;
	VAR temp1, temp2: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrSatVLo);
		temp2 := SYSTEM.GET8(vcd.base + BktrEControl);
		IF (SYSTEM.VAL(SET, temp2) * Bt848EControlSatVMSB # {}) THEN
			RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + {8});
		ELSE
			RETURN temp1;
		END;
	END GetChromaVSaturation;

	(** Set the chroma U saturation. *)
	(** Adds a gain adjustment to the U-component of the video signal. *)
	(** saturation:	a value between 0x000 and 0x1FF adjusts the U saturation in the range of 0 to 200% *)
	PROCEDURE SetChromaUSaturation*(saturation: LONGINT);
	VAR temp1, temp2: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrEControl);
		temp2 := SYSTEM.GET8(vcd.base + BktrOControl);
		IF (SYSTEM.VAL(SET, saturation) * {8} # {}) THEN
			temp1 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848EControlSatUMSB);
			temp2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) + Bt848OControlSatUMSB);
		ELSE
			temp1 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848EControlSatUMSB));
			temp2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * (-Bt848OControlSatUMSB));
		END;
		SYSTEM.PUT8(vcd.base + BktrSatULo, saturation);
		SYSTEM.PUT8(vcd.base + BktrEControl, temp1);
		SYSTEM.PUT8(vcd.base + BktrOControl, temp2);
	END SetChromaUSaturation;

	(** Get the chroma U saturation. *)
	(** return value:	the chroma U saturation *)
	PROCEDURE GetChromaUSaturation*(): LONGINT;
	VAR temp1, temp2: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrSatULo);
		temp2 := SYSTEM.GET8(vcd.base + BktrEControl);
		IF (SYSTEM.VAL(SET, temp2) * Bt848EControlSatUMSB # {}) THEN
			RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + {8});
		ELSE
			RETURN temp1;
		END;
	END GetChromaUSaturation;

	(** Set the luma notch filters. *)
	(** Sets the 3 high bits of EControl/OControl *)
	(** The luma decimation filter is used to reduce the high-frequency component of the luma signal. *)
	(** Useful when scaling to CIF resolution or lower. *)
	(** For monochrome video, the luma notch filter should not be used. This will output full bandwidth luminance. *)
	(** notch:	3 bits of EControl/OControl *)
	(**				[0] 0 enables luma decimation using selectable H filter, 1 disables luma decimation *)
	(**				[1] 0 composite video, 1 Y/C component video *)
	(**				[2] 0 enables the luma notch filter, 1 disables the luma notch filter *)
	PROCEDURE SetLumaNotch*(notch: LONGINT);
	VAR temp1: LONGINT; temp2: LONGINT;
	BEGIN
		temp1 := ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, notch) * {0..2}), 5);
		temp2 := SYSTEM.GET8(vcd.base + BktrEControl);
		SYSTEM.PUT8(vcd.base + BktrEControl,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * (-SYSTEM.VAL(SET, 00E0H))));
		temp2 := SYSTEM.GET8(vcd.base + BktrOControl);
		SYSTEM.PUT8(vcd.base + BktrOControl,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * (-SYSTEM.VAL(SET, 00E0H))));
		temp2 := SYSTEM.GET8(vcd.base + BktrEControl);
		SYSTEM.PUT8(vcd.base + BktrEControl,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) + SYSTEM.VAL(SET, temp1)));
		temp2 := SYSTEM.GET8(vcd.base + BktrOControl);
		SYSTEM.PUT8(vcd.base + BktrOControl,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) + SYSTEM.VAL(SET, temp1)));
	END SetLumaNotch;

	(** Get status of luma notch filters. *)
	(** return value:	3 bits of EControl/OControl *)
	PROCEDURE GetLumaNotch*(): LONGINT;
	VAR temp1: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrEControl);
		RETURN SYSTEM.VAL(LONGINT, ASH(SYSTEM.VAL(LONGINT,
			SYSTEM.VAL(SET, temp1) * SYSTEM.VAL(SET, 00E0H)), -5));
	END GetLumaNotch;

	(** Set the contrast. *)
	(** This value ist multiplied by the luminance value to provide contrast adjustment. *)
	(** contrast:	a value between 0x000 and 0x1FF for an adjustment between 0 and 236% *)
	PROCEDURE SetContrast*(contrast: LONGINT);
	VAR temp1, temp2: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrEControl);
		temp2 := SYSTEM.GET8(vcd.base + BktrOControl);
		IF (SYSTEM.VAL(SET, contrast) * {8} # {}) THEN
			temp1 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848EControlConMSB);
			temp2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) + Bt848OControlConMSB);
		ELSE
			temp1 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848EControlConMSB));
			temp2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * (-Bt848OControlConMSB));
		END;
		SYSTEM.PUT8(vcd.base + BktrContrastLo, contrast);
		SYSTEM.PUT8(vcd.base + BktrEControl, temp1);
		SYSTEM.PUT8(vcd.base + BktrOControl, temp2);
	END SetContrast;

	(** Get contrast value. *)
	(** return value:	value of contrast multiplication factor *)
	PROCEDURE GetContrast*(): LONGINT;
	VAR temp1, temp2: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrContrastLo);
		temp2 := SYSTEM.GET8(vcd.base + BktrEControl);
		IF (SYSTEM.VAL(SET, temp2) * Bt848EControlConMSB # {}) THEN
			RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + {8});
		ELSE
			RETURN temp1;
		END;
	END GetContrast;

	(** Enable or disable color bars. *)
	(** enable:	TRUE to enable color bars, FALSE for disabling color bars *)
	PROCEDURE SetColorBars*(enable: BOOLEAN);
	VAR
		temp1: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(vcd.base + BktrColorCtl);
		IF enable THEN
			SYSTEM.PUT8(vcd.base + BktrColorCtl, SYSTEM.VAL(LONGINT,
				SYSTEM.VAL(SET, temp1) + Bt848ColorCtlColorBars));
		ELSE
			SYSTEM.PUT8(vcd.base + BktrColorCtl, SYSTEM.VAL(LONGINT,
				SYSTEM.VAL(SET, temp1) * (-Bt848ColorCtlColorBars)));
		END;
	END SetColorBars;

	END TVTuner;

	NotificationHandler* = PROCEDURE {DELEGATE};	(* handler for notification of RISC events *)

	(* The Notification Process object is used for calling the notification handler. *)
	NotificationProcess = OBJECT
	VAR
		dead: BOOLEAN;
		callMeNow: BOOLEAN;
		handler: NotificationHandler;

	(* Initialize the notification process. *)
	(* handler:	notification handler to be notified *)
	PROCEDURE &Init*(handler: NotificationHandler);
	BEGIN
		ASSERT(handler # NIL);
		SELF.handler := handler;
	END Init;

	(* Stop the notification process. *)
	PROCEDURE Stop;
	BEGIN {EXCLUSIVE}
		dead := TRUE;
		handler := NIL;
	END Stop;

	PROCEDURE NotifyHandler;
	BEGIN {EXCLUSIVE}
		callMeNow := TRUE;
	END NotifyHandler;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE}
			dead := FALSE;
			callMeNow := FALSE;
			REPEAT
				AWAIT(dead OR callMeNow);
					IF ~dead THEN
						callMeNow := FALSE;
						handler;
					END;
			UNTIL dead;
		END;
	END NotificationProcess;

	(** The VideoCaptureDevice represents a video capture card with its tuning and audio components. *)
	VideoCaptureDevice* = OBJECT (TVDriver.VideoCaptureDevice)
	VAR
		next: VideoCaptureDevice;
		card: CardType;
		tuner: TVTuner;
		audio: Audio;
		i2cBus: I2CBus;
		id: LONGINT;
		base: ADDRESS; irq: LONGINT;
		bt848Tuner: LONGINT;
		bt848Card: LONGINT;
		mspVersionString: ARRAY 9 OF CHAR;	(* MSP version string 34xxx-xx *)
		mspAddr: LONGINT;	(* MSP i2c address *)
		mspSourceSelected: LONGINT;	(* 0 = TV source, 1 = Line-In source, 2 = FM radio source *)
		mspUseMonoSource: BOOLEAN;	(* use Tuner's Mono audio output via MSP chip *)
		slowMSPAudio: LONGINT;	(* 0 = use fast MSP3410/3415 programming sequence *)
													(* 1 = use slow MSP3410/3415 programming sequence *)
		dplVersionString: ARRAY 9 OF CHAR;	(* DPL version string 35xxx-xx *)
		dplAddr: LONGINT;	(* DPL i2c address *)
		audioMUXPresent: BOOLEAN;
		audioMUXSelect: LONGINT;	(* current mode of the audio *)
		audioMuteState: BOOLEAN;	(* mute state of the audio *)
		audioMUXs: ARRAY 5 OF LONGINT;
		reverseMute: BOOLEAN;
		gpioMUXBits: LONGINT;
		xtalPLLMode: LONGINT;
		remoteControl: BOOLEAN;
		remoteControlAddr: LONGINT;

		vbiData: ARRAY TVDriver.VbiDataSize OF CHAR;
		vbiBuffer: TVDriver.VbiBuffer;
		dmaProg: ARRAY 32768 OF LONGINT;
		dmaProgLength: LONGINT;
		oddDmaProg: ARRAY 32768 OF LONGINT;
		oddDmaProgLength: LONGINT;
		formatParameters: LONGINT;
		currentCol: LONGINT;
		videoAddr: LONGINT;
		videoWidth: LONGINT;

		notificationProcess: NotificationProcess;	(* user land notification handler *)
		singleFrameCaptured: BOOLEAN;	(* wait variable for single frame capture *)

		flags: SET;
		vbiFlags: SET;

		dmaProgLoaded: BOOLEAN;
		frameRows, frameCols: LONGINT;	(* # rows, cols in a frame *)
		captureAreaXOffset, captureAreaYOffset, captureAreaXSize, captureAreaYSize: LONGINT;
		captureAreaEnabled: BOOLEAN;
		pixFormat: LONGINT;	(* active pixel format (index into PixelFormatTable *)
		frames: LONGINT;	(* number of frames allocated *)
		fifoErrors: LONGINT;	(* number of FIFO capture errors since open *)
		dmaErrors: LONGINT;	(* number of DMA errors since open *)
		framesCaptured: LONGINT;	(* # of frames captured since open *)
		evenFieldsCaptured: LONGINT;	(* number of even fields captured *)
		oddFieldsCaptured: LONGINT;	(* number of odd fields captured *)
		capControl: SET;
		bktrCapCtl : SET;
		fps: LONGINT;	(* frames per second *)

	(* Initialize the VideoCaptureDevice object. *)
	PROCEDURE &Init*(base: ADDRESS; irq, product, rev: LONGINT);
	BEGIN
		SELF.base := base;
		SELF.irq := irq;
		IF (irq >= 1) & (irq <= 15) THEN
			Objects.InstallHandler(SELF.HandleInterrupt, Machine.IRQ0+irq);
		END;
		IF product = PCIProductBrooktreeBt848 THEN
			IF rev = 0012H THEN
				id := Brooktree848A;
			ELSE
				id := Brooktree848;
			END;
		ELSIF product = PCIProductBrooktreeBt849 THEN
			id := Brooktree849A;
		ELSIF product = PCIProductBrooktreeBt878 THEN
			id := Brooktree878;
		ELSIF product = PCIProductBrooktreeBt879 THEN
			id := Brooktree879;
		END;
		flags := AosInitialized + AosAutoMode + AosDev0;
		dmaProgLoaded := FALSE;
		frameCols := 640;
		frameRows := 260;
		frames := 1;
		pixFormat := 0;
		vbiFlags := {};
		videoAddr := 0;
		videoWidth := 0;
		NEW(i2cBus, id, base);
		NEW(tuner, SELF);
		tuner.frequency := 0;
		tuner.chnl := 0;
		tuner.chnlSet := DefaultChnlSet;
		tuner.afc := 0;
		tuner.radioMode := 0;
		audioMUXSelect := 0;
		audioMuteState := FALSE;
		bt848Card := -1;
		bt848Tuner := -1;
		reverseMute := FALSE;
		slowMSPAudio := 0;
		mspUseMonoSource := FALSE;
		mspSourceSelected := -1;
		audioMUXPresent := TRUE;
		NEW(audio, SELF);
		ProbeCard;
		audio.InitAudioDevices;
		NEW(vbiBuffer);
	END Init;

	(* Finalizes the VideoCaptureDevice object for garbage collection. *)
	PROCEDURE Finalize;
	BEGIN {EXCLUSIVE}
		vbiBuffer.Finalize;
		Objects.RemoveHandler(SELF.HandleInterrupt, Machine.IRQ0 + irq);
		tuner := NIL;
		audio := NIL
	END Finalize;

	(* Handles interrupt requests by the RISC program or any other irq requests for the device. *)
	PROCEDURE HandleInterrupt;
	CONST
		OddField = {0};
		EvenField = {1};
	VAR
		intStatus, devStatus: SET;
		tDecSave: LONGINT;
		field, wField, reqField: SET;
		insPos, i: LONGINT;
	BEGIN
		(* check to see if any interrupts are unmasked on this device. If none are, *)
		(* then we likely got here by way of being on a PCI shared interrupt dispatch *)
		(* list.*)
		IF SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrIntMask)) = AllIntsDisabled THEN
			RETURN;
		END;

		IF DEBUG >= DebugHigh THEN KernelLog.String("{BT848} IRQ handler: "); END;

		IF flags * FileHandlers = {} THEN
			IF DEBUG >= DebugHigh THEN KernelLog.String("(device not open) "); END;
			SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoRiscDisabled));
			SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, AllIntsDisabled));
		END;
		(* record and clear the interrupt status bits *)
		intStatus := SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrIntStat));
		SYSTEM.PUT32(base + BktrIntStat, SYSTEM.VAL(LONGINT, intStatus * (-I2CBits)));	(* don't touch I2C *)
		(* record and clear the device status register *)
		devStatus := SYSTEM.VAL(SET, SYSTEM.GET8(base + BktrDStatus));
		SYSTEM.PUT8(base + BktrDStatus, 0000H);
		IF DEBUG >= DebugHigh THEN
			KernelLog.Ln;
			KernelLog.String("{BT848} IRQ status: "); KernelLog.Bits(intStatus, 0, 32); KernelLog.Ln;
			KernelLog.String("{BT848} Device status: "); KernelLog.Bits(devStatus, 0, 8); KernelLog.Ln;
		END;
		(* if RISC was disabled, restart process again *)
		(* if there was one of the following errors, restart again *)
		IF (intStatus * Bt848IntRiscEn = {}) OR
			(intStatus * (Bt848IntPPErr + Bt848IntRipErr + Bt848IntPAbort + Bt848IntOCErr + Bt848IntSCErr) # {}) OR
			((SYSTEM.GET8(base + BktrTDec) = 0) & (intStatus * TDecBits # {}))
		THEN
			IF DEBUG >= DebugMed THEN
				KernelLog.String("Error");
				IF (intStatus * Bt848IntRiscEn = {}) THEN KernelLog.String("(RISC disabled) "); END;
				IF (intStatus * Bt848IntPPErr # {}) THEN KernelLog.String("(PPErr) "); END;
				IF (intStatus * Bt848IntRipErr # {}) THEN KernelLog.String("(RipErr) "); END;
				IF (intStatus * Bt848IntPAbort # {}) THEN KernelLog.String("(PAbort) "); END;
				IF (intStatus * Bt848IntOCErr # {}) THEN KernelLog.String("(OCErr) "); END;
				IF (intStatus * Bt848IntSCErr # {}) THEN KernelLog.String("(SCErr) "); END;
			END;
			tDecSave := SYSTEM.GET8(base + BktrTDec);
			SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoRiscDisabled));
			SYSTEM.PUT8(base + BktrCapCtl, SYSTEM.VAL(LONGINT, CaptureOff));

			SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, AllIntsDisabled));

			(* reset temporal decimation counter *)
			SYSTEM.PUT8(base + BktrTDec, 0);
			SYSTEM.PUT8(base + BktrTDec, tDecSave);

			(* reset to no-fields captured state *)
			IF flags * (AosContin + AosSynCap) # {} THEN
				IF flags * AosOnlyFieldsMask = AosOnlyOddFields THEN
					flags := flags + AosWantOdd;
				ELSIF flags * AosOnlyFieldsMask = AosOnlyEvenFields THEN
					flags := flags + AosWantEven;
				ELSE
					flags := flags + AosWantMask;
				END;
			END;
			SYSTEM.PUT32(base + BktrRISCStrtAdd, Machine.PhysicalAdr(ADDRESSOF(dmaProg), 4));
			SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoEnabled));
			SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, capControl));

			SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, Bt848IntMysteryBit +
				Bt848IntRiscI + Bt848IntVSync + Bt848IntFmtChg));

			SYSTEM.PUT8(base + BktrCapCtl, SYSTEM.VAL(LONGINT, bktrCapCtl));
		END;
		(* if this is not a RISC program interrupt, return *)
		IF intStatus * Bt848IntRiscI = {} THEN
			IF DEBUG >= DebugHigh THEN KernelLog.String("(not a RISC irq) "); KernelLog.Ln; END;
			RETURN;
		END;
		(* disable future interrupts if no capture mode is selected. *)
		(* This can happen when we are in the process of closing or *)
		(* changing capture modes, otherwise it shouldn't happen. *)
		IF flags * AosCapMask = {} THEN
			IF DEBUG >= DebugHigh THEN KernelLog.String("capture stopped"); KernelLog.Ln; END;
			SYSTEM.PUT8(base + BktrCapCtl, SYSTEM.VAL(LONGINT, CaptureOff));
		END;

		(* determine which field generated this interrupt *)
		IF intStatus * Bt848IntField # {} THEN
			field := EvenField;
			IF DEBUG >= DebugHigh THEN KernelLog.String("(even field) "); END;
		ELSE
			field := OddField;
			IF DEBUG >= DebugHigh THEN KernelLog.String("(odd field) "); END;
		END;

		IF (vbiFlags * VbiCapture # {}) & (vbiFlags * VbiOpen # {}) & (field = EvenField) THEN
			IF DEBUG >= DebugHigh THEN KernelLog.String("(VBI open) "); END;
			(* check if there is room in the buffer to insert the data *)
			IF vbiBuffer.vbiSize + VbiDataSize > VbiBufferSize THEN
				IF DEBUG >= DebugHigh THEN KernelLog.String("(No Space Left in Vbi Buffer) "); KernelLog.Ln END
			ELSE
				BEGIN { EXCLUSIVE }
					(* copy the raw VBI data into the next free slot in the buffer *)
					insPos := vbiBuffer.insertPos;
					FOR i := 0 TO VbiDataSize - 1 DO
						vbiBuffer.data[insPos + i] := vbiData[i]
					END;

					vbiBuffer.insertPos := (vbiBuffer.insertPos + VbiDataSize) MOD VbiBufferSize;
					vbiBuffer.vbiSize := vbiBuffer.vbiSize + VbiDataSize
				END
			END
		END;

		IF flags * AosWantMask = AosWantOdd THEN
			wField := OddField;
		ELSIF flags * AosWantMask = AosWantEven THEN
			wField := EvenField;
		ELSE
			wField := OddField + EvenField;
		END;

		IF flags * AosOnlyFieldsMask = AosOnlyOddFields THEN
			reqField := OddField;
		ELSIF flags * AosOnlyFieldsMask = AosOnlyEvenFields THEN
			reqField := EvenField;
		ELSE
			reqField := OddField + EvenField;
		END;

		IF (field = EvenField) & (wField = EvenField) THEN
			flags := flags * (-AosWantEven);
		ELSIF (field = OddField) & (reqField = OddField) & (wField = OddField) THEN
			flags := flags * (-AosWantOdd);
		ELSIF (field = OddField) & (reqField = (OddField + EvenField)) & (wField = (OddField + EvenField)) THEN
			flags := flags * (-AosWantOdd);
		ELSIF (field = OddField) & (reqField = (OddField + EvenField)) & (wField = OddField) THEN
			flags := flags * (-AosWantOdd);
			flags := flags + AosWantEven;
		ELSE
			IF DEBUG >= DebugHigh THEN KernelLog.String("(out of sync) "); END;
			(* if we are out of sync, start over *)
			IF (flags * (AosContin + AosSynCap) # {}) THEN
				IF flags * AosOnlyFieldsMask = AosOnlyOddFields THEN
					flags := flags + AosWantOdd;
				ELSIF flags * AosOnlyFieldsMask = AosOnlyEvenFields THEN
					flags := flags + AosWantEven;
				ELSE
					flags := flags + AosWantMask;
				END;
			END;
			IF DEBUG >= DebugHigh THEN KernelLog.String("(end)"); KernelLog.Ln; END;
			RETURN;
		END;

		(* if we have a complete frame *)
		IF flags * AosWantMask = {} THEN
			(* post the completion time *)
			(* TO BE DONE *)

			INC(framesCaptured);

			IF flags * AosSingle # {} THEN
				(* stop DMA *)
				SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, AllIntsDisabled));
				(* disable RISC, leave FIFO running *)
				SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoEnabled));
				IF DEBUG >= DebugHigh THEN KernelLog.String("Single frame captured."); KernelLog.Ln; END;
				singleFrameCaptured := TRUE;
			END;

			(* if the user requested to be notified, let them know the frame is complete. *)
			IF notificationProcess # NIL THEN notificationProcess.NotifyHandler; END;

			(* reset the want flags if in continuous or synchronous capture mode *)
			IF flags * (AosContin + AosSynCap) # {} THEN
				IF flags * AosOnlyFieldsMask = AosOnlyOddFields THEN
					flags := flags + AosWantOdd;
				ELSIF flags * AosOnlyFieldsMask = AosOnlyEvenFields THEN
					flags := flags + AosWantEven;
				ELSE
					flags := flags + AosWantMask;
				END;
			END;
		END;
		IF DEBUG >= DebugHigh THEN KernelLog.String("(end)"); KernelLog.Ln; END;
	END HandleInterrupt;

	(** Get Ringbuffer for Vbi (Teletext) data *)
	PROCEDURE GetVbiBuffer* () : TVDriver.VbiBuffer;
	BEGIN
		RETURN vbiBuffer;
	END GetVbiBuffer;

	(** Get the TVTuner object of this VideoCaptureDevice object. *)
	(** return value:	TVTuner object of this card *)
	PROCEDURE GetTuner*(): TVDriver.TVTuner;
	BEGIN
		RETURN tuner;
	END GetTuner;

	(** Get the Audio object of this VideoCaptureDevice object. *)
	(** return value:	Audio object of this card *)
	PROCEDURE GetAudio*(): TVDriver.Audio;
	BEGIN
		RETURN audio;
	END GetAudio;

	(* Probe the card to identify its type and its components. *)
	PROCEDURE ProbeCard;
	CONST Absent = -1;
	VAR
		i, valNirvana: LONGINT;
		cardID: LONGINT;
		eepromI2CAddr, tunerI2CAddr: LONGINT;
		subsystemVendorID, subsystemID: LONGINT;
		byte252, byte253, byte254, byte255: LONGINT;
		eeprom: ARRAY 256 OF CHAR;
		startBlock1, startBlock2, startBlock3, startBlock4: LONGINT;
		dataSizeB1, dataSizeB2, dataSizeB3: LONGINT;
		totalSizeB1, totalSizeB2, totalSizeB3: LONGINT;
		headerSizeB4: LONGINT;
		model, revision: LONGINT;
		tunerCode: LONGINT;
		timer: Kernel.Timer;
		i2cData: LONGINT;
	BEGIN
		NEW(timer);
		(* select all GPIO bits as input *)
		SYSTEM.PUT32(base + BktrGPIOOutEn, 0);
		IF (id = Brooktree878) OR (id = Brooktree879) THEN
			IF DEBUG # DebugOff THEN
				KernelLog.String("{BT848} Probing a Brooktree 878/879 card."); KernelLog.Ln;
			END;
			eepromI2CAddr := LocateEEPROMAddress();
			IF eepromI2CAddr # -1 THEN
				IF DEBUG # DebugOff THEN
					KernelLog.String("{BT848} EEProm address found: "); KernelLog.Hex(eepromI2CAddr, 0); KernelLog.Ln;
				END;
				cardID := CardUnknown;
				card := cards[CardUnknown];
				card.eepromAddr := eepromI2CAddr;
				card.eepromSize := 256 DIV EEPromBlockSize;
				valNirvana := ReadEEProm(0, 256, eeprom);
				ASSERT(valNirvana = 0);
				byte252 := ORD(eeprom[252]);
				byte253 := ORD(eeprom[253]);
				byte254 := ORD(eeprom[254]);
				byte255 := ORD(eeprom[255]);
				subsystemID := SYSTEM.VAL(LONGINT,
					SYSTEM.VAL(SET, ASH(byte252, 8)) + SYSTEM.VAL(SET, byte253));
				subsystemVendorID := SYSTEM.VAL(LONGINT,
					SYSTEM.VAL(SET, ASH(byte254, 8)) + SYSTEM.VAL(SET, byte255));
				IF DEBUG # DebugOff THEN
					KernelLog.String("{BT848} Subsystem ID: "); KernelLog.Hex(subsystemID, 0); KernelLog.Ln;
					KernelLog.String("{BT848} Subsystem vendor ID: "); KernelLog.Hex(subsystemVendorID, 0); KernelLog.Ln;
				END;
				IF subsystemVendorID = PCIVendorHauppauge THEN
					cardID := CardHauppauge;
					card := cards[CardHauppauge];
					card.eepromAddr := eepromI2CAddr;
					card.eepromSize := 256 DIV EEPromBlockSize;
				END;
			END;
		ELSIF (id = Brooktree848) OR (id = Brooktree848A) OR (id = Brooktree849A) THEN
			IF DEBUG # DebugOff THEN
				KernelLog.String("{BT848} Probing a Brooktree 848/848A/849A card."); KernelLog.Ln;
			END;
			(* at i2c address 0xa0, look for Hauppauge *)
			i2cData := i2cBus.I2CRead(PFC8582RAddr);
			IF i2cData # Absent THEN
				IF DEBUG # DebugOff THEN
					KernelLog.String("{BT848} EEProm address found: "); KernelLog.Hex(PFC8582RAddr, 0); KernelLog.Ln;
				END;
				(* read the eeprom contents *)
				card := cards[CardUnknown];
				card.eepromAddr := PFC8582WAddr;
				card.eepromSize := 256 DIV EEPromBlockSize;
				valNirvana := ReadEEProm(0, 256, eeprom);
				ASSERT(valNirvana = 0);
				IF (ORD(eeprom[0]) = 0084H) THEN
					cardID := CardHauppauge;
					card := cards[CardHauppauge];
					card.eepromAddr := PFC8582WAddr;
					card.eepromSize := 256 DIV EEPromBlockSize;
				ELSE
					KernelLog.String("{BT848} Warning: Unknown card type. EEProm data not recognised."); KernelLog.Ln;
				END;
			END;
		END;
		(* check tuner *)
		tunerI2CAddr := LocateTunerAddress();
		IF tunerI2CAddr = Absent THEN
			SelectTuner(NoTuner);
			IF DEBUG # DebugOff THEN
				KernelLog.String("{BT848} No tuner detected.");  KernelLog.Ln;
			END;
		ELSIF cardID = CardHauppauge THEN
			IF card.eepromAddr # 0 THEN
				valNirvana := ReadEEProm(0, 256, eeprom);
				ASSERT(valNirvana = 0);
				startBlock1 := 0;
				dataSizeB1 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(ORD(eeprom[startBlock1 + 2]), 8))
					+ SYSTEM.VAL(SET, ORD(eeprom[startBlock1 + 1])));
				totalSizeB1 := dataSizeB1 + 3;
				startBlock2 := totalSizeB1;
				dataSizeB2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(ORD(eeprom[startBlock2 + 2]), 8))
					+ SYSTEM.VAL(SET, ORD(eeprom[startBlock2 + 1])));
				totalSizeB2 := dataSizeB3 + 3;
				startBlock3 := totalSizeB1 + totalSizeB2;
				dataSizeB3 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ORD(eeprom[startBlock3]))
					* SYSTEM.VAL(SET, 0070H));
				totalSizeB3 := dataSizeB3 + 1;
				startBlock4 := totalSizeB1 + totalSizeB2 + totalSizeB3;
				headerSizeB4 := 1;
				model := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(ORD(eeprom[startBlock1 + 12]), 8))
					+ SYSTEM.VAL(SET, ORD(eeprom[startBlock1 + 11])));
				revision := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(ORD(eeprom[startBlock1 + 15]), 16))
					+ SYSTEM.VAL(SET, ASH(ORD(eeprom[startBlock1 + 14]), 8))
					+ SYSTEM.VAL(SET, ORD(eeprom[startBlock1 + 13])));
				tunerCode := ORD(eeprom[startBlock1 + 9]);
				audioMUXPresent := SYSTEM.VAL(SET, ORD(eeprom[startBlock3 + 3])) * {7} # {};
				IF DEBUG # DebugOff THEN
					KernelLog.String("{BT848} Tuner detected @"); KernelLog.Hex(tunerI2CAddr, 0); KernelLog.Ln;
					KernelLog.String("{BT848} Tuner model: "); KernelLog.Hex(model, 0); KernelLog.Ln;
					KernelLog.String("{BT848} Tuner revision: "); KernelLog.Hex(revision, 0); KernelLog.Ln;
					KernelLog.String("{BT848} Tuner code: "); KernelLog.Hex(tunerCode, 0); KernelLog.Ln;
					IF (audioMUXPresent) THEN KernelLog.String("{BT848} Audio MUX found.");
					ELSE KernelLog.String("{BT848} No audio MUX found."); END; KernelLog.Ln;
				END;
				CASE tunerCode OF
						0005H,
						000AH,
						001AH:	SelectTuner(PhilipsNTSC);
					|  0040H,
						0090H:	SelectTuner(PhilipsSECAM);
					|  0011H,
						0016H:	SelectTuner(PhilipsFR1236SECAM);
					|  0012H,
						0017H:	SelectTuner(PhilipsFR1236NTSC);
					|  0006H,
						0008H,
						000BH,
						001DH,
						0023H:	SelectTuner(PhilipsPALI);
					|  000DH:	SelectTuner(TemicNTSC);
					|  000EH:	SelectTuner(TemicPAL);
					|  000FH:	SelectTuner(TemicPALI);
					|  0015H:	SelectTuner(PhilipsFR1216PAL);
					|  002AH:	mspUseMonoSource := TRUE;
										SelectTuner(PhilipsFR1216PAL);
					|  0030H:	SelectTuner(LGPALBG);
					ELSE
						KernelLog.String("{BT848} Warning: unknown Hauppage tuner ");
						KernelLog.Hex(tunerCode, 0); KernelLog.Ln;
				END;
			END;
		END;
		(* check DBX *)
		IF i2cBus.I2CRead(TDA9850RAddr) # Absent THEN
			card.dbx := TRUE;
			IF DEBUG # DebugOff THEN KernelLog.String("{BT848} DBX found."); KernelLog.Ln; END;
		END;
		(* check MSP *)
		IF (cardID = CardHauppauge) THEN
			SYSTEM.PUT32(base + BktrGPIOOutEn, SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrGPIOOutEn)) + {5});
			SYSTEM.PUT32(base + BktrGPIOData, SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrGPIOData)) + {5});
			timer.Sleep(3);
			SYSTEM.PUT32(base + BktrGPIOData, SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrGPIOData)) * (-{5}));
			timer.Sleep(3);
			SYSTEM.PUT32(base + BktrGPIOData, SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrGPIOData)) + {5});
			timer.Sleep(3);
		END;
		IF i2cBus.I2CRead(MSP3400CRAddr) # Absent THEN
			card.msp3400c := TRUE;
			mspAddr := MSP3400CWAddr;
			audio.MspReadId;
			IF DEBUG # DebugOff THEN
				KernelLog.String("{BT848} MSP3400C found. ["); KernelLog.String(mspVersionString);
				KernelLog.String("]"); KernelLog.Ln;
			END;
		END;
		(* check Dolby Surround Sound DPL3518A sound chip *)
		IF i2cBus.I2CRead(DPL3518ARAddr) # Absent THEN
			card.dpl3518a := TRUE;
			dplAddr := DPL3518AWAddr;
			audio.DplReadId;
			IF DEBUG # DebugOff THEN
				KernelLog.String("{BT848} Dolby Surround Sound DPL3518A sound chip found. [");
				KernelLog.String(dplVersionString); KernelLog.String("]"); KernelLog.Ln;
			END;
		END;
		(* check remote control *)
		remoteControl := FALSE;
		IF i2cBus.I2CRead(HaupRemoteExtRAddr) # Absent THEN
			remoteControl := TRUE;
			remoteControlAddr := HaupRemoteExtRAddr;
			IF DEBUG # DebugOff THEN KernelLog.String("{BT848} External remote control found."); KernelLog.Ln; END;
		END;
		IF i2cBus.I2CRead(HaupRemoteIntRAddr) # Absent THEN
			remoteControl := TRUE;
			remoteControlAddr := HaupRemoteIntRAddr;
			IF DEBUG # DebugOff THEN KernelLog.String("{BT848} Internal remote control found."); KernelLog.Ln; END;
		END;
		(* poll remote control 5 times to turn off the LED *)
		IF remoteControl THEN
			FOR i := 1 TO 5 DO
				valNirvana := i2cBus.I2CRead(Machine.Ensure32BitAddress (base) + remoteControlAddr);
			END;
		END;
		xtalPLLMode := Bt848UseXTALS;
		(* for Bt878 cards switch to PLL mode *)
		IF (id = Brooktree878) OR (id = Brooktree879) THEN
			xtalPLLMode := Bt848UsePLL;
		END;
		card.tunerPLLAddr := tunerI2CAddr;
	END ProbeCard;

	(* Selects the tuner. *)
	(* tunerType:	type of the tuner *)
	PROCEDURE SelectTuner(tunerType: LONGINT);
	BEGIN
		card.tuner := tuners[tunerType];
		IF DEBUG # DebugOff THEN
			KernelLog.String("{BT848} Tuner selected: "); KernelLog.String(card.tuner.name); KernelLog.Ln;
		END;
	END SelectTuner;

	(* Set the number of frames per second. *)
	(* frameRate:	number of frames/s *)
	PROCEDURE SetFPS(frameRate: LONGINT);
	VAR
		fp: FormatParams;
		iFlag: LONGINT;
	BEGIN
		fp := formatParams[formatParameters];
		IF flags * AosOnlyFieldsMask = AosOnlyEvenFields THEN
			IF DEBUG # DebugOff THEN KernelLog.String("{BT848} SetFPS: even fields"); KernelLog.Ln; END;
			flags := flags + AosWantEven;
			iFlag := 1;
		ELSIF flags * AosOnlyFieldsMask = AosOnlyOddFields THEN
			IF DEBUG # DebugOff THEN KernelLog.String("{BT848} SetFPS: odd fields"); KernelLog.Ln; END;
			flags := flags + AosWantOdd;
			iFlag := 1;
		ELSE
			IF DEBUG # DebugOff THEN KernelLog.String("{BT848} SetFPS: odd + even fields"); KernelLog.Ln; END;
			flags := flags + AosWantMask;
			iFlag := 2;
		END;

		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoRiscDisabled));
		SYSTEM.PUT32(base + BktrIntStat, SYSTEM.VAL(LONGINT, AllIntsCleared));

		fps := frameRate;
		SYSTEM.PUT8(base + BktrTDec, 0);

		IF fps < fp.frameRate THEN
			SYSTEM.PUT8(base + BktrTDec, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, iFlag*(fp.frameRate - fps)) *
				SYSTEM.VAL(SET, 003FH)));
		ELSE
			SYSTEM.PUT8(base + BktrTDec, 0);
		END;
	END SetFPS;

	(* Split a DMA transfer if it is too big. *)
	(* Constructs a sequence of the RISC program. *)
	(* prog:	RISC program *)
	(* dmaIndex:	pointer to current RISC program index *)
	(* width:	width of the line to process *)
	(* op:	RISC operation *)
	(* bpp:	bytes per pixel *)
	(* targetBuffer:	pointer to the physical address of the target buffer for video data *)
	(* cols:	number of columns of the scan line *)
	PROCEDURE SplitDmaTransfer(VAR prog: ARRAY OF LONGINT; VAR dmaIndex: LONGINT; width: LONGINT;
		op: SET; bpp: LONGINT; targetBuffer: LONGINT; cols: LONGINT);
	VAR
		pixelFormat: PixelFormat;
		startSkip, skip: LONGINT;
		flag1, flag2: SET;
	BEGIN
		pixelFormat := pixelFormatTable[pixFormat];
		startSkip := 0;
		IF (pixelFormat.type = AosPixTypeRGB) & (pixelFormat.bpp = 3) THEN
			CASE targetBuffer MOD 4 OF
					2:	startSkip := 4;
				|  1:	startSkip := 8;
			END;
		END;
		skip := 0;

		IF (width * bpp) < DmaBt848Split THEN
			IF width = cols THEN
				flag1 := OpSOL + OpEOL;
			ELSIF currentCol = 0 THEN
				flag1 := OpSOL;
			ELSIF currentCol = cols THEN
				flag1 := OpEOL;
			ELSE
				flag1 := {};
			END;
			IF (flag1 * OpSOL # {}) & (startSkip > 0) THEN
				prog[dmaIndex] := SYSTEM.VAL(LONGINT, OpSkip + OpSOL + SYSTEM.VAL(SET, startSkip));
				INC(dmaIndex);
				flag1 := flag1 * (-OpSOL);
				skip := startSkip;
			END;
			prog[dmaIndex] := SYSTEM.VAL(LONGINT, op + flag1 + SYSTEM.VAL(SET, width*bpp - skip));
			INC(dmaIndex);
			IF op * OpSkip = {} THEN
				prog[dmaIndex] := targetBuffer;
			END;
			targetBuffer := targetBuffer + width * bpp;
			currentCol := currentCol + width;
		ELSE
			IF (currentCol = 0) & (width = cols) THEN
				flag1 := OpSOL; flag2 := OpEOL;
			ELSIF currentCol = 0 THEN
				flag1 := OpSOL; flag2 := {};
			ELSIF currentCol >= cols THEN
				flag1 := {}; flag2 := OpEOL;
			ELSE
				flag1 := {}; flag2 := {};
			END;
			IF (flag1 * OpSOL # {}) & (startSkip > 0) THEN
				prog[dmaIndex] := SYSTEM.VAL(LONGINT, OpSkip + OpSOL + SYSTEM.VAL(SET, startSkip));
				INC(dmaIndex);
				flag1 := flag1 * (-OpSOL);
				skip := startSkip;
			END;
			prog[dmaIndex] := SYSTEM.VAL(LONGINT, op + flag1 + SYSTEM.VAL(SET, width*bpp DIV 2 - skip));
			INC(dmaIndex);
			IF op * OpSkip = {} THEN
				prog[dmaIndex] := targetBuffer; INC(dmaIndex);
			END;
			targetBuffer := targetBuffer + width * bpp DIV 2;
			IF op * OpWrite # {} THEN
				op := OpWriteC;
			END;
			prog[dmaIndex] := SYSTEM.VAL(LONGINT, op + flag2 + SYSTEM.VAL(SET, width * bpp DIV 2));
			INC(dmaIndex);
			targetBuffer := targetBuffer + width * bpp DIV 2;
			currentCol := currentCol + width;
		END;
	END SplitDmaTransfer;

	(* Constructs a RISC program for RGB and VBI data capture. *)
	(* mode:	AosOddField, AosEvenField, or AosInterlaced *)
	(* cols:	number of columns of a frame *)
	(* rows:	number of rows of a frame *)
	(* interlace:	interlace value *)
	PROCEDURE DmaRgbVbi(mode: LONGINT; cols: LONGINT; rows: LONGINT; interlace: LONGINT);
	VAR
		targetBuffer, buffer, width: LONGINT;
		pitch: LONGINT;
		dmaIndex, loopPoint, q: LONGINT;
		temp1: LONGINT;
		vbiSamples: LONGINT;	(* VBI samples per line *)
		vbiLines: LONGINT;	(* VBI lines per field *)
		numDWords: LONGINT;	(* DWords per line *)
		pixelFormat: PixelFormat;
	BEGIN
		pixelFormat := pixelFormatTable[pixFormat];
		vbiSamples := formatParams[formatParameters].vbiNumSamples;
		vbiLines := formatParams[formatParameters].vbiNumLines;
		numDWords := vbiSamples DIV 4;

		SYSTEM.PUT8(base + BktrColorFmt, pixelFormat.colorFormat);
		SYSTEM.PUT8(base + BktrADC, SYSTEM.VAL(LONGINT, SyncLevel));
		SYSTEM.PUT8(base + BktrVBIPackSize, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, numDWords) * {0..7}));
		SYSTEM.PUT8(base + BktrVBIPackDel, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(numDWords, -8)) * {0}));	(* no hdelay, no ext frame *)
		SYSTEM.PUT8(base + BktrOForm, 0000H);
		temp1 := SYSTEM.GET8(base + BktrEVScaleHi);
		SYSTEM.PUT8(base + BktrEVScaleHi,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + SYSTEM.VAL(SET, 0040H)));	(* set chroma comb *)
		temp1 := SYSTEM.GET8(base + BktrOVScaleHi);
		SYSTEM.PUT8(base + BktrOVScaleHi,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + SYSTEM.VAL(SET, 0040H)));
		temp1 := SYSTEM.GET8(base + BktrEVScaleHi);
		SYSTEM.PUT8(base + BktrEVScaleHi,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-SYSTEM.VAL(SET, 0080H))));	(* clear Ycomb *)
		temp1 := SYSTEM.GET8(base + BktrOVScaleHi);
		SYSTEM.PUT8(base + BktrOVScaleHi,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-SYSTEM.VAL(SET, 0080H))));
		(* disable gamma correction removal *)
		temp1 := SYSTEM.GET8(base + BktrColorCtl);
		SYSTEM.PUT8(base + BktrColorCtl,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848ColorCtlGamma));

		IF (cols > 385) THEN
			SYSTEM.PUT8(base + BktrEVTC, 0);
			SYSTEM.PUT8(base + BktrOVTC, 0);
		ELSE
			SYSTEM.PUT8(base + BktrEVTC, 1);
			SYSTEM.PUT8(base + BktrOVTC, 1);
		END;
		capControl := {0..3};
		ASSERT((videoAddr # 0) & (videoWidth # 0));
		targetBuffer := videoAddr;
		pitch := videoWidth;
		buffer := targetBuffer;
		(* wait for the VRE sync marking the end of the even and *)
		(* the start of the odd field. Resync here. *)
		dmaIndex := 0;
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrResync + BktrVRE); INC(dmaIndex);
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
		loopPoint := dmaIndex;
		(* store the VBI data *)
		(* look for sync with packed data *)
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrFM1); INC(dmaIndex);
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
		FOR q := 0 TO vbiLines-1 DO
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpWrite + OpSOL + OpEOL + SYSTEM.VAL(SET, vbiSamples));
			INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT,
				Machine.PhysicalAdr(ADDRESSOF(vbiData), 4) + (q * VbiLineSize)); INC(dmaIndex);
		END;

		IF (mode = AosOddField) OR (mode = AosInterlaced) THEN
			(* store the odd field video image *)
			(* look for sync with packed data *)
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrFM1); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
			width := cols;
			FOR q := 0 TO (rows DIV interlace)-1 DO
				IF TRUE THEN
					currentCol := 0;
					SplitDmaTransfer(dmaProg, dmaIndex, width, OpWrite, pixelFormat.bpp, targetBuffer, cols);
				ELSE
					(* TO BE DONE: clipping *)
				END;
				targetBuffer := targetBuffer + interlace * pitch;
			END;
		END;
		(* grab the even field *)
		(* look for the VRO, end of odd field, marker *)
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrGenIRQ + BktrResync + BktrVRO); INC(dmaIndex);
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
		(* store the VBI data *)
		(* look for sync with packed data *)
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrFM1); INC(dmaIndex);
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
		FOR q := 0 TO vbiLines-1 DO
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpWrite + OpSOL + OpEOL + SYSTEM.VAL(SET, vbiSamples));
			INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT,
				Machine.PhysicalAdr(ADDRESSOF(vbiData), 4) + ((q+VbiMaxLines)*VbiLineSize)); INC(dmaIndex);
		END;

		(* store the video image *)
		IF mode = AosEvenField THEN
			targetBuffer := buffer;
		ELSIF mode = AosInterlaced THEN
			targetBuffer := buffer + pitch;
		END;
		IF (mode = AosEvenField) OR (mode = AosInterlaced) THEN
			(* look for sync with packed data *)
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrFM1); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
			width := cols;
			FOR q := 0 TO (rows DIV interlace)-1 DO
				IF TRUE THEN
					currentCol := 0;
					SplitDmaTransfer(dmaProg, dmaIndex, width, OpWrite, pixelFormat.bpp, targetBuffer, cols);
				ELSE
					(* TO BE DONE: clipping *)
				END;
				targetBuffer := targetBuffer + interlace * pitch;
			END;
		END;
		(* look for end of even field *)
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrGenIRQ + BktrResync + BktrVRE); INC(dmaIndex);
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);

		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpJump); INC(dmaIndex);
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT,
			Machine.PhysicalAdr(ADDRESSOF(dmaProg[loopPoint]), 4)); INC(dmaIndex);
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
	END DmaRgbVbi;

	(* Constructs a RISC program for RGB data capture. *)
	(* mode:	AosOddField, AosEvenField, or AosInterlaced *)
	(* cols:	number of columns of a frame *)
	(* rows:	number of rows of a frame *)
	(* interlace:	interlace value *)
	PROCEDURE DmaRgb(mode: LONGINT; cols, rows: LONGINT; interlace: LONGINT);
	VAR
		targetBuffer, buffer, width: LONGINT;
		pitch: LONGINT;
		dmaIndex, q: LONGINT;
		temp1: LONGINT;
		pixelFormat: PixelFormat;
	BEGIN
		pixelFormat := pixelFormatTable[pixFormat];
		SYSTEM.PUT8(base + BktrColorFmt, pixelFormat.colorFormat);
		SYSTEM.PUT8(base + BktrVBIPackSize, 0);
		SYSTEM.PUT8(base + BktrVBIPackDel, 0);
		SYSTEM.PUT8(base + BktrADC, SYSTEM.VAL(LONGINT, SyncLevel));

		SYSTEM.PUT8(base + BktrOForm, 0000H);

		temp1 := SYSTEM.GET8(base + BktrEVScaleHi);	(* set chroma comb *)
		SYSTEM.PUT8(base + BktrEVScaleHi,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + SYSTEM.VAL(SET, 0040H)));
		temp1 := SYSTEM.GET8(base + BktrOVScaleHi);
		SYSTEM.PUT8(base + BktrOVScaleHi,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + SYSTEM.VAL(SET, 0040H)));
		temp1 := SYSTEM.GET8(base + BktrEVScaleHi);	(* clear Ycomb *)
		SYSTEM.PUT8(base + BktrEVScaleHi,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-SYSTEM.VAL(SET, 0080H))));
		temp1 := SYSTEM.GET8(base + BktrOVScaleHi);
		SYSTEM.PUT8(base + BktrOVScaleHi,
			SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-SYSTEM.VAL(SET, 0080H))));

		(* disable gamma correction removal *)
		temp1 := SYSTEM.GET8(base + BktrColorCtl);
		SYSTEM.PUT8(base + BktrColorCtl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848ColorCtlGamma));

		IF cols > 385 THEN
			SYSTEM.PUT8(base + BktrEVTC, 0);
			SYSTEM.PUT8(base + BktrOVTC, 0);
		ELSE
			SYSTEM.PUT8(base + BktrEVTC, 1);
			SYSTEM.PUT8(base + BktrOVTC, 1);
		END;
		capControl := {0..3};

		dmaIndex := 0;

		(* construct write *)
		ASSERT((videoAddr # 0) & (videoWidth # 0));
		targetBuffer := videoAddr;
		pitch := videoWidth;

		buffer := targetBuffer;

		(* construct sync : for video packet format *)
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrResync + BktrFM1); INC(dmaIndex);
		dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
		width := cols;
		FOR q := 0 TO rows DIV interlace - 1 DO
			IF TRUE THEN
				currentCol := 0;
				SplitDmaTransfer(dmaProg, dmaIndex, width, OpWrite, pixelFormat.bpp, targetBuffer, cols);
			ELSE
				(* TO BE DONE: clipping *)
			END;
			targetBuffer := targetBuffer + interlace * pitch;
		END;

		IF mode = 1 THEN
			(* sync vre *)
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrGenIRQ + BktrVRO); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpJump); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, Machine.PhysicalAdr(ADDRESSOF(dmaProg[0]),
				LEN(dmaProg) * SIZEOF(LONGINT)));
			dmaProgLength := dmaIndex;
			RETURN;
		ELSIF mode = 2 THEN
			(* sync vro *)
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrGenIRQ + BktrVRE); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpJump); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, Machine.PhysicalAdr(ADDRESSOF(dmaProg[0]),
				LEN(dmaProg) * SIZEOF(LONGINT)));
			dmaProgLength := dmaIndex;
			RETURN;
		ELSIF mode = 3 THEN
			(* sync vro *)
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrGenIRQ + BktrResync + BktrVRO); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpJump); INC(dmaIndex);
			dmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, Machine.PhysicalAdr(ADDRESSOF(oddDmaProg[0]),
				LEN(oddDmaProg) * SIZEOF(LONGINT)));
		END;
		dmaProgLength := dmaIndex;

		IF interlace = 2 THEN
			targetBuffer := buffer + pitch;

			dmaIndex := 0;

			(* sync vre IRQ bit *)
			oddDmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrResync + BktrFM1); INC(dmaIndex);
			oddDmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0);
			width := cols;
			FOR q := 0 TO rows DIV interlace - 1 DO
				IF TRUE THEN
					currentCol := 0;
					SplitDmaTransfer(oddDmaProg, dmaIndex, width, OpWrite, pixelFormat.bpp, targetBuffer, cols);
				ELSE
					(* TO BE DONE: clipping *)
				END;
				targetBuffer := targetBuffer + interlace * pitch;
			END;
		END;

		(* sync vre IRQ bit *)
		oddDmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpSync + BktrGenIRQ + BktrResync + BktrVRE);
			INC(dmaIndex);
		oddDmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0); INC(dmaIndex);
		oddDmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, OpJump); INC(dmaIndex);
		oddDmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, Machine.PhysicalAdr(ADDRESSOF(dmaProg[0]),
			LEN(dmaProg) * SIZEOF(LONGINT))); INC(dmaIndex);
		oddDmaProg[dmaIndex] := SYSTEM.VAL(LONGINT, 0);
		oddDmaProgLength := dmaIndex;
	END DmaRgb;

	(* Construct the RISC program sequence. *)
	(* mode:	AosOddField, AosEvenField, or AosInterlaced *)
	PROCEDURE BuildDmaProg(mode: LONGINT);
	VAR
		temp1, temp2, temp3: LONGINT;
		fp: FormatParams;
		pixelFormat: PixelFormat;
		interlace: LONGINT;
	BEGIN
		notificationProcess.NotifyHandler;
		fp := formatParams[formatParameters];
		pixelFormat := pixelFormatTable[pixFormat];

		SYSTEM.PUT32(base + BktrIntMask, AllIntsDisabled);

		(* disable FIFO and RISC, leave other bits alone *)
		temp1 := SYSTEM.GET16(base + BktrGPIODmaCtl);
		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-FifoRiscEnabled)));
		(* set video parameters *)
		(* horizontal scale *)
		IF captureAreaEnabled THEN
			temp2 := ENTIER(1.0 * fp.hTotal * captureAreaXSize * 4096 / fp.scaledHTotal / frameCols - 4096);
		ELSE
			temp2 := ENTIER(1.0 * fp.hTotal * fp.scaledHActive * 4096 / fp.scaledHTotal / frameCols - 4096);
		END;
		SYSTEM.PUT8(base + BktrEHScaleLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));
		SYSTEM.PUT8(base + BktrOHScaleLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));
		SYSTEM.PUT8(base + BktrEHScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(temp2, -8)) * {0..7}));
		SYSTEM.PUT8(base + BktrOHScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(temp2, -8)) * {0..7}));

		(* horizontal active *)
		temp2 := frameCols;
		SYSTEM.PUT8(base + BktrEHActiveLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));
		SYSTEM.PUT8(base + BktrOHActiveLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));
		temp1 := SYSTEM.GET8(base + BktrECrop);
		SYSTEM.PUT8(base + BktrECrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-{0,1})));
		temp1 := SYSTEM.GET8(base + BktrOCrop);
		SYSTEM.PUT8(base + BktrOCrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-{0,1})));
		temp1 := SYSTEM.GET8(base + BktrECrop);
		SYSTEM.PUT8(base + BktrECrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp2, -8)) * {0,1})));
		temp1 := SYSTEM.GET8(base + BktrOCrop);
		SYSTEM.PUT8(base + BktrOCrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp2, -8)) * {0,1})));

		(* horizontal delay *)
		IF captureAreaEnabled THEN
			temp2 := ENTIER(1.0 * (fp.hDelay * fp.scaledHActive + captureAreaXOffset * fp.scaledHTotal) * frameCols
				/ captureAreaXSize * fp.hActive);
		ELSE
			temp2 := ENTIER(1.0 * fp.hDelay * frameCols / fp.hActive);
		END;
		temp2 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * SYSTEM.VAL(SET, 03FEH));
		SYSTEM.PUT8(base + BktrEDelayLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));
		SYSTEM.PUT8(base + BktrODelayLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));
		temp1 := SYSTEM.GET8(base + BktrECrop);
		SYSTEM.PUT8(base + BktrECrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) *
			(-SYSTEM.VAL(SET, 000CH))));
		temp1 := SYSTEM.GET8(base + BktrOCrop);
		SYSTEM.PUT8(base + BktrOCrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) *
			(-SYSTEM.VAL(SET, 000CH))));
		temp1 := SYSTEM.GET8(base + BktrECrop);
		SYSTEM.PUT8(base + BktrECrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp2, -6)) * SYSTEM.VAL(SET, 000CH))));
		temp1 := SYSTEM.GET8(base + BktrOCrop);
		SYSTEM.PUT8(base + BktrOCrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp2, -6)) * SYSTEM.VAL(SET, 000CH))));

		(* vertical scale *)
		IF captureAreaEnabled THEN
			IF (flags * AosOnlyEvenFields # {}) OR (flags * AosOnlyOddFields # {}) THEN
				temp3 := ENTIER(1.0 * 65536 - (((captureAreaYSize * 256 + (frameRows DIV 2)) DIV frameRows) - 512));
			ELSE
				temp3 := ENTIER(1.0 * 65536 - (((captureAreaYSize * 512 + (frameRows DIV 2)) DIV frameRows) - 512));
			END;
		ELSE
			IF (flags * AosOnlyEvenFields # {}) OR (flags * AosOnlyOddFields # {}) THEN
				temp3 := ENTIER(1.0 * 65536 - (((fp.vActive * 256 + (frameRows DIV 2)) DIV frameRows) - 512));
			ELSE
				temp3 := ENTIER(1.0 * 65536 - (((fp.vActive * 512 + (frameRows DIV 2)) DIV frameRows) - 512));
			END;
		END;
		temp3 := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp3) * {0..12});
		SYSTEM.PUT8(base + BktrEVScaleLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp3) * {0..7}));
		SYSTEM.PUT8(base + BktrOVScaleLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp3) * {0..7}));
		temp1 := SYSTEM.GET8(base + BktrEVScaleHi);
		SYSTEM.PUT8(base + BktrEVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) *
			(-{0..4})));
		temp1 := SYSTEM.GET8(base + BktrOVScaleHi);
		SYSTEM.PUT8(base + BktrOVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) *
			(-{0..4})));
		temp1 := SYSTEM.GET8(base + BktrEVScaleHi);
		SYSTEM.PUT8(base + BktrEVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp3, -8)) * {0..4})));
		temp1 := SYSTEM.GET8(base + BktrOVScaleHi);
		SYSTEM.PUT8(base + BktrOVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp3, -8)) * {0..4})));

		(* vertical active *)
		IF captureAreaEnabled THEN
			temp2 := captureAreaYSize;
		ELSE
			temp2 := fp.vActive;
		END;
		temp1 := SYSTEM.GET8(base + BktrECrop);
		SYSTEM.PUT8(base + BktrECrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-SYSTEM.VAL(SET, 0030H))));
		temp1 := SYSTEM.GET8(base + BktrECrop);
		SYSTEM.PUT8(base + BktrECrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp2, -4)) * SYSTEM.VAL(SET, 0030H))));
		SYSTEM.PUT8(base + BktrEVActiveLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));
		temp1 := SYSTEM.GET8(base + BktrOCrop);
		SYSTEM.PUT8(base + BktrOCrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-SYSTEM.VAL(SET, 0030H))));
		temp1 := SYSTEM.GET8(base + BktrOCrop);
		SYSTEM.PUT8(base + BktrOCrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp2, -4)) * SYSTEM.VAL(SET, 0030H))));
		SYSTEM.PUT8(base + BktrOVActiveLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));

		(* vertical delay *)
		IF captureAreaEnabled THEN
			temp2 := fp.vDelay + captureAreaYOffset;
		ELSE
			temp2 := fp.vDelay;
		END;
		temp1 := SYSTEM.GET8(base + BktrECrop);
		SYSTEM.PUT8(base + BktrECrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-SYSTEM.VAL(SET, 00C0H))));
		temp1 := SYSTEM.GET8(base + BktrECrop);
		SYSTEM.PUT8(base + BktrECrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp2, -2)) * SYSTEM.VAL(SET, 00C0H))));
		SYSTEM.PUT8(base + BktrEVDelayLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));
		temp1 := SYSTEM.GET8(base + BktrOCrop);
		SYSTEM.PUT8(base + BktrOCrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-SYSTEM.VAL(SET, 00C0H))));
		temp1 := SYSTEM.GET8(base + BktrOCrop);
		SYSTEM.PUT8(base + BktrOCrop, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			(SYSTEM.VAL(SET, ASH(temp2, -2)) * SYSTEM.VAL(SET, 00C0H))));
		SYSTEM.PUT8(base + BktrOVDelayLo, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp2) * {0..7}));
		(* end of video params *)

		IF (xtalPLLMode = Bt848UsePLL) & (fp.iformXTSel = SYSTEM.VAL(LONGINT, Bt848IFormXXT1)) THEN
			IF DEBUG >= DebugMed THEN
				KernelLog.String("{BT848} BuildDmaProg: PLL mode selected"); KernelLog.Ln;
			END;
			SYSTEM.PUT8(base + BktrTGCtrl, SYSTEM.VAL(LONGINT, Bt848TGCtrlTGCKIPLL));	(* select PLL mode *)
		ELSE
			IF DEBUG >= DebugMed THEN
				KernelLog.String("{BT848} BuildDmaProg: normal xtal0/xtal1 mode selected"); KernelLog.Ln;
			END;
			SYSTEM.PUT8(base + BktrTGCtrl, SYSTEM.VAL(LONGINT, Bt848TGCtrlTGCKIXTAL));	(* select normal xtal 0/xtal 1 mode *)
		END;

		(* capture control *)
		CASE mode OF
				AosEvenField:
					IF DEBUG >= DebugMed THEN
						KernelLog.String("{BT848} BuildDmaProg: capture control, even field"); KernelLog.Ln;
					END;
					bktrCapCtl := Bt848CapCtlDithFrame + Bt848CapCtlEven;
					temp1 := SYSTEM.GET8(base + BktrEVScaleHi);
					SYSTEM.PUT8(base + BktrEVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-{5})));
					temp1 := SYSTEM.GET8(base + BktrOVScaleHi);
					SYSTEM.PUT8(base + BktrOVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-{5})));
					interlace := 1;
			|   AosOddField:
					IF DEBUG >= DebugMed THEN
						KernelLog.String("{BT848} BuildDmaProg: capture control, odd field"); KernelLog.Ln;
					END;
					bktrCapCtl := Bt848CapCtlDithFrame + Bt848CapCtlOdd;
					temp1 := SYSTEM.GET8(base + BktrEVScaleHi);
					SYSTEM.PUT8(base + BktrEVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-{5})));
					temp1 := SYSTEM.GET8(base + BktrOVScaleHi);
					SYSTEM.PUT8(base + BktrOVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-{5})));
					interlace := 1;
			ELSE
					IF DEBUG >= DebugMed THEN
						KernelLog.String("{BT848} BuildDmaProg: capture control, interlaced"); KernelLog.Ln;
					END;
					bktrCapCtl := Bt848CapCtlDithFrame + Bt848CapCtlEven + Bt848CapCtlOdd;
					temp1 := SYSTEM.GET8(base + BktrEVScaleHi);
					SYSTEM.PUT8(base + BktrEVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + {5}));
					temp1 := SYSTEM.GET8(base + BktrOVScaleHi);
					SYSTEM.PUT8(base + BktrOVScaleHi, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + {5}));
					interlace := 2;
		END;

		SYSTEM.PUT32(base + BktrRISCStrtAdd, Machine.PhysicalAdr(ADDRESSOF(dmaProg), 4));

		vbiFlags := vbiFlags * (-VbiCapture);	(* default - no VBI capture *)

		IF pixelFormat.type = AosPixTypeRGB THEN
			IF (vbiFlags * VbiOpen # {}) OR (formatParameters = Bt848IFormFPalBDGHI) OR
				(formatParameters = Bt848IFormFSecam) THEN
				bktrCapCtl := bktrCapCtl + Bt848CapCtlVBIEven + Bt848CapCtlVBIOdd;
				vbiFlags := vbiFlags + VbiCapture;
				DmaRgbVbi(mode, frameCols, frameRows, interlace);
			ELSE
				DmaRgb(mode, frameCols, frameRows, interlace);
			END;
		ELSIF pixelFormat.type = AosPixTypeYUV THEN
			KernelLog.String("DMA program YUV not implemented yet."); KernelLog.Ln;
		ELSIF pixelFormat.type = AosPixTypeYUVPacked THEN
			KernelLog.String("DMA program YUV packed not implemented yet."); KernelLog.Ln;
		ELSIF pixelFormat.type = AosPixTypeYUV12 THEN
			KernelLog.String("DMA program YUV12 not implemented yet."); KernelLog.Ln;
		END;
	END BuildDmaProg;

	(** Install a notification handler for RISC events. *)
	(** handler:	procedure of type NotificationHandler *)
	PROCEDURE InstallNotificationHandler*(handler: NotificationHandler);
	BEGIN
		ASSERT(notificationProcess = NIL);
		NEW(notificationProcess, handler);
	END InstallNotificationHandler;

	(** Outputs a dump of the RISC program. *)
	PROCEDURE DumpRisc*;
	VAR
		pc, ipc, spc: ADDRESS; errPC, data: LONGINT;
	BEGIN
		pc := SYSTEM.GET32(base + BktrRISCStrtAdd);
		errPC := SYSTEM.GET32(base + BktrRISCCount);
		Machine.MapPhysical(pc, SIZEOF(LONGINT) * LEN(dmaProg), ipc);
		ASSERT(ipc # Machine.NilAdr);
		spc := ipc;
		data := SYSTEM.GET32(ipc);
		KernelLog.String("{BT848} *** RISC DUMP START ***"); KernelLog.Ln;
		KernelLog.String("{BT848} BktrRISCStrtAddr: "); KernelLog.Hex(pc, 0); KernelLog.Ln;
		KernelLog.String("{BT848} error address: "); KernelLog.Hex(errPC, 0); KernelLog.Ln;
		KernelLog.String("{BT848} risc jump addr: "); KernelLog.Hex(Machine.PhysicalAdr(ADDRESSOF(dmaProg), 0), 0);
			KernelLog.Ln;
		i := 0;
		REPEAT
			CASE SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(data, -28)) * {0..3}) OF
					01H:
						KernelLog.String("{BT848} "); KernelLog.Hex(Machine.PhysicalAdr(ipc, 4), 0);
							KernelLog.String(" write:"); KernelLog.Ln;
						KernelLog.String("{BT848}    bytes: "); KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..11}), 0);
							KernelLog.Ln;
						KernelLog.String("{BT848}    enables: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 12, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status set: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 16, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status reset: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 20, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    irq: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 24, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 25, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    eol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 26, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    sol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 27, 1); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    target: "); KernelLog.Hex(data, 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
				|  09H:
						KernelLog.String("{BT848} "); KernelLog.Hex(Machine.PhysicalAdr(ipc, 4), 0);
							KernelLog.String(" write123:"); KernelLog.Ln;
						KernelLog.String("{BT848}    bytes FIFO 1: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..11}), 0); KernelLog.Ln;
						KernelLog.String("{BT848}    enables: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 12, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status set: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 16, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status reset: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 20, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    irq: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 24, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 25, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    eol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 26, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    sol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 27, 1); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    bytes FIFO 2: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..11}), 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    bytes FIFO 3: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(data, 16)) * {0..11}), 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    target 1: "); KernelLog.Hex(data, 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    target 2: "); KernelLog.Hex(data, 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    target 3: "); KernelLog.Hex(data, 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
				|  0BH:
						KernelLog.String("{BT848} "); KernelLog.Hex(Machine.PhysicalAdr(ipc, 4), 0);
							KernelLog.String(" write1s23:"); KernelLog.Ln;
						KernelLog.String("{BT848}    bytes FIFO 1: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..11}), 0); KernelLog.Ln;
						KernelLog.String("{BT848}    enables: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 12, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status set: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 16, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status reset: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 20, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    irq: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 24, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 25, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    eol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 26, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    sol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 27, 1); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    bytes FIFO 2: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..11}), 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    bytes FIFO 3: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(data, 16)) * {0..11}), 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    target 1: "); KernelLog.Hex(data, 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
				| 05H:
						KernelLog.String("{BT848} "); KernelLog.Hex(Machine.PhysicalAdr(ipc, 4), 0);
							KernelLog.String(" writec:"); KernelLog.Ln;
						KernelLog.String("{BT848}    bytes FIFO 1: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..11}), 0); KernelLog.Ln;
						KernelLog.String("{BT848}    enables: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 12, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status set: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 16, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status reset: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 20, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    irq: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 24, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 25, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    eol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 26, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    sol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 27, 1); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
				| 02H:
						KernelLog.String("{BT848} "); KernelLog.Hex(Machine.PhysicalAdr(ipc, 4), 0);
							KernelLog.String(" skip:"); KernelLog.Ln;
						KernelLog.String("{BT848}    bytes FIFO 1: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..11}), 0); KernelLog.Ln;
						KernelLog.String("{BT848}    enables: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 12, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status set: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 16, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status reset: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 20, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    irq: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 24, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 25, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    eol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 26, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    sol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 27, 1); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
				| 0AH:
						KernelLog.String("{BT848} "); KernelLog.Hex(Machine.PhysicalAdr(ipc, 4), 0);
							KernelLog.String(" skip123:"); KernelLog.Ln;
						KernelLog.String("{BT848}    bytes FIFO 1: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..11}), 0); KernelLog.Ln;
						KernelLog.String("{BT848}    enables: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 12, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status set: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 16, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status reset: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 20, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    irq: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 24, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 25, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    eol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 26, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    sol: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 27, 1); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    bytes FIFO 2: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..11}), 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    bytes FIFO 3: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(data, 16)) * {0..11}), 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
				|  07H:
						KernelLog.String("{BT848} "); KernelLog.Hex(Machine.PhysicalAdr(ipc, 4), 0);
							KernelLog.String(" jump:"); KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: ");
							KernelLog.Int(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..15}), 0); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status set: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 16, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status reset: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 20, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    irq: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 24, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 25, 1); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    target: ");
							KernelLog.Hex(data, 0); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
				|  08H:
						KernelLog.String("{BT848} "); KernelLog.Hex(Machine.PhysicalAdr(ipc, 4), 0);
							KernelLog.String(" sync:"); KernelLog.Ln;
						KernelLog.String("{BT848}    status: ");
						CASE SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) * {0..3}) OF
							   06H:	KernelLog.String("FM1");
							| 0EH:	KernelLog.String("FM3");
							| 02H:	KernelLog.String("SOL");
							| 01H:	KernelLog.String("EOL4");
							| 0DH:	KernelLog.String("EOL3");
							| 09H:	KernelLog.String("EOL2");
							| 05H:	KernelLog.String("EOL1");
							| 04H:	KernelLog.String("VRE");
							| 0CH:	KernelLog.String("VRO");
							| 00H:	KernelLog.String("PXV");
							ELSE	KernelLog.String("*** UNKNOWN ***");
						END;
						KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: ");
							KernelLog.Bits(SYSTEM.VAL(SET, data), 4, 11); KernelLog.Ln;
						KernelLog.String("{BT848}    resync: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 15, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status set: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 16, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    risc status reset: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 20, 4); KernelLog.Ln;
						KernelLog.String("{BT848}    irq: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 24, 1); KernelLog.Ln;
						KernelLog.String("{BT848}    reserved: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 25, 3); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
						KernelLog.String("{BT848}    reserved: ");
							KernelLog.Bits(SYSTEM.VAL(SET, data), 0, 32); KernelLog.Ln;
						INC(ipc, 4); data := SYSTEM.GET32(ipc);
				ELSE
						KernelLog.String("{BT848} INVALID RISC INSN: "); KernelLog.Bits(SYSTEM.VAL(SET, data), 0, 32);
							KernelLog.String(" @ ");
							KernelLog.Hex(Machine.PhysicalAdr(ipc, 4), 0); KernelLog.Ln;
						RETURN;
			END;
		UNTIL ((ipc - spc) DIV 4) > dmaProgLength;
		KernelLog.String("{BT848} risc: risc_jmp: dump completed"); KernelLog.Ln;
	END DumpRisc;

	(** Opens the VideoCaptureDevice object. *)
	PROCEDURE VideoOpen*;
	VAR
		temp1: LONGINT;
	BEGIN
		IF flags * FileHandlers # {} THEN
			IF DEBUG # DebugOff THEN KernelLog.String("{BT848} VideoOpen: device already in use"); KernelLog.Ln; END;
			RETURN;
		END;
		flags := flags + FileHandlers;
		SYSTEM.PUT8(base + BktrDStatus, 0000H);	(* clear device status register *)
		SYSTEM.PUT8(base + BktrADC, SYSTEM.VAL(LONGINT, SyncLevel));
		SYSTEM.PUT8(base + BktrIForm, Bt848IFormFPalBDGHI);
		formatParameters := Bt848IFormFPalBDGHI;
		temp1 := SYSTEM.GET8(base + BktrIForm);
		SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) +
			SYSTEM.VAL(SET, formatParams[formatParameters].iformXTSel)));
		(* work-around for new Hauppauge 878 cards *)
		IF (card.cardID = CardHauppauge) & ((id = Brooktree878) OR (id = Brooktree879)) THEN
			temp1 := SYSTEM.GET8(base + BktrIForm);
			SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848IFormMMUX3));
		ELSE
			temp1 := SYSTEM.GET8(base + BktrIForm);
			SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848IFormMMUX1));
		END;
		SYSTEM.PUT8(base + BktrADelay, formatParams[formatParameters].aDelay);
		SYSTEM.PUT8(base + BktrBDelay, formatParams[formatParameters].bDelay);
		(* enable PLL mode using 28MHz crystal for PAL/SECAM users *)
		IF xtalPLLMode = Bt848UsePLL THEN
			SYSTEM.PUT8(base + BktrTGCtrl, 0);
			SYSTEM.PUT8(base + BktrPLLFLo, 00F9H);
			SYSTEM.PUT8(base + BktrPLLFHi, 00DCH);
			SYSTEM.PUT8(base + BktrPLLFXCI, 008EH);
		END;
		flags := (flags * (-AosDevMask)) + AosDev0;
		(* TO BE DONE: clipping *)
		SYSTEM.PUT8(base + BktrColorCtl, SYSTEM.VAL(LONGINT, Bt848ColorCtlGamma + Bt848ColorCtlRGBDed));

		SYSTEM.PUT8(base + BktrEHScaleLo, 170);
		SYSTEM.PUT8(base + BktrOHScaleLo, 170);

		SYSTEM.PUT8(base + BktrEDelayLo, 0072H);
		SYSTEM.PUT8(base + BktrODelayLo, 0072H);
		SYSTEM.PUT8(base + BktrESCLoop, 0);
		SYSTEM.PUT8(base + BktrOSCLoop, 0);

		SYSTEM.PUT8(base + BktrVBIPackSize, 0);
		SYSTEM.PUT8(base + BktrVBIPackDel, 0);

		notificationProcess := NIL;

		fifoErrors := 0;
		dmaErrors := 0;
		framesCaptured := 0;
		evenFieldsCaptured := 0;
		oddFieldsCaptured := 0;
		SetFPS(formatParams[formatParameters].frameRate);
		videoAddr := 0;
		videoWidth := 0;
		pixFormat := 0;
		captureAreaEnabled := FALSE;
		SYSTEM.PUT32(base + BktrIntMask, Bt848IntMysteryBit);	(* if you take this out, Triton based motherboards will operate unreliably *)
	END VideoOpen;

	(** Closes the VideoCaptureDevice object. *)
	PROCEDURE VideoClose*;
	BEGIN
		flags := flags * (-(FileHandlers + AosSingle + AosCapMask + AosWantMask));

		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoRiscDisabled));
		SYSTEM.PUT8(base + BktrCapCtl, SYSTEM.VAL(LONGINT, CaptureOff));

		dmaProgLoaded := FALSE;
		SYSTEM.PUT8(base + BktrTDec, 0);
		SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, AllIntsDisabled));

		SYSTEM.PUT32(base + BktrSReset, 0000H);
		SYSTEM.PUT32(base + BktrIntStat, SYSTEM.VAL(LONGINT, AllIntsCleared));

		notificationProcess.Stop;
		notificationProcess := NIL;
	END VideoClose;

	(** Is Video device already in use? *)
	PROCEDURE IsVideoOpen* (): BOOLEAN;
	BEGIN
		RETURN (flags * FileHandlers) # {}
	END IsVideoOpen;

	(** Is the Vbi signal (Teletext) being captured? *)
	PROCEDURE IsVbiOpen* (): BOOLEAN;
	BEGIN
		RETURN (vbiFlags * VbiOpen) # {}
	END IsVbiOpen;

	(** Set a list of clipping region. *)
	PROCEDURE SetClipRegion*;
	BEGIN
		KernelLog.String("VideoCaptureDevice.SetClipRegion not implemented yet."); KernelLog.Ln;
	END SetClipRegion;

	(** Get the device status. *)
	(** return value:	device status *)
	PROCEDURE GetStatus*(): LONGINT;
	BEGIN
		RETURN SYSTEM.GET8(base + BktrDStatus);
	END GetStatus;

	(** Set the video input format *)
	(** format:	format of video signal (Bt848IFormPalBDGHI etc.) *)
	PROCEDURE SetInputFormat*(format: LONGINT);
	VAR temp1, temp2: SET;
	BEGIN
		temp1 := SYSTEM.VAL(SET, format) * Bt848IFormFormat;
		temp2 := SYSTEM.VAL(SET, SYSTEM.GET8(base + BktrIForm));
		temp2 := temp2 * (-Bt848IFormFormat);
		temp2 := temp2 * (-Bt848IFormXtSel);
		SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, temp1 + temp2 +
			SYSTEM.VAL(SET, formatParams[SYSTEM.VAL(LONGINT, temp1)].iformXTSel)));
		CASE format OF
				Bt848IFormFAuto:
					flags := (flags * (-AosFormMask)) + AosAutoMode;
			|  Bt848IFormFNTSCM,
			    Bt848IFormFNTSCJ:
			    	flags := (flags * (-AosFormMask)) + AosNTSC;
			    	formatParameters := SYSTEM.VAL(LONGINT, temp1);
			    	SYSTEM.PUT8(base + BktrADelay, formatParams[formatParameters].aDelay);
			    	SYSTEM.PUT8(base + BktrBDelay, formatParams[formatParameters].bDelay);
			|  Bt848IFormFPalBDGHI,
				Bt848IFormFPalN,
				Bt848IFormFSecam,
				Bt848IFormFRSVD,
				Bt848IFormFPalM:
					flags := (flags * (-AosFormMask)) + AosPAL;
					formatParameters := SYSTEM.VAL(LONGINT, temp1);
					SYSTEM.PUT8(base + BktrADelay, formatParams[formatParameters].aDelay);
					SYSTEM.PUT8(base + BktrBDelay, formatParams[formatParameters].bDelay);
		END;
		dmaProgLoaded := FALSE;
	END SetInputFormat;

	(** Get the video input format. *)
	PROCEDURE GetInputFormat*(): LONGINT;
	VAR
		temp1: LONGINT;
	BEGIN
		temp1 := SYSTEM.GET8(base + BktrIForm);
		RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * Bt848IFormFormat);
	END GetInputFormat;

	PROCEDURE SetPixelFormat*(format: LONGINT);
	BEGIN
		pixFormat := format;
	END SetPixelFormat;

	(** Select RCA as input. *)
	PROCEDURE SetInputDev0*;
	VAR
		temp1: LONGINT;
	BEGIN
		flags := (flags * (-AosDevMask)) + AosDev0;
		temp1 := SYSTEM.GET8(base + BktrIForm);
		SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848IFormMUXSel)));
		(* work around for new Hauppauge 878 cards *)
		IF ((card.cardID = CardHauppauge)  & ((id = Brooktree878) OR (id = Brooktree879))) THEN
			temp1 := SYSTEM.GET8(base + BktrIForm);
			SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848IFormMMUX3));
		ELSE
			temp1 := SYSTEM.GET8(base + BktrIForm);
			SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848IFormMMUX1));
		END;
		temp1 := SYSTEM.GET8(base + BktrEControl);
		SYSTEM.PUT8(base + BktrEControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848EControlComp)));
		temp1 := SYSTEM.GET8(base + BktrOControl);
		SYSTEM.PUT8(base + BktrOControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848OControlComp)));
		audio.SetAudioExtern;
	END SetInputDev0;

	(** Select the tuner as input. *)
	PROCEDURE SetInputDev1*;
	VAR
		temp1: LONGINT;
	BEGIN
		flags := (flags * (-AosDevMask)) + AosDev1;
		temp1 := SYSTEM.GET8(base + BktrIForm);
		SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848IFormMUXSel)));
		temp1 := SYSTEM.GET8(base + BktrIForm);
		SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848IFormMMUX0));
		temp1 := SYSTEM.GET8(base + BktrEControl);
		SYSTEM.PUT8(base + BktrEControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848EControlComp)));
		temp1 := SYSTEM.GET8(base + BktrOControl);
		SYSTEM.PUT8(base + BktrOControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848OControlComp)));
		audio.SetAudioTuner;
	END SetInputDev1;

	(** Select S-VHS (composite camera) as input. *)
	PROCEDURE SetInputDev2*;
	VAR
		temp1: LONGINT;
	BEGIN
		flags := (flags * (-AosDevMask)) + AosDev2;
		temp1 := SYSTEM.GET8(base + BktrIForm);
		SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848IFormMUXSel)));
		temp1 := SYSTEM.GET8(base + BktrIForm);
		SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848IFormMMUX2));
		temp1 := SYSTEM.GET8(base + BktrEControl);
		SYSTEM.PUT8(base + BktrEControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848EControlComp)));
		temp1 := SYSTEM.GET8(base + BktrOControl);
		SYSTEM.PUT8(base + BktrOControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848OControlComp)));
		audio.SetAudioExtern;
	END SetInputDev2;

	(** Select S-VHS as input. *)
	PROCEDURE SetInputDevSVideo*;
	VAR
		temp1: LONGINT;
	BEGIN
		flags := (flags * (-AosDevMask)) + AosDevSVideo;
		temp1 := SYSTEM.GET8(base + BktrIForm);
		SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848IFormMUXSel)));
		temp1 := SYSTEM.GET8(base + BktrIForm);
		SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848IFormMMUX2));
		temp1 := SYSTEM.GET8(base + BktrEControl);
		SYSTEM.PUT8(base + BktrEControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848EControlComp)));
		temp1 := SYSTEM.GET8(base + BktrOControl);
		SYSTEM.PUT8(base + BktrOControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848OControlComp)));
		audio.SetAudioExtern;
	END SetInputDevSVideo;

	(** Select MUX 3 as input. *)
	PROCEDURE SetInputDev3*;
	VAR
		temp1: LONGINT;
	BEGIN
		IF ((id = Brooktree848A) OR (id = Brooktree849A) OR (id = Brooktree878) OR (id = Brooktree879)) THEN
			flags := (flags * (-AosDevMask)) + AosDev3;
			temp1 := SYSTEM.GET8(base + BktrIForm);
			SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848IFormMUXSel)));
			IF ((card.cardID = CardHauppauge) & ((id = Brooktree878) OR (id = Brooktree879))) THEN
				temp1 := SYSTEM.GET8(base + BktrIForm);
				SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848IFormMMUX1));
			ELSE
				temp1 := SYSTEM.GET8(base + BktrIForm);
				SYSTEM.PUT8(base + BktrIForm, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) + Bt848IFormMMUX3));
			END;
			temp1 := SYSTEM.GET8(base + BktrEControl);
			SYSTEM.PUT8(base + BktrEControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848EControlComp)));
			temp1 := SYSTEM.GET8(base + BktrOControl);
			SYSTEM.PUT8(base + BktrOControl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp1) * (-Bt848OControlComp)));
			audio.SetAudioExtern;
		END;
	END SetInputDev3;

	(** Set the video data buffer. *)
	(** addr:	physical address of target buffer for video data. *)
	(** width:	line length of video frame buffer *)
	PROCEDURE SetVideo*(addr: ADDRESS; width: LONGINT);
	BEGIN
		ASSERT(flags * AosCapMask = {});
		videoAddr := Machine.Ensure32BitAddress (addr);
		videoWidth := width;
		dmaProgLoaded := FALSE;
	END SetVideo;

	(** Capture a single frame. *)
	PROCEDURE CaptureSingle*;
	VAR
		fp: FormatParams;
		temp1: LONGINT;
		fpsSave: LONGINT;
		iFlag: LONGINT;
		timer: Kernel.Timer;
	BEGIN
		NEW(timer);
		fp := formatParams[formatParameters];
		ASSERT(flags * AosCapMask = {});
		SYSTEM.PUT8(base + BktrDStatus, 0);
		temp1 := SYSTEM.GET32(base + BktrIntStat);
		SYSTEM.PUT32(base + BktrIntStat, temp1);
		flags := flags + AosSingle;
		flags := flags * (-AosWantMask);
		IF flags * AosOnlyFieldsMask = AosOnlyEvenFields THEN
			IF DEBUG >= DebugMed THEN KernelLog.String("{BT848} CaptureSingle: even fields"); KernelLog.Ln; END;
			flags := flags + AosWantEven;
			iFlag := AosEvenField;
		ELSIF flags * AosOnlyFieldsMask = AosOnlyOddFields THEN
			IF DEBUG >= DebugMed THEN KernelLog.String("{BT848} CaptureSingle: odd fields"); KernelLog.Ln; END;
			flags := flags + AosWantOdd;
			iFlag := AosOddField;
		ELSE
			IF DEBUG >= DebugMed THEN KernelLog.String("{BT848} CaptureSingle: interlaced"); KernelLog.Ln; END;
			flags := flags + AosWantMask;
			iFlag := AosInterlaced;
		END;
		(* TDEC is only valid for continuous captures *)
		fpsSave := fps;
		SetFPS(fp.frameRate);
		fps := fpsSave;
		IF dmaProgLoaded = FALSE THEN
			BuildDmaProg(iFlag);
			dmaProgLoaded := TRUE;
		END;

		SYSTEM.PUT32(base + BktrRISCStrtAdd, Machine.PhysicalAdr(ADDRESSOF(dmaProg), 4));

		(* wait for capture to complete *)
		singleFrameCaptured := FALSE;
		SYSTEM.PUT32(base + BktrIntStat, SYSTEM.VAL(LONGINT, AllIntsCleared));
		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoEnabled));
		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, capControl));

		SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, Bt848IntMysteryBit +
			Bt848IntRiscI + Bt848IntVSync + Bt848IntFmtChg));

		SYSTEM.PUT8(base + BktrCapCtl, SYSTEM.VAL(LONGINT, bktrCapCtl));
		REPEAT
		UNTIL singleFrameCaptured;
		(* stop DMA *)
		SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, AllIntsDisabled));
		(* disable RISC, leave FIFO running *)
		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoEnabled));

		flags := flags * (-(AosSingle + AosWantMask));
	END CaptureSingle;

	(** Start continuous frame capture. *)
	PROCEDURE CaptureContinuous*;
	VAR
		iFlag: LONGINT;
		temp1: LONGINT;
	BEGIN
		ASSERT(flags * AosCapMask = {});
		SYSTEM.PUT8(base + BktrDStatus, 0);
		temp1 := SYSTEM.GET32(base + BktrIntStat);
		SYSTEM.PUT(base + BktrIntStat, temp1);
		flags := flags + AosContin;
		flags := flags * (-AosWantMask);
		IF flags * AosOnlyFieldsMask = AosOnlyEvenFields THEN
			flags := flags + AosWantEven;
			iFlag := AosEvenField;
		ELSIF flags * AosOnlyFieldsMask = AosOnlyOddFields THEN
			flags := flags + AosWantOdd;
			iFlag := AosOddField;
		ELSE
			flags := flags + AosWantMask;
			iFlag := AosInterlaced;
		END;
		SetFPS(fps);
		IF dmaProgLoaded = FALSE THEN
			BuildDmaProg(iFlag);
			dmaProgLoaded := TRUE;
		END;
		(* clear the interrupt status register *)
		temp1 := SYSTEM.GET32(base + BktrIntStat);
		SYSTEM.PUT32(base + BktrIntStat, temp1);

		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoEnabled));
		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, capControl));
		SYSTEM.PUT8(base + BktrCapCtl, SYSTEM.VAL(LONGINT, bktrCapCtl));

		SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, Bt848IntMysteryBit +
			Bt848IntRiscI + Bt848IntVSync + Bt848IntFmtChg));
	END CaptureContinuous;

	(** Stop continuous video data capture. *)
	PROCEDURE StopCaptureContinuous*;
	BEGIN
		IF flags * AosContin # {} THEN
			(* turn off capture *)
			SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoRiscDisabled));
			SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, AllIntsDisabled));
			flags := flags * (-(AosContin + AosWantMask));
		END;
	END StopCaptureContinuous;

	(** Set the frame geometry. *)
	(** columns:	number of columns of a frame *)
	(** rows:	number of rows of a frame *)
	(** frames:	number of frames allocated *)
	(** format:	AosEvenOnly, AosOddOnly, none (interlaced) *)
	PROCEDURE SetGeometry*(columns, rows, frames: LONGINT; format: SET);
	BEGIN
		ASSERT(flags * AosCapMask = {});	(* can't change parameters while capturing *)
		ASSERT(~((format * AosOnlyEvenFields # {}) & (format * AosOnlyOddFields # {})));	(* geometry odd or even only *)
		IF format * AosOnlyOddFields # {} THEN
			flags := flags + AosOnlyOddFields;
		ELSE
			flags := flags * (-AosOnlyOddFields);
		END;
		IF format * AosOnlyEvenFields # {} THEN
			flags := flags + AosOnlyEvenFields;
		ELSE
			flags := flags * (-AosOnlyEvenFields);
		END;
		ASSERT(columns > 0);	(* columns must be greater than zero *)
		ASSERT(SYSTEM.VAL(SET, columns) * SYSTEM.VAL(SET, 03FEH) = SYSTEM.VAL(SET, columns));	(* columns too large or not even *)
		ASSERT(rows > 0);	(* rows must be greater than zero *)
		ASSERT(SYSTEM.VAL(SET, rows) * SYSTEM.VAL(SET, 03FEH) = SYSTEM.VAL(SET, rows));	(* rows too large or not even *)
		ASSERT(frames <= 32);	(* too many frames *)
		dmaProgLoaded := FALSE;
		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoRiscDisabled));

		SYSTEM.PUT32(base + BktrIntMask, SYSTEM.VAL(LONGINT, AllIntsDisabled));

		frameRows := rows;
		frameCols := columns;
		SELF.frames := frames;
		IF flags * AosCapMask # {} THEN
			IF flags * (AosContin + AosSynCap) # {} THEN
				IF flags * AosOnlyFieldsMask = AosOnlyOddFields THEN
					flags := flags + AosWantOdd;
				ELSIF flags * AosOnlyFieldsMask = AosOnlyEvenFields THEN
					flags := flags + AosWantEven;
				ELSE
					flags := flags + AosWantMask;
				END;
			END;
		END;
	END SetGeometry;

	(* Read from the remote control device. *)
	(* Uses manual programming of the I2C-bus. See modul notes below for details. *)
	(* data:	placeholder for data *)
	PROCEDURE RemoteRead(VAR data: ARRAY OF CHAR);
	BEGIN
		ASSERT(LEN(data) = 3);
		i2cBus.I2CStart;
		ASSERT(i2cBus.I2CWriteByte(CHR(remoteControlAddr)) = 0);
		i2cBus.I2CReadByte(data[0], FALSE);
		i2cBus.I2CReadByte(data[1], FALSE);
		i2cBus.I2CReadByte(data[2], FALSE);
		i2cBus.I2CStop;
	END RemoteRead;

	(* Locate tuner address. *)
	(* return value:	I2C-bus address of tuner, or -1 if none is found *)
	PROCEDURE LocateTunerAddress(): LONGINT;
	CONST Absent = -1;
	BEGIN
		IF i2cBus.I2CRead(00C1H) # Absent THEN RETURN 00C0H; END;
		IF i2cBus.I2CRead(00C3H) # Absent THEN RETURN 00C2H; END;
		IF i2cBus.I2CRead(00C5H) # Absent THEN RETURN 00C4H; END;
		IF i2cBus.I2CRead(00C7H) # Absent THEN RETURN 00C6H; END;
		RETURN Absent;
	END LocateTunerAddress;

	(* Locate EEProm address. *)
	(* return value:	I2C-bus address of EEProm, or -1 if none is found *)
	PROCEDURE LocateEEPROMAddress(): LONGINT;
	CONST Absent = -1;
	BEGIN
		IF i2cBus.I2CRead(00A0H) # Absent THEN RETURN 00A0H; END;
		IF i2cBus.I2CRead(00ACH) # Absent THEN RETURN 00ACH; END;
		IF i2cBus.I2CRead(00AEH) # Absent THEN RETURN 00AEH; END;
		RETURN Absent;
	END LocateEEPROMAddress;

	(* Read the EEProm. *)
	(* offset:	offset of read action *)
	(* count:	number of bytes to be read *)
	(* data:	placeholder for data *)
	(* return value:	-1 if an error occurred, otherwise 0 *)
	PROCEDURE ReadEEProm(offset: LONGINT; count: LONGINT; VAR data: ARRAY OF CHAR): LONGINT;
	VAR addr, x, byte: LONGINT;
	BEGIN
		addr := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, card.eepromAddr) * {0..7});
		IF addr = 0 THEN RETURN -1 END;
		ASSERT(offset + count <= card.eepromSize * EEPromBlockSize);
		(* set the start address *)
		IF i2cBus.I2CWrite(addr, offset, -1) = -1 THEN RETURN -1; END;
		(* the read cycle *)
		FOR x := 0 TO count-1 DO
			byte := i2cBus.I2CRead(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, addr) + {0}));
			IF byte = -1 THEN RETURN -1; END;
			data[x] := SYSTEM.VAL(CHAR, byte);
		END;
		RETURN 0;
	END ReadEEProm;

	END VideoCaptureDevice;

	(* The I2CBus object represents the I2C bus. *)
	I2CBus = OBJECT
	VAR
		cardID: LONGINT;
		base: ADDRESS;
		dead: BOOLEAN;

	(* Initialize I2CBus object. *)
	(* base:	base of video capture card *)
	PROCEDURE &Init*(id: LONGINT; base: ADDRESS);
	BEGIN
		SELF.cardID := id;
		SELF.base := base;
		dead := FALSE;
	END Init;

	PROCEDURE Close;
	BEGIN
		dead := TRUE;
	END Close;

	(* Read from the I2C-bus. *)
	(* Uses the Brooktree chip I2C-bus capabilities. See modul notes below for details. *)
	(* addr:	read address *)
	(* return value:	-1 if an error occured, otherwise the data *)
	PROCEDURE I2CRead(addr: LONGINT) : LONGINT;
	CONST
		I2CBitTime = {4, 6};
		I2CBitTime878 = {7};
		I2CCommand = I2CBitTime + Bt848DataCtlI2CSCL + Bt848DataCtlI2CSDA;
		I2CCommand878 = I2CBitTime878 + Bt848DataCtlI2CSCL + Bt848DataCtlI2CSDA;
	VAR
		x: LONGINT;
	BEGIN {EXCLUSIVE}
		SYSTEM.PUT32(base + BktrIntStat, SYSTEM.VAL(LONGINT, Bt848IntRAck + Bt848IntI2CDone));	(* clear status bits *)
		IF (cardID = Brooktree848) OR (cardID = Brooktree848A) OR (cardID = Brooktree849A) THEN
			SYSTEM.PUT32(base + BktrI2CDataCtl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,
				ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, addr) * {0..7}), 24)) + I2CCommand));
		ELSE
			SYSTEM.PUT32(base + BktrI2CDataCtl, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,
				ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, addr) * {0..7}), 24)) + I2CCommand878));
		END;
		(* wait for completion; TO BE DONE: infinite loop protection *)
		x := MAX(LONGINT);
		REPEAT
			DEC(x);
		UNTIL (SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrIntStat)) * Bt848IntI2CDone # {}) & (x > 0);
		(* check for ACK *)
		IF (SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrIntStat)) * Bt848IntRAck = {}) OR (x = 0) THEN
			RETURN -1;
		ELSE
			RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(SYSTEM.GET32(base + BktrI2CDataCtl), -8)) * {0..7});
		END;
	END I2CRead;

	(* Write to the I2C-bus. *)
	(* Uses the Brooktree chip I2C-bus capabilities. See modul notes below for details. *)
	(* addr:	write address *)
	(* byte1:	first byte *)
	(* byte2:	second byte *)
	(* return value:	-1 if an error occured, otherwise 0 *)
	PROCEDURE I2CWrite(addr: LONGINT; byte1, byte2: LONGINT): LONGINT;
	CONST
		I2CBitTime = {4, 6};
		I2CBitTime878 = {7};
		I2CCommand = I2CBitTime + Bt848DataCtlI2CSCL + Bt848DataCtlI2CSDA;
		I2CCommand878 = I2CBitTime878 + Bt848DataCtlI2CSCL + Bt848DataCtlI2CSDA;
	VAR
		x, data: LONGINT;
	BEGIN {EXCLUSIVE}
		SYSTEM.PUT32(base + BktrIntStat, SYSTEM.VAL(LONGINT, Bt848IntRAck + Bt848IntI2CDone));	(* clear status bits *)
		(* build the command datum *)
		IF (cardID = Brooktree848) OR (cardID = Brooktree848A) OR (cardID = Brooktree849A) THEN
			data := SYSTEM.VAL(LONGINT,
				SYSTEM.VAL(SET, ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, addr) * {0..7}), 24)) +
				SYSTEM.VAL(SET, ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, byte1) * {0..7}), 16)) +
				I2CCommand);
		ELSE
			data := SYSTEM.VAL(LONGINT,
				SYSTEM.VAL(SET, ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, addr) * {0..7}), 24)) +
				SYSTEM.VAL(SET, ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, byte1) * {0..7}), 16)) +
				I2CCommand878);
		END;
		IF byte2 # -1 THEN
			data := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, data) +
				SYSTEM.VAL(SET, ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, byte2) * {0..7}), 8)) +
				Bt848DataCtlI2CW3B);
		END;
		(* write the address and data *)
		SYSTEM.PUT32(base + BktrI2CDataCtl, data);
		(* wait for completion; TO BE DONE: infinite loop protection *)
		x := MAX(LONGINT);
		REPEAT
			DEC(x);	(* safety valve *)
		UNTIL ((SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrIntStat)) * Bt848IntI2CDone) # {}) & (x > 0);
		(* check for ACK *)
		IF (SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrIntStat)) * Bt848IntRAck = {}) OR (x = 0) THEN
			RETURN -1;
		ELSE
			RETURN 0;
		END;
	END I2CWrite;

	(* Start a I2C-bus transaction. *)
	(* For manual programming of the I2C-bus. See modul notes below for details. *)
	PROCEDURE I2CStart;
	VAR
		timer: Kernel.Timer;
	BEGIN {EXCLUSIVE}
		NEW(timer);
		SYSTEM.PUT32(base + BktrI2CDataCtl, 1); timer.Sleep(1);	(* release data *)
		SYSTEM.PUT32(base + BktrI2CDataCtl, 3); timer.Sleep(1);	(* release clock *)
		SYSTEM.PUT32(base + BktrI2CDataCtl, 2); timer.Sleep(1);	(* lower data *)
		SYSTEM.PUT32(base + BktrI2CDataCtl, 0); timer.Sleep(1);	(* lower clock *)
	END I2CStart;

	(* Stop an I2C-bus transaction. *)
	(* For manual programming of the I2C-bus. See modul notes below for details. *)
	PROCEDURE I2CStop;
	VAR
		timer: Kernel.Timer;
	BEGIN {EXCLUSIVE}
		NEW(timer);
		SYSTEM.PUT32(base + BktrI2CDataCtl, 0); timer.Sleep(1);	(* lower clock and data *)
		SYSTEM.PUT32(base + BktrI2CDataCtl, 2); timer.Sleep(1);	(* release clock *)
		SYSTEM.PUT32(base + BktrI2CDataCtl, 3); timer.Sleep(1);	(* release data *)
	END I2CStop;

	(* Write to the I2C-bus. *)
	(* For manual programming of the I2C-bus. See modul notes below for details. *)
	(* data:	data byte *)
	(* return value:	-1 if an error occurred, otherwise 0 *)
	PROCEDURE I2CWriteByte(data: CHAR): LONGINT;
	VAR
		x, status: LONGINT;
		timer: Kernel.Timer;
	BEGIN {EXCLUSIVE}
		NEW(timer);
		x := 7;
		WHILE x >= 0 DO
			IF (SYSTEM.VAL(SET, ORD(data)) * {x} # {}) THEN
				SYSTEM.PUT32(base + BktrI2CDataCtl, 1); timer.Sleep(1);	(* assert HI data *)
				SYSTEM.PUT32(base + BktrI2CDataCtl, 3); timer.Sleep(1);	(* strobe clock *)
				SYSTEM.PUT32(base + BktrI2CDataCtl, 1); timer.Sleep(1);	(* release clock *)
			ELSE
				SYSTEM.PUT32(base + BktrI2CDataCtl, 0); timer.Sleep(1);	(* assert LO data *)
				SYSTEM.PUT32(base + BktrI2CDataCtl, 2); timer.Sleep(1);	(* strobe clock *)
				SYSTEM.PUT32(base + BktrI2CDataCtl, 0); timer.Sleep(1);	(* release clock *)
			END;
			DEC(x);
		END;
		(* look for an ACK *)
		SYSTEM.PUT32(base + BktrI2CDataCtl, 1); timer.Sleep(1);	(* float data *)
		SYSTEM.PUT32(base + BktrI2CDataCtl, 3); timer.Sleep(1);	(* strobe clock *)
		status := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrI2CDataCtl)) * {0});	(* read the ACK bit *)
		SYSTEM.PUT32(base + BktrI2CDataCtl, 1); timer.Sleep(1);	(* release clock *)
		RETURN status;
	END I2CWriteByte;

	(* Read from the I2C-bus. *)
	(* For manual programming of the I2C-bus. See modul notes below for details. *)
	(* data:	placeholder for data *)
	(* last:	TRUE if this is the last byte to be read, otherwise FALSE *)
	PROCEDURE I2CReadByte(VAR data: CHAR; last: BOOLEAN);
	VAR
		x, bit: LONGINT;
		byte: CHAR;
		timer: Kernel.Timer;
	BEGIN {EXCLUSIVE}
		NEW(timer);
		byte := CHR(0);
		SYSTEM.PUT32(base + BktrI2CDataCtl, 1); timer.Sleep(1);	(* float data *)
		x := 7;
		WHILE x >= 0 DO
			SYSTEM.PUT32(base + BktrI2CDataCtl, 3); timer.Sleep(1);	(* strobe clock *)
			bit := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.GET32(base + BktrI2CDataCtl)) * {0}); (* read the data bit *)
			IF (SYSTEM.VAL(SET, bit) * {0} # {}) THEN byte := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, byte) + {x}); END;
			SYSTEM.PUT32(base + BktrI2CDataCtl, 1); timer.Sleep(1);	(* release clock *)
			DEC(x);
		END;
		(* after reading the byte, send an ACK (unless that was the last byte, for which we send a NAK *)
		IF last THEN	(* send NAK - same as writing a 1 *)
			SYSTEM.PUT32(base + BktrI2CDataCtl, 1); timer.Sleep(1);	(* set data bit *)
			SYSTEM.PUT32(base + BktrI2CDataCtl, 3); timer.Sleep(1);	(* strobe clock *)
			SYSTEM.PUT32(base + BktrI2CDataCtl, 1); timer.Sleep(1);	(* release clock *)
		ELSE (* send ACK - same as writing a 0 *)
			SYSTEM.PUT32(base + BktrI2CDataCtl, 0); timer.Sleep(1);	(* set data bit *)
			SYSTEM.PUT32(base + BktrI2CDataCtl, 2); timer.Sleep(1);	(* strobe clock *)
			SYSTEM.PUT32(base + BktrI2CDataCtl, 0); timer.Sleep(1);	(* release clock *)
		END;
		data := byte;
	END I2CReadByte;

	BEGIN {ACTIVE}
	END I2CBus;

	(** The Audio object represents the audio facilities of the video capture card. *)
	Audio* = OBJECT (TVDriver.Audio)
	VAR
		vcd: VideoCaptureDevice;

	(* Initialize the Audio object. *)
	PROCEDURE &Init*(vcd: TVDriver.VideoCaptureDevice);
	BEGIN
		ASSERT (vcd IS VideoCaptureDevice);
		SELF.vcd := vcd(VideoCaptureDevice);
		InitAudioDevices;
	END Init;

	(* Initialize the audio devices. *)
	PROCEDURE InitAudioDevices;
	BEGIN
		IF vcd.card.dbx THEN InitBTSC; END;
		IF vcd.card.msp3400c THEN MspDplReset(vcd.mspAddr); END;
		IF vcd.card.dpl3518a THEN MspDplReset(vcd.dplAddr); END;
	END InitAudioDevices;

	(* Initialize the BTSC device. *)
	PROCEDURE InitBTSC;
	VAR valNirwana: LONGINT;
	BEGIN
		KernelLog.Hex(Con1Addr, 0);
		valNirwana := vcd.i2cBus.I2CWrite(TDA9850WAddr, Con1Addr, 0008H);
		valNirwana := vcd.i2cBus.I2CWrite(TDA9850WAddr, Con2Addr, 0008H);
		valNirwana := vcd.i2cBus.I2CWrite(TDA9850WAddr, Con3Addr, 0040H);
		valNirwana := vcd.i2cBus.I2CWrite(TDA9850WAddr, Con4Addr, 0007H);
		valNirwana := vcd.i2cBus.I2CWrite(TDA9850WAddr, Ali1Addr, 0010H);
		valNirwana := vcd.i2cBus.I2CWrite(TDA9850WAddr, Ali2Addr, 0010H);
		valNirwana := vcd.i2cBus.I2CWrite(TDA9850WAddr, Ali3Addr, 0003H);
	END InitBTSC;

	(* Read the ID of the MSP device. *)
	PROCEDURE MspReadId;
	VAR rev1, rev2: LONGINT;
	BEGIN
		rev1 := 0; rev2 := 0;
		rev1 := MspDplRead(vcd.mspAddr, CHR(0012H), 001EH);
		rev2 := MspDplRead(vcd.mspAddr, CHR(0012H), 001FH);
		vcd.mspVersionString := "34";
		vcd.mspVersionString[2] := CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(rev2, -8)) * {0..7}) DIV 10 +
			ORD('0'));
		vcd.mspVersionString[3] := CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(rev2, -8)) * {0..7}) MOD 10 +
			ORD('0'));
		vcd.mspVersionString[4] := CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, rev1) * {0..7}) + ORD('@'));
		vcd.mspVersionString[5] := '-';
		vcd.mspVersionString[6] := CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(rev1, -8)) * {0..7}) + ORD('@'));
		vcd.mspVersionString[7] := CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, rev2) * {0..4}));
	END MspReadId;

	(* Read the ID of the DPL device. *)
	(* Note: This function doesn't work as expected. ID code?? *)
	PROCEDURE DplReadId;
	VAR rev1, rev2: LONGINT;
	BEGIN
		rev1 := 0; rev2 := 0;
		rev1 := MspDplRead(vcd.dplAddr, CHR(0012H), 001EH);
		rev2 := MspDplRead(vcd.dplAddr, CHR(0012H), 001FH);
		vcd.dplVersionString := "35";
		vcd.dplVersionString[2] := CHR((SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(rev2, -8)) * {0..7}) - 1) DIV 10 + ORD('0'));
		vcd.dplVersionString[3] := CHR((SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(rev2, -8)) * {0..7}) - 1) MOD 10 + ORD('0'));
		vcd.dplVersionString[4] := '-';
		vcd.dplVersionString[5] := CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(rev1, -8)) * {0..7}) + ORD('@'));
		vcd.dplVersionString[6] := CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, rev2) * {0..4}));
	END DplReadId;

	(* Auto-detect the MSP device. *)
	PROCEDURE MspAutoDetect;
	VAR
		x, loops, autoDetect, stereo: LONGINT;
		id: ARRAY 6 OF CHAR;
		timer: Kernel.Timer;
	BEGIN
		NEW(timer);
		FOR x := 0 TO 4 DO
			id[x] := vcd.mspVersionString[x];
		END;
		(* MSP3430G - countries with mono and DBX stereo *)
		IF id = "3430G" THEN
			MspDplWrite(vcd.mspAddr, CHR(0010H), 0030H, 2003H);	(* enable auto format detection *)
			MspDplWrite(vcd.mspAddr, CHR(0010H), 0020H, 0020H);	(* standard select register = BTSC-stereo *)
			MspDplWrite(vcd.mspAddr, CHR(0012H), 000EH, 2403H);
			MspDplWrite(vcd.mspAddr, CHR(0012H), 0008H, 0320H);	(* source select = (St or A) & ch. matrix = St *)
			MspDplWrite(vcd.mspAddr, CHR(0012H), 0000H, 7300H);	(* set volume to 0 db gain *)
		(* MSP3415D SPECIAL CASE: Use the tuner's mono audio output for the MSP *)
		(* (for Hauppauge 44xxx card with tuner type 0x2a *)
		ELSIF ((id = "3415D") & vcd.mspUseMonoSource) OR (vcd.slowMSPAudio = 2) THEN
			MspDplWrite(vcd.mspAddr, CHR(0012H), 0000H, 7300H);	(* 0 db volume *)
			MspDplWrite(vcd.mspAddr, CHR(0012H), 000DH, 1900H);	(* scart prescale *)
			MspDplWrite(vcd.mspAddr, CHR(0012H), 0008H, 0220H);	(* SCART | STEREO *)
			MspDplWrite(vcd.mspAddr, CHR(0012H), 0013H, 0100H);	(* DSP In = MONO IN *)
		(* MSP3410/MSP3415 - countries with mono, stereo using 2 FM channels and NICAM FAST sound scheme *)
		ELSIF (vcd.slowMSPAudio = 0) THEN
			MspDplWrite(vcd.mspAddr, CHR(0012H), 0000H, 7300H);	(* set volume to 0 db gain *)
			MspDplWrite(vcd.mspAddr, CHR(0012H), 0008H, 0000H);	(* speaker source = default (FM/AM) *)
			MspDplWrite(vcd.mspAddr, CHR(0010H), 0020H, 0001H);	(* enable auto format detection *)
			MspDplWrite(vcd.mspAddr, CHR(0010H), 0021H, 0001H);	(* auto selection of NICAM/MONO mode *)
		(* MSP3410/MSP3415 - European countries where the fast MSP3410/3415 programming fails -> slow sound scheme *)
		ELSIF (vcd.slowMSPAudio = 1) THEN
			MspDplWrite(vcd.mspAddr, CHR(0012H), 0000H, 7300H);	(* set volume to 0 db gain *)
			MspDplWrite(vcd.mspAddr, CHR(0010H), 0020H, 0001H);	(* enable auto format detection *)
			loops := 0;
			(* wait for 0.5s max for terrestrial sound auto-detection *)
			REPEAT
				timer.Sleep(10);
				autoDetect := MspDplRead(vcd.mspAddr, CHR(0010H), 007EH);
				INC(loops);
			UNTIL (autoDetect > 00FFH) & (loops < 50);
			IF DEBUG >= DebugMed THEN
				KernelLog.String("{MSP3400C} result of autodetection: "); KernelLog.Hex(autoDetect, 0); KernelLog.Ln;
			END;
			IF autoDetect = 0 THEN	(* no TV sound standard detected *)
			ELSIF autoDetect = 2 THEN	(* M dual FM *)
			ELSIF autoDetect = 3 THEN
				(* B/G dual FM; German stereo *)
				(* read the stereo detection value from DSP reg 0x0018 *)
				timer.Sleep(2);
				stereo := MspDplRead(vcd.mspAddr, CHR(0012H), 0018H);
				IF DEBUG >= DebugMed THEN
					KernelLog.String("{MSP3400C} stereo reg 0x18 a: "); KernelLog.Hex(stereo, 0); KernelLog.Ln;
				END;
				timer.Sleep(2);
				stereo := MspDplRead(vcd.mspAddr, CHR(0012H), 0018H);
				IF DEBUG >= DebugMed THEN
					KernelLog.String("{MSP3400C} stereo reg 0x18 b: "); KernelLog.Hex(stereo, 0); KernelLog.Ln;
				END;
				timer.Sleep(2);
				stereo := MspDplRead(vcd.mspAddr, CHR(0012H), 0018H);
				IF DEBUG >= DebugMed THEN
					KernelLog.String("{MSP3400C} stereo reg 0x18 c: "); KernelLog.Hex(stereo, 0); KernelLog.Ln;
				END;
				IF (stereo > 0100H) & (stereo < 8000H) THEN	(* seems to be stereo *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0008H, 0020H); (* loudspeaker set stereo *)
					(* set spatial effect strengh to 50% enlargement *)
					(* set spatial effect mode b, stereo basewidth enlargement only *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0005H, 3F28H);
				ELSIF (stereo > 8000H) THEN	(* bilingual mode *)
					IF DEBUG >= DebugMed THEN KernelLog.String("{MSP3400C} bilingual mode detected"); KernelLog.Ln; END;
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0008H, 0000H);	(* loudspeaker *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0005H, 0000H);	(* all spatial effects off *)
				ELSE	(* must be mono *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0008H, 0030H);	(* loudspeaker *)
					(* set spatial effect strength to 50% enlargement *)
					(* set spatial effect mode a, stereo basewidth enlargement *)
					(* and pseudo stereo effect with automatic high-pass filter *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0005H, 3F08H);
				END;
			ELSIF autoDetect = 8 THEN	(* B/G FM NICAM *)
							MspDplWrite(vcd.mspAddr, CHR(0010H), 0021H, 0001H);	(* auto selection of NICAM/MONO mode *)
			ELSIF autoDetect = 9 THEN	(* L_AM NICAM or D/K *)
			ELSIF autoDetect = 10 THEN	(* i-FM NICAM *)
			ELSE
				KernelLog.String("{MSP3400C} Unknown autodetection result value: "); KernelLog.Hex(autoDetect, 0); KernelLog.Ln;
			END;
			(* uncomment the following line to enable the MSP34xx 1kHz tone generator *)
			(* turn your speaker volume down low before trying this *)
			(* vcd.MspDplWrite(vcd.mspAddr, CHR(0012H), 0014H, 7F40H); *)
		END;
	END MspAutoDetect;

	(* Auto-detect the DPL device. *)
	PROCEDURE DplAutoDetect;
	BEGIN
		MspDplWrite(vcd.dplAddr, CHR(0012H), 000CH, 0320H);	(* quasi peak detector source dolby lr 0x03xx; quasi peak detector matrix stereo 0xXX20 *)
		MspDplWrite(vcd.dplAddr, CHR(0012H), 0040H, 0060H);	(* Surround decoder mode; ADAPTIVE/3D-PANORAMA, that means two speakers and no center speaker, *)
																									  (* all channels L/R/C/S mixed to L and R *)
		MspDplWrite(vcd.dplAddr, CHR(0012H), 0041H, 0620H);	(* surround source matrix; I2S2/STEREO *)
		MspDplWrite(vcd.dplAddr, CHR(0012H), 0042H, 1F00H);	(* surround delay 31 ms max *)
		MspDplWrite(vcd.dplAddr, CHR(0012H), 0043H, 0000H);	(* automatic surround input balance *)
		MspDplWrite(vcd.dplAddr, CHR(0012H), 0044H, 4000H);	(* surround spatial effect 50% recommended *)
		MspDplWrite(vcd.dplAddr, CHR(0012H), 0045H, 5400H);	(* surround panorama effect 66% recommended *)
																										(* with PANORAMA mode in 0x0040 set to panorama *)
	END DplAutoDetect;

	(* Write to the sound chip. *)
	(* Uses manual programming of the I2C-bus. See modul notes below for details. *)
	(* i2cAddr:	I2C-bus address of the chip *)
	(* dev:	device *)
	(* addr:	write target address *)
	(* data:	data to be written *)
	PROCEDURE MspDplWrite(i2cAddr: LONGINT; dev: CHAR; addr: LONGINT; data: LONGINT);
	VAR mspWAddr, addrLo, addrHi, dataLo, dataHi: CHAR;
	BEGIN
		mspWAddr := CHR(i2cAddr);
		addrHi := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, ASH(addr, -8)) * {0..7});
		addrLo := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, addr) * {0..7});
		dataHi := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, ASH(data, -8)) * {0..7});
		dataLo := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, data) * {0..7});
		vcd.i2cBus.I2CStart;
		ASSERT(vcd.i2cBus.I2CWriteByte(mspWAddr) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(dev) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(addrHi) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(addrLo) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(dataHi) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(dataLo) = 0);
		vcd.i2cBus.I2CStop;
	END MspDplWrite;

	(* Read from the sound chip. *)
	(* Uses manual programming of the I2C-bus. See modul notes below for details. *)
	(* i2cAddr:	I2C-bus address of the chip *)
	(* dev:	device *)
	(* addr:	read address *)
	(* return value:	data read *)
	PROCEDURE MspDplRead(i2cAddr: LONGINT; dev: CHAR; addr: LONGINT): LONGINT;
	VAR data: LONGINT; addrLo, addrHi, data1, data2, devR: CHAR;
	BEGIN
		addrHi := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, ASH(addr, -8)) * {0..7});
		addrLo := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, addr) * {0..7});
		devR := CHR(ORD(dev) + 1);
		vcd.i2cBus.I2CStart;
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(i2cAddr)) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(devR) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(addrHi) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(addrLo) = 0);
		vcd.i2cBus.I2CStart;
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(i2cAddr+1)) = 0);
		vcd.i2cBus.I2CReadByte(data1, FALSE);
		vcd.i2cBus.I2CReadByte(data2, TRUE);
		vcd.i2cBus.I2CStop;
		data := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(ORD(data1), 8)) + SYSTEM.VAL(SET, data2));
		RETURN data;
	END MspDplRead;

	(* Reset the sound chip. *)
	(* Uses manual programming of the I2C-bus. See modul notes below for details. *)
	(* i2cAddr:	I2C-bus address of the chip *)
	PROCEDURE MspDplReset(i2cAddr: LONGINT);
	BEGIN
		(* put into reset mode *)
		vcd.i2cBus.I2CStart;
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(i2cAddr)) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(0000H)) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(0080H)) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(0000H)) = 0);
		vcd.i2cBus.I2CStop;
		(* put back to operational mode *)
		vcd.i2cBus.I2CStart;
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(i2cAddr)) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(0000H)) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(0000H)) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(0000H)) = 0);
		ASSERT(vcd.i2cBus.I2CWriteByte(CHR(0000H)) = 0);
		vcd.i2cBus.I2CStop;
	END MspDplReset;

	(** Select the tuner for audio input. *)
	PROCEDURE SetAudioTuner*;
	BEGIN
		IF vcd.reverseMute THEN vcd.audioMUXSelect := 0; ELSE vcd.audioMUXSelect := 3; END;
		SetAudio;
	END SetAudioTuner;

	(** Select external input for audio input. *)
	PROCEDURE SetAudioExtern*;
	BEGIN
		vcd.audioMUXSelect := 1;
		SetAudio;
	END SetAudioExtern;

	(** Select internal input for audio input. *)
	PROCEDURE SetAudioIntern*;
	BEGIN
		vcd.audioMUXSelect := 2;
		SetAudio;
	END SetAudioIntern;

	(** Set audio to mute. *)
	PROCEDURE SetAudioMute*;
	BEGIN
		vcd.audioMuteState := TRUE;
		SetAudio;
	END SetAudioMute;

	(** Unmute audio. *)
	PROCEDURE SetAudioUnmute*;
	BEGIN
		vcd.audioMuteState := FALSE;
		SetAudio;
	END SetAudioUnmute;

	(** Returns the mute state. *)
	(** return value:	TRUE if audio is mute, otherwise FALSE *)
	PROCEDURE IsAudioMute*(): BOOLEAN;
	BEGIN
		RETURN vcd.audioMuteState;
	END IsAudioMute;

	(* Set audio input. *)
	PROCEDURE SetAudio;
	VAR idx: LONGINT; temp: SET;
	BEGIN
		IF vcd.audioMuteState THEN
			IF vcd.reverseMute THEN idx := 3; ELSE idx := 0; END;
		ELSE
			idx := vcd.audioMUXSelect;
		END;
		temp := SYSTEM.VAL(SET, SYSTEM.GET32(vcd.base + BktrGPIOData)) * (-SYSTEM.VAL(SET, vcd.card.gpioMUXBits));
		SYSTEM.PUT32(vcd.base + BktrGPIOData,
			SYSTEM.VAL(LONGINT, temp + SYSTEM.VAL(SET, vcd.card.audioMUXs[idx])));
		IF (~vcd.audioMUXPresent & vcd.card.msp3400c) THEN
			IF vcd.audioMuteState THEN
				MspDplWrite(vcd.mspAddr, CHR(0012H), 0000H, 0000H);	(* volume to MUTE *)
				IF DEBUG >= DebugMed THEN KernelLog.String("Set audio to mute"); KernelLog.Ln; END;
			ELSE
				IF (vcd.audioMUXSelect = 0) THEN	(* TV tuner *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0000H, 7300H);	(* 0 db volume *)
					IF (vcd.mspSourceSelected # 0) THEN MspAutoDetect; END;	(* setup TV audio mode *)
					vcd.mspSourceSelected := 0;
					IF DEBUG >= DebugMed THEN KernelLog.String("Set audio to tuner"); KernelLog.Ln; END;
				ELSIF (vcd.audioMUXSelect = 1) THEN	(* line-in *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0000H, 7300H);	(* 0 db volume *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 000DH, 19000H);	(* scart prescale *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0008H, 0220H);	(* SCART | STEREO *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0013H, 0000H);	(* DSP In = SC1_IN_L/R *)
					vcd.mspSourceSelected := 1;
					IF DEBUG >= DebugMed THEN KernelLog.String("Set audio to in-line"); KernelLog.Ln; END;
				ELSIF (vcd.audioMUXSelect = 2) THEN	(* FM radio *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0000H, 7300H);	(* 0 db volumne *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 000DH, 1900H);	(* scart prescale *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0008H, 0220H);	(* SCART | STEREO *)
					MspDplWrite(vcd.mspAddr, CHR(0012H), 0013H, 0200H);	(* DSP In = SC2_IN_L/R *)
					vcd.mspSourceSelected := 2;
					IF DEBUG >= DebugMed THEN KernelLog.String("Set audio to intern [FM-radio]"); KernelLog.Ln; END;
				END;
			END;
		END;
	END SetAudio;

	END Audio;

VAR
	cards: ARRAY NoOfCards OF CardType;
	tuners: ARRAY NoOfTuners OF Tuner;
	vcdDevices: VideoCaptureDevice;
	freqTable: ARRAY NoOfChnlSets OF ChannelSet;
	formatParams: ARRAY NoOfFormatParams OF FormatParams;
	pixelFormatTable: ARRAY NoOfPixelFormats OF PixelFormat;

	i: LONGINT;


(* Scan PCI bus for the specified card. *)
(* vendor:	vendor id *)
(* device:	device id *)
PROCEDURE ScanPCI(vendor, device: LONGINT);
CONST BtDefaultLatencyValue = 10;
VAR
	index, bus, dev, fct, irq, rev: LONGINT;
	base: ADDRESS;
	vcd: VideoCaptureDevice;
	command, fun, latency: LONGINT;
BEGIN
	IF DEBUG # DebugOff THEN
		KernelLog.String("{BT848} Scanning PCI bus for vendor: "); KernelLog.Hex(vendor, 0);
		KernelLog.String("; device: "); KernelLog.Hex(device, 0); KernelLog.Ln();
	END;
	index := 0;
	WHILE (PCI.FindPCIDevice(device, vendor, index, bus, dev, fct) = PCI.Done) DO
		ASSERT(PCI.ReadConfigDword(bus, dev, fct, PCI.Adr0Reg, fun) = PCI.Done);
		base := fun; ASSERT(~ODD(base)); DEC(base, base MOD 16);
		ASSERT(PCI.ReadConfigByte(bus, dev, fct, PCI.IntlReg, irq) = PCI.Done);
		ASSERT(PCI.ReadConfigByte(bus, dev, fct, PCI.RevIdReg, rev) = PCI.Done);
		IF DEBUG # DebugOff THEN
			KernelLog.String("{BT848} PCI device found! irq: ");
			KernelLog.Int(irq, 0); KernelLog.String("; base: "); KernelLog.Hex(base, 0);
			KernelLog.String("; rev: "); KernelLog.Hex(rev, 0); KernelLog.Ln();
		END;

		(* enable memory-mapping / bus mastering *)
		ASSERT(PCI.ReadConfigWord(bus, dev, fct, 4, command) = PCI.Done);
		ASSERT(PCI.WriteConfigWord(bus, dev, fct, 4, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, command)+{1,2})) = PCI.Done);
		Machine.MapPhysical(base, 4096, base);
		(* disable the Brooktree device *)
		SYSTEM.PUT32(base + BktrIntMask, AllIntsDisabled);
		SYSTEM.PUT16(base + BktrGPIODmaCtl, SYSTEM.VAL(LONGINT, FifoRiscDisabled));
		(* update the device control register on Bt878 and Bt879 cards *)
		ASSERT(PCI.ReadConfigWord(bus, dev, fct, 0040H, fun) = PCI.Done);
		fun := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, fun) + {0});	(* enable writes to the sub-system vendor id *)
		ASSERT(PCI.WriteConfigWord(bus, dev, fct, 0040H, fun) = PCI.Done);
		(* PCI latency timer. 32 is a good value for 4 bus mastering slots, if you have more than four, *)
		(* then 16 would be a better value. *)
		ASSERT(PCI.ReadConfigDword(bus, dev, fct, PCILatencyTimer, latency) = PCI.Done);
		latency := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(latency, -8)) * {0..7});
		IF latency = 0 THEN
			IF DEBUG # DebugOff THEN
				KernelLog.String("{BT848} PCI latency 0, setting latency to ");
				KernelLog.Int(BtDefaultLatencyValue, 0); KernelLog.Ln;
			END;
			ASSERT(PCI.WriteConfigDword(bus, dev, fct, PCILatencyTimer, ASH(BtDefaultLatencyValue, 8)) = PCI.Done);
		END;
		NEW(vcd, base, irq, device, rev);
		vcd.next := vcdDevices;
		vcdDevices := vcd;
		INC(index);
		INC(nOfInstalledDevices);
	END;
END ScanPCI;

(* Install procedure for installing a TV card. *)
PROCEDURE InstallDevices;
VAR
	res: LONGINT;
	dev: VideoCaptureDevice;
BEGIN {EXCLUSIVE}
	IF nOfInstalledDevices = 0 THEN
		IF DEBUG # DebugOff THEN
			KernelLog.String("{BT848} Installing device driver ..."); KernelLog.Ln();
			KernelLog.String("{BT848} Looking for Bt848 ..."); KernelLog.Ln;
		END;
		ScanPCI(PCIVendorBrooktree, PCIProductBrooktreeBt848);
		IF DEBUG # DebugOff THEN KernelLog.String("{BT848} Looking for Bt849 ..."); KernelLog.Ln; END;
		ScanPCI(PCIVendorBrooktree, PCIProductBrooktreeBt849);
		IF DEBUG # DebugOff THEN KernelLog.String("{BT848} Looking for Bt878 ..."); KernelLog.Ln; END;
		ScanPCI(PCIVendorBrooktree, PCIProductBrooktreeBt878);
		IF DEBUG # DebugOff THEN KernelLog.String("{BT848} Looking for Bt879 ..."); KernelLog.Ln; END;
		ScanPCI(PCIVendorBrooktree, PCIProductBrooktreeBt879);
		IF vcdDevices = NIL THEN
			KernelLog.String("{BT848} ERROR: No BT848-compatible TV card detected.");
			KernelLog.Ln;
		ELSE
			dev := vcdDevices;
			WHILE dev # NIL DO
				dev.SetName(PluginName);
				dev.desc := PluginDesc;
				TVDriver.devices.Add (dev, res);
				ASSERT (res = Plugins.Ok);
				dev := dev.next
			END;
			IF DEBUG # DebugOff THEN
				KernelLog.String("{BT848} Device driver successfully installed.");
				KernelLog.String(" Found "); KernelLog.Int(nOfInstalledDevices, 0);
				KernelLog.String(" devices."); KernelLog.Ln
			END;
		END;
	END;
END InstallDevices;

PROCEDURE Install*;
BEGIN
	InstallDevices;
END Install;

PROCEDURE UnInstallDevices;
VAR
	dev: VideoCaptureDevice;
BEGIN
	dev := vcdDevices;
	WHILE dev # NIL DO
		TVDriver.devices.Remove (dev);
		dev := dev.next
	END;
	IF vcdDevices # NIL THEN
		KernelLog.String("{BT848} Devices unloaded."); KernelLog.Ln
	END
END UnInstallDevices;

PROCEDURE UnInstall*;
BEGIN
	Cleanup;
END UnInstall;


(* Cleanup procedure if module is released. *)
PROCEDURE Cleanup;
VAR vcd, next: VideoCaptureDevice;
BEGIN
	next := vcdDevices;
	WHILE next # NIL DO
		vcd := next;
		next := vcd.next;
		vcd.Finalize
	END;
	UnInstallDevices
END Cleanup;


BEGIN (* of module code *)
	vcdDevices := NIL;
	cards[CardUnknown].cardID := CardUnknown;
	cards[CardUnknown].name := "Unknown";
	cards[CardUnknown].tunerPLLAddr := 0;
	cards[CardUnknown].dbx := FALSE;
	cards[CardUnknown].msp3400c := FALSE;
	cards[CardUnknown].dpl3518a := FALSE;
	cards[CardUnknown].eepromAddr := 0;
	cards[CardUnknown].eepromSize := 0;
	cards[CardUnknown].audioMUXs[0] := 0;
	cards[CardUnknown].audioMUXs[1] := 0;
	cards[CardUnknown].audioMUXs[2] := 0;
	cards[CardUnknown].audioMUXs[3] := 0;
	cards[CardUnknown].audioMUXs[4] := 0;
	cards[CardUnknown].gpioMUXBits := 0;
	cards[CardHauppauge].cardID := CardHauppauge;
	cards[CardHauppauge].name := "Hauppauge WinCast/TV";
	cards[CardHauppauge].tunerPLLAddr := 0;
	cards[CardHauppauge].dbx := FALSE;
	cards[CardHauppauge].msp3400c := FALSE;
	cards[CardHauppauge].dpl3518a := FALSE;
	cards[CardHauppauge].eepromAddr := PFC8582WAddr;
	cards[CardHauppauge].eepromSize := 256 DIV EEPromBlockSize;
	cards[CardHauppauge].audioMUXs[0] := 0000H;
	cards[CardHauppauge].audioMUXs[1] := 0002H;
	cards[CardHauppauge].audioMUXs[2] := 0001H;
	cards[CardHauppauge].audioMUXs[3] := 0004H;
	cards[CardHauppauge].audioMUXs[4] := 1;
	cards[CardHauppauge].gpioMUXBits := 000FH;

	(* tuners *)

	tuners[NoTuner].name := "<no tuner>";
	tuners[NoTuner].type := TunerTypeXXX;
	tuners[NoTuner].pllControl[0] := 0000H;
	tuners[NoTuner].pllControl[1] := 0000H;
	tuners[NoTuner].pllControl[2] := 0000H;
	tuners[NoTuner].pllControl[3] := 0000H;
	tuners[NoTuner].bandLimits[0] := 0000H;
	tuners[NoTuner].bandLimits[1] := 0000H;
	tuners[NoTuner].bandAddrs[0] := 0000H;
	tuners[NoTuner].bandAddrs[1] := 0000H;
	tuners[NoTuner].bandAddrs[2] := 0000H;
	tuners[NoTuner].bandAddrs[3] := 0000H;
	tuners[TemicNTSC].name := "Temic NTSC";
	tuners[TemicNTSC].type := TunerTypeNTSC;
	tuners[TemicNTSC].pllControl[0] := TSA552xSControl;
	tuners[TemicNTSC].pllControl[1] := TSA552xSControl;
	tuners[TemicNTSC].pllControl[2] := TSA552xSControl;
	tuners[TemicNTSC].pllControl[3] := 0000H;
	tuners[TemicNTSC].bandLimits[0] := ENTIER(157.25 * FreqFactor);
	tuners[TemicNTSC].bandLimits[1] := ENTIER(463.25 * FreqFactor);
	tuners[TemicNTSC].bandAddrs[0] := 0002H;
	tuners[TemicNTSC].bandAddrs[1] := 0004H;
	tuners[TemicNTSC].bandAddrs[2] := 0001H;
	tuners[TemicNTSC].bandAddrs[3] := 0000H;
	tuners[TemicPAL].name := "Temic PAL";
	tuners[TemicPAL].type := TunerTypePAL;
	tuners[TemicPAL].pllControl[0] := TSA552xSControl;
	tuners[TemicPAL].pllControl[1] := TSA552xSControl;
	tuners[TemicPAL].pllControl[2] := TSA552xSControl;
	tuners[TemicPAL].pllControl[3] := 0000H;
	tuners[TemicPAL].bandLimits[0] := ENTIER(140.25 * FreqFactor);
	tuners[TemicPAL].bandLimits[1] := ENTIER(463.25 * FreqFactor);
	tuners[TemicPAL].bandAddrs[0] := 0002H;
	tuners[TemicPAL].bandAddrs[1] := 0004H;
	tuners[TemicPAL].bandAddrs[2] := 0001H;
	tuners[TemicPAL].bandAddrs[3] := 0000H;
	tuners[TemicSECAM].name := "Temic SECAM";
	tuners[TemicSECAM].type := TunerTypeSECAM;
	tuners[TemicSECAM].pllControl[0] := TSA552xSControl;
	tuners[TemicSECAM].pllControl[1] := TSA552xSControl;
	tuners[TemicSECAM].pllControl[2] := TSA552xSControl;
	tuners[TemicSECAM].pllControl[3] := ENTIER(157.25 * FreqFactor);
	tuners[TemicSECAM].bandLimits[0] := ENTIER(463.25 * FreqFactor);
	tuners[TemicSECAM].bandLimits[1] := 0000H;
	tuners[TemicSECAM].bandAddrs[0] := 0002H;
	tuners[TemicSECAM].bandAddrs[1] := 0004H;
	tuners[TemicSECAM].bandAddrs[2] := 0001H;
	tuners[TemicSECAM].bandAddrs[3] := 0000H;
	tuners[PhilipsNTSC].name := "Philips NTSC";
	tuners[PhilipsNTSC].type := TunerTypeNTSC;
	tuners[PhilipsNTSC].pllControl[0] := TSA552xSControl;
	tuners[PhilipsNTSC].pllControl[1] := TSA552xSControl;
	tuners[PhilipsNTSC].pllControl[2] := TSA552xSControl;
	tuners[PhilipsNTSC].pllControl[3] := 0000H;
	tuners[PhilipsNTSC].bandLimits[0] := ENTIER(157.25 * FreqFactor);
	tuners[PhilipsNTSC].bandLimits[1] := ENTIER(451.25 * FreqFactor);
	tuners[PhilipsNTSC].bandAddrs[0] := 00A0H;
	tuners[PhilipsNTSC].bandAddrs[1] := 0090H;
	tuners[PhilipsNTSC].bandAddrs[2] := 0030H;
	tuners[PhilipsNTSC].bandAddrs[3] := 0000H;
	tuners[PhilipsPAL].name := "Philips PAL";
	tuners[PhilipsPAL].type := TunerTypePAL;
	tuners[PhilipsPAL].pllControl[0] := TSA552xSControl;
	tuners[PhilipsPAL].pllControl[1] := TSA552xSControl;
	tuners[PhilipsPAL].pllControl[2] := TSA552xSControl;
	tuners[PhilipsPAL].pllControl[3] := 0000H;
	tuners[PhilipsPAL].bandLimits[0] := ENTIER(168.25 * FreqFactor);
	tuners[PhilipsPAL].bandLimits[1] := ENTIER(447.25 * FreqFactor);
	tuners[PhilipsPAL].bandAddrs[0] := 00A0H;
	tuners[PhilipsPAL].bandAddrs[1] := 0090H;
	tuners[PhilipsPAL].bandAddrs[2] := 0030H;
	tuners[PhilipsPAL].bandAddrs[3] := 0000H;
	tuners[PhilipsSECAM].name := "Philips SECAM";
	tuners[PhilipsSECAM].type := TunerTypeSECAM;
	tuners[PhilipsSECAM].pllControl[0] := TSA552xSControl;
	tuners[PhilipsSECAM].pllControl[1] := TSA552xSControl;
	tuners[PhilipsSECAM].pllControl[2] := TSA552xSControl;
	tuners[PhilipsSECAM].pllControl[3] := 0000H;
	tuners[PhilipsSECAM].bandLimits[0] := ENTIER(168.25 * FreqFactor);
	tuners[PhilipsSECAM].bandLimits[1] := ENTIER(447.25 * FreqFactor);
	tuners[PhilipsSECAM].bandAddrs[0] := 00A7H;
	tuners[PhilipsSECAM].bandAddrs[1] := 0097H;
	tuners[PhilipsSECAM].bandAddrs[2] := 0037H;
	tuners[PhilipsSECAM].bandAddrs[3] := 0000H;
	tuners[TemicPALI].name := "Temic PAL I";
	tuners[TemicPALI].type := TunerTypePAL;
	tuners[TemicPALI].pllControl[0] := TSA552xSControl;
	tuners[TemicPALI].pllControl[1] := TSA552xSControl;
	tuners[TemicPALI].pllControl[2] := TSA552xSControl;
	tuners[TemicPALI].pllControl[3] := 0000H;
	tuners[TemicPALI].bandLimits[0] := ENTIER(170.00 * FreqFactor);
	tuners[TemicPALI].bandLimits[1] := ENTIER(450.00 * FreqFactor);
	tuners[TemicPALI].bandAddrs[0] := 0002H;
	tuners[TemicPALI].bandAddrs[1] := 0004H;
	tuners[TemicPALI].bandAddrs[2] := 0001H;
	tuners[TemicPALI].bandAddrs[3] := 0000H;
	tuners[PhilipsPALI].name := "Philips PAL I";
	tuners[PhilipsPALI].type := TunerTypePAL;
	tuners[PhilipsPALI].pllControl[0] := TSA552xSControl;
	tuners[PhilipsPALI].pllControl[1] := TSA552xSControl;
	tuners[PhilipsPALI].pllControl[2] := TSA552xSControl;
	tuners[PhilipsPALI].pllControl[3] := 0000H;
	tuners[PhilipsPALI].bandLimits[0] := ENTIER(140.25 * FreqFactor);
	tuners[PhilipsPALI].bandLimits[1] := ENTIER(463.25 * FreqFactor);
	tuners[PhilipsPALI].bandAddrs[0] := 00A0H;
	tuners[PhilipsPALI].bandAddrs[1] := 0090H;
	tuners[PhilipsPALI].bandAddrs[2] := 0030H;
	tuners[PhilipsPALI].bandAddrs[3] := 0000H;
	tuners[PhilipsFR1236NTSC].name := "Philips FR1236 NTSC FM";
	tuners[PhilipsFR1236NTSC].type := TunerTypeNTSC;
	tuners[PhilipsFR1236NTSC].pllControl[0] := TSA552xFControl;
	tuners[PhilipsFR1236NTSC].pllControl[1] := TSA552xFControl;
	tuners[PhilipsFR1236NTSC].pllControl[2] := TSA552xFControl;
	tuners[PhilipsFR1236NTSC].pllControl[3] := TSA552xRadio;
	tuners[PhilipsFR1236NTSC].bandLimits[0] := ENTIER(157.25 * FreqFactor);
	tuners[PhilipsFR1236NTSC].bandLimits[1] := ENTIER(451.25 * FreqFactor);
	tuners[PhilipsFR1236NTSC].bandAddrs[0] := 00A0H;
	tuners[PhilipsFR1236NTSC].bandAddrs[1] := 0090H;
	tuners[PhilipsFR1236NTSC].bandAddrs[2] := 0030H;
	tuners[PhilipsFR1236NTSC].bandAddrs[3] := 00A4H;
	tuners[PhilipsFR1216PAL].name := "Philips FR1216 PAL FM";
	tuners[PhilipsFR1216PAL].type := TunerTypePAL;
	tuners[PhilipsFR1216PAL].pllControl[0] := TSA552xFControl;
	tuners[PhilipsFR1216PAL].pllControl[1] := TSA552xFControl;
	tuners[PhilipsFR1216PAL].pllControl[2] := TSA552xFControl;
	tuners[PhilipsFR1216PAL].pllControl[3] := TSA552xRadio;
	tuners[PhilipsFR1216PAL].bandLimits[0] := ENTIER(168.25 * FreqFactor);
	tuners[PhilipsFR1216PAL].bandLimits[1] := ENTIER(447.25 * FreqFactor);
	tuners[PhilipsFR1216PAL].bandAddrs[0] := 00A0H;
	tuners[PhilipsFR1216PAL].bandAddrs[1] := 0090H;
	tuners[PhilipsFR1216PAL].bandAddrs[2] := 0030H;
	tuners[PhilipsFR1216PAL].bandAddrs[3] := 00A4H;
	tuners[PhilipsFR1236SECAM].name := "Philips FR1236 SECAM FM";
	tuners[PhilipsFR1236SECAM].type := TunerTypeSECAM;
	tuners[PhilipsFR1236SECAM].pllControl[0] := TSA552xFControl;
	tuners[PhilipsFR1236SECAM].pllControl[1] := TSA552xFControl;
	tuners[PhilipsFR1236SECAM].pllControl[2] := TSA552xFControl;
	tuners[PhilipsFR1236SECAM].pllControl[3] := TSA552xRadio;
	tuners[PhilipsFR1236SECAM].bandLimits[0] := ENTIER(168.25 * FreqFactor);
	tuners[PhilipsFR1236SECAM].bandLimits[1] := ENTIER(447.25 * FreqFactor);
	tuners[PhilipsFR1236SECAM].bandAddrs[0] := 00A7H;
	tuners[PhilipsFR1236SECAM].bandAddrs[1] := 0097H;
	tuners[PhilipsFR1236SECAM].bandAddrs[2] := 0037H;
	tuners[PhilipsFR1236SECAM].bandAddrs[3] := 00A4H;
	tuners[AlpsTSCH5].name := "ALPS TSCH5 NTSC FM";
	tuners[AlpsTSCH5].type := TunerTypeNTSC;
	tuners[AlpsTSCH5].pllControl[0] := TSCH5FControl;
	tuners[AlpsTSCH5].pllControl[1] := TSCH5FControl;
	tuners[AlpsTSCH5].pllControl[2] := TSCH5FControl;
	tuners[AlpsTSCH5].pllControl[3] := TSCH5Radio;
	tuners[AlpsTSCH5].bandLimits[0] := ENTIER(137.25 * FreqFactor);
	tuners[AlpsTSCH5].bandLimits[1] := ENTIER(385.25 * FreqFactor);
	tuners[AlpsTSCH5].bandAddrs[0] := 0014H;
	tuners[AlpsTSCH5].bandAddrs[1] := 0012H;
	tuners[AlpsTSCH5].bandAddrs[2] := 0011H;
	tuners[AlpsTSCH5].bandAddrs[3] := 0004H;
	tuners[AlpsTSBH1].name := "ALPS TSBH1 NTSC";
	tuners[AlpsTSBH1].type := TunerTypeNTSC;
	tuners[AlpsTSBH1].pllControl[0] := TSBH1FControl;
	tuners[AlpsTSBH1].pllControl[1] := TSBH1FControl;
	tuners[AlpsTSBH1].pllControl[2] := TSBH1FControl;
	tuners[AlpsTSBH1].pllControl[3] := 0000H;
	tuners[AlpsTSBH1].bandLimits[0] := ENTIER(137.25 * FreqFactor);
	tuners[AlpsTSBH1].bandLimits[1] := ENTIER(385.25 * FreqFactor);
	tuners[AlpsTSBH1].bandAddrs[0] := 0001H;
	tuners[AlpsTSBH1].bandAddrs[1] := 0002H;
	tuners[AlpsTSBH1].bandAddrs[2] := 0008H;
	tuners[AlpsTSBH1].bandAddrs[3] := 0000H;
	tuners[LGPALBG].name := "LG PAL BG (TPI8PSB11D)";
	tuners[LGPALBG].type := TunerTypePAL;
	tuners[LGPALBG].pllControl[0] := TSA552xFControl;
	tuners[LGPALBG].pllControl[1] := TSA552xFControl;
	tuners[LGPALBG].pllControl[2] := TSA552xFControl;
	tuners[LGPALBG].pllControl[3] := 0000H;
	tuners[LGPALBG].bandLimits[0] := ENTIER(170.00 * FreqFactor);
	tuners[LGPALBG].bandLimits[1] := ENTIER(450.00 * FreqFactor);
	tuners[LGPALBG].bandAddrs[0] := 00A0H;
	tuners[LGPALBG].bandAddrs[1] := 0090H;
	tuners[LGPALBG].bandAddrs[2] := 0030H;
	tuners[LGPALBG].bandAddrs[3] := 0000H;


	(* channel sets *)

	(* Western-Europe channel set *)
	freqTable[WesternEuropeanChnlSet].maxChnl := 121;
	freqTable[WesternEuropeanChnlSet].ifFreq := ENTIER(38.9 * FreqFactor);
	NEW(freqTable[WesternEuropeanChnlSet].chnls, 11);
	freqTable[WesternEuropeanChnlSet].chnls[0].baseChnl := 100;
	freqTable[WesternEuropeanChnlSet].chnls[0].baseChnlFreq := ENTIER(303.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[0].offsetFreq := ENTIER(8.00 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[1].baseChnl := 90;
	freqTable[WesternEuropeanChnlSet].chnls[1].baseChnlFreq := ENTIER(231.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[1].offsetFreq := ENTIER(7.00 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[2].baseChnl := 80;
	freqTable[WesternEuropeanChnlSet].chnls[2].baseChnlFreq := ENTIER(105.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[2].offsetFreq := ENTIER(7.00 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[3].baseChnl := 74;
	freqTable[WesternEuropeanChnlSet].chnls[3].baseChnlFreq := ENTIER(69.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[3].offsetFreq := ENTIER(7.00 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[4].baseChnl := 21;
	freqTable[WesternEuropeanChnlSet].chnls[4].baseChnlFreq := ENTIER(471.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[4].offsetFreq := ENTIER(8.00 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[5].baseChnl := 17;
	freqTable[WesternEuropeanChnlSet].chnls[5].baseChnlFreq := ENTIER(183.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[5].offsetFreq := ENTIER(9.00 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[6].baseChnl := 16;
	freqTable[WesternEuropeanChnlSet].chnls[6].baseChnlFreq := ENTIER(175.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[6].offsetFreq := ENTIER(9.00 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[7].baseChnl := 15;
	freqTable[WesternEuropeanChnlSet].chnls[7].baseChnlFreq := ENTIER(82.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[7].offsetFreq := ENTIER(8.50 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[8].baseChnl := 13;
	freqTable[WesternEuropeanChnlSet].chnls[8].baseChnlFreq := ENTIER(53.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[8].offsetFreq := ENTIER(8.50 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[9].baseChnl := 5;
	freqTable[WesternEuropeanChnlSet].chnls[9].baseChnlFreq := ENTIER(175.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[9].offsetFreq := ENTIER(7.00 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[10].baseChnl := 2;
	freqTable[WesternEuropeanChnlSet].chnls[10].baseChnlFreq := ENTIER(48.25 * FreqFactor);
	freqTable[WesternEuropeanChnlSet].chnls[10].offsetFreq := ENTIER(7.00 * FreqFactor);

	(* format parameters *)
	FOR i := 0 TO NoOfFormatParams-1 DO
		NEW(formatParams[i]);
	END;
	(* Bt848IFormFAuto *)
	formatParams[Bt848IFormFAuto].vTotal := 525;
	formatParams[Bt848IFormFAuto].vDelay := 26;
	formatParams[Bt848IFormFAuto].vActive := 480;
	formatParams[Bt848IFormFAuto].hTotal := 910;
	formatParams[Bt848IFormFAuto].hDelay := 135;
	formatParams[Bt848IFormFAuto].hActive := 754;
	formatParams[Bt848IFormFAuto].scaledHActive := 640;
	formatParams[Bt848IFormFAuto].scaledHTotal := 780;
	formatParams[Bt848IFormFAuto].frameRate := 30;
	formatParams[Bt848IFormFAuto].aDelay := 0068H;
	formatParams[Bt848IFormFAuto].bDelay := 005DH;
	formatParams[Bt848IFormFAuto].iformXTSel := SYSTEM.VAL(LONGINT, Bt848IFormXAuto);
	formatParams[Bt848IFormFAuto].vbiNumLines := 12;
	formatParams[Bt848IFormFAuto].vbiNumSamples := 1600;
	(* Bt848IFormFNTSCM *)
	formatParams[Bt848IFormFNTSCM].vTotal := 525;
	formatParams[Bt848IFormFNTSCM].vDelay := 26;
	formatParams[Bt848IFormFNTSCM].vActive := 480;
	formatParams[Bt848IFormFNTSCM].hTotal := 910;
	formatParams[Bt848IFormFNTSCM].hDelay := 135;
	formatParams[Bt848IFormFNTSCM].hActive := 754;
	formatParams[Bt848IFormFNTSCM].scaledHActive := 640;
	formatParams[Bt848IFormFNTSCM].scaledHTotal := 780;
	formatParams[Bt848IFormFNTSCM].frameRate := 30;
	formatParams[Bt848IFormFNTSCM].aDelay := 0068H;
	formatParams[Bt848IFormFNTSCM].bDelay := 005DH;
	formatParams[Bt848IFormFNTSCM].iformXTSel := SYSTEM.VAL(LONGINT, Bt848IFormXXT0);
	formatParams[Bt848IFormFNTSCM].vbiNumLines := 12;
	formatParams[Bt848IFormFNTSCM].vbiNumSamples := 1600;
	(* Bt848IFormFNTSCJ *)
	formatParams[Bt848IFormFNTSCJ].vTotal := 525;
	formatParams[Bt848IFormFNTSCJ].vDelay := 22;
	formatParams[Bt848IFormFNTSCJ].vActive := 480;
	formatParams[Bt848IFormFNTSCJ].hTotal := 910;
	formatParams[Bt848IFormFNTSCJ].hDelay := 135;
	formatParams[Bt848IFormFNTSCJ].hActive := 754;
	formatParams[Bt848IFormFNTSCJ].scaledHActive := 640;
	formatParams[Bt848IFormFNTSCJ].scaledHTotal := 780;
	formatParams[Bt848IFormFNTSCJ].frameRate := 30;
	formatParams[Bt848IFormFNTSCJ].aDelay := 0068H;
	formatParams[Bt848IFormFNTSCJ].bDelay := 005DH;
	formatParams[Bt848IFormFNTSCJ].iformXTSel := SYSTEM.VAL(LONGINT, Bt848IFormXXT0);
	formatParams[Bt848IFormFNTSCJ].vbiNumLines := 12;
	formatParams[Bt848IFormFNTSCJ].vbiNumSamples := 1600;
	(* Bt848IFormFPalBDGHI *)
	formatParams[Bt848IFormFPalBDGHI].vTotal := 625;
	formatParams[Bt848IFormFPalBDGHI].vDelay := 32;
	formatParams[Bt848IFormFPalBDGHI].vActive := 576;
	formatParams[Bt848IFormFPalBDGHI].hTotal := 1135;
	formatParams[Bt848IFormFPalBDGHI].hDelay := 186;
	formatParams[Bt848IFormFPalBDGHI].hActive := 924;
	formatParams[Bt848IFormFPalBDGHI].scaledHActive := 768;
	formatParams[Bt848IFormFPalBDGHI].scaledHTotal := 944;
	formatParams[Bt848IFormFPalBDGHI].frameRate := 25;
	formatParams[Bt848IFormFPalBDGHI].aDelay := 007FH;
	formatParams[Bt848IFormFPalBDGHI].bDelay := 0072H;
	formatParams[Bt848IFormFPalBDGHI].iformXTSel := SYSTEM.VAL(LONGINT, Bt848IFormXXT1);
	formatParams[Bt848IFormFPalBDGHI].vbiNumLines := 16;
	formatParams[Bt848IFormFPalBDGHI].vbiNumSamples := 2044;
	(* Bt848IFormFPalM *)
	formatParams[Bt848IFormFPalM].vTotal := 525;
	formatParams[Bt848IFormFPalM].vDelay := 22;
	formatParams[Bt848IFormFPalM].vActive := 480;
	formatParams[Bt848IFormFPalM].hTotal := 910;
	formatParams[Bt848IFormFPalM].hDelay := 135;
	formatParams[Bt848IFormFPalM].hActive := 754;
	formatParams[Bt848IFormFPalM].scaledHActive := 640;
	formatParams[Bt848IFormFPalM].scaledHTotal := 780;
	formatParams[Bt848IFormFPalM].frameRate := 30;
	formatParams[Bt848IFormFPalM].aDelay := 0068H;
	formatParams[Bt848IFormFPalM].bDelay := 005DH;
	formatParams[Bt848IFormFPalM].iformXTSel := SYSTEM.VAL(LONGINT, Bt848IFormXXT0);
	formatParams[Bt848IFormFPalM].vbiNumLines := 16;
	formatParams[Bt848IFormFPalM].vbiNumSamples := 1600;
	(* Bt848IFormFPalN *)
	formatParams[Bt848IFormFPalN].vTotal := 625;
	formatParams[Bt848IFormFPalN].vDelay := 32;
	formatParams[Bt848IFormFPalN].vActive := 576;
	formatParams[Bt848IFormFPalN].hTotal := 1135;
	formatParams[Bt848IFormFPalN].hDelay := 186;
	formatParams[Bt848IFormFPalN].hActive := 924;
	formatParams[Bt848IFormFPalN].scaledHActive := 768;
	formatParams[Bt848IFormFPalN].scaledHTotal := 944;
	formatParams[Bt848IFormFPalN].frameRate := 25;
	formatParams[Bt848IFormFPalN].aDelay := 007FH;
	formatParams[Bt848IFormFPalN].bDelay := 0072H;
	formatParams[Bt848IFormFPalN].iformXTSel := SYSTEM.VAL(LONGINT, Bt848IFormXXT1);
	formatParams[Bt848IFormFPalN].vbiNumLines := 16;
	formatParams[Bt848IFormFPalN].vbiNumSamples := 2044;
	(* Bt848IFormFSecam *)
	formatParams[Bt848IFormFSecam].vTotal := 625;
	formatParams[Bt848IFormFSecam].vDelay := 32;
	formatParams[Bt848IFormFSecam].vActive := 576;
	formatParams[Bt848IFormFSecam].hTotal := 1135;
	formatParams[Bt848IFormFSecam].hDelay := 186;
	formatParams[Bt848IFormFSecam].hActive := 924;
	formatParams[Bt848IFormFSecam].scaledHActive := 768;
	formatParams[Bt848IFormFSecam].scaledHTotal := 944;
	formatParams[Bt848IFormFSecam].frameRate := 25;
	formatParams[Bt848IFormFSecam].aDelay := 007FH;
	formatParams[Bt848IFormFSecam].bDelay := 00A0H;
	formatParams[Bt848IFormFSecam].iformXTSel := SYSTEM.VAL(LONGINT, Bt848IFormXXT1);
	formatParams[Bt848IFormFSecam].vbiNumLines := 16;
	formatParams[Bt848IFormFSecam].vbiNumSamples := 2044;
	(* Bt848IFormFRSVD *)
	formatParams[Bt848IFormFRSVD].vTotal := 625;
	formatParams[Bt848IFormFRSVD].vDelay := 32;
	formatParams[Bt848IFormFRSVD].vActive := 576;
	formatParams[Bt848IFormFRSVD].hTotal := 1135;
	formatParams[Bt848IFormFRSVD].hDelay := 186;
	formatParams[Bt848IFormFRSVD].hActive := 924;
	formatParams[Bt848IFormFRSVD].scaledHActive := 768;
	formatParams[Bt848IFormFRSVD].scaledHTotal := 944;
	formatParams[Bt848IFormFRSVD].frameRate := 25;
	formatParams[Bt848IFormFRSVD].aDelay := 007FH;
	formatParams[Bt848IFormFRSVD].bDelay := 0072H;
	formatParams[Bt848IFormFRSVD].iformXTSel := SYSTEM.VAL(LONGINT, Bt848IFormXXT0);
	formatParams[Bt848IFormFRSVD].vbiNumLines := 16;
	formatParams[Bt848IFormFRSVD].vbiNumSamples := 2044;

	(* pixel formats *)
	FOR i := 0 TO NoOfPixelFormats-1 DO
		NEW(pixelFormatTable[i]);
	END;
	pixelFormatTable[0].index := 0;
	pixelFormatTable[0].type := AosPixTypeRGB;
	pixelFormatTable[0].bpp := 2;
	pixelFormatTable[0].masks[0] := 7C00H;
	pixelFormatTable[0].masks[1] := 03E0H;
	pixelFormatTable[0].masks[2] := 001FH;
	pixelFormatTable[0].swapBytes := FALSE;
	pixelFormatTable[0].swapShorts := FALSE;
	pixelFormatTable[0].colorFormat := 0033H;
	pixelFormatTable[1].index := 0;
	pixelFormatTable[1].type := AosPixTypeRGB;
	pixelFormatTable[1].bpp := 2;
	pixelFormatTable[1].masks[0] := 7C00H;
	pixelFormatTable[1].masks[1] := 03E0H;
	pixelFormatTable[1].masks[2] := 001FH;
	pixelFormatTable[1].swapBytes := TRUE;
	pixelFormatTable[1].swapShorts := FALSE;
	pixelFormatTable[1].colorFormat := 0033H;
	pixelFormatTable[2].index := 0;
	pixelFormatTable[2].type := AosPixTypeRGB;
	pixelFormatTable[2].bpp := 2;
	pixelFormatTable[2].masks[0] := 00F800H;
	pixelFormatTable[2].masks[1] := 07E0H;
	pixelFormatTable[2].masks[2] := 001FH;
	pixelFormatTable[2].swapBytes := FALSE;
	pixelFormatTable[2].swapShorts := FALSE;
	pixelFormatTable[2].colorFormat := 0022H;
	pixelFormatTable[3].index := 0;
	pixelFormatTable[3].type := AosPixTypeRGB;
	pixelFormatTable[3].bpp := 2;
	pixelFormatTable[3].masks[0] := 00F800H;
	pixelFormatTable[3].masks[1] := 07E0H;
	pixelFormatTable[3].masks[2] := 001FH;
	pixelFormatTable[3].swapBytes := TRUE;
	pixelFormatTable[3].swapShorts := FALSE;
	pixelFormatTable[3].colorFormat := 0022H;
	pixelFormatTable[4].index := 0;
	pixelFormatTable[4].type := AosPixTypeRGB;
	pixelFormatTable[4].bpp := 3;
	pixelFormatTable[4].masks[0] := 00FF0000H;
	pixelFormatTable[4].masks[1] := 0000FF00H;
	pixelFormatTable[4].masks[2] := 000000FFH;
	pixelFormatTable[4].swapBytes := TRUE;
	pixelFormatTable[4].swapShorts := FALSE;
	pixelFormatTable[4].colorFormat := 0011H;
	pixelFormatTable[5].index := 0;
	pixelFormatTable[5].type := AosPixTypeRGB;
	pixelFormatTable[5].bpp := 4;
	pixelFormatTable[5].masks[0] := 00FF0000H;
	pixelFormatTable[5].masks[1] := 0000FF00H;
	pixelFormatTable[5].masks[2] := 000000FFH;
	pixelFormatTable[5].swapBytes := FALSE;
	pixelFormatTable[5].swapShorts := FALSE;
	pixelFormatTable[5].colorFormat := 0000H;
	pixelFormatTable[6].index := 0;
	pixelFormatTable[6].type := AosPixTypeRGB;
	pixelFormatTable[6].bpp := 4;
	pixelFormatTable[6].masks[0] := 00FF0000H;
	pixelFormatTable[6].masks[1] := 0000FF00H;
	pixelFormatTable[6].masks[2] := 000000FFH;
	pixelFormatTable[6].swapBytes := FALSE;
	pixelFormatTable[6].swapShorts := TRUE;
	pixelFormatTable[6].colorFormat := 0000H;
	pixelFormatTable[7].index := 0;
	pixelFormatTable[7].type := AosPixTypeRGB;
	pixelFormatTable[7].bpp := 4;
	pixelFormatTable[7].masks[0] := 00FF0000H;
	pixelFormatTable[7].masks[1] := 0000FF00H;
	pixelFormatTable[7].masks[2] := 000000FFH;
	pixelFormatTable[7].swapBytes := TRUE;
	pixelFormatTable[7].swapShorts := FALSE;
	pixelFormatTable[7].colorFormat := 0000H;
	pixelFormatTable[8].index := 0;
	pixelFormatTable[8].type := AosPixTypeRGB;
	pixelFormatTable[8].bpp := 4;
	pixelFormatTable[8].masks[0] := 00FF0000H;
	pixelFormatTable[8].masks[1] := 0000FF00H;
	pixelFormatTable[8].masks[2] := 000000FFH;
	pixelFormatTable[8].swapBytes := TRUE;
	pixelFormatTable[8].swapShorts := TRUE;
	pixelFormatTable[8].colorFormat := 0000H;
	pixelFormatTable[9].index := 0;
	pixelFormatTable[9].type := AosPixTypeYUV;
	pixelFormatTable[9].bpp := 2;
	pixelFormatTable[9].masks[0] := 00FF0000H;
	pixelFormatTable[9].masks[1] := 0000FF00H;
	pixelFormatTable[9].masks[2] := 000000FFH;
	pixelFormatTable[9].swapBytes := TRUE;
	pixelFormatTable[9].swapShorts := TRUE;
	pixelFormatTable[9].colorFormat := 0088H;
	pixelFormatTable[10].index := 0;
	pixelFormatTable[10].type := AosPixTypeYUVPacked;
	pixelFormatTable[10].bpp := 2;
	pixelFormatTable[10].masks[0] := 00FF0000H;
	pixelFormatTable[10].masks[1] := 0000FF00H;
	pixelFormatTable[10].masks[2] := 000000FFH;
	pixelFormatTable[10].swapBytes := FALSE;
	pixelFormatTable[10].swapShorts := TRUE;
	pixelFormatTable[10].colorFormat := 0044H;
	pixelFormatTable[11].index := 0;
	pixelFormatTable[11].type := AosPixTypeYUV12;
	pixelFormatTable[11].bpp := 2;
	pixelFormatTable[11].masks[0] := 00FF0000H;
	pixelFormatTable[11].masks[1] := 0000FF00H;
	pixelFormatTable[11].masks[2] := 000000FFH;
	pixelFormatTable[11].swapBytes := TRUE;
	pixelFormatTable[11].swapShorts := TRUE;
	pixelFormatTable[11].colorFormat := 0088H;

	Modules.InstallTermHandler(Cleanup);
	InstallDevices;
END BT848. (* of module *)

System.Free BT848 ~
Aos.Call BT848.Install