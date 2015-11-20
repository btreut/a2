MODULE WMV24Component; (** AUTHOR "TF/staubesv"; PURPOSE "Terminal"; *)
(**
 * History:
 *	19.01.2006	Adapted to Serials, added clear button, synchronize operations to V24Panel.open (staubesv)
 *	10.06.2006	Added YSend functionality, use XYModem.Mod instead of XModem.Mod, command button
 *	14.06.2006 	Busy loop removed, made window restorable (staubesv)
 *	15.06.2006	Support to paste to terminal window from clipboard, cursor always at the end of the text, keyboard focus indication, added scrollbar (staubesv)
 *	16.06.2006	Added SendCommand functionality (staubesv)
 *	21.06.2006	Improved error reporting (staubesv)
 *	22.06.2006	Added LineFeed and UseBackspace options, added status bar (staubesv)
 *	05.09.2006	Relay all keys to serial port, added copy&paste buttons since shortcuts are relayed to text view anymore,
 *				don't send command if port is not open, configuration can be specified in Configuration.XML (staubesv)
 *	25.09.2006	Added XY modem receive & echo capability (staubesv)
 *	20.02.2007	Better usability for selection, can send multiple files via XY-Modem protocol (staubesv)
 *	25.06.2007	Open progress windows on current view (staubesv)
 *
 * TODO:
 *
 * Sometimes, not all data that is received is displayed until the user sends a character to the device (The data is really receive, w.Char and w.Update
 * are both called but the content of the writer w are not displayed). FIX!
 *)

IMPORT
	KernelLog, Streams, Configuration, Texts, TextUtilities, Strings,
	Modules, Kernel, Serials, XYModem, Files, Inputs,
	WMWindowManager, WMMessages, WMRestorable, WMGraphics, WMRectangles,
	WMComponents, WMStandardComponents, WMProgressComponents, WMTextView, WMEditors, WMPopups, WMDialogs,
	XML, XMLObjects, WMSearchComponents, Commands, V24, T := Trace;

CONST

	(* Terminal Configuration - The default configuration is overriden by the configuration in Configuration.XML if available *)

	(* Default size of window at start up *)
	DefaultWidth = 800; DefaultHeight = 400;

	(* Default serial port settings *)
	DefaultPort = 1;
	DefaultBps = 115200;
	DefaultDataBits = 8;
	DefaultParity = Serials.ParNo;
	DefaultStopBits = Serials.Stop1;

	(* If TRUE, the terminal panel is grey when it has no keyboard focus *)
	DefaultIndicateKeyboardFocus = TRUE;

	(* If TRUE, some CTRL-key combinations are intercepted by the terminal window but not sent to the stream *)
	DefaultShortcutsEnabled = FALSE;

	(* Display status bar with error & port status indication? *)
	DefaultShowStatusBar = TRUE;

	(* Send <CR><LF> when the user presses <CR>. Also send <CR><LF> instead of <CR> when sending commands *)
	DefaultLineFeed = FALSE;

	(* The window manager reports a DEL key pressed when pressing backspace. If TRUE, the terminal sends backspaces instead of deletes *)
	DefaultUseBackspace = TRUE;

	(* Should received characters be sent back? *)
	DefaultEcho = FALSE;

	(* Is UTF support is disabled, all non-ascii characters are replaced by the character "." *)
	DefaultUTF8Support = FALSE;

	(* Internal terminal configuration *)

	(* How often should the port status be polled? *)
	UpdateInterval = 200; (* ms *)

	ReceiveBufferSize = 1024;

	(* Trace Configuration *)

	TraceCharactersSent = {0};
	TraceCharactersReceived = {1};

	Trace = {};

	(* Internal Constants *)

	Backspace = 08X;
	CR = 0DX;
	LF = 0AX;
	ESC = 1BX;
	DEL = 7FX;

	(* Lock *)
	Free = 0;
	Terminal = 1;
	DataTransfer = 2;

	ModuleName = "WMV24Component";

TYPE

	Settings = OBJECT
	VAR
		portSettings : ARRAY 64 OF CHAR;
		indicateKeyboardFocus : BOOLEAN;
		showStatusBar : BOOLEAN;
		shortcutsEnabled : BOOLEAN;
		linefeed : BOOLEAN;
		echo : BOOLEAN;
		utf8Support : BOOLEAN;
		useBackspace : BOOLEAN;
		xReceiveCommand, yReceiveCommand : Strings.String;
		xSendCommand, ySendCommand : Strings.String;

		(* Load settings from Configuration.XML. For settings that are not available, default settings are used *)
		PROCEDURE Load;
		VAR
			value, temp : ARRAY 256 OF CHAR;
			res : LONGINT;
		BEGIN
			Configuration.Get("Applications.WMV24Component.PortSettings", value, res);
			IF (res = Configuration.Ok) THEN COPY(value, portSettings); END;

			Configuration.GetBoolean("Applications.WMV24Component.IndicateKeyboardFocus", indicateKeyboardFocus, res);
			Configuration.GetBoolean("Applications.WMV24Component.LineFeed", linefeed, res);
			Configuration.GetBoolean("Applications.WMV24Component.UseBackspace", useBackspace, res);
			Configuration.GetBoolean("Applications.WMV24Component.ShowStatusBar", showStatusBar, res);
			Configuration.GetBoolean("Applications.WMV24Component.ShortcutsEnabled", shortcutsEnabled, res);
			Configuration.GetBoolean("Applications.WMV24Component.Echo", echo, res);
			Configuration.GetBoolean("Applications.WMV24Component.UTF8Support", utf8Support, res);

			Configuration.Get("Applications.WMV24Component.XReceiveCommand", value, res);
			COPY(value, temp); Strings.TrimWS(temp);
			IF (res = Configuration.Ok) & (temp # "") THEN xReceiveCommand := Strings.NewString(value); END;

			Configuration.Get("Applications.WMV24Component.YReceiveCommand", value, res);
			COPY(value, temp); Strings.TrimWS(temp);
			IF (res = Configuration.Ok) & (temp # "") THEN yReceiveCommand := Strings.NewString(value); END;

			Configuration.Get("Applications.WMV24Component.XSendCommand", value, res);
			COPY(value, temp); Strings.TrimWS(temp);
			IF (res = Configuration.Ok) & (temp # "") THEN xSendCommand := Strings.NewString(value); END;

			Configuration.Get("Applications.WMV24Component.YSendCommand", value, res);
			COPY(value, temp); Strings.TrimWS(temp);
			IF (res = Configuration.Ok) & (temp # "")  THEN ySendCommand := Strings.NewString(value); END;
		END Load;

		PROCEDURE GetDefaultPortSettings(VAR portSettings : ARRAY OF CHAR);
		VAR w : Streams.StringWriter;
		BEGIN
			NEW(w, 64);
			w.Int(DefaultPort, 0); w.Char(" ");
			w.Int(DefaultBps, 0); w.Char(" ");
			w.Int(DefaultDataBits, 0); w.Char(" ");
			w.Int(DefaultStopBits, 0); w.Char(" ");
			CASE DefaultParity OF
				|Serials.ParNo: w.String("none");
				|Serials.ParOdd: w.String("odd");
				|Serials.ParEven: w.String("even");
				|Serials.ParMark: w.String("mark");
				|Serials.ParSpace: w.String("space");
			ELSE
				w.String("unknown");
			END;
			w.Get(portSettings);
		END GetDefaultPortSettings;

		PROCEDURE &Init*;
		BEGIN
			GetDefaultPortSettings(portSettings);
			indicateKeyboardFocus := DefaultIndicateKeyboardFocus;
			linefeed := DefaultLineFeed;
			useBackspace := DefaultUseBackspace;
			showStatusBar := DefaultShowStatusBar;
			shortcutsEnabled := DefaultShortcutsEnabled;
			echo := DefaultEcho;
			utf8Support := DefaultUTF8Support;
			xReceiveCommand := NIL;
			yReceiveCommand := NIL;
			xSendCommand := NIL;
			ySendCommand := NIL;
		END Init;

	END Settings;

TYPE

	(* Recursive lock. This lock is used to provide exclusive access to the currently opened serial port to either
	 * the Terminal or data tranfer operation *)
	Lock = OBJECT
	VAR
		lock : LONGINT;
		locklevel : LONGINT;

		PROCEDURE TryAcquire(lock : LONGINT) : BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF (SELF.lock # Free) & (SELF.lock # lock) THEN
				RETURN FALSE;
			ELSE
				TakeLock(lock);
				RETURN TRUE;
			END;
		END TryAcquire;

		PROCEDURE Acquire(lock : LONGINT);
		BEGIN {EXCLUSIVE}
			IF (SELF.lock # Free) & (SELF.lock # lock) THEN
				AWAIT(SELF.lock=Free);
			END;
			TakeLock(lock);
		END Acquire;

		PROCEDURE Release;
		BEGIN {EXCLUSIVE}
			ASSERT(locklevel > 0);
			DEC(locklevel);
			IF locklevel = 0 THEN lock := Free; END;
		END Release;

		PROCEDURE TakeLock(lock : LONGINT);
		BEGIN (* only call from critical sections !*)
			IF SELF.lock = lock THEN
				INC(locklevel);
			ELSE
				SELF.lock := lock; locklevel := 1;
			END;
		END TakeLock;

		PROCEDURE &Init*;
		BEGIN
			lock := Free; locklevel := 0;
		END Init;

	END Lock;

TYPE

	Command = POINTER TO RECORD
		name : ARRAY 64 OF CHAR;
		commandString : ARRAY 256 OF CHAR;
		next : Command;
	END;

TYPE

	ProgressInfo = OBJECT(WMComponents.VisualComponent)
	VAR
		progressBar : WMProgressComponents.ProgressBar;
		filenameLabel : WMStandardComponents.Label;
		progressLabel : WMStandardComponents.Label;
		currentBytes, maxBytes : LONGINT;

		w : Streams.StringWriter;
		string : ARRAY 128 OF CHAR;

		PROCEDURE SetProgress(progress : LONGINT);
		BEGIN
			w.Reset;
			w.String("Received "); w.Int(progress, 0);
			IF maxBytes > 0 THEN
				w.String(" of "); w.Int(maxBytes, 0); w.String(" Bytes");
				progressBar.SetCurrent(progress);
			ELSE
				w.String(" Bytes");
			END;
			w.Get(string);
			progressLabel.caption.SetAOC(string);
		END SetProgress;

		PROCEDURE &New*(CONST filename : ARRAY OF CHAR; length : LONGINT);
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			Init;
			NEW(w, 128);
			currentBytes := 0; maxBytes := length;

			NEW(panel); panel.fillColor.Set(0FFFFFFFFH); panel.bounds.SetExtents(300, 60); panel.alignment.Set(WMComponents.AlignClient);
			AddContent(panel);

			NEW(filenameLabel); filenameLabel.bounds.SetHeight(20); filenameLabel.alignment.Set(WMComponents.AlignTop);
			filenameLabel.caption.SetAOC(filename);
			panel.AddContent(filenameLabel);

			NEW(progressLabel); progressLabel.bounds.SetHeight(20); progressLabel.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(progressLabel);

			IF maxBytes > 0 THEN
				NEW(progressBar); progressBar.bounds.SetHeight(20); progressBar.alignment.Set(WMComponents.AlignTop);
				progressBar.SetRange(0, maxBytes);
				panel.AddContent(progressBar);
			END;

			SetProgress(0);

			SetNameAsString(StrProgressInfo);
		END New;

	END ProgressInfo;

TYPE

	(* The cursor position of this textview cannot be changed using the mouse pointer *)
	CustomTextView = OBJECT(WMTextView.TextView)
	VAR
		selecting, selectWords, dragPossible  : BOOLEAN;
		lastPos : LONGINT;
		downX, downY : LONGINT;

		utilreader : Texts.TextReader;

		text : Texts.Text;

		PROCEDURE SetText(text : Texts.Text);
		BEGIN
			SetText^(text);
			SELF.text := text;
			NEW(utilreader, text);
		END SetText;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		VAR pos : LONGINT;
		BEGIN
			IF keys * {0, 1, 2} = {2} THEN
				ShowContextMenu(x, y) END;
			IF 0 IN keys THEN
				text.AcquireRead;
				ViewToTextPos(x, y, pos);
				dragPossible := FALSE; selectWords := FALSE;
				IF pos >= 0 THEN
					selection.Sort;
					IF (pos >= selection.a) & (pos < selection.b) THEN
						dragPossible := TRUE; downX := x; downY := y
					ELSE
						(* clicking the same position twice --> Word Selection Mode *)
						IF pos = lastPos THEN
							selectWords := TRUE;
							selection.SetFromTo(TextUtilities.FindPosWordLeft(utilreader, pos - 1),
									TextUtilities.FindPosWordRight(utilreader, pos + 1))
						ELSE
							selection.SetFromTo(pos, pos) (* reset selection *)
						END;
						selecting := TRUE
					END
				END;
				lastPos := pos;
				text.ReleaseRead;
			END;
		END PointerDown;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		CONST DragDist = 5;
		VAR pos : LONGINT;
		BEGIN
			IF dragPossible THEN
				IF (ABS(x - downX) > DragDist) OR (ABS(y - downY) > DragDist) THEN dragPossible := FALSE; AutoStartDrag END
			ELSE
				IF selecting THEN
					text.AcquireRead;
					ViewToTextPos(x, y, pos);
					IF selecting THEN
						IF selectWords THEN
							IF pos < selection.from.GetPosition() THEN pos := TextUtilities.FindPosWordLeft(utilreader, pos - 1);
							ELSE pos := TextUtilities.FindPosWordRight(utilreader, pos + 1)
							END;
							selection.SetTo(pos)
						ELSE
							selection.SetTo(pos);
						END;
						Texts.SetLastSelection(text, selection.from, selection.to);
					END;
					text.ReleaseRead;
				END;
			END
		END PointerMove;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		BEGIN
			selecting := FALSE;
			IF dragPossible THEN selection.SetFromTo(0, 0); Texts.ClearLastSelection (* reset selection *) END;
			dragPossible := FALSE
		END PointerUp;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrCustomTextView);
		END Init;

	END CustomTextView;

TYPE

	TerminalComponent = OBJECT(WMComponents.VisualComponent)
	VAR
		settings : Settings;

		(* Access to serial port *)
		in : Streams.Reader;
		out : Streams.Writer;

		port : Serials.Port;
		portNr, bps, databits, parity, stop : LONGINT;
		open : BOOLEAN;

		lock : Lock;

		(* Terminal window text writer *)
		w : TextUtilities.TextWriter;

		textView : CustomTextView;
		text : Texts.Text;

		searchPanel : WMSearchComponents.SearchPanel;

		(* Upper Toolbar *)
		opencloseBtn : WMStandardComponents.Button;
		settingsEdit : WMEditors.Editor;
		sendXBtn, sendYBtn : WMStandardComponents.Button;
		receiveXBtn, receiveYBtn : WMStandardComponents.Button;

		(* Lower Toolbar *)
		lowerToolBar : WMStandardComponents.Panel;
		sendCommandBtn : WMStandardComponents.Button;
		sendCommandEditor : WMEditors.Editor;
		commandPopup : WMPopups.Popup; (* can be NIL *)
		commandMenuBtn : WMStandardComponents.Button;

		(* Status Bar *)
		status : WMStandardComponents.Label;
		dsr : WMStandardComponents.Label;
		clearStatusBtn : WMStandardComponents.Button;

		(* Error Counters *)
		overrunErrors, framingErrors, parityErrors, breakInterrupts, transportErrors, otherErrors : LONGINT;

		statusUpdater : StatusUpdater;

		running : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE Handle(VAR m: WMMessages.Message);
		BEGIN
			IF m.msgType = WMMessages.MsgKey THEN
				IF ~settings.shortcutsEnabled OR ~HandleShortcut(m.x, m.flags, m.y) THEN
					Handle^(m);
				END;
			ELSE Handle^(m)
			END
		END Handle;

		PROCEDURE HandleCommandMenuButton(sender, data : ANY);
		VAR buttonBounds, panelBounds: WMRectangles.Rectangle; gx, gy : LONGINT;
		BEGIN
			buttonBounds := commandMenuBtn.bounds.Get();
			panelBounds := bounds.Get();
			ToWMCoordinates(panelBounds.l + buttonBounds.l, panelBounds.t + buttonBounds.b, gx, gy);
			commandPopup.Popup(gx,gy);
		END HandleCommandMenuButton;

		PROCEDURE HandleCommandPopup(sender, data : ANY);
		VAR command : Command;
		BEGIN
			IF (data # NIL) & (data IS Command) & open THEN
				command := data (Command);
				lock.Acquire(Terminal);
				out.String(command.commandString); out.Char(CR);
				IF settings.linefeed THEN out.Char(LF); END;
				out.Update;
				lock.Release;
			END;
		END HandleCommandPopup;

		PROCEDURE HandleSendCommandButton(sender, data : ANY);
		VAR commandString : ARRAY 1024 OF CHAR;
		BEGIN
			sendCommandEditor.GetAsString(commandString);
			IF open & (commandString # "") THEN
				lock.Acquire(Terminal);
				out.String(commandString); out.Char(CR);
				IF settings.linefeed THEN out.Char(LF); END;
				out.Update;
				lock.Release;
				sendCommandEditor.SetAsString("");
			END;
		END HandleSendCommandButton;

		PROCEDURE HandleClearStatusButton(sender, data : ANY);
		BEGIN
			ResetStatus;
		END HandleClearStatusButton;

		PROCEDURE HandleSearchButton(sender, data : ANY);
		VAR searchString : WMSearchComponents.SearchString;
		BEGIN
			searchPanel.visible.Set(TRUE);
			searchPanel.SetToLastSelection;
			searchPanel.searchEdit.GetAsString(searchString);
			IF (searchString # "") THEN
				searchPanel.SearchHandler(NIL, NIL);
			ELSE
				searchPanel.searchEdit.SetFocus;
			END;
		END HandleSearchButton;

		PROCEDURE HandleClearButton(sender, data : ANY);
		BEGIN
			text.AcquireWrite;
			text.Delete(0, text.GetLength());
			textView.firstLine.Set(0); textView.cursor.SetPosition(0);
			text.ReleaseWrite
		END HandleClearButton;

		PROCEDURE HandleCopyButton(sender, data : ANY);
		BEGIN
			textView.CopySelection;
		END HandleCopyButton;

		PROCEDURE HandlePasteButton(sender, data : ANY);
		BEGIN
			IF open THEN
				CopyFromClipboard;
			ELSE
				WMDialogs.Error("Terminal", "Port is not open");
				RETURN;
			END;
		END HandlePasteButton;

		PROCEDURE HandleXYButtons(sender, data : ANY);
		VAR
			button : WMStandardComponents.Button;
			command : Strings.String;
			filename, msg : ARRAY 512 OF CHAR;
			filenames : Strings.StringArray;
			mode, i : LONGINT;
			send : BOOLEAN;
		BEGIN
			IF sender IS WMStandardComponents.Button THEN
				button := sender (WMStandardComponents.Button);
				IF button = sendXBtn THEN
					mode := XYModem.XModem; send := TRUE;
				ELSIF button = receiveXBtn THEN
					mode := XYModem.XModem; send := FALSE;
				ELSIF button = sendYBtn THEN
					mode := XYModem.YModem; send := TRUE;
				ELSIF button = receiveYBtn THEN
					mode := XYModem.YModem; send := FALSE;
				ELSE
					HALT(99);
				END;
			ELSE
				HALT(99);
			END;

			IF ~open THEN
				WMDialogs.Error("Terminal", "Port is not open");
				RETURN;
			END;

			IF send THEN msg := "File to send:"; ELSE msg := "File to receive:"; END;

			IF WMDialogs.QueryString(msg, filename) = WMDialogs.ResOk THEN

				filenames := Strings.Split(filename, ";");

				command := GetXYCommand(send, mode);

				IF (LEN(filenames) > 1) & (command = NIL) THEN
					WMDialogs.Error("Terminal", "Multiple files can only be sent if send command is specified");
				ELSE
					FOR i := 0 TO LEN(filenames)-1 DO
						Strings.TrimWS(filenames[i]^);
						IF command # NIL THEN SendXYCommand(send, command^, filenames[i]^); END;
						IF send THEN
							SendXYModem(filenames[i]^, mode);
						ELSE
							ReceiveXYModem(filenames[i]^, mode);
						END;
					END;
				END;
			END;
		END HandleXYButtons;

		PROCEDURE HandleShortcut(ucs : LONGINT; flags : SET; keySym : LONGINT)  : BOOLEAN;
		VAR handled : BOOLEAN;
		BEGIN
			IF ControlKeyDown(flags) THEN
				handled := TRUE;
				IF keySym = 01H THEN (* Ctrl-A *)
					textView.SelectAll;
				ELSIF keySym = 03H THEN (* Ctrl-C *)
					textView.CopySelection;
				ELSIF keySym = 04H THEN (* Ctrl-D *)
					HandleXYButtons(sendYBtn, NIL);
				ELSIF (keySym = 06H) THEN (* CTRL-F *)
					searchPanel.ToggleVisibility;
				ELSIF (keySym= 0EH) THEN (* CTRL-N *)
					searchPanel.HandlePreviousNext(TRUE);
				ELSIF (keySym = 10H) THEN (* CTRL-P *)
					searchPanel.HandlePreviousNext(FALSE);
				ELSE
					handled := FALSE;
				END;
			ELSIF (keySym = Inputs.KsTab) & (flags = {}) THEN (* TAB *)
				handled := searchPanel.HandleTab();
			ELSE
				handled := FALSE;
			END;
			RETURN handled;
		END HandleShortcut;

		PROCEDURE ExtKeyPressed(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			textView.SetFlags(flags);
			handled := TRUE;
			IF (ucs > 0) & (ucs < 256) THEN
				IF open & ~(Inputs.Release IN flags) THEN
					IF lock.TryAcquire(Terminal) THEN
						IF Trace * TraceCharactersSent # {} THEN Show("Sending character: "); KernelLog.Int(ucs, 0); KernelLog.Ln; END;
						IF ucs > 127 THEN (* Escape non-ascii characters *)
							out.Char(ESC); out.Char("["); ucs := ucs - 128;
						END;
						IF settings.linefeed & (ucs = ORD(CR)) THEN
							out.Char(CR); out.Char(LF); out.Update;
						ELSIF settings.useBackspace & (ucs = ORD(DEL)) THEN
							out.Char(Backspace); out.Update;
						ELSE
							out.Char(CHR(ucs)); out.Update;
						END;
						lock.Release;
					ELSE
						(* ignore characters *)
					END;
				END;
			END;
		END ExtKeyPressed;

		PROCEDURE ExtFocus(hasFocus : BOOLEAN);
		BEGIN
			IF hasFocus THEN
				FocusReceived;
				IF settings.indicateKeyboardFocus THEN textView.fillColor.Set(00H); END;
			ELSE
				FocusLost;
				IF settings.indicateKeyboardFocus THEN textView.fillColor.Set(0CCCCCCCCH); END;
			END;
		END ExtFocus;

		PROCEDURE CreateUpperToolBar() : WMComponents.VisualComponent;
		VAR toolbar : WMStandardComponents.Panel; label : WMStandardComponents.Label; button : WMStandardComponents.Button;
		BEGIN
			NEW(toolbar);
			toolbar.alignment.Set(WMComponents.AlignTop); toolbar.bounds.SetHeight(20);
			toolbar.fillColor.Set(0E0E0E0FFH);

			NEW(label);
			label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(50);
			label.caption.SetAOC(" Settings:");
			toolbar.AddContent(label);

			NEW(settingsEdit);
			settingsEdit.alignment.Set(WMComponents.AlignLeft);
			settingsEdit.bounds.SetWidth(110);
			settingsEdit.multiLine.Set(FALSE);
			settingsEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			settingsEdit.fillColor.Set(WMGraphics.White);
			settingsEdit.tv.borders.Set(WMRectangles.MakeRect(4, 3, 2, 2));
			settingsEdit.tv.showBorder.Set(TRUE);
			settingsEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			settingsEdit.SetAsString(settings.portSettings);
			toolbar.AddContent(settingsEdit);

			(* open/close *)
			NEW(opencloseBtn);
			opencloseBtn.alignment.Set(WMComponents.AlignLeft);
			opencloseBtn.takesFocus.Set(FALSE);
			opencloseBtn.caption.SetAOC("Open");
			opencloseBtn.onClick.Add(ToggleOpen);
			toolbar.AddContent(opencloseBtn);

			NEW(label);
			label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(65);
			label.caption.SetAOC("  XModem: ");
			toolbar.AddContent(label);

			(* send XModem *)
			NEW(sendXBtn);
			sendXBtn.alignment.Set(WMComponents.AlignLeft);
			sendXBtn.bounds.SetWidth(40);
			sendXBtn.caption.SetAOC("Send");
			sendXBtn.onClick.Add(HandleXYButtons);
			toolbar.AddContent(sendXBtn);

			(* receive XModem *)
			NEW(receiveXBtn);
			receiveXBtn.alignment.Set(WMComponents.AlignLeft);
			receiveXBtn.bounds.SetWidth(40);
			receiveXBtn.caption.SetAOC("Receive");
			receiveXBtn.onClick.Add(HandleXYButtons);
			toolbar.AddContent(receiveXBtn);

			NEW(label);
			label.alignment.Set(WMComponents.AlignLeft); label.bounds.SetWidth(65);
			label.caption.SetAOC("  YModem:");
			toolbar.AddContent(label);

			(* send YModem *)
			NEW(sendYBtn);
			sendYBtn.alignment.Set(WMComponents.AlignLeft);
			sendYBtn.bounds.SetWidth(40);
			sendYBtn.caption.SetAOC("Send");
			sendYBtn.onClick.Add(HandleXYButtons);
			toolbar.AddContent(sendYBtn);

			(* receive YModem *)
			NEW(receiveYBtn);
			receiveYBtn.alignment.Set(WMComponents.AlignLeft);
			receiveYBtn.bounds.SetWidth(40);
			receiveYBtn.caption.SetAOC("Receive");
			receiveYBtn.onClick.Add(HandleXYButtons);
			toolbar.AddContent(receiveYBtn);

			(* Clear *)
			NEW(button); button.alignment.Set(WMComponents.AlignRight);
			button.caption.SetAOC("Clear");
			button.onClick.Add(HandleClearButton);
			toolbar.AddContent(button);

			(* Paste *)
			NEW(button); button.alignment.Set(WMComponents.AlignRight);
			button.caption.SetAOC("Paste");
			button.onClick.Add(HandlePasteButton);
			toolbar.AddContent(button);

			(* Copy *)
			NEW(button); button.alignment.Set(WMComponents.AlignRight);
			button.caption.SetAOC("Copy");
			button.onClick.Add(HandleCopyButton);
			toolbar.AddContent(button);

			(* Search *)
			NEW(button); button.alignment.Set(WMComponents.AlignRight);
			button.caption.SetAOC("Search");
			button.onClick.Add(HandleSearchButton);
			toolbar.AddContent(button);

			RETURN toolbar;
		END CreateUpperToolBar;

		PROCEDURE CreateCommandMenu() : WMStandardComponents.Button;
		VAR command : Command; button : WMStandardComponents.Button;
		BEGIN
			command := LoadCommandMenu();
			IF command # NIL THEN
				NEW(commandPopup);
				WHILE command # NIL DO
					commandPopup.AddParButton(command.name, HandleCommandPopup, command);
					command := command.next;
				END;

				NEW(button);
				button.bounds.SetWidth(150); button.alignment.Set(WMComponents.AlignRight);
				button.takesFocus.Set(FALSE);
				button.caption.SetAOC("Commands");
				button.onClick.Add(HandleCommandMenuButton);
			END;
			RETURN button;
		END CreateCommandMenu;

		PROCEDURE CreateLowerToolBar() : WMStandardComponents.Panel;
		VAR toolbar : WMStandardComponents.Panel;
		BEGIN
			NEW(toolbar);
			toolbar.alignment.Set(WMComponents.AlignBottom); toolbar.bounds.SetHeight(20);
			toolbar.fillColor.Set(0E0E0E0FFH);

			NEW(sendCommandBtn);
			sendCommandBtn.alignment.Set(WMComponents.AlignLeft); sendCommandBtn.bounds.SetWidth(100);
			sendCommandBtn.takesFocus.Set(FALSE);
			sendCommandBtn.caption.SetAOC("Send Command:");
			sendCommandBtn.onClick.Add(HandleSendCommandButton);
			toolbar.AddContent(sendCommandBtn);

			commandMenuBtn := CreateCommandMenu();
			IF commandMenuBtn # NIL THEN
				toolbar.AddContent(commandMenuBtn);
			END;

			NEW(sendCommandEditor);
			sendCommandEditor.alignment.Set(WMComponents.AlignClient);
			sendCommandEditor.multiLine.Set(FALSE);
			sendCommandEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			sendCommandEditor.fillColor.Set(WMGraphics.White);
			sendCommandEditor.tv.borders.Set(WMRectangles.MakeRect(4, 3, 2, 2));
			sendCommandEditor.tv.showBorder.Set(TRUE);
			sendCommandEditor.SetAsString("");
			sendCommandEditor.onEnter.Add(HandleSendCommandButton);
			toolbar.AddContent(sendCommandEditor);

			RETURN toolbar;
		END CreateLowerToolBar;

		PROCEDURE CreateStatusBar() : WMStandardComponents.Panel;
		VAR statusBar : WMStandardComponents.Panel;
		BEGIN
			NEW(statusBar);
			statusBar.alignment.Set(WMComponents.AlignBottom); statusBar.bounds.SetHeight(20);
			statusBar.fillColor.Set(0E0E0E0FFH);

			NEW(clearStatusBtn);
			clearStatusBtn.bounds.SetWidth(80); clearStatusBtn.alignment.Set(WMComponents.AlignRight);
			clearStatusBtn.caption.SetAOC("Clear Status");
			clearStatusBtn.onClick.Add(HandleClearStatusButton);
			statusBar.AddContent(clearStatusBtn);

			NEW(dsr);
			dsr.bounds.SetWidth(30); dsr.alignment.Set(WMComponents.AlignRight);
			dsr.bearing.Set(WMRectangles.MakeRect(1,1,1,1));
			dsr.caption.SetAOC("DSR"); dsr.fillColor.Set(WMGraphics.White); dsr.alignH.Set(WMGraphics.AlignCenter);
			statusBar.AddContent(dsr);

			NEW(status);
			status.alignment.Set(WMComponents.AlignClient);
			statusBar.AddContent(status);

			RETURN statusBar;
		END CreateStatusBar;

		PROCEDURE CreateContent;
		VAR scrollbarY : WMStandardComponents.Scrollbar;
		BEGIN
			AddContent(CreateUpperToolBar()); (* AlignTop *)
			IF settings.showStatusBar THEN
				AddContent(CreateStatusBar()); (* AlignBottom *)
			END;
			lowerToolBar := CreateLowerToolBar();
			AddContent(lowerToolBar); (* AlignBottom *)

			NEW(scrollbarY); scrollbarY.alignment.Set(WMComponents.AlignRight); scrollbarY.vertical.Set(TRUE);

			NEW(text);
			NEW(textView); textView.alignment.Set(WMComponents.AlignClient);
			textView.SetText(text);
			textView.showBorder.Set(TRUE);
			textView.SetScrollbars(NIL, scrollbarY);
			textView.SetExtKeyEventHandler(ExtKeyPressed);
			textView.SetExtFocusHandler(ExtFocus);
			IF settings.indicateKeyboardFocus THEN textView.fillColor.Set(0CCCCCCCCH); END;

			NEW(searchPanel);
			searchPanel.alignment.Set(WMComponents.AlignBottom);
			searchPanel.bounds.SetHeight(40);
			searchPanel.SetText(text);
			searchPanel.SetTextView(textView);
			searchPanel.visible.Set(FALSE);

			AddContent(searchPanel);
			AddContent(scrollbarY);
			AddContent(textView);
		END CreateContent;

		PROCEDURE Wait(ms : LONGINT);
		BEGIN
			timer.Sleep(ms);
		END Wait;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMV24Component.NewTerminalComponent");
			NEW(timer); NEW(lock);
			NEW(settings); settings.Load;
			CreateContent;
			NEW(w, text); w.SetFontName("Courier");
			IF settings.showStatusBar THEN NEW(statusUpdater, SELF); END;
			SetNameAsString(StrTerminalComponent);
		END Init;

		(* Get global coordinates of the terminal panel *)
		PROCEDURE GetPanelCoordinates(VAR gx, gy : LONGINT);
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			rect := bounds.Get();
			ToWMCoordinates(rect.l, rect.t, gx, gy);
		END GetPanelCoordinates;

		PROCEDURE CopyFromClipboard;
		VAR string : POINTER TO ARRAY OF CHAR;
		BEGIN
			Texts.clipboard.AcquireRead;
			IF Texts.clipboard.GetLength() > 0 THEN
				NEW(string, Texts.clipboard.GetLength()+1);
				TextUtilities.TextToStr(Texts.clipboard, string^);
			END;
			Texts.clipboard.ReleaseRead;
			lock.Acquire(Terminal); out.String(string^); out.Update; lock.Release;
		END CopyFromClipboard;

		PROCEDURE GetXYCommand(send : BOOLEAN; mode : LONGINT) : Strings.String;
		VAR command : Strings.String;
		BEGIN
			IF (mode = XYModem.XModem) THEN
				IF send THEN command := settings.xReceiveCommand;
				ELSE command := settings.xSendCommand;
				END;
			ELSE
				IF send THEN command := settings.yReceiveCommand;
				ELSE command := settings.ySendCommand;
				END;
			END;
			RETURN command;
		END GetXYCommand;

		PROCEDURE SendXYCommand(send : BOOLEAN; CONST command, filename : ARRAY OF CHAR);
		BEGIN
			lock.Acquire(Terminal);
			out.String(command);
			IF ~send THEN out.Char(" "); out.String(filename); END;
			out.Char(CR);
			IF settings.linefeed THEN out.Char(LF); END;
			out.Update;
			lock.Release;
			Wait(500);
		END SendXYCommand;

		PROCEDURE SendXYModem(CONST filename : ARRAY OF CHAR; mode : LONGINT);
		VAR
			f : Files.File;
			progressWindow : ProgressWindow;
			progressInfo : ProgressInfo;
			xysender : XYModem.Sender;
			msg : ARRAY 32 OF CHAR;
			x, y, res : LONGINT;
		BEGIN
			f := Files.Old(filename);
			IF f # NIL THEN
				IF open THEN
					NEW(timer);
					open := FALSE;
					port.Close; (* Force ReceiveCharacters to release the lock *)
					lock.Acquire(DataTransfer);
					(* Now we have the port for us alone *)
					port.Open(bps, databits, parity, stop, res);
					IF res = Serials.Ok THEN
						in.Reset; out.Reset;
						NEW(xysender, out, in, f, mode);
						NEW(progressInfo, filename, f.Length()); progressInfo.bounds.SetExtents(300, 60);
						GetPanelCoordinates(x, y);
						NEW(progressWindow, progressInfo, x + 150, y + 50);
						WHILE ~xysender.IsDone() DO
							progressInfo.SetProgress(xysender.bytesProcessed);
							Wait(500);
						END;
						progressInfo.SetProgress(xysender.bytesProcessed);
						xysender.Await(msg);
					ELSE
						Show("FATAL ERROR, could not re-open the port"); KernelLog.Ln;
					END;
					lock.Release;
					IF msg # "" THEN
						WMDialogs.Error("Transmission failed", msg)
					END;
					Wait(1000);
					progressWindow.Close;
					BEGIN {EXCLUSIVE} open := TRUE; END;
				END;
			ELSE
				WMDialogs.Error("File not found", filename);
			END;
		END SendXYModem;

		PROCEDURE ReceiveXYModem(filename : ARRAY OF CHAR; mode : LONGINT);
		VAR
			f : Files.File;
			progressWindow : ProgressWindow;
			label : WMStandardComponents.Label;
			caption : ARRAY 128 OF CHAR;
			xyreceiver : XYModem.Receiver;
			msg : ARRAY 32 OF CHAR;
			x, y, res : LONGINT;
			awaitF : BOOLEAN;
		BEGIN
			IF filename # "" THEN
				f := Files.New(filename); awaitF := FALSE;
				IF f = NIL THEN
					WMDialogs.Error("Couldn't create file ", filename);
					RETURN;
				END;
			ELSE
				f := NIL; awaitF := TRUE
			END;

			IF open THEN
				NEW(timer);
				open := FALSE;
				port.Close; (* Force ReceiveCharacters to release the lock *)
				lock.Acquire(DataTransfer);
				(* Now we have the port for us alone *)
				port.Open(bps, databits, parity, stop, res);
				IF res = Serials.Ok THEN
					in.Reset; out.Reset;
					NEW(xyreceiver, out, in, f, mode);
					NEW(label); label.alignment.Set(WMComponents.AlignLeft);
					label.bounds.SetExtents(300, 100); label.fillColor.Set(WMGraphics.White);
					label.alignH.Set(WMGraphics.AlignCenter); label.alignV.Set(WMGraphics.AlignCenter);
					label.caption.SetAOC("Receiving data...");
					GetPanelCoordinates(x, y);
					NEW(progressWindow, label, x + 150, y + 50);
					WHILE ~xyreceiver.IsDone() DO
						Strings.IntToStr(xyreceiver.bytesProcessed, caption);
						Strings.Append(caption, " bytes received");
						label.caption.SetAOC(caption);
						Wait(500);
					END;
					Strings.IntToStr(xyreceiver.bytesProcessed, caption);
					Strings.Append(caption, " bytes received");
					label.caption.SetAOC(caption);
					IF ~awaitF THEN
						xyreceiver.Await(msg)
					ELSE
						xyreceiver.AwaitF(f, msg)
					END;
				ELSE
					Show("FATAL ERROR, could not re-open the port"); KernelLog.Ln;
				END;
				lock.Release;

				Wait(500); (* Give the port open time so we see the output below *)

				IF msg # "" THEN
					WMDialogs.Error("Reception failed", msg)
				ELSIF f = NIL THEN
					WMDialogs.Error("Error: File is NIL", msg);
				ELSE
					Files.Register(f);
					IF awaitF THEN
						f.GetName(filename);
					END;
					caption := "File "; Strings.Append(caption, filename); Strings.Append(caption, " received (");
					Strings.IntToStr(xyreceiver.bytesProcessed, msg); Strings.Append(caption, msg); Strings.Append(caption, "Bytes)");
					label.caption.SetAOC(caption);
				END;

				Wait(500);
				progressWindow.Close;
				BEGIN {EXCLUSIVE} open := TRUE; END;
			END;
		END ReceiveXYModem;

		PROCEDURE ResetStatus;
		BEGIN
			overrunErrors := 0; parityErrors := 0; framingErrors := 0; transportErrors := 0; breakInterrupts := 0;
		END ResetStatus;

		PROCEDURE ToggleOpen(sender, data : ANY);
		VAR msg, s, t : ARRAY 64 OF CHAR; parityChar : CHAR;
			r : Streams.StringReader;
			res : LONGINT;
		BEGIN
			ResetStatus;
			IF open THEN
				open := FALSE;
				port.Close;
				opencloseBtn.caption.SetAOC("Open");
			ELSE
				settingsEdit.GetAsString(s);
				NEW(r, 64); r.Set(s); r.SkipWhitespace;
				r.Int(portNr, FALSE);  r.SkipWhitespace;
				r.Int(bps, FALSE); r.SkipWhitespace;
				r.Int(databits, FALSE); r.SkipWhitespace;
				r.Int(stop, FALSE); r.SkipWhitespace;
				r.Char(parityChar);

				port := Serials.GetPort(portNr);
				IF port # NIL THEN
					CASE CAP(parityChar) OF
						| "N" : parity := Serials.ParNo;
						| "O" : parity := Serials.ParOdd;
						| "E" : parity := Serials.ParEven;
						| "M" : parity := Serials.ParMark;
						| "S" : parity := Serials.ParSpace;
					ELSE parity := Serials.ParNo
					END;
					port.Open(bps, databits, parity, stop, res);
					IF res = Serials.Ok THEN
						opencloseBtn.caption.SetAOC("Close");
						NEW(in, port.Receive, 64); NEW(out, port.Send, 64);
						BEGIN {EXCLUSIVE}
							open := TRUE
						END
					ELSE
						ReportError("Configuration Error", res);
					END
				ELSE
					msg := "Port number not available: "; Strings.IntToStr(portNr, t); Strings.Append(msg, t);
					WMDialogs.Error("Port not found", msg)
				END;
			END;
		END ToggleOpen;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF settings.showStatusBar THEN statusUpdater.Terminate; END;
			BEGIN {EXCLUSIVE}
				running := FALSE;
				IF port # NIL THEN port.Close; open := FALSE; END;
			END;
		END Finalize;

		PROCEDURE DeleteNCharacters(nbrOfCharacters : LONGINT);
		VAR pos : LONGINT;
		BEGIN
			text.AcquireWrite;
			pos := textView.cursor.GetPosition();
			text.Delete(pos - nbrOfCharacters, nbrOfCharacters);
			text.ReleaseWrite;
		END DeleteNCharacters;

		PROCEDURE ReportError(CONST title : ARRAY OF CHAR; res : LONGINT);
		VAR msg : ARRAY 128 OF CHAR;
		BEGIN
		CASE res OF
			| Serials.PortInUse : msg := "Port already in use"
			| Serials.WrongBPS : msg := "Unsupported  BPS"
			| Serials.WrongData : msg := "Unsupported data or stop bits"
			| Serials.WrongParity : msg := "Unsupported parity";
			| Serials.OverrunError : msg := "Overrun Error";
			| Serials.ParityError : msg := "Parity Error";
			| Serials.FramingError : msg := "Framing Error (Wrong bitrate?)";
			| Serials.BreakInterrupt : msg := "Break Interrupt received";
			| Serials.Closed : msg := "Port is closed";
			| Serials.TransportError : msg := "Transport Layer Error";
		ELSE msg := "Unspecified error"
		END;
		WMDialogs.Error(title, msg)
		END ReportError;

		PROCEDURE EvaluateError(res : LONGINT);
		BEGIN
			CASE res OF
				|Serials.OverrunError: INC(overrunErrors);
				|Serials.ParityError: INC(parityErrors);
				|Serials.FramingError: INC(framingErrors);
				|Serials.BreakInterrupt: INC(breakInterrupts);
				|Serials.TransportError: INC(transportErrors);
			ELSE
				INC(otherErrors);
			END;
		END EvaluateError;

		PROCEDURE ReceiveCharacters;
		VAR ch : CHAR; buffer : ARRAY ReceiveBufferSize OF CHAR; backspaces, i, len, res : LONGINT;
		BEGIN
			(* Receive at least one character *)
			lock.Acquire(Terminal);
			port.Receive(buffer, 0, ReceiveBufferSize, 1, len, res);
			lock.Release;
			IF res = Serials.Ok THEN
				FOR i := 0 TO len-1 DO

					ch := buffer[i];

					IF Trace * TraceCharactersReceived # {} THEN Show("Received character: "); KernelLog.Int(ORD(ch), 0); KernelLog.Ln; END;
					IF settings.echo THEN out.Char(ch); out.Update; END;

					IF ~settings.utf8Support & (ORD(ch) > 127) THEN
						ch := ".";
					END;

					IF (ch = DEL) OR (ch = Backspace) THEN
						INC(backspaces);
					ELSE
						IF (backspaces > 0) THEN
							w.Update;
							DeleteNCharacters(backspaces);
							backspaces := 0;
						END;
						w.Char(ch);
					END;
				END;
				w.Update;
			ELSE
				EvaluateError(res);
			END;
			DeleteNCharacters(backspaces);
		END ReceiveCharacters;

	BEGIN {ACTIVE}
		running := TRUE;
		WHILE running DO
			BEGIN {EXCLUSIVE} AWAIT(open OR ~running); END;
			IF running THEN ReceiveCharacters; END;
		END;
	END TerminalComponent;

TYPE

	StatusUpdater = OBJECT
	VAR
		terminal : TerminalComponent;

		writer : Streams.StringWriter;

		alive, dead : BOOLEAN;
		timer : Kernel.Timer;

		PROCEDURE UpdateStatusLabel;
		VAR string : ARRAY 1024 OF CHAR; port : Serials.Port; mc : SET;
		BEGIN
			writer.Reset;
			writer.String("  Errors:   ");
			writer.String("Overruns: "); writer.Int(terminal.overrunErrors, 5); writer.String("   ");
			writer.String("Parity: "); writer.Int(terminal.parityErrors, 5); writer.String("   ");
			writer.String("Framing: "); writer.Int(terminal.framingErrors, 5); writer.String("   ");
			writer.String("Transport: "); writer.Int(terminal.transportErrors, 5);
			port := terminal.port;
			IF (port # NIL) & terminal.open THEN
				writer.String("      ");
				writer.String("Sent: "); writer.Int(port.charactersSent, 8); writer.String("   ");
				writer.String("Received: "); writer.Int(port.charactersReceived, 8);
				port.GetMC(mc);
				IF mc * {Serials.DSR} # {} THEN
					terminal.dsr.fillColor.Set(WMGraphics.Green);
				ELSE
					terminal.dsr.fillColor.Set(WMGraphics.Red);
				END;
			ELSE
				terminal.dsr.fillColor.Set(WMGraphics.White);
			END;
			writer.Get(string);
			terminal.status.caption.SetAOC(string);
			IF (terminal.overrunErrors > 0) OR (terminal.parityErrors > 0) OR (terminal.framingErrors > 0) OR
				(terminal.transportErrors > 0) THEN
				terminal.status.fillColor.Set(WMGraphics.Red);
			ELSE
				terminal.status.fillColor.Set(0E0E0E0FFH);
			END;
		END UpdateStatusLabel;

		PROCEDURE Terminate;
		BEGIN {EXCLUSIVE}
			alive := FALSE; timer.Wakeup;
			AWAIT(dead);
		END Terminate;

		PROCEDURE &Init*(terminal : TerminalComponent);
		BEGIN
			ASSERT(terminal # NIL);
			SELF.terminal := terminal;
			alive := TRUE; dead := FALSE;
			NEW(timer);
			NEW(writer, 1024);
		END Init;

	BEGIN {ACTIVE}
		WHILE alive DO
			UpdateStatusLabel;
			timer.Sleep(UpdateInterval);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END StatusUpdater;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	ProgressWindow = OBJECT(WMComponents.FormWindow);

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END
		END Handle;

		PROCEDURE &New*(vc : WMComponents.VisualComponent; x, y : LONGINT);
		BEGIN
			IncCount;

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString("Progress"));

			WMWindowManager.DefaultAddWindow(SELF);
		END New;

	END ProgressWindow;

TYPE

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		terminal : TerminalComponent;

		PROCEDURE GetStartupSize(VAR width, height : LONGINT);
		VAR strings : Strings.StringArray; value : ARRAY 64 OF CHAR; res : LONGINT;
		BEGIN
			width := DefaultWidth; height := DefaultHeight;
			Configuration.Get("Applications.WMV24Component.WindowStartupSize", value, res);
			IF (res = Configuration.Ok) THEN
				Strings.UpperCase(value);
				Strings.TrimWS(value);
				strings := Strings.Split(value, "X");
				IF LEN(strings) = 2 THEN
					Strings.StrToInt(strings[0]^, width);
					Strings.StrToInt(strings[1]^, height);
				END;
			END;
		END GetStartupSize;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel; width, height : LONGINT;
		BEGIN
			GetStartupSize(width, height);
			NEW(panel); panel.bounds.SetExtents(width, height); panel.fillColor.Set(0FFFFFFFFH); panel.takesFocus.Set(TRUE);
			NEW(terminal); terminal.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(terminal);
			RETURN panel
		END CreateForm;

		PROCEDURE &New*(c : WMRestorable.Context; context: Commands.Context);
		VAR
			vc : WMComponents.VisualComponent;
			configuration : WMRestorable.XmlElement; string : ARRAY 64 OF CHAR;
			s: POINTER TO ARRAY OF CHAR;
			len: LONGINT;
		BEGIN
			IncCount;

			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString("BlueTerminal"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMV24Component.png", TRUE));

			IF c # NIL THEN
				configuration := WMRestorable.GetElement(c, "Configuration");
				IF configuration # NIL THEN
					WMRestorable.LoadString(configuration, "PortSettings", string);
					terminal.settingsEdit.SetAsString(string);
				END;
				WMRestorable.AddByContext(SELF, c);
				Resized(GetWidth(), GetHeight());
			ELSE
				WMWindowManager.DefaultAddWindow(SELF);
				IF context # NIL THEN
					NEW(s, (*context.arg.Pos()+*)context.arg.Available());
					context.arg.SkipWhitespace();
					context.arg.Bytes(s^, 0 (*context.arg.Pos()*), context.arg.Available(), len);
					(* Only automatically open the Com Port if a paramater was passed *)
					IF (len > 0) & (s[0] # 0X) THEN
						terminal.settingsEdit.SetAsString(s^);
						terminal.ToggleOpen(NIL, NIL);
					END;
				END;
			END;
		END New;

		PROCEDURE Close;
		BEGIN
			T.String("closing window"); T.Ln;
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		VAR configuration : WMRestorable.XmlElement; string : ARRAY 64 OF CHAR;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN
					Close;
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(configuration); configuration.SetName("Configuration");
					terminal.settingsEdit.GetAsString(string);
					WMRestorable.StoreString(configuration, "PortSettings", string);
					x.ext(WMRestorable.Storage).Add("BlueTerminal", "WMV24Component.Restore", SELF, configuration);
				ELSE
					Handle^(x);
				END;
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;
	timeout: BOOLEAN;

	StrProgressInfo, StrCustomTextView, StrTerminalComponent : Strings.String;

PROCEDURE ControlKeyDown(flags : SET) : BOOLEAN;
BEGIN
	RETURN (flags * Inputs.Ctrl # {}) & (flags - Inputs.Ctrl = {});
END ControlKeyDown;

PROCEDURE LoadCommandMenu() : Command;
VAR
	commandList : Command;
	enum: XMLObjects.Enumerator; p: ANY; e: XML.Element;

	PROCEDURE AddCommand(name,  value : XML.String);
	VAR c, newCmd : Command;
	BEGIN
		IF (name # NIL) & (value # NIL) THEN
			NEW(newCmd);
			COPY(name^, newCmd.name);
			COPY(value^, newCmd.commandString);
			(* append to command list *)
			c := commandList;
			WHILE (c.next # NIL) DO c := c.next; END;
			c.next := newCmd;
		ELSE
			Show("Command menu definition has errors."); KernelLog.Ln;
		END;
	END AddCommand;

BEGIN
	NEW(commandList); commandList.next := NIL;

	e := Configuration.GetSection("Applications.WMV24Component.CommandMenu");
	IF (e # NIL) THEN
		enum := e.GetContents();
		WHILE enum.HasMoreElements() DO
			p := enum.GetNext();
			IF p IS XML.Element THEN
				e := p (XML.Element);
				AddCommand(e.GetAttributeValue("name"), e.GetAttributeValue("value"));
			END;
		END;
	END;

	RETURN commandList.next;
END LoadCommandMenu;

PROCEDURE InitStrings;
BEGIN
	StrProgressInfo := Strings.NewString("ProgressInfo");
	StrCustomTextView := Strings.NewString("CustomTextView");
	StrTerminalComponent := Strings.NewString("TerminalComponent");
END InitStrings;

PROCEDURE Show(CONST string : ARRAY OF CHAR);
BEGIN
	KernelLog.String(ModuleName); KernelLog.String(": "); KernelLog.String(string);
END Show;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR window : Window;
BEGIN
	NEW(window, context, NIL);
END Restore;

PROCEDURE Open*(context: Commands.Context);
VAR window : Window;
BEGIN
	NEW(window, NIL, context);
END Open;

PROCEDURE NewTerminalComponent*(): XML.Element;
VAR component: TerminalComponent;
BEGIN NEW(component); RETURN component;
END NewTerminalComponent;


PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Timeout;
BEGIN{EXCLUSIVE}
	timeout := TRUE
END Timeout;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
	 timer: OBJECT VAR timer: Kernel.Timer; BEGIN{ACTIVE} NEW(timer); timer.Sleep(100); Timeout END;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	WHILE nofWindows >0 DO
		m.Broadcast(msg);
		timeout := FALSE; NEW(timer);
		AWAIT (nofWindows = 0) OR timeout;
	END;
END Cleanup;

PROCEDURE InitV24;
VAR res: LONGINT; msg: ARRAY 32 OF CHAR;
BEGIN
	Commands.Call("V24.Install",{},res,msg); (* auto-initialize V24 in Windows *)
END InitV24;


BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitStrings;
END WMV24Component.


V24.Install ~
Serials.Show ~

SystemTools.Free WMV24Component WMProgressComponents XYModem ~
WMV24Component.Open ~

Serials.CloseAllPorts ~