MODULE NetworkMii; (** AUTHOR "staubesv"; PURPOSE "Media Independent Interface (MII) management interface support"; *)
(**
 * The Media Independent Interface (MII) is an interface between the MAC Layer and the PHY. The MII Management Interface's purpose is
 * to control the PHY and gather status from the PHY. This module defines constants and implements some basic functionality for both
 * the MII management interface and its superset GMII.
 *
 * References:
 *
 *	[1] IEEE Std 802.3-2005 Edition, www.ieee.org
 *
 * History:
 *
 *	03.11.2006	First release (staubesv)
 *
 * Status:
 *
 *	BETA
 *		- 1GB auto-negotiation not yet supported
 *		- Handling of devices that don't support auto-negotiation not supported
 *)

IMPORT
	SYSTEM, KernelLog, Objects, Kernel, Network;

CONST

	Ok* = 0;
	Unsupported* = 1;
	ParametersInvalid* = 2;
	NotAvailable* = 3;
	ErrorRead* = 5;
	ErrorWrite* = 6;
	Timeout* = 7;

	AutoNegotiationTimeout = 1000; (* ms *)

	TraceAutoNegotiation = {0};
	TraceCommands = {1};

	Trace = {};

	Debug = TRUE;

	ModuleName = "NetworkMii";

	(** MII register offsets *)

	(** Basic Registers *)
	BMCR* = 0H;		(** Basic Mode Control Register *)
	BMSR* = 1H;		(** Basic Mode Status Register *)

	BMESR* = 15H;		(** Basic Mode Extended Status Register (GMII only) *)

	(** Extended Registers *)
	PHYIDR1* = 2H; 		(** PHY Identifier Register 1 *)
	PHYIDR2* = 3H;		(** PHY Identifier Register 2 *)
	ANAR* = 4H;		(** Auto-Negotiation Advertisement Register *)
	ANLPAR* = 5H;		(** Auto-Negotiation Link Partner Ability Register *)
	ANER* = 6H;		(** Auto-Negotiation Expansion Register *)
	ANNPTR* = 7H;		(** Auto-Negotiation Next Page Transmit Register *)
	ANLPRNPR* = 8H;	(** Auto-Negotiation Link Partner Received Next Page Register *)
	MSCR* = 9H;		(** Master-Slave Control Register *)
	MSSR* = 10H;		(** Master-Slave Status Register *)
	PSECR* = 11H;		(** PSE Control Register *)
	PSESR* = 12H;		(** PSE Status Register *)
	MMDACR* = 13H;	(** MMD Access Control Register *)
	MMDAADR* = 14H;	(** MMD Access Address Data Register *)

	(* 16H-31H: Vendor-Specific extended registers *)

	(* Basic Mode Control Register (BMCR) *)
	BMCR_Reset* = {15}; (* self-clearing, default: 0 *)
	BMCR_Loopback* = {14}; (* default: 0 *)
	BMCR_SpeedSelectionLsb* = {13};
	BMCR_AutoNegotiationEnable* = {12}; (* default: 1 *)
	BMCR_PowerDown* = {11}; (* default: 0 *)
	BMCR_Isolate* = {10}; (* default: 0 *)
	BMCR_RestartAutoNegotiation* = {9}; (* self-clearing *)
	BMCR_DuplexMode* = {8};
	BMCR_CollisionTest* = {7}; (* default: 0 *)
	BMCR_SpeedSelectionMsb* = {6};
	BMCR_UnidirectionalEnable* = {5};
	BMCR_Reserved* = {0..4}; (* write as zero *)

	(* Basic Mode Status Register (BMSR), all fields are read-only *)
	BMSR_100BaseT4* = {15};
	BMSR_100BaseTXFullDuplex* = {14};
	BMSR_100BaseTXHalfDuplex* = {13};
	BMSR_10BaseTFullDuplex* = {12};
	BMSR_10BaseTHalfDuplex* = {11};
	BMSR_100BaseT2FullDuplex* = {10};
	BMSR_100BaseT2HalfDuplex* = {9};
	BMSR_ExtendedStatus* = {8}; (* Extended status information in register 15 (BMESR) *)
	BMSR_UnidirectionalAbility* = {7};
	BMSR_MfPreambleSuppression* = {6};
	BMSR_AutoNegotiationComplete* = {5};
	BMSR_RemoteFault* = {4};
	BMSR_AutoNegotiationAbility* = {3};
	BMSR_LinkStatus* = {2};
	BMSR_JabberDetect* = {1};
	BMSR_ExtendedCapability* = {0}; (* Extended register available *)

	(* Basic Mode Extended Status Register (BMESR), all fields are read-only *)
	BMESR_1000BaseXFullDuplex* = {15};
	BMESR_1000BaseXHalfDuplex* = {14};
	BMESR_1000BaseTFullDuplex* = {13};
	BMESR_1000BaseTHalfDuplex* = {12};
	BMESR_Reserved* = {0..11};

	(* PHY Identifier Register 1 (PHYIDR1) *)
	PHYIDR1_OuiMSB* = {0..15};

	(* PHY Identifier Register 2 (PHYIDR2) *)
	PHYIDR2_OuiLSB* = {10..15};
	PHYIDR2_VendorModel* = {4..9};
	PHYIDR2_ModelRevision* = {0..3};

	(* Auto Negotiation Advertisement Register (ANAR) *)
	(* Auto Negotiation Link Partner Ability Register (ANLPAR) *)
	ANAR_NextPageIndication* = {15};
	ANAR_Ackknowlegdement* = {14};
	ANAR_RemoteFault* = {13};
	ANAR_Reserved* = {11..12}; (* write as zero *)
	ANAR_AsymmetricPause* = {11};
	ANAR_Pause* = {10};
	ANAR_100BaseT4Support* = {9};
	ANAR_100BaseTXFullDuplex* = {8};
	ANAR_100BaseTXHalfDuplex* = {7};
	ANAR_10BaseTFullDuplex* = {6};
	ANAR_10BaseTHalfDuplex* = {5};
	ANAR_Selector* = {0..4};

	(* ANAR/ANLPAR Selector field *)
	Selector_IEEE_STD802_3* = 1;
	Selector_IEEE_STD802_9ISLAN16T* = 2;

	(* Auto Negotiation Expansion Register (ANER) *)
	ANER_Reserved* = {5..15}; (* write as zero *)
	ANER_ParallelDetectionFault* = {4};
	ANER_LinkPartnerNextPageEnable* = {3};
	ANER_PhyNextPageEnable* = {2};
	ANER_NewPageReception* = {1};
	ANER_LinkPartnerAnEnable* = {0};

TYPE

	Identifier* = RECORD
		oui- : LONGINT; (* Organizationally Unique Identifier *)
		model- : LONGINT;
		revision- : LONGINT;
	END;

TYPE

	MII* = OBJECT
	VAR
		phyId- : LONGINT;

		lockedBy : ANY;
		timer : Kernel.Timer;

		(** Abstract interface to be implemented by the implementor *)

		(** Acqurie PHY ownership *)
		PROCEDURE AcquirePhyOwnership*() : BOOLEAN; (* abstract *)
		BEGIN HALT(301); END AcquirePhyOwnership;

		(** Release PHY ownership *)
		PROCEDURE ReleasePhyOwnership*() : BOOLEAN; (* abstract *)
		BEGIN HALT(301); END ReleasePhyOwnership;

		PROCEDURE HasPhyOwnership() : BOOLEAN; (* abstract *)
		BEGIN HALT(301); END HasPhyOwnership;

		(** Read a MII/GMII register *)
		PROCEDURE ReadRegister16*(register: LONGINT; VAR value : SET; VAR res : LONGINT); (* abstract *)
		BEGIN HALT(301); END ReadRegister16;

		(** Write a MII/GMII register *)
		PROCEDURE WriteRegister16*(register : LONGINT; value : SET; VAR res : LONGINT); (* abstract *)
		BEGIN HALT(301); END WriteRegister16;

		(** MII Management Interface *)

		PROCEDURE Acquire*;
		VAR me : ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			ASSERT(lockedBy # me); (* no recursive locking *)
			AWAIT(lockedBy = NIL);
			IF ~AcquirePhyOwnership() THEN
				Show("Serious error: Software could not acquire PHY ownership."); KernelLog.Ln;
			END;
			lockedBy := me;
		END Acquire;

		PROCEDURE Release*;
		BEGIN {EXCLUSIVE}
			ASSERT(lockedBy = Objects.ActiveObject());
			IF ~ReleasePhyOwnership() THEN
				Show("Fatal error: Software could not release PHY ownership."); KernelLog.Ln;
			END;
			lockedBy := NIL;
		END Release;

		(** Enable/disable auto-negotiation *)
		PROCEDURE EnableAutoNegotiation*(enable : BOOLEAN; VAR res : LONGINT);
		VAR anar, bmcr, bmsr : SET;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject());
			(* Check wether PHY supports auto-negotiation *)
			ReadRegister16(BMSR, bmsr, res);
			IF res # Ok THEN RETURN; END;

			IF bmsr * BMSR_AutoNegotiationAbility = {} THEN
				IF Trace * TraceCommands # {} THEN Show("Auto-Negotiation not supported."); KernelLog.Ln; END;
				res := Unsupported;
				RETURN;
			END;

			IF bmsr * BMSR_ExtendedCapability = {} THEN
				IF Trace * TraceCommands # {} THEN Show("Extended registers not available."); KernelLog.Ln; END;
				res := Unsupported;
				RETURN;
			END;

			(* Set abilities to be advertised *)
			anar := SYSTEM.VAL(SET, Selector_IEEE_STD802_3) * ANAR_Selector;

			IF bmsr * BMSR_100BaseT4 # {} THEN anar := anar + ANAR_100BaseT4Support; END;
			IF bmsr * BMSR_100BaseTXFullDuplex # {} THEN anar := anar + ANAR_100BaseTXFullDuplex; END;
			IF bmsr * BMSR_100BaseTXHalfDuplex # {} THEN anar := anar + ANAR_100BaseTXHalfDuplex; END;
			IF bmsr * BMSR_10BaseTFullDuplex # {} THEN anar := anar + ANAR_10BaseTFullDuplex; END;
			IF bmsr * BMSR_10BaseTHalfDuplex # {} THEN anar := anar + ANAR_10BaseTHalfDuplex; END;
			IF bmsr * BMSR_100BaseT2FullDuplex # {} THEN (* TODO *) END;
			IF bmsr * BMSR_100BaseT2HalfDuplex # {} THEN (* TODO *) END;
			(* TODO: 1GB *)

			anar := anar + ANAR_Pause;

			WriteRegister16(ANAR, anar, res);
			IF res # Ok THEN RETURN END;

			ReadRegister16(BMCR, bmcr, res);
			IF res # Ok THEN RETURN; END;

			IF enable THEN bmcr := bmcr + BMCR_AutoNegotiationEnable; ELSE bmcr := bmcr - BMCR_AutoNegotiationEnable; END;

			WriteRegister16(BMCR, bmcr, res);
			IF res # Ok THEN RETURN; END;

			IF enable THEN
				WriteRegister16(BMCR, bmcr + BMCR_RestartAutoNegotiation, res);
			END;
		END EnableAutoNegotiation;

		(** Get link configuration negotiated by auto-negotiation *)
		PROCEDURE GetAutoNegotiationResult*(VAR linkspeed : LONGINT; VAR fullDuplex : BOOLEAN; VAR res : LONGINT);
		VAR bmsr, anar, aner, anlpar, supported : SET; timeout : LONGINT; string : ARRAY 64 OF CHAR;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject());
			ReadRegister16(BMSR, bmsr, res);
			IF res # Ok THEN RETURN; END;

			IF bmsr * BMSR_AutoNegotiationAbility = {} THEN
				IF Trace * TraceAutoNegotiation # {} THEN Show("Auto-Negotiation not supported."); KernelLog.Ln; END;
				res := Unsupported;
				RETURN;
			END;

			IF bmsr * BMSR_ExtendedCapability = {} THEN
				IF Trace * TraceAutoNegotiation# {} THEN Show("Extended registers not available."); KernelLog.Ln; END;
				res := Unsupported;
				RETURN;
			END;

			ReadRegister16(ANER, aner, res);
			IF res # Ok THEN RETURN; END;

			IF aner * ANER_LinkPartnerAnEnable = {} THEN
				IF Trace * TraceAutoNegotiation # {} THEN Show("Link partner has not enabled auto-negotiation."); KernelLog.Ln; END;
				res := NotAvailable;
				RETURN;
			END;

			timeout := AutoNegotiationTimeout;
			REPEAT
				ReadRegister16(BMSR, bmsr, res);
				IF res # Ok THEN RETURN END;
				timer.Sleep(20);
				DEC(timeout, 20);
			UNTIL (bmsr * BMSR_AutoNegotiationComplete # {}) OR (timeout <= 0);

			IF bmsr * BMSR_AutoNegotiationComplete = {} THEN
				IF Trace * TraceAutoNegotiation # {} THEN Show("Auto-Negotiation not complete."); KernelLog.Ln; END;
				res := NotAvailable;
				RETURN;
			END;

			ReadRegister16(ANAR, anar, res);
			IF res # Ok THEN RETURN; END;

			ReadRegister16(ANLPAR, anlpar, res);
			IF res # Ok THEN RETURN; END;

			IF SYSTEM.VAL(LONGINT, anlpar * ANAR_Selector) # Selector_IEEE_STD802_3 THEN
				Show("Link partner doesn't use IEEE 802.3 Auto-Negotiation _ Other types not supported."); KernelLog.Ln;
				res := Unsupported;
				RETURN;
			END;

			supported := anar * anlpar;

			(* Priority Resolution according [1], Annex 28B *)
			IF supported * ANAR_100BaseTXFullDuplex # {} THEN
				linkspeed := 100; fullDuplex := TRUE; string := "100BASETX Full Duplex";
			ELSIF supported * ANAR_100BaseTXHalfDuplex # {} THEN
				linkspeed := 100; fullDuplex := FALSE; string := "100BASETX Half Duplex";
			ELSIF supported * ANAR_100BaseT4Support # {} THEN
				linkspeed := 100; fullDuplex := TRUE; string := "100BASET4";
			ELSIF supported * ANAR_10BaseTFullDuplex # {} THEN
				linkspeed := 10; fullDuplex := TRUE; string := "10BASET Full Duplex";
			ELSIF supported * ANAR_10BaseTHalfDuplex # {} THEN
				linkspeed := 10; fullDuplex := FALSE; string := "10BASET Half Duplex";
			ELSE
			END;

			IF Trace * TraceAutoNegotiation # {} THEN Show("Detected "); KernelLog.String(string); KernelLog.Ln; END;
		END GetAutoNegotiationResult;

		(** Get the current link status *)
		PROCEDURE GetLinkStatus*(VAR linkStatus, res : LONGINT);
		VAR value : SET;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject());
			ReadRegister16(BMSR, value, res);
			IF res = Ok THEN
				IF value * BMSR_LinkStatus # {} THEN linkStatus := Network.LinkLinked;
				ELSE linkStatus := Network.LinkNotLinked;
				END;
			END;
		END GetLinkStatus;

		(** Manually set the link speed and operating mode. This disables auto-negotiation as side-effect. *)
		PROCEDURE ConfigureLink*(speed : LONGINT; fullDuplex : BOOLEAN; VAR res : LONGINT);
		VAR value : SET;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject());
			ASSERT((speed = 10) OR (speed = 100) OR (speed = 1000));
			(* determine whether PHY supports the desired link configuration *)
			ReadRegister16(BMSR, value, res);
			IF res # Ok THEN RETURN; END;
			(* BMSR_100BaseT4 ???? *)
			IF (speed = 10) & ((fullDuplex & (value * BMSR_10BaseTFullDuplex = {})) OR (~fullDuplex & (value * BMSR_10BaseTHalfDuplex = {}))) THEN
				res := ParametersInvalid; RETURN;
			ELSIF (speed = 100) & ((fullDuplex & (value * (BMSR_100BaseTXFullDuplex + BMSR_100BaseT2FullDuplex) = {})) OR
					(~fullDuplex & (value * (BMSR_100BaseTXHalfDuplex + BMSR_100BaseT2HalfDuplex) = {}))) THEN
				res := ParametersInvalid; RETURN;
			ELSIF (speed = 1000) THEN
				IF value * BMSR_ExtendedStatus = {} THEN res := ParametersInvalid; RETURN; END;
				ReadRegister16(BMESR, value, res);
				IF res # Ok THEN RETURN; END;
				IF (fullDuplex & (value * (BMESR_1000BaseXFullDuplex + BMESR_1000BaseTFullDuplex) = {})) OR
					(~fullDuplex & (value * (BMESR_1000BaseXHalfDuplex + BMESR_1000BaseTHalfDuplex) = {})) THEN
					res := ParametersInvalid; RETURN;
				END;
			END;
			(* disable auto-negotiation if it's enabled *)
			ReadRegister16(BMCR, value, res);
			IF res # Ok THEN RETURN; END;

			IF value * BMCR_AutoNegotiationEnable # {} THEN
				WriteRegister16(BMCR, value - BMCR_AutoNegotiationEnable, res);
				IF res # Ok THEN RETURN; END;
			END;

			(* set link speed and duplex mode *)
			IF fullDuplex THEN value := value + BMCR_DuplexMode; ELSE value := value - BMCR_DuplexMode; END;
			IF speed = 10 THEN
				value := value - BMCR_SpeedSelectionMsb - BMCR_SpeedSelectionLsb;
			ELSIF speed = 100 THEN
				value := value - BMCR_SpeedSelectionMsb + BMCR_SpeedSelectionLsb;
			ELSE
				value := value + BMCR_SpeedSelectionMsb - BMCR_SpeedSelectionLsb;
			END;

			WriteRegister16(BMCR, value, res);
		END ConfigureLink;

		PROCEDURE EnableLoopback*(enable : BOOLEAN; VAR res : LONGINT);
		VAR value : SET;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject());
			IF Trace * TraceCommands # {} THEN
				IF enable THEN Show("Enable "); ELSE Show("Disable "); END; KernelLog.String("loopback."); KernelLog.Ln;
			END;
			ReadRegister16(BMCR, value, res);
			IF res # Ok THEN RETURN; END;
			IF enable THEN value := value + BMCR_Loopback; ELSE value := value - BMCR_Loopback; END;
			WriteRegister16(BMCR, value + BMCR_Loopback, res);
		END EnableLoopback;

		(** Reset the PHY. Sets the Control and the Status registers to their default values. *)
		PROCEDURE Reset*(VAR res : LONGINT);
		VAR timeout, interval : LONGINT; value : SET;
		BEGIN (*  {EXCLUSIVE} *)
			ASSERT(lockedBy = Objects.ActiveObject());
			IF Trace * TraceCommands # {} THEN Show("Reset PHY... "); END;
			WriteRegister16(BMCR, BMCR_Reset, res);
			IF res # Ok THEN RETURN; END;
			(* 0.5s timeout according to [1], page 512 *)
			timeout := 500; interval := 10;
			LOOP
				timer.Sleep(interval);
				ReadRegister16(BMCR, value, res);
				IF (value * BMCR_Reset = {}) OR (res # Ok) THEN EXIT; END;
				DEC(timeout, interval);
				IF timeout <= 0 THEN res := Timeout; EXIT; END
			END;
			IF Trace * TraceCommands # {} THEN KernelLog.String("done."); KernelLog.Ln; END;
		END Reset;

		PROCEDURE GetIdentifier*(VAR identifier : Identifier; VAR res : LONGINT);
		VAR phyIdr1, phyIdr2 : SET;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject());
			ReadRegister16(PHYIDR1, phyIdr1, res);
			IF res # Ok THEN
				IF Debug THEN Show("Could not read PHYIDR1 register."); KernelLog.Ln; END;
				RETURN;
			END;
			ReadRegister16(PHYIDR2, phyIdr2, res);
			IF res # Ok THEN
				IF Debug THEN Show("Could not read PHYIDR2 register."); KernelLog.Ln; END;
				RETURN;
			END;
			identifier.oui := SYSTEM.VAL(LONGINT, LSH(phyIdr1 * PHYIDR1_OuiMSB, 3) + LSH(phyIdr2 * PHYIDR2_OuiLSB, 9));
			identifier.model := SYSTEM.VAL(LONGINT, LSH(phyIdr2 * PHYIDR2_VendorModel, -4));
			identifier.revision := SYSTEM.VAL(LONGINT, phyIdr2 * PHYIDR2_ModelRevision);
		END GetIdentifier;

		PROCEDURE Diag*;
		VAR identifier : Identifier; res : LONGINT; bmsr, anar, anlpar, register : SET;
		BEGIN
			ASSERT(lockedBy = Objects.ActiveObject());
			KernelLog.String("MII information:"); KernelLog.Ln;
			KernelLog.String("   PHY ID: "); KernelLog.Hex(phyId, 0); KernelLog.Ln;
			GetIdentifier(identifier, res);
			IF res = Ok THEN
				KernelLog.String("   OUI: "); KernelLog.Hex(identifier.oui, 0); KernelLog.String(", Vendor model: "); KernelLog.Int(identifier.model, 0);
				KernelLog.String(", Revision: "); KernelLog.Int(identifier.revision, 0);
			ELSE
				KernelLog.String("Error: Could not read PHY Identification registers."); KernelLog.Ln;
			END;
			KernelLog.Ln;
			ReadRegister16(BMCR, register, res);
			IF res = Ok THEN ShowControlRegister(register);
			ELSE KernelLog.String("Error: Could not read BMCR register."); KernelLog.Ln;
			END;
			ReadRegister16(BMSR, bmsr, res);
			IF res = Ok THEN ShowStatusRegister(bmsr);
			ELSE KernelLog.String("Error: Could not read BMSR register."); KernelLog.Ln;
			END;
			KernelLog.String("Extended registers: "); KernelLog.Ln;
			IF bmsr * BMSR_ExtendedCapability # {} THEN
				ReadRegister16(ANAR, anar, res);
				IF res = Ok THEN
					ReadRegister16(ANLPAR, anlpar, res);
					IF res = Ok THEN
						ShowAdvertisementRegisters(anar, anlpar);
					ELSE KernelLog.String("Error: Could not read ANLPAR register."); KernelLog.Ln;
					END;
				ELSE KernelLog.String("Error: Could not read ANAR register."); KernelLog.Ln;
				END;
				ReadRegister16(ANER, register, res);
				IF res = Ok THEN
					ShowAnerRegister(register);
				ELSE KernelLog.String("Error: Could not read ANER register."); KernelLog.Ln;
				END;
			ELSE
				KernelLog.String("Extended registers not available."); KernelLog.Ln;
			END;
			IF bmsr * BMSR_ExtendedStatus # {} THEN
				ReadRegister16(BMESR, register, res);
				IF res = Ok THEN ShowExtendedStatusRegister(register);
				ELSE KernelLog.String("Error: Could not read BMESR register."); KernelLog.Ln;
				END;
			END;
			IF bmsr * BMSR_ExtendedCapability # {} THEN
			END;
		END Diag;

		PROCEDURE &Init*(phyId : LONGINT);
		BEGIN
			SELF.phyId := phyId;
			NEW(timer);
			lockedBy := NIL;
		END Init;

	END MII;

PROCEDURE ShowControlRegister(bmcr : SET);
BEGIN
	KernelLog.String("Basic Mode Control Register (BMCR):"); KernelLog.Ln;
	KernelLog.String("   Reset PHY: "); KernelLog.Boolean(bmcr * BMCR_Reset # {}); KernelLog.Ln;
	KernelLog.String("   Loopback: "); KernelLog.Boolean(bmcr * BMCR_Loopback # {}); KernelLog.Ln;
	KernelLog.String("   Auto-Negotiation Enable: "); KernelLog.Boolean(bmcr * BMCR_AutoNegotiationEnable # {}); KernelLog.Ln;
	KernelLog.String("   Power Down: "); KernelLog.Boolean(bmcr * BMCR_PowerDown # {}); KernelLog.Ln;
	KernelLog.String("   Isolate: "); KernelLog.Boolean(bmcr * BMCR_Isolate # {}); KernelLog.Ln;
	KernelLog.String("   Restart Auto-Negotiation: "); KernelLog.Boolean(bmcr * BMCR_RestartAutoNegotiation # {}); KernelLog.Ln;
	KernelLog.String("   Collision Test: "); KernelLog.Boolean(bmcr * BMCR_CollisionTest # {}); KernelLog.Ln;
	KernelLog.String("   Link Speed: ");
	IF bmcr * BMCR_AutoNegotiationEnable = {} THEN
		IF bmcr * BMCR_SpeedSelectionMsb = {} THEN
			IF bmcr * BMCR_SpeedSelectionLsb # {} THEN KernelLog.String("100 Mbps");
			ELSE KernelLog.String("10 Mbps");
			END;
		ELSE
			IF bmcr * BMCR_SpeedSelectionMsb # {} THEN KernelLog.String("1000 Mbps");
			ELSE KernelLog.String("Invalid setting");
			END;
		END;
		IF bmcr * BMCR_DuplexMode # {} THEN KernelLog.String(" (Full Duplex)"); ELSE KernelLog.String(" (Half Duplex)"); END;
	ELSE KernelLog.String("Reported in BMSR since Auto-negotiation is enabled");
	END;
	KernelLog.Ln;
END ShowControlRegister;

PROCEDURE ShowStatusRegister(bmsr : SET);
BEGIN
	KernelLog.String("Basic Mode Status Register (BMSR):"); KernelLog.Ln;
	KernelLog.String("   Link Capabilities:"); KernelLog.Ln;
	KernelLog.String("      100BaseT4: "); KernelLog.Boolean(bmsr * BMSR_100BaseT4 # {}); KernelLog.Ln;
	KernelLog.String("      100BaseX Full Duplex: "); KernelLog.Boolean(bmsr * BMSR_100BaseTXFullDuplex # {}); KernelLog.Ln;
	KernelLog.String("      100BaseX Half Duplex: "); KernelLog.Boolean(bmsr * BMSR_100BaseTXHalfDuplex # {}); KernelLog.Ln;
	KernelLog.String("      10Mb/s Full Duplex: "); KernelLog.Boolean(bmsr * BMSR_10BaseTFullDuplex # {}); KernelLog.Ln;
	KernelLog.String("      10Mb/s Half Fuplex: "); KernelLog.Boolean(bmsr * BMSR_10BaseTHalfDuplex # {}); KernelLog.Ln;
	KernelLog.String("      100BaseT2FullDuplex: "); KernelLog.Boolean(bmsr * BMSR_100BaseT2FullDuplex # {}); KernelLog.Ln;
	KernelLog.String("      100BaseT2HalfDuplex: "); KernelLog.Boolean(bmsr * BMSR_100BaseT2HalfDuplex  # {}); KernelLog.Ln;
	KernelLog.String("   Extended Status Register available: "); KernelLog.Boolean(bmsr * BMSR_ExtendedStatus # {}); KernelLog.Ln;
	KernelLog.String("   MF Preamble Suppression: "); KernelLog.Boolean(bmsr * BMSR_MfPreambleSuppression # {}); KernelLog.Ln;
	KernelLog.String("   Auto-Negotiation complete: "); KernelLog.Boolean(bmsr * BMSR_AutoNegotiationComplete # {}); KernelLog.Ln;
	KernelLog.String("   Remote Fault: "); KernelLog.Boolean(bmsr * BMSR_RemoteFault # {}); KernelLog.Ln;
	KernelLog.String("   Auto-Negotiation Ability: "); KernelLog.Boolean(bmsr * BMSR_AutoNegotiationAbility # {}); KernelLog.Ln;
	KernelLog.String("   Link status: ");
	IF bmsr * BMSR_LinkStatus # {} THEN KernelLog.String("UP"); ELSE KernelLog.String("DOWN"); END; KernelLog.Ln;
	KernelLog.String("   Jabber Detected: "); KernelLog.Boolean(bmsr * BMSR_JabberDetect # {}); KernelLog.Ln;
	KernelLog.String("   Extended Capability: "); KernelLog.Boolean(bmsr * BMSR_ExtendedCapability # {}); KernelLog.Ln;
END ShowStatusRegister;

PROCEDURE ShowAdvertisementRegisters(anar, anlpar : SET);

	PROCEDURE ShowBit(CONST title : ARRAY OF CHAR; bit : SET);
	BEGIN
		KernelLog.String(title); KernelLog.Boolean(anar * bit # {});
		KernelLog.String(", Link partner: "); KernelLog.Boolean(anlpar * bit # {}); KernelLog.Ln;
	END ShowBit;

BEGIN
	KernelLog.String("Auto-Negotiation Advertisement Registers (ANAR/ANLPAR):"); KernelLog.Ln;
	ShowBit("   Next page indication: ", ANAR_NextPageIndication);
	ShowBit("   Ackknowlegdement: ", ANAR_Ackknowlegdement);
	ShowBit("   Remote Fault: ", ANAR_RemoteFault);
	ShowBit("   Asymmetric Pause: ", ANAR_AsymmetricPause);
	ShowBit("   Pause: ", ANAR_Pause);
	ShowBit("   100BaseT4 support: ", ANAR_100BaseT4Support);
	ShowBit("   100BaseTX Full Duplex support: ", ANAR_100BaseTXFullDuplex);
	ShowBit("   100BaseTX Half Duplex support: ", ANAR_100BaseTXHalfDuplex);
	ShowBit("   10BaseT Full Duplex support: ", ANAR_10BaseTFullDuplex);
	ShowBit("   10BaseT Half Duplex support: ", ANAR_10BaseTHalfDuplex);
	KernelLog.String("   Selector: "); KernelLog.Int(SYSTEM.VAL(LONGINT, anar * ANAR_Selector), 0);
	KernelLog.String(", Link partner: "); KernelLog.Int(SYSTEM.VAL(LONGINT, anlpar * ANAR_Selector), 0);
	KernelLog.Ln;
END ShowAdvertisementRegisters;

PROCEDURE ShowAnerRegister(aner : SET);
BEGIN
	KernelLog.String("Auto-Negotiation Extension Register (ANER):"); KernelLog.Ln;
	KernelLog.String("   Parallel Detection Fault: "); KernelLog.Boolean(aner * ANER_ParallelDetectionFault # {}); KernelLog.Ln;
	KernelLog.String("   Link Partner Next Page Enable: "); KernelLog.Boolean(aner * ANER_LinkPartnerNextPageEnable # {}); KernelLog.Ln;
	KernelLog.String("   PHY Next Page Enable: "); KernelLog.Boolean(aner * ANER_PhyNextPageEnable # {}); KernelLog.Ln;
	KernelLog.String("   New Page Reception: "); KernelLog.Boolean(aner * ANER_NewPageReception # {}); KernelLog.Ln;
	KernelLog.String("   Link Partner Auto-Negotiation Enable: "); KernelLog.Boolean(aner * ANER_LinkPartnerAnEnable # {}); KernelLog.Ln;
END ShowAnerRegister;

PROCEDURE ShowExtendedStatusRegister(bmesr : SET);
BEGIN
	KernelLog.String("Base Mode Extended Status Register (BMESR):"); KernelLog.Ln;
	KernelLog.String("   Link Capabilities:"); KernelLog.Ln;
	KernelLog.String("      1000BaseX Full Duplex: "); KernelLog.Boolean(bmesr * BMESR_1000BaseXFullDuplex # {}); KernelLog.Ln;
	KernelLog.String("      1000BaseX Half Duplex: "); KernelLog.Boolean(bmesr * BMESR_1000BaseXHalfDuplex # {}); KernelLog.Ln;
	KernelLog.String("      1000BaseT Full Duplex: "); KernelLog.Boolean(bmesr * BMESR_1000BaseTFullDuplex # {}); KernelLog.Ln;
	KernelLog.String("      1000BaseT Half Duplex: "); KernelLog.Boolean(bmesr * BMESR_1000BaseTHalfDuplex # {}); KernelLog.Ln;
END ShowExtendedStatusRegister;

PROCEDURE Show(CONST string : ARRAY OF CHAR);
BEGIN
	KernelLog.String(ModuleName); KernelLog.String(": "); KernelLog.String(string);
END Show;

END NetworkMii.
