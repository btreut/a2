MODULE Clipboard; (** AUTHOR "ALEX"; PURPOSE "Windows clipboard interface"; *)

IMPORT SYSTEM, Kernel32, User32, KernelLog, Modules, Texts, TextUtilities, HostClipboard;

CONST
	CR = 0DX;  LF = 0AX;

(** Copy text of Windows clipboard to text *)
PROCEDURE GetFromClipboard(text : Texts.Text);
VAR
	hMem: Kernel32.HGLOBAL; adr: ADDRESS;
	hBool: Kernel32.BOOL;
	ch : CHAR;
	chUnicode: ARRAY 2 OF LONGINT;
BEGIN
	ASSERT((text # NIL) & (text.HasWriteLock()));
	IF User32.OpenClipboard(Kernel32.NULL) # Kernel32.False THEN
		hMem := User32.GetClipboardData(User32.CFText);
		IF hMem # Kernel32.NULL THEN
			text.Delete( 0, text.GetLength() );
			adr := Kernel32.GlobalLock(hMem);
			SYSTEM.GET(adr, ch); INC(adr);
			WHILE ch # 0X DO
				IF (ch # CR) OR (CHR(SYSTEM.GET8(adr)) # LF) THEN (* transform CRLF into LF *)
					chUnicode[0] := ORD(ch);
					chUnicode[1] := 0;
					text.InsertUCS32(text.GetLength(), chUnicode);
				END;
				SYSTEM.GET(adr, ch); INC(adr)
			END;
			hBool := Kernel32.GlobalUnlock(hMem);
		END;
		hBool := User32.CloseClipboard();
	END
END GetFromClipboard;

(** Copy text to Windows clipboard *)
PROCEDURE PutToClipboard(text : Texts.Text);
VAR
	hMem: Kernel32.HGLOBAL; adr: ADDRESS;
	hBool: Kernel32.BOOL;
	chBuff: POINTER TO ARRAY OF CHAR;
	size,requiredSize: LONGINT;
	ind: LONGINT;
BEGIN
	ASSERT((text # NIL) & (text.HasReadLock()));
	IF User32.OpenClipboard(Kernel32.NULL) # Kernel32.False THEN
		User32.EmptyClipboard;
		size := text.GetLength();
		NEW(chBuff, size + 1);
		(* UTF-8 encoding. String is truncated in case of multi-byte encoded characters! *)
		TextUtilities.TextToStr(text, chBuff^);
		ind := 0; requiredSize := size + 1;
		WHILE ind < size  DO
			IF chBuff^[ind] = LF THEN INC(requiredSize); END; (* transform LF into CRLF *)
			INC(ind);
		END;
		hMem := Kernel32.GlobalAlloc({Kernel32.GMemMoveable, Kernel32.GMemDDEShare}, requiredSize);
		adr := Kernel32.GlobalLock(hMem);
		ind := 0;
		WHILE ind < size  DO
			IF chBuff^[ind] = LF THEN (* transform LF into CRLF *)
				SYSTEM.PUT8(adr, CR); INC(adr);
			END;
			SYSTEM.PUT(adr, chBuff^[ind]); INC(adr); INC(ind);
		END;
		SYSTEM.PUT(adr, 0X);
		hBool := Kernel32.GlobalUnlock(hMem);
		hMem := User32.SetClipboardData(User32.CFText, hMem);
		hBool := User32.CloseClipboard();
	END
END PutToClipboard;

PROCEDURE ClipboardChanged(sender, data : ANY);
BEGIN
	Texts.clipboard.AcquireRead;
	PutToClipboard(Texts.clipboard);
	Texts.clipboard.ReleaseRead;
END ClipboardChanged;

PROCEDURE Install*;
BEGIN
	KernelLog.Enter; KernelLog.String("WindowsClipboard: Registered clipboard at host clipboard interface."); KernelLog.Exit;
END Install;

PROCEDURE Cleanup;
BEGIN
	Texts.clipboard.onTextChanged.Remove(ClipboardChanged);
	HostClipboard.SetHandlers(NIL, NIL);
	KernelLog.Enter; KernelLog.String("WindowsClipboard: Unregistered clipboard at host clipboard interface."); KernelLog.Exit;
END Cleanup;

BEGIN
	(* register with AosText clipboard *)
	Texts.clipboard.onTextChanged.Add(ClipboardChanged);
	HostClipboard.SetHandlers(GetFromClipboard, PutToClipboard);
	Modules.InstallTermHandler(Cleanup)
END Clipboard.

Clipboard.Install ~

SystemTools.Free Clipboard ~
