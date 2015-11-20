MODULE NCR810Disks;	(** non-portable *)	(* Contributed by P. Ryser to the System 3 project *)
(* ported by phk *)

IMPORT SYSTEM, Machine, KernelLog, ASPI := SymbiosASPI, Disks, Plugins;

	CONST
		chsdebug = FALSE;	readdebug = FALSE;

		MaxDevices = 10;

		BS = 512;	(* disk block size *)

	TYPE
		Part = POINTER TO PartDesc;
		PartDesc = RECORD
			bootind, head, sector, cyl, type, head2, sector2, cyl2: CHAR;
			start, num: LONGINT
		END;

	Device = OBJECT (Disks.Device)
	VAR drive: LONGINT;

		PROCEDURE Transfer*(op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
		BEGIN
			IF op = Disks.Read THEN res := ReadBlocks(drive, block, num, ADDRESSOF(data[ofs]), 0)
			ELSIF op = Disks.Write THEN res := WriteBlocks(drive, block, num, ADDRESSOF(data[ofs]), 0)
			END
		END Transfer;

		PROCEDURE GetSize*(VAR size, res: LONGINT);
		BEGIN
			size := devs[drive].capacity;
			res := Disks.Ok
		END GetSize;

		PROCEDURE Handle*(VAR msg: Disks.Message;  VAR res: LONGINT);
		BEGIN
			IF msg IS Disks.GetGeometryMsg THEN
				WITH msg: Disks.GetGeometryMsg DO
					msg.cyls := devs[drive].cylinders0;
					msg.hds := devs[drive].heads0;
					msg.spt := devs[drive].sectrack;
					res := Disks.Ok
				END
			ELSE res := Disks.Unsupported
			END
		END Handle;
	END Device;

		DeviceDesc = RECORD
			ha, target, lun: CHAR;
			cylinders, cylinders0: LONGINT;	(* number of cylinders *)
			heads, heads0: LONGINT;	(* number of heads *)
			sectrack: LONGINT;	(* sectors/track *)
			writePreComp: LONGINT;
			capacity, blocksize: LONGINT;
			obstart, obend: LONGINT;
			dev: Device
		END;

	VAR
		devs: ARRAY MaxDevices OF DeviceDesc;
		numdevs: LONGINT;	(* number of physical devices *)

(* ReadBlocks - Read disk blocks *)

	PROCEDURE ReadBlocks(drive, sec, num: LONGINT; adr: ADDRESS; offset: LONGINT): LONGINT;
	VAR srb: ASPI.ExecIOCmdSRB; err: LONGINT;
	BEGIN
		err := 0;
		NEW(srb);
		INC(sec, offset);
		IF (sec < 0) OR (num >= 256*256) THEN KernelLog.Int(sec, 1); KernelLog.Char(" "); KernelLog.Int(num, 1); HALT(100) END;
		IF readdebug & ~((sec >= devs[drive].obstart) & (sec+num <= devs[drive].obend)) THEN
			KernelLog.String("Read on block:"); KernelLog.Int(sec, 1); KernelLog.String("   length:"); KernelLog.Int(num, 1); KernelLog.Ln
		END;
		srb.HaId := devs[drive].ha;
		srb.Flags := {ASPI.FlagsDirIn};
		srb.Target := devs[drive].target;
		srb.Lun := devs[drive].lun;
		srb.BufLen := BS*num;
		srb.BufPointer :=  Machine.Ensure32BitAddress (adr);
		srb.SenseLen := 0X;
		srb.CDBLen := 0AX;
		srb.CDB[0] := 28X; srb.CDB[1] := LSH(devs[drive].lun, 5);
		srb.CDB[2] := CHR(sec DIV 1000000H); srb.CDB[3] := CHR((sec DIV 10000H) MOD 100H);
		srb.CDB[4] := CHR((sec DIV 100H) MOD 100H); srb.CDB[5] := CHR(sec MOD 100H);
		srb.CDB[6] := 0X;
		srb.CDB[7] := CHR(num DIV 100H); srb.CDB[8] := CHR(num MOD 100H);
		srb.CDB[9] := 0X;
		srb.meas := NIL;
		srb.Status := 55X;
		ASPI.SendASPICommand(srb, TRUE);
		ASSERT(srb.Status = ASPI.SSComp);
		RETURN err;
	END ReadBlocks;


(* WriteBlocks - Write disk blocks *)

	PROCEDURE WriteBlocks(drive, sec, num: LONGINT; adr: ADDRESS; offset: LONGINT): LONGINT;
	VAR srb: ASPI.ExecIOCmdSRB; err: LONGINT;
	BEGIN
		err := 0;
		NEW(srb);
		INC(sec, offset);
		IF (sec < 0) OR (num >= 256*256) THEN KernelLog.Int(sec, 1); KernelLog.Char(" "); KernelLog.Int(num, 1); HALT(100) END;
		IF readdebug & ~((sec >= devs[drive].obstart) & (sec+num <= devs[drive].obend)) THEN
			KernelLog.String("Write on block:"); KernelLog.Int(sec, 1); KernelLog.String("   length:"); KernelLog.Int(num, 1); KernelLog.Ln;
			IF (sec # 0) OR (num > 1) THEN (*HALT(101)*) END;
		END;
		srb.HaId := devs[drive].ha;
		srb.Flags := {ASPI.FlagsDirOut};
		srb.Target := devs[drive].target;
		srb.Lun := devs[drive].lun;
		srb.BufLen := BS*num;
		srb.BufPointer :=  Machine.Ensure32BitAddress (adr);
		srb.SenseLen := 0X;
		srb.CDBLen := 0AX;
		srb.CDB[0] := 2AX; srb.CDB[1] := LSH(devs[drive].lun, 5);
		srb.CDB[2] := CHR(sec DIV 1000000H); srb.CDB[3] := CHR((sec DIV 10000H) MOD 100H);
		srb.CDB[4] := CHR((sec DIV 100H) MOD 100H); srb.CDB[5] := CHR(sec MOD 100H);
		srb.CDB[6] := 0X;
		srb.CDB[7] := CHR(num DIV 100H); srb.CDB[8] := CHR(num MOD 100H);
		srb.CDB[9] := 0X;
		srb.meas := NIL;
		srb.Status := 55X;
		ASPI.SendASPICommand(srb, TRUE);
		ASSERT(srb.Status = ASPI.SSComp);
		RETURN err
	END WriteBlocks;

(* ---- Calculate disk geometry ---- *)

	PROCEDURE Partsize(drive: LONGINT; VAR res: LONGINT);
	VAR
		p, cyl, lcyl, cyl2, sector2, head2, extpend, extcyl, lend, pend, i: LONGINT;
		pp, lpp: Part;
		pd: ARRAY 512 OF CHAR;
	BEGIN
		res := ReadBlocks(drive, 0, 1, ADDRESSOF(pd[0]), 0); ASSERT(res = 0);
		res := -1; devs[drive].obstart := -1; devs[drive].obend := -1;
		IF (pd[510] = 055X) &  (pd[511] = 0AAX) THEN
			p :=  Machine.Ensure32BitAddress (1BEH+ADDRESSOF(pd[0])); lcyl := -1;
			FOR i := 0 TO 3 DO
				IF chsdebug THEN KernelLog.String("Partition"); KernelLog.Int(i, 1); KernelLog.Ln END;
				pp := SYSTEM.VAL(Part, p);
				IF pp.type # 0X THEN
					IF pp.type = 4FX THEN
						devs[drive].obstart := pp.start; devs[drive].obend := pp.start+pp.num
					END;
					cyl := ORD(pp.cyl) + ORD(SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, pp.sector)*{6,7}))*4;
					IF cyl > lcyl THEN lpp := pp; lcyl := cyl END;
					IF chsdebug THEN
						KernelLog.String("   BootInd:"); KernelLog.Int(ORD(pp.bootind), 1); KernelLog.Ln;
						KernelLog.String("   Type:"); KernelLog.Int(ORD(pp.type), 1); KernelLog.Ln;
						KernelLog.String("   Start:"); KernelLog.Int(pp.start, 1); KernelLog.Ln;
						KernelLog.String("   Num:"); KernelLog.Int(pp.num, 1); KernelLog.Ln;
						KernelLog.String("   Head:"); KernelLog.Int(ORD(pp.head), 1); KernelLog.Ln;
						KernelLog.String("   Sector:"); KernelLog.Int(ORD(pp.sector), 1); KernelLog.Ln;
						KernelLog.String("   cyl:"); KernelLog.Int(ORD(pp.cyl), 1); KernelLog.Ln;
						KernelLog.String("   Head2:"); KernelLog.Int(ORD(pp.head2), 1); KernelLog.Ln;
						KernelLog.String("   Sector2:"); KernelLog.Int(ORD(pp.sector2), 1); KernelLog.Ln;
						KernelLog.String("   cyl2:"); KernelLog.Int(ORD(pp.cyl2), 1); KernelLog.Ln;
						KernelLog.String("   cyl:"); KernelLog.Int(cyl, 1); KernelLog.Ln;
					END
				END;
				INC(p, 16)
			END;
			IF lcyl # -1 THEN
				cyl2 := ORD(lpp.cyl2) + ORD(SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, lpp.sector2)*{6,7}))*4;
				head2 := ORD(lpp.head2);
				sector2 := ORD(lpp.sector2) MOD 40H;
				pend := cyl2*(head2 + 1)*sector2+head2*sector2+sector2;
				lend := lpp.start+lpp.num;

				extcyl := (lend-(head2*sector2+sector2)) DIV (head2 + 1) DIV sector2;
				extpend := extcyl*(head2+1)*sector2+head2*sector2+sector2;

				IF chsdebug THEN
					KernelLog.String("   head2:"); KernelLog.Int(head2, 1); KernelLog.Ln;
					KernelLog.String("   cyl2:"); KernelLog.Int(cyl2, 1); KernelLog.Ln;
					KernelLog.String("   sector2:"); KernelLog.Int(sector2, 1); KernelLog.Ln;
					KernelLog.String("   lend:"); KernelLog.Int(lend, 1); KernelLog.Ln;
					KernelLog.String("   pend:"); KernelLog.Int(pend, 1); KernelLog.Ln;
					KernelLog.String("   extpend:"); KernelLog.Int(extpend, 1); KernelLog.Ln;
					KernelLog.String("   extcyl:"); KernelLog.Int(extcyl, 1); KernelLog.Ln
				END;

				IF (lend = pend) OR ((cyl2 = 1023) & (extpend = lend)) THEN
					devs[drive].sectrack := sector2;
					devs[drive].heads0 := head2+1;
					devs[drive].cylinders0 := devs[drive].capacity DIV ((head2 + 1) * sector2);
					res := 0;
					IF chsdebug THEN
						KernelLog.String("Partsize:"); KernelLog.Ln;
						KernelLog.String("   secs:"); KernelLog.Int(devs[drive].sectrack, 1); KernelLog.Ln;
						KernelLog.String("   hds:"); KernelLog.Int(devs[drive].heads0, 1); KernelLog.Ln;
						KernelLog.String("   cyls:"); KernelLog.Int(devs[drive].cylinders0, 1); KernelLog.Ln
					END
				END;
			END
		END
	END Partsize;

	PROCEDURE Setsize(drive: LONGINT; VAR res: LONGINT);
	VAR cylinders, temp, heads, sectors, capacity: LONGINT;
	BEGIN
		cylinders := 1024; sectors := 62;
		temp := cylinders*sectors;
		capacity := devs[drive].capacity;
		heads := capacity DIV temp;

		IF capacity MOD temp # 0 THEN
			INC(heads);
			temp := cylinders*heads;
			sectors := capacity DIV temp;
			IF capacity MOD temp # 0 THEN
				INC(sectors);
				temp := heads*sectors;
				cylinders := capacity DIV temp
			END
		END;
		IF cylinders = 0 THEN res := -1 ELSE res := 0 END;
		devs[drive].sectrack := sectors;
		devs[drive].heads0 := heads;
		devs[drive].cylinders0 := cylinders;
		IF chsdebug THEN
			KernelLog.String("Setsize:"); KernelLog.Ln;
			KernelLog.String("   secs:"); KernelLog.Int(devs[drive].sectrack, 1); KernelLog.Ln;
			KernelLog.String("   hds:"); KernelLog.Int(devs[drive].heads0, 1); KernelLog.Ln;
			KernelLog.String("   cyls:"); KernelLog.Int(devs[drive].cylinders0, 1); KernelLog.Ln
		END
	END Setsize;

	PROCEDURE GetGeo(drive: LONGINT);
	VAR res: LONGINT;
	BEGIN
		devs[drive].heads := 0; devs[drive].heads0 := 0;
		devs[drive].cylinders := 0; devs[drive].cylinders0 := 0;
		devs[drive].sectrack := 0;
		res := -1;
		Partsize(drive, res);
		IF res # 0 THEN Setsize(drive, res) END;
		IF res # 0 THEN KernelLog.String("GetGeo: Could not get disk geometry"); KernelLog.Ln END
(*		ASSERT(res = 0); *)
	END GetGeo;

(* ---- Get disk capacity and block size ---- *)

	PROCEDURE GetCapacity(drive: LONGINT);
	VAR srb: ASPI.ExecIOCmdSRB; buf: ARRAY 8 OF CHAR; i: LONGINT;
	BEGIN
		NEW(srb);
		srb.HaId := devs[drive].ha;
		srb.Flags := {ASPI.FlagsDirIn};
		srb.Target := devs[drive].target;
		srb.Lun := devs[drive].lun;
		srb.BufLen := 8;
		srb.BufPointer := Machine.Ensure32BitAddress (ADDRESSOF(buf[0]));
		srb.SenseLen := 0X;
		srb.CDBLen := 0AX;
		srb.CDB[0] := 25X; srb.CDB[1] := LSH(devs[drive].lun, 5); srb.CDB[2] := 0X; srb.CDB[3] := 0X;
		srb.CDB[4] := 0X; srb.CDB[5] := 0X; srb.CDB[6] := 0X; srb.CDB[7] := 0X; srb.CDB[8] := 0X; srb.CDB[9] := 0X;
		srb.meas := NIL;
		srb.Status := 55X;
		ASPI.SendASPICommand(srb, TRUE);
		ASSERT(srb.Status = ASPI.SSComp);
		devs[drive].capacity := 0; devs[drive].blocksize := 0;
		FOR i := 0 TO 3 DO
			devs[drive].capacity := devs[drive].capacity*100H + ORD(buf[i]);
			devs[drive].blocksize := devs[drive].blocksize*100H + ORD(buf[i+4])
		END;
		ASSERT(devs[drive].blocksize=BS)
	END GetCapacity;

	PROCEDURE Init;
	VAR res, ha, targ, lun: LONGINT; srb: ASPI.GetDevTypeSRB;
	BEGIN
		numdevs := 0;
		res := ASPI.GetASPISupportInfo();
		IF CHR(LSH(res, -8)) = ASPI.SSComp THEN
			res := res MOD 100H;
			NEW(srb); ha := 0;
			WHILE ha < res DO
				targ := 0;
				WHILE targ < 7 DO
					lun := 0; srb.Status := ASPI.SSComp;
					WHILE (lun < 8) & (srb.Status = ASPI.SSComp) DO
						KernelLog.String("Init: ha:"); KernelLog.Int(ha, 1);
						KernelLog.String("  target:"); KernelLog.Int(targ, 1);
						KernelLog.String("  lun:"); KernelLog.Int(lun, 1);
						KernelLog.Ln;
						srb.HaId := CHR(ha); srb.Flags := {};
						srb.Target := CHR(targ); srb.Lun := CHR(lun);
						ASPI.SendASPICommand(srb, FALSE);
						KernelLog.String("DevType: "); KernelLog.Int(ORD(srb.DevType), 1); KernelLog.Ln;
						IF (srb.Status = ASPI.SSComp) & (srb.DevType = 0X) THEN (* only support direct access devices *)
							devs[numdevs].ha := CHR(ha); devs[numdevs].target := CHR(targ);
							devs[numdevs].lun := CHR(lun);
							devs[numdevs].writePreComp := 0;
							GetCapacity(numdevs);
							GetGeo(numdevs);
							INC(numdevs)
						END;
						INC(lun)
					END;
					INC(targ)
				END;
				INC(ha)
			END
		ELSE
			KernelLog.String("NCR810Disk: no host adapter found"); KernelLog.Ln
		END
	END Init;

	PROCEDURE Register;
	VAR i, res: LONGINT;  dev: Device; name : ARRAY 12 OF CHAR;
	BEGIN
		FOR i := 0 TO numdevs-1 DO
			NEW(dev); devs[i].dev := dev;
			name := "NCR810Disk0";
			name[10] := CHR(48 + i);
			dev.SetName(name);
			dev.blockSize := BS;
			dev.flags := {};
			dev.drive := i;
			Disks.registry.Add(dev, res);
			IF res # Plugins.Ok THEN KernelLog.String("failed adding to registry"); KernelLog.Ln; END
		END
	END Register;

	(** Install - Install the driver in the Disk module. *)
	(** The install command has no effect, as all NCR810 disk devices are installed when the module is loaded. *)

	PROCEDURE Install*;
	END Install;

BEGIN
	Init;  Register
END NCR810Disks.
