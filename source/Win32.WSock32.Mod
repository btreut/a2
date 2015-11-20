MODULE WSock32; (* AUTHOR "ejz, additions Alex Popescu"; PURPOSE " Win32 WSock32 APIs used by Oberon"; *)	
	
	IMPORT SYSTEM, Kernel32, Modules, User32,KernelLog;

	CONST
		MAXGETHOSTSTRUCT* = 1024;
		
		AFINet* = 2; PFINet* = AFINet;
		
		SockStream* = 1;
		IPProtoIP* = 0;
		IPProtoICMP* = 1;
		IPProtoIGMP* = 2;
		IPProtoTCP* = 6;
		IPProtoUDP* = 17;
		IPProtoRAW* = 255;
		InvalidSocket* = -1;
		
		SocketError*= -1;	SockDGram* = 2; SockRaw* = 3;
		
		FDRead* = 01H; FDWrite* = 02H; FDAccept *= 08H; FDConnect* = 010H; FDClose* = 020H;
		
		WSADescriptionLen* = 256; WSASysStatusLen* = 128;
		
		WSABaseErr = 10000;
		WSAEInProgress* = WSABaseErr+36; WSAEConnAborted* = WSABaseErr+53;
		WSAEConnReset* = WSABaseErr+54; WSAEShutdown* = WSABaseErr+58;
		WSAEInval* = WSABaseErr+22; WSAEWouldBlock* = WSABaseErr+35;
		WSAENoBufs* = WSABaseErr+55;
		WSAEConnRefused*= WSABaseErr+61;
		
		FIONRead* = 4004667FH;
		
		SOLSocket* = 0FFFFH; 
		SOMaxConn* = 07FFFFFFFH;
		SOSndBuf* = 01001H; (** send buffer size *)
		SORcvBuf* = 01002H; (** receive buffer size *)
		SOSndTimeo* = 01005H; SORcvTimeo* = 01006H;
		SIORcvAll* = LONGINT(98000001H);
		
		SDReceive*=0; SDSend*=1; SDboth* = 2; (* graceful shutdown modes *)
		
		MsgPeek* = 2;
		
	TYPE
		TimeVal* = POINTER TO TimeValDesc;
		TimeValDesc* = RECORD
			sec*,musec*: LONGINT; (* seconds and microseconds *)
		END;

		WSAData* = RECORD
			wVersion*, wHighVersion*: INTEGER;
			szDescription*: ARRAY WSADescriptionLen+1 OF CHAR;
			szSystemStatus*: ARRAY WSASysStatusLen+1 OF CHAR;
			iMaxSockets*, iMaxUdpDg*: INTEGER;
			lpVendorInfo*: ADDRESS
		END;

		inAddr* = LONGINT;

		PsockaddrIn* = POINTER TO sockaddrIn;
		sockaddrIn* = RECORD
			sinFamily*, sinPort*: INTEGER;
			sinAddr*: inAddr;
			inZero: ARRAY 8 OF CHAR
		END;

		Paddrinfo* = POINTER TO addrinfo;
		addrinfo* = RECORD
			aiFlags*: SET;
			aiFamily*, aiSocktype*, aiProtocol*: LONGINT;
			aiAddrlen*: LONGINT;
			aiCanonname*: ADDRESS;
			aiAddr*{UNTRACED}: PsockaddrIn;
			aiNext*{UNTRACED}: Paddrinfo
		END;

		Socket* = Kernel32.HANDLE;

		Group* = LONGINT;

		FDSet*=RECORD
			fdcount*: LONGINT;
			socket*: ARRAY 64 OF LONGINT;
		END;

		(** The Windows Sockets WSAPROTOCOL_INFO structure is used to store or retrieve complete information for
			a given protocol. *)
		WSAProtocolInfo* = RECORD
			data: ARRAY 372 OF SYSTEM.BYTE
		END;
		
		(** The Windows Sockets hostent structure is used by functions to store information about a given host,
			such as host name, IP address, and so forth. *)
		LPHostent* = ADDRESS;
		PHostent*= POINTER TO Hostent;
		Hostent* = RECORD
			hName*:ADDRESS; (* pointer to array of char *)
			hAliases*: ADDRESS; (* pointer to array of pointer to array of char *)
			hAddrtype*, hLength*: INTEGER;
			hAddrList*: ADDRESS;(* pointer to array of pointer of address (with len hLength) *)
		END;

		Error = OBJECT
		VAR
		nr: LONGINT;
		name: ARRAY 64 OF CHAR;
		msg: ARRAY 256 OF CHAR;
		left, right: Error;
	END Error;

	VAR
		wsock32: Kernel32.HMODULE;
		wship6: Kernel32.HMODULE; (*ALEX POPESCU 2005.11.25*)
		wsaStarted: BOOLEAN;
		errors: Error;

		(** The Windows Sockets WSACleanup function terminates use of the Ws2_32.dll. *)
		WSACleanup-: PROCEDURE {WINAPI} (): LONGINT;

		(** The Windows Sockets WSAAsyncGetHostByAddr function asynchronously retrieves host information that
			corresponds to an address. *)
		WSAAsyncGetHostByAddr-: PROCEDURE {WINAPI} (hWnd: User32.HWND; wMsg: LONGINT; VAR addr: ARRAY   OF SYSTEM.BYTE; len: LONGINT; type: LONGINT; VAR buf: ARRAY   OF SYSTEM.BYTE; buflen: LONGINT): Kernel32.HANDLE;

		(** The Windows Sockets WSAAsyncGetHostByName function asynchronously retrieves host information corresponding
			to a host name. *)
		WSAAsyncGetHostByName-: PROCEDURE {WINAPI} (hWnd: User32.HWND; wMsg: LONGINT; name: ARRAY   OF CHAR; VAR buf: ARRAY   OF SYSTEM.BYTE; buflen: LONGINT): Kernel32.HANDLE;

		(** The Windows Sockets WSAAsyncSelect function requests Windows message-based notification of network events
			for a socket. *)
		WSAAsyncSelect-: PROCEDURE {WINAPI} (s: Socket; hWnd: User32.HWND; wMsg: LONGINT; lEvent: LONGINT): LONGINT;

		(** The Windows Sockets WSAGetLastError function gets the error status for the last operation that failed. *)
		WSAGetLastError-: PROCEDURE {WINAPI} (): LONGINT;

		(** The Windows Sockets WSASocket function creates a socket that is bound to a specific transport-service provider. *)
		WSASocket-: PROCEDURE {WINAPI} (af, type, protocol: LONGINT; VAR lpProtocolInfo: WSAProtocolInfo; g: Group; dwFlags: LONGINT): Socket;

		(** The Windows Sockets WSAStartup function initiates use of Ws2_32.dll by a process. *)
		WSAStartup-: PROCEDURE {WINAPI} (wVersionRequested: LONGINT; VAR lpWSAData: WSAData): LONGINT;

		WSAIoctl-: PROCEDURE {WINAPI} (s: Socket; ioControlCode:LONGINT; VAR in: LONGINT; inSize:LONGINT;
				VAR outBuffer:ARRAY OF CHAR; outBufLen: LONGINT; VAR lenReturned:LONGINT;  Overlapped: LONGINT; completionRoutine: LONGINT): LONGINT;

		(** The Windows Sockets accept function permits an incoming connection attempt on a socket. *)
		accept-: PROCEDURE {WINAPI} (s: Socket; VAR addr: ARRAY   OF SYSTEM.BYTE; VAR addrlen: LONGINT): Socket;

		(** The Windows Sockets bind function associates a local address with a socket. *)
		bind-: PROCEDURE {WINAPI} (s: Socket; VAR name: ARRAY   OF SYSTEM.BYTE; namelen: LONGINT): LONGINT;

		(** The Windows Sockets closesocket function closes an existing socket. *)
		closesocket-: PROCEDURE {WINAPI} (s: Socket): LONGINT;

		(** The Windows Sockets connect function establishes a connection to a specified socket. *)
		connect-: PROCEDURE {WINAPI} (s: Socket; VAR name: ARRAY   OF SYSTEM.BYTE; namelen: LONGINT): LONGINT;

		freeaddrinfo-:PROCEDURE {WINAPI}(ai:Paddrinfo);
		getaddrinfo-: PROCEDURE {WINAPI}(VAR nodename, servname: ARRAY   OF CHAR; VAR hints: ARRAY   OF SYSTEM.BYTE; VAR res: Paddrinfo): LONGINT;

		(** The Windows Sockets gethostbyname function retrieves host information corresponding to a host name from a
			host database. *)
		gethostbyname-: PROCEDURE {WINAPI} (VAR name: ARRAY   OF CHAR): PHostent;

		(** The Windows Sockets gethostname function returns the standard host name for the local machine. *)
		gethostname-: PROCEDURE {WINAPI} (VAR name: ARRAY   OF CHAR; namelen: LONGINT): LONGINT;

		(** The Windows Sockets getpeername function retrieves the name of the peer to which a socket is connected. *)
		getpeername-: PROCEDURE {WINAPI} (s: Socket; VAR name: ARRAY   OF SYSTEM.BYTE; VAR namelen: LONGINT): LONGINT;

		  (*The getsockname function retrieves the local name for a socket.*)
		getsockname-:PROCEDURE {WINAPI} (s: Socket; VAR name: ARRAY   OF SYSTEM.BYTE; VAR namelen: LONGINT): LONGINT;

		(** The Windows Sockets htonl function converts a u_long from host to TCP/IP network byte order
			(which is big-endian). *)
		htonl-: PROCEDURE {WINAPI} (x: LONGINT): LONGINT;

		(** The Windows Sockets htons function converts a u_short from host to TCP/IP network byte order
			(which is big-endian). *)
		htons-: PROCEDURE {WINAPI} (x: INTEGER): INTEGER;

		(** The Windows Sockets ioctlsocket function controls the I/O mode of a socket. *)
		ioctlsocket-: PROCEDURE {WINAPI} (s: Socket; cmd: LONGINT; VAR argp: LONGINT): LONGINT;

		(** The Windows Sockets listen function places a socket a state where it is listening for an incoming connection. *)
		listen-: PROCEDURE {WINAPI} (s: Socket; backlog: LONGINT): LONGINT;

		(** The Windows Sockets ntohl function converts a u_long from TCP/IP network order to host byte order
			(which is little-endian on Intel processors). *)
		ntohl-: PROCEDURE {WINAPI} (x: LONGINT): LONGINT;

		(** The Windows Sockets ntohs function converts a u_short from TCP/IP network byte order to host byte order
			(which is little-endian on Intel processors). *)
		ntohs-: PROCEDURE {WINAPI} (x: INTEGER): INTEGER;

		(** The Windows Sockets recv function receives data from a connected socket. *)
		recv-: PROCEDURE {WINAPI} (s: Socket; VAR buf: ARRAY   OF SYSTEM.BYTE; len: LONGINT; flags: SET): LONGINT;

		(** The Windows Sockets recvfrom function receives a datagram and stores the source address. *)
		recvfrom-: PROCEDURE {WINAPI} (s: Socket; VAR buf: ARRAY   OF SYSTEM.BYTE; len: LONGINT; flags: LONGINT; VAR from: sockaddrIn (*VAR from: ARRAY   OF SYSTEM.BYTE*); VAR fromlen: LONGINT): LONGINT;

		(**  The select function determines the status of one or more sockets, waiting if necessary, to perform synchronous I/O *)
		select-: PROCEDURE {WINAPI} (nfds:INTEGER; VAR readfds,writefds,exceptfds: FDSet; timeout: TimeVal): LONGINT;

		(** The Windows Sockets send function sends data on a connected socket. *)
		send-: PROCEDURE {WINAPI} (s: Socket; CONST buf: ARRAY   OF SYSTEM.BYTE; len: LONGINT; flags: SET): LONGINT;

		(** The Windows Sockets sendto function sends data to a specific destination. *)
		sendto-: PROCEDURE {WINAPI} (s: Socket; CONST buf: ARRAY   OF SYSTEM.BYTE; len: LONGINT; flags: LONGINT; VAR to: ARRAY   OF SYSTEM.BYTE; tolen: LONGINT): LONGINT;

		(** The Windows Sockets setsockopt function sets a socket option. *)
		setsockopt-: PROCEDURE {WINAPI} (s: Socket; level, optname: LONGINT; VAR optval: ARRAY   OF SYSTEM.BYTE; optlen: LONGINT): LONGINT;
		getsockopt-: PROCEDURE {WINAPI} (s: Socket; level, optname: LONGINT; VAR optval: ARRAY   OF SYSTEM.BYTE; VAR optlen: LONGINT): LONGINT;

		(** The Windows Sockets socket function creates a socket that is bound to a specific service provider. *)
		socket-: PROCEDURE {WINAPI} (af, type, protocol: LONGINT): Socket;

		shutdown-:PROCEDURE{WINAPI} (s: Socket; how: LONGINT): LONGINT;

	PROCEDURE TermMod;
	BEGIN
		IF wsock32 # Kernel32.NULL THEN
			Kernel32.FreeLibrary(wsock32); wsock32 := Kernel32.NULL
		END;
		IF wship6 # Kernel32.NULL THEN
			Kernel32.FreeLibrary(wship6); wship6 := Kernel32.NULL
		END
	END TermMod;

	PROCEDURE Init;
	VAR str: ARRAY 32 OF CHAR;
	BEGIN
		str := "ws2_32.dll";
		wsock32 := Kernel32.LoadLibrary(str);
		IF wsock32 = Kernel32.NULL THEN
			str := "WSOCK32.DLL";
			wsock32 := Kernel32.LoadLibrary(str)
		END;
		str := "wship6.dll";
		wship6 := Kernel32.LoadLibrary(str);
		Kernel32.GetProcAddress(wsock32, "WSACleanup", SYSTEM.VAL(ADDRESS, WSACleanup));
		Kernel32.GetProcAddress(wsock32, "WSAAsyncGetHostByAddr", SYSTEM.VAL(ADDRESS, WSAAsyncGetHostByAddr));
		Kernel32.GetProcAddress(wsock32, "WSAAsyncGetHostByName", SYSTEM.VAL(ADDRESS, WSAAsyncGetHostByName));
		Kernel32.GetProcAddress(wsock32, "WSAAsyncSelect", SYSTEM.VAL(ADDRESS, WSAAsyncSelect));
		Kernel32.GetProcAddress(wsock32, "WSAGetLastError", SYSTEM.VAL(ADDRESS, WSAGetLastError));
		Kernel32.GetProcAddress(wsock32, "WSASocketA", SYSTEM.VAL(ADDRESS, WSASocket));
		Kernel32.GetProcAddress(wsock32, "WSAStartup", SYSTEM.VAL(ADDRESS, WSAStartup));
		Kernel32.GetProcAddress(wsock32, "WSAIoctl", SYSTEM.VAL(ADDRESS, WSAIoctl));
		Kernel32.GetProcAddress(wsock32, "accept", SYSTEM.VAL(ADDRESS, accept));
		Kernel32.GetProcAddress(wsock32, "bind", SYSTEM.VAL(ADDRESS, bind));
		Kernel32.GetProcAddress(wsock32, "closesocket", SYSTEM.VAL(ADDRESS, closesocket));
		Kernel32.GetProcAddress(wsock32, "connect", SYSTEM.VAL(ADDRESS, connect));
		Kernel32.GetProcAddress(wsock32, "freeaddrinfo", SYSTEM.VAL(ADDRESS, freeaddrinfo));
		Kernel32.GetProcAddress(wsock32, "getaddrinfo", SYSTEM.VAL(ADDRESS, getaddrinfo));
		Kernel32.GetProcAddress(wsock32, "gethostbyname", SYSTEM.VAL(ADDRESS, gethostbyname));
		Kernel32.GetProcAddress(wsock32, "gethostname", SYSTEM.VAL(ADDRESS, gethostname));
		Kernel32.GetProcAddress(wsock32, "getpeername", SYSTEM.VAL(ADDRESS, getpeername));
		Kernel32.GetProcAddress(wsock32, "getsockname", SYSTEM.VAL(ADDRESS, getsockname));
		Kernel32.GetProcAddress(wsock32, "htonl", SYSTEM.VAL(ADDRESS, htonl));
		Kernel32.GetProcAddress(wsock32, "htons", SYSTEM.VAL(ADDRESS, htons));
		Kernel32.GetProcAddress(wsock32, "ioctlsocket", SYSTEM.VAL(ADDRESS, ioctlsocket));
		Kernel32.GetProcAddress(wsock32, "listen", SYSTEM.VAL(ADDRESS, listen));
		Kernel32.GetProcAddress(wsock32, "ntohl", SYSTEM.VAL(ADDRESS, ntohl));
		Kernel32.GetProcAddress(wsock32, "ntohs", SYSTEM.VAL(ADDRESS, ntohs));
		Kernel32.GetProcAddress(wsock32, "recv", SYSTEM.VAL(ADDRESS, recv));
		Kernel32.GetProcAddress(wsock32, "recvfrom", SYSTEM.VAL(ADDRESS, recvfrom));
		Kernel32.GetProcAddress(wsock32, "select", SYSTEM.VAL(ADDRESS, select));
		Kernel32.GetProcAddress(wsock32, "send", SYSTEM.VAL(ADDRESS, send));
		Kernel32.GetProcAddress(wsock32, "sendto", SYSTEM.VAL(ADDRESS, sendto));
		Kernel32.GetProcAddress(wsock32, "setsockopt", SYSTEM.VAL(ADDRESS, setsockopt));
		Kernel32.GetProcAddress(wsock32, "getsockopt", SYSTEM.VAL(ADDRESS, getsockopt));
		Kernel32.GetProcAddress(wsock32, "socket", SYSTEM.VAL(ADDRESS, socket));
		Kernel32.GetProcAddress(wsock32, "shutdown", SYSTEM.VAL(ADDRESS, shutdown));

	    IF freeaddrinfo = NIL THEN
	    	KernelLog.String("Trying to locate getaddrinfo, freeaddrinfo"); KernelLog.Ln;
	    	str := "wship6.dll";
			wship6 := Kernel32.LoadLibrary(str);
			IF wship6 # Kernel32.NULL THEN
				Kernel32.GetProcAddress(wship6, "freeaddrinfo", SYSTEM.VAL(ADDRESS, freeaddrinfo));
				Kernel32.GetProcAddress(wship6, "getaddrinfo", SYSTEM.VAL(ADDRESS, getaddrinfo))
			ELSE
				KernelLog.String("Failed locating getaddrinfo, freeaddrinfo! You must install IPv6!"); KernelLog.Ln;
			END
		END;

		Modules.InstallTermHandler(TermMod)
	END Init;

	PROCEDURE Startup*;
		VAR data: WSAData; res: LONGINT;
	BEGIN
		KernelLog.String("WSAStartup ");
		res := WSAStartup(2, data);
		wsaStarted := res = 0;
		IF wsaStarted THEN
			KernelLog.String("done: "); KernelLog.String(data.szDescription)
		ELSE
			KernelLog.String("failed: "); KernelLog.Int(res, 0)
		END;
		KernelLog.Ln()
	END Startup;

	PROCEDURE CleanUp*;
	VAR res: LONGINT;
	BEGIN
		IF wsaStarted THEN
			res := WSACleanup();
			wsaStarted := FALSE
		END

	END CleanUp;
(*** debugging *)

	PROCEDURE DispError*;
	VAR err: Error;  nr: LONGINT;
	BEGIN
		nr := WSAGetLastError();
		IF  (nr=0) THEN RETURN END;
		err := errors;
		WHILE (err # NIL ) & (err.nr # nr) DO
			IF nr < err.nr THEN err := err.left
			ELSIF nr > err.nr THEN err := err.right
			END;
		END;

		IF err # NIL THEN
			KernelLog.Enter;  KernelLog.String( "Winsock: (" );  KernelLog.String( err.name );  KernelLog.String( ") : " );
			KernelLog.String( err.msg );  KernelLog.Exit;
		ELSE
			KernelLog.Enter;  KernelLog.String( "AosWinsock, unknown Error !! This should never happen:" );
			KernelLog.Int( nr, 5 );  KernelLog.Exit;
		END;

	END DispError;

	PROCEDURE Enter( nr: LONGINT;  short, desc: ARRAY OF CHAR );
	VAR this: Error;

		PROCEDURE InsertErr( VAR err: Error;  this: Error );
		BEGIN
			IF err # NIL THEN
				IF this.nr < err.nr THEN InsertErr( err.left, this ) ELSE InsertErr( err.right, this ) END;
			ELSE err := this;
			END;
		END InsertErr;

	BEGIN
		NEW( this );  this.nr := nr;  COPY( short, this.name );  COPY( desc, this.msg );  InsertErr( errors, this );
	END Enter;

	PROCEDURE InitErrs;
	BEGIN
		Enter( 10013, "WSAEACCES", "Permission denied." );
		Enter( 10048, "WSAEADDRINUSE", "Address already in use." );
		Enter( 10049, "WSAEADDRNOTAVAIL", "Cannot assign requested address." );
		Enter( 10047, "WSAEAFNOSUPPORT", "Address family not supported by protocol family." );
		Enter( 10037, "WSAEALREADY", "Operation already in progress." );
		Enter( 10061, "WSAECONNREFUSED", "Connection refused." );
		Enter( 10053, "WSAECONNABORTED", "Software caused connection abort." );
		Enter( 10054, "WSAECONNRESET", "Connection reset by peer." );
		Enter( 10039, "WSAEDESTADDRREQ", "Destination address required." );
		Enter( 10014, "WSAEFAULT", "Bad address." );  Enter( 10064, "WSAEHOSTDOWN", "Host is down." );
		Enter( 10065, "WSAEHOSTUNREACH", "No route to host." );
		Enter( 10036, "WSAEINPROGRESS", "Operation now in progress. " );
		Enter( 10004, "WSAEINTR", "Interrupted function call." );  Enter( 10022, "WSAEINVAL", "Invalid argument." );
		Enter( 10056, "WSAEISCONN", "Socket is already connected." );
		Enter( 10024, "WSAEMFILE", "Too many open files." );  Enter( 10040, "WSAEMSGSIZE", "Message too long." );
		Enter( 10050, "WSAENETDOWN", "Network is down." );
		Enter( 10052, "WSAENETRESET", "Network dropped connection on reset." );
		Enter( 10051, "WSAENETUNREACH", "Network is unreachable." );
		Enter( 10055, "WSAENOBUFS", "No buffer space available." );
		Enter( 10042, "WSAENOPROTOOPT", "Bad protocol option." );
		Enter( 10057, "WSAENOTCONN", "Socket is not connected." );
		Enter( 10038, "WSAENOTSOCK", "Socket operation on non-socket." );
		Enter( 10045, "WSAEOPNOTSUPP", "Operation not supported." );
		Enter( 10046, "WSAEPFNOSUPPORT", "Protocol family not supported." );
		Enter( 10067, "WSAEPROCLIM", "Too many processes." );
		Enter( 10043, "WSAEPROTONOSUPPORT", "Protocol not supported." );
		Enter( 10041, "WSAEPROTOTYPE", "Protocol wrong type for socket." );
		Enter( 10058, "WSAESHUTDOWN", "Cannot send after socket shutdown." );
		Enter( 10044, "WSAESOCKTNOSUPPORT", "Socket type not supported." );
		Enter( 10060, "WSAETIMEDOUT", "Connection timed out." );
		Enter( 10109, "WSATYPE_NOT_FOUND", "Class type not found" );
		Enter( 10035, "WSAEWOULDBLOCK", "Resource temporarily unavailable." );
		Enter( 11001, "WSAHOST_NOT_FOUND", "Host not found." );
		Enter( 10093, "WSANOTINITIALISED", "Successful WSAStartup() not yet performed." );
		Enter( 11004, "WSANO_DATA", "Valid name, no data record of requested type." );
		Enter( 11003, "WSANO_RECOVERY", "This is a non-recoverable error." );
		Enter( 10091, "WSASYSNOTREADY", "Network subsystem is unavailable." );
		Enter( 11002, "WSATRY_AGAIN", "Non-authoritative host not found." );
		Enter( 10092, "WSAVERNOTSUPPORTED", "WINSOCK.DLL version out of range." );
		Enter( 10101, "WSAEDISCON", "Graceful shutdown in progress." );
	END InitErrs;



BEGIN
	InitErrs(); Init();
END WSock32.

SystemTools.FreeDownTo WSock32~
