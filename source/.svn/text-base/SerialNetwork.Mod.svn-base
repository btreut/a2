MODULE SerialNetwork; (** AUTHOR "negelef"; PURPOSE "Serial Network Adapter"; *)

IMPORT Serials, Network, Plugins, Commands, Modules, Strings;

TYPE
	LinkDevice = OBJECT (Network.LinkDevice)
	
		VAR port: Serials.Port;
		VAR next: LinkDevice;
		VAR status: LONGINT;
		
		PROCEDURE & Init (port: Serials.Port; next: LinkDevice);
		VAR name: ARRAY 20 OF CHAR; result: LONGINT;
		BEGIN
			Constr (Network.TypePointToPoint, Network.MaxPacketSize, 0);
			SELF.port := port; SELF.next := next; SELF.status := Network.LinkLinked;
			name := "SerialPort#"; Strings.Append (name, port.name); SetName (name);
			Network.registry.Add(SELF, result);
			ASSERT (result = Plugins.Ok);
		END Init;

		PROCEDURE Linked*(): LONGINT;
		BEGIN RETURN status;
		END Linked;

		PROCEDURE DoSend*(dst: Network.LinkAdr; type: LONGINT; VAR l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: LONGINT);
		VAR result: LONGINT;
		BEGIN {EXCLUSIVE}
			port.Send (l3hdr, 0, h3len, FALSE, result);
			port.Send (l4hdr, 0, h4len, FALSE, result);
			port.Send (data, dofs, dlen, FALSE, result);
		END DoSend;

		PROCEDURE Receive;
		VAR length, result: LONGINT; data: ARRAY Network.MaxPacketSize OF CHAR; buffer: Network.Buffer;
		BEGIN
			LOOP
				port.Receive (data, 0, LEN (data), 1, length, result);
				IF result # Serials.Ok THEN EXIT END;
				buffer := Network.GetNewBuffer();
				Network.Copy (data, buffer.data, 0, 0, length);
				QueueBuffer(buffer, 0);
			END;
		END Receive;
		
		PROCEDURE Finalize (connected: BOOLEAN);
		BEGIN
			IF connected THEN port.Close END;
			BEGIN {EXCLUSIVE} AWAIT (status # Network.LinkLinked) END;
			Network.registry.Remove(SELF);
			Finalize^(connected);
		END Finalize;
		
	BEGIN {ACTIVE}
		Receive;
		BEGIN {EXCLUSIVE} status := Network.LinkNotLinked END;
	END LinkDevice;
	
VAR device: LinkDevice;

(* SerialNetwork.Install portnr bps data parity *)
PROCEDURE Install* (context: Commands.Context);
VAR portNr, bps, data, stop, parity, result: LONGINT; parityChar: CHAR; port: Serials.Port;
BEGIN
	IF context.arg.GetInteger (portNr, FALSE) & context.arg.GetInteger (bps, FALSE) &
		context.arg.GetInteger (data, FALSE) & context.arg.GetInteger (stop, FALSE) & context.arg.GetChar (parityChar) THEN
			port := Serials.GetPort(portNr);
			IF port # NIL THEN
				CASE CAP(parityChar) OF
					| "N" : parity := Serials.ParNo;
					| "O" : parity := Serials.ParOdd;
					| "E" : parity := Serials.ParEven;
					| "M" : parity := Serials.ParMark;
					| "S" : parity := Serials.ParSpace;
				ELSE parity := Serials.ParNo
				END;
				port.Open (bps, data, parity, stop, result);
				IF result = Serials.Ok THEN
					NEW (device, port, device);
					context.out.String ("Serial network: Installed device '"); context.out.String (device.name); context.out.Char ("'"); context.out.Ln;
				ELSE
					context.error.String ("Serial network: Failed to open port "); context.error.Int (portNr, 0); context.error.Ln;
					context.result := Commands.CommandError;
				END;				
			ELSE
				context.error.String ("Serial network: Port "); context.error.Int (portNr, 0); context.error.String (" is not available"); context.error.Ln;
				context.result := Commands.CommandError;
			END;
	ELSE
		context.error.String ("Serial network: Invalid command arguments"); context.error.Ln;
		context.result := Commands.CommandParseError;
	END;
END Install;

PROCEDURE Cleanup;
BEGIN
	WHILE device # NIL DO device.Finalize (TRUE); device := device.next END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	device := NIL;
END SerialNetwork.

V24.Install ~
SystemTools.Free SerialNetwork ~
SerialNetwork.Install 1 115200 8 1 none ~

