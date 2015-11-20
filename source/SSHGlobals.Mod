MODULE SSHGlobals;

IMPORT SYSTEM,
		Texts, TextUtilities, UTF8Strings, Strings, Commands, 
		Ciphers := CryptoCiphers, Out := KernelLog;

CONST
	ConfigFile* = "SSH.Configuration.Text";
	HostkeysFile* = "SSH.KnownHosts.Data";		(* entries in openssh format! *)
	PrivateKeyFile* = "SSH.RSAKey.priv";
	PublicKeyFile* = "SSH.RSAKey.pub";			(* openssh format *)

	HT= 09X;  CR = 0DX; NL = 0AX;

TYPE
	Buffer = POINTER TO ARRAY OF CHAR;

VAR
	buf: Buffer;
	bp: LONGINT; (* current position in buf *)

	debug-: SET;		(* bits: 	{0}: verbose

								transport level:
								{1}: trace protocol,
								{2}: trace protocol more detailed
								{3}: show I/O packets (type only)
								{4}: show I/O packets (with contents)
								....
						*)

	hexd: ARRAY 17 OF CHAR;	(* constant *)

	(*-------------- Debugging -----------------------*)

	PROCEDURE SetDebug*( context: Commands.Context );
	VAR i: LONGINT;
	BEGIN
		IF context.arg.GetInteger( i, FALSE ) THEN
			debug := SYSTEM.VAL( SET, i )
		ELSE
			context.result := Commands.CommandParseError;
		END;
	END SetDebug;

	(*--------------- SSH configuration  -----------------*)

	PROCEDURE NextLine;
	BEGIN
		REPEAT
			WHILE (buf[bp] = HT) OR (buf[bp] >= ' ') DO  INC( bp )  END;
			WHILE (buf[bp] = CR) OR (buf[bp] = NL) DO  INC( bp )  END
		UNTIL (buf[bp] # '#') OR (buf[bp] = 0X);  (* skip comments *)
	END NextLine;

	PROCEDURE GetConfigString( VAR str: ARRAY OF CHAR );
	VAR i: LONGINT;
	BEGIN
		WHILE(buf[bp] = HT) OR (buf[bp] = ' ') DO  INC( bp )  END;
		i := 0;
		WHILE buf[bp] > ' ' DO
			str[i] := buf[bp];  INC( i ); INC( bp )
		END;
		str[i] := 0X
	END GetConfigString;

	PROCEDURE GetConfigInt( VAR i: LONGINT );
	BEGIN
		WHILE(buf[bp] = HT) OR (buf[bp] = ' ') DO  INC( bp )  END;
		i := 0;
		WHILE (buf[bp] >= '0') & (buf[bp] <= '9') DO
			i := 10*i + ORD( buf[bp] ) - ORD( '0' );
			INC( bp )
		END
	END GetConfigInt;


	PROCEDURE GetCipherList*( VAR list: ARRAY OF CHAR );
	VAR n: INTEGER;
		x: ARRAY 64 OF CHAR;
	BEGIN
		IF buf = NIL THEN  buf := GetConfigBuffer()  END;
		bp := 0;  n := 0;  COPY( "", list );
		IF buf[bp] = '#' THEN  NextLine  END;
		WHILE buf[bp] # 0X DO
			GetConfigString( x );
			IF x = "cipher" THEN
				GetConfigString( x );
				IF n > 0 THEN  Strings.Append( list, "," )  END;
				Strings.Append( list, x );  INC( n );
			END;
			NextLine
		END
	END GetCipherList;

	PROCEDURE GetHMacList*( VAR list: ARRAY OF CHAR );
	VAR n: INTEGER;
		x: ARRAY 64 OF CHAR;
	BEGIN
		IF buf = NIL THEN  buf := GetConfigBuffer()  END;
		bp := 0;  n := 0;  COPY( "", list );
		IF buf[bp] = '#' THEN  NextLine  END;
		WHILE buf[bp] # 0X DO
			GetConfigString( x );
			IF x = "hmac" THEN
				GetConfigString( x );
				IF n > 0 THEN  Strings.Append( list, "," )  END;
				Strings.Append( list, x );  INC( n );
			END;
			NextLine
		END
	END GetHMacList;


	PROCEDURE GetCipherParams*(	CONST name: ARRAY OF CHAR;
											VAR modname: ARRAY OF CHAR;  
											VAR bits: LONGINT;
											VAR mode: SHORTINT );
	VAR x: ARRAY 128 OF CHAR;
	BEGIN
		IF buf = NIL THEN  buf := GetConfigBuffer()  END;
		bp := 0;
		COPY( "unknown", modname );  bits := 0;
		IF buf[bp] = '#' THEN  NextLine  END;
		REPEAT
			GetConfigString( x );
			IF x = "cipher" THEN  GetConfigString( x );
				IF x = name THEN
					GetConfigString( modname );  GetConfigInt( bits );
					GetConfigString( x );
					IF x = "CBC" THEN  mode := Ciphers.CBC
					ELSIF x = "CTR" THEN  mode := Ciphers.CTR
					ELSE  mode := Ciphers.ECB
					END;
				END
			END;
			NextLine
		UNTIL (buf[bp] = 0X) OR (modname # "unknown")
	END GetCipherParams;


	PROCEDURE GetHMacParams*(	CONST name: ARRAY OF CHAR;
									VAR modname: ARRAY OF CHAR;  VAR bytes: LONGINT );
	VAR x: ARRAY 128 OF CHAR;
	BEGIN
		IF buf = NIL THEN  buf := GetConfigBuffer()  END;
		bp := 0;
		COPY( "unknown", modname );  bytes := 0;
		IF buf[bp] = '#' THEN  NextLine  END;
		REPEAT
			GetConfigString( x );
			IF x = "hmac" THEN  GetConfigString( x );
				IF x = name THEN
					GetConfigString( modname );  GetConfigInt( bytes )
				END
			END;
			NextLine
		UNTIL (buf[bp] = 0X) OR (modname # "unknown")
	END GetHMacParams;


	PROCEDURE ExpandBuf( VAR buf: Buffer; newSize: LONGINT );
	VAR newBuf: Buffer; i: LONGINT;
	BEGIN
		IF LEN( buf^ ) >= newSize THEN RETURN END;
		NEW( newBuf, newSize );
		FOR i := 0 TO LEN( buf^ ) - 1 DO  newBuf[i] := buf[i]  END;
		buf := newBuf;
	END ExpandBuf;


	PROCEDURE GetConfigBuffer(): Buffer;
	VAR
		text: Texts.Text; r: Texts.TextReader;
		ch, format, res, len, i, j, bytesPerChar: LONGINT;
		buffer: Buffer;
	BEGIN
		NEW( text );
		TextUtilities.LoadAuto( text, ConfigFile, format, res );
		IF res # 0 THEN
			Out.String( "could not open file " ); Out.String( ConfigFile ); Out.Ln
		ELSE
			text.AcquireRead;
			NEW( r, text ); r.SetPosition( 0 );
			len := text.GetLength();
			bytesPerChar := 2;
			NEW( buffer, bytesPerChar*len );
			j := 0;
			FOR i := 0 TO len - 1 DO  r.ReadCh( ch );
				WHILE ~UTF8Strings.EncodeChar( ch, buffer^, j ) DO
					(* buffer too small *)
					INC( bytesPerChar );
					ExpandBuf( buffer, bytesPerChar*len );
				END
			END;
			buffer[j] := 0X;
			text.ReleaseRead;
			RETURN buffer
		END
	END GetConfigBuffer;



BEGIN
	buf := NIL;
	hexd := "0123456789ABCDEF";
END SSHGlobals.


