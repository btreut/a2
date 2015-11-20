MODULE FirewireLow; (** AUTHOR "VIP"; PURPOSE "IEEE 1394 Generic Driver"; *)

IMPORT SYSTEM, KernelLog, Machine, PCI, Objects, Modules, FirewireLowUtil, Kernel, Strings;

CONST
	MaxSelfIDErrors= 16;
	busNumber= {6..15};
	LinkEnable = 17;
	LPS = 19;
	masterIntEnable = 31;
	reqTxComplete = 0;
	respTxComplete = 1;
	ARRQ = 2;
	ARRS = 3;
	RQPkt = 4;
	RSPkt = 5;
	isochTx = 6;
	isochRx = 7;
	postedWriteErr = 8;
	lockRespErr = 9;
	selfIDComplete2 = 15;
	selfIDComplete = 16;
	busReset = 17;
	regAccessFail = 18;
	phy = 19;
	cycleSynch = 20;
	cycle64Seconds = 21;
	cycleLost = 22;
	cycleInconsistent = 23;
	unrecoverableError = 24;
	cycleTooLong = 25;
	phyRegRcvd = 26;
	ackTardy = 27;
	softInterrupt = 29;
	rcvSelfID = 9;


TYPE
	OHCIPacket = FirewireLowUtil.OHCIPacket;
	Contest = FirewireLowUtil.Contest;
	ListMember= FirewireLowUtil.ListMember;

	Controller= OBJECT
		VAR
			base,irq:LONGINT; OHCI*: FirewireLowUtil.OHCIDesc; t: Kernel.Timer; timer: Kernel.MilliTimer;
			timeout: BOOLEAN; clock: Objects.Timer;

		(** Is used to handle an await timeout *)
		PROCEDURE HandleTimeout;
		VAR ms: LONGINT;
		BEGIN {EXCLUSIVE}
			ms:= Kernel.Left(timer);
			IF ms <= 0 THEN
				timeout := TRUE;
			ELSE
				(* KernelLog.Enter; KernelLog.String("Timer early "); KernelLog.Int(ms, 1); KernelLog.Exit; *)
				Objects.SetTimeout(clock, SELF.HandleTimeout, ms)
			END
		END HandleTimeout;

		(** Allocates the receive buffer for the SelfID DMA context *)
		PROCEDURE SelfIDAlloc;
		VAR buffer: FirewireLowUtil.CharBuffer; adr: LONGINT; s: SET;
		BEGIN
			(* KernelLog.String("Entering ConfigSelfID"); *)
			KernelLog.Ln();
			(* Allocating 10K buffer , although I just need 8192 *)
			NEW(buffer,10240);
			(* find a 2K aligned address *)
			adr := ADDRESSOF(buffer[0]);
			DEC(adr,adr MOD 2048);
		  	INC(adr,2048);
		  	s := SYSTEM.VAL(SET,adr);
		  	(* setting the buffer address *)
		   	OHCI.SelfIDBufferAdr:= s;
		   	OHCI.ptrToSelfIDBuf:= buffer;
		   	(* Setting the max selfid retries *)
		   	OHCI.SelfIDErrors:= 0;
		  	(* KernelLog.String("Printing the buffer address"); KernelLog.Ln();
		  	FirewireLowUtil.PrintSet(s);
		  	KernelLog.String("Leaving ConfigSelfID"); *)
		   	KernelLog.Ln();
		END SelfIDAlloc;

		(** Reads a quadlet and returns the content as a set *)
		PROCEDURE ReadSetQuadlet(address:LONGINT):SET;
		BEGIN
			RETURN SYSTEM.VAL(SET, SYSTEM.GET32(address));
		END ReadSetQuadlet;

		(** Checks the selfID packet stream: checks if the generation counter corresponds to the actual one and also checks the integrity of the packets *)
		PROCEDURE CheckSelfIDStream():BOOLEAN;
		CONST offsetSize = 2; selfIDError= 31; selfIDSizeMask = {0..8};
		VAR selfIDSize, address, reg: SET; size: LONGINT; error: BOOLEAN;
		BEGIN
			(* KernelLog.String("Entering CheckSelfIDStream"); KernelLog.Ln(); *)
			error:= FALSE;
			address := OHCI.SelfIDBufferAdr;
			reg := FirewireLowUtil.ReadReg(FirewireLowUtil.SelfIDCount);
			(* Mask the size field *)
			selfIDSize := LSH(reg,-2);
			selfIDSize := selfIDSize*selfIDSizeMask;
			size := ConvertToLongint(selfIDSize);
			(* KernelLog.String("There are "); KernelLog.Int(size,2); KernelLog.String(" quadlets in the self id buffer."); KernelLog.Ln(); *)
			(* compare the selfIDGeneration field of the whole stream if there are errors do a bus reset *)
			IF CompareSelfIDGen(address,size) OR (selfIDError IN reg) THEN error:= TRUE;
				IF OHCI.SelfIDErrors < MaxSelfIDErrors THEN INC(OHCI.SelfIDErrors);
				KernelLog.String("There was an error checking the self id stream"); KernelLog.Ln();
				ELSE KernelLog.String("Too much errors in self id process, giving up"); KernelLog.Ln();
				END
			END;
			IF ~error THEN
				(* Reset selfID error counter *)
				OHCI.SelfIDErrors:= 0;
				(* Now Check the integrity *)
				IF CheckIntegrity(address,size) THEN error:= TRUE;
					KernelLog.String("There was an error checking the integrity of the self id stream"); KernelLog.Ln()
				END
			END;
			(* KernelLog.String("Leaving CheckSelfIDStream"); KernelLog.Ln(); *)
			RETURN error
		END CheckSelfIDStream;

		(** Prints the content of a buffer as a set *)
		PROCEDURE PrintBuffer(address: SET; size: LONGINT);
		VAR i, j, adr: LONGINT;
		BEGIN
			i:= 0;
			j:= 0;
			adr:= ConvertToLongint(address);
			WHILE i < size DO FirewireLowUtil.PrintSet(SYSTEM.VAL(SET, SYSTEM.GET32(adr+j)));
				INC(j,4); INC(i);
			END
		END PrintBuffer;

		(** Checks the integrity of selfID packets *)
		PROCEDURE CheckIntegrity(address: SET; size:LONGINT):BOOLEAN;
		VAR i: LONGINT;data, invData : SET; error: BOOLEAN; j: LONGINT;
		BEGIN
			(* KernelLog.String("Entering CheckIntegrity"); KernelLog.Ln(); *)
			error:= FALSE;
			j := 4; (* First bit holds status information, do not check *)
			i := 1;
			(* PrintBuffer(address,size); *)
			WHILE i < size DO
				data := SYSTEM.VAL(SET, SYSTEM.GET32(ConvertToLongint(address)+j)); INC(j,4);
				invData:= SYSTEM.VAL(SET, SYSTEM.GET32(ConvertToLongint(address)+j));
				IF  ~(({0..31}-data) = invData) THEN
					KernelLog.String("Integrity is broken"); KernelLog.Ln(); error:= TRUE; i:= size;
				ELSE (* KernelLog.String("Integrity check was successfull"); KernelLog.Ln() *)
				END;
				INC(j,4);
				INC(i,2);
			END;
			(* KernelLog.String("Leaving CheckIntegrity"); KernelLog.Ln(); *)
			RETURN error
		END CheckIntegrity;

		(** Compares the generation field of selfID packets with the generation counter of the system to see if they correspond *)
		PROCEDURE CompareSelfIDGen(address:SET; size:LONGINT):BOOLEAN;
		CONST selfIDGenMask = {16..23}; offsetGen = 16;
		VAR header, selfIDGeneration: SET; i: LONGINT; error: BOOLEAN;
		BEGIN
			(* KernelLog.String("Entering Procedure CompareSelfIDGen"); KernelLog.Ln(); *)
			(* Read the header of the first SelfID packet *)
			error:= FALSE;
			header := SYSTEM.VAL(SET,SYSTEM.GET32(ConvertToLongint(address)));
			(* Mask the selfIDGeneration field *)
			selfIDGeneration := header*selfIDGenMask;
			(* check if selfIDGen field is the  same as in selfIDCountRegister *)
			i:= 0;
			header := ReadSetQuadlet(ConvertToLongint(address));
			header := header*selfIDGenMask;
			IF ~(header = selfIDGeneration) THEN
				KernelLog.String("selfIDGeneration mismatch");KernelLog.Ln(); error:= TRUE
			END;
			(* KernelLog.String("Leaving compare SelfIDGen "); KernelLog.Ln(); *)
			RETURN error;
		END CompareSelfIDGen;

		(** Converts a SET to a LONGINT *)
		PROCEDURE ConvertToLongint(reg: SET):LONGINT;
		BEGIN
			RETURN SYSTEM.VAL(LONGINT,reg);
		END ConvertToLongint;

		(** Processes sent packets *)
		PROCEDURE ProcSentPckts(contest: Contest) ;
		VAR packet: OHCIPacket; status: SET; ack,dataSize: LONGINT; block: FirewireLowUtil.Block;
		CONST acks= 4; code= {0..4};
		BEGIN
			(* KernelLog.String("Processing sent packets!"); KernelLog.Ln(); *)
			WHILE ~contest.listInserted.GetPacket(packet) DO
				dataSize:= packet.dataSize;
				block:= packet.block;
				IF (dataSize > 0) & (packet.type # FirewireLowUtil.raw) THEN
					status:= LSH(SYSTEM.VAL(SET, SYSTEM.GET32(block.end + 12)),-16)
				ELSE status:= LSH(SYSTEM.VAL(SET, SYSTEM.GET32(block.start + 12)),-16)
				END;

				(* KernelLog.String("Printing the status: "); FirewireLowUtil.PrintSet(status); KernelLog.Ln(); *)

				(* check if it's an ack *)
				IF (acks IN status) THEN ack:= SYSTEM.VAL(LONGINT,status*code);
					(* KernelLog.String("It's an ack!"); KernelLog.Ln(); *)
				ELSE (* it's an event code *)
					KernelLog.String("It's an event code!"); KernelLog.Ln();
					CASE (ConvertToLongint(status*code)) OF
						FirewireLowUtil.EvtNoStatus: KernelLog.String("No event status!"); KernelLog.Ln()
						| FirewireLowUtil.EvtLongPacket: ack:= FirewireLowUtil.AckError;
							KernelLog.String("The received data length was greater than the buffer's data length!");KernelLog.Ln()
						| FirewireLowUtil.EvtMissingAck: ack:= FirewireLowUtil.AckError;
							KernelLog.String("A subaction gap was detected before an ack arrived or the received ack had a parity error!");
							KernelLog.Ln()
						| FirewireLowUtil.EvtUnderrun: ack:= FirewireLowUtil.AckError;
							KernelLog.String("Underrun on the corresponding FIFO. The packet was truncated!"); KernelLog.Ln()
						| FirewireLowUtil.EvtOverrun: ack:= FirewireLowUtil.AckError;
							KernelLog.String("A receive FIFO overflowed during the reception of an isochronous packet!"); KernelLog.Ln()
						| FirewireLowUtil.EvtDescriptorRead: ack:= FirewireLowUtil.AckError;
							KernelLog.String("An unrecoverable error occurred while the Host Controller was reading a descriptor block!");
							KernelLog.Ln()
						| FirewireLowUtil.EvtDataRead: ack:= FirewireLowUtil.AckError;
							KernelLog.String("An error occurred while the Host Controller was attempting to"); KernelLog.Ln();
							KernelLog.String(" read from host memory in the data stage of descriptor processing!"); KernelLog.Ln();
						| FirewireLowUtil.EvtDataWrite: ack:= FirewireLowUtil.AckError;
							KernelLog.String("An error occurred while the Host Controller was attempting to "); KernelLog.Ln();
							KernelLog.String("write to host memory in the data stage of descriptor processing "); KernelLog.Ln();
						    KernelLog.String("or when processing a single 16-bit host memory write!"); KernelLog.Ln()
						| FirewireLowUtil.EvtBusReset: ack:= FirewireLowUtil.AckError;
							KernelLog.String("This is the synthesized bus reset packet!"); KernelLog.Ln();
						| FirewireLowUtil.EvtTimeout: ack:= FirewireLowUtil.AckError;
							KernelLog.String("This asynchronous transmit response packet expired and"); KernelLog.Ln();
							KernelLog.String(" was not transmitted or an IT DMA context experienced "); KernelLog.Ln();
							KernelLog.String("a skip processing overflow!"); KernelLog.Ln();
						| FirewireLowUtil.EvtTcodeErr: ack:= FirewireLowUtil.AckError;
							KernelLog.String("This packet has a bad event code!"); KernelLog.Ln()
						| FirewireLowUtil.EvtUnknown: ack:= FirewireLowUtil.AckError;
							KernelLog.String("Unknown error condition!"); KernelLog.Ln();
						| FirewireLowUtil.EvtFlushed: ack:= FirewireLowUtil.AckError;
							KernelLog.String("This packet was flushed due to a bus reset!"); KernelLog.Ln();
					ELSE KernelLog.String("Unhandled or reserved event!"); KernelLog.Ln()
					END;

					RETURN
				END;
				 PacketSent(contest,packet,FirewireLowUtil.ConvertToSet(ack));
				(* This should never happen, is already checked by while *)
				ASSERT(~contest.listInserted.DelPacket(packet));
			END;

			IF FillFifo(contest) THEN
				KernelLog.String("There was an error in FIllFifo"); KernelLog.Ln()
			END;

			(* KernelLog.String("Leaving process sent packets!"); KernelLog.Ln(); *)

		END ProcSentPckts;

		(** Processes dma receive buffers *)
		PROCEDURE ProcRcvdPckts(context: Contest);
		VAR block: FirewireLowUtil.Block; i, bufSize, packetSize, resCount,packetBytesLeft, packetBytesRight: LONGINT;
			bufferAddr, tCode,ack: SET; packetAddr,nextDesc: LONGINT; complete: BOOLEAN;
		BEGIN
			(* KernelLog.String("Entering ProcRcvdPckts"); KernelLog.Ln(); *)
			bufSize:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(ConvertToLongint(context.prgr.curDesc)))*{0..15});
			resCount:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(ConvertToLongint(context.prgr.curDesc) + 12))*{0..15});
			packetSize:= FirewireLowUtil.PacketLength(context);
			bufferAddr:= SYSTEM.VAL(SET,SYSTEM.GET32(ConvertToLongint(context.prgr.curDesc) + 4));

			packetAddr:= ConvertToLongint(bufferAddr) + context.prgr.packetOffset;
			tCode:= SYSTEM.VAL(SET,LSH(SYSTEM.GET32(packetAddr),-4)) * {0..3};

			ASSERT(packetAddr > 0);

			(* dump packet
			i:=0;
			KernelLog.String("Dumping packet:"); KernelLog.Ln();
			WHILE i< packetSize DO
				quad:= SYSTEM.VAL(SET,SYSTEM.GET32(packetAddr +i));
				FirewireLowUtil.PrintSet(quad); INC(i,4);
			END; *)

			IF packetSize < 4 THEN (* Something is wrong, there must be an error *)
				KernelLog.String("The packet size is wrong::procRcvdPckts"); KernelLog.Ln();
				FirewireLowUtil.StopContext(context.ctrlClear);
				RETURN
			END;


			(* The first case handles packets that cross more than one buffer *)
			IF (context.prgr.packetOffset + packetSize) > bufSize THEN
				(* KernelLog.String("First case!"); KernelLog.Ln(); *)
				(* reassemble split packet in a new buffer and free the last one *)
				packetBytesLeft:= bufSize - context.prgr.packetOffset; i:= 0;
				ASSERT(packetBytesLeft <= FirewireLowUtil.BufSize);
				WHILE i < packetBytesLeft-1 DO
					SYSTEM.PUT32(ConvertToLongint(context.tempBuffer[0])+i,SYSTEM.GET32(packetAddr + i));
					INC(i,4)
				END;
				(* free this descriptor and its buffer to be reused *)
				block.end:= ConvertToLongint(context.prgr.curDesc);
				(* now go to next buffer/descriptor *)
				nextDesc:= SYSTEM.GET32(ConvertToLongint(context.prgr.curDesc) + 8)-1; (* -1 to eliminate the z *)
				ASSERT(nextDesc > 0);
				bufSize:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(nextDesc))*{0..15});
				resCount:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(nextDesc + 12))*{0..15});
				packetBytesRight:= bufSize - resCount; i:= 0;
				ASSERT(packetAddr > 0);
				ASSERT(packetBytesRight <= FirewireLowUtil.BufSize-packetBytesLeft);
				WHILE i < packetBytesRight-1 DO
					SYSTEM.PUT32(ConvertToLongint(context.tempBuffer[0])+packetBytesLeft+i,SYSTEM.GET32(packetAddr + i));
					INC(i,4)
				END;
				context.prgr.curDesc:= SYSTEM.VAL(SET,nextDesc);
				ASSERT(ConvertToLongint(context.prgr.curDesc) > 0);
				block.start:= ConvertToLongint(context.prgr.curDesc);
				context.prgr.packetOffset:= bufSize-resCount;
				(* ok, we finished copying the packet into a safe place *)
			ELSE (* The packet is all in one buffer *)
				(* KernelLog.String("Second case"); KernelLog.Ln(); *)
				packetBytesLeft:= bufSize - context.prgr.packetOffset; i:= 0;
				ASSERT(packetBytesLeft <= FirewireLowUtil.BufSize);
				WHILE i < packetBytesLeft-1 DO
					SYSTEM.PUT32(ConvertToLongint(context.tempBuffer[0])+i,SYSTEM.GET32(packetAddr + i));
					INC(i,4)
				END;
				IF resCount = 0 THEN
					(* free this descriptor and its buffer to be reused *)
					block.end:= ConvertToLongint(context.prgr.curDesc);
					nextDesc:= SYSTEM.GET32(ConvertToLongint(context.prgr.curDesc) + 8)-1;
					context.prgr.curDesc:= SYSTEM.VAL(SET,nextDesc);
					ASSERT(ConvertToLongint(context.prgr.curDesc) > 0);
					block.start:= ConvertToLongint(context.prgr.curDesc);
				END;
				context.prgr.packetOffset:= bufSize-resCount;
			END;

			IF (SYSTEM.VAL(LONGINT,tCode) = 	FirewireLowUtil.PhyARReq) THEN
				(* We always get this packet after bus reset, just throw it away *)
				(* i:=0;
				KernelLog.String("Dumping packet:"); KernelLog.Ln();
				WHILE i< packetSize DO
					quad:= SYSTEM.VAL(SET,SYSTEM.GET32(packetAddr +i));
					IF i= 12 THEN quad:= quad*{8..31}; KernelLog.Int(SYSTEM.VAL(LONGINT,LSH(quad,-8)),2);
						KernelLog.Ln()
					END;
					FirewireLowUtil.PrintSet(quad); INC(i,4);
				END;
				KernelLog.String("Discarding phy packet::ProcRcvdPckts"); KernelLog.Ln(); *)
			ELSE
				(* find out if we got an ack complete acknowledgement *)
				ack:= FirewireLowUtil.ReadReg(context.ctrlSet) * {0..4};
				IF ConvertToLongint(ack) = FirewireLowUtil.AckComplete THEN complete:= TRUE
				ELSE complete:= FALSE
				END;

				(* dump packet
				i:=0;
				KernelLog.String("Dumping packet:"); KernelLog.Ln();
				WHILE i< packetSize DO
					quad:= SYSTEM.VAL(SET,SYSTEM.GET32(packetAddr +i));
					IF i= 12 THEN quad:= quad*{8..31}; KernelLog.Int(SYSTEM.VAL(LONGINT,LSH(quad,-8)),2);
						KernelLog.Ln()
					END;
					FirewireLowUtil.PrintSet(quad); INC(i,4);
				END; *)

				PacketReceived(context,context.tempBuffer[0], packetSize, complete);
			END;
			(* KernelLog.String("Leaving ProcRcvdPckts"); KernelLog.Ln(); *)
		END ProcRcvdPckts;

		(** Frees unused DMA buffers of receive contexts *)
		PROCEDURE FreeDMABuffer(context:Contest);
		VAR curDesc: LONGINT; active: LONGINT;
		BEGIN
			active:= 10;
			curDesc:= ConvertToLongint(context.prgr.curDesc);
			ASSERT(ConvertToLongint(context.prgr.curDesc) > 0);
			context.prgr.SetBranchAddress(curDesc+1,curDesc+8,context.prgr.ptrToBuf);

			context.buffers.FreeBuffer(SYSTEM.VAL(SET,SYSTEM.GET32(curDesc + 4)));

			(* wake up the context if necessary *)
			IF ~(active IN FirewireLowUtil.ReadReg(context.ctrlSet)) THEN
				(* KernelLog.String("Waking context "); KernelLog.String(context.name); KernelLog.String("!"); KernelLog.Ln() *)
			END;

			(* Always wake it up, to avoid race conditions *)
			FirewireLowUtil.WriteReg(context.ctrlSet,{12});
		END FreeDMABuffer;

		(** Checks the transaction code of a received packet to see if its a response or request packet *)
		PROCEDURE PacketReceived(context: Contest; bufferAddr:SET; packetSize: LONGINT; complete: BOOLEAN);
		VAR tCode: LONGINT;
		BEGIN
			(* KernelLog.String("Entering Packet received"); KernelLog.Ln(); *)
			IF OHCI.inBusReset THEN KernelLog.String("Ignoring packet, because OHCI is in bus reset!"); RETURN END;

			(* get tCode *)
			tCode:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,LSH(SYSTEM.GET32(ConvertToLongint(bufferAddr)),-4))*{0..3});

			(* KernelLog.String("The transaction code is: ");KernelLog.Int(tCode,2); KernelLog.Ln(); *)
			CASE tCode OF
			FirewireLowUtil.NoDataWARRes: HandlePacketResponse(context,bufferAddr,packetSize,tCode)
			|FirewireLowUtil.QReadARRes: HandlePacketResponse(context,bufferAddr,packetSize,tCode)
			|FirewireLowUtil.BReadARRes: HandlePacketResponse(context,bufferAddr,packetSize,tCode)
			|FirewireLowUtil.LockARRes: HandlePacketResponse(context,bufferAddr,packetSize,tCode)

			|FirewireLowUtil.QWriteARReq: HandleIncomingPacket(bufferAddr,packetSize,tCode,complete)
			|FirewireLowUtil.BWriteARReq: HandleIncomingPacket(bufferAddr,packetSize,tCode,complete)
			|FirewireLowUtil.NoDataQRARReq: HandleIncomingPacket(bufferAddr,packetSize,tCode,complete)
			|FirewireLowUtil.BReadARReq: HandleIncomingPacket(bufferAddr,packetSize,tCode,complete)
			|FirewireLowUtil.LockARReq: HandleIncomingPacket(bufferAddr,packetSize,tCode,complete)

			|FirewireLowUtil.IRCode: KernelLog.String("Received iso packet: NOT YET IMPLEMENTED!");
				KernelLog.Ln()

			|FirewireLowUtil.CycleStartCode: (* Just ignore *) (* KernelLog.String("Cycle start packet ignored!");
				KernelLog.Ln() *)

			ELSE KernelLog.String("Received bad tCode for a packet!"); KernelLog.Ln()
			END;
			(* KernelLog.String("Leaving Packet received"); KernelLog.Ln(); *)
		END PacketReceived;

		(** Creates a reply packet to read or write requests *)
		PROCEDURE CreateReplyPacket(VAR p: FirewireLowUtil.OHCIPacket; dataAddr: LONGINT; dataSize: LONGINT);
		BEGIN
			(* KernelLog.String("Data size in CreateReaplyPacket is: "); KernelLog.Int(dataSize,2); KernelLog.Ln(); *)
			p:= OHCI.packetFIFO.GetPacket();
			p.dataSize:= dataSize;
			(* reset packet *)
			FirewireLowUtil.ResetPacket(p);

			p.type:= FirewireLowUtil.async;
			p.state:= FirewireLowUtil.UNUSED;
			p.host:= OHCI;
			p.nodeID:= SYSTEM.VAL(SET,LSH(SYSTEM.GET32(dataAddr+4),-16))*{0..5};
			p.tLabel:= SYSTEM.VAL(SET,LSH(SYSTEM.GET32(dataAddr),-10))*{0..5};
			p.generation:= FirewireLowUtil.GetGeneration();
			p.respExpected:= FALSE;
		END CreateReplyPacket;

		(** Writes packet data to a host memory address *)
		PROCEDURE WriteToAddress(dataAddr: LONGINT; dataLen: LONGINT; writeAddrLo, writeAddrHi: SET):LONGINT;
		VAR i: LONGINT;
		BEGIN
			(* KernelLog.String("WriteToAddress!"); KernelLog.Ln();
			KernelLog.String("Printing the address"); KernelLog.Ln();
			FirewireLowUtil.PrintSet(writeAddrLo);
			FirewireLowUtil.PrintSet(writeAddrHi); *)
			i:= 0;
			IF writeAddrHi*{0..15} # {} THEN
				RETURN FirewireLowUtil.respAddressError
			ELSIF ~OHCI.adrCheck.Find(ConvertToLongint(writeAddrLo)) THEN HALT(55);
			ELSE
				FOR i:= 0 TO dataLen-1 DO
					SYSTEM.PUT32(ConvertToLongint(writeAddrLo)+i*4,SYSTEM.GET32(dataAddr+i*4))
				END
			END;
			RETURN FirewireLowUtil.respComplete;
		END WriteToAddress;

		(** Reads packet data from a host memory address *)
		PROCEDURE ReadFromAddress(VAR bufferAddr: ARRAY OF SET; dataLen: LONGINT; readAddrLo, readAddrHi: SET): LONGINT;
		VAR i: LONGINT;
		BEGIN
			(* KernelLog.String("ReadFromAddress!"); KernelLog.Ln();
			KernelLog.String("Printing the address"); KernelLog.Ln();
			FirewireLowUtil.PrintSet(readAddrLo);
			FirewireLowUtil.PrintSet(readAddrHi); *)
			i:= 0;
			FOR i:= 0 TO dataLen-1 DO
				bufferAddr[i]:= SYSTEM.VAL(SET,SYSTEM.GET32(ConvertToLongint(readAddrLo)+i*4));
				(* FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(ConvertToLongint(readAddrLo)+i*4))); *)
			END;
			RETURN FirewireLowUtil.respComplete;
		END ReadFromAddress;

		(** Handles incoming requests *)
		PROCEDURE HandleIncomingPacket(bufferAddr: SET; packetSize, tCode: LONGINT; complete: BOOLEAN);
		VAR addrHi,addrLo: SET; rCode,dataLen,addr: LONGINT; packet: FirewireLowUtil.OHCIPacket; respBufferAddr: LONGINT;
			respQuadlet: ARRAY 1 OF SET;
		BEGIN
			(* KernelLog.String("Entered routine HandleIcomingPacket!"); KernelLog.Ln(); *)
			addr:= ConvertToLongint(bufferAddr);
			CASE tCode OF
			FirewireLowUtil.QWriteARReq:
				(* KernelLog.String("It's a quadlet write request!"); KernelLog.Ln(); *)
				addrLo:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+8));
				addrHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+4));
				rCode:= WriteToAddress(addr+12,1,addrLo,addrHi);
				IF ~complete THEN
					CreateReplyPacket(packet,addr,0);
					FirewireLowUtil.FillAsyncWriteResp(packet,rCode);
					IF SendPacket1394(OHCI.ATController.GetResContest(),packet) THEN
						(* KernelLog.String("Response successfully sent"); KernelLog.Ln() *)
					ELSE KernelLog.String("Response could not be sent"); KernelLog.Ln()
					END
				END
			|FirewireLowUtil.BWriteARReq:
				(* KernelLog.String("It's a block write request!"); KernelLog.Ln(); *)
				addrLo:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+8));
				addrHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+4));
				dataLen:= (LSH(SYSTEM.GET32(addr+12),-16));
				rCode:= WriteToAddress(addr+16,(dataLen DIV 4),addrLo,addrHi);
				IF ~complete THEN
					CreateReplyPacket(packet,addr,0);
					FirewireLowUtil.FillAsyncWriteResp(packet,rCode);
					IF SendPacket1394(OHCI.ATController.GetResContest(),packet) THEN
						(* KernelLog.String("Response successfully sent"); KernelLog.Ln() *)
					ELSE KernelLog.String("Response could not be sent"); KernelLog.Ln()
					END
				END
			|FirewireLowUtil.NoDataQRARReq:
				(* KernelLog.String("It's a quadlet read request!"); KernelLog.Ln(); *)
				addrLo:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+8));
				addrHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+4));
				rCode:= ReadFromAddress(respQuadlet,1,addrLo,addrHi);
				CreateReplyPacket(packet,addr,0);
				FirewireLowUtil.FillAsyncReadQuadResp(packet,rCode,respBufferAddr);
				IF SendPacket1394(OHCI.ATController.GetResContest(),packet) THEN
					(* KernelLog.String("Response successfully sent"); KernelLog.Ln() *)
				ELSE KernelLog.String("Response could not be sent"); KernelLog.Ln()
				END
			|FirewireLowUtil.BReadARReq:
				(* KernelLog.String("It's a block read request!"); KernelLog.Ln(); *)
				dataLen:= (LSH(SYSTEM.GET32(addr+12),-16));
				CreateReplyPacket(packet,addr,dataLen);
				addrLo:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+8));
				addrHi:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+4));
				rCode:= ReadFromAddress(packet.data^,(dataLen DIV 4),addrLo,addrHi);
				FirewireLowUtil.FillAsyncReadBlockResp(packet,rCode,dataLen);
				IF SendPacket1394(OHCI.ATController.GetResContest(),packet) THEN
					(* KernelLog.String("Response successfully sent"); KernelLog.Ln() *)
				ELSE KernelLog.String("Response could not be sent"); KernelLog.Ln()
				END
			|FirewireLowUtil.LockARReq:
			ELSE KernelLog.String("This request is not supported!"); KernelLog.Ln();
			END;
		END HandleIncomingPacket;

		(** Handles incoming packet responses *)
		PROCEDURE HandlePacketResponse(respContext: Contest; bufferAddr: SET; packetSize, tCode: LONGINT);
		VAR oneBack,temp: POINTER TO ListMember; tLabel, nodeID: SET; found, tCodeMatch: BOOLEAN; packet: OHCIPacket;
			data: LONGINT; i: LONGINT; context: Contest; n: FirewireLowUtil.FIFONode;
		BEGIN
			(* KernelLog.String("Entering handle packet response!"); KernelLog.Ln(); *)
			context:= OHCI.ATController.GetReqContest();
			(* Find the request packet corresponding to this response *)
			found:= FALSE;
			oneBack:= context.listAwaiting.head;
			temp:= oneBack.next;
			nodeID:= SYSTEM.VAL(SET,LSH(SYSTEM.GET32(ConvertToLongint(bufferAddr)+4),-16))*{0..5};
			tLabel:= SYSTEM.VAL(SET,LSH(SYSTEM.GET32(ConvertToLongint(bufferAddr)),-10))*{0..5};

			(* KernelLog.String("Printing the transaction label of the response packet!"); KernelLog.Ln();
			FirewireLowUtil.PrintSet(tLabel); *)

			IF ~context.listAwaiting.GetPacket(packet) THEN
				(* KernelLog.String("Printing the request packet name: "); KernelLog.String(packet.name); KernelLog.Ln();
				KernelLog.String("Printing the request packet transaction label: "); FirewireLowUtil.PrintSet(packet.tLabel); *)
			ELSE
				KernelLog.String("We have a problem"); KernelLog.Ln()
			END;

			WHILE (temp # NIL) &  ~(found) DO (*
				KernelLog.String("Comparing the transaction label"); KernelLog.Ln();
				FirewireLowUtil.PrintSet(temp.data.tLabel);
				FirewireLowUtil.PrintSet(tLabel);
				KernelLog.String("Comparing the node id"); KernelLog.Ln();
				FirewireLowUtil.PrintSet(temp.data.nodeID); FirewireLowUtil.PrintSet(nodeID); *)
				IF (temp.data.tLabel = tLabel) & (temp.data.nodeID = nodeID) THEN
					found:= TRUE; packet:= temp.data; (* KernelLog.String("name of the packet is: ");
					KernelLog.String(temp.data.name); KernelLog.Ln(); *)
				ELSE oneBack:= temp; temp:= temp.next
				END
			END;

			IF ~found THEN KernelLog.String("This packet was not expected, no tLabel match"); KernelLog.Ln();
				RETURN
			END;

			(*
			KernelLog.String("Dumping packet: "); KernelLog.Ln();
			KernelLog.String("The packet name is: "); KernelLog.String(packet.name); KernelLog.Ln();

			FOR i:= 0 TO (packet.headerSize DIV 4)-1 DO
				FirewireLowUtil.PrintSet(packet.header[i]);
			END; i:= 0;

			KernelLog.String("The transaction code is: "); KernelLog.Int(tCode,2); KernelLog.Ln();
			KernelLog.String("The packet transaction code is: "); KernelLog.Int(SYSTEM.VAL(LONGINT,packet.tCode),2); KernelLog.Ln();
			*)

			CASE SYSTEM.VAL(LONGINT,packet.tCode) OF
			FirewireLowUtil.QWriteATReq:
				IF (tCode = FirewireLowUtil.NoDataWARRes) THEN tCodeMatch:= TRUE END
			|FirewireLowUtil.BWriteATReq:
				IF (tCode = FirewireLowUtil.NoDataWARRes) THEN tCodeMatch:= TRUE END
			|FirewireLowUtil.BReadATReq:
				IF (tCode = FirewireLowUtil.BReadARRes) THEN tCodeMatch:= TRUE END
			|FirewireLowUtil.NoDataWATReq:
				IF (tCode = FirewireLowUtil.QReadARRes) THEN tCodeMatch:= TRUE END
			|FirewireLowUtil.LockATReq:
				IF (tCode = FirewireLowUtil.LockARRes) THEN tCodeMatch:= TRUE END
			END;

			IF (~tCodeMatch OR (packet.tLabel # tLabel)) OR (packet.nodeID # nodeID) THEN
				IF tCodeMatch THEN (* KernelLog.String("Transaction code matched!"); KernelLog.Ln() *)
				ELSE KernelLog.String("Transaction code didn't match: "); FirewireLowUtil.PrintSet(packet.tCode);
					FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,tCode)); KernelLog.Ln()
				END;
				KernelLog.String("This packet was not expected,  tcode mismatch!"); RETURN
			END;

			IF found THEN (* delete packet from list *)
				IF oneBack = temp THEN (* It's the first object in the list *)
					context.listAwaiting.head:= context.listAwaiting.head.next
				ELSE oneBack.next:= temp.next;
					IF context.listAwaiting.last = temp THEN
					context.listAwaiting.last:= oneBack END;
				END;
				temp.next:= NIL;
				n:= context.listAwaiting.usedList.DequeuedNode(context.listAwaiting.usedQ);
				n.pListMember:= temp;
				context.listAwaiting.list.Enqueue(context.listAwaiting.q,n);
			END;

			data:= ConvertToLongint(bufferAddr);

			CASE tCode OF
			FirewireLowUtil.NoDataWARRes:
				packet.header[0]:= SYSTEM.VAL(SET,SYSTEM.GET32(data));
				packet.header[1]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 4));
				packet.header[2]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 8));
			|FirewireLowUtil.QReadARRes:
				packet.header[0]:= SYSTEM.VAL(SET,SYSTEM.GET32(data));
				packet.header[1]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 4));
				packet.header[2]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 8));
				packet.header[3]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 12));
			|FirewireLowUtil.BReadARRes:
				packet.header[0]:= SYSTEM.VAL(SET,SYSTEM.GET32(data));
				packet.header[1]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 4));
				packet.header[2]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 8));
				packet.header[3]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 12));
				FOR i:= 0 TO ((packetSize-16) DIV 4)-1 DO
					packet.data[i]:= SYSTEM.VAL(SET,SYSTEM.GET32(data+16+i*4))
				END
			|FirewireLowUtil.LockARRes:
				packet.header[0]:= SYSTEM.VAL(SET,SYSTEM.GET32(data));
				packet.header[1]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 4));
				packet.header[2]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 8));
				packet.header[3]:= SYSTEM.VAL(SET,SYSTEM.GET32(data + 12));
				IF packetSize-16 > 8 THEN
					FOR i:= 0 TO (8 DIV 4)-1 DO
						packet.data[i]:= SYSTEM.VAL(SET,SYSTEM.GET32(data+16+i*4))
					END
				ELSE
					FOR i:= 0 TO ((packetSize-16) DIV 4)-1 DO
						packet.data[i]:= SYSTEM.VAL(SET,SYSTEM.GET32(data+16+i*4));
					END
				END
			END;

			BEGIN{EXCLUSIVE}
			packet.state:= FirewireLowUtil.COMPLETE;
			END;
			packet.pending:= FALSE;
			OHCI.labeler.FreeTransLabel(packet.tLabel);

			(* now free buffer if needed *)
			IF packet.dataSize > 0 THEN
				(* KernelLog.String("Freeing buffer!"); KernelLog.Ln(); *)
				respContext.buffers.FreeBuffer(SYSTEM.VAL(SET,SYSTEM.GET32(packet.block.start+36)))
			END;

			PacketComplete(context,packet);
			(* KernelLog.String("Leaving handle packet response!"); KernelLog.Ln(); *)
		END HandlePacketResponse;

		(** This function is unused *)
		PROCEDURE PacketComplete(context: Contest; VAR packet: OHCIPacket);
			(* This function is basically used if a custom routine has to handle the packet
			 else this packet will just return to the calling routine *)
		END PacketComplete;

		(** This function checks if the packet expects a response or finished and accordingly adds the packet to the
		response await list *)
		PROCEDURE PacketSent(context:Contest;VAR packet: OHCIPacket; ack: SET);
		BEGIN
			packet.ack:= ack;

			IF packet.respExpected & (packet.ack # {0,4}) THEN (* KernelLog.String("Packet is pending!"); KernelLog.Ln(); *)
				packet.pending:= TRUE; context.listAwaiting.AddPacket(packet) (* This list will be traversed in handlePacketResponse *)
			ELSE packet.pending:= FALSE; packet.state:= FirewireLowUtil.COMPLETE; OHCI.labeler.FreeTransLabel(packet.tLabel);
				 (* KernelLog.String("{{{{{{{{{{{{{{{{{{{{{{{{{Packet is complete}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}"); KernelLog.Ln(); *)
			END;

		END PacketSent;

		(** This is the interrupt handler *)
		PROCEDURE HandleInterrupt;
		VAR status, reg, nodeID: SET; ctx,i: LONGINT; root, error: BOOLEAN;
		CONST dead= 11; isValid= 31; id= {0..5}; isRoot= 30;
		BEGIN
			FirewireLowUtil.WriteReg(FirewireLowUtil.CIntMask,{31});
			status := FirewireLowUtil.ReadReg(FirewireLowUtil.CIntEvent);
			(* KernelLog.String("@@@@@@ Entering interrupt handler @@@@@@"); KernelLog.Ln(); *)

			IF reqTxComplete IN status THEN
				(* KernelLog.String("Completion of an AT DMA request OUTPUT-LAST* command"); KernelLog.Ln(); *)
				(* Read the status of the AT response context control register *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.ATReqContCtrlSet);
				(* KernelLog.String("Printing the status of the AT request context control register: ");
				FirewireLowUtil.PrintSet(reg); *)
				IF (dead IN reg) THEN (* KernelLog.String("Context died"); KernelLog.Ln(); *) FirewireLowUtil.StopContext(FirewireLowUtil.ATReqContCtrlClear);
				ELSE ProcSentPckts(OHCI.ATController.GetReqContest()) END;
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{reqTxComplete});
			END;

			IF respTxComplete IN status THEN
				(* KernelLog.String("Completion of an AT DMA response OUTPUT-LAST* command "); KernelLog.Ln(); *)
				(* Read the status of the AT response context control register *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.ATResContCtrlSet);
				(* KernelLog.String("Printing the status of the AT response context control register: ");
				FirewireLowUtil.PrintSet(reg); *)
				IF (dead IN reg) THEN FirewireLowUtil.StopContext(FirewireLowUtil.ATResContCtrlClear);
				ELSE ProcSentPckts(OHCI.ATController.GetResContest()) END;
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{respTxComplete});
			END;

			IF ARRQ IN status THEN
				(* KernelLog.String("Completion of an AR DMA Request context command descriptor "); KernelLog.Ln(); *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{ARRQ});
			END;

			IF ARRS IN status THEN
				(* KernelLog.String("Completion of an AR DMA Response context command descriptor  "); KernelLog.Ln(); *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{ARRS});
			END;

			IF RQPkt IN status THEN
				(* KernelLog.String("A packet was sent to an asynchronous receive request context buffer "); KernelLog.Ln();
				KernelLog.String("*****************************************************************"); KernelLog.Ln(); *)
				(* Read the status of the AT response context control register *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.ARReqContCtrlSet);
				(* KernelLog.String("Printing the status of the AR request context control register: ");
				FirewireLowUtil.PrintSet(reg); *)
				IF (dead IN reg) THEN FirewireLowUtil.StopContext(FirewireLowUtil.ARReqContCtrlClear);
				ELSE ProcRcvdPckts(OHCI.ARController.GetReqContest()) END;
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{RQPkt});
			END;

			IF RSPkt IN status THEN
				(* KernelLog.String("A packet was sent to an asynchronous receive response context buffer "); KernelLog.Ln(); *)
				(* Read the status of the AT response context control register *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.ARResContCtrlSet);
				(* KernelLog.String("Printing the status of the AR response context control register: ");
				FirewireLowUtil.PrintSet(reg); *)
				IF (dead IN reg) THEN (* KernelLog.String("Context died"); KernelLog.Ln(); *) FirewireLowUtil.StopContext(FirewireLowUtil.ARResContCtrlClear);
				ELSE ProcRcvdPckts(OHCI.ARController.GetResContest()) END;
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{RSPkt});
			END;

			IF isochTx IN status THEN
				(* KernelLog.String("One or more isochronous Transmit contexts have generated an interrupt"); KernelLog.Ln(); *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.isochXmitIntEvntSet);
				FirewireLowUtil.WriteReg(FirewireLowUtil.isochXmitIntEvntClear,reg);
				IsoSchedule(reg);
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{isochTx});
			END;

			IF isochRx IN status THEN
				(* KernelLog.String("One or more isochronous Receive contexts have generated an interrupt "); KernelLog.Ln(); *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.isochRecvIntEvntSet);
				IsoSchedule(reg);
				FirewireLowUtil.WriteReg(FirewireLowUtil.isochRecvIntEvntClear,reg);
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{isochRx});
			END;

			IF postedWriteErr IN status THEN
				KernelLog.String("A host bus error occurred"); KernelLog.Ln();
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{postedWriteErr});
			END;

			IF lockRespErr IN status THEN
				KernelLog.String("Host controller attempted to return a lock response without receiving an ack"); KernelLog.Ln();
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{lockRespErr});
			END;

			IF busReset IN status THEN
				(* Masking out the interrupt *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntMask,{busReset});
				IF ~OHCI.inBusReset THEN (* KernelLog.String("bus Reset Interrupt was thrown"); KernelLog.Ln(); *)
					OHCI.inBusReset:= TRUE;
				ELSE KernelLog.String("bus Reset Interrupt was thrown while already in progress"); KernelLog.Ln();
				END;
			END;

			IF selfIDComplete2 IN status THEN
				(* KernelLog.String("Secondary indication of the end of a selfID packet stream "); KernelLog.Ln(); *)
				(* should not be cleared *)
			END;

			IF selfIDComplete IN status THEN
				error:= FALSE;
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntMask,{selfIDComplete});
				IF OHCI.inBusReset THEN
					(* KernelLog.String("Indication of the end of a selfID packet stream "); KernelLog.Ln(); *)
					reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.NodeID);
					(* FirewireLowUtil.PrintNodeInfo(); *)
					IF isValid IN reg THEN
						(* KernelLog.String("Self id is valid, check self id buffer!"); KernelLog.Ln(); *)
						IF isRoot IN reg THEN root:= TRUE; OHCI.IsRoot:= TRUE END;
						nodeID:= reg*id;
						IF CheckSelfIDStream() THEN error:= TRUE END;
					ELSE KernelLog.String("Self id is not valid, do not check self id buffer!"); KernelLog.Ln()
					END;
					(* Clear busreset event and reenable the busreset interrupt *)
					(* KernelLog.String("Reenabling bus interrupt"); KernelLog.Ln(); *)
					FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{busReset});
					FirewireLowUtil.WriteReg(FirewireLowUtil.IntMask,{busReset});
					(* Accept physical requests from all nodes *)
					FirewireLowUtil.WriteReg(FirewireLowUtil.ARFilterHISet, {0..31});
					FirewireLowUtil.WriteReg(FirewireLowUtil.ARFilterLowSet, {0..31});
					(* Turning on physical dma reception *)
					FirewireLowUtil.WriteReg(FirewireLowUtil.PRFilterHiSet, {0..31});
					FirewireLowUtil.WriteReg(FirewireLowUtil.PRFilterLowSet, {0..31});
					FirewireLowUtil.WriteReg(FirewireLowUtil.PhyUpperBound, {16..31});
					IF OHCI.inBusReset THEN OHCI.inBusReset:= FALSE;
					ELSE KernelLog.String("This should not happen!"); KernelLog.Ln(); END;
					IF error THEN FirewireLowUtil.SetPhyControl({8},{6})
					ELSE (* Go on and build the maps *)
						OHCI.nodeID:= SYSTEM.VAL(LONGINT,FirewireLowUtil.ReadReg(FirewireLowUtil.NodeID)*{0..5});
						BuildMaps(); BEGIN {EXCLUSIVE} OHCI.selfIDComplete:= TRUE; END;
					 END;
				ELSE KernelLog.String("SelfID received outside of bus reset"); KernelLog.Ln() END;
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{selfIDComplete});
				FirewireLowUtil.WriteReg(FirewireLowUtil.IntMask,{selfIDComplete});
			END;

			IF regAccessFail IN status THEN
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntMask,{regAccessFail});
				KernelLog.String("Open HCI register access failed "); KernelLog.Ln();
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{regAccessFail});
				FirewireLowUtil.WriteReg(FirewireLowUtil.IntMask,{regAccessFail});
			END;

			IF phy IN status THEN
				KernelLog.String("phy requests an interrupt"); KernelLog.Ln();
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{phy});
			END;

			IF cycleSynch IN status THEN
				(* KernelLog.String("A new isochronous cycle has started"); KernelLog.Ln(); *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{cycleSynch});
			END;

			IF cycle64Seconds IN status THEN
				(* KernelLog.String("The 7th bit of the cycle second counter has changed "); KernelLog.Ln(); *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{cycle64Seconds});
			END;

			IF cycleLost IN status THEN
				KernelLog.String("No cyclestart packet is sent/received "); KernelLog.Ln();
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{cycleLost});
			END;

			IF cycleInconsistent IN status THEN
				(* Nothing has to be done, just clear the bit *)
				KernelLog.String("An inconsistent cycle start was received"); KernelLog.Ln();
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{cycleInconsistent});
			END;

			IF unrecoverableError IN status THEN
				KernelLog.String("Host controller encountered an unrecoverable error"); KernelLog.Ln();
				(* Asynchronous transmit request context *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.ATReqContCtrlSet);
				IF dead IN reg THEN KernelLog.String("The asynchronous transmit request context died!"); KernelLog.Ln();
				KernelLog.String("With event code: "); reg:= reg*{0..4}; FirewireLowUtil.PrintSet(reg); KernelLog.Ln();
				KernelLog.String("The register content is: "); FirewireLowUtil.StopContext(FirewireLowUtil.ATReqContCtrlClear);
				FirewireLowUtil.PrintSet(FirewireLowUtil.ReadReg(FirewireLowUtil.ATReqContCtrlSet)); KernelLog.Ln();
				 END;
					(* Asynchronous transmit response context *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.ATResContCtrlSet);
				IF dead IN reg THEN KernelLog.String("The asynchronous transmit response context died!"); KernelLog.Ln() END;
					(* Asynchronous receive request context *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.ARReqContCtrlSet);
				IF dead IN reg THEN KernelLog.String("The asynchronous receive request context died!"); KernelLog.Ln() END;
					(* Asynchronous receive response context *)
				reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.ARResContCtrlSet);
				IF dead IN reg THEN KernelLog.String("The asynchronous receive response context died!"); KernelLog.Ln() END;
					  (* Isochronous transmit context control *)
				ctx:= FirewireLowUtil.GetAvailableITCont();
				FOR i:= 0 TO ctx-1 DO
					reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.isochXmitCntCtrlSet + i*16);
					IF dead IN reg THEN KernelLog.String("The isochronous transmit context "); KernelLog.Int(i,2); KernelLog.String(" died!");
					 	KernelLog.Ln()
				    END
				END;
					  (* Isochronous receive context control *)
				ctx:= FirewireLowUtil.GetAvailableIRCont();
				FOR i:= 0 TO ctx-1 DO
					reg:= {}; reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.isochRecvCntCtrlSet + i*32);
					IF dead IN reg THEN KernelLog.String("The isochronous receive context "); KernelLog.Int(i,2); KernelLog.String(" died!");
					 	KernelLog.Ln()
				    END
				END;
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{unrecoverableError});
			END;

			IF cycleTooLong IN status THEN
				KernelLog.String("An isochronous cycle lasted longer than the allotted time"); KernelLog.Ln();
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{cycleTooLong});
			END;

			IF ackTardy IN status THEN
				KernelLog.String("HCControl.ackTardyEnable is set to one and other conditions occur"); KernelLog.Ln();
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{ackTardy});
			END;

			IF softInterrupt IN status THEN
				(* KernelLog.String("Software Interrupt"); KernelLog.Ln(); *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntMask,{softInterrupt});
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{softInterrupt});
				FirewireLowUtil.WriteReg(FirewireLowUtil.IntMask,{softInterrupt});
			END;

			IF phyRegRcvd IN status THEN
				(* KernelLog.String("OHCI has received a register data byte"); KernelLog.Ln(); *)
				(* Masking out the interrupt *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntMask,{phyRegRcvd});
				(* Clearing the interrupt *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.CIntEvent,{phyRegRcvd});
				(* Enabling the interrupt *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.IntMask,{phyRegRcvd});
			END;

			(* Enabling all interrupts *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.IntMask,{31});
			(* KernelLog.String("@@@@@@ Leaving interrupt handler @@@@@@"); KernelLog.Ln(); *)

		END HandleInterrupt;

		(**  Builds the descriptor list to send a packet over the 1394 bus *)
		PROCEDURE SendPacket(contest: Contest; VAR packet : OHCIPacket; z: LONGINT);
		VAR cycleTimer: SET; desc,descLast: FirewireLowUtil.GeneralDesc; descOMI: FirewireLowUtil.OutputMoreImmediate;
			descOL: FirewireLowUtil.OutputLast; descOLI: FirewireLowUtil.OutputLastImmediate; block: FirewireLowUtil.Block;
			branchAddressPtr: LONGINT; ptrToBuf: FirewireLowUtil.CharBuffer;
		BEGIN
			(* KernelLog.String("Sending packet to node: "); KernelLog.Int(SYSTEM.VAL(LONGINT,packet.nodeID),2); KernelLog.Ln(); *)

			desc.address := {};
			desc.branchAddress := {};

			IF contest.type = FirewireLowUtil.RES THEN
				(* KernelLog.String("Setting the timeout::SendPacket"); KernelLog.Ln(); *)
				(* I choose the maximum  time out value: 3 sec *)
				cycleTimer:= FirewireLowUtil.ReadReg(FirewireLowUtil.isochCycleTimer);
				desc.status:= LSH(cycleTimer*{12..24},-12) +
				FirewireLowUtil.ConvertToSet(LSH(LSH(ConvertToLongint(cycleTimer),-25)+3,13));
			ELSE desc.status:= {};
			END;

			IF (packet.type = FirewireLowUtil.async) OR (packet.type = FirewireLowUtil.raw) THEN
				descOMI:= FirewireLowUtil.GetAOMIDesc();
				descOL:= FirewireLowUtil.GetAOLDesc();
				descOLI:= FirewireLowUtil.GetAOLIDesc();
				(* KernelLog.String("Packet type is asynchronous or raw::SendPacket"); KernelLog.Ln(); *)
				IF packet.type = FirewireLowUtil.raw THEN
					(* KernelLog.String("Packet type is raw"); KernelLog.Ln(); *)
					desc.data[0]:= FirewireLowUtil.ConvertToSet(LSH(FirewireLowUtil.PhyATReq,4));
					desc.data[1]:= packet.header[0];
					desc.data[2]:= packet.header[1];
				ELSE (* KernelLog.String("Packet type is asynchronous"); KernelLog.Ln(); *)
					desc.data[0]:= LSH(packet.speed,16) + {23} +
					packet.header[0]*{0..15}; (* mask the first 16 bit of a packet header *)
					IF SYSTEM.VAL(LONGINT,packet.tCode) = FirewireLowUtil.StreamATReq THEN
						(* KernelLog.String("Sending an asynchronous stream packet"); KernelLog.Ln(); *)
						(* Sending an asynchronous stream packet *)
						desc.data[1]:= packet.header[0] * {16..31}; desc.data[0]:= desc.data[0] - {23}
					ELSE (* sending a normal async packet: request or response *)
						(* KernelLog.String("Sending a normal asynchronous packet"); KernelLog.Ln(); *)
						desc.data[1]:= packet.header[1] * {0..15} + packet.header[0] * {16..31};
						desc.data[2]:= packet.header[2]; desc.data[3]:= packet.header[3]
					END;
				END;

				IF packet.dataSize > 0 THEN (* block or stream transmit *)
					(* KernelLog.String("DataSize is bigger than zero: this is a block or stream transmit"); KernelLog.Ln(); *)
					IF SYSTEM.VAL(LONGINT,packet.tCode) = FirewireLowUtil.StreamATReq THEN
						(* KernelLog.String("It's a stream packet!"); KernelLog.Ln(); *)
						desc.control:= descOMI.key + {3}; (* two header quadlets for stream packets *)
					ELSE (* 4 header quadlets for block packets *)
						(* KernelLog.String("It's a block packet"); KernelLog.Ln(); *)
						desc.control:= descOMI.key + {4}
					END;
					descLast.control:= descOL.cmd + descOL.i + descOL.b +
						FirewireLowUtil.ConvertToSet(packet.dataSize);

					(* check if packet buffer crosses page boundaries *)
					(* KernelLog.String("Checking if packet crosses page size"); KernelLog.Ln(); *)
					ASSERT(packet.dataSize < FirewireLowUtil.BufSize);
					descLast.address:= FirewireLowUtil.AllocPacket(packet.data^,packet.dataSize,ADDRESSOF(OHCI.tempBuffer[0]));
					descLast.branchAddress:= {}; descLast.status:= {};
				ELSE (* quadlet or no data trasmit *)
					(* KernelLog.String("This is a quadlet or no data transmit, dataSize is zero"); KernelLog.Ln(); *)
					IF packet.type = FirewireLowUtil.raw THEN (* quadlet transmit *)
						(* KernelLog.String("This is quadlet transmit"); KernelLog.Ln(); *)
						desc.control:= descOLI.cmd + descOLI.key + descOLI.b + descOLI.i +
						FirewireLowUtil.ConvertToSet(packet.headerSize + 4)
					ELSE (* no data transmit *)
						(* KernelLog.String("This is a no data transmit"); KernelLog.Ln(); *)
						desc.control:= descOLI.cmd + descOLI.key + descOLI.b + descOLI.i +
						FirewireLowUtil.ConvertToSet(packet.headerSize)
					END
				END
			ELSE (* iso packet *)
				descOMI:= FirewireLowUtil.GetIOMIDesc();
				descOL:= FirewireLowUtil.GetIOLDesc();
				KernelLog.String("We have an iso packet"); KernelLog.Ln();
				desc.data[0]:=  packet.header[0]*{0..15} +
					LSH(packet.speed,16);
				desc.data[1]:= packet.header[0]*{16..31};
				desc.control:= descOMI.key + {3};
				descLast.control:= descOL.cmd + descOL.b + descOL.i +
					FirewireLowUtil.ConvertToSet(packet.dataSize);
				descLast.address:= FirewireLowUtil.AllocPacket(packet.data^,packet.dataSize,ADDRESSOF(OHCI.tempBuffer[0]));
				descLast.branchAddress:= {}; descLast.status:= {};
			END;

			(* write descriptor block in program buffer *)
			(* KernelLog.String("Writing descriptor block in program buffer!"); KernelLog.Ln(); *)
			block.start:= packet.blockBufferAddr;
			(* KernelLog.String("Printing the block.start address!");
			KernelLog.Int(block.start,2); KernelLog.Ln(); *) ASSERT(block.start > 0);
			(* KernelLog.String("Putting first quadlet at address: "); *)(* KernelLog.Int(block.start,2); *) (* KernelLog.Ln(); *)
			SYSTEM.PUT32(block.start, desc.control); (* FirewireLowUtil.PrintSet(desc.control); *)
			SYSTEM.PUT32(block.start + 4, desc.address); (* FirewireLowUtil.PrintSet(desc.address); *)
			(* KernelLog.String("Putting second quadlet at address: "); KernelLog.Ln(); *)
			SYSTEM.PUT32(block.start + 8, desc.branchAddress); (* FirewireLowUtil.PrintSet(desc.branchAddress); *)
			SYSTEM.PUT32(block.start + 12, desc.status); (* FirewireLowUtil.PrintSet(desc.status); *)
			(* KernelLog.String("Putting third quadlet at address: "); KernelLog.Ln(); *)
			SYSTEM.PUT32(block.start + 16, desc.data[0]); (* FirewireLowUtil.PrintSet(desc.data[0]); *)
			SYSTEM.PUT32(block.start + 20, desc.data[1]); (* FirewireLowUtil.PrintSet(desc.data[1]); *)
			(* KernelLog.String("Putting forth quadlet at address: "); KernelLog.Ln(); *)
			SYSTEM.PUT32(block.start + 24, desc.data[2]); (* FirewireLowUtil.PrintSet(desc.data[2]); *)
			SYSTEM.PUT32(block.start + 28, desc.data[3]); (* FirewireLowUtil.PrintSet(desc.data[3]); *)
			IF packet.dataSize > 0 THEN
				(* KernelLog.String("DataSize is bigger than zero");KernelLog.Ln(); *)
				SYSTEM.PUT32(block.start + 32, descLast.control); (* FirewireLowUtil.PrintSet(descLast.control); *)
				SYSTEM.PUT32(block.start + 36, descLast.address); (* FirewireLowUtil.PrintSet(descLast.address); *)
				SYSTEM.PUT32(block.start + 40, descLast.branchAddress); (* FirewireLowUtil.PrintSet(descLast.branchAddress); *)
				SYSTEM.PUT32(block.start + 44, descLast.status); (* FirewireLowUtil.PrintSet(descLast.status); *)
				(* Dump data in buffer *)
				(* KernelLog.String("Dumping the data in buffer::SendPacket"); KernelLog.Ln();
				i:= 0;
				WHILE i< (packet.dataSize-1) DO
					FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,descLast.address)+i)));INC(i,4);
				END; *)
				branchAddressPtr:= block.start + 40; block.end:= block.start + 32;
				ptrToBuf:= packet.ptrToBlckBufAddr;
			ELSE
				branchAddressPtr:= block.start + 8; block.end:= block.start; (* This block is just one desc long *)
				ptrToBuf:= packet.ptrToBlckBufAddr;
			END;

			contest.prgr.SetBranchAddress(block.start+z,branchAddressPtr,ptrToBuf);

			packet.block:= block;

			contest.listInserted.AddPacket(packet);

		END SendPacket;

		(** This procedure checks the packet type to find out which context to use,
		builds the program and fills the FIFO. IF the packet awaits a response, It will wait until the response comes *)
		PROCEDURE OHCISend(VAR packet: OHCIPacket):BOOLEAN;
		VAR contest: FirewireLowUtil.Contest; result: BOOLEAN; i,ms: LONGINT;
		BEGIN
			IF packet.dataSize > OHCI.MaxPacketSize THEN KernelLog.String("The packet size is too big!"); KernelLog.Ln();
				RETURN FALSE;
			END;

			(* Find out what kind of packet we have *)
			IF packet.type = FirewireLowUtil.raw THEN contest:= OHCI.ATController.GetReqContest()
			ELSIF SYSTEM.VAL(LONGINT,packet.tCode) = FirewireLowUtil.ITCode THEN OHCI.ITController.ResetIterator();
				contest:= OHCI.ITController.GetNextContest() (* there are min 4 contests! *)
			ELSIF ((SYSTEM.VAL(LONGINT,packet.tCode) =  FirewireLowUtil.NoDataWATRes) OR (SYSTEM.VAL(LONGINT,packet.tCode) =  FirewireLowUtil.QReadATRes)
				 OR (SYSTEM.VAL(LONGINT,packet.tCode) =  FirewireLowUtil.BReadATRes) OR (SYSTEM.VAL(LONGINT,packet.tCode) =  FirewireLowUtil.LockATRes))
				THEN contest:= OHCI.ATController.GetResContest()
			ELSE contest:= OHCI.ATController.GetReqContest()
			END;

			(* Add packet to the contest pending list *)
			contest.listPending.AddPacket(packet);

			(* KernelLog.String("Printing the content of the control set register in OHCISend:");
			FirewireLowUtil.PrintSet(FirewireLowUtil.ReadReg(contest.ctrlSet)); KernelLog.Ln(); *)

			(* Fills the fifo with pending packets *)
			IF ~FillFifo(contest) THEN result:=  TRUE ELSE result:=  FALSE END;

			(* if packet awaits a response, wait until the response comes *)
			i:= 0;
			IF packet.respExpected THEN
				BEGIN{EXCLUSIVE}
					ms:= 5;
					Kernel.SetTimer(timer,ms);
					Objects.SetTimeout(clock, SELF.HandleTimeout, ms);
					timeout:= FALSE;
					AWAIT((packet.state = FirewireLowUtil.COMPLETE) OR timeout)
				END;
			END;

			IF packet.state = FirewireLowUtil.COMPLETE THEN
				(* KernelLog.String("Packet received answer and is complete::ohciSend"); KernelLog.Ln() *)
			ELSE (* KernelLog.String("Time out::ohciSend"); KernelLog.Ln(); *)
			END;

			RETURN result
		END OHCISend;

		(** Fills the FIFO with the context program *)
		PROCEDURE FillFifo(contest: FirewireLowUtil.Contest):BOOLEAN;
		VAR packet: OHCIPacket; error: BOOLEAN; z: LONGINT; tempAddr: LONGINT;
		CONST isRunning= 15; active= 10;
		BEGIN
			(* KernelLog.String("Entering FillFifo"); KernelLog.Ln(); *)
			error:= contest.listPending.GetPacket(packet);
			IF (error) THEN
				(* KernelLog.String("There are no more packets to send"); KernelLog.Ln(); *) RETURN FALSE
			END;

			(* find out if packet has data *)
			(* KernelLog.String("Finding out packet data size!"); KernelLog.Ln(); *)
			IF packet.dataSize > 0 THEN
				z:= 3 (* use one outputMoreImmediateDescriptor and one outputLast descriptor *)
			ELSE z:= 2 (* use one outputLastImmediate decriptor *)
			END;

			(* Insert the packet into the fifo *)
			WHILE  ~error  DO
				error:= contest.listPending.DelPacket(packet);
				SendPacket(contest,packet,z);
				error:= contest.listPending.GetPacket(packet);
			END;

			error:= FALSE;

			(* IF contest.prgr.GetFreeBlocks() = 0 THEN KernelLog.String("Fifo for context "); KernelLog.String(contest.name);
				 KernelLog.String(" is full!"); KernelLog.Ln() END; *)
			tempAddr:= SYSTEM.GET32(packet.blockBufferAddr);
			(* Check if the context is running, else wake it up *)
			(* KernelLog.String("Printing the content of the control set register before setting the run bit:");
			FirewireLowUtil.PrintSet(FirewireLowUtil.ReadReg(contest.ctrlSet)); KernelLog.Ln(); *)
			IF ~(isRunning IN FirewireLowUtil.ReadReg(contest.ctrlSet)) THEN (* KernelLog.String("Starting "); KernelLog.String(contest.name);
				KernelLog.String(" contest!"); KernelLog.Ln();
				KernelLog.String("The comamnd Ptr is: "); FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,contest.prgr.bufferAddr+z));
				KernelLog.Ln(); *)
				FirewireLowUtil.WriteReg(contest.cmdPtr,FirewireLowUtil.ConvertToSet(packet.blockBufferAddr + z));
				(* KernelLog.String("The content of the ctrl set register is: ");
				FirewireLowUtil.PrintSet(FirewireLowUtil.ReadReg(contest.ctrlSet)); KernelLog.Ln(); *)
				IF FirewireLowUtil.StartContest(contest) THEN (* KernelLog.String("The context started successfully!"); KernelLog.Ln(); *)
				ELSE KernelLog.String("The context didn't start successfully!"); KernelLog.Ln();
				END
			ELSE (* wake up context *)
				IF ~(active IN FirewireLowUtil.ReadReg(contest.ctrlSet)) THEN (* KernelLog.String("Waking up ");
					KernelLog.String(contest.name); KernelLog.Ln() *)
				ELSE (* KernelLog.String("The context "); KernelLog.String(contest.name); KernelLog.String(" is already active!");
					KernelLog.Ln(); *)
				END;
				(* KernelLog.String("The comamnd Ptr is: "); FirewireLowUtil.PrintSet(SYSTEM.VAL(SET,contest.prgr.bufferAddr+z));
				KernelLog.Ln(); *)
				FirewireLowUtil.WriteReg(contest.ctrlSet,{12}); (* wake *)
			END;

			(* KernelLog.String("Leaving FillFifo!"); KernelLog.Ln(); *)
			RETURN error;
		END FillFifo;

		(** Decides if it's a local or external 1394 packet. IF it's an external packet it will be sent to the OHCI send procedures *)
		PROCEDURE  SendPacket1394(context: Contest;VAR packet: OHCIPacket):BOOLEAN; (* core.c *)
		CONST queued = 0;
		VAR speed: LONGINT;
		BEGIN

			IF packet.host.inBusReset
			OR (packet.generation # SYSTEM.VAL(LONGINT,LSH(FirewireLowUtil.ReadReg(FirewireLowUtil.SelfIDCount)*{16..23},-16))) THEN
				KernelLog.String("Generation mismatch or host in bus reset!"); KernelLog.Ln(); RETURN FALSE
			END;

			packet.state:= FirewireLowUtil.QUEUED;

			IF ( SYSTEM.VAL(LONGINT,packet.nodeID) = packet.host.nodeID ) THEN (* It's a local request *)
				KernelLog.String("It's an internal packet!"); KernelLog.Ln(); (*
				size:= packet.dataSize + packet.headerSize;

				SYSTEM.MOVE(packet.header, ConvertToLongint(tempBuf), packet.headerSize);

				IF packet.dataSize > 0 THEN
					SYSTEM.MOVE(packet.data, ConvertToLongint(tempBuf)+packet.headerSize, packet.dataSize)
				END;

				IF packet.respExpected THEN ack:= FirewireLowUtil.ConvertToSet(FirewireLowUtil.AckPending)
				ELSE ack:= FirewireLowUtil.ConvertToSet(FirewireLowUtil.AckComplete)
				END;

				PacketSent(context,packet,ack);
				PacketReceived(context,tempBuf,size,FALSE);

				RETURN TRUE *)
				RETURN FALSE
			END;

			IF (packet.type = FirewireLowUtil.async) & (packet.nodeID # {0..5}) THEN
				speed:= OHCI.SpeedMap[OHCI.nodeID][SYSTEM.VAL(LONGINT,packet.nodeID)];
				packet.speed:= FirewireLowUtil.ConvertToSet(speed);
			END;

			(* IF (speed = 1) OR (speed = 2) THEN
				speed:= speed*200;
				KernelLog.String("Sending packet with speed: "); KernelLog.Int(speed,2); KernelLog.String("!"); KernelLog.Ln()
			ELSE KernelLog.String("Sending packt with speed: 100!"); KernelLog.Ln()
			END; *)

			(*
			CASE speed OF
			0: KernelLog.String("Sending packet with speed: 100!"); KernelLog.Ln()
			|1: KernelLog.String("Sending packet with speed: 200!"); KernelLog.Ln()
			|2: KernelLog.String("Sending packet with speed: 400!"); KernelLog.Ln()
			END; *)

			(*
			KernelLog.String("Dumping the packet::SendPacket1394!"); KernelLog.Ln();
			FOR i:= 0 TO (packet.headerSize DIV 4)-1 DO
				FirewireLowUtil.PrintSet(packet.header[i])
			END;
			IF packet.dataSize > 0 THEN
				FOR i:= 0 TO (packet.dataSize DIV 4)-1 DO
					FirewireLowUtil.PrintSet(packet.data[i])
				END
			ELSE KernelLog.String("PacketDataSize is: "); KernelLog.Int(packet.dataSize,2); KernelLog.Ln();
			END; *)


			RETURN OHCISend(packet);
		END SendPacket1394;

		(** Allocates a buffer for the configuration rom *)
		PROCEDURE ConfigRomAlloc;
		VAR buffer: FirewireLowUtil.CharBuffer; adr: LONGINT; s: SET;
		BEGIN
			(* KernelLog.String("Entering configuration rom allocation"); KernelLog.Ln(); *)
			(* Allocating 2k buffer *)
			NEW(buffer, 2048);
			(* find a 1K aligned address *)
			adr:= ADDRESSOF(buffer[0]);
			DEC(adr,adr MOD 1024);
			INC(adr,1024);
			s:= SYSTEM.VAL(SET,adr);
			(* setting the buffer address *)
			(* KernelLog.String("Printing the buffer address"); KernelLog.Ln();
		    	FirewireLowUtil.PrintSet(s); *)
		  	OHCI.ptrToConfigRomBuf:= buffer;
		    	OHCI.ConfigRomBufferAdr:= s;
		END ConfigRomAlloc;

		(** Initializes the asynchronous receive request/response descriptors *)
		PROCEDURE InitARRDesc;
		CONST cmd = {29}; s = {27}; i = {21,20}; b = {19,18}; reqCount = {9}; resCount = {9};
		VAR desc: FirewireLowUtil.InputMoreDesc;
		BEGIN
			(* Input more AR *)
			desc.cmd := cmd; desc.s := s; desc.b := b;
			(* Input more *)
			desc.i := i; desc.reqCount := reqCount; desc.resCount := resCount;
			OHCI.IMDesc:= desc;
		END InitARRDesc;

		(** Configure the asynchronous receive request/response contexts *)
		PROCEDURE ConfigARR;
		VAR reqCont, resCont: FirewireLowUtil.Contest; controller: FirewireLowUtil.ADMAController; size: LONGINT;
		BEGIN
			OHCI.ARDescNum:= 4;
			InitARRDesc();
			(* Initialize contest with a scheduling buffer with place for 10 packets *)
			 OHCI.MaxPacketSize:= FirewireLowUtil.GetMaxPcktSize();
			size:= 10;
			NEW(controller,size,OHCI.ARDescNum);
			OHCI.ARController:= controller;
			(* Initialize request contest *)
			reqCont:= OHCI.ARController.GetReqContest();
			reqCont.type:= FirewireLowUtil.REQ;
			reqCont.name := "AR request";
			reqCont.cmdPtr:= FirewireLowUtil.ARReqComPtr;
			reqCont.ctrlSet:= FirewireLowUtil.ARReqContCtrlSet;
			reqCont.ctrlClear:= FirewireLowUtil.ARReqContCtrlClear;
			(* Initialize response contest *)
			reqCont.type:= FirewireLowUtil.RES;
			resCont:= OHCI.ARController.GetResContest();
			resCont.name:= "AR response";
			resCont.cmdPtr:= FirewireLowUtil.ARResComPtr;
			resCont.ctrlSet:= FirewireLowUtil.ARResContCtrlSet;
			resCont.ctrlClear:= FirewireLowUtil.ARResContCtrlClear;
			(* Allocate buffers for programs and packets *)
			resCont.prgr.SetBufferAddr(FirewireLowUtil.AllocARResBuf(resCont.prgr.ptrToBuf));
			reqCont.prgr.SetBufferAddr(FirewireLowUtil.AllocARReqBuf(reqCont.prgr.ptrToBuf));
			FirewireLowUtil.AllocPcktBuf(1,reqCont.tempBuffer,reqCont.ptrToTmpBuf);
			FirewireLowUtil.AllocPcktBuf(1,resCont.tempBuffer,resCont.ptrToTmpBuf);
		END ConfigARR;

		(** Configure the asynchronous transmit request/response contexts *)
		PROCEDURE ConfigATR;
		VAR reqCont, resCont: FirewireLowUtil.Contest; controller: FirewireLowUtil.ADMAController; size : LONGINT;
		BEGIN
			OHCI.ATDescNum:= 32;
			(* Initialize contest with a scheduling buffer with place for 10 packets *)
			size:= 10;
			NEW(controller,size,OHCI.ATDescNum);
			OHCI.ATController:= controller;
			(* Initialize request contest *)
			reqCont:= OHCI.ATController.GetReqContest();
			reqCont.type:= FirewireLowUtil.REQ;
			reqCont.name:= "AT request";
			reqCont.cmdPtr:= FirewireLowUtil.ATReqComPtr;
			reqCont.ctrlSet:= FirewireLowUtil.ATReqContCtrlSet;
			reqCont.ctrlClear:= FirewireLowUtil.ATReqContCtrlClear;
			(* Initialize response contest *)
			resCont:= OHCI.ATController.GetResContest();
			resCont.type:= FirewireLowUtil.RES;
			resCont.name:= "AT response";
			resCont.cmdPtr:= FirewireLowUtil.ATResComPtr;
			resCont.ctrlSet:= FirewireLowUtil.ATResContCtrlSet;
			resCont.ctrlClear:= FirewireLowUtil.ATResContCtrlClear;
			(* Allocate buffers for programs and packets *)
			resCont.prgr.SetBufferAddr(FirewireLowUtil.AllocATResBuf(resCont.prgr.ptrToBuf));
			reqCont.prgr.SetBufferAddr(FirewireLowUtil.AllocATReqBuf(reqCont.prgr.ptrToBuf));
		END ConfigATR;

		(** Configures the isochronous receive contexts *)
		PROCEDURE ConfigIR;
     		 VAR contest: FirewireLowUtil.IRContest; controller: FirewireLowUtil.IRDMAController; size, avIRCont, i: LONGINT;
     		str: ARRAY 5 OF CHAR;
      		BEGIN
        		avIRCont:= FirewireLowUtil.GetAvailableIRCont();
        		size:= 10; i:= 0;
        		OHCI.IRDescNum:= 16;
        		NEW(controller,avIRCont,size,OHCI.IRDescNum);
        		OHCI.IRController:= controller;
			WHILE controller.hasNext DO contest:= controller.GetNextContest();
				contest.type:= FirewireLowUtil.ISO;
				contest.name:= "IR "; Strings.IntToStr(i,str); Strings.Append(str,contest.name);
				contest.cmdPtr:= FirewireLowUtil.IRComPtr+(32*i);
				contest.ctrlSet:= FirewireLowUtil.isochRecvCntCtrlSet+(32*i);
				contest.ctrlClear:= FirewireLowUtil.isochRecvCntCtrlClear+(32*i);
				contest.match:= FirewireLowUtil.isochRecvContMatch+(32*i);
				contest.prgr.SetBufferAddr(FirewireLowUtil.AllocIRBuf(contest.prgr.ptrToBuf,OHCI.IRDescNum));
				INC(i);
			END;
			(* FirewireLowUtil.AllocPcktBuf(OHCI.IRDescNum*avIRCont, OHCI.IRPcktBuf); *)
		END ConfigIR;

		(** Configure the isochronous transmit contexts *)
		PROCEDURE ConfigIT;
		VAR contest: FirewireLowUtil.Contest; controller: FirewireLowUtil.ITDMAController; size, avITCont, i: LONGINT;
			str: ARRAY 5 OF CHAR;
		BEGIN
			avITCont:= FirewireLowUtil.GetAvailableITCont();
			size:= 10; i:= 0;
			OHCI.ITDescNum:= 16;
			NEW(controller,avITCont,size,OHCI.ITDescNum);
			OHCI.ITController:= controller;
			WHILE controller.hasNext DO contest:= controller.GetNextContest();
				 contest.type:= FirewireLowUtil.ISO;
				 contest.name:= "IT "; Strings.IntToStr(i,str); Strings.Append(str,contest.name);
				 contest.cmdPtr:= FirewireLowUtil.ITComPtr+(16*i);
				 contest.ctrlSet:= FirewireLowUtil.isochXmitCntCtrlSet+(16*i);
				 contest.ctrlClear:= FirewireLowUtil.isochXmitCntCtrlClear+(16*i);
				 contest.prgr.SetBufferAddr(FirewireLowUtil.AllocITBuf(contest.prgr.ptrToBuf,OHCI.ITDescNum));
				 INC(i);
			END;
			(* FirewireLowUtil.AllocPcktBuf(OHCI.ITDescNum*avITCont, OHCI.ITPcktBuf); *)
		END ConfigIT;

		(** Generates the dma receive programs and starts the contexts *)
		PROCEDURE InitAsyncRecvCont;
			VAR i: LONGINT; desc: FirewireLowUtil.InputMoreDesc; s, Z, branchAddress, dataAddress:SET;
			quadlet1, quadlet2, quadlet3, quadlet4, reqCount: SET; reqCntst, resCntst: FirewireLowUtil.Contest; block: FirewireLowUtil.Block;
			branchAddressPtr: LONGINT;
		BEGIN
			desc:= OHCI.IMDesc;
			reqCntst:= OHCI.ARController.GetReqContest();
			resCntst:= OHCI.ARController.GetResContest();
			(* Stop contexts if not already stopped *)
			(* KernelLog.String("Stopping arreq contest"); KernelLog.Ln(); *)
			FirewireLowUtil.StopContext(reqCntst.ctrlClear);
			(* KernelLog.String("Stopping arres contest"); KernelLog.Ln();	*)
			FirewireLowUtil.StopContext(resCntst.ctrlClear);
			(* Write descriptors for the asynchronous request context *)
			block.descNum:= OHCI.ARDescNum;
			block.start:= reqCntst.prgr.bufferAddr;
			FOR i:= 0 TO OHCI.ARDescNum-1 DO
				s:= desc.cmd + desc.s + desc.b;
				reqCount:= FirewireLowUtil.ConvertToSet(FirewireLowUtil.BufSize);
				(* KernelLog.String("Getting buffer::InitAsyncRecvCont"); KernelLog.Ln(); *)
				dataAddress:= reqCntst.buffers.GetBuffer();
				(* KernelLog.String("Got buffer!"); KernelLog.Ln(); *)
				quadlet1:= s + reqCount; quadlet2:= dataAddress; quadlet4:= reqCount;
				IF i+1 = OHCI.ARDescNum THEN (* build a ring *)
					quadlet3:= SYSTEM.VAL(SET,block.start) + {0}; block.end:= reqCntst.prgr.bufferAddr + i*16;
					branchAddressPtr:= reqCntst.prgr.bufferAddr + i*16+8;
					reqCntst.prgr.nextAddr:= reqCntst.prgr.bufferAddr + i*16+16;
				(* Is this the last descriptor? *)
				ELSE Z:= {0}; branchAddress:= FirewireLowUtil.ConvertToSet(reqCntst.prgr.bufferAddr + (i+1)*16);
						 quadlet3:= branchAddress + Z;
				END;
				SYSTEM.PUT32(reqCntst.prgr.bufferAddr + i*16, quadlet1);
				SYSTEM.PUT32(reqCntst.prgr.bufferAddr + i*16+4, quadlet2);
				SYSTEM.PUT32(reqCntst.prgr.bufferAddr + i*16+8, quadlet3);
				SYSTEM.PUT32(reqCntst.prgr.bufferAddr + i*16+12, quadlet4);
			END;
			reqCntst.prgr.blockBuffer.Append(block);

			block.descNum:= OHCI.ARDescNum;
			block.start:= resCntst.prgr.bufferAddr;
			(* Write descriptors for the asynchronous response context *)
			FOR i:= 0 TO OHCI.ARDescNum-1 DO
				s:= desc.cmd + desc.s + desc.b;
				reqCount:= FirewireLowUtil.ConvertToSet(FirewireLowUtil.BufSize);
				dataAddress:= resCntst.buffers.GetBuffer();
				quadlet1:= s + reqCount; quadlet2:= dataAddress; quadlet4:= reqCount;
				IF i+1 = OHCI.ARDescNum THEN (* build a ring *)
					quadlet3:= SYSTEM.VAL(SET,block.start)+{0}; block.end:= resCntst.prgr.bufferAddr + i*16;
					branchAddressPtr:= resCntst.prgr.bufferAddr + i*16+8;
					resCntst.prgr.nextAddr:= resCntst.prgr.bufferAddr + i*16+16;
				(* Is this the last descriptor? *)
				ELSE Z:= {0}; branchAddress:= FirewireLowUtil.ConvertToSet(resCntst.prgr.bufferAddr + (i+1)*16);
						 quadlet3:= branchAddress + Z;
				END;
				SYSTEM.PUT32(resCntst.prgr.bufferAddr + i*16, quadlet1);
				SYSTEM.PUT32(resCntst.prgr.bufferAddr + i*16+4, quadlet2);
				SYSTEM.PUT32(resCntst.prgr.bufferAddr + i*16+8, quadlet3);
				SYSTEM.PUT32(resCntst.prgr.bufferAddr + i*16+12, quadlet4);
			END;
			resCntst.prgr.blockBuffer.Append(block);

			(* Set the ARReq command ptr *)
			s:= FirewireLowUtil.ConvertToSet(reqCntst.prgr.bufferAddr) + {0};
			SYSTEM.PUT32(base + reqCntst.cmdPtr, s);
			(* Start the ARReq context  *)
			ASSERT(FirewireLowUtil.StartContest(reqCntst));

			(* Set the ARRes command ptr *)
			s:= FirewireLowUtil.ConvertToSet(resCntst.prgr.bufferAddr) + {0};
			SYSTEM.PUT32(base + resCntst.cmdPtr, s);
			(* Start the ARReq context *)
			ASSERT(FirewireLowUtil.StartContest(resCntst));

		END InitAsyncRecvCont;

		(** Initializes the isochronous receive contexts *)
		PROCEDURE InitIsochRecvCont;
		VAR i: LONGINT; desc: FirewireLowUtil.InputMoreDesc; s, Z, branchAddress, dataAddress:SET;
			quadlet1, quadlet2, quadlet3, quadlet4, reqCount: SET; contest: FirewireLowUtil.IRContest; block: FirewireLowUtil.Block;
			branchAddressPtr: LONGINT;
		BEGIN
			OHCI.IRController.ResetIterator();
			IF OHCI.IRController.hasNext THEN contest:= OHCI.IRController.GetNextContest() END;
			desc:= OHCI.IMDesc;
			(* Do not forget to start all other contexts too, if needed *)
			(* Stop contexts if not already stopped *)
			FirewireLowUtil.StopContext(contest.ctrlClear);
			(* Write descriptors for the asynchronous request context *)
			block.descNum:= OHCI.IRDescNum;
			block.start:= contest.prgr.bufferAddr;
			FOR i:= 0 TO OHCI.IRDescNum-1 DO
				s:= desc.cmd + desc.s + desc.b + desc.i;
				reqCount:= FirewireLowUtil.ConvertToSet(FirewireLowUtil.BufSize);
				(* dataAddress:= OHCI.IRPcktBuf[i]; *)
				dataAddress:= contest.buffers.GetBuffer();
				quadlet1:= s + reqCount; quadlet2:= dataAddress; quadlet4:= reqCount;
				(* Is this the last descriptor? *)
				IF i+1 = OHCI.IRDescNum THEN (* build a ring *)
					quadlet3:= SYSTEM.VAL(SET,block.start)+{0}; block.end:= contest.prgr.bufferAddr + i*16;
					branchAddressPtr:= contest.prgr.bufferAddr + i*16+8;
					contest.prgr.nextAddr:= contest.prgr.bufferAddr + i*16+16;
				ELSE Z:= {0}; branchAddress:= FirewireLowUtil.ConvertToSet(contest.prgr.bufferAddr + (i+1)*16);
						 quadlet3:= branchAddress + Z;
				END;
				SYSTEM.PUT32(contest.prgr.bufferAddr + i*16, quadlet1);
				SYSTEM.PUT32(contest.prgr.bufferAddr + i*16+4, quadlet2);
				SYSTEM.PUT32(contest.prgr.bufferAddr + i*16+8, quadlet3);
				SYSTEM.PUT32(contest.prgr.bufferAddr + i*16+12, quadlet4);
			END;
			contest.prgr.blockBuffer.Append(block);

			(* Set the IR command ptr *)
			s:= FirewireLowUtil.ConvertToSet(contest.prgr.bufferAddr) + {0};
			SYSTEM.PUT32(base + contest.cmdPtr, s);
			(* Start the  first IR context *)
			ASSERT(FirewireLowUtil.StartContest(contest));
		END InitIsochRecvCont;

		(** Initializes the isochronous transmit context *)
		PROCEDURE InitIsochXmitCont;
		VAR i: LONGINT; contest: FirewireLowUtil.Contest;
		BEGIN
			OHCI.ITController.ResetIterator();
			WHILE OHCI.ITController.hasNext DO contest:= OHCI.ITController.GetNextContest();
				FirewireLowUtil.StopContext(contest.ctrlClear + i*16);
			END
		END InitIsochXmitCont;

		(** Initializes the asynchronous transmit context *)
		PROCEDURE InitAsyncXmitCont;
	  	VAR reqCont, resCont: FirewireLowUtil.Contest;
		BEGIN
	    		reqCont:= OHCI.ATController.GetReqContest(); resCont:= OHCI.ATController.GetResContest();
	    		(* KernelLog.String("Stopping atreq contest"); KernelLog.Ln(); *)
			FirewireLowUtil.StopContext(reqCont.ctrlClear);
	    		(* KernelLog.String("Stopping atres contest"); KernelLog.Ln(); *)
			FirewireLowUtil.StopContext(resCont.ctrlClear);
		END InitAsyncXmitCont;

		(** Controls the status of the OHCI *)
		PROCEDURE ControlStatus;
			(* Not really used *)
		END ControlStatus;

		(** Checks if this node is bus manager *)
		PROCEDURE FindNodeInfo;
		CONST csrDone= 31;
		VAR reg: SET; done: BOOLEAN;
		BEGIN
			(* First check who is Bus Manager *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.CSRData,{0..5});
			FirewireLowUtil.WriteReg(FirewireLowUtil.CSRCompare,{0..5});
			FirewireLowUtil.WriteReg(FirewireLowUtil.CSRControl,{});
			(* Wait until compare swap operation has been done *)
			reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.CSRControl);
			done:= FALSE;
			WHILE ~done DO
				IF csrDone IN reg THEN done:= TRUE ELSE
				 	reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.CSRControl)
				END
			END;
			(* Read the bus manager ID *)
			reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.CSRData);
			(* Print it out *)
			(* KernelLog.String("Printing the bus manager id");
			FirewireLowUtil.PrintSet(reg); *)
			(* Print the node id to compare it *)
			(* KernelLog.String("Printing the node id");
			reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.NodeID);
			reg:= reg*{0..5};
			FirewireLowUtil.PrintSet(reg); *)
		END FindNodeInfo;

		(* Not used: it was intended as a packet scheduler
		PROCEDURE Schedule(contest: FirewireLowUtil.Contest);
		VAR block: FirewireLowUtil.Block; quadlet3,quadlet: SET; branchAddress, avlbl, resdl, i: LONGINT; packet: FirewireLowUtil.Packet;
			dataAddress, copyAddress: LONGINT;
		CONST notLast= 0; reqCount = {0..15}; resCount = {0..15}; branchMask = {4..31};
		BEGIN
			(* read value of Z *)
			KernelLog.String("Scheduling a block, if there are any!"); KernelLog.Ln();
			ASSERT(contest.prgr.blockBuffer.num > 0);
			block:= contest.prgr.blockBuffer.Remove();
			quadlet3:= SYSTEM.VAL(SET, SYSTEM.GET32(block.start + 8));
			(* read value of reqCount and resCount *)
			quadlet:= SYSTEM.VAL(SET, SYSTEM.GET32(block.start));
			avlbl:= ConvertToLongint(quadlet*reqCount);
			quadlet:= SYSTEM.VAL(SET, SYSTEM.GET32(block.start + 12));
			resdl:= ConvertToLongint(quadlet*reqCount);
			(* read data address *)
			dataAddress:= SYSTEM.VAL(LONGINT, SYSTEM.GET32(block.start + 4));
			(* schedule packet *)
			copyAddress:= ADDRESSOF(packet);
			FOR i:= 0 TO avlbl-resdl-1 DO (* SYSTEM.MOVE(dataAddress+i,copyAddress+i,8) *)
			SYSTEM.PUT8(copyAddress+i,SYSTEM.GET8(dataAddress+i)) END;
			PrintBuffer(FirewireLowUtil.ConvertToSet(dataAddress),(avlbl-resdl) DIV 4);
			PrintBuffer(FirewireLowUtil.ConvertToSet(copyAddress),(avlbl-resdl) DIV 4);
			branchAddress:= ConvertToLongint(branchMask*quadlet3);
			IF avlbl > resdl THEN KernelLog.String("Appending packet"); KernelLog.Ln(); contest.procBuffer.Append(packet) END;
			WHILE notLast IN quadlet3 DO
				quadlet3:= SYSTEM.VAL(SET, SYSTEM.GET32(branchAddress + 8));
				(* read value of reqCount and resCount *)
				quadlet:= SYSTEM.VAL(SET, SYSTEM.GET32(branchAddress));
				avlbl:= ConvertToLongint(quadlet*reqCount);
				quadlet:= SYSTEM.VAL(SET, SYSTEM.GET32(branchAddress + 12));
				resdl:= ConvertToLongint(quadlet*reqCount);
				(* read data address *)
				dataAddress:= SYSTEM.VAL(LONGINT, SYSTEM.GET32(branchAddress + 4));
				FOR i:= 0 TO avlbl-resdl-1 DO SYSTEM.MOVE(dataAddress+i,copyAddress+i,8) END;
				(* KernelLog.String("Difference between available and residual is: "); KernelLog.Int(avlbl - resdl,2); KernelLog.Ln(); *)
				PrintBuffer(FirewireLowUtil.ConvertToSet(dataAddress),(avlbl-resdl) DIV 4);
				PrintBuffer(FirewireLowUtil.ConvertToSet(copyAddress),(avlbl-resdl) DIV 4);
				branchAddress:= ConvertToLongint(branchMask*quadlet3);
				IF avlbl > resdl THEN KernelLog.String("Appending packet"); KernelLog.Ln(); contest.procBuffer.Append(packet) END
			END;

			contest.prgr.blockBuffer.Append(block);
		END Schedule; *)

		(** Schedules packets for isochronous contexts *)
		PROCEDURE IsoSchedule(reg: SET);
		VAR controller: FirewireLowUtil.IRDMAController; i: LONGINT;
		BEGIN
			(* This call will fail in PacketReceived, because implementation is missing *)
			FOR i:= 0 TO controller.avIRCont-1 DO
				IF i IN reg THEN ProcRcvdPckts(controller.GetContest(i)) END
			END;
		END IsoSchedule;

		(** Does OHCI buffer allocation and context initialization *)
		PROCEDURE DevInit;
		    VAR reg: SET; (* t: Kernel.Timer; *)
		BEGIN
			NEW(t);
			(* KernelLog.String("Entering device initialization"); KernelLog.Ln(); *)
			(* csr configuration rom allocation *)
			ConfigRomAlloc();
			(* self-id buffer allocation *)
			SelfIDAlloc();
			FirewireLowUtil.CheckSelfIDCount();
			(* allocate contexts *)
			(* initialize AR response and request context *)
			ConfigARR();
			(* initialize AT response and receive context *)
			ConfigATR();
			(* Do a softReset *)
			FirewireLowUtil.SoftReset();
			(*Give power to the Link Layer *)
			(* KernelLog.String("Giving power to the link layer"); KernelLog.Ln(); *)
			(* KernelLog.String("Control register before power: ");
			FirewireLowUtil.PrintSet(FirewireLowUtil.ReadReg(FirewireLowUtil.HCControl)); *)
			reg := {};
			INCL(reg, LPS);
			FirewireLowUtil.SetHCControl(reg);
			t.Sleep(50);
			(* KernelLog.String("Control register after power: ");
			FirewireLowUtil.PrintSet(FirewireLowUtil.ReadReg(FirewireLowUtil.HCControl)); *)
			(* Determine number of available IR and IT contexts *)
			FirewireLowUtil.CheckAvailableIR();
			FirewireLowUtil.CheckAvailableIT();
			(* initialize IR context *)
			ConfigIR();
			(* initialize IT context *)
			ConfigIT();
		END DevInit;

		(** Inits the OHCI data structure *)
		PROCEDURE InitOHCI;
		VAR i: LONGINT;
		BEGIN
			FOR i:= 0 TO 62 DO
				OHCI.Nodes[i]:= NIL
			END;
			OHCI.selfIDComplete:= FALSE;
			NEW(OHCI.adrCheck);
			NEW(t);NEW(clock);
			NEW(OHCI.packetFIFO,10);
			(* Get max packet size  *)
			OHCI.MaxPacketSize:= FirewireLowUtil.GetMaxPcktSize();
			NEW(OHCI.tempBuffer,OHCI.MaxPacketSize);
		END InitOHCI;

		(** Initializes the OHCI registers *)
		PROCEDURE&Init*(base,irq:LONGINT);
		CONST irmcCmcIsc = {31,30,29}; cycClkAcc = {16..23}; pmcBmc = {28,27}; postedWriteEnable= {18};
			programPhyEnable= 23; aPhyEnhanceEnable= 22; rcvPhyPkt = 10; postedWriteErr = 8;
		VAR reg:SET;
		BEGIN
			SELF.base:=base;
			SELF.irq:=irq;
			DevInit();
			InitOHCI();
			(* Install the handler  *)
			IF(irq >= 1) & (irq <= 15) THEN Objects.InstallHandler(SELF.HandleInterrupt, Machine.IRQ0+irq)
			END;
			(* Define some bus options *)
				reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.BusOptions);
				(* Enable IRMC, CMC and ISC *)
				reg:= reg + irmcCmcIsc;
				(* XXX: Set cyc clk acc to zero for now *)
				reg:= reg - cycClkAcc;
				(* Disable PMC and BMC *)
				reg:= reg - pmcBmc;
				FirewireLowUtil.WriteReg(FirewireLowUtil.BusOptions,reg);
			(* Set the bus number *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.NodeID,busNumber);
			(* Enable posted writes *)
			FirewireLowUtil.SetHCControl(postedWriteEnable);
			(* Clearing LinkControl *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.CLinkControl,{0..31});
			(* Check if OHCI has enhanced register map 1394a *)
			reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.HCControl);
			IF programPhyEnable IN reg THEN OHCI.ExstRegMap:= TRUE;
				IF ~(aPhyEnhanceEnable IN reg) THEN FirewireLowUtil.SetHCControl({aPhyEnhanceEnable}) END
			ELSE OHCI.ExstRegMap:= FALSE
			END; reg:= {};
			(* Enable cycle timer and cycle master and set the IRM contender bit in self ID packets *)
			(* Enable receive selfID packets outside bus reset *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.LinkControl,{10,20,21});
			IF OHCI.ExstRegMap THEN FirewireLowUtil.SetPhyControl({10},{6}) END;
			(* clearing interrupts *)
			(* KernelLog.String("Clearing interrupts"); KernelLog.Ln(); *)
			FirewireLowUtil.ClearIntEventAll();
			FirewireLowUtil.ClearIntMaskAll();
			(* Set SelfID dma buffer *)
			(* KernelLog.String("Setting the Self ID Buffer"); *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.SelfIDBuffer,OHCI.SelfIDBufferAdr);
			(* Enable SelfID dma *)
			(* KernelLog.String("Enabling SelfID"); KernelLog.Ln(); *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.LinkControl,{rcvSelfID});
			(* Do not accept phy packets into the AR request context clearing the rcvPhyPkt bit
			FirewireLowUtil.WriteReg(FirewireLowUtil.CLinkControl,{10}); *)
			(* Set bufferfill, isochHeader, multichannel for IR context  0 *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.isochRecvCntCtrlSet,{28,30,31});
			(* Set all tags of the first isochronous receive match register  *)
			FirewireLowUtil.SetIsochRecvContMatch({28..31});
			(* Clear the isochronous receive mask and event interrupt register  *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.isochRecvIntEvntClear,{0..31});
			FirewireLowUtil.WriteReg(FirewireLowUtil.isochRecvIntMaskClear,{0..31});
			 (* Clear the isochronouse transmit mask and event interrupt register  *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.isochXmitIntEvntClear,{0..31});
			FirewireLowUtil.WriteReg(FirewireLowUtil.isochXmitIntMaskClear,{0..31});
			(* Clear the isochronous receive mutlichannel high and low mask  *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.IRmultiChanMaskHiClear,{0..31});
			FirewireLowUtil.WriteReg(FirewireLowUtil.IRmultiChanMaskLoClear,{0..31});
			(* Initialize asynchronous receive dma *)
			InitAsyncRecvCont();
			InitAsyncXmitCont();
			(* Initialize isochronous dma *)
			InitIsochRecvCont();
			InitIsochXmitCont();
			(* Set the isochronous receive interrupt mask for context 0 *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.isochRecvIntMaskSet,{0});
			(* Set the isochronous transmit interrupt mask for context 0 *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.isochXmitIntMaskSet,{0});
			(* Receive asynchronous requests from all nodes *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.ARFilterHISet,{31});
				  (* Set the asynchronous trasmit retries register *)
			reg:= FirewireLowUtil.MaxPhysRespRetries + FirewireLowUtil.MaxATReqRetries
				 + FirewireLowUtil.MaxATRespRetries;
			FirewireLowUtil.WriteReg(FirewireLowUtil.ATRetries, reg);
			(* Set the physical upper bound if implemented *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.PhyUpperBound,{16..31});
			reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.PhyUpperBound);
			(* FirewireLowUtil.PrintSet(reg); *)
			IF reg = {16..31} THEN
				(* KernelLog.String("The physical upper bound is: 48hFFFF 0000 0000"); KernelLog.Ln(); *)
			ELSE  (* KernelLog.String("The physical upper bound is: 48h0001 0000 0000"); KernelLog.Ln() *)
			END;
			(* Receive physical requests from every bys and every node *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.PRFilterHiSet,{0..30});
			FirewireLowUtil.WriteReg(FirewireLowUtil.PRFilterLowSet,{0..31});
			(* Set no byte swapping *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.HCControl,{30});
			(* Enabling interrupts *)
			(* KernelLog.String("Enabling interrupts"); KernelLog.Ln(); *)
			FirewireLowUtil.WriteReg(FirewireLowUtil.IntMask,{31});
			reg:= {};
			INCL(reg,unrecoverableError);
			INCL(reg,busReset);
			INCL(reg,regAccessFail);
			INCL(reg,selfIDComplete);
			INCL(reg,RSPkt);
			INCL(reg,RQPkt);
			INCL(reg,respTxComplete);
			INCL(reg,reqTxComplete);
			INCL(reg,isochRx);
			INCL(reg,isochTx);
			INCL(reg,cycleInconsistent);
			INCL(reg,postedWriteErr);
			FirewireLowUtil.WriteReg(FirewireLowUtil.IntMask,reg);
			FirewireLowUtil.CheckIntMask();
			FirewireLowUtil.CheckIntEvent();
			(* Initialize the label pool of the OHCI *)
			NEW(OHCI.labeler,63);
			(* Initialize OHCI bus reset status *)
			OHCI.inBusReset:= FALSE;
			(*Enable Operation of the lInk Layer*)
			(* KernelLog.String("Enabling operation of the link layer"); KernelLog.Ln(); *)
			reg:= {};
			INCL(reg, LinkEnable);
			FirewireLowUtil.SetHCControl(reg);
			(* KernelLog.String("Control register after enabling operation of the link layer:");
			KernelLog.Ln();
			FirewireLowUtil.PrintSet(FirewireLowUtil.ReadReg(FirewireLowUtil.HCControl)); *)
			(* Initiate bus reset *)
			(* KernelLog.String("Initiating bus reset!"); KernelLog.Ln(); *)
			FirewireLowUtil.SetPhyControl({8},{6});
			(* Print OHCI information *)
			(* PrintOHCIInfo(); *) BEGIN {EXCLUSIVE}
			AWAIT(OHCI.selfIDComplete)
			END;
			(* KernelLog.String("Scanning nodes!"); KernelLog.Ln(); *)
			ScanNodes();
			KernelLog.String("Finished OHCI initialization"); KernelLog.Ln();
		END Init;

		(** Checks to see who is the bus manager and tries to become it if necessary. This procedure is not complete *)
		PROCEDURE CheckBusManager;
		CONST isRoot= 30;
		VAR selfIDBuf: SET; reg: SET;nodeID,data: SET;countReg,selfIDSize,IRMID: SET; i,j,size: LONGINT;
		BEGIN
			nodeID:= FirewireLowUtil.ReadReg(FirewireLowUtil.NodeID)*{0..5};
			OHCI.nodeID:= ConvertToLongint(nodeID);
			(* Check if OHCI is root *)
			reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.NodeID)*{30};
			(* Check if OHCI is IRM: note that contender bit must be set and link must be active *)
			IF isRoot IN reg THEN OHCI.IsRoot:= TRUE; OHCI.IsIRM:= TRUE;
				(* Now be fast and set the ID of the OHCI into the BusManagerID register *)
				FirewireLowUtil.WriteReg(FirewireLowUtil.CSRData,nodeID);
				FirewireLowUtil.WriteReg(FirewireLowUtil.CSRCompare,{0..5});
				FirewireLowUtil.WriteReg(FirewireLowUtil.CSRControl,{});
				IRMID:= FirewireLowUtil.ReadReg(FirewireLowUtil.CSRData);
				IF  IRMID = {0..5} THEN
					OHCI.IsBM:= TRUE; IRMID:= nodeID ELSE OHCI.IsBM:= FALSE
				END;
			ELSE (* Find out if some other IRM contender has higher ID *)
				selfIDBuf:= OHCI.SelfIDBufferAdr;
				countReg:= FirewireLowUtil.ReadReg(FirewireLowUtil.SelfIDCount);
				selfIDSize := LSH(countReg,-2);
				selfIDSize := selfIDSize*{0..8};
				size := ConvertToLongint(selfIDSize);
				j:= 4;
				(* Traverse self ID buffer *)
				OHCI.IsIRM:= TRUE;
				FOR i:= 0 TO size-2 DO
					data := SYSTEM.VAL(SET, SYSTEM.GET32(ConvertToLongint(selfIDBuf)+j)); INC(j,8);
					IF (11 IN data) & (22 IN data) THEN (* ok it's an IRM contender, check if ID is higher then mine *)
						data:= LSH(data,-24)*{0..5};
						IF OHCI.nodeID > ConvertToLongint(data) THEN (* shit, I'm not IRM *)
							OHCI.IsIRM:= FALSE
						END
					END
				END;
				IF OHCI.IsIRM THEN (* be fast and set OHCI ID into the BusManagerID register *)
					FirewireLowUtil.WriteReg(FirewireLowUtil.CSRData,nodeID);
					FirewireLowUtil.WriteReg(FirewireLowUtil.CSRCompare,{0..5});
					FirewireLowUtil.WriteReg(FirewireLowUtil.CSRControl,{});
					IRMID:= FirewireLowUtil.ReadReg(FirewireLowUtil.CSRData);
					IF IRMID = {0..5} THEN
						OHCI.IsBM:= TRUE; IRMID:= nodeID ELSE OHCI.IsBM:= FALSE
					END
				ELSE (* Go and try to set the nodeId of the OHCI into the IRM *)
					KernelLog.Ln();
				END;
				(* I'm not the bus manager *)
				(* Get the topology map *)
				OHCI.IsRoot:= FALSE; OHCI.IsIRM:= FALSE END;
				(* TODO *)
		END CheckBusManager;

		(** Scans the unit directory *)
		PROCEDURE  ScanUnitDirectory(node: FirewireLowUtil.Node);
			(* not really needed *)
		END ScanUnitDirectory;

		(** Processes the unit directory of each device on the bus *)
		PROCEDURE ProcessUnitDirectory(VAR ud: FirewireLowUtil.UnitDirectory; node: FirewireLowUtil.Node; addrLow, addrHigh: SET; VAR id: LONGINT);
		VAR length,addr,code,value,i: LONGINT; udTemp: FirewireLowUtil.UnitDirectory; context: Contest; buffer: SET;
		BEGIN
			(* KernelLog.String("Processing the unit directory!"); KernelLog.Ln(); *)
			context:= OHCI.ATController.GetReqContest();
			addr:= SYSTEM.VAL(LONGINT,addrLow);
			(* Get the length of the unit directory *)
			IF ~Read1394(context,OHCI,node.phyID,node.generation,addrLow,addrHigh,buffer,4) THEN
				KernelLog.String("There was an error::ProcessUnitDirectory"); KernelLog.Ln(); RETURN
			END;

			length:= SYSTEM.VAL(LONGINT,LSH(buffer,-16));
			NEW(ud,length);

			ud.addrLow:= addrLow;
			ud.addrHigh:= addrHigh;
			INC(id); ud.ID:= id;

			(* increment address *)
			INC(addr,4);
			 addrLow:= SYSTEM.VAL(SET,addr);

			 i:= 0;
			 WHILE length > 0 DO
			 	IF ~Read1394(context,OHCI,node.phyID,node.generation,addrLow,addrHigh,buffer,4) THEN
					KernelLog.String("There was an error::ProcessRootDirectory"); KernelLog.Ln(); RETURN
				END;

				ud.udEntries[i]:= buffer;

				code:= SYSTEM.VAL(LONGINT,LSH(buffer,-24));
				value:= SYSTEM.VAL(LONGINT,buffer*{0..23});
				CASE code OF
					FirewireLowUtil.ConfigRomVendorID: ud.vendorID:= value;
					|FirewireLowUtil.ConfigRomModelID: ud.modelID:= value;
					|FirewireLowUtil.ConfigRomSpecifierID: ud.specifierID:= value;
					|FirewireLowUtil.ConfigRomUnitSWVersion: ud.version:= value;
					|FirewireLowUtil.ConfigRomDescriptorLeaf: (* TODO *)
					|FirewireLowUtil.ConfigRomDescriptorDirectory: (* TODO *)
					|FirewireLowUtil.ConfigRomLogicalUnitDirectory:
						ud.hasLogicalUnitDir:= TRUE;
						ProcessUnitDirectory(udTemp,node,SYSTEM.VAL(SET,addr+value*4),addrHigh,id);
						(* inherit data if missing *)
						IF udTemp.vendorID = 0 THEN udTemp.vendorID:= ud.vendorID END;
						IF udTemp.modelID = 0 THEN udTemp.modelID:= ud.modelID END;
						IF udTemp.specifierID = 0 THEN udTemp.specifierID:= ud.specifierID END;
						IF udTemp.version = 0 THEN udTemp.version:= ud.version END;
						ud.luns[udTemp.ID]:= udTemp;
				ELSE (* NOTHING *)
				END;
				DEC(length); INC(addr,4); addrLow:= SYSTEM.VAL(SET,addr); INC(i);
			 END;

		END ProcessUnitDirectory;

		(** Process the root directory of each device on the bus *)
		PROCEDURE ProcessRootDirectory(node: FirewireLowUtil.Node);
		VAR context: Contest; buffer, addrLow, addrHigh: SET; code, value, addr, busInfoLength, rootDirLength, id: LONGINT;
			ud: FirewireLowUtil.UnitDirectory;
		BEGIN
			(* KernelLog.String("Processing root directory"); KernelLog.Ln(); *)
			id:= -1;
			addrHigh:= FirewireLowUtil.CSRBaseHigh;
			addrLow:= FirewireLowUtil.CSRBaseLow;
			addrLow:= addrLow + FirewireLowUtil.CSRConfigRom;
			addr:= SYSTEM.VAL(LONGINT,addrLow);
			context:= OHCI.ATController.GetReqContest();
			(* get the length of the bus info block *)
			IF ~Read1394(context,OHCI,node.phyID,node.generation,addrLow,addrHigh,buffer,4) THEN
				KernelLog.String("There was an error::ProcessRootDirectory"); KernelLog.Ln(); RETURN
			END;

			busInfoLength:= SYSTEM.VAL(LONGINT,LSH(buffer,-24));

			addr:= addr + 4 + busInfoLength*4;
			addrLow:= SYSTEM.VAL(SET,addr);

			(* now get the length of the root directory *)
			IF ~Read1394(context,OHCI,node.phyID,node.generation,addrLow,addrHigh,buffer,4) THEN
				KernelLog.String("There was an error::ProcessRootDirectory"); KernelLog.Ln(); RETURN
			END;

			rootDirLength:= SYSTEM.VAL(LONGINT,LSH(buffer,-16));

			INC(addr,4);
			addrLow:= SYSTEM.VAL(SET,addr);

			WHILE rootDirLength > 0 DO
				IF ~Read1394(context,OHCI,node.phyID,node.generation,addrLow,addrHigh,buffer,4) THEN
					KernelLog.String("There was an error::ProcessRootDirectory"); KernelLog.Ln(); RETURN
				END;

				code:= SYSTEM.VAL(LONGINT,LSH(buffer,-24));
				value:= SYSTEM.VAL(LONGINT,buffer*{0..23});
				CASE code OF
					FirewireLowUtil.ConfigRomVendorID: node.vendorID:= value; (* perhaps look also for a text leaf *)
					|FirewireLowUtil.ConfigRomNodeCapabilities: node.capabilities:= SYSTEM.VAL(SET,value);
					|FirewireLowUtil.ConfigRomUnitDirectory:
						ProcessUnitDirectory(ud,node,SYSTEM.VAL(SET,addr + value*4),addrHigh,id);
						node.uds[ud.ID]:= ud;
				ELSE (* NOTHING *)
				END;

				DEC(rootDirLength); INC(addr,4); addrLow:= SYSTEM.VAL(SET,addr);
			END;
		END ProcessRootDirectory;

		(** Scan the root directory *)
		PROCEDURE ScanRootDirectory;
			(* not really needed *)
		END ScanRootDirectory;

		(** Scan a node's directories *)
		PROCEDURE ScanEachNode(physicalID: SET; generation: LONGINT);
		VAR buffer: ARRAY 5 OF SET; bufferLength,i: LONGINT;
			node: FirewireLowUtil.Node; found: BOOLEAN; guid: FirewireLowUtil.GUID;
		BEGIN
			(* KernelLog.String("Entering scan each node"); KernelLog.Ln(); *)
			bufferLength:= 5;
			IF ReadBusInfoBlock(OHCI,physicalID,generation,buffer,bufferLength) THEN RETURN END;

			IF (buffer[1] # SYSTEM.VAL(SET,FirewireLowUtil.BusIDNumber)) THEN
				KernelLog.String("This device an invalid bus id number::ScanEachNode!"); KernelLog.Ln()
			END;

			guid.high:= buffer[3]; guid.low:= buffer[4];

			(* now find this node and update it or create it *)
			i:= 0; found:= FALSE;
			WHILE (OHCI.Nodes[i] # NIL) & ~found DO
				node:= OHCI.Nodes[i];
				IF (node.guid.low = guid.low) & (node.guid.high = guid.high) THEN
					found:= TRUE
				ELSE INC(i)
				END
			END;

			IF found THEN (* update *)
				(* KernelLog.String("Updating node"); KernelLog.Ln(); *)
				node.Update(buffer[2],physicalID,generation);
			ELSE (* create new *)
				(* KernelLog.String("Creating new node"); KernelLog.Ln(); *)
				NEW(node,guid,buffer[2],physicalID,generation); OHCI.Nodes[i]:= node;
			END;
			(* KernelLog.String("Leaving scan each node"); KernelLog.Ln(); *)
		END ScanEachNode;

		(** Scan all nodes on the bus *)
		PROCEDURE ScanNodes*;
		VAR i,generation: LONGINT; sid: FirewireLowUtil.SelfID; node: FirewireLowUtil.Node;
		BEGIN
			(* KernelLog.String("Entering scan nodes"); KernelLog.Ln(); *)
			WHILE OHCI.TopologyMap[i] # NIL DO
				sid:= OHCI.TopologyMap[i];
				IF ~sid.extended & (sid.linkActive={0}) THEN
					IF sid.physicalID # SYSTEM.VAL(SET,OHCI.nodeID) THEN
						generation:= FirewireLowUtil.GetGeneration();
						ScanEachNode(sid.physicalID,generation)
					END
				END;
				INC(i)
			END;

			i:= 0;
			WHILE OHCI.Nodes[i] # NIL DO
				node:= OHCI.Nodes[i];
				IF node.probe THEN ProcessRootDirectory(node) END; INC(i);
			END;

			(* i:= 0; j:= 0;
			WHILE c.OHCI.Nodes[i] # NIL DO
				node:= c.OHCI.Nodes[i];
				KernelLog.String("Printing the guid: "); KernelLog.Ln();
				FirewireLowUtil.PrintSet(node.guid.high); FirewireLowUtil.PrintSet(node.guid.low);
				KernelLog.String("Printing the unit directories if there are any"); KernelLog.Ln();
				WHILE node.uds[j] # NIL DO
					KernelLog.String("Printing the specifier id: "); KernelLog.Int(node.uds[j].specifierID,2); KernelLog.Ln();
					INC(j);
				END;
				INC(i);
			END; *)
			(* KernelLog.String("Leaving scan nodes"); KernelLog.Ln(); *)
		END ScanNodes;

		(** Builds the topology and the speed map *)
		PROCEDURE BuildMaps;
		VAR size,i,j,addr: LONGINT; quad,reg: SET; sid: FirewireLowUtil.SelfID; esid: FirewireLowUtil.ExtSelfID;
			speed, children: ARRAY 64 OF LONGINT; c: LONGINT;
		BEGIN
			OHCI.numOfNodes:= 0;
			(* KernelLog.String("Entering BuildMaps!"); KernelLog.Ln(); *)
			addr:= SYSTEM.VAL(LONGINT,OHCI.SelfIDBufferAdr) + 4; (* first quadlet has only management info *)
			(* Count the nodes and remember the ids *)
			reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.SelfIDCount);
			(* mask the size *)
			size:= SYSTEM.VAL(LONGINT,LSH(reg * {2..10},-2));
			size:= ((size-1) DIV 2)-1; (* we just need to look at the first quadlet of each selfid packet *)

			(* Initialize *)
			(* KernelLog.String("Initializing the children array!"); KernelLog.Ln(); *)
			FOR i:= 0 TO 64-1 DO children[i]:= 0 END;

			(* KernelLog.String("Initializing topology map!"); KernelLog.Ln();
			KernelLog.String("size is: ");KernelLog.Int(size,2); KernelLog.Ln();
			KernelLog.String("Number of nodes is: "); KernelLog.Int(OHCI.numOfNodes,2); KernelLog.Ln(); *)
			FOR i:= 0 TO size DO
				quad:= SYSTEM.VAL(SET,SYSTEM.GET32(addr+(i*8)));
				IF 23 IN quad THEN NEW(esid,quad); OHCI.TopologyMap[i]:= esid;
				ELSE
					(* KernelLog.String("It's an sid, increase numOfNodes"); KernelLog.Ln(); *)
					NEW(sid,quad); OHCI.TopologyMap[i]:= sid; INC(OHCI.numOfNodes);
					(* KernelLog.String("Number of nodes is: "); KernelLog.Int(OHCI.numOfNodes,2); KernelLog.Ln(); *)
				END;
			END;

			OHCI.TopologyMap[i]:= NIL;

			i:= 0;
			(* check if port is active and connected to child node *)
			(* and remember how much direct children this node has *)
			(* KernelLog.String("Initialize speed array!"); KernelLog.Ln(); *)
			WHILE OHCI.TopologyMap[i] # NIL DO
				sid:= OHCI.TopologyMap[i]; c:= 0;
				IF sid.extended THEN
					esid:= sid (FirewireLowUtil.ExtSelfID);
					IF (esid.pa = {0,1}) THEN INC(children[i]) END;
					IF (esid.pb = {0,1}) THEN INC(children[i]) END;
					IF (esid.pc = {0,1}) THEN INC(children[i]) END;
					IF (esid.pd = {0,1}) THEN INC(children[i]) END;
					IF (esid.pe = {0,1}) THEN INC(children[i]) END;
					IF (esid.pf = {0,1}) THEN INC(children[i]) END;
					IF (esid.pg = {0,1}) THEN INC(children[i]) END;
					IF (esid.ph = {0,1}) THEN INC(children[i]) END;
				ELSE
					(* KernelLog.String("It's not an extended sid"); KernelLog.Ln(); *)
					IF (sid.p0 = {0,1}) THEN INC(children[i]) END;
					IF (sid.p1 = {0,1}) THEN INC(children[i]) END;
					IF (sid.p2 = {0,1}) THEN INC(children[i]) END;
					speed[i]:= SYSTEM.VAL(LONGINT,sid.sp);
				END;

				(* Check if there are more packets from this node *)
				IF ~(0 IN sid.m) THEN INC(i) END;
			END;

			(* Set the self mapping *)
			(* KernelLog.String("Initializing the speed map!"); KernelLog.Ln();
			KernelLog.String("Number of Nodes: ");KernelLog.Int(OHCI.numOfNodes,2); KernelLog.Ln(); *)
			FOR i:= 0 TO OHCI.numOfNodes-1 DO
				(* KernelLog.String("I is: "); KernelLog.Int(i,2); KernelLog.Ln();*)
				OHCI.SpeedMap[i][i]:= speed[i];
			END;

			(* KernelLog.String("Find out max communication speed!"); KernelLog.Ln(); *)
			(* count the total children of a node and find out the max comunication speed for each node pair *)
			i:= OHCI.numOfNodes-2;
			WHILE i >= 0 DO
				c:= children[i];
				FOR j:=1 TO c DO INC(children[i],children[i+j]);
					IF speed[i] < speed[i+j] THEN speed[i+j]:= speed[i] END;
				END;
			DEC(i);
			END;

			(* KernelLog.String("Complete speed map!"); KernelLog.Ln(); *)
			(* Fill speed capabilities in speed map *)
			i:= 0; j:= 0;
			FOR i:= 0 TO OHCI.numOfNodes-1 DO
				FOR j:= 0 TO OHCI.numOfNodes-1 DO
					IF i # j THEN
						OHCI.SpeedMap[i][j]:= speed[j]
					END
				END
			END;
		END BuildMaps;

		(** Transactions *)

		(** Creates a Lock packet *)
		PROCEDURE Lock1394(context: Contest; ohci: FirewireLowUtil.OHCIDesc; nodeID: SET; generation: LONGINT; addrLow, addrHigh: SET; extCode: LONGINT;
			VAR data: SET; VAR  arg: SET):BOOLEAN;
		VAR packet: OHCIPacket; success: BOOLEAN;
		BEGIN
			success:= FALSE;
			packet:= FirewireLowUtil.MakeLockPacket(ohci,nodeID,addrLow,addrHigh,extCode,data,arg);

			(* Dump data
			KernelLog.String("Dumping the data:: Lock1394"); KernelLog.Ln();
			FOR i:= 0 TO (packet.dataSize DIV 4)-1 DO
				FirewireLowUtil.PrintSet(packet.data[i])
			END; *)

			packet.generation:= generation;

			IF (~SendPacket1394(context,packet)) THEN (* something went wrong, so try it again *)
				KernelLog.String("Something went wrong:: Lock1394"); KernelLog.Ln();
				OHCI.labeler.FreeTransLabel(packet.tLabel);
				RETURN success
			ELSE KernelLog.String("Everything ok::Lock1394"); KernelLog.Ln();
			END;

			success:= FirewireLowUtil.TestIfSuccess(packet);

			IF success THEN data:= packet.data[0] END;

			(* Release Packet *)
			OHCI.labeler.FreeTransLabel(packet.tLabel);
			OHCI.packetFIFO.ReleasePacket(packet);

			RETURN success

		END Lock1394;

		(** Creates a write packet *)
		PROCEDURE Write1394*(context: Contest; ohci: FirewireLowUtil.OHCIDesc; nodeID: SET; generation: LONGINT; VAR buffer: SET;  addrLow, addrHigh: SET;
			length: LONGINT):BOOLEAN;
		VAR packet: OHCIPacket; success: BOOLEAN; tries: LONGINT;
		BEGIN
			success:= FALSE; tries:= 0;

			IF length = 0 THEN RETURN success END;

			(* KernelLog.String("Write1394"); KernelLog.Ln();
			 FirewireLowUtil.PrintSet(addrHigh);
			FirewireLowUtil.PrintSet(addrLow); *)
			packet:= FirewireLowUtil.MakeWritePacket(ohci,nodeID,addrLow,addrHigh,buffer,length);
			packet.generation:= generation;

			WHILE (~success) &  (tries < 4)  DO
			(* IF (~SendPacket1394(context,packet)) THEN  (* something went wrong, so try it again *)
				KernelLog.String("Something went wrong:: Write1394"); KernelLog.Ln();
				OHCI.labeler.FreeTransLabel(packet.tLabel);
				RETURN success
			ELSE (* KernelLog.String("Everything ok::Write1394"); KernelLog.Ln(); *) *)
				IF (SendPacket1394(context,packet)) THEN success:= TRUE
				ELSE INC(tries); KernelLog.String("Something went wrong:: Write1394"); KernelLog.Ln();
				END
			END;

			IF ~success THEN
				KernelLog.String("Something went wrong:: Write1394"); KernelLog.Ln();
				OHCI.labeler.FreeTransLabel(packet.tLabel);
				RETURN success
			END;

			success:= FirewireLowUtil.TestIfSuccess(packet);
			IF ~success THEN KernelLog.String("Not successfull:: Read1394"); KernelLog.Ln(); END;

			(* Release Packet *)
			OHCI.labeler.FreeTransLabel(packet.tLabel);
			OHCI.packetFIFO.ReleasePacket(packet);

			RETURN success
		END Write1394;

		(** Creates a read packet *)
		PROCEDURE Read1394*(context: Contest; ohci: FirewireLowUtil.OHCIDesc; nodeID: SET;generation: LONGINT; addrLow,addrHigh:SET;
		VAR buffer: SET; length: LONGINT):BOOLEAN;
		VAR packet: OHCIPacket; success: BOOLEAN; tries,i: LONGINT;
		BEGIN
			(* KernelLog.String("Read1394"); KernelLog.Ln(); *)
			success:= FALSE; tries:= 0;

			IF length = 0 THEN RETURN success END;

			packet:= FirewireLowUtil.MakeReadPacket(ohci,nodeID,addrLow,addrHigh,length);

			packet.generation:= generation;

			WHILE (~success) &  (tries < 4)  DO
			(*IF (~SendPacket1394(context,packet)) THEN (* something went wrong, so try it again *)
				KernelLog.String("Something went wrong:: Read1394"); KernelLog.Ln();
				OHCI.labeler.FreeTransLabel(packet.tLabel);
				RETURN success
			ELSE (* KernelLog.String("Everything ok::Read1394"); KernelLog.Ln(); *) *)
				IF (SendPacket1394(context,packet)) THEN success:= TRUE
				ELSE INC(tries)
				END
			END;

			IF ~success THEN
				KernelLog.String("Something went wrong:: Read1394"); KernelLog.Ln();
				OHCI.labeler.FreeTransLabel(packet.tLabel);
				RETURN success
			END;

			success:= FirewireLowUtil.TestIfSuccess(packet);

			IF success THEN
				(* KernelLog.String("Packet was successfull::read1394"); KernelLog.Ln(); *)
				IF length = 4 THEN (* It's a read quadlet packet *)
					buffer:= packet.header[3];
				ELSE (* It's a read block packet *) (* in this case buffer is an address *)
					FOR i:= 0 TO (length DIV 4)-1 DO
						SYSTEM.PUT32(ConvertToLongint(buffer) + i*4,packet.data[i])
					END
				END
			ELSE KernelLog.String("Packet was not successfull!"); KernelLog.Ln();
			END;

			(* Release Packet *)
			OHCI.labeler.FreeTransLabel(packet.tLabel);
			OHCI.packetFIFO.ReleasePacket(packet);

			RETURN success
		END Read1394;

		(** Node manager relative part *)

		(** Sends a read quadlet packet *)
		PROCEDURE NodeManagerReadQ(context: Contest; host:FirewireLowUtil.OHCIDesc; nodeID: SET; generation: LONGINT;
			addrLow,addrHigh: SET;  VAR quad: SET):BOOLEAN;
		VAR success: BOOLEAN; i: LONGINT;
		BEGIN
			success:= FALSE; i:= 0;
			WHILE ~success & (i < 4) DO
				success:= Read1394(context,host,nodeID,generation,addrLow,addrHigh,quad,4);
				IF ~success THEN INC(i) END;
			END;

			IF i>=1 THEN KernelLog.String("Something went wrong::NodeManagerReadQ"); KernelLog.Ln()
			ELSE (* KernelLog.String("Everything ok::NodeManagerReadQ"); KernelLog.Ln(); *)
			END;

			RETURN success
		END NodeManagerReadQ;

		(** Reads the bus info block of a node *)
		PROCEDURE ReadBusInfoBlock(host: FirewireLowUtil.OHCIDesc; nodeID: SET; generation: LONGINT; VAR buffer: ARRAY OF SET;
			bufferLength: LONGINT):BOOLEAN;
		VAR addrLow,addrHigh, base: SET; i, headerSize: LONGINT; vendorID: LONGINT; context: Contest;
		BEGIN
			addrHigh:= FirewireLowUtil.CSRBaseHigh;
			addrLow:= FirewireLowUtil.CSRBaseLow + FirewireLowUtil.CSRConfigRom;

			(*
			KernelLog.String("The base low address is: "); FirewireLowUtil.PrintSet(addrLow); KernelLog.Ln();
			KernelLog.String("The base high address is: "); FirewireLowUtil.PrintSet(addrHigh); KernelLog.Ln();
			KernelLog.String("Reading bus info block of node with nodeID: "); KernelLog.Int(SYSTEM.VAL(LONGINT,nodeID),2);
			KernelLog.Ln(); *)

			buffer[0]:= {};

			context:= OHCI.ATController.GetReqContest();
			(* sometimes the device is not ready yet *)
			WHILE (buffer[0] = {}) & (i<1) DO
				IF ~NodeManagerReadQ(context,host,nodeID,generation,addrLow,addrHigh,buffer[0]) THEN
					KernelLog.String("Quadlet read error!"); KernelLog.Ln(); INC(i) END;

			END;

			(* KernelLog.String("(((((((((((((((((((((((((Going on))))))))))))))))))))))))))))))))"); KernelLog.Ln(); *)

			IF i>=1 THEN KernelLog.String("Error: DEVICE was not ready::ReadBusInfoBlock!");KernelLog.Ln();
				RETURN TRUE
			END;

			headerSize:= SYSTEM.VAL(LONGINT,LSH(buffer[0],-24));

			(* Increment address *)

			addrLow:= SYSTEM.VAL(SET,SYSTEM.VAL(LONGINT,addrLow)+4);

			IF headerSize = 1 THEN
				(* KernelLog.String("Node has a minimal rom format!"); KernelLog.Ln(); *)
				vendorID:= SYSTEM.VAL(LONGINT,buffer[0]*{0..23});
				(* KernelLog.String("The vendor ID is: "); KernelLog.Int(vendorID,2); KernelLog.Ln(); *)
				RETURN FALSE
			END;

			IF headerSize < 4 THEN
				KernelLog.String("Non standard rom format, cannot parse!"); KernelLog.Ln(); RETURN TRUE
			END;

			FOR i:= 1 TO bufferLength-1 DO
				(* KernelLog.String("Reading the quadlet number: "); KernelLog.Int(i,2); KernelLog.Ln(); *)
				IF ~NodeManagerReadQ(context,host,nodeID,generation,addrLow,addrHigh,buffer[i]) THEN
					KernelLog.String("Quadlet read error!"); KernelLog.Ln(); RETURN TRUE
				END;
				addrLow:= base + SYSTEM.VAL(SET,SYSTEM.VAL(LONGINT,addrLow)+4);
			END;

			vendorID:= SYSTEM.VAL(LONGINT,LSH(buffer[3],-8));

			(* KernelLog.String("The vendorID is "); KernelLog.Int(vendorID,2); KernelLog.Ln(); *)

			RETURN FALSE;

		END ReadBusInfoBlock;

		(** End node manager relative part *)

		(** Prints OHCI information *)
		PROCEDURE PrintOHCIInfo;
		VAR reg: SET; val: LONGINT;
		BEGIN
			reg:= FirewireLowUtil.ReadReg(FirewireLowUtil.Version);
			KernelLog.String("Printing the OHCI information:"); KernelLog.Ln();
			val:= LSH(ConvertToLongint(reg*{16..23}),-16);
			KernelLog.String("OHCI version: "); KernelLog.Int(val,2); KernelLog.Ln();
			val:= ConvertToLongint(reg*{0..7});
			KernelLog.String("OHCI revision: "); KernelLog.Int(val,2); KernelLog.Ln();
			IF 24 IN reg THEN KernelLog.String("The OHCI has an GUIDROM"); KernelLog.Ln(); END;
			KernelLog.String("The OHCI is on interrupt: "); KernelLog.Int(irq,2); KernelLog.Ln();
			KernelLog.String("The max packet size is: "); KernelLog.Int(OHCI.MaxPacketSize,2); KernelLog.Ln();
			IF OHCI.ExstRegMap THEN
				KernelLog.String("The OHCI has an exstended register map conform to 1394a."); KernelLog.Ln();
			ELSE KernelLog.String("The OHCI has no exstended register map."); KernelLog.Ln();
			END;
			IF OHCI.IsRoot THEN
				KernelLog.String("The OHCI is root."); KernelLog.Ln();
			ELSE KernelLog.String("The OHCI is not root."); KernelLog.Ln()
			END;
			IF OHCI.IsIRM THEN
				KernelLog.String("The OHCI is isochronous resource manager"); KernelLog.Ln();
			ELSE KernelLog.String("The OHCI is not isochronous resource manager"); KernelLog.Ln()
			END;
			IF OHCI.IsBM THEN
				KernelLog.String("The OHCI is bus manager"); KernelLog.Ln();
			ELSE KernelLog.String("The OHCI is not bus manager"); KernelLog.Ln()
			END
		END PrintOHCIInfo;

		(** Tests if access to a register was successfull *)
		PROCEDURE TestAccess(name:ARRAY OF CHAR); (* not used *)
			VAR reg:SET;
		BEGIN
			reg := FirewireLowUtil.ReadReg(FirewireLowUtil.IntEvent);
			IF(18 IN reg) THEN KernelLog.String("RegAccess ");KernelLog.String(name);KernelLog.String(" failed");KernelLog.Ln;
			ELSE KernelLog.String("RegAccess ");KernelLog.String(name);KernelLog.String(" successfull");KernelLog.Ln;
			END
		END TestAccess;

		(** Removes the interrupt handler *)
		PROCEDURE Cleanup;
		BEGIN
			Objects.RemoveHandler(HandleInterrupt,Machine.IRQ0+irq);
		END Cleanup;

	END Controller;

VAR c*:Controller;

(** Procedure to print the specifier ID of a node; not used *)
PROCEDURE ScanRomOfNodes*;
VAR j,i:LONGINT; node: FirewireLowUtil.Node;
BEGIN
	c.ScanNodes();
	(* Printing the content of the nodes array *)
	i:= 0; j:= 0;
	WHILE c.OHCI.Nodes[i] # NIL DO
		node:= c.OHCI.Nodes[i];
		KernelLog.String("Printing the guid: "); KernelLog.Ln();
		(* FirewireLowUtil.PrintSet(node.guid.high); FirewireLowUtil.PrintSet(node.guid.low); *)
		KernelLog.String("Printing the unit directories if there are any"); KernelLog.Ln();
		WHILE node.uds[j] # NIL DO
			KernelLog.String("Printing the specifier id: "); KernelLog.Int(node.uds[j].specifierID,2); KernelLog.Ln();
			INC(j);
		END;
		INC(i);
	END;
END ScanRomOfNodes;

(** Test procedure to send a ping packet *)
PROCEDURE SendPingPacket*;
VAR context: Contest;set0,set1,set2,set3,set4,set5,set6,set7: SET;
	dataSize: LONGINT; packet: OHCIPacket; block: FirewireLowUtil.Block;
BEGIN
	context:= c.OHCI.ATController.GetReqContest();
	set0:= {28} + {25} + {23} + {20,21} + {18,19} + {2,3};
	set1:= {};
	set2:= {};
	set3:= {};
	set4:= {5,6,7};
	set5:= {};
	set6:= -set5;
	set7:= {};


	packet.type:= FirewireLowUtil.async;
	dataSize:= 0;
	block.start:= context.prgr.bufferAddr;
	block.end:= block.start;
	SYSTEM.PUT32(context.prgr.bufferAddr,set0);
	SYSTEM.PUT32(context.prgr.bufferAddr+4,set1);
	SYSTEM.PUT32(context.prgr.bufferAddr+8,set2);
	SYSTEM.PUT32(context.prgr.bufferAddr+12,set3);
	SYSTEM.PUT32(context.prgr.bufferAddr+16,set4);
	SYSTEM.PUT32(context.prgr.bufferAddr+20,set5);
	SYSTEM.PUT32(context.prgr.bufferAddr+24,set6);
	SYSTEM.PUT32(context.prgr.bufferAddr+28,set7);

	packet.block:= block;

	FirewireLowUtil.WriteReg(context.cmdPtr,FirewireLowUtil.ConvertToSet(context.prgr.bufferAddr+2));

	FirewireLowUtil.WriteReg(context.ctrlSet,{15});

	context.listInserted.AddPacket(packet);
END SendPingPacket;

(** Test procedure to send a read packet *)
PROCEDURE SendReadPacket*;
VAR context: Contest; set0, set1, set2, set3, set4, set5, set6, set7: SET;
	dataSize: LONGINT; packet: OHCIPacket; block: FirewireLowUtil.Block;
BEGIN
	context:= c.OHCI.ATController.GetReqContest();
	set0:= {28} + {25} + {20,21} + {18,19} + {2,3};
	set1:= {};
	set2:= {};
	set3:= {};
	set4:= {8} + {6};
	set5:= {22..31} + {0..15};
	set6:= {28..31} + {2,3,4,9}; (* bus manager id *)
	set7:= {};

	NEW(packet,16,0);
	packet.type:= FirewireLowUtil.async;
	packet.tLabel:= {}; packet.tCode:= {2};
	dataSize:= 0;
	block.start:= context.prgr.bufferAddr;
	block.end:= block.start;

	packet.header[0]:= set4;
	packet.header[1]:= set5;
	packet.header[2]:= set6;
	packet.header[3]:= set7;

	packet.name:= "vito";

	SYSTEM.PUT32(context.prgr.bufferAddr,set0);
	SYSTEM.PUT32(context.prgr.bufferAddr+4,set1);
	SYSTEM.PUT32(context.prgr.bufferAddr+8,set2);
	SYSTEM.PUT32(context.prgr.bufferAddr+12,set3);
	SYSTEM.PUT32(context.prgr.bufferAddr+16,set4);
	SYSTEM.PUT32(context.prgr.bufferAddr+20,set5);
	SYSTEM.PUT32(context.prgr.bufferAddr+24,set6);
	SYSTEM.PUT32(context.prgr.bufferAddr+28,set7);

	packet.block:= block;

	FirewireLowUtil.WriteReg(context.cmdPtr,FirewireLowUtil.ConvertToSet(context.prgr.bufferAddr+2));

	context.listInserted.AddPacket(packet);
	context.listAwaiting.AddPacket(packet);
	IF ~context.listAwaiting.GetPacket(packet) THEN
		KernelLog.String("Printing packet name: "); KernelLog.String(packet.name); KernelLog.Ln()
	ELSE
		KernelLog.String("We have a problem"); KernelLog.Ln()
	END;
	FirewireLowUtil.WriteReg(context.ctrlSet,{15});
END SendReadPacket;

(** Send a compare swap lock packet to hd to access maint-utility register *)
PROCEDURE SendLockPacket*;
VAR nodeID: SET; context: Contest; generation: LONGINT; addrLow, addrHigh: SET; extCode: LONGINT; data, arg: SET;
BEGIN
	extCode:= 2H; (* compare swap extended transaction code *)
	addrLow:= FirewireLowUtil.CSRBaseLow; addrHigh:= FirewireLowUtil.CSRBaseHigh;
	(* set the address of the maint utility register *)
	addrLow:= addrLow + {4,5,9};
	context:= c.OHCI.ATController.GetReqContest();
	nodeID:= {};
	generation:= FirewireLowUtil.GetGeneration();
	data:= {0..31}; arg:= {};
	IF c.Lock1394(context,c.OHCI,nodeID,generation,addrLow,addrHigh,extCode,data,arg) THEN
		KernelLog.String("First read was successfull::SendLockPacket"); KernelLog.Ln();
		KernelLog.String("Printing old value: "); FirewireLowUtil.PrintSet(data); KernelLog.Ln()
	ELSE
		KernelLog.String("Something went wrong::SendLockPacket"); KernelLog.Ln();
	END;
END SendLockPacket;

(** Test procedure to send a write packet *)
PROCEDURE SendWritePacket*;
VAR nodeID: SET; context: Contest; generation: LONGINT; addrLow, addrHigh: SET;
	buffer: ARRAY 1 OF SET;
BEGIN
	addrLow:= FirewireLowUtil.CSRBaseLow; addrHigh:= FirewireLowUtil.CSRBaseHigh;
	(* set the address of the maint utility register *)
	addrLow:= addrLow + {4,5,9};
	context:= c.OHCI.ATController.GetReqContest();
	nodeID:= {};
	buffer[0]:= {0..31};
	generation:= FirewireLowUtil.GetGeneration();
	IF c.Write1394(context,c.OHCI,nodeID,generation,buffer[0],addrLow,addrHigh,4) THEN
		KernelLog.String("Write was successfull::SendWritePacket"); KernelLog.Ln();
		(* KernelLog.String("Printing old value: "); FirewireLowUtil.PrintSet(data); KernelLog.Ln() *)
	ELSE
		KernelLog.String("Something went wrong::SendLockPacket"); KernelLog.Ln();
	END;
END SendWritePacket;

(** Test procedure to read the bus info block *)
PROCEDURE Test1394*;
VAR ohci: FirewireLowUtil.OHCIDesc; generation: LONGINT; sid: FirewireLowUtil.SelfID;
	buffer: ARRAY 4 OF SET; i: LONGINT;
BEGIN
 ohci:= c.OHCI; generation:= FirewireLowUtil.GetGeneration(); i:= 0;
 WHILE ohci.TopologyMap[i] # NIL DO
 	IF ~(ohci.TopologyMap[i] IS FirewireLowUtil.ExtSelfID) &
 		(SYSTEM.VAL(LONGINT,ohci.TopologyMap[i].physicalID) # c.OHCI.nodeID) THEN
 		sid:= ohci.TopologyMap[i];
 		IF c.ReadBusInfoBlock(ohci,sid.physicalID,generation,buffer,4) THEN
 			KernelLog.String("There was a problem reading the bus info block::Test1394!"); KernelLog.Ln()
 		END
 	END;
 	INC(i);
 END;
END Test1394;

(** Scan the PCI for 1394 devices *)
PROCEDURE ScanPCI(vendor,device: LONGINT);
VAR index, bus, dev, fct,res,base,irq:LONGINT;
BEGIN
	index := 0;
	WHILE(PCI.FindPCIDevice(device, vendor, index, bus, dev, fct) = PCI.Done) (*?*)
	DO
		(* KernelLog.String("Ok");
		KernelLog.Ln; *)
		res := PCI.ReadConfigDword(bus,dev,fct,PCI.Adr0Reg,base);
		ASSERT(res = PCI.Done);
		ASSERT(~ODD(base)); (* Operational registers mapped correctly in main memory memory space *)
		DEC(base, base MOD 16);
		Machine.MapPhysical(base,800H,SYSTEM.VAL(ADDRESS,base));
		res := PCI.ReadConfigByte(bus,dev,fct,PCI.IntlReg,irq);
		(* KernelLog.Int(irq,2);
		KernelLog.Ln; *)
		ASSERT(res = PCI.Done);
		INC(index);
		(* Set base in helper module *)
		(* KernelLog.Int(base,2); *)
		FirewireLowUtil.SetBase(base);
		NEW(c,base,irq);
	END;
END ScanPCI;

(** Dummy procedure *)
 PROCEDURE Install*;
END Install;

(** Cleanup procedure *)
PROCEDURE Cleanup;
BEGIN
	c.Cleanup();
END Cleanup;

(** Module initialization procedure *)
PROCEDURE Init;
BEGIN
	(* KernelLog.String("Entering ScanPCI");
	KernelLog.Ln; *)
	ScanPCI(1106H,3044H);
END Init;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Init
END FirewireLow.

System.Free FirewireLow~

Builder.Compile \s *
Aos.Call FirewireLow.Install ~
Aos.Call FirewireLowUtil.PrintSelfIDCount ~
Aos.Call FirewireLow.TestReset ~
System.OpenKernelLog