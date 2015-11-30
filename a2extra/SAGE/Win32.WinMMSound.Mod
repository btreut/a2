MODULE WinMMSound; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Sound driver for WinAos"; *)

IMPORT

	SYSTEM, Plugins, SoundDevices, WinMM, WinMMUtils, Commands, Modules, Strings; 

TYPE

	DriverList = POINTER TO RECORD
		driver: Driver;
		next: DriverList;
	END;
	
	Listenerlist = RECORD
		proc: SoundDevices.MixerChangedProc;
		next: POINTER TO Listenerlist
	END;
	
	MixerChannelList = POINTER TO RECORD
		mixerChannel: MixerChannel;
		next: MixerChannelList;
	END;

	Driver = OBJECT(SoundDevices.Driver)
	VAR
		NofMixerChannels: LONGINT;
		firstMixerChannel, lastMixerChannel: MixerChannelList;
		productName: ARRAY WinMM.MAXPNAMELEN * 2 OF CHAR;
		listenerlist: POINTER TO Listenerlist; (* list of MixerChangedProc *)

	PROCEDURE &Constr*(CONST name: ARRAY OF CHAR);
	VAR
		nRes: LONGINT;
	BEGIN
	
		COPY(name, productName);
	
		NofMixerChannels := 0;
		firstMixerChannel := NIL;
		lastMixerChannel := NIL;
		
		NEW(listenerlist); (* no mixer listeners so far *)
		listenerlist.proc := NIL;
		listenerlist.next := NIL;

		(* Register Driver in SoundDevices *)
		SoundDevices.devices.Add(SELF, nRes);
		ASSERT(nRes = Plugins.Ok);

		(* Update driver table *)
		SoundDevices.devices.GetAll(DriverTab);
		
		Enable
	END Constr;

	PROCEDURE Finalize;
	BEGIN
		Disable;
		(* Remove registered driver *)
		SoundDevices.devices.Remove(SELF);
		(* Update driver table *)
		SoundDevices.devices.GetAll(DriverTab)
	END Finalize;

	PROCEDURE Init*;
	BEGIN
		SetName(productName);
	END Init;
	
	PROCEDURE Enable*;
	BEGIN
	END Enable;
	
	PROCEDURE Disable*;
	BEGIN
	END Disable;

	PROCEDURE NofNativeFrequences*(): LONGINT;
	BEGIN
		RETURN 0;
	END NofNativeFrequences;

	PROCEDURE GetNativeFrequency*(nr: LONGINT): LONGINT;
	BEGIN
		RETURN 48000;
	END GetNativeFrequency;

	PROCEDURE NofSamplingResolutions*(): LONGINT;
	BEGIN
		RETURN 2 (* 16 Bit and 8 Bit *)
	END NofSamplingResolutions;

	PROCEDURE GetSamplingResolution(nr: LONGINT): LONGINT;
	BEGIN
		ASSERT((nr >= 0) & (nr <2));
		IF nr = 0 THEN
			RETURN 16
		ELSE
			RETURN 8
		END;
	END GetSamplingResolution;

	PROCEDURE NofSubChannelSettings*() : LONGINT;
	BEGIN
		RETURN 2 (* Mono and stereo *)
	END NofSubChannelSettings;

	PROCEDURE GetSubChannelSetting*(nr : LONGINT) : LONGINT;
	BEGIN
		ASSERT((nr >= 0) & (nr <= 2));
		IF nr = 0 THEN
			RETURN 1 (* Mono *)
		ELSE
			RETURN 2 (* Stereo *)
		END
	END GetSubChannelSetting;

	PROCEDURE NofWaveFormats*(): LONGINT;
	BEGIN
		RETURN 1 (* Only PCM *)
	END NofWaveFormats;
	
	PROCEDURE AddMixerChannel(channel: MixerChannel);
	VAR
		itemMixerChannelList: MixerChannelList;
	BEGIN
		NEW(itemMixerChannelList);
		INC(NofMixerChannels);
		itemMixerChannelList.mixerChannel := channel;
		itemMixerChannelList.next := NIL;
		IF firstMixerChannel = NIL THEN
			firstMixerChannel := itemMixerChannelList;
			lastMixerChannel := itemMixerChannelList
		ELSE
			lastMixerChannel.next := itemMixerChannelList;
			lastMixerChannel := itemMixerChannelList
		END
	END AddMixerChannel;

	PROCEDURE RegisterMixerChangeListener*(mixChangedProc: SoundDevices.MixerChangedProc);
	VAR
		nlistenerlist, nl: POINTER TO Listenerlist;
	BEGIN
		IF listenerlist.proc = NIL THEN
			listenerlist.proc := mixChangedProc
		ELSE
			nlistenerlist := listenerlist;
			WHILE nlistenerlist.next # NIL DO
				nlistenerlist := nlistenerlist.next
			END;
			NEW(nl);
			nl.proc := mixChangedProc;
			nl.next := NIL;
			nlistenerlist.next := nl
		END
	END RegisterMixerChangeListener;

	PROCEDURE UnregisterMixerChangeListener*(mixChangedProc: SoundDevices.MixerChangedProc);
	VAR nlistenerlist, nl : POINTER TO Listenerlist;
	BEGIN
		nlistenerlist := listenerlist;
		IF nlistenerlist.proc = mixChangedProc THEN
			IF listenerlist.next # NIL THEN listenerlist := listenerlist.next
			ELSE
				listenerlist.proc := NIL
			END
		ELSE
			WHILE (nlistenerlist.next # NIL) & (nlistenerlist.proc # mixChangedProc) DO
				nl := nlistenerlist;
				nlistenerlist := nlistenerlist.next
			END;
			IF nlistenerlist.proc=mixChangedProc THEN
				nl.next := nlistenerlist.next
			END
		END
	END UnregisterMixerChangeListener;

	PROCEDURE GetMixerChannel*(channelNr: LONGINT; VAR channel: SoundDevices.MixerChannel);
	VAR
		itemMixerChannelList: MixerChannelList;
		i: LONGINT;
	BEGIN
		channel := NIL;
		IF (channelNr >= 0) & (channelNr < NofMixerChannels) THEN
			i := 0;
			itemMixerChannelList := firstMixerChannel;
			WHILE itemMixerChannelList # NIL DO
				IF i = channelNr THEN
					channel := itemMixerChannelList.mixerChannel
				END;
				itemMixerChannelList := itemMixerChannelList.next;
				INC(i)
			END
		END
	END GetMixerChannel;

	PROCEDURE GetNofMixerChannels*(): LONGINT;
	BEGIN
		RETURN NofMixerChannels
	END GetNofMixerChannels;

	END Driver;

	MixerChannel = OBJECT(SoundDevices.MixerChannel)
	VAR
		driver: Driver;
		name, desc: POINTER TO ARRAY OF CHAR;
		volume: LONGINT;
		mute: BOOLEAN;

	PROCEDURE &Constr*(driver: Driver; mute: BOOLEAN; name, desc: ARRAY OF CHAR);
	BEGIN
		SELF.driver := driver;
		SELF.mute := mute;
		NEW(SELF.name, Strings.Length(name) + 1);
		COPY(name, SELF.name^);
		NEW(SELF.desc, Strings.Length(desc) + 1);
		COPY(desc, SELF.desc^);
		driver.AddMixerChannel(SELF)
	END Constr;
	
	PROCEDURE CallListener;
	VAR nl: POINTER TO Listenerlist;
	BEGIN
		IF driver.listenerlist # NIL THEN
			nl := driver.listenerlist;
			WHILE nl.next # NIL DO
				IF nl.proc # NIL THEN
					nl.proc(SELF)
				END;
				nl := nl.next
			END;
			IF nl.proc # NIL THEN
				nl.proc(SELF)
			END
		END
	END CallListener;

	PROCEDURE GetName*(VAR name: ARRAY OF CHAR);
	BEGIN
		COPY(SELF.name^, name)
	END GetName;

	PROCEDURE GetDesc*(VAR desc: ARRAY OF CHAR);
	BEGIN
		COPY(SELF.desc^, desc)
	END GetDesc;

	PROCEDURE SetVolume*(volume: LONGINT);
	BEGIN
		SELF.volume := volume;
		CallListener
	END SetVolume;

	PROCEDURE GetVolume*(): LONGINT;
	BEGIN
		RETURN SELF.volume
	END GetVolume;

	(* Volume has to be 0 <= volume < 256 *)
	PROCEDURE SetMute*(mute: BOOLEAN);
	BEGIN
		SELF.mute := mute
	END SetMute;

	PROCEDURE GetIsMute*(): BOOLEAN;
	BEGIN
		RETURN SELF.mute
	END GetIsMute;

	END MixerChannel;

VAR
	firstDriver: DriverList;
	DriverTab: Plugins.Table;
	bInstalled: BOOLEAN;

(* Install the driver *)
PROCEDURE Install*(context: Commands.Context);
VAR
	driver: Driver;
	itemDriverList: DriverList;
	mixerChannel: MixerChannel;
	nDevices, iDevice, iDestination, iSource, iCtrl, nResult: LONGINT;
	hMixer: WinMM.HMIXER;
	mixerCaps: WinMM.MIXERCAPS;
	mixerLine: WinMM.MIXERLINE;
	mixerLineCtrls: WinMM.MIXERLINECONTROLS;
	mixerCtrlArray: ARRAY 8 OF WinMM.MIXERCONTROL;
	mixerCtrlDetails: WinMM.MIXERCONTROLDETAILS_MULTIPLE;
	mixerCtrlDetails_Unsigned: WinMM.MIXERCONTROLDETAILS_UNSIGNED;
	utf8Name: ARRAY WinMM.MAXPNAMELEN * 2 OF CHAR;
	utf8MixerShortName: ARRAY WinMM.MIXER_SHORT_NAME_CHARS * 2 OF CHAR;
	utf8MixerLongName: ARRAY WinMM.MIXER_LONG_NAME_CHARS * 2 OF CHAR;
	setControlType: SET;
	(*woCaps: WinMM.WAVEOUTCAPS;*)
BEGIN {EXCLUSIVE}
	(* Avoid multiple installation *)
	IF ~bInstalled THEN
		(* Scan for devices *)

		(* http://www.delphimaster.ru/articles/mixer.html *)
		
		nDevices := WinMM.mixerGetNumDevs();
		
		context.out.Ln; context.out.String("mixerGetNumDevs: "); context.out.Int(nDevices, 1); context.out.Ln;
		
		FOR iDevice := 0 TO nDevices - 1 DO
			IF WinMMUtils.mixerGetDevCaps(iDevice, mixerCaps, context) THEN
				WinMMUtils.WCharToUTF8(mixerCaps.szPname, utf8Name);
				
				IF ~bInstalled THEN
					bInstalled := TRUE
				END;
					
				(* Create Driver Object *)
				NEW(driver, utf8Name);
				COPY(utf8Name, driver.desc);

				NEW(itemDriverList);
				itemDriverList.driver := driver;
				itemDriverList.next := firstDriver;
				firstDriver := itemDriverList;
			
				context.out.String("Product name: "); context.out.String(utf8Name); context.out.Ln;
				
				IF WinMMUtils.mixerOpen(hMixer, iDevice, 0, 0, WinMM.MIXER_OBJECTF_MIXER, context) THEN
					FOR iDestination := 0 TO mixerCaps.cDestinations - 1 DO
						mixerLine.dwDestination := iDestination;
						IF WinMMUtils.mixerGetLineInfo(hMixer, mixerLine, WinMM.MIXER_GETLINEINFOF_DESTINATION + WinMM.MIXER_OBJECTF_HMIXER, context) THEN
							WinMMUtils.WCharToUTF8(mixerLine.szName, utf8MixerLongName);
							WinMMUtils.WCharToUTF8(mixerLine.szShortName, utf8MixerShortName);
							
							context.out.String("  - Dst name: "); context.out.String(utf8MixerLongName); context.out.Ln;
							
							NEW(mixerChannel, driver, FALSE, utf8MixerShortName, utf8MixerLongName);
							
							FOR iSource := 0 TO mixerLine.cConnections - 1 DO
								mixerLine.dwSource := iSource;
								IF WinMMUtils.mixerGetLineInfo(hMixer, mixerLine, WinMM.MIXER_GETLINEINFOF_SOURCE + WinMM.MIXER_OBJECTF_HMIXER, context) THEN
									WinMMUtils.WCharToUTF8(mixerLine.szName, utf8MixerLongName);
									WinMMUtils.WCharToUTF8(mixerLine.szShortName, utf8MixerShortName);
									
									IF WinMMUtils.mixerGetLineInfo(hMixer, mixerLine, WinMM.MIXER_GETLINEINFOF_LINEID, context) THEN
										IF mixerLine.cControls # 0 THEN
										
											context.out.String("    - Src name: "); context.out.String(utf8MixerLongName); context.out.Ln;
										
											NEW(mixerChannel, driver, FALSE, utf8MixerShortName, utf8MixerLongName);
										
											mixerLineCtrls.dwLineID := mixerLine.dwLineID;
											mixerLineCtrls.cControls := MIN(mixerLine.cControls, LEN(mixerCtrlArray));
											mixerLineCtrls.pamxctrl := SYSTEM.ADR(mixerCtrlArray);
											IF WinMMUtils.mixerGetLineControls(hMixer, mixerLineCtrls, WinMM.MIXER_GETLINECONTROLSF_ALL, context) THEN
												FOR iCtrl := 0 TO mixerLineCtrls.cControls - 1 DO
													WinMMUtils.WCharToUTF8(mixerCtrlArray[iCtrl].szName, utf8MixerLongName);
													
													context.out.String("      - Ctrl name: "); context.out.String(utf8MixerLongName); context.out.Ln;
													
													IF mixerCtrlArray[iCtrl].cMultipleItems = 0 THEN
													
														mixerCtrlDetails.dwControlID := mixerCtrlArray[iCtrl].dwControlID;
														mixerCtrlDetails.cMultipleItems := 0;
														mixerCtrlDetails.cChannels := 1;
														mixerCtrlDetails.cbDetails := SYSTEM.SIZEOF(WinMM.MIXERCONTROLDETAILS_UNSIGNED);
														mixerCtrlDetails.paDetails := SYSTEM.ADR(mixerCtrlDetails_Unsigned);
														
														IF WinMMUtils.mixerGetControlDetails(hMixer, mixerCtrlDetails, {}, context) THEN
														
															setControlType := SYSTEM.VAL(SET, mixerCtrlArray[iCtrl].dwControlType) * WinMM.MIXERCONTROL_CT_CLASS_MASK;
															IF (setControlType = WinMM.MIXERCONTROL_CT_CLASS_FADER) OR (setControlType = WinMM.MIXERCONTROL_CT_CLASS_SLIDER) THEN
																mixerChannel.SetVolume(mixerCtrlDetails_Unsigned.dwValue DIV 256(*655*));
																context.out.String("dwValue: "); context.out.Int(mixerCtrlDetails_Unsigned.dwValue, 1);
																context.out.String(" Volume: "); context.out.Int(mixerChannel.GetVolume(), 1);
																context.out.Ln;
															ELSIF setControlType = WinMM.MIXERCONTROL_CT_CLASS_SWITCH THEN
																mixerChannel.SetMute(mixerCtrlDetails_Unsigned.dwValue = 1)
															END
														
														END;
														
														(*context.out.String("cMultipleItems: "); context.out.Int(mixerCtrlArray[iCtrl].cMultipleItems, 1); context.out.Ln;*)
														context.out.String("Bounds: "); context.out.Int(mixerCtrlArray[iCtrl].bounds.dwMinimum, 10); context.out.Int(mixerCtrlArray[iCtrl].bounds.dwMaximum, 10); context.out.Ln;
													END
													
												END
											END
										END
									END
								END
							END
						END
					END;
					nResult := WinMM.mixerClose(hMixer)
				END
			END
		END;
		context.out.Ln;
		
		(*n := WinMM.waveOutGetNumDevs();
		context.out.String("waveOutGetNumDevs: ");
		context.out.Int(n, 1);
		context.out.Ln;
		FOR i := 0 TO n - 1 DO
			WinMM.Fill(SYSTEM.ADR(wocaps), SYSTEM.SIZEOF(WinMM.WAVEOUTCAPSW), 0X);
			result := WinMM.waveOutGetDevCapsW(i, SYSTEM.ADR(wocaps), SYSTEM.SIZEOF(WinMM.WAVEOUTCAPSW));
			IF result = WinMM.MMSYSERR_NOERROR THEN
				WinMM.WCharToUTF8(wocaps.szPname, utf8);
				context.out.String("Wave out name: ");
				context.out.String(utf8);
				context.out.Ln;
				context.out.String("dwFormats: ");
				context.out.Hex(WinMM.GetDWord(wocaps.dwFormats), 10);
				context.out.Ln;
				context.out.String("wChannels: ");
				context.out.Int(WinMM.GetWord(wocaps.wChannels), 1);
				context.out.Ln
			ELSE
				context.out.String("waveOutGetDevCapsW error: ");
				context.out.Int(result, 1);
				context.out.Ln;
			END
		END;*)
		
	END;
END Install;

PROCEDURE Test*(context: Commands.Context);
VAR
	driver: SoundDevices.Driver;
	channel: SoundDevices.MixerChannel;
	name: ARRAY 128 OF CHAR;
BEGIN
	driver := SoundDevices.GetDefaultDevice();
	IF driver # NIL THEN
		context.out.Ln;
		context.out.String(driver.name);
		context.out.Ln;
		context.out.Int(driver.GetNofMixerChannels(), 1);
		context.out.Ln;
		driver.GetMixerChannel(0, channel);
		IF channel # NIL THEN
			context.out.Ln;
			channel.GetName(name);
			context.out.String(name);
			context.out.Ln;
		END;
	END
END Test;

(** Enable is a hardware enable. *)
PROCEDURE Enable*;
VAR
	item : DriverList;
BEGIN
	item := firstDriver;
	WHILE item # NIL DO
		item.driver.Enable;
		item := item.next
	END;
END Enable;

(** Enable is a hardware pause. *)
PROCEDURE Disable*;
VAR
	item : DriverList;
BEGIN
	item := firstDriver;
	WHILE item # NIL DO
		item.driver.Disable;
		item := item.next
	END;
END Disable;

(** Cleanup function called when the module is unloaded *)
PROCEDURE Cleanup;
VAR
	item: DriverList;
BEGIN
	item := firstDriver;
	WHILE item # NIL DO
		item.driver.Finalize;
		item := item.next
	END
END Cleanup;

BEGIN
	firstDriver := NIL;
	bInstalled := FALSE;
	Modules.InstallTermHandler(Cleanup)
END WinMMSound.

WinMMSound.Install ~
WinMMSound.Test ~
WMMixer.Open ~

SystemTools.Free WMMixer WinMMSound WinMMUtils WinMM ~
