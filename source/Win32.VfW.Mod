MODULE VfW; (** AUTHOR "thomas.frey@alumni.ethz.ch"; PURPOSE "Video for Windows bindings for WinA2"; *)
(* see TestVideo.Mod for usage example *)

IMPORT
	KernelLog, GDI32, Kernel32, User32, SYSTEM;

CONST
	WS_POPUP* = LONGINT(80000000H);
	WM_CAP_START* = 0400H;

	WM_CAP_GET_CAPSTREAMPTR* = WM_CAP_START + 1;

	WM_CAP_SET_CALLBACK_ERROR* = WM_CAP_START + 2;
	WM_CAP_SET_CALLBACK_STATUS* = WM_CAP_START + 3;
	WM_CAP_SET_CALLBACK_YIELD* = WM_CAP_START + 4;
	WM_CAP_SET_CALLBACK_FRAME* = WM_CAP_START + 5;
	WM_CAP_SET_CALLBACK_VIDEOSTREAM* = WM_CAP_START + 6;
	WM_CAP_SET_CALLBACK_WAVESTREAM* = WM_CAP_START + 7;
	WM_CAP_GET_USER_DATA* = WM_CAP_START + 8;
	WM_CAP_SET_USER_DATA* = WM_CAP_START + 9;

	WM_CAP_DRIVER_CONNECT* = WM_CAP_START + 10;
	WM_CAP_DRIVER_DISCONNECT* = WM_CAP_START + 11;
	WM_CAP_DRIVER_GET_NAME* = WM_CAP_START + 12;
	WM_CAP_DRIVER_GET_VERSION* = WM_CAP_START + 13;
	WM_CAP_DRIVER_GET_CAPS* = WM_CAP_START + 14;

	WM_CAP_FILE_SET_CAPTURE_FILE* = WM_CAP_START + 20;
	WM_CAP_FILE_GET_CAPTURE_FILE* = WM_CAP_START + 21;
	WM_CAP_FILE_ALLOCATE* = WM_CAP_START + 22;
	WM_CAP_FILE_SAVEAS* = WM_CAP_START + 23;
	WM_CAP_FILE_SET_INFOCHUNK* = WM_CAP_START + 24;
	WM_CAP_FILE_SAVEDIB* = WM_CAP_START + 25;

	WM_CAP_EDIT_COPY* = WM_CAP_START + 30;

	WM_CAP_SET_AUDIOFORMAT* = WM_CAP_START + 35;
	WM_CAP_GET_AUDIOFORMAT* = WM_CAP_START + 36;

	WM_CAP_DLG_VIDEOFORMAT* = WM_CAP_START + 41;
	WM_CAP_DLG_VIDEOSOURCE* = WM_CAP_START + 42;
	WM_CAP_DLG_VIDEODISPLAY* = WM_CAP_START + 43;
	WM_CAP_GET_VIDEOFORMAT* = WM_CAP_START + 44;
	WM_CAP_SET_VIDEOFORMAT* = WM_CAP_START + 45;
	WM_CAP_DLG_VIDEOCOMPRESSION* = WM_CAP_START + 46;

	WM_CAP_SET_PREVIEW* = WM_CAP_START + 50;
	WM_CAP_SET_OVERLAY* = WM_CAP_START + 51;
	WM_CAP_SET_PREVIEWRATE* = WM_CAP_START + 52;
	WM_CAP_SET_SCALE* = WM_CAP_START + 53;
	WM_CAP_GET_STATUS* = WM_CAP_START + 54;
	WM_CAP_SET_SCROLL* = WM_CAP_START + 55;

	WM_CAP_GRAB_FRAME* = WM_CAP_START + 60;
	WM_CAP_GRAB_FRAME_NOSTOP* = WM_CAP_START + 61;

	WM_CAP_SEQUENCE* = WM_CAP_START + 62;
	WM_CAP_SEQUENCE_NOFILE* = WM_CAP_START + 63;
	WM_CAP_SET_SEQUENCE_SETUP* = WM_CAP_START + 64;
	WM_CAP_GET_SEQUENCE_SETUP* = WM_CAP_START + 65;
	WM_CAP_SET_MCI_DEVICE* = WM_CAP_START + 66;
	WM_CAP_GET_MCI_DEVICE* = WM_CAP_START + 67;
	WM_CAP_STOP* = WM_CAP_START + 68;
	WM_CAP_ABORT* = WM_CAP_START + 69;

	WM_CAP_SINGLE_FRAME_OPEN* = WM_CAP_START + 70;
	WM_CAP_SINGLE_FRAME_CLOSE* = WM_CAP_START + 71;

	WM_CAP_SINGLE_FRAME* = WM_CAP_START + 72;


	WM_CAP_PAL_OPEN* = WM_CAP_START + 80;
	WM_CAP_PAL_SAVE* = WM_CAP_START + 81;
	WM_CAP_PAL_PASTE* = WM_CAP_START + 82;
	WM_CAP_PAL_AUTOCREATE* = WM_CAP_START + 83;
	WM_CAP_PAL_MANUALCREATE* = WM_CAP_START + 84;
	WM_CAP_SET_CALLBACK_CAPCONTROL* = WM_CAP_START + 85;

	WM_CAP_END* = WM_CAP_SET_CALLBACK_CAPCONTROL;

TYPE
	HWND* = Kernel32.HANDLE;

	VHdr* = RECORD
		lpData* : ADDRESS;
		dwBufferLength*,
		dwBytesUsed*,
		dwTimeCaptured*,
		dwUser*,
		dwFlags* : LONGINT;
		dwReserved* : ARRAY 4 OF ADDRESS;
	END;

	Capturerec* = RECORD
		dwRequestMicroSecPerFrame*: LONGINT;
		fMakeUserHitOKToCapture*: LONGINT;
		wPercentDropForError*: LONGINT;
		fYield*: LONGINT;
		dwIndexSize*: LONGINT;
		wChunkGranularity*: LONGINT;
		fUsingDOSMemory*: LONGINT;
		wNumVideoRequested*: LONGINT;
		fCaptureAudio*: LONGINT;
		wNumAudioRequested*: LONGINT;
		vKeyAbort*: LONGINT;
		fAbortLeftMouse*: LONGINT;
		fAbortRightMouse*: LONGINT;
		fLimitEnabled*: LONGINT;
		wTimeLimit*: LONGINT;
		fMCIControl*: LONGINT;
		fStepMCIDevice*: LONGINT;
		dwMCIStartTime*: LONGINT;
		dwMCIStopTime*: LONGINT;
		fStepCaptureAt2x*: LONGINT;
		wStepCaptureAverageFrames*: LONGINT;
		dwAudioBufferSize*: LONGINT;
		fDisableWriteCache*: LONGINT;
		AVStreamMaster*: LONGINT;
	END;

	CapVideoStreamCallback* = PROCEDURE {WINAPI} (hWnd : HWND; VAR lpVHdr : VHdr) : User32.LResult;
	CapYieldCallback* = PROCEDURE {WINAPI} (hWnd : HWND) : User32.LResult;

VAR
	CapCreateCaptureWindow-: PROCEDURE {WINAPI} (CONST lpszWindowName: ARRAY OF CHAR;
		dwStyle, x, y, nWidth, nHeight : LONGINT;
		ParentWin : HWND;
		nId : LONGINT): HWND;
	CapGetDriverDescription- : PROCEDURE {WINAPI} (wDriverIndex : LONGINT;
		VAR lpszName : ARRAY OF CHAR; cbName : LONGINT;
 		VAR lpszVer : ARRAY OF CHAR; cbVar : LONGINT) : BOOLEAN;
 	(* PeekMessage is missing in Win32.User32 *)
	PeekMessage-: PROCEDURE {WINAPI} (VAR lpMsg: User32.Msg; hWnd: HWND; wMsgFilterMin, wMsgFilterMax, wRemoveMsg: LONGINT): LONGINT;


PROCEDURE GetProcAddress(hModule: ADDRESS; VAR adr: ADDRESS; CONST procName: ARRAY OF CHAR);
BEGIN
	Kernel32.GetProcAddress(hModule, procName, adr);
END GetProcAddress;

PROCEDURE Init;
VAR
	mod: Kernel32.HMODULE; str: ARRAY 32 OF CHAR;
BEGIN
	str := "AVICAP32.DLL";
	mod := Kernel32.LoadLibrary(str);
	IF mod = 0 THEN
		KernelLog.String("Failed to load AVICAP32.DLL"); KernelLog.Ln;
	END;
	GetProcAddress(mod, SYSTEM.VAL(ADDRESS, CapCreateCaptureWindow ), "capCreateCaptureWindowA");
	GetProcAddress(mod, SYSTEM.VAL(ADDRESS, CapGetDriverDescription ), "capGetDriverDescriptionA");


	str := "USER32.DLL";
	mod := Kernel32.LoadLibrary(str);
	GetProcAddress(mod, SYSTEM.VAL(ADDRESS, PeekMessage ), "PeekMessageA")
END Init;

PROCEDURE CapDriverConnect*(hwnd : HWND; index : LONGINT) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_DRIVER_CONNECT, index, 0);
	RETURN result # 0
END CapDriverConnect;

PROCEDURE CapDriverDisconnect*(hwnd : HWND) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_DRIVER_DISCONNECT, 0, 0);
	RETURN result # 0
END CapDriverDisconnect;

PROCEDURE CapSetCallbackFrame*(hwnd : HWND; proc : CapVideoStreamCallback) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_SET_CALLBACK_FRAME, 0, SYSTEM.VAL(LONGINT, proc));
	RETURN result # 0
END CapSetCallbackFrame;

PROCEDURE CapSetCallbackStream*(hwnd : HWND; proc : CapVideoStreamCallback) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_SET_CALLBACK_VIDEOSTREAM, 0, SYSTEM.VAL(LONGINT, proc));
	RETURN result # 0
END CapSetCallbackStream;

PROCEDURE CapSetCallbackYield*(hwnd : HWND; proc : CapYieldCallback) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_SET_CALLBACK_YIELD, 0, SYSTEM.VAL(LONGINT, proc));
	RETURN result # 0
END CapSetCallbackYield;

PROCEDURE CapGetVideoFormat*(hwnd : HWND; VAR format : GDI32.BitmapInfoHeader) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_GET_VIDEOFORMAT, 40, ADDRESSOF(format));
	RETURN result # 0
END CapGetVideoFormat;

PROCEDURE CapSetVideoFormat*(hwnd : HWND; VAR format : GDI32.BitmapInfoHeader) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_SET_VIDEOFORMAT, 40, ADDRESSOF(format));
	RETURN result # 0
END CapSetVideoFormat;

PROCEDURE CapGetSequenceSetup*(hwnd : HWND; VAR format : Capturerec) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_GET_SEQUENCE_SETUP, 96, ADDRESSOF(format));
	RETURN result # 0
END CapGetSequenceSetup;

PROCEDURE CapSetSequenceSetup*(hwnd : HWND; VAR format : Capturerec) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_SET_SEQUENCE_SETUP, 96, ADDRESSOF(format));
	RETURN result # 0
END CapSetSequenceSetup;

PROCEDURE CapCaptureStop*(hwnd : HWND) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_STOP, 0, 0);
	RETURN result # 0
END CapCaptureStop;

PROCEDURE CapGrabFrame*(hwnd : HWND) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_GRAB_FRAME, 0, 0);
	RETURN result # 0
END CapGrabFrame;

PROCEDURE CapSequenceNoFile*(hwnd : HWND) : BOOLEAN;
VAR result : User32.LResult;
BEGIN
	result := User32.SendMessage(hwnd, WM_CAP_SEQUENCE_NOFILE, 0, 0);
	RETURN result # 0
END CapSequenceNoFile;

PROCEDURE DumpCapRec*(CONST capRec : Capturerec);
BEGIN
	KernelLog.String("capRec.dwRequestMicroSecPerFrame= "); KernelLog.Int(capRec.dwRequestMicroSecPerFrame, 0); KernelLog.Ln;
	KernelLog.String("capRec.fMakeUserHitOKToCapture= "); KernelLog.Int(capRec.fMakeUserHitOKToCapture, 0); KernelLog.Ln;
	KernelLog.String("capRec.wPercentDropForError= "); KernelLog.Int(capRec.wPercentDropForError, 0); KernelLog.Ln;
	KernelLog.String("capRec.fYield= "); KernelLog.Int(capRec.fYield, 0); KernelLog.Ln;
	KernelLog.String("capRec.dwIndexSize= "); KernelLog.Int(capRec.dwIndexSize, 0); KernelLog.Ln;
	KernelLog.String("capRec.wChunkGranularity= "); KernelLog.Int(capRec.wChunkGranularity, 0); KernelLog.Ln;
	KernelLog.String("capRec.fUsingDOSMemory= "); KernelLog.Int(capRec.fUsingDOSMemory, 0); KernelLog.Ln;
	KernelLog.String("capRec.wNumVideoRequested= "); KernelLog.Int(capRec.wNumVideoRequested, 0); KernelLog.Ln;
	KernelLog.String("capRec.fCaptureAudio= "); KernelLog.Int(capRec.fCaptureAudio, 0); KernelLog.Ln;
	KernelLog.String("capRec.wNumAudioRequested= "); KernelLog.Int(capRec.wNumAudioRequested, 0); KernelLog.Ln;
	KernelLog.String("capRec.vKeyAbort= "); KernelLog.Int(capRec.vKeyAbort, 0); KernelLog.Ln;
	KernelLog.String("capRec.fAbortLeftMouse= "); KernelLog.Int(capRec.fAbortLeftMouse, 0); KernelLog.Ln;
	KernelLog.String("capRec.fAbortRightMouse= "); KernelLog.Int(capRec.fAbortRightMouse, 0); KernelLog.Ln;
	KernelLog.String("capRec.fLimitEnabled= "); KernelLog.Int(capRec.fLimitEnabled, 0); KernelLog.Ln;
	KernelLog.String("capRec.wTimeLimit= "); KernelLog.Int(capRec.wTimeLimit, 0); KernelLog.Ln;
	KernelLog.String("capRec.fMCIControl= "); KernelLog.Int(capRec.fMCIControl, 0); KernelLog.Ln;
	KernelLog.String("capRec.fStepMCIDevice= "); KernelLog.Int(capRec.fStepMCIDevice, 0); KernelLog.Ln;
	KernelLog.String("capRec.dwMCIStartTime= "); KernelLog.Int(capRec.dwMCIStartTime, 0); KernelLog.Ln;
	KernelLog.String("capRec.dwMCIStopTime= "); KernelLog.Int(capRec.dwMCIStopTime, 0); KernelLog.Ln;
	KernelLog.String("capRec.fStepCaptureAt2x= "); KernelLog.Int(capRec.fStepCaptureAt2x, 0); KernelLog.Ln;
	KernelLog.String("capRec.wStepCaptureAverageFrames= "); KernelLog.Int(capRec.wStepCaptureAverageFrames, 0); KernelLog.Ln;
	KernelLog.String("capRec.dwAudioBufferSize= "); KernelLog.Int(capRec.dwAudioBufferSize, 0); KernelLog.Ln;
	KernelLog.String("capRec.fDisableWriteCache= "); KernelLog.Int(capRec.fDisableWriteCache, 0); KernelLog.Ln;
	KernelLog.String("capRec.AVStreamMaster= "); KernelLog.Int(capRec.AVStreamMaster, 0); KernelLog.Ln;
END DumpCapRec;

PROCEDURE DumpBitmapInfoHeader*(VAR info : GDI32.BitmapInfoHeader);
BEGIN
	KernelLog.String("info.biSize= "); KernelLog.Int(info.biSize, 0); KernelLog.Ln;
	KernelLog.String("info.biWidth= "); KernelLog.Int(info.biWidth, 0); KernelLog.Ln;
	KernelLog.String("info.biHeight= "); KernelLog.Int(info.biHeight, 0); KernelLog.Ln;
	KernelLog.String("info.biBitCount= "); KernelLog.Int(info.biBitCount, 0); KernelLog.Ln;
	KernelLog.String("info.biCompression= "); KernelLog.Int(info.biCompression, 0); KernelLog.Ln;
END DumpBitmapInfoHeader;


BEGIN
	Init()
END VfW.

SystemTools.Free VfW ~

