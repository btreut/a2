MODULE FirewireLowUtil; (** AUTHOR "VIP"; PURPOSE "IEEE 1394 Generic Driver Utilities"; *)

IMPORT SYSTEM, KernelLog;

CONST
	(* 1394 in ASCII *)
	BusIDNumber* = 31333934H;
	(* CSR Registers *)
	CSRBaseLow* = {28..31};
	CSRBaseHigh* = {0..15};
	CSRConfigRom*= {10};

	(* root directory entries *)
	ConfigRomLogicalUnitNumber*= 14H;
	ConfigRomVendorID*= 03H;
	ConfigRomModelID*= 17H;
	ConfigRomNodeCapabilities*= 0CH;
	ConfigRomUnitDirectory*= 0D1H;
	ConfigRomLogicalUnitDirectory*= 0D4H;
	ConfigRomSpecifierID*= 12H;
	ConfigRomUnitSWVersion*= 13H;
	ConfigRomDescriptorLeaf*= 81H;
	ConfigRomDescriptorDirectory*= 0C1H;

	(* offsets *)
	CSRTopologyMapStart* = 01000H;
	CSRTopologyMapEnd = 1400H;
	CSRSpeedMapStart = 2000H;
	CSRSpeedMapEnd = 3000H;

	(* Packet constants *)
	QUEUED* = 0;
	PENDING* = 1;
	COMPLETE* = 2;
	INCOMING* = 3;
	UNUSED* = 4;

	maxBlock = 10;
	REQU = 0; RESP = 1;

	(* Response codes *)
	respComplete*= 0;
	respConflictError=4;
	respDataError=5;
	respTypeError=6;
	respAddressError*=7;

	(* Extended transaction codes *)
	MaskSwap= 0001H;
	CompareSwap= 0002H;
	FetchAdd= 0003H;
	LittleAdd = 0004H;
	BoundedAdd = 0005H;
	WrapAdd = 0006H;

	(* Event and ack codes *)
	EvtNoStatus*= 0H; (* No event status *)
	EvtReserved1*= 1H;
	EvtLongPacket*= 2H; (* The received data length was greater than the buffer's data length *)
	EvtMissingAck*= 3H; (* A subaction gap was detected before an ack arrived or the received ack had a parity error *)
	EvtUnderrun*= 4H; (* Underrun on the corresponding FIFO. The packet was truncated *)
	EvtOverrun*= 5H; (* A receive FIFO overflowed during the reception of an isochronous packet *)
	EvtDescriptorRead*= 6H;
	EvtDataRead*= 7H;
	EvtDataWrite*= 8H;
	EvtBusReset*= 9H;
	EvtTimeout*= 0AH;
	EvtTcodeErr*= 0BH;
	EvtReserved2*= 0CH;
	EvtReserved3*= 0DH;
	EvtUnknown*= 0EH;
	EvtFlushed*= 0FH;
	EvtReserved4*= 10H;
	AckComplete*= 11H;
	AckPending*= 12H;
	EvtReserved5*= 13H;
	AckBusyX*= 14H;
	AckBusyA*= 15H;
	AckBusyB*= 16H;
	EvtReserved6*= 17H;
	EvtReserved7*= 18H;
	EvtReserved8*= 19H;
	EvtReserved9*= 1AH;
	AckTardy*= 1BH;
	EvtReserved10*= 1CH;
	AckDataError*= 1DH;
	AckTypeError*= 1EH;
	EvtReserved11*= 1FH;
	AckError*= -1;

	(* tcodes *)
	QWriteATReq* = 0H;
	BWriteATReq* = 1H;
	NoDataWATReq* = 4H;
	BReadATReq* = 5H;
	LockATReq* = 9H;
	StreamATReq* = 0AH;
	PhyATReq* = 0EH;
	NoDataWATRes* = 2H;
	QReadATRes* = 6H;
	BReadATRes* = 7H;
	LockATRes* = 0BH;
	QWriteARReq* = 0H;
	BWriteARReq* = 1H;
	NoDataQRARReq* = 4H;
	BReadARReq* = 5H;
    	LockARReq* = 9H;
	PhyARReq* = 0EH;
	NoDataWARRes* = 2H;
	QReadARRes* = 6H;
	BReadARRes* = 7H;
	LockARRes* = 0BH;
	ITCode* = 0AH;
	IRCode* = 0AH;
	CycleStartCode* = 8H;

	Version*= 0H;
	MaxPhysRespRetries*= {10}; (* eight retries *)
	MaxATReqRetries*= {1}; (* two retries *)
	MaxATRespRetries*= {5}; (* two retries *)
	BufSize*= 4096;
	(* contest type *)
	ISO*= 0;
	REQ*= 1;
	RES*= 2;
	(* packet type *)
	async* = {};
	iso* = {0};
	raw* = {1};
	IntMask* =  088H;
	CIntMask*= 08CH;
	SelfIDCount* = 068H;
	SelfIDBuffer* = 064H;
	HCControl* = 050H;
	IntEvent* = 080H;
	CIntEvent* = 084H;
	PhyControl* = 0ECH;
	LinkControl* = 0E0H;
	CLinkControl* = 0E4H;
	softReset* = 16;
	NodeID* = 0E8H;
	BusID* = 01CH;
	ConfigRomMap* = 034H;
	ARReqComPtr* = 1CCH;
	ARResComPtr* = 1ECH;
	ATResComPtr* = 1ACH;
	ATReqComPtr* = 18CH;
	isoRecvIntMaskSet* = 0A8H;
	isoRecvIntMaskClear* = 0ACH;
	isoXmitIntMaskSet* = 098H;
	isoXmitIntMaskClear* = 09CH;
	IRComPtr* = 40CH;
	ITComPtr* = 20CH;
	BusOptions* = 020H;
	postedWriteEnable = 18;
	isochXmitCntCtrlClear* = 204H;
	isochXmitCntCtrlSet* = 200H;
	isochRecvCntCtrlSet* = 400H;
	isochRecvCntCtrlClear* = 404H;
	isochRecvContMatch* = 410H;
	isochRecvIntEvntClear* = 0A4H;
	isochRecvIntEvntSet* = 0A0H;
	isochRecvIntMaskClear* = 0ACH;
	isochRecvIntMaskSet* = 0A8H;
	isochXmitIntEvntSet* = 090H;
	isochXmitIntEvntClear* = 094H;
	isochXmitIntMaskSet* = 098H;
	isochXmitIntMaskClear* = 09CH;
	IRmultiChanMaskLoClear* = 07CH;
	IRmultiChanMaskLoSet* = 078H;
	IRmultiChanMaskHiClear* = 074H;
	IRmultiChanMaskHiSet* = 070H;
	ARReqContCtrlSet* = 1C0H;
	ARReqContCtrlClear* = 1C4H;
	ARResContCtrlSet* = 1E0H;
	ARResContCtrlClear* = 1E4H;
	ATReqContCtrlSet* = 180H;
	ATReqContCtrlClear* = 184H;
	ATResContCtrlSet* = 1A0H;
	ATResContCtrlClear* = 1A4H;
	ARFilterHISet* = 100H;
	ARFilterHIClaer* = 104H;
	ARFilterLowSet* = 108H;
	ARFilterLowClear* = 10CH;
	PRFilterHiSet*= 110H;
	PRFilterHiClear*= 114H;
	PRFilterLowSet*= 118H;
	PRFilterLowClear*= 11CH;
	PhyUpperBound*= 120H;
	ATRetries* = 008H;
	isochCycleTimer* = 0F0H;
	CSRData*= 00CH;
	CSRCompare*= 010H;
	CSRControl*= 014H;

TYPE
	FIFONode*= POINTER TO NodeDesc;

	(** Data structure used only by lists *)
	NodeDesc*= RECORD
		packet: OHCIPacket;
		pListMember*: POINTER TO ListMember; (* used only by List *)
		next: FIFONode;
	END;

	(** FIFO list pointer *)
	FIFO = RECORD
		first, last: FIFONode
	END;

	(** FIFO list *)
	FIFOList= OBJECT

		PROCEDURE Enqueue*(VAR q: FIFO; n: FIFONode);
		BEGIN
			n.next:= NIL;
			IF q.first # NIL THEN q.last.next := n ELSE q.first := n END;
			q.last := n;
		END Enqueue;

		PROCEDURE DequeuedNode*(VAR q: FIFO): FIFONode;
		VAR n: FIFONode;
		BEGIN
			n := q.first;
			IF n # NIL THEN q.first := n.next END;
			RETURN n
		END DequeuedNode;

	END FIFOList;

	(** FIFO list for packets *)
	PacketFIFO*= OBJECT
	VAR q,usedQ: FIFO; list,usedList: FIFOList; bufSize: LONGINT;

		PROCEDURE GetPacket*():OHCIPacket;
		VAR n:FIFONode; packet: OHCIPacket;
		BEGIN {EXCLUSIVE}
			n:=list.DequeuedNode(q); (* Print(debug,"Dequeuning node"); *)
			IF n =  NIL THEN KernelLog.String("Allocating new buffer!"); KernelLog.Ln();
				NEW(n); NEW(packet,0,bufSize); n.packet:= packet;
			END;
			usedList.Enqueue(usedQ,n);
			(* Print(debug,"Returning address!");
			KernelLog.Int(n.bufAddr,2); *)
			RETURN n.packet
		END GetPacket;

		PROCEDURE ReleasePacket*(packet: OHCIPacket);
		VAR n: FIFONode;
		BEGIN {EXCLUSIVE}
			n:= usedList.DequeuedNode(usedQ);
			n.packet:= packet;
			list.Enqueue(q,n);
		END ReleasePacket;

		PROCEDURE &Init*(numOfPacket :LONGINT);
		VAR n: FIFONode;i: LONGINT; packet: OHCIPacket;
		BEGIN {EXCLUSIVE}
			bufSize:= GetMaxPcktSize();
			NEW(list);NEW(usedList);
			IF numOfPacket > 0 THEN
				FOR i:= 0 TO numOfPacket-1 DO
					NEW(n);
					NEW(packet,0,bufSize);
					n.packet:= packet;
					list.Enqueue(q,n)
				END
			END
		END Init;

	END PacketFIFO;

	(** Used to hold addresses that must be checked before being accessed *)
	AddressChecker*= OBJECT
	VAR index: LONGINT; addrs: ARRAY 100 OF LONGINT;

		PROCEDURE Add*(adr: LONGINT);
		BEGIN
			addrs[index]:= adr;
			index:= index MOD 100;
		END Add;

		PROCEDURE Find*(adr: LONGINT): BOOLEAN;
		VAR i: LONGINT; found: BOOLEAN;
		BEGIN
			found:= FALSE;
			WHILE ~found & (i # 100) DO
				IF addrs[i] = adr THEN found:= TRUE END;
				INC(i);
			END;
		END Find;

		PROCEDURE &Init*;
		BEGIN
			index:= 0;
		END Init;

	END AddressChecker;


	CharBuffer*= POINTER TO ARRAY OF CHAR;

	(** Data structure that represents a unit directory *)
	UnitDirectory*= OBJECT
	VAR
		addrHigh*: SET;
		addrLow*: SET;

		vendorID*: LONGINT;
		vendorNameSize*: LONGINT;

		modelID*: LONGINT;
		modelNameSize*: LONGINT;

		specifierID*: LONGINT;
		version*: LONGINT;

		ID*: LONGINT;

		length: LONGINT;
		udEntries*: POINTER TO ARRAY OF SET;

		hasLogicalUnitDir*: BOOLEAN;
		luns*: ARRAY 10 OF UnitDirectory;

		PROCEDURE GetLength*():LONGINT;
		BEGIN
			RETURN length
		END GetLength;

		PROCEDURE &Init*(length: LONGINT);
		VAR i: LONGINT;
		BEGIN
			hasLogicalUnitDir:= FALSE;
			SELF.length:= length;
			NEW(udEntries,length);
			FOR i:= 0 TO 9 DO
				luns[i]:= NIL;
			END
		END Init;

	END UnitDirectory;

	(** Data structure for the global user id *)
	GUID*= RECORD
		low*: SET;
		high*: SET;
	END;

	(** Bus options *)
	BusOpt*= RECORD
		irmc*: BOOLEAN;
		cmc*: BOOLEAN;
		isc*: BOOLEAN;
		bmc*: BOOLEAN;
		pmc*: BOOLEAN;
		cycClkAcc*: LONGINT;
		maxRec*: LONGINT;
		generation*: LONGINT;
		linkSpd*: LONGINT;
	END;

	(** 1394 Node *)
	Node*= OBJECT
	VAR
		capabilities*: SET;
		phyID*: SET;
		linkAct: BOOLEAN;
		phySpeed: SET;
		delay: SET;
		contender: BOOLEAN;
		pwrClass: SET;
		portStatus: ARRAY 16 OF SET;
		guid*: GUID;
		vendorID*: LONGINT;
		generation*: LONGINT;
		probe*: BOOLEAN;
		busOptions*: BusOpt;
		uds*: ARRAY 10 OF UnitDirectory; (* should be enough *)

	PROCEDURE Update*(busOptions: SET; physicalID: SET; generation: LONGINT);
	BEGIN
		IF physicalID # phyID THEN
			KernelLog.String("The physicalID has changed "); KernelLog.Ln();
			phyID:= physicalID
		END;

		IF SELF.busOptions.generation # generation THEN
			UpdateBusOpt(busOptions);
			probe:= TRUE
		END;

		SELF.generation:= generation;
	END Update;

	(* Updates the bus options *)
	PROCEDURE UpdateBusOpt(busOpt: SET);
	BEGIN
		IF 31 IN busOpt THEN busOptions.irmc:= TRUE ELSE busOptions.irmc:= FALSE END;
		IF 30 IN busOpt THEN busOptions.cmc:= TRUE ELSE busOptions.cmc:= FALSE END;
		IF 29 IN busOpt THEN busOptions.isc:= TRUE ELSE busOptions.isc:= FALSE END;
		IF 28 IN busOpt THEN busOptions.bmc:= TRUE ELSE busOptions.bmc:= FALSE END;
		IF 27 IN busOpt THEN busOptions.pmc:= TRUE ELSE busOptions.pmc:= FALSE END;
		busOptions.cycClkAcc:= SYSTEM.VAL(LONGINT,LSH(busOpt,-16)*{0..7});
		busOptions.maxRec:= LSH(SYSTEM.VAL(LONGINT,LSH(busOpt,-12)*{0..3})+1,1);
		busOptions.generation:= SYSTEM.VAL(LONGINT,LSH(busOpt,-4)*{0..3});
		busOptions.linkSpd:= SYSTEM.VAL(LONGINT,busOpt*{0..2});
	END UpdateBusOpt;

	PROCEDURE &Init*(guid: GUID; busOptions: SET; physicalID: SET; generation: LONGINT);
	VAR i: LONGINT;
	BEGIN
		SELF.guid:= guid; phyID:= physicalID; SELF.generation:= generation;
		vendorID:= SYSTEM.VAL(LONGINT,LSH(guid.high,-8)); probe:= TRUE; UpdateBusOpt(busOptions);
		FOR i:= 0 TO 9 DO
			uds[i]:= NIL;
		END;
	END Init;

	END Node;

	(** Is used to distribute the transaction labels *)
	LabelPool*= OBJECT
		VAR freeLabel: LONGINT;
			freeLabelField: ARRAY 64 OF BOOLEAN;

		PROCEDURE GetTransLabel*():SET;
		VAR i: LONGINT; found: BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF freeLabel = 0 THEN KernelLog.String("Awating free label!"); KernelLog.Ln();
				AWAIT(freeLabel > 0);
			END;
			(* search a free label *)
			(* KernelLog.String("Looking for a free label:: GetTransLabel "); KernelLog.Ln(); *)
			found:= FALSE; i:= 0;
			WHILE ~found DO
				IF freeLabelField[i] THEN  found:= TRUE; DEC(freeLabel);
					freeLabelField[i]:= FALSE
				ELSE INC(i)
				END
			END;
			(* KernelLog.String("Returning transaction label: "); KernelLog.Int(i,2); KernelLog.Ln(); *)
			RETURN ConvertToSet(i);
		END GetTransLabel;

		PROCEDURE FreeTransLabel*(lab: SET);
		VAR label: LONGINT;
		BEGIN {EXCLUSIVE} label:= SYSTEM.VAL(LONGINT,lab);
			freeLabelField[label]:= TRUE; (* KernelLog.String("Freeing transaction label"); KernelLog.Ln(); *)
			INC(freeLabel)
		END FreeTransLabel;

		PROCEDURE &Init*(freeLabel: LONGINT);
		VAR i: LONGINT;
		BEGIN SELF.freeLabel:= freeLabel;
		FOR i:= 0 TO freeLabel-1 DO
			freeLabelField[i]:=TRUE;
		END
		END Init;

	END LabelPool;

	(** Data structure used in lists *)
	ListMember*=RECORD
		next*: POINTER TO ListMember;
		data*: OHCIPacket;
	END;

	(** Another kind of FIFO list *)
	List*= OBJECT
		VAR head*: POINTER TO ListMember; last*: POINTER TO ListMember; usedList*,list*: FIFOList;
			 usedQ*,q*: FIFO;
		PROCEDURE AddPacket*(data: OHCIPacket);
		VAR temp: POINTER TO ListMember; n: FIFONode;
		BEGIN
			n:= list.DequeuedNode(q);
			IF n = NIL THEN NEW(temp); KernelLog.String("Run out of nodes in list!"); KernelLog.Ln(); ELSE temp:= n.pListMember; n.pListMember:= NIL; usedList.Enqueue(usedQ,n);
			END;
			last.next:= temp; temp.data:= data;
			last:= temp; last.next:= NIL;
		END AddPacket;

		PROCEDURE GetPacket*(VAR packet:OHCIPacket):BOOLEAN;
		VAR error: BOOLEAN;
		BEGIN
			error:= FALSE;
			IF (head.next # NIL)  THEN
				packet:= head.next.data;
			ELSE error:= TRUE END;
			RETURN error
		END GetPacket;

		PROCEDURE DelPacket*(VAR packet: OHCIPacket):BOOLEAN;
		VAR error: BOOLEAN; n: FIFONode;
		BEGIN
			error:= FALSE;
			IF (head.next # NIL)  THEN
				packet:= head.next.data;
				IF last = head.next THEN last:= head END;
				n:= usedList.DequeuedNode(usedQ);
				n.pListMember:= head.next;
				list.Enqueue(q,n);
				head.next:= head.next.next;
			ELSE error:= TRUE END;
			RETURN error
		END DelPacket;

		PROCEDURE &Init*(numOfPacket: LONGINT);
		VAR n: FIFONode; i: LONGINT;
		BEGIN
			NEW(head); head.next:= NIL; last:= head; NEW(usedList); NEW(list);
			IF numOfPacket > 0 THEN
				FOR i:= 0 TO numOfPacket-1 DO
					NEW(n);
					NEW(n.pListMember);
					list.Enqueue(q,n);
				END
			END
		END Init;

	END List;

	(** Data structure to represent self identification information of each node on the bus *)
	SelfID*= OBJECT (* 1394-1995 *)
	VAR
		packetIdentifier*: SET;
		physicalID*: SET;
		extended*: BOOLEAN;
		linkActive*: SET;
		gapCount*: SET;
		sp*: SET;
		del*: SET;
		c*: SET;
		pwr*: SET;
		p0*: SET;
		p1*: SET;
		p2*: SET;
		i*: SET;
		m*: SET;

		PROCEDURE &Init*(packetZero: SET);
		BEGIN
			packetIdentifier:= LSH(packetZero * {30,31},-30);
			physicalID:= LSH(packetZero * {24..29},-24);
			IF 23 IN packetZero THEN extended:= TRUE ELSE extended:= FALSE END;
			linkActive:= LSH(packetZero * {22},-22);
			gapCount:= LSH(packetZero * {16..21},-16);
			sp:= LSH(packetZero * {14,15},-14);
			del:= LSH(packetZero * {12,13},-12);
			c:= LSH(packetZero * {11},-11);
			pwr:= LSH(packetZero * {8..10},-8);
			p0:= LSH(packetZero * {6,7},-6);
			p1:= LSH(packetZero * {4,5},-4);
			p2:= LSH(packetZero * {2,3},-2);
			i:= LSH(packetZero * {1},-1);
			m:= packetZero * {0};
		END Init;

	END SelfID;

	(** Data structure used to hold extended selfidentification information *)
	ExtSelfID*= OBJECT(SelfID) (* 1394-1995 *)
	VAR
		seq*: SET;
		pa*: SET;
		pb*: SET;
		pc*: SET;
		pd*: SET;
		pe*: SET;
		pf*: SET;
		pg*: SET;
		ph*: SET;

		PROCEDURE &Init*(packetZero: SET);
		BEGIN
			packetIdentifier:= LSH(packetZero * {30,31},-30);
			physicalID:= LSH(packetZero * {24..29},-24);
			IF 23 IN packetZero THEN extended:= TRUE ELSE extended:= FALSE END;
			seq:= LSH(packetZero * {20..22},-20);
			pa:= LSH(packetZero * {16,17},-16);
			pb:= LSH(packetZero * {14,15},-14);
			pa:= LSH(packetZero * {12,13},-12);
			pa:= LSH(packetZero * {10,11},-10);
			pa:= LSH(packetZero * {8,9},-8);
			pa:= LSH(packetZero * {6,7},-6);
			pa:= LSH(packetZero * {4,5},-4);
			pa:= LSH(packetZero * {2,3},-2);
			m:= packetZero * {0};
		END Init;
	END ExtSelfID;

	(** Holds OHCI informatin and status *)
	OHCIDesc*= RECORD
		SelfIDErrors*: LONGINT;
		SelfIDBufferAdr*: SET;
		ptrToSelfIDBuf*: CharBuffer;
		ConfigRomBufferAdr*: SET;
		ptrToConfigRomBuf*: CharBuffer;
		MaxPacketSize*: LONGINT;
		ARDescNum*: LONGINT;
		ATDescNum*: LONGINT;
		IRDescNum*: LONGINT;
		ITDescNum*: LONGINT;
		IMDesc*: InputMoreDesc;
		inBusReset*: BOOLEAN;
		ARController*: ADMAController;
		ATController*: ADMAController;
		IRController*: IRDMAController;
		ITController*: ITDMAController;
		Nodes*: ARRAY 63 OF Node;
		IsRoot*: BOOLEAN;
		ExstRegMap*: BOOLEAN;
		IsIRM*: BOOLEAN;
		IsBM*: BOOLEAN;
		nodeID*: LONGINT;
		TopologyMap*: ARRAY 256 OF SelfID;
		SpeedMap*: ARRAY 64,64 OF LONGINT;
		numOfNodes*: LONGINT;
		labeler*: LabelPool;
		selfIDComplete*: BOOLEAN;
		adrCheck*: AddressChecker;
		packetFIFO*: PacketFIFO;
		tempBuffer*: POINTER TO ARRAY OF CHAR;
	END ;

	(** Represents an OHCI packet *)
	OHCIPacket*= OBJECT
	VAR
		host*: OHCIDesc;
		nodeID*: SET;
		type*: SET;
		header*: POINTER TO ARRAY OF SET; (* data from the response packet *)
		data*: POINTER TO ARRAY OF SET; (* holds data from the response packet if it's a read,from the request packet if it's a write/lock packet *)
		headerSize*: LONGINT;
		dataSize*: LONGINT;
		tCode*: SET;
		speed*: SET;
		ack*: SET;
		pending*: BOOLEAN;
		respExpected*: BOOLEAN;
		tLabel*: SET;
		generation*: LONGINT;
		state*: LONGINT;
		block*: Block; (* only needed when sending *)
		size*: LONGINT;
		name*: ARRAY 5 OF CHAR;
		blockBufferAddr*: ADDRESS;
		ptrToBlckBufAddr*: CharBuffer;

		PROCEDURE &Init*(hSize,dSize: LONGINT);
		BEGIN
			blockBufferAddr:= AllocATReqBuf(ptrToBlckBufAddr);
			headerSize:= hSize; dataSize:= dSize; size:= 0;
			IF headerSize = 0 THEN (* using embedded header *)
				headerSize:= 4*5 END;
			NEW(header,headerSize DIV 4); NEW(data,dataSize DIV 4);
			generation:= -1; state:= UNUSED;
		END Init;

	END OHCIPacket;

	(** Represents a descriptor block *)
	Block* = RECORD
		descNum*: LONGINT;
		start*: LONGINT;
		end*: LONGINT; (* Points to first quadlet of last descriptor *)
	END;

	(** Represents a context program *)
	Program* = OBJECT
		VAR blockBuffer*: BlockBuffer; bufferAddr*: LONGINT; j,blockNum: LONGINT; hasNext,result: BOOLEAN;
			branchAddressPtr, branchAddress: LONGINT; nextAddr*: LONGINT; packetOffset*: LONGINT; curDesc*: SET;
			ptrToBuf*: CharBuffer; oldPtrToBlck,ptrToBlck: CharBuffer;

		PROCEDURE SetBranchAddress*(address,ptr: LONGINT;newPtrToBlck: CharBuffer);
		BEGIN
			oldPtrToBlck:= ptrToBlck;
			ptrToBlck:= newPtrToBlck;
			(* set branchAddress in precedent block *)
			IF branchAddressPtr # 0 THEN
				branchAddress:= address; SYSTEM.PUT32(branchAddressPtr,branchAddress) END;
			(* update branchAddress pointer to this block and set Z to zero because this is the last block*)
			branchAddressPtr:= ptr; SYSTEM.PUT32(branchAddressPtr,{})
		END SetBranchAddress;

		(* Used to set the program buffer address *)
		 PROCEDURE SetBufferAddr*(addr: LONGINT);
		 BEGIN
		 	bufferAddr:= addr;
		 	(* nextAddr and curDesc represent basically the same thing *)
		 	nextAddr:= addr; (* just to initialize *)
		 	curDesc:= SYSTEM.VAL(SET,bufferAddr); (* just to initialize *)
		 END SetBufferAddr;

		 PROCEDURE GetBufferAddr*():LONGINT;
		 BEGIN
		 	RETURN bufferAddr;
		 END GetBufferAddr;

		 (* Block buffer holds free blocks, if there is no block left then one has to wait *)
		 PROCEDURE GetFreeBlocks*():LONGINT;
		 BEGIN
		 	RETURN blockBuffer.GetFreeBlocks()
		 END GetFreeBlocks;

		PROCEDURE &Init*;
		BEGIN
			NEW(blockBuffer,maxBlock); branchAddressPtr:= 0;ptrToBlck:= NIL;
			hasNext:= FALSE; j:= 0; blockNum:= 0; packetOffset:= 0;
		END Init;

	END Program;

	Packet* = ARRAY BufSize OF CHAR;

	(** Represents a DMA context *)
	Contest* = OBJECT
	VAR
		type*: LONGINT;
		prgr*: Program;
		procBuffer*: PacketBuffer; (* received packets *)
		cmdPtr*: LONGINT;
		ctrlSet*: LONGINT;
		ctrlClear*: LONGINT;
		name*: ARRAY 20 OF CHAR;
		listAwaiting*: List; (* packets awaiting an ack or a response after being sent from list inserted*)
		listPending*: List; (* packets to send *)
		listInserted*: List; (* sent packets coming from list pending*)
		tempBuffer*: ARRAY 1 OF SET;
		ptrToTmpBuf*: ARRAY 1 OF CharBuffer;
		buffers*: BufferBuffer;

		PROCEDURE &Init*(pcktNum,bufferNum: LONGINT);
		BEGIN
			NEW(listPending,100); NEW(listInserted,100); NEW(listAwaiting,100);
			NEW(procBuffer,pcktNum);
			NEW(prgr); NEW(buffers,bufferNum);
		END Init;

	END Contest;

	(** The isochronous receive context *)
	IRContest* =OBJECT(Contest)
	VAR match*: LONGINT;
	END IRContest;

	(** The isochronous transmit controller*)
	ITDMAController*= OBJECT
		VAR contests: POINTER TO ARRAY OF Contest; contest: Contest; i,j,avITCont: LONGINT; hasNext*:BOOLEAN;

		PROCEDURE GetNextContest*():Contest;
		BEGIN
			contest:= contests[j];
			INC(j);
			IF ~(j < avITCont) THEN hasNext:= FALSE; j:= 0 END;
			RETURN contest;
		END GetNextContest;

		PROCEDURE ResetIterator*;
		BEGIN
			IF avITCont > 0 THEN hasNext:= TRUE END
		END ResetIterator;

		PROCEDURE &Init*(contNum,pcktNum,bufferNum: LONGINT);
		BEGIN
			NEW(contests,contNum);
			FOR i:= 0 TO contNum-1 DO NEW(contest,pcktNum,contNum*bufferNum);
				contests[i]:= contest;
			END;
			j:= 0; avITCont:= contNum; IF avITCont > 0 THEN hasNext:= TRUE END
		END Init;
	END ITDMAController;

	(** The asynchronous controller *)
	ADMAController* = OBJECT
		VAR contests: POINTER TO ARRAY OF Contest; contest: Contest;

		PROCEDURE GetReqContest*(): Contest;
		BEGIN
			RETURN contests[REQU];
		END GetReqContest;

		PROCEDURE GetResContest*(): Contest;
		BEGIN
			RETURN contests[RESP];
		END GetResContest;

		PROCEDURE &Init*(pcktNum, bufferNum :LONGINT);
		BEGIN
			NEW(contests,2);
			NEW(contest,pcktNum,bufferNum);
			contests[REQU]:= contest;
			NEW(contest,pcktNum,bufferNum);
			contests[RESP]:= contest;
		END Init;
	END ADMAController;

	(** The isochronous controller *)
	IRDMAController*= OBJECT
		VAR contests: POINTER TO ARRAY OF IRContest; contest: IRContest; i,j,avIRCont*: LONGINT; hasNext*:BOOLEAN;

		PROCEDURE GetNextContest*():IRContest;
		BEGIN
			contest:= contests[j];
			INC(j);
			IF ~(j < avIRCont) THEN hasNext:= FALSE; j:= 0 END;
			RETURN contest;
		END GetNextContest;

		PROCEDURE GetContest*(n: LONGINT):IRContest;
		BEGIN
			RETURN contests[n]
		END GetContest;

		PROCEDURE ResetIterator*;
		BEGIN
			IF avIRCont > 0 THEN hasNext:= TRUE END
		END ResetIterator;

		PROCEDURE &Init*(contNum,pcktNum,bufferNum :LONGINT);
		BEGIN
			NEW(contests,contNum);
			FOR i:=0 TO contNum-1 DO NEW(contest,pcktNum,contNum*bufferNum);
				contests[i]:= contest
			END;
			j:= 0; avIRCont:= contNum; IF avIRCont > 0 THEN hasNext:= TRUE END
		END Init;

	END IRDMAController;

	(** This is a ring buffer for generic buffers *)
	BufferBuffer* = OBJECT
		VAR head, num: LONGINT; buffer: POINTER TO ARRAY OF SET;
		ptrToBuf: POINTER TO ARRAY OF CharBuffer;

		PROCEDURE FreeBuffer*(x: SET);
		BEGIN {EXCLUSIVE}
			AWAIT(num # LEN(buffer));
			buffer[(head+num) MOD LEN(buffer)] := x;
			INC(num)
		END FreeBuffer;

		PROCEDURE GetBuffer*(): SET;
		VAR x: SET;
		BEGIN {EXCLUSIVE}
			AWAIT(num # 0);
			x := buffer[head];
			head := (head+1) MOD LEN(buffer);
			DEC(num);
			RETURN x
		END GetBuffer;

		PROCEDURE &Init*(n: LONGINT);
		BEGIN
			head := 0; num := n; NEW(buffer, n); NEW(ptrToBuf, n);
			AllocPcktBuf(n,buffer^,ptrToBuf^);
		END Init;

	END BufferBuffer;

	(** This is a ring buffer for packet buffers *)
	PacketBuffer* = OBJECT
		VAR head, num: LONGINT; buffer: POINTER TO ARRAY OF Packet;

		PROCEDURE Append*(x: Packet);
		BEGIN {EXCLUSIVE}
			AWAIT(num # LEN(buffer));
			buffer[(head+num) MOD LEN(buffer)] := x;
			INC(num)
		END Append;

		PROCEDURE Remove*(): Packet;
		VAR x: Packet;
		BEGIN {EXCLUSIVE}
			AWAIT(num # 0);
			x := buffer[head];
			head := (head+1) MOD LEN(buffer);
			DEC(num);
			RETURN x
		END Remove;

		PROCEDURE GetPckt*(): Packet;
		VAR x: Packet;
		BEGIN {EXCLUSIVE}
			AWAIT(num # 0);
			x := buffer[head];
			RETURN x
		END GetPckt;

		PROCEDURE &Init*(n: LONGINT);
		BEGIN
			head := 0; num := 0; NEW(buffer, n)
		END Init;

	END PacketBuffer;

	(** This is a ring buffer for block buffers *)
	BlockBuffer* = OBJECT
		VAR head, (* free places in the fifo *) num*: LONGINT; buffer: POINTER TO ARRAY OF Block;

		PROCEDURE Append*(x: Block);
		BEGIN {EXCLUSIVE}
			AWAIT(num # LEN(buffer));
			buffer[(head+num) MOD LEN(buffer)] := x;
			INC(num);
		END Append;

		PROCEDURE Remove*(): Block;
		VAR x: Block;
		BEGIN {EXCLUSIVE}
			AWAIT(num # 0);
			x := buffer[head];
			head := (head+1) MOD LEN(buffer);
			DEC(num);
			RETURN x
		END Remove;

		PROCEDURE GetBlock*():Block;
		VAR x: Block;
		BEGIN {EXCLUSIVE}
			AWAIT(num # 0);
			x := buffer[head];
			RETURN x;
		END GetBlock;

		PROCEDURE GetFreeBlocks*():LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN num
		END GetFreeBlocks;

		PROCEDURE &Init*(n: LONGINT);
		BEGIN
			head := 0; num := 0; NEW(buffer, n)
		END Init;

	END BlockBuffer;

	(** A generic descriptor *)
	GeneralDesc*= RECORD
		control*: SET;
		address*: SET;
		branchAddress*: SET;
		status*: SET;
		data*: ARRAY 4 OF SET;
	END;

	(** Data structure for an input more descriptor *)
	InputMoreDesc* = RECORD
		cmd*: SET;
		s*: SET;
		key*: SET;
		i*: SET;
		b*: SET;
		w*:SET;
		reqCount*: SET;
		dataAddress*: SET;
		branchAddress*: SET;
		Z*: SET;
		xferStatus*: SET;
		resCount*: SET;
	END;

	(** Data structure for an input last descriptor *)
	InputLastDesc* = RECORD
		cmd*: SET;
		s*: SET;
		key*: SET;
		i*: SET;
		b*: SET;
		w*:SET;
		reqCount*: SET;
		dataAddress*: SET;
		branchAddress*: SET;
		Z*: SET;
		xferStatus*: SET;
		resCount*: SET;
	END;

	(** Data structure for an output more descriptor *)
	OutputMore*= RECORD
		cmd*: SET;
		key*: SET;
		b*: SET;
		resCount*: SET;
		reqCount*: SET;
		dataAddress*: SET;
	END;

	(** Data structure for an output more immediate descriptor *)
	OutputMoreImmediate*= RECORD
		cmd*: SET;
		key*: SET;
		i*: SET;
		b*: SET;
		reqCount*: SET;
		skipAddress*: SET;
		Z*: SET;
		timeStamp*: SET;
		firstQuadlet*: SET;
		secondQuadlet*: SET;
		thirdQuadlet*: SET;
		fourthQuadlet*: SET;
	END;

	(** Data structure for an output last descriptor *)
	OutputLast*= RECORD
		cmd*: SET;
		s*: SET;
		key*: SET;
		p*: SET;
		i*: SET;
		b*: SET;
		reqCount*: SET;
		dataAddress*: SET;
		brachAddress*: SET;
		Z*: SET;
		xferStatus*: SET;
		timeStamp*: SET;
	END;

	(** Data structure for an output last immediate descriptor *)
	OutputLastImmediate*= RECORD
		cmd*: SET;
		s*: SET;
		key*: SET;
		p*: SET;
		i*: SET;
		b*: SET;
		reqCount*: SET;
		brachAddress*: SET;
		Z*: SET;
		xferStatus*: SET;
		timeStamp*: SET;
		firstQuadlet*: SET;
		secondQuadlet*: SET;
		thirdQuadlet*: SET;
		fourthQuadlet*: SET;
	END;

	(** Data structure for a store value descriptor *)
	StoreValueDesc*= RECORD
		cmd*: SET;
		key*: SET;
		i*: SET;
		storeDoublet*: SET;
		dataAddress*: SET;
		skipAddress*: SET;
		Z*: SET;
	END;

	(** Data structure for a dual buffer descriptor *)
	DualBufferDesc* = RECORD
		s*: SET;
		key*: SET;
		i*: SET;
		b*: SET;
		w*: SET;
		firstSize*: SET;
		firstReqCount*: SET;
		secondReqCount*: SET;
		brachAddress*: SET;
		Z*: SET;
		firstBuffer*: SET;
		secondBuffer*: SET;
	END;

VAR avIRCont, avITCont: LONGINT; base: LONGINT;

(** Returns the bus id *)
PROCEDURE GetBusID*():SET;
BEGIN
	RETURN  LSH(ReadReg(NodeID)*{6..15},-6);
END GetBusID;

(** Returns the generation counter *)
PROCEDURE GetGeneration*():LONGINT;
VAR reg: SET;
BEGIN
	reg:= ReadReg(SelfIDCount);
	reg:= LSH(reg,-16)*{0..7};
	RETURN SYSTEM.VAL(LONGINT,reg);
END GetGeneration;

(** Computes the packet length *)
PROCEDURE PacketLength*(context: Contest):LONGINT;
VAR bufferAddr: SET; bufSize, resCount, packetSize, packetOffset: LONGINT; nextBlock, curBlock: LONGINT;
BEGIN
	(* KernelLog.String("Entering PacketLength"); KernelLog.Ln(); *)
	curBlock:= SYSTEM.VAL(LONGINT,context.prgr.curDesc);
	packetOffset:= context.prgr.packetOffset;
	bufferAddr:= SYSTEM.VAL(SET,SYSTEM.GET32(curBlock + 4));
	bufSize:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(curBlock))*{0..15});
	resCount:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(curBlock + 12))*{0..15});
	(* remember that packet cannot cross more than one buffer boundary *)
	IF resCount > 0 THEN (* Packet is not split *)
		(* KernelLog.String("Packet is not split::PacketLength"); KernelLog.Ln(); *)
		packetSize:= bufSize - packetOffset - resCount;
	ELSE (* packet is split or exactly filled the buffer *)
		(* KernelLog.String("Packet is split or exactly fills the buffer!::PacketLength"); KernelLog.Ln(); *)
		packetSize:= bufSize - packetOffset;
		nextBlock:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(curBlock+8))*{4..31});
		bufSize:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(nextBlock))*{0..15});
		resCount:= SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,SYSTEM.GET32(nextBlock + 12))*{0..15});
		ASSERT(resCount > 0); (* This should never happen *)
		packetSize:= packetSize+ bufSize - resCount;
	END;
	(* KernelLog.String("Leaving PacketLength"); KernelLog.Ln(); *)
	ASSERT(packetSize > 0);
	RETURN packetSize;
	(* remember that we always need at least one free descriptor to handle next incoming packet *)
END PacketLength;

(** This function maps tCodes to packetSizes in bytes *)
PROCEDURE TCodeToSize*(tCode: SET):LONGINT;
VAR tCodeSize: ARRAY 16 OF LONGINT;
BEGIN
	tCodeSize[0]:= 20;
	tCodeSize[1]:= 0;
	tCodeSize[2]:= 16;
	tCodeSize[3]:= -1;
	tCodeSize[4]:= 16;
	tCodeSize[5]:= 20;
	tCodeSize[6]:= 20;
	tCodeSize[7]:= 0;
	tCodeSize[8]:= -1;
	tCodeSize[9]:= 0;
	tCodeSize[10]:= -1;
	tCodeSize[11]:= 0;
	tCodeSize[12]:= -1;
	tCodeSize[13]:= -1;
	tCodeSize[14]:= 16;
	tCodeSize[15]:= -1;
	RETURN tCodeSize[SYSTEM.VAL(LONGINT,tCode)];
END TCodeToSize;

(** Writes to register *)
PROCEDURE WriteReg*(reg: LONGINT; val: SET);
BEGIN
	SYSTEM.PUT32(base + reg, val);
END WriteReg;

(** Reads from a register *)
PROCEDURE ReadReg*(reg: LONGINT):SET;
BEGIN
	RETURN SYSTEM.VAL(SET, SYSTEM.GET32(base + reg));
END ReadReg;

(** Starts a context *)
PROCEDURE StartContest*(contest: Contest):BOOLEAN;
CONST isValid= 31; nodeNumber= {0..5};
BEGIN
	(* check if node id is valid *)
	IF ~(isValid IN ReadReg(NodeID)) THEN KernelLog.String("Node id is not valid"); KernelLog.Ln();
		RETURN FALSE
	END;

	(* check if node id is not equal 63 *)
	IF ConvertToSet(63) = (ReadReg(NodeID)*nodeNumber) THEN KernelLog.String("Node id is 63");
		KernelLog.Ln(); RETURN FALSE
	END;

	(* run the contest*)
	(* KernelLog.String("Running contest "); KernelLog.String(contest.name); KernelLog.Ln(); *)
	WriteReg(contest.ctrlSet,{15}); RETURN TRUE;

END StartContest;

(* isoRecvIntMask *)

(** Checks how much isochronous transmit contexts are availble *)
PROCEDURE  CheckAvailableIT*;
VAR reg: SET; i,av: LONGINT;
BEGIN
	reg:= {0..31};
	SYSTEM.PUT32(base + isoXmitIntMaskSet,reg);
	reg:= SYSTEM.VAL(SET, SYSTEM.GET32(base + isoXmitIntMaskSet));
	FOR i:= 0 TO 31 DO
		IF i IN reg THEN INC(av);
		END
	END;
	(* KernelLog.String("There are ");KernelLog.Int(av,2);
	KernelLog.String(" available isoXmit contexts"); KernelLog.Ln(); *)
	avITCont:= av;
END CheckAvailableIT;

(** Checks how much isochronous receive contexts are availble *)
PROCEDURE  CheckAvailableIR*;
VAR reg: SET; i,av: LONGINT;
BEGIN
	reg:= {0..31};
	SYSTEM.PUT32(base + isoRecvIntMaskSet,reg);
	reg:= SYSTEM.VAL(SET, SYSTEM.GET32(base + isoRecvIntMaskSet));
	FOR i:= 0 TO 31 DO
		IF i IN reg THEN INC(av);
		END
	END;
	(* KernelLog.String("There are ");KernelLog.Int(av,2);
	KernelLog.String(" available isoRecv contexts"); KernelLog.Ln(); *)
	avIRCont:= av;
END CheckAvailableIR;

(** Returns the availble number of isochronous receive contexts *)
PROCEDURE GetAvailableIRCont*():LONGINT;
BEGIN
	RETURN avIRCont;
END GetAvailableIRCont;

(** Returns the availble number of isochronous transmit contexts *)
PROCEDURE GetAvailableITCont*():LONGINT;
BEGIN
	RETURN avITCont;
END GetAvailableITCont;

(** Sets the isochronous receive context match register *)
PROCEDURE SetIsochRecvContMatch*(s: SET);
VAR reg: SET;
BEGIN
	reg:= SYSTEM.VAL(SET,SYSTEM.GET32(base+isochRecvContMatch));
	reg:= reg + s;
	SYSTEM.PUT32(base+isochRecvContMatch,reg);
END SetIsochRecvContMatch;

(** Allocates a buffer for the asynchronous transmit context *)
PROCEDURE AllocATReqBuf*(VAR ptrToBfr: CharBuffer):ADDRESS;
VAR buffer: CharBuffer; adr: ADDRESS;
BEGIN
	(* Allocating a 128 byte address + 16 byte padding *)
	NEW(buffer, 144);
	(* find a 16 byte aligned address *)
	adr:= ADDRESSOF(buffer[0]);
	DEC(adr, adr MOD 16);
	INC(adr, 16);
	ptrToBfr:= buffer;
	RETURN adr;
END AllocATReqBuf;

(** Allocates a buffer for the asynchronous receive context *)
PROCEDURE AllocATResBuf*(VAR ptrToBfr: CharBuffer):ADDRESS;
VAR buffer: CharBuffer; adr: ADDRESS;
BEGIN
	(* Allocating a 128 byte address + 16 byte padding *)
	NEW(buffer, 144);
	(* find a 16 byte aligned address *)
	adr:= ADDRESSOF(buffer[0]);
	DEC(adr, adr MOD 16);
	INC(adr, 16);
	ptrToBfr:= buffer;
	RETURN adr;
END AllocATResBuf;

(** Allocates a buffer for the isochronous transmit context *)
PROCEDURE AllocITBuf*(VAR ptrToBfr: CharBuffer;descNum: LONGINT):ADDRESS;
VAR buffer: CharBuffer; adr: ADDRESS;
BEGIN
	(* Allocating buffer for the isochronous context *)
	NEW(buffer, 16*descNum+16);
	(* Find a 16 byte aligned address *)
	adr:= ADDRESSOF(buffer[0]);
	DEC(adr, adr MOD 16);
	INC(adr, 16);
	ptrToBfr:= buffer;
	RETURN adr;
END AllocITBuf;

(** Allocates a buffer for the isochronous receive context *)
PROCEDURE AllocIRBuf*(VAR ptrToBfr: CharBuffer;descNum: LONGINT):ADDRESS;
VAR buffer: CharBuffer; adr: ADDRESS;
BEGIN
	 (* Allocating buffer for the isochronous context *)
	NEW(buffer, 16*descNum+16);
	(* Find a 16 byte aligned address *)
	adr:= ADDRESSOF(buffer[0]);
	DEC(adr, adr MOD 16);
	INC(adr, 16);
	ptrToBfr:= buffer;
	RETURN adr
END AllocIRBuf;

(** Allocates a buffer for the asynchronous receive request context *)
PROCEDURE AllocARReqBuf*(VAR ptrToBfr: CharBuffer):ADDRESS;
VAR buffer: CharBuffer; adr: ADDRESS;
BEGIN
	(* Allocating a 80 byte address *)
	NEW(buffer, 80);
	(* find a 16 byte aligned address *)
	adr:= ADDRESSOF(buffer[0]);
	DEC(adr, adr MOD 16);
	INC(adr, 16);
	ptrToBfr:= buffer;
	RETURN adr;
END AllocARReqBuf;

(** Allocates a buffer for the asynchronous receive response context *)
PROCEDURE AllocARResBuf*(VAR ptrToBfr: CharBuffer):ADDRESS;
VAR buffer: CharBuffer; adr: ADDRESS;
BEGIN
	(* Allocating a 80 byte address *)
	NEW(buffer, 80);
	(* find a 16 byte aligned address *)
	adr:= ADDRESSOF(buffer[0]);
	DEC(adr, adr MOD 16);
	INC(adr, 16);
	ptrToBfr:= buffer;
	RETURN adr;
END AllocARResBuf;

(** Sets the isochronous receive command pointer *)
PROCEDURE SetIRComPtr*(VAR ptrToBuf: CharBuffer);
VAR buffer: CharBuffer; adr: ADDRESS; s: SET; i: LONGINT;
BEGIN
	FOR i:= 0 TO avIRCont-1 DO
		(* Allocating a 80 byte address *)
		NEW(buffer, 80);
		(* find a 16 byte aligned address *)
		adr:= ADDRESSOF(buffer[0]);
		DEC(adr, adr MOD 16);
		INC(adr, 16);
		s:= SYSTEM.VAL(SET,adr);
		(* Setting the address *)
		SYSTEM.PUT32(base + IRComPtr + 32*i, s);
		ptrToBuf:= buffer;
	END
END SetIRComPtr;

(** Sets the isochronous transmit command pointer *)
PROCEDURE SetITComPtr*(VAR ptrToBuf: CharBuffer);
VAR buffer: CharBuffer; adr: ADDRESS; s: SET; i: LONGINT;
BEGIN
	FOR i:= 0 TO avITCont-1 DO
		(* Allocating a 80 byte address *)
		NEW(buffer, 80);
		(* find a 16 byte aligned address *)
		adr:= ADDRESSOF(buffer[0]);
		DEC(adr, adr MOD 16);
		INC(adr, 16);
		s:= SYSTEM.VAL(SET,adr);
		(* Setting the address *)
		SYSTEM.PUT32(base + ITComPtr + 16*i, s);
		ptrToBuf:= buffer;
	END
END SetITComPtr;

(* Int Mask *)

(** Clears the interrupt mask *)
PROCEDURE ClearIntMaskAll*;
VAR s,s2:SET; i: LONGINT;
BEGIN
	(* KernelLog.String("Entering ClearIntMaskAll");
	KernelLog.Ln(); *)
	CheckIntMask();
	s := ReadReg(IntMask);
	i := 0;
	WHILE i < 32 DO
		s2 := {};
		IF ~(i IN {10,11,12,13,14,28,30,31}) & (i IN s) THEN
			INCL(s2,i);
			WriteReg(CIntMask,s2);
		END;
		INC(i);
	END;
	CheckIntMask();
	(* KernelLog.String("Leaving ClearIntMaskAll");
	KernelLog.Ln(); *)
END ClearIntMaskAll;

(** Prints the interrupt mask register *)
PROCEDURE CheckIntMask*;
VAR reg:SET;
BEGIN
	reg := ReadReg(IntMask);
	(* KernelLog.String("Checking IntMask");
	KernelLog.Ln;
	PrintSet(reg); *)
END CheckIntMask;

(* HCControl *)
(** Sets HCControl register fields *)
PROCEDURE SetHCControl*(reg:SET);
VAR reg2: SET;
BEGIN
	reg2:= ReadReg(HCControl);
	reg:= reg + reg2;
	SYSTEM.PUT32(base+HCControl,reg);
END SetHCControl;

(* IntEvent *)

PROCEDURE SoftInterrupt*; (* not used *)
CONST softInterrupt= 29;
VAR reg:SET;
BEGIN
	INCL(reg,softInterrupt);
	SYSTEM.PUT32(base + IntEvent,reg);
END SoftInterrupt;

(**  Clears all occured interrupt event *)
PROCEDURE ClearIntEventAll*;
VAR s,s2:SET; i: LONGINT;
BEGIN
	(* KernelLog.String("Entering ClearIntEventAll");
	KernelLog.Ln(); *)
	CheckIntEvent();
	s := ReadReg(IntEvent);
	i := 0;
	WHILE i < 32 DO
		s2 := {};
		IF ~(i IN {10,11,12,13,14,28,30,31}) & (i IN s) THEN
			INCL(s2,i);
			WriteReg(CIntEvent,s2);
		END;
		INC(i);
	END;
	CheckIntEvent();
	(* KernelLog.String("Leaving ClearIntEventAll");
	KernelLog.Ln(); *)
END ClearIntEventAll;

(** Checks the HCControl register *)
PROCEDURE CheckHCControl;
VAR reg: SET;
BEGIN
	reg:= ReadReg(HCControl);
	KernelLog.String("Checking HCControl");
	KernelLog.Ln;
	PrintSet(reg);
END CheckHCControl;

(** Checks the int event register *)
PROCEDURE CheckIntEvent*;
VAR reg:SET;
BEGIN
	reg := ReadReg(IntEvent);
	(* KernelLog.String("Checking IntEvent");
	KernelLog.Ln;
	PrintSet(reg); *)
END CheckIntEvent;

(* Context Control *)

(** Stops a context *)
PROCEDURE StopContext*(reg: LONGINT);
CONST run= {15}; active= 10;
VAR s: SET;
BEGIN
	SYSTEM.PUT32(base + reg,run);
	s:= SYSTEM.VAL(SET, SYSTEM.GET32(base + reg));
	WHILE active IN s DO
		s:= SYSTEM.VAL(SET, SYSTEM.GET32(base + reg));
	END;
	(* KernelLog.String("Stopped context"); KernelLog.Ln();
	PrintSet(ReadReg(reg)); *)
END StopContext;

(* PhyControl *)

(** Sets the physical control register to write data to regAddr *)
PROCEDURE SetPhyControl*(regAddr:SET; data: SET);
CONST rdReg = 15; rdData = {16..23}; IBR = 6; wrReg = 14; rdDone = 31;
VAR phyReg: SET; done: BOOLEAN; dataRead: SET; offset: LONGINT; i: LONGINT;
BEGIN
	(* KernelLog.String("Setting the phy control register"); KernelLog.Ln(); *)
	phyReg:= ReadReg(PhyControl);
	(* Set register address *)
	phyReg:= phyReg + regAddr;
	(* Initiate read request *)
	INCL(phyReg,rdReg);
	(* Write the register back *)
	SYSTEM.PUT32(base+PhyControl,phyReg);
	done:= FALSE;
	(* wait until register is read *)
	WHILE ~done DO
		(* KernelLog.String("I'm waiting");
		KernelLog.Ln(); *)
		phyReg := ReadReg(PhyControl);
		IF rdDone IN phyReg THEN done := TRUE;
		END
	END;
	(* masking out ridden Data *)
	dataRead := phyReg*rdData;
	(* eliminate offset *)
	offset := 16;
	i := 16;
	WHILE i<24 DO
		IF i IN dataRead THEN EXCL(dataRead,i);INCL(dataRead,(i-offset));
		END;
		INC(i)
	END;
	(* setting  bit *)
	dataRead:= dataRead + data;
	(* to be sure read out one more time *)
	phyReg := ReadReg(PhyControl);
	(* set register address although could still be set *)
	phyReg:= phyReg + regAddr;
	(* write to wrData the data that has to be written *)
	phyReg := phyReg+dataRead;
	(*initiate write request*)
	(* set "write request" bit *)
	SYSTEM.PUT32(base+PhyControl,phyReg);
	INCL(phyReg,wrReg);
	SYSTEM.PUT32(base+PhyControl,phyReg);
	done := FALSE;
	(* wait until register is written *)
	WHILE ~done DO
		(* KernelLog.String("I'm waiting");
		KernelLog.Ln(); *)
		phyReg := ReadReg(PhyControl);
		IF ~(wrReg IN phyReg) THEN done := TRUE;
		END
	END;
END SetPhyControl;

(** Converts a LONGINT to a set *)
PROCEDURE ConvertToSet*(l: LONGINT):SET;
BEGIN
	RETURN SYSTEM.VAL(SET,l)
END ConvertToSet;

(** Does the same as LSH but only for sets, better use LSH *)
PROCEDURE DelOffset*(reg:SET;offset:LONGINT):SET;
VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE i<32 DO
		IF i IN reg THEN
			EXCL(reg,i); INCL(reg,(i-offset))
		END;
		INC(i);
	END;
	RETURN reg;
END DelOffset;

(** Basically does what system.move does *)
PROCEDURE AllocPacket*(dataAddr: ARRAY OF SET; dataSize: LONGINT;adr: LONGINT):SET;
VAR i,j: LONGINT; address: SET;
BEGIN
	(* dataSize is in bytes *)
	address:= SYSTEM.VAL(SET,adr);
	j:= 0; i:= 0;
	WHILE i< (dataSize-1) DO
		SYSTEM.PUT32(SYSTEM.VAL(LONGINT,address)+i,dataAddr[j]);
		INC(i,4);  INC(j);
	END;
	RETURN address
END AllocPacket;

(** Allocates a 4KB buffer for an OHCI packet *)
PROCEDURE  AllocPcktBuf*(num: LONGINT; VAR bufs: ARRAY OF SET;VAR ptrBufs: ARRAY OF CharBuffer);
VAR i: LONGINT; buffer: CharBuffer; adr: ADDRESS; s: SET;
BEGIN
	FOR i:= 0 TO num-1 DO
		(* Allocating a 4096 byte buffer + 4 byte for the alignement *)
		NEW(buffer, BufSize + 4);
		adr:= ADDRESSOF(buffer[0]);
		(* Find a 4 byte aligned address *)
		DEC(adr, adr MOD 4);
		INC(adr, 4);
		s:= SYSTEM.VAL(SET,adr);
		bufs[i]:= s;
		ptrBufs[i]:= buffer;
	END
END AllocPcktBuf;

(** Returns the maximally allowed size for an asynchronous OHCI packet *)
PROCEDURE GetMaxPcktSize*():LONGINT;
CONST mask = {12..15};
VAR reg:SET; val,i: LONGINT; size: LONGINT;
BEGIN
	size:= 1;
	reg:= SYSTEM.VAL(SET,SYSTEM.GET32(base + BusOptions));
	reg:= reg*mask;
	reg:= DelOffset(reg,12);
	(* convert to integer *)
	val:= SYSTEM.VAL(LONGINT,reg);
	(* increment by one, because smallest value should be two *)
	INC(val);
	FOR i:= 0 TO val-1 DO size:= size*2 END;
	(* add 20 bytes for header and trailer *)
	size:= size + 20;
	RETURN size;
END GetMaxPcktSize;

(** Checks the self identification counter *)
PROCEDURE CheckSelfIDCount*;
CONST selfIDError= 31;
VAR reg:SET;
BEGIN
	reg:= SYSTEM.VAL(SET,SYSTEM.GET32(base + SelfIDCount));
	IF selfIDError IN reg THEN (* KernelLog.String("There was an error during the self ID process"); KernelLog.Ln() *) END;
	(* KernelLog.String("Printing the contents of the Self Id Count register:" ); KernelLog.Ln(); PrintSet(reg); KernelLog.Ln(); *)
END CheckSelfIDCount;

(** Checks the status of the OHCI *)
PROCEDURE CheckStatus*;
BEGIN
	CheckSelfIDCount();
	CheckIntEvent();
	CheckLinkControl();
	CheckHCControl();
	CheckBusID();
	PrintNodeInfo();
	CheckBusManagerID();
END CheckStatus;

(** Checks the bus manager id *)
PROCEDURE CheckBusManagerID;
CONST csrDone= 31;
VAR reg: SET; done: BOOLEAN;
BEGIN
	(* First check who is Bus Manager *)
	WriteReg(CSRData,{0..5});
	WriteReg(CSRCompare,{0..5});
	WriteReg(CSRControl,{});
	(* Wait until compare swap operation has been done *)
	reg:= ReadReg(CSRControl);
	done:= FALSE;
	WHILE ~done DO
		IF csrDone IN reg THEN done:= TRUE ELSE
		 	reg:= ReadReg(CSRControl)
		END
	END;
	(* Read the bus manager ID *)
	reg:= ReadReg(CSRData);
	(* Print it out *)
	KernelLog.String("Printing the bus manager id");
	PrintSet(reg);
	(* Print the node id to compare it *)
	KernelLog.String("Printing the node id");
	reg:= ReadReg(NodeID);
	reg:= reg*{0..5};
	PrintSet(reg);
END CheckBusManagerID;

(** Checks the bus id *)
PROCEDURE CheckBusID;
VAR reg:SET;
BEGIN
	KernelLog.String("Checking the BusID"); KernelLog.Ln();
	reg:= SYSTEM.VAL(SET, SYSTEM.GET32(base + BusID));
	PrintSet(reg);
END CheckBusID;

(** Checks the LinkControl register content *)
PROCEDURE CheckLinkControl*;
VAR reg:SET;
BEGIN
	reg := ReadReg(LinkControl);
	KernelLog.String("Checking LinkControl");
	KernelLog.Ln;
	PrintSet(reg);
END CheckLinkControl;

(** Used to force a softreset *)
PROCEDURE SoftReset*; (* not used *)
BEGIN
	SetHCControl({softReset});
	WHILE softReset IN (ReadReg(HCControl)) DO END
END SoftReset;

(** Sets the base address of the OHCI register set *)
PROCEDURE SetBase*(b: LONGINT);
BEGIN
	base := b;
	(* KernelLog.String("base is: ");
	KernelLog.Int(base,2);
	KernelLog.Ln(); *)
END SetBase;

(** Returns an asynchronous output more immediate descriptor *)
PROCEDURE GetAOMIDesc*():OutputMoreImmediate;
CONST keyOMI= {25};
VAR descOMI: OutputMoreImmediate;
BEGIN
	descOMI.key:= keyOMI;
	RETURN descOMI
END GetAOMIDesc;

(** Returns an asynchronous output last descriptor *)
PROCEDURE GetAOLDesc*():OutputLast;
CONST cmdOL= {28}; bOL= {18,19}; iOL= {20,21};
VAR descOL: OutputLast;
BEGIN
	descOL.cmd:= cmdOL; descOL.b:= bOL; descOL.i:= iOL;
	RETURN descOL
END GetAOLDesc;

(** Returns an asynchronous last immediate descriptor *)
PROCEDURE GetAOLIDesc*(): OutputLastImmediate;
CONST cmdOLI= {28}; keyOLI= {25}; bOLI= {18,19}; iOLI= {20,21};
VAR descOLI: OutputLastImmediate;
BEGIN
	descOLI.cmd:= cmdOLI; descOLI.key:= keyOLI; descOLI.b:= bOLI; descOLI.i:= iOLI;
	RETURN descOLI
END GetAOLIDesc;

(** Returns an isochronous input last descriptor *)
PROCEDURE GetIILDesc*(): InputLastDesc;
CONST cmdIL = {28,29};
VAR descIL: InputLastDesc;
BEGIN
	descIL.cmd:= cmdIL;
	RETURN descIL
END GetIILDesc;

(** Returns an isochronous input more descriptor *)
PROCEDURE GetIIMDesc*():InputMoreDesc;
CONST  cmdIM= {29};
VAR descIM: InputMoreDesc;
BEGIN
	descIM.cmd:= cmdIM;
	RETURN descIM
END GetIIMDesc;

(** Returns an isochronous dual buffer descriptor *)
PROCEDURE GetIDBDesc*(): DualBufferDesc;
CONST s = {27}; b = {19,18};
VAR descDB: DualBufferDesc;
BEGIN
	descDB.s := s; descDB.b := b;
	RETURN descDB
END GetIDBDesc;

(** Returns an isochronous output more immediate descriptor *)
PROCEDURE GetIOMIDesc*(): OutputMoreImmediate;
CONST keyOMI = {25}; reqCountOMI = {4};
VAR descOMI: OutputMoreImmediate;
BEGIN
	descOMI.key:= keyOMI; descOMI.reqCount:= reqCountOMI;
	RETURN descOMI
END GetIOMIDesc;

(** Returns an isochronous output last descriptor *)
PROCEDURE GetIOLDesc*(): OutputLast;
CONST cmdOL = {28}; bOL = {19,18};
VAR descOL: OutputLast;
BEGIN
	descOL.cmd:= cmdOL; descOL.b:= bOL;
	RETURN descOL
END GetIOLDesc;

(** Returns an isochronous output last immediate descriptor *)
PROCEDURE GetIOLIDesc*(): OutputLastImmediate;
CONST cmdOLI = {28}; keyOLI = {25}; bOLI= {19,18}; reqCountOLI= {4};
VAR descOLI: OutputLastImmediate;
BEGIN
	descOLI.cmd:= cmdOLI; descOLI.key:= keyOLI; descOLI.b:= bOLI; descOLI.reqCount:= reqCountOLI;
	RETURN descOLI
END GetIOLIDesc;

(** Returns an isochronous store value descriptor *)
PROCEDURE GetISVDesc*(): StoreValueDesc;
CONST cmdSV= {31}; keySV= {26,25};
VAR descSV: StoreValueDesc;
BEGIN
	descSV.cmd:= cmdSV; descSV.key:= keySV;
	RETURN descSV
END GetISVDesc;

(** Prints the status information of the ohci *)
PROCEDURE PrintNodeInfo*;
CONST iDValid = 31; root = 30; CPS = 27;
VAR reg: SET;
BEGIN
	reg:= SYSTEM.VAL(SET, SYSTEM.GET32(base + NodeID));

	KernelLog.String("Printing node information:"); KernelLog.Ln();

	IF iDValid IN reg THEN
		KernelLog.String("Node has a valid node number."); KernelLog.Ln();
	ELSE KernelLog.String("Node has no valid node number."); KernelLog.Ln() END;

	PrintSet(reg);

	reg:= SYSTEM.VAL(SET, SYSTEM.GET32(base + NodeID));
	IF root IN reg THEN
		KernelLog.String("Node is root."); KernelLog.Ln();
	ELSE KernelLog.String("Node is not root."); KernelLog.Ln() END;
	PrintSet(reg);
	IF CPS IN reg THEN
		KernelLog.String("Cable power status is ok.");KernelLog.Ln();
	ELSE KernelLog.String("Cable power status is not ok.");KernelLog.Ln() END;

	CheckIntEvent();
END PrintNodeInfo;

(** Is used to print out a set *)
PROCEDURE PrintSet*(set:SET);
VAR x:LONGINT;
BEGIN
	x := 0;
	WHILE x < 32 DO
		IF x IN set THEN KernelLog.Int(x,2); KernelLog.String(", "); END;
		INC(x);
	END;
	KernelLog.Ln();
END PrintSet;

(** Builds the header of a response packet *)
PROCEDURE BuildHeaderResp*(tc: LONGINT; VAR packet: OHCIPacket; rCode: LONGINT);
VAR busNumber: SET;
BEGIN
	busNumber:= LSH(ReadReg(NodeID)*{6..15},16);
	packet.tCode:= ConvertToSet(tc);
	packet.header[0]:= LSH(packet.nodeID,16) + busNumber + LSH(packet.tLabel,10) + LSH({0},8) +
		ConvertToSet(LSH(tc,4));
	packet.header[1]:= ConvertToSet(LSH(packet.host.nodeID,16)) + SYSTEM.VAL(SET,LSH(rCode,12));
	packet.header[2]:= {};
END BuildHeaderResp;

(** Fill an asynchronous write response packet *)
PROCEDURE FillAsyncWriteResp*(VAR packet: OHCIPacket; rCode: LONGINT);
BEGIN
	BuildHeaderResp(NoDataWARRes,packet,rCode);
	packet.header[2]:= {};
	packet.headerSize:= 12;
	packet.dataSize:= 0;
	packet.respExpected:= FALSE;
END FillAsyncWriteResp;

(** Fills an asynchronous read quadlet response packet *)
PROCEDURE FillAsyncReadQuadResp*(VAR packet: OHCIPacket; rCode,bufferAddr: LONGINT);
BEGIN
	BuildHeaderResp(QReadARRes,packet,rCode);
	packet.header[3]:= SYSTEM.VAL(SET,SYSTEM.GET32(bufferAddr));
	packet.headerSize:= 16;
	packet.dataSize:= 0;
	packet.respExpected:= FALSE;
END FillAsyncReadQuadResp;

(** Fills an asynchronous read block response packet *)
PROCEDURE FillAsyncReadBlockResp*(VAR packet: OHCIPacket; rCode,length: LONGINT);
VAR padding: LONGINT;
BEGIN
	IF rCode # respComplete THEN length:= 0 END;
	BuildHeaderResp(BReadARRes,packet,rCode);
	packet.header[3]:= SYSTEM.VAL(SET,LSH(length,16));
	packet.headerSize:= 16;
	IF (length MOD 4 > 0) THEN padding:= 4 - (length MOD 4) ELSE padding:= 0 END;
	packet.dataSize:= length + padding;
	packet.respExpected:= FALSE;
END FillAsyncReadBlockResp;

(** Builds the header of a packet *)
PROCEDURE BuildHeader(tc: LONGINT; VAR packet: OHCIPacket; addrLow,addrHigh: SET);
VAR busNumber: SET;
BEGIN
	busNumber:= LSH(ReadReg(NodeID)*{6..15},16);
	packet.tCode:= ConvertToSet(tc);
	(* KernelLog.String("Setting header[0]"); KernelLog.Ln(); *)
	packet.header[0]:= LSH(packet.nodeID,16) + busNumber + LSH(packet.tLabel,10) + LSH({0},8) +
		ConvertToSet(LSH(tc,4));
	(* KernelLog.String("Setting header[1]"); KernelLog.Ln(); *)
	packet.header[1]:= ConvertToSet(LSH(packet.host.nodeID,16)) + addrHigh + busNumber;
	(* KernelLog.String("Printing the nodeID: "); PrintSet(packet.nodeID); KernelLog.Ln();
	KernelLog.String("Printing the address: "); PrintSet(addrLow); PrintSet(addrHigh); KernelLog.Ln();	*)
	(* KernelLog.String("Setting header[2]"); KernelLog.Ln(); *)
	packet.header[2]:= addrLow
END BuildHeader;

(* Procedure needed to build packets from here on *)
(** Fills a lock packet *)
PROCEDURE FillLockPacket(packet: OHCIPacket; addrLow,addrHigh: SET; extCode: LONGINT; length: LONGINT);
BEGIN
	(* KernelLog.String("Building header::FillLockPacket!"); KernelLog.Ln(); *)
	BuildHeader(LockATReq, packet, addrLow, addrHigh);
	packet.header[3]:= SYSTEM.VAL(SET,LSH(length,16)) + SYSTEM.VAL(SET,extCode);
	packet.headerSize:= 16;
	packet.dataSize:= length;
	packet.respExpected:= TRUE;
END FillLockPacket;

(** Fills an asynchronous write quadlet packet *)
PROCEDURE FillAsyncWriteQuadlet*(packet: OHCIPacket; addrLow, addrHigh,  data: SET);
BEGIN
	(* KernelLog.String("Building header::FillAsyncWriteQuadlet!"); KernelLog.Ln(); *)
	BuildHeader(QWriteATReq, packet, addrLow, addrHigh);
	packet.header[3]:= data;
	packet.headerSize:= 16;
	packet.dataSize:= 0;
	packet.respExpected:= TRUE;
END FillAsyncWriteQuadlet;

(** Fills an asynchronous write block packet *)
PROCEDURE FillAsyncWriteBlock*(packet: OHCIPacket; addrLow, addrHigh: SET; length: LONGINT);
VAR padding: LONGINT;
BEGIN
	(* KernelLog.String("Building header::FillAsyncWriteBlock!"); KernelLog.Ln(); *)
	BuildHeader(BWriteATReq, packet,addrLow, addrHigh);
	packet.header[3]:= SYSTEM.VAL(SET,LSH(length,16));
	packet.headerSize:= 16;
	packet.respExpected:= TRUE;
	IF (length MOD 4 > 0) THEN padding:= 4 - (length MOD 4) ELSE padding:= 0 END;
	packet.dataSize:= length + padding;
END FillAsyncWriteBlock;

(** Fills an asynchronous read quadlet packet *)
PROCEDURE FillAsyncReadQuadlet*(VAR packet: OHCIPacket; addrLow,addrHigh: SET);
BEGIN
	(* KernelLog.String("Building header::FillAsyncReadQuadlet!"); KernelLog.Ln(); *)
	BuildHeader(NoDataWATReq,packet,addrLow,addrHigh);
	(* PrintSet(packet.header[0]);
	PrintSet(packet.header[1]);
	PrintSet(packet.header[2]); *)
	packet.headerSize:= 12;
	packet.dataSize:= 0;
	packet.respExpected:= TRUE;
END FillAsyncReadQuadlet;

(** Fills an asynchronous read block packet *)
PROCEDURE FillAsyncReadBlock*(VAR packet: OHCIPacket; addrLow,addrHigh: SET; length: LONGINT);
BEGIN
	BuildHeader(BReadATReq,packet,addrLow,addrHigh);
	packet.header[3]:= ConvertToSet(LSH(length,16));
	packet.headerSize:= 16;
	packet.dataSize:= 0;
	packet.respExpected:= TRUE;
END FillAsyncReadBlock;

(** Test if a packet and eventually its response were successfully sent and received *)
PROCEDURE TestIfSuccess*(packet:OHCIPacket):BOOLEAN;
VAR tCode: LONGINT;
BEGIN

	tCode:= SYSTEM.VAL(LONGINT,packet.tCode);
	CASE SYSTEM.VAL(LONGINT,packet.ack) OF
	AckPending:
		(* KernelLog.String("The packet received an ackPending::testIFSuccess"); KernelLog.Ln(); *)
		CASE SYSTEM.VAL(LONGINT,LSH(packet.header[1],-12) * {0..3}) OF
		respComplete: RETURN TRUE;
		|respConflictError: KernelLog.String("The packet had a conflict error!"); KernelLog.Ln();
			RETURN FALSE;
		|respDataError: KernelLog.String("The packet had a data error!"); KernelLog.Ln();
			RETURN FALSE;
		|respTypeError: KernelLog.String("The packet had a type error!"); KernelLog.Ln();
			RETURN FALSE;
		|respAddressError: KernelLog.String("The packet had an address error!"); KernelLog.Ln();
			RETURN FALSE;
		ELSE KernelLog.String("Received reserved code!"); KernelLog.Ln();
			(* dump packet data *)
			PrintSet(packet.header[0]);
			PrintSet(packet.header[1]);
			PrintSet(packet.header[2]);
			RETURN FALSE
		END;
	|AckBusyX: RETURN FALSE; KernelLog.String("AckBusyX"); KernelLog.Ln();
	|AckBusyA: RETURN FALSE; KernelLog.String("AckBusyA"); KernelLog.Ln();
	|AckBusyB: RETURN FALSE; KernelLog.String("AckBusyB"); KernelLog.Ln();
	|AckTypeError: RETURN FALSE;
	|AckComplete:
		(* KernelLog.String("The packet received an ackComplete::testIFSuccess"); KernelLog.Ln(); *)
		IF (tCode = QWriteATReq) OR (tCode = BWriteATReq) THEN
			RETURN TRUE
		ELSE
			KernelLog.String("Impossible ack complete!"); KernelLog.Ln(); RETURN FALSE
		END;
	|AckDataError:
		KernelLog.String("AckDataError"); KernelLog.Ln();
		IF (tCode = BWriteATReq) OR (tCode = LockATReq) THEN
			RETURN FALSE
		ELSE
			KernelLog.String("Impossible ack data error!"); KernelLog.Ln(); RETURN FALSE
		END;
	|AckError: KernelLog.String("AckError"); KernelLog.Ln(); RETURN FALSE;
	ELSE KernelLog.String("An invalid ack was received!"); KernelLog.Ln(); RETURN FALSE
	END
END TestIfSuccess;

(** Instantiates a lock packet *)
PROCEDURE MakeLockPacket*(ohci: OHCIDesc; nodeID: SET; addrLow, addrHigh:SET; extcode: LONGINT;
	data,arg: SET):OHCIPacket;
VAR p: OHCIPacket; length: LONGINT;
BEGIN

	p:= ohci.packetFIFO.GetPacket();
	p.dataSize:= 8;
	(* reset packet *)
	ResetPacket(p);

	p.host:= ohci;
	p.nodeID:= nodeID;
	p.tLabel:= ohci.labeler.GetTransLabel();

	CASE extcode OF
		FetchAdd: length:= 4;
			IF data # {} THEN p.data[0]:= data; (* KernelLog.String("Data is not an empty set"); KernelLog.Ln() *) END;
		|LittleAdd: length:= 4;
			IF data #{} THEN p.data[0]:= data; (* KernelLog.String("Data is not an empty set"); KernelLog.Ln() *) END;
	ELSE length:= 8;
		IF data # {} THEN p.data[0]:= arg; p.data[1]:= data; (* KernelLog.String("Data is not an empty set"); KernelLog.Ln() *) END
	END;

	(* KernelLog.String("The length is::MakeLockpacket:: "); KernelLog.Int(length,2); KernelLog.Ln(); *)

	FillLockPacket(p, addrLow, addrHigh, extcode, length);

	(* Dump data
	KernelLog.String("Dumping the data::MakeLockPacket"); KernelLog.Ln();
	FOR i:= 0 TO (p.dataSize DIV 4)-1 DO
		PrintSet(p.data[i])
	END; *)

	RETURN p;
END MakeLockPacket;

(** Instantiates a write packet *)
PROCEDURE MakeWritePacket*(ohci:OHCIDesc; nodeID, addrLow, addrHigh, buffer: SET; length: LONGINT ): OHCIPacket;
VAR packet: OHCIPacket; i,padding: LONGINT;
BEGIN
	IF length = 0 THEN RETURN NIL END;

	IF (length MOD 4 > 0) THEN padding:= 4 - (length MOD 4) END;
	(* KernelLog.String("Allocating a new packet!"); KernelLog.Ln(); *)
	packet:= ohci.packetFIFO.GetPacket();
	packet.dataSize:= length + padding;
	(* reset packet *)
	ResetPacket(packet);

	packet.host:= ohci;
	packet.nodeID:= nodeID;

	(* KernelLog.String("Getting transaction label"); KernelLog.Ln(); *)
	packet.tLabel:= ohci.labeler.GetTransLabel(); (* Hier wird gewartet wenn nichts frei ist *)

	(* KernelLog.String("Filling the packets!"); KernelLog.Ln(); *)
	IF length = 4 THEN
		(* KernelLog.String("Filling asynchronous write quadlet packet!"); KernelLog.Ln(); *)
		FillAsyncWriteQuadlet(packet,addrLow,addrHigh,buffer)
	ELSE
		(* KernelLog.String("Filling asynchronous write+ block packet!"); KernelLog.Ln(); *)
		FillAsyncWriteBlock(packet,addrLow,addrHigh,length);
		IF buffer # {} THEN (* SYSTEM.MOVE(SYSTEM.VAL(LONGINT,buffer),ADDRESSOF(packet.data),length) *)
			WHILE i # (length DIV 4) DO
				packet.data[i]:= SYSTEM.VAL(SET,SYSTEM.GET32(SYSTEM.VAL(LONGINT,buffer)+i*4));
				INC(i);
			END
		END;
		(* KernelLog.String("Dumping the packet!"); KernelLog.Ln();
		i:= 0;
		WHILE i # (length DIV 4) DO
			PrintSet(packet.data[i]); INC(i);
		END *)
	END;

	RETURN packet

END MakeWritePacket;

(** Instantiates a read packet *)
PROCEDURE MakeReadPacket*(ohci: OHCIDesc; nodeID: SET; addrLow,addrHigh: SET; length: LONGINT): OHCIPacket;
VAR packet: OHCIPacket; padding: LONGINT;
BEGIN
	IF length = 0 THEN RETURN NIL END;

	IF (length MOD 4 > 0) THEN padding:= 4 - (length MOD 4) END;
	(* KernelLog.String("Allocating a new packet!"); KernelLog.Ln(); *)
	packet:= ohci.packetFIFO.GetPacket();
	packet.dataSize:= length + padding;
	(* reset packet *)
	ResetPacket(packet);

	packet.host:= ohci;
	packet.nodeID:= nodeID;

	(* KernelLog.String("Getting transaction label"); KernelLog.Ln(); *)
	packet.tLabel:= ohci.labeler.GetTransLabel(); (* Hier wird gewartet wenn nichts frei ist *)

	(* KernelLog.String("Filling the packets!"); KernelLog.Ln(); *)
	IF length = 4 THEN
		(* KernelLog.String("Filling asynchronous read quadlet packet!"); KernelLog.Ln(); *)
		FillAsyncReadQuadlet(packet,addrLow,addrHigh)
	ELSE
		(* KernelLog.String("Filling asynchronous read block packet!"); KernelLog.Ln(); *)
		FillAsyncReadBlock(packet,addrLow,addrHigh,length)
	END;

	RETURN packet
END MakeReadPacket;

(** Resets all packet fields *)
PROCEDURE ResetPacket*(VAR packet: OHCIPacket);
VAR block: Block; ohci: OHCIDesc;
BEGIN
	packet.host:= ohci;
	packet.nodeID:= {};
	packet.type:= {};
	packet.tCode:= {};
	packet.speed:= {};
	packet.ack:= {};
	packet.pending:= FALSE;
	packet.respExpected:= FALSE;
	packet.tLabel:= {};
	packet.block:= block;
END ResetPacket;


END FirewireLowUtil.

Aos.Call FirewireLowUtil.TestPrint ~
