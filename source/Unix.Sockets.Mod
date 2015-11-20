

MODULE Sockets;	(** AUTHOR "G.F.";  PURPOSE "Interface to Unix sockets" *)

(* derived from NetBase.Mod,  BD / 13.2.96 *)

(*	1998.04.27	g.f.	Linux PPC version	*)
(*	1099.05.17	g.f.	adapted to Threads	*)
(*	1999.11.22	g.f.	Solaris x86 version	*)
(*	2000.02.18	g.f.	adapted to Solaris 8	*)
(*	2001.01.06	g.f.	[c] - flag for new compiler	*)
(*	2007.07.06	g.f.	IP address format converted to IP.Adr *)

IMPORT S := SYSTEM, Unix, Trace, IP;

CONST

	(*listen *)
	Backlog = 5;		(* max number of pending connections *)


TYPE				
	SocketAdr* = POINTER TO RECORD 
		family*		: INTEGER;
		port*		: INTEGER;	(* in network byte order! *)
	END;
		
	SocketAdrV4* = POINTER TO RECORD (SocketAdr)
		v4Adr*		: LONGINT;
		zero*		: ARRAY 8 OF CHAR
	END;
		
	SocketAdrV6* = POINTER TO RECORD (SocketAdr)
		flowinfo*	: LONGINT;
		v6Adr*		: ARRAY 16 OF CHAR;
		scopeId*	: LONGINT;
		srcId*		: LONGINT
	END;
		
	NameBuf = POINTER TO RECORD
		buf: ARRAY 64 OF CHAR
	END;


	SocketOption = POINTER TO RECORD END;
		
	Linger = POINTER TO RECORD (SocketOption)
		onoff	: LONGINT;
		linger	: LONGINT;
	END;
		
	Switch = POINTER TO RECORD (SocketOption)
		onoff	: LONGINT
	END;

CONST 
	LingerSize = 8;



VAR
	socket		: PROCEDURE {C} ( af, typ, protocol: LONGINT ): LONGINT;		
	setsockopt	: PROCEDURE {C} ( s: LONGINT; level, optname: LONGINT; opt: SocketOption; optlen: LONGINT): LONGINT;
	accept		: PROCEDURE {C} ( s: LONGINT; adrPtr: ADDRESS; VAR adrlen: LONGINT ): LONGINT;
	bind		: PROCEDURE {C} ( s: LONGINT; adr: SocketAdr; adrlen: LONGINT ): LONGINT;
	connect		: PROCEDURE {C} ( s: LONGINT; adr: SocketAdr; adrlen: LONGINT ): LONGINT;
	listen		: PROCEDURE {C} ( s: LONGINT; backlog: LONGINT ): LONGINT;
	recv		: PROCEDURE {C} ( s: LONGINT; buf: ADDRESS; len, flags: LONGINT ): LONGINT;
	send		: PROCEDURE {C} ( s: LONGINT; buf: ADDRESS; len, flags: LONGINT ): LONGINT;
	recvfrom	: PROCEDURE {C} ( s: LONGINT; buf: ADDRESS; len, flags: LONGINT; from: NameBuf; VAR flen: LONGINT ): LONGINT;
	sendto		: PROCEDURE {C} ( s: LONGINT; buf: ADDRESS; len, flags: LONGINT; to: SocketAdr; tolen: LONGINT ): LONGINT;
	shutdown	: PROCEDURE {C} ( s: LONGINT; how: LONGINT );
	
	getpeername	: PROCEDURE {C} ( s: LONGINT; adr: NameBuf; VAR adrlen: LONGINT ): LONGINT;
	getsockname	: PROCEDURE {C} ( s: LONGINT; adr: NameBuf; VAR adrlen: LONGINT ): LONGINT;
	
	htonl	: PROCEDURE {C} ( hostlong	: LONGINT ): LONGINT;
	htons	: PROCEDURE {C} ( hostshort	: LONGINT ): LONGINT;
	ntohl	: PROCEDURE {C} ( netlong		: LONGINT ): LONGINT;
	ntohs	: PROCEDURE {C} ( netshort	: LONGINT ): LONGINT;
	
	
	PROCEDURE NewSocketAdr*( ip: IP.Adr; port: LONGINT ): SocketAdr;
	VAR sadr4: SocketAdrV4;  sadr6: SocketAdrV6; i: LONGINT;
	BEGIN
		CASE ip.usedProtocol OF
		| -1:
			NEW( sadr4 );
				sadr4.family := Unix.AFINET;
				sadr4.port := IntToNet( SHORT( port ) );
				sadr4.v4Adr := 0;
			RETURN sadr4
		| IP.IPv4:
			NEW( sadr4 );
				sadr4.family := Unix.AFINET;
				sadr4.port := IntToNet( SHORT( port ) );
				sadr4.v4Adr := ip.ipv4Adr;
			RETURN sadr4
		| IP.IPv6:
			NEW( sadr6 );
				sadr6.family := Unix.AFINET6;
				sadr6.port := IntToNet( SHORT( port ) );
				sadr6.flowinfo := 0;
				FOR i := 0 TO 15 DO  sadr6.v6Adr[i] := ip.ipv6Adr[i]  END;
				sadr6.scopeId := 0;
				sadr6.srcId := 0;
			RETURN sadr6
		ELSE
			HALT( 99 )
		END
	END NewSocketAdr;
	
	PROCEDURE SockAdrToIPAdr*( sadr: SocketAdr ): IP.Adr;
	VAR ip: IP.Adr;  i: LONGINT;
	BEGIN
		IF sadr IS SocketAdrV4 THEN
			ip.usedProtocol := IP.IPv4;
			ip.ipv4Adr := sadr(SocketAdrV4).v4Adr;
			ip.ipv6Adr := ""
		ELSE
			ip.usedProtocol := IP.IPv6;
			ip.ipv4Adr := 0;
			FOR i := 0 TO 15 DO
				ip.ipv6Adr[i] := sadr(SocketAdrV6).v6Adr[i]
			END
		END;
		RETURN ip
	END SockAdrToIPAdr;
	
	PROCEDURE GetPortNumber*( sadr: SocketAdr ): LONGINT;
	VAR port: LONGINT;
	BEGIN
		port := NetToInt( sadr.port );
		IF port < 0 THEN port := port + 10000H END;
		RETURN port
	END GetPortNumber;

	PROCEDURE BufToSocketAdr( CONST buf: ARRAY OF CHAR; len: LONGINT ): SocketAdr;
	VAR adr4: SocketAdrV4; adr6: SocketAdrV6; 
	BEGIN
		IF len = Unix.SockAddrSizeV4 THEN
			NEW( adr4 ); 
			S.MOVE( ADDRESSOF( buf ), ADDRESSOF( adr4^), len );
			RETURN adr4
		ELSE
			NEW( adr6 ); 
			S.MOVE( ADDRESSOF( buf ), ADDRESSOF( adr6^), len );
			RETURN adr6
		END
	END BufToSocketAdr;

	PROCEDURE Accept*( s: LONGINT ): LONGINT;
	VAR len, err: LONGINT; new: LONGINT;
	BEGIN
		len := 0;
		REPEAT
			new := accept( s, 0, len );
			IF new < 0 THEN  err := Unix.errno()  END
		UNTIL (new > 0) OR (err # Unix.EINTR);
		IF new < 0 THEN  Unix.Perror( "Sockets.Accept" )  END;
		RETURN new
	END Accept;

	PROCEDURE Bind*( s: LONGINT; addr: SocketAdr): BOOLEAN;
	VAR err, len: LONGINT;  
	BEGIN
		IF addr.family = Unix.AFINET THEN  len := Unix.SockAddrSizeV4  ELSE  len := Unix.SockAddrSizeV6  END;
		err:= bind( s, addr, len );
		RETURN err = 0 
	END Bind;

	PROCEDURE Close*( s: LONGINT );
	VAR err: LONGINT;
	BEGIN
		shutdown( s, Unix.ShutRDWR );
		err := Unix.close( s );
	END Close;

	PROCEDURE Connect*( s: LONGINT; addr: SocketAdr ): BOOLEAN;
	VAR err, len: LONGINT;
	BEGIN
		IF addr.family = Unix.AFINET THEN  len := Unix.SockAddrSizeV4  ELSE  len := Unix.SockAddrSizeV6  END;
		err:= connect( s, addr, len );
		IF err = 0 THEN 
			RETURN TRUE 
		ELSE 
			Unix.Perror( "Sockets.Connect: " );
			RETURN FALSE
		END;
		RETURN err = 0
	END Connect;

	PROCEDURE GetSockName*( s: LONGINT ): SocketAdr;
	VAR len, err: LONGINT; buf: NameBuf;
	BEGIN
		NEW( buf );  len := 64;
		err := getsockname( s, buf, len );
		IF err = 0 THEN 
			RETURN BufToSocketAdr( buf.buf, len )
		ELSE
			Unix.Perror( "Sockets.GetSockName" );
			RETURN NIL 
		END
	END GetSockName;


	PROCEDURE GetPeerName*( s: LONGINT ): SocketAdr;
	VAR err, len: LONGINT; buf: NameBuf;
	BEGIN
		NEW( buf );  len := 64;
		err:= getpeername( s, buf, len );
		IF err = 0 THEN 
			RETURN BufToSocketAdr( buf.buf, len )
		ELSE 
			Unix.Perror( "Sockets.GetPeerName" );
			RETURN NIL 
		END
	END GetPeerName;

	PROCEDURE Listen*( s: LONGINT ): BOOLEAN;
	VAR err: LONGINT;
	BEGIN
		err := listen( s, Backlog );
		RETURN err = 0 
	END Listen;

	PROCEDURE Recv*( s: LONGINT; VAR buf: ARRAY OF CHAR; pos: LONGINT; VAR len: LONGINT; flags: LONGINT ): BOOLEAN;
	VAR res, err: LONGINT;
	BEGIN
		REPEAT
			res := recv( s, ADDRESSOF( buf[pos] ), len, flags );
			IF res < 0 THEN  err := Unix.errno()  END
		UNTIL (res >= 0) OR (err # Unix.EINTR);
		IF err >= 0 THEN 
			len:= res;  RETURN TRUE 
		ELSE 
			Unix.Perror( "Sockets.Recv" );
			len:= 0;  RETURN FALSE 
		END
	END Recv;

	PROCEDURE Send*( s: LONGINT; CONST buf: ARRAY OF CHAR; pos: LONGINT; VAR len: LONGINT ): BOOLEAN;
	VAR err: LONGINT;
	BEGIN
		ASSERT( LEN(buf)-pos >= len );
		err := send( s, ADDRESSOF( buf[pos] ), len, 0 );
		IF err >= 0 THEN 
			len := err;  RETURN TRUE 
		ELSE 
			Unix.Perror( "Sockets.Send" );
			len := 0;  RETURN FALSE 
		END
	END Send;
	
	
	
	PROCEDURE RecvFrom*( s: LONGINT; VAR from: SocketAdr; 
						    VAR buf: ARRAY OF CHAR; pos: LONGINT;  VAR len: LONGINT ): BOOLEAN;
	VAR res, err, size: LONGINT; nbuf: NameBuf;
	BEGIN
		NEW( nbuf ); size := 64;
		REPEAT
			res := recvfrom( s, ADDRESSOF(buf[pos]), LEN( buf ) - pos, 0, nbuf, size );
			IF res < 0 THEN  err := Unix.errno()  END
		UNTIL (res >= 0) OR (err # Unix.EINTR);
		IF res >= 0 THEN 
			from := BufToSocketAdr( nbuf.buf, size );
			len := res;  RETURN TRUE 
		ELSE 
			Unix.Perror( "Sockets.RecvFrom" );
			len := 0;  RETURN FALSE 
		END
	END RecvFrom;

	PROCEDURE SendTo*( s: LONGINT;  dest: SocketAdr;  CONST buf: ARRAY OF CHAR;  pos, len: LONGINT ): BOOLEAN;
	VAR err, size: LONGINT;
	BEGIN
		ASSERT( LEN(buf) - pos >= len );
		IF dest.family = Unix.AFINET THEN  size := Unix.SockAddrSizeV4  ELSE  size := Unix.SockAddrSizeV6  END;
		err:= sendto( s, ADDRESSOF( buf[pos] ), len, 0, dest, size );
		IF err >= 0 THEN 
			RETURN TRUE 
		ELSE 
			Unix.Perror( "Sockets.SendTo" );
			RETURN FALSE 
		END
	END SendTo;

	PROCEDURE Socket* ( af, typ, protocol: LONGINT ): LONGINT;
	VAR s: LONGINT;
	BEGIN
		s := socket( af, typ, protocol );
		RETURN s 
	END Socket;

	PROCEDURE Available*( s: LONGINT ): LONGINT;
	VAR available, err: LONGINT; 
	BEGIN
		available := 0;
		err := Unix.ioctl( s, Unix.FioNRead, ADDRESSOF( available ) );
		IF err = 0 THEN
			RETURN available
		ELSE
			Unix.Perror( "Sockets.Available (ioctl)" );
			RETURN -1
		END
	END Available;

	PROCEDURE Requested*( s: LONGINT ): BOOLEAN;
	VAR res, i: LONGINT;
		readfds: Unix.FdSet;
		timeout: Unix.Timeval;
	BEGIN
		timeout.sec := 0; timeout.usec := 0;
		FOR i := 0 TO LEN( readfds ) - 1  DO readfds[i] := {} END;
		INCL( readfds[s DIV 32],  s MOD 32 );
		res := Unix.select( s+1, S.VAL( Unix.FdSetPtr, ADDRESSOF( readfds ) ), NIL, NIL, timeout );
		RETURN res > 0 
	END Requested;
	
	
	PROCEDURE AwaitPacket*( s: LONGINT; ms: LONGINT ): BOOLEAN;
	VAR res, err, i: LONGINT;
		readfds: Unix.FdSet;
		timeout: Unix.Timeval;
	BEGIN
		timeout.sec := ms DIV 1000;  ms := ms MOD 1000;
		timeout.usec := 1000*ms;
		FOR i := 0 TO LEN( readfds ) - 1  DO readfds[i] := {} END;
		INCL( readfds[s DIV 32],  s MOD 32 );
		REPEAT
			res := Unix.select( s+1, S.VAL( Unix.FdSetPtr, ADDRESSOF( readfds ) ), NIL, NIL, timeout );
			IF res < 0 THEN  err := Unix.errno()  END
		UNTIL (res >= 0) OR (err # Unix.EINTR);
		RETURN res > 0 
	END AwaitPacket;

	
	PROCEDURE SetLinger* ( s: LONGINT ): BOOLEAN;
	VAR 
		linger: Linger;
		err: LONGINT;
	BEGIN
		NEW( linger);  linger.onoff := 1;  linger.linger := 1;
		err := setsockopt( s, Unix.SoLSocket, Unix.SoLinger, linger, LingerSize );
		IF err # 0 THEN  Unix.Perror(  "Sockets.SetLinger (setsockopt)" )  END;
		RETURN err = 0 
	END SetLinger;
	
	PROCEDURE KeepAlive* ( s: LONGINT; enable: BOOLEAN ): BOOLEAN;
	VAR 
		opt: Switch;
		err: LONGINT;
	BEGIN
		NEW( opt );  
		IF enable THEN  opt.onoff := 1  ELSE  opt.onoff := 0  END;  
		err := setsockopt( s, Unix.SoLSocket, Unix.SoKeepAlive, opt, 4 );
		IF err # 0 THEN  Unix.Perror(  "Sockets.KeepAlive (setsockopt)" )  END;
		RETURN err = 0 
	END KeepAlive;
	
	
	PROCEDURE NoDelay* ( s: LONGINT; enable: BOOLEAN ): BOOLEAN;
	VAR 
		opt: Switch;
		err: LONGINT;
	BEGIN
		NEW( opt );  
		IF enable THEN  opt.onoff := 1  ELSE  opt.onoff := 0  END;  
		err := setsockopt( s, Unix.SoLSocket, Unix.SoNoDelay, opt, 4 );
		IF err # 0 THEN  Unix.Perror(  "Sockets.NoDelay (setsockopt)" )  END;
		RETURN err = 0 
	END NoDelay;
	
	
	PROCEDURE NetToInt* (x: INTEGER): INTEGER;
	BEGIN
		RETURN SHORT(ntohs(LONG(x)))
	END NetToInt;

	PROCEDURE IntToNet* (x: INTEGER): INTEGER;
	BEGIN
		RETURN SHORT(htons(LONG(x)))
	END IntToNet;

	PROCEDURE NetToLInt* (x: LONGINT): LONGINT;
	BEGIN
		RETURN ntohl(x)
	END NetToLInt;

	PROCEDURE LIntToNet* (x: LONGINT): LONGINT;
	BEGIN
		RETURN htonl(x)
	END LIntToNet;


	PROCEDURE Init;
	VAR slib: ADDRESS;
	BEGIN
		IF Unix.Version = "Solaris" THEN
			slib := Unix.Dlopen( "libsocket.so.1", 2 );
			IF slib = 0 THEN  slib := Unix.Dlopen( "libsocket.so", 2 )  END;
			IF slib = 0 THEN  Trace.StringLn( "Unix.Dlopen( 'libsocket.so' ) failed")  END;
		ELSE
			slib := Unix.libc
		END;
		Unix.Dlsym( slib, "accept", ADDRESSOF( accept ) );
		Unix.Dlsym( slib, "bind", ADDRESSOF( bind ) );
		Unix.Dlsym( slib, "connect", ADDRESSOF( connect ) );
		Unix.Dlsym( slib, "shutdown", ADDRESSOF( shutdown ) );
		Unix.Dlsym( slib, "getpeername", ADDRESSOF( getpeername ) );
		Unix.Dlsym( slib, "htonl", ADDRESSOF( htonl ) );
		Unix.Dlsym( slib, "htons", ADDRESSOF( htons ) );
		Unix.Dlsym( slib, "listen", ADDRESSOF( listen ) );
		Unix.Dlsym( slib, "ntohl", ADDRESSOF( ntohl ) );
		Unix.Dlsym( slib, "ntohs", ADDRESSOF( ntohs ) );
		Unix.Dlsym( slib, "recv", ADDRESSOF( recv ) );
		Unix.Dlsym( slib, "recvfrom", ADDRESSOF( recvfrom ) );
		Unix.Dlsym( slib, "send", ADDRESSOF( send ) );
		Unix.Dlsym( slib, "sendto", ADDRESSOF( sendto ) );
		Unix.Dlsym( slib, "setsockopt", ADDRESSOF( setsockopt ) );
		Unix.Dlsym( slib, "socket", ADDRESSOF( socket ) );
		Unix.Dlsym( slib, "getsockname", ADDRESSOF( getsockname ) );
	END Init;

BEGIN
	Init
END Sockets.