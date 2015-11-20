MODULE WMPartitions; (** AUTHOR "staubesv"; PURPOSE "Partition Tool"; *)

IMPORT
	Streams, Modules, Commands, Strings, Disks, Files, Texts, TextUtilities, Codecs,
	PartitionsLib, DiskVolumes, OldDiskVolumes, FATVolumes, ISO9660Volumes, FATScavenger, DiskBenchmark, DiskTests, Installer,
	WMRectangles, WMGraphics, WMMessages, WMRestorable, WMWindowManager, WMProperties, WMDialogs,
	WMComponents, WMStandardComponents, WMTextView, WMEditors, WMGrids, WMTabComponents, WMPartitionsComponents;

CONST

	(* Return values of PopupWindow.Popup() *)
	ResNone = 0;
	ResOk = 1;
	ResCancel = 2;

	(* Parameter types for Parameter.type field *)
	ParInteger = 0;
	ParString = 1;
	ParBoolean = 2;

	(* Return values of Plugin.SelectionUpdated *)
	SelectionValid = 1; (** selected partition seems to be of the exspected type *)
	SelectionInvalid = 2; (** plugin will do nothing when user tries to apply it *)
	SelectionMaybe = 3; (** plugin can't determine whether its application will be successful *)
	SelectionNotSupported = 0; (** plugin doesn't care about this return value *)

	(* Default window size at startup *)
	DefaultWidth = 700; DefaultHeight = 400;

	(* If the window is smaller than this size, scale it *)
	WindowMinWidth = 350; WindowMinHeight = 350;

	NofTabs = 6;

	BackgroundColor = 0444444FFH;

	MarginH = 5 ;
	MarginV = 5 ;
	MarginColor = 0444444FFH;

	ButtonHeight = 20;
	ButtonWidth = 80;
	ButtonSpacer = 2;

	StatusBarHeight = 20;
	StatusBarBgColor = WMGraphics.Blue;

	(* Pending operation plugin constants *)
	RemoveSelected = 0;
	RemoveFinished = 1;
	RemoveAll = 2;

	(* Prefix for automatically generated mount prefixes. *)
	DefaultPrefix = "Auto";

	(* FAT file systems only: default size of cache in KB (as string) *)
	DefaultFatCacheSize = "2048";

	(* Config editor constants *)
	CeLabelHeight = 20;
	CeOpPanelHeight = ButtonHeight + 2*MarginV;
	CeKeyWidth = 100;
	CeEditPanelHeight = 3*ButtonHeight + 2*MarginV + 2*ButtonSpacer;
	CeCellHeightMinSpacer = 2;

	ToFile = 0;
	ToPartition = 1;

	UseSkinColors = FALSE;

TYPE

	Plugin = OBJECT(WMComponents.VisualComponent);
	VAR
		(** Usage: owner.UpdateStatusLabel(string : Strings.String) updates the main window status bar *)
		owner : Window;
		selection : WMPartitionsComponents.Selection;

		(** This procedure is called everytime when the selection has been updated *)
		(** Return values: SelectionValid, SelectionInvalid, SelectionMaybe or SelectionNotSupported *)
		PROCEDURE SelectionUpdated(selection : WMPartitionsComponents.Selection) : LONGINT; (* abstract *)
		END SelectionUpdated;

		(** Returns TRUE if the selection is valid *)
		PROCEDURE IsValid(selection : WMPartitionsComponents.Selection) : BOOLEAN;
		BEGIN
			RETURN (selection.disk.device # NIL) & (selection.partition >= 0) & (selection.disk.table # NIL) & (selection.partition < LEN(selection.disk.table));
		END IsValid;

	END Plugin;

TYPE

	(*
	 * The File System Tools (FSTools) is basically a graphical front-end for the operations provided by FSTools.Mod.
	 * It can be used to mount / unmount volumes and display a overview (free/total memory) of volumes. If the file system type
	 * of the selected partition is recognize, the plugin will automatically set the correct parameters for the mount command, including
	 * a generate mount prefix.
	 *)
	FSToolsPlugin = OBJECT(Plugin);
	VAR
		(* mount command *)
		mount : WMStandardComponents.Button;
		prefixEditor, fsEditor : WMEditors.Editor;
		mountPanel : WMStandardComponents.Panel;

		(* FatFS specific settings - will only be visible if selected partition contains FAT volume*)
		forceRWlabel, enableWBlabel, cacheSizeLabel : WMStandardComponents.Label;
		forceRW, enableWB : WMStandardComponents.Button;
		cacheSizeEditor : WMEditors.Editor;
		parForceRW, parEnableWB : BOOLEAN;

		(* unmount command *)
		unmount, force : WMStandardComponents.Button;
		parForce : BOOLEAN;

		(* disk info panel *)
		info : WMStandardComponents.Label;

		prefixUsed : ARRAY 128 OF BOOLEAN; (* used by GenPrefix() *)

		PROCEDURE &Init*;
		VAR label : WMStandardComponents.Label; spacer : WMStandardComponents.Panel;
		BEGIN
			Init^;

			NEW(mount);
			mount.bounds.SetExtents(ButtonWidth, ButtonHeight); mount.bounds.SetLeft(0); mount.bounds.SetTop(0);
			mount.onClick.Add(Mount); mount.SetCaption("Mount");
			AddInternalComponent(mount);

			NEW(mountPanel);
			mountPanel.bounds.SetLeft(ButtonWidth + ButtonHeight + 2*ButtonSpacer +40); mountPanel.bounds.SetTop(0);
			AddInternalComponent(mountPanel);

			NEW(label);
			label.bounds.SetWidth(32); label.bounds.SetHeight(ButtonHeight); label.alignment.Set(WMComponents.AlignLeft);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString("Prefix"));
			mountPanel.AddInternalComponent(label);

			NEW(prefixEditor);
			prefixEditor.bounds.SetWidth(40); prefixEditor.bounds.SetHeight(ButtonHeight); prefixEditor.alignment.Set(WMComponents.AlignLeft);
			prefixEditor.multiLine.Set(FALSE);
			prefixEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			IF ~UseSkinColors THEN prefixEditor.fillColor.Set(WMGraphics.White); END;
			prefixEditor.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1)); prefixEditor.tv.showBorder.Set(TRUE);
			mountPanel.AddInternalComponent(prefixEditor);

			NEW(label);
			label.bounds.SetWidth(64); label.bounds.SetHeight(ButtonHeight); label.alignment.Set(WMComponents.AlignLeft);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString(" FileSystem"));
			mountPanel.AddInternalComponent(label);

			NEW(fsEditor);
			fsEditor.bounds.SetWidth(60); fsEditor.bounds.SetHeight(20); fsEditor.alignment.Set(WMComponents.AlignLeft);
			fsEditor.multiLine.Set(FALSE);
			fsEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			IF ~UseSkinColors THEN fsEditor.fillColor.Set(WMGraphics.White); END;
			fsEditor.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1)); fsEditor.tv.showBorder.Set(TRUE);
			mountPanel.AddInternalComponent(fsEditor);

			NEW(spacer); spacer.bounds.SetWidth(2*ButtonSpacer); spacer.alignment.Set(WMComponents.AlignLeft);
			mountPanel.AddInternalComponent(spacer);

			NEW(cacheSizeLabel);
			cacheSizeLabel.bounds.SetWidth(83); cacheSizeLabel.bounds.SetHeight(ButtonHeight); cacheSizeLabel.alignment.Set(WMComponents.AlignLeft);
			IF ~UseSkinColors THEN cacheSizeLabel.fillColor.Set(BackgroundColor); cacheSizeLabel.textColor.Set(WMGraphics.White); END;
			cacheSizeLabel.caption.Set(Strings.NewString("CacheSize (KB)")); cacheSizeLabel.visible.Set(FALSE);
			mountPanel.AddInternalComponent(cacheSizeLabel);

			NEW(cacheSizeEditor);
			cacheSizeEditor.bounds.SetWidth(40); cacheSizeEditor.bounds.SetHeight(ButtonHeight); cacheSizeEditor.alignment.Set(WMComponents.AlignLeft);
			cacheSizeEditor.multiLine.Set(FALSE);
			cacheSizeEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			IF ~UseSkinColors THEN cacheSizeEditor.fillColor.Set(WMGraphics.White); END;
			cacheSizeEditor.SetAsString(DefaultFatCacheSize);
			cacheSizeEditor.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1)); cacheSizeEditor.tv.showBorder.Set(TRUE); cacheSizeEditor.visible.Set(FALSE);
			mountPanel.AddInternalComponent(cacheSizeEditor);

			NEW(spacer); spacer.bounds.SetWidth(2*ButtonSpacer); spacer.alignment.Set(WMComponents.AlignLeft);
			mountPanel.AddInternalComponent(spacer);

			NEW(enableWB);
			enableWB.bounds.SetExtents(ButtonHeight, ButtonHeight); enableWB.alignment.Set(WMComponents.AlignLeft);
			enableWB.bounds.SetLeft(ButtonWidth + ButtonSpacer); enableWB.bounds.SetTop(ButtonHeight + ButtonSpacer);
			enableWB.onClick.Add(EnableWB); enableWB.SetCaption(""); enableWB.visible.Set(FALSE);
			mountPanel.AddInternalComponent(enableWB);

			NEW(enableWBlabel);
			enableWBlabel.bounds.SetWidth(70); enableWBlabel.bounds.SetHeight(ButtonHeight); enableWBlabel.alignment.Set(WMComponents.AlignLeft);
			IF ~UseSkinColors THEN enableWBlabel.fillColor.Set(BackgroundColor); enableWBlabel.textColor.Set(WMGraphics.White); END;
			enableWBlabel.caption.SetAOC(" Writeback"); enableWBlabel.visible.Set(FALSE);
			mountPanel.AddInternalComponent(enableWBlabel);

			NEW(forceRW);
			forceRW.bounds.SetExtents(ButtonHeight, ButtonHeight); forceRW.alignment.Set(WMComponents.AlignLeft);
			forceRW.bounds.SetLeft(ButtonWidth + ButtonSpacer); forceRW.bounds.SetTop(ButtonHeight + ButtonSpacer);
			forceRW.onClick.Add(ForceRW); forceRW.SetCaption(""); forceRW.visible.Set(FALSE);
			mountPanel.AddInternalComponent(forceRW);

			NEW(forceRWlabel);
			forceRWlabel.bounds.SetWidth(160); forceRWlabel.bounds.SetHeight(ButtonHeight); forceRWlabel.alignment.Set(WMComponents.AlignLeft);
			IF ~UseSkinColors THEN forceRWlabel.fillColor.Set(BackgroundColor); forceRWlabel.textColor.Set(WMGraphics.White); END;
			forceRWlabel.caption.Set(Strings.NewString(" Force R/W"));
			forceRWlabel.visible.Set(FALSE);
			mountPanel.AddInternalComponent(forceRWlabel);

			NEW(unmount);
			unmount.bounds.SetExtents(ButtonWidth, ButtonHeight);
			unmount.bounds.SetLeft(0); unmount.bounds.SetTop(ButtonHeight + ButtonSpacer);
			unmount.onClick.Add(Unmount);	unmount.SetCaption("Unmount");
			AddInternalComponent(unmount);

			NEW(force);
			force.bounds.SetExtents(ButtonHeight, ButtonHeight);
			force.bounds.SetLeft(ButtonWidth + ButtonSpacer); force.bounds.SetTop(ButtonHeight + ButtonSpacer);
			force.onClick.Add(Force); force.SetCaption("");
			AddInternalComponent(force);

			NEW(label);
			label.bounds.SetExtents(40, ButtonHeight);
			label.bounds.SetLeft(ButtonWidth + ButtonHeight + 2*ButtonSpacer); label.bounds.SetTop(ButtonHeight + ButtonSpacer);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString("Force"));
			AddInternalComponent(label);

			NEW(info);
			info.bounds.SetLeft(ButtonWidth + ButtonHeight + 2*ButtonSpacer + 40); info.bounds.SetTop(ButtonHeight + ButtonSpacer);
			IF ~UseSkinColors THEN info.fillColor.Set(BackgroundColor); info.textColor.Set(WMGraphics.White); END;
			info.caption.Set(Strings.NewString("File System Info: n/a"));
			AddInternalComponent(info);
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			Initialize^;
			mountPanel.bounds.SetExtents(bounds.GetWidth(), ButtonHeight);
			info.bounds.SetExtents(bounds.GetWidth(), ButtonHeight);
		END Initialize;

		PROCEDURE Resized*;
		BEGIN
			Resized^;
			mountPanel.bounds.SetExtents(bounds.GetWidth(), ButtonHeight);
			info.bounds.SetExtents(bounds.GetWidth(), ButtonHeight);
		END Resized;

		PROCEDURE SelectionUpdated(selection:  WMPartitionsComponents.Selection): LONGINT;
		VAR
			caption, temp : ARRAY 128 OF CHAR;
			fs : Files.FileSystem;
			fstype : LONGINT;
			doClose : BOOLEAN;
			result, res : LONGINT;
		BEGIN
			SELF.selection := selection;
			IF IsValid(selection) THEN

				fstype := 0; (* invalid *)

				IF (selection.disk.isDiskette) & (selection.disk.res = Disks.Ok) THEN
					(* special case: floppy disk *)
					doClose := FALSE;
					IF (selection.disk.device.openCount < 1) THEN
						doClose := TRUE;
						selection.disk.device.Open(res); (* ignore res *)
					END;
					IF PartitionsLib.DisketteInserted(selection.disk.device) THEN
						fstype := PartitionsLib.DetectFS(selection.disk.device, selection.partition);
					END;
				ELSE
					fstype := DetectFS(selection.disk.device, selection.partition);
				END;

				temp := "";
				CASE fstype OF
					|PartitionsLib.UnknownFS:  result := SelectionInvalid;
					|PartitionsLib.NativeFS: temp := "NatFS"; result := SelectionValid;
					|PartitionsLib.OldAosFS32: temp := "OldAosFS"; result := SelectionValid;
					|PartitionsLib.AosFS32: temp := "OldAosFS"; result := SelectionValid;
					|PartitionsLib.FatFS: temp := "FatFS"; result := SelectionValid;
					|PartitionsLib.AosFS128: temp := "AosFS"; result := SelectionValid;
				END;

				IF (selection.disk.isDiskette) & doClose & (selection.disk.device.openCount > 0) THEN
					selection.disk.device.Close(res); (* ignore res *)
				END;

				(* If device is not partitioned, assume CDROM or floppy drive *)
				IF ((result = SelectionInvalid) & (LEN(selection.disk.table) = 1)) THEN
					result := SelectionMaybe;
					temp := "IsoFS";
				END;

				IF fstype = PartitionsLib.FatFS THEN (* FatFS specific settings *)
					parForceRW := FALSE; forceRW.caption.SetAOC("");
					IF Strings.Match("USB*", selection.disk.device.name) THEN (* enable wb caching for USB devices *)
						parEnableWB := TRUE; enableWB.caption.SetAOC("X");
					ELSE
						parEnableWB := FALSE; enableWB.caption.SetAOC("");
					END;
					forceRWlabel.visible.Set(TRUE); forceRW.visible.Set(TRUE);
					cacheSizeEditor.visible.Set(TRUE); cacheSizeLabel.visible.Set(TRUE);
					enableWB.visible.Set(TRUE); enableWBlabel.visible.Set(TRUE);
				ELSE
					forceRWlabel.visible.Set(FALSE); forceRW.visible.Set(FALSE);
					cacheSizeEditor.visible.Set(FALSE); cacheSizeLabel.visible.Set(FALSE);
					enableWB.visible.Set(FALSE); enableWBlabel.visible.Set(FALSE);
				END;

				fsEditor.SetAsString(temp); (* file system *)
				prefixEditor.SetAsString(GenPrefix());
				IF (selection.disk.fs # NIL) & (selection.partition <LEN(selection.disk.fs)) & (selection.disk.fs[selection.partition] # NIL) THEN (* we have a reference to the FS *)
					fs := selection.disk.fs[selection.partition];
					caption := "File System Info:  "; Strings.Append(caption, fs.prefix); Strings.Append(caption, ": ");
					Strings.Append(caption, fs.desc); Strings.Append(caption, " on ");
					Strings.Append(caption, selection.disk.device.name);
					Strings.Append(caption, "#"); Strings.IntToStr(selection.partition, temp); Strings.Append(caption, temp);
					IF fs.vol # NIL THEN
						IF Files.ReadOnly IN fs.vol.flags THEN Strings.Append(caption, " (read-only)") END;
						IF Files.Removable IN fs.vol.flags THEN Strings.Append(caption, " (removable)") END;
						IF Files.Boot IN fs.vol.flags THEN Strings.Append(caption, " (boot)") END;
						Strings.Append(caption, ", ");
						WriteK(ENTIER(fs.vol.Available()/1024.0D0 * fs.vol.blockSize), caption);  Strings.Append(caption, " of ");
						WriteK(ENTIER(fs.vol.size/1024.0D0 * fs.vol.blockSize), caption);  Strings.Append(caption, " free");
					END;
					info.caption.Set(Strings.NewString(caption));
				ELSE
					info.caption.Set(Strings.NewString(" File System Info: n/a"));
				END;
			ELSE
				result := SelectionInvalid;
			END;
			RETURN result;
		END SelectionUpdated;

		(* TBD *)
		PROCEDURE WriteK(k: LONGINT; VAR string : ARRAY OF CHAR);
		VAR suffix: ARRAY 3 OF CHAR; temp : ARRAY 32 OF CHAR;
		BEGIN
			IF k < 10*1024 THEN COPY("Ki", suffix)
			ELSIF k < 10*1024*1024 THEN COPY("Mi", suffix); k := k DIV 1024
			ELSE COPY("Gi", suffix); k := k DIV (1024*1024)
			END;
			Strings.IntToStr(k , temp); Strings.Append(string, temp); Strings.Append(string, suffix); Strings.Append(string, "B");
		END WriteK;

		(* Generate a mount prefix by appending a number to the string represented by the constant DefaultPrefix. *)
		PROCEDURE GenPrefix() : Files.Prefix;
		VAR prefix : Files.Prefix; temp : ARRAY 12 OF CHAR; i : LONGINT;
		BEGIN {EXCLUSIVE}
			WHILE prefixUsed[i] & (i < LEN(prefixUsed)-1) DO INC(i); END;
			ASSERT(i < LEN(prefixUsed));
			prefix := ""; Strings.Append(prefix, DefaultPrefix); Strings.IntToStr(i, temp); Strings.Append(prefix, temp);
			RETURN prefix;
		END GenPrefix;

		PROCEDURE SetPrefixUsed(CONST prefix : ARRAY OF CHAR);
		VAR nbr : LONGINT;
		BEGIN (* will not be concurrently called with GenPrefix *)
			nbr := GetPrefixNbr(prefix);
			IF nbr#-1 THEN prefixUsed[nbr] := TRUE; END;
		END SetPrefixUsed;

		PROCEDURE GetPrefixNbr(CONST iprefix : ARRAY OF CHAR) : LONGINT;
		VAR
			match : BOOLEAN;
			temp : ARRAY 32 OF CHAR;
			default, prefix : Strings.String;
			i, j, result : LONGINT;
		BEGIN
			prefix := Strings.NewString(iprefix);
			default := Strings.NewString(DefaultPrefix);
			result := -1; (* invalid *)
			IF LEN(prefix) > LEN(default) THEN
				match := TRUE;
				FOR i := 0 TO LEN(default)-2 (* ignore 0X *) DO
					IF prefix[i]#default[i] THEN match := FALSE; END;
				END;
				IF match THEN
					temp := ""; j := 0; i := LEN(default)-1;
					WHILE i < LEN(prefix) DO temp[j] := prefix[i]; INC(j); INC(i); END;
					Strings.StrToInt(temp, result);
					IF (result < 0) OR (result >= LEN(prefixUsed)) THEN result := -1; END;
				END;
			END;
			RETURN result;
		END GetPrefixNbr;

		(* Appends FatFS specific parameters to command string *)
		PROCEDURE GetFATspecific(VAR volPar : ARRAY OF CHAR);
		VAR string : ARRAY 128 OF CHAR; cachesize : LONGINT;
		BEGIN
			volPar := "";
			IF parForceRW THEN Strings.Append(volPar, " ,X"); END;
			cacheSizeEditor.GetAsString(string); Strings.StrToInt(string, cachesize);
			IF (cachesize > 0) THEN
				cachesize := (1024 * cachesize) DIV PartitionsLib.BS; (* cachesize in 512B blocks *)
				IF parEnableWB THEN cachesize := -cachesize; END;
				Strings.IntToStr(cachesize, string);
				Strings.Append(volPar, ",C:"); Strings.Append(volPar, string);
			END;
		END GetFATspecific;

		(** prefix [hashSize] [cachesize] alias [volpar] ["|" fspar] ~ *)
		PROCEDURE Mount(sender, data : ANY);
		VAR
			mount : PartitionsLib.Mount;
			prefix, alias, volPar, fsPar : ARRAY 128 OF CHAR;
		BEGIN
			IF IsValid(selection) THEN
				IF selection.disk.table[selection.partition].flags  * {Disks.Mounted} = {} THEN
					(** cmd: prefix [hashSize] [cachesize] alias [volpar] ["|" fspar] ~ *)
					prefixEditor.GetAsString(prefix);
					IF (prefix # "") THEN
						fsEditor.GetAsString(alias);
						IF (alias # "") THEN
							GetFATspecific(volPar); fsPar := "";
							SetPrefixUsed(prefix);
							NEW(mount, selection.disk, selection.partition, NIL);
							mount.SetParameters(prefix, alias, volPar, fsPar);
							mount.SetStart;
						ELSE owner.UpdateStatusLabel(Strings.NewString("No file system alies specified"));
						END;
					ELSE owner.UpdateStatusLabel(Strings.NewString("No prefix specified"));
					END;
				ELSE owner.UpdateStatusLabel(Strings.NewString("Volume is already mounted"));
				END;
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection not valid"));
			END;
		END Mount;

		(* Force parameter of the unmount command *)
		PROCEDURE Force(sender, data : ANY);
		BEGIN
			IF parForce THEN parForce := FALSE; force.caption.Set(Strings.NewString(""));
			ELSE parForce := TRUE; force.caption.Set(Strings.NewString("X"));
			END;
		END Force;

		(* FatFS only: Force R/W mountng *)
		PROCEDURE ForceRW(sender, data : ANY);
		BEGIN
			IF parForceRW THEN parForceRW := FALSE; forceRW.caption.Set(Strings.NewString(""));
			ELSE parForceRW := TRUE; forceRW.caption.Set(Strings.NewString("X"));
			END;
		END ForceRW;

		(* FatFS only: Enable/disable write back caching *)
		PROCEDURE EnableWB(sender, data : ANY);
		BEGIN
			IF parEnableWB THEN parEnableWB := FALSE; enableWB.caption.SetAOC("");
			ELSE parEnableWB := TRUE; enableWB.caption.SetAOC("X");
			END;
		END EnableWB;

		(* parameters : dev#part [/f] *)
		PROCEDURE Unmount(sender, data : ANY);
		VAR
			dev : Disks.Device;
			fs: Files.FileSystem; ft: Files.FileSystemTable;
			vol : DiskVolumes.Volume;
			volOld : OldDiskVolumes.Volume;
			volFAT: FATVolumes.Volume;
			volISO : ISO9660Volumes.Volume;
			fsStart : LONGINT;
			found : BOOLEAN;
			result  : Strings.String;
			i : LONGINT;
		BEGIN
			NEW(result, 128);
			IF IsValid(selection) & (selection.disk.device.table # NIL) & (selection.partition < LEN(selection.disk.device.table)) THEN
				(* for unpartitioned devices we also try to unmount when Disks.Mounted is not set *)
				IF (LEN(selection.disk.table) = 1) OR (selection.disk.device.table[selection.partition].flags * {Disks.Mounted} # {}) THEN
					Files.GetList(ft);
					IF ft # NIL THEN
						i := 0; found := FALSE;
						LOOP
							fs := ft[i];
							IF fs.vol # NIL THEN
								IF fs.vol IS DiskVolumes.Volume THEN
									vol := fs.vol (DiskVolumes.Volume);
									dev := vol.dev; fsStart := vol.startfs;
								ELSIF fs.vol IS OldDiskVolumes.Volume THEN
									volOld := fs.vol (OldDiskVolumes.Volume);
									dev := volOld.dev; fsStart := volOld.startfs;
								ELSIF fs.vol IS FATVolumes.Volume THEN
									volFAT := fs.vol (FATVolumes.Volume);
									dev := volFAT.dev; fsStart := volFAT.start;
								ELSIF fs.vol IS ISO9660Volumes.Volume THEN
									volISO := fs.vol (ISO9660Volumes.Volume);
									dev := volISO.dev; fsStart := 512; (* dummy value *)
								ELSE
									dev := NIL;
								END;
								IF (dev#NIL) & (dev = selection.disk.device) &
							           ((selection.disk.isDiskette) OR
								    (fsStart >= dev.table[selection.partition].start) &
								    (fsStart < dev.table[selection.partition].start + dev.table[selection.partition].size))
								 THEN
									found := TRUE;
									IF (fs.vol = NIL) OR parForce OR ~(Files.Boot IN fs.vol.flags) THEN
										Files.Remove(fs);
										EXCL(selection.disk.table[selection.partition].flags, Disks.Mounted);
										selection.disk.fs[selection.partition] := NIL;
										Strings.Append(result^, fs.prefix); Strings.Append(result^, " unmounted");
										PartitionsLib.diskModel.UpdateDisk(selection.disk);
										owner.UpdateContent;
									ELSE
										Strings.Append(result^, " can't unmount boot volume. Use \f parameter to force unmounting.");
									END;
									EXIT;
								END;
							END;
						INC(i);
						IF found OR (i > LEN(ft)-1) THEN EXIT; END;
						END;
						IF ~found THEN Strings.Append(result^, "Failed: Volume not found"); END;
					ELSE Strings.Append(result^, "Failed: Volume not found");
					END;
				ELSE Strings.Append(result^, "Failed: Volume is not mounted");
				END;
			ELSE Strings.Append(result^, "Failed: Selection Invalid");
			END;
			owner.UpdateStatusLabel(result);
		END Unmount;

		(* Check if an Oberon or FAT  file system is present on a partition. Returns 0 if no Oberon or FAT file system found,
		1 for a Native file system, 2 for an old Aos file system and 3 for a new Aos file system, 4 for FAT file system (from Partitions.Mod) *)
		PROCEDURE DetectFS(dev: Disks.Device; part: LONGINT): LONGINT;
		VAR
			block: POINTER TO ARRAY  OF CHAR;
			type : LONGINT;
			res, fs: LONGINT;
		BEGIN
			IF (dev.table=NIL) OR (part >= LEN(dev.table)) THEN RETURN 0; END;
			type := dev.table[part].type;
			fs := PartitionsLib.UnknownFS;
			IF (type = 01H ) OR (type = 04H) OR (type = 06H) OR (type = 0BH) OR (type = 0CH) OR (type = 0EH) THEN (* FAT Filesystems *)
				NEW(block, dev.blockSize);
				dev.Transfer(Disks.Read, dev.table[part].start, 1, block^, 0, res);
				IF (res = Disks.Ok) & (block[510]=055X) & (block[511]=0AAX) THEN
					fs := PartitionsLib.FatFS;
				END;
			ELSIF (type = 4CH) OR (type =  04FH) OR (type = 050H) THEN (* Aos/NativeOveron *)
				IF dev.blockSize = PartitionsLib.BS THEN
					fs := PartitionsLib.DetectFS(dev, part);
				END;
			END;
			RETURN fs
		END DetectFS;

	END FSToolsPlugin;

TYPE

	ConfigEditor = OBJECT(WMComponents.FormWindow);
	VAR
		config : PartitionsLib.Configuration;
		configTable : PartitionsLib.ConfigTable;
		popup : PopupWindow;

		mainpanel  : WMStandardComponents.Panel;
		titlelabel : WMStandardComponents.Label;

		(* config grid *)
		grid : WMPartitionsComponents.NoWheelGrid;
		gridContainer : WMStandardComponents.Panel;
		gridPanel : WMPartitionsComponents.BevelPanel;
		selectedRow : LONGINT;
		cellHeight : LONGINT;
		scrollbarY : WMStandardComponents.Scrollbar;

		(* edit panel *)
		editPanel : WMPartitionsComponents.BevelPanel;
		editorKey, editorValue : WMEditors.Editor;
		add, delete, replace, clear, moveup, movedown : WMStandardComponents.Button;

		(* operation panel *)
		opPanel : WMPartitionsComponents.BevelPanel;
		set, get : WMStandardComponents.Button;
		toFile, toPartition : WMStandardComponents.Button; (* check boxes *)
		editorFile, editorPartition : WMEditors.Editor;
		target : LONGINT; (* ToFile | ToPartition *)
		fileLeft : LONGINT; (* left offset from editorFile *)

		statusLabel : WMStandardComponents.Label;

		hex : ARRAY 32 OF CHAR;

		PROCEDURE LoadFromPartition(CONST devpart : ARRAY OF CHAR) : BOOLEAN;
		VAR
			getConfig : PartitionsLib.GetConfig;
			selection : PartitionsLib.Selection;
			caption : ARRAY 128 OF CHAR;
			fs : LONGINT;
		BEGIN
			IF PartitionsLib.diskModel.GetDisk(devpart, selection, FALSE) THEN
				fs := PartitionsLib.DetectFS(selection.disk.device, selection.partition);
				IF (fs = PartitionsLib.AosFS32) OR (fs = PartitionsLib.AosFS128) THEN (* new AosFS *)
					NEW(getConfig, selection.disk, selection.partition, NIL);
					getConfig.SetBlockingStart;
					IF getConfig.state.status * PartitionsLib.StatusError = {} THEN
						config.table := getConfig.GetTable();
						configTable.ParseRawTable(config);
						caption := " Configuration string loaded from partition "; Strings.Append(caption, getConfig.diskpartString);
						statusLabel.caption.Set(Strings.NewString(caption));
						caption := ""; Strings.Append(caption, getConfig.diskpartString);
						Strings.Append(caption, "("); Strings.Append(caption, selection.disk.device.desc); Strings.Append(caption, ")");
						titlelabel.caption.Set(Strings.NewString(caption));
						RETURN TRUE;
					ELSE
						caption := " Error: Could not load configuration from partition ";
						Strings.Append(caption, getConfig.diskpartString);
						statusLabel.caption.Set(Strings.NewString(caption));
					END;
				ELSE
					caption := " Error: Could not load configuration from partition (Filesystem is not AosFS) ";
					statusLabel.caption.Set(Strings.NewString(caption));
				END;
			ELSE
				caption := " Error: Could not load configuration from partition (Could not get disk)";
				statusLabel.caption.Set(Strings.NewString(caption));
			END;
			RETURN FALSE;
		END LoadFromPartition;

		PROCEDURE StoreToPartition(CONST devpart : ARRAY OF CHAR);
		VAR
			setConfig : PartitionsLib.SetConfig;
			selection : PartitionsLib.Selection;
			caption : ARRAY 128 OF CHAR;
			params : Parameters;
			string : Strings.String;
			res : LONGINT;
		BEGIN
			IF PartitionsLib.diskModel.GetDisk(devpart, selection, FALSE) THEN
				string := configTable.GetAsString();
				IF string # NIL THEN
					NEW(popup, 200, 100, FALSE); params := NIL;
					popup.SetTextAsString("Are you sure?");
					popup.SetParameters("Write config to ", selection, params);
					popup.Popup(100, 100, res);
					IF res = ResOk THEN
						NEW(setConfig, selection.disk, selection.partition, NIL);
						setConfig.SetParameters(string, 0);
						setConfig.SetBlockingStart;
						IF setConfig.state.status * PartitionsLib.StatusError = {} THEN
							caption := "Configuration loaded from "; Strings.Append(caption, setConfig.diskpartString);
							statusLabel.caption.Set(Strings.NewString(caption));
						ELSE
							statusLabel.caption.Set(setConfig.GetResult());
						END;
					END;
					popup := NIL;
				ELSE statusLabel.caption.Set(Strings.NewString("Could not get config string"));
				END;
			ELSE
				caption := " Error: Could not load configuration from partition (Could not get disk) ";
				statusLabel.caption.Set(Strings.NewString(caption));
			END;
		END StoreToPartition;

		PROCEDURE LoadFromFile(CONST filename : ARRAY OF CHAR);
		VAR caption, msg : ARRAY 256 OF CHAR; res : LONGINT;
		BEGIN
			configTable.LoadFromFile(filename, msg, res);
			IF (res = PartitionsLib.Ok) THEN
				caption := " Configuration string loaded from "; Strings.Append(caption, filename);
				statusLabel.caption.Set(Strings.NewString(caption));
				titlelabel.caption.Set(Strings.NewString(filename));
			ELSE
				statusLabel.caption.SetAOC(msg);
			END;
			UpdateGrid;
		END LoadFromFile;

		PROCEDURE StoreToFile(CONST filename : ARRAY OF CHAR);
		VAR caption, msg : ARRAY 256 OF CHAR; res : LONGINT;
		BEGIN
			configTable.StoreToFile(filename, msg, res);
			IF (res = PartitionsLib.Ok) THEN
				caption := " Configuration string stored to "; Strings.Append(caption, filename);
				statusLabel.caption.Set(Strings.NewString(caption));
			ELSE
				statusLabel.caption.SetAOC(msg);
			END;
		END StoreToFile;

		PROCEDURE SetSelection(selection : WMPartitionsComponents.Selection) : BOOLEAN;
		VAR string, diskpartStr : ARRAY 128 OF CHAR; temp : ARRAY 4 OF CHAR; res : LONGINT;
		BEGIN
			diskpartStr := "";
			Strings.Append(diskpartStr, selection.disk.device.name);
			Strings.Append(diskpartStr, "#"); Strings.IntToStr(selection.partition, temp); Strings.Append(diskpartStr, temp);
			editorPartition.SetAsString(diskpartStr);
			string := " ";
			Strings.Append(string, diskpartStr);
			Strings.Append(string, " ("); Strings.Append(string, selection.disk.device.desc); Strings.Append(string, ")");
			titlelabel.caption.Set(Strings.NewString(string));
			config.GetTable(selection.disk.device, selection.partition, res);
			configTable.ParseRawTable(config);
			UpdateGrid;
			RETURN res = Disks.Ok;
		END SetSelection;

		PROCEDURE WheelMove(dz : LONGINT);
		CONST	Multiplier = 30;
		VAR pos : LONGINT;
		BEGIN
			IF scrollbarY.visible.Get() THEN
				pos := scrollbarY.pos.Get() + Multiplier*dz;
				IF pos < scrollbarY.min.Get() THEN pos := scrollbarY.min.Get(); END;
				IF pos > scrollbarY.max.Get() THEN pos := scrollbarY.max.Get(); END;
				scrollbarY.pos.Set(pos);
			END;
		END WheelMove;

		PROCEDURE ButtonHandler(sender, data : ANY);
		VAR
			button : WMStandardComponents.Button;
			entry : PartitionsLib.ConfigEntry;
			key, value, string : ARRAY 1024 OF CHAR;
		BEGIN
			button := sender (WMStandardComponents.Button);
			IF button = add THEN
				editorKey.GetAsString(string); entry.key := Strings.NewString(string);
				editorValue.GetAsString(string); entry.value := Strings.NewString(string);
				configTable.AddEntry(selectedRow, entry);
				UpdateGrid;
			ELSIF button = delete THEN
				configTable.RemoveEntry(selectedRow);
				UpdateGrid;
			ELSIF button = replace THEN
				editorKey.GetAsString(key);
				editorValue.GetAsString(value);
				configTable.ChangeEntry(selectedRow, Strings.NewString(key), Strings.NewString(value));
				UpdateGrid;
			ELSIF button = clear THEN
				editorKey.SetAsString("");
				editorValue.SetAsString("");
			ELSIF button = moveup THEN
				configTable.SwapEntries(selectedRow, selectedRow -1);
				IF selectedRow > 0 THEN
					grid.Acquire; grid.SetSelection(0, selectedRow - 1, 0, selectedRow-1);grid.Release;
					selectedRow := selectedRow - 1;
				END;
				UpdateGrid;
			ELSIF button = movedown THEN
				configTable.SwapEntries(selectedRow, selectedRow + 1);
				IF selectedRow < configTable.GetNofEntries()-1 THEN
					grid.Acquire; grid.SetSelection(0, selectedRow + 1, 0, selectedRow +1); grid.Release;
					selectedRow := selectedRow + 1;
				END;
				UpdateGrid;
			ELSIF button = get THEN
				IF target = ToFile THEN
					editorFile.GetAsString(string);
					LoadFromFile(string);
				ELSIF target = ToPartition THEN
					editorPartition.GetAsString(string);
					IF LoadFromPartition(string) THEN UpdateGrid; END;
				ELSE
					HALT(397);
				END;
			ELSIF button = set THEN
				IF target = ToFile THEN
					editorFile.GetAsString(string);
					StoreToFile(string);
				ELSIF target = ToPartition THEN
					editorPartition.GetAsString(string);
					StoreToPartition(string);
				ELSE
					HALT(397);
				END;
			ELSE
				HALT(398);
			END;
		END ButtonHandler;

		PROCEDURE ScrollY(sender, data : ANY);
		VAR y : WMProperties.Int32Property;
		BEGIN
			y := data (WMProperties.Int32Property);
			grid.bounds.SetTop(-y.Get());
		END ScrollY;

		PROCEDURE CheckboxHandler(sender, data : ANY);
		VAR button : WMStandardComponents.Button;
		BEGIN
			button := sender (WMStandardComponents.Button);
			toFile.caption.Set(Strings.NewString(""));
			toPartition.caption.Set(Strings.NewString(""));
			IF button = toFile THEN
				target := ToFile; toFile.caption.Set(Strings.NewString("X"));
			ELSIF button = toPartition THEN
				target := ToPartition; toPartition.caption.Set(Strings.NewString("X"));
			ELSE
				HALT(398);
			END;
		END CheckboxHandler;

		PROCEDURE GridClicked(sender, data : ANY);
		VAR grid : WMPartitionsComponents.NoWheelGrid; ignore, row : LONGINT; string : Strings.String;
		BEGIN
			grid := sender (WMPartitionsComponents.NoWheelGrid);
			grid.GetSelection(ignore, row, ignore, ignore);
			selectedRow := row;
			grid.Acquire;
			grid.model.Acquire;
			string := grid.model.GetCellText(0, row); editorKey.SetAsString(string^);
			string := grid.model.GetCellText(1, row); editorValue.SetAsString(string^);
			grid.model.Release;
			grid.Release;
		END GridClicked;

		PROCEDURE UpdateGrid;
		VAR row, height : LONGINT; spacings : WMGrids.Spacings; table : PartitionsLib.Table;
		BEGIN
			table := configTable.GetEntries();
			IF table # NIL THEN
				grid.Acquire;
				grid.model.Acquire;
				grid.model.SetNofRows(LEN(table));
				FOR row := 0 TO LEN(table)-1 DO
					grid.model.SetCellText(0, row, table[row].key);
					grid.model.SetCellText(1, row, table[row].value);
					height := height + cellHeight + CeCellHeightMinSpacer + 1;
				END;
				NEW(spacings, LEN(table));
				FOR row := 0 TO LEN(table)-1 DO spacings[row] := cellHeight + CeCellHeightMinSpacer; END;
				grid.SetRowSpacings(spacings);
				grid.model.Release;
				grid.Release;
				grid.bounds.SetExtents(2000, height);
			ELSE
				grid.Acquire;
				grid.model.Acquire;
				grid.model.SetNofRows(1);
				grid.model.SetCellText(0, row, Strings.NewString(""));
				grid.model.SetCellText(1, row, Strings.NewString("No config loaded"));
				NEW(spacings, 1); spacings[0] := cellHeight + CeCellHeightMinSpacer; grid.SetRowSpacings(spacings);
				grid.model.Release;
				grid.Release;
				grid.bounds.SetExtents(2000, spacings[0]+1);
			END;
			UpdateLayout(SELF.bounds.r - SELF.bounds.l, SELF.bounds.b - SELF.bounds.t);
		END UpdateGrid;

		PROCEDURE UpdateLayout(width, height : LONGINT);
		VAR gridHeight : LONGINT; table : PartitionsLib.Table;
		BEGIN
			DisableUpdate;
			mainpanel.bounds.SetExtents(width, height);
			titlelabel.bounds.SetExtents(width - 2*MarginH, CeLabelHeight);
			gridPanel.bounds.SetExtents(width - 2*MarginH, height - CeLabelHeight - StatusBarHeight- CeOpPanelHeight - CeEditPanelHeight - 5*MarginV);
			gridContainer.bounds.SetExtents(gridPanel.bounds.GetWidth() - 2*MarginH, gridPanel.bounds.GetHeight() - 2*MarginV);
			table := configTable.GetEntries();
			IF table # NIL THEN
				gridHeight := LEN(table)*(cellHeight + CeCellHeightMinSpacer + 1);
			END;
			scrollbarY.bounds.SetLeft(gridContainer.bounds.GetWidth() - scrollbarY.bounds.GetWidth());
			scrollbarY.bounds.SetHeight(gridContainer.bounds.GetHeight());

			IF gridHeight > gridContainer.bounds.GetHeight() THEN
				scrollbarY.pos.Set(ENTIER(1.0*scrollbarY.pos.Get()*(1.0*(gridHeight-gridContainer.bounds.GetHeight()) / scrollbarY.max.Get())));
				scrollbarY.max.Set(gridHeight-gridContainer.bounds.GetHeight());
				scrollbarY.visible.Set(TRUE);
			ELSE
				scrollbarY.visible.Set(FALSE);
			END;
			editPanel.bounds.SetTop(height - CeOpPanelHeight - CeEditPanelHeight - StatusBarHeight - 2*MarginV);
			editPanel.bounds.SetExtents(width - 2*MarginH, CeEditPanelHeight);
			editorValue.bounds.SetWidth(width - CeKeyWidth - 2*MarginH - 2*MarginH);
			opPanel.bounds.SetExtents(width - 2*MarginH, CeOpPanelHeight);
			opPanel.bounds.SetTop(height - StatusBarHeight - CeOpPanelHeight - MarginV);
			editorFile.bounds.SetWidth(width - fileLeft - 2*MarginH - MarginH);
			statusLabel.bounds.SetExtents(width, StatusBarHeight);
			statusLabel.bounds.SetTop(height - StatusBarHeight);
			EnableUpdate;
			CSChanged;
		END UpdateLayout;

		PROCEDURE Close;
		BEGIN
			Close^; IF popup # NIL THEN popup.Close; END;
		END Close;

		PROCEDURE Resized(width, height : LONGINT);
		BEGIN
			Resized^(width, height);
			UpdateLayout(width, height);
		END Resized;

		PROCEDURE &Init*(width, height : LONGINT; alpha : BOOLEAN);
		VAR
			left, ignore : LONGINT;
			spacings : WMGrids.Spacings;
			font : WMGraphics.Font;
			label : WMStandardComponents.Label;
		BEGIN
			Init^(width, height, alpha); scaling := FALSE; hex := "0123456789ABCDEF";
			NEW(config);
			NEW(configTable);

			NEW(mainpanel); mainpanel.bounds.SetLeft(0); mainpanel.bounds.SetTop(0);
			IF ~UseSkinColors THEN mainpanel.fillColor.Set(BackgroundColor); END;

			NEW(titlelabel); titlelabel.bounds.SetLeft(MarginH); titlelabel.bounds.SetTop(MarginV);
			mainpanel.AddInternalComponent(titlelabel);

			NEW(gridPanel); gridPanel.bounds.SetLeft(MarginH); gridPanel.bounds.SetTop(CeLabelHeight + 2*MarginV);
			mainpanel.AddInternalComponent(gridPanel);

			NEW(gridContainer); gridContainer.bounds.SetLeft(MarginH); gridContainer.bounds.SetTop(MarginV);
			gridPanel.AddInternalComponent(gridContainer);

			NEW(grid);
			grid.fixedCols.Set(1);
			grid.onClick.Add(GridClicked); grid.SetSelectionMode(WMGrids.GridSelectSingleRow);
			grid.alwaysShowScrollX.Set(FALSE); grid.showScrollX.Set(FALSE);
			grid.alwaysShowScrollY.Set(FALSE); grid.showScrollY.Set(FALSE);
			grid.allowColResize.Set(TRUE); grid.allowRowResize.Set(FALSE);
			NEW(spacings, 2); spacings[0] := CeKeyWidth; spacings[1] := 2000; (* since allowColResize *)
			grid.Acquire;
			grid.model.Acquire;
			grid.model.SetNofCols(2); grid.SetColSpacings(spacings);
			grid.model.Release;
			grid.Release;
			gridContainer.AddInternalComponent(grid);

			NEW(scrollbarY);
			scrollbarY.vertical.Set(TRUE); scrollbarY.bounds.SetHeight(gridContainer.bounds.GetHeight());
			scrollbarY.bounds.SetTop(0); scrollbarY.bounds.SetLeft(gridContainer.bounds.GetWidth() - scrollbarY.bounds.GetWidth());
			scrollbarY.min.Set(0); scrollbarY.onPositionChanged.Add(ScrollY);
			gridContainer.AddInternalComponent(scrollbarY);

			font := grid.GetFont(); font.GetStringSize("TestString", ignore, cellHeight);

			NEW(editPanel); editPanel.bounds.SetLeft(MarginH);
			editPanel.bounds.SetTop(height - CeEditPanelHeight - StatusBarHeight - CeOpPanelHeight - 2*MarginV);
			mainpanel.AddInternalComponent(editPanel);

			NEW(editorKey);
			editorKey.bounds.SetExtents(CeKeyWidth, ButtonHeight);
			editorKey.bounds.SetLeft(MarginH); editorKey.bounds.SetTop(MarginV);
			editorKey.multiLine.Set(FALSE);
			editorKey.tv.textAlignV.Set(WMGraphics.AlignCenter);
			IF ~UseSkinColors THEN editorKey.fillColor.Set(WMGraphics.White); END;
			editorKey.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1)); editorKey.tv.showBorder.Set(TRUE);
			editPanel.AddInternalComponent(editorKey);

			NEW(editorValue);
			editorValue.bounds.SetExtents(width - CeKeyWidth - 2*MarginH - 2*MarginH, ButtonHeight);
			editorValue.bounds.SetLeft(CeKeyWidth + MarginH); editorValue.bounds.SetTop(MarginV);
			editorValue.multiLine.Set(FALSE);
			editorValue.tv.textAlignV.Set(WMGraphics.AlignCenter);
			IF ~UseSkinColors THEN editorValue.fillColor.Set(WMGraphics.White); END;
			editorValue.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1)); editorValue.tv.showBorder.Set(TRUE);
			editPanel.AddInternalComponent(editorValue);

			NEW(add); left := MarginH;
			add.bounds.SetExtents(ButtonWidth, ButtonHeight);
			add.bounds.SetLeft(left); add.bounds.SetTop(MarginV + ButtonHeight + ButtonSpacer);
			add.onClick.Add(ButtonHandler); add.caption.Set(Strings.NewString("Add"));
			editPanel.AddInternalComponent(add);

			NEW(delete); left := left + ButtonWidth + ButtonSpacer;
			delete.bounds.SetExtents(ButtonWidth, ButtonHeight);
			delete.bounds.SetLeft(left); delete.bounds.SetTop(MarginV + ButtonHeight + ButtonSpacer);
			delete.onClick.Add(ButtonHandler); delete.caption.Set(Strings.NewString("Delete"));
			editPanel.AddInternalComponent(delete);

			NEW(replace); left := left + ButtonWidth + ButtonSpacer;
			replace.bounds.SetExtents(ButtonWidth, ButtonHeight);
			replace.bounds.SetLeft(left); replace.bounds.SetTop(MarginV + ButtonHeight + ButtonSpacer);
			replace.onClick.Add(ButtonHandler); replace.caption.Set(Strings.NewString("Replace"));
			editPanel.AddInternalComponent(replace);

			NEW(clear); left := left + ButtonWidth + ButtonSpacer;
			clear.bounds.SetExtents(ButtonWidth, ButtonHeight);
			clear.bounds.SetLeft(left); clear.bounds.SetTop(MarginV + ButtonHeight + ButtonSpacer);
			clear.onClick.Add(ButtonHandler); clear.caption.Set(Strings.NewString("Clear"));
			editPanel.AddInternalComponent(clear);

			NEW(moveup); left := left + ButtonWidth + ButtonSpacer;
			moveup.bounds.SetExtents(ButtonWidth, ButtonHeight);
			moveup.bounds.SetLeft(left); moveup.bounds.SetTop(MarginV + ButtonHeight + ButtonSpacer);
			moveup.onClick.Add(ButtonHandler); moveup.caption.Set(Strings.NewString("Up"));
			editPanel.AddInternalComponent(moveup);

			NEW(movedown);
			movedown.bounds.SetExtents(ButtonWidth, ButtonHeight);
			movedown.bounds.SetLeft(left); movedown.bounds.SetTop(MarginV + 2*ButtonHeight + 2*ButtonSpacer);
			movedown.onClick.Add(ButtonHandler); movedown.caption.Set(Strings.NewString("Down"));
			editPanel.AddInternalComponent(movedown);

			NEW(opPanel);
			opPanel.bounds.SetExtents(width - 2*MarginH, CeOpPanelHeight);
			opPanel.bounds.SetLeft(MarginH); opPanel.bounds.SetTop(height - StatusBarHeight - CeOpPanelHeight - MarginV);
			mainpanel.AddInternalComponent(opPanel);

			NEW(get); left := MarginH;
			get.bounds.SetExtents(ButtonWidth, ButtonHeight);
			get.bounds.SetLeft(left); get.bounds.SetTop(MarginV);
			get.onClick.Add(ButtonHandler); get.caption.Set(Strings.NewString("GetConfig"));
			opPanel.AddInternalComponent(get);

			NEW(set); left := left + ButtonWidth + ButtonSpacer;
			set.bounds.SetExtents(ButtonWidth, ButtonHeight);
			set.bounds.SetLeft(left); set.bounds.SetTop(MarginV);
			set.onClick.Add(ButtonHandler); set.caption.Set(Strings.NewString("SetConfig"));
			opPanel.AddInternalComponent(set);

			target := ToPartition;
			NEW(toPartition); left := left + ButtonWidth + ButtonSpacer;
			toPartition.bounds.SetExtents(ButtonHeight, ButtonHeight);
			toPartition.bounds.SetLeft(left); toPartition.bounds.SetTop(MarginV);
			toPartition.onClick.Add(CheckboxHandler); toPartition.caption.Set(Strings.NewString("X"));
			opPanel.AddInternalComponent(toPartition);

			NEW(label); left := left + ButtonHeight + ButtonSpacer;
			label.bounds.SetExtents(50, ButtonHeight); label.bounds.SetLeft(left); label.bounds.SetTop(MarginV);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); END;
			label.caption.Set(Strings.NewString("Partition:"));
			opPanel.AddInternalComponent(label);

			NEW(editorPartition); left := left + 50;
			editorPartition.bounds.SetExtents(50, ButtonHeight);
			editorPartition.bounds.SetLeft(left); editorPartition.bounds.SetTop(MarginV);
			editorPartition.multiLine.Set(FALSE);
			editorPartition.tv.textAlignV.Set(WMGraphics.AlignCenter);
			IF ~UseSkinColors THEN editorPartition.fillColor.Set(WMGraphics.White); END;
			editorPartition.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1)); editorPartition.tv.showBorder.Set(TRUE);
			opPanel.AddInternalComponent(editorPartition);

			NEW(toFile); left := left + 50 + ButtonSpacer;
			toFile.bounds.SetExtents(ButtonHeight, ButtonHeight);
			toFile.bounds.SetLeft(left); toFile.bounds.SetTop(MarginV);
			toFile.onClick.Add(CheckboxHandler); toFile.caption.Set(Strings.NewString(""));
			opPanel.AddInternalComponent(toFile);

			NEW(label); left := left + ButtonHeight + ButtonSpacer;
			label.bounds.SetExtents(22, ButtonHeight); label.bounds.SetLeft(left); label.bounds.SetTop(MarginV);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); END;
			label.caption.Set(Strings.NewString("File:"));
			opPanel.AddInternalComponent(label);

			NEW(editorFile); left := left + 22 + ButtonSpacer; fileLeft := left;
			editorFile.bounds.SetExtents(width - fileLeft - MarginH - MarginH, ButtonHeight);
			editorFile.bounds.SetLeft(left); editorFile.bounds.SetTop(MarginV);
			editorFile.multiLine.Set(FALSE);
			editorFile.tv.textAlignV.Set(WMGraphics.AlignCenter);
			IF ~UseSkinColors THEN editorFile.fillColor.Set(WMGraphics.White); END;
			editorFile.tv.borders.Set(WMRectangles.MakeRect(3, 3, 1, 1)); editorFile.tv.showBorder.Set(TRUE);
			editorFile.SetAsString("config.txt"); (* default file name *)
			opPanel.AddInternalComponent(editorFile);

			NEW(statusLabel);
			statusLabel.bounds.SetLeft(0); statusLabel.bounds.SetTop(height - StatusBarHeight);
			IF ~UseSkinColors THEN
				statusLabel.fillColor.Set(WMGraphics.Blue); statusLabel.textColor.Set(WMGraphics.Yellow);
			END;
			statusLabel.caption.Set(Strings.NewString("Ready"));
			mainpanel.AddInternalComponent(statusLabel);

			SetTitle(Strings.NewString("Configuration Editor"));
			SetContent(mainpanel);

			WMWindowManager.AddWindow (SELF, 100, 100);
			manager := WMWindowManager.GetDefaultManager();
			manager.SetFocus(SELF);

			UpdateLayout(width, height);
		END Init;

	END ConfigEditor;

	(*
	 * The Partitions plugin is a graphical front-end for partitioning operations provided by PartitionsLib.Mod.
	 *)
	PartitionsPlugin = OBJECT (Plugin);
	VAR
		show, eject, checkPartition, activeBit, format, changeType,
		delete, create, partitionToFile, fileToPartition, writeMBR, editPBR : WMStandardComponents.Button;

		PROCEDURE &Init*;
		VAR left : LONGINT;
		BEGIN
			Init^;

			(* upper row of buttons *)
			NEW(create); left := 0;
			create.bounds.SetExtents(ButtonWidth, ButtonHeight); create.bounds.SetLeft(left); create.bounds.SetTop(0);
			create.onClick.Add(Create); create.SetCaption("Create");
			AddInternalComponent(create);

			NEW(format); left := left + ButtonWidth + ButtonSpacer;
			format.bounds.SetExtents(ButtonWidth, ButtonHeight); format.bounds.SetLeft(left);  format.bounds.SetTop(0);
			format.onClick.Add(Format); format.SetCaption("Format");
			AddInternalComponent(format);

			NEW(fileToPartition); left := left + ButtonWidth + ButtonSpacer;
			fileToPartition.bounds.SetExtents(ButtonWidth, ButtonHeight); fileToPartition.bounds.SetLeft(left); fileToPartition.bounds.SetTop(0);
			fileToPartition.onClick.Add(FileToPartition); fileToPartition.SetCaption("FromFile");
			AddInternalComponent(fileToPartition);

			NEW(activeBit); left := left + ButtonWidth + ButtonSpacer;
			activeBit.bounds.SetExtents(ButtonWidth, ButtonHeight); activeBit.bounds.SetLeft(left);  activeBit.bounds.SetTop(0);
			activeBit.onClick.Add(ActiveBit); activeBit.SetCaption("Activate");
			AddInternalComponent(activeBit);

			NEW(show); left := left + ButtonWidth + ButtonSpacer;
			show.bounds.SetExtents(ButtonWidth, ButtonHeight); show.bounds.SetLeft(left);  show.bounds.SetTop(0);
			show.onClick.Add(Show); show.SetCaption("ShowBlocks");
			AddInternalComponent(show);

			NEW(writeMBR); left := left + ButtonWidth + ButtonSpacer;
			writeMBR.bounds.SetExtents(ButtonWidth, ButtonHeight); writeMBR.bounds.SetLeft(left); writeMBR.bounds.SetTop(0);
			writeMBR.onClick.Add(WriteMBR); writeMBR.SetCaption("WriteMBR");
			AddInternalComponent(writeMBR);

			(* 2nd row of buttons *)
			NEW(delete); left := 0;
			delete.bounds.SetExtents(ButtonWidth, ButtonHeight); delete.bounds.SetLeft(left); delete.bounds.SetTop(ButtonHeight + ButtonSpacer);
			delete.onClick.Add(Delete); delete.SetCaption("Delete");
			AddInternalComponent(delete);

			NEW(changeType); left := left + ButtonWidth + ButtonSpacer;
			changeType.bounds.SetExtents(ButtonWidth, ButtonHeight); changeType.bounds.SetLeft(left); changeType.bounds.SetTop(ButtonHeight + ButtonSpacer);
			changeType.onClick.Add(ChangeType); changeType.SetCaption("ChangeType");
			AddInternalComponent(changeType);

			NEW(partitionToFile); left := left + ButtonWidth + ButtonSpacer;
			partitionToFile.bounds.SetExtents(ButtonWidth, ButtonHeight); partitionToFile.bounds.SetLeft(left); partitionToFile.bounds.SetTop(ButtonHeight + ButtonSpacer);
			partitionToFile.onClick.Add(PartitionToFile); partitionToFile.SetCaption("ToFile");
			AddInternalComponent(partitionToFile);

			NEW(eject); left := left + ButtonWidth + ButtonSpacer;
			eject.bounds.SetExtents(ButtonWidth, ButtonHeight); eject.bounds.SetLeft(left); eject.bounds.SetTop(ButtonHeight + ButtonSpacer);
			eject.onClick.Add(Eject); eject.SetCaption("Eject");
			AddInternalComponent(eject);

			NEW(checkPartition); left := left + ButtonWidth + ButtonSpacer;
			checkPartition.bounds.SetExtents(ButtonWidth, ButtonHeight); checkPartition.bounds.SetLeft(left); checkPartition.bounds.SetTop(ButtonHeight + ButtonSpacer);
			checkPartition.onClick.Add(CheckPartition); checkPartition.SetCaption("Check");
			AddInternalComponent(checkPartition);

			NEW(editPBR); left := left + ButtonWidth + ButtonSpacer;
			editPBR.bounds.SetExtents(ButtonWidth, ButtonHeight); editPBR.bounds.SetLeft(left); editPBR.bounds.SetTop(ButtonHeight + ButtonSpacer);
			editPBR.onClick.Add(EditPBR); editPBR.SetCaption("EditPBR");
			AddInternalComponent(editPBR);
		END Init;

		(** This procedure is called everytime when the selection has been updated *)
		(** Return value: SelectionValid, SelectionInvalid, SelectionMaybe *)
		PROCEDURE SelectionUpdated(selection : WMPartitionsComponents.Selection) : LONGINT;
		VAR result : LONGINT;
		BEGIN
			SELF.selection := selection;
			IF IsValid(selection) THEN
				IF Disks.Boot IN selection.disk.table[selection.partition].flags THEN
					activeBit.caption.Set(Strings.NewString("Deactivate"));
				ELSE
					activeBit.caption.Set(Strings.NewString("Activate"));
				END;
				result := SelectionMaybe;
			ELSE
				result := SelectionInvalid;
			END;
			RETURN result;
		END SelectionUpdated;

		(* Create a new extended or primary partition. *)
		PROCEDURE Create(sender, data : ANY);
		VAR
			create : PartitionsLib.CreatePartition;
			popup : PopupWindow; param : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) & ~selection.disk.isDiskette THEN
				NEW(param, 2);
				param[0].description := "Size"; param[0].type := ParInteger; param[0].width := 0;
				param[0].optional := FALSE; param[0].default := FALSE;
				param[1].description := "Type"; param[1].type := ParInteger; param[1].width := 0;
				param[1].optional := FALSE; param[1].default := FALSE;
				NEW(popup, 220, 160, FALSE);
				popup.SetTextAsString("Enter size [MB] and type of the partition to be created. To create an extended partition, select type 5.");
				popup.SetParameters("Create a new partition on", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					ASSERT(param[0].valid);
					NEW(create, selection.disk, selection.partition, NIL);
					create.SetParameters(param[0].resInteger, param[1].resInteger, FALSE);
					create.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection Invalid"));
			END;
		END Create;

		(* Delete the selected partition. *)
		PROCEDURE Delete(sender, data : ANY);
		VAR
			delete : PartitionsLib.DeletePartition;
			popup : PopupWindow; param : Parameters;
			res : LONGINT;
		BEGIN
			IF  ~selection.disk.isDiskette & IsValid(selection) &
			    (selection.disk.device # NIL) & (selection.partition < LEN(selection.disk.device.table))
			    THEN
				NEW(popup, 200, 100, FALSE);
				popup.SetTextAsString("Delete partition?");
				param := NIL;
				popup.SetParameters("Delete partition", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					NEW(delete, selection.disk, selection.partition, NIL);
					delete.SetParameters(selection.disk.table[selection.partition].type);
					delete.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END Delete;

		(* Write a MBR to the selected device *)
		PROCEDURE WriteMBR(sender, data : ANY);
		VAR
			writeMBR : PartitionsLib.WriteMBR;
			popup : PopupWindow; param : Parameters;
			res : LONGINT;
		BEGIN
			IF (selection.disk.device # NIL) & (selection.partition = 0) & (selection.disk.table # NIL) & ~selection.disk.isDiskette THEN
				NEW(popup, 250, 180, FALSE);
				popup.SetTextAsString("Write MBR to partition?");
				NEW(param, 3);
				param[0].description := "MBR file"; param[0].type := ParString; param[0].optional := FALSE;
				param[0].width := 0; param[0].default := TRUE; param[0].resString := "OBEMBR.BIN";
				param[1].description := "Preserve Table"; param[1].type := ParBoolean;
				param[1].default := TRUE; param[1].resBoolean := TRUE;
				param[2].description := "Preserve Disk Signature"; param[2].type := ParBoolean;
				param[2].default := TRUE; param[2].resBoolean := TRUE;
				popup.SetParameters("Write MBR to", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					NEW(writeMBR, selection.disk, selection.partition, NIL);
					writeMBR.SetParameters(param[0].resString, param[1].resBoolean, param[2].resBoolean);
					writeMBR.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END WriteMBR;

		PROCEDURE EditPBR(sender, data : ANY);
		VAR cmd, msg : ARRAY 512 OF CHAR; nbr : ARRAY 16 OF CHAR; res : LONGINT;
		BEGIN
			IF (selection.disk.device # NIL) & (selection.disk.table # NIL) & (selection.partition < LEN(selection.disk.table)) & ~selection.disk.isDiskette THEN
				cmd := "PartitionEditor.Open ";
				Strings.Append(cmd, selection.disk.device.name);
				Strings.Append(cmd, " ");
				Strings.IntToStr(selection.disk.table[selection.partition].start, nbr);
				Strings.Append(cmd, nbr);
				Commands.Call(cmd, {}, res, msg);
				IF (res # Commands.Ok) THEN
					owner.UpdateStatusLabel(Strings.NewString(msg));
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END EditPBR;

		(* Format the selected partition. *)
		PROCEDURE Format (sender, data : ANY);
		VAR
			formatAOS : PartitionsLib.FormatPartition;
			formatFAT : FATScavenger.FormatPartition;
			volumelabel : Strings.String;
			popup : PopupWindow; params : Parameters;
			cancel, doClose : BOOLEAN;
			fs : LONGINT;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) & ((selection.disk.table[selection.partition].flags * {Disks.Valid} # {}) OR selection.disk.isDiskette) THEN

				(* If a floppy drive is selected, check whether it contains a diskette *)
				cancel := FALSE; doClose := FALSE;
				IF selection.disk.isDiskette & (selection.disk.device.openCount < 1) THEN
					doClose := TRUE;
					selection.disk.device.Open(res);
					IF res = Disks.MediaMissing THEN
						cancel := TRUE;
						owner.UpdateStatusLabel(Strings.NewString("No diskette inserted"));
					ELSIF res # Disks.Ok THEN
						cancel := TRUE;
						owner.UpdateStatusLabel(Strings.NewString("Cannot open floppy device"));
					END;
				END;

				IF selection.disk.isDiskette THEN (* let the user choose the file system *)
					NEW(params, 1);
					params[0].description := "File System (FatFS or AosFS)"; params[0].type := ParString;
					params[0].optional := FALSE; params[0].width := 0;
					NEW(popup, 250, 200, FALSE);
					popup.SetTextAsString("Format the selected diskette with the specified file system");
					popup.SetParameters("Format diskette", selection, params);
					popup.Popup(100,100,res);
					IF res = ResOk THEN
						IF params[0].valid THEN
							IF params[0].resString = "FatFS" THEN
								fs := 2;
							ELSIF params[0].resString = "AosFS" THEN
								fs := 1;
							ELSE
								fs := 0; (* invalid paramter *)
							END;
						END;
					ELSE
						cancel := TRUE; (* user abort *)
					END;
				ELSE (* use file system that matches the partition type *)
					IF PartitionsLib.IsNativeType(selection.disk.table[selection.partition].type) THEN
						fs := 1;
					ELSIF PartitionsLib.IsFatType(selection.disk.table[selection.partition].type) THEN
						fs := 2;
					ELSE
						fs := 0; (* not supported *)
						owner.UpdateStatusLabel(Strings.NewString("Only FatFS or AosFS supported"));
					END;
				END;

				IF cancel THEN
					(* do nothing *)
				ELSIF fs = 1 THEN
					NEW(params, 4);
					params[0].description := "File System"; params[0].type := ParString;
					params[0].optional := FALSE; params[0].width := 0; params[0].resString := "AosFS"; params[0].default := TRUE;
					params[1].description := "[Bootfile]"; params[1].type := ParString;
					params[1].optional := TRUE;  params[1].width := 0; params[1].resString := "IDE.Bin"; params[1].default := TRUE;
					params[2].description := "[fsRes (KB)]"; params[2].type := ParInteger; params[2].default := TRUE;
					params[2].optional := TRUE; params[2].width := 0; params[2].resInteger := 640;
					params[3].description := "[flags]"; params[3].type := ParInteger; params[3].default := TRUE;
					params[3].optional := TRUE;  params[3].width := 0; params[3].resInteger := 0;
					NEW(popup, 250, 200, FALSE);
					popup.SetTextAsString("Enter parameters");
					popup.SetParameters("Format partition ", selection, params);
					popup.Popup(100,100, res);
					IF res = ResOk THEN
						IF params[1].valid = FALSE THEN params[1].resString := ""; END;
						(* filesystem [bootfilename] [fsres] [flags] *)
						NEW(formatAOS, selection.disk, selection.partition, NIL);
						formatAOS.SetParameters(params[0].resString, params[1].resString, params[2].resInteger, params[3].resInteger);
						formatAOS.SetStart;
					END;
				ELSIF fs = 2 THEN
					NEW(params, 2);
					params[0].description := "Volume label"; params[0].type := ParString;
					params[0].optional := TRUE; params[0].width := 0; params[0].default := FALSE;
					params[1].description := "Quickformat"; params[1].type := ParBoolean;
					params[1].optional := TRUE; params[1].width := 30; params[1].default := TRUE;
					params[1].resBoolean := FALSE;
					NEW(popup, 250, 150, FALSE);
					popup.SetTextAsString("Enter parameters");
					popup.SetParameters("Format partition ", selection, params);
					popup.Popup(100,100, res);
					IF res = ResOk THEN
						IF params[0].valid THEN volumelabel := Strings.NewString(params[0].resString);
						ELSE volumelabel := Strings.NewString("");
						END;
						NEW(formatFAT, selection.disk, selection.partition, NIL);
						formatFAT.SetParameters(volumelabel, params[0].resBoolean);
						formatFAT.SetStart;
					END;
				ELSE owner.UpdateStatusLabel(Strings.NewString("Can't format partition of this type"));
				END;

				IF selection.disk.isDiskette & doClose & (selection.disk.device.openCount > 0) THEN
					selection.disk.device.Close(res); (* ignore res *)
				END;

			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END Format;

		(* Change the type of the selected partition. *)
		PROCEDURE ChangeType(sender, data : ANY);
		VAR
			changeType : PartitionsLib.ChangePartType;
			oldtype, newtype : LONGINT;
			popup : PopupWindow;
			param : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) & (selection.disk.table[selection.partition].flags * {Disks.Valid} # {}) THEN
				NEW(param, 1);
				param[0].description := "New Type"; param[0].type := ParInteger; param[0].optional := FALSE;
				param[0].width := 30; param[0].default := FALSE;
				NEW(popup, 200, 130, FALSE);
				popup.SetParameters("Change type of ", selection, param); popup.SetTextAsString("Enter new type");
				popup.Popup(100,100, res);
				IF res = ResOk THEN
					ASSERT(param[0].valid);
					NEW(changeType, selection.disk, selection.partition, NIL);
					newtype := param[0].resInteger;
					oldtype := selection.disk.table[selection.partition].type;
					changeType.SetParameters(oldtype, newtype);
					changeType.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END ChangeType;

		(* Set the active bit for the selected partition. *)
		PROCEDURE ActiveBit(sender, data : ANY);
		VAR
			setFlags : PartitionsLib.SetFlags;
			popup : PopupWindow; param : Parameters;
			string : ARRAY 64 OF CHAR;
			on : BOOLEAN;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) & (Disks.Valid IN selection.disk.table[selection.partition].flags) & ~selection.disk.isDiskette THEN
				on := Disks.Boot IN selection.disk.table[selection.partition].flags;
				NEW(popup, 200, 100, FALSE);
				IF on THEN
					string := "Deactivate partition";
				ELSE
					string := "Activate partition";
				END;
				param := NIL;
				popup.SetParameters(string, selection, param); popup.SetTextAsString("Are you sure?");
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					NEW(setFlags, selection.disk, selection.partition, NIL);
					setFlags.SetParameters(~on);
					setFlags.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END ActiveBit;

		PROCEDURE FileToPartition(sender, data : ANY);
		VAR
			fileToPartition : PartitionsLib.FileToPartition;
			popup : PopupWindow; param : Parameters;
			block, numblocks, res : LONGINT;
		BEGIN
			IF IsValid(selection) THEN
				NEW(param, 3);
				param[0].description := "Filename"; param[0].type := ParString; param[0].optional := FALSE;
				param[0].width := 0; param[0].default := FALSE;
				param[1].description := "Offset"; param[1].type := ParInteger; param[1].optional := TRUE;
				param[1].width := 0; param[1].default := FALSE;
				param[2].description := "Numblocks"; param[2].type := ParInteger; param[2].optional := TRUE;
				param[2].width := 0; param[2].default := FALSE;
				NEW(popup, 200, 180, FALSE);
				popup.SetTextAsString("Write file <Filename> to the specified partition, starting at bock <Offset>, <Numblocks> blocks ");
				popup.SetParameters("FileToPartition on", selection, param);
				popup.Popup(100,100, res);
				IF res = ResOk THEN
					ASSERT(param[0].valid);
					NEW(fileToPartition, selection.disk, selection.partition, NIL);
					IF param[1].valid THEN block := param[1].resInteger; ELSE block := -1; END;
					IF param[2].valid THEN numblocks := param[2].resInteger; ELSE numblocks := -1; END;
					fileToPartition.SetParameters(param[0].resString, block, numblocks); (* filename [block numblocks] *)
					fileToPartition.SetStart;
				END;
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END FileToPartition;

		PROCEDURE PartitionToFile(sender, data : ANY);
		VAR
			partitionToFile : PartitionsLib.PartitionToFile;
			popup : PopupWindow; param : Parameters;
			block, numblocks, res : LONGINT;
		BEGIN
			IF IsValid(selection) THEN
				NEW(param, 3);
				param[0].description := "Filename"; param[0].type := ParString; param[0].optional := FALSE;
				param[0].width := 0; param[0].default := FALSE;
				param[1].description := "Offset"; param[1].type := ParInteger; param[1].optional := TRUE;
				param[1].width := 0; param[1].default := FALSE;
				param[2].description := "Numblocks"; param[2].type := ParInteger; param[2].optional := TRUE;
				param[2].width := 0; param[2].default := FALSE;
				NEW(popup, 200, 180, FALSE);
				popup.SetTextAsString("Write partition to file <Filename>, starting at block <Offset>, <Numblocks> blocks. ");
				popup.SetParameters("PartitionToFile on ", selection, param);
				popup.Popup(100,100, res);
				IF res = ResOk THEN
					ASSERT(param[0].valid);
					IF param[1].valid THEN block := param[1].resInteger; ELSE block := -1; END;
					IF param[2].valid THEN numblocks := param[2].resInteger; ELSE numblocks := -1; END;
					NEW(partitionToFile, selection.disk, selection.partition, NIL);
					partitionToFile.SetParameters(param[0].resString, block, numblocks); (* filename [block numblocks] *)
					partitionToFile.SetStart;
				END;
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END PartitionToFile;

		(* Will be registered as callback at PartitionsLib.ShowBlocks *)
		PROCEDURE ShowCallback(text : Texts.Text);
		VAR window : ReportWindow;
		BEGIN
			NEW(window, text, 560, 240, FALSE); window.Show;
		END ShowCallback;

		PROCEDURE Show(sender, data : ANY);
		VAR
			showBlocks : PartitionsLib.ShowBlocks;
			popup : PopupWindow; param : Parameters;
			block, numblocks, res : LONGINT;
		BEGIN
			IF IsValid(selection) THEN
				NEW(param, 2);
				param[0].description := "Block"; param[0].type := ParInteger; param[0].optional := FALSE;
				param[0].width := 0; param[0].default := FALSE;
				param[1].description := "Numblocks"; param[1].type := ParInteger; param[1].optional := FALSE;
				param[1].width := 0; param[1].default := FALSE;
				NEW(popup, 200, 160, FALSE);
				popup.SetTextAsString("Show <numblocks> blocks of partition starting at block <block>");
				popup.SetParameters("Showblocks on", selection, param);
				popup.Popup(100,100, res);
				IF res = ResOk THEN
					ASSERT(param[0].valid);
					NEW(showBlocks, selection.disk, selection.partition, NIL);
					block := param[0].resInteger;
					numblocks := param[1].resInteger;
					showBlocks.SetParameters(block, numblocks); (* block [numblocks] *)
					showBlocks.SetCallback(ShowCallback);
					showBlocks.SetStart;
				END;
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END Show;

		PROCEDURE Eject(sender, data : ANY);
		VAR
			result : ARRAY 128 OF CHAR;
			popup : PopupWindow; param : Parameters;
			eject : BOOLEAN;
			res : LONGINT;
		BEGIN
			IF (selection.disk.device # NIL) & (~selection.disk.isDiskette) THEN
				IF (Disks.Removable IN selection.disk.device.flags) THEN
					eject := TRUE;
					IF selection.disk.device.openCount > 0 THEN
						param := NIL;
						popup.SetParameters("Eject disk", selection,  param);
						NEW(popup, 200, 100, FALSE);
						popup.SetTextAsString("Device is open. Do you really want to eject its media? ");
						popup.Popup(100,100, res);
						IF res # ResOk THEN eject := FALSE; END;
					END;
					IF eject THEN
						PartitionsLib.Eject(selection.disk.device, result);
						owner.UpdateStatusLabel(Strings.NewString(result));
					END;
				ELSE owner.UpdateStatusLabel(Strings.NewString("Device not removable"));
				END;
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END Eject;

		PROCEDURE CheckPartition(sender, data : ANY);
		VAR checkPartition : PartitionsLib.CheckPartition;
		BEGIN
			IF IsValid(selection) THEN
				NEW(checkPartition, selection.disk, selection.partition, NIL);
				checkPartition.SetStart;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END CheckPartition;

	END PartitionsPlugin;

TYPE

	A2Plugin = OBJECT(Plugin);
	VAR
		config, updateLoader, updateBoot, bootManagerBtn, installBtn : WMStandardComponents.Button;
		popup : PopupWindow;

		PROCEDURE Config(sender, data : ANY);
		VAR configEditor : ConfigEditor; doClose : BOOLEAN; fsType, res : LONGINT;
		BEGIN
			IF IsValid(selection) &
			    ((Disks.Valid IN selection.disk.table[selection.partition].flags) OR (selection.disk.isDiskette)) THEN
				IF selection.disk.device.blockSize = PartitionsLib.BS THEN
					(* special handling for diskette drives *)
					IF selection.disk.isDiskette & (selection.disk.device.openCount < 1) THEN
						doClose := TRUE;
						selection.disk.device.Open(res); (* ignore res *)
					END;
					fsType := PartitionsLib.DetectFS(selection.disk.device, selection.partition);
					IF (fsType = PartitionsLib.AosFS32) OR (fsType = PartitionsLib.AosFS128) THEN (* new AosFS *)
						NEW(configEditor, 800, 600, FALSE);
						IF configEditor.SetSelection(selection) THEN
							owner.UpdateStatusLabel(Strings.NewString("Configuration Editor started"));
						ELSE
							owner.UpdateStatusLabel(Strings.NewString("Could not load configuration"));
						END;
					ELSE owner.UpdateStatusLabel(Strings.NewString("Partitions does not contain a AosFS volume"));
					END;
					IF selection.disk.isDiskette & doClose & (selection.disk.device.openCount > 0) THEN
						selection.disk.device.Close(res); (* ignore res *)
					END;
				ELSE owner.UpdateStatusLabel(Strings.NewString("Error: Blocksize not supported"));
				END;
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection Invalid"));
			END;
		END Config;

		PROCEDURE UpdateLoader(sender, data : ANY);
		VAR
			updateLoader : PartitionsLib.UpdateBootLoader;
			param : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) &
			    ((Disks.Valid IN selection.disk.table[selection.partition].flags) OR (selection.disk.isDiskette)) THEN
				NEW(popup, 200, 140, FALSE);
				NEW(param, 1); param[0].description:=  "Bootloader name"; param[0].type := ParString;
				param[0].optional := FALSE; param[0].resString := "OBL.Bin"; param[0].default := TRUE;
				popup.SetTextAsString("Enter filename of boot loader");
				popup.SetParameters("Update bootloader on", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					NEW(updateLoader, selection.disk, selection.partition, NIL);
					updateLoader.SetParameters(param[0].resString);
					updateLoader.SetStart;
				END;
				popup := NIL;
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection Invalid"));
			END;
		END UpdateLoader;

		PROCEDURE UpdateBoot(sender, data : ANY);
		VAR
			updateBoot : PartitionsLib.UpdateBootFile;
			param : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) &
			    ((Disks.Valid IN selection.disk.table[selection.partition].flags) OR (selection.disk.isDiskette)) THEN
				NEW(popup, 200, 140, FALSE);
				NEW(param, 1); param[0].description:=  "filename"; param[0].type := ParString;
				param[0].optional := FALSE; param[0].resString := "IDE.Bin"; param[0].default := TRUE;
				popup.SetTextAsString("Enter filename of boot file");
				popup.SetParameters("Update bootfile on", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					NEW(updateBoot, selection.disk, selection.partition, NIL);
					updateBoot.SetParameters(param[0].resString);
					updateBoot.SetStart;
				END;
				popup := NIL;
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection Invalid"));
			END;
		END UpdateBoot;

		PROCEDURE InstallBootManager(sender, data : ANY);
		VAR
			installBootManager : PartitionsLib.InstallBootManager;
			param : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) & ((Disks.Valid IN selection.disk.table[selection.partition].flags) OR (selection.disk.isDiskette)) THEN
				NEW(popup, 300, 200, FALSE);
				NEW(param, 2);
				param[0].description:=  "MBR boot manager filename"; param[0].type := ParString;
				param[0].optional := FALSE; param[0].resString := "BootManagerMBR.Bin"; param[0].default := TRUE;
				param[1].description:=  "MBR boot manager filename"; param[1].type := ParString;
				param[1].optional := FALSE; param[1].resString := "BootManagerTail.Bin"; param[1].default := TRUE;
				popup.SetTextAsString("Enter names of boot manager files");
				popup.SetParameters("Install boot manager  on", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					NEW(installBootManager, selection.disk, selection.partition, NIL);
					installBootManager.SetParameters(param[0].resString, param[1].resString);
					installBootManager.SetStart;
				END;
				popup := NIL;
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection Invalid"));
			END;
		END InstallBootManager;

		PROCEDURE Install(sender, data : ANY);
		VAR
			installer : Installer.Installer; packages : Installer.Packages; configuration : Installer.Configuration;
			errorString : ARRAY 1024 OF CHAR; errorWriter : Streams.StringWriter;
			text : Texts.Text; textWriter : TextUtilities.TextWriter;
			reader : Streams.Reader;
			params : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) & ((Disks.Valid IN selection.disk.table[selection.partition].flags) OR selection.disk.isDiskette) THEN
				NEW(packages); NEW(errorWriter, LEN(errorString));
				IF packages.OpenPackages("InstallerPackages.XML", errorWriter) THEN
					NEW(configuration, selection.disk, selection.partition);
					configuration.SetPackages(packages);
					reader := Codecs.OpenInputStream("config.txt");
					IF (reader # NIL) THEN
						configuration.configTable.LoadFromStream(reader, errorString, res);
						IF (res = PartitionsLib.Ok) THEN
							IF configuration.CheckConfiguration(errorWriter) THEN
								NEW(text); NEW(textWriter, text);
								configuration.ToStream(textWriter); textWriter.Update;

								NEW(popup, 480, 250, FALSE);
								params := NIL;
								popup.SetParameters("Installer", selection, params);
								popup.SetText(text);
								popup.Popup(100, 100, res);

								IF (res = ResOk) THEN
									NEW(installer, selection.disk, selection.partition, NIL);
									installer.SetParameters(configuration);
									installer.SetStart;
								END;
							ELSE
								errorWriter.Get(errorString);
								WMDialogs.Error("Installer Error", errorString);
							END;
						ELSE
							WMDialogs.Error("Installer Error", errorString);
						END;
					ELSE
						WMDialogs.Error("Installer Error", "Configuration file Config.bin not found");
					END;
				ELSE
					errorWriter.Get(errorString);
					WMDialogs.Error("Installer Error", errorString);
				END;
			END;
		END Install;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF popup # NIL THEN popup.Close; popup := NIL END;
		END Finalize;

		PROCEDURE SelectionUpdated(selection : WMPartitionsComponents.Selection) : LONGINT;
		VAR result : LONGINT;
		BEGIN
			SELF.selection := selection;
			IF IsValid(selection) & (Disks.Valid IN selection.disk.table[selection.partition].flags) OR selection.disk.isDiskette THEN
				result := SelectionMaybe;
			ELSE
				result := SelectionInvalid;
			END;
			RETURN result;
		END SelectionUpdated;

		PROCEDURE &Init*;
		VAR  left : LONGINT;
		BEGIN
			Init^;

			(* upper row of buttons *)
			NEW(config); left := 0;
			config.bounds.SetExtents(ButtonWidth, ButtonHeight);
			config.bounds.SetLeft(left); config.bounds.SetTop(0);
			config.onClick.Add(Config); config.SetCaption("Config");
			AddInternalComponent(config);

			NEW(updateLoader); left := left + ButtonWidth + ButtonSpacer;
			updateLoader.bounds.SetExtents(2*ButtonWidth, ButtonHeight);
			updateLoader.bounds.SetLeft(left); updateLoader.bounds.SetTop(0);
			updateLoader.onClick.Add(UpdateLoader); updateLoader.SetCaption("UpdateBootLoader");
			AddInternalComponent(updateLoader);

			NEW(updateBoot); left := left +2* ButtonWidth + ButtonSpacer;
			updateBoot.bounds.SetExtents(2*ButtonWidth, ButtonHeight);
			updateBoot.bounds.SetLeft(left); updateBoot.bounds.SetTop(0);
			updateBoot.onClick.Add(UpdateBoot); updateBoot.SetCaption("UpdateBootFile");
			AddInternalComponent(updateBoot);

			NEW(bootManagerBtn); left := left +2*ButtonWidth + ButtonSpacer;
			bootManagerBtn.bounds.SetExtents(2*ButtonWidth, ButtonHeight);
			bootManagerBtn.bounds.SetLeft(left); bootManagerBtn.bounds.SetTop(0);
			bootManagerBtn.onClick.Add(InstallBootManager); bootManagerBtn.SetCaption("Install BootManager");
			AddInternalComponent(bootManagerBtn);

			(* bottom row *)
			NEW(installBtn); left := 0;
			installBtn.bounds.SetExtents(ButtonWidth, ButtonHeight);
			installBtn.bounds.SetLeft(left); installBtn.bounds.SetTop(ButtonHeight + ButtonSpacer);
			installBtn.onClick.Add(Install); installBtn.SetCaption("Install");
			AddInternalComponent(installBtn);
		END Init;

	END A2Plugin;

TYPE

	ScavengerPlugin = OBJECT(Plugin);
	VAR
		start, doSurfaceScan, doCompareFats, doLostClusters, doWrite : WMStandardComponents.Button;

		(* object polls scavenger status *)
		surfaceScan, compareFats, lostClusters, write : BOOLEAN;

		PROCEDURE &Init*;
		VAR label : WMStandardComponents.Label; left : LONGINT;
		BEGIN
			Init^;
			surfaceScan := FALSE; compareFats := TRUE; lostClusters := TRUE; write := FALSE;

			NEW(start);
			start.bounds.SetExtents(ButtonWidth, ButtonHeight);
			start.bounds.SetLeft(0); start.bounds.SetTop(0);
			start.onClick.Add(StartScan); start.SetCaption("Start");
			AddInternalComponent(start);

			NEW(doSurfaceScan); left := ButtonWidth + ButtonSpacer;
			doSurfaceScan.bounds.SetExtents(ButtonHeight, ButtonHeight);
			doSurfaceScan.bounds.SetLeft(left); doSurfaceScan.bounds.SetTop(0);
			doSurfaceScan.onClick.Add(CheckboxHandler); doSurfaceScan.SetCaption("");
			AddInternalComponent(doSurfaceScan);

			NEW(label); left := left + ButtonHeight + ButtonSpacer;
			label.bounds.SetExtents(70, ButtonHeight); label.bounds.SetLeft(left); label.bounds.SetTop(0);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString("Surface Scan"));
			AddInternalComponent(label);

			NEW(doCompareFats); left := left + 70 + ButtonSpacer;
			doCompareFats.bounds.SetExtents(ButtonHeight, ButtonHeight);
			doCompareFats.bounds.SetLeft(left); doCompareFats.bounds.SetTop(0);
			doCompareFats.onClick.Add(CheckboxHandler); doCompareFats.SetCaption("X");
			AddInternalComponent(doCompareFats);

			NEW(label); left := left + ButtonHeight + ButtonSpacer;
			label.bounds.SetExtents(80, ButtonHeight); label.bounds.SetLeft(left); label.bounds.SetTop(0);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString("Compare FATs"));
			AddInternalComponent(label);

			NEW(doLostClusters); left := left + 80 + ButtonSpacer;
			doLostClusters.bounds.SetExtents(ButtonHeight, ButtonHeight);
			doLostClusters.bounds.SetLeft(left); doLostClusters.bounds.SetTop(0);
			doLostClusters.onClick.Add(CheckboxHandler); doLostClusters.SetCaption("X");
			AddInternalComponent(doLostClusters);

			NEW(label); left := left + ButtonHeight + ButtonSpacer;
			label.bounds.SetExtents(100, ButtonHeight); label.bounds.SetLeft(left); label.bounds.SetTop(0);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString("Scan cluster chains"));
			AddInternalComponent(label);

			NEW(doWrite); left := left + 100 + ButtonSpacer;
			doWrite.bounds.SetExtents(ButtonHeight, ButtonHeight);
			doWrite.bounds.SetLeft(left); doWrite.bounds.SetTop(0);
			doWrite.onClick.Add(CheckboxHandler); doWrite.SetCaption("");
			AddInternalComponent(doWrite);

			NEW(label); left := left + ButtonHeight + ButtonSpacer;
			label.bounds.SetExtents(100, ButtonHeight); label.bounds.SetLeft(left); label.bounds.SetTop(0);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString("Correct Errors"));
			AddInternalComponent(label);
		END Init;

		PROCEDURE SelectionUpdated(selection : WMPartitionsComponents.Selection) : LONGINT;
		VAR result : LONGINT;
		BEGIN
			SELF.selection := selection;
			IF IsValid(selection) & (Disks.Valid IN selection.disk.table[selection.partition].flags) THEN
				IF PartitionsLib.IsFatType(selection.disk.table[selection.partition].type) THEN (* FAT Filesystems *)
					result := SelectionValid;
				ELSE (* only FAT file systems are supported *)
					result := SelectionInvalid;
				END;
			ELSE
				result := SelectionInvalid;
			END;
			RETURN result;
		END SelectionUpdated;

		PROCEDURE StartScan(sender, data : ANY);
		VAR scavenger : FATScavenger.FATScavenger;
		BEGIN
			IF IsValid(selection) & (PartitionsLib.IsFatType(selection.disk.table[selection.partition].type) OR selection.disk.isDiskette) THEN
				NEW(scavenger, selection.disk, selection.partition, NIL);
				scavenger.SetParameters(surfaceScan, compareFats, lostClusters, write);
				scavenger.SetStart;
				owner.UpdateStatusLabel(Strings.NewString("Scavenger started"));
			ELSE owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END StartScan;

		PROCEDURE CheckboxHandler(sender, data : ANY);
		VAR
			button : WMStandardComponents.Button;
			mark : BOOLEAN;
			ch : ARRAY 2 OF CHAR;
		BEGIN
			button := sender (WMStandardComponents.Button);
			IF button = doSurfaceScan THEN
				surfaceScan := ~surfaceScan; mark := surfaceScan;
			ELSIF button = doCompareFats THEN
				compareFats := ~compareFats; mark := compareFats;
			ELSIF button = doLostClusters THEN
				lostClusters := ~lostClusters; mark := lostClusters;
			ELSIF button = doWrite THEN
				write := ~write; mark := write;
			END;
			IF mark THEN ch := "X" ELSE ch := "" END;
			button.caption.Set(Strings.NewString(ch));
		END CheckboxHandler;

	END ScavengerPlugin;

TYPE

	(* Graphical front-end for DiskTests.Mod operations *)
	TestsPlugin = OBJECT (Plugin);
	VAR
		writeDataBtn, testPartitionBtn, verifyDataBtn, writeZerosBtn, benchmarkBtn  : WMStandardComponents.Button;

		PROCEDURE SelectionUpdated(selection : WMPartitionsComponents.Selection) : LONGINT;
		VAR result : LONGINT;
		BEGIN
			SELF.selection := selection;
			IF IsValid(selection) THEN result := SelectionValid;
			ELSE result := SelectionInvalid;
			END;
			RETURN result;
		END SelectionUpdated;

		PROCEDURE WriteTestData(sender, data : ANY);
		VAR
			testDataWriter : DiskTests.TestDataWriter;
			popup : PopupWindow; param : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) THEN
				NEW(param, 1);
				param[0].description := "SectorsPerTransfer"; param[0].type := ParInteger; param[0].width := 0;
				param[0].optional := FALSE; param[0].default := TRUE; param[0].resInteger := 1;
				NEW(popup, 220, 160, FALSE);
				popup.SetTextAsString("Writing test data to a partition will DESTROY ITS CONTENTS!!");
				popup.SetParameters("Write test data to", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					ASSERT(param[0].valid);
					NEW(testDataWriter, selection.disk, selection.partition, NIL);
					testDataWriter.SetParameters(param[0].resInteger);
					testDataWriter.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection Invalid"));
			END;
		END WriteTestData;

		PROCEDURE WriteZeros(sender, data : ANY);
		VAR
			zeroWriter : DiskTests.ZeroWriter;
			popup : PopupWindow; param : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) THEN
				NEW(param, 1);
				param[0].description := "SectorsPerTransfer"; param[0].type := ParInteger; param[0].width := 0;
				param[0].optional := FALSE; param[0].default := TRUE; param[0].resInteger := 1;
				NEW(popup, 220, 160, FALSE);
				popup.SetTextAsString("Writing zeros to the partition will DESTROY ITS CONTENTS!!");
				popup.SetParameters("Write zeros to ", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					ASSERT(param[0].valid);
					NEW(zeroWriter, selection.disk, selection.partition, NIL);
					zeroWriter.SetParameters(param[0].resInteger);
					zeroWriter.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection Invalid"));
			END;
		END WriteZeros;

		PROCEDURE TestPartition(sender, data : ANY);
		VAR
			diskTest : DiskTests.DiskTest;
			popup : PopupWindow; param : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) THEN
				NEW(param, 4);
				param[0].description := "Number of Tests"; param[0].type := ParInteger; param[0].width := 0;
				param[0].optional := FALSE; param[0].default := TRUE; param[0].resInteger := -1;
				param[1].description := "Max. Sectors per Transfer"; param[1].type := ParInteger; param[1].width := 0;
				param[1].optional := FALSE; param[1].default := TRUE; param[1].resInteger := 200;
				param[2].description := "Max. Offset into Client Buffer"; param[2].type := ParInteger; param[2].width := 0;
				param[2].optional := FALSE; param[2].default := TRUE; param[2].resInteger := 0;
				param[3].description := "Verify Test Data"; param[3].type := ParBoolean; param[3].width := 0;
				param[3].optional := FALSE; param[3].default := TRUE; param[3].resBoolean := FALSE;
				NEW(popup, 220, 260, FALSE);
				popup.SetTextAsString("To run the test endlessly, specified a negative number of tests. ");
				popup.SetParameters("Run DiskTest on partition ", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					NEW(diskTest, selection.disk, selection.partition, NIL);
					diskTest.SetParameters(TRUE, FALSE, param[3].resBoolean, param[0].resInteger, param[1].resInteger, param[2].resInteger);
					diskTest.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection Invalid"));
			END;
		END TestPartition;

		PROCEDURE VerifyTestData(sender, data : ANY);
		VAR
			testDataChecker : DiskTests.TestDataChecker;
			popup : PopupWindow; param : Parameters;
			res : LONGINT;
		BEGIN
			IF IsValid(selection) THEN
				NEW(param, 1);
				param[0].description := "SectorsPerTransfer"; param[0].type := ParInteger; param[0].width := 0;
				param[0].optional := FALSE; param[0].default := TRUE; param[0].resInteger := 1;
				NEW(popup, 220, 160, FALSE);
				popup.SetTextAsString("Verify test data");
				popup.SetParameters("Verify test data on", selection, param);
				popup.Popup(100, 100, res);
				IF res = ResOk THEN
					ASSERT(param[0].valid);
					NEW(testDataChecker, selection.disk, selection.partition, NIL);
					testDataChecker.SetParameters(param[0].resInteger);
					testDataChecker.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END VerifyTestData;

		PROCEDURE WriteK(k: LONGINT; VAR string: ARRAY OF CHAR);
		VAR suffix: ARRAY 3 OF CHAR;
		BEGIN
			IF k < 1024 THEN suffix := "B";
			ELSE k := k DIV 1024; suffix := "KB";
			END;
			Strings.IntToStr(k, string); Strings.Append(string, suffix);
		END WriteK;

		PROCEDURE BenchPartition(sender, data : ANY);
		VAR
			benchPartition : DiskBenchmark.DiskBench;
			popup : PopupWindow; param : Parameters;
			blocksizes : SET;
			i, blocksize, res : LONGINT;
			string : ARRAY 128 OF CHAR;
		BEGIN
			IF IsValid(selection) & (selection.disk.device # NIL) THEN
				NEW(popup, 300, 625, FALSE);
				popup.SetTextAsString("Benchmark Configuration");

				NEW(param, 21);
				param[0].description := "Perform Random Block Tests"; param[0].type := ParBoolean;
				param[0].optional := TRUE; param[0].width := 0; param[0].default := TRUE;  param[0].resBoolean := TRUE;

				param[1].description := "NbrOfBlock for random test"; param[1].type := ParInteger;
				param[1].optional := FALSE; param[1].width := 0; param[1].default := TRUE;  param[1].resInteger := 1000;

				param[2].description := "Perform Sequential Block Tests"; param[2].type := ParBoolean;
				param[2].optional := TRUE; param[2].width := 0; param[2].default := TRUE;  param[2].resBoolean := TRUE;

				param[3].description := "Perform Read Tests"; param[3].type := ParBoolean;
				param[3].optional := TRUE; param[3].width := 0; param[3].default := TRUE;  param[3].resBoolean := TRUE;

				param[4].description := "Perform Write Tests (DANGEROUS)"; param[4].type := ParBoolean;
				param[4].optional := TRUE; param[4].width := 0; param[4].default := TRUE;  param[4].resBoolean := FALSE;

				blocksize := 512;
				FOR i := 1 TO 16 DO
					WriteK(blocksize, string); Strings.Append(string, " Blocks");
					COPY(string, param[4+i].description);
					param[4+i].type := ParBoolean;
					param[4+i].optional := TRUE; param[4+i].width := 0; param[4+i].default := TRUE; param[4+i].resBoolean := TRUE;
					blocksize := blocksize * 2;
				END;

				popup.SetParameters("Partition Benchmark", selection, param);
				popup.Popup(100,100, res);
				IF res = ResOk THEN
					blocksizes := {};
					FOR i := 1 TO 16 DO
						IF param[4+i].resBoolean THEN INCL(blocksizes, i-1); END;
					END;
					NEW(benchPartition, selection.disk, selection.partition, NIL);
					benchPartition.SetParameters(param[0].resBoolean, param[2].resBoolean, param[3].resBoolean, param[4].resBoolean, param[1].resInteger, blocksizes);
					benchPartition.SetStart;
				END;
			ELSE
				owner.UpdateStatusLabel(Strings.NewString("Selection invalid"));
			END;
		END BenchPartition;

		PROCEDURE &Init*;
		VAR left : LONGINT;
		BEGIN
			Init^;
			(* upper row of buttons *)
			NEW(writeDataBtn); left := 0;
			writeDataBtn.bounds.SetExtents(ButtonWidth + 20, ButtonHeight); writeDataBtn.bounds.SetLeft(left); writeDataBtn.bounds.SetTop(0);
			writeDataBtn.onClick.Add(WriteTestData); writeDataBtn.SetCaption("Write Test Data");
			AddInternalComponent(writeDataBtn);

			NEW(testPartitionBtn); left := left + ButtonWidth + 20 + ButtonSpacer;
			testPartitionBtn.bounds.SetExtents(ButtonWidth + 20, ButtonHeight); testPartitionBtn.bounds.SetLeft(left);  testPartitionBtn.bounds.SetTop(0);
			testPartitionBtn.onClick.Add(TestPartition); testPartitionBtn.SetCaption("Test Partition");
			AddInternalComponent(testPartitionBtn);

			NEW(benchmarkBtn); left := left + ButtonWidth + 20 + ButtonSpacer;
			benchmarkBtn.bounds.SetExtents(ButtonWidth + 20, ButtonHeight); benchmarkBtn.bounds.SetLeft(left); benchmarkBtn.bounds.SetTop(0);
			benchmarkBtn.onClick.Add(BenchPartition); benchmarkBtn.SetCaption("Benchmark");
			AddInternalComponent(benchmarkBtn);

			(* 2nd row of buttons *)
			NEW(verifyDataBtn); left := 0;
			verifyDataBtn.bounds.SetExtents(ButtonWidth + 20, ButtonHeight); verifyDataBtn.bounds.SetLeft(left);  verifyDataBtn.bounds.SetTop(ButtonHeight + ButtonSpacer);
			verifyDataBtn.onClick.Add(VerifyTestData); verifyDataBtn.SetCaption("Verify Test Data");
			AddInternalComponent(verifyDataBtn);

			NEW(writeZerosBtn); left := left + ButtonWidth + 20 + ButtonSpacer;
			writeZerosBtn.bounds.SetExtents(ButtonWidth + 20, ButtonHeight); writeZerosBtn.bounds.SetLeft(left);  writeZerosBtn.bounds.SetTop(ButtonHeight + ButtonSpacer);
			writeZerosBtn.onClick.Add(WriteZeros); writeZerosBtn.SetCaption("Write Zeros");
			AddInternalComponent(writeZerosBtn);
		END Init;

	END TestsPlugin;

TYPE

	(** Simple text view window *)
	ReportWindow = OBJECT(WMComponents.FormWindow)
	VAR
		textView : WMTextView.TextView;

		PROCEDURE Show*;
		BEGIN
			WMWindowManager.AddWindow(SELF, 100, 100);
			manager := WMWindowManager.GetDefaultManager ();
			manager.SetFocus(SELF);
			SetTitle(WMWindowManager.NewString("  Operation Status Report"));
		END Show;

		PROCEDURE &New*(text : Texts.Text;  width, height : LONGINT; visible : BOOLEAN);
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			Init(width, height, visible); scaling := FALSE;

			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			panel.fillColor.Set(WMGraphics.White);

			NEW(textView); textView.alignment.Set(WMComponents.AlignClient);
			textView.isMultiLine.Set(TRUE); textView.showBorder.Set(FALSE);
			textView.alwaysShowCursor.Set(FALSE);
			textView.SetText(text);
			panel.AddContent(textView);

			SetContent(panel);
		END New;

	END ReportWindow;

TYPE

	(** Specifies a single parameter for the PopupWindow *)
	Parameter = RECORD
		description : ARRAY 32 OF CHAR;
		type : LONGINT; (* ParInteger, ParString *)
		resInteger : LONGINT;
		resString : ARRAY 32 OF CHAR;
		resBoolean : BOOLEAN;
		width : LONGINT; (* width of editor field *)
		valid : BOOLEAN; (* is the resInteger/resString value valid *)
		optional : BOOLEAN; (* Ok possible width filling this parameter *)
		default : BOOLEAN; (* if default is TRUE, the values of ResInteger/ResString is used as default value *)
	END;

	(** Parameters passed to PopupWindow via SetParameters() *)
	Parameters = POINTER TO ARRAY OF Parameter;

	(** Pop up window capable of getting inputs specified with Parameters *)
	PopupWindow = OBJECT(WMComponents.FormWindow)
	VAR
		okBtn, cancelBtn : WMStandardComponents.Button;
		parameterPanel : WMStandardComponents.GroupPanel;

		parameters : Parameters;
		editors : POINTER TO ARRAY OF WMEditors.TextField;
		boxes : POINTER TO ARRAY OF WMStandardComponents.Button;
		vc : POINTER TO ARRAY OF WMComponents.VisualComponent;

		operationName, diskpartString : Strings.String;

		textView : WMTextView.TextView;
		text : Texts.Text;
		attr : Texts.Attributes;

		result : LONGINT;

		width, height : LONGINT; (* of this popup window *)

		PROCEDURE &Init*(width, height : LONGINT; alpha : BOOLEAN);
		VAR panel, line : WMStandardComponents.Panel;
		BEGIN
			SELF.width := width; SELF.height := height; scaling := FALSE;
			Init^(width, height, alpha);

			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			IF ~UseSkinColors THEN panel.fillColor.Set(MarginColor); END;

			NEW(line); line.alignment.Set(WMComponents.AlignBottom);
			line.bounds.SetHeight(ButtonHeight);
			line.bearing.Set(WMRectangles.MakeRect(MarginH, MarginV, MarginH, MarginV));
			panel.AddInternalComponent(line);

			NEW(okBtn);
			okBtn.alignment.Set(WMComponents.AlignRight);
			okBtn.onClick.Add(Ok); okBtn.caption.Set(Strings.NewString("Ok"));
			okBtn.bearing.Set(WMRectangles.MakeRect(ButtonSpacer, 0, 0, 0));
			line.AddInternalComponent(okBtn);

			NEW(cancelBtn);
			cancelBtn.alignment.Set(WMComponents.AlignRight);
			cancelBtn.onClick.Add(Cancel); cancelBtn.caption.Set(Strings.NewString("Cancel"));
			line.AddInternalComponent(cancelBtn);

			NEW(parameterPanel); parameterPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddInternalComponent(parameterPanel);

			parameters := NIL; editors := NIL; boxes := NIL; vc := NIL;
			operationName := NIL; diskpartString := NIL;

			NEW(attr); attr.color := WMGraphics.White; attr.bgcolor := BackgroundColor;

			SetContent(panel);
		END Init;

		PROCEDURE SetText(text : Texts.Text);
		BEGIN
			SELF.text := text;
			IF (text # NIL) THEN
				text.AcquireWrite;
				text.SetAttributes(0, text.GetLength(), attr);
				text.ReleaseWrite;
			END;
		END SetText;

		(** Set text displayed by the PopupWindow as string *)
		PROCEDURE SetTextAsString(CONST string : ARRAY OF CHAR);
		BEGIN
			NEW(text); TextUtilities.StrToText(text, 0, string);
			text.AcquireWrite;
			text.SetAttributes(0, text.GetLength(), attr);
			text.ReleaseWrite;
		END SetTextAsString;

		(** Pass parameters *)
		PROCEDURE SetParameters(CONST operationName  : ARRAY OF CHAR; selection : PartitionsLib.Selection; VAR parameters : Parameters);
		VAR string, temp : ARRAY 32 OF CHAR;
		BEGIN
			SELF.operationName := Strings.NewString(operationName);
			string := ""; Strings.Append(string, selection.disk.device.name);
			Strings.IntToStr(selection.partition, temp); Strings.Append(string, "#"); Strings.Append(string, temp);
			diskpartString := Strings.NewString(string);
			SELF.parameters := parameters;
		END SetParameters;

		(** Show popup window at position (x,y); call is blocking; res = ResNone | ResCancel | ResOk *)
		PROCEDURE Popup(x, y : LONGINT;  VAR res : LONGINT);
		BEGIN
			BuildLayout;
			WMWindowManager.AddWindow (SELF, x, y);
			manager.SetFocus(SELF);
			IF (vc # NIL) & (LEN(vc) >= 2) THEN vc[LEN(vc)-1].SetFocus; END;
			result := ResNone;
			BEGIN {EXCLUSIVE} AWAIT(result # ResNone); END;
			res := result;
		END Popup;

		PROCEDURE BuildLayout;
		CONST MinSpacer = 5;
		VAR
			label, line : WMStandardComponents.Label;
			width, labelwidth : LONGINT;
			maxWidth, ignore : LONGINT;
			font : WMGraphics.Font;
			caption : ARRAY 128 OF CHAR;
			i : LONGINT;

			PROCEDURE SetFocusChain;
			VAR ref, lastRef, uid : Strings.String; nbr : ARRAY 16 OF CHAR; i : LONGINT;

				PROCEDURE GenRef(number : LONGINT) : Strings.String;
				VAR string : Strings.String; temp, nbr : ARRAY 16 OF CHAR;
				BEGIN
					temp := "&";
					Strings.IntToStr(number, nbr);
					Strings.Append(temp, nbr);
					string := Strings.NewString(temp);
					ASSERT(string # NIL);
					RETURN string;
				END GenRef;

			BEGIN
				ASSERT(vc # NIL);
				FOR i := 0 TO LEN(vc)-1 DO
					ASSERT(vc[i] # NIL);
					vc[i].needsTab.Set(FALSE);
					vc[i].takesFocus.Set(TRUE);
					Strings.IntToStr(i, nbr);
					uid := Strings.NewString(nbr);
					ref := GenRef(i);
					vc[i].uid.Set(uid);
					IF (i > 0) THEN
						vc[i-1].focusNext.Set(ref);
						vc[i].focusPrevious.Set(lastRef);
					END;
					lastRef := ref;
				END;
				vc[0].focusPrevious.Set(GenRef(LEN(vc)-1));
				vc[LEN(vc)-1].focusNext.Set(GenRef(0));
			END SetFocusChain;

		BEGIN
			caption := "";

			IF (operationName # NIL) THEN Strings.Append(caption, operationName^); Strings.Append(caption, " "); END;
			IF (diskpartString # NIL) THEN Strings.Append(caption, diskpartString^); END;

			SetTitle(Strings.NewString(caption));

			IF (parameters # NIL) THEN

				NEW(editors, LEN(parameters)); NEW(boxes, LEN(parameters));
				NEW(vc, LEN(parameters) + 2);

				(* look for the widest string *)
				NEW(label);
				font := label.GetFont(); maxWidth := 0;
				FOR i := 0 TO LEN(parameters) -1 DO
					font.GetStringSize(parameters[i].description, width, ignore);
					IF width > maxWidth THEN maxWidth := width; END;
				END;
				font.GetStringSize("[]", width, ignore);
				maxWidth := maxWidth + width;

				labelwidth := maxWidth + MinSpacer;

				FOR i := LEN(parameters)-1 TO 0 BY -1 DO

					NEW(line); line.alignment.Set(WMComponents.AlignBottom);
					line.bounds.SetHeight(ButtonHeight);
					line.bearing.Set(WMRectangles.MakeRect(0, MarginV, 0, 0));
					parameterPanel.AddContent(line);

					(* parameter description *)
					NEW(label); label.alignment.Set(WMComponents.AlignLeft);
					label.bounds.SetWidth(labelwidth);
					IF ~UseSkinColors THEN label.textColor.Set(WMGraphics.White); END;
					IF (parameters[i].optional) THEN
						caption := "["; Strings.AppendX(caption, parameters[i].description);
						Strings.AppendX(caption, "]");
						label.caption.Set(Strings.NewString(caption));
					ELSE
						label.caption.Set(Strings.NewString(parameters[i].description));
					END;
					line.AddInternalComponent(label);

					(* parameter input editor *)
					IF (parameters[i].type = ParInteger) OR (parameters[i].type = ParString) THEN
						NEW(editors[i]); vc[i] := editors[i];
						editors[i].alignment.Set(WMComponents.AlignClient);
						IF ~UseSkinColors THEN editors[i].fillColor.Set(WMGraphics.White); END;
						IF parameters[i].default THEN
							ASSERT((parameters[i].type = ParInteger) OR (parameters[i].type = ParString));
							IF parameters[i].type = ParInteger THEN
								Strings.IntToStr(parameters[i].resInteger, caption);
								editors[i].SetAsString(caption);
							ELSE (* ParString *)
								editors[i].SetAsString(parameters[i].resString);
							END;
						END;
						line.AddInternalComponent(editors[i]);
					ELSIF parameters[i].type = ParBoolean THEN
						NEW(boxes[i]); vc[i] := boxes[i];
						boxes[i].alignment.Set(WMComponents.AlignLeft);
						boxes[i].bounds.SetExtents(ButtonHeight, ButtonHeight);
						boxes[i].onClick.Add(CheckboxHandler);
						IF (parameters[i].default) & (parameters[i].resBoolean) THEN
							boxes[i].caption.Set(Strings.NewString("X"));
						ELSE
							boxes[i].caption.Set(Strings.NewString(""));
						END;
						line.AddInternalComponent(boxes[i]);
					ELSE
						HALT(99); (* Unsupported parameter type *)
					END;
					ASSERT(vc[i] # NIL);
				END;
				vc[LEN(parameters)] := cancelBtn;
				vc[LEN(parameters)+1] := okBtn;
			ELSE
				NEW(vc, 2); vc[0] := cancelBtn; vc[1] := okBtn;
			END;

			(* show PopupWindow text if there is any *)
			IF text # NIL THEN
				NEW(textView); textView.alignment.Set(WMComponents.AlignClient);
				textView.isMultiLine.Set(TRUE); textView.showBorder.Set(FALSE);
				textView.defaultTextColor.Set(WMGraphics.White);
				textView.alwaysShowCursor.Set(FALSE);
				textView.SetText(text);
				textView.takesFocus.Set(FALSE);
				parameterPanel.AddInternalComponent(textView);
			END;

			SetFocusChain;
			CSChanged;
			ASSERT((vc # NIL) & (LEN(vc) >= 2));
		END BuildLayout;

		PROCEDURE EvalParameters() : BOOLEAN;
		VAR  result : BOOLEAN; string : ARRAY 32 OF CHAR; temp : Strings.String; i : LONGINT;
		BEGIN
			IF parameters=NIL THEN result := TRUE;
			ELSE
				result := TRUE;
				FOR i := 0 TO LEN(parameters)-1 DO
					IF (parameters[i].type = ParString) OR (parameters[i].type = ParInteger) THEN
						editors[i].GetAsString(string);
						IF string # "" THEN
							parameters[i].valid := TRUE;
							IF parameters[i].type = ParInteger THEN
								Strings.StrToInt(string, parameters[i].resInteger);
							ELSIF parameters[i].type = ParString THEN
								parameters[i].resString := ""; Strings.Append(parameters[i].resString, string);
							END;
							editors[i].fillColor.Set(WMGraphics.White);
						ELSIF ~parameters[i].optional THEN
							editors[i].fillColor.Set(WMGraphics.Red);
							result := FALSE;
						END;
					ELSIF parameters[i].type = ParBoolean THEN
						temp := boxes[i].caption.Get();
						parameters[i].valid := TRUE;
						parameters[i].resBoolean := temp^ = "X";
					END;
				END;
			END;
			RETURN result;
		END EvalParameters;

		PROCEDURE CheckboxHandler(sender, data : ANY);
		VAR
			checkbox : WMStandardComponents.Button;
			string : Strings.String;
			i : LONGINT;
		BEGIN
			checkbox := sender (WMStandardComponents.Button);
			FOR i := 0 TO LEN(boxes)-1 DO
				IF boxes[i]=checkbox THEN
					string := checkbox.caption.Get();
					IF string^ = "X" THEN string := Strings.NewString(""); ELSE string := Strings.NewString("X"); END;
					checkbox.caption.Set(string);
					checkbox.Reset(NIL, NIL);
				END;
			END;
		END CheckboxHandler;

		PROCEDURE Ok(sender, data : ANY);
		BEGIN
			IF EvalParameters() THEN
				BEGIN {EXCLUSIVE} result := ResOk; END;
				Close^;
			ELSE
				CSChanged; (* force redraw *)
			END;
		END Ok;

		PROCEDURE Cancel(sender, data : ANY);
		BEGIN
			Close^; BEGIN {EXCLUSIVE} result := ResCancel; END;
		END Cancel;

		PROCEDURE Close;
		BEGIN
			Close^; BEGIN {EXCLUSIVE} result := ResCancel; END;
		END Close;

	END PopupWindow;

TYPE

	Window = OBJECT(WMComponents.FormWindow)
	VAR
		tabs : WMTabComponents.Tabs;
		tabList : ARRAY NofTabs OF WMTabComponents.Tab;
		tabPanels : ARRAY NofTabs OF WMComponents.VisualComponent;

		tabPanel : WMStandardComponents.Panel;
		curTabPanel : WMComponents.VisualComponent;
		curTab : WMTabComponents.Tab;

		partitionSelector : WMPartitionsComponents.PartitionSelector;
		operationSelector : WMPartitionsComponents.OperationSelector;

		operationspanel : WMStandardComponents.Panel; (* contains opScollBarX/Y, oppanel *)

		(* operation panel *)
		selectedPlugin : Plugin; (* currently selected plugin, NIL if no plugin is selected *)
		refreshBtn, showDetailsBtn : WMStandardComponents.Button;
		pluginPanel : WMStandardComponents.Panel; (* contains selectedPanel *)

		(* status bar *)
		statusLabel : WMStandardComponents.Label;

		width, height : LONGINT; (* caches "window size"; needed for correct update when downscaled *)

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR configuration : WMRestorable.XmlElement; scale, showDetails : BOOLEAN;
		BEGIN
			scale := FALSE; showDetails := TRUE;
			IF c # NIL THEN
				width := c.r - c.l; height := c.b - c.t;
				configuration := WMRestorable.GetElement(c, "Configuration");
				IF configuration # NIL THEN
					WMRestorable.LoadLongint(configuration, "Width", width);
					WMRestorable.LoadLongint(configuration, "Height", height);
					WMRestorable.LoadBoolean(configuration, "Details", showDetails);
					IF (width < WindowMinWidth) OR (height < WindowMinHeight) THEN
						(* First render window in real size and then scale it down to the size specified by the context *)
						scale := TRUE;
					END;
				END;
			ELSE
				width := DefaultWidth; height := DefaultHeight;
			END;
			Init(width, height, FALSE);

			SetTitle(WMWindowManager.NewString("Partition Tool"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMPartitions.png", TRUE));

			scaling := FALSE;

			SetContent(CreateForm());

			partitionSelector.showDetails.Set(showDetails);
			showDetailsBtn.SetPressed(showDetails);

			IF c # NIL THEN
				WMRestorable.AddByContext(SELF, c);
				IF scale THEN Resized(c.r - c.l, c.b - c.t); END;
			ELSE
				WMWindowManager.AddWindow (SELF, 100, 100);
				manager := WMWindowManager.GetDefaultManager ();
				manager.SetFocus(SELF);
			END;
			PartitionsLib.infobus.AddListener(CompletionHandler);
		END New;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel, upperpanel, lowerpanel, line : WMStandardComponents.Panel;
			operationPanel : WMStandardComponents.GroupPanel;
			resizer : WMStandardComponents.Resizer;
			plugin : Plugin;
			fsTools : FSToolsPlugin;
			partitions : PartitionsPlugin;
			bluebottle : A2Plugin;
			scavenger : ScavengerPlugin;
			tests : TestsPlugin;
			operations : OperationsPlugin;
			caption : ARRAY 32 OF CHAR;
			i : LONGINT;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);
			IF ~UseSkinColors THEN panel.fillColor.Set(MarginColor); END;

			NEW(line); line.alignment.Set(WMComponents.AlignBottom);
			IF ~UseSkinColors THEN line.fillColor.Set(StatusBarBgColor); END;
			line.bounds.SetHeight(StatusBarHeight);
			panel.AddContent(line);

			NEW(statusLabel); statusLabel.alignment.Set(WMComponents.AlignClient);
			statusLabel.bearing.Set(WMRectangles.MakeRect(10, 0, 0, 0));
			IF ~UseSkinColors THEN
				statusLabel.fillColor.Set(StatusBarBgColor);
				statusLabel.textColor.Set(WMGraphics.White);
			END;
			statusLabel.caption.Set(Strings.NewString(" Ready"));
			line.AddInternalComponent(statusLabel);

			NEW(operationPanel); operationPanel.alignment.Set(WMComponents.AlignBottom);
			operationPanel.bounds.SetHeight(90);
			panel.AddInternalComponent(operationPanel);

			NEW(line); line.alignment.Set(WMComponents.AlignTop);
			line.bounds.SetHeight(ButtonHeight);
			operationPanel.AddInternalComponent(line);

			NEW(showDetailsBtn); showDetailsBtn.alignment.Set(WMComponents.AlignRight);
			showDetailsBtn.bearing.Set(WMRectangles.MakeRect(ButtonSpacer, 0, 0, 0));
			showDetailsBtn.isToggle.Set(TRUE); showDetailsBtn.onClick.Add(ShowDetails);
			showDetailsBtn.caption.Set(Strings.NewString("Details"));
			line.AddInternalComponent(showDetailsBtn);

			NEW(refreshBtn); refreshBtn.alignment.Set(WMComponents.AlignRight);
			refreshBtn.bearing.Set(WMRectangles.MakeRect(ButtonSpacer, 0, 0, 0));
			refreshBtn.onClick.Add(Refresh); refreshBtn.caption.Set(Strings.NewString("Refresh"));
			line.AddInternalComponent(refreshBtn);

			NEW(tabs);  tabs.alignment.Set(WMComponents.AlignClient);
			tabs.clDefault.Set(WMGraphics.Black);
			tabs.clSelected.Set(0404040B0H);
			tabs.onSelectTab.Add(TabSelected);

			line.AddContent(tabs);

			NEW(tabPanel); tabPanel.alignment.Set(WMComponents.AlignClient);
			operationPanel.AddContent(tabPanel);

			FOR i := 0 TO NofTabs-1 DO
				CASE i OF
					|0: NEW(fsTools); plugin := fsTools; caption := "FSTools"; selectedPlugin := plugin;
					|1: NEW(partitions); plugin := partitions; caption := "Partitions";
					|2: NEW(scavenger); plugin := scavenger; caption := "Scavenger";
					|3: NEW(bluebottle); plugin := bluebottle; caption := "A2";
					|4: NEW(tests); plugin := tests; caption := "Testing";
					|5: NEW(operations); plugin := operations; caption := "Operations";
				END;
				plugin.owner := SELF;
				tabPanels[i] := plugin;
				tabPanels[i].alignment.Set(WMComponents.AlignClient);
				tabPanels[i].bearing.Set(WMRectangles.MakeRect(0, MarginV, 0, 0));
				tabPanels[i].visible.Set(FALSE);
				tabList[i] := tabs.NewTab(); tabs.AddTab(tabList[i]);
				tabs.SetTabCaption(tabList[i], Strings.NewString(caption));
				tabs.SetTabData(tabList[i], tabPanels[i]);
				tabPanel.AddContent(tabPanels[i]);
			END;

			curTabPanel := fsTools; curTab := tabList[0]; curTabPanel.visible.Set(TRUE);

			NEW(operationSelector); operationSelector.alignment.Set(WMComponents.AlignClient);

			ASSERT(operationSelector # NIL);
			operations.SetSelector(operationSelector);

			NEW(pluginPanel); pluginPanel.alignment.Set(WMComponents.AlignNone);
			operationPanel.AddInternalComponent(pluginPanel);

			NEW(upperpanel); upperpanel.alignment.Set(WMComponents.AlignClient);
			panel.AddInternalComponent(upperpanel);

			NEW(lowerpanel); lowerpanel.alignment.Set(WMComponents.AlignBottom);
			lowerpanel.bounds.SetHeight(45);
			upperpanel.AddInternalComponent(lowerpanel);

			NEW(resizer); resizer.bounds.SetHeight(4); resizer.alignment.Set(WMComponents.AlignTop);
			lowerpanel.AddInternalComponent(resizer);

			NEW(operationspanel);
			operationspanel.alignment.Set(WMComponents.AlignClient);
			operationspanel.AddInternalComponent(operationSelector);
			lowerpanel.AddInternalComponent(operationspanel);

			NEW(partitionSelector); partitionSelector.alignment.Set(WMComponents.AlignClient);
			partitionSelector.bearing.Set(WMRectangles.MakeRect(0, 0, 0, MarginV));
			partitionSelector.onSelection.Add(PartitionSelected);
			upperpanel.AddInternalComponent(partitionSelector);

			RETURN panel;
		END CreateForm;

		PROCEDURE Resized(width, height : LONGINT);
		BEGIN
			IF (width >= WindowMinWidth) & (height >= WindowMinHeight) THEN
				scaling := FALSE;
				SELF.width := width; SELF.height := height;
			ELSE
				scaling := TRUE;
			END;
			Resized^(width, height);
		END Resized;

		PROCEDURE TabSelected(sender, data : ANY);
		VAR tab : WMTabComponents.Tab; selection : WMPartitionsComponents.Selection;
		BEGIN
			IF (data # NIL) & (data IS WMTabComponents.Tab) THEN
				DisableUpdate;
				tab := data(WMTabComponents.Tab);
				IF (tab.data # NIL) & (tab.data IS WMComponents.VisualComponent) THEN
					curTabPanel.visible.Set(FALSE);
					curTab := tab;
					curTabPanel := tab.data(WMComponents.VisualComponent);
					curTabPanel.visible.Set(TRUE);
					tabPanel.Reset(SELF, NIL);
					tabPanel.AlignSubComponents;
				END;
				EnableUpdate;
				tabPanel.Invalidate;
				curTabPanel.Invalidate;
			END;
			ASSERT((curTabPanel # NIL) & (curTabPanel IS Plugin));
			selectedPlugin := curTabPanel (Plugin);
			selection := partitionSelector.GetSelection();
			UpdateSelection(selection);
		END TabSelected;

		PROCEDURE CompletionHandler(operation : PartitionsLib.Operation; CONST message : ARRAY OF CHAR);
		BEGIN
			UpdateStatusLabel(Strings.NewString(message));
		END CompletionHandler;

		(** Set string displayed by the Partition Viewer's status bar *)
		PROCEDURE UpdateStatusLabel(string : Strings.String);
		BEGIN
			statusLabel.caption.Set(string);
		END UpdateStatusLabel;

		PROCEDURE ShowDetails(sender, data : ANY);
		VAR showDetails : BOOLEAN;
		BEGIN
			showDetails := showDetailsBtn.GetPressed();
			partitionSelector.showDetails.Set(showDetails);
		END ShowDetails;

		PROCEDURE Refresh(sender, data : ANY);
		BEGIN
			PartitionsLib.diskModel.Update;
		END Refresh;

		PROCEDURE WheelMove(dz : LONGINT);
		BEGIN
			partitionSelector.WheelMove(dz);
		END WheelMove;

		PROCEDURE PartitionSelected(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.PartitionSelected, sender, data);
			ELSIF (data # NIL) & (data IS WMPartitionsComponents.SelectionWrapper) THEN
				UpdateSelection(data(WMPartitionsComponents.SelectionWrapper).selection);
			END;
		END PartitionSelected;

		(** Update Layout & Contents *)
		PROCEDURE UpdateContent*;
		BEGIN
			partitionSelector.Synchronize;
		END UpdateContent;

		PROCEDURE UpdateSelection(selection : WMPartitionsComponents.Selection);
		VAR caption, temp : ARRAY 128 OF CHAR; res : LONGINT;
		BEGIN
			caption := "";

			IF ((selection.disk.device = NIL) OR (selection.partition = -1)) THEN (* selection: none *)
				Strings.Append(caption, "n/a");
			ELSE
				Strings.Append(caption, selection.disk.device.name); Strings.Append(caption, "#");
				Strings.IntToStr(selection.partition, temp); Strings.Append(caption, temp);
			END;

			IF selectedPlugin # NIL THEN
				res := selectedPlugin.SelectionUpdated(selection);
			END;
		END UpdateSelection;

		PROCEDURE Close;
		BEGIN
			Close^;
			PartitionsLib.infobus.RemoveListener(CompletionHandler);
			window := NIL;
		END Close;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		VAR configuration : WMRestorable.XmlElement;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS WMRestorable.Storage) THEN
					NEW(configuration); configuration.SetName("Configuration");
					WMRestorable.StoreLongint(configuration, "Width", width);
					WMRestorable.StoreLongint(configuration, "Height", height);
					WMRestorable.StoreBoolean(configuration, "Details", showDetailsBtn.GetPressed());
					x.ext(WMRestorable.Storage).Add("PartitionTool", "Restore", SELF, configuration);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

TYPE

	(* This is a special case plugin. It provides access to disk operations (PartitionsLib.Operation) which are registered at the disk
	 * operation manager (PartitionsLib.OperationManager).
	 *)
	OperationsPlugin = OBJECT(Plugin);
	VAR
		abort, remove, showerrors : WMStandardComponents.Button;
		finished, all, selected : WMStandardComponents.Button; (* check boxes *)
		removeMode : LONGINT; (* RemoveSelected | RemoveFinished | RemoveAll *)
		info : WMStandardComponents.Label;

		selector : WMPartitionsComponents.OperationSelector;

		PROCEDURE &Init*;
		VAR left : LONGINT; label : WMStandardComponents.Label;
		BEGIN
			Init^;

			NEW(abort); left := 0;
			abort.bounds.SetExtents(ButtonWidth, ButtonHeight); abort.bounds.SetLeft(left); abort.bounds.SetTop(0);
			abort.onClick.Add(Abort); abort.SetCaption("Abort");
			AddInternalComponent(abort);

			NEW(showerrors); left := left + ButtonWidth + ButtonSpacer;
			showerrors.bounds.SetExtents(ButtonWidth, ButtonHeight); showerrors.bounds.SetLeft(left); showerrors.bounds.SetTop(0);
			showerrors.onClick.Add(Showerrors); showerrors.SetCaption("Report");
			AddInternalComponent(showerrors);

			NEW(remove); left := left + ButtonWidth + ButtonSpacer;
			remove.bounds.SetExtents(ButtonWidth, ButtonHeight); remove.bounds.SetLeft(left); remove.bounds.SetTop(0);
			remove.onClick.Add(Remove); remove.SetCaption("Remove");
			AddInternalComponent(remove);

			(* check boxes *)
			removeMode := RemoveSelected;

			NEW(selected); left := left + ButtonWidth + ButtonSpacer;
			selected.bounds.SetExtents(ButtonHeight, ButtonHeight); selected.bounds.SetLeft(left); selected.bounds.SetTop(0);
			selected.onClick.Add(CheckBoxes); selected.caption.Set(Strings.NewString("X"));
			AddInternalComponent(selected);

			NEW(label); left := left + ButtonHeight + ButtonSpacer;
			label.bounds.SetExtents(50, ButtonHeight); label.bounds.SetLeft(left); label.bounds.SetTop(0);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString("Selected"));
			AddInternalComponent(label);

			NEW(finished); left := left + 50 + ButtonSpacer;
			finished.bounds.SetExtents(ButtonHeight, ButtonHeight); finished.bounds.SetLeft(left); finished.bounds.SetTop(0);
			finished.onClick.Add(CheckBoxes); finished.caption.Set(Strings.NewString(""));
			AddInternalComponent(finished);

			NEW(label); left := left + ButtonHeight + ButtonSpacer;
			label.bounds.SetExtents(50, ButtonHeight); label.bounds.SetLeft(left); label.bounds.SetTop(0);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString("Finished"));
			AddInternalComponent(label);

			NEW(all); left := left + 50 + ButtonSpacer;
			all.bounds.SetExtents(ButtonHeight, ButtonHeight); all.bounds.SetLeft(left); all.bounds.SetTop(0);
			all.onClick.Add(CheckBoxes); all.caption.Set(Strings.NewString(""));
			AddInternalComponent(all);

			NEW(label); left := left + ButtonHeight + ButtonSpacer;
			label.bounds.SetExtents(50, ButtonHeight); label.bounds.SetLeft(left); label.bounds.SetTop(0);
			IF ~UseSkinColors THEN label.fillColor.Set(BackgroundColor); label.textColor.Set(WMGraphics.White); END;
			label.caption.Set(Strings.NewString("All"));
			AddInternalComponent(label);

			NEW(info);
			info.bounds.SetLeft(0); info.bounds.SetTop(ButtonHeight + ButtonSpacer);
			IF ~UseSkinColors THEN info.fillColor.Set(BackgroundColor); info.textColor.Set(WMGraphics.White); END;
			info.caption.Set(Strings.NewString(" Selected operation: none"));
			AddInternalComponent(info);

			selector := NIL;
		END Init;

		PROCEDURE SetSelector(selector : WMPartitionsComponents.OperationSelector);
		BEGIN
			Acquire;
			SELF.selector := selector;
			selector.onSelection.Add(OnOperationSelected);
			UpdateInfoLabel(GetSelectedOperation());
			Release;
		END SetSelector;

		PROCEDURE GetSelectedOperation() : WMPartitionsComponents.Operation;
		VAR operation : WMPartitionsComponents.Operation;
		BEGIN
			Acquire;
			IF (selector # NIL) THEN operation := selector.GetSelection();
			ELSE operation := NIL;
			END;
			Release;
			RETURN operation;
		END GetSelectedOperation;

		PROCEDURE OnOperationSelected(sender, data : ANY);
		VAR operation : WMPartitionsComponents.Operation;
		BEGIN
			IF (data # NIL) & (data IS WMPartitionsComponents.OperationWrapper) THEN
				operation := data(WMPartitionsComponents.OperationWrapper).operation;
				UpdateInfoLabel(operation);
			END;
		END OnOperationSelected;

		PROCEDURE UpdateInfoLabel(operation : WMPartitionsComponents.Operation);
		VAR w : Streams.StringWriter; string : ARRAY 256 OF CHAR;
		BEGIN
			IF (operation # NIL) THEN
				NEW(w, LEN(string));
				w.String(" Selected operation: "); w.String("UID "); w.Int(operation.uid, 0); w.String(": ");
				w.String(operation.name); w.String(" ("); w.String(operation.desc); w.String(")");
				w.Get(string);
				info.caption.Set(Strings.NewString(string));
			ELSE
				info.caption.Set(Strings.NewString(" Selected operation: none"));
			END;
		END UpdateInfoLabel;

		PROCEDURE CheckBoxes(sender, data : ANY);
		VAR button : WMStandardComponents.Button;
		BEGIN
			button := sender (WMStandardComponents.Button);

			(* clear all check boxes *)
			selected.caption.Set(Strings.NewString(""));
			finished.caption.Set(Strings.NewString(""));
			all.caption.Set(Strings.NewString(""));

			IF button = selected THEN
				removeMode := RemoveSelected;
				selected.caption.Set(Strings.NewString("X"));
			ELSIF button = finished THEN
				removeMode := RemoveFinished;
				finished.caption.Set(Strings.NewString("X"));
			ELSIF button = all THEN
				removeMode := RemoveAll;
				all.caption.Set(Strings.NewString("X"));
			ELSE
				HALT(399);
			END;
		END CheckBoxes;

		PROCEDURE Resized;
		BEGIN
			Resized^;
			info.bounds.SetExtents(bounds.GetWidth(), ButtonHeight);
		END Resized;

		(* we don't care about which disk is currently selected *)
		PROCEDURE SelectionUpdated(selection : WMPartitionsComponents.Selection): LONGINT;
		VAR selector : WMPartitionsComponents.OperationSelector; operation : WMPartitionsComponents.Operation;
		BEGIN
			selector := SELF.selector;
			IF (selector # NIL) THEN
				operation := selector.GetSelection();
			ELSE
				operation := NIL;
			END;
			UpdateInfoLabel(operation);
			RETURN SelectionNotSupported;
		END SelectionUpdated;

		PROCEDURE Abort(sender, data : ANY);
		VAR selectedOperation : WMPartitionsComponents.Operation; result : ARRAY 256 OF CHAR; temp : ARRAY 10 OF CHAR;
		BEGIN
			selectedOperation := GetSelectedOperation();
			IF selectedOperation # NIL THEN
				selectedOperation.Abort;
				result := "UID ";
				Strings.IntToStr(selectedOperation.uid, temp); Strings.Append(result, temp);
				Strings.Append(result, " : "); Strings.Append(result, "Operation aborted");
			ELSE
				result := "No operation selected";
			END;
			owner.UpdateStatusLabel(Strings.NewString(result));
		END Abort;

		PROCEDURE Remove(sender, data : ANY);
		VAR selectedOperation : WMPartitionsComponents.Operation; result : ARRAY 256 OF CHAR; temp : ARRAY 10 OF CHAR; num : LONGINT;
		BEGIN
			ASSERT(PartitionsLib.operations # NIL);
			selectedOperation := GetSelectedOperation();
			IF removeMode = RemoveSelected THEN
				IF selectedOperation # NIL THEN
					result := "UID ";
					Strings.IntToStr(selectedOperation.uid, temp); Strings.Append(result, temp);
					Strings.Append(result, " : "); Strings.Append(result, "Operation removed");
					IF PartitionsLib.operations.Remove(selectedOperation) THEN
						result := "UID ";
						Strings.IntToStr(selectedOperation.uid, temp); Strings.Append(result, temp);
						Strings.Append(result, " : "); Strings.Append(result, "Operation removed");
						selectedOperation := NIL;
						info.caption.Set(Strings.NewString(" Selected operation: none"));
					ELSE
						result := "Could not remove operation";
					END;
				ELSE
					result := "No operation selected";
				END;
			ELSIF removeMode = RemoveFinished THEN
				num := PartitionsLib.operations.RemoveAll(TRUE);
				Strings.IntToStr(num, temp);
				result := ""; Strings.Append(result, temp); Strings.Append(result, " finished operations removed");
				selectedOperation := NIL;
				info.caption.Set(Strings.NewString(" Selected operation: none"));
			ELSIF removeMode = RemoveAll THEN
				num := PartitionsLib.operations.RemoveAll(FALSE);
				Strings.IntToStr(num, temp);
				result := ""; Strings.Append(result, temp); Strings.Append(result, " operations removed");
				selectedOperation := NIL;
				info.caption.Set(Strings.NewString(" Selected operation: none"));
			ELSE
				HALT(398);
			END;
			owner.UpdateStatusLabel(Strings.NewString(result));
		END Remove;

		PROCEDURE Showerrors(sender, data : ANY);
		VAR
			selectedOperation : WMPartitionsComponents.Operation;
			text : Texts.Text; reportWindow : ReportWindow; result : ARRAY 256 OF CHAR; temp : ARRAY 10 OF CHAR;
		BEGIN
			selectedOperation := owner.operationSelector.GetSelection();
			IF selectedOperation # NIL THEN
				result := "UID ";
				Strings.IntToStr(selectedOperation.uid, temp); Strings.Append(result, temp);
				Strings.Append(result, " : "); Strings.Append(result, "Showing status report");
				text := selectedOperation.GetReport(TRUE);
				NEW(reportWindow, text, 500, 200, FALSE);
				reportWindow.Show();
			ELSE
				result := "No operation selected";
			END;
			owner.UpdateStatusLabel(Strings.NewString(result));
		END Showerrors;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			Acquire;
			IF (selector # NIL) THEN selector.onSelection.Remove(OnOperationSelected); END;
			Release;
		END Finalize;

	END OperationsPlugin;

VAR
	window : Window;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	IF window # NIL THEN window.Close; window := NIL; END;
END Cleanup;

PROCEDURE Open*;
BEGIN {EXCLUSIVE}
	IF window = NIL THEN
		NEW(window, NIL);
	ELSE
		window.manager.SetFocus(window);
		window.manager.ToFront(window);
	END;
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
BEGIN
	NEW(window, context);
END Restore;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMPartitions.

WMPartitions.Open ~

SystemTools.Free WMPartitions WMPartitionsComponents  ~

PC.Compile \s PartitionsLib.Mod Partitions.Mod FATScavenger.Mod DiskBenchmark.Mod DiskTests.Mod WMPartitionsComponents.Mod WMPartitions.Mod ~

SystemTools.FreeDownTo WMPartitions ~