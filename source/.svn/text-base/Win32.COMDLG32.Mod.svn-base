(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE COMDLG32; (** non-portable / source: Win32.COMDLG32.Mod *)	(* ejz  *)
	IMPORT SYSTEM, Kernel32, User32, Modules;		(* Dan *)

(** This module defines all the Win32 COMDLG32 APIs used by Oberon. *)

	CONST
		(** PRINTDLG Flags values *)
		PDPageNums* = 1; PDReturnDC* = 8; PDReturnDefault* = 10;
		(** PAGESETUPDLG Flags values *)
		PSDMargins* = 1; PSDInThousandthsOfInches* = 2; PSDInHundredthsOfMillimeters* = 3;

		(** FindReplace Flags values *)
		FRDown* = 0; FRWholeWord* = 1; FRMatchCase* = 2; FRFindNext* = 3; FRReplace* = 4;
		FRReplaceAll* = 5; FRDialogTerm* = 6; FRShowHelp * = 7; FRENableHook* = 8;
		FREnableTemplate* = 9; FRNoUpDown* = 10; FRNoMatchCase* = 11; FRNoWholeWord* = 12;
		FREnableTemplateHandle* = 13; FRHideUpDown* = 14; FRHideMatchCase* = 15;
		FRHideWholeWord* = 16;

		(** OpenFileName Flags values *)									(* Dan *)
		OFN_AllowMultiselect* = 0200H;  OFN_Explorer* = 080000H;


	TYPE
		(** The PRINTDLG structure contains information that the PrintDlg function uses to initialize the Print dialog box. *)
		PRINTDLG* = RECORD
			lStructSize*: LONGINT;
			hwndOwner*: User32.HWND;
			hDevMode*, hDevNames*: Kernel32.HANDLE;
			hDC*: User32.HDC;
			Flags*: SET;
			nFromPage*, nToPage*: INTEGER;
			nMinPage*, nMaxPage*: INTEGER;
			fill*: ARRAY 2+8*4 OF SYSTEM.BYTE
		END;

		(** The PAGESETUPDLG structure contains information the PageSetupDlg function uses to initialize the Page Setup
			dialog box. *)
		PAGESETUPDLG* = RECORD
			lStructSize*: LONGINT;
			hwndOwner*: User32.HWND;
			hDevMode*, hDevNames*: Kernel32.HGLOBAL;
			Flags*: SET;
			ptPaperSize*: User32.Point;
			rtMinMargin*, rtMargin*: User32.Rect;
			hInstance*: Kernel32.HINSTANCE;
			lCustData*: LONGINT;
			lpfnPageSetupHook*: ADDRESS;
			lpfnPagePaintHook*: ADDRESS;
			lpPageSetupTemplateName*: Kernel32.LPSTR;
			hPageSetupTemplate*: Kernel32.HANDLE
		END;

		(** The OPENFILENAME structure contains information that the GetOpenFileName and GetSaveFileName functions
			use to initialize an Open or Save As dialog box. *)
		OpenFileName* = RECORD
			lStructSize*: LONGINT;
			hwndOwner*: User32.HWND;
			hInstance*: Kernel32.HINSTANCE;
			lpstrFilter*, lpstrCustomFilter*: Kernel32.LPSTR;
			nMaxCustFilter*, nFilterIndex*: LONGINT;
			lpstrFile*: Kernel32.LPSTR;
			nMaxFile*: LONGINT;
			lpstrFileTitle*: Kernel32.LPSTR;
			nMaxFileTitle*: LONGINT;
			lpstrInitialDir*, lpstrTitle*: Kernel32.LPSTR;
			Flags*: LONGINT;								(* Dan *)
			nFileOffset*, nFileExtension*: INTEGER;
			lpstrDefExt*: Kernel32.LPSTR;
			lCustData*: User32.LParam;
			lpfnHook*: ADDRESS;
			lpTemplateName*: Kernel32.LPSTR
		END;

		(** The FINDREPLACE structure contains information that the FindText and ReplaceText functions use
			to initialize the Find and Replace common dialog boxes. *)
		FindReplace* = RECORD
			lStructSize*: LONGINT;
			hwndOwner*: User32.HWND;
			hInstance*: Kernel32.HINSTANCE;
			Flags*: SET;
			lpstrFindWhat*, lpstrReplaceWith*: Kernel32.LPSTR;
			wFindWhatLen*, wReplaceWithLen*: INTEGER;
			lCustData*: User32.LParam;
			lpfnHook*: ADDRESS;
			lpTemplateName*: Kernel32.LPSTR
		END;

	VAR
		(** The CommDlgExtendedError function returns a common dialog box error code. *)
		CommDlgExtendedError-: PROCEDURE {WINAPI} (): LONGINT;
		(** The FindText function creates a system-defined modeless Find dialog box that lets the user
			specify a string to search for and options to use when searching for text in a document. *)
		FindText-: PROCEDURE {WINAPI} (VAR lpfr: FindReplace): User32.HWND;
		(** The GetOpenFileName function creates an Open dialog box that lets the user specify the drive, directory, and the
			name of a file or set of files to open. *)
		GetOpenFileName-: PROCEDURE {WINAPI} (VAR lpofn: OpenFileName): Kernel32.BOOL;
		(** The GetSaveFileName function creates a Save dialog box that lets the user specify the drive, directory, and name
			of a file to save. *)
		GetSaveFileName-: PROCEDURE {WINAPI} (VAR lpofn: OpenFileName): Kernel32.BOOL;
		(** The PageSetupDlg function creates a Page Setup dialog box that enables the user to specify the attributes of a
			printed page. *)
		PageSetupDlg-: PROCEDURE {WINAPI} (VAR lppsd: PAGESETUPDLG): Kernel32.BOOL;
		(** The PrintDlg function displays a Print dialog box. *)
		PrintDlg-: PROCEDURE {WINAPI} (VAR lppd: PRINTDLG): Kernel32.BOOL;
		mod: Kernel32.HMODULE;
		(** The ReplaceText function creates a system-defined modeless dialog box that lets the user
			specify a string to search for and a replacement string, as well as options to control the find and
			replace operations. *)
		ReplaceText-: PROCEDURE {WINAPI} (VAR lpfr: FindReplace): User32.HWND;
		WMFindText-: LONGINT;
 		FindMsgString: ARRAY 32 OF CHAR;

	PROCEDURE InitAPI;
	VAR str : ARRAY 32 OF CHAR;
	BEGIN
		WMFindText := User32.RegisterWindowMessage(FindMsgString);
		str := "COMDLG32";
		mod := Kernel32.LoadLibrary(str);
		Kernel32.GetProcAddress(mod, "CommDlgExtendedError", SYSTEM.VAL(LONGINT, CommDlgExtendedError));
		Kernel32.GetProcAddress(mod, "FindTextA", SYSTEM.VAL(LONGINT, FindText));
		Kernel32.GetProcAddress(mod, "GetOpenFileNameA", SYSTEM.VAL(LONGINT, GetOpenFileName));
		Kernel32.GetProcAddress(mod, "GetSaveFileNameA", SYSTEM.VAL(LONGINT, GetSaveFileName));
		Kernel32.GetProcAddress(mod, "PageSetupDlgA", SYSTEM.VAL(LONGINT, PageSetupDlg));
		Kernel32.GetProcAddress(mod, "PrintDlgA", SYSTEM.VAL(LONGINT, PrintDlg));
		Kernel32.GetProcAddress(mod, "ReplaceTextA", SYSTEM.VAL(LONGINT,ReplaceText))
	END InitAPI;

	PROCEDURE FreeAPI;
	BEGIN
		Kernel32.FreeLibrary(mod); mod := Kernel32.NULL
	END FreeAPI;

BEGIN
	FindMsgString := "CommDlg_FindReplace"; (* fof *)
	InitAPI(); Modules.InstallTermHandler(FreeAPI);	(* Dan *)
	FindMsgString := "commdlg_FindReplace";
END COMDLG32.
