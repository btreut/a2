MODULE TV;	(** AUTHOR "fr@felix.shacknet.nu", PURPOSE "TV application"; *)
							  (** Redesign by Olivier Jeger, oljeger@student.ethz.ch *)

IMPORT Kernel, Machine, KernelLog, Commands, Streams, Dates, Strings,
	TVDriver, WMRectangles, Graphics := WMGraphics, Messages := WMMessages, Files, TVChannels,
	Standard := WMStandardComponents,
	TeletextDecoder, WMRestorable, XML, Modules, WMDialogs,
	WM := WMWindowManager;

CONST
	ChannelFile = TVChannels.ChannelFile;
	SwitchingInterval = 5;	(* Minutes *)	(* Period after which the TV channel is automatically switched *)

(*	DEBUG = FALSE;		*)

TYPE
	ChannelSeeker = OBJECT
	VAR
		dead : BOOLEAN;
		seeking : BOOLEAN;
		stepSize : LONGINT;
		tuner : TVDriver.TVTuner;
		audio : TVDriver.Audio;
		sigFound, sigLost : LONGINT;

		PROCEDURE &Init*(tuner : TVDriver.TVTuner; audio : TVDriver.Audio);
		BEGIN
			SELF.tuner := tuner;
			dead := FALSE;
			seeking := FALSE;
		END Init;

		PROCEDURE SetStepSize(stepSize : LONGINT);
		BEGIN {EXCLUSIVE}
			SELF.stepSize := stepSize;
		END SetStepSize;

		PROCEDURE StartSeeking;
		BEGIN {EXCLUSIVE}
			seeking := TRUE;
		END StartSeeking;

		PROCEDURE StopSeeking;
		BEGIN {EXCLUSIVE}
			seeking := FALSE;
		END StopSeeking;

		PROCEDURE SeekChannel;
		BEGIN {EXCLUSIVE}
			audio.SetAudioMute;
			(* first get rid of old channel *)
			REPEAT
				tuner.SetTVFrequency(tuner.GetFrequency() + stepSize);
			UNTIL ~seeking OR dead OR ~tuner.IsLocked();
			(* find next channel, save first contact *)
			REPEAT
				tuner.SetTVFrequency(tuner.GetFrequency() + stepSize);
			UNTIL ~seeking OR dead OR tuner.IsLocked();
			sigFound := tuner.GetFrequency();
			(* find point where channel dissapears *)
			REPEAT
				tuner.SetTVFrequency(tuner.GetFrequency() + stepSize);
			UNTIL ~seeking OR dead OR ~tuner.IsLocked();
			sigLost := tuner.GetFrequency();
			(* choose average for new frequency *)
			tuner.SetTVFrequency((sigFound + sigLost) DIV 2);
			seeking := FALSE;
			audio.SetAudioUnmute;
		END SeekChannel;

		PROCEDURE Release;
		BEGIN {EXCLUSIVE}
			dead := TRUE;
		END Release;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE}
			REPEAT
				AWAIT(dead OR seeking);
				IF ~dead THEN
					SeekChannel;
				END;
			UNTIL dead;
		END;
	END ChannelSeeker;


	TvWindow* = OBJECT(WM.BufferWindow);
	VAR
		vcd : TVDriver.VideoCaptureDevice;
		tuner : TVDriver.TVTuner;
		audio : TVDriver.Audio;
		vbi : TeletextDecoder.VbiDecoder;
		timer : Kernel.Timer;
		chNr : LONGINT;
		chSwitcher : Standard.Timer;
		autoSwitch, alive- : BOOLEAN;
		chnlSeeker : ChannelSeeker;
		newImage : BOOLEAN;
		lastX, lastY : LONGINT;
		dragging : BOOLEAN;
		chName : ARRAY 33 OF CHAR;

		vcdNr* : LONGINT;		(* Needed for restore process *)
		nextINchain : TvWindow;

		PROCEDURE &New*(vcd : TVDriver.VideoCaptureDevice);
		VAR
			ch : TVChannels.TVChannel;
		BEGIN
			ASSERT(vcd # NIL);
			SELF.vcd := vcd;
			vcdNr := -1;
			tuner := vcd.GetTuner();
			audio := vcd.GetAudio();
			audio.SetAudioIntern();
			Init(640, 480, FALSE);
			SetTitle(WM.NewString("TV"));
			NEW(chnlSeeker, tuner, audio);
			vcd.VideoOpen();
			vcd.InstallNotificationHandler(SELF.NewImage);
			vcd.SetInputDev1;
			tuner.Open();
			tuner.SetChannel(2);
			tuner.InstallChannelSwitchHandler (SELF.HandleSwitch);
			IF (TVChannels.channels # NIL) & (TVChannels.channels.GetCount() > 0) THEN
				ch := TVChannels.channels.GetItem (0);
				tuner.SetTVFrequency(ch.freq);
			END;
			audio.SetAudioIntern;
			audio.SetAudioUnmute;
			vcd.SetVideo(Machine.PhysicalAdr(SELF.img.adr, 0), SELF.img.bpr);
			vcd.SetGeometry(640, 480, 1, {});
			vcd.SetPixelFormat(2);
			vcd.CaptureContinuous;
			manager := WM.GetDefaultManager();
			manager.Add(100, 100, SELF, {WM.FlagFrame});
			SetPointerInfo(manager.pointerNull);

			(* Insert the window in an internal list for the term handler *)
			nextINchain := windows;
			windows := SELF
		END New;

		(** Close the TV window *)
		PROCEDURE Close;
		VAR
			vbiBuffer : TVDriver.VbiBuffer;
		BEGIN
			BEGIN {EXCLUSIVE}
				alive := FALSE
			END;
			IF chSwitcher # NIL THEN
				chSwitcher.Stop(NIL, NIL)
			END;
			chnlSeeker.Release;
			chnlSeeker := NIL;
			alive := FALSE;
			IF vcd.IsVbiOpen() THEN
				tuner.CloseVbi();
				vbiBuffer := vcd.GetVbiBuffer();
				vbiBuffer.Finalize
			END;
			IF vbi # NIL THEN
				vbi.Stop
			END;
			vcd.VideoClose;
			tuner.Close;
			Close^;
			FreeWindow(SELF)
		END Close;

		(** Start automatic channel switching. Used for automatic teletext caching*)
		PROCEDURE StartAutoSwitch*;
		BEGIN
			IF chSwitcher = NIL THEN
				NEW(chSwitcher);
				chSwitcher.interval.Set(SwitchingInterval * 60 * 1000);
				chSwitcher.onTimer.Add(NextCh)
			END;
			chSwitcher.Start(NIL, NIL);
			autoSwitch := TRUE;
			KernelLog.String("{TV} Automatic channel switch enabled."); KernelLog.Ln
		END StartAutoSwitch;

		(** Stop automatic channel switching *)
		PROCEDURE StopAutoSwitch*;
		BEGIN
			chSwitcher.Stop(NIL, NIL);
			autoSwitch := FALSE;
			KernelLog.String("{TV} Automatic channel switch stopped."); KernelLog.Ln
		END StopAutoSwitch;

		(** Switch to the next channel which has teletext. Used for automatic teletext caching *)
		PROCEDURE NextCh(sender, par : ANY);
		VAR
			ch : TVChannels.TVChannel;
		BEGIN
			REPEAT
				chNr := (chNr + 1) MOD TVChannels.channels.GetCount();
				ch := TVChannels.channels.GetItem (chNr)
			UNTIL ch.hasTeletext;
			tuner.SetTVFrequency(ch.freq)
		END NextCh;

		PROCEDURE PointerDown*(x, y : LONGINT; keys : SET);
		BEGIN
			lastX := bounds.l+x; lastY := bounds.t+y; dragging := TRUE
		END PointerDown;

		PROCEDURE PointerMove*(x,y : LONGINT; keys : SET);
		VAR dx, dy : LONGINT;
		BEGIN
			IF dragging THEN
				x := bounds.l + x; y := bounds.t + y; dx := x - lastX; dy := y - lastY;
				lastX := lastX + dx; lastY := lastY + dy;
				IF (dx # 0) OR (dy # 0) THEN manager.SetWindowPos(SELF, bounds.l + dx, bounds.t + dy) END
			END
		END PointerMove;

		PROCEDURE PointerUp*(x, y : LONGINT; Keys : SET);
		BEGIN
			dragging := FALSE
		END PointerUp;

		PROCEDURE Draw*(canvas : Graphics.Canvas; w, h, q : LONGINT);
		BEGIN
			Draw^(canvas, w, h, 0)
		END Draw;

		PROCEDURE Handle(VAR m : Messages.Message);
		VAR
			data : XML.Element;
			str : ARRAY 10 OF CHAR;
		BEGIN
			IF m.msgType = Messages.MsgKey THEN
				KeyEvent(m.x, m.flags, m.y)
			ELSIF m.msgType = Messages.MsgPointer THEN
				IF m.msgSubType = Messages.MsgSubPointerMove THEN PointerMove(m.x, m.y, m.flags)
				ELSIF m.msgSubType = Messages.MsgSubPointerDown THEN PointerDown(m.x, m.y, m.flags)
				ELSIF m.msgSubType = Messages.MsgSubPointerUp THEN PointerUp(m.x, m.y, m.flags)
				ELSIF m.msgSubType = Messages.MsgSubPointerLeave THEN PointerLeave
				END
			ELSIF m.msgType = Messages.MsgClose THEN Close
			ELSIF m.msgType = Messages.MsgStyleChanged THEN StyleChanged
			ELSIF (m.msgType = Messages.MsgExt) & (m.ext # NIL) THEN
				IF (m.ext IS WMRestorable.Storage) THEN
					NEW(data); data.SetName("TVData");
					Strings.IntToStr(vcdNr, str);
					data.SetAttributeValue("device", str);
					Strings.IntToStr(tuner.GetFrequency(), str);
					data.SetAttributeValue("freq", str);
					IF autoSwitch THEN
						data.SetAttributeValue("autoSwitch", "true")
					ELSE
						data.SetAttributeValue("autoSwitch", "false")
					END;
					m.ext(WMRestorable.Storage).Add("TV", "TV.Restore", SELF, data)
				ELSE Handle^(m)
				END
			ELSE Handle^(m)
			END;
		END Handle;

		(** Called when the TV frequency is changed. Adapt Teletext decoder etc. *)
		PROCEDURE HandleSwitch (freq : LONGINT; tuner : TVDriver.TVTuner);
		VAR
			i : LONGINT;
			ch : TVChannels.TVChannel;
			title : ARRAY 32 OF CHAR;
		BEGIN
			(* This procedure makes only sense if there are registered TV channels *)
			IF TVChannels.channels.GetCount() = 0 THEN RETURN END;

			(* Handle only channel switches that concern the current tuner *)
			IF SELF.tuner # tuner THEN
				RETURN
			END;

			(* Find the channel name for the current TV frequency *)
			i := 0;
			REPEAT
				ch := TVChannels.channels.GetItem (i);
				INC (i)
			UNTIL (i = TVChannels.channels.GetCount()) OR ((ch.freq-10 < freq) & (ch.freq + 10 > freq));

			(* Set the title of the TV window accordingly *)
			title := "TV";
			IF (ch.freq-10 < freq) & (ch.freq + 10 > freq) THEN
				Strings.Append (title, " - ");
				COPY(ch.name, chName);
				Strings.Append (title, chName)
			ELSE
				Strings.Append (title, " - unregistered channel")
			END;
			SetTitle (WM.NewString (title));
			(* Redirect VBI output to the appropriate channel *)
			IF vbi # NIL THEN
				(* Get rid of the VBI data of the old TV channel *)
				vbi.ResetAll;
				vbi.SetFrequency (freq)
			END
		END HandleSwitch;

		(** Enable teletext decoding and caching *)
		PROCEDURE StartTeletextCapture*;
		VAR
			status : LONGINT;
		BEGIN
			IF ~vcd.IsVbiOpen() THEN
				status := tuner.OpenVbi();
				IF status # 0 THEN
					KernelLog.String("{TV} Could not open Vbi device."); KernelLog.Ln;
					RETURN
				END;
				NEW(vbi, vcd)
			END
		END StartTeletextCapture;

		(** Stop Teletext caching. The previously cached data remains in memory *)
		PROCEDURE StopTeletextCapture*;
		BEGIN
			tuner.CloseVbi;
			IF vbi # NIL THEN
				vbi.Stop;
				vbi := NIL
			END
		END StopTeletextCapture;

		PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; keySym : LONGINT);
		VAR
			ch : CHAR;
		BEGIN
			ch := CHR(ucs);
			ch := Strings.LOW(ch);
			IF ch = "+" THEN
				chnlSeeker.StopSeeking;
				chnlSeeker.SetStepSize(5);
				chnlSeeker.StartSeeking;
			ELSIF ch = "-" THEN
				chnlSeeker.StopSeeking;
				chnlSeeker.SetStepSize(-5);
				chnlSeeker.StartSeeking;
			ELSIF ch = 'a' THEN
				StartAutoSwitch
			ELSIF ch = 'q' THEN
				StopAutoSwitch
			ELSIF ch = 'c' THEN
				IF vbi # NIL THEN
					KernelLog.String("{TV} ");
					KernelLog.String(chName);
					KernelLog.String(" Teletext contains ");
					KernelLog.Int(vbi.Count(), 0);
					KernelLog.String(" pages.");
					KernelLog.Ln
				END
			ELSIF ch = 't' THEN
				StartTeletextCapture
			ELSIF ch = 'e' THEN
				StopTeletextCapture
			ELSIF ch = "s" THEN
				chnlSeeker.StopSeeking;
			ELSIF ch = "n" THEN
				tuner.SetChannel(tuner.GetChannel()+1);
			ELSIF ch = "p" THEN
				tuner.SetChannel(tuner.GetChannel()-1);
			ELSIF ch = "1" THEN
				vcd.StopCaptureContinuous;
				vcd.SetGeometry(320, 240, 1, {});
				vcd.CaptureContinuous;
			ELSIF ch = "2" THEN
				vcd.StopCaptureContinuous;
				vcd.SetGeometry(640, 480, 1, {});
				vcd.CaptureContinuous;
			ELSIF ch = "m" THEN
				IF audio.IsAudioMute() THEN audio.SetAudioUnmute
				ELSE audio.SetAudioMute
				END
			END;
		END KeyEvent;

		(** Get the current TV frequency *)
		PROCEDURE GetTVFreq*() : LONGINT;
		BEGIN
			RETURN tuner.GetFrequency()
		END GetTVFreq;

		PROCEDURE NewImage;
		BEGIN {EXCLUSIVE}
			newImage := TRUE;
		(*	t := Kernel.GetTimer();
			IF t - last < 40 THEN KernelLog.String("Early."); KernelLog.Int(t - last, 5); KernelLog.Ln END;
			last := t *)
		END NewImage;

	BEGIN {ACTIVE}
		alive := TRUE; NEW(timer);
		WHILE alive DO
			BEGIN {EXCLUSIVE}
				AWAIT(newImage OR ~alive);
				newImage := FALSE
			END;
			IF alive THEN
				Invalidate(WMRectangles.MakeRect(0, 0, img.width, img.height))
			END
		END
	END TvWindow;

VAR
	windows : TvWindow;

(*
	noOfNotificationCalls : LONGINT;

PROCEDURE NotificationHandler;
BEGIN
	IF noOfNotificationCalls = 50 THEN
		noOfNotificationCalls := 0;
		IF DEBUG THEN KernelLog.String("{TV} notification handler was called 50 times."); KernelLog.Ln; END;
	ELSE
		INC(noOfNotificationCalls);
	END;
END NotificationHandler;
*)

(** Automatic channel tuning and naming based on Teletext information.
	   Be sure to install the TV card drivers before calling this routine
	   e.g. Aos.Call BT848.Install ~
	   You can give an optional filename to store the channel table
	   e.g. Aos.Call TV.BuildChannelTable ChTable.XML ~ *)
PROCEDURE BuildChannelTable* (context : Commands.Context);
VAR filename : ARRAY 100 OF CHAR;
BEGIN
	IF context.arg.GetString(filename) THEN
		BuildChannelTableImpl(filename);
	END;
END BuildChannelTable;

(** Automatic channel tuning and naming based on Teletext information. *)
PROCEDURE BuildChannelTableImpl(filename : ARRAY OF CHAR);
CONST
	Delay = 500;
VAR
	ch, max, i, found, length, res : LONGINT;
	tvWnd : TvWindow;
	tvCh : TVChannels.TVChannel;
	channels : TVChannels.ChannelList;
	suite : TeletextDecoder.TeletextSuite;
	vcd : TVDriver.VideoCaptureDevice;
	tuner : TVDriver.TVTuner;
	timer : Kernel.Timer;
	f : Files.File;
	w : Files.Writer;
	fileBak, lastName : ARRAY 33 OF CHAR;
	doc : XML.Document;
	chList, channel : XML.Element;
	comment : ARRAY 100 OF CHAR;
	xmlComment : XML.Comment;
	freq : ARRAY 10 OF CHAR;
BEGIN
	(* Get video capture device and open TV window *)
	vcd := TVDriver.GetDefaultDevice();
	IF vcd = NIL THEN
		KernelLog.String("{TV} BuildChannelTable: Fail to locate video capture device."); KernelLog.Ln;
		RETURN
	END;
	IF vcd.IsVideoOpen() THEN
		KernelLog.String("{TV} BuildChannelTable: Close TV window before channel installation."); KernelLog.Ln;
		RETURN
	END;
	NEW(tvWnd, vcd);
	tuner := vcd.GetTuner();
	IF tuner.OpenVbi() = 0 THEN
		NEW(tvWnd.vbi, vcd);
		tvWnd.vbi.extractName := TRUE
	END;

	(* Prepare channels list and teletext suite list *)
	NEW (TVChannels.channels);
	channels := TVChannels.channels;
	TeletextDecoder.teletextSuites := NIL;
	max := tuner.GetMaxChannel();

	KernelLog.String("{TV} Automatic channel installation "); KernelLog.Ln;
	KernelLog.String("{TV} This will take about ");
	KernelLog.Int(max*Delay DIV 1000, 0);
	KernelLog.String(" seconds."); KernelLog.Ln;

	found := 0;
	NEW (timer);

	FOR ch := 0 TO max-1 DO
		tuner.SetChannel (ch);

		IF TeletextDecoder.SelectTeletextSuite(tuner.GetFrequency()) = NIL THEN
			(* The current frequency has not already been found *)
			NEW (tvCh);
			tvCh.freq := tuner.GetFrequency();

			(* Suite must be built to store teletext data with channel name *)
			NEW (suite);
			suite.channel := tvCh;
			suite.next := TeletextDecoder.teletextSuites;
			TeletextDecoder.teletextSuites := suite;

			(* Wait for valid data *)
			timer.Sleep (Delay);

			FOR i := 0 TO 12 DO
				tvCh.name[i] := tvWnd.vbi.chName[i]
			END;

			IF (Strings.Length (tvCh.name) = 0) OR (Strings.Match(tvCh.name, lastName)) THEN
				(* This channel does not provide its name => discard it *)
				TeletextDecoder.teletextSuites := TeletextDecoder.teletextSuites.next
			ELSE
				(* Hooray, new channel found! *)
				INC(found);
				channels.Add(tvCh);
				COPY (tvCh.name, lastName)
			END
		END
	END;
	KernelLog.String("{TV} Automatic channel installation done.");
	KernelLog.Ln;
	KernelLog.String("{TV} Found "); KernelLog.Int(found, 0); KernelLog.String(" channels");
	KernelLog.Ln;
	tvWnd.Close;

	(* Write the table to disk *)
	IF found > 0 THEN
		f := Files.Old (ChannelFile);
		IF f # NIL THEN
			(* File existed before: Make Backup *)
(*			filename := ChannelFile;	*)
			COPY(ChannelFile, filename);
			fileBak := ChannelFile;
			length := Strings.Length (fileBak);
			fileBak[length-3] := 'B';
			fileBak[length-2] := 'a';
			fileBak[length-1] := 'k';
			Files.Rename (filename, fileBak, res);
			IF res # 0 THEN
				KernelLog.String("{TV} Error backing up existing channel file.");
				KernelLog.Ln
			END;
			KernelLog.String("{TV} Original file was backed up to '");
			KernelLog.String(fileBak);
			KernelLog.String("'");
			KernelLog.Ln
		END;

		(* Header of the document *)
		NEW(doc);
		NEW(xmlComment);
		comment := "TV channels; Auto-generated settings.";
		xmlComment.SetStr(comment);
		doc.AddContent(xmlComment);
		NEW(xmlComment);
		Strings.DateToStr(Dates.Now(), comment);
		Strings.Concat("This file was created on ", comment, comment);
		xmlComment.SetStr(comment);
		doc.AddContent(xmlComment);

		(* Channel list *)
		NEW(chList); chList.SetName("TVChannelList");
		FOR i := 0 TO channels.GetCount() -1 DO
			tvCh := channels.GetItem(i);
			Strings.IntToStr(tvCh.freq, freq);
			NEW(channel); channel.SetName("Channel");
			channel.SetAttributeValue("name", tvCh.name);
			channel.SetAttributeValue("freq", freq);
			chList.AddContent(channel)
		END;
		doc.AddContent(chList);

		IF filename = "" THEN
(*			filename := ChannelFile	*)
			COPY(ChannelFile, filename)
		END;
		f := Files.New (filename);
		Files.OpenWriter (w, f, 0);
		doc.Write(w, NIL, 0);
		w.Update;
		Files.Register (f)
	END
END BuildChannelTableImpl;

(** Open a TV window.
	   Make sure that a TV card driver is installed first
	   Usage: TV.Open [deviceNo] [TXT] ~	*)
PROCEDURE Open*(context : Commands.Context);
VAR
	tvWnd : TvWindow;
	vcd : TVDriver.VideoCaptureDevice;
	devNr : LONGINT;
	param : ARRAY 32 OF CHAR;
BEGIN
	IF context # NIL THEN
		(* Attempt to read video capture device number *)
		IF context.arg.GetInteger(devNr, FALSE) THEN
			context.out.String("{TV} Open device #"); context.out.Int(devNr, 0); context.out.Ln;
			vcd := TVDriver.GetVideoDevice(devNr);
			context.arg.SkipWhitespace; context.arg.String(param);
		ELSE
			vcd := TVDriver.GetDefaultDevice()
		END
	ELSE
		vcd := TVDriver.GetDefaultDevice()
	END;
	(* Display error message if the specified parameter was invalid *)
	IF vcd = NIL THEN
		IF (context # NIL) & (context.arg.res = 0) THEN
			context.error.String("{TV} Parameter is not a valid video device number."); context.error.Ln;
			WMDialogs.Error("TV - Error", "Parameter is not a valid video device number");
			RETURN;
		ELSE
			context.error.String("{TV} Cannot open TV window: Fail to locate video capture device.");
			context.error.Ln;
			 WMDialogs.Error("TV - Error",
				"Cannot open TV window: Fail to locate video capture device. Install device before opening the TV window. Example: BT848.Install");
			RETURN;
		END
	END;
	(* open video device only if it is not already open *)
	IF ~ vcd.IsVideoOpen() THEN
		NEW(tvWnd, vcd);
		(* Set the device number for non-default devices *)
		IF devNr # -1 THEN
			tvWnd.vcdNr := devNr
		END;
		(* Check if argument invokes automatic Teletext caching *)
		Strings.UpperCase(param);
		IF param = 'TXT' THEN
			tvWnd.StartTeletextCapture;
			tvWnd.StartAutoSwitch
		END
	END;
END Open;

(** Restore the TV window(s) stored on disk *)
PROCEDURE Restore*(context : WMRestorable.Context);
VAR
	manager : WM.WindowManager;
	xml : XML.Element;
	s : Strings.String;
	i : LONGINT;
	vcd : TVDriver.VideoCaptureDevice;
	tuner : TVDriver.TVTuner;
	tvWnd : TvWindow;
BEGIN
	IF context # NIL THEN
		(* restore the desktop *)
		IF context.appData # NIL THEN
			xml := context.appData(XML.Element);
			(* Read the device number *)
			s := xml.GetAttributeValue("device");
			IF s # NIL THEN
				Strings.StrToInt(s^, i);
				IF i = -1 THEN
					vcd := TVDriver.GetDefaultDevice()
				ELSE
					vcd := TVDriver.GetVideoDevice(i)
				END;
				IF (vcd # NIL) & (~ vcd.IsVideoOpen()) THEN
					NEW(tvWnd, vcd);
					manager := WM.GetDefaultManager();
					manager.Remove(tvWnd)
				END
			END;
			(* Read the TV frequency *)
			s := xml.GetAttributeValue("freq");
			IF (s # NIL) & (vcd # NIL) THEN
				tuner := vcd.GetTuner();
				Strings.StrToInt(s^, i);
				tuner.SetTVFrequency(i)
			END;
			(* Read the autoswitch setting *)
			s := xml.GetAttributeValue("autoSwitch");
			IF (s # NIL) & (s^ = "true") & (tvWnd # NIL) THEN
				tvWnd.StartAutoSwitch
			END;
			IF tvWnd # NIL THEN
				WMRestorable.AddByContext(tvWnd, context)
			ELSE
				KernelLog.String("{TV} Could not restore the TV window."); KernelLog.Ln;
				IF vcd = NIL THEN
					KernelLog.String("{TV} Install the device driver first, e.g. BT848.Install"); KernelLog.Ln
				ELSE
					KernelLog.String("{TV} The selected TV window is already open."); KernelLog.Ln
				END
			END
		END
	END
END Restore;

(* Remove the window from the internal list *)
PROCEDURE FreeWindow(tvWnd : TvWindow);
VAR
	w : TvWindow;
BEGIN
	IF tvWnd = NIL THEN
		RETURN
	ELSIF tvWnd = windows THEN
		(* tvWnd is first list element *)
		windows := windows.nextINchain
	ELSE
		w := windows;
		WHILE (w # NIL) & (w.nextINchain # tvWnd) DO
			w := w.nextINchain
		END;
		IF w # NIL THEN
			(* tvWnd found: remove it from the list *)
			w.nextINchain := tvWnd.nextINchain
		END
	END
END FreeWindow;

(** Term handler *)
PROCEDURE Cleanup;
VAR
	w : TvWindow;
BEGIN
	w := windows;
	WHILE w # NIL DO
		w.Close;
		w := w.nextINchain
	END;
	windows := NIL
END Cleanup;

BEGIN
	IF TVChannels.channels.GetCount() = 0 THEN
		KernelLog.String("{TV} No channels detected. Performing auto-detection.");
		KernelLog.Ln;
		BuildChannelTableImpl (ChannelFile)
	END;
	Modules.InstallTermHandler(Cleanup)
END TV.


SystemTools.Free TV ~

Usage: TV.Open [ [deviceNr] TXT ] ~

Requires driver installation, e.g. BT848.Install ~
and valid TVChannels.XML file.

