MODULE UsbOhci; (** AUTHOR "staubesv"; PURPOSE "USB Open Host Controller Driver" *)
(**
 *	Bluebottle USB Open Host Controller Driver
 *	Implements the UsbHcdi host controller driver interface (HCDI)
 *
 * Usage:
 *
 *	UsbOhci.Install ~ loads this device driver
 *	SystemTools.Free UsbOhci ~ unloads it
 *
 * References:
 *
 *	OpenHCI Open Host Controller Interface Specification for USB, Release 1.0a
 *
 * History:
 *
 *	01.12.2005	History started (staubesv)
 *	07.12.2005	Removed shadow registers, improved HC initialization (staubesv)
 *	15.12.2005	Moved buffer checks to UsbHcdi.Mod (staubesv)
 *	11.01.2006	Implemented H/W scatter/gather support (staubesv)
 *	16.01.2006	FlushPCI added (staubesv)
 *	25.01.2006	Make sure HCCA does not cross page boundary (staubesv)
 *	01.03.2006	Fixed critical bug in OpenHostController.CreateTDlist (staubesv)
 *	08.03.2006	LinkTDs: Allow linking TDs to a halted ED (staubesv)
 *	28.06.2006	Use KernelLog.Hex instead of UsbHcdi.PrintHex (staubesv)
 *	03.08.2006	Adapted to UsbHcdi, Unlink TDs from ED if ED halted in UpdatePipeStatus, Fixed datatoggle for control transfer > 1TD,
 *				correctly calclulate actLen in case of short packets (staubesv)
 *	11.08.2006	Cleaner handling of root hub port status register operations (staubesv)
 *	13.11.2006	UpdatePipeStatus: Set pipe.status to Usbdi.Stalled when a stall is detected (staubesv)
 *	03.07.2007	Enable bus mastering for HC if not already enabled (staubesv)
 *
 * TODOs:
 *	- isochronous transfers
 *	- deactivate tds in UnlinkTDs
 *)

IMPORT SYSTEM, KernelLog, Machine, PCI, Kernel, Objects, Modules, UsbHcdi, Usbdi, Debug := UsbDebug;

CONST

	Description = "USB Open Host Controller";

	ScatterGatherListSize = 4000;
	PageSize = 4096;

	(* Operational register offsets from io base address; OHCI Spec. 1.0 *)
	HcRevision = 0H;
	HcControl = 4H;
	HcCommandStatus = 8H;
	HcInterruptStatus = 0CH;
	HcInterruptEnable = 10H;
	HcInterruptDisable = 14H;
	HcHCCA = 18H;
	HcPeriodCurrentED = 1CH;
	HcControlHeadED = 20H;
	HcControlCurrentED = 24H;
	HcBulkHeadED = 28H;
	HcBulkCurrentED = 2CH;
	HcDoneHead = 30H;
	HcFmInterval = 34H;
	HcFmRemaining = 38H;
	HcFmNumber = 3CH;
	HcPeriodicStart = 40H;
	HcLSThreshold = 44H;
	HcRhDescriptorA = 48H;
	HcRhDescriptorB = 4CH;
	HcRhStatus = 50H;
	HcRhPortStatus1 = 54H;
	(* HcRhPortStatus[n] = n * 4 +54; *)

	(* HcRevision Register *)
	HcRevRevision = {0..7};
	HcRevLegacySupport = {8};

	(* Legacy Support Registers (only available if Bit 8 is set in the register HcRevision *)
	HceControl = 100H;
	HceInput = 104H;
	HceOutput = 108H;
	HceStatus = 10CH;

	HceControlReserved = {9..31};

	(* HcControl register *)
	HcConControlBulkServiceRatio = {0..1};
	HcConPeriodicListEnable = {2};
	HcConIsochronousEnable = {3};
	HcConControlListEnable = {4};
	HcConBulkListEnable = {5};
	HcConHcFunctionalState = {6..7};
	HcConInterruptRouting = {8};
	HcConRemoteWakeupConnected = {9};
	HcConRemoteWakeupEnable = {10};
	HcConReserved = {11..31};  (* do not alter *)

	(* HcControl HcConFunctionalState coding *)
	UsbReset = 0;
	UsbResume = 1;
	UsbOperational = 2;
	UsbSuspend = 3;

	(* HcCommandStatus register *)
	HcCmdHostControllerReset = {0};
	HcCmdControlListFilled = {1};
	HcCmdBulkListFilled = {2};
	HcCmdOwnershipChangeRequest = {3};
	HcCmdSchedulingOverrunCount = {16,17};

	(* HcInterruptStatus register *)
	HcIntSchedulingOverrun = {0};
	HcIntWriteBackDoneHead = {1};
	HcIntStartOfFrame = {2};
	HcIntResumeDetected = {3};
	HcIntUnrecoverableError = {4};
	HcIntFrameNumberOverflow = {5};
	HcIntRootHubStatusChange =  {6};
	HcIntReserved = {7..29} + {31}; (* Bit 31 has alwalys to be 0 (OHCIspec) *)
	HcIntOwnerShipChange = {30};

	(* HcInterruptEnable / HciInterruptDisable register; Write 1: set / clear; Write 0: leave unchanged *)
	IntSchedulingOverrun = {0};
	IntHcDoneHeadWriteback = {1};
	IntStartOfFrame = {2};
	IntResumeDetect = {3};
	IntUnrecoverableError = {4};
	IntFrameNumberOverflow = {5};
	IntRootHubStatusChange = {6};
	IntOwnerShipChange = {30};
	IntMasterInterruptEnable = {31};
	IntReservedMask = {7..29};

	(* HcFmInterval register (R/W) *)
	HcFmiFrameInterval = {0..13};
	HcFmiFsLargestDataPacket = {16..30};
	HcFmiFrameIntervalToggle = {31};
	HcFmiReserved = {14,15};

	(* HcPeriodicStart register (R/W) *)
	HcPerPeriodicStart = {0..13};
	HcPerReserved = {14..31};

	(* HcRhDescriptorA register (R) *)
	HcRhaNumberDownstreamPorts = {0..7};
	HcRhaNoPowerSwitching = {9};
	HcRhaPowerSwitchingMode = {8};
	HcRhaDeviceType = {10}; (* should be zero *)
	HcRhaOverCurrentProtectionMode = {11};
	HcRhaNoOverCurrentProtection = {12};
	HcRhaPowerOnToPowerGoodTime = {24..31};  (* unit of time is 2ms *)

	(* HcRhDescriptorB register (R/W)*)
	HcRhbDeviceRemovable = {1..15};
	HcRhbPortPowerControlMask = {17..31};
	HcRhbReserved = {0,16};

	(* HcRhStatus register (R/W) *)
	HcRhsLocalPowerStatus = {0};
	HcRhsOverCurrentIndicator = {1};
	HcRhsDeviceRemoteWakeupEnable = {15};
	HcRhsLocalPowerStatusChange = {16};
	HcRhsOverCurrentIndicatorChange = {17};
	HcRhsClearRemoteWakeupEnable = {31};
	HcRhsReservedMask = {2..14} + {18..30};  (* reserved bits should always be written '0' *)
	(* HcRhStatus register when written '1' *)
	HcRhsClearGlobalPower = {0};
	HcRhsSetRemoteWakeupEnable = {15};
	HcRhsSetGlobalPower = {16};

	(* Writing zeros to RhPortStatus register has no effect *)
	(* HcRhPortStatus register (R) *)
	HcPsCurrentConnectStatus = {0};
	HcPsPortEnableStatus = {1};
	HcPsPortSuspendStatus = {2};
	HcPsPortOverCurrentIndicator = {3};
	HcPsPortResetStatus = {4};
	HcPsPortPowerStatus = {8};
	HcPsLowSpeedDeviceAttached = {9};
	(* HcRhPortStatusRegister (W) *)
	HcPsClearPortEnable = {0};
	HcPsSetPortEnable = {1};
	HcPsSetPortSuspend = {2};
	HcPsClearSuspendStatus = {3};
	HcPsSetPortReset = {4};
	HcPsSetPortPower = {8};
	HcPsClearPortPower = {9};

	(* Write Clear *)
	HcPsConnectStatusChange = {16};
	HcPsPortEnableStatusChange = {17};
	HcPsSuspendStatusChange = {18};
	HcPsOverCurrentIndicatorChange = {19};
	HcPsPortResetStatusChange = {20};

	HcPsReserved = {5..7} + {10..15} + {21..31};  (* reserved bits should always be written '0' *)
	HcPsChangeMask = {16..20};

	(* Endpoint Descriptor Format (16byte structure, must be 16byte aligned) *)
	(* I use a 32 byte data structure. See below *)
	(* Offsets: *)
	EdControlStatus = 0;
	EdTailP = 4;
	EdHeadP = 8;
	EdNextEdP = 12;

	(* Dword 0 *)
	EdFunctionAddress = {0..6};
	EdEndpointNumber = {7..10};
	EdDirection = {11..12};
	EdSpeed = {13};
	EdSkip = {14};
	EdFormat = {15};
	EdMaximumPacketSize = {16..26};
	(* Dword 2 *)
	EdHalted = {0};
	EdToggleCarry = {1};

	(* Used in ED's and TD's to describe the transfers direction *)
	PidSetup = 0; (* get direction from TD *)
	PidOut = 1;
	PidIn = 2;

	(* Transfer Descriptor Format (16byte structure, must be 16byte aligned) *)
	(* Offsets: *)
	TdCommand = 0;
	TdCurrentBufferP = 4;
	TdNextTdP = 8;
	TdBufferEndP = 12;
	(* Dword 0 *)
	TdTransferSize = {0..17};  (* bluebottle specific: how many bytes should have been transfered by this TD *)
	TdBufferRounding = {18};
	TdDirectionPid = {19..20};
	TdDelayInterrupt = {21..23};
	TdDataToggle = {24};
	TdDataToggleFromTd = {25};
	TdErrorCount = {26..27};
	TdConditionCode = {28..31};
	(* Dword 1 *)
	TdCurrentBufferPointer = {0..31};
	(* Dword 2 *)
	TdNextTd = {4..31};
	(* Dword 3 *)
	TdBufferEnd = {0..31};

	(* TD Completion Codes *)
	TdNoError = 0;
	TdCrc = 1;
	TdBitStuffing = 2;
	TdDataToggleMismatch = 3;
	TdStall = 4;
	TdDeviceNotResponding = 5;
	TdPidCheckFailure = 6;
	TdUnexpectedPid = 7;
	TdDataOverrun = 8;
	TdDataUnderrun = 9;
	(* bits 10 & 11 are reserved *)
	TdBufferOverrun = 12;
	TdBufferUnderrun = 13;
	TdNotAccessed1 = 14;
	TdNotAccessed2 = 15;
	(* 1110 & 1111 : not accessed & init value *)

	(* static, disqabled endpoint descriptor to build basic data structure in the HCCA *)
	(* 3: control-,bulk- and isochronousTD;  6: interruptTD[0..5];  1: NullQueue 1: alignment   *)
	TdListSize = 3 + 6 + 1 + 1;

	(* HCCA :  hcca.data[base+offset] *)
	HccaInterruptTable = 0;
	HccaFrameNumber = 32; (* lower 16 bits *)
	HccaDoneHead = 36;

	(* how many Queue Heads should the debug procedure ShowSchedule() show... *)
	(* useful if the schedule data structure is corrupted *)
	ShowScheduleMaxQH = 1000;

	(* constants used for hc initialization *)
	HccFSLargestDataPacket =  1000*8 ; (* in bits *)
	HccFrameInterval = 2EDFH;
	HccPeriodicStart = 3E67H;

TYPE

	OpenHostController = OBJECT (UsbHcdi.Hcd)
	VAR
		(* Host Controller Communication Area (HCCA) *)
		hcca : UsbHcdi.AlignedMemSpace;

		(* host controller revision (HcRevision Register 0..7), BCD coded  *)
		revision : LONGINT;
		legacySupport : BOOLEAN;

		(* queue heads *)
		controlED : LONGINT;
		bulkED : LONGINT;
		isochronousED : LONGINT;
		interruptED : POINTER TO ARRAY 6 OF LONGINT;

		nullTD : LONGINT;

		(* this array will provide the 16byte aligned TD's for controlTD, bulkTD, isochronousTD and interruptTD[] *)
		tdlist : UsbHcdi.AlignedMemSpace;

		globalPowerSwitching : BOOLEAN;

		(** Enable power for the specified port *)
		PROCEDURE EnablePortPower*(port : LONGINT);
		BEGIN
			IF ~globalPowerSwitching THEN
				SYSTEM.PUT32(ports[port], HcPsSetPortPower);
			ELSE
				SYSTEM.PUT32(iobase + HcRhStatus, HcRhsSetGlobalPower);
			END;
			FlushPCI;
		END EnablePortPower;

		(** Disable power for the specified port *)
		PROCEDURE DisablePortPower*(port : LONGINT);
		BEGIN
			IF ~globalPowerSwitching THEN
				SYSTEM.PUT32(ports[port], HcPsClearPortPower);
			ELSE
				(* Disables power for all ports! *)
				SYSTEM.PUT32(iobase + HcRhStatus, HcRhsClearGlobalPower);
			END;
			FlushPCI;
		END DisablePortPower;

		(** Reset and enable specified port *)
		PROCEDURE ResetAndEnablePort*(port : LONGINT) : BOOLEAN;
		VAR status : SET; mtimer : Kernel.MilliTimer;
		BEGIN
			SYSTEM.PUT32(ports[port], HcPsSetPortReset); FlushPCI;
			Wait(UsbHcdi.PortResetTime); (* >= 10ms, USBspec *)
			Kernel.SetTimer(mtimer, UsbHcdi.PortEnableTimeout);
			REPEAT
				status := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			UNTIL (status * HcPsPortEnableStatus # {}) OR Kernel.Expired(mtimer);
			RETURN status * HcPsPortEnableStatus # {};
		END ResetAndEnablePort;

		(** Disables port number <port> on this root hub *)
		PROCEDURE DisablePort*(port : LONGINT);
		BEGIN
			SYSTEM.PUT32(ports[port], HcPsClearPortEnable); FlushPCI;
			SYSTEM.PUT32(ports[port], HcPsChangeMask); FlushPCI;
		END DisablePort;

		(** Get the status of the port <port> of this root hub. Registers which indicate changes are reset by GetPortStatus *)
		PROCEDURE GetPortStatus*(port : LONGINT; ack : BOOLEAN):SET;
		VAR status, s : SET;
		BEGIN
			s := SYSTEM.VAL(SET, SYSTEM.GET32(ports[port]));
			(* clear all bits that reported a change event *)
			IF ack & ((s * HcPsChangeMask) # {}) THEN SYSTEM.PUT32(ports[port], HcPsChangeMask * s); FlushPCI; END;
			status := {};
			IF s * HcPsCurrentConnectStatus # {} THEN status := status + UsbHcdi.PortStatusDevicePresent; END;
			IF s * HcPsPortEnableStatus # {} THEN status := status + UsbHcdi.PortStatusEnabled END;
			IF s * HcPsPortSuspendStatus # {} THEN status := status + UsbHcdi.PortStatusSuspended END;
			IF s * HcPsPortOverCurrentIndicator # {} THEN status := status + UsbHcdi.PortStatusOverCurrent END;
			IF s * HcPsPortResetStatus # {} THEN status := status + UsbHcdi.PortStatusReset END;
			IF s * HcPsPortPowerStatus # {} THEN status := status + UsbHcdi.PortStatusPowered END;
			IF s * HcPsConnectStatusChange # {} THEN status := status + UsbHcdi.PortStatusConnectChange END;
			IF s * HcPsPortEnableStatusChange # {} THEN status := status + UsbHcdi.PortStatusEnabledChange END;
			IF s * HcPsSuspendStatusChange # {} THEN status := status + UsbHcdi.PortStatusSuspendChange END;
			IF s * HcPsOverCurrentIndicatorChange # {} THEN status := status + UsbHcdi.PortStatusOverCurrentChange END;
			IF s * HcPsPortResetStatusChange # {} THEN status := status + UsbHcdi.PortStatusResetChange END;
			IF s * HcPsLowSpeedDeviceAttached # {} THEN
				status := status + UsbHcdi.PortStatusLowSpeed;
			ELSE
				status := status + UsbHcdi.PortStatusFullSpeed;
			END;
			RETURN status;
		END GetPortStatus;

		(* Returns the current frame number; the frame number is incremented by the Host Controller at the end of each frame time *)
		PROCEDURE GetFrameNumber*() : INTEGER;
		BEGIN
			RETURN SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET, hcca.data[hcca.base + HccaFrameNumber]) * {0..15});
		END GetFrameNumber;

		(* Build and then insert the endpoint descriptor of the pipe into the host controller schedule *)
		PROCEDURE InsertQH*(pipe : UsbHcdi.Pipe) : BOOLEAN;
		VAR nextED : LONGINT; dword : SET;
		BEGIN (* only call from exclusive regions *)
			ASSERT((pipe#NIL) & (pipe.qh#0) & (SYSTEM.VAL(SET, pipe.qh) * {0..3} = {})); (* 16byte alignment *)
			ASSERT((pipe.maxPacketSize > 0));
			CASE pipe.type OF (* in which queue should we insert the pipe ? *)
				| UsbHcdi.PipeControl : pipe.queue := controlED;
				| UsbHcdi.PipeBulk : pipe.queue := bulkED;
				| UsbHcdi.PipeIsochronous : pipe.queue := isochronousED;
				| UsbHcdi.PipeInterrupt :
					BEGIN
						IF pipe.irqInterval = 1 THEN (* 1ms queue *)
							pipe.queue := interruptED[0];
						ELSIF pipe.irqInterval < 4 THEN (* 2ms queue *)
							pipe.queue := interruptED[1];
						ELSIF pipe.irqInterval < 8 THEN (* 4ms queue *)
							pipe.queue := interruptED[2];
						ELSIF pipe.irqInterval < 16 THEN (* 8ms queue *)
							pipe.queue := interruptED[3];
						ELSIF pipe.irqInterval < 32 THEN (* 16ms queue *)
							pipe.queue := interruptED[4];
						ELSE
							pipe.queue := interruptED[5]; (* 32 ms queue *)
						END;
					END;
			ELSE
				RETURN FALSE;
			END;

			(* build the pipe's endpoint descriptor *)
			(* dword0:  0..6: function address; 7..10: endpoint number; 11..12: direction; 13: Speed; 14: Skip; 15: Format; 16..26: maximum packet size; 27..31: available *)
			dword := SYSTEM.VAL(SET, pipe.address) * EdFunctionAddress + (SYSTEM.VAL(SET, LSH(pipe.endpoint, 7)) * EdEndpointNumber);
			IF pipe.type = UsbHcdi.PipeControl THEN (* get direction from TD *)
				(* bit 11&12 both zero *)
			ELSE (* get direction from ED *)
				IF pipe.direction = UsbHcdi.In THEN
					INCL(dword, 12); (* PidIn *)
				ELSIF pipe.direction = UsbHcdi.Out THEN
					INCL(dword, 11); (* PidOut *)
				ELSE
					HALT(90);
				END;
			END;

			IF pipe.speed = UsbHcdi.LowSpeed THEN dword := dword + EdSpeed; END;
			IF pipe.type = UsbHcdi.PipeIsochronous THEN dword := dword + EdFormat; END;
			dword := dword + (SYSTEM.VAL(SET, LSH(pipe.maxPacketSize, 16)) * EdMaximumPacketSize);
			dword := dword + EdSkip; (* HC should not (yet) process this ED *)

			SYSTEM.PUT32(pipe.qh + EdControlStatus, dword);
			(* dword1: 0..3: available; 4..31: TailP *)
			SYSTEM.PUT32(pipe.qh + EdTailP , nullTD);
			(* dword2: 0: halted; 1: dataToggle; 2..3: 00; 4..31: HeadP *)
			SYSTEM.PUT32(pipe.qh + EdHeadP , nullTD);
			(* dword3: NextED pointer (Physical Address!!) *)
			nextED := SYSTEM.GET32(pipe.queue + EdNextEdP);  (* get NextED field of the queue; nextED contains physical address *)
			SYSTEM.PUT32(pipe.qh + EdNextEdP, SYSTEM.VAL(SET, nextED) * {4..31});
			SYSTEM.PUT32(pipe.queue + EdNextEdP, pipe.qh);
			RETURN TRUE;
		END InsertQH;

		(* Delete the queue head <qh> in the queue <queue> *)
		PROCEDURE RemoveQH*(pipe : UsbHcdi.Pipe);
		VAR prev, temp : LONGINT; dword : SET;
		BEGIN (* caller must hold obj lock *)
			(* REMEMBER: The Host Controller is concurrently accessing dword1-3 of the ED's *)
			(* set EdSkip flag (HC shall not process the ED) *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh)) + EdSkip;
			SYSTEM.PUT32(pipe.qh, dword);

			(* search to ED that points to the ED of the pipe *)
			prev := pipe.queue;
			LOOP
				temp := SYSTEM.GET32(prev + EdNextEdP);
				IF (temp = pipe.qh) OR (temp = 0) THEN EXIT; END;
				prev := temp;
				ASSERT(SYSTEM.VAL(SET, prev) * {0..3} = {});
			END;

			IF temp = 0 THEN
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbOhci: DeleteQH: Pipe not found."); KernelLog.Ln; END;
				RETURN;
			END;

			(* remove pipe.qh from EDList *)
			SYSTEM.PUT32(prev + EdNextEdP, SYSTEM.GET32(pipe.qh + EdNextEdP));

			(* the ED is not any more in the EDList, but it is possible the HC is processing the ED right now... *)
			(* We disable the list processing for the list that contained the deleted ED *)
			CASE pipe.type OF
				| UsbHcdi.PipeControl:
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcControl)) - HcConControlListEnable;
					SYSTEM.PUT32(iobase + HcControl, dword); FlushPCI;
					temp := SYSTEM.GET32(iobase + HcControlCurrentED);
					IF temp = pipe.qh THEN (* deleted ED currently in process... update *)
						SYSTEM.PUT32(iobase + HcControlCurrentED, 0); FlushPCI;
					END;
					(* re-enable list processing of the control list *)
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcControl)) + HcConControlListEnable;
					SYSTEM.PUT32(iobase + HcControl, dword); FlushPCI;
				| UsbHcdi.PipeBulk :
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcControl)) - HcConBulkListEnable;
					SYSTEM.PUT32(iobase + HcControl, dword); FlushPCI;
					temp := SYSTEM.GET32(iobase + HcBulkCurrentED);
					IF temp = pipe.qh THEN (* deleted ED currently in process... update *)
						SYSTEM.PUT32(iobase + HcBulkCurrentED, 0); FlushPCI;
					END;
					(* re-enable list processing of the control list *)
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcControl))+HcConBulkListEnable;
					SYSTEM.PUT32(iobase + HcControl, dword); FlushPCI;
			ELSE
			END;
		END RemoveQH;

		(** Checks whether TDs may be linked to the pipe's QH *)
		PROCEDURE LinkTDsAllowed*(pipe : UsbHcdi.Pipe) : BOOLEAN;
		VAR headP, tailP : SET;
		BEGIN {EXCLUSIVE}
			headP := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdHeadP)) * {4..31};
			tailP := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdTailP)) * {4..31};
			IF headP # tailP THEN (* There are TDs linked to this ED *)
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.LinkTDsFailed;
				RETURN FALSE;
			ELSE
				RETURN TRUE;
			END;
		END LinkTDsAllowed;

		(* Insert the TD list <td> into the queue (ED) <queue> *)
		PROCEDURE LinkTDs*(pipe : UsbHcdi.Pipe;  td : LONGINT);
		VAR dword : SET;
		BEGIN {EXCLUSIVE}
			(* endpoint should not be processed by the HC ... *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdControlStatus)) + EdSkip;
			SYSTEM.PUT32(pipe.qh + EdControlStatus, dword);

			(* inserts the tdlist <td> into the queue *)
			SYSTEM.PUT32(pipe.qh + EdTailP, nullTD); (* TailP ::= pointer to td *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdHeadP)); (* we need to preserve the lower 4 bits *)
			SYSTEM.PUT32(pipe.qh + EdHeadP, SYSTEM.VAL(SET, td) * {4..31} + dword * {1..3}); (* HeadPointer :: = td; Clear Halt bit if set *)

			(* enable pipe *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdControlStatus));
			SYSTEM.PUT32(pipe.qh + EdControlStatus, dword - EdSkip);

			IF pipe.type = UsbHcdi.PipeControl THEN (* Set ControlListFilled Bit... bits written 0 remain unchanged *)
				SYSTEM.PUT32(iobase + HcCommandStatus, HcCmdControlListFilled);
			ELSIF pipe.type = UsbHcdi.PipeBulk THEN (* Set BulkListFilled Bit... bits written 0 remain unchanged *)
				SYSTEM.PUT32(iobase + HcCommandStatus, HcCmdBulkListFilled);
			END;
			FlushPCI;
		END LinkTDs;

		(** Remove all transfer descriptors from the pipe's endpoint descriptor *)
		PROCEDURE UnlinkTDs*(pipe : UsbHcdi.Pipe);
		VAR dword : SET;
		BEGIN {EXCLUSIVE}
			IF pipe.firstTD = 0 THEN RETURN END; (* pipe has not yet been used *)
			(* disable processing for this endpoint descriptor *)
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdControlStatus));
			SYSTEM.PUT32(pipe.qh + EdControlStatus, dword + EdSkip);
			(* remove TD list *)
			SYSTEM.PUT32(pipe.qh+ EdTailP, nullTD); (* TailP ::= pointer to td *)
			SYSTEM.PUT32(pipe.qh + EdHeadP, nullTD); (* HeadPointer :: = td *)
		END UnlinkTDs;

		(* Clears the EdHalted bit in the Endpoint descriptor and sets the EdSkip bit to prevent processing by the HC *)
		PROCEDURE ClearHalt*(pipe : UsbHcdi.Pipe);
		VAR dword : SET; temp : SET;
		BEGIN
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdHeadP));
			IF dword * EdHalted # {} THEN
				temp := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdControlStatus));
				temp := temp + EdSkip;
				SYSTEM.PUT32(pipe.qh + EdControlStatus, temp);
				dword := dword - EdHalted - EdToggleCarry;
				SYSTEM.PUT32(pipe.qh + EdHeadP, dword);
			ELSE
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbOhci: ClearHalt: Pipe is not halted."); KernelLog.Ln; END;
			END;
		END ClearHalt;

		PROCEDURE ScheduleControl*(pipe : UsbHcdi.Pipe; direction : LONGINT; msg : UsbHcdi.ControlMessage;  bufferLen : LONGINT; VAR buffer : Usbdi.Buffer);
		VAR ranges : ARRAY ScatterGatherListSize OF Machine.Range; 	td, numRanges : LONGINT; dword : SET;
		BEGIN
			(* control transfers use a three stage protocol:
			 *	stage1: control setup transaction
			 *	stage2: optional data stage
			 *	stage3: status transaction         *)
			pipe.firstTD := pipe.tdBase; td := pipe.tdBase;

			(* stage1: control setup transaction: build the setup TD *)
			(* dword0: no IOC; EdDirection = EdPidSetup; DataToggle in TDs; DataToggle = Data0; ErrorCount = 0; CC = not accessed *)
			SYSTEM.PUT32(td + TdCommand, TdDelayInterrupt + TdDataToggleFromTd + {29,30,31});
			SYSTEM.PUT32(td + TdNextTdP, td + 16);

			Machine.TranslateVirtual(ADDRESSOF(msg[0]), 8, numRanges, ranges);
			IF numRanges = 0 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbOhci: Scatter/Gather list too small."); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := UsbHcdi.TransferTooLarge; RETURN;
			END;

			SYSTEM.PUT32(td + TdCurrentBufferP, ranges[0].adr);
			IF numRanges = 1 THEN
				SYSTEM.PUT32(td + TdBufferEndP, ranges[0].adr + 8 - 1);
			ELSE
				SYSTEM.PUT32(td + TdBufferEndP, ranges[1].adr + ranges[1].size - 1);
			END;
			ASSERT(SYSTEM.GET32(td + TdBufferEndP) - SYSTEM.GET32(td + TdCurrentBufferP) + 1 = 8); (* 8 byte control message *)


			(* setup phase always starts with dataToggle = FALSE, so now it must be TRUE *)
			pipe.dataToggle := TRUE;

			(* stage 2: (optional) data stage *)
			IF bufferLen # 0 THEN
				IF ~CreateTDList(pipe, direction, bufferLen, 0, buffer, td + 16, td, TRUE) THEN
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbOhci: Scatter/Gather list too small."); KernelLog.Ln; END;
					pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.TransferTooLarge; RETURN;
				END;
			END;

			td := td + 16;
			IF td + 15 > ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1]) THEN
				IF Debug.Level >= Debug.Errors  THEN KernelLog.String("UsbOhci: TD buffer too small"); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.OutOfTDs; RETURN;
			END;

			(* stage 3: status: build status TD *)
			dword := TdDataToggle + TdDataToggleFromTd + {29,30,31}; (* dataToggle always TRUE and set ind TD in status stage; CC = not accessed *)

			IF (direction = UsbHcdi.Out) OR (bufferLen = 0) THEN
				INCL(dword, 20); (* PidIn *)
			ELSE
				INCL(dword, 19); (* PidOut *)
			END;

			IF pipe.ioc THEN (* enable interrupt on completion for this TD *)
				(* okay, but ...  optimization possible : DelayInterrupt  *)
			ELSE
				dword := dword + TdDelayInterrupt; (* no IOC *)
			END;

			SYSTEM.PUT32(td + TdCommand, dword);
			SYSTEM.PUT32(td + TdCurrentBufferP, 0); (* no data *)
			SYSTEM.PUT32(td + TdNextTdP, nullTD);
			SYSTEM.PUT32(td + TdBufferEndP, 0);
			pipe.lastTD := td;
		END ScheduleControl;

		PROCEDURE Schedule*(pipe : UsbHcdi.Pipe; bufferLen, offset: LONGINT; VAR buffer: Usbdi.Buffer);
		VAR dword : SET;
		BEGIN
			pipe.firstTD :=  pipe.tdBase;

			IF ~CreateTDList(pipe, pipe.direction, bufferLen, offset, buffer, pipe.firstTD, pipe.lastTD, FALSE) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbOhci: Scatter/Gather list too small."); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := pipe.errors + UsbHcdi.TransferTooLarge; RETURN;
			END;

			SYSTEM.PUT32(pipe.lastTD + TdNextTdP, nullTD);
			IF pipe.ioc THEN
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.lastTD + TdCommand));
				dword := dword - TdDelayInterrupt; (* Enable IOC by delaying interrupts for zero frames *)
				SYSTEM.PUT32(pipe.lastTD + TdCommand, dword);
			END;
		END Schedule;

		PROCEDURE CreateTDList(pipe : UsbHcdi.Pipe; direction, len, ofs : LONGINT; VAR buffer : Usbdi.Buffer; firstTD : LONGINT; VAR lastTD : LONGINT; tdToggle : BOOLEAN) : BOOLEAN;
		VAR
			restlen, curlen : LONGINT;
			numRanges, idx, offset : LONGINT;
			td, temp : LONGINT;
			dword : SET;
		BEGIN
			Machine.TranslateVirtual(ADDRESSOF(buffer[ofs]), len, numRanges, pipe.sgList^);
			IF numRanges = 0 THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbOhci: Scatter/Gather list too small."); KernelLog.Ln; END;
				pipe.status := Usbdi.Error; pipe.errors := UsbHcdi.TransferTooLarge; RETURN FALSE;
			END;

			td := firstTD - 16;
			restlen := len; idx := 0; offset := 0;

			WHILE restlen > 0 DO (* build TD chain *)

				td := td + 16;
				IF td + 15 > ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1]) THEN
					pipe.errors := pipe.errors + UsbHcdi.OutOfTDs;
					IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbOhci: TD buffer too small"); KernelLog.Ln; END;
					RETURN FALSE;
				END;

				(* Each TD can have at maximum 8KB buffer space. The buffer must be virtually contiguous. The buffer may, however, 		*)
				(* spawn across one page boundary. When the HC detects a page crossing, it will use the 20 msb bits of the TdBufferEndP  	*)
				(* pointer to get the next page frame number. 																			*)

				(* dword1: current buffer pointer *)
				SYSTEM.PUT32(td + TdCurrentBufferP, pipe.sgList[idx].adr + offset); (* Adding offset is okay since adr is page aligned or offset is zero *)

				curlen := PageSize - LONGINT ((pipe.sgList[idx].adr + offset) MOD PageSize);
				IF curlen >= restlen THEN (* no page crossing, last TD in chain *)
					curlen := restlen; restlen := 0;
					SYSTEM.PUT32(td + TdBufferEndP, pipe.sgList[idx].adr + offset + curlen - 1);
				ELSE (* Page crossing; will still have room for 4096 Bytes in this TD *)
					restlen := restlen - curlen; offset := 0; INC(idx);
					ASSERT(idx < numRanges);
					(* The special thing here is, that, curlen must be a multiple of pipe.maxPacketSize if this is not the last TD in the chain. 	*)
					(* Otherwise we would ask/sent for less data than device exspects to send/receive. 									*)
					temp := PageSize - ((curlen + PageSize) MOD pipe.maxPacketSize); (* max amount of data that fits into second buffer *)
					IF restlen > temp THEN (* Not last TD *)
						(* There will be more TDs. *)
						curlen := curlen + temp; offset := temp; restlen := restlen - temp;
						SYSTEM.PUT32(td + TdBufferEndP, pipe.sgList[idx].adr + temp - 1);
						IF offset = PageSize THEN INC(idx); offset := 0;
						ELSE (* Same page (idx) will be filled in first buffer pointer of next TD in chain *)
						END;
					ELSE (* Last TD in chain *)
						curlen := curlen + restlen;
						SYSTEM.PUT32(td + TdBufferEndP, pipe.sgList[idx].adr + restlen - 1);
						restlen := 0;
					END;
				END;
				ASSERT(curlen <= 8192);

				SYSTEM.PUT32(td + TdNextTdP, td + 16);

				dword := {29,30,31} + TdDelayInterrupt + TdBufferRounding ; (* CC = not accessed; no IOC *)
				dword := dword + SYSTEM.VAL(SET, curlen) * TdTransferSize;

				IF tdToggle THEN
					dword := dword + TdDataToggleFromTd;
					IF pipe.dataToggle THEN dword := dword + TdDataToggle; END;

					(* Calculate datatoggle value for next TD *)
					IF (curlen DIV pipe.maxPacketSize) MOD 2 # 0 THEN
						pipe.dataToggle := ~pipe.dataToggle;
					END;
				END;

				IF direction = UsbHcdi.In THEN
					INCL(dword, 20);
				ELSIF direction = UsbHcdi.Out THEN
					INCL(dword, 19);
				END;

				SYSTEM.PUT32(td + TdCommand, dword);
			END;
			lastTD := td;
			RETURN TRUE;
		END CreateTDList;

		PROCEDURE InterruptHandler;
		VAR s : SET;
		BEGIN (* works without being exclusive *)
			IF Debug.Stats THEN INC(NnofInterrupts); END;
			IF state >= UsbHcdi.Initialized THEN
				s := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcInterruptStatus));
				IF s # {} THEN
					IF Debug.Stats THEN INC(NnofInterruptsHandled); END;
					(* Reset interrupt status register *)
					SYSTEM.PUT32(iobase + HcInterruptStatus, s - HcIntReserved); FlushPCI;

					IF s * HcIntSchedulingOverrun # {} THEN  KernelLog.String("UsbOhci: HcIntSchedulingOverrun"); KernelLog.Ln; END;
					IF s * HcIntResumeDetected # {} THEN KernelLog.String("UsbOhci: HcIntResumeDetected"); KernelLog.Ln; END;
					IF s * HcIntUnrecoverableError # {} THEN KernelLog.String("UsbOhci: HcIntUnrecoverableError"); KernelLog.Ln; END;
					IF s * HcIntFrameNumberOverflow # {} THEN (* KernelLog.String("UsbOhci: HcIntFrameNumberOverflow");  KernelLog.Ln; *)END;
					IF s * HcIntRootHubStatusChange # {} THEN
						IF statusChangeHandler # NIL THEN statusChangeHandler(0, 0); END;
					END;
					IF s * HcIntOwnerShipChange # {} THEN KernelLog.String("UsbOhci: HcIntOwnerShipChange"); KernelLog.Ln; END;
					IF s * HcIntWriteBackDoneHead # {} THEN
						NotifyCompletionHandlers;
					END;
				END;
			END;
		END InterruptHandler;

		(* re-evaluate the status of the pipe's qh (endpoint descriptor) and its TD list *)
		PROCEDURE UpdatePipeStatus*(pipe : UsbHcdi.Pipe);
		CONST
			MaxLoops = 10000;
		VAR
			tailP, headP : SET;
			td : LONGINT;
			currentBufferP, bufferEndP : LONGINT;
			dword, errors : SET;
			cc : LONGINT;
			actLen, len : LONGINT;
			loop : LONGINT;
		BEGIN
			IF SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdControlStatus)) * EdSkip # {} THEN RETURN; END;
			tailP := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdTailP));
			headP := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdHeadP));

			IF headP * EdHalted # {} THEN (* some error occured when processing this TD list ... *)

				td := pipe.firstTD; loop := 0; actLen := 0; errors := UsbHcdi.NoErrors;
				LOOP
					ASSERT(SYSTEM.VAL(SET, td) * {0..3} = {});
					(* evaluate condition codes (CC)*)
					dword := SYSTEM.VAL(SET, SYSTEM.GET32(td + TdCommand));
					cc := LSH(SYSTEM.VAL(LONGINT, dword * TdConditionCode), -28);
					CASE cc OF
						| TdNoError : (* only Usbdi.ResOK if all TD's do not have errors *)
						| TdCrc : errors := errors + UsbHcdi.Crc;
						| TdBitStuffing : errors := errors + UsbHcdi.BitStuff;
						| TdDataToggleMismatch : errors :=  errors + UsbHcdi.DataToggleMismatch;
						| TdStall : errors := errors + UsbHcdi.Stalled;
						| TdDeviceNotResponding : errors := errors + UsbHcdi.DeviceNotResponding;
						| TdPidCheckFailure : errors := errors + UsbHcdi.PidCheckFailure;
						| TdUnexpectedPid :	errors := errors + UsbHcdi.UnexpectedPid;
						| TdDataOverrun : errors :=  errors + UsbHcdi.Babble;
						| TdDataUnderrun : errors := errors + UsbHcdi.ShortPacket;
						| TdBufferOverrun : errors := errors + UsbHcdi.Databuffer;
						| TdBufferUnderrun : errors := errors + UsbHcdi.Databuffer;
					ELSE
						(* there's something wrong ... either the TD has not been accessed (which is not possible since the information in the ED) *)
						errors := errors + UsbHcdi.Internal;
					END;

					IF pipe.transferLen > 0 THEN (* data had to be transfered... *)

						(* len bytes should have been transfered for this TD *)
						len := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, SYSTEM.GET32(td + TdCommand)) * TdTransferSize);

						currentBufferP := SYSTEM.GET32(td + TdCurrentBufferP);

						IF currentBufferP = 0 THEN (* all bytes transfered *)
							actLen := actLen + len;
						ELSE (* short packet *)
							bufferEndP := SYSTEM.GET32(td + TdBufferEndP);
							actLen := actLen + len - (bufferEndP - currentBufferP + 1);
							errors := errors + UsbHcdi.ShortPacket;
						END;
					END;

					IF errors - UsbHcdi.ShortPacket # {} THEN EXIT; END;
					IF td = pipe.lastTD THEN EXIT; END;

					td := td + 16;
					IF loop > MaxLoops THEN EXIT; END;
					INC(loop);
				END; (* end loop *)

				pipe.actLen := actLen; pipe.errors := errors;
				IF errors = UsbHcdi.NoErrors THEN
					pipe.status := Usbdi.Ok;
				ELSIF errors = UsbHcdi.ShortPacket THEN
					pipe.status := Usbdi.ShortPacket;
				ELSE
					IF errors * UsbHcdi.Stalled # {} THEN
						pipe.status := Usbdi.Stalled;
					ELSE
						pipe.status := Usbdi.Error;
					END;
				END;

				dword := SYSTEM.VAL(SET, SYSTEM.GET32(pipe.qh + EdControlStatus));
				SYSTEM.PUT32(pipe.qh + EdControlStatus, dword + EdSkip);
				(* Unlink TDs from ED *)
				SYSTEM.PUT32(pipe.qh+ EdTailP, nullTD);
				SYSTEM.PUT32(pipe.qh + EdHeadP, nullTD);

			ELSIF (headP * {4..31} = tailP * {4..31}) THEN	(* no errors occured *)
				pipe.actLen := pipe.transferLen;
				pipe.status := Usbdi.Ok;
				pipe.errors := errors;
			ELSE (* TD still active *)
				(* do nothing *)
			END;
		END UpdatePipeStatus;

		(* Set HC functional state to UsbReset. This causes the root hub and its downstream port to be reset and possible powered off (the latter) *)
		PROCEDURE HardwareReset() : BOOLEAN;
		VAR timer : Kernel.Timer;
		BEGIN
			SYSTEM.PUT32(iobase + HcControl, LSH(UsbReset, 6));	 FlushPCI;
			NEW(timer); timer.Sleep(UsbHcdi.RootHubResetTime);
			RETURN TRUE;
		END HardwareReset;

		(* HC moves to UsbSuspend state und almost all operational registers are reset.
  		 * Does not affect the root hub and its downstream ports *)
		PROCEDURE SoftwareReset() : BOOLEAN;
		VAR millitimer : Kernel.MilliTimer; dword : SET;
		BEGIN
			SYSTEM.PUT32(iobase + HcCommandStatus, HcCmdHostControllerReset); FlushPCI;
			Kernel.SetTimer(millitimer, 10);
			LOOP (* OpenHCI Spec.: Controller must clear this bit within 10 microseconds. We allow 10ms  *)
				dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcCommandStatus));
				IF (HcCmdHostControllerReset * dword = {}) OR Kernel.Expired(millitimer) THEN EXIT END;
			END;
			RETURN HcCmdHostControllerReset * dword = {};
		END SoftwareReset;

		(* initialization of the data structures of the Host Controller Communication Area; Only useb by Init(...) *)
		PROCEDURE InitHcca(): BOOLEAN;
		VAR i, k, j : LONGINT;
		BEGIN
			(* HCCA needs to be 256-byte aligned *)
			hcca := UsbHcdi.GetAlignedMemSpace(256, 4096);  (* May not cross page boundary *)

			(* okay... now allocate memory for the 16byte aligned queue heads ... *)
			tdlist := UsbHcdi.GetAlignedMemSpace(16*TdListSize, 16);

			NEW(interruptED); FOR i := 0 TO 5 DO interruptED[i] := Machine.Ensure32BitAddress (ADDRESSOF(tdlist.data[tdlist.base]) + i*16); END;

			isochronousED := interruptED[5] + 16;
			controlED :=  isochronousED + 16;
			bulkED := controlED +16;

			(* if the HeadP and the TailP pointers of a ED both points to nullQueue, there are no TDs in that ED TD list *)
			nullTD := bulkED + 16;

			(* set the Skip Flags, HeadP and TailP fields of all 66 ED's (63 interrupt + bulk + control + iso) *)
			FOR i := 0 TO 8 DO
				tdlist.data[tdlist.base + i*4 + (EdControlStatus DIV 4)] := SYSTEM.VAL(LONGINT, EdSkip);
				tdlist.data[tdlist.base + i*4 + (EdTailP DIV 4)] := nullTD;
				tdlist.data[tdlist.base + i*4 + (EdHeadP DIV 4)] := nullTD;
				tdlist.data[tdlist.base + i*4 + (EdNextEdP DIV 4)] := 0;
			END;

			(* tree structure:
			    The host controller uses the lower 5 bits of the framenumber as index into an 32 entry head pointer table in the HCCA.
			    We want them to point to 32 interrupt endpoint descriptors. These are schedule all 32ms.

			    interrupt[0]: 1ms
			    interrupt[1]: 2ms
			    interrupt[2]: 4ms
			    interrupt[3]: 8ms
			    interrupt[4]: 16ms
			    interrupt[5]: 32ms
			  *)

			FOR i := 5 TO 1 BY -1 DO
				SYSTEM.PUT32(interruptED[i] + EdNextEdP, interruptED[i-1]);
			END;

			(* interrupt TD for 1ms points to isochronousTD *)
			SYSTEM.PUT32(interruptED[0] + EdNextEdP, isochronousED);

			FOR i := 0 TO 31 DO (* i is slot number, we want to calc the queue number (k) for this slot *)
				k := 0; j := i;
				LOOP (* k: counts '1' in j from the lsb until the first '0' *)
					IF (SYSTEM.VAL(SET, j) * {0}) = {} THEN EXIT; END;
					INC(k); j := j DIV 2;
				END;
				hcca.data[hcca.base + i] := interruptED[k];
			END;

			RETURN TRUE;
		END InitHcca;

		(* Initializes the host controller and builds up the  data structures of the HCCA *)
		PROCEDURE Init(virtualbase,  IRQ :  LONGINT) : BOOLEAN;
		CONST MaxOwnershipChangeRequests = 100;
		VAR
			dword, hcRhDescriptorA, hcRhDescriptorB, Reg_HcFmInterval : SET;
			timer : Kernel.Timer;
			periodicStart : LONGINT;
			hcControl, temp, i : LONGINT;
			ignore : BOOLEAN;
		BEGIN
			IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Starting host controller initialization..."); KernelLog.Ln; END;
			iobase := virtualbase; irq := IRQ;
			DMAchaining := TRUE; sgListSize := ScatterGatherListSize;

			(* get revision of the open host controller : Bit 0..7 of the HcRevision register *)
			temp := SYSTEM.GET32(iobase + HcRevision);
			revision:= SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp) * HcRevRevision);
			IF revision #10H THEN
				KernelLog.String("UsbOhci: Revision of OHCI Programming Interface not supported."); KernelLog.Ln;
				RETURN FALSE;
			END;

			(* check whether the controller does have legacy support registers : Bit 8 of HcRevision register  *)
			IF SYSTEM.VAL(SET, temp) * HcRevLegacySupport # {} THEN
				legacySupport := TRUE;
			END;

			(* save contents from HcFmInterval register ... *)
			Reg_HcFmInterval := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcFmInterval));

			(* Host controller already in use by other instances (SMM/BIOS driver) ?  *)
			hcControl := SYSTEM.GET32(iobase + HcControl);

			IF (SYSTEM.VAL(SET, hcControl) * HcConInterruptRouting) # {}  THEN (* Interrupts routed to SMI -> SMM driver active *)
				IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Host Controller initialization: SMM driver found"); KernelLog.Ln; END;
				SYSTEM.PUT32(iobase + HcCommandStatus, HcCmdOwnershipChangeRequest); FlushPCI;
				NEW(timer);
				(* the SMM driver should clear the OwnershipChangeRequest bit *)
				i := 0;
				LOOP
					temp := SYSTEM.GET32(iobase + HcControl);
					IF SYSTEM.VAL(SET, temp) * HcConInterruptRouting = {} THEN EXIT; END;
					INC(i);
					IF i > MaxOwnershipChangeRequests THEN EXIT; END;
					timer.Sleep(1);
				END;
				hcControl := temp;
				(* OwnerShipChange successful ? *)
				IF SYSTEM.VAL(SET, temp) * HcConInterruptRouting # {} THEN
					IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Host Controller initialization: SMM driver did not response to OwnerShipChangeRequest."); KernelLog.Ln; END;
				ELSE
					IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Host Controller initialization: OwnerShipChangeRequest succeeded."); KernelLog.Ln; END;
				END;
			ELSIF SYSTEM.VAL(SET, hcControl) * HcConHcFunctionalState # {} THEN (* USB state not UsbReset -> BIOS driver active *)
				IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Controller initialization: BIOS driver found"); KernelLog.Ln; END;
			ELSE (* neither SMM driver nor BIOS driver were active -> cold start *)
				IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Controller initialization: Cold start..."); KernelLog.Ln; END;
			END;

			IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Host Controller Initialization: USB Reset."); KernelLog.Ln; END;
			IF ~HardwareReset() THEN RETURN FALSE; END;

			(* Resets most registers. After a software reset, the HC is in mode UsbSuspend.  *)
			IF ~SoftwareReset() THEN RETURN FALSE; END;

			(* restore contents of HcFmInterval register ... *)
			SYSTEM.PUT32(iobase + HcFmInterval, Reg_HcFmInterval);

			(* 	According to the OHCIspec, restoring the contents of HcFmInterval should be enough. Nevertheless,
				check its contents to be sure it really works *)
			IF (Reg_HcFmInterval * HcFmiFrameInterval = {}) OR (Reg_HcFmInterval * HcFmiFsLargestDataPacket = {}) THEN
				IF Debug.Trace & Debug.traceInit THEN
					KernelLog.String("UsbOhci: HcFmInterval values invalid. Set to defaults."); KernelLog.Ln;
				END;
				IF (Reg_HcFmInterval *  HcFmiFrameInterval = {}) THEN (* set to default *)
					Reg_HcFmInterval := Reg_HcFmInterval + (SYSTEM.VAL(SET, HccFrameInterval) * HcFmiFrameInterval);
				END;
				IF  (Reg_HcFmInterval * HcFmiFsLargestDataPacket = {}) THEN (* set to default *)
					Reg_HcFmInterval := Reg_HcFmInterval + (LSH(SYSTEM.VAL(SET, HccFSLargestDataPacket), 16) * HcFmiFsLargestDataPacket);
				END;
			END;

			(* tell the HC that we updated the field *)
			IF (Reg_HcFmInterval *  HcFmiFrameIntervalToggle = {}) THEN
				Reg_HcFmInterval := Reg_HcFmInterval + HcFmiFrameIntervalToggle;
			ELSE
				Reg_HcFmInterval := Reg_HcFmInterval - HcFmiFrameIntervalToggle;
			END;

			SYSTEM.PUT32(iobase + HcFmInterval, Reg_HcFmInterval);

			IF legacySupport THEN
				(* diable legacy emulation if enabled *)
				temp := SYSTEM.GET32(iobase + HceControl);
				IF SYSTEM.VAL(SET, temp) * {0} # {} THEN
					(* disable legacy emulation *)
					SYSTEM.PUT32(iobase + HceControl, SYSTEM.VAL(SET, temp) * HceControlReserved); FlushPCI;
					IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Disabled legacy emulation."); KernelLog.Ln; END;
				END;
			ELSE
				legacySupport := FALSE;
			END;

			(* determine the number of ports the root hub provides *)
			hcRhDescriptorA := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcRhDescriptorA));

			portCount := SYSTEM.VAL(LONGINT, hcRhDescriptorA * HcRhaNumberDownstreamPorts);
			IF (portCount < 1) OR (portCount > 15) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbOhci: Host Controller Initialization failed (port count error)."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			NEW(ports, portCount);
			(* Calculate offset from iobase of the port status/controll register for each port *)
			FOR i := 0 TO portCount-1 DO ports[ i ] := iobase + HcRhPortStatus1 + i*4; END;

			(* Build the emulated hub descriptor *)
			NEW(hubDescriptor, 8);
			hubDescriptor[0] := CHR(7);
			hubDescriptor[1] := CHR(29H); (* Hub Descriptor *)
			hubDescriptor[2] := CHR(portCount);

			IF hcRhDescriptorA * HcRhaNoPowerSwitching # {} THEN (* Power switchting not supported *)
				dword := dword + {1};
			ELSIF hcRhDescriptorA * HcRhaPowerSwitchingMode # {} THEN (* Per port power switching *)
				dword := dword + {0};
				hcRhDescriptorB := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcRhDescriptorB)); (* preserve reserved bits ... *)
				hcRhDescriptorB := hcRhDescriptorB + HcRhbPortPowerControlMask;
				SYSTEM.PUT32(iobase + HcRhDescriptorB, hcRhDescriptorB - HcRhbDeviceRemovable); FlushPCI;
			ELSE (* Ganged power switching *)
				globalPowerSwitching := TRUE;
			END;

			IF hcRhDescriptorA * HcRhaNoOverCurrentProtection # {} THEN (* Overcurrent protection not supported *)
				dword := dword + {4};
			ELSIF hcRhDescriptorA * HcRhaOverCurrentProtectionMode # {} THEN (* Per port overcurrent protection *)
				dword := dword + {3};
			ELSE (* Global overcurrent protection *)
				(* do nothing *)
			END;
			hubDescriptor[3] := CHR(SYSTEM.VAL(LONGINT, dword));
			hubDescriptor[4] := CHR(0); (* Reserved *)
			hubDescriptor[5] := CHR(SYSTEM.VAL(LONGINT, LSH(hcRhDescriptorA * HcRhaPowerOnToPowerGoodTime, -24)));
			hubDescriptor[6] := CHR(0); (* Root hubs don't draw current from the USB *)

			(* HC now in UsbSuspend state... if we do not change the HC functional state to UsbOperational within 2ms, we need to go into UsbResume... *)

			IF ~InitHcca() THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbOhci: Initialization of HCCA failed."); KernelLog.Ln; END;
				RETURN FALSE;
			END;

			(* try to start the host controller *)
			IF Start() = FALSE THEN (* ERROR: Couldn't start the host controller. Controller was probably not correctly initialized. *)
				ignore := SoftwareReset(); KernelLog.String("UsbOhci: Couldn't start host controller."); KernelLog.Ln; RETURN FALSE;
			END;

			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcFmInterval));
			IF (dword # Reg_HcFmInterval) THEN (* quirk: Some HCs need to be in the state operational for this change to be effective *)
				SYSTEM.PUT32(iobase + HcFmInterval, Reg_HcFmInterval);
			END;

			(* Set HcPeriodicStart to a value that is 90% of the value in FrameInterval field of the HcFmInterval register *)
			periodicStart := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, Reg_HcFmInterval) * HcFmiFrameInterval);
			periodicStart := (periodicStart * 9) DIV 10;

			dword := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcPeriodicStart)); (* we need to preserve reserved bits... *)
			dword := dword - HcPerPeriodicStart + (SYSTEM.VAL(SET, periodicStart) * HcPerPeriodicStart);
			SYSTEM.PUT32(iobase + HcPeriodicStart, dword);

			RETURN TRUE;
		END Init;

		(* Resets and then starts the host controller. As soon as the host controller is started, it processes the schedule *)
		PROCEDURE Start():BOOLEAN;
		VAR dword : SET;
		BEGIN
			IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Starting host controller..."); END;
			(* set base address of the HCCA *)
			SYSTEM.PUT32(iobase + HcHCCA, ADDRESSOF(hcca.data[hcca.base]));

			(* set the bulk list and the control list  head pointers *)
			SYSTEM.PUT32(iobase + HcControlHeadED,  controlED);
			SYSTEM.PUT32(iobase + HcBulkHeadED,  bulkED);
			SYSTEM.PUT32(iobase + HcControlCurrentED,  0);
			SYSTEM.PUT32(iobase + HcBulkCurrentED,  0);
			FlushPCI;

			SetState(UsbHcdi.Initialized);
			Objects.InstallHandler(InterruptHandler, Machine.IRQ0+irq);
			(* enable all interrupts *)
			dword := IntMasterInterruptEnable + IntHcDoneHeadWriteback + IntFrameNumberOverflow + IntUnrecoverableError + IntOwnerShipChange + IntRootHubStatusChange;
			SYSTEM.PUT32(iobase + HcInterruptEnable, dword); FlushPCI;

			(* Set HcControl Register: Start the controller by set the hc functional state to UsbOperational *)
			(* ControlBulkServiceRatio = 1:1 (Bit0&Bit1: 00); Enable List Processing; UsbOperational (Bit 7) *)
			dword := HcConPeriodicListEnable (*+ HcConIsochronousEnable *) +  HcConControlListEnable + HcConBulkListEnable + {7};
			SYSTEM.PUT32(iobase + HcControl, dword); FlushPCI;

			SetState(UsbHcdi.Operational);
			IF Debug.Trace & Debug.traceInit THEN KernelLog.String("done."); KernelLog.Ln; END;
			RETURN TRUE;
		END Start;

		(* PCI writes may be posted. A read forces posted writes to be flushed before the read transaction is proceeded. *)
		PROCEDURE FlushPCI;
		VAR ignore : LONGINT;
		BEGIN
			ignore := SYSTEM.GET32(iobase + HcControl)
		END FlushPCI;

		PROCEDURE Cleanup;
		BEGIN
			IF state >= UsbHcdi.Initialized THEN Objects.RemoveHandler(InterruptHandler, Machine.IRQ0 + irq);END;
			Cleanup^;
			IF ~HardwareReset() THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbOhci: Host controller reset failed."); KernelLog.Ln; END;
			END;
			IF ~SoftwareReset() THEN
				IF Debug.Level >= Debug.Errors  THEN KernelLog.String("UsbOhci: Software reset failed.");  KernelLog.Ln; END;
			END;
			(* Unmap the HC's operational registers *)
			Machine.UnmapPhysical(iobase, 4096);
		END Cleanup;

		(** Displays the host controller's data struture on KernelLog *)
		PROCEDURE ShowSchedule*;
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("Host Controller Data Structures for ");
			KernelLog.String(name); KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String("):"); KernelLog.Ln;
			HumanSchedule(SELF);
			END;
		END ShowSchedule;

		PROCEDURE ShowPipe*(pipe : UsbHcdi.Pipe);
		BEGIN
			HumanED(pipe.qh, SELF, 4, FALSE, FALSE);
			HumanTD(pipe.firstTD, pipe.lastTD, nullTD, 8);
		END ShowPipe;

		(* for debugging: display diagnostics of this host controller to KernelLog *)
		PROCEDURE Diag*;
		VAR s : SET; temp : LONGINT;
		BEGIN
			IF Debug.Trace THEN
			Diag^;
			(* display information of the HcRevision register *)
			temp := SYSTEM.GET32(iobase+HcRevision);
			KernelLog.String("   HcRevision: ");
			KernelLog.Hex(SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, temp) * {4..7}, -4)), -2); KernelLog.String(".");
			KernelLog.Hex(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, temp) * {0..3}), -2);
			KernelLog.String("   Legacy support: ");
			IF HcRevLegacySupport * SYSTEM.VAL(SET, temp) # {}  THEN
				KernelLog.String("Yes");
				KernelLog.String(" [HceControl: "); temp := SYSTEM.GET32(iobase+HceControl); KernelLog.Hex(temp, 8); KernelLog.String("H]");
				KernelLog.String(" [HceStatus: "); temp := SYSTEM.GET32(iobase+HceStatus); KernelLog.Hex(temp, 8); KernelLog.String("H]");
				KernelLog.String(" [HceInput: "); temp := SYSTEM.GET32(iobase+HceInput); KernelLog.Hex(temp, 8); KernelLog.String("H]");
				KernelLog.String(" [HceOutput: "); temp := SYSTEM.GET32(iobase+HceOutput); KernelLog.Hex(temp, 8); KernelLog.String("H]");
			ELSE
				KernelLog.String("No");
			END;
			KernelLog.Ln;
			(* display information of the HcControl register *)
			KernelLog.String("   HcControl: State: ");
			temp := SYSTEM.GET32(iobase + HcControl);
			s := SYSTEM.VAL(SET, temp);
			CASE SYSTEM.VAL(LONGINT, LSH(s*HcConHcFunctionalState, -6)) OF
				UsbReset : KernelLog.String("UsbReset");
				| UsbResume : KernelLog.String("UsbResume");
				| UsbOperational : KernelLog.String("UsbOperational");
				| UsbSuspend : KernelLog.String("UsbSuspend");
			ELSE
				KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(s*HcConHcFunctionalState,-6)),0);
			END;
			KernelLog.String(" C/B-Ratio: ");
			temp := SYSTEM.VAL(LONGINT, s * HcConControlBulkServiceRatio);
			KernelLog.Int(temp, 0); KernelLog.String(": 1,");
			KernelLog.String(" Flags: ");
			IF s * HcConPeriodicListEnable # {} THEN KernelLog.String(" [PeriodicListEnabled]"); END;
			IF s * HcConControlListEnable # {} THEN KernelLog.String(" [ControlListEnabled]"); END;
			IF s * HcConBulkListEnable # {} THEN KernelLog.String(" [BulkListEnabled]"); END;
			IF s * HcConIsochronousEnable # {} THEN KernelLog.String(" [IsochronousEnabled]"); END;
			IF s * HcConInterruptRouting # {} THEN KernelLog.String(" [InterruptRouting]"); END;
			IF s * HcConRemoteWakeupConnected # {} THEN KernelLog.String(" [RemoteWakeupConnected]"); END;
			IF s * HcConRemoteWakeupEnable # {} THEN KernelLog.String(" [RemoteWakeupEnabled]"); END;
			KernelLog.Ln;
			(* display information from HcCommandStatus register *)
			KernelLog.String("   HcCommandStatus: SchedulingOverrungCount: ");
			 KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(s * HcCmdSchedulingOverrunCount,16)), 0);
			KernelLog.String(", Flags: ");
			temp := SYSTEM.GET32(iobase + HcCommandStatus);
			s := SYSTEM.VAL(SET, temp);
			IF s * HcCmdHostControllerReset # {}  THEN KernelLog.String("[Reset]"); END;
			IF s * HcCmdControlListFilled # {} THEN KernelLog.String("[ControlListFilled]"); END;
			IF s * HcCmdBulkListFilled # {} THEN KernelLog.String("[BulkListFilled]"); END;
			IF s * HcCmdOwnershipChangeRequest # {} THEN KernelLog.String("[OwnerShipRequest]"); END;
			KernelLog.Ln;
			(* HcInterruptEnable register *)
			temp := SYSTEM.GET32(iobase + HcInterruptEnable);
			s := SYSTEM.VAL(SET, temp);
			KernelLog.String("   Interrupts Enabled: ");
			IF s * IntMasterInterruptEnable # {} THEN KernelLog.String("[MasterInterrupt]"); END;
			IF s * IntSchedulingOverrun # {} THEN KernelLog.String("[SchedulingOverflow]"); END;
			IF s * IntHcDoneHeadWriteback # {} THEN KernelLog.String("[WBDoneHead]"); END;
			IF s * IntStartOfFrame # {} THEN KernelLog.String("[SOF]"); END;
			IF s * IntResumeDetect # {} THEN KernelLog.String("[ResumeDetect]"); END;
			IF s * IntUnrecoverableError # {} THEN KernelLog.String("[Error]"); END;
			IF s * IntFrameNumberOverflow # {} THEN KernelLog.String("[FmOverflow]"); END;
			IF s * IntRootHubStatusChange # {} THEN KernelLog.String("[RHStatusChange]"); END;
			IF s * IntOwnerShipChange # {} THEN KernelLog.String("[OwnerShipChange]"); END;
			KernelLog.Ln;
			(* display information from HcInterruptStatus register *)
			temp := SYSTEM.GET32(iobase + HcInterruptStatus);
			s := SYSTEM.VAL(SET, temp);
			KernelLog.String("   HcInterruptStatus: ");
			IF s # {} THEN
				IF s * HcIntSchedulingOverrun # {} THEN KernelLog.String("[SchedulingOverrun]"); END;
				IF s * HcIntWriteBackDoneHead # {} THEN KernelLog.String("[WriteBackDoneHead]"); END;
				IF s * HcIntStartOfFrame # {} THEN KernelLog.String("[StartOfFrame]"); END;
				IF s * HcIntResumeDetected # {} THEN KernelLog.String("[ResumeDetected]"); END;
				IF s * HcIntUnrecoverableError # {} THEN KernelLog.String("[UnrecoverableError]"); END;
				IF s * HcIntFrameNumberOverflow # {} THEN KernelLog.String("[FrameNumberOverflow]"); END;
				IF s * HcIntRootHubStatusChange # {} THEN KernelLog.String("[RooHubStatusChange]"); END;
				IF s * HcIntOwnerShipChange # {} THEN KernelLog.String("[IntOwnerShipChange]"); END;
			ELSE
				KernelLog.String(" [ok]");
			END;
			KernelLog.Ln;
			(* display current framenumber *)
			temp := SYSTEM.GET32(iobase + HcFmNumber);
			KernelLog.String("   Frame: Nbr: "); KernelLog.Hex(temp, 8);
			s := SYSTEM.VAL(SET, SYSTEM.GET32(iobase + HcFmInterval));
			KernelLog.String("  FmInterval: "); KernelLog.Int(SYSTEM.VAL(LONGINT, s * HcFmiFrameInterval), 0);
			KernelLog.String("  FSMaxPacketSize: "); KernelLog.Int(LSH(SYSTEM.VAL(LONGINT, s * HcFmiFsLargestDataPacket),-16), 0); KernelLog.String(" Bits, ");
			KernelLog.String("  FmiToggle: ");
			IF s * HcFmiFrameIntervalToggle # {} THEN KernelLog.String("Set"); ELSE KernelLog.String("Not Set"); END;
			temp := SYSTEM.GET32(iobase + HcPeriodicStart); KernelLog.String(" PeriodicStart: "); KernelLog.Hex(temp, 8);
			temp := SYSTEM.GET32(iobase + HcPeriodCurrentED); KernelLog.String(" PeriodicCurrentED: "); KernelLog.Hex(temp, 8);
			KernelLog.Ln;
			(* display list head addresses *)
			temp := SYSTEM.GET32(iobase + HcControlHeadED); KernelLog.String("   ControlHeadED: "); KernelLog.Hex(temp, 8);
			temp := SYSTEM.GET32(iobase + HcControlCurrentED); KernelLog.String("  CurrentControlED: "); KernelLog.Hex(temp, 8);
			temp := SYSTEM.GET32(iobase + HcBulkHeadED); KernelLog.String("  BulkHeadED: "); KernelLog.Hex(temp, 8);
			temp := SYSTEM.GET32(iobase + HcBulkCurrentED); KernelLog.String("  CurrentBulkED: "); KernelLog.Hex(temp, 8);
			KernelLog.Ln;
			END;
		END Diag;

	END OpenHostController;

VAR
	qhCounter : LONGINT; (* used by HumanQH; only for debug puposes *)

(* debug: displays the information in the queue head qh and all TD's in that queue
 * ed : virtual address if first ED in EDList  *)
PROCEDURE HumanSchedule(controller : OpenHostController);
BEGIN
	IF Debug.Trace THEN
	HumanED(controller.interruptED[5], controller, 4, TRUE, TRUE);
	HumanED(controller.bulkED, controller, 4, TRUE, TRUE);
	HumanED(controller.controlED, controller, 4, TRUE, TRUE);
	(* reset qhCounter *)
	qhCounter := 0;
	END;
END HumanSchedule;

PROCEDURE Indent(spaces : LONGINT);
VAR i : LONGINT;
BEGIN
	FOR i := 1 TO spaces DO KernelLog.Char(" "); END;
END Indent;

(* Displays endpoint descriptor information to the kernel log; addr : Physical Address!! *)
PROCEDURE HumanED(ed : LONGINT; controller : OpenHostController; spaces : LONGINT; showTds, showEds : BOOLEAN);
VAR dword : SET; adr, ep : LONGINT; pipe : UsbHcdi.Pipe;
BEGIN
	IF Debug.Trace THEN
	(* to avoid endless loops because of (wrong) circular data structures *)
	IF qhCounter > ShowScheduleMaxQH THEN
		KernelLog.String("UsbOhci: HumanED: UsbOhci.ShowScheduleMaxQH showed... aborting."); KernelLog.Ln;
		RETURN;
	ELSE
		INC(qhCounter);
	END;
	ed := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ed) * {4..31});
	dword :=SYSTEM.VAL(SET, SYSTEM.GET32(ed + EdControlStatus));
	adr := SYSTEM.VAL(LONGINT, dword * EdFunctionAddress);
	ep := SYSTEM.VAL(LONGINT, LSH(dword * EdEndpointNumber, -7));

	Indent(spaces); KernelLog.String("ED at address: "); KernelLog.Hex(ed, 8); KernelLog.String("H ");
	IF ed = controller.controlED THEN KernelLog.String("(ControlList Head)");
	ELSIF ed = controller.bulkED THEN KernelLog.String("(BulkList Head)");
	ELSIF ed = controller.isochronousED THEN KernelLog.String("(IsochronousList Head)");
	ELSIF ed = controller.interruptED[0] THEN KernelLog.String("(1ms Interrupt Head)");
	ELSIF ed = controller.interruptED[1] THEN KernelLog.String("(2ms Interrupt Head)");
	ELSIF ed = controller.interruptED[2] THEN KernelLog.String("(4ms Interrupt Head)");
	ELSIF ed = controller.interruptED[3] THEN KernelLog.String("(8ms Interrupt Head)");
	ELSIF ed = controller.interruptED[4] THEN KernelLog.String("(16ms Interrupt Head)");
	ELSIF ed = controller.interruptED[5] THEN KernelLog.String("(32ms Interrupt Head)");
	ELSE
		KernelLog.String("(USB Pipe)");
	END;
	KernelLog.Ln;

	(* Display information from EdControlStatus field *)
	Indent(spaces+4);
	KernelLog.String("Adr: "); KernelLog.Int(adr, 0); KernelLog.String(" Ep: "); KernelLog.Int(ep, 0);
	IF pipe # NIL THEN
		KernelLog.String(" Type: ");
		CASE pipe.type OF
			UsbHcdi.PipeControl : KernelLog.String("Control");
			| UsbHcdi.PipeBulk : KernelLog.String("Bulk");
			| UsbHcdi.PipeIsochronous : KernelLog.String("Isochronous");
			| UsbHcdi.PipeInterrupt : KernelLog.String("Interrupt");
		ELSE
			KernelLog.String("UNKNOWN!!!");
		END;
	END;
	KernelLog.String(" Dir: ");
	CASE SYSTEM.VAL(LONGINT, LSH(dword * EdDirection ,-11)) OF
		  PidIn : KernelLog.String("In");
		| PidOut : KernelLog.String("Out");
	ELSE
		KernelLog.String("Specified in TD");
	END;
	KernelLog.String(" MaxPacketSize: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * EdMaximumPacketSize, -16)), 0); KernelLog.String(" Bytes");
	IF pipe # NIL THEN
		KernelLog.String(", LastStatus: "); UsbHcdi.ShowStatus(pipe.status);
	END;
	KernelLog.String(", Flags: ");
	IF EdSkip * dword # {} THEN KernelLog.String("[Skip]"); END;
	IF EdSpeed * dword # {}  THEN KernelLog.String("[LowSpeed]"); ELSE KernelLog.String("[FullSpeed]"); END;
	IF EdFormat * dword # {} THEN KernelLog.String("[Isochronous]"); END;

	dword := SYSTEM.VAL(SET, SYSTEM.GET32(ed + EdHeadP));
	IF EdHalted * dword # {} THEN KernelLog.String("[Halted]"); END;
	IF EdToggleCarry * dword # {} THEN KernelLog.String("[Toggle=DATA1]"); ELSE KernelLog.String("[Toggle=DATA0]"); END;
	KernelLog.Ln;

	Indent(spaces+4); KernelLog.String("HeadP: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(ed + EdHeadP)) * {4..31};
	IF SYSTEM.VAL(LONGINT, dword) = controller.nullTD THEN
		KernelLog.String("NullTD");
	ELSE
		KernelLog.Hex(SYSTEM.VAL(LONGINT, dword * {4..31}), 8); KernelLog.String("H");
	END;
	KernelLog.String(", TailP: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(ed + EdTailP));
	IF SYSTEM.VAL(LONGINT, dword) = controller.nullTD THEN
		KernelLog.String("NullTD");
	ELSE
		KernelLog.Hex(SYSTEM.VAL(LONGINT, dword * {4..31}), 8); KernelLog.String("H");
	END;
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(ed + EdNextEdP));
	KernelLog.String(", NextED: ");
	IF dword = {} THEN
		KernelLog.String("None");
	ELSE
		KernelLog.Hex(SYSTEM.VAL(LONGINT, dword * {4..31}), 8); KernelLog.String("H");
	END;
	KernelLog.Ln;
	(* Show TD list of this endpoint descriptor *)
	Indent(spaces+4); KernelLog.String("TDList: ");
	dword := SYSTEM.VAL(SET, SYSTEM.GET32(ed + EdHeadP)) * {4..31};
	IF SYSTEM.VAL(SET, SYSTEM.GET32(ed + EdTailP)) * {4..31} = dword THEN (* HeadP == TailP *)
		KernelLog.String("Empty");  KernelLog.Ln;
	ELSE (* There are TD's in the list ... show TD list. *)
		KernelLog.String("Non_Empty - First TD at "); KernelLog.Hex(SYSTEM.VAL(LONGINT, dword * {4..31}), 8); KernelLog.Char("H"); KernelLog.Ln; KernelLog.Ln;
		IF showTds THEN
			KernelLog.Ln; HumanTD(SYSTEM.VAL(LONGINT, dword * {4..31}), 0, controller.nullTD, spaces + 4); KernelLog.Ln;
		END;
	END;
	(* Show next endpoint descriptor in list *)
	IF showEds THEN
		dword := SYSTEM.VAL(SET, SYSTEM.GET32(ed + EdNextEdP)) * {4..31}; (* get NextED field *)
		IF dword # {} THEN
			HumanED(SYSTEM.VAL(LONGINT, dword), controller, 4, showTds, showEds);
		END;
	END;
	END;
END HumanED;

(* debug: displays the information of the  Transfer Descriptor nexttd and all linked TD's and displays it *)
(* nextd : Physical Address !!! *)
PROCEDURE HumanTD(nexttd, lasttd, nulltd: LONGINT; spaces : LONGINT);
CONST MaxTDListLength = 200;
VAR val, val2 : LONGINT; dword : SET; iteration : LONGINT;
BEGIN
	IF Debug.Trace THEN
	iteration := 1;
	LOOP
		IF iteration > MaxTDListLength THEN (* for the case that addresses are misinterpreted ... *)
			Indent(spaces); KernelLog.String("UsbOhci.HumandTD.MaxTDListLength reached... aborting.");
			EXIT;
		END;
		Indent(spaces); KernelLog.String("TD at address: "); KernelLog.Hex(nexttd, 8); KernelLog.String("H"); KernelLog.Ln;

		IF SYSTEM.VAL(SET, nexttd) * {0..3} # {} THEN
			Indent(spaces); KernelLog.String("Error: not 16byte aligned!!");
			EXIT;
		ELSIF nexttd = 0 THEN
			Indent(spaces); KernelLog.String("Error: Address = 0 !!!"); KernelLog.Ln;
			EXIT;
		ELSE
			(* TD Completion Codes *)
			Indent(spaces+4); KernelLog.String("Condition Codes:");
			dword := SYSTEM.VAL(SET, SYSTEM.GET32(nexttd + TdCommand));
			CASE SYSTEM.VAL(LONGINT, LSH(dword,-28)) OF
				| TdNoError : KernelLog.String("[NoError]");
				| TdCrc : KernelLog.String("[CRC]");
				| TdBitStuffing : KernelLog.String("[BitStuffError]");
				| TdDataToggleMismatch : KernelLog.String("[DataToggleMismatch]");
				| TdStall : KernelLog.String("[STALL]");
				| TdDeviceNotResponding : KernelLog.String("[DeviceNotResponding]");
				| TdPidCheckFailure : KernelLog.String("[PidCheckFailure]");
				| TdUnexpectedPid : KernelLog.String("[UnexpectedPid]");
				| TdDataOverrun : KernelLog.String("[DataOverrun]");
				| TdDataUnderrun : KernelLog.String("[DataUnderrun]");
				| TdBufferOverrun : KernelLog.String("[BufferOverrun]");
				| TdBufferUnderrun : KernelLog.String("[BufferUnderrun]");
				| 14..15: KernelLog.String("[NotAccessed]");
			ELSE
				KernelLog.String("[ConditionCodesNotValid]");
			END;
			KernelLog.Ln;

			Indent(spaces+4); KernelLog.String("Pid: ");
			CASE SYSTEM.VAL(LONGINT, LSH(dword * TdDirectionPid, -19)) OF
				PidSetup : KernelLog.String("PidSetup");
				| PidIn : KernelLog.String("PidIn");
				| PidOut : KernelLog.String("PidOut");
				| 3 : KernelLog.String("Reserved");
			ELSE
				KernelLog.String("Invalid");
			END;

			KernelLog.String(", Flags: ");
			IF dword * TdBufferRounding # {} THEN KernelLog.String("[BufferRounding]"); END;
			IF 25 IN dword THEN KernelLog.String("[ToggleFromTD]"); ELSE KernelLog.String("[ToggleFromEd]"); END;
			IF 24 IN dword THEN KernelLog.String("[Toggle=DATA1]"); ELSE KernelLog.String("[Toggle=DATA0]"); END;
			IF SYSTEM.VAL(LONGINT, LSH(dword * TdDelayInterrupt, -21)) # 7 THEN (* IOC enabled *)
				KernelLog.String("[IOC, MaxDelay: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * TdDelayInterrupt, -21)), 0); KernelLog.Char("]");
			END;
			KernelLog.String(", Errors: "); KernelLog.Int(SYSTEM.VAL(LONGINT, LSH(dword * TdErrorCount, -26)), 0);
			KernelLog.Ln;

			(* CurrentBufferPointer, BufferEndPointer & NextTD *)
			Indent(spaces+4); KernelLog.String("CurBufferP: ");
			val := SYSTEM.GET32(nexttd + TdCurrentBufferP); KernelLog.Hex(val, 8); KernelLog.String("H");
			KernelLog.String(", BufferEnd: ");
			val2 := SYSTEM.GET32(nexttd + TdBufferEndP); KernelLog.Hex(val2, 8); KernelLog.String("H");
			KernelLog.String(" (");
			IF val = 0 THEN KernelLog.String("0");
			ELSE KernelLog.Int(val2 - val + 1, 0);
			END;
			KernelLog.String(" Bytes)");

			val := SYSTEM.GET32(nexttd + TdNextTdP);
			KernelLog.String(", NextTD: ");
			IF val = nulltd THEN KernelLog.String("NullTD");
			ELSE KernelLog.Hex(val, 8); KernelLog.String("H");
			END;
			KernelLog.Ln;

			IF SYSTEM.GET32(nexttd + TdNextTdP) = nulltd THEN
				Indent(spaces); KernelLog.String("NullTD (EOL)"); KernelLog.Ln; EXIT;
			ELSIF nexttd = lasttd THEN
				Indent(spaces); KernelLog.String("Pipe.lastTD (EOL)"); KernelLog.Ln; EXIT;
			ELSIF nexttd = 0 THEN
				Indent(spaces); KernelLog.String("nexttd adr is zero"); KernelLog.Ln; EXIT;
			END;
			KernelLog.Ln;
			nexttd := nexttd + 16;
			INC(iteration);
		END;
	END;
	END;
END HumanTD;

(* Find UHCI controllers on the PCI bus, create correspondig UCHIcontroller object and register them in the UHCI USB host controllers registry;
	called by FindControllers *)
PROCEDURE PCIFindOhci;
CONST
	OhciClassCode = 0C0310H;
	PCIStatusErrorMask = {24,27,28,29,30,31};
VAR
	hostController : OpenHostController;
	bus, device, function : LONGINT;
	iobasePhys, irq : LONGINT;
	iobaseVirt: ADDRESS;
	pciCmdReg : LONGINT;
	index : LONGINT;
	res: LONGINT;
BEGIN
	index := 0;
	IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbOhci: Looking for PCI Open Host Controllers..."); KernelLog.Ln; END;
	(* traverse all USB Open Host Controllers of all PCI busses in the system *)
	WHILE PCI.FindPCIClassCode(OhciClassCode, index, bus, device, function) = PCI.Done DO
		res := PCI.ReadConfigDword(bus, device, function, PCI.CmdReg, pciCmdReg); ASSERT(res = PCI.Done);
		IF SYSTEM.VAL(SET, pciCmdReg) * PCIStatusErrorMask # {} THEN
			KernelLog.String("UsbOhci: PCI device is in error state."); KernelLog.Ln;
		ELSIF PCI.Enable(PCI.MemorySpace + PCI.BusMaster, bus, device, function) # PCI.Done THEN
			KernelLog.String("UsbOhci: Could not enable nus mastering or memory space access."); KernelLog.Ln;
		ELSE
			res := PCI.ReadConfigByte(bus, device, function, PCI.IntlReg, irq); ASSERT(res = PCI.Done);
			res := PCI.ReadConfigDword(bus, device, function, PCI.Adr0Reg, iobasePhys); ASSERT(res = PCI.Done);
			IF SYSTEM.VAL(SET, iobasePhys) * {0} # {} THEN
				KernelLog.String("UsbOhci: Error: Operational Register are not memory mapped"); KernelLog.Ln;
			ELSIF SYSTEM.VAL(SET, iobasePhys) * {1,2,3} # {} THEN
				KernelLog.String("UsbOhci: Error: Operational Register are not correctly mapped "); KernelLog.Ln;
			ELSIF irq = 0 THEN
				KernelLog.String("UsbOhci: Error: Please enable interrupts for USB Host Controller."); KernelLog.Ln;
			ELSE
				(* OHCI Spec: iobase address are the higher 20 bits *)
				iobasePhys := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, iobasePhys) * {12..31});
				Machine.MapPhysical(iobasePhys, 4096, iobaseVirt);
				NEW(hostController, bus, device, function);
				IF hostController.Init(Machine.Ensure32BitAddress(iobaseVirt), irq) THEN (* host controller has been initialized and started successfully *)
					IF Debug.Verbose THEN
						KernelLog.Enter;
						KernelLog.String("UsbOhci: Initialised USB Open Host Controller at base 0"); KernelLog.Hex(iobasePhys, 8);
						KernelLog.String(", Irq: "); KernelLog.Int(irq, 0);
						KernelLog.Exit;
					END;
					UsbHcdi.RegisterHostController(hostController, Description);
				ELSE (* ERROR: host controller initialization failed *)
					KernelLog.Enter;
					KernelLog.String("UsbOhci: Cannot init USB Open Host Controller at base 0"); KernelLog.Hex(iobasePhys, 8);
					KernelLog.String(", Irq: "); KernelLog.Int(irq, 0);
					KernelLog.Exit;
				END;
			END;
		END;
		INC(index);
	END; (* end while loop *)
END PCIFindOhci;

(* called when this module is unloaded *)
PROCEDURE Cleanup;
BEGIN
	UsbHcdi.UnRegisterHostControllers(Description);
END Cleanup;

PROCEDURE Install*;
(* Load module *)
END Install;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	(* Find, init and start all compatible UHCI USB host controllers and register them in the UsbHcdi.controllers registry *)
	PCIFindOhci;
END UsbOhci.

UsbOhci.Install ~ SystemTools.Free UsbOhci ~
