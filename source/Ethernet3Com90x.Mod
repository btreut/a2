(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Ethernet3Com90x; (** AUTHOR "rstrobl/jaco/prk/pjm/mvt/BdT"; PURPOSE "3Com 3C90X ethernet driver"; *)

(*
Aos driver for 3Com EtherLink XL ethernet adapter.
Auto-select not yet supported: configure the card using the 3Com-supplied utility.

Based on Native Oberon driver by Reto Strobl, Jaco Geldenhuys, Patrik Reali, Pieter Muller.
Reference: 3Com, "3C90x Network Interface Cards Technical Reference: 3Com EtherLink XL NICs".

Config strings:
	3C90xMedia =
		1 -> 10Base-T
		2 -> 10 Mbps AU
		4 -> 10Base2
		5 -> 100Base-TX
		6 -> 100Base-FX
		7 -> MII
		9 -> Auto (3C90xB only)
	3C90xDuplex =
		0 -> read duplex setting from EPROM
		1 -> half-duplex
		2 -> full-duplex
*)

IMPORT SYSTEM, Machine, KernelLog, Modules, Objects,
	PCI, Plugins, Network, Kernel;

CONST
	Name = "3Com90x#";
	Desc = "3Com Etherlink XL ethernet driver";

	MaxPkt = 1514;
	MTU = MaxPkt-14;

	EarlyThresh = MAX(LONGINT);

	ReceiveBuffers = 128;

	SendTimeout = 5*1000;	(* ms *)

	NewTries = 32;

		(* Media Types *)
	MediaMask = {20..23};
	Base10T = {}; (*AUI = {20};*) Base10Coax = {21, 20}; (*Base100TX = {22};*)
	(*Base100FX = {22, 20};*) MII = {22, 21}; Auto = {23};

		(* Controller flags *)
	Eprom230 = 0; InvertMIIPower = 1;

		(* models *)
	Model90x = 0; Model90xB = 1; Model90xC = 2;

TYPE
	MemRangeArray = ARRAY 2 OF Machine.Range;

	DPD = POINTER TO RECORD	(* p. 6-1 *)
		(* dummy : CHAR; may be used for padding, next field must be aligned at multiplee of 8 bytes  *)
			(* start fixed-layout *)
		nextPhysAdr: LONGINT;	(* 00H *)
		status: SET;	(* 04 *)
		frag: ARRAY 5 OF RECORD
			dataPhysAdr: LONGINT;	(* 08H, 10H, 18H, 20H, 28H *)
			dataLen: LONGINT	(* 0CH, 14H, 1CH, 24H, 2CH *)
		END;
		dst, src: ARRAY 6 OF CHAR;
		type: INTEGER;
			(* end fixed-layout *)
		physAdr: LONGINT;	(* assume physical address of dpd^ will not change *)
	END;

	UPD = POINTER TO RECORD	(* p. 7-1 *)
		 (* dummy : CHAR; may be used for padding, next field must be aligned at multiplee of 8 bytes  *)
			(* start fixed-layout *)
		nextPhysAdr: LONGINT;	(* 00H *)
		status: SET;	(* 04 *)
		frag: ARRAY 3 OF RECORD
			dataPhysAdr: LONGINT;	(* 08H, 10H, 18H *)
			dataLen: LONGINT	(* 0CH, 14H, 1CH *)
		END;
		dst, src: ARRAY 6 OF CHAR;
		type: INTEGER;
			(* end fixed-layout *)
		physAdr: LONGINT;	(* assume physical address of upd^ will not change *)
		buffer: Network.Buffer;
		next: UPD;
	END;

VAR
	installed: LONGINT;	(* number of installed devices *)
	NdnTxReclaimError, NdnTxStatusOverflow, NdnMaxCollisions, NdnTxUnderrun, NdnTxJabber, NnewRetry,
		NspuriousComplete, NupOverrun, NupRuntFrame, NupAlignmentError, NupCrcError, NupOversizedFrame,
		NupOverflow, NbadSize, Ninterrupt, NintHostError, NintTxComplete, NintRxEarly, NintRequested,
		NintUpdateStats, NintLinkEvent, NintDnComplete, NintUpComplete, NstatCarrierLost,
		NstatSqeErrors, NstatMultipleCollisions, NstatSingleCollisions, NstatLateCollisions, NstatRxOverruns,
		NstatFramesXmittedOk, NstatFramesRcvdOk, NstatFramesDeferred, NstatBytesRcvdOk,
		NstatBytesXmittedOk, NstatBadSSD, NupCompleteLoops, NsendTimeouts: LONGINT;

TYPE
	Timer = OBJECT (Kernel.Timer)
		VAR
			ms: LONGINT;
			c: Controller;
			quit: BOOLEAN;

		PROCEDURE &Init2*(c: Controller);
		BEGIN
			SELF.c := c; SELF.quit := FALSE; SELF.ms := 1;
			Init
		END Init2;

	BEGIN {ACTIVE}
		WHILE ~quit DO
			c.HandleInterrupt();
			Sleep(ms);
		END
	END Timer;

	Controller* = OBJECT
		VAR
			base, irq*: LONGINT;
			dev: LinkDevice;
			flags: SET;
			model: LONGINT;
			media: SET;
			dpd: DPD;
			upd: UPD;

			bus, pdev, fct: LONGINT;
			interrupted: BOOLEAN;
			timer: Timer;

		PROCEDURE HandleInterrupt;
		VAR type, len: LONGINT; status: SET; int: INTEGER; ch: CHAR; buf: Network.Buffer;
		BEGIN
			interrupted := TRUE;
			Machine.AtomicInc(Ninterrupt);
			Machine.Portin16(base+0EH, SYSTEM.VAL(INTEGER, status));	(* IntStatus (p. 8-3) *)
			IF 1 IN status THEN	(* hostError *)
				Machine.AtomicInc(NintHostError)
				(* to do: reset *)
			END;
			IF 2 IN status THEN	(* txComplete *)
				Machine.AtomicInc(NintTxComplete);
				Machine.Portout8(base+1BH, 0X)	(* TxStatus (p. 6-23) *)
			END;
			IF 5 IN status THEN	(* rxEarly *)
				Machine.AtomicInc(NintRxEarly)
			END;
			IF 6 IN status THEN	(* intRequested (or Countdown expiry) *)
				Machine.AtomicInc(NintRequested)
			END;
			IF 7 IN status THEN	(* updateStats *)
				Machine.AtomicInc(NintUpdateStats);
				SetWindow(base, 6);
				Machine.Portin8(base+0, ch); Machine.AtomicAdd(NstatCarrierLost, ORD(ch));
				Machine.Portin8(base+1, ch); Machine.AtomicAdd(NstatSqeErrors, ORD(ch));
				Machine.Portin8(base+2, ch); Machine.AtomicAdd(NstatMultipleCollisions, ORD(ch));
				Machine.Portin8(base+3, ch); Machine.AtomicAdd(NstatSingleCollisions, ORD(ch));
				Machine.Portin8(base+4, ch); Machine.AtomicAdd(NstatLateCollisions, ORD(ch));
				Machine.Portin8(base+5, ch); Machine.AtomicAdd(NstatRxOverruns, ORD(ch));
				Machine.Portin8(base+6, ch); Machine.AtomicAdd(NstatFramesXmittedOk, ORD(ch));
				Machine.Portin8(base+7, ch); Machine.AtomicAdd(NstatFramesRcvdOk, ORD(ch));
				Machine.Portin8(base+9, ch);	(* UpperFramesOk *)
				Machine.AtomicAdd(NstatFramesXmittedOk, ORD(ch) DIV 16 MOD 16 * 100H);
				Machine.AtomicAdd(NstatFramesRcvdOk, ORD(ch) MOD 16 * 100H);
				Machine.Portin8(base+8, ch); Machine.AtomicAdd(NstatFramesDeferred, ORD(ch));
				Machine.Portin16(base+0AH, int); Machine.AtomicAdd(NstatBytesRcvdOk, LONG(int) MOD 10000H);
				Machine.Portin16(base+0CH, int); Machine.AtomicAdd(NstatBytesXmittedOk, LONG(int) MOD 10000H);
				SetWindow(base, 4);
				Machine.Portin8(base+0CH, ch); Machine.AtomicAdd(NstatBadSSD, ORD(ch));
				Machine.Portin8(base+0DH, ch);	(* UpperBytesOk *)
				Machine.AtomicAdd(NstatBytesXmittedOk, ORD(ch) DIV 16 MOD 16 * 10000H);
				Machine.AtomicAdd(NstatBytesRcvdOk, ORD(ch) MOD 16 * 10000H)
					(* now back in window 4 *)
			END;
			IF 8 IN status THEN	(* linkEvent *)
				Machine.AtomicInc(NintLinkEvent)
				(* to do: read AutoNegExpansion via MII *)
			END;
			IF 9 IN status THEN
				Machine.AtomicInc(NintDnComplete)
			END;
			IF 10 IN status THEN	(* upComplete *)
				Machine.AtomicInc(NintUpComplete);
				IF 15 IN upd.status THEN	(* upComplete (p. 7-3) *)
					REPEAT
						Machine.AtomicInc(NupCompleteLoops);
						IF upd.status * {14,16..20,24} = {} THEN	(* no error *)
							len := SYSTEM.VAL(LONGINT, upd.status * {0..12}) - 14;
							IF (len >= 60-14) & (len <= MTU) THEN
								buf := upd.buffer;
								IF buf # NIL THEN
									(* get buffer from UPD for upcall *)
									buf := upd.buffer;
									type := LONG(ROT(upd.type, 8)) MOD 10000H;
									buf.ofs := 0;
									buf.len := len;
									buf.calcChecksum := {};
									buf.src := SYSTEM.VAL(Network.LinkAdr, upd.src);
									dev.QueueBuffer(buf, type);
								ELSE
									Machine.AtomicInc(NupOverflow); (* no more upcall buffers available *)
								END;
								(* get new empty buffer for UPD *)
								BufferToUPD(Network.GetNewBuffer(), upd);
							ELSE
								Machine.AtomicInc(NbadSize)
							END
						ELSE
							ASSERT((14 IN upd.status) & (upd.status * {16..20,24} # {}));
							IF 16 IN upd.status THEN Machine.AtomicInc(NupOverrun) END;
							IF 17 IN upd.status THEN Machine.AtomicInc(NupRuntFrame) END;
							IF 18 IN upd.status THEN Machine.AtomicInc(NupAlignmentError) END;
							IF 19 IN upd.status THEN Machine.AtomicInc(NupCrcError) END;
							IF 20 IN upd.status THEN Machine.AtomicInc(NupOversizedFrame) END;
							IF 24 IN upd.status THEN Machine.AtomicInc(NupOverflow) END
						END;
						upd.status := {}; upd := upd.next;
						Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 3001H))	(* UpUnstall (p. 10-8) *)
					UNTIL ~(15 IN upd.status)
				ELSE
					Machine.AtomicInc(NspuriousComplete)
				END
			END;
			IF status * {0, 5, 6, 9, 10} # {} THEN
				Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, SHORT(6800H +
						SYSTEM.VAL(LONGINT, status * {0, 5, 6, 9, 10}))))	(* AcknowledgeInterrupt 10 (p. 10-9) *)
			END
		END HandleInterrupt;

		(* Initialize the controller. *)

		PROCEDURE &Init*(dev: LinkDevice; base, irq, model: LONGINT; flags, media: SET);
		VAR res, i: LONGINT;
		BEGIN
			SELF.interrupted := FALSE;
			SELF.base := base; SELF.irq := irq;  SELF.dev := dev; SELF.model := model; SELF.media := media;
			SELF.flags := flags;
			dev.ctrl := SELF;
			InitDPD(dpd);
			InitUPD(upd);
			InitAddress(dev);	(* sets dev.local and dev.broadcast *)
			SYSTEM.MOVE(ADDRESSOF(dev.local[0]), ADDRESSOF(dpd.src[0]), 6);
			InitInterface(SELF);
			InitRegisters(SELF);
			IF (irq >= 1) & (irq <= 15) THEN
				KernelLog.Enter; KernelLog.String("Install Handler IRQ = "); KernelLog.Hex(irq, -3); KernelLog.Exit;
				Objects.InstallHandler(SELF.HandleInterrupt, Machine.IRQ0+irq)
			END;
			Network.registry.Add(dev, res);
			ASSERT(res = Plugins.Ok);
			INC(installed);
			Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 6000H));	(* RequestInterrupt (p. 10-9) *)
			i := 0;
			WHILE (i < 100) & ~interrupted DO
				Objects.Yield;
				INC(i)
			END;
			IF ~interrupted THEN	(* interrupt handler not called, install timer *)
				KernelLog.Enter; KernelLog.String("Install Timer"); KernelLog.Exit;
				NEW(timer, SELF)
			ELSE
				KernelLog.Enter; KernelLog.String("No need for Timer"); KernelLog.Exit
			END
		END Init;

		PROCEDURE Finalize;
		VAR item: UPD;
		BEGIN {EXCLUSIVE}
			IF timer # NIL THEN
				KernelLog.Enter; KernelLog.String("Remove Timer"); KernelLog.Exit;
				timer.quit := TRUE
			END;
			ResetTx(base);
			ResetRx(SELF, FALSE);
			Objects.RemoveHandler(HandleInterrupt, Machine.IRQ0+irq);
			Network.registry.Remove(dev);
			dev.ctrl := NIL; dev := NIL;
			(* return buffers attached to UPD *)
			item := upd;
			REPEAT
				Network.ReturnBuffer(item.buffer);
				item.buffer := NIL; (* in case of concurrent interrupt *)
				item := item.next;
			UNTIL item = upd;
		END Finalize;

	END Controller;

TYPE
	LinkDevice* = OBJECT (Network.LinkDevice)
		VAR
			hdr: ARRAY Network.MaxPacketSize OF CHAR; (* internal buffer for eventual header copy in DoSend *)
			ctrl*: Controller;

		PROCEDURE DoSend(dst: Network.LinkAdr; type: LONGINT; CONST l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT);
		VAR
			dpd: DPD;
			t: Kernel.MilliTimer;
			h3n, h4n, dn, hn, hlen, len, base, i: LONGINT;
			h3phys, h4phys, dphys, hphys: MemRangeArray;

			PROCEDURE PutToDPD(n: LONGINT; VAR phys: MemRangeArray);
			VAR j: LONGINT;
			BEGIN
				FOR j := 0 TO n-1 DO
					dpd.frag[i].dataPhysAdr := Machine.Ensure32BitAddress (phys[j].adr);
					dpd.frag[i].dataLen := Machine.Ensure32BitAddress (phys[j].size);
					INC(i);
				END;
			END PutToDPD;

		BEGIN {EXCLUSIVE}
			base := ctrl.base; dpd := ctrl.dpd;

			(* set up ethernet header *)
			SYSTEM.MOVE(ADDRESSOF(dst[0]), ADDRESSOF(dpd.dst[0]), 6);
			dpd.type := ROT(SHORT(type), 8);

			(* set up the download *)
			IssueCommand(base, 3002H);	(* DnStall (p. 10-4) *)
			CheckTransmission(base);

			(* set up the DPD *)
			Machine.TranslateVirtual(ADDRESSOF(l3hdr[0]), h3len, h3n, h3phys);
			Machine.TranslateVirtual(ADDRESSOF(l4hdr[0]), h4len, h4n, h4phys);
			Machine.TranslateVirtual(ADDRESSOF(data[dofs]), dlen, dn, dphys);

			(* max. 2 fragments allowed (all packets smaller than one 4K page) *)
			ASSERT(h3n <= 2);
			ASSERT(h4n <= 2);
			ASSERT(dn <= 2);
			i := 1; (* start at fragment index 1 in DPD *)

			IF h3n + h4n + dn > 4 THEN
				(* max. number of fragments exceeded - occurs very rarely! only handled to avoid eventual packet loss *)
				(* copy l3hdr and l4hdr to hdr to reduce fragments *)
				Network.Copy(l3hdr, hdr, 0, 0, h3len);
				Network.Copy(l4hdr, hdr, 0, h3len, h4len);
				hlen := h3len + h4len;
				Machine.TranslateVirtual(ADDRESSOF(hdr[0]), hlen, hn, hphys);
				PutToDPD(hn, hphys);
			ELSE
				(* this is the normal case *)
				PutToDPD(h3n, h3phys);
				PutToDPD(h4n, h4phys);
			END;
			(* put data *)
			PutToDPD(dn, dphys);
			(* set "end" marker *)
			INC(dpd.frag[i-1].dataLen, LONGINT(80000000H));

			len := h3len + h4len + len +14;	(* now len is total packet length including headers *)
			ASSERT((len >= 14) & (len <= MaxPkt));	(* packet size *)
			dpd.status := SYSTEM.VAL(SET, len);
			Machine.Portout32(base+24H, dpd.physAdr);	(* DnListPtr (p. 6-17) *)
			Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 3003H));	(* DnUnstall (p. 10-5) *)

			(* wait for download to finish, so that buffer is free afterwards *)
			Kernel.SetTimer(t, SendTimeout);
			REPEAT
				Machine.Portin32(base+24H, i)	(* downloading finished *)
			UNTIL (i = 0) OR Kernel.Expired(t);
			IF i # 0 THEN Machine.AtomicInc(NsendTimeouts) END;
			INC(sendCount)
		END DoSend;

		PROCEDURE Finalize(connected: BOOLEAN);
		BEGIN
			ctrl.Finalize;
			Finalize^(connected);
		END Finalize;

	END LinkDevice;

(* Change to the specified register window. *)

PROCEDURE SetWindow(base, window: LONGINT);
BEGIN
	ASSERT((0 <= window) & (window <= 7));
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, SHORT(800H + window)))
END SetWindow;

(* Read a 16-bit value from the EEPROM (chapter 5). *)

PROCEDURE ReadConfig(base, reg: LONGINT; flags: SET; VAR word: INTEGER);
VAR x: INTEGER;
BEGIN
	ASSERT((0 <= reg) & (reg < 64));
	SetWindow(base, 0);
	IF Eprom230 IN flags THEN INC(reg, 230H) ELSE INC(reg, 80H) END;
	Machine.Portout16(base+0AH, SYSTEM.VAL(INTEGER, SHORT((*80H + *)reg)));	(* Read Register - 162 us *)
	REPEAT
		Machine.Portin16(base+0AH, x)
	UNTIL ~(15 IN SYSTEM.VAL(SET, LONG(x)));	(*  Wait till ~eepromBusy *)
	Machine.Portin16(base+0CH, word)
END ReadConfig;

(* Initialize the local address. *)

PROCEDURE InitAddress(d: LinkDevice);
VAR base, i: LONGINT; flags: SET; word: ARRAY 3 OF INTEGER;
BEGIN
	base := d.ctrl.base;
	flags := d.ctrl.flags;
	ReadConfig(base, 0AH, flags, word[0]);	(* OEM Node Address / word 0 *)
	ReadConfig(base, 0BH, flags, word[1]);	(* OEM Node Address / word 1 *)
	ReadConfig(base, 0CH, flags, word[2]);	(* OEM Node Address / word 2 *)
	SetWindow(base, 2);
	FOR i := 0 TO 2 DO
		word[i] := ROT(word[i], 8);
		d.local[2*i] := CHR(word[i] MOD 100H);
		d.local[2*i+1] := CHR(word[i] DIV 100H MOD 100H);
		Machine.Portout16(base+2*i, word[i]);	(* StationAddress *)
		Machine.Portout16(base+6+2*i, SYSTEM.VAL(INTEGER, 0))	(* StationMask *)
	END;
	FOR i := 0 TO 5 DO d.broadcast[i] := 0FFX END
END InitAddress;

(* Get the specified setting for the NIC currently being initialized (indexed by "installed"). *)

PROCEDURE GetSetting(s: ARRAY OF CHAR): LONGINT;
VAR i: LONGINT; name, val: ARRAY 32 OF CHAR;
BEGIN
	i := 0; WHILE s[i] # 0X DO name[i] := s[i]; INC(i) END;
	name[i] := CHR(ORD("0") + installed); name[i+1] := 0X;
	Machine.GetConfig(name, val);
	IF val[0] = 0X THEN	(* specified setting not found, look for generic one *)
		name[i] := 0X; Machine.GetConfig(name, val)
	END;
	i := 0;
	RETURN Machine.StrToInt(i, val)
END GetSetting;

(* Initialize the communication interface. *)

PROCEDURE InitInterface(ctrl: Controller);
VAR config: SET; base, media: LONGINT;
BEGIN
	base := ctrl.base;
	SetWindow(base, 3);
	Machine.Portin32(base, SYSTEM.VAL (LONGINT, config));	(* InternalConfig (p. 4-9) *)
	media := GetSetting("3C90xMedia");
	IF media # 0 THEN
		ASSERT((media >= 1) & (media <= 9));
		ctrl.media := SYSTEM.VAL(SET, LSH(media-1, 20)) * MediaMask;
		Machine.Portout32(base, SYSTEM.VAL (LONGINT, config - MediaMask + ctrl.media))
	ELSIF ~(24 IN config) THEN
		ctrl.media := config * MediaMask	(* autoselect off, no changes needed *)
	ELSE
		media := SYSTEM.VAL(LONGINT, ctrl.media);
		Machine.Portout32(base, SYSTEM.VAL (LONGINT, config - MediaMask + ctrl.media));
		KernelLog.Enter; KernelLog.String(ctrl.dev.name); KernelLog.String(" auto-selection not supported"); KernelLog.Exit;
		(*HALT(3801)*)	(* auto-selection not yet supported *)
	END
	;KernelLog.Enter; KernelLog.String("Media = "); KernelLog.Hex(media, 0); KernelLog.Exit;
END InitInterface;

(* Issue a command and wait for completion. *)

PROCEDURE IssueCommand(base, cmd: LONGINT);
VAR word: INTEGER;
BEGIN
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, SHORT(cmd)));
	REPEAT
		Machine.Portin16(base+0EH, word)
	UNTIL ~(12 IN SYSTEM.VAL(SET, LONG(word)))
END IssueCommand;

PROCEDURE ResetTx(base: LONGINT);
BEGIN
	IssueCommand(base, 5800H);	(* TxReset (p. 10-4) *)
	Machine.Portout32(base+24H, SYSTEM.VAL(LONGINT, 0))	(* DnListPtr (p. 6-17) *)
END ResetTx;

PROCEDURE ResetRx(ctrl: Controller; setThresh: BOOLEAN);
VAR base: LONGINT;
BEGIN
	base := ctrl.base;
	IssueCommand(base, 2800H);	(* RxReset (p. 10-3) *)
	IF setThresh THEN
		IF EarlyThresh DIV 4 > 7FFH THEN
			Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 8FFFH));	(* SetRxEarlyThresh (p. 10-7) *)
			Machine.Portout32(base+20H, SYSTEM.VAL(LONGINT, 0H))	(* DmaCtrl (p. 6-14) *)
		ELSE
			Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 8800H + EarlyThresh DIV 4));
			Machine.Portout32(base+20H, SYSTEM.VAL(LONGINT, 20H))	(* DmaCtrl (p. 6-14) - upRxEarlyEnable *)
		END
	END;
	Machine.Portout32(base+38H, ctrl.upd.physAdr);	(* UpListPtr (p. 7-14) *)
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 8007H))	(* SetRxFilter (p. 10-8) - Individual, Multicast, Broadcast *)
END ResetRx;

(* Check the transmitter and reset it if required. *)

PROCEDURE CheckTransmission(base: LONGINT);
VAR status: SET; enable, reset: BOOLEAN; ch: CHAR;
BEGIN
	enable := FALSE; reset := FALSE;
	LOOP
		Machine.Portin8(base+1BH, ch);	(* TxStatus (p. 6-23) *)
		status := SYSTEM.VAL(SET, LONG(ORD(ch)));
		IF ~(7 IN status) THEN EXIT END;	(* txComplete *)
		IF 1 IN status THEN Machine.AtomicInc(NdnTxReclaimError) END;
		IF 2 IN status THEN Machine.AtomicInc(NdnTxStatusOverflow); enable := TRUE END;
		IF 3 IN status THEN Machine.AtomicInc(NdnMaxCollisions); enable := TRUE END;
		IF 4 IN status THEN Machine.AtomicInc(NdnTxUnderrun); reset := TRUE END;
		IF 5 IN status THEN Machine.AtomicInc(NdnTxJabber); reset := TRUE END;
		Machine.Portout8(base+1BH, ch)	(* advance *)
	END;
	IF reset THEN IssueCommand(base, 5800H); enable := TRUE END;	(* TxReset (p. 10-4) *)
	IF enable THEN Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 4800H)) END	(* TxEnable (p. 10-6) *)
END CheckTransmission;

(* Allocate a DPD.  Assume the physical address of the record will not change (beware copying GC). *)

PROCEDURE InitDPD(VAR dpd: DPD);
VAR i, n: LONGINT; phys: MemRangeArray;
BEGIN
	i := 0;
	LOOP
		NEW(dpd);
		Machine.TranslateVirtual(ADDRESSOF(dpd.nextPhysAdr), SIZEOF(DPD), n, phys);
		IF n = 1 THEN EXIT END;	(* contiguous *)
		INC(i); Machine.AtomicInc(NnewRetry);
		IF i = NewTries THEN HALT(3802) END	(* can not allocate contiguous DPD *)
	END;
	ASSERT(phys[0].size = SIZEOF(DPD));
	dpd.physAdr := Machine.Ensure32BitAddress (phys[0].adr);
	ASSERT(dpd.physAdr MOD 8 = 0);	(* alignment constraint (p. 6-3) *)
	dpd.nextPhysAdr := 0;
		(* entry 0 always points to ethernet header *)
	dpd.frag[0].dataPhysAdr := Machine.Ensure32BitAddress ((ADDRESSOF(dpd.dst[0])-ADDRESSOF(dpd.nextPhysAdr)) + dpd.physAdr);
	dpd.frag[0].dataLen := 14	(* ethernet header *)
END InitDPD;

(* Allocate the UPD ring. *)

PROCEDURE InitUPD(VAR upd: UPD);
VAR i, j, n: LONGINT; head, tail: UPD; phys: MemRangeArray;
BEGIN
	head := NIL; tail := NIL;
	FOR j := 1 TO ReceiveBuffers DO
		i := 0;
		LOOP
			NEW(upd);
			Machine.TranslateVirtual(ADDRESSOF(upd.nextPhysAdr), SIZEOF(UPD), n, phys);
			IF n = 1 THEN EXIT END;	(* contiguous *)
			INC(i); Machine.AtomicInc(NnewRetry);
			IF i = NewTries THEN HALT(3803) END	(* can not allocate contiguous UPD *)
		END;
		ASSERT(phys[0].size = SIZEOF(UPD));
		upd.physAdr := Machine.Ensure32BitAddress (phys[0].adr);
		ASSERT(upd.physAdr MOD 8 = 0);	(* alignment constraint (p. 7-2) *)
		upd.status := {};
			(* entry 0 always points to ethernet header *)
		upd.frag[0].dataPhysAdr := Machine.Ensure32BitAddress ((ADDRESSOF(upd.dst[0])-ADDRESSOF(upd.nextPhysAdr)) + upd.physAdr);
		upd.frag[0].dataLen := 14;	(* ethernet header *)

		(* get new empty buffer and attach it to the UPD *)
		BufferToUPD(Network.GetNewBuffer(), upd);

			(* link in *)
		IF head # NIL THEN
			upd.next := head; upd.nextPhysAdr := head.physAdr
		ELSE
			upd.next := NIL; upd.nextPhysAdr := 0; tail := upd
		END;
		head := upd
	END;
	tail.next := head; tail.nextPhysAdr := head.physAdr
END InitUPD;

(* Set buffer as DMA receive buffer in UPD. *)

PROCEDURE BufferToUPD(buffer: Network.Buffer; upd: UPD);
VAR
	n, i: LONGINT;
	phys: MemRangeArray;
BEGIN
	ASSERT(upd # NIL);
	IF buffer # NIL THEN
		(* entry 1-2 points to data *)
		Machine.TranslateVirtual(ADDRESSOF(buffer.data[0]), LEN(buffer.data), n, phys);
		ASSERT(n <= 2);
		FOR i := 1 TO n DO
			upd.frag[i].dataPhysAdr := Machine.Ensure32BitAddress (phys[i-1].adr); upd.frag[i].dataLen := Machine.Ensure32BitAddress (phys[i-1].size)
		END;
		INC(upd.frag[n].dataLen, LONGINT(80000000H)); (* end of buffer marker *)
	ELSE
		(* no buffer available at the moment. only header can be received. *)
		upd.frag[0].dataLen := 14; (* ethernet header *)
		INC(upd.frag[0].dataLen, LONGINT(80000000H)); (* end of buffer marker *)
	END;
	upd.buffer := buffer; (* attach buffer reference *)
END BufferToUPD;

(* Initialize the registers. *)

PROCEDURE InitRegisters(ctrl: Controller);
VAR base, duplex, i: LONGINT; word: INTEGER; full: BOOLEAN; ch: CHAR; flags: SET;
BEGIN
	base := ctrl.base;
	flags := ctrl.flags;
	IF InvertMIIPower IN flags THEN
		SetWindow(base, 2);
		Machine.Portin16(base+0CH, word);
		word := SHORT(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(word)) + {14}));
		Machine.Portout16(base+0CH, word);
		KernelLog.Enter; KernelLog.String("Invert MII Power "); KernelLog.Hex(word, 0); KernelLog.Exit;
	END;
	IF ctrl.media = Base10Coax THEN
		Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 1000H))	(* EnableDcConverter (p. 10-10) *)
	ELSE
		Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 0B800H))	(* DisableDcConverter (p. 10-10) *)
	END;
	duplex := GetSetting("3C90xDuplex");
	IF duplex = 0 THEN
		ReadConfig(base, 0DH, flags, word);	(* Software Information (p. 5-5) *)
		full := (15 IN SYSTEM.VAL(SET, LONG(word)))
	ELSE
		full := (duplex = 2)
	END;
	SetWindow(base, 3);
	IF full THEN
		KernelLog.Enter; KernelLog.String(ctrl.dev.name); KernelLog.String(" full-duplex"); KernelLog.Exit;
		Machine.Portout16(base+6, SYSTEM.VAL(INTEGER, 20H))	(* MacControl (p. 12-2) *)
	ELSE	(* half-duplex *)
		KernelLog.Enter; KernelLog.String(ctrl.dev.name); KernelLog.String(" half-duplex"); KernelLog.Exit;
		Machine.Portout16(base+6, SYSTEM.VAL(INTEGER, 0))
	END;
	ResetTx(base);
	ResetRx(ctrl, TRUE);
	SetWindow(base, 7);	(* operating window *)
	IF ctrl.model = Model90x THEN
		Machine.Portout8(base+2FH, CHR((MaxPkt+255) DIV 256))	(* TxFreeThresh (p. 6-20) *)
	END;
		(* clear all interrupts & indications *)
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 7FF6H));	(* SetIndicationEnable (p. 10-9) - all *)
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, SYSTEM.VAL(LONGINT, {1, 6, 7, 10}) + 7000H));	(* SetInterruptEnable (p. 10-10, 8-4) *)
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 6F69H));	(* AcknowledgeInterrupt (p. 10-9) - all *)
		(* clear all statistics *)
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 0B000H));	(* StatisticsDisable (p. 10-11) *)
	SetWindow(base, 5);
	Machine.Portin16(base+0AH, word);
	KernelLog.Enter; KernelLog.String("IntEnable = "); KernelLog.Hex(word, 4); KernelLog.Exit;
	SetWindow(base, 6);
	FOR i := 0 TO 9 DO Machine.Portin8(base+i, ch) END;
	Machine.Portin16(base+0AH, word);
	Machine.Portin16(base+0CH, word);
	SetWindow(base, 4);
(*
	Machine.Portin8(base+0AH, word);
	Machine.Portout8(base+0AH, SYSTEM.VAL(INTEGER, SHORT(SYSTEM.VAL(LONGINT,
			SYSTEM.VAL(SET, LONG(word)) - {7}))));	(* MediaStatus: disable linkBeatEnable *)
*)
	Machine.Portin8(base+0CH, ch);
	Machine.Portin8(base+0DH, ch);
	Machine.Portin16(base+6, word);	(* NetworkDiagnostic (p. 9-8) *)
	Machine.Portout16(base+6, SYSTEM.VAL(INTEGER, SHORT(SYSTEM.VAL(LONGINT,
			SYSTEM.VAL(SET, LONG(word)) + {6}))));	(* upperBytesEnable *)
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 0A800H));	(* StatisticsEnable (p. 10-11) *)
		(* start the NIC *)
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 2000H));	(* RxEnable (p. 10-6) *)
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 4800H));	(* TxEnable (p. 10-6) *)
	Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 3001H))	(* UpUnstall (p. 10-8) *)
END InitRegisters;

(* Scan the PCI bus for the specified card. *)

PROCEDURE ScanPCI(vendor, device, model: LONGINT; flags, media: SET);
VAR index, bus, dev, fct, res, base, irq, i: LONGINT; d: LinkDevice; c: Controller; name: Plugins.Name;
BEGIN
	index := 0;
	WHILE (PCI.FindPCIDevice(device, vendor, index, bus, dev, fct) = PCI.Done) & (installed < 10) DO
		res := PCI.ReadConfigDword(bus, dev, fct, PCI.Adr0Reg, base); ASSERT(res = PCI.Done);
		ASSERT(ODD(base)); DEC(base);	(* I/O mapped *)
		res := PCI.ReadConfigByte(bus, dev, fct, PCI.IntlReg, irq); ASSERT(res = PCI.Done);
(*
		IF irq = 11 THEN
			res := PCI.WriteConfigByte(bus, dev, fct, PCI.IntlReg, 5); ASSERT(res = PCI.Done);
			res := PCI.ReadConfigByte(bus, dev, fct, PCI.IntlReg, irq); ASSERT(res = PCI.Done);
		END;
*)
		NEW(d, Network.TypeEthernet, MTU, 6);
		name := Name;
		i := 0; WHILE name[i] # 0X DO INC(i) END;
		name[i] := CHR(ORD("0") + installed);
		name[i+1] := 0X;
		d.SetName(name);
		d.desc := Desc;
		NEW(c, d, base, irq, model, flags, media);	(* increments "installed" when successful *)
		c.bus := bus; c.pdev := dev; c.fct := fct;
		INC(index)
	END
END ScanPCI;

(** Install a driver object for every NIC found. *)

PROCEDURE Install*;
BEGIN {EXCLUSIVE}
	IF installed = 0 THEN
		ScanPCI(10B7H, 9200H, Model90xC, {}, Auto);
		ScanPCI(10B7H, 6055H, Model90xB, {Eprom230, InvertMIIPower}, MII);	(* check if C model *)
		ScanPCI(10B7H, 9055H, Model90xB, {}, Auto);
		ScanPCI(10B7H, 9056H, Model90xB, {}, MII);
		ScanPCI(10B7H, 9004H, Model90xB, {}, Auto);
		ScanPCI(10B7H, 9005H, Model90xB, {}, Auto);
		ScanPCI(10B7H, 9050H, Model90x, {}, MII);
		ScanPCI(10B7H, 9000H, Model90x, {}, Base10T);
		ScanPCI(10B7H, 9001H, Model90x, {}, Base10T)
	END;
END Install;

(** Remove all device driver objects. *)

PROCEDURE Remove*;
VAR table: Plugins.Table; i: LONGINT;
BEGIN {EXCLUSIVE}
	Network.registry.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			IF table[i] IS LinkDevice THEN table[i](LinkDevice).Finalize(TRUE) END
		END
	END;
	installed := 0;
END Remove;

(* Request an interrupt from every controller. *)

PROCEDURE Kick*;
VAR i, base: LONGINT; table: Plugins.Table;
BEGIN
	Network.registry.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			IF table[i] IS LinkDevice THEN
				base := table[i](LinkDevice).ctrl.base;
				KernelLog.Enter; KernelLog.String(table[i].name); KernelLog.Exit;
				Machine.Portout16(base+0EH, SYSTEM.VAL(INTEGER, 6000H));	(* RequestInterrupt (p. 10-9) *)
			END
		END
	END;
END Kick;

(* Dump all registers - may have side effects that influence the device's normal operation *)

PROCEDURE Dump*;
VAR i, base, win: LONGINT; int: INTEGER; table: Plugins.Table;

	PROCEDURE Byte(reg: ARRAY OF CHAR; ofs: LONGINT);
	VAR x: CHAR;
	BEGIN
		KernelLog.String(reg); KernelLog.Char("=");
		Machine.Portin8(base+ofs, x);
		KernelLog.Hex(ORD(x), -2); KernelLog.Char(" ")
	END Byte;

	PROCEDURE Word(reg: ARRAY OF CHAR; ofs: LONGINT);
	VAR x: INTEGER;
	BEGIN
		KernelLog.String(reg); KernelLog.Char("=");
		Machine.Portin16(base+ofs, x);
		KernelLog.Hex(LONG(x) MOD 10000H, 8); KernelLog.Char(" ")
	END Word;

	PROCEDURE DWord(reg: ARRAY OF CHAR; ofs: LONGINT);
	VAR x: LONGINT;
	BEGIN
		KernelLog.String(reg); KernelLog.Char("=");
		Machine.Portin32(base+ofs, x);
		KernelLog.Hex(x, 8); KernelLog.Char(" ")
	END DWord;

	PROCEDURE PCIWord(reg: ARRAY OF CHAR; ofs: LONGINT);
	VAR x, res: LONGINT; ctrl: Controller;
	BEGIN
		ctrl := table[i](LinkDevice).ctrl;
		KernelLog.String(reg); KernelLog.Char("=");
		res := PCI.ReadConfigWord(ctrl.bus, ctrl.pdev, ctrl.fct, ofs, x);
		KernelLog.Hex(x MOD 10000H, 8); KernelLog.Char(" ")
	END PCIWord;


BEGIN
	Network.registry.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			IF table[i] IS LinkDevice THEN
				base := table[i](LinkDevice).ctrl.base;
				KernelLog.Enter;
				KernelLog.String(table[i].name); KernelLog.Char(" ");
					(* current window *)
				Machine.Portin16(base+0EH, int); win := ASH(int, -13) MOD 8;
				KernelLog.String("Window="); KernelLog.Int(win, 1); KernelLog.Char(" ");
					(* assume 3C90xB *)
				Byte("TxPktId", 18H); Byte("Timer", 1AH); Byte("TxStatus", 1BH);
				(*Word("IntStatusAuto", 1EH);*)	(* reading this would clear InterruptEnable (p. 8-5) *)
				DWord("DmaCtrl", 20H);
				DWord("DnListPtr", 24H); Byte("DnBurstThresh", 2AH);
				Byte("DnPriorityThresh", 2CH); Byte("DnPoll", 2DH);
				DWord("UpPktStatus", 30H); Word("FreeTimer", 34H);
				Word("Countdown", 36H); DWord("UpListPtr", 38H);
				Byte("UpPriorityThresh", 3CH); Byte("UpPoll", 3DH);
				Byte("UpBurstThresh", 3EH); DWord("RealTimeCnt", 40H);
				Word("DnMaxBurst", 78H); Word("UpMaxBurst", 7AH);
					(* output windows *)
				SetWindow(base, 0);
				DWord("0.BiosRomAddr", 4); Byte("0.BiosRomData", 8);
				Word("0.EepromCommand", 0AH); Word("0.EepromData", 0CH);
				Word("0.IntStatus", 0EH);
				SetWindow(base, 1);
				Word("1.IntStatus", 0EH);
				SetWindow(base, 2);
				Word("2.StationAddress-0", 0); Word("2.StationAddress-2", 2); Word("2.StationAddress-4", 4);
				Word("2.StationMask-0", 6); Word("2.StationMask-2", 8); Word("2.StationMask-4", 0AH);
				Word("2.ResetOptions", 0CH); Word("2.IntStatus", 0EH);
				SetWindow(base, 3);
				DWord("3.InternalConfig", 0); Word("3.MaxPktSize", 4);
				Word("3.MacControl", 6); Word("3.MediaOptions", 8);
				Word("3.RxFree", 0AH); Word("3.TxFree", 0CH);
				Word("3.IntStatus", 0EH);
				SetWindow(base, 4);
				Word("4.VcoDiagnostic", 2); Word("4.FifoDiagnostic", 4);
				Word("4.NetworkDiagnostic", 6); Word("4.PhysicalMgmt", 8);
				Word("4.MediaStatus", 0AH); Byte("4.BadSSD", 0CH);
				Byte("4.UpperBytesOk", 0DH); Word("4.IntStatus", 0EH);
				SetWindow(base, 5);
				Word("5.TxStartThresh", 0); Word("5.RxEarlyThresh", 6);
				Byte("5.RxFilter", 8); Byte("5.TxReclaimThresh", 9);
				Word("5.InterruptEnable", 0AH); Word("5.IndicationEnable", 0CH);
				Word("5.IntStatus", 0EH);
				SetWindow(base, 6);
				Byte("6.CarrierLost", 0); Byte("6.SqeErrors", 1);
				Byte("6.MultipleCollisions", 2); Byte("6.SingleCollisions", 3);
				Byte("6.LateCollisions", 4); Byte("6.RxOverruns", 5);
				Byte("6.FramesXmittedOk", 6); Byte("6.FramesRcvdOk", 7);
				Byte("6.FramesDeferred", 8); Byte("6.UpperFramesOk", 9);
				Word("6.BytesRcvdOk", 0AH); Word("6.BytesXmittedOk", 0CH);
				Word("6.IntStatus", 0EH);
				SetWindow(base, 7);
				Word("7.VlanMask", 0); Word("7.VlanEtherType", 4);
				Word("7.PowerMgmtEvent", 0CH); Word("7.IntStatus", 0EH);
				SetWindow(base, win);
				Byte("Timer", 1AH); Byte("TxStatus", 1BH);
				(*Word("IntStatusAuto", 1EH);	Reding this register clears IntEnable *)
				DWord("DMACtrl", 20H); DWord("DnListPtr", 24);
				Byte("DnBurstThresh", 2AH);
				Byte("DnPriorityThresh", 2CH); Byte("DnPoll", 2DH);
				DWord("UpPktStatus", 30H);
				Word("FreeTimer", 34H); Word("Countdown", 36H);
				DWord("UpListPtr", 38H);
				Byte("UpPriorityThresh", 3CH); Byte("UpPoll", 3DH); Byte("UpBurstThresh", 3EH);
				DWord("RealTimeCnt", 40H);
				Word("DnMaxBurst", 78H); Word("UpMaxBurst", 7AH);
				PCIWord("Status", 02H);
				KernelLog.Exit
			END
		END
	END;
END Dump;

PROCEDURE Cleanup;
BEGIN
	IF Modules.shutdown = Modules.None THEN	(* module is being freed *)
		Remove;
	END
END Cleanup;

BEGIN
	installed := 0;
	Modules.InstallTermHandler(Cleanup)
END Ethernet3Com90x.

(*
History:
17.10.2003	mvt	Changed for new Network interface
05.11.2003	mvt	Implemented DMA directly to Network.Buffer

! System.Free Ethernet3Com90x ~

Aos.Call Ethernet3Com90x.Install
Aos.Call Ethernet3Com90x.Remove

TestNet.ShowDevices
TestNet.SetDevice "3Com90x#0"
TestNet.SendBroadcast
TestNet.SendTest 1

System.State Ethernet3Com90x ~

Aos.Call Ethernet3Com90x.Kick
Aos.Call Ethernet3Com90x.Kick2
Aos.Call Ethernet3Com90x.Dump

Aos.Call Ethernet3Com90x.TestCount 100000

NetSystem.Start
NetSystem.Stop

ftp://reali@lillian.ethz.ch
*)