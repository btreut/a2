MODULE PartitionEditor; (** AUTHOR "staubesv"; PURPOSE "Partition Table Editor Application"; *)

IMPORT
	Modules, Streams, Commands, Strings, PartitionTable := PartitionEditorTable, PartitionEditorComponents,
	WMGraphics, WMWindowManager,  WMMessages, WMRestorable,
	WMComponents, WMStandardComponents, WMEditors, WMDialogs;

CONST
	WindowTitle = "Partition Table Editor";
	WindowWidth = 680; WindowHeight = 140;

	Grey = LONGINT(0C0C0C0FFH);

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		blockNumberEditor, deviceNameEditor : WMEditors.Editor;
		editor : PartitionEditorComponents.PartitionTableEditor;
		loadBtn, storeBtn, clearBtn : WMStandardComponents.Button;
		statusLabel : WMStandardComponents.Label;

		reader : Streams.StringReader;

		(**	Retrieve the blockNumber currently displayed in the blockNumberEditor. Returns FALSE
			if the string is no valid number *)
		PROCEDURE GetBlockNumber(VAR blockNumber : LONGINT) : BOOLEAN;
		VAR nbr : ARRAY 16 OF CHAR;
		BEGIN
			blockNumberEditor.GetAsString(nbr);
			reader.Reset;
			reader.SkipWhitespace;
			reader.Set(nbr);
			reader.Int(blockNumber, FALSE);
			RETURN (reader.res = Streams.Ok) OR (reader.res = Streams.EOF);
		END GetBlockNumber;

		PROCEDURE HandleButtons(sender, data : ANY);
		VAR
			deviceName : ARRAY 32 OF CHAR;
			pt : PartitionTable.PartitionTable; blockNumber, res : LONGINT;
			message: ARRAY 256 OF CHAR;
		BEGIN
			IF (sender = storeBtn) THEN
				deviceNameEditor.GetAsString(deviceName);
				Strings.TrimWS(deviceName);
				IF (deviceName # "") THEN
					pt := editor.Get();
					res := WMDialogs.Confirmation("Confirmation", "Do you really want to store the partition table?");
					IF (res = WMDialogs.ResYes) THEN
						IF GetBlockNumber(blockNumber) THEN
							PartitionTable.StorePartitionTable(deviceName, blockNumber, pt, res);
							IF (res # PartitionTable.Ok) THEN
								GetErrorMessage("Could not write block! ", deviceName, res, message);
								 WMDialogs.Error(WindowTitle, message);
							END;
						ELSE
							WMDialogs.Error(WindowTitle, "Block number invalid!");
						END;
					END;
				ELSE
					 WMDialogs.Error(WindowTitle, "No device name specified");
				END;
			ELSIF (sender = loadBtn) THEN
				deviceNameEditor.GetAsString(deviceName);
				IF (deviceName # "") THEN
					IF GetBlockNumber(blockNumber) THEN
						Load(deviceName, blockNumber);
					ELSE
						WMDialogs.Error(WindowTitle, "Block number invalid!");
					END;
				ELSE
					WMDialogs.Error(WindowTitle, "No device name specified");
				END;
			ELSIF (sender = clearBtn) THEN
				PartitionTable.Clear(pt);
				editor.Set(pt);
			END;
		END HandleButtons;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR panel, toolbar : WMStandardComponents.Panel; label : WMStandardComponents.Label;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignTop);
			toolbar.bounds.SetHeight(20);
			toolbar.fillColor.Set(Grey);
			panel.AddContent(toolbar);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft);
			label.bounds.SetWidth(60);
			label.caption.SetAOC(" Device:");
			toolbar.AddContent(label);

			NEW(deviceNameEditor); deviceNameEditor.alignment.Set(WMComponents.AlignLeft);
			deviceNameEditor.bounds.SetWidth(100);
			deviceNameEditor.tv.showBorder.Set(TRUE);
			deviceNameEditor.multiLine.Set(FALSE);
			deviceNameEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			deviceNameEditor.fillColor.Set(WMGraphics.White);
			toolbar.AddContent(deviceNameEditor);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft);
			label.bounds.SetWidth(80);
			label.caption.SetAOC(" Block (LBA):");
			toolbar.AddContent(label);

			NEW(blockNumberEditor); blockNumberEditor.alignment.Set(WMComponents.AlignLeft);
			blockNumberEditor.bounds.SetWidth(100);
			blockNumberEditor.tv.showBorder.Set(TRUE);
			blockNumberEditor.multiLine.Set(FALSE);
			blockNumberEditor.tv.textAlignV.Set(WMGraphics.AlignCenter);
			blockNumberEditor.fillColor.Set(WMGraphics.White);
			toolbar.AddContent(blockNumberEditor);

			NEW(loadBtn); loadBtn.alignment.Set(WMComponents.AlignLeft);
			loadBtn.caption.SetAOC("Load");
			loadBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(loadBtn);

			NEW(storeBtn); storeBtn.alignment.Set(WMComponents.AlignLeft);
			storeBtn.caption.SetAOC("Store");
			storeBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(storeBtn);

			NEW(clearBtn); clearBtn.alignment.Set(WMComponents.AlignRight);
			clearBtn.caption.SetAOC("Clear");
			clearBtn.onClick.Add(HandleButtons);
			toolbar.AddContent(clearBtn);

			NEW(statusLabel); statusLabel.alignment.Set(WMComponents.AlignBottom);
			statusLabel.bounds.SetHeight(20);
			statusLabel.fillColor.Set(Grey);

			NEW(editor); editor.alignment.Set(WMComponents.AlignBottom);
			editor.bounds.SetHeight(120);
			editor.changeHandler := HandleChange;
			panel.AddContent(editor);

			RETURN panel;
		END CreateForm;

		PROCEDURE &New*(context : WMRestorable.Context);
		BEGIN
			IncCount;
			NEW(reader, 256);

			Init(WindowWidth, WindowHeight, FALSE);

			SetTitle(Strings.NewString(WindowTitle));
			SetContent(CreateForm());

			IF (context # NIL) THEN
				WMRestorable.AddByContext(SELF, context);
			ELSE
				WMWindowManager.DefaultAddWindow(SELF)
			END;
		END New;

		PROCEDURE Load(deviceName : ARRAY OF CHAR; block : LONGINT);
		VAR pt : PartitionTable.PartitionTable; blockStr : ARRAY 16 OF CHAR; message: ARRAY 256 OF CHAR; res : LONGINT;
		BEGIN
			Strings.TrimWS(deviceName);
			deviceNameEditor.SetAsString(deviceName);
			Strings.IntToStr(block, blockStr);
			blockNumberEditor.SetAsString(blockStr);
			IF (deviceName # "") THEN
				IF GetBlockNumber(block) THEN
					pt := PartitionTable.LoadPartitionTable(deviceName, block, res);
					IF (res = PartitionTable.Ok) OR (res = PartitionTable.NoSignature) THEN
						editor.Set(pt);
					ELSE
						GetErrorMessage("Could not load block!", deviceName, res, message);
						WMDialogs.Error(WindowTitle, message);
					END;
				ELSE
					WMDialogs.Error(WindowTitle, "Block number invalid!");
				END;
			ELSE
				WMDialogs.Error(WindowTitle, "No device name specified");
			END;
		END Load;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		(* Since the content of this window is not scalable, we don't allow window resizing *)
		PROCEDURE Resizing(VAR width, height : LONGINT);
		BEGIN
			width := WindowWidth; height := WindowHeight;
		END Resizing;

		PROCEDURE HandleChange(changeType : LONGINT; VAR partition : PartitionTable.Partition);
		VAR deviceName : ARRAY 32 OF CHAR; res : LONGINT;
		BEGIN
			deviceNameEditor.GetAsString(deviceName);
			PartitionTable.Changed(changeType, partition, deviceName, res);
			IF (res # PartitionTable.Ok) THEN
				WMDialogs.Warning(WindowTitle, "Field adjustion failed");
			END;
		END HandleChange;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					x.ext(WMRestorable.Storage).Add("Partition Table Editor", "PartitionEditor.Restore", SELF, NIL);
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE GetErrorMessage(CONST string1, devicename : ARRAY OF CHAR; res : LONGINT; VAR message: ARRAY OF CHAR);
VAR nbr : ARRAY 8 OF CHAR;
BEGIN
	COPY(string1, message);
	CASE res OF
		|PartitionTable.DeviceNotFound:
			Strings.Append(message, " (Device '"); Strings.Append(message, devicename); Strings.Append(message, "' not found)");
		|PartitionTable.BlocksizeNotSupported:
			Strings.Append(message, " (Block size not supported)");
	ELSE
		Strings.Append(message, " (res: ");
		Strings.IntToStr(res, nbr); Strings.Append(message, nbr); Strings.Append(message, ")");
	END;
END GetErrorMessage;

(* open an editor window *)
PROCEDURE Open*(context : Commands.Context); (** DeviceName [Block] ~ *)
VAR window : Window; deviceName : ARRAY 128 OF CHAR; block : LONGINT;
BEGIN
	deviceName := ""; block := 0;
	context.arg.SkipWhitespace; context.arg.String(deviceName);
	context.arg.SkipWhitespace; context.arg.Int(block, FALSE);
	NEW(window, NIL);
	IF (deviceName # "") THEN
		window.Load(deviceName, block);
	END;
END Open;

(* if system context is stored via menu system -> SaveDesktop, then restore the window like it was at next bootup *)
PROCEDURE Restore*(context : WMRestorable.Context);
VAR window : Window;
BEGIN
	NEW(window, context)
END Restore;

(* increase the number of open windows, for window book kepping and correct cleanup *)
PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

(* decrease the number of open windows, for window book kepping and correct cleanup *)
PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

(* Cleanup: close all open windows when this module gets unloaded or when the system goes down *)
PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END PartitionEditor.

PC.Compile \s PartitionEditorTable.Mod PartitionEditorComponents.Mod PartitionEditor.Mod ~

SystemTools.Free PartitionEditor PartitionEditorComponents PartitionEditorTable ~

PartitionEditor.Open ~

VirtualDisks.Create Test.Dsk 2880 512 80 2 18 ~  1.44MB floppy disk :)

VirtualDisks.Install Test Test.Dsk  512 80 2 18 ~

VirtualDisks.Uninstall Test ~

ZipTool.Add PartitionEditor.zip
	PartitionEditorTable.Mod
	PartitionEditorComponents.Mod
	PartitionEditor.Mod
~