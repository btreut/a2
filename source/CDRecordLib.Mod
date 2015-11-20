MODULE CDRecordLib;

IMPORT SYSTEM, KernelLog, Ata := ATADisks, Utils := CDRecordUtils;

CONST
	TrackLimit = 99;
	ResOk = 0; ResErr = 1;
	Trace = FALSE;

	Ignore* = 0H;

	(* Mode Pages *)

	(* Page Codes *)
	MPCapabilities* = 2AH;
	MPWriteParameters* = 5H;

	(* Page Control *)
	MPCurrent* = 0H;
	MPChangeable* = 1H;
	MPDefault* = 2H;
	MPSaved* = 3H;

	MPPSBit* = 7;

	(* Capabilities *)
	MPCCdrBit* = 0;
	MPCCdRwBit* = 1;
	MPCBufeBit* = 7;
	MPCMultisessionBit* = 5;

	(* Loading Mechanism *)
	LMTMask* = {5..7}; LMTOfs* = 5;
	LMTCaddy* = 0;
	LMTTray* = 1;
	LMTPopUp * = 2;


	(* Write Parameters *)
	MPWBufeBit* = 6;
	MPWTestWriteBit* = 4;

	MPWWriteTypeMask* = {0..3}; MPWWriteTypeOfs* = 0;
	WTPacket* = 0H;
	WTTao* = 1H;
	WTSao* = 2H;
	WTRaw* = 3H;
	WTLayerJump* = 4H;

	MPWTrackModeMask* = {0..3}; MPWTrackModeOfs* = 0; (* ECMA 130. p. 20 Control Nibble *)
	(* Track Mode is the q channel control nibble. See below *)

	MPWDataBlockMask* = {0..3}; MPWDataBlockOfs* = 0;
	DBRaw* = 0H; (* 2352 *)
	DBIsoMode1* = 8H;
	DBIsoMode2* = 9H;

	(* multisession *)
	MPWMultisessionMask* = {6,7}; MPWMultisessionOfs* = 6;
	MSNoNextSessNoB0* = 0H;
	MSNoNextSessB0* = 1H;
	MSNextSessB0* = 3H;

	(* Features *)
	FMorphing* = 2H;
	FMastering* = 2EH;

	FAll* = 0H;
	FCurrent* = 1H;
	FOne* = 2H;

	(* CD Mastering *)
	FDMSaoBit* = 5;

	(* ReadTrackInformation *)
	TRAdrType0 = 0H;
	TRAdrType1 = 1H;
	TRAdrType2 = 2H;
	TRAdrType3 = 3H;

	TRInvisible* = 0FFH;

	(* Read Toc *)

	TCFormatToc* = 0H;
	TCFormatSessionInfo* = 1H;
	TCFormatFullToc* = 2H;
	TCFormatPMA* = 3H;
	TCFormatATIP* = 4H;
	TCFormatCDText* = 5H;

	(* track descriptor *)
	(* Control is the q channel control nibble. see below *)
	TCControlMask* = {0..3}; TCControlOfs* = 0; (* control nibble *)

	(* ATIP *)
	ATCdRwBit* = 6;
	ATA1ValidBit* = 2; ATA2ValidBit* = 1; ATA3ValidBit* = 0;

	ATSubTypeMask* = {3..5}; ATSubTypeOfs* = 3;
	(* cdr subtypes orange book *)
	ATCdrNormal*= 0H;
	ATCdrHighSpeed* =1H;

	(* cdrw subtypes *)
	ATCdRwStandardSpeed* = 0H;
	ATCdRwHighSpeed* = 1H;
	ATCdRwUltraHighSpeed* = 2H;
	ATCdRwUltraHighSpeedPlus* = 3H;

	ATRefSpeedMask* ={0..2}; ATRefSpeedOfs*=0;
	(* A1 / A2 / A3 Values *)
	ATCLVHighMask* = {0..3}; ATCLVHighOfs* = 0;
	ATCLVLowMask* = {4..6}; ATCLVLowOfs* = 4;

	(* disc information block *)
	(* Data Type *)
	DTDiscInfoBlock* =  0H;
	DTAssignedTrack* = 1H;

	DIBErasableBit* = 4;

	(*Disc Status *)
	DIBDiscStatusMask* = {0,1}; DIBDiscStatusOfs* = 0;
	DSEmpty* = 0H;
	DSAppendable* = 1H;
	DSComplete* = 2H;
	DSOtherStatus* =4H;

	(* Last Session Status *)
	DIBSessionStatusMask* = {2, 3}; DIBSessionStatusOfs*= 2;
	LSSEmpty* = 0H;
	LSSIncomplete* = 1H;
	LSSComplete* = 3H;

	(* disc types *)
	DTCdDACdRom* = 0H;
	DTCdI* = 10H;
	DTCdRomXA* = 20H;
	DTUndefined* = 0FFH;

	(* Cue Sheet *)
	(* Ctl/Adr *)
	CTLMask* = {4..7}; CTLOfs* = 4;
	(* CTL is the q channel control nibble. see below *)

	ADRMask* = {0..3}; ADROfs* = 0;
	ADRTno* = 1H;
	ADRCatalogCode* = 2H;
	ADRIsrcCode* =2H;

	(* main data form *)
	DFMLeadin* = 1H;
	DFMLeadout* = 1H;
	DFMDigitalAudio* = 0H;
	DFMCdRomMode1* = 10H;
	DFMMask* = {0..5}; DFMOfs* = 0;

	(* Close Session *)
	(* Close Function *)
	CFTrack* = 1H;
	CFSession* = 2H;

	(* q Channel Control nibble *)
	QCWithPreEmphasis* = 0;
	QCCopyPermitted* = 1;
	QCDataTrack* = 2;
	QC4ChannelAudio* = 3;

	(* Blank Disc*)
	BDEntire* = 0H;
	BDQuick* = 1H;
	BDTrack* = 2H; (* optional *)

	(* get performance *)
	PTypeWriteSpeed* = 3H;

	(* Read CD *)
	(* sector type *)
	STAny* = 0;
	STCdDa* = 1;
	STMode1* = 2;
	STMode2* = 3;
	STMode2Form1* = 4;
	STMode2Form2*= 5;

	(* header *)
	HNone*= SYSTEM.VAL(SET, ASH(0, 5));
	HOnlyHeader* = SYSTEM.VAL(SET, ASH(1, 5));
	HOnlySubHeader* = SYSTEM.VAL(SET, ASH(2, 5));
	HAllHeaders* = SYSTEM.VAL(SET, ASH(3, 5));

	(* error flags *)
	EFNone* = SYSTEM.VAL(SET, ASH(0,1));
	EFC2* = SYSTEM.VAL(SET, ASH(1, 1));
	EFC2Block *= SYSTEM.VAL(SET, ASH(2, 1));

	EDC* = {3};
	Sync*= {7};
	UserData* = {4};

	(* Sub-Channel *)
	SCNoData* = 0;
	SCRaw* = 1;

TYPE
	(* Read Toc *)

	TocDescriptor* = RECORD
		Reserved1: CHAR;
		Byte1*: CHAR;
		TNO*: CHAR;
		Reserved2: CHAR;
		TrackStartAdr*: ARRAY 4 OF CHAR;
	END;

	TocHeader* = RECORD
		DataLength*: ARRAY 2 OF CHAR;
		FirstTrackNo*: CHAR;
		LastTrackNo*: CHAR;
	END;

	SessionInfo* = RECORD
		DataLength*: ARRAY 2 OF CHAR; (* 0Ah *)
		FirstComplSess*: CHAR;
		LastComplSess*: CHAR;
		Reserved1: CHAR;
		Byte1*: CHAR;
		FirstTNOLastSess*: CHAR;
		Reserved2: CHAR;
		StartAdrFirstTrack*: ARRAY 4 OF CHAR;
	END;

	FullTocDescriptor* = RECORD
		SessionNo*: CHAR;
		AdrCtrl*: CHAR;
		TNO*: CHAR;
		Point*: CHAR;
		Min*: CHAR;
		Sec*: CHAR;
		Frame*: CHAR;
		Zero*: CHAR;
		PMin*: CHAR;
		PSec*: CHAR;
		PFrame*: CHAR;
	END;

	FullTocHeader* = RECORD
		DataLength: ARRAY 2 OF CHAR;
		FirstComplSessNo*, LastComplSessNo*: CHAR;
	END;

	PmaDescriptor* = RECORD
		Reserved: CHAR;
		AdrCtrl*: CHAR;
		TNO*: CHAR;
		Point*: CHAR;
		Min*: CHAR;
		Sec*: CHAR;
		Frame*: CHAR;
		Zero*: CHAR;
		PMin*: CHAR;
		PSec*: CHAR;
		PFrame*: CHAR;
	END;

	PmaHeader* = RECORD
		DataLength*: ARRAY 2 OF CHAR;
		Reserved1: ARRAY 2 OF CHAR;
	END;

	ATIPHeader* = PmaHeader;

	ATIPDescriptor* = RECORD
		Byte0*, Byte1*, Byte2*: CHAR;
		Reserved1: CHAR;
		LeadInMin*, LeadInSec*, LeadInFrame*: CHAR;
		Reserved2: CHAR;
		LastLeadOutMin*, LastLeadOutSec*, LastLeadOutFrame*: CHAR;
		Reserved3: CHAR;
		A1Values*: ARRAY 3 OF CHAR;
		Reserved4: CHAR;
		A2Values*: ARRAY 3 OF CHAR;
		Reserved5: CHAR;
		A3Values*: ARRAY 3 OF CHAR;
		Reserved6: CHAR;
	END;
	ATIPDescriptorPtr* = POINTER TO ATIPDescriptor;

	(* Read Track Information *)

	TrackInfo* = RECORD
		InfoLength*: ARRAY 2 OF CHAR;
		TrackNo*: CHAR;
		SessionNo*: CHAR;
		Reserved1*: CHAR;
		Byte5*, Byte6*, Byte7*: CHAR;
		StartAdr*: ARRAY 4 OF CHAR;
		NextWriteAdr*: ARRAY 4 OF CHAR;
		FreeBlocks*: ARRAY 4 OF CHAR;
		PacketSize*: ARRAY 4 OF CHAR;
		Size*: ARRAY 4 OF CHAR;
	END;

	(* Read Disc Information *)

	DiscInfo* = RECORD
		DataLength*: ARRAY 2 OF CHAR;
		Byte2*: CHAR;
		NoFirstTrack*: CHAR;
		NofSessions*: CHAR;
		FirstTNOLastSess*: CHAR;
		LastTNOLastSess*: CHAR;
		Byte7*: CHAR;
		DiscType*: CHAR;
		Reserved1*: ARRAY 3 OF CHAR; (* session/tracks <= 99 *)
		DiscIdent*: ARRAY 4 OF CHAR;
		LeadInLastSess*: ARRAY 4 OF CHAR;
		LastLeadOut*: ARRAY 4 OF CHAR;
		BarCode*: ARRAY 8 OF CHAR;
	END;

	(* mode pages *)

	ModeHeader* = RECORD
		DataLength*: ARRAY 2 OF CHAR;
		Obsolete*: CHAR;
		Reserved*: ARRAY 3 OF CHAR;
		DescrLength*: ARRAY 2 OF CHAR;
	END;

	CapabilityPage* = RECORD
		Header*: ModeHeader;
		Byte0*: CHAR;
		Length*: CHAR;
		Byte2*, Byte3*, Byte4*, Byte5*, Byte6*, Byte7*: CHAR;
		MaxReadSpeed*: ARRAY 2 OF CHAR; (* obsolete *)
		NoVolumeLevels*: ARRAY 2 OF CHAR;
		BufferSize*: ARRAY 2 OF CHAR;
		CurReadSpeed*: ARRAY 2 OF CHAR; (* obsolete *)
		Obsolete*: CHAR;
		Byte17*: CHAR;
		MaxWriteSpeed*: ARRAY 2 OF CHAR; (* obsolete*)
		CurWriteSpeed1*: ARRAY 2 OF CHAR; (* obsolete *)
		CopyManagement*: ARRAY 2 OF CHAR;
		Reserved1*: ARRAY 3 OF CHAR;
		Byte27*: CHAR;
		CurWriteSpeed2*: ARRAY 2 OF CHAR;
		NofWriteDescriptors*: ARRAY 2 OF CHAR;
	END;
	CapabilityPagePtr* = POINTER TO CapabilityPage;

	SpeedDescriptor* = RECORD
		Reserved: CHAR;
		Byte1*: CHAR;
		WriteSpeed*: ARRAY 2 OF CHAR; (* kbytes/s*)
	END;
	SpeedDescriptorPtr* = POINTER TO SpeedDescriptor;

	(* Write Parameters Mode Page *)

	WriteParameterPage* = RECORD
		Header*: ModeHeader;
		Byte0*: CHAR;
		Length*: CHAR;
		Byte2*, Byte3*, Byte4*: CHAR;
		LinkSize*: CHAR;
		Reserved1*: CHAR;
		Byte7*: CHAR;
		SessionFormat*: CHAR;
		Reserved2*: CHAR;
		PacketSize*: ARRAY 4 OF CHAR;
		PauseLength*: ARRAY 2 OF CHAR;
		CatalogNo*: ARRAY 16 OF CHAR;
		ISRC*: ARRAY 16 OF CHAR;
		SubHeader*: ARRAY 4 OF CHAR;
	END;

	(* Get Configuration *)

	FeatureHeader = RECORD
		DataLength: ARRAY 4 OF CHAR;
		Reserved1: CHAR;
		Reserved2: CHAR;
		CurProfile: ARRAY 2 OF CHAR;
	END;

	MasteringFeature* =  RECORD
		Header: FeatureHeader;
		FeatureCode*: ARRAY 2 OF CHAR;
		Byte2*: CHAR;
		AdditionalLength*: CHAR;
		Byte4*: CHAR;
		MaxCueSheetLen*: ARRAY 3 OF CHAR;
	END;

	(* Read Buffer Capacity *)

	BufferCapacity* = RECORD
		DataLength*: ARRAY 2 OF CHAR;
		Reserved1*: CHAR;
		Reserved2*: CHAR;
		BufferLength*: ARRAY 4 OF CHAR;
		BlankLength*: ARRAY 4 OF CHAR;
	END;

	(* Get Performance *)

	WriteSpeedHeader* = RECORD
		DataLength*: ARRAY 4 OF CHAR;
		Reserved*: ARRAY 4 OF CHAR;
	END;

	WriteSpeedDescr* = RECORD
		Byte0*: CHAR;
		Reserved: ARRAY 3 OF CHAR;
		EndLba*: ARRAY 4 OF CHAR;
		ReadSpeed*: ARRAY 4 OF CHAR;
		WriteSpeed*: ARRAY 4 OF CHAR;
	END;
	WriteSpeedDescrPtr* = POINTER TO WriteSpeedDescr;

PROCEDURE GetNextAddress*(dev: Ata.DeviceATAPI; VAR adr: LONGINT): LONGINT;
VAR
	info: TrackInfo;
	res: LONGINT;
BEGIN
	res := ReadTrackInformation(dev, FALSE, TRAdrType1, TRInvisible, ADDRESSOF(info), SIZEOF(TrackInfo));
	IF res = ResOk THEN
		adr := Utils.ConvertBE32Int(info.NextWriteAdr);
	END;
	RETURN res;
END GetNextAddress;

PROCEDURE ReadSessionInfo*(dev: Ata.DeviceATAPI; VAR info: SessionInfo): LONGINT;
BEGIN
	RETURN ReadToc(dev, FALSE, TCFormatSessionInfo, 0, ADDRESSOF(info), SIZEOF(SessionInfo));
END ReadSessionInfo;

PROCEDURE GetTrackDescriptor*(dev: Ata.DeviceATAPI; tno: LONGINT; VAR toc: TocDescriptor): LONGINT;
VAR
	buf: POINTER TO ARRAY OF CHAR;
	res: LONGINT;
BEGIN
	NEW(buf, SIZEOF(TocHeader) + SIZEOF(TocDescriptor));
	res := ReadToc(dev, FALSE, TCFormatToc, tno, ADDRESSOF(buf^), LEN(buf));
	IF res = ResOk THEN
		SYSTEM.MOVE(ADDRESSOF(buf^) + SIZEOF(TocHeader), ADDRESSOF(toc), SIZEOF(TocDescriptor));
	END;
	RETURN res;
END GetTrackDescriptor;

PROCEDURE SetField*(VAR byte: CHAR; mask: SET; ofs, value: LONGINT);
BEGIN
	byte := SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, byte) * (-mask)) + SYSTEM.VAL(SET, LSH(value, ofs)));
END SetField;

PROCEDURE GetField*(byte: CHAR; mask: SET; ofs: LONGINT) : LONGINT;
BEGIN
	RETURN LSH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, byte) * mask), -ofs);
END GetField;

PROCEDURE SetBit*(VAR byte: CHAR; bit: SHORTINT);
BEGIN
	ASSERT(bit < 8);
	byte := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, byte) + {bit});
END SetBit;

PROCEDURE CheckBit*(byte: CHAR; bit: SHORTINT): BOOLEAN;
BEGIN
	RETURN bit IN SYSTEM.VAL(SET, byte);
END CheckBit;

PROCEDURE ClearBit*(VAR byte: CHAR; bit: SHORTINT);
BEGIN
	ASSERT(bit < 8);
	byte := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, byte) *(-{bit}));
END ClearBit;


PROCEDURE CLVToSpeed*(clv: LONGINT): LONGINT;
VAR
	speed: LONGINT;
BEGIN
	CASE clv OF
		1: speed := 2;
		| 2: speed := 4;
		| 3: speed := 6;
		| 4: speed := 8;
		ELSE speed := 0;
	END;
	RETURN speed;
END CLVToSpeed;

PROCEDURE CLVToHighSpeed*(clv: LONGINT): LONGINT;
VAR
	speed: LONGINT;
BEGIN
	CASE clv OF
		1: speed := 2;
		| 2: speed := 4;
		| 3: speed := 6;
		| 4: speed := 10;
		ELSE speed := 0;
	END;
	RETURN speed;
END CLVToHighSpeed;


PROCEDURE CLVToUltraHighSpeed*(clv: LONGINT): LONGINT;
VAR
	speed: LONGINT;
BEGIN
	CASE clv OF
		1: speed := 2;
		| 2: speed := 4;
		| 3: speed := 8;
		| 6: speed := 16;
		| 8: speed := 24;
		| 9: speed := 32;
		| 10: speed := 40;
		| 11: speed := 48;
		ELSE speed := 0;
	END;
	RETURN speed;
END CLVToUltraHighSpeed;

PROCEDURE SetAllocationLength(VAR command: Ata.CommandPacket; length: LONGINT);
BEGIN
	command.packet[7] := CHR(ASH(length, -8) MOD 100H);
	command.packet[8] := CHR(length MOD 100H)
END SetAllocationLength;


(* additional ATAPI commands *)

PROCEDURE ModeSense*(dev: Ata.DeviceATAPI; pageControl, pageCode: LONGINT; adr: ADDRESS; len: LONGINT) : LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(5AH);
	command.packet[1] := 8X;

	SetField(command.packet[2], {6, 7}, 6, pageControl);
	SetField(command.packet[2], {0..5}, 0, pageCode);

	SetAllocationLength(command, len);

	command.protocol := Ata.Protocol_PacketPIO;
	command.read := TRUE;
	command.bufAdr := adr;
	command.size := len;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" mode sense"); KernelLog.Ln;
	END;
	RETURN res;
END ModeSense;

PROCEDURE Blank*(dev: Ata.DeviceATAPI; immediate: BOOLEAN; type, tno: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(0A1H);
	command.packet[1] := CHR(type);
	IF immediate THEN
		SetBit(command.packet[1], 4);
	END;
	command.packet[2] := CHR(ASH(tno, -24) MOD 100H);
	command.packet[3] := CHR(ASH(tno, -16)  MOD 100H);
	command.packet[4] := CHR(ASH(tno, -8) MOD 100H);
	command.packet[5] := CHR(tno MOD 100H);
	command.protocol:= Ata.Protocol_PacketPIO;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" blank"); KernelLog.Ln;
	END;
	RETURN res;
END Blank;

PROCEDURE SendOPCInformation*(dev: Ata.DeviceATAPI; doOPC: BOOLEAN): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(54H);
	IF doOPC THEN
		SetBit(command.packet[1], 0);
	END;
	SetAllocationLength(command, 0);
	command.protocol := Ata.Protocol_PacketPIO;
	command.read := FALSE;
	command.bufAdr := 0;
	command.size := 0;

	res := dev.controller.ExecuteCommand(command, 10*Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" send opc information"); KernelLog.Ln;
	END;
	RETURN res;
END SendOPCInformation;

PROCEDURE GetConfiguration*(dev: Ata.DeviceATAPI; rt, start: LONGINT; adr: ADDRESS; len: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(46H);

	SetField(command.packet[1], {0,1}, 0, rt);

	command.packet[2] := CHR(ASH(start, -8) MOD 100H);
	command.packet[3] := CHR(start MOD 100H);

	SetAllocationLength(command, len);
	command.protocol := Ata.Protocol_PacketPIO;
	command.read := TRUE;
	command.bufAdr := adr;
	command.size := len;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" get configuration"); KernelLog.Ln;
	END;
	RETURN res;
END GetConfiguration;

PROCEDURE SynchronizeCache*(dev: Ata.DeviceATAPI; immediate: BOOLEAN): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(35H);
	IF immediate THEN
		SetBit(command.packet[1], 1);
	END;
	command.protocol:= Ata.Protocol_PacketPIO;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" synchronize cache "); KernelLog.Ln;
	END;
	RETURN res;
END SynchronizeCache;

PROCEDURE ModeSelect*(dev: Ata.DeviceATAPI;  save: BOOLEAN; adr: ADDRESS; len: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(55H);
	SetBit(command.packet[1], 4);
	IF save THEN
		SetBit(command.packet[1], 0);
	END;
	SetAllocationLength(command, len);

	command.protocol := Ata.Protocol_PacketPIO;
	command.read := FALSE;
	command.bufAdr := adr;
	command.size := len;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" mode select"); KernelLog.Ln;
	END;
	RETURN res;
END ModeSelect;

PROCEDURE ReadDiscInformation*(dev: Ata.DeviceATAPI; dataType: LONGINT; adr: ADDRESS; len: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(51H);
	SetField(command.packet[1], {0..2}, 0, dataType);

	SetAllocationLength(command, len);

	command.protocol := Ata.Protocol_PacketPIO;
	command.read := TRUE;
	command.bufAdr := adr;
	command.size := len;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" read disc information "); KernelLog.Ln;
	END;
	RETURN res;
END ReadDiscInformation;

PROCEDURE ReadToc*(dev: Ata.DeviceATAPI; msf: BOOLEAN; format, tno:  LONGINT; adr: ADDRESS; len: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(43H);
	IF msf THEN
		SetBit(command.packet[1], 1);
	END;
	SetField(command.packet[2], {0..3}, 0, format);
	command.packet[6] := CHR(tno);

	SetAllocationLength(command, len);

	command.protocol := Ata.Protocol_PacketPIO;
	command.read := TRUE;
	command.bufAdr := adr;
	command.size := len;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" read toc "); KernelLog.Ln;
	END;
	RETURN res;
END ReadToc;

PROCEDURE Verify*(dev: Ata.DeviceATAPI; lba, length: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(2FH);
	command.packet[2] := CHR(ASH(lba, -24) MOD 100H);
	command.packet[3] := CHR(ASH(lba, -16) MOD 100H);
	command.packet[4] := CHR(ASH(lba, -8) MOD 100H);
	command.packet[5] := CHR(lba MOD 100H);

	command.packet[7] := CHR(ASH(length, -8) MOD 100H);
	command.packet[8] := CHR(length MOD 100H);

	command.protocol := Ata.Protocol_PacketPIO;

	res := dev.controller.ExecuteCommand(command, Ata.IOTimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" verify"); KernelLog.Ln;
	END;
	RETURN res;
END Verify;

PROCEDURE ReadCD*(dev: Ata.DeviceATAPI; lba, length, adr, size, type, subChannel: LONGINT; flags: SET; dma: BOOLEAN): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(0BEH);

	SetField(command.packet[1], {2..4}, 2, type);

	command.packet[2] := CHR(ASH(lba, -24) MOD 100H);
	command.packet[3] := CHR(ASH(lba, -16) MOD 100H);
	command.packet[4] := CHR(ASH(lba, -8) MOD 100H);
	command.packet[5] := CHR(lba MOD 100H);

	command.packet[7] := CHR(ASH(length, -16) MOD 100H);
	command.packet[7] := CHR(ASH(length, -8) MOD 100H);
	command.packet[8] := CHR(length MOD 100H);

	command.packet[9] := SYSTEM.VAL(CHAR, flags);

	SetField(command.packet[10], {0..2}, 0, subChannel);

	command.protocol := Ata.Protocol_PacketPIO;
	command.read := TRUE;
	command.bufAdr := adr;
	command.size := size;
	command.count := length;

	IF dma THEN
		command.protocol := Ata.Protocol_PacketDMA;
		INCL(command.features, Ata.ATAPI_DMA);
	ELSE
		command.protocol := Ata.Protocol_PacketPIO;
	END;

	res := dev.controller.ExecuteCommand(command, Ata.IOTimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" read cd"); KernelLog.Ln;
	END;
	RETURN res;
END ReadCD;

PROCEDURE GetPerformance*(dev: Ata.DeviceATAPI; type, dataType, lba, maxDescr: LONGINT; adr: ADDRESS; len: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(0ACH);

	SetField(command.packet[1], {0..4}, 0, dataType);

	command.packet[2] := CHR(ASH(lba, -24) MOD 100H);
	command.packet[3] := CHR(ASH(lba, -16)  MOD 100H);
	command.packet[4] := CHR(ASH(lba, -8) MOD 100H);
	command.packet[5] := CHR(lba MOD 100H);

	command.packet[8] := CHR(ASH(maxDescr, -8) MOD 100H);
	command.packet[9] := CHR(maxDescr MOD 100H);

	command.packet[10] := CHR(type);

	command.protocol := Ata.Protocol_PacketPIO;
	command.read := TRUE;
	command.bufAdr := adr;
	command.size := len;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" get performance "); KernelLog.Ln;
	END;
	RETURN res;
END GetPerformance;

PROCEDURE ReadTrackInformation*(dev: Ata.DeviceATAPI; appendable: BOOLEAN; adrType, adrnr: LONGINT; adr: ADDRESS; len: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(52H);
	SetField(command.packet[1], {0,1}, 0, adrType);
	IF appendable THEN
		SetBit(command.packet[1], 2);
	END;
	command.packet[2] := CHR(ASH(adrnr, -24) MOD 100H);
	command.packet[3] := CHR(ASH(adrnr, -16)  MOD 100H);
	command.packet[4] := CHR(ASH(adrnr, -8) MOD 100H);
	command.packet[5] := CHR(adrnr MOD 100H);

	SetAllocationLength(command, len);

	command.protocol := Ata.Protocol_PacketPIO;
	command.read := TRUE;
	command.bufAdr := adr;
	command.size := len;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" read track information "); KernelLog.Ln;
	END;
	RETURN res;
END ReadTrackInformation;

PROCEDURE CloseTrackSess*(dev: Ata.DeviceATAPI; immediate: BOOLEAN; func, trackNr: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(5BH);
	IF immediate THEN
		SetBit(command.packet[1], 0);
	END;
	SetField(command.packet[2], {0..2}, 0, func);

	command.packet[4] := CHR(ASH(trackNr, -8) MOD 100H);
	command.packet[5] := CHR(trackNr MOD 100H);

	command.protocol := Ata.Protocol_PacketPIO;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" close track / Session"); KernelLog.Ln;
	END;
	RETURN res;
END CloseTrackSess;

PROCEDURE ReadBufferCapacity*(dev: Ata.DeviceATAPI; block: BOOLEAN; adr: ADDRESS; len: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(5CH);
	IF block THEN
		SetBit(command.packet[1], 0);
	END;

	SetAllocationLength(command, 12);

	command.protocol := Ata.Protocol_PacketPIO;
	command.read := TRUE;
	command.bufAdr := adr;
	command.size := len;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" read buffer capacity "); KernelLog.Ln;
	END;
	RETURN res;
END ReadBufferCapacity;

PROCEDURE SetCDSpeed*(dev: Ata.DeviceATAPI; readSpeed, writeSpeed, rotControl: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(0BBH);

	SetField(command.packet[1], {0,1}, 0, rotControl);

	command.packet[2] := CHR(ASH(readSpeed, -8) MOD 100H);
	command.packet[3] := CHR(readSpeed MOD 100H);

	command.packet[4] := CHR(ASH(writeSpeed, -8) MOD 100H);
	command.packet[5] := CHR(writeSpeed MOD 100H);

	command.protocol := Ata.Protocol_PacketPIO;

	res := dev.controller.ExecuteCommand(command, Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" set cd speed "); KernelLog.Ln;
	END;
	RETURN res;
END SetCDSpeed;

PROCEDURE SendCueSheet*(dev: Ata.DeviceATAPI; adr: ADDRESS; len: LONGINT): LONGINT;
VAR
	command: Ata.CommandPacket;
	res: LONGINT;
	status: SET;
BEGIN
	command := dev.NewCommandPacket(5DH);

	command.packet[6] := CHR(ASH(len, -16) MOD 100H);
	command.packet[7] := CHR(ASH(len, -8) MOD 100H);
	command.packet[8] := CHR(len MOD 100H);

	command.protocol := Ata.Protocol_PacketPIO;
	command.read := FALSE;
	command.bufAdr := adr;
	command.size :=len;
	res := dev.controller.ExecuteCommand(command, 4*Ata.ATAPITimeout, status);
	IF Trace THEN
		KernelLog.String(dev.name); KernelLog.String(" send cue sheet"); KernelLog.Ln;
	END;
	RETURN res;
END SendCueSheet;

END CDRecordLib.

CDRecordLib.test~

