(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE SymbiosDisks;	(** non-portable *)
(** AUTHOR "ryser"; PURPOSE "NCR/Symbios SCSI driver"; *)

(* Symbios/NCR SCSI Disk driver for Aos, Q&D port from the Native Oberon version by Peter Ryser *)

	IMPORT SYSTEM, KernelLog, Machine, ASPI := SymbiosASPI, Disks, Plugins;

	CONST
		PageSize = 4096;

		BS = 512;	(* disk block size *)
		MaxRanges = ASPI.MaxRanges;
		MaxTransfer = (MaxRanges-1) * PageSize;

		TraceVerbose = FALSE;

	TYPE
		Device = OBJECT (Disks.Device)
			VAR
				ha, target, lun: CHAR;
				writePreComp: LONGINT;
				capacity: LONGINT;

			PROCEDURE Transfer* (op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR res: LONGINT);
			VAR
				srb: ASPI.ExecIOCmdSRB; size, n, i, copyAdr, orgadr, orgsize: LONGINT; phys: ARRAY MaxRanges OF Machine.Range;
			BEGIN
				orgsize := num*BS;
				orgadr := Machine.Ensure32BitAddress (ADDRESSOF(data[ofs]));
				IF TraceVerbose THEN
					KernelLog.Enter;
					KernelLog.String("NCR: Transfer "); KernelLog.Int(op, 1); KernelLog.Char(" ");
					KernelLog.Int(block, 1); KernelLog.Char(" "); KernelLog.Int(num, 1);
(*
					IF op = Disks.Write THEN
						KernelLog.Ln; KernelLog.Memory(orgadr, orgsize)
					END;
*)
					KernelLog.Exit
				END;
				IF (op = Disks.Read) OR (op = Disks.Write) THEN
					IF (block >= 0) & (num > 0) THEN
						NewSRB(srb);
						REPEAT
							copyAdr := 0;
							size := BS*num;	(* number of bytes to transfer now *)
							IF size > MaxTransfer THEN
								size := MaxTransfer; ASSERT(MaxTransfer MOD BS = 0)
							END;
							IF size > 256*256*BS THEN size := 256*256*BS END;	(* max 64K * 512B blocks *)
							Machine.TranslateVirtual(ADDRESSOF(data[ofs]), size, n, phys);
							i := 0; size := 0;
							WHILE (i < n) & (phys[0].adr + size = phys[i].adr) DO	(* find contiguous memory range *)
								INC(size, Machine.Ensure32BitAddress (phys[i].size)); INC(i)
							END;
							IF size MOD BS = 0 THEN
								srb.BufPointer := Machine.Ensure32BitAddress (ADDRESSOF(data[ofs]))	(* the virtual address *)
							ELSE
								AcquireBuffer(copyAdr);
								size := BS; srb.BufPointer := copyAdr;
								IF op = Disks.Write THEN
									SYSTEM.MOVE(ADDRESSOF(data[ofs]), copyAdr, size)
								END
							END;
							srb.BufLen := size;
							n := size DIV BS;	(* n is number of blocks to transfer now *)
							ASSERT((n > 0) & (n < 10000H));
							srb.HaId := ha; srb.Flags := {ASPI.FlagsDirIn}; srb.Target := target; srb.Lun := lun;
							srb.SenseLen := 0X;
							srb.CDBLen := 0AX;
							CASE op OF
								Disks.Read: srb.CDB[0] := 28X
								|Disks.Write: srb.CDB[0] := 2AX
							END;
							srb.CDB[1] := LSH(lun, 5);
							srb.CDB[2] := CHR(block DIV 1000000H); srb.CDB[3] := CHR((block DIV 10000H) MOD 100H);
							srb.CDB[4] := CHR((block DIV 100H) MOD 100H); srb.CDB[5] := CHR(block MOD 100H);
							srb.CDB[6] := 0X;
							srb.CDB[7] := CHR(n DIV 100H); srb.CDB[8] := CHR(n MOD 100H);
							srb.CDB[9] := 0X;
							srb.meas := NIL;
							srb.Status := 55X;
							IF TraceVerbose THEN
								KernelLog.Enter;
								KernelLog.String("SRB: "); KernelLog.Int(op, 1); KernelLog.Char(" ");
								KernelLog.Int(block, 1); KernelLog.Char(" "); KernelLog.Int(n, 1);
								KernelLog.Hex(srb.BufPointer, 9); KernelLog.Char(" "); KernelLog.Int(srb.BufLen, 1);
								KernelLog.Exit
							END;
							ASPI.SendASPICommand(srb, TRUE);
							ASSERT(srb.Status = ASPI.SSComp);
							IF copyAdr # 0 THEN
								IF op = Disks.Read THEN
									SYSTEM.MOVE(copyAdr, ADDRESSOF(data[ofs]), size);
									i := 0; WHILE (i < size) & (SYSTEM.GET32(copyAdr+i) # 0DEADDEADH) DO INC(i, 4) END;
									IF i < size THEN
										KernelLog.Enter; KernelLog.String("DEAD"); KernelLog.Ln;
										KernelLog.Memory(copyAdr, size); KernelLog.Exit
									END
								END;
								ReleaseBuffer(copyAdr)
							END;
							INC(block, n); DEC(num, n); INC(ofs, size)
						UNTIL num <= 0;
						DisposeSRB(srb);
						res := Disks.Ok
					ELSE
						IF num = 0 THEN res := Disks.Ok ELSE res := 4001 (* blocks out of range *) END
					END
				ELSE
					res := Disks.Unsupported
				END;
(*
				IF Trace & (op = Disks.Read) THEN
					KernelLog.Enter;
					KernelLog.String("Read "); KernelLog.Int(res, 1); KernelLog.Ln;
					KernelLog.Memory(orgadr, orgsize);
					KernelLog.Exit
				END
*)
			END Transfer;

			PROCEDURE GetSize* (VAR size, res: LONGINT);
			BEGIN
				size := capacity; res := Disks.Ok;
				IF TraceVerbose THEN
					KernelLog.Enter;
					KernelLog.String("NCR GetSize "); KernelLog.Int(size, 1); KernelLog.Char(" "); KernelLog.Int(res, 1);
					KernelLog.Exit
				END
			END GetSize;

		END Device;

VAR
	fallbackBufAdr: LONGINT;
	fallbackBuf: POINTER TO ARRAY OF CHAR;
	Ncopies: LONGINT;
	freeSRB: ASPI.ExecIOCmdSRB;

	PROCEDURE AcquireBuffer(VAR adr: LONGINT);
	BEGIN {EXCLUSIVE}
		INC(Ncopies);
		AWAIT(fallbackBufAdr # 0);
		adr := fallbackBufAdr;
		fallbackBufAdr := 0
	END AcquireBuffer;

	PROCEDURE ReleaseBuffer(adr: LONGINT);
	BEGIN {EXCLUSIVE}
		fallbackBufAdr := adr
	END ReleaseBuffer;

	PROCEDURE NewSRB(VAR srb: ASPI.ExecIOCmdSRB);
	BEGIN {EXCLUSIVE}
		IF freeSRB = NIL THEN
			NEW(srb)
		ELSE
			srb := freeSRB; freeSRB := srb.next
		END
	END NewSRB;

	PROCEDURE DisposeSRB(srb: ASPI.ExecIOCmdSRB);
	BEGIN {EXCLUSIVE}
		srb.next := freeSRB; freeSRB := srb
	END DisposeSRB;

(* ---- Get disk capacity and block size ---- *)

	PROCEDURE GetCapacity(ha, target, lun: CHAR; VAR capacity, blocksize: LONGINT);
	VAR srb: ASPI.ExecIOCmdSRB; buf: ARRAY 8 OF CHAR; i: LONGINT;
	BEGIN
		NEW(srb);
		srb.HaId := ha; srb.Flags := {ASPI.FlagsDirIn}; srb.Target := target; srb.Lun := lun;
		srb.BufLen := 8;
		srb.BufPointer := Machine.Ensure32BitAddress (ADDRESSOF(buf[0]));
		srb.SenseLen := 0X;
		srb.CDBLen := 0AX;
		srb.CDB[0] := 25X; srb.CDB[1] := LSH(lun, 5); srb.CDB[2] := 0X; srb.CDB[3] := 0X;
		srb.CDB[4] := 0X; srb.CDB[5] := 0X; srb.CDB[6] := 0X; srb.CDB[7] := 0X; srb.CDB[8] := 0X; srb.CDB[9] := 0X;
		srb.meas := NIL;
		srb.Status := 55X;
		ASPI.SendASPICommand(srb, TRUE);
		ASSERT(srb.Status = ASPI.SSComp);
		capacity := 0; blocksize := 0;
		FOR i := 0 TO 3 DO
			capacity := capacity*100H + ORD(buf[i]);
			blocksize := blocksize*100H + ORD(buf[i+4])
		END
	END GetCapacity;

	PROCEDURE Init;
	VAR res, ha, targ, lun, num, regres: LONGINT; srb: ASPI.GetDevTypeSRB; dev: Device; name: Plugins.Name;
	BEGIN
		freeSRB := NIL;
		NEW(fallbackBuf, 2*BS);
		fallbackBufAdr := Machine.Ensure32BitAddress (ADDRESSOF(fallbackBuf[0]));
		res := PageSize - fallbackBufAdr MOD PageSize;
		IF res < BS THEN INC(fallbackBufAdr, res) END;
		num := 0;
		res := ASPI.GetASPISupportInfo();
		IF CHR(LSH(res, -8)) = ASPI.SSComp THEN
			res := res MOD 100H;
			NEW(srb); ha := 0;
			WHILE ha < res DO
				targ := 0;
				WHILE targ < 7 DO
					lun := 0; srb.Status := ASPI.SSComp;
					WHILE (lun < 8) & (srb.Status = ASPI.SSComp) DO
						(*KernelLog.String("Init: ha:"); LogInt(ha); KernelLog.String("  target:"); LogInt(targ);
						KernelLog.String("  lun:"); LogInt(lun); KernelLog.Ln;*)
						srb.HaId := CHR(ha); srb.Flags := {};
						srb.Target := CHR(targ); srb.Lun := CHR(lun);
						ASPI.SendASPICommand(srb, FALSE);
						(*KernelLog.String("DevType: "); LogInt(ORD(srb.DevType)); KernelLog.Ln;*)
						IF (srb.Status = ASPI.SSComp) & (srb.DevType = 0X) & (num < 10) THEN (* only support direct access devices *)
							NEW(dev);
							name := "Symbios0";  name[7] := CHR(48 + num); INC(num);
							dev.SetName(name);
							dev.flags := {};
							(*IF RemovableBit IN dev.id.type THEN INCL(dev.flags, Disks.Removable) END;*)
							COPY(dev.name, dev.desc);
							dev.ha := CHR(ha); dev.target := CHR(targ);
							dev.lun := CHR(lun);
							dev.writePreComp := 0;
							GetCapacity(dev.ha, dev.target, dev.lun, dev.capacity, dev.blockSize);
							Disks.registry.Add(dev, regres);
							ASSERT(regres = Plugins.Ok)
						END;
						INC(lun)
					END;
					INC(targ)
				END;
				INC(ha)
			END
		ELSE
			KernelLog.String("SymbiosDisk: no host adapter found"); KernelLog.Ln
		END
	END Init;

	(** Install - Install the driver in the Disk module. *)
	(** The install command has no effect, as all disk devices are installed when the module is loaded. *)

	PROCEDURE Install*;
	END Install;

BEGIN
	Init
END SymbiosDisks.

ASPI.Stop
SCSIDisk.ShowPartitions
System.Free SCSIDisk ASPI ~

		xferPhysAdr: ARRAY MaxPRD OF Machine.Range;
	Machine.TranslateVirtual(bufAdr, num*BS, n, c.xferPhysAdr); ASSERT(n > 0);
