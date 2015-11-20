MODULE EFISimpleFS; (** AUTHOR "Matthias Frei"; PURPOSE "EFI Simple FS Protocol"; *)

IMPORT
	EFI, EFIFileProtocol, SYSTEM;

CONST
	Revision* = 00010000H;

VAR
	GUID- : EFI.GUID;

TYPE Protocol*= POINTER TO ProtocolDescription;

TYPE SFSOpenVolume* = PROCEDURE{C}(This : Protocol; VAR Root : EFIFileProtocol.Protocol):EFI.Status;
TYPE ProtocolDescription *= RECORD(EFI.ProtocolDescription)
	Revision-:EFI.Int64;
	OpenVolume-: SFSOpenVolume
END;

BEGIN
	GUID.Data1 := -69B1A4DEH; (* 964E5B22H;*)
	GUID.Data2 := 6459H;
	GUID.Data3 := 11D2H;
	GUID.Data4[0] := -72H; (*8EH;*)
	GUID.Data4[1] := 39H;
	GUID.Data4[2] := 00H;
	GUID.Data4[3] := -60H; (*0A0H;*)
	GUID.Data4[4] := -37H; (*0C9H;*)
	GUID.Data4[5] := 69H;
	GUID.Data4[6] := 72H;
	GUID.Data4[7] := 3BH;
END EFISimpleFS.
