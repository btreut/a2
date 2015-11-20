MODULE WMUnicodeIME; (** AUTHOR "tf, pl"; PURPOSE "Unicode input mode editor"; *)

IMPORT
	KernelLog, Modules, Strings, UTF8Strings,
	WMInputMethods, WMMessages,
	(* visual part *)
	WMRectangles, WMWindowManager, WMComponents, WMStandardComponents, WMEditors,
	WMGraphics;

CONST
	imeName* = "Unicode";

TYPE
	IMEWindow*  = OBJECT (WMComponents.FormWindow)
	VAR edit : WMEditors.Editor;
		curEditStr : ARRAY 64 OF CHAR;
		uniChar : WMStandardComponents.Label;
		font : WMGraphics.Font;

		ime : IME;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			ep, sb, sr, gb, gr, d : WMStandardComponents.Panel;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(200, 104); panel.fillColor.Set(0); panel.takesFocus.Set(TRUE);

			(* right shadow *)
			NEW(sr); sr.bounds.SetWidth(4); sr.alignment.Set(WMComponents.AlignRight); sr.fillColor.Set(0);
			panel.AddContent(sr);

			NEW(d); d.bounds.SetHeight(4); d.alignment.Set(WMComponents.AlignTop); d.fillColor.Set(0);
			sr.AddContent(d);

			NEW(gr); gr.alignment.Set(WMComponents.AlignClient); gr.fillColor.Set(080H);
			sr.AddContent(gr);

			(* bottom shadow *)
			NEW(sb); sb.bounds.SetHeight(4); sb.alignment.Set(WMComponents.AlignBottom); sb.fillColor.Set(0);
			panel.AddContent(sb);

			NEW(d); d.bounds.SetWidth(4); d.alignment.Set(WMComponents.AlignLeft); d.fillColor.Set(0);
			sb.AddContent(d);

			NEW(gb); gb.alignment.Set(WMComponents.AlignClient); gb.fillColor.Set(080H);
			sb.AddContent(gb);

			(* edit panel *)
			NEW(ep); ep.alignment.Set(WMComponents.AlignClient); ep.fillColor.Set(LONGINT(0DDDD00EEH));
			panel.AddContent(ep);

			NEW(edit); edit.bounds.SetHeight(20); edit.alignment.Set(WMComponents.AlignTop); edit.tv.showBorder.Set(TRUE);
			edit.tv.defaultTextBgColor.Set(0);

			edit.tv.borders.Set(WMRectangles.MakeRect(3, 3, 2, 2));
			edit.allowIME := FALSE;
			edit.multiLine.Set(FALSE);
			edit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			ep.AddContent(edit);

			(* preview Unicode Char *)
			NEW(uniChar); uniChar.alignment.Set(WMComponents.AlignClient);
			uniChar.textColor.Set(0000000FFH); uniChar.alignH.Set(WMGraphics.AlignCenter);
			uniChar.caption.SetAOC(""); uniChar.alignV.Set(WMGraphics.AlignTop);
			ep.AddContent(uniChar);

			RETURN panel
		END CreateForm;

		PROCEDURE &New*(ime : IME; x, y :LONGINT; CONST text : ARRAY OF CHAR);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm();
			SELF.ime := ime;
			edit.onEnter.Add(Ok);
			edit.tv.SetExtKeyEventHandler(EditKeyPressed);

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);

			font := WMGraphics.GetFont("Cyberbit", 60, {});
			IF font # NIL THEN uniChar.SetFont(font) END;

			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {});
			manager.SetFocus(SELF);
			edit.SetAsString(text);
			edit.SetFocus;
			edit.text.onTextChanged.Add(TextChanged);
		END New;

		PROCEDURE EditKeyPressed(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			handled := TRUE;
			IF keySym = 20H THEN (* space *)
				IF curEditStr = "" THEN ScheduleHide
				ELSE WriteSelected;
					(* private change, dont need to evaluate anything *)
					edit.text.onTextChanged.Remove(TextChanged);
					edit.SetAsString("");
					curEditStr := "";
					edit.text.onTextChanged.Add(TextChanged);
					ClearSelection
				END
			ELSIF keySym = 0FF08H THEN (* Inputs.KsBackSpace *)
				IF curEditStr = "" THEN ScheduleHide
				ELSE edit.KeyPressed(ucs, flags, keySym, handled)
				END
			ELSIF keySym = 0FF54H THEN (* Inputs.DownArrow *)
			ELSIF (keySym >= 48) & (keySym <= 57) THEN
				edit.KeyPressed(ucs, flags, keySym, handled)
			ELSIF keySym = 0FF0DH THEN (* enter *)
				edit.KeyPressed(ucs, flags, keySym, handled)
			END;
		END EditKeyPressed;

		PROCEDURE ScheduleHide;
		VAR msg : WMMessages.Message;
		BEGIN
			msg.msgType := WMMessages.MsgExt;
			msg.ext := SELF;
			IF ~sequencer.Add(msg) THEN KernelLog.String("IME Editor out of sync") END;
		END ScheduleHide;

		PROCEDURE WriteSelected;
		VAR uni : Strings.String;
		BEGIN
			uni := uniChar.caption.Get();
			ime.InsertUTF8String(uni^)
		END WriteSelected;

		PROCEDURE ClearSelection;
		BEGIN
			uniChar.caption.SetAOC("")
		END ClearSelection;

		PROCEDURE Ok*(sender, data:ANY);
		BEGIN
			WriteSelected;
			ScheduleHide
		END Ok;

		PROCEDURE TextChanged*(sender, data:ANY);
		VAR ch, no : LONGINT; charString : ARRAY 16 OF CHAR;

		BEGIN
			(* avoid recursion *)
			edit.text.onTextChanged.Remove(TextChanged);

			(* find representation for the unicode *)
			edit.GetAsString(curEditStr);
			IF Strings.Length(curEditStr) > 8 THEN
				uniChar.caption.SetAOC("overflow");
			ELSE
				uniChar.caption.SetAOC("");
				Strings.StrToInt(curEditStr, ch);

				no := 0;
				IF UTF8Strings.EncodeChar(ch, charString, no) THEN
					uniChar.caption.SetAOC(charString)
				ELSE
					uniChar.caption.SetAOC("error")
				END;

			END;

			edit.text.onTextChanged.Add(TextChanged)
		END TextChanged;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			ScheduleHide
		END FocusLost;

		PROCEDURE FocusGot;
		BEGIN
			manager.SetFocus(SELF)
		END FocusGot;

		PROCEDURE Hide;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			manager.Remove(SELF);
			ime.w := NIL;
		END Hide;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) THEN
				IF (x.ext = SELF) THEN Hide
				END
			ELSE Handle^(x)
			END
		END Handle;

	END IMEWindow;

TYPE
	IME* = OBJECT(WMInputMethods.IME)
	VAR
		w : IMEWindow;

		PROCEDURE GetName*() : Strings.String;
		BEGIN
			RETURN Strings.NewString(imeName);
		END GetName;

		PROCEDURE KeyEvent*(ucs : LONGINT; flags : SET; keysym : LONGINT);
		VAR x, y, pos : LONGINT; str : ARRAY 8 OF CHAR;
		BEGIN
			IF (ucs >= 48) & (ucs <= 57) THEN
				GetCursorScreenPosition(x, y);
				pos := 0; IF UTF8Strings.EncodeChar(ucs, str, pos) THEN END;
				NEW(w, SELF, x, y, str);
			ELSE InsertChar(ucs)
			END
		END KeyEvent;

		PROCEDURE Finalize;
		END Finalize;

	END IME;

(* ----------------------------------------- *)

(* installs the Unicode IME *)
PROCEDURE Install*;
VAR ime : IME;
BEGIN
	NEW(ime);
	WMInputMethods.InstallIME(ime);
END Install;

PROCEDURE Cleanup;
BEGIN
	IF (WMInputMethods.defaultIME # NIL) & (WMInputMethods.defaultIME IS IME) THEN
		WMInputMethods.defaultIME(IME).Finalize
	END;
	WMInputMethods.InstallIME(NIL)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END WMUnicodeIME.

-------------------------------------------------

SystemTools.Free WMUnicodeIME ~
WMUnicodeIME.Install ~
