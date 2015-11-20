MODULE EFIGraphicsOutput; (** AUTHOR "Matthias Frei"; PURPOSE "EFI Graphics Output Protocol"; *)

IMPORT
	EFI, SYSTEM;

CONST
	(* PixelFormat enum *)
	PFRGBX8Bit*= 0; (* a pixel is 32 bit. Each color is 8bit and they are ordered Red,Green,Blue,Reserved *)
	PFBGRX8Bit*= 1; (* a pixel is 32 bit. Each color is 8bit and they are ordered Blue,Green,Red,Reserved *)
	PFBitMask*= 2; (* format is defined by PixelBitmask *)
	PFBltOnly*= 3; (* this mode does not support a physical frame buffer *)
	PFMax*= 4;

VAR
	GUID-: EFI.GUID;

TYPE GraphicsMode* = POINTER TO GraphicsModeDescription;
TYPE GraphicsModeDescription* = RECORD
	MaxMode-: EFI.Int32;
	Mode-: EFI.Int32; (*current mode. Valid mode numbers are 0 to MaxMode-1 *)
	Info-{UNTRACED}: GraphicsModeInfo;
	SizeOfInfo-: EFI.Int;
	FrameBufferBase-: EFI.PhysicalAddress;
	FrameBufferSize-: EFI.Int;
END;

TYPE GraphicsModeInfo* = POINTER TO GraphicsModeInfoDescription;
TYPE GraphicsModeInfoDescription* = RECORD
	Version-: EFI.Int32; (* = 0 for the structure specified here. If > 0, structure extended backwards compatibly *)
	HorizontalResolution-: EFI.Int32;
	VerticalResolution-: EFI.Int32;
	PixelFormat-: EFI.Int32; (* enum *)
	PixelBitmask-: RECORD RedMask-,GreenMask-,BlueMask-,ReservedMask-:EFI.Int32; END;
	PixelsPerScanline-: EFI.Int32;
END;

TYPE Protocol* = POINTER TO ProtocolDescription;
TYPE GOQueryMode* = PROCEDURE{C}(This : Protocol; ModeNumber : EFI.Int32; VAR SizeOfInfo : EFI.Int; VAR Info : GraphicsModeInfo) : EFI.Status;
TYPE GOSetMode* = PROCEDURE{C}(This : Protocol; ModeNumber : EFI.Int32) : EFI.Status;
TYPE GODummyType* = PROCEDURE{C}():EFI.Status;
TYPE ProtocolDescription* = RECORD(EFI.ProtocolDescription)
	QueryMode-: GOQueryMode;
	SetMode-: GOSetMode;
	Blt-: GODummyType; (* not implemented *)
	Mode-{UNTRACED}: GraphicsMode;
END;

BEGIN
	GUID.Data1 := LONGINT(9042A9DEH);
	GUID.Data2 := 23DCH;
	GUID.Data3 := 4A38H;
	GUID.Data4[0] := SHORTINT(96H);
	GUID.Data4[1] := SHORTINT(0FBH);
	GUID.Data4[2] := 7AH;
	GUID.Data4[3] := SHORTINT(0DEH);
	GUID.Data4[4] := SHORTINT(0D0H);
	GUID.Data4[5] := SHORTINT(80H);
	GUID.Data4[6] := 51H;
	GUID.Data4[7] := 6AH;
END EFIGraphicsOutput.
