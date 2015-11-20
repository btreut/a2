MODULE V24;   (**  AUTHOR "fof"; PURPOSE "V24 (V24/RS-232 driver) for WinAos";  **)

IMPORT Kernel32, KernelLog, Heaps, Kernel, Commands, Serials, Strings;

CONST

	MaxPortNo = 32;   (* Up to 8 serial ports supported *)

(*

TYPE

	DCB32 = RECORD  (* DCB structure for Win32 *)
		DCBlength: LONGINT;   (* sizeof(DCB) *)
		BaudRate: LONGINT;   (* current baud rate*)
		flags: SET;   (* bits in flags:
				DWORD fBinary: 1; (* binary mode, no EOF check *)
				DWORD fParity: 1; (* enable parity checking *)
				DWORD fOutxCtsFlow:1; (* CTS output flow control *)
				DWORD fOutxDsrFlow:1; (* DSR output flow control *)
				DWORD fDtrControl:2; (* DTR flow control type *)
				DWORD fDsrSensitivity:1; (* DSR sensitivity *)
				DWORD fTXContinueOnXoff:1; (* XOFF continues Tx *)
				DWORD fOutX: 1; (* XON/XOFF out flow control *)
				DWORD fInX: 1; (* XON/XOFF in flow control *)
				DWORD fErrorChar: 1; (* enable error replacement *)
				DWORD fNull: 1; (* enable null stripping *)
				DWORD fRtsControl:2; (* RTS flow control *)
				DWORD fAbortOnError:1; (* abort reads/writes on error *)
				DWORD fDummy2:17; (* reserved *) *)
		wReserved: INTEGER;   (* not currently used *)
		XonLim: INTEGER;   (* transmit XON threshold *)
		XoffLim: INTEGER;   (* transmit XOFF threshold *)
		ByteSize: SHORTINT;   (* number of bits/byte, 4-8 *)
		Parity: SHORTINT;   (* 0-4=no,odd,even,mark,space *)
		StopBits: SHORTINT;   (* 0, 1, 2 = 1, 1.5, 2 *)
		XonChar: CHAR;   (* Tx and Rx XON character *)
		XoffChar: CHAR;   (* Tx and Rx XOFF character *)
		ErrorChar: CHAR;   (* error replacement character *)
		EofChar: CHAR;   (* end of input character *)
		EvtChar: CHAR (* received event character *)
	END;
	COMMTIMEOUTS = RECORD  (* COMMTIMEOUTS *)
		ReadInterval: LONGINT;
		ReadTotalMultiplier: LONGINT;
		ReadTotalConstant: LONGINT;
		WriteTotalMultiplier: LONGINT;
		WriteTotalConstant: LONGINT
	END;
	COMSTAT32 = RECORD  (* COMSTAT for Win32 *)
		status: SET;   (* fields in status:
				DWORD fCtsHold : 1; (* Tx waiting for CTS signal *)
				DWORD fDsrHold : 1; (* Tx waiting for DSR signal *)
				DWORD fRlsdHold : 1; (* Tx waiting for RLSD signal *)
				DWORD fXoffHold : 1; (* Tx waiting, XOFF char rec'd *)
				DWORD fXoffSent : 1; (* Tx waiting, XOFF char sent *)
				DWORD fEof : 1; (* EOF character sent *)
				DWORD fTxim : 1; (* character waiting for Tx *)
				DWORD fReserved : 25; (* reserved *) *)
		cbInQueue: LONGINT;   (* bytes in input buffer *)
		cbOutQueue: LONGINT (* bytes in output buffer *)
	END;
	*)

	(*	Handle = POINTER TO RECORD (Kernel32.Object)
	(*
			recBuf: ARRAY BufSize OF S.BYTE;
			recBufSize, recBufPos: LONGINT;
			*)
		port: LONGINT
	END;
*)


TYPE

	Port* = OBJECT (Serials.Port)
	VAR
		handle: Kernel32.HANDLE;
		portname: ARRAY 6 OF CHAR; (* Name COM1 to COM8 must terminate with a 0X *)
		timer : Kernel.Timer;

		PROCEDURE & Init*( port: LONGINT );
		VAR fn: Heaps.FinalizerNode;
		BEGIN
			NEW(timer);
			COPY( "COM ", portname );
			IF port < 10 THEN
				portname[3] := CHR( ORD( "0" ) + port );
				portname[4]:= 0X;
			ELSE
				portname[3] := CHR( ORD( "0" ) + (port DIV 10) );
				portname[4] := CHR( ORD( "0" ) + (port MOD 10) );
				portname[5] := 0X;
			END;
			handle := Kernel32.InvalidHandleValue;
			NEW( fn ); fn.finalizer := SELF.FinalizePort; Heaps.AddFinalizer( SELF, fn );
		END Init;

		PROCEDURE Open*( bps, data, parity, stop: LONGINT;  VAR res: LONGINT );
		BEGIN {EXCLUSIVE}
			IF handle = Kernel32.InvalidHandleValue THEN
				SetPortState( bps, data, parity, stop, res );
				IF res = Serials.Ok THEN
					KernelLog.String( portname );  KernelLog.String( " opened" ); KernelLog.Ln
				END;
			ELSE
				res := Serials.PortInUse;
			END;
		END Open;

	(** Send len characters from buf to output, starting at ofs. res is non-zero on error. *)
		PROCEDURE Send*( CONST buf: ARRAY OF CHAR;  ofs, len: LONGINT;  propagate: BOOLEAN;  VAR res: LONGINT );
		VAR written: LONGINT;  ret: Kernel32.BOOL;
		BEGIN
			ASSERT ( LEN( buf ) >= ofs + len );   (* array bound check not implemented in Kernel32.WriteFile *)
			IF (handle # Kernel32.InvalidHandleValue) THEN
				ret := Kernel32.WriteFile( handle, buf[ofs], len, written, NIL );
				IF (ret # Kernel32.False) & (written = len) THEN
					charactersSent  := charactersSent + written;
					res := Serials.Ok;
				ELSE
					res := Serials.TransportError;
				END;
			ELSE
				res := Serials.Closed;
			END
		END Send;

	(** Send a single character to the UART. *)
		PROCEDURE SendChar*( ch: CHAR; VAR res: LONGINT );
		VAR ret: Kernel32.BOOL;  written: LONGINT;
		BEGIN
			IF handle # Kernel32.InvalidHandleValue THEN
				ret := Kernel32.WriteFile( handle, ch, 1, written, NIL );
				IF (ret # Kernel32.False) & (written=1) THEN
					INC(charactersSent);
					res := Serials.Ok;
				ELSE
					res := Serials.TransportError;
				END;
			ELSE
				res := Serials.Closed;
			END
		END SendChar;

	(** Receive size characters into buf, starting at ofs and return the effective number of bytes read in len.
		Wait until at least min bytes (possibly zero) are available.
			res is non-zero on error. *)

		PROCEDURE Receive*( VAR buf: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );
		VAR i, l, read, ret: LONGINT;
		BEGIN
			ASSERT ( LEN( buf ) >= ofs + size );
			ASSERT ( LEN( buf ) >= ofs + min );   (* array bound check not implemented in Kernel32.ReadFile *)
			res := Serials.Ok; len := 0;
			i := ofs;  l := Available();
			WHILE (res = Serials.Ok) & ((min > 0) OR ((l > 0) & (size > 0))) DO  (* fof 060804 *)
				IF l > size THEN l := size END;
				IF (handle # Kernel32.InvalidHandleValue) THEN
					IF  (l > 0) THEN
						ret := Kernel32.ReadFile( handle, buf[i], l, read, NIL );
						IF (ret # Kernel32.False) & (read = l) THEN
							charactersReceived := charactersReceived + read;
							DEC( min, l );  DEC( size, l );  INC( len, l );  INC( i, l );
						ELSE
							(* If we've already received <min> bytes, <res> will become Serials.Ok later *)
							res := Serials.TransportError;
						END;
					END;
				ELSE
					res := Serials.Closed;
				END;
				l := Available();
				IF (res = Serials.Ok) & ( (min > 0) OR ((l > 0) & (size > 0)) ) THEN
					Wait;
				END;
			END;
			IF min <= 0 THEN res := Serials.Ok END;
		END Receive;

	(** Wait for the next character is received in the input buffer.  *)
		PROCEDURE ReceiveChar*( VAR ch: CHAR;  VAR res: LONGINT );
		VAR l, ret, read: LONGINT;
		BEGIN
			IF handle # Kernel32.InvalidHandleValue THEN
				REPEAT
					l := Available();
					IF l = 0 THEN Wait; END;
				UNTIL (l > 0) OR (handle = Kernel32.InvalidHandleValue);
				ret := Kernel32.ReadFile( handle, ch, 1, read, NIL );
				IF (ret # Kernel32.False) & (read = 1) THEN
					INC(charactersReceived);
					res := Serials.Ok
				ELSE
					res := Serials.TransportError;
				END
			ELSE
				res := Serials.Closed;
			END
		END ReceiveChar;

		PROCEDURE Available*( ): LONGINT;
		VAR errors: SET;  stat: Kernel32.ComStat;  res: Kernel32.BOOL;
		BEGIN
			IF handle # Kernel32.InvalidHandleValue THEN
				res := Kernel32.ClearCommError( handle, errors, stat );
				IF res # Kernel32.False THEN RETURN stat.cbInQue END
			END;
			RETURN 0
		END Available;

	(** Open a serial port (numbered from 0) connection.  bps is the required bits per second.
	data is the number of bits per communication unit.  parity is the parity mode.
	stop is the number of stop bits.
	res: Ok, PortInUse, NoSuchPort, WrongBPS, WrongData, WrongParity, WrongStop, Failed *)
		PROCEDURE SetPortState( bps, data, parity, stop: LONGINT;  VAR res: LONGINT );
		VAR
			hFile: Kernel32.HANDLE;  dcb: Kernel32.DCB;
			ret: Kernel32.BOOL;  err: LONGINT;
			windowsComName: ARRAY 16 OF CHAR;
		BEGIN
			res := Serials.Ok;

			windowsComName := "\\.\";
			Strings.Append(windowsComName, portname);

			hFile := 	Kernel32.CreateFile( windowsComName,
												  {Kernel32.GenericRead, Kernel32.GenericWrite}, {},
												  NIL , Kernel32.OpenExisting, {}, Kernel32.NULL );
			IF hFile # Kernel32.InvalidHandleValue THEN
				ret := Kernel32.GetCommState( hFile, dcb );
				IF ret # Kernel32.False THEN
					dcb.BaudRate := bps;
					IF (data >= 4) & (data <= 8) THEN dcb.ByteSize := CHR( data )
					ELSE res := Serials.WrongData
					END;
					CASE stop OF
					| Serials.Stop1:
						dcb.StopBits := Kernel32.OneStopBit
					| Serials.Stop1dot5:
						dcb.StopBits := Kernel32.One5StopBits
					| Serials.Stop2:
						dcb.StopBits := Kernel32.TwoStopBits
					ELSE
						res := Serials.WrongStop
					END;
					CASE parity OF
					| Serials.ParNo:
						dcb.Parity := Kernel32.NoParity
					| Serials.ParOdd:
						dcb.Parity := Kernel32.OddParity
					| Serials.ParEven:
						dcb.Parity := Kernel32.EvenParity
					| Serials.ParMark:
						dcb.Parity := Kernel32.MarkParity
					| Serials.ParSpace:
						dcb.Parity := Kernel32.SpaceParity
					ELSE
						res := Serials.WrongParity
					END;
					IF res = Serials.Ok THEN
						ret := Kernel32.SetCommState( hFile, dcb );
						IF ret # Kernel32.False THEN
							ret := Kernel32.PurgeComm( hFile, {Kernel32.PurgeTXClear, Kernel32.PurgeRXClear} );
							ret := Kernel32.SetupComm( hFile, 800H, 800H );
							handle := hFile;
							RETURN
						END
					END
				END;
				ret := Kernel32.CloseHandle( hFile )
			END;
			IF res = Serials.Ok THEN
				err := Kernel32.GetLastError();
				CASE err OF
				Kernel32.ErrorFileNotFound:
						res := Serials.NoSuchPort
				| Kernel32.ErrorAccessDenied:
						res := Serials.PortInUse
				| Kernel32.ErrorInvalidParameter:
						res := Serials.WrongBPS
				ELSE res := Serials.TransportError
				END
			END
		END SetPortState;

		PROCEDURE FinalizePort( ptr: ANY );
		BEGIN
			Close();
		END FinalizePort;

	(** Get the port state: speed, no. of data bits, parity, no. of stop bits (only valid if openstat is TRUE) *)
		PROCEDURE GetPortState*( VAR openstat: BOOLEAN;  VAR bps, data, parity, stop: LONGINT );
		VAR dcb: Kernel32.DCB;  ret: Kernel32.BOOL;
		BEGIN {EXCLUSIVE}
			openstat := FALSE;
			IF handle # Kernel32.InvalidHandleValue THEN
				ret := Kernel32.GetCommState(handle, dcb );
				IF ret # Kernel32.False THEN
					openstat := TRUE;
					bps := dcb.BaudRate;
					data := ORD(dcb.ByteSize);

					CASE dcb.StopBits OF
						|Kernel32.OneStopBit: stop := Serials.Stop1;
						|Kernel32.One5StopBits: stop := Serials.Stop1dot5;
						|Kernel32.TwoStopBits: stop := Serials.Stop2;
					ELSE
						KernelLog.String("Win32.V24.GetPortState: Wrong stops bits"); KernelLog.Ln;
					END;

					CASE dcb.Parity OF
						|Kernel32.NoParity: parity := Serials.ParNo;
						|Kernel32.OddParity: parity := Serials.ParOdd;
						|Kernel32.EvenParity: parity := Serials.ParEven;
						|Kernel32.MarkParity: parity := Serials.ParMark;
						|Kernel32.SpaceParity: parity := Serials.ParSpace;
					ELSE
						KernelLog.String("Win32.V24.GetPortState: Wrong parity mode"); KernelLog.Ln;
					END;
				END;
			END;
		END GetPortState;

	(** ClearMC - Clear the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE ClearMC*( s: SET );
		BEGIN {EXCLUSIVE}
			IF (handle # Kernel32.InvalidHandleValue) THEN
				IF Serials.Break IN s THEN Kernel32.ClearCommBreak( handle ) END;
				IF Serials.DTR IN s THEN Kernel32.EscapeCommFunction( handle, Kernel32.CLRDTR ) END;
				IF Serials.RTS IN s THEN Kernel32.EscapeCommFunction( handle, Kernel32.CLRRTS ) END
			END
		END ClearMC;

	(** SetMC - Set the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE SetMC*( s: SET );
		VAR res: LONGINT;
		BEGIN {EXCLUSIVE}
			IF handle # Kernel32.InvalidHandleValue THEN
				IF Serials.Break IN s THEN res := Kernel32.SetCommBreak( handle ) END;
				IF Serials.DTR IN s THEN
					res := Kernel32.EscapeCommFunction( handle, Kernel32.SETDTR )
				END;
				IF Serials.RTS IN s THEN
					res := Kernel32.EscapeCommFunction( handle, Kernel32.SETRTS )
				END
			END
		END SetMC;

	(** GetMC - Return the state of the specified modem control lines.  s contains
			the current state of DSR, CTS, RI, DCD & Break Interrupt. *)
		PROCEDURE GetMC*( VAR s: SET );
		VAR state: SET;  res: LONGINT;
		BEGIN {EXCLUSIVE}
			s := {};
			IF handle # Kernel32.InvalidHandleValue THEN
				res := Kernel32.GetCommModemStatus( handle, state );
				IF Kernel32.MSCTSOn IN state THEN INCL( s, Serials.CTS ) END;
				IF Kernel32.MSDSROn IN state THEN INCL( s, Serials.DSR ) END;
				IF Kernel32.MSRingOn IN state THEN INCL( s, Serials.RI ) END;
				IF Kernel32.MSRLSDOn IN state THEN INCL( s, Serials.DCD ) END
			END
		END GetMC;

		PROCEDURE Wait;
		BEGIN {EXCLUSIVE}
			timer.Sleep(1);
		END Wait;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			IF handle # Kernel32.InvalidHandleValue THEN
				Kernel32.CloseHandle( handle );  handle := Kernel32.InvalidHandleValue
			END
		END Close;

	END Port;

	(** Scan the installed serial ports  *)
	PROCEDURE Scan*(context : Commands.Context);
	VAR i, ret: LONGINT; name,winname: ARRAY 256 OF CHAR;
		strNumber: ARRAY 4 OF CHAR; found: BOOLEAN;
	BEGIN
		context.out.String( "Serial port detection and inspection (WinAos):" ); context.out.Ln;
		found := FALSE;
		FOR i := 1 TO MaxPortNo DO
			COPY( "COM", name );
			Strings.IntToStr(i, strNumber);
			Strings.Append(name, strNumber);
			ret := Kernel32.QueryDosDevice( name, winname, LEN( name ) );
			IF ret # Kernel32.False THEN
				found := TRUE;
				context.out.String( name ); context.out.String( ":" );
				context.out.String( winname );  context.out.String( "." );
				context.out.Ln
			END;
		END;
		IF ~found THEN context.out.String("no ports found"); context.out.Ln END;
	END Scan;

	PROCEDURE Install*(context: Commands.Context);
	END Install;

(** Create a port object for each windows COM port *)
	PROCEDURE Init*;
	VAR
		i, ret: LONGINT;
		name : ARRAY 8 OF CHAR;
		winname: ARRAY 256 OF CHAR;
		port: Port;
		strNumber: ARRAY 4 OF CHAR;
		serialsPort: Serials.Port;
	BEGIN
		FOR i := 1 TO MaxPortNo DO
			COPY( "COM", name );
			Strings.IntToStr(i, strNumber);
			Strings.Append(name, strNumber);
			ret := Kernel32.QueryDosDevice(name, winname, LEN( winname ) );
			IF ret # 0 THEN
				serialsPort := Serials.GetPort(i);
				IF (serialsPort = NIL) OR (serialsPort.description # winname) THEN
					IF serialsPort # NIL THEN Serials.UnRegisterPort(serialsPort) END;
					NEW(port, i);
					Serials.RegisterOnboardPort( i , port, name, winname );
				END;
			END;
		END;
	END Init;

BEGIN
	Init();
END V24.


V24.Install ~
V24.Scan ~

SystemTools.Free V24 ~

Serials.Show ~
SystemTools.Free Serials ~