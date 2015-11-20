MODULE EFILoadedImage; (** AUTHOR "Matthias Frei"; PURPOSE "EFI Loaded Image Protocol"; *)

IMPORT
	EFI, SYSTEM;

CONST
	Revision* = 00010000H;

VAR
	GUID-: EFI.GUID;

TYPE Protocol* = POINTER TO ProtocolDescription;

TYPE PtrToArrayOfByte* = POINTER TO ARRAY 2048 OF SYSTEM.BYTE;
TYPE LIUnload* = PROCEDURE{C}(ImageHandle : EFI.Handle) : EFI.Status;
TYPE ProtocolDescription* = RECORD(EFI.ProtocolDescription)
	Revision-: EFI.Int32;
	ParentHandle-: EFI.Handle;
	SystemTable-{UNTRACED}: POINTER TO EFI.SystemTable;

	(* source location of the image *)
	DeviceHandle-: EFI.Handle;
	FilePath : ADDRESS; (* not implemented *)
	Reserved : ADDRESS;

	(* image's load options *)
	LoadOptionsSize-: EFI.Int32;
	LoadOptions-{UNTRACED} : PtrToArrayOfByte;

	(* location where image was loaded *)
	ImageBase-: ADDRESS;
	ImageSize-: EFI.Int64;
	ImageCodeType-: EFI.Int; (* memory types: see EFI.MT... *)
	ImageDataType-: EFI.Int;

	Unload-: LIUnload;
END;

BEGIN
	GUID.Data1 := 5B1B31A1H;
	GUID.Data2 := -6A9EH; (*9562H;*)
	GUID.Data3 := 11D2H;
	GUID.Data4[0] :=-72H; (* 8EH;*)
	GUID.Data4[1] := 3FH;
	GUID.Data4[2] := 00H;
	GUID.Data4[3] := -60H; (*0A0H*)
	GUID.Data4[4] := -37H; (*0C9H;*)
	GUID.Data4[5] := 69H;
	GUID.Data4[6] := 72H;
	GUID.Data4[7] := 3BH;
END EFILoadedImage.
