MODULE PCITools; (** AUTHOR "pjm/staubesv"; PURPOSE "PCI Bus Tools"; *)
(**
 * This module provide two kinds of services related to PCI:
 *	- Display information about all PCI busses/devices installed in the system
 *	- Map PCI function to PCI device drivers
 *
 * Usage:
 *
 *	PCITools.Scan ~				displays information about all installed PCI busses/devices
 *	PCITools.Scan details ~		displays excessively detailed information
 *	PCITools.DetectHardware ~	performs a PCI function to device driver mapping for all devices found
 *
 *	SystemTools.Free PCITools ~
 *
 * Port of Oberon PCITools.Mod from "pjm" which is based on Linux pci.c and PCI Local Bus Specification Revision 2.0
 *
 * History:
 *
 * 	18.06.2003	Fix for non-continuously numbered device functions (tf)
 *	15.09.2005 	Ported to Bluebottle, added DetectHardware(), InstallPCIDrivers() & Extract(), removed ShowInterrupts() (staubesv)
 *	17.01.2006	Added WriteRegs & WriteCmdSts (staubesv)
 *)

IMPORT
	SYSTEM, PCI, KernelLog, Streams, Files, Commands, Options, DriverDatabase;

CONST
	HdrType = 0EH;

	Verbose = FALSE;
	ShowDrivers = TRUE;				(* Also show available device/class drivers *)

	PCIIDS = "pci.ids";					(* File containing PCI vendor ID to vendor string mapping *)

TYPE
	Device = POINTER TO RECORD
		bus: Bus;						(* bus this device is on *)
		sibling: Device;					(* next device on this bus *)
		next, prev: Device;				(* chain of all devices *)
		devfn: LONGINT;				(* dev = top 5 bits, fn = lower 3 bits *)
		device: LONGINT;				(* device id *)
		vendor: LONGINT;				(* vendor id *)
		class: LONGINT;					(* base, sub, prog-if bytes *)
		revision : LONGINT;				(* device revision *)
		irq, pin: LONGINT
	END;

	Bus = POINTER TO RECORD
		parent : Bus;					(* parent bus this bridge is on *)
		children : Bus;					(* chain of P2P bridges on this bus *)
		next : Bus;						(* chain of all PCI buses *)
		self: Device;						(* bridge device as seen by parent *)
		devices: Device;					(* devices behind this bridge *)
		number: LONGINT;				(* bus number *)
		primary, secondary: LONGINT;	(* bridge numbers *)
		subordinate: LONGINT			(* max number of subordinate buses *)
	END;

PROCEDURE ScanBus(VAR bus: Bus; VAR devices : Device): LONGINT;
VAR devfn, max, x, hdrtype, ht, buses: LONGINT;  ismulti: BOOLEAN;  dev: Device;  child: Bus;
BEGIN (* Only call from within EXCLUSIVE regions *)
	max := bus.secondary;  ismulti := FALSE;
	FOR devfn := 0 TO 0FEH DO
		IF (devfn MOD 8 = 0) OR ismulti THEN
			ReadConfigByte(bus.number, devfn, HdrType, hdrtype);
			IF devfn MOD 8 = 0 THEN ismulti := ODD(hdrtype DIV 80H) END;
			ReadConfigDword(bus.number, devfn, PCI.DevReg, x);
			IF (x # -1) & (x # 0) THEN (* some boards return 0 instead of -1 for empty slot, according to Linux *)
				NEW(dev);
				dev.bus := bus;  dev.devfn := devfn;
				dev.vendor := x MOD 10000H;
				dev.device := ASH(x, -16) MOD 10000H;
				ReadConfigByte(bus.number, devfn, PCI.IntlReg, dev.irq);
				ReadConfigByte(bus.number, devfn, PCI.IntlReg+1, dev.pin);
				ReadConfigDword(bus.number, devfn, PCI.RevIdReg, x);
				dev.class := ASH(x, -8) MOD 1000000H;	(* upper 3 bytes *)
				dev.revision := x MOD 100H; (* lowest byte *)
				CASE ASH(dev.class, -8) OF
					604H: ht := 1	(* bridge pci *)
					|607H: ht := 2	(* bridge cardbus *)
					ELSE ht := 0
				END;
				IF ht = hdrtype MOD 80H THEN
					dev.next := devices;  devices := dev;  dev.prev := NIL;
					dev.sibling := bus.devices;  bus.devices := dev;
					IF ASH(dev.class, -8) = 604H THEN (* bridge pci *)
						NEW(child);
						child.next := bus.children;  bus.children := child;
						child.self := dev;  child.parent := bus;
						INC(max);  child.secondary := max;  child.number := max;
						child.primary := bus.secondary;  child.subordinate := 0FFH;

						ReadConfigDword(bus.number, devfn, 18H, buses);
						IF buses MOD 1000000 # 0 THEN
							child.primary := buses MOD 100H;
							child.secondary := ASH(buses, -8) MOD 100H;
							child.subordinate := ASH(buses, -16) MOD 100H;
							child.number := child.secondary;
							max := ScanBus(child, devices)
						ELSE (* configure bus numbers for this bridge *)
							KernelLog.String("PCI: Warning: Bus numbers not configured."); KernelLog.Ln;
						END
					END
				ELSE
					KernelLog.String("PCI: Warning: Unknown header type (Bus: "); KernelLog.Int(bus.number, 0);
					KernelLog.String(", device: "); KernelLog.Int(dev.devfn DIV 8, 0);
					KernelLog.String(", function: "); KernelLog.Int(dev.devfn MOD 8, 0);
					KernelLog.String(", Header Type: "); KernelLog.Int(hdrtype, 0); KernelLog.Ln;
				END;
		(*	ELSE
				ismulti := FALSE *) (* not all functions are continuously numbered *)
			END
		END
	END;
	RETURN max
END ScanBus;

PROCEDURE Extract(classcode : LONGINT; VAR class, subclass, protocol : LONGINT);
BEGIN
	class := LSH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, classcode) * {16..23}), -16);
	subclass := LSH(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, classcode) * {8..15}), -8);
	protocol := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, classcode) * {0..7});
END Extract;

PROCEDURE InstallPCIDrivers;
VAR root : Bus; device : Device; nbrOfDevices : LONGINT; class, subclass, protocol : LONGINT;
BEGIN {EXCLUSIVE}
	KernelLog.String("Looking for PCI devices..."); KernelLog.Ln;
	NEW(root);
	nbrOfDevices := ScanBus(root, device);
	WHILE(device # NIL) DO
		IF Verbose THEN
			KernelLog.String("Bus: "); IF device.bus = NIL THEN KernelLog.String("n/a"); ELSE KernelLog.Int(device.bus.number, 2); END;
			KernelLog.String(", Device: "); KernelLog.Int(ASH(device.devfn, -3) MOD 20H, 2); KernelLog.String(", Function: "); KernelLog.Int(device.devfn MOD 8, 2);
			KernelLog.String(": "); KernelLog.String("VendorID: "); KernelLog.Hex(device.vendor, -4); KernelLog.String(", DeviceID: "); KernelLog.Hex(device.device, -4);
			KernelLog.Ln;
		END;
		IF DriverDatabase.InstallDeviceDriver(DriverDatabase.PCI, device.vendor, device.device, device.revision) THEN
		ELSE
			Extract(device.class, class, subclass, protocol);
			IF DriverDatabase.InstallClassDriver(DriverDatabase.PCI, class, subclass, protocol, device.revision) THEN
			END;
		END;
		device := device.next;
	END;
END InstallPCIDrivers;

PROCEDURE HexDigit(ch: CHAR): BOOLEAN;
BEGIN
	RETURN (ch >= "0") & (ch <= "9") OR (CAP(ch) >= "A") & (CAP(ch) <= "F")
END HexDigit;

PROCEDURE Read(VAR r: Files.Reader; VAR ch: CHAR);
BEGIN
	IF ch = Streams.EOT THEN ch := 0X ELSE r.Char(ch) END
END Read;

PROCEDURE WriteDevice(w: Streams.Writer; class: BOOLEAN; p1, p2, p3: LONGINT; CONST l1, l2, l3: ARRAY OF CHAR; pciids : Files.File);
VAR r: Files.Reader; ch: CHAR; level, value: LONGINT;

	PROCEDURE SkipLine(write: BOOLEAN);
	BEGIN
		WHILE (ch # 0X) & (ch # 0DX) & (ch # 0AX) DO
			IF write THEN w.Char(ch) END;
			Read(r, ch)
		END;
		REPEAT Read(r, ch) UNTIL (ch # 0DX) & (ch # 0AX)
	END SkipLine;

	PROCEDURE ReadHex(VAR x: LONGINT);
	BEGIN
		x := 0;
		LOOP
			IF (ch >= "0") & (ch <= "9") THEN
				x := x * 16 + (ORD(ch)-ORD("0"))
			ELSIF (CAP(ch) >= "A") & (CAP(ch) <= "F") THEN
				x := x * 16 + (ORD(CAP(ch))-ORD("A")+10)
			ELSE
				EXIT
			END;
			Read(r, ch)
		END
	END ReadHex;

	PROCEDURE GetLine(VAR level, value: LONGINT);
	BEGIN
		IF class THEN
			IF ch = "C" THEN Read(r, ch); Read(r, ch) END
		END;
		WHILE (ch # 0X) & (ch # 9X) & ~HexDigit(ch) DO SkipLine(FALSE) END;
		level := 0; WHILE ch = 9X DO INC(level); Read(r, ch) END;
		ReadHex(value);
		WHILE ch = " " DO Read(r, ch) END
	END GetLine;

	PROCEDURE Label(CONST l: ARRAY OF CHAR);
	BEGIN
		w.String(l); w.String(": ");
	END Label;

BEGIN
	IF pciids = NIL THEN
		Label(l1); w.String("Unknown");
		Label(l2); w.String("Unknown");
	ELSE
		NEW(r, pciids, 0); Read(r, ch);
		IF class THEN WHILE (ch # 0X) & (ch # "C") DO SkipLine(FALSE) END; END;

		LOOP
			GetLine(level, value);
			IF (ch = 0X) OR (level = 0) & (value = p1) THEN EXIT END;
			SkipLine(FALSE)
		END;
		Label(l1);
		IF (ch # 0X) & (level = 0) & (value = p1) THEN
			SkipLine(TRUE); w.String(", ");
			LOOP
				GetLine(level, value);
				IF (ch = 0X) OR (level = 0) OR (level = 1) & (value = p2) THEN EXIT END;
				SkipLine(FALSE)
			END;
			Label(l2);
			IF (ch # 0X) & (level = 1) & (value = p2) THEN
				SkipLine(TRUE);
				LOOP
					GetLine(level, value);
					IF (ch = 0X) OR (level < 2) OR (level = 2) & (value = p3) THEN EXIT END;
					SkipLine(FALSE)
				END;
				IF (ch # 0X) & (level = 2) & (value = p3) THEN
					w.String(", "); Label(l3); SkipLine(TRUE)
				END
			ELSE
				w.String("Unknown")
			END
		ELSE
			w.String("Unknown")
		END
	END;
END WriteDevice;

PROCEDURE WriteB(w: Streams.Writer; x: LONGINT);
CONST K = 1024; M = K*K; G = K*M;
VAR mult: CHAR;
BEGIN
	IF x MOD K # 0 THEN
		w.Int(x, 1)
	ELSE
		IF x MOD M # 0 THEN mult := "K"; x := x DIV K
		ELSIF x MOD G # 0 THEN mult := "M"; x := x DIV M
		ELSE mult := "G"; x := x DIV G
		END;
		w.Int(x, 1); w.Char(mult)
	END;
	w.String("B")
END WriteB;

PROCEDURE WriteBase(w: Streams.Writer; bus, devfn, reg: LONGINT; VAR double: BOOLEAN);
VAR base, basehi, type, size: LONGINT; mask: SET;
BEGIN
	double := FALSE; basehi := 0; size := 0;
	ReadConfigDword(bus, devfn, reg, base);
	IF base # 0 THEN
		WriteConfigDword(bus, devfn, reg, -1);
		ReadConfigDword(bus, devfn, reg, size);
		WriteConfigDword(bus, devfn, reg, base);
		IF ODD(base) THEN (* I/O *)
			IF ASH(base, -16) = 0 THEN mask := {2..15} ELSE mask := {2..31} END;
			type := base MOD 4
		ELSE (* memory *)
			mask := {4..31}; type := base MOD 10H
		END;
		size := SYSTEM.VAL(LONGINT, -(SYSTEM.VAL(SET, size) * mask))+1;
		size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, size) * mask);
		IF type MOD 8 = 4 THEN	(* 64-bit *)
			ReadConfigDword(bus, devfn, reg+4, basehi); double := TRUE
		END;
		DEC(base, type);
			(* write *)
		w.Char(9X); w.Char(9X);
		WriteB(w, size); w.String(" ");
		CASE type OF
			0: w.String("32-bit memory")
			|1: w.String("I/O")
			|4: w.String("64-bit memory")
			|8: w.String("prefetchable 32-bit memory")
			|12: w.String("prefetchable 64-bit memory")
			ELSE w.String("type "); w.Int(type, 1)
		END;
		w.String(" at ");
		IF basehi # 0 THEN w.Hex(basehi, -2) END;
		w.Hex(base, -8); w.String("-");
		IF basehi # 0 THEN w.Hex(basehi, -8) END;
		w.Hex(base + size - 1, -8); w.Ln;
	END
END WriteBase;

PROCEDURE WriteDriver(w : Streams.Writer; dev : Device);
VAR d, c : DriverDatabase.Driver; class, subclass, progintf : LONGINT;
BEGIN
	w.String("Driver: ");
	d := DriverDatabase.GetDeviceSpecific(DriverDatabase.PCI, dev.vendor, dev.device, dev.revision);
	Extract(dev.class, class, subclass, progintf);
	c := DriverDatabase.GetClassSpecific(DriverDatabase.PCI, class, subclass, progintf, dev.revision);
	IF (c = NIL) & (d = NIL) THEN w.String("n/a");
	ELSIF (d # NIL) THEN
		w.String(d.commands^);
	ELSIF (c # NIL) THEN
		w.String(c.commands^);
	END;
END WriteDriver;

PROCEDURE WriteDev(w: Streams.Writer;  dev: Device; pciids : Files.File; details : BOOLEAN);
VAR bus, devfn, hdrtype, classrev, vendor, device, cmd, status, lastreg, reg, base: LONGINT; double: BOOLEAN;
BEGIN
	bus := dev.bus.number;  devfn := dev.devfn;
	ReadConfigByte(bus, devfn, HdrType, hdrtype);
	ReadConfigDword(bus, devfn, PCI.RevIdReg, classrev);
	ReadConfigWord(bus, devfn, PCI.DevReg, vendor);
	ReadConfigWord(bus, devfn, PCI.DevReg+2, device);
	ReadConfigWord(bus, devfn, PCI.CmdReg+2, status);
	ReadConfigWord(bus, devfn, PCI.CmdReg, cmd);

	w.String("Bus ");  w.Int(bus, 1);
	w.String(", device ");  w.Int(ASH(devfn, -3) MOD 20H, 1);
	w.String(", function ");  w.Int(devfn MOD 8, 1);
	w.String(": class/rev ");  w.Hex(classrev, -8);
	w.String(", vendor/device ");  w.Hex(ASH(vendor, 16) + device, -8);
	w.String(", status/cmd ");  w.Hex(ASH(status, 16) + cmd, -8);
	w.Ln;

	w.Char(9X);
	WriteDevice(w, TRUE, ASH(classrev, -24) MOD 100H, ASH(classrev, -16) MOD 100H, ASH(classrev, -8) MOD 100H, "Class", "Sub-class", "ProgIntfc", pciids);
	w.Ln;
	w.Char(9X);
	WriteDevice(w, FALSE, vendor, device, -1, "Vendor", "Device", "", pciids);
	w.Ln;
	IF ShowDrivers THEN
		w.Char(9X); WriteDriver(w, dev); w.Ln;
	END;
	IF (dev.irq # 0) OR (dev.pin # 0) THEN
		w.Char( 9X); w.Char( 9X);
		w.String("IRQ");  w.Int( dev.irq, 1);
		IF dev.pin # 0 THEN
			w.String(", INT");  w.Char( CHR(ORD("A")+dev.pin-1))
		END;
		w.Ln;
	END;
	CASE hdrtype MOD 80H OF
		0: lastreg := PCI.Adr5Reg
		|1: lastreg := PCI.Adr1Reg
		ELSE lastreg := 0
	END;
	FOR reg := PCI.Adr0Reg TO lastreg BY 4 DO
		WriteBase(w, bus, devfn, reg, double);
		IF double THEN INC(reg, 4) END	(* modifying FOR variable *)
	END;
	IF hdrtype MOD 80H = 0 THEN
		ReadConfigDword(bus, devfn, PCI.ROMReg, base);
		IF base # 0 THEN
			w.Char(9X); w.Char(9X);
			w.String("ROM at");
			w.Hex(base, -8);  w.Ln;
		END
	END;
	IF details THEN WriteRegs(w, dev); WriteCmdSts(w, dev); END;
	w.Ln;
END WriteDev;

(* Dump PCI configuration space *)
PROCEDURE WriteRegs(w : Streams.Writer; dev : Device);
VAR value, offset : LONGINT;
BEGIN
	w.Char(9X); w.String("PCI Configuration Space Registers: "); w.Ln;
	w.Char(0EX); (* KernelLog: non-proportional font *)
	FOR offset := 0 TO 3CH BY 4 DO
		w.Char(9X); w.Char(9X); w.Hex(offset, -2); w.Char("h"); w.Char(9X); w.Char(9X);
		ReadConfigDword(dev.bus.number, dev.devfn, PCI.DevReg + offset, value);
		w.Hex(value, -8); w.Ln;
	END;
	w.Char(0FX); (* KernelLog: proportional font *)
END WriteRegs;

(* Decode & display the command and the status register *)
PROCEDURE WriteCmdSts(w : Streams.Writer; dev : Device);
VAR value : LONGINT; dword : SET;
BEGIN
	ReadConfigDword(dev.bus.number, dev.devfn, PCI.CmdReg, value); dword := SYSTEM.VAL(SET, value);
	w.Char(9X); w.String("Command Register: "); w.Ln;
	w.Char(9X); w.Char(9X);
	w.String("IO Space: "); IF 0 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.String(", Memory Space: "); IF 1 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.String(", Bus Master: "); IF 2 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.String(", Special Cycles:  "); IF 3 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.String(", Memory Write and Invalidate: "); IF 4 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.Ln;
	w.Char(9X); w.Char(9X);
	w.String("VGA Palette Snoop: "); IF 5 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.String(", Parity Error Response: "); IF 6 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.String(", Stepping Control: "); IF 7 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.String(", SERR#: "); IF 8 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.String(", Fast Back-to-Back: "); IF 9 IN dword THEN w.String("On"); ELSE w.String("Off"); END;
	w.Ln;
	w.Char(9X); w.String("Status Register: "); w.Ln;
	w.Char(9X); w.Char(9X);
	w.String("Capabilities List: "); IF 4 + 16 IN dword THEN w.String("Yes"); ELSE w.String("No"); END;
	w.String(", 66MHz Capable: "); IF 5 + 16 IN dword THEN w.String("Yes"); ELSE w.String("No"); END;
	w.String(", Fast Back-to-Back Capable: "); IF 7 + 16 IN dword THEN w.String("Yes"); ELSE w.String("No"); END;
	w.String(", Master Data Parity Error: "); IF 8 + 16 IN dword THEN w.String("Yes"); ELSE w.String("No"); END;
	w.Ln;
	w.Char(9X); w.Char(9X);
	w.String("DEVSEL timing: ");
	IF {9+16, 10+16} * dword = {} THEN w.String("Fast");
	ELSIF {9+16, 10+16} * dword = {9+16} THEN w.String("Medium");
	ELSIF {9+16, 10+16} * dword = {10+16} THEN w.String("Slow");
	ELSE w.String("ERROR");
	END;
	w.Ln;
	w.Char(9X); w.Char(9X);
	w.String("Signaled Target Abort: "); IF 11 + 16 IN dword THEN w.String("Yes"); ELSE w.String("No"); END;
	w.String(", Received Target Abort: "); IF 12 + 16 IN dword THEN w.String("Yes"); ELSE w.String("No"); END;
	w.String(", Received Master Abort: "); IF 13 + 16 IN dword THEN w.String("Yes"); ELSE w.String("No"); END;
	w.String(", Signaled System Error: "); IF 14 + 16 IN dword THEN w.String("Yes"); ELSE w.String("No"); END;
	w.String(", Detected Parity Error: "); IF 15 + 16 IN dword THEN w.String("Yes"); ELSE w.String("No"); END;
	w.Ln;
END WriteCmdSts;

PROCEDURE ReadConfigByte(bus, devfn, ofs: LONGINT;  VAR val: LONGINT);
VAR res: LONGINT;
BEGIN
	res := PCI.ReadConfigByte(bus, ASH(devfn, -3) MOD 20H, devfn MOD 8, ofs, val);
	ASSERT(res = PCI.Done)
END ReadConfigByte;

PROCEDURE ReadConfigWord(bus, devfn, ofs: LONGINT;  VAR val: LONGINT);
VAR res: LONGINT;
BEGIN
	res := PCI.ReadConfigWord(bus, ASH(devfn, -3) MOD 20H, devfn MOD 8, ofs, val);
	ASSERT(res = PCI.Done)
END ReadConfigWord;

PROCEDURE ReadConfigDword(bus, devfn, ofs: LONGINT;  VAR val: LONGINT);
VAR res: LONGINT;
BEGIN
	res := PCI.ReadConfigDword(bus, ASH(devfn, -3) MOD 20H, devfn MOD 8, ofs, val);
	ASSERT(res = PCI.Done)
END ReadConfigDword;

PROCEDURE WriteConfigDword(bus, devfn, ofs, val: LONGINT);
VAR res: LONGINT;
BEGIN
	res := PCI.WriteConfigDword(bus, ASH(devfn, -3) MOD 20H, devfn MOD 8, ofs, val);
	ASSERT(res = PCI.Done)
END WriteConfigDword;

(** Exported commands *)

(** Perform bus enumeration and display information about found PCI busses/devices *)
PROCEDURE Scan*(context : Commands.Context); (** ["-d"|"--details"] ~ *)
VAR
	options : Options.Options;
	root : Bus; dev, prev: Device;
	version, lastPCIBus, hw, count: LONGINT;
	pciids : Files.File;
BEGIN {EXCLUSIVE}
	NEW(options);
	options.Add("d", "details", Options.Flag);
	IF options.Parse(context.arg, context.out) THEN
		context.out.String("PCITools: PCI bus enumeration:"); context.out.Ln;
		IF PCI.PCIPresent(version, lastPCIBus, hw) = PCI.Done THEN
			context.out.String("PCI Bus Information: "); context.out.Int(lastPCIBus + 1, 0); context.out.String(" bus(ses) found, PCI version: ");
			context.out.Hex(version DIV 256, -2); context.out.Char("."); context.out.Hex(version MOD 256, -2); context.out.Ln;
			context.out.Ln;
			NEW(root);
			root.subordinate := ScanBus(root, dev);
			count := 0; prev := NIL;
			WHILE dev # NIL DO
				dev.prev := prev; prev := dev;
				dev := dev.next; INC(count)
			END;
			pciids := Files.Old(PCIIDS);
			WHILE prev # NIL DO
				WriteDev(context.out, prev, pciids, options.GetFlag("details"));
				prev := prev.prev
			END;
			context.out.Int(count, 1); context.out.String(" devices found"); context.out.Ln;
		ELSE
			context.out.String("PCI not present"); context.out.Ln;
		END;
	END;
END Scan;

(** Perform bus enumeration and install appropriate device drivers if available *)
PROCEDURE DetectHardware*(context : Commands.Context);
VAR ver, last, hw : LONGINT;
BEGIN
	IF DriverDatabase.enabled THEN
		IF (PCI.PCIPresent(ver, last, hw) = PCI.Done) THEN
			InstallPCIDrivers;
		ELSE
			context.out.String("PCITools: No PCI bus found."); context.out.Ln;
		END;
	ELSE
		context.out.String("PCITools: Automatic hardware detedtion is disabled."); context.out.Ln;
	END;
END DetectHardware;

END PCITools.

PCITools.Scan ~  SystemTools.Free PCITools DriverDatabase ~

PCITools.Scan details ~

PCITools.DetectHardware ~
