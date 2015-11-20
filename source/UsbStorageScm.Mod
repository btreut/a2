MODULE UsbStorageScm; (** AUTHOR "cplattner/staubesv"; PURPOSE "SCM transport layer of USB mass storage driver"; *)
(**
 * SCSI commands borrowed from SCSI.Mod.
 *
 * History:
 *
 *	09.02.2006	First release (staubesv)
 *)

IMPORT
	SYSTEM, KernelLog, Kernel,
	Usbdi, Base := UsbStorageBase, Debug := UsbDebug, UsbStorageCbi;

CONST

	(* Constans for the SCM USB-ATAPI Shuttle device *)
	ScmATA = 40X; ScmISA = 50X;

	(* Data registers *)
	ScmUioEpad = 80X; ScmUioCdt = 40X; ScmUio1 = 20X; ScmUio0 = 10X;

	(* User i/o enable registers *)
	ScmUioDrvrst = 80X; ScmUioAckd = 40X; ScmUioOE1 = 20X; ScmUioOE0 = 10X;

TYPE

	(* SCM Shuttle Transport Layer  *)
	SCMTransport* = OBJECT(UsbStorageCbi.CBITransport) (* same Reset procedure as CBITransport -> inherit it *)
	VAR
		(* these buffers will be re-used; they are created in &Init *)
		command : Usbdi.BufferPtr;
		buffer : Usbdi.BufferPtr;
		timer : Kernel.Timer;

		PROCEDURE ScmShortPack(p1, p2 : CHAR) : INTEGER;
		BEGIN
			RETURN SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET, ORD(p2)*256) + SYSTEM.VAL(SET, ORD(p1)));
		END ScmShortPack;

		PROCEDURE ScmSendControl(dir : SET; req, reqtyp, value, index : LONGINT; VAR buffer : Usbdi.Buffer;
			ofs, bufferlen, timeout : LONGINT) : LONGINT;
		VAR status : Usbdi.Status; 	ignore : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceScTransfers THEN
				KernelLog.String("UsbStorage: Sending SCM Control:"); KernelLog.String(" Direction: ");
				IF dir = Base.DataIn THEN KernelLog.String("In");
				ELSIF dir = Base.DataOut THEN KernelLog.String("Out");
				ELSE KernelLog.String("Unknown");
				END;
				KernelLog.String(" Bufferlen: "); KernelLog.Int(bufferlen, 0); KernelLog.String(" Offset: "); KernelLog.Int(ofs, 0); KernelLog.Ln;
			END;
			IF (bufferlen > 0) & (bufferlen+ofs > LEN(buffer)) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmSendControl: Buffer underrun"); KernelLog.Ln; END;
				RETURN Base.ResFatalError;
			END;

			IF device.Request(SYSTEM.VAL(SET, reqtyp), req, value, index, bufferlen, buffer) # Usbdi.Ok THEN
				status := defaultPipe.GetStatus(ignore);
				IF status = Usbdi.Stalled THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Stall on Transport SCM Control"); KernelLog.Ln; END;
					IF defaultPipe.ClearHalt() THEN
						RETURN Base.ResError;
					ELSE
						IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Failure on Transport SCM clear halt on Controlpipe"); KernelLog.Ln; END;
						RETURN Base.ResFatalError;
					END;
				END;
				IF status = Usbdi.InProgress THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Timeout on Transport SCM Control"); KernelLog.Ln; END;
					RETURN Base.ResTimeout;
				ELSIF status = Usbdi.Disconnected THEN
					RETURN Base.ResDisconnected;
				ELSIF status # Usbdi.Ok THEN
					IF Debug.Level >= Debug.Errors  THEN KernelLog.String("UsbStorage: Failure on Transport SCM Control"); KernelLog.Ln; END;
					RETURN Base.ResFatalError;
				END;
			END;
			RETURN Base.ResOk;
		END ScmSendControl;

		PROCEDURE ScmBulkTransport(dir : SET; VAR buffer : Usbdi.Buffer; ofs, bufferlen : LONGINT;
			VAR tlen : LONGINT; timeout : LONGINT) : LONGINT;
		VAR status : Usbdi.Status;
		BEGIN
			IF Debug.Trace & Debug.traceScTransfers THEN
				KernelLog.String("UsbStorage: Transfering SCM Data: Direction: ");
				IF dir = Base.DataIn THEN KernelLog.String("IN");
				ELSIF dir =  Base.DataOut THEN KernelLog.String("OUT");
				ELSE KernelLog.String("Unknown");
				END;
				KernelLog.String(" Bufferlen: "); KernelLog.Int(bufferlen, 0); KernelLog.String(" Offset: "); KernelLog.Int(ofs, 0);
				KernelLog.Ln;
			END;
			tlen := 0;
			IF bufferlen = 0 THEN RETURN Base.ResOk END;

			IF bufferlen + ofs > LEN(buffer) THEN
				IF Debug.Level >= Debug.Errors THEN
					KernelLog.String("UsbStorage: ScmBulkTransport: Buffer underrun");
					KernelLog.String(" (buffer length: "); KernelLog.Int(LEN(buffer), 0); KernelLog.String(")"); KernelLog.Ln;
				END;
				RETURN Base.ResFatalError;
			END;

			IF dir = Base.DataIn THEN
				bulkInPipe.SetTimeout(timeout);
				status := bulkInPipe.Transfer(bufferlen, ofs, buffer);
				tlen := bulkInPipe.GetActLen();
			ELSIF dir = Base.DataOut THEN
				bulkOutPipe.SetTimeout(timeout);
				status := bulkOutPipe.Transfer(bufferlen, ofs, buffer);
				tlen := bulkOutPipe.GetActLen();
			ELSE
				HALT(301);
			END;

			(* clear halt if STALL occured, but do not abort!!! *)
			IF status = Usbdi.Stalled THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Stall on SCM data phase"); KernelLog.Ln; END;
				(* only abort if clear halt fails *)
				IF ((dir=Base.DataIn) & ~bulkInPipe.ClearHalt()) OR ((dir=Base.DataOut) & ~bulkOutPipe.ClearHalt())  THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Failure on SCM bulk clear halt"); KernelLog.Ln; END;
					RETURN Base.ResFatalError;
				END;
			END;

			IF status = Usbdi.InProgress THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Timeout on SCM data phase"); KernelLog.Ln; END;
				RETURN Base.ResTimeout;
			ELSIF status = Usbdi.Disconnected THEN
				RETURN Base.ResDisconnected;
			ELSIF status = Usbdi.Error THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Failure on SCM bulk"); KernelLog.Ln; END;
				RETURN Base.ResFatalError;
			END;

			IF tlen # bufferlen THEN
				IF Debug.Level >= Debug.Errors THEN
					KernelLog.String("UsbStorage: ScmBulkTransport short read: ");
					KernelLog.Int(bufferlen, 0); KernelLog.Char("/"); KernelLog.Int(tlen, 0); KernelLog.Ln;
				END;
				RETURN Base.ResShortTransfer;
			END;
			RETURN Base.ResOk;
			END ScmBulkTransport;

		PROCEDURE ScmWaitNotBusy(timeout : LONGINT) : LONGINT;
		VAR status : CHAR; res : LONGINT;
		BEGIN
			LOOP
				res := ScmRead(ScmATA, 17X, status, 1000);
				IF res # Base.ResOk THEN
					IF (res = Base.ResDisconnected) OR (res = Base.ResFatalError) THEN RETURN res ELSE RETURN Base.ResError END;
				ELSIF (SYSTEM.VAL(SET, status) * {0}) # {} THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmWaitNotBusy: check condition"); KernelLog.Ln; END;
					RETURN Base.ResError;
				ELSIF (SYSTEM.VAL(SET, status) * {5}) # {} THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmWaitNotBusy: device fault"); KernelLog.Ln; END;
					RETURN Base.ResFatalError;
				ELSIF (SYSTEM.VAL(SET, status) * {7}) = {} THEN
					IF Debug.Trace & Debug.traceScTransfers THEN KernelLog.String("UsbStorage: ScmWaitNotBusy: good"); KernelLog.Ln; END;
					RETURN Base.ResOk;
				END;
				IF timeout # -1 THEN
					timeout  := timeout - 10; IF timeout < 0 THEN EXIT END;
				END;
				Wait(10);
			END;
			IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmWaitNotBusy: Timeout"); KernelLog.Ln; END;
			RETURN Base.ResTimeout;
		END ScmWaitNotBusy;

		PROCEDURE ScmReadUserIO(VAR dataflags: CHAR; timeout : LONGINT) : LONGINT;
		VAR res : LONGINT;
		BEGIN
			res := ScmSendControl(Base.DataIn, 82H, 0C0H, 0, 0, buffer^, 0, 1, timeout);
			dataflags := buffer[0];
			RETURN res;
		END ScmReadUserIO;

		PROCEDURE ScmWriteUserIO(enableflags, dataflags: CHAR; timeout : LONGINT) : LONGINT;
		BEGIN
			RETURN ScmSendControl(Base.DataOut, 82H, 40H, ScmShortPack(enableflags, dataflags), 0, Usbdi.NoData, 0, 0, timeout);
		END ScmWriteUserIO;

		PROCEDURE ScmRead(access, reg : CHAR; VAR content: CHAR; timeout : LONGINT) : LONGINT;
		VAR res : LONGINT;
		BEGIN
			res := ScmSendControl(Base.DataIn, ORD(access), 0C0H, ORD(reg), 0, buffer^, 0, 1, timeout);
			content := buffer[0];
			RETURN res;
		END ScmRead;

		PROCEDURE ScmWrite(access, reg, content : CHAR; timeout : LONGINT) : LONGINT;
		BEGIN
			access := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, access) + {0});
			RETURN ScmSendControl(Base.DataOut, ORD(access), 040H, ScmShortPack(reg, content), 0, Usbdi.NoData, 0, 0, timeout);
		END ScmWrite;

		PROCEDURE ScmMultipleWrite(access : CHAR; VAR registers, dataout: ARRAY OF CHAR; numregs,  timeout : LONGINT) : LONGINT;
		VAR res, i, tlen : LONGINT;
		BEGIN
			IF numregs > 7 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmMultipleWrite: Numregs > 7."); KernelLog.Ln;END;
				RETURN Base.ResFatalError;
			END;
			command[0] := 40X;
			command[1] := SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, access)+ {0,1,2}));
			command[2] := 0X;
			command[3] := 0X;
			command[4] := 0X;
			command[5] := 0X;
			command[6] := CHR(numregs*2);
			command[7] := CHR(LSH(numregs*2, -8));

			FOR i:= 0 TO numregs - 1 DO
				buffer[i*2] := registers[i];
				buffer[(i*2)+1] := dataout[i];
			END;

			res := ScmSendControl(Base.DataOut, 80H, 040H, 0, 0, command^, 0, 8, timeout);
			IF res # Base.ResOk THEN RETURN res END;

			res := ScmBulkTransport(Base.DataOut, buffer^, 0, numregs*2, tlen, timeout);
			IF res # Base.ResOk THEN RETURN res END;

			RETURN ScmWaitNotBusy(timeout);
		END ScmMultipleWrite;

		PROCEDURE ScmReadBlock(access, reg : CHAR; VAR content : Usbdi.Buffer; ofs, len: LONGINT; VAR tlen : LONGINT; timeout : LONGINT): LONGINT;
		VAR res : LONGINT;
		BEGIN
			command[0] := 0C0X;
			command[1] := SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, access)+ {1}));
			command[2] := reg;
			command[3] := 0X;
			command[4] := 0X;
			command[5] := 0X;
			command[6] := CHR(len);
			command[7] := CHR(LSH(len, -8));

			tlen := 0;
			res := ScmSendControl(Base.DataOut, 80H, 40H, 0, 0, command^, 0, 8, timeout);
			IF res # Base.ResOk THEN RETURN res END;
			res := ScmBulkTransport(Base.DataIn, content, ofs, len, tlen, timeout);
			RETURN res;
		END ScmReadBlock;

		PROCEDURE ScmWriteBlock(access, reg : CHAR; VAR content : Usbdi.Buffer; ofs, len : LONGINT; VAR tlen : LONGINT; timeout : LONGINT): LONGINT;
		VAR res : LONGINT;
		BEGIN
			command[0] := 40X;
			command[1] := SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, access)+ {0,1}));
			command[2] := reg;
			command[3] := 0X;
			command[4] := 0X;
			command[5] := 0X;
			command[6] := CHR(len);
			command[7] := CHR(LSH(len, -8));

			tlen := 0;
			res := ScmSendControl(Base.DataOut, 80H, 40H, 0, 0, command^, 0, 8, timeout);
			IF res # Base.ResOk THEN RETURN res END;

			res := ScmBulkTransport(Base.DataOut, content, ofs, len, tlen, timeout);
			IF res # Base.ResOk THEN RETURN res END;
			RETURN ScmWaitNotBusy(timeout);
		END ScmWriteBlock;

		PROCEDURE ScmRWBlockTest(access : CHAR; VAR registers, dataout : ARRAY OF CHAR;
			numregs :INTEGER; datareg, statusreg, atapitimeout, qualifier : CHAR; dir : SET; VAR content : Usbdi.Buffer;
			ofs, contentlen: LONGINT; VAR tlen : LONGINT; timeout : LONGINT): LONGINT;
		VAR
			tmpreg : CHAR;
			status : CHAR;
			i, msgindex, msglen : INTEGER;
			tmplen : LONGINT;
			res : LONGINT;
		BEGIN
			IF numregs > 19 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmRWBlockTest too many registers"); KernelLog.Ln; END;
				RETURN Base.ResFatalError;
			END;
			ASSERT(LEN(command)>=16);
			command[0] := 40X;
			command[1] := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET,access) + {0,1,2});
			command[2] := 7X;
			command[3] := 17X;
			command[4] := 0FCX;
			command[5] := 0E7X;
			command[6] := CHR(numregs*2);
			command[7] := CHR(LSH(numregs*2, -8));
			IF dir = Base.DataOut THEN
				command[8] := 40X;
				command[9] := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, access) + {0,2});
			ELSIF dir = Base.DataIn THEN
				command[8] := 0C0X;
				command[9] := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, access) + {2});
			ELSE
				HALT(303)
			END;
			command[10] := datareg;
			command[11] := statusreg;
			command[12] := atapitimeout;
			command[13] := qualifier;
			command[14] := CHR(contentlen);
			command[15] := CHR(LSH(contentlen, -8));

			FOR i:=0 TO numregs -1 DO
				buffer[i*2] := registers[i]; buffer[(i*2)+1] := dataout[i];
			END;

			tlen := 0;

			FOR i := 0 TO 19 DO

				IF i = 0 THEN msgindex := 0; msglen := 16 ELSE msgindex := 8; msglen := 8 END;

				res := ScmSendControl(Base.DataOut, 80H, 40H, 0, 0, command^, msgindex, msglen, 1000);
				IF res # Base.ResOk THEN
					IF (res = Base.ResFatalError) OR (res = Base.ResTimeout) OR (res = Base.ResDisconnected) THEN RETURN res ELSE RETURN Base.ResError END;
				END;

				IF i = 0 THEN
					res := ScmBulkTransport(Base.DataOut, buffer^, 0, numregs*2, tmplen, 1000);
					IF res # Base.ResOk THEN
						IF (res = Base.ResFatalError) OR (res = Base.ResTimeout) OR (res = Base.ResDisconnected)  THEN RETURN res ELSE RETURN Base.ResError END;
					END;
				END;

				res := ScmBulkTransport(dir, content, 0, contentlen, tlen, timeout);
				IF res = Base.ResShortTransfer THEN
					IF (dir = Base.DataIn) & (i=0) THEN (* hm. makes somehow no sense, but that's life *)
						IF ~bulkOutPipe.ClearHalt() THEN
							IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmRWBlockTest clear halt failed"); KernelLog.Ln; END;
						END
					END;

				IF dir = Base.DataOut THEN tmpreg := 17X; ELSE tmpreg := 0EX; END;

				res := ScmRead(ScmATA, tmpreg, status, 1000);
				IF res # Base.ResOk THEN
					IF (res = Base.ResFatalError) OR (res = Base.ResDisconnected) OR (res = Base.ResTimeout)  THEN RETURN res ELSE RETURN Base.ResError END;
					ELSIF (SYSTEM.VAL(SET, status) * {0}) # {} THEN
						IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmRWBlockTest: check condition"); KernelLog.Ln; END;
						RETURN Base.ResError;
					ELSIF (SYSTEM.VAL(SET, status) * {5}) # {} THEN
						IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmRWBlockTest: device fault"); KernelLog.Ln; END;
						RETURN Base.ResFatalError;
					END;
				ELSE
					RETURN ScmWaitNotBusy(timeout);
				END;
			END;
			IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmRWBlockTest failed 20 times!"); KernelLog.Ln; END;
			RETURN Base.ResError;
		END ScmRWBlockTest;

		PROCEDURE ScmSelectAndTestRegisters() : BOOLEAN;
		VAR selector : INTEGER; status : CHAR;
		BEGIN
			FOR selector := 0A0H TO 0B0H BY 10H DO (* actually, test 0A0H and 0B0H *)
				IF ScmWrite(ScmATA, 16X, CHR(selector), 1000) # Base.ResOk THEN RETURN FALSE END;
				IF ScmRead(ScmATA, 17X, status, 1000) # Base.ResOk THEN RETURN FALSE END;
				IF ScmRead(ScmATA, 16X, status, 1000) # Base.ResOk THEN RETURN FALSE END;
				IF ScmRead(ScmATA, 14X, status, 1000) # Base.ResOk THEN RETURN FALSE END;
				IF ScmRead(ScmATA, 15X, status, 1000) # Base.ResOk THEN RETURN FALSE END;
				IF ScmWrite(ScmATA, 14X, 55X, 1000) # Base.ResOk THEN RETURN FALSE END;
				IF ScmWrite(ScmATA, 15X, 0AAX, 1000) # Base.ResOk THEN RETURN FALSE END;
				IF ScmRead(ScmATA, 14X, status, 1000) # Base.ResOk THEN RETURN FALSE END;
				IF ScmRead(ScmATA, 15X, status, 1000) # Base.ResOk THEN RETURN FALSE END;
			END;
			RETURN TRUE;
		END ScmSelectAndTestRegisters;

		PROCEDURE ScmSetShuttleFeatures(externaltrigger, eppcontrol, maskbyte, testpattern, subcountH, subcountL : CHAR) : BOOLEAN;
		BEGIN
			command[0] := 40X;
			command[1] := 81X;
			command[2] := eppcontrol;
			command[3] := externaltrigger;
			command[4] := testpattern;
			command[5] := maskbyte;
			command[6] := subcountL;
			command[7] := subcountH;
			IF ScmSendControl(Base.DataOut, 80H, 40H, 0, 0, command^, 0, 8, 1000) # Base.ResOk THEN
				RETURN FALSE;
			ELSE
				RETURN TRUE;
			END;
		END ScmSetShuttleFeatures;

		PROCEDURE Initialization*() : BOOLEAN;
		VAR status : CHAR; res : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceScInit THEN KernelLog.String("UsbStorage: Initializing SCM USB-ATAPI Shuttle... "); KernelLog.Ln; END;
			res := ScmWriteUserIO(SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, ScmUioOE0) + SYSTEM.VAL(SET, ScmUioOE1))),
				SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, ScmUioEpad) + SYSTEM.VAL(SET, ScmUio1))), 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 1"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			Wait(2000);

			res := ScmReadUserIO(status, 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 2"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			res := ScmReadUserIO(status, 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 3"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			res := ScmWriteUserIO(SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, ScmUioDrvrst) + SYSTEM.VAL(SET, ScmUioOE0)
				+ SYSTEM.VAL(SET, ScmUioOE1))), SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, ScmUioEpad)
				+ SYSTEM.VAL(SET, ScmUio1))), 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 4"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			res := ScmWriteUserIO(SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, ScmUioOE0) + SYSTEM.VAL(SET, ScmUioOE1)),
				 SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, ScmUioEpad) + SYSTEM.VAL(SET, ScmUio1))), 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 5"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			Wait(250);

			res := ScmWrite(ScmISA, 03FX, 080X, 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 6"); KernelLog.Ln; END;
				RETURN FALSE;
			END;
			res := ScmRead(ScmISA, 027X, status, 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 7"); KernelLog.Ln; END;
				RETURN FALSE;
			END;
			res := ScmReadUserIO(status, 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 8"); KernelLog.Ln; END;
				RETURN FALSE;
			END;
			IF ~ScmSelectAndTestRegisters() THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 9"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			res := ScmReadUserIO(status, 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 10"); KernelLog.Ln; END;
				 RETURN FALSE;
			END;

			res := ScmWriteUserIO(SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, ScmUioAckd) + SYSTEM.VAL(SET, ScmUioOE0)
				+ SYSTEM.VAL(SET, ScmUioOE1))), SYSTEM.VAL(CHAR, (SYSTEM.VAL(SET, ScmUioEpad)
				+ SYSTEM.VAL(SET, ScmUio1))), 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 11"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			res := ScmReadUserIO(status, 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 12"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			Wait(1400);

			res := ScmReadUserIO(status, 1000);
			IF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 13"); KernelLog.Ln; END;
				RETURN FALSE;
			END;
			IF ~ScmSelectAndTestRegisters() THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 14"); KernelLog.Ln; END;
				RETURN FALSE;
			END;
			IF ~ScmSetShuttleFeatures(83X, 0X, 88X, 08X, 15X, 14X) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM Init error, step 15"); KernelLog.Ln; END;
				RETURN FALSE;
			END;
			IF  Debug.Trace & Debug.traceScInit THEN KernelLog.String("UsbStorage: Initialization done."); KernelLog.Ln; END;
			RETURN TRUE;
		END Initialization;

		PROCEDURE Transport*(cmd : ARRAY OF CHAR; cmdlen : LONGINT; dir : SET;
			VAR buffer : ARRAY OF CHAR; ofs, bufferlen : LONGINT; VAR tlen : LONGINT; timeout : LONGINT) : LONGINT;
		VAR
			registers, data : ARRAY 32 OF CHAR;
			i, res : LONGINT;
			status : CHAR;
			atapilen, tmplen, sector, transfered : LONGINT;
			j : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceScTransfers THEN
				KernelLog.String("UsbStorage: Transport:");
				KernelLog.String(" Direction: ");
				IF dir = Base.DataIn THEN KernelLog.String("In");
				ELSIF dir = Base.DataOut THEN KernelLog.String("Out");
				ELSE KernelLog.String("Unknown");
				END;
				KernelLog.String(" Bufferlen: "); KernelLog.Int(bufferlen, 0); KernelLog.String(" Offset: "); KernelLog.Int(ofs, 0);
				KernelLog.String(" Cmd: ");
				IF cmdlen = 0 THEN KernelLog.String("None");
				ELSE
					FOR j := 0 TO cmdlen-1 DO KernelLog.Int(ORD(cmd[j]), 0); KernelLog.Char(" "); END;
				END;
				KernelLog.Ln;
			END;
			registers[0] := 11X;
			registers[1] := 12X;
			registers[2] := 13X;
			registers[3] := 14X;
			registers[4] := 15X;
			registers[5] := 16X;
			registers[6] := 17X;

			data[0] := 0X;
			data[1] := 0X;
			data[2] := 0X;
			data[3] := CHR(bufferlen);
			data[4] := CHR(LSH(bufferlen, -8));
			data[5] := 0B0X;
			data[6] := 0A0X;

			FOR i:= 7 TO 18 DO
				registers[i] := 010X;
				IF (i - 7) >= cmdlen THEN data[i] := 0X; ELSE data[i] := cmd[i-7]; END;
			END;

			tlen := 0;

			IF dir = Base.DataOut THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM DataOut not supported!!!"); KernelLog.Ln; END;
				RETURN Base.ResUnsupported;
			END;

			IF bufferlen > 65535 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Too large request for SCM USB-ATAPI Shuttle"); KernelLog.Ln;	END;
				RETURN Base.ResUnsupported;
			END;

			IF cmd[0] = CHR(Base.UfiRead10) THEN
				IF bufferlen < 10000H THEN
					IF Debug.Trace & Debug.traceScTransfers THEN KernelLog.String("UsbStorage: Doing SCM single read"); KernelLog.Ln; END;
					res := ScmRWBlockTest(ScmATA, registers, data, 19, 10X, 17X, 0FDX, 30X, Base.DataIn, buffer, ofs, bufferlen, tlen, timeout);
					RETURN res;
				ELSE
					IF Debug.Trace & Debug.traceScTransfers THEN KernelLog.String("UsbStorage: Doing SCM multi read"); KernelLog.Ln; END;
					tmplen := (65535 DIV sdevs.blockSize) * sdevs.blockSize;
					sector := LSH(ScmShortPack(data[10], data[9]), 16) + ScmShortPack(data[12], data[11]);
					transfered := 0;
					WHILE transfered # bufferlen DO
						IF tmplen > (bufferlen - transfered) THEN tmplen := bufferlen - transfered END;
						data[3] := CHR(tmplen);
						data[4] := CHR(LSH(tmplen, -8));
						data[9] := CHR(LSH(sector, -24));
						data[10] := CHR(LSH(sector, -16));
						data[11] := CHR(LSH(sector, -8));
						data[12] := CHR(sector);
						data[14] := CHR(LSH(tmplen DIV sdevs.blockSize, -8));
						data[15] := CHR(tmplen DIV sdevs.blockSize);
						res := ScmRWBlockTest(ScmATA, registers, data, 19, 10X, 17X, 0FDX, 30X, Base.DataIn, buffer, ofs+transfered, tmplen, atapilen, timeout);
						transfered := transfered + atapilen; tlen := transfered;
						sector := sector + (tmplen DIV sdevs.blockSize);
						IF res # Base.ResOk THEN RETURN res END;
					END;
					RETURN Base.ResOk;
				END;
			END;

			IF Debug.Trace & Debug.traceScTransfers THEN KernelLog.String("UsbStorage: Sending SCM registers"); KernelLog.Ln; END;
			res := ScmMultipleWrite(ScmATA, registers, data, 7, 1000);
			IF (res = Base.ResDisconnected) THEN
				RETURN res;
			ELSIF (res # Base.ResOk) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM register setup failed"); KernelLog.Ln; END;
				RETURN Base.ResError
			END;

			IF cmdlen # 12 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM command len # 12"); KernelLog.Ln; END;
				RETURN Base.ResFatalError;
			END;

			IF Debug.Trace & Debug.traceScTransfers THEN KernelLog.String("UsbStorage: Sending SCM command"); KernelLog.Ln; END;

			res := ScmWriteBlock(ScmATA, 10X, cmd, 0, 12, tmplen, timeout);
			IF (res = Base.ResDisconnected) THEN
				RETURN res;
			ELSIF res # Base.ResOk THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: SCM command transfer failed"); KernelLog.Ln; END;
				RETURN Base.ResError
			END;

			IF (bufferlen # 0) & (dir = Base.DataIn) THEN
				IF Debug.Trace & Debug.traceScTransfers THEN KernelLog.String("UsbStorage: SCM  data transfer"); KernelLog.Ln; END;
				res := ScmRead(ScmATA, 014X, status, 1000);
				IF (res = Base.ResDisconnected) THEN
					RETURN res;
				ELSIF res # Base.ResOk THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmRead failed"); KernelLog.Ln; END;
					RETURN Base.ResError
				END;
				atapilen := ORD(status);
				IF bufferlen > 255 THEN
					res := ScmRead(ScmATA, 015X, status, 1000);
					IF (res = Base.ResDisconnected) THEN
						RETURN res;
					ELSIF res # Base.ResOk THEN
						IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmRead2 failed"); KernelLog.Ln; END;
						RETURN res;
					END;
					atapilen := atapilen + (ORD(status) * 256);
				END;
				IF Debug.Trace & Debug.traceScTransfers THEN
					KernelLog.String("UsbStorage: Scm Transfer: Want: "); KernelLog.Int(bufferlen, 0);
					KernelLog.String(" / have: "); KernelLog.Int(atapilen, 0); KernelLog.Ln;
				END;
				tmplen := atapilen;
				IF atapilen < bufferlen THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Scm has FEWER bytes in the atapi buffer"); KernelLog.Ln; END;
				ELSIF atapilen > bufferlen THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: Scm has MORE bytes in the atapi buffer"); KernelLog.Ln; END;
					tmplen := bufferlen;
				END;

				res := ScmReadBlock(ScmATA, 10X, buffer, ofs, tmplen, tlen, timeout);
				IF Debug.Trace & Debug.traceScTransfers THEN
					IF (res = Base.ResOk) OR (res = Base.ResShortTransfer) THEN
						KernelLog.String("UsbStorage: wanted: "); KernelLog.Int(tmplen, 0);
						KernelLog.String(" / got: "); KernelLog.Int(tlen, 0); KernelLog.Ln;
					END;
				END;
				IF (res = Base.ResOk) & (atapilen < bufferlen) THEN res := Base.ResShortTransfer END;
				IF (res # Base.ResOk) & (res # Base.ResShortTransfer) THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbStorage: ScmReadBlock failed"); KernelLog.Ln; END;
					RETURN res;
				END;
			ELSE
				tlen := 0;
			END;

			RETURN Base.ResOk;
		END Transport;

		PROCEDURE Wait(ms : LONGINT);
		BEGIN
			timer.Sleep(ms);
		END Wait;

		PROCEDURE &Init*;
		BEGIN
			Init^; NEW(command, 16); NEW(buffer, 64); NEW(timer);
		END Init;

	END SCMTransport;

END UsbStorageScm.
