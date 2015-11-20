MODULE MainMenu; (** AUTHOR "TF"; PURPOSE "Menu for Bluebottle"; *)

IMPORT
	KernelLog, XML, Modules, Files, Inputs,
	WMMessages, WMStandardComponents, WMComponents, WMTabComponents,
	Strings, WM := WMWindowManager;

CONST
	MenuFilePrefix = "MenuPage";

TYPE
	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		tabs : WMTabComponents.Tabs;
		pages : ARRAY 100 OF WMComponents.VisualComponent;
		tabList : ARRAY 100 OF WMTabComponents.Tab;
		currentPage : WMComponents.VisualComponent;
		currentPageNr : LONGINT;
		page : WMStandardComponents.Panel;
		moveToFront : BOOLEAN;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			pagePanel : WMStandardComponents.Panel;
			tabs : WMTabComponents.Tabs;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(1024, 60); panel.fillColor.Set(0); panel.takesFocus.Set(TRUE);

			NEW(tabs); tabs.fillColor.Set(000600080H); tabs.bounds.SetHeight(20); tabs.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(tabs);
			SELF.tabs := tabs;

			NEW(pagePanel); pagePanel.fillColor.Set(0H); pagePanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(pagePanel);
			page := pagePanel;

			RETURN panel
		END CreateForm;

		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
			view : WM.ViewPort;
		BEGIN
			vc := CreateForm();
			moveToFront := TRUE;
			currentPageNr := -1;
			tabs.onSelectTab.Add(TabSelected);

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), TRUE);
			SetContent(vc);
			SetTitle(Strings.NewString("MainMenu"));
			pointerThreshold := 10;
			manager := WM.GetDefaultManager();
			view := WM.GetDefaultView();
			manager.Add(0, view.height0 - GetHeight(), SELF, {WM.FlagNavigation, WM.FlagHidden});
		END New;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		BEGIN
			PointerMove^(x, y, keys);
			moveToFront := FALSE;
			manager.ToFront(SELF);
		END PointerMove;

		PROCEDURE PointerLeave;
		BEGIN
			PointerLeave^;
			moveToFront := TRUE;
		END PointerLeave;

		PROCEDURE SetOriginator*(extView : ANY);
		VAR view : WM.ViewPort;
		BEGIN
			IF (extView # NIL) & (extView IS WM.ViewPort) THEN
				view := extView(WM.ViewPort)
			ELSE view := WM.GetDefaultView()
			END;
			Refresh(NIL, NIL);
			IF ~(WM.FlagNavigation IN SELF.flags) THEN
				manager.SetWindowPos(SELF, ENTIER(view.range.l), ENTIER(view.range.b) - GetHeight());
			END;
			manager.ToFront(SELF)
		END SetOriginator;

		PROCEDURE UpdatePages;
		VAR i : LONGINT;
			tab : WMTabComponents.Tab;
			s : Strings.String;
		BEGIN
			DisableUpdate;
			tabs.RemoveAllTabs;
			IF currentPage # NIL THEN page.RemoveContent(currentPage);
				currentPage := NIL
			END;
			IF currentPageNr >= 0 THEN currentPage := pages[currentPageNr] END;
			FOR i := 0 TO 99 DO
				tabList[i] := NIL;
				IF pages[i] # NIL THEN
					pages[i].alignment.Set(WMComponents.AlignClient);
					tab := tabs.NewTab();
					tabs.AddTab(tab);
					tabList[i] := tab;
					s := pages[i].GetAttributeValue("caption");
					IF s = NIL THEN s := Strings.NewString("Untitled") END;
					tabs.SetTabCaption(tab, s);
					tabs.SetTabData(tab, pages[i])
				END
			END;
			IF currentPage = NIL THEN
				i := 0;
				WHILE (i < 100) & (currentPage = NIL) DO
					IF pages[i] # NIL THEN currentPage := pages[i]; currentPageNr := i END;
					INC(i);
				END
			END;
			EnableUpdate;
			IF currentPage # NIL THEN
				page.AddContent(currentPage);
				currentPage.Reset(SELF, NIL);
				page.AlignSubComponents;
				page.Invalidate;
				IF tabList[currentPageNr] # NIL THEN tabs.Select(tabList[currentPageNr]) END
			END;
			tabs.Invalidate
		END UpdatePages;

		PROCEDURE TryLoad(CONST name : ARRAY OF CHAR; pos : LONGINT);
		VAR x : XML.Content;
		BEGIN
			IF (pos >= 0) & (pos <= 99) THEN
				x := WMComponents.Load(name);
				IF x # NIL THEN
					IF x IS WMComponents.VisualComponent THEN
						pages[pos] := x(WMComponents.VisualComponent);
				 	END
				 END
			END
		END TryLoad;

		PROCEDURE LoadPages*;
		VAR mask : ARRAY 64 OF CHAR;
			name : ARRAY 256 OF CHAR; flags : SET;
			time, date, size : LONGINT;
			i: LONGINT;
			enumerator : Files.Enumerator;
			number: LONGINT;

			PROCEDURE IsNum(ch : CHAR) : BOOLEAN;
			BEGIN
				RETURN (ch >= '0') & (ch <= '9')
			END IsNum;

		BEGIN
			DisableUpdate;
			NEW(enumerator);
			FOR i := 0 TO 99 DO
				IF pages[i] = currentPage THEN currentPageNr := i END;
				pages[i] := NIL
			END;
			mask := MenuFilePrefix;
			i := Strings.Length(mask);
			Strings.Append(mask, "*.XML");
			enumerator.Open(mask, {});
			WHILE enumerator.HasMoreEntries() DO
				IF enumerator.GetEntry(name, flags, time, date, size) THEN
					i := Strings.Length(name);
					IF IsNum(name[i - 6]) & IsNum(name[i - 5]) THEN
						number := (ORD(name[i - 6]) - ORD('0')) * 10 + (ORD(name[i - 5]) - ORD('0'));
						IF pages[number] = NIL THEN (* use first incident for respecting the search path order *)
							TryLoad(name, number);
						END;
					END
				END
			END;
			enumerator.Close;
			EnableUpdate;
			UpdatePages
		END LoadPages;

		PROCEDURE Refresh(sender, data : ANY);
		BEGIN
			LoadPages
		END Refresh;

		PROCEDURE TabSelected(sender, data : ANY);
		VAR tab : WMTabComponents.Tab;
		BEGIN
			IF (data # NIL) & (data IS WMTabComponents.Tab) THEN
				DisableUpdate;
				page.RemoveContent(currentPage);
				tab := data(WMTabComponents.Tab);
				IF (tab.data # NIL) & (tab.data IS WMComponents.VisualComponent) THEN
					currentPage := tab.data(WMComponents.VisualComponent);
					page.AddContent(currentPage);
					IF ~currentPage.initialized THEN currentPage.Initialize END;
					currentPage.Reset(SELF, NIL);
					page.AlignSubComponents;
				END;
				EnableUpdate;
				page.Invalidate
			END
		END TabSelected;

		PROCEDURE Close;
		BEGIN
			Close^;
			window := NIL
		END Close;

	END Window;

(* the starter decouples the sensitive callback from the WindowManager. *)
TYPE
	Starter = OBJECT
	VAR
		originator : ANY;
		w : Window;

	PROCEDURE &Init*(o : ANY);
	BEGIN
		originator := o;
		w := NIL;
	END Init;

	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE}
			IF (window = NIL) THEN NEW(window); w := window;
			ELSE window.SetOriginator(originator);
			END;
		END;
		IF (w # NIL) THEN w.LoadPages; END;
	END Starter;

VAR
	window : Window;
	manager : WM.WindowManager;

(* This procedure is directly called by the window manager. It must be safe. *)
PROCEDURE MessagePreview(VAR m : WMMessages.Message; VAR discard : BOOLEAN);
VAR starter : Starter;
BEGIN
	IF m.msgType = WMMessages.MsgKey THEN
		IF (m.y = 0FF1BH) & ((m.flags * Inputs.Ctrl # {}) OR (m.flags * Inputs.Meta # {})) THEN
			NEW(starter, m.originator); discard := TRUE
		END
	END
END MessagePreview;

PROCEDURE Open*;
VAR w : Window;
BEGIN
	BEGIN {EXCLUSIVE}
		IF window = NIL THEN NEW(window); w := window;
		ELSE window.SetOriginator(NIL)
		END;
	END;
	IF w # NIL THEN w.LoadPages END;
END Open;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	KernelLog.String("Cleanup"); KernelLog.Ln;
	(* removal must be done in all cases to avoid system freeze *)
	manager.RemoveMessagePreview(MessagePreview);
	IF window # NIL THEN window.Close  END;
END Cleanup;

BEGIN
	manager := WM.GetDefaultManager();
	Modules.InstallTermHandler(Cleanup)
END MainMenu.

SystemTools.Free MainMenu WMTabComponents ~
MainMenu.Open ~
