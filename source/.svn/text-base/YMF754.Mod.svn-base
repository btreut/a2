MODULE YMF754;	(** AUTHOR "mvt"; PURPOSE "Sound driver for Yamaha YMF754"; *)

IMPORT
	SYSTEM, PCI, Strings, Files, Machine, Modules, SoundDevices,
	Plugins, Objects, Kernel, KernelLog;

CONST
	(* Driver related constants *)
	Logging = TRUE; (* output to kernel log? *)
	FNameInstRAM = "YMF754.Bin"; (* name of instruction RAM file *)
	PluginDescPrefix = "Sound driver for Yamaha ";
	BufferSizeMS = 100; (* size of sound buffer in milliseconds *)

	(* Device related constants *)
	SizeDSPInstRAM = 80H;
	SizeCtrlInstRAM = 3000H;
	NofPlaySlots = 64;
	NofPlaySlotPairs = NofPlaySlots DIV 2;
	NofBanks = 2;
	NofMixerChannels = 6;
	NofNativeFreq = 7;
	WorkBitTimeout = 250000;

	(* PCI configuration register offsets *)
	PCIRegDS1EControl = 48H;

	(* PCI Audio control register offsets *)
	PCCRegAC97CmdData = 0060H;
	PCCRegAC97CmdAddress = 0062H;
	PCCRegAC97StatusData = 0064H;
	PCCRegAC97StatusAddress = 0066H;

	PCCRegVolLegOut = 0080H;
	PCCRegVolDACOut = 0084H;
	PCCRegVolZVOut = 0088H;
	PCCRegVolSecAC97Out = 008CH;
	PCCRegVolADCOut = 0090H;
	PCCRegVolADCIn = 00A8H;
	PCCRegVolRECIn = 00ACH;
	PCCRegVolP44Out = 00B0H;
	PCCRegVolSPDIFOut = 00B8H;

	PCCRegADCSlotSamplingRate = 00C0H;
	PCCRegADCSlotFormat = 00C8H;

	PCCRegStatus = 0100H;
	PCCRegControlSelect = 0104H;
	PCCRegMode = 0108H;
	PCCRegConfig = 0114H;
	PCCRegPlayCtrlSize = 0140H;
	PCCRegRecCtrlSize = 0144H;
	PCCRegMapOfRec = 0150H;
	PCCRegMapOfEff = 0154H;
	PCCRegPlayCtrlBase = 0158H;
	PCCRegRecCtrlBase = 015CH;
	PCCRegEffCtrlBase = 0160H;
	PCCRegWorkBase = 0164H;

	PCCRegDSPInstRAM = 1000H;
	PCCRegCtrlInstRAM = 4000H;

	(* AC97 control register offsets *)
	ACCRegReset = 00H;
	ACCRegVolMasterOut = 02H;
	ACCRegVolMic = 0EH;
	ACCRegVolLineIn = 10H;
	ACCRegVolCD = 12H;
	ACCRegVolPCM = 18H;
	ACCRegRecordSelect = 1AH;
	ACCRegRecordGain= 1CH;

TYPE
	BufferListener = SoundDevices.BufferListener;
	Buffer = SoundDevices.Buffer;
	MixerChangedProc = SoundDevices.MixerChangedProc;

	(* Native frequencies table *)
	NativeFreqTable = ARRAY NofNativeFreq OF RECORD
		hz: LONGINT; (* frequency in Hz *)
		valRec: LONGINT; (* corresponding value to write to record register *)
		valLpfK: LONGINT; (* corresponding value to write to LpfK registers *)
		valLpfQ: LONGINT; (* corresponding value to write to LpfQ registers *)
	END;

	(* Mixer channel listener list type *)
	ListMixerChangedProc = POINTER TO RECORD
		proc: MixerChangedProc;
		next: ListMixerChangedProc
	END;

	(* Buffer list type *)
	ListBuffer = POINTER TO RECORD
		buff: Buffer;
		next: ListBuffer;
	END;

	(* Player channel list type *)
	ListPlayerChannel = POINTER TO RECORD
		channel: PlayerChannel;
		next: ListPlayerChannel;
	END;

	(* String types *)
	NameStr = ARRAY 32 OF CHAR;
	DescStr = ARRAY 128 OF CHAR;

	(* Buffer type for playing and recording data *)
	PlayRecBuffer = POINTER TO ARRAY OF CHAR;

	(* PCI Audio play control data table *)
	PlayCtrlDataTable = RECORD
		numOfPlay: LONGINT;
		playSlotBase: ARRAY NofPlaySlots OF LONGINT;
	END;

	(* PCI Audio record slot control data *)
	RecSlotCtrlData = RECORD
		recSlotREC: ARRAY NofBanks OF RecBank;
		recSlotADC: ARRAY NofBanks OF RecBank;
	END;

	(* Bank for record slot control data
		For description of the fields, see YMF754 hardware specification manual *)
	RecBank = RECORD;
		pgBase,
		pgLoopEndAdr,
		pgStartAdr,
		numOfLoops: LONGINT;
	END;

	(* Bank for play slot control data
		For description of the fields, see YMF754 hardware specification manual *)
	PlayBank = RECORD
		format, loopDefault, pgBase, pgLoop, pgLoopEnd, pgLoopFrac,
		pgDeltaEnd, lpfKEnd, egGainEnd, lchGainEnd, rchGainEnd, effect1GainEnd,
		effect2GainEnd, effect3GainEnd, lpfQ, status, numOfFrames, loopCount,
		pgStart, pgStartFrac, pgDelta, lpfK, egGain, lchGain,
		rchGain, effect1Gain, effect2Gain, effect3Gain, lpfD1, lpfD2: LONGINT;
	END;

	(* PCI Audio play slot control data *)
	PlaySlotCtrlData = ARRAY NofBanks OF PlayBank;

	(* Active object for calling buffer listeners *)
	BufferListenerCaller = OBJECT
		VAR
			bufferListener: BufferListener; (* this one will be called - NIL if none is registered *)
			first, last: ListBuffer; (* first and last pointer of queue *)
			close: BOOLEAN; (* close state: return all buffers and end ACTIVE part *)
			actualListener: BufferListener; (* used by ACTIVE part *)
			actualBuffer: Buffer; (* used by ACTIVE part *)

		(* Constructor *)
		PROCEDURE &Constr*;
		BEGIN
			bufferListener := NIL;
			first := NIL;
			last := NIL;
			close := FALSE;
		END Constr;

		(* Go to close state *)
		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			close := TRUE;
		END Close;

		(* Register a new buffer listener *)
		PROCEDURE RegisterBufferListener(bufferListener: BufferListener);
		BEGIN {EXCLUSIVE}
			SELF.bufferListener := bufferListener;
		END RegisterBufferListener;

		(* Queue a buffer to be returned by listener *)
		PROCEDURE ReturnBuffer(buffer: Buffer);
		VAR item: ListBuffer;
		BEGIN {EXCLUSIVE}
			IF bufferListener = NIL THEN RETURN END;
			NEW(item);
			item.buff := buffer;
			item.next := NIL;
			IF first = NIL THEN
				first := item;
				last := item;
			ELSE
				last.next := item;
				last := item;
			END;
		END ReturnBuffer;

	(* Active part of object *)
	BEGIN {ACTIVE, SAFE, PRIORITY(Objects.High)}
		WHILE ~close DO
			BEGIN {EXCLUSIVE}
				AWAIT((first # NIL) OR close);
				IF ~close THEN
					(* get actual listener and buffer for calling afterwards *)
					actualListener := bufferListener;
					actualBuffer := first.buff;
					first := first.next;
				END;
			END;
			(* Do listener calls outside of EXCLUSIVE region! *)
			IF close THEN
				(* return all buffers *)
				WHILE first # NIL DO
					bufferListener(first.buff);
					first := first.next;
				END;
			ELSE
				(* return actual buffer *)
				actualListener(actualBuffer);
			END;
		END;
		bufferListener := NIL;
	END BufferListenerCaller;

	(* PCI Audio control object *)
	PCIAudioControl = OBJECT
		VAR base: ADDRESS;
		CntrlInst1E: BOOLEAN; (* What Cntrl code to load: CntrlInst or CntrlInst1E *)

		(* Constructor *)
		PROCEDURE &Constr*(base: ADDRESS; CntrlInst1E: BOOLEAN);
		BEGIN
			SELF.base := base;
			SELF.CntrlInst1E := CntrlInst1E;
		END Constr;

		(* Routines for reading and writing PCI Audio registers *)

		PROCEDURE RegRead8(offset: LONGINT): LONGINT;
		BEGIN
			RETURN SYSTEM.GET8(base + offset);
		END RegRead8;

		PROCEDURE RegRead16(offset: LONGINT): LONGINT;
		BEGIN
			RETURN SYSTEM.GET16(base + offset);
		END RegRead16;

		PROCEDURE RegRead32(offset: LONGINT): LONGINT;
		BEGIN
			RETURN SYSTEM.GET32(base + offset);
		END RegRead32;

		PROCEDURE RegWrite8(offset: LONGINT; val: LONGINT);
		BEGIN
			SYSTEM.PUT8(base + offset, val);
		END RegWrite8;

		PROCEDURE RegWrite16(offset: LONGINT; val: LONGINT);
		BEGIN
			SYSTEM.PUT16(base + offset, val);
		END RegWrite16;

		PROCEDURE RegWrite32(offset: LONGINT; val: LONGINT);
		BEGIN
			SYSTEM.PUT32(base + offset, val);
		END RegWrite32;

		(* Initialize PCI Audio device *)
		PROCEDURE Initialize;
		VAR
			cnt: LONGINT;
			t: Kernel.Timer;
		BEGIN {EXCLUSIVE}
			(* Mute DAC volume before resetting *)
			RegWrite32(PCCRegVolDACOut, 0);

			(* Reset PCI Audio *)
			RegWrite32(PCCRegConfig, 0);
			cnt := 0;
			WHILE (cnt < WorkBitTimeout) & (1 IN SYSTEM.VAL(SET, RegRead32(PCCRegStatus))) DO
				INC(cnt);
			END;
			RegWrite32(PCCRegMode, 10000H);
			RegWrite32(PCCRegMode, 0);

			(* Init registers *)
			RegWrite32(PCCRegMapOfRec, 0);
			RegWrite32(PCCRegMapOfEff, 0);
			RegWrite32(PCCRegPlayCtrlBase, 0);
			RegWrite32(PCCRegRecCtrlBase, 0);
			RegWrite32(PCCRegEffCtrlBase, 0);
			RegWrite32(PCCRegWorkBase, 0);

			(* Load instruction code *)
			LoadInstructionCode;

			(* Enable DSP *)
			RegWrite32(PCCRegConfig, 1);

			(* Wait until instruction code takes effect *)
			NEW(t);
			cnt := 50; (* timeout = 50*2ms *)
			WHILE (cnt >= 0) & ~((SIZEOF(PlayBank) DIV 4 = RegRead32(PCCRegPlayCtrlSize)) & (SIZEOF(RecBank) DIV 4 = RegRead32(PCCRegRecCtrlSize))) DO
					t.Sleep(2); (* sleep for 2ms *)
					DEC(cnt);
			END;
			ASSERT(cnt >= 0); (* timeout - instruction code could not be correctly loaded! *)

			(* Sleep for 10ms before volume init to prevent scratching sounds *)
			t.Sleep(10);

			(* Mute unused native volumes *)
			RegWrite32(PCCRegVolLegOut, 0);
			RegWrite32(PCCRegVolZVOut, 0);
			RegWrite32(PCCRegVolSecAC97Out, 0);
			RegWrite32(PCCRegVolADCOut, 0);
			RegWrite32(PCCRegVolRECIn, 0);
			RegWrite32(PCCRegVolP44Out, 0);
			RegWrite32(PCCRegVolSPDIFOut, 0);

			(* Maximize DAC volume *)
			RegWrite32(PCCRegVolDACOut, 3FFF3FFFH);

			(* Minimize ADC volume (record channel volume) *)
			RegWrite32(PCCRegVolADCIn, 0);

		END Initialize;

		(* Uninitialize PCI Audio device *)
		PROCEDURE UnInitialize;
		VAR cnt: LONGINT;
		BEGIN {EXCLUSIVE}
			(* Mute volumes *)
			RegWrite32(PCCRegVolDACOut, 0);
			RegWrite32(PCCRegVolADCIn, 0);

			(* Reset PCI Audio *)
			RegWrite32(PCCRegConfig, 0);
			cnt := 0;
			WHILE (cnt < WorkBitTimeout) & (1 IN SYSTEM.VAL(SET, RegRead32(PCCRegStatus))) DO
				INC(cnt);
			END;
			RegWrite32(PCCRegMode, 10000H);

			(* Init registers *)
			RegWrite32(PCCRegMapOfRec, 0);
			RegWrite32(PCCRegMapOfEff, 0);
			RegWrite32(PCCRegPlayCtrlBase, 0);
			RegWrite32(PCCRegRecCtrlBase, 0);
			RegWrite32(PCCRegEffCtrlBase, 0);
			RegWrite32(PCCRegWorkBase, 0);
		END UnInitialize;

		(* Load instruction code into device RAM *)
		PROCEDURE LoadInstructionCode;
		VAR
			f: Files.File;
			r: Files.Reader;
			offset, data: LONGINT;
		BEGIN
			f := Files.Old(FNameInstRAM);
			ASSERT(f # NIL); (* assert existance of file *)
			ASSERT(f.Length() = SizeDSPInstRAM + SizeCtrlInstRAM * 2); (* assert length of file *)
			Files.OpenReader(r, f, 0);
			offset := PCCRegDSPInstRAM; (* begin with DSP instruction code *)
			WHILE offset < (PCCRegCtrlInstRAM + SizeCtrlInstRAM) DO
				r.RawLInt(data);
				RegWrite32(offset, data);
				INC(offset, SIZEOF(LONGINT));
				IF offset = PCCRegDSPInstRAM + SizeDSPInstRAM THEN
					(* Switch to controller instruction code *)
					offset := PCCRegCtrlInstRAM;
					(* Skip CtrlInst code *)
					IF CntrlInst1E THEN
						r.SkipBytes(SizeCtrlInstRAM);
					END;
				END;
			END;
		END LoadInstructionCode;

	END PCIAudioControl;

	(* AC97 control object *)
	AC97Control = OBJECT
		VAR PCC: PCIAudioControl;

		(* Constructor *)
		PROCEDURE &Constr*(PCC: PCIAudioControl);
		BEGIN
			SELF.PCC := PCC;
		END Constr;

		(* Routines for reading and writing AC97 registers (always 16 Bit) *)

		PROCEDURE RegRead16(offset: LONGINT): LONGINT;
		BEGIN {EXCLUSIVE}
			PCC.RegWrite16(PCCRegAC97CmdAddress, offset + 8000H);
			ASSERT(BusyWait());
			RETURN PCC.RegRead16(PCCRegAC97StatusData);
		END RegRead16;

		PROCEDURE RegWrite16(offset: LONGINT; val: LONGINT);
		BEGIN {EXCLUSIVE}
			PCC.RegWrite16(PCCRegAC97CmdAddress, offset);
			PCC.RegWrite16(PCCRegAC97CmdData, val);
			ASSERT(BusyWait());
		END RegWrite16;

		(* Wait while AC97 controller is busy. Return FALSE when timeout occurs. *)
		PROCEDURE BusyWait(): BOOLEAN;
		VAR t: Kernel.MilliTimer;
		BEGIN
			Kernel.SetTimer(t, 2); (* timeout is 2 ms *)
			WHILE ~Kernel.Expired(t) DO
				IF ~(15 IN SYSTEM.VAL(SET, PCC.RegRead16(PCCRegAC97StatusAddress))) THEN
					RETURN TRUE;
				END;
			END;
			RETURN FALSE;
		END BusyWait;

		PROCEDURE Reset;
		BEGIN
			RegWrite16(ACCRegReset, 0);
			RegWrite16(ACCRegRecordSelect, 0505H); (* select stereo mix (also works for mono) *)
		END Reset;

	END AC97Control;

	(** MixerChannel object, allows to set and get volume information *)
	MixerChannel* = OBJECT(SoundDevices. MixerChannel)
		VAR
			drv: Driver; (*  driver object *)
			name: NameStr; (* name of mixer channel *)
			desc: DescStr; (* description of mixer channel *)
			regVol: LONGINT; (* volume register offset *)
			inverted: BOOLEAN; (* is maximum register value = maximum volume or inverted? *)
			volBits: LONGINT; (* number of bits for volume range *)
			volume: LONGINT; (* current volume *)
			mute: BOOLEAN; (* current mute state *)

		(* Constructor *)
		PROCEDURE &Constr*(drv: Driver; regVol: LONGINT; inverted, mute: BOOLEAN; name: NameStr; desc: DescStr);
		VAR tmpVol: LONGINT;
		BEGIN
			SELF.drv := drv;
			SELF.regVol := regVol;
			SELF.inverted := inverted;
			SELF.name := name;
			SELF.desc := desc;

			(* Get number of volume bits *)
			drv.ACC.RegWrite16(regVol, 803FH); (* set first 6 bits and mute bit *)
			tmpVol := drv.ACC.RegRead16(regVol); (* read back volume value *)
			SELF.volBits := 0;
			WHILE ODD(tmpVol) DO
				tmpVol := LSH(tmpVol, -1);
				INC(SELF.volBits);
			END;

			SELF.mute := mute; (* set mute state of channel *)
			SetVolume(128); (* set volume to middle position *)
		END Constr;

		(* Call mixer channel listeners *)
		PROCEDURE CallListeners;
		VAR item: ListMixerChangedProc;
		BEGIN
			item := drv.mixerChannelListeners;
			WHILE item # NIL DO
				item.proc(SELF);
				item := item.next;
			END;
		END CallListeners;

		(** Return the name (as UTF-8 Unicode) of this channel *)
		PROCEDURE GetName*(VAR name : ARRAY OF CHAR);
		BEGIN
			COPY(SELF.name, name);
		END GetName;

		(** Return the description string (as UTF-8 Unicode) of this channel *)
		PROCEDURE GetDesc*(VAR desc : ARRAY OF CHAR);
		BEGIN
			COPY(SELF.desc, desc);
		END GetDesc;

		(** Set the volume of the channel (0-255) *)
		PROCEDURE SetVolume*(volume : LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT((volume >= 0) & (volume <= 255));
			SELF.volume := volume;
			IF inverted THEN
				volume := 255 - volume;
			END;
			volume := LSH(volume, volBits - 8); (* adapt volume resolution *)
			volume := volume + LSH(volume, 8); (* set L and R (also works for mono) *)
			IF SELF.mute THEN
				volume := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, volume) + {15});
			END;
			drv.ACC.RegWrite16(regVol, volume);
			CallListeners;
		END SetVolume;

		(** Get the volume of the channel (0-255) *)
		PROCEDURE GetVolume*() : LONGINT;
		BEGIN
			RETURN SELF.volume;
		END GetVolume;

		(** Mute or unmute the channel *)
		PROCEDURE SetMute*(mute : BOOLEAN);
		VAR volume: SET;
		BEGIN {EXCLUSIVE}
			SELF.mute := mute;
			volume := SYSTEM.VAL(SET, drv.ACC.RegRead16(regVol));
			IF mute THEN
				volume := volume + {15};
			ELSE
				volume := volume - {15};
			END;
			drv.ACC.RegWrite16(regVol, SYSTEM.VAL(LONGINT, volume));
			CallListeners;
		END SetMute;

		(** Get the mute-state of the channel *)
		PROCEDURE GetIsMute*() : BOOLEAN;
		BEGIN
			RETURN SELF.mute;
		END GetIsMute;

	END MixerChannel;


	(** Channel object *)
	Channel* = OBJECT(SoundDevices.Channel)
		VAR
			drv: Driver; (* driver object *)
			bufferListenerCaller: BufferListenerCaller; (* buffer listener call object *)
			buffFirst, buffLast: ListBuffer; (* buffer queue (FIFO) *)
			buffFirstPos: LONGINT; (* position in currently used buffer *)
			playRecBuff: PlayRecBuffer; (* ring buffer for playing/recording *)
			playRecBuffSize: LONGINT; (* size of ring buffer for playing/recording *)
			playRecBuffPhys: LONGINT; (* physical address of ring buffer *)
			playRecBuffPos: LONGINT; (* position marker in ring buffer in bytes *)
			samplePosition: LONGINT; (* current absolute position in samples *)
			bytesPerSampleExp: LONGINT; (* bytesPerSampleExp^2 = bytes per sample *)
			running: BOOLEAN; (* is channel currently playing/recording? *)
			closed: BOOLEAN; (* has channel been closed? *)
			volume: LONGINT; (* current volume *)

		(* Constructor *)
		PROCEDURE &Constr*(drv: Driver);
		BEGIN
			SELF.drv := drv;
			buffFirst := NIL;
			buffLast := NIL;
			buffFirstPos := 0;
			samplePosition := 0;
			running := FALSE;
			closed := FALSE;
			volume := 0;
			NEW(bufferListenerCaller);
		END Constr;

		(** Register a delegate that handles reuse / processing of buffers.
			Only one Buffer listener can be registered per channel.
		*)
		PROCEDURE RegisterBufferListener*(bufferListener : BufferListener);
		BEGIN {EXCLUSIVE}
			ASSERT(~closed);
			bufferListenerCaller.RegisterBufferListener(bufferListener);
			IF Logging THEN
				IF bufferListener = NIL THEN
					KernelLog.String("YMF754 - BufferListener unregistered");
				ELSE
					KernelLog.String("YMF754 - BufferListener registered");
				END;
				KernelLog.Ln;
			END;
		END RegisterBufferListener;

		(** Queue another buffer for playing / recording *)
		PROCEDURE QueueBuffer*(x : Buffer);
		VAR buffItem: ListBuffer;
		BEGIN {EXCLUSIVE}
			ASSERT(~closed);
			ASSERT(x # NIL);
			ASSERT(x.data # NIL);
			ASSERT(x.len MOD LSH(1, bytesPerSampleExp) = 0); (* Buffer length must be sample aligned *)
			NEW(buffItem);
			buffItem.buff := x;
			buffItem.next := NIL;
			IF buffFirst = NIL THEN
				buffFirst := buffItem;
			ELSE
				buffLast.next := buffItem;
			END;
			buffLast := buffItem;
		END QueueBuffer;

		(* Removes current buffer from queue and returns it to listener (if registered) - queue must not be empty! *)
		PROCEDURE ReturnCurrentBuffer;
		BEGIN
			bufferListenerCaller.ReturnBuffer(buffFirst.buff);
			buffFirst := buffFirst.next;
			buffFirstPos := 0;
		END ReturnCurrentBuffer;

		(* Prepare data - this procedure is called for each channel every time PCI Audio generates an interrupt *)
		PROCEDURE PrepareData;
		BEGIN
			HALT(99); (* abstract *)
		END PrepareData;

		(* Activate channel - init banks and start playback/record *)
		PROCEDURE Activate;
		BEGIN
			HALT(99); (* abstract *)
		END Activate;

		(* Deactivate channel - stop playback/record *)
		PROCEDURE Deactivate;
		BEGIN
			HALT(99); (* abstract *)
		END Deactivate;

		(* Set volume for play or record channel (0-255) *)
		PROCEDURE SetPlayRecVol(volume: LONGINT);
		BEGIN
			HALT(99); (* abstract *)
		END SetPlayRecVol;

		(** Set the current volume of the channel (8.8 bit fixed point value) *)
		PROCEDURE SetVolume*(volume : LONGINT);
		BEGIN {EXCLUSIVE}
			ASSERT(~closed);
			ASSERT(volume >= 0);
			SELF.volume := volume;
			IF volume > 255 THEN (* 1.0 fix point value is maximum volume *)
				volume := 255;
			END;
			SetPlayRecVol(volume);
		END SetVolume;

		(** Get the current volume of the channel (8.8 bit fixed point value) *)
		PROCEDURE GetVolume*() : LONGINT;
		BEGIN
			ASSERT(~closed);
			RETURN SELF.volume;
		END GetVolume;

		(** GetPosition returns the current position in samples. MAY CHANGE TO HUGEINT*)
		PROCEDURE GetPosition*() : LONGINT;
		BEGIN
			ASSERT(~closed);
			RETURN samplePosition;
		END GetPosition;

		(** Start playing / recording *)
		PROCEDURE Start*;
		BEGIN {EXCLUSIVE}
			ASSERT(~closed);
			IF ~running THEN
				Activate;
				running := TRUE;
			END;
		END Start;

		(** Pause playing / recording, no buffers are returned *)
		PROCEDURE Pause*;
		BEGIN {EXCLUSIVE}
			ASSERT(~closed);
			PauseChannel;
		END Pause;

		(** Stop the playing / recording and return all buffers *)
		PROCEDURE Stop*;
		BEGIN {EXCLUSIVE}
			ASSERT(~closed);
			StopChannel;
		END Stop;

		(* Used to prevent recursive calls of EXCLUSIVE sections *)
		PROCEDURE PauseChannel;
		BEGIN
			IF running THEN
				Deactivate;
				running := FALSE;
			END;
		END PauseChannel;

		(* Used to prevent recursive calls of EXCLUSIVE sections *)
		PROCEDURE StopChannel;
		BEGIN
			PauseChannel;
			(* Return all buffers *)
			WHILE buffFirst # NIL DO
				ReturnCurrentBuffer;
			END;
			samplePosition := 0;
		END StopChannel;

	END Channel;

	(** Player channel *)
	PlayerChannel* = OBJECT(Channel)
		VAR
			playSlotPair: LONGINT; (* play slot pair this channel is using *)
			playSlot: ARRAY 2 OF POINTER TO PlaySlotCtrlData; (* play slot control data *)
			playSlotPhys: ARRAY 2 OF LONGINT; (* physical address *)
			nofSubCh: LONGINT; (* number of sub channels *)
			silentData: CHAR; (* silent data byte *)

		(* Constructor *)
		PROCEDURE &ConstrPlay*(drv: Driver; sRate, sRes, nofSubCh, playslotpair: LONGINT);
		VAR
			i, j: LONGINT;
			pgDelta, lpfK, lpfQ: LONGINT;
		BEGIN
			Constr(drv); (* call parent constructor *)
			SELF.bytesPerSampleExp := nofSubCh - sRes;
			SELF.nofSubCh := nofSubCh;
			SELF.playSlotPair := playslotpair;
			INCL(drv.playSlotPairsUsed, playSlotPair); (* occupy this channels play slot pair *)
			drv.PlayerChannelListAdd(SELF); (* add to list of currently active player channels *)
			silentData := CHR(LSH(sRes, 7)); (* calculate silent data byte *)

			(* Allocate buffer memory / init buffer *)
			playRecBuffSize := sRate * nofSubCh * (2-sRes) * BufferSizeMS DIV 1000; (* calculate buffer size *)
			NEW(playRecBuff, playRecBuffSize);
			playRecBuffPhys := GetPhysicalAdr(ADDRESSOF(playRecBuff^), playRecBuffSize);
			playRecBuffPos := 0;

			(* Calculate pgDelta *)
			pgDelta := LSH(LSH(sRate, 15) DIV 48000, 13); (* sRate * 2^28 / 48000 *)

			(* Calculate lpfK and lpfQ *)
			i := 0;
			WHILE sRate > NativeFreqTab[i].hz DO
				INC(i); (* "i" can't go above upper array bound because sRate is asserted to be <= 48000 *)
			END;
			lpfK := NativeFreqTab[i].valLpfK;
			lpfQ := NativeFreqTab[i].valLpfQ;

			(* Allocate control data memory and init banks *)
			FOR i := 0 TO nofSubCh - 1 DO
				NEW(playSlot[i]);
				playSlotPhys[i] := GetPhysicalAdr(ADDRESSOF(playSlot[i]^), SIZEOF(PlaySlotCtrlData));
				FOR j := 0 TO NofBanks - 1 DO
					playSlot[i][j].format := i + LSH(nofSubCh-1, 16) + LSH(sRes, 31);
					playSlot[i][j].loopDefault := 0;
					playSlot[i][j].pgBase := playRecBuffPhys;
					playSlot[i][j].pgLoop := 0;
					playSlot[i][j].pgLoopEnd := LSH(playRecBuffSize, -bytesPerSampleExp);
					playSlot[i][j].pgLoopFrac := 0;
					playSlot[i][j].pgDeltaEnd := pgDelta;
					playSlot[i][j].lpfKEnd := lpfK;
					playSlot[i][j].egGainEnd := 0;
					playSlot[i][j].lchGainEnd := 40000000H;
					playSlot[i][j].rchGainEnd := 40000000H;
					playSlot[i][j].effect1GainEnd := 0;
					playSlot[i][j].effect2GainEnd := 0;
					playSlot[i][j].effect3GainEnd := 0;
					playSlot[i][j].lpfQ := lpfQ;
					playSlot[i][j].status := 0;
					playSlot[i][j].numOfFrames := 0;
					playSlot[i][j].loopCount := 0;
					playSlot[i][j].pgStart := 0;
					playSlot[i][j].pgStartFrac := 0;
					playSlot[i][j].pgDelta := pgDelta;
					playSlot[i][j].lpfK := lpfK;
					playSlot[i][j].egGain := 0;
					playSlot[i][j].lchGain := 40000000H;
					playSlot[i][j].rchGain := 40000000H;
					playSlot[i][j].effect1Gain := 0;
					playSlot[i][j].effect2Gain := 0;
					playSlot[i][j].effect3Gain := 0;
					playSlot[i][j].lpfD1 := 0;
					playSlot[i][j].lpfD2 := 0;
				END;
			END;

			SetVolume(255); (* set initial volume to maximum *)

		END ConstrPlay;

		(* Prepare data - this procedure is called for each channel every time PCI Audio generates an interrupt *)
		PROCEDURE PrepareData;
		VAR
			curBuffPos: LONGINT; (* current recording position in ring buffer in bytes *)
			copySize: LONGINT; (* size of next block to copy in bytes *)
		BEGIN
			IF ~running THEN RETURN END;
			curBuffPos := LSH(playSlot[0][drv.inactiveBank].pgStart, bytesPerSampleExp);
			WHILE (buffFirst # NIL) & (playRecBuffPos # curBuffPos) DO
				(* Calculate copy size *)
				copySize := curBuffPos - playRecBuffPos;
				IF copySize < 0 THEN
					copySize := playRecBuffSize - playRecBuffPos;
				END;
				copySize := Strings.Min(copySize, buffFirst.buff.len - buffFirstPos);
				(* Copy *)
				SYSTEM.MOVE(
					ADDRESSOF(buffFirst.buff.data^) + buffFirstPos,
					ADDRESSOF(playRecBuff^) + playRecBuffPos,
					copySize);
				INC(playRecBuffPos, copySize);
				INC(buffFirstPos, copySize);
				INC(samplePosition, LSH(copySize, -bytesPerSampleExp));
				(* Handle special cases *)
				IF playRecBuffPos = playRecBuffSize THEN
					playRecBuffPos := 0;
				END;
				IF buffFirstPos = buffFirst.buff.len THEN
					ReturnCurrentBuffer;
				END;
			END;
			(* Output silent data if no PCM data is available *)
			WHILE playRecBuffPos # curBuffPos DO
				playRecBuff[playRecBuffPos] := silentData;
				playRecBuffPos := (playRecBuffPos + 1) MOD playRecBuffSize;
			END;
		END PrepareData;

		(* Init banks and start playback/record *)
		PROCEDURE Activate;
		VAR copySize, i, j: LONGINT;
		BEGIN
			IF Logging THEN
				KernelLog.String("YMF754 - Starting PlayerChannel number ");
				KernelLog.Int(playSlotPair, 0);
				KernelLog.Ln;
			END;
			(* Init buffer *)
			playRecBuffPos := 0;
			WHILE (buffFirst # NIL) & (playRecBuffPos < playRecBuffSize) DO
				(* Calculate copy size *)
				copySize := Strings.Min(buffFirst.buff.len, playRecBuffSize - playRecBuffPos);
				(* Copy *)
				SYSTEM.MOVE(
					ADDRESSOF(buffFirst.buff.data^),
					ADDRESSOF(playRecBuff^) + playRecBuffPos,
					copySize);
				INC(playRecBuffPos, copySize);
				INC(buffFirstPos, copySize);
				INC(samplePosition, LSH(copySize, -bytesPerSampleExp));
				(* Handle special cases *)
				IF buffFirstPos = buffFirst.buff.len THEN
					ReturnCurrentBuffer;
				END;
			END;
			(* Output silent data if no PCM data is available *)
			FOR i := playRecBuffPos TO playRecBuffSize - 1 DO
				playRecBuff[i] := silentData;
			END;
			(* Init banks and start *)
 			FOR i := 0 TO nofSubCh - 1 DO
				FOR j := 0 TO NofBanks - 1 DO
					playSlot[i][j].pgStart := 0;
					playSlot[i][j].pgStartFrac := 0;
				END;
				drv.PCD.playSlotBase[2*playSlotPair+i] := playSlotPhys[i];
			END;
		END Activate;

		(* Stop playback/record *)
		PROCEDURE Deactivate;
		VAR i: LONGINT;
		BEGIN
			IF Logging THEN
				KernelLog.String("YMF754 - Stopping/Pausing PlayerChannel number ");
				KernelLog.Int(playSlotPair, 0);
				KernelLog.Ln;
			END;
			FOR i := 0 TO nofSubCh - 1 DO
				drv.PCD.playSlotBase[2*playSlotPair+i] := 0;
			END;
		END Deactivate;

		(* Set volume for play or record channel (0-255) *)
		PROCEDURE SetPlayRecVol(volume: LONGINT);
		VAR i, j: LONGINT;
		BEGIN
			volume := LSH(volume, 22);
			FOR i := 0 TO nofSubCh - 1 DO
				IF running THEN
					playSlot[i][drv.inactiveBank].egGainEnd := volume;
				ELSE
					FOR j := 0 TO NofBanks - 1 DO
						playSlot[i][j].egGainEnd := volume;
						playSlot[i][j].egGain := volume;
					END;
				END;
			END;
		END SetPlayRecVol;

		(** Get kind of channel *)
		PROCEDURE GetChannelKind*(): LONGINT;
		BEGIN
			ASSERT(~closed);
			RETURN SoundDevices.ChannelPlay;
		END GetChannelKind;

		(** Close the channel, the driver may release any ressources reserved for it.
		The object is still there but can never be opened again *)
		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			ASSERT(~closed);
			IF Logging THEN
				KernelLog.String("YMF754 - Closing PlayerChannel number ");
				KernelLog.Int(playSlotPair, 0);
				KernelLog.Ln;
			END;
			StopChannel; (* stop playing *)
			bufferListenerCaller.Close; (* close buffer listener caller object *)
			drv.PlayerChannelListRemove(SELF); (* remove from list uf currently active player channels *)
			EXCL(drv.playSlotPairsUsed, playSlotPair); (* free used play slot pair *)
			closed := TRUE;
			IF Logging THEN
				KernelLog.String("YMF754 - Closing done"); KernelLog.Ln;
			END;
		END Close;

	END PlayerChannel;

	(** Recoder channel *)
	RecordChannel* = OBJECT(Channel)
		VAR
			recSlot: POINTER TO RecSlotCtrlData; (* record slot control data *)
			recSlotPhys: LONGINT; (* physical address of it *)

		(* Constructor *)
		PROCEDURE &ConstrRec*(drv: Driver; sRate, sRes, nofSubCh: LONGINT);
		VAR i: LONGINT;
		BEGIN
			Constr(drv); (* call parent constructor *)
			bytesPerSampleExp := nofSubCh - sRes;

			(* Allocate buffer memory / init buffer *)
			playRecBuffSize := NativeFreqTab[sRate].hz * nofSubCh * (2-sRes) * BufferSizeMS DIV 1000; (* calculate buffer size *)
			NEW(playRecBuff, playRecBuffSize);
			playRecBuffPhys := GetPhysicalAdr(ADDRESSOF(playRecBuff^), playRecBuffSize);
			playRecBuffPos := 0;

			(* Allocate control data memory *)
			NEW(recSlot);
			recSlotPhys := GetPhysicalAdr(ADDRESSOF(recSlot^), SIZEOF(RecSlotCtrlData));

			(* Register control data memory *)
			drv.PCC.RegWrite32(PCCRegRecCtrlBase, recSlotPhys);

			(* Set channel config *)
			drv.PCC.RegWrite16(PCCRegADCSlotSamplingRate, NativeFreqTab[sRate].valRec);
			drv.PCC.RegWrite16(PCCRegADCSlotFormat, LSH(nofSubCh-1, 1) + sRes);

			(* Init ADC slot *)
			FOR i := 0 TO NofBanks - 1 DO
				recSlot.recSlotADC[i].pgBase := playRecBuffPhys;
				recSlot.recSlotADC[i].pgLoopEndAdr := playRecBuffSize;
				recSlot.recSlotADC[i].pgStartAdr := 0;
				recSlot.recSlotADC[i].numOfLoops := 0;
			END;

			SetVolume(255); (* set initial volume to maximum *)

		END ConstrRec;

		(* Prepare data - this procedure is called for each channel every time PCI Audio generates an interrupt *)
		PROCEDURE PrepareData;
		VAR
			curBuffPos: LONGINT; (* current recording position in ring buffer in bytes *)
			copySize: LONGINT; (* size of next block to copy in bytes *)
		BEGIN
			IF ~running THEN RETURN END;
			curBuffPos := recSlot.recSlotADC[drv.inactiveBank].pgStartAdr;
			WHILE (buffFirst # NIL) & (playRecBuffPos # curBuffPos) DO
				(* Calculate copy size *)
				copySize := curBuffPos - playRecBuffPos;
				IF copySize < 0 THEN
					copySize := playRecBuffSize - playRecBuffPos;
				END;
				copySize := Strings.Min(copySize, buffFirst.buff.len - buffFirstPos);
				(* Copy *)
				SYSTEM.MOVE(
					ADDRESSOF(playRecBuff^) + playRecBuffPos,
					ADDRESSOF(buffFirst.buff.data^) + buffFirstPos,
					copySize);
				INC(playRecBuffPos, copySize);
				INC(buffFirstPos, copySize);
				INC(samplePosition, LSH(copySize, -bytesPerSampleExp));
				(* Handle special cases *)
				IF playRecBuffPos = playRecBuffSize THEN
					playRecBuffPos := 0;
				END;
				IF buffFirstPos = buffFirst.buff.len THEN
					ReturnCurrentBuffer;
				END;
			END;
		END PrepareData;

		(* Init banks and start playback/record *)
		PROCEDURE Activate;
		VAR i: LONGINT;
		BEGIN
			IF Logging THEN
				KernelLog.String("YMF754 - Starting RecordChannel"); KernelLog.Ln;
			END;
			FOR i := 0 TO NofBanks - 1 DO
				recSlot.recSlotADC[i].pgStartAdr := 0;
			END;
			drv.PCC.RegWrite32(PCCRegMapOfRec, 2); (* activate ADC slot *)
		END Activate;

		(* Stop playback/record *)
		PROCEDURE Deactivate;
		BEGIN
			IF Logging THEN
				KernelLog.String("YMF754 - Stopping/Pausing RecordChannel"); KernelLog.Ln;
			END;
			drv.PCC.RegWrite32(PCCRegMapOfRec, 0); (* deactivate ADC slot *)
			playRecBuffPos := 0;
		END Deactivate;

		(* Set volume for play or record channel (0-255) *)
		PROCEDURE SetPlayRecVol(volume: LONGINT);
		BEGIN
			volume := LSH(volume, 6);
			drv.PCC.RegWrite32(PCCRegVolADCIn, volume + LSH(volume, 16));
		END SetPlayRecVol;

		(** Get kind of channel *)
		PROCEDURE GetChannelKind*(): LONGINT;
		BEGIN
			ASSERT(~closed);
			RETURN SoundDevices.ChannelRecord;
		END GetChannelKind;

		(** Close the channel, the driver may release any ressources reserved for it.
		The object is still there but can never be opened again *)
		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			ASSERT(~closed);
			IF Logging THEN
				KernelLog.String("YMF754 - Closing RecordChannel"); KernelLog.Ln;
			END;
			StopChannel; (* stop recording *)
			bufferListenerCaller.Close; (* close buffer listener caller object *)
			SetPlayRecVol(0); (* mute ADC slot *)
			drv.recSlot := NIL; (* free record slot *)
			closed := TRUE;
			IF Logging THEN
				KernelLog.String("YMF754 - Closing done"); KernelLog.Ln;
			END;
		END Close;

	END RecordChannel;

	(** Driver object *)
	Driver* = OBJECT (SoundDevices.Driver)
		VAR
			base: ADDRESS; (* virtual PCI Audio register base address *)
			irq: LONGINT; (* IRQ number *)
			ACC: AC97Control; (* AC97 controller object *)
			PCC: PCIAudioControl; (* PCI Audio controller object *)
			PCD: POINTER TO PlayCtrlDataTable; (* PCI Audio play control data table *)
			mixerChannels: ARRAY NofMixerChannels OF MixerChannel; (* array of mixer channels *)
			mixerChannelListeners: ListMixerChangedProc; (* list of mixer channel listeners *)
			playChannels: ListPlayerChannel; (* list of currently active player channels *)
			playSlotPairsUsed: SET; (* set of currently used PlaySlotPairs *)
			recSlot: RecordChannel; (* record channel currently using record slot *)
			inactiveBank: LONGINT; (* bank that is currently not used by PCI Audio *)

		(* Constructor *)
		PROCEDURE &Constr*(name: ARRAY OF CHAR; physbase, irq: LONGINT; CntrlInst1E: BOOLEAN);
		VAR
			i, res: LONGINT;
			PCDbase: LONGINT; (* physical base address of PCI Audio play control data table *)
		BEGIN
			SELF.irq := irq;

			SELF.SetName(name);
			SELF.desc := PluginDescPrefix;
			Strings.Append(SELF.desc, name);

			(* Map base address *)
			Machine.MapPhysical(physbase, 8000H (* 32KB *), base);
			ASSERT(base # Machine.NilAdr);

			IF Logging THEN
				KernelLog.String("  Initializing driver object:"); KernelLog.Ln;
				KernelLog.String("    Device name: "); KernelLog.String(name); KernelLog.Ln;
				KernelLog.String("    Physical base address: "); KernelLog.Hex(physbase, 0); KernelLog.Char("h"); KernelLog.Ln;
				KernelLog.String("    Mapped base address: "); KernelLog.Hex(base, 0); KernelLog.Char("h"); KernelLog.Ln;
				KernelLog.String("    Mapped space: 32KB"); KernelLog.Ln;
				KernelLog.String("    Hardware interrupt (IRQ): "); KernelLog.Int(irq, 0); KernelLog.Ln;
			END;

			(* Create controller register objects *)
			NEW(PCC, base, CntrlInst1E);
			NEW(ACC, PCC);

			(* Initialize PCI Audio *)
			PCC.Initialize;

			(* Reset AC97 controller *)
			ACC.Reset;

			(* Init used slots and channels *)
			playChannels := NIL;
			playSlotPairsUsed := {};
			recSlot := NIL;
			inactiveBank := 0;

			(* Init mixer channel listener list *)
			mixerChannelListeners := NIL;

			(* Create mixer channel objects *)
			NEW(mixerChannels[0], SELF, ACCRegVolMasterOut, TRUE, FALSE, "MasterOut", "Master output mixer channel");
			NEW(mixerChannels[1], SELF, ACCRegRecordGain, FALSE, FALSE, "MasterIn", "Master input mixer channel");
			NEW(mixerChannels[2], SELF, ACCRegVolLineIn, TRUE, TRUE, "LineIn", "LineIn mixer channel");
			NEW(mixerChannels[3], SELF, ACCRegVolPCM, TRUE, FALSE, "PCM", "PCM mixer channel");
			NEW(mixerChannels[4], SELF, ACCRegVolCD, TRUE, TRUE, "CD", "CD mixer channel");
			NEW(mixerChannels[5], SELF, ACCRegVolMic, TRUE, TRUE, "Mic", "Microphone mixer channel");

			(* Allocate DMA memory for PCI Audio control data table *)
			NEW(PCD);
			PCDbase := GetPhysicalAdr(ADDRESSOF(PCD^), SIZEOF(PlayCtrlDataTable));

			(* Initialize PCI Audio play control data *)
			PCD.numOfPlay := NofPlaySlots;
			FOR i := 0 TO NofPlaySlots - 1 DO
				PCD.playSlotBase[i] := 0;
			END;
			PCC.RegWrite32(PCCRegPlayCtrlBase, PCDbase);

			ASSERT((irq >= 1) & (irq <= 15));
			(* Install Objects interrupt handler *)
			Objects.InstallHandler(HandleInterrupt, Machine.IRQ0+irq);

			(* Register in SoundDevices *)
			SoundDevices.devices.Add(SELF, res);
			ASSERT(res = Plugins.Ok);

			(* Update table of all active sound drivers *)
			SoundDevices.devices.GetAll(DriverTab);

			IF Logging THEN
				KernelLog.String("  Initializing finished."); KernelLog.Ln;
			END;

		END Constr;

		(** Finalizer *)
		PROCEDURE Finalize*;
		VAR
			item: ListPlayerChannel;
		BEGIN
			IF Logging THEN
				KernelLog.String("  Finalizing driver object:"); KernelLog.Ln;
				KernelLog.String("    Device name: "); KernelLog.String(name); KernelLog.Ln;
				KernelLog.String("    Mapped base address: "); KernelLog.Hex(base, 0); KernelLog.Char("h"); KernelLog.Ln;
				KernelLog.String("    Hardware interrupt (IRQ): "); KernelLog.Int(irq, 0); KernelLog.Ln;
			END;

			(* Close all channels *)
			item := playChannels;
			WHILE item # NIL DO
				item.channel.Close;
				item := item.next;
			END;
			IF recSlot # NIL THEN
				recSlot.Close;
			END;

			(* Reset AC97 controller *)
			ACC.Reset;

			(* Uninitialize PCI Audio *)
			PCC.UnInitialize;

			(* Unmap base address *)
			Machine.UnmapPhysical(base, 8000H (* 32KB *));

			(* Remove plugin *)
			SoundDevices.devices.Remove(SELF);

			(* Update table of all active sound drivers *)
			SoundDevices.devices.GetAll(DriverTab);

			(* Remove Objects interrupt handler *)
			Objects.RemoveHandler(HandleInterrupt, Machine.IRQ0+irq);

			IF Logging THEN
				KernelLog.String("  Finalizing finished."); KernelLog.Ln;
			END;

		END Finalize;

		(* Interrupt handler *)
		PROCEDURE HandleInterrupt;
		VAR
			item: ListPlayerChannel;
			regMode: SET;
		BEGIN
			(* Check if PCI Audio generated the interrupt *)
			IF ~(31 IN SYSTEM.VAL(SET, PCC.RegRead32(PCCRegStatus))) THEN RETURN END;

			(* Handle PCI Audio interrupt *)
			PCC.RegWrite32(PCCRegStatus, SYSTEM.VAL(LONGINT, {31})); (* deassert INTA# *)
			inactiveBank := PCC.RegRead32(PCCRegControlSelect) MOD 2; (* get inactive bank *)

			(* Prepare data in channels *)
			item := playChannels;
			WHILE item # NIL DO
					item.channel.PrepareData;
					item := item.next;
			END;
			IF recSlot # NIL THEN
				recSlot.PrepareData;
			END;

			IF (playChannels = NIL) & (recSlot = NIL) THEN
				(* Stop PCI Audio operation *)
				PCC.RegWrite32(PCCRegMode, 0);
			ELSE
				(* Notify PCI Audio that interrupt has been finished *)
				regMode := SYSTEM.VAL(SET, PCC.RegRead32(PCCRegMode));
				INCL(regMode, 1);
				PCC.RegWrite32(PCCRegMode, SYSTEM.VAL(LONGINT, regMode));
			END;
		END HandleInterrupt;

		(** Sound device routines *)
		PROCEDURE Init*;
			(* Not used *)
		END Init;

		PROCEDURE Enable*;
			(* Not used *)
		END Enable;

		PROCEDURE Disable*;
			(* Not used *)
		END Disable;

		(** Capabilities *)
		PROCEDURE NofNativeFrequencies*():LONGINT;
		BEGIN
			RETURN NofNativeFreq;
		END NofNativeFrequencies;

		PROCEDURE GetNativeFrequeny*(nr : LONGINT):LONGINT;
		BEGIN
			RETURN NativeFreqTab[nr].hz;
		END GetNativeFrequeny;

		PROCEDURE NofSamplingResolutions*():LONGINT;
		BEGIN
			RETURN 2; (* 16 Bit and 8 Bit *)
		END NofSamplingResolutions;

		PROCEDURE GetSamplingResolution*(nr : LONGINT):LONGINT;
		BEGIN
			ASSERT((nr >= 0) & (nr < 2));
			IF nr = 0 THEN
				RETURN 16;
			ELSE
				RETURN 8;
			END;
		END GetSamplingResolution;

		(** How many different sub channel settings are possible *)
		PROCEDURE NofSubChannelSettings*():LONGINT;
		BEGIN
			RETURN 2; (* mono and stereo *)
		END NofSubChannelSettings;

		(** Get sub channel setting nr. *)
		PROCEDURE GetSubChannelSetting*(nr : LONGINT):LONGINT;
		BEGIN
			ASSERT((nr >= 0) & (nr < 2));
			IF nr = 0 THEN
				RETURN 1; (* mono *)
			ELSE
				RETURN 2; (* stereo *)
			END;
		END GetSubChannelSetting;

		(** How many different wave formats are possible *)
		PROCEDURE NofWaveFormats*():LONGINT;
		BEGIN
			RETURN 1; (* only PCM *)
		END NofWaveFormats;

		(** Get wave format nr. *)
		PROCEDURE GetWaveFormat*(nr : LONGINT):LONGINT;
		BEGIN
			ASSERT(nr = 0);
			RETURN SoundDevices.FormatPCM; (* PCM *)
		END GetWaveFormat;

		(** Playing *)
		(** Open a new channel for playing
			The maximum number of playing channels opened at the same time is 32.
			res is the result code (see constants in SoundDevices)
			channel is the resulting Play channel, NIL if an error occured.
			samplingRate is the desired samplingRate ( IMPORTANT: all values from 8000 to 48000 are allowed ! )
			samplingResolution = 8/16 Bit
			nofSubChannes = 1 for Mono, 2 for Stereo
			format is the wave format
		*)
		PROCEDURE OpenPlayChannel*(VAR channel : SoundDevices.Channel; samplingRate, samplingResolution, nofSubChannels, format : LONGINT; VAR res : LONGINT);
		VAR
			playSlotPair: LONGINT;
			playChannel: PlayerChannel;
		BEGIN {EXCLUSIVE}
			(* Searching for free play slot pair *)
			IF Logging THEN
				KernelLog.String("YMF754 - Opening PlayerChannel");
			END;
			playSlotPair := 0;
			WHILE (playSlotPair < NofPlaySlotPairs) & (playSlotPair IN playSlotPairsUsed) DO
				INC(playSlotPair);
			END;
			IF playSlotPair = NofPlaySlotPairs THEN
				IF Logging THEN
					KernelLog.String(" - rejected: no more channels available"); KernelLog.Ln;
				END;
				res := SoundDevices.ResNoMoreChannels;
				channel := NIL;
				RETURN;
			END;
			(* Free play slot pair found *)
			CheckChannelParam(FALSE, samplingRate, samplingResolution, nofSubChannels, format, res);
			IF res = SoundDevices.ResOK THEN
				NEW(playChannel, SELF, samplingRate, samplingResolution, nofSubChannels, playSlotPair);
				IF Logging THEN
					KernelLog.String(" number ");
					KernelLog.Int(playSlotPair, 0);
					KernelLog.String(" - done");
					KernelLog.Ln;
				END;
				channel := playChannel;
				StartPCIAudio;
			ELSE
				IF Logging THEN
					KernelLog.String(" - rejected: invalid parameters"); KernelLog.Ln;
				END;
				channel := NIL;
			END;
		END OpenPlayChannel;

		(** Recording *)
		(** Open a new channel for recording.
			Only one record channel can be opened at the same time!
			res is the result code (see constants in SoundDevices)
			channel is the resulting Recorder channel, NIL if an error occured.
			samplingRate is the desired samplingRate ( IMPORTANT: only native frequencies are allowed ! )
			samplingResolution = 8/16 Bit
			nofSubChannes = 1 for Mono, 2 for Stereo
			format is the wave format
		*)
		PROCEDURE OpenRecordChannel*(VAR channel : SoundDevices.Channel; samplingRate, samplingResolution, nofSubChannels, format : LONGINT; VAR res : LONGINT);
		BEGIN {EXCLUSIVE}
			IF Logging THEN
				KernelLog.String("YMF754 - Opening RecordChannel");
			END;
			(* Testing for free record slot *)
			IF recSlot # NIL THEN
				IF Logging THEN
					KernelLog.String(" - rejected: RecordChannel currently in use"); KernelLog.Ln;
				END;
				res := SoundDevices.ResNoMoreChannels;
				channel := NIL;
				RETURN;
			END;
			(* RecSlot is available *)
			CheckChannelParam(TRUE, samplingRate, samplingResolution, nofSubChannels, format, res);
			IF res = SoundDevices.ResOK THEN
				NEW(recSlot, SELF, samplingRate, samplingResolution, nofSubChannels);
				IF Logging THEN
					KernelLog.String(" - done"); KernelLog.Ln;
				END;
				channel := recSlot;
				StartPCIAudio;
			ELSE
				IF Logging THEN
					KernelLog.String(" - rejected: invalid parameters"); KernelLog.Ln;
				END;
				channel := NIL;
			END;
		END OpenRecordChannel;

		(* Start PCI Audio operation - if not already operating *)
		PROCEDURE StartPCIAudio;
		BEGIN
			IF ~ODD(PCC.RegRead32(PCCRegMode)) THEN
				(* Not operating - starting operation *)
				PCC.RegWrite32(PCCRegMode, 3);
			END;
		END StartPCIAudio;

		(* Check channel parameters and convert the values for internal use *)
		PROCEDURE CheckChannelParam(onlyNativeFreq: BOOLEAN; VAR sRate, sResolution, nofSubCh, format, res: LONGINT);
		VAR i: LONGINT;
		BEGIN
			res := SoundDevices.ResOK;

			(* Samling rate *)
			IF onlyNativeFreq THEN
				(* only native freqencies are allowed *)
				i := 0;
				WHILE (i < NofNativeFreq) & (NativeFreqTab[i].hz # sRate) DO INC(i) END;
				IF i < NofNativeFreq THEN
					sRate := i; (* corresponding array position is returned as sRate *)
				ELSE
					res := SoundDevices.ResUnsupportedFrequency;
				END;
			ELSE
				(* all frequencies in specified range are allowed *)
				IF (sRate < 8000) OR (sRate > 48000) THEN
					res := SoundDevices.ResUnsupportedFrequency;
				END;
			END;

			(* Sampling resolution *)
			IF sResolution = 16 THEN
				sResolution := 0;
			ELSIF sResolution = 8 THEN
				sResolution := 1;
			ELSE
				res := SoundDevices.ResUnsupportedSamplingRes;
			END;

			(* Sub channel setting *)
			IF (nofSubCh # 1) & (nofSubCh # 2) THEN
				res := SoundDevices.ResUnsupportedSubChannels;
			END;

			(* Format *)
			IF format # SoundDevices.FormatPCM THEN
				res := SoundDevices.ResUnsupportedFormat;
			END;
		END CheckChannelParam;

		(* Add a player channel to the list of currently active player channels - always called by the channel itself *)
		PROCEDURE PlayerChannelListAdd(channel: PlayerChannel);
		VAR item: ListPlayerChannel;
		BEGIN (* can't be exclusive because it is called by ConstrPlay() of object created in OpenPlayChannel() *)
			ASSERT(channel # NIL);
			NEW(item);
			item.channel := channel;
			item.next := playChannels;
			playChannels := item;
		END PlayerChannelListAdd;

		(* Remove a player channel from the list of currently active player channels - always called by the channel itself *)
		PROCEDURE PlayerChannelListRemove(channel: PlayerChannel);
		VAR item: ListPlayerChannel;
		BEGIN {EXCLUSIVE}
			item := playChannels;
			IF item = NIL THEN
				(* not found - empty list *)
				RETURN;
			END;
			IF item.channel = channel THEN
				(* found - remove first item *)
				playChannels := item.next;
				RETURN;
			END;
			WHILE (item.next # NIL) & (item.next.channel # channel) DO
				item := item.next;
			END;
			IF item.next # NIL THEN
				(* found - remove item *)
				item.next := item.next.next;
			END;
		END PlayerChannelListRemove;

		(** Mixer *)
		(** Register a listener for channel changes, the number of listeners is not limited.
			Listeners run in the thread of the changeing program, therefore they have to
			return control immediately after beeing called.
		*)
		PROCEDURE RegisterMixerChangeListener*(mixChangedProc : MixerChangedProc);
		VAR item: ListMixerChangedProc;
		BEGIN {EXCLUSIVE}
			ASSERT(mixChangedProc # NIL);
			NEW(item);
			item.proc := mixChangedProc;
			item.next := mixerChannelListeners;
			mixerChannelListeners := item;
			IF Logging THEN
				KernelLog.String("YMF754 - MixerChangeListener registered"); KernelLog.Ln;
			END;
		END RegisterMixerChangeListener;

		(** Unregister a previously registered listener *)
		PROCEDURE UnregisterMixerChangeListener*(mixChangedProc : MixerChangedProc);
		VAR item: ListMixerChangedProc;
		BEGIN {EXCLUSIVE}
			IF Logging THEN
				KernelLog.String("YMF754 - Unregistering MixerChangeListener");
			END;
			item := mixerChannelListeners;
			IF item = NIL THEN
				(* not found - empty list *)
				IF Logging THEN
					KernelLog.String(" - failed: no listener was registered"); KernelLog.Ln;
				END;
				RETURN;
			END;
			IF item.proc = mixChangedProc THEN
				(* found - remove first item *)
				mixerChannelListeners := item.next;
				IF Logging THEN
					KernelLog.String(" - done"); KernelLog.Ln;
				END;
				RETURN;
			END;
			WHILE (item.next # NIL) & (item.next.proc # mixChangedProc) DO
				item := item.next;
			END;
			IF item.next # NIL THEN
				(* found - remove item *)
				item.next := item.next.next;
				IF Logging THEN
					KernelLog.String(" - done"); KernelLog.Ln;
				END;
			ELSE
				IF Logging THEN
					KernelLog.String(" - failed: listener was not registered"); KernelLog.Ln;
				END;
			END;
		END UnregisterMixerChangeListener;

		(** Return channel object
			channel 0 is always present and is specified as the master output volume
			channel 1 is always present and is specified as the master input volume
			Drivers may ignore channel 0 or 1 but need to return a generic "Channel" object for these channel numbers
			GetMixerChannel returns NIL if the channelNr is invalid
		*)
		PROCEDURE GetMixerChannel*(channelNr : LONGINT; VAR channel : SoundDevices.MixerChannel);
		VAR name: NameStr;
		BEGIN
			IF (channelNr >= 0) & (channelNr < NofMixerChannels) THEN
				channel := mixerChannels[channelNr];
				IF Logging THEN
					channel.GetName(name);
					KernelLog.String("YMF754 - GetMixerChannel (");
					KernelLog.String(name);
					KernelLog.String(")");
					KernelLog.Ln;
				END;
			ELSE
				channel := NIL;
			END;
		END GetMixerChannel;

		(** Returns the number of mixer channels available, at least 2 *)
		PROCEDURE GetNofMixerChannels*() : LONGINT;
		BEGIN
			RETURN NofMixerChannels;
		END GetNofMixerChannels;

	END Driver;

(* Module variables *)

VAR
	NativeFreqTab: NativeFreqTable; (* parameter of native frequencies *)
	DriverTab: Plugins.Table; (* table of all active sound drivers *)

(** Module routines *)

(* Fill native frequencies table *)
PROCEDURE FillNativeFreqTable;
BEGIN
	NativeFreqTab[0].hz := 8000;
	NativeFreqTab[0].valRec := 24575;
	NativeFreqTab[0].valLpfK := 18B00000H;
	NativeFreqTab[0].valLpfQ := 32020000H;
	NativeFreqTab[1].hz := 11025;
	NativeFreqTab[1].valRec := 17832;
	NativeFreqTab[1].valLpfK := 20900000H;
	NativeFreqTab[1].valLpfQ := 31780000H;
	NativeFreqTab[2].hz := 16000;
	NativeFreqTab[2].valRec := 12287;
	NativeFreqTab[2].valLpfK := 2B980000H;
	NativeFreqTab[2].valLpfQ := 31380000H;
	NativeFreqTab[3].hz := 22050;
	NativeFreqTab[3].valRec := 8915;
	NativeFreqTab[3].valLpfK := 35A00000H;
	NativeFreqTab[3].valLpfQ := 31C80000H;
	NativeFreqTab[4].hz := 32000;
	NativeFreqTab[4].valRec := 6143;
	NativeFreqTab[4].valLpfK := 40000000H;
	NativeFreqTab[4].valLpfQ := 33D00000H;
	NativeFreqTab[5].hz := 44100;
	NativeFreqTab[5].valRec := 4457;
	NativeFreqTab[5].valLpfK := 40000000H;
	NativeFreqTab[5].valLpfQ := 40000000H;
	NativeFreqTab[6].hz := 48000;
	NativeFreqTab[6].valRec := 4095;
	NativeFreqTab[6].valLpfK := 40000000H;
	NativeFreqTab[6].valLpfQ := 40000000H;
END FillNativeFreqTable;

(*  Get physical address for DMA access *)
PROCEDURE GetPhysicalAdr(adr: ADDRESS; size: SIZE): Machine.Address32;
VAR physadr: Machine.Address32;
BEGIN
	(* All data must be continous in physical memory ! *)
	(* This can not be forced, but Aos seems to do it anyway. *)
	physadr := Machine.Ensure32BitAddress (Machine.PhysicalAdr(adr, size));
	ASSERT(physadr # Machine.NilAdr); (* check if it is continous in physical memory ! *)
	ASSERT(physadr MOD 4 = 0); (* must be 4 byte aligned in physical memory *)
	RETURN physadr;
END GetPhysicalAdr;

(* Scan the PCI bus for the specified card *)
PROCEDURE ScanPCI(vendor, device: LONGINT; name: Plugins.Name; CntrlInst1E: BOOLEAN);
VAR
	len, res, reg, index: LONGINT;
	bus, dev, fct: LONGINT;
	base, irq: LONGINT;
	d: Driver;
BEGIN
	index := 0;
	WHILE (index < 10) & (PCI.FindPCIDevice(device, vendor, index, bus, dev, fct) = PCI.Done) DO
		(* Get physical base address *)
		res := PCI.ReadConfigDword(bus, dev, fct, PCI.Adr0Reg, base); ASSERT(res = PCI.Done);
		ASSERT(~ODD(base)); (* memory mapped *)
		DEC(base, base MOD 16); (* zero last 4 bits *)

		(* Get IRQ number *)
		res := PCI.ReadConfigByte(bus, dev, fct, PCI.IntlReg, irq); ASSERT(res = PCI.Done);

		(* Reset AC97 link (must be done here at PCI bus level) *)
		res := PCI.ReadConfigByte(bus, dev, fct, PCIRegDS1EControl, reg); ASSERT(res = PCI.Done);
		IF ODD(reg) THEN
			DEC(reg);
			res := PCI.WriteConfigByte(bus, dev, fct, PCIRegDS1EControl, reg); ASSERT(res = PCI.Done);
		END;
		res := PCI.WriteConfigByte(bus, dev, fct, PCIRegDS1EControl, reg + 1); ASSERT(res = PCI.Done);
		res := PCI.WriteConfigByte(bus, dev, fct, PCIRegDS1EControl, reg); ASSERT(res = PCI.Done);

		(* Add digit to name *)
		len := Strings.Length(name);
		name[len] := "#";
		INC(len);
		name[len] := CHR(ORD("0") + index);
		INC(len);
		name[len] := 0X;

		(* Instanciate new driver object *)
		NEW(d, name, base, irq, CntrlInst1E);

		INC(index)
	END
END ScanPCI;

(* Initialize the driver module *)
PROCEDURE Init;
BEGIN
	FillNativeFreqTable; (* fill native frequencies table *)
	DriverTab := NIL; (* init table of active sound drivers *)

	IF Logging THEN
		KernelLog.String("Scanning for devices..."); KernelLog.Ln;
	END;

	(* Scan for Yamaha YMF724 - YMF724E *)
	ScanPCI(1073H, 0004H, "YMF724", FALSE);

	(* Scan for Yamaha YMF740 and YMF740B *)
	ScanPCI(1073H, 000AH, "YMF740", FALSE);

	(* Scan for Yamaha YMF740C *)
	ScanPCI(1073H, 000CH, "YMF740C", TRUE);

	(* Scan for Yamaha YMF724F *)
	ScanPCI(1073H, 000DH, "YMF724F", TRUE);

	(* Scan for Yamaha YMF744 *)
	ScanPCI(1073H, 0010H, "YMF744", TRUE);

	(* Scan for Yamaha YMF754 *)
	ScanPCI(1073H, 0012H, "YMF754", TRUE);

	IF Logging THEN
		KernelLog.String("Scanning finished."); KernelLog.Ln;
	END;

END Init;

PROCEDURE Install*;
	(* Init routines are called implicitly *)
END Install;

(** Called when unloading module *)
PROCEDURE Close*;
VAR
	i: LONGINT;
BEGIN
	IF Logging THEN
		KernelLog.String("Unloading driver module..."); KernelLog.Ln;
	END;

	(* Finalize all driver objects of this module *)
	IF DriverTab # NIL THEN
		FOR i := 0 TO LEN(DriverTab^) - 1 DO
			IF DriverTab[i] IS Driver THEN
				DriverTab[i](Driver).Finalize;
			END;
		END;
	END;

	IF Logging THEN
		KernelLog.String("Unloading finished."); KernelLog.Ln;
	END;
END Close;

BEGIN
	ASSERT(BufferSizeMS <= 10000);
	Modules.InstallTermHandler(Close);
	Init;
END YMF754.

Aos.Call YMF754.Install ~
System.Free YMF754 ~

Installation
add YMF754.Install to Configuration.XML, section 'Autostart' to load driver at system startup.
