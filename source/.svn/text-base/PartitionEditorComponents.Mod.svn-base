MODULE PartitionEditorComponents; (** AUTHOR "staubesv"; PURPOSE "Visual components used by the Partition Editor"; *)

IMPORT
	Strings, PartitionTable := PartitionEditorTable,
	WMGraphics, WMRectangles, WMComponents, WMStandardComponents, WMEditors;

CONST
	NoChangeFound = 0;
	SizeChanged* = PartitionTable.SizeChanged;
	StartLbaChanged* = PartitionTable.StartLbaChanged;
	StartChsChanged* = PartitionTable.StartChsChanged;
	EndLbaChanged* = PartitionTable.EndLbaChanged;
	EndChsChanged* = PartitionTable.EndChsChanged;

	LbaEditorWidth = 100;
	ChsEditorWidth = 40;
	LineHeight  = 20;

TYPE

	(* Visual representation of PartitionTable.Block datastructure *)
	BlockEditor = OBJECT (WMComponents.VisualComponent)
	VAR
		lbaEditor : WMEditors.Editor;
		cylinderEditor, headEditor, sectorEditor : WMEditors.Editor;

		PROCEDURE Set(block : PartitionTable.Block);
		VAR nbr : ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToStr(block.lba, nbr);lbaEditor.SetAsString(nbr);
			Strings.IntToStr(block.cylinder, nbr); cylinderEditor.SetAsString(nbr);
			Strings.IntToStr(block.head, nbr); headEditor.SetAsString(nbr);
			Strings.IntToStr(block.sector, nbr); sectorEditor.SetAsString(nbr);
		END Set;

		PROCEDURE Get() : PartitionTable.Block;
		VAR block : PartitionTable.Block; nbr : ARRAY 16 OF CHAR;
		BEGIN
			lbaEditor.GetAsString(nbr); Strings.StrToInt(nbr, block.lba);
			cylinderEditor.GetAsString(nbr); Strings.StrToInt(nbr, block.cylinder);
			headEditor.GetAsString(nbr); Strings.StrToInt(nbr, block.head);
			sectorEditor.GetAsString(nbr); Strings.StrToInt(nbr, block.sector);
			RETURN block;
		END Get;

		PROCEDURE Clear;
		BEGIN
			lbaEditor.SetAsString("");
			cylinderEditor.SetAsString("");
			headEditor.SetAsString("");
			sectorEditor.SetAsString("");
		END Clear;

		PROCEDURE GetTitle(CONST caption : ARRAY OF CHAR) : WMComponents.VisualComponent;
		VAR label : WMStandardComponents.Label;
		BEGIN
			CreateLabel(label, caption, LbaEditorWidth + 3*ChsEditorWidth); label.alignH.Set(WMGraphics.AlignCenter);
			label.bearing.Set(WMRectangles.MakeRect(5, 0, 5, 0));
			RETURN label;
		END GetTitle;

		PROCEDURE GetLegend() : WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel; label : WMStandardComponents.Label;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignLeft);
			panel.bounds.SetWidth(LbaEditorWidth + 3*ChsEditorWidth);
			panel.bearing.Set(WMRectangles.MakeRect(5, 0, 5, 0));

			CreateLabel(label, "LBA", LbaEditorWidth); label.alignH.Set(WMGraphics.AlignCenter);
			panel.AddContent(label);

			CreateLabel(label, "C", ChsEditorWidth); label.alignH.Set(WMGraphics.AlignCenter);
			panel.AddContent(label);

			CreateLabel(label, "H", ChsEditorWidth); label.alignH.Set(WMGraphics.AlignCenter);
			panel.AddContent(label);

			CreateLabel(label, "S", ChsEditorWidth); label.alignH.Set(WMGraphics.AlignCenter);
			panel.AddContent(label);

			RETURN panel;
		END GetLegend;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			bounds.SetWidth(LbaEditorWidth + 3*ChsEditorWidth);
			bearing.Set(WMRectangles.MakeRect(5, 0, 5, 0));
			CreateEditor(lbaEditor, LbaEditorWidth); AddContent(lbaEditor);
			CreateEditor(cylinderEditor, ChsEditorWidth); AddContent(cylinderEditor);
			CreateEditor(headEditor, ChsEditorWidth); AddContent(headEditor);
			CreateEditor(sectorEditor, ChsEditorWidth); AddContent(sectorEditor);
		END Init;

	END BlockEditor;

TYPE

	(* Visual representation of a partition table slot containing a field for the flag, the type, a start block and an end block *)
	PartitionEditor = OBJECT (WMComponents.VisualComponent)
	VAR
		typeEditor, flagEditor : WMEditors.Editor;
		startBlock, endBlock : BlockEditor;
		sizeEditor : WMEditors.Editor;

		PROCEDURE Set(partition : PartitionTable.Partition);
		VAR nbr : ARRAY 16 OF CHAR;
		BEGIN
			Strings.IntToStr(partition.type, nbr); typeEditor.SetAsString(nbr);
			Strings.IntToStr(ORD(partition.flag), nbr); flagEditor.SetAsString(nbr);
			startBlock.Set(partition.start);
			endBlock.Set(partition.end);
			Strings.IntToStr(partition.size, nbr); sizeEditor.SetAsString(nbr);
		END Set;

		PROCEDURE Get() : PartitionTable.Partition;
		VAR partition : PartitionTable.Partition ;nbr : ARRAY 16 OF CHAR; value : LONGINT;
		BEGIN
			typeEditor.GetAsString(nbr); Strings.StrToInt(nbr, partition.type);
			flagEditor.GetAsString(nbr); Strings.StrToInt(nbr, value); partition.flag := CHR(value);
			partition.start := startBlock.Get();
			partition.end := endBlock.Get();
			sizeEditor.GetAsString(nbr); Strings.StrToInt(nbr, partition.size);
			RETURN partition;
		END Get;

		PROCEDURE Clear;
		BEGIN
			typeEditor.SetAsString("");
			flagEditor.SetAsString("");
			startBlock.Clear;
			endBlock.Clear;
			sizeEditor.SetAsString("");
		END Clear;

		PROCEDURE GetTitle() : WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel; label : WMStandardComponents.Label;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignTop);
			panel.bounds.SetHeight(LineHeight);

			CreateLabel(label, "Flag", ChsEditorWidth); label.alignH.Set(WMGraphics.AlignCenter);
			panel.AddContent(label);

			CreateLabel(label, "Type", ChsEditorWidth); label.alignH.Set(WMGraphics.AlignCenter);
			panel.AddContent(label);

			panel.AddContent(startBlock.GetTitle("Start"));
			panel.AddContent(endBlock.GetTitle("End"));

			CreateLabel(label, "Size", LbaEditorWidth); label.alignH.Set(WMGraphics.AlignCenter);
			panel.AddContent(label);

			RETURN panel;
		END GetTitle;

		PROCEDURE GetLegend() : WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			NEW(panel); panel.alignment.Set(WMComponents.AlignTop);
			panel.bounds.SetHeight(LineHeight);
			panel.bearing.Set(WMRectangles.MakeRect(2 * ChsEditorWidth, 0, 0, 0));

			panel.AddContent(startBlock.GetLegend());
			panel.AddContent(endBlock.GetLegend());

			RETURN panel;
		END GetLegend;

		PROCEDURE &Init*;
		VAR rect : WMRectangles.Rectangle;
		BEGIN
			Init^;
			CreateEditor(flagEditor, ChsEditorWidth); AddContent(flagEditor);
			CreateEditor(typeEditor, ChsEditorWidth); AddContent(typeEditor);
			rect := WMRectangles.MakeRect(5, 0, 5, 0);
			NEW(startBlock); startBlock.alignment.Set(WMComponents.AlignLeft);
			startBlock.bearing.Set(rect);
			AddContent(startBlock);
			NEW(endBlock); endBlock.alignment.Set(WMComponents.AlignLeft);
			endBlock.bearing.Set(rect);
			AddContent(endBlock);
			CreateEditor(sizeEditor, LbaEditorWidth); AddContent(sizeEditor);
		END Init;

	END PartitionEditor;

TYPE
	ChangeHandler* = PROCEDURE {DELEGATE} (changeType : LONGINT; VAR partition : PartitionTable.Partition);

	(** The PartitionTableEditor component can display and edit the PartitionTable.PartitionTable datastructure *)
	PartitionTableEditor* = OBJECT (WMComponents.VisualComponent)
	VAR
		partitionEditors : ARRAY 4 OF PartitionEditor;
		partitionTable : PartitionTable.PartitionTable;
		changeHandler* : ChangeHandler;

		PROCEDURE Set*(CONST partitionTable : PartitionTable.PartitionTable);
		VAR i : LONGINT;
		BEGIN
			SELF.partitionTable := partitionTable;
			FOR i := 0 TO LEN(partitionEditors)-1 DO
				partitionEditors[i].Set(partitionTable[i]);
			END;
		END Set;

		PROCEDURE Get*() : PartitionTable.PartitionTable;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(partitionEditors)-1 DO
				partitionTable[i] := partitionEditors[i].Get();
			END;
			RETURN partitionTable;
		END Get;

		(** Discards all user changes by reloading the values from the currently set partition table *)
		PROCEDURE Discard*;
		BEGIN
			Set(partitionTable);
		END Discard;

		(** Clears all editable fields of the editor *)
		PROCEDURE Clear*;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(partitionEditors)-1 DO
				partitionEditors[i].Clear;
			END;
		END Clear;

		(* This handler is called whenever a text of any of the editors changes *)
		PROCEDURE HandleOnEnter(sender, data : ANY);
		VAR changeHandler : ChangeHandler; partition, changeType : LONGINT;
		BEGIN
			changeHandler := SELF.changeHandler;
			IF (changeHandler # NIL) THEN
				partition := -1;
				changeType := NoChangeFound;
				WHILE(changeType = NoChangeFound) & (partition < LEN(partitionEditors) - 1) DO
					INC(partition);
					IF (sender = partitionEditors[partition].sizeEditor) THEN
						changeType := SizeChanged;
					ELSIF (sender = partitionEditors[partition].startBlock.lbaEditor) THEN
						changeType := StartLbaChanged;
					ELSIF (sender = partitionEditors[partition].startBlock.cylinderEditor) OR
							(sender = partitionEditors[partition].startBlock.headEditor) OR
							(sender = partitionEditors[partition].startBlock.sectorEditor) THEN
						changeType := StartChsChanged;
					ELSIF (sender = partitionEditors[partition].endBlock.lbaEditor) THEN
						changeType := EndLbaChanged;
					ELSIF (sender = partitionEditors[partition].endBlock.cylinderEditor) OR
							(sender = partitionEditors[partition].endBlock.headEditor) OR
							(sender = partitionEditors[partition].endBlock.sectorEditor) THEN
						changeType := EndChsChanged;
					END;
				END;
				IF (changeType # NoChangeFound) THEN
					partitionTable[partition] := partitionEditors[partition].Get();
					changeHandler(changeType, partitionTable[partition]);
					partitionEditors[partition].Set(partitionTable[partition]);
				END;
			END;
		END HandleOnEnter;

		PROCEDURE RegisterOnEnterHandlers;
		VAR i : LONGINT;

			PROCEDURE RegisterBlock(blockEditor : BlockEditor);
			BEGIN
				blockEditor.lbaEditor.onEnter.Add(HandleOnEnter);
				blockEditor.cylinderEditor.onEnter.Add(HandleOnEnter);
				blockEditor.headEditor.onEnter.Add(HandleOnEnter);
				blockEditor.sectorEditor.onEnter.Add(HandleOnEnter);
			END RegisterBlock;

		BEGIN
			FOR i := 0 TO LEN(partitionEditors)-1 DO
				partitionEditors[i].sizeEditor.onEnter.Add(HandleOnEnter);
				RegisterBlock(partitionEditors[i].startBlock);
				RegisterBlock(partitionEditors[i].endBlock);
			END;
		END RegisterOnEnterHandlers;

		PROCEDURE &Init*;
		VAR
			panel : WMStandardComponents.Panel;
			label : WMStandardComponents.Label;
			vc : WMComponents.VisualComponent;
			caption : ARRAY 16 OF CHAR;
			i : LONGINT;
		BEGIN
			Init^;
			PartitionTable.Clear(partitionTable);
			fillColor.Set(WMGraphics.White);
			FOR i := 0 TO LEN(partitionEditors)-1 DO
				NEW(panel); panel.alignment.Set(WMComponents.AlignTop);
				panel.bounds.SetHeight(LineHeight);

				Strings.IntToStr(i+1, caption);
				CreateLabel(label, caption, 20); label.alignH.Set(WMGraphics.AlignCenter);

				NEW(partitionEditors[i]); partitionEditors[i].alignment.Set(WMComponents.AlignLeft);
				partitionEditors[i].bounds.SetWidth(700);

				IF (i = 0) THEN
					vc := partitionEditors[i].GetTitle();
					vc.bearing.Set(WMRectangles.MakeRect(20, 0, 0, 0));
					AddContent(vc);
				END;

				AddContent(panel);
				panel.AddContent(label);
				panel.AddContent(partitionEditors[i]);
			END;
			vc := partitionEditors[0].GetLegend(); vc.bearing.Set(WMRectangles.MakeRect(100, 0, 0, 0));
			AddContent(vc);
			Clear;
			RegisterOnEnterHandlers;
		END Init;

	END PartitionTableEditor;

PROCEDURE CreateLabel(VAR label : WMStandardComponents.Label; CONST caption : ARRAY OF CHAR; width : LONGINT);
BEGIN
	NEW(label);
	label.alignment.Set(WMComponents.AlignLeft);
	label.bounds.SetWidth(width);
	label.caption.SetAOC(caption);
END CreateLabel;

PROCEDURE CreateEditor(VAR editor : WMEditors.Editor; width : LONGINT);
BEGIN
	NEW(editor);
	editor.alignment.Set(WMComponents.AlignLeft);
	editor.bounds.SetWidth(width);
	editor.multiLine.Set(FALSE);
	editor.tv.textAlignV.Set(WMGraphics.AlignCenter);
	editor.tv.showBorder.Set(TRUE);
END CreateEditor;

END PartitionEditorComponents.

PartitionEditorComponents.Test ~

SystemTools.Free PartitionEditorComponents ~


