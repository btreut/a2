MODULE Loopback;	(** AUTHOR "mvt"; PURPOSE "Virtual local loopback/discard network device"; *)

IMPORT Network, Modules, Plugins;

TYPE
	LinkDevice =  OBJECT(Network.LinkDevice)

		PROCEDURE &Constr*(type, mtu, adrSize: LONGINT);
		VAR res: LONGINT;
		BEGIN
			Constr^(type, mtu, adrSize); (* call inherited constructor first *)

			calcChecksum := {Network.ChecksumIP, Network.ChecksumUDP, Network.ChecksumTCP};

			(* Add to registry *)
			SetName("Loopback");
			Network.registry.Add(SELF, res);
			ASSERT(res = Plugins.Ok);
		END Constr;

		PROCEDURE Linked*(): LONGINT;
		BEGIN
			RETURN Network.LinkLinked;
		END Linked;

		PROCEDURE Finalize*(connected: BOOLEAN);
		BEGIN
			(* Remove from registry *)
			Network.registry.Remove(SELF);
			Finalize^(connected);
		END Finalize;

		PROCEDURE DoSend(dst: Network.LinkAdr; type: LONGINT;  CONST l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT);
			(* do nothing, discard packet *)
		END DoSend;

	END LinkDevice;

VAR
	device: LinkDevice;

PROCEDURE Cleanup;
BEGIN
	device.Finalize(TRUE);
END Cleanup;

(** Procedure for initializing the module *)
PROCEDURE Install*;
	(* module body is called implicitly *)
END Install;

BEGIN
	NEW(device, Network.TypePointToPoint, Network.MaxPacketSize, 0);
	Modules.InstallTermHandler(Cleanup);
END Loopback.

(*
History:
11.10.2003	mvt	Created
17.10.2003	mvt	Changed for new initialization and finalization (see Network)
17.12.2003	mvt	Changed for new method Network.Linked
*)

Aos.Call Loopback.Install
System.Free Loopback~

Installation
Add Loopback.Install to Configuration.XML, section 'Autostart' to load driver at system startup.
