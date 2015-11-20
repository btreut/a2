(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE UDP;   (** AUTHOR "pjm, mvt, G.F."; PURPOSE "UDP protocol"; *)

IMPORT IP, Sockets, Unix;

CONST
	(** Error codes *)
	Ok* = 0;  PortInUse* = 3501;  Timeout* = 3502;  BufferOverflow* = 3503;  NoInterface* = 3504;
	Closed* = 3505;  Error* = 9999;

	NilPort* = 0;  anyport = 0;

	UDPHdrLen = 8;
	MaxUDPDataLen = 10000H - UDPHdrLen;
VAR
	anyIP: IP.Adr;

TYPE
	(** Socket. Stores the state of a UDP communication endpoint. *)
	Socket* = OBJECT
			VAR 
				socket: LONGINT;
				lport: LONGINT;   (* local port *)
				open: BOOLEAN;


				(** Constructor *)
				PROCEDURE & Open*( lport: LONGINT;  VAR res: LONGINT );
				VAR laddr: Sockets.SocketAdr;
				BEGIN
					ASSERT( (lport >= 0) & (lport < 10000H) );
					SELF.lport := lport;  res := Error;
					socket := Sockets.Socket( Unix.AFINET, Unix.SockDGram, Unix.IpProtoUDP );
					IF socket # 0 THEN
						IF lport # anyport THEN
							(* server *)
							laddr := Sockets.NewSocketAdr( anyIP, lport );
							IF Sockets.Bind( socket, laddr ) THEN  
								res := Ok;  open := TRUE  
							ELSE  
								Sockets.Close( socket )  
							END
						ELSE
							(* client *)
							res := Ok;  open := TRUE 
						END
					END
				END Open;


				(** Send a UDP datagram to the foreign address specified by "fip" and "fport".
					   The data is in "data[ofs..ofs+len-1]".  In case of concurrent sends the datagrams are serialized.
					*)
				PROCEDURE Send*( fip: IP.Adr;  
								   fport: LONGINT;  
								   CONST data: ARRAY OF CHAR;  ofs, len: LONGINT;
								   VAR res: LONGINT );
				VAR addr: Sockets.SocketAdr;
				BEGIN {EXCLUSIVE}
					ASSERT( (fport >= 0) & (fport < 10000H) );  
					ASSERT( (len >= 0) & (len <= MaxUDPDataLen) );
					addr := Sockets.NewSocketAdr( fip, fport );
					IF Sockets.SendTo( socket, addr, data, ofs, len ) THEN  res := Ok  ELSE  res := Error  END
				END Send;


				(** Send a broadcast UDP datagram via interface "int" to port "lport". Normally only used by DHCP.
					   The data is in "data[ofs..ofs+len-1]".  In case of concurrent sends the datagrams are serialized.
					*)
				PROCEDURE SendBroadcast*( int: IP.Interface;  fport: LONGINT;  
										      CONST data: ARRAY OF CHAR;  ofs, len: LONGINT );
				BEGIN (*{EXCLUSIVE}*)
					ASSERT( (fport >= 0) & (fport < 10000H) );  ASSERT( (len >= 0) & (len <= MaxUDPDataLen) );
					HALT( 99 ) (* not implemented yet *)
				END SendBroadcast;


				(** Receive a UDP datagram.  If none is available, wait up to the specified timeout for one to arrive.
					"data[ofs..ofs+size-1]" is the data buffer to hold the returned datagram.
					"ms" is a wait timeout value in milliseconds, 0 means "don't wait", -1 means "infinite wait".
					On return, "fip" and "fport" hold the foreign address and port.
					"len" returns the actual datagram size and "data[ofs..ofs+len-1]" returns the data.
					"res" returns "Timeout" in case of a timeout and "BufferOverflow" if the received datagram was
					too big.
				*)
				PROCEDURE Receive*( VAR data: ARRAY OF CHAR;  ofs, size, ms: LONGINT;  
									 VAR fip: IP.Adr;  VAR fport, len, res: LONGINT );
				VAR 
					addr: Sockets.SocketAdr; i: LONGINT;
				BEGIN {EXCLUSIVE}
					IF ~open THEN  res := Closed;  RETURN   END;
					IF (ms >= 0) & ~Sockets.AwaitPacket( socket, ms ) THEN
						res := Timeout;  RETURN
					END;
					IF Sockets.RecvFrom( socket, addr, data, ofs, len ) THEN
						fport := Sockets.GetPortNumber( addr );
						IF addr IS Sockets.SocketAdrV4 THEN
							fip.usedProtocol := IP.IPv4;
							fip.ipv4Adr := addr(Sockets.SocketAdrV4).v4Adr;
						ELSE
							fip.usedProtocol := IP.IPv6;
							FOR i := 0 TO 15 DO  
								fip.ipv6Adr[i] := addr(Sockets.SocketAdrV6).v6Adr[i]
							END
						END;
						res := Ok;
					ELSE  
						res := Error
					END
				END Receive;



				(** Close the Socket, freeing its address for re-use. *)
				PROCEDURE Close*;
				BEGIN 
					Sockets.Close( socket );  open := FALSE
				END Close;

			END Socket;

BEGIN
	anyIP := IP.NilAdr;
END UDP.



