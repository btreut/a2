MODULE RTL8139; (** AUTHOR "TF"; PURPOSE "Driver for RealTek RTL8139 Ethernet Controllers"; *)

(* references :
	RTL 8139C(L) Preliminary, REALTEK Semiconductor Corp., Rev 1.1 1999/11/4
	RTL 8139(a/B) Programming guide (V0.1) 1999/1/15

	This driver is not optimized for speed. It has been tested on Chipset8139 and Chipset8139C. Please report success / failure with
	other 8139 compatible chipsets.
*)

IMPORT
		SYSTEM, Kernel, Machine, PCI, Objects, Modules, Plugins, Network, KernelLog
		, Files;

CONST
	Name = "RTL8139#";
	Desc = "RealTek 8139 ethernet driver";
	Model8139 = 0;  Model8139CB = 1; ModelSMC1211TX = 2; ModelDELTA8139 = 3; ModelADDTRON8139 = 4; ModelDFE528TX = 5;
	Model8129 = 7; MaxModel = 8;

	Chipset8139 = 0; Chipset8139K = 1; Chipset8139A = 2; Chipset8139B = 3; Chipset8130 = 4; Chipset8139C = 5;
	NofChipsets = 6;

	HasPwrDn = 0; HasLWake = 1;

	DebugFind = TRUE; DebugInit = TRUE; DebugCleanup = TRUE; DebugTransmit = FALSE; DebugReceive = FALSE;

	RegisterInNetwork = TRUE; CallNetworkReceiver = TRUE; Min60BytePacket = TRUE;

	ReceiveAll = FALSE;

	RxBufLenIdx = 2;
	RxBufLen = ASH(8192, RxBufLenIdx) ;
	RxBufPad = 16;
	RxBufWrapPad = 2048;
	RxBufSize = RxBufLen + RxBufPad + RxBufWrapPad;
	MaxETHFrameSize = 1514;
	MaxPacketsPerIRQ = 10;

VAR
	installed: LONGINT;	(* number of installed devices *)
	logtime: Kernel.MilliTimer;

TYPE
	ChipsetSpecific = RECORD
		name: ARRAY 32 OF CHAR;
		version: LONGINT;
		configSet, flags: SET;
	END;

VAR
	chipsetInfo: ARRAY MaxModel OF ChipsetSpecific;

	(* Interrupt statistics (only with one adapter) *)
	nPCIError, nTimeOut, nCableLengthChg, nFifoOverflow, nPUnOrLnkChg,
	nRxBufferOverflow, nTxError, nTxOk, nRxError, nRxOk :LONGINT;

	logging : BOOLEAN;
	log :Files.Rider;
TYPE
	LinkDevice = OBJECT (Network.LinkDevice)
		VAR ctrl: Controller;

		PROCEDURE Linked*(): LONGINT;
			BEGIN
			IF ctrl.Linked() THEN
				RETURN Network.LinkLinked;
			ELSE
				RETURN Network.LinkNotLinked;
			END;
		END Linked;

		PROCEDURE DoSend*(dst: Network.LinkAdr; type: LONGINT; CONST l3hdr, l4hdr, data: ARRAY OF CHAR;  h3len, h4len, dofs, dlen: LONGINT);
		VAR i: LONGINT; bufAdr: ADDRESS; txState:LONGINT; txs:SET; t, totlen:LONGINT;
		BEGIN {EXCLUSIVE}
			(* Disable IRQ *)
			SYSTEM.PUT16(ctrl.base + 3CH, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(SYSTEM.GET16(ctrl.base + 3CH)))-{0..6, 13..15}));

			bufAdr:=ADDRESSOF(ctrl.txBuffers[ctrl.nextTxBuffer]^[0]);
			SYSTEM.MOVE(ADDRESSOF(dst[0]), bufAdr, 6);
			SYSTEM.MOVE(ADDRESSOF(local[0]), bufAdr+6, 6);
			SYSTEM.PUT16(bufAdr+12, ROT(SYSTEM.VAL(INTEGER, SHORT(type)), 8));
			i:=14;
			IF h3len > 0 THEN SYSTEM.MOVE(ADDRESSOF(l3hdr[0]),  bufAdr+i, h3len); INC(i, h3len) END;
			IF h4len > 0 THEN SYSTEM.MOVE(ADDRESSOF(l4hdr[0]),  bufAdr+i, h4len); INC(i, h4len) END;
			IF i + dlen < MaxETHFrameSize THEN
				SYSTEM.MOVE(ADDRESSOF(data[0]) + dofs,  bufAdr + i, dlen); INC(i, dlen);
			END;

			IF Min60BytePacket THEN WHILE i<60 DO ctrl.txBuffers[ctrl.nextTxBuffer]^[i] := CHR(0); INC(i) END END;
			totlen := i;
			IF DebugTransmit THEN
				KernelLog.Enter; KernelLog.String("[TRANSMIT] Packet length:"); KernelLog.Int(i, 5); KernelLog.String(" data ..."); KernelLog.Ln;
				KernelLog.Buffer(ctrl.txBuffers[ctrl.nextTxBuffer]^, 0, i);
				KernelLog.Exit;
			END;
			IF i <= MaxETHFrameSize THEN
				SYSTEM.PUT32(ctrl.base + 20H+4*ctrl.nextTxBuffer, bufAdr); (* set Transmit Start Address *)
				txState:=8*32*2048; (* threshold 256 *)
				txState:=txState+i;
				SYSTEM.PUT32(ctrl.base + 10H+4*ctrl.nextTxBuffer, txState); (* send *)
				i:=0; WHILE (i<10000000) & (SYSTEM.VAL(SET, SYSTEM.GET32(ctrl.base+10H+4*ctrl.nextTxBuffer)) * {14, 15, 30} = {}) DO
					INC(i)
				END;

				IF i=10000000 THEN KernelLog.Enter; KernelLog.String("MegaError !!!"); KernelLog.Exit; ctrl.Reset END;

				IF DebugTransmit THEN
					KernelLog.Enter;
					IF i<10000000 THEN
						txs:=SYSTEM.VAL(SET, SYSTEM.GET32(ctrl.base+10H+4*ctrl.nextTxBuffer));
						IF 13 IN txs THEN KernelLog.String(" DMA Completed ") END;
						IF 14 IN txs THEN KernelLog.String(" Fifo underrun ") END;
						IF 15 IN txs THEN KernelLog.String(" Transmit OK ") END;
						IF 30 IN txs THEN KernelLog.String(" Transmit ABORTED ") END
					ELSE KernelLog.String("Transmit timed out ");
						 KernelLog.Bits(SYSTEM.VAL(SET, SYSTEM.GET32(ctrl.base+10H+4*ctrl.nextTxBuffer)), 0, 32)
					END;
					KernelLog.Exit
				END;
				INC(sendCount);
				 ctrl.nextTxBuffer :=  (ctrl.nextTxBuffer + 1) MOD 4
			END
			;
			(* Enable IRQ *)
			SYSTEM.PUT16(ctrl.base + 3CH, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(SYSTEM.GET16(ctrl.base + 3CH)))+{0..6, 13..15}));
			IF logging THEN
				t := Kernel.Elapsed(logtime);
				Files.WriteLInt(log, t DIV 1000);
				Files.WriteLInt(log, (t MOD 1000)*1000+1);
				Files.WriteLInt(log, totlen);  Files.WriteLInt(log, totlen);
				log.file.WriteBytes(log, ctrl.txBuffers[ctrl.nextTxBuffer]^, 0, totlen)
			END
		END DoSend;

		PROCEDURE Finalize(connected: BOOLEAN);
		BEGIN
			ctrl.Finalize;
			Finalize^(connected);
		END Finalize;

	END LinkDevice;


	Controller = OBJECT
		VAR
			next: Controller;
			base: ADDRESS; irq: LONGINT;
			dev: LinkDevice;
			model, chipset: LONGINT;
			media: SET;
			rxBufPos: LONGINT;
			timer: Kernel.Timer;
			eepromAdrLen:LONGINT;

			devAdr:ARRAY 3 OF LONGINT;

			rxBuffer: POINTER TO ARRAY OF CHAR; (* ring buffer *)
			rxAdr: LONGINT; (* ring buffer physical adr *)
			nextTxBuffer: LONGINT;
			txBuffers: ARRAY 4 OF POINTER TO ARRAY OF CHAR;

			rcvAdr, rcvSize:LONGINT;

		PROCEDURE FlushWrite8(reg, val:LONGINT);
		BEGIN
			SYSTEM.PUT8(base + reg, val); (* force flush *) val := SYSTEM.GET8(base + reg)
		END FlushWrite8;

	PROCEDURE Reset;
	VAR dp, dummy:LONGINT; val:SET;
	BEGIN	nextTxBuffer:=0;
			KernelLog.Enter; KernelLog.String("Softreset"); KernelLog.Exit;
			(* soft reset *)
			SYSTEM.PUT8(base + 37H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 37H)))) + {4})); (* command register: 4 soft reset *)
			dp:=0;
			LOOP INC(dp); timer.Sleep(1); IF (SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 37H)))) * {4} = {})  OR (dp=100) THEN EXIT END END;

			(* assert PIO and MMIO enabled *)
			val := SYSTEM.VAL(SET, SYSTEM.GET8(base + 52H));
			IF val * {3} = {} THEN KernelLog.String("MMIO is disabled."); HALT(1000) END;
			IF val * {2} = {} THEN KernelLog.String("IO mapping is disabled."); HALT(1000) END;

			(* enable Tx / Rx *)
			FlushWrite8(37H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 37H))))* {1, 5, 6, 7} + {2 , 3}));

			(* initialize the rxBuffer *)
			SYSTEM.PUT32(base + 30H, ADDRESSOF(rxBuffer[0]));
			rxBufPos:=0; SYSTEM.PUT16(base+38H, rxBufPos-16); dummy:=SYSTEM.GET16(base + 38H);

			(* initialize packet types *)
(*			IF ReceiveAll THEN SYSTEM.PUT32(base + 44H, SYSTEM.VAL(SET, SYSTEM.GET32(base + 44H)) - {24..27, 13..15} + {24(*..27, 13..15*), 12, 8..10, 7, 0..4})
			ELSE SYSTEM.PUT32(base + 44H, SYSTEM.VAL(SET, SYSTEM.GET32(base + 44H)) - {24..27, 13..15} + {24(*..27, 13..15*), 12, 8..10, 7, 1..4})
			END; *)

			IF ReceiveAll THEN
				SYSTEM.PUT32(base + 44H,
					SYSTEM.VAL(SET, SYSTEM.GET32(base + 44H)) * chipsetInfo[chipset].configSet + {24(*..27, 13..15*), 12, 8..10, 7, 0..4})
			ELSE
				SYSTEM.PUT32(base + 44H,
					SYSTEM.VAL(SET, SYSTEM.GET32(base + 44H))  * chipsetInfo[chipset].configSet  + {24(*..27, 13..15*), 12, 8..10, 7, 1..4})
			END;

			dummy:=SYSTEM.GET32(base + 44H); (* flush *)
			(* Set MAC address *)
			SYSTEM.PUT32(base, Network.Get4(dev.local, 0)); dummy:=SYSTEM.GET32(base);
			SYSTEM.PUT32(base + 4, Network.Get4(dev.local, 4));dummy:=SYSTEM.GET32(base + 4);

			(* enable Tx interrupt for testing *)
		(*	SYSTEM.PUT16(base + 3CH, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(SYSTEM.GET16(base + 3CH)))+{2, 0, 4}));*)
			SYSTEM.PUT16(base + 3CH, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(SYSTEM.GET16(base + 3CH)))+{0..6, 13..15}));

			(* Set Max DMA Burst Size*)
			SYSTEM.PUT32(base + 40H, SYSTEM.VAL(SET, SYSTEM.GET32(base + 40H))+{9, 10});

	END Reset;

		PROCEDURE &Init*(dev: LinkDevice; base: ADDRESS; irq, model: LONGINT);
		VAR res, dp, ver, i, dummy: LONGINT; val, nval: SET;
		BEGIN
			SELF.next:=installedControllers; installedControllers:=SELF;
			NEW(timer);

			SELF.base := base; SELF.dev := dev; SELF.model := model; SELF.media := media; SELF.irq := irq;
			dev.ctrl := SELF;

			(* chipset:=Chipset8139; (*uncomment this line if the driver does not work. Maybe it will then still not work ;-) *) *)

			(* enable high power mode *)
			IF HasPwrDn IN chipsetInfo[chipset].flags THEN
				FlushWrite8(50H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 50H)))) + {7, 6})); (* config write enable *)
				SYSTEM.PUT8(base + 52H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 52H)))) - {0, 1})); (* config 1: 0 pwrdn, 1 sleep *)
				FlushWrite8(50H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 50H)))) - {7, 6})); (* config write disable *)
			ELSE
				val := SYSTEM.VAL(SET, SYSTEM.GET8(base + 52H)); nval := val;
				IF (HasLWake IN chipsetInfo[chipset].flags) & (1 IN val) THEN nval:=nval - {1} END;
				nval := nval + {0}; (* cfg1 pm enable *)
				IF nval # val THEN
					FlushWrite8(50H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 50H)))) + {7, 6})); (* config write enable *)
					SYSTEM.PUT8(base + 52H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 52H)))) - {0, 1})); (* config 1: 0 pwrdn, 1 sleep *)
					FlushWrite8(50H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 50H)))) - {7, 6})) (* config write disable *)
				END;
				IF (HasLWake IN chipsetInfo[chipset].flags) THEN
					SYSTEM.PUT8(base + 5AH, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 5AH)))) - {2})) (* config 4: 2 lwptn *)
				END
			END;

			(* soft reset *)
			SYSTEM.PUT8(base + 37H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 37H)))) + {4})); (* command register: 4 soft reset *)
			dp:=0;
			LOOP INC(dp); timer.Sleep(1); IF (SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 37H)))) * {4} = {})  OR (dp=100) THEN EXIT END END;

			(* assert PIO and MMIO enabled *)
			val := SYSTEM.VAL(SET, SYSTEM.GET8(base + 52H));
			IF val * {3} = {} THEN KernelLog.String("MMIO is disabled."); HALT(1000) END;
			IF val * {2} = {} THEN KernelLog.String("IO mapping is disabled."); HALT(1000) END;

			(* get version *)
				chipset:=-1;
			ver := SYSTEM.GET8(base + 43H);
			i := 0; WHILE i < NofChipsets DO IF chipsetInfo[i].version = ver THEN chipset := i; i:=NofChipsets ELSE INC(i) END END;
			IF chipset = -1 THEN chipset:=Chipset8139; KernelLog.Enter; KernelLog.String("chipset version unknown... assuming RTL-8139"); KernelLog.Exit END;

			IF DebugInit THEN KernelLog.String("Chip version is: "); KernelLog.Hex(ver, 2); KernelLog.String(" "); KernelLog.String(chipsetInfo[chipset].name); KernelLog.Ln END;

			(* Install Interrupt handler *)
			IF DebugInit THEN KernelLog.String("Install IRQ Handler: "); KernelLog.Int(irq, 5); KernelLog.Ln END;
			IF (irq >= 1) & (irq <= 15) THEN Objects.InstallHandler(SELF.HandleInterrupt, Machine.IRQ0+irq) END;

			NEW(rxBuffer, RxBufSize);

			(* enable Tx / Rx *)
			FlushWrite8(37H, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 37H))))* {1, 5, 6, 7} + {2 , 3}));

			(* initialize the rxBuffer *)
			SYSTEM.PUT32(base + 30H, ADDRESSOF(rxBuffer[0]));
			rxBufPos:=0; SYSTEM.PUT16(base+38H, rxBufPos-16); dummy:=SYSTEM.GET16(base + 38H);

			(* initialize packet types *)
	(*		IF ReceiveAll THEN SYSTEM.PUT32(base + 44H, SYSTEM.VAL(SET, SYSTEM.GET32(base + 44H)) - {24..27, 13..15} + {24(*..27, 13..15*), 12, 8..10, 7, 0..4})
			ELSE SYSTEM.PUT32(base + 44H, SYSTEM.VAL(SET, SYSTEM.GET32(base + 44H)) - {24..27, 13..15} + {24(*..27, 13..15*), 12, 8..10, 7, 1..4})
			END; *)
			IF ReceiveAll THEN
				SYSTEM.PUT32(base + 44H,
					SYSTEM.VAL(SET, SYSTEM.GET32(base + 44H)) * chipsetInfo[chipset].configSet + {24(*..27, 13..15*), 12, 8..10, 7, 0..4})
			ELSE
				SYSTEM.PUT32(base + 44H,
					SYSTEM.VAL(SET, SYSTEM.GET32(base + 44H))  * chipsetInfo[chipset].configSet  + {24(*..27, 13..15*), 12, 8..10, 7, 1..4})
			END;

			dummy:=SYSTEM.GET32(base + 44H); (* flush *)


			FOR i:=0 TO 3 DO NEW(txBuffers[i], MaxETHFrameSize) END;
			FOR i := 0 TO 5 DO dev.broadcast[i] := 0FFX END;

			eepromAdrLen:=8; IF ReadEEPROM(0)#8129H THEN eepromAdrLen:=6 END;
			FOR i:=0 TO 2 DO devAdr[i]:=ReadEEPROM(7+i);
				dev.local[i*2]:=CHR(devAdr[i] MOD 256);dev.local[i*2+1]:=CHR(devAdr[i] DIV 256 MOD 256)
			END;

			dev.adrSize := 6;

			(* Set MAC address *)
			SYSTEM.PUT32(base, Network.Get4(dev.local, 0)); dummy:=SYSTEM.GET32(base);
			SYSTEM.PUT32(base + 4, Network.Get4(dev.local, 4));dummy:=SYSTEM.GET32(base + 4);

			(* MAR Multicast Filter Setup (33 33 xx xx xx xx) *)
			SYSTEM.PUT32(base + 8H, 0FFFF3333H);
			SYSTEM.PUT32(base + 0CH, 0FFFFFFFFH);

			(* enable Tx interrupt for testing *)
		(*	SYSTEM.PUT16(base + 3CH, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(SYSTEM.GET16(base + 3CH)))+{2, 0, 4}));*)
			SYSTEM.PUT16(base + 3CH, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LONG(SYSTEM.GET16(base + 3CH)))+{1..6, 13..15}));

			(* Set Max DMA Burst Size*)
			SYSTEM.PUT32(base + 40H, SYSTEM.VAL(SET, SYSTEM.GET32(base + 40H))+{9, 10});


			(* Register with Network *)
			IF RegisterInNetwork THEN
				Network.registry.Add(dev, res);
				ASSERT(res = Plugins.Ok);
				INC(installed)
			END
		END Init;

		PROCEDURE ReadEEPROM(loc:LONGINT):LONGINT;
		VAR readCMD, data:SET; dummy, i:LONGINT;
		BEGIN
			readCMD := SYSTEM.VAL(SET, loc);
			IF eepromAdrLen = 6 THEN readCMD:=readCMD+{1+6, 2+6} ELSE readCMD:=readCMD+{1+8, 2+8} END;
			(* base+50H bit 3: EEPROM chip select; bit 2 EEPROM clock shift *)

			(* enable EEPROM access *)
			SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR, {7})); SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR, {7, 3}));
			dummy:=SYSTEM.GET32(base+50H); (* delay *)

			(* setup read adress *)
			i := 4 + eepromAdrLen;
			WHILE i >= 0 DO
				IF i IN readCMD THEN SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR, {7, 3, 1})) ELSE SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR,{7, 3})) END;
				dummy:=SYSTEM.GET32(base+50H); (* delay *)
				IF i IN readCMD THEN SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR,{7, 3, 2, 1})) ELSE SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR,{7, 3, 2})) END;  (* clock shift *)
				dummy:=SYSTEM.GET32(base+50H); (* delay *)
				DEC(i)
			END;

			(* enb, chip select  *)
			SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR, {7, 3}));
			dummy:=SYSTEM.GET32(base+50H); (* delay *)

			(* read 16 bit *)
			data:={};
			FOR i:=15 TO 0 BY -1 DO
				SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR,{7, 3, 2})); (* shift clock *)
				dummy:=SYSTEM.GET32(base+50H); (* delay *)

				IF SYSTEM.VAL(SET, LONG(LONG(SYSTEM.GET8(base + 50H)))) * {0} = {0} THEN INCL(data, i) END;

				SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR, {7, 3})); (* ~shift clock *)
				dummy:=SYSTEM.GET32(base+50H) (* delay *)
			END;

			(* disable EEPROM *)
			SYSTEM.PUT8(base+50H, SYSTEM.VAL(CHAR, -{3}));
			dummy:=SYSTEM.GET32(base+50H); (* delay *)

			RETURN SYSTEM.VAL(LONGINT, data)
		END ReadEEPROM;

		PROCEDURE ReadPacket;
		VAR rxInfo, pSize, pStart, dummy, i, type: LONGINT; t: LONGINT;
			buf : Network.Buffer;
		BEGIN
			i:=0;
			WHILE (i<MaxPacketsPerIRQ) &  ~(0 IN SYSTEM.VAL(SET, SYSTEM.GET8(base + 37H))) DO
				rxInfo := Network.Get4(rxBuffer^, rxBufPos);
				pSize := (rxInfo DIV 65536) MOD 65536 - 4;
				pStart := rxBufPos + 4;
				IF DebugReceive THEN KernelLog.Enter; KernelLog.String("[RECEIVE] PSize is:"); KernelLog.Int(pSize, 4); KernelLog.Exit END;
				IF pSize # 0FFF0H THEN
					IF pSize < MaxETHFrameSize THEN
						IF DebugReceive THEN
							KernelLog.Enter;
							KernelLog.String("Read Packet ("); KernelLog.Int(pSize, 4); KernelLog.String(")"); KernelLog.Ln;
							KernelLog.Buffer(rxBuffer^, rxBufPos + 4, pSize);
							KernelLog.Exit
						END;
						IF logging THEN
							t := Kernel.Elapsed(logtime);
							Files.WriteLInt(log, t DIV 1000);
							Files.WriteLInt(log, (t MOD 1000)*1000+1);
							Files.WriteLInt(log, pSize);  Files.WriteLInt(log, pSize);
							log.file.WriteBytes(log, rxBuffer^, rxBufPos + 4, pSize);
						END;

						type := Network.GetNet2(rxBuffer^, pStart + 6 + 6);
						IF DebugReceive THEN KernelLog.Enter; KernelLog.String("packet type:"); KernelLog.Hex(type, 2); KernelLog.Exit END;

(*						IF CallNetworkReceiver THEN
							dev.GetReceiver(type, handler, hSize);	(* base method call *)
							IF hSize > pSize THEN hSize := pSize END;
							rcvAdr := ADDRESSOF(rxBuffer[pStart + 14 + hSize]);
							rcvSize := pSize - hSize - 14;
							INC(dev.recvCount);
							handler(dev, SYSTEM.VAL(Network.RecvHdr, rxBuffer[pStart+14]), pSize-14, type,
								SYSTEM.VAL(Network.LinkAdr, rxBuffer[pStart+6]));
						END;	*)
						buf := Network.GetNewBuffer();
						IF buf # NIL THEN
							buf.ofs := 0;
							buf.len := pSize - 14;
							buf.src := SYSTEM.VAL(Network.LinkAdr, rxBuffer[pStart + 6]);
							buf.calcChecksum := {};
							Network.Copy(rxBuffer^, buf.data, pStart + 14, 0, pSize - 14);
							dev.QueueBuffer(buf, type);
						ELSE
							(* no more upcall buffers available *)
						END

						(* write buffer pos was here *)
					END
				END; (* ELSE DMA is still in action for this packet (Info: BSD-driver) *)

						(* write buffer *)
				rxBufPos:=(rxBufPos+pSize+8+3); rxBufPos:=(rxBufPos - (rxBufPos MOD 4)) MOD RxBufLen;
				SYSTEM.PUT16(base+38H, rxBufPos-16); dummy:=SYSTEM.GET16(base + 38H);
				INC(i)
			END;


		END ReadPacket;

		PROCEDURE HandleInterrupt;
		VAR status, ack:SET; dummy:LONGINT;
		BEGIN
			ack:={0};
			status:=SYSTEM.VAL(SET, LONG(SYSTEM.GET16(base + 3EH)));

			 (* System Error: PCI bus error *)
			 IF 15 IN status THEN
				Machine.AtomicInc(nPCIError)
			END;

			(* TimeOut: TCTR reaches value of TimerInt register *)
			IF 14 IN status THEN
				Machine.AtomicInc(nTimeOut); INCL(ack, 14);
			END;

			(* Cable length changed *)
			IF 13 IN status THEN
				Machine.AtomicInc(nCableLengthChg); INCL(ack, 13)
			END;

			(* Rx FIFO overflow *)
			IF 6 IN status THEN
				INCL(ack, 4); INCL(ack, 6); INCL(ack, 0);
				Machine.AtomicInc(nFifoOverflow);
			END;

			(* Packet underrun or link changed  *)
			IF 5 IN status THEN Reset;
				Machine.AtomicInc(nPUnOrLnkChg); INCL(ack, 5)
			END;

			(* Rx buffer overflow  *)
			IF 4 IN status THEN (* Reset; *)
				Machine.AtomicInc(nRxBufferOverflow);
				INCL(ack, 0); INCL(ack, 4);
			END;

			(* Transmit error: packet transmission aborted (too many collisions)  *)
			IF 3 IN status THEN
				Machine.AtomicInc(nTxError); INCL(ack, 3)
			END;

			(* Transmit ok  *)
			IF 2 IN status THEN
				Machine.AtomicInc(nTxOk);
				INCL(ack, 2)
			END;

			(* Receive Error: CRC error or alignment error *)
			IF 1 IN status THEN
				Machine.AtomicInc(nRxError); INCL(ack, 1)
			END;

			(* receive ok *)
			IF 0 IN status THEN
				Machine.AtomicInc(nRxOk);
				ReadPacket;
				INCL(ack, 0);
			END;
			SYSTEM.PUT16(base + 3EH, SYSTEM.VAL(LONGINT, ack));
			dummy:=SYSTEM.GET16(base + 3EH);
		END HandleInterrupt;

		PROCEDURE Finalize;
		BEGIN
			(* disable all interrupts *)
			SYSTEM.PUT16(base + 3CH, 0);
			timer.Sleep(1000); (* hope the interrupt will be over, then *)
			IF DebugCleanup THEN KernelLog.String("Remove IRQ Handler.");  KernelLog.Ln END;
			Objects.RemoveHandler(SELF.HandleInterrupt, Machine.IRQ0+irq);
			IF RegisterInNetwork THEN Network.registry.Remove(dev) END
		END Finalize;

		PROCEDURE Linked(): BOOLEAN;
		BEGIN
			RETURN ~(2 IN SYSTEM.VAL(SET, SYSTEM.GET8(base + 58H)));
		END Linked;

	END Controller;

 VAR
	installedControllers: Controller;

(* Scan the PCI bus for the specified card. *)

PROCEDURE ScanPCI(vendor, device, model: LONGINT);
VAR index, bus, dev, fct, res, irq, i: LONGINT; base: ADDRESS; d: LinkDevice; c: Controller; name: Plugins.Name;
BEGIN
	index := 0;
	WHILE (PCI.FindPCIDevice(device, vendor, index, bus, dev, fct) = PCI.Done) & (installed < 10) DO
		res := PCI.ReadConfigDword(bus, dev, fct, PCI.Adr1Reg, i); ASSERT(res = PCI.Done);
		base := i; ASSERT(~ODD(base)); 	(* memory mapped *)
		DEC(base, base MOD 16);
		Machine.MapPhysical(base, 0FFH, base);

		res := PCI.ReadConfigByte(bus, dev, fct, PCI.IntlReg, irq); ASSERT(res = PCI.Done);
		NEW(d, Network.TypeEthernet, MaxETHFrameSize - 14, 6);
		name := Name;
		i := 0; WHILE name[i] # 0X DO INC(i) END;
		name[i] := CHR(ORD("0") + installed);
		name[i+1] := 0X;
		d.SetName(name);
		d.desc := Desc;

		IF DebugFind THEN KernelLog.String("Found model nr :"); KernelLog.Int(model, 4); KernelLog.Ln END;

		NEW(c, d, base, irq, model);	(* increments "installed" when successful *)
		INC(index)
	END
END ScanPCI;

PROCEDURE Install*;
BEGIN {EXCLUSIVE}
	IF installed = 0 THEN
		IF DebugFind THEN KernelLog.String("Searching devices..."); KernelLog.Ln END;
		ScanPCI(10ECH, 8139H, Model8139);
		ScanPCI(10ECH, 8138H, Model8139CB);
		ScanPCI(1113H, 1211H, ModelSMC1211TX);
		ScanPCI(1500H, 1360H, ModelDELTA8139);
		ScanPCI(4033H, 1360H, ModelADDTRON8139);
		ScanPCI(1186H, 1300H, ModelDFE528TX);
		ScanPCI(10ECH, 8129H, Model8129);
		IF DebugFind THEN KernelLog.String("Find finished."); KernelLog.Ln END;
	END;
END Install;

PROCEDURE StartLog*;
VAR f: Files.File;
BEGIN
	Kernel.SetTimer(logtime, 0);
	f := Files.New("EtherNet.Log");  f.Set(log, 0); Files.Register(f);	(* tcpdump compatible log file *)
	Files.WriteLInt(log, LONGINT(0A1B2C3D4H));  Files.WriteInt(log, 2);
	Files.WriteInt(log, 4);  Files.WriteLInt(log, 0);  Files.WriteLInt(log, 0);
	Files.WriteLInt(log, 1514);  Files.WriteLInt(log, 1);
	logging := TRUE;
	KernelLog.Enter; KernelLog.String("EtherNet log started --> dumping to EtherNet.Log."); KernelLog.Exit
END StartLog;

PROCEDURE StopLog*;
BEGIN
	logging:=FALSE;
	KernelLog.Enter; KernelLog.String("EtherNet log stopped."); KernelLog.Exit
END StopLog;

PROCEDURE Cleanup;
BEGIN
	WHILE installedControllers # NIL DO installedControllers.Finalize; installedControllers:=installedControllers.next END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);

	chipsetInfo[Chipset8139].name := "RTL-8139"; chipsetInfo[Chipset8139].version := 40H;
	chipsetInfo[Chipset8139].flags := {HasPwrDn}; chipsetInfo[Chipset8139].configSet:={28..31, 17..23, 6};

	chipsetInfo[Chipset8139B].name := "RTL-8139B"; chipsetInfo[Chipset8139B].version := 78H;
	chipsetInfo[Chipset8139B].flags := {HasLWake}; chipsetInfo[Chipset8139B].configSet:={28..31, 17..22, 6};

	chipsetInfo[Chipset8139A].name := "RTL-8139A"; chipsetInfo[Chipset8139A].version := 70H;
	chipsetInfo[Chipset8139A].flags := {}; chipsetInfo[Chipset8139A].configSet:={28..31, 17..26, 6};

	chipsetInfo[Chipset8139C].name := "RTL-8139C"; chipsetInfo[Chipset8139C].version := 74H;
	chipsetInfo[Chipset8139C].flags := {HasLWake}; chipsetInfo[Chipset8139C].configSet:={28..31, 17..22, 6};

END RTL8139.


SystemTools.Free RTL8139 ~
RTL8139.Install
System.OpenKernelLog
TestNet.Mod
TestNet.SetDevice "RTL8139#0"