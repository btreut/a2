MODULE TVRemoteControl;	(** AUTHOR "oljeger@student.ethz.ch"; PURPOSE "Graphical channel switcher for TV"; *)

IMPORT
	TVDriver, TV, TVChannels, Standard := WMStandardComponents, Base := WMComponents, Commands,
	Streams, WM := WMWindowManager, Modules, KernelLog, TeletextViewer, WMDialogs,
	Messages := WMMessages, WMRestorable, XML, Strings, WMGrids, WMStringGrids;

CONST
	Width = 200;
	ButtonWidth = 100;
	ButtonHeight = 30;
	ButtonsPerRow = 3;

	ButtonCol = 0FF00008FH;

TYPE
	(** Remote control window *)
	Window = OBJECT (Base.FormWindow)
	VAR
		vcd: TVDriver.VideoCaptureDevice;
		devNr: LONGINT;
		tuner: TVDriver.TVTuner;
		audio: TVDriver.Audio;
		tvWnd: TV.TvWindow;
		nofChannels: LONGINT;
		buttons: POINTER TO ARRAY OF Standard.Button;
		isMute: BOOLEAN;
		muteButton: Standard.Button;
		next: Window;

		PROCEDURE &New *(vcd: TVDriver.VideoCaptureDevice; devNr: LONGINT; openTV: BOOLEAN);
		VAR
			i: LONGINT;
			fix, panel: Standard.Panel;
			channel: TVChannels.TVChannel;
			openButton: Standard.Button;
			txtButton: Standard.Button;
			channelList : WMStringGrids.StringGrid;
		BEGIN
			nofChannels := TVChannels.channels.GetCount();
			IF vcd = NIL THEN
				KernelLog.String("{TVRemoteControl} ERROR: Fail to locate video capture device.");
				KernelLog.Ln;
				RETURN;
			END;
			SELF.vcd := vcd;
			tuner := vcd.GetTuner();
			audio := vcd.GetAudio();
			SELF.devNr := devNr;
			NEW(panel);
			panel.alignment.Set(Base.AlignClient);

			(* add a panel *)
			panel.fillColor.Set(0FFH);

			(* add 'fix' panel *)
			NEW (fix);
			fix.alignment.Set (Base.AlignTop);
			fix.bounds.SetHeight (ButtonHeight);

			NEW (channelList);

			channelList.model.Acquire;
			channelList.model.SetNofCols(1);
			channelList.model.SetNofRows(1);
			channelList.SetSelectionMode(WMGrids.GridSelectRows);
			channelList.model.Release;


			(* add 'Open TV Window' button *)
			NEW (openButton);
			openButton.caption.SetAOC ("Open TV");
			openButton.bounds.SetWidth (Width DIV 3);
			openButton.onClick.Add (OnOpen);
			openButton.clDefault.Set (ButtonCol);
			openButton.alignment.Set (Base.AlignLeft);
			openButton.bounds.SetHeight (ButtonHeight);
			fix.AddContent (openButton);

			(* add 'Mute' button *)
			NEW(muteButton);
			muteButton.caption.SetAOC ("Mute");
			muteButton.bounds.SetWidth (Width DIV 3);
			muteButton.onClick.Add (OnMuteToggle);
			muteButton.clDefault.Set (ButtonCol);
			muteButton.alignment.Set (Base.AlignLeft);
			muteButton.bounds.SetHeight (ButtonHeight);
			fix.AddContent (muteButton);
			isMute := FALSE;

			(* add 'TXT' button *)
			NEW (txtButton);
			txtButton.caption.SetAOC ("TXT");
			txtButton.bounds.SetWidth (Width DIV 3);
			txtButton.clDefault.Set (ButtonCol);
			txtButton.onClick.Add (OnTXT);
			txtButton.alignment.Set (Base.AlignLeft);
			txtButton.bounds.SetHeight (ButtonHeight);
			fix.AddContent (txtButton);

			panel.AddContent (fix);

			panel.AddContent (channelList);
			channelList.alignment.Set(Base.AlignClient);


	(*		(* add channel buttons *)
			IF nofChannels > 0 THEN
				NEW (buttons, nofChannels);
				FOR i := 0 TO nofChannels-1 DO
					NEW (buttons[i]);
					buttons[i].bounds.SetHeight (ButtonHeight);
					buttons[i].alignment.Set (Base.AlignTop);
					channel := TVChannels.channels.GetItem(i);
					buttons[i].caption.SetAOC (channel.name);
					buttons[i].onClick.Add (OnPush);
					panels[i MOD ButtonsPerRow].AddContent (buttons[i])
				END
			END; *)

			(* create the form window with panel size *)
			Init(Width, 300, TRUE);
			SetContent(panel);

			(* open the window *)
			manager := WM.GetDefaultManager();
			SetTitle(WM.NewString("TV Remote Control"));
			manager.Add(770, 100, SELF, {WM.FlagFrame});
			next := window;
			window := SELF;

			channelList.model.Acquire;
			channelList.model.SetNofRows(nofChannels);
			FOR i := 0 TO nofChannels-1 DO
				channel := TVChannels.channels.GetItem(i);
				channelList.model.SetCellText(0, i,Strings.NewString(channel.name));
				channelList.model.SetCellData(0, i, channel);
			END;
			channelList.model.Release;
			channelList.Invalidate;
			channelList.onClick.Add(OnPush);


			(* open the TV window (there will be only one single instance) *)
			IF openTV THEN
				OnOpen (NIL, NIL)
			END
		END New;

		(** Find a button for correct action *)
		PROCEDURE FindButton (button: Standard.Button): LONGINT;
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (i < LEN(buttons)) & (buttons[i] # button) DO
				INC(i)
			END;
			RETURN i
		END FindButton;

		(** Switch to the appropriate TV channel *)
		PROCEDURE OnPush (sender, data: ANY);
		VAR channel: TVChannels.TVChannel;
		BEGIN
			IF (data # NIL) & (data IS TVChannels.TVChannel) THEN
				channel := data(TVChannels.TVChannel);
				IF tuner # NIL THEN
					tuner.SetTVFrequency (channel.freq)
				END
			END
		END OnPush;

		(** Toggle audio mute state *)
		PROCEDURE OnMuteToggle (sender, data: ANY);
		BEGIN
			IF isMute THEN
				muteButton.caption.SetAOC ("Mute");
				audio.SetAudioUnmute
			ELSE
				muteButton.caption.SetAOC ("Unmute");
				audio.SetAudioMute
			END;
			isMute := ~isMute
		END OnMuteToggle;

		(** Open a TV window. Do nothing if already open *)
		PROCEDURE OnOpen (sender, data: ANY);
		BEGIN
			IF ~ vcd.IsVideoOpen() THEN
				NEW(tvWnd, vcd);
				(* Set the device number for non-default devices *)
				IF devNr # -1 THEN
					tvWnd.vcdNr := devNr
				END
			END
		END OnOpen;

		(** Open a teletext viewer window *)
		PROCEDURE OnTXT (sender, data: ANY);
		VAR
			viewer: TeletextViewer.TeletextViewer;
		BEGIN
			NEW(viewer);
			IF (tvWnd # NIL) & tvWnd.alive THEN
				viewer.Switch(tvWnd.GetTVFreq());
				tvWnd.StartTeletextCapture
			ELSE
				tvWnd := NIL
			END
		END OnTXT;

		(** Select another VideoCaptureDevice *)
		PROCEDURE SetDevice* (dev: LONGINT);
		BEGIN
			vcd := TVDriver.GetVideoDevice (dev);
			tuner := vcd.GetTuner();
			audio := vcd.GetAudio();
			devNr := dev
		END SetDevice;

		(** Close the remote control window *)
		PROCEDURE Close;
		BEGIN
			FreeWindow(SELF);
			Close^
		END Close;

		(** Handle window messages *)
		PROCEDURE Handle(VAR m : Messages.Message);
		VAR
			data: XML.Element;
			str: ARRAY 10 OF CHAR;
		BEGIN
			IF (m.msgType = Messages.MsgExt) & (m.ext # NIL) THEN
				IF (m.ext IS WMRestorable.Storage) THEN
					NEW(data);  data.SetName("TVRemoteControlData");
					Strings.IntToStr(devNr, str);
					data.SetAttributeValue("device", str);
					m.ext(WMRestorable.Storage).Add("TVRemoteControl",
							"TVRemoteControl.Restore", SELF, data)
				ELSE Handle^(m)
				END
			ELSE Handle^(m)
			END
		END Handle;

	END Window;

VAR
	window: Window;

(** Open a remote control window *)
PROCEDURE Open* (context : Commands.Context);
VAR
	vcd : TVDriver.VideoCaptureDevice;
	devNr: LONGINT;
	wnd: Window;
BEGIN {EXCLUSIVE}
	IF context # NIL THEN
		(* Read VideoCaptureDevice number *)
		IF context.arg.GetInteger(devNr, FALSE) THEN
			vcd := TVDriver.GetVideoDevice(devNr)
		ELSE
			devNr := -1;
			vcd := TVDriver.GetDefaultDevice()
		END
	ELSE
		devNr := -1;
		vcd := TVDriver.GetDefaultDevice()
	END;
	(* Display error message if no VideoCaptureDevice has been found *)
	IF vcd = NIL THEN
		IF (context # NIL) & (context.arg.res = 0) THEN
			context.error.String("{TV} Parameter is not a valid video device number."); context.error.Ln;
			WMDialogs.Error("TV - Error", "Parameter is not a valid video device number. Make sure that all TV card drivers are loaded.");
			RETURN;
		ELSE
			context.error.String("{TV} Cannot open TV window: Fail to locate video capture device.");
			context.error.Ln;
			WMDialogs.Error("TVRemoteControl - Error",
				"Cannot open TV window: Fail to locate video capture device. Install device before opening the TV window. Example: BT848.Install");
			RETURN
		END
	END;
	NEW (wnd, vcd, devNr, TRUE);
END Open;

(** Restore stored windows *)
PROCEDURE Restore*(c : WMRestorable.Context);
VAR
	manager: WM.WindowManager;
	xml: XML.Element;
	s: Strings.String;
	devNr: LONGINT;
	vcd: TVDriver.VideoCaptureDevice;
	wnd: Window;
BEGIN
	(* restore the desktop *)
	IF c.appData # NIL THEN
		xml := c.appData(XML.Element);
		s := xml.GetAttributeValue("device");
		IF s # NIL THEN
			(* Read device number *)
			Strings.StrToInt(s^, devNr);
			IF devNr = -1 THEN
				vcd := TVDriver.GetDefaultDevice()
			ELSE
				vcd := TVDriver.GetVideoDevice(devNr)
			END;
			IF vcd # NIL THEN
				NEW(wnd, vcd, devNr, FALSE);
				manager := WM.GetDefaultManager();
				manager.Remove(wnd);
				WMRestorable.AddByContext(wnd, c)
			ELSE
				KernelLog.String("{TVRemoteControl} Could not restore the RemoteControl window."); KernelLog.Ln;
				KernelLog.String("{TVRemoteControl} Install the device driver first, e.g. BT848.Install"); KernelLog.Ln
			END
		END
	END
END Restore;

(** Remove the window from the internal channelList *)
PROCEDURE FreeWindow(wnd: Window);
VAR
	w: Window;
BEGIN
	IF wnd = NIL THEN
		RETURN
	ELSIF wnd = window THEN
		(* wnd is first channelList element *)
		window := window.next
	ELSE
		w := window;
		WHILE (w # NIL) & (w.next # wnd) DO
			w := w.next
		END;
		IF w # NIL THEN
			(* wnd found: remove it from the channelList *)
			w.next := wnd.next
		END
	END;
END FreeWindow;

(** Term hander *)
PROCEDURE Cleanup;
VAR
	w: Window;
BEGIN
	w := window;
	WHILE w # NIL DO
		w.Close;
		w := w.next
	END;
	window := NIL
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END TVRemoteControl.


SystemTools.Free TVRemoteControl ~
TVRemoteControl.Open ~