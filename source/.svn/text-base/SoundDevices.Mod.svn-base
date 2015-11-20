MODULE SoundDevices;	(** AUTHOR "TF"; PURPOSE "Abstract sound device driver / Generic sound support"; *)

IMPORT
		Plugins, Modules;

VAR
	devices* : Plugins.Registry;

CONST
	ResOK* = 0;
	ResQualityReduced* = 1; (** ResReducedQuality can be the res value of OpenPlayChannel if the playing quality
													of the resulting channel may be reduced due to insufficient ressources *)
	ResNoMoreChannels* = 10;
	ResUnsupportedFrequency* = 20;
	ResUnsupportedSubChannels* = 30;
	ResUnsupportedSamplingRes* = 40;
	ResUnsupportedFormat* = 50;

	(* Channel types *)
	ChannelPlay* = 0;
	ChannelRecord* = 1;

	(** Currently only PCM defined *)
	FormatPCM* = 0;

TYPE
	(** a generic buffer. data^ contains the data to be played or space for the data recorded.
		len contains the length of the buffer.
		len MOD 4 must be 0
		Buffers may be extended by the client application for buffer management. A buffer may only be reused if
		it is returned to the BufferListener.
	*)
	Buffer* = OBJECT
	VAR
		len* : LONGINT;
		data* : POINTER TO ARRAY OF CHAR;
	END Buffer;

	(* a blocking buffer pool that can be used by a sound playing process to synchronize sound generation *)
	BufferPool* = OBJECT
		VAR head, num: LONGINT; buffer: POINTER TO ARRAY OF Buffer;

		PROCEDURE &Init*(n: LONGINT);
		BEGIN
			head := 0; num := 0; NEW(buffer, n)
		END Init;

		PROCEDURE Add*(x: Buffer);
		BEGIN {EXCLUSIVE}
			AWAIT(num # LEN(buffer));
			buffer[(head+num) MOD LEN(buffer)] := x;
			INC(num)
		END Add;

		PROCEDURE Remove*(): Buffer;
		VAR x: Buffer;
		BEGIN {EXCLUSIVE}
			AWAIT(num # 0);
			x := buffer[head];
			head := (head+1) MOD LEN(buffer);
			DEC(num);
			RETURN x
		END Remove;

		PROCEDURE NofBuffers*(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN num
		END NofBuffers;

	END BufferPool;

	(** A buffer listener is called when a play / or record buffer is completed,
			the application should reuse eg. process the buffer *)
	BufferListener* = PROCEDURE { DELEGATE } (buffer : Buffer);

	(** Generic MixerChannel object. Allows to set and get volume information *)
	MixerChannel* = OBJECT
		(** Return the name (as UTF-8 Unicode) of this channel *)
		PROCEDURE GetName*(VAR name : ARRAY OF CHAR);
		BEGIN HALT(99) (* abstract *)
		END GetName;

		(** Return the description string (as UTF-8 Unicode) of this channel *)
		PROCEDURE GetDesc*(VAR desc : ARRAY OF CHAR);
		BEGIN HALT(99) (* abstract *)
		END GetDesc;

		(** Set the volume of the channel *)
		(** 0 is silent, 255 is max *)
		PROCEDURE SetVolume*(volume : LONGINT);
		BEGIN HALT(99) (* abstract *)
		END SetVolume;

		(** Get the volume of the channel *)
		(** 0 is silent, 255 is max *)
		PROCEDURE GetVolume*() : LONGINT;
		BEGIN HALT(99) (* abstract *)
		END GetVolume;

		(** mute or unmute the channel *)
		PROCEDURE SetMute*(mute : BOOLEAN);
		BEGIN HALT(99) (* abstract *)
		END SetMute;

		(** get the "mute - state" of the channel *)
		PROCEDURE GetIsMute*() : BOOLEAN;
		BEGIN HALT(99) (* abstract *)
		END GetIsMute;
	END MixerChannel;

	(** a MixerChangedProc delegate is called whenever a channel (volume / mute) is changed *)
	MixerChangedProc* = PROCEDURE { DELEGATE } (channel : MixerChannel);

	(** Generic channel *)
	Channel* = OBJECT
		(** Return if the channel is ChannelPlay or ChannelRecord *)
		PROCEDURE GetChannelKind*() : LONGINT;
		END GetChannelKind;

		(** Set the current volume of the channel *)
		(** Volume is a 8.8 bit fix-point value, 0 is silent *)
		PROCEDURE SetVolume*(volume : LONGINT);
		BEGIN HALT(99) (* abstract *)
		END SetVolume;

		(** Get the current volume of the channel *)
		PROCEDURE GetVolume*() : LONGINT;
		BEGIN HALT(99) (* abstract *)
		END GetVolume;

		(** GetPosition return the current position in samples. MAY CHANGE TO HUGEINT*)
		PROCEDURE GetPosition*() : LONGINT;
		BEGIN HALT(99) (* abstract *)
		END GetPosition;

		(** Register a delegate that handles reuse / processing of buffers. Only one Buffer listener can be registered
		per channel *)
		PROCEDURE RegisterBufferListener*(bufferListener : BufferListener);
		BEGIN HALT(99) (* abstract *)
		END RegisterBufferListener;

		(** Start playing / recording *)
		PROCEDURE Start*;
		BEGIN HALT(99) (* abstract *)
		END Start;

		(** Queue another buffer for playing / recording *)
		PROCEDURE QueueBuffer*(x : Buffer);
		BEGIN HALT(99) (* abstract *)
		END QueueBuffer;

		(** Pause playing / recording, no buffers are returned *)
		PROCEDURE Pause*;
		BEGIN HALT(99) (* abstract *)
		END Pause;

		(** Stop the playing / recording and return all buffers *)
		PROCEDURE Stop*;
		BEGIN HALT(99) (* abstract *)
		END Stop;

		(** The channel is closed, the driver may release any ressources reserved for it. The object is still there
			but can never be opened again*)
		PROCEDURE Close*;
		BEGIN HALT(99) (* abstract *)
		END Close;
	END Channel;

	Driver* = OBJECT (Plugins.Plugin)
	VAR
		masterIn*, masterOut* : MixerChannel;

(** Generic functions *)
		PROCEDURE Init*;
		BEGIN
			NEW(masterIn); NEW(masterOut)
		END Init;

		PROCEDURE Enable*;
		END Enable;

		PROCEDURE Disable*;
		END Disable;

(** Capabilities *)
		PROCEDURE NofNativeFrequencies*():LONGINT;
		BEGIN HALT(99) (* abstract *)
		END NofNativeFrequencies;

		PROCEDURE GetNativeFrequency*(nr : LONGINT):LONGINT;
		BEGIN HALT(99) (* abstract *)
		END GetNativeFrequency;

		PROCEDURE NofSamplingResolutions*():LONGINT;
		BEGIN HALT(99) (* abstract *)
		END NofSamplingResolutions;

		PROCEDURE GetSamplingResolution*(nr : LONGINT):LONGINT;
		BEGIN HALT(99) (* abstract *)
		END GetSamplingResolution;

		(** How many different sub channel settings are possible. Default implementation returns 2 for mono and stereo *)
		PROCEDURE NofSubChannelSettings*():LONGINT;
		BEGIN
			RETURN 2
		END NofSubChannelSettings;

		(** Get sub channel setting nr. Default implementation returns mono and stereo *)
		PROCEDURE GetSubChannelSetting*(nr : LONGINT):LONGINT;
		BEGIN
			IF nr = 0 THEN RETURN 1
			ELSIF nr = 1 THEN RETURN 2
			ELSE RETURN 1
			END
		END GetSubChannelSetting;

		(** How many different wave formats are possible. Default implementation returns 1 *)
		PROCEDURE NofWaveFormats*():LONGINT;
		BEGIN
			RETURN 1
		END NofWaveFormats;

		(** Get wave format nr. Default implementation returns FormatPCM *)
		PROCEDURE GetWaveFormat*(nr : LONGINT):LONGINT;
		BEGIN
			RETURN FormatPCM
		END GetWaveFormat;

(** Playing *)
		(** Open a new channel for playing. If more than one channel is opened, the sound driver needs to mix the
			channels in software or hardware, using the respective volumes. Sampling rate conversion must be done if needed.
			The driver may respond with res = ResNoMoreChannels, if it can not open more channels. (The driver
			SHOULD support more play channels (eg. 8 / 16 or more channels))
			The driver can also respond with res = ResReducedQuality if the playback quality is reduced due to insufficient
			ressources.
			channel is the resulting Play channel, NIL if an error that prevents playing has occured.
			(Applications only interested in the ability of playing and not in playback quality should only check for
			  channel # NIL and not for res = ResOk)
			samplingRate is the desired samplingRate
			samplingResolution = 8 / 16 / 24 / 32 (All drivers should support at least 8 and 16 bit)
			nofSubChannes = 1 for Mono, 2 for Stereo, 4 for Quadro etc.
			format is the wave format
		*)
		PROCEDURE OpenPlayChannel*(VAR channel : Channel; samplingRate, samplingResolution, nofSubChannels, format : LONGINT; VAR res : LONGINT);
		END OpenPlayChannel;

(** Recording *)
		(** Open a new channel for recording.
			If more than one channel is opened, the sound driver copies the recorded data to all the recording
			channels, using the respective volumes. Sampling rate conversion must be done if needed. Support for
			multichannel recording is possible but NOT required. The driver may respond with res := ResNoMoreChannels, if
			more than one recording channel is opened.
			channel is the resulting Recorder channel, NIL if an error occured.
			samplingRate is the desired samplingRate
			samplingResolution = 8 / 16 / 24 / 32 (All drivers should support at least 8 and 16 bit)
			nofSubChannes = 1 for Mono, 2 for Stereo, 4 for Quadro etc.
			format is the wave format
		*)
		PROCEDURE OpenRecordChannel*(VAR channel : Channel; samplingRate, samplingResolution, nofSubChannels, format : LONGINT; VAR res : LONGINT);
		END OpenRecordChannel;

(** Mixer *)
		(** Register a listener for channel changes,
			The number of listeners is not limited
		  *)
		PROCEDURE RegisterMixerChangeListener*(mixChangedProc : MixerChangedProc);
		END RegisterMixerChangeListener;

		(** Unregister a previously registered channel change listener  *)
		PROCEDURE UnregisterMixerChangeListener*(mixChangedProc : MixerChangedProc);
		END UnregisterMixerChangeListener;

		(** Return channel object
			channel 0 is always present and is specified as the master output volume
			channel 1 is always present and is specified as the master input volume
				Drivers may ignore channel 0 or 1 but need to return a generic "Channel" object for these channel numbers
			GetMixerChannel returns NIL if the channelNr is invalid
		*)
		PROCEDURE GetMixerChannel*(channelNr : LONGINT; VAR channel : MixerChannel);
		BEGIN
			IF channelNr = 0 THEN channel := masterOut
			ELSIF channelNr = 1 THEN channel := masterIn
			ELSE channel := NIL
			END
		END GetMixerChannel;

		(** Returns the number of mixer channels available, at least 2 *)
		PROCEDURE GetNofMixerChannels*() : LONGINT;
		BEGIN
			RETURN 2
		END GetNofMixerChannels;
	END Driver;

(** Returns the default sound device. (Blocks until at least one sound device is installed *)
PROCEDURE GetDefaultDevice*() : Driver;
VAR p : Plugins.Plugin;
BEGIN
	p := devices.Await("");
	ASSERT(p IS Driver);
	RETURN p(Driver)
END GetDefaultDevice;

PROCEDURE Cleanup;
BEGIN
	Plugins.main.Remove(devices)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	NEW(devices, "SoundDevices", "Sound drivers")
END SoundDevices.
