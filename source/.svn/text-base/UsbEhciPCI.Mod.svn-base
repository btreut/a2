(**
 * This module provides installation services for EHCI controllers connected with PCI.
 * This service was separated from the EHCI HCD to improve code reuse with EHCI controllers wired directly to CPUs, as it
 * is the case in several ARM systems.
 *)
MODULE UsbEhciPCI; (** AUTHOR "Timothée Martiel"; PURPOSE "Installation of EHCI controller connected through PCI."; *)

IMPORT SYSTEM, Machine, Kernel, KernelLog, PCI, Debug := UsbDebug, UsbHcdi, UsbEhci;
CONST
	(* If TRUE, the HC driver just continues if it could not get the ownership of the HC *)
	OverrideHcOwnership = TRUE;

	(* Legacy support related constants *)
	bOwnedByBios * = {16};
	bRequestOwnership * = {24};
	USBCapabilityID * = 01H; (* Capability ID of USB Legacy Support Extended Capability *)

TYPE
	EnhancedHostController = OBJECT (UsbEhci.EnhancedHostController)
		(* Release the HC ownership semaphore; eecp is the EHCI Extended Capability Pointer *)
		PROCEDURE ReleaseHcOwnerShip(bus, device, function, eecp : LONGINT);
		VAR register, res : LONGINT; usblegsup : SET;
		BEGIN
			(* 00H: No capability list; > 40H to maintain consistency with PCI header *)
			IF (eecp > 40H) THEN
				res :=  PCI.ReadConfigDword(bus, device, function, eecp, register);
				ASSERT(res = PCI.Done);
				IF (register MOD 256 = USBCapabilityID) THEN (* USB legacy support available *)
					usblegsup := SYSTEM.VAL(SET, register);
					IF usblegsup * bRequestOwnership # {} THEN
						IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbEhci: Release HC ownership semaphore... "); END;
						res := PCI.WriteConfigByte(bus, device, function, eecp + 3, SYSTEM.VAL(LONGINT, LSH(usblegsup - bRequestOwnership, -24)));
						ASSERT(res = PCI.Done);
					END;
				END;
			END;
		END ReleaseHcOwnerShip;
	END EnhancedHostController;

	(*
	 * Get the ownership of the host controller.
	 * If the EHCI Extended Capability Pointer (EECP) in the Host Controller Capabilities Parameters register (HCCPARAM) has
	 * a non-zero value, its value indicates the presence of EHCI Extended Capabilities Registers. At offset EECP + 0H in
	 * the PCI configuration space, we find the USB Legacy Support Extended Capability (USBLEGSUP), which is used to coordinate
	 * ownership of the EHCI host controller by the pre-OS software and the operating system software.
	 * IF the USBLEGSUP register is not available, this procedure simply returns TRUE since there is no legacy support. Otherwise,
	 * we request HC ownership and wait for the pre-OS software to acknowledge.
	 * Note: At the time this driver was implemented, the current EHCI specification did not specify any other Extended Capabilities
	 *           than USB Legacy Support. The capability registers from, however, a linked list, so more capabilities could be added in
	 *           the future.
	 * @param bus PCI bus number of HC
	 * @param device PCI device number of HC
	 * @param function PCI function number of HC
	 * @param iobase Virtual I/O base address of the HC
	 * @return TRUE, if system software taken over the HC, false otherwise
	 *)
	PROCEDURE GetHcOwnerShip(bus, device, function: LONGINT; iobase : ADDRESS) : BOOLEAN;
	CONST
		MaxWaits = 1000; (* Timeout for pre-OS to system software HC handoff [ms], not specified by EHCIspec *)
	VAR
		timer : Kernel.Timer;
		usblegsup : SET;
		eecp, reg, res, waits : LONGINT;
		hcOwnedByOS : BOOLEAN;
	BEGIN
		(* Get the HC Capabilities Parameters register *)
		reg := SYSTEM.GET32(iobase + UsbEhci.HcCapCparams);

		(* Get the EHCI Extended Capabilities Pointer (EECP) *)
		eecp := SYSTEM.VAL(LONGINT, LSH(SYSTEM.VAL(SET, reg) * {8..15}, - 8));

		(* 00H: No capability list; > 40H to maintain consistency with PCI header *)
		IF eecp > 40H THEN
	 		(* USB Legacy Support registers are available. eecp is an offset into the PCI configuration space	*)
			(* pointing to the USB Legacy Support Extended Capability, which we load now.  				*)
			IF Debug.Trace & Debug.traceInit THEN
				KernelLog.String("UsbEhci: EHCI Extended Capabilities at offset "); KernelLog.Hex(eecp, -2); KernelLog.Char("H"); KernelLog.Ln;
			END;
	      		res :=  PCI.ReadConfigDword(bus, device, function, eecp, reg);
			IF (res = PCI.Done) & (reg MOD 256 = USBCapabilityID) THEN (* USB legacy support available *)
				IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbEhci: Legacy support capability found."); KernelLog.Ln; END;
				usblegsup := SYSTEM.VAL(SET, reg);
				IF usblegsup * bOwnedByBios # {} THEN
					IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbEhci: Request ownership of host controller... "); END;
					(* The value of the USB Legacy Support Extented Capability keeps its value when soft booting. If we set it before, 	*)
					(* clear the bRequestOwnership bit now 																		*)
					IF usblegsup * bRequestOwnership # {} THEN
						KernelLog.Enter; KernelLog.String("UsbEhci: Warning: controller already owns HC."); KernelLog.Exit;
						res := PCI.WriteConfigByte(bus, device, function, eecp + 3, SYSTEM.VAL(LONGINT, LSH(usblegsup - bRequestOwnership, -24)));
						ASSERT(res = PCI.Done);
					END;

					(* Set HC OS Owned Semaphore to indicate that we (want to) control the host controller... *)
					res := PCI.WriteConfigByte(bus, device, function, eecp + 3, SYSTEM.VAL(LONGINT, LSH(usblegsup + bRequestOwnership, -24)));

					hcOwnedByOS := FALSE; waits := 0; NEW(timer);
					WHILE ~hcOwnedByOS & (res = PCI.Done) & (waits < MaxWaits) DO
						(* The pre-OS software should clear the HC BIOS Owned Semaphore bit... *)
						res := PCI.ReadConfigDword(bus, device, function, eecp, reg);
						usblegsup := SYSTEM.VAL(SET, reg);
						IF (usblegsup * bRequestOwnership # {}) & (usblegsup * bOwnedByBios = {}) THEN
							hcOwnedByOS := TRUE;
						ELSE
							INC(waits, 1); timer.Sleep(1);
						END;
					END;
					IF ~hcOwnedByOS THEN
						KernelLog.Enter; KernelLog.String("UsbEhci: Pre-OS to system software handoff failed."); KernelLog.Exit;
						IF OverrideHcOwnership THEN
							KernelLog.Enter; KernelLog.String("UsbEhci: Override Pre-OS... take over HC!"); KernelLog.Exit;
							RETURN TRUE;
						ELSE
							RETURN FALSE;
						END;
					END;
					IF Debug.Trace & Debug.traceInit THEN KernelLog.String("done."); KernelLog.Ln; END;
				END;
			ELSE
				IF Debug.Level >= Debug.Errors THEN KernelLog.String("UsbEhci: PCI error: Couldn't get USB Legacy Support register."); KernelLog.Ln; END;
				RETURN FALSE;
			END;
		END;
		RETURN TRUE;
	END GetHcOwnerShip;

	(*
	 * Find EHCI host controllers on the PCI bus, create correspondig EHCI controller objects and register them in the
	 * EHCI USB host controllers registry. For EHCI host controllers, this procedure also takes care of the handoff from
	 * Pre-OS software to the host system software.
	 *)
	PROCEDURE PCIFindEhci;
	CONST
		EhciClassCode = 0C0320H;
		PCIStatusErrorMask = {24,27,28,29,30,31};
	VAR
		hostController : EnhancedHostController;
		bus, device, function : LONGINT;
		iobasePhys, irq : LONGINT;
		iobaseVirt: ADDRESS;
		pciCmdStsReg, sbrn  : LONGINT;
		index : LONGINT;
		res: LONGINT;
	BEGIN
		IF Debug.Trace & Debug.traceInit THEN KernelLog.String("UsbEhci: Looking for PCI Enhanced USB Host Controllers..."); KernelLog.Ln; END;
		(* Traverse all USB EHCI Host Controllers of all PCI busses in the system *)
		index := 0;
		WHILE PCI.FindPCIClassCode(EhciClassCode, index, bus, device, function) = PCI.Done DO
			res := PCI.ReadConfigDword(bus, device, function, PCI.CmdReg, pciCmdStsReg); ASSERT(res = PCI.Done);

			IF SYSTEM.VAL(SET, pciCmdStsReg) * PCIStatusErrorMask # {} THEN
				IF Debug.Level >= Debug.Warnings THEN KernelLog.String("UsbEhci: Warning: PCI device is in error ."); KernelLog.Ln; END;
			END;

			IF PCI.Enable(PCI.MemorySpace + PCI.BusMaster, bus, device, function) = PCI.Done THEN

				res := PCI.ReadConfigByte(bus, device, function, PCI.IntlReg, irq); ASSERT(res = PCI.Done);
				res := PCI.ReadConfigDword(bus, device, function, PCI.Adr0Reg, iobasePhys); ASSERT(res = PCI.Done);

				IF SYSTEM.VAL(SET, iobasePhys) * {0} # {} THEN
					KernelLog.String("UsbEhci: Error: Operational Register are not memory mapped"); KernelLog.Ln;
				ELSIF SYSTEM.VAL(SET, iobasePhys) * {1,2,3} # {} THEN
					KernelLog.String("UsbEhci: Error: Operational Register are not correctly mapped "); KernelLog.Ln;
				ELSIF irq = 0 THEN
					KernelLog.String("UsbEhci: Error: Please enable interrupts for all USB Host Controllers."); KernelLog.Ln;
				ELSE
					iobasePhys := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, iobasePhys) * {4..31});
					(* Check the Serial Bus Release Number; 20H expected *)
					res := PCI.ReadConfigDword(bus, device, function, 60H, sbrn); ASSERT(res = PCI.Done);

	     				IF (sbrn MOD 256) # 20H THEN
	     					KernelLog.Enter; KernelLog.String("UsbEhci: Error: Serial bus release number not supported."); KernelLog.Exit;
	     				ELSE
	     					(* Map the capabiliy registers and the operational registers to memory *)
	     					Machine.MapPhysical(iobasePhys, 4096, iobaseVirt);
						IF GetHcOwnerShip(bus, device, function, iobaseVirt) THEN
							NEW(hostController, bus, device, function);
							IF hostController.Init(Machine.Ensure32BitAddress (iobaseVirt), irq) THEN
								(* Host controller has been initialized and started successfully *)
								IF Debug.Verbose THEN
									KernelLog.Enter;
									KernelLog.String("UsbEhci: Initialised USB Enhanced Host Controller at base 0");
									KernelLog.Hex(iobasePhys, 8); KernelLog.String(", Irq: "); KernelLog.Int(irq, 0);
									KernelLog.Exit;
								END;
								(* Set the value for the Port Wake Capability Register *)
								hostController.pwcr := LSH(sbrn, -16);
								UsbHcdi.RegisterHostController(hostController, UsbEhci.Description);
							ELSE (* ERROR: host controller initialization failed *)
								KernelLog.Enter;
								KernelLog.String("UsbEhci: Cannot init USB Enhanced Host Controller at base 0");
								KernelLog.Hex(iobasePhys, 8); KernelLog.String(", Irq: "); KernelLog.Int(irq, 0);
								KernelLog.Exit;
							END;
						ELSE
							KernelLog.Enter; KernelLog.String("UsbEhci: Couldn't get ownership of host controller."); KernelLog.Exit;
						END;
					END;
				END;
			ELSE
				KernelLog.Enter; KernelLog.String("UsbEhci: Could not enable bus mastering or memory space access."); KernelLog.Exit;
			END;
			INC(index);
		END; (* End while loop *)
	END PCIFindEhci;

	(** Installs EHCI controllers connected through PCI. *)
	PROCEDURE Install*;
	END Install;

BEGIN
	(* Find, init and start all compatible PCI EHCI USB host controllers and register them in the UsbHcdi.controllers registry *)
	PCIFindEhci;
END UsbEhciPCI.
