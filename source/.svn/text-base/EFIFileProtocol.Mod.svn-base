MODULE EFIFileProtocol; (** AUTHOR "Matthias Frei"; PURPOSE "EFI File Protocol"; *)

IMPORT
	EFI, SYSTEM;

CONST
	Revision* = 00010000H;

	(* Open Modes. Allowed combinations are Read, Read/Write, Create/Read/Write *)
	ModeRead* = 1H;
	ModeWrite* = 2H;
	ModeCreate* = LONG(8000000000000000H); (* TODO: This does probably not work! *)

	(* File Attributes *)
	ReadOnly* = 1H;
	Hidden *= 2H;
	System *= 4H;
	Reserved *= 8H;
	Directory *= 10H;
	FileArchive *= 20H;
	ValidAttr *= 37H;

VAR
	FileInfoGUID- : EFI.GUID;
	FileSystemInfoGUID- : EFI.GUID;
	FileSystemVolumeInfoGUID- : EFI.GUID;

TYPE Protocol*= POINTER TO ProtocolDescription;

(* Open or create a new file. 'This' is a pointer to a protocol instance that is the file handle to the source location. This would
typically be an open handle to a directory. A handle for the new file is returned to 'NewHandle'.  The filename may include
the path modifiers '\', '.' and '..'. If the filename starts with a '\' the relative location is the root directory. *)
TYPE FileOpen* = PROCEDURE{C}(This : Protocol; VAR NewHandle : Protocol; CONST FileName : ARRAY OF EFI.Char16; OpenMode : EFI.Int64; Attributes : EFI.Int64) : EFI.Status;
(* Close a specified handle. All dirty cached file data is flushed to the device, and the file is closed *)
TYPE FileClose* = PROCEDURE{C}(This : Protocol) : EFI.Status;
(* Close and delete a file *)
TYPE FileDelete* = PROCEDURE{C}(This : Protocol) : EFI.Status;
(* Read 'BufferSize' bytes. On success, the number bytes read is written to 'BufferSize' and the file position is updated.
If 'This' is a directory, read the directory entry at the current file position. If this entry does not fit into the buffer BufferTooSmall
is returned and the file position is not updated and 'BufferSize' is set to the size needed to read the entry. *)
TYPE FileRead* = PROCEDURE{C}(This : Protocol; VAR BufferSize : EFI.Int; Buffer : ADDRESS) : EFI.Status;
(* Write specified number of bytes to the file at the current file position. Current file position is advanced the actual number of
bytes written, which is returned in 'BufferSize'. Direct writes to open directories are not supported *)
TYPE FileWrite* = PROCEDURE{C}(This : Protocol; VAR BufferSize : EFI.Int; CONST Buffer : ARRAY OF SYSTEM.BYTE) : EFI.Status;
(* Set the current file position. Only absolute position is supported with exception of FFFFFFFFFFFFFFFFH which sets the position
to the end of the file. Seeking past the end of file is allowed (a subsequent write would grow the file. *)
TYPE FileGetPosition* = PROCEDURE{C}(This : Protocol; VAR Position : EFI.Int64) : EFI.Status;
TYPE FileSetPosition* = PROCEDURE{C}(This : Protocol; Position : EFI.Int64) : EFI.Status;
TYPE FileGetInfo* = PROCEDURE{C}(This : Protocol; CONST InformationType : EFI.GUID; VAR BufferSize : EFI.Int; VAR Buffer : ARRAY OF SYSTEM.BYTE) : EFI.Status;
TYPE FileSetInfo* = PROCEDURE{C}(This : Protocol; CONST InformationType : EFI.GUID; BufferSize : EFI.Int; CONST Buffer : ARRAY OF SYSTEM.BYTE) : EFI.Status;
TYPE FileFlush* = PROCEDURE{C}(This : Protocol) : EFI.Status;

TYPE ProtocolDescription*= RECORD(EFI.ProtocolDescription)
	Revision-: EFI.Int64;
	Open- : FileOpen;
	Close-: FileClose;
	Delete-: FileDelete;
	Read-: FileRead;
	Write-: FileWrite;
	GetPosition-: FileGetPosition;
	SetPosition-: FileSetPosition;
	GetInfo-: FileGetInfo;
	SetInfo-: FileSetInfo;
	Flush-: FileFlush;
END;

(* Information *)
(* Note : the structs should have variable size! The FileName-field can NOT be CORRECTly mapped to Oberon. *)
CONST MaxFileNameLength = 128;
TYPE FileInfo* = RECORD
	Size-: EFI.Int64; (* size of the FileInfo RECORD, including the Null-terminated  FileName string*)
	FileSize-: EFI.Int64; (* in bytes *)
	PhysicalSize-: EFI.Int64;
	CreateTime-: EFI.Time;
	LastAccessTime-: EFI.Time;
	ModificationTime-: EFI.Time;
	Attribute-: EFI.Int64;
	FileName-: ARRAY MaxFileNameLength OF EFI.Char16;
END;

(* Note : same here... *)
TYPE FileSystemInfo* =  RECORD
	Size-: EFI.Int64; (* size of the FileInfo RECORD, including the Null-terminated  VolumeLabel string*)
	ReadOnly-: EFI.Boolean;
	VolumeSize-: EFI.Int64; (* in bytes *)
	FreeSpace-: EFI.Int64;
	BlockSize-: EFI.Int32;
	VolumeLabel-: ARRAY MaxFileNameLength OF EFI.Char16;
END;

(* Note : ... and here *)
TYPE FileSystemVolumeInfo* = RECORD
	VolumeLabel-: ARRAY MaxFileNameLength OF EFI.Char16;
END;

BEGIN
	FileInfoGUID.Data1 := 09576E92H;
	FileInfoGUID.Data2 := 6D3FH;
	FileInfoGUID.Data3 := 11D2H;
	FileInfoGUID.Data4[0] := -72H; (*8EH;*)
	FileInfoGUID.Data4[1] := 39H;
	FileInfoGUID.Data4[2] := 00H;
	FileInfoGUID.Data4[3] := -60H; (*0A0H;*)
	FileInfoGUID.Data4[4] := -37H; (*0C9H;*)
	FileInfoGUID.Data4[5] := 69H;
	FileInfoGUID.Data4[6] := 72H;
	FileInfoGUID.Data4[7] := 3BH;

	FileSystemInfoGUID.Data1 := 09576E93H;
	FileSystemInfoGUID.Data2 := 6D3FH;
	FileSystemInfoGUID.Data3 := 11D2H;
	FileSystemInfoGUID.Data4[0] := -72H; (*8EH;*)
	FileSystemInfoGUID.Data4[1] := 39H;
	FileSystemInfoGUID.Data4[2] := 00H;
	FileSystemInfoGUID.Data4[3] := -60H; (*0A0H;*)
	FileSystemInfoGUID.Data4[4] := -37H; (*0C9H;*)
	FileSystemInfoGUID.Data4[5] := 69H;
	FileSystemInfoGUID.Data4[6] := 72H;
	FileSystemInfoGUID.Data4[7] := 3BH;

	FileSystemVolumeInfoGUID.Data1 := -24B8282DH; (*0DB47D7D3H*)
	FileSystemVolumeInfoGUID.Data2 := -17FH; (*0FE81H*)
	FileSystemVolumeInfoGUID.Data3 := 11D3H;
	FileSystemVolumeInfoGUID.Data4[0] := -66H; (*9AH;*)
	FileSystemVolumeInfoGUID.Data4[1] := 35H;
	FileSystemVolumeInfoGUID.Data4[2] := 00H;
	FileSystemVolumeInfoGUID.Data4[3] := -70H; (*090H;*)
	FileSystemVolumeInfoGUID.Data4[4] := 27H;
	FileSystemVolumeInfoGUID.Data4[5] := 3FH;
	FileSystemVolumeInfoGUID.Data4[6] := -3FH; (*0C1H*)
	FileSystemVolumeInfoGUID.Data4[7] := 4DH;
END EFIFileProtocol.