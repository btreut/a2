(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE ADVAPI32;  (** non-portable / source: Win32.ADVAPI32.Mod *)	(* ejz *)
IMPORT SYSTEM, Kernel32, Modules, KernelLog; 		(* ALEX *)

	(** This module defines all the Win32 ADVAPI32 APIs used by Oberon.
	Note this module is part of the Oberon inner-core and must be linked with PELinker. *)

CONST
	(** HKEYs *)
	HKEYClassesRoot* = LONGINT(080000000H);  HKEYCurrentUser* = LONGINT(080000001H);

	(** value type *)
	RegNone* = 0;  RegSZ* = 01H;

	(** sam *)
	KeyQueryValue* = 0;  KeySetValue* = 1;  KeyCreateSubKey* = 2;  KeyEnumerateSubKeys* = 3;  KeyAllAccess* = {19, 18, 17, 16, 5, 4 ,3, 2, 1, 0};

	(** options *)
	RegOptionNonVolatile* = {};

	(** error codes *)
	Success* = 0H;  ErrorMoreData* = 234;

	(* ALEX *)
	SC_MANAGER_CREATE_SERVICE*  = 0002H;
	SC_MANAGER_ALL_ACCESS*  = 000F003FH;
	SERVICE_ALL_ACCESS* = 000F01FFH;

	SERVICE_WIN32_OWN_PROCESS* = 00000010H;
	SERVICE_AUTO_START* =  00000002H;
	SERVICE_ERROR_NORMAL* = 00000001H;


	SERVICE_WIN32* = 30H;
	SERVICE_START_PENDING *= 00000002H;
	SERVICE_ACCEPT_STOP* = 00000001H;
	SERVICE_ACCEPT_SHUTDOWN* = 00000004H;

	SERVICE_RUNNING* = 00000004H;
	SERVICE_CONTROL_STOP* = 00000001H;
	SERVICE_CONTROL_SHUTDOWN* = 00000005H;
	SERVICE_STOPPED*	= 00000001H;


TYPE
	(** Handle to a registry key. *)
	HKEY* = ADDRESS;

	(* ALEX *)
    	LPSTR* = ADDRESS;
    	LPCSTR* = ARRAY  OF CHAR;
    	HWND* = Kernel32.HANDLE;
	HINSTANCE* = Kernel32.HINSTANCE;
	INT* =  LONGINT;
	LPCTSTR* = LPCSTR;
	SC_HANDLE* = Kernel32.HANDLE;
	DWORD* = LONGINT;
	LPDWORD* = ADDRESS;
	BOOL* = Kernel32.BOOL;
	LPSERVICE_MAIN_FUNCTIONA = PROCEDURE {WINAPI} (dwNumServicesArgs: DWORD; VAR lpServiceArgVectors: ARRAY  OF CHAR): BOOL;
	LPSERVICE_MAIN_FUNCTION* = LPSERVICE_MAIN_FUNCTIONA;
	SERVICE_TABLE_ENTRYA = RECORD
		lpServiceName*: LPSTR;
		lpServiceProc*: LPSERVICE_MAIN_FUNCTIONA;
	END;
	SERVICE_TABLE_ENTRY* = SERVICE_TABLE_ENTRYA;
	LPHANDLER_FUNCTION* = PROCEDURE {WINAPI} (dwControl: DWORD);
	SERVICE_STATUS_HANDLE* = Kernel32.HANDLE;
	SERVICE_STATUS* = RECORD
		dwServiceType*,
		dwCurrentState*,

		dwControlsAccepted*,
		dwWin32ExitCode*,
		dwServiceSpecificExitCode*,
		dwCheckPoint*,
		dwWaitHint*: DWORD;
	END;




VAR
	(** The GetUserName function retrieves the user name of the current thread. *)
	GetUserName-: PROCEDURE {WINAPI} (VAR lpBuffer: ARRAY   OF CHAR;  VAR nSize: LONGINT): Kernel32.BOOL;
	(** The RegCloseKey function releases a handle to the specified key. *)
	RegCloseKey-: PROCEDURE {WINAPI} (hKey: HKEY): LONGINT;
	(** The RegCreateKeyEx function creates the specified key. *)
	RegCreateKeyEx-: PROCEDURE {WINAPI} (hKey: HKEY;  lpSubKey: ARRAY   OF CHAR;  Reserved: LONGINT;  lpClass: ARRAY   OF CHAR;  dwOptions, samDesired: SET;  lpSecurityAttributes: ANY;  VAR phkResult: HKEY;  VAR lpdwDisposition: LONGINT): LONGINT;
	(** The RegDeleteKey function deleted a subkey. *)
	RegDeleteKey-: PROCEDURE {WINAPI} (hKey: HKEY;  lpSubKey: ARRAY   OF CHAR): LONGINT;
	(** The RegDeleteValue function removes a named value from the specified registry key. *)
	RegDeleteValue-: PROCEDURE {WINAPI} (hKey: HKEY;  lpValueName: ARRAY   OF CHAR): LONGINT;
	(** The RegEnumKeyEx function enumerates subkeys of the specified open registry key. *)
	RegEnumKeyEx-: PROCEDURE {WINAPI} (hKey: HKEY;  dwIndex: LONGINT;  VAR lpName: ARRAY   OF CHAR;  VAR lpcbName: LONGINT;  VAR lpReserved: LONGINT;  VAR lpClass: ARRAY   OF CHAR;  VAR lpcbClass: LONGINT;  VAR lpftLastWriteTime: Kernel32.FileTime): LONGINT;
	(** The RegEnumValue function enumerates the values for the specified open registry key. *)
	RegEnumValue-: PROCEDURE {WINAPI} (hKey: HKEY;  dwIndex: LONGINT;  VAR lpValueName: ARRAY   OF CHAR;  VAR lpcbValueName: LONGINT;  VAR lpReserved, type: LONGINT;  VAR lpData: ARRAY   OF SYSTEM.BYTE;  VAR lpcbData: LONGINT): LONGINT;
	(** The RegOpenKeyEx function opens the specified key. *)
	RegOpenKeyEx-: PROCEDURE {WINAPI} (hKey: HKEY;  lpSubKey: ARRAY   OF CHAR;  ulOptions: LONGINT;  samDesired: SET;  VAR phkResult: HKEY): LONGINT;
	(** The RegQueryValueEx function retrieves the type and data for a specified value name associated with an
			open registry key. *)
	RegQueryValueEx-: PROCEDURE {WINAPI} (hKey: HKEY;  lpValueName: ARRAY   OF CHAR;  VAR lpReserved, lpType: LONGINT;  VAR lpData: ARRAY   OF SYSTEM.BYTE;  VAR lpcbData: LONGINT): LONGINT;
	(** The RegSetValueEx function sets the data and type of a specified value under a registry key. *)
	RegSetValueEx-: PROCEDURE {WINAPI} (hKey: HKEY;  lpValueName: ARRAY   OF CHAR;  Reserved, dwType: LONGINT;  VAR lpData: ARRAY   OF SYSTEM.BYTE;  cbData: LONGINT): LONGINT;
	(** The GetFileVersionInfo function returns version information about a specified file. *)
	GetFileVersionInfo-: PROCEDURE {WINAPI} (lpstrFilename: ARRAY   OF CHAR;  dwHandle, dwLen: LONGINT;  VAR lpDate: ARRAY   OF SYSTEM.BYTE): Kernel32.BOOL;
	(** The GetFileVersionInfoSize function determines whether the operating system can obtain version information
			about a specified file. *)
	GetFileVersionInfoSize-: PROCEDURE {WINAPI} (lpstrFilename: ARRAY   OF CHAR;  VAR lpdwHandle: LONGINT): LONGINT;
	(** The VerQueryValue function returns selected version information from the specified version-information resource. *)
	VerQueryValue-: PROCEDURE {WINAPI} (pBlock: ARRAY   OF SYSTEM.BYTE;  lpSubBlock: ARRAY   OF CHAR;  VAR lplpBuffer: ADDRESS;  VAR puLen: LONGINT): Kernel32.BOOL;




	(* ALEX BEGIN *)
	CloseServiceHandle-: PROCEDURE {WINAPI} (hSCObject: SC_HANDLE): BOOL;

	CreateService-: PROCEDURE {WINAPI} (hSCManager: SC_HANDLE; VAR lpServiceName, lpDisplayName: LPCTSTR;
					dwDesiredAccess, dwServiceType, dwStartType, dwErrorControl: DWORD;
					VAR lpBinaryPathName, lpLoadOrderGroup: LPCTSTR; lpdwTagId: LPDWORD;
					VAR lpDependencies, lpServiceStartName, lpPassword: LPCTSTR): SC_HANDLE;


	DeleteService-: PROCEDURE {WINAPI} (hService: SC_HANDLE): BOOL;

	OpenSCManager-: PROCEDURE {WINAPI} (VAR lpMachineName, lpDatabaseName: LPCTSTR; dwDesiredAccess: DWORD): SC_HANDLE;
	OpenService-: PROCEDURE {WINAPI} (hSCManager: SC_HANDLE; VAR lpServiceName: LPCTSTR; dwDesiredAccess: DWORD): SC_HANDLE;



	RegisterServiceCtrlHandler-: PROCEDURE {WINAPI} (VAR lpServiceName: ARRAY  OF CHAR; lpHandlerProc: LPHANDLER_FUNCTION): SERVICE_STATUS_HANDLE;
	SetServiceStatus-: PROCEDURE {WINAPI} (hServiceStatus: SERVICE_STATUS_HANDLE; VAR lpServiceStatus: SERVICE_STATUS): BOOL;

	StartService-: PROCEDURE {WINAPI} (hService: SC_HANDLE; dwNumServiceArgs: DWORD; VAR lpServiceArgVectors: LPCTSTR): BOOL;
	StartServiceCtrlDispatcher-: PROCEDURE {WINAPI} (VAR lpServiceTable: ARRAY  OF SYSTEM.BYTE): BOOL;

	advapi32: Kernel32.HMODULE;


	PROCEDURE InstallService*(srvName, serviceDesc, exeFile: ARRAY OF CHAR): BOOLEAN;
	VAR newService, scm: SC_HANDLE; err: LONGINT;
	BEGIN
		scm := OpenSCManager(NIL,NIL,SC_MANAGER_CREATE_SERVICE);
		IF scm = Kernel32.NULL THEN
			err := OutError("Advapi32.OpenSCManager");
			RETURN FALSE;
		END;
		newService := CreateService(scm, srvName,
			serviceDesc,
			SERVICE_ALL_ACCESS,SERVICE_WIN32_OWN_PROCESS,SERVICE_AUTO_START,
			SERVICE_ERROR_NORMAL,
			exeFile,
			NIL,0,NIL,NIL,NIL);
		IF newService = Kernel32.NULL THEN
			err := OutError("Advapi32.CreateService");
			CloseServiceHandle(scm);
			RETURN FALSE;
		END;
		CloseServiceHandle(newService);
		CloseServiceHandle(scm);
		KernelLog.Enter;
		KernelLog.String('Service "'); KernelLog.String(srvName); KernelLog.String('" was installed!'); KernelLog.Ln;
		KernelLog.Exit;
		RETURN TRUE;
	END InstallService;

	PROCEDURE UninstallService*(srvName: ARRAY OF CHAR): BOOLEAN;
	VAR scm, service:  SC_HANDLE;
		ret: BOOL; err: LONGINT;
	BEGIN
		scm := OpenSCManager(NIL, NIL, SC_MANAGER_ALL_ACCESS);
		IF scm = Kernel32.NULL THEN
			err := OutError("Advapi32.OpenSCManager");
			RETURN FALSE
		ELSE
			service := OpenService( scm, srvName, SERVICE_ALL_ACCESS);
			IF service = Kernel32.NULL THEN
				err := OutError("Advapi32.OpenService");
				RETURN FALSE
			ELSE
				ret := DeleteService(service);
				IF ret = Kernel32.NULL THEN
					err := OutError("Advapi32.DeleteService");
					RETURN FALSE
				ELSE
					KernelLog.Enter;
					KernelLog.String('Service "'); KernelLog.String(srvName); KernelLog.String('" was removed!'); KernelLog.Ln;
					KernelLog.Exit;
				END;
				CloseServiceHandle(service);
			END;
			CloseServiceHandle(scm);
			RETURN TRUE
		END
	END UninstallService;


	PROCEDURE OutError*(funcName: ARRAY OF CHAR): LONGINT;
	VAR err: LONGINT;
	BEGIN
		err := Kernel32.GetLastError();
		KernelLog.Enter;
		KernelLog.String(funcName); KernelLog.String(" failed, error code = "); KernelLog.Int(err, 10);
		KernelLog.Ln; KernelLog.Exit;
		RETURN err
	END OutError;


	PROCEDURE TermMod;
	BEGIN
		IF advapi32 # Kernel32.NULL THEN
			Kernel32.FreeLibrary(advapi32); advapi32 := Kernel32.NULL
		END
	END TermMod;

	(* ALEX END *)




PROCEDURE GetProcAddress(hModule: ADDRESS; VAR adr: ADDRESS; procName: ARRAY OF CHAR);
BEGIN
	Kernel32.GetProcAddress(hModule,procName,adr);
END GetProcAddress;


PROCEDURE Init;
VAR
 mod: Kernel32.HMODULE;str: ARRAY 32 OF CHAR;
BEGIN
	str := "ADVAPI32.DLL";
	mod := Kernel32.LoadLibrary(str);
	advapi32 := mod;
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetUserName  ),"GetUserNameA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RegCloseKey  ),"RegCloseKey");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RegCreateKeyEx  ),"RegCreateKeyExA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RegDeleteKey  ),"RegDeleteKeyA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RegDeleteValue  ),"RegDeleteValueA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RegEnumKeyEx  ),"RegEnumKeyExA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RegEnumValue  ),"RegEnumValueA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RegOpenKeyEx  ),"RegOpenKeyExA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RegQueryValueEx  ),"RegQueryValueExA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RegSetValueEx  ),"RegSetValueExA");
str := "Version";
mod := Kernel32.LoadLibrary(str);
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetFileVersionInfo ),"GetFileVersionInfoA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetFileVersionInfoSize),"GetFileVersionInfoSizeA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,VerQueryValue),"VerQueryValueA");

		(* ALEX *)
		Kernel32.GetProcAddress(advapi32, "CloseServiceHandle", SYSTEM.VAL(ADDRESS, CloseServiceHandle));
		Kernel32.GetProcAddress(advapi32, "CreateServiceA", SYSTEM.VAL(ADDRESS, CreateService));
		Kernel32.GetProcAddress(advapi32, "DeleteService", SYSTEM.VAL(ADDRESS, DeleteService));
		Kernel32.GetProcAddress(advapi32, "OpenSCManagerA", SYSTEM.VAL(ADDRESS, OpenSCManager));
		Kernel32.GetProcAddress(advapi32, "OpenServiceA", SYSTEM.VAL(ADDRESS, OpenService));

		Kernel32.GetProcAddress(advapi32, "RegisterServiceCtrlHandlerA", SYSTEM.VAL(ADDRESS, RegisterServiceCtrlHandler));
		Kernel32.GetProcAddress(advapi32, "SetServiceStatusA", SYSTEM.VAL(ADDRESS, SetServiceStatus));

		Kernel32.GetProcAddress(advapi32, "StartServiceA", SYSTEM.VAL(ADDRESS, StartService));
		Kernel32.GetProcAddress(advapi32, "StartServiceCtrlDispatcherA", SYSTEM.VAL(ADDRESS, StartServiceCtrlDispatcher));
		Modules.InstallTermHandler(TermMod)

END Init;

BEGIN
	Init;
END ADVAPI32.
