(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE IP; (** AUTHOR "pjm, mvt, eb"; PURPOSE "IP (v4 and v6)"; *)

IMPORT SYSTEM, KernelLog, Commands, Strings, Network;

CONST
	(* DEBUG *)
	DEBUG = TRUE;

	(** Error codes *)
	Ok* = 0;
	DeviceAlreadyUsed* = 3901;
	DuplicateInterfaceName* = 3902;
	NoInterfaceName* = 3903;
	GatewayNotInSubnet* = 3904;
	IPv6AdrUsedOnIPv4Interface* = 4001;
	IPv4AdrUsedOnIPv6Interface* = 4002;
	DublicatedAddresses* = 4003;
	MixedIpProtocols* = 4003;
	LocalAdrSetIntv6* = 4004;   (* local address must be NIL when calling SetAdrs on a IPv6 interface *)
	PrefixNotSet* = 4005; (* prefix on ipv6 interface must be set with local address *)

	MaxNofDNS* = 10; (** maximum number of DNS servers per interface *)
	MaxTTL* = 255; (** maximum time-to-live on outgoing datagrams *)

	NbrOfReceivers = 255; (* Number of possible receivers, i.e. possible layer 3 protocols *)

	(** IP address constants *)
	NilAdrIPv4 = 0;

	(* Comparators for Adr.usedProtocols *)
	IPv4* = 4;
	IPv6* = 6;
	NilAdrIdent = -1;	(* usedProtocol of NilAdrs *)

	(* ICMP *)
	ICMPHdrLen* = 4;
	ICMPSrcLLAdrOptionType* = 1;
	ICMPTargetLLAdrOptionType* = 2;
	ICMPPrefixInfoOptionType* = 3;
	ICMPRedirectHdrOptionType* = 4;
	ICMPMTUOptionType* = 5;
	ICMPAdvIntOptionType* = 7;
	ICMPHomeAgOptionType* = 8;
	ICMPRouteOption* = 9;


TYPE
	Adr* = RECORD
		ipv4Adr*: LONGINT;
		ipv6Adr*: ARRAY 16 OF CHAR;
		usedProtocol*: LONGINT;
		data*: LONGINT;
	END; (** An IP Address.	usedProtocol = 0: No protocol yet used
							usedProtocol = IPv4: IPv4 address stored in field ipv4Adr
							usedProtocol = IPv6: IPv6 address stored in field ipv6Adr
							data can be used to store additional informations. I.e. in IPv6 the
							prefix length is stored in the data field *)

TYPE
	Packet* = POINTER TO ARRAY OF CHAR;

	Name* = ARRAY 128 OF CHAR; (** Name type for interface name *)

	Interface* = OBJECT
	VAR
		(** IP addresses of this interface. *)
		localAdr*, maskAdr*, gatewayAdr*, subnetAdr*, broadAdr*: Adr;

		(** name of the interface *)
		name*: Name;

		(** Device that the interface belongs to *)
		dev*: Network.LinkDevice;

		(** DNS server list - can be used by DNS, not used in IP itself *)
		DNS-: ARRAY MaxNofDNS OF Adr; (* DNS server list *)
		DNScount*: LONGINT; (* number of DNS servers in list *)

		(* interface *)
		next*: Interface; (* next pointer for interface list *)
		closed*: BOOLEAN; (* is interface already closed? *)
		protocol*: LONGINT; (* Interface for IPv4 or IPv6?. Only used by IP otherwise use dynamic type checking! *)


		(** Set addresses. Is normally called just after instanciation, but can also be called later, e.g. by DHCP.
			If "gatewayAdr" is "NilAdr", the subnet is considered to have no gateway, else it must be in the same
			subnet as the "localAdr".
			"domain" can be an empty string. It is normally used by a DNS implementation. It is not used in IP directly.
			In IPv6 maskAdr is the prefix of the currently IP address *)
		PROCEDURE SetAdrs*(localAdr, maskOrPrefixAdr, gatewayAdr: Adr; VAR res: LONGINT);
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END SetAdrs;


		(** Remove all domain name servers from the interface. *)
		PROCEDURE DNSRemoveAll*;
		BEGIN {EXCLUSIVE}
			DNScount := 0;
		END DNSRemoveAll;


		(** Add a domain name server to the interface. *)
		PROCEDURE DNSAdd*(adr: Adr);
		VAR
			i: LONGINT;

		BEGIN {EXCLUSIVE}
			(* concurrent lookup is consistent *)
			ASSERT(DNScount < MaxNofDNS);

			i := 0;
			WHILE i < DNScount DO
				IF AdrsEqual (DNS[i],adr) THEN RETURN END;
				INC(i)
			END;
			DNS[DNScount] := adr;
			INC(DNScount);
		END DNSAdd;


		(** Remove a domain name server from the interface. *)
		PROCEDURE DNSRemove*(adr: Adr);
		VAR i: LONGINT;
		BEGIN {EXCLUSIVE}
			(* concurrent lookup could result in a duplicate address in worst-case *)
			(* this happends hardly ever and is harmless for DNS anyway *)
			i := 0;
			WHILE (i < DNScount) & (~ AdrsEqual(DNS[i],adr)) DO
				INC(i)
			END;
			IF i < DNScount THEN
				INC(i);
				WHILE i < DNScount DO
					DNS[i-1] := DNS[i];
					INC(i);
				END;
				DEC(DNScount);
			END;
		END DNSRemove;


		(** Send an IP packet on this interface. *)
		PROCEDURE Send*(type: LONGINT; destAdr: Adr; CONST l4hdr, data: ARRAY OF CHAR; h4len, dofs, dlen, TTL: LONGINT);
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END Send;


		(* Internal procedure to perform the rest of the send operation. Used by "Send" and for IP forwarding. *)
		PROCEDURE DoSend*(destAdr: Adr; CONST l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT) ;
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END DoSend;


		(** Enumerate all ARP table entries. *)
		PROCEDURE ARPEnumerate*(handle: ARPHandler);
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END ARPEnumerate;


		(** Close and deactivate the interface, i.e. remove it from the configuration. *)
		PROCEDURE Close*;
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END Close;


		(** Check if adr is a broadcast address *)
		PROCEDURE IsBroadcast*(adr: Adr) : BOOLEAN;
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END IsBroadcast;


		(** Check if adr is a multicast address *)
		PROCEDURE IsMulticast*(adr: Adr) : BOOLEAN;
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END IsMulticast;


		(** Receive an IP packet *)
		PROCEDURE IPInput*(dev: Network.LinkDevice; type: LONGINT; buffer: Network.Buffer);
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END IPInput;


		(** Reads the source address of a IP packet buffer *)
		PROCEDURE ReadSrcAdr* (buffer: Network.Buffer): Adr;
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END ReadSrcAdr;


		(** Reads the destination address of a IP packet buffer *)
		PROCEDURE ReadDestAdr* (buffer: Network.Buffer): Adr;
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END ReadDestAdr;


		(** Creates a pseudo-header for checksum calculation (TCP/UDP) and returns the length of this header *)
		PROCEDURE WritePseudoHeader*(VAR pseudoHdr: ARRAY OF CHAR;  src, dst: Adr; protocol, pktLengthUpperLayer: LONGINT): LONGINT;
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END WritePseudoHeader;


		(** Writes the configuration of this interface *)
		PROCEDURE OutInterface*;
		BEGIN
			(* Extensions have to override this method.*)
			HALT(99);
		END OutInterface;

	END Interface;


TYPE
	(* List of interfaces *)
	InterfaceList* = POINTER TO RECORD
		interface*: Interface;
		next*: InterfaceList;
	END;

	Receiver* = PROCEDURE {DELEGATE} (int: Interface; type: LONGINT; fip, lip: Adr; buffer: Network.Buffer);
	V6InterfaceByDstIP* = PROCEDURE {DELEGATE} (dstAdr: Adr): Interface;

	(** Handler for ARPPool.Enumerate. *)
	ARPHandler* = PROCEDURE {DELEGATE} (ip: Adr; complete: BOOLEAN; link: Network.LinkAdr; size, sendTime, updateTime, updateDate, hash: LONGINT);

	InterfaceHandler* = PROCEDURE {DELEGATE} (int: Interface);


VAR
	(* receiver *)
	receivers*: ARRAY 256 OF Receiver; (* registered receivers - array position is IPv4 protocol field or IPv6 next header field *)

	(* Interface by dst for IPv6 *)
	v6InterfaceByDstIP*: V6InterfaceByDstIP;

	(* IP *)
	NilAdr*: Adr; (* To check if an IP address is NIL use IsNilAdr instead *)
	preferredProtocol*: LONGINT;	(* Preferred IP protocol *)

	(* IP counters *)
	NIPSentToSubnet*, NIPSentToGateway*, NIPSentBroadcast*, NIPCantFragment*,
	NIPRcvTotal*, NIPTooSmall*, NIPBadVersion*, NIPOptions*, NIPBadChecksum*,
	NIPBadLength*, NIPTrim*, NIPBadHdrLen*, NIPNotForUs*, NIPCantReassemble*, NIPSrcIsBroadcast*,
	NIPDelivered*, NIPNoReceiver*, NIPForwarded*, NIPSentLocalLoopback*, NIPSentPointToPoint*: LONGINT;

	(* turn on/off IP forwarding, echo replay *)
	IPForwarding*: BOOLEAN;
	EchoReply*: BOOLEAN;

	(* Interface *)
	interfaces*: Interface; (* list of all installed interfaces *)

	counter: LONGINT; (* Use it only in the module body! *)


(** Is address not yet specified *)
PROCEDURE IsNilAdr* (adr: Adr): BOOLEAN;
VAR
	isNil: BOOLEAN;
	i: LONGINT;

BEGIN
	CASE adr.usedProtocol OF
		IPv4:
			RETURN (adr.ipv4Adr = NilAdrIPv4)

		|IPv6:
			isNil := TRUE;
			i := 0;
			WHILE ((i<16) & isNil) DO
				IF adr.ipv6Adr[i] # 0X THEN
					isNil := FALSE;
				END;
				INC(i);
			END;
			RETURN isNil;

		|NilAdrIdent:
			RETURN TRUE;

		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
			RETURN TRUE;
	END;
END IsNilAdr;


(* Checks if two addresses are equal *)
PROCEDURE AdrsEqual* (adr1, adr2: Adr): BOOLEAN;
VAR
	equal: BOOLEAN;
	i: LONGINT;

BEGIN
	IF adr1.usedProtocol # adr2.usedProtocol THEN
		RETURN FALSE;
	END;

	CASE adr1.usedProtocol OF
		IPv4:
			IF adr1.ipv4Adr = adr2.ipv4Adr THEN
				RETURN TRUE;
			END;

		|IPv6:
			equal := TRUE;
			i := 0;
			WHILE ((i < 16) & equal) DO
				IF adr1.ipv6Adr[i] # adr2.ipv6Adr[i] THEN
					equal := FALSE;
				END;
				INC(i);
			END;

			IF adr1.data # adr2.data THEN
				equal := FALSE;
			END;

			RETURN equal;

		|NilAdrIdent:
			(* both addresses NIL therefore equal *)
			IF adr2.usedProtocol = NilAdrIdent THEN
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;

		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
			RETURN FALSE;
	END;
	RETURN FALSE;
END AdrsEqual;


(** Convert a dotted-decimal string to an ip address. Return NilAdr on failure. *)
PROCEDURE StrToAdr*(ipString: ARRAY OF CHAR): Adr;
VAR
	retAdr: Adr;
	i, j, x: LONGINT;
	adr: ARRAY 4 OF CHAR;
	ok: BOOLEAN;
	charCount: LONGINT;				(* ipv6: number of character between two : *)
	ipv6AdrPart: ARRAY 6 OF CHAR;		(* two bytes of an IPv6 address *)
	ipv6AdrRight: ARRAY 16 OF CHAR;	(* right part of an IPv6 address; after :: *)
	hexToChar: ARRAY 3 OF CHAR;
	leftParts: LONGINT;					(* number of bytes before :: *)
	rightParts: LONGINT;				(* number of bytes after :: *)
	val, res: LONGINT;
	state: LONGINT;						(* state of the FSM look at the eof for more info *)
	dPointOcc: BOOLEAN;				(* double point occured *)
	prefixVal: LONGINT;


	(* compute a subpart (two bytes) of a IPv6 address; subpart:=between two : *)
	PROCEDURE ComputeIPv6Part():BOOLEAN;
	BEGIN
		CASE charCount OF
			0:
				RETURN TRUE;

			|1,2:
				IF dPointOcc THEN
					ipv6AdrRight[rightParts] := 0X;
					INC(rightParts);
				ELSE
					retAdr.ipv6Adr[leftParts] := 0X;
					INC(leftParts);
				END;
				Strings.HexStrToInt(ipv6AdrPart, val, res);

				IF res = Strings.Ok THEN
					IF dPointOcc THEN
						ipv6AdrRight[rightParts] := CHR(val);
						INC(rightParts);
					ELSE
						retAdr.ipv6Adr[leftParts] := CHR(val);
						INC(leftParts);
					END;
				ELSE
					RETURN FALSE;
				END;

			|3:
				hexToChar[0] := ipv6AdrPart[0];
				hexToChar[1] := 0X;
				Strings.HexStrToInt(hexToChar, val, res);

				IF res = Strings.Ok THEN
					IF dPointOcc THEN
						ipv6AdrRight[rightParts] := CHR(val);
						INC(rightParts);
					ELSE
						retAdr.ipv6Adr[leftParts] := CHR(val);
						INC(leftParts);
					END;
				ELSE
					RETURN FALSE;
				END;
				ipv6AdrPart[0] := "0";
				Strings.HexStrToInt(ipv6AdrPart, val, res);

				IF res = Strings.Ok THEN
					IF dPointOcc THEN
						ipv6AdrRight[rightParts] := CHR(val);
						INC(rightParts);
					ELSE
						retAdr.ipv6Adr[leftParts] := CHR(val);
						INC(leftParts);
					END;
				ELSE
					RETURN FALSE;
				END;

			|4:
				hexToChar[0] := ipv6AdrPart[0];
				hexToChar[1] := ipv6AdrPart[1];
				hexToChar[2] := 0X;
				Strings.HexStrToInt(hexToChar, val, res);

				IF res = Strings.Ok THEN
					IF dPointOcc THEN
						ipv6AdrRight[rightParts] := CHR(val);
						INC(rightParts);
					ELSE
						retAdr.ipv6Adr[leftParts] := CHR(val);
						INC(leftParts);
					END;
				ELSE
					RETURN FALSE;
				END;
				ipv6AdrPart[0] := "0";
				ipv6AdrPart[1] := "0";
				Strings.HexStrToInt(ipv6AdrPart, val, res);

				IF res = Strings.Ok THEN
					IF dPointOcc THEN
						ipv6AdrRight[rightParts] := CHR(val);
						INC(rightParts);
					ELSE
						retAdr.ipv6Adr[leftParts] := CHR(val);
						INC(leftParts);
					END;
				ELSE
					RETURN FALSE;
				END;

			ELSE
				IF DEBUG THEN
					ASSERT(TRUE);
				END;
				RETURN FALSE;
		END;
		charCount := 0;
		RETURN TRUE;
	END ComputeIPv6Part;


BEGIN
	retAdr := NilAdr;

	IF IsValidIPv4Str(ipString) THEN
		(* Return an ipv4 address *)
		i := 0;
		j := 0;
		x := -1;
		ok := FALSE;

		LOOP
			IF (ipString[i] = ".") OR (ipString[i] = 0X) THEN
				IF (x < 0) OR (x > 255) OR (j = 4) THEN EXIT END;
				adr[j] := CHR(x);
				IF ipString[i] = 0X THEN ok := (j = 3); EXIT END;
				x := -1; INC(i); INC(j)
			ELSIF (ipString[i] >= "0") & (ipString[i] <= "9") THEN
				IF x = -1 THEN x := 0 END;
				x := x*10 + (ORD(ipString[i])-ORD("0"));
				INC(i)
			ELSE
				EXIT
			END
		END;

		IF ok THEN
			retAdr.ipv4Adr := SYSTEM.VAL (LONGINT, adr);
			retAdr.usedProtocol := IPv4;
			RETURN retAdr;
		ELSE
			RETURN NilAdr;
		END


	(* IPv6 *)
	ELSIF IsValidIPv6Str(ipString) THEN
		i := 0;
		state := 1;
		charCount := 0;
		dPointOcc := FALSE;
		retAdr.usedProtocol := 6;
		retAdr.ipv4Adr := NilAdrIPv4;
		i := 0;
		j := 0;
		charCount := 0;
		leftParts := 0;
		rightParts := 0;
		prefixVal := 0;

		Strings.UpperCase(ipString);

		WHILE (i < (LEN(ipString) - 1)) & (ipString[i] # 0X) DO

			CASE state OF  (* Using the same FSM as IsValidIPv6Str *)
				-1:	(* Error state
					    Should never happen, is checked by IsValidIPv6Str() *)
					RETURN NilAdr;

				|1:	(* reading two blocks of two bytes of 0-9\A-F *)
					IF ipString[i] = ":" THEN
						ipv6AdrPart[charCount] := 0X;
						IF ~ComputeIPv6Part() THEN
							RETURN NilAdr;
						END;
						state := 2;

					ELSIF ipString[i] = "/" THEN
						ipv6AdrPart[charCount] := 0X;

						IF ~ComputeIPv6Part() THEN
							RETURN NilAdr;
						END;
						state := 3;

					ELSE
						(* 0-9, A-F *)
						ipv6AdrPart[charCount] := ipString[i];
						INC(charCount);
					END;

				|2:	(* a : occured *)
					IF ipString[i] = ":" THEN
						dPointOcc := TRUE;
						state := 4;
					ELSE
						(* 0-9, A-F *)
						state := 1;
						charCount := 0;
						ipv6AdrPart[charCount] := ipString[i];
						INC(charCount);
					END;

				|3:	(* prefix will follow *)
					prefixVal := (prefixVal * 10) + (ORD(ipString[i]) - ORD("0"));

				|4:	(* A :: occured *)
					IF ipString[i] = "/" THEN
						state := 3;
					ELSE
						IF ~ComputeIPv6Part() THEN
							RETURN NilAdr;
						END;

						(* 0-9, A-F *)
						state := 1;
						charCount := 0;
						ipv6AdrPart[charCount] := ipString[i];
						INC(charCount);
					END;
				ELSE
					IF DEBUG THEN
						ASSERT(TRUE);
					END;
			END;
			INC(i);
		END;

		ipv6AdrPart[charCount] := 0X;
		IF charCount # 0 THEN
			IF ~ComputeIPv6Part() THEN
				RETURN NilAdr;
			END;
		END;

		IF dPointOcc THEN
			(* fill 0X for :: *)
			FOR i:= leftParts TO ((LEN(retAdr.ipv6Adr) -1) - rightParts) DO
				retAdr.ipv6Adr[i] := 0X;
			END;

			(* fill part behind :: *)
			FOR i := 0 TO (rightParts - 1) DO
				retAdr.ipv6Adr[(LEN(retAdr.ipv6Adr) - rightParts) + i] := ipv6AdrRight[i];
			END;
		END;

		IF prefixVal > 64 THEN
			RETURN NilAdr;
		END;
		retAdr.data := prefixVal;
		RETURN retAdr;
	END;
	RETURN NilAdr;
END StrToAdr;


(** Convert an IP address to a dotted-decimal string. *)
PROCEDURE AdrToStr*(adr: Adr; VAR string: ARRAY OF CHAR);
VAR
	i, j, x: LONGINT;
	a: ARRAY 4 OF CHAR;
	val: LONGINT;
	hexToStr: ARRAY 5 OF CHAR;
	prefixLenStr: ARRAY 64 OF CHAR;
	maxZeroRow: LONGINT;
	currentZeroRow: LONGINT;
	maxZeroStart: LONGINT;
	currentZeroStart: LONGINT;
	lastZero: BOOLEAN;
	lastDPoint: BOOLEAN;
	countEnded: BOOLEAN;

BEGIN
	CASE adr.usedProtocol OF
		IPv4:
			ASSERT(LEN(string) >= 16);	(* enough space for largest result *)
			Network.Put4(a, 0, adr.ipv4Adr);
			i := 0;
			FOR j := 0 TO 3 DO
				x := ORD(a[j]);
				IF x >= 100 THEN string[i] := CHR(ORD("0")+x DIV 100); INC(i) END;
				IF x >= 10 THEN string[i] := CHR(ORD("0")+x DIV 10 MOD 10); INC(i) END;
				string[i] := CHR(ORD("0")+x MOD 10); INC(i);
				IF j = 3 THEN string[i] := 0X ELSE string[i] := "." END;
				INC(i)
			END

		|IPv6:
			FOR i := 0 TO (LEN(adr.ipv6Adr) -1) BY 2 DO
				(* simple version *)
				val :=  ORD(adr.ipv6Adr[i]) * 256;
				val := val + ORD(adr.ipv6Adr[i+1]);
				Strings.IntToHexStr (val, 3, hexToStr);

				(* Delete leading zeros *)
				WHILE (hexToStr[0] = "0") & (hexToStr[1] # 0X) DO
					Strings.Delete(hexToStr, 0, 1);
				END;
				Strings.Append (string, hexToStr);

				IF i # (LEN(adr.ipv6Adr) - 2) THEN
					Strings.Append (string, ":");
				END;
			END;

			(* replace longest row of zeros with :: *)
			maxZeroRow := 0;
			currentZeroRow := 0;
			maxZeroStart := 0;
			currentZeroStart := 0;
			i := 0;
			lastZero := FALSE;
			lastDPoint := TRUE;
			countEnded :=TRUE;

			WHILE string[i] # 0X DO
				IF string[i] = "0" THEN
					IF lastDPoint THEN
						INC(currentZeroRow);
						lastZero := TRUE;
						lastDPoint := FALSE;
						IF countEnded THEN
							currentZeroStart := i;
							countEnded := FALSE;
						END;
					END;
				ELSIF string[i] = ":" THEN
					lastDPoint := TRUE;
					IF lastZero THEN
						lastZero := FALSE;
					END;
				ELSE
					IF lastDPoint THEN
						lastDPoint := FALSE;
						countEnded := TRUE;
						IF currentZeroRow > maxZeroRow THEN
							maxZeroRow := currentZeroRow;
							maxZeroStart := currentZeroStart;
						END;
					END;
				END;

				INC(i);
			END;

			IF ~countEnded THEN
				IF currentZeroRow > maxZeroRow THEN
					maxZeroRow := currentZeroRow;
					maxZeroStart := currentZeroStart;
				END;
			END;
			IF maxZeroRow # 0 THEN
				(* write a :: *)
				IF maxZeroStart = 0 THEN
					string[0] := ":";
					i := 1;
					WHILE ((string[i] # 0X) & ~((string[i] # "0") & (string[i] # ":"))) DO INC(i); END;
					IF string[i] = 0X THEN
						string := "::";
					ELSE
						Strings.Delete(string, 1, i-2);
					END;
				ELSE
					i := maxZeroStart;
					WHILE ((string[i] = "0") OR (string[i] = ":")) DO INC(i); END;
					IF string[i] = 0X THEN
						string[maxZeroStart] := ":";
						string[maxZeroStart+1] := 0X;
					ELSE
						Strings.Delete(string, maxZeroStart, i - maxZeroStart - 1);
					END;
				END;
			END;

			IF adr.data # 0 THEN
				(* write prefix *)
				Strings.IntToStr(adr.data, prefixLenStr);
				Strings.Append (string, "/");
				Strings.Append (string, prefixLenStr);
			END;

		ELSE
			IF IsNilAdr (adr) THEN
				string := "";
			END;
	END;
END AdrToStr;


(** Convert a IP address from an array [ofs..ofs+x] to an
	Adr-type variable.
	Example for IPv4:
	If the LSB (least significant byte) is stored the the beginning [ofs],
	LSBfirst must be set to TRUE.
		(address "a.b.c.d" is stored as [d,c,b,a])
	If the LSB is stored at the end [ofs+3], LSBfirst must be set to FALSE.
		(address "a.b.c.d" is stored as [a,b,c,d])
*)
PROCEDURE ArrayToAdr*(CONST array: ARRAY OF CHAR; ofs, protocol: LONGINT; LSBfirst: BOOLEAN): Adr;
VAR
	adr: Adr;
	i, swapTemp: LONGINT;
BEGIN
	ASSERT((protocol = 4) OR (protocol = 6));

	IF protocol = IPv4 THEN  (* index check *)
		IF ~(ofs + 4 <= LEN(array)) THEN
			RETURN NilAdr;
		END;

		SYSTEM.MOVE(ADDRESSOF(array[ofs]), ADDRESSOF(adr.ipv4Adr), 4);
		IF LSBfirst THEN
			SwapEndian(adr.ipv4Adr);
		END;
		adr.usedProtocol := IPv4;

	ELSIF protocol = IPv6 THEN
		IF ~(ofs + 16 <= LEN(array)) THEN
			RETURN NilAdr;
		END;

		SYSTEM.MOVE(ADDRESSOF(array[ofs]), ADDRESSOF(adr.ipv6Adr), 16);
		IF LSBfirst THEN
			FOR i := 0 TO 3 DO
				SYSTEM.MOVE(ADDRESSOF(adr.ipv6Adr[i*4]), ADDRESSOF(swapTemp), 4);
				SwapEndian(swapTemp);
				SYSTEM.MOVE(ADDRESSOF(swapTemp), ADDRESSOF(adr.ipv6Adr[i*4]), 4);
			END;
		END;
		adr.usedProtocol := IPv6;

	ELSE
		IF DEBUG THEN
			ASSERT(TRUE);
		END;
		RETURN NilAdr;
	END;
	RETURN adr;
END ArrayToAdr;


(** Convert an Adr-type variable  into an array [ofs..ofs+x]
	Example in IPv4:
	If the LSB (least significant byte) should be stored the the
	beginning [ofs], LSBfirst must be set to TRUE.
		(address "a.b.c.d" is stored as [d,c,b,a])
	If the LSB should be stored at the end [ofs+3], LSBfirst must be set to FALSE.
		(address "a.b.c.d" is stored as [a,b,c,d])
*)
PROCEDURE AdrToArray*(adr: Adr; VAR array: ARRAY OF CHAR; ofs: LONGINT; LSBfirst: BOOLEAN);
VAR
	tempAdr: Adr;
	i, swapTemp: LONGINT;

BEGIN
	tempAdr := adr;

	CASE adr.usedProtocol OF
		IPv4:
			IF ~(ofs+4 <= LEN(array)) THEN
				tempAdr := NilAdr;
			END;

			IF LSBfirst THEN
				SwapEndian(tempAdr.ipv4Adr);
			END;
			SYSTEM.MOVE(ADDRESSOF(tempAdr.ipv4Adr), ADDRESSOF(array[ofs]), 4);

		| IPv6:
			IF ~(ofs + 16 <= LEN(array)) THEN
				tempAdr := NilAdr;
			END;

			IF LSBfirst THEN
				FOR i := 0 TO 3 DO
					SYSTEM.MOVE(ADDRESSOF(tempAdr.ipv6Adr[i*4]), ADDRESSOF(swapTemp), 4);
					SwapEndian(swapTemp);
					SYSTEM.MOVE(ADDRESSOF(swapTemp), ADDRESSOF(tempAdr.ipv6Adr[i*4]), 4);
				END;
			END;
			SYSTEM.MOVE(ADDRESSOF(adr.ipv6Adr), ADDRESSOF(array[ofs]), 16);
		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
	END;
END AdrToArray;


(** Reads the IP source address from a buffer *)
PROCEDURE SrcAdrFromBuffer* (buffer: Network.Buffer): Adr;
VAR
	i: LONGINT;
	adr: Adr;

BEGIN
	CASE ORD(buffer.data[buffer.l3ofs]) DIV 16 OF
		IPv4:
			adr.usedProtocol := IPv4;
			SYSTEM.MOVE(ADDRESSOF(buffer.data[buffer.l3ofs+12]),ADDRESSOF(adr.ipv4Adr),4); (*adr.ipv4Adr := SYSTEM.VAL(LONGINT, buffer.data[buffer.l3ofs+12]);*)
			SetIPv6AdrNil(adr);
			RETURN adr;

		|IPv6:
			adr.usedProtocol := IPv6;
			FOR i := 0 TO 15 DO
				adr.ipv6Adr[i] := buffer.data[buffer.l3ofs+8+i];
			END;
			adr.ipv4Adr := NilAdrIPv4;

		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
			RETURN NilAdr;
	END;
	RETURN NilAdr;
END SrcAdrFromBuffer;


(** Reads the IP destination address from a buffer *)
PROCEDURE DestAdrFromBuffer* (buffer: Network.Buffer): Adr;
VAR
	adr: Adr;
	i: LONGINT;

BEGIN
	CASE ORD(buffer.data[buffer.l3ofs]) DIV 16 OF
		IPv4:
			adr.usedProtocol := IPv4;
			SYSTEM.MOVE(ADDRESSOF(buffer.data[buffer.l3ofs+16]),ADDRESSOF(adr.ipv4Adr),4); (*adr.ipv4Adr := SYSTEM.VAL(LONGINT, buffer.data[buffer.l3ofs+16]);*)
			SetIPv6AdrNil(adr);
			RETURN adr;

		|IPv6:
			adr.usedProtocol := IPv6;
			FOR i := 0 TO 15 DO
				adr.ipv6Adr[i] := buffer.data[buffer.l3ofs+24+i];
			END;
			adr.ipv4Adr := NilAdrIPv4;

		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
			RETURN NilAdr;
	END;
	RETURN NilAdr;
END DestAdrFromBuffer;


(* Swap internal representation of an IP address from big to little endian or vice versa. *)
PROCEDURE -SwapEndian(VAR adr: LONGINT);
CODE
	LDR	R0, [FP, #adr]
	LDR	R1, [R0, #0]
	REV	R1, R1
	STR	R1, [R0, #0]
	ADD	SP, SP, #4
END SwapEndian;


(** Write an IP address. *)
PROCEDURE OutAdr*(adr: Adr);
VAR
	s: ARRAY 64 OF CHAR;

BEGIN
	AdrToStr(adr, s); KernelLog.String(s);
END OutAdr;


(** Enumerate all installed interfaces *)
PROCEDURE Enumerate*(handler: InterfaceHandler);
VAR item: Interface;
BEGIN
	item := interfaces;
	WHILE item # NIL DO
		handler(item);
		item := item.next;
	END;
END Enumerate;


(** Output the configuration of the specified interface. Can be used as Handler in Enumerate(). *)
PROCEDURE OutInterface*(interface: Interface);
BEGIN
	interface.OutInterface;
END OutInterface;


(** Aos command: Output statistics and configuration of all installed interfaces. *)
PROCEDURE IPConfig*(context : Commands.Context);
BEGIN
	context.out.String("Interfaces:"); context.out.Ln;
	context.out.String("----------------------"); context.out.Ln;
	Enumerate(OutInterface);
	context.out.Ln;
	context.out.String("IP statistics:"); context.out.Ln;
	context.out.String("----------------------"); context.out.Ln;
	context.out.String("NIPSentToSubnet"); context.out.Int(NIPSentToSubnet,10);context.out.Ln;
	context.out.String("NIPSentToGateway"); context.out.Int(NIPSentToGateway,10);context.out.Ln;
	context.out.String("NIPSentBroadcast"); context.out.Int(NIPSentBroadcast,10);context.out.Ln;
	context.out.String("NIPCantFragment"); context.out.Int(NIPCantFragment,10);context.out.Ln;
	context.out.String("NIPRcvTotal"); context.out.Int(NIPRcvTotal,10);context.out.Ln;
	context.out.String("NIPTooSmall"); context.out.Int(NIPTooSmall,10);context.out.Ln;
	context.out.String("NIPBadVersion"); context.out.Int(NIPBadVersion,10);context.out.Ln;
	context.out.String("NIPOptions"); context.out.Int(NIPOptions,10);context.out.Ln;
	context.out.String("NIPBadChecksum"); context.out.Int(NIPBadChecksum,10);context.out.Ln;
	context.out.String("NIPBadLength"); context.out.Int(NIPBadLength,10);context.out.Ln;
	context.out.String("NIPTrim"); context.out.Int(NIPTrim, 10);context.out.Ln;
	context.out.String("NIPBadHdrLen"); context.out.Int(NIPBadHdrLen,10);context.out.Ln;
	context.out.String("NIPNotForUs"); context.out.Int(NIPNotForUs,10);context.out.Ln;
	context.out.String("NIPCantReassemble"); context.out.Int(NIPCantReassemble,10);context.out.Ln;
	context.out.String("NIPSrcIsBroadcast"); context.out.Int(NIPSrcIsBroadcast,10);context.out.Ln;
	context.out.String("NIPDelivered"); context.out.Int(NIPDelivered,10);context.out.Ln;
	context.out.String("NIPNoReceiver"); context.out.Int(NIPNoReceiver,10);context.out.Ln;
	context.out.String("NIPForwarded"); context.out.Int(NIPForwarded,10);context.out.Ln;
	context.out.String("NIPSentLocalLoopback"); context.out.Int(NIPSentLocalLoopback,10);context.out.Ln;
	context.out.String("NIPSentPointToPoint"); context.out.Int(NIPSentPointToPoint,10);context.out.Ln; context.out.Ln;
END IPConfig;


(**
	First part of a split checksum operation. len must be non-zero and even. chk1 must be 0 at the
	beginning. The result can be passed to a following call to Checksum1(). The last chk1 result must
	be passed to Checksum2, which sums the data following sequentially on the data summed by this
	operation. Carries from bit 15 are accumulated in the top 16 bits, so at most 65535 words can be
	summed by Checksum1 and Checksum2 together. *)
PROCEDURE Checksum1*(CONST data: ARRAY OF CHAR; ofs, len, chk1: LONGINT): LONGINT;
CODE
	LDR R0, [FP, #chk1]
	LDR R1, [FP, #ofs]
	LDR R2, [FP, #len]
	LDR R3, [FP, #data] ; LDR R3, [FP, #20]
	ADD R3, R3, R1
	AND R4, R2, #1
	LSR R2, R2, #1 ; number of 16-bit words to process
	CMP R4, #0
	BEQ WordLoop
	SWI #8 ; ASSERT(~ODD(length))
WordLoop: ; sum up the words
	LDRH R4, [R3, #0]
	ADD R0, R0, R4
	ADD R3, R3, #2
	SUB R2, R2, #1
	CMP R2, #0
	BNE WordLoop
END Checksum1;

(**
	Continue a checksum operation. len can be zero or odd. chk1 can be the result of Checksum1 for
	the immediately preceding data, or 0 for contiguous data. *)
PROCEDURE Checksum2*(CONST data: ARRAY OF CHAR; ofs, len, chk1: LONGINT): INTEGER;
CODE
	LDR	R0, [FP, #chk1]
	LDR	R1, [FP, #20] ; LDR R1, [FP, #data]
	LDR	R2, [FP, #ofs]
	LDR	R3, [FP, #len]
	ADD	R1, R1, R2
	LSR	R4, R3, #1 ; number of 16-bit words to process
	CMP	R4, #0
	BEQ	Remainder
WordLoop: ; sum up the words
	LDRH	R5, [R1, #0]
	ADD	R0, R0, R5
	ADD	R1, R1, #2
	SUB	R4, R4, #1
	CMP	R4, #0
	BNE	WordLoop
	ANDS R5, R3, #1 ; if len is even
	BEQ WrapUp
Remainder: ; addition of the remaining byte
	LDRB	R5, [R1, #0]
	ADD	R0, R0, R5
WrapUp: ; 32-bit sum is in R0
	LDR	R7, [PC, #WordMask - $ - 8] ; load the 16-bit word mask
	LSR	R6, R0, 16 ; upper 16 bits of R0 is the carry
	AND	R0, R0, R7
	ADD	R0, R0, R6
	LSR	R6, R0, 16 ; upper 16 bits of R0 is the carry
	AND	R0, R0, R7
	ADD	R0, R0, R6
	EOR	R0, R0, R7 ; negate the bits of the resulted 16-bit word
	B		end
data:
	WordMask:	d32 0FFFFH
end:
END Checksum2;

(* Return TRUE if "adr1" and "adr2" are in the same subnet defined by "mask". Only for IPv4 *)
PROCEDURE -SameSubnetv4(adr1, adr2, mask: LONGINT): BOOLEAN;
CODE
	LDR		R0, [FP, #adr1]
	LDR		R1, [FP, #adr2]
	LDR		R2, [FP, #mask]
	AND		R0, R0, R2
	AND		R1, R1, R2
	CMP		R0, R1
	BNE false
	MOV		R0, #1
	B end
false:
	MOV		R0, #0
end:
	ADD		SP, SP, #12
END SameSubnetv4;


(* Return TRUE if adr matches the prefix *)
PROCEDURE MatchPrefix*(adr: Adr; prefix: Adr): BOOLEAN;
VAR
	bytesToCheck: LONGINT;
	bitsToCheck: LONGINT;
	i: LONGINT;
	matches: BOOLEAN;
	diffSet: SET;

BEGIN
	IF DEBUG THEN
		ASSERT ((IsNilAdr(adr)) OR (adr.usedProtocol = IPv6));
	END;

	matches := TRUE;

	bytesToCheck := prefix.data DIV 8;
	bitsToCheck := prefix.data MOD 8;

	FOR i := 0 TO bytesToCheck - 1 DO
		IF adr.ipv6Adr[i] # prefix.ipv6Adr[i] THEN
			matches := FALSE;
		END;
	END;

	IF bitsToCheck # 0 THEN
		diffSet := {};
		FOR i := 0 TO 8 - bitsToCheck - 1 DO
			diffSet := diffSet + {i};
		END;

		FOR i := 0 TO bitsToCheck - 1 DO
			IF (SYSTEM.VAL(SET, adr.ipv6Adr[bytesToCheck]) - diffSet) # (SYSTEM.VAL(SET, prefix.ipv6Adr[bytesToCheck]) - diffSet) THEN
				matches := FALSE;
			END;
		END;
	END;
	RETURN matches;
END MatchPrefix;


(** Return the interface on which packets with "dst" address should be sent. Return NIL if no interface matches. *)
PROCEDURE InterfaceByDstIP*(dest: Adr): Interface;
VAR
	item, gw: Interface;

BEGIN
	CASE dest.usedProtocol OF
		IPv4:
			gw := NIL;
			item := interfaces;
			LOOP
				IF item = NIL THEN EXIT END;
				IF (item.protocol = IPv4) & (~IsNilAdr(item.localAdr)) & (item.dev.Linked() # Network.LinkNotLinked) THEN
					IF SameSubnetv4(dest.ipv4Adr, item.subnetAdr.ipv4Adr, item.maskAdr.ipv4Adr) THEN
						EXIT;
					ELSIF (gw = NIL) & (~IsNilAdr(item.subnetAdr)) THEN
						IF item.protocol # IPv4 THEN
							gw := item;
						ELSIF ~IsNilAdr(item.gatewayAdr) THEN
							gw := item;
						END;
					END;
				END;
				item := item.next;
			END;
			IF item # NIL THEN
				RETURN item;
			ELSE
				RETURN gw;
			END;

		|IPv6:
			(* Requires special handling when multiple devices are present *)
			RETURN v6InterfaceByDstIP(dest);

		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
			RETURN NIL;
	END;
END InterfaceByDstIP;


(** Return the reference to an installed interface by its name. NIL is returned if no interface with this name
	was found. *)
PROCEDURE InterfaceByName*(CONST name: ARRAY OF CHAR): Interface;
VAR item: Interface;
BEGIN
	item := interfaces;
	WHILE (item # NIL) & (item.name # name) DO
		item := item.next;
	END;
	RETURN item;
END InterfaceByName;


(** Delivers first preferred (if possible) interface of an device.
	Return the reference to an installed interface by its device. NIL is returned if no interface with this
	device was found. *)
PROCEDURE InterfaceByDevice*(dev: Network.LinkDevice): Interface;
VAR
	item: Interface;
	unprefInt: Interface;
BEGIN
	unprefInt := NIL;
	item := interfaces;
	WHILE (item # NIL) DO
		IF item.dev = dev THEN
			IF item.protocol # preferredProtocol THEN
				unprefInt := item;
			ELSE
				RETURN item;
			END;
		END;
		item := item.next;
	END;
	(* return interface with unpreferred protocol or NIL *)
	RETURN unprefInt;
END InterfaceByDevice;


(** Return a list of installed interfaces of a certain device. *)
PROCEDURE InterfaceListByDevice* (dev: Network.LinkDevice):InterfaceList;
VAR
	item: Interface;
	interfaceList: InterfaceList;
	interfaceListItem: InterfaceList;

BEGIN
	item := interfaces;
	interfaceList := NIL;

	(* search for interfaces with matching device and put them in a list *)
	WHILE item # NIL DO
		IF item.dev = dev THEN
			NEW(interfaceListItem);
			interfaceListItem.interface := item;
			interfaceListItem.next := interfaceList;
			interfaceList := interfaceListItem;
		END;
		item := item.next;
	END;
	RETURN interfaceList;
END InterfaceListByDevice;


(** Install a receiver for a type. The type is stored in
	IPv4: Protocol field
	IPv6: Next header field *)
PROCEDURE InstallReceiver*( type: LONGINT; r: Receiver);
BEGIN {EXCLUSIVE}
	IF DEBUG THEN
		ASSERT(r # NIL);
		ASSERT((type >=0) & (type <= 255));
		ASSERT(receivers[type] = NIL);
	END;

	receivers[type] := r;
END InstallReceiver;


(** Remove the currently installed receiver for a type. The type is stored in
	IPv4: Protocol field
	IPv6: Next header field *)
PROCEDURE RemoveReceiver*(type: LONGINT);
BEGIN {EXCLUSIVE}
	ASSERT((type >=0) & (type <= 255));
	ASSERT(receivers[type] # NIL);

	receivers[type] := NIL;
END RemoveReceiver;


(** Checks if a string is a valid IPv4 address *)
PROCEDURE IsValidIPv4Str (CONST ipString: ARRAY OF CHAR): BOOLEAN;
VAR
	i,j: LONGINT;
	ipNr: LONGINT;
	digits: ARRAY 4 OF CHAR;
	startClass: LONGINT;
BEGIN
	i := 0;

	(* Class A *)
	WHILE (i < Strings.Length(ipString)) & (ipString[i] #'.') & (i < 3) DO
		digits[i] := ipString[i];
		INC (i);
	END;
	digits[i] := 0X;

	IF ipString[i] # '.' THEN RETURN FALSE END;

	(* Check if in digits are only numbers *)
	j := 0;
	WHILE digits[j] # 0X DO
		IF (ORD(digits[j]) - ORD("0")) > 9 THEN RETURN FALSE END;
		INC (j);
	END;
	Strings.StrToInt (digits, ipNr);
	IF ipNr > 255 THEN RETURN FALSE END;

	(* Class B *)
	INC(i);
	startClass := i;
	WHILE (i < Strings.Length(ipString)) & (ipString[i] # '.') & (i - startClass <= 3) DO
		digits[i-startClass] := ipString[i];
		INC (i);
	END;
	digits[i-startClass] := 0X;

	IF ipString[i] # '.' THEN RETURN FALSE END;

	(* Check if in digits are only number *)
	j := 0;
	WHILE digits[j] # 0X DO
		IF (ORD(digits[j]) - ORD("0")) > 9 THEN RETURN FALSE END;
		INC (j);
	END;
	Strings.StrToInt (digits, ipNr);
	IF ipNr > 255 THEN RETURN FALSE END;

	(* Class C *)
	INC(i);
	startClass := i;
	WHILE (i < Strings.Length (ipString)) & (ipString[i] # '.') & (i - startClass <= 3) DO
		digits[i-startClass] := ipString[i];
		INC (i);
	END;
	digits[i-startClass] := 0X;

	IF ipString[i] # '.' THEN RETURN FALSE END;

	(* Check if in digits are only number *)
	j := 0;
	WHILE digits[j] # 0X DO
		IF (ORD(digits[j]) - ORD("0")) > 9 THEN RETURN FALSE END;
		INC (j);
	END;
	Strings.StrToInt (digits, ipNr);
	IF ipNr > 255 THEN RETURN FALSE END;

	(* Class D *)
	INC(i);
	startClass := i;
	WHILE (i < Strings.Length (ipString)) & (i - startClass <= 3) DO
		digits[i-startClass] := ipString[i];
		INC (i);
	END;
	digits[i-startClass] := 0X;

	(* Check if in digits are only number *)
	j := 0;
	WHILE digits[j] # 0X DO
		IF (ORD(digits[j]) - ORD("0")) > 9 THEN RETURN FALSE END;
		INC (j);
	END;
	Strings.StrToInt (digits, ipNr);
	IF ipNr > 255 THEN RETURN FALSE END;

	RETURN TRUE;
END IsValidIPv4Str;


(** Checks if a string is a valid IPv6 address *)
PROCEDURE IsValidIPv6Str (ipString: ARRAY OF CHAR): BOOLEAN;
VAR
	i: LONGINT;
	state: LONGINT; (* -1: error *)
	charCount: LONGINT;
	ascD: LONGINT;
	ascH: LONGINT;
	dPointOcc: BOOLEAN;
	prefixLenArr: ARRAY 3 OF LONGINT;
	prefixLen: LONGINT;

BEGIN
	i := 0;
	state := 1;
	dPointOcc := FALSE;

	Strings.UpperCase(ipString);

	WHILE (i < (LEN(ipString) - 1)) & (ipString[i] # 0X) DO

		CASE state OF
			-1:
				RETURN FALSE;

			|1:
				(* 0-9 & A-F *)
				ascD := ORD(ipString[i]) - ORD("0");
				ascH := ORD(ipString[i]) - ORD("A");

				IF ((ascD >= 0) & (ascD <= 9)) OR ((ascH >= 0) & (ascH <= 5)) THEN
					INC(charCount);

					(* more than 4 digits between two : *)
					IF charCount > 4 THEN
						state := -1;
					END;

				(* : *)
				ELSIF ipString[i] = ":" THEN
					charCount := 0;
					state := 2;
				ELSIF ipString[i] = "/" THEN
					charCount := 0;
					state := 3;
				ELSE
					state := -1;
				END;

			|2:
				ascD := ORD(ipString[i]) - ORD("0");
				ascH := ORD(ipString[i]) - ORD("A");

				IF ipString[i] = ":" THEN
					IF dPointOcc THEN
						state := -1;
					ELSE
						dPointOcc := TRUE;
						state := 4;
					END

				ELSIF ((ascD >= 0) & (ascD <= 9)) OR ((ascH >= 0) & (ascH <= 5)) THEN
					INC(charCount);
					state := 1;
				ELSE
					state := -1;
				END;

			|3:
				ascD := ORD(ipString[i]) - ORD("0");

				IF ~((ascD >= 0) & (ascD <= 9)) THEN
					state := -1;
				ELSE
					IF charCount > 3 THEN
						state := -1;
					ELSE
						prefixLenArr[charCount] := ascD;
						INC(charCount);
					END;
				END;

			|4:
				ascD := ORD(ipString[i]) - ORD("0");
				ascH := ORD(ipString[i]) - ORD("A");

				IF ipString[i] = "/" THEN
					state := 3;
				ELSIF ((ascD >= 0) & (ascD <= 9)) OR ((ascH >= 0) & (ascH <= 5)) THEN
					INC(charCount);
					state := 1;
				ELSE
					state := -1;
				END;

			ELSE
				IF DEBUG THEN
					ASSERT(TRUE);
				END;
		END;
		INC(i);
	END;

	CASE state OF
		1:
			RETURN TRUE;

		|3:
			IF charCount > 0 THEN
				prefixLen := 0;
				FOR i:= 0 TO charCount - 1 DO
					prefixLen := prefixLen * 10;
					INC(prefixLen, prefixLenArr[i]);
				END;
				IF prefixLen <= 64 THEN
					RETURN TRUE;
				ELSE
					RETURN FALSE;
				END;
			ELSE
				RETURN FALSE;
			END;

		|4:
			RETURN TRUE;

		ELSE
			IF DEBUG THEN
				ASSERT(TRUE);
			END;
			RETURN FALSE;
	END;
	RETURN FALSE;
END IsValidIPv6Str;


(** Set IPv6 address to zero *)
PROCEDURE SetIPv6AdrNil (adr: Adr);
VAR
	i: LONGINT;

BEGIN
	FOR i := 0 TO 15 DO
		adr.ipv6Adr[i] := 0X;
	END;
END SetIPv6AdrNil;


(* Add the interface to the IP configuration. *)
PROCEDURE AddInterface*(int: Interface; VAR res: LONGINT);
VAR
	item: Interface;
BEGIN {EXCLUSIVE}
	item := interfaces;
	WHILE item # NIL DO
		(* Check if interface name already exists *)
		IF item.name = int.name THEN
			res := DuplicateInterfaceName;
			RETURN;
		END;
		item := item.next;
	END;
	(* Add interface *)
	int.next := interfaces;
	interfaces := int;
	res := Ok;
END AddInterface;


(* Remove the interface from the IP configuration. *)
PROCEDURE RemoveInterface*(int: Interface);
VAR
	item: Interface;

BEGIN {EXCLUSIVE}
	item := interfaces;
	IF item = NIL THEN
		(* empty list *)
	ELSIF item = int THEN
		(* remove first item *)
		interfaces := interfaces.next;
	ELSE
		WHILE item.next # int DO
			item := item.next;
		END;
		IF item.next # NIL THEN
			item.next := item.next.next;
		ELSE
			(* not found *)
		END;
	END;
END RemoveInterface;


(* Prints out a packet *)
PROCEDURE PacketOut*(CONST title, buffer: ARRAY OF CHAR; all: BOOLEAN);
VAR
	i: LONGINT;
	length: LONGINT;

BEGIN
	KernelLog.Ln;KernelLog.String("********************");KernelLog.Ln;
	KernelLog.String(title); KernelLog.Ln;

	IF all THEN
		length := LEN(buffer) -1;
	ELSE
		length := Strings.Min(LEN(buffer) - 1, 256);
	END;

	FOR i := 0 TO length DO
		IF (i MOD 4) = 0 THEN
			KernelLog.Ln;
			KernelLog.Int(i, 2);KernelLog.String(":  ");
		END;
		KernelLog.Hex(ORD(buffer[i]), -1);
		KernelLog.String(" ");
	END;

	KernelLog.Ln;KernelLog.String("********************");KernelLog.Ln;
END PacketOut;


BEGIN
	(* IPFowarding default value is FALSE *)
	IPForwarding := FALSE;

	(* EchoReply default value is TRUE *)
	EchoReply := TRUE;

	(* Initializations *)
	(* NilAdr *)
	NilAdr.ipv4Adr := NilAdrIPv4;
	SetIPv6AdrNil (NilAdr);
	NilAdr.usedProtocol := NilAdrIdent;

	(* Initialize receiver list *)
	FOR counter:=0 TO NbrOfReceivers-1 DO
		receivers[counter] := NIL;
	END;

	(* Initialize inteface list *)
	interfaces := NIL;
END IP.



Free:
SystemTools.Free TraceRoute VNC Ping WMFTPClient FTPClient WebFTPServer TCPServices TLS InitNetwork Ping DHCP TCP DNS UDP ICMP IPv4 IPv6 IP~

Start:
InitNetwork.Init

Compile:
PC.Compile \s IP.Mod IPv4.Mod IPv6.Mod ICMP.Mod UDP.Mod DNS.Mod TCP.Mod DHCP.Mod InitNetwork.Mod WebFTPServer.Mod FTPClient.Mod WMFTPClient.Mod Ping.Mod VNC.Mod TraceRoute.Mod~



History:
02.05.2005	eb	Supports IPv6 and fragmented IPv6 packets.




IsValidIPv6Str:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`

FSM used in IsValidIPv6Str:
-----------------------
EOS: end of string
	State 1: Initial state
			0-9/A-F goto state 1
			: goto state 2
			/ goto state 3
			EOS valid
	State 2:	0-9/A-F goto state 1
			: goto state 4
			EOS invalid
	State 3:	0-9 goto state 3
			EOS valid
	State 4:	/ goto state 3
			0-9/A-F goto state 1
			EOS valid

			