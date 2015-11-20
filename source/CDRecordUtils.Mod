MODULE CDRecordUtils;

IMPORT
	SYSTEM, Codecs, Strings, Streams, Files, SoundDevices, KernelLog, Disks, DiskVolumes, FATVolumes, ISO9660Volumes, ATADisks,
	WMWindowManager, WMComponents, WMStandardComponents, WMFileManager, WMSystemComponents, WMGrids, WMStringGrids, WMDialogs,
 	WMEvents, WMTabComponents, WMProperties, WMGraphics, WMRectangles;

CONST
	MaxLen = 256;
	ResOk=0; ResErr=1;

	(* mpeg *)
	MPEGVer1 = 3;
	MPEGVer2 =  2;
	MPEGVer25 = 0;

	(* wave compression *)
	CUnknown* = 0H;
	CPCM* = 1H;
	CMsADPCM* = 2H;

	(* Errors *)
	ErrFileNotFound* = 100;
	ErrNoISOImage* = 101;

	White = 0FFFFFFFFH;
	Black = 0000000FFH;
	LightGray = (0C8C8C8FFH);
	DarkGray = (0A0A0A0FFH);

TYPE
	String = Strings.String;

	Status* = OBJECT END Status;

	ConvertingStatus* = OBJECT(Status)
	VAR
		bytesEncoded*: LONGINT;
	END ConvertingStatus;

	StatusProc* = PROCEDURE {DELEGATE} (status: Status);

	WAVInfo* = OBJECT
		VAR
			compression*, size*, nofchannels*, samplerate*, encoding* : LONGINT;

		PROCEDURE Open*(filename : Strings.String): LONGINT;
		VAR
			bytesRead: LONGINT;
			file: Files.File;
			r: Files.Reader;
			buf: ARRAY 8 OF CHAR;
		BEGIN
			file := Files.Old(filename^);
			IF file = NIL THEN
				RETURN 1;
			END;
			Files.OpenReader(r, file, 0);
			(* read first chunk and check if file is a wav file *)
			buf[4] := 0X;
			r.Bytes(buf, 0, 4, bytesRead);
			IF buf # "RIFF" THEN
				RETURN ResErr;
			END;
			r.Bytes(buf, 0, 4, bytesRead);
			size := ConvertLE32Int(buf);
			(* Bluebottle's Wave Encoder only sets the header size
			IF size # file.Length() - 8 THEN
				RETURN ResErr;
			END;
			*)
			IF size < 1024 THEN size := file.Length() - 8; END;

			r.Bytes(buf, 0, 4, bytesRead);
			IF buf # "WAVE" THEN
				RETURN ResErr;
			END;

			(* format chunk *)
			r.Bytes(buf, 0, 4, bytesRead);
			IF buf # "fmt " THEN
				RETURN ResErr;
			END;

			r.Bytes(buf, 0, 4, bytesRead);

			r.Bytes(buf, 0, 2, bytesRead);
			compression := ConvertLE16Int(buf);

			r.Bytes(buf, 0, 2, bytesRead);
			nofchannels := ConvertLE16Int(buf);

			r.Bytes(buf, 0, 4, bytesRead);
			samplerate := ConvertLE32Int(buf);

			r.Bytes(buf, 0, 6, bytesRead);
			r.Bytes(buf, 0, 2, bytesRead);
			encoding := ConvertLE16Int(buf);

			RETURN ResOk;
		END Open;

	END WAVInfo;

	Frame = RECORD
		mpegver, bitrate, samplerate, padding, layer, size : LONGINT
	END;

	ID3v1* = OBJECT
	VAR
		Title*, Artist*, Album: ARRAY 31 OF CHAR;
	END ID3v1;

	MP3Info* = OBJECT
	VAR
		nofframes*, playtime* : LONGINT;
		id3v1*: ID3v1;
		bitrateTable: ARRAY 6, 16 OF LONGINT;

		PROCEDURE &New*;
		BEGIN
			InitTable(bitrateTable);
			id3v1 := NIL;
		END New;

		PROCEDURE GetNextFrame(r: Files.Reader; VAR frame: Frame): LONGINT;
		VAR
			n, start, bytesRead, tmp: LONGINT;
			chr: CHAR;
			buf : ARRAY 4 OF CHAR;

		BEGIN
			start := -1; n := 0;
			(* find first frame in first 10k by comparing sync pattern *)
			REPEAT
				r.Bytes(buf, 0, 1, bytesRead);
				IF (bytesRead = 1) & (buf[0] = 0FFX) THEN
					chr := r.Peek();
					IF ASH(ORD(chr), -5) = 7 THEN
						start := n;
						r.Bytes(buf, 1, 3, bytesRead);
					END;
				END;
				INC(n, 1);
			UNTIL (n > 10000) OR (bytesRead < 1) OR (start # -1);

			IF start = -1 THEN
				RETURN ResErr;
			END;

			(* MPEG version *)
			tmp := ASH(ORD(buf[1]), -3) MOD 4;
			CASE tmp OF
				  0: frame.mpegver := MPEGVer25; (* 2.5 *)
				| 2: frame.mpegver := MPEGVer2;
				| 3: frame.mpegver := MPEGVer1;
				ELSE RETURN ResErr;
			END;

			(* MPEG Layer *)
			tmp := ASH(ORD(buf[1]), -1) MOD 4;
			CASE tmp OF
				  1: frame.layer := 3;
				| 2: frame.layer := 2;
				| 3: frame.layer := 1;
				ELSE RETURN ResErr;
			END;

			(* Bitrate *)
			tmp := ASH(ORD(buf[2]), -4);
			IF frame.mpegver = MPEGVer1 THEN
				CASE frame.layer OF
					  1: frame.bitrate := bitrateTable[0][tmp];
					| 2: frame.bitrate := bitrateTable[1][tmp];
					| 3: frame.bitrate := bitrateTable[2][tmp];
					ELSE RETURN ResErr;
				END;
			ELSE
				CASE frame.layer OF
					  1: frame.bitrate := bitrateTable[3][tmp];
					| 2: frame.bitrate := bitrateTable[4][tmp];
					| 3: frame.bitrate := bitrateTable[5][tmp];
					ELSE RETURN ResErr;
				END;
			END;

			(* samplerate *)
			tmp := ASH(ORD(buf[2]), -2) MOD 4;
			IF frame.mpegver = MPEGVer1 THEN
				CASE tmp OF
					  0: frame.samplerate := 44100;
					| 1: frame.samplerate := 48000;
 					| 2: frame.samplerate := 32000;
 					ELSE RETURN ResErr;
 				END;
 			ELSIF frame.mpegver = MPEGVer2 THEN
 				CASE tmp OF
					  0: frame.samplerate := 22050;
					| 1: frame.samplerate := 24000;
 					| 2: frame.samplerate := 16000;
 					ELSE RETURN ResErr;
 				END;
 			ELSIF frame.mpegver = MPEGVer25 THEN
 				CASE tmp OF
					  0: frame.samplerate := 11025;
					| 1: frame.samplerate := 12000;
 					| 2: frame.samplerate := 8000;
 					ELSE RETURN ResErr;
 				END;
 			END;

 			frame.padding := ASH(ORD(buf[2]), -1) MOD 2;

 			IF frame.mpegver = MPEGVer1 THEN
 				IF frame.layer = 1 THEN
 					tmp := 48000;
 				ELSE
					tmp := 144000;
				END;
 			ELSE
 				IF frame.layer = 1 THEN
 					tmp := 24000
 				ELSE
 					tmp := 72000;
 				END;
 			END;

 			frame.size := tmp*frame.bitrate DIV frame.samplerate + frame.padding;
 			RETURN ResOk;
		END GetNextFrame;

		PROCEDURE Open*(filename: String): LONGINT;
		VAR
			file : Files.File;
			r: Files.Reader;
			frame: Frame;

		BEGIN
			nofframes := 0; playtime := 0;
			file := Files.Old(filename^);
			IF file = NIL THEN
				RETURN ResErr;
			END;

			Files.OpenReader(r, file, 0);
 			WHILE GetNextFrame(r, frame) = ResOk DO
 				INC(nofframes);
 				r.SkipBytes(frame.size-4);
 				INC(playtime, (8*frame.size) DIV frame.bitrate); (* in ms *)
 			END;

 			IF nofframes < 1 THEN RETURN ResErr END;
 			playtime := (playtime+1000-1) DIV 1000;

 			NEW(id3v1);
 			IF ReadID3v1(filename, id3v1) # ResOk THEN
 				id3v1 := NIL;
 			END;

			RETURN ResOk;
		END Open;

		PROCEDURE InitTable(VAR table: ARRAY OF ARRAY OF LONGINT);
		BEGIN
			table[0][0] := 0;			table[1][0] := 0;			table[2][0] := 0; 		table[3][0] := 0;			table[4][0] := 0; 		table[5][0] := 0;
			table[0][1] :=32;		table[1][1] := 32;		table[2][1] := 32; 		table[3][1] := 32;		table[4][1] := 8; 		table[5][1] := 8;
			table[0][2] :=64;		table[1][2] := 48; 		table[2][2] := 40; 		table[3][2] := 48; 		table[4][2] := 16; 		table[5][2] := 16;
			table[0][3] :=96;		table[1][3] := 56; 		table[2][3] := 48; 		table[3][3] := 56; 		table[4][3] := 24; 		table[5][3] := 24;
			table[0][4] :=128;		table[1][4] := 64;		table[2][4] := 56; 		table[3][4] := 64; 		table[4][4] := 32; 		table[5][4] := 32;
			table[0][5] :=160;		table[1][5] := 80; 		table[2][5] := 64; 		table[3][5] := 80;		table[4][5] := 40; 		table[5][5] := 64;
			table[0][6] :=192;		table[1][6] := 96; 		table[2][6] := 80; 		table[3][6] := 96; 		table[4][6] := 48 ;		table[5][6] := 80;
			table[0][7] :=224;		table[1][7] := 112;		table[2][7] := 96; 		table[3][7] := 112; 		table[4][7] := 56;  		table[5][7] := 56;
			table[0][8] :=256;		table[1][8] := 128; 		table[2][8] := 112; 		table[3][8] := 128; 		table[4][8] := 64; 		table[5][8] := 64;
			table[0][9] :=288;		table[1][9] := 160; 		table[2][9] := 128; 		table[3][9] := 144; 		table[4][9] := 80; 		table[5][9] := 128;
			table[0][10] := 320; 	table[1][10] := 192; 	table[2][10] := 160; 	table[3][10] := 160;	table[4][10] := 96; 		table[5][10] := 160;
			table[0][11] := 352; 	table[1][11] := 224; 	table[2][11] := 192; 	table[3][11] := 176;	table[4][11] := 112; 	table[5][11] := 112;
			table[0][12] := 384; 	table[1][12] := 256; 	table[2][12] := 224; 	table[3][12] := 192;	table[4][12] := 128; 	table[5][12] := 128;
			table[0][13] := 416; 	table[1][13] := 320; 	table[2][13] := 256; 	table[3][13] := 224;	table[4][13] := 144; 	table[5][13] := 256;
			table[0][14] := 448; 	table[1][14] := 384; 	table[2][14] := 320;	table[3][14] := 256; 	table[4][14] := 160; 	table[5][14] := 320;
			table[0][15] := -1; 	table[1][15] := -1; 	table[2][15] := -1;		table[3][15] := -1; 	table[4][15] := -1;  	table[5][15] := -1;
		END InitTable;

	END MP3Info;

	(* Window Components *)

	StandardDialog* = OBJECT(WMDialogs.Dialog);
	VAR
		width*, height*: LONGINT;
		ok*, abort*: WMStandardComponents.Button;
		content*: WMComponents.VisualComponent;
		buttonPanel*: WMStandardComponents.Panel;

		PROCEDURE &New*(title: String; bounds: WMRectangles.Rectangle; width, height: LONGINT);
		BEGIN
			x := bounds.l + ((bounds.r - bounds.l - width) DIV 2); IF x < 0 THEN x := 0 END;
			y := bounds.t + ((bounds.b - bounds.t - height) DIV 2); IF y < 20 THEN y := 20 END;
			SELF.width := width; SELF.height := height;
			SetTitle(title);
			errors := FALSE;
			CreateDialog;
			WireDialog;
			Init(content.bounds.GetWidth(), content.bounds.GetHeight(), FALSE);
			SetContent(content);
		END New;

		PROCEDURE Show*;
		BEGIN
			result := -1;
			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop});
			manager.SetFocus(SELF);
			content.Reset(NIL, NIL);
			BEGIN {EXCLUSIVE}
				AWAIT(result >= 0)
			END;
			manager.Remove(SELF)
		END Show;

		PROCEDURE ShowNonModal*;
		BEGIN
			result := -1;
			manager := WMWindowManager.GetDefaultManager();
			manager.Add(x, y, SELF, {WMWindowManager.FlagFrame, WMWindowManager.FlagStayOnTop});
			manager.SetFocus(SELF);
		END ShowNonModal;

		PROCEDURE CreateDialog*;
		VAR
			panel: WMStandardComponents.Panel;
			manager: WMWindowManager.WindowManager;
			windowStyle: WMWindowManager.WindowStyle;
		BEGIN
			manager := WMWindowManager.GetDefaultManager();
			windowStyle := manager.GetStyle();
			NEW(panel); panel.bounds.SetExtents(width, height);
			panel.fillColor.Set(windowStyle.bgColor);
			panel.takesFocus.Set(FALSE);

			NEW(buttonPanel); buttonPanel.bounds.SetHeight(30); buttonPanel.alignment.Set(WMComponents.AlignBottom);
			panel.AddContent(buttonPanel);

			NEW(abort);
			abort.bounds.SetExtents(60,30);
			abort.alignment.Set(WMComponents.AlignRight);
			abort.caption.SetAOC("Abort");
			buttonPanel.AddContent(abort);

			NEW(ok);
			ok.bounds.SetExtents(60,30);
			ok.alignment.Set(WMComponents.AlignRight);
			ok.caption.SetAOC("Ok");
			buttonPanel.AddContent(ok);

			content := panel
		END CreateDialog;

		PROCEDURE WireDialog;
		BEGIN
			ok.onClick.Add(Ok);
			abort.onClick.Add(Abort);
		END WireDialog;

	END StandardDialog;

	FileDialog* = OBJECT(StandardDialog);
		VAR
			path*: WMProperties.StringProperty;
			explorer: ExplorerPanel;

		PROCEDURE CreateDialog*;
		VAR
			bearing: WMRectangles.Rectangle;
		BEGIN
			CreateDialog^;
			NEW(path, NIL, NIL, NIL);
			path.Set(Strings.NewString(""));
			bearing := WMRectangles.MakeRect(3, 3, 3, 3);
			NEW(explorer);
			explorer.alignment.Set(WMComponents.AlignClient);
			content.AddContent(explorer);
		END CreateDialog;

		PROCEDURE Ok(sender, data: ANY);
		VAR
			dirEntries: WMSystemComponents.DirEntries;
			str: ARRAY MaxLen OF CHAR;
		BEGIN
			dirEntries := explorer.list.list.GetSelection();
			IF (LEN(dirEntries) > 0) & (dirEntries[0] # NIL) &(dirEntries[0].name # NIL) & (dirEntries[0].path # NIL) THEN
				COPY(dirEntries[0].path^, str);
				Strings.Append(str, "/");
				Strings.Append(str, dirEntries[0].name^);
				path.Set(Strings.NewString(str));
			END;
			Ok^(sender, data);
		END Ok;
	END FileDialog;

	PropertyPage* = OBJECT(WMComponents.VisualComponent);
	VAR
		tab: WMTabComponents.Tab;
		owner*: PropertySheet;

		PROCEDURE UpdateData*(save: BOOLEAN);
		END UpdateData;
	END PropertyPage;

	PropertySheet* = OBJECT(StandardDialog);
	VAR
		tabs: WMTabComponents.Tabs;
		curPage: PropertyPage;

		PROCEDURE CreateDialog*;
		VAR
			topPanel: WMStandardComponents.Panel;
		BEGIN
			CreateDialog^;
			NEW(topPanel);
			topPanel.bounds.SetHeight(20); topPanel.alignment.Set(WMComponents.AlignTop); topPanel.fillColor.Set(LightGray);
			content.AddContent(topPanel);
			NEW(tabs);
			tabs.alignment.Set(WMComponents.AlignTop); tabs.bounds.SetExtents(width,20);
			tabs.onSelectTab.Add(TabSelected);
			topPanel.AddContent(tabs);
		END CreateDialog;

		PROCEDURE TabSelected(sender, data: ANY);
		VAR
			tab: WMTabComponents.Tab;

		BEGIN
			IF (data # NIL) THEN
				tab := data(WMTabComponents.Tab);
				IF tab.data # NIL THEN
					IF curPage # NIL THEN
						content.RemoveContent(curPage);
					END;
					curPage := tab.data(PropertyPage);
					content.AddContent(curPage);
					curPage.Reset(NIL, NIL);
					curPage.Invalidate();
					curPage.Resized;
				END;
			END;
		END TabSelected;

		PROCEDURE AddPage*(page: PropertyPage; name: String);
		VAR
			tab: WMTabComponents.Tab;
		BEGIN
			page.owner := SELF;
			tab := tabs.NewTab();
			tabs.SetTabCaption(tab, name);
			tabs.SetTabData(tab, page);
			page.tab := tab;
			tabs.AddTab(tab);
		END AddPage;

		PROCEDURE SelectPage*(page: PropertyPage);
		BEGIN
			tabs.Select(page.tab);
			curPage := page;
			IF curPage # NIL THEN
				content.RemoveContent(page);
			END;
			content.AddContent(page);
		END SelectPage;

	END PropertySheet;


	ProgressBar* = OBJECT(WMComponents.VisualComponent)
	VAR
		start*, end*, cur*: WMProperties.Int32Property;
		color*: WMProperties.ColorProperty;
		borderColor*: WMProperties.ColorProperty;

		PROCEDURE &Init*;
		VAR
		BEGIN
			Init^();
			NEW(color, NIL, NIL, NIL);
			NEW(borderColor, NIL, NIL, NIL);
			NEW(start, NIL, NIL, NIL);
			NEW(end, NIL, NIL, NIL);
			NEW(cur, NIL, NIL, NIL);
		END Init;

		PROCEDURE SetPos*(pos: LONGINT);
		BEGIN
			IF pos < start.Get() THEN
				pos := start.Get();
			ELSIF pos > end.Get() THEN
				pos := end.Get();
			END;
			cur.Set(pos);
			Invalidate();
		END SetPos;

		PROCEDURE GetPos*(): LONGINT;
		BEGIN
			RETURN cur.Get();
		END GetPos;

		PROCEDURE SetRange*(start, end: LONGINT);
		BEGIN
			SELF.start.Set(start);
			SELF.end.Set(end);
			cur.Set(start);
		END SetRange;

		PROCEDURE StepIt*;
		BEGIN
			IF cur.Get() < end.Get() THEN
				cur.Set(cur.Get() + 1);
				Invalidate;
			END;
		END StepIt;

		PROCEDURE DrawBackground*(canvas: WMGraphics.Canvas);
		VAR
			rect: WMRectangles.Rectangle;
			width: LONGINT;
			pt: ARRAY 4 OF WMGraphics.Point2d;
		BEGIN
			IF end.Get() > start.Get() THEN
				width := (cur.Get()-start.Get()) * bounds.GetWidth() DIV (end.Get()-start.Get());
			END;
			rect := WMRectangles.MakeRect(0, 0, width, bounds.GetHeight());

			canvas.Fill(rect, color.Get(), WMGraphics.ModeCopy);

			rect := GetClientRect();
			rect.l := width;
			canvas.Fill(rect, fillColor.Get(), WMGraphics.ModeCopy);

			pt[0].x := 0; pt[0].y := 0;
			pt[1].x := bounds.GetWidth()-1; pt[1].y := 0;
			pt[2].x := bounds.GetWidth()-1; pt[2].y := bounds.GetHeight()-1;
			pt[3].x := 0; pt[3].y := bounds.GetHeight()-1;
			canvas.PolyLine(pt, 4, TRUE, borderColor.Get(), WMGraphics.ModeCopy);
		END DrawBackground;
	END ProgressBar;

	ListBox* =  OBJECT(WMComponents.VisualComponent);
	VAR
		grid: WMStringGrids.StringGrid;
		nofRows: LONGINT;
		caption*: WMProperties.StringProperty;
		label: WMStandardComponents.Label;
		selected*: WMProperties.Int32Property;
		onSelectionChanged* : WMEvents.EventSource;

		PROCEDURE &Init*;
		VAR
			leftPanel, rightPanel: WMStandardComponents.Panel;
		BEGIN
			Init^();
			NEW(caption, NIL, NIL, NIL); properties.Add(caption);
			NEW(selected, NIL, NIL, NIL); properties.Add(selected);
			NEW(onSelectionChanged, SELF, NIL, NIL, NIL);

			NEW(leftPanel); leftPanel.bounds.SetWidth(80); leftPanel.alignment.Set(WMComponents.AlignLeft);
			AddContent(leftPanel);

			NEW(label); label.bounds.SetHeight(14); label.alignment.Set(WMComponents.AlignTop); label.textColor.Set(Black);
			leftPanel.AddContent(label);

			NEW(rightPanel); rightPanel.alignment.Set(WMComponents.AlignClient);
			AddContent(rightPanel);

			NEW(grid);
			grid.alignment.Set(WMComponents.AlignClient);
			rightPanel.AddContent(grid);
			grid.onSelect.Add(SelectionHandler);
			grid.model.Acquire;
			grid.model.SetNofCols(1);
			grid.SetSelectionMode(WMGrids.GridSelectSingleRow);
			grid.model.Release;
		END Init;

		PROCEDURE Update*;
		BEGIN
			Reset(NIL, NIL);
			Invalidate();
			Resized;
		END Update;

		PROCEDURE Clear*;
		BEGIN
			nofRows := 0;
			grid.model.Acquire;
			grid.model.SetNofRows(nofRows);
			grid.model.Release;
		END Clear;

		PROCEDURE SelectionHandler*(sender, data: ANY);
		VAR
			scol, srow, ecol, erow: LONGINT;
		BEGIN
			grid. GetSelection(scol, srow, ecol, erow );
			selected.Set(srow);
		END SelectionHandler;

		PROCEDURE RecacheProperties;
		BEGIN
			label.caption.Set(caption.Get());
			grid.SetSelection(0, selected.Get(), 0, selected.Get());
			onSelectionChanged.Call(selected);
			RecacheProperties^;
		END RecacheProperties;

		PROCEDURE PropertyChanged(sender, property: ANY);
		BEGIN
			IF property = caption THEN
				label.caption.Set(caption.Get());
			ELSIF property = selected THEN
				grid.SetSelection(0, selected.Get(), 0, selected.Get());
				onSelectionChanged.Call(selected);
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE Add*(name: String; data: ANY);
		BEGIN
			grid.model.Acquire;
			INC(nofRows);
			grid.model.SetNofRows(nofRows);
			grid.model.SetCellText(0, nofRows-1, name);
			grid.model.SetCellData(0, nofRows-1, data);
			grid.model.Release;
		END Add;
	END ListBox;

	ExplorerPanel* = OBJECT(WMComponents.VisualComponent);
	VAR
		tree*: WMSystemComponents.DirectoryTree;
		list: WMFileManager.FileListPanel;

		PROCEDURE &Init*;
		VAR
			panel, sidePanel: WMStandardComponents.Panel;
			resizer: WMStandardComponents.Resizer;
		BEGIN
			Init^();
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

			NEW(tree);
			tree.alignment.Set(WMComponents.AlignClient);
			sidePanel.AddContent(tree);
			panel.AddContent(sidePanel);
			tree.onPathChanged.Add(PathChanged);

			NEW(list);
			list.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(list);
		END Init;

		PROCEDURE PathChanged(sender, data: ANY);
		BEGIN
			list.pathProp.Set(tree.currentPath.Get());
		END PathChanged;
	END ExplorerPanel;


PROCEDURE ReadID3v1(VAR filename: String; VAR id3v1: ID3v1): LONGINT;
VAR
	file: Files.File;
	r: Files.Reader;
	id, buf: ARRAY 128 OF CHAR;
	len, bytesRead: LONGINT;
BEGIN
	file := Files.Old(filename^);
	IF file = NIL THEN
		RETURN ResErr;
	END;
	Files.OpenReader(r, file, 0);
	len := file.Length();
	r.SkipBytes(len-128);
	r.Bytes(buf, 0, 128, bytesRead);
	Strings.Copy(buf, 0, 3, id);
	IF id # "TAG" THEN RETURN ResErr; END;
	Strings.Copy(buf, 3, 30, id3v1.Title);
	Strings.Copy(buf, 33, 30, id3v1.Artist);
	Strings.Copy(buf, 63, 30, id3v1.Album);
	RETURN ResOk;

END ReadID3v1;


PROCEDURE ConvertLE16Int*(CONST buf : ARRAY OF CHAR): LONGINT;
BEGIN
	RETURN ASH(ORD(buf[1]), 8) + ORD(buf[0]);
END ConvertLE16Int;

PROCEDURE ConvertLE32Int*(CONST buf : ARRAY OF CHAR): LONGINT;
BEGIN
	RETURN ASH(ORD(buf[3]), 24) + ASH(ORD(buf[2]), 16) + ASH(ORD(buf[1]), 8) + ORD(buf[0]);
END ConvertLE32Int;

PROCEDURE ConvertBE16Int*(CONST buf : ARRAY OF CHAR): LONGINT;
BEGIN
	RETURN ASH(ORD(buf[0]), 8) + ORD(buf[1]);
END ConvertBE16Int;

PROCEDURE ConvertBE32Int*(CONST buf : ARRAY OF CHAR): LONGINT;
BEGIN
	RETURN ASH(ORD(buf[0]), 24) + ASH(ORD(buf[1]), 16) + ASH(ORD(buf[2]), 8) + ORD(buf[3]);
END ConvertBE32Int;


PROCEDURE SetLE16*(x: INTEGER; VAR dst : ARRAY OF CHAR);
BEGIN
	dst[0] := CHR(x MOD 100H);
	dst[1] := CHR(x DIV 100H MOD 100H);
END SetLE16;

PROCEDURE SetLE32*(x: LONGINT; VAR dst: ARRAY OF CHAR);
BEGIN
	dst[0] := CHR(x MOD 100H);
	dst[1] := CHR(x DIV 100H MOD 100H);
	dst[2] := CHR(x DIV 10000H MOD 100H);
	dst[3] := CHR(x DIV 1000000H MOD 100H);
END SetLE32;

PROCEDURE SetBE16*(x: INTEGER; VAR dst : ARRAY OF CHAR);
BEGIN
	dst[1] := CHR(x MOD 100H);
	dst[0] := CHR(x DIV 100H MOD 100H);
END SetBE16;

PROCEDURE SetBE32*(x: LONGINT; VAR dst: ARRAY OF CHAR);
BEGIN
	dst[3] := CHR(x MOD 100H);
	dst[2] := CHR(x DIV 100H MOD 100H);
	dst[1] := CHR(x DIV 10000H MOD 100H);
	dst[0] := CHR(x DIV 1000000H MOD 100H);
END SetBE32;

PROCEDURE Mp3ToWave*(srcFileName, destFileName : Strings.String; onConvertStatusChanged: StatusProc) : LONGINT;
VAR
	res: LONGINT;
	srcFile, destFile : Files.File;
	decoder: Codecs.AudioDecoder;
	encoder: Codecs.AudioEncoder;
	in : Streams.Reader;
	out : Files.Writer;
	buffer : SoundDevices.Buffer;
	convertStatus: ConvertingStatus;
	bytesEncoded: LONGINT;
BEGIN
	NEW(convertStatus);
	decoder := Codecs.GetAudioDecoder("MP3");
	IF decoder = NIL THEN
		KernelLog.String("Could not open MP3DEcoder");
		RETURN ResErr;
	END;

	encoder := Codecs.GetAudioEncoder("WAV");
	IF encoder = NIL THEN
		KernelLog.String("Could not open WAV Encoder");
		RETURN ResErr;
	END;

	srcFile := Files.Old(srcFileName^);
	destFile := Files.New(destFileName^);
	IF destFile = NIL THEN
		RETURN ResErr;
	END;
	Files.Register(destFile);
	Files.OpenWriter(out, destFile, 0);
	in := Codecs.OpenInputStream(srcFileName^);
	IF (in = NIL) OR (out = NIL) THEN
		RETURN ResErr;
	END;

	decoder.Open(in, res);
	decoder.SetStreamLength(srcFile.Length());
	NEW(buffer);
	buffer.len := 4096;
	NEW(buffer.data, 4096);

	encoder.Open(out, 44100, 16, 2, res);
	WHILE decoder.HasMoreData() & (res = ResOk) DO
		decoder.FillBuffer(buffer);
		encoder.Write(buffer, res);
		INC(bytesEncoded, buffer.len);
		IF onConvertStatusChanged # NIL THEN
			convertStatus.bytesEncoded := bytesEncoded;
			onConvertStatusChanged(convertStatus);
		END;
	END;
	encoder.Close(res);
	RETURN res;

END Mp3ToWave;

PROCEDURE GetFreeSpace*(CONST destination: ARRAY OF CHAR; VAR freeSpace: LONGINT): LONGINT;
VAR
	fs: Files.FileSystem;
	prefix, name: ARRAY MaxLen OF CHAR;
	res: LONGINT;
BEGIN
	res := ResErr;
	Files.SplitName(destination, prefix, name);
	fs := Files.This(prefix);
	IF fs # NIL THEN
		freeSpace := (fs.vol.Available() DIV 1024) * fs.vol.blockSize;
		res := ResOk;
	END;
	RETURN res;
END GetFreeSpace;

PROCEDURE IsReadOnly*(CONST destination: ARRAY OF CHAR; VAR readOnly: BOOLEAN): LONGINT;
VAR
	fs: Files.FileSystem;
	prefix, name: ARRAY MaxLen OF CHAR;
	res: LONGINT;
BEGIN
	res := ResErr;
	Files.SplitName(destination, prefix, name);
	fs := Files.This(prefix);
	IF (fs # NIL) & (fs.vol # NIL) THEN
		readOnly := Files.ReadOnly IN fs.vol.flags;
		res := ResOk;
	END;
	RETURN res;
END IsReadOnly;

PROCEDURE GetDevice*(file: Files.File; VAR device: Disks.Device): LONGINT;
VAR
	fs: Files.FileSystem;
	res: LONGINT;
BEGIN
	res := ResErr;
	fs := file.fs;
	IF (fs # NIL) & (fs.vol # NIL) THEN
		IF fs.vol IS DiskVolumes.Volume THEN
			device := fs.vol(DiskVolumes.Volume).dev;
			res := ResOk;
		ELSIF fs.vol IS FATVolumes.Volume THEN
			device := fs.vol(FATVolumes.Volume).dev;
			res := ResOk;
		ELSIF fs.vol IS ISO9660Volumes.Volume THEN
			device := fs.vol(FATVolumes.Volume).dev;
			res := ResOk;
		END;
	END;
	RETURN res;
END GetDevice;

PROCEDURE IsOnSameController*(device1, device2: Disks.Device): BOOLEAN;
BEGIN
	IF (device1 IS ATADisks.Device) & (device2 IS ATADisks.Device) THEN
		RETURN device1(ATADisks.Device).controller = device2(ATADisks.Device).controller;
	END;
	RETURN FALSE;
END IsOnSameController;

PROCEDURE ClearBuffer*(VAR buf: ARRAY OF CHAR; ofs, len: LONGINT);
VAR
	adr: ADDRESS;
	rem: SIZE;
BEGIN
	ASSERT((ofs+len) <= LEN(buf));
	adr := ADDRESSOF(buf);
	INC(adr, ofs);
	rem := adr MOD 4;
	WHILE rem > 0 DO
		SYSTEM.PUT8(adr, 0X);
		DEC(rem); INC(adr); DEC(len);
	END;
	WHILE len >= 4 DO
		SYSTEM.PUT32(adr, 0H);
		INC(adr, 4); DEC(len, 4);
	END;
	WHILE len > 0 DO
		SYSTEM.PUT8(adr, 0X);
		INC(adr); DEC(len);
	END;
END ClearBuffer;

END CDRecordUtils.