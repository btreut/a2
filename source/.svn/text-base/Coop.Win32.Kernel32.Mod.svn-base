(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE Kernel32;   (** AUTHOR "ejz"; PURPOSE "Definition of the Win32 Kernel32 API used by (Win)Aos"; *)

IMPORT SYSTEM;

CONST
	(** NIL pointer/address value *)
	NULL* = 0;

	(** BOOL values *)
	False* = NULL;  True* = 1;


	(** standard handles *)
	InvalidHandleValue* = -1;  STDInput* = -10;  STDOutput* = -11;
	STDError* = -12;

	(** generic access rights *)
	GenericWrite* = 30;  GenericRead* = 31;

	(** file sharing *)
	FileShareRead* = 0;  FileShareWrite* = 1; FileShareDelete*=2;

	(** file creation *)
	CreateAlways* = 2;  OpenExisting* = 3;

	(** file attributes *)
	FileAttributeReadonly* = 0;  FileAttributeHidden* = 1;
	FileAttributeSystem* = 2;  FileAttributeDirectory* = 4;
	FileAttributeArchive* = 5;  FileAttributeEncrypted* = 6;
	FileAttributeNormal* = 7;  FileAttributeTemporary* = 8;
	FileAttributeSparseFILE* = 9;  FileAttributeReparsePoint* = 10;
	FileAttributeCompressed* = 11;  FileAttributeOffline* = 12;
	FileAttributeNotContentIndexed* = 13;

	(** file creation flags *)
	FileFlagDeleteOnClose*=26;
	FileFlagRandomAccess* = 28;
	FileFlagWriteThrough*= 31;

	(** move method *)
	FileBegin* = 0;

	(** move file flags *)
	MoveFileReplaceExisting* = 0;  MoveFileCopyAllowed* = 1;  MoveFileWriteThrough*= 3;
	(* (* reason for call values *)
		DLLProcessDetach = 0; DLLProcessAttach = 1; *)

	(** allocation/free type *)
	MEMCommit* = 12;  MEMReserve* = 13;  MEMDecommit* = 14;
	MEMRelease* = 15;  CreateSuspended* = 2;  TLSOutOfIndexes* = -1;

	(** heap allocation options *)
	HeapNoSerialize* = 2H;
	HeapGenerateExceptions* = 4H;
	HeapZeroMemory* = 8H;
	
	(** protect (VirtualAlloc) flags *)
	PageReadWrite* = 2;  PageExecuteReadWrite* = 6;

	(** global memory flags *)
	GMemMoveable* = 1;  GMemShare* = 13;
	GMemDDEShare* = GMemShare;

	(** maximum length of full path *)
	MaxPath* = 260;

	(** specifies the type of a drive *)
	DriveUnknown* = 0;  DriveNoRootDir* = 1;  DriveRemovable* = 2;
	DriveFixed* = 3;  DriveRemote* = 4;  DriveCDRom* = 5;
	DriveRamDisk* = 6;  Infinite* = -1;  WaitObject0* = 0;

	(** thread context and exception information *)

	SizeOf80387Registers* = 80;  ExceptionMaximumParameters* = 15;

	ExceptionGuardPage* = LONGINT(080000001H);
	ExceptionBreakPoint* = LONGINT(080000003H);
	ExceptionSingleStep* = LONGINT(080000004H);
	ExceptionAccessViolation* = LONGINT(0C0000005H);
	ExceptionIllegalInstruction* = LONGINT(0C000001DH);
	ExceptionArrayBoundsExceeded* = LONGINT(0C000008CH);
	ExceptionFltDenormalOperand* = LONGINT(0C000008DH);
	ExceptionFltDivideByZero* = LONGINT(0C000008EH);
	ExceptionFltInexactResult* = LONGINT(0C000008FH);
	ExceptionFltInvalidOperation* = LONGINT(0C0000090H);
	ExceptionFltOverflow* = LONGINT(0C0000091H);
	ExceptionFltStackCheck* = LONGINT(0C0000092H);
	ExceptionFltUndeflow* = LONGINT(0C0000093H);
	ExceptionIntDivideByZero* = LONGINT(0C0000094H);
	ExceptionIntOverflow* =LONGINT(0C0000095H);
	ExceptionPrivInstruction* = LONGINT(0C0000096H);
	ExceptionStackOverflow* = LONGINT(0C00000FDH);

	ContextIntel = 16;
	ContextControl* = {0, ContextIntel};   (* SS:SP, CS:IP, FLAGS, BP *)
	ContextInteger* = {1, ContextIntel};   (* AX, BX, CX, DX, SI, DI *)
	ContextSegments* = {2, ContextIntel};   (* DS, ES, FS, GS *)
	ContextFloatingPoint* = {3, ContextIntel};   (* 387 state *)
	ContextDebugRegisters* = {4, ContextIntel};   (* DB 0-3,6,7 *)
	ContextFull* = ContextControl + ContextInteger + ContextSegments;

	(** exception frame handler return values *)
	ExceptionContinueExecution* = -1;  ExceptionContinueSearch* = 0;
	ExceptionExecuteHandler* = 1;

	(** thread priorities *)
	ThreadPriorityIdle* = -15;  ThreadPriorityBelowNormal* = -1;
	ThreadPriorityNormal* = 0;  ThreadPriorityAboveNormal* = 1; ThreadPriorityHighest* = 2;
	ThreadPriorityTimeCritical* = 15;  ThreadPriorityErrorReturn* = MAX( LONGINT );


	(** WaitForSingleObject return values *)
	WaitFailed* = -1;
	WaitTimeout* = 0102H;

	(** SetErrorMode *)
	SEMFailCriticalErrors* = 0;

	(** DuplicateHandle *)
	DuplicateCloseSource* = 0;  DuplicateSameAccess* = 1;

	(** StartupInfo flags *)
	StartFUseShowWindow* = 0;  StartFUseSize* = 1;  StartFUsePosition* = 2;

	(** OSVersionInfo dwPlatformId values *)
	VerPlatformWin32s* = 0;  VerPlatformWin32Windows* = 1;
	VerPlatformWin32NT* = 2;

	(** EscapeCommFunction *)
	SETXOFF* = 1;  SETXON* = 2;  SETRTS* = 3;  CLRRTS* = 4;  SETDTR* = 5;
	CLRDTR* = 6;  RESETDEV* = 7;  SETBREAK* = 8;  CLRBREAK* = 9;

	(** PurgeComm *)
	PurgeTXAbort* = 0;  PurgeRXAbort* = 1;  PurgeTXClear* = 2;
	PurgeRXClear* = 3;

	(** SetCommMask *)
	EVRXChar* = 0;  EVRXFlag* = 1;  EVTXEmpty* = 2;  EVCTS* = 3;
	EVDSR* = 4;  EVRLSD* = 5;  EVBreak* = 6;  EVErr* = 7;  EVRing* = 8;
	EVPErr* = 9;  EVRX80Full* = 10;  EVEvent1* = 11;  EVEvent2* = 12;

	(** GetCommModemStatus *)
	MSCTSOn* = 4;  MSDSROn* = 5;  MSRingOn* = 6;  MSRLSDOn* = 7;
	(** DCB *)
	NoParity* = 0X;  OddParity* = 1X;  EvenParity* = 2X;  MarkParity* = 3X;
	SpaceParity* = 4X;  OneStopBit* = 0X;  One5StopBits* = 1X;
	TwoStopBits* = 2X;

	(** GetLastError *)
	ErrorSuccess* = 0;  ErrorFileNotFound* = 2;  ErrorAccessDenied* = 5;
	ErrorInvalidParameter* = 87;

TYPE
	(* OutputStringProc* = PROCEDURE (VAR str: ARRAY OF CHAR); *)

	BOOL* = LONGINT;

	HANDLE* = ADDRESS;  HMODULE* = ADDRESS;
	HINSTANCE* = ADDRESS;  ATOM* = INTEGER;  HGLOBAL* = HANDLE;
	LPSTR* = ADDRESS;

	(** The FILETIME structure is a 64-bit value representing the number of 100-nanosecond intervals since January 1, 1601. *)
	FileTime* = RECORD
		dwLowDateTime*, dwHighDateTime*: LONGINT
	END;

	(** The FindData structure describes a file found by the FindFirstFile or FindNextFile function. *)
	FindData* = RECORD
		dwFileAttributes*: SET;
		ftCreationTime*, ftLastAccessTime*, ftLastWriteTime*: FileTime;
		nFileSizeHigh*, nFileSizeLow*: LONGINT;
		dwReserved0*, dwReserved1*: LONGINT;
		cFileName*: ARRAY MaxPath OF CHAR;
		cAlternateFileName*: ARRAY 14 OF CHAR
	END;

	(** The SYSTEMTIME structure represents a date and time using individual members for the month, day, year, weekday,
			hour, minute, second, and millisecond. *)
	SystemTime* = RECORD
		wYear*, wMonth*, wDayOfWeek*, wDay*: INTEGER;
		wHour*, wMinute*, wSecond*, wMilliseconds*: INTEGER
	END;

	(** The SMALL_RECT structure defines the coordinates of the upper left and lower right corners of a rectangle. *)
	SmallRect* = RECORD
		left*, top*, right*, bottom*: INTEGER
	END;


	(** Critical-section object. *)
	CriticalSection* = RECORD
		a, b, c, d, e, f: LONGINT
	END;

	(** thread context and exception information *)

	FloatingSaveArea* = RECORD
		ControlWord*, StatusWord*, TagWord*, ErrorOffset*, ErrorSelector*, DataOffset*, DataSelector*: LONGINT;
		RegisterArea*: ARRAY SizeOf80387Registers OF SYSTEM.BYTE;
		Cr0NpxState*: LONGINT
	END;

	Context* = RECORD
		ContextFlags*: SET;
		DR0*, DR1*, DR2*, DR3*, DR6*, DR7*: LONGINT;
		FloatSave*: FloatingSaveArea;
		GS*, FS*, ES*, DS*: LONGINT;
		EDI*, ESI*, EBX*, EDX*, ECX*, EAX*: OBJECT;
		BP*, PC*, CS*, FLAGS*, SP*, SS*: LONGINT; (* whereas BP is EBP and SP is ESP *)
	END;

	ExceptionRecordPtr* = POINTER TO ExceptionRecord;
	ExceptionRecord* = RECORD
		ExceptionCode*, ExceptionFlags*: LONGINT;
		nextExceptionRecord*: ExceptionRecordPtr;
		ExceptionAddress*: ADDRESS;
		NumberParameters*: LONGINT;
		ExceptionInformation*: ARRAY ExceptionMaximumParameters OF LONGINT
	END;

	ExcpFrmPtr* = ADDRESS;
	ExcpFrmHandler* = PROCEDURE {WINAPI} ( VAR excpRec: ExceptionRecord;
																														   excpFrame: ExcpFrmPtr;
																														   VAR context: Context;
																														   dispatch: LONGINT ): LONGINT;
	ExcpFrm* = RECORD
		link*: ExcpFrmPtr;
		handler*: ExcpFrmHandler
	END;

	(** Synchronization Objects *)
	Object* = POINTER TO RECORD
		handle*: HANDLE
	END;

	(** A 64-bit signed integer value. *)
	LargeInteger* = RECORD
		LowPart*, HighPart*: LONGINT
	END;

	(** A 64-bit unsigned integer value. *)
	ULargeInteger* = LargeInteger;

	(* Added by Alexey *)
	MemoryStatusEx* = RECORD
		  dwLength*: LONGINT;
		  dwMemoryLoad*: LONGINT;

		  ullTotalPhys*: HUGEINT;
		  ullAvailPhys*: HUGEINT;
		  ullTotalPageFile*: HUGEINT;
		  ullAvailPageFile*: HUGEINT;
		  ullTotalVirtual*: HUGEINT;
		  ullAvailVirtual*: HUGEINT;
		  ullAvailExtendedVirtual*: HUGEINT;
	END;

	(** CreateThread *)
	ThreadProc* = PROCEDURE {WINAPI} ( lpParameter {UNTRACED}: ANY ): LONGINT;

	(** CreateProcess *)
	ProcessInformation* = RECORD
		hProcess*, hThread*: HANDLE;
		dwProcessId*, dwThreadId*: LONGINT
	END;

	(** CreateProcess, GetStartupInfo *)
	StartupInfo* = RECORD
		cb*: LONGINT;
		lpReserved*, lpDesktop*, lpTitle*: LPSTR;
		dwX*, dwY*, dwXSize*, dwYSize*: LONGINT;
		dwXCountChars*, dwYCountChars*: LONGINT;
		dwFillAttribute*: LONGINT;
		dwFlags*: SET;
		wShowWindow*, cbReserved2*: INTEGER;
		lpReserved2*: ADDRESS;
		hStdInput*, hStdOutput*, hStdError*: HANDLE
	END;

	(** The OSVersionInfo data structure contains operating system version information. *)
	OSVersionInfo* = RECORD
		dwOSVersionInfoSize*, dwMajorVersion*, dwMinorVersion*, dwBuildNumber*, dwPlatformId*: LONGINT;
		szCSDVersion*: ARRAY 128 OF CHAR
	END;

	Exception* = RECORD
		exc*: ExceptionRecord;
		cont*: Context
	END;

	CommTimeouts* = RECORD
		ReadIntervalTimeout*, ReadTotalTimeoutMultiplier*, ReadTotalTimeoutConstant*, WriteTotalTimeoutMultiplier*, WriteTotalTimeoutConstant*: LONGINT
	END;

	DCB* = RECORD
		DCBlength*, BaudRate*: LONGINT;
		flags*: SET;
		wReserved*, XonLim*, XoffLim*: INTEGER;
		ByteSize*, Parity*, StopBits*, XonChar*, XoffChar*, ErrorChar*, EofChar*, EvtChar*: CHAR;
		wReserved1*: INTEGER
	END;

	ComStat* = RECORD
		status*: SET;
		cbInQue*, cbOutQue*: LONGINT
	END;

	SystemInfo* = RECORD
		wProcessorArchitecture*: INTEGER;
		wReserved: INTEGER;
		dwPageSize*: LONGINT;
		lpMinimumApplicationAddress*: LONGINT;
		lpMaximumApplicationAddress*: LONGINT;
		dwActiveProcessorMask*: LONGINT;
		dwNumberOfProcessors*: LONGINT;
		dwProcessorType*: LONGINT;
		dwAllocationGranularity*: LONGINT;
		wProcessorLevel*: INTEGER;
		wProcessorRevision*: INTEGER;
	END;

	(*ALEX 2005.10.18 The TIME_ZONE_INFORMATION as defined in winbase.h*)
	TimeZoneInformation* = RECORD
		Bias*: LONGINT;
		StandardName*: ARRAY 32 OF INTEGER;
		StandardDate*: SystemTime;
		StandardBias*: LONGINT;
		DaylightName*: ARRAY 32 OF INTEGER;
		DaylightDate*: SystemTime;
		DaylightBias*: LONGINT;
	END;

VAR
	(* the procedure variables getProcAddress and LoadLibrary  must be patched by linker / PE loader *)
	(** The GetProcAddress function returns the address of the specified exported dynamic-link library (DLL) function.
			Use the GetProcAddress Oberon wrapper. *)
	getProcAddress-: PROCEDURE {WINAPI} ( hModule: HMODULE;  CONST  lpProcName: ARRAY   OF CHAR ): ADDRESS;
	(** The LoadLibrary function maps the specified executable module into the address space of the calling process. *)
	LoadLibrary-: PROCEDURE {WINAPI} ( CONST lpLibFileName: ARRAY   OF CHAR ): HINSTANCE;   (* must be patched by linker / PE loader *)


	(** The AllocConsole function allocates a new console for the calling process. *)
	AllocConsole-: PROCEDURE {WINAPI} ( ): BOOL;
	(**The Beep function generates simple tones on the speaker. The function is synchronous; it does not return control to its caller until the sound finishes.*)
	Beep-: PROCEDURE {WINAPI} ( dwFreq, dwDuration: LONGINT ): BOOL;
	(** The ClearCommBreak function restores character transmission for a specified communications device and places the transmission line in a nonbreak state. *)
	ClearCommBreak-: PROCEDURE {WINAPI} ( hFile: HANDLE ): BOOL;
	(** The ClearCommError function retrieves information about a communications error and reports the current status of a communications device. *)
	ClearCommError-: PROCEDURE {WINAPI} ( hFile: HANDLE;  VAR lpErrors: SET;  VAR lpStat: ComStat ): BOOL;
	(** The CloseHandle function closes an open object handle. *)
	CloseHandle-: PROCEDURE {WINAPI} ( hObject: HANDLE ): BOOL;
	(** The CopyFile function copies an existing file to a new file. *)
	CopyFile-: PROCEDURE {WINAPI} ( VAR lpExistingFileName, lpNewFileName: ARRAY  OF CHAR; bFailIfExists: BOOL ): BOOL;
	(** The CreateDirectory function creates a new directory. *)
	CreateDirectory-: PROCEDURE {WINAPI} ( VAR lpPathName: ARRAY   OF CHAR;
																		 lpSecurityAttributes {UNTRACED}: ANY ): BOOL;
	(** The CreateEvent function creates a named or unnamed event object. *)
	CreateEvent-: PROCEDURE {WINAPI} ( lpEventAttributes {UNTRACED}: ANY;
																   bManualReset, bInitialState: BOOL;
																   CONST lpName: ARRAY   OF CHAR ): HANDLE;
	(** The CreateFile function creates or opens the following objects and returns a handle that can be used to access the object:
		 files, pipes, mailslots, communications resources, disk devices (Windows NT only), consoles, directories (open only) *)
	CreateFile-: PROCEDURE {WINAPI} ( CONST lpFileName: ARRAY   OF CHAR;
																dwDesiredAccess, dwShareMode: SET;
																lpSecurityAttributes {UNTRACED}: ANY;
																dwCreationDistribution: LONGINT;
																dwFlagsAndAttributes: SET;
																hTemplateFile: HANDLE ): HANDLE;
	(** The CreateProcess function creates a new process and its primary thread. The new process executes the specified
			executable file. *)
	CreateProcess-: PROCEDURE {WINAPI} ( CONST lpApplicationName, lpCommandLine: ARRAY   OF CHAR;
																	   lpProcessAttributes, lpThreadAttributes {UNTRACED}: ANY;
																	   bInheritHandles: BOOL;
																	   dwCreationFlags: LONGINT;
																	   lpEnvironment {UNTRACED}: ANY;
																	   VAR lpCurrentDirectory: ARRAY   OF CHAR;
																	   VAR lpStartupInfo: StartupInfo;
																	   VAR lpProcessInformation: ProcessInformation ): BOOL;
	(** The CreateSemaphore function creates or opens a named or unnamed semaphore object. *)
	CreateSemaphore-: PROCEDURE {WINAPI} ( lpThreadAttributes: ADDRESS; lInitialCount: LONGINT; lMaximumCount: LONGINT; lpName: LPSTR): HANDLE;
	(** The CreateThread function creates a thread to execute within the address space of the calling process. *)
	CreateThread-: PROCEDURE {WINAPI} ( lpThreadAttributes: ADDRESS;
																	  dwStackSize: LONGINT;
																	  lpStartAddress: ThreadProc;
																	  lpParameter {UNTRACED}: ANY;  dwCreationFlags: SET;
																	  VAR lpThreadId: LONGINT ): HANDLE;
	(** The DeleteCriticalSection function releases all resources used by an unowned critical section object. *)
	DeleteCriticalSection-: PROCEDURE {WINAPI} ( VAR lpCriticalSection: CriticalSection );
	(** The DeleteFile function deletes an existing file. *)
	DeleteFile-: PROCEDURE {WINAPI} ( VAR lpFileName: ARRAY   OF CHAR ): BOOL;
	(** The DisableThreadLibraryCalls function disables the DLL_THREAD_ATTACH and DLL_THREAD_DETACH notifications
			for the dynamic-link library (DLL) specified by hLibModule. *)
	DisableThreadLibraryCalls-: PROCEDURE {WINAPI} ( hLibModule: HMODULE ): BOOL;
	(** The DuplicateHandle function duplicates an object handle. *)
	DuplicateHandle-: PROCEDURE {WINAPI} ( hSourceProcessHandle, hSourceHandle, hTargetProcessHandle: HANDLE;
																			 VAR lpTargetHandle: HANDLE;
																			 dwDesiredAccess: SET;
																			 bInheritHandle: BOOL;
																			 dwOptions: SET ): BOOL;
	(** The EnterCriticalSection function waits for ownership of the specified critical section object. *)
	EnterCriticalSection-: PROCEDURE {WINAPI} ( VAR lpCriticalSection: CriticalSection );
	(** The EscapeCommFunction function directs a specified communications device to perform an extended function. *)
	EscapeCommFunction-: PROCEDURE {WINAPI} ( hFile: HANDLE;
																					  dwFunc: LONGINT ): BOOL;
	(** The ExitProcess function ends a process and all its threads. *)
	ExitProcess-: PROCEDURE {WINAPI} ( uExitCode: LONGINT );
	(** The ExitThread function ends a thread. *)
	ExitThread-: PROCEDURE {WINAPI} ( dwExitCode: LONGINT );
	(** The FileTimeToLocalFileTime function converts a file time based on the Coordinated Universal Time (UTC) to a
			local file time. *)
	FileTimeToLocalFileTime-: PROCEDURE {WINAPI} ( VAR lpFileTime: FileTime;
																						   VAR lpLocalFileTime: FileTime ): BOOL;
	(** The FileTimeToSystemTime function converts a 64-bit file time to system time format. *)
	FileTimeToSystemTime-: PROCEDURE {WINAPI} ( VAR lpFileTime: FileTime;
																					   VAR lpSystemTime: SystemTime ): BOOL;
	(** The FindClose function closes the specified search handle. *)
	FindClose-: PROCEDURE {WINAPI} ( hFindFile: HANDLE ): BOOL;
	(** The FindFirstFile function searches a directory for a file whose name matches the specified filename. *)
	FindFirstFile-: PROCEDURE {WINAPI} ( VAR lpFileName: ARRAY   OF CHAR;
																	 VAR lpFindFileDate: FindData ): HANDLE;
	(** The FindNextFile function continues a file search from a previous call to the FindFirstFile function. *)
	FindNextFile-: PROCEDURE {WINAPI} ( hFindFile: HANDLE;
																	  VAR lpFindFileDate: FindData ): BOOL;
	(** The FlushFileBuffers function clears the buffers for the specified file and causes all buffered data to be written
			to the file. *)
	FlushFileBuffers-: PROCEDURE {WINAPI} ( hFile: HANDLE ): BOOL;
	(** The FreeConsole function detaches the calling process from its console *)
	FreeConsole-: PROCEDURE {WINAPI} ( ): BOOL;
	(** The FreeLibrary function decrements the reference count of the loaded dynamic-link library (DLL) module.
			When the reference count reaches zero, the module is unmapped from the address space of the calling process
			and the handle is no longer valid. *)
	FreeLibrary-: PROCEDURE {WINAPI} ( hLibModule: HMODULE ): BOOL;
	(** The GetCommandLine function returns a pointer to the command-line string for the current process. *)
	GetCommandLine-: PROCEDURE {WINAPI} ( ): LPSTR;
	(** The GetCommModemStatus function retrieves modem control-register values. *)
	GetCommModemStatus-: PROCEDURE {WINAPI} ( hFile: HANDLE;
																						VAR lpModemStat: SET ): BOOL;
	(** The GetCommState function retrieves the current control settings for a specified communications device. *)
	GetCommState-: PROCEDURE {WINAPI} ( hFile: HANDLE;
																		 VAR lpDCB: DCB ): BOOL;
	(** The GetComputerName function retrieves the NetBIOS name of the local computer. *)
	GetComputerName-: PROCEDURE {WINAPI} ( VAR lpBuffer: ARRAY   OF CHAR;
																			    VAR lpnSize: LONGINT ): BOOL;
	(** The GetCurrentDirectory function retrieves the current directory for the current process. *)
	GetCurrentDirectory-: PROCEDURE {WINAPI} ( nBufferLength: LONGINT;
																				 VAR lpBuffer: ARRAY   OF CHAR ): LONGINT;
	(** The GetConsoleWindow function retrieves the window handle used by the console associated with the calling process. *)
	(*
	GetConsoleWindow-: PROCEDURE{WINAPI} (): LONGINT ;
	(** The GetCurrentProcess function returns a pseudohandle for the current process. *)
	not in smaller versions than Win2000!
	*)
	GetCurrentProcess-: PROCEDURE {WINAPI} ( ): HANDLE;
	(** The GetCurrentProcessId function returns the process identifier of the calling process. *)
	GetCurrentProcessId-: PROCEDURE {WINAPI} ( ): LONGINT;
	(** The GetCurrentThread function returns a pseudohandle for the current thread. *)
	GetCurrentThread-: PROCEDURE {WINAPI} ( ): HANDLE;
	(** The GetCurrentThreadId function returns the thread identifier of the calling thread. *)
	GetCurrentThreadId-: PROCEDURE {WINAPI} ( ): LONGINT;
	(** The GetDiskFreeSpace function retrieves information about the specified disk, including the amount of
			free space on the disk. *)
	GetDiskFreeSpace-: PROCEDURE {WINAPI} ( VAR lpRootPathName: ARRAY   OF CHAR;
																			  VAR lpSectorsPerCluster, lpBytesPerSector, lpNumberOfFreeClusters, lpTotalNumberOfClusters: LONGINT ): BOOL;
	(** The GetDriveType function determines whether a disk drive is a removable, fixed, CD-ROM, RAM disk, or
			network drive. *)
	GetDriveType-: PROCEDURE {WINAPI} ( VAR lpRootPathName: ARRAY   OF CHAR ): LONGINT;
	(** The GetExitCodeProcess function retrieves the termination status of the specified process. *)
	GetExitCodeProcess-: PROCEDURE {WINAPI} ( hProcess: HANDLE;
																				  VAR lpExitCode: LONGINT ): BOOL;
	(** The GetFileAttributes function returns attributes for a specified file or directory. *)
	GetFileAttributes-: PROCEDURE {WINAPI} ( VAR lpFileName: ARRAY   OF CHAR ): SET;
	(** The GetFileSize function retrieves the size, in bytes, of the specified file. *)
	GetFileSize-: PROCEDURE {WINAPI} ( hFile: HANDLE;  VAR lpFileSizeHigh: LONGINT ): LONGINT;
	(** The GetFileTime function retrieves the date and time that a file was created, last accessed, and last modified. *)
	GetFileTime-: PROCEDURE {WINAPI} ( hFile: HANDLE;
																	VAR lpCreationTime, lpLastAccessTime, lpLastWriteTime: FileTime ): BOOL;
	(** The GetFullPathName function retrieves the full path and filename of a specified file. *)
	GetFullPathName-: PROCEDURE {WINAPI} ( CONST lpFileName: ARRAY   OF CHAR;
																			  nBufferLength: LONGINT;
																			  VAR lpBuffer: ARRAY   OF CHAR;
																			  lpFilePart: LPSTR ): LONGINT;
	(** The GetLastError function returns the calling thread's last-error code value. *)
	GetLastError-: PROCEDURE {WINAPI} ( ): LONGINT;
	(** The GetLocalTime function retrieves the current local date and time. *)
	GetLocalTime-: PROCEDURE {WINAPI} ( VAR lpSystemTime: SystemTime );
	(** The GetLogicalDriveStrings function retrieves a string containing the drive letters. *)  (*ALEX 2005.02.10*)
	GetLogicalDriveStrings-: PROCEDURE {WINAPI} ( nBufferLength: LONGINT;
																					   VAR lpBuffer: ARRAY   OF CHAR ): LONGINT;
	(** The GetModuleFileName function retrieves the full path and filename for the executable file containing the
			specified module. *)
	(* The GetLogicalDrives function retrieves a bitmask representing the currently available disk drives.
*)

	GetLogicalDrives-: PROCEDURE {WINAPI} ( ): SET;
	GetModuleFileName-: PROCEDURE {WINAPI} ( hModule: HMODULE;
																				    VAR lpFileName: ARRAY   OF CHAR;
																				    nSize: LONGINT ): LONGINT;
	(** The GetModuleHandle function returns a module handle for the specified module if the file has been mapped
			into the address space of the calling process. *)
	GetModuleHandle-: PROCEDURE {WINAPI} ( CONST lpModuleName: ARRAY   OF CHAR ): HMODULE;
	(** The GetPrivateProfileString function retrieves a string from the specified section in an initialization file.*)
	GetPrivateProfileString-: PROCEDURE {WINAPI} ( CONST lpAppName: ARRAY OF CHAR;
																			CONST lpKeyName: ARRAY OF CHAR;
																			CONST lpDefault: ARRAY OF CHAR;
																			CONST lpReturnedString: ARRAY OF CHAR;
																			nSize: LONGINT;
																			CONST lpFileName: ARRAY OF CHAR): LONGINT;
	(** The GetProcessAffinityMask function retrieves the process affinity mask for the specified process and the system affinity mask for the system. *)
	GetProcessAffinityMask- : PROCEDURE {WINAPI} ( hProcess: HANDLE; lpProcessAffinityMask: ADDRESS;  lpSystemAffinityMask: ADDRESS ): BOOL;
	(** The GetProcessHeap function retrieves a handle to the default heap of the calling process. This handle can then be used in subsequent calls to the heap functions. *)
	GetProcessHeap- : PROCEDURE {WINAPI} (): HANDLE;
	(** The GetProcessTimes function returns the times spent in kernel mode, user mode ... for the specified process *)
	GetProcessTimes- : PROCEDURE {WINAPI} (CONST hProcess: HANDLE; VAR lpCreationTime, lpExitTime, lpKernelTime, lpUserTime: FileTime ): LONGINT;
	(** The GetStartupInfo function retrieves the contents of the StartupInfo structure that was specified when
			the calling process was created. *)
	GetStartupInfo-: PROCEDURE {WINAPI} ( VAR lpStartupInfo: StartupInfo );
	(** Retrieves information about the current system. *)
	GetSystemInfo-: PROCEDURE {WINAPI} ( VAR lpSystemInfo: SystemInfo );
	(** The GetStdHandle function returns a handle for the standard input, standard output, or standard error device. *)
	GetStdHandle-: PROCEDURE {WINAPI} ( nStdHandle: LONGINT ): HANDLE;
	(** The GetSystemTime function retrieves the current system date and time. The system time is expressed in
			Coordinated Universal Time (UTC). *)
	GetSystemTime-: PROCEDURE {WINAPI} ( VAR lpSystemTime: SystemTime );
	(** The GetTempFileName function creates a name for a temporary file. The filename is the concatenation of
			specified path and prefix strings, a hexadecimal string formed from a specified integer, and the .TMP extension. *)
	GetTempFileName-: PROCEDURE {WINAPI} ( VAR lpPathName, lpPrefixName: ARRAY   OF CHAR;
																			   uUnique: LONGINT;
																			   VAR lpTempFileName: ARRAY   OF CHAR ): LONGINT;
	(** The GetTempPath function retrieves the path of the directory designated for temporary files. *)
	GetTempPath-: PROCEDURE {WINAPI} ( nBufferLength: LONGINT;
																	   VAR lpBuffer: ARRAY   OF CHAR ): LONGINT;
	(** The GetThreadContext function retrieves the context of the specified thread. *)
	GetThreadContext-: PROCEDURE {WINAPI} ( hThread: HANDLE;
																			  VAR lpContext: Context ): BOOL;
	(** The GetThreadPriority function returns the priority value for the specified thread. This value, together with
			the priority class of the thread's process, determines the thread's base-priority level. *)
	GetThreadPriority-: PROCEDURE {WINAPI} ( hThread: HANDLE ): LONGINT;
	(** The GetThreadTimes function returns the times spent in kernel mode, user mode ... specified thread.  *)
	GetThreadTimes-: PROCEDURE {WINAPI} ( hThread: HANDLE;
																		   VAR lpCreationTime, lpExitTime, lpKernelTime, lpUserTime: FileTime ): LONGINT;   (*ALEX 2005.12.12*)
	 (** The GetTickCount function retrieves the number of milliseconds that have elapsed since the system was started. *)
	GetTickCount-: PROCEDURE {WINAPI} ( ): LONGINT;
	(** The GetTimeZoneInformation function retrieves information about timezone setup. *)  (*ALEX 2005.10.18*)
	GetTimeZoneInformation-: PROCEDURE {WINAPI} ( VAR lpTimeZoneInformation: TimeZoneInformation ): LONGINT;
	(** The GetWindowsDir function retrieves the path of the Windows directory. *) (*ALEX 2006.06.05*)
	GetWindowsDirectory-: PROCEDURE {WINAPI} (  VAR lpBuffer: ARRAY   OF CHAR; nBufferLength: LONGINT ): LONGINT;
	(** The GetVersion function returns the current version number of the operating system. *)
	GetVersion-: PROCEDURE {WINAPI} ( ): LONGINT;
	(** The GetVersionEx function obtains extended information about the version of the operating system that is
			currently running. *)
	GetVersionEx-: PROCEDURE {WINAPI} ( VAR lpVersionInfo: OSVersionInfo ): BOOL;
	(*The GetVolumeInformation function retrieves information about a file system and volume that have a specified
	root directory. *)

	GetVolumeInformation-: PROCEDURE {WINAPI} ( VAR lpRootPathName: ARRAY   OF CHAR;
																					    VAR lpVolumeNameBuffer: ARRAY   OF CHAR;
																					    nVolumeNameSize: LONGINT;
																					    VAR lpVolumeSerialNumber: LONGINT;
																					    VAR lpMaximumComponentLength: LONGINT;
																					    VAR lpFileSystemFlags: LONGINT;
																					    VAR lpFileSystemNameBuffer: ARRAY   OF CHAR;
																					    nFileSystemNameSize: LONGINT ): LONGINT;

	(** The GlobalAddAtom function adds a character string to the global atom table and returns a unique value
			(an atom) identifying the string. *)
	GlobalAddAtom-: PROCEDURE {WINAPI} ( VAR lpString: ARRAY   OF CHAR ): ATOM;
	(** The GlobalAlloc function allocates the specified number of bytes from the heap. *)
	GlobalAlloc-: PROCEDURE {WINAPI} ( uFlags: SET;  dwBytes: LONGINT ): HGLOBAL;
	(** The GlobalDeleteAtom function decrements the reference count of a global string atom. *)
	GlobalDeleteAtom-: PROCEDURE {WINAPI} ( nAtom: ATOM ): ATOM;
	(** The GlobalLock function locks a global memory object and returns a pointer to the first byte of the
			object's memory block. *)
	GlobalLock-: PROCEDURE {WINAPI} ( hMem: HGLOBAL ): ADDRESS;

	(* Added by Alexey *)
	GlobalMemoryStatusEx-: PROCEDURE {WINAPI} (VAR lpBuffer: MemoryStatusEx): BOOL;

	(** The GlobalReAlloc function changes the size or attributes of a specified global memory object. *)
	GlobalReAlloc-: PROCEDURE {WINAPI} ( hMem: HGLOBAL;  dwBytes: LONGINT;
																		uFlags: SET ): HGLOBAL;
	(** The GlobalSize function retrieves the current size, in bytes, of the specified global memory object. *)
	GlobalSize-: PROCEDURE {WINAPI} ( hMem: HGLOBAL ): LONGINT;
	(** The GlobalUnlock function decrements the lock count associated with a memory object that was allocated with
			the GMEM_MOVEABLE flag. *)
	GlobalUnlock-: PROCEDURE {WINAPI} ( hMem: HGLOBAL ): BOOL;
	(** The HeapAlloc function allocates a block of memory from a heap. The allocated memory is not movable. *)
	HeapAlloc-: PROCEDURE {WINAPI} ( hHeap: HANDLE; dwFlags: LONGINT; size: SIZE): ADDRESS;
	(** The HeapFree function frees a memory block allocated from a heap by the HeapAlloc or HeapReAlloc function. *)
	HeapFree-: PROCEDURE {WINAPI} ( hHeap: HANDLE; dwFlags: LONGINT; lpMem: ADDRESS): ADDRESS;
	(** The InitializeCriticalSection function initializes a critical section object. *)
	InitializeCriticalSection-: PROCEDURE {WINAPI} ( VAR lpCriticalSection: CriticalSection );
	(** The InterlockedDecrement function both decrements (decreases by one) the value of the specified 32-bit
			variable and checks the resulting value. *)
	InterlockedDecrement-: PROCEDURE {WINAPI} ( VAR lpAddend: LONGINT ): LONGINT;
	(** The InterlockedIncrement function both increments (increases by one) the value of the specified 32-bit variable
			and checks the resulting value. *)
	InterlockedIncrement-: PROCEDURE {WINAPI} ( VAR lpAddend: LONGINT ): LONGINT;
	(** The LeaveCriticalSection function releases ownership of the specified critical section object. *)
	LeaveCriticalSection-: PROCEDURE {WINAPI} ( VAR lpCriticalSection: CriticalSection );
	(** The LocalFileTimeToFileTime function converts a local file time to a file time based on the Coordinated
			Universal Time (UTC). *)
	LocalFileTimeToFileTime-: PROCEDURE {WINAPI} ( VAR lpLocalFileTime: FileTime;
																						   VAR lpFileTime: FileTime ): BOOL;
	(** The MoveFileEx function renames an existing file or directory. *)
	MoveFileEx-: PROCEDURE {WINAPI} ( VAR lpExistingFileName, lpNewFileName: ARRAY   OF CHAR;
																    dwFlags: SET ): BOOL;
	(** The OutputDebugString function sends a string to the debugger for the current application. *)
	outputDebugString-: PROCEDURE {WINAPI} ( CONST lpOutputString: ARRAY   OF CHAR );

	(* The IsDebuggerPresent Function determines whether the calling process is being debugged by a user-mode debugger. *)

	IsDebuggerPresent-: PROCEDURE {WINAPI}(): BOOL;


	(** The PurgeComm function discards all characters from the output or input buffer of a specified communications resource. *)
	PurgeComm-: PROCEDURE {WINAPI} ( hFile: HANDLE;  dwFlags: SET ): BOOL;
	(** The QueryDosDevice function retrieves information about MS-DOS device names. *)
	QueryDosDevice-: PROCEDURE {WINAPI} ( lpDeviceName: ARRAY   OF CHAR;
																		   VAR lpTargetPath: ARRAY   OF CHAR;
																		   ucchMax: LONGINT ): LONGINT;
	(** The QueryPerformanceCounter function retrieves the current value of the high-resolution
	performance counter, if one exists. *)
	QueryPerformanceCounter-: PROCEDURE {WINAPI} ( VAR lpPerformaceCount: LargeInteger ): BOOL;
	(** The QueryPerformanceFrequency function retrieves the frequency of the high-resolution
			performance counter, if one exists. *)
	QueryPerformanceFrequency-: PROCEDURE {WINAPI} ( VAR lpFrequency: LargeInteger ): BOOL;

	(** Retrieves the cycle time for the specified thread (both user and kernel mode, Windows Vista and newer) *)
	QueryThreadCycleTime- : PROCEDURE {WINAPI} (hThread : HANDLE; VAR cycleTime : HUGEINT) : BOOL;
	(** The ReadFile function reads data from a file, starting at the position indicated by the file pointer. *)
	ReadFile-: PROCEDURE {WINAPI} ( hFile: HANDLE;
															  VAR lpBuffer: ARRAY   OF SYSTEM.BYTE;
															  nNumberOfBytesToRead: LONGINT;
															  VAR lpNumberOfBytesRead: LONGINT;
															  lpOverlapped {UNTRACED}: ANY ): BOOL;
	(** The ReadProcessMemory function reads data from an area of memory in a specified process. *)
	ReadProcessMemory-: PROCEDURE {WINAPI} ( hProcess: HANDLE;
																				   lpBaseAddress: ADDRESS;
																				   VAR lpBuffer: ARRAY   OF SYSTEM.BYTE;
																				   nSize: LONGINT;
																				   VAR lpNumberOfBytesRead: LONGINT ): BOOL;
	(** The ReleaseSemaphore function increases the count of the specified semaphore object by a specified amount. *)
	ReleaseSemaphore-: PROCEDURE {WINAPI} ( hSemaphore: HANDLE; lReleaseCount: LONGINT; lpPreviousCount: ADDRESS): BOOL;
	(** The RemoveDirectory function deletes an existing empty directory. *)
	RemoveDirectory-: PROCEDURE {WINAPI} ( VAR lpPathName: ARRAY   OF CHAR ): BOOL;
	(** The ResetEvent function sets the state of the specified event object to nonsignaled. *)
	ResetEvent-: PROCEDURE {WINAPI} ( hEvent: HANDLE ): BOOL;
	(** The ResumeThread function decrements a thread's suspend count. *)
	ResumeThread-: PROCEDURE {WINAPI} ( hThread: HANDLE ): LONGINT;
	(** The SearchPath function searches for the specified file. *)
	SearchPath-: PROCEDURE {WINAPI} ( CONST lpPath, lpFileName, lpExtension: ARRAY   OF CHAR;
																  nBufferLength: LONGINT;
																  VAR lpBuffer: ARRAY   OF CHAR;
																  VAR lpFilePart: LPSTR ): LONGINT;
	(** The SetCommBreak function suspends character transmission for a specified communications device and places the transmission line in a break state until the ClearCommBreak function is called. *)
	SetCommBreak-: PROCEDURE {WINAPI} ( hFile: HANDLE ): BOOL;
	(** The SetCommMask function specifies a set of events to be monitored for a communications device. *)
	SetCommMask-: PROCEDURE {WINAPI} ( hFile: HANDLE;  dwEvtMask: SET ): BOOL;
	(** The SetCommState function configures a communications device according to the specifications in a device-control block (a DCB structure)*)
	SetCommState-: PROCEDURE {WINAPI} ( hFile: HANDLE;
																	    VAR lpDCB: DCB ): BOOL;
	(** The SetCommTimeouts function sets the time-out parameters for all read and write operations on a specified communications device. *)
	SetCommTimeouts-: PROCEDURE {WINAPI} ( hFile: HANDLE;
																			    VAR lpCommTimeouts: CommTimeouts ): BOOL;
	(** the SetConsoleCursorPosition  sets the cursor position in the specified console screen buffer. *)
	SetConsoleCursorPosition-: PROCEDURE {WINAPI} ( hConsoleOutput: HANDLE;  dwCursorPosition:  (* imitate Coord=RECORD x,y: INTEGER END; *) LONGINT ): BOOL;
	(** The SetConsoleScreenBufferSize function changes the size of the specified console screen buffer. *)
	SetConsoleScreenBufferSize-: PROCEDURE {WINAPI} ( hConsoleOuput: HANDLE;
																							   dwSize: LONGINT ): BOOL;
	(** The SetConsoleTextAttribute function sets the attributes of characters written to the console screen buffer by the WriteFile or WriteConsole function, or echoed by the ReadFile or ReadConsole function. *)
	SetConsoleTextAttribute-: PROCEDURE {WINAPI} (hConsoleOutput: HANDLE; wAttributes: LONGINT): BOOL;
	(** The SetConsoleTitle function sets the title bar string for the current console window. *)
	SetConsoleTitle-: PROCEDURE {WINAPI} ( VAR lpConsoleTitle: ARRAY   OF CHAR ): BOOL;
	(** The SetConsoleWindowInfo function sets the current size and position of a console screen buffer's window. *)
	SetConsoleWindowInfo-: PROCEDURE {WINAPI} ( hConsoleOuput: HANDLE;
																						 bAbsolute: BOOL;
																						 VAR lpConsoleWindow: SmallRect ): BOOL;
	(** The SetCurrentDirectory function changes the current directory for the current process. *)
	SetCurrentDirectory-: PROCEDURE {WINAPI} ( VAR lpPathName: ARRAY   OF CHAR ): BOOL;
	(** The SetErrorMode function controls whether the system will handle the specified types of serious errors,
			or whether the process will handle them. *)
	SetErrorMode-: PROCEDURE {WINAPI} ( uMode: SET ): SET;
	(** The SetEndOfFile function moves the end-of-file (EOF) position for the specified file to the current position of the file pointer. *)
	SetEndOfFile-: PROCEDURE {WINAPI} ( hFile: HANDLE ): BOOL;
	(** The SetEvent function sets the state of the specified event object to signaled. *)
	SetEvent-: PROCEDURE {WINAPI} ( hEvent: HANDLE ): BOOL;
	(** The SetFileAttributes function sets a file's attributes. *)
	SetFileAttributes-: PROCEDURE {WINAPI} ( VAR lpFileName: ARRAY   OF CHAR;
																			dwFileAttributes: SET ): BOOL;
	(** The SetFilePointer function moves the file pointer of an open file. *)
	SetFilePointer-: PROCEDURE {WINAPI} ( hFile: HANDLE;  lDistanceToMove: LONGINT;
																	    VAR lpDistanceToMoveHigh: LONGINT;
																	    dwMoveMethod: LONGINT ): LONGINT;
	(** The SetFileTime function sets the date and time that a file was created, last accessed, or last modified. *)
	SetFileTime-: PROCEDURE {WINAPI} ( hFile: HANDLE;
																    VAR lpCreationTime, lpLastAccessTime, lpLastWriteTime: FileTime ): BOOL;
	(** The SetLocalTime function sets the current local time and date. *)
	SetLocalTime-: PROCEDURE {WINAPI} ( VAR lpSystemTime: SystemTime ): BOOL;
	(** The SetThreadAffinityMask function sets a processor affinity mask for the specified thread. *)
	SetThreadAffinityMask-: PROCEDURE {WINAPI} ( hThread: HANDLE; dwThreadAffinityMask: SET): SET;
	(** The SetThreadContext function sets the context in the specified thread. *)
	SetThreadContext-: PROCEDURE {WINAPI} ( hThread: HANDLE;
																			  VAR lpContext: Context ): BOOL;
	(** The SetThreadPriority function sets the priority value for the specified thread. *)
	SetThreadPriority-: PROCEDURE {WINAPI} ( hThread: HANDLE;
																			 nPriority: LONGINT ): BOOL;
	(** The SetupComm function initializes the communications parameters for a specified communications device. *)
	SetupComm-: PROCEDURE {WINAPI} ( hFile: HANDLE;
																    dwInQueue, dwOutQueue: LONGINT ): BOOL;
	(** The Sleep function suspends the execution of the current thread for a specified interval. *)
	Sleep-: PROCEDURE {WINAPI} ( dwMilliseconds: LONGINT );
	(** The SuspendThread function suspends the specified thread. *)
	SuspendThread-: PROCEDURE {WINAPI} ( hThread: HANDLE ): LONGINT;
	(** The SystemTimeToFileTime function converts a system time to a file time. *)
	SystemTimeToFileTime-: PROCEDURE {WINAPI} ( VAR lpSystemTime: SystemTime;
																					   VAR lpFileTime: FileTime ): BOOL;
	(** The TerminateThread function terminates a thread. *)
	TerminateThread-: PROCEDURE {WINAPI} ( hThread: HANDLE;
																			 dwExitCode: LONGINT ): BOOL;
	TlsAlloc-: PROCEDURE {WINAPI} ( ): LONGINT;
	TlsFree-: PROCEDURE {WINAPI} ( dwTlsIndex: LONGINT ): BOOL;
	TlsGetValue-: PROCEDURE {WINAPI} ( dwTlsIndex: LONGINT ): LONGINT;
	TlsSetValue-: PROCEDURE {WINAPI} ( dwTlsIndex, lpTlsValue: LONGINT ): BOOL;
	(** The TryEnterCriticalSection function attempts to enter a critical section without blocking. *)
	TryEnterCriticalSection-: PROCEDURE {WINAPI} ( VAR lpCriticalSection: CriticalSection ): BOOL;
	(** The VirtualAlloc function reserves or commits a region of pages in the virtual address space of the calling process. *)
	VirtualAlloc-: PROCEDURE {WINAPI} ( lpAddress: ADDRESS;  dwSize: LONGINT;
																    flAllocationType, flProtect: SET ): ADDRESS;
	(** The VirtualFree function releases or decommits (or both) a region of pages within the virtual address space of the
			calling process. *)
	VirtualFree-: PROCEDURE {WINAPI} ( lpAddress: ADDRESS;  dwSize: LONGINT;
																  dwFreeType: SET ): BOOL;
	(** The WaitForSingleObject function returns when one of the following occurs:
			The specified object is in the signaled state.
			The time-out interval elapses. *)
	WaitForSingleObject-: PROCEDURE {WINAPI} ( hHandle: HANDLE;
																				   dwMilliseconds: LONGINT ): LONGINT;
	(** The WriteFile function writes data to a file and is designed for both synchronous and asynchronous operation. *)
	WriteFile-: PROCEDURE {WINAPI} ( hFile: HANDLE;
															   CONST lpBuffer: ARRAY   OF SYSTEM.BYTE;
															   nNumberOfBytesToWrite: LONGINT;
															   VAR lpNumberOfBytesWritten: LONGINT;
															   lpOverlapped {UNTRACED}: ANY ): BOOL;
	(** Thread abort notifier, parameter is the threads id. Note this should only be used in modules which
			can't use the exception handling mechanism provided by module Exceptions. *)

	(** Method used to write text to the Console. *)
	OutputString*: PROCEDURE ( CONST a: ARRAY OF CHAR );

	hInstance-: HINSTANCE;   (* init by linker/loader *)
	isEXE-: BOOLEAN;

	PROCEDURE {WINAPI} ExceptionHandler( VAR excpRec: ExceptionRecord; excpFrame: ExcpFrmPtr;
	 										VAR context: Context;  dispatch: LONGINT ): LONGINT;
	PROCEDURE Trap EXTERN "Runtime.Trap" (number: SIZE);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		SYSTEM.SetActivity (context.ECX);
		Trap (excpRec.ExceptionCode);
	END ExceptionHandler;

	PROCEDURE InstallExceptionHandler-;
	CODE
		DB	064H, 08BH, 01DH, 000H, 000H, 000H, 000H
		MOV	[EBX + 4], ExceptionHandler
	END InstallExceptionHandler;

	(** Wrapper for getProcAddress. *)
	PROCEDURE GetProcAddress*( hModule: HMODULE;  procName: ARRAY OF CHAR; VAR adr: ADDRESS );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		adr := getProcAddress( hModule, procName );
	END GetProcAddress;

(** Copy a zero-terminated string from address lpString. *)
	PROCEDURE CopyString*( lpString: LPSTR;  VAR str: ARRAY OF CHAR );
	VAR i: LONGINT;  ch: CHAR;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		i := 0;
		IF lpString # NULL THEN
			SYSTEM.GET( lpString, ch );
			WHILE ch # 0X DO
				str[i] := ch;  INC( i );  INC( lpString );  SYSTEM.GET( lpString, ch )
			END
		END;
		str[i] := 0X
	END CopyString;

	PROCEDURE OutputDebugString*( CONST str: ARRAY OF CHAR );
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		outputDebugString( str );
	END OutputDebugString;

	PROCEDURE NoOutputString(CONST str: ARRAY OF CHAR);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
	END NoOutputString;

	PROCEDURE SendToDebugger*(str: ARRAY OF CHAR;  x: LONGINT );
	VAR s: ARRAY 16 OF CHAR;
		d, i: LONGINT;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		outputDebugString( str );  s[8] := 0X;
		FOR i := 7 TO 0 BY -1 DO
			d := x MOD 16;
			IF d < 10 THEN s[i] := CHR( d + ORD( "0" ) ) ELSE s[i] := CHR( d - 10 + ORD( "A" ) ) END;
			x := x DIV 16
		END;
		outputDebugString( s );  s[0] := 0AX;  s[1] := 0X;  outputDebugString( s )
	END SendToDebugger;

	PROCEDURE Shutdown*(l: LONGINT);
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		outputDebugString("Kernel32.Shutdown");
		ExitProcess(l);
	END Shutdown;

	PROCEDURE Init;
	VAR mod: HMODULE;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		InstallExceptionHandler;
		mod := LoadLibrary("Kernel32.DLL");
		GetProcAddress(mod, "AllocConsole",SYSTEM.VAL(ADDRESS,AllocConsole));
		GetProcAddress(mod, "Beep",SYSTEM.VAL(ADDRESS,Beep));
		GetProcAddress(mod, "ClearCommBreak",SYSTEM.VAL(ADDRESS,ClearCommBreak));
		GetProcAddress(mod, "ClearCommError",SYSTEM.VAL(ADDRESS,ClearCommError));
		GetProcAddress(mod, "CloseHandle",SYSTEM.VAL(ADDRESS,CloseHandle));
		GetProcAddress(mod, "CopyFileA",SYSTEM.VAL(ADDRESS,CopyFile));
		GetProcAddress(mod, "CreateDirectoryA",SYSTEM.VAL(ADDRESS,CreateDirectory));
		GetProcAddress(mod, "CreateEventA",SYSTEM.VAL(ADDRESS,CreateEvent));
		GetProcAddress(mod, "CreateFileA",SYSTEM.VAL(ADDRESS,CreateFile));
		GetProcAddress(mod, "CreateProcessA",SYSTEM.VAL(ADDRESS,CreateProcess));
		GetProcAddress(mod, "CreateSemaphoreA",SYSTEM.VAL(ADDRESS,CreateSemaphore));
		GetProcAddress(mod, "CreateThread",SYSTEM.VAL(ADDRESS,CreateThread));
		GetProcAddress(mod, "DeleteCriticalSection",SYSTEM.VAL(ADDRESS,DeleteCriticalSection));
		GetProcAddress(mod, "DeleteFileA",SYSTEM.VAL(ADDRESS,DeleteFile));
		GetProcAddress(mod, "DisableThreadLibraryCalls",SYSTEM.VAL(ADDRESS,DisableThreadLibraryCalls));
		GetProcAddress(mod, "DuplicateHandle",SYSTEM.VAL(ADDRESS,DuplicateHandle));
		GetProcAddress(mod, "EnterCriticalSection",SYSTEM.VAL(ADDRESS,EnterCriticalSection));
		GetProcAddress(mod, "EscapeCommFunction",SYSTEM.VAL(ADDRESS,EscapeCommFunction));
		GetProcAddress(mod, "ExitProcess",SYSTEM.VAL(ADDRESS,ExitProcess));
		GetProcAddress(mod, "ExitThread",SYSTEM.VAL(ADDRESS,ExitThread));
		GetProcAddress(mod, "FindClose",SYSTEM.VAL(ADDRESS,FindClose));
		GetProcAddress(mod, "FileTimeToLocalFileTime",SYSTEM.VAL(ADDRESS,FileTimeToLocalFileTime));
		GetProcAddress(mod, "FileTimeToSystemTime",SYSTEM.VAL(ADDRESS,FileTimeToSystemTime));
		GetProcAddress(mod, "FindFirstFileA",SYSTEM.VAL(ADDRESS,FindFirstFile));
		GetProcAddress(mod, "FindNextFileA",SYSTEM.VAL(ADDRESS,FindNextFile));
		GetProcAddress(mod, "FlushFileBuffers",SYSTEM.VAL(ADDRESS,FlushFileBuffers));
		GetProcAddress(mod, "FreeConsole",SYSTEM.VAL(ADDRESS,FreeConsole));
		GetProcAddress(mod, "FreeLibrary",SYSTEM.VAL(ADDRESS,FreeLibrary));
		GetProcAddress(mod, "GetCommandLineA",SYSTEM.VAL(ADDRESS,GetCommandLine));
		GetProcAddress(mod, "GetCommModemStatus",SYSTEM.VAL(ADDRESS,GetCommModemStatus));
		GetProcAddress(mod, "GetCommState",SYSTEM.VAL(ADDRESS,GetCommState));
		GetProcAddress(mod, "GetComputerNameA",SYSTEM.VAL(ADDRESS,GetComputerName));
		GetProcAddress(mod, "GetCurrentDirectoryA",SYSTEM.VAL(ADDRESS,GetCurrentDirectory));
		GetProcAddress(mod, "GetCurrentProcess",SYSTEM.VAL(ADDRESS,GetCurrentProcess));
		GetProcAddress(mod, "GetCurrentProcessId",SYSTEM.VAL(ADDRESS,GetCurrentProcessId));
		GetProcAddress(mod, "GetCurrentThread",SYSTEM.VAL(ADDRESS,GetCurrentThread));
		GetProcAddress(mod, "GetCurrentThreadId",SYSTEM.VAL(ADDRESS,GetCurrentThreadId));
		GetProcAddress(mod, "GetDiskFreeSpaceA",SYSTEM.VAL(ADDRESS,GetDiskFreeSpace));
		GetProcAddress(mod, "GetDriveTypeA",SYSTEM.VAL(ADDRESS,GetDriveType));
		GetProcAddress(mod, "GetExitCodeProcess",SYSTEM.VAL(ADDRESS,GetExitCodeProcess));
		GetProcAddress(mod, "GetFileAttributesA",SYSTEM.VAL(ADDRESS,GetFileAttributes));
		GetProcAddress(mod, "GetFileSize",SYSTEM.VAL(ADDRESS,GetFileSize));
		GetProcAddress(mod, "GetFileTime",SYSTEM.VAL(ADDRESS,GetFileTime));
		GetProcAddress(mod, "GetFullPathNameA",SYSTEM.VAL(ADDRESS,GetFullPathName));
		GetProcAddress(mod, "GetLastError",SYSTEM.VAL(ADDRESS,GetLastError));
		GetProcAddress(mod, "GetLocalTime",SYSTEM.VAL(ADDRESS,GetLocalTime));
		GetProcAddress(mod, "GetLogicalDriveStringsA",SYSTEM.VAL(ADDRESS,GetLogicalDriveStrings));
		GetProcAddress(mod, "GetLogicalDrives",SYSTEM.VAL(ADDRESS,GetLogicalDrives));
		GetProcAddress(mod, "GetModuleFileNameA",SYSTEM.VAL(ADDRESS,GetModuleFileName));
		GetProcAddress(mod, "GetModuleHandleA",SYSTEM.VAL(ADDRESS,GetModuleHandle));
		GetProcAddress(mod, "GetPrivateProfileStringA",SYSTEM.VAL(ADDRESS,GetPrivateProfileString));
		(* must be done by linker: GetProcAddress(mod, "GetProcAddress",SYSTEM.VAL(ADDRESS,getProcAddress)); *)
		GetProcAddress(mod, "GetProcessAffinityMask",SYSTEM.VAL(ADDRESS,GetProcessAffinityMask));
		GetProcAddress(mod, "GetProcessHeap",SYSTEM.VAL(ADDRESS,GetProcessHeap));
		GetProcAddress(mod, "GetProcessTimes", SYSTEM.VAL(ADDRESS, GetProcessTimes));
		GetProcAddress(mod, "GetStartupInfoA",SYSTEM.VAL(ADDRESS,GetStartupInfo));
		GetProcAddress(mod, "GetStdHandle",SYSTEM.VAL(ADDRESS,GetStdHandle));
		GetProcAddress(mod, "GetSystemInfo",SYSTEM.VAL(ADDRESS,GetSystemInfo));
		GetProcAddress(mod, "GetSystemTime",SYSTEM.VAL(ADDRESS,GetSystemTime));
		GetProcAddress(mod, "GetTempFileNameA",SYSTEM.VAL(ADDRESS,GetTempFileName));
		GetProcAddress(mod, "GetTempPathA",SYSTEM.VAL(ADDRESS,GetTempPath));
		GetProcAddress(mod, "GetThreadContext",SYSTEM.VAL(ADDRESS,GetThreadContext));
		GetProcAddress(mod, "GetThreadPriority",SYSTEM.VAL(ADDRESS,GetThreadPriority));
		GetProcAddress(mod, "GetThreadTimes",SYSTEM.VAL(ADDRESS,GetThreadTimes));
		GetProcAddress(mod, "GetTickCount",SYSTEM.VAL(ADDRESS,GetTickCount));
		GetProcAddress(mod, "GetWindowsDirectoryA",SYSTEM.VAL(ADDRESS,GetWindowsDirectory));
		GetProcAddress(mod, "GetTimeZoneInformation",SYSTEM.VAL(ADDRESS,GetTimeZoneInformation));
		GetProcAddress(mod, "GetVersion",SYSTEM.VAL(ADDRESS,GetVersion));
		GetProcAddress(mod, "GetVersionExA",SYSTEM.VAL(ADDRESS,GetVersionEx));
		GetProcAddress(mod, "GetVolumeInformationA",SYSTEM.VAL(ADDRESS,GetVolumeInformation));
		GetProcAddress(mod, "GlobalAddAtomA",SYSTEM.VAL(ADDRESS,GlobalAddAtom));
		GetProcAddress(mod, "GlobalAlloc",SYSTEM.VAL(ADDRESS,GlobalAlloc));
		GetProcAddress(mod, "GlobalDeleteAtom",SYSTEM.VAL(ADDRESS,GlobalDeleteAtom));
		GetProcAddress(mod, "GlobalLock",SYSTEM.VAL(ADDRESS,GlobalLock));
		GetProcAddress(mod, "GlobalReAlloc",SYSTEM.VAL(ADDRESS,GlobalReAlloc));
		GetProcAddress(mod, "GlobalSize",SYSTEM.VAL(ADDRESS,GlobalSize));
		GetProcAddress(mod, "GlobalUnlock",SYSTEM.VAL(ADDRESS,GlobalUnlock));
		GetProcAddress(mod, "HeapAlloc",SYSTEM.VAL(ADDRESS,HeapAlloc));
		GetProcAddress(mod, "HeapFree",SYSTEM.VAL(ADDRESS,HeapFree));
		GetProcAddress(mod, "InitializeCriticalSection",SYSTEM.VAL(ADDRESS,InitializeCriticalSection));
		GetProcAddress(mod, "InterlockedDecrement",SYSTEM.VAL(ADDRESS,InterlockedDecrement));
		GetProcAddress(mod, "InterlockedIncrement",SYSTEM.VAL(ADDRESS,InterlockedIncrement));
		GetProcAddress(mod, "IsDebuggerPresent",SYSTEM.VAL(ADDRESS,IsDebuggerPresent));
		GetProcAddress(mod, "LeaveCriticalSection",SYSTEM.VAL(ADDRESS,LeaveCriticalSection));
		(* must be done by linker: GetProcAddress(mod, "LoadLibraryA",SYSTEM.VAL(ADDRESS,LoadLibrary)); *)
		GetProcAddress(mod, "LocalFileTimeToFileTime",SYSTEM.VAL(ADDRESS,LocalFileTimeToFileTime));
		GetProcAddress(mod, "MoveFileExA",SYSTEM.VAL(ADDRESS,MoveFileEx));
		GetProcAddress(mod, "OutputDebugStringA",SYSTEM.VAL(ADDRESS,outputDebugString));
		GetProcAddress(mod, "PurgeComm",SYSTEM.VAL(ADDRESS,PurgeComm));
		GetProcAddress(mod, "QueryDosDeviceA",SYSTEM.VAL(ADDRESS,QueryDosDevice));
		GetProcAddress(mod, "QueryPerformanceCounter",SYSTEM.VAL(ADDRESS,QueryPerformanceCounter));
		GetProcAddress(mod, "QueryPerformanceFrequency",SYSTEM.VAL(ADDRESS,QueryPerformanceFrequency));
		GetProcAddress(mod, "QueryThreadCycleTime", SYSTEM.VAL(ADDRESS, QueryThreadCycleTime));
		GetProcAddress(mod, "ReadFile",SYSTEM.VAL(ADDRESS,ReadFile));
		GetProcAddress(mod, "ReadProcessMemory",SYSTEM.VAL(ADDRESS,ReadProcessMemory));
		GetProcAddress(mod, "ReleaseSemaphore",SYSTEM.VAL(ADDRESS,ReleaseSemaphore));
		GetProcAddress(mod, "RemoveDirectoryA",SYSTEM.VAL(ADDRESS,RemoveDirectory));
		GetProcAddress(mod, "ResetEvent",SYSTEM.VAL(ADDRESS,ResetEvent));
		GetProcAddress(mod, "ResumeThread",SYSTEM.VAL(ADDRESS,ResumeThread));
		GetProcAddress(mod, "SearchPathA",SYSTEM.VAL(ADDRESS,SearchPath));
		GetProcAddress(mod, "SetCommBreak",SYSTEM.VAL(ADDRESS,SetCommBreak));
		GetProcAddress(mod, "SetCommMask",SYSTEM.VAL(ADDRESS,SetCommMask));
		GetProcAddress(mod, "SetCommState",SYSTEM.VAL(ADDRESS,SetCommState));
		GetProcAddress(mod, "SetCommTimeouts",SYSTEM.VAL(ADDRESS,SetCommTimeouts));
		GetProcAddress(mod, "SetConsoleCursorPosition",SYSTEM.VAL(ADDRESS,SetConsoleCursorPosition));
		GetProcAddress(mod, "SetConsoleScreenBufferSize",SYSTEM.VAL(ADDRESS,SetConsoleScreenBufferSize));
		GetProcAddress(mod, "SetConsoleTextAttribute",SYSTEM.VAL(ADDRESS,SetConsoleTextAttribute));
		GetProcAddress(mod, "SetConsoleTitleA",SYSTEM.VAL(ADDRESS,SetConsoleTitle));
		GetProcAddress(mod, "SetConsoleWindowInfo",SYSTEM.VAL(ADDRESS,SetConsoleWindowInfo));
		GetProcAddress(mod, "SetCurrentDirectoryA",SYSTEM.VAL(ADDRESS,SetCurrentDirectory));
		GetProcAddress(mod, "SetEndOfFile",SYSTEM.VAL(ADDRESS,SetEndOfFile));
		GetProcAddress(mod, "SetErrorMode",SYSTEM.VAL(ADDRESS,SetErrorMode));
		GetProcAddress(mod, "SetEvent",SYSTEM.VAL(ADDRESS,SetEvent));
		GetProcAddress(mod, "SetFileAttributesA",SYSTEM.VAL(ADDRESS,SetFileAttributes));
		GetProcAddress(mod, "SetFilePointer",SYSTEM.VAL(ADDRESS,SetFilePointer));
		GetProcAddress(mod, "SetFileTime",SYSTEM.VAL(ADDRESS,SetFileTime));
		GetProcAddress(mod, "SetLocalTime",SYSTEM.VAL(ADDRESS,SetLocalTime));
		GetProcAddress(mod, "SetThreadAffinityMask",SYSTEM.VAL(ADDRESS,SetThreadAffinityMask));
		GetProcAddress(mod, "SetThreadContext",SYSTEM.VAL(ADDRESS,SetThreadContext));
		GetProcAddress(mod, "SetThreadPriority",SYSTEM.VAL(ADDRESS,SetThreadPriority));
		GetProcAddress(mod, "SetupComm",SYSTEM.VAL(ADDRESS,SetupComm));
		GetProcAddress(mod, "Sleep",SYSTEM.VAL(ADDRESS,Sleep));
		GetProcAddress(mod, "SuspendThread",SYSTEM.VAL(ADDRESS,SuspendThread));
		GetProcAddress(mod, "SystemTimeToFileTime",SYSTEM.VAL(ADDRESS,SystemTimeToFileTime));
		GetProcAddress(mod, "TerminateThread",SYSTEM.VAL(ADDRESS,TerminateThread));
		GetProcAddress(mod, "TlsAlloc",SYSTEM.VAL(ADDRESS,TlsAlloc));
		GetProcAddress(mod, "TlsFree",SYSTEM.VAL(ADDRESS,TlsFree));
		GetProcAddress(mod, "TlsGetValue",SYSTEM.VAL(ADDRESS,TlsGetValue));
		GetProcAddress(mod, "TlsSetValue",SYSTEM.VAL(ADDRESS,TlsSetValue));
		GetProcAddress(mod, "TryEnterCriticalSection", SYSTEM.VAL(ADDRESS, TryEnterCriticalSection));
		GetProcAddress(mod, "VirtualAlloc",SYSTEM.VAL(ADDRESS,VirtualAlloc));
		GetProcAddress(mod, "VirtualFree",SYSTEM.VAL(ADDRESS,VirtualFree));
		GetProcAddress(mod, "WaitForSingleObject",SYSTEM.VAL(ADDRESS,WaitForSingleObject));
		GetProcAddress(mod, "WriteFile",SYSTEM.VAL(ADDRESS,WriteFile));
		GetProcAddress(mod, "GlobalMemoryStatusEx",SYSTEM.VAL(ADDRESS,GlobalMemoryStatusEx));
		IF IsDebuggerPresent()=True THEN
			OutputString := OutputDebugString
		ELSE
			OutputString := NoOutputString
		END;
		isEXE := hInstance = NULL;
		IF isEXE THEN hInstance := GetModuleHandle( NIL ) END;
		END Init;

		(* The following procedure is linked as the first block in the code section of a PE32 executable file 
			It contains the import table for the two procedures Kernel32.GetProcAddress and Kernel32.LoadLibrary that
			are patched by the PE linker. 
			[CF. Microsoft Portable Executable and Common Object File Format Specification]
		*)
		PROCEDURE {NOPAF, FIXED(401000H)} EntryPoint;
		CODE{SYSTEM.i386}
			JMP  DWORD end;
			DB 0
			DB 0
			DB 0

		ImportTable:
			DD Kernel32Import + 1000H 
			DD 0
			DD -1
			DD Kernel32Name + 1000H
			DD Kernel32Import + 1000H
			DD 0, 0, 0, 0, 0
		
		Kernel32Import:
		adrLoadLibrary:			
			DD LoadLibraryA + 1000H
		adrGetProcAddress:			
			DD GetProcAddress + 1000H
			DD 0
			
		Kernel32Name:
			DB 'KERNEL32.DLL' , 0
			
		LoadLibraryA:			
			DW 0
			DB 'LoadLibraryA',0,0
			
		GetProcAddress:
			DW 0
			DB 'GetProcAddress',0
			
		end:
			MOV EAX,[401000H+adrLoadLibrary]
			MOV LoadLibrary, EAX
			MOV EAX,[401000H+adrGetProcAddress]
			MOV getProcAddress, EAX
			CALL Init
		END EntryPoint;

END Kernel32.
	
