
MODULE Clipboard;	(** AUTHOR "G.F."; PUROSE "X11 clipboard interface";  *)

IMPORT	SYSTEM, Unix, Machine, X11, X11Api, Displays, XDisplay, Plugins, Log := KernelLog, 
		Modules, Texts, TextUtilities, Strings, HostClipboard, Objects;

CONST  
	BufferSize = 2000H;
	
TYPE
	Buffer = POINTER TO ARRAY BufferSize OF CHAR;
	
	Grabber = OBJECT
	CONST 
		HSize = 256;
	VAR 
		terminate: BOOLEAN;
		lastSelectionHead: ARRAY HSize OF CHAR;
		
	
		PROCEDURE &Init;
		BEGIN 
			terminate := FALSE; 
			lastSelectionHead := "";
		END Init;
		
		PROCEDURE SelectionIsNew(): BOOLEAN;
		VAR i: LONGINT;  rc, lc: CHAR;
		BEGIN 
			rc := recBuffer[0];  lc := lastSelectionHead[0];  i := 0;
			WHILE (rc = lc) & (rc # 0X) & (lc # 0X) & (i < HSize-1) DO 
				INC( i );   rc := recBuffer[i];  lc := lastSelectionHead[i];
			END;
			RETURN rc # lc
		END SelectionIsNew;
		
		PROCEDURE SaveSelection;
		VAR i: LONGINT;  c: CHAR;
		BEGIN
			i := 0; 
			REPEAT  c := recBuffer[i];  lastSelectionHead[i] := c;  INC( i )
			UNTIL (c = 0X) OR (i >= HSize) 
		END SaveSelection;
			
	BEGIN{ACTIVE}
		LOOP
			GetX11Selection;
			IF SelectionIsNew() THEN
				SaveSelection;
				UnixToA2;  
				
				Texts.clipboard.AcquireWrite;	
				Texts.clipboard.Delete( 0, Texts.clipboard.GetLength() );
				TextUtilities.StrToText( Texts.clipboard, 0, utf8Buffer^ );
				Texts.clipboard.ReleaseWrite;
			END;
			IF terminate THEN  Objects.Terminate  END;
			Objects.Sleep( 350 )
		END;
	END Grabber;


VAR
	sendBuffer, recBuffer, utf8Buffer: Buffer;
	slen, rlen, ulen	: LONGINT;
	received	: BOOLEAN;
	
	grabber		: Grabber;
	
	myProperty	: X11.Atom;
	xdisp		: X11.DisplayPtr;
	primary		: X11.Window;
	secondary	: X11.Window;
	

	
	PROCEDURE A2ToUnix;	(* UTF-8 to XA_STRING *)
	VAR i, newlen, unicode: LONGINT; 
	BEGIN
		i := 0;  newlen := 0;
		WHILE i < slen  DO
			unicode := Utf8ToUnicode( sendBuffer^, i );
			IF unicode >= 100H THEN  unicode := 0B6H  END;
			sendBuffer[newlen] := CHR( unicode );
			INC( newlen )
		END;
		slen := newlen
	END A2ToUnix;
	

	
	PROCEDURE UnixToA2;
	VAR i, d, tag: LONGINT;  unicode, utflen: LONGINT;
	BEGIN
		i := 0;  ulen := 0;
		WHILE (i < rlen) & (ulen < BufferSize - 5) DO
			unicode := ORD( recBuffer[i] );  INC( i );
			IF (unicode = ORD( '\' )) & (recBuffer[i] = 'u') THEN
				INC( i );
				unicode := ScanHexDigits( recBuffer^, i );
			END;
			IF unicode >= 800H THEN  tag := 0E0H; utflen := 3
			ELSIF unicode >= 80H THEN  tag := 0C0H;  utflen := 2
			ELSE  tag := 0; utflen := 1
			END;
			d := utflen - 1;
			WHILE d > 0 DO
				utf8Buffer[ulen + d] := CHR( 80H + unicode MOD 40H ); 
				unicode := unicode DIV 40H;  DEC( d )
			END;
			utf8Buffer[ulen]  := CHR( tag + unicode );
			INC( ulen, utflen )
		END;
		utf8Buffer[ulen] := 0X;  INC( ulen )
	END UnixToA2;


	PROCEDURE ScanHexDigits( CONST buf: ARRAY OF CHAR;  VAR pos: LONGINT ): LONGINT;
	VAR e, unicode: LONGINT;  c: CHAR;
	BEGIN
		e := pos + 4;  unicode := 0;
		REPEAT
			c := buf[pos];  INC( pos );;
			IF (c >= '0') & (c <= '9' ) THEN unicode := unicode*10H + ORD( c ) - ORD( '0' )
			ELSIF (c >= 'a') & (c <= 'f') THEN unicode := unicode*10H + ORD( c ) - ORD( 'a' ) + 10
			ELSIF (c >= 'A') & (c <= 'F') THEN unicode := unicode*10H + ORD( c ) - ORD( 'A' ) + 10
			END;
		UNTIL pos = e;
		RETURN unicode
	END ScanHexDigits;

	PROCEDURE Utf8ToUnicode( CONST buf: ARRAY OF CHAR;  VAR pos: LONGINT ): LONGINT;
	VAR unicode, tag, next, ch: LONGINT;  ;
	BEGIN
		ch := ORD( buf[pos] );  INC( pos );
		IF ch < 128 THEN  unicode := ch
		ELSE
			tag :=  ch DIV 10H;   unicode := ch MOD 10H;  
			IF tag = 0EH THEN  next := pos + 2
			ELSE (* tag = 0CH *) next := pos + 1
			END;
			REPEAT
				unicode := unicode*40H + ORD( buf[pos] ) MOD 40H;  INC( pos )
			UNTIL pos >= next;
		END;
		RETURN unicode
	END Utf8ToUnicode;
	
	PROCEDURE ClearSelection;
	BEGIN 
	(*	Texts.ClearLastSelection	*)
	END ClearSelection;
	

	PROCEDURE ClipboardChanged( sender, data : ANY );
	BEGIN
		Texts.clipboard.AcquireRead;
		PutToClipboard( Texts.clipboard );
		Texts.clipboard.ReleaseRead;
	END ClipboardChanged;



	(** Copy text to X11 clipboard *)
	PROCEDURE PutToClipboard( text : Texts.Text );
	BEGIN
		ASSERT((text # NIL) & (text.HasReadLock()));	
		TextUtilities.TextToStr( text, sendBuffer^ );  slen := Strings.Length( sendBuffer^ );
		A2ToUnix;
		Machine.Acquire( Machine.X11 );
		X11.SetSelectionOwner( xdisp, X11.XAPRIMARY, primary, X11.lastEventTime );	
		Machine.Release( Machine.X11 );
	END PutToClipboard;

	PROCEDURE SendSelection( VAR event: X11Api.XSelectionRequestEvent );
	VAR ev: X11.SelectionEvent; 
	BEGIN
		ev.typ := X11.SelectionNotify;
		ev.requestor := event.requestor;
		ev.selection := event.selection;
		ev.target := event.target;
		ev.time := event.time;
		IF (event.selection = X11.XAPRIMARY) & (event.target = X11.XASTRING) THEN
			ev.property := event.property;
			Machine.Acquire( Machine.X11 );
			X11.ChangeProperty( xdisp, ev.requestor, ev.property, ev.target, 8, X11.PropModeReplace, 
								  ADDRESSOF( sendBuffer[0] ), slen );
			Machine.Release( Machine.X11 );
		ELSE
			ev.property := X11.None
		END;
		Machine.Acquire( Machine.X11 );
		X11.SendEvent( xdisp, ev.requestor, X11.False, 0, ADDRESSOF(ev) );
		Machine.Release( Machine.X11 );
	END SendSelection;



	(** Copy text of X11 clipboard to text *)
	PROCEDURE GetFromClipboard( text : Texts.Text );
	BEGIN
		ASSERT((text # NIL) & (text.HasWriteLock()));
		GetX11Selection;
		UnixToA2;
		TextUtilities.StrToText( text, 0, utf8Buffer^ );
	END GetFromClipboard;
	
	
	PROCEDURE GetX11Selection;
	BEGIN{EXCLUSIVE}
		received := FALSE;
		Machine.Acquire( Machine.X11 );
		X11.ConvertSelection( xdisp, X11.XAPRIMARY, X11.XASTRING, myProperty, primary, X11.lastEventTime );
		Machine.Release( Machine.X11 );
		AWAIT( received );
	END GetX11Selection;

	PROCEDURE ReceiveSelection( VAR event: X11Api.XSelectionEvent );
	VAR type: X11.Atom;  format, len, after: LONGINT;  prop, adr: ADDRESS; ch: CHAR; 
	BEGIN {EXCLUSIVE}
		rlen := 0; recBuffer[0] := 0X;
		IF (event.selection = X11.XAPRIMARY) & (event.property = myProperty) THEN
			Machine.Acquire( Machine.X11 );
			X11.GetWindowProperty( xdisp, event.requestor, event.property, 0, BufferSize, X11.False, 
									  event.target, type, format, len, after, prop );
			Machine.Release( Machine.X11 );
			adr := prop;
			IF len >= BufferSize THEN len := BufferSize - 2  END;
			WHILE len > 0 DO
				SYSTEM.GET( adr, ch ); INC( adr ); DEC( len );
				IF ch # 0X THEN  recBuffer[rlen] := ch;  INC( rlen )  END	
			END;
			recBuffer[rlen] := 0X;  INC( rlen );
			Machine.Acquire( Machine.X11 );
			X11.Free( prop );  X11.DeleteProperty( xdisp, event.requestor, event.property );
			Machine.Release( Machine.X11 );
		END;
		received := TRUE;
	END ReceiveSelection;



	PROCEDURE GetXDisplay;
	VAR p: Plugins.Plugin;  disp: XDisplay.Display;
	BEGIN
		p := Displays.registry.Await("XDisplay");
		disp := p(XDisplay.Display);
		xdisp := disp.xdisp;  
		primary := disp.primary;  
		secondary := disp.secondary;
	END GetXDisplay;

	(* set Selection handlers to NIL *)
	PROCEDURE Cleanup;
	BEGIN
		grabber.terminate := TRUE;
		Objects.Sleep( 1000 );
		
		X11Api.SendSelection := NIL;
		X11Api.ReceiveSelection := NIL;
		X11Api.ClearSelection := NIL;
		
		Texts.clipboard.onTextChanged.Remove( ClipboardChanged );
		HostClipboard.SetHandlers( NIL, NIL );
		
		Log.Enter; Log.String( "X11 clipboard unregistered at host clipboard interface." );  Log.Exit;
	END Cleanup;


	PROCEDURE Install*;
	BEGIN
		IF Unix.Version = "Darwin" THEN
			Log.String( "Can't register the X11 clipboard in the Darwin port (ABI incompatiblity)" ); Log.Ln
		ELSE
			GetXDisplay;  
			X11Api.SendSelection := SendSelection;
			X11Api.ReceiveSelection := ReceiveSelection;
			X11Api.ClearSelection := ClearSelection;
			
			Machine.Acquire( Machine.X11 );
			myProperty := X11.InternAtom( xdisp, ADDRESSOF("UNICODE"), X11.False );
			Machine.Release( Machine.X11 );
			
			NEW( sendBuffer );  NEW( recBuffer );  slen := 0;  rlen := 0;
			NEW( utf8Buffer );  ulen := 0;
			
			(* register with AosText clipboard *)
			Texts.clipboard.onTextChanged.Add( ClipboardChanged );
			HostClipboard.SetHandlers( GetFromClipboard, PutToClipboard );
			
			NEW( grabber );
			
			Modules.InstallTermHandler( Cleanup );
			Log.Enter; Log.String("X11 clipboard registered at host clipboard interface."); Log.Exit;
		END
	END Install;


BEGIN
END Clipboard.



 Clipboard.Install ~


 SystemTools.Free Clipboard ~
	
	
	  ---------------------------------------------
	   Cut & paste between X11 applications and UnixAos. 
	
	   After performing 'Clipboard.Install ~' the X11 clipboard and the
	   Aos clipboard get synchronized. Every new X11 selection modifies 
	   the Aos clipboard and the copy operation with the pie menu in 
	   Aos alters the primary X11 selection. The selection can then be 
	   inserted into an X11 application (e.g. the mail tool Thunderbird) 
	   by clicking the MM button. 
	   
	   To stop the clipboard synchronization perform:
	        'SystemTools.Free Clipboard ~'.
	        
	        
	   ---------------------------------------------
