MODULE WMCDRecorder;

IMPORT
	WMWindowManager, WMComponents, WMStandardComponents, WMGrids, WMStringGrids, WMMessages, WMDialogs,
 	WMEvents, Objects, Kernel, WMProperties, WMGraphics, WMEditors, WMTrees, WMRectangles, WMPopups, WMDropTarget,
 	Modules, Disks, XMLObjects, Files, Strings, CDRecord, Lib := CDRecordLib, MakeIsoImages, Utils := CDRecordUtils;

CONST
	Title = "CD Recording Tool";
	White = 0FFFFFFFFH;
	Black = 0000000FFH;
	LightGray = 0C8C8C8FFH;
	DarkGray = 0A0A0A0FFH;
	Blue = 00000FFFFH;
	MaxLen = 256;
	ResOk=0; ResErr=1;
	DefaultImageLocation = "AOS:Image.Iso";
	DefaultWaveLocation = "AOS:"; (* temporary location for converted mp3 files *)

	BBMinISOSize = 512; (* the minimum size in sectors of an iso image to be mountable in Bluebottle *)
	BBMultisessionCapable = FALSE; (* no multisession support in bluebottle  *)

	(* Data Session *)
	NoMultisession = 0;
	StartMultisession = 1;
	ContinueMultisession = 2;
	FinishMultisession = 3;
	BootSession = 4;

	(* Tools *)
	OpenIsoTool = 0;
	CopyIsoTool = 1;
	BlankTool = 2;
	DiscInfo = 3;

TYPE
	KillerMsg = OBJECT END KillerMsg;

	Directory = MakeIsoImages.Directory;

	Window* = OBJECT (WMComponents.FormWindow)
		VAR
			workPanel, mainPanel, toolPanel, filePanel,leftPanel, statusBar: WMStandardComponents.Panel;
			projectPanel: ProjectPanel;
			audioBtn, dataBtn, burnBtn, toolBtn, refreshBtn: WMStandardComponents.Button;
			explorer: Utils.ExplorerPanel;
			sizeLabel: WMStandardComponents.Label;
			overheadLabel: WMStandardComponents.Label;
			burnPanel: BurnPanel;
			onStatusChanged : WMEvents.EventSource;

		PROCEDURE &New*;
		VAR
			vc: WMComponents.VisualComponent;
		BEGIN
			IncCount();
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetTitle(Strings.NewString(Title));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMCDRecorder.png", TRUE));
			WMWindowManager.DefaultAddWindow(SELF);
			NEW(onStatusChanged, SELF, NIL, NIL, NIL);
			 onStatusChanged.Add(StatusChanged);
		END New;

		PROCEDURE ShowBurnPanel;
		BEGIN
			workPanel.visible.Set(FALSE);
			burnPanel.visible.Set(TRUE);
			burnPanel.ResetAll();
			EnableWindow(FALSE);
		END ShowBurnPanel;

		PROCEDURE ShowWorkPanel;
		BEGIN
			burnPanel.visible.Set(FALSE);
			workPanel.visible.Set(TRUE);
			EnableWindow(TRUE);
		END ShowWorkPanel;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			resizer: WMStandardComponents.Resizer;
			label: WMStandardComponents.Label;
		BEGIN
			NEW(mainPanel);
			mainPanel.bounds.SetExtents(600, 400);
			mainPanel.fillColor.Set(White);

			NEW(toolPanel);
			toolPanel.bounds.SetHeight(20);
			toolPanel.fillColor.Set(LightGray);
			toolPanel.alignment.Set(WMComponents.AlignTop);
			mainPanel.AddContent(toolPanel);

			NEW(statusBar);
			statusBar.bounds.SetHeight(20);
			statusBar.fillColor.Set(LightGray);
			statusBar.alignment.Set(WMComponents.AlignBottom);
			mainPanel.AddContent(statusBar);

			NEW(label);
			label.bounds.SetWidth(40);
			label.alignment.Set(WMComponents.AlignLeft);
			label.caption.SetAOC("Size:");
			label.textColor.Set(Black);
			statusBar.AddContent(label);

			NEW(sizeLabel);
			sizeLabel.bounds.SetWidth(200);
			sizeLabel.alignment.Set(WMComponents.AlignLeft);
			sizeLabel.textColor.Set(Black);
			statusBar.AddContent(sizeLabel);

			NEW(audioBtn);
			audioBtn.bounds.SetWidth(100);
			audioBtn.alignment.Set(WMComponents.AlignLeft);
			audioBtn.caption.SetAOC("Audio Project");
			audioBtn.onClick.Add(ProjectHandler);
			toolPanel.AddContent(audioBtn);

			NEW(dataBtn);
			dataBtn.bounds.SetWidth(100);
			dataBtn.alignment.Set(WMComponents.AlignLeft);
			dataBtn.caption.SetAOC("Data Project");
			dataBtn.onClick.Add(ProjectHandler);
			toolPanel.AddContent(dataBtn);

			NEW(burnBtn);
			burnBtn.bounds.SetWidth(100);
			burnBtn.alignment.Set(WMComponents.AlignLeft);
			burnBtn.caption.SetAOC("Burn");
			burnBtn.onClick.Add(BurnHandler);
			toolPanel.AddContent(burnBtn);

			NEW(refreshBtn);
			refreshBtn.bounds.SetWidth(100);
			refreshBtn.alignment.Set(WMComponents.AlignRight);
			refreshBtn.caption.SetAOC("Refresh FS");
			refreshBtn.onClick.Add(RefreshHandler);
			toolPanel.AddContent(refreshBtn);

			NEW(toolBtn);
			toolBtn.bounds.SetWidth(100);
			toolBtn.alignment.Set(WMComponents.AlignRight);
			toolBtn.caption.SetAOC("Tools");
			toolBtn.onClick.Add(ToolHandler);
			toolPanel.AddContent(toolBtn);

			NEW(resizer);
			resizer.alignment.Set(WMComponents.AlignLeft);
			resizer.bounds.SetWidth(8);

			NEW(workPanel);
			workPanel.alignment.Set(WMComponents.AlignClient);
			mainPanel.AddContent(workPanel);

			NEW(burnPanel);
			burnPanel.alignment.Set(WMComponents.AlignClient);
			burnPanel.fillColor.Set(DarkGray);
			burnPanel.visible.Set(FALSE);
			mainPanel.AddContent(burnPanel);

			NEW(filePanel);
			filePanel.alignment.Set(WMComponents.AlignRight);
			filePanel.bounds.SetWidth(300);
			workPanel.AddContent(filePanel);

			NEW(resizer);
			resizer.alignment.Set(WMComponents.AlignLeft);
			resizer.bounds.SetWidth(4);
			filePanel.AddContent(resizer);

			NEW(explorer);
			explorer.alignment.Set(WMComponents.AlignClient);
			explorer.fillColor.Set(White);
			filePanel.AddContent(explorer);

			NEW(leftPanel);
			leftPanel.alignment.Set(WMComponents.AlignClient);
			leftPanel.fillColor.Set(White);
			workPanel.AddContent(leftPanel);

			RETURN mainPanel;
		END CreateForm;

		PROCEDURE EnableWindow(enable: BOOLEAN);
		BEGIN
			EnableComponents(toolPanel, enable);
		END EnableWindow;

		PROCEDURE EnableComponents(component: WMComponents.Component; enable: BOOLEAN);
		VAR
			enum: XMLObjects.Enumerator;
			p: ANY;
		BEGIN
			enum := component.GetContents();
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS WMComponents.Component THEN
					EnableComponents(p(WMComponents.Component), enable);
					p(WMComponents.Component).enabled.Set(enable);
				END;
			END;
		END EnableComponents;

		PROCEDURE Resized(width, height: LONGINT);
		VAR
			oldWidth: LONGINT;
			factor: REAL;
		BEGIN
			oldWidth := leftPanel.bounds.GetWidth() + filePanel.bounds.GetWidth();
			factor := width / oldWidth;
			filePanel.bounds.SetWidth(ENTIER(factor * filePanel.bounds.GetWidth()));
			Resized^(width, height);
		END Resized;

		PROCEDURE UpdateSize(size, overhead: LONGINT);
		VAR
			text, tmp: ARRAY 16 OF CHAR;
			total: LONGINT;
		BEGIN
			total := (size + 1024 - 1) DIV 1024;
			Strings.IntToStr(total, text);
			IF overhead > 0 THEN
				Strings.Append(text, " (");
				overhead := (overhead + 1024 + 1) DIV 1024;
				Strings.IntToStr(overhead , tmp);
				Strings.Append(text, tmp);
				Strings.Append(text, ")");
			END;
			Strings.Append(text, " KB");
			sizeLabel.caption.SetAOC(text);
		END UpdateSize;

		PROCEDURE IdentifyRecorders(): LONGINT;
		VAR
			res: LONGINT;
			dlg: WaitDialog;
			ticks : LONGINT;
		BEGIN
			NEW(dlg, Strings.NewString("Waiting"), bounds, 200, 100, TRUE);
			dlg.SetText("Identifying recorders");
			dlg.ShowNonModal;
			ticks := Kernel.GetTicks ();
			res := CDRecord.IdentifyRecorders(recorders);
			WHILE (res # ResOk) & (dlg.result # WMDialogs.ResAbort) & (Kernel.GetTicks () < ticks + 8000) DO
				Objects.Yield();
				res := CDRecord.IdentifyRecorders(recorders);
			END;
			IF (dlg # NIL) & (dlg.result # WMDialogs.ResAbort) THEN
				dlg.Close();
			END;
			IF recorders[0] = NIL THEN res := ResErr END;
			IF res # ResOk THEN
				WMDialogs.Error("", "No recorder found");
			END;
			RETURN res;
		END IdentifyRecorders;

		PROCEDURE ToolHandler(sender, data: ANY);
		VAR
			dlg: ToolDialog;
			handler: Handler;
		BEGIN
			NEW(dlg, Strings.NewString("Tools"), bounds, 300, 200);
			dlg.Show();
			IF dlg.result = WMDialogs.ResOk THEN
				CASE dlg.tool OF
					  OpenIsoTool: NEW(handler, OpenHandler, data);
					| CopyIsoTool: NEW(handler,  CopyHandler, data);
					| BlankTool: NEW(handler,  BlankHandler, data);
					| DiscInfo: InfoHandler(SELF, NIL);
				END;
			END;
		END ToolHandler;

		PROCEDURE InfoHandler(sender, data: ANY);
		VAR
			recDlg: RecorderDialog;
			infoDlg: InfoDialog;
			recorder: CDRecord.CDRecorder;
			disc: CDRecord.Disc; discEx: CDRecord.DiscEx;
		BEGIN
			IF IdentifyRecorders() # ResOk THEN RETURN END;
			NEW(recDlg, Strings.NewString("Blank"), bounds, 300, 200);
			recDlg.Show();
			IF recDlg.result # ResOk THEN RETURN END;
			recorder := recDlg.recorder;
			IF WaitOnDisc(recorder) # ResOk THEN RETURN END;
			NEW(disc); NEW(discEx);
			IF recorder.GetDiscInfo(disc) # ResOk THEN
				WMDialogs.Error(Title, "Could not read disc information");
				RETURN;
			ELSIF recorder.GetDiscInfoEx(discEx) = ResOk THEN
				disc := discEx;
			END;
			NEW(infoDlg, Strings.NewString("Blank"), bounds, 300, 200, disc);
			infoDlg.Show();
		END InfoHandler;

		PROCEDURE CopyHandler(sender, data: ANY);
		VAR
			copyDlg: CopyDialog;
			waitDlg: WaitDialog;
			recorder: CDRecord.CDRecorder;
			disc: CDRecord.Disc;
			compilation: CDRecord.Compilation;
			res, tmp, startsec, size, freeSpace: LONGINT;
			toc: Lib.TocDescriptor;
			dest: String;
			pvd: MakeIsoImages.PSVolumeDescriptor;
			readOnly: BOOLEAN;
			msg: ARRAY MaxLen OF CHAR;
		BEGIN
			IF IdentifyRecorders() # ResOk THEN RETURN END;
			NEW(copyDlg, Strings.NewString("Copy"), bounds, 300, 400);
			copyDlg.Show();
			IF copyDlg.result # WMDialogs.ResOk THEN RETURN END;
			dest := copyDlg.sourcePage.location.Get();
			RemoveSpecialChars(dest^);
			recorder := copyDlg.sourcePage.recorder;

			IF WaitOnDisc(recorder) # ResOk THEN RETURN END;
			NEW(disc);
			IF recorder.GetDiscInfo(disc) # ResOk THEN
				WMDialogs.Error(Title, "Could not read disc information");
				RETURN;
			END;

			IF disc.status # Lib.DSComplete THEN
				WMDialogs.Error(Title, "Only finalized discs can be copied");
				RETURN;
			ELSIF disc.nofSessions # 1 THEN
				WMDialogs.Error(Title, "Only single session discs can be copied");
				RETURN;
			END;
			(* check if disc contains digital data *)
			IF Lib.GetTrackDescriptor(recorder.dev, 1, toc) # ResOk THEN
				WMDialogs.Error(Title, "Cannot read toc");
				RETURN;
			END;
			IF ~Lib.CheckBit(CHR(Lib.GetField(toc.Byte1, Lib.TCControlMask, Lib.TCControlOfs)), Lib.QCDataTrack) THEN
				WMDialogs.Error(Title, "Not a Data Disc");
				RETURN;
			END;
			startsec := Utils.ConvertBE32Int(toc.TrackStartAdr);

			recorder.UpdateCapacity();
			IF MakeIsoImages.GetVolumeDescriptor(recorder.dev, startsec, pvd, MakeIsoImages.Primary) # ResOk THEN RETURN END;
			size := Utils.ConvertLE32Int(pvd.VolSpaceSize);

			IF (Utils.IsReadOnly(dest^, readOnly) # ResOk) OR (Utils.GetFreeSpace(dest^, freeSpace) # ResOk) THEN
				COPY(dest^, msg); Strings.Append(msg, " seems to be invalid");
				WMDialogs.Error(Title, msg);
				RETURN;
			END;
			IF readOnly THEN
				 WMDialogs.Error(Title, "Destination volume is read only");
				RETURN;
			ELSIF ((size * MakeIsoImages.SectorSize) DIV 1024) > freeSpace THEN
				 WMDialogs.Error(Title, "Not enough Space for image");
				RETURN;
			END;
			UpdateSize(disc.usedBlocks*MakeIsoImages.SectorSize, 0);
			ShowBurnPanel();
			burnPanel.SetTitle0(Strings.NewString("Reading source"));
			burnPanel.progress0.SetRange(0, (size * MakeIsoImages.SectorSize) DIV 1024 );
			burnPanel.progress0.SetPos(0);
			IF MakeIsoImages.SaveImage(recorder.dev, startsec, dest^, UpdateStatus) # ResOk THEN
				burnPanel.Terminate(TRUE);
				ShowWorkPanel();
				RETURN;
			END;
			res := recorder.dev.MediaEject(FALSE, FALSE);
			IF WMDialogs.Message(WMDialogs.TInformation, "Record", "Insert Empty Medium", {WMDialogs.ResAbort, WMDialogs.ResYes}) = WMDialogs.ResAbort THEN
				burnPanel.Terminate(TRUE);
				ShowWorkPanel();
				RETURN;
			END;
			NEW(compilation);
		 	res := compilation.AddTrack(dest, CDRecord.DataTrack, FALSE);
		 	IF res # ResOk THEN
		 		burnPanel.Terminate(TRUE);
		 		ShowWorkPanel();
		 		RETURN;
		 	END;
		 	compilation.Finish();
			burnPanel.progress1.SetRange(0, compilation.GetSize(FALSE, TRUE));
			res := Record(compilation, copyDlg.burnPage.recorder,copyDlg. burnPage.settings);
			(* delete the image if desired *)
		 	IF copyDlg.sourcePage.remove.Get() & FileExists(dest^) THEN
		 		NEW(waitDlg, Strings.NewString("Please Wait"), bounds, 200, 100, FALSE);
				waitDlg.SetText("Removing iso image");
				waitDlg.ShowNonModal;
		 		Files.Delete(dest^, tmp);
		 		waitDlg.Close();
		 	END;
			IF res = ResOk THEN
				burnPanel.Terminate(FALSE);
			ELSE
				burnPanel.Terminate(TRUE);
			END;
			ShowWorkPanel();
		END CopyHandler;

		PROCEDURE BlankHandler(sender, data: ANY);
		VAR
			recDlg: RecorderDialog;
			typeDlg: BlankTypeDialog;
			disc: CDRecord.Disc;
			recorder: CDRecord.CDRecorder;
			res: LONGINT;
			waitDlg: WaitDialog;
		BEGIN
			IF IdentifyRecorders() # ResOk THEN RETURN END;
			NEW(recDlg, Strings.NewString("Blank"), bounds, 300, 200);
			recDlg.Show();
			IF recDlg.result # ResOk THEN RETURN END;
			recorder := recDlg.recorder;
			IF WaitOnDisc(recorder) # ResOk THEN RETURN END;
			NEW(disc);
			IF recorder.GetDiscInfo(disc) # ResOk THEN
				WMDialogs.Error(Title, "Could not read disc information");
				RETURN;
			END;
			IF ~disc.erasable THEN
				WMDialogs.Error(Title, "Inserted disc is not eraseble");
				RETURN;
			END;
			NEW(typeDlg, Strings.NewString("Blank Type"), bounds, 300, 200);
			typeDlg.Show();
			IF typeDlg.result # ResOk THEN RETURN END;

			NEW(waitDlg, Strings.NewString("Waiting"), bounds, 200, 100, FALSE);
			waitDlg.SetText("Erasing. Please Wait.");
			waitDlg.abort.visible.Set(FALSE);
			waitDlg.ShowNonModal();
			res := Lib.Blank(recorder.dev, TRUE, typeDlg.type, Lib.Ignore);
			IF res # ResOk THEN
				WMDialogs.Error(Title, "An error occured during erase operation");
				RETURN;
			END;
			recorder.WaitUntilFinished();
			waitDlg.Close();
			 WMDialogs.Information(Title, "Disc successfully erased");
		END BlankHandler;

		PROCEDURE OpenHandler(sender, data: ANY);
		VAR
			imageDlg: ImageDialog;
			file: Files.File;
			info: MakeIsoImages.ISOInfo;
			compilation: CDRecord.Compilation;
			image: String;
			res : LONGINT;
		BEGIN
			IF IdentifyRecorders() = ResErr THEN RETURN END;
			NEW(imageDlg, Strings.NewString("Burn"), bounds, 300, 400);
			imageDlg.Show();
			IF imageDlg.result = WMDialogs.ResOk THEN
				burnPanel.progress0.visible.Set(FALSE);
				ShowBurnPanel();
				image := imageDlg.imagePage.location.Get();
				file := Files.Old(image^);
				IF file # NIL THEN
					NEW(info);
					IF  info.Open(image) = ResOk THEN
						NEW(compilation);
						res := compilation.AddTrack(image, CDRecord.DataTrack, FALSE);
						compilation.Finish();
						UpdateSize(compilation.GetSize(FALSE, FALSE), 0);
						burnPanel.progress1.SetRange(0, compilation.GetSize(FALSE, TRUE));
						res := Record(compilation, imageDlg.burnPage.recorder, imageDlg.burnPage.settings);
					ELSE
						res := ResErr;
						WMDialogs.Error(Title, "not an iso file");
					END;
				ELSE
					res := ResErr;
					WMDialogs.Error(Title, "image not found");
				END;

				IF res = ResOk THEN
		 			burnPanel.Terminate(FALSE);
		 		ELSE
		 			burnPanel.Terminate(TRUE);
		 		END;
		 		ShowWorkPanel();
			END;
		END OpenHandler;

		PROCEDURE ProjectHandler(sender, data: ANY);
		VAR
			audioPanel: AudioPanel;
			dataPanel: DataPanel;
			sessDlg: SessionDialog;
			bootDlg: BootDialog;
			res: LONGINT;
			audioProject: AudioProject;
			dataProject: DataProject;
		BEGIN
			IF projectPanel # NIL THEN
				leftPanel.RemoveContent(projectPanel);
				projectPanel := NIL;
			END;
			IF sender = audioBtn THEN
				NEW(audioProject);
				NEW(audioPanel, audioProject);
				projectPanel := audioPanel;
				UpdateSize(0, 0);
			ELSIF sender = dataBtn THEN
				NEW(dataProject);
				NEW(sessDlg, Strings.NewString("Burn"), bounds, 300, 200);
				sessDlg.Show();
				IF sessDlg.result # WMDialogs.ResOk THEN RETURN END;
				dataProject.session := sessDlg.session;
				IF ((sessDlg.session = StartMultisession) OR (sessDlg.session = ContinueMultisession)) & ~BBMultisessionCapable THEN
					res := WMDialogs.Message(WMDialogs.TQuestion, Title, "Multisession discs are not yet supported in Bluebottle. Only first session will be readable. Continue?" , {WMDialogs.ResYes, WMDialogs.ResNo});
					IF res = WMDialogs.ResNo THEN RETURN END;
				END;
				IF (sessDlg.session = ContinueMultisession) OR (sessDlg.session = FinishMultisession) THEN
					IF ReadSessionData(dataProject) # ResOk THEN RETURN END;
				ELSIF sessDlg.session = BootSession THEN
					NEW(bootDlg, Strings.NewString("Boot"), bounds, 300, 400);
					bootDlg.Show();
					IF bootDlg.result # ResOk THEN RETURN END;
					IF bootDlg.bootCatalog = NIL THEN
						WMDialogs.Error(Title, "Boot Image not found");
						RETURN;
					END;
					dataProject.bootCatalog := bootDlg.bootCatalog;
					dataProject.totalSize := bootDlg.imageSize;
				END;
				NEW(dataPanel, dataProject);
				projectPanel := dataPanel;
				UpdateSize(dataProject.totalSize, dataProject.overhead);
			END;
			projectPanel.owner := SELF;
			projectPanel.alignment.Set(WMComponents.AlignClient);
			leftPanel.AddContent(projectPanel);
			projectPanel.Reset(NIL, NIL);
			projectPanel.Invalidate();
			leftPanel.Resized();
		END ProjectHandler;

		PROCEDURE ReadSessionData(project: DataProject): LONGINT;
		VAR
			adr, startSec: LONGINT;
			recDlg: RecorderDialog;
			recorder: CDRecord.CDRecorder;
			info:Lib.SessionInfo;
			reader: MakeIsoImages.ISOReader;
		BEGIN
			IF IdentifyRecorders() # ResOk THEN RETURN ResErr END;
			NEW(recDlg, Strings.NewString("Multisession"), bounds, 300, 200);
			recDlg.Show();
			IF recDlg.result # ResOk THEN RETURN ResErr END;

			recorder := recDlg.recorder;
			(* first check if recorder is multisession capable *)
			IF ~(CDRecord.MFMultisession IN recorder.cap.mediaFunc) THEN
				WMDialogs.Error(Title, "Selected Recorder does not support Multisession");
				RETURN ResErr;
			END;
			IF WaitOnDisc(recorder) # ResOk THEN RETURN ResErr END;
			IF Lib.ReadSessionInfo(recorder.dev, info) # ResOk THEN
				WMDialogs.Error(Title, "Cannot read session info");
				RETURN ResErr;
			END;
			IF Lib.GetNextAddress(recorder.dev, adr) # ResOk THEN
				WMDialogs.Error(Title, "medium is full or finalized");
				RETURN ResErr;
			END;
			project.isoOfs := adr;

			startSec := Utils.ConvertBE32Int(info.StartAdrFirstTrack);
			NEW(reader, recorder.dev);
			recorder.UpdateCapacity();
			IF reader.Read(startSec) # ResOk THEN
				RETURN ResErr;
			END;
			project.root := reader.tree.root;
			project.totalSize := reader.tree.sizeFiles;
			project.oldSize := project.totalSize;
			project.overhead := adr*MakeIsoImages.SectorSize-project.oldSize;
			RETURN ResOk;
		END ReadSessionData;

		PROCEDURE WaitOnDisc(recorder: CDRecord.CDRecorder): LONGINT;
		VAR
			res: LONGINT;
			waitDlg: WaitDialog;
		BEGIN
			NEW(waitDlg, Strings.NewString("Waiting"), bounds, 200, 100, TRUE);
			REPEAT
				waitDlg.SetText("Recorder not ready. Please Wait.");
				waitDlg.ShowNonModal();

				REPEAT
					Objects.Yield();
					res := recorder.dev.RequestSense();
					IF recorder.CheckNoMediumPresent() THEN res := 3008 END;
				UNTIL recorder.IsReady() OR (res = 3008) OR (waitDlg.result = WMDialogs.ResAbort);

				IF waitDlg.result = WMDialogs.ResAbort THEN
					RETURN ResErr;
				ELSE
					waitDlg.Close();
				END;
				IF res = 3008 THEN
					IF WMDialogs.Message(WMDialogs.TAction, "Not Ready", "No Medium present"  , {WMDialogs.ResOk, WMDialogs.ResAbort}) = WMDialogs.ResAbort THEN
						RETURN ResErr;
					END;
				END;
			UNTIL recorder.IsReady();
			RETURN ResOk;
		END WaitOnDisc;

		PROCEDURE BurnHandler(sender, data: ANY);
		VAR handler: Handler;
		BEGIN
			IF projectPanel = NIL THEN
				WMDialogs.Error(Title, "Please create a project first");
				RETURN;
			ELSE
				IF projectPanel.project.totalSize <= 0 THEN
					WMDialogs.Error(Title, "Project is empty");
					RETURN;
				END;
				IF (projectPanel IS DataPanel) & (projectPanel.project.totalSize - projectPanel.project(DataProject).oldSize <=0) THEN
					WMDialogs.Error(Title, "No New Data Added");
					RETURN;
				END;
				IF projectPanel IS AudioPanel THEN
					NEW(handler, BurnAudioHandler, data);
				ELSIF projectPanel IS DataPanel THEN
					NEW(handler, BurnDataHandler, data);
				END;
			END;
		END BurnHandler;

		PROCEDURE BurnAudioHandler(sender, data: ANY);
		VAR
			audioDlg: AudioDialog;
			waitDlg: WaitDialog;
			tmp, res, freeSpace, wavSpace: LONGINT;
			dest:String;
			cur: Node;
			project: AudioProject;
			compilation: CDRecord.Compilation;
			msg: ARRAY MaxLen OF CHAR;
			readOnly: BOOLEAN;
		BEGIN
			project := projectPanel.project(AudioProject);
			IF IdentifyRecorders() = ResErr THEN RETURN END;
			NEW(audioDlg, Strings.NewString("Burn"), bounds, 300, 400);
			audioDlg.Show();
			IF audioDlg.result = WMDialogs.ResOk THEN
				dest := audioDlg.audioPage.location.Get();
				IF (Utils.IsReadOnly(dest^, readOnly) # ResOk) OR (Utils.GetFreeSpace(dest^, freeSpace) # ResOk) THEN
					COPY(dest^, msg); Strings.Append(msg, " seems to be invalid");
					WMDialogs.Error(Title, msg);
					RETURN;
				END;
				wavSpace := GetWavSpace(project);
				IF wavSpace > 0 THEN
					IF readOnly THEN
						WMDialogs.Error(Title, "Destination volume is read only");
						RETURN;
					ELSIF (wavSpace DIV 1024) > freeSpace THEN
						WMDialogs.Error(Title, "Not enough Space for wav Files");
						RETURN;
					END;
				END;
				burnPanel.progress0.visible.Set(FALSE);
				ShowBurnPanel();
				res := Convert(project, dest);
				IF res = ResErr THEN
					 WMDialogs.Error(Title, "an error occured during the conversion");
				ELSE
					NEW(compilation);
					cur := project.root(Node);
					WHILE (cur # NIL) & (res = ResOk) DO
						res := compilation.AddTrack(cur.convName, CDRecord.AudioTrack, FALSE);
						cur := cur.next;
					END;
					IF res = ResOk THEN
						compilation.Finish();
						burnPanel.progress1.SetRange(0, compilation.GetSize(FALSE, TRUE));
						res := Record(compilation, audioDlg.burnPage.recorder, audioDlg.burnPage.settings);
					END;
				END;
				(* delete the converted if desired *)
				IF audioDlg.audioPage.remove.Get() THEN
					NEW(waitDlg, Strings.NewString("Please Wait"), bounds, 200, 100, FALSE);
					waitDlg.SetText("Removing iso image");
					waitDlg.ShowNonModal;
					cur := project.root(Node);
					WHILE cur # NIL DO
		 				IF cur.mp3 & FileExists(cur.convName^) THEN
		 					Files.Delete(cur.convName^, tmp);
		 				END;
		 				cur := cur.next;
		 			END;
		 			waitDlg.Close();
		 		END;
				IF res = ResOk THEN
		 			burnPanel.Terminate(FALSE);
		 		ELSE
		 			burnPanel.Terminate(TRUE);
		 		END;
		 		ShowWorkPanel();
			END;
		END BurnAudioHandler;

		(* returns the number of bytes needed for conversion of wav files *)
		PROCEDURE GetWavSpace(project: AudioProject): LONGINT;
		VAR
			node: Node;
			size: LONGINT;
		BEGIN
			node := project.root(Node);
			WHILE node # NIL DO
				IF node.mp3 THEN	INC(size, node.size)	END;
				node := node.next;
			END;
			RETURN size;
		END GetWavSpace;

		PROCEDURE Convert(project: AudioProject; dest: String): LONGINT;
		VAR
			no, res: LONGINT;
			cur: Node;
			filename, path, tmp: ARRAY MaxLen OF CHAR;
		BEGIN
			cur := project.root(Node);
			no := 0;
			WHILE cur # NIL DO
				IF cur.mp3 THEN
					filename := "TRACK";
					Strings.IntToStr(no, tmp);
					Strings.Append(filename, tmp);
					Strings.Append(filename, ".WAV");
					INC(no);
					Files.JoinPath(dest^, filename, path);
					cur.convName := Strings.NewString(path);
					IF FileExists(path) THEN
						IF WMDialogs.Confirmation("Confirm overwriting", path) = WMDialogs.ResNo THEN
							RETURN ResErr;
						END;
					END;
					Files.SplitPath(cur.fullpath^, tmp, filename);
					burnPanel.progress0.visible.Set(TRUE);
					burnPanel.SetTitle0(Strings.NewString("Converting mp3 Files"));
					burnPanel.SetCaption0(Strings.NewString(filename));
					burnPanel.progress0.SetRange(0, cur.size DIV 1024);
					burnPanel.progress0.SetPos(0);
					res := Utils.Mp3ToWave(cur.fullpath, cur.convName, UpdateStatus);
					IF res # ResOk THEN
						RETURN ResErr;
					END;
				ELSE (* no conversion needed *)
					cur.convName := cur.fullpath;
				END;
				cur := cur.next;
			END;
			RETURN ResOk;
		END Convert;

		PROCEDURE UpdateStatus(status: Utils.Status);
		BEGIN
			(* schedule event and return immedately *)
			(* it doesn't matter if one status notifcation is skipped *)
			onStatusChanged.Call(status);
		END UpdateStatus;

		PROCEDURE StatusChanged(sender, data: ANY);
		VAR
			filename, path: ARRAY MaxLen OF CHAR;
			tmp: ARRAY MaxLen OF CHAR;
			percent: LONGINT;
			recStatus: CDRecord.RecordingStatus;
			writeStatus: MakeIsoImages.WritingStatus;
			convStatus: Utils.ConvertingStatus;
		BEGIN
			IF ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.StatusChanged, sender, data);
			ELSE
				IF data IS Utils.ConvertingStatus THEN
					convStatus := data(Utils.ConvertingStatus);
					burnPanel.progress0.SetPos(convStatus.bytesEncoded DIV 1024);
				ELSIF data IS CDRecord.RecordingStatus THEN
					recStatus := data(CDRecord.RecordingStatus);
					IF recStatus.operation = CDRecord.Verifying THEN
						burnPanel.progress1.SetPos(recStatus.secsVerified);
					ELSE
						burnPanel.progress1.SetPos(recStatus.secsTransferred);
					END;
					IF recStatus.bufferSize > 0 THEN
						percent :=100* (recStatus.bufferSize - recStatus.freeBuffer) DIV recStatus.bufferSize;
					ELSE
						percent := 0;
					END;
					Strings.IntToStr(percent, tmp);
					Strings.Append(tmp, "%");
					burnPanel.SetLevel(Strings.NewString(tmp));
					Strings.IntToStr(recStatus.currentSpeed, tmp);
					Strings.Append(tmp, " KB/s");
					burnPanel.SetSpeed(Strings.NewString(tmp));

					CASE recStatus.operation OF
						  CDRecord.Calibrating:			tmp := "Calibrating";
						| CDRecord.Writing: 				tmp := "Writing";
						| CDRecord.ClosingTrack:			tmp := "Closing Track";
						| CDRecord.ClosingSession:		tmp := "Closing Session";
						| CDRecord.SendingCueSheet:	tmp := "Sending Cue Sheet";
						| CDRecord.FillingFifo:			tmp := "Filling Fifo";
						| CDRecord.FlushingCache:	tmp := "Flushing Cache";
						| CDRecord.Verifying:			tmp := "Verifying Written Data";
						ELSE  tmp := "";
					END;
					burnPanel.SetOp(Strings.NewString(tmp));
				ELSIF data IS MakeIsoImages.WritingStatus THEN
					writeStatus := data(MakeIsoImages.WritingStatus);
					IF writeStatus.fileName # NIL THEN
						Files.SplitPath(writeStatus.fileName^, path, filename);
						burnPanel.SetCaption0(Strings.NewString(filename));
					END;
					burnPanel.progress0.SetPos(writeStatus.bytesWritten DIV 1024);
				END;
			END;
		END StatusChanged;

		PROCEDURE RefreshHandler(sender, data: ANY);
		BEGIN
			explorer.tree.Refresh();
		END RefreshHandler;

		PROCEDURE BurnDataHandler(sender, data: ANY);
		VAR
			dataDlg: DataDialog;
			res, tmp: LONGINT;
			root: ANY;
			dest: String;
			compilation: CDRecord.Compilation;
			isoSettings: MakeIsoImages.IsoSettings;
			project: DataProject;
			burnSettings: CDRecord.BurnSettings;
			waitDlg: WaitDialog;
			msg, str: ARRAY MaxLen OF CHAR;
		BEGIN
			project := projectPanel.project(DataProject);
			IF IdentifyRecorders() = ResErr THEN RETURN END;
			NEW(dataDlg, Strings.NewString("Burn"), bounds, 300, 400);
			dataDlg.Show();
			IF dataDlg.result = WMDialogs.ResOk THEN
				root :=project.root;
				burnSettings := dataDlg.burnPage.settings;
				burnSettings.multisession := (project.session = ContinueMultisession) OR (project.session = StartMultisession);
				burnSettings.append := (project.session = ContinueMultisession) OR (project.session = FinishMultisession);
				isoSettings := dataDlg.isoPage.settings;
				dest := dataDlg.isoPage.location.Get();
				IF FileExists(dest^) THEN
					IF WMDialogs.Confirmation("Confirm overwriting", dest^) = WMDialogs.ResNo THEN
						RETURN;
					ELSE
						(* delete the file in order to adjust free space *)
						Files.Delete(dest^, tmp);
					END;
				END;
				ShowBurnPanel();
				burnPanel.SetTitle0(Strings.NewString("Generating ISO Image"));
				burnPanel.progress0.SetRange(0, (project.totalSize - project.oldSize) DIV 1024 );
				burnPanel.progress0.SetPos(0);
				isoSettings.bootCatalog := project.bootCatalog;
				isoSettings.startLba := project.isoOfs;
				IF (project.totalSize - project.oldSize) DIV MakeIsoImages.SectorSize < BBMinISOSize THEN
					msg := "This image is too small to be mountable on Bluebottle. Do you want the image be padded to the minimal size of ";
					Strings.IntToStr(BBMinISOSize, str); Strings.Append(msg, str); Strings.Append(msg, " Sectors?");
					res := WMDialogs.Message(WMDialogs.TQuestion, "Info", msg , {WMDialogs.ResYes, WMDialogs.ResNo, WMDialogs.ResAbort});
					IF res = WMDialogs.ResYes THEN
						isoSettings.padToSize := BBMinISOSize;
					ELSIF res = WMDialogs.ResAbort THEN
						burnPanel.Terminate(TRUE);
						ShowWorkPanel();
						RETURN;
					END;
				END;
				res := MakeIsoImages.MakeImageFromTree(project.root(Directory),dest, isoSettings, UpdateStatus);
		 		IF res # ResOk THEN
		 			CASE res OF
		 				  MakeIsoImages.ErrNotEnoughSpace: msg := "Not enough Space for Image";
		 				| MakeIsoImages.ErrDestinationInvalid: msg := "Destination is invalid";
		 				| MakeIsoImages.ErrDestinationReadOnly: msg := "Destination is read only";
		 				| MakeIsoImages.ErrFileNotFound: msg := "an error occured during of ISO Image: File not found";
		 				ELSE msg := "an error occured during generation of ISO Image";
		 			END;
		 			WMDialogs.Error(Title, msg);
		 			burnPanel.Terminate(TRUE);
		 			ShowWorkPanel();
		 			RETURN;
		 		ELSE
		 			NEW(compilation);
		 			res := compilation.AddTrack(dest, CDRecord.DataTrack, FALSE);
		 			IF res = ResOk THEN
		 				compilation.Finish();
		 				burnPanel.progress1.SetRange(0, compilation.GetSize(FALSE, TRUE));
			 			res := Record(compilation, dataDlg.burnPage.recorder, burnSettings);
			 		ELSE
			 			WMDialogs.Error(Title, "Track could not be added");
		 				burnPanel.Terminate(TRUE);
		 				ShowWorkPanel();
		 				RETURN;
			 		END;
		 		END;
		 		(* delete the image if desired *)
		 		IF dataDlg.isoPage.remove.Get() & FileExists(dest^) THEN
		 			NEW(waitDlg, Strings.NewString("Please Wait"), bounds, 200, 100, FALSE);
					waitDlg.SetText("Removing iso image");
					waitDlg.ShowNonModal;
		 			Files.Delete(dest^, tmp);
		 			waitDlg.Close();
		 		END;
		 		IF res = ResOk THEN
		 			burnPanel.Terminate(FALSE);
		 		ELSE
		 			burnPanel.Terminate(TRUE);
		 		END;
		 		ShowWorkPanel();
			END;
		END BurnDataHandler;

		PROCEDURE Record(compilation: CDRecord.Compilation; recorder: CDRecord.CDRecorder; settings: CDRecord.BurnSettings): LONGINT;
		VAR
			res, tmp : LONGINT;
			msg, str : ARRAY MaxLen OF CHAR;
			waitDlg: WaitDialog;
			timer: Timer;
		BEGIN
			IF CheckController(compilation, recorder, str) THEN
				msg := "source ("; Strings.Append(msg, str); Strings.Append(msg, ") and recorder (");
				Strings.Append(msg, recorder.dev.name);
				Strings.Append(msg, ") are connected to the same controller. This decreases performance of buffer!");
				WMDialogs.Information(Title, msg);
			END;
			IF recorder.dev.openCount > 0 THEN
				msg := "OpenCount of device (";
				Strings.Append(msg, recorder.dev.desc);
				Strings.Append(msg, ") is not zero. Unmount any partition first.");
				WMDialogs.Error(Title, msg);
				RETURN ResErr;
			END;
			NEW(timer); timer.interval.Set(500);
			timer.onUpdate.Add(TimeHandler);
			NEW(waitDlg, Strings.NewString("Waiting"), bounds, 200, 100, TRUE);
			LOOP
				timer.Start(SELF, NIL);
				res := recorder.Record(compilation, settings, UpdateStatus);
				timer.Stop(SELF, NIL); burnPanel.SetTime(Strings.NewString(""));
				IF res = CDRecord.ErrDriveNotReady THEN
					msg := "Recorder not ready. Please Wait";
					waitDlg.SetText(msg);
					waitDlg.ShowNonModal();
					REPEAT
						Objects.Yield();
						res := recorder.dev.RequestSense();
						IF recorder.CheckNoMediumPresent() THEN res := CDRecord.ErrNoMediumPresent END;
					UNTIL recorder.IsReady() OR (res = CDRecord.ErrNoMediumPresent) OR (waitDlg.result = WMDialogs.ResAbort);
					IF waitDlg.result = WMDialogs.ResAbort THEN
						RETURN ResErr;
					ELSE
						waitDlg.Close();
					END;
				ELSIF res = CDRecord.ErrSendingCueSheet THEN
					IF settings.multisession THEN
						msg := "Drive does not support SAO with multisession disc. Do you want to burn it in TAO mode instead?";
					ELSE
						msg := "Cue sheet could not be sent.Do you want to burn in TAO mode instead?";
					END;
					IF WMDialogs.Message(WMDialogs.TAction, "Not Ready", msg , {WMDialogs.ResOk, WMDialogs.ResAbort}) = WMDialogs.ResAbort THEN
						RETURN ResErr;
					ELSE
						settings.writeType := CDRecord.TrackAtOnce;
					END;
				ELSIF (res = CDRecord.ErrCDRWNotEmpty) OR (res = CDRecord.ErrCDRWNotAppendable) THEN
					msg :=" CDRW is not empty. Do you want to blank it now?";
					tmp :=  WMDialogs.Message(WMDialogs.TAction, "Not Ready", msg , {WMDialogs.ResAbort, WMDialogs.ResNo, WMDialogs.ResYes});
					IF tmp = WMDialogs.ResAbort THEN
						RETURN ResErr;
					ELSIF tmp = WMDialogs.ResYes THEN
						BlankHandler(SELF, NIL);
					END;
				ELSIF res = CDRecord.ErrWriting THEN
					msg := "An error occured during writing.";
					IF recorder.locked THEN
						Strings.Append(msg, " Drive could not be unlocked.");
					END;
					WMDialogs.Error(Title, msg);
					RETURN ResErr;
				ELSIF res = CDRecord.ErrVerificationFailed THEN
					msg := "Verification failed";
					WMDialogs.Error(Title, msg );
					RETURN ResErr
				ELSE
					CASE res OF
						  CDRecord.ErrDiscNotEmpty: msg := "Disc is not empty";
						| CDRecord.ErrNotEnoughFreeSpace: msg := "Data does not fit on inserted Disk";
						| CDRecord.ErrNoMediumPresent: msg := "No Medium present";
						| CDRecord.ErrDiscNotAppendable: msg := "Inserted Disc is finalized";
						| CDRecord.ErrIncompatibleMedium: msg := "Inserted disc is incompatible";
						ELSE EXIT;
					END;
					IF WMDialogs.Message(WMDialogs.TAction, "Not Ready", msg , {WMDialogs.ResOk, WMDialogs.ResAbort}) = WMDialogs.ResAbort THEN
						RETURN ResErr;
					END;
				END;

			END;

			IF res = ResOk THEN
				msg := "Recording was successful. ";
				IF recorder.recStatus.empty >= 0 THEN
					Strings.Append(msg, "SW Buffer was ");
					Strings.IntToStr(recorder.recStatus.empty, str); Strings.Append(msg, str); Strings.Append(msg, " times empty. ");
				END;
				Strings.Append(msg, "Eject Disc?");
				IF WMDialogs.Message(WMDialogs.TQuestion, "Finished", msg , {WMDialogs.ResNo, WMDialogs.ResYes}) = WMDialogs.ResYes THEN
					tmp := recorder.dev.MediaEject(FALSE, FALSE);
				END;
			END;
			tmp := recorder.dev.RequestSense();
			RETURN res;
		END Record;

		PROCEDURE TimeHandler(sender, data: ANY);
		VAR
			time: Time;
			timeStr: ARRAY MaxLen OF CHAR;
		BEGIN
			time := data(Time);
			time.Format(timeStr);
			burnPanel.SetTime(Strings.NewString(timeStr));
		END TimeHandler;

		PROCEDURE Close;
		BEGIN
			Close^();
			DecCount();
		END Close;

	END Window;


	SessionDialog = OBJECT(Utils.StandardDialog);
		VAR
			session: LONGINT;
			sessionList: Utils.ListBox;

		PROCEDURE CreateDialog;
		VAR
			bearing: WMRectangles.Rectangle;
		BEGIN
			CreateDialog^;
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);
			NEW(sessionList); sessionList.bearing.Set(bearing); sessionList.bounds.SetHeight(120); sessionList.alignment.Set(WMComponents.AlignTop);
			sessionList.caption.Set(Strings.NewString("Session"));
			sessionList.Add(Strings.NewString("No Multisession"), NIL);
			sessionList.Add(Strings.NewString("Start Multisession"), NIL);
			sessionList.Add(Strings.NewString("Continue Multisession"), NIL);
			sessionList.Add(Strings.NewString("Finish Multisession"), NIL);
			sessionList.Add(Strings.NewString("Boot"), NIL);
			content.AddContent(sessionList);
		END CreateDialog;

		PROCEDURE Ok(sender, data: ANY);
		BEGIN
			CASE sessionList.selected.Get() OF
				  0: session := NoMultisession;
				| 1: session := StartMultisession;
				| 2: session := ContinueMultisession;
				| 3: session := FinishMultisession;
				| 4: session := BootSession;
			END;
			Ok^(sender, data);
		END Ok;
	END SessionDialog;

	ToolDialog = OBJECT(Utils.StandardDialog);
		VAR
			tool: LONGINT;
			toolList: Utils.ListBox;

		PROCEDURE CreateDialog;
		VAR
			bearing: WMRectangles.Rectangle;
		BEGIN
			CreateDialog^;
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);
			NEW(toolList); toolList.bearing.Set(bearing); toolList.bounds.SetHeight(100); toolList.alignment.Set(WMComponents.AlignTop);
			toolList.caption.Set(Strings.NewString("Tool"));
			toolList.Add(Strings.NewString("Burn Iso Image"), NIL);
			toolList.Add(Strings.NewString("Copy Data CD"), NIL);
			toolList.Add(Strings.NewString("Blank CDRW"), NIL);
			toolList.Add(Strings.NewString("Disc Information"), NIL);
			content.AddContent(toolList);
		END CreateDialog;

		PROCEDURE Ok(sender, data: ANY);
		BEGIN
			CASE toolList.selected.Get() OF
				  0: tool := OpenIsoTool;
				| 1: tool := CopyIsoTool;
				| 2: tool := BlankTool;
				| 3: tool := DiscInfo;
			END;
			Ok^(sender, data);
		END Ok;
	END ToolDialog;

	InfoDialog = OBJECT(Utils.StandardDialog);
		VAR
			disc: CDRecord.Disc;
			grid: WMStringGrids.StringGrid;

		PROCEDURE CreateDialog;
		VAR
			bearing: WMRectangles.Rectangle;
		BEGIN
			CreateDialog^;
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);
			NEW(grid);
			grid.alignment.Set(WMComponents.AlignClient);
			content.AddContent(grid);
			grid.model.Acquire;
			grid.alwaysShowScrollY.Set(FALSE);
			grid.model.SetNofCols(2);
			grid.SetSelectionMode(WMGrids.GridSelectNone);
			grid.model.Release
		END CreateDialog;

		PROCEDURE Show;
		VAR
			tmp: ARRAY MaxLen OF CHAR;
			colWidths: WMGrids.Spacings;
		BEGIN
			NEW(colWidths, 2);
			colWidths[0] := width DIV 2;
			colWidths[1] := width DIV 2;
			grid.SetColSpacings(colWidths);
			grid.model.Acquire;
			grid.model.SetNofRows(7);
			grid.model.SetCellText(0, 0, Strings.NewString("type:"));
			grid.model.SetCellText(0, 1, Strings.NewString("status:"));
			grid.model.SetCellText(0, 2, Strings.NewString("used space:"));
			grid.model.SetCellText(0, 3, Strings.NewString("free space:"));
			grid.model.SetCellText(0, 4, Strings.NewString("sessions: "));
			grid.model.SetCellText(0, 5, Strings.NewString("last session: "));
			grid.model.SetCellText(0, 6, Strings.NewString("max wr. speed: "));
			IF disc # NIL THEN
				IF disc.erasable & (disc IS CDRecord.DiscEx) THEN
					CASE disc(CDRecord.DiscEx).subtype OF
						 Lib.ATCdRwStandardSpeed: tmp := "CDRW Standard Speed";
						| Lib.ATCdRwHighSpeed: tmp := "CDRW High Speed";
						| Lib.ATCdRwUltraHighSpeed, Lib.ATCdRwUltraHighSpeedPlus: tmp := "CDRW Ultra High Speed";
						ELSE tmp := "Unknown";
					END;
				ELSIF disc IS CDRecord.DiscEx THEN
					tmp := "CDR";
				ELSE
					CASE disc.type OF
						Lib.DTCdDACdRom: tmp := "CD-DA / CD-Rom (Not recordable)"; (* TODO: Read Toc to find out wheter DA or CD-ROM*)
						| Lib.DTCdI: tmp := "CD-I";
						| Lib.DTCdRomXA: tmp := "CD-Rom XA";
						| Lib.DTUndefined: tmp := "Undefined";
						ELSE tmp := "Unknown";
					END;
				END;
				grid.model.SetCellText(1, 0, Strings.NewString(tmp));
				CASE disc.status OF
					   Lib.DSEmpty: tmp := "Empty Disc";
					 | Lib.DSAppendable: tmp := "Incomplete Disc (Appendable)";
					 | Lib.DSComplete: tmp := "Complete Disc";
					 | Lib.DSOtherStatus: tmp := "Unknown Status";
				END;
				grid.model.SetCellText(1, 1, Strings.NewString(tmp));
				Strings.IntToStr(disc.usedBlocks, tmp); Strings.Append(tmp, " sectors");
				grid.model.SetCellText(1, 2, Strings.NewString(tmp));
				Strings.IntToStr(disc.freeBlocks, tmp); Strings.Append(tmp, " sectors");
				grid.model.SetCellText(1, 3, Strings.NewString(tmp));
				Strings.IntToStr(disc.nofSessions, tmp);
				grid.model.SetCellText(1, 4, Strings.NewString(tmp));
				CASE disc.statusLastSession OF
					   Lib.LSSEmpty: tmp := "Empty";
					 | Lib.LSSIncomplete: tmp := "Incomplete";
					 | Lib.LSSComplete: tmp := "Complete";
				END;
				grid.model.SetCellText(1, 5, Strings.NewString(tmp));
				IF (disc IS CDRecord.DiscEx) & (disc(CDRecord.DiscEx).maxSpeed > 0) THEN
					Strings.IntToStr(disc(CDRecord.DiscEx).maxSpeed, tmp); Strings.Append(tmp, " x");
				ELSE
					tmp := "Not available";
				END;
				grid.model.SetCellText(1, 6, Strings.NewString(tmp));
			END;
			grid.model.Release;
			Show^();
		END Show;

		PROCEDURE &Create*(title: String; bounds: WMRectangles.Rectangle; width, height: LONGINT; disc: CDRecord.Disc);
		BEGIN
			SELF.disc := disc;
			New(title, bounds, width, height);
		END Create;
	END InfoDialog;

	BlankTypeDialog = OBJECT(Utils.StandardDialog);
		VAR
			type: LONGINT;
			typeList: Utils.ListBox;

		PROCEDURE CreateDialog;
		VAR
			bearing: WMRectangles.Rectangle;
		BEGIN
			CreateDialog^;
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);
			NEW(typeList); typeList.bearing.Set(bearing); typeList.bounds.SetHeight(100); typeList.alignment.Set(WMComponents.AlignTop);
			typeList.caption.Set(Strings.NewString("Type"));
			typeList.Add(Strings.NewString("Quick"), NIL);
			typeList.Add(Strings.NewString("Complete"), NIL);
			content.AddContent(typeList);
		END CreateDialog;

		PROCEDURE Ok(sender, data: ANY);
		BEGIN
			CASE typeList.selected.Get() OF
				   0: type := Lib.BDQuick;
				| 1: type := Lib.BDEntire;
			END;
			Ok^(sender, data);
		END Ok;
	END BlankTypeDialog;

	RecorderDialog = OBJECT(Utils.StandardDialog);
		VAR
			recorder: CDRecord.CDRecorder;
			recList: Utils.ListBox;

		PROCEDURE CreateDialog;
		VAR
			bearing: WMRectangles.Rectangle;
			label:  WMStandardComponents.Label;
			i: LONGINT;
		BEGIN
			CreateDialog^;
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);
			NEW(label);
			label.bearing.Set(bearing); label.bounds.SetHeight(60);  label.alignment.Set(WMComponents.AlignTop); label.caption.SetAOC("Please choose desired Recorder and insert disc");
			content.AddContent(label);
			NEW(recList); recList.bearing.Set(bearing); recList.bounds.SetHeight(60); recList.alignment.Set(WMComponents.AlignTop);
			recList.caption.Set(Strings.NewString("Drive"));
			i := 0;
			WHILE (i < LEN(recorders)) & (recorders[i] # NIL) DO
				recList.Add(Strings.NewString(recorders[i].name), NIL);
				INC(i);
			END;
			content.AddContent(recList);
		END CreateDialog;

		PROCEDURE Ok(sender, data: ANY);
		BEGIN
			recorder := recorders[recList.selected.Get()];
			Ok^(sender, data);
		END Ok;
	END RecorderDialog;

	WaitDialog = OBJECT(Utils.StandardDialog);
		VAR
			label: WMStandardComponents.Label;

		PROCEDURE CreateDialog;
		VAR
			bearing: WMRectangles.Rectangle;
		BEGIN
			CreateDialog^;
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);
			buttonPanel.RemoveContent(ok);
			NEW(label);
			label.bearing.Set(bearing); label.alignment.Set(WMComponents.AlignClient);
			content.AddContent(label);
		END CreateDialog;

		PROCEDURE &Create*(title: String; bounds: WMRectangles.Rectangle; width, height: LONGINT; abortable: BOOLEAN);
		BEGIN
			New(title, bounds, width, height);
			IF ~abortable THEN content.RemoveContent(abort) END;
		END Create;

		PROCEDURE Abort(sender, data: ANY);
		BEGIN
			IF result < 0 THEN
				manager.Remove(SELF);
			END;
			result := WMDialogs.ResAbort;
		END Abort;

		PROCEDURE Close;
		BEGIN
			Abort(SELF, NIL);
		END Close;

		PROCEDURE SetText(CONST str: ARRAY OF CHAR);
		BEGIN
			label.caption.Set(Strings.NewString(str));
		END SetText;
	END WaitDialog;

	BurnPanel = OBJECT(WMComponents.VisualComponent);
	VAR
		bearing: WMRectangles.Rectangle;
		endBtn: WMStandardComponents.Button;
		progress0, progress1: Utils.ProgressBar;
		result: LONGINT;
		prepareLabel, titleLabel0, titleLabel1, opLabel, bufLabel, speedLabel, timeLabel: WMStandardComponents.Label;

		PROCEDURE &Init*;
		VAR
			preparePanel, burnPanel, bufPanel, speedPanel, opPanel, timePanel, buttonPanel: WMStandardComponents.Panel;
			label0, label1, label2, label3 : WMStandardComponents.Label;
		BEGIN
			Init^();

			NEW(buttonPanel);
			result := -1;
			buttonPanel.alignment.Set(WMComponents.AlignBottom);
			buttonPanel.bounds.SetHeight(30);
			AddContent(buttonPanel);

			NEW(endBtn);
			endBtn.bounds.SetExtents(60,30);
			endBtn.alignment.Set(WMComponents.AlignRight);
			endBtn.visible.Set(FALSE);
			endBtn.onClick.Add(EndHandler);
			buttonPanel.AddContent(endBtn);

			bearing := WMRectangles.MakeRect(3, 3, 3, 3);

			NEW(preparePanel);
			preparePanel.bounds.SetHeight(100); preparePanel.alignment.Set(WMComponents.AlignTop);
			AddContent(preparePanel);

			NEW(titleLabel0);
			titleLabel0.bearing.Set(bearing); titleLabel0.bounds.SetHeight(30); titleLabel0.alignment.Set(WMComponents.AlignTop);
			preparePanel.AddContent(titleLabel0);

			NEW(prepareLabel); prepareLabel.bearing.Set(bearing); prepareLabel.bounds.SetHeight(20); prepareLabel.alignment.Set(WMComponents.AlignTop);
			preparePanel.AddContent(prepareLabel);

			NEW(progress0); progress0.bearing.Set(bearing); progress0.bounds.SetHeight(20); progress0.alignment.Set(WMComponents.AlignTop); progress0.color.Set(Blue);
			progress0.borderColor.Set(Black); progress0.fillColor.Set(White);
			preparePanel.AddContent(progress0);

			NEW(burnPanel);
			burnPanel.alignment.Set(WMComponents.AlignClient);
			AddContent(burnPanel);

			NEW(titleLabel1);
			titleLabel1.bearing.Set(bearing); titleLabel1.bounds.SetHeight(30); titleLabel1.alignment.Set(WMComponents.AlignTop); titleLabel1.caption.SetAOC("Recording");
			burnPanel.AddContent(titleLabel1);

			NEW(opPanel);
			opPanel.bounds.SetHeight(20); opPanel.bearing.Set(bearing); opPanel.alignment.Set(WMComponents.AlignTop);
			burnPanel.AddContent(opPanel);

			NEW(label2);
			label2.bounds.SetWidth(60); label2.alignment.Set(WMComponents.AlignLeft); label2.caption.SetAOC("operation: ");
			opPanel.AddContent(label2);

			NEW(opLabel);
			opLabel.bounds.SetWidth(140); opLabel.alignment.Set(WMComponents.AlignLeft);
			opPanel.AddContent(opLabel);

			NEW(progress1); progress1.bearing.Set(bearing);progress1.alignment.Set(WMComponents.AlignTop); progress1.SetRange(0,20); progress1.color.Set(Blue);
			progress1.borderColor.Set(Black); progress1.fillColor.Set(White); progress1.bounds.SetHeight(20);
			burnPanel.AddContent(progress1);

			NEW(bufPanel);
			bufPanel.bounds.SetHeight(20); bufPanel.bearing.Set(bearing); bufPanel.alignment.Set(WMComponents.AlignTop);
			burnPanel.AddContent(bufPanel);

			NEW(label0);
			label0.bounds.SetWidth(80); label0.alignment.Set(WMComponents.AlignLeft); label0.caption.SetAOC("buffer level: ");
			bufPanel.AddContent(label0);

			NEW(bufLabel);
			bufLabel.bounds.SetWidth(80); bufLabel.alignment.Set(WMComponents.AlignLeft);
			bufPanel.AddContent(bufLabel);

			NEW(speedPanel);
			speedPanel.bounds.SetHeight(20); speedPanel.bearing.Set(bearing); speedPanel.alignment.Set(WMComponents.AlignTop);
			burnPanel.AddContent(speedPanel);

			NEW(label1);
			label1.bounds.SetWidth(80); label1.alignment.Set(WMComponents.AlignLeft); label1.caption.SetAOC("speed: ");
			speedPanel.AddContent(label1);

			NEW(speedLabel);
			speedLabel.bounds.SetWidth(80); speedLabel.alignment.Set(WMComponents.AlignLeft);
			speedPanel.AddContent(speedLabel);

			NEW(timePanel);
			timePanel.bounds.SetHeight(20); timePanel.bearing.Set(bearing); timePanel.alignment.Set(WMComponents.AlignTop);
			burnPanel.AddContent(timePanel);

			NEW(label3);
			label3.bounds.SetWidth(80); label3.alignment.Set(WMComponents.AlignLeft); label3.caption.SetAOC("elapsed time: ");
			timePanel.AddContent(label3);

			NEW(timeLabel);
			timeLabel.bounds.SetWidth(80); timeLabel.alignment.Set(WMComponents.AlignLeft);
			timePanel.AddContent(timeLabel);
		END Init;

		PROCEDURE ResetAll;
		BEGIN
			progress0.SetPos(0);
			progress1.SetPos(0);
			titleLabel0.caption.Set(Strings.NewString(""));
			prepareLabel.caption.Set(Strings.NewString(""));
			bufLabel.caption.Set(Strings.NewString(""));
			speedLabel.caption.Set(Strings.NewString(""));
			opLabel.caption.Set(Strings.NewString(""));
			timeLabel.caption.Set(Strings.NewString(""));
			result := -1;
			endBtn.visible.Set(FALSE);
		END ResetAll;

		PROCEDURE SetTitle0(str: String);
		BEGIN
			titleLabel0.caption.Set(str);
		END SetTitle0;

		PROCEDURE SetCaption0(str: String);
		BEGIN
			prepareLabel.caption.Set(str);
		END SetCaption0;

		PROCEDURE SetTime(str: String);
		BEGIN
			timeLabel.caption.Set(str);
		END SetTime;

		PROCEDURE SetLevel(str: String);
		BEGIN
			bufLabel.caption.Set(str);
		END SetLevel;

		PROCEDURE SetSpeed(str: String);
		BEGIN
			speedLabel.caption.Set(str);
		END SetSpeed;

		PROCEDURE SetOp(str: String);
		BEGIN
			opLabel.caption.Set(str);
		END SetOp;

		PROCEDURE Terminate(error: BOOLEAN);
		BEGIN
			IF error THEN
				endBtn.caption.SetAOC("Failed");
			ELSE
				endBtn.caption.SetAOC("Done");
			END;
			endBtn.visible.Set(TRUE);
			endBtn.Reset(NIL, NIL);
			endBtn.Invalidate();
			BEGIN {EXCLUSIVE}
				AWAIT(result >= 0);
			END;
		END Terminate;

		PROCEDURE EndHandler(sender, data: ANY);
		BEGIN {EXCLUSIVE}
			result := 1;
		END EndHandler;

	END BurnPanel;


	CopyDialog = OBJECT(Utils.PropertySheet);
	VAR
		sourcePage: SourcePage;
		burnPage: BurnPage;

		PROCEDURE CreateDialog;
		BEGIN
			CreateDialog^;
			NEW(sourcePage);
			sourcePage.alignment.Set(WMComponents.AlignClient);
			sourcePage.remove.Set(TRUE);
			sourcePage.location.Set(Strings.NewString(DefaultImageLocation));
			sourcePage.UpdateData(FALSE);

			AddPage(sourcePage, Strings.NewString("Source"));
			SelectPage(sourcePage);

			NEW(burnPage);
			burnPage.alignment.Set(WMComponents.AlignClient);
			AddPage(burnPage, Strings.NewString("Burn"));
		END CreateDialog;

		PROCEDURE Ok(sender, data: ANY);
		BEGIN
			sourcePage.UpdateData(TRUE);
			burnPage.UpdateData(TRUE);
			Ok^(sender, data);
		END Ok;
	END CopyDialog;

	AudioDialog = OBJECT(Utils.PropertySheet);
	VAR
		audioPage: AudioPage;
		burnPage: BurnPage;

		PROCEDURE CreateDialog;
		BEGIN
			CreateDialog^;
			NEW(audioPage);
			audioPage.alignment.Set(WMComponents.AlignClient);
			audioPage.remove.Set(TRUE);
			audioPage.location.Set(Strings.NewString(DefaultWaveLocation));
			audioPage.UpdateData(FALSE);

			AddPage(audioPage, Strings.NewString("Audio"));
			SelectPage(audioPage);

			NEW(burnPage);
			burnPage.alignment.Set(WMComponents.AlignClient);
			burnPage.RemoveContent(burnPage.verifyChk);
			AddPage(burnPage, Strings.NewString("Burn"));

		END CreateDialog;

		PROCEDURE Ok(sender, data: ANY);
		BEGIN
			audioPage.UpdateData(TRUE);
			burnPage.UpdateData(TRUE);
			Ok^(sender, data);
		END Ok;
	END AudioDialog;

	DataDialog = OBJECT(Utils.PropertySheet);
	VAR
		isoPage: IsoPage;
		burnPage: BurnPage;

		PROCEDURE CreateDialog;
		BEGIN
			CreateDialog^;
			NEW(isoPage);
			isoPage.alignment.Set(WMComponents.AlignClient);
			isoPage.settings.joliet := TRUE;
			isoPage.remove.Set(TRUE);
			isoPage.location.Set(Strings.NewString(DefaultImageLocation));
			isoPage.settings.isoLevel := MakeIsoImages.IsoLevel1;
			isoPage.UpdateData(FALSE);

			AddPage(isoPage, Strings.NewString("ISO"));
			SelectPage(isoPage);

			NEW(burnPage);
			burnPage.alignment.Set(WMComponents.AlignClient);
			AddPage(burnPage, Strings.NewString("Burn"));

			burnPage.recorder := recorders[0];
			burnPage.UpdateData(FALSE);
		END CreateDialog;

		PROCEDURE Ok(sender, data: ANY);
		BEGIN
			isoPage.UpdateData(TRUE);
			burnPage.UpdateData(TRUE);
			Ok^(sender, data);
		END Ok;
	END DataDialog;

	ImageDialog = OBJECT(Utils.PropertySheet);
	VAR
		imagePage: ImagePage;
		burnPage: BurnPage;

		PROCEDURE CreateDialog;
		BEGIN
			CreateDialog^;
			NEW(imagePage);
			imagePage.alignment.Set(WMComponents.AlignClient);
			imagePage.UpdateData(FALSE);

			AddPage(imagePage, Strings.NewString("Image"));
			SelectPage(imagePage);

			NEW(burnPage);
			burnPage.alignment.Set(WMComponents.AlignClient);
			AddPage(burnPage, Strings.NewString("Burn"));
			burnPage.recorder := recorders[0];
			burnPage.UpdateData(FALSE)
		END CreateDialog;

		PROCEDURE Ok(sender, data: ANY);
		BEGIN
			imagePage.UpdateData(TRUE);
			burnPage.UpdateData(TRUE);
			Ok^(sender, data);
		END Ok;
	END ImageDialog;

	BootDialog = OBJECT(Utils.StandardDialog);
	VAR
		bootCatalog: MakeIsoImages.BootCatalog;
		locationEdit, idEdit: WMEditors.Editor;
		platformList, emulList: Utils.ListBox;
		imageSize: LONGINT;

		PROCEDURE CreateDialog;
		VAR
			label1, label2: WMStandardComponents.Label;
			bearing: WMRectangles.Rectangle;
			locationPanel: WMStandardComponents.Panel;
			browseBtn: WMStandardComponents.Button;
		BEGIN
			CreateDialog^();
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);

			NEW(label1); label1.bearing.Set(bearing); label1.alignment.Set(WMComponents.AlignTop); label1.bounds.SetHeight(20); label1.caption.SetAOC("location of boot image");
			content.AddContent(label1);

			NEW(locationPanel); locationPanel.alignment.Set(WMComponents.AlignTop); locationPanel.bounds.SetHeight(26);
			content.AddContent(locationPanel);

			NEW(locationEdit); locationEdit.bearing.Set(bearing); locationEdit.alignment.Set(WMComponents.AlignClient); locationEdit.bounds.SetHeight(20);  locationEdit.multiLine.Set(FALSE);
			locationEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			locationEdit.fillColor.Set(White); locationEdit.tv.showBorder.Set(TRUE);
			locationPanel.AddContent(locationEdit);

			NEW(browseBtn); browseBtn.alignment.Set(WMComponents.AlignRight); browseBtn.bounds.SetWidth(60); browseBtn.caption.SetAOC("Browse...");
			locationPanel.AddContent(browseBtn); browseBtn.onClick.Add(OnBrowse);

			NEW(label2); label2.bearing.Set(bearing); label2.alignment.Set(WMComponents.AlignTop); label2.bounds.SetHeight(20); label2.caption.SetAOC("id String");
			content.AddContent(label2);

			NEW(idEdit); idEdit.bearing.Set(bearing); idEdit.alignment.Set(WMComponents.AlignTop); idEdit.bounds.SetHeight(20); idEdit.multiLine.Set(FALSE);
			idEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			idEdit.fillColor.Set(White); idEdit.tv.showBorder.Set(TRUE);
			content.AddContent(idEdit);

			NEW(emulList); emulList.bearing.Set(bearing); emulList.bounds.SetHeight(140); emulList.alignment.Set(WMComponents.AlignTop);
			emulList.caption.Set(Strings.NewString("Emulation"));
			emulList.Add(Strings.NewString("None"), NIL);
			emulList.Add(Strings.NewString("1.2MB Floppy"), NIL);
			emulList.Add(Strings.NewString("1.44MB Floppy"), NIL);
			emulList.Add(Strings.NewString("2.88MB Floppy"), NIL);
			emulList.Add(Strings.NewString("Harddisc"), NIL);
			content.AddContent(emulList);

			NEW(platformList); platformList.bearing.Set(bearing); platformList.bounds.SetHeight(80); platformList.alignment.Set(WMComponents.AlignTop);
			platformList.caption.Set(Strings.NewString("Platform"));
			platformList.Add(Strings.NewString("80x86"), NIL);
			platformList.Add(Strings.NewString("PowerPC"), NIL);
			platformList.Add(Strings.NewString("Mac"), NIL);

			content.AddContent(platformList);
		END CreateDialog;

		PROCEDURE OnBrowse(sender, data: ANY);
		VAR
			dlg: Utils.FileDialog;
			path: String;
		BEGIN
			NEW(dlg, Strings.NewString("Boot File"), bounds, 400, 200);
			dlg.Show();
			IF dlg.result = WMDialogs.ResOk THEN
				path := dlg.path.Get();
				locationEdit.SetAsString(path^);
			END;
		END OnBrowse;

		PROCEDURE Ok(sender, data: ANY);
		VAR
			image, id: ARRAY MaxLen OF CHAR;
			emulation, platform: CHAR;
		BEGIN
			bootCatalog := NIL;
			locationEdit.GetAsString(image); RemoveSpecialChars(image);
			IF (image # "") & FileExists(image) THEN
				imageSize := GetFileSize(image);
				CASE platformList.selected.Get() OF
					  0: platform := MakeIsoImages.Platform80x86;
					| 1: platform := MakeIsoImages.PlatformPowerPC;
					| 2: platform := MakeIsoImages.PlatformMac;
				END;

				CASE emulList.selected.Get() OF
					  0: emulation := MakeIsoImages.EmulationNone;
					| 1: emulation := MakeIsoImages.Emulation12Floppy;
					| 2: emulation := MakeIsoImages.Emulation144Floppy;
					| 3: emulation := MakeIsoImages.Emulation288Floppy;
					| 4: emulation := MakeIsoImages.EmulationHDD;
				END;
				idEdit.GetAsString(id);
				NEW(bootCatalog);
				bootCatalog.AddDefaultEntry(Strings.NewString(image), Strings.NewString(id), TRUE, platform, emulation);
			END;
			Ok^(sender, data);
		END Ok;
	END BootDialog;



	AudioPage = OBJECT(Utils.PropertyPage)
	VAR
		remove: WMProperties.BooleanProperty;
		removeChk: WMStandardComponents.Checkbox;
		location: WMProperties.StringProperty;
		locationEdit: WMEditors.Editor;

		PROCEDURE &Init*;
		VAR
			label: WMStandardComponents.Label;
			bearing: WMRectangles.Rectangle;
		BEGIN
			Init^();
			NEW(location, NIL, NIL, NIL); NEW(remove, NIL, NIL, NIL);
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);

			NEW(label); label.bearing.Set(bearing); label.alignment.Set(WMComponents.AlignTop); label.bounds.SetHeight(20); label.caption.SetAOC("location for converted mp3 files ");
			AddContent(label);

			NEW(locationEdit); locationEdit.bearing.Set(bearing); locationEdit.alignment.Set(WMComponents.AlignTop); locationEdit.bounds.SetHeight(20); locationEdit.multiLine.Set(FALSE);
			locationEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			locationEdit.fillColor.Set(White); locationEdit.tv.showBorder.Set(TRUE);
			AddContent(locationEdit);

			NEW(removeChk); removeChk.bearing.Set(bearing); removeChk.bounds.SetExtents(100, 14); removeChk.alignment.Set(WMComponents.AlignTop);
			removeChk.caption.Set(Strings.NewString("Remove converted wav files after writing"));
			AddContent(removeChk);
		END Init;

		PROCEDURE UpdateData(save: BOOLEAN);
		VAR
			str: ARRAY MaxLen OF CHAR;
			string: String;
		BEGIN
			IF save THEN
				IF removeChk.state.Get() = 0 THEN remove.Set(FALSE); ELSE remove.Set(TRUE); END;
				locationEdit.GetAsString(str); RemoveSpecialChars(str); location.Set(Strings.NewString(str));
			ELSE
				IF remove.Get() THEN removeChk.state.Set(1); ELSE removeChk.state.Set(0); END;
				string := location.Get();
				IF string # NIL THEN
					locationEdit.SetAsString(string^);
				END;
				RecacheProperties();
			END;
		END UpdateData;

	END AudioPage;

	SourcePage = OBJECT(Utils.PropertyPage)
	VAR
		remove: WMProperties.BooleanProperty;
		removeChk: WMStandardComponents.Checkbox;
		location: WMProperties.StringProperty;
		locationEdit: WMEditors.Editor;
		recList: Utils.ListBox;
		recorder: CDRecord.CDRecorder;

		PROCEDURE &Init*;
		VAR
			label: WMStandardComponents.Label;
			bearing: WMRectangles.Rectangle;
			i: LONGINT;
		BEGIN
			Init^();
			NEW(location, NIL, NIL, NIL); NEW(remove, NIL, NIL, NIL);
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);

			NEW(recList); recList.bearing.Set(bearing); recList.bounds.SetHeight(60); recList.alignment.Set(WMComponents.AlignTop);
			recList.caption.Set(Strings.NewString("Drive"));
			i := 0;
			WHILE (i < LEN(recorders)) & (recorders[i] # NIL) DO
				recList.Add(Strings.NewString(recorders[i].name), NIL);
				INC(i);
			END;
			AddContent(recList);

			NEW(label); label.bearing.Set(bearing); label.alignment.Set(WMComponents.AlignTop); label.bounds.SetHeight(20); label.caption.SetAOC("location for image");
			AddContent(label);

			NEW(locationEdit); locationEdit.bearing.Set(bearing); locationEdit.alignment.Set(WMComponents.AlignTop); locationEdit.bounds.SetHeight(20); locationEdit.multiLine.Set(FALSE);
			locationEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			locationEdit.fillColor.Set(White); locationEdit.tv.showBorder.Set(TRUE);
			AddContent(locationEdit);

			NEW(removeChk); removeChk.bearing.Set(bearing); removeChk.bounds.SetExtents(100, 14); removeChk.alignment.Set(WMComponents.AlignTop);
			removeChk.caption.Set(Strings.NewString("Remove image after writing"));
			AddContent(removeChk);
		END Init;

		PROCEDURE UpdateData(save: BOOLEAN);
		VAR
			str: ARRAY MaxLen OF CHAR;
			string: String;
		BEGIN
			IF save THEN
				IF removeChk.state.Get() = 0 THEN remove.Set(FALSE); ELSE remove.Set(TRUE); END;
				locationEdit.GetAsString(str); RemoveSpecialChars(str);
				location.Set(Strings.NewString(str));
				recorder := recorders[recList.selected.Get()];
			ELSE
				IF remove.Get() THEN removeChk.state.Set(1); ELSE removeChk.state.Set(0); END;
				string := location.Get();
				IF string # NIL THEN
					locationEdit.SetAsString(string^);
				END;
				RecacheProperties();
			END;
		END UpdateData;

	END SourcePage;

	ImagePage = OBJECT(Utils.PropertyPage)
	VAR
		location: WMProperties.StringProperty;
		locationEdit: WMEditors.Editor;

		PROCEDURE &Init*;
		VAR
			label: WMStandardComponents.Label;
			bearing: WMRectangles.Rectangle;
			locationPanel: WMStandardComponents.Panel;
			browseBtn: WMStandardComponents.Button;
		BEGIN
			Init^();
			NEW(location, NIL, NIL, NIL);
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);

			NEW(label); label.bearing.Set(bearing); label.alignment.Set(WMComponents.AlignTop); label.bounds.SetHeight(20); label.caption.SetAOC("location of image");
			AddContent(label);

			NEW(locationPanel); locationPanel.alignment.Set(WMComponents.AlignTop); locationPanel.bounds.SetHeight(26);
			AddContent(locationPanel);

			NEW(locationEdit); locationEdit.bearing.Set(bearing); locationEdit.alignment.Set(WMComponents.AlignClient); locationEdit.bounds.SetHeight(20); locationEdit.multiLine.Set(FALSE);
			locationEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			locationEdit.fillColor.Set(White); locationEdit.tv.showBorder.Set(TRUE);
			locationPanel.AddContent(locationEdit);

			NEW(browseBtn); browseBtn.alignment.Set(WMComponents.AlignRight); browseBtn.bounds.SetWidth(60); browseBtn.caption.SetAOC("Browse...");
			locationPanel.AddContent(browseBtn); browseBtn.onClick.Add(OnBrowse);

		END Init;

		PROCEDURE OnBrowse(sender, data: ANY);
		VAR
			dlg: Utils.FileDialog;
			path: String;
		BEGIN
			NEW(dlg, Strings.NewString("Image File"), owner.bounds, 400, 200);
			dlg.Show();
			IF dlg.result = WMDialogs.ResOk THEN
				path := dlg.path.Get();
				locationEdit.SetAsString(path^);
			END;
		END OnBrowse;

		PROCEDURE UpdateData(save: BOOLEAN);
		VAR
			str: ARRAY MaxLen OF CHAR;
			string: String;
		BEGIN
			IF save THEN
				locationEdit.GetAsString(str); RemoveSpecialChars(str);
				location.Set(Strings.NewString(str));
			ELSE
				string := location.Get();
				IF string # NIL THEN
					locationEdit.SetAsString(string^);
				END;
				RecacheProperties();
			END;
		END UpdateData;

	END ImagePage;





	BurnPage = OBJECT(Utils.PropertyPage);
	VAR
		recorder: CDRecord.CDRecorder;
		settings: CDRecord.BurnSettings;
		recList: Utils.ListBox;
		speedList: Utils.ListBox;
		typeList: Utils.ListBox; (* TAO / SAO *)
		verifyChk, bufeChk: WMStandardComponents.Checkbox;


		PROCEDURE &Init*;
		VAR
			bearing: WMRectangles.Rectangle;
			i: LONGINT;
		BEGIN
			Init^();
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);

			NEW(recList); recList.bearing.Set(bearing); recList.bounds.SetHeight(60); recList.alignment.Set(WMComponents.AlignTop);
			recList.caption.Set(Strings.NewString("Drive"));
			i := 0;

			WHILE (i < LEN(recorders)) & (recorders[i] # NIL) DO
				recList.Add(Strings.NewString(recorders[i].name), NIL);
				INC(i);
			END;
			recList.onSelectionChanged.Add(ListSpeeds);
			recList.onSelectionChanged.Add(ListTypes);
			recList.onSelectionChanged.Add(ListOptions);
			AddContent(recList);

			NEW(speedList); speedList.bearing.Set(bearing); speedList.bounds.SetHeight(100); speedList.alignment.Set(WMComponents.AlignTop);
			speedList.caption.Set(Strings.NewString("speed"));
			AddContent(speedList);

			NEW(typeList); typeList.bearing.Set(bearing); typeList.bounds.SetHeight(60); typeList.alignment.Set(WMComponents.AlignTop);
			typeList.caption.Set(Strings.NewString("write type"));
			AddContent(typeList);

			NEW(verifyChk); verifyChk.bearing.Set(bearing); verifyChk.bounds.SetExtents(100, 14); verifyChk.alignment.Set(WMComponents.AlignTop);
			verifyChk.caption.Set(Strings.NewString("Verify written data"));
			AddContent(verifyChk);

			NEW(bufeChk); bufeChk.bearing.Set(bearing); bufeChk.bounds.SetExtents(100, 14); bufeChk.alignment.Set(WMComponents.AlignTop);
			bufeChk.caption.Set(Strings.NewString("Buffer Underrrun Free")); bufeChk.visible.Set(FALSE);
			AddContent(bufeChk);
		END Init;

		PROCEDURE ListOptions(sender, data: ANY);
		VAR
			recorder: CDRecord.CDRecorder;
		BEGIN
			recorder := recorders[recList.selected.Get()];
			IF recorder # NIL THEN
				bufeChk.visible.Set(CDRecord.MFBufe IN recorder.cap.mediaFunc );
			END;
		END ListOptions;

		PROCEDURE ListSpeeds(sender, data: ANY);
		VAR
			i: LONGINT;
			recorder: CDRecord.CDRecorder;
			tmp, entry: ARRAY MaxLen OF CHAR;
			speed, max : LONGINT;
			disc: CDRecord.DiscEx;
		BEGIN
			max := MAX(LONGINT);
			recorder := recorders[recList.selected.Get()];
			speedList.Clear();
			IF  recorder # NIL THEN
				(* in case that a disc is inserted and the disc specifies a maximum speed we do not list all speeds *)
				NEW(disc);
				IF (recorder.GetDiscInfoEx(disc) = ResOk) & (disc.maxSpeed > 0) THEN
					max := disc.maxSpeed;
				END;
				FOR i:= 0 TO LEN(recorder.cap.writeSpeeds)-1 DO
					speed := recorder.cap.writeSpeeds[i];
					IF (speed DIV CDRecord.SingleSpeed) <= max THEN
						Strings.IntToStr(speed DIV CDRecord.SingleSpeed, entry);
						Strings.Append(entry, "x (");
						Strings.IntToStr(speed, tmp);
						Strings.Append(entry, tmp);
						Strings.Append(entry, " KB/s)");
						speedList.Add(Strings.NewString(entry), NIL);
					END;
				END;
			END;
			speedList.Update();
		END ListSpeeds;

		PROCEDURE ListTypes(sender, data: ANY);
		VAR
			recorder: CDRecord.CDRecorder;
		BEGIN
			recorder := recorders[recList.selected.Get()];
			typeList.Clear();
			IF recorder # NIL THEN
				typeList.Add(Strings.NewString("Track at Once"), NIL);
				IF CDRecord.MFSao IN recorder.cap.mediaFunc THEN
					typeList.Add(Strings.NewString("Session at Once"), NIL);
				END;
			END;
			typeList.Update();
		END ListTypes;

		PROCEDURE UpdateData(save: BOOLEAN);
		BEGIN
			IF save THEN
				recorder := recorders[recList.selected.Get()];
			END;

			IF recorder # NIL THEN
				settings.speed := recorder.cap.writeSpeeds[speedList.selected.Get()] DIV CDRecord.SingleSpeed;
				IF typeList.selected.Get() = 1 THEN
					settings.writeType :=CDRecord.SessionAtOnce;
				ELSE
					settings.writeType := CDRecord.TrackAtOnce;
				END;
				settings.verify := verifyChk.state.Get() = 1;
				settings.bufe := bufeChk.state.Get() = 1;
			END;
		END UpdateData;

	END BurnPage;

	IsoPage = OBJECT(Utils.PropertyPage);
	VAR
		settings: MakeIsoImages.IsoSettings;
		remove: WMProperties.BooleanProperty;
		location: WMProperties.StringProperty;
		jolietChk, removeChk: WMStandardComponents.Checkbox;
		levelList: Utils.ListBox;
		locationEdit: WMEditors.Editor;

		PROCEDURE &Init*;
		VAR

			label: WMStandardComponents.Label;
			bearing: WMRectangles.Rectangle;
		BEGIN
			Init^();
			NEW(remove, NIL, NIL, NIL); NEW(location, NIL, NIL, NIL);
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);

			NEW(levelList); levelList.bearing.Set(bearing); levelList.bounds.SetHeight(100); levelList.alignment.Set(WMComponents.AlignTop);
			levelList.caption.Set(Strings.NewString("ISO Level"));
			levelList.Add(Strings.NewString("ISO Level 1"), NIL);
			levelList.Add(Strings.NewString("ISO Level 2"), NIL);
			AddContent(levelList);

			NEW(jolietChk); jolietChk.bearing.Set(bearing); jolietChk.bounds.SetExtents(100, 14); jolietChk.alignment.Set(WMComponents.AlignTop);
			jolietChk.caption.Set(Strings.NewString("Joliet Extensions"));
			AddContent(jolietChk);

			NEW(label); label.bearing.Set(bearing); label.alignment.Set(WMComponents.AlignTop); label.bounds.SetHeight(20); label.caption.SetAOC("location of iso image");
			AddContent(label);

			NEW(locationEdit); locationEdit.bearing.Set(bearing); locationEdit.alignment.Set(WMComponents.AlignTop); locationEdit.bounds.SetHeight(20); locationEdit.multiLine.Set(FALSE);
			locationEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			locationEdit.fillColor.Set(White); locationEdit.tv.showBorder.Set(TRUE);
			AddContent(locationEdit);

			NEW(removeChk); removeChk.bearing.Set(bearing); removeChk.bounds.SetExtents(100, 14); removeChk.alignment.Set(WMComponents.AlignTop);
			removeChk.caption.Set(Strings.NewString("Remove image after writing"));
			AddContent(removeChk);
		END Init;

		PROCEDURE UpdateData(save: BOOLEAN);
		VAR
			str: ARRAY MaxLen OF CHAR;
			string: String;
		BEGIN
			IF save THEN
				IF levelList.selected.Get() = 1 THEN
					settings.isoLevel := MakeIsoImages.IsoLevel2;
				ELSE
					settings.isoLevel := MakeIsoImages.IsoLevel1;
				END;
				IF jolietChk.state.Get() = 0 THEN settings.joliet := FALSE ELSE settings.joliet := TRUE END;
				IF removeChk.state.Get() = 0 THEN remove.Set(FALSE); ELSE remove.Set(TRUE); END;
				locationEdit.GetAsString(str); RemoveSpecialChars(str); location.Set(Strings.NewString(str));
			ELSE
				IF settings.isoLevel = MakeIsoImages.IsoLevel2 THEN
					levelList.selected.Set(1);
				ELSE
					levelList.selected.Set(0);
				END;
				IF settings.joliet THEN jolietChk.state.Set(1); ELSE jolietChk.state.Set(0); END;
				IF remove.Get() THEN removeChk.state.Set(1); ELSE removeChk.state.Set(0); END;
				string := location.Get();
				locationEdit.SetAsString(string^);
				RecacheProperties();
			END;
		END UpdateData;
	END IsoPage;

	URLDropTarget* = OBJECT(WMDropTarget.DropTarget)
	VAR
		node: ANY;
		panel: ProjectPanel;

		PROCEDURE &New*(panel: ProjectPanel; node: ANY);
		BEGIN
			SELF.panel := panel;
			SELF.node := node;
		END New;

		PROCEDURE GetInterface*(type: LONGINT): WMDropTarget.DropInterface;
		VAR
			di: DropURL;

		BEGIN
			IF type = WMDropTarget.TypeURL THEN
				NEW(di, SELF.panel, SELF.node);
				RETURN di;
			ELSE
				RETURN NIL;
			END;
		END GetInterface;
	END URLDropTarget;

	DropURL* = OBJECT(WMDropTarget.DropURLs)
	VAR
		panel: ProjectPanel;
		node: ANY;

		PROCEDURE &New*(panel: ProjectPanel; node: ANY);
		BEGIN
			SELF.panel := panel;
			SELF.node := node;
		END New;

		PROCEDURE URL*(CONST url: ARRAY OF CHAR; VAR res: LONGINT);
		BEGIN
			IF panel.enabled.Get() THEN
				panel.AddFile(url, node);
			END;
		END URL;
	END DropURL;

	String = Strings.String;

	Node = OBJECT
	VAR
		fullpath, convName: String;
		next: Node;
		size: LONGINT;
		mp3: BOOLEAN;
	END Node;

	AudioFile = OBJECT(Node)
	VAR
		title: String;
		duration: LONGINT;

	PROCEDURE &New*(fullpath, title: String; duration: LONGINT; mp3: BOOLEAN);
	BEGIN
		SELF.fullpath := fullpath;
		SELF.title := title;
		SELF.duration := duration;
		SELF.mp3 := mp3;
	END New;

	END AudioFile;

	Selection = POINTER TO ARRAY OF ANY;

	SelectionWrapper = POINTER TO RECORD
		sel: Selection;
	END;

	Project = OBJECT
	VAR
		totalSize: LONGINT;
		root: ANY;

	END Project;

	AudioProject = OBJECT(Project);
	END AudioProject;

	DataProject = OBJECT(Project);
		VAR
			session: LONGINT;
			isoOfs: LONGINT; (* in case of multisession, this is the offset of the new session lead in*)
			oldSize: LONGINT; (* total size of previous sessions *)
			overhead: LONGINT; (* overhead for session leadins *)
			bootCatalog: MakeIsoImages.BootCatalog;
	END DataProject;

	ProjectPanel = OBJECT(WMComponents.VisualComponent);
	VAR
		owner: Window;
		project: Project;

		PROCEDURE AddFile(CONST name: ARRAY OF CHAR; Node: ANY);
			(* abstract *)
		END AddFile;
	END ProjectPanel;

	AudioPanel =  OBJECT(ProjectPanel);
	VAR
		grid: WMStringGrids.StringGrid;
		colWidths: WMGrids.Spacings;
		nofEntries: LONGINT;
		popup: WMPopups.Popup;
		root: Node;

		PROCEDURE &New*(project: AudioProject);
		BEGIN
			Init();
			SELF.project := project;
			NEW(grid);
			grid.alignment.Set(WMComponents.AlignClient);
			AddContent(grid);
			grid.model.Acquire;
			grid.model.SetNofCols(3);
			grid.model.SetNofRows(1);
			grid.fixedRows.Set(1);
			grid.model.SetCellText(0, 0, Strings.NewString("No"));
			grid.model.SetCellText(1, 0, Strings.NewString("Title"));
			grid.model.SetCellText(2, 0, Strings.NewString("Length"));
			grid.SetSelectionMode(WMGrids.GridSelectRows);
			NEW(colWidths, 3);
			grid.model.Release;
			grid.SetExtDragDroppedHandler(DragDroppedH);
			grid.SetExtContextMenuHandler(ContextMenu);
		END New;

		PROCEDURE ContextMenu(sender: ANY; x, y: LONGINT);
		VAR
			curSel: Selection;
			w: SelectionWrapper;
			px, py: LONGINT;
		BEGIN
			NEW(popup); NEW(w);
			curSel := GetSelection();
			w.sel := curSel;
			IF LEN(curSel) > 0 THEN
				popup.AddParButton("Delete", DeleteFiles, w);
				px := x; py := y;
				grid.ToWMCoordinates(x, y, px, py);
				popup.Popup(px, py);
			END;
		END ContextMenu;

		PROCEDURE GetSelection(): Selection;
		VAR
			selection: Selection;
			l, t, r, b, i, j: LONGINT;
			p: ANY;
		BEGIN
			grid.model.Acquire;
			grid.GetSelection(l, t, r, b);
			NEW(selection, b-t+1);
			j := 0;
			FOR i := t TO b DO
				 p := grid.model.GetCellData(0, i);
				 IF (p # NIL) & (p IS Node) THEN
				 	selection[j] := p(Node);
				 	INC(j);
				 END;
			END;
			grid.model.Release;
			RETURN selection;
		END GetSelection;

		PROCEDURE DeleteFiles(sender, data: ANY);
		VAR
			cur, prev: Node;
			i: LONGINT;
			selection: Selection;
		BEGIN
			IF popup # NIL THEN popup.Close; popup := NIL END;
			i := 0;
			selection := data(SelectionWrapper).sel;
			cur := root;
			WHILE (cur # NIL) & (i < LEN(selection)) DO
				IF cur = selection[i] THEN
					IF cur = root THEN
						root := cur.next;
					ELSE
						prev.next := cur.next;
					END;
					INC(i); DEC(project.totalSize, cur.size); DEC(nofEntries);
					owner.UpdateSize(project.totalSize, 0);
				ELSE
					prev := cur;
				END;
				cur := cur.next;
			END;
			Refresh();
		END DeleteFiles;

		PROCEDURE AddFile(CONST name: ARRAY OF CHAR; node: ANY);
		VAR
			title, file, path, ext: ARRAY MaxLen OF CHAR;
			mp3info: Utils.MP3Info;
			wavinfo: Utils.WAVInfo;
			audioFile: AudioFile;
			waitDlg : WaitDialog;
		BEGIN
			NEW(waitDlg, Strings.NewString("Waiting"), owner.bounds, 200, 100, TRUE);
			waitDlg.SetText("Analyzing File");
			waitDlg.ShowNonModal;
			IF ~MakeIsoImages.GetExtension(name, file, ext) THEN RETURN END;
			Strings.UpperCase(ext);
			IF ext = "WAV" THEN
				NEW(wavinfo);
				IF (wavinfo.Open(Strings.NewString(name)) = ResOk) &
				  (wavinfo.compression = Utils.CPCM) & (wavinfo.nofchannels = 2) &
				  (wavinfo.samplerate = 44100) & (wavinfo.encoding = 16) THEN
					Files.SplitPath(file, path, title);
					NEW(audioFile, Strings.NewString(name), Strings.NewString(title), wavinfo.size DIV (44100*2*(16 DIV 8)), FALSE);
					audioFile.size := wavinfo.size;
					Insert(audioFile);
				END;
			ELSIF ext = "MP3" THEN
				NEW(mp3info);
				IF mp3info.Open(Strings.NewString(name)) = ResOk THEN
					IF mp3info.id3v1 # NIL THEN
						COPY(mp3info.id3v1.Title, title);
					END;
					IF title = "" THEN
						Files.SplitPath(file, path, title);
					END;
					NEW(audioFile, Strings.NewString(name), Strings.NewString(title), mp3info.playtime, TRUE);
					audioFile.size := 44100*2*(16 DIV 8)*audioFile.duration;
					Insert(audioFile);
				END;
			END;
			IF waitDlg.result # WMDialogs.ResAbort THEN
				waitDlg.Close();
			END;
		END AddFile;

		(* inserts track at the end of the list *)

		PROCEDURE Insert(file: AudioFile);
		VAR
			cur: Node;
		BEGIN
			IF root = NIL THEN
				root := file;
				project.root := root;
			ELSE
				cur := root;
				WHILE cur.next # NIL DO
					cur := cur.next;
				END;
				cur.next := file;
			END;
			INC(nofEntries);
			INC(project.totalSize, file.size);
			owner.UpdateSize(project.totalSize, 0);
			Refresh();
		END Insert;

		(* refreshes the list *)

		PROCEDURE Refresh;
		VAR
			cur: Node;
			row: LONGINT;
			tmp: ARRAY MaxLen OF CHAR;
			time: Time;
		BEGIN
			NEW(time);
			cur := root;
			grid.model.Acquire;
			grid.model.SetNofRows(nofEntries + 1);
			WHILE cur # NIL DO
				INC(row);
				Strings.IntToStr(row, tmp);
				grid.model.SetCellData(0, row, cur);
				grid.model.SetCellText(0, row, Strings.NewString(tmp));
				grid.model.SetCellText(1, row, cur(AudioFile).title);
				time.SetTime(cur(AudioFile).duration);
				time.Format(tmp);
				grid.model.SetCellText(2, row, Strings.NewString(tmp));
				cur := cur.next;
			END;
			grid.model.Release;
		END Refresh;

		PROCEDURE Resized;
		VAR
			width: LONGINT;
		BEGIN
			Resized^();
			width := bounds.GetWidth();
			colWidths[0] := 20;
			colWidths[1] := width - 100;
			colWidths[2] := 80;
			grid.SetColSpacings(colWidths);
		END Resized;

		PROCEDURE DragDroppedH(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo; VAR handled : BOOLEAN);
		VAR
			dropTarget: URLDropTarget;
		BEGIN
			NEW(dropTarget, SELF, NIL);
			dragInfo.data := dropTarget;
			ConfirmDrag(TRUE, dragInfo);
		END DragDroppedH;
	END AudioPanel;

	DirectoryView* = OBJECT(WMTrees.TreeView);
	VAR
		tree : WMTrees.Tree;
		curNode: WMTrees.TreeNode;
		owner: DataPanel;
		onPathChanged : WMEvents.EventSource;
		onNodeRenamed : WMEvents.EventSource;
		popup: WMPopups.Popup;
		px, py: LONGINT;

		PROCEDURE &Init*;
		VAR
		BEGIN
			Init^;
			NEW(onPathChanged, SELF, NIL, NIL, NIL);
			events.Add(onPathChanged);
			NEW(onNodeRenamed, SELF, NIL, NIL, NIL);
			events.Add(onPathChanged);
			tree := GetTree();
			onSelectNode.Add(NodeSelected);
			SetExtContextMenuHandler(ContextMenu);
		END Init;

		PROCEDURE AddDir(dir: Directory);
		BEGIN
			AddNode(curNode, dir);
		END AddDir;

		PROCEDURE AddNode(parent: WMTrees.TreeNode; dir: Directory);
		VAR
			tr: WMTrees.TreeNode;
			cur: Directory;
		BEGIN
			tree.Acquire;
			NEW(tr);
			tree.SetNodeCaption(tr, dir.name);
			tree.SetNodeData(tr, dir);
			tree.InclNodeState(tr, WMTrees.NodeSubnodesUnknown);
			tree.AddChildNode(parent, tr);
			tree.Release;
			cur := dir.subdir;
			ExpandNode(tr);
			WHILE cur # NIL DO
				AddNode(tr, cur);
				cur := cur.nextdir;
			END;
		END AddNode;

		PROCEDURE SetSubDir(subdir: Directory);
		BEGIN
		 	curNode := GetTreeNode(subdir);
		 	ExpandNode(curNode);
		END SetSubDir;

		PROCEDURE GetTreeNode(dir: Directory): WMTrees.TreeNode;
		VAR
			cur: WMTrees.TreeNode;
			x: String;
		BEGIN
			(* dir must be a child of current node *)
			tree.Acquire;
			cur :=tree.GetChildren(curNode);
			WHILE (cur # NIL) & (tree.GetNodeData(cur) # dir) DO
				cur := tree.GetNextSibling(cur);
				x := tree.GetNodeCaption(cur);
			END;
			tree.Release;
			ASSERT (cur # NIL);
			RETURN cur;
		END GetTreeNode;

		PROCEDURE RemoveDir(dir: Directory);
		BEGIN
			tree.Acquire;
			tree.RemoveNode(GetTreeNode(dir));
			tree.Release;
		END RemoveDir;

		PROCEDURE ContextMenu(sender: ANY; x, y: LONGINT);
		VAR
			node: WMTrees.TreeNode;
		BEGIN
			IF enabled.Get() THEN
				NEW(popup);
				tree.Acquire;
				node := GetNodeAtPos(x, y);
				IF node # NIL THEN
					popup.AddParButton("Rename", Rename, node);
					px := x; py := y;
					ToWMCoordinates(x, y, px, py);
					popup.Popup(px, py);
				END;
				tree.Release;
			END;
		END ContextMenu;

		PROCEDURE Rename(sender, data : ANY);
		VAR
			rename : WMDialogs.MiniStringInput;
			name : ARRAY 128 OF CHAR;
			dir: Directory;
			tr: WMTrees.TreeNode;
			p: ANY;
		BEGIN
			IF ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.Rename, sender, data);
			ELSE
				IF popup # NIL THEN popup.Close; popup := NIL END;
				tree.Acquire;
				tr := data(WMTrees.TreeNode);
				p := tree.GetNodeData(tr);
				dir := p(Directory);
				NEW(rename);
				COPY(dir.name^, name);
				IF rename.Show(px, py, name) = WMDialogs.ResOk THEN
					IF (name # dir.name^) & (Strings.Length(name) > 0) THEN
						dir.name := Strings.NewString(name);
						tree.SetNodeCaption(tr, dir.name);
						onNodeRenamed.Call(dir);
					END;
				END;
				tree.Release;
			END;
		END Rename;

		PROCEDURE RenameNode(dir: Directory);
		BEGIN
			tree.Acquire;
			tree.SetNodeCaption(GetTreeNode(dir), dir.name);
			tree.Release;
		END RenameNode;

		PROCEDURE NodeSelected(sender, data : ANY);
		VAR
			tr: WMTrees.TreeNode;
			p: ANY;
		BEGIN
			IF ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.NodeSelected, sender, data);
			ELSE
				IF (data # NIL) & (data IS WMTrees.TreeNode) THEN
					tr := data(WMTrees.TreeNode);
					tree.Acquire;
					p := tree.GetNodeData(tr);
					curNode := tr; ExpandNode(tr);
					onPathChanged.Call(p(Directory));
					tree.Release
				END;
			END;
		END NodeSelected;

		PROCEDURE ExpandNode(tr: WMTrees.TreeNode);
		BEGIN
			tree.Acquire;
			tree.SetNodeState(tr, {WMTrees.NodeExpanded});
			tree.Release
		END ExpandNode;

		PROCEDURE DragDropped(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		VAR
			dropTarget: URLDropTarget;
			node : WMTrees.TreeNode;
			p: ANY;
			dir: Directory;
		BEGIN
			tree.Acquire;
			node := GetNodeAtPos(x, y);
			IF node # NIL THEN
				p := tree.GetNodeData(node);
				dir := p(Directory);
			END;
			NEW(dropTarget, owner, dir);
			dragInfo.data := dropTarget;
			ConfirmDrag(TRUE, dragInfo);
			tree.Release;
		END DragDropped;

		PROCEDURE SetRoot(dir: Directory);
		VAR
			tr: WMTrees.TreeNode;
			cur: Directory;
		BEGIN
			tree.Acquire;
			NEW(tr);
			curNode := tr;
			tree.SetRoot(tr);
			tree.SetNodeCaption(tr, dir.name);
			tree.SetNodeData( tr, dir);
			tree.InclNodeState(tr, WMTrees.NodeAlwaysExpanded);
			tree.Release;
			cur := dir.subdir;
			WHILE cur # NIL DO
				AddNode(tr, cur);
				cur := cur.nextdir;
			END;
		END SetRoot;
	END DirectoryView;

	FileList* = OBJECT(WMComponents.VisualComponent)
	VAR
		owner: DataPanel;
		grid : WMStringGrids.StringGrid;
		curDir: Directory;
		onPathChanged : WMEvents.EventSource;
		onDeleteEntries : WMEvents.EventSource;
		onNodeRenamed: WMEvents.EventSource;
		onNodeCreated: WMEvents.EventSource;
		popup: WMPopups.Popup;
		px, py: LONGINT;
		nofEntries: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			NEW(onPathChanged, SELF, NIL, NIL, NIL);
			events.Add(onPathChanged);
			NEW(onDeleteEntries, SELF, NIL, NIL, NIL);
			events.Add(onDeleteEntries);
			NEW(onNodeRenamed, SELF, NIL, NIL, NIL);
			events.Add(onNodeRenamed);
			NEW(onNodeCreated, SELF, NIL, NIL, NIL);
			events.Add(onNodeCreated);
			NEW(grid);
			grid.alignment.Set(WMComponents.AlignClient);
			grid.onClickSelected.Add(ClickSelected);
			grid.SetExtContextMenuHandler(ContextMenu);
			AddContent(grid);
			grid.model.Acquire;
			grid.model.SetNofCols(1);
			grid.model.SetNofRows(1);
			grid.fixedRows.Set(1);
			grid.model.SetCellText(0, 0, Strings.NewString("Name"));
			grid.SetSelectionMode(WMGrids.GridSelectRows);
			grid.model.Release;
			grid.SetExtDragDroppedHandler(DragDroppedH);
		END Init;

		PROCEDURE ContextMenu(sender: ANY; x, y: LONGINT);
		VAR
			curSel: Selection;
			w: SelectionWrapper;
		BEGIN
			IF enabled.Get() THEN
				NEW(popup); NEW(w);
				curSel := GetSelection();
				w.sel := curSel;
				popup.AddParButton("Create Direcotry", CreateDir, w);
				IF curSel # NIL THEN
					popup.AddParButton("Delete", Delete, w);
					IF  LEN(curSel) = 1 THEN
						popup.AddParButton("Rename", Rename, curSel[0]);
					END;
				END;
				px := x; py := y;
				grid.ToWMCoordinates(x, y, px, py);
				popup.Popup(px, py);
			END;
		END ContextMenu;

		PROCEDURE Delete(sender, data: ANY);
		BEGIN
			IF ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.Delete, sender, data);
			ELSE
				IF popup # NIL THEN popup.Close; popup := NIL END;
				onDeleteEntries.Call(data);
			END;
		END Delete;

		PROCEDURE CreateDir(sender, data: ANY);
		VAR
			dlg: WMDialogs.MiniStringInput;
			name: ARRAY MaxLen OF CHAR;
			dir: Directory;
		BEGIN
			IF ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.CreateDir, sender, data);
			ELSE
				IF popup # NIL THEN popup.Close; popup := NIL END;
				NEW(dlg);
				NEW(dlg);
				IF dlg.Show(px, py, name) = WMDialogs.ResOk THEN
					IF Strings.Length(name) > 0 THEN
						NEW(dir, curDir, Strings.NewString(name), NIL, curDir.depth+1);
						onNodeCreated.Call(dir);
						Refresh();
					END;
				END;
			END;
		END CreateDir;

		PROCEDURE Rename(sender, data : ANY);
		VAR
			dlg : WMDialogs.MiniStringInput;
			name : ARRAY MaxLen OF CHAR;
			node: MakeIsoImages.Node;
		BEGIN
			IF ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.Rename, sender, data);
			ELSE
				IF popup # NIL THEN popup.Close; popup := NIL END;
				IF data # NIL THEN
					node:= data(MakeIsoImages.Node);
					NEW(dlg);
					COPY(node.name^, name);
					IF dlg.Show(px, py, name) = WMDialogs.ResOk THEN
						IF (name # node.name^) & (Strings.Length(name) > 0) THEN
							node.name := Strings.NewString(name);
							onNodeRenamed.Call(node);
							Refresh();
						END;
					END;
				END;
			END;
		END Rename;

		PROCEDURE GetSelection(): Selection;
		VAR
			selection: Selection;
			l, t, r, b, i, j: LONGINT;
			p: ANY;
		BEGIN
			IF nofEntries < 1 THEN RETURN NIL END;
			grid.GetSelection(l, t, r, b);
			grid.model.Acquire;
			NEW(selection, b-t+1);
			j := 0;
			FOR i := t TO b DO
				 p := grid.model.GetCellData(0, i);
				 IF (p # NIL) & (p IS MakeIsoImages.Node) THEN
				 	selection[j] := p;
				 	INC(j);
				 END;
			END;
			grid.model.Release;
			RETURN selection;
		END GetSelection;

		PROCEDURE SetCurrentDir(dir: Directory);
		BEGIN
			curDir := dir;
			Refresh();
		END SetCurrentDir;

		PROCEDURE ClickSelected(sender, data : ANY);
		BEGIN
			IF ~sequencer.IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.ClickSelected, sender, data);
			ELSE
				IF (data # NIL) & (data IS Directory) THEN
					SetCurrentDir(data(Directory));
					onPathChanged.Call(data(Directory));
				END;
			END;
		END ClickSelected;

		PROCEDURE Refresh;
		VAR
			node: MakeIsoImages.Node;
			row: LONGINT;
		BEGIN
			IF curDir # NIL THEN
				grid.model.Acquire;
				nofEntries := GetNofNodes(curDir);
				grid.model.SetNofRows(nofEntries+1);
				node := curDir.content;
				WHILE node # NIL DO
					INC(row);
					IF node IS Directory THEN
						grid.model.SetCellImage(0, row, WMGraphics.LoadImage("icons.tar://Folder.png", TRUE));
					ELSE
						grid.model.SetCellImage(0, row, NIL)
					END;
					grid.model.SetCellData(0, row, node);
					grid.model.SetCellText(0, row, node.name);
					node := node.next;
				END;
				grid.model.Release;
			END;
		END Refresh;

		PROCEDURE GetNofNodes(dir: Directory): LONGINT;
		VAR
			cur: MakeIsoImages.Node;
			nofNodes: LONGINT;
		BEGIN
			cur := dir.content;
			WHILE cur # NIL DO
				INC(nofNodes);
				cur := cur.next;
			END;
			RETURN nofNodes;
		END GetNofNodes;

		PROCEDURE DragDroppedH(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo; VAR handled : BOOLEAN);
		VAR
			dropTarget: URLDropTarget;
		BEGIN
			NEW(dropTarget, owner, curDir);
			dragInfo.data := dropTarget;
			ConfirmDrag(TRUE, dragInfo);
		END DragDroppedH;
	END FileList;

	DataPanel = OBJECT(ProjectPanel);
	VAR
		dirView : DirectoryView;
		list: FileList;
		root: Directory;
		sidePanel: WMStandardComponents.Panel;

		PROCEDURE &New*(project: DataProject);
		VAR
			panel: WMStandardComponents.Panel;
			resizer: WMStandardComponents.Resizer;
		BEGIN
			Init();
			SELF.project := project;

			NEW(panel);
			panel.alignment.Set(WMComponents.AlignClient);
			panel.fillColor.Set(White);
			AddContent(panel);

			NEW(sidePanel);
			sidePanel.alignment.Set(WMComponents.AlignLeft);
			sidePanel.bounds.SetWidth(200);

			NEW(resizer);
			resizer.alignment.Set(WMComponents.AlignRight);
			resizer.bounds.SetWidth(4);
			sidePanel.AddContent(resizer);

			NEW(dirView); dirView.alignment.Set(WMComponents.AlignClient);
			dirView.owner := SELF;
			dirView.onPathChanged.Add(PathChanged);
			dirView.onNodeRenamed.Add(NodeRenamed);
			sidePanel.AddContent(dirView);
			panel.AddContent(sidePanel);

			NEW(list);
			list.owner := SELF;
			list.alignment.Set(WMComponents.AlignClient);
			list.onPathChanged.Add(PathChanged);
			list.onDeleteEntries.Add(DeleteEntries);
			list.onNodeRenamed.Add(NodeRenamed);
			list.onNodeCreated.Add(NodeCreated);
			panel.AddContent(list);

			IF project.root = NIL THEN
				NEW(root, NIL, Strings.NewString("NEW"), NIL, 0);
				root.parent := root;
				project.root := root;
			ELSE
				root := project.root(Directory);
			END;
			dirView.SetRoot(root);
			list.SetCurrentDir(root);
		END New;

		PROCEDURE NodeRenamed(sender, data: ANY);
		BEGIN
			IF sender IS DirectoryView THEN
				list.Refresh();
			ELSIF (sender IS FileList) & (data IS Directory) THEN
				dirView.RenameNode(data(Directory));
			END;
		END NodeRenamed;

		PROCEDURE NodeCreated(sender, data: ANY);
		VAR
			dir: Directory;
		BEGIN
			IF (sender IS FileList) THEN
				dir := data(Directory);
				Insert(dir.parent(Directory), dir);
			END;
		END NodeCreated;

		PROCEDURE DeleteEntry(node: MakeIsoImages.Node);
		VAR
			w: SelectionWrapper;
			sel: Selection;
		BEGIN
			NEW(sel, 1); sel[0] := node;
			NEW(w); w.sel := sel;
			DeleteEntries(SELF, w);
		END DeleteEntry;

		PROCEDURE DeleteEntries(sender, data: ANY);
		VAR
			cur, prev: MakeIsoImages.Node;
			curDir, prevDir, dir: Directory;
			i: LONGINT;
			selection: Selection;
		BEGIN
			i := 0;
			selection := data(SelectionWrapper).sel;
			curDir := list.curDir;
			cur := curDir.content;
			WHILE (cur # NIL) & (i < LEN(selection)) DO
				IF cur = selection[i] THEN
					IF cur = curDir.content THEN
						curDir.content := cur.next;
					ELSE
						prev.next := cur.next;
					END;
					INC(i);
					RemoveNode(cur); (* update project size *)
					owner.UpdateSize(project.totalSize, project(DataProject).overhead);
				ELSE
					prev := cur;
				END;
				cur := cur.next;
			END;
			list.Refresh();

			(* directories *)
			i := 0;
			dir := curDir.subdir;
			WHILE (dir # NIL) & (i < LEN(selection)) DO
				IF dir = selection[i] THEN
					IF curDir.subdir = selection[i] THEN
						curDir.subdir := dir.nextdir;
					ELSE
						prevDir.nextdir := dir.nextdir;
					END;
					dirView.RemoveDir(dir(Directory));
					INC(i);
				END;
				prevDir := dir;
				dir := dir.nextdir;
			END;
		END DeleteEntries;

		(* update overhead and size *)
		PROCEDURE RemoveNode(node: MakeIsoImages.Node);
		VAR
			cur: MakeIsoImages.Node;
		BEGIN
			IF node IS Directory THEN
				cur := node(Directory).content;
				WHILE cur # NIL DO
					RemoveNode(cur);
					cur := cur.next;
				END;
			ELSE (* File *)
				DEC(project.totalSize, node.size);
				IF node(MakeIsoImages.File).prevSession THEN
					INC(project(DataProject).overhead, node.size);
					DEC(project(DataProject).oldSize, node.size);
				END;
			END;
		END RemoveNode;

		PROCEDURE PathChanged(sender, data: ANY);
		BEGIN
			IF (data # NIL) & (data IS Directory) THEN
				IF sender IS DirectoryView THEN
					list.SetCurrentDir(data(Directory));
				ELSIF (data # NIL) & (sender IS FileList) THEN
					dirView.SetSubDir(data(Directory));
				END;
			END;
		END PathChanged;

		PROCEDURE AddFile(CONST name: ARRAY OF CHAR; node: ANY);
		VAR
			file: Files.File;
			parent, newDir: Directory;
			newFile: MakeIsoImages.File;
			path, filename: ARRAY MaxLen OF CHAR;
			old: MakeIsoImages.Node;
		BEGIN
			file:= Files.Old(name);
			IF (node # NIL) & (file # NIL) THEN
				parent := node(Directory);
				Files.SplitPath(name,  path, filename);
				old := GetNodeByName(parent, Strings.NewString(filename));
				IF old # NIL THEN
					IF WMDialogs.Confirmation("Confirm overwriting", filename) = WMDialogs.ResYes THEN
						DeleteEntry(old);
					ELSE
						RETURN;
					END;
				END;
				IF Files.Directory IN file.flags THEN
					NEW(newDir, parent, Strings.NewString(filename), Strings.NewString(name), parent.depth+1);
					Insert(parent, newDir);
					list.Refresh();
				ELSE
					NEW(newFile, Strings.NewString(filename), Strings.NewString(name), file.Length());
					INC(project.totalSize, newFile.size);
					owner.UpdateSize(project.totalSize, project(DataProject).overhead);
					Insert(parent, newFile);
					list.Refresh();
				END;
			END;
		END AddFile;

		PROCEDURE Insert(parent: Directory; node: MakeIsoImages.Node);
		VAR
			cur: MakeIsoImages.Node;
			dir: Directory;
		BEGIN
			(* always insert at the end of the list *)
			IF parent.content  = NIL THEN
				parent.content := node;
			ELSE
				cur := parent.content;
				WHILE cur.next # NIL DO
					cur := cur.next;
				END;
				cur.next := node;
			END;

			IF node IS Directory THEN
				IF parent.subdir = NIL THEN
					parent.subdir := node(Directory);
				ELSE
					dir := parent.subdir(Directory);
					WHILE dir.nextdir # NIL DO
						dir := dir.nextdir(Directory);
					END;
					dir.nextdir := node(Directory);
				END;

				BuildDir(node(Directory));
				dirView.AddDir(node(Directory));
			END;
		END Insert;

		PROCEDURE GetNodeByName(parent: Directory; name: String): MakeIsoImages.Node;
		VAR
			cur: MakeIsoImages.Node;
		BEGIN
			cur := parent.content;
			WHILE cur # NIL DO
				IF cur.name^ = name^ THEN
					RETURN cur;
				END;
				cur := cur.next;
			END;
			RETURN NIL;
		END GetNodeByName;

		PROCEDURE BuildDir(dir: Directory);
		VAR
			enumerator: Files.Enumerator;
			name, filename, path, mask: ARRAY MaxLen OF CHAR;
			time, date, size: LONGINT;
			flags: SET;
			newDir, curDir : Directory;
			newFile : MakeIsoImages.File;
			cur, tmp : MakeIsoImages.Node;
		BEGIN
			NEW(enumerator);
			IF dir.fullpath = NIL THEN RETURN END;
			COPY(dir.fullpath^, mask);
			Strings.Append(mask, "/*");
			enumerator.Open(mask, {Files.EnumSize});
			WHILE enumerator.HasMoreEntries() DO
				IF enumerator.GetEntry(name, flags, time, date, size) THEN
					Files.SplitPath(name, path, filename);
					IF Files.Directory IN flags THEN
						NEW(newDir, dir, Strings.NewString(filename), Strings.NewString(name), dir.depth+1);
						BuildDir(newDir);
						IF dir.subdir = NIL THEN
							dir.subdir := newDir;
						ELSE
							curDir.nextdir := newDir;
						END;
						curDir := newDir;
						tmp := newDir;
					ELSE
						NEW(newFile, Strings.NewString(filename), Strings.NewString(name), size);
						INC(project.totalSize, size);
						owner.UpdateSize(project.totalSize, project(DataProject).overhead);
						tmp := newFile;
					END;
					IF dir.content = NIL THEN
						dir.content := tmp;
					ELSE
						cur.next := tmp;
					END;
					cur := tmp;
				END;
			END;
		END BuildDir;
	END DataPanel;

	Time = OBJECT
		VAR
			sec, min, hour: LONGINT;

		PROCEDURE SetTime(seconds: LONGINT);
		VAR
			rem: LONGINT;
		BEGIN
			rem := seconds;
			sec := rem MOD 60; rem := rem DIV 60;
			min := rem MOD 60; rem := rem DIV 60;
			hour := rem MOD 24;
		END SetTime;

		PROCEDURE Format(VAR str: ARRAY OF CHAR);
		VAR
			tmp: ARRAY MaxLen OF CHAR;
		BEGIN
			str := "";
			IF hour < 10 THEN str := "0" END;
			Strings.IntToStr(hour, tmp); Strings.Append(str, tmp); Strings.Append(str, ":");
			IF min < 10 THEN Strings.Append(str, "0") END;
			Strings.IntToStr(min, tmp); Strings.Append(str, tmp); Strings.Append(str, ":");
			IF sec < 10 THEN Strings.Append(str, "0") END;
			Strings.IntToStr(sec, tmp); Strings.Append(str, tmp);
		END Format;
	END Time;

	RunProc = PROCEDURE{DELEGATE} (sender, data: ANY);

	Handler = OBJECT
		VAR
			data: ANY;
			proc: RunProc;

		PROCEDURE &New*(proc: RunProc; data: ANY);
		BEGIN
			SELF.proc := proc;
			SELF.data := data;
		END New;

		BEGIN {ACTIVE}
			proc(SELF, data);
	END Handler;

	Timer = OBJECT(WMStandardComponents.Timer);
		VAR
			start: LONGINT;
			onUpdate*: WMEvents.EventSource;
			time: Time;

		PROCEDURE &Init*;
		BEGIN
			Init^();
			NEW(onUpdate, SELF, NIL, NIL, NIL);
			NEW(time);
			onTimer.Add(UpdateHandler);
		END Init;

		PROCEDURE UpdateHandler(sender, date: ANY);
		VAR
			diff: LONGINT;
		BEGIN
			diff := (Kernel.GetTicks () - start) DIV 1000;
			time.SetTime(diff);
			onUpdate.Call(time);
		END UpdateHandler;

		PROCEDURE Start(sender, data: ANY);
		BEGIN
			start := Kernel.GetTicks ();
			Start^(sender, data);
		END Start;
	END Timer;

VAR
	nofWindows: LONGINT;
	recorders: ARRAY CDRecord.MaxRecorders OF  CDRecord.CDRecorder;

(* returns true if the hd on which a source file is located is on the same controller as the recorder *)
PROCEDURE CheckController(compilation: CDRecord.Compilation; recorder: CDRecord.CDRecorder; VAR name: ARRAY OF CHAR): BOOLEAN;
VAR
	i: LONGINT;
	track: CDRecord.InformationTrack;
	device: Disks.Device;
BEGIN
	FOR i := 0 TO compilation.nofTracks-1 DO
		IF (compilation.tracks[i] # NIL) & (compilation.tracks[i] IS CDRecord.InformationTrack) THEN
			track := compilation.tracks[i](CDRecord.InformationTrack);
			IF (Utils.GetDevice(track.file, device) = ResOk) & Utils.IsOnSameController(device, recorder.dev) THEN
				COPY(device.name, name);
				RETURN TRUE;
			END;
		END;
	END;
	RETURN FALSE;
END CheckController;

PROCEDURE FileExists(CONST filename: ARRAY OF CHAR): BOOLEAN;
BEGIN
	RETURN Files.Old(filename) # NIL;
END FileExists;

PROCEDURE GetFileSize(CONST filename: ARRAY OF CHAR): LONGINT;
VAR
	file: Files.File;
BEGIN
	file := Files.Old(filename);
	RETURN file.Length();
END GetFileSize;

PROCEDURE RemoveSpecialChars(VAR str: ARRAY OF CHAR);
VAR
	i, j: LONGINT;
BEGIN
	j := 0;
	FOR i := 0 TO LEN(str) - 1 DO
		IF ORD(str[i]) > 31 THEN
			str[j] := str[i]; INC(j);
		END;
	END;
	str[j] := 0X;
END RemoveSpecialChars;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR
	die: KillerMsg;
	msg: WMMessages.Message;
	m: WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

PROCEDURE Open*;
VAR
	wnd: Window;
BEGIN
	NEW(wnd);
END Open;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMCDRecorder.

WMCDRecorder.Open~

