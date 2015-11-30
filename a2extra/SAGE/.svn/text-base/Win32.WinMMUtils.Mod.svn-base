MODULE WinMMUtils; (** AUTHOR "Yaroslav Romanchenko (sage)"; PURPOSE "WinMM.dll API utilities"; *)

IMPORT
	SYSTEM, WinMM, Texts, UTF8Strings, Commands;

	PROCEDURE mixerGetDevCaps*(CONST uMxId: WinMM.UINT; CONST MxCaps: WinMM.MIXERCAPS; context: Commands.Context): BOOLEAN;
	VAR
		nResult: WinMM.MMRESULT;
	BEGIN
		nResult := WinMM.mixerGetDevCaps(uMxId, SYSTEM.ADR(MxCaps), SYSTEM.SIZEOF(WinMM.MIXERCAPS));
		IF (nResult # WinMM.MMSYSERR_NOERROR) & (context # NIL) THEN
			context.out.String("mixerGetDevCaps error: "); context.out.Int(nResult, 1); context.out.Ln
		END;
		RETURN nResult = WinMM.MMSYSERR_NOERROR
	END mixerGetDevCaps;

	PROCEDURE mixerOpen*(VAR hMx: WinMM.HMIXER; CONST uMxId: WinMM.UINT; CONST dwCallback, dwInstance: WinMM.DWORD; CONST fOpen: SET; context: Commands.Context): BOOLEAN;
	VAR
		nResult: WinMM.MMRESULT;
	BEGIN
		nResult := WinMM.mixerOpen(SYSTEM.ADR(hMx), uMxId, dwCallback, dwInstance, SYSTEM.VAL(LONGINT, fOpen));
		IF (nResult # WinMM.MMSYSERR_NOERROR) & (context # NIL) THEN
			context.out.String("mixerOpen error: "); context.out.Int(nResult, 1); context.out.Ln
		END;		
		RETURN nResult = WinMM.MMSYSERR_NOERROR
	END mixerOpen;

	PROCEDURE mixerGetLineInfo*(CONST hMx: WinMM.HMIXEROBJ; VAR mxL: WinMM.MIXERLINE; fInfo: SET; context: Commands.Context): BOOLEAN;
	VAR
		nResult: WinMM.MMRESULT;
	BEGIN
		mxL.cbStruct := SYSTEM.SIZEOF(WinMM.MIXERLINE);
		nResult := WinMM.mixerGetLineInfo(hMx, SYSTEM.ADR(mxL), SYSTEM.VAL(LONGINT, fInfo));
		IF (nResult # WinMM.MMSYSERR_NOERROR) & (context # NIL) THEN
			context.out.String("mixerGetLineInfo error: "); context.out.Int(nResult, 1); context.out.Ln
		END;		
		RETURN nResult = WinMM.MMSYSERR_NOERROR
	END mixerGetLineInfo;
	
	PROCEDURE mixerGetLineControls*(CONST hMx: WinMM.HMIXEROBJ; VAR mxLC: WinMM.MIXERLINECONTROLS; fControls: SET; context: Commands.Context): BOOLEAN;
	VAR
		nResult: WinMM.MMRESULT;
	BEGIN
		mxLC.cbStruct := SYSTEM.SIZEOF(WinMM.MIXERLINECONTROLS);
		mxLC.cbmxctrl := SYSTEM.SIZEOF(WinMM.MIXERCONTROL);
		nResult := WinMM.mixerGetLineControls(hMx, SYSTEM.ADR(mxLC), SYSTEM.VAL(LONGINT, fControls));
		IF (nResult # WinMM.MMSYSERR_NOERROR) & (context # NIL) THEN
			context.out.String("mixerGetLineControls error: "); context.out.Int(nResult, 1); context.out.Ln
		END;		
		RETURN nResult = WinMM.MMSYSERR_NOERROR
	END mixerGetLineControls;
	
	PROCEDURE mixerGetControlDetails*(CONST hMx: WinMM.HMIXEROBJ; VAR MxCD: WinMM.MIXERCONTROLDETAILS_MULTIPLE; fDetails: SET; context: Commands.Context): BOOLEAN;
	VAR
		nResult: WinMM.MMRESULT;
	BEGIN
		MxCD.cbStruct := SYSTEM.SIZEOF(WinMM.MIXERCONTROLDETAILS_MULTIPLE);
		nResult := WinMM.mixerGetControlDetails(hMx, SYSTEM.ADR(MxCD), SYSTEM.VAL(LONGINT, fDetails));
		IF (nResult # WinMM.MMSYSERR_NOERROR) & (context # NIL) THEN
			context.out.String("mixerGetControlDetails error: "); context.out.Int(nResult, 1); context.out.Ln
		END;		
		RETURN nResult = WinMM.MMSYSERR_NOERROR
	END mixerGetControlDetails;

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
	
	(* Copy the wide string *)
	PROCEDURE WCharToUTF8*(CONST wchar: ARRAY OF WinMM.WCHAR; VAR utf8: ARRAY OF CHAR);
	VAR
		i: LONGINT;
		pUCS: POINTER TO ARRAY OF Texts.Char32;
	BEGIN
		NEW(pUCS, LEN(wchar));
		i := 0;
		WHILE (i < LEN(wchar) - 1) & (wchar[i] # 0) DO
			pUCS[i] := 0;
			SYSTEM.PUT16(SYSTEM.ADR(pUCS^[i]), SYSTEM.VAL(INTEGER, wchar[i]));
			INC(i)
		END;
		pUCS[i] := 0;
		UTF8Strings.UnicodetoUTF8(pUCS^, utf8)
	END WCharToUTF8;
	
END WinMMUtils.
