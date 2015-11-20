(* Patrick Stuedi, 30.08.01 *)

MODULE RfsConnection; (** AUTHOR "pstuedi"; PURPOSE "Remote File System connections"; *)

IMPORT SYSTEM, TCP, DNS, IP, KernelLog;

CONST
	MaxNameLen = 64;
	OpenTimeout = 10000;


TYPE
	(** Wrapper for TCP.Connection so that TCP.Connection shouldn't Trap **)
	Connection* = OBJECT
		VAR
			rpcConn: TCP.Connection;
			host: ARRAY MaxNameLen OF CHAR;
			port: INTEGER;

		PROCEDURE &Init*(host: ARRAY OF CHAR; port: INTEGER);
			VAR len: LONGINT;
		BEGIN
			len := Len(host);
			CopyBuffer(host, len + 1, SELF.host, 0);
			SELF.host[len] := 0X;
			SELF.port := port;
			NEW(rpcConn);
	END Init;

		(** res = 0 if Connection opened *)
		PROCEDURE Open*(VAR res: LONGINT);
			VAR ip: IP.Adr;
		BEGIN
			IF rpcConn.state = TCP.Unused THEN
				DNS.HostByName(host, ip, res);
				IF res # DNS.Ok THEN
					KernelLog.String("Connection->konnte DNS nicht aufloesen");
					KernelLog.Ln;
				ELSE
					rpcConn.Open(TCP.NilPort, ip, port, res);
					IF res # TCP.Ok THEN
						KernelLog.String("Connection->error in Opening, res: ");
						KernelLog.Int(res, 12);
					ELSE
						AwaitState(TCP.OpenStates, TCP.ClosedStates, OpenTimeout, res);
						IF res # TCP.Ok THEN
							KernelLog.String("Connection->bad state ");
							KernelLog.Int(res, 6);
							KernelLog.Ln;
						ELSE
							KernelLog.String("Connection->connection Opened");
							KernelLog.Ln;
						END;
					END;
				END;
			ELSE
				res := TCP.NotConnected;
				KernelLog.String("Connection->connection used");
				KernelLog.Ln;
			END;
		END Open;

		PROCEDURE Close*;
		BEGIN
			rpcConn.Close;
		END Close;

		(** If Connection down, Receive tries to connect again **)
		PROCEDURE Receive*(VAR buf: ARRAY OF CHAR; off, len: LONGINT; VAR received, res: LONGINT);
		BEGIN{EXCLUSIVE}
			received := 0;
			res := TCP.NotConnected;
			IF off < 0 THEN
				KernelLog.String("Connection->receive: off not valid");
				KernelLog.Ln;
				RETURN;
			ELSIF len < 0 THEN
				KernelLog.String("Connection->receive: len not valid");
				KernelLog.Ln;
				RETURN;
			ELSIF off + len > LEN(buf) THEN
				KernelLog.String("Connection->bufferspace to small");
				KernelLog.Ln;
				RETURN;
			END;
			rpcConn.Receive(buf, off, len, len, received, res);
		END Receive;

		(** if the connection is down Send tries to connect again **)
		PROCEDURE Send*(VAR buf: ARRAY OF CHAR; off, len: LONGINT; VAR res: LONGINT);
		BEGIN{EXCLUSIVE}
			res := TCP.NotConnected;
			IF off < 0 THEN
				KernelLog.String("Connection->send: off not valid");
				KernelLog.Ln;
				RETURN;
			ELSIF len < 0 THEN
				KernelLog.String("Connection->send: len not valid");
				KernelLog.Ln;
				RETURN;
			ELSIF off + len > LEN(buf) THEN
				KernelLog.String("Connection->send: not enough bufferspace");
				KernelLog.Ln;
				RETURN;
			END;
			rpcConn.Send(buf, off, len, FALSE, res);
		END Send;

		PROCEDURE AwaitState*(good, bad: SET; ms: LONGINT; VAR res: LONGINT);
		BEGIN
			rpcConn.AwaitState(good, bad, ms, res);
		END AwaitState;

		PROCEDURE Reset*;
		BEGIN
			Close();
			NEW(rpcConn);
		END Reset;

	END Connection;


PROCEDURE Len(VAR x: ARRAY OF CHAR): LONGINT;
	VAR j: LONGINT;
BEGIN
	j := 0;
	WHILE x[j] # 0X DO
		INC(j);
	END;
	RETURN j;
END Len;

(*copy buf1 of Size len into offset of buf2 *)
PROCEDURE CopyBuffer(VAR buf1: ARRAY OF CHAR; len: LONGINT; VAR buf2: ARRAY OF CHAR; off: LONGINT);
BEGIN
	SYSTEM.MOVE(ADDRESSOF(buf1[0]), ADDRESSOF(buf2[off]), len);
END CopyBuffer;

END RfsConnection.