MODULE WebTimeServer; (** AUTHOR "Patrick Hunziker"; PURPOSE "time server RFC 868"; *)

IMPORT Modules, TCP, TCPServices, Streams, Dates;

CONST
	TimePort* = 37;

TYPE
	TimeAgent = OBJECT (TCPServices.Agent)
		VAR 
			days,hours,minutes,seconds: LONGINT; 
			t: HUGEINT;
			w: Streams.Writer;

	BEGIN {ACTIVE}
		Streams.OpenWriter(w, client.Send);
		Dates.TimeDifference(Dates.ZeroDateRFC868, Dates.Now(), days,hours,minutes,seconds); 
		t:=((HUGEINT(days)*24+hours)*60+minutes)*60+seconds; (* the leap seconds are handled implicitely: http://www.eecis.udel.edu/~mills/leap.html *)
		w.Net32(LONGINT(t));
		w.Update;
		Terminate
	END TimeAgent;

VAR
	time: TCPServices.Service;

PROCEDURE Open*;
VAR res : LONGINT;
BEGIN
	NEW(time, TimePort, NewTimeAgent, res);
END Open;

PROCEDURE Close*;
BEGIN
	IF time#NIL THEN time.Stop; time := NIL END;
END Close;

PROCEDURE NewTimeAgent(c: TCP.Connection; s: TCPServices.Service): TCPServices.Agent;
VAR a: TimeAgent;
BEGIN
	NEW(a, c, s); RETURN a
END NewTimeAgent;

PROCEDURE Cleanup;
BEGIN
	Close;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WebTimeServer.

SystemTools.Free WebTimeServer ~
SystemTools.FreeDownTo TCP ~

WebTimeServer.Open
WebTimeServer.Close
