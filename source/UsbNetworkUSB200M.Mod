MODULE  UsbNetworkUSB200M;  (** AUTHOR "staubesv"; PURPOSE "USB device driver for Linksys USB200M network adapter"; *)
(**
 * This driver should basically work with USB ethernet adapters based on the ASIX AX88772 chipset. Currently it has been tested only
 * with the Linksys USB200M Rev2 device. Different devices may require device-specific configuration for the GPIO Pins, for example.
 *
 * References:
 *
 *	ASIX AX88772 USB to 10/100 Mbps Fast Ethernet/HomePNA Controller specification, www.asix.com.tw
 *
 * History:
 *
 *	03.11.2006	First release (staubesv)
 *	19.12.2006	User can specify the MAC address to be used using the MacAddress constant (staubesv)
 *)

IMPORT SYSTEM, KernelLog, Modules, Kernel, Usbdi, UsbNetwork, Network, Mii := NetworkMii, Strings;

CONST

	Name = "USB200M";
	Description = "Linksys USB200M network adapter";
	Priority = 1;

	(* Pad Ethernet frame to minimum length of 60 Byte? *)
	Min60BytePacket = TRUE;

	PromiscuousMode = FALSE;

	(* Specifiy MAC address to be used:
	 *	- "EEPROM": use MAC address stored in the adapters EEPROM
	 *	- "aa:bb:cc:ee:ff:gg": use aa:bb:cc:ee:ff:gg as MAC address
	 *)
	MacAddress = "EEPROM";

	BulkInRequestSize = 16384;
	RxBufferSize = 4 * BulkInRequestSize;

	TraceSend = {0};
	TraceReceive = {1};
	TraceReceiveDetailed = {2};
	Trace = {};

	Debug = TRUE;

	Verbose = TRUE;

	ModuleName = "UsbNetworkAsix88772";

	ReadCommand = Usbdi.ToHost + Usbdi.Vendor + Usbdi.Device;
	WriteCommand = Usbdi.ToDevice + Usbdi.Vendor + Usbdi.Device;

	(* Vendor-specific requests *)
	ReadRxTxRegister = 02H;
	WriteRxTxRegister = 03H;
	SetSoftwareSerialManagement = 06H;
	ReadPhyRegister = 07H;
	WritePhyRegister = 08H;
	ReadSerialManagementStatus = 09H;
	SetHardwareSerialManagement = 0AH;
	ReadSromRegister = 0BH;
	WriteSromRegister = 0CH;
	WriteSromEnable = 0DH;
	WriteSromDisable = 0EH;
	ReadRxControlRegister = 0FH;
	WriteRxControlRegister = 10H;
	ReadIpgControlRegister = 11H;
	WriteIpgControlRegister = 12H;
	ReadNodeId = 13H;
	WriteNodeId = 14H;
	ReadMcastFilterArray = 15H;
	WriteMcastFilterArray = 16H;
	WriteTestRegister = 17H;
	ReadPhyAddressRegister = 19H;
	ReadMediumStatus = 1AH;
	WriteMediumModeRegister = 1BH;
	ReadMonitorModeStatus = 1CH;
	WriteMonitorModeRegister = 1DH;
	ReadGPIOStatusRegister = 1EH;
	WriteGPIORegister = 1FH;
	WriteSoftwareReset = 20H;
	ReadPhySelectStatus = 21H;
	WritePhySelectRegister = 22H;

	(* Software Reset register encoding *)
	SRS_ClearFrameLengthErrorIn = {0};
	SRS_ClearFrameLengthErrorOut = {1};
	SRS_ExtPhyResetPinTristate = {2};
	SRS_ExtPhyResetPinLevel = {3};
	SRS_ForceZeroPacketIn = {4};
	SRS_IntPhyResetControl = {5};
	SRS_IntPhyPowerdownControl = {6};

	(* Medium Status/Mode Register Encoding (16bit) *)
	MSR_FullDuplex = 1;
	MSR_RxFlowControlEnable = 4;
	MSR_TxFlowControlEnable = 5;
	MSR_PauseFrameSimpleCheck = 7;
	MSR_ReceiveEnable = 8;
	MSR_PortSpeed = 9;
	MSR_StopBackpressure = 11;
	MSR_SuperMacSupport = 12;
	MSR_AlwaysZero = {0, 3, 6};
	MSR_AlwaysOne = {2};
	MSR_Reserved = {10, 13..15};

	(* Default medium mode when no auto-negotiation took place *)
	MSR_Default = MSR_AlwaysOne + {MSR_ReceiveEnable} + {MSR_TxFlowControlEnable} + {MSR_RxFlowControlEnable} + {MSR_PortSpeed} + {MSR_FullDuplex};

	(* Monitor Mode register encoding (8bit) *)
	MMR_MonitorMode = 0;
	MMR_WakeupOnLinkup = 1;
	MMR_WakeupOnMagicPacket = 2;
	MMR_UsbHighSpeed = 4;
	MMR_Reserved = {3..7};

	(* RX Control register encoding (16bit) *)
	RXCR_PromiscuousMode = 0;
	RXCR_AllMulticastFrames = 1;
	RXCR_SaveErrorPacket = 2;
	RXCR_AllBroadcasts = 3;
	RXCR_Multicast = 4;
	RXCR_AcceptPhysical = 5;
	RXCR_StartOperation = 7;
	RXCR_Msb = {8..9};
	RXCR_Reserved = {6, 10,11};

	(* GPIO register encoding (8bit)*)
	GP0OutputEnable = 0;
	GP1OutputEnable = 2;
	GP2OutputEnable = 4;
	GP0Value = 1;
	GP1Value = 3;
	GP2Value = 5;
	ReloadSerialEEPROM = 7;

	(* Interrupt Endpoint *)
	(* 3rd Byte *)
	IEB3_PrimaryPhyLinkUp = 0;
	IEB3_SecondaryPhyLinkUp = 1;
	IEB3_EthernetFrameLengthError = 2;
	IEB3_MdIntPinLevel = 3;

	(* SRAM access parameters *)
	RX = 0;
	TX = 1;

	TxPadBytes = LONGINT(0FFFF0000H);

	UsbHeaderSize = 4;

TYPE

	(* Access to media independent interface *)
	MII = OBJECT (Mii.MII)
	VAR
		device : Usbdi.UsbDevice;
		buffer : Usbdi.BufferPtr;

		PROCEDURE AcquirePhyOwnership*() : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(WriteCommand, SetSoftwareSerialManagement, 0, 0, 0, Usbdi.NoData);
			RETURN status = Usbdi.Ok;
		END AcquirePhyOwnership;

		PROCEDURE ReleasePhyOwnership*() : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(WriteCommand, SetHardwareSerialManagement, 0, 0, 0, Usbdi.NoData);
			RETURN status = Usbdi.Ok;
		END ReleasePhyOwnership;

		PROCEDURE HasPhyOwnership*() : BOOLEAN;
		VAR ownership : BOOLEAN; status : Usbdi.Status;
		BEGIN
			status := device.Request(ReadCommand, ReadSerialManagementStatus, 0, 0, 1, buffer^);
			IF status = Usbdi.Ok THEN
				ownership := 0 IN SYSTEM.VAL(SET, ORD(buffer[0]));
			ELSE
				IF Debug THEN Show("Error: Could not get status of PHY ownership."); KernelLog.Ln; END;
			END;
			RETURN ownership;
		END HasPhyOwnership;

		PROCEDURE ReadRegister16*(register: LONGINT; VAR value : SET; VAR res : LONGINT);
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(ReadCommand, ReadPhyRegister, phyId, register, 2, buffer^);
			IF status = Usbdi.Ok THEN
				value := SYSTEM.VAL(SET, ORD(buffer[0])) + LSH(SYSTEM.VAL(SET, ORD(buffer[1])), 8);
				res := Mii.Ok;
			ELSE
				res := Mii.ErrorRead;
			END;
		END ReadRegister16;

		PROCEDURE WriteRegister16*(register : LONGINT; value : SET; VAR res : LONGINT);
		VAR status : Usbdi.Status;
		BEGIN
			buffer[0] := CHR(SYSTEM.VAL(LONGINT, value));
			buffer[1] := CHR(SYSTEM.VAL(LONGINT, LSH(value, -8)));
			status := device.Request(WriteCommand, WritePhyRegister, phyId, register, 2, buffer^);
			IF status = Usbdi.Ok THEN
				res := Mii.Ok;
			ELSE
				res := Mii.ErrorWrite;
			END;
		END WriteRegister16;

		PROCEDURE &New*(device : Usbdi.UsbDevice; phyId : LONGINT);
		BEGIN
			Init(phyId);
			SELF.device := device;
			NEW(buffer, 2);
		END New;

	END MII;

TYPE

	Usb200MDriver = OBJECT (UsbNetwork.UsbNetworkController)
	VAR
		txBuffer : Usbdi.BufferPtr;
		txBufferAdr : ADDRESS;

		(* Receiving data is somewhat more complicated than sending it. Since the device expects us to always ask
		for at least bulkInPipe.maxPacketSize data, we can't use a standard ring buffer. Instead, we use a ring buffer with
		variable buffer end indicated by rxBufferLastIndex *)
		rxBufferHead : LONGINT; 		(* index in rxBuffer: next byte to be processed *)
		rxBufferTail : LONGINT; 			(* index in rxBuffer: next unused byte *)
		rxBufferLastIndex : LONGINT;	(* index in rxBuffer:  last byte that contains valid data *)
		rxBufferBytes : LONGINT; 		(* number of bytes in rxBuffer *)

		(* To make the parsing of the USB header & ethernet header simpler, we copy the header to the buffer start if it's
		not contiguous in the buffer. A headerBytes value n > 0 indicates that n bytes of the header are located at the end
		of the buffer and have to be copied to its start *)
		headerBytes : LONGINT;

		sRomWriteEnabled : BOOLEAN;

		mii : MII;

		primaryPhyId, primaryPhyType : LONGINT;
		secondaryPhyId, secondaryPhyType : LONGINT;

		gpioConfiguration : SET;

		PROCEDURE SendFrame*(dst: Network.LinkAdr; type: LONGINT; CONST l3hdr, l4hdr, data: ARRAY OF CHAR;  h3len, h4len, dofs, dlen: LONGINT);
		VAR status : Usbdi.Status; i, packetSize, padLength : LONGINT;
		BEGIN {EXCLUSIVE}
			(* 4 Byte USB header *)
			packetSize := UsbNetwork.EthernetHeaderSize + h3len + h4len + dlen;
			IF packetSize > UsbNetwork.MaxEthernetFrameSize THEN
				packetSize := UsbNetwork.MinEthernetFrameSize;
			ELSIF packetSize < UsbNetwork.MinEthernetFrameSize THEN
				packetSize := UsbNetwork.MinEthernetFrameSize;
			END;

			SYSTEM.PUT16(txBufferAdr, packetSize);
			SYSTEM.PUT16(txBufferAdr + 2, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, packetSize) / {0..15})); (* Checksum *)

			(* 14 Byte Ethernet Frame Header (destination address - source address - Frame type *)
			SYSTEM.MOVE(ADDRESSOF(dst[0]), txBufferAdr + 4, 6);
			SYSTEM.MOVE(ADDRESSOF(linkDevice.local[0]), txBufferAdr + 10, 6);
			SYSTEM.PUT16(txBufferAdr + 16, ROT(SYSTEM.VAL(INTEGER, LONGINT(type)), 8));

			i := UsbNetwork.EthernetHeaderSize + UsbHeaderSize;
			(* Network Layer Header *)
			IF h3len > 0 THEN SYSTEM.MOVE(ADDRESSOF(l3hdr[0]), txBufferAdr+i, h3len); INC(i, h3len) END;

			(* Transport Layer Header *)
			IF h4len > 0 THEN SYSTEM.MOVE(ADDRESSOF(l4hdr[0]), txBufferAdr+i, h4len); INC(i, h4len) END;

			(* Payload *)
			IF i + dlen < UsbNetwork.MaxEthernetFrameSize THEN
				SYSTEM.MOVE(ADDRESSOF(data[0]) + dofs, txBufferAdr + i, dlen); INC(i, dlen);
			ELSE
				Show("Warning: Maximum ethernet frame size exceeded. Packet dropped."); KernelLog.Ln;
			END;

			(* Pad Ethernet frame to minimum frame length if necessary *)
			IF Min60BytePacket THEN WHILE i < UsbNetwork.MinEthernetFrameSize + UsbHeaderSize DO txBuffer[i] := CHR(0); INC(i) END; END;
			IF Trace * TraceSend # {} THEN
				 KernelLog.String("[TRANSMIT] Packet length:"); KernelLog.Int(i, 5); KernelLog.Ln;
			END;

			padLength := 0;
			IF packetSize + UsbHeaderSize MOD bulkOutPipe.maxPacketSize = 0 THEN (* append pad bytes to force shortpacket *)
				padLength := 4;
				Network.Put4(txBuffer^, i, TxPadBytes);
			END;

			status := bulkOutPipe.Transfer(UsbHeaderSize + packetSize + padLength, 0, txBuffer^);

			IF status # Usbdi.Ok THEN
				IF Debug THEN Show("Bulk Out Pipe Error, res: "); KernelLog.Int(status, 0); KernelLog.Ln; END;
				IF status = Usbdi.Stalled THEN
					IF ~bulkOutPipe.ClearHalt() THEN
						Show("Bulk Out Pipe Fatal Error: Could not clear stall condition."); KernelLog.Ln;
					END;
				END;
			END;
		END SendFrame;

		PROCEDURE SoftwareReset(value : SET) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(WriteCommand, WriteSoftwareReset, SYSTEM.VAL(LONGINT, value), 0, 0, Usbdi.NoData);
			RETURN status = Usbdi.Ok;
		END SoftwareReset;

		PROCEDURE GetLinkAddress(VAR linkAddress : Network.LinkAdr; VAR res : LONGINT);
		VAR buffer : Usbdi.BufferPtr; status : Usbdi.Status; i : LONGINT;
		BEGIN
			NEW(buffer, 6);
			status := device.Request(ReadCommand, ReadNodeId, 0, 0, 6, buffer^);
			IF status = Usbdi.Ok THEN
				FOR i := 0 TO 5 DO linkAddress[i] := buffer[i]; END;
				res := UsbNetwork.Ok;
			ELSE
				res := UsbNetwork.Error;
			END;
		END GetLinkAddress;

		PROCEDURE SetLinkAddress(linkAddress : Network.LinkAdr; VAR res : LONGINT);
		VAR buffer : Usbdi.BufferPtr; status : Usbdi.Status; i : LONGINT;
		BEGIN
			NEW(buffer, 6);
			FOR i := 0 TO 5 DO buffer[i] := linkAddress[i]; END;
			status := device.Request(WriteCommand, WriteNodeId, 0, 0, 6, buffer^);
			IF status = Usbdi.Ok THEN
				res := UsbNetwork.Ok;
			ELSIF status = Usbdi.Stalled THEN
				res := UsbNetwork.Unsupported;
			ELSE
				res := UsbNetwork.Error;
			END;
		END SetLinkAddress;

		PROCEDURE LinkReset(verbose : BOOLEAN; VAR res : LONGINT);
		VAR mediumMode : SET; fullDuplex : BOOLEAN; linkSpeed : LONGINT;
		BEGIN
			mediumMode := MSR_Default;
			mii.Acquire;
			mii.GetAutoNegotiationResult(linkSpeed, fullDuplex, res);
			mii.Release;
			IF res = Mii.Ok THEN
				IF linkSpeed = 10 THEN mediumMode := mediumMode - {MSR_PortSpeed}; END;
				IF ~fullDuplex THEN mediumMode := mediumMode - {MSR_FullDuplex}; END;
			END;
			IF ~WriteMediumMode(mediumMode - MSR_AlwaysZero) THEN
				Show("Error: Could not set medium mode."); KernelLog.Ln;
				res := UsbNetwork.Error;
			ELSE
				IF verbose & Verbose THEN
					IF linkDevice # NIL THEN linkDevice.Show("Link speed: "); ELSE Show("Link speed: "); END;
					IF MSR_PortSpeed IN mediumMode THEN KernelLog.String("100 Mbps"); ELSE KernelLog.String("10 Mbps"); END;
					IF MSR_FullDuplex IN mediumMode THEN KernelLog.String(", Full Duplex"); ELSE KernelLog.String(", Half Duplex"); END;
					IF res = Mii.Ok THEN KernelLog.String(" (Auto-Negotiation)"); ELSE KernelLog.String(" (Manually selected)"); END;
					KernelLog.Ln;
				END;
				res := UsbNetwork.Ok;
			END;
		END LinkReset;

		(* Read RX control register *)
		PROCEDURE ReadRxControl(rxControl16bit : SET) : BOOLEAN;
		VAR buffer : Usbdi.BufferPtr; status : Usbdi.Status;
		BEGIN
			NEW(buffer, 2);
			status := device.Request(ReadCommand, ReadRxControlRegister, 0, 0, 2, buffer^);
			IF status = Usbdi.Ok THEN
				rxControl16bit := SYSTEM.VAL(SET, ORD(buffer[0])) + LSH(SYSTEM.VAL(SET, ORD(buffer[1])), 8);
			END;
			RETURN status = Usbdi.Ok;
		END ReadRxControl;

		(* Write RX control register *)
		PROCEDURE WriteRxControl(rxControl16Bit : SET) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(WriteCommand, WriteRxControlRegister, SYSTEM.VAL(LONGINT, rxControl16Bit), 0, 0, Usbdi.NoData);
			RETURN status = Usbdi.Ok;
		END WriteRxControl;

		(* Read medium mode status register *)
		PROCEDURE ReadMediumMode*(VAR mediumMode16bit : SET) : BOOLEAN;
		VAR buffer : Usbdi.BufferPtr; status : Usbdi.Status;
		BEGIN
			NEW(buffer, 2);
			status := device.Request(ReadCommand, ReadMediumStatus, 0, 0, 2, buffer^);
			IF status = Usbdi.Ok THEN
				mediumMode16bit := SYSTEM.VAL(SET, ORD(buffer[0])) + LSH(SYSTEM.VAL(SET, ORD(buffer[1])), 8);
			END;
			RETURN status = Usbdi.Ok;
		END ReadMediumMode;

		(* Write medium mode register *)
		PROCEDURE WriteMediumMode*(mediumMode16bit : SET) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(WriteCommand, WriteMediumModeRegister, SYSTEM.VAL(LONGINT, mediumMode16bit), 0, 0, Usbdi.NoData);
			RETURN status = Usbdi.Ok;
		END WriteMediumMode;

		PROCEDURE ScanRxBuffer;
		VAR
			index, packetSize, packetSizeChecksum, packetSizeEven, packetStart, type, res : LONGINT;
			contiguousLength, bytesCopied : LONGINT;
			error : BOOLEAN;
			buffer : Network.Buffer;
		BEGIN
			(* packet format:
				USB header
					2 byte packet length (excl. USB header)
					2 byte packet length checksum
				Ethernet header
					6 byte source address
					6 byte destination address
					2 byte type
				Payload
					packet length data bytes

				The device always sends 16-bit quantities, for uneven amounts of data, one padding byte will be added.
			*)
			index := rxBufferHead; error := FALSE;
			LOOP
				IF Trace * TraceReceiveDetailed # {} THEN
					KernelLog.String("[RECEIVE] RX Buffer: Head: "); KernelLog.Int(rxBufferHead, 0); KernelLog.String(", Tail: "); KernelLog.Int(rxBufferTail, 0);
					KernelLog.String(", last Index: "); KernelLog.Int(rxBufferLastIndex, 0); KernelLog.String(", Bytes: "); KernelLog.Int(rxBufferBytes, 0); KernelLog.Ln;
				END;
				(* The way we're doing the bulk in transfers guarantees that the header is always contiguous in the buffer *)
				headerBytes := 0;

				IF rxBufferBytes = 0 THEN
					IF Trace * TraceReceiveDetailed # {} THEN KernelLog.String("[RECEIVE] RX buffer empty"); KernelLog.Ln; END;
					EXIT;
				ELSIF rxBufferBytes < UsbHeaderSize + UsbNetwork.EthernetHeaderSize THEN (* wait for more bytes *)
					headerBytes := rxBufferBytes;
					IF Trace * TraceReceiveDetailed # {} THEN
						KernelLog.String("[RECEIVE] Header not yet complete, have "); KernelLog.Int(headerBytes, 0); KernelLog.String(" bytes so far"); KernelLog.Ln;
					END;
					EXIT;
				END;

				packetSize := Network.Get2(rxBuffer^, index);
				packetSizeChecksum := Network.Get2(rxBuffer^, index + 2);
				packetSizeEven := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, packetSize + 1) * {1..31});
				packetStart := index + 4;

				IF packetSize # SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, packetSizeChecksum) / {0..15}) THEN
					error := TRUE;
					Show("Packet size checksum error"); KernelLog.Ln;
					EXIT;
				ELSIF packetSize = 0FFF0H THEN
					error := TRUE;
					Show("Invalid packet size error"); KernelLog.Ln;
					EXIT;
				ELSIF packetSize > UsbNetwork.MaxEthernetFrameSize THEN
					error := TRUE;
					Show("Packet too big."); KernelLog.Ln;
					EXIT;
				END;

				IF Trace * TraceReceive # {} THEN KernelLog.String("[RECEIVE] PacketSize:"); KernelLog.Int(packetSize, 4); KernelLog.Ln; END;

				IF rxBufferBytes >= UsbHeaderSize + packetSizeEven THEN

					buffer := Network.GetNewBuffer();

					IF buffer # NIL THEN

						type := Network.GetNet2(rxBuffer^, packetStart + 6 + 6);

						buffer.ofs := 0;
						buffer.len := packetSize - 14;
						buffer.src := SYSTEM.VAL(Network.LinkAdr, rxBuffer^[packetStart + 6]);
						buffer.calcChecksum := {};

						contiguousLength := rxBufferLastIndex - packetStart + 1;
						ASSERT(contiguousLength >= 0);

						IF packetSize <= contiguousLength THEN (* no wrap aroung within packet boundaries *)
							IF Trace * TraceReceiveDetailed # {} THEN KernelLog.String("[RECEIVE] Contiguous packet"); KernelLog.Ln; END;
							Network.Copy(rxBuffer^, buffer.data, packetStart + UsbNetwork.EthernetHeaderSize, 0, packetSize - UsbNetwork.EthernetHeaderSize);
							INC(rxBufferHead, packetSize + UsbHeaderSize);
						ELSE
							IF Trace * TraceReceiveDetailed # {} THEN
								KernelLog.String("[RECEIVE] Non-contiguous packet: "); KernelLog.Int(contiguousLength, 0); KernelLog.String(" bytes at end, ");
								KernelLog.Int(packetSize - contiguousLength, 0); KernelLog.String(" bytes at start"); KernelLog.Ln;
							END;
							bytesCopied := 0;
							IF contiguousLength - UsbNetwork.EthernetHeaderSize > 0 THEN
								bytesCopied := contiguousLength - UsbNetwork.EthernetHeaderSize;
								Network.Copy(rxBuffer^, buffer.data, packetStart + UsbNetwork.EthernetHeaderSize, 0, bytesCopied);
							END;
							rxBufferHead := 0;
							Network.Copy(rxBuffer^, buffer.data, rxBufferHead, bytesCopied, packetSize - bytesCopied);
							INC(rxBufferHead, packetSize - contiguousLength);
							rxBufferLastIndex := rxBufferTail - 1;
						END;

						linkDevice.QueueBuffer(buffer, type);

						DEC(rxBufferBytes, packetSize + UsbHeaderSize);

						IF rxBufferHead MOD 2 = 1 THEN (* pad byte since device sends 2byte quantities *)
							INC(rxBufferHead);
							DEC(rxBufferBytes);
						END;

						(* incrementing rxBufferHead above could do a wrap around -> handle it *)
						IF (rxBufferBytes > 0) & (rxBufferHead > rxBufferLastIndex) THEN
							rxBufferHead := 0;
							rxBufferLastIndex := rxBufferTail - 1;
						END;

						IF rxBufferHead = rxBufferTail THEN rxBufferLastIndex := rxBufferTail; END;

						index := rxBufferHead;
					ELSE
						Show("Receive buffer underrun."); KernelLog.Ln;
					END;

				ELSE
					IF Trace * TraceReceive # {} THEN KernelLog.String("[RECEIVE] Waiting for more data"); KernelLog.Ln; END;
					EXIT; (* Wait until the complete packet is in the buffer *)
				END;
			END;
			IF error THEN
				IF Debug THEN Show("Link reset forced."); KernelLog.Ln; END;
				ResetRxBuffer;
				LinkReset(FALSE, res);
				IF res # UsbNetwork.Ok THEN Show("Fatal error. Link reset failed."); KernelLog.Ln; END;
			END;
		END ScanRxBuffer;

		PROCEDURE ResetRxBuffer;
		BEGIN
			rxBufferHead := 0; rxBufferTail := 0; rxBufferLastIndex := 0;
			rxBufferBytes := 0; headerBytes := 0;
		END ResetRxBuffer;

		PROCEDURE HandleBulkIn*(status : Usbdi.Status; actLen : LONGINT);
		VAR i : LONGINT;
		BEGIN
			IF (status = Usbdi.Ok) OR (status = Usbdi.ShortPacket) THEN
				IF Trace * TraceReceive # {} THEN Show("[USB RECEIVE] "); KernelLog.Int(actLen, 5); KernelLog.String(" Bytes"); KernelLog.Ln; END;
				IF actLen = 0 THEN RETURN; END;

				(* Buffer accounting *)
				INC(rxBufferTail, actLen);
				IF rxBufferLastIndex < rxBufferTail - 1 THEN rxBufferLastIndex := rxBufferTail - 1; END;
				INC(rxBufferBytes, actLen);

				ScanRxBuffer;

				IF rxBufferTail + BulkInRequestSize > LEN(rxBuffer) THEN (* wrap around *)
					(* Unfortunately, requesting less bytes than maxPacketSize results in a babble when the device has more data to send
					, so	we have to ask for maxPacketSize bytes of data *)
					IF Trace * TraceReceiveDetailed # {} THEN KernelLog.String("[RECEIVE] Buffer wrap"); KernelLog.Ln; END;
					IF headerBytes > 0 THEN (* copy the header at the end of the buffer to the buffer start *)
						IF Trace * TraceReceiveDetailed # {} THEN
							KernelLog.String("[RECEIVE] Copying header to buffer start:: "); KernelLog.Int(headerBytes, 0); KernelLog.String(" bytes from index ");
							KernelLog.Int(rxBufferHead, 0); KernelLog.Ln;
						END;
						FOR i := 0 TO headerBytes-1 DO
							rxBuffer[i] := rxBuffer[rxBufferHead + i];
						END;
						rxBufferHead := 0;
						rxBufferLastIndex := headerBytes - 1;
						rxBufferTail := headerBytes;
					ELSE
						rxBufferTail := 0;
						IF rxBufferBytes = 0 THEN
							rxBufferHead := 0;
							rxBufferLastIndex := 0;
						END;
					END;
				END;

				status := bulkInPipe.Transfer(BulkInRequestSize, rxBufferTail, rxBuffer^);
			ELSE
				IF Debug THEN Show("Bulk IN Pipe Error, res: "); KernelLog.Int(status, 0); KernelLog.Ln; END;
				IF status = Usbdi.Stalled THEN
					IF ~bulkInPipe.ClearHalt() THEN
						Show("Bulk IN Pipe Fatal Error: Could not clear stall condition."); KernelLog.Ln;
					END;
				END;
			END;
		END HandleBulkIn;

		PROCEDURE HandleInterrupt*(status : Usbdi.Status; actLen : LONGINT);
		VAR s, register1, register2 : SET; oldLinkStatus : LONGINT; res : LONGINT;
		BEGIN
			IF (status = Usbdi.Ok) OR ((status = Usbdi.ShortPacket) & (actLen >=8)) THEN
				s := SYSTEM.VAL(SET, ORD(interruptInBuffer[2]));
				oldLinkStatus := linkStatus;

				IF IEB3_PrimaryPhyLinkUp IN s THEN
					linkStatus := Network.LinkLinked;
				ELSE
					linkStatus := Network.LinkNotLinked;
				END;

				IF IEB3_EthernetFrameLengthError IN s THEN
					IF Debug THEN Show("Bulk out ethernet frame length error detected. Forcing Link reset."); KernelLog.Ln; END;
					LinkReset(FALSE, res); (* ignore res *)
				END;

				IF Verbose THEN
					IF oldLinkStatus # linkStatus THEN
						IF linkStatus = Network.LinkUnknown THEN
							linkDevice.Show("No cable connected."); KernelLog.Ln;
						ELSIF linkStatus = Network.LinkNotLinked THEN
							linkDevice.Show("Connection lost."); KernelLog.Ln;
						ELSIF linkStatus = Network.LinkLinked THEN
							linkDevice.Show("Connection established."); KernelLog.Ln;
						END;
					END;
				END;

				IF oldLinkStatus # linkStatus THEN
					IF linkStatus = Network.LinkLinked THEN
						LinkReset(TRUE, res);
					ELSE
						LinkReset(FALSE, res);
					END;
					IF res # UsbNetwork.Ok THEN
						IF Debug THEN Show("Link Reset failed."); KernelLog.Ln; END;
					END;
				END;

				(* Registers of primary Phy. Offset specified in EEPROM at 0Fh *)
				register1 := SYSTEM.VAL(SET, ORD(interruptInBuffer[4])) + LSH(SYSTEM.VAL(SET, ORD(interruptInBuffer[5])), 8);
				register2 := SYSTEM.VAL(SET, ORD(interruptInBuffer[6])) + LSH(SYSTEM.VAL(SET, ORD(interruptInBuffer[7])), 8);

				status := interruptInPipe.Transfer(interruptInPipe.maxPacketSize, 0, interruptInBuffer^); (* ignore status *)
			ELSE
				IF Debug THEN Show("Interrupt IN Pipe Error, res: "); KernelLog.Int(status, 0); KernelLog.Ln; END;
				IF status = Usbdi.Stalled THEN
					IF ~interruptInPipe.ClearHalt() THEN
						Show("Interrupt IN Pipe Fatal Error: Could not clear stall condition."); KernelLog.Ln;
					END;
				END;
			END;
		END HandleInterrupt;

		PROCEDURE InitController*(VAR rxBuffer : Usbdi.BufferPtr) : BOOLEAN;
		VAR
			rxControl : SET;
			res : LONGINT; timer : Kernel.Timer;
			customLinkAdr : Network.LinkAdr;
		BEGIN
			GetPhyId(primaryPhyId, primaryPhyType, secondaryPhyId, secondaryPhyType, res);
			IF res # UsbNetwork.Ok THEN
				Show("Error: Could not read PHY ID/Type."); KernelLog.Ln;
				RETURN FALSE;
			END;

			(* Manufactur/model-specific GPIO configuration *)
			IF ~WriteGpioRegister(gpioConfiguration) THEN
				Show("Error: Could not configure GPIO pins."); KernelLog.Ln;
				RETURN FALSE;
			END;

			(* Select the internal PHY *)
			SetPhySelect(TRUE, FALSE, res);
			IF res # UsbNetwork.Ok THEN
				Show("Error: Could not select PHY."); KernelLog.Ln;
				RETURN FALSE;
			END;

			(* Power down internal PHY *)
			IF ~SoftwareReset(SRS_IntPhyPowerdownControl) THEN
				Show("Error: Could not power down internal PHY."); KernelLog.Ln;
				RETURN FALSE;
			END;

			(* Power up and reset internal PHY *)
			IF ~SoftwareReset({}) THEN
				Show("Error: Could not set internal PHY state to operating."); KernelLog.Ln;
				RETURN FALSE;
			END;

			(* Set internal PHY to operating mode and set external PHY reset pin level to high *)
			IF ~SoftwareReset(SRS_IntPhyResetControl + SRS_ExtPhyResetPinLevel) THEN
				Show("Error: Configuration error."); KernelLog.Ln;
				RETURN FALSE;
			END;

			(* Ethernet MAC stop operation *)
			IF ~WriteRxControl({}) THEN
				Show("Error: Could not write RX control register."); KernelLog.Ln;
				RETURN FALSE;
			END;

			IF ~WriteIPGRegisters(15X, 0CX, 0EX) THEN
				Show("Error: Could not set IPG registers."); KernelLog.Ln;
				RETURN FALSE;
			END;

			NEW(mii, device, primaryPhyId);

			mii.Acquire;

			mii.Reset(res);
			IF res # Mii.Ok THEN
				Show("Error: MII Reset failed."); KernelLog.Ln;
				mii.Release;
				RETURN FALSE;
			END;

			mii.EnableAutoNegotiation(TRUE, res);
			IF res # Mii.Ok THEN
				Show("Error: Enabling Auto-Negotiation failed."); KernelLog.Ln;
				mii.Release;
				RETURN FALSE;
			END;

			mii.Release;

			(* Wait shortly so auto-negotiation takes place *)
			NEW(timer); timer.Sleep(200);

			LinkReset(FALSE, res);
			IF res # Mii.Ok THEN
				Show("Error: Could not reset link."); KernelLog.Ln;
				RETURN FALSE;
			END;

			IF MacAddress # "EEPROM" THEN (* Use user-specific MAC address *)
				IF StringToLinkAdr(MacAddress, customLinkAdr) THEN
					SetLinkAddress(customLinkAdr, res);
					IF res = UsbNetwork.Ok THEN
						KernelLog.String(name); KernelLog.String(": Using user-specific MAC address: "); KernelLog.String(MacAddress); KernelLog.Ln;
					ELSE
						KernelLog.String(name); KernelLog.String(": Failed to set user-specific MAC address"); KernelLog.Ln;
					END;
				ELSE
					KernelLog.String(name); KernelLog.String(" Failed to convert user-specified MAC address into link address."); KernelLog.Ln;
				END;
			END;

			bulkOutPipe.mode := Usbdi.MaxPerformance;

			(* Start MAC operation *)
			rxControl := {RXCR_AllBroadcasts} + {RXCR_StartOperation};
			rxControl := rxControl + RXCR_Msb; (* 16K Frame Bursts on USB *)
			IF PromiscuousMode THEN
				IF Verbose THEN Show("Enabled promiscuous mode."); KernelLog.Ln; END;
				INCL(rxControl, RXCR_PromiscuousMode);
			END;
			IF  ~WriteRxControl(rxControl) THEN
				Show("Error: Could not enable MAC operation."); KernelLog.Ln;
				RETURN FALSE;
			END;

			NEW(rxBuffer, RxBufferSize);
			ResetRxBuffer;

			NEW(txBuffer, UsbNetwork.MaxEthernetFrameSize + UsbHeaderSize);
			txBufferAdr := ADDRESSOF(txBuffer[0]);

			RETURN TRUE;
		END InitController;

		PROCEDURE ReadMulticastFilterArray(bitmap : Usbdi.BufferPtr) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			ASSERT((bitmap # NIL) & (LEN(bitmap) >= 8));
			status := device.Request(ReadCommand, ReadMcastFilterArray, 0, 0, 8, bitmap^);
			RETURN status = Usbdi.Ok;
		END ReadMulticastFilterArray;

		PROCEDURE WriteMulticastFilterArray(bitmap : Usbdi.BufferPtr) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			ASSERT((bitmap # NIL) & (LEN(bitmap) >= 8));
			status := device.Request(WriteCommand, ReadMcastFilterArray, 0, 0, 8, bitmap^);
			RETURN status = Usbdi.Ok;
		END WriteMulticastFilterArray;

		PROCEDURE ReadIPGRegisters(VAR ipg, ipg1, ipg2 : CHAR) : BOOLEAN;
		VAR buffer : Usbdi.BufferPtr; status : Usbdi.Status;
		BEGIN
			NEW(buffer, 3);
			status := device.Request(ReadCommand, ReadIpgControlRegister, 0, 0, 3, buffer^);
			IF status = Usbdi.Ok THEN
				ipg := buffer[0];
				ipg1 := buffer[1];
				ipg2 := buffer[2];
			END;
			RETURN status = Usbdi.Ok;
		END ReadIPGRegisters;

		PROCEDURE WriteIPGRegisters(ipg, ipg1, ipg2 : CHAR) : BOOLEAN;
		VAR wValue, wIndex : LONGINT; status : Usbdi.Status;
		BEGIN
			wValue := ORD(ipg) + 100H* SYSTEM.VAL(LONGINT, ORD(ipg1));
			wIndex := SYSTEM.VAL(LONGINT, ORD(ipg2));
			status := device.Request(WriteCommand, WriteIpgControlRegister, wValue, wIndex, 0, Usbdi.NoData);
			RETURN status = Usbdi.Ok;
		END WriteIPGRegisters;

		PROCEDURE ReadMonitorMode(VAR monitorMode, wakeupOnLinkup, wakeupOnMagicPacket : BOOLEAN; VAR usbSpeed : LONGINT) : BOOLEAN;
		VAR s : SET; buffer : Usbdi.BufferPtr; status : Usbdi.Status;
		BEGIN
			NEW(buffer, 1);
			status := device.Request(ReadCommand, ReadMonitorModeStatus, 0, 0, 1, buffer^);
			IF status = Usbdi.Ok THEN
				s := SYSTEM.VAL(SET, ORD(buffer[0]));
				monitorMode := MMR_MonitorMode IN s;
				wakeupOnLinkup := MMR_WakeupOnLinkup IN s;
				wakeupOnMagicPacket := MMR_WakeupOnMagicPacket IN s;
				IF MMR_UsbHighSpeed IN s THEN usbSpeed := 480; ELSE usbSpeed := 12; END
			END;
			RETURN status = Usbdi.Ok;
		END ReadMonitorMode;

		PROCEDURE WriteMonitorMode(monitorMode, wakeupOnLinkup, wakeupOnMagicPacket : BOOLEAN) : BOOLEAN;
		VAR set : SET; status : Usbdi.Status;
		BEGIN
			IF monitorMode THEN INCL(set, MMR_MonitorMode); END;
			IF wakeupOnLinkup THEN INCL(set, MMR_WakeupOnLinkup); END;
			IF wakeupOnMagicPacket THEN INCL(set, MMR_WakeupOnMagicPacket); END;
			status := device.Request(WriteCommand, WriteMonitorModeRegister, SYSTEM.VAL(LONGINT, set), 0, 0, Usbdi.NoData);
			RETURN status = Usbdi.Ok;
		END WriteMonitorMode;

		PROCEDURE GetPhyId(VAR primaryPhyId, primaryPhyType, secondaryPhyId, secondaryPhyType, res : LONGINT);
		VAR set : SET; buffer : Usbdi.BufferPtr; status : Usbdi.Status;
		BEGIN
			NEW(buffer, 2);
			status := device.Request(ReadCommand, ReadPhyAddressRegister, 0, 0, 2, buffer^);
			IF status = Usbdi.Ok THEN
				set := SYSTEM.VAL(SET, ORD(buffer[0]));
				secondaryPhyId := SYSTEM.VAL(LONGINT, set * {0..4});
				secondaryPhyType := SYSTEM.VAL(LONGINT, LSH(set * {5..7}, -5));
				set := SYSTEM.VAL(SET, ORD(buffer[1]));
				primaryPhyId := SYSTEM.VAL(LONGINT, set * {0..4});
				primaryPhyType := SYSTEM.VAL(LONGINT, LSH(set * {5..7}, -5));
				res := UsbNetwork.Ok;
			ELSE
				res := UsbNetwork.Error;
			END;
		END GetPhyId;

		(**
			Which PHY is selected?
			@embedded: If TRUE: Embedded 10/100Mbps PHY is select; If FALSE; External PHY is selected
			@autoSelect: If TRUE, Automatically selected on link status of embedded PHY; If FALSE: Manually selected PHY
			@res: UsbNetwork.Ok if command succeeded
		*)
		PROCEDURE GetPhySelectStatus(VAR embedded, autoSelect : BOOLEAN; VAR res : LONGINT);
		VAR buffer : Usbdi.BufferPtr; status : Usbdi.Status;
		BEGIN
			NEW(buffer, 1);
			status := device.Request(ReadCommand, ReadPhySelectStatus, 0, 0, 1, buffer^);
			IF status = Usbdi.Ok THEN
				embedded := 0 IN SYSTEM.VAL(SET, ORD(buffer[0]));
				autoSelect := 1 IN SYSTEM.VAL(SET, ORD(buffer[0]));
				res := UsbNetwork.Ok;
			ELSE
				res := UsbNetwork.Error;
			END;
		END GetPhySelectStatus;

		PROCEDURE SetPhySelect(embedded, autoSelect : BOOLEAN; VAR res : LONGINT);
		VAR set : SET; status : Usbdi.Status;
		BEGIN
			IF embedded THEN INCL(set, 0); END;
			IF autoSelect THEN INCL(set, 1); END;
			status := device.Request(WriteCommand, WritePhySelectRegister, SYSTEM.VAL(LONGINT, set), 0, 0, Usbdi.NoData);
			IF status = Usbdi.Ok THEN
				res := UsbNetwork.Ok;
			ELSE
				res := UsbNetwork.Error;
			END;
		END SetPhySelect;

		PROCEDURE ReadGpioRegister(VAR gpio8bit : SET; VAR res : LONGINT);
		VAR buffer : Usbdi.BufferPtr; status : Usbdi.Status;
		BEGIN
			NEW(buffer, 1);
			status := device.Request(ReadCommand, ReadGPIOStatusRegister, 0, 0, 1, buffer^);
			IF status = Usbdi.Ok THEN
				gpio8bit := SYSTEM.VAL(SET, ORD(buffer[0]));
				res := UsbNetwork.Ok;
			ELSE
				res := UsbNetwork.Error;
			END;
		END ReadGpioRegister;

		PROCEDURE WriteGpioRegister(gpio8bit : SET) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			status := device.Request(WriteCommand, WriteGPIORegister, SYSTEM.VAL(LONGINT, gpio8bit), 0, 0, Usbdi.NoData);
			RETURN status = Usbdi.Ok;
		END WriteGpioRegister;

		(** Enable/disable write access to SROM *)
		PROCEDURE SromWriteEnable(enable : BOOLEAN) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN
			IF enable THEN
				status := device.Request(WriteCommand, WriteSromEnable, 0, 0, 0, Usbdi.NoData);
			ELSE
				status := device.Request(WriteCommand, WriteSromDisable, 0, 0, 0, Usbdi.NoData);
			END;
			IF status = Usbdi.Ok THEN sRomWriteEnabled := enable; END;
			RETURN status = Usbdi.Ok;
		END SromWriteEnable;

		(* Read register from 2-byte addressed SROM *)
		PROCEDURE SromRead16(address : LONGINT; VAR word : LONGINT;  VAR res : LONGINT);
		VAR buffer : Usbdi.BufferPtr; status : Usbdi.Status;
		BEGIN
			ASSERT(address < 256);
			NEW(buffer, 2);
			status := device.Request(ReadCommand, ReadSromRegister, address, 0, 2, buffer^);
			IF status = Usbdi.Ok THEN
				word := SYSTEM.VAL(LONGINT, ORD(buffer[0])) + 100H*SYSTEM.VAL(LONGINT, ORD(buffer[1]));
				res := UsbNetwork.Ok;
			ELSE
				res := UsbNetwork.Error;
			END;
		END SromRead16;

		(* Write register to 2-byte addressed SROM *)
		PROCEDURE SromWrite16(address : LONGINT; word : LONGINT;  VAR res : LONGINT);
		VAR status : Usbdi.Status;
		BEGIN
			ASSERT(sRomWriteEnabled);
			ASSERT(address < 256);
			status := device.Request(WriteCommand, WriteSromRegister, address, word, 0, Usbdi.NoData);
			IF status = Usbdi.Ok THEN
				res := UsbNetwork.Ok;
			ELSE
				res := UsbNetwork.Error;
			END;
		END SromWrite16;

		(** SRAM buffer access *)

		PROCEDURE WriteSRAM(ram, address : LONGINT; buffer : Usbdi.BufferPtr) : BOOLEAN;
		VAR a : SET; wValue, wIndex : LONGINT; status : Usbdi.Status;
		BEGIN (* UNTESTED *)
			a := SYSTEM.VAL(SET, address);
			wValue := SYSTEM.VAL(LONGINT, LSH(a * {0..7}, 8) + LSH(a * {8..10}, -8));
			wIndex := LSH(ram, 8);
			status := device.Request(WriteCommand, WriteRxTxRegister, wValue, wIndex, 8, buffer^);
			RETURN status = Usbdi.Ok;
		END WriteSRAM;

		PROCEDURE ReadSRAM(ram, address : LONGINT; buffer : Usbdi.BufferPtr) : BOOLEAN;
		VAR a : SET; wValue, wIndex : LONGINT; status : Usbdi.Status;
		BEGIN (* UNTESTED *)
			a := SYSTEM.VAL(SET, address);
			wValue := SYSTEM.VAL(LONGINT, LSH(a * {0..7}, 8) + LSH(a * {8..10}, -8));
			wIndex := LSH(ram, 8);
			status := device.Request(ReadCommand, ReadRxTxRegister, wValue, wIndex, 8, buffer^);
			RETURN status = Usbdi.Ok;
		END ReadSRAM;

		PROCEDURE Finalize;
			(* do nothing *)
		END Finalize;

		PROCEDURE Diag;
		VAR
			linkAdr : Network.LinkAdr;
			embeddedPhy, autoSelect : BOOLEAN;
			monitorMode, wakeupOnLinkup, wakeupOnMagicPacket : BOOLEAN; usbSpeed : LONGINT;
			priId, priType, secId, secType : LONGINT;
			set : SET;
			i, word, res : LONGINT;
		BEGIN
			Diag^;
			GetLinkAddress(linkAdr, res);
			IF res = UsbNetwork.Ok THEN
				KernelLog.String("Link Address: "); Network.OutLinkAdr(linkAdr, 6);KernelLog.Ln;
			ELSE KernelLog.String("Error: Could not get link address information."); KernelLog.Ln;
			END;

			IF ReadMediumMode(set) THEN ShowMediumModeRegister(set);
			ELSE KernelLog.String("Error: Could not get medium mode information."); KernelLog.Ln;
			END;

			IF ReadMonitorMode(monitorMode, wakeupOnLinkup, wakeupOnMagicPacket, usbSpeed) THEN
				ShowMonitorMode(monitorMode, wakeupOnLinkup, wakeupOnMagicPacket, usbSpeed);
			ELSE KernelLog.String("Error: Could not get monitor mode information."); KernelLog.Ln;
			END;

			IF ReadRxControl(set) THEN ShowRxControlRegister(set);
			ELSE KernelLog.String("Error: Could not get RX control status."); KernelLog.Ln;
			END;

			GetPhySelectStatus(embeddedPhy, autoSelect, res);
			IF res = UsbNetwork.Ok THEN ShowPhySelectStatus(embeddedPhy, autoSelect);
			ELSE KernelLog.String("Error: Could not get PHY select status information."); KernelLog.Ln;
			END;

			GetPhyId(priId, priType, secId, secType, res);
			IF res = UsbNetwork.Ok THEN
				KernelLog.String("Primary PHY: ID: "); KernelLog.Int(priId, 0); KernelLog.String(", Type: "); KernelLog.Int(priType, 0); KernelLog.Ln;
				KernelLog.String("Secondary PHY: ID: "); KernelLog.Int(secId, 0); KernelLog.String(", Type: "); KernelLog.Int(secType, 0); KernelLog.Ln;
			ELSE KernelLog.String("Error: Could not get PHY ID/Type information."); KernelLog.Ln;
			END;

			ReadGpioRegister(set, res);
			IF res = UsbNetwork.Ok THEN ShowGpioStatusRegister(set);
			ELSE KernelLog.String("Error: Could not read GPIO status register."); KernelLog.Ln;
			END;

			mii.Acquire;
			mii.Diag;
			mii.Release;

			KernelLog.String("First 28H Bytes of EEPROM: "); KernelLog.Ln;
			i := 0;
			LOOP
				KernelLog.Hex(i, -2); KernelLog.String("H: ");
				SromRead16(i, word, res);
				IF res # UsbNetwork.Ok THEN
					Show("Error: Could not read SROM."); KernelLog.Ln;
				ELSE
					KernelLog.Hex(word, 0); KernelLog.Ln;
				END;
				INC(i);
				IF i > 14H THEN EXIT; END;
			END;

		END Diag;

	END Usb200MDriver;

(* Converts a string formatted as AA:BB:CC:DD:EE:FF:GG into a Network link address *)
PROCEDURE StringToLinkAdr(CONST string : ARRAY OF CHAR; VAR linkAdr : Network.LinkAdr) : BOOLEAN;
VAR stringArray : Strings.StringArray; value, i, res : LONGINT;
BEGIN
	stringArray := Strings.Split(string, ":");
	IF LEN(stringArray) = 6 THEN
		FOR i := 0 TO LEN(stringArray)-1 DO
			Strings.HexStrToInt(stringArray[i]^, value, res);
			IF res = 0 THEN
				linkAdr[i] := CHR(value);
			ELSE
				RETURN FALSE;
			END;
		END;
		RETURN TRUE;
	END;
	RETURN FALSE;
END StringToLinkAdr;

PROCEDURE ShowMonitorMode(monitorMode, wakeupOnLinkup, wakeupOnMagicPacket : BOOLEAN;  usbSpeed : LONGINT);
BEGIN
	KernelLog.String("Monitor Mode Status:"); KernelLog.Ln;
	KernelLog.String("   Monitor Mode: "); KernelLog.Boolean(monitorMode); KernelLog.Ln;
	KernelLog.String("   Remote Wakeup triggered by Ethernet Link-up: "); KernelLog.Boolean(wakeupOnLinkup); KernelLog.Ln;
	KernelLog.String("   Remote Wakeup triggered by Magic Packet: "); KernelLog.Boolean(wakeupOnMagicPacket); KernelLog.Ln;
	KernelLog.String("   USB speed: "); KernelLog.Int(usbSpeed, 0); KernelLog.String("Mbps");
	KernelLog.Ln;
END ShowMonitorMode;

PROCEDURE ShowPhySelectStatus(embeddedPhy, autoSelect : BOOLEAN);
BEGIN
	KernelLog.String("PHY Select Status:"); KernelLog.Ln;
	KernelLog.String("   Selected PHY: ");
	IF embeddedPhy THEN
		KernelLog.String("Embedded 10/100Mbps PHY");
	ELSE
		KernelLog.String("External PHY");
	END;
	KernelLog.String(" (");
	IF autoSelect THEN KernelLog.String("Auto Select"); ELSE KernelLog.String("Manual Select"); END;
	KernelLog.String(")");
	KernelLog.Ln;
END ShowPhySelectStatus;

PROCEDURE ShowMediumModeRegister(s : SET);
BEGIN
	KernelLog.String("Medium status: "); KernelLog.Ln;
	KernelLog.String("   Port speed: ");
	IF MSR_PortSpeed IN s THEN KernelLog.String("100 MBps"); ELSE KernelLog.String("10 MBps"); END; KernelLog.String(", ");
	IF MSR_FullDuplex IN s THEN KernelLog.String("Full Duplex"); ELSE KernelLog.String("Half Duplex"); END;
	KernelLog.Ln;
	KernelLog.String("   Flow control: ");
	KernelLog.String("RX: "); KernelLog.Boolean(MSR_RxFlowControlEnable IN s);
	KernelLog.String(", TX: "); KernelLog.Boolean(MSR_TxFlowControlEnable IN s);
	KernelLog.Ln;
	KernelLog.String("   Pause Frame only length/type: "); KernelLog.Boolean(MSR_PauseFrameSimpleCheck IN s);
	KernelLog.String(", Receive Enable: "); KernelLog.Boolean(MSR_ReceiveEnable IN s);
	KernelLog.String(", Stop Backpressure: "); KernelLog.Boolean(MSR_StopBackpressure IN s);
	KernelLog.String(", Super Max support: "); KernelLog.Boolean(MSR_SuperMacSupport IN s);
	KernelLog.Ln;
END ShowMediumModeRegister;

PROCEDURE ShowRxControlRegister(s : SET);
VAR value : LONGINT;
BEGIN
	KernelLog.String("RX Control:"); KernelLog.Ln;
	KernelLog.String("   Promiscuous mode: "); KernelLog.Boolean(RXCR_PromiscuousMode IN s); KernelLog.Ln;
	KernelLog.String("   Forward packets to host: "); KernelLog.Ln;
	KernelLog.String("      All Multicasts: "); KernelLog.Boolean(RXCR_AllMulticastFrames IN s); KernelLog.Ln;
	KernelLog.String("      Packets with CRC error: "); KernelLog.Boolean(RXCR_SaveErrorPacket IN s); KernelLog.Ln;
	KernelLog.String("      Multicasts whose DA match multicast address list: "); KernelLog.Boolean(RXCR_Multicast IN s); KernelLog.Ln;
	KernelLog.String("      Unicasts whos DA match multicast address list: "); KernelLog.Boolean(RXCR_AcceptPhysical IN s); KernelLog.Ln;
	KernelLog.String("   Ethernet MAC start operating: "); KernelLog.Boolean(RXCR_StartOperation IN s); KernelLog.Ln;
	KernelLog.String("   Maximum frame burst transfer on USB: ");
	value := SYSTEM.VAL(LONGINT, LSH(s * RXCR_Msb, -8));
	CASE value OF
		|0: KernelLog.String("2048 Bytes");
		|1: KernelLog.String("4096 Bytes");
		|2: KernelLog.String("8192 Bytes");
		|3: KernelLog.String("16384 Bytes");
	ELSE
		KernelLog.String("Invalid Value");
	END;
	KernelLog.Ln;
END ShowRxControlRegister;

PROCEDURE ShowGpioStatusRegister(s : SET);
BEGIN
	KernelLog.String("GPIO Configuration: ");
	KernelLog.String("GP0: "); IF GP0OutputEnable IN s THEN KernelLog.String("OUT"); ELSE KernelLog.String("IN"); END;
	KernelLog.String(", GP1: "); IF GP1OutputEnable IN s THEN KernelLog.String("OUT"); ELSE KernelLog.String("IN"); END;
	KernelLog.String(", GP2: "); IF GP2OutputEnable IN s THEN KernelLog.String("OUT"); ELSE KernelLog.String("IN"); END;
	KernelLog.Ln;
END ShowGpioStatusRegister;

PROCEDURE Show(CONST string : ARRAY OF CHAR);
BEGIN
	KernelLog.String(ModuleName); KernelLog.String(": "); KernelLog.String(string);
END Show;

PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR driver : Usb200MDriver;
BEGIN
	IF (dev.descriptor.idVendor = 13B1H) & (dev.descriptor.idProduct = 0018H) & (id.bInterfaceNumber = 0) THEN (* Linksys USB200M *)
		NEW(driver); driver.gpioConfiguration := {GP2OutputEnable, GP2Value, ReloadSerialEEPROM};
	END;
	RETURN driver;
END Probe;

PROCEDURE Cleanup;
BEGIN
	Usbdi.drivers.Remove(Name);
END Cleanup;

PROCEDURE Install*;
END Install;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Usbdi.drivers.Add(Probe, Name, Description, Priority)
END UsbNetworkUSB200M.

UsbNetworkUSB200M.Install ~

SystemTools.Free UsbNetworkUSB200M UsbNetwork NetworkMii ~