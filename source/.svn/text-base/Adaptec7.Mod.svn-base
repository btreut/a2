MODULE Adaptec7; (** AUTHOR "prk"; PURPOSE "Adaptec 7xxx SCSI driver"; *)

IMPORT
	SYSTEM, KernelLog, PCI, Machine, Kernel, Objects, Modules,
	SCSI, Script := Adaptec7Script;

CONST
		(*debug flags*)
	traceCalls = 0;
	traceInts = 1;
	traceMsg = 2;
	traceSequencer = 4;
	traceReset = 5;
	traceConfig = 6;
	tracePeriod = 7;
	traceCmds = 8;
	traceSeeprom = 9;
	traceTermination = 10;

	traceSmall = 16;
	traceAIC7880 = 17;
	traceAIC7890 = 18;
	traceAHA2940 = 19;
	traceNoHandling = 20;
	(*traceDog = 21;*)
	traceNoRegister = 22;
	traceSync = 23;

	(* Buffer sizes*)
	QBufferSize = 3 * 256;
	SCBBufferSize = 128*32;
	BufferAlignment = 32;

	(* Message.Dir *)
	Sending = 0; Receiving = 1;

	(* Bus.sync Command Synchronization *)
	Free = 0;  InUse = 1;  Terminated = 2;

		(*Bus.chip: enumeration   *)
	AIC7770 = 1; AIC7850 = 2; AIC7860 = 3; AIC7870 = 4; AIC7880 = 5; AIC7890 = 6;
	AIC7895 = 7; AIC7896 = 8;

		(*Bus.feature   *)
	FeatUltra = 1; FeatUltra2 = 2; FeatWide = 3; FeatTwin = 4; FeatMoreSRAM = 5; FeatCmdChan = 6;
	FeatQueueRegs = 7; FeatSGPreload = 8; FeatSpioCap = 9;

		(*Bus.flag  *)
	FlagPageSCB = 1; FlagNewEepromFMT = 2; FlagBiosEnabled = 3; FlagMultiChannel = 4; FlagChnlB = 5; FlagChnlC = 6;
	FlagSeepromFound = 7; FlagChannelBPrimary = 8; FlagExtendTransA = 9; FlagExternalSRam = 10; FlagAbortPending = 11;
	FlagHandlingReqInits = 12;

		(*HSCB Control *)
	HwScbTypeMask = 03X; HwScbMsgMask = 0F6X;
	HwScbDisconnected = 3; HwScbDiscEnable = 6; HwScbMessage = 7;

(*SCSI Register Block *)
	(* 00H	SCSI Sequencer Control *)	SCSISEQ = 00H;
		(* Bit 0	SCSI Reset Out *)		SCSIRSTO = 0;
		(* Bit 1	Enable Auto ATN on parity *)		ENAUTOATNP = 1;
		(* Bit 4	Enable Reselection *)		ENRSELI = 4;
		(* Bit 5	Enable Selection in *)		ENSELI = 5;
		(* Bit 6	Enable Selection out *)		ENSELO = 6;
	(* 01H	SCSI Transfer Control 0 Register *)	SXFRCTL0 = 01H;
		(* Bit 3	SCSI PIO Enable *)		SPIOEN = 3;
		(* Bit 5	*)		FAST20 = 5;
		(* Bit 7	Digital Filtering On *)		DFON = 7;
	(* 02H	SCSI Transfer Control 1 Register *)	SXFRCTL1 = 02H;
		(* Bit 0	SCSI Termination Power Enable *)		STPWEN = 0;
		(* Bit 1	Active Negation Enable *)		ACTNEGEN = 1;
		(* Bit 2	Enable Selection timeout *)		ENSTIMER = 2;
		(* Bit 5	Enable Parity Check *)		ENSPCHK = 5;
	(* 03H	SCSI Control Signal *)	SCSISIG = 03H;
		(* Bit 0	Ack *)		ACK = 0;
		(* Bit 1	*)		REQ = 1;
		(* Bit 2	*)		BSY = 2;
		(* Bit 3	*)		SEL = 3;
		(* Bit 4	*)		ATN = 4;
		(* Bit 5	*)		MSG = 5;
		(* Bit 6	*)		IO = 6;
		(* Bit 7	*)		CD = 7;
	(* 04H	SCSI Rate Control *)	SCSIRATE = 04H;
		(* Bit 7	Wide Transer control *)		WIDEXFER = 7;
	(* 05H	SCSI ID *)	SCSIID = 05H;
					SCSIOFFSET = 05H;
	(* 06H	SCSI Data Low *)	SCSIDATL = 06H;
	(* 0BH	SCSI Status 0 *)	SSTAT0 = 0BH;
	(* 0BH	Clear SCSI Interrupt 0 *)	CLRSINT0 = 0BH;
		(* Bit 1	CLRSPIORDY *)		CLRSPIORDY = 1;
		(* Bit 3	CLRSWRAP *)		CLRSWRAP = 3;
		(* Bit 4	CLRSELINGO *)		CLRSELINGO = 4;
		(* Bit 5	CLRSELDI *)		CLRSELDI = 5;
		(* Bit 6	CLRSELDO *)		CLRSELDO = 6;
	(* 0CH	SCSI Status 1 *)	SSTAT1 = 0CH;
		(* Bit 0	*)		REQINIT = 0;
		(* Bit 2	SCSI Parity Error *)		SCSIPERR = 2;
		(* Bit 3	Bus Free Flag *)		BUSFREE = 3;
		(* Bit 5	Scsi Reset *)		SCSIRSTI = 5;
		(* Bit 7	Selection Time Out *)		SELTO = 7;
	(* 0CH	Clear SCSI Interrupt 1 *)	CLRSINT1 = 0CH;
		(* Bit 0	CLRREQINIT *)		CLRREQINIT = 0;
		(* Bit 1	CLRPHASECHG *)		CLRPHASECHG = 1;
		(* Bit 2	CLRSCSIPERR *)		CLRSCSIPERR = 2;
		(* Bit 3	CLRBUSFREE *)		CLRBUSFREE = 3;
		(* Bit 5	CLRSCSIRSTI *)		CLRSCSIRSTI = 5;
		(* Bit 6	CLRATNO *)		CLRATNO = 6;
		(* Bit 7	CLRSELTIMEO *)		CLRSELTIMEO = 7;
						CLRSINT1ALL = {0..3, 5..7};
	(* 0DH	SCSI Status 2 *)	SSTAT2 = 0DH;
		(* Bit 4	SCSI Expander Active *)		EXPACTIVE = 4;
	(* 0EH	SCSI Status 3 *)	SSTAT3 = 0EH;
	(* 0FH	SCSI ID for Ultra2 Chips *)	SCSIIDULTRA2 = 0FH;
	(* 10H	SCSI Interrupt Mode 0 *)	SIMODE0 = 10H;

	(* 11H	SCSI Interrupt Mode 1 *)	SIMODE1 = 11H;
		(* Bit 1	Enable ReqInit *)		ENREQINIT = 0;
		(* Bit 2	Enable Scsi Parity Error *)		ENSCSIPERR = 2;
		(* Bit 3	Enable Bus Free *)		ENBUSFREE = 3;
		(* Bit 5	Enable Scsi Reset *)		ENSCSIRST = 5;
		(* Bit 7	Enable Time-out *)		ENSELTIMO = 7;
	(* 12H	SCSI Bus Low *)	SCSIBUSL = 12H;
	(* 1BH	Serial Port I/O Cabability register *)	SPIOCAP = 1BH;
		(* Bit 0	 Termination and cable detection *)		SSPIOCPS = 0;
	(* 1DH	Board Control *)	BRDCTL = 1DH;
		(* Bit 0	7890 only: Board Strobe *)		BRDSTBULTRA2 = 0;
		(* Bit 1	7890 only: Board Read/Write *)		BRDRWULTRA2 = 1;
		(* Bit 2	Board Read/Write *)		BRDRW = 2;
		(* Bit 3	Board Chip Select *)		BRDCS = 3;
		(* Bit 4	Board Strobe *)		BRDSTB = 4;
	(* 1EH	Serial EEPROM Control *)	SEECTL = 1EH;
		(* Bit 0	Serial EEPROM Data In *)		SEEDI = 0;
		(* Bit 1	Serial EEPROM Data Out *)		SEEDO = 1;
		(* Bit 2	Serial EEPROM Clock *)		SEECK = 2;
		(* Bit 3	Serial EEPROM Chip Select *)		SEECS = 3;
		(* Bit 4	Serial EEPROM Ready *)		SEERDY = 4;
		(* Bit 5	Serial EEPROM Mode Select *)		SEEMS = 5;
	(* 1FH	SCSI Block Control *)	SBLKCTL = 1FH;
		(* Bit 1	Select Wide *)		SELWIDE = 1;
		(* Bit 3	SELBUSB *)		SELBUSB = 3;
		(* Bit 3	LVD transceiver active *)		ENAB40 = 3;
		(* Bit 5	Auto Flush Disable *)		AUTOFLUSHDIS = 5;
		(* Bit 6	Diagnostic LED on *)		DIAGLEDON = 6;
		(* Bit 7	Diagnostic LED Enable *)		DIAGLEDEN =7;

(* Scratch RAM *)
	(* 20H	1 byte per target starting at this address for configuration values*)	TARGSCSIRATE = 20H;
	(* 30H	Bit vector of targets that have ULTRA enabled. *)	ULTRAENB = 30H;
 	(* 32H 	Bit vector of targets that have disconnection disabled*)	DISCDSB = 32H;
 	(* 34H	buffer to designate the type or message to send to a target*)	MSGOUT = 34H;
 	(* 35H	Parameters for DMA Logic*)	DMAPARAMS = 35H;
 	(* 36H	*)		SEQFLAGS = 36H;
 	(* 37H	SAVED_TCL*)	SAVEDTCL = 37H;
 	(* 38H	SG_COUNT*)
 	(* 39H	SG_NEXT*)
 	(* 3DH	LASTPHASE*)	LASTPHASE = 3DH;
 		(* Signals are declared in SCSISIG *)		PHASEMASK = {CD, MSG, IO};
 		(* Patterns*)
 		PhaseStatus = {CD, IO};
 		PhaseCommand = {CD};
 		PhaseMsgOut = {CD, MSG};
 		PhaseMsgIn = {CD, MSG, IO};
 		PhaseDataIn = {IO};
 		PhaseDataOut = {};
 		PhaseBusFree = {0};
 	(* 3EH	WAITINGSCBH*)	WAITINGSCBH = 3EH;
 	(* 3FH	DISCONNECTEDSCBH*)	DISCONNECTEDSCBH = 3FH;
 	(* 40H	head of list of SCBs that are not in use.  Used for SCB paging*)	FREESCBH = 40H;
 	(* 41H	HSCB_ADDR*)	HSCBARRAY = 41H;
 	(* 45H	SCBID_ADDR*)	SCBIDADDR = 45H;
 	(* 49H	TMODE_CMDADDR*)	TMODECMDADDR = 49H;
 	(* 4DH	KERNEL_QINPOS*)	KERNELQINPOS = 4DH;
 	(* 4EH	QINPOS*)	QINPOS = 4EH;
 	(* 4FH	QOUTPOS*)	QOUTPOS = 4FH;
 	(* 50H	TMODE_CMDADDR_NEXT*)	TMODECMDADDRNEXT = 50H;
 	(* 51H	ARG_1 / RETURN_1*)	RETURN1 = 51H;
 		(*	Phase Mismatch *)		MSGOUTPHASEMIS = {4};
 		(* 	Send Sense *)		SENDSENSE = {6};
 		(* 	Send Msg *)		SENDMSG = {7};
 	(* 52H	ARG_2 *)
 	(* 53H	LAST_MSG*)	LASTMSG = 53H;
 	(* 54H	PREFETCH_CNT*)

	(* 5AH	Scsi Configuration *)	SCSICONF = 5AH;
		(* Bit 6	Reset SCSI-Bus at boot *)		RESETSCSI = 6;
		(* Bit 7	Termination Enable *)		TERMENB = 7;
	(* 60H	Sequencer Control *)	SEQCTL = 60H;
		(* Bit 0	Load Ram *)		LOADRAM = 0;
		(* Bit 1	Reset *)		SEQRESET = 1;
		(* Bit 4	Fast Mode *)		FASTMODE = 4;
		(* Bit 5	Fail disable *)		FAILDIS = 5;
		(* Bit 7	Parity Error disable *)		PERRORDIS = 7;
	(* 61H	Sequencer RAM Data *)	SEQRAM = 61H;
	(* 62H	Sequencer Address Registers *)	SEQADDR0 = 62H;
	(* 63H	*)		SEQADDR1 = 63H;
	(* 65H	*)		SINDEX = 65H;
(* Sequencer (SCSI Phase Engine)*)
	(* 70H	1 byte per target SCSI offset values for Ultra2 controllers *)	TARGOFFSET = 70H;
(* Bus Registers*)
	(* 84H	Board Control*)	BCTL = 84H;
		(* Bit 0 	Enable *)		ENABLE = 0;
	(* 84H	Device Space Command*)	DSCOMMAND0 = 84H;
		(* Bit 0	*)		CIOPARCKEN = 0;
		(* bit 1	*)		USCBSIZE32 = 1;
		(* Bit 5	Memory Parity Check Enable *)		MPARCKEN = 5;
		(* Bit 6	Data Parity Check Enable *)		DPARCKEN = 6;
		(* Bit 7	Cache Threshold Enable *)		CACHETHEN = 7;
	(* 86H	DSPCI Status *)	DSPCISTATUS = 86H;
		(*	Read when 100% empty, write when 100% full *)		DFTHRSH100 = {6, 7};
	(* 87H	Host Control, Overall host control of the device*)	HCNTRL = 87H;
		(* Bit 0	Chip Reset / Chip Reset Acknowledge *)		CHIPRST = 0;
		(* Bit 1	Interrupt Enable *)		INTEN = 1;
		(* Bit 2	Pause Enable *)		PAUSE = 2;
	(* 90H	Gate one of the four SCBs into the SCBARRAY window*)	SCBPTR = 90H;
	(* 91H	Interrupt Status *)	INTSTAT = 91H;
		(* Bit 0	Sequencer Interrupt *)		SEQINT = 0H;
		(* Bit 1	Command Completed *)		CMDCMPLT = 1H;
		(* Bit 2	Scsi Interrupt *)		SCSIINT = 2H;
		(* Bit 3	Break address *)		BRKADRINT = 3H;
		(* Sequencer Interrupt Mask *)		SEQINTMASK = {0, 4..7};
		(* Interrupt Values*)
			DataOverrun = 0EH; MsgInPhaseMis = 0DH; TracePoint2 = 0CH;
			TracePoint = 0BH; AwaitingMsg = 0AH; Residual = 08H;
			BadStatus = 07H; RejectMsg = 06H; AbortRequested = 05H;
			ExtendedMsg = 04H; NoMatch = 03H; NoIdent = 02H;
			SendReject = 01H; BadPhase = 00H;
	(* 92H	Write: Clear Interrupt Status *)	CLRINT = 92H;
		(* Bit 0	Clear Sequencer Interrupt *)		CLRSEQINT = 0;
		(* Bit 1	Clear Command Complete Interrupt *)		CLRCMDINT = 1;
		(* Bit 2	Clear SCSI Interrupt *)		CLRSCSIINT = 2;
		(* Bit 3	Clear Break Address Interrupt *)		CLRBRKADRINT = 3;
		(* Bit 4	Clear Parity Errors*)		CLRPARERR = 4;
	(* 92H	Read: Hard Error *)	ERROR = 92H;
		(* Bit 0	Illegal Hardware Address *)		ILLHADDR = 0;
		(* Bit 1	Illegal Software Address *)		ILLSADDR = 1;
		(* Bit 2	Illegal Opcode Error *)		ILLOPCODE = 2;
		(* Bit 3	Sequencer Parity Error *)		SQPARERR = 3;
		(* Bit 6	Pci error *)		PCIERRSTAT = 6;
	(* 94H	Data FIFO Status *)	DFSTATUS = 94H;

(* SCB Definition: this field give direct access to the scb pointed by SCBPTR*)
	(* A0H	SCB Control *)	SCBCONTROL = 0A0H;
		(* Bit 3	Disconnected*)		DISCONNECTED = 3;
		(* Bit 6	Disconnect Enabled*)		DISCENB = 6;
	(* A1H	*)		SCBTCL = 0A1H;
	(* A2H	Target Status *)	SCBTARGETSTATUS = 0A2H;
	(* A3H	SG / Count *)	SCBSGCOUNT = 0A3H;
	(* A4H	SG / Ptr *)	SCBSGPTR = 0A4H;
	(* A8H	*)		SCBRESIDSGCNT = 0A8H;
	(* A9H	*)		SCBRESIDDCNT = 0A9H;
	(* ACH	*)		SCBDATAPTR = 0ACH;
	(* B0H	*)		SCBDATACNT = 0B0H;
	(* B4H	*)		SCBCMDPTR = 0B4H;
	(* B8H	*)		SCBCMDLEN = 0B8H;
	(* B9H	*)		SCBTAG = 0B9H;
	(* BAH	*)		SCBNEXT = 0BAH;
	(* BBH	*)		SCBPREV = 0BBH;
	(* BCH	*)		SCBBUSYTARGETS = 0BCH;

	(* F0H	CCSCBBADDR, 7895/6/7 only *)	CCSCBBADDR = 0F0H;
	(* F4H	Host New SCB Queue Offset *)	HNSCBQOFF = 0F4H;
	(* F6H	Sequencer New SCB Queue Offset *)	SNSCBQOFF = 0F6H;
	(* F8H	Sequencer Done SCB Queue Offset *)	SDSCBQOFF = 0F8H;
	(* FAH	Queue Offset Control & Status *)	QOFFCTLSTA = 0FAH;
		(*	Queue size = 256 *)		SCBQSIZE256 = {1, 2};
	(* FBH	Data FIFO Threshold *)	DFFTHRSH = 0FBH;
		(*	Write starts when 75% full *)		WRDFFTHRSH75 = {6};
		(*	Read starts when 75% empty *)		RDDFFTHRSH75 = {2};

(*PCI Registers*)
	(* 40H	Device Configuration *)	DEVCONFIG = 40H;
		(* Bit 2	RAMPSM_ULTRA2 7895/6 only? *)		RAMPSMULTRA2 = 2;
		(* Bit 3	Byte Parity Error Enable *)		BERREN = 3;
		(* Bit 3	SCBRAMSELULTRA2??? *)		SCBRAMSELULTRA2 = 3;
		(* Bit 4	External SCB Parity Enable *)		EXTSCBPEN = 4;
		(* Bit 7	SCB RAM Select,  not 7890 *)		SCBRAMSEL = 7;
		(* Bit 9	RAM Present Mode *)		RAMPSM = 9;
		(* Bit 16	SCBSIZE32, 7895 only? *)		SCBSIZE32 = 16;
		(* Bit 31	PCI Error Generation Disable *)		PCIERRGENDIS = 31;

	SCAMCTL = 1AH;			(*ultra2 only*)

	(* HW-SCB Offsets *)
	HScontrol = 0;
	HStarget = 1;
	HSstatus = 2;
	HSSGcount = 3;
	HSSGptr = 4;
	HSresSGcnt = 8;
	HSresDataCnt = 9;
	HSdataPtr = 12;
	HSdataCnt = 16;
	HScmdPtr = 20;
	HScmdLen = 24;
	HStag = 25;
	HSnext = 26;
	HSprev = 27;
	HSpar = 28;

TYPE
	Interrupt = OBJECT
		VAR
			root: Bus; int: LONGINT;

		PROCEDURE HandleInterrupt;
		VAR  int, err: SET;  d: Bus;
		BEGIN
			INC(aIntCount);
			d := root;
			WHILE d # NIL DO
				int := SYSTEM.VAL(SET, d.Get1(d, INTSTAT));
				err := SYSTEM.VAL(SET, d.Get1(d, ERROR));
				IF d.interruptable & ((int # {}) OR (err # {})) THEN
					IF traceSmall IN trace THEN KernelLog.Char("<") END;
					IF CMDCMPLT IN int THEN
						IF traceSmall IN trace THEN KernelLog.Char("C") END;
						IntCommand(d)
					END;
					IF (BRKADRINT IN int) OR (err # {}) THEN
						IF traceSmall IN trace THEN KernelLog.Char("B") END;
						IntBrkAdr(d)
					END;
					IF SEQINT IN int THEN
						IF traceSmall IN trace THEN KernelLog.Char("S") END;
						IntSeqHandle(d, LSH(SYSTEM.VAL(LONGINT, int), -4))
					END;
					IF SCSIINT IN int THEN
						IF traceSmall IN trace THEN KernelLog.Char("s") END;
						IntScsiHandle(d)
					END;
					IF traceSmall IN trace THEN KernelLog.Char(">") END;
				END;
				d := d.next
			END
		END HandleInterrupt;

		PROCEDURE Cleanup;
		BEGIN
			Objects.RemoveHandler(SELF.HandleInterrupt, int)
		END Cleanup;

		PROCEDURE & Init*(irq: LONGINT);
		BEGIN
			int := Machine.IRQ0 + irq;
			Objects.InstallHandler(SELF.HandleInterrupt, int)
		END Init;
	END Interrupt;
(*
	Watchdog = POINTER TO RECORD  (Timer)
		VAR
			stop: BOOLEAN;
			dev, ms, count: LONGINT;
			bus: Bus;

		PROCEDURE & InitW(ms, count: LONGINT;  bus: Bus;  dev: LONGINT);
		BEGIN
			KernelLog.String("Watchdog installed"); KernelLog.Ln;
			Init;
			SELF.count := count;  SELF.ms := ms;
			SELF.dev := dev;  SELF.bus := bus
		END InitW;

	BEGIN {ACTIVE}
		Wait(ms);
		WHILE ~stop & (count > 0) DO
			WriteBusState(bus);
			Wait(ms);
			DEC(count)
		END;
		IF ~stop THEN	(*timeouted*)
			bus.Synchronize(dev, bus.sync[dev], Terminated)
		END;
		KernelLog.String("Watchdog terminated"); KernelLog.Ln;
	END Watchdog;
*)
	Message = RECORD
		buf: ARRAY 6 OF CHAR;
		pos, len, dir: SHORTINT;
	END;


	Bus = OBJECT (SCSI.Bus)
		VAR
				(* card configuration *)
			flags, features:  SET;
			chip: SHORTINT;
			interruptable: BOOLEAN;
			irq: SHORTINT;	(* interrupt line *)
			scsiId: SHORTINT;

			sync: ARRAY 16 OF SHORTINT;	(* bus synchronization: only one cmd per device *)

				(* card IO information *)
			busNo, devNo, slotNo: LONGINT;	(* PCI Address *)
			buffers: ARRAY (QBufferSize + SCBBufferSize + BufferAlignment) OF CHAR;	(* Q and SCB buffers *)
			scbArea: LONGINT;	(* virtual address of the hardware scb buffer, shared with the sequencer *)
			queueArea: LONGINT;	(*virtual address of the queue buffers, shared with the sequencer *)
			in, out: LONGINT;	(*pointer to next scb*)
			base: ADDRESS;	(*virtual address for memory mapped IO / port address for port based IO *)
			Put1: PROCEDURE (d: Bus; offset: LONGINT; val: CHAR);
			Get1: PROCEDURE (d: Bus; offset: LONGINT): CHAR;

				(* cached values *)
			width: SHORTINT; 	(* 8 or 16, iff FeatWide *)
			negotiateWidth: SET;	(*handle transmission width whenever possible*)
			negotiateSync: SET;	(*handle transmission sync whenever possible*)
			msg: Message;	(*message from/to device. Only one buffer: the message phase is not prehempted*)

			result, status: ARRAY 16 OF SHORTINT;

			next: Bus;	(*list of all Ada7 busses *)

		PROCEDURE Synchronize(dev: LONGINT;  await, set: SHORTINT);
			PROCEDURE Data;
			BEGIN
				KernelLog.String("Sync ["); KernelLog.Int(dev, 0); KernelLog.String("] ");
				KernelLog.Int(await, 0); KernelLog.String(" -> "); KernelLog.Int(set, 0)
			END Data;
		BEGIN  {EXCLUSIVE}
			IF traceSync IN trace THEN BusNameMsg(SELF, " ->"); Data; KernelLog.Ln; END;
			AWAIT(sync[dev] = await);
			IF traceSync IN trace THEN BusNameMsg(SELF, " <-"); Data; KernelLog.Ln END;
			sync[dev] := set
		END Synchronize;

		PROCEDURE Submit*(VAR c: SCSI.Command);
		BEGIN
			Synchronize(c.target, Free, InUse);
			BusSchedule(SELF, c);		(* return only when command Terminated *)
			c.result := result[c.target];
			c.status := status[c.target];
			Synchronize(c.target, Terminated, Free);	(* activate/allow next command *)
		END Submit;

		PROCEDURE & Init*(id, bus, dev, slot: LONGINT);
		BEGIN
			flags := card[id].flags;
			features := card[id].features;
			chip := card[id].chip;
			interruptable := FALSE;
			COPY(card[id].name, fullname);
			busNo := bus;  devNo := dev;  slotNo := slot;
			IF firstBus = NIL THEN  firstBus := SELF  END;
		END Init;
	END Bus;

	RateTableDesc = RECORD
		period: SHORTINT;	(* 1/4 of nsec, same as sync negotiation message *)
		rate: CHAR;	(* rate for normal/fast/ultra cards *)
		u2rate: CHAR;	(* rate ultra2 cards *)
		speed: LONGINT;	(* speed in 100 KB/s for 8-bit bus *)
	END;

	(* Description of the cards we're know about *)
	CardTable = RECORD
		signature: LONGINT;
		chip: SHORTINT;
		flags, features: SET;
		name: ARRAY 32 OF CHAR;
	END;

VAR
	timer: Kernel.Timer;
	interrupt: ARRAY 32 OF Interrupt;

	card: ARRAY 19 OF CardTable;	(*description of the known cards*)
	rateTable: ARRAY 13 OF RateTableDesc;

	firstBus: Bus;
	trace: SET;
	aExecute,
	aIntScsiSeltoProblem1, aIntScsiSeltoProblem2,
	aIntScsiReset, aIntScsiSelto, aIntScsiBusFree, aIntScsiParity, aIntScsiReqInit, aIntScsiSpecial, aIntScsiUnknown,
	aIntSeqNoMatch, aIntSeqSendReject, aIntSeqNoIdent, aIntSeqBadPhase, aIntSeqExtendedMsg,
	aIntSeqRejectMsg, aIntSeqBadStatus, aIntSeqAwaitingMsg, aIntSeqDataOverrun,
	aIntCount, aIntCmdCount, aIntBrkAdrCount, aIntSeqCount, aIntScsiCount: LONGINT;


(* Debug Procedures *)

PROCEDURE ToDo(desc: ARRAY OF CHAR);
BEGIN
	KernelLog.Enter;
	KernelLog.String(desc); KernelLog.String(" not implemented yet");
	KernelLog.Exit
END ToDo;

PROCEDURE BusName(b: Bus);
BEGIN
	KernelLog.Char("["); KernelLog.Hex(b.busNo, -2);
	KernelLog.Char("/"); KernelLog.Hex(b.devNo, -2);
	KernelLog.Char("/"); KernelLog.Hex(b.slotNo, -2); KernelLog.String("] ");
END BusName;

PROCEDURE BusNameMsg(b: Bus;  str: ARRAY OF CHAR);
BEGIN
	KernelLog.Char("["); KernelLog.Hex(b.busNo, -2);
	KernelLog.Char("/"); KernelLog.Hex(b.devNo, -2);
	KernelLog.Char("/"); KernelLog.Hex(b.slotNo, -2); KernelLog.String("] ");
	KernelLog.String(str)
END BusNameMsg;

PROCEDURE Reg(d: Bus; off: LONGINT;  name: ARRAY OF CHAR);
BEGIN
	KernelLog.String(name); KernelLog.Hex(ORD(d.Get1(d, off)), -2)
END Reg;

PROCEDURE DumpCurSCB(d: Bus);
BEGIN
	Reg(d, SCBPTR, "CurSCB = ");
	Reg(d, SCBCONTROL, " Ctrl = ");
	Reg(d, SCBTCL, " Targ = ");
	Reg(d, SCBTAG, " Tag = ");
	Reg(d, SCBPREV, " Prev = ");
	Reg(d, SCBNEXT, " Next = ");
	KernelLog.Ln;
END DumpCurSCB;

PROCEDURE DumpBusList(d: Bus;  list: LONGINT;  name: ARRAY OF CHAR);
VAR  ch, save: CHAR;
BEGIN
	BusName(d); KernelLog.String(name);
	save := d.Get1(d, SCBPTR);
	ch := d.Get1(d, list);
	WHILE ch # 0FFX DO
		KernelLog.String("->"); KernelLog.Hex(ORD(ch), -2);
		d.Put1(d, SCBPTR, ch); ch :=  d.Get1(d, SCBNEXT);
	END;
	KernelLog.Ln;
	d.Put1(d, SCBPTR, save);
END DumpBusList;

PROCEDURE DumpAllLists(d: Bus);
BEGIN
	DumpBusList(d, FREESCBH, "Free");
	DumpBusList(d, WAITINGSCBH, "Wait");
	DumpBusList(d, DISCONNECTEDSCBH, "Disc");
END DumpAllLists;

(* IO Procedures to be installed into the Bus structures to comunicate with hardware *)

PROCEDURE PortPut(d: Bus; offset: LONGINT; val: CHAR);
BEGIN
	Machine.Portout8(d.base+offset, val)
END PortPut;

PROCEDURE PortGet(d: Bus; offset: LONGINT): CHAR;
VAR ch: CHAR;
BEGIN
	Machine.Portin8(d.base+offset, ch); RETURN ch
END PortGet;

PROCEDURE MemoryPut(d: Bus; offset: LONGINT; val: CHAR);
BEGIN
	SYSTEM.PUT(d.base+offset, val)
END MemoryPut;

PROCEDURE MemoryGet(d: Bus; offset: LONGINT): CHAR;
VAR ch: CHAR;
BEGIN
	SYSTEM.GET(d.base+offset, ch);  RETURN ch
END MemoryGet;

(* Common Code Patterns *)

PROCEDURE MakeTarget(targ, chan, lun: LONGINT): CHAR;
BEGIN
	RETURN  CHR(LSH(targ MOD 16, 4)+LSH(chan MOD 2, 3)+lun MOD 8)
END MakeTarget;

(* Sync / Width functions *)

(* GetTableIndex - Return the index to start the search in the rateTable *)

PROCEDURE GetTableIndex(ultra, ultra2: BOOLEAN): LONGINT;
BEGIN
	IF ultra2 THEN RETURN 0 ELSIF ultra THEN RETURN 2 ELSE RETURN 5 END
END GetTableIndex;

PROCEDURE GetMaxOffset(wide, ultra2: BOOLEAN): CHAR;
BEGIN
	IF ultra2 THEN  RETURN 7FX
	ELSIF wide THEN  RETURN  08X
	ELSE RETURN 0FX
	END
END GetMaxOffset;

PROCEDURE SetWidth(d: Bus;  wide: BOOLEAN);
VAR  index: LONGINT;  rate: SET;
BEGIN
	index := ORD(d.Get1(d, SCBTAG));
	rate := SYSTEM.VAL(SET, d.Get1(d, TARGSCSIRATE + index));
	IF wide THEN
		INCL(rate, WIDEXFER)
	ELSE
		EXCL(rate, WIDEXFER)
	END;
	d.Put1(d, TARGSCSIRATE + index, SYSTEM.VAL(CHAR, rate));
	d.Put1(d, SCSIRATE, SYSTEM.VAL(CHAR, rate));
	BusNameMsg(d, "Device["); KernelLog.Int(index, 0); KernelLog.String("].width=");
	KernelLog.Int(SYSTEM.VAL(SHORTINT, wide), 0); KernelLog.Ln
END SetWidth;

PROCEDURE SetSyncRate(d: Bus;  period, offset: LONGINT);
VAR i, index, speed: LONGINT;  ultra2, ultra, wide: BOOLEAN;  ctrl0, rate: CHAR;  set: SET;
BEGIN
	ultra2 := FeatUltra2 IN d.features;
	ultra := FeatUltra IN d.features;

	index := ORD(d.Get1(d, SCBTAG));
	i := GetTableIndex(ultra, ultra2);
	WHILE  (i < LEN(rateTable)) & (period > rateTable[i].period) DO INC(i) END;
	IF i = LEN(rateTable) THEN
		i := -1; offset := 0;	(*async*)
	END;
	rate := d.Get1(d, TARGSCSIRATE + index);
	rate := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, rate) * {WIDEXFER});
	wide := rate # 0X;
	IF ultra2 THEN
		IF i # -1 THEN  rate := CHR(ORD(rate) + ORD(rateTable[i].u2rate))  END;
		d.Put1(d, SCSIRATE, rate);
		d.Put1(d, SCSIOFFSET, CHR(offset));
		d.Put1(d, TARGSCSIRATE+index, rate);
		d.Put1(d, TARGOFFSET+index, CHR(offset))
	ELSE
		IF i # -1 THEN
			ASSERT(offset < 10H);
			rate := CHR(ORD(rate) + ORD(rateTable[i].rate) + (offset MOD 10H));
			ultra := i < 5
		ELSE
			ultra := FALSE
		END;
		d.Put1(d, SCSIRATE, rate);
		d.Put1(d, TARGSCSIRATE + index, rate);
		ctrl0 := d.Get1(d, SXFRCTL0);
		set := SYSTEM.VAL(SET, d.Get1(d, ULTRAENB + index DIV 8));
		IF ultra THEN
			ctrl0 := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, ctrl0) + {FAST20});
			INCL(set, index MOD 8)
		ELSE
			ctrl0 := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, ctrl0) - {FAST20});
			EXCL(set, index MOD 8)
		END;
		d.Put1(d, SXFRCTL0, ctrl0);
		d.Put1(d, ULTRAENB + index DIV 8, SYSTEM.VAL(CHAR, set))
	END;
	BusNameMsg(d, "Device["); KernelLog.Int(index, 0); KernelLog.String("].rate=");
	IF i = -1 THEN
		KernelLog.String("async")
	ELSE
		KernelLog.Int(rateTable[i].period, 0); KernelLog.Char("/"); KernelLog.Int(offset, 0);
		speed := rateTable[i].speed;
		IF wide THEN speed := speed*2  END;
		KernelLog.Int(speed DIV 10, 4); KernelLog.Char("."); KernelLog.Int(speed MOD 10, 0);
		KernelLog.String(" MB/s")
	END;
	KernelLog.Ln
END SetSyncRate;

(* Queues Functions *)
(*
	Queue Layout

	+000H	untagged queue
	+100H	out queue
	+200H	in queue
*)

PROCEDURE QUntaggedSet(d: Bus;  i: LONGINT;  ch: CHAR);
BEGIN
	SYSTEM.PUT(d.queueArea+i, ch)
END QUntaggedSet;

PROCEDURE QOutSet(d: Bus;  i: LONGINT;  ch: CHAR);
BEGIN
	SYSTEM.PUT(d.queueArea+100H+i, ch)
END QOutSet;

PROCEDURE QOutGet(d: Bus;  i: LONGINT): CHAR;
VAR ch: CHAR;
BEGIN
	SYSTEM.GET(d.queueArea+100H+i, ch);  RETURN ch
END QOutGet;

PROCEDURE QInSet(d: Bus;  i: LONGINT;  ch: CHAR);
BEGIN
	SYSTEM.PUT(d.queueArea+200H+i, ch)
END QInSet;

PROCEDURE QInit(d: Bus);
VAR paddr, i: LONGINT;
BEGIN
	IF traceCalls IN trace THEN  BusNameMsg(d, "QInit"); KernelLog.Ln  END;
(*
	Machine.NewPhysicalPage(paddr);
	Machine.MapPhysical(paddr, Machine.PageSize, d.queueArea);
*)
	paddr := ADDRESSOF(d.buffers[0]);
	INC(paddr, (-paddr) MOD BufferAlignment);
	d.queueArea := paddr;

	FOR i := 0 TO 255 DO
		QUntaggedSet(d, i, 0FFX);  QOutSet(d, i, 0FFX);  QInSet(d, i, 0FFX)
	END;
	d.in := 0;
	d.out := 0;
	d.Put1(d, SCBIDADDR, CHR(paddr));
	d.Put1(d, SCBIDADDR+1, CHR(LSH(paddr, -8)));
	d.Put1(d, SCBIDADDR+2, CHR(LSH(paddr, -16)));
	d.Put1(d, SCBIDADDR+3, CHR(LSH(paddr, -24)));
	d.Put1(d, QINPOS, 0X);
	d.Put1(d, KERNELQINPOS, 0X);
	d.Put1(d, QOUTPOS, 0X);
	IF FeatQueueRegs IN d.features THEN
		d.Put1(d, QOFFCTLSTA, 6X);	(* Queue size = 256 *)
		d.Put1(d, SDSCBQOFF, 0X);
		d.Put1(d, SNSCBQOFF, 0X);
		d.Put1(d, HNSCBQOFF, 0X)
	END;
	d.Put1(d, WAITINGSCBH, 0FFX);
	d.Put1(d, DISCONNECTEDSCBH, 0FFX);
END QInit;


(* HW-SCB Functions *)
(*
	HW SCB Layout:
	00	1	control
	01	1	target
	02	1	status
	03	1	SG count
	04	4	SG pointer
	08	1	residual SG count
	09	3	residual Data count
	12	4	data ptr
	16	4	data cnt
	20	4	cmd ptr
	24	1	cmd len
	25	1	tag
	26	1	next
	27	1	prev
	28	4	par
*)

PROCEDURE HSSet(d: Bus;  num, offset: LONGINT;  val: CHAR);
BEGIN	SYSTEM.PUT(d.scbArea + num*32 + offset, val)
END HSSet;

PROCEDURE HSSet4(d: Bus;  num, offset: LONGINT;  val: LONGINT);
BEGIN	SYSTEM.PUT(d.scbArea + num*32 + offset, val)
END HSSet4;

PROCEDURE HSFreeCurrent(d: Bus);
BEGIN
	d.Put1(d, SCBTAG, 0FFX);
	d.Put1(d, SCBCONTROL, 0X);
	d.Put1(d, SCBNEXT, d.Get1(d, FREESCBH));
	d.Put1(d, FREESCBH, d.Get1(d, SCBPTR))
END HSFreeCurrent;

PROCEDURE HSFreeScb(d: Bus;  index: LONGINT);
BEGIN
	HSSet(d, index, HScontrol, 0X);
	HSSet(d, index, HSstatus, 0X);
	HSSet(d, index, HStarget, 0FFX)
END HSFreeScb;

PROCEDURE HSInit(d: Bus);
VAR  paddr, i: LONGINT;  quit: BOOLEAN;
BEGIN
	IF traceCalls IN trace THEN  BusNameMsg(d, "HSInit"); KernelLog.Ln  END;
	(*allocate hw-scb buffer*)
(*
	Machine.NewPhysicalPage(paddr);
	Machine.MapPhysical(paddr, Machine.PageSize, d.scbArea);
*)
	paddr := ADDRESSOF(d.buffers[QBufferSize]);
	INC(paddr, (-paddr) MOD BufferAlignment);
	d.scbArea := paddr;

	FOR i := 0 TO 127 DO
		SYSTEM.PUT(d.scbArea + i*32 + HScontrol, 0X);	(* control := 0X *)
		SYSTEM.PUT(d.scbArea + i*32 + HStag, CHR(i));	(* tag := i *)
	END;
	d.Put1(d, HSCBARRAY, CHR(paddr));
	d.Put1(d, HSCBARRAY+1, CHR(LSH(paddr, -8)));
	d.Put1(d, HSCBARRAY+2, CHR(LSH(paddr, -16)));
	d.Put1(d, HSCBARRAY+3, CHR(LSH(paddr, -24)));

	(* clear and initialize host scb table *)
	d.Put1(d, FREESCBH, 0X);
	i := 0;  quit := FALSE;
	WHILE (i < 255) & ~quit DO
		d.Put1(d, SCBPTR, CHR(i));
		d.Put1(d, SCBCONTROL, CHR(i));
		IF i # ORD(d.Get1(d, SCBCONTROL)) THEN
			quit := TRUE
		ELSE
			d.Put1(d, SCBPTR, 0X);
			IF d.Get1(d, SCBCONTROL) # 0X THEN
				quit := TRUE
			ELSE
				d.Put1(d, SCBPTR, CHR(i));
				d.Put1(d, SCBCONTROL, 0X);
				d.Put1(d, SCBNEXT, CHR(i+1));
				d.Put1(d, SCBPREV, CHR(i-1));
				d.Put1(d, SCBTAG, 0FFX);
				d.Put1(d, SCBBUSYTARGETS, 0FFX);
				d.Put1(d, SCBBUSYTARGETS+1, 0FFX);
				d.Put1(d, SCBBUSYTARGETS+2, 0FFX);
				d.Put1(d, SCBBUSYTARGETS+3, 0FFX);
				INC(i)
			END
		END
	END;
	d.Put1(d, SCBPTR, CHR(i-1));	(*last SCB terminates the list*)
	d.Put1(d, SCBNEXT, 0FFX);

	d.Put1(d, SCBPTR, 0X);	(*clear first SCB control byte (may have been changed)*)
	d.Put1(d, SCBCONTROL, 0X);
	IF i = 255 THEN  EXCL(d.flags, FlagPageSCB)  END;
	BusNameMsg(d, "SCB = "); KernelLog.Int(i, 0); KernelLog.Ln
END HSInit;

(* Sequencer Functions *)

PROCEDURE SeqPause(d: Bus);
BEGIN
	IF traceSequencer IN trace THEN  BusNameMsg(d, "SeqPause"); KernelLog.Ln  END;
	d.Put1(d, HCNTRL, SYSTEM.VAL(CHAR, {INTEN, PAUSE}));
	WHILE ~(PAUSE IN SYSTEM.VAL(SET, d.Get1(d, HCNTRL))) DO  END;
END SeqPause;

PROCEDURE SeqUnpause(d: Bus);
BEGIN
	IF traceSequencer IN trace THEN  BusNameMsg(d, "SeqUnpause")  END;
	IF ~(FlagHandlingReqInits IN d.flags) THEN
		IF traceSequencer IN trace THEN  KernelLog.String("*")  END;
		d.Put1(d, HCNTRL, SYSTEM.VAL(CHAR, {INTEN}))
	ELSE
		ToDo("Ada7: Unpausing the sequencer while in message mode")
	END;
	IF traceSequencer IN trace THEN  KernelLog.Ln  END;
END SeqUnpause;

PROCEDURE SeqLoad(d: Bus);
VAR i, line: LONGINT;
BEGIN
	IF traceCalls IN trace THEN  BusNameMsg(d, "LoadSequencer"); KernelLog.Ln  END;
		Script.Init(FeatUltra2 IN d.features, FeatUltra IN d.features, FeatWide IN d.features, FeatTwin IN d.features,
				FlagPageSCB IN d.flags, FeatQueueRegs IN d.features, FeatCmdChan IN d.features, FALSE, AIC7895 = d.chip);
	i := 0;
	d.Put1(d, SEQCTL, SYSTEM.VAL(CHAR, {PERRORDIS,LOADRAM,FAILDIS,FASTMODE}));
	d.Put1(d, SEQADDR0, 0X);
	d.Put1(d, SEQADDR1, 0X);
	WHILE Script.GetNext(SYSTEM.VAL(SET, line)) DO
		d.Put1(d, SEQRAM, CHR(line));
		d.Put1(d, SEQRAM, CHR(LSH(line, -8)));
		d.Put1(d, SEQRAM, CHR(LSH(line, -16)));
		d.Put1(d, SEQRAM, CHR(LSH(line, -24)));
		INC(i)
	END;
	BusNameMsg(d, "Sequencer Loaded lines="); KernelLog.Int(i, 0); KernelLog.Ln;
	d.Put1(d, SEQCTL, SYSTEM.VAL(CHAR, {FASTMODE,SEQRESET}));
END SeqLoad;

(* PCI Functions *)

PROCEDURE PCIClearInt(d: Bus);
CONST	DPR = 0;  RMA = 5;  RTA = 4;
VAR	res, dw: LONGINT;  bus, dev, slot: LONGINT;
BEGIN
	bus := d.busNo;  dev := d.devNo;  slot := d.slotNo;
	res := PCI.ReadConfigByte(bus, dev, slot, 7H, dw);
	res := PCI.WriteConfigByte(bus, dev, slot, 7H, dw);	(* Clear PCI-Status *)
	IF {DPR, RMA, RTA} * SYSTEM.VAL(SET, dw) # {} THEN
		d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRPARERR}))
	END;
END PCIClearInt;

PROCEDURE PCIInit(d: Bus;  bus, dev, slot: LONGINT);
VAR  res, dw: LONGINT;
BEGIN
	IF traceCalls IN trace THEN  BusNameMsg(d, "PCIInit"); KernelLog.Ln  END;
	res:=PCI.ReadConfigByte(bus, dev, slot, PCI.IntlReg, dw);	(*irq*)
	d.irq :=  SHORT(SHORT(dw));
	BusName(d); KernelLog.String("irq="); KernelLog.Int(d.irq, 0);
	res:=PCI.ReadConfigDword(bus, dev, slot, PCI.Adr1Reg, dw);	(*memio*)
	IF dw = 0 THEN
		res:=PCI.ReadConfigDword(bus, dev, slot, PCI.Adr0Reg, dw);	(*iobase*)
		d.base := dw - 1;
		d.Put1 := PortPut;
		d.Get1 := PortGet;
		KernelLog.String(" Port="); KernelLog.Int(d.base, 0)
	ELSE
		dw := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, dw) * {3..31});	(* clear io mode & 64 bit flags*)
		Machine.MapPhysical(dw, 100H, d.base);
		d.Put1 := MemoryPut;
		d.Get1 := MemoryGet;
		KernelLog.String(" MemMap="); KernelLog.Hex(dw, 0); KernelLog.String("/"); KernelLog.Hex(d.base, 0)
	END;
	KernelLog.Ln;
	res:=PCI.ReadConfigWord(bus, dev, slot, PCI.CmdReg, dw);
	dw := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, dw) + {8, 6, 4, 2, 1, 0});	(*Serren, Perren, Mwricen, Master, MSpace, ISpace*)
	res:=PCI.WriteConfigWord(bus, dev, slot, PCI.CmdReg, dw);
	res:=PCI.ReadConfigDword(bus, dev, slot, DEVCONFIG, dw);
	dw := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, dw) + {PCIERRGENDIS} - {BERREN});
	IF d.chip = AIC7895 THEN
		dw := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, dw) + {SCBSIZE32});
	END;
	res:=PCI.WriteConfigDword(bus, dev, slot, DEVCONFIG, dw);
	SeqPause(d);
	PCIClearInt(d);
END PCIInit;

(* Message Handling *)

PROCEDURE MsgStart(d: Bus);
VAR  t: SET;
BEGIN
	INCL(d.flags, FlagHandlingReqInits);
	t := SYSTEM.VAL(SET, d.Get1(d, SIMODE1));
	d.Put1(d, SIMODE1, SYSTEM.VAL(CHAR, t + {ENREQINIT}));
END MsgStart;

PROCEDURE MsgStop(d: Bus);
VAR  t: SET;
BEGIN
	t := SYSTEM.VAL(SET, d.Get1(d, SIMODE1));
	d.Put1(d, SIMODE1, SYSTEM.VAL(CHAR, t - {ENREQINIT}));
	d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSCSIINT}));
	EXCL(d.flags, FlagHandlingReqInits);
END MsgStop;

PROCEDURE MsgCompose(d: Bus;  index: LONGINT;  VAR msg: Message);
VAR i: LONGINT;
BEGIN
	IF index IN d.negotiateWidth THEN
		EXCL(d.negotiateWidth, index);
		msg.buf[0] := SCSI.MsgExtended;
		msg.buf[1] := SCSI.MsgExtWdTrLen;
		msg.buf[2] := SCSI.MsgExtWdTr;
		msg.buf[3] := SCSI.MsgExtWdTr16Bit;	(*always ask for the max*)
		msg.len := 4;
		msg.pos := 0;
		msg.dir := Sending
	ELSIF index IN d.negotiateSync THEN
		EXCL(d.negotiateSync, index);
		i := GetTableIndex(FeatUltra IN d.features, FeatUltra2 IN d.features);
		msg.buf[0] := SCSI.MsgExtended;
		msg.buf[1] := SCSI.MsgExtSdTrLen;
		msg.buf[2] := SCSI.MsgExtSdTr;
		msg.buf[3] := CHR(rateTable[i].period);	(* ask for min period (fastest) *)
		msg.buf[4] := GetMaxOffset(FeatWide IN d.features, FeatUltra2 IN d.features);	(* ask for the max offset *)
		msg.len := 5;
		msg.pos := 0;
		msg.dir := Sending
	ELSE
		ToDo("Adaptec7.MsgCompose: negotiate what?");
	END
END MsgCompose;

PROCEDURE MsgParse(d: Bus;  VAR msg: Message): BOOLEAN;
VAR  reject, done, wide: BOOLEAN;  period, offset: LONGINT;  t: SET;
BEGIN
	reject := FALSE;  done := FALSE;
	IF msg.buf[0] # SCSI.MsgExtended THEN
		reject := TRUE
	ELSIF msg.len <= 2 THEN	(*ExtMsg are 4 or 5 bytes*)
		done := FALSE
	ELSIF msg.buf[2] = SCSI.MsgExtSdTr THEN	(*sync handling*)
		IF msg.buf[1] # SCSI.MsgExtSdTrLen THEN
			reject := TRUE
		ELSIF msg.len < ORD(SCSI.MsgExtSdTrLen)+2 THEN
			done := FALSE
		ELSE
			done := TRUE;
			period := ORD(msg.buf[3]);
			offset := ORD(msg.buf[4]);
			BusNameMsg(d, "SyncMsg "); KernelLog.Int(period, 0); KernelLog.Char("/");
			KernelLog.Int(offset, 0); KernelLog.Ln;
			SetSyncRate(d, period, offset)
		END
	ELSIF msg.buf[2] = SCSI.MsgExtWdTr THEN	(*width handling*)
		IF msg.buf[1] # SCSI.MsgExtWdTrLen THEN
			reject := TRUE
		ELSIF msg.len < ORD(SCSI.MsgExtWdTrLen)+2 THEN
			done := FALSE
		ELSE
			done := TRUE;
			wide := msg.buf[3] = SCSI.MsgExtWdTr16Bit;
			BusNameMsg(d, "WidthMsg "); KernelLog.Int(ORD(msg.buf[3]), 0); KernelLog.Ln;
			SetWidth(d, wide);
		END
	ELSE
		reject := TRUE
	END;
	IF reject THEN
		d.Put1(d, MSGOUT, SCSI.MsgMessageReject);
		t := SYSTEM.VAL(SET, d.Get1(d, SCSISIG));
		d.Put1(d, SCSISIG, SYSTEM.VAL(CHAR, t + {ATN}))
	END;
	RETURN reject OR done
END MsgParse;

PROCEDURE MsgTransmit(d: Bus;  VAR msg: Message);
VAR  t: SET;  done: BOOLEAN;  ch: CHAR;
BEGIN
	t := SYSTEM.VAL(SET, d.Get1(d, SCSISIG));
	IF msg.dir = Sending THEN
		IF traceSmall IN trace THEN
			KernelLog.Char("["); KernelLog.Hex(ORD(msg.buf[msg.pos]), -2); KernelLog.Char("]")
		END;
		IF msg.pos = msg.len-1 THEN	(* last byte *)
			done := TRUE;
			d.Put1(d, SINDEX, msg.buf[msg.pos]);
			d.Put1(d, RETURN1, 0X)
		ELSIF (t * PHASEMASK) # PhaseMsgOut  THEN	(* Phase Mismatch *)
			IF traceSmall IN trace THEN KernelLog.Char("&") END;
			done := TRUE;
			d.Put1(d, RETURN1, SYSTEM.VAL(CHAR, MSGOUTPHASEMIS))
		ELSE
			d.Put1(d, CLRSINT1, SYSTEM.VAL(CHAR, {CLRREQINIT}));
			d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSCSIINT}));
			d.Put1(d, SCSIDATL, msg.buf[msg.pos]);
			INC(msg.pos);
		END;
	ELSE
		done := (t * PHASEMASK) # PhaseMsgIn;
		IF ~done THEN
			msg.buf[msg.pos] := SYSTEM.VAL(CHAR, d.Get1(d, SCSIBUSL));
			IF traceSmall IN trace THEN
				KernelLog.Char("("); KernelLog.Hex(ORD(msg.buf[msg.pos]), -2); KernelLog.Char(")")
			END;
			INC(msg.len);  INC(msg.pos);
			done := MsgParse(d, d.msg);

			d.Put1(d, CLRSINT1, SYSTEM.VAL(CHAR, {CLRREQINIT}));
			d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSCSIINT}));
			ch := d.Get1(d, SCSIDATL);
			IF ch # msg.buf[msg.pos-1] THEN  KernelLog.String("Ada7.MsgTransmit, strange"); KernelLog.Ln END;
		ELSE
			KernelLog.String("Ada7.MsgTransmit, phase mismatch "); KernelLog.Hex(SYSTEM.VAL(LONGINT, t), -2);
			KernelLog.Ln
		END
	END;
	IF done THEN
		MsgStop(d);  SeqUnpause(d)
	END
END MsgTransmit;

(* Interrupt Handling *)

PROCEDURE Done(d: Bus;  index: LONGINT);	(* command terminated / aborted: remove scb and finish *)
BEGIN
(*
	BusNameMsg(d, "Done = "); KernelLog.Int(index, 0); KernelLog.Ln;
*)
	QUntaggedSet(d, index, 0FFX);
	HSFreeScb(d, index);
	IF d.sync[index] = InUse THEN
		d.Synchronize(index, InUse, Terminated)
	ELSE
		KernelLog.String("PANIC: done called but not in use!"); KernelLog.Ln
	END;
END Done;

PROCEDURE IntCommand(d: Bus);
VAR  index: LONGINT;
BEGIN
	INC(aIntCmdCount);
	IF traceInts IN trace THEN
		BusNameMsg(d, "IntCmdCmplt"); KernelLog.Ln;
		DumpAllLists(d);
		Reg(d, RETURN1, " RETURN = "); Reg(d, SCBPTR, " SCBPTR = "); KernelLog.Ln
	END;

	d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRCMDINT}));
	index := ORD(QOutGet(d, d.out));
	WHILE index # ORD(0FFX) DO
		QOutSet(d, d.out, 0FFX);
		d.out := (d.out + 1) MOD 256;
		Done(d, index);
		index := ORD(QOutGet(d, d.out))
	END
END IntCommand;

PROCEDURE IntBrkAdr(d: Bus);
VAR  error: SET;
BEGIN
	INC(aIntBrkAdrCount);
	error := SYSTEM.VAL(SET, d.Get1(d, ERROR));
	IF PCIERRSTAT IN error THEN
		ToDo("Adaptec7.IntBrkAdr/PCIERRSTAT");
		PCIClearInt(d)
	END;
	d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRPARERR, CLRBRKADRINT}));
	(*
		Sequence is interrupted by a break position. This should not happen (I do not
		set any breakpoint).
		Restart the sequencer
	*)
(*
	ToDo("IntBrkAdr");
	d.Put1(d, SEQCTL, SYSTEM.VAL(CHAR, {FASTMODE, SEQRESET}));
*)
	SeqUnpause(d)
END IntBrkAdr;

PROCEDURE IntSeqHandle(d: Bus;  code: LONGINT);
CONST trace = {traceInts};
VAR  active, ch: CHAR;  index: LONGINT;
BEGIN
	IF FALSE & (traceInts IN trace) THEN
		BusNameMsg(d, "IntSeqHandle"); KernelLog.Ln;
		DumpAllLists(d);
		Reg(d, RETURN1, " RETURN = "); Reg(d, SCBPTR, " SCBPTR = "); Reg(d, SCBTARGETSTATUS, " TargStat = "); KernelLog.Ln
	END;
	INC(aIntSeqCount);

	d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSEQINT}));
	active := d.Get1(d, SCBPTR);  index := ORD(d.Get1(d, SCBTAG));

	CASE code OF
	| NoMatch:
			IF traceInts IN trace THEN BusNameMsg(d, "IntSeqHandle.NoMatch"); KernelLog.Ln END;
			INC(aIntSeqNoMatch);
			ch := d.Get1(d, SCSISEQ);
			d.Put1(d, SCSISEQ, SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, ch) * {ENSELI, ENRSELI, ENAUTOATNP}))
	| SendReject:
			IF traceInts IN trace THEN BusNameMsg(d, "IntSeqHandle.SendReject"); KernelLog.Ln END;
			INC(aIntSeqSendReject)
	| NoIdent:
			INC(aIntSeqNoIdent);
			ToDo("IntSeqHandle.NoIdent")
	| BadPhase:
			IF traceInts IN trace THEN BusNameMsg(d, "IntSeqHandle.BadPhase"); KernelLog.Ln END;
			INC(aIntSeqBadPhase);
			IF PhaseBusFree = SYSTEM.VAL(SET, d.Get1(d, LASTPHASE)) THEN
				d.Put1(d, SEQCTL, SYSTEM.VAL(CHAR, {FASTMODE, SEQRESET}))
			END
	| ExtendedMsg:
			IF (traceInts IN trace) THEN BusNameMsg(d, "IntSeqHandle.ExtendedMsg"); KernelLog.Ln END;
			INC(aIntSeqExtendedMsg);
			MsgStart(d);
			d.msg.dir := Receiving; d.msg.pos := 0; d.msg.len := 0;
			RETURN	(*don't unpause the sequencer!*)
	| RejectMsg:
			IF (traceInts IN trace) THEN BusNameMsg(d, "IntSeqHandle.RejectMsg"); KernelLog.Ln END;
			INC(aIntSeqRejectMsg);
	| BadStatus:
			(* result of the status phase *)
			INC(aIntSeqBadStatus);
			d.Put1(d, RETURN1, 0X);
			d.status[index] := SHORT(ORD(d.Get1(d, SCBTARGETSTATUS)));
			IF traceInts IN trace THEN
				BusNameMsg(d, "IntSeq.BadStatus[");
				KernelLog.Int(index, 0);  KernelLog.String("] = "); KernelLog.Int(d.status[index], 0); KernelLog.Ln;
				Reg(d, SSTAT0, "STAT0 = "); Reg(d, SSTAT1, " STAT1 = "); Reg(d, SSTAT2, " STAT2 = "); Reg(d, SSTAT3, " STAT3 = ");
				Reg(d, ERROR, " ERROR = ");
				Reg(d, DSCOMMAND0, " CMD0 = "); Reg(d, DSPCISTATUS, " DSPCISTATUS = "); KernelLog.Ln;
				DumpAllLists(d);
				Reg(d, RETURN1, " RETURN = "); Reg(d, SCBPTR, " SCBPTR = "); Reg(d, SCBTARGETSTATUS, " TargStat = ");
				Reg(d, DFSTATUS, " DFSTATUS = "); Reg(d, DFFTHRSH, " DFFTHRSH = ");
				 KernelLog.Ln;
				DumpCurSCB(d);
			END
	| AwaitingMsg:	(* ScbMessage was in the scb control tag: now the sequencer asks if we have a message *)
			IF traceInts IN trace THEN BusNameMsg(d, "IntSeqHandle.AwaitingMsg"); KernelLog.Ln END;
			INC(aIntSeqAwaitingMsg);
			MsgStart(d);
			MsgCompose(d, index, d.msg);	(*prepare the message in the buffer, send during the scsi interrupt*)
			RETURN	(*don't unpause the sequencer!*)
	| DataOverrun:
			INC(aIntSeqDataOverrun);
			IF TRUE & (traceInts IN trace) THEN BusNameMsg(d, "IntSeqHandle.DataOverrun"); KernelLog.Ln END;
			d.status[index] := SCSI.CommandTerminated;
			d.result[index] := SCSI.Error;
	END;
	SeqUnpause(d)
END IntSeqHandle;

PROCEDURE IntScsiSeltoHandle(d: Bus);
VAR  t: SET;  index: LONGINT;
BEGIN
	INC(aIntScsiSelto);
	IF d.Get1(d, WAITINGSCBH) # d.Get1(d, SCBPTR) THEN
		INC(aIntScsiSeltoProblem1);
		BusNameMsg(d, "Selto: WAITING # SCBPTR"); KernelLog.Ln
	END;
	d.Put1(d, SCBPTR, d.Get1(d, WAITINGSCBH));
	index := ORD(d.Get1(d, SCBTAG));
	IF (traceInts IN trace) THEN
		BusNameMsg(d, "IntScsiHandle.Selto"); KernelLog.Int(index, 0); KernelLog.Ln;
		DumpCurSCB(d)
	END;

	IF d.sync[index] # InUse THEN
		INC(aIntScsiSeltoProblem2);
		ToDo("IntScsiHandle.Selto/Invalid Index");
		BusNameMsg(d, "IntScsiHandle.Selto"); KernelLog.Int(ORD(d.Get1(d, WAITINGSCBH)), 0);
		KernelLog.Char("/"); KernelLog.Int(index, 0); KernelLog.Ln;
		DumpCurSCB(d);
		DumpAllLists(d);

	ELSE
		d.status[index] := SCSI.CommandTerminated;
		d.result[index] := SCSI.TimeOut;
		EXCL(d.negotiateWidth, index);
		EXCL(d.negotiateSync, index);
		d.Put1(d, SCBCONTROL, 0X);
		d.Put1(d, MSGOUT, SCSI.MsgNoop);
		d.Put1(d, WAITINGSCBH, d.Get1(d, SCBNEXT));
		HSFreeCurrent(d);
		Done(d, index)
	END;
	d.Put1(d, SCSISEQ, 0X);
	t := SYSTEM.VAL(SET, d.Get1(d, SIMODE1));
	d.Put1(d, SIMODE1, SYSTEM.VAL(CHAR, t - {ENREQINIT, ENBUSFREE}));
	EXCL(d.flags, FlagHandlingReqInits);
	d.Put1(d, CLRSINT1, SYSTEM.VAL(CHAR, {CLRSELTIMEO,CLRBUSFREE}));
	d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSCSIINT}));
	d.Put1(d, SEQCTL, SYSTEM.VAL(CHAR, {FASTMODE, SEQRESET}));
	SeqUnpause(d)
END IntScsiSeltoHandle;

PROCEDURE IntScsiResetHandle(d: Bus);
	PROCEDURE TraverseList(d: Bus;  list: LONGINT;  debugMsg: ARRAY OF CHAR);
	VAR  ptr: CHAR;  index: LONGINT;
	BEGIN
		ptr := d.Get1(d, list);
		WHILE ptr # 0FFX DO
			d.Put1(d, SCBPTR, ptr);
			index := ORD(d.Get1(d, SCBTAG));
			KernelLog.String(debugMsg); KernelLog.Hex(ORD(ptr), -2); KernelLog.Char("/");
			KernelLog.Hex(index, -2); KernelLog.Ln;
			ptr := d.Get1(d, SCBNEXT);
			HSFreeCurrent(d);
			d.status[index] := SCSI.NotGood;
			d.result[index] := SCSI.Reset;
			Done(d, index)
		END;
	END TraverseList;
BEGIN
	(* the bus is reset. Kill outstanding commands and reconfigure bus*)
	IF TRUE & (traceInts IN trace) THEN
		BusNameMsg(d, "IntScsiResetHandle"); KernelLog.Ln;
		DumpAllLists(d);
	END;
	INC(aIntScsiReset);
	BusConfigure(d);
	TraverseList(d, WAITINGSCBH, "waiting list ");
	TraverseList(d, DISCONNECTEDSCBH, "disc list");
	d.Put1(d, CLRSINT1, SYSTEM.VAL(CHAR, {CLRSCSIRSTI}));
	d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSCSIINT}));
	SeqUnpause(d)
END IntScsiResetHandle;

PROCEDURE IntScsiHandle(d: Bus);
VAR  status: SET;
BEGIN
	IF traceInts IN trace THEN
		BusNameMsg(d, "IntScsiHandle"); KernelLog.Ln;
		DumpAllLists(d);
		Reg(d, SSTAT1, "STAT1 = ");  Reg(d, SIMODE1, " SIMODE1 = ");
		Reg(d, RETURN1, " RETURN = "); Reg(d, SCBPTR, " SCBPTR = "); KernelLog.Ln
	END;
	INC(aIntScsiCount);
	status := SYSTEM.VAL(SET, d.Get1(d, SSTAT1));
	IF SCSIRSTI IN status THEN
			IntScsiResetHandle(d)
	ELSIF SELTO IN status THEN
			IntScsiSeltoHandle(d)
	ELSIF BUSFREE IN status THEN
			INC(aIntScsiBusFree);
			ToDo("IntScsiHandle.BusFree");
			Reg(d, LASTPHASE, "LASTPHASE"); KernelLog.Ln;
			d.Put1(d, CLRSINT1, SYSTEM.VAL(CHAR, {CLRBUSFREE}));
			d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSCSIINT}));
			d.Put1(d, SEQCTL, SYSTEM.VAL(CHAR, {FASTMODE, SEQRESET}));
			SeqUnpause(d)
	ELSIF SCSIPERR IN status THEN
			INC(aIntScsiParity);
			IF TRUE & (traceInts IN trace) THEN BusNameMsg(d, "IntScsiHandle.SCSIPERR"); KernelLog.Ln END;
			d.Put1(d, CLRSINT1, SYSTEM.VAL(CHAR, {CLRSCSIPERR}));
			d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSCSIINT}));
			SeqUnpause(d)
	ELSIF (REQINIT IN status) & (FlagHandlingReqInits IN d.flags) THEN
			IF traceInts IN trace THEN  BusNameMsg(d, "IntScsiHandle.ReqInit"); KernelLog.Ln  END;
			INC(aIntScsiReqInit);
			MsgTransmit(d, d.msg);
	ELSIF (1 IN status) & (FlagHandlingReqInits IN d.flags) THEN
			INC(aIntScsiSpecial);
			KernelLog.Char("("); KernelLog.Hex(ORD(d.Get1(d, SCSIBUSL)), -2); KernelLog.Char(")");
			ToDo("IntScsiHandle.Unexpected message");
	ELSE
			INC(aIntScsiUnknown);
			ToDo("IntScsiHandle.Unknown");
			KernelLog.String("SSTAT1 = "); KernelLog.Hex(SYSTEM.VAL(LONGINT, status), -2); KernelLog.Ln;
			d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSCSIINT}));
			SeqUnpause(d)
	END
END IntScsiHandle;

PROCEDURE IntClear(d: Bus);
BEGIN
	d.Put1(d, CLRSINT0, SYSTEM.VAL(CHAR, {CLRSELDO, CLRSELDI, CLRSELINGO}));
	d.Put1(d, CLRSINT1, SYSTEM.VAL(CHAR, CLRSINT1ALL));
	d.Put1(d, CLRINT, SYSTEM.VAL(CHAR, {CLRSCSIINT, CLRSEQINT, CLRBRKADRINT, CLRPARERR}))
END IntClear;

PROCEDURE IntInstall(d: Bus);
BEGIN
	IntClear(d);
	IF interrupt[d.irq] = NIL THEN  NEW(interrupt[d.irq], d.irq)  END;
	d.next := interrupt[d.irq].root;  interrupt[d.irq].root := d;
	BusNameMsg(d, "IntHandler installed, "); KernelLog.Int(d.irq, 0); KernelLog.Ln;
END IntInstall;

(* ScbControl - Compote the control byte for dev-th device *)

PROCEDURE ScbControl(d: Bus;  dev: LONGINT): CHAR;
BEGIN
	IF dev IN d.negotiateWidth THEN
		IF traceSmall IN trace THEN KernelLog.Char("W") END;
		(*EXCL(dev, d.negotiateWidth);*) 	(*done in message handling! Only one msg per device*)
		RETURN SYSTEM.VAL(CHAR, {HwScbMessage})
	ELSIF dev IN d.negotiateSync THEN
		IF traceSmall IN trace THEN KernelLog.Char("S") END;
		RETURN SYSTEM.VAL(CHAR, {HwScbMessage})
	END;
	RETURN 0X
END ScbControl;

(* BusSchedule - Schedule a new command for execution *)

PROCEDURE BusSchedule(d: Bus;  VAR c: SCSI.Command);
CONST  MaxRange = 64;
VAR  index, num, useRange, sgaddr: LONGINT; target: CHAR;  range: ARRAY 2, MaxRange+1 OF Machine.Range;
	(*dog: Watchdog;*)
	cmd: ARRAY 2, 16 OF CHAR;  cmdBlock: LONGINT;
BEGIN
	INC(aExecute);
	IF (0 > c.target) OR (c.target >= d.width) OR ~(c.lun IN {0..7}) OR ~(c.chan IN {0,1}) THEN	(*Invalid Destination*)
		d.Synchronize(c.target, InUse, Free);
		HALT(200)
	END;
	IF (c.dlen > MaxRange * 4096) THEN		(* max pages: change range to increment this limit *)
		d.Synchronize(c.target, InUse, Free);
		HALT(201)
	END;
	(*IF traceDog IN trace THEN NEW(dog, 1000, 5, d, c.target) END;*)
	index := c.target;	(* this will be the scb used! *)
	IF traceSmall IN trace THEN
		KernelLog.Char("{"); KernelLog.Hex(ORD(c.cmd[0]), -2); KernelLog.Char("}")
	END;
	IF traceCmds IN trace THEN
		BusNameMsg(d, "schedule ["); KernelLog.Int(index, 0); KernelLog.String("] =  ");
		KernelLog.Hex(ORD(c.cmd[0]), -2);
	END;
	d.status[index] := SCSI.Good;
	d.result[index] := SCSI.OK;
	target := MakeTarget(c.target, c.chan, c.lun);
	HSSet(d, index, HScontrol, ScbControl(d, index));
	HSSet(d, index, HStarget, target);
	Machine.TranslateVirtual(ADDRESSOF(c.cmd[0]), c.clen, num, range[0]);
	ASSERT(num # 0, 202);
	IF num > 1 THEN	(* The command buffer doesn't fit on one page, create own temp buffer *)
		cmdBlock := -1;
		REPEAT
			INC(cmdBlock);
			Machine.TranslateVirtual(ADDRESSOF(cmd[cmdBlock, 0]), c.clen, num, range[0]);
		UNTIL num = 1;
		SYSTEM.MOVE(ADDRESSOF(c.cmd[0]), ADDRESSOF(cmd[cmdBlock, 0]), c.clen);
	END;
	HSSet4(d, index, HScmdPtr, range[0, 0].adr);
	HSSet(d, index, HScmdLen, CHR(c.clen));

	IF c.dlen = 0 THEN
		IF traceCmds IN trace THEN
			KernelLog.String("  No Data "); KernelLog.Ln
		END;
		HSSet(d, index, HSSGcount, 0X);
		HSSet4(d, index, HSSGptr, 0);
		HSSet4(d, index, HSdataPtr, 0);
		HSSet4(d, index, HSdataCnt, 0)
	ELSE
		ASSERT(c.dataAddr # 0);
		(* the data can be spread across many physical pages, I thus use a scatter-gather list
			for the data. Now the list itself could also be on a page boundary: I declare two adjacent ranges
			and at least one of them will fit on one page. *)
		Machine.TranslateVirtual(ADDRESSOF(range[0, 0]), 16*SIZEOF(Machine.Range), num, range[0]);
		IF num = 1 THEN	(* whole range[0] fits in one memory page *)
			useRange := 0;
		ELSE
			Machine.TranslateVirtual(ADDRESSOF(range[1, 0]), 16*SIZEOF(Machine.Range), num, range[0]);
			ASSERT(num = 1, 203);
			useRange := 1;
			IF traceCmds IN trace THEN KernelLog.Char("+")END;
		END;
		sgaddr := range[0, 0].adr;
		Machine.TranslateVirtual(c.dataAddr, c.dlen, num, range[useRange]);
		ASSERT(num # 0, 204);
		IF traceCmds IN trace THEN
			IF num > 1 THEN KernelLog.Char("%") ELSE KernelLog.Char("$") END
		END;
		HSSet(d, index, HSSGcount, CHR(num));
		HSSet4(d, index, HSSGptr, sgaddr+SIZEOF(Machine.Range));	(*pass address to 2nd block*)
		HSSet4(d, index, HSdataPtr, range[useRange, 0].adr);
		HSSet4(d, index, HSdataCnt, range[useRange, 0].size);
		IF traceCmds IN trace THEN
			KernelLog.String("  Data = "); KernelLog.Int(c.dlen, 0);
			KernelLog.Int(useRange, 2);
			KernelLog.Int(num, 2);
			KernelLog.Ln;
		END;
	END;
	QUntaggedSet(d, ORD(target), CHR(index));
	QInSet(d, d.in, CHR(index));
	d.in := (d.in+1) MOD 256;
	IF FeatQueueRegs IN d.features THEN
		d.Put1(d, HNSCBQOFF, CHR(d.in))
	ELSE
		SeqPause(d);
		d.Put1(d, KERNELQINPOS, CHR(d.in));
		SeqUnpause(d)
	END;
	d.Synchronize(c.target, Terminated, Terminated);	(* don't free: let bus.Submit copy results *)
	(*IF traceDog IN trace THEN dog.stop := TRUE END;*)	(*kill watchdog*)
	IF traceCmds IN trace THEN
		BusNameMsg(d, "schedule ["); KernelLog.Int(index, 0); KernelLog.String("] result = ");
		KernelLog.Int(d.status[index], 0); KernelLog.Char("/"); KernelLog.Int(d.result[index], 0);
		KernelLog.Ln
	END;
END BusSchedule;

(* Reset Bus *)

PROCEDURE BusReset(d: Bus);
(* if bus reset is called during bus operations, then the timer must be made local to the bus to avoid race conditions *)
VAR  mode1, seq: SET;
BEGIN
	BusNameMsg(d, "BusR");
	mode1 := SYSTEM.VAL(SET, d.Get1(d, SIMODE1));

	d.Put1(d, SIMODE1, SYSTEM.VAL(CHAR, mode1 - {ENSCSIRST}));
	d.Put1(d, SCSISEQ, SYSTEM.VAL(CHAR, {SCSIRSTO}));		(*d.Put1(d, SCSISEQ, d.Get1(d, SCSISEQ) + {SCSIRSTO});*)
	KernelLog.Char("e");
	REPEAT
		timer.Sleep(5);
		seq :=SYSTEM.VAL(SET,  d.Get1(d, SCSISEQ))
	UNTIL (SCSIRSTO IN seq);
	KernelLog.Char("s");
	timer.Sleep(10);
	d.Put1(d, SCSISEQ, 0X);
	timer.Sleep(5);
	KernelLog.Char("e");
	IntClear(d);
	d.Put1(d, SIMODE1, SYSTEM.VAL(CHAR, mode1 + {ENSCSIRST}));
	KernelLog.Char("t"); KernelLog.Ln
END BusReset;

PROCEDURE BusChipReset(d: Bus);
VAR  t: Kernel.MilliTimer;
BEGIN
	IF {traceCalls, traceReset} * trace # {} THEN  BusNameMsg(d, "ResetChip"); KernelLog.Ln  END;
	d.Put1(d, HCNTRL, SYSTEM.VAL(CHAR, {PAUSE, CHIPRST}));
	Kernel.SetTimer(t, 1000);	(*1 sec*)
	REPEAT
	UNTIL (CHIPRST IN SYSTEM.VAL(SET, d.Get1(d, HCNTRL))) OR Kernel.Expired(t);
	SeqPause(d);	(*pause & clear rst bit*)
END BusChipReset;

PROCEDURE BusDetectWidth(d: Bus);
VAR s: SET;
BEGIN
	s := SYSTEM.VAL(SET, d.Get1(d, SBLKCTL));
	s := s * {SELWIDE, SELBUSB};
	d.wide := FALSE;  d.width := 8;	(*default values*)
	IF s = {SELWIDE} THEN
		BusNameMsg(d, "bus is wide"); KernelLog.Ln;
		INCL(d.features, FeatWide);
		d.wide := TRUE;  d.width := 16
	ELSIF s = {SELBUSB} THEN
		BusNameMsg(d, "multichannel card"); KernelLog.Ln;
		IF ~(FlagMultiChannel IN d.flags) THEN
			BusNameMsg(d, "WARNING: this card is not declared as multichannel"); KernelLog.Ln
		END;
		INCL(d.features, FeatTwin);
		INCL(d.flags, FlagMultiChannel)
	ELSIF s # {} THEN
		BusNameMsg(d, "PANIC: this card is both wide and multichannel"); KernelLog.Ln;
		HALT(99)
	END
END BusDetectWidth;

PROCEDURE BusConfigureChannels(d: Bus);	(*special setups for multichannel boards*)
VAR  chip: SHORTINT; set: SET;
BEGIN
	chip := d.chip;
	IF  FlagMultiChannel IN d.flags THEN
		IF chip IN {AIC7870, AIC7880} THEN
			IF d.slotNo = 5 THEN  INCL(d.flags, FlagChnlB)			(*3940, 3940Ultra*)
			ELSIF d.slotNo = 8 THEN INCL(d.flags, FlagChnlB)			(*3985, 3985Ultra*)
			ELSIF d.slotNo = 12 THEN INCL(d.flags, FlagChnlC)			(*3985, 3985Ultra*)
			END
		ELSIF chip IN {AIC7895, AIC7896} THEN
			IF d.devNo # 0 THEN  INCL(d.flags, FlagChnlB) END;
		END;
	END;
	(*set of DEVCONFIG.SCBSIZE32 for 7895 done in InitPCIBus*)

	set := SYSTEM.VAL(SET, d.Get1(d, DSCOMMAND0));
	IF chip IN {AIC7890, AIC7896} THEN
		d.Put1(d, SCAMCTL, 0X);
		set := set + {CACHETHEN, MPARCKEN, USCBSIZE32, CIOPARCKEN} - {DPARCKEN}
	ELSIF chip IN {AIC7850, AIC7860} THEN
		set := set + {CACHETHEN, MPARCKEN}- {DPARCKEN}
	END;
	d.Put1(d, DSCOMMAND0, SYSTEM.VAL(CHAR, set))
END BusConfigureChannels;

PROCEDURE BusConfigure(d: Bus);
VAR i: LONGINT;
BEGIN
	(* Init Speed/Width/Scratch RAM *)
	d.scsiId := 7;	(* host card id = 7 *)
	i := d.width;
	IF ~(traceNoHandling IN trace) THEN
		IF d.wide THEN
			d.negotiateWidth := {0 .. d.width-1};
		END;
		d.negotiateSync := {0 .. d.width-1}
	END;
	WHILE i > 0 DO
		DEC(i);
		d.Put1(d, TARGSCSIRATE+i, 0X);	(* dev[i] = async / 8-bit wide*)
		IF FeatUltra2 IN d.features THEN
			d.Put1(d, TARGOFFSET+i, 0X);	(* dev[i] = no offset *)
		END
	END;
	d.Put1(d, ULTRAENB, 0X);		(* no ultra *)
	d.Put1(d, ULTRAENB+1, 0X);
	d.Put1(d, DISCDSB, 0X);		(* no disconnect *)
	d.Put1(d, DISCDSB+1, 0X);
	d.Put1(d, SCSICONF, SYSTEM.VAL(CHAR, {ENSPCHK, RESETSCSI}));
	d.Put1(d, SCSICONF+1, CHR(d.scsiId))
END BusConfigure;

PROCEDURE BusInit(d: Bus);
VAR  sblkctr: SET;

	PROCEDURE InitChannel;
	BEGIN
		IF FeatUltra2 IN d.flags THEN
			d.Put1(d, SCSIIDULTRA2, CHR(d.scsiId))
		ELSE
			d.Put1(d, SCSIID, CHR(d.scsiId))
		END;
		d.Put1(d, SXFRCTL0, SYSTEM.VAL(CHAR, {DFON, SPIOEN}));
		d.Put1(d, SXFRCTL1, SYSTEM.VAL(CHAR, {ENSPCHK, ENSTIMER, ACTNEGEN, STPWEN}));
		d.Put1(d, SIMODE0, 0X);
		d.Put1(d, SIMODE1, SYSTEM.VAL(CHAR,{ENSELTIMO, ENSCSIRST, ENSCSIPERR}));
		d.Put1(d, SCSIRATE, 0X);
	END InitChannel;

BEGIN
	IF d.chip = AIC7770 THEN  d.Put1(d, BCTL, SYSTEM.VAL(CHAR, {ENABLE}))  END;
	sblkctr := SYSTEM.VAL(SET, d.Get1(d, SBLKCTL));
	sblkctr := sblkctr - {AUTOFLUSHDIS, DIAGLEDEN};
	d.Put1(d, SBLKCTL, SYSTEM.VAL(CHAR, sblkctr));

	d.Put1(d, MSGOUT, SCSI.MsgNoop);
	d.Put1(d, LASTMSG, SCSI.MsgNoop);
	d.Put1(d, SEQFLAGS, 0X);

	d.Put1(d, TMODECMDADDR, 0X);
	d.Put1(d, TMODECMDADDR+1, 0X);
	d.Put1(d, TMODECMDADDR+2, 0X);
	d.Put1(d, TMODECMDADDR+3, 0X);
	d.Put1(d, TMODECMDADDRNEXT, 0X);

	IF FeatTwin IN d.features THEN
		d.Put1(d, SBLKCTL, SYSTEM.VAL(CHAR, sblkctr+{SELBUSB}));
		InitChannel;
		BusReset(d);
		d.Put1(d, SBLKCTL, SYSTEM.VAL(CHAR, sblkctr))
	END;
	InitChannel;
	IF FeatUltra2 IN d.features THEN
		d.Put1(d, DFFTHRSH, SYSTEM.VAL(CHAR, WRDFFTHRSH75 + RDDFFTHRSH75))
	ELSE
		d.Put1(d, DSPCISTATUS, SYSTEM.VAL(CHAR, DFTHRSH100))
	END;
	BusReset(d);
	d.interruptable := TRUE;
END BusInit;

(* Bus detection *)

PROCEDURE Detect;
VAR  dummy, idx, bus, dev, slot, res, signature, i: LONGINT;  host: Bus;
BEGIN
	IF traceCalls IN trace THEN KernelLog.String("Ada7: Detect"); KernelLog.Ln  END;
	IF PCI.Done = PCI.PCIPresent(dummy, dummy, dummy) THEN
		idx := 0;
		WHILE PCI.Done = PCI.FindPCIClassCode(010000H (*scsi card*), idx, bus, dev, slot) DO
			res := PCI.ReadConfigDword(bus, dev, slot, PCI.DevReg, signature);	(*signature = VendID / DevID*)
			i := LEN(card)-1;
			REPEAT  DEC(i)  UNTIL  (i < 0) OR (card[i].signature = signature);
			IF i >= 0 THEN
				NEW(host, i, bus, dev, slot);
				BusNameMsg(host, card[i].name); KernelLog.Ln;
				PCIInit(host, bus, dev, slot);
				BusChipReset(host);
				BusDetectWidth(host);
				BusConfigureChannels(host);
				BusConfigure(host);
				HSInit(host);
				QInit(host);
				SeqLoad(host);
				BusInit(host);
				IntInstall(host);
				SeqUnpause(host);
				IF ~(traceNoRegister IN trace) THEN
					timer.Sleep(1000);		(*wait for the bus reset to complete*)
					SCSI.RegisterBus(host)
				END
			END;
			INC(idx)
		END
	ELSE
		KernelLog.String("Ada7: No PCI present"); KernelLog.Ln
	END;
END Detect;

(* Module Termination Functions *)

PROCEDURE Cleanup;
VAR  d: Bus;  i: LONGINT;
BEGIN
	IF Modules.shutdown # Modules.None THEN  RETURN  END;
	FOR i := 0 TO 31 DO
		IF interrupt[i] # NIL THEN
			d := interrupt[i].root;
			WHILE d # NIL DO
				SeqPause(d);
				SCSI.RemoveBus(d);
				ToDo("Ada7: free buffers");
				BusNameMsg(d, "Removed"); KernelLog.Ln;
				d := d.next
			END;
			interrupt[i].Cleanup
		END
	END;
	firstBus := NIL;
END Cleanup;

PROCEDURE Init;
CONST
	ultraFlags = {FlagPageSCB, FlagNewEepromFMT, FlagBiosEnabled};
	ultra2Features = {FeatMoreSRAM, FeatUltra2, FeatCmdChan, FeatQueueRegs, FeatSGPreload};

	PROCEDURE Card(i: LONGINT; sig: HUGEINT;  chip: SHORTINT;  flags, features: SET;  name: ARRAY OF CHAR);
	BEGIN
		card[i].signature := SHORT(sig);
		card[i].chip := chip;
		card[i].flags := flags;  card[i].features := features;
		COPY(name, card[i].name)
	END Card;

	PROCEDURE Table(i: LONGINT;  period: SHORTINT;  rate, u2rate: CHAR;  speed: LONGINT);
	BEGIN
		rateTable[i].period := period;
		rateTable[i].rate := rate;
		rateTable[i].u2rate := u2rate;
		rateTable[i].speed := speed
	END Table;

BEGIN
	IF traceAIC7890 IN trace THEN
		Card(15, 001F9005H, AIC7890, ultraFlags, ultra2Features, "Adaptec AIC-7890/1 Ultra2");
	ELSIF traceAIC7880 IN trace THEN
		Card(9, 80789004H, AIC7880, {FlagPageSCB, FlagBiosEnabled}, {FeatUltra}, "Adaptec AIC-7880 Ultra");
	ELSIF traceAHA2940 IN trace THEN
		Card(10, 81789004H, AIC7880, {FlagPageSCB, FlagBiosEnabled}, {FeatUltra}, "Adaptec AHA-294X Ultra");
	ELSE
	Card(0, 50789004H, AIC7850, {}, {FeatSpioCap}, "Adaptec AIC-7850");
	Card(1, 55789004H, AIC7850, {FlagPageSCB}, {FeatSpioCap}, "Adaptec AIC-7855");
	Card(2, 60789004H, AIC7860, ultraFlags, {FeatUltra, FeatSpioCap}, "Adaptec AIC-7860 Ultra");
	Card(3, 61789004H, AIC7860, ultraFlags, {FeatUltra, FeatSpioCap}, "Adaptec AHA-2940A Ultra");
	Card(4, 70789004H, AIC7870, {FlagPageSCB, FlagBiosEnabled}, {}, "Adaptec AIC-7870");
	Card(5, 71789004H, AIC7870, {FlagPageSCB, FlagBiosEnabled}, {}, "Adaptec AHA-294X");
	Card(6, 72789004H, AIC7870, {FlagPageSCB, FlagBiosEnabled, FlagMultiChannel}, {}, "Adaptec AHA-394X");
	Card(7, 73789004H, AIC7870, {FlagPageSCB, FlagBiosEnabled, FlagMultiChannel}, {}, "Adaptec AHA-398X");
	Card(8, 74789004H, AIC7870, {FlagPageSCB, FlagBiosEnabled}, {}, "Adaptec AHA-2944");
	Card(9, 80789004H, AIC7880, {FlagPageSCB, FlagBiosEnabled}, {FeatUltra}, "Adaptec AIC-7880 Ultra");
	Card(10, 81789004H, AIC7880, {FlagPageSCB, FlagBiosEnabled}, {FeatUltra}, "Adaptec AHA-294X Ultra");
	Card(11, 82789004H, AIC7880, {FlagPageSCB, FlagBiosEnabled, FlagMultiChannel}, {FeatUltra}, "Adaptec AHA-394X Ultra");
	Card(12, 83789004H, AIC7880, {FlagPageSCB, FlagBiosEnabled, FlagMultiChannel}, {FeatUltra}, "Adaptec AHA-398X Ultra");
	Card(13, 84789004H, AIC7880, {FlagPageSCB, FlagBiosEnabled}, {FeatUltra},"Adaptec AHA-2944 Ultra");
	Card(14, 78959004H, AIC7895, ultraFlags + {FlagMultiChannel}, {FeatMoreSRAM, FeatUltra, FeatCmdChan}, "Adaptec AIC-7895 Ultra");
	Card(15, 001F9005H, AIC7890, ultraFlags, ultra2Features, "Adaptec AIC-7890/1 Ultra2");
	Card(16, 00109005H, AIC7890, ultraFlags, ultra2Features, "Adaptec AHA-294X Ultra2");
	Card(17, 005F9005H, AIC7896, ultraFlags + {FlagMultiChannel}, ultra2Features, "Adaptec AIC-7896/7 Ultra2");
	Card(18, 00509005H, AIC7896, ultraFlags + {FlagMultiChannel}, ultra2Features, "Adaptec AHA-394X Ultra2");
	END;
	Table(0, 10, 0FFX, 13X, 400);
	Table(1, 11, 0FFX, 14X, 200);
	Table(2, 12, 0X, 15X, 200);
	Table(3, 15, 10X, 16X, 160);
	Table(4, 18, 20X, 17X, 133);
	Table(5, 25, 00X, 18X, 100);
	Table(6, 31, 10X, 19X, 80);
	Table(7, 37, 20X, 1AX, 67);
	Table(8, 43, 30X, 1BX, 57);
	Table(9, 50, 40X, 1CX, 50);
	Table(10, 56, 50X, 0FFX, 44);
	Table(11, 62, 60X, 0FFX, 40);
	Table(12, 68, 70X, 0FFX, 36);
	Modules.InstallTermHandler(Cleanup)
END Init;

(*
PROCEDURE WriteBusState(d: Bus);
BEGIN
	BusName(d);
	Reg(d, ERROR, "ERROR = ");
	Reg(d, INTSTAT, " INTSTAT = ");
	Reg(d, HCNTRL, " HCNTRL = ");
(*
	SeqPause(d);
	Reg(d, SIMODE0, " SIMODE0 = ");
	Reg(d, SIMODE1, " SIMODE1 = ");
	SeqUnpause(d);
*)
	KernelLog.Ln;
END WriteBusState;

PROCEDURE WriteScsiState(d: Bus);
BEGIN
	SeqPause(d);
	BusNameMsg(d, "Scsi State");
	Reg(d, SSTAT0, " S0=");
	Reg(d, SSTAT1, " S1=");
	Reg(d, SSTAT2, " S2=");
	Reg(d, SIMODE0, " M0=");
	Reg(d, SIMODE1, " M1=");
	KernelLog.Ln;
	SeqUnpause(d);
END WriteScsiState;

PROCEDURE WriteBusConfig(d: Bus);
VAR i: LONGINT;  name: ARRAY 8 OF CHAR; Hex: ARRAY 17 OF CHAR;
BEGIN
	Hex := "0123456789ABCDEF";
	BusNameMsg(d, d.name); KernelLog.Ln;
	Reg(d, ULTRAENB, "Ultra0=");  Reg(d, ULTRAENB+1, " Ultra1=");
	Reg(d, DISCDSB, " Disc0=");  Reg(d, DISCDSB+1, " Disc1=");
	Reg(d, SCSICONF, " Conf0=");  Reg(d, SCSICONF+1, " Conf1="); KernelLog.Ln;
	name := " rateX=";
	FOR i := 0 TO d.width-1 DO
		name[5] := Hex[i];
		Reg(d, TARGSCSIRATE+i, name);
		IF FeatUltra2 IN d.features THEN  Reg(d, TARGOFFSET+i, "/")  END;
		IF i MOD 4 = 3 THEN KernelLog.Ln END
	END;
END WriteBusConfig;

PROCEDURE WriteBusConfig2(d: Bus);
VAR i: LONGINT;  name: ARRAY 8 OF CHAR; Hex: ARRAY 17 OF CHAR;

	PROCEDURE Bit(d: Bus;  base, bit: LONGINT;  msg: ARRAY OF CHAR);
	VAR  set: SET;
	BEGIN
		set := SYSTEM.VAL(SET, d.Get1(d, base + bit DIV 8));
		IF (bit MOD 8) IN set THEN  KernelLog.String(msg)  END
	END Bit;

BEGIN
	Hex := "0123456789ABCDEF";
	BusNameMsg(d, d.name); KernelLog.Ln;
	FOR i := 0 TO d.width-1 DO
		KernelLog.String("Device"); KernelLog.Char(Hex[i]);
		Reg(d, TARGSCSIRATE+i, " rate = ");
		IF FeatUltra2 IN d.features THEN  Reg(d, TARGOFFSET+i, "/")  END;
		Bit(d, ULTRAENB, i, " ultra");  Bit(d, DISCDSB, i, " disc");
		KernelLog.Ln
	END;
END WriteBusConfig2;

PROCEDURE WriteConfig*;
BEGIN
	WriteBusConfig(firstBus);
	WriteBusConfig2(firstBus);
END WriteConfig;

PROCEDURE WriteLists*;
VAR  d: Bus;
BEGIN
	d := firstBus;
	SeqPause(d);
	DumpAllLists(d);
	SeqUnpause(d)
END WriteLists;

PROCEDURE FullDump*;
VAR d: Bus;
BEGIN
	d := firstBus;
	BusNameMsg(d, "Full Dump!"); KernelLog.Ln;
	KernelLog.Memory(d.base, 100H); KernelLog.Ln
END FullDump;

PROCEDURE BusState*;
BEGIN	WriteBusState(firstBus);
END BusState;

PROCEDURE ScsiState*;
BEGIN	WriteScsiState(firstBus)
END ScsiState;

PROCEDURE Test*;
VAR  d: Bus;  res: LONGINT;
BEGIN
	d := firstBus;
	KernelLog.String("Adaptec7.Test"); KernelLog.Int(aCount, 0); KernelLog.Ln;
	INC(aCount);
	SCSI.DoTestUnitReady(d, 0, 0, res);
	KernelLog.String("res = "); KernelLog.Int(res, 0); KernelLog.Ln
END Test;

PROCEDURE Scan*;
VAR  d: Bus;  res: LONGINT;  i: SHORTINT;  inq: SCSI.InquiryData;
BEGIN
	d := firstBus;
	KernelLog.String("Adaptec7.Scan"); KernelLog.Int(aCount, 0); KernelLog.Ln;
	SCSI.DoInquiry(d, SHORT(SHORT(aCount MOD 8)), 0, inq, res);
	INC(aCount);
END Scan;

PROCEDURE Stress*;
VAR  d: Bus;  i, key, code, res: LONGINT;  data: ARRAY 64*1024 OF CHAR;
	dev: Disks.DeviceTable;
BEGIN
	d := firstBus;
	Disks.GetRegistered(dev);
	i := 0;
	WHILE (i < LEN(dev)) & (dev[i].name # "SCSI0.2") DO  INC(i)  END;
	KernelLog.String("Adaptec7.Stress /  No Data"); KernelLog.Ln;
	FOR i := 0 TO 1000 DO
		SCSI.DoTestUnitReady(d, SHORT(SHORT(i MOD 8)), 0, res)
	END;
	KernelLog.String("Adaptec7.Stress /   Small Data"); KernelLog.Ln;
	FOR i := 0 TO 1000 DO
		SCSI.DoSense(d, SHORT(SHORT(i MOD 8)), 0, key, code, res)
	END;
	KernelLog.String("Adaptec7.Stress /   Medium Data"); KernelLog.Ln;
	FOR i := 0 TO 1000 DO
		dev[i].Transfer(Disks.Read, i*5, 1, data, 0, res)
	END;
	KernelLog.String("Adaptec7.Stress /   Big Data"); KernelLog.Ln;
	FOR i := 0 TO 1000 DO
		dev[i].Transfer(Disks.Read, i*5, 16, data, 0, res)
	END;
	KernelLog.String("Adaptec7.Stress /   Done"); KernelLog.Ln;
END Stress;

PROCEDURE Speed*;
VAR  dev: Disks.DeviceTable;  c, i, run, elap, size, res: LONGINT;  data: ARRAY 64*1024 OF CHAR;
	t: Kernel.MilliTimer;
BEGIN
	Disks.GetRegistered(dev);
	i := 0;
	WHILE (i < LEN(dev)) & (dev[i].name # "SCSI0.2") DO  INC(i)  END;

	dev[i].GetSize(size, res);
	KernelLog.String("Size is = "); KernelLog.Int(size, 0); KernelLog.Ln;

	FOR run := 0 TO 7 DO
		size := ASH(1, run);
		Kernel.SetTimer(t, 0);
		FOR c := 0 TO 2047 DO
			dev[i].Transfer(Disks.Read, ASH(c, run), size, data, 0, res)
		END;
		elap := Kernel.Elapsed(t);
		KernelLog.String("blkSize = "); KernelLog.Int(512*size, 0);
		KernelLog.String("  elapsed = "); KernelLog.Int(elap, 0);
		KernelLog.String(" rate (KB/s) = "); KernelLog.Int(1000*1024*size DIV elap, 0);
		KernelLog.Ln;
	END
END Speed;

PROCEDURE Register*;
BEGIN
	SCSI.RegisterBus(firstBus)
END Register;
*)
PROCEDURE KillAll*;		(*last resort when a command dies... *)
VAR  i, j: LONGINT;  d: Bus;
BEGIN
	FOR i := 0 TO 31 DO
		IF interrupt[i] # NIL THEN
			d := interrupt[i].root;
			WHILE d # NIL DO
				FOR j := 0 TO d.width-1 DO
					d.Synchronize(j, d.sync[j], Terminated)
				END;
				d := d.next
			END
		END
	END
END KillAll;

PROCEDURE Install*;
END Install;

BEGIN
	KernelLog.String("Adaptec7 - 0.41 / prk"); KernelLog.Ln;
	NEW(timer);
	Init;
	Detect;
END Adaptec7.

System.Free Adaptec7 ~		System.Free SCSI ~
System.State Adaptec7 ~

	Adaptec7.Cleanup

	Adaptec7.Detect

	Adaptec7.FullDump
	Adaptec7.WriteConfig
	Adaptec7.BusState			Adaptec7.ScsiState
	Adaptec7.WriteLists
	Adaptec7.Test
	Adaptec7.Speed
	Adaptec7.Scan
	Adaptec7.Register


	!OFSTools.Mount TEST AosFS SCSI0.2#2,R ~
	OFSTools.Mount USER AosFS SCSI0.0#6,R ~
	OFSTools.Unmount ^ ~
	OFSTools.Watch
	System.Directory USER:* ~

(*
	15.10.01	0.41	prk	wrong constant offset for DFF_THRSH discovered and corrected
	26.03.01	0.4	prk	adapted for the new Machine. Queue and SCB Buffers now anchored in Bus structure
	20.02.01	0.3	prk	own Timer removed, use Kernel.Timer instead, Watchdog commented out


	Failures:
	200:	Invalid Target
	201:	Data Size > 64KB
	202:	TranslateVirtual, num = 0 for the cmd buffer
	203:	TranslateVirtual, num invalid for the range buffer
	204:	TranslateVirtual, num = 0 for the data buffer

	Todos:
	300:	Command spans page boundary		[obsolete]
*)

(*
ToDo:
2 Disconnection
2 Ultra handling in SetSync
3 use CHAR consts instead of Bits/SETs -> use memory IO always (port IO is not needed)
4 BusCleanup: free buffers
*)