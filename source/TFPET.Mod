MODULE TFPET; (** AUTHOR "TF, PL"; PURPOSE "Programmer's Editing Tool"; *)
(**
 * Shortcuts:
 *
 *	CTRL-F:		Show search panel of current page, set focus to its editor and clear the content of the editor
 *	CTRL-N:	If search panel is visible: Find next occurence downwards
 *				elsif error grid is visible: Jump to next error position
 *	CTRL-P:		If search panel is visible: Find next occurence upwards
 *				elsif error grid is visible: Jump to previous error position
 *
 *	CTRL-0:		Set cursor to position zero
 *	CTRL-9:		Move cursor to end of text
 *
 *	CTRL-O:	Set focus to filename editor and clear its content
 *	CTRL-S:		Store current page
 *
 *	CTRL-M:	Toggle visibility of sidepanel
 *
 *	CTRL-H:		Compile file opened in current page
 *	CTRL-U:		Unload module opened in current  page
 *	CTRL-D:	Diff current tab to file
 *
 *	CTRL-DEL	Delete end-of-line whitespace in current page
 *
 *	ALT-INS	Uncomment selected code of commented
 *	ALT-DEL	Comment selected code
 *
 *	CTRL-PgUp	Load PET state from file
 * 	CTRL-PgDn	Save PET state to file
 *
 *	CTRL-SHIFT-Tab		Select previous tab
 *	CTRL-Tab			Select next tab
 *
 *	SHIFT-F1..F12	Store current cursor position
 *	CTRL-F1..F12	Recall cursor position
 *
 * When the filename editor has the keyboard focus:
 *
 *	ESC				Reset filename to filename of currently opened tab
 *	ENTER			Open  file
 *	SHIFT_ENTER	Open file in new PET window instance
 *)

IMPORT
	KernelLog, Modules, Commands, Options, Streams, Inputs, Files, WMRestorable, XML, XMLScanner, XMLParser, XMLObjects,
	WMStandardComponents, WMGraphics, CompilerInterface,
	WMComponents, WMRectangles, WMMessages, WMDialogs,
	WMTextView, WMEditors, Strings, TextUtilities, Texts,
	WMWindowManager, WMGrids, WMMacros, WMPopups, WMDropTarget, WMDiagnostics,
	PETTrees, Configuration, Codecs, WMTabComponents, UndoManager, WMSearchComponents, WhitespaceRemover,
	TFModuleTrees;

CONST
	WindowWidth = 800; WindowHeight = 600;

	(* Default Settings for all PET instances *)

	(* backup levels when storing a file *)
	No = 0; (* don't create backup file *)
	Yes = 1; (* create backup file *)
	Paranoid = 2; (* create backup file for each store *)

	(* General *)
	DefaultBackupOnStore = No;
	DefaultBackupOnCompile = FALSE;
	DefaultShowPathInTabs = FALSE;
	DefaultScratchPanelHeight = 250;
	DefaultEnableWhitespaceWarnings = FALSE;
	DefaultShowLineNumbers = FALSE;
	DefaultIndicateTabs = FALSE;
	DefaultCurrentLineColor = 0;

	(* Compiler *)
	DefaultCompilerName = "Fox";
	DefaultCompilerCaption = "Compile";
	DefaultCompilerOptions = "-b=AMD --warnings";
	DefaultCompilerLoadModule = "Compiler";
	DefaultCompilerFileExtension = "MOD";
	DefaultCompilerFindPC = TRUE;

	(* Diff *)
	(* The Diff shortcurt will use the DiffCommand to compare the file currently opened in PET to a file specified by the user... *)
	DefaultDiffCommand = "WMDiff.Open";
	(* PET will suggest a filename based on the following constants: *)
	DefaultDiffPrefix = "";		(* Add this string as prefix to the current filename (e.g. path) *)
	DefaultDiffSuffix = ".Bak";	(* Add this string as suffix to the current filename (e.g. ".Bak") *)

	(* Search *)
	DefaultSearchWrap = FALSE;
	DefaultSearchCaseSensitive = TRUE;
	DefaultSearchHighlightAll = FALSE;

	(* If you really don't like any shortcuts, disable them! *)
	DisableShortcuts = FALSE;

	BackupOnCompileFilename = "PETBackup.Mod.Bak";

	ScratchTextFilename = "PETScratch.Text";
	StateFileExtension = ".pet";

	SearchStringMaxLen = 128;

	MaxNbrOfTabs = 100;
	MaxNbrOfCompilers = 8;

	WindowTitle = "TF Programmer's Editing Tool v2.1";

	DefaultTextFormat = "UTF-8";

	EditorFocus = 1;
	SplitEditorFocus = 2;

TYPE

	CompilerOptions = ARRAY 256 OF CHAR;
	Filename = ARRAY 256 OF CHAR;
	String = ARRAY 128 OF CHAR;
	SearchString = ARRAY SearchStringMaxLen OF CHAR;

TYPE
	CompilerSettings = RECORD
		name : ARRAY 32 OF CHAR; 			(* name of compiler (same as in CompilerInterface) *)
		caption : ARRAY 16 OF CHAR;		(* Caption of "compile" button *)
		options : CompilerOptions;			(* default compiler options *)
		fileExtension : ARRAY 16 OF CHAR;	(* file extension *)
		loadmodule : Filename;				(* module to be loaded to register compiler at CompilerInterface *)
		genTree : ARRAY 128 OF CHAR;		(* Factory procedure to generate a sidepanel tree *)
		findPC : BOOLEAN;					(* Use Find PC button? *)
	END;

	(* Global PET settings for all window instances *)
	Settings = OBJECT
	VAR
		(* General *)
		backupOnStore : LONGINT; (* No | Yes | Always *)
		backupOnCompile : BOOLEAN;
		showPathInTabs : BOOLEAN;
		scratchPanelHeight : LONGINT;
		enableWhitespaceWarnings : BOOLEAN;
		showLineNumbers : BOOLEAN;
		indicateTabs : BOOLEAN;
		currentLineColor : LONGINT;

		(* Compiler *)
		defaultCompilerOptions : CompilerOptions;
		defaultCompilerSettings : CompilerSettings;
		compilers : ARRAY MaxNbrOfCompilers OF CompilerSettings;
		nofCompilers : LONGINT;

		(* Diff *)
		diffCommand, diffPrefix, diffSuffix : String;

		(* Search *)
		searchWrap, searchHighlightAll, searchCaseSensitive : BOOLEAN;

		(* Initialize settings to default values *)
		PROCEDURE &Init*;
		BEGIN
			(* General *)
			backupOnStore := DefaultBackupOnStore;
			backupOnCompile := DefaultBackupOnCompile;
			showPathInTabs := DefaultShowPathInTabs;
			scratchPanelHeight := DefaultScratchPanelHeight;
			enableWhitespaceWarnings := DefaultEnableWhitespaceWarnings;
			showLineNumbers := DefaultShowLineNumbers;
			indicateTabs := DefaultIndicateTabs;
			currentLineColor := DefaultCurrentLineColor;
			(* Compiler *)
			COPY(DefaultCompilerOptions, defaultCompilerOptions);
			nofCompilers := 0;
			defaultCompilerSettings.name := DefaultCompilerName;
			defaultCompilerSettings.caption := DefaultCompilerCaption;
			defaultCompilerSettings.options := DefaultCompilerOptions;
			defaultCompilerSettings.fileExtension := DefaultCompilerFileExtension;
			defaultCompilerSettings.loadmodule := DefaultCompilerLoadModule;
			defaultCompilerSettings.genTree := "";
			defaultCompilerSettings.findPC := DefaultCompilerFindPC;
			(* Diff *)
			diffCommand := DefaultDiffCommand; diffPrefix := DefaultDiffPrefix; diffSuffix := DefaultDiffSuffix;
			(* Search *)
			searchWrap := DefaultSearchWrap; searchCaseSensitive := DefaultSearchCaseSensitive; searchHighlightAll := DefaultSearchHighlightAll;
		END Init;

		PROCEDURE GetCompilerSettings(CONST filename : ARRAY OF CHAR) : CompilerSettings;
		VAR settings : CompilerSettings; i : LONGINT; extension : ARRAY 16 OF CHAR;
		BEGIN
			settings := defaultCompilerSettings;
			i := 0;
			LOOP
				IF (i >= nofCompilers) THEN (* no compiler found *) EXIT; END;
				extension := ".";
				Strings.Append(extension, compilers[i].fileExtension);
				IF ContainsFileExtension(filename, extension) THEN (* found *) EXIT; END;
				INC(i);
			END;
			IF (i < nofCompilers) THEN (* found *)
				settings := compilers[i];
			END;
			RETURN settings;
		END GetCompilerSettings;

		PROCEDURE LoadCompilerSettings;
		VAR
			element, e : XML.Element;
			sectionEnumerator : XMLObjects.Enumerator;
			p : ANY; string : XML.String;

			PROCEDURE GetAttributeValue(element : XML.Element; CONST attributeName : ARRAY OF CHAR; VAR value : ARRAY OF CHAR);
			VAR attribute : XML.Attribute;
			BEGIN
				ASSERT(element # NIL);
				COPY("", value);
				attribute := element.GetAttribute(attributeName);
				IF (attribute # NIL) THEN
					string := attribute.GetValue();
					IF (string # NIL) THEN
						COPY(string^, value);
					END;
				END;
			END GetAttributeValue;

			PROCEDURE ParseCompilerSettings(element : XML.Element; VAR settings : CompilerSettings);
			VAR enumerator : XMLObjects.Enumerator; e : XML.Element; p : ANY; string : XML.String; value : ARRAY 64OF CHAR;
			BEGIN
				ASSERT(element # NIL);
				GetAttributeValue(element, "name", value);
				IF (value # "") THEN
					COPY(value, settings.name);
					enumerator := element.GetContents();
					WHILE enumerator.HasMoreElements() DO
						p := enumerator.GetNext();
						IF (p IS XML.Element) THEN
							e := p (XML.Element);
							string := e.GetName();
							IF (string # NIL) & (string^ = "Setting") THEN
								GetAttributeValue(e, "name", value);
								IF (value = "caption") THEN
									GetAttributeValue(e, "value", settings.caption);
									IF (settings.caption = "") THEN settings.caption := "Action"; END;
								ELSIF (value = "options") THEN
									GetAttributeValue(e, "value", settings.options);
								ELSIF (value = "fileExtension") THEN
									GetAttributeValue(e, "value", settings.fileExtension);
								ELSIF (value = "loadmodule") THEN
									GetAttributeValue(e, "value", settings.loadmodule);
								ELSIF (value = "genTree") THEN
									GetAttributeValue(e, "value", value);
									Strings.TrimWS(value);
									COPY(value, settings.genTree);
								ELSIF (value = "findPC") THEN
									GetAttributeValue(e, "value", value);
									Strings.UpperCase(value); Strings.TrimWS(value);
									settings.findPC := (value = "TRUE");
								ELSE
									KernelLog.String("PET: Warning: Unknown compiler setting '");
									KernelLog.String(value); KernelLog.String("'"); KernelLog.Ln;
								END;
							ELSE
								KernelLog.String("PET: Warning: Expected 'Setting' element."); KernelLog.Ln;
							END;
						END;
					END;
				END;
			END ParseCompilerSettings;

		BEGIN
			element := Configuration.GetSection("Applications.PET.Compilers");
			IF (element # NIL) THEN
				sectionEnumerator := element.GetContents();
				WHILE sectionEnumerator.HasMoreElements() DO
					p := sectionEnumerator.GetNext();
					IF (p IS XML.Element) THEN
						e := p (XML.Element);
						string := e.GetName();
						IF (string # NIL) & (string^ = "Section") THEN	(* sanity check *)
							IF (nofCompilers < LEN(compilers)) THEN
								ParseCompilerSettings(e, compilers[nofCompilers]);
								INC(nofCompilers);
							ELSE
								KernelLog.String("PET: Warning: Maximum number of compiler settings exceeded."); KernelLog.Ln;
							END;
						ELSE
							KernelLog.String("PET: Warning: Expected 'Section' element."); KernelLog.Ln;
						END;
					END;
				END;
			END;
		END LoadCompilerSettings;

		(* Load settings from system configuration database *)
		PROCEDURE Load;
		VAR string : String; temp, res : LONGINT;
		BEGIN
			(* General *)
			Configuration.Get("Applications.PET.General.BackupOnStore", string, res);
			Strings.TrimWS(string);
			Strings.LowerCase(string);
			IF (string = "yes") THEN backupOnStore := Yes;
			ELSIF (string = "no") THEN backupOnStore := No;
			ELSIF (string = "paranoid") THEN backupOnStore := Paranoid;
			ELSE
				KernelLog.String("Warning: PET.Settings.Load: BackupOnStore # Yes | No | Paranoid, using default."); KernelLog.Ln;
				backupOnStore := DefaultBackupOnStore;
			END;

			IF (backupOnStore < No) OR (Paranoid < backupOnStore) THEN backupOnStore := DefaultBackupOnStore; END;
			Configuration.GetBoolean("Applications.PET.General.BackupOnCompile", backupOnCompile, res);
			Configuration.GetBoolean("Applications.PET.General.ShowPathInTabs", showPathInTabs, res);
			Configuration.GetInteger("Applications.PET.General.ScratchPanelHeight", scratchPanelHeight, res);
			Configuration.GetBoolean("Applications.PET.General.EnableWhitespaceWarnings", enableWhitespaceWarnings, res);
			Configuration.GetBoolean("Applications.PET.General.ShowLineNumbers", showLineNumbers, res);
			Configuration.GetBoolean("Applications.PET.General.IndicateTabs", indicateTabs, res);
			Configuration.Get("Applications.PET.General.CurrentLineColor", string, res);
			IF (res = Configuration.Ok) THEN
				Strings.TrimWS(string);
				Strings.HexStrToInt(string, temp, res);
				IF (res = Strings.Ok) THEN currentLineColor := temp; END;
			END;

			(* Compiler *)
			Configuration.Get("Applications.PET.Compilers.DefaultOptions", defaultCompilerOptions, res);
			LoadCompilerSettings;
			(* Diff *)
			Configuration.Get("Applications.PET.Diff.Command", diffCommand, res);
			Configuration.Get("Applications.PET.Diff.Prefix", diffPrefix, res);
			Configuration.Get("Applications.PET.Diff.Suffix", diffSuffix, res);
			(* Search *)
			Configuration.GetBoolean("Applications.PET.Search.Wrap", searchWrap, res);
			Configuration.GetBoolean("Applications.PET.Search.CaseSensitive", searchCaseSensitive, res);
			Configuration.GetBoolean("Applications.PET.Search.HighlightAll", searchHighlightAll, res);
		END Load;

	END Settings;

TYPE
	CaptionObject = OBJECT
	VAR caption : ARRAY 128 OF CHAR;

		PROCEDURE &New*(CONST caption: ARRAY OF CHAR);
		BEGIN
			COPY(caption, SELF.caption);
		END New;
	END CaptionObject;

TYPE
	(* Association between a text position and a key combination *)
	Position = OBJECT
	VAR
		marker : WMTextView.PositionMarker;
		ucs, keysym : LONGINT; flags : SET;
		next : Position;

		PROCEDURE &Init*(ucs, keysym : LONGINT; flags : SET);
		BEGIN
			SELF.ucs := ucs; SELF.keysym := keysym; SELF.flags := flags;
			marker := NIL; next := NIL;
		END Init;

	END Position;

	(* Store and Recall cursor positions in the main editor. Flags are ignored for now *)
	Positions = OBJECT
	VAR
		textView : WMTextView.TextView;
		positions : Position;

		PROCEDURE &Init*(textView : WMTextView.TextView);
		BEGIN
			ASSERT(textView # NIL);
			SELF.textView := textView;
		END Init;

		PROCEDURE FindPosition(ucs, keysym : LONGINT; flags : SET) : Position;
		VAR p : Position;
		BEGIN
			p := positions;
			WHILE (p # NIL) & ~((p.ucs = ucs) & (p.keysym = keysym) & (p.flags = flags)) DO
				p := p.next;
			END;
			RETURN p;
		END FindPosition;

		(* Associate current cursor position with the spec  ified key combination.  *)
		PROCEDURE StoreCurrentPosition(ucs, keysym : LONGINT; flags : SET);
		VAR newPosition : Position; intPos : LONGINT;
		BEGIN
			ASSERT(flags * { Inputs.Release} = {});
			newPosition := FindPosition(ucs, keysym, flags);
			IF (newPosition = NIL) THEN
				NEW(newPosition, ucs, keysym, flags);
				newPosition.marker := textView.CreatePositionMarker();
				newPosition.marker.SetVisible(FALSE);
				newPosition.next := positions;
				positions := newPosition;
			END;
			intPos := textView.GetInternalPos(textView.cursor.GetPosition());
			newPosition.marker.SetPosition(intPos);
		END StoreCurrentPosition;

		PROCEDURE RecallPosition(ucs, keysym : LONGINT; flags : SET);
		VAR position : Position;
		BEGIN
			position := FindPosition(ucs, keysym, flags);
			IF (position # NIL) THEN
				textView.cursor.SetPosition(position.marker.GetPosition());
			END;
		END RecallPosition;

	END Positions;

TYPE

	ScratchPanel = OBJECT(WMComponents.VisualComponent)
	VAR
		editor : WMEditors.Editor;
		label : WMStandardComponents.Label;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrScratchPanel);
			NEW(label); label.alignment.Set(WMComponents.AlignTop); label.bounds.SetHeight(20);
			label.fillColor.Set(0CCCCCCFFH); label.caption.SetAOC(" Scratch Text");
			AddContent(label);

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.tv.showBorder.Set(TRUE);
			AddContent(editor);
			editor.SetText(scratchText)
		END Init;

		PROCEDURE SetText(text : Texts.Text);
		BEGIN
			ASSERT(text # NIL);
			editor.SetText(text);
			label.caption.SetAOC(" Project Text");
		END SetText;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			StoreScratchText;
		END Finalize;

	END ScratchPanel;

	URLDropTarget = OBJECT(WMDropTarget.DropTarget);
	VAR win : Window;

		PROCEDURE &New*(win : Window);
		BEGIN
			SELF.win := win
		END New;

		PROCEDURE GetInterface(type : LONGINT) : WMDropTarget.DropInterface;
		VAR di : DropURL;
		BEGIN
			IF type = WMDropTarget.TypeURL THEN
				NEW(di, SELF.win);
				RETURN di
			ELSE RETURN NIL
			END
		END GetInterface;
	END URLDropTarget;

	DropURL = OBJECT(WMDropTarget.DropURLs)
	VAR win : Window;

		PROCEDURE &New*(win: Window);
		BEGIN
			SELF.win := win;
		END New;

		PROCEDURE URL(CONST url : ARRAY OF CHAR; VAR res : LONGINT);
		BEGIN
			win.Load(url, "AUTO");
			res := 0
		END URL;
	END DropURL;

TYPE

	PETPanel = OBJECT(WMComponents.VisualComponent)
	VAR
		editor, splitEditor : WMEditors.Editor;
		logEdit : WMEditors.Editor;
		scratchPanel, splitPanel : WMStandardComponents.Panel;
		scratch : ScratchPanel;
		sidePanel : WMStandardComponents.Panel;
		logPanel, editPanel: WMStandardComponents.Panel;
		searchPanel: WMSearchComponents.SearchPanel;

		errorGrid : WMDiagnostics.DiagnosticsView;
		diagnostics : WMDiagnostics.Model;

		tree : PETTrees.Tree;

		modified, splitted, wrap: BOOLEAN;
		focus : LONGINT;

		codecFormat: ARRAY 128 OF CHAR;
		autoCodecFormat: ARRAY 128 OF CHAR;

		name : Filename; (* name of tab (filename without path *)
		filename : Filename; (* Filename including path *)

		options : CompilerOptions;
		compilerSettings : CompilerSettings;

		showErrorMarkers : BOOLEAN;

		positions : Positions;

		owner : Window;

		PROCEDURE &InitPanel *(window: Window);
		VAR
			resizerH, resizerV: WMStandardComponents.Resizer;
			um: UndoManager.UndoManager;
			colWidths : WMGrids.Spacings;
			textViews : ARRAY 2 OF WMTextView.TextView;
		BEGIN
			Init;
			owner := window;
			tree := NIL;
			SetNameAsString(StrPETPanel);
			showErrorMarkers := TRUE;
			COPY("Untitled.Mod", filename);
			COPY("Untitled.Mod", name);

			(* -- left tool area *)
			NEW(sidePanel);
			sidePanel.bounds.SetWidth(250); sidePanel.alignment.Set(WMComponents.AlignLeft);
			AddContent(sidePanel);

			NEW(resizerH); resizerH.alignment.Set(WMComponents.AlignRight);
			resizerH.bounds.SetWidth(4);
			sidePanel.AddContent(resizerH);

			(* scratch panel *)
			NEW(scratchPanel);
			scratchPanel.bounds.SetHeight(250); scratchPanel.alignment.Set(WMComponents.AlignBottom);

			NEW(resizerV); resizerV.alignment.Set(WMComponents.AlignTop);
			resizerV.bounds.SetHeight(4);
			scratchPanel.AddContent(resizerV);

			NEW(scratch); scratch.alignment.Set(WMComponents.AlignClient);
			scratch.editor.tv.commandCaller := window;
			scratchPanel.AddContent(scratch);

			sidePanel.AddContent(scratchPanel);

			(* -- Editor Area *)
			NEW(editPanel); editPanel.alignment.Set(WMComponents.AlignClient);
			AddContent(editPanel);

			NEW(logPanel);
			logPanel.alignment.Set(WMComponents.AlignBottom);
			logPanel.bounds.SetHeight(130);

			NEW(resizerH); resizerH.alignment.Set(WMComponents.AlignTop);
			resizerH.bounds.SetHeight(4);
			logPanel.AddContent(resizerH);

			NEW(logEdit); logEdit.bounds.SetHeight(30); logEdit.alignment.Set(WMComponents.AlignBottom);
			logEdit.allowScrollbars.Set(FALSE);
			logEdit.tv.showBorder.Set(TRUE); logEdit.visible.Set(FALSE);

			NEW(resizerV); resizerV.alignment.Set(WMComponents.AlignTop);
			resizerV.bounds.SetHeight(4);
			logEdit.AddContent(resizerV);

			editPanel.AddContent(logEdit);
			editPanel.AddContent(logPanel);

			NEW(diagnostics);

			NEW(errorGrid);
			errorGrid.SetModel(diagnostics);
			errorGrid.alignment.Set(WMComponents.AlignClient);
			errorGrid.nofCols.Set(3);
			errorGrid.fixedRows.Set(1);
			errorGrid.adjustFocusPosition.Set(FALSE);

			NEW(colWidths, 3);
			colWidths[0] := 60;
			colWidths[1] := 40;
			colWidths[2] := 2048;
			errorGrid.SetColSpacings(colWidths);
			errorGrid.onClick.Add(ErrorClick);
			errorGrid.SetSelectionMode(WMGrids.GridSelectSingleRow);
			errorGrid.visible.Set(FALSE);
			logPanel.AddContent(errorGrid);

			NEW(searchPanel);
			searchPanel.alignment.Set(WMComponents.AlignBottom);
			searchPanel.bounds.SetHeight(40); searchPanel.visible.Set(FALSE);
			editPanel.AddContent(searchPanel);

			NEW(splitPanel);
			splitPanel.alignment.Set(WMComponents.AlignBottom);
			splitPanel.bounds.SetHeight(400);
			editPanel.AddContent(splitPanel);

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient); editor.tv.showBorder.Set(TRUE);
			editor.tv.SetExtFocusHandler(EditorFocusHandler);
			editPanel.AddContent(editor);
			editor.macros.Add(WMMacros.Handle);
			editor.multiLine.Set(TRUE);
			editor.tv.wrapMode.Set(WMTextView.NoWrap);
			editor.tv.onCursorChanged := CursorChanged;
			editor.tv.commandCaller := window;
			editor.text.onTextChanged.Add(TextChanged);
			editor.tv.showLineNumbers.Set(settings.showLineNumbers);
			editor.tv.indicateTabs.Set(settings.indicateTabs);
			editor.tv.clBgCurrentLine.Set(settings.currentLineColor);

			NEW(positions, editor.tv);
			searchPanel.SetText(editor.text);

			NEW(resizerV);
			resizerV.bounds.SetHeight(5); resizerV.alignment.Set(WMComponents.AlignTop);
			resizerV.fillColor.Set(0808080FFH);
			splitPanel.AddContent(resizerV);

			NEW(splitEditor); splitEditor.alignment.Set(WMComponents.AlignClient); splitEditor.tv.showBorder.Set(TRUE);
			splitEditor.tv.SetExtFocusHandler(SplitEditorFocusHandler);
			splitPanel.AddContent(splitEditor);
			splitEditor.macros.Add(WMMacros.Handle);
			splitEditor.multiLine.Set(TRUE);
			splitEditor.tv.wrapMode.Set(WMTextView.NoWrap);
			splitEditor.tv.commandCaller := window;
			splitEditor.SetText(editor.text);
			splitEditor.tv.showLineNumbers.Set(settings.showLineNumbers);
			splitEditor.tv.indicateTabs.Set(settings.indicateTabs);
			splitEditor.tv.clBgCurrentLine.Set(settings.currentLineColor);

			textViews[0] := editor.tv;
			textViews[1] := splitEditor.tv;
			errorGrid.SetTextViews(textViews);

			logPanel.visible.Set(FALSE);
			splitPanel.visible.Set(FALSE);

			modified := FALSE;
			splitted := FALSE;
			wrap := FALSE;
			codecFormat := "AUTO";
			autoCodecFormat := DefaultTextFormat;
			options := settings.defaultCompilerOptions;

			NEW(um, 1001, TRUE);
			editor.text.SetUndoManager(um);
			editor.SetUndoManager(um);
		END InitPanel;

		PROCEDURE CreateSidePanel(settings : CompilerSettings);
		VAR factory : PETTrees.Factory; strings : Strings.StringArray;
		BEGIN
			IF (tree # NIL) THEN sidePanel.RemoveContent(tree); tree := NIL END;
			IF settings.fileExtension = "MOD" THEN
				GETPROCEDURE("TFModuleTrees", "GenModuleTree", factory);
				IF (factory # NIL) THEN
					tree := factory();
				END
			ELSE
				IF (settings.genTree # "") THEN
					strings := Strings.Split(settings.genTree, ".");
					IF (LEN(strings) = 2) THEN
						GETPROCEDURE(strings[0]^, strings[1]^, factory);
						IF (factory # NIL) THEN
							tree := factory();
						END;
					END
				END
			END;
			IF (tree # NIL) THEN
				tree.alignment.Set(WMComponents.AlignClient);
				tree.SetEditor(editor);
				tree.onExpandNode.Add(OnNodeExpand);
				tree.onGoToFile.Add(OnGoToFile);
				tree.onGoToDefinition.Add(OnGoToDefinition);
				tree.onRefresh.Add(HandleTreeRefresh);
				sidePanel.AddContent(tree);
				tree.RefreshHandler(NIL, NIL);
				sidePanel.visible.Set(TRUE);
			ELSE
				sidePanel.visible.Set(FALSE);
				scratchPanel.alignment.Set(WMComponents.AlignClient);
				scratchPanel.bounds.Set(sidePanel.bounds.Get());
			END;
		END CreateSidePanel;

		PROCEDURE OnGoToFile(sender, data : ANY);
		VAR info : PETTrees.ExternalInfo; file : Files.File; filename : Files.FileName;
		BEGIN
			IF (data # NIL) & (data IS PETTrees.ExternalInfo) THEN
				info := data (PETTrees.ExternalInfo);
				COPY(info.filename, filename); Strings.Append(filename, ".Mod");
				file := Files.Old(filename);
				IF (file # NIL) THEN
					owner.GotoFile(filename, info.position);
				END;
			END;
		END OnGoToFile;

		PROCEDURE OnGoToDefinition(sender, data : ANY);
		VAR info : PETTrees.ExternalDefinitionInfo;
		BEGIN
			IF (data # NIL) & (data IS PETTrees.ExternalDefinitionInfo) THEN
				info := data (PETTrees.ExternalDefinitionInfo);
				owner.GotoDefinition(info);
			END;
		END OnGoToDefinition;

		PROCEDURE OnNodeExpand (sender, data: ANY);
		BEGIN
			IF (tree # NIL) THEN tree.SelectNodeByPos (editor.tv.cursor.GetPosition()) END
		END OnNodeExpand;

		PROCEDURE HandleTreeRefresh(sender, data : ANY);
		BEGIN

		END HandleTreeRefresh;

		PROCEDURE ClearLog;
		BEGIN
			logEdit.text.AcquireWrite;
			logEdit.text.Delete(0, logEdit.text.GetLength());
			logEdit.tv.firstLine.Set(0); logEdit.tv.cursor.SetPosition(0);
			logEdit.text.ReleaseWrite;
		END ClearLog;

		PROCEDURE DoCompile(findPC : BOOLEAN; CONST pc :ARRAY OF CHAR; options : CompilerOptions);
		VAR
			compiler : CompilerInterface.Compiler; tw : TextUtilities.TextWriter; errors : BOOLEAN;
			positions : ARRAY 2 OF LONGINT;
			type : LONGINT;
		BEGIN
			ClearLog;
			IF findPC THEN Strings.Append(options, " /f") END;
			NEW(tw, logEdit.text);
			diagnostics.DisableNotification;
			diagnostics.Clear;
			compiler := CompilerInterface.GetCompilerByName(compilerSettings.name);
			IF (compiler = NIL) & (compilerSettings.loadmodule # "") THEN
				LoadModule(compilerSettings.loadmodule); (* compiler shall register itself at the CompilerInterface *)
				compiler := CompilerInterface.GetCompilerByName(compilerSettings.name);
			END;
			IF (compiler # NIL) THEN
				compiler.CompileText(editor.text, "", 0, pc, options, tw, diagnostics, errors);
				IF ~errors THEN
					IF tree IS TFModuleTrees.ModuleTree THEN
(*						tree(TFModuleTrees.ModuleTree).StoreSymbols(NIL, NIL);*)
					END
				END;
			ELSE
				tw.String("No compiler available for file '"); tw.String(filename); tw.String("'");
				logPanel.visible.Set(TRUE);
			END;
			tw.Update;
			IF settings.enableWhitespaceWarnings THEN
				WhitespaceRemover.CheckWhitespace(editor.text, diagnostics);
			END;
			diagnostics.EnableNotification;
			IF (diagnostics.nofEntries > 0) THEN
				errorGrid.GetFirstPosition(positions, type);
				IF (focus = EditorFocus) & (positions[0] # WMDiagnostics.Invalid) THEN
					editor.tv.cursor.SetPosition(positions[0]);
					editor.SetFocus;
				ELSIF (focus = SplitEditorFocus) THEN
					splitEditor.tv.cursor.SetPosition(positions[0]);
					splitEditor.SetFocus;
				END;
				CursorChanged;
				errorGrid.visible.Set(TRUE);
				logPanel.visible.Set(TRUE); logEdit.visible.Set(TRUE);
			ELSE
				logPanel.visible.Set(FALSE); logEdit.visible.Set(TRUE);
				errorGrid.visible.Set(FALSE);
			END;
		END DoCompile;

		PROCEDURE ErrorClick(sender, data : ANY);
		VAR
			focusEditor: WMEditors.Editor;
			entry : WMDiagnostics.ViewEntry;
			index: LONGINT;
		BEGIN
			IF (data # NIL) & (data IS WMDiagnostics.CellInfo) & (data(WMDiagnostics.CellInfo).entryValid) THEN
				IF (focus = EditorFocus) THEN focusEditor := editor; index := 0;
				ELSIF (focus = SplitEditorFocus) THEN focusEditor := splitEditor; index := 1;
				ELSE
					HALT(99);
				END;
				entry := data(WMDiagnostics.CellInfo).entry;
				IF (entry.pos # NIL) & (LEN(entry.pos) = 2) & (entry.pos[index] # NIL) THEN
					focusEditor.tv.selection.SetFromTo(0, 0);
					focusEditor.tv.cursor.SetPosition(entry.pos[index].GetPosition());
					focusEditor.SetFocus;
				END;
			END;
		END ErrorClick;

		PROCEDURE GoToNextError(forward : BOOLEAN);
		VAR nearestPosition, row, index : LONGINT; focusEditor: WMEditors.Editor;
		BEGIN
			IF focus = EditorFocus THEN focusEditor := editor; index := 0;
			ELSIF focus = SplitEditorFocus THEN focusEditor := splitEditor; index := 1;
			ELSE RETURN;
			END;
			focusEditor.tv.selection.SetFromTo(0, 0);
			errorGrid.GetNearestPosition(editor.tv.cursor.GetPosition(), index, forward, nearestPosition, row);
			editor.tv.cursor.SetPosition(nearestPosition);
			errorGrid.SelectEntry(row, TRUE);
		END GoToNextError;

		PROCEDURE EditorFocusHandler(hasFocus: BOOLEAN);
		BEGIN
			IF hasFocus THEN
				focus := EditorFocus;
				searchPanel.SetTextView(editor.tv);
				IF (tree # NIL) THEN tree.SetEditor(editor) END;
			END;
		END EditorFocusHandler;

		PROCEDURE SplitEditorFocusHandler(hasFocus: BOOLEAN);
		BEGIN
			IF hasFocus THEN
				focus := SplitEditorFocus;
				searchPanel.SetTextView(splitEditor.tv);
				IF (tree # NIL) THEN tree.SetEditor(splitEditor) END;
			END
		END SplitEditorFocusHandler;

		PROCEDURE ToggleLabels;
		BEGIN
			IF editor.tv.showLabels.Get() THEN
				editor.tv.showLabels.Set(FALSE);
				splitEditor.tv.showLabels.Set(FALSE);
			ELSE
				editor.tv.showLabels.Set(TRUE);
				splitEditor.tv.showLabels.Set(TRUE);
			END;
			Invalidate;
		END ToggleLabels;

		PROCEDURE ToggleWrap;
		BEGIN
			IF (editor.tv.wrapMode.Get() = WMTextView.WrapWord) THEN
				editor.tv.wrapMode.Set(WMTextView.NoWrap);
				splitEditor.tv.wrapMode.Set(WMTextView.NoWrap);
			ELSE
				editor.tv.wrapMode.Set(WMTextView.WrapWord);
				splitEditor.tv.wrapMode.Set(WMTextView.WrapWord);
			END;
			wrap := ~wrap;
		END ToggleWrap;

		PROCEDURE TextChanged(sender, data : ANY);
		BEGIN
			IF logPanel.visible.Get() THEN
				logPanel.Invalidate
			END;
			IF ~modified THEN
				IF (owner # NIL) THEN owner.SetModified(TRUE) END;
				modified := TRUE
			END;
			CursorChanged
		END TextChanged;

		PROCEDURE CursorChanged;
		VAR position : LONGINT; pos : ARRAY 16 OF CHAR;
		BEGIN
			position := editor.tv.cursor.GetPosition();
			Strings.IntToStr(position, pos);
			owner.positionEdit.SetAsString(pos);
			IF (tree # NIL) THEN tree.SelectNodeByPos (position) END
		END CursorChanged;

		PROCEDURE HandleShortcut(ucs : LONGINT; flags : SET; keysym : LONGINT) : BOOLEAN;
		VAR pos : LONGINT;

			PROCEDURE HandlePreviousNext(forward : BOOLEAN);
			BEGIN
				IF (focus = EditorFocus) THEN
					editor.SetFocus;
				ELSE
					splitEditor.SetFocus;
				END;
				IF searchPanel.visible.Get() THEN
					searchPanel.HandlePreviousNext(forward);
				ELSIF errorGrid.visible.Get() THEN
					GoToNextError(forward);
				END;
				CursorChanged;
			END HandlePreviousNext;

			PROCEDURE HandleDiff;
			VAR
				filename, string : Filename; context : Commands.Context; res : LONGINT;
				arg : Streams.StringReader;
			BEGIN
				IF (settings.diffCommand = "") THEN
					WMDialogs.Error(WindowTitle, "No diff command specified");
					RETURN;
				END;
				COPY(settings.diffPrefix, filename);
				Strings.Append(filename, SELF.filename);
				Strings.Append(filename, settings.diffSuffix);
				IF (WMDialogs.QueryString("Diff to file...", filename) = WMDialogs.ResOk) THEN
					string := ""; Strings.Append(string, filename); Strings.Append(string, " "); Strings.Append(string, SELF.filename);
					NEW(arg, LEN(string)); arg.SetRaw(string, 0, LEN(string));
					NEW(context, NIL, arg, NIL, NIL, owner);
					Commands.Activate(settings.diffCommand, context, {}, res, string);
					IF (res # Commands.Ok) THEN
						WMDialogs.Error(WindowTitle, string);
					END;
				END;
			END HandleDiff;

			PROCEDURE HandlePositions;
			BEGIN
				IF (flags * Inputs.Ctrl # {}) THEN
					positions.RecallPosition(ucs, keysym, flags - Inputs.Ctrl);
				ELSE (* ShiftKeyDown(flags) *)
					positions.StoreCurrentPosition(ucs, keysym, flags - Inputs.Shift);
				END;
			END HandlePositions;

			PROCEDURE RemoveWhitespace;
			VAR tw : TextUtilities.TextWriter; nofRemoved : LONGINT;
			BEGIN
				ClearLog;
				NEW(tw, logEdit.text);
				WhitespaceRemover.RemoveFromText(editor.text, nofRemoved);
				tw.String("Removed "); tw.Int(nofRemoved, 0); tw.String(" end-of-line whitespace"); tw.Update;
				logEdit.visible.Set(TRUE);
			END RemoveWhitespace;

			PROCEDURE HandleComments(remove : BOOLEAN);
			VAR editor : WMEditors.Editor;
			BEGIN
				IF (focus = EditorFocus) THEN editor := SELF.editor; ELSE editor := splitEditor; END;
				editor.text.AcquireWrite;
				editor.tv.selection.Sort;
				IF (editor.tv.selection.a # editor.tv.selection.b) THEN
					IF remove THEN
						UncommentSelection(editor.text, editor.tv.selection.from, editor.tv.selection.to);
					ELSE
						CommentSelection(editor.text, editor.tv.selection.from, editor.tv.selection.to);
					END;
				END;
				editor.text.ReleaseWrite;
			END HandleComments;

		BEGIN
			IF (keysym = 06H) & ControlKeyDown(flags)THEN (* CTRL-F *)
				searchPanel.ToggleVisibility;
			ELSIF (keysym= 0EH) & ControlKeyDown(flags) THEN (* CTRL-N *)
				HandlePreviousNext(TRUE);
			ELSIF (keysym = 10H) & ControlKeyDown(flags) THEN (* CTRL-P *)
				HandlePreviousNext(FALSE);
			ELSIF (keysym = 0DH) & ControlKeyDown(flags) THEN (* CTRL-M *)
				IF sidePanel.visible.Get() THEN sidePanel.visible.Set(FALSE);
				ELSE sidePanel.visible.Set(TRUE);
				END;
			ELSIF (keysym = 04H) & ControlKeyDown(flags) THEN (* CTRL-D *)
				HandleDiff;
			ELSIF (keysym = 30H) & ControlKeyDown(flags) THEN (* CTRL- 0 *)
				IF (focus = EditorFocus) THEN
					editor.tv.cursor.SetPosition(0);
				ELSE
					splitEditor.tv.cursor.SetPosition(0);
				END;
			ELSIF (keysym = 39H) & ControlKeyDown(flags) THEN (* CTRL - 0 *)
				IF (focus = EditorFocus) THEN
					editor.text.AcquireRead; pos := editor.text.GetLength()-1; editor.text.ReleaseRead;
					editor.tv.cursor.SetPosition(pos);
				ELSE
					splitEditor.text.AcquireRead; pos := splitEditor.text.GetLength()-1; splitEditor.text.ReleaseRead;
					splitEditor.tv.cursor.SetPosition(pos);
				END;
			ELSIF (0FFBEH <= keysym) & (keysym <= 0FFC9H) & EitherShiftOrControlDown(flags) THEN
				HandlePositions;
			ELSIF (keysym = Inputs.KsTab) & (flags = {}) THEN (* TAB *)
				RETURN searchPanel.HandleTab();
			ELSIF (keysym = Inputs.KsDelete) & ControlKeyDown(flags) THEN (* CTRL-DELETE *)
				RemoveWhitespace;
			ELSIF (keysym = Inputs.KsInsert) & (flags * Inputs.Alt # {}) THEN
				HandleComments(FALSE);
			ELSIF (keysym = Inputs.KsDelete) & (flags * Inputs.Alt # {}) THEN
				HandleComments(TRUE);
			ELSE
				RETURN FALSE; (* Key not handled *)
			END;
			RETURN TRUE;
		END HandleShortcut;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF (editor # NIL) & (editor.text # NIL) THEN
				editor.text.onTextChanged.Remove(TextChanged);
				editor.tv.onCursorChanged := NIL;
				IF editor.undoMgr # NIL THEN
					editor.undoMgr.nrUpdatesListener := NIL;
				END;
			END;
		END Finalize;

	END PETPanel;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	BrowseEntry = POINTER TO RECORD
		prev, next : BrowseEntry;
		filename : Filename;
		pos : LONGINT;
	END;

	Window = OBJECT (WMComponents.FormWindow)
	VAR
		filenameEdit, optionsEdit, positionEdit: WMEditors.Editor;
		loadBtn, storeBtn, closeBtn, compileBtn, findPCBtn, undoBtn, redoBtn: WMStandardComponents.Button;
		splitBtn, formatBtn, searchBtn, labelsBtn, wrapBtn, forwardBtn, backBtn : WMStandardComponents.Button;
		popup: WMPopups.Popup;

		tabs : WMTabComponents.Tabs;
		pages : ARRAY MaxNbrOfTabs OF PETPanel;
		tabList : ARRAY MaxNbrOfTabs OF WMTabComponents.Tab;
		currentPage : PETPanel;
		currentPageNr : LONGINT;
		page : WMStandardComponents.Panel;

		xmlHasErrors : BOOLEAN;

		codecFormat: ARRAY 128 OF CHAR;
		autoCodecFormat: ARRAY 128 OF CHAR;

		projectText : Texts.Text;
		projectTextFilename : Filename;
		projectTextModified : BOOLEAN;

		showTypeHierarchy, showImportedModules : BOOLEAN;

		windowInfo : WMWindowManager.WindowInfo;

		(* window icons handling *)
		currentIcon : WMGraphics.Image;
		iconIdle, iconWorking : WMGraphics.Image;

		modifierFlags : SET;

		browseBase, browseTOS : BrowseEntry;

		PROCEDURE &New*(c : WMRestorable.Context);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;
			InitCodecs;
			vc := CreateForm();

			currentPageNr := -1;
			projectTextFilename := "";
			projectText := NIL;
			projectTextModified := FALSE;
			tabs.onSelectTab.Add(TabSelected);
			showTypeHierarchy := FALSE;
			showImportedModules := FALSE;
			modifierFlags := {};

			IF (c # NIL) THEN
				Init(c.r - c.l, c.b - c.t, FALSE);
			ELSE
				Init(WindowWidth, WindowHeight, FALSE);
			END;
			SetContent(vc);
			SetTitle(Strings.NewString(WindowTitle));

			currentIcon := NIL;
			iconIdle := WMGraphics.LoadImage("WMIcons.tar://PETIdle.png", TRUE);
			iconWorking := WMGraphics.LoadImage("WMIcons.tar://PET.png", TRUE);

			IF (iconIdle = NIL) THEN
				iconIdle := iconWorking;
			ELSIF (iconWorking = NIL) THEN
				iconWorking := iconIdle;
			END;

			SetIcon(iconIdle);

			IF c # NIL THEN (* restore the desktop *)
				WMRestorable.AddByContext(SELF, c);
				IF c.appData # NIL THEN
					DisableUpdate;
					LoadPages(c.appData(XML.Element));
					EnableUpdate;
				END;
				vc.Invalidate;
			ELSE WMWindowManager.DefaultAddWindow(SELF);
				(* NewTab; *)
				codecFormat := "AUTO";
				autoCodecFormat := DefaultTextFormat;
				SetFormatCaption("AUTO");
			END;

			NEW(browseBase); (* sentinel *)
			browseBase.prev := browseBase;
			browseTOS := browseBase
		END New;

		PROCEDURE CreateForm():WMComponents.VisualComponent;
		VAR
			panel, resizerPanel : WMStandardComponents.Panel;
			resizer : WMStandardComponents.Resizer;
			posLabel : WMStandardComponents.Label;
			font: WMGraphics.Font;
			dx, dy: LONGINT;

			PROCEDURE CreateToolbar() : WMComponents.VisualComponent;
			VAR toolbar : WMStandardComponents.Panel;
			BEGIN
				(* -- top toolbar *)
				NEW(toolbar); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);

				NEW(resizerPanel);
				resizerPanel.alignment.Set(WMComponents.AlignLeft);
				resizerPanel.bounds.SetWidth(200);
				toolbar.AddContent(resizerPanel);

				NEW(resizer);
				resizer.alignment.Set(WMComponents.AlignRight);
				resizer.bounds.SetWidth(4);
				resizerPanel.AddContent(resizer);

				NEW(filenameEdit); filenameEdit.alignment.Set(WMComponents.AlignClient);
				filenameEdit.multiLine.Set(FALSE); filenameEdit.bounds.SetWidth(200);
				filenameEdit.fillColor.Set(0FFFFFFFFH);
				filenameEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
				filenameEdit.tv.showBorder.Set(TRUE);
				filenameEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
				filenameEdit.tv.commandCaller := SELF;
				filenameEdit.onEnter.Add(LoadHandler);
				filenameEdit.onEscape.Add(FilenameEditEscapeHandler);
				resizerPanel.AddContent(filenameEdit);

				NEW(loadBtn); loadBtn.caption.SetAOC("Load"); loadBtn.alignment.Set(WMComponents.AlignLeft);
				loadBtn.onClick.Add(LoadHandler);
				toolbar.AddContent(loadBtn);

				NEW(storeBtn); storeBtn.caption.SetAOC("Store"); storeBtn.alignment.Set(WMComponents.AlignLeft);
				storeBtn.onClick.Add(StoreHandler);
				toolbar.AddContent(storeBtn);

				NEW(closeBtn); closeBtn.caption.SetAOC("Close"); closeBtn.alignment.Set(WMComponents.AlignLeft);
				closeBtn.onClick.Add(CloseHandler);
				toolbar.AddContent(closeBtn);

				NEW(formatBtn); formatBtn.caption.SetAOC("Format : ---"); formatBtn.alignment.Set(WMComponents.AlignLeft);
				formatBtn.SetExtPointerDownHandler(FormatHandler);
				formatBtn.bounds.SetWidth(3 * formatBtn.bounds.GetWidth());
				toolbar.AddContent(formatBtn);

				NEW(searchBtn); searchBtn.caption.SetAOC("Search"); searchBtn.alignment.Set(WMComponents.AlignLeft);
				searchBtn.onClick.Add(ButtonHandler);
				toolbar.AddContent(searchBtn);

				NEW(compileBtn); compileBtn.caption.SetAOC("Compile"); compileBtn.alignment.Set(WMComponents.AlignLeft);
				compileBtn.onClick.Add(ButtonHandler);
				toolbar.AddContent(compileBtn);

				NEW(findPCBtn); findPCBtn.caption.SetAOC("Find PC"); findPCBtn.alignment.Set(WMComponents.AlignLeft);
				findPCBtn.onClick.Add(FindPC);
				toolbar.AddContent(findPCBtn);

				NEW(undoBtn);
				font := undoBtn.GetFont();
				font.GetStringSize(" Undo (000) ", dx, dy);
				undoBtn.bounds.SetWidth(dx);
				undoBtn.caption.SetAOC("Undo"); undoBtn.alignment.Set(WMComponents.AlignLeft);
				undoBtn.onClick.Add(ButtonHandler);
				toolbar.AddContent(undoBtn);

				NEW(redoBtn);
				font := redoBtn.GetFont();
				font.GetStringSize(" Redo (000) ", dx, dy);
				redoBtn.bounds.SetWidth(dx);
				redoBtn.caption.SetAOC("Redo"); redoBtn.alignment.Set(WMComponents.AlignLeft);
				redoBtn.onClick.Add(ButtonHandler);
				toolbar.AddContent(redoBtn);

				NEW(optionsEdit); optionsEdit.tv.showBorder.Set(TRUE); optionsEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
				optionsEdit.alignment.Set(WMComponents.AlignClient); optionsEdit.multiLine.Set(FALSE);
				optionsEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
				optionsEdit.bounds.SetWidth(80); optionsEdit.fillColor.Set(0FFFFFFFFH);
				optionsEdit.SetAsString(settings.defaultCompilerOptions);
				toolbar.AddContent(optionsEdit);

				RETURN toolbar;
			END CreateToolbar;

			PROCEDURE CreateStatusbar() : WMComponents.VisualComponent;
			VAR statusbar : WMStandardComponents.Panel;
			BEGIN
				NEW(statusbar); statusbar.bounds.SetHeight(20); statusbar.alignment.Set(WMComponents.AlignBottom); statusbar.fillColor.Set(0CCCCCCFFH);

				NEW(posLabel); posLabel.caption.SetAOC(" Position: "); posLabel.bounds.SetWidth(60); posLabel.alignment.Set(WMComponents.AlignLeft);
				statusbar.AddContent(posLabel); posLabel.textColor.Set(0000000FFH);

				NEW(positionEdit); positionEdit.tv.showBorder.Set(TRUE); positionEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));

				positionEdit.alignment.Set(WMComponents.AlignLeft); positionEdit.multiLine.Set(FALSE);
				positionEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
				positionEdit.bounds.SetWidth(80); positionEdit.fillColor.Set(0FFFFFFFFH); positionEdit.onEnter.Add(PositionHandler);
				statusbar.AddContent(positionEdit);

				NEW(splitBtn); splitBtn.caption.SetAOC("Split"); splitBtn.alignment.Set(WMComponents.AlignRight);
				splitBtn.onClick.Add(SplitHandler);
				splitBtn.isToggle.Set(TRUE); splitBtn.SetPressed(FALSE);
				statusbar.AddContent(splitBtn);

				NEW(labelsBtn); labelsBtn.caption.SetAOC("Labels"); labelsBtn.alignment.Set(WMComponents.AlignRight);
				labelsBtn.isToggle.Set(TRUE); labelsBtn.SetPressed(FALSE);
				labelsBtn.onClick.Add(ButtonHandler);
				statusbar.AddContent(labelsBtn);

				NEW(wrapBtn); wrapBtn.caption.SetAOC("Wrap"); wrapBtn.alignment.Set(WMComponents.AlignRight);
				wrapBtn.isToggle.Set(TRUE); wrapBtn.SetPressed(FALSE);
				wrapBtn.onClick.Add(ButtonHandler);
				statusbar.AddContent(wrapBtn);

				NEW(forwardBtn); forwardBtn.caption.SetAOC("-->"); forwardBtn.alignment.Set(WMComponents.AlignRight);
				forwardBtn.onClick.Add(ButtonHandler);
				statusbar.AddContent(forwardBtn);

				NEW(backBtn); backBtn.caption.SetAOC("<--"); backBtn.alignment.Set(WMComponents.AlignRight);
				backBtn.onClick.Add(ButtonHandler);
				statusbar.AddContent(backBtn);

				RETURN statusbar;
			END CreateStatusbar;

		BEGIN
			(* -- Main Panel holding the tabs, toolbar and tabcontents (instance of PETPanel) *)
			NEW(panel); panel.alignment.Set(WMComponents.AlignClient); panel.fillColor.Set(0FFFFFFFFH); panel.takesFocus.Set(TRUE);

			(* -- Tabs for the PETPanels *)
			NEW(tabs); tabs.fillColor.Set(00000CCCCH); tabs.bounds.SetHeight(20); tabs.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(tabs); tabs.SetExtDragDroppedHandler(DragDroppedHandler);

			panel.AddContent(CreateToolbar());
			panel.AddContent(CreateStatusbar());

			(* -- Page holding the PETPanel *)
			NEW(page); page.fillColor.Set(0CCCCCCFFH); page.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(page);

			RETURN panel;
		END CreateForm;

		PROCEDURE ButtonHandler(sender, data : ANY);
		VAR options : CompilerOptions; searchString : SearchString; res : LONGINT;
		BEGIN
			IF sender = undoBtn THEN
				currentPage.editor.Undo;
			ELSIF sender = redoBtn THEN
				currentPage.editor.Redo;
			ELSIF sender = searchBtn THEN
				IF (currentPage # NIL) THEN
					currentPage.searchPanel.visible.Set(TRUE);
					currentPage.searchPanel.SetToLastSelection;
					currentPage.searchPanel.searchEdit.GetAsString(searchString);
					IF (searchString # "") THEN
						currentPage.searchPanel.SearchHandler(NIL, NIL);
					ELSE
						currentPage.searchPanel.searchEdit.SetFocus;
					END;
				END;
			ELSIF sender = labelsBtn THEN
				IF (currentPage # NIL) THEN currentPage.ToggleLabels; END;
			ELSIF sender = compileBtn THEN
				IF currentPage # NIL THEN
					IF (settings.backupOnCompile) THEN
						TextUtilities.StoreOberonText(currentPage.editor.text, BackupOnCompileFilename, res);
						IF (res = 0) THEN
							KernelLog.String("PET: Backup stored in "); KernelLog.String(BackupOnCompileFilename); KernelLog.Ln;
						ELSE
							KernelLog.String("PET: Warning: Backup-on-compile file creating failed."); KernelLog.Ln;
						END;
					END;
					optionsEdit.GetAsString(options);
					currentPage.DoCompile(FALSE, "", options);
				END;
			ELSIF sender = wrapBtn THEN
				IF (currentPage # NIL) THEN
					currentPage.ToggleWrap;
				END;
			ELSIF sender = backBtn THEN
				BrowseBack
			ELSIF sender = forwardBtn THEN
				BrowseForward
			END;
		END ButtonHandler;

		PROCEDURE NrUpdatesChanged(nrUndos, nrRedos: LONGINT);
		VAR lbl, str: ARRAY 32 OF CHAR;
		BEGIN
			IF nrUndos = 0 THEN
				undoBtn.enabled.Set(FALSE);
				undoBtn.clDefault.Set(999999FFH);
			ELSE
				undoBtn.enabled.Set(TRUE);
				undoBtn.clDefault.Reset;
			END;
			lbl := "Undo (";
			Strings.IntToStr(nrUndos, str);
			Strings.Append(lbl, str);
			Strings.Append(lbl, ")");
			undoBtn.caption.SetAOC(lbl);

			IF nrRedos = 0 THEN
				redoBtn.enabled.Set(FALSE);
				redoBtn.clDefault.Set(999999FFH);
			ELSE
				redoBtn.enabled.Set(TRUE);
				redoBtn.clDefault.Reset;
			END;
			lbl := "Redo (";
			Strings.IntToStr(nrRedos, str);
			Strings.Append(lbl, str);
			Strings.Append(lbl, ")");
			redoBtn.caption.SetAOC(lbl);
		END NrUpdatesChanged;

		PROCEDURE ProjectTextModified(sender, data : ANY);
		BEGIN
			projectTextModified :=TRUE;
		END ProjectTextModified;

		PROCEDURE InitCodecs;
		VAR caption: CaptionObject;
			elem: XML.Element; enum: XMLObjects.Enumerator; ptr: ANY; str : Strings.String;
		BEGIN
			NEW(popup);
			(* retrieve available Text-Codecs *)
			elem := Configuration.config.GetRoot();
			IF elem # NIL THEN
				enum := elem.GetContents(); enum.Reset;
				WHILE enum.HasMoreElements() DO
					ptr := enum.GetNext();
					IF ptr IS XML.Element THEN
						str := ptr(XML.Element).GetAttributeValue("name");
						IF (str # NIL) & (str^ = "Codecs") THEN
							enum := ptr(XML.Element).GetContents(); enum.Reset;
							WHILE enum.HasMoreElements() DO
								ptr := enum.GetNext();
								IF ptr IS XML.Element THEN
									str := ptr(XML.Element).GetAttributeValue("name");
									IF (str # NIL) & (str^ = "Decoder") THEN
										enum := ptr(XML.Element).GetContents(); enum.Reset;
										WHILE enum.HasMoreElements() DO
											ptr := enum.GetNext();
											IF ptr IS XML.Element THEN
												str := ptr(XML.Element).GetAttributeValue("name");
												IF (str # NIL) & (str^ = "Text") THEN
													enum := ptr(XML.Element).GetContents(); enum.Reset;
													WHILE enum.HasMoreElements() DO
														ptr := enum.GetNext();
														IF ptr IS XML.Element THEN
															str := ptr(XML.Element).GetAttributeValue("name");
															NEW(caption, str^);
															popup.AddParButton(str^, FormatPopupHandler, caption);
														END;
													END;
												END;
											END;
										END;
									END;
								END;
							END;
						END;
					END;
				END;
			END;
			NEW(caption, "AUTO");
			popup.AddParButton("AUTO", FormatPopupHandler, caption);
		END InitCodecs;

		PROCEDURE SelectNextTab;
		VAR i : LONGINT;
		BEGIN
			IF currentPageNr < 0 THEN RETURN; END;
			i := currentPageNr + 1;
			LOOP
				IF (i >= MaxNbrOfTabs) OR (pages[i] # NIL) THEN EXIT; END;
				INC(i);
			END;
			IF (i < MaxNbrOfTabs) THEN
				SelectTab(i);
			END;
		END SelectNextTab;

		PROCEDURE SelectPreviousTab;
		VAR i : LONGINT;
		BEGIN
			IF currentPageNr < 0 THEN RETURN; END;
			i := currentPageNr - 1;
			LOOP
				IF (i < 0) OR (pages[i] # NIL) THEN EXIT; END;
				DEC(i);
			END;
			IF (i >= 0) THEN
				SelectTab(i);
			END;
		END SelectPreviousTab;

		PROCEDURE SelectTab(tabNr : LONGINT);
		BEGIN
			IF (tabNr >= 0) & (tabNr < LEN(SELF.pages)) & (SELF.pages[tabNr] # NIL) THEN
				TabSelected(NIL, tabList[tabNr]);
				tabs.Select(tabList[tabNr]);
			END;
		END SelectTab;

		PROCEDURE RecordCurrentPos;
		VAR be : BrowseEntry;
		BEGIN
			IF (currentPage # NIL) THEN
				NEW(be);
				COPY(currentPage.filename, be.filename);
				be.pos := currentPage.editor.tv.cursor.GetPosition();

				be.next := NIL;
				be.prev := browseTOS;
				browseTOS.next := be;
				browseTOS := be;
			END;
		END RecordCurrentPos;

		PROCEDURE GotoFileInternal(CONST filename : ARRAY OF CHAR; pos : LONGINT);
		VAR page : PETPanel; i : LONGINT;
		BEGIN
			KernelLog.String("filename= "); KernelLog.String(filename); KernelLog.Ln;
			KernelLog.String("pos= "); KernelLog.Int(pos, 0); KernelLog.Ln;

			i := 0;
			page := NIL;
			WHILE (i < LEN(pages)-1) & (page = NIL) DO
				IF (pages[i] # NIL) & (pages[i].filename = filename) THEN
					page := pages[i];
				ELSE
					INC(i);
				END;
			END;
			IF (page = NIL) THEN
				Load(filename, "AUTO");
				page := currentPage;
			ELSE
				SelectTab(i);
			END;
			IF (page # NIL) THEN
				currentPage.editor.tv.cursor.SetPosition(pos);
				IF (currentPage.tree # NIL) THEN
					currentPage.tree.SelectNodeByPos(pos);
				END;
			END;
		END GotoFileInternal;

		PROCEDURE BrowseBack;
		BEGIN
			IF browseTOS.prev # browseBase THEN
				browseTOS := browseTOS.prev;
				(* browseBase.prev = browseBase *)
				GotoFileInternal(browseTOS.filename, browseTOS.pos);
			END
		END BrowseBack;

		PROCEDURE BrowseForward;
		BEGIN
			IF browseTOS.next # NIL THEN
				browseTOS := browseTOS.next;
				GotoFileInternal(browseTOS.filename, browseTOS.pos)
			END
		END BrowseForward;

		PROCEDURE GotoFile(CONST filename : ARRAY OF CHAR; pos : LONGINT);
		VAR page : PETPanel; i : LONGINT;
		BEGIN
			IF browseTOS = browseBase THEN RecordCurrentPos END;
			i := 0;
			page := NIL;
			WHILE (i < LEN(pages)-1) & (page = NIL) DO
				IF (pages[i] # NIL) & (pages[i].name = filename) THEN
					page := pages[i];
				ELSE
					INC(i);
				END;
			END;
			IF (page = NIL) THEN
				Load(filename, "AUTO");
				page := currentPage;
			ELSE
				SelectTab(i);
			END;
			IF (page # NIL) THEN
				currentPage.editor.tv.cursor.SetPosition(pos);
				IF (currentPage.tree # NIL) THEN
					currentPage.tree.SelectNodeByPos(pos);
				END;
				RecordCurrentPos
			END
		END GotoFile;

		PROCEDURE GotoDefinition(info : PETTrees.ExternalDefinitionInfo);
		VAR page : PETPanel; i : LONGINT;
		BEGIN
			IF info.filename = "" THEN RETURN END;
			IF browseTOS = browseBase THEN RecordCurrentPos END;

			i := 0;
			page := NIL;
			WHILE (i < LEN(pages)-1) & (page = NIL) DO
				IF (pages[i] # NIL) & (pages[i].filename = info.filename) THEN
					page := pages[i];
				ELSE
					INC(i);
				END;
			END;

			IF (page = NIL) THEN
				Load(info.filename, "AUTO");
				page := currentPage;
			ELSE
				SelectTab(i);
			END;
			IF (page # NIL) THEN
				IF (currentPage.tree # NIL) THEN
					currentPage.tree.BrowseToDefinition(SELF, info);
				END;
				RecordCurrentPos
			END;
		END GotoDefinition;


		PROCEDURE GetNrFromPage(page : PETPanel): LONGINT;
		VAR i : LONGINT; found : BOOLEAN;
		BEGIN
			i := 0; found := FALSE;
			WHILE (~found & (i < MaxNbrOfTabs)) DO
				IF (page = pages[i]) THEN RETURN i END;
				INC(i)
			END;
			RETURN -1
		END GetNrFromPage;

		PROCEDURE TabSelected(sender, data : ANY);
		VAR tab : WMTabComponents.Tab;
		BEGIN
			IF (data # NIL) & (data IS WMTabComponents.Tab) THEN
				DisableUpdate;
				optionsEdit.GetAsString(currentPage.options);
				compileBtn.caption.SetAOC(currentPage.compilerSettings.caption);
				findPCBtn.visible.Set(currentPage.compilerSettings.findPC);
				page.RemoveContent(currentPage);
				tab := data(WMTabComponents.Tab);
				IF (tab.data # NIL) & (tab.data IS WMComponents.VisualComponent) THEN
					currentPage := tab.data(PETPanel);
					currentPageNr := GetNrFromPage(currentPage);
					page.AddContent(currentPage);
					IF ~currentPage.initialized THEN currentPage.Initialize END;
					currentPage.Reset(SELF, NIL);
					page.AlignSubComponents;
				END;
				EnableUpdate;
				UpdateState;
				page.Invalidate
			END
		END TabSelected;

		PROCEDURE UpdatePages;
		VAR i : LONGINT;
			tab : WMTabComponents.Tab;
			s : Strings.String;
			foundModifiedPage : BOOLEAN;
		BEGIN
			DisableUpdate;
			tabs.RemoveAllTabs;
			IF currentPage # NIL THEN page.RemoveContent(currentPage);
				currentPage := NIL
			END;
			IF currentPageNr >= 0 THEN currentPage := pages[currentPageNr] END;
			foundModifiedPage := FALSE;
			FOR i := 0 TO 99 DO
				tabList[i] := NIL;
				IF pages[i] # NIL THEN
					pages[i].alignment.Set(WMComponents.AlignClient);
					tab := tabs.NewTab();
					tab.attention := pages[i].modified;
					foundModifiedPage := foundModifiedPage OR pages[i].modified;
					tabs.AddTab(tab);
					tabList[i] := tab;
					s := Strings.NewString(pages[i].name);
					tabs.SetTabCaption(tab, s);
					tabs.SetTabData(tab, pages[i]);
				END
			END;
			IF currentPage = NIL THEN
				i := 0;
				WHILE (i < MaxNbrOfTabs) & (currentPage = NIL) DO
					IF pages[i] # NIL THEN currentPage := pages[i]; currentPageNr := i END;
					INC(i);
				END;
				IF currentPage = NIL THEN SetModified(FALSE) END;
			END;
			IF currentPage # NIL THEN
				IF ~currentPage.initialized THEN currentPage.Initialize END;
				page.AddContent(currentPage);
				currentPage.Reset(SELF, NIL);
				page.AlignSubComponents;
				page.Invalidate;
				IF tabList[currentPageNr] # NIL THEN tabs.Select(tabList[currentPageNr]) END
			END;
			UpdateState;
			EnableUpdate;
			UpdateInfo;
			IF foundModifiedPage THEN
				SetIcon(iconWorking);
			ELSE
				SetIcon(iconIdle);
			END;
		END UpdatePages;

		PROCEDURE UpdateInfo;
		VAR i, j : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(windowInfo.openDocuments)-1 DO windowInfo.openDocuments[i].name := ""; END;
			windowInfo.handleDocumentInfo := HandleDocumentInfo;
			windowInfo.vc.generator := NIL;
			j := 0;
			FOR i := 0 TO LEN(pages)-1 DO
				IF (pages[i] # NIL) & (j < LEN(windowInfo.openDocuments)) THEN
					windowInfo.openDocuments[j].id := i;
					COPY(pages[i].name, windowInfo.openDocuments[j].name);
					COPY(pages[i].filename, windowInfo.openDocuments[j].fullname);
					windowInfo.openDocuments[j].modified := pages[i].modified;
					windowInfo.openDocuments[j].hasFocus := pages[i] = currentPage;
					INC(j);
				END;
			END;
			SetInfo(windowInfo);
		END UpdateInfo;

		PROCEDURE HandleDocumentInfo(CONST info : WMWindowManager.DocumentInfo; new : BOOLEAN; VAR res : LONGINT);
		BEGIN
			IF (pages[info.id] # NIL) THEN SelectTab(info.id); END;
		END HandleDocumentInfo;

		PROCEDURE UpdateState;
		VAR tInt : LONGINT; tStr : ARRAY 16 OF CHAR;

			PROCEDURE SetSplitted(splitted : BOOLEAN);
			BEGIN
				IF splitted THEN splitBtn.SetPressed(TRUE); ELSE splitBtn.SetPressed(FALSE); END;
			END SetSplitted;

			PROCEDURE SetLabels(show : BOOLEAN);
			BEGIN
				IF show THEN labelsBtn.SetPressed(TRUE); ELSE labelsBtn.SetPressed(FALSE); END;
			END SetLabels;

			PROCEDURE SetWrap(wrap : BOOLEAN);
			BEGIN
				IF wrap THEN wrapBtn.SetPressed(TRUE); ELSE wrapBtn.SetPressed(FALSE); END;
			END SetWrap;

			PROCEDURE ResetUndo;
			BEGIN
				undoBtn.caption.Reset;
				redoBtn.caption.Reset;
				undoBtn.clDefault.Reset;
				redoBtn.clDefault.Reset;
			END ResetUndo;

		BEGIN
			(* set state of current page *)
			IF (currentPage # NIL) THEN
				SetModified(currentPage.modified);
				SetSplitted(currentPage.splitted);
				SetWrap(currentPage.wrap);
				SetLabels(currentPage.editor.tv.showLabels.Get());
				SetFormatCaption(currentPage.codecFormat);
				filenameEdit.SetAsString(currentPage.filename);
				optionsEdit.SetAsString(currentPage.options);
				compileBtn.caption.SetAOC(currentPage.compilerSettings.caption);
				findPCBtn.visible.Set(currentPage.compilerSettings.findPC);
				currentPage.editor.tv.cursor.SetVisible(TRUE);
				currentPage.editor.SetFocus;
				tInt := currentPage.editor.tv.cursor.GetPosition(); Strings.IntToStr(tInt, tStr);
				positionEdit.SetAsString(tStr);
				IF currentPage.editor.undoMgr # NIL THEN
					NrUpdatesChanged(currentPage.editor.undoMgr.nrUndoUpdates, currentPage.editor.undoMgr.nrRedoUpdates);
				END;
			ELSE
				SetModified(FALSE);
				SetSplitted(FALSE);
				SetWrap(FALSE);
				codecFormat := "AUTO";
				autoCodecFormat := DefaultTextFormat;
				SetFormatCaption("AUTO");
				storeBtn.caption.SetAOC("Store");
				filenameEdit.SetAsString("");
				optionsEdit.SetAsString("");
				compileBtn.caption.Reset;
				findPCBtn.visible.Set(FALSE);
				positionEdit.SetAsString("-");
				ResetUndo;
			END;
		END UpdateState;

		PROCEDURE DragDroppedHandler(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo; VAR handled : BOOLEAN);
		VAR dropTarget : URLDropTarget;
		BEGIN
			NEW(dropTarget, SELF);
			dragInfo.data := dropTarget;
			ConfirmDrag(TRUE, dragInfo)
		END DragDroppedHandler;

		PROCEDURE PositionHandler(sender, data : ANY);
		VAR tempString : ARRAY 16 OF CHAR;
			tempInt : LONGINT;
		BEGIN
			IF (currentPage # NIL) THEN
				positionEdit.GetAsString(tempString);
				Strings.StrToInt(tempString, tempInt);
				currentPage.editor.tv.cursor.SetPosition(tempInt);
				currentPage.editor.tv.cursor.SetVisible(TRUE);
				currentPage.editor.SetFocus;
			END
		END PositionHandler;

		PROCEDURE FormatHandler(x, y: LONGINT; keys: SET; VAR handled: BOOLEAN);
		VAR rectangle: WMRectangles.Rectangle;
		BEGIN
			handled := TRUE;
			rectangle := formatBtn.bounds.Get();
			popup.Popup(bounds.l + rectangle.l, bounds.t + rectangle.b+ 20);
		END FormatHandler;

		PROCEDURE SetFormatCaption(CONST format: ARRAY OF CHAR);
		VAR caption : ARRAY 100 OF CHAR;
		BEGIN
			caption := "Format : ";
			Strings.Append(caption, format);
			IF (format = "AUTO") THEN
				IF (currentPage # NIL) THEN Strings.Append(caption, " "); Strings.Append(caption, currentPage.autoCodecFormat);
				ELSE Strings.Append(caption, " "); Strings.Append(caption, autoCodecFormat);
				END;
			END;
			formatBtn.caption.SetAOC(caption);
		END SetFormatCaption;

		PROCEDURE SetCursorPosition (position: LONGINT);
		VAR string : ARRAY 16 OF CHAR;
		BEGIN
			IF (currentPage # NIL) THEN
				Strings.IntToStr(position, string);
				positionEdit.SetAsString(string);
				currentPage.editor.tv.cursor.SetPosition(position);
			END;
		END SetCursorPosition;

		PROCEDURE SetModified(modified : BOOLEAN);
		BEGIN
			IF currentPage # NIL THEN
				tabList[currentPageNr].attention := modified;
				tabs.Invalidate;
				IF modified THEN
					SetIcon(iconWorking);
					storeBtn.caption.SetAOC("Store !")
				ELSE
					storeBtn.caption.SetAOC("Store");
				END;
			END
		END SetModified;

		PROCEDURE SetIcon(icon : WMGraphics.Image);
		BEGIN
			IF (icon # NIL) & (icon # currentIcon) THEN
				currentIcon := icon;
				SetIcon^(icon);
			END;
		END SetIcon;

		PROCEDURE FormatPopupHandler(sender, data: ANY);
		BEGIN
			IF (data # NIL) & (data IS CaptionObject) THEN
				popup.Close;
				IF (currentPage # NIL) THEN
					COPY(data(CaptionObject).caption, currentPage.codecFormat);
					COPY(currentPage.codecFormat, codecFormat);
					COPY(currentPage.autoCodecFormat, autoCodecFormat);
				ELSE
					COPY(data(CaptionObject).caption, codecFormat);
					COPY(DefaultTextFormat, autoCodecFormat);
				END;
				SetFormatCaption(codecFormat);
			END
		END FormatPopupHandler;

		(* Called when pressing the Escape key while the filename editor has the keyboard focus. *)
		PROCEDURE FilenameEditEscapeHandler(sernder, data : ANY);
		BEGIN
			IF (currentPage # NIL) THEN
				filenameEdit.SetAsString(currentPage.filename);
			END;
		END FilenameEditEscapeHandler;

		PROCEDURE LoadHandler(sender, data : ANY);
		VAR filename : Filename; command : ARRAY 1024 OF CHAR; msg : ARRAY 64 OF CHAR; ignoreRes : LONGINT;
		BEGIN
			filenameEdit.GetAsString(filename);
			Strings.TrimWS(filename);
			IF (filename # "") THEN
				IF (Inputs.LeftShift IN modifierFlags) THEN
					command := "PET.Open "; Strings.AppendX(command, filename);
					Commands.Call(command, {}, ignoreRes, msg);
					IF (currentPage # NIL) THEN
						filenameEdit.SetAsString(currentPage.filename);
					ELSE
						filenameEdit.SetAsString("");
					END;
				ELSE
					Load(filename, codecFormat);
					IF (currentPage # NIL) THEN
						optionsEdit.GetAsString(currentPage.options);
					END;
				END;
			END;
		END LoadHandler;

		PROCEDURE Load(CONST filename,  format : ARRAY OF CHAR);
		VAR
			text : Texts.Text; res : LONGINT;
			decoder : Codecs.TextDecoder;
			msg : ARRAY 512 OF CHAR;
			readonly : BOOLEAN;
			name, fullname, archiveName, entryName, path : Filename;
			syntaxHighlighterName : ARRAY 32 OF CHAR;
			file : Files.File;
			in: Streams.Reader;
		BEGIN
			DisableUpdate;
			res := -1;

			NewTab; (* create a new Tab with an empty PETPanel to Load into *)

			Codecs.SplitName(filename, archiveName, entryName);
			IF (archiveName # "") THEN
				COPY(archiveName, name);
			ELSE
				COPY(filename, name);
			END;
			COPY(name, fullname);

			readonly := FALSE;
			(* Check whether file/archive exists and get its canonical name *)
			file := Files.Old(name);
			IF (file # NIL) THEN
				file.GetName(fullname);
				readonly := Files.ReadOnly IN file.flags;
			ELSE
				file := Files.New(name); (* to get path *)
				IF (file # NIL) THEN
					file.GetName(fullname);
					file := NIL;
				END;
			END;

			IF (archiveName # "") THEN
				Codecs.JoinName(fullname, entryName, currentPage.filename);
			ELSE
				COPY(fullname, currentPage.filename);
			END;

			IF (settings.showPathInTabs) THEN
				COPY(fullname, currentPage.name);
				IF (archiveName # "") THEN Codecs.JoinName(currentPage.name, entryName, currentPage.name); END;
			ELSE
				Files.SplitPath(fullname, path, currentPage.name);
				IF (archiveName # "") THEN Codecs.JoinName(currentPage.name, entryName, currentPage.name); END;
			END;
			IF readonly THEN Strings.Append(currentPage.name, " (R)"); END;

			IF (archiveName # "") THEN Codecs.JoinName(fullname, entryName, fullname); END;

			filenameEdit.SetAsString(fullname);

			IF projectText # NIL THEN
				currentPage.scratch.SetText(projectText);
			END;

			text := currentPage.editor.text;
			text.AcquireWrite;
			currentPage.modified := TRUE; (* avoid the ! on the store button while loading *)
			text.Delete(0, text.GetLength());
			currentPage.editor.tv.firstLine.Set(0);
			currentPage.editor.tv.onLinkClicked.Add(LinkClickedHandler);
			text.ReleaseWrite;

			IF (file # NIL) THEN
				IF (format = "AUTO") THEN
					decoder := TextUtilities.DecodeAuto(fullname, autoCodecFormat);
					COPY(autoCodecFormat, currentPage.autoCodecFormat);
				ELSE
					decoder := Codecs.GetTextDecoder(format);
				END;

				IF (decoder # NIL) THEN
					COPY(format, currentPage.codecFormat);
					in := Codecs.OpenInputStream(fullname);
					IF in # NIL THEN
						decoder.Open(in, res);
						IF res = 0 THEN
							currentPage.editor.text.onTextChanged.Remove(currentPage.TextChanged);
							currentPage.editor.SetText(decoder.GetText());
							currentPage.searchPanel.SetText(decoder.GetText());
							currentPage.splitEditor.SetText(currentPage.editor.text);
							currentPage.editor.text.onTextChanged.Add(currentPage.TextChanged);
							currentPage.editor.text.SetUndoManager(currentPage.editor.undoMgr)
						END;
					ELSE
						msg := "Can't open input stream on file "; Strings.Append(msg, fullname);
						WMDialogs.Error(WindowTitle, msg);
					END;
				ELSE
					msg := "No decoder for file "; Strings.Append(msg, fullname);
					Strings.Append(msg, " (Format: "); Strings.Append(msg, format); Strings.Append(msg, ")");
					WMDialogs.Error(WindowTitle, msg);
				END;
			END;

			SetFormatCaption(format);

			currentPage.editor.tv.firstLine.Set(0);
			currentPage.editor.tv.cursor.SetPosition(0);
			currentPage.editor.tv.SetFocus;

			currentPage.searchPanel.SetSettings(settings.searchWrap, settings.searchCaseSensitive, FALSE, settings.searchHighlightAll);

			currentPage.compilerSettings := settings.GetCompilerSettings(filename);
			currentPage.options := currentPage.compilerSettings.options;

			GetSyntaxHighlighterName(filename, syntaxHighlighterName);
			IF (syntaxHighlighterName # "") THEN
				currentPage.editor.highlighting.SetAOC(syntaxHighlighterName);
				currentPage.splitEditor.highlighting.SetAOC(syntaxHighlighterName);
			END;

			currentPage.CreateSidePanel(currentPage.compilerSettings);

			COPY(currentPage.name, tabList[currentPageNr].caption^); tabs.Invalidate;
			currentPage.modified := FALSE;
			SetModified(FALSE);
			UpdatePages;
			EnableUpdate;
			form.Invalidate;
		END Load;

		PROCEDURE StoreHandler(sender, data : ANY);
		VAR filename : Filename;
		BEGIN
			IF (currentPage # NIL) THEN
				filenameEdit.GetAsString(filename);
				Strings.TrimWS(filename);
				IF filename # "" THEN
					Store(filename, currentPage.codecFormat);
				ELSE
					WMDialogs.Error(WindowTitle, "Filename invalid");
					filenameEdit.SetAsString(currentPage.filename);
				END;
			END
		END StoreHandler;
		
		PROCEDURE CompleteHandler(sender, data : ANY);
		BEGIN
			IF currentPage.tree IS TFModuleTrees.ModuleTree THEN
				currentPage.tree(TFModuleTrees.ModuleTree).Complete(NIL, NIL);
			END
		END CompleteHandler;

		PROCEDURE Store(CONST filename, format  : ARRAY OF CHAR);
		VAR
			res : LONGINT;
			msg : ARRAY 512 OF CHAR;
			name, backName, fullname, archiveName, entryName, path: Filename;
			syntaxHighlighterName : ARRAY 32 OF CHAR;
			backExt, t, ext: ARRAY 12 OF CHAR;
			options : CompilerOptions;
			encoder : Codecs.TextEncoder;
			w : Streams.Writer; i : LONGINT;
			file, oldFile : Files.File;

			PROCEDURE FileExists(CONST filename : ARRAY OF CHAR) : BOOLEAN;
			BEGIN
				RETURN Files.Old(filename) # NIL
			END FileExists;

			PROCEDURE CreateBackupFile;
			BEGIN
				IF settings.backupOnStore = Paranoid THEN
					Strings.Concat(filename, ".Bak", backName);
					IF FileExists(backName) THEN
						i := 0;
						REPEAT
							backExt := "."; Strings.IntToStr(i, t);
							Strings.Append(backExt, t); Strings.Append(backExt, ".Bak");
							Strings.Concat(filename, backExt, backName);
							INC(i);
						UNTIL ~FileExists(backName);
					END;
				ELSE
					ASSERT(settings.backupOnStore = Yes);
					Strings.Concat(filename, ".Bak", backName);
				END;
				Files.Rename(filename, backName, res);
				IF res = Files.Ok THEN KernelLog.String("Backup created  in "); KernelLog.String(backName); KernelLog.Ln END;
			END CreateBackupFile;

		BEGIN
			IF currentPage # NIL THEN
				filenameEdit.SetAsString(filename);

				Codecs.SplitName(filename, archiveName, entryName);
				IF (archiveName # "") THEN
					COPY(archiveName, name);
				ELSE
					COPY(filename, name);
				END;
				COPY(name, fullname);

				oldFile := Files.Old(name);
				IF (oldFile # NIL) THEN
					IF (Files.ReadOnly IN oldFile.flags) THEN
						msg := "File is read-only: "; Strings.Append(msg, name);
						WMDialogs.Error("Error", msg);
						RETURN;
					END;
				END;

				IF (archiveName = "") & (settings.backupOnStore # No) THEN CreateBackupFile; END;

				IF (format = "AUTO") THEN
					IF (currentPage.autoCodecFormat = "") THEN
						encoder := Codecs.GetTextEncoder(DefaultTextFormat);
					ELSE
						encoder := Codecs.GetTextEncoder(currentPage.autoCodecFormat);
						IF encoder = NIL THEN
							encoder := Codecs.GetTextEncoder(DefaultTextFormat);
						END;
					END;
				ELSE
					encoder := Codecs.GetTextEncoder(format);
				END;

				IF (encoder # NIL) THEN
					IF (archiveName # "") & (oldFile # NIL) THEN
						file := oldFile;
					ELSE
						oldFile := NIL;
						file := Files.New(name);
						IF (file = NIL) THEN
							msg := "Could not create file "; Strings.Append(msg, name);
							WMDialogs.Error(WindowTitle, msg);
							RETURN;
						END;
					END;

					file.GetName(fullname);
					IF (archiveName # "") THEN Codecs.JoinName(fullname, entryName, fullname); END;
					filenameEdit.SetAsString(fullname);

					w := Codecs.OpenOutputStream(fullname);

					IF (w # NIL) THEN
						encoder.Open(w);
						currentPage.editor.text.AcquireWrite;
						encoder.WriteText(currentPage.editor.text, res);
						currentPage.editor.text.ReleaseWrite;
						w.Update;
						IF res # 0 THEN
							msg := "Could not encode file "; Strings.Append(msg, fullname);
							WMDialogs.Error(WindowTitle, msg);
						END;
				ELSE
						msg := "Could not store to file "; Strings.Append(msg, fullname); Strings.Append(msg, " (Could not open output stream)");
						WMDialogs.Error(WindowTitle, msg);
				END;
				ELSE
					msg := "Could not store file "; Strings.Append(msg, fullname); Strings.Append(msg, " (No encoder found)");
					WMDialogs.Error(WindowTitle, msg);
				END;

				IF (settings.showPathInTabs) THEN
					COPY(fullname, pages[currentPageNr].name);
				ELSE
					IF (archiveName # "") THEN
						Files.SplitPath(archiveName, path, name);
						Codecs.JoinName(name, entryName, pages[currentPageNr].name);
					ELSE
						Files.SplitPath(fullname, path, pages[currentPageNr].name);
					END;
				END;
				tabs.SetTabCaption(tabList[currentPageNr], Strings.NewString(currentPage.name));
				tabs.Invalidate;

				Files.SplitExtension (fullname, backName, ext);
				Files.SplitExtension (currentPage.filename, backName, backExt);

				IF ext # backExt THEN
					currentPage.compilerSettings := settings.GetCompilerSettings(name);
					currentPage.options := currentPage.compilerSettings.options;
					optionsEdit.SetAsString(currentPage.options);

					GetSyntaxHighlighterName(filename, syntaxHighlighterName);
					IF (syntaxHighlighterName # "") THEN
						currentPage.editor.highlighting.SetAOC(syntaxHighlighterName);
						currentPage.editor.highlighting.SetAOC(syntaxHighlighterName);
					END;
				END;

				COPY(fullname, currentPage.filename);

				compileBtn.caption.SetAOC(currentPage.compilerSettings.caption);
				findPCBtn.visible.Set(currentPage.compilerSettings.findPC);

 				optionsEdit.GetAsString(options); COPY(options, currentPage.options);
				currentPage.modified := FALSE;
				SetModified(FALSE);

				IF HasModifiedPage() THEN
					SetIcon(iconWorking);
				ELSE
					SetIcon(iconIdle);
				END;
			END
		END Store;

		PROCEDURE NewTab;
		VAR pet : PETPanel;
			i : LONGINT;
			found : BOOLEAN;
		BEGIN
			found := FALSE;
			NEW(pet, SELF); pet.alignment.Set(WMComponents.AlignClient); pet.fillColor.Set(0FFFFFFFFH); pet.takesFocus.Set(TRUE);
			IF pet.editor.undoMgr # NIL THEN
				pet.editor.undoMgr.nrUpdatesListener := NrUpdatesChanged;
				NrUpdatesChanged(0, 0);
			END;
			IF (pet.scratchPanel # NIL) THEN
				pet.scratchPanel.bounds.SetHeight(settings.scratchPanelHeight);
			END;
			(* find a free place *)
			i := 0;
			WHILE (i < MaxNbrOfTabs) & (~found) DO
				IF pages[i] = NIL THEN pages[i] := pet; currentPageNr := i; found := TRUE; END;
				INC(i)
			END;
			UpdatePages;
		END NewTab;

		(** Returns TRUE if at least one page has been modified, FALSE otherwise *)
		PROCEDURE HasModifiedPage() : BOOLEAN;
		VAR modified : BOOLEAN; i : LONGINT;
		BEGIN
			modified := FALSE;
			i := 0;
			WHILE ~modified & (i < MaxNbrOfTabs) DO
				IF (pages[i] # NIL) & (pages[i].modified) THEN
					modified := TRUE;
				END;
				INC(i);
			END;
			RETURN modified;
		END HasModifiedPage;

		(* Returns FALSE if the user declines to close all tabs *)
		PROCEDURE CloseAllTabs() : BOOLEAN;
		VAR res, i : LONGINT;
		BEGIN
			(* First check whether all pages are saved to disk *)
			i := 0;
			LOOP
				IF i >= MaxNbrOfTabs THEN EXIT; END;
				IF (pages[i] # NIL) & (pages[i].modified) THEN
					res := WMDialogs.Confirmation(WindowTitle, "At least on page has not been stored. Continue?");
					IF res = WMDialogs.ResNo THEN
						RETURN FALSE;
					ELSIF res = WMDialogs.ResYes THEN
						EXIT;
					END;
				END;
				INC(i);
			END;

			i := 0;
			WHILE (i < MaxNbrOfTabs) DO
				IF (pages[i] # NIL) THEN 	pages[i].Finalize; pages[i] := NIL; END;
				INC(i);
			END;
			UpdatePages;
			form.Invalidate;
			RETURN TRUE;
		END CloseAllTabs;

		PROCEDURE CloseHandler(sender, data: ANY);
		VAR found : BOOLEAN; i : LONGINT;
		BEGIN
			(* close current tab, warn user if not saved *)
			IF (currentPage = NIL) OR (currentPage.modified) & (
				WMDialogs.Confirmation(WindowTitle, "The current text was not stored. Continue ?") = WMDialogs.ResNo)
			THEN RETURN END;
			(* remove current page *)
			found := FALSE; i := 0;
			WHILE (~found & (i < MaxNbrOfTabs)) DO
				IF (currentPage = pages[i]) THEN pages[i].Finalize; pages[i] := NIL; found := TRUE END;
				INC(i);
			END;
			IF found & (i >= 2) THEN currentPageNr := i-2; END;
			UpdatePages;
			form.Invalidate;
		END CloseHandler;

		PROCEDURE SplitHandler(sender, data: ANY);
		BEGIN
			IF (currentPage # NIL) THEN
				IF currentPage.splitted THEN
					currentPage.splitPanel.visible.Set(FALSE);
					currentPage.editor.SetFocus;
				ELSE
					currentPage.splitPanel.visible.Set(TRUE);
				END;
				currentPage.splitted := ~currentPage.splitted
			END
		END SplitHandler;

		PROCEDURE LinkClickedHandler(sender, data : ANY);
		BEGIN
			IF data IS WMTextView.LinkWrapper THEN
				KernelLog.String("Link: "); KernelLog.String(data(WMTextView.LinkWrapper).link^); KernelLog.Ln
			END;
		END LinkClickedHandler;

		PROCEDURE FindPC(sender, data : ANY);
		VAR a, b : LONGINT;
			pcStr : ARRAY 128 OF CHAR;
			selectionText: Texts.Text;
			from, to: Texts.TextPosition;
			options : CompilerOptions;
		BEGIN
			IF currentPage = NIL THEN RETURN; END;
			IF Texts.GetLastSelection(selectionText, from, to) THEN
				selectionText.AcquireRead;
				a := Strings.Min(from.GetPosition(), to.GetPosition());
				b := Strings.Max(from.GetPosition(), to.GetPosition());
				TextUtilities.SubTextToStr(selectionText, a, b - a, pcStr);
				selectionText.ReleaseRead;
				Strings.Trim(pcStr, " ");
			END;
			optionsEdit.GetAsString(options);
			IF pcStr = "" THEN
				IF WMDialogs.QueryString("Enter PC to locate", pcStr) = WMDialogs.ResOk THEN
					currentPage.DoCompile(TRUE, pcStr, options)
				END
			ELSE
				currentPage.DoCompile(TRUE, pcStr, options)
			END
		END FindPC;

		PROCEDURE UnloadModule;
		VAR
			path, filename : Files.FileName;
			name, extension, msg : ARRAY 128 OF CHAR;
			tw : TextUtilities.TextWriter; res : LONGINT;
		BEGIN
			ASSERT(currentPage # NIL);
			Files.SplitPath(currentPage.filename, path, filename);
			Strings.GetExtension(filename, name, extension);
			IF (name # "PET") THEN
				Modules.FreeModule(name, res, msg);
			ELSE
				res := -1; msg := "Unloading module PET not allowed! PET is running.";
			END;
			IF res = 0 THEN
				msg := "Module "; Strings.Append(msg, name); Strings.Append(msg, " unloaded.");
			END;
			currentPage.ClearLog;
			NEW(tw, currentPage.logEdit.text); tw.String (msg); tw.Update;
			IF currentPage.logEdit.visible.Get() = FALSE THEN currentPage.logEdit.visible.Set(TRUE); END;
		END UnloadModule;

		PROCEDURE Close;
		VAR page : LONGINT;
		BEGIN
			Close^;
			FOR page := 0 TO LEN(pages)-1 DO
				IF pages[page] # NIL THEN pages[page].Finalize; END;
			END;
			IF projectTextModified THEN
				StoreText(projectTextFilename, projectText);
			END;
			DecCount;
		END Close;

		(* XML scanner/parser error handler *)
		PROCEDURE Error(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			xmlHasErrors := TRUE;
		END Error;

		PROCEDURE LoadState(CONST filename : ARRAY OF CHAR) : BOOLEAN;
		VAR
			file : Files.File;
			scanner : XMLScanner.Scanner;
			parser : XMLParser.Parser;
			reader : Files.Reader;
			doc : XML.Document;
			elem : XML.Element;
			string : XML.String;
			msg : ARRAY 128 OF CHAR;
		BEGIN
			xmlHasErrors := FALSE;
			file := Files.Old(filename);
			IF file # NIL THEN
				NEW(reader, file, 0);
				NEW(scanner, reader); scanner.reportError := Error;
				NEW(parser, scanner); parser.reportError := Error;
				doc := parser.Parse();
				IF xmlHasErrors THEN
					msg := "Could not load state: "; Strings.Append(msg, filename); Strings.Append(msg, " could not be parsed");
					WMDialogs.Error(WindowTitle, msg);
					RETURN FALSE;
				END;
				elem := doc.GetRoot();
				IF elem # NIL THEN string := elem.GetName(); END;
				IF (string # NIL) & (string^ = "PETData") THEN
					DisableUpdate;
					LoadPages(doc.GetRoot());
					EnableUpdate;
				ELSE
					msg := "Could not load state: "; Strings.Append(msg, filename); Strings.Append(msg, " not valid");
					WMDialogs.Error(WindowTitle, msg);
					RETURN FALSE;
				END;
			ELSE
				msg := "Could not load state: XML file "; Strings.Append(msg, filename); Strings.Append(msg, " not found");
				WMDialogs.Error(WindowTitle, msg);
				RETURN FALSE;
			END;
			RETURN TRUE;
		END LoadState;

		(* Store the current editor settings into a file *)
		PROCEDURE StoreState(CONST filename : ARRAY OF CHAR);
		VAR state : XML.Element; file : Files.File; w : Files.Writer;
		BEGIN
			file := Files.New(filename);
			IF file # NIL THEN
				Files.OpenWriter(w, file, 0);
				state := StorePages();
				state.Write(w, NIL, 0);
				w.Update;
				Files.Register(file);
				KernelLog.String("PET state saved into "); KernelLog.String(filename); KernelLog.Ln;
			ELSE
				WMDialogs.Error(WindowTitle, "Could not create file");
			END;
		END StoreState;

		PROCEDURE LoadPages(pages : XML.Element);
		VAR
			elem : XML.Element; enum : XMLObjects.Enumerator; ptr : ANY; s : XML.String;
			selectedPageNr : LONGINT;
		BEGIN
			selectedPageNr := -1;
			enum := pages.GetContents(); enum.Reset;
			WHILE (enum.HasMoreElements()) DO
				ptr := enum.GetNext();
				IF ptr IS XML.Element THEN
					elem := ptr(XML.Element);
					s := elem.GetName();
					IF (s # NIL) & (s^ = "Tab") THEN
						LoadPage(elem);
					ELSIF (s # NIL) & (s^ = "General") THEN
						WMRestorable.LoadLongint(elem, "SelectedPageNr", selectedPageNr);
						WMRestorable.LoadString(elem, "ProjectTextFile", projectTextFilename);
						IF projectTextFilename # "" THEN
							projectText := LoadText(projectTextFilename);
							projectText.onTextChanged.Add(ProjectTextModified);
						END;
					END;
				END;
			END;
			IF (selectedPageNr >= 0) & (selectedPageNr < LEN(SELF.pages)) & (SELF.pages[selectedPageNr] # NIL) THEN
				TabSelected(NIL, tabList[selectedPageNr]);
				tabs.Select(tabList[selectedPageNr]);
			END;
		END LoadPages;

		PROCEDURE StorePages() : XML.Element;
		VAR data, elem : WMRestorable.XmlElement; i : LONGINT;
		BEGIN
			NEW(data); data.SetName("PETData");
			NEW(elem); elem.SetName("General");
			WMRestorable.StoreLongint(elem, "SelectedPageNr", currentPageNr);
			WMRestorable.StoreString(elem, "ProjectTextFile", projectTextFilename);
			data.AddContent(elem);
			WHILE (i < MaxNbrOfTabs) DO
				IF (pages[i] # NIL) THEN
					elem := StorePage(pages[i]);
					data.AddContent(elem);
				END;
				INC(i)
			END;
			RETURN data;
		END StorePages;

		PROCEDURE LoadPage(page : WMRestorable.XmlElement);
		VAR
			entries: XMLObjects.Enumerator;
			entry : XML.Element;
			s : Strings.String;
			firstLine, cursorPos, width, height : LONGINT;
			options : CompilerOptions;
			showLabels, wordWrap, visible, wrap, caseSensitive, backwards, highlightAll : BOOLEAN;
			searchString, replaceString : WMSearchComponents.SearchString;
			ptr : ANY;
		BEGIN
			WMRestorable.LoadString(page, "codecFormat", codecFormat);
			WMRestorable.LoadString(page, "compilerOptions", options);
			WMRestorable.LoadBoolean(page, "showLabels", showLabels);
			WMRestorable.LoadBoolean(page, "wordWrap", wordWrap);
			WMRestorable.LoadStringPtr(page, "file", s);
			IF (s # NIL) THEN
				Load(s^, codecFormat);
				COPY(options, currentPage.options);
				optionsEdit.SetAsString(options);
				IF showLabels THEN currentPage.ToggleLabels; labelsBtn.SetPressed(TRUE); END;
				IF wordWrap THEN currentPage.ToggleWrap; wrapBtn.SetPressed(TRUE); END;

				entries := page.GetContents(); entries.Reset;
				WHILE(entries.HasMoreElements()) DO
					ptr := entries.GetNext();
					IF ptr IS XML.Element THEN
						entry := ptr (XML.Element);
						s := entry.GetName();
						IF (s # NIL) THEN
							IF (s^ = "Editor") THEN
								WMRestorable.LoadLongint(entry, "firstLine", firstLine);
								WMRestorable.LoadLongint(entry, "cursorPos", cursorPos);
								currentPage.editor.tv.firstLine.Set(firstLine);
								currentPage.editor.tv.cursor.SetPosition(cursorPos);
							ELSIF (s^ = "SplitEditor") THEN
								WMRestorable.LoadLongint(entry, "firstLine", firstLine);
								WMRestorable.LoadLongint(entry, "cursorPos", cursorPos);
								WMRestorable.LoadBoolean(entry, "visible", visible);
								WMRestorable.LoadLongint(entry, "height", height);
								currentPage.splitEditor.tv.firstLine.Set(firstLine);
								currentPage.splitEditor.tv.cursor.SetPosition(cursorPos);
								currentPage.splitPanel.visible.Set(visible);
								currentPage.splitted := visible;
								currentPage.splitPanel.bounds.SetHeight(height);
							ELSIF (s^ = "SidePanel") THEN
								WMRestorable.LoadBoolean(entry, "visible", visible);
								WMRestorable.LoadLongint(entry, "width", width);
								WMRestorable.LoadLongint(entry, "scratchHeight", height);
								currentPage.sidePanel.visible.Set(visible);
								currentPage.sidePanel.bounds.SetWidth(width);
								currentPage.scratchPanel.bounds.SetHeight(height);
							ELSIF (s^ = "SearchPanel") THEN
								WMRestorable.LoadBoolean(entry, "visible", visible);
								WMRestorable.LoadBoolean(entry, "wrap", wrap);
								WMRestorable.LoadBoolean(entry, "casesensitive", caseSensitive);
								WMRestorable.LoadBoolean(entry, "backwards", backwards);
								WMRestorable.LoadBoolean(entry, "highlight", highlightAll);
								WMRestorable.LoadString(entry, "searchString", searchString);
								WMRestorable.LoadString(entry, "replaceString", replaceString);
								currentPage.searchPanel.visible.Set(visible);
								currentPage.searchPanel.SetSettings(wrap, caseSensitive, backwards, highlightAll);
								currentPage.searchPanel.searchEdit.SetAsString(searchString);
								currentPage.searchPanel.replEdit.SetAsString(replaceString);
							ELSIF (s^ = "LogPanel") THEN
								WMRestorable.LoadLongint(entry, "height", height);
								currentPage.logPanel.bounds.SetHeight(height);
							END;
						END;
					END;
				END; (* WHILE (entries.HasMoreElements() *)
			END;
		END LoadPage;

		PROCEDURE StorePage(page : PETPanel) : WMRestorable.XmlElement;
		VAR
			elem, entry : WMRestorable.XmlElement;
			wrap, caseSensitive, backwards, highlightAll : BOOLEAN;
			string : WMSearchComponents.SearchString;
		BEGIN
			ASSERT(page # NIL);
			NEW(elem); elem.SetName("Tab");
			WMRestorable.StoreString(elem, "file", page.filename);
			WMRestorable.StoreString(elem, "codecFormat", page.codecFormat);
			WMRestorable.StoreString(elem, "compilerOptions", page.options);
			WMRestorable.StoreBoolean(elem, "showLabels", page.editor.tv.showLabels.Get());
			WMRestorable.StoreBoolean(elem, "wordWrap", page.editor.tv.wrapMode.Get() = WMTextView.WrapWord);

			NEW(entry); entry.SetName("Editor");
				WMRestorable.StoreLongint(entry, "firstLine", page.editor.tv.firstLine.Get());
				WMRestorable.StoreLongint(entry, "cursorPos", page.editor.tv.cursor.GetPosition());
			elem.AddContent(entry);

			NEW(entry); entry.SetName("SplitEditor");
				WMRestorable.StoreBoolean(entry, "visible", page.splitPanel.visible.Get());
				WMRestorable.StoreLongint(entry, "firstLine", page.splitEditor.tv.firstLine.Get());
				WMRestorable.StoreLongint(entry, "cursorPos", page.splitEditor.tv.cursor.GetPosition());
				WMRestorable.StoreLongint(entry, "height", page.splitPanel.bounds.GetHeight());
			elem.AddContent(entry);

			NEW(entry); entry.SetName("SearchPanel");
				page.searchPanel.GetSettings(wrap, caseSensitive, backwards, highlightAll);
				WMRestorable.StoreBoolean(entry, "visible", page.searchPanel.visible.Get());
				WMRestorable.StoreBoolean(entry, "wrap", wrap);
				WMRestorable.StoreBoolean(entry, "casesensitive", caseSensitive);
				WMRestorable.StoreBoolean(entry, "backwards", backwards);
				WMRestorable.StoreBoolean(entry, "highlight", highlightAll);
				page.searchPanel.searchEdit.GetAsString(string);
				WMRestorable.StoreString(entry, "searchString", string);
				page.searchPanel.replEdit.GetAsString(string);
				WMRestorable.StoreString(entry, "replaceString", string);
			elem.AddContent(entry);

			NEW(entry); entry.SetName("LogPanel");
				WMRestorable.StoreLongint(entry, "height", page.logPanel.bounds.GetHeight());
			elem.AddContent(entry);

			NEW(entry); entry.SetName("SidePanel");
				WMRestorable.StoreBoolean(entry, "visible", page.sidePanel.visible.Get());
				WMRestorable.StoreLongint(entry, "width", page.sidePanel.bounds.GetWidth());
				WMRestorable.StoreLongint(entry, "scratchHeight", page.scratchPanel.bounds.GetHeight());
			elem.AddContent(entry);

			RETURN elem;
		END StorePage;

		PROCEDURE HandleShortcut(ucs : LONGINT; flags : SET; keysym : LONGINT) : BOOLEAN;
		VAR filename : Filename; options : CompilerOptions;
		BEGIN
			modifierFlags := flags;
			IF DisableShortcuts THEN RETURN FALSE; END;
			IF (keysym = 13H) & ControlKeyDown(flags) THEN (* CTRL-S *)
				StoreHandler(NIL, NIL);
			ELSIF (keysym = 20H) & ControlKeyDown(flags) THEN (* CTRL-<space> *)
				CompleteHandler(NIL, NIL);
			ELSIF (keysym = 08H) & ControlKeyDown(flags) THEN (* CTRL-H *)
				IF currentPage # NIL THEN
					optionsEdit.GetAsString(options);
					currentPage.DoCompile(FALSE, "", options);
				END;
			ELSIF (keysym = 0FH) & ControlKeyDown(flags) THEN (* CTRL-O *)
				filenameEdit.SetAsString("");
				filenameEdit.SetFocus;
			ELSIF (keysym = Inputs.KsPageDown) & ControlKeyDown(flags) THEN (* CTRL-PgDn *)
				IF (WMDialogs.QueryString("Save PET state into (.pet extension is appended)", filename) = WMDialogs.ResOk) & (filename # "") THEN
					Strings.Append(filename, StateFileExtension);
					StoreState(filename);
				END;
			ELSIF (keysym = Inputs.KsPageUp) & ControlKeyDown(flags) THEN (* CTRL-PgUp *)
				IF (WMDialogs.QueryString("Load PET state from (.pet extension  is appended)", filename) = WMDialogs.ResOk) & (filename # "") THEN
					DisableUpdate;
					IF CloseAllTabs() THEN
						Strings.Append(filename, StateFileExtension);
						IF LoadState(filename) THEN
							UpdatePages;
							UpdateState;
						END;
					END;
					EnableUpdate;
					form.Invalidate;
				END;
			ELSIF (keysym = Inputs.KsTab) & ControlKeyDown(flags) THEN (* CTRL-Tab *)
				DisableUpdate; SelectNextTab; EnableUpdate;
			ELSIF (keysym = Inputs.KsTab) & (flags * Inputs.Ctrl # {}) & (flags * Inputs.Shift # {}) &
					(flags - Inputs.Ctrl - Inputs.Shift = {}) THEN (* CTRL-SHIFT-Tab *)
				DisableUpdate; SelectPreviousTab; EnableUpdate;
			ELSIF (keysym = 015H) & ControlKeyDown(flags) THEN (* CTRL-U *)
				IF (currentPage # NIL) THEN UnloadModule; END;

			(* relay hot key to current page *)
			ELSIF (currentPage = NIL) OR ((currentPage # NIL) & (~currentPage.HandleShortcut(ucs, flags, keysym))) THEN
				RETURN FALSE; (* Key not handled *)
			END;
			RETURN TRUE;
		END HandleShortcut;

		PROCEDURE Handle(VAR m: WMMessages.Message);
		VAR data : WMRestorable.XmlElement;
		BEGIN
			IF m.msgType = WMMessages.MsgKey THEN
				IF ~HandleShortcut(m.x, m.flags, m.y) THEN
					Handle^(m);
				END;
			ELSIF (m.msgType = WMMessages.MsgExt) & (m.ext # NIL) THEN
				IF (m.ext IS KillerMsg) THEN Close
				ELSIF (m.ext IS WMRestorable.Storage) THEN
					data := StorePages();
					m.ext(WMRestorable.Storage).Add("TFPET", "TFPET.Restore", SELF, data)
				ELSE Handle^(m)
				END
			ELSE Handle^(m)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;
	scratchText : Texts.Text;
	scratchModified : BOOLEAN;
	settings : Settings;

	StrScratchPanel, StrPETPanel : Strings.String;

(** Open document *)
PROCEDURE Open*(context : Commands.Context); (** [Options] {filename['@'position]} ~ *)
VAR
	window : Window; count, index, temp, position : LONGINT;
	filename : Filename; format : ARRAY 32 OF CHAR;
	options: Options.Options;
BEGIN
	NEW(options);
	options.Add("e","external",Options.Flag);
	options.Add("f", "format", Options.String);
	IF options.Parse(context.arg, context.out) THEN
		IF (context.caller # NIL) & (context.caller IS Window) & ~options.GetFlag("external") THEN
			window := context.caller(Window);
		ELSE
			NEW(window, NIL);
		END;
		IF ~options.GetString("format", format) THEN format := "AUTO"; END;
		count := 0;
		WHILE context.arg.GetString(filename) DO
			position := 0; index := Strings.Find(filename, 0, '@');
			IF index >= 0 THEN temp := index + 1; Strings.StrToIntPos(filename, position, temp); ASSERT (position # 0); Strings.Truncate(filename, index) END;
			IF filename # "" THEN window.Load(filename, format); window.SetCursorPosition(position); INC(count) END
		END;
		IF count = 0 THEN window.Load("Untitled.Mod", "AUTO") END;
	END;
END Open;

PROCEDURE OpenState*(context : Commands.Context); (** filename ~ *)
VAR filename : Filename; window : Window;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(filename);
	NEW(window, NIL);
	IF ~window.LoadState(filename) THEN
		context.error.String("PET: Could not  state from file "); context.error.String(filename); context.error.Ln;
	END;
END OpenState;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
BEGIN
	NEW(w, context)
END Restore;

(** Comment the currently selected text *)
PROCEDURE CommentSelection*(text : Texts.Text; from, to : Texts.TextPosition);
VAR a, b : LONGINT; string : ARRAY 4 OF Texts.Char32;
BEGIN
	ASSERT((text # NIL) & (from # NIL) & (to # NIL));
	text.AcquireWrite;
	a := Strings.Min(from.GetPosition(), to.GetPosition());
	b := Strings.Max(from.GetPosition(), to.GetPosition());
	string[0] := ORD(" "); string[1] := ORD("*"); string[2] := ORD(")"); string[3] := 0;
	text.InsertUCS32(b, string);
	string[0] := ORD("("); string[1] := ORD("*"); string[2] := ORD(" "); string[3] := 0;
	text.InsertUCS32(a, string);
	IF (a <= b) THEN from.SetPosition(a); ELSE to.SetPosition(a); END;
	text.ReleaseWrite;
	Texts.SetLastSelection(text, from, to);
END CommentSelection;

(** Uncomment the currently selected text if it is commented *)
PROCEDURE UncommentSelection*(text : Texts.Text; from, to : Texts.TextPosition);
VAR
	reader : Texts.TextReader; ch : Texts.Char32;
	a, b : LONGINT;
	openPos, closePos, openLen, closeLen : LONGINT;
BEGIN
	text.AcquireWrite;
	a := Strings.Min(from.GetPosition(), to.GetPosition());
	b := Strings.Max(from.GetPosition(), to.GetPosition());

	NEW(reader, text);

	(* find open *)
	openPos := -1; openLen := 2;
	reader.SetPosition(a);
	REPEAT reader.ReadCh(ch); UNTIL reader.eot OR ~TextUtilities.IsWhiteSpace(ch, FALSE) OR (reader.GetPosition() >= b);
	IF (ch = ORD("(")) THEN
		reader.ReadCh(ch);
		IF (ch = ORD("*")) THEN
			openPos := reader.GetPosition() - 2;
			reader.ReadCh(ch);
			IF (ch = ORD(" ")) THEN INC(openLen); END; (* delete the space character right to the open comment string *)
		END;
	END;

	(* find close *)
	closePos := -1; closeLen := 2;
	IF (openPos > 0) THEN
		reader.SetDirection(-1);
		reader.SetPosition(b - 1);
		REPEAT reader.ReadCh(ch); UNTIL reader.eot OR ~TextUtilities.IsWhiteSpace(ch, FALSE) OR (reader.GetPosition() <= a);
		IF (ch = ORD(")")) THEN
			reader.ReadCh(ch);
			IF (ch = ORD("*")) THEN
				closePos := reader.GetPosition() + 1;
				reader.ReadCh(ch);
				IF (ch = ORD(" ")) & (openPos + openLen - 1 < closePos - closeLen + 2) THEN
					(* delete the space character left to the close comment string *)
					INC(closeLen); DEC(closePos);
				END;
			END;
		END;
	END;

	IF (openPos + openLen - 1 < closePos) THEN
		text.Delete(closePos, closeLen);
		text.Delete(openPos, openLen);
	END;
	text.ReleaseWrite;
END UncommentSelection;

(** Comment the currently selected text *)
PROCEDURE Comment*;
VAR text : Texts.Text; from, to : Texts.TextPosition;
BEGIN
	IF Texts.GetLastSelection(text, from, to) THEN
		CommentSelection(text, from, to);
	END;
END Comment;

(** Uncomment the currently selected text if it is commented *)
PROCEDURE Uncomment*;
VAR text : Texts.Text; from, to : Texts.TextPosition;
BEGIN
	IF Texts.GetLastSelection(text, from, to) THEN
		UncommentSelection(text, from, to);
	END;
END Uncomment;

PROCEDURE GetSyntaxHighlighterName*(fullname : ARRAY OF CHAR; VAR name : ARRAY OF CHAR);
VAR filename, extension, config : Files.FileName; res : LONGINT;
BEGIN
	name := "";
	Strings.UpperCase(fullname);
	Strings.GetExtension(fullname, filename, extension);
	IF (extension # "") THEN
		config := "Applications.PET.SyntaxHighlighter.";
		Strings.AppendX(config, extension);
		Configuration.Get(config, name, res);
		IF (res # Configuration.Ok) THEN name := ""; END;
	END;
END GetSyntaxHighlighterName;

PROCEDURE ControlKeyDown(flags : SET) : BOOLEAN;
BEGIN
	RETURN (flags * Inputs.Ctrl # {}) & (flags - Inputs.Ctrl = {});
END ControlKeyDown;

PROCEDURE EitherShiftOrControlDown(flags : SET) : BOOLEAN;
BEGIN
	RETURN ((flags * Inputs.Shift # {}) & (flags * Inputs.Ctrl = {})) OR ((flags * Inputs.Ctrl # {}) & (flags * Inputs.Shift = {}));
END EitherShiftOrControlDown;

PROCEDURE ContainsFileExtension(filename , extension : ARRAY OF CHAR) : BOOLEAN;
BEGIN
	Strings.UpperCase(filename);
	Strings.UpperCase(extension);
	RETURN Strings.Pos(extension, filename) > 0;
END ContainsFileExtension;

PROCEDURE ScratchModified(sender, data : ANY);
BEGIN {EXCLUSIVE}
	scratchModified := TRUE
END ScratchModified;

PROCEDURE StoreScratchText;
BEGIN (* caller holds module lock *)
	IF scratchModified THEN
		StoreText(ScratchTextFilename, scratchText);
		scratchModified := FALSE;
	END;
END StoreScratchText;

PROCEDURE LoadScratchText;
BEGIN (* caller holds module lock *)
	scratchText := LoadText(ScratchTextFilename);
	scratchText.onTextChanged.Add(ScratchModified);
END LoadScratchText;

PROCEDURE StoreText(CONST filename : ARRAY OF CHAR; text : Texts.Text);
VAR res : LONGINT;
BEGIN
	text.AcquireRead;
	TextUtilities.StoreOberonText(text, filename, res);
	text.ReleaseRead
END StoreText;

PROCEDURE LoadText(CONST filename : ARRAY OF CHAR) : Texts.Text;
VAR text : Texts.Text; res : LONGINT;
BEGIN
	NEW(text);
	text.AcquireWrite;
	TextUtilities.LoadOberonText(text, filename, res);
	text.ReleaseWrite;
	RETURN text;
END LoadText;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
	IF (nofWindows = 1) THEN
		NEW(settings); settings.Load;
		LoadScratchText;
	END;
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
	IF (nofWindows = 0) THEN
		StoreScratchText;
		scratchText := NIL;
		settings := NIL;
	END;
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

PROCEDURE LoadModule(CONST moduleName : ARRAY OF CHAR);
VAR module : Modules.Module; msg : ARRAY 128 OF CHAR; res : LONGINT;
BEGIN
	module := Modules.ThisModule(moduleName, res, msg);
END LoadModule;

PROCEDURE InitStrings;
BEGIN
	StrScratchPanel := Strings.NewString("ScratchPanel");
	StrPETPanel := Strings.NewString("PETPanel");
END InitStrings;

BEGIN
	nofWindows := 0;
	scratchText := NIL; scratchModified := FALSE;
	Modules.InstallTermHandler(Cleanup);
	InitStrings;
END TFPET.

SystemTools.Free TFPET ~
WMMacros.ReadMacros Macros.XML ~
TFPET.Open TFAOParser.Mod~
TFPET.Open TFPET.Mod ~

SystemTools.Free TFPET WMXMLTree ~

PC.Compile TFPET.Mod ~

SystemTools.Free TFXRef TFPET TFModuleTrees TFAOParser TFDumpTS TFCheck TFScopeTools TFTypeSys BimboScanner TFStringPool~
Compiler.Compile TFStringPool.Mod BimboScanner.Mod TFTypeSys.Mod TFScopeTools.Mod TFCheck.Mod TFDumpTS.Mod TFAOParser.Mod TFModuleTrees.Mod TFPET.Mod~
TFPET.OpenState a.pet ~
(* Create .xym files for all modules in a directory *)
TFAOParser.MakeSymbolFiles "Strings" "Oberon*"~ (* main *.Mod*)
TFAOParser.MakeSymbolFiles "Trunk/" ~ (* main *.Mod*)
TFAOParser.MakeSymbolFiles "D:\Aos\trunk\source\" "*Oberon*"~ (* d:/release/*.Mod *)
TFAOParser.MakeSymbolFiles "D:\Aos\trunk\WinAos\Work\" "*Oberon*"~

AosTar.Create TFPET20061118.tar TextUtilities.Mod WMTextView.Mod TFStringPool.Mod BimboScanner.Mod TFScopeTools.Mod TFTypeSys.Mod TFCheck.Mod TFDumpTS.Mod TFAOParser.Mod
	TFModuleTrees.Mod TFPET.Mod  ~
TFPET.Open TFModuleTrees.Mod~
TFPET.Open PET.Mod~
TFPET.Open TFPET.Mod ~
TFPET.Open WMComponents.Mod~
PET.Open TFPET.Mod ~

WMTextView.Mod
Changed Highlight and TextMarker to use TextPositionKeeper instead of Texts.TextPosition
