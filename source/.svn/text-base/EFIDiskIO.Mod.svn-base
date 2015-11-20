MODULE EFIDiskIO; (** AUTHOR "Matthias Frei"; PURPOSE "EFI Disk I/O Protocol"; *)

(** This protocol is used to abstract the block accesses of
the Block I/O protocol to a more general offset-length protocol. The firmware is responsible for adding
this protocol to any Block I/O interface that appears in the system that does not already have a Disk I/O
protocol. File systems and other disk access code utilize the Disk I/O protocol." *)

IMPORT
	EFI, SYSTEM;

CONST
	Revision* = 00010000H;

VAR
	GUID- : EFI.GUID;

TYPE Protocol* = POINTER TO ProtocolDescription;

TYPE DiskIOReadDisk* = PROCEDURE{C}(This : Protocol; MediaId : EFI.Int32; Offset : EFI.Int64; BufferSize : EFI.Int; Buffer : ADDRESS) : EFI.Status;
TYPE DiskIOWriteDisk* = PROCEDURE{C}(This : Protocol; MediaId : EFI.Int32; Offset : EFI.Int64; BufferSize : EFI.Int; Buffer : ADDRESS) : EFI.Status;

TYPE ProtocolDescription* = RECORD(EFI.ProtocolDescription)
	Revision-: EFI.Int64;
	ReadDisk-: DiskIOReadDisk;
	WriteDisk-: DiskIOWriteDisk;
END;

BEGIN
	GUID.Data1 := -31CBAE8FH; (* CE345171H *)
	GUID.Data2 := -45F5H; (*0BA0BH;*)
	GUID.Data3 := 11D2H;
	GUID.Data4[0] := -72H; (*8EH;*)
	GUID.Data4[1] := 4FH;
	GUID.Data4[2] := 00H;
	GUID.Data4[3] := -60H; (*0A0H;*)
	GUID.Data4[4] := -37H; (*0C9H;*)
	GUID.Data4[5] := 69H;
	GUID.Data4[6] := 72H;
	GUID.Data4[7] := 3BH;
END EFIDiskIO.