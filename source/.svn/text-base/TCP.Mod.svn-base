(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE TCP; (** AUTHOR "pjm, mvt"; PURPOSE "TCP protocol"; *)

(*
TCP - Transmission Control Protocol. Based on the 4.4BSD-Lite distribution described in Wright and Stevens, "TCP/IP Illustrated, Volume 2: The Implementation", ISBN 0-201-63354-X. See the BSD copyright statement at the end of this module. From that code it inherits some horrible control flow, which was left mostly intact, to make it easier to compare with the book.

	TCP Header

	00	16	source port
	02	16	destination port
	04	32	sequence number
	08	32	acknowledgement number
	12	08	header length & reserved
		07..04	header length (4-byte units)
		03..00	reserved
	13	08	flags
		07..06	reserved
		05..05	URG
		04..04	ACK
		03..03	PSH
		02..02	RST
		01..01	SYN
		00..00	FIN
	14	16	window size
	16	16	TCP checksum
	18	16	urgent pointer
	20	--	options (0-40 bytes)
	--	--	data

	TCP Pseudo-header (for checksum calculation)

	00	32	source address
	04	32	destination address
	08	08	zero = 0
	09	08	protocol = 17
	10	16	TCP length (duplicate)

	Notes:
	o Bit numbers above are Intel bit order.
	o Avoid use of SET because of PPC bit numbering issues.
	o Always access fields as 8-, 16- or 32-bit values and use DIV, MOD, ASH, ODD for bit access.


*)

IMPORT SYSTEM, Machine, KernelLog, Clock, Modules, Objects, Kernel, Commands, Network, IP, Streams, ActiveTimers, Strings;

CONST
	StrongChecks = FALSE;
	SystemMove = FALSE;

	TraceProtocol = FALSE;
	TraceError = FALSE;
	TracePacket = FALSE;
	TraceTimer = FALSE;
	TraceCongestion = FALSE;
	Trace = TraceProtocol OR TraceError OR TracePacket OR TraceTimer;

	HandleCongestion = TRUE;

	MinEphemeralPort = 1024;
	MaxEphemeralPort = 50000;
	HashTableSize = 1024 * 16; (* size of connection lookup hash table *)

	Acceptable = 500;	(* "backlog" on listening connections *)

	NilPort* = 0;

	(** Error codes *)
	Ok* = 0;
	ConnectionRefused* = 3701;
	ConnectionReset* = 3702;
	WrongInterface* = 3703;
	TimedOut* = 3704;
	NotConnected* = 3705;
	NoInterface* = 3706;
	InterfaceClosed* = 3707;

	MinError = 3700;
	MaxError = 3735;
	NumErrors = MaxError-MinError+1;

	(** TCP connection states *)
	NumStates* = 12;
	Closed* = 0;
	Listen* = 1;
	SynSent* = 2;
	SynReceived* = 3;
	Established* = 4;
	CloseWait* = 5;
	FinWait1* = 6;
	Closing* = 7;
	LastAck* = 8;
	FinWait2* = 9;
	TimeWait* = 10;
	Unused* = 11; (* no real state, only used in this implementation *)

	OpenStates* = {Listen, SynReceived, Established, CloseWait, FinWait1, FinWait2};
	ClosedStates* = {Unused, Closed, Closing, LastAck, TimeWait};
	HalfClosedStates* = ClosedStates + {FinWait1, FinWait2};
	FinStates* = {Unused, Closed, CloseWait, Closing, LastAck, TimeWait};

	Fin = 0; Syn = 1; Rst = 2; Psh = 3; Ack = 4; Urg = 5;	(* tcp header flags *)

	DoRFC1323 = TRUE; (* handle time stamp option (processing and generating) *)
	ProcOptions = TRUE; (* process TCP options *)
	GenOptions = TRUE; (* generate TCP options *)

	(* Flags in Connection *)
	AckNow = 0;	(* send Ack immediately *)
	DelAck = 1;	(* send Ack, but try to delay it *)
	NoDelay = 2;	(* don't delay packets tocoalesce (disable Nagle algorithm) *)
	SentFin = 3;	(* have sent Fin *)
	Force = 4;	(* force out a byte (persist/OOB) *)
	RcvdScale = 5;	(* set when other side sends window scale option in Syn *)
	RcvdTstmp = 6;	(* set when other side sends timestamp option in Syn *)
	ReqScale = 7;	(* have/will request window scale option in Syn *)
	ReqTstmp = 8;	(* have/will request timestamp option in Syn *)
	DoKeepAlive = 9;	(* enable keep-alive timer *)
	AcceptConn = 10;	(* listening for incoming connections *)
	(*Notify = 11;*)	(* socket wakeup *)
	(*Gone = 12;*)	(* SS_NOFDREF *)
	(*NoMore = 13;*)	(* SS_CANTRCVMORE *)
	Timeout = 14;

	NumTimers = 4;
	ReXmt = 0; Persist = 1; Keep = 2; MSL2 = 3;

	FastPeriod = 5;	(* number of fast ticks per second *)
	SlowPeriod = 2;	(* number of slow ticks per second *)
	TimerPeriod = 10;	(* timer ticks per second *)
	MinTime = 1*SlowPeriod;	(* minimum allowable time value *)
	ReXmtMax = 64*SlowPeriod;	(* max allowable ReXmt value *)

	ReXmtThresh = 3;

	KeepInit = 75*SlowPeriod;	(* connection establishment timer value (75s) *)
	KeepIntvl = 75*SlowPeriod;	(* time between probes when no response (75s) *)
	KeepIdle = 2*60*60*SlowPeriod;	(* default time before probing (2h) *)
	KeepCnt = 8;	(* max probes before drop *)
	MaxIdle = KeepCnt * KeepIntvl;	(* max time to send keepalive probes (10min) *)
	MSL = 30*SlowPeriod;	(* max segment lifetime (30s) *)
	MaxPersistIdle = KeepIdle;	(* max time to keep dead/unreachable connections (2h) *)


	PawsIdle = 24*24*60*60*SlowPeriod;

	SRTTBase = 0;	(* base round trip time *)
	SRTTDflt = 3*SlowPeriod;	(* assumed RTT if no info *)
	RTTShift = 3;
	RTTVarShift = 2;

	PersMin = 5*SlowPeriod;	(* retransmit persistance *)
	PersMax = 60*SlowPeriod;	(* maximum persist interval *)

	MSS = 536-12; (* maximum segment size for outgoing segments, 12 = size of timestamp option *)

	MaxRxtShift = 12;	(* maximum retransmits *)

	MaxWin = 65535;	(* largest value for (unscaled) window *)
	MaxWinShift = 14;	(* maximum window shift *)

	MaxSendSpace = 80000H; (* 512KB, max. 1023MB *)
	MaxRecvSpace = 80000H; (* 512KB, max. 1023MB *)

	SegsPerBuf = 4;	(* number of mss segments per send buffer (potential fragmentation waste is 1/SegsPerBuf) *)

	ISSInc = 128000;	(* increment for iss each second *)

	IPTypeTCP = 6; (* TCP type code for IP packets *)

	MinTCPHdrLen = 20;
	MaxTCPHdrLen = 60;
	MaxPseudoHdrLen = 40; (* IPv4 = 12; IPv6 = 40 *)

	NewZeros = FALSE;	(* NEW initializes allocated object fields to 0 *)

	BroadcastReceived = 3708;
	InvalidParameter = 3709;
	AllPortsInUse = 3710;
	AddressInUse = 3711;
	DuplicateSegment = 3712;
	DuplicatePartialSegment = 3713;
	DuplicateSegmentPAWS = 3714;
	DataBeyondWindow1 = 3715;
	DataBeyondWindow2 = 3716;
	DataBeyondWindow3 = 3717;
	BadChecksum = 3718;
	DuplicateAck = 3719;
	OutOfRangeAck = 3720;
	TimeOutKeepAlive = 3721;
	TimeoutEstablished = 3722;
	SegmentTooBig = 3723;
	SegmentTooSmall = 3724;
	BadHeaderLength = 3725;
	ConnectionGone = 3726;
	NIYNewIncarnation = 3727;
	NIYOutOfBand = 3728;
	NIYMSS = 3729;
	ConnectionAborted = 3730;
	NotInitialized = 3731;
	DataDuplicatePrevComplete = 3732;
	DataDuplicatePrevPartial = 3733;
	DataDuplicateNextComplete = 3734;
	DataDuplicateNextPartial = 3735;

TYPE
	(* Send buffer types *)
	SendData = IP.Packet;

	SendBuffer = POINTER TO RECORD
		next: SendBuffer;
		ofs, len: LONGINT;	(* data[ofs..ofs+len-1] is valid *)
		seq: LONGINT;	(* sequence number of byte data[ofs] (only valid if len # 0) *)
		pf: SET;	(* flags of segment *)
		data: SendData	(* size should be multiple of maxseg *)
	END;

TYPE
	ISS = OBJECT
		VAR iss: LONGINT;	(* next iss to use *)

		PROCEDURE Update(hz: LONGINT);
		BEGIN {EXCLUSIVE}
			INC(iss, ISSInc DIV hz)
		END Update;

		PROCEDURE Get(): LONGINT;
		VAR t: LONGINT;
		BEGIN {EXCLUSIVE}
			t := iss; INC(iss, ISSInc);
			RETURN t
		END Get;

		PROCEDURE &Init*(iss: LONGINT);
		BEGIN
			SELF.iss := iss
		END Init;
	END ISS;

TYPE
	Timer = OBJECT	(* temporary *)
		VAR
			lastFast, lastSlow: LONGINT;	(* time of last execution *)
			(*lastTrace: LONGINT;*)
			now: LONGINT;	(* current tcp "time" - read from other procedures, but only updated inside this object *)
			timer: ActiveTimers.Timer;

		PROCEDURE CallDelayedAck(p: Connection);
		BEGIN
			p.DelayedAck();
		END CallDelayedAck;

		PROCEDURE CallSlowTimer(p: Connection);
		BEGIN
			p.SlowTimer();
		END CallSlowTimer;

		PROCEDURE HandleTimeout;
		VAR t: LONGINT;
		BEGIN {EXCLUSIVE}
			t := Kernel.GetTicks();
			IF t - lastFast >= Kernel.second DIV FastPeriod THEN
				lastFast := t;
				pool.Enumerate(CallDelayedAck);
			END;
			IF t - lastSlow >= Kernel.second DIV SlowPeriod THEN
				lastSlow := t;
				pool.Enumerate(CallSlowTimer);
				issSource.Update(SlowPeriod);
				INC(now)
			END;
			timer.SetTimeout(HandleTimeout, Kernel.second DIV TimerPeriod)
		END HandleTimeout;

		(* Finalize timer by cancelling it *)

		PROCEDURE Finalize;
		BEGIN {EXCLUSIVE}
			timer.Finalize
		END Finalize;

		PROCEDURE &Init*;
		BEGIN
			now := 0;
			lastSlow := Kernel.GetTicks() - Kernel.second;
			lastFast := lastSlow; (*lastTrace := lastSlow;*)
			NEW(timer);
			timer.SetTimeout(HandleTimeout, Kernel.second DIV TimerPeriod)
		END Init;

	END Timer;

TYPE
	(** Connection object.
		NOTE: Only one process should access a Connection!
	*)
	Connection* = OBJECT(Streams.Connection)
		VAR
			poolNext, parent, acceptNext: Connection;
			(* assigned interface *)
			int-: IP.Interface;
			(* local protocol address *)
			lport-: LONGINT;
			(* foreign protocol address *)
			fip-: IP.Adr;
			fport-: LONGINT;
			state*: SHORTINT;	(* TCP state *)
			timer: ARRAY NumTimers OF LONGINT;
			rxtshift-: LONGINT;	(* log(2) of rexmt exponential backoff *)
			rxtcur-: LONGINT;	(* current retransmission timeout (ticks) *)
			dupacks-: LONGINT;	(* number of consequtive duplicate acks received *)
			maxseg-: LONGINT;	(* maximum segment size to send *)
			flags: SET;	(* various connection and buffer flags *)
			error: LONGINT;	(* error on connection (socket error) *)
			acceptable: LONGINT;	(* number of connections that can be before acceptance *)
				(* send sequence *)
			snduna-: LONGINT;	(* send unacknowledged *)
			sndnxt-: LONGINT;	(* send next *)
			sndup: LONGINT;	(* send urgent pointer *)
			sndwl1-: LONGINT;	(* window update seg seq number *)
			sndwl2-: LONGINT;	(* window update seg ack number *)
			iss-: LONGINT;	(* initial send sequence number *)
			sndwnd-: LONGINT;	(* send window *)
			sndmax-: LONGINT;	(* highest sequence number sent - used to recognize retransmits *)
				(* receive sequence *)
			rcvwnd-: LONGINT;	(* receive window *)
			rcvnxt-: LONGINT;	(* receive next *)
			rcvup: LONGINT;	(* receive urgent pointer *)
			irs-: LONGINT;	(* initial receive sequence number *)
			rcvadv-: LONGINT;	(* advertised window by other end *)
				(* congestion control *)
			sndcwnd-: LONGINT;	(* congestion-controlled window *)
			sndssthresh-: LONGINT;	(* sndcwnd threshold for slow start - exponential to linear switch *)
				(* transmit timing *)
			idle-: LONGINT;	(* inactivity time *)
			rtt-: LONGINT;	(* round trip time *)
			rtseq-: LONGINT;	(* sequence number being timed *)
			srtt-: LONGINT;	(* smoothed round trip time *)
			rttvar-: LONGINT;	(* variance in round trip time *)
			rttmin-: LONGINT;	(* minimum rtt allowed *)
			maxsndwnd: LONGINT;	(* largest window peer has offered *)
				(* RFC 1323 *)
			sndscale: LONGINT;	(* scaling for send window (0-14) *)
			rcvscale: LONGINT;	(* scaling for receive window (0-14) *)
			requestrscale: LONGINT;	(* our pending window scale *)
			requestedsscale: LONGINT;	(* peer's pending window scale *)
			tsrecent: LONGINT;	(* timestamp echo data *)
			tsrecentage: LONGINT;	(* when last updated *)
			lastacksent-: LONGINT;	(* sequence number of last ack field *)
				(* send buffer *)
			sndcc-: LONGINT;	(* number of bytes in send buffer *)
			sndspace-: LONGINT;	(* number of bytes that may still be added before buffer is full *)
			sndhead, sndtail: SendBuffer;	(* queue of segments (contiguous and in order) *)
			sndcontig: SendData;	(* maxseg size buffer to make data contiguous *)
				(* receive buffer *)
			rcvspace-: LONGINT;	(* number of bytes that may still be received before buffer is considered full *)
			rcvhiwat-: LONGINT;	(* receive high water mark (MaxRecvSpace) *)
			rcvhead, rcvreasm, rcvtail: Network.Buffer;	(* queue of segments - see description at the beginning of this file *)
			rcvheadFragment: Network.Buffer; (* current fragment of rcvhead *)
			timeout: ActiveTimers.Timer;
			traceflow-: LONGINT;

		(* Initialization for internal use only. *)
		PROCEDURE &Init*;
		BEGIN
			state := Unused;
		END Init;

		(** Open a TCP connection (only use once per Connection instance).
			Use TCP.NilPort for lport to automatically assign an unused local port.
		*)
		PROCEDURE Open*(lport: LONGINT; fip: IP.Adr; fport: LONGINT; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT((state = Unused) & (lport >= 0) & (lport < 10000H) & (fport >= 0) & (fport < 10000H));
			IF timeSource # NIL THEN
				InitConnection(SELF);
				IF (~IP.IsNilAdr(fip)) & (fport # NilPort) THEN
					(* active open (connect) *)
					int := IP.InterfaceByDstIP(fip);
					IF int # NIL THEN
						SELF.fip := fip;
						pool.Add(SELF, lport, fport, res); (* add connection to connection pool *)
						IF res = Ok THEN	(* address assignment ok, now start the connection *)
							Machine.AtomicInc(NTCPConnectAttempt);
							state := SynSent; timer[Keep] := KeepInit;
							iss := issSource.Get();
							snduna := iss; sndnxt := iss; sndmax := iss; sndup := iss;
							Output(SELF)
						END;
					ELSE
						res := NoInterface;
					END;
				ELSE
					(* passive open (listen) *)
					ASSERT((fport = NilPort) & (IP.IsNilAdr(fip)));
					SELF.int := NIL;
					SELF.fip := IP.NilAdr;
					pool.Add(SELF, lport, NilPort, res);
					IF res = Ok THEN
						INCL(flags, AcceptConn);
						acceptable := Acceptable;
						state := Listen;
					END
				END;
				IF TraceProtocol THEN
					TraceTCP("Open", SELF, empty^, empty^, 0, 0, 0)
				END
			ELSE
				res := NotInitialized;
			END
		END Open;


		(** Send data on a TCP connection. *)
		PROCEDURE Send*(CONST data: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR buf: SendBuffer; len0: LONGINT;
		BEGIN {EXCLUSIVE}
			IF StrongChecks THEN Invariant(SELF) END;
			ASSERT(ofs+len <= LEN(data));	(* index check *)
			LOOP
				IF len <= 0 THEN EXIT END;
				IF len <= maxseg THEN len0 := len ELSE len0 := maxseg END;
				IF ~((state IN {Established, CloseWait}) & (sndspace >= len0)) THEN	(* can not send immediately *)
					AWAIT(((state IN {Established, CloseWait}) & (sndspace >= len0)) OR ~(state IN {SynSent..CloseWait}));
					IF StrongChecks THEN Invariant(SELF) END;
					IF ~(state IN {SynSent..CloseWait}) THEN	(* connection broken *)
						IF error # Ok THEN res := error ELSE res := NotConnected END;
						RETURN
					END
				END;
				buf := sndtail;
				IF LEN(buf.data^) - (buf.ofs+buf.len) >= len0 THEN	(* last buffer has space for data *)
					IF SystemMove THEN
						SYSTEM.MOVE(ADDRESSOF(data[ofs]), ADDRESSOF(buf.data[buf.ofs+buf.len]), len0)
					ELSE
						Network.Copy(data, buf.data^, ofs, buf.ofs+buf.len, len0)
					END;
					INC(buf.len, len0)
				ELSE	(* last buffer has no space for data *)
					buf := buf.next;
					IF buf # sndhead THEN	(* is free buffer *)
						ASSERT((buf.ofs = 0) & (buf.len = 0));	(* buffer must be unused *)
						ASSERT(LEN(buf.data^) >= len0)	(* index check *)
					ELSE
						Machine.AtomicInc(NTCPNewBufs);
						NEW(buf); NEW(buf.data, MSS * SegsPerBuf);
						IF ~NewZeros THEN buf.ofs := 0; END;
						buf.next := sndtail.next; sndtail.next := buf;
						ASSERT(LEN(buf.data^) >= len0)	(* index check *)
					END;
					IF SystemMove THEN
						SYSTEM.MOVE(ADDRESSOF(data[ofs]), ADDRESSOF(buf.data[0]), len0)
					ELSE
						Network.Copy(data, buf.data^, ofs, 0, len0)
					END;
					buf.len := len0; sndtail := buf
				END;
				INC(sndcc, len0); DEC(sndspace, len0);
				Output(SELF);
				INC(ofs, len0); DEC(len, len0)
			END;
			IF TraceProtocol THEN
				TraceTCP("Send", SELF, empty^, data, 0, ofs, len)
			END;
			res := Ok
		END Send;


		(** Receive data on a TCP connection. The data parameter specifies the buffer. The ofs parameters specify the position in the buffer where data should be received (usually 0), and the size parameters specifies how many bytes of data can be received in the buffer. The min parameter specifies the minimum number of bytes to receive before Receive returns and must by <= size. The len parameter returns the number of bytes received, and the res parameter returns 0 if ok, or a non-zero error code otherwise (e.g. if the connection is closed by the communication partner, or by a call of the Close method). *)
		PROCEDURE Receive*(VAR data: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
		VAR
			buf: Network.Buffer;
			rlen: LONGINT;

		BEGIN {EXCLUSIVE}
			IF StrongChecks THEN Invariant(SELF) END;
			ASSERT((ofs >= 0) & (ofs+size <= LEN(data)) & (min <= size));	(* parameter consistency check *)
			len := 0;
			LOOP
				WHILE (rcvhead # NIL) & (rcvhead # rcvreasm) & (size > 0) DO
					IF rcvhead.nextFragment = NIL THEN
						(* read all available data until user buffer is full *)
						rlen := Strings.Min(rcvhead.len, size);
						IF SystemMove THEN
							SYSTEM.MOVE(ADDRESSOF(rcvhead.data[rcvhead.ofs]), ADDRESSOF(data[ofs]), rlen);
						ELSE
							Network.Copy(rcvhead.data, data, rcvhead.ofs, ofs, rlen);
						END;
						INC(len, rlen);
						INC(ofs, rlen);
						DEC(size, rlen);
						INC(rcvhead.ofs, rlen);
						DEC(rcvhead.len, rlen);
						INC(rcvhead.int, rlen);
						INC(rcvspace, rlen);
						IF rcvhead.len = 0 THEN
							(* go to next buffer *)
							buf := rcvhead;
							rcvhead := rcvhead.next;
							IF rcvhead # NIL THEN
								rcvhead.prev := NIL;
							END;
							Network.ReturnBuffer(buf);
							Output(SELF); (* enable sending window update segment *)
						END;
					ELSE
						(* rcvhead has fragments *)
						(* read all available data until user buffer is full *)
						IF rcvheadFragment = NIL THEN
							rcvheadFragment := rcvhead;
						END;
						rlen := Strings.Min(rcvheadFragment.len, size);
						IF SystemMove THEN
							SYSTEM.MOVE(ADDRESSOF(rcvheadFragment.data[rcvheadFragment.ofs]), ADDRESSOF(data[ofs]), rlen);
						ELSE
							Network.Copy(rcvheadFragment.data, data, rcvheadFragment.ofs, ofs, rlen);
						END;
						INC(len, rlen);
						INC(ofs, rlen);
						DEC(size, rlen);
						INC(rcvheadFragment.ofs, rlen);
						DEC(rcvheadFragment.len, rlen);
						INC(rcvheadFragment.int, rlen);
						INC(rcvspace, rlen);
						IF rcvheadFragment.len = 0 THEN
							IF rcvheadFragment.nextFragment # NIL THEN
								(* go to next fragment *)
								rcvheadFragment := rcvheadFragment.nextFragment;
							ELSE
								(* go to next buffer *)
								buf := rcvhead;
								rcvhead := rcvhead.next;
								IF rcvhead # NIL THEN
									rcvhead.prev := NIL;
								END;
								Network.ReturnBuffer(buf);
								Output(SELF); (* enable sending window update segment *)
							END;
						END;

					END;
				END;
				IF size = 0 THEN
					(* user buffer full *)
					EXIT;
				END;
				IF len >= min THEN
					(* enough was read *)
					EXIT;
				ELSE
					(* await available data or closed connection state *)
					AWAIT(((rcvhead # NIL) & (rcvhead # rcvreasm)) OR ~(state IN {SynSent, SynReceived, Established, FinWait1, FinWait2}));
					IF StrongChecks THEN Invariant(SELF) END;
					IF (rcvhead # NIL) & (rcvhead # rcvreasm) THEN
						(* new data available, start again with LOOP *)
					ELSE
						(* no data available, and no more can arrive, as we've seen the FIN *)
						IF error # Ok THEN res := error ELSE res := Streams.EOF (* end of file *) END;
						RETURN;
					END;
				END;
			END;
			IF StrongChecks THEN Invariant(SELF) END;
			IF TraceProtocol THEN
				TraceTCP("Receive", SELF, empty^, data, 0, ofs, len)
			END;
			res := Ok
		END Receive;


		(** Enable or disable delayed send (Nagle algorithm).
			If enabled, the sending of a segment is delayed if it is not filled by one call to Send, in order to be able to be filled
			by further calls to Send. This is the default option.
			If disabled, a segment is sent immediatly after a call to Send, even if it is not filled. This option is normally chosen
			by applications like telnet or VNC client, which send verly little data but shall not be delayed.
		*)
		PROCEDURE DelaySend*(enable: BOOLEAN);
		BEGIN {EXCLUSIVE}
			IF enable THEN
				EXCL(flags, NoDelay);
			ELSE
				INCL(flags, NoDelay);
			END;
		END DelaySend;


		(** Enable or disable keep-alive. (default: disabled) *)
		PROCEDURE KeepAlive*(enable: BOOLEAN);
		BEGIN {EXCLUSIVE}
			IF enable THEN
				INCL(flags, DoKeepAlive);
			ELSE
				EXCL(flags, DoKeepAlive);
			END;
		END KeepAlive;


		(** Return number of bytes that may be read without blocking. *)
		PROCEDURE Available*(): LONGINT;
		VAR
			len: LONGINT;
			item: Network.Buffer;
			fragmentBuffer: Network.Buffer;
			reassembledLength: LONGINT;

		BEGIN {EXCLUSIVE}
			len := 0;
			item := rcvhead;
			WHILE(item # NIL) & (item # rcvreasm) DO
				IF item.nextFragment # NIL THEN
					INC(len, item.len);
				ELSE
					(* fragmented packet *)
					fragmentBuffer := item;
					reassembledLength := 0;
					WHILE fragmentBuffer # NIL DO
						INC(len, fragmentBuffer.len);
						fragmentBuffer := fragmentBuffer.nextFragment;
					END;
				END;
				item := item.next;
			END;
			RETURN len;
		END Available;


		(** Return connection state. *)
		PROCEDURE State*(): LONGINT;
		BEGIN {EXCLUSIVE}
			IF (state IN FinStates) & (rcvhead # NIL) & (rcvhead.len # 0) THEN	(* workaround for client errors *)
				IF state = CloseWait THEN	(* act as if we haven't seen a FIN yet *)
					RETURN Established
				ELSE
					RETURN FinWait1
				END
			ELSE
				RETURN state
			END
		END State;


		(** Wait until the connection state is either in the good or bad set, up to "ms" milliseconds. *)
		PROCEDURE AwaitState*(good, bad: SET; ms: LONGINT; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			IF ~(state IN (good+bad)) THEN
				IF ms # -1 THEN
					IF timeout = NIL THEN NEW(timeout) END;
					timeout.SetTimeout(SELF.HandleTimeout, ms);
				END;
				EXCL(flags, Timeout);
				AWAIT((state IN (good+bad)) OR (Timeout IN flags));
				IF ms # -1 THEN timeout.CancelTimeout(); END
			END;
			IF state IN good THEN
				res := Ok
			ELSIF state IN bad THEN
				res := NotConnected
			ELSE
				res := TimedOut
			END
		END AwaitState;

		PROCEDURE HandleTimeout;
		BEGIN {EXCLUSIVE}
			INCL(flags, Timeout)
		END HandleTimeout;

		(** Close a TCP connection (half-close). *)
		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			IF state < Established THEN
				CloseConnection(SELF)
			ELSIF FALSE (* linger *) THEN
				Drop(SELF, 0)
			ELSE
				UsrClosed(SELF);
				IF state # Closed THEN Output(SELF) END
			END;
			IF TraceProtocol THEN
				TraceTCP("Close", SELF, empty^, empty^, 0, 0, 0)
			END
		END Close;


		(** Discard a TCP connection (shutdown). *)
		PROCEDURE Discard*;
		BEGIN {EXCLUSIVE}
			IF state < Established THEN
				CloseConnection(SELF)
			ELSE
				Drop(SELF, ConnectionReset)	(* ??? *)
			END;
			IF TraceProtocol THEN
				TraceTCP("Discard", SELF, empty^, empty^, 0, 0, 0)
			END
		END Discard;


		(** Accept a client waiting on a listening connection. Blocks until a client is available or the connection is closed. *)
		PROCEDURE Accept*(VAR client: Connection; VAR res: LONGINT);
		BEGIN {EXCLUSIVE}
			AWAIT((state # Listen) OR (acceptNext # NIL));
			IF acceptNext # NIL THEN
				client := acceptNext; acceptNext := acceptNext.acceptNext;
				INC(acceptable); res := Ok
			ELSE
				client := NIL; res := ConnectionRefused
			END
		END Accept;


		(** Return TRUE iff a listening connection has clients waiting to be accepted. *)
		PROCEDURE Requested*(): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN (state = Listen) & (acceptNext # NIL)
		END Requested;


		(* Process a received segment for the current Connection. *)
		PROCEDURE Input(int: IP.Interface; fip: IP.Adr; hdrLen: LONGINT; buffer: Network.Buffer);
		VAR
			bufferQueued: BOOLEAN; (* was buffer queued by ProcessInput() ? *)
			p: Connection;

		BEGIN {EXCLUSIVE}
			(* to do: move header prediction code here *)
			IF StrongChecks THEN Invariant(SELF) END;
			bufferQueued := FALSE;
			IF AcceptConn IN flags THEN
				IF acceptable > 0 THEN
					NEW(p); InitConnection(p);	(* fig. 28.7 *)
					p.int := int;
					p.fip := fip;
					p.state := Listen; p.parent := SELF;
					ProcessInput(p, hdrLen, buffer, TRUE, bufferQueued);
					IF p.state = SynReceived THEN	(* packet was accepted *)
						DEC(acceptable)	(* limit number of "temporary" Connections *)
					END
				ELSE
					Machine.AtomicInc(NTCPUnacceptable)
				END
			ELSE
				IF SELF = nilpcb THEN
					(* set info for "Respond" *)
					SELF.int := int;
					SELF.fport := Network.GetNet2(buffer.data, buffer.ofs);
					SELF.lport := Network.GetNet2(buffer.data, buffer.ofs+2);
				END;
				IF SELF.int # int THEN
					(* packet must be received by interface attached to this connection *)
					Error(WrongInterface, 0, SELF);
				ELSE
					SELF.fip := fip;
					ProcessInput(SELF, hdrLen, buffer, FALSE, bufferQueued);
				END;
			END;
			IF StrongChecks THEN Invariant(SELF) END;
			IF ~bufferQueued THEN
				Network.ReturnBuffer(buffer);
			END;
		END Input;


		(* Schedule a delayed ack. *)
		PROCEDURE DelayedAck;
		BEGIN {EXCLUSIVE}
			IF StrongChecks THEN Invariant(SELF) END;
			IF DelAck IN flags THEN
				flags := (flags - {DelAck}) + {AckNow};
				Machine.AtomicInc(NTCPDelAck);
				Output(SELF)
			END
		END DelayedAck;


		(* Schedule a slow timer event (fig. 25.8). *)
		PROCEDURE SlowTimer;
		VAR dropit: BOOLEAN;
			oldie: LONGINT;
		BEGIN {EXCLUSIVE}
			oldie := sndnxt;
			IF StrongChecks THEN Invariant(SELF) END;

			IF Expired(timer[ReXmt]) THEN	(* fig. 25.26 *)
				INC(rxtshift);
				IF rxtshift > MaxRxtShift THEN
					rxtshift := MaxRxtShift; Error(TimedOut, 0, SELF); Drop(SELF, TimedOut)
				ELSE
					Machine.AtomicInc(NTCPReXmtTimer);
					RangeSet(rxtcur, (ASH(srtt, -RTTShift) + rttvar) * backoff[rxtshift], rttmin, ReXmtMax);
					timer[ReXmt] := rxtcur;
					IF rxtshift > MaxRxtShift DIV 4 THEN
						(* to do: drop current route *)
						INC(rttvar, ASH(srtt, -RTTShift));
						srtt := 0
					END;
					sndnxt := snduna; rtt := 0;
					sndcwnd := maxseg; dupacks := 0;
					sndssthresh := Strings.Max(Strings.Min(sndwnd, sndcwnd) DIV 2 DIV maxseg, 2) * maxseg;
					IF TraceCongestion THEN
						KernelLog.String("ST sndssthresh := "); KernelLog.Int(sndssthresh, 1); KernelLog.Ln
					END;
					Output(SELF)
				END
			END;

			IF Expired(timer[Persist]) THEN	(* fig. 25.13 *)
				Machine.AtomicInc(NTCPPersistTimer);
				IF (rxtshift = MaxRxtShift) & ((idle >= MaxPersistIdle) OR (idle >= (ASH(srtt, -RTTShift) + rttvar) * totbackoff)) THEN
					Machine.AtomicInc(NTCPPersistDrop);	(* vol. 3 fig. 14.17 *)
					Drop(SELF, TimedOut)
				ELSE
					SetPersist(SELF); INCL(flags, Force); Output(SELF); EXCL(flags, Force)
				END
			END;

			traceflow := 0;

			IF Expired(timer[Keep]) THEN	(* fig. 25.16 *)
				Machine.AtomicInc(NTCPKeepTimer); dropit := FALSE;
				IF state >= Established THEN
					IF (DoKeepAlive IN flags) & (state <= CloseWait) THEN
						IF idle < KeepIdle + MaxIdle THEN
							traceflow := 1;
							Machine.AtomicInc(NTCPKeepProbe);
							Respond(SELF, rcvnxt, snduna-1, {});
							timer[Keep] := KeepIntvl
						ELSE
							traceflow := 2;
							dropit := TRUE; Error(TimeOutKeepAlive, 0, SELF)
						END
					ELSE
						traceflow := 3;
						timer[Keep] := KeepIdle
					END
				ELSE
					traceflow := 4;
					dropit := TRUE; Error(TimeoutEstablished, 0, SELF)
				END;
				IF dropit THEN Drop(SELF, TimedOut) END
			END;

			IF Expired(timer[MSL2]) THEN	(* fig. 25.10 *)
				IF (state # TimeWait) & (idle <= MaxIdle) THEN
					timer[MSL2] := KeepIntvl
				ELSE
					IF state = FinWait2 THEN Machine.AtomicInc(NTCPFinWait2Timer) ELSE Machine.AtomicInc(NTCPTimeWaitTimer) END;
					CloseConnection(SELF)
				END
			END;

			INC(idle);
			IF rtt # 0 THEN INC(rtt) END;
			(* check if interface wasn't closed/removed in meantime *)
			IF (int # NIL) & (int.closed) THEN
				Drop(SELF, InterfaceClosed);
			END;
		END SlowTimer;

		(* Finalize the Connection object *)

		PROCEDURE Finalize;
		BEGIN
			IF timeout # NIL THEN timeout.Finalize; END;
			Discard();
		END Finalize;

	END Connection;

TYPE
	ConnectionHandler* = PROCEDURE {DELEGATE} (p: Connection);

	ConnectionPool* = OBJECT
		VAR
			eport: LONGINT;
			table: ARRAY HashTableSize OF Connection;

		(* Initialization for internal use only. *)

		PROCEDURE &Init*;
		VAR i: LONGINT;
		BEGIN
			FOR i:= 0 TO HashTableSize-1 DO
				table[i] := NIL;
			END;
			eport := MinEphemeralPort;
		END Init;

		(* Finalize all connections in this pool *)

		PROCEDURE Finalize;
		VAR i: LONGINT;
		BEGIN
			FOR i:= 0 TO HashTableSize-1 DO
				WHILE table[i] # NIL DO
					table[i].Finalize();
				END;
			END;
		END Finalize;

		(* Look for the specified Connection. *)

		PROCEDURE Lookup(lport, fport: LONGINT; fip: IP.Adr): Connection;
		VAR
			item: Connection;

		BEGIN
			item := table[HashPool(lport, fport, fip)];
			WHILE (item # NIL) & ((~IP.AdrsEqual(item.fip, fip)) OR (item.fport # fport) OR (item.lport # lport)) DO
				item := item.poolNext;
			END;

			IF item = NIL THEN
				RETURN nilpcb;
			ELSE
				RETURN item;
			END;
		END Lookup;

		(** Enumerate all Connections. Only for tracing, due to concurrent updates data may be stale. *)

		PROCEDURE Enumerate*(handle: ConnectionHandler);
		VAR
			i: LONGINT;
			item: Connection;
		BEGIN
			FOR i:= 0 TO HashTableSize-1 DO
				item := table[i];
				WHILE item # NIL DO
					handle(item);
					item := item.poolNext;
				END;
			END;
		END Enumerate;

		(* Add the connection p to the pool (attach). Assumes the caller has exclusive access to p.
			IF (fport = NilPort) & (fip = IP.NilAdr), a listening connection is assumed.
			ELSE an active open is assumed.
			IF (lport = NilPort), an ephemeral port is assigned.
		*)
		PROCEDURE Add(p: Connection; lport, fport: LONGINT; VAR res: LONGINT);
		VAR i, sport: LONGINT;
		BEGIN {EXCLUSIVE}
			IF ((fport # NilPort) & (IP.IsNilAdr(p.fip))) OR (* workaround for XOR *)
				((fport = NilPort) & (~IP.IsNilAdr(p.fip))) THEN
				(* both must be "nil" or both must not be "nil" *)
				res := InvalidParameter;
				Error(res, 0, p);
				RETURN;
			END;

			IF lport = NilPort THEN
				(* find an ephemeral port *)
				sport := eport;
				LOOP
					lport := eport;
					INC(eport);
					IF eport > MaxEphemeralPort THEN
						eport := MinEphemeralPort;
					END;
					IF Lookup(lport, fport, p.fip) = nilpcb THEN
						(* found port that is not in use *)
						EXIT;
					END;
					IF eport = sport THEN
						res := AllPortsInUse;
						Error(res, 0, p);
						RETURN;
					END;
				END;
			ELSE
				IF Lookup(lport, fport, p.fip) # nilpcb THEN
					res := AddressInUse;
					Error(res, 0, p);
					RETURN;
				END;
			END;
			p.lport := lport;
			p.fport := fport;

			(* add to pool *)
			i := HashPool(lport, fport, p.fip);
			p.poolNext := table[i];
			table[i] := p;
			res := Ok;
		END Add;

		(* Remove a Connection from the queue (detach), making its address re-usable. *)

		PROCEDURE Remove(p: Connection);
		VAR
			i: LONGINT;
			item: Connection;
		BEGIN {EXCLUSIVE}
			i := HashPool(p.lport, p.fport, p.fip);
			IF table[i] # NIL THEN
				IF table[i] = p THEN
					(* remove first item *)
					table[i] := table[i].poolNext;
					RETURN;
				ELSE
					(* search list for connection *)
					item := table[i];
					WHILE (item.poolNext # NIL) & (item.poolNext # p) DO
						item := item.poolNext;
					END;
					IF item.poolNext # NIL THEN
						(* found - remove *)
						item.poolNext := item.poolNext.poolNext;
						RETURN;
					END;
				END;
			END;
			Error(ConnectionGone, 0, p); (* pcb gone, e.g. Rst received *)
		END Remove;

	END ConnectionPool;

TYPE
	(** Install a procedure to be called when no matching port was found for an incoming connection request.
		The buffer MUST NOT be returned by the listener, it is returned automatically by the caller afterwards.
	*)
	PacketDumpListener* = PROCEDURE (fip: IP.Adr; buffer: Network.Buffer);

VAR
	pool*: ConnectionPool;	(* pool of all Connections *)
	timeSource: Timer;	(* global timer *)
	issSource: ISS;	(* source for ISS numbers *)
	lastpcb: Connection;	(* cache last used pcb (never NIL). Note that it is possible that a deleted pcb can be ressurrected by a packet arriving for it. As soon as a packet for another connection arrives, the deleted pcb will vanish. *)
	nilpcb: Connection;	(* never NIL *)
	empty: SendData;	(* never NIL *)
	backoff: ARRAY MaxRxtShift+1 OF LONGINT;	(* exponential backoff multipliers *)
	totbackoff: LONGINT;
	outflags: ARRAY NumStates OF SET;	(* output header flags *)

	(* TCP counters *)
	NTCPError-: ARRAY NumErrors OF LONGINT;
	NTCPConnectAttempt-, NTCPPersistTimer-, NTCPFinWait2Timer-, NTCPSendProbe-, NTCPReXmtPack-,
		NTCPReXmtByte-, NTCPSendPack-, NTCPSendByte-, NTCPAcks-, NTCPSendCtrl-, NTCPSendUrg-,
		NTCPSendWinUp-, NTCPSegsTimed-, NTCPSendTotal-, NTCPKeepTimer-, NTCPKeepProbe-,
		NTCPReXmtTimer-, NTCPRcvTotal-, NTCPRcvOptions-, NTCPCacheMiss-, NTCPPredAck-, NTCPAckPack-,
		NTCPAckByte-, NTCPPredData-, NTCPRcvPackFast-, NTCPRcvByteFast-, NTCPConnects-, NTCPRcvWinProbe-,
		NTCPDrops-, NTCPRcvWinUpd-, NTCPRTTUpdated-, NTCPDelAck-, NTCPConnDrops-, NTCPClosed-, NTCPSplitBuffer-,
		NTCPRcvPackSlow-, NTCPRcvByteSlow-, NTCPNewBufs-, NTCPTimeWaitTimer-,
		NTCPUnacceptable-, NTCPAccepts-, NTCPPersistDrop-: LONGINT;
	trace: BOOLEAN;
	packetDumpListener : PacketDumpListener;

(* Trace installer *)

(** Install a procedure to be called when no matching port was found for an incoming connection request.
	The buffer doesn't have to be returned by the listener, it is returned automatically by the caller afterwards.
*)
PROCEDURE SetDefaultListener*(pdl : PacketDumpListener);
BEGIN
	packetDumpListener := pdl
END SetDefaultListener;


(* --- Utility procedures. *)
PROCEDURE Invariant(p: Connection);
VAR
	rcvbuf: Network.Buffer;
	sndbuf: SendBuffer;
	found: BOOLEAN;

BEGIN
	IF StrongChecks & (p # nilpcb) THEN
		(* receive buffers *)
		rcvbuf := p.rcvhead;
		IF rcvbuf # NIL THEN
			(* not empty *)
			ASSERT((rcvbuf.len > 0) OR (Fin IN rcvbuf.set));
			ASSERT(rcvbuf.prev = NIL);
			IF rcvbuf.next = NIL THEN
				(* the only buffer *)
				ASSERT(p.rcvtail = rcvbuf);
			ELSE
				rcvbuf := rcvbuf.next;
				IF rcvbuf.next = NIL THEN
					(* 2 buffers *)
					ASSERT(rcvbuf.prev.next = rcvbuf);
					ASSERT(p.rcvtail = rcvbuf);
				ELSE
					(* check chain (more than 2 buffers *)
					REPEAT
						ASSERT(rcvbuf.next.prev = rcvbuf);
						ASSERT(rcvbuf.prev.next = rcvbuf);
						rcvbuf := rcvbuf.next;
					UNTIL rcvbuf.next = NIL;
					(* last buffer *)
					ASSERT(p.rcvtail = rcvbuf);
				END;
			END;
		END;

		(* send buffers *)
		sndbuf := p.sndhead; found := FALSE;
		LOOP
			found := found OR (sndbuf = p.sndtail);
			sndbuf := sndbuf.next;
			ASSERT(sndbuf # NIL);
			IF sndbuf = p.sndhead THEN EXIT END;
			ASSERT(~found OR ((sndbuf.ofs = 0) & (sndbuf.len = 0)))
		END;
		ASSERT(found);
	END
END Invariant;


(* Hash function for ConnectionPool *)
PROCEDURE HashPool(lport, fport: LONGINT; fip:IP.Adr): LONGINT;
VAR
	i: LONGINT;
	hash: LONGINT;
BEGIN
	(* hash := (lport + fport + fip) MOD HashTableSize; *)
	hash := lport + fport;

	CASE fip.usedProtocol OF
		IP.IPv4:
			INC(hash, fip.ipv4Adr);

		|IP.IPv6:
			FOR i := 0 TO 15 DO
				INC(hash, ORD(fip.ipv6Adr[i]));
			END;

		ELSE

	END;

	RETURN hash MOD HashTableSize;

END HashPool;

(*
(* Hash function for ConnectionPool. *)

PROCEDURE -HashPool(lport, fport: LONGINT; fip: IP.Adr): LONGINT;
CODE {SYSTEM.i386}
	(* hash := (lport + fport + fip) MOD HashTableSize; *)
	POP ECX
	POP EBX
	POP EAX
	; Convert IP to host byte order
	XCHG CL, CH
	ROL ECX, 16
	XCHG CL, CH
	; Calculate sum
	ADD EAX, EBX
	ADD EAX, ECX
	; MOD operation
	MOV EBX, HashTableSize
	XOR EDX, EDX
	DIV EBX
	MOV EAX, EDX
END HashPool;
*)



(* Set x to val, but keep it between min and max. *)

PROCEDURE RangeSet(VAR x: LONGINT; val, min, max: LONGINT);
BEGIN
	IF val < min THEN x := min
	ELSIF val > max THEN x := max
	ELSE x := val
	END
END RangeSet;

(*
PROCEDURE -Min(a, b: LONGINT): LONGINT;
CODE {SYSTEM.i386}
	POP EBX
	POP EAX
	CMP EAX, EBX
	JLE end
	MOV EAX, EBX
end:
END Min;

PROCEDURE -Max(a, b: LONGINT): LONGINT;
CODE {SYSTEM.i386}
	POP EBX
	POP EAX
	CMP EAX, EBX
	JGE end
	MOV EAX, EBX
end:
END Max;
*)

PROCEDURE WriteTime(t: LONGINT);
VAR s: ARRAY 8 OF CHAR;
BEGIN
	KernelLog.Int(t DIV Kernel.second, 1);
	s[0] := "."; t := (t MOD Kernel.second)*1000 DIV Kernel.second;
	s[1] := CHR(48+t DIV 100 MOD 10); s[2] := CHR(48+t DIV 10 MOD 10);
	s[3] := CHR(48+t MOD 10); s[4] := 0X;
	KernelLog.String(s)
END WriteTime;

(* TCP error function. *)

PROCEDURE Error(err, n: LONGINT; p: Connection);
BEGIN
	IF trace THEN
		KernelLog.Enter; KernelLog.String("TCP: "); WriteTime(Kernel.GetTicks());
		KernelLog.String(" result "); KernelLog.Int(err, 1);
		KernelLog.Char(" "); KernelLog.Int(n, 1); KernelLog.Exit
	END;
	IF TraceError & (p # NIL) THEN TraceTCP("", p, empty^, empty^, 0, 0, 0) END;
	Machine.AtomicInc(NTCPError[0]); Machine.AtomicInc(NTCPError[err-MinError])
END Error;

(* Calculate and store new value for persist timer. *)

PROCEDURE SetPersist(p: Connection);
BEGIN
	ASSERT(p.timer[ReXmt] = 0);
	RangeSet(p.timer[Persist], (p.srtt DIV 4 + p.rttvar) DIV 2 * backoff[p.rxtshift], PersMin, PersMax);
	IF p.rxtshift < MaxRxtShift THEN INC(p.rxtshift) END
END SetPersist;

(* Trace Connection fields. *)

PROCEDURE TraceConnection(p: Connection);
VAR i: LONGINT;
BEGIN
	IF Trace THEN
		KernelLog.String(" state=");
		CASE p.state OF
			Closed: KernelLog.String("Closed")
			|Listen: KernelLog.String("Listen")
			|SynSent: KernelLog.String("SynSent")
			|SynReceived: KernelLog.String("SynReceived")
			|Established: KernelLog.String("Established")
			|CloseWait: KernelLog.String("CloseWait")
			|FinWait1: KernelLog.String("FinWait1")
			|Closing: KernelLog.String("Closing")
			|LastAck: KernelLog.String("LastAck")
			|FinWait2: KernelLog.String("FinWait2")
			|TimeWait: KernelLog.String("TimeWait")
		END;
		KernelLog.String(" maxseg="); KernelLog.Int(p.maxseg, 1);
		KernelLog.String(" flags={");
		IF AckNow IN p.flags THEN KernelLog.String(" AckNow") END;
		IF DelAck IN p.flags THEN KernelLog.String(" DelAck") END;
		IF NoDelay IN p.flags THEN KernelLog.String(" NoDelay") END;
		IF SentFin IN p.flags THEN KernelLog.String(" SentFin") END;
		IF Force IN p.flags THEN KernelLog.String(" Force") END;
		IF RcvdScale IN p.flags THEN KernelLog.String(" RcvdScale") END;
		IF RcvdTstmp IN p.flags THEN KernelLog.String(" RcvdTstmp") END;
		IF ReqScale IN p.flags THEN KernelLog.String(" ReqScale") END;
		IF ReqTstmp IN p.flags THEN KernelLog.String(" ReqTstmp") END;
		IF DoKeepAlive IN p.flags THEN KernelLog.String(" DoKeepAlive") END;
		IF AcceptConn IN p.flags THEN KernelLog.String(" AcceptConn") END;
		FOR i := 11 TO 31 DO
			IF i IN p.flags THEN KernelLog.Char(" "); KernelLog.Int(i, 1) END
		END;
		KernelLog.String(" } error="); KernelLog.Int(p.error, 1);
		KernelLog.Ln;
		KernelLog.String(" iss="); KernelLog.Int(p.iss, 1);
		KernelLog.String(" snduna="); KernelLog.Int(p.snduna-p.iss, 1);
		KernelLog.String(" sndnxt="); KernelLog.Int(p.sndnxt-p.iss, 1);
		KernelLog.String(" sndmax="); KernelLog.Int(p.sndmax-p.iss, 1);
		KernelLog.String(" sndup="); KernelLog.Int(p.sndup-p.iss, 1);
		KernelLog.String(" sndwl2="); KernelLog.Int(p.sndwl2-p.iss, 1);
		KernelLog.String(" rtseq="); KernelLog.Int(p.rtseq-p.iss, 1);
		KernelLog.Ln;
		KernelLog.String(" sndwnd="); KernelLog.Int(p.sndwnd, 1);
		KernelLog.String(" sndcwnd="); KernelLog.Int(p.sndcwnd, 1);
		KernelLog.String(" sndcc="); KernelLog.Int(p.sndcc, 1);
		KernelLog.String(" sndspace="); KernelLog.Int(p.sndspace, 1);
		KernelLog.String(" sndssthresh="); KernelLog.Int(p.sndssthresh, 1);
		KernelLog.Ln;
		KernelLog.String(" irs="); KernelLog.Int(p.irs, 1);
		KernelLog.String(" rcvnxt="); KernelLog.Int(p.rcvnxt-p.irs, 1);
		KernelLog.String(" rcvup="); KernelLog.Int(p.rcvup-p.irs, 1);
		KernelLog.String(" sndwl1="); KernelLog.Int(p.sndwl1-p.irs, 1);
		KernelLog.String(" rcvadv="); KernelLog.Int(p.rcvadv-p.irs, 1);
		KernelLog.String(" lastacksent="); KernelLog.Int(p.lastacksent-p.irs, 1);
		KernelLog.Ln;
		KernelLog.String(" rcvwnd="); KernelLog.Int(p.rcvwnd, 1);
		KernelLog.String(" rcvspace="); KernelLog.Int(p.rcvspace, 1);
		KernelLog.String(" rcvhiwat="); KernelLog.Int(p.rcvhiwat, 1);
		KernelLog.String(" idle="); KernelLog.Int(p.idle, 1);
		KernelLog.String(" rtt="); KernelLog.Int(p.rtt, 1);
		KernelLog.String(" srtt="); KernelLog.Int(p.srtt, 1);
		KernelLog.Ln;
		KernelLog.String(" rttvar="); KernelLog.Int(p.rttvar, 1);
		KernelLog.String(" rttmin="); KernelLog.Int(p.rttmin, 1);
		KernelLog.String(" maxsndwnd="); KernelLog.Int(p.maxsndwnd, 1);
		KernelLog.String(" sndscale="); KernelLog.Int(p.sndscale, 1);
		KernelLog.String(" rcvscale="); KernelLog.Int(p.rcvscale, 1);
		KernelLog.String(" requestrscale="); KernelLog.Int(p.requestrscale, 1);
		KernelLog.Ln;
		KernelLog.String(" requestedsscale="); KernelLog.Int(p.requestedsscale, 1);
		KernelLog.String(" tsrecent="); KernelLog.Int(p.tsrecent, 1);
		KernelLog.String(" tsrecentage="); KernelLog.Int(p.tsrecentage, 1);
		KernelLog.String(" rxtshift="); KernelLog.Int(p.rxtshift, 1);
		KernelLog.String(" rxtcur="); KernelLog.Int(p.rxtcur, 1);
		KernelLog.String(" dupacks="); KernelLog.Int(p.dupacks, 1);
		KernelLog.Ln; KernelLog.Ln
	END
END TraceConnection;

(* Trace the protocol. *)

PROCEDURE TraceTCP(msg: ARRAY OF CHAR; p: Connection; CONST hdr, data: ARRAY OF CHAR; hlen, ofs, len: LONGINT);
BEGIN
	IF Trace THEN
		WriteTime(Kernel.GetTicks()); KernelLog.Char(" ");
		KernelLog.String(msg); TraceConnection(p);
		IF TracePacket THEN
			KernelLog.Memory(ADDRESSOF(hdr[0]), hlen);
			KernelLog.Memory(ADDRESSOF(data[ofs]), len)
		END
	END
END TraceTCP;

(* Output a TCP segment. *)

PROCEDURE Output(p: Connection);
VAR
	idle, sendalot: BOOLEAN;
	optLen, off, sum, win, len, adv, x, startseq, left: LONGINT;
	pf: SET; buf: SendBuffer; data: SendData;
	pseudoHdr: ARRAY MaxPseudoHdrLen OF CHAR;
	hdr: ARRAY MaxTCPHdrLen OF CHAR;
	pseudoHdrLen: LONGINT;
BEGIN
	idle := (p.sndmax = p.snduna);
	IF idle & (p.idle >= p.rxtcur) THEN p.sndcwnd := p.maxseg END;
	REPEAT
		sendalot := FALSE;
		LOOP	(* look for reason to send a segment (not a real loop, just a goto-substitute) *)
			off := p.sndnxt - p.snduna;	(* the first off bytes from the buffer have been sent and are waiting for Ack *)
			win := p.sndwnd;	(* minimum of window advertised by receiver and the congestion window *)
			IF HandleCongestion & (p.sndcwnd < win) THEN win := p.sndcwnd END;
			pf := outflags[p.state];
			IF Force IN p.flags THEN
				IF win = 0 THEN
					IF off < p.sndcc THEN EXCL(pf, Fin) END;
					win := 1
				ELSE
					p.timer[Persist] := 0; p.rxtshift := 0
				END
			END;
			len := p.sndcc;	(* minimum of bytes in send buffer and win *)
			IF win < len THEN len := win END;
			DEC(len, off);	(* off bytes have already been sent and are waiting for Ack *)
			IF len < 0 THEN
				len := 0;
				IF win = 0 THEN p.timer[ReXmt] := 0; p.sndnxt := p.snduna END;
			END;
			IF len > p.maxseg THEN len := p.maxseg; sendalot := TRUE END;
			IF (p.sndnxt + len) - (p.snduna + p.sndcc) < 0 THEN EXCL(pf, Fin) END;	(* not emptying send buffer *)
			win := p.rcvspace;	(* now win is receive window advertised *)
			IF len # 0 THEN
				IF len = p.maxseg THEN EXIT END;
				IF (idle OR (NoDelay IN p.flags)) & (len + off >= p.sndcc) THEN EXIT END;
				IF Force IN p.flags THEN EXIT END;
				IF len >= p.maxsndwnd DIV 2 THEN EXIT END;
				IF p.sndnxt - p.sndmax < 0 THEN EXIT END
			END;
			IF win > 0 THEN
				adv := ASH(MaxWin, p.rcvscale);
				IF win < adv THEN adv := win END;
				DEC(adv, p.rcvadv - p.rcvnxt);
				IF adv >= 2*p.maxseg THEN EXIT END;
				IF 2*adv >= p.rcvhiwat THEN EXIT END
			END;
			IF AckNow IN p.flags THEN EXIT END;
			IF pf * {Syn,Rst} # {} THEN EXIT END;
			IF p.sndup - p.snduna > 0 THEN EXIT END;
			IF (Fin IN pf) & (~(SentFin IN p.flags) OR (p.sndnxt = p.snduna)) THEN EXIT END;
			IF (p.sndcc # 0) & (p.timer[ReXmt] = 0) & (p.timer[Persist] = 0) THEN
				p.rxtshift := 0; SetPersist(p)
			END;
			RETURN (* 0 *)	(* no reason to send a segment *)
		END; (* LOOP *)

		(* form output segment *)
		optLen := 0;
		IF Syn IN pf THEN
			p.sndnxt := p.iss;
			IF GenOptions THEN
				(* generate MSS option *)
				hdr[MinTCPHdrLen+optLen] := 2X; (* MSS option *)
				hdr[MinTCPHdrLen+optLen+1] := 4X; (* option length *)
				Network.PutNet2(hdr, MinTCPHdrLen+optLen+2, p.int.dev.mtu-120); (* MSS = dev.mtu-120 *)
				INC(optLen, 4);
				(* generate window scale option *)
				IF ((ReqScale IN p.flags) & (~(Ack IN pf) OR (RcvdScale IN p.flags))) THEN
					hdr[MinTCPHdrLen+optLen] := 1X; (* NOP *)
					hdr[MinTCPHdrLen+optLen+1] := 3X; (* window scale option *)
					hdr[MinTCPHdrLen+optLen+2] := 3X; (* option length *)
					hdr[MinTCPHdrLen+optLen+3] := CHR(p.requestrscale); (* window scale *)
					INC(optLen, 4);
				END;
			END;
		END;
		(* generate timestamp option *)
		IF GenOptions & DoRFC1323 & (ReqTstmp IN p.flags) & ~(Rst IN pf) & ((pf * {Syn, Ack} = {Syn}) OR (RcvdTstmp IN p.flags)) THEN
			hdr[MinTCPHdrLen+optLen] := 1X; (* NOP *)
			hdr[MinTCPHdrLen+optLen+1] := 1X; (* NOP *)
			hdr[MinTCPHdrLen+optLen+2] := 8X; (* timestamp option *)
			hdr[MinTCPHdrLen+optLen+3] := 0AX; (* option length *)
			Network.PutNet4(hdr, MinTCPHdrLen+optLen+4, timeSource.now);
			Network.PutNet4(hdr, MinTCPHdrLen+optLen+8, p.tsrecent);
			INC(optLen, 12);
		END;

		(* This doesn't work if Fin was set before !! (bug in TCP/IP Illustrated Vol. 2, p. 873, fig. 26.24)
			Solved by setting MSS = 536 - 12 (size of timestamp option) and commenting this out.
			(mvt, 28.02.2004)
		IF len > p.maxseg - optLen THEN
			len := p.maxseg - optLen;
			sendalot := TRUE;
		END;
		*)

		IF len # 0 THEN
			IF (Force IN p.flags) & (len = 1) THEN Machine.AtomicInc(NTCPSendProbe)
			ELSIF p.sndnxt - p.sndmax < 0 THEN Machine.AtomicInc(NTCPReXmtPack); Machine.AtomicAdd(NTCPReXmtByte, len)
			ELSE Machine.AtomicInc(NTCPSendPack); Machine.AtomicAdd(NTCPSendByte, len)
			END;
			IF off + len = p.sndcc THEN INCL(pf, Psh) END;
				(* data to send is in buffer[off..off+len-1] *)
			buf := p.sndhead; WHILE off >= buf.len DO DEC(off, buf.len); buf := buf.next END;
			IF off+len <= buf.len THEN	(* all data is this buffer *)
				data := buf.data; INC(off, buf.ofs)
			ELSE	(* data is spread over more buffers *)
				Machine.AtomicInc(NTCPSplitBuffer);
				data := p.sndcontig;
				ASSERT(len <= LEN(data^));
				ASSERT(buf.len-off <= len);	(* index check *)
				IF SystemMove THEN
					SYSTEM.MOVE(ADDRESSOF(buf.data[off+buf.ofs]), ADDRESSOF(data[0]), buf.len-off)
				ELSE
					Network.Copy(buf.data^, data^, off+buf.ofs, 0, buf.len-off)
				END;
				off := buf.len-off; left := len-off;
				WHILE left # 0 DO
					buf := buf.next; IF left <= buf.len THEN x := left ELSE x := buf.len END;
					ASSERT(off+x <= len);	(* index check *)
					IF SystemMove THEN
						SYSTEM.MOVE(ADDRESSOF(buf.data[buf.ofs]), ADDRESSOF(data[off]), x)
					ELSE
						Network.Copy(buf.data^, data^, buf.ofs, off, x)
					END;
					INC(off, x); DEC(left, x)
				END;
				off := 0
			END
		ELSE
			IF AckNow IN p.flags THEN Machine.AtomicInc(NTCPAcks)
			ELSIF pf * {Syn,Fin,Rst} # {} THEN Machine.AtomicInc(NTCPSendCtrl)
			ELSIF p.sndup - p.snduna > 0 THEN Machine.AtomicInc(NTCPSendUrg)
			ELSE Machine.AtomicInc(NTCPSendWinUp)
			END;
			data := empty; off := 0
		END;
		IF (Fin IN pf) & (SentFin IN p.flags) & (p.sndnxt = p.sndmax) THEN DEC(p.sndnxt) END;

		IF (len # 0) OR (pf * {Syn,Fin} # {}) OR (p.timer[Persist] # 0) THEN
			Network.PutNet4(hdr, 4, p.sndnxt)	(* sequence number *)
		ELSE
			Network.PutNet4(hdr, 4, p.sndmax)
		END;
		Network.PutNet4(hdr, 8, p.rcvnxt);	(* acknowledgement number *)
		IF (win < p.rcvhiwat DIV 4) & (win < p.maxseg) THEN win := 0 END;
		IF win > ASH(MaxWin, p.rcvscale) THEN win := ASH(MaxWin, p.rcvscale) END;
		IF win < p.rcvadv - p.rcvnxt THEN win := p.rcvadv - p.rcvnxt END;
		Network.PutNet2(hdr, 14, ASH(win, -p.rcvscale));
		IF p.sndup - p.sndnxt > 0 THEN
			x := p.sndup - p.sndnxt;
			IF x > 65535 THEN x := 65535 END;
			Network.PutNet2(hdr, 18, x);
			INCL(pf, Urg)
		ELSE
			p.sndup := p.snduna
		END;
		hdr[13] := CHR(SHORT(SHORT(SYSTEM.VAL(LONGINT, pf))));

		(* set rest of TCP header *)
		Network.PutNet2(hdr, 0, p.lport);
		Network.PutNet2(hdr, 2, p.fport);
		hdr[12] := CHR((MinTCPHdrLen+optLen) DIV 4*10H);
		Network.Put2(hdr, 16, 0); (* checksum := 0; *)

		IF ~(Network.ChecksumTCP IN p.int.dev.calcChecksum) THEN
			(* set pseudo header *)
			pseudoHdrLen := p.int.WritePseudoHeader(pseudoHdr, p.int.localAdr, p.fip, IPTypeTCP, MinTCPHdrLen+optLen+len);

			sum := IP.Checksum1(pseudoHdr, 0, pseudoHdrLen, 0);
			sum := IP.Checksum1(hdr, 0, MinTCPHdrLen+optLen, sum);
			sum := IP.Checksum2(data^, off, len, sum);
			Network.Put2(hdr, 16, sum); (* checksum := sum *)
		END;

		IF ~(Force IN p.flags) OR (p.timer[Persist] = 0) THEN
			startseq := p.sndnxt;
			IF pf * {Syn,Fin} # {} THEN
				IF Syn IN pf THEN INC(p.sndnxt) END;
				IF Fin IN pf THEN INC(p.sndnxt); INCL(p.flags, SentFin) END
			END;
			INC(p.sndnxt, len);
			IF p.sndnxt - p.sndmax > 0 THEN
				p.sndmax := p.sndnxt;
				IF p.rtt = 0 THEN p.rtt := 1; p.rtseq := startseq; Machine.AtomicInc(NTCPSegsTimed) END
			END;
			IF (p.timer[ReXmt] = 0) & (p.sndnxt # p.snduna) THEN
				p.timer[ReXmt] := p.rxtcur;
				IF p.timer[Persist] # 0 THEN p.timer[Persist] := 0; p.rxtshift := 0 END
			END
		ELSIF (p.sndnxt + len) - p.sndmax > 0 THEN
			p.sndmax := p.sndnxt + len
		ELSE (* skip *)
		END;
		IF TraceProtocol THEN
			TraceTCP("Output", p, hdr, data^, MinTCPHdrLen+optLen, off, len)
		END;

		(* Send packet *)
		p.int.Send(IPTypeTCP, p.fip, hdr, data^, MinTCPHdrLen+optLen, off, len, IP.MaxTTL);

		(* old code:
			IP.IPOutput(IP.default, p.hdr, data^, IP.MinIPHdrLen+MinTCPHdrLen, off, len);
			IF FALSE THEN	(* error in IPOutput *)
				IF FALSE THEN	(* out of buffers *)
					p.sndcwnd := p.maxseg;	(* close congestion window *)
					RETURN (* 0 *)
				END;
				IF FALSE & (p.state >= SynReceived) THEN	(* host unreachable or network down *)
					(*p.softerror := error;*) RETURN (* 0 *)
				END;
				RETURN (* error *)
			END;
		*)
		Machine.AtomicInc(NTCPSendTotal);
		IF (win > 0) & ((p.rcvnxt + win) - p.rcvadv > 0) THEN p.rcvadv := p.rcvnxt + win END;
		p.lastacksent := p.rcvnxt;
		p.flags := p.flags - {AckNow,DelAck}
	UNTIL ~sendalot;
	(* RETURN 0 *)
END Output;

(* Special output function for Rst and KeepAlive packets (fig. 26.34). *)

PROCEDURE Respond(p: Connection; ack, seq: LONGINT; rf: SET);
VAR
	win, sum: LONGINT;
	pseudoHdr: ARRAY MaxPseudoHdrLen OF CHAR;
	hdr: ARRAY MaxTCPHdrLen OF CHAR;
	pseudoHdrLen: LONGINT;

BEGIN
	win := ASH(p.rcvspace, -p.rcvscale);	(* zero in nilpcb *)
	IF rf = {} THEN
		(* keepalive probe *)
		INCL(rf, Ack)
	ELSE
		(* Rst segment *)
	END;

	(* set TCP header *)
	Network.PutNet2(hdr, 0, p.lport);
	Network.PutNet2(hdr, 2, p.fport);
	Network.PutNet4(hdr, 4, seq);
	Network.PutNet4(hdr, 8, ack);
	hdr[12] := CHR(MinTCPHdrLen DIV 4*10H);
	hdr[13] := CHR(SHORT(SHORT(SYSTEM.VAL(LONGINT, rf))));
	Network.PutNet2(hdr, 14, win);
	Network.Put2(hdr, 16, 0); (* checksum := 0 *)
	Network.Put2(hdr, 18, 0); (* urgent pointer := 0 *)

	IF ~(Network.ChecksumTCP IN p.int.dev.calcChecksum) THEN
		(* set pseudo header *)
		pseudoHdrLen := p.int.WritePseudoHeader(pseudoHdr, p.int.localAdr, p.fip, IPTypeTCP, MinTCPHdrLen);

		sum := IP.Checksum1(pseudoHdr, 0, pseudoHdrLen, 0);
		sum := IP.Checksum2(hdr, 0, MinTCPHdrLen, sum);
		Network.Put2(hdr, 16, sum); (* checksum := sum; *)
	END;

	p.int.Send(IPTypeTCP, p.fip, hdr, hdr, MinTCPHdrLen, 0, 0, IP.MaxTTL);
END Respond;

(* Cancel all timers. *)

PROCEDURE CancelTimers(p: Connection);
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO NumTimers-1 DO p.timer[i] := 0 END
END CancelTimers;

(* Apply new RTT measurement to smoothed estimators. *)

(*
PROCEDURE XmitTimer(p: Connection; rtt: LONGINT);
VAR delta: LONGINT;
BEGIN
	Machine.AtomicInc(NTCPRTTUpdated);
	IF p.srtt # 0 THEN
		delta := rtt - 1 - ASH(p.srtt, -RTTShift);
		INC(p.srtt, delta);
		IF p.srtt <= 0 THEN p.srtt := 1 END;
		IF delta < 0 THEN delta := -delta END;
		DEC(delta, ASH(p.rttvar, -RTTVarShift));
		INC(p.rttvar, delta);
		IF p.rttvar <= 0 THEN p.rttvar := 1 END
	ELSE
		p.srtt := ASH(rtt, RTTShift); p.rttvar := ASH(rtt, RTTVarShift-1)
	END;
	p.rtt := 0; p.rxtshift := 0;
	RangeSet(p.rxtcur, ASH(p.srtt, -RTTShift) + p.rttvar, p.rttmin, ReXmtMax);
	(*p.softerror := 0*)
END XmitTimer;
*)

PROCEDURE XmitTimer(p: Connection; rtt: LONGINT);
(*
	 m ->  rtt
	 sa -> p.srtt
	 sd -> p.rttvar
*)
VAR delta: LONGINT;
BEGIN
	Machine.AtomicInc(NTCPRTTUpdated);
	IF p.srtt # 0 THEN
(*		delta := (rtt*4)  - ASH(p.srtt, -RTTShift);*)
		delta := rtt - 1 - ASH(p.srtt, -RTTShift);
		INC(p.srtt, delta);
		IF p.srtt <= 0 THEN p.srtt := 1 END;
		IF delta < 0 THEN delta := -delta END;
		DEC(delta, ASH(p.rttvar, -RTTVarShift));
		INC(p.rttvar, delta);
		IF p.rttvar <= 0 THEN p.rttvar := 1 END
	ELSE
		p.srtt := ASH(rtt, RTTShift); p.rttvar := ASH(rtt, RTTVarShift-1)
	END;
	p.rtt := 0; p.rxtshift := 0;
(*	p.rxtcur:=((p.srtt DIV 8)+ p.rttvar) DIV 4;
	IF p.rxtcur < (rtt+2) THEN p.rxtcur:=rtt; END;*)
	RangeSet(p.rxtcur, ASH(p.srtt, -RTTShift) + p.rttvar, MinTime, ReXmtMax);

	(*p.softerror := 0*)
END XmitTimer;


(* Drop len bytes from the front of the send buffer. *)
PROCEDURE SbDrop(p: Connection; len: LONGINT);
VAR buf: SendBuffer;
BEGIN
	DEC(p.sndcc, len); INC(p.sndspace, len);
	buf := p.sndhead;
	LOOP
		IF buf.len > len THEN	(* part of buffer will remain *)
			INC(buf.ofs, len); DEC(buf.len, len);	(* ignore buf.seq (later: why?) *)
			EXIT
		END;
		DEC(len, buf.len);
		buf.ofs := 0; buf.len := 0;	(* make buffer ready for re-use *)
		IF buf # p.sndtail THEN buf := buf.next END;
		IF len = 0 THEN EXIT END
	END;
	p.sndhead := buf
END SbDrop;


(* Close a connection (fig. 27.4-6). *)
PROCEDURE CloseConnection(p: Connection);
VAR
	buf: Network.Buffer;

BEGIN
	IF FALSE (* we sent enough data to update rtt in route *) THEN
	END;
	pool.Remove(p);
	(* can not remove from parent's accept list, because of possible deadlock *)
	IF p = lastpcb THEN lastpcb := nilpcb END;	(* only for GC -- race does not matter *)
		(* can not clear any pcb pointer fields, because Lookup is non-exclusive *)
	(*SoIsDisconnected(p);*)
	p.state := Closed;
	(* return the buffers still in receive queue *)
	p.rcvreasm := NIL;
	p.rcvtail := NIL;
	WHILE p.rcvhead # NIL DO
		buf := p.rcvhead;
		p.rcvhead := p.rcvhead.next;
		Network.ReturnBuffer(buf);
	END;
	Machine.AtomicInc(NTCPClosed);
END CloseConnection;


(* Drop a connection (fig. 27.2). *)
PROCEDURE Drop(p: Connection; err: LONGINT);
BEGIN
	IF p.state >= SynReceived THEN
		p.state := Closed; Output(p); Machine.AtomicInc(NTCPDrops)
	ELSE
		Machine.AtomicInc(NTCPConnDrops)
	END;
	(* IF (err = TimedOut) & (p.softerror # Ok) THEN err := p.softerror END; *)
	p.error := err; CloseConnection(p)
END Drop;

PROCEDURE SetMSS(p: Connection; mss: LONGINT);
	(* Error(NIYMSS, 0, p); *)
	(* Processing of received MSS option not necessary as long as sending is always done with MSS=536. *)
END SetMSS;


(* Process a received TCP segment. *)
PROCEDURE Input(int: IP.Interface; type: LONGINT; fip, lip: IP.Adr; buffer: Network.Buffer);
VAR
	lport, fport, hdrLen: LONGINT;
	p: Connection;
BEGIN
	ASSERT(type = IPTypeTCP);
	Machine.AtomicInc(NTCPRcvTotal);
	IF IP.AdrsEqual(int.localAdr, lip) THEN
		IF buffer.len >= MinTCPHdrLen THEN
			hdrLen := LONG(ORD(buffer.data[buffer.ofs+12])) DIV 10H * 4;
			IF (hdrLen < MinTCPHdrLen) OR (hdrLen > buffer.len) THEN
				(* bad header length *)
				Error(BadHeaderLength, hdrLen, NIL);
				(*GotoDrop;*)
			ELSE
				(* findpcb *)
				p := lastpcb;
				fport := Network.GetNet2(buffer.data, buffer.ofs);
				lport := Network.GetNet2(buffer.data, buffer.ofs+2);
				IF (p = nilpcb) OR (~IP.AdrsEqual(p.fip, fip)) OR (p.lport # lport) OR (p.fport # fport) THEN
					p := pool.Lookup(lport, fport, fip);
					IF p = nilpcb THEN
						(* look for listening connection *)
						p := pool.Lookup(lport, NilPort, IP.NilAdr);
					END;
					lastpcb := p;
					Machine.AtomicInc(NTCPCacheMiss);
				END;
				p.Input(int, fip, hdrLen, buffer);
				RETURN; (* w/o returning buffer *)
			END;
		ELSE
			Error(SegmentTooSmall, buffer.len, NIL);
		END;
	ELSE
		Error(BroadcastReceived, buffer.len, NIL);
	END;
	Network.ReturnBuffer(buffer);
END Input;


(* Process a received TCP segment for the specified Connection. *)
PROCEDURE ProcessInput(p: Connection; hdrLen: LONGINT; buffer: Network.Buffer; drop: BOOLEAN; VAR bufferQueued: BOOLEAN);
CONST
	Options = 0; TSPresent = 1; NeedOutput = 2;

VAR
	win, sum, urp, seq, ack, tsval, tsecr, acked, discard, tlen, optLen: LONGINT;
	pseudoHdr: ARRAY MaxPseudoHdrLen OF CHAR;
	pseudoHdrLen: LONGINT;
	pf, lf: SET;
	reassembledLength: LONGINT;
	fragmentBuffer: Network.Buffer;

	PROCEDURE GotoDrop;	(* fig. 29.27 *)
	BEGIN
		IF TraceProtocol THEN TraceTCP("Drop", p, empty^, empty^, 0, 0, 0) END;
		IF drop THEN Drop(p, ConnectionAborted) END
	END GotoDrop;

	PROCEDURE GotoDropReset;	(* fig. 29.27 - may be called with p = nilpcb (at start) *)
	BEGIN
		IF (Rst IN pf) THEN
			GotoDrop
		ELSE
			IF Ack IN pf THEN
				Respond(p, 0, ack, {Rst})
			ELSE
				IF Syn IN pf THEN INC(tlen) END;
				Respond(p, seq + tlen, 0, {Rst,Ack})
			END;
			IF drop THEN Drop(p, ConnectionAborted) END
		END
	END GotoDropReset;

	PROCEDURE GotoDropAfterAck;	(* fig. 29.26 *)
	BEGIN
		IF Rst IN pf THEN
			GotoDrop
		ELSE
			INCL(p.flags, AckNow); Output(p)
		END
	END GotoDropAfterAck;

	PROCEDURE ProcessOptions;	(* fig. 28.9 & 28.10 *)
	VAR opt: CHAR; i, m, optlen: LONGINT;
	BEGIN
		i := buffer.ofs+MinTCPHdrLen; m := buffer.ofs+hdrLen;
		LOOP
			IF i >= m THEN EXIT END;
			opt := buffer.data[i];
			IF opt = 0X THEN
				EXIT; (* EOL *)
			ELSIF opt = 1X THEN
				optlen := 1; (* NOP *)
			ELSE
				optlen := ORD(buffer.data[i+1]);
				IF optlen = 0 THEN EXIT END;
			END;
			CASE opt OF
				2X: (* MaxSeg *)
					IF (optlen = 4) & (Syn IN pf) THEN
						SetMSS(p, Network.GetNet2(buffer.data, i+2));
					END;
				|3X: (* Window Scaling *)
					IF (optlen = 3) & (Syn IN pf) THEN
						INCL(p.flags, RcvdScale);
						p.requestedsscale := Strings.Min(LONG(ORD(buffer.data[i+2])), MaxWinShift);
					END;
				|8X: (* Timestamp *)
					IF DoRFC1323 & (optlen = 10) THEN
						INCL(lf, TSPresent);
						tsval := Network.GetNet4(buffer.data, i+2);
						tsecr := Network.GetNet4(buffer.data, i+6);
						IF Syn IN pf THEN
							INCL(p.flags, RcvdTstmp);
							p.tsrecent := tsval;
							p.tsrecentage := timeSource.now;
						END;
					END;
				ELSE
					(* skip *)
			END;
			INC(i, optlen);
		END
	END ProcessOptions;

	PROCEDURE ProcessListen(): BOOLEAN;	(* fig. 28.15-17 *)
	VAR
		res: LONGINT;
		q: Connection;
	BEGIN
		IF Rst IN pf THEN GotoDrop; RETURN FALSE END;
		IF Ack IN pf THEN GotoDropReset; RETURN FALSE END;
		IF ~(Syn IN pf) THEN GotoDrop; RETURN FALSE END;
		pool.Add(p, Network.GetNet2(buffer.data, buffer.ofs+2), Network.GetNet2(buffer.data, buffer.ofs), res);
		IF res # Ok THEN
			GotoDrop;
			RETURN FALSE;
		END;
		IF ProcOptions & (Options IN lf) THEN ProcessOptions END;
		p.iss := issSource.Get();
		p.snduna := p.iss; p.sndnxt := p.iss; p.sndmax := p.iss; p.sndup := p.iss;
		p.irs := seq; p.rcvnxt := seq+1; p.rcvadv := p.rcvnxt;
		INCL(p.flags, AckNow);
		p.state := SynReceived;
		p.timer[Keep] := KeepInit;
		drop := FALSE;	(* commit *)
			(* put on accept queue *)
		ASSERT(Objects.LockedByCurrent(p.parent));	(* came here via Connection.Input of parent *)
		q := p.parent.acceptNext; p.acceptNext := NIL;
		IF q = NIL THEN
			p.parent.acceptNext := p
		ELSE
			WHILE q.acceptNext # NIL DO q := q.acceptNext END;	(* find last entry in queue *)
			q.acceptNext := p
		END;
		Machine.AtomicInc(NTCPAccepts);
		RETURN TRUE
	END ProcessListen;

	PROCEDURE ProcessSynSent(): BOOLEAN;
	BEGIN
		IF (Ack IN pf) & ((ack - p.iss <= 0) OR (ack - p.sndmax > 0)) THEN GotoDropReset; RETURN FALSE END;
		IF Rst IN pf THEN
			IF Ack IN pf THEN Error(ConnectionRefused, 0, p); Drop(p, ConnectionRefused) END;
			GotoDrop; RETURN FALSE
		END;
		IF ~(Syn IN pf) THEN GotoDrop; RETURN FALSE END;
		IF Ack IN pf THEN
			p.snduna := ack;
			IF p.sndnxt - p.snduna < 0 THEN p.sndnxt := p.snduna END;
		END;
		p.timer[ReXmt] := 0;
		p.irs := seq; p.rcvnxt := seq+1; p.rcvadv := p.rcvnxt;
		INCL(p.flags, AckNow);
		IF (Ack IN pf) & (p.snduna - p.iss > 0) THEN
			Machine.AtomicInc(NTCPConnects); (*SoIsConnected(p);*)
			p.state := Established;
			IF p.flags * {RcvdScale,ReqScale} = {RcvdScale,ReqScale} THEN
				p.sndscale := p.requestedsscale; p.rcvscale := p.requestrscale
			END;
			(*GotoPresent;*)	(* not necessary, processed later *)
			IF p.rtt # 0 THEN XmitTimer(p, p.rtt) END
		ELSE
			p.state := SynReceived
		END;
		RETURN TRUE
	END ProcessSynSent;

	PROCEDURE Trim1;	(* fig. 28.21 *)
	BEGIN
		INC(seq);
		IF tlen > p.rcvwnd THEN
			Error(DataBeyondWindow1, tlen - p.rcvwnd, p);	(* data received beyond window (with Syn) *)
			tlen := p.rcvwnd; EXCL(pf, Fin)
		END;
		p.sndwl1 := seq-1; p.rcvup := seq
	END Trim1;

	PROCEDURE Paws(): BOOLEAN;	(* fig. 28.22 *)
	BEGIN
		IF (TSPresent IN lf) & ~(Rst IN pf) & (p.tsrecent # 0) & (tsval - p.tsrecent < 0) THEN
			IF (timeSource.now - p.tsrecentage) > PawsIdle THEN
				p.tsrecent := 0
			ELSE
				Error(DuplicateSegmentPAWS, tlen, p); (* duplicate segment (PAWS) *)
				GotoDropAfterAck; RETURN FALSE
			END
		END;
		RETURN TRUE
	END Paws;

	PROCEDURE Trim2(todrop: LONGINT): BOOLEAN;	(* fig. 28.24-25, corrected fig. 28.30*)
	BEGIN
		IF Syn IN pf THEN
			EXCL(pf, Syn); INC(seq);
			IF urp > 1 THEN DEC(urp) ELSE EXCL(pf, Urg) END;
			DEC(todrop)
		END;
		IF (todrop > tlen) OR ((todrop = tlen) & ~(Fin IN pf)) THEN
			EXCL(pf, Fin); INCL(p.flags, AckNow); todrop := tlen;
			Error(DuplicateSegment, todrop, p)	(* duplicate segment *)
		ELSE
			Error(DuplicatePartialSegment, todrop, p)	(* partially duplicate segment *)
		END;
		INC(discard, todrop); INC(seq, todrop); DEC(tlen, todrop);
		IF urp > todrop THEN DEC(urp, todrop) ELSE EXCL(pf, Urg); urp := 0 END;
		RETURN TRUE
	END Trim2;

	PROCEDURE Trim3(todrop: LONGINT): BOOLEAN;	(* fig. 28.29 *)
	BEGIN
		IF todrop >= tlen THEN
			IF (Syn IN pf) & (p.state = TimeWait) & (seq - p.rcvnxt > 0) THEN
				(*iss := p.rcvnxt + ISSInc; CloseConnection(p); goto findpcb*)
				Error(NIYNewIncarnation, 0, p);	(* new incarnation NIY - also read p. 945-946 *)
				GotoDropAfterAck; RETURN FALSE
			END;
			IF (p.rcvwnd = 0) & (seq = p.rcvnxt) THEN
				INCL(p.flags, AckNow); Machine.AtomicInc(NTCPRcvWinProbe)
			ELSE
				Error(DataBeyondWindow2, tlen, p);	(* data received beyond window (complete) *)
				GotoDropAfterAck; RETURN FALSE
			END
		ELSE
			Error(DataBeyondWindow3, todrop, p)	(* data received beyond window (partial) *)
		END;
		DEC(tlen, todrop); pf := pf - {Psh,Fin};
		RETURN TRUE
	END Trim3;

	PROCEDURE RecordTS;	(* fig. 28.35 *)
	VAR x: LONGINT;
	BEGIN
		IF DoRFC1323 THEN
			IF pf * {Syn,Fin} # {} THEN x := 1 ELSE x := 0 END;
			IF p.lastacksent - (seq + tlen + x) < 0 THEN
				p.tsrecentage := timeSource.now;
				p.tsrecent := tsval;
			END
		END
	END RecordTS;

	PROCEDURE ProcessRst(): BOOLEAN;	(* fig. 28.36 *)
	BEGIN
		CASE p.state OF
			SynReceived, Established, FinWait1, FinWait2, CloseWait:
				IF p.state = SynReceived THEN p.error := ConnectionRefused ELSE p.error := ConnectionReset END;
				p.state := Closed; Error(p.error, 0, p);	(* connection reset *)
				CloseConnection(p); GotoDrop; RETURN FALSE
			|Closing, LastAck:
				CloseConnection(p); GotoDrop; RETURN FALSE
			ELSE (* skip *)
		END;
		RETURN TRUE
	END ProcessRst;

	PROCEDURE ProcessAck(): BOOLEAN;	(* fig. 29.2-29.14 *)
	VAR onxt, cw, incr: LONGINT; finacked: BOOLEAN;
	BEGIN
		IF p.state IN {SynReceived..TimeWait} THEN
			IF p.state = SynReceived THEN
				IF (p.snduna - ack > 0) OR (ack - p.sndmax > 0) THEN
					GotoDropReset; RETURN FALSE
				END;
				Machine.AtomicInc(NTCPConnects);
				(*SoIsConnected(p);*)
				p.state := Established;
				IF p.flags * {RcvdScale,ReqScale} = {RcvdScale,ReqScale} THEN
					p.sndscale := p.requestedsscale; p.rcvscale := p.requestrscale
				END;
				(* IF tlen > 0 THEN (* would inc of twice by the header size *)
					Reasm;
				END; *)
				p.sndwl1 := seq-1;
			END;
			IF ack - p.snduna <= 0 THEN
				IF (tlen = 0) & (win = p.sndwnd) THEN
					Error(DuplicateAck, 0, p);	(* duplicate ack *)
					IF (p.timer[ReXmt] = 0) OR (ack # p.snduna) THEN
						p.dupacks := 0
					ELSE
						INC(p.dupacks);
						IF p.dupacks = ReXmtThresh THEN
							onxt := p.sndnxt;
							p.sndssthresh := Strings.Max(Strings.Min(p.sndwnd, p.sndcwnd) DIV 2 DIV p.maxseg, 2) * p.maxseg;
							IF TraceCongestion THEN
								KernelLog.String("DA sndssthresh := "); KernelLog.Int(p.sndssthresh, 1); KernelLog.Ln
							END;
							p.timer[ReXmt] := 0; p.rtt := 0; p.sndnxt := ack; p.sndcwnd := p.maxseg;
							Output(p);
							p.sndcwnd := p.sndssthresh + p.maxseg * p.dupacks;
							IF onxt - p.sndnxt > 0 THEN p.sndnxt := onxt END;
							GotoDrop; RETURN FALSE
						ELSIF p.dupacks > ReXmtThresh THEN
							INC(p.sndcwnd, p.maxseg);
							Output(p);
							GotoDrop; RETURN FALSE
						ELSE (* skip *)
						END
					END
				ELSE
					p.dupacks := 0
				END;
				RETURN TRUE	(* skip rest of Ack processing - goto step 6 *)
			END;

			IF (p.dupacks > ReXmtThresh) & (p.sndcwnd > p.sndssthresh) THEN
				p.sndcwnd := p.sndssthresh
			END;
			p.dupacks := 0;
			IF ack - p.sndmax > 0 THEN
				Error(OutOfRangeAck, ack - p.sndmax, p); GotoDropAfterAck;
				RETURN FALSE;
			END;
			acked := ack - p.snduna;
			Machine.AtomicInc(NTCPAckPack); Machine.AtomicAdd(NTCPAckByte, acked);
			IF TSPresent IN lf THEN XmitTimer(p, timeSource.now - tsecr + 1)
			ELSIF (p.rtt # 0) & (ack - p.rtseq > 0) THEN XmitTimer(p, p.rtt)
			ELSE (* skip *)
			END;
			IF ack = p.sndmax THEN p.timer[ReXmt] := 0; INCL(lf, NeedOutput)
			ELSIF p.timer[Persist] = 0 THEN
				p.timer[ReXmt] := p.rxtcur;
			ELSE (* skip *)
			END;
			cw := p.sndcwnd; incr := p.maxseg;
			IF cw > p.sndssthresh THEN incr := incr * incr DIV cw END;
			p.sndcwnd := Strings.Min(cw + incr, ASH(MaxWin, p.sndscale));
			IF acked > p.sndcc THEN
				DEC(p.sndwnd, p.sndcc); SbDrop(p, p.sndcc); finacked := TRUE
			ELSE
				SbDrop(p, acked); DEC(p.sndwnd, acked); finacked := FALSE
			END;
			(*IF Notify IN p.flags THEN SoWakeup(p) END;*)
			p.snduna := ack;
			IF p.sndnxt - p.snduna < 0 THEN p.sndnxt := p.snduna END;
			CASE p.state OF
				FinWait1:
					IF finacked THEN
						(*IF NoMore IN p.flags THEN SoIsDisconnected(p); p.timer[MSL2] := MaxIdle END;*)
						p.timer[MSL2] := MaxIdle;	(* otherwise we hang in FinWait2 *)
						p.state := FinWait2
					END
				|Closing:
					IF finacked THEN
						p.state := TimeWait; CancelTimers(p); p.timer[MSL2] := 2 * MSL;
						(*SoIsDisconnected(p)*)
					END
				|LastAck:
					IF finacked THEN
						CloseConnection(p); GotoDrop; RETURN FALSE
					END
				|TimeWait:
					p.timer[MSL2] := 2 * MSL; GotoDropAfterAck; RETURN FALSE
				ELSE (* skip *)
			END (* CASE *)
		END;
		RETURN TRUE
	END ProcessAck;


	PROCEDURE GotoPresent;
	VAR
		buf: Network.Buffer;

	BEGIN
		buf := p.rcvreasm;	(* first buffer on reassembly list *)
		IF (p.state >= Established) & (buf # NIL) & (buf.int = p.rcvnxt) THEN
			REPEAT
				DEC(p.rcvspace, buf.len);
				INC(p.rcvnxt, buf.len);
				pf := buf.set * {Fin};
				buf := buf.next;
			UNTIL (buf = NIL) OR (buf.int # p.rcvnxt);
			p.rcvreasm := buf;
		ELSE
			EXCL(pf, Fin);
		END;
	END GotoPresent;


	PROCEDURE Reasm;
	VAR
		pos, last: Network.Buffer;
		lap: LONGINT;

	BEGIN
		buffer.set := pf;
		buffer.int := seq;
		INC(buffer.ofs, hdrLen + discard);
		buffer.len := tlen;

		IF p.rcvhead = NIL THEN
			(* insert into empty queue *)
			buffer.next := NIL;
			buffer.prev := NIL;
			p.rcvhead := buffer;
			p.rcvreasm := buffer;
			p.rcvtail := buffer;
			bufferQueued := TRUE;
		ELSE
			(* go to insert position, insert in front of pos and after last. *)
			pos := p.rcvreasm;
			IF pos = NIL THEN
				(* no reasm part of queue *)
				last := p.rcvtail;
			ELSE
				last := pos.prev;
				WHILE (pos # NIL) & (pos.int < seq) DO
					last := pos;
					pos := pos.next;
				END;
			END;
			IF last # NIL THEN
				(* check for overlap with previous buffer *)
				lap := (last.int + last.len) - seq;
				IF lap > 0 THEN
					(* some overlap - drop new data *)
					IF lap >= tlen THEN
						(* complete duplicate *)
						Error(DataDuplicatePrevComplete, tlen, p);
						RETURN;
					ELSE
						(* partial duplicate *)
						Error(DataDuplicatePrevPartial, lap, p);
						INC(buffer.ofs, lap);
						DEC(buffer.len, lap);
						DEC(tlen, lap);
						INC(seq, lap);
						buffer.int := seq;
					END;
				END;
			END;
			IF pos # NIL THEN
				(* check for overlap with next buffer *)
				lap := (seq + tlen) - pos.int;
				IF lap > 0 THEN
					(* some overlap - drop new data *)
					IF lap >= tlen THEN
						(* complete duplicate *)
						Error(DataDuplicateNextComplete, lap, p);
						RETURN;
					ELSE
						(* partial duplicate *)
						Error(DataDuplicateNextPartial, lap, p);
						DEC(tlen, lap);
						DEC(buffer.len, lap);
					END;
				END;
			END;
			Machine.AtomicInc(NTCPRcvPackSlow);
			Machine.AtomicAdd(NTCPRcvByteSlow, tlen);
			(* insert buffer into correct position in queue *)
			IF pos = NIL THEN
				(* insert at the end of the queue *)
				ASSERT(last = p.rcvtail);
				buffer.next := NIL;
				buffer.prev := last;
				buffer.prev.next := buffer;
				p.rcvtail := buffer;
				IF p.rcvreasm = NIL THEN
					p.rcvreasm := buffer;
				END;
			ELSIF last = NIL THEN
				(* insert at the beginning of the queue *)
				ASSERT((pos = p.rcvhead) & (pos = p.rcvreasm));
				buffer.prev := NIL;
				buffer.next := pos;
				buffer.next.prev := buffer;
				p.rcvhead := buffer;
				p.rcvreasm := buffer;
			ELSE
				(* insert somewhere in the middle *)
				ASSERT((last.next = pos) & (pos.prev = last));
				last.next := buffer;
				buffer.prev := last;
				pos.prev := buffer;
				buffer.next := pos;
				IF buffer.next = p.rcvreasm THEN
					p.rcvreasm := buffer;
				END;
			END;
			bufferQueued := TRUE;
		END;
		GotoPresent;
	END Reasm;

	PROCEDURE DoData;
	BEGIN
		IF ((tlen # 0) OR (Fin IN pf)) & (p.state < TimeWait) THEN
			IF (seq = p.rcvnxt) & (p.rcvreasm = NIL) & (p.state = Established) THEN
				INCL(p.flags, DelAck)
			ELSE
				INCL(p.flags, AckNow)	(* cf. fig. 27.15 *)
			END;
			Reasm();
		ELSE
			EXCL(pf, Fin)
		END;
		IF Fin IN pf THEN
			IF p.state < TimeWait THEN
				(*SoCantRcvMore(p);*)
				INCL(p.flags, AckNow); INC(p.rcvnxt)
			END;
			CASE p.state OF
				SynReceived, Established:
					p.state := CloseWait
				|FinWait1:
					p.state := Closing
				|FinWait2:
					p.state := TimeWait; CancelTimers(p); p.timer[MSL2] := 2 * MSL;
					(*SoIsDisconnected(p)*)
				|TimeWait:
					p.timer[MSL2] := 2 * MSL
				ELSE (* skip *)
			END (* CASE *)
		END;
		IF TraceProtocol THEN
			TraceTCP("Input", p, buffer.data, empty^, buffer.ofs+hdrLen, 0, 0)
		END;
		IF (NeedOutput IN lf) OR (AckNow IN p.flags) THEN Output(p) END
	END DoData;

	PROCEDURE Step6(): BOOLEAN;
	BEGIN
		IF (Ack IN pf) & ((p.sndwl1 - seq < 0) OR ((p.sndwl1 = seq) & ((p.sndwl2 - ack < 0) OR
				((p.sndwl2 = ack) & (win > p.sndwnd))))) THEN
			IF (tlen = 0) & (p.sndwl2 = ack) & (win > p.sndwnd) THEN Machine.AtomicInc(NTCPRcvWinUpd) END;
			p.sndwnd := win; p.sndwl1 := seq; p.sndwl2 := ack;
			IF p.sndwnd > p.maxsndwnd THEN p.maxsndwnd := p.sndwnd END;
			INCL(lf, NeedOutput)
		END;
		IF (Urg IN pf) & (urp # 0) & (p.state < TimeWait) THEN
			Error(NIYOutOfBand, 0, p); (* out-of-band data NIY *)
			(*IF urp + p.rcvcc > sbmax THEN*)
				urp := 0; EXCL(pf, Urg); DoData; RETURN FALSE;
			(*END;*)
		ELSE
			IF p.rcvnxt - p.rcvup > 0 THEN p.rcvup := p.rcvnxt END
		END;
		RETURN TRUE
	END Step6;


BEGIN
	lf := {};
	discard := 0; (* data from 0 to discard has to be thrown away. *)
	tlen := buffer.len-hdrLen; (* length of user data. *)
	optLen := hdrLen - MinTCPHdrLen; (* length of options *)

	pf := SYSTEM.VAL(SET, LONG(ORD(buffer.data[buffer.ofs+13])));

	IF optLen > 0 THEN (* TCP options present *)
		Machine.AtomicInc(NTCPRcvOptions);
		IF ProcOptions THEN
			IF DoRFC1323 THEN
				(* quick processing of timestamp option, fig. 28.4 *)
				IF ((optLen = 12) OR ((optLen > 12) & (buffer.data[buffer.ofs+MinTCPHdrLen+12] = 0X))) & ~(Syn IN pf) &
						(buffer.data[buffer.ofs+MinTCPHdrLen] = 1X) &
						(buffer.data[buffer.ofs+MinTCPHdrLen+1] = 1X) &
						(buffer.data[buffer.ofs+MinTCPHdrLen+2] = 8X) &
						(buffer.data[buffer.ofs+MinTCPHdrLen+3] = 0AX) THEN
					INCL(lf, TSPresent);
					tsval := Network.GetNet4(buffer.data, buffer.ofs+MinTCPHdrLen+4);
					tsecr := Network.GetNet4(buffer.data, buffer.ofs+MinTCPHdrLen+8);
				ELSE
					INCL(lf, Options);
				END;
			ELSE
				INCL(lf, Options);
			END
		END
	END;

	(* initialize variables needed for GotoDropReset *)
	seq := Network.GetNet4(buffer.data, buffer.ofs+4);
	ack := Network.GetNet4(buffer.data, buffer.ofs+8);

(*	pf := SYSTEM.VAL(SET, LONG(ORD(buffer.data[buffer.ofs+13])));*)
	IF p = nilpcb THEN
		IF packetDumpListener # NIL THEN packetDumpListener(p.fip, buffer) END;
		GotoDropReset; RETURN
	END;
	IF p.state <= Closed THEN GotoDrop; RETURN END;

	IF ~(Network.ChecksumTCP IN buffer.calcChecksum) THEN
		(* calculate checksum *)
		(* set pseudo header *)
		reassembledLength := 0;
		fragmentBuffer := buffer;
		WHILE fragmentBuffer # NIL DO
			INC(reassembledLength, fragmentBuffer.len);
			fragmentBuffer := fragmentBuffer.nextFragment;
		END;

		pseudoHdrLen := p.int.WritePseudoHeader(pseudoHdr, p.fip, p.int.localAdr, IPTypeTCP, reassembledLength);
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

		IF sum # 0 THEN
			Error(BadChecksum, 0, p);
			GotoDrop;
			RETURN;
		END;
	END;

	win := Network.GetNet2(buffer.data, buffer.ofs+14);
	urp := Network.GetNet2(buffer.data, buffer.ofs+18);

	IF ~(Syn IN pf) THEN win := ASH(win, p.sndscale) END;

	p.idle := 0; p.timer[Keep] := KeepIdle;
	IF ProcOptions & (Options IN lf) & (p.state # Listen) THEN ProcessOptions END;

	(* header prediction (fig. 28.11-13) *)
	IF (p.state = Established) & (pf * {Syn,Fin,Rst,Urg,Ack} = {Ack}) &
			(~DoRFC1323 OR ~(TSPresent IN lf) OR (tsval - p.tsrecent >= 0)) & (seq = p.rcvnxt) &
			(win # 0) & (win = p.sndwnd) & (p.sndnxt = p.sndmax) THEN
		IF DoRFC1323 & (TSPresent IN lf) & (seq - p.lastacksent <= 0) THEN
			p.tsrecentage := timeSource.now;
			p.tsrecent := tsval; (* see p. 937 & fig. 26.20 *)
		END;
		IF tlen = 0 THEN
			IF (ack - p.snduna > 0) & (ack - p.sndmax <= 0) & (p.sndcwnd >= p.sndwnd) & (p.dupacks < ReXmtThresh) THEN
				(* p.dupacks < ReXmtThres fix from "Performance Problems in 4.4BSD TCP" *)
				Machine.AtomicInc(NTCPPredAck);
				IF DoRFC1323 & (TSPresent IN lf) THEN XmitTimer(p, timeSource.now - tsecr + 1)
				ELSIF (p.rtt # 0) & (ack - p.rtseq > 0) THEN XmitTimer(p, p.rtt)
				ELSE (* skip *)
				END;
				acked := ack - p.snduna;
				Machine.AtomicInc(NTCPAckPack); Machine.AtomicAdd(NTCPAckByte, acked);
				SbDrop(p, acked);
				p.snduna := ack;
				IF ack = p.sndmax THEN p.timer[ReXmt] := 0
				ELSIF p.timer[Persist] = 0 THEN
					p.timer[ReXmt] := p.rxtcur;
				ELSE (* skip *)
				END;
				(*IF Notify IN p.flags THEN SoWakeup(p) END;*)
				IF p.sndcc # 0 THEN Output(p) END;
				RETURN
			END
		ELSIF (ack = p.snduna) & (p.rcvreasm = NIL) & (tlen <= p.rcvspace) THEN
			Machine.AtomicInc(NTCPPredData);
			Machine.AtomicInc(NTCPRcvPackFast);
			Machine.AtomicAdd(NTCPRcvByteFast, tlen);
			(* can assume no overlap with last or next buffers *)
			Reasm; (* queue the buffer directly *)
			(*SoWakeup(p);*)
			INCL(p.flags, DelAck);
			RETURN
		ELSE
			(* skip - continue to slow path *)
		END
	END;

	(* slow path *)
	p.rcvwnd := Strings.Max(Strings.Max(p.rcvspace, 0), p.rcvadv - p.rcvnxt);
	CASE p.state OF
		Listen:
			IF ProcessListen() THEN Trim1 ELSE RETURN END
		|SynSent:
			IF ProcessSynSent() THEN Trim1 ELSE RETURN END
		ELSE
			IF DoRFC1323 & ~Paws() THEN RETURN END;
			IF (p.rcvnxt - seq > 0) & ~Trim2(p.rcvnxt - seq) THEN RETURN END;
			(*IF (Gone IN p.flags) & (p.state > CloseWait) & (tlen # 0) THEN
				CloseConnection(p); Machine.AtomicInc(NTCPRcvAfterClose); GotoDropReset; RETURN
			END;*)
			IF ((seq + tlen) - (p.rcvnxt + p.rcvwnd) > 0) & ~Trim3((seq + tlen) - (p.rcvnxt + p.rcvwnd)) THEN RETURN END;
			IF DoRFC1323 & (TSPresent IN lf) & (seq - p.lastacksent <= 0) THEN RecordTS END;
			IF (Rst IN pf) & ~ProcessRst() THEN RETURN END;
			IF Syn IN pf THEN Drop(p, ConnectionReset); GotoDropReset; RETURN END;
			IF ~(Ack IN pf) THEN GotoDrop; RETURN END;
			IF ~ProcessAck() THEN RETURN END;
	END; (* CASE *)
	IF ~Step6() THEN RETURN END;
	DoData;
END ProcessInput;


(* Initialize a new Connection. *)
PROCEDURE InitConnection(p: Connection);
VAR
	buf: SendBuffer;

BEGIN
	IF ~NewZeros THEN	(* clear all fields *)
		CancelTimers(p);
		p.fip := IP.NilAdr; p.fport := NilPort; p.rxtshift := 0; p.dupacks := 0;
		p.snduna := 0; p.sndnxt := 0; p.sndup := 0; p.sndwl1 := 0; p.sndwl2 := 0; p.iss := 0;
		p.sndwnd := 0; p.rcvwnd := 0; p.rcvnxt := 0; p.rcvup := 0; p.irs := 0; p.rcvadv := 0;
		p.sndmax := 0; p.idle := 0; p.rtt := 0; p.rtseq := 0; p.maxsndwnd := 0;
		p.sndscale := 0; p.rcvscale := 0; p.requestrscale := 0; p.requestedsscale := 0;
		p.tsrecent := 0; p.tsrecentage := 0; p.lastacksent := 0; p.error := 0; p.acceptable := 0;
		p.sndcc := 0; p.poolNext := NIL; p.parent := NIL; p.acceptNext := NIL
	END;
		(* initialize fields *)
	p.maxseg := MSS; p.state := Closed;
	IF DoRFC1323 THEN p.flags := {ReqScale,ReqTstmp} ELSE p.flags := {} END;
	p.srtt := SRTTBase; p.rttvar := SRTTDflt * 4; p.rttmin := MinTime;
	RangeSet(p.rxtcur, (SRTTBase DIV 4 + SRTTDflt * 4) DIV 2, MinTime, ReXmtMax);
	p.sndcwnd := ASH(MaxWin, MaxWinShift);
	p.sndssthresh := ASH(MaxWin, MaxWinShift);
	p.sndspace := MaxSendSpace;
	p.rcvspace := MaxRecvSpace;
	p.rcvhiwat := MaxRecvSpace;
	WHILE (p.requestrscale < MaxWinShift) & (ASH(MaxWin, p.requestrscale) < p.rcvhiwat) DO
		INC(p.requestrscale)
	END;
	Machine.AtomicInc(NTCPNewBufs);
		(* allocate send buffer *)
	NEW(buf); NEW(buf.data, MSS * SegsPerBuf);
	IF ~NewZeros THEN buf.ofs := 0; buf.len := 0; END;
	buf.next := buf; p.sndhead := buf; p.sndtail := buf;
	NEW(p.sndcontig, MSS);
	(* init receive buffer *)
	p.rcvhead := NIL;
END InitConnection;


(* Move connection to next state in close process. *)
PROCEDURE UsrClosed(p: Connection);
BEGIN
	CASE p.state OF
		Closed, Listen, SynSent:
			p.state := Closed; CloseConnection(p)
		|SynReceived, Established:
			p.state := FinWait1
		|CloseWait:
			p.state := LastAck
		ELSE (* skip *)
	END;
	(*IF p.state >= FinWait2 THEN SoIsDisconnected(p) END*)
END UsrClosed;


(* If t is not zero, decrement it. Return true if it has reached 0, false otherwise. *)
PROCEDURE Expired(VAR t: LONGINT): BOOLEAN;
BEGIN
	IF t # 0 THEN DEC(t); RETURN t = 0 ELSE RETURN FALSE END
END Expired;

PROCEDURE GetID(): LONGINT;
VAR id, time, date: LONGINT;
BEGIN
	Clock.Get(time, date);
	id := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, time) / SYSTEM.VAL(SET, date));
	RETURN id;
END GetID;


(** Aos command - display all errors *)
PROCEDURE DisplayErrors*(context : Commands.Context);
VAR i: LONGINT;
BEGIN
	FOR i := 1 TO NumErrors-1 DO
		IF NTCPError[i] # 0 THEN
			context.out.String("TCP: Error "); context.out.Int(i+MinError, 1);
			context.out.String(" "); context.out.Int(NTCPError[i], 1); context.out.Ln;
		END;
	END;
END DisplayErrors;


(** Aos command - discard and finalize all connections *)
PROCEDURE DiscardAll*;
BEGIN
	pool.Finalize();
END DiscardAll;


(** Temporary trace procedure. *)
PROCEDURE ToggleTrace*;
BEGIN
	trace := ~trace;
	KernelLog.Enter; KernelLog.String("TCP trace ");
	IF trace THEN KernelLog.String("on") ELSE KernelLog.String("off") END;
	KernelLog.Exit
END ToggleTrace;

PROCEDURE Init;
VAR i: LONGINT;
BEGIN

	FOR i := 0 TO MaxRxtShift DO
		IF i < 6 THEN backoff[i] := ASH(1, i) ELSE backoff[i] := 64 END;
		INC(totbackoff, backoff[i])
	END;

(*	maxdiff := 0;*)
(*	backoff[0]:=1;
	backoff[1]:=1;
	backoff[2]:=2;
	backoff[3]:=3;
	backoff[4]:=5;
	backoff[5]:=10;
	backoff[6]:=18;
	backoff[7]:=30;
	backoff[8]:=60;
	backoff[9]:=120;
	backoff[10]:=240;
	backoff[11]:=240;
	backoff[12]:=240;*)
	ASSERT(MaxRxtShift=12);
	totbackoff := 0;
	FOR i:=0 TO MaxRxtShift DO
		INC(totbackoff, backoff[i]);
	END;

	(* Flags used when sending segments in tcp_output. Basic flags {Rst, Ack, Syn, Fin} are totally determined by state, with the proviso that Fin is sent only if all data queued for output is included in the segment. The {Psh,Urg} flags are set as necessary.
	*)
	outflags[Closed] := {Rst,Ack}; outflags[Listen] := {}; outflags[SynSent] := {Syn};
	outflags[SynReceived] := {Syn,Ack}; outflags[Established] := {Ack};
	outflags[CloseWait] := {Ack}; outflags[FinWait1] := {Fin,Ack}; outflags[Closing] := {Fin,Ack};
	outflags[LastAck] := {Fin,Ack}; outflags[FinWait2] := {Ack}; outflags[TimeWait] := {Ack};

	(* other globals *)
	NEW(nilpcb);
	nilpcb.lport := -1; (* can never match *)
	nilpcb.int := NIL;
	IF ~NewZeros THEN nilpcb.rcvspace := 0; nilpcb.rcvscale := 0 END;	(* for Respond *)
	lastpcb := nilpcb;
	NEW(empty, 1);
	NEW(pool);
	NEW(issSource, GetID());
	NEW(timeSource)
END Init;

PROCEDURE Cleanup;
BEGIN
	IP.RemoveReceiver(IPTypeTCP);
	pool.Finalize();
	timeSource.Finalize();
END Cleanup;

BEGIN
	ASSERT(~DoRFC1323 OR (ProcOptions & GenOptions)); (* constants should make sense *)
	ASSERT(SYSTEM.VAL(LONGINT, {Fin}) = 1);	(* bit order for flags cast in Input, Output and Respond *)
	ASSERT((TimerPeriod MOD FastPeriod = 0) & (TimerPeriod MOD SlowPeriod = 0));
	trace := FALSE;
	Init();
	IP.InstallReceiver(IPTypeTCP, Input);
	Modules.InstallTermHandler(Cleanup);
END TCP.

(*
History:
08.11.2003	mvt	Changed for new interface of IP and Network.
08.11.2003	mvt	Fixed array position error in ProcessOptions().
09.11.2003	mvt	Min()/Max() functions now in inline assembler.
10.11.2003	mvt	Added InterfaceClosed detection in Connection.SlowTimer().
10.11.2003	mvt	Added correct finalization of Connection, ConnectionPool, Timer and the module itself.
11.11.2003	mvt	Completely changed receive buffer queueing, integrated Network buffers directly.
12.11.2003	mvt	Completely changed ConnectionPool, now working with a hash table.
12.12.2003	mvt	Bugfixed entire module by comparing it with the book.
12.12.2003	mvt	Completed header prediction code according to the book.
12.12.2003	mvt	Added support for RFC1323 (timestamp, PAWS).
12.12.2003	mvt	Added support for window scaling (for windows >64KB).
14.02.2004	mvt	Fixed reassembly bug in Reasm().
14.02.2004	mvt	Fixed MSS option sending bug in Output().
28.02.2004	mvt	Fixed early Fin sending bug in Output().
04.03.2004	rp	  Fixed & (p.dupacks < ReXmtThresh) in Step6 according to ftp://ftp.cs.arizona.edu/xkernel/papers/tcp_problems.ps
04.03.2004	rp 	 Fixed XmitTimer according to  ftp://ftp.cs.arizona.edu/xkernel/papers/tcp_problems.ps
02.05.2005	eb	Supports IPv6 (WritePseudoHdr) and fragmented IP packets.
*)

(*
 * Copyright (c) 1982, 1986, 1993
 *      The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by the University of
 *      California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *)

(* pjm:

Gigabit:
Alteon AceNIC / 3Com 3C985 / NetGear GA620 Gigabit Ethernet Adapter
http://sanjose.alteon.com/open.shtml

Linux Driver
http://home.cern.ch/~jes/gige/acenic.html

Packet Engines Hamachi Driver
http://www.nscl.msu.edu/~kasten/perf/hamachi/

A Connection has to react to external and internal events
1. User calls (external)
	Connection.Open
	Connection.Send
	Connection.Receive
	Connection.Available
	Connection.Close
2. Timer.HandleTimeout (internal)
	Connection.DelayedAck
	Connection.SlowTimer
3. Packet arrival (external)
	Connection.Input (from Input)

The Timer reacts to external and internal events
1. Timer.HandleTimeout (external)
2. Timer.GetISS (internal - only called from Connection.Open, which is only called externally)

The ConnectionPool reacts to external and internal events
1. Lookup (internal)
2. Enumerate (external)
3. Add (internal)
4. Remove (internal)
*)