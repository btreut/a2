(* Version 0.94 *)

(* AUTHOR: Christian Heinzer, heinzerc@student.ethz.ch *)
(* Based on FreeBSDs dev/sound/pci/es137x.c *)
(* The exported procedures implement those of the generic sound driver interface SoundDevices.Mod *)

MODULE EnsoniqSound;	(** AUTHOR "chh"; PURPOSE "Ensoniq PCI Sounddriver"; *)

IMPORT SYSTEM, KernelLog, PCI, Objects, Kernel, Machine, Modules, Plugins, SoundDevices;

CONST
	Trace = FALSE; (* debug output kernel log *)
	Bsize = 25600 * 3; (* size of intern soundbuffer, better > 25600*)

	(* Ensoniq registers and content *)
	Es1370RegControl = 0;
	Es1370RegStatus = 4H;
	Es1370RegSerialControl = 20H;
	Es1370RegMemPage = 0CH;
	Es1371RegCodec = 14H;
	Es1371RegLegacy = 18H;
	Es1371RegSmprate = 10H;

	Es1370RegDac1Scount = 24H;
	Es1370RegDac2Scount = 28H;
	Es1370RegAdcScount = 2CH;

	Es1371SyncRes = 4000H;
	Es1371DisSrc = 400000H;
	Es1371SrcRamBusy = 800000H;	(*Bit 23 *)

	EsSmpregDac1 = 70H;
	EsSmpregDac2 = 74H;
	EsSmpregAdc = 78H;
	EsSmpregVolAdc = 6CH;
	EsSmpregVolDac1 = 7CH;
	EsSmpregVolDac2 = 7EH;

	NumMixerChannels = 5; (* maximal number of mixerchannels *)

TYPE
	Sample = ARRAY 4 OF CHAR; (* one sample: stereo 16 Bit *)

	Bufferlist = RECORD
		content : SoundDevices.Buffer;
		next : POINTER TO Bufferlist
	END;

	Listenerlist = RECORD
		proc : SoundDevices.MixerChangedProc;
		next : POINTER TO Listenerlist
	END;

	BuffersToReturn = RECORD (* temporary saves the buffers and their listeners that aren't needed any more *)
		blistener : SoundDevices.BufferListener;
		content : SoundDevices.Buffer;
		next : POINTER TO BuffersToReturn
	END;

	(* make sure that playcopy is not in progress *)
	(* make sure QueueBuffer and ReturnAllBuffers can not run parallel *)
	BufferObj* = OBJECT
	VAR inplaycopy : BOOLEAN;
		drv : Driver;

		PROCEDURE Setinplaycopy(pc: BOOLEAN);
		BEGIN {EXCLUSIVE}
			inplaycopy := pc
		END Setinplaycopy;

		PROCEDURE ReturnAllBuffers(chan: Channel);
		BEGIN {EXCLUSIVE}
			AWAIT(inplaycopy=FALSE); (*AWAIT(~playcopy);*)
			chan.ReturnAllBuffers
		END ReturnAllBuffers;
	END BufferObj;

	MixerChannel*=OBJECT(SoundDevices.MixerChannel)
	VAR vol : LONGINT;
		muted : BOOLEAN;
		name, desc : POINTER TO ARRAY OF CHAR;
		reg : LONGINT; (* register of mixerchannel *)
		drv : Driver;

		PROCEDURE &Constr*(drv: Driver; name, desc : ARRAY OF CHAR; reg : LONGINT);
		VAR i : LONGINT;
		BEGIN
			SELF.drv := drv;
			NEW(SELF.name, LEN(name));
			FOR i := 0 TO LEN(name)-1 DO
				SELF.name^[i] := name[i]
			END;
			NEW(SELF.desc, LEN(desc));
			FOR i := 0 TO LEN(desc)-1 DO
				SELF.desc^[i] := desc[i]
			END;
			SELF.reg := reg;
			i := 0;
			WHILE (i < NumMixerChannels-1) & (SELF.drv.mixerChannels[i] # NIL) DO
				INC(i)
			END;
			SELF.drv.mixerChannels[i] := SELF
		END Constr;

		PROCEDURE SetVolume*(vol : LONGINT);
		VAR resl : LONGINT;
		BEGIN
			IF vol > 0FFH THEN SELF.vol := 0FFH END;
			IF vol < 0 THEN SELF.vol := 0 END;
			SELF.vol := vol;
			resl := 31-SELF.vol DIV 8;
			resl := resl+256*resl;
			drv.EsWrCd(reg, SYSTEM.VAL(INTEGER, resl));
			CallListener
		END SetVolume;

		PROCEDURE GetVolume*() : LONGINT;
		BEGIN
			RETURN(vol)
		END GetVolume;

		PROCEDURE GetIsMute*(): BOOLEAN;
		BEGIN
			RETURN muted
		END GetIsMute;

		PROCEDURE CallListener;
		VAR nl : POINTER TO Listenerlist;
		BEGIN
			IF drv.listenerlist # NIL THEN
				nl := drv.listenerlist;
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
			COPY (SELF.desc^, desc)
		END GetDesc;

		PROCEDURE SetMute*(muted: BOOLEAN);
		BEGIN
			IF SELF.muted # muted THEN (* change mute state *)
				IF muted THEN
					drv.EsWrCd(reg, SYSTEM.VAL(INTEGER, 8000H))
				ELSE
					SetVolume(vol)
				END;
				SELF.muted := muted;
				CallListener
			END
		END SetMute;
	END MixerChannel;

	PlayMixerChannel=OBJECT(MixerChannel)
		PROCEDURE SetVolume*(vol: LONGINT);
		VAR resl : LONGINT;
		BEGIN
			IF vol > 0FFH THEN vol := 0FFH END;
			IF vol < 0 THEN vol := 0 END;
			SELF.vol := vol;
			resl := 63-vol DIV 4;
			resl := resl+256*resl;
			drv.EsWrCd(reg, SYSTEM.VAL(INTEGER, resl)); (* Master Out *)
			CallListener
		END SetVolume;
	END PlayMixerChannel;

	RecMixerChannel=OBJECT(MixerChannel)
		PROCEDURE SetVolume*(vol: LONGINT);
		VAR resl : LONGINT;
		BEGIN
			IF vol > 0FFH THEN vol := 0FFH END;
			IF vol < 0 THEN vol := 0 END;
			SELF.vol := vol;
			resl := vol DIV 16;
			resl := resl+256*resl;
			drv.EsWrCd(reg, SYSTEM.VAL(INTEGER, resl)); (* Record Gain *)
			CallListener
		END SetVolume;
	END RecMixerChannel;

	Channel*=OBJECT(SoundDevices.Channel)
	VAR active, free: BOOLEAN;
		first, last: POINTER TO Bufferlist; (* fast access to buffers *)
		blistener : SoundDevices.BufferListener;
		vol : INTEGER;
		ratedone : LONGINT; (* for sample rate conversion *)

		pos : LONGINT; (* actual position in buffer *)
		samplingRate, samplingResolution, nofSubChannels: LONGINT;
		delta: LONGINT; (* number of bytes for one sample *)
		drv : Driver;
		pause, stop, start : BOOLEAN;
		silent, rsilent : BOOLEAN; (* is a  channel playing/recording? *)

		PROCEDURE ReturnAllBuffers;
		VAR driver : POINTER TO Bufferlist;
		BEGIN
			driver := first;
			WHILE driver#NIL DO
				drv.AddBufferToReturn(blistener, driver.content); (* triggers blistener(driver.content); *)
				driver := driver.next
			END;
			first := NIL; last := NIL
		END ReturnAllBuffers;

		PROCEDURE &Init*(drv : Driver);
		BEGIN
			SELF.drv := drv;
			pause := FALSE; stop := FALSE; start := FALSE
		END Init;

		PROCEDURE SetVolume*(vol: LONGINT);
		(* standard : 100H *)
		BEGIN
			IF vol > 0FFFFH THEN vol := 0FFFFH; END;
			IF vol < 0 THEN vol := 0; END;
			SELF.vol := SHORT(vol)
		END SetVolume;

		PROCEDURE GetVolume*() : LONGINT;
		BEGIN
			RETURN vol
		END GetVolume;

		PROCEDURE GetPosition() : LONGINT;
		BEGIN
			RETURN pos
		END GetPosition;

		PROCEDURE Pause*; (* generic pause, used by recordchannel *)
		BEGIN {EXCLUSIVE}
			active := FALSE
		END Pause;

		PROCEDURE PauseNonExclusive;
		BEGIN
			active := FALSE
		END PauseNonExclusive;

		PROCEDURE Close*;
		BEGIN
			Stop;
			free := TRUE
		END Close;

		PROCEDURE RegisterBufferListener*(blistener: SoundDevices.BufferListener);
		BEGIN
			SELF.blistener := blistener
		END RegisterBufferListener;
	END Channel;

	PlayerChannel=OBJECT(Channel)
	VAR sample, oldsample : Sample; (*both needed for linear interpolation*)

		PROCEDURE Pause*;
		BEGIN {EXCLUSIVE}
			pause := TRUE (* triggers drv.introbj.Deactivate(SELF) *)
		END Pause;

		PROCEDURE PauseNonExclusive;
		BEGIN
			drv.introbj.Deactivate(SELF)
		END PauseNonExclusive;

		PROCEDURE Stop*;
		BEGIN {EXCLUSIVE}
			stop := TRUE
		END Stop;

		PROCEDURE QueueBuffer*(buf: SoundDevices.Buffer);
		VAR bufferlist: POINTER TO Bufferlist;
		BEGIN {EXCLUSIVE}
			IF last # NIL THEN
				NEW(bufferlist);
				last.next := bufferlist;
				bufferlist.next := NIL;
				bufferlist.content := buf;
				last := bufferlist
			ELSE
				NEW(bufferlist);
				last := bufferlist;
				last.next := NIL;
				bufferlist.content := buf;
				(*I'm too lazy to read in here the very first sample*)
				sample[0] := CHR(0); sample[1] := CHR(0);
				sample[2] := CHR(0); sample[3] := CHR(0);
				(*Take the second sample next for linear interpolation*)
				ratedone := 48000-samplingRate;
				pos := 0
			END;
			IF first = NIL THEN first := bufferlist END
		END QueueBuffer;

		(* Advance by one Buffer *)
		PROCEDURE NextBuffer;
		BEGIN {EXCLUSIVE}
			IF first # NIL THEN
				IF first.next # NIL THEN
					first := first.next
				ELSE
					silent := TRUE; active := FALSE;
					DEC(drv.introbj.numplayer);
					first := NIL
				END
			END
		END NextBuffer;

		PROCEDURE Start*;
		BEGIN {EXCLUSIVE}
				start := TRUE
		END Start;

		PROCEDURE AwaitEvent;
		BEGIN {EXCLUSIVE}
			AWAIT(pause OR start OR stop)
		END AwaitEvent;

	BEGIN {ACTIVE}
		REPEAT
			AwaitEvent;
			IF pause THEN
				drv.introbj.Deactivate(SELF); pause := FALSE
			END;

			IF stop THEN
				drv.introbj.Deactivate(SELF);
				drv.bufferobj.ReturnAllBuffers(SELF);
				stop := FALSE
			END;

			IF start THEN
				IF (first#NIL) THEN (* at least one buffer is registered *)
					drv.introbj.Activate(SELF)
				END;
				start := FALSE
			END
		UNTIL 1=2
	END PlayerChannel;

	RecordChannel=OBJECT(Channel)

		PROCEDURE Stop*;
		BEGIN {EXCLUSIVE}
			PauseNonExclusive;
			drv.introbj.WaitNoRec;(*AWAIT(~reccopy);*)
			drv.bufferobj.ReturnAllBuffers(SELF)
		END Stop;

		PROCEDURE QueueBuffer*(buf: SoundDevices.Buffer);
		VAR bufferlist: POINTER TO Bufferlist;
		BEGIN
			IF last # NIL THEN
				NEW(bufferlist);
				last.next := bufferlist;
				bufferlist.next := NIL;
				bufferlist.content := buf;
				last := bufferlist
			ELSE
				NEW(bufferlist);
				last := bufferlist;
				last.next := NIL;
				bufferlist.content := buf;
				ratedone := 0;
				pos := 0
			END;
			IF first = NIL THEN first := bufferlist END
		END QueueBuffer;

		(* Advances by one Buffer *)
		PROCEDURE NextBuffer;
		BEGIN {EXCLUSIVE}
			IF first.next # NIL THEN
				first := first.next
			ELSE
				rsilent := TRUE; active := FALSE;
				first := NIL
			END
		END NextBuffer;

		PROCEDURE Start;
		BEGIN {EXCLUSIVE}
			IF first#NIL THEN (* at least one buffer registered *)
				active := TRUE;

				IF ~ (4 IN SYSTEM.VAL(SET, drv.EsState.rctrl)) THEN
					IF Trace THEN KernelLog.String("Enabling ADC Interrupt"); END;
					drv.rloopcount := 0;
					Machine.Portout8(drv.base+Es1370RegMemPage, 0DX); (*1101*)
					Machine.Portout32(drv.base+34H, SYSTEM.VAL(LONGINT, Bsize DIV 4-1));
					(*additionally resets the counter of transfered longwords to 0*)

					drv.EsState.rctrl := SYSTEM.VAL(LONGINT, {4}+SYSTEM.VAL(SET, drv.EsState.rctrl));
					Machine.Portout32(drv.base+Es1370RegControl, drv.EsState.rctrl) (*AdcEn*)
				END
			END
		END Start;
	END RecordChannel;

	Driver*=OBJECT(SoundDevices.Driver)
	VAR playchannels : ARRAY 32 OF PlayerChannel; (* 32 channels are supported *)
			recordchannels : ARRAY 32 OF RecordChannel;
			pcm, line, cd : MixerChannel;
			time: Kernel.Timer; (* used in init *)
			base, irq : LONGINT; (* base address, interrupt nr of soundcard *)

			EsState : RECORD (* actual state of the soundcard *)
				sctrl : LONGINT; (* serial control register *)
				rctrl : LONGINT; (* irq / chip select block *)
			END;
			p2, pr2 : POINTER TO ARRAY OF CHAR; (* points to intern soundbuffer for play/record *)
			loopcount, rloopcount : LONGINT; (* determines if first or second bufferpart is playing *)
			next: Driver;
			introbj : Introbj; (* interrupt handler *)
			masterout : PlayMixerChannel;
			masterin : RecMixerChannel;
			allsilent, rallsilent : BOOLEAN; (* is at least one channel playing/recording? *)
			playcopy, reccopy : BOOLEAN; (* interrupt occured, copy data *)
			listenerlist : POINTER TO Listenerlist; (* list of MixerChangedProc *)
			mixerChannels : ARRAY NumMixerChannels OF MixerChannel;

			buffersToReturn, lastbtr : POINTER TO BuffersToReturn;
			bufferobj : BufferObj;


		(** Change the Record Source*)
		(** 0: Microphone, 1: CD IN, 4: LINE IN, 5: STEREO MIX (DEFAULT) *)
		PROCEDURE SetRecordSource*(i: INTEGER);
		BEGIN
			EsWrCd(1AH, SYSTEM.VAL(INTEGER, i+i*256))
		END SetRecordSource;

		PROCEDURE &Constructor*(irq, base: LONGINT);
		BEGIN
			NEW(bufferobj);
			buffersToReturn := NIL;
			lastbtr := NIL;
			SELF.base := base;
			SELF.irq := irq;
			SELF.next := installedDrivers;
			installedDrivers := SELF;
			INC(installed);
			Init
		END Constructor;

		(* add a buffer and it's listener to be returned *)
		(* mustn't be EXCLUSIVE because it could be blocked by ReturnBuffers *)
		PROCEDURE AddBufferToReturn(blistener: SoundDevices.BufferListener; content: SoundDevices.Buffer);
		VAR newbtr : POINTER TO BuffersToReturn;
		BEGIN {EXCLUSIVE}
			NEW(newbtr);
			newbtr.blistener := blistener;
			newbtr.content := content;
			newbtr.next := NIL;
			IF buffersToReturn # NIL THEN lastbtr.next := newbtr; lastbtr := newbtr
			ELSE buffersToReturn := newbtr; lastbtr := buffersToReturn END
		END AddBufferToReturn;

		(* return all collected buffers now *)
		PROCEDURE ReturnBuffers;
		BEGIN {EXCLUSIVE}
			WHILE buffersToReturn # NIL DO
				buffersToReturn.blistener(buffersToReturn.content);
				buffersToReturn := buffersToReturn.next
			END
		END ReturnBuffers;

		PROCEDURE WaitBuffersToReturn;
		BEGIN {EXCLUSIVE}
			AWAIT(buffersToReturn # NIL)
		END WaitBuffersToReturn;

		(* wait until sample rate converter is ready to accept commands/data *)
		PROCEDURE EsWaitSrcReady() : LONGINT;
		VAR t, r : LONGINT;
		BEGIN
			FOR t := 0 TO 500 DO
				Machine.Portin32(base+Es1371RegSmprate, SYSTEM.VAL(LONGINT, r));
				IF ~(23 IN SYSTEM.VAL(SET, r)) THEN
					RETURN r
				END
			END;
			KernelLog.String("es1371: wait src ready timeout");
			RETURN 0
		END EsWaitSrcReady;

		(* set the address part of the value for the sample rate converter *)
		PROCEDURE EsSrcRamAddro(reg: LONGINT): SET;
		VAR s, s2 : SET;
			i : LONGINT;
		BEGIN
			s := SYSTEM.VAL(SET, reg);
			s := s*{0..6};
			s2 := {};
			FOR i := 0 TO 6 DO
				IF i IN s THEN s2 := s2+{i+25} END
			END;
			RETURN s2
		END EsSrcRamAddro;

		(* set the data part of the value for the src *)
		PROCEDURE EsSrcRamDatao(reg: LONGINT): SET;
		VAR s : SET;
		BEGIN
			s := SYSTEM.VAL(SET, reg);
			s := s*{0..15};
			RETURN s
		END EsSrcRamDatao;

		(* write to the sample rate converter *)
		PROCEDURE EsSrcWrite(reg, data: LONGINT);
		VAR r : LONGINT;
		VAR s : SET;
		BEGIN
			r := EsWaitSrcReady();
			s := SYSTEM.VAL(SET, r);
			s := s * {19..22};
			s := s + EsSrcRamAddro(reg)+EsSrcRamDatao(data);
			s := s + {24};
			r := SYSTEM.VAL(LONGINT, s);
			Machine.Portout32(base+Es1371RegSmprate, r)
		END EsSrcWrite;

		(* read from sample rate converter *)
		PROCEDURE EsSrcRead(reg: LONGINT) : LONGINT;
		VAR r : LONGINT; s : SET;
		BEGIN
			r := EsWaitSrcReady();
			s := SYSTEM.VAL(SET, r);
			s := s*{19..22};
			s := s + EsSrcRamAddro(reg);
			r := SYSTEM.VAL(LONGINT, r);
			Machine.Portout32(base+Es1371RegSmprate, r);
			r := EsWaitSrcReady();
			RETURN SYSTEM.VAL(LONGINT, EsSrcRamDatao(r))
		END EsSrcRead;

		(* set the adc sample rate *)
		PROCEDURE EsAdcRate(rate, set: LONGINT);
		VAR n, truncm, freq, result, tmp : LONGINT;
			stmp : SET;
		BEGIN
			IF rate > 48000 THEN rate := 48000 END;
			IF rate < 4000 THEN rate := 4000 END;
			n := rate DIV 3000;
			IF ((n=15) OR (n=13) OR (n=11) OR (n=9)) THEN DEC(n) END;
			truncm := (21*n-1);
			truncm := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, truncm)+{0});
			freq := ((48000*32768) DIV rate) * n;
			result := ((48000*32768) DIV (freq DIV n));
			IF set>0 THEN
				IF (rate >= 24000) THEN
					IF (truncm > 239) THEN truncm := 239; END;
					tmp := ((239-truncm) DIV 2) * 512;
					stmp := SYSTEM.VAL(SET, tmp) + SYSTEM.VAL(SET, n*16);
					tmp := SYSTEM.VAL(LONGINT, stmp);
					EsSrcWrite(EsSmpregAdc, tmp)
				ELSE
					IF (truncm < 119) THEN truncm := 119; END;
					tmp := ((119-truncm) DIV 2) * 512;
					stmp := SYSTEM.VAL(SET, tmp)+SYSTEM.VAL(SET, n*16)+{15};
					tmp := SYSTEM.VAL(LONGINT, stmp);
					EsSrcWrite(EsSmpregAdc, tmp)
				END;

				tmp := EsSrcRead(EsSmpregAdc+1);
				stmp := SYSTEM.VAL(SET, tmp)*{0..7};
				stmp := stmp + (SYSTEM.VAL(SET, freq DIV 32)*{10..15});
				EsSrcWrite(EsSmpregAdc+1, SYSTEM.VAL(LONGINT, stmp));

				EsSrcWrite(EsSmpregAdc+3, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, freq)*{0..14}));

				EsSrcWrite(EsSmpregVolAdc, SYSTEM.VAL(LONGINT, n * 256));
				EsSrcWrite(EsSmpregVolAdc+1, SYSTEM.VAL(LONGINT, n * 256))
			END
		END EsAdcRate;

		(* set the dac sample rate for dac number "set" *)
		PROCEDURE EsDacRate(rate, set: LONGINT);
		VAR freq, r, result, dac, dis, temp : LONGINT;
		VAR stmp : SET;

		BEGIN
			IF rate > 48000 THEN rate := 48000; END;
			IF rate < 4000 THEN rate := 4000; END;
			freq := (rate * 32768) DIV 3000;
			result := (freq * 3000) DIV 32768;
			IF set>0 THEN
				IF set = 1 THEN dac := EsSmpregDac1; ELSE dac := EsSmpregDac2; END;
				IF set = 1 THEN dis := 20; ELSE dis := 21; END;
				r := EsWaitSrcReady();
				stmp := SYSTEM.VAL(SET, r)*{19..22};
				r := SYSTEM.VAL(LONGINT, stmp);
				Machine.Portout32(base+Es1371RegSmprate, r);
				r := EsSrcRead(dac+1);
				stmp := SYSTEM.VAL(SET, r)*{0..7};
				stmp := stmp + (SYSTEM.VAL(SET, freq DIV 32)*{10..15});
				temp := SYSTEM.VAL(LONGINT, stmp);
				EsSrcWrite(dac+1, temp);
				stmp := SYSTEM.VAL(SET, freq);
				stmp := stmp*{0..14};
				temp := SYSTEM.VAL(LONGINT, stmp);
				EsSrcWrite(dac+3, temp);
				r := EsWaitSrcReady();
				stmp := SYSTEM.VAL(SET, r);
				stmp := stmp*({22}+{dis}+{19});
				r := SYSTEM.VAL(LONGINT, stmp);
				Machine.Portout32(base+Es1371RegSmprate, r)
			END
		END EsDacRate;

		(* write ac97 codec *)
		PROCEDURE EsWrCd(addr, data: LONGINT);
		VAR t, res, x, i: LONGINT;
		VAR tset, tset2 : SET;
		BEGIN
			t := 0;
			REPEAT
				INC(t);
				Machine.Portin32(base+Es1371RegCodec, SYSTEM.VAL(LONGINT, res))
			UNTIL ((t>2000) OR ~(30 IN SYSTEM.VAL(SET, res)));
			Machine.Portin32(base+Es1371RegSmprate, SYSTEM.VAL(LONGINT, x));
			t := EsWaitSrcReady();
			t := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, t)*{19..22});
			Machine.Portout32(base+Es1371RegSmprate, t);

			t := 0;
			REPEAT
				INC(t);
				Machine.Portin32(base+Es1371RegSmprate, SYSTEM.VAL(LONGINT, res))
			UNTIL (t>2000) OR (SYSTEM.VAL(SET, res)*{16..18, 23} = {16});

			tset := SYSTEM.VAL(SET, addr)*{0..6};
			tset2 := {};
			FOR i := 0 TO 6 DO
				IF i IN tset THEN tset2 := tset2+{i+16} END
			END;
			tset := SYSTEM.VAL(SET, data)*{0..15};
			tset := tset+tset2;
			res := SYSTEM.VAL(LONGINT, tset);
			Machine.Portout32(base+Es1371RegCodec, res);
			t := EsWaitSrcReady();
			Machine.Portout32(base+Es1371RegSmprate, x)
		END EsWrCd;

		(* initialise the driver *)
		PROCEDURE Initdrv;
		VAR i: LONGINT;
			sndbuf : Machine.Address32; (* physical address of the intern soundbuffer *)
		BEGIN

			FOR i := 0 TO 31 DO
				NEW(playchannels[i], SELF);
				playchannels[i].active := FALSE;
				playchannels[i].free := TRUE
			END;

			FOR i := 0 TO 31 DO
				NEW(recordchannels[i], SELF);
				recordchannels[i].active := FALSE;
				recordchannels[i].free := TRUE
			END;

			NEW(introbj, SELF);
			introbj.numplayer := 0;

			(* set Bit 19 instead if you want to play direct 8 Bit sound *)
			EsState.sctrl := SYSTEM.VAL(LONGINT, {20});
			EsState.rctrl := 0;
			NEW(time);

			Objects.InstallHandler(introbj.HandleInterrupt, Machine.IRQ0+irq);

	(*********** INIT like in BSD driver *******************************)

			Machine.Portout32(base+Es1370RegStatus, SYSTEM.VAL(LONGINT, {29})); (* No idea why this is needed *)
			time.Sleep(20);
			Machine.Portout32(base+Es1370RegSerialControl, SYSTEM.VAL(LONGINT, 0));
			Machine.Portout32(base+Es1371RegLegacy, SYSTEM.VAL(LONGINT, 0));
			(* Now not again RegLegacy like in BSD-Driver *)
			Machine.Portout32(base+Es1370RegControl, SYSTEM.VAL(LONGINT, Es1371SyncRes));
			time.Sleep(2);	Machine.Portout32(base+Es1370RegControl, SYSTEM.VAL(LONGINT, {}));
			Machine.Portout32(base+Es1371RegSmprate, SYSTEM.VAL(LONGINT, Es1371DisSrc));

			FOR i := 0 TO 07FH DO
				EsSrcWrite(SYSTEM.VAL(INTEGER, i), 0)
			END;
			EsSrcWrite(EsSmpregDac1, SYSTEM.VAL(LONGINT, {8}));
			EsSrcWrite(EsSmpregDac1+1, SYSTEM.VAL(LONGINT, {14}));
			EsSrcWrite(EsSmpregDac2, SYSTEM.VAL(LONGINT, {8}));
			EsSrcWrite(EsSmpregDac2+1, SYSTEM.VAL(LONGINT, {14}));
			(*Why not?*)
			EsSrcWrite(EsSmpregAdc, SYSTEM.VAL(LONGINT, {8}));
			EsSrcWrite(EsSmpregAdc+1, SYSTEM.VAL(LONGINT, {14}));

			EsSrcWrite(EsSmpregVolAdc, SYSTEM.VAL(LONGINT, {12}));
			EsSrcWrite(EsSmpregVolAdc+1, SYSTEM.VAL(LONGINT, {12}));
			EsSrcWrite(EsSmpregVolDac1, SYSTEM.VAL(LONGINT, {12}));
			EsSrcWrite(EsSmpregVolDac1+1, SYSTEM.VAL(LONGINT, {12}));
			EsSrcWrite(EsSmpregVolDac2, SYSTEM.VAL(LONGINT, {12}));
			EsSrcWrite(EsSmpregVolDac2+1, SYSTEM.VAL(LONGINT, {12}));

			EsAdcRate(48000, 1); (* set the base (hardware) samplerate for recording *)
			EsDacRate(48000, 2); (* set the base (hardware) samplerate for playback *)
			(*EsDacRate(40100, 1);(* DAC1 is not used in this driver *) *)
			Machine.Portout32(base+Es1371RegSmprate, SYSTEM.VAL(LONGINT, 0));

	(*****************************************************)

			(* allocate, allign and register record and play buffer *)

			NEW(pr2, Bsize);
			rloopcount := 0;
			NEW(p2, Bsize);
			loopcount := 0;
			Machine.Portout32(base+Es1370RegControl, SYSTEM.VAL(LONGINT, {})); (* Disable all Channels *)

			sndbuf := Machine.Ensure32BitAddress (Machine.PhysicalAdr(ADDRESSOF(pr2[0]), Bsize));
			IF sndbuf = -1 THEN KernelLog.String("not enough defragmented space"); END;


			Machine.Portout8(base+Es1370RegMemPage, 0DX); (*1101*)
			Machine.Portout32(base+30H, SYSTEM.VAL(LONGINT, sndbuf)); (* physical buf adress *)

			Machine.Portout32(base+34H, SYSTEM.VAL(LONGINT, Bsize DIV 4-1)); (* size of buffer (in longwords -1) *)

			(* number of samples to playback until interrupt for ADC*)
			(* set it to Bsize DIV 4-1 for 16bitmono/8bitstereo and to Bsize DIV 2-1 for 8bitmono *)
			Machine.Portout32(base+Es1370RegAdcScount, SYSTEM.VAL(LONGINT, Bsize DIV 8-1));

			(* enable interrupt and set dataformat for ADC*)
			(* 14: LoopMode OFF, driver is always in loop mode *)
			(* 4,5: 00:8BMono 01:8BStereo 10:16BM 11:16BS *)
			(* 10: INTERRUPT ENABLE*)

			EsState.sctrl := SYSTEM.VAL(LONGINT, {4, 5, 10}+SYSTEM.VAL(SET, EsState.sctrl));
			Machine.Portout32(base+Es1370RegSerialControl, EsState.sctrl);


			sndbuf := Machine.Ensure32BitAddress (Machine.PhysicalAdr(ADDRESSOF(p2[0]), Bsize));
			IF sndbuf = -1 THEN KernelLog.String("not enough defragmented space") END;

			Machine.Portout8(base+Es1370RegMemPage, 0CX); (*1100*)
			Machine.Portout32(base+38H, SYSTEM.VAL(LONGINT, sndbuf)); (*physical buf adress*)

			Machine.Portout32(base+3CH, SYSTEM.VAL(LONGINT, Bsize DIV 4-1)); (* size of buffer (in longwords -1) *)

			(* number of samples to record until interrupt for DAC2*)
			(* set it to Bsize DIV 4-1 for 16bitmono/8bitstereo and to Bsize DIV 2-1 for 8bitmono *)
			Machine.Portout32(base+Es1370RegDac2Scount, SYSTEM.VAL(LONGINT, Bsize DIV 8-1));

			(* enable interrupt and set dataformat for DAC2*)
			(*14: LoopMode OFF, driver is always in loop mode*)
			(*2,3: 00:8BMono 01:8BStereo 10:16BM 11:16BS *)
			(*9: INTERRUPT ENABLE*)
		 	EsState.sctrl := SYSTEM.VAL(LONGINT, {2, 3, 9} + SYSTEM.VAL(SET, EsState.sctrl));
			Machine.Portout32(base+Es1370RegSerialControl, EsState.sctrl)
		END Initdrv;

		PROCEDURE Initvol;
		BEGIN
			(*EsWrCd(0, 1); (*Reset*) not needed*)

			EsWrCd(2, 0000H); (*Master*)
			EsWrCd(4, 8000H); (*Aux*)
			EsWrCd(6, 8000H); (*Mono*)
			EsWrCd(8, 8000H); (*Tone*)
			EsWrCd(0CH, 8000H); (*Phone*)
			EsWrCd(0EH, 8000H); (*Mic*)
			EsWrCd(10H, 4040H); (*Line In*)
			EsWrCd(18H, 4040H); (*PCM Out*)

			EsWrCd(1AH, SYSTEM.VAL(INTEGER, 5+5*256)); (*Record Source Stereo Mix*)
			EsWrCd(1CH, SYSTEM.VAL(INTEGER, 0+0*256)); (*Record Gain*)
			EsWrCd(1EH, SYSTEM.VAL(INTEGER, 0)); (*Record Gain Mic*)

	(* alternatives:
			EsWrCd(1AH, SYSTEM.VAL(INTEGER, 0)); (* Record Source Micro *)
			EsWrCd(1CH, SYSTEM.VAL(INTEGER, 15+15*256)); (*Record Gain*)
			EsWrCd(1EH, SYSTEM.VAL(INTEGER, 15)); (*Record Gain Mic*)
	*)

			IF Trace THEN KernelLog.String("Volume initialized"); KernelLog.Ln END
		END Initvol;

		PROCEDURE Finalize;
		BEGIN
			(* disable interrupt *)
			Machine.Portout32(base+Es1370RegSerialControl, SYSTEM.VAL(LONGINT, {20}));
			Objects.RemoveHandler(introbj.HandleInterrupt, Machine.IRQ0+irq);
			time.Sleep(100); (* make sure interrup has terminated *)
			IF Modules.shutdown = Modules.None THEN
				SoundDevices.devices.Remove(SELF)
			END
		END Finalize;

		PROCEDURE Init*;
		VAR i : LONGINT;
		BEGIN
			Initdrv;
			Initvol; (* initialise the hardware volume *)

			FOR i := 0 TO NumMixerChannels-1 DO mixerChannels[i] := NIL END;

			NEW(masterout, SELF, "MasterOut", "Master Output mixer channel", 02H);
			NEW(masterin, SELF, "MasterIn", "master Input mixer channel", 1CH);
			NEW(pcm, SELF, "PCM", "PCM Output mixer channel", 18H);
			NEW(line, SELF, "LineIn", "Line In mixer channel", 10H);
			NEW(cd, SELF, "CD", "CD mixer channel", 12H);

			masterIn := masterin;
			masterOut := masterout;

			desc := "Ensoniq PCI Sound driver";

			masterin.SetVolume(0H);
			masterout.SetVolume(0FFH);
			pcm.SetVolume(0D8H);
			(* according to documentation pcm.SetVolume(0B8H) should give gain 0, but it's too silent *)

			masterin.muted := FALSE;
			masterout.muted := FALSE;
			pcm.muted := FALSE;

			line.SetVolume(0D8H);

			(*line.SetMute(TRUE);*) (* set it mute if you hear noise *)

			cd.SetVolume(0D8H);
			cd.SetMute(TRUE);
			(* set volume so that recorded sound gets played back with same amplitude *)

			NEW(listenerlist); (* no mixer listeners so far *)
			listenerlist.proc := NIL;
			listenerlist.next := NIL;
			IF Trace THEN KernelLog.String("init done"); KernelLog.Ln END
		END Init;

		PROCEDURE OpenPlayChannel*(VAR channel : SoundDevices.Channel;
		samplingRate, samplingResolution, nofSubChannels, format : LONGINT;
		VAR res : LONGINT);
		VAR i, count : LONGINT;
		BEGIN {EXCLUSIVE}
			channel := NIL;
			count := 0;
			FOR i := 0 TO 31 DO
				IF ~playchannels[i].free THEN
					INC(count)
				END
			END;
			IF Trace THEN KernelLog.String("Active channel #: "); KernelLog.Int(count, 0); KernelLog.Ln END;
			i := 0;
			WHILE (i<=31) & (~playchannels[i].free) DO
				INC(i);
			END;

			IF i <32 THEN
				channel := playchannels[i];
				playchannels[i].free := FALSE;
				playchannels[i].first := NIL;
				playchannels[i].last := NIL;
				playchannels[i].samplingRate := samplingRate;
				playchannels[i].samplingResolution := samplingResolution;
				playchannels[i].nofSubChannels := nofSubChannels;
				playchannels[i].delta := (samplingResolution DIV 8) * nofSubChannels; (* number of bytes per sample *)
				playchannels[i].SetVolume(100H);
				playchannels[i].RegisterBufferListener(DefaultBufferListener);
				res := SoundDevices.ResOK;
				IF Trace THEN KernelLog.String("Open play channel #: "); KernelLog.Int(i, 0); KernelLog.Ln END
			ELSE res := SoundDevices.ResNoMoreChannels
			END
		END OpenPlayChannel;

		PROCEDURE OpenRecordChannel*(VAR channel : SoundDevices.Channel;
		samplingRate, samplingResolution, nofSubChannels, format : LONGINT;
		VAR res: LONGINT);
		VAR i : LONGINT;
		BEGIN
			channel := NIL;
			i := 0;
			WHILE (i <= 31) & (~recordchannels[i].free) DO
				INC(i)
			END;
			IF i<32 THEN
				channel := recordchannels[i];
				recordchannels[i].free := FALSE;
				recordchannels[i].first := NIL;
				recordchannels[i].last := NIL;
				recordchannels[i].samplingRate := samplingRate;
				recordchannels[i].samplingResolution := samplingResolution;
				recordchannels[i].nofSubChannels := nofSubChannels;
				recordchannels[i].delta := (samplingResolution DIV 8) * nofSubChannels; (* number of bytes per sample *)
				recordchannels[i].SetVolume(100H);
				recordchannels[i].RegisterBufferListener(DefaultBufferListener);
				res := SoundDevices.ResOK
			ELSE res := SoundDevices.ResNoMoreChannels
			END
		END OpenRecordChannel;

		PROCEDURE NofNativeFrequencies*():LONGINT;
		BEGIN
			RETURN 1
		END NofNativeFrequencies;

		PROCEDURE GetNativeFrequency*(nr: LONGINT): LONGINT;
		BEGIN
			RETURN 48000
		END GetNativeFrequency;

		PROCEDURE RegisterMixerChangeListener*(mixChangedProc: SoundDevices.MixerChangedProc);
		VAR nlistenerlist, nl : POINTER TO Listenerlist;
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
		BEGIN
			IF (channelNr<NumMixerChannels) & (channelNr>=0) THEN
				channel := (mixerChannels[channelNr])
			ELSE
				channel := NIL
			END;
		END GetMixerChannel;

		PROCEDURE GetNofMixerChannels*() : LONGINT;
		BEGIN
			RETURN NumMixerChannels
		END GetNofMixerChannels;

	BEGIN {ACTIVE}
		REPEAT
			WaitBuffersToReturn;
			ReturnBuffers
		UNTIL 1=2
	END Driver;

	(* interrupt handling Object *)
	Introbj=OBJECT
	VAR numplayer : LONGINT;
		 driver : Driver;
		VAR copy : BOOLEAN;

		PROCEDURE &Init*(driver : Driver);
		BEGIN
			SELF.driver := driver;
			copy := FALSE
		END Init;

		PROCEDURE WaitInterruptStop;
		BEGIN
			AWAIT(~(5 IN SYSTEM.VAL(SET, driver.EsState.rctrl)))
		END WaitInterruptStop;

		PROCEDURE Deactivate(playerchannel : PlayerChannel);
		BEGIN {EXCLUSIVE}
			IF playerchannel.active THEN
				playerchannel.active := FALSE;
				DEC(numplayer);
				IF numplayer=0 THEN
					WaitInterruptStop
				END
			END
		END Deactivate;

		PROCEDURE Activate(playerchannel : PlayerChannel);
		BEGIN {EXCLUSIVE}
			IF playerchannel.active = FALSE THEN
				IF numplayer=0 THEN
					WaitInterruptStop;
					(*Make sure Interrupt is already disabled*)
					driver.playcopy := TRUE;
					driver.loopcount := 1
				END;
				playerchannel.active := TRUE;
				INC(numplayer)
			END
		END Activate;

		PROCEDURE HandleInterrupt; (* interrupt handler *)
		VAR r, where : LONGINT;
			sr, ssctrl : SET;
		BEGIN {EXCLUSIVE}
			Machine.Portin32(driver.base+Es1370RegStatus, r);
			sr := SYSTEM.VAL(SET, r);
			IF 31 IN sr THEN (* Interrupt pending *)
				IF 0 IN sr THEN (* ACD int pending *)

					Machine.Portout8(driver.base+Es1370RegMemPage, 0DX);
					Machine.Portin32(driver.base+34H, where);

					IF where DIV 65536 >= Bsize DIV 8 -1 THEN
						driver.rloopcount := 0 ELSE driver.rloopcount := 1
					END; (* which part of the buffer is not getting recorded into, so we can read it out next*)

					driver.reccopy := TRUE;
					ssctrl := SYSTEM.VAL(SET, driver.EsState.sctrl)-{10};
					Machine.Portout32(driver.base+Es1370RegSerialControl, SYSTEM.VAL(LONGINT, ssctrl));
					Machine.Portout32(driver.base+Es1370RegSerialControl, driver.EsState.sctrl)
				END;
				IF 1 IN sr THEN (* DAC2 int pending *)
					Machine.Portout8(driver.base+Es1370RegMemPage, 0CX);
					Machine.Portin32(driver.base+3CH, where);

					IF where DIV 65536 >= Bsize DIV 8 - 1 THEN
						driver.loopcount := 0 ELSE driver.loopcount := 1;
					END; (* which part of the buffer is not playing, so we can fill it next*)

					driver.playcopy := TRUE;
					ssctrl := SYSTEM.VAL(SET, driver.EsState.sctrl)-{9};
					Machine.Portout32(driver.base+Es1370RegSerialControl, SYSTEM.VAL(LONGINT, ssctrl));
					Machine.Portout32(driver.base+Es1370RegSerialControl, driver.EsState.sctrl)
				END;
				IF 2 IN sr THEN (* DAC1 int pending, should never happen *)
					ssctrl := SYSTEM.VAL(SET, driver.EsState.sctrl)-{8};
					Machine.Portout32(driver.base+Es1370RegSerialControl, SYSTEM.VAL(LONGINT, ssctrl));
					Machine.Portout32(driver.base+Es1370RegSerialControl, driver.EsState.sctrl)
				END
			END
			END HandleInterrupt;

		(* wait until interrupt sets playcopy or reccopy *)
		PROCEDURE Wait;
		BEGIN {EXCLUSIVE}
			AWAIT(driver.playcopy OR driver.reccopy)
		END Wait;

		PROCEDURE WaitNoPlay;
		BEGIN {EXCLUSIVE}
			AWAIT(~driver.playcopy);
		END WaitNoPlay;

		PROCEDURE WaitNoRec;
		BEGIN (*{EXCLUSIVE}*)
			AWAIT(~driver.reccopy)
		END WaitNoRec;

		PROCEDURE Setplaycopy(VALUE: BOOLEAN);
		BEGIN {EXCLUSIVE}
			driver.playcopy := VALUE
		END Setplaycopy;

		(* make sure amplitude is in the allowed range *)
		PROCEDURE Clip(VAR lsigned: LONGINT);
		BEGIN
			IF lsigned >MAX(INTEGER) THEN
				lsigned := MAX(INTEGER)
			END;
			IF lsigned <MIN(INTEGER) THEN
				lsigned := MIN(INTEGER)
			END
		END Clip;

		PROCEDURE Copy;
		VAR first : BOOLEAN;

			(* convert sample from mono to stereo *)
			PROCEDURE mono(VAR ca: Sample);
			BEGIN
				ca[2] := ca[0];
				ca[3] := ca[1]
			END mono;

			(* convert sample from 8 to 16 bit *)
			PROCEDURE eight(VAR ca: Sample);
			BEGIN
				ca[3] := CHR(ORD(ca[1])-128);
				ca[2] := CHR(0);
				ca[1] := CHR(ORD(ca[0])-128);
				ca[0] := CHR(0)
			END eight;

			(* convert 8 bit mono sample to 16 bit stereo *)
			PROCEDURE eightmono(VAR ca: Sample);
			BEGIN
				eight(ca);
				mono(ca)
			END eightmono;

			(* fills first or second half of intern buffer *)
			PROCEDURE Playcopy(from, to : LONGINT);
			VAR signed : INTEGER;
				lsigned, i, j, l : LONGINT;
				nr : LONGINT; (* ratedone MOD 48000 *)
				temp : LONGINT;

				PROCEDURE Readnextsample;
				BEGIN
					driver.playchannels[j].pos := driver.playchannels[j].pos+driver.playchannels[j].delta;
					driver.playchannels[j].ratedone := nr;
					driver.playchannels[j].oldsample := driver.playchannels[j].sample;

					(* first should never be NIL if we get so far. but if we are unlucky -stop and play of a channel exactly after each other- it can be, drop me a mail if you see how *)
					IF (driver.playchannels[j].first # NIL) & (driver.playchannels[j].pos >= driver.playchannels[j].first.content.len) THEN

						(* current buffer is over *)

						driver.playchannels[j].pos := 0;
						(* driver.playchannels[j].blistener(driver.playchannels[j].first.content); *)
						(* can't return the buffer directly because we are inside an EXCLUSIVE part here and don't want
						to call an external Procedure from here, so save it for later in bufferObj *)
						driver.AddBufferToReturn(driver.playchannels[j].blistener, driver.playchannels[j].first.content);
						driver.playchannels[j].NextBuffer;
					END;
					IF (driver.playchannels[j].silent) OR (driver.playchannels[j].first = NIL) THEN (* nothing more to read, but will still interpolate with oldsample *)
						driver.playchannels[j].sample[0]:= CHR(0);
						driver.playchannels[j].sample[1]:= CHR(0);
						driver.playchannels[j].sample[2]:= CHR(0);
						driver.playchannels[j].sample[3]:= CHR(0)
					ELSE
						driver.allsilent := FALSE;
						(* convert sample to 16 bit stereo *)
						driver.playchannels[j].sample[0] :=
						driver.playchannels[j].first.content.data[driver.playchannels[j].pos];
						IF (driver.playchannels[j].samplingResolution=8) &
						(driver.playchannels[j].nofSubChannels=1) THEN
							eightmono(driver.playchannels[j].sample)
						END;
						IF (driver.playchannels[j].samplingResolution=16) OR
						(driver.playchannels[j].nofSubChannels=2) THEN
							driver.playchannels[j].sample[1] :=
							driver.playchannels[j].first.content.data[driver.playchannels[j].pos+1];

							IF (driver.playchannels[j].samplingResolution=8) THEN
								eight(driver.playchannels[j].sample)
							END;
							IF (driver.playchannels[j].nofSubChannels=1) THEN
								mono(driver.playchannels[j].sample)
							END;
							IF (driver.playchannels[j].samplingResolution=16) &
							(driver.playchannels[j].nofSubChannels=2) THEN
								driver.playchannels[j].sample[2] :=
								driver.playchannels[j].first.content.data[driver.playchannels[j].pos+2];
								driver.playchannels[j].sample[3] :=
								driver.playchannels[j].first.content.data[driver.playchannels[j].pos+3]
							END
						END
					END (* not silent *)
				END Readnextsample;

			BEGIN {EXCLUSIVE}
				driver.bufferobj.Setinplaycopy(TRUE); (* wait until bufferobj is not locked *)
				FOR j := 0 TO 31 DO
					IF driver.playchannels[j].active THEN
						driver.playchannels[j].silent := FALSE;
						i := from;

						WHILE (i <= to) DO
							driver.playchannels[j].ratedone :=
							driver.playchannels[j].ratedone + driver.playchannels[j].samplingRate;
							nr := driver.playchannels[j].ratedone MOD 48000;
							IF (nr # driver.playchannels[j].ratedone) THEN
								IF (driver.playchannels[j].active) THEN
									(* time to read out next sample *)
									Readnextsample
								ELSE
									driver.playchannels[j].oldsample[0] := CHR(0);
									driver.playchannels[j].oldsample[1] := CHR(0);
									driver.playchannels[j].oldsample[2] := CHR(0);
									driver.playchannels[j].oldsample[3] := CHR(0)
									(* now it's really silent *)
								END
							END;

							IF first THEN (* don't have to mix *)
								FOR l := 0 TO 1 DO
									signed := SYSTEM.VAL(INTEGER, driver.playchannels[j].sample[2*l]);
									lsigned := LONG(signed);
									signed := SYSTEM.VAL(INTEGER, driver.playchannels[j].oldsample[2*l]);
									lsigned := ENTIER((1-driver.playchannels[j].ratedone/48000)*
									LONG(signed)+(driver.playchannels[j].ratedone/48000)*lsigned+0.5);

									lsigned := lsigned*(driver.playchannels[j].vol) DIV 256 (*DIV 32*);

									Clip(lsigned);
									signed := SHORT(lsigned);
									driver.p2[i+2*l] := CHR(signed MOD 256);
									driver.p2[i+2*l+1] := CHR(signed DIV 256)
								END
							ELSE (* mix with current buffercontent *)
								FOR l := 0 TO 1 DO
									signed := SYSTEM.VAL(INTEGER, driver.playchannels[j].sample[2*l]);
									lsigned := LONG(signed);
									signed := SYSTEM.VAL(INTEGER, driver.playchannels[j].oldsample[2*l]);
									lsigned := ENTIER((1-driver.playchannels[j].ratedone/48000)*
									LONG(signed)+(driver.playchannels[j].ratedone/48000)*lsigned+0.5);

									lsigned := lsigned*(driver.playchannels[j].vol) DIV 256 (*DIV 32*);

									signed := SYSTEM.VAL(INTEGER, driver.p2[i+2*l]);
									lsigned := LONG(signed) + lsigned;

									Clip(lsigned);
									signed := SHORT(lsigned);
									driver.p2[i+2*l] := CHR(signed MOD 256);
									driver.p2[i+1+2*l] := CHR(signed DIV 256)
								END
							END;
							INC(i, 4)
						END; (*WHILE*)
						first := FALSE (* next channel can't be the first *)
					END (*IF*)
				END; (*FOR*)

				IF ~driver.allsilent THEN (* make sure playing is in progress *)
					IF ~ (5 IN SYSTEM.VAL(SET, driver.EsState.rctrl)) THEN
						IF Trace THEN KernelLog.String("Enabling DAC2 Interrupt"); KernelLog.Ln END;
						Machine.Portout8(driver.base+Es1370RegMemPage, 0CX); (*1100*)
						Machine.Portout32(driver.base+3CH, SYSTEM.VAL(LONGINT, Bsize DIV 4-1));
						(*resets the counter of transferred longwords to 0*)
						driver.EsState.rctrl := SYSTEM.VAL(LONGINT, {5}+SYSTEM.VAL(SET, driver.EsState.rctrl));
						Machine.Portout32(driver.base+Es1370RegControl, driver.EsState.rctrl); (*Dac2En*)
					END;
				ELSE (* make sure playing is stopped *)
					IF (5 IN SYSTEM.VAL(SET, driver.EsState.rctrl)) THEN
						temp := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, driver.EsState.rctrl)-{5});
						Machine.Portout32(driver.base+Es1370RegControl, temp); (*Dac2Dis*)
						FOR i := 0 TO Bsize-1 DO driver.p2[i] := CHR(0) END;
						driver.EsState.rctrl := temp
					END
				END;
				driver.bufferobj.Setinplaycopy(FALSE)
			END Playcopy;

			PROCEDURE Reccopy(from, to: LONGINT);
			VAR sample : Sample;
				signed : INTEGER;
				lsigned, i, j, l : LONGINT;
				nr : LONGINT; (* ratedone MOD 48000 *)

			BEGIN {EXCLUSIVE}
				FOR j := 0 TO 31 DO
					IF driver.recordchannels[j].active THEN
						driver.recordchannels[j].rsilent := FALSE;
						i := from;
						WHILE (i <= to) & (driver.recordchannels[j].active) DO
							IF driver.recordchannels[j].pos >= driver.recordchannels[j].first.content.len THEN
								(* current buffer is over *)
								driver.recordchannels[j].pos := 0;
								(*driver.recordchannels[j].blistener(driver.recordchannels[j].first.content);*)
								driver.AddBufferToReturn(driver.recordchannels[j].blistener,
								driver.recordchannels[j].first.content);
								driver.recordchannels[j].NextBuffer;
							END;

							driver.recordchannels[j].ratedone :=
							driver.recordchannels[j].ratedone + driver.recordchannels[j].samplingRate;
							nr := driver.recordchannels[j].ratedone MOD 48000;
							IF nr # driver.recordchannels[j].ratedone THEN (* time to read out next sample *)
								driver.recordchannels[j].ratedone := nr;

								IF ~driver.recordchannels[j].rsilent THEN
									driver.rallsilent := FALSE;
									sample[0] := driver.pr2[i];
									sample[1] := driver.pr2[i+1];
									sample[2] := driver.pr2[i+2];
									sample[3] := driver.pr2[i+3];

									FOR l := 0 TO 1 DO
										signed := SYSTEM.VAL(INTEGER, sample[2*l]);
										lsigned := LONG(signed);
										lsigned := lsigned*(driver.recordchannels[j].vol) DIV 256;
										Clip(lsigned);
										signed := SHORT(lsigned);

										sample[2*l] := CHR(signed MOD 256);
										sample[2*l+1] := CHR(signed DIV 256)
									END;
									(* convert recorded 16 bit stereo sample to target format *)

									IF driver.recordchannels[j].samplingResolution=8 THEN
										IF driver.recordchannels[j].nofSubChannels=1 THEN
											driver.recordchannels[j].first.content.data[driver.recordchannels[j].pos]
											:= CHR( (ORD(sample[1])-128 + ORD(sample[3])-128) DIV 2)
										ELSE
											driver.recordchannels[j].first.content.data[driver.recordchannels[j].pos]
											:= CHR(ORD(sample[1])-128);
											driver.recordchannels[j].first.content.data[driver.recordchannels[j].pos+1]
											:= CHR(ORD(sample[3])-128)
										END
									ELSE
										IF driver.recordchannels[j].nofSubChannels=1 THEN
											lsigned := SYSTEM.VAL(INTEGER, sample[0]);
											lsigned := lsigned+SYSTEM.VAL(INTEGER, sample[2]);
											signed := SHORT(lsigned DIV 2);
											driver.recordchannels[j].first.content.data[driver.recordchannels[j].pos]
											:= CHR(signed MOD 256);
											driver.recordchannels[j].first.content.data[driver.recordchannels[j].pos+1]
											:= CHR(signed DIV 256)
										ELSE
											driver.recordchannels[j].first.content.data[driver.recordchannels[j].pos]
											:= sample[0];
											driver.recordchannels[j].first.content.data[driver.recordchannels[j].pos+1]
											:= sample[1];
											driver.recordchannels[j].first.content.data[driver.recordchannels[j].pos+2]
											:= sample[2];
											driver.recordchannels[j].first.content.data[driver.recordchannels[j].pos+3]
											:= sample[3]
										END
									END
								END;
								driver.recordchannels[j].pos:= driver.recordchannels[j].pos+driver.recordchannels[j].delta
							END;
							INC(i, 4)
						END (*WHILE*)
					END
				END;

				IF ~driver.rallsilent THEN (* make sure recording is in progress *)
					IF ~ (4 IN SYSTEM.VAL(SET, driver.EsState.rctrl)) THEN
						Machine.Portout8(driver.base+Es1370RegMemPage,  0DX); (*1101*)
						Machine.Portout32(driver.base+34H, SYSTEM.VAL(LONGINT, Bsize DIV 4-1));
						(*resets the counter of transferred longwords to 0*)

						driver.EsState.rctrl := SYSTEM.VAL(LONGINT, {4}+SYSTEM.VAL(SET, driver.EsState.rctrl));
						Machine.Portout32(driver.base+Es1370RegControl, driver.EsState.rctrl) (*AdcEn*)
					END
				ELSE (* make sure recording is stopped *)
					IF (4 IN SYSTEM.VAL(SET, driver.EsState.rctrl)) THEN
						driver.EsState.rctrl := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, driver.EsState.rctrl)-{4});
						Machine.Portout32(driver.base+Es1370RegControl, driver.EsState.rctrl); (*AdcDis*)
						FOR i := 0 TO Bsize-1 DO driver.pr2[i] := CHR(0) END
					END
				END
			END Reccopy;

		BEGIN
			driver.allsilent := TRUE; first := TRUE;
			driver.rallsilent := TRUE;

			IF driver.reccopy=TRUE THEN
				IF driver.rloopcount MOD 2 = 0 THEN
					Reccopy(0, Bsize DIV 2 -1)
				ELSE
					Reccopy(Bsize DIV 2, Bsize -1)
				END;
				driver.reccopy := FALSE
			END;
			IF driver.playcopy = TRUE THEN
				Setplaycopy(FALSE);
				IF driver.loopcount MOD 2 = 0 THEN
					Playcopy(0, Bsize DIV 2 -1)
				ELSE
					Playcopy(Bsize DIV 2, Bsize -1)
				END
			END
		END Copy;

	BEGIN {ACTIVE}
		driver.playcopy := FALSE;
		driver.reccopy := FALSE;
		REPEAT (* wait for user/interrupt setting playcopy/reccopy as long as driver is loaded *)
			Wait;
			Copy
		UNTIL 1=2
	END Introbj;

VAR installedDrivers: Driver;
	installed: LONGINT;

PROCEDURE DefaultBufferListener(buffer: SoundDevices.Buffer);
END DefaultBufferListener;

(** Called when unloading the module *)
PROCEDURE Cleanup;
BEGIN
	WHILE installedDrivers # NIL DO
		installedDrivers.Finalize;
		installedDrivers := installedDrivers.next
	END;
	installed := 0;
END Cleanup;

PROCEDURE ScanPCI(vendor, device: LONGINT; name: Plugins.Name);
VAR index, bus, dev, fct, res, base, irq, i : LONGINT;
	driver : Driver;
	drivername : Plugins.Name;
BEGIN
	driver := NIL;
	index := 0;
	WHILE (PCI.FindPCIDevice(device, vendor, index, bus, dev, fct) = PCI.Done) & (installed < 10) DO
		IF Trace THEN
			KernelLog.String("Bus "); KernelLog.Int(bus, 1);
			KernelLog.String(", device: "); KernelLog.Int(dev, 1);
			KernelLog.String(", function: "); KernelLog.Int(fct, 1);
			KernelLog.String(", vendor/device "); KernelLog.Hex(ASH(vendor, 16) + device, 0); KernelLog.Ln;
		END;

		(* Get physical base address *)
		res := PCI.ReadConfigDword(bus, dev, fct, PCI.Adr0Reg, base);
		ASSERT(res=PCI.Done);
		ASSERT(ODD(base));
		DEC(base, base MOD 4); (* zero last 2 bits *)
		IF Trace THEN KernelLog.String("Base address: "); KernelLog.Hex(base, 0); KernelLog.Ln END;

		(* Get IRQ number *)
		res := PCI.ReadConfigByte(bus, dev, fct, PCI.IntlReg, irq);
		ASSERT(res=PCI.Done);
		IF Trace THEN KernelLog.String("IRQ"); KernelLog.Int(irq, 1); KernelLog.Ln END;
		(* Instanciate new driver object *)
		NEW(driver, irq, base);
		KernelLog.String("Ensoniq sound driver installed."); KernelLog.Ln;
		i := 0;
		WHILE name[i] # 0X DO drivername[i] := name[i]; INC(i) END;
		drivername[i] := "#";
		drivername[i + 1] := CHR(ORD("0") + installed);
		drivername[i + 2] := 0X;
		driver.SetName(drivername);
		SoundDevices.devices.Add(driver, res);	(* add NEW driver to installedDrivers *)
		ASSERT(res=0);
		INC(index)
	END
END ScanPCI;

(** command forcing Init and the installation of a driver. *)
PROCEDURE Install*;
(* Init routine is called implicitly *)
END Install;

(* Initialize the driver module *)
PROCEDURE Init;
BEGIN
	IF installedDrivers = NIL THEN
		ScanPCI(1274H, 1371H, "ES1371");
		ScanPCI(1274H, 1373H, "ES1373");
		ScanPCI(1274H, 5880H, "5880 AudioPCI")
	END;
END Init;

BEGIN {EXCLUSIVE}
	Modules.InstallTermHandler(Cleanup);
	installedDrivers := NIL;
	installed := 0;
	Init;
END EnsoniqSound.

EnsoniqSound.Install ~
SystemTools.Free EnsoniqSound ~

Installation
Add EnsoniqSound.Install to Configuration.XML, section 'Autostart' to load driver at system startup.

