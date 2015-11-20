MODULE Intel8255x;

(*
Aos driver for Intel 8255x Ethernet Controllers

Reference: Intel, "Intel 8255x 10/100 Mbps Ethernet Controller Family, Open Source Software Developer Manual,
Revision 1.0, January 2003"
*)

IMPORT SYSTEM, Kernel, Machine, PCI, Objects, Modules, Plugins, Network, KernelLog;

CONST
	Name = "Intel8255x#";
	Desc = "Intel 8255x Ethernet Driver";
	K = 1024;
	MaxETHFrameSize = 1514;
	RxRingSize = 100;
	TxRingSize = 100;
	MaxTxTrials = 5;

	SizeOfConfigCmdHdr = 32;
	SizeOfNOPCmdHdr = 8;
	SizeOfIASetupCmdHdr = 16;
	SizeOfTxCmdHdr = 16;
	SizeOfRFDHdr = 16;

	keepMasks = TRUE;

	(* device registers *)
	SCBStatus = 0H;
	SCBCommand = 2H;
	SCBGenPtr = 4H;
	SCBEeprom = 0EH;
	PORTReg = 8H;

	(* ack bits *)
	CX = {15};
	FR = {14};
	CNA = {13};
	RNR = {12};
	MDI = {11};
	SWI = {10};

	(* interrupt masks *)
	CXMask = {31};
	FRMask = {30};
	CNAMask = {29};
	RNRMask = {28};
	ERMask = {27};
	FCPMask = {26};
	MaskAllIntr = {24};
	UnMaskAllIntr = {};

	(* generate software interrupt *)
	SI = {25};

	(* CU Commands *)
	CUNop = {};
	CUStart = {20};
	CUResume = {21};
	CULoadBase = {21, 22};

	(* RU Commands *)
	RUNop = {};
	RUStart = {16};
	RUResume = {17};
	RUAbort = {18};
	RULoadBase = {17, 18};

	(* CU States *)
	CUIdle = {};
	CUSuspended = {6};

	(* RU States *)
	RUIdle = {};
	RUSuspended = {2};
	RUReady = {4};

	(* PORT Selection Function *)
	Reset = {};
	SelectiveReset = {1};

	(* Action Command Opcodes in Control Block List (CBL) *)
	ActionCmdNOP = {};
	ActionCmdIASetup = {16};
	ActionCmdConfig = {17};
	ActionCmdTx = {18};

	(* More Command Bits in CBL *)
	LastBlock = {31};	(* EL Bit *)
	Suspend = {30};	(* S Bit *)
	Interrupt = {29};	(* I Bit *)

VAR
	nCUWaitActive: LONGINT;

TYPE
	ByteField = POINTER TO ARRAY OF CHAR;

	DataBlock = POINTER TO RECORD
		next: DataBlock;
		size: LONGINT;
		data: ByteField;
	END;

	LinkDevice = OBJECT(Network.LinkDevice)
		VAR
			ctrl: Controller;
			txTrials: LONGINT;

		(*
			send a frame
			padding and checksum are inserted directly by the device
		*)
		PROCEDURE DoSend*(dst: Network.LinkAdr; type: LONGINT; CONST l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT);
		CONST
			DataOfs = 10H;	(* data block offset in transmit command block *)
			C = 15;
		VAR
			actAdr, prevAdr: ADDRESS; txLen, i: LONGINT;
			byteCount, EOF, TxThreshold, state, cmdHdr, sendStatus: SET;
		BEGIN {EXCLUSIVE}
			(* if C Bit in next TxCmd Block is not set, the transmit command has not yet finished processing all bytes
				=> buffer overflow (wait)
			*)
			ctrl.ExecCmd(MaskAllIntr, ~keepMasks);

			REPEAT
				sendStatus := SYSTEM.VAL(SET, SYSTEM.GET32(ADDRESSOF(ctrl.actTxCmd.next.data[0])));
			UNTIL (C IN sendStatus);

			txLen := 14 + h3len + h4len + dlen;	(* number of bytes to transmit *)
			prevAdr := ADDRESSOF(ctrl.actTxCmd.data[0]);

			ctrl.actTxCmd := ctrl.actTxCmd.next;
			actAdr := ADDRESSOF(ctrl.actTxCmd.data[0]);

			(* setup cmd hdr *)
			SYSTEM.PUT32(actAdr, Suspend + ActionCmdTx);

			(* in simplified mode the TBD array address should be set to all ones *)
			SYSTEM.PUT32(actAdr + 08H, 0FFFFFFFFH);

			(* set TxThreshold, EOF Bit, Tx Command Block Byte Count *)
			byteCount := SYSTEM.VAL(SET, txLen) * {0..13};
			EOF := {15};
			TxThreshold := {16};
			SYSTEM.PUT32(actAdr + 0CH, byteCount + EOF + TxThreshold);

			(* set data field *)
			SYSTEM.MOVE(ADDRESSOF(dst[0]), actAdr + DataOfs, 6);	(* the first 6 bytes of data field are dst address *)
			SYSTEM.MOVE(ADDRESSOF(local[0]), actAdr + DataOfs + 6, 6);
			SYSTEM.PUT16(actAdr + DataOfs + 12, ROT(SYSTEM.VAL(INTEGER, SHORT(type)), 8));
			i := 14;
			IF h3len > 0 THEN SYSTEM.MOVE(ADDRESSOF(l3hdr[0]), actAdr + DataOfs + i, h3len); INC(i, h3len) END;
			IF h4len > 0 THEN SYSTEM.MOVE(ADDRESSOF(l4hdr[0]), actAdr + DataOfs + i, h4len); INC(i, h4len) END;
			IF i+dlen < MaxETHFrameSize THEN
				SYSTEM.MOVE(ADDRESSOF(data[0])+dofs, actAdr + DataOfs + i, dlen);
				INC(i, dlen);
			END;

			(* delete Suspended Bit from previous TxCmd *)
			state := ctrl.GetCUState();
			WHILE (state # CUIdle) & (state # CUSuspended) DO
				Machine.AtomicInc(nCUWaitActive);
				state := ctrl.GetCUState();
			END;
			cmdHdr := SYSTEM.VAL(SET, SYSTEM.GET32(prevAdr)) - Suspend;
			SYSTEM.PUT32(prevAdr, cmdHdr);

			state := ctrl.GetCUState();
			IF state = CUIdle THEN
				actAdr := Machine.PhysicalAdr(actAdr, ctrl.actTxCmd.size);
				ctrl.WriteSCBGenPtr(Machine.Ensure32BitAddress (actAdr));
				ctrl.ExecCmd(CUStart, keepMasks);
			ELSIF state = CUSuspended THEN
				ctrl.ExecCmd(CUResume, keepMasks);
			END;

			INC(sendCount);
			ctrl.ExecCmd(UnMaskAllIntr, ~keepMasks);
			(* ctrl.ExecCmd(CXMask + CNAMask + ERMask, ~keepMasks); *)
		END DoSend;

		PROCEDURE ReceiveData(VAR data: ARRAY OF CHAR; ofs, size: LONGINT);
		BEGIN
			ASSERT(size <= ctrl.rcvSize);	(* enough data left *)
			ASSERT((size >= 0) & (ofs+size <= LEN(data)));	(* index check *)
			SYSTEM.MOVE(ctrl.rcvAdr, ADDRESSOF(data[ofs]), size);
			INC(ctrl.rcvAdr, size);
			DEC(ctrl.rcvSize, size);
		END ReceiveData;

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
			actRFD, lastRFD: DataBlock;
			actTxCmd: DataBlock;
			rcvAdr, rcvSize: LONGINT;

		PROCEDURE &Init*(dev: LinkDevice; base: ADDRESS; irq: LONGINT);
		VAR res, i: LONGINT;
			configCmd, iASetupCmd: DataBlock;
		BEGIN
			SELF.next := installedControllers; installedControllers := SELF;

			SELF.base := base;
			SELF.irq := irq;
			SELF.dev := dev;
			dev.ctrl := SELF;

			(* set Ethernet Broadcast Address *)
			FOR i := 0 TO 5 DO
				dev.broadcast[i] := 0FFX;
			END;

			WritePORT(Reset); Delay(1);

			ExecCmd(MaskAllIntr, ~keepMasks);	(* mask all interrupts, do not keep any old masks *)

			WriteSCBGenPtr(0);
			ExecCmd(CULoadBase, keepMasks);	(* set CU base, keeping all interrupt masks *)

			WriteSCBGenPtr(0);
			ExecCmd(RULoadBase, keepMasks);	(* set RU base, keeping all interrupt masks *)

			(* configure the device *)
			MakeBlock(configCmd, SizeOfConfigCmdHdr);
			SetCmdHdr(LastBlock + ActionCmdConfig, configCmd);
			SetByteMap8255x(configCmd);
			StartActionCmd(configCmd);

			(* load the device with the individual address (MAC address) *)
			MakeBlock(iASetupCmd, SizeOfIASetupCmdHdr);
			SetCmdHdr(LastBlock + ActionCmdIASetup, iASetupCmd);
			SetMACAddress(iASetupCmd);
			StartActionCmd(iASetupCmd);

			SetupRxRing();
			StartRxUnit();

			SetupTxRing();

			(* install interrupt handler *)
			Objects.InstallHandler(SELF.HandleInterrupt, Machine.IRQ0+irq);

			(* mask interrupts *)
			(* ExecCmd(UnMaskAllIntr, ~keepMasks); *)
			ExecCmd(CXMask + CNAMask + ERMask, ~keepMasks);

			(* register with Network *)
			Network.registry.Add(dev, res); ASSERT(res = Plugins.Ok);
			INC(installed);

			KernelLog.Enter; KernelLog.String(dev.name); KernelLog.String("  "); Network.OutLinkAdr(dev.local, 6); KernelLog.Exit;
		END Init;

		(*
			setup the IASetup Command and put the MAC in dev.local
			if the MAC address is aabbccddeeffH:
			dev.local[0] is aa
			dev.local[1] is bb
			dev.local[2] is cc
			etc.
		*)
		PROCEDURE SetMACAddress(VAR cmd: DataBlock);
		CONST
			MacAdrBase = 0;
		VAR reg, i: INTEGER;
		BEGIN
			(* read permanent MAC address *)
			FOR i := 0 TO 2 DO
				ReadEEPROM(MacAdrBase + i, reg);	(* EEPROM registers are 2 bytes *)
				SYSTEM.PUT16(ADDRESSOF(dev.local[2*i]), reg);	(* put MAC in dev.local *)
				SYSTEM.PUT16(ADDRESSOF(cmd.data[8 + 2*i]), reg);	(* put MAC in Action Command Block *)
			END;
		END SetMACAddress;

		PROCEDURE SetByteMap8255x(VAR cmd: DataBlock);
		VAR
			byteArray: ARRAY 22 OF CHAR;

			PROCEDURE ToChar(s: SET): CHAR;
			BEGIN
				RETURN SYSTEM.VAL(CHAR, SHORT(SHORT(SYSTEM.VAL(LONGINT, s))));
			END ToChar;

		BEGIN
			byteArray[0] := 16X;
			byteArray[1] := 8X;
			byteArray[2] := 00X;
			byteArray[3] := 00X;	(* MWI disable *)
			byteArray[4] := 00X;
			byteArray[5] := 00X;
			byteArray[6] := ToChar({5, 4, 1});
			byteArray[7] := ToChar({1, 0});	(* discard short frames (frames < 64 bytes) *)
			byteArray[8] := 01X;
			byteArray[9] := 00X;
			byteArray[10] := ToChar({5, 3, 2, 1});	(* NO src adr insertion (from internal dev IA) *)
			byteArray[11] := 00X;
			byteArray[12] := ToChar({6, 5, 0});
			byteArray[13] := 00X;	(* default *)
			byteArray[14] := 0F2X;	(* default *)
			byteArray[15] := ToChar({3});
			byteArray[16] := 00X;
			byteArray[17] := ToChar({6});	(* for compatibility reason *)
			byteArray[18] := ToChar({7, 6, 5, 4, 1});	(* enable padding *)
			byteArray[19] := ToChar({7});
			byteArray[20] := ToChar({0..5});	(* prio field in byte #31 in flow control frame *)
			byteArray[21] := ToChar({2, 0});

			SYSTEM.MOVE(ADDRESSOF(byteArray[0]), ADDRESSOF(cmd.data[0]) + 08H, 22);
		END SetByteMap8255x;

		PROCEDURE SetupTxRing;
		VAR
			r: LONGINT;
			adr, physAdr: ADDRESS;
			txCmd, prev: DataBlock;
		BEGIN
			FOR r := 0 TO TxRingSize - 1 DO
				MakeBlock(txCmd, SizeOfTxCmdHdr + MaxETHFrameSize);

				adr := ADDRESSOF(txCmd.data[0]);
				SYSTEM.PUT32(adr, {15});	(* set C Bit for LinkDevice.Send => no C Bit means Send Buffer Overflow *)
				IF prev # NIL THEN
					prev.next := txCmd;
					physAdr := Machine.PhysicalAdr(adr, txCmd.size); ASSERT(physAdr # Machine.NilAdr);
					SYSTEM.PUT32(ADDRESSOF(prev.data[0]) + 04H, physAdr);	(* set link address to physical address *)
				ELSE
					actTxCmd := txCmd;	(* set first TxCmd *)
				END;
				prev := txCmd;
			END;
			(* link last TxCmd to first TxCmd *)
			txCmd.next := actTxCmd;
			physAdr := Machine.PhysicalAdr(ADDRESSOF(actTxCmd.data[0]), actTxCmd.size);
			ASSERT(physAdr # Machine.NilAdr);
			adr := ADDRESSOF(txCmd.data[0]);
			SYSTEM.PUT32(adr + 04H, Machine.Ensure32BitAddress (physAdr));
		END SetupTxRing;

		PROCEDURE SetupRxRing;
		VAR
			r: LONGINT;
			adr, physAdr: ADDRESS;
			rxFrame, prev: DataBlock;
		BEGIN
			FOR r := 0 TO RxRingSize - 1 DO
				MakeBlock(rxFrame, SizeOfRFDHdr + MaxETHFrameSize);
				(* configure RFD *)
				adr := ADDRESSOF(rxFrame.data[0]);
				SYSTEM.PUT32(adr, 0);
				SYSTEM.PUT32(adr + 0CH, 0);
				SYSTEM.PUT16(adr + 0CH + 2H, SHORT(rxFrame.size));
				IF prev # NIL THEN
					prev.next := rxFrame;
					physAdr := Machine.PhysicalAdr(adr, rxFrame.size); ASSERT(physAdr # Machine.NilAdr);
					SYSTEM.PUT32(ADDRESSOF(prev.data[0]) + 4H, physAdr);	(* set link address to physical address *)
				ELSE
					actRFD := rxFrame;	(* set first RFD *)
				END;
				prev := rxFrame;
			END;
			lastRFD := rxFrame;
			(* link last RFD TO first RFD *)
			lastRFD.next := actRFD;
			physAdr := Machine.PhysicalAdr(ADDRESSOF(actRFD.data[0]), actRFD.size); ASSERT(physAdr # Machine.NilAdr);
			adr := ADDRESSOF(lastRFD.data[0]);
			SYSTEM.PUT32(adr + 4H, Machine.Ensure32BitAddress (physAdr));
			SYSTEM.PUT32(adr, Suspend);	(* after having received the last block, suspend reception of further frames *)
		END SetupRxRing;

		PROCEDURE StartRxUnit;
		VAR
			adr: ADDRESS;
		BEGIN
			adr := Machine.PhysicalAdr(ADDRESSOF(actRFD.data[0]), actRFD.size); ASSERT(adr # Machine.NilAdr);
			WriteSCBGenPtr(Machine.Ensure32BitAddress (adr));
			ASSERT(GetRUState() # RUReady);
			ExecCmd(RUStart, keepMasks);
		END StartRxUnit;

		PROCEDURE SetCmdHdr(bits: SET; VAR cmd: DataBlock);
		BEGIN
			SYSTEM.PUT32(ADDRESSOF(cmd.data[0]), bits * {16..31});	(* set status word bits to 0 *)
		END SetCmdHdr;

		PROCEDURE MakeBlock(VAR cmd: DataBlock; dataSize: LONGINT);
		BEGIN
			NEW(cmd);
			cmd.size := dataSize;
			NEW(cmd.data, cmd.size);
		END MakeBlock;

		PROCEDURE AckIntr(interrupts: SET);
		BEGIN
			SYSTEM.PUT16(base + SCBStatus, SHORT(SYSTEM.VAL(LONGINT, interrupts)));
		END AckIntr;

		PROCEDURE GetStatus():SET;
		BEGIN
			RETURN SYSTEM.VAL(SET, LONG(SYSTEM.GET16(base + SCBStatus)));
		END GetStatus;

		PROCEDURE GetCUState(): SET;
		BEGIN
			RETURN GetStatus() * {6, 7};
		END GetCUState;

		PROCEDURE GetRUState(): SET;
		BEGIN
			RETURN GetStatus() * {2..5};
		END GetRUState;

		(*
			set the SCB command word
			keep indicates if interrupt masks of upper byte are deleted
		*)
		PROCEDURE ExecCmd(cmd: SET; keep: BOOLEAN);
		VAR masks: SET;
		BEGIN
			cmd := cmd * {16..31};	(* delete status part of cmd *)
			IF keep THEN
				masks := SYSTEM.VAL(SET, SYSTEM.GET32(base + SCBStatus));	(* get interrupt masks *)
				masks := masks * {24..31};	(* delete all but the mask bits *)
				cmd := cmd + masks;	(* merge cmd with interrupt mask *)
			END;
			SYSTEM.PUT32(base + SCBStatus, cmd);	(* writing zeros to status word has no effect *)
			WHILE (SYSTEM.GET8(base + SCBCommand) # 0) DO END;	(* wait for command done *)
		END ExecCmd;

		PROCEDURE WaitForActionCmd(VAR cmd: DataBlock);
		CONST
			C = 15;
			OK = 13;
			SecsToWait = 10;
		VAR
			t: Kernel.MilliTimer;
			status: SET;
		BEGIN
			(* check command completion *)
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ADDRESSOF(cmd.data[0])));
			Kernel.SetTimer(t, SecsToWait * 1000);
			WHILE ~(C IN status) & ~Kernel.Expired(t) DO
				status := SYSTEM.VAL(SET, SYSTEM.GET32(ADDRESSOF(cmd.data[0])));
			END;
			ASSERT(C IN status);

			(* check command ok *)
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ADDRESSOF(cmd.data[0])));
			Kernel.SetTimer(t, SecsToWait * 1000);
			WHILE ~(OK IN status) & ~Kernel.Expired(t) DO
				status := SYSTEM.VAL(SET, SYSTEM.GET32(ADDRESSOF(cmd.data[0])));
			END;
			ASSERT(OK IN status);
		END WaitForActionCmd;

		PROCEDURE ContainsRxData(VAR rxFrame: DataBlock): BOOLEAN;
		CONST
			C = 15;
			OK = 13;
			EOF = 15;
		VAR
			adr: ADDRESS;
			status: SET;
		BEGIN
			adr := ADDRESSOF(rxFrame.data[0]);
			status := SYSTEM.VAL(SET, SYSTEM.GET32(adr));
			IF (C IN status) & (OK IN status) THEN
				RETURN EOF IN SYSTEM.VAL(SET, SYSTEM.GET32(adr + 0CH));	(* data placing completed ? *)
			END;
			RETURN FALSE;
		END ContainsRxData;

		PROCEDURE StartActionCmd(VAR cmd: DataBlock);
		CONST
			ActiveState = 7;
		VAR
			adr: ADDRESS;
		BEGIN
			adr := Machine.PhysicalAdr(ADDRESSOF(cmd.data[0]), cmd.size); ASSERT(adr # Machine.NilAdr);
			WriteSCBGenPtr(Machine.Ensure32BitAddress (adr));
			ASSERT(~(ActiveState IN GetStatus()));	(* CU must not be in active state *)
			ExecCmd(CUStart, keepMasks);
			WaitForActionCmd(cmd);	(* todo: if we know the last cmd, then check for cmd done BEFORE execCmd *)
		END StartActionCmd;

		PROCEDURE WritePORT(p: SET);
		BEGIN
			SYSTEM.PUT32(base + PORTReg, p);
		END WritePORT;

		PROCEDURE WriteSCBGenPtr(val: LONGINT);
		BEGIN
			SYSTEM.PUT32(base + SCBGenPtr, val);
		END WriteSCBGenPtr;

		PROCEDURE ReadEEPROM(reg: INTEGER; VAR res: INTEGER);
		CONST
			EESK = 0;
			EECS = 1;
			EEDI = 2;
			EEDO = 3;
			ReadOpcode = 6;
		VAR
			x: SET;
			bits: INTEGER;

			PROCEDURE RaiseClk(VAR x: SET);
			VAR dummy: LONGINT;
			BEGIN
				INCL(x, EESK);
				SYSTEM.PUT16(base + SCBEeprom, SHORT(SYSTEM.VAL(LONGINT, x)));
				dummy := SYSTEM.GET16(base + SCBStatus);
				Delay(1);
			END RaiseClk;

			PROCEDURE LowerClk(VAR x: SET);
			VAR dummy: LONGINT;
			BEGIN
				EXCL(x, EESK);
				SYSTEM.PUT16(base + SCBEeprom, SHORT(SYSTEM.VAL(LONGINT, x)));
				dummy := SYSTEM.GET16(base + SCBStatus);
				Delay(1);
			END LowerClk;

			PROCEDURE ShiftOutBits(data, count: INTEGER);
			VAR
				mask: INTEGER;
				x: SET;
				dummy: LONGINT;
			BEGIN
				mask := LSH(1, count-1);
				x := GetEEPROMReg();
				EXCL(x, EEDO); EXCL(x, EEDI);
				REPEAT
					EXCL(x, EEDI);
					IF (SYSTEM.VAL(SET, LONG(data)) * SYSTEM.VAL(SET, LONG(mask)) # {}) THEN
						INCL(x, EEDI);
					END;
					SYSTEM.PUT16(base + SCBEeprom, SHORT(SYSTEM.VAL(LONGINT, x)));
					dummy := SYSTEM.GET16(base + SCBStatus);
					Delay(1);
					RaiseClk(x);
					LowerClk(x);
					mask := LSH(mask, -1);
				UNTIL mask = 0;

				EXCL(x, EEDI);
				SYSTEM.PUT16(base + SCBEeprom, SHORT(SYSTEM.VAL(LONGINT, x)));
			END ShiftOutBits;

			PROCEDURE ShiftInBits(): INTEGER;
			VAR
				x: SET;
				d, i: INTEGER;
			BEGIN
				x := GetEEPROMReg();
				EXCL(x, EEDO); EXCL(x, EEDI);
				d := 0;

				FOR i := 0 TO 15 DO
					d := LSH(d, 1);
					RaiseClk(x);

					x := GetEEPROMReg();

					EXCL(x, EEDI);
					IF (EEDO IN x) & (~ODD(d)) THEN
						d := d + 1;
					END;
					LowerClk(x);
				END;

				RETURN d;
			END ShiftInBits;

			PROCEDURE GetEEPROMReg(): SET;
				BEGIN
					RETURN SYSTEM.VAL(SET, LONG(SYSTEM.GET16(base + SCBEeprom)));
			END GetEEPROMReg;

			(*
				returns number of bits in eeprom address
				typically 6 or 8 bits according to eeprom size of 64 or 256 registers
			*)
			PROCEDURE GetEEPROMAdrSize(): INTEGER;
			VAR
				x: SET;
				size: INTEGER;
				dummy: LONGINT;
				err: BOOLEAN;
			BEGIN
				err := FALSE;

				(* enable eeprom by setting EECS *)
				x := GetEEPROMReg();
				EXCL(x, EEDI); EXCL(x, EEDO); EXCL(x, EESK);
				INCL(x, EECS);
				SYSTEM.PUT16(base + SCBEeprom, SHORT(SYSTEM.VAL(LONGINT, x)));

				ShiftOutBits(ReadOpcode, 3);	(* opcodes are 3 bits *)

				x := GetEEPROMReg();

				REPEAT
					INC(size);
					INCL(x, EEDO);
					EXCL(x, EEDI);
					SYSTEM.PUT16(base + SCBEeprom, SHORT(SYSTEM.VAL(LONGINT, x)));
					dummy := SYSTEM.GET16(base + SCBStatus);
					Delay(1);
					RaiseClk(x);
					LowerClk(x);

					IF size > 8 THEN	(* max address size is 8 bits *)
						size := 0;
						err := TRUE;
					END;
					x := GetEEPROMReg();
				UNTIL ~(EEDO IN x) OR err;

				dummy := ShiftInBits();
				CleanupEEPROM();

				RETURN size;
			END GetEEPROMAdrSize;

			PROCEDURE CleanupEEPROM;
			VAR x: SET;
			BEGIN
				x := GetEEPROMReg();

				EXCL(x, EECS); EXCL(x, EEDI);
				SYSTEM.PUT16(base + SCBEeprom, SHORT(SYSTEM.VAL(LONGINT, x)));

				RaiseClk(x);
				LowerClk(x);
			END CleanupEEPROM;

		BEGIN
			bits := GetEEPROMAdrSize();
			x := GetEEPROMReg();
			EXCL(x, EEDI); EXCL(x, EEDO); EXCL(x, EESK);
			INCL(x, EECS);
			SYSTEM.PUT16(base + SCBEeprom, SHORT(SYSTEM.VAL(LONGINT, x)));

			ShiftOutBits(ReadOpcode, 3);	(* opcodes are 3 bits *)
			ShiftOutBits(reg, bits);

			res := ShiftInBits();

			CleanupEEPROM();
		END ReadEEPROM;

		PROCEDURE HandleInterrupt;
		VAR
			status, ack: SET;
		BEGIN
			status := GetStatus();
			ack := {};

			IF IsIn(CX, status) THEN
				(* this interrupt indicates that the CU finished executing a command *)
				ack := ack + CX;
			END;

			IF IsIn(FR, status) THEN
				(* this interrupt indicates that the RU has finished receiving a frame *)
				ack := ack + FR;
				ReadFrame();
			END;

			IF IsIn(CNA, status) THEN
				(* this interrupt indicates that the CU has left the active state or has entered the idle state *)
				ack := ack + CNA;
			END;

			IF IsIn(RNR, status) THEN
				(* this interrupt indicates that the RU leaves the ready state -> no more place in the RxRing !!! *)
				KernelLog.String("Intel8255x: RNR Interrupt: RxRing too small."); KernelLog.Ln;
				ack := ack + RNR;
			END;

			IF IsIn(MDI, status) THEN
				(* this interrupt indicates when an MDI read or write cycle has completed *)
				ack := ack + MDI;
			END;

			IF IsIn(SWI, status) THEN
				(* used for software generated interrupts *)
				ack := ack + SWI;
			END;

			AckIntr(ack);
		END HandleInterrupt;

		PROCEDURE IncLastRFD;
		VAR
			prevStatus: SET;
			prevAdr, adr: ADDRESS;
		BEGIN
			prevAdr := ADDRESSOF(lastRFD.data[0]);
			lastRFD := lastRFD.next;
			adr := ADDRESSOF(lastRFD.data[0]);
			SYSTEM.PUT32(adr, Suspend);	(* set Suspend Bit *)
			SYSTEM.PUT32(adr + 0CH, 0);	(* delete EOF Bit *)
			SYSTEM.PUT16(adr + 0CH + 2H, SHORT(lastRFD.size));

			prevStatus := SYSTEM.VAL(SET, SYSTEM.GET32(prevAdr));
			SYSTEM.PUT32(prevAdr, prevStatus * {0..29, 31});	(* delete Suspend Bit (30) in previous RFD *)

			IF GetRUState() = RUSuspended THEN
				ExecCmd(RUResume, keepMasks);
			END;
		END IncLastRFD;

		PROCEDURE ReadFrame;
		CONST
			DataOfs = 10H;	(* receive buffer offset *)
		VAR
			frameAdr: ADDRESS; type, actualCount: LONGINT;
			srcAdr (* , dstAdr *) : Network.LinkAdr;
			(* handler: Network.Receiver; *)
			buf: Network.Buffer;
		BEGIN
			WHILE ContainsRxData(actRFD) DO
				frameAdr := ADDRESSOF(actRFD.data[0]);
				actualCount := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.GET32(frameAdr + 0CH)) * {0..13});

				(*SYSTEM.MOVE(frameAdr + DataOfs, ADDRESSOF(dstAdr), 6);*)
				SYSTEM.MOVE(frameAdr + DataOfs + 6, ADDRESSOF(srcAdr), 6);
				type := Network.GetNet2(actRFD.data^, DataOfs + 12);	(* Endianess ! *)
				(*
				dev.GetReceiver(type, handler, hSize);
				rcvAdr := frameAdr + DataOfs + 14 + hSize;
				rcvSize := actualCount - 14 - hSize;

				INC(dev.recvCount);
				handler(dev, SYSTEM.VAL(Network.RecvHdr, actRFD.data[DataOfs + 14]), actualCount - 14, type, srcAdr);
				*)
				buf := Network.GetNewBuffer();
				IF buf # NIL THEN
					buf.ofs := 0;
					buf.len := actualCount - 14;
					buf.src := srcAdr;
					Network.Copy(actRFD.data^, buf.data, DataOfs + 14, 0, actualCount - 14);
					dev.QueueBuffer(buf, type);
				END;

				(* delete C, OK and EOF Bits in RFD *)
				SYSTEM.PUT32(frameAdr, 0);
				SYSTEM.PUT16(frameAdr + 0CH, 0);

				actRFD := actRFD.next;
				IncLastRFD();
			END;
		END ReadFrame;

		PROCEDURE Finalize;
		BEGIN
			Objects.RemoveHandler(SELF.HandleInterrupt, Machine.IRQ0 + irq);
			Network.registry.Remove(dev);
			dev.ctrl := NIL;
			dev := NIL;
		END Finalize;

	END Controller;

VAR
	installedControllers: Controller;
	installed: LONGINT;

PROCEDURE Install*;
BEGIN {EXCLUSIVE}
	IF installed = 0 THEN
		ScanPCI(8086H, 2449H);
		ScanPCI(8086H, 1029H);	(* 82559 Ethernet Controller *)
		ScanPCI(8086H, 1031H);	(* ICH3 *)
		ScanPCI(8086H, 1032H);
		ScanPCI(8086H, 1033H);
		ScanPCI(8086H, 1034H);	(* Reserved *)
		ScanPCI(8086H, 1035H);
		ScanPCI(8086H, 1036H);	(* Reserved *)
		ScanPCI(8086H, 1037H);	(* Reserved *)
		ScanPCI(8086H, 1038H);	(* Reserved *)
		ScanPCI(8086H, 103DH);	(* In VAIO *)
		ScanPCI(8086H, 1064H); 	(* 82562ET/EZ/GT/GZ - Pro/100 VE (LOM) *)
		ScanPCI(8086H, 1209H);	(* 82559ER *)
		ScanPCI(8086H, 1229H);	(* Ethernet Pro 100 *)
	END;
END Install;

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

PROCEDURE ScanPCI(vendor, device: LONGINT);
VAR
	index, bus, dev, fct, res, irq, i: LONGINT;
	base: ADDRESS;
	d: LinkDevice;
	c: Controller;
	name: Plugins.Name;
BEGIN
	index := 0;
	WHILE (PCI.FindPCIDevice(device, vendor, index, bus, dev, fct) = PCI.Done) & (installed < 10) DO
		res := PCI.ReadConfigDword(bus, dev, fct, PCI.Adr0Reg, i); ASSERT(res = PCI.Done);
		base := i; ASSERT(~ODD(base)); 	(* memory mapped *)
		DEC(base, base MOD 16);
		Machine.MapPhysical(base, 4*K, base);

		res := PCI.ReadConfigByte(bus, dev, fct, PCI.IntlReg, irq); ASSERT(res = PCI.Done);
		NEW(d, Network.TypeEthernet, MaxETHFrameSize - 14, 6);
		name := Name;
		i := 0; WHILE name[i] # 0X DO INC(i) END;
		name[i] := CHR(ORD("0") + installed);
		name[i+1] := 0X;
		d.SetName(name);
		d.desc := Desc;

		NEW(c, d, base, irq);	(* increments "installed" when successful *)
		INC(index)
	END

END ScanPCI;

PROCEDURE IsIn(subset, set: SET): BOOLEAN;
BEGIN
	RETURN ((subset * set) = subset);
END IsIn;

PROCEDURE Cleanup;
BEGIN
	(*WHILE installedControllers # NIL DO installedControllers.Finalize; installedControllers := installedControllers.next END;*)
	IF Modules.shutdown = Modules.None THEN	(* module is being freed *)
		Remove;
	END
END Cleanup;

(*
	busy wait for ms milliseconds
*)
PROCEDURE Delay(ms: LONGINT);
VAR t: Kernel.MilliTimer;
BEGIN
	Kernel.SetTimer(t, ms);
	REPEAT UNTIL Kernel.Expired(t);
END Delay;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END Intel8255x.


PC.Compile \s Intel8255x.Mod ~
System.OpenKernelLog ~
TestNet.Mod
System.Free TestNet ~
TestNet.SetDevice "Intel8255x#0" ~
TestNet.ShowDevices ~
TestNet.SendBroadcast ~
TestNet.SendBroadcastVar 1499 ~
TestNet.SendTest ^ 1 10 100 1000 ~
Intel8255x.Test
Decoder.Decode Intel8255x.Obx ~

System.Free Intel8255x ~
System.Free TestNet ~

System.State Intel8255x ~

Aos.Call Intel8255x.Install
Aos.Call Intel8255x.Remove
