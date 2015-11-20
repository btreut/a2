MODULE UDP;   (* AUTHOR "fof"; PURPOSE "UDP protocol for Winsock"; *)

IMPORT SYSTEM, IP, (* AosWinsock, *) WSock32, KernelLog;

CONST
	(* error codes. *)
	Ok* = 0;  AddressInUse* = 3501;  Timeout* = 3502;  BufferOverflow* = 3503;  AlreadyBlocked* = 3504;
	PortInUse* = 3501;

	unknown = 1;  IPAdrLen = 4;
	NilPort* = 0;  (* Dan 31.01.05 *)

	SendBufSize = 65536*8; (* send buffer size in bytes *)
	RecvBufSize = 65536*16; (* receive buffer size in bytes *)

TYPE

TYPE
	Socket* = OBJECT  (* stores the state of a UDP communication endpoint. *)
	VAR sock: WSock32.Socket;

		(* Initialize the Socket (only use once per instance).
	Opens a socket which is dedicated to datagram services. lport is registered to receive datagrams
	from any port and any host. *)
		PROCEDURE & Open*( lport: LONGINT;  VAR res: LONGINT );
		VAR
			sadr: WSock32.sockaddrIn;
			err: LONGINT;
			bufSize, len: LONGINT;
		BEGIN
			(* IF ~AosWinsock.ready THEN RETURN END;  *)
			sock := WSock32.socket( WSock32.PFINet, WSock32.SockDGram, WSock32.IPProtoUDP );
			IF sock # WSock32.InvalidSocket THEN
				sadr.sinFamily := WSock32.PFINet;  sadr.sinAddr := 0;
				IF lport # NilPort THEN sadr.sinPort := WSock32.htons( SHORT( lport ) ) ELSE sadr.sinPort := 0 END;
				res := WSock32.bind( sock, sadr, SIZEOF( WSock32.sockaddrIn ) );
				IF res # Ok THEN
					err := WSock32.WSAGetLastError(); (*  AosWinsock.DispError( err ); *)  SockFinalizer( SELF );  res := unknown;
				ELSE (*  Kernel.RegisterObject( SELF, SockFinalizer, FALSE ); *)  res := Ok
				END
			ELSE res := unknown;
			END;
			
			bufSize := SendBufSize; len := SIZEOF(LONGINT);
			err := WSock32.setsockopt(sock,WSock32.SOLSocket,WSock32.SOSndBuf,bufSize,len);
			IF (err # 0) & trace THEN
				KernelLog.String( "UDP.Open : failed to set send buffer size, WSock32 error code " ); KernelLog.Int(err,0); KernelLog.Ln;
			END;
			bufSize := RecvBufSize;
			err := WSock32.setsockopt(sock,WSock32.SOLSocket,WSock32.SORcvBuf,bufSize,SIZEOF(LONGINT));
			IF (err # 0) & trace THEN
				KernelLog.String( "UDP.Open : failed to set receive buffer size, WSock32 error code " ); KernelLog.Int(err,0); KernelLog.Ln;
			END;

			IF trace THEN
				KernelLog.String( "UDP.Open : " );  KernelLog.Int( lport, 1 );  KernelLog.String( "(" );  KernelLog.Int( res, 1 );
				KernelLog.String( ")" );  KernelLog.Ln;
			END;
		END Open;

	(* Send a UDP datagram to the foreign address specified by "fip" and "lport".  The data is in "data[ofs..ofs+len-1]".
					 In case of concurrent sends the datagrams are serialized.
	Sends len bytes of data (beginning at pos in buf) to the host specified by remIP and remPort. *)

		PROCEDURE Send*( fip: IP.Adr;  fport: LONGINT;  CONST data: ARRAY OF CHAR;  ofs, len: LONGINT; VAR res: LONGINT );
		VAR sadr: WSock32.sockaddrIn;  err: LONGINT;
		BEGIN
			ASSERT ( LEN( data ) >= (ofs + len) );
			IF (fip.usedProtocol = IP.IPv4) THEN
				SYSTEM.MOVE( ADDRESSOF( fip ), ADDRESSOF( sadr.sinAddr ), IPAdrLen );
				sadr.sinFamily := WSock32.PFINet;  sadr.sinPort := WSock32.htons( SHORT( fport ) );
				res := WSock32.sendto( sock, data[ofs], len, 0, sadr, SIZEOF( WSock32.sockaddrIn ) );
				(* account that sendto returns number of bytes sent to the socket (Alexey) *)
				IF res = len THEN res := Ok; ELSE err := WSock32.WSAGetLastError(); res := unknown;  END;
			ELSE res := unknown;
			END;
			IF trace THEN
				IF (fip.usedProtocol = IP.IPv4) THEN
					KernelLog.String( "UDP.Send : " );  KernelLog.Int( fip.ipv4Adr, 1 );  KernelLog.String( " , " );  KernelLog.Int( fport, 1 );
					KernelLog.String( "(" );  KernelLog.Int( res, 1 );  KernelLog.String( ")" );  KernelLog.Ln;
				ELSE
					KernelLog.String("UDP.Send : Error, only works with IPv4 addresses!"); KernelLog.Ln;
				END;
			END;
		END Send;

	(* Receive a UDP datagram.  If none is available, wait up to the specified timeout for one to arrive.  Only one thread
					is allowed to wait for a datagram.  "data[ofs..ofs+size-1]" is the data buffer to hold the returned datagram.
					 "ms" is a timeout value in milliseconds, or 0 for an indefinite wait.  On return, "fip" and "lport" hold
					the foreign address.  "len" returns the actual datagram size and "data[ofs..ofs+len-1]" returns the data.
					 "res" returns "Timeout" in case of a timeout and "BufferOverflow" if the received datagram was too big,
					in which case "len" is the actual datagram size negated and the data is undefined.  "res" returns "AlreadyBlocked"
					if another thread is already blocked on this Socket.
	Stores an entire datagram in buf beginning at pos. On success (S.res = done), remIP and remPort indicate the sender, len indicate the length of valid data. *)

		PROCEDURE Receive*( VAR data: ARRAY OF CHAR;  ofs, size, ms: LONGINT;  VAR fip: IP.Adr;
										   VAR fport, len, res: LONGINT );
		VAR sadr: WSock32.sockaddrIn;  err: LONGINT;  l: LONGINT;
		ret: LONGINT;  fdset: WSock32.FDSet; avail: BOOLEAN; time: WSock32.TimeVal;
		BEGIN
			ASSERT ( ofs+size <= LEN( data ) );
			l := SIZEOF( WSock32.sockaddrIn );

			IF ms=-1 THEN (* do, as if data was available to invoke blocking call of recvfrom *)
				avail := TRUE;
			ELSE (* handle timeout *)
				ret := WSock32.ioctlsocket( sock, WSock32.FIONRead, res );
				IF ret # 0 THEN (* error *)
					err := WSock32.WSAGetLastError(); res := unknown; avail := FALSE;
				ELSE  (* no error *)
					avail := res > 0;
					IF ~avail THEN  (* nothing available yet *)
						fdset.fdcount := 1;  fdset.socket[0] := sock;
						IF ms = 0 THEN
							time := NIL
						ELSE
							NEW(time);
							time.sec := ms DIV 1000; time.musec := 1000* (ms MOD 1000);
						END;
						ret := WSock32.select( 0, fdset, NIL , NIL , time );
						avail := ret = 1;
						IF  ~avail THEN (* still nothing available *)
							len := 0; res := Timeout
						END;
					END;
				END;
			END;

			IF avail THEN
				len := WSock32.recvfrom( sock, data[ofs], size, 0, sadr, l );
				IF len < 0 THEN err := WSock32.WSAGetLastError(); (*  AosWinsock.DispError( err ); *)  res := unknown;
				ELSE res := Ok;
				END;
			END;

			fport := WSock32.ntohs( sadr.sinPort );
			SYSTEM.MOVE( ADDRESSOF( sadr.sinAddr ), ADDRESSOF( fip ), IPAdrLen );

			(*? Problem - Windows XP does not fill in the Fip.UseProtocol field for IPv4 packets ! done manually here*)
			IF fip.ipv4Adr # 0 THEN fip.usedProtocol := IP.IPv4 END;

			IF trace THEN
				IF (fip.usedProtocol = IP.IPv4) THEN
					KernelLog.String( "UDP.Receive : " );  KernelLog.Int( fip.ipv4Adr, 1 );  KernelLog.String( " , " );  KernelLog.Int( fport, 1 );
					KernelLog.String( "(" );  KernelLog.Int( res, 1 );  KernelLog.String( ")" );  KernelLog.Ln;
				ELSE
					KernelLog.String("UDP.Receive : Warning, received UDP packet from non-IPv4 source!"); KernelLog.Ln;
				END;
			END;

		END Receive;

	(* Close the Socket, freeing its address for re-use. *)
		PROCEDURE Close*;
		BEGIN
			SockFinalizer( SELF );
			IF trace THEN KernelLog.String( "UDP.Close" );  KernelLog.Ln;  END;
		END Close;
	(*
		(** Returns the size of the first available datagram on the socket, otherwise <= 0. *)
	PROCEDURE Available*(  ): LONGINT;
	VAR avail: LONGINT;
	BEGIN
		WSock32.ioctlsocket( sock, WSock32.FIONRead, avail );  RETURN avail
	END Available;
*)

	END Socket;

VAR
	trace: BOOLEAN;

	PROCEDURE SockFinalizer( S: ANY );
	VAR ret: LONGINT;																			(* Dan 10.11.05 *)	BEGIN
		WITH S: Socket DO
			IF S.sock # WSock32.InvalidSocket THEN  ret:= WSock32.closesocket( S.sock );  S.sock := WSock32.InvalidSocket END
		END
	END SockFinalizer;

	PROCEDURE ToggleTrace*;
	BEGIN
		trace := ~trace;
		IF trace THEN KernelLog.String( "UDP: tracing ON" );  KernelLog.Ln;
		ELSE KernelLog.String( "UDP: tracing OFF" );  KernelLog.Ln
		END;
	END ToggleTrace;

END UDP.