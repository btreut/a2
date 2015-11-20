MODULE WMPlayer; (** AUTHOR "PL"; PURPOSE "MediaPlayer GUI"; *)

IMPORT
	Strings, Modules, Commands, Files, Texts, TextUtilities,
	WMGraphics, WMMessages, WMComponents, WMStandardComponents, WMWindowManager, WMTextView, WMDialogs,
	MediaPlayer;

CONST
	WindowTitle = "Media Player";
	DefaultWidth = 800;
	DefaultHeight = 60;

	StyleRegular = {};
	StyleBold = {0};

	Tab = CHR(Texts.TabChar);
TYPE

	KillerMsg = OBJECT
	END KillerMsg;

TYPE

	(* Small window showing information about the currently loaded content (framerate, etc. ) *)
	InfoWindow = OBJECT(WMComponents.FormWindow)
	VAR
		data : MediaPlayer.Setup;

		tv : WMTextView.TextView;
		text : Texts.Text;
		tw : TextUtilities.TextWriter;

		next : InfoWindow;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			tabPositions : WMTextView.TabPositions; tabStops : WMTextView.CustomTabStops;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(300, 100); panel.fillColor.Set(LONGINT(0FFFFFFFFH));

			NEW(tv);tv.alignment.Set(WMComponents.AlignClient);
			tv.isMultiLine.Set(TRUE); tv.showBorder.Set(TRUE); tv.alwaysShowCursor.Set(FALSE);
			panel.AddContent(tv);

			NEW(tabPositions, 2); tabPositions[0] := 70; tabPositions[1] := 150;
			NEW(tabStops, tabPositions);
			tv.SetTabStops(tabStops);
			RETURN panel;
		END CreateForm;

		PROCEDURE CreateContent;
		VAR framerate : REAL; hours, minutes, seconds : LONGINT;
		BEGIN
			NEW(text); NEW(tw, text);
			tw.SetFontStyle(StyleBold); tw.String("Content"); tw.Char(Tab); tw.SetFontStyle(StyleRegular);
			tw.String(data.uri);
			tw.Ln;
			tw.String("________________________________________________");
			tw.Ln;
			tw.SetFontStyle(StyleBold); tw.String("Duration"); tw.Char(Tab); tw.SetFontStyle(StyleRegular);
			ConvertTime(data.maxTime*100, hours, minutes, seconds);
			IF hours # 0 THEN tw.Int(hours, 0); tw.String("h "); END;
			IF (hours # 0) OR (minutes # 0) THEN tw.Int(minutes, 0); tw.String("min "); END;
			tw.Int(seconds, 0); tw.String("s");
			tw.Ln;
			tw.SetFontStyle(StyleBold); tw.String("Video"); tw.Char(Tab); tw.SetFontStyle(StyleRegular);
			IF data.hasVideo THEN
				tw.Int(data.width, 0); tw.String("x"); tw.Int(data.height, 0); tw.String(", ");
				IF data.mspf # 0 THEN
					framerate := 1000 / data.mspf;
					tw.Int(ENTIER(framerate), 0);
					IF framerate - ENTIER(framerate) # 0 THEN
						tw.Char("."); tw.Int(ENTIER((framerate - ENTIER(framerate))*1000), 0);
					END;
					tw.String(" frames per second");
				ELSE
					tw.String("Unknown framerate");
				END;
			ELSE
				tw.String("n/a");
			END;
			tw.Ln;
			tw.SetFontStyle(StyleBold); tw.String("Audio"); tw.Char(9X);tw.SetFontStyle(StyleRegular);
			IF data.hasAudio THEN
				tw.Int(data.channels, 0); tw.String(" Channel(s), "); tw.Int(data.rate, 0); tw.String("Hz, ");
				tw.Int(data.bits, 0); tw.String(" bits");
			ELSE
				tw.String("n/a");
			END;
			tw.Ln;
			tw.Update;
			tv.SetText(text);
		END CreateContent;

		PROCEDURE &New*(setupData : MediaPlayer.Setup);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			ASSERT(setupData # NIL);
			data := setupData;
			vc := CreateForm(); CreateContent;
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString("Content Info"));
			WMWindowManager.AddWindow (SELF, 100, 100);
			manager := WMWindowManager.GetDefaultManager ();
			manager.SetFocus(SELF);
		END New;

	END InfoWindow;

TYPE

	Control = OBJECT(WMComponents.VisualComponent)
	VAR
		playBtn, stopBtn, pauseBtn : WMStandardComponents.Button;
		owner : Window;

		PROCEDURE ButtonHandler(sender, data : ANY);
		BEGIN
			IF (sender = playBtn) THEN
				owner.ButtonHandler(owner.playBtn, NIL);
			ELSIF (sender = pauseBtn) THEN
				owner.ButtonHandler(owner.pauseBtn, NIL);
			ELSIF (sender = stopBtn) THEN
				owner.ButtonHandler(owner.stopBtn, NIL);
			END;
		END ButtonHandler;

		PROCEDURE &New(owner : Window);
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			ASSERT(owner # NIL);
			SELF.owner := owner;
			Init;

			NEW(panel); panel.alignment.Set(WMComponents.AlignTop);
			panel.bounds.SetHeight(20);
			AddContent(panel);

			NEW(playBtn); playBtn.alignment.Set(WMComponents.AlignLeft);
			playBtn.caption.SetAOC("Play");
			playBtn.onClick.Add(ButtonHandler);
			panel.AddContent(playBtn);

			NEW(pauseBtn); pauseBtn.alignment.Set(WMComponents.AlignLeft);
			pauseBtn.caption.SetAOC("Pause");
			pauseBtn.onClick.Add(ButtonHandler);
			panel.AddContent(pauseBtn);

			NEW(stopBtn); stopBtn.alignment.Set(WMComponents.AlignLeft);
			stopBtn.caption.SetAOC("Stop");
			stopBtn.onClick.Add(ButtonHandler);
			panel.AddContent(stopBtn);
		END New;

	END Control;

TYPE

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		playBtn, stopBtn, pauseBtn, ffBtn, rewBtn, infoBtn : WMStandardComponents.Button;
		search: WMStandardComponents.Scrollbar;

		timeLbl, totTimeLbl: WMStandardComponents.Label;

		player : MediaPlayer.Player;
		stepSize : LONGINT;

		(* Info about currently loaded content *)
		filename : Files.FileName;
		setupData : MediaPlayer.Setup;
		infos : InfoWindow;

		windowInfo : WMWindowManager.WindowInfo;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel, toolbar : WMStandardComponents.Panel;
			label: WMStandardComponents.Label;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(DefaultWidth, DefaultHeight); panel.fillColor.Set(LONGINT(0FFFFFFFFH)); panel.takesFocus.Set(TRUE);

			(* Search / position scrollbar *)
			NEW(toolbar); toolbar.fillColor.Set(LONGINT(0FFFFFFFFH)); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);

			NEW(search); search.alignment.Set(WMComponents.AlignClient);
			search.vertical.Set(FALSE); search.max.Set(1000); search.pos.Set(0);
			toolbar.AddContent(search);

			(* Buttons *)
			NEW(toolbar); toolbar.fillColor.Set(LONGINT(0A0A0A0FFH)); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);

			NEW(playBtn); playBtn.alignment.Set(WMComponents.AlignLeft); playBtn.caption.SetAOC("Play");
			toolbar.AddContent(playBtn);

			NEW(pauseBtn); pauseBtn.alignment.Set(WMComponents.AlignLeft); pauseBtn.caption.SetAOC("Pause");
			toolbar.AddContent(pauseBtn);

			NEW(stopBtn); stopBtn.alignment.Set(WMComponents.AlignLeft); stopBtn.caption.SetAOC("Stop");
			toolbar.AddContent(stopBtn);

			NEW(rewBtn); rewBtn.alignment.Set(WMComponents.AlignLeft); rewBtn.caption.SetAOC("<<");
			toolbar.AddContent(rewBtn); rewBtn.isRepeating.Set(TRUE);

			NEW(ffBtn); ffBtn.alignment.Set(WMComponents.AlignLeft); ffBtn.caption.SetAOC(">>");
			toolbar.AddContent(ffBtn); ffBtn.isRepeating.Set(TRUE);

			NEW(infoBtn); infoBtn.alignment.Set(WMComponents.AlignRight); infoBtn.caption.SetAOC("Info");
			toolbar.AddContent(infoBtn);

			(* Info Labels *)
			NEW(label); label.bounds.SetWidth(100); label.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(label); label.caption.SetAOC(" Elapsed Time: ");

			NEW(timeLbl); timeLbl.bounds.SetWidth(100); timeLbl.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(timeLbl); timeLbl.caption.SetAOC("00:00:00");

			NEW(label); label.bounds.SetWidth(100); label.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(label); label.caption.SetAOC("Total Time: ");

			NEW(totTimeLbl); totTimeLbl.bounds.SetWidth(100); totTimeLbl.alignment.Set(WMComponents.AlignLeft);
			panel.AddContent(totTimeLbl); timeLbl.caption.SetAOC("00:00:00");

			RETURN panel;
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			NEW(player);
			player.setup := SetUpController;
			player.update := Update;
			player.console := FALSE;

			IncCount();
			vc := CreateForm();

			playBtn.onClick.Add(ButtonHandler);
			stopBtn.onClick.Add(ButtonHandler);
			pauseBtn.onClick.Add(ButtonHandler);
			ffBtn.onClick.Add(ButtonHandler);
			rewBtn.onClick.Add(ButtonHandler);
			infoBtn.onClick.Add(ButtonHandler);
			search.onPositionChanged.Add(SliderSearch);

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString(WindowTitle));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMPlayer.png", TRUE));

			WMWindowManager.ClearInfo(windowInfo);
			windowInfo.vc.width := 100;
			windowInfo.vc.height := 20;
			windowInfo.vc.generator := SELF.GenerateControl;

			WMWindowManager.ExtAddWindow(SELF, 100, 30, {WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop, WMWindowManager.FlagClose, WMWindowManager.FlagMinimize});
			manager := WMWindowManager.GetDefaultManager();
			manager.SetFocus(SELF);
		END New;

		PROCEDURE GenerateControl*() : ANY;
		VAR control : Control;
		BEGIN
			NEW(control, SELF);
			RETURN control;
		END GenerateControl;

		PROCEDURE Open*(CONST fileName : ARRAY OF CHAR);
		VAR res : LONGINT; msg : ARRAY 256 OF CHAR;
		BEGIN
			COPY(fileName, filename);
			player.Open(filename, msg, res);
			IF res # MediaPlayer.Ok THEN
				WMDialogs.Error(WindowTitle, msg);
				SetTitle(Strings.NewString("Media Player"));
				COPY("", windowInfo.openDocuments[0].name);
			ELSE
				msg := "Media Player - "; Strings.Append(msg, fileName);
				SetTitle(Strings.NewString(msg));
				COPY(filename, windowInfo.openDocuments[0].name);
			END;
			SetInfo(windowInfo);
		END Open;

		PROCEDURE ButtonHandler(sender, data : ANY);
		VAR b : WMStandardComponents.Button; info : InfoWindow;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ButtonHandler, sender, data);
			ELSE
				IF (sender # NIL) & (sender IS WMStandardComponents.Button) THEN
					b := sender (WMStandardComponents.Button);
					IF b = playBtn THEN player.Play;
					ELSIF b = stopBtn THEN player.Stop;
					ELSIF b = pauseBtn THEN player.Pause;
					ELSIF b = ffBtn THEN player.SetPos(player.GetPos() + stepSize);
					ELSIF b = rewBtn THEN player.SetPos(player.GetPos() - 2*stepSize);
					ELSIF b = infoBtn THEN
						IF setupData # NIL THEN
							NEW(info, setupData);
							BEGIN {EXCLUSIVE} info.next := infos; infos := info; END;
						ELSE
							WMDialogs.Error(WindowTitle, "No content loaded.");
						END;
					END;
				END;
			END;
		END ButtonHandler;

		PROCEDURE Close;
		BEGIN
			player.Close;
			(* Close all open InfoWindow if any *)
			WHILE infos # NIL DO infos.Close; infos := infos.next; END;
			Close^;
			DecCount;
		END Close;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END;
		END Handle;

		PROCEDURE SliderSearch(sender, data: ANY);
		VAR pos: LONGINT;
		BEGIN
			pos := search.pos.Get();
			player.SetPos(pos)
		END SliderSearch;

		(* Update the Info Labels *)
		PROCEDURE Update*(status, pos, maxpos, displayTime: LONGINT);
		VAR temp : ARRAY 16 OF CHAR;
		BEGIN
			ConvertTimeToStr(displayTime * 100, temp);
			timeLbl.caption.SetAOC(temp);
			IF (setupData # NIL) & (setupData.hasVideo) THEN
				search.pos.Set(pos);
			ELSE
				search.pos.Set(displayTime);
			END;
			IF (pos # 0) & (displayTime # 0) THEN stepSize := 10* pos DIV displayTime END
		END Update;

		(* Init the GUI with infos from the Decoder *)
		PROCEDURE SetUpController*(setup : MediaPlayer.Setup);
		VAR temp : ARRAY 16 OF CHAR;
		BEGIN
			setupData := setup;
			IF setup.canSeek THEN
				search.visible.Set(TRUE);
				IF setup.hasVideo THEN
					search.max.Set(setup.maxFrames);
					search.pageSize.Set(setup.maxFrames DIV 25);
				ELSE
					search.max.Set(setup.maxTime);
					search.pageSize.Set(setup.maxTime DIV 100);
				END;
			ELSE
				search.visible.Set(FALSE)
			END;
			ConvertTimeToStr(setup.maxTime * 100, temp);
			totTimeLbl.caption.SetAOC(temp)
		END SetUpController;

	END Window;

VAR
	nofWindows : LONGINT;

(* Convert milliseconds to hours:minutes:seconds *)
PROCEDURE ConvertTime(ms : LONGINT; VAR hours, minutes, seconds : LONGINT);
CONST Hour = 60*60*1000; Minute = 60*1000;
VAR rest : LONGINT;
BEGIN
	hours := ms DIV Hour; rest := ms MOD Hour;
	minutes := rest DIV Minute; rest := rest MOD Minute;
	seconds := rest DIV 1000;
END ConvertTime;

(* Convert time in millisecond into string of the form "hh:mm:ss" *)
PROCEDURE ConvertTimeToStr(ms : LONGINT; VAR timeStr : ARRAY OF CHAR);
VAR hour, minute, second : LONGINT; nbr : ARRAY 4 OF CHAR;

	(* Append 'number' to 'string' using 2 or more digits *)
	PROCEDURE Append(VAR string : ARRAY OF CHAR; number : LONGINT);
	BEGIN
		Strings.IntToStr(number, nbr);
		IF number >= 10 THEN Strings.Append(string, nbr);
		ELSE Strings.Append(string, "0"); Strings.Append(string, nbr);
		END;
	END Append;

BEGIN
	ConvertTime(ms, hour, minute, second);
	timeStr := "";
	Append(timeStr, hour); Strings.Append(timeStr, ":");
	Append(timeStr, minute); Strings.Append(timeStr, ":");
	Append(timeStr, second);
END ConvertTimeToStr;

PROCEDURE Open*(context : Commands.Context); (** filename ~ *)
VAR inst : Window; fileName: Files.FileName;
BEGIN
	IF context.arg.GetString(fileName) THEN
		NEW(inst);
		inst.Open(fileName);
	END
END Open;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMPlayer.

------------------------------------------------------------------------------
SystemTools.Free WMPlayer ~
WMPlayer.Open track.mp3~
WMPlayer.Open test.wav~
WMPlayer.Open FAT:tndx.avi~
WMPlayer.Open flags.avi~

WMPlayer.Open Filme:/test.wav ~
WMPlayer.Open Filme:/test2.wav ~
WMPlayer.Open Filme:/test.mp3 ~

MediaPlayer.Open Filme:/test.mp3 ~

MediaPlayer.Close ~

