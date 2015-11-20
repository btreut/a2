(* AUTHOR: Kristofer Jonsson, kjonsson@student.ethz.ch, krijo210@student.liu.se *)
(* Written Sommer Semester 2003 *)

MODULE i810Sound; (** AUTHOR "krijo210@student.liu.se"; PURPOSE "Intel 810 Sound driver for SoundDevices"; *)

	IMPORT SYSTEM, PCI, Machine, Kernel, Objects, Modules, Plugins,
		SoundDevices, KernelLog;

	CONST
		(* PCI Audio Control register offsets *)
		PACRegAC97CmdData = 0060H;
		PACRegAC97CmdAddress = 0062H;
		PACRegAC97StatusData = 0064H;
		PACRegAC97StatusAddress = 0066H;

		(* Sound Preferences *)
		MasterVolume = 225; (* 0 silent, 255 full volume *)
		InitVolume = 128; (* 0 silent, 255 full volume *)
		(* Could be any value MOD 4 = 0. Small buffer size means much work for
			the driver but fast respons times. Big buffers vice versa. *)
		BufferSize = 08FF0H;
		NofMixerChannels = 6;
		Boost = TRUE;
		InsecureMode = TRUE; (* also search for untested but probably compatible devices *)

		(* States for channel *)
		StatePlaying = 1;
		StateRecording = 2;
		StatePaused = 3;
		StateStoped = 4;
		StateClosed = 5;

		(* Bus Master Registers *)
		BMRInBase = 00H;
		BMROutBase = 10H;

		BMRBufferDescriptorBaseAddress = 00H;
		BMRCurrentIndexReg = 04H;
		BMRLastValidIndexReg = 05H;
		BMRStatusReg = 06H;
		BMRCtrlReg = 0BH;
		BMRGlobalStatusReg = 30H;

		(* AC97 Registers *)
		AC97MasterVolReg = 02H;
		AC97AuxVolReg = 04H;
		AC97MonoVolReg = 06H;
		AC97MicVolReg = 0EH;
		AC97LineInVolReg = 10H;
		AC97CDVolReg = 12H;
		AC97PCMOutVolReg = 18H;
		AC97RecordGainReg = 1CH;

		AC97ResetReg = 0;
		AC97RecordSelectReg = 1AH;
		AC97DacRateReg = 2CH;
		AC97AdcRateReg = 32H;
		AC97StatCtrlReg = 2AH;

		DebugBaseAddress = 0;
		DebugDMAAddess = 1;
		TraceOpenChannel = 2;
		DebugTraceListeners = 3;
		DebugInit = 4;
		Debug = {DebugBaseAddress, DebugDMAAddess, TraceOpenChannel, DebugTraceListeners, DebugInit };

	TYPE
		PlayChannelList = POINTER TO RECORD
			channel : PlayChannel;
			next : PlayChannelList;
		END;

		RecChannelList = POINTER TO RECORD
			channel : RecChannel;
			next : RecChannelList;
		END;

		MixerChangedProcList = POINTER TO RECORD
			mixerChangedProc : SoundDevices.MixerChangedProc;
			next : MixerChangedProcList;
		END;

		BufferList = POINTER TO RECORD
			buffer : SoundDevices.Buffer;
			next : BufferList;
		END;

		Sample = ARRAY 4 OF CHAR; (* 16 bit stereo sample *)

		DriverList = POINTER TO RECORD
			driver : Driver;
			next : DriverList;
		END;

		(**
			PCM data is transmitted through a DMA channel. Pointers to buffers are held in the
			memory in form of a structure named Buffer Drescriptor List.
			See Intel 82801xx Programmers manual for further details.
		*)
		DMABufferDescriptorList = POINTER TO ARRAY 32 OF RECORD
			addr : LONGINT;
			CmdAndLength : LONGINT;
		END;

		(**
			PCIAudioControl read/write from the PCI I/O space.
			I/O space is not memory mapped so we have to use PORTIN/PORTOUT.
		*)
		PCIAudioControl = OBJECT
			VAR
				base: LONGINT;

			PROCEDURE &Constr*(base : LONGINT);
			BEGIN
				SELF.base := base
			END Constr;

			(* Read from I/O register *)
			PROCEDURE RegRead8(offset : LONGINT) : SHORTINT;
			VAR
				res : CHAR;
			BEGIN
				Machine.Portin8(base + offset, res);
				RETURN SYSTEM.VAL(SHORTINT, res)
			END RegRead8;

			PROCEDURE RegRead16(offset : LONGINT) : INTEGER;
			VAR
				res : INTEGER;
			BEGIN
				Machine.Portin16(base + offset, res);
				RETURN SYSTEM.VAL(INTEGER, res)
			END RegRead16;

			PROCEDURE RegRead32(offset : LONGINT) : LONGINT;
			VAR
				res : LONGINT;
			BEGIN
				Machine.Portin32(base + offset, res);
				RETURN res
			END RegRead32;

			(* Write to I/O register *)
			PROCEDURE RegWrite8(offset : LONGINT; val : LONGINT);
			BEGIN
				Machine.Portout8(base + offset, SYSTEM.VAL(CHAR, val))
			END RegWrite8;

			PROCEDURE RegWrite16(offset : LONGINT; val : LONGINT);
			BEGIN
				Machine.Portout16(base + offset, SYSTEM.VAL(INTEGER, val))
			END RegWrite16;

			PROCEDURE RegWrite32(offset : LONGINT; val : LONGINT);
			BEGIN
				Machine.Portout32(base + offset, val)
			END RegWrite32;

		END PCIAudioControl;


		(**
			The AC97 Codec is a serial chip and we have to respect this fact. We may not flood it
			with data, but have to first check the semaphore register at NABMBAR + 34H if the
			chip is read to receive/transmit data. Else we get/put data to/from the I/O space
			as usual.
			All registers are 16 bit.
		*)
		AC97Control = OBJECT
			VAR
				NAMBAR, NABMBAR: PCIAudioControl;

			PROCEDURE &Constr*(NAMBAR, NABMBAR : PCIAudioControl);
			BEGIN
				SELF.NAMBAR := NAMBAR;
				SELF.NABMBAR := NABMBAR
			END Constr;

			PROCEDURE RegRead16(offset : LONGINT): LONGINT;
			BEGIN{EXCLUSIVE}
				ASSERT(BusyWait());
				RETURN NAMBAR.RegRead16(offset)
			END RegRead16;

			PROCEDURE RegWrite16(offset, value : LONGINT);
			BEGIN{EXCLUSIVE}
				ASSERT(BusyWait());
				NAMBAR.RegWrite16(offset, value)
			END RegWrite16;

			(* Read semaphore register. If 0 is returned access to the AC97 I/O space
				is granted. If 1 is returned AC97 Codec is blocked. Then retry until timer
				of 2 ms times out. *)
			PROCEDURE BusyWait() : BOOLEAN;
			VAR t: Kernel.MilliTimer;
			BEGIN
				Kernel.SetTimer(t, 2);
				WHILE ~Kernel.Expired(t) DO
					IF ~(0 IN SYSTEM.VAL(SET, NABMBAR.RegRead8(34H))) THEN
						RETURN TRUE
					END
				END;

				RETURN FALSE
			END BusyWait;

			(* Writing any value to this register restes the AC97 Codec *)
			PROCEDURE Reset*;
			BEGIN
				RegWrite16(AC97ResetReg, 1);
			END Reset;

			PROCEDURE WriteCodec*;
			BEGIN
				(* Set volumes *)
				RegWrite16(AC97ResetReg, 0001H); (* Reset *)
				RegWrite16(AC97MasterVolReg, MasterVolume); (* Master volume *)
				RegWrite16(AC97AuxVolReg, 8000H); (* AUX volume *)
				RegWrite16(AC97MonoVolReg, 8000H); (* Mono volume *)
				RegWrite16(AC97PCMOutVolReg, 1818H); (* PCM Out Volume *)

				(* Enable variable DAC rate *)
				RegWrite16(AC97StatCtrlReg, 0001H)
			END WriteCodec;

			PROCEDURE SetDacRate*(rate : LONGINT);
			BEGIN
				RegWrite16(AC97DacRateReg, rate)
			END SetDacRate;

			PROCEDURE SetAdcRate*(rate : LONGINT);
			BEGIN
				RegWrite16(AC97AdcRateReg, rate)
			END SetAdcRate;
		END AC97Control;

TYPE
		(**
		 	Driver object is the core of the driver. It is responsible for creating
		 	new objects, setting registers, returning channels, handling interrupts.
		 *)
		Driver = OBJECT(SoundDevices.Driver)
			VAR
				base : LONGINT;
				irq : LONGINT;
				AC97 : AC97Control;
				NAMBAR, NABMBAR : PCIAudioControl;
				DMAIn, DMAOut : DMABufferDescriptorList;
				firstPlayChannel : PlayChannelList;
				firstRecChannel : RecChannelList;
				mixerChannelList : ARRAY NofMixerChannels OF MixerChannel;
				firstMixerChangedProc : MixerChangedProcList;
				playCurrentBufferIndex, recCurrentBufferIndex : LONGINT;
				playLastValidIndex, recLastValidIndex : LONGINT;
				playBuffer, recBuffer, silentBuffer : SoundDevices.Buffer;
				playSamplingRate : ARRAY 32 OF LONGINT;
				recSamplingRate : LONGINT;
				playCurrentSamplingRate : LONGINT;
				playBufferList, recBufferList : ARRAY 32 OF SoundDevices.Buffer;
				playInterrupt, recInterrupt : BOOLEAN;

			PROCEDURE &Constr*(nambar, nabmbar, irq : LONGINT);
			VAR
				res : LONGINT;
				DMAInPhysAdr, DMAOutPhysAdr: LONGINT;
				i : LONGINT;
			BEGIN
				SELF.base := base;
				SELF.irq := irq;

				(* Create PCI Audio Control Object *)
				NEW(NAMBAR, nambar);

				(* Create PCI Audio Control Object *)
				NEW(NABMBAR, nabmbar);

				(* Create AC97 Control Object *)
				NEW(AC97, NAMBAR, NABMBAR);

				(* Reset registers *)
				NABMBAR.RegWrite8(BMRInBase + BMRCtrlReg, 02H);
				NABMBAR.RegWrite8(BMROutBase + BMRCtrlReg, 02H);

				(* Write AC97 Codec *)
				AC97.Reset;
				AC97.WriteCodec;

				NEW(DMAIn);
				NEW(DMAOut);

				(* Size is 32 entries * 2 fields * 8 byte = 256 byte *)
				DMAInPhysAdr := GetPhysicalAdr(ADDRESSOF(DMAIn[0]), 256);
				DMAOutPhysAdr := GetPhysicalAdr(ADDRESSOF(DMAOut[0]), 256);

				(* Read Buffer Descriptor List Base Addresses *)
				NABMBAR.RegWrite32(BMRInBase + BMRBufferDescriptorBaseAddress, DMAInPhysAdr);
				NABMBAR.RegWrite32(BMROutBase + BMRBufferDescriptorBaseAddress, DMAOutPhysAdr);

				IF DebugDMAAddess IN Debug THEN
					KernelLog.String("DMA In Physical Address: "); KernelLog.Int(DMAInPhysAdr, 5); KernelLog.Ln;
					KernelLog.String("DMA Out Physical Address: "); KernelLog.Int(DMAOutPhysAdr, 5); KernelLog.Ln
				END;

				(* Create buffers for playing and recording *)
				FOR i := 0 TO 31 DO
					NEW(playBufferList[i]); NEW(recBufferList[i]);
					NEW(playBufferList[i].data, BufferSize); NEW(recBufferList[i].data, BufferSize);
					playBufferList[i].len := BufferSize; recBufferList[i].len := BufferSize;

					DMAOut[i].addr := GetPhysicalAdr(
						ADDRESSOF(playBufferList[i].data[0]), BufferSize);
					DMAIn[i].addr := GetPhysicalAdr(
						ADDRESSOF(recBufferList[i].data[0]), BufferSize);

					DMAOut[i].CmdAndLength := LSH(BufferSize, -1);
					SetBit(DMAOut[i].CmdAndLength, 31);
					DMAIn[i].CmdAndLength := LSH(BufferSize, -1);
					SetBit(DMAIn[i].CmdAndLength, 31)
				END;

				(* Create silent buffer *)
				NEW(silentBuffer);
				NEW(silentBuffer.data, BufferSize);
				FOR i := 0 TO BufferSize - 1 DO silentBuffer.data[i] := silentData END;
				silentBuffer.len := BufferSize;

				(* Set initial samplings rate *)
				FOR i := 0 TO 31 DO playSamplingRate[i] := 48000 END;
				playCurrentSamplingRate := 48000;

				(* Choose mic as record channel *)
				AC97.RegWrite16(AC97RecordSelectReg, 0000H);

				(* Create mixer channels *)
				NEW(mixerChannelList[0], SELF, AC97MasterVolReg, FALSE, "MasterOut", "Master output mixer channel");
				NEW(mixerChannelList[1], SELF, AC97RecordGainReg, FALSE, "MasterIn", "Master input mixer channel");
				NEW(mixerChannelList[2], SELF, AC97LineInVolReg, TRUE, "LineIn", "LineIn mixer channel");
				NEW(mixerChannelList[3], SELF, AC97PCMOutVolReg, FALSE, "PCMOut", "PCM out mixer channel");
				NEW(mixerChannelList[4], SELF, AC97CDVolReg, TRUE, "CD", "CD input mixer channel");
				NEW(mixerChannelList[5], SELF, AC97MicVolReg, FALSE, "Mic", "Microphone mixer channel");
				mixerChannelList[5].SetVolume(0); (* cancel noise that might come from the mic *)

				(* Give master volume some more gas *)
				mixerChannelList[0].SetVolume(MasterVolume);

				(* Install Objects interrupt handler *)
				Objects.InstallHandler(HandleInterrupt, Machine.IRQ0+irq);

				(* Register Driver in SoundDevices *)
				SoundDevices.devices.Add(SELF, res);
				ASSERT(res = Plugins.Ok);

				(* Update driver table *)
				SoundDevices.devices.GetAll(DriverTab);

				(* Enable DMA
					Set the PCM Control Register
					Read more about it in the Intel documentation
					0001 1101 = 1Dh
					0000 0001 = 01h

					The Current Buffer Position seems to turn around when it reaches zero. This will result in a
					negative number counting backwards. It is not that interesting hearing the kernel code played
					at your loudspeakers, but who knows, maybe you hear satanic words if you play it backwards
					through the soundcard. I have to try it with the Windows...

					It is said that if you play the Windows install CD backwards you hear satanic words. What is
					that to care about. I mean, if you play it forwards it installs Windows!

					11H will enable DMA and raise an interrupt when a buffer is completed.
				*)
				Enable
			END Constr;

			PROCEDURE Finalize;
			BEGIN
				Disable;

				(* Reset AC97 Codec *)
				AC97.Reset;

				(* Remove interrupt handler *)
				Objects.RemoveHandler(HandleInterrupt, Machine.IRQ0+irq);

				(* Remove registered driver *)
				SoundDevices.devices.Remove(SELF);

				(* Update driver table *)
				SoundDevices.devices.GetAll(DriverTab)
			END Finalize;

			PROCEDURE HandleInterrupt;
			VAR
				status : LONGINT;
				interrupt : LONGINT;
			BEGIN
				interrupt := NABMBAR.RegRead32(BMRGlobalStatusReg);

				(* Did a PCM Out interrupt occur? *)
				IF (6 IN SYSTEM.VAL(SET, interrupt)) THEN
					(*
						Do a 32 bit read over Current Index, Last Valid Index and Status Register
						starting at Current Buffer Index.
					*)
					status := NABMBAR.RegRead32(BMROutBase + BMRCurrentIndexReg);

					(* Did a Buffer completion interrupt occur? *)
					IF (19 IN SYSTEM.VAL(SET, status)) THEN
						BEGIN {EXCLUSIVE}
							playLastValidIndex := (SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, status)*{0..7}) + 2) MOD 32;
							playInterrupt := TRUE;
						END;
					END;

					(* Clear the interrupt *)
					NABMBAR.RegWrite16(BMROutBase + BMRStatusReg, 0FFH);
				END;

				(* Did a PCM In interrupt occur? *)
				IF (5 IN SYSTEM.VAL(SET, interrupt)) THEN
					(*
						Do a 32 bit read over Current Index, Last Valid Index and Status Register
						starting at Current Buffer Index.
					*)
					status := NABMBAR.RegRead32(BMRInBase + BMRCurrentIndexReg);

					(* Did a Buffer completion interrupt occur? *)
					IF (19 IN SYSTEM.VAL(SET, status)) THEN
						BEGIN {EXCLUSIVE}
							recLastValidIndex := (SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, status)*{0..7}) + 2) MOD 32;
							recInterrupt := TRUE;
						END;
					END;

					(* Clear the interrupt *)
					NABMBAR.RegWrite16(BMRInBase + BMRStatusReg, 0FFH)
				END;
			END HandleInterrupt;

			(* Enqueues a new buffer for DMA to fetch, and updates last valid buffer index. *)
			PROCEDURE QueueBuffer*;
			VAR
				noOfSamples : LONGINT;
			BEGIN
				MixBuffers;

				DMAOut[playLastValidIndex].addr := GetPhysicalAdr(
					ADDRESSOF(playBufferList[playCurrentBufferIndex].data[0]), BufferSize);

				noOfSamples := LSH(playBufferList[playCurrentBufferIndex].len, -1);
				DMAOut[playLastValidIndex].CmdAndLength := noOfSamples;
				SetBit(DMAOut[playLastValidIndex].CmdAndLength, 31);

				NABMBAR.RegWrite8(BMROutBase + BMRLastValidIndexReg, playLastValidIndex)

			END QueueBuffer;

			(* Mix all active channels into one single buffer. *)
			PROCEDURE MixBuffers;
			VAR
				item : PlayChannelList;
				buffer : SoundDevices.Buffer;
				silent : BOOLEAN;
			BEGIN
				playCurrentBufferIndex := playLastValidIndex;

				playBuffer := NIL;
				playSamplingRate[playCurrentBufferIndex] := 1;
				silent := TRUE;

				(* Set max sampling rate *)
				item := firstPlayChannel;
				WHILE item # NIL DO
					IF item.channel.state = StatePlaying THEN
						playSamplingRate[playCurrentBufferIndex] :=
							Max(playSamplingRate[playCurrentBufferIndex], item.channel.samplingRate);
						silent := FALSE
					END;
					item := item.next
				END;

				(* Mix buffers *)
				item := firstPlayChannel;
				WHILE item # NIL DO
					IF item.channel.state = StatePlaying THEN
						item.channel.PrepareData(playSamplingRate[playCurrentBufferIndex]);
						buffer := item.channel.ReturnBuffer();
						MixTwo(playBuffer, buffer);
					END;
					item := item.next
				END;

				(* If no active channel is found then outpus silent data *)
				IF silent THEN
					playSamplingRate[playCurrentBufferIndex] := 48000;
					playBuffer := silentBuffer
				END;

				(* We are always two steps ahead of DMA *)
				IF playSamplingRate[(playCurrentBufferIndex-2) MOD 32] # playCurrentSamplingRate THEN
					playCurrentSamplingRate := playSamplingRate[(playCurrentBufferIndex-2) MOD 32];
					AC97.SetDacRate(playCurrentSamplingRate)
				END;

				SYSTEM.MOVE(
					ADDRESSOF(playBuffer.data[0]),
					ADDRESSOF(playBufferList[playCurrentBufferIndex].data[0]),
					BufferSize);
				playBufferList[playCurrentBufferIndex].len := playBuffer.len;

			END MixBuffers;

			(* Mix two buffers of the same sampling rate *)
			PROCEDURE MixTwo(VAR buffer : SoundDevices.Buffer; buffer2 : SoundDevices.Buffer);
			VAR
				mix, sample1, sample2 : LONGINT;
				i : LONGINT;
			BEGIN
				(* First buffer don't have to be mixed *)
				IF buffer = NIL THEN
					buffer := buffer2;
					RETURN;
				END;

				ASSERT(buffer.len = buffer2.len);

				FOR i := 0 TO buffer.len-1 DO
					(* Lineary interpolate two samples *)
					sample1 := SYSTEM.VAL(INTEGER, buffer.data[i]);
					sample2 := SYSTEM.VAL(INTEGER, buffer2.data[i]);

					(* Lower volume to try to avoid clipping *)
					mix := sample1+sample2;

					(* Clip *)
					IF mix > MAX(INTEGER) THEN
						mix := MAX(INTEGER);
					END;
					IF mix < MIN(INTEGER) THEN
						mix := MIN(INTEGER);
					END;


					buffer.data[i] := CHR(mix);
					buffer.data[i+1] := CHR(LSH(mix, -8));

					INC(i)
				END
			END MixTwo;

			(* Procedure to return recorded data *)
			PROCEDURE ReturnBuffers*;
			VAR
				item : RecChannelList;
			BEGIN
				(* Last valid index is always 3 steps ahead of current buffer index *)
				recCurrentBufferIndex := (recLastValidIndex - 3) MOD 32;
				item := firstRecChannel;
				WHILE item # NIL DO
					IF item.channel.state = StateRecording THEN
						item.channel.PrepareData(recBufferList[recCurrentBufferIndex], recSamplingRate)
					END;
					item := item.next
				END;

				NABMBAR.RegWrite8(BMRInBase + BMRLastValidIndexReg, recLastValidIndex)
			END ReturnBuffers;

			PROCEDURE Init*;
			BEGIN
				SetName("i810 Sound driver");
				desc := "Sound driver for the Intel 810 chips"
			END Init;

			PROCEDURE Enable*;
			BEGIN
				(* PCM Out *)
				IF TestBit(NABMBAR.RegRead16(BMROutBase + BMRStatusReg), 0) THEN
					NABMBAR.RegWrite8(BMROutBase + BMRCtrlReg, 11H)
				END;

				(* PCM In *)
				IF TestBit(NABMBAR.RegRead16(BMRInBase + BMRStatusReg), 0) THEN
					NABMBAR.RegWrite8(BMRInBase + BMRCtrlReg, 11H)
				END
			END Enable;

			PROCEDURE Disable*;
			BEGIN
				(* PCM Out *)
				NABMBAR.RegWrite16(BMROutBase + BMRStatusReg, 0002H);
				NABMBAR.RegWrite8(BMROutBase + BMRCtrlReg, 00H);

				(* PCM In *)
				NABMBAR.RegWrite16(BMRInBase + BMRStatusReg, 0002H);
				NABMBAR.RegWrite8(BMRInBase + BMRCtrlReg, 00H)
			END Disable;

			PROCEDURE NofNativeFrequences() : LONGINT;
			BEGIN
				RETURN 0;
			END NofNativeFrequences;

			PROCEDURE GetNativeFrequency*(nr : LONGINT) : LONGINT;
			BEGIN
				RETURN 48000;
			END GetNativeFrequency;

			PROCEDURE NofSamplingResolutions*() : LONGINT;
			BEGIN
				RETURN 2 (* 16 Bit and 8 Bit *)
			END NofSamplingResolutions;

			PROCEDURE GetSamplingResolution(nr : LONGINT) : LONGINT;
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

			PROCEDURE NofWaveFormats*() : LONGINT;
			BEGIN
				RETURN 1 (* Only PCM *)
			END NofWaveFormats;

			PROCEDURE OpenPlayChannel*(VAR channel : SoundDevices.Channel; samplingRate, samplingResolution,
				nofSubChannels, format : LONGINT; VAR res : LONGINT);
			VAR
				playChannel : PlayChannel;
				sResolution : LONGINT;
			BEGIN {EXCLUSIVE}
				channel := NIL;

				(* Check for valid sample rate.
					All values < 7040 will be set to 7040. *)
				IF ~((samplingRate > 0) & (samplingRate <= 48000)) THEN
					res := SoundDevices.ResUnsupportedFrequency;
					RETURN
				END;

				(* Check for supported samplingResolution *)
				IF samplingResolution = 16 THEN
					sResolution := 0
				ELSIF samplingResolution = 8 THEN
					sResolution := 1
				ELSE
					res := SoundDevices.ResUnsupportedSamplingRes;
					RETURN
				END;

				(* Check for supported subchannel *)
				IF (nofSubChannels # 1) & (nofSubChannels # 2) THEN
					res := SoundDevices.ResUnsupportedSubChannels;
					RETURN
				END;

				(* Check for supported format *)
				IF format # SoundDevices.FormatPCM THEN
					res := SoundDevices.ResUnsupportedFormat;
					RETURN
				END;

				(* Fine, we passed all tests. Let's create a channel. *)
				NEW(playChannel, SELF, samplingRate, sResolution, nofSubChannels);
				channel := playChannel;
				AddPlayChannel(playChannel);

				IF TraceOpenChannel IN Debug THEN
					KernelLog.String("Open PlayChannel: "); KernelLog.Int(samplingRate, 1); KernelLog.String("Hz, ");
					KernelLog.Int(samplingResolution, 1); KernelLog.String("bit, ");
					KernelLog.Int(nofSubChannels, 1); KernelLog.String(" channel(s)"); KernelLog.Ln
				END;

				res := SoundDevices.ResOK
			END OpenPlayChannel;

			PROCEDURE RemovePlayChannel(channel : PlayChannel);
			VAR
				item : PlayChannelList;
			BEGIN
				item := firstPlayChannel;
				IF item # NIL THEN
					IF item.channel = channel THEN
						firstPlayChannel := item.next;
						RETURN
					END
				END;

				WHILE item.next # NIL DO
					IF item.next.channel = channel THEN
						item.next := item.next.next;
						RETURN
					END;
					item := item.next
				END
			END RemovePlayChannel;

			PROCEDURE AddPlayChannel(channel : PlayChannel);
			VAR
				item : PlayChannelList;
			BEGIN
				NEW(item);
				item.channel := channel;
				item.next := firstPlayChannel;
				firstPlayChannel := item
			END AddPlayChannel;

			PROCEDURE OpenRecordChannel*(VAR channel : SoundDevices.Channel; samplingRate, samplingResolution,
				nofSubChannels, format : LONGINT; VAR res : LONGINT);
			VAR
				recChannel : RecChannel;
				item : RecChannelList;
				sResolution : LONGINT;
			BEGIN {EXCLUSIVE}
				channel := NIL;

				(* Check for valid sample rate.
					All values < 7040 will be set to 7040. *)
				IF ~((samplingRate > 0) & (samplingRate <= 48000)) THEN
					res := SoundDevices.ResUnsupportedFrequency;
					RETURN
				END;

				(* Check for supported samplingResolution *)
				IF samplingResolution = 16 THEN
					sResolution := 0
				ELSIF samplingResolution = 8 THEN
					sResolution := 1
				ELSE
					res := SoundDevices.ResUnsupportedSamplingRes;
					RETURN
				END;

				(* Check for supported subchannel *)
				IF (nofSubChannels # 1) & (nofSubChannels # 2) THEN
					res := SoundDevices.ResUnsupportedSubChannels;
					RETURN
				END;

				(* Check for supported format *)
				IF format # SoundDevices.FormatPCM THEN
					res := SoundDevices.ResUnsupportedFormat;
					RETURN;
				END;

				(* Fine, we passed all tests. Let's create a channel. *)
				NEW(recChannel, SELF, samplingRate, sResolution, nofSubChannels);
				channel := recChannel;
				AddRecChannel(recChannel);

				IF TraceOpenChannel IN Debug THEN
					KernelLog.String("Open RecChannel: "); KernelLog.Int(samplingRate, 1); KernelLog.String("Hz, ");
					KernelLog.Int(samplingResolution, 1); KernelLog.String("bit, ");
					KernelLog.Int(nofSubChannels, 1); KernelLog.String(" channel(s)"); KernelLog.Ln
				END;

				(* Set max sampling rate *)
				recSamplingRate := 1;
				item := firstRecChannel;
				WHILE item # NIL DO
					recSamplingRate := Max(recSamplingRate, item.channel.samplingRate);
					item := item.next;
				END;

				recSamplingRate := samplingRate;
				AC97.SetAdcRate(recSamplingRate);

				res := SoundDevices.ResOK

			END OpenRecordChannel;

			PROCEDURE RemoveRecChannel(channel : RecChannel);
			VAR
				item : RecChannelList;
			BEGIN
				item := firstRecChannel;
				IF item # NIL THEN
					IF item.channel = channel THEN
						firstRecChannel := item.next;
						RETURN
					END
				END;

				WHILE item.next # NIL DO
					IF item.next.channel = channel THEN
						item.next := item.next.next;
						RETURN
					END;
					item := item.next
				END;

			END RemoveRecChannel;

			PROCEDURE AddRecChannel(channel : RecChannel);
			VAR
				item : RecChannelList;
			BEGIN
				NEW(item);
				item.channel := channel;
				item.next := firstRecChannel;
				firstRecChannel := item
			END AddRecChannel;

			PROCEDURE RegisterMixerChangeListener*(mixChangedProc : SoundDevices.MixerChangedProc);
			VAR
				item : MixerChangedProcList;
			BEGIN {EXCLUSIVE}
				ASSERT(mixChangedProc # NIL);

				NEW(item);
				item.mixerChangedProc := mixChangedProc;
				item.next := firstMixerChangedProc;
				firstMixerChangedProc := item
			END RegisterMixerChangeListener;

			PROCEDURE UnregisterMixerChangeListener*(mixChangeProc : SoundDevices.MixerChangedProc);
			VAR
				item : MixerChangedProcList;
			BEGIN {EXCLUSIVE}
				item := firstMixerChangedProc;

				(* No registered listeners *)
				IF item = NIL THEN
					RETURN;
				END;

				(* Check first entry *)
				IF item.mixerChangedProc = mixChangeProc THEN
					firstMixerChangedProc := item.next;
					IF DebugTraceListeners IN Debug THEN KernelLog.String("Removed mixerChangedProc"); KernelLog.Ln END;
					RETURN;
				END;

				WHILE (item.next # NIL) & (item.next.mixerChangedProc # mixChangeProc) DO
					item := item.next
				END;

				IF item.next # NIL THEN
					item.next := item.next.next;
					IF DebugTraceListeners IN Debug THEN KernelLog.String("Removed mixerChangedProc"); KernelLog.Ln END
				ELSE
					IF DebugTraceListeners IN Debug THEN KernelLog.String("Could not remove mixerChangeProc"); KernelLog.Ln END
				END;
			END UnregisterMixerChangeListener;

			PROCEDURE GetMixerChannel*(channelNr : LONGINT; VAR channel : SoundDevices.MixerChannel);
			BEGIN
				IF (channelNr >= 0) & (channelNr < NofMixerChannels) THEN
					channel := mixerChannelList[channelNr]
				ELSE
					channel := NIL
				END
			END GetMixerChannel;

			PROCEDURE GetNofMixerChannels*() : LONGINT;
			BEGIN
				RETURN NofMixerChannels
			END GetNofMixerChannels;

			BEGIN {ACTIVE}
				playInterrupt := FALSE;
				recInterrupt := FALSE;

				WHILE (TRUE) DO
					BEGIN {EXCLUSIVE}
						AWAIT(playInterrupt OR recInterrupt);
					END;

					IF playInterrupt THEN
						QueueBuffer;
						playInterrupt := FALSE;
					ELSIF recInterrupt THEN
						ReturnBuffers;
						recInterrupt := FALSE;
					END;
				END;
		END Driver;



		(**
			MixerChannel is a hardware mixer channel that control the
			AC97 chip. It can set volume for each channel.
		*)
		MixerChannel = OBJECT(SoundDevices.MixerChannel)
			VAR
				driver : Driver;
				name, desc : POINTER TO ARRAY OF CHAR;
				volumeReg : LONGINT;
				volume, muteVol : LONGINT;
				volBits : LONGINT;
				mute : BOOLEAN;

			PROCEDURE &Constr*(driver : Driver; volumeReg : LONGINT; mute : BOOLEAN; name, desc : ARRAY OF CHAR);
			VAR
				i : LONGINT;
			BEGIN
				SELF.driver := driver;
				SELF.volumeReg := volumeReg;
				SELF.mute := mute;

				NEW(SELF.name, LEN(name));
				FOR i := 0 TO LEN(name) - 1 DO
					SELF.name^[i] := name[i];
				END;

				NEW(SELF.desc, LEN(desc));
				FOR i := 0 TO LEN(desc) - 1 DO
					SELF.desc^[i] := desc[i]
				END;

				(* Get number of volume bits *)
				(* Set first 6 bits and shift until a '0' appears *)
				driver.AC97.RegWrite16(volumeReg, 803FH);
				volume := driver.AC97.RegRead16(volumeReg);
				volBits := 0;
				WHILE ODD(volume) DO
					volume := LSH(volume, -1);
					INC(volBits)
				END;

				(* 64 seems to be a reasonable init volume *)
				SetVolume(InitVolume)
			END Constr;

			PROCEDURE GetName*(VAR name : ARRAY OF CHAR);
			BEGIN
				COPY(SELF.name^, name)
			END GetName;

			PROCEDURE GetDesc*(VAR desc : ARRAY OF CHAR);
			BEGIN
				COPY(SELF.desc^, desc)
			END GetDesc;

			PROCEDURE SetVolume*(volume : LONGINT);
			BEGIN {EXCLUSIVE}
				ASSERT((volume >= 0) & (volume <= 255));
				SELF.volume := volume;

				(* Shift away "overflow" bits *)
				volume := 255 - volume;
				volume := LSH(volume, volBits - 8);
				volume := volume + LSH(volume, 8);
				IF SELF.mute THEN SetBit(volume, 15) END;
				IF Boost THEN SetBit(volume, 6) END;
				driver.AC97.RegWrite16(volumeReg, volume);

				CallMixerListeners
			END SetVolume;

			PROCEDURE GetVolume*() : LONGINT;
			BEGIN
				RETURN SELF.volume
			END GetVolume;

			(* Volume has to be 0 <= volume < 256 *)
			PROCEDURE SetMute*(mute : BOOLEAN);
			VAR
				volume : LONGINT;
			BEGIN {EXCLUSIVE}
				SELF.mute := mute;
				IF mute THEN muteVol := volume; volume := 0
				ELSE volume := muteVol END;
(*				volume := driver.AC97.RegRead16(volumeReg);
				SetBit(volume, 15);
				driver.AC97.RegWrite16(volume, volumeReg);
*)				CallMixerListeners
			END SetMute;

			PROCEDURE GetIsMute*() : BOOLEAN;
			BEGIN
				RETURN SELF.mute;
			END GetIsMute;

			PROCEDURE CallMixerListeners;
			VAR
				item : MixerChangedProcList;
			BEGIN
				item := driver.firstMixerChangedProc;
				WHILE item # NIL DO
					item.mixerChangedProc(SELF);
					item := item.next
				END
			END CallMixerListeners;

		END MixerChannel;

		(**
			Audio player/recorder asks driver for a channel. Through the channel are data
			enqueued for playing or recording. Software mixing of volume i possible.
		*)
		Channel = OBJECT(SoundDevices.Channel)
			VAR
				driver : Driver;
				samplingRate, samplingResolution, nofSubChannels : LONGINT;
				bufferListener : SoundDevices.BufferListener;
				firstBuffer, lastBuffer : BufferList;
				playRecBuffer : SoundDevices.Buffer;
				firstBufferPos : LONGINT;
				volume : LONGINT;
				state : LONGINT;


			PROCEDURE &Constr*(driver : Driver; samplingRate, samplingResolution, nofSubChannels : LONGINT);
			BEGIN
				SELF.driver := driver;
				SELF.samplingRate := samplingRate;
				SELF.samplingResolution := samplingResolution;
				SELF.nofSubChannels := nofSubChannels;

				NEW(playRecBuffer);
				NEW(playRecBuffer.data, BufferSize);
				playRecBuffer.len := BufferSize;

				(* Set volume to max. Software software mixing only wastes data. *)
				SetVolume(255)
			END Constr;

			PROCEDURE GetChannelKind*() : LONGINT;
			BEGIN
				HALT(99) (* ABSTRACT *)
			END GetChannelKind;

			PROCEDURE SetVolume*(volume : LONGINT);
			BEGIN
				SELF.volume := volume
			END SetVolume;

			(* Linear volume *)
			PROCEDURE SampleSetVolume(VAR sample : Sample);
			VAR
				left, right : LONGINT;
				volume : LONGINT;
			BEGIN
				volume := SELF.volume;
				IF (volume < 0) THEN volume := 0 END;
				IF (volume > 255) THEN volume := 255 END;

				left := SYSTEM.VAL(INTEGER, sample);
				right := SYSTEM.VAL(INTEGER, sample[2]);

				(* Multiply volume with a number between 0 and 1. *)

				left := left * volume DIV 256;
				right := right * volume DIV 256;

				sample[0] := CHR(left);
				sample[1] := CHR(LSH(left, -8));
				sample[2] := CHR(right);
				sample[3] := CHR(LSH(right, -8))
			END SampleSetVolume;

			PROCEDURE GetVolume*() : LONGINT;
			BEGIN
				RETURN SELF.volume
			END GetVolume;

			PROCEDURE GetPosition*() : LONGINT;
			BEGIN
				RETURN firstBufferPos
			END GetPosition;

			PROCEDURE RegisterBufferListener*(bufferListener : SoundDevices.BufferListener);
			BEGIN {EXCLUSIVE}
				SELF.bufferListener := bufferListener
			END RegisterBufferListener;

			PROCEDURE QueueBuffer*(x : SoundDevices.Buffer);
			VAR
				bufferListItem : BufferList;
			BEGIN
				NEW(bufferListItem);
				bufferListItem.buffer := x;

				IF firstBuffer = NIL THEN
					firstBuffer := bufferListItem
				ELSE
					lastBuffer.next := bufferListItem
				END;

				lastBuffer := bufferListItem
			END QueueBuffer;

			PROCEDURE ReturnBuffer*() : SoundDevices.Buffer;
			BEGIN
				RETURN playRecBuffer
			END ReturnBuffer;

			PROCEDURE Start*;
			BEGIN
				HALT(99) (* ABSTRACT *)
			END Start;

			PROCEDURE Pause*;
			BEGIN
				state := StatePaused
			END Pause;

			PROCEDURE Stop*;
			BEGIN
				state := StateStoped;
				ReturnAllBuffers;
			END Stop;

			PROCEDURE Close*;
			BEGIN
				HALT(99) (* ABSTRACT *)
			END Close;

			PROCEDURE CallBufferListener() : BOOLEAN;
			BEGIN
				IF bufferListener = NIL THEN
					IF firstBuffer # NIL THEN
						firstBuffer := firstBuffer.next
					END;
					firstBufferPos := 0;
					RETURN FALSE
				END;

				bufferListener(firstBuffer.buffer);
				firstBuffer := firstBuffer.next;
				firstBufferPos := 0;
				RETURN TRUE
			END CallBufferListener;

			PROCEDURE ReturnAllBuffers;
			VAR
				item : BufferList;
			BEGIN {EXCLUSIVE}
				IF bufferListener = NIL THEN RETURN END;
				item := firstBuffer;
				WHILE item # NIL DO
					bufferListener(item.buffer);
					item := item.next
				END;
				firstBuffer := NIL
			END ReturnAllBuffers;

		END Channel;


		PlayChannel = OBJECT(Channel);

			PROCEDURE &ConstrPlay*(driver : Driver; samplingRate, samplingResolution, nofSubChannels : LONGINT);
			BEGIN
				Constr(driver, samplingRate, samplingResolution, nofSubChannels);
			END ConstrPlay;

			PROCEDURE Start*;
			BEGIN
				ASSERT(state # StateClosed);
				state := StatePlaying;
				driver.Enable;
			END Start;

			PROCEDURE Close*;
			BEGIN
				Stop;
				state := StateClosed;
				driver.RemovePlayChannel(SELF)
			END Close;

			(*
				1) PCM Out Interrupt -> Driver::QueueBuffer -> Driver::MixBuffers -> PlayChannel::PrepareData
				2) Driver::MixBuffer -> PlayChannel::ReturnBuffer

				Prepare data into playRecBuffer. That buffer is then read by Driver::MixBuffers which mixes
				several channels into one channel, which will be enqueued for DMA to read and play.

				WavePlayer enqueues a buffer the the channel. When this channel has emptied the buffer
				it calls the registered buffer listener and asks the player to enqueue another buffer.
			*)
			PROCEDURE PrepareData*(toRate : LONGINT);
			VAR
				playRecBufferPos : LONGINT;
				sample : Sample;
				srate : LONGINT;
			BEGIN {EXCLUSIVE}
				srate := 0;

				WHILE (firstBuffer # NIL) & (playRecBufferPos < BufferSize) DO

					(* Upsampling. If srate > torate then we insert the sample,
						else we strech buffer by inserting silent data. *)
					srate := srate + samplingRate;
					IF (srate >= toRate) THEN
						srate := srate MOD toRate;

						(* 16 bit stereo *)
						IF (samplingResolution = 0) & (nofSubChannels = 2) THEN
							sample[0] := firstBuffer.buffer.data[firstBufferPos];
							sample[1] := firstBuffer.buffer.data[firstBufferPos+1];
							sample[2] := firstBuffer.buffer.data[firstBufferPos+2];
							sample[3] := firstBuffer.buffer.data[firstBufferPos+3];
							INC(firstBufferPos, 4);

						(* 16 bit mono *)
						ELSIF (samplingResolution = 0) & (nofSubChannels = 1) THEN
							sample[0] := firstBuffer.buffer.data[firstBufferPos];
							sample[1] := firstBuffer.buffer.data[firstBufferPos+1];
							MonoToStereo(sample);
							INC(firstBufferPos, 2);

						(* 8 bit stereo *)
						ELSIF (samplingResolution = 1) & (nofSubChannels = 2) THEN
							sample[0] := firstBuffer.buffer.data[firstBufferPos];
							sample[1] := firstBuffer.buffer.data[firstBufferPos+1];
							EightToSixten(sample);
							INC(firstBufferPos, 2);

						(* 8 bit stereo *)
						ELSIF (samplingResolution = 1) & (nofSubChannels = 1) THEN
							sample[0] := firstBuffer.buffer.data[firstBufferPos];
							EightToSixten(sample);
							MonoToStereo(sample);
							INC(firstBufferPos);

						(* Unsupported bitrate and no of channels *)
						ELSE
							KernelLog.Int(samplingResolution, 1); KernelLog.String(" bit, ");
							KernelLog.Int(nofSubChannels, 1); KernelLog.String(" channels are not supported");
							HALT(99)
						END;

						SampleSetVolume(sample);

						playRecBuffer.data[playRecBufferPos] := sample[0];
						playRecBuffer.data[playRecBufferPos+1] := sample[1];
						playRecBuffer.data[playRecBufferPos+2] := sample[2];
						playRecBuffer.data[playRecBufferPos+3] := sample[3];

						INC(playRecBufferPos, 4);

						(* End of queue buffer *)
						IF firstBufferPos >= firstBuffer.buffer.len THEN
							IF ~CallBufferListener() THEN
								OutputSilentData(playRecBufferPos);
								RETURN
							END;
						END;

					(* Insert silent sample *)
					ELSE
						(*KernelLog.String("Upsample"); KernelLog.Ln;*)
						playRecBuffer.data[playRecBufferPos] := CHR(0);
						playRecBuffer.data[playRecBufferPos+1] := CHR(0);
						playRecBuffer.data[playRecBufferPos+2] := CHR(0);
						playRecBuffer.data[playRecBufferPos+3] := CHR(0);

						INC(playRecBufferPos, 4);
					END;
				END;

					(* If buffer is not filled up then output silent data *)
					OutputSilentData(playRecBufferPos)
			END PrepareData;

			(* 8 bit => 16 bit conversion *)
			PROCEDURE EightToSixten(VAR sample : Sample);
			BEGIN
				sample[3] := CHR(ORD(sample[1])-128);
				sample[2] := CHR(0);
				sample[1] := CHR(ORD(sample[0])-128);
				sample[0] := CHR(0)
			END EightToSixten;

			(* mono => stereo conversion *)
			PROCEDURE MonoToStereo(VAR sample : Sample);
			BEGIN
				sample[2] := sample[0];
				sample[3] := sample[1]
			END MonoToStereo;

			(* If there is no more data to fill up playRecBuffer with we output silent data. *)
			PROCEDURE OutputSilentData(playRecBufferPos : LONGINT);
			BEGIN
				WHILE (playRecBufferPos < BufferSize) DO
					playRecBuffer.data[playRecBufferPos] := silentData;
					INC(playRecBufferPos, 1)
				END
			END OutputSilentData;

		END PlayChannel;


		RecChannel = OBJECT(Channel)

			PROCEDURE Start*;
			BEGIN
				ASSERT(state # StateClosed);
				state := StateRecording;
				driver.Enable
			END Start;

			PROCEDURE Close*;
			BEGIN
				Stop;
				state := StateClosed;
				driver.RemoveRecChannel(SELF);
			END Close;

			(*
				PCM In Interrupt -> Driver::ReturnBuffers -> RecChannel::PrepareData
				Prepares data and return it to RecPlayer
			*)
			PROCEDURE PrepareData(buffer : SoundDevices.Buffer; toRate : LONGINT);
			VAR
				bufferPos : LONGINT;
				sample : Sample;
				sampleSize : SHORTINT;
				srate : LONGINT;
			BEGIN
				srate := 0;
				bufferPos := 0;
				WHILE (firstBuffer # NIL) & (bufferPos < buffer.len) DO

					srate := srate + toRate;
					IF (srate >= samplingRate) THEN
						srate := srate MOD samplingRate;

						sample[0] := buffer.data[bufferPos];
						sample[1] := buffer.data[bufferPos+1];
						sample[2] := buffer.data[bufferPos+2];
						sample[3] := buffer.data[bufferPos+3];

						(*SampleSetVolume(sample);*)
						INC(bufferPos, 4);

						(* 16 bit stereo *)
						IF (samplingResolution = 0) & (nofSubChannels = 2) THEN
							sampleSize := 4

						(* 16 bit mono *)
						ELSIF (samplingResolution = 0) & (nofSubChannels = 1) THEN
							StereoToMono(sample);
							sampleSize := 2

						(* 8 bit stereo *)
						ELSIF (samplingResolution = 1) & (nofSubChannels = 2) THEN
							SixtenToEight(sample);
							sampleSize := 2

						(* 8 bit stereo *)
						ELSIF (samplingResolution = 1) & (nofSubChannels = 1) THEN
							StereoToMono(sample);
							SixtenToEight(sample);
							sampleSize := 1

						(* Unsupported bitrate and no of channels *)
						ELSE
							KernelLog.Int(samplingResolution, 1); KernelLog.String(" bit, ");
							KernelLog.Int(nofSubChannels, 1); KernelLog.String(" channels are not supported");
							HALT(99)
						END;

						SYSTEM.MOVE(
							ADDRESSOF(sample[0]),
							ADDRESSOF(firstBuffer.buffer.data[0]) + firstBufferPos,
							sampleSize);
						INC(firstBufferPos, sampleSize);

						(* If buffer is filled, then return buffer *)
						IF firstBufferPos >= firstBuffer.buffer.len THEN
							IF ~CallBufferListener() THEN
								RETURN
							END;
						END;

					(* Drop sample *)
					ELSE
						INC(bufferPos, 4);
					END;

				END;

			END PrepareData;

			(* stereo => mono conversion *)
			PROCEDURE StereoToMono(VAR sample : Sample);
			VAR
				mix, left, right : LONGINT;
			BEGIN
				(* Take average of left and right channel *)
				left := SYSTEM.VAL(INTEGER, sample);
				right := SYSTEM.VAL(INTEGER, sample[2]);
				mix := LSH(left + right, -1);

				sample[0] := CHR(mix);
				sample[1] := CHR(LSH(mix, -8))
			END StereoToMono;

			(* 16 bit => 8 bit conversion *)
			PROCEDURE SixtenToEight(VAR sample : Sample);
			BEGIN
				sample[0] := CHR(ORD(sample[1]) - 128);
				sample[1] := CHR(ORD(sample[3]) - 128)
			END SixtenToEight;

		END RecChannel;

	VAR
		silentData : CHAR;
		firstDriver : DriverList;
		DriverTab : Plugins.Table;
		installedDriver : BOOLEAN;



	PROCEDURE SetBit(VAR a : LONGINT; n : LONGINT);
	BEGIN
		ASSERT((n >= 0) & (n < 32));
		INCL(SYSTEM.VAL(SET, a), n)
	END SetBit;

(*
	PROCEDURE ClearBit(VAR a : LONGINT; n : LONGINT);
	VAR t : SET;
	BEGIN
		ASSERT((n >= 0) & (n < 32));
		t := SYSTEM.VAL(SET, a);
		EXCL(t, n);
		a := SYSTEM.VAL(LONGINT, t)
	END ClearBit;
*)

	PROCEDURE TestBit(a, n : LONGINT) : BOOLEAN;
	BEGIN
		RETURN n IN SYSTEM.VAL(SET, a);
	END TestBit;

	(* Return maximum value *)
	PROCEDURE Max(i, j : LONGINT) : LONGINT;
	BEGIN
		IF i > j THEN RETURN i ELSE RETURN j END
	END Max;

	(* Get physical address for DMA transfers *)
	PROCEDURE GetPhysicalAdr(adr: ADDRESS; size : SIZE) : Machine.Address32;
	VAR
		physadr : Machine.Address32;
	BEGIN
		(* All data has to be continous in memory since DMA does not understand pages *)
		physadr := Machine.Ensure32BitAddress (Machine.PhysicalAdr(adr, size));
		ASSERT(physadr # Machine.NilAdr);
		(* Address must be 8 byte align. See Intel programmes manual
		for close details of the Buffer Description List *)
		ASSERT(physadr MOD 4 = 0);
		RETURN physadr
	END GetPhysicalAdr;

	(* Scan after PCI card and install it if found *)
	PROCEDURE ScanPCI(vendid, devid : LONGINT);
	VAR
		index, res, i : LONGINT;
		CmdReg : LONGINT;
		bus, dev, fkt : LONGINT;
		nambar, nabmbar, irq : LONGINT;
		driver : Driver;
		driverList : DriverList;

	BEGIN
		IF DebugInit IN Debug THEN KernelLog.String("Search for PCI card"); KernelLog.Ln END;

		index := 0;
		WHILE (index < 10) &
			(PCI.FindPCIDevice(devid, vendid, index, bus, dev, fkt) = PCI.Done) DO

			res := PCI.ReadConfigWord(bus, dev, fkt, PCI.CmdReg, i);
			IF DebugInit IN Debug THEN
				KernelLog.String("Vendor ID: "); KernelLog.Hex(vendid, 4); KernelLog.String("h"); KernelLog.Ln;
				KernelLog.String("Device ID: "); KernelLog.Hex(devid, 4); KernelLog.String("h"); KernelLog.Ln;
				KernelLog.String("Bus: "); KernelLog.Int(bus, 1); KernelLog.Ln;
				KernelLog.String("Device: "); KernelLog.Int(dev, 1); KernelLog.Ln;
				KernelLog.String("Function: "); KernelLog.Int(fkt, 1); KernelLog.Ln;
				KernelLog.String("Command: "); KernelLog.Hex(i, 4); KernelLog.String("h"); KernelLog.Ln
			END;

			(* Get NAMBAR, Native Audio Mixer Base Address Register *)
			res := PCI.ReadConfigDword(bus, dev, fkt, PCI.Adr0Reg, nambar);
			ASSERT(res = PCI.Done);
			ASSERT(ODD(nambar));
			DEC(nambar, nambar MOD 16);
			IF DebugInit IN Debug THEN
				KernelLog.String("Native Audio Mastering Base Address (NAMABR): "); KernelLog.Int(nambar, 5); KernelLog.Ln
			END;

			(* Get NAMBMBAR, Native Audio Bus Mastering Base Address Register *)
			res := PCI.ReadConfigDword(bus, dev, fkt, PCI.Adr1Reg, nabmbar);
			ASSERT(res = PCI.Done);
			ASSERT(ODD(nabmbar));
			DEC(nabmbar, nabmbar MOD 16);
			IF DebugInit IN Debug THEN
				KernelLog.String("Native Audio Bus Mastering Base Address (NABMABR): "); KernelLog.Int(nabmbar, 5); KernelLog.Ln
			END;

			(* Get IRQ number *)
			res := PCI.ReadConfigByte(bus, dev, fkt, PCI.IntlReg, irq);
			ASSERT(res = PCI.Done);
			IF DebugInit IN Debug THEN
				KernelLog.String("IRQ: "); KernelLog.Int(irq, 2); KernelLog.Ln
			END;

			(* AC97 registers have to be enabled in the PCI Command Register *)
			res := PCI.ReadConfigWord(bus, dev, fkt, PCI.CmdReg, CmdReg);
			ASSERT(res = PCI.Done);
			SetBit(CmdReg, 0);
			res := PCI.WriteConfigWord(bus, dev, fkt, PCI.CmdReg, CmdReg);
			ASSERT(res = PCI.Done);

			(* Create Driver Object *)
			NEW(driver, nambar, nabmbar, irq);

			KernelLog.String("Intel 810 sound driver installed."); KernelLog.Ln;

			NEW(driverList);
			driverList.driver := driver;
			driverList.next := firstDriver;
			firstDriver := driverList;

			INC(index)
		END
END ScanPCI;


	(* Install the driver *)
	PROCEDURE Install*;
	BEGIN {EXCLUSIVE}
		(* Avoid multiple installation *)
		IF ~installedDriver THEN
			(* Scan for hardware *)
			(* TODO - extend this list *)
			ScanPCI(8086H,2485H);
			ScanPCI(8086H, 24C5H);
			ScanPCI(8086H, 266EH); (* Intel 915 chipset *)

			(* These chips should work, but it hasn't been tested! *)
			(* This list could probaly be further extended *)
			IF (InsecureMode = TRUE) THEN
				ScanPCI(8086H, 2415H);
				ScanPCI(8086H, 2425H);
				ScanPCI(8086H, 2445H);
				ScanPCI(8086H, 24D5H);
				ScanPCI(8086H, 7195H);
				(*ScanPCI(8086H, 7012H);*)
			END;

			installedDriver := TRUE
		END;
	END Install;

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
		item : DriverList;
	BEGIN
		item := firstDriver;
		WHILE item # NIL DO
			item.driver.Finalize;
			item := item.next
		END
	END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END i810Sound.


PC.Compile * \s ~
System.Free i810Sound ~ (* Make sure module is unloaded *)
Aos.Call i810Sound.Install ~

Aos.Call i810Sound.Disable ~ (* pause all *)
Aos.Call i810Sound.Enable ~

Aos.Call PlayRecWave.Play x.wav ~
Aos.Call MP3Player.Play DATA:/SomeMp3File.Mp3 ~

System.Free i810Sound ~
SystemTools.Free i810Sound~
