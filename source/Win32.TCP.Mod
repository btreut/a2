(* Aos Runtime: TCP, Copyright 2005, Emil J. Zeller *)

(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE TCP;   (** AUTHOR "pjm, mvt"; PURPOSE "TCP protocol"; *)

IMPORT
	WSock32, Modules, Kernel, Streams, IP, Objects, KernelLog,SYSTEM;

CONST
	Trace = FALSE;

	NilPort* = 0;

	(** Error codes *)
	Ok* = 0;  ConnectionRefused* = 3701;  NotConnected* = 3705;  TimedOut* = 3704;

	(** TCP connection states *)
	(** TCP connection states *)
	NumStates* = 12;  Closed* = 0;  Listen* = 1;  SynSent* = 2;
	SynReceived* = 3;  Established* = 4;  CloseWait* = 5;  FinWait1* = 6;
	Closing* = 7;  LastAck* = 8;  FinWait2* = 9;  TimeWait* = 10;
	Unused* = 11;   (* no real state, only used in this implementation *)

	OpenStates* = {Listen, SynReceived, Established, CloseWait, FinWait1, FinWait2};
	ClosedStates* = {Unused, Closed, Closing, LastAck, TimeWait};
	HalfClosedStates* = ClosedStates + {FinWait1, FinWait2};
	FinStates* = {Unused, Closed, CloseWait, Closing, LastAck, TimeWait};  Timeout = 14;


	(*AckNow = 0;   *)  (* send Ack immediately *)
	(* DelAck = 1;*)  (* send Ack, but try to delay it *)
	NoDelay = 2;   (* don't delay packets tocoalesce (disable Nagle algorithm) *)
	DoKeepAlive = 3;   (* enable keep-alive timer *)

TYPE

	(** Connection object. NOTE: Only one process should access a Connection! *)
	Connection* = OBJECT (Streams.Connection)
	VAR
		(* assigned interface *)
		int-: IP.Interface;
		(* local protocol address *)
		lport-: LONGINT;
		(* foreign protocol address *)
		fip-: IP.Adr;
		fport-: LONGINT;
		state*: SHORTINT;   (* TCP state *)
		(* send sequence *)
		sndnxt-: LONGINT;   (* send next *)
		iss-: LONGINT;   (* initial send sequence number *)
		(* receive sequence *)
		rcvnxt-: LONGINT;   (* receive next *)
		irs-: LONGINT;   (* initial receive sequence number *)
		socket: WSock32.Socket;
		sndwnd-: LONGINT;   (* send window *)
		sndcwnd-: LONGINT;   (* congestion-controlled window *)
		sndcc-: LONGINT;   (* number of bytes in send buffer *)
		rcvwnd-: LONGINT;   (* receive window *)
		srtt-: LONGINT;   (* smoothed round trip time *)
		(* receiver: Receiver;  *)
		(* sender: Sender;  *)
		(* lip: IP.Adr; *)

		timeout: Objects.Timer;
		flags: SET;

		(* Initialization for internal use only. *)
		PROCEDURE & Init*;
		BEGIN
			state := Unused;
			socket := WSock32.InvalidSocket;   (*  NEW(inbuf,receive,send); *)  (*NEW( receiver, SELF.receive );  *)
			(*NEW( sender, SELF.send );  *)
		END Init;

	(** Open a TCP connection (only use once per Connection instance).
				Use TCP.NilPort for lport to automatically assign an unused local port.
			*)
		PROCEDURE Open*( lport: LONGINT;  fip: IP.Adr;  fport: LONGINT;  VAR res: LONGINT );
		VAR adr: WSock32.sockaddrIn;  err: LONGINT; str: ARRAY 64 OF CHAR;
		BEGIN {EXCLUSIVE}
			IF Trace THEN
				KernelLog.Enter;  KernelLog.String( "Open connection: lport=" );  KernelLog.Int( lport, 1 );
				KernelLog.String( " ,fip=" );  IP.AdrToStr( fip, str );  KernelLog.String( str );
				KernelLog.String( " ,fport=" );  KernelLog.Int( fport, 1 );  Report( SELF );  KernelLog.Exit;
			END;
			ASSERT ( (state = Unused) & (lport >= 0) & (lport < 10000H) & (fport >= 0) & (fport < 10000H) );
			IF (fip.usedProtocol # IP.IPv4) THEN
				KernelLog.String("TCP.Connection.Open: Warning: Connection to non-IPv4 host not supported!"); KernelLog.Ln;
				res := NotConnected;
				RETURN;
			END;

			IF socket = WSock32.InvalidSocket THEN
				socket := WSock32.socket( WSock32.AFINet, WSock32.SockStream, WSock32.IPProtoTCP );
				ASSERT ( socket # WSock32.InvalidSocket );
				pool.Add( SELF, SELF.Finalize )
			END;
			IF ~IP.IsNilAdr(fip) & (fport # NilPort) THEN  (* active open (connect) *)
				IF Trace THEN KernelLog.Enter;  KernelLog.String( "Active open" );  Report( SELF );  KernelLog.Exit; END;

				int := IP.InterfaceByDstIP( fip );

				SELF.lport := lport;  SELF.fip := fip;  SELF.fport := fport;

				IF lport # NilPort THEN
					adr.sinFamily := WSock32.PFINet;  adr.sinAddr := 0;
					adr.sinPort := WSock32.htons( SHORT( lport ) );
					err := WSock32.bind( socket, adr, SIZEOF( WSock32.sockaddrIn ) );
					IF err # 0 THEN
						res := NotConnected;  state := Closed;  WSock32.DispError;
						RETURN
					END
				END;

				adr.sinFamily := WSock32.PFINet;   (* SYSTEM.MOVE( ADDRESSOF( fip ), ADDRESSOF( adr.sinAddr ), 4 ); *)
				adr.sinAddr := (fip.ipv4Adr);  adr.sinPort := WSock32.htons( SHORT( fport ) );
				err := WSock32.connect( socket, adr, SIZEOF( WSock32.sockaddrIn ) );
				IF err # 0 THEN
					res := NotConnected;  WSock32.DispError;  state := Closed;
					err := WSock32.closesocket( socket );
				ELSE res := Ok;  state := Established;  SetPortAndIp;
				END

			ELSE
				IF Trace THEN KernelLog.Enter;  KernelLog.String( "Passive open" );  Report( SELF );  KernelLog.Exit; END;
				(* passive open (listen) *)
				ASSERT ( (fport = NilPort) & IP.IsNilAdr(fip));
				SELF.int := NIL;  SELF.lport := lport;  SELF.fip := IP.NilAdr;
				SELF.fport := NilPort;  adr.sinFamily := WSock32.PFINet;
				adr.sinAddr := 0;  adr.sinPort := WSock32.htons( SHORT( lport ) );
				err := WSock32.bind( socket, adr, SIZEOF( WSock32.sockaddrIn ) );
				IF err = 0 THEN err := WSock32.listen( socket, WSock32.SOMaxConn ) END;
				IF err # 0 THEN
					res := NotConnected;  state := Closed;
					WSock32.DispError;
				ELSE
					SetPortAndIp;  res := Ok;  state := Listen
				END
			END;
			IF Trace THEN
				KernelLog.Enter; KernelLog.String( "Open connection, result = " ); ReportResult( res ); Report( SELF ); KernelLog.Exit;
			END;
			IF state = Established THEN  (* receiver.Start*) END;
		END Open;

	(** Send data on a TCP connection. *)
		PROCEDURE Send*( CONST data: ARRAY OF CHAR;  ofs, len: LONGINT;  propagate: BOOLEAN;  VAR res: LONGINT );
		VAR err : LONGINT;
		BEGIN
			ASSERT((ofs >= 0) & (ofs + len <= LEN(data)));

			IF state = Closed THEN res := NotConnected;  RETURN
			ELSIF state = Closing THEN
			ELSE
				ASSERT ((*state = Established) & *) (socket # WSock32.InvalidSocket) );
			END;

			res := Streams.Ok;
			err := WSock32.send( socket, data[ofs], len, {} );

			IF (err < 0) OR ((err = 0) & (len > 0)) THEN
				KernelLog.String( "TCP.Send :" );  WSock32.DispError;  res := NotConnected;
			END;
		END Send;

	(** Receive data on a TCP connection. The data parameter specifies the buffer. The ofs parameters specify the position in the buffer where data should be received (usually 0), and the size parameters specifies how many bytes of data can be received in the buffer. The min parameter specifies the minimum number of bytes to receive before Receive returns and must by <= size. The len parameter returns the number of bytes received, and the res parameter returns 0 if ok, or a non-zero error code otherwise (e.g. if the connection is closed by the communication partner, or by a call of the Close method). *)
		PROCEDURE Receive*( VAR data: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );
		VAR ret: LONGINT;
		BEGIN
			ASSERT ( (ofs >= 0) & (ofs + size <= LEN( data )) & (min <= size) );

			len := 0; res := Streams.Ok;

			BEGIN {EXCLUSIVE}
				IF state = Closed THEN res := NotConnected;  RETURN
				ELSIF state=CloseWait THEN res := Streams.EOF;  RETURN
				END;
			END;

			IF socket = WSock32.InvalidSocket THEN res := NotConnected;  RETURN
			END;

			IF (size = 0) OR ((min = 0) & (Available() = 0)) THEN res := Streams.Ok;  RETURN
			END;

			REPEAT
				ret := WSock32.recv( socket, data[ofs], size, {} );
				IF ret > 0 THEN INC( len, ret ); INC(ofs, ret); DEC(size, ret); END;
			UNTIL (size <= 0) OR (len >= min) OR (ret <= 0);

			IF ret < 0 THEN
				IF Trace THEN KernelLog.String( "TCP.Receiver.Receive" );  WSock32.DispError;  END;
				BEGIN {EXCLUSIVE}
					res := WSock32.shutdown( socket, WSock32.SDboth );
					res := WSock32.closesocket( socket );
					state := Closed;   res := Streams.EOF
				END;
			ELSIF ret = 0 THEN  (* connection has been gracefully shut down by remote side, otherwise recv would block  *)
				IF Trace THEN
					KernelLog.Enter;  KernelLog.String( "TCP.Connection.Receive, graceful shutdown by remote side " );  Report( SELF );  KernelLog.Exit;
				END;
				BEGIN {EXCLUSIVE}
					IF state = Established THEN res := WSock32.shutdown( socket, WSock32.SDReceive );   (* may not receive any more *) state := CloseWait;
					ELSIF state IN {FinWait1, FinWait2, Closing} THEN state := Closed;  res := WSock32.shutdown( socket, WSock32.SDboth );
					res := WSock32.closesocket( socket ); socket := WSock32.InvalidSocket;  pool.Remove( SELF );
					END;
					res := Streams.EOF
				END;
				IF Trace THEN
					KernelLog.Enter;  KernelLog.String( "Receive Result " );  ReportResult( res );
					Report( SELF );  KernelLog.Exit;
				END;
			END;
		END Receive;

	(** Return connection state. *)
		PROCEDURE State*( ): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN state
		END State;

		PROCEDURE HandleTimeout;
		BEGIN {EXCLUSIVE}
			INCL( flags, Timeout )
		END HandleTimeout;

		PROCEDURE AwaitState*( good, bad: SET;  ms: LONGINT;  VAR res: LONGINT );
		BEGIN {EXCLUSIVE}
			IF ~(state IN (good + bad)) THEN
				IF ms # -1 THEN
					IF timeout = NIL THEN NEW( timeout ) END;
					Objects.SetTimeout( timeout, SELF.HandleTimeout, ms )
				END;
				EXCL( flags, Timeout );
				AWAIT( (state IN (good + bad)) OR (Timeout IN flags) );
				IF ms # -1 THEN Objects.CancelTimeout( timeout ) END
			END;
			IF state IN good THEN res := Ok
			ELSIF state IN bad THEN res := NotConnected
			ELSE res := TimedOut
			END
		END AwaitState;

	(** Close a TCP connection (half-close). *)
		PROCEDURE Close*;
		VAR res: LONGINT; closetimer: Objects.Timer; (* fof 070102 *)
		BEGIN {EXCLUSIVE}
			IF state = Closed THEN RETURN END;
			(*IF receiver # NIL THEN receiver.Terminate END;  *)
			IF Trace THEN
				KernelLog.Enter;  KernelLog.String( "TCP.Connection.Close,  " );  Report( SELF );  KernelLog.Exit;
			END;
			(* ASSERT (  ((state = Listen) OR (state = Established) OR (state=Closing) ) &  (socket # WSock32.InvalidSocket) );  *)
			IF socket # WSock32.InvalidSocket THEN
				IF state = CloseWait THEN
					res := WSock32.shutdown( socket, WSock32.SDboth );
					state := Closed;  res := WSock32.closesocket( socket );
					socket := WSock32.InvalidSocket;  pool.Remove( SELF );
				ELSIF state = Established THEN
					res := WSock32.shutdown( socket, WSock32.SDSend );   (* may not send any more *)
					state := FinWait1;
					NEW(closetimer);
					Objects.SetTimeout(closetimer,SELF.Close,5000); (* 5 seconds time for receiving rest of data, i.e. by calling Available etc. *) (* fof 070102 *)
				ELSIF state IN {FinWait1, FinWait2, Closing, TimeWait} THEN
					res := WSock32.shutdown( socket, WSock32.SDboth );
					res := WSock32.closesocket( socket );
					socket := WSock32.InvalidSocket;  pool.Remove( SELF );
					state := Closed;
				ELSIF state = Listen THEN
					res := WSock32.shutdown( socket, WSock32.SDboth );
					state := Closed;  res := WSock32.closesocket( socket );
					socket := WSock32.InvalidSocket;  pool.Remove( SELF );
				END;
				IF Trace THEN KernelLog.Enter;  KernelLog.String( "Close done." );  Report( SELF );  KernelLog.Exit; END;
				(* half-close: use shutdown? *)
			END;
			(*state := Closed*) (* fof 070102 *)
		END Close;

		PROCEDURE SetPortAndIp;
		VAR sockname: WSock32.sockaddrIn;  lensockname: LONGINT;  res: LONGINT;
		BEGIN
			lensockname := SIZEOF( WSock32.sockaddrIn );
			res := WSock32.getsockname( socket, sockname, lensockname );
			IF res = Ok THEN
				(* lip := sockname.sinAddr; *)
				lport := WSock32.ntohs( sockname.sinPort );   (* lip := WSock32.ntohl( lip );  *)
			END;
			lensockname := SIZEOF( WSock32.sockaddrIn );
			res := WSock32.getpeername( socket, sockname, lensockname );
			IF res = Ok THEN
				fip.usedProtocol := IP.IPv4;
				fip.ipv4Adr := sockname.sinAddr;  fport := WSock32.ntohs( sockname.sinPort );
				fip.ipv4Adr := WSock32.ntohl( fip.ipv4Adr );
			END;
			IF Trace THEN KernelLog.Enter;  KernelLog.String( "SetPortAndIp " );  Report( SELF );  KernelLog.Exit; END;
		END SetPortAndIp;

	(** Accept a client waiting on a listening connection. Blocks until a client is available or the connection is closed. *)
		PROCEDURE Accept*( VAR client: Connection;  VAR res: LONGINT );
		VAR s: WSock32.Socket;  adr: WSock32.sockaddrIn;  adrlen: LONGINT;
			str: ARRAY 64 OF CHAR;
		BEGIN
			IF Trace THEN KernelLog.Enter;  KernelLog.String( "Accepting connections" );  Report( SELF );  KernelLog.Exit; END;
			ASSERT ( (state = Listen) & (socket # WSock32.InvalidSocket) );
			adr.sinFamily := WSock32.PFINet;  adrlen := SIZEOF( WSock32.sockaddrIn );
			s := WSock32.accept( socket, adr, adrlen );   (* blocks ! *)

			BEGIN {EXCLUSIVE}
				IF s # WSock32.InvalidSocket THEN
					NEW( client );  client.lport := NilPort;
					IF (adrlen = SIZEOF( WSock32.sockaddrIn )) &
						(adr.sinFamily = WSock32.PFINet) THEN
						client.fip.usedProtocol := IP.IPv4;
						client.fip.ipv4Adr := adr.sinAddr;   (* WSock32.ntohl( adr.sinAddr ); *)
						client.fport := WSock32.ntohs( adr.sinPort )
					ELSE client.fip := IP.NilAdr;  client.fport := NilPort
					END;
					client.int := IP.InterfaceByDstIP( client.fip );
					pool.Add( client, client.Finalize );  client.socket := s;
					client.state := Established;  res := Ok;  client.SetPortAndIp;

					(*client.receiver.Start;  *)
					IF Trace THEN
						KernelLog.Enter;  KernelLog.String( "Accepted connection: client lport=" );  KernelLog.Int( client.lport, 1 );
						KernelLog.String( " ,fip=" );  IP.AdrToStr( client.fip, str );
						KernelLog.String( str );  KernelLog.String( " ,fport=" );
						KernelLog.Int( client.fport, 1 );  Report( SELF );  KernelLog.Exit;
					END;
				ELSE client := NIL;  res := ConnectionRefused
				END;
			END;
		END Accept;

		PROCEDURE DelaySend*( enable: BOOLEAN );
		BEGIN {EXCLUSIVE}
			IF enable THEN EXCL( flags, NoDelay );  ELSE INCL( flags, NoDelay );  END;
		END DelaySend;

		PROCEDURE KeepAlive*( enable: BOOLEAN );
		BEGIN {EXCLUSIVE}
			IF enable THEN INCL( flags, DoKeepAlive );  ELSE EXCL( flags, DoKeepAlive );  END;
		END KeepAlive;

		PROCEDURE Discard*;
		BEGIN
			(* SetState( Closed ); *) Close;   (*  ConnectionFinalizer( SELF ); *)
		END Discard;

		PROCEDURE Requested*( ): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN FALSE;
		END Requested;

		PROCEDURE Available*( ): LONGINT;
		VAR ret, res: LONGINT;  fdset: WSock32.FDSet;
			data: ARRAY 256 OF CHAR;
		BEGIN  (* {EXCLUSIVE} *)
			(* IF Trace THEN KernelLog.String("available: "); KernelLog.Int(receiver.Available(),1); KernelLog.Ln END; *)
			ret := WSock32.ioctlsocket( socket, WSock32.FIONRead, res );
			IF ret # 0 THEN KernelLog.String( "TCP.Available " );  WSock32.DispError;  END;
			IF res = 0 THEN  (* check socket for shutdown *)
				fdset.fdcount := 1;  fdset.socket[0] := socket;
				(* KernelLog.String("select..."); *)
				ret := WSock32.select( 0, fdset, NIL , NIL , selectTimeout );
				IF ret = 1 THEN  (* nothing available but we can receive, try it: *)
					(* KernelLog.Enter;  KernelLog.String( " Available: trying to receive " );  KernelLog.Exit;  *)

					res := WSock32.recv( socket, data, 256, {1} );
					IF res = 0 THEN
						BEGIN {EXCLUSIVE}
							IF state = Established THEN state := CloseWait;  res := WSock32.shutdown( socket, WSock32.SDReceive ); (* may not receive any more *)
							ELSIF state IN {FinWait1, FinWait2, Closing} THEN
								state := Closed; res := WSock32.shutdown( socket, WSock32.SDboth ); res := WSock32.closesocket( socket );
								socket := WSock32.InvalidSocket;  pool.Remove( SELF );
							END;
						END;
						IF Trace THEN
							KernelLog.Enter;  KernelLog.String( "TCP.Connection.Available: graceful shutdown by remote side." );  Report( SELF );  KernelLog.Exit;
						END;
					ELSIF res < 0 THEN
						IF Trace THEN KernelLog.String( "TCP.Receiver.Receive: " );  WSock32.DispError;  END;
						res := 0;
						BEGIN {EXCLUSIVE}
							state := CloseWait;
						END;
					END;
				END;
			END;
			RETURN res;
		END Available;

	(* Finalize the Connection object *)
		PROCEDURE Finalize( ptr: ANY );
		VAR res: LONGINT;
		BEGIN {EXCLUSIVE}
			IF Trace THEN KernelLog.Enter;  KernelLog.String( "TCP.Finalize " );  Report( SELF );  KernelLog.Exit; END;
			ASSERT ( ptr = SELF );
			IF socket # WSock32.InvalidSocket THEN
				res := WSock32.shutdown( socket, WSock32.SDboth );
				res := WSock32.closesocket( socket );
				(* ASSERT ( res = 0 );  *)
				socket := WSock32.InvalidSocket;
				(* pool.Remove(SELF) *)  (* done outside !*)
			END;
			state := Unused
		END Finalize;

	END Connection;

VAR
	pool*: Kernel.FinalizedCollection;   (* pool of all Connections *)
	selectTimeout: WSock32.TimeVal;

	PROCEDURE Init;
	BEGIN
		NEW( pool ); NEW(selectTimeout); (* zero *)
	END Init;

	PROCEDURE Finalize( obj: ANY;  VAR cont: BOOLEAN );
	BEGIN
		obj( Connection ).Finalize( obj );  cont := TRUE
	END Finalize;

	PROCEDURE Cleanup;
	BEGIN
		pool.Enumerate( Finalize )
	END Cleanup;

	PROCEDURE ReportState( state: LONGINT );
	BEGIN
		KernelLog.String( "State=" );
		CASE state OF
		Closed:
				KernelLog.String( "Closed" )
		| Listen:
				KernelLog.String( "Listen" );
		| SynSent:
				KernelLog.String( "SynSent" );
		| SynReceived:
				KernelLog.String( "SynReceived" );
		| Established:
				KernelLog.String( "Established" );
		| CloseWait:
				KernelLog.String( "CloseWait" );
		| FinWait1:
				KernelLog.String( "FinWait1" );
		| FinWait2:
				KernelLog.String( "FinWait2" );
		| TimeWait:
				KernelLog.String( "TimeWait" );
		| Unused:
				KernelLog.String( "Unused" );
		ELSE KernelLog.String( "????" );
		END;
	END ReportState;

	PROCEDURE Report( c: Connection );
	VAR str: ARRAY 64 OF CHAR;
	BEGIN
		KernelLog.String( " [lport=" );  KernelLog.Int( c.lport, 1 );  KernelLog.String( " ,fip=" );
		IP.AdrToStr( c.fip, str );  KernelLog.String( str );  KernelLog.String( " ,fport=" );
		KernelLog.Int( c.fport, 1 );  KernelLog.String( "," );  ReportState( c.state );
		KernelLog.String( "]" );
	END Report;

	PROCEDURE ReportResult( res: LONGINT );
	BEGIN
		IF res = Ok THEN KernelLog.String( "Ok" );
		ELSIF res = ConnectionRefused THEN KernelLog.String( "ConnectionRefused" )
		ELSIF res = NotConnected THEN KernelLog.String( "NotConnected" )
		ELSIF res = TimedOut THEN KernelLog.String( "TimedOut" );
		ELSIF res = Streams.EOF THEN KernelLog.String( "Streams.EOF" );
		ELSE KernelLog.String( "Unknown result code=" );  KernelLog.Int( res, 1 );
		END;
	END ReportResult;

BEGIN
	Init;  Modules.InstallTermHandler( Cleanup )
END TCP.

state diagram in this version of TCP very much simplified (rest done by Windows):

either

closed -> Listen -> Established -> CloseWait | FinWait1 -> Closed

or

closed -> Established -> CloseWait | FinWait1 -> Closed

