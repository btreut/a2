MODULE PCI;	(** non-portable *)
(** AUTHOR "ryser"; PURPOSE "PCI bus interface (compatible with Native Oberon)"; *)

(* Contributed by P. Ryser to the System 3 project *)

	IMPORT SYSTEM, Machine, KernelLog;

	CONST
		Trace = FALSE;

		(* PCI Configuration Registers *)
		DevReg* = 0H; CmdReg* = 4H; RevIdReg* = 8H; CLSReg* = 0CH;
		Adr0Reg* = 10H; Adr1Reg* = 14H; Adr2Reg* = 18H;
		Adr3Reg* = 1CH; Adr4Reg* = 20H; Adr5Reg* = 24H;
		CISReg* = 28H; SubvReg* = 2CH; ROMReg* = 30H; IntlReg* = 3CH;

		(* PCI Command register encoding, used as arguments for Enable *)
		IOSpace* = {0};
		MemorySpace* = {1};
		BusMaster* = {2};

		debug = FALSE;

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

		RouteBuffer = RECORD
			BufferSize, SegSelector: INTEGER;
			DataBufferAdr: ADDRESS
		END;

		Pci* = RECORD bus*, device*, function*: LONGINT END;

	VAR
		Bios32Def: RECORD
			sig: ARRAY 4 OF CHAR;
			entry: LONGINT;
			rev, len, chksum: CHAR;
			res: ARRAY 5 OF CHAR;
		END;

		bios32: BOOLEAN;

		pci: BOOLEAN;
		pciEntry: ADDRESS;

	PROCEDURE BiosServiceDirectory(sadr: ADDRESS; sid, fsel: LONGINT; VAR badr: ADDRESS; VAR len, entry: LONGINT): CHAR;
	CODE {SYSTEM.AMD64}
		MOV EAX, [RBP + sid]
		MOV EBX, [RBP + fsel]

		PUSH QWORD [RBP + sadr]
		MOV WORD [RSP + 4], 3*8
		DB 0FFH, 01CH, 024h ; CALL FAR [RSP]

		MOV R8, [RBP + badr]
		MOV [R8], RBX
		MOV R8, [RBP + len]
		MOV [R8], ECX
		MOV R8, [RBP + entry]
		MOV [R8], EDX
	END BiosServiceDirectory;

	PROCEDURE FindBios32Service*(serviceId, serviceFkt: LONGINT; VAR serviceAdr: ADDRESS; VAR serviceLen, entryOffset: LONGINT): LONGINT;
	VAR ch: CHAR; res: LONGINT; state: SET;
	BEGIN {EXCLUSIVE}
		IF bios32 THEN
			state := Machine.DisableInterrupts();
			ch := BiosServiceDirectory(Bios32Def.entry, serviceId, serviceFkt,
					serviceAdr, serviceLen, entryOffset);
			Machine.RestoreInterrupts(state);
			res := ORD(ch)
		ELSE
			res := NoBios32
		END;
		RETURN res
	END FindBios32Service;

	PROCEDURE DetectBios32;
	VAR adr, chksum, i: LONGINT; s: ARRAY 16 OF CHAR;
	BEGIN
		adr := 0E0000H; chksum := 0FFH;
		REPEAT
			SYSTEM.MOVE(adr, ADDRESSOF(s[0]), 16);
			IF (s[0] = "_") & (s[1] = "3") & (s[2] = "2") & (s[3] = "_") THEN
				chksum := 0; i := 0;
				WHILE i < 16 DO
					chksum := chksum + ORD(s[i]);
					IF FALSE & debug THEN KernelLog.Int(ORD(s[i]), 1); KernelLog.Char(" ") END;
					INC(i)
				END;
				chksum := chksum MOD 256;
			END;
			INC(adr, 16)
		UNTIL (chksum = 0) OR (adr = 0100000H);
		bios32 := chksum = 0;
		IF bios32 THEN
			SYSTEM.MOVE(ADDRESSOF(s[0]), ADDRESSOF(Bios32Def), 16);
			IF Trace THEN
				KernelLog.String("PCI Bios32 detected at: "); KernelLog.Hex(adr-16, 8); KernelLog.Ln;
				KernelLog.String("  Sig: ");
				KernelLog.Char(Bios32Def.sig[0]); KernelLog.Char(Bios32Def.sig[1]);
				KernelLog.Char(Bios32Def.sig[2]); KernelLog.Char(Bios32Def.sig[3]);
				KernelLog.String(", Entry: "); KernelLog.Hex(Bios32Def.entry, 8);
				KernelLog.String(", Revision: "); KernelLog.Int(ORD(Bios32Def.rev), 1);
				KernelLog.String(", Length: "); KernelLog.Int(ORD(Bios32Def.len)*16, 1);
				KernelLog.String(", Checksum: "); KernelLog.Int(ORD(Bios32Def.chksum), 1);
				KernelLog.Ln
			END
		END
	END DetectBios32;

		PROCEDURE pcicall(entry:ADDRESS; VAR peax,pebx,pecx,pedx,pesi,pedi:LONGINT; VAR eflags: SET);
		CODE {SYSTEM.AMD64}
			MOV R8, [RBP + peax]
			MOV EAX, [R8]
			MOV R8, [RBP + pebx]
			MOV EBX, [R8]
			MOV R8, [RBP + pecx]
			MOV ECX, [R8]
			MOV R8, [RBP + pedx]
			MOV EDX, [R8]
			MOV R8, [RBP + pesi]
			MOV ESI, [R8]
			MOV R8, [RBP + pedi]
			MOV EDI, [R8]

			PUSH QWORD [RBP + entry]
			MOV WORD [RSP + 4], 3*8
			DB 0FFH, 01CH, 024h; FAR CALL [RSP]

			PUSHFQ
			MOV R8, [RBP + peax]
			MOV [R8], EAX
			MOV R8, [RBP + pebx]
			MOV [R8], EBX
			MOV R8, [RBP + pecx]
			MOV [R8], ECX
			MOV R8, [RBP + pedx]
			MOV [R8], EDX
			MOV R8, [RBP + pesi]
			MOV [R8], ESI
			MOV R8, [RBP + pedi]
			MOV [R8], EDI
			MOV R8, [RBP + eflags]
			POP R9
			MOV [R8], R9
		END pcicall;

	PROCEDURE OutRegs(eax, ebx, ecx, edx, esi, edi: LONGINT; eflags: SET);
	BEGIN
		IF debug THEN
			KernelLog.String("   eax: "); KernelLog.Hex(eax, 8); KernelLog.Ln;
			KernelLog.String("   ebx: "); KernelLog.Hex(ebx, 8); KernelLog.Ln;
			KernelLog.String("   ecx: "); KernelLog.Hex(ecx, 8); KernelLog.Ln;
			KernelLog.String("   edx: "); KernelLog.Hex(edx, 8); KernelLog.Ln;
			KernelLog.String("   esi: "); KernelLog.Hex(esi, 8); KernelLog.Ln;
			KernelLog.String("   edi: "); KernelLog.Hex(edi, 8); KernelLog.Ln;
			KernelLog.String("   eflags: "); KernelLog.Hex(SYSTEM.VAL(LONGINT, eflags), 8); KernelLog.Ln
		END
	END OutRegs;

	PROCEDURE PCIPresent*(VAR version, lastPCIbus, hwMech: LONGINT): LONGINT;
	VAR res, eax, ebx, ecx, edx, esi, edi: LONGINT; eflags, state: SET;
	BEGIN {EXCLUSIVE}
		IF pci THEN
			eax := PCIFunctionId + PCIBiosPresent;
			state := Machine.DisableInterrupts();
			pcicall(pciEntry, eax, ebx, ecx, edx, esi, edi, eflags);
			Machine.RestoreInterrupts(state);
			res := (eax DIV 100H) MOD 100H;
			IF (edx = PCIString) & ~(0 IN eflags) & (res = Done) THEN
				version := ebx MOD 10000H;
				lastPCIbus := ecx MOD 100H;
				hwMech := eax MOD 100H
			ELSIF res = 0 THEN res := NoPCI (* ; pci := FALSE (* <- hmm, not sure about that *) *)
			END;
			IF debug THEN
				KernelLog.String("PCIPresent:"); KernelLog.Ln;
				OutRegs(eax, ebx, ecx, edx, esi, edi, eflags)
			END
		ELSE
			res := NoPCI
		END;
		RETURN res
	END PCIPresent;

	PROCEDURE FindPCIDevice*(devId, vendId, idx: LONGINT; VAR busNr, devNr, fktNr: LONGINT): LONGINT;
	VAR res, eax, ebx, ecx, edx, esi, edi: LONGINT; eflags, state: SET;
	BEGIN {EXCLUSIVE}
		IF pci THEN
			eax := PCIFunctionId + findPCIDevice;
			ecx := devId; edx := vendId; esi := idx;
			state := Machine.DisableInterrupts();
			pcicall(pciEntry, eax, ebx, ecx, edx, esi, edi, eflags);
			Machine.RestoreInterrupts(state);
			res := (eax DIV 100H) MOD 100H;  ASSERT(~((0 IN eflags) & (res=0)));
			IF ~(0 IN eflags) & (res = Done) THEN
				busNr := (ebx DIV 100H) MOD 100H;
				devNr := (ebx DIV 8) MOD 20H;
				fktNr := ebx MOD 8
			END;
			IF debug THEN
				KernelLog.String("FindPCIDevice:"); KernelLog.Ln;
				OutRegs(eax, ebx, ecx, edx, esi, edi, eflags)
			END
		ELSE
			res := NoPCI
		END;
		RETURN res
	END FindPCIDevice;

	PROCEDURE FindPCIClassCode*(classCode, idx: LONGINT; VAR busNr, devNr, fktNr: LONGINT): LONGINT;
	VAR res, eax, ebx, ecx, edx, esi, edi: LONGINT; eflags, state: SET;
	BEGIN {EXCLUSIVE}
		IF pci THEN
			eax := PCIFunctionId + findPCIClassCode;
			ecx := classCode; esi := idx;
			state := Machine.DisableInterrupts();
			pcicall(pciEntry, eax, ebx, ecx, edx, esi, edi, eflags);
			Machine.RestoreInterrupts(state);
			res := (eax DIV 100H) MOD 100H;  ASSERT(~((0 IN eflags) & (res=0)));
			IF ~(0 IN eflags) & (res = Done) THEN
				busNr := (ebx DIV 100H) MOD 100H;
				devNr := (ebx DIV 8) MOD 20H;
				fktNr := ebx MOD 8
			END;
			IF debug THEN
				KernelLog.String("FindPCIClassCode:"); KernelLog.Ln;
				OutRegs(eax, ebx, ecx, edx, esi, edi, eflags)
			END
		ELSE
			res := NoPCI
		END;
		RETURN res
	END FindPCIClassCode;

	PROCEDURE GenerateSpecialCycle*(busNr, specCycleData: LONGINT): LONGINT;
	VAR res, eax, ebx, ecx, edx, esi, edi: LONGINT; eflags, state: SET;
	BEGIN {EXCLUSIVE}
		IF pci THEN
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
		ELSE
			res := NoPCI
		END;
		RETURN res
	END GenerateSpecialCycle;

	PROCEDURE GetIrqRoutingOptions*(VAR rt: RouteTable; VAR IrqBitmap: SET): LONGINT;
	CONST dbN = 16*8;
	VAR
		res, eax, ebx, ecx, edx, esi, edi, i: LONGINT; eflags, state: SET;
		rb: RouteBuffer; db: ARRAY dbN OF CHAR;
		last: RouteTable;
	BEGIN {EXCLUSIVE}
		IF pci THEN
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
		ELSE
			res := NoPCI
		END;
		RETURN res
	END GetIrqRoutingOptions;

	PROCEDURE SetPCIIrq*(IntPin, IrqNum, busNr, devNr, fktNr: LONGINT): LONGINT;
	VAR res, eax, ebx, ecx, edx, esi, edi: LONGINT; eflags, state: SET;
	BEGIN {EXCLUSIVE}
		IF pci THEN
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

	PROCEDURE ReadConfig(fkt, busNr, devNr, fktNr, regNr: LONGINT; mask: SET; VAR regVal: LONGINT): LONGINT;
	VAR res, eax, ebx, ecx, edx, esi, edi: LONGINT; eflags, state: SET;
	BEGIN {EXCLUSIVE}
		IF pci THEN
			eax := PCIFunctionId + fkt;
			ebx := busNr*100H+devNr*8+fktNr; edi := regNr;
			state := Machine.DisableInterrupts();
			pcicall(pciEntry, eax, ebx, ecx, edx, esi, edi, eflags);
			Machine.RestoreInterrupts(state);
			res := (eax DIV 100H) MOD 100H;  ASSERT(~((0 IN eflags) & (res=0)));
			IF ~(0 IN eflags) & (res = Done) THEN
				regVal := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ecx)*mask)
			END;
			IF debug THEN
				KernelLog.String("ReadConfig ("); KernelLog.Int(fkt, 1); KernelLog.String("):"); KernelLog.Ln;
				OutRegs(eax, ebx, ecx, edx, esi, edi, eflags)
			END
		ELSE
			res := NoPCI
		END;
		RETURN res
	END ReadConfig;

	PROCEDURE ReadConfigByte*(busNr, devNr, fktNr, regNr: LONGINT; VAR regVal: LONGINT): LONGINT;
	BEGIN
		RETURN ReadConfig(readConfigByte, busNr, devNr, fktNr, regNr, {0..7}, regVal)
	END ReadConfigByte;

	PROCEDURE ReadConfigWord*(busNr, devNr, fktNr, regNr: LONGINT; VAR regVal: LONGINT): LONGINT;
	BEGIN
		ASSERT(regNr MOD 2 = 0);
		RETURN ReadConfig(readConfigWord, busNr, devNr, fktNr, regNr, {0..15}, regVal)
	END ReadConfigWord;

	PROCEDURE ReadConfigDword*(busNr, devNr, fktNr, regNr: LONGINT; VAR regVal: LONGINT): LONGINT;
	BEGIN
		ASSERT(regNr MOD 4 = 0);
		RETURN ReadConfig(readConfigDword, busNr, devNr, fktNr, regNr, {0..31}, regVal)
	END ReadConfigDword;

	PROCEDURE WriteConfig(fkt, busNr, devNr, fktNr, regNr, regVal: LONGINT): LONGINT;
	VAR res, eax, ebx, ecx, edx, esi, edi: LONGINT; eflags, state: SET;
	BEGIN {EXCLUSIVE}
		IF pci THEN
			eax := PCIFunctionId + fkt;
			ebx := busNr*100H+devNr*8+fktNr; ecx := regVal; edi := regNr;
			state := Machine.DisableInterrupts();
			pcicall(pciEntry, eax, ebx, ecx, edx, esi, edi, eflags);
			Machine.RestoreInterrupts(state);
			res := (eax DIV 100H) MOD 100H;  ASSERT(~((0 IN eflags) & (res=0)));
			IF debug THEN
				KernelLog.String("WriteConfig ("); KernelLog.Int(fkt, 1); KernelLog.String("):"); KernelLog.Ln;
				OutRegs(eax, ebx, ecx, edx, esi, edi, eflags)
			END
		ELSE
			res := NoPCI
		END;
		RETURN res
	END WriteConfig;

	PROCEDURE WriteConfigByte*(busNr, devNr, fktNr, regNr, regVal: LONGINT): LONGINT;
	BEGIN
		RETURN WriteConfig(writeConfigByte, busNr, devNr, fktNr, regNr, regVal)
	END WriteConfigByte;

	PROCEDURE WriteConfigWord*(busNr, devNr, fktNr, regNr, regVal: LONGINT): LONGINT;
	BEGIN
		ASSERT(regNr MOD 2 = 0);
		RETURN WriteConfig(writeConfigWord, busNr, devNr, fktNr, regNr, regVal)
	END WriteConfigWord;

	PROCEDURE WriteConfigDword*(busNr, devNr, fktNr, regNr, regVal: LONGINT): LONGINT;
	BEGIN
		ASSERT(regNr MOD 4 = 0);
		RETURN WriteConfig(writeConfigDword, busNr, devNr, fktNr, regNr, regVal)
	END WriteConfigDword;

	PROCEDURE DetectPCI;
	VAR res, len, entry: LONGINT; adr: ADDRESS;
	BEGIN
		res := FindBios32Service(PCIServiceId, 0, adr, len, entry);
		pci := res = Done;
		IF pci THEN
			Machine.MapPhysical(adr, len, adr);	(* map into virtual address space *)
			ASSERT(adr # Machine.NilAdr);
			pciEntry := adr+entry
		END
	END DetectPCI;

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

	PROCEDURE StartIterate*(VAR pci: Pci);
	BEGIN pci.bus := 0; pci.device := 0; pci.function := 0
	END StartIterate;

	PROCEDURE Iterate*(VAR pci: Pci): BOOLEAN;
	VAR hdrType,res: LONGINT; multifunction: BOOLEAN;
	BEGIN
		IF pci.function = 0 THEN
			(* check if multi-function device *)
			res := ReadConfigDword(pci.bus, pci.device, pci.function, 0CH, hdrType);
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


PROCEDURE PCIDisabled() : BOOLEAN;
VAR string : ARRAY 2 OF CHAR;
BEGIN
	Machine.GetConfig("DisablePCI", string);
	RETURN string = "1";
END PCIDisabled;

BEGIN
	pci := FALSE; bios32 := FALSE;
	IF ~PCIDisabled() THEN
		DetectBios32;
		DetectPCI;
	END;
	Show;
END PCI.

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
