MODULE VMWareTools; (** AUTHOR "thomas.frey@alumni.ethz.ch"; PURPOSE "Tools to integrate BB into VMWare"; *)
(* Reference found on : http://chitchat.at.infoseek.co.jp/vmware/backdoor.html
	Thanks to Ken Kato for this documentation
*)

IMPORT
	SYSTEM, Strings, Modules, KernelLog, WMWindowManager, WMMessages, Texts, TextUtilities, HostClipboard, Kernel;

TYPE
	MouseGrabber= OBJECT
	VAR
		timer : Kernel.Timer;
		alive : BOOLEAN;
		t : LONGINT;
	BEGIN {ACTIVE}
		NEW(timer);
		alive := TRUE;
		WHILE alive DO
			timer.Sleep(10);
			t := ReadMouse();
		END;
	END MouseGrabber;

VAR
	manager : WMWindowManager.WindowManager;
	viewPort : WMWindowManager.ViewPort;
	w, h : LONGINT;
	hw : LONGINT;
	oldGUIBits : SET;
	mouseGrabber : MouseGrabber;
	textbuffer : Strings.String;

PROCEDURE -ReadMouse() : LONGINT;
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	MOV ECX, 4
	MOV DX, 5658H
	IN EAX, DX;
	POP ECX
END ReadMouse;

PROCEDURE -WriteMouse(pos : LONGINT);
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	POP EBX
	MOV ECX, 5
	MOV DX, 5658H
	OUT DX, EAX;
	POP ECX
END WriteMouse;

PROCEDURE -SendLength(l : LONGINT);
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	POP EBX
	MOV ECX, 8
	MOV DX, 5658H
	OUT DX, EAX;
	POP ECX
END SendLength;

PROCEDURE -Send4Chars(chars : LONGINT);
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	POP EBX
	MOV ECX, 9
	MOV DX, 5658H
	OUT DX, EAX;
	POP ECX
END Send4Chars;

PROCEDURE -ReceiveLength() : LONGINT;
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	MOV ECX, 6
	MOV DX, 5658H
	IN EAX, DX;
	POP ECX
END ReceiveLength;

PROCEDURE -Receive4Chars() : LONGINT;
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	MOV ECX, 7
	MOV DX, 5658H
	IN EAX, DX
	POP ECX
END Receive4Chars;

PROCEDURE -GetVirtualHWVersion() : LONGINT;
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	MOV ECX, 11H
	MOV DX, 5658H
	IN EAX, DX
	POP ECX
END GetVirtualHWVersion;

PROCEDURE -GetVMWareVersion() : LONGINT;
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	MOV ECX, 0AH
	MOV DX, 5658H
	IN EAX, DX
	MOV EAX, ECX
	POP ECX
END GetVMWareVersion;

(*
PROCEDURE -GetDeviceInformation(nrnr : LONGINT) : LONGINT;
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	POP EBX
	MOV ECX, 0BH
	MOV DX, 5658H
	IN EAX, DX
	MOV EAX, EBX
	POP ECX
END GetDeviceInformation;
*)

PROCEDURE -SetGUIOptions(options: SET);
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	POP EBX
	MOV ECX, 0EX
	MOV DX, 5658H
	OUT DX, EAX;
	POP ECX
END SetGUIOptions;

PROCEDURE -GetGUIOptions(): SET;
CODE {SYSTEM.i386}
	PUSH ECX
	MOV EAX, 564D5868H
	MOV ECX, 0DX
	MOV DX, 5658H
	IN EAX, DX;
	POP ECX
END GetGUIOptions;

PROCEDURE SetMousePos(x, y : LONGINT);
VAR t : LONGINT;
BEGIN
	WriteMouse(x * 10000H + y);
	t := ReadMouse(); (* readback seems to trigger the mouse exit routine *)
END SetMousePos;

(*
PROCEDURE DevId; (* print one device ID...  only works for 1 device like this*)
VAR i, t : LONGINT; text : ARRAY 50 OF CHAR;
BEGIN
	FOR i := 0 TO 9 DO
		t := GetDeviceInformation(i * 4);
		SYSTEM.PUT32(ADDRESSOF(text[0]) + i * 4, t);
	END;
	KernelLog.String(text);
END DevId;
*)

PROCEDURE SetTextToClipBoard(CONST text : ARRAY OF CHAR);
VAR l, t, i: LONGINT;
BEGIN
	l := Strings.Length(text);
	SendLength(l);
	t := 0;
	FOR i := 0 TO (l - 1) DIV 4 DO
		t := SYSTEM.GET32(ADDRESSOF(text[i * 4]));
		Send4Chars(t);
	END;
END SetTextToClipBoard;

PROCEDURE GetTextFromClipBoard(VAR s : Strings.String);
VAR l, t, i, f : LONGINT;
BEGIN
	l := ReceiveLength();
	IF (l > 0) & (l < 10000H) THEN
		NEW(s, l + 5);
		f := ADDRESSOF(s[0]);
		FOR i := 0 TO (l - 1) DIV 4 DO
			t := Receive4Chars();
			SYSTEM.PUT32(f + i * 4, t);
		END;
	END
END GetTextFromClipBoard;

(* Copy the content of the host system clipboard to the specified text *)
PROCEDURE GetFromClipboard(text : Texts.Text);
VAR s : Strings.String;
BEGIN
	ASSERT((text # NIL) & (text.HasWriteLock()));
	GetTextFromClipBoard(s);
	IF (text.GetLength() > 0) THEN text.Delete(0, text.GetLength()); END;
	TextUtilities.StrToText(text, 0, s^);
END GetFromClipboard;

(* Copy the content of the specified text to the host system clipboard *)
PROCEDURE PutToClipboard(text : Texts.Text);
VAR buffer : Strings.String;
BEGIN
	ASSERT((text # NIL) & (text.HasReadLock()));
	TextUtilities.TextToStr(text, buffer^);
	SetTextToClipBoard(buffer^);
END PutToClipboard;

PROCEDURE GetHostClipboard*;
VAR s : Strings.String;
BEGIN
	GetTextFromClipBoard(s);
	Texts.clipboard.AcquireWrite;
	IF Texts.clipboard.GetLength() > 0 THEN Texts.clipboard.Delete(0, Texts.clipboard.GetLength()) END;
	TextUtilities.StrToText(Texts.clipboard, 0, s^);
	Texts.clipboard.ReleaseWrite;
	KernelLog.String("Copied host clipboard context"); KernelLog.Ln;
END GetHostClipboard;

PROCEDURE ClipboardChanged(sender, data : ANY);
BEGIN
	TextUtilities.TextToStr(Texts.clipboard, textbuffer^);
	SetTextToClipBoard(textbuffer^);
END ClipboardChanged;

(* This procedure is directly called by the window manager. It must be safe. *)
PROCEDURE MessagePreview(VAR m : WMMessages.Message; VAR discard : BOOLEAN);
BEGIN
	IF m.msgType = WMMessages.MsgPointer THEN
		SetMousePos(ENTIER((m.x - viewPort.range.l) * w / (viewPort.range.r - viewPort.range.l)) ,
					ENTIER((m.y  - viewPort.range.t) * h / (viewPort.range.b - viewPort.range.t)));
	END
END MessagePreview;

PROCEDURE Install*;
END Install;

PROCEDURE Cleanup;
BEGIN
	mouseGrabber.alive := FALSE;
	mouseGrabber.timer.Wakeup;
	SetGUIOptions({});
	(* removal must be done in all cases to avoid system freeze *)
	manager.RemoveMessagePreview(MessagePreview);
	Texts.clipboard.onTextChanged.Remove(ClipboardChanged);
	HostClipboard.SetHandlers(NIL, NIL);
END Cleanup;

BEGIN
	KernelLog.String("Bimbo-VMWare Tools Installed"); KernelLog.Ln;
	hw := GetVirtualHWVersion();
	KernelLog.String("VMVare Version : "); KernelLog.Int(GetVMWareVersion(), 0); KernelLog.Ln;
	KernelLog.String("Virtual Hardware Version : "); KernelLog.Int(hw, 0); KernelLog.Ln;
	KernelLog.String("VMWare GUI Bits :");
	oldGUIBits := GetGUIOptions();
	KernelLog.Bits(oldGUIBits, 0, 32); KernelLog.Ln;
	SetGUIOptions({0, 1, 2, 3, 4});

	NEW(textbuffer, 65536 + 5);

	(* register in clipboard *)
	Texts.clipboard.onTextChanged.Add(ClipboardChanged);

	(* register at host system clipboard interface *)
	HostClipboard.SetHandlers(GetFromClipboard, PutToClipboard);

	(* register in window manager *)
	manager := WMWindowManager.GetDefaultManager();
	viewPort := WMWindowManager.GetDefaultView();
	w := viewPort.width0;
	h := viewPort.height0;
	manager.InstallMessagePreview(MessagePreview);

	NEW(mouseGrabber);
	Modules.InstallTermHandler(Cleanup);
END VMWareTools.

VMWareTools.Install ~
VMWareTools.GetHostClipboard ~
SystemTools.Free VMWareTools ~

