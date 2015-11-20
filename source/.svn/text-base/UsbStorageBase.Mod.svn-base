MODULE UsbStorageBase; (** AUTHOR "staubesv"; PURPOSE " USB Mass Storage Driver Base Class"; *)
(**
 *	Bluebottle USB Mass Storage Driver Base Class
 *
 *	This module is the base for all USB mass storage device drivers. There are three different transport layers:
 *
 *		UsbStorageCbi.Mod		CB/I transport layer
 *		UsbStorageBot.Mod		Bulk-only transport layer
 *		UsbStorageScm.Mod		SCM transport layer
 *
 * This driver is based on the work of Christian Plattner.
 *
 * Usage:
 *
 *	UsbStorageBase.Show ~ displays a list of all USB storage devices
 *
 * References:
 *
 *	[1] Universal Serial Bus Mass Storage Class Specification Overview, Revision 1.2, June 23, 2003
 *	[2] Universal Serial Bus Mass Storage Class UFI Command Specification, Revision 1.0, December 1998
 *	[3] Universal Serial Bus Mass Storage Specification for Bootability, Revision 1.0, October 25, 2004
 *
 *	All references available at www.usb.org
 *
 * History:
 *
 *	30.09.2000 	cp first release
 *	20.10.2000 	cp many improvements (BulkOnly, UTS)
 *	20.11.2005 	Added support for logical devices, use Disks.Mod-compatible result codes on transport layer (staubesv)
 *	24.11.2005 	Added UFI commands TestUnitReady, Allow/Prevent medium removal (staubesv)
 *	29.11.2005 	Added UFI commands SendDiagnostic and Start/Stop Unit (used and therefore named to EjectMedia,
 *				moved ReadCapacity to USB layer (staubesv)
 *	13.12.2005	Adapted to USBDI changes (staubesv)
 *	14.12.2005	UsbStorageDevice.Transfer, GetSize & Handle made exclusive (staubesv)
 *	15.12.2005	Fixed Bulk-Only reset recovery (staubesv)
 *	19.12.2005	Trim vendor/product strings (staubesv)
 *	03.01.2006	Use sequence number for CSW tag (staubesv)
 *	05.01.2006	Added TraceCBWs & TraceCSWs trace options (staubesv)
 *	12.01.2006	Removed data copying/memory allocation (staubesv)
 *	09.02.2006	Refactored driver: Introduced UsbStorageBase, UsbStorageCbi, UsbStorageBot,
 *				UsbStorageScm, UsbStorageBoot (staubesv)
 *	28.06.2006	Use UsbUtilties (staubesv)
 *	09.08.2006	Inquiry, TestUnitReady, ReadCapacity, Read & Write commands length set to 12 bytes since lower values broke the CBI Layer (staubesv)
 *	26.03.2007	Added NnofReads, NnofWrites, NnofOthers and NnofErrors statistics (staubesv)
 *)

IMPORT SYSTEM, KernelLog, Kernel, Commands, Disks, Plugins, Usbdi, Debug := UsbDebug, Lib := UsbUtilities;

CONST

	NoData* = {};
	DataIn* = {1};
	DataOut* = {2};

	(* Result codes *)
	(* From Disks.Mod *)
	ResOk* = Disks.Ok;
	ResWriteProtected* = Disks.WriteProtected;
	ResDeviceInUse* = Disks.DeviceInUse;
	ResMediaChanged* = Disks.MediaChanged;
	ResMediaMissing* = Disks.MediaMissing;
	ResUnsupported* = Disks.Unsupported;
	(* USB Storage Device Driver specific *)
	ResTimeout* = 30;
	ResShortTransfer* = 31;
	ResDeviceNotReady* = 32;
	ResDeviceNotReadyInit* = 33; (* Device need to be initialized *)
	ResSenseError* = 34; (* Do sensing *)
	ResError* = 35;
	ResFatalError* = 36; (* Device needs to be resetted *)
	ResDisconnected* = 37;

	MethodCBI* = 1;
	MethodCB* = 2;
	MethodBulkOnly* = 3;
	MethodSCMShuttle* = 4;

	ProtocolUFI* = 100;  	(* UFI *)
	ProtocolUTS* = 101; 	(* USB TRANSPARENT SCSI => UTS (plattner definition) *)
	ProtocolRBC* = 102; 	(* RBC = reduced block commands, often used for flash devices *)
	Protocol8020* = 103; 	(* ATAPI for CDROM *)
	Protocol8070* = 104; 	(* ATAPI for floppy drives and similar devices *)
	ProtocolQIC157* = 105;	(* QIC, meaning the tape company. Typically used by tape devices *)

	(* UFI Commands according UFI Command Specification *)
	UfiFormatUnit = 04H; 			(* Format unformatted media; not implemented *)
	UfiInquiry = 12H;				(* Get device information *)
	UfiStartStop = 1BH;				(* Request a removable-media device to load or unload its media; partially  implemented *)
	UfiModeSelect = 55H;			(* Allow the host to set parameters in a peripheral (mode sense should be issued prior to mode select); not implemented *)
	UfiModeSense = 5AH;			(* Report parameters to the host. *)
	UfiAllowRemoval = 1EH;			(* Prevent or allow the removal of media from a removable media device *)
	UfiRead10* = 28H;				(* Transfer binary data from the media to the host *)
	UfiRead12 = 0A8H;				(* Transfer binary data from the media to the host not implemented *)
	UfiReadCapacity = 25H;			(* Report current media capacity *)
	UfiReadFormatCapacity = 23H; 	(* Read current media capacity and formattable capacities supported by media; not implemented *)
	UfiRequestSense = 03H;			(* Tansfer status sense data to the host *)
	UfiRezeroUnit = 01H;			(* Position a head of the drive to zero track not implemented *)
	UfiSeek10 = 2BH;				(* Seek the device to a specified address not implemented *)
	UfiSendDiag = 1DH;				(* Perform a hard reset and execute diagnostics  *)
	UfiTestUnitReady = 00H;			(* Request the device to report if it's ready *)
	UfiVerify = 2FH;					(* Verify data on the media not implemented *)
	UfiWrite10 = 2AH;				(* Transfer binary data from the host to the media *)
	UfiWrite12 = 0AAH;				(* Transfer binary data from the host to the media not implemented *)
	UfiWriteNVerify = 2EH;			(* Transfer binary data from the host to the media and verify data not implemented *)

	(* Device types as reported by the UFI Inquiry command *)
	DtSbcDirectAccess = 00H;
	DtCDROM = 05H;
	DtOpticalMemory = 07H;
	DtRbcDirectAccess = 0EH;

	RemovableBit = {7};

	(* UfiModeSense constants: Page Control Field *)
	PcCurrentValues = 0;
	PcChangeableValues = 1;
	PcDefaultValues = 2;
	PcSavedValues = 3;

	(* UfiModeSense constants: Page Code field *)
	PageRwErrorRecovery = 01H;
	PageFlexibleDisk = 05H;
	PageBlockAccessCapacities = 1BH;
	PageTimerAndProtect = 1CH;
	PageAll = 3FH; (* only for mode sense command *)

	(* Timeout values in milliseconds *)
	TransferTimeout = 20000;
	CommandTimeout = 5000;

TYPE

	(* Information delivered by UFI Inquiry command *)
	InquiryResult = POINTER TO RECORD
		deviceType : LONGINT; 			(* Peripheral device type; 00h: direct access device (floppy), 1FH > none *)
		removable : BOOLEAN; 			(* Removable media bit *)
		ansiVersion : LONGINT; 			(* Should be 0 for compatible devices *)
		additionalLength : LONGINT;
		validStrings : BOOLEAN; 		(* Are the fields below valid? *)
		vendor : ARRAY 9 OF CHAR;
		product : ARRAY 17 OF CHAR;
		revision : ARRAY 5 OF CHAR;
	END;

	(* Information delivered by UFI Mode Sense Command when Flexible Disk Page is requested *)
	FlexibleDiskPage = POINTER TO RECORD
		TransferRate : LONGINT; (* kbits/s *)
		NumberOfHeads : LONGINT;
		SectorsPerTrack : LONGINT; (* 1 - 63 *)
		BytesPerSector : LONGINT;
		NumberOfCylinders : LONGINT;
		MotorOnDelay, MotorOffDelay : LONGINT;
		MediumRotationRate : LONGINT; (* r.p.m. *)
	END;

TYPE

	UsbStorageDevice = OBJECT (Disks.Device)
	VAR
		usbDriver : StorageDriver;
		lun : LONGINT; (* Logical Unit Number of this storage device*)

		transportProtocol : LONGINT;

		(* Fields used by the DiskManager *)
		number : LONGINT; (* Suffix appended to name to get unique device name *)
		next : UsbStorageDevice;

		PROCEDURE Transfer* (op, block, num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR diskres: LONGINT);
		VAR direction : SET; cmd : ARRAY 12 OF CHAR; i, tlen, trans, offset, num0 : LONGINT;
		BEGIN {EXCLUSIVE}
			IF (op = Disks.Read) OR (op = Disks.Write) THEN
				FOR i := 0 TO 11 DO cmd[i] := 0X; END;
				IF op = Disks.Read THEN
					cmd[0] := CHR(UfiRead10); direction := DataIn;
				ELSE
					cmd[0] := CHR(UfiWrite10); direction := DataOut;
				END;
				cmd[1] := CHR(LSH(lun, 5));  (* Logical device number *)

				offset := ofs; num0 := num;
				WHILE num > 0 DO
					IF num > 65000 THEN trans := 65000; ELSE trans := num END;
					cmd[2] := CHR(LSH(block, -24));
					cmd[3] := CHR(LSH(block, -16));
					cmd[4] := CHR(LSH(block, -8));
					cmd[5] := CHR(block);
					cmd[7] := CHR(LSH(trans, -8));
					cmd[8] := CHR(trans);
					cmd[9] := 0X;
					diskres := usbDriver.InvokeTransport(cmd, 12, direction, data, offset, trans * blockSize, tlen, TransferTimeout);
					IF diskres # Disks.Ok THEN RETURN; END;
					block := block + trans;
					num := num - trans;
					offset := offset + (trans * blockSize);
				END;

				IF Disks.Stats THEN
					IF (op = Disks.Read) THEN
						INC (NnofReads);
						IF (diskres = ResOk) THEN INC (NbytesRead, num0 * blockSize);
						ELSE INC (NnofErrors);
						END;
					ELSE
						INC (NnofWrites);
						IF (diskres = ResOk) THEN INC (NbytesWritten, num0 * blockSize);
						ELSE INC (NnofErrors);
						END;
					END;
				END;
			ELSE
				diskres := Disks.Unsupported;
				IF Disks.Stats THEN INC (NnofOthers); END;
			END;
		END Transfer;

		(** Get number of blocks and size of blocks using the UFI Read Capacity command *)
		PROCEDURE GetSize* (VAR size, res: LONGINT);
		BEGIN {EXCLUSIVE}
			IF Debug.Trace & Debug.traceInfo THEN KernelLog.String("UsbStorage: GetSize: "); KernelLog.Ln; END;
			(* Some devices I've seen didn't like to be asked for their capacity when no medium was inserted... *)
			res := usbDriver.WaitForReady(lun, 5000);
			IF (res # ResOk) & (res # ResMediaChanged) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: GetCapacity: command failed: "); ShowRes(res); KernelLog.Ln; END;
				RETURN;
			END;

			blockSize := 0; size := 0;
			res := usbDriver.ReadCapacity(lun, size, blockSize);

			IF ((res # ResOk) & (res # ResShortTransfer))  THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ReadCapacity: command failed: "); ShowRes(res); KernelLog.Ln; END;
				RETURN;
			END;
			res := ResOk; (* Allow short transfer *)
		END GetSize;

		PROCEDURE Handle*(VAR msg: Disks.Message; VAR diskres: LONGINT);
		VAR cmd : ARRAY 12 OF CHAR; i : LONGINT; fdp : FlexibleDiskPage;
		BEGIN {EXCLUSIVE}
			FOR i := 0 TO 11 DO cmd[i] := CHR(0); END;
			IF msg IS Disks.GetGeometryMsg THEN
			 	 IF transportProtocol = ProtocolUFI THEN
					WITH msg : Disks.GetGeometryMsg DO
						(* TODO: But what if the user changes the medium... *)
						fdp := usbDriver.ModeSense(lun, 0, PageFlexibleDisk, 32);
						IF fdp # NIL THEN
							msg.spt := fdp.SectorsPerTrack;
							msg.hds := fdp.NumberOfHeads;
							msg.cyls := fdp.NumberOfCylinders;
						ELSE
							(* assume 1440KB floppy disk *)
							msg.spt := 18; msg.hds := 2; msg.cyls := 80;
						END;
						IF Debug.Trace & Debug.traceScRequests THEN
							KernelLog.String("UsbStorageBase: Disk geometry CHS:");
							KernelLog.Int(msg.cyls, 0); KernelLog.String("x"); KernelLog.Int(msg.hds, 0); KernelLog.String("x"); KernelLog.Int(msg.spt, 0); KernelLog.Ln;
						END;
					END;
					diskres := Disks.Ok;
				ELSE
					diskres := Disks.Unsupported;
				END;
			ELSIF msg IS Disks.LockMsg THEN
				diskres := usbDriver.PreventMediumRemoval(lun, TRUE);
			ELSIF msg IS Disks.UnlockMsg THEN
				diskres := usbDriver.PreventMediumRemoval(lun, FALSE);
			ELSIF msg IS Disks.EjectMsg THEN
				diskres := usbDriver.EjectMedia(lun);
			ELSE
				diskres := Disks.Unsupported;
			END;
		END Handle;

	END UsbStorageDevice;

TYPE

	StorageDriver* = OBJECT (Usbdi.Driver);
	VAR
		sdevs- : UsbStorageDevice; (* list of storage devices associated to this driver *)
		description* : Plugins.Description;

		transportProtocol*, transportMethod* : LONGINT;

		bulkIn*, bulkOut*, interrupt* : LONGINT; (* adresses of the used endpoints *)
		bulkInPipe-, bulkOutPipe-, interruptPipe-, defaultPipe- : Usbdi.Pipe;

		initialize* : BOOLEAN; (* if TRUE, the Initialization() procedure is called *)

		timer : Kernel.Timer;

		(** Transport layer specific reset procedure *)
		PROCEDURE Reset*(timeout : LONGINT) : LONGINT;
		BEGIN
			HALT(301); RETURN 0; (* abstract *)
		END Reset;

		(** Transport layer specific transfer procedure *)
		PROCEDURE Transport*(cmd : ARRAY OF CHAR; cmdlen : LONGINT; dir :  SET;
			VAR buffer : ARRAY OF CHAR; ofs, bufferlen : LONGINT; VAR tlen : LONGINT; timeout : LONGINT) : LONGINT;
		BEGIN
			HALT(301); RETURN 0;  (* abstract *)
		END Transport;

		(* Bulk-only transport layer only *)
		PROCEDURE GetMaxLun*(VAR lun : LONGINT) : LONGINT;
		BEGIN
			HALT(301); RETURN 0; (* abstract *)
		END GetMaxLun;

		(* UFI command: Test whether the specified logical unit is ready *)
		PROCEDURE TestUnitReady(lun : LONGINT) : LONGINT;
		VAR cmd : ARRAY 12 OF CHAR; i, ignore : LONGINT;
		BEGIN
			cmd[0] := CHR(UfiTestUnitReady);
			cmd[1] := CHR(LSH(lun, 5));
			FOR i := 2 TO 11 DO cmd[i] := 0X; END;
			RETURN InvokeTransport(cmd, 12, NoData, cmd, 0, 0, ignore, 30000);
		END TestUnitReady;

		(* Issues TestUnitReady commands until device is ready or an error occurs *)
		PROCEDURE WaitForReady(lun, timeout : LONGINT) : LONGINT;
		VAR retry, res : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceScRequests THEN KernelLog.String("UsbStorageBase: WaitForReady..."); KernelLog.Ln; END;
			retry := 0;
			LOOP
				res := TestUnitReady(lun);
				IF (res = ResDisconnected) THEN
					EXIT;
				ELSIF (res = ResDeviceNotReady) OR (res = ResMediaChanged) THEN
					(* continue *)
				ELSE
					INC(retry);
				END;
				IF (retry > 3) OR (timeout < 0) THEN EXIT; END;
				Wait(100);
				timeout := timeout - 100;
			END;
			IF Debug.Trace & Debug.traceScRequests THEN KernelLog.String("UsbStorageBase: WaitForReady done, res: "); ShowRes(res); KernelLog.Ln; END;
			RETURN res;
		END WaitForReady;

		(* UFI command: Start/Stop Unit. 														*)
		(* Note: Since UFI devices control the motor on/off themselves, it's not implemented here.	*)
		(* We just use the command to eject the media, thus the name							*)
		PROCEDURE EjectMedia(lun : LONGINT) : LONGINT;
		VAR cmd, data : ARRAY 12 OF CHAR; i, tlen, res : LONGINT;
		BEGIN
			cmd[0] := CHR(UfiStartStop);
			cmd[1] := CHR(LSH(lun, 5));
			FOR i := 2 TO 11 DO cmd[i] := 0X; END;
			cmd[4] := CHR(2); (* Eject *)
			res := InvokeTransport(cmd, 12, DataOut, data, 0, 0, tlen, CommandTimeout);
			RETURN res;
		END EjectMedia;

		(* UFI command: Prevent/Allow Medium Removal *)
		PROCEDURE PreventMediumRemoval(lun : LONGINT; prevent : BOOLEAN) : LONGINT;
		VAR cmd, data : ARRAY 12 OF CHAR; i, tlen, res : LONGINT;
		BEGIN
			cmd[0] := CHR(UfiAllowRemoval);
			cmd[1] := CHR(LSH(lun, 5));
			FOR i := 2 TO 11 DO cmd[i] := 0X; END;
			IF prevent THEN cmd[4] := CHR(1); END;
			res := InvokeTransport(cmd, 12, DataOut, data, 0, 0, tlen, CommandTimeout);
			RETURN res;
		END PreventMediumRemoval;

		(* UFI command: Request UFI device to do a reset or perform a self-test *)
		PROCEDURE SendDiagnostic(lun : LONGINT) : LONGINT;
		VAR cmd, data : ARRAY 12 OF CHAR; i, tlen, res : LONGINT;
		BEGIN
			cmd[0] := CHR(UfiSendDiag);
			cmd[1] := CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(lun, 5)) + {2}));
			FOR i := 2 TO 11 DO cmd[i] := 0X; END;
			res := InvokeTransport(cmd, 12, DataOut, data, 0, 0, tlen, CommandTimeout);
			RETURN res;
		END SendDiagnostic;

		(* UFI command: Get the number of blocks and the blocksize of the specified logical unit *)
		PROCEDURE ReadCapacity(lun : LONGINT; VAR blocks, blocksize : LONGINT) : LONGINT;
		VAR cmd, data : ARRAY 12 OF CHAR; res, i, tlen : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceInfo THEN KernelLog.String("UsbStorage: ReadCapacity: "); KernelLog.Ln; END;
			cmd[0] := CHR(UfiReadCapacity);
			cmd[1] := CHR(LSH(lun, 5));
			FOR i := 2 TO 11 DO cmd[i] := CHR(0); END;

			blocks := 0; blocksize := 0;

			res := InvokeTransport(cmd, 12, DataIn, data, 0, 8, tlen, TransferTimeout);
			IF (res # ResOk) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ReadCapacity: command failed: "); ShowRes(res); KernelLog.Ln; END;
				RETURN res;
			END;

			FOR i := 0 TO 3 DO
				blocks := blocks*100H + ORD(data[i]);
				blocksize := blocksize*100H + ORD(data[4+i])
			END;
			INC(blocks); (* The device reports the highest valid block address -> also count block zero *)
			res := ResOk; (* allow short transfers *)
			IF Debug.Trace & Debug.traceInfo THEN
				KernelLog.String("UsbStorage: Disk info: Blocks: "); KernelLog.Int(blocks, 0);
				KernelLog.String(" blocksize: "); KernelLog.Int(blocksize, 0); KernelLog.String(" size: "); KernelLog.Int(blocks*blocksize, 0);
				KernelLog.Ln;
			END;
			RETURN ResOk;
		END ReadCapacity;

		(* UFI command: Inquiry the specified locigal unit; Returns NIL in error case *)
		PROCEDURE Inquiry(lun : LONGINT) : InquiryResult;
		VAR cmd : ARRAY 12 OF CHAR; data : ARRAY 36 OF CHAR; result : InquiryResult; i, j, tlen, res : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceInfo THEN
				KernelLog.String("UsbStorage: Inquiry logical device "); KernelLog.Int(lun, 0); KernelLog.String("... "); KernelLog.Ln;
			END;
			FOR i := 0 TO 11 DO cmd[i] := CHR(0); END;
			cmd[0] := CHR(UfiInquiry);
			cmd[1] := CHR(LSH(lun, 5));
			cmd[4] := CHR(36); (* maximum allocation length *)

			res := InvokeTransport(cmd, 12, DataIn, data, 0, 36, tlen, 50000);
			IF ((res # Disks.Ok) & (res # ResShortTransfer)) OR (tlen < 5) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Fatal, inquiry device error: "); ShowRes(res); KernelLog.Ln; END;
				RETURN NIL;
			END;

			NEW(result);
			result.deviceType := ORD(data[0]) MOD 32;
			IF SYSTEM.VAL(SET, ORD(data[1])) * RemovableBit # {} THEN
				result.removable := TRUE;
			END;
			result.ansiVersion := ORD(data[2]) MOD 8;
			result.additionalLength := ORD(data[4]);

			IF transportProtocol = ProtocolRBC THEN
				IF result.deviceType # DtRbcDirectAccess THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: RBC device type is not 0EH"); KernelLog.Ln; END;
					RETURN NIL;
				END;
			ELSIF (result.deviceType # DtSbcDirectAccess) & (result.deviceType # DtCDROM) & (result.deviceType # DtOpticalMemory) THEN
				IF Debug.Trace & Debug.traceInfo THEN KernelLog.String("UsbStorage: Device is not a storage device"); KernelLog.Ln; END;
				RETURN NIL;
			END;

			IF tlen >= 36 THEN
				result.validStrings := TRUE;
				j := 0; FOR i := 8 TO 15 DO result.vendor[j] := data[i]; INC(j); END; result.vendor[8] := 0X;
				j := 0; FOR i := 16 TO 31 DO result.product[j] := data[i]; INC(j); END; result.product[16] := 0X;
				j := 0; FOR i := 32 TO 35 DO result.revision[j] := data[i]; INC(j); END; result.revision[4] := 0X;
			END;
			IF Debug.Trace & Debug.traceInfo THEN ShowInquiryResult(result); END;
			RETURN result;
		END Inquiry;

		(* The mode sense command allows the UFI device to report medium or device parameters to the host *)
		PROCEDURE ModeSense(lun, pagecontrol, page, length : LONGINT) : FlexibleDiskPage;
		VAR cmd : ARRAY 12 OF CHAR; data : Usbdi.BufferPtr; actLen, res : LONGINT; fdp : FlexibleDiskPage;

			(* page[index] is first byte of flexible disk page *)
			PROCEDURE ParseFlexibleDiskPage(page : Usbdi.BufferPtr; index : LONGINT) : FlexibleDiskPage;
			VAR temp : LONGINT; fdp : FlexibleDiskPage;
			BEGIN
				ASSERT((page # NIL) & (LEN(page) - index >= 32));
				ASSERT(SYSTEM.VAL(LONGINT, (SYSTEM.VAL(SET, page[index]) * {0..5})) = PageFlexibleDisk);
				NEW(fdp);
				temp := LSH(ORD(page[index+2]), 8) + ORD(page[index+3]);
				IF temp = 00FAH THEN fdp.TransferRate := 250;
				ELSIF temp = 012CH THEN fdp.TransferRate := 300;
				ELSIF temp = 01F4H THEN fdp.TransferRate := 500;
				ELSIF temp = 03E8H THEN fdp.TransferRate := 1000;
				ELSIF temp = 07D0H THEN fdp.TransferRate := 2000;
				ELSIF temp = 1388H THEN fdp.TransferRate := 5000;
				ELSIF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorage: ParseFlexibleDiskPage: Warning: Parse error"); KernelLog.Ln;
				END;
				fdp.NumberOfHeads := ORD(page[index+4]);
				fdp.SectorsPerTrack := ORD(page[index+5]);
				fdp.BytesPerSector := LSH(ORD(page[index+6]), 8) + ORD(page[index+7]);
				fdp.NumberOfCylinders := LSH(ORD(page[index+8]), 8) + ORD(page[index+9]);
				fdp.MotorOnDelay := ORD(page[index+19]);
				fdp.MotorOffDelay := ORD(page[index+20]);
				IF fdp.MotorOffDelay = 0FFH THEN fdp.MotorOffDelay := 0; (* don't turn it off !! *) END;
				fdp.MediumRotationRate := LSH(ORD(page[index+28]), 8) + ORD(page[index+29]);
				IF Debug.Trace & Debug.traceInfo THEN ShowFlexibleDiskPage(fdp); END;
				RETURN fdp;
			END ParseFlexibleDiskPage;

		BEGIN
			length := length + 8; (* 8 additional bytes for mode parameter header *)
			cmd[0] := CHR(UfiModeSense);
			cmd[1] := CHR(LSH(lun, 5)); (* logical unit number *)
			cmd[2] := CHR(LSH(pagecontrol, 6) + page);
			cmd[3] := CHR(0); (* reserved *)
			cmd[5] := CHR(0); (* reserved *)
			cmd[6] := CHR(0); (* reserved *)
			cmd[7] := CHR(LSH(length, -8)); (* Parameter List Length (MSB)*)
			cmd[8] := CHR(length); (* Parameter List Length (LSB) *)
			cmd[9] := CHR(0); (* reserved *)
			cmd[10] := CHR(0); (* reserved *)
			cmd[11] := CHR(0); (* reserved *)

			NEW(data, length);
			res := InvokeTransport (cmd, 12, DataIn, data^, 0, length, actLen, CommandTimeout);
			IF ((res # Disks.Ok) OR ((res # ResShortTransfer) & (actLen < length))) THEN
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorage: UFI Mode Sense command failed."); KernelLog.Ln; END;
				RETURN NIL;
			END;

			IF (ORD(data[1]) + 100H*SYSTEM.VAL(LONGINT, ORD(data[0]))) # length + 8 THEN
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorage: ModeSense: Error: Wrong Mode Data Length returned."); KernelLog.Ln; END;
				RETURN NIL;
			END;

			(* parse the result *)
			CASE page OF
				PageFlexibleDisk : fdp := ParseFlexibleDiskPage(data, 8);
			ELSE
				IF Debug.Level >= Debug.Warnings THEN
					KernelLog.String("UsbStorage: ModeSense: Parsing of page type "); KernelLog.Hex(page,-2);
					KernelLog.String(" not (yet) supported."); KernelLog.Ln;
				END;
			END;
			RETURN fdp;
		END ModeSense;

		(* UFI command: The Request Sense command instructs the UFI device to transfer sense data to the host for
		 * the specified logical unit *)
		PROCEDURE RequestSense(lun, cmdlen : LONGINT) : LONGINT;
		VAR
			cmd : ARRAY 12 OF CHAR; data : ARRAY 36 OF CHAR;
			key, asc, ascq : CHAR;
			information : LONGINT;
			i, tlen, res : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceSensing THEN KernelLog.String("UsbStorage: Doing auto sense..."); KernelLog.Ln; END;
			IF (transportProtocol = ProtocolUTS) OR (transportProtocol = ProtocolRBC) THEN
				cmdlen := 6;
			END;
			FOR i := 0 TO 11 DO cmd[i] := CHR(0); END;
			cmd[0] := CHR(UfiRequestSense);
			cmd[1] := CHR(LSH(lun, 5));
			cmd[4] := CHR(18); (* allocation length (max. 18 Bytes) *)

			res := Transport(cmd, cmdlen, DataIn, data, 0, 18, tlen, 2000);

			IF (res = ResDisconnected) THEN
				RETURN res;
			ELSIF (res = ResShortTransfer) THEN
				IF (tlen < 14) THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Crappy device gives not enough sense data"); KernelLog.Ln; END;
					RETURN ResSenseError;
				ELSE
					(* sense >= 14 is ok *)
				END;
			ELSIF (transportProtocol = ProtocolUFI) & (res = ResSenseError) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: UFI autosense TransportSenseError"); KernelLog.Ln; END;
				(* thats ok *)
			ELSIF res # ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Sense error on protocol sense"); KernelLog.Ln; END;
				res := Reset(5000);
				RETURN ResSenseError;
			END;

			key := CHR(ORD(data[2]) MOD 16); asc := data[12]; ascq := data[13];

			IF Debug.Trace & Debug.traceSensing THEN
				IF SYSTEM.VAL(SET, ORD(data[0])) * {7} # {} THEN (* information field is valid *)
					information := ORD(data[3]) + 10H*ORD(data[4]) + 100H*ORD(data[5]) + 1000H*ORD(data[6]);
				END;
				ShowSenseData(key, asc, ascq, information, SYSTEM.VAL(SET, ORD(data[0])) * {7} # {});
			END;
			IF key = 0X THEN (* No sense -> okay *)
				IF (res = ResOk) OR (res = ResShortTransfer) THEN RETURN ResOk; END;
				RETURN ResError;
			ELSIF (key = 1X) THEN RETURN ResOk; (* Recovered error -> okay *)
			ELSIF (key = 2X) & (asc = 4X) & (ascq = 01X) THEN RETURN ResDeviceNotReady; (* Logical drive not ready - becoming ready *)
			ELSIF (key = 2X) & (asc = 4X) & (ascq = 02X) THEN RETURN ResDeviceNotReadyInit; (* Logical drive not ready - initialization required *)
			ELSIF (key = 2X) & (asc = 4X) & (ascq = 04X) THEN RETURN ResDeviceInUse; (* Logical drive not ready - format in progress *)
			ELSIF (key = 2X) & (asc = 4X) & (ascq = 0FFX) THEN RETURN ResDeviceInUse; (* Logical drive not ready - device is busy *)
			ELSIF (key = 2X) & (asc = 6X) & (ascq = 00X) THEN RETURN ResError; (* No reference position found *)
			ELSIF (key = 2X) & (asc = 8X) & (ascq = 00X) THEN RETURN ResError; (* Logical unit communication failure *)
			ELSIF (key = 2X) & (asc = 8X) & (ascq = 01X) THEN RETURN ResTimeout; (* Logical unit communication timeout *)
			ELSIF (key = 2X) & (asc = 8X) & (ascq = 80X) THEN RETURN ResError; (* Logical unit communication overrun *)
			ELSIF (key = 2X) & (asc = 3AX) & (ascq = 0X) THEN RETURN ResMediaMissing; (* Medium not present *)
			ELSIF (key = 2X) THEN RETURN ResError;
			ELSIF (key = 3X) THEN RETURN ResError; (* Medium Error *)
			ELSIF (key = 4X) THEN RETURN ResError; (* Hardware Error *)
			ELSIF (key = 5X) THEN RETURN ResUnsupported; (* Illegal Request *)
			ELSIF (key = 6X) & (asc = 28X) & (ascq = 00X) THEN RETURN ResMediaChanged;
			ELSIF (key = 6X) & (asc = 29X) & (ascq = 0X) THEN	RETURN ResDeviceNotReady; (* PowerOnReset *)
			ELSIF (key = 6X) THEN RETURN ResDeviceNotReady;
			ELSIF (key = 7X) THEN RETURN ResWriteProtected;
			ELSE
				RETURN ResError;
			END;
		END RequestSense;

	(*	PROCEDURE ReadWrite10(lun, blockSize, op, block, num : LONGINT; VAR data : ARRAY OF CHAR; ofs : LONGINT; VAR diskres : LONGINT);
		VAR cmd : ARRAY 12 OF CHAR;  trans, tlen, i, res : LONGINT; direction : SET;
		BEGIN
			FOR i:= 0 TO 11 DO cmd[i] := 0X; END;
			IF op = Disks.Read THEN
				cmd[0] := CHR(UfiRead10); direction := DataIn;
			ELSE
				cmd[0] := CHR(UfiWrite10); direction := DataOut;
			END;
			cmd[1] := CHR(LSH(lun, 5));  (* Logical device number *)

			WHILE num > 0 DO
				IF num > 65000 THEN trans := 65000; ELSE trans := num END;
				trans := trans * blockSize;
				cmd[2] := CHR(LSH(block, -24));
				cmd[3] := CHR(LSH(block, -16));
				cmd[4] := CHR(LSH(block, -8));
				cmd[5] := CHR(block);
				cmd[7] := CHR(LSH(num, -8));
				cmd[8] := CHR(num);
				diskres := InvokeTransport(cmd, 12, direction, data, ofs, trans, tlen, TransferTimeout);
				IF diskres # Disks.Ok THEN RETURN; END;
				block := block + trans;
				num := num - trans;
			END;
		END ReadWrite10;

		PROCEDURE ReadWrite12(lun, op, block, num : LONGINT; VAR data : ARRAY OF CHAR; ofs : LONGINT; VAR diskres : LONGINT);
		VAR cmd : ARRAY 12 OF CHAR;  trans, tlen, i, res : LONGINT; direction : SET;
		BEGIN
			ASSERT(num < MAX(LONGINT));
			FOR i:= 0 TO 11 DO cmd[i] := 0X; END;
			IF op = Disks.Read THEN
				cmd[0] := CHR(UfiRead12); direction := DataIn;
			ELSE
				cmd[0] := CHR(UfiWrite12); direction := DataOut;
			END;
			cmd[1] := CHR(LSH(lun, 5));  (* Logical device number *)
			cmd[2] := CHR(LSH(block, -24));
			cmd[3] := CHR(LSH(block, -16));
			cmd[4] := CHR(LSH(block, -8));
			cmd[5] := CHR(block);
			cmd[6] := CHR(LSH(num, -24));
			cmd[7] := CHR(LSH(num, -16));
			cmd[8] := CHR(LSH(num, -8));
			cmd[9] := CHR(num);
			diskres := InvokeTransport(cmd, 12, direction, data, ofs, trans, tlen, TransferTimeout);
		END ReadWrite12; *)

		(* Generic Transport Handler  *)
		PROCEDURE InvokeTransport (cmd : ARRAY OF CHAR; cmdlen : INTEGER; dir : SET;
			VAR data : ARRAY OF CHAR; ofs, datalen : LONGINT; VAR tlen : LONGINT; timeout : LONGINT) : LONGINT;
		VAR
			sensecmdlen, res, retry, i : LONGINT; forceRetry : BOOLEAN;
		BEGIN {EXCLUSIVE}
			(* here one could add additional stuff for the different protocols *)
			IF transportProtocol = ProtocolUFI THEN
				cmdlen := 12; sensecmdlen := 12;
			ELSIF (transportProtocol = ProtocolUTS) OR (transportProtocol = ProtocolRBC) THEN
				(* all ok *) sensecmdlen := 6;
			ELSIF (transportProtocol = Protocol8020) OR (transportProtocol = Protocol8070) THEN
				cmdlen := 12; sensecmdlen := 12;
			ELSIF transportProtocol = ProtocolQIC157 THEN
				cmdlen := 12; sensecmdlen := 12;
			END;

			retry := 0; (* retries for "power up/reset" and "lun becoming ready" *)

			LOOP
				IF Debug.Trace & Debug.traceScTransfers THEN
					KernelLog.String("UsbStorageBase: [cmd: ");
					IF transportProtocol = ProtocolUFI THEN ShowUFICmd(cmd[0]); END;
					FOR i := 0 TO cmdlen-1 DO KernelLog.String(" "); KernelLog.Hex(ORD(cmd[i]), -2); END;
					KernelLog.String(" BufferLen: "); KernelLog.Int(datalen, 0); KernelLog.String(" Bytes]");
					KernelLog.Ln;
				END;
				res := Transport(cmd, cmdlen, dir, data, ofs, datalen, tlen, timeout);
				IF Debug.Trace & Debug.traceScTransfers THEN
					KernelLog.String("UsbStorageBase: Sent "); KernelLog.Int(cmdlen, 0); KernelLog.String(" bytes commands, res: ");
					ShowRes(res); KernelLog.Ln;
				END;

				IF (res = ResDisconnected) THEN
					RETURN res;
				END;

				forceRetry := FALSE;
				IF (res = ResFatalError) OR (res = ResTimeout) THEN
					res := Reset(5000); (* ignore res *)
					IF res # ResOk THEN
					(*	TODO:
						lun := SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, ORD(cmd[1])) * {5..7}, -5));
						res := SendDiagnostic(lun); (* hardware reset; ignore res *) *)
						RETURN ResFatalError;
					ELSE
						forceRetry := TRUE;
						res := ResError; (* retry *)
					END;
				END;

				IF (res = ResShortTransfer) & (transportMethod # MethodCB) THEN
					IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorageBase: Had a short read"); KernelLog.Ln; END;
					RETURN ResShortTransfer;
				END;

				(* Do an auto-sense if something was not ok or if we are using the CB (not CBI) transport method *)
				IF (res = ResOk) & (transportMethod # MethodCB) THEN
					RETURN ResOk;
				END;

				(* It makes no sense to auto-sense on Inquiry/Sense on UFI/CB (not CBI)*)
				IF (transportMethod = MethodCB) & (transportProtocol = ProtocolUFI) & ((res = ResOk) OR (res = ResShortTransfer)) THEN
					IF (ORD(cmd[0]) = UfiInquiry) OR (ORD(cmd[0]) = UfiRequestSense) THEN RETURN res; END;
				END;

				res := RequestSense(SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, ORD(cmd[1])) * {5..7}, -5)), sensecmdlen);
				IF Debug.Trace & Debug.traceScTransfers THEN KernelLog.String("UsbStorageBase: Sent sense command, res: "); ShowRes(res); KernelLog.Ln; END;

				IF (res = ResWriteProtected) OR (res = ResDeviceInUse) OR (res = ResMediaMissing) OR (res = ResUnsupported) OR (res = ResDisconnected)THEN
					RETURN res; (* don't retry *)
				END;

				IF forceRetry OR (res = ResDeviceNotReady) THEN
					INC(retry);
					IF retry = 4 THEN
						IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorageBase: Too many protocol retries, giving up"); KernelLog.Ln; END;
						EXIT;
					ELSE
						IF Debug.Trace & Debug.traceScTransfers THEN KernelLog.String("UsbStorageBase: Retry #"); KernelLog.Int(retry, 0); KernelLog.Ln; END;
					END;
				ELSE
					EXIT;
				END;

				Wait(50); (* try again *)
			END;
			RETURN res;
		END InvokeTransport;

		PROCEDURE Initialization*() : BOOLEAN;
		BEGIN
			(* dummy *)
			RETURN TRUE;
		END Initialization;

		PROCEDURE RegisterDevice(lun : LONGINT) : BOOLEAN;
		VAR stordev : UsbStorageDevice; info : InquiryResult; i, j : LONGINT;
		BEGIN
			info := Inquiry(lun);
			IF info # NIL THEN
				NEW(stordev);
				stordev.SetName("USB");
				IF info.validStrings THEN (* override description *)
					Lib.TrimWS(info.vendor);
					stordev.desc := ""; i := 0; j := 0;
					LOOP (* append vendor string *)
						IF (i >= LEN(info.vendor)) OR (info.vendor[i] = 0X) THEN EXIT; END;
						stordev.desc[j] := info.vendor[i];
						INC(i); INC(j);
					END;
					IF j # 0 THEN stordev.desc[j] := " "; INC(j); END;
					Lib.TrimWS(info.product);
					i := 0;
					LOOP (* append product string *)
						IF (i >= LEN(info.product)) OR (info.product[i] = 0X) THEN EXIT; END;
						stordev.desc[j] := info.product[i];
						INC(i); INC(j);
					END;
					stordev.desc[j] := 0X;
				ELSE (* use USB vendor/product strings *)
					stordev.desc := description;
				END;
				stordev.lun := lun;
				stordev.transportProtocol := transportProtocol;
				stordev.blockSize := 0;
				stordev.flags := {}; stordev.table := NIL; stordev.openCount := 0;
				stordev.usbDriver := SELF;
				IF (info.deviceType = DtCDROM) OR (info.deviceType = DtOpticalMemory) THEN
					stordev.flags := stordev.flags + {Disks.ReadOnly};
				END;
				IF info.removable THEN stordev.flags := stordev.flags + {Disks.Removable}; END;
				diskManager.Add(stordev);
				RETURN TRUE;
			ELSE
				IF Debug.Level >= Debug.Default THEN
					KernelLog.String("UsbStorage: Inquiry for device LUN "); KernelLog.Int(lun, 0); KernelLog.String(" failed."); KernelLog.Ln;
				END;
				RETURN FALSE;
			END;
		END RegisterDevice;

		PROCEDURE RegisterDevices() : BOOLEAN;
		VAR lun, maxlun, res : LONGINT; succeeded : LONGINT; (* How many storage device were added to the disk manager? *)
		BEGIN
			maxlun := 0; succeeded := 0;
			IF transportMethod = MethodBulkOnly THEN (* logical devices support *)
				res := GetMaxLun(maxlun);
				IF res = ResOk THEN
					IF Debug.Trace & Debug.traceInfo THEN KernelLog.String("UsbStorageBase: MaxLUN is "); KernelLog.Int(maxlun, 0); KernelLog.Ln; END;
				ELSIF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorageBase: GetMaxLun failed: "); ShowRes(res); KernelLog.Ln;
				END;
			END;

			FOR lun := 0 TO maxlun DO
				IF RegisterDevice(lun) THEN INC(succeeded); END;
			END;

			RETURN succeeded > 0;
		END RegisterDevices;

		PROCEDURE Connect*(): BOOLEAN;
		BEGIN
			(* note that this procedure is common to the Bulkonly, CB and CB/I transport layer *)
			(* get the default control pipe *)
			defaultPipe := device.GetPipe(0);

			(* get the bulk pipes *)
			bulkInPipe := device.GetPipe(bulkIn);
			bulkOutPipe := device.GetPipe(bulkOut);

			IF (bulkInPipe=NIL) OR (bulkOutPipe=NIL)  THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Could not allocate pipes"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* if the interface support a interrupt endpoint, get the corresponding pipe *)
			IF (interrupt # 0) & (transportMethod # MethodBulkOnly) THEN
				interruptPipe := device.GetPipe(interrupt);
				IF interruptPipe = NIL THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Could not allocate interrupt pipe."); KernelLog.Ln; END;
					RETURN FALSE;
				END;
			END;

			IF initialize & ~Initialization() THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Could not initialize device."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			IF ~RegisterDevices() THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Error while registering new devices."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			RETURN TRUE;
		END Connect;

		PROCEDURE Disconnect*;
		BEGIN
			diskManager.RemovedDriver(SELF);
		END Disconnect;

		PROCEDURE Wait(ms : LONGINT);
		BEGIN
			timer.Sleep(ms);
		END Wait;

		PROCEDURE &Init*;
		BEGIN
			NEW(timer);
		END Init;

	END StorageDriver;

TYPE

	(* Manages a list of all installed USB storage devices and registers/unregisters them at the Disks.registry *)
	DiskManager = OBJECT
	VAR
		storageDeviceList : UsbStorageDevice;
		suffixUsed : ARRAY 100 OF BOOLEAN;
		regName : ARRAY 32 OF CHAR;
		res : LONGINT;

		PROCEDURE Add*(dev : UsbStorageDevice);
		VAR i : LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT(dev#NIL);
			(* add new device to list *)
			dev.next := storageDeviceList.next; storageDeviceList.next := dev;

			(* get unused suffix *)
			i := 0; WHILE suffixUsed[i] & (i < 100) DO INC(i) END;
			IF (i = 99) & suffixUsed[99] THEN
				KernelLog.String("UsbStorage: Can't register storage device. Maximal 100 devices supported."); KernelLog.Ln;
				RETURN;
			END;

			(* generate unique device name *)
			suffixUsed[i] := TRUE; dev.number := i;

			i := 1; WHILE (dev.name[i] # 0X) & (i < 32) DO INC(i); END;
			IF (dev.name[i] # 0X) THEN
				KernelLog.String("UsbStorage: Error: Couldn't register the device "); KernelLog.String(dev.name);
				KernelLog.String(" (device names shall be 2-30 characters long (incl. 0X)"); KernelLog.Ln;
				suffixUsed[dev.number] := FALSE;
				RETURN;
			END;

			COPY(dev.name, regName);

			IF dev.number < 10 THEN
				regName[i] := CHR(ORD("0") + dev.number); regName[i+1] := 0X;
			ELSIF dev.number < 100 THEN
				regName[i] := CHR(ORD("0") + dev.number DIV 10);
				regName[i+1] := CHR(ORD("0") + dev.number MOD 10); regName[i+2] := 0X;
			END;

			dev.SetName(regName);

			Disks.registry.Add(dev, res);
			IF res # Plugins.Ok THEN
				KernelLog.String("UsbStorage: Error: Couldn't add device to Disks.registry (Error code: ");
				KernelLog.Int(res, 0); KernelLog.String(")"); KernelLog.Ln;
				suffixUsed[dev.number] := FALSE;
				RETURN;
			END;
			IF Debug.Verbose THEN
				KernelLog.String("UsbStorage: Storage device "); KernelLog.String(dev.name);
				KernelLog.String(" ("); KernelLog.String(dev.desc); KernelLog.String(") is now accessible."); KernelLog.Ln;
			END;
		END Add;

		(** Remove storage device from Disks.registry. *)
		PROCEDURE Remove*(dev : UsbStorageDevice);
		VAR temp : UsbStorageDevice;
		BEGIN {EXCLUSIVE}
			temp:=storageDeviceList;
			WHILE (temp.next#NIL) & (temp.next.name#dev.name) DO temp:=temp.next; END;
			IF (temp.next=NIL) OR (temp.next.name#dev.name) THEN
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbStorage: Warning: Couldn't remove device from registry (device not found)"); KernelLog.Ln; END;
			ELSE
				temp.next := temp.next.next;
				Disks.registry.Remove(dev);
				suffixUsed[dev.number]:=FALSE;
			END;
			IF Debug.Verbose THEN
				KernelLog.String("UsbStorage: Removed storage device "); KernelLog.String(dev.name);
				KernelLog.String(" ("); KernelLog.String(dev.desc); KernelLog.String(")"); KernelLog.Ln;
			END;
		END Remove;

		(* Remove all storage devices associated to the specifed storage device driver *)
		PROCEDURE RemovedDriver*(driver : StorageDriver);
		VAR temp : UsbStorageDevice;
		BEGIN {EXCLUSIVE}
			temp := storageDeviceList;
			WHILE(temp # NIL) & (temp.next # NIL) DO
				IF temp.next.usbDriver = driver THEN
					Disks.registry.Remove(temp.next);
					suffixUsed[temp.next.number] := FALSE;
					IF Debug.Verbose THEN
						KernelLog.String("UsbStorage: Remove storage device "); KernelLog.String(temp.next.name);
						KernelLog.String(" ("); KernelLog.String(temp.next.desc); KernelLog.String(")"); KernelLog.Ln;
					END;
					temp.next := temp.next.next;
				ELSE
					temp := temp.next;
				END;
			END;
		END RemovedDriver;

		(* Removes all USB storage devices from the Disks.registry. *)
		PROCEDURE RemoveAll*;
		VAR temp : UsbStorageDevice;
		BEGIN {EXCLUSIVE}
			temp := storageDeviceList.next;
			WHILE temp # NIL DO
				Disks.registry.Remove(temp);
				suffixUsed[temp.number] := FALSE;
				temp := temp.next;
			END;
			storageDeviceList.next := NIL;
			IF Debug.Verbose THEN KernelLog.Enter; KernelLog.String("UsbStorage: All storage devices removed."); KernelLog.Exit; END;
		END RemoveAll;

		(* Displays a list of all USB storage devices which are registered at the DiskManager *)
		PROCEDURE Show;
		VAR temp : UsbStorageDevice;
		BEGIN
			KernelLog.String("UsbStorage: Accessible USB storage devices:"); KernelLog.Ln;
			IF storageDeviceList.next=NIL THEN
				KernelLog.String("No devices registred.");
			ELSE
				temp := storageDeviceList.next;
				WHILE temp # NIL DO
					KernelLog.String(temp.name); KernelLog.String(" ("); KernelLog.String(temp.desc); KernelLog.String(")"); KernelLog.Ln;
					temp := temp.next;
				END;
				KernelLog.Ln;
			END;
		END Show;

		PROCEDURE &Init*;
		BEGIN
			NEW(storageDeviceList);
		END Init;

	END DiskManager;

VAR
	diskManager- : DiskManager;
	performance- : LONGINT;

(* displays the UFI command to KernelLog *)
PROCEDURE ShowUFICmd(cmd : CHAR) ;
BEGIN
	IF Debug.Trace THEN
	CASE ORD(cmd) OF
		04H : KernelLog.String("Format Unit");
		| 12H :  KernelLog.String("Inquiry");
		| 55H : KernelLog.String("Mode Select");
		| 5AH : KernelLog.String("Mode Sense");
		| 1EH : KernelLog.String("Prevent-Allow Media Removal");
		| 28H : KernelLog.String("Read(10)");
		| 0A8H : KernelLog.String("Read(12)");
		| 25H : KernelLog.String("Read Capacity");
		| 23H : KernelLog.String("Read Format Capabilities");
		| 03H : KernelLog.String("Request Sense");
		| 01H : KernelLog.String("Rezero");
		| 2BH : KernelLog.String("Seek(10)");
		| 1DH : KernelLog.String("Send Diagnostic");
		| 1BH :KernelLog.String("Start-Stop Unit");
		| 00H : KernelLog.String("Test Unit Ready");
		| 2FH : KernelLog.String("Verify");
		| 2AH : KernelLog.String("Write(10)");
		| 0AAH : KernelLog.String("Write(12)");
		| 2EH : KernelLog.String("Write and Verify");
	ELSE
		KernelLog.String("Unknown Command("); KernelLog.Int(ORD(cmd), 0); KernelLog.String(")");
	END;
	END;
END ShowUFICmd;

PROCEDURE ShowInquiryResult(i : InquiryResult);
BEGIN
	IF Debug.Trace  THEN
	KernelLog.String("Inquiry data:"); KernelLog.Ln;
	IF i # NIL THEN
		KernelLog.String("   Peripheral device type: "); KernelLog.Int(i.deviceType, 0);
		IF i.removable THEN KernelLog.String(" [removable]"); ELSE KernelLog.String(" [not removable]"); END; KernelLog.Ln;
		KernelLog.String("   ANSI version: "); KernelLog.Int(i.ansiVersion, 0); KernelLog.Ln;
		KernelLog.String("   Additional Length: "); KernelLog.Int(i.additionalLength, 0); KernelLog.String("B"); KernelLog.Ln;
		KernelLog.String("   Vendor: "); KernelLog.String(i.vendor); KernelLog.Ln;
		KernelLog.String("   Product: "); KernelLog.String(i.product); KernelLog.Ln;
		KernelLog.String("   Revision: "); KernelLog.String(i.revision); KernelLog.Ln;
	ELSE
		KernelLog.String("Information not available");
	END;
	END;
END ShowInquiryResult;

PROCEDURE ShowFlexibleDiskPage(fdp : FlexibleDiskPage);
BEGIN
	IF Debug.Trace  THEN
	KernelLog.String("UsbStorage: Flexible Disk Page Contents: "); KernelLog.Ln;
	IF fdp # NIL THEN
		KernelLog.String("   Transfer rate: "); KernelLog.Int(fdp.TransferRate, 0); KernelLog.String(" kbits/s"); KernelLog.Ln;
		KernelLog.String("   Cylinders: "); KernelLog.Int(fdp.NumberOfCylinders, 0);
		KernelLog.String("   Heads: "); KernelLog.Int(fdp.NumberOfHeads, 0);
		KernelLog.String(" SectorsPerTrack: "); KernelLog.Int(fdp.SectorsPerTrack, 0);
		KernelLog.String(" BytesPerSector: "); KernelLog.Int(fdp.BytesPerSector, 0); KernelLog.Ln;
		KernelLog.String("   Motordelay On: "); KernelLog.Int(fdp.MotorOnDelay, 0);
		KernelLog.String(" Off: "); 	IF fdp.MotorOffDelay = 0 THEN KernelLog.String("Don't turn off!!"); ELSE KernelLog.Int(fdp.MotorOffDelay, 0); END;
		KernelLog.Ln;
		KernelLog.String("   Medium Rotation rate: "); KernelLog.Int(fdp.MediumRotationRate, 0); KernelLog.String(" rpm"); KernelLog.Ln;
	ELSE
		KernelLog.String("Information not available"); KernelLog.Ln;
	END;
	END;
END ShowFlexibleDiskPage;

PROCEDURE ShowSenseData(key, asc, ascq : CHAR;  information : LONGINT; valid : BOOLEAN);
BEGIN
	IF Debug.Trace THEN
	KernelLog.String("UsbStorage: Sense Key: "); KernelLog.Int(ORD(key), 0);
	KernelLog.String(" asc: "); KernelLog.Hex(ORD(asc), 0); KernelLog.String(" ascq: "); KernelLog.Hex(ORD(ascq), 0); KernelLog.String(" -> ");
	IF key = 0X THEN KernelLog.String("Device reports error, but auto-sense gives 0X");
	ELSIF (key = 1X) & (asc = 17X) & (ascq = 01X) THEN KernelLog.String("Recovered data with retries");
	ELSIF (key = 1X) & (asc = 18X) & (ascq = 00X) THEN KernelLog.String("Recovered data with ECC");
	ELSIF (key = 1X) THEN KernelLog.String("Recovered Error");
	ELSIF (key = 2X) & (asc = 04X) & (ascq = 01X) THEN KernelLog.String("Logical drive not ready, becoming ready");
	ELSIF (key = 2X) & (asc = 04X) & (ascq = 02X) THEN KernelLog.String("Logical drive not ready - initialization required");
	ELSIF (key = 2X) & (asc = 04X) & (ascq = 04X) THEN KernelLog.String("Logical unit not ready - format in progress");
	ELSIF (key = 2X) & (asc = 04X) & (ascq = 0FFX) THEN KernelLog.String("Logical drive not ready - device is busy");
	ELSIF (key = 2X) & (asc = 06X) & (ascq = 00X) THEN KernelLog.String("No reference position found");
	ELSIF (key = 2X) & (asc = 08X) & (ascq = 00X) THEN KernelLog.String("Logical unit communication failure");
	ELSIF (key = 2X) & (asc = 08X) & (ascq = 01X) THEN KernelLog.String("Logical unit communication timeout");
	ELSIF (key = 2X) & (asc = 08X) & (ascq = 80X) THEN KernelLog.String("Logical unit communication overrun");
	ELSIF (key = 2X) & (asc = 3AX) & (ascq = 00X) THEN KernelLog.String("Medium not present");
	ELSIF (key = 2X) & (asc = 54X) & (ascq = 00X) THEN KernelLog.String("USB to host system interface failure");
	ELSIF (key = 2X) & (asc = 80X) & (ascq = 00X) THEN KernelLog.String("Insufficient resources");
	ELSIF (key = 2X) & (asc = 0FFX) & (ascq = 0FFX) THEN KernelLog.String("Unknown error");
	ELSIF (key = 2X) THEN KernelLog.String("Not Ready");
	ELSIF (key = 3X) & (asc = 02X) & (ascq = 00X) THEN KernelLog.String("No seek complete");
	ELSIF (key = 3X) & (asc = 03X) & (ascq = 00X) THEN KernelLog.String("Write fault");
	ELSIF (key = 3X) & (asc = 10X) & (ascq = 00X) THEN KernelLog.String("ID CRC Error");
	ELSIF (key = 3X) & (asc = 11X) & (ascq = 00X) THEN KernelLog.String("Unrecovered read error");
	ELSIF (key = 3X) & (asc = 12X) & (ascq = 00X) THEN KernelLog.String("Address mark not found for ID field");
	ELSIF (key = 3X) & (asc = 13X) & (ascq = 00X) THEN KernelLog.String("Address mark not found for data field");
	ELSIF (key = 3X) & (asc = 14X) & (ascq = 00X) THEN KernelLog.String("Recorded entity not found");
	ELSIF (key = 3X) & (asc = 30X) & (ascq = 01X) THEN KernelLog.String("Cannot read medium - unknown format");
	ELSIF (key = 3X) & (asc = 31X) & (ascq = 01X) THEN KernelLog.String("Format command failed");
	ELSIF (key = 3X) THEN KernelLog.String("Medium Error");
	ELSIF (key = 4X) & (asc = 40X) THEN KernelLog.String("Diagnostic failure on component "); KernelLog.Int(ORD(ascq), 0);
	ELSIF (key = 4X) THEN KernelLog.String("Hardware Error");
	ELSIF (key = 5X) & (asc = 1AX) & (ascq = 00X) THEN KernelLog.String("Parameter list length error");
	ELSIF (key = 5X) & (asc = 20X) & (ascq = 00X) THEN KernelLog.String("Invalid command operation code");
	ELSIF (key = 5X) & (asc = 21X) & (ascq = 00X) THEN KernelLog.String("Logical block address out of range");
	ELSIF (key = 5X) & (asc = 24X) & (ascq = 00X) THEN KernelLog.String("Invalid field in command packet");
	ELSIF (key = 5X) & (asc = 25X) & (ascq = 00X) THEN KernelLog.String("Logical unit not supported");
	ELSIF (key = 5X) & (asc = 26X) & (ascq = 00X) THEN KernelLog.String("Invalid field in parameter list");
	ELSIF (key = 5X) & (asc = 26X) & (ascq = 01X) THEN KernelLog.String("Parameter not supported");
	ELSIF (key = 5X) & (asc = 26X) & (ascq = 02X) THEN KernelLog.String("Parameter value invalid");
	ELSIF (key = 5X) & (asc = 39X) & (ascq = 00X) THEN KernelLog.String("Saving parameters not supported");
	ELSIF (key = 5X) THEN KernelLog.String("Illegal Request");
	ELSIF (key = 6X) & (asc = 28X) & (ascq = 00X) THEN KernelLog.String("Not ready to ready transition - media changed");
	ELSIF (key = 6X) & (asc = 29X) & (ascq = 00X) THEN	KernelLog.String("PowerOnReset, retrying");
	ELSIF (key = 6X) & (asc = 2FX) & (ascq = 00X) THEN	KernelLog.String("Commands cleared by another indicator");
	ELSIF (key = 6X) THEN KernelLog.String("Unit Attention");
	ELSIF (key = 7X) & (asc = 27X) & (ascq = 00X) THEN KernelLog.String("Write protected media");
	ELSIF (key = 7X) THEN KernelLog.String("Data Protected");
	ELSIF (key = 8X) THEN KernelLog.String("Blank Check");
	ELSIF (key = 9X) THEN KernelLog.String("Vendor Specific");
	ELSIF (key = 0AX) THEN KernelLog.String("Reserved");
	ELSIF (key = 0BX) & (asc = 4EX) & (ascq = 00X) THEN KernelLog.String("Overlapped command attemted");
	ELSIF (key = 0BX) THEN KernelLog.String("Aborted command");
	ELSIF (key = 0CX) THEN KernelLog.String("Reserved");
	ELSIF (key = 0DX) THEN KernelLog.String("Volume Overflow");
	ELSIF (key = 0EX) THEN KernelLog.String("Miscompare");
	ELSIF (key = 0FX) THEN KernelLog.String("Reserved");
	ELSE KernelLog.String("Unkown");
	END;
	IF valid THEN KernelLog.String(" [information: "); KernelLog.Int(information, 0); KernelLog.String("]"); END;
	KernelLog.Ln;
	END;
END ShowSenseData;

PROCEDURE ShowRes(res : LONGINT);
BEGIN
	IF Debug.Level >= Debug.Errors THEN
	CASE res OF
		ResOk: KernelLog.String("OK");
		|ResWriteProtected: KernelLog.String("Write-Protected");
		|ResDeviceInUse: KernelLog.String("DeviceInUse");
		|ResMediaChanged: KernelLog.String("MediaChanged");
		|ResMediaMissing: KernelLog.String("MediaMissing");
		|ResUnsupported: KernelLog.String("Unsupported");
		|ResTimeout: KernelLog.String("Timeout");
		|ResShortTransfer: KernelLog.String("ShortTransfer");
		|ResDeviceNotReady: KernelLog.String("DeviceNotReady");
		|ResDeviceNotReadyInit: KernelLog.String("DeviceNotReady-need init");
		|ResSenseError: KernelLog.String("SenseError");
		|ResError: KernelLog.String("Error");
		|ResFatalError: KernelLog.String("FatalError");
		|ResDisconnected: KernelLog.String("Disconnected");
	ELSE
		KernelLog.String("Unknown(res="); KernelLog.Int(res, 0); KernelLog.String(")");
	END;
	END;
END ShowRes;

(** Shows all devices which are registered at the UsbStorage Disk Manager and the Disks.registry *)
PROCEDURE Show*(context : Commands.Context);
VAR table : Plugins.Table; i : LONGINT;
BEGIN
	(* show all devices which are registered at the UsbStorage disk manager *)
	diskManager.Show;
	(* show all devices registered at Disks.registry *)
	Disks.registry.GetAll(table);
	context.out.String("Storage devices registered at Disks.registry:"); context.out.Ln;
	IF table = NIL THEN
		context.out.String("No devices registered."); context.out.Ln;
	ELSE
		FOR i := 0 TO LEN(table)-1 DO
			context.out.String(table[i].name); context.out.String(" ("); context.out.String(table[i].desc); context.out.String(")"); context.out.Ln;
		END;
	END;
END Show;

(* ToBeRemoved *)
PROCEDURE SetMax*(context : Commands.Context);
BEGIN
	context.out.String("UsbStorage: Max performance mode."); context.out.Ln;
	performance := Usbdi.MaxPerformance;
END SetMax;

(* ToBeRemoved *)
PROCEDURE SetNormal*(context : Commands.Context);
BEGIN
	context.out.String("UsbStorage: Normal performance mode."); context.out.Ln;
	performance := Usbdi.Normal;
END SetNormal;

BEGIN
	NEW(diskManager);
	performance := Usbdi.MaxPerformance;
END UsbStorageBase.

UsbStorage.Install ~ SystemTools.Free UsbStorage ~

UsbStorage.Show ~