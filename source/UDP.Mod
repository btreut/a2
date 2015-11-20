(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE UDP; (** AUTHOR "pjm, mvt"; PURPOSE "UDP protocol"; *)

(*
	UDP Header

	00	16	source port
	02	16	destination port
	04	16	UDP length (header and data)
	06	16	UDP checksum (pseudo-header, header and data)
	08	--	optional data

	UDP Pseudo-header (for checksum calculation)

	00	32	source address
	04	32	destination address
	08	08	zero = 0
	09	08	protocol = 17
	10	16	UDP length (duplicate)

	Notes:
	o Bit numbers above are Intel bit order.
	o Avoid use of SET because of PPC bit numbering issues.
	o Always access fields as 8-, 16- or 32-bit values and use DIV, MOD, ASH, ODD for bit access.
*)

IMPORT Modules, Machine, Objects, Network, IP, ICMP;

CONST
	(** Error codes *)
	Ok* = 0;
	PortInUse* = 3501;
	Timeout* = 3502;
	BufferOverflow* = 3503;
	NoInterface* = 3504;
	Closed* = 3505;

	NilPort* = 0;

	IPTypeUDP = 17; (* UDP type code for IP packets *)
	UDPHdrLen = 8;
	MaxPseudoHdrLen = 40;  (* IPv4: 12, IPv6: 40 *)
	MaxUDPDataLen = 10000H-UDPHdrLen;

	MinEphemeralPort = 1024;
	MaxEphemeralPort = 5000;

	QueueSize = 40; (* size (number of packets) of receive queue per socket *)
	HashTableSize = 128; (* size of connection lookup hash table *)

TYPE
	(** Socket. Stores the state of a UDP communication endpoint. *)
	Socket* = OBJECT
		VAR
			next: Socket; (* link for socket pool *)
			lport: LONGINT; (* local port *)

			hdr: ARRAY UDPHdrLen OF CHAR; (* UDP prototype header for sending *)
			pseudoHdr: ARRAY MaxPseudoHdrLen OF CHAR; (* pseudo header for calculating checksum *)

			(* Receive queue (ring buffer) *)
			queue: ARRAY QueueSize OF Network.Buffer;
			queueFirst: LONGINT; (* index where the new items are queued *)
			queueLast: LONGINT; (* index where the items are removed from the queued *)

			(* Variables for handling timeout *)
			timer: Objects.Timer;
			timeout, open: BOOLEAN;


		(** Constructor *)
		PROCEDURE &Open*(lport: LONGINT; VAR res: LONGINT);
		BEGIN
			open := TRUE;
			ASSERT((lport >= 0) & (lport < 10000H));
			SELF.lport := lport;
			IF pool.AddSocket(SELF) THEN
				(* set first part of UDP header *)
				Network.PutNet2(hdr, 0, SELF.lport);
				(* set up buffering and blocking *)
				queueFirst := 0;
				queueLast := 0;
				NEW(timer);
				res := Ok;
			ELSE
				res := PortInUse;
			END
		END Open;


		(** Send a UDP datagram to the foreign address specified by "fip" and "fport".
			The data is in "data[ofs..ofs+len-1]".  In case of concurrent sends the datagrams are serialized. *)
		PROCEDURE Send*(fip: IP.Adr; fport: LONGINT; CONST data: ARRAY OF CHAR; ofs, len: LONGINT; VAR res: LONGINT);
		VAR
			int: IP.Interface;

		BEGIN {EXCLUSIVE}
			ASSERT((fport >= 0) & (fport < 10000H));
			ASSERT((len >= 0) & (len <= MaxUDPDataLen));

			int := IP.InterfaceByDstIP(fip);

			IF int # NIL THEN
				DoSend(int, fip, fport, data, ofs, len);
				res := Ok;
			ELSE
				res := NoInterface;
			END;
		END Send;


		(** Send a broadcast UDP datagram via interface "int" to port "lport". Normally only used by DHCP.
			The data is in "data[ofs..ofs+len-1]".  In case of concurrent sends the datagrams are serialized. *)
		PROCEDURE SendBroadcast*(int: IP.Interface; fport: LONGINT; CONST data: ARRAY OF CHAR; ofs, len: LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT((fport >= 0) & (fport < 10000H));
			ASSERT((len >= 0) & (len <= MaxUDPDataLen));
			DoSend(int, int.broadAdr, fport, data, ofs, len);
		END SendBroadcast;


		(** Receive a UDP datagram.  If none is available, wait up to the specified timeout for one to arrive.
		"data[ofs..ofs+size-1]" is the data buffer to hold the returned datagram.
		"ms" is a wait timeout value in milliseconds, 0 means "don't wait", -1 means "infinite wait".
		On return, "fip" and "fport" hold the foreign address and port.
		"len" returns the actual datagram size and "data[ofs..ofs+len-1]" returns the data.
		"res" returns "Timeout" in case of a timeout and "BufferOverflow" if the received datagram was too big.
		*)
		PROCEDURE Receive*(VAR data: ARRAY OF CHAR; ofs, size, ms: LONGINT; VAR fip: IP.Adr; VAR fport, len, res: LONGINT);
		VAR
			buffer: Network.Buffer;
			fragmentBuffer: Network.Buffer;
			fragmentOffset: LONGINT;

		BEGIN {EXCLUSIVE}
			IF ~open THEN res := Closed; RETURN END;
			IF queueFirst = queueLast THEN
				(* queue empty *)
				IF ms > 0 THEN
					timeout := FALSE;
					Objects.SetTimeout(timer, DoTimeout, ms);
					AWAIT((queueFirst # queueLast) OR timeout OR ~open);
					IF ~open THEN res := Closed; RETURN END;
					IF timeout THEN
						res := Timeout;
						RETURN;
					ELSE
						Objects.CancelTimeout(timer)
						(* now we can continue *)
					END;
				ELSIF ms = -1 THEN
					(* infinite wait *)
					AWAIT((queueFirst # queueLast) OR ~ open);
					IF ~open THEN res := Closed; RETURN END;
				ELSE
					res := Timeout;
					RETURN;
				END;
			END;
			(* Here we can get a packet from the queue *)
			buffer := queue[queueLast];
			queueLast := (queueLast + 1) MOD QueueSize;

			fip := IP.SrcAdrFromBuffer(buffer);
			fport := Network.GetNet2(buffer.data, buffer.ofs);
			fragmentBuffer := buffer;
			len := 0;
			WHILE fragmentBuffer # NIL DO
				INC(len, fragmentBuffer.len);
				fragmentBuffer := fragmentBuffer.nextFragment;
			END;

			DEC(len, UDPHdrLen);
			IF len > size THEN
				(* packet too big for receive buffer *)
				res := BufferOverflow;
			ELSE
				Network.Copy(buffer.data, data, buffer.ofs+UDPHdrLen, ofs, buffer.len - UDPHdrLen);
				fragmentOffset := ofs + buffer.len - UDPHdrLen;
				fragmentBuffer := buffer.next;
				WHILE fragmentBuffer # NIL DO
					Network.Copy(fragmentBuffer.data, data, buffer.ofs, fragmentOffset, buffer.len);
					INC(fragmentOffset, buffer.len);

					fragmentBuffer := fragmentBuffer.nextFragment;
				END;

				res := Ok;
			END;
			Network.ReturnBuffer(buffer);
		END Receive;


		(* Internal send operation. Called from "Send" and "SendBroadcast". *)
		PROCEDURE DoSend(int: IP.Interface; fip: IP.Adr; fport: LONGINT; CONST data: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR
			sum: LONGINT;
			pseudoHdrLen: LONGINT;
		BEGIN
			(* set UDP header *)
			Network.PutNet2(hdr, 2, fport); (* foreign port *)
			Network.PutNet2(hdr, 4, len+UDPHdrLen); (* UPD length *)
			Network.Put2(hdr, 6, 0); (* checksum := 0 *)
			IF ~(Network.ChecksumUDP IN int.dev.calcChecksum) THEN
				(* set pseudo header *)
				pseudoHdrLen := int.WritePseudoHeader(pseudoHdr, int.localAdr, fip, IPTypeUDP, len+UDPHdrLen);

				sum := IP.Checksum1(pseudoHdr, 0, pseudoHdrLen, 0);
				sum := IP.Checksum1(hdr, 0, UDPHdrLen, sum);
				sum := IP.Checksum2(data, ofs, len, sum);

				Network.Put2(hdr, 6, sum); (* checksum := sum *)
			END;
			int.Send(IPTypeUDP, fip, hdr, data, UDPHdrLen, ofs, len, IP.MaxTTL);
		END DoSend;


		(* Handle timeout call from Objects *)
		PROCEDURE DoTimeout;
		BEGIN {EXCLUSIVE}
			timeout := TRUE;
		END DoTimeout;


		(* Input a datagram on this socket. *)
		PROCEDURE Input(fip: IP.Adr; buffer: Network.Buffer);
		BEGIN {EXCLUSIVE}
			IF (queueLast - queueFirst) MOD QueueSize = 1 THEN
				(* queue full - discard packet and return buffer *)
				Machine.AtomicInc(NUDPQueueOverflow);
				Network.ReturnBuffer(buffer);
			ELSE
				queue[queueFirst] := buffer;
				queueFirst := (queueFirst + 1) MOD QueueSize;
				Machine.AtomicInc(NUDPQueued);
			END;
		END Input;


		(** Close the Socket, freeing its address for re-use. *)
		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			pool.RemoveSocket(SELF);
			Objects.CancelTimeout(timer);
			open := FALSE;
			(* return all queued buffers *)
			WHILE queueFirst # queueLast DO
				Network.ReturnBuffer(queue[queueLast]);

				queueLast := (queueLast + 1) MOD QueueSize;
			END;
			(* do not touch any other fields, as instance may still be in use via pool.Lookup. *)
		END Close;

	END Socket;


	(* Socket pool *)
	SocketPool = OBJECT
		VAR
			table: ARRAY HashTableSize OF Socket;
			eport: LONGINT;

		(* Initialize the pool. *)
		PROCEDURE &Init*;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO HashTableSize-1 DO
				table[i] := NIL;
			END;
			eport := MinEphemeralPort;
		END Init;


		(* Look for the specified Socket *)
		PROCEDURE Lookup(lport: LONGINT): Socket;
		VAR item: Socket;
		BEGIN
			item := table[lport MOD HashTableSize];
			WHILE (item # NIL) & (item.lport # lport) DO
				item := item.next;
			END;
			RETURN item;
		END Lookup;


		(* Add a socket to the pool. If lport is NilPort, an ephemeral port is assigned. *)
		PROCEDURE AddSocket(p: Socket): BOOLEAN;
		VAR
			ok: BOOLEAN;
			i, sport: LONGINT;
		BEGIN {EXCLUSIVE}
			IF p.lport = NilPort THEN
				(* find an unused ephemeral port *)
				sport := eport; (* store port where the search started *)
				REPEAT
					p.lport := eport;
					(* check if port is in use *)
					ok := (Lookup(eport) = NIL);
					INC(eport);
					IF eport > MaxEphemeralPort THEN
						eport := MinEphemeralPort;
					END;
				UNTIL ok OR (eport = sport);
				(* ok is TRUE here if the port is not used yet *)
			ELSE
				(* ensure port is not in use *)
				ok := (Lookup(p.lport) = NIL);
			END;
			IF ok THEN
				i := p.lport MOD HashTableSize;
				p.next := table[i];
				table[i] := p;
			END;
			RETURN ok;
		END AddSocket;


		(* Remove the Socket from the pool, making its address re-usable. *)
		PROCEDURE RemoveSocket(p: Socket);
		VAR
			i: LONGINT;
			item: Socket;
		BEGIN {EXCLUSIVE}
			i := p.lport MOD HashTableSize;
			IF table[i] = NIL THEN
				(* not found *)
			ELSIF table[i] = p THEN
				table[i] := table[i].next;
			ELSE
				item := table[i];
				WHILE (item.next # NIL) & (item.next # p) DO
					item := item.next;
				END;
				IF item.next # NIL THEN
					item.next := item.next.next;
				END;
			END;
			(* do not clear p.next, because Lookup may be looking at it *)
		END RemoveSocket;


		(* Close all sockets that are registered in pool *)
		PROCEDURE CloseAll;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO HashTableSize-1 DO
				WHILE table[i] # NIL DO
					table[i].Close();
				END;
			END;
		END CloseAll;

	END SocketPool;


VAR
	(* Module variables *)
	pool: SocketPool;

	(* Statistic variables *)
	NUDPRcvTotal-, NUDPTooSmall-, NUDPBadChecksum-, NUDPRcvBroadcast-, NUDPUnknownPort-,
	NUDPQueued-, NUDPQueueOverflow-, NUDPTrim-, NUDPBadHdrLen-: LONGINT;


(* Receive a UDP datagram. *)
PROCEDURE Input(int: IP.Interface; type: LONGINT; fip, lip: IP.Adr; buffer: Network.Buffer);
VAR
	(* pseudo header for calculating checksum *)
	pseudoHdr: ARRAY MaxPseudoHdrLen OF CHAR;
	pseudoHdrLen: LONGINT;
	sum, tlen: LONGINT;
	s: Socket;
	reassembledLength: LONGINT;
	fragmentBuffer: Network.Buffer;

BEGIN
	Machine.AtomicInc(NUDPRcvTotal);
	IF buffer.len >= UDPHdrLen THEN
		tlen := Network.GetNet2(buffer.data, buffer.ofs+4);
		IF (tlen >= UDPHdrLen) & (tlen <= buffer.len) THEN
			IF tlen < buffer.len THEN
				(* size not used *)
				Machine.AtomicInc(NUDPTrim);
				buffer.len := tlen;
			END;
			IF Network.ChecksumUDP IN buffer.calcChecksum THEN
				sum := 0;
			ELSE
				sum := Network.Get2(buffer.data, buffer.ofs+6); (* get checksum from header *)
			END;
			IF sum # 0 THEN
				(* calculate checksum *)
				(* set pseudo header *)
				reassembledLength := 0;
				fragmentBuffer := buffer;
				WHILE fragmentBuffer # NIL DO
					INC(reassembledLength, fragmentBuffer.len);
					fragmentBuffer := fragmentBuffer.nextFragment;
				END;

				pseudoHdrLen := int.WritePseudoHeader(pseudoHdr, fip, lip, IPTypeUDP, reassembledLength);
				sum := IP.Checksum1(pseudoHdr, 0, pseudoHdrLen, 0);

				IF buffer.nextFragment # NIL THEN
					(* fragmented packets *)
					fragmentBuffer := buffer;
					WHILE fragmentBuffer.nextFragment # NIL DO
						sum := IP.Checksum1(fragmentBuffer.data, fragmentBuffer.ofs, fragmentBuffer.len, sum);
						fragmentBuffer := fragmentBuffer.nextFragment;
					END;
					sum := IP.Checksum2(fragmentBuffer.data, fragmentBuffer.ofs, fragmentBuffer.len, sum);
				ELSE
					sum := IP.Checksum2(buffer.data, buffer.ofs, buffer.len, sum);
				END;
			END;
			IF sum = 0 THEN
				s := pool.Lookup(Network.GetNet2(buffer.data, buffer.ofs+2));
				IF s # NIL THEN
					s.Input(fip, buffer);
					(* Exit here w/o returning buffer because it is passed to Socket.Input *)
					RETURN;
				ELSIF ~int.IsBroadcast(lip) THEN
					Machine.AtomicInc(NUDPUnknownPort);
					ICMP.SendICMP (ICMP.ICMPDstUnreachable, fip, buffer);
				END;
			ELSE
				Machine.AtomicInc(NUDPBadChecksum);
			END;
		ELSE
			Machine.AtomicInc(NUDPBadHdrLen);
		END;
	ELSE
		Machine.AtomicInc(NUDPTooSmall);
	END;
	(* Exit and return buffer here because it is no longer used *)

	Network.ReturnBuffer(buffer);
END Input;

PROCEDURE Cleanup;
BEGIN
	IP.RemoveReceiver(IPTypeUDP);
	pool.CloseAll();
END Cleanup;

BEGIN
	NEW(pool);
	IP.InstallReceiver(IPTypeUDP, Input);
	Modules.InstallTermHandler(Cleanup);
END UDP.

(*
History:
27.10.2003	mvt	Complete internal redesign for new interfaces of Network and IP.
22.11.2003	mvt	Changed SocketPool to work with a hash table.
02.05.2005	eb Works with fragmented packets & IPv6 ready (WritePseudoHdr)
*)
