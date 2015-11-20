MODULE UsbEhci; (** AUTHOR "staubesv"; PURPOSE "USB Enhanced Host Controller Driver"; *)
(**
 * Bluebottle USB Enhanced Host Controller Driver
 * Implements the UsbHcdi host controller driver interface (HCDI)
 *
 * Usage:
 *
 * This module provides the core implementation of the EHCI driver. Finding EHCI controllers was moved to a separate
 * module to increase flexibility. If your EHCI controller is accessible with PCI, the command:
 * 		UsbEhciPCI.Install ~
 * will install EHCI drivers as needed. To remove them, simply uninstall Ehci modules:
 * 		SystemTools.Free UsbEhciPCI UsbEhci ~
 *
 * In other cases, specific modules can be written, that will instanciate drivers as needed.
 *
 * References:
 *	Enhanced Host Controller Interface Specification for Universal Serial Bus, Rev. 1.0
 *
 * Notes:
 * - 64bit control data structures: This driver doesn`t support real 64bit operation. If the host controller indicates 64bit capabilities, i.e. all
 *   pointers used for control data structures as qTd, QHs and buffers are 64bit memory addresses, the upper 32bit of the address are just set to zero
 *   to selected the 0..4GB segment.
 *
 * TODOs:
 * - FSTN save path pointers
 * - use sparse tree for more fine granular scheduling
 * - implement isochronous transfers
 *	- DataToggle would not work for Control Transfers spanning multiple TDs
 *
 * History:
 *
 *	24.11.2005	First release (staubesv)
 * 	15.12.2005	Moved buffer checks to UsbHcdi.Mod (staubesv)
 *	05.01.2006	Fixed EnhancedHostController.DeleteTranfer (staubesv)
 *	10.01.2006	H/W scatter/gather support implemented, fixed bug when sending > 16KB blocks (staubesv)
 *	16.01.2006	FlushPCI added (staubesv)
 *	08.01.2006	Added ScheduleOn, more safe TD unlinked/QH removal (staubesv)
 *	01.03.2006	Fixed critical bug in CreateTDList (staubesv)
 *	02.03.2006 	Implemented port indicator control (staubesv)
 *	03.04.2006	Improved interrupt sharing (staubesv)
 *	05.04.2006	Fixed BIOS-to-OS handoff (staubesv)
 *	28.06.2006	Use KernelLog.Hex instead of UsbHcdi.PrintHex (staubesv)
 *	30.06.2006	Bugfix in InitFramelist: Also reset QH structure for isochronousQH, fixed bug when removing periodic QHs (staubesv)
 *	03.06.2006	UpdatePipe removed (staubesv)
 *	04.06.2006 	Allow LinkTD to automatically clear halt condition (staubesv)
 *	20.07.2006	Release HC ownership when HC driver is shutdown, introduced OverrideHcOwnership constant (staubesv)
 *	03.08.2006	Adapted to UsbHcdi, fixed control transfer > 1TD (staubesv)
 *	13.11.2006	UpdatePipeStatus: Set pipe.status to Usbdi.Stalled when a stall is detected (staubesv)
 *)

IMPORT SYSTEM, KernelLog, Machine, Kernel, Objects, Modules, UsbHcdi, Usbdi, Debug := UsbDebug;

CONST

	Description * = "USB Enhanced Host Controller";

	(* Some configuration stuff *)
	HcInterruptThreshold = 01H; (* Maximum rate at which the host controller will issue interrupts (in microframes, 125 microseconds) *)
	HcFrameListSize = 1024;

	ScatterGatherListSize = 4200; (* Number of entries in scatter/gather list -> limits the maximum transfer size *)

	(* How many transaction of a single queue head in the asynchronous schedule list is the host controller allowed to execute
	within a micro-frame? Valid values: [0..3] (0 disables the feature).  Will only be set if the HC supports the Asynchronous Schedule Park Mode. Higher values
	should result in higher performance. *)
	HcAsyncParkModeCount = 3;

	(* Host Controller Capability Registers *)
	HcCapLength = 00H;
	HcCapHciVersion = 02H;
	HcCapSparams = 04H;
	HcCapCparams * = 08H;
	HcCapPortroute = 0CH;

	(* Host Controller Operational Registers *)
	HcUsbCmd * = 00H;
	HcUsbSts * = 04H;
	HcUsbIntr * = 08H;
	HcFrIndex * = 0CH;
	HcCtrlDsSegment * = 10H;
	HcPeriodicListBase * = 14H;
	HcAsyncListAddr * = 18H;
	HcConfigFlag * = 40H;
	HcPortSc * = 44H;

	(* HcUsbCmd register fields *)
	CmdInterruptThreshold * = {16..23};
	CmdAsyncSchedParkMode * = {11};
	CmdAsyncSchedParkCount * = {8..9};
	CmdLightHcReset * = {7}; (* Note: optional *)
	CmdAsyncAdvDoorbell * = {6};
	CmdAsyncSchedEnable * = {5};
	CmdPeriodicSchedEnable * = {4};
	CmdFrameListSize * = {2 .. 3};
	CmdHcReset * = {1};
	CmdRunStop * = {0};
	CmdReserved * = {10} + {12..15} + {24..31};

	(* HcUsbSts register fields *)
	StsAsyncSchedule * = {15};
	StsPeriodicSchedule * = {14};
	StsReclamation * = {13};
	StsHcHalted * = {12};
	(* HcUsbSts & HcUsbIntr common fields *)
 	StsAsyncAdvance * = {5};
	StsHostSystemError * = {4};
	StsFrameListRollover * = {3};
	StsPortChange * = {2};
	StsUsbError * = {1};
	StsUsbInterrupt * = {0};

	(* Port Status & Control register, EHCIspec p. 26-30 *)
	PscWakeOnOvercurrent = {22};
	PscWakeOnDisconnect = {21};
	PscWakeOnConnect = {20};
	PscTestControl = {16..19};
	PscIndicatorControl = {14..15};
	PscPortOwner = {13};
	PscPortPower * = {12};
	PscLineStatus = {10..11};
	PscPortReset = {8};
	PscSuspend = {7};
	PscForcePortResume = {6};
	PscOvercurrentChange = {5};
	PscOvercurrentActive = {4};
	PscPortEnableChange = {3};
	PscPortEnable = {2};
	PscConnectStatusChange = {1};
	PscCurrentConnectStatus = {0};
	PscReserved = {9} + {23..31};
	PscChangeMask = {1, 3, 5};

	(* Queue Element Transfer Descriptor; must be 32byte aligned *)
	(* Offsets *)
	QtdNextQtdPointer = 00H;
	QtdAltNextQtdPointer = 04H;
	QtdToken = 08H;
	QtdBufferPtr0 = 0CH;
	QtdBufferPtr1 = 10H;
	QtdBufferPtr2 = 14H;
	QtdBufferPtr3 = 18H;
	QtdBufferPtr4 = 1CH;
	QtdExtBufferPtr0 = 20H;
	QtdExtBufferPtr1 = 24H;
	QtdExtBufferPtr2 = 28H;
	QtdExtBufferPtr3 = 2CH;
	QtdExtBufferPtr4 = 30H;
	(* Masks *)
	QtdTerminate = {0};
	QtdBufferPtr = {12..31};

	(* qTD Token *)
	QtdDataToggle = {31};
	QtdBytesToTransfer = {16..30};
	QtdIoc = {15}; (* Interrupt on complete *)
	QtdCurrentPage = {12..14};
	QtdErrorCounter = {10..11};
	QtdPidCode = {8..9};
	QtdStatus = {0..7};

	(* Isochronous Transfer Descriptor *)
	ItdNextLinkPointer = 00H;
	ItdTransaction0 = 04H;
	ItdBufferPtr0 = 024H;
	ItdBufferPtr1 = 028H;
	ItdBufferPtr2 = 02CH;
	ItdExtBufferPtr0 = 40H;

	(* ITD Transaction *)
	ItdTransactionStatus = {28..31};
	ItdTransactionLength = {16..27};
	ItdTransactionIoc = {15};
	ItdTransactionPg = {12..14};
	ItdTransactionOffset = {0..11};

	(* ITD Buffer Pointers *)
	ItdBufferPtr = {12..31};
	(* ItdBufferPtr0 *)
	ItdEndPt = {8..11};
	ItdReserved = {7};
	ItdDevAdr = {0..6};
	(* ItdBufferPtr1 *)
	ItdIn = {11};
	ItdMaxPacketSize = {0..10};
	(* ItdBufferPtr2 *)
	ItdMult = {0..1};

	(* ITD Transaction Status *)
	ItdStatus = {28..31};
	ItdActive = {31};
	ItdDataBufferError = {30};
	ItdBabbleDetected = {29};
	ItdTransactionError = {28};

	(* Queue Head *)
	(* Offsets *)
	QhHorizontalLinkPointer = 00H;
	QhEpCapabilities1 = 04H;
	QhEpCapabilities2 = 08H;
	QhCurrentQtdPointer = 0CH;
	QhNextQtdPointer = 10H;
	QhAltNextQtdPointer = 14H;
	QhQtdToken = 18H;
	QhBufferPointer0 = 1CH;
	QhBufferPointer1 = 20H;
	QhBufferPointer2 = 24H;
	QhBufferPointer3 = 28H;
	QhBufferPointer4 = 2CH;
	QhExtBufferPointer0 = 30H;
	QhExtBufferPointer1 = 34H;
	QhExtBufferPointer2 = 38H;
	QhExtBufferPointer3 = 3CH;
	QhExtBufferPointer4 = 40H;

	(* Masks *)
	(* Queue Head Horizontal Link Pointer *)
	QhTyp = {1..2};
	QhTypItd = 0;
	QhTypQh = 1;
	QhTypSitd = 2;
	QhTypFstn = 3; (* Frame span traversal node *)
	QhTerminate = {0};

	(* Queue Head Endpoint Capabilities *)
	(* Dword 1 *)
	QhNakCountReload = {28..31};
	QhControlEndpointFlag = {27};
	QhMaxPacketLen = {16..26};
	QhHeadOfReclamation = {15};
	QhDataToggleControl = {14};
	QhEndpointSpeed = {12..13};
	QhEndpointNbr = {8..11};
	QhInactivate = {7};
	QhDeviceAddress = {0..6};
	(* Dword 2 *)
	QhMultiplier = {30..31}; (* High-Bandwidth Pipe Muliplier *)
	QhPortNbr = {23..29};
	QhHubAddr = {16..22};
	QhSplitCMask = {8..15};
	QhSMask = {0..7};

	(* Periodic Frame Span Traversal Node (FSTN) *)
	(* FSTN offsets *)
	FstnNormalPathLinkPointer = 0;
	FstnBackPathLinkPointer = 4;

	(* Status fields of qTD Token *)
	TdActive = {7}; (* If set, the HC will process the qTD *)
	TdHalted = {6}; (* Caused by babble, error counter transition from one to zero or STALL handshake. Will also clear TdActive. *)
	TdDataBufferError = {5}; (* Buffer overrun or underrun *)
	TdBabbleDetected = {4}; (* Babble. Will also set TdHalted *)
	TdTransactionError = {3}; (* No valid response from device during status update (Timeout, CRC errir, PID wrong...) *)
	TdMissedMicroFrame = {2};
	TdSplitTransactionState = {1};
	TdPingState = {0};

	(* Periodic Frame Span Traversal Node *)
	FstnNormalPathLink = 00H;
	FstnBackPathLink = 04H;

	(* Packet Identifier codes *)
	PidOut = 0;
	PidIn = 1;
	PidSetup = 2;

	PageSize = 4096;

	Polling = FALSE;

TYPE

	EnhancedHostController * = OBJECT (UsbHcdi.Hcd)
	VAR
		framelist *: UsbHcdi.AlignedMemSpace;

		pwcr * : LONGINT; (* Port Wake Capability Register; Not implemented by device if pwcr = 0 *)

		(* Information from Host Controller Capability Registers *)
		(* HCSPARAMS - Structural Parameters *)
		capDebugPortNumber : LONGINT; 	(* 0: n/a, other: number of debug port (0-15)*)
		capPortIndicators : BOOLEAN; 		(* Do the ports support port indicator control? *)
		capNbrOfCompanionHc : LONGINT; 	(* How many companion host controllers are present (0-15) *)
		capPortsPerCompanion : LONGINT; 	(* Number of ports supported per companion host controller *)
		capPortRoutingRules : BOOLEAN; 	(* Port routing rules *)
		capPortPowerControl : BOOLEAN; 	(* Does the HC support Port Power Control? *)
		capNbrOfPorts : LONGINT; 			(* Number of physical downstream ports implemented by this host controller *)
		(* HCCPARAMS - Capability Parameters *)
		capIsoSchedThreshold : LONGINT; 	(* Isochronous Schedule Threshold *)
		capAsynchSchedPark : BOOLEAN; 	(* Does the controller support the park feature for high-speed transfers? *)
		capProgrammableFLG : BOOLEAN; 	(* FALSE: use default (1024); TRUE: Frame List size is programmable *)
		cap64bit : BOOLEAN; 				(* 32 / 64 bit memory pointers in the data structures *)

		(* EHCI Extended Capabilities Pointer. Used in relation with USB legacy support *)
		eecp : LONGINT;

		(* The size of control data structures is dependent on whether the HC uses 32bit or 64bit address pointers as indicated
		by the cap64bit field *)
		sizeQtd, alignQtd : LONGINT;
		sizeQh, alignQh : LONGINT;

		(* HC Companion Port Route Descriptor, NIL of not available.
		If the capPortRoutingRules is TRUE, the HC provides a description of which port is routed to
		which companion HC.  *)
		hcportroute : POINTER TO ARRAY OF LONGINT;

		(* queue heads *)
		isochronousQh* : LONGINT;
		interruptQh : POINTER TO ARRAY 11 OF LONGINT;

		(* this array will provide the 16byte aligned TD's for controlTD, bulkTD, isochronousTD and interruptTD[] *)
		qhlist : UsbHcdi.AlignedMemSpace;

		(* The Asynchronous Advance Doorbell interrupt is always enabled by this driver. Since the interrupt handler will
		clear the bit that were set when it was invoked, it sets hcHandshake to TRUE, so its sticky *)
		hcHandshake * : BOOLEAN;

		(* Set of all currently enabled interrupts *)
		interruptsEnabled * : SET;

		(** Enable power for the specified port *)
		PROCEDURE EnablePortPower*(port : LONGINT);
		VAR status : SET;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], status - PscChangeMask + PscPortPower); FlushPCI;
		END EnablePortPower;

		(** Disable power for the specified port *)
		PROCEDURE DisablePortPower*(port : LONGINT);
		VAR status : SET;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], status - PscChangeMask - PscPortPower); FlushPCI;
		END DisablePortPower;

		(** Enable the specified port.
		 	The EHCI host controllers do not explicitly support a port enable command. The port will be automatically enabled
		 	by the host controller after a port reset, if a high-speed capable device is attached to it *)
		PROCEDURE ResetAndEnablePort*(port : LONGINT) : BOOLEAN;
		VAR status : SET; mtimer : Kernel.MilliTimer;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], status - PscChangeMask + PscPortReset - PscPortEnable); FlushPCI;
			Wait(UsbHcdi.PortResetTime); (* >= 10ms, USBspec *)
			SYSTEM.PUT32(ports[port], status - PscChangeMask - PscPortReset); FlushPCI;
			Wait(2+1); (* 2ms recovery interval according EHCIspec, p. 28 *)
			(* The host controller should have automatically enabled this port *)
			Kernel.SetTimer(mtimer, UsbHcdi.PortEnableTimeout);
			REPEAT
				status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			UNTIL (status * PscPortEnable # {}) OR Kernel.Expired(mtimer);
			RETURN status * PscPortEnable # {};
		END ResetAndEnablePort;

		(** Disable the specified port. *)
		PROCEDURE DisablePort*(port : LONGINT);
		VAR status : SET;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], status - PscChangeMask- PscPortEnable);
			FlushPCI;
		END DisablePort;

		(** Suspend the specified port (selective suspend). *)
		PROCEDURE SuspendPort*(port : LONGINT) : BOOLEAN;
		VAR status : SET;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			IF (status * PscPortEnable # {}) & (status * PscPortOwner = {}) THEN
				SYSTEM.PUT32(ports[port], status - PscChangeMask + PscSuspend);
				FlushPCI;
				RETURN TRUE;
			END;
			RETURN FALSE;
		END SuspendPort;

		(** Resume a selectively suspended port. *)
		PROCEDURE ResumePort*(port : LONGINT) : BOOLEAN;
		VAR status : SET; timer : Kernel.Timer;
		BEGIN
			status := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			IF status * CmdRunStop = {} THEN
				(* HC must be running when resume a port. Otherwise, the device would automatically re-renter
				the suspended mode in 10 ms *)
				SYSTEM.PUT32(iobase + HcUsbCmd, status + CmdRunStop);
				FlushPCI;
			END;
			status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			IF (status * PscSuspend # {}) & (status * PscPortOwner = {}) THEN
				SYSTEM.PUT32(ports[port], status - PscChangeMask + PscForcePortResume);
				FlushPCI;
				NEW(timer); timer.Sleep(20); (* EHCI p. 60 *)
				SYSTEM.PUT32(ports[port], status - PscChangeMask - PscForcePortResume);
				FlushPCI;
			END;
			RETURN SYSTEM.VAL(SET, SYSTEM.GET32(ports[port])) * PscSuspend = {};
			(* TODO: write 1 to PORTSC Force resume bit if port is suspended; first wait 10ms (EHCIp59)*)
		END ResumePort;

		(** Suspend all ports and then stop the host controller. *)
		PROCEDURE Suspend*;
		VAR dword : SET; i : LONGINT; ignore : BOOLEAN;
		BEGIN
			(* Suspend all individual ports *)
			FOR i := 0 TO portCount - 1 DO ignore := SuspendPort(i); END;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd)); (* Stop HC *)
			SYSTEM.PUT32(iobase + HcUsbCmd, dword - CmdRunStop);
			FlushPCI;
			(* Put HC in lower device state via the PCI power management interface *)
		END Suspend;

		(** Restart the host controller and selectively resume all suspended ports.  *)
		PROCEDURE Resume*() : BOOLEAN;
		VAR dword : SET; i : LONGINT; res : BOOLEAN;
		BEGIN
			(* Re-start the HC *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			SYSTEM.PUT32(iobase + HcUsbCmd, dword + CmdRunStop);
			FlushPCI;
			(* Resume all individual ports *)
			res := TRUE;
			FOR i := 0 TO portCount - 1 DO
				IF ~ResumePort(i) THEN res := FALSE; END;
			END;
			RETURN res;
		END Resume;

		(**
		 * Get the status of the specified port.
		 * Registers which indicate status changes are reset by GetPortStatus.
		 * Note: UsbHcdi.HighSpeed will only be correctly set when the port is enabled. The hub driver
		 * takes care of this special behaviour by getting the port status again after it has enabled the port.
		 * @param port Port to get the status of
		 * @return Port status
		 *)
		PROCEDURE GetPortStatus*(port : LONGINT; ack : BOOLEAN) : SET;
		VAR status, s : SET;
		BEGIN
			s := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			(* Clear all bits that reported a change event; the correspondig register are R/WC *)
			IF ack & ((s * PscChangeMask) # {}) THEN SYSTEM.PUT32(ports[port], s); END;  FlushPCI;
			status := {};
			IF s * PscCurrentConnectStatus # {} THEN status := status + UsbHcdi.PortStatusDevicePresent; END;
			IF s * PscPortEnable # {} THEN status := status + UsbHcdi.PortStatusEnabled END;
			IF s * PscSuspend # {} THEN status := status + UsbHcdi.PortStatusSuspended END;
			IF s * PscOvercurrentActive # {} THEN status := status + UsbHcdi.PortStatusOverCurrent END;
			IF s * PscPortReset # {} THEN status := status + UsbHcdi.PortStatusReset END;
			IF s * PscPortPower # {} THEN status := status + UsbHcdi.PortStatusPowered END;
			IF s * PscConnectStatusChange # {} THEN status := status + UsbHcdi.PortStatusConnectChange END;
			IF s * PscPortEnableChange # {} THEN status := status + UsbHcdi.PortStatusEnabledChange END;
			IF s * PscOvercurrentChange # {} THEN status := status + UsbHcdi.PortStatusOverCurrentChange END;
			IF s * PscTestControl # {} THEN status := status + UsbHcdi.PortStatusTestControl END;
			IF s * PscIndicatorControl # {} THEN status := status + UsbHcdi.PortStatusIndicatorControl END;
			IF s * PscWakeOnOvercurrent # {} THEN status := status + UsbHcdi.PortStatusWakeOnOvercurrent; END;
			IF s * PscWakeOnDisconnect # {} THEN status := status + UsbHcdi.PortStatusWakeOnDisconnect; END;
			IF s * PscWakeOnConnect # {} THEN status := status + UsbHcdi.PortStatusWakeOnConnect; END;
			IF s * PscPortOwner # {} THEN status := status + UsbHcdi.PortStatusPortOwner; END;
			(* When a device is attached to a port of the root hub, the hub driver will try to reset and enable the port.
			The EHCI HC only enables the port if the connected device is a high-speed device which is determined during
			the reset. So if a device is attached to the port, the port is not in reset and it's enabled, it is a high-speed device *)
			IF (s * PscPortEnable = {}) & (s * PscCurrentConnectStatus # {}) & (s * PscPortPower # {}) & (s * {10} # {}) THEN (* Lowspeed device connected *)
				status := status + UsbHcdi.PortStatusLowSpeed;
			ELSIF (s * PscCurrentConnectStatus # {}) & (s * PscPortReset = {}) & (s * PscPortEnable # {}) THEN
				status := status + UsbHcdi.PortStatusHighSpeed;
			END;
			RETURN status;
		END GetPortStatus;

		(** Route the specified port to a companion host controller if supported. *)
		PROCEDURE RoutePortToCompanion*(port : LONGINT);
		VAR dword : SET;
		BEGIN
			(* Assert ports are not globally routed to companion controllers *)
			ASSERT(SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcConfigFlag)) * {0} # {});
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			SYSTEM.PUT32(ports[port], dword - PscChangeMask + PscPortOwner); FlushPCI;
		END RoutePortToCompanion;

		(** Indicate a port state using the port indicators *)
		PROCEDURE IndicatePort*(port, indicate : LONGINT);
		VAR indicators, dword : SET;
		BEGIN
			IF indicate = UsbHcdi.Amber THEN indicators := {14};
			ELSIF indicate = UsbHcdi.Green THEN indicators := {15};
			ELSE indicators := {};
			END;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			dword := dword - PscIndicatorControl + indicators;
			SYSTEM.PUT32(ports[port], dword); FlushPCI;
		END IndicatePort;

		(**	Return the current frame number.
		 	The micro-frame number is incremented each micro-frame, i.e. per 125us. There are 8 micro-frames per frame *)
		PROCEDURE GetFrameNumber*() : INTEGER;
		BEGIN
			RETURN SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET, LSH(SYSTEM.GET32(iobase + HcFrIndex), -3)) * {0..10});
		END GetFrameNumber;

		(*
		 * Contruct the queue head of the specified pipe.
		 * Fill in the following DWORDs into pipe.qh:
		 * - Queue Head Endpoint Capabilities 1
		 * - Queue Head Endpoint Capabilities 2
		 * - Current qTD Pointer
		 * - Next qTD Pointer, Alternate Next qTD Pointer, qTD Token & all five qTD Buffer Pointers
		 * The Queue Head Horizontal Link Pointer will be set by InsertPipeQH
		 * @param pipe
		 *)
		PROCEDURE BuildQueueHead(pipe : UsbHcdi.Pipe);
		VAR dword : SET; nakRL, multi, mmask : LONGINT;
		BEGIN
			ASSERT(pipe.maxPacketSize <= 1024); (* Maximum allowed packet size *)

			(*
			pipe.qh := Align(pipe.qh, alignQh);
			pipe.tdBase := pipe.qh + alignQh;;
			*)
			(*
			IF ~CheckBoundary(pipe.qh, sizeQh) THEN
				INC(pipe.qh, sizeQh);
				INC(pipe.tdBase, sizeQh)
			END;
			*)
			
			(* Queue Head Horizontal Link Pointer is not set here *)
			(* Queue Head Endpoint Capabilities 1 *)
			nakRL := 3;
			IF pipe.type = UsbHcdi.PipeInterrupt THEN nakRL := 0; END; (* EHCIspec, p.83 *)
			(* IF (pipe.speed = UsbHcdi.HighSpeed) & ((pipe.type = UsbHcdi.PipeBulk) OR
				(pipe.type = UsbHcdi.PipeControl)) (* Control OUT only *) THEN
				nakRL := pipe.irqInterval;
			END; *)
			dword := LSH(SYSTEM.VAL(SET, nakRL), 28) * QhNakCountReload;
			IF (pipe.speed # UsbHcdi.HighSpeed) & (pipe.type = UsbHcdi.PipeControl) THEN
				dword := dword + QhControlEndpointFlag;
			END;
			IF pipe.type = UsbHcdi.PipeControl THEN dword := dword  + QhDataToggleControl;  END;
			dword := dword + LSH(SYSTEM.VAL(SET, pipe.maxPacketSize), 16) * QhMaxPacketLen;
			IF (pipe.speed = UsbHcdi.LowSpeed) THEN (* EPS - endpoint speed *)
				dword := dword + {12}; (* Low-speed endpoint *)
			ELSIF (pipe.speed = UsbHcdi.FullSpeed) THEN
				(* Do nothing; Full-speed endpoint *)
			ELSIF (pipe.speed = UsbHcdi.HighSpeed) THEN
				dword := dword + {13}; (* High-speed endpoint *)
			ELSE
				HALT(99);
			END;
			dword := dword + LSH(SYSTEM.VAL(SET, pipe.endpoint), 8) * QhEndpointNbr;
			dword := dword + SYSTEM.VAL(SET, pipe.address) * QhDeviceAddress;
			SYSTEM.PUT32(pipe.qh + QhEpCapabilities1, dword);

			(* Queue Head Endpoint Capabilities 2 *)
			multi := 1; (* TODO: How many transactions per frame for high-speed isochronous and interrupts transfer are allowed? *)
			dword := LSH(SYSTEM.VAL(SET, multi), 30) * QhMultiplier;

			IF (pipe.speed = UsbHcdi.LowSpeed) OR (pipe.speed = UsbHcdi.FullSpeed) THEN
				ASSERT((pipe.ttAddress # 0) & (pipe.ttPort >= 0));
				(* Hub port and address for split transaction *)
				dword := dword + LSH(SYSTEM.VAL(SET, pipe.ttAddress), 16) * QhHubAddr;
				dword := dword + LSH(SYSTEM.VAL(SET, pipe.ttPort + 1), 23) * QhPortNbr;
				IF (pipe.type = UsbHcdi.PipeInterrupt) OR (pipe.type = UsbHcdi.PipeIsochronous) THEN
					(* In which micro-frames the HC should issue Complete Split tokens *)
					dword := dword + LSH({2..6}, 8) * QhSplitCMask;
				END;
			END;

			mmask := 1;
			IF (pipe.type = UsbHcdi.PipeInterrupt) OR (pipe.type = UsbHcdi.PipeIsochronous) THEN
				dword := dword + SYSTEM.VAL(SET, mmask)  * QhSMask;
			END;
			SYSTEM.PUT32(pipe.qh + QhEpCapabilities2, dword);
			SYSTEM.PUT32(pipe.qh + QhCurrentQtdPointer, 0);
			(* Zero-out the queue head transfer overlay *)
			SYSTEM.PUT32(pipe.qh + QhNextQtdPointer, QhTerminate);
			SYSTEM.PUT32(pipe.qh + QhAltNextQtdPointer, QhTerminate);
			SYSTEM.PUT32(pipe.qh + QhQtdToken, 0);
			SYSTEM.PUT32(pipe.qh + QhBufferPointer0, 0);
			SYSTEM.PUT32(pipe.qh + QhBufferPointer1, 0);
			SYSTEM.PUT32(pipe.qh + QhBufferPointer2, 0);
			SYSTEM.PUT32(pipe.qh + QhBufferPointer3, 0);
			SYSTEM.PUT32(pipe.qh + QhBufferPointer4, 0);
			IF cap64bit THEN
				SYSTEM.PUT32(pipe.qh + QhExtBufferPointer0, 0);
				SYSTEM.PUT32(pipe.qh + QhExtBufferPointer1, 0);
				SYSTEM.PUT32(pipe.qh + QhExtBufferPointer2, 0);
				SYSTEM.PUT32(pipe.qh + QhExtBufferPointer3, 0);
				SYSTEM.PUT32(pipe.qh + QhExtBufferPointer4, 0);
			END;
		END BuildQueueHead;

		(** Build a Queue Head for the specified pipe and insert it into the host controller schedule. *)
		PROCEDURE InsertQH*(pipe : UsbHcdi.Pipe) : BOOLEAN;
		VAR adr, asyncListAddr : LONGINT; dword : SET;
		BEGIN (* Only call from exclusive regions *)
			ASSERT((pipe # NIL) & (pipe.qh # 0) & (SYSTEM.VAL(SET, pipe.qh) * {0..4} = {}));
			ASSERT((pipe.maxPacketSize > 0));
			CASE pipe.type OF (* In which queue should we insert the pipe ? *)
				|UsbHcdi.PipeControl : pipe.queue := 0;
				| UsbHcdi.PipeBulk : pipe.queue := 0;
				| UsbHcdi.PipeIsochronous :
					(* TODO: Implement isochronous transfers  *)
					(* Enable the periodic list if necessary *)
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
					IF dword * CmdPeriodicSchedEnable = {} THEN
						SYSTEM.PUT32(iobase + HcUsbCmd, dword + CmdPeriodicSchedEnable); FlushPCI;
					END;
					RETURN TRUE;
				| UsbHcdi.PipeInterrupt :
					BEGIN
						IF pipe.irqInterval = 1 THEN (* 1ms queue *)
							pipe.queue := interruptQh[0];
						ELSIF pipe.irqInterval < 4 THEN (* 2ms queue *)
							pipe.queue := interruptQh[1];
						ELSIF pipe.irqInterval < 8 THEN (* 4ms queue *)
							pipe.queue := interruptQh[2];
						ELSIF pipe.irqInterval < 16 THEN (* 8ms queue *)
							pipe.queue := interruptQh[3];
						ELSIF pipe.irqInterval < 32 THEN (* 16ms queue *)
							pipe.queue := interruptQh[4];
						ELSE
							pipe.queue := interruptQh[5]; (* 32 ms queue *)
						END;
					END;
			ELSE
				RETURN FALSE;
			END;
			BuildQueueHead(pipe);
			IF pipe.queue = 0 THEN (* Insert into the asynchronous schedule list *)
				asyncListAddr := SYSTEM.GET32(iobase + HcAsyncListAddr);
				IF asyncListAddr = 0 THEN (* Not queue heads in the list yet *)
					(* Since the address is obviously invalid, the asynchronous schedule mustn't be enabled *)
					ASSERT(SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsAsyncSchedule = {});
					SYSTEM.PUT32(pipe.qh + QhHorizontalLinkPointer, SYSTEM.VAL(SET, pipe.qh) * {5..31}  + {1} - {2} - QhTerminate);
					(* If the asynchronous schedule is enabled, exactly one queue head MUST have the H-bit set. *)
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhEpCapabilities1)) + QhHeadOfReclamation;
					SYSTEM.PUT32(pipe.qh + QhEpCapabilities1, dword);
					Machine.FlushDCacheRange(pipe.qh, sizeQh);

					(* Insert the queue head into the schedule list and activate the asynchronous schedule *)
					SYSTEM.PUT32(iobase + HcAsyncListAddr, pipe.qh); FlushPCI;
					IF ~ScheduleOn(CmdAsyncSchedEnable, TRUE) & (Debug.Level >= Debug.Errors) THEN Show("Failed to enable async schedule."); KernelLog.Ln; END;
				ELSE
					ASSERT(SYSTEM.VAL(SET, asyncListAddr) * {0..4} = {}); (* 32byte alignment *)
					adr := asyncListAddr;
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + QhHorizontalLinkPointer));
					SYSTEM.PUT32(pipe.qh + QhHorizontalLinkPointer, dword);
					Machine.FlushDCacheRange(pipe.qh, sizeQh);

					(* Insert the newly created queue head into the asynchronous schedule list. *)
					dword := SYSTEM.VAL(SET, pipe.qh) * {5..31} + {1}  - {2}  - QhTerminate;
					SYSTEM.PUT32(adr + QhHorizontalLinkPointer, dword);
				END;
			ELSE (* Insert into the periodic schedule list *)
				adr := SYSTEM.GET32(pipe.queue + QhHorizontalLinkPointer);
				SYSTEM.PUT32(pipe.qh + QhHorizontalLinkPointer, adr);
				SYSTEM.PUT32(pipe.queue + QhHorizontalLinkPointer, pipe.qh + SYSTEM.VAL(LONGINT, {1} - {2}));
				Machine.FlushDCacheRange(pipe.qh, sizeQh);
				Machine.FlushDCacheRange(pipe.queue, sizeQh);
				(* Enable the periodic list if necessary *)
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
				IF dword * StsPeriodicSchedule = {} THEN
					IF ~ScheduleOn(CmdPeriodicSchedEnable, TRUE) THEN
						IF Debug.Level >= Debug.Errors THEN Show("Could not enable periodic schedule."); KernelLog.Ln; END;
					END;
				END;
			END;
			IF Debug.Trace & Debug.traceQueuing THEN Show("Inserted QH at "); KernelLog.Address(pipe.qh); KernelLog.Ln; END;
			Machine.FlushDCacheRange(pipe.qh, sizeQh);
			RETURN TRUE;
		END InsertQH;

		(* Enable/Disable the periodic or asynchronous schedule. *)
		PROCEDURE ScheduleOn(cmd : SET; on : BOOLEAN) : BOOLEAN;
		VAR dword, sts : SET; mtimer : Kernel.MilliTimer;
		BEGIN (* Caller must hold obj lock *)
			ASSERT((cmd = CmdPeriodicSchedEnable) OR (cmd = CmdAsyncSchedEnable));
			IF Debug.Trace & Debug.traceQueuing THEN
				IF on THEN Show("Enabling"); ELSE Show("Disabling"); END;
				IF cmd = CmdAsyncSchedEnable THEN KernelLog.String(" asynchronous schedule."); ELSE KernelLog.String(" periodic schedule."); END;
				KernelLog.Ln;
			END;
			IF cmd = CmdAsyncSchedEnable THEN sts := StsAsyncSchedule; ELSE sts := StsPeriodicSchedule; END;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			ASSERT(dword * cmd = LSH(SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * sts, -10)); (* HcUsbCmd & HcUsbSts in consistent state *)
			IF on THEN dword := dword + cmd; ELSE dword := dword - cmd; END;
			SYSTEM.PUT32(iobase + HcUsbCmd, dword); FlushPCI;

			(* Wait until the HC reaches the desired state *)
			Kernel.SetTimer(mtimer, 500);
			WHILE ~Kernel.Expired(mtimer) & ((SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * sts # {}) # on) DO
				Objects.Yield;
			END;
			RETURN (SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * sts # {}) = on;
		END ScheduleOn;

		(*
		 * Remove a queue head data structure from the host controller's asynchronous schedule.
		 * The asynchronous schedule is a circular linked list of queue heads. At least one queue heads has
		 * the H-bit (Head of asynchronous schedule list) set which is used by the host controller to detect
		 * empty list conditions. There are two cases when we remove a queue head:
		 * 1) It is the only queue head in the list. In this case, we disabled the asynchronous schedule execution and
		 *     and remove the queue head then.
		 * 2) There are other queue heads in the list. If the queue head to be removed is the head of the list, we
		 *      need to set the H-bit for another queue head.
		 *
		 * Precondition: TDs are already removed from the QH, QH is inactive
		 *)
		 PROCEDURE RemoveAsyncQH(pipe : UsbHcdi.Pipe);
		 VAR start, cur, prev  : LONGINT; dword : SET;
		 BEGIN (* Caller must hold obj lock *)
			prev := SYSTEM.GET32(iobase + HcAsyncListAddr);
			ASSERT((prev # 0) & (SYSTEM.VAL(SET, prev) * {0..4} = {}));
			Machine.InvalidateDCacheRange(prev, sizeQh);
			prev := SYSTEM.GET32(prev + QhHorizontalLinkPointer);
			ASSERT((SYSTEM.VAL(SET, prev) * {1} # {}) & (SYSTEM.VAL(SET, prev) * QhTerminate = {})); (* Pointer references queue head *)
			prev := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, prev) * {5..31});
			Machine.InvalidateDCacheRange(prev, sizeQh);
			cur := SYSTEM.GET32(prev + QhHorizontalLinkPointer);
			ASSERT((SYSTEM.VAL(SET, cur) * {1} # {}) & (SYSTEM.VAL(SET, cur) * QhTerminate  =  {})); (* Pointer references queue head *)
			cur := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, cur) * {5..31});
			Machine.InvalidateDCacheRange(cur, sizeQh);

			(* prev is the address of the queue head that points to the queue head with the address cur *)
			IF cur = prev THEN (* Only one queue head in the list *)
				ASSERT(SYSTEM.VAL(SET, SYSTEM.GET32(cur + QhEpCapabilities1)) * QhHeadOfReclamation # {});
				ASSERT(SYSTEM.VAL(SET, SYSTEM.GET32(cur + QhQtdToken)) * TdActive = {});
				IF cur = pipe.qh THEN (* just disable asynchronous schedule *)
					IF ScheduleOn(CmdAsyncSchedEnable, FALSE) THEN
						SYSTEM.PUT32(iobase + HcAsyncListAddr, 0); FlushPCI; (* Mark as invalid. *)
					ELSIF Debug.Level >= Debug.Errors  THEN Show("Could not disable async schedule."); KernelLog.Ln;
					END;
				ELSIF Debug.Level >= Debug.Warnings THEN Show("Failed to remove QH from asynchronous schedule: QH not found."); KernelLog.Ln;
				END;
			ELSE (* Find and remove the queue head in the list *)
				(* Search the queue head that references the queue head to be removed *)
				start := cur;
				LOOP
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(cur + QhHorizontalLinkPointer));
					ASSERT(dword * QhTerminate = {}); (* Circular lists don't terminate *)
					ASSERT(dword * {1} # {}); (* Pointer references queue head *)
					ASSERT(dword * {2..4} = {}); (* qTD pointers must be 32byte aligned *)
					prev := cur;
					cur := SYSTEM.VAL(LONGINT, dword * {5..31});
					IF cur = pipe.qh THEN (* QH found *) EXIT; END;
					IF cur = start THEN (* list completely searched but QH not found *) EXIT; END;
					Machine.InvalidateDCacheRange(cur, sizeQh);
				END;

				IF cur = pipe.qh THEN (* Found the queue head. prev is pointing to it *)
					(* If we remove the head of reclamation, elect a new one *)
					IF SYSTEM.VAL(SET, SYSTEM.GET32(cur + QhEpCapabilities1)) * QhHeadOfReclamation # {} THEN
						IF Debug.Trace & Debug.traceQueuing THEN Show("Electing new head of reclamation."); KernelLog.Ln; END;
						dword := SYSTEM.VAL(SET, SYSTEM.GET32(prev + QhEpCapabilities1));
						SYSTEM.PUT32(prev + QhEpCapabilities1, dword + QhHeadOfReclamation);
					END;
					(* Remove QH from asynchronous list and inforam host controller *)
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(cur + QhHorizontalLinkPointer));
					SYSTEM.PUT32(prev + QhHorizontalLinkPointer, dword);
					Machine.FlushDCacheRange(prev, sizeQh);
				ELSIF Debug.Level >= Debug.Warnings THEN Show("Failed to remove QH from asynchronous list: QH not found."); KernelLog.Ln;
				END;
				(* Before we may free the pipe ressources, we have to make sure that the HC has no cached references to the structure 	*)
				(* we just removed. 																									*)
				IF ~HcHandshake() THEN
					IF Debug.Level >= Debug.Errors THEN Show("UsbEhci: Serious error: HC handshake failed."); KernelLog.Ln; END;
				END;
			END;
			IF Debug.Trace & Debug.traceQueuing THEN Show("Removed QH at "); KernelLog.Hex(pipe.qh, 8); KernelLog.Ln; END;
		 END RemoveAsyncQH;

	 	(*
	 	 * Inform the host controller that we removed something from the asynchronous schedule list. This is
		 * necessary since the HC could have cached a copy of the pointer to the queue head we've just removed.
		 *)
		PROCEDURE HcHandshake() : BOOLEAN;
		VAR dword : SET; mtimer : Kernel.MilliTimer; result : BOOLEAN;
		BEGIN (* caller holds object lock *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
			ASSERT(dword * StsAsyncSchedule # {}); (* HC behaviour undefined if ringing doorbell while async schedule is off *)
			hcHandshake := FALSE;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			SYSTEM.PUT32(iobase + HcUsbCmd, dword + CmdAsyncAdvDoorbell); FlushPCI;
			Kernel.SetTimer(mtimer, 500);
			WHILE ~Kernel.Expired(mtimer) & (SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd)) * CmdAsyncAdvDoorbell # {}) DO
				Objects.Yield;
			END;
			result := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd)) * CmdAsyncAdvDoorbell = {}; (* The HC should have cleared the bit *)
			IF Debug.Trace & Debug.traceQueuing THEN
				Show("HC handshake "); IF result THEN KernelLog.String("succeeded."); ELSE KernelLog.String("failed."); END; KernelLog.Ln;
			END;
			RETURN result;
		END HcHandshake;

		PROCEDURE RemovePeriodicQH(pipe : UsbHcdi.Pipe);
		VAR timer : Kernel.Timer; cur, temp : LONGINT; next : SET;
		BEGIN (* caller must hold obj lock *)
			IF pipe.queue = 0 THEN RETURN; END;
			cur := pipe.queue;
			LOOP
				Machine.InvalidateDCacheRange(cur, sizeQh);
				next := SYSTEM.VAL(SET, SYSTEM.GET32(cur + QhHorizontalLinkPointer));
				IF next * {5..31} = SYSTEM.VAL(SET, pipe.qh) * {5..31} THEN (* found *)
					temp := SYSTEM.GET32(pipe.qh + QhHorizontalLinkPointer);
					SYSTEM.PUT32(cur + QhHorizontalLinkPointer, temp);
					Machine.FlushDCacheRange(cur, sizeQh);
					IF Debug.Trace & Debug.traceQueuing THEN KernelLog.String("UsbEhci: Deleted Interrupt Pipe QH."); KernelLog.Ln; END;
					NEW(timer); timer.Sleep(10); (* HC has still access to QH, wait > 1ms *)
					EXIT;
				ELSIF next * QhTerminate # {} THEN (* not found, reached end of list *)
					IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbEhci: Could not delete interrupt QH -> QH not found."); KernelLog.Ln; END;
					EXIT;
				ELSE
					cur := SYSTEM.VAL(LONGINT, next * {5..31});
				END;
			END;
			IF Debug.Trace & Debug.traceQueuing THEN Show("Removed QH at "); KernelLog.Hex(pipe.qh, 8); KernelLog.Ln; END;
		END RemovePeriodicQH;

		(** Remove the pipe's queue head from the host controller schedule *)
		PROCEDURE RemoveQH*(pipe : UsbHcdi.Pipe);
		BEGIN (* caller must hold obj lock *)
			IF Debug.Trace & Debug.traceQueuing THEN Show("Removing QH at "); KernelLog.Hex(pipe.qh, 8); KernelLog.Ln; END;
			(* First remove all transfer descriptors from the queue head *)
			UnlinkTDsInternal(pipe);
			(* Then remove the pipe's queue head from the host controller schedule *)
			IF (pipe.type = UsbHcdi.PipeControl) OR (pipe.type = UsbHcdi.PipeBulk) THEN
				RemoveAsyncQH(pipe);
			ELSIF pipe.type = UsbHcdi.PipeInterrupt THEN
				RemovePeriodicQH(pipe);
			ELSE
				(* TODO: Isochronous transfers not yet implemented *)
			END;
		END RemoveQH;

		(** Checks whether TDs may be linked to the pipe's QH *)
		PROCEDURE LinkTDsAllowed*(pipe : UsbHcdi.Pipe) : BOOLEAN;
		VAR dword : SET;
		BEGIN {EXCLUSIVE}
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhQtdToken));
			IF dword * TdActive # {} THEN
				IF Debug.Level >= Debug.Errors THEN Show("LinkTDs: ERROR: PIPE IS STILL ACTIVE!!!!"); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.LinkTDsFailed;
				RETURN FALSE;
			END;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhNextQtdPointer));
			IF dword * QhTerminate = {} THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: LinkTDs: Overwriten valid pointer ?!?"); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.LinkTDsFailed;
				RETURN FALSE;
			END;
			RETURN TRUE;
		END LinkTDsAllowed;

		(* Insert the TD list <td> into the queue (ED) <queue> *)
		PROCEDURE LinkTDs*(pipe : UsbHcdi.Pipe;  qtd : Machine.Address32);
		VAR dword : SET;
		BEGIN {EXCLUSIVE}
			ASSERT(SYSTEM.VAL(SET, qtd) * {0..4} = {}); (* 32byte alignment *)
			(* Pipe must be inactive... *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhQtdToken));
			IF dword * TdHalted # {} THEN
				IF Debug.Trace & Debug.tracePipes THEN Show("LinkTDs: Automatically clear halt condition"); KernelLog.Ln; END;
				ClearHalt(pipe);
			END;

			SYSTEM.PUT32(pipe.qh + QhNextQtdPointer, qtd);
			Machine.FlushDCacheRange(pipe.qh, sizeQh);
			Machine.FlushDCacheRange(qtd, sizeQtd);
			IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsAsyncSchedule = {} THEN
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
				IF dword * CmdAsyncSchedEnable = {} THEN
					IF ~ScheduleOn(CmdAsyncSchedEnable, TRUE) & (Debug.Level >= Debug.Errors) THEN Show("Failed to re-enabled async schedule."); KernelLog.Ln; END;
				END;
			END;
		END LinkTDs;

		(** Remove all transfer descriptors from the pipe's queue head *)
		PROCEDURE UnlinkTDs*(pipe : UsbHcdi.Pipe);
		BEGIN {EXCLUSIVE}
			UnlinkTDsInternal(pipe);
		END UnlinkTDs;

		(** Remove all transfer descriptors from the pipe's queue head *)
		PROCEDURE UnlinkTDsInternal(pipe : UsbHcdi.Pipe);
		VAR dword : SET; timer : Kernel.Timer; qtd : LONGINT; mtimer : Kernel.MilliTimer;
		BEGIN (* caller must hold obj lock *)
			IF pipe.firstTD = 0 THEN RETURN END; (* pipe has not yet been used *)
			(* We must inactivate all qTD of the queue head... *)

			qtd := pipe.firstTD; ASSERT(pipe.lastTD >= pipe.firstTD); (* Consistency check *)
			AssertAlignment(qtd, alignQtd);
			WHILE qtd <= pipe.lastTD DO
				Machine.InvalidateDCacheRange(qtd, sizeQtd);
				AssertAlignment(qtd, alignQtd);
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(qtd + QtdToken));
				SYSTEM.PUT32(qtd + QtdToken, dword - TdActive);
				qtd := qtd + sizeQtd;
			END;

			(* we should wait until the transaction overlay is also inactive *)
			Kernel.SetTimer(mtimer, 2000);
			Machine.InvalidateDCacheRange(pipe.qh, sizeQh);
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhQtdToken));
			WHILE ~Kernel.Expired(mtimer) & (dword  * TdActive # {}) DO
				Machine.InvalidateDCacheRange(pipe.qh, sizeQh);
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhQtdToken));
				Objects.Yield;
			END;
			IF dword * TdActive # {} THEN
				IF Debug.Level >= Debug.Errors THEN Show("Transaction overlay indicates active transfer!"); KernelLog.Ln; END;
			END;

			NEW(timer); timer.Sleep(10); (* > 1ms - the HC could update the QhQtdToken field *)
			SYSTEM.PUT32(pipe.qh + QhQtdToken, 0);
			Machine.FlushDCacheRange(pipe.qh, sizeQh);
			timer.Sleep(2); (* > 1ms *)
			IF SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhQtdToken)) * TdActive # {} THEN
				IF Debug.Level >= Debug.Errors THEN Show("Failed to unlink TDs from pipe:"); KernelLog.Ln;  pipe.Show(TRUE); KernelLog.Ln; END;
			(*	RETURN;  *)
			END;

			SYSTEM.PUT32(pipe.qh + QhNextQtdPointer, QhTerminate);
			SYSTEM.PUT32(pipe.qh + QhAltNextQtdPointer, QhTerminate);
			SYSTEM.PUT32(pipe.qh + QhCurrentQtdPointer, 0); (* Bits 0-4 are reserved *)
			SYSTEM.PUT32(pipe.qh + QhQtdToken, 0);
			Machine.FlushDCacheRange(pipe.qh, sizeQh);
			pipe.firstTD := 0; pipe.lastTD := 0;
		END UnlinkTDsInternal;

		(*
		 * Clears the Halt bit in the pipe's queue head and removes any qTD from the pipe.
		 * Note that this only makes sense if the Halt feature of the USB device is also cleared used the ClearFeature standard
		 * request. This procedure here only changes the pipe's queue head.
		 *)
		PROCEDURE ClearHalt(pipe : UsbHcdi.Pipe);
		VAR dword : SET;
		BEGIN
			Machine.InvalidateDCacheRange(pipe.qh, sizeQh);
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhQtdToken));
			IF dword * TdHalted # {} THEN
				SYSTEM.PUT32(pipe.qh + QhCurrentQtdPointer, 0);
				(* Zero-out the queue head transfer overlay *)
				SYSTEM.PUT32(pipe.qh + QhNextQtdPointer, QhTerminate);
				SYSTEM.PUT32(pipe.qh + QhAltNextQtdPointer, QhTerminate);
				SYSTEM.PUT32(pipe.qh + QhQtdToken, 0);
				SYSTEM.PUT32(pipe.qh + QhBufferPointer0, 0);
				SYSTEM.PUT32(pipe.qh + QhBufferPointer1, 0);
				SYSTEM.PUT32(pipe.qh + QhBufferPointer2, 0);
				SYSTEM.PUT32(pipe.qh + QhBufferPointer3, 0);
				SYSTEM.PUT32(pipe.qh + QhBufferPointer4, 0);
				IF cap64bit THEN
					SYSTEM.PUT32(pipe.qh + QhExtBufferPointer0, 0);
					SYSTEM.PUT32(pipe.qh + QhExtBufferPointer1, 0);
					SYSTEM.PUT32(pipe.qh + QhExtBufferPointer2, 0);
					SYSTEM.PUT32(pipe.qh + QhExtBufferPointer3, 0);
					SYSTEM.PUT32(pipe.qh + QhExtBufferPointer4, 0);
				END;
				Machine.FlushDCacheRange(pipe.qh, sizeQh)
			ELSIF Debug.Level >= Debug.Warnings THEN Show("Tried to clear a non-halted pipe."); KernelLog.Ln;
			END;
		END ClearHalt;

		(**
		 * Put the specified control transfer into the host controller's schedule.
		 * USB Control Transfers use a three stage protocol:
		 *  - stage 1: control setup transaction
		 *  - stage 2: optional data stage
		 *  - stage 3: status transaction
		 * For high-speed devices, the PING protocol must be used for OUT transactions in the data stage and status stage.
		 *
		 *
		 * @param pipe
		 * @param direction Direction of the control transfer (UsbHcdi.In (device-to-host) | UsbHcdi.Out (host-to-device))
		 * @param msg Control message
		 * @param bufferlen Number of bytes transmitted/received in the data stage
		 * @param buffer Buffer where to get/put the specified number of bytes
		 *)
		PROCEDURE ScheduleControl*(pipe : UsbHcdi.Pipe; direction : LONGINT; msg : UsbHcdi.ControlMessage;  bufferLen : LONGINT; VAR buffer : Usbdi.Buffer);
		VAR
			qtd : Machine.Address32;
			dword : SET;
			ranges : ARRAY ScatterGatherListSize OF Machine.Range;
			numRanges : LONGINT;
		BEGIN
			(*Machine.FlushDCacheRange(ADDRESSOF(buffer[0]), bufferLen);*)
			(* pipe.tdBase = pipe.qh + 32 in UsbHcdi *)
(*			pipe.firstTD := pipe.tdBase;
			ASSERT(pipe.firstTD = pipe.qh + alignQh); 
*)			
			pipe.firstTD := pipe.tdBase - 32 + alignQh;
			AssertAlignment(pipe.firstTD, alignQtd);
			ASSERT(SYSTEM.VAL(SET, pipe.firstTD) * {0..4} = {}); (* qTDs must be 32byte aligned *)
			ASSERT(pipe.firstTD MOD alignQtd = 0);

			IF (pipe.speed = UsbHcdi.LowSpeed) OR (pipe.speed = UsbHcdi.FullSpeed) THEN
				IF pipe.maxRetries = 0 THEN
					(* For low-speed and full-speed devices, the value 0 is not allowed *)
					pipe.maxRetries := 3;
				END;
			END;

			(* Stage1: Control setup transaction *)
			qtd := pipe.firstTD;
			ASSERT((qtd + sizeQtd - 1 <= ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1])));

			AssertAlignment(qtd+sizeQtd, alignQtd);
			SYSTEM.PUT32(qtd + QtdNextQtdPointer, qtd + sizeQtd);
			SYSTEM.PUT32(qtd + QtdAltNextQtdPointer, QtdTerminate); (* Mark Alternate Next qTD Pointer as invalid *)

			dword := LSH(SYSTEM.VAL(SET, pipe.maxRetries), 10) * QtdErrorCounter; (* DataToggle = FALSE; Current Page = 0; no IOC *)
			dword := dword + LSH(SYSTEM.VAL(SET, 8), 16) * QtdBytesToTransfer; (* 8byte control message *)
			dword := dword + LSH(SYSTEM.VAL(SET, PidSetup), 8) * QtdPidCode + TdActive;
			SYSTEM.PUT32(qtd + QtdToken, dword);

			Machine.TranslateVirtual(ADDRESSOF(msg[0]), 8, numRanges, ranges);
			IF numRanges = 0 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: ScheduleControl: Scatter/Gather list too small."); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.TransferTooLarge; RETURN;
			END;

			(* The HC will access the next buffer pointer when the buffer crosses a physical page... *)
			SYSTEM.PUT32(qtd + QtdBufferPtr0, ranges[0].adr);
			IF numRanges > 1 THEN (* buffer is across page boundaries *)
				SYSTEM.PUT32(qtd + QtdBufferPtr1, ranges[1].adr)
			ELSE
				SYSTEM.PUT32(qtd + QtdBufferPtr1, 0);
			END;
			SYSTEM.PUT32(qtd + QtdBufferPtr2, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr3, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr4, 0);
			IF cap64bit THEN
				SYSTEM.PUT32(qtd + QtdExtBufferPtr0, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr1, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr2, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr3, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr4, 0);
			END;
			Machine.FlushDCacheRange(qtd, sizeQtd);

			(* Setup phase always starts with dataToggle = FALSE, so now it must be TRUE *)
			pipe.dataToggle := TRUE;

			(* Stage 2: Optional data stage *)
			IF bufferLen # 0 THEN
				IF ~CreateTDList(pipe, direction, bufferLen, 0, buffer, qtd + sizeQtd, qtd, TRUE) THEN
					pipe.status := Usbdi.Error; pipe.errors := UsbHcdi.Internal; RETURN;
				END;
			END;

			Machine.FlushDCacheRange(qtd, sizeQtd);
			qtd := qtd + sizeQtd;
			AssertAlignment(qtd, alignQtd);
			IF qtd + sizeQtd - 1 > ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1]) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: TD buffer too small."); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.OutOfTDs; RETURN;
			END;

			(* stage 3: status: build status TD *)

			SYSTEM.PUT32(qtd + QtdNextQtdPointer, QtdTerminate); (* Last qTD in chain *)
			SYSTEM.PUT32(qtd + QtdAltNextQtdPointer, QtdTerminate); (* Mark Alternate Next qTD Pointer as invalid *)

			dword := QtdDataToggle + TdActive; (* dataToggle always TRUE and set ind TD in status stage; CC = not accessed *)

			IF (direction = UsbHcdi.Out) OR (bufferLen = 0) THEN
				dword := dword + LSH(SYSTEM.VAL(SET, PidIn), 8);
			ELSE
				dword := dword + LSH(SYSTEM.VAL(SET, PidOut), 8);
				IF pipe.speed = UsbHcdi.HighSpeed THEN (* Do PING protocol *)
					dword := dword + TdPingState;
				END;
			END;
			dword := dword + LSH(SYSTEM.VAL(SET, pipe.maxRetries), 10) * QtdErrorCounter;
			IF pipe.ioc THEN dword := dword + QtdIoc; END; (* Set interrupt on completion bit *)
			SYSTEM.PUT32(qtd + QtdToken, dword);

			SYSTEM.PUT32(qtd + QtdBufferPtr0, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr1, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr2, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr3, 0);
			SYSTEM.PUT32(qtd + QtdBufferPtr4, 0);
			IF cap64bit THEN
				SYSTEM.PUT32(qtd + QtdExtBufferPtr0, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr1, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr2, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr3, 0);
				SYSTEM.PUT32(qtd + QtdExtBufferPtr4, 0);
			END;

			Machine.FlushDCacheRange(ADDRESSOF(msg[0]), LEN(msg));
			Machine.FlushDCacheRange(ADDRESSOF(buffer[0]), bufferLen);
			Machine.FlushDCacheRange(qtd, sizeQtd);
			pipe.lastTD := qtd;
		END ScheduleControl;

		PROCEDURE Schedule*(pipe : UsbHcdi.Pipe; bufferLen, offset: LONGINT; VAR buffer: Usbdi.Buffer);
		VAR dword : SET;
		BEGIN
			Machine.FlushDCacheRange(ADDRESSOF(buffer[offset]), bufferLen);
			SYSTEM.PUT32(pipe.qh + QhCurrentQtdPointer, 0);
(*			pipe.firstTD := pipe.tdBase;
			ASSERT(pipe.firstTD = pipe.qh + alignQh); 
*)
			pipe.firstTD :=  pipe.tdBase - 32 + alignQh;
			
			AssertAlignment(pipe.firstTD, alignQtd);
			ASSERT(pipe.firstTD MOD alignQtd = 0);
			ASSERT(SYSTEM.VAL(SET, pipe.firstTD) * {0..4} = {}); (* qTDs must be 32byte aligned *)

			IF ~CreateTDList(pipe, pipe.direction, bufferLen, offset, buffer, pipe.firstTD, pipe.lastTD, FALSE) THEN
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.LinkTDsFailed; RETURN;
			END;

			SYSTEM.PUT32(pipe.lastTD + QtdNextQtdPointer, QhTerminate);
			IF pipe.ioc THEN
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.lastTD + QtdToken));
				dword := dword + QtdIoc;
				SYSTEM.PUT32(pipe.lastTD + QtdToken, dword);
			END;
		END Schedule;

		PROCEDURE CreateTDList(pipe : UsbHcdi.Pipe; direction, len, ofs : LONGINT; VAR buffer : Usbdi.Buffer; firstTD : LONGINT; VAR lastTD : Machine.Address32; tdToggle : BOOLEAN) : BOOLEAN;
		VAR
			restlen, curlen, temp : LONGINT;
			j, qtd, nextTd : LONGINT;
			dword : SET;
			numRanges, idx, offset : LONGINT;
		BEGIN
			ASSERT((pipe.maxRetries >= 0) & (pipe.maxRetries <= 3));
			Machine.TranslateVirtual(ADDRESSOF(buffer[ofs]), len, numRanges, pipe.sgList^);
			IF numRanges = 0 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: Schedule: Scatter/Gather list too small"); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.TransferTooLarge;
				RETURN FALSE;
			END;

			qtd := firstTD - sizeQtd;
			idx := 0;
			offset := 0;		(* offset from last qTD (must fill multiples of packetSize into qTD buffers) *)
			curlen := 0; 		(* amount of data that is transferred in a single qTD *)
			restlen := len;	(* total amount of data to be transferred *)

			WHILE restlen > 0 DO (* build qTD chain *)
				
				qtd := qtd + sizeQtd;
				IF qtd + sizeQtd - 1 > ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1]) THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: TD buffer too small"); KernelLog.Ln; END;
					pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.OutOfTDs;
					RETURN FALSE;
				END;

				(* Each qTD has for buffer pointers. Each buffer is 4K. The buffer must be virtually contiguous but may be				*)
				(* physically non-contiguous. The HC detects crossings of page boundaries and increments the current buffer pointer. 	*)
				SYSTEM.PUT32(qtd + QtdBufferPtr0, pipe.sgList[idx].adr + offset);
				curlen := PageSize - LONGINT ((pipe.sgList[idx].adr + offset)  MOD PageSize);
				IF curlen > restlen THEN (* No other buffer pointers needed, fits into the first page *)
					curlen := restlen;
				END;
				ASSERT(curlen > 0);
				restlen := restlen - curlen; offset := 0;
				INC(idx);

				(* Fill in the other 4 buffer pointers *)
				FOR j := 1 TO 4 DO
					IF restlen <= 0 THEN
						SYSTEM.PUT32(qtd + QtdBufferPtr0 + j*4, 0);
					ELSE
						IF j = 4 THEN (* last buffer available in this qTD *)
							temp := PageSize - ((curlen + PageSize) MOD pipe.maxPacketSize); (* data that fits into the last buffer (max) *)
							IF restlen > temp THEN
								(* The HC will issues USB transaction at pipe.maxPacketSize granularity. If this is not the 			*)
								(* last qTD of this qTD chain, curlen must be multiple of pipe.maxPacketSize. If the last qTD of this	*)
								(* chain was not a multiple of pipe.maxPacketSize, the device will send more data (since we 		*)
								(* requested more data) and the HC thinks it's a babble.											*)
								curlen := curlen + temp; restlen := restlen - temp; offset := temp;
								SYSTEM.PUT32(qtd + QtdBufferPtr0 + j*4, pipe.sgList[idx].adr);
								IF offset = PageSize THEN INC(idx); offset := 0;
								ELSE (* In the next iteration of the outer while loop, the same page will be completed -> don't increment idx *)
								END;
							ELSE (* this is the last qTD in chains *)
								curlen := curlen + restlen; restlen := 0;
								SYSTEM.PUT32(qtd + QtdBufferPtr0 + j*4, pipe.sgList[idx].adr);
							END;
						ELSE
							IF restlen > PageSize THEN
								curlen := curlen + PageSize; restlen := restlen - PageSize;
							ELSE
								curlen := curlen + restlen; restlen := 0;
							END;
							SYSTEM.PUT32(qtd + QtdBufferPtr0 + j*4, pipe.sgList[idx].adr);
							INC(idx);
						END;
					END;
				END;

				IF cap64bit THEN
					SYSTEM.PUT32(qtd + QtdExtBufferPtr0, 0);
					SYSTEM.PUT32(qtd + QtdExtBufferPtr1, 0);
					SYSTEM.PUT32(qtd + QtdExtBufferPtr2, 0);
					SYSTEM.PUT32(qtd + QtdExtBufferPtr3, 0);
					SYSTEM.PUT32(qtd + QtdExtBufferPtr4, 0);
				END;

				SYSTEM.PUT32(qtd + QtdNextQtdPointer, qtd + sizeQtd);
				SYSTEM.PUT32(qtd + QtdAltNextQtdPointer, QtdTerminate); (* Mark Alternate Next qTD Pointer as invalid *)

				ASSERT(curlen <= 5000H); (* Maximum allowed value for a single qTD: 5*4KB *)

				dword := TdActive;
				dword := dword + LSH(SYSTEM.VAL(SET, pipe.maxRetries), 10) * QtdErrorCounter;  (* Current Page=0 *)
				dword := dword + LSH(SYSTEM.VAL(SET, curlen), 16) * QtdBytesToTransfer;

				IF tdToggle THEN
					IF pipe.dataToggle THEN	dword := dword + QtdDataToggle; END;

					(* Calculate datatoggle value for next TD *)
					IF (curlen DIV pipe.maxPacketSize) MOD 2 # 0 THEN
						pipe.dataToggle := ~pipe.dataToggle;
					END;
				END;

				IF direction = UsbHcdi.In  THEN
					dword := dword + LSH(SYSTEM.VAL(SET, PidIn), 8);
				ELSIF direction = UsbHcdi.Out THEN
					dword := dword + LSH(SYSTEM.VAL(SET, PidOut), 8);
					IF pipe.speed = UsbHcdi.HighSpeed THEN (* Do PING protocol *)
						dword := dword + TdPingState;
					END;
				END;

				SYSTEM.PUT32(qtd + QtdToken, dword);
				Machine.FlushDCacheRange(qtd, sizeQtd);
			END;

			lastTD := qtd;
			RETURN TRUE;
		END CreateTDList;



		PROCEDURE InterruptHandler;
		VAR s  : SET;
		BEGIN (* Works without being exclusive *)
			IF Debug.Stats THEN INC(NnofInterrupts); END;
			IF state >= UsbHcdi.Initialized THEN

				s := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * interruptsEnabled;

				IF s # {} THEN
					IF Debug.Stats THEN INC(NnofInterruptsHandled); END;
					IF Debug.Trace & Debug.traceInterrupts THEN
						Show("Interrupt: "); ShowInterrupts(s); KernelLog.Ln;
					END;
					(* Reset interrupt status register (Write clear)*)
					SYSTEM.PUT32(iobase + HcUsbSts, s * {0..5}); FlushPCI;

					IF s * StsAsyncAdvance # {} THEN hcHandshake := TRUE; END;
					IF s * StsHostSystemError # {} THEN
						 Show("Serious error. Please restart the EHCI driver:");
						 IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsHcHalted # {} THEN
						 	KernelLog.String(" [HC halted]");
						 	SetState(UsbHcdi.Halted);
						 END;
						 KernelLog.Ln;
					END;
					IF s * StsFrameListRollover # {} THEN END;
					IF s * StsPortChange # {} THEN
						(* TODO: If wake-up, time 20ms, poll PscSuspend... enable HC if necessary*)
						IF statusChangeHandler # NIL THEN  statusChangeHandler(Usbdi.Ok, 0); END;
					END;
					IF s * (StsUsbError + StsUsbInterrupt) # {} THEN (* USB Interrupt occured: can be IOC or ShortPacketInt *)
						NotifyCompletionHandlers;
					END;
				END;
			END;
		END InterruptHandler;

		(* re-evaluate the status of the pipe's qh (endpoint descriptor) and its TD list *)
		PROCEDURE UpdatePipeStatus*(pipe : UsbHcdi.Pipe);
		CONST MaxLoops = 10000;
		VAR
			qtd : LONGINT;
			s, errors : SET;
			restLen, len : LONGINT;
			loop : LONGINT;
		BEGIN
			FlushPCI;
			(* First look up active bit in the QH tranfer overlay *)
			Machine.InvalidateDCacheRange(pipe.qh, sizeQh);
			s := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhQtdToken));
			IF s * TdActive # {}  THEN  (* The HC hasn't yet executed the transaction *) RETURN; END;

			errors := UsbHcdi.NoErrors; loop := 0; restLen := 0; qtd := pipe.firstTD;
			LOOP
				AssertAlignment(qtd, alignQtd);
				Machine.InvalidateDCacheRange(qtd, sizeQtd);

				(* evaluate condition codes (CC)*)
				s := SYSTEM.VAL(SET, SYSTEM.GET32(qtd + QtdToken)) * QtdStatus - TdPingState - TdSplitTransactionState;

				(* TODO: NOTE: TdPingState would be used as error indicator for split transactions *)

				IF s = {} THEN (* No errors occured *)
				ELSIF s * TdActive # {} THEN (* qTD is still active, no errors so far *)
					RETURN;
				ELSE (* At least one error occured *)
					IF s * TdHalted # {} THEN errors := errors + UsbHcdi.Stalled; END;
					IF s * TdDataBufferError # {} THEN errors := errors + UsbHcdi.Databuffer; END;
					IF s * TdBabbleDetected # {} THEN errors := errors + UsbHcdi.Babble; END;
					IF s * TdTransactionError # {} THEN errors := errors + UsbHcdi.CrcTimeout; END;
					IF s * TdMissedMicroFrame # {} THEN errors := errors + UsbHcdi.Internal; END;
					EXIT;
				END;

				IF pipe.transferLen > 0 THEN (* Data had to be transfered... *)
					(* The host controller decrements the Total Bytes To Transfer field according the amount of data it did
					transfer. If this field has not the value zero, the host controller did not transfer all data. If there is no
					error reported, this is a short packet condition, which can be okay. *)

					(* len bytes should have been transfered for this TD *)
					len := SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, SYSTEM.GET32(qtd + QtdToken)) * QtdBytesToTransfer, -16));

					IF (len # 0) THEN (* Short packet *)
						restLen := restLen + len;
					END;
				END;

				IF qtd = pipe.lastTD THEN EXIT; END; (* End of qTD chain *)

				qtd := qtd + sizeQtd;

				INC(loop);
				IF loop > MaxLoops THEN (* Endless loop protection *)
					IF Debug.Level >= Debug.Errors THEN Show("UpdateStatus: Serious error occured."); KernelLog.Ln; END;
					EXIT;
				END;
			END; (* end loop *)

			pipe.errors := errors;
			IF errors = UsbHcdi.NoErrors THEN
				IF restLen = 0 THEN
					pipe.actLen := pipe.transferLen;
					pipe.status := Usbdi.Ok;
				ELSE
					pipe.actLen := pipe.transferLen - restLen;
					pipe.status := Usbdi.ShortPacket;
					pipe.errors := pipe.errors + UsbHcdi.ShortPacket;
				END;
			ELSE
				pipe.actLen := pipe.transferLen - restLen;
				IF errors * UsbHcdi.Stalled # {} THEN
					pipe.status := Usbdi.Stalled;
				ELSE
					pipe.status := Usbdi.Error;
				END;
			END;

			Machine.InvalidateDCacheRange(pipe.qh, sizeQh);
			s := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + QhQtdToken));
			IF s * TdHalted # {} THEN
				ClearHalt(pipe);
			END;

			IF (pipe.type = UsbHcdi.PipeBulk) OR (pipe.type = UsbHcdi.PipeInterrupt) THEN
				(* If we received an ACK, do the toggle *)
				IF (pipe.status = Usbdi.Ok) OR (pipe.status = Usbdi.ShortPacket) THEN
					Machine.InvalidateDCacheRange(pipe.lastTD, sizeQtd);
					s := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.lastTD + QtdToken));
					IF s * QtdDataToggle # {} THEN  pipe.dataToggle := TRUE; ELSE pipe.dataToggle := FALSE;  END;
				END;
			END;
		END UpdatePipeStatus;

		(* Reset the host controller. Note: This will NOT assert reset on the USB downstream ports. *)
		PROCEDURE HardwareReset * () : BOOLEAN;
		CONST MaxWaits = 1000; (* Timeout in milliseconds the HC must have completed the reset command *)
		VAR dword : SET; i : LONGINT;
		BEGIN
			(* Host software mustn't reset the host controller when it's running. Stop it and ... *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			SYSTEM.PUT32(iobase + HcUsbCmd, dword - CmdRunStop); FlushPCI;
			(* ... wait until the HC is halted.*)
			i := 1; dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
			WHILE (dword * StsHcHalted = {}) & (i <= MaxWaits) DO
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
				INC(i); Wait(1);
			END;

			IF dword * StsHcHalted = {} THEN (* HC did not stop *) RETURN FALSE; END;

			(* Do the actual reset operation *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			SYSTEM.PUT32(iobase + HcUsbCmd, dword + CmdHcReset); FlushPCI;

			(* The host controller should clear the HCRESET bit when it has finished resetting *)
			FOR i := 1 TO MaxWaits DO
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
				IF dword * CmdHcReset = {} THEN
					RETURN TRUE;
				END;
				Wait(1);
			END;
			RETURN FALSE;
		END HardwareReset;

		(* HC moves to UsbSuspend state und almost all operational registers are reset.
  		Does not affect the root hub and its downstream ports *)
		PROCEDURE SoftwareReset*() : BOOLEAN;
		BEGIN
			(* TODO: Implement *)
			RETURN FALSE;
		END SoftwareReset;

		(* Initialization of the data structures of the Host Controller Communication Area *)
		PROCEDURE InitFrameList(): BOOLEAN;
		VAR fstn, i, k, j, shift : LONGINT;
		BEGIN
			(* Host controller interface data structures should not cross page-boundaries... 32 byte alignment.
			These queue heads are used as skeleton and never contain any qTDs. *)
			qhlist := UsbHcdi.GetAlignedMemSpace(2048, 4096);
			framelist := UsbHcdi.GetAlignedMemSpace(4096, 4096); (* Must be 4K aligned *)

			(* Set up QHs. 11 Interrupt QHs and the isochronousQh + fstn *)
			shift := sizeQh DIV 4; ASSERT(sizeQh MOD 4 = 0);
			FOR i := 0 TO 12 DO
				qhlist.data[qhlist.base + i*shift + (QhEpCapabilities1 DIV 4)] := 0;
				qhlist.data[qhlist.base + i*shift + (QhEpCapabilities2 DIV 4)] := 0;
				qhlist.data[qhlist.base + i*shift + (QhQtdToken DIV 4)] := 0;
				qhlist.data[qhlist.base + i*shift + (QhCurrentQtdPointer DIV 4)] := 0;
				qhlist.data[qhlist.base + i*shift + (QhNextQtdPointer DIV 4)] := 1; (* Pointer not valid *)
				qhlist.data[qhlist.base + i*shift + (QhAltNextQtdPointer DIV 4)] := 1; (* Pointer not valid *)
				FOR j := 0 TO 4 DO
					qhlist.data[qhlist.base + i*shift + (QhBufferPointer0 DIV 4) + j] := 0;
				END;
				IF cap64bit THEN
					FOR j := 0 TO 4 DO
						qhlist.data[qhlist.base + i*shift + (QhExtBufferPointer0 DIV 4) + j] := 0;
					END;
				END;
			END;

			(* Addresses of queue heads *)
			NEW(interruptQh);
			FOR i := 0 TO 10 DO interruptQh[i] := Machine.Ensure32BitAddress (ADDRESSOF(qhlist.data[qhlist.base]) + i*sizeQh); END;
			fstn := interruptQh[10] + sizeQh; (* Actually 8 bytes *)
			isochronousQh := fstn + sizeQh;

			FOR i := 10 TO 2 BY -1 DO
				SYSTEM.PUT32(interruptQh[i] + QhHorizontalLinkPointer, interruptQh[i-1] + LSH(QhTypQh, 1));
			END;

			(* Link restore indicator. InterruptQh[1] points to FSTN points to InterruptQh[0] *)
			SYSTEM.PUT32(interruptQh[1] + QhHorizontalLinkPointer, fstn + LSH(QhTypFstn, 1));
			SYSTEM.PUT32(fstn + FstnNormalPathLinkPointer, interruptQh[0] + LSH(QhTypQh, 1));
			SYSTEM.PUT32(fstn + FstnBackPathLinkPointer, QhTerminate); (* Indicates restore indicator *)

			(* Interrupt Qh for 1ms points to isochronousQh *)
			SYSTEM.PUT32(interruptQh[0] + QhHorizontalLinkPointer, isochronousQh + LSH(QhTypQh, 1));
			SYSTEM.PUT32(isochronousQh + QhHorizontalLinkPointer, QhTerminate);

			(* tree structure:
			    interrupt[0]: 1ms    interrupt[1]: 2ms    interrupt[2]: 4ms    interrupt[3]: 8ms    interrupt[4]: 16ms	    interrupt[5]: 32ms  *)

			(* => end of queue 10 points to 9, end of 8 points to 7 , ..., end of 1 points to 0 *)
			(* => if we start at queue 10, then we will pass all others too; if we start at 9 then we will pass all queues < 9, too etc.*)

			(* queue 0 executes 1024x, queue 1 executes 512x, queue 2 executes 256x,  queue 3 executes 128x*)
			(* queue 4 executes 64x, queue 5 executes 32x, queue 6 executes 16x,  queue 7 executes 8x*)
			(* queue 8 executes 4x, queue 9 executes 2x, queue 10 executes 1x *)

			(* What does the following mean? => We count the 1's (starting at lsb) until we pass a zero *)
			(* This count gives the queue number for a given slot *)

			FOR i := 0 TO 1023 DO (* i is slot number, we want to calc the queue number (k) for this slot *)
				k := 0; j := i;
				LOOP
					IF (SYSTEM.VAL(SET, j) * {0}) = {} THEN EXIT; END;
					INC(k); j := j DIV 2;
				END;
				framelist.data[framelist.base + i] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, interruptQh[k]) + {1});
				Machine.FlushDCacheRange(ADDRESSOF(framelist.data[framelist.base]), 4096);
			END;
			RETURN TRUE;
		END InitFrameList;

		(* Initializes the host controller and builds up the data structures of the HCCA.
		 * @param iobase I/O base address (virtual, pointing to capability register at offset 0)
		 * @param int Interrupt Line
		 * @return TRUE if initialization succeeded, FALSE otherwise
		 *)
		PROCEDURE Init * (iobase , irq  :  LONGINT) : BOOLEAN;
		VAR
			reg  : LONGINT;
			dword : SET; qword : HUGEINT;
			ignore : BOOLEAN;
			i : LONGINT;
		BEGIN
			IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbEhci: Starting host controller initialization..."); KernelLog.Ln; END;
		       SELF.iobase := iobase; SELF.irq := irq;
			isHighSpeed := TRUE;  DMAchaining := TRUE; sgListSize := ScatterGatherListSize;

			(* Read in the Host Controller Capability Registers *)
			(* Get and check EHCI revision *)
			reg := SYSTEM.GET16(iobase + HcCapHciVersion);
			IF reg # 0100H THEN
				KernelLog.String("UsbEhci: Revision of EHCI Programming Interface not supported."); KernelLog.Ln;
				RETURN FALSE;
			END;

			(* Get and parse the HC structural parameters register (HCSPARAM) *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcCapSparams));
			capDebugPortNumber := SYSTEM.VAL(LONGINT, LSH(dword * {20..31}, -20));
			IF dword * {16} # {} THEN capPortIndicators := TRUE; ELSE capPortIndicators := FALSE; END;
			capNbrOfCompanionHc := SYSTEM.VAL(LONGINT, LSH(dword * {12..15}, -12));
			capPortsPerCompanion := SYSTEM.VAL(LONGINT, LSH(dword * {8..11}, -8));
			IF dword * {7} # {} THEN capPortRoutingRules := TRUE; ELSE capPortRoutingRules := FALSE; END;
			IF dword * {4} # {} THEN capPortPowerControl := TRUE; ELSE capPortPowerControl := FALSE; END;
			capNbrOfPorts  := SYSTEM.VAL(LONGINT, dword * {0..3});

			(* Get and parse the HC capability parameters register (HCCPARAM) *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcCapCparams));
			capIsoSchedThreshold := SYSTEM.VAL(LONGINT, LSH(dword * {4..7}, -4));
			IF dword * {2} # {} THEN capAsynchSchedPark := TRUE; ELSE capAsynchSchedPark := FALSE; END;
			IF dword * {1} # {} THEN capProgrammableFLG := TRUE; ELSE capProgrammableFLG := FALSE; END;
			IF dword * {0} # {} THEN cap64bit := TRUE; ELSE cap64bit := FALSE; END;
			(* Get the EHCI Extended Capabilities Pointer (EECP) *)
			eecp := SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, dword) * {8..15}, - 8));

			(* Get HC companion port route description (60bits, 4bits per port *)
			IF capPortRoutingRules THEN (* HC companion port route description available *)
				qword := SYSTEM.GET32(iobase + HcCapPortroute);
				qword := qword + LSH(SYSTEM.GET32(iobase + HcCapPortroute + 4), 32);
				NEW(hcportroute, 16);
				FOR i := 0 TO 15 DO
					hcportroute[i] := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, LSH(qword, -i)) * {0..3});
				END;
			END;

			(* Build the emulated hub descriptor *)
			NEW(hubDescriptor, 8);
			hubDescriptor[0] := CHR(7);
			hubDescriptor[1] := CHR(29H); (* Hub Descriptor *)
			hubDescriptor[2] := CHR(capNbrOfPorts);
			IF capPortPowerControl THEN (* If power control is available, EHCI root hubs always provide per port power control *)
				dword := dword + {0};
			ELSE (* No power switching implemented *)
				dword := dword + {1};
			END;
			dword := dword + {3}; (* EHCI root hubs always provide per port overcurrent protection *)
			IF capPortIndicators THEN (* Port indicator control support available *) dword := dword + {7}; END;
			hubDescriptor[3] := CHR(SYSTEM.VAL(LONGINT, dword));
			hubDescriptor[4] := CHR(0); (* Reserved *)
			hubDescriptor[5] := CHR(10); (* 20ms Power on to power good *)
			hubDescriptor[6] := CHR(0); (* Root hubs don't draw current from the USB *)

			(* The Host Controller Capability Registers are readonly so we don't need further access to them and set
			iobase to the base of the Host Controller Operational Registers *)
			iobase := iobase + SYSTEM.GET8(iobase + HcCapLength);
			SELF.iobase := iobase;

			(* Calculate offset from iobase of the port status/controll register for each port *)
			portCount := capNbrOfPorts;
			NEW(ports, portCount);
			FOR i := 0 TO portCount - 1 DO ports[i] := iobase + HcPortSc + i*4; END;

			IF ~HardwareReset() THEN RETURN FALSE; END;

			(* Bluebottle does not yet support 64bit address space. Set the 4GB segment selector for the control data structures to zero. *)
			SYSTEM.PUT32(iobase + HcCtrlDsSegment, 0);

			(* Note that the control data structures must finally be 32byte aligned. Since they occupy subsequent memory location when
			associated with pipes, the value are rounded up to the next value for which value MOD 32 = 0 holds. *)
			IF cap64bit THEN
				sizeQh := 96; (* Actually: 68 Bytes *)
				sizeQtd := 64; (* Actually: 52 Bytes *)
				alignQh := 128;
				alignQtd := 64;
			ELSE
				sizeQh := 64; (* Actually: 48 Byte *)
				sizeQtd := 32;
				alignQh := 64;
				alignQtd := 32;
			END;

			IF ~InitFrameList() THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: Initialization of HCCA failed."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* If the Asynchronous Schedule Park Mode is not available or not enabled, the host controller must not
			 * execute more than one bus transaction per queue head, per traversal of the asynchronous schedule. If it
			 * is enabled, the host controller may execute Asynchronous Schedule Park Mode Count transaction if the
			 * endpoint belongs to a high-speed device. Results in better bus utilization. *)
			IF capAsynchSchedPark THEN
				ASSERT((HcAsyncParkModeCount >= 0) & (HcAsyncParkModeCount < 4));
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
				IF HcAsyncParkModeCount = 0 THEN (* Disable Asynchronous Schedule Park Mode *)
					dword := dword - CmdAsyncSchedParkMode;
				ELSE (* Enable Asynchronous Schedule Park Mode and set its count field in USBCMD *)
					dword := dword + LSH(SYSTEM.VAL(SET, HcAsyncParkModeCount), 8) * CmdAsyncSchedParkCount;
					dword := dword + CmdAsyncSchedParkMode;
				END;
				SYSTEM.PUT32(iobase + HcUsbCmd, dword);
			END;

			dword := {};
			IF capProgrammableFLG THEN (* Size of frame list can be programmed... use constant value *)
				IF Debug.Trace & Debug.traceInit THEN
					KernelLog.String("UsbEhci: Set frame list size to "); KernelLog.Int(HcFrameListSize, 0);
					KernelLog.String(" elements."); KernelLog.Ln;
				END;
				(* TODO: Programm it *)
			END;

			(* Set interrupt threshold *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			dword := dword - {16 .. 23};
			IF ((HcInterruptThreshold#01H) & (HcInterruptThreshold#02H) & (HcInterruptThreshold#04H) & (HcInterruptThreshold#08H)
			    & (HcInterruptThreshold#10H) & (HcInterruptThreshold#20H) & (HcInterruptThreshold#40H)) THEN
				(* Wrong parameter value... use default *)
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbEhci: Interrupt Threshold value invalid... using default setting."); KernelLog.Ln; END;
				dword := dword + SYSTEM.VAL(SET, LSH(08H, 16)) * {16..23};
			ELSE
				dword := dword + SYSTEM.VAL(SET, LSH(HcInterruptThreshold, 16)) *  {16..23};
			END;
			SYSTEM.PUT32(iobase + HcUsbCmd, dword); FlushPCI;

			(* Try to start the host controller *)
			IF Start() = FALSE THEN (* ERROR: Couldn't start the host controller. Controller was probably not correctly initialized. *)
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: Couldn't start host controller."); KernelLog.Ln; END;
				ignore := HardwareReset();
				RETURN FALSE;
			END;

			RETURN TRUE;
		END Init;

		(* PCI writes may be posted. A read forces posted writes to be flushed before the read transaction is proceeded. *)
		PROCEDURE FlushPCI *;
		VAR ignore : LONGINT;
		BEGIN
			ignore := SYSTEM.GET32(iobase + HcUsbSts);
		END FlushPCI;

		(* Release the HC ownership semaphore; eecp is the EHCI Extended Capability Pointer *)
		PROCEDURE ReleaseHcOwnerShip(bus, device, function, eecp : LONGINT);
		END ReleaseHcOwnerShip;

		(**
		 * Inits the ULPI PHY of the controller.
		 *)
		PROCEDURE InitUlpi(): BOOLEAN;
		BEGIN
			RETURN TRUE
		END InitUlpi;

		(*
		 * Start the host controller.
		 * This will:
		 * - enable interrupts for the host controller and install a interrupt handler
		 * - set the addresses for the periodic and asynchronous lists
		 * - turn the host controller on
		 * - route all ports to the EHCI controller
		 * - power on all ports of the root hub
	  	 *)
		PROCEDURE Start * ():BOOLEAN;
		VAR dword : SET;
		TYPE 
			IRQPoller = OBJECT (* support polling i/o IRQ -- for testing *)
				VAR handler: PROCEDURE {DELEGATE}; timer: Kernel.Timer;
				
				PROCEDURE & Init* (h: PROCEDURE {DELEGATE});
				BEGIN
					handler := h;
					NEW(timer); 
				END Init;
				
			BEGIN{ACTIVE}
				LOOP
					handler();
					timer.Sleep(1);
				END;
			END IRQPoller;
		VAR is: IRQPoller;
		BEGIN
			IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbEhci: Starting host controller... "); KernelLog.Ln; END;
			(* Enable Interrupts *)
			SetState(UsbHcdi.Initialized);
			
			IF Polling THEN
				NEW(is, InterruptHandler)
			ELSE
				Objects.InstallHandler(InterruptHandler, Machine.IRQ0+irq);
			END;

			(* Clear interrupts *)
			SYSTEM.PUT32(iobase + HcUsbSts, 0);
			
			(* Enable all interrupts except the frame list rollover interrupt *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbIntr));
			interruptsEnabled := dword + {0..5}  - StsFrameListRollover;
			SYSTEM.PUT32(iobase + HcUsbIntr, interruptsEnabled);

			(* Set Addresses for queue heads *)
			SYSTEM.PUT32(iobase + HcPeriodicListBase, ADDRESSOF(framelist.data[framelist.base]));
			SYSTEM.PUT32(iobase + HcAsyncListAddr, 0); (* Invalid address -> list empty *)

			(* Start controller *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			dword := dword + CmdRunStop;
			SYSTEM.PUT32(iobase + HcUsbCmd, dword); FlushPCI;
			SetState(UsbHcdi.Operational);

			(* Route all ports to this EHCI host controller *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcConfigFlag));
			dword := dword + {0};
			SYSTEM.PUT32(iobase + HcConfigFlag, dword); FlushPCI;

			RETURN InitUlpi();
		END Start;

		PROCEDURE &Default*(bus, device, function : LONGINT);
		BEGIN
			Default^(bus, device, function); (* The high-speed default pipe uses 64byte maxPacketSize0 *)
			pipes[0, 0, 0].maxPacketSize := 64;
		END Default;

		PROCEDURE Cleanup;
		BEGIN
			IF state >= UsbHcdi.Initialized THEN Objects.RemoveHandler(InterruptHandler, Machine.IRQ0 + irq); END;
			Cleanup^;
			IF ~HardwareReset() THEN
				IF Debug.Level >= Debug.Errors THEN Show("Host controller reset failed."); KernelLog.Ln; END;
			END;
			(* Release ownership of host controller *)
			ReleaseHcOwnerShip(bus, device, function, eecp);
			(* Unmap the HC's operational registers *)
			Machine.UnmapPhysical(iobase, 4096);
		END Cleanup;

		(** Displays the host controller's data struture on KernelLog *)
		PROCEDURE ShowSchedule*;
		CONST MaxIterations =21;
		VAR dword : SET; first, cur : LONGINT; i, ms : LONGINT;
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("Host Controller Data Structures for ");
			KernelLog.String(name);
			KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String("):"); KernelLog.Ln;
			KernelLog.String("Periodic Schedule: "); KernelLog.Ln;
			IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsPeriodicSchedule = {} THEN
				KernelLog.String("Periodic schedule is disabled."); KernelLog.Ln;
			END;

			KernelLog.String("*** Isochronous schedule: "); KernelLog.Ln;
			ShowQueueHead(isochronousQh, 0, cap64bit);
			ms := 1;
			FOR i := 0 TO 10 DO
				KernelLog.String("*** "); KernelLog.Int(ms, 0); KernelLog.String(" ms schedule:"); KernelLog.Ln;
				ShowQueueHead(interruptQh[i], 0, cap64bit);
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(interruptQh[i] + QhHorizontalLinkPointer));
				cur := 0;
				LOOP
					IF dword * QhTerminate # {} THEN EXIT; END;
					IF cur > MaxIterations THEN
						KernelLog.String("Maximum allowed iterations reached."); KernelLog.Ln;
						EXIT;
					END;
					INC(cur);

					IF i > 0 THEN
						IF SYSTEM.VAL(LONGINT, dword * {5..31}) = interruptQh[i-1] THEN
							dword := dword + QhTerminate;
						ELSE
							dword := dword * {5..31};
							IF SYSTEM.VAL(SET, SYSTEM.GET32(SYSTEM.VAL(LONGINT, dword) + QhNextQtdPointer)) * QhTerminate # {} THEN
								ShowQueueHead(SYSTEM.VAL(LONGINT, dword), 0, cap64bit);
							ELSE
								ShowQueueHead(SYSTEM.VAL(LONGINT, dword), SYSTEM.GET32(SYSTEM.VAL(LONGINT, dword) + QhNextQtdPointer), cap64bit);
							END;
							dword := SYSTEM.VAL(SET, SYSTEM.GET32(SYSTEM.VAL(LONGINT, dword) + QhHorizontalLinkPointer));
						END;
					ELSIF SYSTEM.VAL(LONGINT, dword * {5..31}) = isochronousQh THEN
						dword := dword + QhTerminate;
					ELSE
						dword := dword * {5..31};
						IF SYSTEM.VAL(SET, SYSTEM.GET32(SYSTEM.VAL(LONGINT, dword) + QhNextQtdPointer)) * QhTerminate # {} THEN
							ShowQueueHead(SYSTEM.VAL(LONGINT, dword), 0, cap64bit);
						ELSE
							ShowQueueHead(SYSTEM.VAL(LONGINT, dword), SYSTEM.GET32(SYSTEM.VAL(LONGINT, dword) + QhNextQtdPointer), cap64bit);
						END;
						dword := SYSTEM.VAL(SET, SYSTEM.GET32(SYSTEM.VAL(LONGINT, dword) + QhHorizontalLinkPointer));
					END;
				END;
				ms := ms * 2;
			END;
			KernelLog.String("*** Asynchronous list: "); KernelLog.Ln;
			IF SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts)) * StsAsyncSchedule # {} THEN
				first := SYSTEM.GET32(iobase + HcAsyncListAddr);
				IF (SYSTEM.VAL(SET, first) * {0..4} = {}) & (first # 0) THEN
					first := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, first) * {5..31});
					ShowQueueHead(first, 0, cap64bit);
					i := 0; cur := first;
					LOOP
						cur := SYSTEM.GET32(cur + QhHorizontalLinkPointer);
						IF (SYSTEM.VAL(SET, cur) * {2..4} # {}) OR (SYSTEM.VAL(SET, cur) * {1} = {}) THEN
							KernelLog.String("Error: Queue head horizontal link pointer is invalid."); KernelLog.Ln;
							EXIT;
						END;
						cur := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, cur) * {5..31});
						IF (cur = first) OR (i >= MaxIterations) THEN EXIT END;

						ShowQueueHead(cur, 0, cap64bit);
						INC(i);
					END;
					IF i >= MaxIterations THEN
						KernelLog.String("MaxIterations reached. Aborting..."); KernelLog.Ln;
					END;
				ELSE KernelLog.String("Error: Asynchronous Schedule List address is invalid.");
				END;
			ELSE KernelLog.String("Asynchronous Schedule is disabled.");
			END;
			KernelLog.Ln;
			END;
		END ShowSchedule;

		PROCEDURE ShowPipe*(pipe : UsbHcdi.Pipe);
		BEGIN
			ShowQueueHead(pipe.qh, pipe.firstTD, cap64bit);
		END ShowPipe;

		(* Show some information on this host controller on KernelLog *)
		PROCEDURE Diag;
		VAR dword : SET;
		BEGIN
			IF Debug.Trace THEN
			Diag^;
			(* Host Controller structural capabilities *)
			KernelLog.String("  HC Structural Parameters: "); KernelLog.Ln;
			KernelLog.String("    Nbr of ports: "); KernelLog.Int(capNbrOfPorts, 0);
			KernelLog.String(", Debug port: ");
			IF capDebugPortNumber # 0 THEN KernelLog.Int(capDebugPortNumber, 0); ELSE KernelLog.String("n/a"); END;
			KernelLog.Ln;
			KernelLog.String("    Per port power control: ");
			IF capPortPowerControl THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
			KernelLog.String(", Port indicator control: ");
			IF capPortIndicators THEN KernelLog.String("Available"); ELSE KernelLog.String("n/a"); END;
			KernelLog.Ln;
			KernelLog.String("    Nbr of companion HCs: "); KernelLog.Int(capNbrOfCompanionHc, 0);
			KernelLog.String(", Ports per companion: "); KernelLog.Int(capPortsPerCompanion, 0);
			KernelLog.String(", Port routing rules: ");
			IF capPortRoutingRules THEN KernelLog.String("Available"); ELSE KernelLog.String("n/a"); END;
			KernelLog.Ln;
			(* Host Controller capability parameters *)
			KernelLog.String("  HC Capablilty Parameters:"); KernelLog.Ln;
			KernelLog.String("    64bit Data Structures: "); IF cap64bit THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
			KernelLog.String(", Async Schedule Park Mode support: ");  IF capAsynchSchedPark THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
			KernelLog.Ln;
			KernelLog.String("    Programmable Frame List Size: "); IF capAsynchSchedPark THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
			KernelLog.String(", Isochronous Scheduling Threshold: "); KernelLog.Int(capIsoSchedThreshold, 0);
			KernelLog.Ln;
			(* Host Controller Command Register *)
			KernelLog.String("  HC Command Register: "); KernelLog.Ln;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			KernelLog.String("    Interrupt Threshold: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {16..23}, -16)), 0);
			KernelLog.String(", Async Schedule Park Mode: ");
			IF dword * {11} # {} THEN
				KernelLog.String("Enabled ("); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {8..9}, -8)), 0); KernelLog.Char(")");
			ELSE
				KernelLog.String("Disabled");
			END;
			KernelLog.String(", Frame List Size: ");
			CASE SYSTEM.VAL(LONGINT, LSH(dword * {2..3}, -2)) OF
			 	0: KernelLog.String("1024");
			 	|1: KernelLog.String("512");
			 	|2: KernelLog.String("256");
			 	|3: KernelLog.String("Reserved");
			 END;
			KernelLog.Ln;
			(* Host Controller Status information *)
			KernelLog.String("  HC Status Register:"); KernelLog.Ln;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbSts));
			KernelLog.String("      Asynchronous Schedule: ");
			IF dword * StsAsyncSchedule # {} THEN KernelLog.String("Enabled"); ELSE KernelLog.String("Disabled"); END;
			KernelLog.String(", Periodic Schedule: ");
			IF dword * StsPeriodicSchedule # {} THEN KernelLog.String("Enabled"); ELSE KernelLog.String("Disabled"); END;
			KernelLog.String("  ");
			IF dword * StsReclamation # {} THEN KernelLog.String("[Reclamation]"); END;
			IF dword * StsHcHalted # {} THEN KernelLog.String("[HcHalted]"); END;
			KernelLog.Ln;
			KernelLog.String("      Interrupt Status: "); ShowInterrupts(dword); KernelLog.Ln;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbIntr));
			KernelLog.String("      Interrupts Enabled: "); ShowInterrupts(dword); KernelLog.Ln;
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcUsbCmd));
			KernelLog.String("    HC operation: ");
			IF dword * {0} # {} THEN KernelLog.String("Running"); ELSE KernelLog.String("Stopped"); END;
			KernelLog.Ln;
			END;
		END Diag;

		PROCEDURE Show * (txt : ARRAY OF CHAR);
		BEGIN
			KernelLog.String("UsbEhci: "); KernelLog.String(name); KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String("): ");
			KernelLog.String(txt);
		END Show;

	END EnhancedHostController;

PROCEDURE AssertAlignment(desc: ADDRESS; alignment: SIZE);
BEGIN
	ASSERT(desc MOD alignment = 0);
END AssertAlignment;

PROCEDURE Indent(spaces : LONGINT);
VAR i : LONGINT;
BEGIN
	FOR i := 1 TO spaces DO KernelLog.Char(" "); END;
END Indent;

(*
 * Display a textual representation of a queue head data structure and its associated qTD.
 * @param qh Virtual memory address of queue head
 * @param firstQtd First qTD of this queue. If 0, the qTD chain will not be shown
 *)
PROCEDURE ShowQueueHead(qh, firstQtd : LONGINT; cap64bit : BOOLEAN);
CONST MaxChainLen = 32;
VAR
	dword : SET;
	val, chainlen : LONGINT;

	PROCEDURE ShowQhTyp(qh : LONGINT);
	BEGIN
		IF Debug.Trace THEN
		val := SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, qh) * QhTyp, -1));
		IF val = 0 THEN KernelLog.String("Isochronous Tranfers Desriptor");
		ELSIF val = 1 THEN KernelLog.String("Queue Head");
		ELSIF val = 2 THEN KernelLog.String("Split Transaction Isochronous Transfer Descriptor");
		ELSIF val = 3 THEN KernelLog.String("Frame Span Traversal Node");
		END;
		END;
	END ShowQhTyp;

BEGIN
	IF Debug.Trace THEN
	KernelLog.String("EHCI data structure at "); KernelLog.Hex(qh, 8); KernelLog.String(": ");
	ShowQhTyp(qh); KernelLog.String(" ");

	IF qh = 0 THEN KernelLog.String("Error: QH pointer = 0"); KernelLog.Ln;RETURN;
	ELSIF SYSTEM.VAL(SET, qh) * {0..4} # {} THEN KernelLog.String("Error: Not aligned"); KernelLog.Ln; RETURN;
	END;
	KernelLog.Ln;

	KernelLog.String("    Endpoint Capabilities 1: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qh + QhEpCapabilities1));
	KernelLog.String(" DeviceAddr: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * QhDeviceAddress), 0);
	KernelLog.String(", Endpoint: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhEndpointNbr, -8)), 0);
	KernelLog.String(", Speed: "); val := SYSTEM.VAL(LONGINT, LSH(dword * QhEndpointSpeed, -12));
	IF val = 0 THEN KernelLog.String("FullSpeed");
	ELSIF val = 1 THEN KernelLog.String("LowSpeed");
	ELSIF val = 2 THEN  KernelLog.String("HighSpeed");
	ELSE KernelLog.String("ERROR: Not set correctly");
	END;
	KernelLog.String(", MaxPacketSize: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhMaxPacketLen, -16)), 0);
	KernelLog.String(", NakRL: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhNakCountReload, -28)), 0);

	KernelLog.String(", Flags: ");
	IF dword * QhControlEndpointFlag # {} THEN	KernelLog.String("[ControlEp]"); END;
	IF dword * QhDataToggleControl # {} THEN KernelLog.String("[DataToggleControl]"); END;
	IF dword * QhHeadOfReclamation  # {} THEN KernelLog.String("[Head]"); END;
	IF dword * QhInactivate # {} THEN KernelLog.String("[Inactivate]"); END;
	KernelLog.Ln;

	KernelLog.String("    Endpoint Capabilities 2: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qh + QhEpCapabilities2));
	KernelLog.String("Mult: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhMultiplier, -30)), 0);
	KernelLog.String(", HubAddr: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhHubAddr, -16)), 0);
	KernelLog.String(", HubPort: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhPortNbr, -23)), 0);
	KernelLog.String(", SplitCMask: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QhSplitCMask, -8)), 0);
	KernelLog.String(", QhSMask: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * QhSMask), 0);
	KernelLog.Ln;

	KernelLog.String("    Queue Head Horizontal Link Pointer: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qh + QhHorizontalLinkPointer));
	IF dword * QhTerminate # {} THEN
		KernelLog.String("Invalid ("); KernelLog.Hex(SYSTEM.VAL(LONGINT, dword), 8); KernelLog.String("H)");
	ELSE
		KernelLog.Hex(SYSTEM.VAL(LONGINT, dword * {5..31}), 8);
		KernelLog.String(" ("); ShowQhTyp(SYSTEM.VAL(LONGINT, dword)); KernelLog.String(")");
	END;
	KernelLog.Ln;

	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qh + QhCurrentQtdPointer));
	KernelLog.String("    Current qTD Pointer: "); KernelLog.Hex(SYSTEM.VAL(LONGINT, dword), 8);
	KernelLog.String(", Next qTD Pointer: "); KernelLog.Hex(SYSTEM.GET32(qh + QhNextQtdPointer), 8);
	KernelLog.Ln;

	KernelLog.String("    Transfer overlay: "); KernelLog.Ln;
	ShowQtd(qh+16, 8, cap64bit, TRUE); KernelLog.Ln;

	IF firstQtd # 0 THEN (* show qTD chain *)
		KernelLog.String("    qTD chain:"); KernelLog.Ln;
		IF SYSTEM.VAL(SET, firstQtd) * {0..4} # {} THEN
			KernelLog.String("        qTD Pointer not 32byte aligned!"); KernelLog.Ln;
		ELSE
			chainlen := 0;
			WHILE(SYSTEM.VAL(SET, firstQtd) * QhTerminate = {}) & (chainlen < MaxChainLen) DO
				INC(chainlen);
				ShowQtd(firstQtd, 8, cap64bit, FALSE); KernelLog.Ln;
				(* Get next qTD *)
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(firstQtd + QtdNextQtdPointer));
				IF dword * {1..4} # {} THEN
					KernelLog.String("        Alignment error!"); KernelLog.Ln;
					chainlen := MaxChainLen; (* abort *)
				ELSIF dword * QhTerminate # {} THEN
					KernelLog.String("        End of Chain"); KernelLog.Ln;
					chainlen := MaxChainLen; (* abort *)
				ELSE
					firstQtd := SYSTEM.VAL(LONGINT, dword * {5..31});
				END;
			END;
		END;
	END;
	END;
END ShowQueueHead;

PROCEDURE ShowQtd(qtd, spaces : LONGINT; cap64bit, overlay : BOOLEAN);
VAR i, val : LONGINT; dword : SET;
BEGIN
	IF Debug.Trace THEN
	Indent(spaces);
	KernelLog.String("qTD at "); KernelLog.Hex(qtd, 8);  KernelLog.String(": ");

	IF SYSTEM.VAL(SET, qtd) * {0..3} # {} THEN
		(* Regular qTDs are 32byte aligned. We allow 16byte alignment for the transfer overlay area *)
		KernelLog.String("Not 16byte aligned... aborting."); KernelLog.Ln; RETURN;
	ELSIF qtd = 0 THEN
		KernelLog.String("Address = 0?"); KernelLog.Ln; RETURN;
	END;
	KernelLog.Ln;

	Indent(spaces+ 4);
	KernelLog.String("qTD Token: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qtd + QtdToken));
	KernelLog.String("Pid: ");
	val := SYSTEM.VAL(LONGINT, LSH(dword * QtdPidCode, -8));
	IF val = PidSetup THEN KernelLog.String("SETUP");
	ELSIF val = PidIn THEN KernelLog.String("IN");
	ELSIF val = PidOut THEN KernelLog.String("OUT");
	ELSE KernelLog.String("PID ERROR!");
	END;

	KernelLog.String(", DataToggle: ");
	IF dword * QtdDataToggle # {} THEN KernelLog.String("DATA1"); ELSE  KernelLog.String("DATA0"); END;

	KernelLog.String(", Bytes to transfer: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QtdBytesToTransfer, -16)), 0);
	KernelLog.String(", IOC: "); IF dword * QtdIoc # {} THEN KernelLog.String("Yes"); ELSE KernelLog.String("No"); END;
	KernelLog.String(", CERR: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QtdErrorCounter, -10)) ,0);
	KernelLog.Ln;

	Indent(spaces + 4);
	KernelLog.String("qTD Token Status: ");
	dword := dword * QtdStatus;
	IF dword * TdActive # {} THEN KernelLog.String("[Active]"); END;
	IF dword * TdHalted # {} THEN KernelLog.String("[Halted]"); END;
	IF dword * TdDataBufferError # {} THEN KernelLog.String("[DataBufferError]"); END;
	IF dword * TdBabbleDetected # {} THEN KernelLog.String("[BabbleDetected]"); END;
	IF dword * TdTransactionError # {} THEN KernelLog.String("[TransactionError]"); END;
	IF dword * TdMissedMicroFrame # {} THEN KernelLog.String("[MissedMicroFrame]"); END;
	IF dword * TdSplitTransactionState # {} THEN KernelLog.String("[SplitTransactionState]"); END;
	IF dword * TdPingState # {} THEN KernelLog.String("[PingState]"); END;
	KernelLog.Ln;

	Indent(spaces + 4); KernelLog.String("Buffer information:");KernelLog.Ln;
	Indent(spaces + 8); KernelLog.String("Current Buffer: ");
	KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * QtdCurrentPage, -12)), 0);
	IF SYSTEM.VAL(SET, qtd) * {4} # {} THEN (* Should be transfer overlay since not 32byte aligned *)
		KernelLog.String(", Nak counter: ");
		KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, SYSTEM.GET32(qtd + QtdAltNextQtdPointer)) * {1..3}, -1)), 0);
	END;
	KernelLog.Ln;
	FOR i := 0 TO 4 DO
		val := SYSTEM.GET32(qtd + QtdBufferPtr0 + i*4);
		Indent(spaces + 8);
		KernelLog.String("Buffer Pointer "); KernelLog.Int(i, 0); KernelLog.String(": "); KernelLog.Hex(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, val) * {12..31}), 8);

		val := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, val) * {0..11});
		IF i = 0 THEN
			KernelLog.String("   Current Offset: "); KernelLog.Hex(val, 8);
		ELSIF overlay & (i = 1) THEN
			KernelLog.String("   C-prog-mask: "); KernelLog.Hex(val, 8);
		ELSIF overlay & (i = 2) THEN
			KernelLog.String("   S-Bytes / Frametag: "); KernelLog.Hex(val, 8);
		END;

		KernelLog.Ln;
	END;

	IF cap64bit THEN
		FOR i := 0 TO 4 DO
			val := SYSTEM.GET32(qtd + QtdExtBufferPtr0 + i*4);
			Indent(spaces + 8);
			KernelLog.String("   ExtBufferPointer"); KernelLog.Int(i, 0); KernelLog.String(": "); KernelLog.Hex(val, 8); KernelLog.Ln;
		END;
	END;

	Indent(spaces + 4); KernelLog.String("Alternate Next qTD Pointer: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qtd + QtdAltNextQtdPointer));
	IF dword * QhTerminate # {} THEN
		KernelLog.String("Invalid ("); KernelLog.Hex(SYSTEM.VAL(LONGINT, dword), 8); KernelLog.String(")");
	ELSIF dword * {1..3} # {} THEN
		KernelLog.String("Alignment Error ("); KernelLog.Hex(SYSTEM.VAL(LONGINT, dword), 8); KernelLog.String(")");
	ELSE
		KernelLog.Hex(SYSTEM.VAL(LONGINT, dword), 8);
	END;
	KernelLog.Ln;

	Indent(spaces + 4);
	KernelLog.String("Next qTD Pointer: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(qtd + QtdNextQtdPointer));
	IF dword * QhTerminate # {} THEN
		KernelLog.String("Invalid ("); KernelLog.Hex(SYSTEM.VAL(LONGINT, dword), 8); KernelLog.String(")");
		qtd := 0;
	ELSIF dword * {1..3} # {} THEN
		KernelLog.String("Alignment Error ("); KernelLog.Hex(SYSTEM.VAL(LONGINT, dword), 8); KernelLog.String(")");
		qtd := 0;
	ELSE
		KernelLog.Hex(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, dword) * {5..31}), 8);
		qtd := SYSTEM.VAL(LONGINT, dword * {5..31});
	END;
	KernelLog.Ln;
	END;
END ShowQtd;

(*
PROCEDURE ShowItd(adr : LONGINT);
VAR dword : SET; i : LONGINT;
BEGIN
	IF Debug.Trace THEN
	KernelLog.String("UsbEhci: ITD at address "); KernelLog.Hex(adr, 8); KernelLog.Ln;
	Indent(4);
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr));
	KernelLog.String("Next Link Pointer: "); KernelLog.Hex(SYSTEM.VAL(LONGINT, dword * {5..31}), 8);
	IF dword * {0} = {} THEN KernelLog.String(" [VALID]"); ELSE KernelLog.String("[INVALID]"); END;
	KernelLog.String(", Typ: ");
	CASE SYSTEM.VAL(LONGINT, LSH(dword * {1..2}, -1)) OF
		0: KernelLog.String("iTD");
		|1 : KernelLog.String("QH");
		|2 : KernelLog.String("siTD");
		|3 : KernelLog.String("FSTN");
	END;
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + 24H));
	KernelLog.String(", Device Address: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0..6}), 0);
	KernelLog.String(", Endpoint: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {8..11}, -7)), 0);
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + 28H));
	KernelLog.String(" MaxPacket: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0..10}), 0);
	IF dword * {11} # {} THEN KernelLog.String(" [IN]"); ELSE KernelLog.String(" [OUT]"); END;
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + 2CH));
	KernelLog.String(", MULT: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0..1}), 0);
	KernelLog.Ln;
	FOR i := 0 TO 7 DO
		Indent(4);
		dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + (i+1) * 4));
		KernelLog.String("Transaction "); KernelLog.Int(i, 0); KernelLog.String(": ");
		KernelLog.String("Status: ");
		IF dword * ItdStatus # {} THEN
			IF dword * ItdActive # {} THEN KernelLog.String("[ACTIVE]"); END;
			IF dword * ItdDataBufferError # {} THEN KernelLog.String("[DataBufferError]"); END;
			IF dword * ItdBabbleDetected # {} THEN KernelLog.String("[Babble]"); END;
			IF dword * ItdTransactionError # {} THEN KernelLog.String("[TransactionError]"); END;
		ELSE
			KernelLog.String("[Done]");
		END;

		KernelLog.String(" Length: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {16..27}, -16)), 0);
		KernelLog.String(", PG: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * {12..14}, -12)), 0);
		KernelLog.String(", Offset: "); KernelLog.Int(SYSTEM.VAL(LONGINT, dword * {0..11}), 0);
		IF dword * {15} # {} THEN KernelLog.String(" [IOC]"); END;
		KernelLog.Ln;
	END;
	FOR i := 0 TO 6 DO
		Indent(4);
		dword := SYSTEM.VAL(SET, SYSTEM.GET32(adr + 24H + i*4));
		KernelLog.String("Buffer Pointer Page "); KernelLog.Int(i, 0); KernelLog.String(": ");
		KernelLog.Hex(SYSTEM.VAL(LONGINT, dword * {12..31}), 8);
		KernelLog.Ln;
	END;
	END;
END ShowItd;
*)

PROCEDURE ShowInterrupts * (s : SET);
BEGIN
	IF Debug.Trace THEN
 	IF s * StsAsyncAdvance # {} THEN KernelLog.String("[AsyncAdvance]"); END;
	IF s * StsHostSystemError # {} THEN KernelLog.String("[HostSystemError]"); END;
	IF s * StsFrameListRollover # {} THEN KernelLog.String("[FrameListRollover]"); END;
	IF s * StsPortChange # {} THEN KernelLog.String("[PortChange]"); END;
	IF s * StsUsbError # {} THEN KernelLog.String("[UsbError]"); END;
	IF s * StsUsbInterrupt # {} THEN KernelLog.String("[UsbInterrupt]"); END;
	END;
END ShowInterrupts;

(* Called when this module is unloaded. Unregister all EnhancedHostController objects *)
PROCEDURE Cleanup;
BEGIN
	UsbHcdi.UnRegisterHostControllers(Description);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END UsbEhci.

UsbEhci.Install ~  SystemTools.Free UsbEhci ~
