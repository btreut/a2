(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE DHCP; (** AUTHOR "pjm, mvt"; PURPOSE "DHCP client"; *)

(* DHCP - Dynamic Host Configuration Protocol (RFC 2131, RFC 1533, RFC 951)

	BootP Request/Reply Packet

	00	08	operation = 1 (request) or 2 (reply)
	01	08	hardware type = 1 (10Mbit ethernet)
	02	08	hardware address length = 6
	03	08	hops (set to 0 by client)
	04	32	transaction id
	08	16	seconds elapsed since boot
	10	16	unused
	12	32	client ip address (if known)
	16	32	client ip address assigned by server
	20	32	server ip address (in reply)
	24	32	gateway ip address (for cross-gateway booting)
	28	--	client hardware address (16 bytes)
	44	--	server host name (64 bytes, null terminated, optional)
	108	--	boot file name (128 bytes, null terminated, "generic" or empty in request, full name in reply)
	236	--	vendor-specific area (64 bytes, optional)
*)

IMPORT SYSTEM, KernelLog, Kernel, Network, IP, UDP, DNS, IPv6, IPv4;

CONST
	(** Error codes *)
	Ok* = 0;

	BootPTimeMin = 2;	(* in s *)
	BootPClient = 68;
	BootPServer = 67;

	MaxDHCPMsgSize = 548;
	MaxOfferTries = 3;
	MaxRequestTries = 3;

	Trace = FALSE;

(* Parse the BootP vendor extensions in buf[i..m-1]. *)

PROCEDURE ParseOptions(VAR buf: ARRAY OF CHAR; i, m: LONGINT; VAR maskAdr, gatewayAdr: IP.Adr;
		VAR dns: ARRAY OF IP.Adr; VAR domain: ARRAY OF CHAR; VAR serverIP: IP.Adr; VAR xid:LONGINT;
		VAR msgType:CHAR);
VAR j, len: LONGINT;
BEGIN
	IF (LEN(buf) >= 8) THEN xid := Network.Get4(buf, 4) ELSE xid := 0 END;

	IF (buf[i] = 63X) & (buf[i+1] = 82X) & (buf[i+2] = 53X) & (buf[i+3] = 63X) THEN
		INC(i, 4);
		LOOP
			IF (i >= m) OR (buf[i] = 0FFX) THEN EXIT END;
			IF (buf[i] # 0X) & (i+2 <= m) THEN
				len := ORD(buf[i+1]);
				IF Trace THEN KernelLog.Memory(ADDRESSOF(buf[i]), 2+len) END;
				CASE buf[i] OF
					1X:	(* subnet mask *)
						IF i+6 <= m THEN
							maskAdr.ipv4Adr := Network.Get4(buf, i+2);
							maskAdr.usedProtocol := IP.IPv4;
						END
					|3X:	(* router *)
						IF i+6 <= m THEN
							gatewayAdr.ipv4Adr := Network.Get4(buf, i+2);
							gatewayAdr.usedProtocol := IP.IPv4;
						END
					|6X:	(* domain name server *)
						IF i+2+len <= m THEN
							j := 0;
							WHILE (j+4 <= len) & (j DIV 4 # LEN(dns)) DO
								dns[j DIV 4].ipv4Adr := Network.Get4(buf, i+2+j);
								dns[j DIV 4].usedProtocol := IP.IPv4;
								INC(j, 4)
							END
						END
					|35X:	(* DHCP message type *)
						IF i+3 <= m THEN
							msgType := buf[i+2]
						END
					|36X:	(* DHCP server identifier *)
						IF i+6 <= m THEN
							serverIP.ipv4Adr := Network.Get4(buf, i+2);
							serverIP.usedProtocol := IP.IPv4;
						END
					|0FX:	(* domain name *)
						IF i+2+len <= m THEN
							j := 0;
							WHILE (j < len) & (j # LEN(domain)-1) DO
								domain[j] := buf[i+2+j]; INC(j)
							END;
							domain[j] := 0X
						END
				ELSE (* skip *)
				END;
				INC(i, 2+len)
			ELSE
				INC(i)
			END
		END
	ELSE
		KernelLog.Enter; KernelLog.String("DHCP: Unknown BootP cookie");
		KernelLog.Hex(SYSTEM.VAL(LONGINT, buf[i]), 9); KernelLog.Exit
	END
END ParseOptions;

PROCEDURE CreateDHCPDiscoverMsg(hwAdr: Network.LinkAdr; xid,secondsElapsed:LONGINT; VAR buf:ARRAY OF CHAR): LONGINT;
VAR i:LONGINT;
BEGIN
	FOR i := 0 TO LEN(buf)-1 DO buf[i] := 0X END; (* Clear buffer contents *)

	buf[0] := 1X; buf[1] := 1X; buf[2] := 6X; (* bootprequest, 10Mb ethernet, 48bit haddr, hops=0 from init *)

	Network.Put4(buf, 4, xid); (* transaction ID *)

	Network.PutNet2(buf, 8, secondsElapsed); (* Elapsed time *)

	Network.PutNet2(buf, 10, 08000H); 	(* broadcast flag (needed for some ISC DHCP servers) *)

	Network.Copy(hwAdr, buf, 0, 28, 6); (* Fill in hardware address (chaddr field) *)

	buf[236] := 63X; buf[237] := 82X; buf[238] := 53X; buf[239] := 63X; (* options field magic cookie (99, 130, 83,99) *)

	buf[240] := 35X; buf[241] := 1X; buf[242] := 1X; (* DHCP message type: DHCP-DISCOVER *)

	buf[243] := 0FFX; (* options end *)

	(* return length *)
	RETURN ((243 + 1 + 15) DIV 16) * 16	(* align to 16-byte boundary *)
END CreateDHCPDiscoverMsg;

PROCEDURE CreateDHCPRequestMsg(hwAdr: Network.LinkAdr; xid, secondsElapsed:LONGINT; VAR buf:ARRAY OF CHAR; serverIP:IP.Adr; myNewIP :IP.Adr): LONGINT;
VAR i:LONGINT;
BEGIN
	FOR i := 0 TO LEN(buf)-1 DO buf[i] := 0X END; (* Clear buffer contents *)

	buf[0] := 1X; buf[1] := 1X; buf[2] := 6X; (* bootprequest, 10Mb ethernet, 48bit haddr, hops=0 from init *)

	Network.Put4(buf, 4, xid); (* transaction ID *)

	Network.PutNet2(buf, 8, secondsElapsed); (* Elapsed time *)

	Network.PutNet2(buf, 10, 08000H); 	(* broadcast flag (needed for some ISC DHCP servers) *)

	Network.Copy(hwAdr, buf, 0, 28, 6); (* Fill in hardware address (chaddr field) *)

	buf[236] := 63X; buf[237] := 82X; buf[238] := 53X; buf[239] := 63X; (* options field magic cookie (99, 130, 83,99) *)

	buf[240] := 35X; buf[241] := 1X; buf[242] := 3X; (* DHCP message type: DHCP-REQUEST *)

	buf[244] := 36X; buf[245] := 4X; Network.Put4(buf,246, serverIP.ipv4Adr); (* server identifier option *)

	buf[252] := 32X; buf[253] := 4X; Network.Put4(buf,254, myNewIP.ipv4Adr); (* requested IP option *)

	buf[260] := 37X; buf[261] := 4X; (* "requested options" option *)
	buf[262] := 1X; (* netmask *)
	buf[263] := 3X; (* router (gateway) *)
	buf[264] := 6X; (* DNS servers *)
	buf[265] := 0FX; (* domain name *)

	buf[268] := 0FFX; (* options end *)

	(* return length *)
	RETURN (268 + 1 + 15) DIV 16 * 16	(* align to 16-byte boundary *)
END CreateDHCPRequestMsg;

(* Initiate the boot protocol. When successful, return res = 0 and set the parameters. *)

PROCEDURE InitDHCP(int: IP.Interface; VAR localAdr, maskAdr, gatewayAdr: IP.Adr;
		VAR dns: ARRAY OF IP.Adr; VAR domain: ARRAY OF CHAR; VAR res: LONGINT);
VAR
	p: UDP.Socket;
	fport, len, time, start, offerDelay, requestDelay, i: LONGINT;
	fip, serverIP: IP.Adr;
	msgType: CHAR;
	xid, rxid, offerTries, requestTries: LONGINT;
	buf: ARRAY MaxDHCPMsgSize OF CHAR;
	msgLen: LONGINT; exit: BOOLEAN;
	(* used to avoid busy waits *)
	t: Kernel.Timer;
	sleep: LONGINT;
BEGIN
	NEW(t);
	localAdr := IP.NilAdr;
	localAdr.usedProtocol := IP.IPv4;
	maskAdr := IP.NilAdr;
	maskAdr.usedProtocol := IP.IPv4;
	gatewayAdr := IP.NilAdr;
	gatewayAdr.usedProtocol := IP.IPv4;

	domain[0] := 0X;
	FOR i := 0 TO LEN(dns)-1 DO
		dns[i] := IP.NilAdr
	END;

	(* DHCP client in INIT State *)
	NEW(p, BootPClient, res);
	IF res = UDP.Ok THEN
		start := ASH(Kernel.GetTicks(), 16) + Kernel.GetTicks();
		offerDelay := BootPTimeMin * Kernel.second;	(* Start timing *)
		xid := start;	(* Generate "random" xid *)
		offerTries := 1;	(* First DHCP-DISCOVER request *)
		LOOP
			(* empty receive buffer (ev. "garbage" from previous offers) *)
			REPEAT
				p.Receive(buf, 0, LEN(buf), 0, fip, fport, len, res);
			UNTIL res = UDP.Timeout;

			exit := FALSE;
			INC(xid);
			KernelLog.Enter; KernelLog.String("DHCP: Discover - xid "); KernelLog.Int(xid, 0); KernelLog.Exit;
			time := Kernel.GetTicks();

			(* Send DHCP-DISCOVER Msg *)
			msgLen := CreateDHCPDiscoverMsg(int.dev.local, xid, 0(*((time-start) DIV Kernel.second)*), buf);
			p.SendBroadcast(int, BootPServer, buf, 0, msgLen);
			(* Receive the DHCP-OFFER *)
			p.Receive(buf, 0, LEN(buf), offerDelay, fip, fport, len, res);

			(* Is it a BOOTPReply from DHCP ServerPort? *)
			IF (res = UDP.Ok) & (fport = BootPServer) & (len >= 28) & (buf[0] = 2X) & (xid = Network.Get4(buf, 4)) THEN
				localAdr.ipv4Adr := Network.Get4(buf, 16);
				localAdr.usedProtocol := IP.IPv4;

				KernelLog.Enter; KernelLog.String("DHCP: BootP reply from "); (*IP.OutAdr(Network.Get4(buf, 20))*)
				KernelLog.String("; IP offered: "); IP.OutAdr(localAdr); KernelLog.Exit;

				IF len > 236 THEN
					ParseOptions(buf, 236, len, maskAdr, gatewayAdr, dns, domain, serverIP, rxid, msgType);
					KernelLog.Enter; KernelLog.String("DHCP: Offer received - xid "); KernelLog.Int(rxid, 0);
					KernelLog.String( " msgType "); KernelLog.Int(ORD(msgType), 0); KernelLog.Exit;

					(* Check xid to make sure it matches the most recent DISCOVER request *)
					IF (rxid = xid) & (msgType = 2X) THEN	(* DHCP-OFFER *)
						requestTries := 1; requestDelay := 2 * Kernel.second;
						LOOP
							(* empty receive buffer (ev. "garbage" from previous offers or ACKs) *)
							REPEAT
								p.Receive(buf, 0, LEN(buf), 0, fip, fport, len, res);
							UNTIL res = UDP.Timeout;

							time := Kernel.GetTicks();
							KernelLog.Enter; KernelLog.String("DHCP: Request - xid "); KernelLog.Int(xid,0); KernelLog.Exit;
							msgLen := CreateDHCPRequestMsg(int.dev.local, xid, 0(*((time-start) DIV Kernel.second)*), buf, serverIP, localAdr);
							p.SendBroadcast(int, BootPServer, buf, 0, msgLen);
							(* Receive the DHCP-ACK *)
							p.Receive(buf, 0, LEN(buf), requestDelay, fip, fport, len, res);
							IF (res = UDP.Ok) & (fport = BootPServer) & (len >= 28) & (buf[0] = 2X) THEN
								IF (localAdr.ipv4Adr = Network.Get4(buf, 16)) THEN
									ParseOptions(buf, 236, len, maskAdr, gatewayAdr, dns, domain, serverIP, rxid, msgType);
									KernelLog.Enter; KernelLog.String("DHCP: Ack - xid "); KernelLog.Int(rxid,0);
									KernelLog.String( " msgType "); KernelLog.Int(ORD(msgType), 0); KernelLog.Ln;
									KernelLog.String("   localIP: "); IP.OutAdr(localAdr);
									KernelLog.String("; mask: "); IP.OutAdr(maskAdr);
									KernelLog.String("; gateway: "); IP.OutAdr(gatewayAdr);
									KernelLog.Exit;
									exit := TRUE
								ELSE
									KernelLog.Enter; KernelLog.String("DHCP: Nack - xid "); KernelLog.Int(rxid,0);
									KernelLog.String( " msgType "); KernelLog.Int(ORD(msgType), 0); KernelLog.Ln;
									KernelLog.Exit;
									localAdr := IP.NilAdr;
									exit := FALSE;
									res := 3;
								END;
								EXIT
							END;
							(* REPEAT UNTIL Kernel.GetTicks() - time > requestDelay; *)	(* busy wait *)
							sleep := offerDelay - (Kernel.GetTicks() - time);
							IF sleep > 0 THEN
								t.Sleep(sleep);
							END;

							IF requestTries >= MaxRequestTries THEN
								KernelLog.Enter; KernelLog.String("DHCP: Retransmission limit reached"); KernelLog.Exit;
								EXIT
							END;
							INC(requestTries); requestDelay := requestDelay * 2
						END;
						IF exit THEN EXIT END
					ELSE
						(* wrong type *)
						res := 2;
					END
				ELSE
					(* wrong length *)
					res := 1;
				END
			END;

			(* Exponential backoff *)
			(* REPEAT UNTIL Kernel.GetTicks() - time > offerDelay; *)	(* busy wait *)

			sleep := offerDelay - (Kernel.GetTicks() - time);
			IF sleep > 0 THEN
				t.Sleep(sleep);
			END;

			offerDelay := offerDelay*3 DIV 2;
			INC(offerTries);
			IF offerTries > MaxOfferTries THEN
				res := UDP.Timeout;
				EXIT;
			END;
		END;
		p.Close
	END
END InitDHCP;

(** Run DHCP on specified interface and try to configure it directly. *)

PROCEDURE RunDHCP*(int: IP.Interface; VAR res: LONGINT);
VAR
	localAdr, maskAdr, gatewayAdr: IP.Adr;
	dns: ARRAY IP.MaxNofDNS OF IP.Adr;
	domain: IP.Name;
	i: LONGINT;
	intv4: IPv4.Interface;

BEGIN {EXCLUSIVE}
	IF int IS IPv6.Interface THEN
		KernelLog.String("DHCP: DHCP for IPv6 interfaces not yet implemented"); KernelLog.Ln;
	ELSE
		intv4 := int (IPv4.Interface);
		intv4.doingDHCPRequest := TRUE;
		(* run DHCP protocol on this interface *)
		KernelLog.String("DHCP: Starting DHCP on interface '"); KernelLog.String(int.name); KernelLog.String("'..."); KernelLog.Ln;
		InitDHCP(int, localAdr, maskAdr, gatewayAdr, dns, domain, res);
		IF res = Ok THEN
			(* configure interface *)
			int.SetAdrs(localAdr, maskAdr, gatewayAdr, res);
			IF DNS.domain = "" THEN
				COPY(domain, DNS.domain);
				KernelLog.String("DHCP: DNS.domain set to: "); KernelLog.String(domain); KernelLog.Ln;
			ELSE
				KernelLog.String("DHCP: DNS.domain not set because it is alredy defined."); KernelLog.Ln;
			END;
			(* add DNS server *)
			int.DNSRemoveAll;
			i := 0;
			WHILE (i < LEN(dns)) & (~IP.IsNilAdr(dns[i])) DO
				int.DNSAdd(dns[i]);
				INC(i);
			END;
		END;
		KernelLog.String("DHCP: Finished DHCP on interface '"); KernelLog.String(int.name);
		KernelLog.String("'. Error code: "); KernelLog.Int(res, 0); KernelLog.Ln;
		intv4.doingDHCPRequest := FALSE;
	END;
END RunDHCP;

END DHCP.

(*
History:
02.11.2003	mvt	Moved interface configuration to InitNetwork.
02.11.2003	mvt	Complete redesign for new interfaces of underlying modules.
03.11.2003	mvt	Replaced busy waits by Kernel.Timer.Sleep().
02.05.2004	eb	DHCP client for IPv4. IPv6 DHCP client is not supported.

ToDo (pjm):
o correct state machine implementation?
	e.g. in the following scenario:
		C->S: discover 0
		(reply delayed)
		C->S: discover 1
		S->C: offer 0 (ignored by client.  correct?)
		C->S: discover 2
		S->C: offer 1 (ignored by client.  correct?)
o return res # 0 if protocol didn't complete successfully (DHCP NAK)
o renew lease
o release the lease in term handler
o ARP resolution after commit - gratitious ARP (export procedure for this from IP?)
*)
