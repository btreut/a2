MODULE DiskTests; (** AUTHOR "staubesv"; PURPOSE "Simple block device tests"; *)
(**
 * Usage:
 *
 *	DiskTests.WriteTestData dev#part ~ fills the specified partition with test data
 *	DiskTests.VerifyTestData dev#part ~ checks whether the test data can be correctly read
 *	DiskTests.WriteZeros dev#part ~ fills the specifed partition with zeros
 *	DiskTests.Test dev#part ~ tests the specified partition
 *	DiskTests.TransferBlocks dev#part "READ"|"WRITE" block numblocks ~  (TUI only)
 *
 *	WMPartitions.Open ~ opens the graphical front-end
 *
 * History:
 *
 *	28.02.2006	First release (staubesv)
 *)

IMPORT
	Streams, Random, Kernel, Commands, Disks, Partitions, Lib := PartitionsLib, Strings;

TYPE

	TestDataBase = OBJECT(Lib.Operation);
	VAR
		buffer : POINTER TO ARRAY OF CHAR;
		sectorsPerTransfer : LONGINT;

		PROCEDURE SetParameters*(sectorsPerTransfer : LONGINT);
		BEGIN
			SELF.sectorsPerTransfer := sectorsPerTransfer;
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF sectorsPerTransfer < 1 THEN ReportError("SectorsPerTransfer must be >= 1"); RETURN FALSE; END;
			IF disk.device.blockSize MOD 256 # 0 THEN ReportError("Device blocksize MOD 256 MUST BE 0"); RETURN FALSE; END;
			RETURN TRUE;
		END ValidParameters;

	END TestDataBase;

TYPE

	(** Fills partition with test data *)
	TestDataWriter* = OBJECT(TestDataBase);

		PROCEDURE FillWithTestData(VAR buffer : ARRAY OF CHAR);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(buffer) - 1 DO buffer[i] := CHR(i MOD 256); END;
		END FillWithTestData;

		PROCEDURE DoOperation*;
		VAR pos, num, nbrOfBlocks, blocksWritten, res : LONGINT; temp : ARRAY 256 OF CHAR;
		BEGIN
			SetStatus(state.status, "Writing test data...", 0, 0, disk.table[partition].size, TRUE);
			NEW(buffer, disk.device.blockSize * sectorsPerTransfer);
			FillWithTestData(buffer^);
			pos := disk.table[partition].start; num := sectorsPerTransfer; nbrOfBlocks := disk.table[partition].size;
			LOOP
				IF num > nbrOfBlocks - blocksWritten THEN num := nbrOfBlocks - blocksWritten; END;
				IF ~alive OR (num = 0) THEN EXIT; END;
				disk.device.Transfer(Disks.Write, pos, num, buffer^, 0, res);
				IF res # Disks.Ok THEN Lib.GetTransferError(disk.device, Disks.Write, pos, res, temp); ReportError(temp); END;
				INC(pos, num); INC(blocksWritten, num);
				SetCurrentProgress(blocksWritten);
			END;
			IF alive THEN
				result.String("Test data written to partition "); result.String(diskpartString);
			ELSE
				result.String("Operation aborted");
			END;
		END DoOperation;

		PROCEDURE &Init*(disk :Lib.Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "WriteTestData"; desc := "Write test data to partition"; locktype := Lib.WriterLock;
		END Init;

	END TestDataWriter;

TYPE

	(** Checks whether the test data written by the WriteTestData object can be read back correctly *)
	TestDataChecker* = OBJECT(TestDataBase);

		PROCEDURE DoOperation*;
		VAR
			pos, num, nbrOfBlocks, blocksRead, res : LONGINT; string, nbr : ARRAY 128 OF CHAR;
			expected, found, foundAt : LONGINT;
		BEGIN
			SetStatus(state.status, "Verifying test data...", 0, 0, disk.table[partition].size, TRUE);
			NEW(buffer, disk.device.blockSize * sectorsPerTransfer);
			pos := disk.table[partition].start; num := sectorsPerTransfer; nbrOfBlocks := disk.table[partition].size;
			LOOP
				IF num > nbrOfBlocks - blocksRead THEN num := nbrOfBlocks - blocksRead; END;
				IF ~alive OR (num = 0) THEN EXIT; END;
				disk.device.Transfer(Disks.Read, pos, num, buffer^, 0, res);
				IF res # Disks.Ok THEN
					Lib.GetTransferError(disk.device, Disks.Read, pos, res, string); ReportError(string);
				ELSIF ~TestDataIsCorrect(0, num, disk.device.blockSize, buffer^, expected, found, foundAt) THEN
					string := "Verification of block at pos "; Strings.IntToStr(pos, nbr); Strings.Append(string, nbr);
					Strings.Append(string, ", Expected value: "); Strings.IntToStr(expected, nbr); Strings.Append(string, nbr);
					Strings.Append(string, ", found: "); Strings.IntToStr(found, nbr); Strings.Append(string, nbr);
					Strings.Append(string, " at index: "); Strings.IntToStr(foundAt, nbr); Strings.Append(string, nbr);
					ReportError(string);
				END;
				INC(pos, num); INC(blocksRead, num);
				SetCurrentProgress(blocksRead);
			END;
			IF alive THEN
				result.String("Test data verified on partition "); result.String(diskpartString); result.String(" - ");
				IF state.errorCount = 0 THEN result.String("No "); END;
				result.String("Errors found.");
			END;
		END DoOperation;

		PROCEDURE &Init*(disk :Lib.Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "CheckTestData"; desc := "Verify test data on partition"; locktype := Lib.ReaderLock;
		END Init;

	END TestDataChecker;

TYPE

	ZeroWriter* = OBJECT(TestDataWriter);

		PROCEDURE FillWithTestData*(VAR buffer : ARRAY OF CHAR);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(buffer) - 1 DO buffer[i] := 0X; END;
		END FillWithTestData;

		PROCEDURE & Init*(disk : Lib.Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "ZeroWriter"; desc := "Fill with zeros partition"; locktype := Lib.WriterLock;
		END Init;

	END ZeroWriter;

TYPE

	(**
	 * Test a partition
	 *)
	DiskTest* = OBJECT(Lib.Operation)
	VAR
		(* parameters *)
		doRead, doWrite, testData : BOOLEAN;
		nbrOfTests, maxNbrOfSectors, maxOffset : LONGINT;

		start, size : LONGINT; (* First block of partition and size of the partition *)
		offset : LONGINT; (* currently used offset into client buffer *)

		(* Coverage information *)
		testCount : LONGINT;
		testedOffsets : POINTER TO ARRAY OF BOOLEAN;
		testedSectors : POINTER TO ARRAY OF BOOLEAN;
		blocksRead : HUGEINT;

		buffer : POINTER TO ARRAY OF CHAR;
		random : Random.Generator;

		PROCEDURE SetParameters*(doRead, doWrite,  testData : BOOLEAN; nbrOfTests, maxNbrOfSectors, maxOffset : LONGINT);
		BEGIN
			SELF.doRead := doRead; SELF.doWrite := doWrite; SELF.testData := testData;
			SELF.nbrOfTests := nbrOfTests; SELF.maxNbrOfSectors := maxNbrOfSectors; SELF.maxOffset := maxOffset;
		END SetParameters;

		PROCEDURE ValidParameters*() : BOOLEAN;
		BEGIN
			IF ~doRead & ~doWrite THEN ReportError("Either read or write tests must be done"); RETURN FALSE; END;
			IF maxNbrOfSectors < 1 THEN ReportError("MaxNbrOfSectors must be >= 1"); RETURN FALSE; END;
			IF maxOffset < 0 THEN ReportError("MaxOffset must be >= 0"); RETURN FALSE; END;
			RETURN TRUE;
		END ValidParameters;

		PROCEDURE WriteTestSettings;
		BEGIN
			info.String("Test Settings:"); info.Ln;
			info.String("   Number of Tests: "); IF nbrOfTests > 0 THEN info.Int(nbrOfTests, 0); ELSE info.String("Endless Loop Mode"); END; info.Ln;
			info.String("   Read Tests: "); IF doRead THEN info.String("Yes"); ELSE info.String("No"); END; info.Ln;
			info.String("   Write Tests: "); IF doWrite THEN info.String("Yes"); ELSE info.String("No"); END; info.Ln;
			info.String("   Verify Reads using Test Data: "); IF testData THEN info.String("Yes"); ELSE info.String("No"); END; info.Ln;
			info.String("   Max. Sectors per Transfer: "); info.Int(maxNbrOfSectors, 0); info.Ln;
			info.String("   Max. Offset into Client Buffer: "); info.Int(maxOffset, 0); info.Ln;
			info.Ln;
		END WriteTestSettings;

		PROCEDURE WriteSummary;
		VAR i, val : LONGINT;

			PROCEDURE WriteB(b: HUGEINT; w : Streams.Writer);
			VAR suffix: ARRAY 3 OF CHAR;
			BEGIN
				IF b > 1024*1024*1024 THEN suffix := "GB"; b := b DIV (1024*1024*1024);
				ELSIF b > 1024*1024 THEN suffix := "MB"; b := b DIV (1024*1024);
				ELSIF b > 1024 THEN suffix := "KB"; b := b DIV 1024;
				ELSE suffix := "B";
				END;
				w.Int(SHORT(b), 0); w.String(suffix);
			END WriteB;

		BEGIN
			info.String("Test Summary:"); info.Ln;
			info.String("   "); info.Int(testCount, 0); info.String(" Test Runs done"); info.Ln;
			IF testedOffsets # NIL THEN
				val := 0; FOR i := 0 TO LEN(testedOffsets)-1 DO IF testedOffsets[i] THEN INC(val); END; END;
				info.String("   Offset Coverage: "); info.FloatFix(100.0 * val / LEN(testedOffsets), 5, 2, 0); info.Char("%"); info.Ln;
			END;
			IF testedSectors # NIL THEN
				val := 0; FOR i := 0 TO LEN(testedSectors)-1 DO IF testedSectors[i] THEN INC(val); END; END;
				info.String("   Transfer Sizes Coverage: "); info.FloatFix(100.0 * val / LEN(testedSectors), 5, 2, 0); info.Char("%"); info.Ln;
			END;
			info.String("   Total amount of data read: "); WriteB(blocksRead * disk.device.blockSize, info); info.Ln;
		END WriteSummary;

		PROCEDURE PerformStep;
		VAR pos, num, res, expected, found, foundAt : LONGINT; string, nbr : ARRAY 128 OF CHAR;
		BEGIN
			num := random.Dice(maxNbrOfSectors) + 1;
			IF maxNbrOfSectors > 1 THEN testedSectors[num - 1] := TRUE; END;
			pos := start + random.Dice(size - num);
			disk.device.Transfer(Disks.Read, pos, num, buffer^, offset, res);
			IF res # Disks.Ok THEN
				Lib.GetTransferError(disk.device, Disks.Write, pos, res, string); ReportError(string);
			ELSE
				INC (blocksRead, num);
				IF  testData & ~TestDataIsCorrect(offset, num, disk.device.blockSize, buffer^, expected, found, foundAt) THEN
					string := "Data Verification failed (Pos: "; Strings.IntToStr(pos, nbr); Strings.Append(string, nbr);
					Strings.Append(string, ", Num: "); Strings.IntToStr(num, nbr); Strings.Append(string, nbr);
					Strings.Append(string, ", Offset: "); Strings.IntToStr(offset, nbr); Strings.Append(string, nbr);
					Strings.Append(string, ": ");
					Strings.Append(string, "Expected value: "); Strings.IntToStr(expected, nbr); Strings.Append(string, nbr);
					Strings.Append(string, ", found value: "); Strings.IntToStr(found, nbr); Strings.Append(string, nbr);
					Strings.Append(string, " at index: "); Strings.IntToStr(foundAt, nbr); Strings.Append(string, nbr);
					Strings.Append(string, ")");
					ReportError(string);
				END;
			END;
		END PerformStep;

		PROCEDURE DoOperation*;
		BEGIN
			start := disk.table[partition].start; size := disk.table[partition].size;
			NEW(buffer, maxNbrOfSectors * disk.device.blockSize + maxOffset);
			WriteTestSettings;
			IF nbrOfTests > 0 THEN SetStatus(state.status, "Testing...", 0, 0, nbrOfTests, TRUE);
			ELSE SetStatus(state.status, "Testing (loop mode)...", 0, 0, 0, FALSE);
			END;
			IF maxOffset > 0 THEN NEW(testedOffsets, maxOffset + 1); END;
			IF maxNbrOfSectors > 1 THEN NEW(testedSectors, maxNbrOfSectors); END;
			testCount := 0; offset := 0;
			LOOP
				IF ~alive THEN EXIT END;
				IF nbrOfTests > 0 THEN
					SetCurrentProgress(testCount);
					IF testCount >= nbrOfTests THEN EXIT; END;
				END;
				PerformStep;
				IF maxOffset > 0 THEN testedOffsets[offset] := TRUE; offset := (offset + 1) MOD (maxOffset + 1); END;
				INC(testCount);
			END;
			WriteSummary;
			IF alive THEN
				result.String("Finished testing partition "); result.String(diskpartString); result.String(" - ");
				IF state.errorCount = 0 THEN result.String("No "); END;
				result.String("Errors found");
			END;
		END DoOperation;

		PROCEDURE &Init*(disk :Lib.Disk; partition : LONGINT; out : Streams.Writer);
		BEGIN
			Init^(disk, partition, out);
			name := "DiskTester"; desc := "Perform disk test on partition"; locktype := Lib.ReaderLock;
			NEW(random); random.InitSeed(Kernel.GetTicks());
		END Init;

	END DiskTest;

PROCEDURE TestDataIsCorrect*(offset, numblocks, blocksize : LONGINT; CONST buffer : ARRAY OF CHAR; VAR expected, found, foundAt : LONGINT) : BOOLEAN;
VAR i : LONGINT;
BEGIN
	ASSERT(LEN(buffer) >= numblocks * blocksize + offset);
	ASSERT(blocksize MOD 256 = 0); (* Otherwise test data used will not work *)
	FOR i := 0 TO numblocks * blocksize - 1 DO
		IF ORD(buffer[i + offset]) # i MOD 256 THEN
			expected := i MOD 256; found := ORD(buffer[i + offset]); foundAt := i;
			RETURN FALSE;
		END;
	END;
	RETURN TRUE;
END TestDataIsCorrect;

(** Fill partition with test data *)
PROCEDURE WriteTestData*(context : Commands.Context); (** dev#part ~ *)
VAR selection : Lib.Selection; testDataWriter : TestDataWriter;
BEGIN
	IF Partitions.GetSelection(context, FALSE, selection) THEN
		NEW(testDataWriter, selection.disk, selection.partition, context.out);
		testDataWriter.SetParameters(1);
		testDataWriter.SetStart;
	ELSE (* skip; error written to <w> by ScanOpenPart *)
	END;
END WriteTestData;

(** Fill partition with test data *)
PROCEDURE VerifyTestData*(context : Commands.Context); (** dev#part ~ *)
VAR selection : Lib.Selection; testDataChecker : TestDataChecker;
BEGIN
	IF Partitions.GetSelection(context, FALSE, selection) THEN
		NEW(testDataChecker, selection.disk, selection.partition, context.out);
		testDataChecker.SetParameters(1);
		testDataChecker.SetStart;
	ELSE (* skip; error written to <w> by ScanOpenPart *)
	END;
END VerifyTestData;

(** Fill partition with zeros *)
PROCEDURE WriteZeros*(context : Commands.Context); (** dev#part ~ *)
VAR selection : Lib.Selection;  zeroWriter : ZeroWriter;
BEGIN
	IF Partitions.GetSelection(context, FALSE, selection) THEN
		NEW(zeroWriter, selection.disk, selection.partition, context.out);
		zeroWriter.SetParameters(1);
		zeroWriter.SetStart;
	ELSE (* skip; error written to <w> by ScanOpenPart *)
	END;
END WriteZeros;

(** Test the specified partition *)
PROCEDURE Test*(context : Commands.Context); (** dev#part ~ *)
VAR selection : Lib.Selection; diskTest : DiskTest;
BEGIN
	IF Partitions.GetSelection(context, FALSE, selection) THEN
		NEW(diskTest, selection.disk, selection.partition, context.out);
		diskTest.SetParameters(TRUE, FALSE, FALSE, 100, 100, 0);
		diskTest.SetStart;
	ELSE (* skip; error written to <w> by ScanOpenPart *)
	END;
END Test;

(** Read/write the specified number of sectors from/to the specified paritition starting at the specified sector *)
PROCEDURE TransferBlocks*(context : Commands.Context); (** dev#part "READ"|"WRITE" block numblocks ~ *)
VAR
	selection : Lib.Selection;
	string : ARRAY 32 OF CHAR; dev : Disks.Device;
	op, block, numblocks, res : LONGINT;
	buffer : POINTER TO ARRAY OF CHAR;
BEGIN
	IF Partitions.GetSelection(context, FALSE, selection) THEN
		context.arg.SkipWhitespace; context.arg.String(string);
		IF string = "READ" THEN op := Disks.Read;
		ELSIF string = "WRITE" THEN op := Disks.Write;
		ELSE context.error.String("DiskTests: Expected READ|WRITE parameter."); context.error.Ln; RETURN;
		END;

		IF ~context.arg.GetInteger(block, FALSE) OR (block < 0) THEN context.error.String("DiskTests: Expected block parameter."); context.error.Ln; RETURN; END;

		IF ~context.arg.GetInteger(numblocks, FALSE) OR (block < 0) THEN context.error.String("DiskTests: Expected numblocks parameter."); context.error.Ln; RETURN; END;

		dev := selection.disk.device;
		context.out.String("DiskTests: ");
		IF op = Disks.Read THEN context.out.String("Reading "); ELSE context.out.String(" Writing "); END;
		context.out.Int(numblocks, 0); context.out.String(" blocks at offset "); context.out.Int(block, 0);
		IF op = Disks.Read THEN context.out.String(" from "); ELSE context.out.String(" to "); END;
		context.out.String(" partition "); context.out.String(dev.name); context.out.String("#"); context.out.Int(selection.partition, 0);
		context.out.String("... "); context.out.Update;
		dev.Open(res);
		IF res = Disks.Ok THEN
			IF dev.table[selection.partition].size - block < numblocks THEN
				context.error.String("DiskTests: Numblocks too big. Would cross partition. Aborting test."); context.error.Ln;
			ELSE
				NEW(buffer, numblocks * dev.blockSize);
				dev.Transfer(op, block, numblocks, buffer^, 0, res);
				ShowDiskres(res, context.out); context.error.Ln;
			END;
			dev.Close(res); (* ignore res *)
		ELSE
			context.error.String("DiskTests: Could not open device "); context.error.String(dev.name);
			context.error.String(": "); ShowDiskres(res, context.out); context.error.Ln;
		END;
	ELSE context.error.String("DiskTests: TransferBlocks: Device not found."); context.error.Ln;
	END;
END TransferBlocks;

PROCEDURE ShowDiskres(res : LONGINT; out : Streams.Writer);
BEGIN
	IF res = Disks.Ok THEN out.String("Ok");
	ELSIF res = Disks.MediaChanged THEN out.String("MediaChanged");
	ELSIF res = Disks.WriteProtected THEN out.String("WriteProtected");
	ELSIF res = Disks.Unsupported THEN out.String("Unsupported");
	ELSIF res = Disks.DeviceInUse THEN out.String("DeviceInUse");
	ELSIF res = Disks.MediaMissing THEN out.String("MediaMissing");
	ELSE out.String("Unknown (res: "); out.Int(res, 0); out.String(")");
	END;
END ShowDiskres;

END DiskTests.

DiskTests.WriteTestData USB0#1 ~  SystemTools.Free DiskTests ~
DiskTests.VerifyTestData USB0#1 ~

DiskTests.Test USB0#1 ~

DiskTests.TransferBlocks USB0#1 READ 0 6 ~

UsbInfo.TraceOn Custom~

UsbInfo.TraceNone ~

Partitions.ShowOps ~
Partitions.ShowOps detail ~

Partitions.Abort 1 ~
