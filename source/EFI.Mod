MODULE EFI; (** AUTHOR "Matthias Frei"; PURPOSE "Provides (low-level) API to the (Unified) Extensible Firmware Interface"; *)

IMPORT SYSTEM;

CONST
	(* Status Codes *)
	(* Success *)
	Success* = 0;
	(* Warnings *)
	WarnUnknownGlyph *= 1;
	WarnDeleteFailure *= 2;
	WarnWriteFailure	*= 3;
	WarnBufferTooSmall *= 4;
	(* Errors*)
	Error* = LONGINT(80000000H); (* == 80000000H *)
	ErrLoadError* = Error + 1;
	ErrInvalidParameter* = Error + 2;
	ErrUnsupported* = Error + 3;
	ErrBadBufferSize* = Error + 4;
	ErrBufferTooSmall* = Error + 5;
	(* ... TODO ... *)
	ErrNotFound* = Error + 14;
	(* ... TODO ... *)
	ErrEndOfFile* = Error + 31;
	ErrInvalidLanguage* = Error + 32;

	(* BSAllocatePages allocation types *)
	AllocateAnyPage* = 0;
	AllocateMaxAddress* = 1;
	AllocateAddress* = 2;
	MaxAllocateType* = 3;

	(* Memory Types (for BSAllocatePages and MemoryDescriptor.Type)*)
	MTReserved* = 0;
	MTLoaderCode* = 1;
	MTLoaderData* = 2;
	MTBootServicesCode* = 3;
	MTBootServicesData* = 4;
	MTRuntimeServicesCode* = 5;
	MTRuntimeServicesData* = 6;
	MTConventionalMemory*= 7;
	MTUnusableMemory* = 8;
	MTACPIReclaimMemory* = 9;
	MTACPIMemoryNVSM* = 10;
	MTMemoryMappedIO* = 11;
	MTMemoryMappedIOPortSpace* = 12;
	MTPalCode* = 13;
	MTMaxMemoryType* = 14;

	(* Page Size in bytes *)
	PageSize* = 1000H; (* = 4KB *)

	(* BSLocateHandle search types *)
	AllHandles* = 0; (* the 'Protocol' and 'SearchLey' argument are ignored and all handles in the system are returned *)
	ByRegistryNotify* = 1; (* 'SearchKey' supplies the Registration value returned by RegisterProtocolNotify(). 'Protocol' is ignored *)
	ByProtocol* =2; (* return all handles that support 'Protocol' the 'SearchKey' argument is ignored *)

	(* Task Priority Levels *)
	ApplicationTPL* = 4;
	CallbackTPL* = 8;
	NotifiyTPL* = 16;
	HighLevelTPL* = 31;

(* various type definitions *)
TYPE Char8* = SHORTINT;
TYPE Char16* = INTEGER;
TYPE Boolean* = BOOLEAN;

TYPE Int* = SIZE; (* size of Int architecture dependant (e.g. 32bit on i386, 64bit on ia64) *)
TYPE Int8* = SHORTINT; (* Int8, Int16, Int32, Int64 NOT architecture dependant *)
TYPE Int16* = INTEGER;
TYPE Int32* = LONGINT;
TYPE Int64* = HUGEINT;
TYPE Address*= ADDRESS;

TYPE Status* = Int;
TYPE TPL* = Int;
TYPE LBA* = Int64;
TYPE Pointer* = Address;
TYPE VirtualAddress* = Int64; (* sic! *)
TYPE PhysicalAddress* = Int64; (* sic! *)
TYPE Handle* = Pointer;
TYPE Event* = Pointer;

TYPE Protocol* = POINTER TO ProtocolDescription;
TYPE ProtocolDescription* = RECORD END;

TYPE GUID* = RECORD
	Data1*: Int32;
	Data2*: Int16;
	Data3*: Int16;
	Data4*: ARRAY 8 OF Int8;
END;

TYPE 
	MemoryDescriptorPointer*= POINTER TO MemoryDescriptor;
	MemoryDescriptor* = RECORD
		Type- : Int32;
		PhysicalStart-: PhysicalAddress;
		VirtualStart-: VirtualAddress; 
	(*	PhysicalStart-: Int64;
		VirtualStart-: Int64;	*)
		NumberOfPages-: Int64;
		Attribute-: Int64;
END;

TYPE Time* = RECORD
	Year-: Int16; (* 1998 - 20XX *)
	Month-: Int8; (* 1 - 12 *)
	Day-: Int8; (* 1 - 31 *)
	Hour-: Int8; (* 0-23 *)
	Minute-: Int8; (* 0 - 59 *)
	Second-: Int8; (* 0 - 59 *)
	Pad1 : Int8;
	Nanosecond-: Int32; (* 0 - 999,999,999 *)
	TimeZone- : Int8; (* -1440 - 1440 or 2047 (= unspecified) *)
	Daylight-: Int8; (* 1 : EFITimeAdjustDaylight, 2 : EFITimeInDaylight *)
	Pad2 : Int8;
END;

(* efi generic table header *)
TYPE TableHeader* = RECORD
	Signature-: Int64;
	Revision-: Int32;
	HeaderSize-: Int32;
	CRC32-: Int32;
	Reserved-: Int32;
END;

(* main EFI tables *)
TYPE 
SystemTable* = RECORD
	Hdr-: TableHeader;
	FirmwareVendor-{UNTRACED}: POINTER TO ARRAY OF Char16;
	FirmwareRevision-: Int32;
	ConsoleInHandle* : Handle;
	ConIn* {UNTRACED}: POINTER TO SimpleInputInterface;
	ConsoleOutHandle*: Handle;
	ConOut* {UNTRACED}: POINTER TO SimpleTextOutputInterface;
	StandardErrorHandle*: Handle;
	StdErr* {UNTRACED}: POINTER TO SimpleTextOutputInterface;
	RS- {UNTRACED}: POINTER TO RuntimeServices;
	BS* {UNTRACED}: POINTER TO BootServices;
	NumberOfTableEntries-: Int;
	ConfigurationTable-{UNTRACED}: POINTER TO ARRAY 2048 OF ConfigurationTableEntry; (* access to ACPI, SMBIOS, ... *)
END;

(* BootServices function type declarations *)
TYPE DevicePath* = RECORD
	Type-: Int8;
	SubType-: Int8;
	Length-: ARRAY 2 OF Int8;
END;
TYPE BSDummyType* = PROCEDURE{C};
(* task priority functions *)
TYPE BSTPLRaise* = PROCEDURE{C}(NewTpl : TPL) : TPL;
TYPE BSTPLRestore* = PROCEDURE{C}(oldTpl : TPL);
(* Memory functions *)
TYPE BSAllocatePages* = PROCEDURE{C}(Type : Int; MemoryType : Int; Pages : Int; VAR Memory : PhysicalAddress) : Status;
TYPE BSFreePages* = PROCEDURE{C}(Memory : PhysicalAddress; Pages : Int) : Status;
TYPE BSGetMemoryMap* = PROCEDURE{C}(VAR MemoryMapSize : Int; VAR MemoryMap : ARRAY OF MemoryDescriptor; VAR MapKey, DescriptorSize : Int; VAR DescriptorVersion : Int32) : Status;
(* protocol handler functions *)
TYPE BSProtocolInstall* = PROCEDURE{C}(VAR Handle : Handle; CONST Protocol : GUID; InterfaceType : Int; Interface : Protocol) : Status;
TYPE BSProtocolReinstall* = PROCEDURE{C}(Handle : Handle; CONST Protocol : GUID; OldInterface, NewInterface : Protocol) : Status;
TYPE BSProtocolUninstall* = PROCEDURE{C}(Handle : Handle; CONST Protocol : GUID; Interface : Protocol) : Status;
TYPE BSProtocolHandle* = PROCEDURE{C}(Handle : Handle; CONST Protocol : GUID; VAR Interface : Protocol) : Status;
TYPE BSProtocolRegisterNotify* = PROCEDURE{C}(CONST Protocol : GUID; Event : Event; VAR Registration : Pointer) : Status;
TYPE BSLocateHandle* = PROCEDURE{C}(SearchType : Int; CONST Protocol : GUID; SearchKey : Pointer; VAR BufferSize : Int; VAR Buffer : ARRAY OF Handle): Status;
TYPE BSLocateDevicePath* = PROCEDURE{C}(CONST Protocol : GUID; VAR DevicePath : DevicePath; VAR Device : Handle) : Status;
TYPE BSInstallConfigurationTable* = PROCEDURE{C}(CONST Protocol : GUID; Table : Pointer) : Status;
(* image functions *)
TYPE BSImageLoad* = PROCEDURE{C}(BootPolicy : Boolean; ParentImageHandle : Handle; CONST FilePath : DevicePath; SourceSize : Int; SourceBuffer : Pointer; VAR ImageHandle : Handle) : Status;
TYPE BSImageStart* = PROCEDURE{C}(ImageHandle : Handle; VAR ExitDataSize : Int; VAR ExitData : ARRAY OF Char16) : Status;
TYPE BSImageExit* = PROCEDURE{C}(ImageHandle : Handle; ExitStatus : Status; ExitDataSize : Int; VAR ExitData : ARRAY OF Char16) : Status;
TYPE BSImageUnload* = PROCEDURE{C}(ImageHandle : Handle) : Status;
TYPE BSExitBootServices* = PROCEDURE{C}(ImageHandle : Handle; MapKey : Int) : Status;
(* misc. functions *)
TYPE BSGetNextMonotonicCount* = PROCEDURE{C}(VAR Count : Int64);
TYPE BSStall* = PROCEDURE{C}(Microseconds : Int);

TYPE BootServices* = RECORD
	Hdr- : TableHeader;
	RaiseTPL-: BSTPLRaise;
	RestoreTPL-: BSTPLRestore;
	(* memory functions *)
	AllocatePages-: BSAllocatePages;
	FreePages-: BSFreePages;
	GetMemoryMap-: BSGetMemoryMap;
	AllocatePool-: BSDummyType;
	FreePool-: BSDummyType;
	(* event & timer functions *)
	CreateEvent-: BSDummyType;
	SetTimer-: BSDummyType;
	WaitForEvent-: BSDummyType;
	SignaleEvent-: BSDummyType;
	CloseEvent-: BSDummyType;
	CheckEvent-: BSDummyType;
	(* protocol handler functions *)
	InstallProtocolInterface-: BSProtocolInstall;
	ReinstallProtocolInterface-: BSProtocolReinstall;
	UninstallProtocolInterface-: BSProtocolUninstall;
	HandleProtocol-: BSProtocolHandle;
	PCHandleProtocol-: BSProtocolHandle;
	RegisterProtocolNotify-: BSProtocolRegisterNotify;
	LocateHandle-: BSLocateHandle;
	LocateDevicePath-: BSLocateDevicePath;
	InstallConfigurationTable-: BSDummyType;
	(* image functions *)
	LoadImage-: BSImageLoad;
	StartImage-: BSImageStart;
	Exit-: BSImageExit;
	UnloadImage-: BSImageUnload;
	ExitBootServices-: BSExitBootServices;
	(* misc *)
	GetNextMonotinicCount-: BSGetNextMonotonicCount;
	Stall-: BSStall;
	SetWatchdogTimer-: BSDummyType;
END;

(* RuntimeService function type declarations *)
TYPE RSDummyType* = PROCEDURE{C};

TYPE RuntimeServices* = RECORD
	Hdr- : TableHeader;
	(* time services *)
	GetTime-: RSDummyType;
	SetTime-: RSDummyType;
	GetWakeupTime-: RSDummyType;
	SetWakeupTime-: RSDummyType;
	(* virtual memory services *)
	SetVirtualAddressMap-: RSDummyType;
	ConvertPointer-: RSDummyType;
	(* varible services *)
	GetVariable-: RSDummyType;
	GetNextVariable-: RSDummyType;
	SetVariable-: RSDummyType;
	(* misc *)
	GetNextHighMonotonicCount-: RSDummyType;
	ResetSystem -: RSDummyType;
END;

TYPE ConfigurationTableEntry* = RECORD
	VendorGuid-: GUID;
	VendorTable-: ADDRESS; (* virtual OR physical address - see EFI spec. Chapter 4.6 *)
END;

(* basic EFI protocols ( = function tables to communicate with EFI services ) *)

(* Simple Input Interface Protocol *)
TYPE InputKey* = RECORD
	ScanCode-: Int16;
	UnicodeChar-: Char16;
END;
TYPE InputReset* = PROCEDURE {C} (This: POINTER TO SimpleInputInterface; ExtendedVerification: Boolean): Status;
TYPE InputReadKey* = PROCEDURE {C} (This: POINTER TO SimpleInputInterface; VAR key: InputKey): Status;

TYPE SimpleInputInterface* = RECORD(ProtocolDescription)
	Reset-: InputReset;
	ReadKey-: InputReadKey;
	WaitForEvent- : Event;
END;

(* Simple Text Output Interface Protocol *)

TYPE SimpleTextOutputInterfaceMode* = RECORD
	MaxMode-: Int32;
	(* current settings: *)
	Mode-: Int32;
	Attribute-: Int32;
	CursorColumn-: Int32;
	CursorRow-: Int32;
	CursorVisible-: Boolean;
END;

TYPE TextReset* = PROCEDURE {C} (This: POINTER TO SimpleTextOutputInterface; ExtendedVerification: Boolean): Status;
TYPE TextString* = PROCEDURE {C} (This: POINTER TO SimpleTextOutputInterface;  CONST String: ARRAY OF Char16): Status;
TYPE TextTestString* = PROCEDURE {C} (This: POINTER TO SimpleTextOutputInterface; CONST String: ARRAY OF Char16): Status;
TYPE TextQueryMode* = PROCEDURE {C} (This: POINTER TO SimpleTextOutputInterface; ModeNumber: Int; VAR Columns, Rows: Int): Status;
TYPE TextSetMode* = PROCEDURE {C} (This: POINTER TO SimpleTextOutputInterface; ModeNumber: Int): Status;
TYPE TextSetAttribute* = PROCEDURE {C} (This: POINTER TO SimpleTextOutputInterface; Attribute: Int): Status;
TYPE TextClearScreen* = PROCEDURE {C} (This: POINTER TO SimpleTextOutputInterface): Status;
TYPE TextSetCursorPos* = PROCEDURE {C} (This: POINTER TO SimpleTextOutputInterface; Column, Row : Int): Status;
TYPE TextEnableCursor* = PROCEDURE {C} (This : POINTER TO SimpleTextOutputInterface; Visible : Boolean): Status;

TYPE SimpleTextOutputInterface* = RECORD(ProtocolDescription)
	Reset-: TextReset;
	OutputString-: TextString;
	TestString-: TextTestString;
	QueryMode-: TextQueryMode;
	SetMode-: TextSetMode;
	SetAttribute-: TextSetAttribute;
	ClearScreen-: TextClearScreen;
	SetCursorPosition-: TextSetAttribute;
	EnableCursor-: TextEnableCursor;
	Mode-{UNTRACED}: POINTER TO SimpleTextOutputInterfaceMode;
END;

VAR
	imageHandle-: Handle;
	table- {UNTRACED}: POINTER TO SystemTable;

END EFI.