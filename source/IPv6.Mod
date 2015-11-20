MODULE IPv6; (** AUTHOR "Erwin Betschart"; PURPOSE "IP protocol version 6"; *)

IMPORT SYSTEM, Machine, Kernel, Objects, Modules, Strings, KernelLog, Network, IP, Plugins;

CONST
	(* DEBUG *)
	DEBUG = TRUE;

	(* IP *)
	EtherTypeIP* = 86DDH;
	MinIPHdrLen*= 40;
	MaxIPHdrLen* = 40;
	MaxFragPacketSize* = 65536;	(* Maximal size of a packet, which can be fragmented *)

	(* Interface *)
	V6RouterIntName = "v6Router";
	V6OwnRouterIntName = "v6OwnRouter";
	V6DHCPIntName = "v6DHCP";

	(* Neighbor etc.  cache *)
	CacheSize = 256;
	(* Neighbor cache reachablility states *)
	Incomplete = 0;
	Reachable = 1;
	Stale = 2;
	Delay = 3;
	Probe = 4;
	ReachableTime = 30000;

	(* autoconfig states *)
	TentativeInterface = 0;
	PreferredInterface = 1;
	DepricatedInterface = 2;
	InvalidInterface = 3;

	(* Next header types *)
	IPv6FragmentType = 44;
	IPv6RoutingHdrType = 43;
	IPv6HopByHopHdrType = 0;
	IPv6DestinationHdrType = 60;
	ICMPv6Type = 58;

	(* Header / Options Lengths *)
	NeighborHdrLen* = 20;
	RouterSolHdrLen* = 4;
	RouterAdvHdrLen = 12;
	LLAdrOptionLen* = 8;  (* Source or Target Link-Layer address option len *)
	FragmentHdrLen = 8;	(* Fragmentation header length *)
	RoutingHdrLen = 8;		(* Routing header length *)
	HopByHopHdrLen = 8;	(* Hop-by-hop header length *)
	DestinationHdrLen = 8;	(* Destination header length *)
	MaxPrefixOptions = 10;

	(* Timers *)
	ShortTimerTimeout = 3000;		(* 3 sec *)
	LongTimerTimeout = 600000;	(* 10 min *)

	(* ICMP codes *)
	ICMPv6CodeHopLimitExc* = 0;
	ICMPv6FragmentReassemblyExc* = 3;

	(* router *)
	MaxRtrAdvInterval = 600000; (* milliseconds; default from RFC 2461*)
	MinRtrAdvInterval = 198000;  (* milliseconds; default 0.33 * MaxRtrAdvInterval *)
	RouterPrefHigh = 1;
	RouterPrefMedium = 0;
	RouterPrefLow = 3;


TYPE
	(* List of incoming fragmented packets which should be reassembled *)
	FragmentList = POINTER TO RECORD
		fragmentID: LONGINT;
		nextHeader: LONGINT;
		srcAdr: IP.Adr;
		dstAdr: IP.Adr;
		packets: PacketFragment;
		startedAt: Kernel.MilliTimer;
		fragmentCount: LONGINT;
		next: FragmentList;
	END;


	(* List of a packet which was fragmented *)
	PacketFragment = POINTER TO RECORD
		buffer: Network.Buffer;
		fragmentOffset: LONGINT;
		moreFragments: BOOLEAN;
		next: PacketFragment;
		prev: PacketFragment;
	END;


	(* List of devices *)
	DeviceList = POINTER TO RECORD
		device: Network.LinkDevice;
		linkLocalInterface: Interface;
		next: DeviceList;
	END;


	(* Router config *)
	RouterConfig* = POINTER TO RECORD
		Device*: Plugins.Name;
		SendRouterAdvertisements*: BOOLEAN;
		ManagedAddressConfig*: BOOLEAN;
		OtherStatefulConfig*: BOOLEAN;
		LinkMTU*: LONGINT;
		ReachableTime*: LONGINT;	(* in seconds *)
		RetransTimer*: LONGINT;		(* in seconds *)
		CurrentHopLimit*: LONGINT;
		Lifetime*: LONGINT;			(* in seconds *)
		Prefixes*: PrefixConfig;
		next*: RouterConfig;
	END;


	(* Prefix config for router config *)
	PrefixConfig* = POINTER TO RECORD
		Prefix*: IP.Adr;
		IsSitePrefix*: BOOLEAN;
		ValidLifetime*: LONGINT;		(* in seconds *)
		OnLink*: BOOLEAN;
		PreferredLifetime*: LONGINT;(* in seconds *)
		Autonomous*: BOOLEAN;
		next*: PrefixConfig;
	END;


	(* A queue of packets used in neighbor cache to store pending packets *)
	PacketQueue = POINTER TO RECORD
		l3hdr: POINTER TO ARRAY OF CHAR;
		l4hdr: POINTER TO ARRAY OF CHAR;
		data: POINTER TO ARRAY OF CHAR;
		h3len: LONGINT;
		h4len: LONGINT;
		dofs: LONGINT;
		dlen: LONGINT;
		next: PacketQueue;
	END;


	(* Entry in the neighbor cache *)
	NeighborCacheEntry* = POINTER TO RECORD
		next: NeighborCacheEntry;
		neighborIP: IP.Adr;
		linkAdr: Network.LinkAdr;
		reachability: LONGINT; (* either 	Incomplete, Reachable, Stale, Delay or Probe *)
		isRouter: BOOLEAN;
		queuedPackets: PacketQueue;
		probes: LONGINT; (* number of unanswered probes *)
		lastConfirmation: Kernel.MilliTimer;
	END;


	(* Entry in the destination cache *)
	DestCacheEntry = POINTER TO RECORD
		next: DestCacheEntry;
		dest: IP.Adr;
		nextHop: IP.Adr;
		pmtu: LONGINT;
	END;


	(* Entry in the prefix list *)
	PrefixesEntry = POINTER TO RECORD
		next: PrefixesEntry;
		prefix: IP.Adr;
		lifetime: Kernel.MilliTimer;		(* time, when a prefix becomes invalid *)
	END;


	(* Entry in the default router list *)
	RoutersEntry = POINTER TO RECORD
		next: RoutersEntry;
		router: NeighborCacheEntry;
		routerLifetime: Kernel.MilliTimer;
	END;


	(* Entry in the local address cache *)
	LocalAdrCacheEntry = POINTER TO RECORD
		next: LocalAdrCacheEntry;
		localAdr: IP.Adr;
		interface: Interface;
		created: Kernel.MilliTimer;
	END;


TYPE
	(** Destination cache *)
	DestCache = OBJECT
	VAR
		(* Array which holds linked lists of destination cache entries. The last byte of the destination address
		    is the key to find a entry in this array *)
		destArray: ARRAY CacheSize OF DestCacheEntry;
		interface: Interface;	(* Interface on which this cache operates *)


	(** Constructor: Initializes destinations array.*)
	PROCEDURE &Constr*(int: Interface; prefixes: Prefixes);
	VAR
		i: LONGINT;

	BEGIN
		FOR i := 0 TO 255 DO
			destArray[i] := NIL;
		END;
		interface := int;
	END Constr;


	(** Add a new dest entry *)
	PROCEDURE Add(destAdr, nextHop: IP.Adr);
	VAR
		newDestItem: DestCacheEntry;
		destItem: DestCacheEntry;

	BEGIN {EXCLUSIVE}
		(* look if entry already exists *)
		destItem := destArray[ORD(destAdr.ipv6Adr[15])];
		WHILE (destItem # NIL) & (~IP.AdrsEqual(destItem.dest, destAdr)) DO
			destItem := destItem.next;
		END;

		IF destItem = NIL THEN
			(* Add new entry *)
			NEW(newDestItem);
			newDestItem.next := NIL;
			newDestItem.dest := destAdr;
			newDestItem.nextHop := nextHop;
			newDestItem.pmtu := interface.linkMTU;

			(* put in array *)
			destItem := destArray[ORD(destAdr.ipv6Adr[15])];
			IF destItem = NIL THEN
				(* first element *)
				destArray[ORD(destAdr.ipv6Adr[15])] := newDestItem;
			ELSE
				WHILE destItem.next # NIL DO
					destItem := destItem.next;
				END;
				destItem.next := newDestItem;
			END;
		END;
	END Add;


	(** Remove a destination entry *)
	PROCEDURE Remove(destAdr: IP.Adr);
	VAR
		destItem: DestCacheEntry;

	BEGIN {EXCLUSIVE}
		destItem := destArray[ORD(destAdr.ipv6Adr[15])];
		IF destItem # NIL THEN
			IF IP.AdrsEqual(destItem.dest, destAdr) THEN
				(* remove first element *)
				destArray[ORD(destAdr.ipv6Adr[15])] := destItem.next;
			ELSIF destItem.next # NIL THEN
				(* search for elem *)
				WHILE (destItem.next.next # NIL) & (~IP.AdrsEqual(destItem.next.dest, destAdr)) DO
					destItem := destItem.next;
				END;
				IF destItem.next # NIL THEN
					(* found the right elem *)
					destItem.next := destItem.next.next;
				END;
			END;
		END;
	END Remove;


	(* Changes a PMTU of a cache entry *)
	PROCEDURE ChangePMTU(adr: IP.Adr; newPMTU: LONGINT);
	VAR
		destItem: DestCacheEntry;

	BEGIN
		destItem := destArray[ORD(adr.ipv6Adr[15])];
		IF destItem # NIL THEN
			(* search for right element *)
			WHILE (destItem # NIL) & (~IP.AdrsEqual(destItem.dest, adr)) DO
				destItem := destItem.next;
			END;

			IF destItem # NIL THEN
				destItem.pmtu := newPMTU;
			END;
		END;
	END ChangePMTU;


	(** Get next hop address *)
	PROCEDURE GetNextHop(destAdr: IP.Adr): IP.Adr;
	VAR
		nextHop: IP.Adr;
		destItem: DestCacheEntry;

	BEGIN
		IF interface.IsMulticast(destAdr) THEN
			(* Multicast packets are considered to be on-link *)
			nextHop := destAdr;
		ELSE
			nextHop := IP.NilAdr;
			destItem := destArray[ORD(destAdr.ipv6Adr[15])];
			WHILE (destItem # NIL) & (~IP.AdrsEqual(destAdr, destItem.dest)) DO
				destItem := destItem.next;
			END;

			IF destItem # NIL THEN
				nextHop := destItem.nextHop;
			ELSE
				nextHop := NextHopDetermination(destAdr);

				IF IP.IsNilAdr(nextHop) THEN
					(* assume destination is link-local *)
					nextHop := destAdr;
				END;

				(* Save results of NextHopDetermination *)
				Add(destAdr, nextHop);
			END;
		END;
		RETURN nextHop;
	END GetNextHop;


	(** Get PMTU of a address *)
	PROCEDURE GetPMTU(adr: IP.Adr): LONGINT;
	VAR
		destItem: DestCacheEntry;
		pmtu: LONGINT;

	BEGIN
		destItem := destArray[ORD(adr.ipv6Adr[15])];
		WHILE (destItem # NIL) & (~IP.AdrsEqual(adr, destItem.dest)) DO
			destItem := destItem.next;
		END;

		IF destItem # NIL THEN
			pmtu := destItem.pmtu;
		ELSE
			pmtu := interface.linkMTU;
		END;
		RETURN pmtu;
	END GetPMTU;


	(** Next hop determination *)
	PROCEDURE NextHopDetermination(destAdr: IP.Adr): IP.Adr;
	VAR
		longestPrefix: PrefixesEntry;
		nextHop: IP.Adr;

	BEGIN
		(* perform longest prefix match against prefix list *)
		longestPrefix := interface.prefixes.FindLongestMatch(destAdr);

		IF longestPrefix = NIL THEN
			(* select a router from the Default Router list *)
			nextHop := interface.routers.GetRouter();

			IF IP.IsNilAdr(nextHop) THEN
				(* no default router is found assume destAdr is on-link, therefore
				    next hop = destination address *)
				nextHop := destAdr;
			END;
		ELSE
			(* destination is on-link: nextHop is same as destination *)
			nextHop := destAdr;
		END;

		RETURN nextHop;
	END NextHopDetermination;


	(** When a router become invalid update all affected entries *)
	PROCEDURE ChangeDests(fromAdr: IP.Adr; toAdr: IP.Adr);
	VAR
		destItem: DestCacheEntry;
		i: LONGINT;

	BEGIN
		FOR i := 0 TO CacheSize DO
			destItem := destArray[i];

			WHILE destItem # NIL DO
				IF IP.AdrsEqual(fromAdr, destItem.dest) THEN
					destItem.dest := toAdr;
				END;
				destItem := destItem.next;
			END;
		END;
	END ChangeDests;


	(** Clears the destination cache *)
	PROCEDURE Clear;
	VAR
		i: LONGINT;

	BEGIN
		FOR i := 0 TO CacheSize - 1 DO
			destArray[i] := NIL;
		END;
	END Clear;

	END DestCache;


TYPE
	(** Neighbor cache. *)
	NeighborCache = OBJECT
	VAR
		neighbors: ARRAY CacheSize OF NeighborCacheEntry;
			(* Array which holds all neighbor entries. The last byte of the neighbor IP is the index
			    of the array *)
		interface: Interface;	(* Interface the neighbor cache operates on *)


	(** Constructor: Initializes neighbor array.*)
	PROCEDURE &Constr *(int: Interface);
	VAR
		i: LONGINT;

	BEGIN
		interface := int;

		FOR i := 0 TO (CacheSize - 1) DO
			neighbors[i] := NIL;
		END;
	END Constr;


	(** Add an IP to the neighbor cache *)
	PROCEDURE Add(neighborIP: IP.Adr);
	VAR
		newNeighborEntry: NeighborCacheEntry;
		neighborItem: NeighborCacheEntry;

	BEGIN {EXCLUSIVE}
		(* look if already an entry exists *)
		newNeighborEntry := Get(neighborIP);
		IF newNeighborEntry = NIL THEN
			NEW(newNeighborEntry);

			(* initialize neighbor cache entry to incomplete*)
			newNeighborEntry.next := NIL;
			newNeighborEntry.neighborIP := neighborIP;
			newNeighborEntry.reachability := Incomplete;
			newNeighborEntry.isRouter := FALSE;
			newNeighborEntry.queuedPackets := NIL;
			newNeighborEntry.probes := 0;
			Kernel.SetTimer(newNeighborEntry.lastConfirmation, 0);

			(* put into neighbor cache *)
			neighborItem := neighbors[ORD(neighborIP.ipv6Adr[15])];

			IF neighborItem = NIL THEN
				neighbors[ORD(neighborIP.ipv6Adr[15])] := newNeighborEntry;
			ELSE
				WHILE (neighborItem.next # NIL) DO
					neighborItem := neighborItem.next
				END;

				neighborItem.next := newNeighborEntry;
			END;
		END;
	END Add;


	(* Remove *)
	PROCEDURE Remove(neighborIP: IP.Adr);
	VAR
		neighborItem: NeighborCacheEntry;

	BEGIN {EXCLUSIVE}
		neighborItem := neighbors[ORD(neighborIP.ipv6Adr[15])];

		(* first element *)
		IF IP.AdrsEqual(neighborItem.neighborIP, neighborIP) THEN
			neighbors[ORD(neighborIP.ipv6Adr[15])] := neighborItem.next;
		ELSE
			WHILE (neighborItem.next # NIL) & (~IP.AdrsEqual(neighborItem.neighborIP, neighborIP)) DO
				neighborItem := neighborItem.next;
			END;

			IF neighborItem.next # NIL THEN
				(* found *)
				neighborItem.next := neighborItem.next.next;
			END;
		END;
	END Remove;


	(** Delete expired neighbor entries *)
	PROCEDURE ClearExpired;
	VAR
		neighborItem: NeighborCacheEntry;
		neighborItemPrev: NeighborCacheEntry;
		i: LONGINT;

	BEGIN {EXCLUSIVE}
		FOR i := 0 TO CacheSize - 1 DO
			neighborItem := neighbors[i];

			WHILE neighborItem # NIL DO
				IF Kernel.Expired(neighborItem.lastConfirmation) THEN
					IF neighborItemPrev = NIL THEN
						(* first item *)
						neighbors[i] := neighborItem.next;
					ELSE
						neighborItemPrev.next := neighborItem.next;
					END;
				END;
				IF (neighborItem.next # NIL) & (neighborItem.next # neighbors[i]) THEN
					neighborItemPrev := neighborItem;
				ELSE
					neighborItemPrev := NIL;
				END;
				neighborItem := neighborItem.next;
			END;
		END;
	END ClearExpired;


	(* Deliver a neighbor cache entry *)
	PROCEDURE Get*(adr: IP.Adr): NeighborCacheEntry;
	VAR
		neighborItem: NeighborCacheEntry;

	BEGIN
		neighborItem := neighbors[ORD(adr.ipv6Adr[15])];

		WHILE (neighborItem # NIL) & (~IP.AdrsEqual(neighborItem.neighborIP, adr)) DO
			neighborItem := neighborItem.next;
		END;
		RETURN neighborItem;
	END Get;


	(* Return link-layer address of a IP address *)
	PROCEDURE GetLinkLayerAdr(adr: IP.Adr; VAR linkAdr: Network.LinkAdr): BOOLEAN;
	VAR
		neighborItem: NeighborCacheEntry;
		found: BOOLEAN;

	BEGIN
		neighborItem := neighbors[ORD(adr.ipv6Adr[15])];
		WHILE (neighborItem # NIL) & (~IP.AdrsEqual(neighborItem.neighborIP, adr)) DO
			neighborItem := neighborItem.next;
		END;

		IF (neighborItem # NIL) & (neighborItem.reachability # Incomplete) THEN
			(* check timers *)
			IF Kernel.Expired(neighborItem.lastConfirmation) THEN
				(* Send a Neighbor Solicitation message *)
				sendNeighborSolicitation(interface, neighborItem.linkAdr, adr, FALSE);
			END;

			linkAdr := neighborItem.linkAdr;
			found := TRUE;
		ELSE
			found := FALSE;
		END;
		RETURN found;
	END GetLinkLayerAdr;


	(* Initiate address resolution *)
	PROCEDURE AddressResolution(neighborIP: IP.Adr; CONST l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT);
	VAR
		neighborEntry: NeighborCacheEntry;
		packetQueue: PacketQueue;
		packetQueueItem: PacketQueue;
		linkDst: Network.LinkAdr;
		i: LONGINT;

	BEGIN
		(* create a new neighbor cache entry *)
		Add(neighborIP);
		neighborEntry := Get(neighborIP);

		IF neighborEntry # NIL THEN
			(* Queue packet *)
			NEW(packetQueueItem);
			NEW(packetQueueItem.l3hdr, LEN(l3hdr));
			FOR i := 0 TO LEN(l3hdr) - 1 DO
				packetQueueItem.l3hdr[i] := l3hdr[i];
			END;
			NEW(packetQueueItem.l4hdr, LEN(l4hdr));
			FOR i := 0 TO LEN(l4hdr) - 1 DO
				packetQueueItem.l4hdr[i] := l4hdr[i];
			END;
			NEW(packetQueueItem.data, LEN(data));
			FOR i := 0 TO LEN(data) - 1 DO
				packetQueueItem.data[i] := data[i];
			END;
			packetQueueItem.h3len := h3len;
			packetQueueItem.h4len := h4len;
			packetQueueItem.dofs := dofs;
			packetQueueItem.dlen := dlen;

			packetQueue := neighborEntry.queuedPackets;
			packetQueueItem.next := packetQueue;

			neighborEntry.queuedPackets := packetQueueItem;

			(* link and IP destination addresses are the solicited node addresses *)
			linkDst := linkMulticastAllNodesAdr;
			linkDst[2] := 0FFX;
			linkDst[3] := neighborIP.ipv6Adr[13];
			linkDst[4] := neighborIP.ipv6Adr[14];
			linkDst[5] := neighborIP.ipv6Adr[15];

			(* Send a Neighbor Solicitation message *)
			sendNeighborSolicitation(interface, linkDst, neighborIP, TRUE);
		END;
	END AddressResolution;


	(* Send queued Packets *)
	PROCEDURE SendQueuedPackets(neighborCacheEntry: NeighborCacheEntry);
	VAR
		queuedPacket: PacketQueue;
		pmtu: LONGINT;
		toFragment: BOOLEAN;

	BEGIN {EXCLUSIVE}
		toFragment := FALSE;
		queuedPacket := neighborCacheEntry.queuedPackets;

		WHILE queuedPacket # NIL DO

			pmtu := interface.destCache.GetPMTU(neighborCacheEntry.neighborIP);
			IF queuedPacket.h3len+queuedPacket.h4len+queuedPacket.dlen > pmtu THEN
				(* fragment packet *)
				toFragment := TRUE;
			END;

			IF ~toFragment THEN
				interface.dev.Send(neighborCacheEntry.linkAdr,
								     EtherTypeIP,
								     queuedPacket.l3hdr^,
								     queuedPacket.l4hdr^,
								     queuedPacket.data^,
								     queuedPacket.h3len,
								     queuedPacket.h4len,
								     queuedPacket.dofs,
								     queuedPacket.dlen,
								     FALSE);
			ELSE
				interface.DoFragAndSend(pmtu,
								 neighborCacheEntry.linkAdr,
								 queuedPacket.l3hdr^,
								 queuedPacket.l4hdr^,
								 queuedPacket.data^,
								 queuedPacket.h3len,
								 queuedPacket.h4len,
								 queuedPacket.dofs,
								 queuedPacket.dlen);
			END;

			queuedPacket := queuedPacket.next;
		END;
		neighborCacheEntry.queuedPackets := NIL;
	END SendQueuedPackets;

	END NeighborCache;


TYPE
	(* Prefix list *)
	Prefixes = OBJECT
	VAR
		prefixes: PrefixesEntry;

	(* Constructor: Initializes prefixes.*)
	PROCEDURE &Constr*;
	BEGIN
		prefixes := NIL;
	END Constr;


	(* Add a prefix. Lifetime in seconds *)
	PROCEDURE Add(prefix: IP.Adr; lifetime: LONGINT);
	VAR
		prefixItem: PrefixesEntry;

	BEGIN {EXCLUSIVE}
		NEW(prefixItem);
		prefixItem.prefix := prefix;

		Kernel.SetTimer(prefixItem.lifetime, lifetime * 1000); (* Milliseconds *)

		prefixItem.next := prefixes;
		prefixes := prefixItem;
	END Add;


	(* Remove a prefix *)
	PROCEDURE Remove(prefix: IP.Adr);
	VAR
		prefixItem: PrefixesEntry;

	BEGIN {EXCLUSIVE}
		prefixItem := prefixes;

		IF prefixItem # NIL THEN
			(* first element? *)
			IF IP.AdrsEqual(prefix, prefixItem.prefix) THEN
				prefixes := prefixItem.next;
			ELSE
				WHILE (prefixItem.next # NIL) & (~IP.AdrsEqual(prefix, prefixItem.next.prefix)) DO
					prefixItem := prefixItem.next;
				END;
				IF prefixItem # NIL THEN
					(* remove item from list *)
					prefixItem.next := prefixItem.next.next;
				END;
			END;
		END;
	END Remove;


	(** Delete expired prefixes *)
	PROCEDURE ClearExpired;
	VAR
		prefixItem: PrefixesEntry;
		prefixItemPrev: PrefixesEntry;

	BEGIN {EXCLUSIVE}
		prefixItem := prefixes;
		WHILE prefixItem # NIL DO
			IF Kernel.Expired(prefixItem.lifetime) THEN
				IF prefixItemPrev = NIL THEN
					(* first item *)
					prefixes := prefixItem.next;
				ELSE
					prefixItemPrev.next := prefixItem.next;
				END;

			END;
			IF (prefixItem.next # NIL) & (prefixItem.next # prefixes) THEN
				prefixItemPrev := prefixItem;
			ELSE
				prefixItemPrev := NIL;
			END;
			prefixItem := prefixItem.next;
		END;
	END ClearExpired;


	(* Deliver a specific prefix entry *)
	PROCEDURE Get(prefix: IP.Adr): PrefixesEntry;
	VAR
		prefixItem: PrefixesEntry;

	BEGIN
		prefixItem := prefixes;

		WHILE ((prefixItem # NIL) & (~IP.AdrsEqual(prefix, prefixItem.prefix)) & (~(prefix.data = prefixItem.prefix.data))) DO
			prefixItem := prefixItem.next;
		END;
		RETURN prefixItem;
	END Get;


	(* Is there a prefix which matches adr *)
	PROCEDURE FindLongestMatch(adr: IP.Adr): PrefixesEntry;
	VAR
		prefixItem: PrefixesEntry;
		longestPrefixItem: PrefixesEntry;
		longestPrefix: LONGINT;

	BEGIN
		prefixItem := prefixes;
		longestPrefixItem := NIL;
		longestPrefix := 0;

		WHILE (prefixItem # NIL) DO
			IF IP.MatchPrefix (adr, prefixItem.prefix) THEN
				IF prefixItem.prefix.data > longestPrefix THEN
					longestPrefix := prefixItem.prefix.data;
					longestPrefixItem := prefixItem;
				END;
			END;

			prefixItem := prefixItem.next;
		END;

		IF longestPrefixItem # NIL THEN
			RETURN longestPrefixItem;
		END;
		RETURN NIL;
	END FindLongestMatch;

	END Prefixes;


TYPE
	(* Default Router List *)
	Routers = OBJECT
	VAR
		routers: RoutersEntry;
		lastRobinRouter: RoutersEntry;	(* last choosen Router with round robin *)
		interface: Interface;

	(* Constructor: Initializes routers.*)
	PROCEDURE &Constr*(int: Interface);
	BEGIN
		routers := NIL;
		lastRobinRouter := routers;
		interface := int;
	END Constr;


	(* Add a default router *)
	PROCEDURE Add(routerIP: IP.Adr; routerLinkAdr: Network.LinkAdr; lifetime: LONGINT): RoutersEntry;
	VAR
		router: RoutersEntry;
		neighbor: NeighborCacheEntry;

	BEGIN {EXCLUSIVE}
		lifetime := lifetime * 1000; (* lifetime in milliseconds *)

		router := Get(routerIP);

		IF router = NIL THEN
			(* default routers does not exist *)
			NEW(router);
			router.next := routers;
			routers := router;
		END;

		Kernel.SetTimer(router.routerLifetime, lifetime);

		neighbor := interface.neighborCache.Get(routerIP);
		IF neighbor = NIL THEN
			interface.neighborCache.Add(routerIP);
			neighbor := interface.neighborCache.Get(routerIP);
			neighbor.linkAdr := routerLinkAdr;
			neighbor.reachability := Stale;
			neighbor.isRouter := TRUE;
			neighbor.probes := 0;
			Kernel.SetTimer(neighbor.lastConfirmation, lifetime);
		ELSE
			Kernel.SetTimer(neighbor.lastConfirmation, lifetime);
		END;
		router.router := neighbor;
		RETURN router;
	END Add;


	(* Remove a default router *)
	PROCEDURE Remove(router: IP.Adr);
	VAR
		routerItem: RoutersEntry;
		routerItemPrev: RoutersEntry;

	BEGIN {EXCLUSIVE}
		routerItem := routers;

		WHILE (routerItem # NIL) & (~IP.AdrsEqual(routerItem.router.neighborIP, router)) DO
			routerItemPrev := routerItem;
			routerItem := routerItem.next;
		END;

		IF routerItem # NIL THEN
			IF routerItemPrev = NIL THEN
				(* first element *)
				routers := routerItem.next;
			ELSE
				routerItemPrev.next := routerItem.next;
			END;
		END;
	END Remove;


	(* Deliver a specific router *)
	PROCEDURE Get(routerIP: IP.Adr): RoutersEntry;
	VAR
		item: RoutersEntry;

	BEGIN
		item := routers;

		WHILE (item # NIL) & (~IP.AdrsEqual(item.router.neighborIP, routerIP)) DO
			item := item.next;
		END;
		RETURN item;
	END Get;


	(* Deliver a default router *)
	PROCEDURE GetRouter(): IP.Adr;
	VAR
		routersItem: RoutersEntry;
		routerAdr: IP.Adr;
		searchReachable: BOOLEAN;

	BEGIN
		(* deliver router: first searched for REACHABLES then other in round robin fashion *)
		routerAdr := IP.NilAdr;

		IF routers # NIL THEN
			IF lastRobinRouter = NIL THEN
				lastRobinRouter := routers;
			END;
			routersItem := lastRobinRouter.next;
			IF routersItem = NIL THEN
				(* start from begin *)
				routersItem := routers.next;
			END;

			searchReachable := TRUE;
			LOOP
				IF routersItem = NIL THEN
					(* start from begin *)
					routersItem := routers;
				END;

				IF (routersItem = lastRobinRouter) & ~searchReachable THEN
					IF routersItem.router.reachability # Incomplete THEN
						routerAdr := routersItem.router.neighborIP;
					ELSE
						(* searched for reachable and other found nothing *)
						lastRobinRouter := NIL;
						routerAdr := IP.NilAdr;
						EXIT;
					END;
				END;

				IF (routersItem = lastRobinRouter) & searchReachable THEN
					(* searched for reachable found nothing *)
					searchReachable := FALSE;
					IF routersItem.router.reachability = Reachable THEN
						(* only a single reachable router *)
						EXIT;
					END;
					routersItem := routersItem.next;
					IF routersItem = NIL THEN
						routersItem := routers;
					END;
				END;

				IF searchReachable & (routersItem.router.reachability = Reachable) THEN
					(* found a reachable router *)
					routerAdr := routersItem.router.neighborIP;
					lastRobinRouter := routersItem;
					EXIT;
				END;

				IF ~searchReachable & (routersItem.router.reachability # Incomplete) THEN
					(* found a stale, delay or probe router *)
					routerAdr := routersItem.router.neighborIP;
					lastRobinRouter := routersItem;
					EXIT;
				END;
				routersItem := routersItem.next;
			END;
		END;
		RETURN routerAdr;
	END GetRouter;


	(** Delete expired routers *)
	PROCEDURE ClearExpired;
	VAR
		routerItem: RoutersEntry;
		routerItemPrev: RoutersEntry;

	BEGIN {EXCLUSIVE}
		routerItem := routers;
		WHILE routerItem # NIL DO
			IF Kernel.Expired(routerItem.routerLifetime) THEN
				IF routerItemPrev = NIL THEN
					(* first item *)
					routers := routerItem.next;
				ELSE
					routerItemPrev.next := routerItem.next;
				END;

			END;
			IF (routerItem.next # NIL) & (routerItem.next # routers) THEN
				routerItemPrev := routerItem;
			ELSE
				routerItemPrev := NIL;
			END;
			routerItem := routerItem.next;
		END;
	END ClearExpired;


	(** Writes all default routers *)
	PROCEDURE OutRouters;
	VAR
		item: RoutersEntry;
	BEGIN
		KernelLog.String("Default routers:"); KernelLog.Ln;
		item := routers;
		WHILE item # NIL DO
			IP.OutAdr(item.router.neighborIP); KernelLog.Ln;
			item := item.next;
		END;
	END OutRouters;

	END Routers;


TYPE
	(** When multiple network devices are present the IPv6 implementation is unable to know on which interface
		a local address is reachable. To prevent sending a lot of neighbor discovery messages this cache is created. *)
	LocalAdrCache = OBJECT
	VAR
		localAdrs: ARRAY CacheSize OF LocalAdrCacheEntry;
			(* Array which holds all local address entries. The last byte of the neighbor IP is the index
			    of the array *)

	PROCEDURE &Constr*;
	VAR
		i: LONGINT;

	BEGIN
		FOR i := 0 TO (CacheSize - 1) DO
			localAdrs[i] := NIL;
		END;
	END Constr;


	(** Add an IP to the neighbor cache *)
	PROCEDURE Add(localIP: IP.Adr; interface: Interface);
	VAR
		newLocalAdrEntry: LocalAdrCacheEntry;
		localAdrItem: LocalAdrCacheEntry;

	BEGIN {EXCLUSIVE}
		(* look if already an entry exists *)
		newLocalAdrEntry := Get(localIP);
		IF newLocalAdrEntry = NIL THEN
			NEW(newLocalAdrEntry);

			(* initialize local adr cache entry *)
			newLocalAdrEntry.next := NIL;
			newLocalAdrEntry.localAdr := localIP;
			newLocalAdrEntry.interface := interface;
			Kernel.SetTimer(newLocalAdrEntry.created, LongTimerTimeout);

			(* put into local address cache *)
			localAdrItem := localAdrs[ORD(localIP.ipv6Adr[15])];

			IF localAdrItem = NIL THEN
				localAdrs[ORD(localIP.ipv6Adr[15])] := newLocalAdrEntry;
			ELSE
				WHILE (localAdrItem.next # NIL) DO
					localAdrItem := localAdrItem.next
				END;

				localAdrItem.next := newLocalAdrEntry;
			END;
		END;
	END Add;


	(* Remove *)
	PROCEDURE Remove(localIP: IP.Adr);
	VAR
		localAdrItem: LocalAdrCacheEntry;

	BEGIN {EXCLUSIVE}
		localAdrItem := localAdrs[ORD(localIP.ipv6Adr[15])];

		(* first element *)
		IF IP.AdrsEqual(localAdrItem.localAdr, localIP) THEN
			localAdrs[ORD(localIP.ipv6Adr[15])] := localAdrItem.next;
		ELSE
			WHILE (localAdrItem.next # NIL) & (~IP.AdrsEqual(localAdrItem.localAdr, localIP)) DO
				localAdrItem := localAdrItem.next;
			END;

			IF localAdrItem.next # NIL THEN
				(* found *)
				localAdrItem.next := localAdrItem.next.next;
			END;
		END;
	END Remove;


	(** Delete expired local address entries *)
	PROCEDURE ClearExpired;
	VAR
		localAdrItem: LocalAdrCacheEntry;
		localAdrItemPrev: LocalAdrCacheEntry;
		i: LONGINT;

	BEGIN {EXCLUSIVE}
		FOR i := 0 TO CacheSize - 1 DO
			localAdrItem := localAdrs[i];

			WHILE localAdrItem # NIL DO
				IF Kernel.Expired(localAdrItem.created) THEN
					IF localAdrItemPrev = NIL THEN
						(* first item *)
						localAdrs[i] := localAdrItem.next;
					ELSE
						localAdrItemPrev.next := localAdrItem.next;
					END;
				END;
				IF (localAdrItem.next # NIL) & (localAdrItem.next # localAdrs[i]) THEN
					localAdrItemPrev := localAdrItem;
				ELSE
					localAdrItemPrev := NIL;
				END;
				localAdrItem := localAdrItem.next;
			END;
		END;
	END ClearExpired;


	(* Deliver a local address cache entry *)
	PROCEDURE Get*(localAdr: IP.Adr): LocalAdrCacheEntry;
	VAR
		localAdrItem: LocalAdrCacheEntry;

	BEGIN
		localAdrItem := localAdrs[ORD(localAdr.ipv6Adr[15])];

		WHILE (localAdrItem # NIL) & (~IP.AdrsEqual(localAdrItem.localAdr, localAdr)) DO
			localAdrItem := localAdrItem.next;
		END;
		RETURN localAdrItem;
	END Get;


	(* Deliver the interface according to a local address *)
	PROCEDURE GetInterface*(localAdr: IP.Adr): Interface;
	VAR
		localAdrItem: LocalAdrCacheEntry;

	BEGIN
		localAdrItem := localAdrs[ORD(localAdr.ipv6Adr[15])];

		WHILE (localAdrItem # NIL) & (~IP.AdrsEqual(localAdrItem.localAdr, localAdr)) DO
			localAdrItem := localAdrItem.next;
		END;

		IF localAdrItem # NIL THEN
			RETURN localAdrItem.interface;
		ELSE
			RETURN NIL;
		END;
	END GetInterface;

	END LocalAdrCache;


TYPE
	Interface* = OBJECT (IP.Interface)

	VAR
		destCache: DestCache;
		neighborCache: NeighborCache;
		prefixes: Prefixes;
		routers: Routers;
		linkMTU: LONGINT;
		curHopLimit*: LONGINT;

		linkMulticastSolicited: Network.LinkAdr;
		linkLocalSolicitedNodeAdr: IP.Adr;

		(* Autoconfiguration *)
		autoconfigurated*: BOOLEAN;
		autoconfigState: LONGINT;
		createStatelessInterface*: BOOLEAN;
		createStatefulInterface: BOOLEAN;
		routerSolCount: LONGINT;

		(* Timers *)
		shortTimer: Kernel.Timer;
		longTimer: Kernel.MilliTimer;
		duplicateTimer: Kernel.MilliTimer;

		intName: IP.Name;
		intv6: Interface;
		int: IP.Interface;
		res: LONGINT;
		fragmentList: FragmentList;

		(* router *)
		isRouter*: BOOLEAN;
		routerConfig: RouterConfig;
		nextRtrAdvertisement: LONGINT;	(* When should the next unsolicited router advertisement be sent; in numbers of shortTimer *)


		(** Constructor - Open an IPv6 interface and add it to the IP configuration.
			"name" must be a unique name for this interface (tested in "AddInterface").
			"dev" must be a Network.LinkDevice that can be used in other interfaces => multiple IP addresses on the
			same interface. *)
		PROCEDURE &Constr*(name: IP.Name; dev: Network.LinkDevice; VAR res: LONGINT);
		VAR
			devListItem: DeviceList;

		BEGIN
			ASSERT(dev # NIL);

			SELF.dev := dev;
			protocol := IP.IPv6;
			autoconfigurated := FALSE;
			autoconfigState := TentativeInterface;
			createStatelessInterface := FALSE;
			createStatefulInterface := FALSE;
			routerSolCount := 0;
			fragmentList := NIL;
			isRouter := FALSE;
			routerConfig:= NIL;
			nextRtrAdvertisement := 0;

			(* create caches *)
			NEW(prefixes);
			NEW(routers, SELF);
			NEW(destCache, SELF, prefixes);
			NEW(neighborCache, SELF);

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
			linkLocalSolicitedNodeAdr := IP.NilAdr;

			(* broadAdr is Link-local multicast address *)
			broadAdr := IP.NilAdr;
			broadAdr.usedProtocol := IP.IPv6;
			broadAdr.ipv6Adr[0] := 0FFX;
			broadAdr.ipv6Adr[1] := 2X;
			broadAdr.ipv6Adr[15] := 1X;
			broadAdr.data := 0;

			(* init DNS *)
			DNScount := 0;

			closed := FALSE;

			IP.AddInterface(SELF, res);
			IF res = IP.Ok THEN
				(* install receivers *)
				dev.InstallReceiver(SELF, EtherTypeIP, IPInput, IsPacketValid, IsPacketForSingleInt, IsPacketAccepted
				, IP.IPForwarding); (* IPv6 *)

				(* Update list of devices *)
				devListItem := devList;
				WHILE (devListItem # NIL) & (devListItem.device # dev) DO
					devListItem := devListItem.next;
				END;

				IF devListItem = NIL THEN
					NEW(devListItem);
					devListItem.device := dev;
					devListItem.next := devList;
					devList := devListItem;
				END;
			ELSE
				closed := TRUE;
			END;
		END Constr;


		(** Close and deactivate the interface, i.e. remove it from the configuration. *)
		PROCEDURE Close*;
		VAR
			i: LONGINT;

		BEGIN {EXCLUSIVE}
			ASSERT(~closed);

			dev.RemoveReceiver(SELF, EtherTypeIP);
			closed := TRUE;
			shortTimer.Wakeup;

			(* To be "sure" that the active body is terminated *)
			FOR i := 0 TO 9999 DO
				Objects.Yield;
			END;
			IP.RemoveInterface(SELF);
		END Close;


		(** Set addresses. Is normally called just after instanciation, but can also be called later, e.g. by DHCP.
			If "gatewayAdr" is not "NilAdr", it will be added to the default router list. *)
		PROCEDURE SetAdrs*(localAdr, prefixAdr, defaultRouterAdr: IP.Adr; VAR res: LONGINT);
		VAR
			devListItem: DeviceList;

		BEGIN {EXCLUSIVE}
			IF DEBUG THEN
				ASSERT ((IP.IsNilAdr(localAdr)) OR (localAdr.usedProtocol = 6), 2345);
				ASSERT ((IP.IsNilAdr(prefixAdr)) OR (prefixAdr.usedProtocol = 6), 2345);
			END;

			IF (~IP.IsNilAdr(localAdr)) THEN
				IF IP.IsNilAdr(prefixAdr) & ~(dev.name = "Loopback") THEN
					(* prefix has to be set! *)
					res := IP.PrefixNotSet;
					RETURN;
				END;

				(* Check if addresses are of same protocol as interface *)
				IF dev.name = "Loopback" THEN
					IF localAdr.usedProtocol # IP.IPv6 THEN
						res := IP.IPv4AdrUsedOnIPv6Interface;
						RETURN;
					END;
				ELSIF (localAdr.usedProtocol # IP.IPv6) OR (prefixAdr.usedProtocol # IP.IPv6) THEN
					res := IP.IPv4AdrUsedOnIPv6Interface;
					RETURN;
				END;

				(* set addresses *)
				SELF.localAdr := localAdr;
				SELF.maskAdr := prefixAdr;

				linkLocalSolicitedNodeAdr := IP.NilAdr;
				linkLocalSolicitedNodeAdr.usedProtocol := IP.IPv6;
				linkLocalSolicitedNodeAdr.ipv6Adr[0] := 0FFX;
				linkLocalSolicitedNodeAdr.ipv6Adr[1] := 2X;
				linkLocalSolicitedNodeAdr.ipv6Adr[11] := 1X;
				linkLocalSolicitedNodeAdr.ipv6Adr[12] := 0FFX;
				linkLocalSolicitedNodeAdr.ipv6Adr[13] := localAdr.ipv6Adr[13];
				linkLocalSolicitedNodeAdr.ipv6Adr[14] := localAdr.ipv6Adr[14];
				linkLocalSolicitedNodeAdr.ipv6Adr[15] := localAdr.ipv6Adr[15];

				IF name # "Loopbackv6" THEN
					(* Duplicate Address Detection *)
					Kernel.SetTimer(duplicateTimer, ShortTimerTimeout);
					sendNeighborSolicitation(SELF, linkMulticastSolicited, linkLocalSolicitedNodeAdr, FALSE);
				END;
				res := IP.Ok;

				(* When this interface a link-local interface is update devList *)
				IF IsLinkLocalAdr(localAdr) THEN
					devListItem := devList;
					WHILE (devListItem # NIL) & (devListItem.device # dev) DO
						devListItem := devListItem.next;
					END;

					devListItem.linkLocalInterface := SELF;
				END;
			ELSE
				(* make nothing *)
			END;
		END SetAdrs;


		(* Receive an IP packet *)
		PROCEDURE IPInput*(dev: Network.LinkDevice; type: LONGINT; buffer: Network.Buffer);
		VAR
			payloadLength: LONGINT;
			nextHeader: LONGINT;
			srcAdr: IP.Adr;
			dstAdr: IP.Adr;
			forwardInt: IP.Interface;
			receiver: IP.Receiver;
			incomingFragment: BOOLEAN;
			forwardBuffer: Network.Buffer;

		BEGIN
			IF DEBUG THEN
				ASSERT(type = EtherTypeIP);
				ASSERT(dev = SELF.dev);
			END;

			incomingFragment := FALSE;
			IF buffer.nextFragment = NIL THEN
				payloadLength := Network.GetNet2(buffer.data, buffer.ofs+4);
				nextHeader := ORD(buffer.data[buffer.ofs+6]);
			ELSE
				nextHeader := ORD(buffer.data[buffer.ofs]);
				payloadLength := buffer.len - MinIPHdrLen;	(* not correct but otherwise fragmented packet are not accepted *)
			END;

			IF ((payloadLength + MinIPHdrLen) <= buffer.len) THEN
				(* payloadLength = 0: Jumbo-Payload *)

				srcAdr := ReadSrcAdr (buffer);
				dstAdr := ReadDestAdr (buffer);
				IF (nextHeader = IPv6FragmentType) & (buffer.nextFragment = NIL) THEN
					(* a fragmented packet try to reassemble it *)
					INC(buffer.ofs, MinIPHdrLen);
					DEC(buffer.len, MinIPHdrLen);
					AddToFragmentList(srcAdr, dstAdr, buffer);
					incomingFragment := TRUE;
				END;

				IF ~IsMulticast(srcAdr) & ~incomingFragment THEN
					IF ~IsMulticast(dstAdr) THEN
						(* unicast *)
						IF (IP.AdrsEqual(dstAdr, localAdr)) THEN
							receiver := IP.receivers[nextHeader];
							IF receiver # NIL THEN
								(* do receiver upcall *)
								buffer.l3ofs := buffer.ofs;

								IF buffer.nextFragment # NIL THEN
									(* adjust offset when a packet is fragmented*)
									INC(buffer.ofs, FragmentHdrLen);
									DEC(buffer.len, FragmentHdrLen);
								ELSE
									INC(buffer.ofs, MinIPHdrLen);
									DEC(buffer.len, MinIPHdrLen);
								END;

								receiver(SELF, nextHeader, srcAdr, dstAdr, buffer);
								Machine.AtomicInc(IP.NIPDelivered);
								(* Exit here w/o returning buffer because it is passed to a receiver *)
								RETURN;
							ELSE
								Machine.AtomicInc(IP.NIPNoReceiver);
							END;
						ELSIF IP.IPForwarding THEN
							(* forward packet *)
							(* look if there is a routing header *)
							IF nextHeader = IPv6RoutingHdrType THEN
								INC(buffer.ofs, MinIPHdrLen);
								DEC(buffer.len, MinIPHdrLen);

								dstAdr := ReadDestAdr (buffer);
							END;

							forwardInt := IP.InterfaceByDstIP(dstAdr);
							IF forwardInt # NIL THEN
								forwardBuffer := buffer;

								WHILE forwardBuffer # NIL DO
									(* only forward packets with hop limit > zero *)
									IF ORD(forwardBuffer.data[7]) > 0 THEN
										(* Decrement hop limit *)
										forwardBuffer.data[7] := CHR(ORD(forwardBuffer.data[7]) - 1);

										forwardInt.DoSend(dstAdr,
														     forwardBuffer.data,
														     forwardBuffer.data,
														     forwardBuffer.data,
														     0,
														     0,
														     forwardBuffer.ofs,
														     forwardBuffer.len);

										Machine.AtomicInc(IP.NIPForwarded);
									ELSE
										sendICMPv6TimeExceeded(SELF, forwardBuffer, srcAdr, ICMPv6CodeHopLimitExc);
									END;

									forwardBuffer := forwardBuffer.nextFragment;
								END;
							ELSE
								Machine.AtomicInc(IP.NIPNotForUs)
							END;
						ELSE
							Machine.AtomicInc(IP.NIPNotForUs);
						END
					ELSIF IsSolicitedNodeAdr(dstAdr) THEN
						receiver := IP.receivers[nextHeader];
						IF receiver # NIL THEN
							(* do receiver upcall *)
							buffer.l3ofs := buffer.ofs;

							IF (buffer.nextFragment # NIL) & (nextHeader = IPv6FragmentType) THEN
								(* adjust offset when a packet is fragmented*)
								INC(buffer.ofs, FragmentHdrLen + MinIPHdrLen);
								DEC(buffer.len, FragmentHdrLen + MinIPHdrLen);
							ELSE
								INC(buffer.ofs, MinIPHdrLen);
								DEC(buffer.len, MinIPHdrLen);
							END;

							receiver(SELF, nextHeader, srcAdr, dstAdr, buffer);
							Machine.AtomicInc(IP.NIPDelivered);
							(* Exit here w/o returning buffer because it is passed to a receiver *)
							RETURN;
						ELSE
							Machine.AtomicInc(IP.NIPNoReceiver);
						END;
					ELSIF ORD(dstAdr.ipv6Adr[15]) = 1 THEN
						(* multicast to node *)
						receiver := IP.receivers[nextHeader];
						IF receiver # NIL THEN
							(* do receiver upcall *)
							buffer.l3ofs := buffer.ofs;

							IF (buffer.nextFragment # NIL) & (nextHeader = IPv6FragmentType) THEN
								(* adjust offset when a packet is fragmented*)
								INC(buffer.ofs, FragmentHdrLen + MinIPHdrLen);
								DEC(buffer.len, FragmentHdrLen + MinIPHdrLen);
							ELSE
								INC(buffer.ofs, MinIPHdrLen);
								DEC(buffer.len, MinIPHdrLen);
							END;

							receiver(SELF, nextHeader, srcAdr, dstAdr, buffer);
							Machine.AtomicInc(IP.NIPDelivered);
							(* Exit here w/o returning buffer because it is passed to a receiver *)
							RETURN;
						ELSE
							Machine.AtomicInc(IP.NIPNoReceiver);
						END;
					ELSIF IsMulticast(dstAdr) & (isRouter) & (ORD(dstAdr.ipv6Adr[15]) = 2) THEN
						(* multicast packet for router; to capture these packets IPForwarding must be
						    turned on *)
						receiver := IP.receivers[nextHeader];
						IF receiver # NIL THEN
							(* do receiver upcall *)
							buffer.l3ofs := buffer.ofs;

							IF (buffer.nextFragment # NIL) & (nextHeader = IPv6FragmentType) THEN
								(* adjust offset when a packet is fragmented*)
								INC(buffer.ofs, FragmentHdrLen + MinIPHdrLen);
								DEC(buffer.len, FragmentHdrLen + MinIPHdrLen);
							ELSE
								INC(buffer.ofs, MinIPHdrLen);
								DEC(buffer.len, MinIPHdrLen);
							END;

							receiver(SELF, nextHeader, srcAdr, dstAdr, buffer);
							Machine.AtomicInc(IP.NIPDelivered);
							(* Exit here w/o returning buffer because it is passed to a receiver *)
							RETURN;
						ELSE
							Machine.AtomicInc(IP.NIPNoReceiver);
						END;
					ELSE
						Machine.AtomicInc(IP.NIPNotForUs)
					END;
				ELSE
					IF ~incomingFragment THEN
						Machine.AtomicInc(IP.NIPSrcIsBroadcast)
					END;
				END;
			ELSE
				Machine.AtomicInc(IP.NIPBadLength)
			END;
			(* Exit and return buffer here because it is no longer used *)
			IF ~incomingFragment THEN
				Network.ReturnBuffer(buffer);
			END;
		END IPInput;


		(** Send an IP packet on this interface. Send it directly without lookup of destination cache, etc... *)
		PROCEDURE SendDirectly*(linkDst: Network.LinkAdr;
								       nextHeader: LONGINT;
								       destAdr: IP.Adr;
								        VAR l4hdr, data: ARRAY OF CHAR;
								        h4len, dofs, dlen, hopLimit: LONGINT);
		VAR
			l3hdr: ARRAY MaxIPHdrLen OF CHAR;
			i: LONGINT;

		BEGIN
			IF DEBUG THEN
				ASSERT (destAdr.usedProtocol =  6, 2345 );
			END;

			IF closed THEN
				RETURN;
			END; (* just in case of concurrent Send/Close *)

			(* set IP header *)
			l3hdr[0] := CHR(IP.IPv6*10H); (* IP version and first part of traffic class *)
			l3hdr[1] := 0X; (* second part of traffic class and first part of flow label *)
			Network.Put2(l3hdr, 2, 0); (* second part of flow label *)
			Network.PutNet2(l3hdr, 4, h4len+dlen); (* Payload length *)
			l3hdr[6] := CHR(nextHeader); (* next header *)
			l3hdr[7] := CHR(hopLimit); (* Hop limit *)
			(* set local address *)
			FOR i := 0 TO 15 DO
				l3hdr[i+8] := localAdr.ipv6Adr[i];
			END;
			(* set foreign address *)
			FOR i := 0 TO 15 DO
				l3hdr[i+24] := destAdr.ipv6Adr[i];
			END;

			(* perform sending *)
			DoSendDirectly(linkDst, destAdr, l3hdr, l4hdr, data, MinIPHdrLen, h4len, dofs, dlen);
		END SendDirectly;


		(* Internal procedure to perform the rest of the send operation. Without destination cache lookup etc...,
		    fragmentation is not supported! *)
		PROCEDURE DoSendDirectly*(linkDst: Network.LinkAdr;
									    destAdr: IP.Adr;
									     VAR l3hdr, l4hdr, data: ARRAY OF CHAR;
									     h3len, h4len, dofs, dlen: LONGINT) ;
		BEGIN
			ASSERT (destAdr.usedProtocol = 6, 2345);
			IF h3len+h4len+dlen <= dev.mtu THEN
				IF dev.type = Network.TypeEthernet THEN
					IF IsNodeLocalAdr(destAdr) THEN
						(* send local loopback. If destAdr is a node local adr packet sould only be received from
       					     the same interfaces as it was sent *)
       					Machine.AtomicInc(IP.NIPSentLocalLoopback);
						dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen, TRUE);
					ELSE
						dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen, FALSE);
					END;
				ELSE
					(* Network.TypePointToPoint *)
					Machine.AtomicInc(IP.NIPSentPointToPoint);
					dev.Send(linkDst,
							   EtherTypeIP,
							   l3hdr,
							   l4hdr,
							   data,
							   h3len,
							   h4len,
							   dofs,
							   dlen,
							   IP.AdrsEqual (destAdr, localAdr));
				END;
			END;
		END DoSendDirectly;


		(** Send an IP packet on this interface. *)
		PROCEDURE Send*(nextHeader: LONGINT; destAdr: IP.Adr; CONST l4hdr, data: ARRAY OF CHAR; h4len, dofs, dlen, hopLimit: LONGINT);
		VAR
			l3hdr: ARRAY MaxIPHdrLen OF CHAR;
			i: LONGINT;

		BEGIN
			IF DEBUG THEN
				ASSERT (destAdr.usedProtocol =  6, 2345 );
			END;

			IF closed THEN RETURN END; (* just in case of concurrent Send/Close *)

			(* set IP header *)
			l3hdr[0] := CHR(IP.IPv6*10H); (* IP version and first part of traffic class *)
			l3hdr[1] := 0X; (* second part of traffic class and first part of flow label *)
			Network.Put2(l3hdr, 2, 0); (* second part of flow label *)
			Network.PutNet2(l3hdr, 4, h4len+dlen); (* Payload length *)
			l3hdr[6] := CHR(nextHeader); (* next header *)
			l3hdr[7] := CHR(hopLimit); (* Hop limit *)
			(* set local address *)
			FOR i := 0 TO 15 DO
				l3hdr[i+8] := localAdr.ipv6Adr[i];
			END;
			(* set foreign address *)
			FOR i := 0 TO 15 DO
				l3hdr[i+24] := destAdr.ipv6Adr[i];
			END;

			(* perform sending *)
			DoSend(destAdr, l3hdr, l4hdr, data, MinIPHdrLen, h4len, dofs, dlen);
		END Send;


		(* Internal procedure to perform the rest of the send operation. Used by "Send" and for IP forwarding. *)
		PROCEDURE DoSend*(destAdr: IP.Adr; CONST l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT) ;
		VAR
			linkDst: Network.LinkAdr;
			nextHop: IP.Adr;
			pmtu: LONGINT;
			toFragment: BOOLEAN;

		BEGIN
			ASSERT (destAdr.usedProtocol = 6, 2345);

			toFragment := FALSE;

			(* Get Path Maximum transmission unit *)
			pmtu := destCache.GetPMTU(destAdr);
			pmtu := Strings.Min(pmtu, linkMTU);
			pmtu := Strings.Min(pmtu, dev.mtu);

			IF h3len+h4len+dlen > pmtu THEN
				(* fragment packet *)
				toFragment := TRUE;
			END;

			IF dev.type = Network.TypeEthernet THEN
				IF IsNodeLocalAdr(destAdr) OR IsLinkLocalMulticastAdr(destAdr) OR IP.AdrsEqual(destAdr, localAdr) THEN
					(* send local loopback. If destAdr is a node local adr packet sould only be received from
					    the same interfaces as it was sent *)
					Machine.AtomicInc(IP.NIPSentLocalLoopback);
					dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen, TRUE);
				ELSE
					(* check destination cache for next-hop *)
					nextHop := destCache.GetNextHop(destAdr);

					(* Neighbor cache lookup for link-layer address of next hop *)
					IF ~neighborCache.GetLinkLayerAdr(nextHop, linkDst) THEN

						(* no link-layer address found initiate address resolution packet will be queued*)
						neighborCache.AddressResolution(nextHop, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen);
					ELSE

						IF ~toFragment THEN
							dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen, FALSE);
						ELSE
							DoFragAndSend(pmtu, linkDst, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen);
						END;
					END;
				END;
			ELSE
				(* Network.TypePointToPoint *)
				Machine.AtomicInc(IP.NIPSentPointToPoint);
				dev.Send(linkDst,
						   EtherTypeIP,
						   l3hdr,
						   l4hdr,
						   data,
						   h3len,
						   h4len,
						   dofs,
						   dlen,
						   IP.AdrsEqual (destAdr, localAdr));
			END;
		END DoSend;


		(** Fragment packets and send them *)
		PROCEDURE DoFragAndSend(pmtu: LONGINT; linkDst: Network.LinkAdr; l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT);
		VAR
			maxDataLen: LONGINT;
			fragmentOffset: LONGINT;
			oldNextHeader: LONGINT;
			l4hdrFragment: POINTER TO ARRAY OF CHAR;	(* fragment header *)
			dataFragment: POINTER TO ARRAY OF CHAR;	(* fragment data *)
			fragmentHdrSet: SET;
			fragID: LONGINT;
			i: LONGINT;

		BEGIN
			fragID := GetFragmentID();

			(* do fragmentation *)
			maxDataLen := pmtu - MinIPHdrLen - FragmentHdrLen;

			DEC(maxDataLen, maxDataLen MOD 8); 	(* 64-bit boundary *)
			fragmentOffset := 0;

			(* change IP header *)
			oldNextHeader := ORD(l3hdr[6]); (* next header *)
			l3hdr[6] := CHR(IPv6FragmentType);

			(* build fragment header *)
			NEW(l4hdrFragment, FragmentHdrLen);

			fragmentHdrSet := {};
			fragmentHdrSet := fragmentHdrSet + {0};
			Network.PutNet4(l4hdrFragment^, 0, SYSTEM.VAL(LONGINT, fragmentHdrSet));
			l4hdrFragment^[0] := CHR(oldNextHeader);
			Network.PutNet4(l4hdrFragment^, 4, fragID);

			(* fragment data *)
			NEW(dataFragment, maxDataLen);
			FOR i := 0 TO h4len - 1 DO
				dataFragment^[i] := l4hdr[i];
			END;

			FOR i := h4len TO maxDataLen - 1 DO
				dataFragment^[i] := data[i-h4len + dofs];
			END;

			INC(fragmentOffset, maxDataLen - h4len + dofs);

			(* adjust payload length *)
			Network.PutNet2(l3hdr, 4, maxDataLen + FragmentHdrLen);

			(* first packet *)
			dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdrFragment^, dataFragment^, h3len, FragmentHdrLen, 0, maxDataLen, FALSE);

			WHILE fragmentOffset < h4len + dlen DO
				IF fragmentOffset + maxDataLen > h4len + dlen THEN
					(* last fragment *)
					fragmentHdrSet := SYSTEM.VAL(SET, LSH((fragmentOffset - dofs + h4len) DIV 8, 3));
					fragmentHdrSet := fragmentHdrSet - {0, 1, 2};
					Network.PutNet4(l4hdrFragment^, 0, SYSTEM.VAL(LONGINT, fragmentHdrSet));
					l4hdrFragment^[0] := CHR(oldNextHeader);
					l4hdrFragment^[1] := 0X;
					Network.PutNet4(l4hdrFragment^, 4, fragID);

					(* fragment data *)
					FOR i := 0 TO dlen - fragmentOffset - 1 DO
						dataFragment^[i] := data[i + fragmentOffset];
					END;

					(* adjust payload length *)
					Network.PutNet2(l3hdr, 4, dlen - fragmentOffset + FragmentHdrLen);

					dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdrFragment^, dataFragment^, h3len, FragmentHdrLen, 0, dlen - fragmentOffset, FALSE);

					INC(fragmentOffset, maxDataLen);

				ELSE
					(* fragment in the middle *)
					fragmentHdrSet := SYSTEM.VAL(SET, LSH((fragmentOffset - dofs + h4len) DIV 8, 3));
					fragmentHdrSet := fragmentHdrSet + {0} - {1,2};
					Network.PutNet4(l4hdrFragment^, 0, SYSTEM.VAL(LONGINT, fragmentHdrSet));
					l4hdrFragment^[0] := CHR(oldNextHeader);
					l4hdrFragment^[1] := 0X;
					Network.PutNet4(l4hdrFragment^, 4, fragID);

					(* fragment data *)
					FOR i := 0 TO maxDataLen - 1 DO
						dataFragment^[i] := data[i + fragmentOffset];
					END;
					dev.Send(linkDst, EtherTypeIP, l3hdr, l4hdrFragment^, dataFragment^, h3len, FragmentHdrLen, 0, maxDataLen, FALSE);

					INC(fragmentOffset, maxDataLen);
				END;
			END;
		END DoFragAndSend;


		(** Enumerate all ARP table entries. In IPv6 Enumerate the Neighbors*)
		PROCEDURE ARPEnumerate*(handle: IP.ARPHandler);
			(* This procedure has to be inherited but is ignored because in IPv6 ARP is not used *)
		END ARPEnumerate;


		(** Performs a check for Network if a packet is accepted by this interface *)
		PROCEDURE IsPacketAccepted(buffer: Network.Buffer): BOOLEAN;
		VAR
			i: LONGINT;
			isAccepted: BOOLEAN;

		BEGIN
			isAccepted := TRUE;

			IF ~IP.IsNilAdr(localAdr) THEN
				(* When interface is not yet configurated take all packets *)

				(* If it is a link-local interface take link-local multicast packets *)
				IF ~((IsLinkLocalAdr(localAdr)) & (buffer.data[24] = 0FFX)) THEN
					FOR i := 0 TO 15 DO
						IF buffer.data[i+24] # localAdr.ipv6Adr[i] THEN
							isAccepted := FALSE;
						END;
					END;
				END;
			END;
			RETURN isAccepted;
		END IsPacketAccepted;


		(** Checks if an IPv6 address is a multicast address in IPv6 there are no broadcasts *)
		PROCEDURE IsBroadcast*(adr: IP.Adr) : BOOLEAN;
		BEGIN
			RETURN IsMulticast (adr);
		END IsBroadcast;


		(** Check if adr is a local multicast address *)
		PROCEDURE IsMulticast*(adr: IP.Adr) : BOOLEAN;
		BEGIN
			IF adr.ipv6Adr[0] = 0FFX THEN
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END IsMulticast;


		(* Checks if adr is a solicited node address *)
		PROCEDURE IsSolicitedNodeAdr(adr: IP.Adr): BOOLEAN;
		VAR
			isSolicitedNode: BOOLEAN;

		BEGIN
			isSolicitedNode := TRUE;

			IF ~AdrsPartEqual(linkLocalMulticastNodeAdr, adr, 0, 1) THEN
				isSolicitedNode := FALSE;
			END;
			IF ~AdrsPartEqual(IP.NilAdr, adr, 2, 10) THEN
				isSolicitedNode := FALSE;
			END;
			IF ~((adr.ipv6Adr[11] = 1X) & (adr.ipv6Adr[12] = 0FFX)) THEN
				isSolicitedNode := FALSE;
			END;
			IF ~AdrsPartEqual(localAdr, adr, 13, 15) THEN
				isSolicitedNode := FALSE
			END;
			RETURN isSolicitedNode;
		END IsSolicitedNodeAdr;


		(* Check if adr is a node-local adr: localAdr, nodeLocalMulticastAdr *)
		PROCEDURE IsNodeLocalAdr (adr: IP.Adr): BOOLEAN;
		VAR
			isNodeLocal: BOOLEAN;

		BEGIN
			isNodeLocal := FALSE;

			IF (IP.AdrsEqual(adr, localAdr)) OR (IP.AdrsEqual(adr, nodeLocalMulticastNodeAdr)) THEN
				isNodeLocal := TRUE;
			END;
			RETURN isNodeLocal;
		END IsNodeLocalAdr;


		(* Reads the source address of a IP packet buffer *)
		PROCEDURE ReadSrcAdr* (buffer: Network.Buffer): IP.Adr;
		VAR
			i: LONGINT;
			retAdr: IP.Adr;

		BEGIN
			retAdr.usedProtocol := IP.IPv6;
			FOR i := 0 TO 15 DO
				retAdr.ipv6Adr[i] := buffer.data[i+8];
			END;
			RETURN retAdr;
		END ReadSrcAdr;


		(* Reads the destination address of a IP packet buffer *)
		PROCEDURE ReadDestAdr* (buffer: Network.Buffer):IP. Adr;
		VAR
			i: LONGINT;
			retAdr: IP.Adr;

		BEGIN
			retAdr.usedProtocol := IP.IPv6;
			FOR i := 0 TO 15 DO
				retAdr.ipv6Adr[i] := buffer.data[i+24];
			END;
			RETURN retAdr;
		END ReadDestAdr;


		(* writes the interface ID to a IPv6 address (last 64 bits) *)
		PROCEDURE SetInterfaceID*(VAR ip: IP.Adr);
		VAR
			bitSet: SET;

		BEGIN
			(* IEEE 802 Address to IPv6 Interface Identifier:
				cccccc00 cccccccc cccccccc   xxxxxxxx xxxxxxxx xxxxxxxx
				  IEEE 802 Address

			   ccccccc00 cccccccc cccccccc 11111111 11111110 xxxxxxxx xxxxxxxx xxxxxxxx
			        EUI-64 address

			   cccccc10 cccccccc cccccccc 11111111 11111110 xxxxxxxx xxxxxxxx xxxxxxxx
			*)

			ip.usedProtocol := IP.IPv6;

			ip.ipv6Adr[13] := dev.local[3];
			ip.ipv6Adr[14] := dev.local[4];
			ip.ipv6Adr[15] := dev.local[5];

			ip.ipv6Adr[11] := 0FFX;
			ip.ipv6Adr[12] := 0FEX;

			ip.ipv6Adr[8] := dev.local[0];
			ip.ipv6Adr[9] := dev.local[1];
			ip.ipv6Adr[10] := dev.local[2];

			bitSet := SYSTEM.VAL(SET, ip.ipv6Adr[8]);
			(* toggle second bit *)
			IF 1 IN bitSet THEN
				bitSet := bitSet - {1};
			ELSE
				bitSet := bitSet + {1};
			END;
			ip.ipv6Adr[8] := SYSTEM.VAL(CHAR, bitSet);
		END SetInterfaceID;


		(** Creates a pseudo-header for checksum calculation (TCP/UDP) and returns the length of this header *)
		PROCEDURE WritePseudoHeader*(VAR pseudoHdr: ARRAY OF CHAR;
										     src, dst: IP.Adr;
										     nextHeader, pktLengthUpperLayer: LONGINT): LONGINT;
		VAR
			i: LONGINT;
			tmpAdr: ARRAY 4 OF LONGINT;

		BEGIN
			(* UDP/TCP Pseudo-header (for checksum calculation)

			00	128	source address
			16	128	destination address
			32	32	Upper Layer Packet Length
			36	24	zero = 0
			39	8	Next header *)

			IF DEBUG THEN
				ASSERT (IP.IsNilAdr(src) OR (src.usedProtocol = IP.IPv6));
				ASSERT (IP.IsNilAdr(dst) OR (dst.usedProtocol = IP.IPv6));
			END;

			(* cast src adr to LONGINT array *)
			FOR i := 0 TO 3 DO
				tmpAdr[i] := ORD(src.ipv6Adr[i*4 + 0]);
				tmpAdr[i] := (tmpAdr[i] * 256) + ORD(src.ipv6Adr[i*4 + 1]);
				tmpAdr[i] := (tmpAdr[i] * 256) + ORD(src.ipv6Adr[i*4 + 2]);
				tmpAdr[i] := (tmpAdr[i] * 256) + ORD(src.ipv6Adr[i*4 + 3]);
				Network.PutNet4(pseudoHdr, i*4, tmpAdr[i]); (* local IP address *)
			END;

			(* cast dst adr to LONGINT array *)
			FOR i := 0 TO 3 DO
				tmpAdr[i] := 0;
				tmpAdr[i] := ORD(dst.ipv6Adr[i*4 + 0]);
				tmpAdr[i] := (tmpAdr[i] * 256) + ORD(dst.ipv6Adr[i*4 + 1]);
				tmpAdr[i] := (tmpAdr[i] * 256) + ORD(dst.ipv6Adr[i*4 + 2]);
				tmpAdr[i] := (tmpAdr[i] * 256) + ORD(dst.ipv6Adr[i*4 + 3]);
				Network.PutNet4(pseudoHdr, (i*4)+16, tmpAdr[i]); (* foreign IP address *)
			END;

			(* Upper Layer Packet Length *)
			Network.PutNet4(pseudoHdr, 32, pktLengthUpperLayer);
			(* Zero and next header *)
			Network.PutNet4(pseudoHdr, 36, nextHeader);
			RETURN 40; (* IPv6 pseudo header length *)
		END WritePseudoHeader;


		(* Received a neighbor solicitation message *)
		PROCEDURE ReceiveNeighborSolicitation*(srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
		VAR
			target: IP.Adr;
			i: LONGINT;
			int: IP.Interface;

		BEGIN
			target.usedProtocol := IP.IPv6;
			FOR i := 0 TO 15 DO
				target.ipv6Adr[i] := buffer.data[buffer.ofs + 4 + i];
			END;

			int := IP.InterfaceByDstIP(target);

			IF (int # NIL) & (IP.AdrsEqual(int.localAdr, target)) THEN
				(* send a soliciated neighbor advertisement message *)
				sendNeighborAdvertisement(int(Interface), buffer.src, srcAdr, TRUE);
			END;
			Network.ReturnBuffer(buffer);
		END ReceiveNeighborSolicitation;


		(* Received a neighbor advertisement message *)
		PROCEDURE ReceiveNeighborAdvertisement* (srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
		VAR
			neighborEntry: NeighborCacheEntry;
			flags: SET;
			routerFlag: BOOLEAN;
			solicitedFlag: BOOLEAN;
			overrideFlag: BOOLEAN;
			linkAdrsEqual: BOOLEAN;	(* Are both link-addresses equal (in neighbor advertisement and cache *)
			hasTargetLinkOption: BOOLEAN;
			targetLinkAdr: Network.LinkAdr;
			newRouter: IP.Adr;

		BEGIN
			(* Check for duplicated address *)
			IF IP.AdrsEqual(srcAdr, localAdr) THEN
				KernelLog.Ln; KernelLog.String("Duplicate address detected. Shuting down interface: ");
				KernelLog.String(dev.name);
				KernelLog.Ln;

				Close;
			ELSE
				neighborEntry := neighborCache.Get(srcAdr);

				IF neighborEntry = NIL THEN
					(* make a new entry. According to RFC 2461 entry should not be added. But because of V6InterfaceByDstIP
					    unsolicited neigbor advertisements have to be accepted *)
					neighborCache.Add(srcAdr);
					neighborEntry := neighborCache.Get(srcAdr);
				END;

				(* read flags *)
				flags := SYSTEM.VAL(SET, Network.GetNet4(buffer.data, buffer.ofs));
				routerFlag := 31 IN flags;
				solicitedFlag := 30 IN flags;
				overrideFlag := 29 IN flags;

				IF neighborEntry.reachability = Incomplete THEN
					(* save link address *)
					neighborEntry.linkAdr := buffer.src;

					IF solicitedFlag THEN
						neighborEntry.reachability := Reachable;
						Kernel.SetTimer(neighborEntry.lastConfirmation, ReachableTime);
					ELSE
						neighborEntry.reachability := Stale;
					END;

					neighborEntry.isRouter := routerFlag;

					neighborCache.SendQueuedPackets(neighborEntry);
				ELSE
					(* reachability is not incomplete *)
					IF (buffer.len - buffer.ofs) > (MinIPHdrLen + IP.ICMPHdrLen + NeighborHdrLen) THEN
						(* Option is available *)
						IF (buffer.data[buffer.ofs + NeighborHdrLen] = 2X) & (buffer.data[buffer.ofs + NeighborHdrLen + 1] = 1X) THEN
							(* Target link-layer address option *)
							hasTargetLinkOption := TRUE;

							buffer.ofs := buffer.ofs + NeighborHdrLen;
							icmpLinkLayerAdrOption(buffer, targetLinkAdr);

							linkAdrsEqual := Network.LinkAdrsEqual(targetLinkAdr, neighborEntry.linkAdr);
						ELSE
							hasTargetLinkOption := FALSE;
							linkAdrsEqual := FALSE;
						END;
					ELSE
						hasTargetLinkOption := FALSE;
						linkAdrsEqual := FALSE;
					END;

					IF (~overrideFlag) & (~linkAdrsEqual) & (neighborEntry.reachability = Reachable) THEN
						neighborEntry.reachability := Stale;
					END;

					IF overrideFlag OR (~overrideFlag & linkAdrsEqual) OR (~hasTargetLinkOption) THEN
						(* Update neighbor cache *)
						IF hasTargetLinkOption THEN
							neighborEntry.linkAdr := targetLinkAdr
						END;

						IF solicitedFlag THEN
							neighborEntry.reachability := Reachable;
							Kernel.SetTimer(neighborEntry.lastConfirmation, ReachableTime);
						ELSIF hasTargetLinkOption THEN
							neighborEntry.reachability := Stale;
						END;

						IF (neighborEntry.isRouter) & ~routerFlag THEN
							(* changed from a router to normal host *)
							routers.Remove(neighborEntry.neighborIP);
							newRouter := routers.GetRouter();
							destCache.ChangeDests(neighborEntry.neighborIP, newRouter);
						END;
						neighborEntry.isRouter := routerFlag;
					END;
				END;
			END;
			Network.ReturnBuffer(buffer);
		END ReceiveNeighborAdvertisement;


		(* initiate a router solicitation *)
		PROCEDURE RouterSolicitation*;
		BEGIN
			sendRouterSolicitation(SELF);
			INC(routerSolCount);
		END RouterSolicitation;


		(* Receive a Router Advertisement message *)
		PROCEDURE ReceiveRouterAdvertisement*(srcAdr: IP.Adr; buffer: Network.Buffer);
		VAR
			int: IP.Interface;
			intv6: Interface;
			intName: IP.Name;
			newLocalAdr: IP.Adr;
			hopLimit: LONGINT;
			flags: SET;
			managedFlag: BOOLEAN;
			otherStatefulFlag: BOOLEAN;
			homeAgentFlag: BOOLEAN;
			routerLifetime: LONGINT;
			reachableTime: LONGINT;
			retransTimer: LONGINT;
			linkAdr: Network.LinkAdr;
			mtu: LONGINT;
			onLink: ARRAY MaxPrefixOptions OF BOOLEAN;
			autonomous: ARRAY MaxPrefixOptions OF BOOLEAN;
			routerAddress: ARRAY MaxPrefixOptions OF BOOLEAN;
			sitePrefix: ARRAY MaxPrefixOptions OF BOOLEAN;
			validLifetime: ARRAY MaxPrefixOptions OF LONGINT;
			preferredLifetime: ARRAY MaxPrefixOptions OF LONGINT;
			sitePrefixLength: ARRAY MaxPrefixOptions OF LONGINT;
			localPrefix: ARRAY MaxPrefixOptions OF IP.Adr;
			router: RoutersEntry;
			hasSrcLinkLayerOption: BOOLEAN;
			hasMTUOption: BOOLEAN;
			prefixItem: PrefixesEntry;
			nbrOfPrefixOpt: LONGINT;
			i: LONGINT;
			res: LONGINT;
			tmpStr: ARRAY 8 OF CHAR;


			(* Parse options of a router advertisement message return FALSE on error *)
			PROCEDURE ParseRouterAdvOptions(): BOOLEAN;
			BEGIN
				WHILE buffer.len > 0 DO
					(* Options are available *)
					CASE ORD(buffer.data[buffer.ofs]) OF
						IP.ICMPSrcLLAdrOptionType:
							(* Check length field *)
							IF ORD(buffer.data[buffer.ofs + 1]) <= 0 THEN
								RETURN FALSE;
							END;
							hasSrcLinkLayerOption := TRUE;
							icmpLinkLayerAdrOption(buffer, linkAdr);

						|IP.ICMPPrefixInfoOptionType:
							(* Check length field *)
							IF ORD(buffer.data[buffer.ofs + 1]) <= 0 THEN
								RETURN FALSE;
							END;
							icmpPrefixInfoOption(buffer,
												  onLink[nbrOfPrefixOpt],
												  autonomous[nbrOfPrefixOpt],
												  routerAddress[nbrOfPrefixOpt],
												  sitePrefix[nbrOfPrefixOpt],
												  validLifetime[nbrOfPrefixOpt],
												  preferredLifetime[nbrOfPrefixOpt],
												  sitePrefixLength[nbrOfPrefixOpt],
												  localPrefix[nbrOfPrefixOpt]);
							INC(nbrOfPrefixOpt);

						|IP.ICMPMTUOptionType:
							(* Check length field *)
							IF ORD(buffer.data[buffer.ofs + 1]) <= 0 THEN
								RETURN FALSE;
							END;
							hasMTUOption := TRUE;
							icmpMTUOption(buffer, mtu);
							mtu := Strings.Min(mtu, linkMTU);
							mtu := Strings.Min(mtu, dev.mtu);

						|IP.ICMPAdvIntOptionType:
							(* Check length field *)
							IF ORD(buffer.data[buffer.ofs + 1]) <= 0 THEN
								RETURN FALSE;
							END;
							icmpAdvIntervalOption(buffer);

						|IP.ICMPHomeAgOptionType:
							(* Check length field *)
							IF ORD(buffer.data[buffer.ofs + 1]) <= 0 THEN
								RETURN FALSE;
							END;
							icmpHomeAgentInfoOption(buffer);

						|IP.ICMPRouteOption:
							(* Check length field *)
							IF ORD(buffer.data[buffer.ofs + 1]) <= 0 THEN
								RETURN FALSE;
							END;
							icmpRouteInfoOption(buffer);

					ELSE
						(* packet is not well-formed *)
						IF DEBUG THEN
							ASSERT(TRUE);
						END;
						RETURN FALSE;
					END;
				END;
				RETURN TRUE; (* no error occured *)
			END ParseRouterAdvOptions;


			(* create IPv6-interfaces if necessary *)
			PROCEDURE createInterfaces;
			VAR
				i: LONGINT;
				currentPrefix: LONGINT;

			BEGIN
				(* autoconfiguration of interfaces *)
				IF autoconfigurated THEN
					IF createStatelessInterface THEN
						(* FOR i := 0 TO (nbrOfPrefixOpt - 1) DO if this for loop is used programm crashes *)
						currentPrefix := 0;
						WHILE currentPrefix < nbrOfPrefixOpt DO
							IF autonomous[currentPrefix] THEN
								Strings.IntToStr(currentPrefix, tmpStr);
								Strings.Concat(V6RouterIntName, tmpStr, intName);
								Strings.Concat(intName , dev.name, intName);
								NEW(intv6, intName, dev, res);
								int := intv6;

								IF res = IP.Ok THEN
									int(Interface).autoconfigurated := TRUE;
									newLocalAdr := localPrefix[currentPrefix];
									newLocalAdr.data := 0;
									int(Interface).SetInterfaceID(newLocalAdr);

									int.SetAdrs(newLocalAdr, localPrefix[currentPrefix], IP.NilAdr, res);
									IF res = IP.Ok THEN
										KernelLog.String("IPv6: Add interface for LinkDevice '"); KernelLog.String(dev.name);
										KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
										IP.OutInterface(int);

										int(Interface).createStatelessInterface := FALSE;

										(* set available DNS *)
										FOR i := 0 TO DNScount - 1 DO
											int.DNSAdd(DNS[i]);
										END;

										(* use the same caches for interfaces on the same device *)
										int(Interface).routers := routers;
										int(Interface).prefixes := prefixes;
										int(Interface).neighborCache := neighborCache;
										int(Interface).destCache := destCache;
									END;
								END;
							END;
							INC(currentPrefix);
						END;
					END;

					IF createStatefulInterface THEN

(*						(* create new interface on which asks a DHCPv6 *)
						Strings.Concat(V6DHCPIntName , dev.name, intName);
						NEW (intv6, intName, dev, res);
						IF res = IP.Ok THEN
							(* configure DHCP interface *)
						END;
*)					END;
				END;
			END createInterfaces;


		BEGIN
			hasSrcLinkLayerOption := FALSE;
			hasMTUOption := FALSE;
			nbrOfPrefixOpt := 0;

			(* Checks if a router advertisement message is valid *)
			(* Accept only link-local packets *)
			IF ~AdrsPartEqual(srcAdr, linkLocalPrefix, 0, (linkLocalPrefix.data DIV 8) - 1 (* number of bytes *)) THEN
				Network.ReturnBuffer(buffer);
				RETURN;
			END;

			(* Hop limit = 255 *)
			IF buffer.data[7] # 0FFX THEN
				RETURN
			END;

			(* ICMP Code field = 0 *)
			IF buffer.data[buffer.ofs - 3] # 0X THEN
				RETURN;
			END;
			(* read packet contents *)
			hopLimit := ORD(buffer.data[buffer.ofs]);
			(* read flags *)
			flags := SYSTEM.VAL(SET, Network.GetNet4(buffer.data, buffer.ofs + 1));
			managedFlag := 31 IN flags;
			otherStatefulFlag := 30 IN flags;
			homeAgentFlag := 29 IN flags;

			routerLifetime := Network.GetNet2(buffer.data, buffer.ofs + 2);
			reachableTime := SYSTEM.VAL(LONGINT, Network.GetNet4(buffer.data, buffer.ofs + 4));
			retransTimer := SYSTEM.VAL(LONGINT, Network.GetNet4(buffer.data, buffer.ofs + 8));

			INC(buffer.ofs, RouterAdvHdrLen);
			DEC(buffer.len, RouterAdvHdrLen);

			(* Parse available options *)
			IF ~ ParseRouterAdvOptions() THEN
				Network.ReturnBuffer(buffer);
				RETURN;
			END;

			(* Update default router list *)
			router := routers.Get(srcAdr);
			IF (router = NIL) & (routerLifetime # 0) THEN
				(* Add a new default router *)
				router := routers.Add(srcAdr, linkAdr, routerLifetime);
			END;

			Kernel.SetTimer(router.routerLifetime, routerLifetime * 1000);
			IF routerLifetime # 0 THEN
				IF hopLimit # 0 THEN
					curHopLimit := hopLimit;
				END;
			ELSE
				(* update destination cache for destinations using this router *)
				router.router.reachability := Probe;
				destCache.ChangeDests(srcAdr, routers.GetRouter());
			END;

			IF hasSrcLinkLayerOption & (routerLifetime # 0) THEN
				IF router.router.linkAdr # linkAdr THEN
					router.router.reachability := Stale;
					router.router.linkAdr := linkAdr;
				END;
			END;

			IF hasMTUOption & (mtu >= MinIPHdrLen)THEN
				linkMTU := mtu;
			END;

			router.router.isRouter := TRUE;
			(* go through all prefix options and update them *)
			FOR i := 0 TO nbrOfPrefixOpt - 1 DO
				IF onLink[i] THEN
					prefixItem := prefixes.Get(localPrefix[i]);

					IF prefixItem = NIL THEN
						IF validLifetime[i] # 0 THEN
							prefixes.Add(localPrefix[i], validLifetime[i]);
						END;
					ELSE
						IF validLifetime[i] = 0 THEN
							(* timeout prefix *)
							prefixes.Remove(localPrefix[i]);
						ELSE
							Kernel.SetTimer(prefixItem.lifetime, validLifetime[i] * 1000); (* milliseconds *)
						END;
					END;
				END;
			END;

			IF managedFlag OR otherStatefulFlag THEN
				createStatefulInterface := TRUE;
			END;
			(* create necessary IPv6-interfaces *)
			createInterfaces;
			Network.ReturnBuffer(buffer);
		END ReceiveRouterAdvertisement;


		(** Receive a router solicitation message *)
		PROCEDURE ReceiveRouterSolicitation*;
		BEGIN
			IF isRouter THEN
				(* send a solicited router advertisement *)
				sendRouterAdvertisement(SELF, linkLocalMulticastNodeAdr, linkMulticastAllNodesAdr, routerConfig);
			END;
		END ReceiveRouterSolicitation;


		(* Receive a packet too big ICMP message *)
		PROCEDURE ReceivePacketTooBig*(from: IP.Adr; buffer: Network.Buffer);
		VAR
			newPMTU: LONGINT;
		BEGIN
			(* ICMP Code field = 0 *)
			IF buffer.data[buffer.ofs - 3] = 0X THEN
				newPMTU := Network.GetNet4(buffer.data, 0);

				destCache.ChangePMTU(from, newPMTU);
			END;
			Network.ReturnBuffer(buffer);
		END ReceivePacketTooBig;


		(** Configurate this interface as a router *)
		PROCEDURE ConfigAsRouter*(newRouterConfig: RouterConfig);
		VAR
			prefixConfigItem: PrefixConfig;
			intv6: Interface;
			count: LONGINT;
			tmpStr: ARRAY 8 OF CHAR;
			newLocalAdr: IP.Adr;
			res: LONGINT;
			i: LONGINT;

		BEGIN
			isRouter := TRUE;

			routerConfig := newRouterConfig;
			routerConfig.next := NIL;

			KernelLog.String("Interface "); KernelLog.String(name); KernelLog.String(" is configured as a IPv6 router"); KernelLog.Ln;

			(* create an interface according to the router configuration *)
			count := 0;
			prefixConfigItem := newRouterConfig.Prefixes;
			WHILE prefixConfigItem # NIL DO
				IF prefixConfigItem.Autonomous THEN
					Strings.IntToStr(count, tmpStr);
					Strings.Concat(V6OwnRouterIntName, tmpStr, intName);
					Strings.Concat(intName, dev.name, intName);
					NEW(intv6, intName, dev, res);
					IF res = IP.Ok THEN
						intv6.autoconfigurated := TRUE;
						newLocalAdr := prefixConfigItem.Prefix;
						newLocalAdr.data := 0;
						intv6.SetInterfaceID(newLocalAdr);

						intv6.SetAdrs(newLocalAdr, prefixConfigItem.Prefix, IP.NilAdr, res);
						IF res = IP.Ok THEN
							KernelLog.String("IPv6: Add interface for LinkDevice '"); KernelLog.String(dev.name);
							KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
							IP.OutInterface(intv6);

							intv6.createStatelessInterface := FALSE;

							(* set available DNS *)
							FOR i := 0 TO DNScount - 1 DO
								intv6.DNSAdd(DNS[i]);
							END;

							(* use the same caches for interfaces on the same device *)
							intv6.routers := routers;
							intv6.prefixes := prefixes;
							intv6.neighborCache := neighborCache;
							intv6.destCache := destCache;
						END;
					END;
					INC(count);
				END;
				prefixConfigItem := prefixConfigItem.next;
			END;
		END ConfigAsRouter;


		(** Adds a packet to the fragment list *)
		PROCEDURE AddToFragmentList(srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
		VAR
			fragmentListItem: FragmentList;
			newPacketFragmentItem: PacketFragment;
			packetFragmentItem: PacketFragment;
			fragmentID: LONGINT;


			(** Ad new fragmentItem *)
			PROCEDURE CreateNewFragAndAdd;
			BEGIN
				NEW(fragmentListItem);
				fragmentListItem.fragmentID := fragmentID;
				fragmentListItem.nextHeader := ORD(buffer.data[buffer.ofs]);
				fragmentListItem.srcAdr := srcAdr;
				fragmentListItem.dstAdr := dstAdr;
				Kernel.SetTimer(fragmentListItem.startedAt, 60000); (* 60 seconds *)
				fragmentListItem.fragmentCount := 1;

				NEW(newPacketFragmentItem);
				newPacketFragmentItem.buffer := buffer;

				(* calculate fragment offset & more fragments flag *)
				buffer.data[buffer.ofs] := 0X;
				newPacketFragmentItem.fragmentOffset := Network.GetNet4(buffer.data, buffer.ofs);

				(* more fragments flag *)
				newPacketFragmentItem.moreFragments :=  0 IN SYSTEM.VAL(SET, newPacketFragmentItem.fragmentOffset);
				newPacketFragmentItem.fragmentOffset := 8 * (newPacketFragmentItem.fragmentOffset DIV 8); (* shift 3 right times 8 *)
				buffer.data[buffer.ofs] := CHR(fragmentListItem.nextHeader);

				newPacketFragmentItem.next := NIL;
				newPacketFragmentItem.prev := NIL;

				fragmentListItem.packets := newPacketFragmentItem;
				fragmentListItem.next := fragmentList;
				fragmentList := fragmentListItem;
			END CreateNewFragAndAdd;


		BEGIN
			fragmentID := Network.GetNet4(buffer.data, buffer.ofs + 4);

			(* Does already a entry exist *)
			fragmentListItem := fragmentList;
			WHILE (fragmentListItem # NIL) &
				     (fragmentListItem.fragmentID # fragmentID) &
				     (~IP.AdrsEqual(fragmentListItem.srcAdr, srcAdr)) &
				     ( ~IP.AdrsEqual(fragmentListItem.dstAdr, dstAdr)) DO
				fragmentListItem := fragmentListItem.next;
			END;

			IF fragmentListItem = NIL THEN
				CreateNewFragAndAdd();
			ELSE
				(* insert fragmented packet into right position *)
				INC(fragmentListItem.fragmentCount);
				NEW(newPacketFragmentItem);
				newPacketFragmentItem.buffer := buffer;

				(* calculate fragment offset *)
				buffer.data[buffer.ofs] := 0X;
				newPacketFragmentItem.fragmentOffset := Network.GetNet4(buffer.data, buffer.ofs);

				(* more fragments flag *)
				newPacketFragmentItem.moreFragments :=  0 IN SYSTEM.VAL(SET, newPacketFragmentItem.fragmentOffset);
				newPacketFragmentItem.fragmentOffset := 8 * (newPacketFragmentItem.fragmentOffset DIV 8);(* shift 3 right times 8 *)
				buffer.data[buffer.ofs] := CHR(fragmentListItem.nextHeader);

				packetFragmentItem := fragmentListItem.packets;
				LOOP
					IF (packetFragmentItem.next = NIL) & (packetFragmentItem.fragmentOffset <= newPacketFragmentItem.fragmentOffset) THEN
						(* last item *)
						packetFragmentItem.next := newPacketFragmentItem;
						newPacketFragmentItem.next := NIL;
						newPacketFragmentItem.prev := packetFragmentItem;
						EXIT;
					END;

					IF packetFragmentItem.fragmentOffset > newPacketFragmentItem.fragmentOffset THEN
						newPacketFragmentItem.next := packetFragmentItem;
						newPacketFragmentItem.prev := packetFragmentItem.prev;
						packetFragmentItem.prev := newPacketFragmentItem;

						IF newPacketFragmentItem.prev = NIL THEN
							(* new first elem *)
							fragmentListItem.packets := newPacketFragmentItem;
						ELSE
							(* elem in the middle *)
							newPacketFragmentItem.prev.next := newPacketFragmentItem;
						END;
						EXIT;
					END;
					packetFragmentItem := packetFragmentItem.next;
				END;
				(* Reassemble packets *)
				ReassembleFragments(fragmentListItem);
			END;
		END AddToFragmentList;


		(** Reassemble fragmented packets *)
		PROCEDURE ReassembleFragments(fragmentListItem: FragmentList);
		VAR
			packetFragmentItem: PacketFragment;
			currentFragmentOffset: LONGINT;
			lastPacketOk: BOOLEAN;
			lastFragment: PacketFragment;

		BEGIN
			(* Check timer *)
			IF Kernel.Expired(fragmentListItem.startedAt) THEN

				(* send ICMP Time Exceeded -- Fragment Reassembly Time Exceeded message *)
				IF fragmentListItem.packets.fragmentOffset = 0 THEN
					(* only if first fragment was received *)
					sendICMPv6TimeExceeded(SELF, fragmentListItem.packets.buffer, fragmentListItem.srcAdr, ICMPv6FragmentReassemblyExc);
				END;
				DelFragmentListEntry(fragmentListItem, TRUE);
			ELSE
				(* Check if all fragments are present *)
				packetFragmentItem := fragmentListItem.packets;
				currentFragmentOffset := 0;
				lastPacketOk := FALSE;
				WHILE (packetFragmentItem # NIL) & (currentFragmentOffset = packetFragmentItem.fragmentOffset) DO
					IF packetFragmentItem.next = NIL THEN
						(* last packet: no more fragments *)
						lastPacketOk := ~packetFragmentItem.moreFragments;
						lastFragment := packetFragmentItem;
					END;

					INC(currentFragmentOffset, packetFragmentItem.buffer.len - FragmentHdrLen);
					packetFragmentItem := packetFragmentItem.next;
				END;

				IF (packetFragmentItem = NIL) & lastPacketOk THEN
					(* Reassemble packet *)
					(* connect packets through nextFragment *)
					packetFragmentItem := fragmentListItem.packets;
					WHILE packetFragmentItem.next # NIL DO
						packetFragmentItem.buffer.nextFragment := packetFragmentItem.next.buffer;
						(* adjust offset *)
						INC(packetFragmentItem.next.buffer.ofs, FragmentHdrLen);
						DEC(packetFragmentItem.next.buffer.len, FragmentHdrLen);

						packetFragmentItem := packetFragmentItem.next;
					END;

					IPInput(dev, EtherTypeIP, fragmentListItem.packets.buffer);
					DelFragmentListEntry(fragmentListItem, FALSE);
				END;
			END;
		END ReassembleFragments;


		(** Delete a entry in the fragmentation list *)
		PROCEDURE DelFragmentListEntry(fragmentListEntry: FragmentList; returnBuffers: BOOLEAN);
		VAR
			fragmentListFind: FragmentList;

		BEGIN
			(* discard the fragmented packets *)
			IF returnBuffers THEN
				Network.ReturnBuffer(fragmentListEntry.packets.buffer);
			END;

			(* delete fragment list entry *)
			IF fragmentList = fragmentListEntry THEN
				(* delete first entry in fragment list *)
				fragmentList := fragmentListEntry.next;
			ELSE
				(* delete entry in the middle or at the end *)
				fragmentListFind := fragmentList;
				WHILE (fragmentListFind.next # NIL) & (fragmentListFind.next # fragmentListEntry) DO
					fragmentListFind := fragmentListFind.next;
				END;
				fragmentListFind.next := fragmentListFind.next.next;
			END;
		END DelFragmentListEntry;


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

				routers.OutRouters;

				KernelLog.String("Prefix: "); IP.OutAdr(maskAdr); KernelLog.Ln;

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


	BEGIN {ACTIVE}
		(* init timers *)
		NEW(shortTimer);
		Kernel.SetTimer(longTimer, LongTimerTimeout);
		Kernel.SetTimer(duplicateTimer, LongTimerTimeout);

		(* Init solicited multicast MAC address *)
		linkMulticastSolicited[0] := 33X;
		linkMulticastSolicited[1] := 33X;
		linkMulticastSolicited[2] := 0FFX;
		linkMulticastSolicited[3] := dev.local[3];
		linkMulticastSolicited[4] := dev.local[4];
		linkMulticastSolicited[5] := dev.local[5];
		linkMulticastSolicited[6] := 0X;
		linkMulticastSolicited[7] := 0X;

		linkMTU := 1500; (* Default value for link MTU (assuming I'm on ethernet) *)
		curHopLimit := 255; (* Default hop limit *)

		REPEAT
			shortTimer.Sleep(ShortTimerTimeout);

			IF Kernel.Expired(duplicateTimer) THEN
				IF autoconfigState = TentativeInterface THEN
					autoconfigState := PreferredInterface;
				END;
			END;

			(* Search fragment list for lost packets *)
			fragmentListItem := fragmentList;
			WHILE fragmentListItem # NIL DO
				(* Check timer *)
				IF Kernel.Expired(fragmentListItem.startedAt) THEN
					(* send ICMP Time Exceeded -- Fragment Reassembly Time Exceeded message *)
					IF fragmentListItem.packets.fragmentOffset = 0 THEN
						(* only if first fragment was received *)
						sendICMPv6TimeExceeded(SELF, fragmentListItem.packets.buffer, fragmentListItem.srcAdr, ICMPv6FragmentReassemblyExc);
					END;
					DelFragmentListEntry(fragmentListItem, TRUE);
				END;
				fragmentListItem := fragmentListItem.next;
			END;

			IF createStatelessInterface THEN
				(* Do stateless autoconfiguration *)
				IF sendRouterSolicitation # NIL THEN
					IF routerSolCount < 4 THEN
						RouterSolicitation;
					ELSE
						(* initiate DHCPv6 *)
						createStatelessInterface := FALSE;
						createStatefulInterface := TRUE;

(*						(* create new interface on which asks a DHCPv6 *)
						Strings.Concat(V6DHCPIntName , dev.name, intName);
						NEW (intv6, intName, dev, res);
						IF res = IP.Ok THEN
							(* configure DHCP interface *)
						END;
*)						createStatefulInterface := FALSE;
					END;
				END;
			END;

			(* Interface acts as a router *)
			IF isRouter THEN
				IF nextRtrAdvertisement = 0 THEN
					(* send a unsolicited router advertisement *)
					sendRouterAdvertisement(SELF, linkLocalMulticastNodeAdr, linkMulticastAllNodesAdr, routerConfig);

					(* When to send next unsolicited router advertisement *)
					nextRtrAdvertisement := RandomNumber(MaxRtrAdvInterval - MinRtrAdvInterval);
					INC(nextRtrAdvertisement, MinRtrAdvInterval);
					nextRtrAdvertisement := nextRtrAdvertisement DIV ShortTimerTimeout;
				ELSE
					DEC(nextRtrAdvertisement);
				END;
			END;

			IF Kernel.Expired(longTimer) THEN
				IF autoconfigurated THEN
					(* If no stateful or stateless interfaces exist, try to create them *)
					int := IP.interfaces;
					createStatefulInterface := TRUE;
					createStatelessInterface := TRUE;
					WHILE int # NIL DO
						IF Strings.Pos(V6RouterIntName, int.name) = 0 THEN
							createStatelessInterface := FALSE;
						END;

						IF Strings.Pos(V6DHCPIntName, int.name) = 0 THEN
							createStatefulInterface := FALSE;
						END;
						int := int.next;
					END;
				END;
				Kernel.SetTimer(longTimer, LongTimerTimeout);

				(* Check caches for old entries and delete them *)
				destCache.Clear();	(* Destination cache *)
				prefixes.ClearExpired();	(* Clear expired prefixes *)
				routers.ClearExpired();	(* Clear expired default routers *)
				localAdrCache.ClearExpired(); (* Clear expored local addresses *)
				RouterSolicitation();


			END;
		UNTIL closed;
	END Interface;


TYPE
	SendNeighborSolicitation* = PROCEDURE {DELEGATE} (interface: Interface; linkAdr: Network.LinkAdr; destAdr: IP.Adr; multicast: BOOLEAN);
	SendNeighborAdvertisement* = PROCEDURE {DELEGATE} (interface: Interface; linkDst: Network.LinkAdr; destAdr: IP.Adr; solicited: BOOLEAN);
	SendRouterSolicitation* = PROCEDURE {DELEGATE} (interface: Interface);
	SendRouterAdvertisement* = PROCEDURE {DELEGATE} (interface: Interface; dstAdr: IP.Adr; dstLinkAdr: Network.LinkAdr; routerConfig:RouterConfig);
	SendICMPv6TimeExceeded* = PROCEDURE {DELEGATE} (interface: Interface; discardedPacket: Network.Buffer; srcAdr: IP.Adr; code: LONGINT);
	SendICMPv6ParamProb* = PROCEDURE {DELEGATE} (interface: Interface; discardedPacket: Network.Buffer; srcAdr: IP.Adr; probPointer, code: LONGINT);
	ICMPLinkLayerAdrOption* = PROCEDURE {DELEGATE} (VAR buffer: Network.Buffer; VAR linkAdr: Network.LinkAdr);
	ICMPPrefixInfoOption* = PROCEDURE {DELEGATE} (VAR buffer: Network.Buffer;
													     VAR onLink, autonomous, routerAddress, sitePrefix: BOOLEAN;
													     VAR validLifetime, preferredLifetime, sitePrefixLength: LONGINT;
													     VAR localPrefix: IP.Adr);
	ICMPRedirectHdrOption* = PROCEDURE {DELEGATE} (VAR buffer: Network.Buffer);
	ICMPMTUOption* = PROCEDURE {DELEGATE} (VAR buffer: Network.Buffer; VAR MTU: LONGINT);
	ICMPAdvIntervalOption* = PROCEDURE {DELEGATE} (VAR buffer: Network.Buffer);
	ICMPHomeAgentInfoOption* = PROCEDURE {DELEGATE} (VAR buffer: Network.Buffer);
	ICMPRouteInfoOption* = PROCEDURE {DELEGATE} (VAR buffer: Network.Buffer);


VAR
	(* Delegates *)
	sendNeighborSolicitation*: SendNeighborSolicitation;
	sendNeighborAdvertisement*: SendNeighborAdvertisement;
	sendRouterSolicitation*: SendRouterSolicitation;
	sendRouterAdvertisement*: SendRouterAdvertisement;
	sendICMPv6TimeExceeded*: SendICMPv6TimeExceeded;
	sendICMPv6ParamProb*: SendICMPv6ParamProb;
	icmpLinkLayerAdrOption*: ICMPLinkLayerAdrOption;
	icmpPrefixInfoOption*: ICMPPrefixInfoOption;
	icmpRedirectHdrOption*: ICMPRedirectHdrOption;
	icmpMTUOption*: ICMPMTUOption;
	icmpAdvIntervalOption*: ICMPAdvIntervalOption;
	icmpHomeAgentInfoOption*: ICMPHomeAgentInfoOption;
	icmpRouteInfoOption*: ICMPRouteInfoOption;

	(* Link-Local prefix *)
	linkLocalPrefix: IP.Adr;

	(* Multicast addresses *)
	nodeLocalMulticastNodeAdr: IP.Adr;
	nodeLocalMulticastRouterAdr: IP.Adr;
	linkLocalMulticastNodeAdr*: IP.Adr;
	linkLocalMulticastRouterAdr*: IP.Adr;

	(* Ethernet multicast addresses *)
	linkMulticastAllNodesAdr*: Network.LinkAdr;
	linkMulticastAllRoutersAdr*: Network.LinkAdr;

	(* list of devices *)
	devList: DeviceList;

	(* local address cache *)
	localAdrCache: LocalAdrCache;

	(* fragmentation *)
	fragmentationID: LONGINT;
	fragmentListItem: FragmentList;

	(* random generator *)
	randomZ: LONGINT;


(* Checks if a part of two addresses is equal *)
PROCEDURE AdrsPartEqual(adr1, adr2: IP.Adr; from, to: LONGINT): BOOLEAN;
VAR
	i: LONGINT;
	isPartEqual: BOOLEAN;

BEGIN
	IF DEBUG THEN
		ASSERT((from >= 0) & (from <= 15));
		ASSERT((from >= 0) & (from <= 15));
		ASSERT(from <= to);
	END;

	isPartEqual := TRUE;

	FOR i := from TO to DO
		IF (adr1.ipv6Adr[i] # adr2.ipv6Adr[i]) THEN
			isPartEqual := FALSE;
		END;
	END;
	RETURN isPartEqual;
END AdrsPartEqual;


(** Checks if a buffer contains a valid IPv6 packet; this check is performed for Network *)
PROCEDURE IsPacketValid(VAR buffer: Network.Buffer): BOOLEAN;
VAR
	isValid: BOOLEAN;

BEGIN
	isValid := FALSE;

	Machine.AtomicInc(IP.NIPRcvTotal);
	IF buffer.len >= MinIPHdrLen THEN
		IF LSH(ORD(buffer.data[buffer.ofs]), -4) = IP.IPv6 THEN
			isValid := TRUE;
		ELSE
			Machine.AtomicInc(IP.NIPBadVersion)
		END
	ELSE
		Machine.AtomicInc(IP.NIPTooSmall)
	END;
	RETURN isValid;
END IsPacketValid;


(** Performs a check for Network if a packet is for a single interface *)
PROCEDURE IsPacketForSingleInt(buffer: Network.Buffer): BOOLEAN;
BEGIN
	(* All IPv6 packets are delivered to only one interface *)
	RETURN TRUE;
END IsPacketForSingleInt;


(* Check if adr is a link-local multicast adr: linkLocalMulticastAdr *)
PROCEDURE IsLinkLocalMulticastAdr (adr: IP.Adr): BOOLEAN;
VAR
	isLinkLocal: BOOLEAN;

BEGIN
	isLinkLocal := FALSE;

	IF IP.AdrsEqual(adr, linkLocalMulticastNodeAdr) THEN
		isLinkLocal := TRUE;
	END;
	RETURN isLinkLocal;
END IsLinkLocalMulticastAdr;


(* Check if adr is a link-local adr: FE80::/64 prefix *)
PROCEDURE IsLinkLocalAdr (adr: IP.Adr): BOOLEAN;
VAR
	isLinkLocal: BOOLEAN;

BEGIN
	isLinkLocal := FALSE;

	IF IP.MatchPrefix(adr, linkLocalPrefix) THEN
		isLinkLocal := TRUE;
	END;
	RETURN isLinkLocal;
END IsLinkLocalAdr;

(** Delivers the right interface for a specific destination *)
PROCEDURE V6InterfaceByDstIP(dstAdr: IP.Adr): IP.Interface;
VAR
	retInt: Interface;
	devListItem: DeviceList;
	linkLocalInt: Interface;
	neighborCacheItem: NeighborCacheEntry;
	sleepTimer: Kernel.Timer;
	sleepCounter: LONGINT;		(* 5 times 100 ms *)
	normalCase: BOOLEAN;
	intItem: IP.Interface;
	gw: IP.Interface;
	linkDst: Network.LinkAdr;
	devCount: LONGINT;

BEGIN
	(* Problem: When two network devices are available it is impossible to know on
	    which device a link-local address is. Therefore neigbor solicitations are sent on
	    both devices. The procedure has then to wait until the neighbor advertisement
	    arrives. *)
	retInt := NIL;
	devListItem := devList;
	NEW(sleepTimer);
	sleepCounter := 0;
	normalCase := TRUE;

	(* Look if an address is a link-local address *)
	IF IsLinkLocalAdr(dstAdr) THEN
		(* Are there multiple devices present *)
		devCount := 0;
		WHILE devListItem # NIL DO
			IF devListItem.device.name # "Loopback" THEN
				INC(devCount);
			END;
			devListItem := devListItem.next;
		END;

		IF devCount > 1 THEN
			normalCase := FALSE;

			retInt := localAdrCache.GetInterface(dstAdr);

			WHILE (retInt = NIL) & (sleepCounter < 5) DO
				(* search in neighbor cache *)
				devListItem := devList;
				WHILE devListItem # NIL DO
					linkLocalInt := devListItem.linkLocalInterface;

					IF linkLocalInt # NIL THEN
						(* search neighbor cache *)
						neighborCacheItem := linkLocalInt.neighborCache.Get(dstAdr);
						IF neighborCacheItem # NIL THEN
							retInt := linkLocalInt;
						END;

						(* look if the dstAdr is equal a local address *)
						IF IP.AdrsEqual(dstAdr, linkLocalInt.localAdr) THEN
							retInt := linkLocalInt;
						END;
					END;
					devListItem := devListItem.next;
				END;
				IF retInt = NIL THEN
					(* send neigbor solicitations on all devices *)
					devListItem := devList;
					WHILE devListItem # NIL DO
						IF (devListItem.linkLocalInterface # NIL) &
						    (devListItem.linkLocalInterface IS Interface) &
						    (devListItem.linkLocalInterface.dev.Linked() # Network.LinkNotLinked) THEN
							(* link and IP destination addresses are the solicited node addresses *)
							linkDst := linkMulticastAllNodesAdr;
							linkDst[2] := 0FFX;
							linkDst[3] := dstAdr.ipv6Adr[13];
							linkDst[4] := dstAdr.ipv6Adr[14];
							linkDst[5] := dstAdr.ipv6Adr[15];

							(* Send a Neighbor Solicitation message *)
							sendNeighborSolicitation(devListItem.linkLocalInterface(Interface), linkDst, dstAdr, TRUE);
						END;
						devListItem := devListItem.next;
					END;
				END;
				sleepTimer.Sleep(200);
				INC(sleepCounter);
			END;

			IF retInt # NIL THEN
				(* store interface in local address cache *)
				localAdrCache.Add(dstAdr, retInt);
			END;
		END;
	END;

	(* Normal case *)
	IF (retInt = NIL) & normalCase THEN
		gw := NIL;
		intItem := IP.interfaces;
		LOOP
			IF intItem = NIL THEN
				EXIT
			END;

			IF (intItem.protocol = IP.IPv6) & (~IP.IsNilAdr(intItem.localAdr)) & (intItem.dev.Linked() # Network.LinkNotLinked) THEN
				IF IP.MatchPrefix(dstAdr, intItem.maskAdr) THEN
					EXIT;
				ELSIF (gw = NIL) & (~IP.IsNilAdr(intItem.maskAdr)) THEN
					gw := intItem;
				END;
			END;

			intItem := intItem.next;
		END;

		IF intItem # NIL THEN
			retInt := intItem(Interface);
		ELSE
			retInt := gw(Interface);
		END;
	END;
	RETURN retInt;
END V6InterfaceByDstIP;

(*
(** Deliver the link-local interface of a certain device *)
PROCEDURE GetLinkLocalInterface(dev: Network.LinkDevice): Interface;
VAR
	devListItem: DeviceList;

BEGIN
	devListItem := devList;

	WHILE (devListItem # NIL) & (devListItem.device # dev) DO
		devListItem := devListItem.next;
	END;

	IF devListItem # NIL THEN
		RETURN devListItem.linkLocalInterface;
	ELSE
		RETURN NIL;
	END;
END GetLinkLocalInterface;
*)

(** Deliver a ID for packet fragmentation *)
PROCEDURE GetFragmentID(): LONGINT;
BEGIN {EXCLUSIVE}
	INC(fragmentationID);
	RETURN fragmentationID;
END GetFragmentID;


(** Parses the routing header extension *)
PROCEDURE RoutingExtHeader(int: IP.Interface; type: LONGINT; srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
VAR
	segmentsLeft: LONGINT;
	hdrExtLen: LONGINT;
	receiver: IP.Receiver;
	nextHeader: LONGINT;
	nbrOfAdrs: LONGINT;
	ithAddress: LONGINT;
	tempAdr: ARRAY 16 OF CHAR;
	intv6: Interface;

BEGIN
	ASSERT (int IS Interface);

	intv6 := int(Interface);
	(* read values *)
	nextHeader := ORD(buffer.data[buffer.ofs]);
	hdrExtLen := ORD(buffer.data[buffer.ofs + 1]);
	segmentsLeft := ORD(buffer.data[buffer.ofs + 3]);

	IF IP.AdrsEqual(dstAdr, int.localAdr) THEN
		IF segmentsLeft = 0 THEN
			(* process next header *)
			receiver := IP.receivers[nextHeader];
			IF receiver # NIL THEN
				(* do receiver upcall *)
				INC(buffer.ofs, hdrExtLen * 8 + RoutingHdrLen);
				DEC(buffer.len, hdrExtLen * 8 + RoutingHdrLen);

				receiver(int, nextHeader, srcAdr, dstAdr, buffer);
				(* Exit here w/o returning buffer because it is passed to a receiver *)
				RETURN;
			ELSE
				Network.ReturnBuffer(buffer);
			END;
		ELSIF IP.IPForwarding THEN
			IF hdrExtLen MOD 2 = 1 THEN
				(* odd header extension length *)
				sendICMPv6ParamProb(intv6, buffer, srcAdr, MinIPHdrLen + 2, 0);
				Network.ReturnBuffer(buffer);
			ELSE
				(* segments left not correct *)
				nbrOfAdrs := hdrExtLen DIV 2;
				IF segmentsLeft > nbrOfAdrs THEN
					sendICMPv6ParamProb(intv6, buffer, srcAdr, MinIPHdrLen + 4, 0);
					Network.ReturnBuffer(buffer);
				ELSE
					DEC(segmentsLeft);
					buffer.data[buffer.ofs + 4] := CHR(segmentsLeft);

					ithAddress := nbrOfAdrs - segmentsLeft;

					(* swap dest adr and ith address *)
					Network.Copy(dstAdr.ipv6Adr, tempAdr, 0, 0, 16);
					Network.Copy(buffer.data, dstAdr.ipv6Adr, 8 + (ithAddress - 1 * 16), 0, 16);
					Network.Copy(tempAdr, buffer.data, 0, (ithAddress - 1 * 16), 16);

					(* For forwarding set offset to IP level *)
					INC(buffer.len, buffer.ofs);
					buffer.ofs := 0;
				END;
			END;
		ELSE
			Network.ReturnBuffer(buffer);
		END;
	END;
END RoutingExtHeader;


(** Parses the hop-by-hop header extension, which is ignored up to now *)
PROCEDURE HopByHopExtHeader(int: IP.Interface; type: LONGINT; srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
VAR
	receiver: IP.Receiver;
	nextHeader: LONGINT;
	hdrExtLen: LONGINT;
	intv6: Interface;

BEGIN
	ASSERT(int IS Interface);

	intv6 := int(Interface);

	nextHeader := ORD(buffer.data[buffer.ofs]);
	hdrExtLen := ORD(buffer.data[buffer.ofs + 1]);

	(* process next header *)
	receiver := IP.receivers[nextHeader];
	IF receiver # NIL THEN
		(* do receiver upcall *)
		INC(buffer.ofs, hdrExtLen * 8 + HopByHopHdrLen);
		DEC(buffer.len, hdrExtLen * 8 + HopByHopHdrLen);

		receiver(intv6, nextHeader, srcAdr, dstAdr, buffer);
		(* Exit here w/o returning buffer because it is passed to a receiver *)
		RETURN;
	ELSE
		Network.ReturnBuffer(buffer);
	END;
END HopByHopExtHeader;


(** Parses the destination header extension, which is ignored up to now *)
PROCEDURE DestinationExtHeader(int: IP.Interface; type: LONGINT; srcAdr, dstAdr: IP.Adr; buffer: Network.Buffer);
VAR
	receiver: IP.Receiver;
	nextHeader: LONGINT;
	hdrExtLen: LONGINT;
	intv6: Interface;

BEGIN
	ASSERT(int IS Interface);

	intv6 := int(Interface);

	nextHeader := ORD(buffer.data[buffer.ofs]);
	hdrExtLen := ORD(buffer.data[buffer.ofs + 1]);

	(* process next header *)
	receiver := IP.receivers[nextHeader];
	IF receiver # NIL THEN
		(* do receiver upcall *)
		INC(buffer.ofs, hdrExtLen * 8 + DestinationHdrLen);
		DEC(buffer.len, hdrExtLen * 8 + DestinationHdrLen);

		receiver(intv6, nextHeader, srcAdr, dstAdr, buffer);
		(* Exit here w/o returning buffer because it is passed to a receiver *)
		RETURN;
	ELSE
		Network.ReturnBuffer(buffer);
	END;
END DestinationExtHeader;


(** Deliver a random number between 0 and limit *)
PROCEDURE RandomNumber(limit: LONGINT): LONGINT;
CONST
	a = 16807;
	m = 2147483647;
	q = m DIV a;
	r = m MOD a;

VAR
	g: LONGINT;

BEGIN
	g := a*(randomZ MOD q) - r*(randomZ DIV q);
	IF g > 0 THEN randomZ := g ELSE randomZ := g + m END;
	RETURN ENTIER((randomZ*1.0D0/m) * limit);	(* must compute this in double precision, e.g. (m-1)/m *)
END RandomNumber;


PROCEDURE Cleanup;
BEGIN
	(* Remove all interfaces *)
	WHILE IP.interfaces # NIL DO
		IP.interfaces.Close();
	END;
END Cleanup;


BEGIN
	(* link-local prefix *)
	linkLocalPrefix := IP.NilAdr;
	linkLocalPrefix.usedProtocol := IP.IPv6;
	linkLocalPrefix.ipv6Adr[0] := 0FEX;
	linkLocalPrefix.ipv6Adr[1] := 80X;
	linkLocalPrefix.data := 64;

	(* init multicast addresses *)
	nodeLocalMulticastNodeAdr := IP.NilAdr;
	nodeLocalMulticastRouterAdr := IP.NilAdr;
	linkLocalMulticastNodeAdr := IP.NilAdr;
	linkLocalMulticastRouterAdr := IP.NilAdr;

	nodeLocalMulticastNodeAdr.usedProtocol := IP.IPv6;
	nodeLocalMulticastRouterAdr.usedProtocol := IP.IPv6;
	linkLocalMulticastNodeAdr.usedProtocol := IP.IPv6;
	linkLocalMulticastRouterAdr.usedProtocol := IP.IPv6;

	nodeLocalMulticastNodeAdr.ipv6Adr[0] := 0FFX;
	nodeLocalMulticastRouterAdr.ipv6Adr[0] := 0FFX;
	linkLocalMulticastNodeAdr.ipv6Adr[0] := 0FFX;
	linkLocalMulticastRouterAdr.ipv6Adr[0] := 0FFX;

	nodeLocalMulticastNodeAdr.ipv6Adr[1] := 1X;
	nodeLocalMulticastRouterAdr.ipv6Adr[1] :=1X;
	linkLocalMulticastNodeAdr.ipv6Adr[1] := 2X;
	linkLocalMulticastRouterAdr.ipv6Adr[1] := 2X;

	nodeLocalMulticastNodeAdr.ipv6Adr[15] := 1X;
	nodeLocalMulticastRouterAdr.ipv6Adr[15] :=2X;
	linkLocalMulticastNodeAdr.ipv6Adr[15] := 1X;
	linkLocalMulticastRouterAdr.ipv6Adr[15] := 2X;

	(* Init Ethernet Multicast addresses *)
	linkMulticastAllNodesAdr[0] := 33X;
	linkMulticastAllNodesAdr[1] := 33X;
	linkMulticastAllNodesAdr[2] := 0X;
	linkMulticastAllNodesAdr[3] := 0X;
	linkMulticastAllNodesAdr[4] := 0X;
	linkMulticastAllNodesAdr[5] := 1X;
	linkMulticastAllNodesAdr[6] := 0X;
	linkMulticastAllNodesAdr[7] := 0X;

	linkMulticastAllRoutersAdr[0] := 33X;
	linkMulticastAllRoutersAdr[1] := 33X;
	linkMulticastAllRoutersAdr[2] := 0X;
	linkMulticastAllRoutersAdr[3] := 0X;
	linkMulticastAllRoutersAdr[4] := 0X;
	linkMulticastAllRoutersAdr[5] := 2X;
	linkMulticastAllRoutersAdr[6] := 0X;
	linkMulticastAllRoutersAdr[7] := 0X;

	(* random generator initialization *)
	randomZ := Kernel.GetTicks();

	devList := NIL;

	NEW(localAdrCache);

	IP.v6InterfaceByDstIP := V6InterfaceByDstIP;

	IP.InstallReceiver(IPv6RoutingHdrType, RoutingExtHeader);
	IP.InstallReceiver(IPv6HopByHopHdrType, HopByHopExtHeader);
	IP.InstallReceiver(IPv6DestinationHdrType, DestinationExtHeader);

	Modules.InstallTermHandler(Cleanup);
END IPv6.




Free:
SystemTools.Free TraceRoute VNC Ping WMFTPClient FTPClient WebFTPServer TCPServices TLS InitNetwork Ping DHCP TCP DNS UDP ICMP IPv4 IPv6 IP~

Start:
InitNetwork.Init

Compile:
PC.Compile \s IP.Mod IPv4.Mod IPv6.Mod ICMP.Mod UDP.Mod DNS.Mod TCP.Mod DHCP.Mod InitNetwork.Mod WebFTPServer.Mod FTPClient.Mod WMFTPClient.Mod Ping.Mod VNC.Mod TraceRoute.Mod~




History:
02.05.2005	eb	Created.
     07.2005    eb    Cache added