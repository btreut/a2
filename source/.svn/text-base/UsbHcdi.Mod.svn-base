MODULE UsbHcdi; (** AUTHOR "staubesv"; PURPOSE "USB Host Controller Driver Interface (HCDI)" *)
(**
 * Bluebottle USB Host Controller Driver Interface
 *
 * This is the hardware abstraction layer which enables the USB Bus Driver / Hub Driver to handle all USB Host Controller
 * in a unique way.
 *
 * Overview:
 *
 *	HcdInterface	Interface of the hardware-specific operations to be implemented by specific USB Host Controller drivers
 *	Hcd(Interface)	Implementation of hardware-independent functionality common to all USB Host Controllers
 *
 * USB host controllers are controlled by operational registers and the host controller communication area in system memory.
 *
 * History:
 *
 *	24.11.2005	History started (staubesv)
 *	29.11.2005	Introduced Notifier object and moved corresponding code from HC drivers to Hcd (staubesv)
 *	12.12.2005	More options for HcdManager.Show, use exception handling for critical calls (staubesv)
 *	13.12.2005	Fixed critical bug in RemoveQH, some cleanup (staubesv)
 *	15.12.2005	Added pipe.CheckBuffer, removed Pipe.pid field (staubesv)
 *	06.01.2006	Check whether USB device has been disconnected in Pipe transfer routines (staubesv)
 *	09.01.2006	Added TraceControlData trace option (staubesv)
 *	11.01.2006	Removed Hcd.GetPortCount, Hcd.RestartPipe, Pipe.Restart (staubesv)
 *	12.01.2006	Implemented software scatter/gather mechanism for pipes (staubesv)
 *	12.01.2006	Implemented transfer completion notification via interrupts (staubesv)
 *	16.01.2006	Bugfix: Pipe.Clearhalt request must use endpoint address instead of endpoint number (staubesv)
 *	17.01.2006	Use less memory for the TD buffer of the default pipe (staubesv)
 *	24.01.2006	Removed offset parameter for control transfer buffer (staubesv)
 *	25.01.2006	Unified Pipe.ControlTranfer & Pipe.Transfer, introduced TransferCompletion object (staubesv)
 *	26.01.2006	Don't return failure codes in Hcd.GetPipe, just NIL if allocation fails (staubesv)
 *	01.02.2006	Removed HcdManager, use Plugins mechanis instead (staubesv)
 *	01.03.2006	Fixed broken control out transfers (staubesv)
 *	28.06.2006	Removed procedure PrintHex (use KernelLog.Hex instead),
 *				fixed UnRegisterHostControllers so it only removes the Controllers with the provided description (staubesv)
 *	03.06.2006	HcdInterface.UpdatePipe removed (staubesv)
 *	03.08.2006	Introduced HcdInterface.LinkTDsAllowed procedure (staubesv)
 *	05.01.2007	Separatly trace shortpackets/other errors, each pipe has now a own thread that's used to call its completion handler (staubesv)
 *
 * TODOs:
 *	- nicer design of pipes (message pipe / stream pipe)
 *	- move pipes in separate module?
 *	- Should control transfers also use IOC completion? No.
 * 	- Timeout handling: Fix: Transfer could still complete when a timeout occurs
 *)

IMPORT SYSTEM, KernelLog, Machine, Plugins, Modules, Kernel, Objects, Usbdi, Debug := UsbDebug;

CONST

	(** Bluebottle specific hub port status bits. Not all (root) hubs do support all of the possible status bits *)
	PortStatusDevicePresent* = {0}; 			(** USB device is attached to the port (only visible when port is powered) *)
	PortStatusEnabled* = {1}; 				(** The port is enabled *)
	PortStatusLowSpeed* = {2}; 				(** Connected device is a low-speed device *)
	PortStatusFullSpeed* = {3}; 				(** Connected device is a full-speed device *)
	PortStatusHighSpeed* = {4}; 			(** Connected device is a high-speed device *)
	PortStatusReset* = {5}; 					(** The port is current resetting *)
	PortStatusError* = {6}; 					(** The status request failed. *)
	PortStatusConnectChange* = {7};		(** The connection status of the port has changed *)
	PortStatusSuspended* = {8}; 			(** The port is suspended *)
	PortStatusOverCurrent* = {9}; 			(** There is an overcurrent condition on this port *)
	PortStatusPowered* = {10}; 				(** The port is powered *)
	PortStatusEnabledChange* = {11}; 		(** The enabled/disabled status has changed *)
	PortStatusSuspendChange* = {12}; 		(** The suspended status has changed *)
	PortStatusOverCurrentChange* = {13}; 	(** The overcurrent status has changed *)
	PortStatusResetChange* = {14}; 			(** The reset status has changed *)
	PortStatusWakeOnOvercurrent* = {15}; 	(** Overcurrent conditions are a wake-up event *)
	PortStatusWakeOnDisconnect* = {16}; 	(** Device disconnection is a wake-up event *)
	PortStatusWakeOnConnect* = {17}; 		(** Device connection is a wake-up event *)
	PortStatusTestControl* = {18}; 			(** The port is in test mode *)
	PortStatusIndicatorControl* = {19}; 		(** The port supports control of its status indicator LEDs *)
	PortStatusPortOwner* = {20}; 			(** The port is owned by the high-speed controller (only EHCI HCs) *)

	(** Pipe.errors coding. Gives more detailed transfer completion status than Pipe.status *)
	NoErrors* = {};							(** No errors occured *)
	ShortPacket* = {1};						(** Device transferred less data than requested *)
	Stalled* = {2};							(** Stall condition *)
	InProgress* = {3};						(** Transfer is still in progress (timeout for blocking transfers) *)
	Nak* = {4};								(** [UHCI] Device NAKed transfer *)
	Crc* = {5};								(** [OHCI] CRC error *)
	Timeout* = {6};							(** [OHCI] USB protocol timeout *)
	CrcTimeout* = {7};						(** [UHCI] CRC or Timeout error *)
	BitStuff* = {8};							(** Bitstuffing error *)
	Databuffer* = {9};						(** Databuffer error *)
	Babble* = {10};							(** Babble: Device sent more data than requested -> serious error! *)
	UnexpectedPid* = {13};					(** [OHCI] Unexpected PID *)
	PidCheckFailure* = {15};					(** [OHCI] PID check failure *)
	DataToggleMismatch* = {16};			(** [OHCI] Datatoggle mismatch *)
	DeviceNotResponding* = {17};			(** [OHCI] Device did not respond *)
	(** Pipe.errors HCDI level errors *)
	LinkTDsFailed* = {18};					(** Could not link TDs to QH since there are already linked TDs *)
	OutOfTDs* = {19};						(** No more TDs available for transfer scheduling *)
	Internal* = {11};							(** HCDI level error *)
	TransferTooLarge* = {14};				(** HCDI level error: Transfer is too large, respectively SG list is too small *)
	Disconnected* = {12};					(** Device has been disconnected *)

	(** Coding of ORD(PipePolicy.type) field *)
	PipeControl* =  0;
	PipeIsochronous* = 1;
	PipeBulk* = 2;
	PipeInterrupt* = 3;

	(* Host controller states *)
	Undefined* = 0;
	Initialized* = 1;
	Operational* = 2;
	Suspended* = 3;
	Resuming* = 4;
	Halted* = 5;
	Shutdown* = 6;

	(* USB transfer modes *)
	LowSpeed* = 0;
	FullSpeed* = 1;
	HighSpeed* = 2;

	(** Direction field for control transfers / pipes *)
	In* = 0;		(* Device-to-Host *)
	Out* = 1;	(* Host-to-Device *)

	TDsPerPipe = 64000;
	TDsDefaultPipe = 20; (* The default pipe (address 0, endpoint 0) is only used to read/write at maximum 8 Bytes *)

	(** HcCapabilities powerSwitching, overCurrentDetection field values *)
	NotAvailable* = 0; (* MUST be 0 *)
	Global* = 1; (* MUST be 1 *)
	PerPort* = 2; (* MUST be 2 *)

	(* Port indicator colors. Don't change values! *)
	Automatic* = 0;
	Amber* = 1;
	Green* = 2;
	Off* = 3;

	(** Timing [milliseconds] *)
	PortResetTime* = 10 + 20; (* "The duration of the Resetting state is nominally 10 ms to 20 ms (10 ms is preferred)", USB2.0spec Chapter 11.5.1.5 *)

	(** After a port reset, the hub should enable the port within this time *)
	PortEnableTimeout* = 20;  (* ms *)

	 (* Wait for at least 100ms to allow completion of insertion process and for power at the device to become stable. USB 2.0spec Chapter 9.1.2 *)
	PortInsertionTime* = 100 + 50;

	(* SetAddress recovery interval of 2ms, USB2.0spec Chapter 9.2.6.3 *)
	AddressRecoveryTime* = 2 + 10;

	(* Minimum time the root hub must assert the reset signal on its downstream ports *)
	RootHubResetTime* = 100; (* >= 50 ms, USB2.0spec, p. 282  *)

	(* Minimum time the HC must stay in suspend state once entered *)
	MinSuspendTime* = 8; (* >= 5ms, OHCI specification p. 44 *)

	StateDisconnected* = -1; (* MUST be equal to Usb.StateDisconnected *)

TYPE

	(** Aligned memory space. Use data[base] as first entry. *)
	AlignedMemSpace* = POINTER TO RECORD
		data- : POINTER TO ARRAY OF LONGINT;
		base- : ADDRESS;
	END;

	(** Emulated hub descriptor for supporting root hub emulation *)
	HubDescriptor* = POINTER TO ARRAY OF CHAR;

	(* Used for reporting root hub status and root hub port status changes *)
	StatusChangeHandler* = PROCEDURE {DELEGATE} (status : Usbdi.Status; actLen : LONGINT);

	(* Packet for message pipe transfers *)
	ControlMessage* = POINTER TO ARRAY 8 OF CHAR;

TYPE

	(* The HcdInterface defines the interface that must be implemented by the Host Controller Drivers *)
	HcdInterface = OBJECT(Plugins.Plugin)

		(** Root Hub Control *)

		(* Port numbers: 0.. nbrOfPorts-1 *)

		(**
		 * Enable power for the specified port.
		 * It is the hub driver that is responsible for waiting the PwrOn2PwrGood time after enabling a port.
		 * The actual result is depending on the kind of power switching the root hub implements:
		 * - Per port: Enable power for the specified port
		 * - Ganged: One call will enable power for all ports, independent on the specified port number
		 * - None: The hub driver will not call this procedure
		 * @param port Port to enable power for
		 *)
		PROCEDURE EnablePortPower*(port : LONGINT);
		BEGIN HALT(301); END EnablePortPower;

		(**
		 * Disable power for the specified port.
		 * The actual result is depending on the kind of power switching the root hub implements:
		 * - Per port: Disable power for the specified port
		 * - Ganged: One call will disable power for all ports, independent on the specified port number
		 * - None: The hub driver will not call this procedure
		 * @param port Port to disable power for
		 *)
		PROCEDURE DisablePortPower*(port : LONGINT);
		BEGIN HALT(301); END DisablePortPower;

		(**	Reset and then enable the specified port.
			Resets the port, waits until reset is complete, enables the port and then returns. The client
			(HubDriver) is responsible for waiting after the port is enabled *)

		PROCEDURE ResetAndEnablePort*(port : LONGINT) : BOOLEAN;
		BEGIN HALT(301); RETURN FALSE; END ResetAndEnablePort; (* abstract *)

		(** Disable the specified port. *)

		PROCEDURE DisablePort*(port: LONGINT);
		BEGIN HALT(301); END DisablePort; (* abstract *)

		(** Suspend the specified port *)

		PROCEDURE SuspendPort*(port: LONGINT) : BOOLEAN;
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbHcdi: Port suspending not supported."); KernelLog.Ln; END;
			RETURN FALSE;
		END SuspendPort;

		(** Resume the specified port *)

		PROCEDURE ResumePort*(port: LONGINT) : BOOLEAN;
		BEGIN
			IF Debug.Level >= Debug.Warnings  THEN KernelLog.String("UsbHcdi: Port resuming not supported."); KernelLog.Ln; END;
			RETURN FALSE;
		END ResumePort;

		(**
		 * Get the status of the specified port.
		 * @param port Port to get status from
		 * @param ack Ackknowlegde status bits that are set
		 * @return Port status
		 *)
		PROCEDURE GetPortStatus*(port : LONGINT; ack : BOOLEAN) : SET;
		BEGIN HALT(301); RETURN {}; END GetPortStatus; (* abstract *)

		(** Indicate a port state using the port indicators *)
		PROCEDURE IndicatePort*(port, indicate : LONGINT);
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbHcdi: Port indicator control not supported."); KernelLog.Ln; END;
		END IndicatePort;

		(** Route the specified port to a companion host controller if supported. *)
		PROCEDURE RoutePortToCompanion*(port : LONGINT);
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbHcdi: Port routing not supported."); KernelLog.Ln; END;
		END RoutePortToCompanion;

		(** USB transfer scheduling *)

		PROCEDURE Schedule*(pipe : Pipe; bufferLen, offset: LONGINT; VAR buffer : Usbdi.Buffer);
		BEGIN HALT(301); END Schedule; (* abstract *)

		PROCEDURE ScheduleControl*(pipe : Pipe; direction: LONGINT; msg: ControlMessage;  bufferLen : LONGINT; VAR buffer : Usbdi.Buffer);
		BEGIN HALT(301); END ScheduleControl; (* abstract *)

		(** Inserts a QH for the specified USB pipe into the host controller's schedule data structure. *)

		PROCEDURE InsertQH*(pipe : Pipe): BOOLEAN; (* Only call in EXCLUSIVE regions *)
		BEGIN HALT(301); RETURN FALSE; END InsertQH; (* abstract *)

		(** Remove the pipe's queue head from the host controller's schedule data structure. *)

		PROCEDURE RemoveQH*(pipe : Pipe); (* Only call in EXCLUSIVE regions *)
		BEGIN HALT(301); END RemoveQH; (* abstract *)

		(** Updates the status field of the USB transfer request <req> *)

		PROCEDURE UpdatePipeStatus*(pipe : Pipe);
		BEGIN HALT(301); END UpdatePipeStatus; (* abstract *)

		(** Checks whether TDs may be linked to the pipe's QH *)

		PROCEDURE LinkTDsAllowed*(pipe : Pipe) : BOOLEAN; (* {EXCLUSIVE} *)
		BEGIN HALT(301); RETURN FALSE; END LinkTDsAllowed; (* abstract *)

		(** Insert the TD list into the host controllers schedule *)

		PROCEDURE LinkTDs*(pipe : Pipe; firstTD : Machine.Address32); (* {EXCLUSIVE} *)
		BEGIN HALT(301); END LinkTDs; (* abstract *)

		(** Remove all transfer descriptors from the pipe's queue head / endpoint descriptor *)

		PROCEDURE UnlinkTDs*(pipe: Pipe); (* {EXCLUSIVE} *)
		BEGIN HALT(301); END UnlinkTDs; (* abstract *)

		(* Clear halt bit if pipe is stalled. The TDs associated to the pipe will be removed from the queue *)

		PROCEDURE ClearHalt*(pipe : Pipe);
		BEGIN HALT(301); END ClearHalt; (* abstract *)

		(** Debug interface *)

		(** Show the specified queue head / endpoint descriptor *)
		PROCEDURE ShowQH*(qh, firstTD : ADDRESS);
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("QH/TD diagnostics not implemented."); KernelLog.Ln; END;
		END ShowQH;

		(** Show the data structures associated with the specified pipe *)
		PROCEDURE ShowPipe*(pipe : Pipe);
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Pipe diagnostics not implemented."); KernelLog.Ln; END;
		END ShowPipe;

		(** Show the host controller's scheduling data structure *)
		PROCEDURE ShowSchedule*;
		BEGIN
			IF Debug.Level >= Debug.Warnings THEN KernelLog.String("Schedule diagnostics not implemented."); KernelLog.Ln; END;
		END ShowSchedule;

	END HcdInterface;

	(** Implements hardware-independent functionality of USB Host Controllers *)
	Hcd* = OBJECT(HcdInterface)
	VAR
		(* Host controller configuration data - Consider this fields as read-only. *)
		iobase*: Machine.Address32;
		irq* : LONGINT;
		portCount* : LONGINT;
		ports* : POINTER TO ARRAY OF Machine.Address32;  (* addresses of the Port Status Control registers  *)

		(* PCI specific *)
		bus-, device-, function- : LONGINT;

		(* HC capabilities (consider read-only) *)
		DMAchaining* : BOOLEAN; 	(* Can the HC do H/W scatter/gather? *)
		sgListSize* : LONGINT; 		(* How many entries shall the SG list support? Only valid if DMAchaining is TRUE. *)
		isHighSpeed* : BOOLEAN;	(* Does this host controller support high-speed transfer mode? *)

		(* Emulated hub device descriptor *)
		hubDescriptor* : HubDescriptor;

		(* current state of the host controller (Undefined|Initialized|Operational|Suspended|Resuming|Error) *)
		state- : LONGINT;

		(* Procedure called when the status of the root hub port changes *)
		statusChangeHandler- : StatusChangeHandler;

		(* pipes[deviceaddress][direction][endpoint],  [0][0][0] is the dummy default control pipe 	*)
		(* control pipes (bidirectional) are stored as they had dir In (0)							*)
		pipes- : ARRAY 128 OF ARRAY 2 OF ARRAY 16 OF Pipe;

		(* These pipes have an handler associated which should be called when the pipe's transfer is finished 		*)
		(* The Default Pipe (Address 0, ep 0) of the controller is used as list head but has no completion handler	*)
		notifyPipes- : Pipe;

		(* Keeps track which UDB device addresses are in use. *)
		adrRange : ARRAY 128 OF BOOLEAN;


		(* Per USB lock *)
		buslock : LONGINT;

		(* For the Wait procedure *)
		timer : Kernel.Timer;

		(* Performance monitoring *)
		NbytesTransfered- : HUGEINT;

		(* HC statistics *)
		NnofTransfers-,
		NnofBulkTransfers-, NnofControlTransfers-, NnofInterruptTransfers-, NnofIsochronousTransfers-,
		NnofUnknownTransfers-,
		NnofInterrupts*, NnofInterruptsHandled* : LONGINT;

		(** Bus Locking *)

		(** Lock this bus *)
		PROCEDURE Acquire*;
		BEGIN {EXCLUSIVE}
			AWAIT(buslock <= 0); buslock := 1;
		END Acquire;

		(** Unlock this bus *)
		PROCEDURE Release*;
		BEGIN {EXCLUSIVE}
			DEC(buslock);
		END Release;

		(** Set the state of the HC *)
		PROCEDURE SetState*(state : LONGINT);
		BEGIN {EXCLUSIVE}
			SELF.state := state;
		END SetState;

		(** Root hub control *)

		(**
		 * Return the emulated hub device descriptor.
		 * To be controllable by the hub driver, root hubs emulate a USB hub devices. This procedure returns
		 * the emulated hub descriptor to communicate the root hubs facilities.
		 *)
		PROCEDURE GetHubDescriptor*() : HubDescriptor;
		BEGIN
			IF Debug.StrongChecks THEN ASSERT(hubDescriptor # NIL); END;
			RETURN hubDescriptor;
		END GetHubDescriptor;

		(** Set the emulated hub device descriptor. *)
		 PROCEDURE SetHubDescriptor*(hd : HubDescriptor);
		 BEGIN
		 	IF Debug.StrongChecks THEN ASSERT((hd # NIL) & (LEN(hd) >= 8)); END;
		 	hubDescriptor := hd;
		 END SetHubDescriptor;

		(**
		 * Install a handler for root hub port status changes.
		 * Some host controller can report changes of the port status registers via interrupts. If this is not
		 * supported, the hub driver must poll the root hub for port status changes.
		 * @param handler to be called when root hub port status changes occus
		 * @return TRUE, if root hub support status change notifications, FALSE otherwise.
		 *)
		PROCEDURE SetStatusChangeHandler*(handler : StatusChangeHandler) : BOOLEAN;
		BEGIN
			statusChangeHandler := handler; RETURN TRUE;
		END SetStatusChangeHandler;

		(** Add an interrupt handler. The handler is called, when a IOC interrupt occurs and the pipe.status field is changed	*)
		PROCEDURE AddCompletionHandler*(pipe : Pipe);
		VAR temp : Pipe;
		BEGIN {EXCLUSIVE}
			IF Debug.Trace & Debug.tracePipes THEN
				KernelLog.String("UsbHcdi: Adding completion handler for pipe (Adr: "); KernelLog.Int(pipe.address, 0);
				KernelLog.String(", ep: "); KernelLog.Int(pipe.endpoint, 0); KernelLog.String(")"); KernelLog.Ln;
			END;
			temp := notifyPipes;
			WHILE(temp.next # NIL) & (temp.next # pipe) DO temp := temp.next; END;
			IF temp.next = NIL THEN
				temp.next := pipe;
			ELSIF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbHcdi: Warning: Procedure was already registered as interrupt handler"); KernelLog.Ln;
			END;
		END AddCompletionHandler;

		(** Remove an interrupt handler. The head of this list is always the control pipe for the default address. *)
		PROCEDURE RemoveCompletionHandler*(pipe : Pipe);
		VAR temp : Pipe;
		BEGIN (* only to be called from exclusive regions !! *)
			IF Debug.Trace & Debug.tracePipes & (ADDRESSOF(pipe) > 10H)  THEN
				KernelLog.String("UsbHcdi: Removing completion handler for pipe (Adr: "); KernelLog.Int(pipe.address, 0);
				KernelLog.String(", ep: "); KernelLog.Int(pipe.endpoint, 0); KernelLog.String(")"); KernelLog.Ln;
			END;
			(* Never remove the default address control pipe *)
			pipe.irqActive := FALSE;
			temp := notifyPipes;
			WHILE (temp.next # NIL) & (temp.next # pipe) DO temp := temp.next; END;
			IF temp.next # NIL THEN (* delete pipe in list *)
				 temp.next := temp.next.next;
			ELSIF Debug.Level >= Debug.Warnings THEN
				KernelLog.String("UsbHcdi: Warning: Could not remove interrupt handler (not found)"); KernelLog.Ln;
			END;
		END RemoveCompletionHandler;

		PROCEDURE NotifyCompletionHandlers*;
		VAR pipe : Pipe;
		BEGIN (* concurrent insertion/removal of completion handlers is allowed *)
			pipe := notifyPipes.next; (* notifyPipes is the Default Pipe (address 0, ep 0), skip it *)
			WHILE pipe # NIL DO
				IF pipe.irqActive & (pipe.mode = Usbdi.MinCpu) THEN
					UpdatePipeStatus(pipe);
					IF (pipe.status # Usbdi.InProgress) & (pipe.device.state # StateDisconnected) THEN
						pipe.irqActive := FALSE;
						IF Debug.Trace & Debug.traceIoc THEN
							KernelLog.String("UsbHcdi: Notify pipe adr: "); KernelLog.Int(pipe.address, 0);
							KernelLog.String(", ep: "); KernelLog.Int(pipe.endpoint, 0); KernelLog.String(": "); ShowErrors(pipe.errors); KernelLog.Ln;
						END;
						IF Debug.Trace & (pipe.status # Usbdi.Ok) THEN
							IF (pipe.status = Usbdi.ShortPacket) THEN
								IF Debug.traceShortPackets THEN pipe.Show(TRUE); KernelLog.Ln; END;
							ELSE
								IF Debug.traceFailed THEN pipe.Show(TRUE); KernelLog.Ln; END;
							END;
						END;
						IF Debug.PerformanceMonitoring THEN
							IF (pipe.status = Usbdi.Ok) OR (pipe.status = Usbdi.ShortPacket) THEN
								(* should be protected *)
								INC (NbytesTransfered, pipe.actLen);
							END;
						END;
						IF pipe.mode = Usbdi.MinCpu THEN pipe.completion.SetDone; END;
						IF pipe.completionHandlerCaller # NIL THEN pipe.completionHandlerCaller.Call(); END;
					END;
				END;
				pipe := pipe.next;
			END;
		END NotifyCompletionHandlers;

		(* The default pipe (adr 0, ep 0) is only used to communicate with devices as long they are not in the addressed state. *)
		PROCEDURE GetDefaultPipe*(speed, ttPort, ttAddress : LONGINT; device : Usbdi.UsbDevice) : Pipe;
		VAR pipe : Pipe;
		BEGIN {EXCLUSIVE}
			IF Debug.StrongChecks THEN ASSERT(pipes[0, 0, 0] # NIL); END; (* dummy default pipe is always present *)
			pipe := pipes[0, 0, 0];
			pipe.speed := speed;
			pipe.device := device;
			pipe.completion.device := device;
			pipe.ttPort := ttPort;
			pipe.ttAddress := ttAddress;
			IF isHighSpeed THEN
				pipe.maxPacketSize := 64;
			ELSE
				pipe.maxPacketSize := 8;
			END;
			IF ~InsertQH(pipe) THEN pipe := NIL; END;
			RETURN pipe;
		END GetDefaultPipe;

		(** USB Pipe Handling *)

		PROCEDURE GetPipe*(deviceAddress, endpointNbr : LONGINT; VAR pipe : Pipe);
		VAR testaddr : ADDRESS;
		BEGIN {EXCLUSIVE}
			IF Debug.StrongChecks THEN
				ASSERT((deviceAddress > 0) & (deviceAddress < 128));  (* valid USB device address *)
				ASSERT((endpointNbr MOD 16 >=  0) & (endpointNbr MOD 16 < 16)); (* valid endpoint number *)
				ASSERT((pipe # NIL) & (pipe.direction = In) OR (pipe.direction = Out));
			END;
			IF pipes[deviceAddress, pipe.direction, endpointNbr MOD 16] # NIL THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbHcdi: GetPipe: Pipe already in use."); KernelLog.Ln; END;
				pipe := NIL; RETURN;
			END;
			(* Allocate the TD buffers  *)
			pipe.tdBufferLen := (TDsPerPipe+1)* 16 + 128;
			NEW(pipe.tdBuffer, pipe.tdBufferLen);
			IF Debug.StrongChecks THEN
				testaddr := Machine.PhysicalAdr(ADDRESSOF(pipe.tdBuffer[0]), pipe.tdBufferLen);
				IF testaddr = Machine.NilAdr THEN
					KernelLog.String("UsbHcdi: GetPipe: Allocated buffer not physically contiguous"); KernelLog.Ln;
					pipe := NIL; RETURN;
				END;
			END;
			(* TD's must be 32byte aligned for EHCI, 16byte aligned for UHCI & OHCI data structures*)
			(* currently max qh size is below 128 bytes for EHCI, so a queue head will not cross page boundaries *)
			pipe.qh := Align(ADDRESS OF pipe.tdBuffer[0], 128);
			pipe.tdBase := pipe.qh + 32;
			ASSERT((pipe.qh >= ADDRESSOF(pipe.tdBuffer[0])) & (pipe.tdBase <= ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1])));
			IF ~InsertQH(pipe) THEN
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbHcdi: GetPipe: InsertQH failed."); KernelLog.Ln; END;
				pipe := NIL; RETURN;
			END;
			pipes[deviceAddress, pipe.direction, endpointNbr MOD 16] := pipe;
			IF Debug.Trace & Debug.tracePipes THEN
				KernelLog.String("UsbHcdi: GetPipe: ");
				CASE pipe.type OF
					|PipeControl: KernelLog.String("Control");
					|PipeBulk: KernelLog.String("Bulk");
					|PipeInterrupt: KernelLog.String("Interrupt");
					|PipeIsochronous: KernelLog.String("Isochronous");
				ELSE
					KernelLog.String("Unknown");
				END;
				IF pipe.direction = In THEN KernelLog.String(" IN Pipe, ");
				ELSIF pipe.direction = Out THEN KernelLog.String(" OUT Pipe, ");
				ELSE KernelLog.String("Unknown direction Pipe, ");
				END;
				KernelLog.String(" Adr: "); KernelLog.Int(deviceAddress, 0);
				KernelLog.String(" Ep: "); KernelLog.Int(endpointNbr, 0);
				KernelLog.String(" established"); KernelLog.Ln;
			END;
		END GetPipe;

		PROCEDURE FreePipe*(pipe : Pipe);
		BEGIN {EXCLUSIVE}
			FreePipeInternal(pipe);
		END FreePipe;

		PROCEDURE FreePipeInternal(pipe : Pipe);
		BEGIN (* only call from exclusive regions *)
			IF pipe.address = 0 THEN
				IF pipe.qh # 0 THEN RemoveQH(pipe); END;
				IF Debug.Trace & Debug.tracePipes THEN KernelLog.String("UsbHcdi: Default pipe at adr 0 freed up."); KernelLog.Ln; END;
			ELSIF pipes[pipe.address, pipe.direction, pipe.endpoint MOD 16] # NIL THEN
				(* De-install interrupt handler if present *)
				IF pipe.ioc THEN RemoveCompletionHandler(pipe); END;
				(* Kill completion handler caller if present *)
				IF pipe.completionHandlerCaller # NIL THEN pipe.completionHandlerCaller.Terminate; END;
				(* Remove the pipe's queue head from the host controller's schedule *)
				IF pipe.qh # 0 THEN RemoveQH(pipe); END;
				(* Never free the dummy default pipe *)
				pipes[pipe.address, pipe.direction, pipe.endpoint MOD 16] := NIL;
				IF Debug.Trace & Debug.tracePipes THEN
					KernelLog.String("UsbHcdi: FreePipe:"); KernelLog.String(" Adr: "); KernelLog.Int(pipe.address, 0);
					KernelLog.String(" Ep: "); KernelLog.Int(pipe.endpoint, 0); KernelLog.String(" freed up."); KernelLog.Ln;
				END;
			ELSE (* Pipe not known by host controller *)
				IF Debug.Level >= Debug.Warnings THEN
					KernelLog.String("UsbHcdi: FreePipe: Can't free pipe... pipe not known by host controller ADR: ");
					IF pipe # NIL THEN
						KernelLog.Int(pipe.address, 0); KernelLog.String(", ep: "); KernelLog.Int(pipe.endpoint, 0);
						KernelLog.String(", dir: "); KernelLog.Int(pipe.direction, 0);
					ELSE
						KernelLog.String("NIL");
					END;
					KernelLog.Ln;
				END;
			END;
		END FreePipeInternal;

		(** Free all pipes of the device with the address adr *)
		PROCEDURE FreeAll*(adr : LONGINT);
		VAR i, j : LONGINT;
		BEGIN {EXCLUSIVE}
			IF Debug.StrongChecks THEN ASSERT((adr >= 0) & (adr < 128)); END;
			IF adr = 0 THEN RETURN (* Emulated hub device has no pipes *) END;
			IF state = Shutdown THEN RETURN; END; (* Since the controller has been resetted, removing QHs would trap *)
			FOR i := 0 TO 15 DO
				FOR j := 0 TO 1 DO
					IF pipes[adr, j, i] # NIL THEN
						FreePipeInternal(pipes[adr, j , i]);
					END;
				END;
			END;
		END FreeAll;

		(** Returns a unused address and marks it as used; address 0 is the default address, to
		 * which unaddressed USB devices at enabled endpoints will respond.  *)
		PROCEDURE GetFreeAddress*() : LONGINT;
		VAR adr : LONGINT;
		BEGIN {EXCLUSIVE}
			FOR adr := 1 TO 127 DO
				IF adrRange[adr] = FALSE THEN adrRange[adr] := TRUE; RETURN adr; END;
			END;
			RETURN 0;
		END GetFreeAddress;

		(** Marks the address <adr> as free *)
		PROCEDURE FreeAddress*(adr : LONGINT);
		BEGIN {EXCLUSIVE}
			adrRange[adr] := FALSE;
		END FreeAddress;

		(** Helper: Wait for the specified number of milliseconds *)
		PROCEDURE Wait*(ms : LONGINT);
		BEGIN
			timer.Sleep(ms);
		END Wait;

		PROCEDURE Cleanup*;
		BEGIN
			SetState(Shutdown); timer.Wakeup;
		END Cleanup;

		PROCEDURE &Default*(bus, device, funtion : LONGINT);
		VAR pipe : Pipe; i : LONGINT;
		BEGIN
			SELF.bus := bus; SELF.device := device; SELF.function := function;
			NEW(timer);
			FOR i := 0 TO 127 DO adrRange[i] := FALSE; END;
			NEW(pipe, 0, 0, SELF);
			pipe.type := PipeControl; pipe.direction := 0;
			pipe.maxPacketSize := 8; (* will be reset to 64 for EHCI HCs by hub driver *)
			pipe.maxRetries := 3; pipe.timeout := 5000;
			(* okay, now we allocate the TD buffers  *)
			pipe.tdBufferLen := (TDsDefaultPipe+1) * 16 + 128; (* max alignment of 128 bytes *)
			NEW(pipe.tdBuffer, pipe.tdBufferLen);
			(* TD's must be 32byte aligned for EHCI data structures, 16byte for UHCI & OHCI data structures *)
			(* currently max qh size is below 128 bytes for EHCI, so a queue head will not cross page boundaries *)
			pipe.qh := Align(ADDRESS OF pipe.tdBuffer[0], 128);
			pipe.tdBase := pipe.qh + 32;
			IF Debug.StrongChecks THEN
				ASSERT(pipe.tdBase >= ADDRESSOF(pipe.tdBuffer[0]));
				ASSERT(pipe.tdBase <= ADDRESSOF(pipe.tdBuffer[pipe.tdBufferLen-1]));
			END;
			pipes[0, 0, 0] := pipe;
			notifyPipes := pipe; (* Used as list head only (don't call its completion handler) *)
		END Default;

		(** Show diagnostic of host controller *)
		PROCEDURE Diag*;
		VAR port : LONGINT; dword : SET;
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("Diagnostics of "); KernelLog.String(name);
			KernelLog.String(" ("); KernelLog.String(desc); KernelLog.String(")");
			KernelLog.Ln;
			(* PCI information *)
			KernelLog.String("   PCI bus "); KernelLog.Int(bus, 0); KernelLog.String(", device "); KernelLog.Int(device, 0);
			KernelLog.String(", function "); KernelLog.Int(function, 0);
			KernelLog.Ln;
			(* IO base address and Interrupt Line *)
			KernelLog.String("   I/O base "); KernelLog.Hex(iobase, 8); KernelLog.String("H,  Irq: "); KernelLog.Int (irq, 0);
			KernelLog.String(", Int Counter: "); KernelLog.Int(NnofInterrupts, 0);
			KernelLog.Ln;
			(* Port Status *)
			KernelLog.String("   Number of ports: "); KernelLog.Int(portCount, 0); KernelLog.String(", Port status: ");
			KernelLog.Ln;
			FOR port := 0 TO portCount-1 DO
				dword := GetPortStatus(port, FALSE); KernelLog.String("      Port "); KernelLog.Int(port+1, 0); KernelLog.String(": ");
				ShowPortStatus(dword);	KernelLog.Ln;
			END;
			END;
		END Diag;
	END Hcd;

TYPE

	(** Used for Interrupt On Completion (IOC) transfer status notification *)
	TransferCompletion = OBJECT
	VAR
		done : BOOLEAN;
		completiontimeout : BOOLEAN;
		timer : Objects.Timer;
		device* : Usbdi.UsbDevice;

		PROCEDURE SetDone;
		BEGIN {EXCLUSIVE}
			done := TRUE;
		END SetDone;

		PROCEDURE SetCompletionTimeout;
		BEGIN {EXCLUSIVE}
			completiontimeout := TRUE;
		END SetCompletionTimeout;

		PROCEDURE AwaitDone(timeout : LONGINT) : BOOLEAN;
		VAR result : BOOLEAN;
		BEGIN {EXCLUSIVE}
			Objects.SetTimeout(timer, SELF.SetCompletionTimeout, timeout);
			done := FALSE; completiontimeout := FALSE;
			AWAIT(done OR completiontimeout OR (device.state = StateDisconnected));
			Objects.CancelTimeout(timer);
			done := FALSE; result := completiontimeout; completiontimeout := FALSE;
			RETURN ~result;
		END AwaitDone;

		PROCEDURE &New*;
		BEGIN
			NEW(timer);
		END New;

	END TransferCompletion;

TYPE

	(* Thread that calls the completion handler of a pipe (if it has one) *)
	CompletionHandlerCaller = OBJECT
	VAR
		completionHandler : Usbdi.CompletionHandler;
		pipe : Pipe;
		alive, dead, doCall : BOOLEAN;

		PROCEDURE Call;
		BEGIN {EXCLUSIVE}
			doCall := TRUE;
		END Call;

		PROCEDURE HandleTimeout;
		BEGIN{EXCLUSIVE}
			dead := TRUE;
		END HandleTimeout;

		PROCEDURE Terminate;
		VAR timer:Objects.Timer;
		BEGIN
			BEGIN {EXCLUSIVE} alive := FALSE; END;
			(* release monitor lock *)
			NEW(timer);
			Objects.SetTimeout(timer, HandleTimeout, 100);
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
		END Terminate;

		PROCEDURE &New*(pipe : Pipe; c : Usbdi.CompletionHandler);
		BEGIN
			ASSERT(c # NIL);
			SELF.pipe := pipe;
			completionHandler := c;
			alive := TRUE; dead := FALSE; doCall := FALSE;
		END New;

	BEGIN {ACTIVE}
		WHILE alive DO
			BEGIN {EXCLUSIVE}
				AWAIT(doCall OR ~alive);
				doCall := FALSE;
			END;
			IF alive THEN completionHandler(pipe.status, pipe.actLen); END;
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END CompletionHandlerCaller;

TYPE


	(**
	 * USB Communication Pipe
	 * USB communication happens between buffers provided by client software and device endpoints. The association between
	 * a client software buffer and a device endpoint is called pipe.
	 * This is the low-level implementation of a pipe which is used by the host controller drivers. The fields declared here aren't visible
	 * to client software which uses the interface defined by the USB Driver Interface (Usbdi).
	 *
	 * Concurrency:
	 *	- Allow for control pipes, not allowed for interrupt, bulk & isochronous pipes
	 *)
	Pipe* = OBJECT(Usbdi.Pipe)
	VAR
		(* Device endpoint *)
		address* : LONGINT; 	(* USB device address *)
		endpoint* : LONGINT; 	(* Endpoint address *)
		direction* : LONGINT; 	(* Endpoint direction; Usbdi.In or Usbdi.Out; not used for control transfers *)

		(* Associated host controller & USB device *)
		controller* : Hcd;
		device* : Usbdi.UsbDevice;

		(* Address of hub device that contains the transaction translator we're connected to and port of the TT *)
		(* These fields are duplicate here (also available in Usb.UsbDevice to avoid the import of Usb.Mod in UsbEhci.Mod *)
		ttPort*, ttAddress* : LONGINT;

		(* Information from endpoint descriptor *)
		type* : LONGINT; 		(* PipeControl, PipeBulk, PipeInterrupt or PipeIsochronous *)
		irqInterval* : LONGINT; 	(* Interrupt interval for PipeInterrupt (interrupt transfers) *)
		mult* : LONGINT; 		(* For high-speed interrupt/isochronous pipes: How many transactions per microframe (1,2 or 3) *)

		(* Pipe specific features *)
		speed* : LONGINT; 		 	(* LowSpeed, FullSpeed, HighSpeed *)
		dataToggle* : BOOLEAN; 	(* 1bit sequence number *)
(*		hostDelay, hubLsSetup : LONGINT; (* Delay introduced by host / hub in nanoseconds *)  *)

		(* Transfer status information *)
		status* : Usbdi.Status	;	(* Status of the last tranfer from/to this endpoint *)
		errors* : SET;
		transferLen* : LONGINT;		(* Length of the transfer in bytes *)
		actLen* : LONGINT; 			(* how many bytes did the controller send/receive *)

		(* Buffer for S/W scatter/gather support *)
		sgBuffer : Usbdi.BufferPtr;
		physBufferAdr- : ADDRESS;

		(* Buffer for H/W scatter/gather suport *)
		sgList- : POINTER TO ARRAY OF Machine.Range;

		(* Pipe parameters set by client software *)
		timeout* : LONGINT;

		(* Data structures 																									*)
		(* For control, bulk and interrupt transfers, each pipe has an associated queue head in the host controllers schedule.		*)
		(* This queue head can be found in the queue <queue>. The actual USB transfers are described as linked list of 			*)
		(* transfer descriptors (TD), which are linked to the pipe`s queue head. 												*)
		queue* : Machine.Address32;
		qh* : Machine.Address32;
		firstTD*, lastTD* : Machine.Address32;

		(* Per pipe buffer for transfer descriptors *)
		tdBuffer* : POINTER TO ARRAY OF CHAR;
		tdBufferLen* : LONGINT;
		tdBase* : Machine.Address32;

		(* Transfer completion handling related *)
		ioc* : BOOLEAN;  (* interrupt on completion enabled/disabled *)
		completionHandlerCaller* : CompletionHandlerCaller; (* if active & ioc, the procedure interruptHandler will be called if status * ResInProgress = {} *)
		irqActive* : BOOLEAN; (* Should the InterruptHandler be called? *)
		completion- : TransferCompletion;

		(* Pipe management *)
		next* : Pipe;

		(* Control pipes only: 8 Byte message *)
		message : ControlMessage;

		PROCEDURE &New*(adr, ep : LONGINT; hcd : Hcd);
		BEGIN
			NEW(completion);
			address := adr; endpoint := ep; controller := hcd; status := Usbdi.InProgress;
			IF controller.DMAchaining THEN NEW(sgList, controller.sgListSize); END;
		END New;

		(* For host controllers that do not support DMA chaining, the buffers must be physically contiguous. In Bluebottle, all buffers allocated 	*)
		(* on the heap meet this requirement. Buffers allocated on the stack may, however, be physically non-contiguous. Fortunately, the 		*)
		(* stack size is limited to 128K, so these buffers won't be bigger than 128K.																*)
		(* This procedure...																													*)
		(* 	- 	Returns TRUE and as a side effect copies the client buffer into the scatter/gather buffer for OUT transfers if the specified buffer	*)
		(*		cannot directly be used by the host controller																					*)
		(*	-	Returns FALSE when the client buffer meets the requirement of the host controller hardware									*)
		PROCEDURE NeedSWScatterGather(direction, bufferLen, offset : LONGINT; VAR buffer : Usbdi.Buffer; VAR doCopy : BOOLEAN) : BOOLEAN;
		VAR adr : ADDRESS;
		BEGIN
			doCopy := FALSE;
			IF bufferLen = 0 THEN RETURN FALSE; END;
			adr := Machine.PhysicalAdr(ADDRESSOF(buffer[offset]), bufferLen);
			IF adr = -1 THEN  (* buffer is not physically contiguous *)
				IF sgBuffer = NIL THEN NEW(sgBuffer, 128*1024); END; (* 128K is stack limit *)
				physBufferAdr := ADDRESSOF(sgBuffer[0]);
				IF direction = In THEN
					doCopy := TRUE;
				ELSE
					ASSERT(bufferLen <= 128*1024); (* If the buffer is on the heap, we don't reach this code. Stack limit is 128K *)
					Copy(buffer, sgBuffer^, offset, 0, bufferLen);
				END;
				RETURN TRUE;
			ELSE
				physBufferAdr := adr;
				RETURN FALSE;
			END;
		END NeedSWScatterGather;

		(* Make TDs accessible to the host controller and wait for transfer completion if transfer is blocking *)
		PROCEDURE ExecuteTransfer(bufferLen, offset : LONGINT; VAR buffer : Usbdi.Buffer; copy : BOOLEAN) : Usbdi.Status;
		VAR mtimer : Kernel.MilliTimer;
		BEGIN
			IF (controller.state # Operational) OR (device.state = StateDisconnected) THEN
				status := Usbdi.Disconnected; errors := Disconnected;
			ELSIF status = Usbdi.Error THEN (* controller.Schedule/ScheduleControl failed *)
				(* do nothing; return status *)
			ELSE
				IF mode = Usbdi.MinCpu THEN irqActive := TRUE; END;
				controller.LinkTDs(SELF, firstTD);

				IF timeout # 0 THEN (* this is a blocking transfer *)
					IF mode # Usbdi.MinCpu THEN
						Kernel.SetTimer(mtimer, timeout);
						LOOP
							IF (status # Usbdi.InProgress) OR Kernel.Expired(mtimer) OR (device.state = StateDisconnected) THEN EXIT; END;
							controller.UpdatePipeStatus(SELF);
							IF mode = Usbdi.Normal THEN Objects.Yield; END;
						END;
					ELSE
						IF ~completion.AwaitDone(timeout) THEN
							(* ignore *)
						END;
					END;
					IF Debug.PerformanceMonitoring THEN
						(* access should be protected *)
						INC (controller.NbytesTransfered, actLen);
					END;
					IF Debug.Trace & Debug.traceControlData & (type = PipeControl) THEN
						IF bufferLen > 0 THEN ShowData(buffer); KernelLog.Char(" "); ELSE KernelLog.String("[No Data] "); END;
					END;
					IF Debug.Trace & (Debug.traceTransfers OR Debug.traceControl) THEN ShowStatus(status); KernelLog.Ln; END;
					IF Debug.Trace & (status # Usbdi.Ok) THEN
						IF (status = Usbdi.ShortPacket) THEN
							IF Debug.traceShortPackets THEN Show(TRUE); KernelLog.Ln; END;
						ELSE
							IF Debug.traceFailed THEN Show(TRUE); KernelLog.Ln; END;
						END;
					END;
					IF device.state = StateDisconnected THEN
						errors := Disconnected; status := Usbdi.Disconnected;
					ELSIF status = Usbdi.InProgress THEN
						(* Timeout -> deactivate all transfers associated with this pipe. Otherwise we would return a buffer that could
						 * be still accessible to the host controller  *)
						controller.UnlinkTDs(SELF);
					ELSIF copy THEN (* copy data from scatter/gather buffer to client buffer *)
						Copy(sgBuffer^, buffer, 0, offset, actLen);
					END;
				END;
				IF Debug.Stats THEN
					Machine.AtomicInc(controller.NnofTransfers);
					IF (type = PipeControl) THEN Machine.AtomicInc(controller.NnofControlTransfers)
					ELSIF (type = PipeBulk) THEN Machine.AtomicInc(controller.NnofBulkTransfers)
					ELSIF (type = PipeInterrupt) THEN Machine.AtomicInc(controller.NnofInterruptTransfers)
					ELSIF (type = PipeIsochronous) THEN Machine.AtomicInc(controller.NnofIsochronousTransfers);
					ELSE
						Machine.AtomicInc(controller.NnofUnknownTransfers);
					END;
				END;
			END;
			RETURN status;
		END ExecuteTransfer;

		PROCEDURE Transfer*(bufferLen, offset : LONGINT; VAR buffer : Usbdi.Buffer) : Usbdi.Status;
		VAR copy : BOOLEAN;
		BEGIN
			ASSERT(type # PipeControl);
			ASSERT(LEN(buffer) >= bufferLen + offset);
			IF Debug.Trace & Debug.traceTransfers THEN ShowTransfer(bufferLen, offset); END;
			transferLen := bufferLen;	status := Usbdi.InProgress; errors := NoErrors;
			IF controller.LinkTDsAllowed(SELF) THEN

				IF ~controller.DMAchaining & NeedSWScatterGather(direction, bufferLen, offset, buffer, copy) THEN
					IF timeout = 0 THEN
						KernelLog.String("UsbHcdi: Non-blocking transfer to physically non-contiguous buffer not allowed."); KernelLog.Ln;
						status := Usbdi.Error; errors := Internal; RETURN status;
					END;
					controller.Schedule(SELF, bufferLen, 0, sgBuffer^);
				ELSE
					controller.Schedule(SELF, bufferLen, offset, buffer);
				END;

			END;
			IF Debug.StrongChecks THEN CheckBuffer(bufferLen, offset, buffer); END;
			status := ExecuteTransfer(bufferLen, offset, buffer, copy);
			RETURN status;
		END Transfer;

		(* Data structure consistency check *)
		PROCEDURE CheckBuffer(length, ofs : LONGINT; VAR buffer : Usbdi.Buffer);
		VAR i : ADDRESS;
		BEGIN
			IF Debug.StrongChecks THEN
				ASSERT(tdBuffer # NIL);
				(* TD buffer MUST be physically contiguous *)
				i := Machine.PhysicalAdr(ADDRESSOF(tdBuffer[0]), tdBufferLen);
				IF i = Machine.NilAdr THEN HALT(99); END;
				(* TD list MUST be located in TD buffer *)
				ASSERT((firstTD >= ADDRESSOF(tdBuffer[0])) & (firstTD <= ADDRESSOF(tdBuffer[tdBufferLen-1])));
				ASSERT((lastTD >= ADDRESSOF(tdBuffer[0])) & (lastTD <= ADDRESSOF(tdBuffer[tdBufferLen-1])));
			END;
		END CheckBuffer;

		(** For control transfers (only for Control Pipes) *)
		PROCEDURE Request*(bmRequestType : SET;  bRequest, wValue, wIndex, wLength : LONGINT; VAR buffer : Usbdi.Buffer) : Usbdi. Status;
		VAR dir : LONGINT; copy : BOOLEAN;
		BEGIN {EXCLUSIVE}
			ASSERT(type = PipeControl);
			ASSERT(LEN(buffer) >= wLength);
			IF message = NIL THEN NEW(message); END;
			message[0] := CHR(SYSTEM.VAL(LONGINT, bmRequestType));
			message[1] := CHR(bRequest);
			message[2] := CHR(wValue);
			message[3] := CHR(LSH(wValue, -8));
			message[4] := CHR(wIndex);
			message[5] := CHR(LSH(wIndex,-8));
			message[6] := CHR(wLength);
			message[7] := CHR(LSH(wLength, -8));
			IF bmRequestType * Usbdi.ToHost # {} THEN dir := In; ELSE 	dir := Out; END;
			IF Debug.Trace & Debug.traceControl THEN ShowMessage(wLength, dir, message); END;

			transferLen := wLength; status := Usbdi.InProgress; errors := NoErrors;

			IF controller.LinkTDsAllowed(SELF) THEN

				IF ~controller.DMAchaining & NeedSWScatterGather(dir, wLength, 0, buffer, copy) THEN
					IF timeout = 0 THEN
						KernelLog.String("UsbHcdi: Non-blocking transfer to physically non-contiguous buffer not allowed."); KernelLog.Ln;
						status := Usbdi.Error; errors := Internal;  RETURN status;
					END;
					controller.ScheduleControl(SELF, dir, message, wLength, sgBuffer^);
				ELSE
					controller.ScheduleControl(SELF, dir, message, wLength, buffer);
				END;
				IF Debug.StrongChecks THEN CheckBuffer(wLength, 0, buffer); END;
				status := ExecuteTransfer(wLength, 0, buffer, copy);

			END;
			RETURN status;
		END Request;

		PROCEDURE ClearHalt*(): BOOLEAN;
		CONST FsEndpointHalt = 0; SrClearFeature = 1;
		VAR res : BOOLEAN;
		BEGIN
			IF Debug.Trace & Debug.tracePipes THEN
				KernelLog.String("UsbHcdi: Clearhalt Pipe"); KernelLog.String(" Adr: ");KernelLog.Int(address, 0);
				KernelLog.String(" Ep: "); KernelLog.Int(endpoint, 0); KernelLog.Ln;
			END;
			controller.ClearHalt(SELF);
			res := device.Request(Usbdi.ToDevice + Usbdi.Standard + Usbdi.Endpoint, SrClearFeature, FsEndpointHalt, endpoint, 0, Usbdi.NoData) = Usbdi.Ok;
			IF res THEN dataToggle := FALSE; END;
			RETURN res;
		END ClearHalt;

		PROCEDURE IsHalted*() : BOOLEAN;
		CONST SrGetStatus = 0; Halted = {0};
		VAR buffer : Usbdi.BufferPtr; status : SET;
		BEGIN
			IF Debug.Trace & Debug.tracePipes THEN
				KernelLog.String("UsbHcdi: Get endpoint status for Adr: "); KernelLog.Int(address, 0);
				KernelLog.String(", Ep: "); KernelLog.Int(endpoint, 0); KernelLog.Ln;
			END;
			NEW(buffer, 2);
			IF device.Request(Usbdi.ToHost + Usbdi.Standard + Usbdi.Endpoint, SrGetStatus , 0, endpoint MOD 16, 2, buffer^) = Usbdi.Ok THEN
				status := SYSTEM.VAL(SET, ORD(buffer[0]) + ORD(buffer[1])*100H);
				RETURN status * Halted # {};
			END;
			RETURN FALSE;
		END IsHalted;

		PROCEDURE GetActLen*() : LONGINT;
		BEGIN
			RETURN actLen;
		END GetActLen;

		PROCEDURE SetTimeout*(timeout : LONGINT);
		BEGIN
			SELF.timeout := timeout;
		END SetTimeout;

		PROCEDURE GetStatus*(VAR len : LONGINT) : Usbdi.Status;
		BEGIN
			controller.UpdatePipeStatus(SELF); len := actLen;
			RETURN status;
		END GetStatus;

		PROCEDURE SetCompletionHandler*(handler: Usbdi.CompletionHandler);
		BEGIN
			ioc := TRUE; (* set Interrupt On Completion Bit in TD's *)
			mode := Usbdi.MinCpu;
			IF completionHandlerCaller # NIL THEN
				completionHandlerCaller.Terminate;
			END;
			NEW(completionHandlerCaller, SELF, handler);
			controller.AddCompletionHandler(SELF);
		END SetCompletionHandler;

		(**
		 * Calculate Bus Transaction Times (USB2.0, p. 63).
		 * When the USB System software allows a new pipe to be created for the bus, it must calculate how much
		 * bus time is required for a given transaction. The results of these calculations are used to determine whether
		 * a transfer or pipe creation can be supported in a given USB configuration.
		 * @return: Time in nanoseconds the transactions will take, -1: Error
		 *)
(*		PROCEDURE GetBusTime*() : REAL;
		VAR time : REAL;

			(* Bitstuffing inserts 1 Bit for 6 Bits in worst case, so in a worst case scenario, the amount of data
			 * to be sent over the bus would increase by a factor of 7/6 *)
			PROCEDURE BitStuffTime(lenData : LONGINT) : REAL;
			BEGIN
				RETURN 8.0 * 7.0 * lenData / 6.0;
			END BitStuffTime;
		BEGIN
			IF speed = HighSpeed THEN
				IF (type = PipeIsochronous) THEN (* Isochronous transfer (No handshake) *)
					time := (55 * 8 * 2.083) + (2.083 * ENTIER(3.167 + BitStuffTime(transferLen))) + hostDelay;
				ELSE (* Non-isochronous transfer (Handshake included) *)
					time := (38 * 8 * 2.832) + (2.083 * ENTIER(3.167 + BitStuffTime(transferLen))) + hostDelay;
				END;
			ELSIF speed = FullSpeed THEN
				time := 83.54 * ENTIER(3.167 + BitStuffTime(transferLen)) + hostDelay;
				IF (type = PipeIsochronous) THEN (* Isochronous transfer (No handshake) *)
					IF direction = In THEN
						time := time + 7268;
					ELSE
						time := time + 6265;
					END;
				ELSE (* Non-isochronous transfer (Handshake included) *)
					time := time + 9107;
				END;
			ELSIF speed = LowSpeed THEN
				IF (direction = In) THEN
					time := 64060 + (2 * hubLsSetup) + (676.67 * ENTIER(3.167 + BitStuffTime(transferLen))) + hostDelay;
				ELSE (* Non-isochronous transfer *)
					time := 64107 + (2 * hubLsSetup) + (667.0 * ENTIER(3.167 + BitStuffTime(transferLen))) + hostDelay;
				END;
			END;
			RETURN time;
		END GetBusTime;
*)
		(* Display textual representation of the transfer that will be executed. *)
		PROCEDURE ShowTransfer(bufferLen, offset : LONGINT);
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("UsbHcdi: ");
			CASE type OF
				PipeControl : KernelLog.String("Control Transfer???:");
				| PipeBulk : KernelLog.String("Bulk Transfer:");
				| PipeInterrupt : KernelLog.String("Interrupt Transfer:");
				| PipeIsochronous : KernelLog.String("Isochronous Transfer:");
			ELSE KernelLog.String("Unknown transfer type");
			END;
			KernelLog.String(" Adr: "); KernelLog.Int(address, 0);
			KernelLog.String(" Endpoint: "); KernelLog.Int(endpoint, 0);
			KernelLog.String(" Length: "); KernelLog.Int(bufferLen, 0); KernelLog.String(" Bytes: ");
			END;
		END ShowTransfer;

		PROCEDURE ShowMessage(bufferLen, direction : LONGINT; msg : ControlMessage);
		VAR i : LONGINT;
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("UsbHcdi: Control Transfer: ");
			IF direction = In THEN KernelLog.String("IN");
			ELSIF direction = Out THEN KernelLog.String("OUT");
			ELSE KernelLog.String("ERROR");
			END;
			KernelLog.String(" Adr: "); KernelLog.Int(address, 0);
			KernelLog.String(" Endpoint: "); KernelLog.Int(endpoint, 0);
			KernelLog.String(" Length: "); KernelLog.Int(bufferLen, 0); KernelLog.String(" Bytes: ");
			KernelLog.String(" CtrlMsg: "); 	FOR i := 0 TO 7 DO KernelLog.Hex(ORD(msg[i]), -2); KernelLog.String(" "); END;
			END;
		END ShowMessage;

		PROCEDURE ShowData(CONST buffer : Usbdi.Buffer);
		VAR i : LONGINT;
		BEGIN
			IF Debug.Trace THEN
			KernelLog.String("[DATA: ");
			FOR i := 0 TO LEN(buffer)-1 DO
				KernelLog.Hex(ORD(buffer[i]), -2);
				IF i < LEN(buffer)-1 THEN KernelLog.Char(" "); END;
			END;
			KernelLog.Char("]");
			END;
		END ShowData;

		PROCEDURE Show*(detailed : BOOLEAN);
		BEGIN
			IF Debug.Trace THEN
			CASE type OF
				| PipeControl: KernelLog.String(" Control ");
				| PipeInterrupt : KernelLog.String(" Interrupt ");
				| PipeBulk : KernelLog.String(" Bulk ");
				| PipeIsochronous : KernelLog.String(" Isochronous ");
			ELSE
				KernelLog.String("Unknown("); KernelLog.Int(type, 0); KernelLog.String(") ");
			END;
			CASE direction OF
				| Out: KernelLog.String("OUT");
				| In : KernelLog.String("IN");
			ELSE
				KernelLog.String("IN/OUT");
			END;
			KernelLog.String(" Pipe:"); KernelLog.String(" Adr: "); KernelLog.Int(address, 0); KernelLog.String(" Ep: "); KernelLog.Int(endpoint, 0);
			KernelLog.String(" ");
			IF ioc THEN KernelLog.String("[IOC]"); END;
			IF completionHandlerCaller # NIL THEN KernelLog.String("[Handler]"); END;
			IF irqActive THEN KernelLog.String("[IRQ_ACTIVE]"); END;
			IF speed = LowSpeed THEN KernelLog.String("[LowSpeed]");
			ELSIF speed = FullSpeed THEN KernelLog.String("[FullSpeed]");
			ELSIF speed = HighSpeed THEN KernelLog.String("[HighSpeed]");
			ELSE KernelLog.String("[ERROR: Not speed specified]");
			END;
			KernelLog.Ln;
			KernelLog.String("    Queue: "); KernelLog.Hex(queue, 8); KernelLog.String("H");
			KernelLog.String(", QH: "); KernelLog.Hex(qh, 8); KernelLog.String("H");
			KernelLog.String(", firstTD: "); KernelLog.Hex(firstTD, 8); KernelLog.String("H");
			KernelLog.String(", lastTD: "); KernelLog.Hex(lastTD, 8); KernelLog.String("H");
			KernelLog.Ln;
			IF detailed THEN
				IF type = PipeInterrupt THEN KernelLog.String("    IRQ Interval: "); KernelLog.Int(irqInterval, 0); KernelLog.String("ms, "); ELSE KernelLog.String("    "); END;
				KernelLog.String("Timeout: "); KernelLog.Int(timeout, 0); KernelLog.String("ms ");
				KernelLog.String(", MaxPacketSize: "); KernelLog.Int(maxPacketSize, 0); KernelLog.String(" Bytes");
				KernelLog.String(", MaxRetries: "); KernelLog.Int(maxRetries, 0);
				KernelLog.String(", Mode: ");
				CASE mode OF
					|Usbdi.Normal: KernelLog.String("Normal");
					|Usbdi.MaxPerformance: KernelLog.String("MaxPerformance");
					|Usbdi.MinCpu: KernelLog.String("MinCPU");
				ELSE
					KernelLog.String("Undefined ("); KernelLog.Int(mode, 0); KernelLog.String(")");
				END;
				KernelLog.String(", Last status: "); ShowStatus(status);
				KernelLog.String(", Last errors: "); ShowErrors(errors); KernelLog.Ln;
				IF type # PipeIsochronous THEN
					KernelLog.String("    TD buffer: "); KernelLog.Int((LEN(tdBuffer) - (tdBase - ADDRESSOF(tdBuffer[0]))) DIV 16 , 0); KernelLog.String(" TD's ");
					KernelLog.Ln; KernelLog.Ln;
					controller.ShowPipe(SELF);
				ELSE
					KernelLog.String("    ITD chain: "); KernelLog.Ln;
					(* controller.ShowItds(SELF); *)
				END;
				KernelLog.Ln;
			END;
			END;
		END Show;
	END Pipe;

TYPE
	Registry= OBJECT(Plugins.Registry) END Registry;

VAR
	controllerCount : LONGINT; (* Only used for name creation - does not necessary reflect the actual HC count *)
	controllers- : (*Plugins.*)Registry;

(** Assign a name to the host controller and add it to the controllers registry *)
PROCEDURE RegisterHostController*(hcd : Hcd; CONST description : Plugins.Description);
VAR name : Plugins.Name; res : LONGINT;
BEGIN {EXCLUSIVE}
	name := "USBHC"; name[5] := CHR(controllerCount + 48); name[6] := 0X;
	hcd.SetName(name); hcd.desc := description;
	(* Register the host controller as AosPlugin *)
	controllers.Add(hcd, res);
	IF res # Plugins.Ok THEN (* ERROR: registering the host controller failed, should not happen *)
		KernelLog.Enter; KernelLog.String("UsbHcdi: Error: Couldn't add host controller to registry."); KernelLog.Exit;
	ELSE
		INC(controllerCount);
	END;
END RegisterHostController;

(** Remove all controllers with the specified description from the controllers registry *)
PROCEDURE UnRegisterHostControllers*(CONST description : Plugins.Description);
VAR table : Plugins.Table; hcd : Hcd; i : LONGINT;
BEGIN {EXCLUSIVE}
	controllers.GetAll(table);
	IF table # NIL THEN
		FOR i := 0 TO LEN(table)-1 DO
			hcd := table[i] (Hcd);
			IF hcd.desc = description THEN
				hcd.Cleanup;
				controllers.Remove(hcd);
			END;
		END;
	END;
END UnRegisterHostControllers;

(** Copy data from array to array *)
PROCEDURE Copy(VAR from, to: ARRAY OF CHAR; fofs, tofs, len: LONGINT);
BEGIN
	IF Debug.Trace & Debug.traceCopying THEN KernelLog.String("UsbHcdi: SG: Copying "); KernelLog.Int(len, 0); KernelLog.String(" Bytes."); KernelLog.Ln; END;
	IF len > 0 THEN
		ASSERT((fofs+len <= LEN(from)) & (tofs+len <= LEN(to)));
		SYSTEM.MOVE(ADDRESSOF(from[fofs]), ADDRESSOF(to[tofs]), len);
	END;
END Copy;

PROCEDURE Align*(address: ADDRESS; size: LONGINT): ADDRESS;
BEGIN
	RETURN address + (-address) MOD size;
END Align;

(**
 * Returns an AlignMemSpace with: memspace.data[memspace.base] is the first, <alignment>-aligned element of an
 * array of LONGINTs of the size <size>;  parameters in bytes; alignmet has to be a power of two
 *)
PROCEDURE GetAlignedMemSpace*(size, alignment : LONGINT ) : AlignedMemSpace;
VAR memspace : AlignedMemSpace; base, adr: ADDRESS;  len: SIZE;
BEGIN
	ASSERT(alignment >= 4);
	NEW(memspace);
	len := (size +  alignment) DIV 4;
	NEW(memspace.data, len ); (* so we will definitly find a <alignment>-aligned memory space of the size <size> *)

	adr := ADDRESS OF memspace.data[0];
	(* alignment *)
	base := adr + (-adr) MOD alignment;
	ASSERT(base MOD alignment = 0);

	memspace.base := (base - adr) DIV 4;

	ASSERT(ADDRESS OF memspace.data[memspace.base] = base);

	RETURN memspace;
END GetAlignedMemSpace;

(** Display textual representation of the USB tranfer status bits defined in Usbdi.Mod  *)
PROCEDURE ShowStatus*(status : Usbdi.Status);
BEGIN
	IF Debug.Trace THEN
	IF status = Usbdi.Ok THEN KernelLog.String("[Ok]"); END;
	IF status = Usbdi.ShortPacket THEN KernelLog.String("[ShortPacket]"); END;
	IF status = Usbdi.Stalled THEN KernelLog.String("[Stalled]"); END;
	IF status = Usbdi.InProgress THEN KernelLog.String("[InProgress]"); END;
	IF status = Usbdi.Error THEN KernelLog.String("[Error]"); END;
	IF status = Usbdi.Disconnected THEN KernelLog.String("[Disconnected]"); END;
	END;
END ShowStatus;

PROCEDURE ShowErrors*(errors : SET);
BEGIN
	IF Debug.Trace THEN
	IF errors = NoErrors THEN KernelLog.String("[NoErrors]"); END;
	IF errors * ShortPacket # {} THEN KernelLog.String("[ShortPacket]"); END;
	IF errors * Stalled # {} THEN KernelLog.String("[Stalled]"); END;
	IF errors * InProgress # {} THEN KernelLog.String("[InProgress]"); END;
	IF errors * Nak # {} THEN KernelLog.String("[Nak]"); END;
	IF errors * Crc # {} THEN KernelLog.String("[Crc]"); END;
	IF errors * Timeout # {} THEN KernelLog.String("[Timeout]"); END;
	IF errors * CrcTimeout # {} THEN KernelLog.String("[CRC/Timeout]"); END;
	IF errors * BitStuff # {} THEN KernelLog.String("[Bitstuff]"); END;
	IF errors * Databuffer # {} THEN KernelLog.String("[Databuffer]"); END;
	IF errors * Babble # {} THEN KernelLog.String("[Babble]"); END;
	IF errors * Internal # {} THEN KernelLog.String("[Internal]"); END;
	IF errors * Disconnected # {} THEN KernelLog.String("[Disconnected]"); END;
	IF errors * UnexpectedPid # {} THEN KernelLog.String("[UnexpectedPid]"); END;
	IF errors * TransferTooLarge # {} THEN KernelLog.String("[TransferTooLarge]"); END;
	IF errors * PidCheckFailure # {} THEN KernelLog.String("[PidCheckFailure]"); END;
	IF errors * DataToggleMismatch # {} THEN KernelLog.String("[DatatoggleMismatch]"); END;
	IF errors * DeviceNotResponding # {} THEN KernelLog.String("[DeviceNotResponding]"); END;
	IF errors * LinkTDsFailed # {} THEN KernelLog.String("[TDLinkError]"); END;
	IF errors * OutOfTDs  # {} THEN KernelLog.String("[OutOfTDs]"); END;
	END;
END ShowErrors;

(** Display textual represenation of the port status bits defined in UsbHcdi.Mod *)
PROCEDURE ShowPortStatus*(status : SET);
BEGIN
	IF Debug.Trace THEN
	IF status * PortStatusEnabled # {} THEN KernelLog.String("[Enabled]"); ELSE KernelLog.String("[Disabled]"); END;
	IF status * PortStatusDevicePresent # {} THEN
		IF status * PortStatusLowSpeed # {} THEN KernelLog.String("[LowSpeed]");
		ELSIF status * PortStatusFullSpeed # {} THEN KernelLog.String("[FullSpeed]");
		ELSIF status * PortStatusHighSpeed # {} THEN KernelLog.String("[HighSpeed]");
		ELSE
			KernelLog.String("[ERROR:Device connected but no speed indication, port enabled?]");
		END;
	END;
	IF status * PortStatusReset # {} THEN KernelLog.String("[Reset]"); END;
	IF status * PortStatusDevicePresent # {} THEN KernelLog.String("[DevicePresent]"); END;
	IF status * PortStatusError # {} THEN KernelLog.String("[Error]"); END;
	IF status * PortStatusConnectChange # {} THEN KernelLog.String("[ConnectChange]"); END;
	IF status * PortStatusSuspended # {} THEN KernelLog.String("[Suspended]"); END;
	IF status * PortStatusOverCurrent # {} THEN KernelLog.String("[OverCurrent]"); END;
	IF status * PortStatusPowered # {} THEN KernelLog.String("[Powered]"); END;
	IF status * PortStatusEnabledChange # {} THEN KernelLog.String("[EnabledChange]"); END;
	IF status * PortStatusSuspendChange # {} THEN KernelLog.String("[SuspendChange]"); END;
	IF status * PortStatusOverCurrentChange # {} THEN KernelLog.String("[OverCurrentChange]"); END;
	IF status * PortStatusWakeOnOvercurrent # {} THEN KernelLog.String("[WakeOnOvercurrent]"); END;
	IF status * PortStatusWakeOnDisconnect # {} THEN KernelLog.String("[WakeOnDisconnect]"); END;
	IF status * PortStatusWakeOnConnect # {} THEN KernelLog.String("[WakeOnConnect]"); END;
	IF status * PortStatusTestControl # {} THEN KernelLog.String("[TestControl]"); END;
	IF status * PortStatusIndicatorControl # {} THEN KernelLog.String("[IndicatorControl]"); END;
	IF status * PortStatusPortOwner # {} THEN KernelLog.String("[PortOwner]"); END;
	END;
END ShowPortStatus;

PROCEDURE Cleanup;
BEGIN
	Plugins.main.Remove(controllers);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(controllers, "UsbHcdi","USB host controller drivers");
END UsbHcdi.