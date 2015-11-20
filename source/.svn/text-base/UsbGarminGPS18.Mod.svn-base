MODULE UsbGarminGPS18;  (** AUTHOR "staubesv"; PURPOSE "Garmin GPS 18 USB Driver"; *)
(**
 * Status:
 *
 *	14.12.2005: Device works, delivered data is valid.  No interface for clients implemented so far.
 *
 * Usage:
 *
 *	UsbGarminGPS18.Install ~ loads this driver
 *	SystemTools.Free UsbGarminGPS18 ~ unloads it
 *
 * Note: The GPS needs several minutes until it receives PVT (position, velocity, time) data.
 *
 * References:
 *
 *	GARMIN GPS Interface Specification USB Addendum (Rev. 3)
 *
 * History:
 *
 *	01.12.2005 	History started (staubesv)
 *	14.12.2005 	Fixed PVT data parsing, some cleanup (staubesv)
 *	05.07.2006	Adapted to Usbdi (staubesv)
 *)

IMPORT SYSTEM, KernelLog, Modules, Kernel, Strings, Usbdi;

CONST

	Name = "UsbGps";
	Description = "Garmin GPS 18 USB";

	Debug = TRUE;

	TraceEvents = {1};
	TracePackets = {2};
	TraceDeviceInfo = {3};
	TraceData = {4};
	TraceSatelliteInfo = {5};
	TracePVTData = {6};
	TraceAll = {0..31};
	TraceNone = {};

	Trace = TracePVTData + TraceSatelliteInfo;

	(* Packet format: 														*)
	(*																		*)
	(* Byte 0 : 		PacketType (Transport Layer = 0, Application Layer = 20)	*)
	(* Byte 1-3 : 	Reserved (must be 0)									*)
	(* Byte 4-5 : 	PacketID												*)
	(* Byte 6-7 : 	Reserved (must be 0)									*)
	(* Byte 4-11: 	DataSize												*)
	(* Byte 12+  :	Data													*)
	PacketTransport = 0;
	PacketApplication = 20;

	(* Transport layer packets *)
	TlPidDataAvailable = 2;
	TlPidStartSession = 5; 	(* host-to-device: start session *)
	TlPidSessionStarted = 6; 	(* device-to-host: session started *)

	(* Application layer packets *)
	AlPidAck = 6;
	AlPidNak = 21;
	AlPidSatelliteData = 114;
	AlPidProtocolArray = 253;
	AlPidProductRequest = 254;
	AlPidProductData = 255;

	GPS18UnitID = 18;

	(* Link Protocol L001 *)
	PidL1CommandData = 10;
	PidL1XferCmplt = 12;
	PidL1DateTimeData = 14;
	PidL1PositionData = 17;
	PidL1PrxWptData = 19;
	PidL1Records = 27;
	PidL1RteHdr = 29;
	PidL1RteWptData = 30;
	PidL1AlamancData = 31;
	PidL1TrkData = 34;
	PidL1WptData = 35;
	PidL1PvtData = 51;
	PidL1RteLinkData = 98;
	PidL1TrkHdr = 99;
	PidL1FlightbookRecord = 134; 		(* packet with Flightbook data *)
	PidL1Lap = 149; 						(* part of Forerunner data *)

	(* Device Command Protocol A10 *)
	CmdA10AbortTransfer = 0; 			(* abort current transfer *)
	CmdA10TransferAlm = 1; 			(* transfer almanac *)
	CmdA10TransferPosn = 2; 			(* transfer position *)
	CmdA10TransferPrx = 3; 				(* transfer proximity waypoints *)
	CmdA10TransferRte = 4; 				(* transfer routes *)
	CmdA10TransferTime =5; 			(* transfer time *)
	CmdA10TransferTrk = 6; 				(* transfer track log *)
	CmdA10TransferWpt = 7; 			(* transfer waypoints *)
	CmdA10TurnOffPwr = 8; 				(* turn off power *)
	CmdA10StartPvtData = 49; 			(* start transmitting PVT data *)
	CmdA10StopPvtData = 50; 			(* stop transmitting PVT data *)
	CmdA10FlightbookTransfer = 92;		(* start transferring flight records *)
	CmdA10TransferLaps = 117; 			(* transfer laps *)

	(* GPS18-specific commands *)
	CmdGps18MeasurementOn = 110;	(* Receiver Measurement Record On *)
	CmdGps18MeasurementOff = 111; 	(* Receiver Measurement Record On *)

	(* Coding of D800PVT.fix field *)
	FixUnusable = 0;
	FixInvalid = 1;
	Fix2D = 2;
	Fix3D = 3;
	Fix2DDiff = 4;
	Fix3DDiff = 5;

	pi = 3.14159265358979323846E0;

TYPE

	ProtocolDataType = RECORD
		tag : CHAR;
		data : LONGINT;
	END;

	SatelliteData = RECORD;
		svid : LONGINT; 		(* space vehicle identification (1-32 and 33-64 for WAAS); (uint8) *)
		snr : LONGINT; 		(* signal-to-noise ratio (uint16) 						*)
		elev : LONGINT; 	(* satellite elevation in degrees (uint8) 				*)
		azmuth : LONGINT; 	(* satellite azmuth in degrees (uint16) 				*)
		(* status bit field:														*)
		(* Bit 1: The unit has ephemeris data for the specified satellite			*)
		(* Bit 2: The unit has a differential correction for the specified satellite		*)
		(* Bit 3: The unit is using this satellite in the solution 						*)
		status : SET;
	END;

	SatelliteInfo = OBJECT
	VAR
		info : ARRAY 12 OF SatelliteData;
		valid : BOOLEAN; (* did we already receive the information ?? *)

		PROCEDURE Parse(data : ARRAY OF CHAR);
		VAR temp, i : LONGINT;
		BEGIN {EXCLUSIVE}
			IF LEN(data) # 84 THEN RETURN; END;
			FOR i := 0 TO 11 DO
				info[i].svid := ORD(data[i*7]);
				info[i].snr := ORD(data[i*7+1]) + 256*ORD(data[i*7+2]);
				info[i].elev := ORD(data[i*7+3]);
				info[i].azmuth := ORD(data[i*7+4]) + 256*ORD(data[i*7+5]);
				temp := ORD(data[i*7+6]); (* QBIC broken SYSTEM.VAL() workaround *)
				info[i].status := SYSTEM.VAL(SET, temp);
			END;
			valid := TRUE;
		END Parse;

		PROCEDURE Show(details : BOOLEAN);
		CONST SnrThreshold = 100;
		VAR nbrOfSatellites, i : LONGINT;
		BEGIN {EXCLUSIVE}
			KernelLog.String("Satellite Data: "); KernelLog.Ln;
			IF valid THEN
				IF details THEN
					FOR i := 0 TO 11 DO
						KernelLog.String("Info Rec "); KernelLog.Int(i, 4);
						KernelLog.String(": Vehicle identification: "); KernelLog.Int(info[i].svid, 5);
						KernelLog.String(" SNR: "); KernelLog.Int(info[i].snr, 5);
						KernelLog.String(" elevation: "); KernelLog.Int(info[i].elev, 5);
						KernelLog.String(" azmuth : "); KernelLog.Int(info[i].azmuth, 5);
						KernelLog.String(" Status: ");
						IF 0 IN info[i].status THEN KernelLog.String("[ephemeris]"); END;
						IF 1 IN info[i].status THEN KernelLog.String("[differential correction]"); END;
						IF 2 IN info[i].status THEN KernelLog.String("[inUse]"); END;
						KernelLog.Ln;
					END;
				ELSE
					nbrOfSatellites := 0;
					FOR i := 0 TO 11 DO IF info[i].snr >= SnrThreshold THEN INC(nbrOfSatellites); END; END;
					KernelLog.String(" Satellites: ");  KernelLog.Int(nbrOfSatellites, 0); KernelLog.Ln;
				END;
			ELSE
				KernelLog.String("Information not yet received."); KernelLog.Ln;
			END;
		END Show;

		PROCEDURE &Init*;
		BEGIN
			valid := FALSE;
		END Init;

	END SatelliteInfo;

TYPE

	RadianType* = RECORD
		lat-, long- : LONGREAL;
	END;

	D800PVT* = RECORD;
		alt- : REAL; 				(* altitude above WGS 84 ellipsoid (meters) *)
		epe- : REAL; 				(* estimated position error, 2 sigma (meters) *)
		eph-, epv- : REAL; 		(* epe, but horizontal rsp. vertical only (meters) *)
		fix- : INTEGER; 			(* type of position fix: 0 = no fix; 1 = no fix; 2 = 2D; 3 = 3D; 4 = 2D differential, 5 = 3D differential *)
		tow- : LONGREAL; 		(* time of week (seconds) *)
		posn- : RadianType;  		(* latitude and longitude (radians) *)
		east-, north-, up- : REAL; 	(* velocity east, north & up (meters per second) *)
		mslHeight- : REAL; 		(* height of WGS 84 ellipsoid above MSL (meters) *)
		leapSeconds- : INTEGER; 	(* difference between GPS and UTC *)
		wnDays- : LONGINT; 		(* week number days *)
	END;

	(* Note: Consider the D800PVT.fix field for information about which fields are valid *)
	PvtInfo = OBJECT
	VAR
		pvtData : D800PVT;
		valid : BOOLEAN;

		PROCEDURE Parse(data : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			IF LEN(data) # 64 THEN RETURN END;
			SYSTEM.GET(ADDRESSOF(data[0]), pvtData.alt);
			SYSTEM.GET(ADDRESSOF(data[4]), pvtData.epe);
			SYSTEM.GET(ADDRESSOF(data[8]), pvtData.eph);
			SYSTEM.GET(ADDRESSOF(data[12]), pvtData.epv);
			SYSTEM.GET(ADDRESSOF(data[16]), pvtData.fix);
			SYSTEM.GET(ADDRESSOF(data[18]), pvtData.tow);
			SYSTEM.GET(ADDRESSOF(data[26]), pvtData.posn.lat);
			SYSTEM.GET(ADDRESSOF(data[34]), pvtData.posn.long);
			SYSTEM.GET(ADDRESSOF(data[42]), pvtData.east);
			SYSTEM.GET(ADDRESSOF(data[46]), pvtData.north);
			SYSTEM.GET(ADDRESSOF(data[50]), pvtData.up);
			SYSTEM.GET(ADDRESSOF(data[54]), pvtData.mslHeight);
			SYSTEM.GET(ADDRESSOF(data[59]), pvtData.leapSeconds);
			SYSTEM.GET(ADDRESSOF(data[60]), pvtData.wnDays);
			valid := TRUE;
		END Parse;

		PROCEDURE GetPVTdata() : D800PVT;
		BEGIN {EXCLUSIVE}
			RETURN pvtData;
		END GetPVTdata;

		PROCEDURE Show(details : BOOLEAN);
		VAR string : ARRAY 32 OF CHAR; temp : REAL;
		BEGIN {EXCLUSIVE}
			KernelLog.String("GPS18: Position Info: "); KernelLog.Ln;
			IF valid THEN
				KernelLog.String("Position: ");
				KernelLog.String("Latitude: ");
				string := ""; Strings.FloatToStr(RadianToDegree(pvtData.posn.lat), 5, 4, 0, string); KernelLog.String(string); KernelLog.String("N degree, ");
				KernelLog.String("Longitude: ");
				string := ""; Strings.FloatToStr(RadianToDegree(pvtData.posn.long), 5, 4, 0, string); KernelLog.String(string); KernelLog.String("E degree");
				KernelLog.Ln;
				KernelLog.String("Altitude: ");
				temp := pvtData.alt + pvtData.mslHeight;
				string := ""; Strings.FloatToStr(temp, 5, 2, 0, string); KernelLog.String(string); KernelLog.String("m (MSL)");
				KernelLog.String(", alt: "); string := ""; Strings.FloatToStr(pvtData.alt, 5, 2, 0, string); KernelLog.String(string); KernelLog.String("m, ");
				KernelLog.String(", msl: "); string := ""; Strings.FloatToStr(pvtData.mslHeight, 5, 2, 0, string); KernelLog.String(string); KernelLog.String("m, ");
				KernelLog.Ln;
				KernelLog.String("Estimated Position Error: ");
				string := ""; Strings.FloatToStr(pvtData.epe, 5, 2, 0, string); KernelLog.String(string); KernelLog.String("m (");
				KernelLog.String("Horizontal: "); string := ""; Strings.FloatToStr(pvtData.eph, 5, 2, 0, string); KernelLog.String(string); KernelLog.String("m, ");
				KernelLog.String("Vertical: "); string := ""; Strings.FloatToStr(pvtData.epv, 5, 2, 0, string); KernelLog.String(string); KernelLog.String("m)");
				KernelLog.Ln;
				KernelLog.String("Velocity: ");
				KernelLog.String("E: "); string := ""; Strings.FloatToStr(pvtData.east, 5, 2, 0, string); KernelLog.String(string); KernelLog.String("m/s, ");
				KernelLog.String("N: ");  string := ""; Strings.FloatToStr(pvtData.north, 5, 2, 0, string); KernelLog.String(string); KernelLog.String("m/s, ");
				KernelLog.String("Up: ");  string := ""; Strings.FloatToStr(pvtData.up, 5, 2, 0, string); KernelLog.String(string); KernelLog.String("m/s, ");
				KernelLog.Ln;
				KernelLog.String("Fix: "); ShowFix(pvtData.fix); KernelLog.Ln;
				KernelLog.String("WeekNbrDays: "); KernelLog.Int(pvtData.wnDays, 0); KernelLog.Ln;
			ELSE
				KernelLog.String("No position info available");
			END;
			KernelLog.Ln;
		END Show;

		PROCEDURE ShowFix(fix : LONGINT);
		BEGIN
			CASE fix OF
				FixUnusable: KernelLog.String("unusable");
				|FixInvalid:  KernelLog.String("invalid");
				|Fix2D: KernelLog.String("2D");
				|Fix3D: KernelLog.String("3D");
				|Fix2DDiff: KernelLog.String("2D differential");
				|Fix3DDiff: KernelLog.String("3D differential");
			ELSE
				KernelLog.String("unknown("); KernelLog.Int(fix, 0); KernelLog.String(")");
			END;
		END ShowFix;

		PROCEDURE &Init*;
		BEGIN
			valid := FALSE;
		END Init;

	END PvtInfo;

TYPE

	GarminGPS18= OBJECT (Usbdi.Driver)
	VAR
		satelliteInfo : SatelliteInfo;
		pvt : PvtInfo;
		interruptIn, bulkIn, bulkOut : Usbdi.Pipe;
		interruptInBuffer : Usbdi.BufferPtr;
		started, received : BOOLEAN;
		epMaxSize : LONGINT;
		byteCounter : LONGINT;	(* how many bytes have been received *)

		(* information about the GPS device and its capabilities *)
		unitID : LONGINT;
		productString : Strings.String;
		productId, softwareVersion : LONGINT;
		protocolDataType : POINTER TO ARRAY OF ProtocolDataType;

		(* packets *)
		startSession, productDataRequest : Usbdi.BufferPtr;

		(* used by Handleevent *)
		data : POINTER TO ARRAY OF CHAR;
		fragLen, fragOfs, fragType, fragId : LONGINT;

		(** Start gathering PVT data *)
		PROCEDURE StartPvtData*() : BOOLEAN;
		VAR command : Usbdi.BufferPtr;
		BEGIN
			NEW(command, 2); command[0] := CHR(CmdA10StartPvtData); command[1] := CHR(0);
			RETURN SendPacket(BuildPacket(PacketApplication, PidL1CommandData, command));
		END StartPvtData;

		(** Stop gathering PVT data *)
		PROCEDURE StopPvtData*() : BOOLEAN;
		VAR command : Usbdi.BufferPtr;
		BEGIN
			NEW(command, 2); command[0] := CHR(CmdA10StopPvtData); command[1] := CHR(0);
			RETURN SendPacket(BuildPacket(PacketApplication, PidL1CommandData, command));
		END StopPvtData;

		(** Get most recent PVT data. Consider the field fix for validity of data *)
		PROCEDURE GetPvtData*() : D800PVT;
		BEGIN
			RETURN pvt.GetPVTdata();
		END GetPvtData;

		PROCEDURE HandlePacket(type, id : LONGINT; data : ARRAY OF CHAR);
		VAR i : LONGINT;
		BEGIN
			IF Trace * TracePackets # {} THEN KernelLog.String("GPS18: packet received: "); ShowPacket(type, id); KernelLog.Ln; END;
			IF  type = PacketTransport THEN

				IF id =TlPidSessionStarted THEN
						IF LEN(data) = 4 THEN
							unitID := Get4(data, 0);
							IF Trace * TraceDeviceInfo # {} THEN KernelLog.String("GPS18: Unit ID received: "); KernelLog.Hex(unitID, 0); KernelLog.Ln; END;
						END;
						started := TRUE;
				ELSIF id = TlPidDataAvailable THEN
				END;

			ELSIF type = PacketApplication THEN

				IF id = AlPidProductData THEN
					ASSERT(LEN(data) > 4);
					NEW(productString, LEN(data)-4);
					productId := ORD(data[0]) + 256*ORD(data[1]);
					softwareVersion := ORD(data[2]) + 256*ORD(data[3]);
					FOR i :=4 TO LEN(data)-1 DO
						productString[i-4] := data[i];
					END;
					IF Trace * TraceDeviceInfo # {} THEN
						KernelLog.String("GPS18: Product ID: "); KernelLog.Int(productId, 0);
						KernelLog.String(" Software Version: "); KernelLog.Int(softwareVersion, 0);
						KernelLog.String(" Product description: "); KernelLog.String(productString^);
						KernelLog.Ln;
					END;

				ELSIF id = AlPidProtocolArray THEN
					ASSERT(LEN(data)  MOD  3 = 0);
					NEW(protocolDataType, LEN(data) DIV 3);
					IF Trace * TraceDeviceInfo # {} THEN KernelLog.String("GPS18: Supported protocols: "); END;
					FOR i := 0 TO (LEN(data) DIV 3) -1 DO
						protocolDataType[i].tag := data[i*3];
						protocolDataType[i].data := ORD(data[i*3+1]) + 256*ORD(data[i*3+2]);
						IF Trace * TraceDeviceInfo # {} THEN KernelLog.Char(protocolDataType[i].tag); KernelLog.Int(protocolDataType[i].data, 0); KernelLog.Char(" "); END;
					END;
					IF Trace  * TraceDeviceInfo # {}THEN KernelLog.Ln; END;
					received := TRUE;

				ELSIF id = AlPidSatelliteData THEN
					satelliteInfo.Parse(data);
					IF Trace * TraceSatelliteInfo # {} THEN satelliteInfo.Show(TRUE); END;

				ELSIF id = PidL1PvtData THEN
					pvt.Parse(data);
					IF Trace * TracePVTData # {} THEN pvt.Show(FALSE); END;
				END;

			ELSE
				IF Debug THEN KernelLog.String("GPS 18: Unknown packet type. Discarding packet."); KernelLog.Ln; END;
			END;
		END HandlePacket;

		(* re-assembles fragmented packets and sends them to HandlePacket *)
		PROCEDURE HandleEvent(status : Usbdi.Status; actLen : LONGINT);
		VAR
			packetType, packetId : LONGINT;
			dataLen, len, i : LONGINT;
			error : BOOLEAN;
		BEGIN
			error := FALSE;
			IF actLen > 0 THEN byteCounter := byteCounter + actLen; END;
			IF (status = Usbdi.Ok) OR (status = Usbdi.ShortPacket) THEN
				IF fragLen > 0 THEN (* we exspect a fragment of the lenght fragLen *)
					IF Trace * TraceEvents # {} THEN
						KernelLog.String("GPS18: Handle fragment: "); ShowPacket(fragType, fragId);
						KernelLog.String(" fragLen: "); KernelLog.Int(fragLen, 0); KernelLog.String(" fragOfs: "); KernelLog.Int(fragOfs, 0);
						KernelLog.String(" actLen: "); KernelLog.Int(actLen, 0); KernelLog.Ln;
					END;
					IF fragLen > epMaxSize THEN len := epMaxSize; ELSE len := fragLen; END;
					ASSERT(len <= actLen);

					FOR i := 0 TO len -1 DO data[fragOfs + i] := interruptInBuffer[i]; END;

					IF fragLen > epMaxSize THEN
						ASSERT(actLen = epMaxSize);
						fragLen := fragLen - epMaxSize;
						fragOfs := fragOfs + epMaxSize;
					ELSE
						fragLen := 0; fragOfs := 0;
						HandlePacket(fragType, fragId, data^);
					END;

				ELSIF actLen >= 11 THEN (* beginning of new packet *)
					ASSERT((interruptInBuffer[1]=CHR(0)) & (interruptInBuffer[2]=CHR(0)) & (interruptInBuffer[3]=CHR(0)));
					packetType := ORD(interruptInBuffer[0]);
					packetId := ORD(interruptInBuffer[4]) + 256*ORD(interruptInBuffer[5]);
					ASSERT((interruptInBuffer[6]=CHR(0)) & (interruptInBuffer[7]=CHR(0)));
					dataLen := Get4(interruptInBuffer^, 8);
					IF Trace * TraceEvents # {} THEN
						KernelLog.String("GPS18: Handle packet: "); ShowPacket(packetType, packetId);
						KernelLog.String(" dataLen: "); KernelLog.Int(Get4(interruptInBuffer^,8) ,0); KernelLog.String(" actLen: "); KernelLog.Int(actLen, 0);
						IF Trace * TraceData # {} THEN KernelLog.String(" Data: "); FOR i := 12 TO actLen-1 DO KernelLog.Char(interruptInBuffer[i]); END; END;
						KernelLog.Ln;
					END;
					NEW(data, dataLen);
					IF dataLen + 12 > epMaxSize THEN (* packet fragmented *)
						fragLen := dataLen + 12 - epMaxSize; fragOfs := epMaxSize - 12;
						fragType := packetType; fragId := packetId;
					ELSE
						fragLen := 0; fragOfs := 0;
					END;

					FOR i := 0 TO actLen - 12-1 DO
						data[i] := interruptInBuffer[12 + i];
					END;

					IF fragLen = 0 THEN HandlePacket(packetType, packetId, data^); END;

				ELSE (* probably the device has been disconneted *)
					IF Debug THEN KernelLog.String("GPS18: Serious error encountered..."); KernelLog.Ln; END;
					error := TRUE;
				END;

				IF ~error THEN status := interruptIn.Transfer(epMaxSize, 0, interruptInBuffer^); (* ignore res *) ELSE device.FreePipe(interruptIn); END;

			ELSE
				IF Debug THEN interruptIn.Show(TRUE); KernelLog.Ln; END;
				IF status = Usbdi.Stalled THEN
					IF interruptIn.ClearHalt() THEN
						IF Debug THEN KernelLog.String("GPS18: Stall on Interrupt Pipe cleared."); KernelLog.Ln; END;
						status := interruptIn.Transfer(epMaxSize, 0, interruptInBuffer^); (* ignore res *)
					ELSE
						IF Debug THEN KernelLog.String("GPS18: Couldn't clear stall on interrupt pipe. Abort."); KernelLog.Ln; END;
						device.FreePipe(interruptIn);
					END;
				END;
			END;
		END HandleEvent;

		PROCEDURE SendPacket(packet : Usbdi.BufferPtr) : BOOLEAN;
		VAR status : Usbdi.Status;
		BEGIN {EXCLUSIVE}
			ASSERT(LEN(packet) >= 12);
			status := bulkOut.Transfer(LEN(packet), 0, packet^);
			RETURN status = Usbdi.Ok;
		END SendPacket;

		PROCEDURE BuildPacket(type, id : LONGINT; data : Usbdi.BufferPtr) : Usbdi.BufferPtr;
		VAR packet : Usbdi.BufferPtr; i : LONGINT;
		BEGIN
			IF data=NIL THEN
				NEW(packet, 12);
			ELSE
				NEW(packet, 12 + LEN(data));
				FOR i := 0 TO LEN(data)-1 DO packet[i + 12] := data[i]; END;
			END;
			FOR i := 0 TO 11 DO packet[i] := CHR(0); END;
			IF data # NIL THEN Put4(packet, 8, LEN(data)); END;
			packet[0] := CHR(type);
			packet[4] := CHR(id);
			RETURN packet;
		END BuildPacket;

		PROCEDURE Connect() : BOOLEAN;
		CONST
			MaxWaits = 5000; (* maximum time we wait for the TlSessionStarted packet [ms] *)
		VAR
			epInterruptIn, epBulkOut, epBulkIn, epFound : LONGINT;
			status : Usbdi.Status;
			timer : Kernel.Timer;
			waits : LONGINT;
			i : LONGINT;
		BEGIN
			(* Exspected endpoints: 1 InterruptIn, 1 BulkIn, 1 Bulkout*)
			LOOP
				IF ((i >= LEN(interface.endpoints)) OR (epFound = 3)) THEN EXIT; END;
				IF interface.endpoints[i].type = Usbdi.InterruptIn THEN
					epInterruptIn := interface.endpoints[i].bEndpointAddress; epMaxSize := interface.endpoints[i].wMaxPacketSize;
					INC(epFound);
				ELSIF interface.endpoints[i].type = Usbdi.BulkIn THEN
					epBulkIn := interface.endpoints[i].bEndpointAddress;
					INC(epFound);
				ELSIF  interface.endpoints[i].type = Usbdi.BulkOut THEN
					epBulkOut := interface.endpoints[i].bEndpointAddress;
					INC(epFound);
				END;
				INC(i);
			END;

			IF ~((epFound = 3) & (epInterruptIn # 0) & (epBulkIn # 0) & (epBulkOut # 0)) THEN
				IF Debug THEN KernelLog.String("GPS18: Error: Exspected endpoints not found."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			interruptIn := device.GetPipe(epInterruptIn);
			IF interruptIn = NIL THEN
				IF Debug THEN KernelLog.String("GPS18: Error: Couldn't get interrupt in pipe."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			bulkIn := device.GetPipe(epBulkIn); bulkOut := device.GetPipe(epBulkOut);
			IF (bulkIn = NIL) OR (bulkOut = NIL) THEN
				IF Debug THEN KernelLog.String("GPS18: Error: Couldn't get bulk in/out pipes."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			NEW(interruptInBuffer, interruptIn.maxPacketSize);
			interruptIn.SetTimeout(0); (* non-blocking *)
			interruptIn.SetCompletionHandler(HandleEvent);
			status := interruptIn.Transfer(interruptIn.maxPacketSize, 0, interruptInBuffer^); (* ignore res *)

		(*	NEW(buffer, 64);
			bulkIn.SetTimeout(0);
			bulkIn.SetInterruptHandler(HandleEvent);
			status := bulkIn.Send(64, 0, buffer);*)

			(* start session *)
			started := FALSE;
			IF ~SendPacket(BuildPacket(PacketTransport, TlPidStartSession, NIL)) THEN
				IF Debug THEN KernelLog.String("GPS18: Couldn't start session"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* the start session packet should be acknowlegde by a SessionStarted packet... wait for it *)
			NEW(timer); waits := 0;
			LOOP
				IF started OR (waits >= MaxWaits) THEN EXIT; END;
				timer.Sleep(1);
			END;

			IF ~started THEN
				IF Debug THEN KernelLog.String("GPS18: Timeout: SesssionStarted packet not received"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* A001 Protocol capability protocol - get supported protocols *)
			IF ~SendPacket(BuildPacket(PacketApplication, AlPidProductRequest, NIL)) THEN
				IF Debug THEN KernelLog.String("GPS18: Couldn't get product data"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			received := FALSE; waits := 0;
			LOOP
				IF received OR (waits >= MaxWaits) THEN EXIT; END;
				timer.Sleep(1);
			END;

			IF ~received THEN
				IF Debug THEN KernelLog.String("GPS18: Timeout: Product Data packet not received"); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			IF StartPvtData() THEN
				KernelLog.String("GPS18: PVT data started"); KernelLog.Ln;
			ELSE
				KernelLog.String("GPS18: PVT start command failed."); KernelLog.Ln;
			END;

			KernelLog.String("Garmin GPS18 connected."); KernelLog.Ln;
			RETURN TRUE;
		END Connect;

		PROCEDURE Disconnect;
		BEGIN
			KernelLog.String("Garmin GPS 18 USB disconnected."); KernelLog.Ln;
			KernelLog.String("GPS18: Received bytes: "); KernelLog.Int(byteCounter, 0); KernelLog.Ln;
		END Disconnect;

		PROCEDURE &Init*;
		BEGIN
			fragLen := 0; NEW(satelliteInfo); NEW(pvt);
			byteCounter := 0;
		END Init;

	END GarminGPS18;

PROCEDURE RadianToDegree(radian : LONGREAL) : LONGREAL;
BEGIN
	RETURN radian * (180 / pi);
END RadianToDegree;

PROCEDURE Get4(CONST buf : ARRAY OF CHAR; ofs : LONGINT): LONGINT;
BEGIN
	ASSERT(ofs + 3 < LEN(buf));
	RETURN ORD(buf[ofs]) + LSH(ORD(buf[ofs+1]), 8) + LSH(ORD(buf[ofs+2]), 16) + LSH(ORD(buf[ofs+3]), 24);
END Get4;

PROCEDURE Put4(buf : Usbdi.BufferPtr; ofs, value : LONGINT);
BEGIN
	ASSERT(ofs + 3 < LEN(buf));
	buf[ofs] := CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, value) * {0..7}));
	buf[ofs+1] := CHR(SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, value) * {8..15}, -8)));
	buf[ofs+2] := CHR(SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, value) * {16..23}, -16)));
	buf[ofs+3] := CHR(SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, value) * {24..31}, -24)));
END Put4;

PROCEDURE ShowPacket(type, id : LONGINT);
BEGIN
	KernelLog.String("Type: ");
	IF type = PacketTransport THEN KernelLog.String("Transport");
	ELSIF type = PacketApplication THEN KernelLog.String("Application");
	ELSE KernelLog.String("Unknown("); KernelLog.Int(type, 0); KernelLog.String(")");
	END;
	KernelLog.String(" id: ");
	CASE id OF
		TlPidDataAvailable: KernelLog.String("Data Available");
		|TlPidStartSession: KernelLog.String("Start Session");
		|AlPidAck:  IF type = PacketTransport THEN KernelLog.String("Session Started"); ELSE KernelLog.String("Ack"); END;
		|AlPidNak: KernelLog.String("Nak");
		|AlPidProtocolArray: KernelLog.String("Protocol array");
		|AlPidProductRequest: KernelLog.String("Product request");
		|AlPidProductData: KernelLog.String("Product Data");
		|AlPidSatelliteData : KernelLog.String("Satellite Data Record");
	ELSE
		KernelLog.String("Unkown("); KernelLog.Int(id, 0); KernelLog.String(")");
	END;
END ShowPacket;

PROCEDURE Probe(dev : Usbdi.UsbDevice; id : Usbdi.InterfaceDescriptor) : Usbdi.Driver;
VAR driver : GarminGPS18;
BEGIN
	(* check whether the probed device is a Garmin GPS 18 USB*)
	IF (dev.descriptor.idVendor # 91EH) OR (dev.descriptor.idProduct # 03H) THEN RETURN NIL; END;
	IF Trace * TraceDeviceInfo # {}  THEN KernelLog.String("Garmin GPS 18 USB found."); KernelLog.Ln; END;
	NEW(driver);
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
	Usbdi.drivers.Add(Probe, Name, Description, 9)
END UsbGarminGPS18.

UsbGarminGPS18.Install ~  SystemTools.Free UsbGarminGPS18 ~