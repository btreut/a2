MODULE WMInstaller; (** AUTHOR "staubesv"; PURPOSE "Graphical installer"; *)

IMPORT
	KernelLog, Modules, Kernel, Streams, Strings, Texts, TextUtilities, Codecs,
	Disks, PartitionsLib, Installer,
	WMRectangles, WMWindowManager, WMGraphics, WMGraphicUtilities, WMComponents, WMStandardComponents, WMTextView, WMEditors,
	WMProgressComponents, WMPartitionsComponents, WMDialogs;

CONST
	DefaultPackageFile = "InstallerPackages.XML";

	ImageLogo = "WMInstaller.tar://OberonLogoSmall.png";
	TitleText = "WMInstaller.tar://Title.Text";
	HelpText = "WMInstaller.tar://Help.Text";
	TextSelectPartition = "WMInstaller.tar://SelectPartition.Text";
	TextSelectPackages = "WMInstaller.tar://SelectPackages.Text";
	TextInstallSteps = "WMInstaller.tar://InstallSteps.Text";
	TextInstallLog = "WMInstaller.tar://InstallLog.Text";
	TextAdvancedOptions = "WMInstaller.tar://AdvancedOptions.Text";
	DefaultConfigFile = "WMInstaller.tar://DefaultConfig.Text"; (* MUST BE UTF-8 *)

	WindowTitle = "Installer";
	WindowWidth = 640;
	WindowHeight = 400;

	WindowMinWidth = 600;
	WindowMinHeight = 300;

	OberonColor =  LONGINT(0D1616CAFH);

	UpperPanelHeight = 60;
	LowerPanelHeight = 60;
	ButtonPanelHeight = 20;

	ImageWidth = 150;

	PageSelectPartition = 0;
	PageSelectPackages = 1;
	PageShowSteps = 2;
	PageShowLog = 3;
	PageAdvancedOptions = 4;

	NofPages = 5;

	(* PackageSelector *)
	LineHeight = 20;

	MouseWheelMultiplier = LineHeight;

TYPE

	(* Panel that can vertically scroll its content *)
	ScrollPanel = OBJECT(WMComponents.VisualComponent)
	VAR
		content : WMComponents.VisualComponent;
		scrollbar : WMStandardComponents.Scrollbar;
		scrollPanel : WMStandardComponents.Panel;

		PROCEDURE SetContent(content : WMComponents.VisualComponent);
		BEGIN
			ASSERT(content.alignment.Get() = WMComponents.AlignNone);
			IF (SELF.content # NIL) THEN scrollPanel.RemoveContent(SELF.content); END;
			scrollPanel.AddContent(content);
			SELF.content := content;
		END SetContent;

		PROCEDURE Resized;
		BEGIN
			Resized^;
			IF (content # NIL) THEN
				CheckScrollbars;
				content.bounds.SetWidth(scrollPanel.bounds.GetWidth());
			END;
		END Resized;

		PROCEDURE CheckScrollbars;
		VAR availableHeight, neededHeight : LONGINT;
		BEGIN
			IF (content = NIL) THEN RETURN; END;
			availableHeight := scrollPanel.bounds.GetHeight();
			neededHeight := content.bounds.GetHeight();
			IF (availableHeight >= neededHeight) THEN
				content.bounds.SetTop(0);
				scrollbar.visible.Set(FALSE);
			ELSE
				scrollbar.min.Set(0);
				scrollbar.max.Set(neededHeight - availableHeight);
				scrollbar.visible.Set(TRUE);
			END;
		END CheckScrollbars;

		PROCEDURE ScrollbarChanged(sender, data : ANY);
		BEGIN
			IF (content # NIL) THEN content.bounds.SetTop(-scrollbar.pos.Get()); END;
		END ScrollbarChanged;

		PROCEDURE WheelMove(dz : LONGINT);
		BEGIN
			IF (scrollbar.visible.Get()) THEN
				scrollbar.pos.Set(scrollbar.pos.Get() + dz * MouseWheelMultiplier);
				ScrollbarChanged(NIL, NIL);
			END;
		END WheelMove;

		PROCEDURE &Init*;
		BEGIN
			Init^;

			NEW(scrollbar); scrollbar.alignment.Set(WMComponents.AlignRight);
			scrollbar.vertical.Set(TRUE);
			scrollbar.onPositionChanged.Add(ScrollbarChanged);
			AddContent(scrollbar);

			NEW(scrollPanel); scrollPanel.alignment.Set(WMComponents.AlignClient);
			AddContent(scrollPanel);

			SetNameAsString(StrScrollPanel);
		END Init;

	END ScrollPanel;

TYPE

	PackageSelector = OBJECT(WMComponents.VisualComponent)
	VAR
		packageList : Installer.PackageArray;
		scrollPanel : ScrollPanel;
		label : WMStandardComponents.Label;
		allBtn, noneBtn : WMStandardComponents.Button;

		PROCEDURE ClickHandler(sender, data : ANY);
		VAR checkbox : WMStandardComponents.Checkbox; msg : ARRAY 512 OF CHAR;i : LONGINT; install : BOOLEAN;
		BEGIN
			FOR i := 0 TO LEN(packageList)-1 DO
				checkbox := packageList[i].user (WMStandardComponents.Checkbox);
				IF (sender = checkbox) THEN
					install := (checkbox.state.Get() = WMStandardComponents.Checked);
					IF ~packageList[i].SetInstall(install, msg) THEN
						WMDialogs.Error(WindowTitle, msg);
						IF install THEN
							checkbox.state.Set(WMStandardComponents.Unchecked);
						ELSE
							checkbox.state.Set(WMStandardComponents.Checked);
						END;
					END;
				END;
			END;
			UpdateLabel;
		END ClickHandler;

		PROCEDURE GetTotalSize(VAR size, sizeOnDisk : LONGINT);
		VAR i : LONGINT;
		BEGIN
			size := 0; sizeOnDisk := 0;
			IF (packageList = NIL) THEN RETURN; END;
			FOR i := 0 TO LEN(packageList)-1 DO
				IF (packageList[i].install) THEN
					size := size + packageList[i].size;
					sizeOnDisk := sizeOnDisk + packageList[i].sizeOnDisk;
				END;
			END;
			size := (size DIV 1024); IF (size MOD 1024 # 0) THEN INC(size); END;
			sizeOnDisk := (sizeOnDisk DIV 1024); IF (sizeOnDisk MOD 1024 # 0) THEN INC(sizeOnDisk); END;
		END GetTotalSize;

		PROCEDURE UpdateLabel;
		VAR caption : ARRAY 128 OF CHAR; nbr : ARRAY 16 OF CHAR; size, sizeOnDisk : LONGINT;
		BEGIN
			caption := "Total Size: ";
			GetTotalSize(size, sizeOnDisk);
			Strings.IntToStr(size, nbr);
			Strings.Append(caption, nbr); Strings.Append(caption, " KB");
			Strings.IntToStr(sizeOnDisk, nbr);
			Strings.Append(caption, "  (Size on disk: "); Strings.Append(caption, nbr); Strings.Append(caption, " KB)");
			label.caption.SetAOC(caption);
		END UpdateLabel;

		PROCEDURE GetSizeString(package : Installer.Package; VAR caption : ARRAY OF CHAR);
		BEGIN
			IF (package.file # NIL) THEN
				Strings.IntToStr((package.size DIV 1024) + 1, caption);
				Strings.Append(caption, " KB");
			ELSE
				caption := "n/a";
			END;
		END GetSizeString;

		PROCEDURE CreatePackagePanel(package : Installer.Package) : WMStandardComponents.Panel;
		VAR
			panel : WMStandardComponents.Panel; l : WMStandardComponents.Label; checkbox : WMStandardComponents.Checkbox; caption : ARRAY 64 OF CHAR;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignTop);
			panel.bounds.SetHeight(LineHeight);

			NEW(checkbox); checkbox.alignment.Set(WMComponents.AlignLeft);
			checkbox.bearing.Set(WMRectangles.MakeRect(5, 5, 10, 5));
			checkbox.bounds.SetWidth(20);
			checkbox.onClick.Add(ClickHandler);
			IF package.install THEN checkbox.state.Set(WMStandardComponents.Checked);
			ELSE checkbox.state.Set(WMStandardComponents.Unchecked);
			END;
			panel.AddContent(checkbox);
			package.user := checkbox;

			NEW(l); l.alignment.Set(WMComponents.AlignRight);
			l.bounds.SetWidth(60);
			GetSizeString(package, caption); l.caption.SetAOC(caption);
			panel.AddContent(l);

			NEW(l); l.alignment.Set(WMComponents.AlignLeft);
			l.bounds.SetWidth(140);
			l.bearing.Set(WMRectangles.MakeRect(5, 0, 0, 0));
			l.caption.Set(package.filename);
			panel.AddContent(l);

			NEW(l); l.alignment.Set(WMComponents.AlignClient);
			l.caption.Set(package.description);
			panel.AddContent(l);

			RETURN panel;
		END CreatePackagePanel;

		PROCEDURE SetPackages(packages : Installer.Packages);
		VAR packagePanel : WMStandardComponents.Panel; panel : WMStandardComponents.Panel; height, i : LONGINT;
		BEGIN
			ASSERT(packages # NIL);
			height := 0;
			NEW(panel); panel.alignment.Set(WMComponents.AlignNone);

			packageList := packages.GetPackages();
			IF packageList # NIL THEN
				FOR i := 0 TO LEN(packageList)-1 DO
					packagePanel := CreatePackagePanel(packageList[i]);
					height := height + packagePanel.bounds.GetHeight();
					panel.AddContent(packagePanel);
				END;
			ELSE
			END;

			panel.bounds.SetHeight(height);
			panel.bounds.SetWidth(bounds.GetWidth());
			scrollPanel.SetContent(panel);

			UpdateLabel;
		END SetPackages;

		PROCEDURE HandleButtons(sender, data : ANY);
		VAR newState, i : LONGINT; checkbox : WMStandardComponents.Checkbox; ignore : ARRAY 512 OF CHAR; install : BOOLEAN;
		BEGIN
			IF (sender = allBtn) THEN
				newState := WMStandardComponents.Checked;
			ELSE (* sender = allBtn *)
				newState := WMStandardComponents.Unchecked;
			END;
			FOR i := 0 TO LEN(packageList)-1 DO
				checkbox := packageList[i].user (WMStandardComponents.Checkbox);
				install := (newState = WMStandardComponents.Checked);
				IF packageList[i].SetInstall(install, ignore) THEN
					checkbox.state.Set(newState);
				END;
			END;
			UpdateLabel;
		END HandleButtons;

		PROCEDURE &New*;
		VAR panel : BorderPanel;
		BEGIN
			Init;

			NEW(panel); panel.alignment.Set(WMComponents.AlignBottom);
			panel.bounds.SetHeight(LineHeight); panel.fillColor.Set(WMGraphics.White);
			AddContent(panel);

			NEW(noneBtn); noneBtn.alignment.Set(WMComponents.AlignRight);
			noneBtn.caption.SetAOC("None");
			noneBtn.onClick.Add(HandleButtons);
			panel.AddContent(noneBtn);

			NEW(allBtn); allBtn.alignment.Set(WMComponents.AlignRight);
			allBtn.caption.SetAOC("All");
			allBtn.onClick.Add(HandleButtons);
			panel.AddContent(allBtn);

			NEW(label); label.alignment.Set(WMComponents.AlignClient);
			label.bearing.Set(WMRectangles.MakeRect(5, 0, 0, 0));
			label.fillColor.Set(WMGraphics.White);
			panel.AddContent(label);

			NEW(scrollPanel); scrollPanel.alignment.Set(WMComponents.AlignClient);
			AddContent(scrollPanel);

			SetNameAsString(StrPackageSelector);
		END New;

	END PackageSelector;

TYPE

	ConfigurationSettings = OBJECT(WMComponents.VisualComponent)
	VAR
		steps : ARRAY Installer.NofSteps OF WMStandardComponents.Checkbox;

		mbrFileEdit,  bootLoaderEdit, bootFileEdit, bootFile2Edit,
		bootManMbrEdit, bootManRestEdit, prefixEdit : WMEditors.Editor;

		config : Installer.Configuration;
		scrollPanel : ScrollPanel;
		panel : WMStandardComponents.Panel;

		PROCEDURE CreateConfigPanel() : WMStandardComponents.Panel;
		VAR panel, line : WMStandardComponents.Panel; lineNbr, height : LONGINT;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignNone);

			height := 0;
			FOR lineNbr := 1 TO Installer.NofSteps-1 DO
				line := CreateLine(lineNbr);
				panel.AddContent(line);
				height := height + line.bounds.GetHeight();
			END;
			panel.bounds.SetHeight(height);

			RETURN panel;
		END CreateConfigPanel;

		PROCEDURE SetConfiguration(config : Installer.Configuration);
		BEGIN
			ASSERT(config # NIL);
			SELF.config := config.Clone();
			panel := CreateConfigPanel();
			panel.bounds.SetWidth(scrollPanel.bounds.GetWidth());
			scrollPanel.SetContent(panel);
		END SetConfiguration;

		PROCEDURE GetConfiguration() : Installer.Configuration;
		BEGIN
			RETURN config;
		END GetConfiguration;

		PROCEDURE IsValidConfiguration(w : Streams.Writer) : BOOLEAN;
		BEGIN
			ASSERT(w # NIL);
			RETURN config.CheckConfiguration(w);
		END IsValidConfiguration;

		PROCEDURE CreateLine(lineNbr : LONGINT) : WMStandardComponents.Panel;
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignTop);
			panel.bounds.SetHeight(LineHeight);

			NEW(steps[lineNbr]); steps[lineNbr].alignment.Set(WMComponents.AlignLeft);
			steps[lineNbr].bounds.SetWidth(LineHeight);
			steps[lineNbr].bearing.Set(WMRectangles.MakeRect(5, 5, 10, 5));
			steps[lineNbr].onClick.Add(ClickHandler);
			panel.AddContent(steps[lineNbr]);

			IF config.DoStep(lineNbr) THEN
				steps[lineNbr].state.Set(WMStandardComponents.Checked);
			ELSE
				steps[lineNbr].state.Set(WMStandardComponents.Unchecked);
			END;

			CASE lineNbr OF
				|Installer.WriteMBR:
					panel.AddContent(NewLabel("WriteMBR", 100));
					panel.AddContent(NewLabel("MBR filename:", 90)); NewEditor(mbrFileEdit, config.mbrFile, 0); panel.AddContent(mbrFileEdit);
				|Installer.CreatePartition:
					panel.AddContent(NewLabel("CreatePartition", 100));
					panel.AddContent(NewLabel("Create a new partition of type 76?", 0));
				|Installer.ChangeType:
					panel.AddContent(NewLabel("ChangeType", 100));
					panel.AddContent(NewLabel("Changes the partition type to 76 (AosFS)", 0));
				|Installer.Activate:
					panel.AddContent(NewLabel("Activate", 100));
					panel.AddContent(NewLabel("Set the active flag of the partition?", 0));
				|Installer.Format:
					panel.AddContent(NewLabel("Format", 100));
					panel.AddContent(NewLabel("Boot Loader:", 90)); NewEditor(bootLoaderEdit, config.bootloader, 100); panel.AddContent(bootLoaderEdit);
					panel.AddContent(NewLabel("  Boot File:", 60)); NewEditor(bootFileEdit, config.bootfile, 0); panel.AddContent(bootFileEdit);
				|Installer.UpdateBootfile:
					panel.AddContent(NewLabel("UpdateBootFile", 100));
					panel.AddContent(NewLabel("Boot File:", 90)); NewEditor(bootFile2Edit, config.bootfile, 0); panel.AddContent(bootFile2Edit);
				|Installer.SetConfig:
					panel.AddContent(NewLabel("SetConfig", 100));
				|Installer.InstallBootManager:
					panel.AddContent(NewLabel("BootManager", 100));
					panel.AddContent(NewLabel("Boot MBR: ", 90)); NewEditor(bootManMbrEdit, config.bootManMBR, 100); panel.AddContent(bootManMbrEdit);
					panel.AddContent(NewLabel("Boot Manager: ", 90)); NewEditor(bootManRestEdit, config.bootManRest, 0); panel.AddContent(bootManRestEdit);
				|Installer.Mount:
					panel.AddContent(NewLabel("Mount", 100));
					panel.AddContent(NewLabel("Prefix:", 90)); NewEditor(prefixEdit, config.mountPrefix, 0); panel.AddContent(prefixEdit);
				|Installer.InstallPackages:
					panel.AddContent(NewLabel("InstallPackages", 100));
					panel.AddContent(NewLabel("Should packages be installed?", 0));
				|Installer.Unmount:
					panel.AddContent(NewLabel("Unmount", 100));
					panel.AddContent(NewLabel("Unmount partition after installation", 0));
			ELSE
			END;

			RETURN panel;
		END CreateLine;

		PROCEDURE ClickHandler(sender, data : ANY);
		VAR checkbox : WMStandardComponents.Checkbox; msg : ARRAY 512 OF CHAR; i : LONGINT; doStep : BOOLEAN;
		BEGIN
			i := 0;
			LOOP
				IF (i >= LEN(steps)) OR (sender = steps[i]) THEN EXIT; END;
				INC(i);
			END;
			IF (i < LEN(steps)) THEN
				checkbox := sender (WMStandardComponents.Checkbox);
				doStep := (checkbox.state.Get() = WMStandardComponents.Checked);
				IF ~config.SetInstallStep(i, doStep, msg) THEN
					WMDialogs.Error(WindowTitle,  msg);
					IF doStep THEN
						checkbox.state.Set(WMStandardComponents.Unchecked);
					ELSE
						checkbox.state.Set(WMStandardComponents.Checked);
					END;
				END;
			END;
		END ClickHandler;

		PROCEDURE ApplyConfiguration;
		VAR step : LONGINT;
		BEGIN
			ASSERT(config # NIL);
			FOR step := 1 TO Installer.NofSteps-1 DO
				CASE step OF
					|Installer.WriteMBR:
						mbrFileEdit.GetAsString(config.mbrFile);
					|Installer.CreatePartition:
					|Installer.ChangeType:
					|Installer.Activate:
					|Installer.Format:
						bootLoaderEdit.GetAsString(config.bootloader);
						bootFileEdit.GetAsString(config.bootfile);
					|Installer.UpdateBootfile:
						bootFileEdit.GetAsString(config.bootfile);
					|Installer.SetConfig:
					|Installer.InstallBootManager:
						bootManMbrEdit.GetAsString(config.bootManMBR);
						bootManRestEdit.GetAsString(config.bootManRest);
					|Installer.Mount:
						prefixEdit.GetAsString(config.mountPrefix);
					|Installer.InstallPackages:
					|Installer.Unmount:
				ELSE
				END;
			END;
		END ApplyConfiguration;

		PROCEDURE NewLabel(CONST caption : ARRAY OF CHAR; width : LONGINT) : WMStandardComponents.Label;
		VAR label : WMStandardComponents.Label;
		BEGIN
			NEW(label);
			IF (width > 0) THEN
				label.alignment.Set(WMComponents.AlignLeft);
				label.bounds.SetWidth(width);
			ELSE
				label.alignment.Set(WMComponents.AlignClient);
			END;
			label.caption.SetAOC(caption);
			RETURN label;
		END NewLabel;

		PROCEDURE NewEditor(VAR editor : WMEditors.Editor; CONST caption : ARRAY OF CHAR; width : LONGINT);
		BEGIN
			NEW(editor);
			IF (width > 0) THEN
				editor.alignment.Set(WMComponents.AlignLeft);
				editor.bounds.SetWidth(width);
			ELSE
				editor.alignment.Set(WMComponents.AlignClient);
			END;
			editor.SetAsString(caption);
			editor.multiLine.Set(FALSE);
			editor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			editor.tv.showBorder.Set(TRUE);
		END NewEditor;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrConfigurationSettings);
			config := NIL;
			NEW(scrollPanel); scrollPanel.alignment.Set(WMComponents.AlignClient);
			AddContent(scrollPanel);
		END Init;

	END ConfigurationSettings;

TYPE

	InstallerBgPanel = OBJECT(WMComponents.VisualComponent)

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR color : LONGINT; rect : WMRectangles.Rectangle;
		BEGIN
			DrawBackground^(canvas); (* fills background with fillColor *)
			rect := GetClientRect();
			color := OberonColor;
			rect.l := rect.l + 0;
			rect.r := rect.r - 0;
			rect.b := rect.b + 0;
			rect.t := rect.b - ButtonPanelHeight - LowerPanelHeight - 40;
			IF color # 0 THEN canvas.Fill(rect, color, WMGraphics.ModeSrcOverDst) END;
		END DrawBackground;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrInstallerBgPanel);
		END Init;

	END InstallerBgPanel;

	BorderPanel = OBJECT(WMStandardComponents.Panel)

		PROCEDURE DrawForeground(canvas : WMGraphics.Canvas);
		BEGIN
			DrawForeground^(canvas);
			WMGraphicUtilities.DrawBevel(canvas, GetClientRect(), 1, TRUE, LONGINT(0808080FFH), WMGraphics.ModeCopy);
		END DrawForeground;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrBorderPanel);
		END Init;

	END BorderPanel;

TYPE

	Window = OBJECT(WMComponents.FormWindow)
	VAR
		main : WMComponents.VisualComponent;
		buttonPanel : WMStandardComponents.Panel;
		upperText, lowerText : Texts.Text;
		logText, stepsText : Texts.Text;
		imagePanel : WMStandardComponents.ImagePanel;
		showDetailsBtn : WMStandardComponents.Button;
		showDetails : BOOLEAN;
		titleLabel : WMStandardComponents.Label;

		helpBtn, quickInstallBtn, backBtn, nextBtn : WMStandardComponents.Button;

		w, stepsW : TextUtilities.TextWriter;

		selectionLabel : WMStandardComponents.Label;

		progressBar : WMProgressComponents.ProgressBar;
		progressPoller : PollProgress;
		partitionSelector : WMPartitionsComponents.PartitionSelector;

		packageSelector : PackageSelector;
		configurationSettings : ConfigurationSettings;

		pages : ARRAY NofPages OF WMComponents.VisualComponent;
		currentPage : LONGINT;

		packages : Installer.Packages;

		installer : Installer.Installer;
		configuration : Installer.Configuration;
		selection, lockedSelection : WMPartitionsComponents.Selection;
		opened : BOOLEAN;

		PROCEDURE Resizing(VAR width, height : LONGINT);
		BEGIN
			IF width < WindowMinWidth THEN width := WindowMinWidth; END;
			IF height < WindowMinHeight THEN height := WindowMinHeight; END;
		END Resizing;

		PROCEDURE ShowHelpText;
		VAR text : Texts.Text;
		BEGIN
			IF (helpWindow = NIL) THEN
				NEW(text);
				LoadText(text, HelpText);
				IF (text # NIL) THEN
					NEW(helpWindow, text);
				ELSE
					WMDialogs.Error(WindowTitle, "Could not load help text");
				END;
			END;
		END ShowHelpText;

		PROCEDURE GetDiskPartString(selection : WMPartitionsComponents.Selection) : Strings.String;
		VAR diskPartString : Strings.String; string, nbr : ARRAY 32 OF CHAR;
		BEGIN
			IF IsValidSelection(selection) THEN
				string := ""; Strings.Append(string, selection.disk.device.name);
				Strings.IntToStr(selection.partition, nbr);
				Strings.Append(string, "#"); Strings.Append(string, nbr);
				diskPartString := Strings.NewString(string);
			ELSE
				diskPartString := Strings.NewString("INVALID");
			END;
			ASSERT(diskPartString # NIL);
			RETURN diskPartString;
		END GetDiskPartString;

		PROCEDURE ReallyDoInstallation(selection : WMPartitionsComponents.Selection) : BOOLEAN;
		VAR res : LONGINT; string : ARRAY 256 OF CHAR; diskPartString : Strings.String;
		BEGIN
			ASSERT(IsValidSelection(selection));
			string := "The installation will delete all content on partition ";
			diskPartString := GetDiskPartString(selection);
			Strings.Append(string, diskPartString^); Strings.Append(string, ". Do you want to start the installation?");

			res := WMDialogs.Confirmation(WindowTitle, string);
			RETURN res = WMDialogs.ResYes;
		END ReallyDoInstallation;

		PROCEDURE HandleButtons(sender, data : ANY);
		VAR caption : Strings.String; errorWriter : Streams.StringWriter; errorString : ARRAY 1024 OF CHAR;
		BEGIN
			IF sender = showDetailsBtn THEN
				showDetails := ~showDetails;
				partitionSelector.showDetails.Set(showDetails);
			ELSIF sender = helpBtn THEN
				ShowHelpText;
			ELSIF sender = quickInstallBtn THEN
				IF (currentPage = PageSelectPartition) & QuickInstall() THEN
					SelectPage(PageShowLog);
				ELSIF (currentPage = PageShowSteps) THEN
					configurationSettings.SetConfiguration(configuration);
					SelectPage(PageAdvancedOptions);
				END;
			ELSIF sender = nextBtn THEN
				CASE currentPage OF
					|PageSelectPartition: (* next *)
						IF GetSelection(selection) THEN
							IF LockPartition(selection) THEN
								IF LoadPackages(DefaultPackageFile, packages) THEN
									packageSelector.SetPackages(packages);
									SelectPage(PageSelectPackages);
								END;
							END;
						END;
					|PageSelectPackages: (* next *)
						ClearText(stepsText);
						IF GetConfiguration(selection, packages, configuration) THEN
							configuration.ToStream(stepsW);
							SelectPage(PageShowSteps);
						END;
					|PageShowSteps: (* next *)
						ClearText(logText);
						IF CheckConfiguration(configuration) THEN
							SelectPage(PageShowLog);
							StartInstaller(selection, configuration);
						END;
					|PageShowLog:	(* abort or done *)
						caption := nextBtn.caption.Get();
						IF (caption # NIL) & (caption^ = "Done") THEN
							Close;
						ELSE
							StopInstaller;
						END;
					|PageAdvancedOptions:	(*ok *)
						configurationSettings.ApplyConfiguration;
						NEW(errorWriter, LEN(errorString));
						IF ~configurationSettings.IsValidConfiguration(errorWriter) THEN
							errorWriter.Get(errorString);
							WMDialogs.Error(WindowTitle, errorString);
						ELSE
							configuration := configurationSettings.GetConfiguration();
							ClearText(stepsText);
							configuration.ToStream(stepsW);
							SelectPage(PageShowSteps);
						END;
				ELSE
				END;
			ELSIF sender = backBtn THEN
				CASE currentPage OF
					|PageSelectPartition: (* btn2 not visible *)
					|PageSelectPackages: (* back*)
						SelectPage(PageSelectPartition);
						UnlockPartition(lockedSelection);
					|PageShowSteps: (* back *)
						SelectPage(PageSelectPackages);
					|PageShowLog: (* back, only visible after installer has been aborted or has finished *)
						installer := NIL;
						packages := NIL;
						configuration := NIL;
						IF (progressPoller # NIL) THEN progressPoller.Close; progressPoller := NIL; END;
						partitionSelector.ClearSelection;
						SelectPage(PageSelectPartition);
					|PageAdvancedOptions: (* abort *)
						SelectPage(PageShowSteps);
				ELSE
				END;
			END;
		END HandleButtons;

		PROCEDURE HandleSelection(sender, data : ANY);
		VAR selection : PartitionsLib.Selection; caption : ARRAY 128 OF CHAR; nbr : ARRAY 4 OF CHAR;
		BEGIN
			IF (data # NIL) & (data IS WMPartitionsComponents.SelectionWrapper) THEN
				selection := data(WMPartitionsComponents.SelectionWrapper).selection;
				caption := " Selection: ";
				IF (selection.disk.device # NIL) THEN
					Strings.Append(caption, selection.disk.device.name);
					Strings.Append(caption, "#");
					Strings.IntToStr(selection.partition, nbr); Strings.Append(caption, nbr);
				ELSE
					caption := "None";
				END;
				selectionLabel.caption.SetAOC(caption);
			END;
		END HandleSelection;

		(* Called by the ProgressPoller when the install operation  has been aborted or is finished *)
		PROCEDURE HandleProgressNotification(aborted : BOOLEAN);
		BEGIN
			IF (currentPage = PageShowLog) THEN
				backBtn.visible.Set(TRUE);
				nextBtn.caption.SetAOC("Done");
			END;
		END HandleProgressNotification;

		PROCEDURE LockPartition(selection : WMPartitionsComponents.Selection) : BOOLEAN;
		BEGIN
			IF IsValidSelection(selection) THEN
				lockedSelection := selection;
				RETURN PartitionsLib.diskModel.AcquirePartition(selection.disk, selection.partition, PartitionsLib.WriterLock);
			END;
			RETURN FALSE;
		END LockPartition;

		PROCEDURE UnlockPartition(selection : WMPartitionsComponents.Selection);
		BEGIN
			IF IsValidSelection(selection) THEN
				PartitionsLib.diskModel.ReleasePartition(selection.disk, selection.partition);
			END;
		END UnlockPartition;

		PROCEDURE OpenDevice(device : Disks.Device) : BOOLEAN;
		VAR res : LONGINT;
		BEGIN
			IF (device # NIL) THEN
				device.Open(res);
				IF (res = Disks.Ok) THEN
					opened := TRUE;
					RETURN TRUE;
				END;
			END;
			RETURN FALSE;
		END OpenDevice;

		PROCEDURE CloseDevice(device : Disks.Device);
		VAR ignore : LONGINT;
		BEGIN
			IF opened & (device # NIL) THEN
				device.Close(ignore);
			END;
		END CloseDevice;

		PROCEDURE GetConfiguration(selection : WMPartitionsComponents.Selection; packages : Installer.Packages; VAR configuration : Installer.Configuration) : BOOLEAN;
		VAR reader : Streams.Reader; res : LONGINT; msg : ARRAY 128 OF CHAR;
		BEGIN
			IF IsValidSelection(selection) THEN
				NEW(configuration, selection.disk, selection.partition);
				configuration.SetPackages(packages);
				reader := Codecs.OpenInputStream(DefaultConfigFile);
				IF (reader # NIL) THEN
					configuration.configTable.LoadFromStream(reader, msg, res);
					IF (res = PartitionsLib.Ok) THEN
						RETURN TRUE;
					END;
				ELSE msg := "Could not open configuration file";
				END;
			ELSE msg := "Select partition not valid";
			END;
			configuration := NIL;
			WMDialogs.Error(WindowTitle, msg);
			RETURN FALSE;
		END GetConfiguration;

		PROCEDURE CheckConfiguration(configuration : Installer.Configuration) : BOOLEAN;
		VAR errorWriter : Streams.StringWriter; errorString : ARRAY 2048 OF CHAR;
		BEGIN
			NEW(errorWriter, LEN(errorString));
			IF configuration.CheckConfiguration(errorWriter) THEN
				RETURN TRUE;
			ELSE
				configuration := NIL;
				errorWriter.Get(errorString);
				WMDialogs.Error(WindowTitle, errorString);
			END;
			RETURN FALSE;
		END CheckConfiguration;

		PROCEDURE GetSelection(VAR selection : WMPartitionsComponents.Selection) : BOOLEAN;
		BEGIN
			selection := partitionSelector.GetSelection();
			IF IsValidSelection(selection) THEN
				RETURN TRUE;
			ELSE
				WMDialogs.Error(WindowTitle, "Selected partition is not valid");
			END;
			RETURN FALSE;
		END GetSelection;

		PROCEDURE LoadPackages(CONST filename : ARRAY OF CHAR; VAR packages : Installer.Packages) : BOOLEAN;
		VAR errorWriter : Streams.StringWriter; errorString : ARRAY 2048 OF CHAR;
		BEGIN
			NEW(packages); NEW(errorWriter, LEN(errorString));
			IF packages.OpenPackages(filename, errorWriter) THEN
				packages.GetPackageSizes();
				RETURN TRUE;
			END;
			errorWriter.Get(errorString);
			WMDialogs.Error(WindowTitle, errorString);
			RETURN FALSE;
		END LoadPackages;

		PROCEDURE IsValidSelection(selection : WMPartitionsComponents.Selection) : BOOLEAN;
		BEGIN
			RETURN (selection.disk.device # NIL) & (selection.partition > 0);
		END IsValidSelection;

		PROCEDURE StartInstaller(selection : WMPartitionsComponents.Selection; configuration : Installer.Configuration);
		BEGIN
			UnlockPartition(lockedSelection); (* installer operation will lock it again *)
			NEW(installer, selection.disk, selection.partition, NIL);
			installer.SetParameters(configuration);
			installer.SetInstallLog(w);
			installer.SetStart;
			IF (progressPoller # NIL) THEN progressPoller.Close; END;
			NEW(progressPoller, installer, progressBar);
			progressPoller.SetNotifyProc(HandleProgressNotification);
		END StartInstaller;

		PROCEDURE StopInstaller;
		BEGIN
			IF (installer # NIL) THEN installer.Abort; installer := NIL; configuration := NIL; END;
		END StopInstaller;

		PROCEDURE QuickInstall() : BOOLEAN;
		VAR
			selection : WMPartitionsComponents.Selection; configuration : Installer.Configuration;
			packages : Installer.Packages;
			errorString : ARRAY 2048 OF CHAR; errorWriter : Streams.StringWriter;
		BEGIN
			IF (installer = NIL) THEN
				IF GetSelection(selection) THEN
					IF LoadPackages(DefaultPackageFile, packages) THEN
						IF GetConfiguration(selection, packages, configuration) THEN
							NEW(errorWriter, LEN(errorString));
							IF configuration.CheckConfiguration(errorWriter) THEN
								IF ReallyDoInstallation(selection) THEN
									StartInstaller(selection, configuration);
									RETURN TRUE;
								END;
							ELSE
								configuration := NIL;
								errorWriter.Get(errorString);
								WMDialogs.Error(WindowTitle, errorString);
							END;
						END;
					END;
				END;
			END;
			RETURN FALSE;
		END QuickInstall;

		PROCEDURE SelectPage(pageNr : LONGINT);
		BEGIN
			ASSERT((pageNr >= 0) & (pageNr < LEN(pages)));
			DisableUpdate;
			IF (currentPage >= 0) THEN main.RemoveContent(pages[currentPage]); END;
			main.AddContent(pages[pageNr]);
			currentPage := pageNr;
			CASE pageNr OF
				|PageSelectPartition:
					titleLabel.caption.SetAOC("Select Partition");
					quickInstallBtn.caption.SetAOC("QuickInstall"); quickInstallBtn.visible.Set(TRUE);
					nextBtn.caption.SetAOC("Next"); nextBtn.visible.Set(TRUE);
					backBtn.visible.Set(FALSE);
					LoadText(lowerText, TextSelectPartition);
				|PageSelectPackages:
					titleLabel.caption.SetAOC("Select Packages");
					quickInstallBtn.visible.Set(FALSE);
					nextBtn.caption.SetAOC("Next"); nextBtn.visible.Set(TRUE);
					backBtn.caption.SetAOC("Back"); backBtn.visible.Set(TRUE);
					LoadText(lowerText, TextSelectPackages);
				|PageShowSteps:
					titleLabel.caption.SetAOC("Installation Steps");
					quickInstallBtn.caption.SetAOC("Advanced"); quickInstallBtn.visible.Set(TRUE);
					nextBtn.caption.SetAOC("Next"); nextBtn.visible.Set(TRUE);
					backBtn.caption.SetAOC("Back"); backBtn.visible.Set(TRUE);
					LoadText(lowerText, TextInstallSteps);
				|PageShowLog:
					titleLabel.caption.SetAOC("Installation Log");
					quickInstallBtn.visible.Set(FALSE);
					nextBtn.caption.SetAOC("Abort"); nextBtn.visible.Set(TRUE);
					backBtn.caption.SetAOC("Back"); backBtn.visible.Set(FALSE);
					LoadText(lowerText, TextInstallLog);
				|PageAdvancedOptions:
					titleLabel.caption.SetAOC("Advanced Options");
					quickInstallBtn.visible.Set(FALSE);
					nextBtn.caption.SetAOC("Ok"); nextBtn.visible.Set(TRUE);
					backBtn.caption.SetAOC("Abort"); backBtn.visible.Set(TRUE);
					LoadText(lowerText, TextAdvancedOptions);
			ELSE
			END;
			main.Reset(SELF, NIL);
			main.AlignSubComponents;
			EnableUpdate;
			main.Invalidate;
		END SelectPage;

		PROCEDURE ClearText(text : Texts.Text);
		BEGIN
			text.AcquireWrite;
			text.Delete(0, text.GetLength());
			text.ReleaseWrite;
		END ClearText;

		PROCEDURE LoadText(text : Texts.Text; CONST filename : ARRAY OF CHAR);
		VAR newText : Texts.Text;
		BEGIN
			ClearText(text);
			LoadOberonText(filename, newText);
			IF (newText # NIL) THEN
				newText.AcquireRead;
				text.AcquireWrite;
				text.CopyFromText(newText, 0, newText.GetLength(), 0);
				text.ReleaseWrite;
				newText.ReleaseRead;
			END;
		END LoadText;

		PROCEDURE CreatePageSelectPackages() : WMComponents.VisualComponent;
		VAR panel : BorderPanel;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.bearing.Set(WMRectangles.MakeRect(20, 0, 20, 0));

			NEW(packageSelector); packageSelector.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(packageSelector);

			RETURN panel;
		END CreatePageSelectPackages;

		PROCEDURE CreatePageAdvancedOptions() : WMComponents.VisualComponent;
		VAR panel : BorderPanel;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.bearing.Set(WMRectangles.MakeRect(20, 0, 20, 0));

			NEW(configurationSettings); configurationSettings.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(configurationSettings);

			RETURN panel;
		END CreatePageAdvancedOptions;


		PROCEDURE CreatePageShowSteps() : WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel; textView : WMTextView.TextView;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.bearing.Set(WMRectangles.MakeRect(20, 0, 20, 0));

			NEW(textView); textView.alignment.Set(WMComponents.AlignClient);
			textView.isMultiLine.Set(TRUE); textView.showBorder.Set(TRUE);
			textView.defaultTextColor.Set(WMGraphics.Black);
			textView.alwaysShowCursor.Set(FALSE);
			NEW(stepsText); NEW(stepsW, stepsText);
			textView.SetText(stepsText);
			panel.AddContent(textView);

			RETURN panel;
		END CreatePageShowSteps;

		PROCEDURE CreatePageShowLog() : WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel; textView : WMTextView.TextView;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.bearing.Set(WMRectangles.MakeRect(20, 0, 20, 0));

			NEW(progressBar); progressBar.alignment.Set(WMComponents.AlignBottom);
			progressBar.bounds.SetHeight(20);
			progressBar.fillColor.Set(WMGraphics.White);
			progressBar.borderColor.Set(WMGraphics.Black);
			progressBar.color.Set(OberonColor);
			progressBar.textColor.Set(WMGraphics.Black);
			progressBar.showPercents.Set(TRUE);
			progressBar.SetRange(0, 100);
			progressBar.SetCurrent(0);
			panel.AddContent(progressBar);

			NEW(textView); textView.alignment.Set(WMComponents.AlignClient);
			textView.isMultiLine.Set(TRUE); textView.showBorder.Set(TRUE);
			textView.defaultTextColor.Set(WMGraphics.Black);
			textView.alwaysShowCursor.Set(FALSE);
			NEW(logText); NEW(w, logText);
			textView.SetText(logText);
			panel.AddContent(textView);

			RETURN panel;
		END CreatePageShowLog;

		PROCEDURE CreatePageSelectPartition() : WMComponents.VisualComponent;
		VAR panel : BorderPanel; toolbar : WMStandardComponents.Panel;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.bearing.Set(WMRectangles.MakeRect(20, 0, 20, 0));

			NEW(toolbar); toolbar.bounds.SetHeight(20);
			toolbar.alignment.Set(WMComponents.AlignBottom);
			panel.AddContent(toolbar);

			NEW(showDetailsBtn); showDetailsBtn.alignment.Set(WMComponents.AlignRight);
			showDetailsBtn.caption.SetAOC("Details");
			showDetailsBtn.onClick.Add(HandleButtons);
			showDetailsBtn.isToggle.Set(TRUE);
			showDetailsBtn.SetPressed(showDetails);
			toolbar.AddContent(showDetailsBtn);

			NEW(selectionLabel); selectionLabel.alignment.Set(WMComponents.AlignClient);
			selectionLabel.fillColor.Set(WMGraphics.White);
			selectionLabel.caption.SetAOC(" Selection : None");
			toolbar.AddContent(selectionLabel);
			NEW(partitionSelector); partitionSelector.alignment.Set(WMComponents.AlignClient);
			partitionSelector.fillColor.Set(WMGraphics.White);
			partitionSelector.clBackground.Set(LONGINT(0E0E0E0FFH) (* OberonColorLight *));
			partitionSelector.onSelection.Add(HandleSelection);
			panel.AddContent(partitionSelector);

			RETURN panel;
		END CreatePageSelectPartition;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel : InstallerBgPanel; upperpanel : WMStandardComponents.Panel;  textView : WMTextView.TextView;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient); panel.fillColor.Set(WMGraphics.White);

			NEW(upperpanel); upperpanel.alignment.Set(WMComponents.AlignTop);
			upperpanel.bearing.Set(WMRectangles.MakeRect(10, 10, 10, 0));
			upperpanel.bounds.SetHeight(UpperPanelHeight);
			upperpanel.fillColor.Set(WMGraphics.White);
			panel.AddContent(upperpanel);

			NEW(imagePanel); imagePanel.alignment.Set(WMComponents.AlignLeft);
			imagePanel.fillColor.Set(WMGraphics.White);
			imagePanel.bounds.SetWidth(ImageWidth);
			imagePanel.imgName.SetAOC(ImageLogo);
			upperpanel.AddContent(imagePanel);

			NEW(textView); textView.alignment.Set(WMComponents.AlignClient);
			textView.isMultiLine.Set(TRUE); textView.showBorder.Set(FALSE);
			textView.defaultTextBgColor.Set(WMGraphics.White);
			textView.alwaysShowCursor.Set(FALSE);
			textView.mouseWheelScrollSpeed.Set(0);
			textView.allowCommandExecution.Set(FALSE);
			textView.allowTextSelection.Set(FALSE);
			textView.allowPiemenu.Set(FALSE);
			textView.takesFocus.Set(FALSE);
			NEW(upperText);
			textView.SetText(upperText);
			upperpanel.AddContent(textView);

			 NEW(titleLabel); titleLabel.alignment.Set(WMComponents.AlignTop);
			 titleLabel.bounds.SetHeight(20);
			 titleLabel.bearing.Set(WMRectangles.MakeRect(20, 0, 20, 0));
			 panel.AddContent(titleLabel);

			NEW(buttonPanel); buttonPanel.alignment.Set(WMComponents.AlignBottom);
			buttonPanel.bearing.Set(WMRectangles.MakeRect(20, 0, 20, 20));
			buttonPanel.bounds.SetHeight(ButtonPanelHeight);
			panel.AddContent(buttonPanel);

			helpBtn := NewButton();
			helpBtn.alignment.Set(WMComponents.AlignLeft);
			helpBtn.caption.SetAOC("Help");
			buttonPanel.AddContent(helpBtn);

			quickInstallBtn := NewButton();
			quickInstallBtn.alignment.Set(WMComponents.AlignLeft);
			quickInstallBtn.bounds.SetWidth(80);
			quickInstallBtn.bearing.Set(WMRectangles.MakeRect(5, 0, 0, 0));
			quickInstallBtn.caption.SetAOC("QuickInstall");
			buttonPanel.AddContent(quickInstallBtn);

			nextBtn := NewButton(); buttonPanel.AddContent(nextBtn);
			backBtn := NewButton(); buttonPanel.AddContent(backBtn);
			backBtn.bearing.Set(WMRectangles.MakeRect(5, 0, 5, 0));

			NEW(textView); textView.alignment.Set(WMComponents.AlignBottom);
			textView.bearing.Set(WMRectangles.MakeRect(20, 20, 20, 10));
			textView.bounds.SetHeight(LowerPanelHeight);
			textView.isMultiLine.Set(TRUE); textView.showBorder.Set(TRUE);
			textView.alwaysShowCursor.Set(FALSE);
			textView.mouseWheelScrollSpeed.Set(0);
			textView.allowCommandExecution.Set(FALSE);
			textView.allowPiemenu.Set(FALSE);
			textView.takesFocus.Set(FALSE);

			NEW(lowerText);
			textView.SetText(lowerText);

			panel.AddContent(textView);

			RETURN panel;
		END CreateForm;

		PROCEDURE NewButton() : WMStandardComponents.Button;
		VAR button : WMStandardComponents.Button;
		BEGIN
			NEW(button); button.alignment.Set(WMComponents.AlignRight);
			button.onClick.Add(HandleButtons);
			RETURN button;
		END NewButton;

		PROCEDURE WheelMove(dz: LONGINT);
		BEGIN
			CASE currentPage OF
				|PageSelectPartition:
					partitionSelector.WheelMove(dz);
				|PageSelectPackages:
					packageSelector.scrollPanel.WheelMove(dz);
				|PageShowSteps:
				|PageAdvancedOptions:
					configurationSettings.scrollPanel.WheelMove(dz);
				|PageShowLog:
			ELSE
			END;
		END WheelMove;

		PROCEDURE Close;
		BEGIN
			Close^;
			WindowClosed;
			UnlockPartition(lockedSelection);
			IF (progressPoller # NIL) THEN progressPoller.Close; END;
			IF (installer # NIL) THEN installer.Abort; END;
		END Close;

		PROCEDURE &New*;
		BEGIN
			showDetails := FALSE;
			Init(WindowWidth, WindowHeight, FALSE);
			main := CreateForm();
			currentPage := -1;
			pages[PageSelectPartition] := CreatePageSelectPartition();
			pages[PageSelectPackages] := CreatePageSelectPackages();
			pages[PageShowSteps] := CreatePageShowSteps();
			pages[PageShowLog] := CreatePageShowLog();
			pages[PageAdvancedOptions] := CreatePageAdvancedOptions();

			LoadText(upperText, TitleText);

			SetContent(main);
			WMWindowManager.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString(WindowTitle));

			SelectPage(0);
		END New;

	END Window;

TYPE

	HelpWindow = OBJECT(WMComponents.FormWindow)

		PROCEDURE Close;
		BEGIN
			Close^;
			helpWindow := NIL;
		END Close;

		PROCEDURE &New*(text : Texts.Text);
		VAR editor : WMEditors.Editor;
		BEGIN
			Init(WindowWidth, WindowHeight, FALSE);

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.multiLine.Set(TRUE);
			editor.readOnly.Set(TRUE);
			editor.SetText(text);
			editor.fillColor.Set(WMGraphics.White);

			SetContent(editor);
			WMWindowManager.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("Oberon Installer Help"));
		END New;

	END HelpWindow;

TYPE

	(* Called when the installer operation has been aborted or is finished *)
	NotifyProc = PROCEDURE {DELEGATE} (aborted : BOOLEAN);

	(* Polls the progress of the installer operation *)
	PollProgress = OBJECT
	VAR
		progressBar : WMProgressComponents.ProgressBar;
		installer : Installer.Installer;
		notifyProc : NotifyProc;

		last : HUGEINT;
		timer : Kernel.Timer;
		alive, dead : BOOLEAN;

		PROCEDURE Update;
		VAR state : PartitionsLib.OperationState;
		BEGIN
			IF (last = 100) OR (state.status * (PartitionsLib.StatusFinished + PartitionsLib.StatusAborted) # {}) THEN alive := FALSE; END;
			state := installer.GetState();
			IF state.cur # last THEN
				progressBar.SetCurrent(SHORT(state.cur));
				last := state.cur;
			END;
			IF (alive = FALSE) & (notifyProc # NIL) THEN notifyProc(state.status * PartitionsLib.StatusAborted # {}); END;
		END Update;

		PROCEDURE SetNotifyProc(notifyProc : NotifyProc);
		BEGIN
			SELF.notifyProc := notifyProc;
		END SetNotifyProc;

		PROCEDURE &Init*(installer : Installer.Installer; progressBar : WMProgressComponents.ProgressBar);
		BEGIN
			ASSERT((installer # NIL) & (progressBar # NIL));
			SELF.installer := installer; SELF.progressBar := progressBar;
			alive := TRUE; dead := FALSE;
			last := -1;
			NEW(timer);
		END Init;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			alive := FALSE; timer.Wakeup;
			AWAIT(dead);
		END Close;

	BEGIN {ACTIVE}
		WHILE alive DO
			Update;
			timer.Sleep(200);
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END PollProgress;

VAR
	window : Window;
	helpWindow : HelpWindow;

	StrScrollPanel, StrPackageSelector, StrConfigurationSettings, StrInstallerBgPanel, StrBorderPanel : Strings.String;

PROCEDURE InitStrings;
BEGIN
	StrScrollPanel := Strings.NewString("ScrollPanel");
	StrPackageSelector := Strings.NewString("PackageSelector");
	StrConfigurationSettings := Strings.NewString("ConfigurationSettings");
	StrInstallerBgPanel := Strings.NewString("InstallerBgPanel");
	StrBorderPanel := Strings.NewString("BorderPanel");
END InitStrings;

PROCEDURE LoadOberonText(CONST filename : ARRAY OF CHAR; VAR text : Texts.Text);
VAR reader : Streams.Reader; decoder : Codecs.TextDecoder; res : LONGINT;
BEGIN
	text := NIL;
	reader := Codecs.OpenInputStream(filename);
	IF (reader # NIL) THEN
		decoder := Codecs.GetTextDecoder("Oberon");
		IF (decoder # NIL) THEN
			decoder.Open(reader, res);
			IF (res = Codecs.ResOk) THEN
				text := decoder.GetText();
			ELSE
				KernelLog.String("WMInstaller: Could not decode file "); KernelLog.String(filename);
				KernelLog.String(" (res: "); KernelLog.Int(res, 0); KernelLog.String(")"); KernelLog.Ln;
			END;
		ELSE KernelLog.String("WMInstaller: Could not get Oberon text decoder"); KernelLog.Ln;
		END;
	ELSE KernelLog.String("WMInstaller: Could not open file "); KernelLog.String(filename); KernelLog.Ln;
	END;
END LoadOberonText;

PROCEDURE Open*;
BEGIN {EXCLUSIVE}
	IF (window = NIL) THEN
		NEW(window);
	END;
END Open;

PROCEDURE WindowClosed;
BEGIN {EXCLUSIVE}
	window := NIL;
END WindowClosed;

PROCEDURE Cleanup;
BEGIN
	IF (window # NIL) THEN window.Close; END;
	IF (helpWindow # NIL) THEN helpWindow.Close; END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	InitStrings;
	window := NIL; helpWindow := NIL;
END WMInstaller.

WMInstaller.Open ~

SystemTools.Free WMInstaller ~

~
FSTools.DeleteFiles WMInstaller.tar ~
~

Tar.Create WMInstaller.tar
	OberonLogoSmall.png
	Title.Text
	Help.Text
	SelectPartition.Text
	SelectPackages.Text
	InstallSteps.Text
	InstallLog.Text
	AdvancedOptions.Text
	DefaultConfig.Text
~



Tar.Extract WMInstaller.tar ~

SystemTools.FreeDownTo PartitionsLib ~

PC.Compile \s
PartitionsLib.Mod
FATScavenger.Mod
Installer.Mod
Partitions.Mod
WMPartitionsComponents.Mod
WMPartitionsPlugins.Mod
WMPartitions.Mod
WMInstaller.Mod
~