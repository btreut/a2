MODULE WMMixer;	(** AUTHOR "TF"; PURPOSE "Control the mixer of the default SoundDevices device"; *)

IMPORT
	Modules,
	SoundDevices, Strings, Plugins, WMComponents, WMStandardComponents, WMMessages, WMWindowManager, WMProperties;

VAR
	device : SoundDevices.Driver;
	master : SoundDevices.MixerChannel;

	StrMixer : Strings.String;

TYPE
	String = Strings.String;

	Mixer* = OBJECT(WMComponents.VisualComponent)
	VAR
		deviceName-, channelName- : WMProperties.StringProperty;

		name : WMStandardComponents.Label;
		value : WMStandardComponents.Scrollbar;
		mute : WMStandardComponents.Checkbox;

		channel : SoundDevices.MixerChannel;
		device : SoundDevices.Driver;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			NEW(deviceName, PrototypedeviceName, NIL, NIL); properties.Add(deviceName);
			NEW(channelName, PrototypechannelName, NIL, NIL); properties.Add(channelName);
			NEW(name); name.alignment.Set(WMComponents.AlignTop); name.bounds.SetHeight(20);
			AddContent(name);

			NEW(mute); mute.alignment.Set(WMComponents.AlignBottom); mute.bounds.SetHeight(20);
			mute.caption.SetAOC("Mute");
			mute.onClick.Add(MuteChanged);
			AddContent(mute);

			NEW(value); value.alignment.Set(WMComponents.AlignClient);
			value.bearing.SetLeft(20); value.bearing.SetRight(20);
			value.onPositionChanged.Add(VolChanged);
			value.max.Set(255);
			AddContent(value);
			SetNameAsString(StrMixer);
		END Init;

		PROCEDURE MuteChanged(sender, data : ANY);
		BEGIN
			IF channel # NIL THEN
				channel.SetMute(mute.state.Get () = WMStandardComponents.Checked);
			END
		END MuteChanged;

		PROCEDURE RecacheProperties;
		VAR s : String; dn, cn : ARRAY 128 OF CHAR;
		BEGIN
			RecacheProperties^;
			s := deviceName.Get(); IF s # NIL THEN COPY(s^, dn) END;
			s := channelName.Get(); IF s # NIL THEN COPY(s^, cn); name.caption.SetAOC(cn) END;
			IF device # NIL THEN device.UnregisterMixerChangeListener(MixerChangeListener) END;
			FindChannel(dn, cn, device, channel);
			IF channel # NIL THEN
				 sequencer.ScheduleEvent(SELF.MixerChangeEvent, device, channel)
			END;
			IF device # NIL THEN device.RegisterMixerChangeListener(MixerChangeListener) END;
		END RecacheProperties;

		PROCEDURE MixerChangeListener(channel : SoundDevices.MixerChannel);
		BEGIN
			 sequencer.ScheduleEvent(SELF.MixerChangeEvent, device, channel)
		END MixerChangeListener;

		PROCEDURE MixerChangeEvent(sender, data : ANY);
		VAR vol : LONGINT; m : BOOLEAN;
		BEGIN
			IF (data = channel) & (channel # NIL) THEN
				vol := channel.GetVolume();
				m := channel.GetIsMute();
				value.pos.Set(255 - vol);
				IF m THEN mute.state.Set(WMStandardComponents.Checked)
				ELSE mute.state.Set(WMStandardComponents.Unchecked)
				END;
			END;
		END MixerChangeEvent;

		PROCEDURE VolChanged(sender, data : ANY);
		BEGIN
			IF channel # NIL THEN
				channel.SetVolume(255 - value.pos.Get())
			END
		END VolChanged;

		PROCEDURE FindChannel(deviceName, channelName : ARRAY OF CHAR; VAR dev : SoundDevices.Driver; VAR channel : SoundDevices.MixerChannel);
		VAR i : LONGINT; ch : SoundDevices.MixerChannel; name : ARRAY 128 OF CHAR;
			p : Plugins.Plugin;
		BEGIN
			p := SoundDevices.devices.Get(deviceName);
			channel := NIL;
			IF (p # NIL) & (p IS SoundDevices.Driver) THEN dev := p(SoundDevices.Driver) ELSE dev := NIL END;
			IF dev # NIL THEN
				FOR i := 0 TO dev.GetNofMixerChannels() - 1 DO
					dev.GetMixerChannel(i, ch);
					ch.GetName(name);
					IF name = channelName THEN channel := ch END;
				END;
			END
		END FindChannel;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF device # NIL THEN device.UnregisterMixerChangeListener(MixerChangeListener) END;
		END Finalize;
	END Mixer;

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;
			(* To create a multi language app, try loading the respective XML instead of CreateForm()
			if the XML was not found or does not contain all needed elements, use CreateForm as fallback *)
			vc := CreateForm();

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);

			 WMWindowManager.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("Mixer"));
		END New;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel;
			dev : SoundDevices.Driver;
			i : LONGINT;
			ch : SoundDevices.MixerChannel;
			name : ARRAY 128 OF CHAR;
			m : Mixer;
		CONST MWidth = 60;
		BEGIN
			dev := SoundDevices.GetDefaultDevice();

			NEW(panel); panel.bounds.SetExtents(MWidth * dev.GetNofMixerChannels(), 200); panel.fillColor.Set(LONGINT(0FFFFFFFFH)); panel.takesFocus.Set(TRUE);

			IF dev # NIL THEN
				FOR i := 0 TO dev.GetNofMixerChannels() - 1 DO
					dev.GetMixerChannel(i, ch);
					ch.GetName(name);
					NEW(m);
					m.alignment.Set(WMComponents.AlignLeft); m.bounds.SetWidth(MWidth);
					m.channelName.SetAOC(name);
					panel.AddContent(m);
				END;
			END;
			RETURN panel
		END CreateForm;

		PROCEDURE Close;
		BEGIN
			DecCount;
			Close^;
		END Close;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END
		END Handle;
	END Window;

VAR
	PrototypedeviceName, PrototypechannelName: WMProperties.StringProperty;
	nofWindows : LONGINT;

PROCEDURE Open*;
VAR inst : Window;
BEGIN
	NEW(inst);
END Open;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE MasterIncVol*;
BEGIN
	IF master = NIL THEN
		device := SoundDevices.GetDefaultDevice();
		device.GetMixerChannel(0, master)
	END;
	IF master # NIL THEN
		master.SetVolume(Strings.Min(255, master.GetVolume() + 4))
	END;
END MasterIncVol;

PROCEDURE MasterDecVol*;
BEGIN
	IF master = NIL THEN
		device := SoundDevices.GetDefaultDevice();
		device.GetMixerChannel(0, master)
	END;
	IF master # NIL THEN
		master.SetVolume(Strings.Max(0, master.GetVolume() - 4))
	END;
END MasterDecVol;

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
	NEW(PrototypedeviceName, NIL, Strings.NewString(""), Strings.NewString("Name of the associated sound device"));
	NEW(PrototypechannelName, NIL, Strings.NewString("MasterVol"), Strings.NewString("Name of the associated sound channel"));
	StrMixer := Strings.NewString("Mixer");
END WMMixer.

WMMixer.Open ~
SystemTools.Free WMMixer ~

WMMixer.MasterDecVol ~
