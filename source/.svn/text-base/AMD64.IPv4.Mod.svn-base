(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE IPv4; (** AUTHOR "pjm, mvt"; PURPOSE "IPv4 and ARP protocols"; *)

IMPORT SYSTEM, Machine, Kernel, Modules, Clock, KernelLog, Network, IP;

CONST
	(* DEBUG *)
	DEBUG = TRUE;

	(* ARP *)
	ARPHdrLen = 8;
	ARPPktLen = 28;
	EtherTypeARP* = 806H;
	ARPMonitor = FALSE; (* monitor all ARP packets *)
	ARPHashSize = 256; (* size of ARP hash table *)
	MinARPTime = 1000; (* minimum time between ARP requests in ms *)

	(* IP *)
	EtherTypeIP* = 800H;
	MinIPHdrLen*= 20;
	MaxIPHdrLen* = 60;
	TOS = 10X; (* type-of-service on outgoing datagrams *)
	BroadcastAdr = SHORT(0FFFFFFFFH);

TYPE
	ARPEntry = POINTER TO RECORD
		next: ARPEntry;
		ip: IP.Adr;
		ether: Network.LinkAdr;
		sendTime, updateTime, updateDate: LONGINT;
		complete: BOOLEAN;
		buf: IP.Packet; (* buffer for a packet waiting to be sent, NIL if none *)
	END;

TYPE
	Interface* = OBJECT(IP.Interface)
	VAR
		(* ARP hash table *)
		arpTable: ARRAY ARPHashSize OF ARPEntry;
		NARPEntries: LONGINT;

		(* The interface is trying to get an IP from a DHCP *)
		doingDHCPRequest*: BOOLEAN;


		(** Constructor - Open an IPv4 interface and add it to the IP configuration.
			"name" must be a unique name for this interface (tested in "AddInterface").
			"dev" must be a Network.LinkDevice that can be used in other interfaces => multiple IP addresses on the
			same interface. *)
		PROCEDURE &Constr*(name: IP.Name; dev: Network.LinkDevice; VAR res: LONGINT);
		VAR
			i: LONGINT;

		BEGIN
			ASSERT(dev # NIL);

			SELF.dev := dev;
			protocol := IP.IPv4;
			doingDHCPRequest := FALSE;

			(* set name *)
			IF name = "" THEN
				res := IP.NoInterfaceName;
				RETURN;
			END;
			COPY(name, SELF.name);

			(* init addresses *)
			localAdr := IP.NilAdr;
			maskAdr := IP.NilAdr;
			gatewayAdr := IP.NilAdr;
			subnetAdr := IP.NilAdr;

			broadAdr.usedProtocol := IP.IPv4;
			broadAdr.ipv4Adr := BroadcastAdr;

			(* init ARP *)
			FOR i := 0 TO ARPHashSize-1 DO
				arpTable[i] := NIL;
			END;
			NARPEntries := 0;

			(* init DNS *)
			DNScount := 0;

			closed := FALSE;

			IP.AddInterface(SELF, res);
			IF res = IP.Ok THEN
				(* install receivers *)
				dev.InstallReceiver(SELF, EtherTypeIP, IPInput, IsIPPacketValid, IsIPPacketForSingleInt, IsIPPacketAccepted, IP.IPForwarding); (* IPv4 *)
				dev.InstallReceiver(SELF, EtherTypeARP, ARPInput, IsARPPacketValid, IsARPPacketForSingleInt, IsARPPacketAccepted, FALSE); (* ARP *)
			ELSE
				closed := TRUE;
			END;
		END Constr;


		(** Close and deactivate the interface, i.e. remove it from the configuration. *)
		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			ASSERT(~closed);

			closed := TRUE;
			(* remove receivers *)
			dev.RemoveReceiver(SELF, EtherTypeIP); (* IPv4 *)
			dev.RemoveReceiver(SELF, EtherTypeARP); (* ARP *)

			IP.RemoveInterface(SELF);
		END Close;


		(** Send an IP packet on this interface. *)
		PROCEDURE Send*(type: LONGINT; fip:IP. Adr; VAR l4hdr, data: ARRAY OF CHAR; h4len, dofs, dlen, TTL: LONGINT);
		VAR
			l3hdr: ARRAY MaxIPHdrLen OF CHAR;

		BEGIN
			ASSERT (fip.usedProtocol =  4, 2345 );

			IF closed THEN RETURN END; (* just in case of concurrent Send/Close *)

			(* set IP header *)
			l3hdr[0] := CHR(IP.IPv4*10H + MinIPHdrLen DIV 4); (* IP version and header length *)
			l3hdr[1] := TOS; (* type-of-service *)
			Network.PutNet2(l3hdr, 2, MinIPHdrLen+h4len+dlen); (* total packet length *)
			Network.PutNet2(l3hdr, 4, GetNextID()); (* identification *)
			Network.Put2(l3hdr, 6, 0); (* fragmentation *)
			l3hdr[8] := CHR(TTL); (* time-to-live *)
			l3hdr[9] := CHR(type); (* IP type code *)

			Network.Put4(l3hdr, 12, localAdr.ipv4Adr); (* set local address *)
			Network.Put4(l3hdr, 16, fip.ipv4Adr); (* set foreign address *)
			Network.Put2(l3hdr, 10, 0); (* checksum := 0 *)
			IF ~(Network.ChecksumIP IN dev.calcChecksum) THEN
				Network.Put2(l3hdr, 10, IP.Checksum2(l3hdr, 0, MinIPHdrLen, 0)); (* calculate checksum *)
			END;

			(* perform sending *)
			DoSend(fip, l3hdr, l4hdr, data, MinIPHdrLen, h4len, dofs, dlen);
		END Send;


		(* Internal procedure to perform the rest of the send operation. Used by "Send" and for IP forwarding. *)
		PROCEDURE DoSend*(destAdr: IP.Adr; VAR l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT) ;
		VAR
			linkDst: Network.LinkAdr;

		BEGIN
			ASSERT (destAdr.usedProtocol = 4, 2345);

			IF h3len+h4len+dlen <= dev.mtu THEN
				IF dev.type = Network.TypeEthernet THEN
					IF IP.AdrsEqual (destAdr, localAdr) THEN
						(* send local loopback *)
						Machine.AtomicInc(IP.NIPSentLocalLoopback);
						dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen, TRUE);
					ELSIF IsBroadcast(destAdr) (* (fip = broadAdr) OR  OR (fip = BroadcastAdr) OR (fip = OldBroadcastAdr)  *) THEN
						(* send broadcast *)
						Machine.AtomicInc(IP.NIPSentBroadcast);
						dev.Send(dev.broadcast, EtherTypeIP, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen, FALSE);
					ELSIF IsMulticast(destAdr) THEN
						(* Drop Multicast packet, NIY *)
					ELSE
						IF (~IP.IsNilAdr (gatewayAdr)) & ~SameSubnet(destAdr.ipv4Adr, subnetAdr.ipv4Adr, maskAdr.ipv4Adr) THEN
							Machine.AtomicInc(IP.NIPSentToGateway);
							destAdr := gatewayAdr;
						ELSE
							Machine.AtomicInc(IP.NIPSentToSubnet);
						END;
						IF ARPLookup(destAdr, linkDst) THEN
							dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen, FALSE);
						ELSE
							ARPQueue(destAdr, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen);
						END;
					END;
				ELSE
					(* Network.TypePointToPoint *)
					Machine.AtomicInc(IP.NIPSentPointToPoint);
					dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen, IP.AdrsEqual (destAdr, localAdr));
				END;
			ELSE
				Machine.AtomicInc(IP.NIPCantFragment);
			END;
		END DoSend;


		(* Receive an ARP packet *)
		PROCEDURE ARPInput* (dev: Network.LinkDevice; type: LONGINT; buffer: Network.Buffer);
		VAR
			src, dst: IP.Adr;
			forus: BOOLEAN;

		BEGIN
			src := ARPReadSrcAdr (buffer);
			dst := ARPReadDestAdr (buffer);
			IF IP.AdrsEqual (src, localAdr) THEN
				(* duplicate source address! *)
				Machine.AtomicInc(NARPRcvDuplicate);
				KernelLog.Enter;
				KernelLog.String("IP: Address "); IP.OutAdr(src); KernelLog.String(" hijacked by ");
				Network.OutLinkAdr(SYSTEM.VAL(Network.LinkAdr, buffer.data[buffer.ofs+8]), dev.adrSize); KernelLog.Ln;
				KernelLog.Exit;
			ELSIF (buffer.data[buffer.ofs+7] = 1X) OR (buffer.data[buffer.ofs+7] = 2X) THEN
				(* request or reply *)
				IF ~ODD(LONG(ORD(buffer.data[buffer.ofs+8]))) & (~IP.IsNilAdr(src)) THEN
					forus := (IP.AdrsEqual(dst, localAdr));
					ARPEnter(src, SYSTEM.VAL(Network.LinkAdr, buffer.data[buffer.ofs+8]), forus);
					IF (buffer.data[buffer.ofs+7] = 1X) & forus THEN
						(* request for us *)
						ARPReply(buffer.data, buffer.ofs);
					END;
				ELSE
					(* nil IP address or non-unicast ethernet address supplied *)
					Machine.AtomicInc(NARPBadAddr)
				END
			ELSE
				Machine.AtomicInc(NARPRcvIgnored)
			END;

			(* Return the buffer *)
			Network.ReturnBuffer(buffer);
		END ARPInput;


		(* Receive an IP packet *)
		PROCEDURE IPInput(dev: Network.LinkDevice; type: LONGINT; buffer: Network.Buffer);
		VAR
			hlen: LONGINT;
			src, dst: IP.Adr;
			receiver: IP.Receiver;
			int: IP.Interface;

		BEGIN
			hlen := ORD(buffer.data[buffer.ofs]) MOD 10H * 4;

			src := ReadSrcAdr (buffer);
			dst := ReadDestAdr (buffer);

			IF ~IsBroadcast(src) & ~IsMulticast(src)  THEN
				IF (IP.AdrsEqual (dst,localAdr)) OR IsBroadcast(dst) (* (dst = broadAdr) OR
					(dst = BroadcastAdr) OR (dst = OldBroadcastAdr) *) THEN
					(* packet is for us *)
					type := ORD(buffer.data[buffer.ofs+9]);
					receiver := IP.receivers[type];
					IF receiver # NIL THEN
						(* do receiver upcall *)
						buffer.l3ofs := buffer.ofs;
						INC(buffer.ofs, hlen);
						DEC(buffer.len, hlen);
						receiver(SELF, type, src, dst, buffer);
						Machine.AtomicInc(IP.NIPDelivered);
						(* Exit here w/o returning buffer because it is passed to a receiver *)
						RETURN;
					ELSE
						Machine.AtomicInc(IP.NIPNoReceiver);
					END;
				ELSIF  IsMulticast(dst) THEN
					(* Drop multicast packet, NIY *)
				ELSIF IP.IPForwarding THEN
					int := IP.InterfaceByDstIP(dst);
					IF int # NIL THEN
						int.DoSend(dst, buffer.data, buffer.data, buffer.data, 0, 0, buffer.ofs, buffer.len);
						Machine.AtomicInc(IP.NIPForwarded)
					ELSE
						Machine.AtomicInc(IP.NIPNotForUs)
					END;
				ELSE
					Machine.AtomicInc(IP.NIPNotForUs)
				END
			ELSE
				Machine.AtomicInc(IP.NIPSrcIsBroadcast)
			END;
			(* Exit and return buffer here because it is no longer used *)
			Network.ReturnBuffer(buffer);
		END IPInput;


		(** Check if adr is a broadcast address *)
		PROCEDURE IsBroadcast*(adr: IP.Adr) : BOOLEAN;
		BEGIN
			ASSERT (adr.usedProtocol = 4, 2345);

			RETURN (adr.ipv4Adr = broadAdr.ipv4Adr) OR
				 (adr.ipv4Adr = subnetAdr.ipv4Adr) OR (adr.ipv4Adr = BroadcastAdr)
		END IsBroadcast;


		(** Check if adr is a multicast address *)
		PROCEDURE IsMulticast*(adr: IP.Adr) : BOOLEAN;
		VAR
			arr: ARRAY 4 OF CHAR;

		BEGIN
			ASSERT (adr.usedProtocol = 4, 2345);

			IP.AdrToArray(adr, arr, 0, FALSE);
			RETURN (ORD(arr[0]) >= 224) & (ORD(arr[0]) < 240)
		END IsMulticast;


		(** Performs a check for Network if a packet is accepted by this interface *)
		PROCEDURE IsIPPacketAccepted(buffer: Network.Buffer): BOOLEAN;
		VAR
			dstAdr: LONGINT;
			interface: IP.Interface;
			accept: BOOLEAN;

		BEGIN
			dstAdr := Network.Get4(buffer.data, buffer.ofs+16);

			IF IP.IsNilAdr(localAdr) THEN
				IF doingDHCPRequest THEN
					(* Check if there are other interface waiting for this packet if not take it could be DHCP *)
					interface := IP.interfaces;
					WHILE (interface # NIL) & (interface.localAdr.ipv4Adr # dstAdr) DO
						interface := interface.next;
					END;
					IF interface # NIL THEN
						accept := FALSE;
					ELSE
						accept := TRUE;
					END;
				ELSE
					(* An interface with no IP does not take packets *)
					accept := FALSE;
				END;
			ELSE
				accept := dstAdr = localAdr.ipv4Adr;
			END;

			RETURN accept;
		END IsIPPacketAccepted;


		(** Set addresses. Is normally called just after instanciation, but can also be called later, e.g. by DHCP.
			If "gatewayAdr" is "NilAdr", the subnet is considered to have no gateway, else it must be in the same
			subnet as the "localAdr".
			"domain" can be an empty string. It is normally used by a DNS implementation. It is not used in IP directly. *)
		PROCEDURE SetAdrs*(localAdr, maskAdr, gatewayAdr: IP.Adr; VAR res: LONGINT);
		VAR
			maskSet: SET;

		BEGIN {EXCLUSIVE}
			IF DEBUG THEN
				ASSERT ((IP.IsNilAdr(localAdr)) OR (localAdr.usedProtocol = 4), 2345);
				ASSERT ((IP.IsNilAdr(maskAdr)) OR (maskAdr.usedProtocol = 4), 2345);
				ASSERT ((IP.IsNilAdr(gatewayAdr)) OR (gatewayAdr.usedProtocol = 4), 2345);
			END;

			IF ~IP.IsNilAdr (localAdr) THEN
				(* Check, if all IPv6 or all IPv4 *)
				IF ((localAdr.usedProtocol # maskAdr.usedProtocol) OR
				    ((~IP.IsNilAdr (gatewayAdr)) & (localAdr.usedProtocol # gatewayAdr.usedProtocol))) THEN
					res := IP.MixedIpProtocols;
					RETURN;
				END;

				(* Check if addresses are of same protocol as interface *)
				IF localAdr.usedProtocol # IP.IPv4 THEN
					res := IP.IPv6AdrUsedOnIPv4Interface;
					RETURN;
				END;
			END;

			(* set addresses *)
			SELF.localAdr := localAdr;
			SELF.maskAdr := maskAdr;
			SELF.gatewayAdr := gatewayAdr;

			(* compute other addresses  *)
			maskSet := SYSTEM.VAL(SET, maskAdr.ipv4Adr);
			subnetAdr.usedProtocol := IP.IPv4;
			subnetAdr.ipv4Adr := SYSTEM.VAL (LONGINT, SYSTEM.VAL (SET, localAdr.ipv4Adr) * maskSet);
			broadAdr.usedProtocol := IP.IPv4;
			broadAdr.ipv4Adr := SYSTEM.VAL (LONGINT, SYSTEM.VAL (SET, subnetAdr.ipv4Adr) + (-maskSet));

			IF (~IP.IsNilAdr (gatewayAdr)) &
			    ( ~SameSubnet(gatewayAdr.ipv4Adr, localAdr.ipv4Adr, maskAdr.ipv4Adr)) THEN
				res := IP.GatewayNotInSubnet;
			ELSE
				res := IP.Ok;
			END;
		END SetAdrs;


		(* Reads the source address of a IPv4 packet buffer *)
		PROCEDURE ReadSrcAdr* (buffer: Network.Buffer): IP.Adr;
		VAR
			adr: IP.Adr;

		BEGIN
			adr.usedProtocol := IP.IPv4;
			adr.ipv4Adr := Network.Get4(buffer.data, buffer.ofs+12);
			RETURN adr;
		END ReadSrcAdr;


		(* Reads the destination address of a IPv4 packet buffer *)
		PROCEDURE ReadDestAdr* (buffer: Network.Buffer): IP.Adr;
		VAR
			adr: IP.Adr;

		BEGIN
			adr.usedProtocol := IP.IPv4;
			adr.ipv4Adr := Network.Get4(buffer.data, buffer.ofs+16);
			RETURN adr;
		END ReadDestAdr;



		(** Creates a pseudo-header for checksum calculation (TCP/UDP) and returns the length of this header *)
		PROCEDURE WritePseudoHeader*(VAR pseudoHdr: ARRAY OF CHAR;  src, dst: IP.Adr; protocol, pktLengthUpperLayer: LONGINT): LONGINT;
		BEGIN
			(* UDP/TCP Pseudo-header (for checksum calculation)

			00	32	source address
			04	32	destination address
			08	08	zero = 0
			09	08	protocol = 17
			10	16	UDP/TCP length *)

			Network.Put4(pseudoHdr, 0, src.ipv4Adr); (* local IP address *)
			Network.Put4(pseudoHdr, 4, dst.ipv4Adr); (* foreign IP address *)
			Network.PutNet2(pseudoHdr, 8, protocol); (* IP type code of UDP/TCP*)
			Network.PutNet2(pseudoHdr, 10, pktLengthUpperLayer); (* UPD/TCP length *)

			RETURN 12; (* IPv4 pseudo header length *)
		END WritePseudoHeader;


		(* Reads the source address of a ARP packet buffer *)
		PROCEDURE ARPReadSrcAdr* (buffer: Network.Buffer): IP.Adr;
		VAR
			adr: IP.Adr;

		BEGIN
			adr.usedProtocol := IP.IPv4;
			adr.ipv4Adr := Network.Get4(buffer.data, buffer.ofs+14);
			RETURN adr;
		END ARPReadSrcAdr;


		(* Reads the destination address of a ARP packet buffer *)
		PROCEDURE ARPReadDestAdr* (buffer: Network.Buffer): IP.Adr;
		VAR
			adr: IP.Adr;

		BEGIN
			adr.usedProtocol := IP.IPv4;
			adr.ipv4Adr := Network.Get4(buffer.data, buffer.ofs+24);
			RETURN adr;
		END ARPReadDestAdr;


		(** Enumerate all ARP table entries. *)
		PROCEDURE ARPEnumerate*(handle: IP.ARPHandler);
		VAR
			p: ARPEntry;
			i: LONGINT;

		BEGIN
			FOR i := 0 TO ARPHashSize-1 DO
				p := arpTable[i];
				WHILE p # NIL DO
					handle(p.ip, p.complete, p.ether, 6, p.sendTime, p.updateTime, p.updateDate, i);
					p := p.next
				END
			END
		END ARPEnumerate;


		(* Update or add an ARP entry. *)
		PROCEDURE ARPEnter(ip:IP. Adr; ether: Network.LinkAdr; forus: BOOLEAN);
		VAR
			p, q: ARPEntry;
			n: LONGINT;

			(* Create a new entry at the front of the hash list *)
			PROCEDURE NewEntry;
			BEGIN
				NEW(p);
				p.ip := ip;
				p.buf := NIL;
				p.sendTime := Kernel.GetTicks() - minARPTime;
				p.complete := FALSE;
				p.next := arpTable[n];
				arpTable[n] := p;
				Machine.AtomicInc(NARPEntries);
			END NewEntry;

		BEGIN {EXCLUSIVE}
			ASSERT (ip.usedProtocol = 4, 2345);

			n := ARPHash(ip.ipv4Adr);
			p := arpTable[n];
			WHILE (p # NIL) & (~IP.AdrsEqual(p.ip,ip)) DO
				p := p.next;
			END;
			IF (p = NIL) & (ARPMonitor OR forus) THEN
				NewEntry();
			END;
			IF p # NIL THEN	(* update address *)
				IF ARPMonitor & p.complete & ~Network.Equal(ether, p.ether, 0, 0, 6) THEN
					(* mapping changed! *)
					q := p.next;
					WHILE (q # NIL) & (~Network.Equal(ether, q.ether, 0, 0, 6) OR ~IP.AdrsEqual(q.ip, ip)) DO
						q := q.next
					END;
					IF q # NIL THEN (* we had this changed mapping before *)
						p := q; (* update it *)
					ELSE
						(* insert new mapping at front *)
						KernelLog.Enter;
						KernelLog.String("IP: Address for "); IP.OutAdr(p.ip);
						KernelLog.String(" changed from "); Network.OutLinkAdr(p.ether, 6);
						KernelLog.String(" to "); Network.OutLinkAdr(ether, 6);
						KernelLog.Exit;
						NewEntry();
					END;
				END;
				(* send queued packet *)
				IF p.buf # NIL THEN
					dev.Send(ether, EtherTypeIP, p.buf^, p.buf^, p.buf^, 0, 0, 0, LEN(p.buf^), FALSE);
					p.buf := NIL; (* 26.02.04 : fixes the resend bug *)
				END;
				(* update entry *)
				p.ether := ether;
				p.complete := TRUE;
				Clock.Get(p.updateTime, p.updateDate);
			END
		END ARPEnter;


		(* Send an ARP reply. Assume arp/ofs contains a valid ARP request packet. *)
		PROCEDURE ARPReply(VAR arp: ARRAY OF CHAR; ofs: LONGINT);
		BEGIN
			Machine.AtomicInc(NARPReply);
			arp[ofs+7] := 2X;	(* reply operation *)
			Network.Copy(arp, arp, ofs+8, ofs+18, 6+4); (* target := sender *)
			Network.Copy(dev.local, arp, 0, ofs+8, 6); (* sender ethernet address *)
			Network.Put4(arp, ofs+14, localAdr.ipv4Adr); (* sender ip address *)
			dev.Send(SYSTEM.VAL(Network.LinkAdr, arp[ofs + 18]), EtherTypeARP, arp, arp, arp, 0, 0, ofs, ARPPktLen, FALSE);
		END ARPReply;


		(* Look for the ethernet address matching the specified ip address. *)
		PROCEDURE ARPLookup(ip: IP.Adr; VAR ether: Network.LinkAdr): BOOLEAN;
		VAR p: ARPEntry; c: BOOLEAN;
		BEGIN
			ASSERT (ip.usedProtocol = 4, 2345);

			p := arpTable[ARPHash(ip.ipv4Adr)];
			LOOP
				IF p = NIL THEN RETURN FALSE END;
				IF IP.AdrsEqual (p.ip, ip) THEN
					c := p.complete; (* to allow concurrent "Enter" *)
					ether := p.ether;
					RETURN c;
				END;
				p := p.next
			END
		END ARPLookup;


		(* Queue an IP packet awaiting an ARP reply. *)
		PROCEDURE ARPQueue(dst: IP.Adr; VAR l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT);
		VAR p: ARPEntry; n: LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT (dst.usedProtocol = 4, 2345);

			Machine.AtomicInc(NARPPut);
			n := ARPHash(dst.ipv4Adr);
			p := arpTable[n];
			WHILE (p # NIL) & (~IP.AdrsEqual (p.ip, dst)) DO
				p := p.next
			END;
			IF p = NIL THEN
				(* not found, create a new incomplete entry *)
				NEW(p);
				p.complete := FALSE;
				p.ip := dst;
				p.sendTime := Kernel.GetTicks() - minARPTime;
				(* store one packet with the incomplete entry *)
				NEW(p.buf, h3len+h4len+dlen);
				Network.Copy(l3hdr, p.buf^, 0, 0, h3len);
				Network.Copy(l4hdr, p.buf^, 0, h3len, h4len);
				Network.Copy(data, p.buf^, dofs, h3len+h4len, dlen);
				(* publish the incomplete entry *)
				p.next := arpTable[n];
				arpTable[n] := p;
				Machine.AtomicInc(NARPEntries);
			END;
			IF p.complete THEN
				(* address arrived in the mean-time, so send the packet *)
				dev.Send(p.ether, EtherTypeIP, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen, FALSE);
			ELSE
				(* (re-)send ARP request *)
				IF Kernel.GetTicks() - p.sendTime >= minARPTime THEN
					ARPRequest(dst);
					p.sendTime := Kernel.GetTicks();
				ELSE
					Machine.AtomicInc(NARPSkipped);
				END
			END
		END ARPQueue;


		(* Send an ARP request *)
		PROCEDURE ARPRequest(ip: IP.Adr);
		VAR
			i: LONGINT;
			arp: ARRAY ARPPktLen OF CHAR;
		BEGIN
			ASSERT (ip.usedProtocol = 4, 2345);

			Machine.AtomicInc(NARPRequest);
			Network.Copy(arpProto, arp, 0, 0, ARPHdrLen);
			arp[7] := 1X; (* request operation *)
			Network.Copy(dev.local, arp, 0, 8, 6); (* sender ethernet address *)
			Network.Put4(arp, 14, localAdr.ipv4Adr); (* sender ip address *)
			(* target ethernet address *)
			FOR i:= 18 TO 23 DO
				arp[i] := 0X;
			END;
			Network.Put4(arp, 24, ip.ipv4Adr); (* target ip address *)
			dev.Send(dev.broadcast, EtherTypeARP, arp, arp, arp, 0, 0, 0, ARPPktLen, FALSE);
		END ARPRequest;


		(** Writes the configuration of this interface *)
		PROCEDURE OutInterface*;
		VAR i: LONGINT;
			str : ARRAY 32 OF CHAR;
		BEGIN
			IF closed THEN
				KernelLog.Enter;
				KernelLog.String("IP.OutInterface: Error: Interface already closed!"); KernelLog.Ln;
				KernelLog.Exit;
			ELSE
				KernelLog.Enter; KernelLog.Ln;
				KernelLog.String("=== Interface ==="); KernelLog.Ln;
				KernelLog.String("Interface name: "); KernelLog.String(name); KernelLog.Ln;
				KernelLog.String("Attached device: "); KernelLog.String(dev.name);
				IF dev.Linked() = Network.LinkLinked THEN
					KernelLog.String(" (LinkLinked)"); KernelLog.Ln;
				ELSIF dev.Linked() = Network.LinkNotLinked THEN
					KernelLog.String(" (LinkNotLinked)"); KernelLog.Ln;
				ELSE
					KernelLog.String(" (LinkUnknown)"); KernelLog.Ln;
				END;

				Network.LinkAdrToStr(dev.local, 8, str);
				KernelLog.String("MAC address: "); KernelLog.String(str); KernelLog.Ln;
				KernelLog.String("Local address: "); IP.OutAdr(localAdr); KernelLog.Ln;

				KernelLog.String("Netmask: "); IP.OutAdr(maskAdr); KernelLog.Ln;
				KernelLog.String("Gateway address: "); IP.OutAdr(gatewayAdr); KernelLog.Ln;
				KernelLog.String("Subnet: "); IP.OutAdr(subnetAdr); KernelLog.Ln;
				KernelLog.String("Net broadcast: "); IP.OutAdr(broadAdr); KernelLog.Ln;

				IF DNScount > 0 THEN
					FOR i:= 0 TO DNScount-1 DO
						KernelLog.String("DNS server: "); IP.OutAdr(DNS[i]); KernelLog.Ln;
					END;
				ELSE
					KernelLog.String("DNS server: none"); KernelLog.Ln;
				END;
				KernelLog.Exit;
			END;
		END OutInterface;


	END Interface;


VAR
	(* Module variables *)
	nextID: INTEGER;

	(* ARP *)
	arpProto: ARRAY ARPHdrLen OF CHAR;
	minARPTime: LONGINT;	(* minimum time between ARP requests in ticks *)

	(* ARP counters *)
	NARPPut-, NARPRcvTotal-, NARPRcvTooSmall-, NARPRcvIgnored-, NARPRcvDuplicate-, NARPBadAddr-,
	NARPRequest-, NARPReply-, NARPSkipped-: LONGINT;


(* Return TRUE if "adr1" and "adr2" are in the same subnet defined by "mask". *)
PROCEDURE SameSubnet(adr1, adr2, mask: LONGINT): BOOLEAN;
CODE {SYSTEM.AMD64}
	MOV EAX, [RBP + adr1]
	MOV EBX, [RBP + adr2]
	MOV ECX, [RBP + mask]
	AND EAX, ECX
	AND EBX, ECX
	CMP EAX, EBX
	SETZ AL
END SameSubnet;


(* Inline hash function for ARP hash table *)
PROCEDURE -ARPHash(ip: LONGINT): LONGINT;
CODE {SYSTEM.AMD64}
	; hash := ip MOD ARPHashSize;
	POP EAX
	; Convert IP to host byte order
	BSWAP EAX
	; MOD operation
	MOV EBX, ARPHashSize
	XOR EDX, EDX
	DIV EBX
	MOV EAX, EDX
END ARPHash;


(** Performs a check for Network if a packet is only for a single interface. Every ARP packet should go to every interface*)
PROCEDURE IsARPPacketForSingleInt(buffer: Network.Buffer): BOOLEAN;
BEGIN
	RETURN FALSE;
END IsARPPacketForSingleInt;


(** Performs a check for Network if a packet is for a single interface *)
PROCEDURE IsIPPacketForSingleInt(buffer: Network.Buffer): BOOLEAN;
BEGIN
	RETURN ~(buffer.data[buffer.ofs+19] = 0FFX);
END IsIPPacketForSingleInt;


(** Performs a check for Network if a packet is accepted by this interface. Every ARP packet is accepted *)
PROCEDURE IsARPPacketAccepted(buffer: Network.Buffer): BOOLEAN;
BEGIN
	RETURN TRUE;
END IsARPPacketAccepted;


(** Checks if an IPv4 packet is valid *)
PROCEDURE IsIPPacketValid(VAR buffer: Network.Buffer): BOOLEAN;
VAR
	isValid: BOOLEAN;
	hlen, tlen, frag: LONGINT;

BEGIN
	isValid := FALSE;

	Machine.AtomicInc(IP.NIPRcvTotal);
	IF buffer.len >= MinIPHdrLen THEN
		IF LSH(ORD(buffer.data[buffer.ofs]), -4) = IP.IPv4 THEN
			hlen := ORD(buffer.data[buffer.ofs]) MOD 10H * 4;
			IF (hlen >= MinIPHdrLen) & (hlen <= MaxIPHdrLen) THEN
				IF (Network.ChecksumIP IN buffer.calcChecksum) OR (IP.Checksum2(buffer.data, buffer.ofs, hlen, 0) = 0) THEN
					tlen := Network.GetNet2(buffer.data, buffer.ofs+2);
					IF (tlen >= hlen) & (tlen <= buffer.len) THEN
						IF tlen < buffer.len THEN
							(* size not used *)
							Machine.AtomicInc(IP.NIPTrim);
							buffer.len := tlen;
						END;
						frag := Network.GetNet2(buffer.data, buffer.ofs+6);
						IF (frag = 0) OR (frag = 4000H) THEN (* not a fragment *)
							IF hlen # MinIPHdrLen THEN
								(* process options here *)
								Machine.AtomicInc(IP.NIPOptions);
							END;

							isValid := TRUE;
						ELSE
							Machine.AtomicInc(IP.NIPCantReassemble)
						END
					ELSE
						Machine.AtomicInc(IP.NIPBadLength)
					END
				ELSE
					Machine.AtomicInc(IP.NIPBadChecksum)
				END
			ELSE
				Machine.AtomicInc(IP.NIPBadHdrLen)
			END
		ELSE
			Machine.AtomicInc(IP.NIPBadVersion)
		END
	ELSE
		Machine.AtomicInc(IP.NIPTooSmall)
	END;
	RETURN isValid;
END IsIPPacketValid;


(** Checks if an ARP packet is valid *)
PROCEDURE IsARPPacketValid(VAR buffer: Network.Buffer): BOOLEAN;
VAR
	isValid: BOOLEAN;

BEGIN
	isValid := FALSE;

	Machine.AtomicInc(NARPRcvTotal);
	IF buffer.len >= ARPPktLen THEN
		IF Network.Equal(buffer.data, arpProto, buffer.ofs, 0, ARPHdrLen-1) THEN
			isValid := TRUE;
		ELSE
			Machine.AtomicInc(NARPRcvIgnored)
		END
	ELSE
		Machine.AtomicInc(NARPRcvTooSmall)
	END;
	RETURN isValid;
END IsARPPacketValid;


(* Return a unique datagram ID *)
PROCEDURE GetNextID*(): INTEGER;
BEGIN {EXCLUSIVE}
	INC(nextID);
	RETURN nextID;
END GetNextID;


PROCEDURE Cleanup;
BEGIN
	(* Remove all interfaces *)
	WHILE IP.interfaces # NIL DO
		IP.interfaces.Close();
	END;
END Cleanup;


BEGIN
	(* intializations *)
	nextID := 0;

	(* Init ARP variables *)
	minARPTime := MinARPTime * Kernel.second DIV 1000;
	arpProto[0] := 0X; arpProto[1] := 1X; (* hardware type ethernet *)
	arpProto[2] := CHR(EtherTypeIP DIV 100H); (* protocol type IP *)
	arpProto[3] := CHR(EtherTypeIP MOD 100H);
	arpProto[4] := 6X; arpProto[5] := 4X; (* lengths *)
	arpProto[6] := 0X; arpProto[7] := 0X; (* no operation *)

	Modules.InstallTermHandler(Cleanup);
END IPv4.




Free:
SystemTools.Free TraceRoute VNC Ping WMFTPClient FTPClient WebFTPServer TCPServices TLS InitNetwork Ping DHCP TCP DNS UDP ICMP IPv4 IPv6 IP~

Start:
InitNetwork.Init

Compile:
PC.Compile \s IP.Mod IPv4.Mod IPv6.Mod ICMP.Mod UDP.Mod DNS.Mod TCP.Mod DHCP.Mod InitNetwork.Mod WebFTPServer.Mod FTPClient.Mod WMFTPClient.Mod Ping.Mod VNC.Mod TraceRoute.Mod~


History:
02.05.2005	eb	Created.