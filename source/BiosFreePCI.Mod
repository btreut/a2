MODULE PCI;	 (** author: fof -- PCI without using PCI bios (using PCI tables described in OSDev wiki ) *)

	IMPORT SYSTEM, Machine, KernelLog;

	CONST
		Trace = TRUE;

		PciAdrReg=0CF8H;
		PciDataReg = 0CFCH;

		(* PCI Configuration Registers *)
		DevReg* = 0H; CmdReg* = 4H; RevIdReg* = 8H; CLSReg* = 0CH;
		Adr0Reg* = 10H; Adr1Reg* = 14H; Adr2Reg* = 18H;
		Adr3Reg* = 1CH; Adr4Reg* = 20H; Adr5Reg* = 24H;
		CISReg* = 28H; SubvReg* = 2CH; ROMReg* = 30H; IntlReg* = 3CH;

		(* PCI Command register encoding, used as arguments for Enable *)
		IOSpace* = {0};
		MemorySpace* = {1};
		BusMaster* = {2};

		debug = TRUE;

		Done* = 0;  NoPCI* = -1;  NoBios32* = -1; Error* = -2;

		FuncNotSupported* = 81H; BadVendorId* = 83H; DeviceNotFound* = 86H;
		BadRegisterNumber* = 87H; SetFailed* = 88H; BufferTooSmall* = 89H;
		PCIServiceId = 49435024H;	(* "$PCI" *)
		PCIString = 20494350H;	(* " PCI" *)

		PCIFunctionId = 0B1H*256;
		PCIBiosPresent = 1H; findPCIDevice = 2H; findPCIClassCode = 3H; generateSpecialCycle = 6H;
		readConfigByte = 8H; readConfigWord = 9H; readConfigDword = 0AH;
		writeConfigByte = 0BH; writeConfigWord = 0CH; writeConfigDword = 0DH;
		getIrqRoutingOptions = 0EH; setPCIIrq = 0FH;

	TYPE

		RouteTable* = POINTER TO RouteTableDesc;
		RouteTableDesc* = RECORD
			busNr*, devNr*, slotNr*: LONGINT;
			linkValIntA*, linkValIntB*, linkValIntC*, linkValIntD*: CHAR;
			IrqBitmapA*, IrqBitmapB*, IrqBitmapC*, IrqBitmapD*: SET;
			next*: RouteTable
		END;
		(*
		RouteBuffer = RECORD
			BufferSize, SegSelector: INTEGER;
			DataBufferAdr: ADDRESS
		END;
		*)

		Pci* = RECORD bus*, device*, function*: LONGINT END;
	VAR
		pciEnabled: BOOLEAN;


	PROCEDURE PCIPresent*(VAR version, lastPCIbus, hwMech: LONGINT): LONGINT;
	VAR res: LONGINT; pci: Pci; r0: LONGINT;
	BEGIN {EXCLUSIVE}
		IF pciEnabled THEN
			StartIterate(pci);
			lastPCIbus := 0;
			REPEAT
				res := PCIReadConfig32(pci.bus, pci.device, pci.function, 0, r0);
				IF r0 # LONGINT(0FFFFFFFFH) THEN
					IF lastPCIbus < pci.bus THEN lastPCIbus := pci.bus END;
				END;
			UNTIL ~Iterate(pci);
			res := Done;
			IF debug THEN
				KernelLog.String("PCIPresent, lastbus ="); KernelLog.Int(lastPCIbus,1); KernelLog.Ln;
			END
		ELSE
			res := NoPCI
		END;
		RETURN res
	END PCIPresent;

	PROCEDURE FindPCIDevice*(devId, vendId, idx: LONGINT; VAR busNr, devNr, fktNr: LONGINT): LONGINT;
	VAR pci: Pci; r0, vendorId, deviceId, index,res: LONGINT;
	BEGIN {EXCLUSIVE}
		IF pciEnabled THEN
			StartIterate(pci); index := 0;
			REPEAT
				res := PCIReadConfig32(pci.bus, pci.device, pci.function, 0, r0);
				IF r0 # LONGINT(0FFFFFFFFH) THEN
					vendorId := r0 MOD 10000H;
					deviceId := r0 DIV 10000H MOD 10000H;
					IF (devId = deviceId) & (vendId = vendorId) THEN
						IF idx = index THEN
							busNr := pci.bus; devNr := pci.device; fktNr := pci.function;
							IF debug THEN
								KernelLog.String("FindPCIDevice "); 
								KernelLog.Int(devId,1); KernelLog.String(", "); 
								KernelLog.Int(vendId,1); KernelLog.String(","); 
								KernelLog.Int(idx,1);
								KernelLog.String(" found."); KernelLog.Ln; 
							END;
							RETURN Done
						ELSE INC(index)
						END;
					END;
				END;
			UNTIL ~Iterate(pci);
			res := DeviceNotFound
		ELSE
			res := NoPCI
		END;
		RETURN res
	END FindPCIDevice;

	PROCEDURE FindPCIClassCode*(classCode, idx: LONGINT; VAR busNr, devNr, fktNr: LONGINT): LONGINT;
	VAR pci: Pci; r0, r8,  index,res,class: LONGINT;
	BEGIN {EXCLUSIVE}
		IF pciEnabled THEN
			StartIterate(pci);
			REPEAT
				res := PCIReadConfig32(pci.bus, pci.device, pci.function, 0, r0);
				IF r0 # LONGINT(0FFFFFFFFH) THEN
					res := PCIReadConfig32(pci.bus, pci.device, pci.function, 8, r8);
					class := r8 DIV 100H MOD 1000000H;
					IF (classCode = class) THEN
						IF idx = index THEN
							busNr := pci.bus; devNr := pci.device; fktNr := pci.function;
							IF debug THEN
								KernelLog.String("FindPCIClassCode "); 
								KernelLog.Int(classCode,1); KernelLog.String(","); KernelLog.Int(idx,1);
								KernelLog.String(" found."); KernelLog.Ln; 
							END;
							RETURN Done
						ELSE INC(index)
						END;
					END;
				END;
			UNTIL ~Iterate(pci);
			res := DeviceNotFound;
		ELSE
			res := NoPCI
		END;
		RETURN res
	END FindPCIClassCode;

	PROCEDURE GenerateSpecialCycle*(busNr, specCycleData: LONGINT): LONGINT;
	VAR res: LONGINT;
	BEGIN {EXCLUSIVE}
		IF pciEnabled THEN
			(*
			eax := PCIFunctionId + generateSpecialCycle;
			ebx := busNr*100H; edx := specCycleData;
			state := Machine.DisableInterrupts();
			pcicall(pciEntry, eax, ebx, ecx, edx, esi, edi, eflags);
			Machine.RestoreInterrupts(state);
			res := (eax DIV 100H) MOD 100H;  ASSERT(~((0 IN eflags) & (res=0)));
			IF debug THEN
				KernelLog.String("GenerateSpecialCycle:"); KernelLog.Ln;
				OutRegs(eax, ebx, ecx, edx, esi, edi, eflags)
			END
			*)
		ELSE
			res := NoPCI
		END;
		RETURN res
	END GenerateSpecialCycle;

	PROCEDURE GetIrqRoutingOptions*(VAR rt: RouteTable; VAR IrqBitmap: SET): LONGINT;
	CONST dbN = 16*8;
	VAR
		res: LONGINT;
		(*eflags, state: SET;
		rb: RouteBuffer; db: ARRAY dbN OF CHAR;
		last: RouteTable;
		*)
	BEGIN {EXCLUSIVE}
		IF pciEnabled THEN
			(*
			eax := PCIFunctionId + getIrqRoutingOptions;
			rb.BufferSize := dbN; rb.SegSelector := 0; rb.DataBufferAdr := ADDRESSOF(db[0]);
			ebx := 0H; edi := Machine.Ensure32BitAddress(SYSTEM.VAL (ADDRESS, rb));
			state := Machine.DisableInterrupts();
			pcicall(pciEntry, eax, ebx, ecx, edx, esi, edi, eflags);
			Machine.RestoreInterrupts(state);
			res := (eax DIV 100H) MOD 100H;  ASSERT(~((0 IN eflags) & (res=0)));
			ASSERT(res # BufferTooSmall); (* Increase dbN on Trap *)
			IF ~(0 IN eflags) & (res = Done)  THEN
				IrqBitmap := SYSTEM.VAL(SET, ebx);
				NEW(rt); rt.next := NIL; last := rt; i := 0;
				WHILE i < rb.BufferSize DO
					NEW(last.next); last := last.next; last.next := NIL;
					last.busNr := ORD(db[i]); INC(i);
					last.devNr := ORD(db[i]) DIV 8; INC(i);
					last.linkValIntA := db[i]; INC(i);
					last.IrqBitmapA := SYSTEM.VAL(SET, LONG(ORD(db[i])+ORD(db[i+1])*100H)); INC(i, 2);
					last.linkValIntB := db[i]; INC(i);
					last.IrqBitmapB := SYSTEM.VAL(SET, LONG(ORD(db[i])+ORD(db[i+1])*100H)); INC(i, 2);
					last.linkValIntC:= db[i]; INC(i);
					last.IrqBitmapC := SYSTEM.VAL(SET, LONG(ORD(db[i])+ORD(db[i+1])*100H)); INC(i, 2);
					last.linkValIntD := db[i]; INC(i);
					last.IrqBitmapD := SYSTEM.VAL(SET, LONG(ORD(db[i])+ORD(db[i+1])*100H)); INC(i, 2);
					last.slotNr := ORD(db[i]); INC(i);
					INC(i)	(* reserved byte *)
				END;
				rt := rt.next
			END;
			IF debug THEN
				KernelLog.String("GetIrqRoutingOptions:"); KernelLog.Ln;
				OutRegs(eax, ebx, ecx, edx, esi, edi, eflags)
			END
			*)
		ELSE
			res := NoPCI
		END;
		RETURN res
	END GetIrqRoutingOptions;

	PROCEDURE SetPCIIrq*(IntPin, IrqNum, busNr, devNr, fktNr: LONGINT): LONGINT;
	VAR res:LONGINT;
	BEGIN {EXCLUSIVE}
		IF pciEnabled THEN
			(*
			eax := PCIFunctionId + setPCIIrq;
			ecx := IrqNum*100H + IntPin; ebx := busNr*100H+devNr*8+fktNr;
			state := Machine.DisableInterrupts();
			pcicall(pciEntry, eax, ebx, ecx, edx, esi, edi, eflags);
			Machine.RestoreInterrupts(state);
			res := (eax DIV 100H) MOD 100H;  ASSERT(~((0 IN eflags) & (res=0)));
			IF debug THEN
				KernelLog.String("SetPCIHwInt:"); KernelLog.Ln;
				OutRegs(eax, ebx, ecx, edx, esi, edi, eflags)
			END
			*)
		ELSE
			res := NoPCI
		END;
		RETURN res
	END SetPCIIrq;

	(** Set bits included in <mask> in the PCI command register if not set already *)
	PROCEDURE Enable*(mask : SET; busNr, devNr, fktNr : LONGINT) : LONGINT;
	VAR cmdReg : LONGINT; res : LONGINT;
	BEGIN
		res := ReadConfigWord(busNr, devNr, fktNr, CmdReg, cmdReg);
		IF (res = Done) THEN
			IF mask - SYSTEM.VAL(SET, cmdReg) # {} THEN
				cmdReg := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, cmdReg) + mask);
				res := WriteConfigWord(busNr, devNr, fktNr, CmdReg, cmdReg);
				IF (res = Done) THEN (* maybe the device does not implement all bits writable... check! *)
					res := ReadConfigWord(busNr, devNr, fktNr, CmdReg, cmdReg);
					IF (res = Done) THEN
						IF mask - SYSTEM.VAL(SET, cmdReg) # {} THEN (* at least one bit is not set *)
							res := Error;
						END;
					END;
				END;
			END;
		END;
		RETURN res;
	END Enable;

	PROCEDURE ReadConfigByte*(busNr, devNr, fktNr, regNr: LONGINT; VAR regVal: LONGINT): LONGINT;
	BEGIN
		RETURN PCIReadConfig8(busNr, devNr, fktNr, regNr, regVal)
	END ReadConfigByte;

	PROCEDURE ReadConfigWord*(busNr, devNr, fktNr, regNr: LONGINT; VAR regVal: LONGINT): LONGINT;
	BEGIN
		ASSERT(regNr MOD 2 = 0);
		RETURN PCIReadConfig16(busNr, devNr, fktNr, regNr, regVal)
	END ReadConfigWord;

	PROCEDURE ReadConfigDword*(busNr, devNr, fktNr, regNr: LONGINT; VAR regVal: LONGINT): LONGINT;
	BEGIN
		ASSERT(regNr MOD 4 = 0);
		RETURN PCIReadConfig32(busNr, devNr, fktNr, regNr, regVal)
	END ReadConfigDword;

	PROCEDURE WriteConfigByte*(busNr, devNr, fktNr, regNr, regVal: LONGINT): LONGINT;
	BEGIN
		RETURN PCIWriteConfig8(busNr, devNr, fktNr, regNr, regVal)
	END WriteConfigByte;

	PROCEDURE WriteConfigWord*(busNr, devNr, fktNr, regNr, regVal: LONGINT): LONGINT;
	BEGIN
		ASSERT(regNr MOD 2 = 0);
		RETURN PCIWriteConfig16(busNr, devNr, fktNr, regNr, regVal)
	END WriteConfigWord;

	PROCEDURE WriteConfigDword*(busNr, devNr, fktNr, regNr, regVal: LONGINT): LONGINT;
	BEGIN
		ASSERT(regNr MOD 4 = 0);
		RETURN PCIWriteConfig32(busNr, devNr, fktNr, regNr, regVal)
	END WriteConfigDword;


	PROCEDURE Show*;
	VAR version, lastPCIBus, hwMech, res : LONGINT;
	BEGIN
		IF ~PCIDisabled() THEN
			res := PCIPresent(version, lastPCIBus, hwMech);
			IF (res = Done) THEN
				KernelLog.Enter;
				KernelLog.String("PCI: "); KernelLog.Int(lastPCIBus + 1, 0); KernelLog.String(" bus(ses) found, PCI version: ");
				KernelLog.Hex(version DIV 256, -2); KernelLog.Char("."); KernelLog.Hex(version MOD 256, -2);
				KernelLog.Exit;
			ELSE
				KernelLog.Enter; KernelLog.String("PCI: No bus found."); KernelLog.Exit;
			END;
		ELSE
			KernelLog.Enter; KernelLog.String("PCI: Not available (Disabled by user)."); KernelLog.Exit;
		END;
	END Show;


	PROCEDURE GetAdr1(pciBus, pciDev, pciFn, reg, len: LONGINT; VAR adr, dataAdr: LONGINT);
	BEGIN
		adr := LONGINT(80000000H) + ASH(pciBus,16) + ASH(pciDev, 11) + ASH(pciFn, 8);
		adr := adr + SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,reg) * SYSTEM.VAL(SET,0FCH));
		adr := adr + ASH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,reg) * SYSTEM.VAL(SET,0F00H)), 16);
		CASE len OF
			8: dataAdr := PciDataReg + SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,reg) * SYSTEM.VAL(SET,3));
			|16: dataAdr := PciDataReg + SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,reg) * SYSTEM.VAL(SET,2));
			|32: dataAdr := PciDataReg;
		END;
	END GetAdr1;

	PROCEDURE PCIReadConfig32(pciBus, pciDev, pciFn, reg: LONGINT; VAR val: LONGINT): LONGINT;
	VAR adr, dataAdr: LONGINT; state: SET; res: LONGINT;
	BEGIN
		IF pciEnabled THEN
			state := Machine.DisableInterrupts();
			GetAdr1(pciBus, pciDev, pciFn, reg, 32, adr, dataAdr);
			Machine.Portout32(PciAdrReg, adr);
			Machine.Portin32(dataAdr, val);
			Machine.RestoreInterrupts(state);
			res := Done;
		ELSE
			res := NoPCI
		END;
		RETURN res
	END PCIReadConfig32;

	PROCEDURE PCIReadConfig16(pciBus, pciDev, pciFn, reg: LONGINT; VAR val: LONGINT): LONGINT;
	VAR adr, dataAdr: LONGINT; state: SET;res: LONGINT; int: INTEGER;
	BEGIN
		IF pciEnabled THEN
			state := Machine.DisableInterrupts();
			GetAdr1(pciBus, pciDev, pciFn, reg, 16, adr, dataAdr);
			Machine.Portout32(PciAdrReg, adr);
			Machine.Portin16(dataAdr, int);
			val := int;
			Machine.RestoreInterrupts(state);
			res := Done;
		ELSE
			res := NoPCI
		END;
		RETURN res
	END PCIReadConfig16;

	PROCEDURE PCIReadConfig8(pciBus, pciDev, pciFn, reg: LONGINT; VAR val: LONGINT): LONGINT;
	VAR adr, dataAdr: LONGINT; state: SET;res: LONGINT; chr: CHAR;
	BEGIN
		IF pciEnabled THEN
			state := Machine.DisableInterrupts();
			GetAdr1(pciBus, pciDev, pciFn, reg, 8, adr, dataAdr);
			Machine.Portout32(PciAdrReg, adr);
			Machine.Portin8(dataAdr, chr);
			val := ORD(chr);
			Machine.RestoreInterrupts(state);
			res := Done;
		ELSE
			res := NoPCI
		END;
		RETURN res
	END PCIReadConfig8;

	PROCEDURE PCIWriteConfig32(pciBus, pciDev, pciFn: LONGINT; reg: LONGINT;  val: LONGINT): LONGINT;
	VAR adr, dataAdr: LONGINT; state: SET;res: LONGINT;
	BEGIN
		IF pciEnabled THEN
			state := Machine.DisableInterrupts();
			GetAdr1(pciBus, pciDev, pciFn, reg, 32, adr, dataAdr);
			Machine.Portout32(PciAdrReg, adr);
			Machine.Portout32(dataAdr, val);
			Machine.RestoreInterrupts(state);
			res := Done;
		ELSE
			res := NoPCI
		END;
		RETURN res
	END PCIWriteConfig32;

	PROCEDURE PCIWriteConfig16(pciBus, pciDev, pciFn: LONGINT; reg: LONGINT;  val: LONGINT): LONGINT;
	VAR adr, dataAdr: LONGINT; state: SET;res: LONGINT;
	BEGIN
		IF pciEnabled THEN
			state := Machine.DisableInterrupts();
			GetAdr1(pciBus, pciDev, pciFn, reg, 16, adr, dataAdr);
			Machine.Portout32(PciAdrReg, adr);
			Machine.Portout16(dataAdr, SHORT(val));
			Machine.RestoreInterrupts(state);
			res := Done;
		ELSE
			res := NoPCI
		END;
		RETURN res
	END PCIWriteConfig16;

	PROCEDURE PCIWriteConfig8(pciBus, pciDev, pciFn: LONGINT; reg: LONGINT;  val: LONGINT): LONGINT;
	VAR adr, dataAdr: LONGINT; state: SET;res: LONGINT;
	BEGIN
		IF pciEnabled THEN
			state := Machine.DisableInterrupts();
			GetAdr1(pciBus, pciDev, pciFn, reg, 8, adr, dataAdr);
			Machine.Portout32(PciAdrReg, adr);
			Machine.Portout8(dataAdr, CHR(val));
			Machine.RestoreInterrupts(state);
			res := Done;
		ELSE
			res := NoPCI
		END;
		RETURN res
	END PCIWriteConfig8;

	PROCEDURE PCICheckType1(): BOOLEAN;
	VAR in,temp: LONGINT; works: BOOLEAN; state: SET;
	BEGIN
		state := Machine.DisableInterrupts();
		Machine.Portout8(PciDataReg, 1X);
		Machine.Portin32(PciAdrReg, temp);
		Machine.Portout32(PciAdrReg, LONGINT(80000000H));
		Machine.Portin32(PciAdrReg, in);
		IF in = LONGINT(80000000H) THEN works := TRUE ELSE works := FALSE END;
		Machine.Portout32(PciAdrReg, temp);
		Machine.RestoreInterrupts(state);
		RETURN works
	END PCICheckType1;

	(* not implemented type 2 implemented on older machines ...
	PROCEDURE PCICheckType2(): BOOLEAN;
	CONST PciAdr=0CF8H; DataAdr=0CFBH; PciAdr2 = 0CFAH;
	VAR i,j:CHAR;
	VAR works: BOOLEAN;
	BEGIN
		Machine.Portout8(DataAdr, 0X);
		Machine.Portout8(PciAdr, 0X);
		Machine.Portout8(PciAdr2, 0X);
		Machine.Portin8(PciAdr, i);
		Machine.Portin8(PciAdr2, j);
		IF (i=0X) & (j=0X) THEN works := TRUE ELSE works := FALSE END;
		RETURN works
	END PCICheckType2;
	*)

	PROCEDURE StartIterate*(VAR pci: Pci);
	BEGIN pci.bus := 0; pci.device := 0; pci.function := 0
	END StartIterate;

	PROCEDURE Iterate*(VAR pci: Pci): BOOLEAN;
	VAR hdrType,res: LONGINT; multifunction: BOOLEAN;
	BEGIN
		IF pci.function = 0 THEN
			(* check if multi-function device *)
			res := PCIReadConfig32(pci.bus, pci.device, pci.function, 0CH, hdrType);
			multifunction := 23 IN SYSTEM.VAL(SET, hdrType);
		ELSE multifunction := TRUE
		END;
		INC(pci.function);
		
		IF ~multifunction OR (pci.function >= 8) THEN
			pci.function := 0;
			INC(pci.device);
			IF pci.device >= 32 THEN
				pci.device := 0;
				INC(pci.bus);
				IF pci.bus > 255 THEN RETURN FALSE END;
			END;
		END;
		RETURN TRUE
	END Iterate;

	PROCEDURE DisplayDeviceClass(class, subclass: LONGINT);
	BEGIN
		CASE class OF
		1:	KernelLog.String("disk controller:");
			CASE subclass OF
			0: KernelLog.String("SCSI")
			|1: KernelLog.String("IDE")
			|2: KernelLog.String("floppy");
			|3: KernelLog.String("IPI");
			|4: KernelLog.String("RAID");
			|80H: KernelLog.String("Other ");
			ELSE KernelLog.String("unkown")
			END;
		|2:	KernelLog.String("network controller:");
			CASE subclass OF
			0: KernelLog.String("Ethernet");
			|1: KernelLog.String("Token ring");
			|2: KernelLog.String("FDDI");
			|3: KernelLog.String("ATM");
			|80H: KernelLog.String("other");
			ELSE KernelLog.String("unknown");
			END;
		|3:	KernelLog.String("display controller:");
			CASE subclass OF
			0: KernelLog.String("VGA");
			|1: KernelLog.String("XGA");
			|80H: KernelLog.String("other");
			ELSE KernelLog.String("unknown");
			END;
		|4:	KernelLog.String("multimedia controller:");
			CASE subclass OF
			0: KernelLog.String("Video");
			|1: KernelLog.String("Audio");
			|80H: KernelLog.String("other");
			ELSE KernelLog.String("unknown");
			END;
		|5:	KernelLog.String("memory:");
			CASE subclass OF
			0: KernelLog.String("RAM");
			|1: KernelLog.String("Flash");
			|80H: KernelLog.String("other");
			ELSE KernelLog.String("unknown");
			END;
		|6:	KernelLog.String("bridge:");
			CASE subclass OF
			0: KernelLog.String("Host/PCI")
			|1: KernelLog.String("PCI/ISA")
			|2: KernelLog.String("PCI/EISA");
			|3: KernelLog.String("PCI/Microchannel");
			|4: KernelLog.String("PCI/PCI");
			|5: KernelLog.String("PCI/PCMCIA");
			|6: KernelLog.String("PCI/NuBus");
			|7: KernelLog.String("PCI/CardBus");
			|80H: KernelLog.String("Other ");
			ELSE KernelLog.String("unkown")
			END;
		|7:	KernelLog.String("communications device:");
			CASE subclass OF
			0: KernelLog.String("Serial")
			|1: KernelLog.String("Parallel")
			|80H: KernelLog.String("Other ");
			ELSE KernelLog.String("unkown")
			END;
		|8:	KernelLog.String("system device:");
			CASE subclass OF
			0: KernelLog.String("PIC")
			|1: KernelLog.String("DMA")
			|2: KernelLog.String("Timer")
			|3: KernelLog.String("RTC")
			|80H: KernelLog.String("Other ");
			ELSE KernelLog.String("unkown")
			END;
		|9:	KernelLog.String("HID:");
			CASE subclass OF
			0: KernelLog.String("Keyboard")
			|1: KernelLog.String("Digitizer")
			|2: KernelLog.String("Mouse")
			|80H: KernelLog.String("Other ");
			ELSE KernelLog.String("unkown")
			END;
		|10:	KernelLog.String("dock:");
			CASE subclass OF
			0: KernelLog.String("Generic")
			|80H: KernelLog.String("Other ");
			ELSE KernelLog.String("unkown")
			END;
		|11:	KernelLog.String("CPU:");
			CASE subclass OF
			0: KernelLog.String("386")
			|1: KernelLog.String("486")
			|2: KernelLog.String("Pentium")
			|10H: KernelLog.String("Alpha")
			|20H: KernelLog.String("PowerPC")
			|40H: KernelLog.String("Coprocessor")
			|80H: KernelLog.String("Other ");
			ELSE KernelLog.String("unkown")
			END;
		|12:	KernelLog.String("serial bus controller:");
			CASE subclass OF
			0: KernelLog.String("Firewire")
			|1: KernelLog.String("ACCESS")
			|2: KernelLog.String("SSA")
			|3: KernelLog.String("USB")
			ELSE KernelLog.String("unkown")
			END;
		ELSE
			KernelLog.String("unknown class");
		END;
	END DisplayDeviceClass;

	PROCEDURE TracePCIDevices;
	VAR r0,r8,r10 : LONGINT; pci: Pci; res, class, subclass, api, vendorId, deviceId: LONGINT;
	BEGIN
		IF pciEnabled THEN
			KernelLog.String("PCI Devices"); KernelLog.Ln;
			StartIterate(pci);
			REPEAT
				res := PCIReadConfig32(pci.bus, pci.device, pci.function, 0, r0);
				IF r0 # LONGINT(0FFFFFFFFH) THEN
					res := PCIReadConfig32(pci.bus, pci.device, pci.function, 8, r8);
					IF r8 # LONGINT(0FFFFFFFFH) THEN
						vendorId := r0 MOD 10000H;
						deviceId := r0 DIV 10000H MOD 10000H;
						class := r8 DIV 1000000H MOD 100H;
						subclass := r8 DIV 10000H MOD 100H;
						api := r8 DIV 100H MOD 100H;

						KernelLog.String("device bus="); KernelLog.Int(pci.bus,1);
						KernelLog.String(" pciDev="); KernelLog.Int(pci.device,1);
						KernelLog.String(" pciFn="); KernelLog.Int(pci.function,1);
						KernelLog.String(" vendorId="); KernelLog.Int(vendorId,1);
						KernelLog.String(" deviceId="); KernelLog.Int(deviceId,1);
						KernelLog.String(" class="); KernelLog.Int(class,1);
						KernelLog.String(" subclass="); KernelLog.Int(subclass,1);
						KernelLog.String(" api="); KernelLog.Int(api,1);
						KernelLog.String(" classCode= "); KernelLog.Address(r8 DIV 100H MOD 1000000H); 
						KernelLog.String(" : ");
						DisplayDeviceClass(class, subclass);
						KernelLog.Ln;
					END;
				END;
			UNTIL ~Iterate(pci);
		ELSE
			KernelLog.String("No PCI type 1 found"); KernelLog.Ln;
		END;
	END TracePCIDevices;


PROCEDURE PCIDisabled() : BOOLEAN;
VAR string : ARRAY 2 OF CHAR;
BEGIN
	Machine.GetConfig("DisablePCI", string);
	RETURN string = "1";
END PCIDisabled;

BEGIN
	pciEnabled := FALSE;
	IF ~PCIDisabled() THEN
		pciEnabled := PCICheckType1();
		IF Trace THEN TracePCIDevices END;
	END;
	Show;
END PCI.

useful sources: 

http://tldp.org/LDP/tlk/dd/pci.html
http://my.execpc.com/~geezer/code/pci.c 


(**
Notes

PCI devices are uniquely identified by their vendor ID and device ID.  For example, a 3Com 905B Etherlink XL ethernet card has vendor ID 10B7H (3Com) and device ID 9055H.  To get access to this card, use the FindPCIDevice call.  The third parameter (idx) is used to find multiple instances of the card.  If set to 0, the first card is returned; if set to 1, the second; etc.  The last three parameters return the bus number, device number and function number of the card, respectively.  This triple can be used with the other calls (e.g., ReadConfig..., WriteConfig...) to address a specific card.

Example:
	VAR res, bus, dev, fkt: LONGINT;
		(* look for a 3Com 905B ethernet card *)
	res := PCI.FindPCIDevice(9055H, 10B7H, 0, bus, dev, fkt);
	IF res = PCI.Done THEN (* found at (bus, dev, fkt) *) END

The PCI configuration area is a standardized set of registers provided by every PCI device.  It can be accessed using the ReadConfig... and WriteConfig... calls.  Typically, registers 10H, 14H, ..., 24H specify the base addresses of a card.  Bit 0 is 1 if the address is in the I/O space, and 0 if it is in the physical memory space.  For I/O addresses, the bottom two bits should be masked off, and for physical memory addresses, the bottom 4 bits should be masked off.

Example:
	VAR res, adr: LONGINT;
		(* find the I/O base address of the ethernet controller *)
	res := PCI.ReadConfigDword(bus, dev, fkt, 10H, adr);
	IF res = PCI.Done THEN
		ASSERT(ODD(adr));	(* must be I/O mapped *)
		DEC(adr, adr MOD 4);	(* strip lower 2 bits *)
		...
		SYSTEM.PORTIN(adr+X, x)	(* read some device register *)
	END

To access a memory-mapped device, its address range has to be mapped into the virtual address space first.

Example:
	CONST Size = 4096;	(* the device has 4KB of registers *)
	VAR res, physAdr, virtAdr: LONGINT;
		(* find the base address of a memory-mapped device *)
	res := PCI.ReadConfigDword(bus, dev, fkt, 10H, physAdr);
	IF res = PCI.Done THEN
		ASSERT(~ODD(physAdr));	(* must be memory mapped *)
		DEC(physAdr, physAdr MOD 16);	(* strip lower 4 bits *)
		Machine.MapPhysical(physAdr, Size, virtAdr);
		...
		x := SYSTEM.GET32(virtAdr+X);	(* read some device register *)
		...
		Machine.UnmapPhysical(virtAdr, Size)
	END
*)
