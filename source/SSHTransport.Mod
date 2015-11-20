MODULE SSHTransport;  	(* g.f.	2002.07.08 *)
(** SSH Transport Layer *)

(*	2002.09.24	g.f.	rel. 1.3	*)
(*	2002.10.15	g.f.	RSA hostkeys added, proc. 'deriveKey' fixed	*)
(*	2005.07.08	g.f.	algoMatch fixed, HMAC handling fixed *)

IMPORT TCP, IP, DNS, Out := KernelLog,
	Ciphers := CryptoCiphers, B := CryptoBigNumbers, DH := CryptoDiffieHellman,
	HMAC := CryptoHMAC, SHA1 := CryptoSHA1,
	U := CryptoUtils, G := SSHGlobals, SSHKeys;

CONST
	ClientVersion = "SSH-2.0-A2 SSH-1.7";  SSHport = 22;
	KEXAlgorythms		= "diffie-hellman-group14-sha1,diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha1";
	SHKAlgorythms		= "ssh-rsa,ssh-dss";
	(* Ciphers list			=  built from contents of  SSHConfiguration.Text *)
	(* HMAC list			=  built from contents of  SSHConfiguration.Text *)
	ComprAlgorythms	= "none";
	Languages 			= "";

	CR = 0DX;  NL = 0AX;

	(* SSH  Message Numbers *)
	Disconn = 1X;  Ignore = 2X;  Unimpl = 3X;  Debug = 4X;
	ServiceRequest = 5X;  ServiceAccept = 6X;
	KEXInit = 14X;  NewKeys = 15X;

	Closed* = 0;  Connected* = 1;  Keyexchange* = 2;  (** Connection states *)


TYPE
	Key = ARRAY 20 OF CHAR;

	Connection* = OBJECT
			VAR
				state-: SHORTINT;
				tcp: TCP.Connection;
				servername: ARRAY 128 OF CHAR;
				cvers, svers: ARRAY 260 OF CHAR;  (* string *)
				sessionId-, hash: Key;
				secret: ARRAY 1024 OF CHAR;	(* shared secret, (mpint format) *)
				incount, outcount: LONGINT;	(* packet counters *)
				(* current security state: *)
				inhkey, outhkey: Key;
				incipher, outcipher: Ciphers.Cipher;
				inmac, outmac: HMAC.HMac;
				inmaclen, outmaclen: LONGINT;
				new: RECORD
						(* pending security state: *)
						incipher, outcipher: Ciphers.Cipher;
						inkeybits, outkeybits: LONGINT;		(* cipher keybits *)
						inmode, outmode: SHORTINT;		(* cipher modes *)
						inmac, outmac: HMAC.HMac;
						inmaclen, outmaclen: LONGINT;
					END;

				cipherList, hmacList: ARRAY 1024 OF CHAR;
				clientChannelNo: LONGINT;

				PROCEDURE & Open*( CONST hostname: ARRAY OF CHAR );
				VAR
					res: LONGINT;  adr: IP.Adr;  p: LONGINT;
				BEGIN
					state := Closed;
					Out.String( "connecting to " );  Out.String( hostname );  Out.String( " ... " );
					DNS.HostByName( hostname, adr, res );
					IF res = DNS.Ok THEN
						NEW( tcp ); tcp.Open( 0, adr, SSHport, res );
						IF res = TCP.Ok THEN
							state := Connected;
							COPY( hostname, servername );
							Out.String( "connected" );  Out.Ln;
							tcp.KeepAlive( TRUE );
							p := 0;  U.PutString( cvers, p, ClientVersion );
							incipher := Ciphers.NewCipher( "" );
							outcipher := Ciphers.NewCipher( "" );		(* empty ciphers, no encryption *)
							incount := 0; outcount := 0;
							inmac := NIL;  outmac := NIL;
							IF ReceiveServerVersion( ) THEN
								SendClientVersion;
								G.GetCipherList( cipherList );
								G.GetHMacList( hmacList );
								IF 2 IN G.debug THEN
									Out.String( "client Ciphers: "); Out.Ln;  Out.String( cipherList ); Out.Ln;
									Out.String( "client hmacs: "); Out.Ln;  Out.String( hmacList ); Out.Ln;
								END;
								NegotiateAlgorythms;
							END
						ELSE
							Out.Ln;  Out.String( "connection failed" );  Out.Ln;
						END
					ELSE
						Out.Ln;  Out.String( "DNS lookup failed" );  Out.Ln;
					END;
				END Open;


				PROCEDURE ReceiveServerVersion( ): BOOLEAN;
				VAR receivebuf: ARRAY 2048 OF CHAR;  len, p1, p2: LONGINT;
				BEGIN
					REPEAT
						len := ReceiveLine( tcp, receivebuf )
					UNTIL Head( receivebuf, "SSH-" );

					IF ~Head( receivebuf, "SSH-1.99" ) & ~Head( receivebuf, "SSH-2.0" ) THEN
						Out.String( "remote host does not support SSH version 2.0" );  Out.Ln;
						tcp.Close( );
						RETURN FALSE
					ELSE
						p1 := 0;  p2 := 0;
						U.PutArray( svers, p1, receivebuf, p2, len );
						IF 0 IN G.debug THEN
							Out.String( "server version: " ); U.PrintBufferString( svers, 0 ); Out.Ln;
							Out.String( "client version: " ); U.PrintBufferString( cvers, 0 ); Out.Ln;
						END;
						RETURN TRUE
					END
				END ReceiveServerVersion;

				PROCEDURE SendClientVersion;
				VAR
					len, pos, res: LONGINT;
					nl: ARRAY 4 OF CHAR;
				BEGIN
					pos := 0;
					U.GetLength( cvers, pos, len );
					tcp.Send( cvers, 4, len, TRUE, res );
					nl[0] := CR; nl[1] := NL;
					tcp.Send( nl, 0, 2, TRUE, res );
				END SendClientVersion;

				(** Send packet p *)
				PROCEDURE SendPacket*( p: Packet );
				VAR
					i, trlen, payload, pad, cbs, res: LONGINT;
					seqno: ARRAY 4 OF CHAR;
					trbuf: ARRAY 8196 OF CHAR;
					packType: LONGINT;
				BEGIN
					IF state = Closed THEN  RETURN  END;
					ASSERT( p.len > 0 );
					cbs := outcipher.blockSize;
					pad := cbs - (p.len + 5) MOD cbs;
					IF pad < 4 THEN INC( pad, cbs ) END;
					payload := 1 + p.len + pad;
					Int2Chars( payload, trbuf );  trbuf[4] := CHR( pad );
					trlen := 4 + payload;
					FOR i := 0 TO p.len - 1 DO trbuf[i+5] := p.buf[i]  END;
					U.RandomBytes( trbuf, p.len + 5, pad  );
					IF outmac # NIL THEN
						Int2Chars( outcount, seqno );
						outmac.Initialize( outhkey, outmac.size );
						outmac.Update( seqno, 0, 4 );  outmac.Update( trbuf, 0, trlen );
						outmac.GetMac( trbuf, trlen );
					END;
					outcipher.Encrypt( trbuf, 0, trlen );
					IF outmac # NIL THEN INC( trlen, outmaclen ) END;
					tcp.Send( trbuf, 0, trlen, TRUE, res );
					INC( outcount );
					IF 3 IN G.debug THEN
						packType := ORD( p.buf[0] );
						Out.String( "sent: "); Out.Int( packType, 0 );  Out.Char( '(' );
						Out.Char( hexd[packType DIV 16] );
						Out.Char( hexd[packType MOD 16] );
						Out.String( "X), len = " ); Out.Int( p.len, 0);
						Out.Ln
					END;
				END SendPacket;

				(** Receive SSH Packet into buf,  return packet type *)
				PROCEDURE ReceivePacket*( VAR buf: ARRAY OF CHAR;  VAR size: LONGINT ): CHAR;
				VAR i, l, pad, trlen, cbs, pos, res: LONGINT;
					seqno: ARRAY 4 OF CHAR; rmac, cmac: ARRAY 20 OF CHAR;
					trbuf: ARRAY 8196 OF CHAR;
					packType: LONGINT;
				BEGIN
					IF state = Closed THEN RETURN 0X END;
					cbs := incipher.blockSize;
					tcp.Receive( trbuf, 0, cbs, cbs, l, res );
					IF res # TCP.Ok THEN (* closed by peer *) size := 0;  RETURN 0X  END;
					incipher.Decrypt( trbuf, 0, cbs );
					pos := 0;
					U.GetLength( trbuf, pos, trlen );
					IF 3 IN G.debug THEN
						packType := ORD( trbuf[5] );
						Out.String( "received: "); Out.Int( packType, 0 );  Out.Char( '(' );
						Out.Char( hexd[packType DIV 16] );
						Out.Char( hexd[packType MOD 16] );
						Out.String( "X), len = " ); Out.Int( trlen, 0 );
						Out.Ln
					END;
					ASSERT( (4 + trlen) MOD cbs = 0 );
					pad := ORD( trbuf[4] );  size := trlen - 1 - pad;
					INC( trlen, 4 );	(* the len bytes itself *)
					tcp.Receive( trbuf, cbs, trlen - cbs, trlen - cbs, l, res );
					incipher.Decrypt( trbuf, cbs, trlen - cbs );
					IF inmac # NIL THEN
						tcp.Receive( rmac, 0, inmaclen, inmaclen, l, res );
						Int2Chars( incount, seqno );
						inmac.Initialize( inhkey, inmac.size );
						inmac.Update( seqno, 0, 4 ); inmac.Update( trbuf, 0, trlen );
						inmac.GetMac( cmac, 0 );
						i := 0;
						WHILE (i < inmaclen) & (rmac[i] = cmac[i])  DO INC( i ) END;
						IF i < inmaclen THEN
							Out.String( "received packet #" ); Out.Int( incount, 1 );
							Out.String( " with wrong MAC" ); Out.Ln;
						END
					END;
					INC( incount );
					IF trbuf[5] = Ignore THEN  RETURN ReceivePacket( buf, size )
					ELSIF trbuf[5] = Debug THEN  RETURN ReceivePacket( buf, size )
					ELSIF (trbuf[5] = KEXInit) & (state # Keyexchange) THEN
						Out.String( "reexchanging keys:  not yet implemented" ); Out.Ln;
						HALT( 99 );
						(* renegotiate( ssh, package )*)
					ELSE
						IF trbuf[5] = Disconn THEN
							Out.String( "remote host closed connection: " );
							pos := 10;
							U.GetLength( trbuf, pos, l );
							FOR i := 0 TO l - 1 DO Out.Char( trbuf[14 + i] ) END;  Out.Ln;
							state := Closed
						END;
						FOR i := 0 TO size - 1 DO buf[i] := trbuf[i+5] END
					END;
					RETURN buf[0]
				END ReceivePacket;


				PROCEDURE SendDebug*;
				VAR packet: Packet;
				BEGIN
					NEW( packet,  Debug, 512 );
					packet.AppChar( 1X );				(* TRUE, always display *)
					packet.AppString( "ETH Oberon" );	(* message *)
					packet.AppString( "" );				(* language *)
					SendPacket( packet )
				END SendDebug;


				PROCEDURE Disconnect*( reason: SHORTINT;  CONST msg: ARRAY  OF CHAR );
				VAR packet: Packet;
				BEGIN
					IF state > Closed THEN
						NEW( packet, Disconn, 512 );
						packet.AppInteger( reason );
						packet.AppString( msg );
						packet.AppString( "" );	(* language *)
						SendPacket( packet );

						tcp.Close( );  state := Closed;
						IF msg # "" THEN  Out.String( msg );  Out.Ln  END;
						Out.String( "connection to " ); Out.String( servername );  Out.String( " closed "); Out.Ln;
					END
				END Disconnect;

				PROCEDURE GetChannelNo*( ): LONGINT;
				BEGIN
					INC( clientChannelNo );
					RETURN clientChannelNo
				END GetChannelNo;

				PROCEDURE PacketAvailable*(  ): BOOLEAN;
				BEGIN
					IF state = Closed THEN  RETURN FALSE
					ELSE RETURN  tcp.Available( ) >= 16
					END
				END PacketAvailable;


				PROCEDURE NegotiateAlgorythms;
				VAR
					l, p, len, n: LONGINT;  kex: SHORTINT;
					buf: ARRAY 4096 OF CHAR;
					x, m: ARRAY 512 OF CHAR;  lbuf: ARRAY 4 OF CHAR;
					cipher: Ciphers.Cipher; keybits, maclen: LONGINT;
					modname: ARRAY 32 OF CHAR;
					mode: SHORTINT;
					mac: HMAC.HMac;
					sha1: SHA1.Hash;
					packet: Packet;
				BEGIN
					state := Keyexchange;
					NEW( sha1 );
					sha1.Initialize;
					p := 0;  U.GetLength( cvers, p, l );  sha1.Update( cvers, 0, l + 4 );		(* VC *)
					p := 0;  U.GetLength( svers, p, l );  sha1.Update( svers, 0, l + 4 );		(* VS *)

					packet := ClientAlgorythms( );

					Int2Chars( packet.len, lbuf );
					sha1.Update( lbuf, 0, 4 );  sha1.Update( packet.buf^, 0, packet.len );	(* IC *)
					SendPacket( packet );

					IF ReceivePacket( buf, len ) = KEXInit THEN
						Int2Chars( len, lbuf );
						sha1.Update( lbuf, 0, 4 );  sha1.Update( buf, 0, len );				(* IS *)

						p := 17;
						FOR n := 1 TO 8 DO
							U.GetString( buf, p, x );
							IF 2 IN G.debug THEN  Out.String( x ); Out.Ln  END;
							CASE n OF
							|1:
									algoMatch( KEXAlgorythms, x, m );
									IF m = "diffie-hellman-group1-sha1" THEN kex := 1
									ELSIF m = "diffie-hellman-group14-sha1" THEN kex := 2
									ELSIF m = "diffie-hellman-group-exchange-sha1" THEN kex := 3
									ELSE 
										Out.String( 'no common kex alg found' ); Out.Ln;
										Out.String( "   client: " ); Out.String( KEXAlgorythms );  Out.Ln;
										Out.String( "   server: " ); Out.String( x );  Out.Ln;
										Disconnect( 2, "protocol error" );  RETURN
									END
							|2:
									algoMatch( SHKAlgorythms, x, m );
									IF m = "" THEN  
										Out.String( 'no common server host key alg found' ); Out.Ln;
										Out.String( "   client: " ); Out.String( SHKAlgorythms );  Out.Ln;
										Out.String( "   server: " ); Out.String( x );  Out.Ln;
										Disconnect( 2, "protocol error" );  RETURN  
									END
							|3, 4:
									algoMatch( cipherList, x, m );
									IF m = "" THEN
										Out.String( 'no common cipher found' ); Out.Ln;
										Out.String( "   client: " ); Out.String( cipherList );  Out.Ln;
										Out.String( "   server: " ); Out.String( x );  Out.Ln;
										Disconnect( 2, "protocol error" );  RETURN  
									END;
									G.GetCipherParams( m, modname, keybits, mode );
									cipher := Ciphers.NewCipher( modname );
									IF n = 3 THEN
										new.outcipher := cipher;  new.outkeybits := keybits; new.inmode := mode
									ELSE
										new.incipher := cipher;  new.inkeybits := keybits; new.outmode := mode
									END;
							|5, 6:
									algoMatch( hmacList, x, m );
									IF m = "none" THEN
									ELSIF m # "" THEN
										G.GetHMacParams( m, modname, maclen );
										NEW( mac, modname )
									ELSE 
										Out.String( 'no common hmac found' ); Out.Ln;
										Out.String( "   client: " ); Out.String( hmacList );  Out.Ln;
										Out.String( "   server: " ); Out.String( x );  Out.Ln;
										Disconnect( 2, "protocol error" );  RETURN
									END;
									IF n = 5 THEN
										new.outmac := mac;  new.outmaclen := maclen
									ELSE
										new.inmac := mac;  new.inmaclen := maclen
									END;
							|7, 8:
									algoMatch( ComprAlgorythms, x, m );
									IF m # "none" THEN 
										Out.String( 'no common compr alg found' ); Out.Ln;
										Out.String( "   client: " ); Out.String( ComprAlgorythms );  Out.Ln;
										Out.String( "   server: " ); Out.String( x );  Out.Ln;
										Disconnect( 2, "protocol error" );  RETURN 
									END
							END;
						END;
					ELSE Disconnect( 2, "protocol error" );  RETURN
					END;
					Out.String( "exchanging keys" ); Out.Ln;
					IF kex = 1 THEN Group1( sha1 ) 
					ELSIF kex = 2 THEN Group14( sha1 )
					ELSIF kex = 3 THEN GroupExchange( sha1 ) 
					END;
					IF state # Closed THEN
						ActivateNewKeys;
						state := Connected;
						Out.String( "key exchange done" ); Out.Ln
					ELSE
						Out.String( "key exchange failed" ); Out.Ln
					END;
				END NegotiateAlgorythms;

				PROCEDURE ClientAlgorythms(): Packet;
				VAR packet: Packet;
				BEGIN
					NEW( packet, KEXInit, 2048 );
					U.RandomBytes( packet.buf^, 1, 16 );  packet.len := 17;
					packet.AppString( KEXAlgorythms );
					packet.AppString( SHKAlgorythms );
					packet.AppString( cipherList );  packet.AppString( cipherList );
					packet.AppString( hmacList );  packet.AppString( hmacList );
					packet.AppString( ComprAlgorythms );  packet.AppString( ComprAlgorythms );
					packet.AppString( Languages );  packet.AppString( Languages );
					packet.AppChar(  0X );	(* FALSE *)
					packet.AppInteger( 0 );
					RETURN packet
				END ClientAlgorythms;

				PROCEDURE Group1( sha1: SHA1.Hash );
				CONST DHInit = 1EX;  DHReply = 1FX;
				VAR
					buf: ARRAY 1024 OF CHAR; p, pos, len, lshkb, lf: LONGINT;
					pub, serverpub, sec: B.BigNumber;  dh: DH.DH;  packet: Packet;
				BEGIN
					IF 1 IN G.debug THEN
						Out.String( "diffie-hellman-group1-sha1 key exchange ... " );  Out.Ln;
					END;
					NEW( dh, 0, "dh.ssh.group1" );
					pub := dh.GenPubKey( );

					NEW( packet, DHInit, 1024 );
					U.PutBigNumber( packet.buf^, packet.len, pub );
					SendPacket( packet );

					IF ReceivePacket( buf, len ) = DHReply THEN
						pos := 1;
						U.GetLength( buf, pos, lshkb );
						sha1.Update( buf, 1, 4 + lshkb );					(* KS *)
						sha1.Update( packet.buf^, 1, packet.len - 1 );	(* e *)
						INC( pos, lshkb );
						U.GetLength( buf, pos, lf );
						sha1.Update( buf, 1 + 4 + lshkb, 4 + lf );			(*  f *)
						B.AssignBin( serverpub, buf, 1 + 4 + lshkb + 4, lf );
						sec := dh.ComputeKey( serverpub );
						p := 0;  U.PutBigNumber( secret, p, sec );
						sha1.Update( secret, 0, p );							(* K *)
						sha1.GetHash( hash, 0 );
						IF 1 IN G.debug THEN  Out.String( "done" );  Out.Ln  END;
						CheckSHK( buf, 1, 1 + 4 + lshkb + 4 + lf );
						IF incount < 5 THEN  sessionId := hash END;
					ELSE
						Disconnect( 2, "protocol error: 'DH REPLY' package expected" );
					END
				END Group1;
				
				PROCEDURE Group14( sha1: SHA1.Hash );
				CONST DHInit = 1EX;  DHReply = 1FX;
				VAR
					buf: ARRAY 2048 OF CHAR; p, pos, len, lshkb, lf: LONGINT;
					pub, serverpub, sec: B.BigNumber;  dh: DH.DH;  packet: Packet;
				BEGIN
					IF 1 IN G.debug THEN
						Out.String( "diffie-hellman-group14-sha1 key exchange ... " );  Out.Ln;
					END;
					NEW( dh, 0, "dh.ssh.group14" );
					pub := dh.GenPubKey( );

					NEW( packet, DHInit, 2048 );
					U.PutBigNumber( packet.buf^, packet.len, pub );
					SendPacket( packet );

					IF ReceivePacket( buf, len ) = DHReply THEN
						pos := 1;
						U.GetLength( buf, pos, lshkb );
						sha1.Update( buf, 1, 4 + lshkb );					(* KS *)
						sha1.Update( packet.buf^, 1, packet.len - 1 );	(* e *)
						INC( pos, lshkb );
						U.GetLength( buf, pos, lf );
						sha1.Update( buf, 1 + 4 + lshkb, 4 + lf );			(*  f *)
						B.AssignBin( serverpub, buf, 1 + 4 + lshkb + 4, lf );
						sec := dh.ComputeKey( serverpub );
						p := 0;  U.PutBigNumber( secret, p, sec );
						sha1.Update( secret, 0, p );							(* K *)
						sha1.GetHash( hash, 0 );
						IF 1 IN G.debug THEN  Out.String( "done" );  Out.Ln  END;
						CheckSHK( buf, 1, 1 + 4 + lshkb + 4 + lf );
						IF incount < 5 THEN  sessionId := hash END;
					ELSE
						Disconnect( 2, "protocol error: 'DH REPLY' package expected" );
					END
				END Group14;

				PROCEDURE CheckSHK( CONST buf: ARRAY OF CHAR; shk, sig: LONGINT );
				VAR keyblob, signature: ARRAY 2048 OF CHAR;
				BEGIN
					Out.String( "checking server hostkey" ); Out.Ln;
					U.GetString( buf, shk, keyblob );
					U.GetString( buf, sig, signature );
					IF ~SSHKeys.VerifyIdentity( keyblob, signature, servername, hash ) THEN
						Out.String( "Server host key verification failed" ); Out.Ln;
						Disconnect( 2, "protocol error" );
					END;
				END CheckSHK;

				PROCEDURE GroupExchange( sha1: SHA1.Hash );
				CONST GEXRequest = 22X;  GEXGroup = 1FX;  GEXInit = 20X;  GEXReply = 21X;
				VAR
					buf1,buf2: ARRAY 4096 OF CHAR; pos, b1len, b2len, l, lshkb, lf: LONGINT;
					pub, serverpub, sec, prim, gen: B.BigNumber;  dh: DH.DH;
					pack1, pack2: Packet;
				BEGIN
					IF 1 IN G.debug THEN
						Out.String( "diffie-hellman-group-exchange-sha1 key exchange ... " ); Out.Ln;
					END;
					NEW( pack1, GEXRequest, 64 );
					pack1.AppInteger( 1024 );
					pack1.AppInteger( 1024 );
					pack1.AppInteger( 2048 );
					SendPacket( pack1 );

					IF ReceivePacket( buf1, b1len ) = GEXGroup THEN
						pos := 1;
						U.GetLength( buf1, pos, l );  B.AssignBin( prim, buf1, pos, l );
						INC( pos, l );
						U.GetLength( buf1, pos, l );  B.AssignBin( gen, buf1, pos, l );
						NEW( dh, 512, "" );
						dh.SetPrime( prim, gen );
						pub := dh.GenPubKey( );

						NEW( pack2, GEXInit, 1024 );
						U.PutBigNumber( pack2.buf^, pack2.len, pub );
						SendPacket( pack2 );

						IF ReceivePacket( buf2, b2len ) = GEXReply THEN
							pos := 1;
							U.GetLength( buf2, pos, lshkb );
							sha1.Update( buf2, 1, 4 + lshkb );					(* KS *)
							sha1.Update( pack1.buf^, 1, 12 );					(* min || n || max *)
							sha1.Update( buf1, 1, b1len - 1 );					(* p || g *)
							sha1.Update( pack2.buf^, 1, pack2.len - 1 );		(* e *)
							INC( pos, lshkb );
							U.GetLength( buf2, pos, lf );
							sha1.Update( buf2, 1 + 4 + lshkb, 4 + lf );		(* f *)
							B.AssignBin( serverpub, buf2, 1 + 4 + lshkb + 4, lf );
							sec := dh.ComputeKey( serverpub );
							pos := 0;  U.PutBigNumber( secret, pos, sec );
							sha1.Update( secret, 0, pos );						(* K *)
							sha1.GetHash( hash, 0 );
							IF 1 IN G.debug THEN  Out.String( "done" );  Out.Ln  END;
							CheckSHK( buf2, 1, 1 + 4 + lshkb + 4 + lf );
							IF incount < 5 THEN  sessionId := hash END;
						ELSE
							Disconnect( 2, "protocol error: 'DH GEX REPLY' package expected" );
						END
					ELSE
						Disconnect( 2, "protocol error: 'DH GEX GROUP' package expected" );
					END;
				END GroupExchange;



				PROCEDURE ActivateNewKeys;
				VAR len: LONGINT;  buf: ARRAY 512 OF CHAR; packet: Packet;
				BEGIN
					DeriveKey( 'C', new.outkeybits DIV 8, buf );
					new.outcipher.InitKey( buf, new.outkeybits );
					DeriveKey( 'A', 16, buf );
					new.outcipher.SetIV( buf, new.outmode );

					DeriveKey( 'D', new.inkeybits DIV 8, buf );
					new.incipher.InitKey( buf, new.inkeybits );
					DeriveKey( 'B', 16, buf );
					new.incipher.SetIV( buf, new.inmode );

					NEW( packet, NewKeys, 64 );  SendPacket( packet );

					IF ReceivePacket( buf, len ) = NewKeys THEN
						DeriveKey( 'E', 20, outhkey );
						outmac := new.outmac;  outmaclen := new.outmaclen;
						DeriveKey(  'F', 20, inhkey );
						inmac := new.inmac;   inmaclen := new.inmaclen;
						outcipher := new.outcipher;  incipher := new.incipher;
						IF 0 IN G.debug THEN
							Out.String( "receive cipher: " );  Out.String( incipher.name );  Out.Ln;
							Out.String( "send cipher:     " );  Out.String( outcipher.name );  Out.Ln;
							Out.String( "receive MAC:   " );  Out.String( inmac.name );
									Out.Int( inmaclen, 7 );  Out.Ln;
							Out.String( "send MAC:       " );  Out.String( outmac.name );
									Out.Int( outmaclen, 7 );  Out.Ln;
						END
					ELSE
						Disconnect( 2, "protocol error:  'NEWKEYS' packet expected" )
					END
				END ActivateNewKeys;


				PROCEDURE DeriveKey( keykind: CHAR;  keylen: LONGINT;  VAR key: ARRAY OF CHAR );
				VAR
					buf: ARRAY 512 OF CHAR;
					i, p, top, slen: LONGINT;
					h: SHA1.Hash;
				BEGIN
					NEW( h );  h.Initialize;
					p := 0;  U.GetLength( secret, p, slen );
					h.Update( secret, 0, slen + 4 );
					h.Update( hash, 0, 20 );
					buf[0] := keykind;  h.Update( buf, 0, 1 );
					h.Update( sessionId, 0, 20 );
					h.GetHash( buf, 0 );  top :=  h.size;
					WHILE top < keylen DO
						h.Initialize;
						p := 0;  U.GetLength( secret, p, slen );
						h.Update( secret, 0, slen + 4 );
						h.Update( hash, 0, 20 );
						h.Update( buf, 0, top );
						h.GetHash( buf, top );  INC( top,  h.size );
					END;
					FOR i := 0 TO keylen - 1 DO key[i] := buf[i] END;
				END DeriveKey;


			END Connection;


TYPE
	Packet* = OBJECT (** SSH Packet for sending *)
			VAR
				buf-: POINTER TO ARRAY OF CHAR;
				len-: LONGINT;

				PROCEDURE & Init*( type: CHAR; size: LONGINT );
				BEGIN
					NEW( buf, size );  buf[0] := type;  len := 1;
				END Init;

				PROCEDURE AppChar*( c: CHAR );
				BEGIN
					buf[len] := c;  INC( len )
				END AppChar;

				PROCEDURE AppInteger* ( v: LONGINT );
				VAR i: INTEGER;
				BEGIN
					FOR i := 3 TO 0 BY -1 DO buf[len + i] := CHR( v MOD 256 );  v := v DIV 256 END;
					INC( len, 4 )
				END AppInteger;

				PROCEDURE AppString*( CONST str: ARRAY OF CHAR );
				VAR l, p: LONGINT;  c: CHAR;
				BEGIN
					l := 0;  c := str[0];  p := len + 4;
					WHILE (l < LEN( str )) & (c # 0X) DO buf[p + l] := c;  INC( l );  c := str[l]  END;
					AppInteger( l );
					INC( len, l )
				END AppString;

				PROCEDURE AppArray*( CONST arr: ARRAY OF CHAR;  pos, arrlen: LONGINT );
				VAR i: LONGINT;
				BEGIN
					AppInteger( arrlen );
					FOR i := 0 TO arrlen -1 DO buf[len] := arr[pos + i];  INC( len )  END
				END AppArray;


		END Packet;

VAR hexd: ARRAY 17 OF CHAR;


	PROCEDURE Int2Chars( v: LONGINT;  VAR buf: ARRAY OF CHAR );
	VAR i: INTEGER;
	BEGIN
		FOR i := 3 TO 0 BY -1 DO buf[i] := CHR( v MOD 256 );  v := v DIV 256 END;
	END Int2Chars;

	PROCEDURE Head( CONST buf, s: ARRAY OF CHAR ): BOOLEAN;
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN( s ) - 1 DO
			IF (buf[i] # s[i]) & (s[i] # 0X) THEN  RETURN FALSE  END
		END;
		RETURN TRUE
	END Head;

	PROCEDURE ReceiveLine( tcp: TCP.Connection;  VAR buf: ARRAY OF CHAR ): LONGINT;
	VAR i, l, res: LONGINT;
	BEGIN
		i := 0;
		REPEAT tcp.Receive( buf, i, 1, 1, l, res );  INC( i );
		UNTIL buf[i - 1] = NL;
		IF buf[i - 2] = CR THEN i := i - 2 ELSE i := i - 1 END;
		buf[i] := 0X;
		RETURN i
	END ReceiveLine;


	PROCEDURE algoMatch( CONST cstr, sstr: ARRAY OF CHAR;  VAR match: ARRAY OF CHAR );
	VAR
		si, ci: INTEGER;  matched: BOOLEAN;  tmp: ARRAY 64 OF CHAR;

		PROCEDURE nextSuit( CONST buf: ARRAY OF CHAR;  VAR i: INTEGER;  VAR suit: ARRAY OF CHAR );
		VAR j: INTEGER;
		BEGIN
			WHILE (i < LEN( buf )) & (buf[i] # 0X) & ((buf[i] = ',') OR (buf[i] = ' ')) DO  INC( i )  END;
			j := 0;
			WHILE (i < LEN( buf )) & (buf[i] # 0X) & ((buf[i] # ',') & (buf[i] # ' ')) DO
				suit[j]  := buf[i];  INC( i );  INC( j )
			END;
			suit[j] := 0X;
		END nextSuit;

	BEGIN  ci := 0;
		REPEAT  nextSuit( cstr, ci, match );  si := 0;
			REPEAT
				nextSuit( sstr, si, tmp );
				matched := (tmp # "") & (tmp = match)
			UNTIL matched OR (tmp = "");
		UNTIL matched OR (match = "");
	END algoMatch;

BEGIN
	hexd := "0123456789ABCDEF"
END SSHTransport.
