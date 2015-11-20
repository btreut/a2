MODULE PowerManagementEvents; (** AUTHOR "Patrick Hunziker"; PURPOSE "Wake-On-LAN - trigger computer booting by sending a magic network packet"; *)
(**  see http://en.wikipedia.org/wiki/Wake-on-LAN or BIOS "PME = Power Management Events". 
   	for details , and how to use it in wired and wireless networks depending on the hardware used.
  	BIOS settings of the computer need to have PME events or 'wake-on-lan' or similar  setting activated.
  	according to ACPI specification, wake-on-lan should be effective in computer power-down states S3, S4 and S5.
  	UDP is used here, but other protocols containing the same magic string are possible, too ;
  	routers can interfere with such signals, in particular if sent accross internet across firewalls: consult http://en.wikipedia.org/wiki/Wake-on-LAN 
  	for solutions, also taking security aspects (brute force attacks) into account.
  *)

IMPORT UDP, DNS, IP,  Commands;

CONST WOLport*=7; (*usually sent to port 7 or 9, but any port can be used in principle.*)

(** usage: PowerManagementEvents.Wake host MAC ~  *)
PROCEDURE Wake*(context : Commands.Context);
VAR
	i, j, res, hex, pos: LONGINT;
	c: CHAR;
	hostname: ARRAY 128 OF CHAR;
	fip: IP.Adr;
	data: ARRAY 6 + 16*6 OF CHAR;
	mac: ARRAY 6 OF CHAR;
	socket: UDP.Socket;

BEGIN
	context.arg.SkipWhitespace; 
	context.arg.String(hostname);
	context.arg.SkipWhitespace; 
	FOR i:=0 TO 5 DO
		context.arg.Int(hex, TRUE); (*! to do: accept Hex numbers without leading 0 and trailing H for MAC in the format AA:BB:CC:DD:EE:FF *)
		mac[i] := CHR(hex);
		context.arg.Char(c);
	END;

	IF hostname # "" THEN
		context.out.String("Wake: Resolving host name: "); context.out.String(hostname); context.out.Ln;
		DNS.HostByName(hostname, fip, res);
		i:=0; pos:=0;
		IF res = DNS.Ok THEN
			NEW(socket,UDP.NilPort,res);
			FOR i:=0 TO 5 DO data[pos] := 0FFX; INC(pos); END;
			FOR i:=0 TO 15 DO
				FOR j:=0 TO 5 DO data[pos]:= mac[j]; INC(pos) END;
			END;
			socket.Send( fip, WOLport,  data,  0, 6+16*6, res);
			IF res=UDP.Ok THEN context.out.String("Wake: Sending wakeup signal"); context.out.Ln;
			ELSE 				   context.out.String("Wake: Failed sending wakeup signal to ");  context.out.Int(fip.ipv4Adr,8); context.out.Ln;
			END;
		ELSE					   context.error.String("Wake: Couldn't resolve host name: "); context.error.String(hostname); context.error.Ln;
		END;
	ELSE context.out.String("Wake: wrong syntax. Use 'PowerManagementEvents.Wake host MAC ~' ");context.out.Ln;
	END;

END Wake;

END PowerManagementEvents.

(*
Usage: PowerManagementEvents.Wake host MAC ~   (* ; "host" as url or IP address; "MAC" address of computer's network card *)

Example:
PowerManagementEvents.Wake 172.168.178.21 000H:040H:0F4H:0C7H:064H:09EH ~ (*game PC*)

SystemTools.Free PowerManagementEvents~
*)
