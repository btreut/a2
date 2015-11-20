MODULE WMDialogs;	(** AUTHOR "TF"; PURPOSE "Standard dialogs"; *)

IMPORT
	KernelLog, Commands, Inputs, Texts, Strings, XML, Repositories,
	WMMessages, WMRectangles, WMGraphics, WMWindowManager, WMComponents, WMStandardComponents,WMEditors;

CONST
	(** Dialog types *)
	TUserInput* = 0;
	TConfirmation* = 1;
	TInformation* = 2;
	TWarning* = 3;
	TError* = 4;
	TCriticalError* = 5;
	TPassword* = 6;
	TLogin* = 7;
	TNoIcon* = 8; (** don't show an icon *)
	TQuestion* = 9;
	TAction* = 10;

	ResDialogFailure* = - 1;
	ResOk* = 0;
	ResNo* = 1;
	ResAbort* = 2;
	ResYes* = 4;
	ResAll* = 5;
	ResNever* = 6;
	ResIgnore* = 7;

	OkBtnId* = "OkBtn";
	AbortBtnId* = "AbortBtn";
	NoBtnId* = "NoBtn";
	YesBtnId* = "YesBtn";
	AllBtnId* = "AllBtn";
	NeverBtnId* = "NeverBtn";
	IgnoreBtnId* = "IgnoreBtn";

	ButtonWidth* = 60;
	LineHeight* = 30; (* Height of buttons, labels and editors *)

	(* Initial width and height of dialogs *)
	QueryStringWidth = 350;
	QueryStringHeight = 100;

	MessageWidth = 350;
	MessageHeight = 100;

	LoginWidth = 12 * 18;
	LoginHeight = 3 * LineHeight + 30;

	UserInfoWidth = 400;
	UserInfoHeight = 240;

	(* CustomDialog flags *)
	CdFrame* = 0; (* dialog window has a frame with close button *)
	CdStayOnTop* = 1; (* dialog window stays on top of other windows *)
	CdCloseWhenFocusLost*  = 2; (* dialog window is closed when loosing the keyboard focus *)

TYPE

	Dialog* = OBJECT(WMComponents.FormWindow)
	VAR
		result*, x*, y* : LONGINT;
		errors* : BOOLEAN;

		PROCEDURE Show*;
		BEGIN
			result := ResDialogFailure;
			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {WMWindowManager.FlagFrame});
			manager.SetFocus(SELF);
			BEGIN {EXCLUSIVE}
				AWAIT(result >= 0)
			END;
			manager.Remove(SELF);
		END Show;

		PROCEDURE SetType*(type : LONGINT);
		VAR name : ARRAY 128 OF CHAR;
		BEGIN
			CASE type OF
				|TUserInput: name := "WMIcons.tar://WMDialogsUserInput.png";
				|TConfirmation: name := "WMIcons.tar://WMDialogsConfirmation.png";
				|TInformation: name := "WMIcons.tar://WMDialogsInformation.png";
				|TWarning: name := "WMIcons.tar://WMDialogsWarning.png";
				|TError: name := "WMIcons.tar://WMDialogsError.png";
				|TCriticalError: name := "WMIcons.tar://WMDialogsCriticalError.png";
				|TPassword: name := "WMIcons.tar://WMDialogsPassword.png";
				|TLogin: name := "WMIcons.tar://WMDialogsLogin.png";
			ELSE
				name := "WMIcons.tar://WMDialogsUnknown.png";
			END;
			IF (type # TNoIcon) THEN
				SetIcon(WMGraphics.LoadImage(name, TRUE));
			END;
		END SetType;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			result := ResAbort;
		END Close;

		PROCEDURE Ok*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := ResOk
		END Ok;

		PROCEDURE Abort*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := ResAbort
		END Abort;

		PROCEDURE No*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := ResNo
		END No;

		PROCEDURE Yes*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := ResYes
		END Yes;

		PROCEDURE All*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := ResAll
		END All;

		PROCEDURE Never*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := ResNever
		END Never;

		PROCEDURE Ignore*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := ResIgnore
		END Ignore;

		PROCEDURE WireError*(CONST detectedBy, msg: ARRAY OF CHAR);
		BEGIN
			errors := TRUE;
			KernelLog.String("WMDialogs - Wiring error : "); KernelLog.String(detectedBy); KernelLog.String(" - "); KernelLog.String(msg); KernelLog.Ln
		END WireError;

		PROCEDURE Handle(VAR msg : WMMessages.Message);
		BEGIN
			IF (msg.msgType = WMMessages.MsgKey) & (msg.y = Inputs.KsEscape) & (msg.flags = {}) THEN
				Close;
			ELSE
				Handle^(msg)
			END;
		END Handle;

	END Dialog;

TYPE

	(** Open a query string dialog *)
	QueryStringDlg* = OBJECT (Dialog)
	VAR
		edit : WMEditors.Editor;
		content : WMComponents.VisualComponent;
		ok, abort : WMStandardComponents.Button;

		PROCEDURE &New*;
		BEGIN
			errors := FALSE;
			content := CreateDialog();
			WireDialog;
			Init(QueryStringWidth, QueryStringHeight, FALSE);
			SetContent(content);
			IF edit # NIL THEN edit.SetFocus; edit.SetFocus; END;
		END New;

		PROCEDURE CreateDialog() : WMComponents.VisualComponent;
		VAR
			line, panel : WMStandardComponents.Panel;
			manager : WMWindowManager.WindowManager;
			windowStyle : WMWindowManager.WindowStyle;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			windowStyle := manager.GetStyle();

			panel := NewPanel(windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			panel.takesFocus.Set(FALSE);

			(* Input *)
			edit := NewEditor("Input", windowStyle.fgColor, windowStyle.bgColor, WMComponents.AlignTop, 0, LineHeight);
			edit.bearing.Set(WMRectangles.MakeRect(10, 10, 10, 10));
			panel.AddContent(edit);

			(* Buttons *)
			line := NewPanel(windowStyle.bgColor, WMComponents.AlignBottom, 0, LineHeight);
			panel.AddContent(line);

			abort := InstantiateButton(AbortBtnId, "Abort"); line.AddContent(abort);
			abort.bounds.SetWidth(ButtonWidth); abort.alignment.Set(WMComponents.AlignRight);

			ok := InstantiateButton(OkBtnId, "Ok"); line.AddContent(ok);
			ok.bounds.SetWidth(ButtonWidth); ok.alignment.Set(WMComponents.AlignRight);

			RETURN panel;
		END CreateDialog;

		PROCEDURE WireDialog;
		VAR c : WMComponents.Component;
		BEGIN
			c := FindComponent(content, "Input");
			IF (c # NIL) & (c IS WMEditors.Editor) THEN edit := c(WMEditors.Editor) END;

			IF edit = NIL THEN  WireError("QueryStringDlg", "Required component 'Input' not found."); RETURN END;

			ok := FindButton(content, OkBtnId);
			abort := FindButton(content, AbortBtnId);
			IF ok = NIL THEN WireError("QueryStringDlg", "Required component 'Ok' not found."); RETURN END;
			IF abort = NIL THEN WireError("QueryStringDlg", "Required component 'Abort' not found."); RETURN END;

			ok.onClick.Add(Ok);
			abort.onClick.Add(Abort);
			edit.onEnter.Add(Ok)
		END WireDialog;

	END QueryStringDlg;

TYPE

	(** Generic Message Dialog  *)
	MessageDlg* =OBJECT(Dialog)
	VAR
		buttons : SET;
		msg : WMEditors.Editor; ok, abort, no, yes, all, never: WMStandardComponents.Button;
		content : WMComponents.VisualComponent;

		PROCEDURE &New*(buttons : SET);
		BEGIN
			errors := FALSE;
			SELF.buttons := buttons;
			CreateDialog;
			WireDialog;
			Init(MessageWidth, MessageHeight, FALSE);
			SetContent(content)
		END New;

		PROCEDURE CreateDialog;
		VAR
			panel, buttonPanel : WMStandardComponents.Panel;
			manager : WMWindowManager.WindowManager;
			windowStyle : WMWindowManager.WindowStyle;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			windowStyle := manager.GetStyle();

			panel := NewPanel(windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			panel.takesFocus.Set(TRUE);

			NEW(buttonPanel); buttonPanel.bounds.SetHeight(LineHeight); buttonPanel.alignment.Set(WMComponents.AlignBottom);
			panel.AddContent(buttonPanel);

			abort := InstantiateButton(AbortBtnId, "Abort"); buttonPanel.AddContent(abort);
			abort.bounds.SetWidth(ButtonWidth); abort.alignment.Set(WMComponents.AlignRight);

			no := InstantiateButton(NoBtnId, "No"); buttonPanel.AddContent(no);
			no.bounds.SetWidth(ButtonWidth); no.alignment.Set(WMComponents.AlignRight);

			never := InstantiateButton(NeverBtnId, "Never"); buttonPanel.AddContent(never);
			never.bounds.SetWidth(ButtonWidth); never.alignment.Set(WMComponents.AlignRight);

			all := InstantiateButton(AllBtnId, "All"); buttonPanel.AddContent(all);
			all.bounds.SetWidth(ButtonWidth); all.alignment.Set(WMComponents.AlignRight);

			yes := InstantiateButton(YesBtnId, "Yes"); buttonPanel.AddContent(yes);
			yes.bounds.SetWidth(ButtonWidth); yes.alignment.Set(WMComponents.AlignRight);

			ok := InstantiateButton(OkBtnId, "Ok"); buttonPanel.AddContent(ok);
			ok.bounds.SetWidth(ButtonWidth); ok.alignment.Set(WMComponents.AlignRight);

			msg := NewEditor("Msg", windowStyle.fgColor, windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			msg.bearing.Set(WMRectangles.MakeRect(10, 10, 10, 10));
			msg.readOnly.Set(TRUE);
			msg.takesFocus.Set(FALSE);
			panel.AddContent(msg);

			content := panel;
		END CreateDialog;

		PROCEDURE WireDialog;
		VAR c : WMComponents.Component;
		BEGIN
			c := FindComponent(content, "Msg");
			IF (c # NIL) & (c IS WMEditors.Editor) THEN msg := c(WMEditors.Editor) END;

			ok := FindButton(content, OkBtnId);
			no := FindButton(content, NoBtnId);
			abort := FindButton(content, AbortBtnId);
			yes := FindButton(content, YesBtnId);
			all := FindButton(content, AllBtnId);

			IF msg = NIL THEN
				WireError("QueryStringDlg", "Required component 'Input' not found.")
			END;

			IF ok # NIL THEN ok.onClick.Add(Ok) END;
			IF abort # NIL THEN abort.onClick.Add(Abort) END;
			IF no # NIL THEN no.onClick.Add(No) END;
			IF yes # NIL THEN yes.onClick.Add(Yes) END;
			IF all # NIL THEN all.onClick.Add(All) END;
			IF never # NIL THEN never.onClick.Add(Never) END;

			IF abort # NIL THEN abort.visible.Set(ResAbort IN buttons) END;
			IF no # NIL THEN no.visible.Set(ResNo IN buttons) END;
			IF ok # NIL THEN ok.visible.Set(ResOk IN buttons) END;
			IF yes # NIL THEN yes.visible.Set(ResYes IN buttons) END;
			IF all # NIL THEN all.visible.Set(ResAll IN buttons) END;
			IF never # NIL THEN never.visible.Set(ResNever IN buttons) END;

			IF (abort # NIL) & (ResAbort IN buttons) THEN abort.SetFocus;
			ELSIF (no # NIL) & (ResNo IN buttons)  THEN no.SetFocus;
			ELSIF (never # NIL) & (ResNever IN buttons) THEN never.SetFocus;
			ELSIF (ok # NIL) & (ResOk IN buttons)  THEN ok.SetFocus;
			ELSIF (yes # NIL) & (ResYes IN buttons) THEN yes.SetFocus;
			ELSIF (all # NIL) & (ResAll IN buttons) THEN all.SetFocus;
			END;
		END WireDialog;

	END MessageDlg;

TYPE

	LoginDlg* = OBJECT (Dialog)
	VAR
		editUser, editPassword: WMEditors.Editor;
		ok, abort: WMStandardComponents.Button;
		content: WMComponents.VisualComponent;

     	 	PROCEDURE &New*;
     	 	BEGIN
			errors := FALSE;
			CreateDialog;
			WireDialog;

          		Init(LoginWidth, LoginHeight, FALSE);
			SetContent (content);

			IF editUser # NIL THEN editUser.SetFocus; editUser.SetFocus; END;
		END New;

		PROCEDURE CreateDialog;
		VAR
			line, panel: WMStandardComponents.Panel;
			label : WMStandardComponents.Label;
			manager: WMWindowManager.WindowManager;
			windowStyle: WMWindowManager.WindowStyle;
		CONST
			LabelWidth = 60;
		BEGIN
			manager := WMWindowManager.GetDefaultManager ();
			windowStyle := manager.GetStyle ();

          		panel := NewPanel(windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
          		panel.takesFocus.Set(FALSE);

          		(* Username *)
          		line := NewPanel(windowStyle.bgColor, WMComponents.AlignTop, 0, LineHeight);
          		line.bearing.Set(WMRectangles.MakeRect(10, 10, 10, 5));
			line.takesFocus.Set(FALSE);
          		panel.AddContent(line);

          		label := NewLabel("User: ", WMComponents.AlignLeft, LabelWidth, 0);
			label.alignH.Set(WMGraphics.AlignRight);
			label.takesFocus.Set(FALSE);
			line.AddContent(label);

			editUser := NewEditor("Login", windowStyle.fgColor, windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			editUser.needsTab.Set(FALSE);
			editUser.takesFocus.Set(TRUE);
			editUser.tv.needsTab.Set(FALSE);
			editUser.tv.takesFocus.Set(TRUE);
			line.AddContent (editUser);

			(* Password *)
			line := NewPanel(windowStyle.bgColor, WMComponents.AlignTop, 0, LineHeight);
			line.bearing.Set(WMRectangles.MakeRect(10, 5, 10, 5));
          		line.takesFocus.Set(FALSE);
          		panel.AddContent(line);

          		label := NewLabel("Password: ", WMComponents.AlignLeft, LabelWidth, 0);
			label.alignH.Set (WMGraphics.AlignRight);
			label.takesFocus.Set(FALSE);
			line.AddContent (label);

			editPassword := NewEditor("Password", windowStyle.fgColor, windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			editPassword.takesFocus.Set(TRUE);
			editPassword.needsTab.Set(FALSE);
			editPassword.tv.isPassword.Set(TRUE);
			editPassword.tv.needsTab.Set(FALSE);
			line.AddContent (editPassword);

          		(* Buttons *)
			line := NewPanel(windowStyle.bgColor, WMComponents.AlignBottom, 0, LineHeight);
			panel.AddContent(line);

			abort := InstantiateButton(AbortBtnId, "Abort");
			abort.bounds.SetWidth(ButtonWidth); abort.alignment.Set(WMComponents.AlignRight);
			line.AddContent (abort);

          		ok := InstantiateButton(OkBtnId, "Ok");
			ok.bounds.SetWidth(ButtonWidth); ok.alignment.Set(WMComponents.AlignRight);
			line.AddContent (ok);

			content := panel
		END CreateDialog;

	      	PROCEDURE WireDialog;
		VAR c: WMComponents.Component;
		BEGIN
			c := FindComponent (content, "Login");
			IF (c # NIL) & (c IS WMEditors.Editor) THEN editUser := c (WMEditors.Editor) END;

			IF editUser = NIL THEN
				WireError ("LoginDlg", "Required component 'Login' not found."); RETURN
			END;

			c := FindComponent (content, "Password");
			IF (c # NIL) & (c IS WMEditors.Editor) THEN editPassword := c (WMEditors.Editor) END;

			IF editPassword = NIL THEN
				WireError ("LoginDlg", "Required component 'Password' not found."); RETURN
			END;

			ok := FindButton (content, OkBtnId);
			abort := FindButton (content, AbortBtnId);
			IF ok = NIL THEN WireError ("LoginDlg", "Required component 'Ok' not found."); RETURN END;
			IF abort = NIL THEN WireError ("LoginDlg", "Required component 'Abort' not found."); RETURN END;

			ok.onClick.Add (Ok);
			abort.onClick.Add (Abort);
			editUser.onEnter.Add (Ok);
			editPassword.onEnter.Add (Ok);
	        END WireDialog;

	END LoginDlg;

TYPE
	(** Dialog that allows to get basic User Info *)
	UserInfoDlg* = OBJECT (Dialog)
	VAR
		editShortName, editFullName, editEMail, editPassword, editPasswordConfirm: WMEditors.Editor;
		ok, abort: WMStandardComponents.Button;
		content: WMComponents.VisualComponent;

		PROCEDURE &New*;
		BEGIN
			errors := FALSE;
			CreateDialog;
			WireDialog;

			Init(UserInfoWidth, UserInfoHeight, FALSE);
			SetContent (content);

			IF editShortName # NIL THEN editShortName.SetFocus; editShortName.SetFocus END
		END New;

		PROCEDURE CreateDialog;
		VAR
			line, panel : WMStandardComponents.Panel;
			label : WMStandardComponents.Label;
			manager: WMWindowManager.WindowManager;
			windowStyle: WMWindowManager.WindowStyle;
		CONST
			LabelWidth = 120;
		BEGIN
			manager := WMWindowManager.GetDefaultManager ();
			windowStyle := manager.GetStyle ();

			panel := NewPanel(windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			panel.takesFocus.Set(FALSE);

			(* Short Name *)
			line := NewPanel(windowStyle.bgColor, WMComponents.AlignTop, 0, LineHeight);
			line.bearing.Set(WMRectangles.MakeRect(10, 10, 10, 5));
			panel.AddContent(line);

			label := NewLabel("Short Name: ", WMComponents.AlignLeft, LabelWidth, 0);
			label.alignH.Set(WMGraphics.AlignRight);
			line.AddContent(label);

			editShortName := NewEditor("ShortName", windowStyle.fgColor, windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			line.AddContent (editShortName);

			(* Full Name *)
			line := NewPanel(windowStyle.bgColor, WMComponents.AlignTop, 0, LineHeight);
			line.bearing.Set(WMRectangles.MakeRect(10, 5, 10, 5));
			panel.AddContent(line);

			label := NewLabel("Full Name: ", WMComponents.AlignLeft, LabelWidth, 0);
			label.alignH.Set (WMGraphics.AlignRight);
			line.AddContent (label);

			editFullName := NewEditor("FullName", windowStyle.fgColor, windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			line.AddContent (editFullName);

			(* E-Mail *)
			line := NewPanel(windowStyle.bgColor, WMComponents.AlignTop, 0, LineHeight);
			line.bearing.Set(WMRectangles.MakeRect(10, 5, 10, 5));
			panel.AddContent(line);

			label := NewLabel("E-Mail: ", WMComponents.AlignLeft, LabelWidth, 0);
			label.alignH.Set (WMGraphics.AlignRight);
			line.AddContent (label);

			editEMail := NewEditor("EMail", windowStyle.fgColor, windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			line.AddContent (editEMail);

			(* Password *)
			line := NewPanel(windowStyle.bgColor, WMComponents.AlignTop, 0, LineHeight);
			line.bearing.Set(WMRectangles.MakeRect(10, 5, 10, 5));
			panel.AddContent(line);

			label := NewLabel("Password: ", WMComponents.AlignLeft, LabelWidth, 0);
			label.alignH.Set (WMGraphics.AlignRight);
			line.AddContent (label);

			editPassword := NewEditor("Password", windowStyle.fgColor, windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			editPassword.tv.isPassword.Set (TRUE);
			line.AddContent (editPassword);

			(* Password Confirm *)
			line := NewPanel(windowStyle.bgColor, WMComponents.AlignTop, 0, LineHeight);
			line.bearing.Set(WMRectangles.MakeRect(10, 5, 10, 5));
			panel.AddContent(line);

			label := NewLabel("Password Confirm: ", WMComponents.AlignLeft, LabelWidth, 0);
			label.alignH.Set (WMGraphics.AlignRight);
			line.AddContent (label);

			editPassword := NewEditor("PasswordConfirm", windowStyle.fgColor, windowStyle.bgColor, WMComponents.AlignClient, 0, 0);
			editPassword.tv.isPassword.Set (TRUE);
			line.AddContent (editPassword);

			(* Buttons *)
			line := NewPanel(windowStyle.bgColor, WMComponents.AlignBottom, 0, LineHeight);
			panel.AddContent(line);

			abort := InstantiateButton (AbortBtnId, "Abort"); line.AddContent (abort);
			abort.bounds.SetWidth (ButtonWidth); abort.alignment.Set (WMComponents.AlignRight);

			ok := InstantiateButton (OkBtnId, "Ok"); line.AddContent (ok);
			ok.bounds.SetWidth (ButtonWidth); ok.alignment.Set (WMComponents.AlignRight);

			content := panel
		END CreateDialog;

		PROCEDURE WireDialog;
		VAR c: WMComponents.Component;
		BEGIN
			c := FindComponent (content, "FullName");
			IF (c # NIL) & (c IS WMEditors.Editor) THEN editFullName := c (WMEditors.Editor) END;

			IF editFullName = NIL THEN
				WireError ("UserInfoDlg", "Required component 'FullName' not found."); RETURN
			END;

			c := FindComponent (content, "EMail");
			IF (c # NIL) & (c IS WMEditors.Editor) THEN editEMail := c (WMEditors.Editor) END;

			IF editPassword = NIL THEN
				WireError ("UserInfoDlg", "Required component 'EMail' not found."); RETURN
			END;

			c := FindComponent (content, "Password");
			IF (c # NIL) & (c IS WMEditors.Editor) THEN editPassword := c (WMEditors.Editor) END;

			IF editPassword = NIL THEN
				WireError ("UserInfoDlg", "Required component 'Password' not found."); RETURN
			END;

			c := FindComponent (content, "PasswordConfirm");
			IF (c # NIL) & (c IS WMEditors.Editor) THEN editPasswordConfirm := c (WMEditors.Editor) END;

			IF editPasswordConfirm = NIL THEN
				WireError ("UserInfoDlg", "Required component 'PasswordConfirm' not found."); RETURN
			END;

			ok := FindButton (content, OkBtnId);
			abort := FindButton (content, AbortBtnId);
			IF ok = NIL THEN WireError ("UserInfoDlg", "Required component 'Ok' not found."); RETURN END;
			IF abort = NIL THEN WireError ("UserInfoDlg", "Required component 'Abort' not found."); RETURN END;

			ok.onClick.Add (Ok);
			abort.onClick.Add (Abort);
			editPasswordConfirm.onEnter.Add (Ok);
		END WireDialog;

	END UserInfoDlg;

TYPE

	MiniStringInput*  = OBJECT (WMComponents.FormWindow)
	VAR
		edit : WMEditors.Editor;
		result : LONGINT;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			ep, sb, sr, gb, gr, d : WMStandardComponents.Panel;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(200, 25); panel.fillColor.Set(0); panel.takesFocus.Set(TRUE);

			(* bottom shadow *)
			NEW(sb); sb.bounds.SetHeight(4); sb.alignment.Set(WMComponents.AlignBottom); sb.fillColor.Set(0);
			panel.AddContent(sb);

			NEW(d); d.bounds.SetWidth(4); d.alignment.Set(WMComponents.AlignLeft); d.fillColor.Set(0);
			sb.AddContent(d);

			NEW(gb); gb.alignment.Set(WMComponents.AlignClient); gb.fillColor.Set(080H);
			sb.AddContent(gb);

			(* right shadow *)
			NEW(sr); sr.bounds.SetWidth(4); sr.alignment.Set(WMComponents.AlignRight); sr.fillColor.Set(0);
			panel.AddContent(sr);

			NEW(d); d.bounds.SetHeight(4); d.alignment.Set(WMComponents.AlignTop); d.fillColor.Set(0);
			sr.AddContent(d);

			NEW(gr); gr.alignment.Set(WMComponents.AlignClient); gr.fillColor.Set(080H);
			sr.AddContent(gr);

			(* edit panel *)
			NEW(ep); ep.alignment.Set(WMComponents.AlignClient); ep.fillColor.Set(LONGINT(0DDDD00EEH));
			panel.AddContent(ep);

			NEW(edit); edit.alignment.Set(WMComponents.AlignClient); edit.tv.showBorder.Set(TRUE);
			edit.tv.defaultTextBgColor.Set(0);
			edit.tv.borders.Set(WMRectangles.MakeRect(3, 3, 2, 2));
			edit.multiLine.Set(FALSE);
			edit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			ep.AddContent(edit);
			RETURN panel
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			vc := CreateForm();
			edit.onEnter.Add(Ok);
			edit.onEscape.Add(Abort);
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			manager := WMWindowManager.GetDefaultManager();
		END New;

		PROCEDURE Ok*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := ResOk
		END Ok;

		PROCEDURE Abort*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := ResAbort
		END Abort;

		PROCEDURE Show*(x, y : LONGINT; VAR text : ARRAY OF CHAR) : LONGINT;
		BEGIN
			result := -1;
			edit.SetAsString(text);
			manager.Add(x, y, SELF, {});
			manager.SetFocus(SELF);
			edit.SetFocus;
			BEGIN {EXCLUSIVE}
				AWAIT(result >= 0)
			END;
			manager.Remove(SELF);
			IF result = ResOk THEN
				edit.GetAsString(text)
			END;
			RETURN result
		END Show;

		PROCEDURE FocusLost;
		BEGIN {EXCLUSIVE}
			result := ResAbort
		END FocusLost;

	END MiniStringInput;

TYPE

	(**
		The CustomDialog displays a component composition in a transluent window. The size
		of the window is determined by the component composition which is loaded from a repository.
		The window is made visible using the Show procedure which blocks until the window is closed.
		The 'res' parameter of this procedure results the UID of the button that caused the window to be
		closed (in applicable) *)
	CustomDialog* = OBJECT(WMComponents.FormWindow)
	VAR
		closed : BOOLEAN;
		closingComponent : WMComponents.Component;
		xflags : SET;

		(**	Create an instance of the CustomDialog window. 'dialog' is a string reference to a component stored in a repository.
			'width' and 'height' are taken from the component that is loaded. Only use this instance when res = ResOk *)
		PROCEDURE &New*(CONST dialog : ARRAY OF CHAR; VAR width, height, res : LONGINT);
		VAR
			content : WMComponents.VisualComponent;
			c : Repositories.Component; rect : WMRectangles.Rectangle;
		BEGIN
			closed := FALSE; closingComponent := NIL; xflags := {};
			Repositories.GetComponentByString(dialog, c, res);
			IF (res = Repositories.Ok) & (c IS WMComponents.VisualComponent) THEN
				content := c (WMComponents.VisualComponent);
				rect := content.bounds.Get();
				width := content.bounds.GetWidth(); height := content.bounds.GetHeight();
				IF (width > 0) & (height > 0) THEN
					WMRectangles.MoveRel(rect, -rect.l, -rect.t);
					content.bounds.Set(rect);
					Init(width, height, TRUE);
					SetContent(content);
					content.Traverse(WireComponents, NIL);
				ELSE
					res := ResDialogFailure;
				END;
			ELSE
				res := ResDialogFailure;
			END;
		END New;

		(** Show the dialog window at position (x, y). This procedure is blocking until the window is closed.
			Flags are CdFrame, CdStayOnTop and CdCloseWhenFocusLost. 'res' is set to the UID of the button that
			caused the window to be closed if applicable *)
		PROCEDURE Show*(x, y : LONGINT; flags : SET; VAR res : ARRAY OF CHAR);
		VAR string : Strings.String; wflags : SET;
		BEGIN
			res := "";
			wflags := {WMWindowManager.FlagHidden};
			IF (CdFrame IN flags) THEN wflags := wflags + {WMWindowManager.FlagFrame, WMWindowManager.FlagClose}; END;
			IF (CdStayOnTop IN flags) THEN wflags := wflags + {WMWindowManager.FlagStayOnTop}; END;
			WMWindowManager.ExtAddWindow(SELF, x, y, wflags);
			BEGIN {EXCLUSIVE} AWAIT(closed); END;
			IF (closingComponent # NIL) THEN
				string := closingComponent.uid.Get();
				IF (string # NIL) THEN COPY(string^, res); END;
			END;
		END Show;

		PROCEDURE WireComponents(c : XML.Content; data : ANY);
		BEGIN
			IF (c # NIL) & (c IS WMStandardComponents.Button) THEN
				c(WMStandardComponents.Button).onClick.Add(HandleEvents);
			END;
		END WireComponents;

		PROCEDURE HandleEvents(sender, data : ANY);
		BEGIN
			IF (sender # NIL) & (sender IS WMComponents.Component) THEN
				closingComponent := sender (WMComponents.Component);
			END;
			Close;
		END HandleEvents;

		PROCEDURE FocusLost;
		BEGIN
			FocusLost^;
			IF (CdCloseWhenFocusLost IN xflags) THEN Close; END;
		END FocusLost;

		PROCEDURE Close;
		BEGIN
			Close^;
			BEGIN {EXCLUSIVE} closed := TRUE; END;
		END Close;

	END CustomDialog;


(** Helper procedures *)

PROCEDURE NewPanel(fillColor, alignment, width, height : LONGINT) : WMStandardComponents.Panel;
VAR panel : WMStandardComponents.Panel;
BEGIN
	NEW(panel); panel.alignment.Set(alignment); panel.bounds.SetExtents(width, height);
	panel.fillColor.Set(fillColor);
	RETURN panel;
END NewPanel;

PROCEDURE NewLabel*(CONST caption : ARRAY OF CHAR; alignment, width, height : LONGINT) : WMStandardComponents.Label;
VAR label : WMStandardComponents.Label;
BEGIN
	NEW(label); label.alignment.Set(alignment); label.bounds.SetExtents(width, height);
	label.caption.SetAOC(caption);
	RETURN label;
END NewLabel;

PROCEDURE NewEditor*(CONST uid : ARRAY OF CHAR; textColor, textBgColor, alignment, width, height : LONGINT) : WMEditors.Editor;
VAR editor : WMEditors.Editor;
BEGIN
	NEW(editor); editor.uid.SetAOC(uid);
	editor.alignment.Set(alignment); editor.bounds.SetExtents(width, height);
	editor.tv.defaultTextColor.Set(textColor);
	editor.tv.defaultTextBgColor.Set(textBgColor);
	editor.multiLine.Set (FALSE);
	editor.tv.borders.Set (WMRectangles.MakeRect(5, 2, 3, 2));
	editor.tv.showBorder.Set (TRUE);
	RETURN editor;
END NewEditor;

(** Exported for implementation of Dialog subclasses *)

PROCEDURE InstantiateButton*(CONST uid, caption : ARRAY OF CHAR) : WMStandardComponents.Button;
VAR b : WMStandardComponents.Button;
BEGIN
	NEW(b); b.caption.SetAOC(caption);
	b.uid.SetAOC(uid);
	b.takesFocus.Set(TRUE);
	RETURN b
END InstantiateButton;

PROCEDURE FindComponent*(c : WMComponents.Component; CONST id : ARRAY OF CHAR) : WMComponents.Component;
BEGIN
	RETURN c.FindByUID(id)
END FindComponent;

PROCEDURE FindButton*(c : WMComponents.Component; CONST id : ARRAY OF CHAR) : WMStandardComponents.Button;
VAR tc : WMComponents.Component;
BEGIN
	tc := c.FindByUID(id);
	IF (tc # NIL) & (tc IS WMStandardComponents.Button) THEN RETURN tc(WMStandardComponents.Button) END;
	RETURN NIL
END FindButton;

(** Given the width and height of a visual components or window, calculate the center position (x, y) *)
PROCEDURE DefaultPos*(VAR x, y : LONGINT; width, height : LONGINT);
VAR manager : WMWindowManager.WindowManager;
	vp : WMWindowManager.ViewPort;
	s : WMWindowManager.WindowStyle;
BEGIN
	manager := WMWindowManager.GetDefaultManager();
	vp := WMWindowManager.GetDefaultView();
	s := manager.GetStyle();
	x := ENTIER(vp.range.l + (vp.range.r - vp.range.l - width) / 2);
	y := ENTIER(vp.range.t + (vp.range.b - vp.range.t - height) / 2);
	IF s # NIL THEN y := y +  s.th END;
END DefaultPos;


(** Open a string query dialog at position x, y with title caption and default value string.
	Return ResOk or ResAbort. If res is ResOk string contains the utf8 string. String is not changed if
	res is ResAbort *)
PROCEDURE QueryStringXY*(x, y : LONGINT; CONST caption : ARRAY OF CHAR; VAR string : ARRAY OF CHAR) : LONGINT;
VAR qsd : QueryStringDlg;
BEGIN
	NEW(qsd);
	IF ~qsd.errors THEN
		qsd.SetTitle(Strings.NewString(caption)); qsd.edit.SetAsString(string); qsd.edit.tv.SelectAll();
		qsd.SetType(TUserInput);
		qsd.x := x; qsd.y := y; qsd.Show;
		IF qsd.result = ResOk THEN qsd.edit.GetAsString(string) END;
		RETURN qsd.result
	ELSE RETURN ResDialogFailure
	END
END QueryStringXY;

(** Open a string query at default position with title caption and default value string.
	Return ResOk or ResAbort. If res is ResOk string contains the utf8 string. String is not changed if
	res is ResAbort *)
PROCEDURE QueryString*(CONST caption : ARRAY OF CHAR; VAR string : ARRAY OF CHAR) : LONGINT;
VAR x, y : LONGINT;
BEGIN
	DefaultPos(x, y, QueryStringWidth, QueryStringHeight);
	RETURN QueryStringXY(x, y, caption, string)
END QueryString;


(** Open a string query dialog at position x, y with title caption and default value string.
	Return ResOk or ResAbort. If res is ResOk string contains the utf8 string. String is not changed if
	res is ResAbort *)
PROCEDURE QueryPasswordXY*(x, y : LONGINT; CONST caption : ARRAY OF CHAR;  VAR string : ARRAY OF CHAR) : LONGINT;
VAR qsd : QueryStringDlg;
BEGIN
	NEW(qsd);
	IF ~qsd.errors THEN
		qsd.SetTitle(Strings.NewString(caption)); qsd.edit.tv.isPassword.Set(TRUE); qsd.edit.SetAsString(string);  qsd.edit.tv.SelectAll();
		qsd.SetType(TPassword);
		qsd.x := x; qsd.y := y; qsd.Show;
		IF qsd.result = ResOk THEN qsd.edit.GetAsString(string) END;
		RETURN qsd.result
	ELSE RETURN ResDialogFailure
	END
END QueryPasswordXY;

(** Open a string query at default position with title caption and default value string.
	Return ResOk or ResAbort. If res is ResOk string contains the utf8 string. String is not changed if
	res is ResAbort *)
PROCEDURE QueryPassword*(CONST caption : ARRAY OF CHAR; VAR string : ARRAY OF CHAR) : LONGINT;
VAR x, y : LONGINT;
BEGIN
	DefaultPos(x, y, QueryStringWidth, QueryStringHeight);
	RETURN QueryPasswordXY(x, y, caption, string)
END QueryPassword;


(** Open a message dialog at position x, y*)
PROCEDURE MessageXY*(type, x, y : LONGINT; CONST caption, string : ARRAY OF CHAR; buttons : SET) : LONGINT;
VAR qsd : MessageDlg;
BEGIN
	NEW(qsd, buttons);
	IF ~qsd.errors THEN
		qsd.SetTitle(Strings.NewString(caption)); qsd.msg.SetAsString(string);
		qsd.SetType(type);
		qsd.x := x; qsd.y := y; qsd.Show;
		RETURN qsd.result
	ELSE RETURN ResDialogFailure
	END
END MessageXY;

(** Open a string query at default position with title caption and default value string.
	Return ResOk or ResAbort. If res is ResOk string contains the utf8 string. String is not changed if
	res is ResAbort *)
PROCEDURE Message*(type : LONGINT; CONST caption, string : ARRAY OF CHAR; buttons : SET) : LONGINT;
VAR x, y : LONGINT;
BEGIN
	DefaultPos(x, y, MessageWidth, MessageHeight);
	RETURN MessageXY(type, x, y, caption, string, buttons)
END Message;

PROCEDURE Information*(CONST caption, string : ARRAY OF CHAR);
VAR ignore : LONGINT;
BEGIN
	ignore := Message(TInformation, caption, string, {ResOk});
END Information;

PROCEDURE Warning*(CONST caption, string : ARRAY OF CHAR);
VAR ignore : LONGINT;
BEGIN
	ignore := Message(TWarning, caption, string, {ResOk});
END Warning;

PROCEDURE Error*(CONST caption, string : ARRAY OF CHAR);
VAR ignore : LONGINT;
BEGIN
	ignore := Message(TError, caption, string, {ResOk});
END Error;

PROCEDURE Confirmation*(CONST caption, string : ARRAY OF CHAR) : LONGINT;
BEGIN
	RETURN Message(TConfirmation, caption, string, {ResYes, ResNo});
END Confirmation;

(** Open a string query dialog at position x, y with title caption and default value string.
	Return ResOk or ResAbort. If res is ResOk string contains the utf8 string. String is not changed if
	res is ResAbort *)
PROCEDURE TextMessageXY*(type, x, y : LONGINT; CONST caption: ARRAY OF CHAR; text : Texts.Text; buttons : SET) : LONGINT;
VAR qsd : MessageDlg;
BEGIN
	NEW(qsd, buttons);
	IF ~qsd.errors THEN
		qsd.SetTitle(Strings.NewString(caption)); qsd.msg.SetText(text);
		qsd.SetType(type);
		qsd.x := x; qsd.y := y; qsd.Show;
		RETURN qsd.result
	ELSE RETURN ResDialogFailure
	END
END TextMessageXY;

(** Open a string query at default position with title caption and default value string.
	Return ResOk or ResAbort. If res is ResOk string contains the utf8 string. String is not changed if
	res is ResAbort *)
PROCEDURE TextMessage*(type : LONGINT; CONST caption : ARRAY OF CHAR; text : Texts.Text; buttons : SET) : LONGINT;
VAR x, y : LONGINT;
BEGIN
	DefaultPos(x, y, MessageWidth, MessageHeight);
	RETURN TextMessageXY(type, x, y, caption, text, buttons)
END TextMessage;

PROCEDURE QueryLoginXY*(x, y : LONGINT; CONST caption : ARRAY OF CHAR; VAR login, password : ARRAY OF CHAR) : LONGINT;
VAR ld : LoginDlg;
BEGIN
	NEW(ld);
	IF ~ld.errors THEN
		ld.SetTitle(Strings.NewString(caption));
		ld.SetType(TLogin);
		ld.editUser.SetAsString(login); ld.editUser.tv.SelectAll();
		ld.x := x; ld.y := y; ld.Show();
		IF ld.result = ResOk THEN
			ld.editUser.GetAsString(login);
			ld.editPassword.GetAsString(password);
		END;
		RETURN ld.result
	ELSE RETURN ResDialogFailure;
	END;
END QueryLoginXY;

PROCEDURE QueryLogin*(CONST caption: ARRAY OF CHAR; VAR login, password: ARRAY OF CHAR) : LONGINT;
VAR x, y : LONGINT;
BEGIN
	DefaultPos(x, y, LoginWidth, LoginHeight);
	RETURN QueryLoginXY(x, y, caption, login, password);
END QueryLogin;


(** Open a user info query dialog at center of default viewport with title caption..
	Return ResOk or ResAbort. If res is ResOk string contains the utf8 string. String is not changed if
	res is ResAbort *)
PROCEDURE QueryUserInfoXY*(x, y : LONGINT;
	CONST caption: ARRAY OF CHAR; VAR shortName, fullName, eMail, password, passwordConfirm: ARRAY OF CHAR) : LONGINT;
VAR
	uid: UserInfoDlg;
BEGIN
	NEW(uid);
	IF ~uid.errors THEN
		uid.SetTitle(Strings.NewString(caption));
		uid.SetType(TLogin);
		uid.x := x; uid.y := y; uid.Show();
		IF uid.result = ResOk THEN
			uid.editShortName.GetAsString (shortName);
			uid.editFullName.GetAsString (fullName);
			uid.editEMail.GetAsString (eMail);
			uid.editPassword.GetAsString (password);
			uid.editPasswordConfirm.GetAsString (passwordConfirm);
		END;
		RETURN uid.result
	ELSE RETURN ResDialogFailure
	END
END QueryUserInfoXY;

PROCEDURE QueryUserInfo*(CONST caption : ARRAY OF CHAR; VAR shortName, fullName, eMail, password, passwordConfirm : ARRAY OF CHAR) : LONGINT;
VAR x, y : LONGINT;
BEGIN
	DefaultPos(x, y, UserInfoWidth, UserInfoHeight);
	RETURN QueryUserInfoXY(x, y, caption, shortName, fullName, eMail, password, passwordConfirm);
END QueryUserInfo;

PROCEDURE CustomDialogXY*(x, y : LONGINT; flags : SET; CONST dialog : ARRAY OF CHAR; VAR answer : ARRAY OF CHAR);
VAR cd : CustomDialog; ignore, res : LONGINT;
BEGIN
	answer := "";
	NEW(cd, dialog, ignore, ignore, res);
	IF (res = ResOk) THEN
		cd.Show(x, y, flags, answer);
		KernelLog.String("WMDialogs.CustomDialogXY error, res = "); KernelLog.Int(res, 0); KernelLog.Ln;
	END;
END CustomDialogXY;

PROCEDURE Test*;
VAR bimbo : ARRAY 100 OF CHAR;
BEGIN
	bimbo := "Test";
	KernelLog.Int(QueryString("Input", bimbo), 5);
	KernelLog.String("Result = "); KernelLog.String(bimbo); KernelLog.Ln;
END Test;

PROCEDURE TestMsg*;
BEGIN
	KernelLog.Int(Message(TInformation, "Huga", "You should only see the Ok button", {ResOk}), 5);
	KernelLog.Int(Message(TWarning, "Huga", "You should only see the Abort button", {ResAbort}), 5);
	KernelLog.Int(Message(TError, "Huga", "You should only see the No button", {ResNo}), 5);
	KernelLog.Int(Message(TCriticalError, "Huga", "You should see the Ok + Abort  button", {ResOk, ResAbort}), 5);
	KernelLog.Int(Message(TUserInput, "Huga", "You should see the Ok + Abort + No button", {ResOk, ResNo, ResAbort}), 5);
END TestMsg;

PROCEDURE TestLogin*;
VAR user, password : ARRAY 128 OF CHAR; res : LONGINT;
BEGIN
	user := "TestUser";
	res := QueryLogin("Test login dialog", user, password);
	IF res = ResOk THEN
		KernelLog.String("OK (User: "); KernelLog.String(", login: "); KernelLog.String(user);
		KernelLog.String(", password: "); KernelLog.String(password); KernelLog.String(")");
	ELSE
		KernelLog.String("res = "); KernelLog.Int(res, 0);
	END;
	KernelLog.Ln;
END TestLogin;

PROCEDURE TestUserInfo*;
VAR shortName, fullName, eMail, password, passwordConfirm : ARRAY 128 OF CHAR; res : LONGINT;
BEGIN
	res := QueryUserInfo("Test user info dialog", shortName, fullName, eMail, password, passwordConfirm);
	IF res = ResOk THEN
		KernelLog.String("OK (Short Name: "); KernelLog.String(shortName);
		KernelLog.String(", Full Name: "); KernelLog.String(fullName);
		KernelLog.String(", E-Mail: "); KernelLog.String(eMail);
		KernelLog.String(", Password: "); KernelLog.String(password);
		KernelLog.String(", Password confirm: "); KernelLog.String(passwordConfirm);
		KernelLog.String(")");
	ELSE
		KernelLog.String("res = "); KernelLog.Int(res, 0);
	END;
	KernelLog.Ln;
END TestUserInfo;

PROCEDURE TestCustomDialog*(context : Commands.Context); (** dialog x y ~ *)
VAR cd : CustomDialog; dialog, answer : ARRAY 256 OF CHAR; x, y, width, height, res : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(dialog);
	context.arg.SkipWhitespace; context.arg.Int(x, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(y, FALSE);
	NEW(cd, dialog, width, height, res);
	IF (res = Repositories.Ok) THEN
		context.out.String("Show dialog at "); context.out.Int(x, 0); context.out.String(", "); context.out.Int(y, 0);
		context.out.String(" size: "); context.out.Int(width, 0); context.out.String(", "); context.out.Int(height, 0); context.out.Ln;
		context.out.Update;
		cd.Show(x, y, {WMWindowManager.FlagFrame, WMWindowManager.FlagClose}, answer);
		context.out.String("Answer: "); context.out.String(answer); context.out.Ln;
	ELSE
		context.error.String("Could not create dialog window, res = "); context.error.Int(res, 0); context.error.Ln;
	END;
END TestCustomDialog;

END WMDialogs.

SystemTools.Free WMDialogs ~
WMDialogs.Test ~
WMDialogs.TestMsg ~
WMDialogs.TestLogin ~
WMDialogs.TestUserInfo ~
WMDialogs.TestCustomDialog Test:Dialog 100 100 ~