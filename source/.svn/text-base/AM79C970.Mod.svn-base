MODULE AM79C970;
(* Aos Driver for AMD 79C970 (simulated by VMware) *)

IMPORT
	SYSTEM, Machine, PCI, Objects, Modules, Plugins, Network, KernelLog;

CONST
	Name = "AM79C970#";
	Description = "AMD Network Driver, Chipversion AM79C970A";

	MaxETHFrameSize = 1514;
	TxBufSize = 1600; (* Max size of tx buffers *)
	RxBufSize =1536; (* Max size for received frames *)

	RxRingSize = 32;
	TxRingSize = 16;

	ModeDRX = 0; (* disable rx *)
	ModeDTX = 1; (* disable tx *)
	ModePROM = 15; (* promiscuous mode *)

	(* 16 bit resources *)
	RAP=12H;
	RDP=10H;
	BDP=16H;
	RESET=14H;

	CSR0 = 0; (* control and status register *)
	OWN = 31;


VAR
	installed: LONGINT; (* number of installed devices *)
	installFinished: BOOLEAN;
	outPackets, inPackets, missedFrames: LONGINT;

TYPE

	(* 32bit Initializationblock, p. 989*)
	InitializationBlock = RECORD
		modeTlenRlen : SET;
		padr : ARRAY 3 OF INTEGER;
		reserved : INTEGER;
		ladr : ARRAY 2 OF SET;
		rdra : Machine.Address32;
		tdra : Machine.Address32;
	END;


	(* buffer for transmission*)
	TxBuffer = POINTER TO ARRAY TxBufSize OF CHAR;


	(* LinkDevice: interface to Bluebottle *)
	LinkDevice = OBJECT (Network.LinkDevice)
		VAR
			ctrl: Controller;
			hw: LONGINT;

		PROCEDURE Linked*(): LONGINT;
		BEGIN
			IF ctrl.Linked() THEN
				RETURN Network.LinkLinked;
			ELSE
				RETURN Network.LinkNotLinked;
			END;
		END Linked;


		PROCEDURE DoSend*(dst: Network.LinkAdr; type: LONGINT; CONST l3hdr, l4hdr, data: ARRAY OF CHAR;  h3len, h4len, dofs, dlen: LONGINT);
		VAR
			i, pos: LONGINT;
			tBuf: TxBuffer;
			flags1: SET;

		BEGIN
		INC(outPackets);
			tBuf := ctrl.txBufRing[ctrl.txIndex];

			ctrl.DisableInterrupts();

			pos := 0;
			(* set up ethernet header *)
			FOR i := 0 TO 6 - 1 DO tBuf[pos + i] := dst[i] END;
			INC(pos, 6);

			FOR i := 0 TO 6 - 1 DO tBuf[pos + i] := local[i] END;
			INC(pos, 6);

			tBuf[pos] := CHR(type DIV 100H);
			INC(pos);
			tBuf[pos] := CHR(type MOD 100H);
			INC(pos);

			(* insert l3hdr into buffer data field *)
			FOR i := 0 TO h3len - 1 DO
				tBuf[pos+i] := l3hdr[i]
			END;
			INC(pos, h3len);

			(* insert l4hdr into buffer data field *)
			FOR i := 0 TO h4len - 1 DO
				tBuf[pos + i] := l4hdr[i]
			END;
			INC(pos, h4len);

			(* insert data into buffer data field *)
			FOR i := 0 TO dlen - 1 DO
				tBuf[pos + i] := data[i + dofs];
			END;
			INC(pos, dlen);


			flags1 := SYSTEM.VAL(SET, -pos) - {16..31} + {OWN} + {25, 24};
			SYSTEM.PUT32(ctrl.txRingAdr + ctrl.txIndex * 16 + 4, flags1);

			ctrl.txIndex:=(ctrl.txIndex+1) MOD TxRingSize;
			(* trigger immediate send poll *)
			ctrl.WriteCSR(0,58);

			ctrl.EnableInterrupts();

	END DoSend;


	PROCEDURE Finalize(connected: BOOLEAN);
		BEGIN
			ctrl.Finalize;
			Finalize^(connected);
		END Finalize;
	END LinkDevice;




	(* Controller: interface to the AM79C970 hardware *)
	Controller = OBJECT
		VAR
			next: Controller; (* next controller in list *)
			base, irq: LONGINT;
			dev: LinkDevice;
			initBlock: InitializationBlock;

			rxAlignDescriptorRing: POINTER TO ARRAY (RxRingSize+1)*16 OF CHAR;
			txAlignDescriptorRing: POINTER TO ARRAY (TxRingSize+1)*16 OF CHAR;
			(* actual ring starting address (16 byte aligned!) *)
			rxRingAdr: ADDRESS;
			txRingAdr: ADDRESS;
			(* buffer rings (parallel to descriptors..) *)
			txBufRing: ARRAY TxRingSize OF TxBuffer;
			rxBufRing: ARRAY RxRingSize OF Network.Buffer;
			(* index to point to current descriptor entry/ current buffer *)
			rxIndex, txIndex : LONGINT;



		PROCEDURE &Init*(dev: LinkDevice; base, irq: LONGINT);
		VAR
			res: LONGINT;
			s: SET;
			i,x: INTEGER;

		BEGIN
			outPackets:=0;
			inPackets:=0;
			missedFrames:= 0;
			(* set ethernet broadcast address: FF-FF-FF-FF-FF-FF *)
			FOR i := 0 TO 5 DO dev.broadcast[i] := 0FFX END;

			(* update list of installed controllers, insert at head *)
			SELF.next := installedControllers;
			installedControllers := SELF;

			SELF.base := base;
			SELF.dev := dev;
			SELF.irq := irq;
			dev.ctrl := SELF;

			(* install Interrupthandler *)
			IF (irq >= 1) & (irq <= 15) THEN
				Objects.InstallHandler(SELF.HandleInterrupt, Machine.IRQ0+irq);
			END;

			(* 16 Bit Software Reset *)
			Machine.Portin16(base + RESET, x);

			(* make sure S-Reset has set  STOP (2) to initialize registers *)
			ASSERT(ReadCSR(0)=4);

			(* this Chip needs 16 Bit IO-Resources *)
			ASSERT(DeviceOk());


			(* Setup Init Block *)

			(* Rx/Tx disabled *)
			initBlock.modeTlenRlen := {ModePROM, ModeDTX, ModeDRX};

			(* TLEN 16, RLEN 32 *)
			initBlock.modeTlenRlen := initBlock.modeTlenRlen + {30} + {22} + {20};

			(* PADR - read the MAC address and set to the init block *)
			Machine.Portin16(base, x);
			dev.local[0] := CHR(x MOD 100H);
			dev.local[1] := CHR(x DIV 100H);
			initBlock.padr[0] := x;

			Machine.Portin16(base + 2, x);
			dev.local[2] := CHR(x MOD 100H);
			dev.local[3] := CHR(x DIV 100H);
			initBlock.padr[1] := x;

			Machine.Portin16(base + 4, x);
			dev.local[4] := CHR(x MOD 100H);
			dev.local[5] := CHR(x DIV 100H);
			initBlock.padr[2] := x;


			(* Logical Address Filter *)
			initBlock.ladr[0] := SYSTEM.VAL(SET, 0H);
			initBlock.ladr[1] := SYSTEM.VAL(SET, 0H);

			(* Descriptor Ring Addresses *)
			NEW(rxAlignDescriptorRing);
			rxRingAdr := ADDRESSOF(rxAlignDescriptorRing[0]);
			IF rxRingAdr MOD 16 # 0 THEN
				INC(rxRingAdr, 16 - rxRingAdr MOD 16);
			END;
			initBlock.rdra := Machine.Ensure32BitAddress (rxRingAdr);


			NEW(txAlignDescriptorRing);
			txRingAdr := ADDRESSOF(txAlignDescriptorRing[0]);
			IF txRingAdr MOD 16 # 0 THEN
				INC(txRingAdr, 16 - txRingAdr MOD 16);
			END;
			initBlock.tdra := Machine.Ensure32BitAddress (txRingAdr);


			(*Switch to 32bit mode. SSIZE32=1 *)
			WriteBCR(20, 2);


			(*write CSR1 (InitBlock Lower Address) *)
			s := SYSTEM.VAL(SET, ADDRESSOF(initBlock));
			x := SYSTEM.VAL(INTEGER, ADDRESSOF(initBlock) MOD 10000H);
			WriteCSR(1, x);


			(*write CSR2 (InitBlock Upper Address) *)
			x:= SYSTEM.VAL(INTEGER, ADDRESSOF(initBlock) DIV 10000H);
			WriteCSR(2, x);


			(* Set INIT bit (0) in CSR0 in order to start initialization*)
			WriteCSR(CSR0, 1);

			(* wait for IDON bit (8)  in CSR0 *)
			i := 0;
			REPEAT
				INC(i)
			UNTIL (8 IN SYSTEM.VAL(SET, ReadCSR(CSR0))) OR (i > 1000);

			ASSERT( i < 1000) ;	(* check for timeout *)
			WriteCSR(CSR0, 42H);

			SetupRxTxRings();


			(* register device with Network (res gets set) *)
			Network.registry.Add(dev, res);
			ASSERT(res = Plugins.Ok);
			INC(installed);

		END Init;


		PROCEDURE ReadCSR(nr:INTEGER) : INTEGER;
		VAR x: INTEGER;
		BEGIN
			Machine.Portout16(base + RAP, nr); (* write address *)
			Machine.Portin16(base + RDP, x); (* read value *)
			RETURN x;
		END ReadCSR;

		PROCEDURE WriteCSR(nr, val : INTEGER);
		BEGIN
			Machine.Portout16(base + RAP, nr);  	(* write address *)
			Machine.Portout16(base + RDP, val); 	(* read value *)
		END WriteCSR;

		PROCEDURE ReadBCR(nr: INTEGER) : INTEGER;
		VAR x : INTEGER;
		BEGIN
			Machine.Portout16(base + RAP, nr);
			Machine.Portin16(base + BDP, x);
			RETURN x;
		END ReadBCR;

		PROCEDURE WriteBCR(nr, val : INTEGER);
		BEGIN
			Machine.Portout16(base + RAP, nr);
			Machine.Portout16(base + BDP, val);
		END WriteBCR;

		PROCEDURE DeviceOk() : BOOLEAN;
		VAR x : INTEGER;
		BEGIN
			x := 88;
			Machine.Portout16(base + RAP, x);
			Machine.Portin16(base + RAP, x);
			RETURN x = 88
		END DeviceOk;


		PROCEDURE SetupRxTxRings;
		VAR
			i: LONGINT;
			adr: ADDRESS;
			t: SET;
			rBuf: Network.Buffer;
			tBuf: TxBuffer;
		BEGIN
			rxIndex := 0;
			txIndex := 0;

			(* Rx/Tx descriptor see p. 991-996*)
			adr := rxRingAdr;
			FOR i:=0 TO RxRingSize-1 DO
				rBuf:=Network.GetNewBuffer();
				rxBufRing[i] := rBuf;
				SYSTEM.PUT32(adr, ADDRESSOF(rBuf.data[0])); INC(adr, 4);
				SYSTEM.PUT16(adr, -RxBufSize); INC(adr, 2);
				SYSTEM.PUT16(adr, 8000H); INC(adr, 2);
				SYSTEM.PUT32(adr, 0); INC(adr, 4);
				SYSTEM.PUT32(adr, 0); INC(adr, 4)
			END;

			t:= SYSTEM.VAL(SET, 0FFFH-TxBufSize+1)+{12..15};
			adr := txRingAdr;
			FOR i:=0 TO TxRingSize-1 DO
				NEW(tBuf);
				txBufRing[i] := tBuf;
				SYSTEM.PUT32(adr, ADDRESSOF(tBuf[0])); INC(adr, 4);
				SYSTEM.PUT32(adr, t); INC(adr, 4);
				SYSTEM.PUT32(adr, 0); INC(adr, 4);
				SYSTEM.PUT32(adr, 0); INC(adr, 4)
			END;

			(* stop chip and write some BMU related registers  bit.*)
			HWStop();
			(* enable Rx/Tx, clear bits 0 and 1. This will automatically set TXON and RXON bits in CSR0*)
			WriteCSR(15, 0);
			(* enable polling (and some other stuff) *)
			WriteCSR(4, 915H);
			HWStart();

		END SetupRxTxRings;



		PROCEDURE UpdateTxRing;
		VAR
			i:LONGINT;
			flags1, flags2: SET;
		BEGIN

			i := 0;

			WHILE i < TxRingSize DO

				flags1 := SYSTEM.VAL(SET, SYSTEM.GET32(txRingAdr + i * 16 + 4));
				flags2 := SYSTEM.VAL(SET, SYSTEM.GET32(txRingAdr + i * 16 + 8));

				IF ~(31 IN flags1) THEN
					SYSTEM.PUT32(txRingAdr+ i * 16+4,SYSTEM.VAL(SET, 0FFFH-TxBufSize+1)+{12..15});
					SYSTEM.PUT32(txRingAdr+i*16+8, 0);
				END;

				INC(i);

			END;

		END UpdateTxRing;


		(* read all frames that are marked with OWN = 0*)
		PROCEDURE ReceivePacket;
		VAR
			type, size: LONGINT;
			rBuf, buf: Network.Buffer;
			flags1, flags2:SET;
		BEGIN

			DisableInterrupts();

			flags1 := SYSTEM.VAL(SET,SYSTEM.GET32(rxRingAdr + rxIndex * 16 + 4));
			flags2 := SYSTEM.VAL(SET,SYSTEM.GET32(rxRingAdr + rxIndex * 16 + 8));

			WHILE ~(31 IN flags1) DO
				INC(inPackets);
				buf := Network.GetNewBuffer();
				IF buf # NIL THEN

					rBuf:=rxBufRing[rxIndex];

					size:= SYSTEM.VAL(INTEGER,flags2);
					type := Network.GetNet2(rBuf.data, 6 + 6);
					rBuf.ofs:= 14;
					rBuf.len:= size;
					rBuf.src:= SYSTEM.VAL(Network.LinkAdr, rBuf.data[6]);
					rBuf.calcChecksum:= {};

					dev.QueueBuffer(rBuf, type);

					rxBufRing[rxIndex]:=buf;
					SYSTEM.PUT32(rxRingAdr+ rxIndex * 16, ADDRESSOF(buf.data[0]));
					SYSTEM.PUT32(rxRingAdr+ rxIndex * 16+4,SYSTEM.VAL(SET, 0FFFH-RxBufSize+1)+{12..15}+{31});
					SYSTEM.PUT32(rxRingAdr+ rxIndex * 16+8, 0);

				ELSE
					(* no more upcall buffers available, so do not queue the old one *)
					KernelLog.String("NO MORE BUFFERS!!!!!!!"); KernelLog.Ln;
				END;

				rxIndex:=(rxIndex+1) MOD RxRingSize;
				flags1 := SYSTEM.VAL(SET,SYSTEM.GET32(rxRingAdr + rxIndex * 16 + 4));
				flags2 := SYSTEM.VAL(SET,SYSTEM.GET32(rxRingAdr + rxIndex * 16 + 8));
			END;

			EnableInterrupts();



		END ReceivePacket;


		PROCEDURE HWStop;
		BEGIN
			WriteCSR(CSR0, 4);
		END HWStop;

		PROCEDURE HWStart;
		BEGIN
			WriteCSR(15, SYSTEM.VAL(INTEGER, {ModePROM}));
			WriteCSR(CSR0, SYSTEM.VAL(INTEGER, {1, 6}))
		END HWStart;

		PROCEDURE DisableInterrupts;
		VAR
			x: INTEGER;
		BEGIN
			x:=ReadCSR(0);
			WriteCSR(0, SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET, x)-{6}-{14}-{13}-{12}-{11}-{10}-{9})); (* do not clear the interrupt bits *)
		END DisableInterrupts;

		PROCEDURE EnableInterrupts;
		VAR
			x: INTEGER;
		BEGIN
			x:=ReadCSR(0);
			WriteCSR(0, SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET, x)+{6}-{14}-{13}-{12}-{11}-{10}-{9}));
		END EnableInterrupts;


		PROCEDURE HandleInterrupt;
		VAR
			status : INTEGER;

		BEGIN

			status:=ReadCSR( 0);

			(* TINT *)
			IF (9 IN SYSTEM.VAL(SET,status)) THEN
				UpdateTxRing();
			END;

			(* RINT *)
			IF (10 IN SYSTEM.VAL(SET,status)) THEN
				ReceivePacket();
			END;

			(* MISS - if a frame got lost, increment counter *)
			IF (12 IN SYSTEM.VAL(SET,status)) THEN
				INC(missedFrames);
			END;

			(* to clear interrupts write 1 to according bits *)
			status:=ReadCSR(0);
			WriteCSR(0, status);

		END HandleInterrupt;


		PROCEDURE Linked():BOOLEAN;
		BEGIN
			RETURN TRUE;
		END Linked;


		PROCEDURE Finalize;
		BEGIN
			(* cleanup Network registry and remove interrupthandler*)
			Network.registry.Remove(dev);
			DEC(installed);
			Objects.RemoveHandler(SELF.HandleInterrupt, Machine.IRQ0 + irq);
		END Finalize;


	END Controller;


 VAR
	installedControllers: Controller;

(* Scan the PCI bus for the specified card. *)
PROCEDURE ScanPCI(vendor, device: LONGINT);
VAR
	index, bus, dev, fct, res, base, irq, i: LONGINT;
	d: LinkDevice;
	c: Controller;
	name: Plugins.Name;
BEGIN
	index := 0; (*returns the first card found. If index was 1, it would return the second one.. *)

	WHILE (PCI.FindPCIDevice(device, vendor, index, bus, dev, fct) = PCI.Done) & (installed < 16) DO
		res := PCI.ReadConfigDword(bus, dev, fct, PCI.Adr0Reg, base); (* read offset 10H (PCI.Adr0Reg) from PCI Registers *)
		ASSERT (res = PCI.Done);
		ASSERT(ODD(base)); (* I/O mapped *)
		DEC(base, base MOD 4); (* strip lower 2 bits *)
		res := PCI.ReadConfigByte(bus, dev, fct, PCI.IntlReg, irq);
		ASSERT(res = PCI.Done);
		NEW(d, Network.TypeEthernet, MaxETHFrameSize - 14, 6);
		name := Name;
		i := 0;
		WHILE name[i] # 0X DO INC(i) END;
		IF installed > 9 THEN
			name[i] := CHR(ORD("A") + installed - 10);
		ELSE
			name[i] := CHR(ORD("0") + installed);
		END;
		name[i+1] := 0X;
		KernelLog.String("Found device: "); KernelLog.String(name); KernelLog.String("; IRQ = "); KernelLog.Int(irq, 0); KernelLog.Ln;
		res:=PCI.WriteConfigDword(bus, dev, fct, PCI.CmdReg, 5); (* enable bus master and IO Space access *)
		d.SetName(name);
		d.desc := Description;

		NEW(c, d, base, irq);	 (* increments "installed" when successful *)
		INC(index);

	END
END ScanPCI;

PROCEDURE Install*;
BEGIN {EXCLUSIVE}
	IF installed = 0 THEN
		ScanPCI(1022H, 2000H);	(* Vendor = AMD, Device = 79C970 *)
	END;
END Install;

PROCEDURE Cleanup; (*(par : ANY) :ANY;*)
BEGIN
	WHILE installedControllers # NIL DO
		KernelLog.String("Removing "); KernelLog.String(installedControllers.dev.name); KernelLog.Ln;
		installedControllers.Finalize;
		installedControllers := installedControllers.next;
		KernelLog.String("Outgoing packets: "); KernelLog.Int(outPackets,0); KernelLog.Ln;
		KernelLog.String("Incoming packets: "); KernelLog.Int(inPackets,0); KernelLog.Ln;
		KernelLog.String("Missed packets: "); KernelLog.Int(missedFrames,0); KernelLog.Ln;
		KernelLog.String("Success!"); KernelLog.Ln;
	END;
	installedControllers := NIL;
END Cleanup;

(* executed at module load *)
BEGIN
	installFinished:=FALSE;
	Modules.InstallTermHandler(Cleanup);
END AM79C970.

(*

SystemTools.Free AM79C970~
AM79C970.Install ~

*)