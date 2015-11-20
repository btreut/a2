(* Copyright (c) 2004 - 2005 DP Sisteme  2000 srl*)

MODULE Shell32; (** non-portable / source: Win32.Shell32.Mod *)
	IMPORT SYSTEM, Kernel32, Modules;
	CONST
	(*
	#define SW_HIDE             0
	#define SW_SHOWNORMAL       1
	#define SW_NORMAL           1
	#define SW_SHOWMINIMIZED    2
	#define SW_SHOWMAXIMIZED    3
	#define SW_MAXIMIZE         3
	#define SW_SHOWNOACTIVATE   4
	#define SW_SHOW             5
	#define SW_MINIMIZE         6
	#define SW_SHOWMINNOACTIVE  7
	#define SW_SHOWNA           8
	#define SW_RESTORE          9
	#define SW_SHOWDEFAULT      10
	#define SW_FORCEMINIMIZE    11
	#define SW_MAX              11
	*)
	SWNORMAL* = 1;

    TYPE
    	LPCSTR* = ADDRESS;
    	HWND* = Kernel32.HANDLE;
		HINSTANCE* = Kernel32.HINSTANCE;
		INT* =  LONGINT;
	VAR
	shell32: Kernel32.HMODULE;

	ShellExecute-: PROCEDURE {WINAPI}
	(hwnd: HWND; lpOperation, lpFile: ARRAY OF CHAR; lpParameters, lpDirectory: LPCSTR;  nShowCmd: INT): HINSTANCE;


	PROCEDURE TermMod;
	BEGIN
		IF shell32 # Kernel32.NULL THEN
			Kernel32.FreeLibrary(shell32); shell32 := Kernel32.NULL
		END
	END TermMod;

	PROCEDURE Init;
	VAR str: ARRAY 32 OF CHAR;
	BEGIN
		str := "shell32.dll";
		shell32 := Kernel32.LoadLibrary(str);
		Kernel32.GetProcAddress(shell32, "ShellExecuteA", SYSTEM.VAL(ADDRESS, ShellExecute));

		Modules.InstallTermHandler(TermMod)
	END Init;

BEGIN
	Init()
END Shell32.
