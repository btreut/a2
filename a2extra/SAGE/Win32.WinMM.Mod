MODULE WinMM; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "WinMM.dll API"; *)

IMPORT
	SYSTEM, Kernel32, Modules;
	
CONST

	MAXPNAMELEN* = 32;
	MIXER_SHORT_NAME_CHARS* = 16;
	MIXER_LONG_NAME_CHARS* = 64;

	MMSYSERR_BASE* = 0;
	WAVERR_BASE* = 32;
	MIXERR_BASE* = 1024;
	
	MMSYSERR_NOERROR* = 0;
	MMSYSERR_ERROR* = MMSYSERR_BASE+1;
	MMSYSERR_BADDEVICEID* = MMSYSERR_BASE+2;
	MMSYSERR_NOTENABLED* = MMSYSERR_BASE+3;
	MMSYSERR_ALLOCATED* = MMSYSERR_BASE+4;
	MMSYSERR_INVALHANDLE* = MMSYSERR_BASE+5;
	MMSYSERR_NODRIVER* = MMSYSERR_BASE+6;
	MMSYSERR_NOMEM* = MMSYSERR_BASE+7;
	MMSYSERR_NOTSUPPORTED* = MMSYSERR_BASE+8;
	MMSYSERR_BADERRNUM* = MMSYSERR_BASE+9;
	MMSYSERR_INVALFLAG* = MMSYSERR_BASE+10;
	MMSYSERR_INVALPARAM* = MMSYSERR_BASE+11;
	MMSYSERR_HANDLEBUSY* = MMSYSERR_BASE+12;
	MMSYSERR_INVALIDALIAS* = MMSYSERR_BASE+13;
	MMSYSERR_BADDB* = MMSYSERR_BASE+14;
	MMSYSERR_KEYNOTFOUND* = MMSYSERR_BASE+15;
	MMSYSERR_READERROR* = MMSYSERR_BASE+16;
	MMSYSERR_WRITEERROR* = MMSYSERR_BASE+17;
	MMSYSERR_DELETEERROR* = MMSYSERR_BASE+18;
	MMSYSERR_VALNOTFOUND* = MMSYSERR_BASE+19;
	MMSYSERR_NODRIVERCB* = MMSYSERR_BASE+20;
	MMSYSERR_LASTERROR* = MMSYSERR_BASE+20;

	MIXER_GETLINEINFOF_DESTINATION*		= {};
	MIXER_GETLINEINFOF_SOURCE*		= {0};
	MIXER_GETLINEINFOF_LINEID*		= {1};
	MIXER_GETLINEINFOF_COMPONENTTYPE*	= {0, 1};
	MIXER_GETLINEINFOF_TARGETTYPE*		= {2};
	MIXER_GETLINEINFOF_QUERYMASK*		= {0, 1, 2, 3};
	
	MIXER_GETLINECONTROLSF_ALL*		= {};
	MIXER_GETLINECONTROLSF_ONEBYID*		= {0};
	MIXER_GETLINECONTROLSF_ONEBYTYPE*		= {1};
	MIXER_GETLINECONTROLSF_QUERYMASK*		= {0, 1, 2, 3};

	MIXER_OBJECTF_HANDLE*			= {31};
	MIXER_OBJECTF_MIXER*			= {};
	MIXER_OBJECTF_HMIXER*			= MIXER_OBJECTF_HANDLE + MIXER_OBJECTF_MIXER;
	MIXER_OBJECTF_WAVEOUT*			= {28};
	MIXER_OBJECTF_HWAVEOUT*			= MIXER_OBJECTF_HANDLE + MIXER_OBJECTF_WAVEOUT;
	MIXER_OBJECTF_WAVEIN*			= {29};
	MIXER_OBJECTF_HWAVEIN*			= MIXER_OBJECTF_HANDLE + MIXER_OBJECTF_WAVEIN;
	MIXER_OBJECTF_MIDIOUT*			= {28, 29};
	MIXER_OBJECTF_HMIDIOUT*			= MIXER_OBJECTF_HANDLE + MIXER_OBJECTF_MIDIOUT;
	MIXER_OBJECTF_MIDIIN*			= {30};
	MIXER_OBJECTF_HMIDIIN*			= MIXER_OBJECTF_HANDLE + MIXER_OBJECTF_MIDIIN;
	MIXER_OBJECTF_AUX*			= {28, 30};
	
	MIXERCONTROL_CT_CLASS_MASK* = {28, 29, 30, 31};
	MIXERCONTROL_CT_CLASS_CUSTOM* = {};
	MIXERCONTROL_CT_CLASS_METER* = {28};
	MIXERCONTROL_CT_CLASS_SWITCH* = {29};
	MIXERCONTROL_CT_CLASS_NUMBER* = {28, 29};
	MIXERCONTROL_CT_CLASS_SLIDER* = {30};
	MIXERCONTROL_CT_CLASS_FADER* = {28, 30};
	MIXERCONTROL_CT_CLASS_TIME* = {29, 30};
	MIXERCONTROL_CT_CLASS_LIST* = {28, 29, 30};

TYPE

	HANDLE* = Kernel32.HANDLE;
	HMIXER* = HANDLE;
	HMIXEROBJ* = HANDLE;
	
	ADDRESS* = Kernel32.ADDRESS;
	LPMIXERCAPS* = ADDRESS;
	LPHMIXER* = ADDRESS;
	LPMIXERLINECONTROLS* = ADDRESS;
	LPMIXERLINE* = ADDRESS;
	LPWAVEOUTCAPS* = ADDRESS;
	LPMIXERCONTROLDETAILS* = ADDRESS;

	UINT* = LONGINT;
	MMRESULT* = Kernel32.HANDLE;
	
	WORD* = INTEGER;
	DWORD* = LONGINT;
	MMVERSION* = UINT;
	WCHAR* = WORD;
	
	MIXERCAPS* = RECORD
		wMid-: WORD;								(* manufacturer id *)
		wPid-: WORD;								(* product id *)
		vDriverVersion-: MMVERSION;				(* version of the driver *)
		szPname-: ARRAY MAXPNAMELEN OF WCHAR;	(* product name *)
		fdwSupport-: DWORD;						(* misc. support bits *)
		cDestinations-: DWORD;						(* count of destinations *)
	END;

	WAVEOUTCAPS* = RECORD
		wMid-: WORD;								(* manufacturer ID *)
		wPid-: WORD;								(* product ID *)
		vDriverVersion-: MMVERSION;				(* version of the driver *)
		szPname-: ARRAY MAXPNAMELEN OF WCHAR;	(* product name *)
		dwFormats-: DWORD;						(* formats supported *)
		wChannels-: WORD;						(* number of sources supported *)
		(*wReserved1-: WORD;*)					(* Packing *)
		dwSupport-: DWORD;						(* functionality supported by driver *)
	END;
	
	Target* = RECORD
		dwType-: DWORD;							(* MIXERLINE_TARGETTYPE_xxxx *)
		dwDeviceID-: DWORD;						(* target device ID of device type *)
		wMid-: WORD;								(* of target device *)
		wPid-: WORD;								(*      " *)
		vDriverVersion-: MMVERSION;				(*      " *)
		szPname-: ARRAY MAXPNAMELEN OF WCHAR;	(*      " *)
	END;

	MIXERLINE* = RECORD
		cbStruct*: DWORD;							(* size of MIXERLINE structure *)
		dwDestination*: DWORD;					(* zero based destination index *)
		dwSource*: DWORD;						(* zero based source index (if source) *)
		dwLineID-: DWORD;						(* unique line id for mixer device *)
		fdwLine-: DWORD;							(* state/information about line *)
		dwUser-: DWORD;							(* driver specific information *)
		dwComponentType-: DWORD;				(* component type line connects to *)
		cChannels-: DWORD;						(* number of channels line supports *)
		cConnections-: DWORD;						(* number of connections [possible] *)
		cControls-: DWORD;						(* number of controls at this line *)
		szShortName-: ARRAY MIXER_SHORT_NAME_CHARS OF WCHAR;
		szName-: ARRAY MIXER_LONG_NAME_CHARS OF WCHAR;
		target-: Target;
	END;

	MIXERLINECONTROLS* = RECORD
		cbStruct*: DWORD;					(* size in bytes of MIXERLINECONTROLS *)
		dwLineID*: DWORD;				(* line id (from MIXERLINE.dwLineID) *)
		dwControlID_ControlType-: DWORD;
		cControls*: DWORD;					(* count of controls pmxctrl points to *)
		cbmxctrl*: DWORD;					(* size in bytes of _one_ MIXERCONTROL *)
		pamxctrl*: ADDRESS;				(* pointer to first MIXERCONTROL array *)
	END;
	
	Bounds = RECORD
		dwMinimum-: DWORD;
		dwMaximum-: DWORD;
		reserved-: ARRAY 4 OF DWORD;
	END;
	
	Metrics = RECORD
		cSteps-: DWORD;
		reserved-: ARRAY 5 OF DWORD;
	END;
	
	MIXERCONTROL* = RECORD
		cbStruct*: DWORD;					(* size in bytes of MIXERCONTROL *)
		dwControlID-: DWORD;			(* unique control id for mixer device *)
		dwControlType-: DWORD;			(* MIXERCONTROL_CONTROLTYPE_xxx *)
		fdwControl-: DWORD;				(* MIXERCONTROL_CONTROLF_xxx *)
		cMultipleItems-: DWORD;			(* if MIXERCONTROL_CONTROLF_MULTIPLE set *)
		szShortName-: ARRAY MIXER_SHORT_NAME_CHARS OF WCHAR;
		szName-: ARRAY MIXER_LONG_NAME_CHARS OF WCHAR;
		bounds-: Bounds;
		metrics-: Metrics;
	END;

	MIXERCONTROLDETAILS_BASE = RECORD
		cbStruct*: DWORD;					(* size in bytes of MIXERCONTROLDETAILS *)
		dwControlID*: DWORD;				(* control id to get/set details on *)
		cChannels*: DWORD;				(* number of channels in paDetails array *)
	END;

	(* for MIXER_SETCONTROLDETAILSF_CUSTOM *)
	MIXERCONTROLDETAILS_CUSTOM* = RECORD(MIXERCONTROLDETAILS_BASE)
		hwndOwner*: HANDLE;
	END;

	(* if _MULTIPLE *)
	MIXERCONTROLDETAILS_MULTIPLE* = RECORD(MIXERCONTROLDETAILS_BASE)
		cMultipleItems*: DWORD;			(* if _MULTIPLE, the number of items per channel *)
		cbDetails*: DWORD;					(* size of _one_ details_XX struct *)
		paDetails*: ADDRESS;				(* pointer to array of details_XX structs *)
	END;
	
	MIXERCONTROLDETAILS_UNSIGNED* = RECORD
		dwValue*: DWORD;
	END;

VAR

	mod: Kernel32.HMODULE;

	(* UINT WINAPI mixerGetNumDevs(void); *)
	mixerGetNumDevs-: PROCEDURE {WINAPI} (): UINT;

	(* MMRESULT WINAPI mixerGetDevCapsW(UINT,LPMIXERCAPSW,UINT); *)
	mixerGetDevCaps-: PROCEDURE {WINAPI} (uMxId: UINT; pMxCaps: LPMIXERCAPS; cbMxCaps: UINT): MMRESULT;

	(* MMRESULT WINAPI mixerOpen(LPHMIXER,UINT,DWORD,DWORD,DWORD); *)
	mixerOpen-: PROCEDURE {WINAPI} (phMx: LPHMIXER; uMxId: UINT; dwCallback, dwInstance, fdwOpen: DWORD): MMRESULT;

	(* MMRESULT WINAPI mixerClose(HMIXER); *)
	mixerClose-: PROCEDURE {WINAPI} (hMx: HMIXER): MMRESULT;

	(* DWORD WINAPI mixerMessage(HMIXER,UINT,DWORD,DWORD); *)

	(* MMRESULT WINAPI mixerGetLineInfoW(HMIXEROBJ,LPMIXERLINEW,DWORD); *)
	mixerGetLineInfo-: PROCEDURE {WINAPI} (hMx: HMIXEROBJ; pMxl: LPMIXERLINE;  fdwInfo: DWORD): MMRESULT;
	
	(* MMRESULT WINAPI mixerGetID(HMIXEROBJ,PUINT,DWORD); *)
	
	(* MMRESULT WINAPI mixerGetLineControlsW(HMIXEROBJ,LPMIXERLINECONTROLSW,DWORD); *)
	mixerGetLineControls-: PROCEDURE {WINAPI} (hMx: HMIXEROBJ; pMxLC: LPMIXERLINECONTROLS;  fdwControls: DWORD): MMRESULT;
	
	(* MMRESULT WINAPI mixerGetControlDetailsW(HMIXEROBJ,LPMIXERCONTROLDETAILS,DWORD); *)
	mixerGetControlDetails-: PROCEDURE {WINAPI} (hMx: HMIXEROBJ; pMxCD: LPMIXERCONTROLDETAILS;  fdwDetails: DWORD): MMRESULT;
	(* MMRESULT WINAPI mixerSetControlDetails(HMIXEROBJ,LPMIXERCONTROLDETAILS,DWORD); *)
	mixerSetControlDetails-: PROCEDURE {WINAPI} (hMx: HMIXEROBJ; pMxCD: LPMIXERCONTROLDETAILS;  fdwDetails: DWORD): MMRESULT;
	
	(* UINT WINAPI waveOutGetNumDevs(void); *)
	waveOutGetNumDevs-: PROCEDURE {WINAPI} (): UINT;
	(* MMRESULT WINAPI waveOutGetDevCapsW(UINT,LPWAVEOUTCAPSW,UINT); *)
	waveOutGetDevCaps-: PROCEDURE {WINAPI} (uDeviceId: UINT; pwoc: LPWAVEOUTCAPS; cbwoc: UINT): MMRESULT;
	
	(* MMRESULT WINAPI waveOutGetVolume(HWAVEOUT,PDWORD); *)
	(* MMRESULT WINAPI waveOutSetVolume(HWAVEOUT,DWORD); *)
	(* MMRESULT WINAPI waveOutGetErrorTextW(MMRESULT,LPWSTR,UINT); *)
	(* MMRESULT WINAPI waveOutOpen(LPHWAVEOUT,UINT,LPCWAVEFORMATEX,DWORD,DWORD,DWORD); *)
	(* MMRESULT WINAPI waveOutClose(HWAVEOUT); *)
	(* MMRESULT WINAPI waveOutPrepareHeader(HWAVEOUT,LPWAVEHDR,UINT); *)
	(* MMRESULT WINAPI waveOutUnprepareHeader(HWAVEOUT,LPWAVEHDR,UINT); *)
	(* MMRESULT WINAPI waveOutWrite(HWAVEOUT,LPWAVEHDR,UINT); *)
	(* MMRESULT WINAPI waveOutPause(HWAVEOUT); *)
	(* MMRESULT WINAPI waveOutRestart(HWAVEOUT); *)
	(* MMRESULT WINAPI waveOutReset(HWAVEOUT); *)
	(* MMRESULT WINAPI waveOutBreakLoop(HWAVEOUT); *)
	(* MMRESULT WINAPI waveOutGetPosition(HWAVEOUT,LPMMTIME,UINT); *)
	(* MMRESULT WINAPI waveOutGetPitch(HWAVEOUT,PDWORD); *)
	(* MMRESULT WINAPI waveOutSetPitch(HWAVEOUT,DWORD); *)
	(* MMRESULT WINAPI waveOutGetPlaybackRate(HWAVEOUT,PDWORD); *)
	(* MMRESULT WINAPI waveOutSetPlaybackRate(HWAVEOUT,DWORD); *)
	(* MMRESULT WINAPI waveOutGetID(HWAVEOUT,LPUINT); *)
	(* MMRESULT WINAPI waveOutMessage(HWAVEOUT,UINT,DWORD,DWORD); *)


	(*PROCEDURE Fill*(adr: Kernel32.ADDRESS; len: LONGINT; c: CHAR);
	VAR
		i: LONGINT;
	BEGIN
		FOR i := 0 TO len - 1 DO
			SYSTEM.PUT(adr, SYSTEM.VAL(CHAR, c))
		END
	END Fill;*)
	
	(*PROCEDURE GetWord*(w: WORD): LONGINT;
	VAR
		val: LONGINT;
	BEGIN
		val := 0;
		SYSTEM.PUT16(SYSTEM.ADR(val), SYSTEM.VAL(INTEGER, w));
		RETURN (*SYSTEM.VAL(INTEGER, w)*) val
	END GetWord;
	
	PROCEDURE GetDWord*(dw: DWORD): HUGEINT;
	VAR
		val: HUGEINT;
	BEGIN
		val := 0;
		SYSTEM.PUT32(SYSTEM.ADR(val), SYSTEM.VAL(LONGINT, dw));
		RETURN (*SYSTEM.VAL(INTEGER, w)*) val
	END GetDWord;*)

	PROCEDURE Init;
	VAR
		str: ARRAY 16 OF CHAR;
	BEGIN
		str := "WinMM.DLL";
		mod := Kernel32.LoadLibrary(str);

		Kernel32.GetProcAddress(mod, "mixerGetNumDevs", SYSTEM.VAL(Kernel32.ADDRESS, mixerGetNumDevs));
		Kernel32.GetProcAddress(mod, "mixerGetDevCapsW", SYSTEM.VAL(Kernel32.ADDRESS, mixerGetDevCaps));
		Kernel32.GetProcAddress(mod, "mixerOpen", SYSTEM.VAL(Kernel32.ADDRESS, mixerOpen));
		Kernel32.GetProcAddress(mod, "mixerClose", SYSTEM.VAL(Kernel32.ADDRESS, mixerClose));
		Kernel32.GetProcAddress(mod, "mixerGetLineInfoW", SYSTEM.VAL(Kernel32.ADDRESS, mixerGetLineInfo));
		Kernel32.GetProcAddress(mod, "mixerGetLineControlsW", SYSTEM.VAL(Kernel32.ADDRESS, mixerGetLineControls));
		Kernel32.GetProcAddress(mod, "mixerGetControlDetailsW", SYSTEM.VAL(Kernel32.ADDRESS, mixerGetControlDetails));
		Kernel32.GetProcAddress(mod, "mixerSetControlDetails", SYSTEM.VAL(Kernel32.ADDRESS, mixerSetControlDetails));

		Kernel32.GetProcAddress(mod, "waveOutGetNumDevs", SYSTEM.VAL(Kernel32.ADDRESS, waveOutGetNumDevs));
		Kernel32.GetProcAddress(mod, "waveOutGetDevCapsW", SYSTEM.VAL(Kernel32.ADDRESS, waveOutGetDevCaps));
		
	END Init;

	PROCEDURE Free;
	BEGIN
		Kernel32.FreeLibrary(mod); mod := Kernel32.NULL
	END Free;
	
BEGIN
	Init;
	Modules.InstallTermHandler(Free)
END WinMM.
