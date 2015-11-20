MODULE StdIO;	(** AUTHOR gf;  PURPOSE "Unix standard IO and argument channels *)

(* Commands.Context for programs running outside Aos *)

IMPORT S := SYSTEM, Modules, Commands, Streams, Unix;

CONST 
	AddrSize = SIZEOF( ADDRESS );
VAR 
	env-: Commands.Context;
	argc-: LONGINT;
	
	
	argv: ADDRESS;
	iarg: LONGINT;
	addr: ADDRESS; 
	ch: CHAR;
	

PROCEDURE ReceiveArg( VAR data: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );
BEGIN
	len := 0;
	REPEAT
		IF ch = 0X THEN
			IF iarg >= argc THEN  
				IF len >= min THEN  res := Streams.Ok  ELSE  res := Streams.EOF  END;
				RETURN
			END;
			S.GET( argv + iarg*AddrSize, addr );
			INC( iarg );
		END;
		REPEAT
			S.GET( addr, ch );  data[ofs] := ch;  INC( addr );  INC( ofs );  INC( len );  DEC( size )
		UNTIL (ch = 0X) OR (size <= 0);
		IF ch = 0X THEN  data[ofs-1] := ' '  END
	UNTIL (size <= 0) OR (ofs >= LEN(data));
	res := Streams.Ok
END ReceiveArg;

PROCEDURE ReceiveStdin( VAR data: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );
VAR ures: LONGINT;
BEGIN
	len := 0;
	REPEAT
		ures := Unix.read( 0, ADDRESSOF( data[ofs] ), size );
		IF ures > 0 THEN  INC( ofs, ures );  DEC( size, ures );  INC( len, ures )  END;
	UNTIL (len >= min) OR ((ures <= 0) & (Unix.errno() # Unix.EINTR));
	IF len > 0 THEN  res := Streams.Ok  ELSE  res := Streams.EOF  END
END ReceiveStdin;

PROCEDURE SendStdout( CONST data: ARRAY OF CHAR;  ofs, len: LONGINT;  prop: BOOLEAN;  VAR res: LONGINT );
VAR ignore: LONGINT;
BEGIN
	ignore := Unix.write( 1, ADDRESSOF( data[ofs] ), len );  res := Streams.Ok
END SendStdout;


PROCEDURE SendErrout( CONST data: ARRAY OF CHAR;  ofs, len: LONGINT;  prop: BOOLEAN;  VAR res: LONGINT );
VAR ignore: LONGINT;
BEGIN
	ignore := Unix.write( 2, ADDRESSOF( data[ofs] ), len );  res := Streams.Ok
END SendErrout;

PROCEDURE Cleanup;
BEGIN
	env.error.Update;
	env.out.Update
END Cleanup;

PROCEDURE Setup;
VAR
	arg: Streams.Reader;
	stdin: Streams.Reader;
	stdout: Streams.Writer;
	errout: Streams.Writer
BEGIN
	NEW( arg, ReceiveArg, 512 );
	NEW( stdin, ReceiveStdin, 1024 );
	NEW( stdout, SendStdout, 1024 );
	NEW( errout, SendErrout, 512 );
	NEW( env, stdin, arg, stdout, errout, NIL );
	argc := Unix.argc;
	argv := Unix.argv;
	iarg := 0; ch := 0X;
	Modules.InstallTermHandler( Cleanup )
END Setup

BEGIN
	Setup
END  StdIO.
