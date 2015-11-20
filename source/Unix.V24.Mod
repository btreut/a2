MODULE V24;		(** AUTHOR "F.Necati"; PURPOSE "V24 serial lines"; *)

IMPORT Unix, Log := KernelLog, Serials, Objects, Commands, Strings;
	
CONST
	(* modem lines  bits *)
	TIOCM_LE = 0;  TIOCM_DTR = 1; TIOCM_RTS = 2; TIOCM_ST = 3;
	TIOCM_SR = 4;  TIOCM_CTS = 5; TIOCM_CAR = 6; TIOCM_RNG = 7;
	TIOCM_DSR	= 8;  TIOCM_CD = TIOCM_CAR; TIOCM_RI = TIOCM_RNG;
	
	(* tio.iflag bits *)
	IGNBRK  = {0};
	BRKINT  = {1};
	IGNPAR  = {2};

	(* tcsetattr actions *)
	TCSANOW    = 0;
	TCSADRAIN  = 1;
	TCSAFLUSH  = 2;

	NumberOfPorts = 4;
	
	
VAR
	tcgetattr	: PROCEDURE {C} ( fd: LONGINT;  VAR tio: Unix.Termios ): LONGINT;
	tcsetattr	: PROCEDURE {C} ( fd: LONGINT; action: LONGINT;  VAR tio: Unix.Termios ): LONGINT;
	cfsetispeed	: PROCEDURE {C} ( VAR tio: Unix.Termios; speed: LONGINT ): LONGINT;
	cfsetospeed	: PROCEDURE {C} ( VAR tio: Unix.Termios; speed: LONGINT ): LONGINT;
	cfgetispeed	: PROCEDURE {C} ( VAR tio: Unix.Termios ): LONGINT;
	cfgetospeed	: PROCEDURE {C} ( VAR tio: Unix.Termios ): LONGINT;
	
	

	
TYPE 
	Port* = OBJECT (Serials.Port)
	VAR
		 fd: LONGINT;
		 portname: ARRAY 128 OF CHAR;
		 
		PROCEDURE & Init*( port: LONGINT; CONST name: ARRAY OF CHAR );
		BEGIN 
			COPY(name, portname);
			fd := 0;
		END Init;
		
		(* adapted from LNO.V24.Mod *)
		PROCEDURE Open*( bps, data, parity, stop: LONGINT;  VAR res: LONGINT );
		VAR 
			err, speed: LONGINT;
			tio: Unix.Termios;
		BEGIN {EXCLUSIVE}
			IF fd > 0 THEN res := Serials.PortInUse; RETURN END;			
		
			IF (data < 5) OR ( data > 8) OR ( parity = Serials.ParMark) OR 
			    ( parity = Serials.ParSpace) OR (stop = Serials.Stop1dot5) THEN
				res := Serials.WrongData;  RETURN;
			END;

			fd := Unix.open( ADDRESSOF(portname), Unix.rdwr, {} );
			IF fd = -1 THEN  
				fd := 0;  res := Serials.NoSuchPort;  RETURN 
			END;
			
			err := tcgetattr( fd, tio );
			
			tio.iflags:= IGNBRK + IGNPAR;
			tio.oflags:={};
			tio.cflags:= Unix.CREAD + Unix.HUPCL + Unix.CLOCAL;
			tio.lflags:={};

			IF bps < 50 THEN speed := Unix.B0	
			ELSIF bps < 75 THEN speed := Unix.B50
			ELSIF bps < 110 THEN speed := Unix.B75
			ELSIF bps < 134 THEN speed := Unix.B110
			ELSIF bps < 150 THEN speed := Unix.B134
			ELSIF bps < 200 THEN speed := Unix.B150
			ELSIF bps < 300 THEN speed := Unix.B200
			ELSIF bps < 600 THEN speed := Unix.B300
			ELSIF bps < 1200 THEN speed := Unix.B600
			ELSIF bps < 1800 THEN speed := Unix.B1200
			ELSIF bps < 2400 THEN speed := Unix.B1800
			ELSIF bps < 4800 THEN speed := Unix.B2400
			ELSIF bps < 9600 THEN speed := Unix.B4800
			ELSIF bps < 19200 THEN speed := Unix.B9600
			ELSIF bps < 38400 THEN speed := Unix.B19200
			ELSIF bps < 57600 THEN speed := Unix.B38400
			ELSIF bps < 115200 THEN speed := Unix.B57600
			ELSIF bps < 230400 THEN speed := Unix.B115200
			ELSE speed := Unix.B230400
			END;
			err := cfsetispeed( tio, speed );
			err := cfsetospeed( tio, speed );
			
			tio.cflags := tio.cflags - Unix.CSIZE;
			IF data= 5 THEN tio.cflags:= tio.cflags + Unix.CS5;
			ELSIF data= 6 THEN tio.cflags:= tio.cflags + Unix.CS6;
			ELSIF data= 7 THEN tio.cflags:= tio.cflags + Unix.CS7;
			ELSIF data= 8 THEN tio.cflags:= tio.cflags + Unix.CS8;
			END;
			
			IF parity # Serials.ParNo THEN
				tio.cflags := tio.cflags + Unix.PARENB;
				IF parity= Serials.ParOdd THEN  tio.cflags := tio.cflags + Unix.PARODD   END;
			END;
			IF stop= Serials.Stop2 THEN tio.cflags := tio.cflags + Unix.CSTOPB  END;
			
			err := tcsetattr( fd, TCSAFLUSH, tio);	
			IF err # -1 THEN 
				Log.String( "V24 opened the port: " ); Log.String( portname ); Log.Ln;
				res := Serials.Ok; 
			ELSE
				Close;
				res := Serials.NoSuchPort;
			END;
		END Open;

		PROCEDURE Close*;
		VAR err: LONGINT;
		BEGIN 
			IF fd > 0  THEN
				err:= Unix.close( fd );
				fd := 0
			END
		END Close;

		PROCEDURE Available*(): LONGINT;
		VAR  
			 num, err: LONGINT;
		BEGIN
		 	err := Unix.ioctl( fd, Unix.FIONREAD, ADDRESSOF(num) );
			RETURN num;
		END Available;

		PROCEDURE ReceiveChar*( VAR ch: CHAR;  VAR res: LONGINT );
		BEGIN	
			res := Unix.read( fd, ADDRESSOF(ch), 1);
			IF res = 1 THEN 
				INC( charactersReceived );
				res := Serials.Ok;
			ELSE 
				res := Serials.TransportError; 
			END;
		END ReceiveChar;

		(** Send - Send a byte to the specified port.  Waits until buffer space is available.  res = 0 iff ok. *)		
		PROCEDURE SendChar*( ch: CHAR;  VAR res: LONGINT );
		BEGIN
			res := Unix.write( fd, ADDRESSOF(ch), 1);
			IF res = 1 THEN 
				INC( charactersSent );
				res := Serials.Ok;
			ELSE 
				res := Serials.TransportError;
			END;
		END SendChar;

		PROCEDURE Send*( CONST buf: ARRAY OF CHAR;  ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT );
		BEGIN
			ASSERT ( LEN( buf ) >= ofs + len );   (* array bound check not implemented in Kernel32.WriteFile *)
			res := Unix.write( fd, ADDRESSOF(buf[ofs]), len );
			IF res < 0 THEN 
				res := Serials.TransportError;
			ELSE	
				INC( charactersSent, res );
				res := Serials.Ok;
			END;			
		END Send;

		PROCEDURE Receive*( VAR buf: ARRAY OF CHAR;  ofs, size, min: LONGINT;  VAR len, res: LONGINT );
		VAR i, l, read: LONGINT;
		BEGIN
			ASSERT ( LEN( buf ) >= ofs + size );
			ASSERT ( LEN( buf ) >= ofs + min );   (* array bound check not implemented in Kernel32.ReadFile *)
			res := Serials.Ok; len := 0;
			i := ofs;  l := Available();
			WHILE (res = Serials.Ok) & ( (min > 0) OR ((l > 0) & (size > 0)) ) DO  (* fof 060804 *)
				IF l > size THEN l := size END;
				IF  l > 0 THEN
					read := Unix.read(fd, ADDRESSOF(buf[i]), l );
					IF  read = l  THEN
						charactersReceived := charactersReceived + read;
						DEC( min, l );  DEC( size, l );  INC( len, l );  INC( i, l );
					ELSE
						(* If we've already received <min> bytes, <res> will become Serials.Ok later *)
						res := Serials.TransportError;
					END;
				END;
				l := Available();
				IF (res = Serials.Ok) & ( (min > 0) OR ((l > 0) & (size > 0)) ) THEN
					Objects.Sleep(1);
				END;
			END;
			IF min <= 0 THEN  res := Serials.Ok  END;
		END Receive;

		(** Get the port state: state (open, closed), speed in bps, no. of data bits, parity, stop bit length. *)
		PROCEDURE GetPortState*( VAR openstat : BOOLEAN;  VAR bps, data, parity, stop : LONGINT );
		VAR
			err, br: LONGINT;  t: SET;  tio: Unix.Termios; 
		BEGIN
			IF fd > 0 THEN
				err := tcgetattr( fd, tio );
				br := cfgetispeed( tio );
				IF br = Unix.B0 THEN bps := 0
				ELSIF br = Unix.B50 THEN bps := 50
				ELSIF br = Unix.B75 THEN bps := 75
				ELSIF br = Unix.B110 THEN bps := 110
				ELSIF br = Unix.B134 THEN bps := 134
				ELSIF br = Unix.B150 THEN bps := 150
				ELSIF br = Unix.B200 THEN bps := 200
				ELSIF br = Unix.B300 THEN bps := 300
				ELSIF br = Unix.B600 THEN bps := 600
				ELSIF br = Unix.B1200 THEN bps := 1200
				ELSIF br = Unix.B1800 THEN bps := 1800
				ELSIF br = Unix.B2400 THEN bps := 2400
				ELSIF br = Unix.B4800 THEN bps := 4800
				ELSIF br = Unix.B9600 THEN bps := 9600
				ELSIF br = Unix.B19200 THEN bps := 19200
				ELSIF br = Unix.B38400 THEN bps := 38400
				ELSIF br = Unix.B57600 THEN bps := 57600
				ELSIF br = Unix.B115200 THEN bps := 115200
				ELSIF br = Unix.B230400 THEN bps := 230400
				ELSE bps := -1
				END;
				t := tio.cflags*Unix.CSIZE;
				IF t = Unix.CS8 THEN data := 8
				ELSIF t = Unix.CS7 THEN data := 7
				ELSIF t = Unix.CS6 THEN data := 6
				ELSE data := 5
				END;
				IF tio.cflags*Unix.PARENB = {} THEN parity := Serials.ParNo
				ELSIF tio.cflags*Unix.PARODD = Unix.PARODD THEN parity := Serials.ParOdd
				ELSE parity := Serials.ParEven
				END;
				IF tio.cflags*Unix.CSTOPB = {} THEN  stop := Serials.Stop1  ELSE  stop := Serials.Stop2  END
			ELSE
				openstat := FALSE
			END
		END GetPortState;

		(** Clear the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE ClearMC*( s: SET );
		VAR
			err : LONGINT;  stat: SET;
		BEGIN
			err := Unix.ioctl( fd, Unix.TIOCMGET , ADDRESSOF(stat) );
			IF Serials.DTR IN s THEN  EXCL( stat, TIOCM_DTR )  END;
			IF Serials.RTS IN s THEN  EXCL( stat, TIOCM_RTS )  END;
			err := Unix.ioctl( fd, Unix.TIOCMSET , ADDRESSOF(stat) );			
		END ClearMC;

		(** Set the specified modem control lines.  s may contain DTR, RTS & Break. *)
		PROCEDURE SetMC*( s: SET );
		VAR 
			err : LONGINT;  stat: SET;
		BEGIN
			err := Unix.ioctl( fd, Unix.TIOCMGET , ADDRESSOF(stat) );
			IF Serials.DTR IN s THEN  INCL( stat, TIOCM_DTR )  ELSE  EXCL( stat, TIOCM_DTR )  END;
			IF Serials.RTS IN s THEN  INCL( stat, TIOCM_RTS )  ELSE  EXCL( stat, TIOCM_RTS )  END;
			err := Unix.ioctl( fd, Unix.TIOCMSET , ADDRESSOF(stat) );			
		END SetMC;

		(** Return the state of the specified modem control lines. s contains
			the current state of DSR, CTS, RI, DCD & Break Interrupt. *)
		PROCEDURE GetMC*( VAR s: SET );
		VAR 
			err : LONGINT;  stat: SET;
		BEGIN
			err := Unix.ioctl( fd, Unix.TIOCMGET , ADDRESSOF(stat) );
			IF TIOCM_DTR IN stat THEN  INCL( s, Serials.DTR )  END;
			IF TIOCM_RTS IN stat THEN  INCL( s, Serials.RTS )  END;
			(* IF TIOCM_LE IN stat THEN INCL(s, Serials.Break) END;  *) (* ?? *)
			IF TIOCM_DSR IN stat THEN  INCL( s, Serials.DSR )  END;
			IF TIOCM_CTS IN stat THEN  INCL( s, Serials.CTS )  END;
			IF TIOCM_RI IN stat THEN  INCL( s, Serials.RI )  END;
			IF TIOCM_CAR IN stat THEN  INCL( s, Serials.DCD )  END;
		END GetMC;

		
	END Port;

	PROCEDURE Install*();
	VAR i: LONGINT;
		port: Port;
		name, ttyname: ARRAY 128 OF CHAR;
	BEGIN
		FOR i := 0 TO NumberOfPorts - 1 DO
			name:="COM ";
			name[3]:= CHR( i + ORD("1") );
			ttyname:="/dev/ttySx";
			ttyname[ 9]:= CHR( i + ORD("0") );
			NEW( port, i , ttyname);
			Serials.RegisterOnboardPort( i+1 , port, name, ttyname);
		END;
	END Install;
	
	PROCEDURE Map*(context: Commands.Context);
	VAR	number: LONGINT; name, ttyname: ARRAY 128 OF CHAR; port: Port;
	BEGIN
		IF context.arg.GetInteger(number, FALSE) & context.arg.GetString(ttyname) THEN
			name := "COM";
			Strings.AppendInt(name, number);
			NEW(port, number, ttyname); 
			Serials.RegisterOnboardPort( number, port, name, ttyname);
		END;
	END Map;
	

	PROCEDURE Initialize;
	BEGIN
		Unix.Dlsym( Unix.libc, "tcgetattr",		ADDRESSOF( tcgetattr ) );
		Unix.Dlsym( Unix.libc, "tcsetattr",		ADDRESSOF( tcsetattr ) );
		Unix.Dlsym( Unix.libc, "cfgetispeed",		ADDRESSOF( cfgetispeed ) );
		Unix.Dlsym( Unix.libc, "cfgetospeed",	ADDRESSOF( cfgetospeed ) );
		Unix.Dlsym( Unix.libc, "cfsetispeed",		ADDRESSOF( cfsetispeed ) );
		Unix.Dlsym( Unix.libc, "cfsetospeed",		ADDRESSOF( cfsetospeed ) );
	END Initialize

BEGIN
	Initialize;
(*	Install;*)
END V24.

V24.Install ~ 
V24.Map 5 ttyUSB0 ~ 

Serials.Show ~ 

SystemTools.Free V24~ 





	install /dev/ttySx as :

	COM1 -> /dev/ttyS0
	COM2 -> /dev/ttyS1
	COM3 -> /dev/ttyS2
	COM4 -> /dev/ttyS3
	
	On Solaris and Darwin hosts the tty lines have different names.
	To make them useable for Aos create symbolic links
	
	Solaris:	ln -s  /dev/ttya  /dev/ttyS0
	

	------------------------------------------
	
	you must have access rights to serial port:
	
	first method:
	must give username exclusive access to the device file, the first serial port on linux:
	
	# chown username /dev/ttyS0
	# chmod 0600 /dev/ttyS0
	
	#  ls -ls  /dev/ttyS0
	
	second method: allow anybody to use serial port 0 (be carefull for security)
	
	# chmod a+rw  /dev/ttyS0
	
	---------------------
	permanent setting:
	
	# groups   
	
	see which groups you belong	    
	if you dont belong to "dialout" group, add yourself to this group by
	
	# sudo usermode -a -G dialout your_username
	or
	# sudo adduser your_username group
	 logout and login to system. that is all.
	 
	
	  removing: 
	# sudo deluser your_username group
	
	---------------------
	------------------------------------------




