MODULE EFIBlockIO; (** AUTHOR "Matthias Frei"; PURPOSE "EFI Block I/O Protocol"; *)

IMPORT
	EFI, SYSTEM;

CONST
	Revision* = 00010000H;

VAR
	GUID- : EFI.GUID;

TYPE BlockIOMedia* = RECORD
	MediaId-: EFI.Int32;
	RemovableMedia-: EFI.Boolean;
	MediaPresent-: EFI.Boolean;
	LogicalPartition-: EFI.Boolean;
	ReadOnly-: EFI.Boolean;
	WriteCaching-: EFI.Boolean;
	BlockSize-: EFI.Int32;
	IoAlign-: EFI.Int32;
	LastBlock-: EFI.LBA;
END;

TYPE Protocol* = POINTER TO ProtocolDescription;

TYPE BlockIOReset* = PROCEDURE{C}(This : Protocol; ExtendedVerification : EFI.Boolean) : EFI.Status;
TYPE BlockIOReadBlocks* = PROCEDURE{C}(This : Protocol; MediaId : EFI.Int32; LBA: EFI.LBA; BufferSize : EFI.Int; VAR Buffer : ARRAY OF SYSTEM.BYTE) : EFI.Status;
TYPE BlockIOWriteBlocks* = PROCEDURE{C}(This : Protocol; MediaId : EFI.Int32; LBA: EFI.LBA; BufferSize : EFI.Int; CONST Buffer : ARRAY OF SYSTEM.BYTE) : EFI.Status;
TYPE BlockIOFlushBlocks* = PROCEDURE{C}(This : Protocol) : EFI.Status;

TYPE ProtocolDescription* = RECORD(EFI.ProtocolDescription)
	Revision-: EFI.Int64;
	Media-{UNTRACED} : POINTER TO BlockIOMedia;
	Reset-: BlockIOReset;
	ReadBlocks-: BlockIOReadBlocks;
	WriteBlocks-: BlockIOWriteBlocks;
	FlushBlocks-: BlockIOFlushBlocks;
END;

BEGIN
	GUID.Data1 := -69B1A4DDH; (* 964E5B21H *)
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
	(*GUID = EFI.GUID (964E5B21H; 6459H, 11D2H, (8EH, 39H, 0H, A0H, C9H, 69H, 72H, 3BH) );*)
END EFIBlockIO.