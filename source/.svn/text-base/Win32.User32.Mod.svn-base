(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE User32; (** non-portable / source: Win32.User32.Mod *)	(* ejz  *)
	IMPORT SYSTEM, Kernel32;

(** This module defines all the Win32 User32 APIs used by Oberon.
	Note this module is part of the Oberon inner-core and must be linked with PELinker. *)

	CONST
		(** window messages *)
		WMCreate* = 01H; WMDestroy* = 02H; WMMove* = 03H; WMSize* = 05H; WMActivate* = 06H; WMSetFocus* = 07H;
		WMKillFocus* = 08H; WMPaint* = 0FH; WMClose* = 010H; WMQuit* = 012H; WMSetCursor* = 020H;
		WMMouseActivate* = 021H; WMGetMinMaxInfo* = 024H; WMWindowPosChanging* = 046H;
		WMGetIcon* = 07FH; WMSetIcon* = 080H; WMNCHitTest* = 084H;
		WMKeyFirst* = 0100H;
		WMKeyDown* = 0100H; WMKeyUp* = 0101H; WMChar* = 0102H; WMDeadChar* = 0103H;
		WMSysKeyDown* = 0104H; WMSysKeyUp* = 0105H; WMSysChar* = 0106H; WMSysDeadChar* = 107H;
		WMKeyLast* = 0108H;
		WMCommand* = 0111H;
		WMMouseFirst* = 0200H; WMMouseMove* = 0200H; WMMouseLast* = 020DH;
		WMLButtonDown* = 0201H; WMLButtonUp* = 0202H;
		WMRButtonDown* = 0204H; WMRButtonUp* = 0205H;
		WMMButtonDown* = 0207H; WMMButtonUp* = 0208H;
		WMMouseWheel* = 020AH;
		WMXButtonDown* = 020BH; WMXButtonUp* = 020CH;

		WMDropFiles* = 0233H;
		WMCut* = 0300H; WMCopy* = 0301H; WMPaste* = 0302;
		WMClear* = 0303H; WMUndo* = 0304H;
		WMUser* = 0400H;

		(** WndClass style values *)
		CSVRedraw* = 0; CSHRedraw* = 1; CSOwnDC* = 5; CSSaveBits* = 11; CSGlobalClass* = 14;

		(** CreateWindow dwStyle values *)
		WSMaximizeBox* = 16; WSMinimizeBox* = 17; WSThickFrame* = 18; WSSysMenu* = 19; WSBorder* = 23;
		WSMaximize* = 24; WSVisible* = 28; WSMinimize* = 29; WSChild* = 30;

		(** CreateWindow default value for x, y, nWidth, nHeight *)
		CWUseDefault* = LONGINT(080000000H);

		(** WMSize wParam values *)
		SizeRestored* = 0; SizeMinimized* = 1; SizeMaximized* = 2; SizeMaxshow* = 3; SizeMaxhide* = 4;

		(** WMActivate LoWord(wParam) values *)
		WAInactive* = 0; WAActive* = 1; WAClickActive* = 2;

		(** WMmouseActivate return codes *)
		MAActivate* = 1; MANoActivate* = 3;

		(** GetSystemMetrics nIndex values *)
		SMCXScreen* = 0; SMCYScreen* = 1; SMCYCaption* = 4;
		SMCXDlgFrame* = 7; SMCYDlgFrame* = 8;
		SMCXFixedFrame* = SMCXDlgFrame; SMCYFixedFrame* = SMCYDlgFrame;
		SMCYMenu* = 15; SMCXFrame* = 32; SMCYFrame* = 33;
		SMCMouseButtons* = 43;

		(** Predefined HWND values *)
		HWNDDesktop* = 0; HWNDBroadcast* = 0FFFFH;

		(** virtual key codes *)
		VKCancel* = 03H; VKBack* = 08H; VKTab * = 09H; VKClear* = 0CH; VKReturn* = 0DH;
		VKShift* = 010H; VKControl* = 011H; VKMenu* = 012H;
		VKPause* = 013H; VKCapital* = 014H; VKEscape* = 01BH;
		VKPrior* = 021H; VKNext* = 022H; VKEnd* = 023H; VKHome* = 024H;
		VKLeft* = 025H; VKUp* = 026H; VKRight* = 027H; VKDown* = 028H;
		VKSelect* = 029H; VKPrint* = 02AH; VKExecute* = 02BH; VKSnapshot* = 02CH;
		VKInsert* = 02DH; VKDelete* = 02EH; VKHelp* = 02FH;
		VKLWin* = 05BH; VKRWin* = 05CH; VKApps* = 05DH;
		VKF1* = 070H; VKF2* = 071H; VKF3* = 072H; VKF4* = 073H;
		VKF5* = 074H; VKF6* = 075H; VKF7* = 076H; VKF8* = 077H;
		VKF9* = 078H; VKF10* = 079H; VKF11* = 07AH; VKF12* = 07BH;

		(** WMMouse... wParam values *)
		MKLButton* = 0; MKRButton* = 1; MKShift* = 2; MKControl* = 3; MKMButton* = 4;

		(** predefined cursors/icons fo LoadCursor/LoadIcon *)
		IDCArrow* = 32512; IDCWait* = 32514;

		(** WMNCHitTest return values *)
		HTClient* = 1;

		(** ShowWindow nCmdShow values *)
		SWHide* = 0; SWShow* = 5;
		SWNormal* = 1; SWShowNormal* = 1;
		SWMinimize* = 6; SWShowMinimized* = 2;
		SWMaximize* = 3; SWShowMaximized* = 3;
		SWRestore* = 9;
		SWShowDefault* = 10;

		(** SetWindowPos uFlags values *)
		SWPNoSize* = 0; SWPNoMove* = 1; SWPNoZOrder* = 2; SWPNoRedraw* = 3; SWPNoActivate* = 4;
		SWPFrameChanged* = 5; SWPShowWindow* = 6; SWPHideWindow* = 7;

		(** clipboard formats *)
		CFText* = 1; CFBitmap* = 2; CFMetafilePict* = 3; CFDIB* = 8; CFEnhMetafile* = 14; CFHDrop* = 15;

		(** InsertMenu uFlags values *)
		MFByCommand* = {}; MFByPosition* = 10;
		MFPopup* = 4; MFSeparator* = 11;
		MFEnabled* = {}; MFGrayed * = 0; MFDisabled* = 1;
		MFUnchecked* = {}; MFChecked* = 3;
		MFString* = {};

		(** MenuItemInfo fMask values *)
		MIIMID* = 1; MIIMType* = 4;

		(** WMSetIcon wPaam values *)
		IconSmall* = 0; IconBig* = 1;

		(** GetWindowLong/SetWindowLong nIndex values *)
		GWLWndProc* = -4; GWLStyle* = - 16; GWLExStyle* = -20;

		(** MessageBox uType values *)
		MBOk* = {}; MBOkCancel* = {0}; MBAbortRetryIgnore* = {1};
		MBYesNoCancel* = {0, 1}; MBYesNo* = {2}; MBRetryCancel* = {0, 2};
		MBIconHand* = {4}; MBIconQuestion* = {5}; MBIconExclamation* = {4, 5}; MBIconAsterisk* = {6};
		MBIconWarning* = MBIconExclamation; MBIconError* = MBIconHand;
		MBIconInformation* = MBIconAsterisk; MBIconStop* = MBIconHand;

		(** TrackPopupMenu uFlags values *)
		TPMLeftButton* = {}; TPMRightButton* = 1;
		TPMLeftAlign* = {}; TPMCenterAlign* = 2; TPMRightAlign* = 3;
		TPMTopAlign* = {}; TPMVCenterAlign* = 4; TPMBottomAlign* = 5;
		TPMHorizontal* = {}; TPMVertical* = 6;
		TPMNoNotify* = 7; TPMReturnCmd* = 8;

		(** SetWindowsHookEx idHook values *)
		WHKeyboard* = 2;

		(** GetSysColor *)
		ColorWindow* = 5;
		ColorWindowText* = 8;
		ColorBtnFace* = 15;
		ColorBtnShadow* = 16;
		Color3DLight* = 22;
		Color3DFace* = ColorBtnFace;
		Color3DShadow* = ColorBtnShadow;

	TYPE
		(** handle types for different win and gdi objects *)
		HWND* = Kernel32.HANDLE;
		HDC* = Kernel32.HANDLE;
		HGDIObj* = Kernel32.HANDLE;
		HFont* = HGDIObj;
		HBrush* = HGDIObj;
		HRgn* = HGDIObj;
		HBitmap* = HGDIObj;
		HIcon* = Kernel32.HANDLE;
		HCursor* = Kernel32.HANDLE;
		HMenu* = Kernel32.HANDLE;
		HPalette* = Kernel32.HANDLE;
		HAccel* = Kernel32.HANDLE;
		HHook* = Kernel32.HANDLE;

		(** The COLORREF value is used to specify an RGB color. *)
		ColorRef* = LONGINT;

		(** The POINT structure defines the x- and y- coordinates of a point. *)
		Point* = RECORD
			x*, y*: LONGINT
		END;
		PointL* = Point;
		PointF* = RECORD
			x*, y*: REAL
		END;

		(** The RECT structure defines the coordinates of the upper-left and lower-right corners of a rectangle. *)
		Rect* = RECORD
			left*, top*, right*, bottom*: LONGINT
		END;
		RectL* = Rect;

		(** The SIZE structure specifies the width and height of a rectangle. *)
		Size* = RECORD
			cx*, cy*: LONGINT
		END;
		SizeL* = Size;

		(** The MINMAXINFO structure contains information about a window's maximized size and position and its minimum
			and maximum tracking size. *)
		MinMaxInfo* = RECORD
			ptReserved*, ptMaxSize*, ptMaxPosition*, ptMinTrackSize*, ptMaxTrackSize*: Point
		END;

		(** The MSG structure contains message information from a thread's message queue. *)
		Msg* = RECORD  			hwnd*: HWND;
			message*: LONGINT;
			wParam*, lParam*: LONGINT;
			time*: LONGINT;
			point*: Point
		END;

		(** A 32-bit value passed as a parameter to a window procedure or callback function. *)
		WParam* = LONGINT; LParam* = LONGINT;

		(** A 32-bit value returned from a window procedure or callback function. *)
		LResult* = LONGINT;

		(** A 32-bit pointer to a window procedure. *)
		WndProc* = PROCEDURE {WINAPI} (hwnd: HWND; uMsg: LONGINT; wParam: WParam; lParam: LParam): LResult;

		(** The WNDCLASSEX structure contains window class information. It is used with the RegisterClassEx and
			GetClassInfoEx functions. *)
		WndClassEx* = RECORD
			cbSize*: LONGINT;
			style*: SET;
			lpfnWndProc*: WndProc;
			cbClsExtra*, cbWndExtra*: LONGINT;
			hInstance*: Kernel32.HINSTANCE;
			hIcon*: HIcon;
			hCursor*: HCursor;
			hbrBackground*: HBrush;
			lpszMenuName*, lpszClassName*: Kernel32.LPSTR;
			hIconSm*: HIcon
		END;

		(** Application-defined callback function used with the EnumWindows. *)
		WndEnumProc* = PROCEDURE {WINAPI} (hwnd: HWND; lParam: LParam): Kernel32.BOOL;

		(** The WINDOWPOS structure contains information about the size and position of a window. *)
		WindowPos* = RECORD  			hwnd*, hwndInsertAfter*: HWND;
			x*, y*, cx*, cy*: LONGINT;
			flags*: SET
		END;

		(** The WINDOWPLACEMENT structure contains information about the placement of a window on the screen. *)
		WindowPlacement* = RECORD
			length*: LONGINT;
			flags*: SET;
			showCmd*: LONGINT;
			ptMinPosition*, ptMaxPosition*: Point;
			rcNormalPosition*: Rect
		END;

		(** The MENUITEMINFO structure contains information about a menu item. *)
		MenuItemInfo* = RECORD  			cbSize*: LONGINT;
			fMask*, fType*, fState*: SET;
			wID*: LONGINT;
			hSubMenu*: HMenu;
			hbmpChecked*, hbmpUnchecked*: HBitmap;
			dwItemData*: LONGINT;
			dwTypeData*: Kernel32.LPSTR;
			cch*: LONGINT
		END;

		(** The ACCEL structure defines an accelerator key used in an accelerator table. *)
		Accel* = RECORD  			fVirt*: CHAR;
			key*, cmd*: INTEGER
		END;

		(** Proctype for SetWindowsHook(Ex) *)
		HookProc* = PROCEDURE {WINAPI} (code: LONGINT; wParam: WParam; lParam: LParam): LResult;

		PaintStruct* = RECORD
			hdc*: HDC;
		    fErase*: Kernel32.BOOL;
		    rcPaint*: Rect;
		    fRestore, fIncUpdate: Kernel32.BOOL;
		    rgbReserved: ARRAY 32 OF CHAR
		END;

	VAR
		(** The BeginPaint function prepares the specified window for painting and fills a PAINTSTRUCT
			structure with information about the painting. *)
		BeginPaint-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpPaint: PaintStruct): HDC;
		(** The BringWindowToTop function brings the specified window to the top of the Z order. *)
		BringWindowToTop-: PROCEDURE {WINAPI} (hWnd: HWND): Kernel32.BOOL;
		(** The CallNextHookEx function passes the hook information to the next hook procedure in the current hook chain. *)
		CallNextHookEx-: PROCEDURE {WINAPI} (hhk: HHook; nCode: LONGINT; wParam: WParam; lParam: LParam): LResult;
		(** The CloseClipboard function closes the clipboard. *)
		CloseClipboard-: PROCEDURE {WINAPI} (): Kernel32.BOOL;
		(** The CreateAcceleratorTable function creates an accelerator table. *)
		CreateAcceleratorTable-: PROCEDURE {WINAPI} (lpaccl: ADDRESS; cEntries: LONGINT): HAccel;
		(** The CreateMenu function creates a menu. *)
		CreateMenu-: PROCEDURE {WINAPI} (): HMenu;
		(** The CreateWindow function creates an overlapped, pop-up, or child window. *)
		CreateWindowEx-: PROCEDURE {WINAPI} (dwExStyle: LONGINT; VAR lpClassName, lpWindowName: ARRAY   OF CHAR; dwStyle: SET; x, y, nWidth, nHeight: LONGINT; hWndParent: HWND; hMenu: HMenu; hInstance: Kernel32.HINSTANCE; lpParam: LONGINT): HWND;
		(** The DefWindowProc function calls the default window procedure to provide default processing for any window
			messages that an application does not process. *)
		DefWindowProc-: WndProc;
		(** The DestroyAcceleratorTable function destroys an accelerator table. *)
		DestroyAcceleratorTable-: PROCEDURE {WINAPI} (hAccel: HAccel): Kernel32.BOOL;
		(** The DestroyCursor function destroys a cursor and frees any memory the cursor occupied. *)
		DestroyCursor-: PROCEDURE {WINAPI} (hCursor: HCursor): Kernel32.BOOL;
		(** The DestroyIcon function destroys an icon and frees any memory the icon occupied. *)
		DestroyIcon-: PROCEDURE {WINAPI} (hIcon: HIcon): Kernel32.BOOL;
		(** The DestroyMenu function destroys the specified menu and frees any memory that the menu occupies. *)
		DestroyMenu-: PROCEDURE {WINAPI} (hMenu: HMenu): Kernel32.BOOL;
		(** The DestroyWindow function destroys the specified window. *)
		DestroyWindow-: PROCEDURE {WINAPI} (hWnd: HWND): Kernel32.BOOL;
		(** The DispatchMessage function dispatches a message to a window procedure. *)
		DispatchMessage-: PROCEDURE {WINAPI} (VAR lpMsg: Msg): LONGINT;
		(** The DrawMenuBar function redraws the menu bar of the specified window. *)
		DrawMenuBar-: PROCEDURE {WINAPI} (hWnd: HWND): Kernel32.BOOL;
		(** The EmptyClipboard function empties the clipboard and frees handles to data in the clipboard. *)
		EmptyClipboard-: PROCEDURE {WINAPI} (): Kernel32.BOOL;
		(** The EnableWindow function enables or disables mouse and keyboard input to the specified window or control. *)
		EnableWindow-: PROCEDURE {WINAPI} (hWnd: HWND; bEnable: Kernel32.BOOL): Kernel32.BOOL;
		(** The EndPaint function marks the end of painting in the specified window. *)
		EndPaint-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpPaint: PaintStruct): Kernel32.BOOL;
		(** The EnumWindows function enumerates all top-level windows on the screen by passing the handle to each
			window, in turn, to an application-defined callback function. *)
		EnumWindows-: PROCEDURE {WINAPI} (lpEnumProc: WndEnumProc; lParam: LParam): Kernel32.BOOL;
		(** The EqualRect function determines whether the two specified rectangles are equal by comparing the coordinates
			of their upper-left and lower-right corners. *)
		EqualRect-: PROCEDURE {WINAPI} (lprc1, lprc2: Rect): Kernel32.BOOL;
		(** The GetAsyncKeyState function determines whether a key is up or down at the time the function is called, and
			whether the key was pressed after a previous call to GetAsyncKeyState. *)
		GetAsyncKeyState-: PROCEDURE {WINAPI} (vKey: LONGINT): INTEGER;
		(** The GetClientRect function retrieves the coordinates of a window's client area. *)
		GetClientRect-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpRect: Rect): Kernel32.BOOL;
		(** The GetClipboardData function retrieves data from the clipboard in a specified format. *)
		GetClipboardData-: PROCEDURE {WINAPI} (uFormat: LONGINT): Kernel32.HANDLE;
		(** The GetClipboardFormatName function retrieves from the clipboard the name of the specified registered format. *)
		GetClipboardFormatName-: PROCEDURE {WINAPI} (format: LONGINT; VAR lpszFormatName: ARRAY   OF CHAR; cchMaxCount: LONGINT): LONGINT;
		(** The GetCursorPos function retrieves the cursor's position, in screen coordinates. *)
		GetCursorPos-: PROCEDURE {WINAPI} (VAR lpPoint: Point): Kernel32.BOOL;
		(** The GetDC function retrieves a handle to a display device context (DC) for the client area of a specified window
			or for the entire screen. *)
		GetDC-: PROCEDURE {WINAPI} (hWnd: HWND): HDC;
		(** The GetFocus function retrieves the handle to the window that has the keyboard focus, if the window is attached
			to the calling thread's message queue. *)
		GetFocus-: PROCEDURE {WINAPI} (): HWND;
		(** Retrieves a handle to the foreground window (the window with which the user is currently working). The system assigns a slightly higher priority to the thread that creates the foreground window than it does to other threads.  *)
		GetForegroundWindow-: PROCEDURE {WINAPI} (): HWND;
		(** The GetKeyState function retrieves the status of the specified virtual key. *)
		GetKeyState-: PROCEDURE {WINAPI} (vKey: LONGINT): INTEGER;
		(** The GetMenu function retrieves a handle to the menu assigned to the specified window. *)
		GetMenu-: PROCEDURE {WINAPI} (hWnd: HWND): HMenu;
		(** The GetMenuItemInfo function retrieves information about a menu item. *)
		GetMenuItemInfo-: PROCEDURE {WINAPI} (hMenu: HMenu; uItem: LONGINT; fyByPosition: Kernel32.BOOL; VAR lpmii: MenuItemInfo): Kernel32.BOOL;
		(** The GetMenuString function copies the text string of the specified menu item into the specified buffer. *)
		GetMenuString-: PROCEDURE {WINAPI} (hMenu: HMenu; uIDItem: LONGINT; VAR lpString: ARRAY   OF CHAR; nMaxCount: LONGINT; uFlag: SET): Kernel32.BOOL;
		(** The GetMessage function retrieves a message from the calling thread's message queue and places it in the
			specified structure. *)
		GetMessage-: PROCEDURE {WINAPI} (VAR lpMsg: Msg; hWnd: HWND; wMsgFilterMin, wMsgFilterMax: LONGINT): LONGINT;
		(** The GetParent function retrieves a handle to the specified child window's parent window. *)
		GetParent-: PROCEDURE {WINAPI} (hWnd: HWND): HWND;
		(** The GetProp function retrieves a data handle from the property list of the given window. *)
		GetProp-: PROCEDURE {WINAPI} (hWnd: HWND; lpString: LONGINT): LONGINT;
		(** The GetSystemMetrics function retrieves various system metrics (widths and heights of display elements) and
			system configuration settings. *)
		(** The GetSysColor function retrieves the current color of the specified display element. *)
		GetSysColor-: PROCEDURE {WINAPI} (nIndex: LONGINT): ColorRef;
		(** The GetSystemMetrics function retrieves various system metrics (widths and heights of display elements)
			and system configuration settings. *)
		GetSystemMetrics-: PROCEDURE {WINAPI} (nIndex: LONGINT): LONGINT;
		(** The GetWindowLong function retrieves information about the specified window. *)
		GetWindowLong-: PROCEDURE {WINAPI} (hWnd: HWND; nIndex: LONGINT): LONGINT;
		(** The GetWindowPlacement function retrieves the show state and the restored, minimized, and maximized
			positions of the specified window. *)
		GetWindowPlacement-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpwndpl: WindowPlacement): Kernel32.BOOL;
		(** The GetWindowRect function retrieves the dimensions of the bounding rectangle of the specified window. *)
		GetWindowRect-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpRect: Rect): Kernel32.BOOL;
		(** The GetWindowRgn function obtains a copy of the window region of a window. *)
		GetWindowRgn-: PROCEDURE {WINAPI} (hWnd: HWND; VAR hRgn: HRgn): LONGINT;
		(** The GetWindowText function copies the text of the specified window's title bar (if it has one) into a buffer. *)
		GetWindowText-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpString: ARRAY   OF CHAR; nMaxCount: LONGINT): LONGINT;
		(** The GetUpdateRect function retrieves the coordinates of the smallest rectangle that completely encloses the
			update region of the specified window. *)
		GetUpdateRect-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpRect: Rect; bErase: Kernel32.BOOL): Kernel32.BOOL;
		(** The GetUpdateRgn function retrieves the update region of a window by copying it into the specified
			region. *)
		GetUpdateRgn-: PROCEDURE {WINAPI} (hWnd: HWND; VAR hRgn: HRgn; bErase: Kernel32.BOOL): LONGINT;
		(** The InsertMenu function inserts a new menu item into a menu, moving other items down the menu. *)
		InsertMenu-: PROCEDURE {WINAPI} (hMenu: HMenu; uPosition: LONGINT; uFlags: SET; uIDNewItem: LONGINT; VAR lpNewItem: ARRAY   OF CHAR): Kernel32.BOOL;
		(** The IntersectRect function calculates the intersection of two source rectangles and places the coordinates of the
			intersection rectangle into the destination rectangle. *)
		IntersectRect-: PROCEDURE {WINAPI} (VAR lprcDst: Rect; lprcSrc1, lprcSrc2: Rect): Kernel32.BOOL;
		(** The InvalidateRect function adds a rectangle to the specified window's update region. *)
		InvalidateRect-: PROCEDURE {WINAPI} (hWnd: HWND; lpRect: Rect; bErase: Kernel32.BOOL): Kernel32.BOOL;
		(** The IsChild function tests whether a window is a child window or descendant window of a specified parent window. *)
		IsChild-: PROCEDURE {WINAPI} (hWndParent, hWnd: HWND): Kernel32.BOOL;
		(** The LoadCursor function loads the specified cursor resource from the executable (.EXE) file associated with
			an application instance. *)
		LoadCursor-: PROCEDURE {WINAPI} (hInstance: Kernel32.HINSTANCE; VAR lpCursorName: ARRAY   OF CHAR): HCursor;
		(** The LoadCursorFromFile function creates a cursor based on data contained in a file. *)
		LoadCursorFromFile-: PROCEDURE {WINAPI} (VAR lpFileName: ARRAY   OF CHAR): HCursor;
		(** The LoadIcon function loads the specified icon resource from the executable (.exe) file associated with an
			application instance. *)
		LoadIcon-: PROCEDURE {WINAPI} (hInstance: Kernel32.HINSTANCE; VAR lpIconName: ARRAY   OF CHAR): HIcon;
		(** The MessageBeep function plays a waveform sound. *)
		MessageBeep-: PROCEDURE {WINAPI} (uType: LONGINT): Kernel32.BOOL;
		(** The MessageBox function creates, displays, and operates a message box. *)
		MessageBox-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpText, lpCaption: ARRAY   OF CHAR; uType: SET): LONGINT;
		(** The MoveWindow function changes the position and dimensions of the specified window. *)
		MoveWindow-: PROCEDURE {WINAPI} (hWnd: HWND; X, Y, nWidth, nHeight: LONGINT; bRepaint: Kernel32.BOOL): Kernel32.BOOL;
		(** The OffsetRect function moves the specified rectangle by the specified offsets. *)
		OffsetRect-: PROCEDURE {WINAPI} (VAR lprc: Rect; dx, dy: LONGINT): Kernel32.BOOL;
		(** The OpenClipboard function opens the clipboard for examination and prevents other applications from modifying
			the clipboard content. *)
		OpenClipboard-: PROCEDURE {WINAPI} (hWndNewOwner: HWND): Kernel32.BOOL;
		(** The PtInRect function determines whether the specified point lies within the specified rectangle. *)
		PtInRect-: PROCEDURE {WINAPI} (lprc: Rect; ptx, pty: LONGINT): Kernel32.BOOL;
		(** The PostMessage function places (posts) a message in the message queue associated with the thread that created
			the specified window and then returns without waiting for the thread to process the message. *)
		PostMessage-: PROCEDURE {WINAPI} (hWnd: HWND; Msg: LONGINT; wParam: WParam; lParam: LParam): Kernel32.BOOL;
		(** The PostQuitMessage function indicates to the system that a thread has made a request to terminate (quit). *)
		PostQuitMessage-: PROCEDURE {WINAPI} (nExitCode: LONGINT);
		(** The RegisterClassEx function registers a window class for subsequent use in calls to the CreateWindow or
			CreateWindowEx function. *)
		RegisterClassEx-: PROCEDURE {WINAPI} (VAR lpwcx: WndClassEx): Kernel32.ATOM;
		(** The RegisterClipboardFormat function registers a new clipboard format. *)
		RegisterHotKey-: PROCEDURE{WINAPI} (hWnd: HWND; id: LONGINT; fsmodifiers,vk: LONGINT): Kernel32.BOOL;
		(*The RegisterHotKey function defines a system-wide hot key *)
		RegisterClipboardFormat-: PROCEDURE {WINAPI} (VAR lpszFormat: ARRAY   OF CHAR): INTEGER;
		(** The RegisterWindowMessage function defines a new window message that is guaranteed to be
			unique throughout the system. *)
		RegisterWindowMessage-: PROCEDURE {WINAPI} (VAR lpString: ARRAY   OF CHAR): LONGINT;
		(** The ReleaseCapture function releases the mouse capture from a window in the current thread and restores normal
			mouse input processing. *)
		ReleaseCapture-: PROCEDURE {WINAPI} (): Kernel32.BOOL;
		(** The ReleaseDC function releases a device context (DC), freeing it for use by other applications. *)
		ReleaseDC-: PROCEDURE {WINAPI} (hWnd: HWND; hDC: HDC): LONGINT;
		(** The RemoveProp function removes an entry from the property list of the specified window. *)
		RemoveProp-: PROCEDURE {WINAPI} (hWnd: HWND; lpString: LONGINT): LONGINT;
		(** The ScreenToClient function converts the screen coordinates of a specified point on the screen to client coordinates. *)
		ScreenToClient-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpPoint: Point): Kernel32.BOOL;
		(** The SendMessage function sends the specified message to a window or windows. *)
		SendMessage-: PROCEDURE {WINAPI} (hWnd: HWND; Msg: LONGINT; wParam: WParam; lParam: LParam): LResult;
		(** The SetCapture function sets the mouse capture to the specified window belonging to the current thread. *)
		SetCapture-: PROCEDURE {WINAPI} (hWnd: HWND): HWND;
		(** The SetClipboardData function places data on the clipboard in a specified clipboard format. *)
		SetClipboardData-: PROCEDURE {WINAPI} (uFormat: LONGINT; hMem: Kernel32.HANDLE): Kernel32.HANDLE;
		(** The SetCursor function establishes the cursor shape. *)
		SetCursor-: PROCEDURE {WINAPI} (hCursor: HCursor): HCursor;
		(** The SetCursorPos function moves the cursor to the specified screen coordinates. *)
		SetCursorPos-: PROCEDURE {WINAPI} (X, Y: LONGINT): Kernel32.BOOL;
		(** The SetFocus function sets the keyboard focus to the specified window. *)
		SetFocus-: PROCEDURE {WINAPI} (hWnd: HWND): HWND;
		(** The SetForegroundWindow function puts the thread that created the specified window into the foreground
			and activates the window. *)
		SetForegroundWindow-: PROCEDURE {WINAPI} (hWnd: HWND): Kernel32.BOOL;
		(** The SetMenu function assigns a new menu to the specified window. *)
		SetMenu-: PROCEDURE {WINAPI} (hWnd: HWND; hMenu: HMenu): Kernel32.BOOL;
		(** The SetMenuItemInfo function changes information about a menu item. *)
		SetMenuItemInfo-: PROCEDURE {WINAPI} (hMenu: HMenu; uItem: LONGINT; fyByPosition: Kernel32.BOOL; VAR lpmii: MenuItemInfo): Kernel32.BOOL;
		(** The SetProp function adds a new entry or changes an existing entry in the property list of the specified window. *)
		SetProp-: PROCEDURE {WINAPI} (hWnd: HWND; lpString, hData: LONGINT): Kernel32.BOOL;
		(** The SetWindowsHookEx function installs an application-defined hook procedure into a hook chain. *)
		SetWindowsHookEx-: PROCEDURE {WINAPI} (idHook: LONGINT; lpfn: HookProc; hMod: Kernel32.HINSTANCE; dwThreadId: LONGINT): HHook;
		(** The SetWindowLong function changes an attribute of the specified window. *)
		SetWindowLong-: PROCEDURE {WINAPI} (hWnd: HWND; nIndex, dwNewLong: LONGINT): LONGINT;
		(** The SetWindowPos function changes the size, position, and Z order of a child, pop-up, or top-level window. *)
		SetWindowPos-: PROCEDURE {WINAPI} (hWnd, hWndInsertAfter: HWND; X, Y, cx, cy: LONGINT; uFlags: SET): Kernel32.BOOL;
		(** The SetWindowRgn function sets the window region of a window. *)
		SetWindowRgn-: PROCEDURE {WINAPI} (hWnd: HWND; hRgn: HRgn; bRedraw: Kernel32.BOOL): LONGINT;
		(** The SetWindowText function changes the text of the specified window's title bar (if it has one). *)
		SetWindowText-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpString: ARRAY   OF CHAR): Kernel32.BOOL;
		(** The ShowCursor function displays or hides the cursor. *)
		ShowCursor-: PROCEDURE {WINAPI} (bShow: Kernel32.BOOL): LONGINT;
		(** The ShowWindow function sets the specified window's show state. *)
		ShowWindow-: PROCEDURE {WINAPI} (hWnd: HWND; nCmdShow: LONGINT): Kernel32.BOOL;
		(** The ShowWindowAsync function sets the show state of a window created by a different thread. *)
		ShowWindowAsync-: PROCEDURE {WINAPI} (hWnd: HWND; nCmdShow: LONGINT): Kernel32.BOOL;
		(** The TrackPopupMenu function displays a shortcut menu at the specified location and tracks the selection of
			items on the menu. *)
		TrackPopupMenu-: PROCEDURE {WINAPI} (hMenu: HMenu; uFlags: SET; x, y, nReserved: LONGINT; hWnd: HWND; VAR prcRect: Rect): Kernel32.BOOL;
		(** The TranslateAccelerator function processes accelerator keys for menu commands. *)
		TranslateAccelerator-: PROCEDURE {WINAPI} (hWnd: HWND; hAccTable: HAccel; VAR lpMsg: Msg): LONGINT;
		(** The TranslateMessage function translates virtual-key messages into character messages. *)
		TranslateMessage-: PROCEDURE {WINAPI} (VAR lpMsg: Msg): Kernel32.BOOL;
		(** The UnhookWindowsHookEx function removes a hook procedure installed in a hook chain by the SetWindowsHookEx
			function. *)
		UnhookWindowsHookEx-: PROCEDURE {WINAPI} (hhk: HHook): Kernel32.BOOL;
		(** The UnregisterClass function removes a window class, freeing the memory required for the class. *)
		UnregisterClass-: PROCEDURE {WINAPI} (VAR lpClassName: ARRAY   OF CHAR; hInstance: Kernel32.HINSTANCE): Kernel32.BOOL;
		(** The UpdateWindow function updates the client area of the specified window by sending a WM_PAINT message
			to the window if the window's update region is not empty. *)
		UpdateWindow-: PROCEDURE {WINAPI} (hWnd: HWND): Kernel32.BOOL;
		(** The ValidateRect function validates the client area within a rectangle by removing the rectangle from the
			update region of the specified window. *)
		ValidateRect-: PROCEDURE {WINAPI} (hWnd: HWND; VAR lpRect: Rect): Kernel32.BOOL;

		GetConsoleWindow-: PROCEDURE{WINAPI} (): LONGINT ;


	(** The EqualSize function determines whether the two specified sizes are equal. *)
	PROCEDURE {WINAPI} EqualSize*(VAR a, b: Size): BOOLEAN;
	BEGIN
		RETURN (a.cx = b.cx) & (a.cy = b.cy)
	END EqualSize;

PROCEDURE Init;
VAR mod: Kernel32.HMODULE; str: ARRAY 32 OF CHAR;
BEGIN
	str := "KERNEL32.DLL";
	mod := Kernel32.LoadLibrary(str);
	Kernel32.GetProcAddress(mod, "GetConsoleWindow", SYSTEM.VAL(ADDRESS, GetConsoleWindow));
	(* the GetConsoleWindow function is not available for version minor Win2000, that's why it is set dynamically here *)
	str := "USER32.DLL";
	mod := Kernel32.LoadLibrary(str);
	Kernel32.GetProcAddress(mod, "BeginPaint", SYSTEM.VAL(ADDRESS,BeginPaint ));
	Kernel32.GetProcAddress(mod, "BringWindowToTop", SYSTEM.VAL(ADDRESS,BringWindowToTop ));
	Kernel32.GetProcAddress(mod, "CallNextHookEx", SYSTEM.VAL(ADDRESS,CallNextHookEx ));
	Kernel32.GetProcAddress(mod, "CloseClipboard", SYSTEM.VAL(ADDRESS,CloseClipboard ));
	Kernel32.GetProcAddress(mod, "CreateAcceleratorTableA", SYSTEM.VAL(ADDRESS,CreateAcceleratorTable ));
	Kernel32.GetProcAddress(mod, "CreateMenu", SYSTEM.VAL(ADDRESS,CreateMenu ));
	Kernel32.GetProcAddress(mod, "CreateWindowExA", SYSTEM.VAL(ADDRESS,CreateWindowEx ));
	Kernel32.GetProcAddress(mod, "DefWindowProcA", SYSTEM.VAL(ADDRESS,DefWindowProc ));
	Kernel32.GetProcAddress(mod, "DestroyAcceleratorTable", SYSTEM.VAL(ADDRESS,DestroyAcceleratorTable ));
	Kernel32.GetProcAddress(mod, "DestroyMenu", SYSTEM.VAL(ADDRESS,DestroyMenu ));
	Kernel32.GetProcAddress(mod, "DestroyWindow", SYSTEM.VAL(ADDRESS,DestroyWindow ));
	Kernel32.GetProcAddress(mod, "DispatchMessageA", SYSTEM.VAL(ADDRESS,DispatchMessage ));
	Kernel32.GetProcAddress(mod, "DrawMenuBar", SYSTEM.VAL(ADDRESS,DrawMenuBar ));
	Kernel32.GetProcAddress(mod, "EmptyClipboard", SYSTEM.VAL(ADDRESS,EmptyClipboard ));
	Kernel32.GetProcAddress(mod, "EnableWindow", SYSTEM.VAL(ADDRESS,EnableWindow ));
	Kernel32.GetProcAddress(mod, "EndPaint", SYSTEM.VAL(ADDRESS,EndPaint ));
	Kernel32.GetProcAddress(mod, "EnumWindows", SYSTEM.VAL(ADDRESS,EnumWindows ));
	Kernel32.GetProcAddress(mod, "EqualRect", SYSTEM.VAL(ADDRESS,EqualRect ));
	Kernel32.GetProcAddress(mod, "GetAsyncKeyState", SYSTEM.VAL(ADDRESS,GetAsyncKeyState ));
	Kernel32.GetProcAddress(mod, "GetClientRect", SYSTEM.VAL(ADDRESS,GetClientRect ));
	Kernel32.GetProcAddress(mod, "GetClipboardData", SYSTEM.VAL(ADDRESS,GetClipboardData ));
	Kernel32.GetProcAddress(mod, "GetClipboardFormatNameA", SYSTEM.VAL(ADDRESS,GetClipboardFormatName));
	Kernel32.GetProcAddress(mod, "GetCursorPos", SYSTEM.VAL(ADDRESS,GetCursorPos ));
	Kernel32.GetProcAddress(mod, "GetDC", SYSTEM.VAL(ADDRESS,GetDC ));
	Kernel32.GetProcAddress(mod, "GetFocus", SYSTEM.VAL(ADDRESS,GetFocus ));
	Kernel32.GetProcAddress(mod, "GetForegroundWindow", SYSTEM.VAL(ADDRESS,GetForegroundWindow ));
	Kernel32.GetProcAddress(mod, "GetKeyState", SYSTEM.VAL(ADDRESS,GetKeyState ));
	Kernel32.GetProcAddress(mod, "GetMenu", SYSTEM.VAL(ADDRESS,GetMenu ));
	Kernel32.GetProcAddress(mod, "GetMenuItemInfoA", SYSTEM.VAL(ADDRESS,GetMenuItemInfo ));
	Kernel32.GetProcAddress(mod, "GetMenuStringA", SYSTEM.VAL(ADDRESS,GetMenuString ));
	Kernel32.GetProcAddress(mod, "GetMessageA", SYSTEM.VAL(ADDRESS,GetMessage ));
	Kernel32.GetProcAddress(mod, "GetParent", SYSTEM.VAL(ADDRESS,GetParent ));
	Kernel32.GetProcAddress(mod, "GetPropA", SYSTEM.VAL(ADDRESS,GetProp ));
	Kernel32.GetProcAddress(mod, "GetSysColor", SYSTEM.VAL(ADDRESS,GetSysColor ));
	Kernel32.GetProcAddress(mod, "GetSystemMetrics", SYSTEM.VAL(ADDRESS,GetSystemMetrics ));
	Kernel32.GetProcAddress(mod, "GetWindowLongA", SYSTEM.VAL(ADDRESS,GetWindowLong ));
	Kernel32.GetProcAddress(mod, "GetWindowPlacement", SYSTEM.VAL(ADDRESS,GetWindowPlacement ));
	Kernel32.GetProcAddress(mod, "GetWindowRect", SYSTEM.VAL(ADDRESS,GetWindowRect ));
	Kernel32.GetProcAddress(mod, "GetWindowRgn", SYSTEM.VAL(ADDRESS,GetWindowRgn ));
	Kernel32.GetProcAddress(mod, "GetWindowTextA", SYSTEM.VAL(ADDRESS,GetWindowText ));
	Kernel32.GetProcAddress(mod, "GetUpdateRect", SYSTEM.VAL(ADDRESS,GetUpdateRect ));
	Kernel32.GetProcAddress(mod, "GetUpdateRgn", SYSTEM.VAL(ADDRESS,GetUpdateRgn ));
	Kernel32.GetProcAddress(mod, "InvalidateRect", SYSTEM.VAL(ADDRESS,InvalidateRect ));
	Kernel32.GetProcAddress(mod, "InsertMenuA", SYSTEM.VAL(ADDRESS,InsertMenu ));
	Kernel32.GetProcAddress(mod, "IntersectRect", SYSTEM.VAL(ADDRESS,IntersectRect ));
	Kernel32.GetProcAddress(mod, "IsChild", SYSTEM.VAL(ADDRESS,IsChild ));
	Kernel32.GetProcAddress(mod, "LoadCursorA", SYSTEM.VAL(ADDRESS,LoadCursor ));
	Kernel32.GetProcAddress(mod, "LoadCursorFromFileA", SYSTEM.VAL(ADDRESS,LoadCursorFromFile ));
	Kernel32.GetProcAddress(mod, "LoadIconA", SYSTEM.VAL(ADDRESS,LoadIcon ));
	Kernel32.GetProcAddress(mod, "MessageBeep", SYSTEM.VAL(ADDRESS,MessageBeep ));
	Kernel32.GetProcAddress(mod, "MessageBoxA", SYSTEM.VAL(ADDRESS,MessageBox ));
	Kernel32.GetProcAddress(mod, "MoveWindow", SYSTEM.VAL(ADDRESS,MoveWindow ));
	Kernel32.GetProcAddress(mod, "OffsetRect", SYSTEM.VAL(ADDRESS,OffsetRect ));
	Kernel32.GetProcAddress(mod, "OpenClipboard", SYSTEM.VAL(ADDRESS,OpenClipboard ));
	Kernel32.GetProcAddress(mod, "PtInRect", SYSTEM.VAL(ADDRESS,PtInRect ));
	Kernel32.GetProcAddress(mod, "PostMessageA", SYSTEM.VAL(ADDRESS,PostMessage ));
	Kernel32.GetProcAddress(mod, "PostQuitMessage", SYSTEM.VAL(ADDRESS,PostQuitMessage ));
	Kernel32.GetProcAddress(mod, "RegisterClassExA", SYSTEM.VAL(ADDRESS,RegisterClassEx ));
	Kernel32.GetProcAddress(mod, "RegisterClipboardFormatA", SYSTEM.VAL(ADDRESS,RegisterClipboardFormat ));
	Kernel32.GetProcAddress(mod, "RegisterHotKey", SYSTEM.VAL(ADDRESS,RegisterHotKey ));
	Kernel32.GetProcAddress(mod, "RegisterWindowMessageA", SYSTEM.VAL(ADDRESS,RegisterWindowMessage ));
	Kernel32.GetProcAddress(mod, "ReleaseCapture", SYSTEM.VAL(ADDRESS,ReleaseCapture ));
	Kernel32.GetProcAddress(mod, "ReleaseDC", SYSTEM.VAL(ADDRESS,ReleaseDC ));
	Kernel32.GetProcAddress(mod, "RemovePropA", SYSTEM.VAL(ADDRESS,RemoveProp ));
	Kernel32.GetProcAddress(mod, "ScreenToClient", SYSTEM.VAL(ADDRESS,ScreenToClient ));
	Kernel32.GetProcAddress(mod, "SendMessageA", SYSTEM.VAL(ADDRESS,SendMessage ));
	Kernel32.GetProcAddress(mod, "SetCapture", SYSTEM.VAL(ADDRESS,SetCapture ));
	Kernel32.GetProcAddress(mod, "SetClipboardData", SYSTEM.VAL(ADDRESS,SetClipboardData ));
	Kernel32.GetProcAddress(mod, "SetCursor", SYSTEM.VAL(ADDRESS,SetCursor ));
	Kernel32.GetProcAddress(mod, "SetCursorPos", SYSTEM.VAL(ADDRESS,SetCursorPos ));
	Kernel32.GetProcAddress(mod, "SetFocus", SYSTEM.VAL(ADDRESS,SetFocus ));
	Kernel32.GetProcAddress(mod, "SetForegroundWindow", SYSTEM.VAL(ADDRESS,SetForegroundWindow ));
	Kernel32.GetProcAddress(mod, "SetMenu", SYSTEM.VAL(ADDRESS,SetMenu ));
	Kernel32.GetProcAddress(mod, "SetMenuItemInfoA", SYSTEM.VAL(ADDRESS,SetMenuItemInfo ));
	Kernel32.GetProcAddress(mod, "SetPropA", SYSTEM.VAL(ADDRESS,SetProp ));
	Kernel32.GetProcAddress(mod, "SetWindowsHookExA", SYSTEM.VAL(ADDRESS,SetWindowsHookEx ));
	Kernel32.GetProcAddress(mod, "SetWindowLongA", SYSTEM.VAL(ADDRESS,SetWindowLong ));
	Kernel32.GetProcAddress(mod, "SetWindowPos", SYSTEM.VAL(ADDRESS,SetWindowPos ));
	Kernel32.GetProcAddress(mod, "SetWindowRgn", SYSTEM.VAL(ADDRESS,SetWindowRgn ));
	Kernel32.GetProcAddress(mod, "SetWindowTextA", SYSTEM.VAL(ADDRESS,SetWindowText ));
	Kernel32.GetProcAddress(mod, "ShowCursor", SYSTEM.VAL(ADDRESS,ShowCursor ));
	Kernel32.GetProcAddress(mod, "ShowWindow", SYSTEM.VAL(ADDRESS,ShowWindow ));
	Kernel32.GetProcAddress(mod, "ShowWindowAsync", SYSTEM.VAL(ADDRESS,ShowWindowAsync ));
	Kernel32.GetProcAddress(mod, "TrackPopupMenu", SYSTEM.VAL(ADDRESS,TrackPopupMenu ));
	Kernel32.GetProcAddress(mod, "TranslateAcceleratorA", SYSTEM.VAL(ADDRESS,TranslateAccelerator ));
	Kernel32.GetProcAddress(mod, "TranslateMessage", SYSTEM.VAL(ADDRESS,TranslateMessage ));
	Kernel32.GetProcAddress(mod, "UnhookWindowsHookEx", SYSTEM.VAL(ADDRESS,UnhookWindowsHookEx ));
	Kernel32.GetProcAddress(mod, "UnregisterClassA", SYSTEM.VAL(ADDRESS,UnregisterClass ));
	Kernel32.GetProcAddress(mod, "UpdateWindow", SYSTEM.VAL(ADDRESS,UpdateWindow ));
	Kernel32.GetProcAddress(mod, "ValidateRect", SYSTEM.VAL(ADDRESS,ValidateRect ));


END Init;

BEGIN
Init;
END User32.
