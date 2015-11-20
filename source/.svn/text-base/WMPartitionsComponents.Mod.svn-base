MODULE WMPartitionsComponents; (** AUTHOR "staubesv"; PURPOSE "Partition view & selection componet"; *)

IMPORT
	AosDisks := Disks, PartitionsLib, Strings, Kernel,
	WMWindowManager,
	WMGraphics, WMGraphicUtilities, WMProperties, WMEvents, XML, WMComponents, WMStandardComponents, WMGrids, WMStringGrids;

CONST

	MainPanelMarginH = 5 ;
	MainPanelMarginV = 5 ;

	(* BevelPanel *)
	BevelBorderWidth = 2;

	(* the DiskOverviewPanel contains the DiskPanels & Grids *)
	DiskOverviewPanelMarginH = 7;
	DiskOverviewPanelMarginV = 7;
	DiskOverviewTableColumns = 6;

	(* DiskPanels are graphical representations of disks *)
	DiskPanelHeight = 40;
	DiskPanelMarginH = 5;
	DiskPanelMarginV = 5;
	DiskPanelSpacer = 5; (* spacer between partitions *)
	PanelMinWidth = 10; (* minimum width of the graphical representation of a partition *)
	LabelHeight = 18;
	LabelTxtColor = WMGraphics.Black;
	GridMinSpacerV = 2;
	GridMinSpacerH = 2;

	(* speed of scrolling *)
	Multiplier = 30;

	(* active object states *)
	Initializing = 0;
	Running = 1;
	Terminating = 2;
	Terminated = 3;

TYPE

	NoWheelGrid* = OBJECT(WMStringGrids.StringGrid);
		PROCEDURE WheelMove(dz : LONGINT); (* do nothing *) END WheelMove;
	END NoWheelGrid;

	BevelPanel* = OBJECT(WMStandardComponents.Panel);

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		BEGIN
			IF ~visible.Get() THEN RETURN END;
			Acquire;
			WMGraphicUtilities.DrawBevelPanel(canvas, GetClientRect(), BevelBorderWidth, TRUE, fillColor.Get(), 0 );
			Release;
		END DrawBackground;

	END BevelPanel;

TYPE

	Disk = RECORD (PartitionsLib.Disk);
		panel : BevelPanel; (* disk panel: contains all other fields *)
		label : WMStandardComponents.Label;
		buttons : POINTER TO ARRAY OF WMStandardComponents.Button; (* references to the partition buttons; *)
		mapping : POINTER TO ARRAY OF LONGINT; (* maps buttons[i] to correctly ordered partition number *)
		vtable : AosDisks.PartitionTable; (* virtual partition table (order different to disk.table, only used for graphical representation *)
		grid, titlegrid : NoWheelGrid; (* reference to grid (table); *)
	END;

	Disks = POINTER TO ARRAY OF Disk; (* no devices when NIL *)

TYPE

	DiskModel = OBJECT
	VAR
		disks : Disks;
		diskmodel : PartitionsLib.DisksModel;

		locked : BOOLEAN; (* Access via Acquire/Release only *)

		PROCEDURE Acquire;
		BEGIN {EXCLUSIVE}
			AWAIT(locked = FALSE);
			locked := TRUE;
		END Acquire;

		PROCEDURE Release;
		BEGIN {EXCLUSIVE}
			locked := FALSE;
		END Release;

		PROCEDURE IsLocked() : BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN locked;
		END IsLocked;

		(** Synchronize to PartitionsLib.DiskModel.
		 * force: Force the latter being updated
		 * disk: Just update this disk
		 * diskValid: disk parameter valid?
		 *)
		PROCEDURE Synchronize;
		VAR i : LONGINT;
		BEGIN (* diskModel must be locked *)
			diskmodel.Acquire;
			IF (diskmodel.disks # NIL) THEN
				NEW(disks, LEN(diskmodel.disks));
				FOR i := 0 TO LEN(disks)-1 DO
					(* copy information from disk model *)
					disks[i].device := diskmodel.disks[i].device;
					disks[i].isDiskette := diskmodel.disks[i].isDiskette;
					disks[i].table := diskmodel.disks[i].table;
					disks[i].size := diskmodel.disks[i].size; disks[i].res := diskmodel.disks[i].res;
					disks[i].geo := diskmodel.disks[i].geo; disks[i].gres := diskmodel.disks[i].gres;
					disks[i].fs := diskmodel.disks[i].fs;
				END;
			ELSE
				disks := NIL;
			END;
			diskmodel.Release;
		END Synchronize;

		PROCEDURE &Init*(model : PartitionsLib.DisksModel);
		BEGIN
			ASSERT(model # NIL);
			SELF.diskmodel := model;
		END Init;

	END DiskModel;

TYPE

	Selection* = PartitionsLib.Selection;

	SelectionWrapper* = OBJECT
	VAR
		selection- : PartitionsLib.Selection;
	END SelectionWrapper;

TYPE

	PartitionSelector* = OBJECT(WMComponents.VisualComponent)
	VAR
		(** Show detailed textual disk information? (default = FALSE) *)
		showDetails- : WMProperties.BooleanProperty;

		(** Show disk geometry information in title? (default = FALSE) *)
		showDiskGeometry- : WMProperties.BooleanProperty;

		(** Generates an event whenever the user selects a partition *)
		onSelection- : WMEvents.EventSource;

		(** use fillColor property for overall background of the component *)
		clSelected-, clBackground- : WMProperties.ColorProperty;

		(* Internal fields *)
		model : DiskModel;
		selection : Selection;

		diskOverviewScrollPanel : WMStandardComponents.Panel;
		diskOverviewPanel : WMStandardComponents.Panel;

		scrollbarX, scrollbarY : WMStandardComponents.Scrollbar;
		scrollX, scrollY : LONGINT; (* current position of scrollbars *)

		titleGrid : NoWheelGrid; (* prototype; for layouting only *)
		maxWidths : ARRAY DiskOverviewTableColumns OF LONGINT; (* maximum cell widths per column*)
		maxHeight : LONGINT; (* maximum height of test *)
		minWidth, minHeight : LONGINT; (* of the diskoverview panel *)

		firstAlign : BOOLEAN;

		PROCEDURE &Init*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			Init^;
			SetNameAsString(StrPartitionSelector);
			SetGenerator("WMPartitionsComponents.GenPartitionSelector");
			firstAlign := TRUE;

			NEW(showDetails, PrototypeShowDetails, NIL, NIL); properties.Add(showDetails);
			NEW(showDiskGeometry, PrototypeShowDiskGeometry, NIL, NIL); properties.Add(showDiskGeometry);
			NEW(clSelected, PrototypeClSelected, NIL, NIL); properties.Add(clSelected);
			NEW(clBackground, PrototypeClBackground, NIL, NIL); properties.Add(clBackground);

			NEW(onSelection, SELF, Strings.NewString("onSelection"), Strings.NewString("Generates an event when a disk is selected"),
				SELF.StringToCompCommand); events.Add(onSelection);

			vc := CreateContent();
			AddInternalComponent(vc);
			PartitionsLib.diskModel.onChanged.Add(DiskEventHandler);
		END Init;

		PROCEDURE GetSelection*() : Selection;
		VAR s : Selection;
		BEGIN
			model.Acquire;
			s := selection;
			model.Release;
			RETURN s;
		END GetSelection;

		PROCEDURE ClearSelection*;
		BEGIN
			model.Acquire;
			UpdateSelection(-1, -1);
			model.Release;
		END ClearSelection;

		PROCEDURE Synchronize*;
		BEGIN
			DiskEventHandler(NIL, NIL);
		END Synchronize;

		PROCEDURE AlignSubComponents;
		BEGIN
			AlignSubComponents^;
			IF firstAlign THEN
				(* When the component is created, layouting will be incorrect since it's depended on the
				not yet known size of the component. The first time the component is visible, Resized is not
				called... therefore we do the layouting here. *)
				firstAlign := FALSE;
				model.Acquire;
				UpdateLayout(bounds.GetWidth(), bounds.GetHeight(), FALSE);
				model.Release;
			END;
		END AlignSubComponents;

		PROCEDURE Resized;
		BEGIN
			model.Acquire;
			UpdateLayout(bounds.GetWidth(), bounds.GetHeight(), FALSE);
			model.Release;
			Resized^;
		END Resized;

		PROCEDURE CreateContent() : WMComponents.VisualComponent;
		VAR noDisksLabel : WMStandardComponents.Label; i : LONGINT;
		BEGIN
			titleGrid := BuildTitleGrid();

			NEW(model, PartitionsLib.diskModel);
			model.Acquire;
			model.Synchronize;

			NEW(diskOverviewPanel);

			IF model.disks # NIL THEN
				BuildSkeleton;
				UpdateDiskGrids;
				FOR i := 0 TO LEN(model.disks)-1 DO diskOverviewPanel.AddInternalComponent(BuildDiskPanel(model.disks[i])); END;
			ELSE
				NEW(noDisksLabel);
				noDisksLabel.alignment.Set(WMComponents.AlignClient);
				noDisksLabel.alignV.Set(WMGraphics.AlignCenter); noDisksLabel.alignH.Set(WMGraphics.AlignCenter);
				noDisksLabel.caption.SetAOC("No Disks");
				diskOverviewPanel.AddInternalComponent(noDisksLabel);
			END;

			(* build & add the diskoverview panel *)
			NEW(diskOverviewScrollPanel);
			diskOverviewScrollPanel.alignment.Set(WMComponents.AlignClient);
			diskOverviewPanel.bounds.SetTop(0);
			diskOverviewScrollPanel.AddInternalComponent(diskOverviewPanel);

			NEW(scrollbarY);
			scrollbarY.vertical.Set(TRUE); scrollbarY.alignment.Set(WMComponents.AlignRight);
			scrollbarY.min.Set(0); scrollbarY.onPositionChanged.Add(ScrollY);
			diskOverviewScrollPanel.AddInternalComponent(scrollbarY);

			NEW(scrollbarX);
			scrollbarX.vertical.Set(FALSE); scrollbarX.alignment.Set(WMComponents.AlignBottom);
			scrollbarX.min.Set(0); scrollbarX.onPositionChanged.Add(ScrollX);
			diskOverviewScrollPanel.AddInternalComponent(scrollbarX);

			UpdateSelection(-1, -1);
			UpdateLayout(bounds.GetWidth(), bounds.GetHeight(), TRUE);
			model.Release;

			RETURN diskOverviewScrollPanel;
		END CreateContent;

		PROCEDURE ScrollY(sender, data : ANY);
		VAR y : WMProperties.Int32Property;
		BEGIN
			IF data # NIL THEN y := data (WMProperties.Int32Property); scrollY := y.Get(); END;
			diskOverviewPanel.bounds.SetTop(-scrollY);
		END ScrollY;

		PROCEDURE ScrollX(sender, data : ANY);
		VAR x : WMProperties.Int32Property;
		BEGIN
			IF data # NIL THEN x := data (WMProperties.Int32Property); scrollX := x.Get(); END;
			diskOverviewPanel.bounds.SetLeft(-scrollX);
		END ScrollX;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			PartitionsLib.diskModel.onChanged.Remove(DiskEventHandler);
		END Finalize;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = showDetails) OR (property = showDiskGeometry) OR
				(property = clSelected) OR (property = clBackground) THEN
				scrollbarY.pos.Set(0); scrollY := 0;
				model.Acquire;
				UpdateLayout(bounds.GetWidth(), bounds.GetHeight(), FALSE);
				model.Release;
				diskOverviewPanel.bounds.SetTop(0);
				Invalidate;
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE GridClicked(sender, x : ANY);
		VAR ignore, row, i : LONGINT; grid : NoWheelGrid;
		BEGIN
			grid := sender (NoWheelGrid);
			grid.GetSelection(ignore, row, ignore, ignore);
			model.Acquire;
			i := 0;
			LOOP
				IF model.disks[i].grid = grid THEN UpdateSelection(i, row); EXIT END;
				INC(i); IF i >= LEN(model.disks) THEN EXIT; END;
			END;
			model.Release;
		END GridClicked;

		PROCEDURE UpdateDiskOverview(disk : Disk;  top : LONGINT; updateContent : BOOLEAN): WMStandardComponents.Panel;
		VAR
			height : LONGINT;
			msg : ARRAY 32 OF CHAR;
			(* updateContent variables *)
			dev : AosDisks.Device;
			string : Strings.String;
			caption, temp : ARRAY 256 OF CHAR;
		BEGIN
			ASSERT(model.IsLocked());
			ASSERT(disk.panel # NIL);
			disk.panel.bounds.SetExtents(diskOverviewPanel.bounds.GetWidth() - 2*MainPanelMarginH , height);
			disk.panel.bounds.SetLeft(MainPanelMarginH); disk.panel.bounds.SetTop(top);
			disk.panel.fillColor.Set(clBackground.Get());

			disk.label.bounds.SetExtents(disk.panel.bounds.GetWidth() - 2*DiskOverviewPanelMarginH, LabelHeight);
			disk.label.fillColor.Set(clBackground.Get());
			disk.label.bounds.SetLeft(DiskOverviewPanelMarginH); disk.label.bounds.SetTop(DiskOverviewPanelMarginV);

			IF updateContent THEN
				ASSERT(disk.device # NIL ); dev := disk.device;
				Strings.Append(caption, dev.name); Strings.Append(caption, " ("); Strings.Append(caption, dev.desc); Strings.Append(caption, ")");
				IF AosDisks.ReadOnly IN dev.flags THEN Strings.Append(caption, ", readonly"); END;
				IF AosDisks.Removable IN dev.flags THEN Strings.Append(caption, ", removable"); END;
			END;

			IF (disk.table # NIL) THEN

				IF updateContent THEN
					Strings.Append(caption,", Size: " );
					IF disk.res = AosDisks.Ok THEN
						string := GetSizeString(disk.size, dev.blockSize);
					ELSE
						string := Strings.NewString("GetSize Error");
					END;
					Strings.Append(caption, string^);
					Strings.IntToStr(dev.openCount, temp); Strings.Append(caption, ", Open count: "); Strings.Append(caption, temp);

					IF showDiskGeometry.Get() THEN
						IF disk.gres # AosDisks.MediaMissing THEN
							Strings.Append(caption, ", CHS: ");
							IF disk.gres = AosDisks.Ok THEN
								Strings.IntToStr(disk.geo.cyls, temp); Strings.Append(caption, temp); Strings.Append(caption, "x");
								Strings.IntToStr(disk.geo.hds, temp); Strings.Append(caption, temp); Strings.Append(caption, "x");
								Strings.IntToStr(disk.geo.spt, temp); Strings.Append(caption, temp);
							ELSE
								PartitionsLib.GetErrorMsg("Unknown", disk.gres, temp); Strings.Append(caption, temp);
							END;
						END;
					END;

					disk.label.caption.Set(Strings.NewString(caption));
				END;

				UpdateDiskPanel(disk);

				height :=  2*DiskOverviewPanelMarginV + LabelHeight + DiskPanelHeight;

				IF showDetails.Get() & (disk.grid#NIL) THEN
	 			  	ASSERT(disk.titlegrid#NIL);
					disk.titlegrid.bounds.SetLeft(DiskOverviewPanelMarginH); disk.titlegrid.bounds.SetTop(height);
					SetGridBounds(disk.titlegrid);
					height := height + disk.titlegrid.bounds.GetHeight();
					disk.grid.bounds.SetLeft(DiskOverviewPanelMarginH); disk.grid.bounds.SetTop(height);
					SetGridBounds(disk.grid);
					height := height + disk.grid.bounds.GetHeight() + DiskOverviewPanelMarginV;
					disk.grid.visible.Set(TRUE);
					disk.titlegrid.visible.Set(TRUE);
				ELSIF disk.grid # NIL THEN
					disk.grid.visible.Set(FALSE);
					disk.titlegrid.visible.Set(FALSE);
				END;
				disk.panel.bounds.SetExtents(diskOverviewPanel.bounds.GetWidth() - 2*MainPanelMarginH , height);
			ELSE
				IF updateContent THEN
					IF  disk.res = AosDisks.MediaMissing THEN
						msg := "No Media";
					ELSE
						Strings.IntToStr(disk.res, temp);
						msg := "Error: "; Strings.Append(msg, temp);
					END;
					disk.label.caption.Set(Strings.NewString(caption));
					disk.buttons[0].caption.Set(Strings.NewString(msg));
				END;

				(* update empty disk panel (no partition table) *)
				disk.buttons[0].bounds.SetExtents(diskOverviewPanel.bounds.GetWidth() - 2*MainPanelMarginH - 2*DiskOverviewPanelMarginH, DiskPanelHeight);
				disk.buttons[0].bounds.SetLeft(DiskOverviewPanelMarginH); disk.buttons[0].bounds.SetTop(DiskOverviewPanelMarginV + LabelHeight);

				height := DiskPanelHeight + LabelHeight + 2*DiskOverviewPanelMarginV;
				disk.panel.bounds.SetExtents(diskOverviewPanel.bounds.GetWidth() - 2*MainPanelMarginH , height);
			END;
			RETURN disk.panel;
		END UpdateDiskOverview;

		(* changes the order of the partition of disk.table so that it's sequential *)
		PROCEDURE BuildVTable(VAR disk : Disk);
		VAR part, i : LONGINT; isIncluded : POINTER TO ARRAY OF BOOLEAN;

			PROCEDURE GetNext(lastStart : LONGINT) : LONGINT;
			VAR i, min, next : LONGINT;
			BEGIN
				min := MAX(LONGINT);
				FOR i := 1 TO LEN(disk.table)-1 DO
					(* Note: Extended partitions that do not contain logical drives will be found twice: The extended partition and a pseudo *)
					(* partition (free) with the same boundaries -> Therefor, isIncluded is used *)
					IF ~isIncluded[i] & (disk.table[i].start >= lastStart) & (disk.table[i].start < min) THEN min := disk.table[i].start; next := i; END;
				END;
				ASSERT((next > 0) & (next < LEN(disk.table)));
				RETURN next;
		 	END GetNext;

		BEGIN
			ASSERT(model.IsLocked());
			IF disk.table # NIL THEN
				NEW(disk.vtable, LEN(disk.table)); NEW(disk.mapping, LEN(disk.table)); NEW(isIncluded, LEN(disk.table));
				disk.vtable[0] := disk.table[0]; disk.mapping[0] := 0; (* whole disk;  not mapped *)
				IF LEN(disk.table) > 1 THEN
					FOR i := 1 TO LEN(disk.vtable)-1 DO
						part := GetNext(disk.vtable[i-1].start);
						isIncluded[part] := TRUE;
						disk.vtable[i] := disk.table[part];
						disk.mapping[i] := part;
					END;
				END;
			ELSE
				disk.vtable := NIL;
			END;
		END BuildVTable;

		PROCEDURE BuildDiskPanel(VAR disk  : Disk): WMStandardComponents.Panel;
		VAR
			diskSelected : BOOLEAN;
			fillColor : LONGINT;
			text : ARRAY 32 OF CHAR;
			logical : LONGINT; (* nbr of logical partitions on disk *)
			i, k : LONGINT;
		BEGIN
			ASSERT(model.IsLocked());
			BuildVTable(disk);
			(* disk.buttons[0]: representation of "whole disk" *)
			(* disk.buttons[i]: primary or extended partitions *)
			IF (disk.vtable # NIL) THEN

				PartitionsLib.WriteType(disk.vtable[0].type, text, fillColor); (* get whole disk color *)

				IF selection.disk.device = disk.device THEN diskSelected := TRUE; ELSE diskSelected := FALSE; END;
				disk.buttons[0].onClick.Add(DiskPanelHandler);
				disk.buttons[0].clDefault.Set(fillColor);
				disk.buttons[0].clPressed.Set(clSelected.Get());

				IF diskSelected & (selection.partition = 0) THEN disk.buttons[0].SetPressed(TRUE); END;

				i := 1;
				WHILE i < LEN(disk.vtable) DO (* draw bar for each partition *)

					PartitionsLib.WriteType(disk.vtable[i].type, text, fillColor);

					IF ((disk.vtable[i].type = 15) OR (disk.vtable[i].type=5)) & (disk.vtable[i].flags * {AosDisks.Primary} = {AosDisks.Primary}) THEN (* it's an extended partition *)

						disk.buttons[i].clDefault.Set(fillColor);
						disk.buttons[i].clPressed.Set(clSelected.Get());
						disk.buttons[i].onClick.Add(DiskPanelHandler);

						IF diskSelected & (selection.partition = i) THEN disk.buttons[i].SetPressed(TRUE); END;

						(* how many logical drives does the extented partition contain? *)
						logical := 0;
						WHILE(i+logical+1 < LEN(disk.vtable)) & (disk.vtable[i+logical+1].flags * {AosDisks.Primary} = {}) DO
							INC(logical);
						END;

						IF logical > 0 THEN (* extended partition contains at least one logical drive *)
								FOR k := 1 TO logical DO
									PartitionsLib.WriteType(disk.vtable[i+k].type, text, fillColor);

									disk.buttons[i+k].clDefault.Set(fillColor);
									disk.buttons[i+k].clPressed.Set(clSelected.Get());
									disk.buttons[i+k].onClick.Add(DiskPanelHandler);

									IF diskSelected & (selection.partition = i+k) THEN disk.buttons[i+k].SetPressed(TRUE); END;

									disk.buttons[i].AddInternalComponent(disk.buttons[i+k]); (* add logical drives to extended partition *)
								END;
						END;

						(* Add extended partition to whole disk *)
						disk.buttons[0].AddInternalComponent(disk.buttons[i]);
						i := i + 1 + logical;

					ELSE (* It's a primary partition *)
						disk.buttons[i].clDefault.Set(fillColor);
						disk.buttons[i].clPressed.Set(clSelected.Get());
						disk.buttons[i].onClick.Add(DiskPanelHandler);
						IF diskSelected & (selection.partition = i) THEN disk.buttons[i].SetPressed(TRUE); END;
						(* add primary partition to whole disk *)
						disk.buttons[0].AddInternalComponent(disk.buttons[i]);
						INC(i);
					END;
				END;
			ELSE (* unpartitioned space or unpartitioned device *)
				PartitionsLib.WriteType(-1, text, fillColor); (* get color of unallocated space *)
				disk.buttons[0].clDefault.Set(fillColor);
				disk.buttons[0].clTextDefault.Set(WMGraphics.Black);
				disk.buttons[0].clPressed.Set(clSelected.Get());
				disk.buttons[0].onClick.Add(DiskPanelHandler);
				IF diskSelected & (selection.partition = 0) THEN disk.buttons[0].SetPressed(TRUE); END;
			END;
			disk.panel.AddInternalComponent(disk.buttons[0]);
			RETURN disk.panel;
		END BuildDiskPanel;

		PROCEDURE UpdateDiskPanel(disk  : Disk);
		VAR
			width, offset, extWidth, extOffset, totalWidth, extTotalWidth : LONGINT;
			fillColor : LONGINT;
			text : ARRAY 32 OF CHAR;
			primary, logical : LONGINT; (* nbr of primary/logical partitions on disk *)
			i, k : LONGINT;
		BEGIN
			ASSERT(model.IsLocked());
			disk.buttons[0].bounds.SetExtents(diskOverviewPanel.bounds.GetWidth() - 2*MainPanelMarginH - 2*DiskOverviewPanelMarginH, DiskPanelHeight);
			disk.buttons[0].bounds.SetLeft(DiskOverviewPanelMarginH); disk.buttons[0].bounds.SetTop(DiskOverviewPanelMarginV + LabelHeight);

			(* For the case we deal with an unpartitioned device which is mounted *)
			IF (disk.table # NIL) & (LEN(disk.table) = 1) & (disk.fs#NIL) & (disk.fs[0] # NIL) THEN
				disk.buttons[0].caption.Set(Strings.NewString(disk.fs[0].prefix));
			END;

			(* how many primary partitions does the drive contain? (needed for layout only) *)
			primary := 0;
			FOR i := 1 TO LEN(disk.vtable)-1 DO (* table[0] is whole disk *) (* should also count reserved / free *)
				IF disk.vtable[i].flags * {AosDisks.Primary} # {} THEN INC(primary) END;
			END;

			(* the graphical representation of some partition may have to be enlarged to PanelMinWidth... how many pixels are added? (Layouting) *)
			totalWidth :=disk.buttons[0].bounds.GetWidth() - 2*DiskPanelMarginH - (primary-1)*DiskPanelSpacer;

			i := 1;
			WHILE i < LEN(disk.vtable) DO

				IF disk.vtable[i].type = 15 THEN
					WHILE (i+1 < LEN(disk.vtable)) & (disk.vtable[i+1].flags * {AosDisks.Primary} = {}) DO INC(i); END; (* skip logical drives *)
				END;
				width := ENTIER((disk.vtable[i].size / disk.vtable[0].size) * totalWidth);
				IF width < PanelMinWidth THEN
					totalWidth := totalWidth - (PanelMinWidth - width);
				END;
				INC(i);
			END;

			offset := DiskPanelMarginH;

			i := 1;
			WHILE i < LEN(disk.vtable) DO (* draw bar for each partition *)

				width := ENTIER((disk.vtable[i].size / disk.vtable[0].size) * totalWidth);
				IF width < PanelMinWidth THEN width := PanelMinWidth; END;

				PartitionsLib.WriteType(disk.vtable[i].type, text, fillColor);

				IF ((disk.vtable[i].type = 15) OR (disk.vtable[i].type=5)) & (disk.vtable[i].flags * {AosDisks.Primary} = {AosDisks.Primary}) THEN (* it's an extended partition *)

					disk.buttons[i].bounds.SetExtents(width, DiskPanelHeight - 2*DiskPanelMarginV);
					disk.buttons[i].bounds.SetLeft(offset); disk.buttons[i].bounds.SetTop(DiskPanelMarginV);

					(* how many logical drives does the extented partition contain? *)
					logical := 0;
					WHILE(i+logical+1 < LEN(disk.vtable)) & (disk.vtable[i+logical+1].flags * {AosDisks.Primary} = {}) DO
						INC(logical);
					END;

					extTotalWidth := + disk.buttons[i].bounds.GetWidth() - 2*DiskPanelMarginH-(logical-1)*DiskPanelSpacer;

					logical := 0;
					WHILE(i+logical+1 < LEN(disk.vtable)) & (disk.vtable[i+logical+1].flags * {AosDisks.Primary} = {}) DO
						extWidth := ENTIER((disk.vtable[i+logical+1].size / disk.vtable[i].size) * extTotalWidth);
						IF extWidth < PanelMinWidth THEN
							extTotalWidth := extTotalWidth - (PanelMinWidth - extWidth);
						END;
						INC(logical);
					END;

					IF logical > 0 THEN (* extended partition contains at least one logical drive *)

							extOffset := DiskPanelMarginH;

							FOR k := 1 TO logical DO
								extWidth := ENTIER((disk.vtable[i+k].size / disk.vtable[i].size) * extTotalWidth);
								IF extWidth < PanelMinWidth THEN
									extWidth := PanelMinWidth;
								END;

								PartitionsLib.WriteType(disk.vtable[i+k].type, text, fillColor);
								disk.buttons[i+k].clDefault.Set(fillColor);
								disk.buttons[i+k].bounds.SetExtents(extWidth, disk.buttons[i].bounds.GetHeight() - 2*DiskPanelMarginV);
								disk.buttons[i+k].bounds.SetLeft(extOffset); disk.buttons[i+k].bounds.SetTop(DiskPanelMarginV);

								IF (disk.fs#NIL) & (disk.mapping[i+k] < LEN(disk.fs)) & (disk.fs[disk.mapping[i+k]]#NIL) THEN
									disk.buttons[i+k].caption.Set(Strings.NewString(disk.fs[disk.mapping[i+k]].prefix));
								END;

								extOffset := extOffset + extWidth + DiskPanelSpacer;
							END;
					END;

					offset := offset + width + DiskPanelSpacer;
					i := i + 1 + logical;

				ELSE (* It's a primary partition *)
					disk.buttons[i].clDefault.Set(fillColor);
					disk.buttons[i].bounds.SetExtents(width, DiskPanelHeight - 2*DiskPanelMarginV);
					disk.buttons[i].bounds.SetLeft(offset); disk.buttons[i].bounds.SetTop(DiskPanelMarginV);

					IF (disk.fs#NIL) & (disk.mapping[i] < LEN(disk.fs)) & (disk.fs[disk.mapping[i]]#NIL) THEN
						disk.buttons[i].caption.Set(Strings.NewString(disk.fs[disk.mapping[i]].prefix));
					END;

					offset := offset + width + DiskPanelSpacer;
					INC(i);
				END;
			END;
		END UpdateDiskPanel;

		PROCEDURE DiskEventHandler(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.DiskEventHandler, sender, data)
			ELSE
				model.Acquire;
				model.Synchronize;
				RebuildDiskOverview;
				UpdateLayout(bounds.GetWidth(), bounds.GetHeight(), TRUE);
				ScrollX(NIL, NIL); ScrollY(NIL, NIL);
				model.Release;
				Reset(SELF, NIL); (* UGLY HACK *)
				Invalidate;
			END;
		END DiskEventHandler;

		PROCEDURE DiskPanelHandler(owner, par : ANY);
		VAR
			found : BOOLEAN;
			disk, partition : LONGINT;
			button : WMStandardComponents.Button;
		BEGIN
			button := owner (WMStandardComponents.Button); found := FALSE;
			model.Acquire;
			disk := 0;
			LOOP
				IF model.disks[disk].buttons#NIL THEN
					partition := 0;
					LOOP
						IF model.disks[disk].buttons[partition] = button THEN
							found := TRUE;
						END;
						IF found OR (model.disks[disk].table = NIL) OR (partition >= LEN(model.disks[disk].table)-1) THEN EXIT END;
						INC(partition);
					END;
				END;
				IF found OR (disk >= LEN(model.disks)-1) THEN EXIT END;
				INC(disk);
			END;
			IF model.disks[disk].table # NIL THEN partition := model.disks[disk].mapping[partition]; END; (* map to oberon partition numbering *)
			IF found THEN UpdateSelection(disk, partition); END;
			model.Release;
		END DiskPanelHandler;

		(* called when disks[] has changed *)
		PROCEDURE RebuildDiskOverview;
		VAR
			panel : WMStandardComponents.Panel;
			label : WMStandardComponents.Label;
			top, i : LONGINT;
			minHeight, minWidth, min : LONGINT;
			width, height : LONGINT;
		BEGIN
			ASSERT(model.IsLocked());
			diskOverviewScrollPanel.RemoveContent(diskOverviewPanel);
			NEW(diskOverviewPanel);
			diskOverviewScrollPanel.AddInternalComponent(diskOverviewPanel);

			IF model.disks # NIL THEN
				BuildSkeleton;
				CalcDiskPanelBounds(minWidth, minHeight);
				UpdateDiskGrids;

				IF showDetails.Get() THEN (* also consider the bounds of the grids *)
					(* minWidth *)
					min := 0;
					FOR i := 0 TO DiskOverviewTableColumns-1 DO
						min := min + maxWidths[i] (* cell width *) + GridMinSpacerH +1; (* spacing between cells *)
					END;
					min := min - 1; (* counted one spacing to much *)
					IF min > minWidth THEN minWidth := min; END;

					FOR i := 0 TO LEN(model.disks)-1 DO
						IF model.disks[i].grid # NIL THEN
							SetGridBounds(model.disks[i].grid);
						END;
					END;

					(* minHeight *)
					FOR i := 0 TO LEN(model.disks)-1 DO
						IF model.disks[i].grid # NIL THEN
							minHeight := minHeight + model.disks[i].grid.bounds.GetHeight() + titleGrid.bounds.GetHeight() + DiskOverviewPanelMarginV + 8;
						END;
					END;
				END;

				IF bounds.GetWidth() >= (minWidth + 2*MainPanelMarginH + 2*DiskOverviewPanelMarginH) THEN
					width := bounds.GetWidth();
				ELSE
					width := minWidth + 2*MainPanelMarginH + 2*DiskOverviewPanelMarginH;
				END;

				height := bounds.GetHeight() - 2*MainPanelMarginV;
				IF height  < minHeight THEN
					height := minHeight + 2*MainPanelMarginV;
					width := width- scrollbarY.bounds.GetWidth();
				END;

				diskOverviewPanel.bounds.SetLeft(0); diskOverviewPanel.bounds.SetTop(-scrollbarY.pos.Get());
				diskOverviewPanel.bounds.SetExtents(width, height);

				FOR i := 0 TO LEN(model.disks)-1 DO diskOverviewPanel.AddInternalComponent(BuildDiskPanel(model.disks[i])); END;

				top := 0;
				FOR i := 0 TO LEN(model.disks)-1 DO
					top := top + MainPanelMarginV;
					panel := UpdateDiskOverview(model.disks[i], top, TRUE);
					top := top + panel.bounds.GetHeight();
				END;
			ELSE
				NEW(label);
				label.alignment.Set(WMComponents.AlignClient);
				label.alignV.Set(WMGraphics.AlignCenter); label.alignH.Set(WMGraphics.AlignCenter);
				label.caption.SetAOC("No Disks");
				diskOverviewPanel.AddInternalComponent(label);
				diskOverviewPanel.bounds.SetLeft(0); diskOverviewPanel.bounds.SetTop(0);
				height := bounds.GetHeight() - 2*MainPanelMarginV;
				IF height < 0 THEN height := 10; END;
				diskOverviewPanel.bounds.SetExtents(bounds.GetWidth(), height);
			END;
		END RebuildDiskOverview;

		PROCEDURE BuildSkeleton;
		VAR grid : WMStringGrids.StringGrid; i, j : LONGINT;
		BEGIN
			ASSERT(model.IsLocked());
			ASSERT(model.disks # NIL);
			FOR i := 0 TO LEN(model.disks)-1 DO
				(* build skeleton for graphical representation of the disk models data *)
				NEW(model.disks[i].label);
				model.disks[i].label.fillColor.Set(clBackground.Get()); model.disks[i].label.textColor.Set(LabelTxtColor);
				NEW(model.disks[i].panel);
				model.disks[i].panel.AddInternalComponent(model.disks[i].label);

				IF model.disks[i].table # NIL THEN
					NEW(model.disks[i].grid);
					model.disks[i].panel.AddInternalComponent(model.disks[i].grid);
					grid := model.disks[i].grid;
					grid.alwaysShowScrollX.Set(FALSE); grid.showScrollX.Set(FALSE);
					grid.alwaysShowScrollY.Set(FALSE); grid.showScrollY.Set(FALSE);
					grid.SetSelectionMode(WMGrids.GridSelectRows);
					grid.onClick.Add(GridClicked);
					grid.Acquire;
					grid.model.Acquire;
					grid.model.SetNofCols(DiskOverviewTableColumns);
					grid.model.SetNofRows(LEN(model.disks[i].table));
					grid.allowColResize.Set(FALSE); grid.allowRowResize.Set(FALSE);
					FOR j := 0 TO LEN(model.disks[i].table) -1 DO
						grid.model.SetTextAlign(0, j, WMGraphics.AlignLeft);
						grid.model.SetTextAlign(1, j, WMGraphics.AlignRight);
						grid.model.SetTextAlign(2, j,  WMGraphics.AlignRight);
						grid.model.SetTextAlign(3, j, WMGraphics.AlignRight);
						grid.model.SetTextAlign(4, j, WMGraphics.AlignCenter);
						grid.model.SetTextAlign(5, j, WMGraphics.AlignCenter);
					END;
					grid.model.Release;
					grid.Release;
 					model.disks[i].titlegrid := BuildTitleGrid(); model.disks[i].panel.AddInternalComponent(model.disks[i].titlegrid);
					NEW(model.disks[i].buttons, LEN(model.disks[i].table));
					FOR j := 0 TO LEN(model.disks[i].table)-1 DO
						NEW(model.disks[i].buttons[j]);
						model.disks[i].buttons[j].isToggle.Set(TRUE);
						model.disks[i].buttons[j].indicateToggle.Set(FALSE);
						model.disks[i].buttons[j].useBgBitmaps.Set(FALSE);
					END;
				ELSE
					NEW(model.disks[i].buttons, 1);
					NEW(model.disks[i].buttons[0]);
				END;
			END;
		END BuildSkeleton;

		PROCEDURE GetSizeString(nbrOfBlocks, blockSize : LONGINT) : Strings.String;
		VAR sizeKB : HUGEINT; caption : ARRAY 128 OF CHAR;
		BEGIN
			sizeKB := (LONG(nbrOfBlocks) * LONG(blockSize)) DIV  1024;
			IF sizeKB > 4*1024 THEN
				Strings.IntToStr(SHORT(sizeKB DIV 1024), caption);
				Strings.Append(caption, " MB");
			ELSE
				Strings.IntToStr(SHORT (sizeKB), caption);
				Strings.Append(caption, " KB");
			END;
			RETURN Strings.NewString(caption);
		END GetSizeString;

		PROCEDURE UpdateDiskGrids;
		VAR
			table : AosDisks.PartitionTable;
			caption, temp : ARRAY 128 OF CHAR;
			fillColor : LONGINT;
			grid : NoWheelGrid;
			disk, partition : LONGINT;
			width, height : LONGINT;
			minHeights : POINTER TO ARRAY OF LONGINT; (* minimum heights of each grid *)
			col, row : LONGINT;
			string : Strings.String;
			font : WMGraphics.Font;
		BEGIN
			ASSERT(model.IsLocked());
			ASSERT(model.disks # NIL);
			FOR disk := 0 TO LEN(model.disks)-1 DO
				table := model.disks[disk].table;	grid := model.disks[disk].grid;
				IF (table # NIL) & (grid # NIL) THEN
					FOR partition := 0 TO LEN(table)-1 DO
						grid.Acquire;
						grid.model.Acquire;
						(* Column 1: Partition : dev#part *)
						caption := "";
						Strings.Append(caption, model.disks[disk].device.name); Strings.Append(caption, "#");
						Strings.IntToStr(partition, temp); Strings.Append(caption, temp);
						grid.model.SetCellText(0, partition, Strings.NewString(caption));
						(* Column 2: Start *)
						Strings.IntToStr(table[partition].start, caption);
						grid.model.SetCellText(1, partition, Strings.NewString(caption));
						(* Column 3: End *)
						Strings.IntToStr(table[partition].start + table[partition].size -1, caption);
						grid.model.SetCellText(2, partition, Strings.NewString(caption));
						(* Column 4: Size in MB or KB*)
						grid.model.SetCellText(3, partition, GetSizeString(table[partition].size, model.disks[disk].device.blockSize));
						(* Column 5: Type: Number and description *)
						Strings.IntToStr(table[partition].type, caption);
						PartitionsLib.WriteType(table[partition].type, temp, fillColor);
						Strings.Append(caption, " ("); Strings.Append(caption, temp); Strings.Append(caption, ")");
						grid.model.SetCellText(4, partition, Strings.NewString(caption));
						(* Column 6: Flags *)
						caption := "";
						IF AosDisks.Mounted IN table[partition].flags THEN Strings.Append(caption, "[M]"); END;
						IF AosDisks.Valid IN table[partition].flags THEN Strings.Append(caption, "[V]"); END;
						IF AosDisks.Primary IN table[partition].flags THEN Strings.Append(caption, "[P]"); END;
						IF AosDisks.Boot IN table[partition].flags THEN Strings.Append(caption, "[B]"); END;
						grid.model.SetCellText(5, partition, Strings.NewString(caption));
						grid.model.Release;
						grid.Release;
					END;
				ELSE (* no partition table available *)
					model.disks[disk].grid := NIL;
				END;
			END;

			(* now we calculate the minimum column widths so that the cell text does fit into the cells *)
			(* also consider alignment of title grid ... *)
			font := titleGrid.GetFont();
			titleGrid.Acquire;
			titleGrid.model.Acquire;
			FOR col := 0 TO titleGrid.model.GetNofCols() -1 DO
				string := titleGrid.model.GetCellText(col, row);
				IF string # NIL THEN font.GetStringSize(string^, width, height); END;
				IF width  > maxWidths[col] THEN maxWidths[col] := width; END;
				IF height > maxHeight THEN maxHeight := height; END;
			END;
			titleGrid.model.Release;
			titleGrid.Release;

			NEW(minHeights, LEN(model.disks));

			FOR disk := 0 TO LEN(model.disks)-1 DO
				grid := model.disks[disk].grid;
				IF grid # NIL THEN
					font := grid.GetFont();
					grid.Acquire;
					grid.model.Acquire;
					(* determine minimum heigths and widths needed to show the text in the cells *)
					FOR col := 0 TO grid.model.GetNofCols() -1 DO
						FOR row := 0 TO grid.model.GetNofRows() - 1 DO
							string := grid.model.GetCellText(col, row);
							IF string # NIL THEN font.GetStringSize(string^, width, height); END;
							IF width  > maxWidths[col] THEN maxWidths[col] := width; END;
							IF height > maxHeight THEN maxHeight := height; END;
						END;
					END;
					grid.model.Release;
					grid.Release;
				END;
			END;
		END UpdateDiskGrids;

		(* calculates the minimum width/height which is needed to display the disk panels correctly *)
		PROCEDURE CalcDiskPanelBounds(VAR minWidth, minHeight : LONGINT);
		VAR i, j : LONGINT;
		BEGIN
			ASSERT(model.IsLocked());
			ASSERT(model.disks # NIL);
			minWidth := 0; minHeight := MainPanelMarginV;
			(*determine the minimum width and height required for  the disk panels *)
			FOR i := 0 TO LEN(model.disks)-1 DO (* traverse all model.disks ... *)
				minHeight := minHeight + MainPanelMarginV + 2*DiskOverviewPanelMarginV + LabelHeight + DiskPanelHeight;
				IF model.disks[i].table#NIL THEN
					WHILE j < LEN(model.disks[i].table) DO (* ... and all partitions *)
						IF model.disks[i].table[j].flags * {AosDisks.Primary} # {} THEN (* primary partition *)
							minWidth := minWidth + PanelMinWidth + DiskPanelMarginH;
						ELSE (* extended partition *)
							minWidth := minWidth + DiskPanelMarginH + PanelMinWidth;
						END;
						INC(j);
					END;
				END;
				minWidth := minWidth + 2*DiskOverviewPanelMarginH + DiskPanelMarginH;
			END;
		END CalcDiskPanelBounds;

 		PROCEDURE BuildTitleGrid() : NoWheelGrid;
		VAR grid : NoWheelGrid;
		BEGIN
			NEW(grid);
			grid.Acquire;
			grid.model.Acquire;
			grid.alwaysShowScrollX.Set(FALSE); grid.showScrollX.Set(FALSE);
			grid.alwaysShowScrollY.Set(FALSE); grid.showScrollY.Set(FALSE);
			grid.SetSelectionMode(WMGrids.GridSelectNone);
			grid.allowColResize.Set(FALSE); grid.allowRowResize.Set(FALSE);
			grid.model.SetNofCols(DiskOverviewTableColumns); grid.model.SetNofRows(1);
			grid.fixedCols.Set(DiskOverviewTableColumns); grid.fixedRows.Set(1);
			grid.model.SetCellText(0, 0, Strings.NewString("Partition"));
			grid.model.SetCellText(1, 0, Strings.NewString("Start"));
			grid.model.SetCellText(2, 0, Strings.NewString("End"));
			grid.model.SetCellText(3, 0, Strings.NewString("Size"));
			grid.model.SetCellText(4, 0, Strings.NewString("Type"));
			grid.model.SetCellText(5, 0, Strings.NewString("Flags"));
			grid.model.Release;
			grid.Release;
			RETURN grid;
		END BuildTitleGrid;

		(** calculates the length/height of the largest string per row/column *)
		PROCEDURE SetGridBounds(VAR grid : NoWheelGrid);
		VAR
			col, row : LONGINT;
			widths, heights : WMGrids.Spacings;
			width, height: LONGINT;
			spacer : LONGINT;
		BEGIN
			ASSERT(grid#NIL);
			grid.Acquire;
			grid.model.Acquire;
			(* set the widths ... *)
			IF bounds.GetWidth() >= (minWidth + 2*MainPanelMarginH + 2*DiskOverviewPanelMarginH) THEN
			 	spacer := (bounds.GetWidth() - 2*MainPanelMarginH  - minWidth) DIV DiskOverviewTableColumns;
				width := bounds.GetWidth() - 2*MainPanelMarginH - 2*DiskOverviewPanelMarginH;
				IF GridMinSpacerH > spacer THEN spacer := GridMinSpacerH; END;
			ELSE
				spacer := GridMinSpacerH;
				width := minWidth;
			END;

			NEW(widths, DiskOverviewTableColumns);
			FOR col := 0 TO DiskOverviewTableColumns-1 DO widths[col] := maxWidths[col] + spacer; END;
			(* Correct integer division rounding error *)
			IF (bounds.GetWidth() - 2*MainPanelMarginH -2*DiskOverviewPanelMarginH - minWidth) MOD DiskOverviewTableColumns # 0 THEN INC(widths[0]); END;
			grid.SetColSpacings(widths);

			(* set the heights *)
			height := 0;
			spacer := GridMinSpacerV;
			NEW(heights, grid.model.GetNofRows());
			FOR row := 0 TO grid.model.GetNofRows()-1 DO heights[row] := maxHeight + spacer; height := height + maxHeight + spacer + 1; END;
			grid.SetRowSpacings(heights);
			grid.bounds.SetExtents(width, height);
			grid.model.Release;
			grid.Release;
		END SetGridBounds;

		PROCEDURE UpdateLayout(w, h : LONGINT; updateContent : BOOLEAN);
		VAR
			panel : WMStandardComponents.Panel;
			min, top : LONGINT;
			width, height : LONGINT;
			i : LONGINT;
		BEGIN
			ASSERT(model.IsLocked());
			IF model.disks # NIL THEN
				CalcDiskPanelBounds(minWidth, minHeight);
				IF updateContent THEN UpdateDiskGrids; END;
			ELSE
				minWidth := 0; minHeight := 0;
			END;

			IF showDetails.Get() & (model.disks # NIL) THEN (* also consider the bounds of the grids *)
				(* minWidth *)
				min := 0;
				FOR i := 0 TO DiskOverviewTableColumns-1 DO
					min := min + maxWidths[i] (* cell width *) + GridMinSpacerH +1; (* spacing between cells *)
				END;
				min := min - 1; (* counted one spacing to much *)
				IF min > minWidth THEN minWidth := min; END;

				FOR i := 0 TO LEN(model.disks)-1 DO
					IF model.disks[i].grid # NIL THEN
						SetGridBounds(model.disks[i].grid);
					END;
				END;

				(* minHeight *)
				FOR i := 0 TO LEN(model.disks)-1 DO
					IF model.disks[i].grid # NIL THEN
						minHeight := minHeight + model.disks[i].grid.bounds.GetHeight() + titleGrid.bounds.GetHeight() + DiskOverviewPanelMarginV + 13;
					END;
				END;
			END;

			(* if the actual diskoverview panel bounds are bigger then minWidth&minHeight, then use them *)
			IF w >= (minWidth + 2*MainPanelMarginH + 2*DiskOverviewPanelMarginH) THEN
				width := w;
			ELSE
				width := minWidth + 2*MainPanelMarginH + 2*DiskOverviewPanelMarginH;
			END;

			IF (h >= minHeight) THEN
				height := h;
			ELSE
				height := minHeight;
				width := width - scrollbarY.bounds.GetWidth();
			END;

			diskOverviewPanel.bounds.SetExtents(width, height); diskOverviewPanel.bounds.SetLeft(0);

			IF (model.disks # NIL) THEN
				top := 0;
				FOR i := 0 TO LEN(model.disks)-1 DO
					top := top + MainPanelMarginV;
					panel := UpdateDiskOverview(model.disks[i], top, updateContent);
					top := top + panel.bounds.GetHeight();
				END;
			END;

			(* do we need scrollbars for the diskoverview panel ? *)
			IF (minHeight > h) THEN (* need a vertical scrollbar ... *)
				scrollbarY.max.Set(minHeight - h);
				scrollbarY.pos.Set(scrollY);
				scrollbarY.visible.Set(TRUE);
			ELSE
				scrollY := 0; diskOverviewPanel.bounds.SetTop(0);
				scrollbarY.visible.Set(FALSE);
			END;

			IF (minWidth > w)  THEN (* need a horizontal scrollbar *)
				scrollbarX.max.Set(w - 2 * MainPanelMarginH - scrollbarY.bounds.GetWidth());
				scrollbarX.pos.Set(scrollX);
				scrollbarX.visible.Set(TRUE);
			ELSE
				scrollX := 0; diskOverviewPanel.bounds.SetLeft(0);
				scrollbarX.visible.Set(FALSE);
			END;
		END UpdateLayout;

		(* UpdateSelection(-1,-1) means "no selection" *)
		PROCEDURE UpdateSelection(disk, partition : LONGINT);
		VAR
			caption, temp : ARRAY 128 OF CHAR;
			selectionNone : LONGINT;
			wrapper : SelectionWrapper;
			i, j : LONGINT;
		BEGIN
			ASSERT(model.IsLocked());
			selection.partition := partition;

			caption := "Selection: ";
			IF (disk = -1) & (partition = -1) THEN (* selection: none *)
				Strings.Append(caption, "none");
				selection.disk.device := NIL;
			ELSE
				Strings.IntToStr(selection.partition, temp);
				selection.disk := model.disks[disk];
				Strings.Append(caption, selection.disk.device.name); Strings.Append(caption, "#");
				Strings.IntToStr(selection.partition, temp); Strings.Append(caption, temp);
				Strings.Append(caption, " ("); Strings.Append(caption, selection.disk.device.desc); Strings.Append(caption, ")");
				Strings.Append(caption, "");
			END;

			(* update grids & buttons *)
			IF model.disks # NIL THEN
				FOR i := 0 TO LEN(model.disks)-1 DO
					IF (model.disks[i].grid # NIL) THEN
						IF i = disk THEN
							model.disks[i].grid.SetSelection(disk,partition,disk,partition);
						ELSE
							selectionNone := LEN(model.disks[i].table); (* not visible *)
							model.disks[i].grid.SetSelection(selectionNone,selectionNone,selectionNone,selectionNone);
						END;
					END;

					IF model.disks[i].buttons#NIL THEN
						FOR j := 0 TO LEN(model.disks[i].buttons)-1 DO (* for all partitions... *)
							IF model.disks[i].table#NIL THEN
								IF (i = disk) & (model.disks[i].mapping[j] = partition) THEN (* selected *)
									model.disks[i].buttons[j].SetPressed(TRUE);
								ELSE
									model.disks[i].buttons[j].SetPressed(FALSE);
								END;
							ELSE (* no partition table *)
								IF (i = disk) & (partition = 0) THEN
									model.disks[i].buttons[0].SetPressed(TRUE);
								ELSE
									model.disks[i].buttons[0].SetPressed(FALSE);
								END;
							END;
						END;
					END;
				END;
			END;

			NEW(wrapper); wrapper.selection := selection;
			onSelection.Call(wrapper);
		END UpdateSelection;

		PROCEDURE WheelMove*(dz : LONGINT);
		VAR pos : LONGINT;
		BEGIN
			IF scrollbarY.visible.Get() THEN
				pos := scrollbarY.pos.Get() + Multiplier*dz;
				IF pos < scrollbarY.min.Get() THEN pos := scrollbarY.min.Get(); END;
				IF pos > scrollbarY.max.Get() THEN pos := scrollbarY.max.Get(); END;
				scrollbarY.pos.Set(pos);
				scrollbarY.onPositionChanged.Call(scrollbarY.pos)
			END;
		END WheelMove;

	END PartitionSelector;

TYPE

	Operation* = PartitionsLib.Operation;

	OperationWrapper* = OBJECT
	VAR
		operation- : PartitionsLib.Operation;
	END OperationWrapper;

TYPE

	OperationSelector* = OBJECT(WMComponents.VisualComponent)
	VAR
		(** Generates an event whenever the user selects an operation *)
		onSelection- : WMEvents.EventSource;

		grid, titleGrid : NoWheelGrid;
		spacings : WMGrids.Spacings; noOfCols : LONGINT;

		operations : PartitionsLib.AllOperations;

		selectedOperation: PartitionsLib.Operation; (* NIL if no operation is selected *)

		scrollbarY : WMStandardComponents.Scrollbar;
		scrollPanel : WMStandardComponents.Panel;
		scrollY : LONGINT; (* current position of scrollbar *)

		state : LONGINT;
		timer : Kernel.Timer;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrOperationSelector);
			SetGenerator("WMPartitionsComponents.GenOperationSelector");
			NEW(onSelection, SELF, Strings.NewString("onSelection"), Strings.NewString("Generates an event when an  is selected"),
				SELF.StringToCompCommand); events.Add(onSelection);

			state := Initializing;
			NEW(timer); noOfCols := 6;

			NEW(scrollbarY);
			scrollbarY.vertical.Set(TRUE); scrollbarY.alignment.Set(WMComponents.AlignRight);
			scrollbarY.min.Set(0); scrollbarY.onPositionChanged.Add(ScrollY);
			AddInternalComponent(scrollbarY);

			NEW(scrollPanel);
			AddInternalComponent(scrollPanel);

			scrollY := 0;

			NEW(titleGrid);
			titleGrid.bounds.SetLeft(0); titleGrid.bounds.SetTop(0);
			titleGrid.alwaysShowScrollX.Set(FALSE); titleGrid.showScrollX.Set(FALSE);
			titleGrid.alwaysShowScrollY.Set(FALSE); titleGrid.showScrollY.Set(FALSE);
			titleGrid.allowColResize.Set(FALSE); titleGrid.allowRowResize.Set(FALSE);
			titleGrid.fixedCols.Set(noOfCols); titleGrid.fixedRows.Set(1);
			titleGrid.Acquire;
			titleGrid.model.Acquire;
			titleGrid.SetSelectionMode(WMGrids.GridSelectNone);
			titleGrid.model.SetNofCols(noOfCols); titleGrid.model.SetNofRows(1);
			titleGrid.model.SetCellText(0, 0, Strings.NewString("UID")); titleGrid.model.SetTextAlign(0, 0, WMGraphics.AlignCenter);
			titleGrid.model.SetCellText(1, 0, Strings.NewString("Operation")); titleGrid.model.SetTextAlign(1, 0, WMGraphics.AlignLeft);
			titleGrid.model.SetCellText(2, 0, Strings.NewString("Device")); titleGrid.model.SetTextAlign(2, 0, WMGraphics.AlignCenter);
			titleGrid.model.SetCellText(3, 0, Strings.NewString("Status")); titleGrid.model.SetTextAlign(3, 0, WMGraphics.AlignLeft);
			titleGrid.model.SetCellText(4, 0, Strings.NewString("Errors")); titleGrid.model.SetTextAlign(4, 0, WMGraphics.AlignCenter);
			titleGrid.model.SetCellText(5, 0, Strings.NewString("Progress")); titleGrid.model.SetTextAlign(5, 0, WMGraphics.AlignCenter);
			titleGrid.model.Release;
			titleGrid.Release;

			NEW(spacings, noOfCols);
			spacings[0] := 30; spacings[1] := 100; spacings[2] := 50;
			spacings[3] := 0; (* will be set later *)
			spacings[4] := 35; spacings[5] := 50;

			operations := PartitionsLib.operations.GetAll();

			NEW(grid);
			grid.bounds.SetLeft(0); grid.bounds.SetTop(15);
			grid.SetSelectionMode(WMGrids.GridSelectSingleRow); grid.onClick.Add(GridClicked);
			grid.alwaysShowScrollX.Set(FALSE); grid.showScrollX.Set(FALSE);
			grid.alwaysShowScrollY.Set(FALSE); grid.showScrollY.Set(FALSE);
			grid.allowColResize.Set(FALSE); grid.allowRowResize.Set(FALSE);

			UpdateGrid(TRUE);

			IF operations = NIL THEN grid.SetSelection(-1, -1, -1, -1); END; (* no selection *)

			scrollPanel.AddInternalComponent(titleGrid);
			scrollPanel.AddInternalComponent(grid);
		END Init;

		PROCEDURE Initialize*;
		BEGIN
			Initialize^;
			ASSERT(PartitionsLib.operations # NIL);
			PartitionsLib.operations.onChanged.Add(OperationEventHandler);
			UpdateGrid(FALSE);
			BEGIN {EXCLUSIVE} state := Running; END;
		END Initialize;

		PROCEDURE ScrollY(sender, data : ANY);
		VAR y : WMProperties.Int32Property;
		BEGIN
			IF data # NIL THEN y := data (WMProperties.Int32Property); scrollY := y.Get(); END;
			scrollPanel.bounds.SetTop(-scrollY);
		END ScrollY;

		PROCEDURE GetSelection*() : Operation;
		BEGIN
			RETURN selectedOperation;
		END GetSelection;

		PROCEDURE GridClicked(sender, x : ANY);
		VAR wrapper : OperationWrapper; grid : NoWheelGrid; ignore, row : LONGINT;
		BEGIN
			BEGIN {EXCLUSIVE} (* lock operations *)
				grid := sender (NoWheelGrid);
				IF operations # NIL THEN
					grid.Acquire;
					grid.model.Acquire;
					grid.GetSelection(ignore, row, ignore, ignore);
					IF row < LEN(operations) THEN
						selectedOperation := operations[row];
					ELSE
						selectedOperation := NIL;
						grid.model.SetTextAlign(0, 0, WMGraphics.AlignLeft);
					END;
					grid.model.Release;
					grid.Release;
				ELSE
					selectedOperation := NIL;
				END;
			END;
			NEW(wrapper); wrapper.operation := selectedOperation;
			onSelection.Call(wrapper);
		END GridClicked;

		PROCEDURE Resized*;
		BEGIN
			Resized^;
			UpdateGrid(FALSE);
		END Resized;

		PROCEDURE UpdateGrid(updateContent : BOOLEAN);
		CONST
			ColStatus = 3;
		VAR
			caption : ARRAY 128 OF CHAR;
			operation : PartitionsLib.Operation;
			width, height, minWidth : LONGINT;
			row, i, ignore, cellHeight : LONGINT;
			font : WMGraphics.Font;
			operationState : PartitionsLib.OperationState;
			widths, heights : WMGrids.Spacings;
		BEGIN (* caller must hold lock *)
			ASSERT((grid # NIL) & (titleGrid#NIL));
			IF operations # NIL THEN
				IF updateContent THEN
					grid.Acquire;
					grid.model.Acquire;
					grid.SetSelectionMode(WMGrids.GridSelectSingleRow);
					grid.model.SetNofCols(noOfCols); grid.model.SetNofRows(LEN(operations));

					FOR row := 0 TO LEN(operations)-1 DO
						operation := operations[row];
						FOR i := 0 TO LEN(operations) -1 DO
							grid.model.SetTextAlign(0, i, WMGraphics.AlignCenter); (* uid *)
							grid.model.SetTextAlign(1, i, WMGraphics.AlignLeft); (* operation *)
							grid.model.SetTextAlign(2, i,  WMGraphics.AlignCenter); (* device *)
							grid.model.SetTextAlign(3, i, WMGraphics.AlignLeft); (* status *)
							grid.model.SetTextAlign(4, i, WMGraphics.AlignCenter); (* errors *)
							grid.model.SetTextAlign(5, i, WMGraphics.AlignCenter); (* progress *)
						END;
						operationState := operation.GetState();
						(* Column 1: UID *)
						Strings.IntToStr(operation.uid, caption);
						grid.model.SetCellText(0, row, Strings.NewString(caption));
						(* Column 2: Operation Name *)
						grid.model.SetCellText(1, row, Strings.NewString(operation.name));
						(* Column 3: Device#partition *)
						grid.model.SetCellText(2, row, Strings.NewString(operation.diskpartString));
						(* Column 4: Status *)
						grid.model.SetCellText(3, row, Strings.NewString(operationState.statusString));
						(* Column 5: Errors *)
						Strings.IntToStr(operationState.errorCount, caption);
						grid.model.SetCellText(4, row, Strings.NewString(caption));
						(* Column 6: Progress *)
						IF operationState.progressValid THEN
							Strings.IntToStr(ENTIER(operationState.cur*100.0 / operationState.max), caption); Strings.Append(caption, "%");
						ELSE
							caption := "";
						END;
						grid.model.SetCellText(5, row, Strings.NewString(caption));
					END;
					grid.model.Release;
					grid.Release;
				END;

			ELSE (* no operations registered *)
				grid.Acquire;
				grid.model.Acquire;
				grid.model.SetNofCols(1); grid.model.SetNofRows(1);
				grid.model.SetCellText(0, 0, Strings.NewString("No operations"));
				grid.SetSelectionMode(WMGrids.GridSelectNone);
				grid.model.Release;
				grid.Release;
			END;

			(* Determine cell height *)
			font := titleGrid.GetFont(); font.GetStringSize("TestString", ignore, height);
			cellHeight := height + GridMinSpacerV;

			grid.Acquire;
			grid.model.Acquire;
			(* only the column "Status" is resizable, all others have a fixed width *)
			minWidth := 0;
			FOR i := 0 TO noOfCols-1 DO
				IF i # ColStatus THEN
					minWidth := minWidth + spacings[i] (* cell width *) +1; (* spacing between cells *)
				END;
			END;

			(* Calculate the grid height and set row spacings *)
			height := 0;
			IF operations # NIL THEN
				NEW(heights, grid.model.GetNofRows());
				FOR row := 0 TO grid.model.GetNofRows()-1 DO heights[row] := cellHeight; height := height + cellHeight + 1; END;
			ELSE
				NEW(heights, 1); heights[0] := cellHeight; height := height + cellHeight + 1;
			END;
			grid.SetRowSpacings(heights);

			(* Calculate the grid width and set column spacings *)
			width := bounds.GetWidth() - 2*DiskOverviewPanelMarginH;
			IF (height > bounds.GetHeight()) THEN
				width := width - scrollbarY.bounds.GetWidth();
			END;

			IF width > minWidth THEN
			 	spacings[ColStatus] := width- minWidth;
			ELSE (* should not be the case *)
				spacings[ColStatus] := 0;	width := minWidth;
			END;

			IF operations # NIL THEN
				grid.SetColSpacings(spacings);
			ELSE
				NEW(widths, 1);widths[0] := width;
				grid.SetColSpacings(widths);
			END;
			grid.model.Release;
			grid.Release;

			titleGrid.Acquire; titleGrid.model.Acquire;
			titleGrid.SetColSpacings(spacings);
			titleGrid.model.Release; titleGrid.Release;

			titleGrid.bounds.SetTop(DiskOverviewPanelMarginV); titleGrid.bounds.SetLeft(DiskOverviewPanelMarginH);
			titleGrid.bounds.SetExtents(width, cellHeight);

			grid.bounds.SetExtents(width, height); grid.bounds.SetTop(titleGrid.bounds.GetHeight() + DiskOverviewPanelMarginV + 1);
			grid.bounds.SetLeft(DiskOverviewPanelMarginH);

			scrollPanel.bounds.SetExtents(width + DiskOverviewPanelMarginH, height + titleGrid.bounds.GetHeight() + DiskOverviewPanelMarginV + 1);

			(* do we need scrollbars for the scrollPanel ? *)
			IF (height > bounds.GetHeight()) THEN (* need a vertical scrollbar ... *)
				scrollbarY.max.Set(height - bounds.GetHeight());
				scrollbarY.pos.Set(scrollY);
				scrollbarY.visible.Set(TRUE);
			ELSE
				scrollY := 0; scrollPanel.bounds.SetTop(0);
				scrollbarY.visible.Set(FALSE);
			END;
		END UpdateGrid;

		PROCEDURE OperationEventHandler(sender, data :  ANY);
		BEGIN (*{EXCLUSIVE}*) (* can lead to deadlock: we hold exclusive lock. Other component has lock but needs exclusive lock, cf. WMComponents.VisualComponent.Draw *)
			operations := PartitionsLib.operations.GetAllInternal();
			UpdateGrid(TRUE);
		END OperationEventHandler;

		PROCEDURE WheelMove(dz : LONGINT);
		VAR pos : LONGINT;
		BEGIN
			IF scrollbarY.visible.Get() THEN
				pos := scrollbarY.pos.Get() + Multiplier*dz;
				IF pos < scrollbarY.min.Get() THEN pos := scrollbarY.min.Get(); END;
				IF pos > scrollbarY.max.Get() THEN pos := scrollbarY.max.Get(); END;
				scrollbarY.pos.Set(pos);
				scrollbarY.onPositionChanged.Call(scrollbarY.pos)
			END;
		END WheelMove;

		PROCEDURE Finalize*;
		BEGIN
			Finalize^;
			ASSERT(PartitionsLib.operations # NIL);
			PartitionsLib.operations.onChanged.Remove(OperationEventHandler);
			BEGIN {EXCLUSIVE} state := Terminating; END;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(state = Terminated); END;
		END Finalize;

		PROCEDURE PollStatus;
		VAR
			operation : PartitionsLib.Operation;
			state : PartitionsLib.OperationState;
			caption : ARRAY 32 OF CHAR;
			i : LONGINT;
		BEGIN {EXCLUSIVE} (* lock operations *)
			IF operations # NIL THEN
				grid.Acquire;
				grid.model.Acquire;
				FOR i := 0 TO LEN(operations)-1 DO
					operation := operations[i];
					state := operation.GetState();
					(* Column 4: Status *)
					grid.model.SetCellText(3, i, Strings.NewString(state.statusString));

					(* Column 5: errors *)
					Strings.IntToStr(state.errorCount, caption);
					grid.model.SetCellText(4, i, Strings.NewString(caption));

					(* Column 6: Progress *)
					IF state.progressValid THEN
						Strings.IntToStr(ENTIER(state.cur*100.0 / state.max), caption); Strings.Append(caption, "%");
						grid.model.SetCellText(5, i, Strings.NewString(caption));
					ELSE
						caption := "";
						grid.model.SetCellText(5, i, Strings.NewString(caption));
					END;
				END;
				grid.model.Release;
				grid.Release;
			END;
		END PollStatus;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE} AWAIT(state > Initializing); END;
		WHILE (state = Running) DO
			PollStatus;
			timer.Sleep(100);
		END;
		BEGIN {EXCLUSIVE} state := Terminated; END;
	END OperationSelector;

TYPE

	TestWindow = OBJECT(WMComponents.FormWindow)
	VAR
		showDetailsBtn, showGeometryBtn : WMStandardComponents.Button;
		showDetails, showGeometry : BOOLEAN;

		selectionLabel : WMStandardComponents.Label;

		selector : PartitionSelector;

		PROCEDURE HandleButtons(sender, data : ANY);
		BEGIN
			IF sender = showDetailsBtn THEN
				showDetails := ~showDetails;
				selector.showDetails.Set(showDetails);
			ELSIF sender = showGeometryBtn THEN
				showGeometry := ~showGeometry;
				selector.showDiskGeometry.Set(showGeometry);
			END;
		END HandleButtons;

		PROCEDURE HandleSelection(sender, data : ANY);
		VAR selection : PartitionsLib.Selection; caption : ARRAY 128 OF CHAR; nbr : ARRAY 4 OF CHAR;
		BEGIN
			IF (data # NIL) & (data IS SelectionWrapper) THEN
				selection := data(SelectionWrapper).selection;
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

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel, toolbar : WMStandardComponents.Panel;
		BEGIN
			NEW(panel);
			panel.alignment.Set(WMComponents.AlignClient);
			panel.fillColor.Set(WMGraphics.White);

			NEW(toolbar);
			toolbar.bounds.SetHeight(20);
			toolbar.alignment.Set(WMComponents.AlignBottom);
			panel.AddInternalComponent(toolbar);

			NEW(showDetailsBtn); showDetailsBtn.alignment.Set(WMComponents.AlignLeft);
			showDetailsBtn.caption.SetAOC("Details");
			showDetailsBtn.onClick.Add(HandleButtons);
			showDetailsBtn.isToggle.Set(TRUE);
			showDetailsBtn.SetPressed(showDetails);
			toolbar.AddInternalComponent(showDetailsBtn);

			NEW(showGeometryBtn); showGeometryBtn.alignment.Set(WMComponents.AlignLeft);
			showGeometryBtn.caption.SetAOC("Geometry");
			showGeometryBtn.onClick.Add(HandleButtons);
			showGeometryBtn.isToggle.Set(TRUE);
			showGeometryBtn.SetPressed(showGeometry);
			toolbar.AddInternalComponent(showGeometryBtn);

			NEW(selectionLabel);
			selectionLabel.alignment.Set(WMComponents.AlignClient);
			selectionLabel.fillColor.Set(WMGraphics.White);
			toolbar.AddInternalComponent(selectionLabel);

			NEW(selector);
			selector.alignment.Set(WMComponents.AlignClient);
			selector.onSelection.Add(HandleSelection);
			panel.AddInternalComponent(selector);

			RETURN panel;
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			showDetails := FALSE; showGeometry := FALSE;
			Init(400, 300, FALSE);
			vc := CreateForm();
			SetContent(vc);
			WMWindowManager.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("Partition Selector Test Window"))
		END New;

	END TestWindow;

VAR
	PrototypeShowDetails, PrototypeShowDiskGeometry : WMProperties.BooleanProperty;
	PrototypeClSelected, PrototypeClBackground : WMProperties.ColorProperty;

	StrPartitionSelector, StrOperationSelector : Strings.String;

PROCEDURE TestPartitionSelector*;
VAR window : TestWindow;
BEGIN
	NEW(window);
END TestPartitionSelector;

PROCEDURE GenPartitionSelector*() : XML.Element;
VAR p : PartitionSelector;
BEGIN
	NEW(p); RETURN p;
END GenPartitionSelector;

PROCEDURE GenOperationSelector*() : XML.Element;
VAR o : OperationSelector;
BEGIN
	NEW(o); RETURN o;
END GenOperationSelector;

PROCEDURE InitStrings;
BEGIN
	StrPartitionSelector := Strings.NewString("PartitionSelector");
	StrOperationSelector := Strings.NewString("OperationSelector");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(PrototypeShowDetails, NIL, Strings.NewString("showDetails"), Strings.NewString("Show detailed textual information as grid"));
	PrototypeShowDetails.Set(FALSE);
	NEW(PrototypeShowDiskGeometry, NIL, Strings.NewString("showDiskGeometry"), Strings.NewString("Show disk geometry information in title"));
	PrototypeShowDiskGeometry.Set(FALSE);
	NEW(PrototypeClSelected, NIL, Strings.NewString("clSelected"), Strings.NewString("Color of selected partition"));
	PrototypeClSelected.Set(WMGraphics.Yellow);
	NEW(PrototypeClBackground, NIL, Strings.NewString("clBackground"), Strings.NewString("Background color of disk panels"));
	PrototypeClBackground.Set(LONGINT(0999999FFH));
END InitPrototypes;

BEGIN
	InitStrings;
	InitPrototypes;
END WMPartitionsComponents.

WMPartitionsComponents.TestPartitionSelector ~

SystemTools.Free WMPartitionsComponents ~
