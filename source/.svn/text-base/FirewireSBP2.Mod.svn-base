MODULE FirewireSBP2;

IMPORT SYSTEM, Strings, Modules, KernelLog, FirewireLow, FirewireLowUtil, Disks, Kernel,Plugins, Objects;

CONST
	(* scsi status *)
	good= 0;
	checkCondition= 2;
	conditionMet= 4;
	busy= 8;
	reservationConflict= 18H;
	commandTerminated= 22H;

	NumOfOrbs= 10; (* how muchs orbs have to allocated in advance *)
	OrbSize= 32;
	NumOfBufs= 10; (* how much buffers have to be allocated in advance *)
	(* DataBufferSize= 1024; *)
	(* This address belongs to a region specified for write postings and the ohci controller will automatically send an ack
		when the status is written *)
	SBP2StatusFifoAddressHi= 0FFFEH;
	SBP2StatusFifoAddressLo= 0H;

	SBP2CSROffsetKey= 54H;
	SBP2UnitSpecIDKey= 12H;
	SBP2UnitSWVersionKey= 13H;
	SBP2CommandSetSpecIDKey= 38H;
	SBP2CommandSetKey= 39H;
	SBP2UnitCharKey= 3AH;
	SBP2DeviceTypeAndLUNKey= 14H;
	SBP2FirmwareRevKey= 3CH;
	SBP2BusyTimeOutAddrHi= 0FFFFH;
	SBP2BusyTimeOutAddrLo= LONGINT(0F0000210H);
	SBP2AgentResetData= 0FH;

	SBP2AgentStateOffset= 0H;
	SBP2AgentResetOffset= 4H;
	SBP2ORBPointerOffset= 8H;
	SBP2DoorbellOffset= 10H;
	SBP2UnsolStatusEnableOffset= 14H;
	SBP2UnsolicitedStatusValue= 0FH;

	LoginRequest= 0H;
	QueryLoginsRequest= 1H;
	ReconnectRequest= 3H;
	SetPasswordRequest= 4H;
	LogoutRequest= 7H;
	AbortTastRequest= 0BH;
	AbortTaskSet= 0CH;
	LogicalUnitReset= 0EH;
	TargetResetRequest= 0FH;

	UninitializedLUN= LONGINT(0FFFFFFFFH);

	BusyTimeOut = 0FH;

	NullPointerOrbHi= {31};

	NoDataTransfer= 3;
	DataWrite= 1;
	DataRead= 2;
	DataDirUnknown= 0;
	OrbDirWriteToMedia= 0H;
	OrbDirReadFromMedia= 1H;
	OrbDirNoDataTransfer = 2H;

TYPE
	Address= RECORD
	value: LONGINT;
	next: POINTER TO Address;
	END;

	Buffer= POINTER TO ARRAY OF CHAR;

	Command= RECORD
		bufferLen: LONGINT;
		dataDirection: LONGINT;
		bufferAddr: SET;
		ptrToBfr: Buffer;
		cdb: ARRAY 12 OF CHAR; (* scsi command or sthg else *)
	END;

	Node= POINTER TO NodeDesc;

	NodeDesc= RECORD
		bufAddr: LONGINT;
		ptrToBfr: Buffer;
		next: Node;
	END;

	FIFO = RECORD
		first, last: Node
	END;

	FIFOList= OBJECT

		PROCEDURE Enqueue(VAR q: FIFO; n: Node);
		BEGIN
			n.next:= NIL;
			IF q.first # NIL THEN q.last.next := n ELSE q.first := n END;
			q.last := n;
		END Enqueue;

		PROCEDURE DequeuedNode(VAR q: FIFO): Node;
		VAR n: Node;
		BEGIN
			n := q.first;
			IF n # NIL THEN q.first := n.next END;
			RETURN n
		END DequeuedNode;

	END FIFOList;

	BufferFIFO= OBJECT
	VAR q: FIFO; list: FIFOList; usedQ: FIFO; usedList: FIFOList; bufSize: LONGINT;
		owner : ANY;

		PROCEDURE GetBuffer(VAR ptrToBfr: Buffer):LONGINT;
		VAR n:Node;
		BEGIN {EXCLUSIVE}
			n:=list.DequeuedNode(q); (* Print(debug,"Dequeuning node"); *)
			IF n =  NIL THEN (* Print(debug,"Allocating new buffer!"); *)
				NEW(n); n.bufAddr:= SYSTEM.VAL(LONGINT,AllocBuf(bufSize,n.ptrToBfr))
			END;
			usedList.Enqueue(usedQ,n);
			(* Print(debug,"Returning address!");
			KernelLog.Int(n.bufAddr,2); *)
			ASSERT(n.bufAddr > 0);
			ptrToBfr:= n.ptrToBfr;
			RETURN n.bufAddr;
		END GetBuffer;

		PROCEDURE ReleaseBuffer(ptrToBfr: Buffer; bufAddr: LONGINT);
		VAR n: Node;
		BEGIN {EXCLUSIVE}
		ASSERT(bufAddr > 0);
			n:= usedList.DequeuedNode(usedQ);
			(* Be aware that n.bufAddr, will not necessarily point to the same buffer as n.ptrToBfr *)
			n.bufAddr:= bufAddr;
			n.ptrToBfr:= ptrToBfr;
			ASSERT(n.bufAddr > 0);
			list.Enqueue(q,n);
		END ReleaseBuffer;

		PROCEDURE &Init*(numOfBuf,bufSize: LONGINT);
		VAR n: Node;i: LONGINT;
		BEGIN {EXCLUSIVE}
			NEW(list); NEW(usedList); SELF.bufSize:= bufSize;
			IF numOfBuf > 0 THEN
				FOR i:= 0 TO numOfBuf-1 DO
					NEW(n);
					n.bufAddr:= SYSTEM.VAL(LONGINT,AllocBuf(bufSize,n.ptrToBfr));
					list.Enqueue(q,n)
				END
			END
		END Init;

	END BufferFIFO;

	(** The SBP2 fireWire device *)
	Sbp2Dev= OBJECT(Disks.Device)
	VAR
		DataBufferSize: LONGINT;
		id*: LONGINT;
		speedCode*: LONGINT;
		mgmtAgntAddrLow*: SET;
		mgmtAgntAddrHigh*: SET;
		cmdBlckAgntAddrLow*: SET;
		cmdBlckAgntAddrHigh*: SET;

		lastOrb: Sbp2CommandOrb;
		loginOrb: Sbp2LoginOrb;
		loginResp: Sbp2LoginResponse;
		queryLogins: Sbp2QueryLoginsOrb;
		queryLoginsResp: Sbp2QueryLoginsResp;
		reconnectOrb: Sbp2ReconnectOrb;
		logoutOrb: Sbp2LogoutOrb;
		statusBlock: Sbp2StatusBlock;

		maxPayload*: LONGINT;

		commandSetSpecID*: LONGINT;
		commandSet*: LONGINT;
		unitChar*: SET;
		logicalUnitNumber*: SET;
		firmwareRev*: LONGINT;

		loginComplete*: BOOLEAN;

		nodeEntry*: FirewireLowUtil.Node;
		commandOrbFIFO*: BufferFIFO;
		dataBufferFIFO*: BufferFIFO;

		t: Kernel.Timer;

		PROCEDURE Config;
		VAR size, diskres,payloadNotCoded: LONGINT;
		BEGIN
			payloadNotCoded:= SYSTEM.VAL(LONGINT,LSH({0},maxPayload+1));
			NEW(dataBufferFIFO,10,payloadNotCoded);
			NEW(commandOrbFIFO,NumOfOrbs,OrbSize);
			GetSize(size,diskres);
			DataBufferSize:= blockSize;
		END Config;

PROCEDURE CreateCommandOrb(VAR commandOrb: Sbp2CommandOrb; VAR command: Command);
VAR dataBufAddr,addr,direction,i,numOfOrbs,payloadNotCoded: LONGINT;
BEGIN
	commandOrb.nextOrbHi:= NullPointerOrbHi;
	commandOrb.nextOrbLo:= {};
	(* set the max payload *)
	commandOrb.misc:= LSH(SYSTEM.VAL(SET,maxPayload),20);
	(* set the speed *)
	commandOrb.misc:= commandOrb.misc + LSH(SYSTEM.VAL(SET,speedCode),24);
	(* set the notify speed *)
	commandOrb.misc:= commandOrb.misc + {31};
	(* set the page size *)
	commandOrb.misc:= commandOrb.misc + {17};

	dataBufAddr:= dataBufferFIFO.GetBuffer(commandOrb.ptrToDataBfr);
	host.adrCheck.Add(dataBufAddr);
	ASSERT(dataBufAddr > 0);
	(* Print(debug,"Printing the data buffer address");
	KernelLog.Int(dataBufAddr,2); *)

	CASE command.dataDirection OF
		NoDataTransfer: direction:= OrbDirNoDataTransfer;
		|DataWrite: direction:= OrbDirWriteToMedia;
		|DataRead: direction:= OrbDirReadFromMedia;
	ELSE direction:= OrbDirNoDataTransfer; Print(debug,"Data direction is unknown");
	END;

	IF direction = OrbDirNoDataTransfer THEN
		Print(debug,"No data transfer!::CrateCommandOrb");
		 commandOrb.dataDescHi:= {}; commandOrb.dataDescLo:= {};
		commandOrb.misc:= commandOrb.misc + {27};
	ELSE
		(* set the direction *)
		commandOrb.misc:= commandOrb.misc + SYSTEM.VAL(SET,LSH(direction,27));
		(* check how big the buffer has to be *)
		(* KernelLog.Int(maxPayload,2);KernelLog.Ln(); *)
		payloadNotCoded:= SYSTEM.VAL(LONGINT,LSH({0},maxPayload+1));
		(* KernelLog.Int(payloadNotCoded,2); *)
		numOfOrbs:= command.bufferLen DIV payloadNotCoded;

		ASSERT(numOfOrbs <= 1);

		(* set the data size *)
		commandOrb.misc:= commandOrb.misc + SYSTEM.VAL(SET,command.bufferLen);
		(* set the buffer address *)
		commandOrb.dataDescHi:= LSH(FirewireLowUtil.ReadReg(FirewireLowUtil.NodeID)*{0..15},16);
		commandOrb.dataDescLo:= SYSTEM.VAL(SET,dataBufAddr);
		ASSERT(~(31 IN commandOrb.dataDescLo));
		FOR i:= 0 TO 11 DO
			commandOrb.cdb[i]:= command.cdb[i];
		END;
		(* copy the data into a buffer *)
		ASSERT( dataBufAddr > 0);
		IF direction = OrbDirWriteToMedia THEN
			ASSERT((command.bufferLen MOD 4) = 0);
			ASSERT(command.bufferLen <= 1024);
			FOR i:= 0 TO (command.bufferLen DIV 4)-1 DO
				SYSTEM.PUT32(dataBufAddr+i*4,SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)+i*4));
			END;
		ELSE command.bufferAddr:= SYSTEM.VAL(SET,dataBufAddr)
		END;

		(* Now copy the  commandOrb into a buffer *)
		commandOrb.bufAddr:= SYSTEM.VAL(SET,commandOrbFIFO.GetBuffer(commandOrb.ptrToBfr));
		addr:= SYSTEM.VAL(LONGINT,commandOrb.bufAddr);
		ASSERT(addr > 0);
		SYSTEM.PUT32(addr,SYSTEM.VAL(LONGINT,commandOrb.nextOrbHi));
		SYSTEM.PUT32(addr+4,SYSTEM.VAL(LONGINT,commandOrb.nextOrbLo));
		SYSTEM.PUT32(addr+8,SYSTEM.VAL(LONGINT,commandOrb.dataDescHi));
		SYSTEM.PUT32(addr+12,SYSTEM.VAL(LONGINT,commandOrb.dataDescLo));
		SYSTEM.PUT32(addr+16,SYSTEM.VAL(LONGINT,commandOrb.misc));



		(* byte swap the command orb *)
		InvertByteOrder(addr,32);

		SYSTEM.PUT8(addr+20,commandOrb.cdb[0]);
		SYSTEM.PUT8(addr+21,commandOrb.cdb[1]);
		SYSTEM.PUT8(addr+22,commandOrb.cdb[2]);
		SYSTEM.PUT8(addr+23,commandOrb.cdb[3]);
		(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+20))); *)
		SYSTEM.PUT8(addr+24,commandOrb.cdb[4]);
		SYSTEM.PUT8(addr+25,commandOrb.cdb[5]);
		SYSTEM.PUT8(addr+26,commandOrb.cdb[6]);
		SYSTEM.PUT8(addr+27,commandOrb.cdb[7]);
		(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+24))); *)
		SYSTEM.PUT8(addr+28,commandOrb.cdb[8]);
		SYSTEM.PUT8(addr+29,commandOrb.cdb[9]);
		SYSTEM.PUT8(addr+30,commandOrb.cdb[10]);
		SYSTEM.PUT8(addr+31,commandOrb.cdb[11]);
		(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+28))); *)
	END
END CreateCommandOrb;

PROCEDURE LinkCommandOrb(commandOrb: Sbp2CommandOrb;VAR diskres: LONGINT);
VAR buffer: ARRAY 2 OF SET; quadlet: SET;
BEGIN
	diskres:= 0;

	(* Print(debug,"Printing the buffer Address of the last orb");
	FirewireLowUtil.PrintSet(lastOrb.bufAddr); *)
	IF lastOrb.bufAddr = {} THEN
		(* let's write to the targets management agent register to to set the orb pointer offset *)
		(* Print(debug,"Setting the orb pointer offset"); *)
		buffer[0]:=  {};
		buffer[1]:= commandOrb.bufAddr;
		(* swap bytes *)

		InvertByteOrderWord(buffer[1]);

		IF ~HpsbNodeWrite(nodeEntry,cmdBlckAgntAddrLow+SYSTEM.VAL(SET,SBP2ORBPointerOffset),
			cmdBlckAgntAddrHigh , SYSTEM.VAL(SET,ADDRESSOF(buffer)), 8) THEN diskres:= 1;
			Print(debug,"Setting the orb pointer failed");
		END;

		lastOrb.bufAddr:= commandOrb.bufAddr;
		lastOrb.ptrToBfr:= commandOrb.ptrToBfr;
		lastOrb.dataDescLo:= commandOrb.dataDescLo;
		lastOrb.ptrToDataBfr:= commandOrb.ptrToDataBfr;
		(* Print(debug,"Printing the buffer Address of the last orb");
		FirewireLowUtil.PrintSet(lastOrb.bufAddr); *)
	ELSE (* the orb pointer is already set *)
		SYSTEM.PUT32(SYSTEM.VAL(LONGINT,lastOrb.bufAddr),0);
		SYSTEM.PUT32(SYSTEM.VAL(LONGINT,lastOrb.bufAddr)+4,SYSTEM.VAL(LONGINT,commandOrb.bufAddr));
		(* swap bytes *)
		InvertByteOrder(SYSTEM.VAL(LONGINT,lastOrb.bufAddr)+4,4);
		(* release buffer *)
		commandOrbFIFO.ReleaseBuffer(lastOrb.ptrToBfr,SYSTEM.VAL(LONGINT,lastOrb.bufAddr));
		dataBufferFIFO.ReleaseBuffer(lastOrb.ptrToDataBfr,SYSTEM.VAL(LONGINT,lastOrb.dataDescLo));
		lastOrb.bufAddr:= commandOrb.bufAddr;
		lastOrb.ptrToBfr:= commandOrb.ptrToBfr;
		lastOrb.dataDescLo:= commandOrb.dataDescLo;
		lastOrb.ptrToDataBfr:= commandOrb.ptrToDataBfr;
		(* ring the doorbell *)
		(* Print(debug,"Ringing the doorbell"); *)
		quadlet:= commandOrb.bufAddr;
		(* it's not important what we write in the doorbell register *)
		IF ~HpsbNodeWrite(nodeEntry,cmdBlckAgntAddrLow+SYSTEM.VAL(SET,SBP2DoorbellOffset),
			cmdBlckAgntAddrHigh ,quadlet , 4) THEN diskres:= 1;
			Print(debug,"Ringing the doorbell failed");
		END
	END
END LinkCommandOrb;

PROCEDURE HandleStatus(statusBufAddr: LONGINT);
VAR statusHi: SET; length: LONGINT; scsiStatus: LONGINT;
BEGIN
	statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(statusBufAddr));
	(* Check if target stored any scsi status information, check the length *)
	length:= SYSTEM.VAL(LONGINT,LSH(statusHi,-24)*{0..2});
	IF length > 1 THEN (* there is scsi sense data, something went wrong *)
	ELSE scsiStatus:= good; (* for future use *)
	END;


	(* check to see if the dead bit is set *)
	IF 27 IN SYSTEM.VAL(SET,SYSTEM.GET32(statusBufAddr)) THEN (* do an agent reset *)
		KernelLog.String("The dead bit is set, doing an agent reset!"); KernelLog.Ln();
		AgentReset(SELF);
	END;

	(*
	KernelLog.String("Printing the status: "); KernelLog.Ln();
	FirewireLowUtil.PrintSet(statusHi);
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(statusBufAddr+4)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(statusBufAddr+8)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(statusBufAddr+12))); *)
	IF ({28,29}*statusHi # {}) OR (27 IN statusHi) OR ({16..23}* statusHi # {}) THEN
		KernelLog.String("There was an error sending the command!"); KernelLog.Ln();
	ELSE (* Print(debug,"There was no error sending the command!"); KernelLog.Ln(); *)
	END;
	(* resetting the status *)
	SYSTEM.PUT32(statusBufAddr,{});
END HandleStatus;

PROCEDURE SendCommand(VAR command: Command;VAR diskres: LONGINT): BOOLEAN;
VAR
	commandOrb: Sbp2CommandOrb;i,addr,retBufferAddr : LONGINT; (* t: Kernel.Timer; *)
	statusHi,statusLow: SET;
	milliTimer : Kernel.MilliTimer;
BEGIN
	(* remember return buffer address *)
	(* Print(debug,"Printing the return buffer address");
	FirewireLowUtil.PrintSet(command.bufferAddr); *)
	retBufferAddr:= SYSTEM.VAL(LONGINT,command.bufferAddr);
	(* ASSERT(retBufferAddr > 0); *)
	(* KernelLog.String("Printing commandOrb.cdb: "); KernelLog.Int(ADDRESSOF(commandOrb.cdb),2); KernelLog.Ln();
	ASSERT(ADDRESSOF(commandOrb.cdb) > 0); *)
	(* Print(debug,"Printing the return buffer address");
	KernelLog.Int(retBufferAddr,2); *)
	(* fill the command orb *)

	CreateCommandOrb(commandOrb,command);


	(* initialize status block *)
	FOR i:= 0 TO 7 DO
		SYSTEM.PUT32(SYSTEM.VAL(LONGINT,statusBlock.bufAddr)+i*4,0);
	END;
	(* link up the orb and ring the doorbell *)

	LinkCommandOrb(commandOrb,diskres);


	(* wait for the status *)
	addr:= SYSTEM.VAL(LONGINT,statusBlock.bufAddr);
	statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
	statusLow:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+4));

	Kernel.SetTimer(milliTimer, 120000); (* Wait for two min *)
	i:= 0;
	WHILE ((statusHi = {}) OR (statusLow = {})) & ~Kernel.Expired(milliTimer)  DO
		Objects.Yield(); statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
		statusLow:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+4));
	END;
	IF (statusHi = {}) & (statusLow = {}) THEN Print(debug,"Error: Received no status!"); diskres:= -1; RETURN FALSE
	ELSE  HandleStatus(addr)
	END;
	IF command.dataDirection = DataRead THEN
		ASSERT((blockSize MOD 4)=0);
		FOR i:= 0 TO (command.bufferLen DIV 4)-1 DO
			SYSTEM.PUT32(retBufferAddr+i*4,SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)+i*4))
		END;
		InvertByteOrder(retBufferAddr,command.bufferLen);
	END;

	RETURN TRUE;
END SendCommand;

PROCEDURE Handle *(VAR msg: Disks.Message; VAR diskres: LONGINT);
(* VAR command: Command; cylinders,heads,sectors,i: LONGINT; *)
BEGIN
	KernelLog.String("HANDLE"); KernelLog.Ln;
	diskres := Disks.Unsupported;
(*	IF msg IS Disks.GetGeometryMsg THEN  Print(debug,"It's a geometry message request!");
		msg(Disks.GetGeometryMsg).spt:= 18; msg(Disks.GetGeometryMsg).hds := 2; msg(Disks.GetGeometryMsg).cyls := 80;
		build IDENTIFY DRIVE command
		command.bufferAddr:= AllocBuf(1024,command.ptrToBfr);

		command.bufferLen:= 1024;
		command.dataDirection:= DataRead;

		(* UFI: IDENTIFY DRIVE command *)
		FOR i:= 0 TO 11 DO command.cdb[i] := CHR(0); END;
		command.cdb[0] := 0ECX;

		IF ~SendCommand(command,diskres) THEN END;
		IF (diskres # Disks.Ok) THEN RETURN; END;

		cylinders:= SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)+1);
		heads:= SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)+3);
		sectors:= SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)+6);

		Print(debug,"cylinders: "); KernelLog.Int(cylinders,2); KernelLog.Ln();
		Print(debug,"cylinders: "); KernelLog.Int(heads,2); KernelLog.Ln();
		Print(debug,"cylinders: "); KernelLog.Int(sectors,2); KernelLog.Ln();

	ELSE Print(debug,"Message unknown!")
	END; *)
	SELF.blockSize:= 512;
	(* KernelLog.Int(SELF.blockSize,2); *)
END Handle;

PROCEDURE Transfer*(op,block,num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR diskres: LONGINT);
VAR i, payloadNotCoded: LONGINT; command: Command; numOfBlocks,tries: LONGINT;
BEGIN

	tries:= 0;
	payloadNotCoded:= SYSTEM.VAL(LONGINT,LSH({0},maxPayload+1));
	numOfBlocks:= payloadNotCoded DIV blockSize;

	FOR i:= 0 TO 11 DO command.cdb[i]:= CHR(0) END;

	IF (op = Disks.Read) OR (op = Disks.Write) THEN

		IF op = Disks.Read THEN
			command.cdb[0]:= 28X; command.dataDirection:= DataRead
		ELSE
			command.cdb[0]:= 2AX; command.dataDirection:= DataWrite
		END;

		i:= 0;

		WHILE num > 0 DO
			IF numOfBlocks < num THEN command.bufferLen:= numOfBlocks*blockSize;
			ELSE command.bufferLen:= num*blockSize; numOfBlocks:= num;
			END;
			command.bufferAddr:= SYSTEM.VAL(SET,ADDRESSOF(data[0])+ofs+i*blockSize);
			command.cdb[2]:= CHR(LSH(block,-24));
			command.cdb[3]:= CHR(LSH(block,-16));
			command.cdb[4]:= CHR(LSH(block,-8));
			command.cdb[5]:= CHR(block);
			(* command.cdb[7]:= CHR(LSH(num,-8));
			command.cdb[8]:= CHR(num); *)
			command.cdb[7]:= CHR(LSH(numOfBlocks,-8));
			command.cdb[8]:= CHR(numOfBlocks);
			IF ~SendCommand(command, diskres) THEN
				IF tries > 10 THEN RETURN ELSE INC(tries); END;
			ELSE
				IF diskres # Disks.Ok THEN RETURN
				END;
				tries:= 0;
				INC(block,numOfBlocks); DEC(num,numOfBlocks); INC(i,numOfBlocks);
			END;
		END
	ELSE
		diskres:= Disks.Unsupported;
	END;
END Transfer;

PROCEDURE GetSize*(VAR size: LONGINT;VAR diskres: LONGINT);
VAR command: Command; i: LONGINT; (* dev: Sbp2Dev; *)
BEGIN

	command.bufferAddr:= AllocBuf(1024,command.ptrToBfr);

	command.bufferLen:= 1024;
	command.dataDirection:= DataRead;

	(* UFI: Read Capacity command *)
	FOR i:= 0 TO 11 DO command.cdb[i] := CHR(0); END;
	command.cdb[0] := 25X;

	IF ~SendCommand(command,diskres) THEN END;
	IF (diskres # Disks.Ok) THEN RETURN; END;

	size:= SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr));
	blockSize:= SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)+4);

	INC (size);

	diskres := Disks.Ok;

	(* KernelLog.String(" Disk info: Blocks: "); KernelLog.Int(size, 0);
	KernelLog.String(" blocksize: "); KernelLog.Int(blockSize,0);
	KernelLog.String(" size: "); KernelLog.Int(size*blockSize,0);
	KernelLog.String(" size in giga: "); KernelLog.Int(((size DIV 1024)*(blockSize)) DIV (1024*1024),0);
	KernelLog.Ln; *)

END GetSize;

		PROCEDURE &Init*;
		BEGIN
			(* set default *) blockSize:= 512; NEW(t);
		END Init;

	END Sbp2Dev;

	SbpDevGrp= ARRAY 64 OF Sbp2Dev;

	Sbp2StatusBlock*= RECORD
		orbOffsetHi: SET;
		orbOffsetLo: SET;
		commandSetDependent: ARRAY 24 OF CHAR;
		bufAddr: SET;
		ptrToBfr: Buffer;
	END;

	Sbp2LoginOrb*= RECORD
		passwordHi: LONGINT;
		passwordLo: LONGINT;
		loginRespHi: LONGINT;
		loginRespLo: LONGINT;
		lunMisc: SET;
		passwrdRespLens: LONGINT;
		statusFIFOHi: SET;
		statusFIFOLo: SET;
		bufAddr: SET;
		ptrToBfr: Buffer;
	END;

	Sbp2LoginResponse*= RECORD
		lenLoginID: LONGINT;
		commandBlckAgntHi: SET;
		commandBlckAgntLo: SET;
		reconnectHold: SET;
		bufAddr: SET;
		ptrToBfr: Buffer;
	END;

	Sbp2QueryLoginsOrb*= RECORD
		reserved1: LONGINT;
		reserved2: LONGINT;
		queryRespHi: SET;
		queryRespLo: SET;
		lunMisc: SET;
		reservedRespLen: LONGINT;
		statusFIFOHi: SET;
		statusFIFOLo: SET;
		bufAddr: SET;
		ptrToBfr: Buffer;
	END;

	Sbp2QueryLoginsResp*= RECORD
		lenMaxLogins: LONGINT;
		miscIDs: SET;
		initiatorMiscHi: LONGINT;
		initiatorMiscLo: LONGINT;
		bufAddr: SET;
		ptrToBfr: Buffer;
	END;

	Sbp2ReconnectOrb*= RECORD
		reserved1: LONGINT;
		reserved2: LONGINT;
		reserved3: LONGINT;
		reserved4: LONGINT;
		loginIDMisc: SET;
		reserved5: LONGINT;
		statusFIFOHi: SET;
		statusFIFOLo: SET;
		bufAddr: SET;
		ptrToBfr: Buffer;
	END;

	Sbp2LogoutOrb*= RECORD
		reserved1: LONGINT;
		reserved2: LONGINT;
		reserved3: LONGINT;
		reserved4: LONGINT;
		loginIDMisc: SET;
		reserved5: LONGINT;
		statusFIFOHi: SET;
		statusFIFOLo: SET;
		bufAddr: SET;
		ptrToBfr: Buffer;
	END;

	Sbp2CommandOrb*= RECORD
		nextOrbHi: SET;
		nextOrbLo: SET;
		dataDescHi: SET;
		dataDescLo: SET;
		ptrToDataBfr: Buffer;
		misc: SET;
		cdb: ARRAY 12 OF CHAR;
		bufAddr: SET;
		ptrToBfr: Buffer;
	END;

	Sbp2CommandInfo*= RECORD
		command: Sbp2CommandOrb;
		dataDirection: LONGINT;
	END;

VAR
	debug: BOOLEAN;
	sbpDevGrps: ARRAY 63 OF SbpDevGrp; (* This should be updated if the driver has to scan more than one bus *)
	numOfGrps: LONGINT;
	host: FirewireLowUtil.OHCIDesc;

(** Set the maximum speed and payload size for a new identified device *)
PROCEDURE MaxSpeedAndSize(VAR dev: Sbp2Dev);
BEGIN
	(* Print(debug,"Setting max speed and payload size"); *)
	dev.speedCode:= host.SpeedMap[host.nodeID][SYSTEM.VAL(LONGINT,dev.nodeEntry.phyID)];
	IF ConvertSpeedToPayload(dev.speedCode) > ConvertPayloadToMaxRec(host.MaxPacketSize) THEN
		dev.maxPayload:= ConvertPayloadToMaxRec(host.MaxPacketSize)
	ELSE dev.maxPayload:= ConvertSpeedToPayload(dev.speedCode)
	END;
	(* KernelLog.Int(dev.speedCode,2); KernelLog.Ln();
	KernelLog.Int(dev.maxPayload,2); KernelLog.Ln(); *)
END MaxSpeedAndSize;

PROCEDURE AgentReset(dev: Sbp2Dev);
VAR quadlet: SET;
BEGIN
	(* Print(debug,"Doing an agent reset"); *)
	quadlet:= SYSTEM.VAL(SET,SBP2AgentResetData);

	IF ~HpsbNodeWrite(dev.nodeEntry,
		dev.cmdBlckAgntAddrLow+SYSTEM.VAL(SET,SBP2AgentResetOffset),dev.cmdBlckAgntAddrHigh,quadlet,4) THEN
		Print(debug,"Resetting the agent failed");
	END;

END AgentReset;

PROCEDURE SetBusyTimeOut(ne: FirewireLowUtil.Node);
VAR quadlet: SET;
BEGIN
	(* Print(debug,"Setting busy time out"); *)

	quadlet:= SYSTEM.VAL(SET,BusyTimeOut);

	InvertByteOrderWord(quadlet);

	IF ~HpsbNodeWrite(ne,SYSTEM.VAL(SET,SBP2BusyTimeOutAddrLo),
		SYSTEM.VAL(SET,SBP2BusyTimeOutAddrHi),quadlet,4) THEN
		Print(debug,"Setting the busy time out failed");
	END;

END SetBusyTimeOut;

PROCEDURE InvertByteOrderWord(VAR word: SET);
VAR swapWord: SET;
BEGIN
	swapWord:= LSH(word*{0..7},24);
	swapWord:= swapWord +LSH(word*{8..15},8);
	swapWord:= swapWord +LSH(word*{16..23},-8);
	swapWord:= swapWord +LSH(word*{24..31},-24);
	word:= swapWord;
END InvertByteOrderWord;

(*
PROCEDURE InvertByteOrderBuf(VAR buffer: ARRAY OF SET; length: LONGINT);
VAR numOfWords, i: LONGINT; quadlet,quadletSwap: SET;
BEGIN
	numOfWords:= length DIV 4; i:= 0; length:= 0;
	WHILE i # numOfWords DO
		quadlet:= buffer[i];
		(* FirewireLowUtil.PrintSet(quadlet); *)
		quadletSwap:= LSH(quadlet*{0..7},24);
		quadletSwap:= quadletSwap+LSH(quadlet*{8..15},8);
		quadletSwap:= quadletSwap+LSH(quadlet*{16..23},-8);
		quadletSwap:= quadletSwap+LSH(quadlet*{24..31},-24);
		(* FirewireLowUtil.PrintSet(quadletSwap); *)
		buffer[i]:= quadletSwap;
		INC(i);
	END;
END InvertByteOrderBuf;
*)

PROCEDURE InvertByteOrder(bufAddr: LONGINT; length: LONGINT);
VAR  numOfWords, i: LONGINT; quadlet,quadletSwap: SET;
BEGIN
	numOfWords:= length DIV 4; i:= 0; length:= 0;
	WHILE i # numOfWords DO
		quadlet:= SYSTEM.VAL(SET,SYSTEM.GET32(bufAddr+length));
		(* FirewireLowUtil.PrintSet(quadlet); *)
		quadletSwap:= LSH(quadlet*{0..7},24);
		quadletSwap:= quadletSwap+LSH(quadlet*{8..15},8);
		quadletSwap:= quadletSwap+LSH(quadlet*{16..23},-8);
		quadletSwap:= quadletSwap+LSH(quadlet*{24..31},-24);
		(* FirewireLowUtil.PrintSet(quadletSwap); *)
		SYSTEM.PUT32(bufAddr+length,SYSTEM.VAL(LONGINT,quadletSwap));
		INC(i); INC(length,4);
	END;
END InvertByteOrder;

(* Allocates quadlet aligned buffers *)
PROCEDURE AllocBuf(size:LONGINT;VAR ptrToBfr: Buffer):SET;
VAR buffer: Buffer; adr: LONGINT; s: SET;
BEGIN
	NEW(buffer, size + 4);
	adr:= ADDRESSOF(buffer[0]);
	ASSERT(adr > 0);
	(* Find a 4 byte aligned address *)
	DEC(adr, adr MOD 4);
	INC(adr, 4);
	ASSERT(adr > 0);
	s:= SYSTEM.VAL(SET,adr);
	ptrToBfr:= buffer;
	RETURN s;
END AllocBuf;

PROCEDURE Probe*;
VAR i,j,k: LONGINT; node: FirewireLowUtil.Node; ud: FirewireLowUtil.UnitDirectory;
BEGIN
	i:= 0; j:= 0; k:= 0;
	(* Print(debug,"<<<<<<<<<<<<<<<<<<<<<<<<<< SBP2 >>>>>>>>>>>>>>>>>>>>>>>>>>"); *)
	host:= FirewireLow.c.OHCI;
	WHILE FirewireLow.c.OHCI.Nodes[i] # NIL DO
		node:= FirewireLow.c.OHCI.Nodes[i];
		WHILE node.uds[j] # NIL DO
			ud:= node.uds[j];
			IF ud.hasLogicalUnitDir THEN
				WHILE ud.luns[k] # NIL DO
					ScanUD(node,i,ud.luns[k],ud,TRUE); INC(k);
				END
			ELSE ScanUD(node,i,ud,ud,FALSE)
			END;
			INC(j)
		END;
		INC(i)
	END;
	numOfGrps:= i-1;
	(* Print(debug,"Leaving Probe!"); *)
END Probe;

PROCEDURE ConvertSpeedToPayload(speed: LONGINT):LONGINT;
BEGIN
	CASE speed OF
		0: RETURN 7H  (* 512 *);
		|1: RETURN  8H (*  1024 *);
		|2: RETURN 9H (* 2048  *);
		|3: RETURN 0AH (* 4096 *);
		|4: RETURN  0BH (* 8192 *);
		|5: RETURN 0CH (* 16384 *);
	END;
END ConvertSpeedToPayload;

PROCEDURE ConvertPayloadToMaxRec(payload: LONGINT):LONGINT;
BEGIN
	payload:= payload-20;
	IF payload = 4 THEN RETURN 1H
	ELSIF payload = 8 THEN RETURN 2H
	ELSIF payload = 16 THEN RETURN 3H
	ELSIF payload = 32 THEN RETURN 4H
	ELSIF payload = 64 THEN RETURN 5H
	ELSIF payload = 128 THEN RETURN 6H
	ELSIF payload = 256 THEN RETURN 7H
	ELSIF payload = 512 THEN RETURN 8H
	ELSIF payload = 1024 THEN RETURN 9H
	ELSIF payload = 2048 THEN RETURN 0AH
	ELSIF payload = 4096 THEN RETURN 0BH
	ELSIF payload = 8192 THEN RETURN 0CH
	ELSIF payload = 16384 THEN RETURN 0DH
	ELSIF payload = 32768 THEN RETURN 0EH
	ELSIF payload = 65536 THEN RETURN 0FH
	ELSE RETURN 0H
	END
END ConvertPayloadToMaxRec;

PROCEDURE CreateCommandOrbPool(dev: Sbp2Dev);
	(* does nothing *)
END CreateCommandOrbPool;

PROCEDURE Sbp2LogoutDevice(VAR dev: Sbp2Dev): BOOLEAN;
VAR buffer: ARRAY 2 OF SET; i,addr: LONGINT; t: Kernel.Timer;
BEGIN
	NEW(t);
	(* Print(debug,"Logging out of the device"); *)
	dev.logoutOrb.reserved1:= 0;
	dev.logoutOrb.reserved2:= 0;
	dev.logoutOrb.reserved3:= 0;
	dev.logoutOrb.reserved4:= 0;
	(* set the logout function *)
	dev.logoutOrb.loginIDMisc:= {};
	dev.logoutOrb.loginIDMisc:= (* SYSTEM.VAL(SET,LSH(7,16)); *) {16,17,18};
	(* set the login id *)
	(* Print(debug,"Printing the login id: "); FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,dev.loginResp.bufAddr)))*{0..15});
	dev.logoutOrb.loginIDMisc:=
		dev.logoutOrb.loginIDMisc + SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,dev.loginResp.bufAddr)))*{0..15};
	(* set the notify bit *) *)
	dev.logoutOrb.loginIDMisc:= dev.logoutOrb.loginIDMisc + {31};
	dev.logoutOrb.reserved5:= 0;
	dev.logoutOrb.statusFIFOLo:= dev.statusBlock.bufAddr;
	(* Print(debug,"Printing the status buffer address");
	FirewireLowUtil.PrintSet(dev.statusBlock.bufAddr); *)
	dev.logoutOrb.statusFIFOHi:= LSH(FirewireLowUtil.ReadReg(FirewireLowUtil.NodeID)*{0..15},16);

	(* now write the structure into the buffers *)
	(* Print(debug,"Printing the logoutOrb buffer address"); *)
	addr:= SYSTEM.VAL(LONGINT,dev.logoutOrb.bufAddr);
	(* FirewireLowUtil.PrintSet(dev.logoutOrb.bufAddr); *)
	SYSTEM.PUT32(addr,dev.logoutOrb.reserved1);
	SYSTEM.PUT32(addr+4,dev.logoutOrb.reserved2);
	SYSTEM.PUT32(addr+8,dev.logoutOrb.reserved3);
	SYSTEM.PUT32(addr+12,dev.logoutOrb.reserved4);
	SYSTEM.PUT32(addr+16,dev.logoutOrb.loginIDMisc);
	SYSTEM.PUT32(addr+20,dev.logoutOrb.reserved5);
	SYSTEM.PUT32(addr+24,{});
	SYSTEM.PUT32(addr+28,dev.logoutOrb.statusFIFOLo);

	(* byte swap the content *)
	InvertByteOrder(addr,32);

	(* let's write to the target's management agent register *)
	buffer[0]:= LSH(FirewireLowUtil.ReadReg(FirewireLowUtil.NodeID)*{0..15},16);
	buffer[1]:= dev.logoutOrb.bufAddr;
	(* Print(debug,"Address before byte swapping");
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,buffer[0]));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,buffer[1])); *)

	(* swap bytes *)
	InvertByteOrderWord(buffer[1]);

	(* Print(debug,"Address after byte swapping");
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,buffer[0]));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,buffer[1])); *)

	(* Print(debug,"Writing to node!"); *)
	(* Print(debug,"Printing the management agent address!");
	FirewireLowUtil.PrintSet(dev.mgmtAgntAddrLow);FirewireLowUtil.PrintSet(dev.mgmtAgntAddrHigh); *)
	IF ~HpsbNodeWrite(dev.nodeEntry, dev.mgmtAgntAddrLow,
		dev.mgmtAgntAddrHigh, SYSTEM.VAL(SET,ADDRESSOF(buffer)), 8) THEN
		Print(debug,"Writing to the management agent failed");
	END;

	(* should wait up to 20 seconds *)
	t.Sleep(50);
	addr:= SYSTEM.VAL(LONGINT,dev.statusBlock.bufAddr);
	(* Print(debug,"Printing the status"); *) i:= 0;
	WHILE (SYSTEM.GET32(addr) = 0) & (i<10) DO t.Sleep(50); INC(i); Print(debug,"I'm waiting"); END;
	(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+4))); *)

	(* make sure that address belongs to this login orb
	IF ~(dev.logoutOrb.bufAddr = SYSTEM.VAL(SET,SYSTEM.GET32(addr+4))) THEN
		Print(debug,"The status block belongs to a wrong orb"); RETURN FALSE
	END; *)

	(* check the status
	statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
	Print(debug,"Printing the status");
	FirewireLowUtil.PrintSet(statusHi);
	IF ({28,29}*statusHi # {}) OR (27 IN statusHi) OR ({16..23}* statusHi # {}) THEN
		KernelLog.String("There was an error logging out of the device!"); KernelLog.Ln();
		RETURN FALSE
	END; *)

	(* Print(debug,"Logout was successfull!"); *)
	RETURN TRUE;

END Sbp2LogoutDevice;

PROCEDURE Sbp2LoginDevice(VAR dev: Sbp2Dev): BOOLEAN;
VAR buffer: ARRAY 2 OF SET; i,addr: LONGINT; t: Kernel.Timer; statusHi: SET;
BEGIN
	NEW(t);
	(* Print(debug,"Logging into device"); *)
	(* initialize login orb, no password *)
	dev.loginOrb.passwordHi:= 0;
	dev.loginOrb.passwordLo:= 0;
	dev.loginOrb.loginRespHi:= 0; (* LSH(SYSTEM.VAL(LONGINT,LSH(FirewireLowUtil.GetBusID(),6)) + host.nodeID,16); *)
	dev.loginOrb.loginRespLo:= SYSTEM.VAL(LONGINT,dev.loginResp.bufAddr);
	dev.loginOrb.lunMisc:= (* SYSTEM.VAL(SET,LSH(LoginRequest,16)) + *)
	LSH({},20) (* one second reconnect time *) +
	LSH({0},28) (* exclusive login *) +
	LSH({0},31) (* notify us when the login is complete *);
	(* now set the lun if initialized *)
	IF SYSTEM.VAL(LONGINT,dev.logicalUnitNumber) # UninitializedLUN THEN
		dev.loginOrb.lunMisc:= dev.loginOrb.lunMisc + SYSTEM.VAL(SET,dev.logicalUnitNumber);
		(* KernelLog.Int(SYSTEM.VAL(LONGINT,dev.logicalUnitNumber),2); KernelLog.Ln(); *)
	ELSE Print(debug,"LUN uninitialized");
	END;
	dev.loginOrb.passwrdRespLens:= 16;
	dev.loginOrb.statusFIFOLo:= dev.statusBlock.bufAddr;
	(* Print(debug,"Printing the status buffer address");
	FirewireLowUtil.PrintSet(dev.statusBlock.bufAddr); *)
	dev.loginOrb.statusFIFOHi:= LSH(FirewireLowUtil.ReadReg(FirewireLowUtil.NodeID)*{0..15},16);

	(* now write the structure into the buffers *)
	(* Print(debug,"Printing the loginOrb buffer address"); *)
	addr:= SYSTEM.VAL(LONGINT,dev.loginOrb.bufAddr);
	(* FirewireLowUtil.PrintSet(dev.loginOrb.bufAddr); *)
	SYSTEM.PUT32(addr,dev.loginOrb.passwordHi);
	SYSTEM.PUT32(addr+4,dev.loginOrb.passwordLo);
	SYSTEM.PUT32(addr+8,{});
	SYSTEM.PUT32(addr+12,dev.loginOrb.loginRespLo);
	SYSTEM.PUT32(addr+16,dev.loginOrb.lunMisc);
	SYSTEM.PUT32(addr+20,dev.loginOrb.passwrdRespLens);
	SYSTEM.PUT32(addr+24,{});
	SYSTEM.PUT32(addr+28,dev.loginOrb.statusFIFOLo);

	(* byte swap the content *)
	InvertByteOrder(addr,32);

	(* let's write to the target's management agent register *)
	buffer[0]:= {};
	buffer[1]:= dev.loginOrb.bufAddr; (*
	Print(debug,"Address before byte swapping");
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,buffer[0]));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,buffer[1])); *)

	(* swap bytes *)
	InvertByteOrderWord(buffer[1]); (*
	Print(debug,"Address after byte swapping");
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,buffer[0]));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,buffer[1])); *)

	dev.loginComplete:= FALSE;

	(* Print(debug,"Writing to node!"); *)
	(* Print(debug,"Printing the management agent address!");
	FirewireLowUtil.PrintSet(dev.mgmtAgntAddrLow);FirewireLowUtil.PrintSet(dev.mgmtAgntAddrHigh); *)

	IF ~HpsbNodeWrite(dev.nodeEntry, dev.mgmtAgntAddrLow,
		dev.mgmtAgntAddrHigh, SYSTEM.VAL(SET,ADDRESSOF(buffer)), 8) THEN
		Print(debug,"Writing to the management agent failed");
	END;

	(* should wait up to 20 seconds *)
	t.Sleep(50);
	addr:= SYSTEM.VAL(LONGINT,dev.statusBlock.bufAddr);
	(* Print(debug,"Printing the status"); *) i:= 0;
	WHILE (SYSTEM.GET32(addr) = 0) & (i<10) DO t.Sleep(50); INC(i); Print(debug,"I'm waiting"); END;
	(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+4))); *)

	(* make sure that address belongs to this login orb *)
	IF ~(dev.loginOrb.bufAddr = SYSTEM.VAL(SET,SYSTEM.GET32(addr+4))) THEN
		Print(debug,"The status block belongs to a wrong orb"); RETURN FALSE
	END;

	(* check the status *)
	statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
	IF ({28,29}*statusHi # {}) OR (27 IN statusHi) OR ({16..23}* statusHi # {}) THEN
		KernelLog.String("There was an error logging into the device!"); KernelLog.Ln();
		FirewireLowUtil.PrintSet(statusHi);
		RETURN FALSE
	END;

	(* take the command block agent address *)
	(* Print(debug,"Printing the command block agent address"); *)

	addr:= SYSTEM.VAL(LONGINT,dev.loginResp.bufAddr);
	(* Print(debug,"Printing the login id: "); FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr))*{0..15}); *)
	dev.cmdBlckAgntAddrHigh:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+4));
	(* FirewireLowUtil.PrintSet(dev.cmdBlckAgntAddrHigh); *)
	dev.cmdBlckAgntAddrLow:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+8));
	(* FirewireLowUtil.PrintSet(dev.cmdBlckAgntAddrLow); *)

	KernelLog.String("Successfully logged into 1394 device"); KernelLog.Ln();
	RETURN TRUE;

END Sbp2LoginDevice;

PROCEDURE HpsbNodeWrite(ne: FirewireLowUtil.Node; addrLow, addrHigh: SET;buffer:  SET; len: LONGINT):BOOLEAN;
VAR generation,i: LONGINT; result: BOOLEAN;
BEGIN
	(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,bufAddr))));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,bufAddr)+4))); *)
	generation:= FirewireLowUtil.GetGeneration();
	i:= 0;
	WHILE (i<4) & ~result DO
		IF FirewireLow.c.Write1394(host.ATController.GetReqContest(),host,ne.phyID,generation, buffer, addrLow,addrHigh,len) THEN
			(* Print(debug,"Write was successfull!"); *) result:= TRUE;
		ELSE Print(debug,"Write was not successfull!"); result:= FALSE;
		END;
		INC(i);
	END;
	RETURN result
END HpsbNodeWrite;

PROCEDURE StartDev(VAR dev: Sbp2Dev);
BEGIN
	(* Print(debug,"Starting device!"); *)
	dev.loginResp.bufAddr:= AllocBuf(16,dev.loginResp.ptrToBfr); (* 4 quadlets *)
	dev.queryLogins.bufAddr:= AllocBuf(32,dev.queryLogins.ptrToBfr); (* 8 quadlets *)
	dev.queryLoginsResp.bufAddr:= AllocBuf(16,dev.queryLoginsResp.ptrToBfr);
	dev.reconnectOrb.bufAddr:= AllocBuf(32,dev.reconnectOrb.ptrToBfr);
	dev.logoutOrb.bufAddr:= AllocBuf(32,dev.logoutOrb.ptrToBfr);
	dev.loginOrb.bufAddr:= AllocBuf(32,dev.loginOrb.ptrToBfr);
	dev.statusBlock.bufAddr:= AllocBuf(32,dev.statusBlock.ptrToBfr);
	CreateCommandOrbPool(dev);

	IF ~Sbp2LoginDevice(dev) THEN KernelLog.String("Login into device failed"); KernelLog.Ln(); RETURN END;
	(* Set max retries to a large number *)
	SetBusyTimeOut(dev.nodeEntry);
	(* do a fetch agent reset *)
	AgentReset(dev);
	(* get the max speed and packet size we can use *)
	MaxSpeedAndSize(dev);
	dev.Config();
END StartDev;

(** Scans the unit directory *)
PROCEDURE ScanUD(node: FirewireLowUtil.Node;index: LONGINT; ud, udPar: FirewireLowUtil.UnitDirectory; isLUN: BOOLEAN);
VAR devGrp: SbpDevGrp; i: LONGINT; dev: Sbp2Dev; devNum,lunNum: ARRAY 10 OF CHAR;
name: Plugins.Name;
BEGIN
	ParseUD(devGrp,ud,udPar,isLUN);
	sbpDevGrps[index]:= devGrp;
	i:= 0;
	WHILE devGrp[i] # NIL DO
		dev:= devGrp[i];
		dev.nodeEntry:= node;
		dev.speedCode:= 0; (* stands for 100 in 1394 *)
		dev.maxPayload:= ConvertSpeedToPayload(dev.speedCode);
		dev.loginComplete:= FALSE;
		StartDev(dev);
		devGrp[i]:= dev;
		Strings.IntToStr(index,devNum);
		Strings.IntToStr(i,lunNum);
		name := "1394Dev";
		Strings.Append(name,devNum);
		Strings.Append(name,lunNum);
		dev.SetName(name);
		AddStorageDevices(dev);
		(* Print(debug,"Storing device on index: "); KernelLog.Int(i,2); KernelLog.Ln();
		KernelLog.Int(dev.maxPayload,2); KernelLog.Ln(); *)
		INC(i);
	END;
	sbpDevGrps[index]:= devGrp;
END ScanUD;

PROCEDURE AddStorageDevices(VAR dev: Sbp2Dev);
VAR res: LONGINT;
BEGIN
	(* now add to disk system *)
	Disks.registry.Add(dev,res);
	IF res#Plugins.Ok THEN
		KernelLog.Ln;
		KernelLog.String("AosFireWireStorage: Error: Couldn't add device to Disks.registry (Error code: ");
		KernelLog.Int(res,0); KernelLog.String(")"); KernelLog.Ln;
		RETURN;
	END;
END AddStorageDevices;

PROCEDURE RemoveStorageDevice(VAR dev: Sbp2Dev);
BEGIN
	IF ~Sbp2LogoutDevice(dev) THEN KernelLog.String("Device could not be removed!") END;
	Disks.registry.Remove(dev);
END RemoveStorageDevice;

PROCEDURE RemoveAllStorageDevices;
VAR index,index2,numOfDev: LONGINT; grp: SbpDevGrp; dev: Sbp2Dev;
BEGIN
	index:= 0; index2:= 0;
	numOfDev:= numOfGrps;
	WHILE index <= numOfDev DO
		grp:= sbpDevGrps[index];
		WHILE grp[index2] # NIL DO
			dev:= grp[index2];
			RemoveStorageDevice(dev);
			INC(index2);
		END;
		IF index2 = 1 THEN  DEC(numOfDev) END;
		INC(index);
	END;
END RemoveAllStorageDevices;

PROCEDURE ParseUD(VAR grp: SbpDevGrp; ud,udPar: FirewireLowUtil.UnitDirectory; isLUN: BOOLEAN);
VAR mgmtAgntAddrLow, mgmtAgntAddrHigh, unitChar: SET; commandSetSpecID, commandSet, firmwareRev: LONGINT;
	i,j,length,key,value: LONGINT; dev: Sbp2Dev;
BEGIN
	(* Print(debug,"Parsing unit directory!"); *)
	length:= ud.GetLength(); i:= 0;
	WHILE i < (length) DO
		key:= SYSTEM.VAL(LONGINT,LSH(ud.udEntries[i],-24));
		value:= SYSTEM.VAL(LONGINT,ud.udEntries[i]*{0..23});
		CASE key OF
			SBP2CSROffsetKey: mgmtAgntAddrLow:= FirewireLowUtil.CSRBaseLow;
				mgmtAgntAddrHigh:= FirewireLowUtil.CSRBaseHigh;
				(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,value)); *)
				(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,LSH(value,2)));
				FirewireLowUtil.PrintSet(mgmtAgntAddrLow); *)
				mgmtAgntAddrLow:= SYSTEM.VAL(SET,LSH(value,2)) + mgmtAgntAddrLow;
				(* Print(debug,"Found management agent address"); *)
				(* FirewireLowUtil.PrintSet(mgmtAgntAddrLow); *)
			|SBP2CommandSetSpecIDKey: commandSetSpecID:= value;
			|SBP2CommandSetKey: commandSet:= value;
			|SBP2UnitCharKey: unitChar:= SYSTEM.VAL(SET,value);
			|SBP2DeviceTypeAndLUNKey: NEW(dev); (* KernelLog.Int(value,2); KernelLog.Ln(); *) dev.logicalUnitNumber:= SYSTEM.VAL(SET,value)*{0..15}; j:= 0;
				(* FirewireLowUtil.PrintSet(dev.logicalUnitNumber); *)
				WHILE (grp[j] # NIL) DO
					INC(j);
				END;
				ASSERT(j < 64); grp[j]:= dev; (* add this device to the grp *)
				(* Print(debug,"Found a logical unit number"); *)
			|SBP2FirmwareRevKey: firmwareRev:= value;
		ELSE
		END;
		INC(i);
	END;

	IF isLUN THEN (* scan parent to get common values *) ParseUD(grp,udPar,udPar,FALSE);
	ELSE
		IF  ~(grp[0] # NIL)  THEN (* the list is empty so we will add a defult base id *)
			NEW(dev); dev.logicalUnitNumber:= SYSTEM.VAL(SET,UninitializedLUN); grp[0]:= dev;
			(* Print(debug,"There was no logical unit number, initialize with default id"); *)
		END;

		(* update all generic data *)
		(* Print(debug,"Updating generic data"); *)
		i:= 0;
		WHILE grp[i] # NIL DO
			dev:= grp[i];
			(* Print(debug,"Writing the management agent address"); *)
			dev.mgmtAgntAddrLow:= mgmtAgntAddrLow;
			dev.mgmtAgntAddrHigh:= mgmtAgntAddrHigh;
			dev.commandSetSpecID:= commandSetSpecID;
			dev.commandSet:= commandSet;
			dev.unitChar:= unitChar;
			dev.firmwareRev:= firmwareRev;
			grp[i]:= dev;
			INC(i);
		END
	END;
END ParseUD;


PROCEDURE Print(debug: BOOLEAN; string: ARRAY OF CHAR);
BEGIN
	IF debug THEN KernelLog.String(string); KernelLog.Ln() END;
END Print;

(** Test procedure *)
PROCEDURE TestTransfer*;
VAR diskres,ofs,i: LONGINT; data: ARRAY 1024 OF CHAR; dev: Sbp2Dev;grp: SbpDevGrp;
	tempSet: SET;
BEGIN
	ofs:= 0;
	grp:= sbpDevGrps[0];
	dev:= grp[0];

	(* dev.GetSize(size,diskres);  *)

	FOR i:= 0 TO 3 DO
		data[i]:= SYSTEM.VAL(CHAR,{});
	END;

	Print(debug,"Reading from medium");
	dev.Transfer(Disks.Read,900,2,data,ofs,diskres); tempSet:= {};
	FOR i:= 0 TO 3 DO
		tempSet:= tempSet + LSH(SYSTEM.VAL(SET,data[i]),-(i*8));
	END;
	FirewireLowUtil.PrintSet(tempSet);
	(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(data))));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(data)+512)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(data)+1024))); *)


	FOR i:= 0 TO 3 DO
		data[i]:= SYSTEM.VAL(CHAR,{0});
	END;
	(* SYSTEM.PUT32(ADDRESSOF(data),SYSTEM.VAL(LONGINT,{0,3,6,9,12,15,18,21,24,27,30}));
	SYSTEM.PUT32(ADDRESSOF(data)+512,SYSTEM.VAL(LONGINT,{1,11}));
	SYSTEM.PUT32(ADDRESSOF(data)+1024,SYSTEM.VAL(LONGINT,{1,2,3,4,5})); *)
	Print(debug,"Writing to medium");
	dev.Transfer(Disks.Write,900,2,data,ofs,diskres);


	FOR i:= 0 TO 3 DO
		data[i]:= SYSTEM.VAL(CHAR,{});
	END;

	Print(debug,"Reading from medium");
	dev.Transfer(Disks.Read,900,2,data,ofs,diskres);
	FOR i:= 0 TO 3 DO
		tempSet:= tempSet + LSH(SYSTEM.VAL(SET,data[i]),-(i*8));
	END;
	FirewireLowUtil.PrintSet(tempSet);
	(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(data))));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(data)+512)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(data)+1024))); *)
END TestTransfer;

(* PROCEDURE TestHandle*(par:ANY):ANY;
VAR msg: Disks.GetGeometryMsg; diskres: LONGINT; dev: Sbp2Dev;grp: SbpDevGrp;
BEGIN
	grp:= sbpDevGrps[0];
	dev:= grp[0];
	dev.Handle(msg,diskres);
	RETURN NIL
END TestHandle; *)

(*
PROCEDURE Transfer*(op,block,num: LONGINT; VAR data: ARRAY OF CHAR; ofs: LONGINT; VAR diskres: LONGINT);
VAR i,addr: LONGINT; command: Command; dev: Sbp2Dev; grp: SbpDevGrp; statusHi: SET;
BEGIN
	grp:= sbpDevGrps[0];
	dev:= grp[0];
	command.bufferAddr:= SYSTEM.VAL(SET,ADDRESSOF(data));
	command.bufferLen:= blockSize;

	FOR i:= 0 TO 11 DO command.cdb[i]:= CHR(0) END;

	IF (op = Disks.Read) OR (op = Disks.Write) THEN

		IF op = Disks.Read THEN
			command.cdb[0]:= 28X; command.dataDirection:= DataRead
		ELSE
			command.cdb[0]:= 2AX; command.dataDirection:= DataWrite
		END;

		i:= 0;
		WHILE num > 0 DO
			command.bufferAddr:= SYSTEM.VAL(SET,ADDRESSOF(data)+i*blockSize);
			command.cdb[2]:= CHR(LSH(block,-24));
			command.cdb[3]:= CHR(LSH(block,-16));
			command.cdb[4]:= CHR(LSH(block,-8));
			command.cdb[5]:= CHR(block);
			command.cdb[7]:= CHR(LSH(num,-8));
			command.cdb[8]:= CHR(num);
			IF ~SendCommand(dev, command, diskres) THEN RETURN END;
			IF diskres # Disks.Ok THEN RETURN END;
			INC(block);DEC(num);INC(i);
		END
	ELSE
		diskres:= Disks.Unsupported;
	END;

	grp[0]:= dev;
	sbpDevGrps[0]:= grp;

	(* SYSTEM.PUT32(ADDRESSOF(data),SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)));

		(* check the status *)
	addr:= SYSTEM.VAL(LONGINT,dev.statusBlock.bufAddr);
	statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
	WHILE statusHi = {} DO
		statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));

	END;
	FirewireLowUtil.PrintSet(statusHi);
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+4)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+8)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+12)));
	IF ({28,29}*statusHi # {}) OR (27 IN statusHi) OR ({16..23}* statusHi # {}) THEN
		KernelLog.String("There was an error sending the command!"); KernelLog.Ln();
	ELSE Print(debug,"There was no error sending the command!");
	END; *)
	(*
	IF op = Disks.Read THEN
		(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)))); *)
		SYSTEM.PUT32(ADDRESSOF(data),SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)));
		InvertByteOrder(ADDRESSOF(data),4);
	END; *)
END Transfer;

PROCEDURE GetSize*(VAR size: LONGINT;diskres: LONGINT);
VAR command: Command; data : ARRAY 8 OF CHAR; i: LONGINT; dev: Sbp2Dev; grp: SbpDevGrp;
BEGIN
	grp:= sbpDevGrps[0];
	dev:= grp[0];
	(* blockSize := 0; size := 0; *)

	command.bufferAddr:= AllocBuf(1024);

	(* FirewireLowUtil.PrintSet(dev.mgmtAgntAddrLow);
	KernelLog.Int(dev.maxPayload,2); KernelLog.Ln(); *)

	(* command.bufferAddr:= SYSTEM.VAL(SET,ADDRESSOF(data)); *)
	command.bufferLen:= 1024;
	command.dataDirection:= DataRead;

	(* UFI: Read Capacity command *)
	FOR i:= 0 TO 11 DO command.cdb[i] := CHR(0); END;
	command.cdb[0] := 25X;

	IF ~SendCommand(dev,command,diskres) THEN END;
	IF (diskres # Disks.Ok) THEN RETURN; END;

	(* data[0]:= CHR(2);
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(ADDRESSOF(data)))); *)

	(* FOR i := 0 TO 3 DO
		size := size*100H + SYSTEM.GET8(SYSTEM.VAL(LONGINT,command.bufferAddr)+i);
		blockSize := blockSize*100H + SYSTEM.GET8(SYSTEM.VAL(LONGINT,command.bufferAddr)+4+i);
	END; *)
	size:= SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr));
	blockSize:= SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)+4);

	INC (size);

	diskres := Disks.Ok;

	KernelLog.String("UsbStorage: Disk info: Blocks: "); KernelLog.Int(size, 0);
	KernelLog.String(" blocksize: "); KernelLog.Int(blockSize,0);
	KernelLog.String(" size: "); KernelLog.Int(size*blockSize,0);
	KernelLog.String(" size in giga: "); KernelLog.Int(((size DIV 1024)*(blockSize)) DIV (1024*1024),0);
	KernelLog.Ln;

	grp[0]:= dev;
	sbpDevGrps[0]:= grp;

END GetSize;

PROCEDURE TestSendCommand*(par:ANY):ANY;
VAR buffer,bufferAnsw: ARRAY 1024 OF CHAR; command: Command; grp: SbpDevGrp; dev: Sbp2Dev; statusHi: SET;
	addr,i,diskres,size: LONGINT;
BEGIN
	(* check size
	Print(debug,"Checking the size");
	GetSize(size,diskres);
	KernelLog.Int(diskres,2); *)
	grp:= sbpDevGrps[0];
	dev:= grp[0];

	(* FirewireLowUtil.PrintSet(dev.mgmtAgntAddrLow);
	KernelLog.Int(dev.maxPayload,2); KernelLog.Ln(); *)

	Print(debug,"Writing to medium");
	command.bufferLen:= 1024;
	command.bufferAddr:= SYSTEM.VAL(SET,ADDRESSOF(buffer));
	SYSTEM.PUT32(SYSTEM.VAL(LONGINT,command.bufferAddr),SYSTEM.VAL(LONGINT,{0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}));
	command.dataDirection:= DataWrite;
	FOR i:= 0 TO 2 DO
		SYSTEM.PUT32(ADDRESSOF(command.cdb)+i*4,0);
	END;
	command.cdb[0]:= 2AX; (* write *)
	command.cdb[1]:= CHR(SYSTEM.VAL(LONGINT,{5}));
	command.cdb[2]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH(SYSTEM.VAL(SET,260),-24)));
	command.cdb[3]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH(SYSTEM.VAL(SET,260),-16)));
	command.cdb[4]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH(SYSTEM.VAL(SET,260),-8)));
	command.cdb[5]:= CHR(SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,260)*{0..7}));
	command.cdb[7]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH({6},-8)));
	command.cdb[8]:= CHR(SYSTEM.VAL(LONGINT,{6}*{0..7}));
	IF ~SendCommand(dev, command,diskres) THEN Print(debug,"Send command failed") END;

	(* check the status *)
	addr:= SYSTEM.VAL(LONGINT,dev.statusBlock.bufAddr);
	statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
	WHILE statusHi = {} DO
		statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
		(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)))); *)
	END;
	FirewireLowUtil.PrintSet(statusHi);
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+4)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+8)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+12)));
	IF ({28,29}*statusHi # {}) OR (27 IN statusHi) OR ({16..23}* statusHi # {}) THEN
		KernelLog.String("There was an error sending the command!"); KernelLog.Ln();
	ELSE Print(debug,"There was no error sending the command!");
	END;

	Print(debug,"Reading from medium");

	command.bufferLen:= 1024;
	command.bufferAddr:= SYSTEM.VAL(SET,ADDRESSOF(bufferAnsw));
	(* SYSTEM.PUT32(command.bufferAddr,SYSTEM.VAL(LONGINT,{0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30})); *)
	command.dataDirection:= DataRead;
	FOR i:= 0 TO 2 DO
		SYSTEM.PUT32(ADDRESSOF(command.cdb)+i*4,0);
	END;
	command.cdb[0]:= 28X; (* read *)
	command.cdb[1]:= CHR(SYSTEM.VAL(LONGINT,{5}));
	command.cdb[2]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH(SYSTEM.VAL(SET,245),-24)));
	command.cdb[3]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH(SYSTEM.VAL(SET,245),-16)));
	command.cdb[4]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH(SYSTEM.VAL(SET,245),-8)));
	command.cdb[5]:= CHR(SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,245)*{0..7}));
	command.cdb[7]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH({5},-8)));
	command.cdb[8]:= CHR(SYSTEM.VAL(LONGINT,{5}*{0..7}));
	IF ~SendCommand(dev, command,diskres) THEN Print(debug,"Send command failed") END;

	(* check the status *)
	addr:= SYSTEM.VAL(LONGINT,dev.statusBlock.bufAddr);
	statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
	WHILE statusHi = {} DO
		statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
		(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)))); *)
	END;
	FirewireLowUtil.PrintSet(statusHi);
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+4)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+8)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+12)));
	IF ({28,29}*statusHi # {}) OR (27 IN statusHi) OR ({16..23}* statusHi # {}) THEN
		KernelLog.String("There was an error sending the command!"); KernelLog.Ln();
	ELSE Print(debug,"There was no error sending the command!");
	END;

	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr))));

	Print(debug,"Reading from medium");

	command.bufferLen:= 1024;
	command.bufferAddr:= SYSTEM.VAL(SET,ADDRESSOF(bufferAnsw));
	(* SYSTEM.PUT32(command.bufferAddr,SYSTEM.VAL(LONGINT,{0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30})); *)
	command.dataDirection:= DataRead;
	FOR i:= 0 TO 2 DO
		SYSTEM.PUT32(ADDRESSOF(command.cdb)+i*4,0);
	END;
	command.cdb[0]:= 28X; (* read *)
	command.cdb[1]:= CHR(SYSTEM.VAL(LONGINT,{5}));
	command.cdb[2]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH(SYSTEM.VAL(SET,260),-24)));
	command.cdb[3]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH(SYSTEM.VAL(SET,260),-16)));
	command.cdb[4]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH(SYSTEM.VAL(SET,260),-8)));
	command.cdb[5]:= CHR(SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,260)*{0..7}));
	command.cdb[7]:= CHR(SYSTEM.VAL(LONGINT,{0..7}*LSH({5},-8)));
	command.cdb[8]:= CHR(SYSTEM.VAL(LONGINT,{5}*{0..7}));
	IF ~SendCommand(dev, command,diskres) THEN Print(debug,"Send command failed") END;

	(* check the status *)
	addr:= SYSTEM.VAL(LONGINT,dev.statusBlock.bufAddr);
	statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
	WHILE statusHi = {} DO
		statusHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr));
		(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr)))); *)
	END;
	FirewireLowUtil.PrintSet(statusHi);
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+4)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+8)));
	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(addr+12)));
	IF ({28,29}*statusHi # {}) OR (27 IN statusHi) OR ({16..23}* statusHi # {}) THEN
		KernelLog.String("There was an error sending the command!"); KernelLog.Ln();
	ELSE Print(debug,"There was no error sending the command!");
	END;

	FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,command.bufferAddr))));

	RETURN NIL;
END TestSendCommand;
*)

PROCEDURE Cleanup;
BEGIN
	RemoveAllStorageDevices();
	(* Print(debug,"All storage devices removed"); *)
END Cleanup;

BEGIN
	debug:= TRUE;
	Modules.InstallTermHandler(Cleanup);
END FirewireSBP2.
