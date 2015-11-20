MODULE TeletextViewer;	(** AUTHOR "oljeger@student.ethz.ch"; PURPOSE "Aos Viewer for teletext pages"; *)

IMPORT
	Modules, Standard := WMStandardComponents,
	WM := WMWindowManager, Base := WMComponents, Messages := WMMessages, Graphics := WMGraphics,
	Editor:= WMEditors, Dates, Strings, TextUtilities, Texts, TVChannels, TeletextDecoder,
	TeletextFont, TeletextBrowser, XML, WMRestorable, WMTextView;

CONST
	Width = 300;
	ButtonWidth = 100;
	ButtonHeight = 30;
	ButtonsPerRow = 3;

	ModeNoRefresh = 0;
	ModeFastRefreshSame = 1;
	ModeSlowCycleSubs = 2;

	CaptionNoRefresh = "auto-refresh is off";
	CaptionFastRefreshSame = "immediate refresh";
	CaptionSlowCycleSubs = "30 sec. subpage cycle";

TYPE
	(** Extension of the generic TeletextPage type *)
	TeletextPage = OBJECT(TeletextBrowser.TeletextPage)
	VAR
		text*: Texts.Text
	END TeletextPage;

	(** Adapted browser for Aos Teletext view *)
	Browser = OBJECT(TeletextBrowser.TeletextBrowser)
		VAR
			content: TeletextPage;
			colors : ARRAY 8 OF LONGINT;

		PROCEDURE &Init*(suite: TeletextDecoder.TeletextSuite);
		BEGIN
			Init^(suite);
			NEW(content);
			loadProc := LoadPage;
			colors[0] := LONGINT(0FF0000FFH);	(* Red *)
			colors[1] := 0FF00FFH;		(* Green *)
			colors[2] := 0FFFFH;			(* Blue *)
			colors[3] := LONGINT(0FFFF00FFH);	(*Yellow *)
			colors[4] := LONGINT(0FF00FFFFH);	(* Magenta *)
			colors[5] := 0FFFFFFH;		(* Cyan *)
			colors[6] := LONGINT(0FFFFFFFFH);	(* White *)
			colors[7] := 0FFH			   (* Black *)
		END Init;

		(** Create an Texts.Text instance with colored text *)
		PROCEDURE LoadPage() : TeletextBrowser.TeletextPage;
		VAR
			attr, fg, bg : SHORTINT;
			boxed : BOOLEAN;
			i, begin, pos : LONGINT;
			nl: ARRAY 3 OF LONGINT;
			attributes: Texts.Attributes;
			text : Texts.Text;
		BEGIN
			IF content = NIL THEN
				NEW(content);
				pgData := NIL
			END;

			(* Display an alternative page if the requested page is not in cache *)
			IF pgData = NIL THEN
				NEW(content.text);
				text := content.text;
				text.AcquireWrite;
				TextUtilities.StrToText(text, 0, "The requested page is not available.");
				(* Yellow text *)
				NEW(attributes);
				attributes.color := LONGINT(0FFFF00FFH);
				attributes.bgcolor := 0FFH;
				pos := text.GetLength();
				text.SetAttributes(0, pos, attributes);
				nl[0] := Texts.NewLineChar;
				nl[1] := Texts.NewLineChar;
				nl[2] := 0;
				text.InsertUCS32(pos, nl);
				pos := text.GetLength();
				TextUtilities.StrToText(text, pos, "Try another page number.");
				(* White text *)
				NEW(attributes);
				attributes.color := LONGINT(0FFFFFFFFH);
				attributes.bgcolor := 0FFH;
				text.SetAttributes(pos, 24, attributes);
				text.ReleaseWrite;
				RETURN content
			END;

			(* Markup real teletext page *)
			NEW(content.text);
			text := content.text;
			text.AcquireWrite;
			pgData.text.AcquireRead;
			text.CopyFromText(pgData.text, 0, pgData.text.GetLength(), 0);
			pgData.text.ReleaseRead;
			text.ReleaseWrite;

			(* Extract attributes and apply them to the text *)
			begin := 0;
			attr := 52;	(* Compressed form of: fg = White, bg = Black, flashing = FALSE *)
			FOR i := 0 TO 41*24-1 DO
				IF (pgData.attributes[i] # attr) OR (i = 41*24-1) THEN
					(* The 'boxed' flag is coded by the sign bit *)
					boxed := attr < 0;
					attr := ABS(attr);
					(* Foreground is coded in the least 3 bits *)
					fg := attr MOD 8;
					bg := (attr DIV 8) MOD 8;
					NEW(attributes);
					attributes.color := colors[fg];
					IF transparent & ~boxed THEN
						attributes.bgcolor := 0H;
					ELSE
						attributes.bgcolor := colors[bg];
					END;
					text.AcquireWrite;
					text.SetAttributes (begin, i-begin, attributes);
					text.ReleaseWrite;
					attr := pgData.attributes[i];
					begin := i
				END
			END;

			(* Hide first line when in transparent mode *)
			IF transparent THEN
				NEW(attributes);
				attributes.color := 0H;
				attributes.bgcolor := 0H;
				text.AcquireWrite;
				text.SetAttributes (0, 41, attributes);
				text.ReleaseWrite
			END;
			RETURN content
		END LoadPage;

	END Browser;

	(** Channel selector window for Teletext *)
	ChannelSwitcher = OBJECT (Base.FormWindow)
		VAR
			nofChannels: LONGINT;
			buttons: POINTER TO ARRAY OF Standard.Button;
			browser : Browser;
			viewer: TeletextViewer;

		PROCEDURE &New *(browser : Browser; viewer: TeletextViewer);
		VAR
			i, left, top: LONGINT;
			panel: Standard.Panel;
			panels: POINTER TO ARRAY OF Standard.Panel;
			channel: TVChannels.TVChannel;
			chName : ARRAY 33 OF CHAR;
			now : Dates.DateTime;
		BEGIN
			SELF.browser := browser;
			SELF.viewer := viewer;
			nofChannels := TVChannels.channels.GetCount();
			(* add a panel *)
			NEW (panel);
			panel.fillColor.Set(0FFH);
			IF nofChannels MOD ButtonsPerRow = 0 THEN
				panel.bounds.SetHeight ((nofChannels DIV ButtonsPerRow) * ButtonHeight)
			ELSE
				panel.bounds.SetHeight ((nofChannels DIV ButtonsPerRow+1) * ButtonHeight)
			END;

			(* Create columns for the buttons *)
			NEW (panels, ButtonsPerRow);
			FOR i := 0 TO ButtonsPerRow-1 DO
				NEW(panels[i]);
				panels[i].alignment.Set (Base.AlignLeft);
				panels[i].bounds.SetWidth (ButtonWidth);
				panel.AddContent (panels[i])
			END;

			(* Set the content width *)
			IF ButtonsPerRow < 3 THEN
				panel.bounds.SetWidth (Width)
			ELSE
				panel.bounds.SetWidth (LEN(panels) * ButtonWidth)
			END;

			(* Create buttons for channel selection *)
			now := Dates.Now();
			NEW (buttons, nofChannels);
			FOR i := 0 TO nofChannels-1 DO
				NEW (buttons[i]);
				buttons[i].bounds.SetHeight (ButtonHeight);
				buttons[i].alignment.Set (Base.AlignTop);
				channel := TVChannels.channels.GetItem(i);
				COPY(channel.name, chName);
				buttons[i].caption.SetAOC (chName);
				IF ~channel.HasRecentData() THEN
					buttons[i].clTextDefault.Set(0747200FFH)
				END;
				buttons[i].onClick.Add (OnPushButton);
				panels[i MOD ButtonsPerRow].AddContent (buttons[i])
			END;

			(* create the form window with panel size *)
			Init(panel.bounds.GetWidth(), panel.bounds.GetHeight(), TRUE);
			SetContent(panel);

			(* open the window *)
			manager := WM.GetDefaultManager();
			SetTitle(WM.NewString("Teletext Channel Selector"));
			left := viewer.bounds.l + viewer.GetWidth() + 30;
			top := viewer.bounds.t;
			manager.Add(left, top, SELF, {WM.FlagFrame});
		END New;

		(** Determine which button has been pressed for correct action *)
		PROCEDURE FindButton (button: Standard.Button): LONGINT;
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (i < LEN(buttons)) & (buttons[i] # button) DO
				INC(i)
			END;
			RETURN i
		END FindButton;

		(** Switch channel and show index page *)
		PROCEDURE OnPushButton (sender, data: ANY);
		VAR
			button: Standard.Button;
			buttonNo: LONGINT;
			channel: TVChannels.TVChannel;
		BEGIN
			button := sender(Standard.Button);
			buttonNo := FindButton(button);
			channel := TVChannels.channels.GetItem(buttonNo);
			browser.SetSuiteFromFreq(channel.freq);
			viewer.ShowPage(browser.GetPage(100))
		END OnPushButton;

		(** Close the channel selector *)
		PROCEDURE Close;
		BEGIN
			viewer.channelSwitcher := NIL;
			Close^
		END Close;

	END ChannelSwitcher;

	(** Teletext viewer window *)
	TeletextViewer* = OBJECT (Base.FormWindow)
	VAR
		panel, magazines, navi : Standard.Panel;
		back, forward, prevSub, nextSub, refresh, transparent, channel, refreshMode : Standard.Button;
		refreshLabel: Standard.Label;
		timer : Standard.Timer;
		mag : ARRAY 8 OF Standard.Button;
		nrEditor, teleText: Editor.Editor;
		browser-: Browser;
		channelSwitcher : ChannelSwitcher;
		l, t, refrMode : LONGINT;
		next: TeletextViewer;

		PROCEDURE &New*;
		VAR
			i : LONGINT;
			magCaption : ARRAY 4 OF CHAR;
			ch : TVChannels.TVChannel;
			suite : TeletextDecoder.TeletextSuite;
		BEGIN
			(* create the background panel *)
			NEW(panel);
			panel.bounds.SetWidth(700); panel.bounds.SetHeight(510);

			(* create a toolbar for navigation *)
			NEW(navi); navi.bounds.SetHeight(25); navi.alignment.Set(Base.AlignTop);

			(* back button *)
			NEW(back); back.bounds.SetHeight(25); back.alignment.Set(Base.AlignLeft);
			back.bounds.SetWidth(30);
			back.imageName.SetAOC("prev.png");
			back.onClick.Add(OnBack);
			navi.AddContent(back);

			(* add an editor for the page number *)
			NEW(nrEditor);
			nrEditor.bounds.SetWidth(60);
			nrEditor.alignment.Set(Base.AlignLeft); nrEditor.multiLine.Set(FALSE);
			nrEditor.tv.textAlignV.Set(Graphics.AlignCenter);
			nrEditor.onEnter.Add(OnLoad);
			navi.AddContent(nrEditor);

			(* forward button *)
			NEW(forward); forward.bounds.SetHeight(25); forward.alignment.Set(Base.AlignLeft);
			forward.bounds.SetWidth(30);
			forward.imageName.SetAOC("next.png");
			forward.onClick.Add(OnForward);
			navi.AddContent(forward);

			(* previous subpage button *)
			NEW(prevSub); prevSub.bounds.SetHeight(25); prevSub.alignment.Set(Base.AlignLeft);
			prevSub.bounds.SetWidth(50); prevSub.caption.SetAOC("sub -");
			prevSub.onClick.Add(OnPrevSub);
			navi.AddContent(prevSub);

			(* next subpage button *)
			NEW(nextSub); nextSub.bounds.SetHeight(25); nextSub.alignment.Set(Base.AlignLeft);
			nextSub.bounds.SetWidth(50); nextSub.caption.SetAOC("sub +");
			nextSub.onClick.Add(OnNextSub);
			navi.AddContent(nextSub);

			(* refresh button *)
			NEW(refresh); refresh.bounds.SetHeight(25); refresh.alignment.Set(Base.AlignLeft);
			refresh.bounds.SetWidth(75); refresh.caption.SetAOC("   Refresh");
			refresh.imageName.SetAOC("refresh.png");
			refresh.onClick.Add(OnRefresh);
			navi.AddContent(refresh);

			(* transparent button *)
			NEW(transparent); transparent.alignment.Set(Base.AlignLeft);
			transparent.bounds.SetWidth(90); transparent.caption.SetAOC("Transparent");
			transparent.onClick.Add(OnTransp);
			navi.AddContent(transparent);

			(* refresh mode button *)
			NEW(refreshMode); refreshMode.bounds.SetHeight(25); refreshMode.alignment.Set(Base.AlignLeft);
			refreshMode.bounds.SetWidth(100); refreshMode.caption.SetAOC("Refresh mode");
			refreshMode.onClick.Add(OnRefreshMode);
			navi.AddContent(refreshMode);

			(* refresh mode label *)
			NEW(refreshLabel); refreshLabel.bounds.SetHeight(25); refreshLabel.alignment.Set(Base.AlignLeft);
			refreshLabel.bounds.SetWidth(125); refreshLabel.caption.SetAOC(CaptionNoRefresh);
			refreshLabel.fillColor.Set(053FFH); refreshLabel.textColor.Set(0FFFF00FFH);
			refreshLabel.alignH.Set(Graphics.AlignCenter);
			navi.AddContent(refreshLabel);

			refrMode := ModeNoRefresh;

			(* channel switch button *)
			NEW(channel); channel.bounds.SetHeight(25); channel.alignment.Set(Base.AlignLeft);
			channel.bounds.SetWidth(90); channel.caption.SetAOC("TV Channels");
			channel.onClick.Add(OnChannelSwitch);
			navi.AddContent(channel);

			panel.AddContent(navi);

			(* add a toolbar for magazine pages (n*100) *)
			NEW(magazines); magazines.bounds.SetHeight(300); magazines.alignment.Set(Base.AlignLeft);
			magazines.bounds.SetWidth(120);
			magazines.fillColor.Set (0H);

			(* magazine buttons *)
			magCaption := "000";
			FOR i := 0 TO 7 DO
				NEW(mag[i]);
				mag[i].bounds.SetHeight(25);
				mag[i].alignment.Set(Base.AlignTop);
				magCaption[0] := CHR((ORD('1') + i));
				mag[i].caption.SetAOC(magCaption);
				mag[i].clDefault.Set(009933AFH);
				mag[i].onClick.Add (OnMagClick);
				magazines.AddContent(mag[i]);
			END;

			panel.AddContent(magazines);

			(* add viewer for the teletext data *)
			NEW(teleText);
			teleText.alignment.Set(Base.AlignClient);
			teleText.tv.wrapMode.Set(WMTextView.NoWrap);
			teleText.allowScrollbars.Set(FALSE);
			panel.AddContent(teleText);

			(* create the form window with panel size *)
			Init(panel.bounds.GetWidth(), panel.bounds.GetHeight(), TRUE);
			SetContent(panel);
			teleText.tv.SetFont(TeletextFont.bimbofont);
			teleText.fillColor.Set(0H);
			panel.fillColor.Set(0FFH);

			(* open the window *)
			manager := WM.GetDefaultManager();
			SetTitle(WM.NewString("Teletext - No data available"));

			l := 100; t := 100;
			manager.Add(l, t, SELF, {WM.FlagFrame});

			(* Switch to first available TV channel *)
			ch := TVChannels.channels.GetItem(0);
			IF ch # NIL THEN
				suite := TeletextDecoder.SelectTeletextSuite(ch.freq);
				NEW(browser, suite);
				ShowPage(browser.GetPage(100))
			END;

			NEW(timer);

			next := window;
			window := SELF
		END New;

		(** Handle window messages *)
		PROCEDURE Handle(VAR m : Messages.Message);
		VAR
			data: XML.Element;
			str: ARRAY 10 OF CHAR;
		BEGIN
			IF (m.msgType = Messages.MsgExt) & (m.ext # NIL) THEN
				IF (m.ext IS WMRestorable.Storage) THEN
					NEW(data);  data.SetName("TeletextViewerData");
					Strings.IntToStr(browser.suite.channel.freq, str);
					data.SetAttributeValue("tvFreq", str);
					Strings.IntToStr(browser.page, str);
					data.SetAttributeValue("page", str);
					IF channelSwitcher # NIL THEN
						data.SetAttributeValue("switchWindow", "true")
					ELSE
						data.SetAttributeValue("switchWindow", "false")
					END;
					m.ext(WMRestorable.Storage).Add("TeletextViewer", "TeletextViewer.Restore", SELF, data)
				ELSE Handle^(m)
				END
			ELSE Handle^(m)
			END
		END Handle;

		(** Close the Viewer window *)
		PROCEDURE Close;
		BEGIN
			IF timer # NIL THEN
				timer.Stop(NIL, NIL)
			END;
			IF channelSwitcher # NIL THEN
				channelSwitcher.Close
			END;
			FreeWindow(SELF);
			Close^
		END Close;

		(** Switch to the given TV frequency *)
		PROCEDURE Switch*(tvFreq: LONGINT);
		BEGIN
			browser.SetSuiteFromFreq(tvFreq);
			ShowPage(browser.GetPage(100))
		END Switch;

		(** Switch to the given magazine (page X*100) *)
		PROCEDURE OnMagClick (sender, data: ANY);
		VAR
			button: Standard.Button;
			buttonNo, pageNo: LONGINT;
		BEGIN
			ClearNumberField;
			button := sender (Standard.Button);
			buttonNo := FindButton (button);
			pageNo := 100*buttonNo;
			ShowPage (browser.GetPage(pageNo + 100))
		END OnMagClick;

		(** Find magazine button for correct action *)
		PROCEDURE FindButton (button: Standard.Button): LONGINT;
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (i < 8) & (mag[i] # button) DO
				INC(i)
			END;
			RETURN i
		END FindButton;

		(** Display the teletext page on the screen *)
		PROCEDURE ShowPage(pg : TeletextBrowser.TeletextPage);
		VAR
			page: TeletextPage;
		BEGIN
			IF pg = NIL THEN
				SetText(NIL);
				RETURN
			END;
			page := pg(TeletextPage);
			SetText(page.text)
		END ShowPage;

		(** Go back one page *)
		PROCEDURE OnBack (sender, data : ANY);
		BEGIN
			ClearNumberField;
			ResetTimer();
			ShowPage(browser.GetPreviousPage())
		END OnBack;

		(** Go to the next page *)
		PROCEDURE OnForward (sender, data : ANY);
		BEGIN
			ClearNumberField;
			ResetTimer();
			ShowPage(browser.GetNextPage())
		END OnForward;

		(** Go to the previous subpage *)
		PROCEDURE OnPrevSub (sender, data : ANY);
		BEGIN
			ClearNumberField;
			ResetTimer();
			ShowPage(browser.GetPreviousSubpage())
		END OnPrevSub;

		(** Go to the next subpage *)
		PROCEDURE OnNextSub (sender, data : ANY);
		BEGIN
			ClearNumberField;
			ResetTimer();
			ShowPage(browser.GetNextSubpage())
		END OnNextSub;

		(** Toggle window transparency mode *)
		PROCEDURE OnTransp (sender, data : ANY);
		VAR
			i: LONGINT;
		BEGIN
			browser.transparent := ~browser.transparent;
			IF browser.transparent THEN
				(* Set the window transparent *)
				transparent.caption.SetAOC("Opaque");
				FOR i := 0 TO 7 DO
					mag[i].clDefault.Set(0H);
					mag[i].clTextDefault.Set(0H);
					mag[i].clTextHover.Set(0FFH)
				END;
				panel.fillColor.Set(0H);
				(* Assume subtitle mode => Enable automatic page refresh *)
				WHILE refrMode # ModeFastRefreshSame DO
					OnRefreshMode(NIL,NIL)
				END;
				timer.Start(sender, data)
			ELSE
				(* Set the window opaque *)
				transparent.caption.SetAOC("Transparent");
				FOR i := 0 TO 7 DO
					mag[i].clDefault.Set(009933AFH);
					mag[i].clTextDefault.Set(0FFFF00FFH);
					mag[i].clTextHover.Set(0FFFF00FFH);
				END;
				panel.fillColor.Set(0FFH);
				timer.Stop(sender, data)
			END;
			ShowPage(browser.ReloadPage())
		END OnTransp;

		(** Load the page number which has been entered in the input field *)
		PROCEDURE OnLoad (sender, data : ANY);
		VAR
			pageNo: LONGINT;
			nr : ARRAY 10 OF CHAR;
		BEGIN
			ResetTimer();
			nrEditor.GetAsString(nr);
			Strings.StrToInt(nr, pageNo);
			ClearNumberField;
			ShowPage(browser.GetPage(pageNo))
		END OnLoad;

		(** Reload the current page *)
		PROCEDURE OnRefresh (sender, data : ANY);
		BEGIN
			ResetTimer();
			ShowPage(browser.ReloadPage())
		END OnRefresh;

		(** Change the refresh mode *)
		PROCEDURE OnRefreshMode (sender, data : ANY);
		BEGIN
			refrMode := (refrMode+1) MOD 3;
			CASE refrMode OF
				ModeNoRefresh:
					(* No automatic refresh *)
					timer.Stop(NIL, NIL);
					refreshLabel.caption.SetAOC(CaptionNoRefresh)
			|	ModeFastRefreshSame:
				(* Reload same page 2x per second. Used for subtitles etc. *)
				timer.interval.Set(500);
				IF timer.onTimer.HasListeners() THEN
					timer.onTimer.Remove(OnNextSub)
				END;
				timer.onTimer.Add(OnRefresh);
				timer.Start(NIL, NIL);
				refreshLabel.caption.SetAOC(CaptionFastRefreshSame)
			|	ModeSlowCycleSubs:
				(* Go to the next subpage after a delay of 30 seconds *)
				timer.interval.Set(30000);
				IF timer.onTimer.HasListeners() THEN
					timer.onTimer.Remove(OnRefresh)
				END;
				timer.onTimer.Add(OnNextSub);
				timer.Start(NIL, NIL);
				refreshLabel.caption.SetAOC(CaptionSlowCycleSubs)
			END
		END OnRefreshMode;

		(** Display the given text in the viewer *)
		PROCEDURE SetText (text: Texts.Text);
		VAR
			title: ARRAY 50 OF CHAR;
			pnum: ARRAY 10 OF CHAR;
		BEGIN
			COPY(browser.channel, title);
			Strings.Append (title, " Teletext - ");
			IF text # NIL THEN
				Strings.IntToStr (browser.page+100, pnum);
				Strings.Append (title, pnum);
				SetTitle(WM.NewString(title))
			ELSE
				Strings.Append (title, "<Page does not exist>");
				SetTitle(WM.NewString(title));
				NEW(text)
			END;
			teleText.Acquire;
			teleText.SetText(text);
			teleText.Release
		END SetText;

		(** Clear the page number input field *)
		PROCEDURE ClearNumberField;
		BEGIN
			nrEditor.SetAsString("")
		END ClearNumberField;

		(** Open the channel selector window *)
		PROCEDURE OnChannelSwitch (sender, data : ANY);
		BEGIN
			IF channelSwitcher # NIL THEN
				manager := WM.GetDefaultManager();
				manager.ToFront(channelSwitcher);
				manager.SetWindowPos(channelSwitcher, l+GetWidth() + 30, t)
			ELSE
				NEW(channelSwitcher, browser, SELF)
			END
		END OnChannelSwitch;

		(** Reset the timer for automatic page reloading *)
		PROCEDURE ResetTimer;
		BEGIN
			IF timer.onTimer.HasListeners() THEN
				timer.Stop(NIL, NIL);
				timer.Start(NIL, NIL)
			END
		END ResetTimer;

		(** Overwrite standard 'Draw' routine: Move the channel selector window
			   together with the viewer window. *)
		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h, q : LONGINT);
		BEGIN
			Draw^(canvas, w, h, q);
			IF (channelSwitcher # NIL) & ((bounds.l # l) OR (bounds.t # t)) THEN
				l := bounds.l;
				t := bounds.t;
				manager := WM.GetDefaultManager();
				manager.SetWindowPos(channelSwitcher, l+GetWidth() + 30, t)
			END
		END Draw;

	END TeletextViewer;

VAR window: TeletextViewer;

(* Remove the window from the internal list (Finalizer) *)
PROCEDURE FreeWindow(wnd: TeletextViewer);
VAR
	w: TeletextViewer;
BEGIN
	IF wnd = NIL THEN
		RETURN
	ELSIF wnd = window THEN
		(* wnd is first list element *)
		window := window.next
	ELSE
		w := window;
		WHILE (w # NIL) & (w.next # wnd) DO
			w := w.next
		END;
		IF w # NIL THEN
			(* wnd found: remove it from the list *)
			w.next := wnd.next
		END
	END;
END FreeWindow;

(** Open a teletext viewer window *)
PROCEDURE Open*;
VAR
	w: TeletextViewer;
BEGIN
	NEW(w);
END Open;

(** Restore the windows *)
PROCEDURE Restore*(c : WMRestorable.Context);
VAR
	w: TeletextViewer;
	manager: WM.WindowManager;
	xml: XML.Element;
	s: Strings.String;
	freq, page: LONGINT;
	suite: TeletextDecoder.TeletextSuite;
BEGIN
	NEW(w);
	(* restore the desktop *)
	IF c.appData # NIL THEN
		xml := c.appData(XML.Element);
		(* Read the TV frequency to restore the channel *)
		s := xml.GetAttributeValue("tvFreq");
		IF s # NIL THEN
			Strings.StrToInt(s^, freq);
			suite := TeletextDecoder.SelectTeletextSuite(freq);
			IF suite # NIL THEN
				w.browser.SetSuite(suite)
			END;
		END;
		(* Read the page number *)
		s := xml.GetAttributeValue("page");
		IF s # NIL THEN
			Strings.StrToInt(s^, page);
			w.ShowPage(w.browser.GetPage(page+100));
		END;
		(* Check if the channel selector window was open *)
		s := xml.GetAttributeValue("switchWindow");
		IF s # NIL THEN
			IF s^ = "true" THEN
				w.OnChannelSwitch(NIL, NIL)
			END
		END;
	END;
	(* Show the restored window *)
	manager := WM.GetDefaultManager();
	manager.Remove(w);
	WMRestorable.AddByContext(w, c);
END Restore;

(** Finalizer routine *)
PROCEDURE Cleanup;
VAR
	w: TeletextViewer;
BEGIN
	w := window;
	WHILE w # NIL DO
		w.Close;
		w := w.next
	END;
	window := NIL
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END TeletextViewer.

TeletextViewer.Open ~
SystemTools.Free TeletextViewer ~