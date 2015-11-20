MODULE StartMenu;

IMPORT
	Strings, XML, KernelLog, Modules, Inputs, UTF8Strings, XMLObjects,
	MainMenu, WM := WMWindowManager, WMComponents, WMStandardComponents, WMProperties, WMMessages, WMEvents,
	WMRectangles;

CONST
	DefaultPlugin = "BlockStartMenu";
	FancyMenuDesc = "Dummy.XML";
	MaxMenus = 16;
	MaxMenuButtons = 10;

TYPE
	String = Strings.String;
	EventListenerInfo = WMEvents.EventListenerInfo;
	Message = WMMessages.Message;

	Popup = OBJECT (WMComponents.FormWindow)

		PROCEDURE FocusLost;
		BEGIN manager.Remove(SELF) END FocusLost;

		PROCEDURE FocusGot;
		BEGIN manager.SetFocus(SELF) END FocusGot;

		PROCEDURE Handle(VAR msg : Message);
		BEGIN
			Handle^(msg);
			IF (msg.msgType = WMMessages.MsgExt) & (msg.ext = closePopupMsg) THEN FocusLost END;
		END Handle;

	END Popup;

	ClosePopupMsg = OBJECT
	END ClosePopupMsg;

	PluginManager = OBJECT
	VAR
		plugin : Plugin;
		currentPluginName : Strings.String; (* { currentPluginName # NIL } *)
		factory : PluginFactory;
		startIndex : LONGINT;

		PROCEDURE & New*;
		BEGIN
			NEW(factory);
			currentPluginName := NIL;
			SetPlugin(Strings.NewString(DefaultPlugin));
			startIndex := 0;
		END New;

		PROCEDURE Refresh;
		BEGIN {EXCLUSIVE}
			IF manager = NIL THEN manager := WM.GetDefaultManager() END;
			SetPlugin(pluginName.Get());
		END Refresh;

		PROCEDURE SetPlugin(name : String);
		BEGIN
			IF plugin # NIL THEN
				plugin.Close;
			END;
			IF (name # NIL) & ((currentPluginName=NIL) OR (name^ # currentPluginName^)) THEN
				currentPluginName := name;
				plugin := factory.Get(name);
				startIndex := 0;
			END;
			IF plugin # NIL THEN
				plugin.Open
			END
		END SetPlugin;

		PROCEDURE Close;
		BEGIN
			IF plugin # NIL THEN plugin.Close END
		END Close;

		PROCEDURE ShiftMenuItems(upwards : BOOLEAN);
		BEGIN
			plugin.ReopenMenuItemsShifted(upwards)
		END ShiftMenuItems;

	END PluginManager;

	PluginFactory = OBJECT

		PROCEDURE Get(type : String) : Plugin;
		VAR a : ANY;
		BEGIN
			IF type^ = "FancyStartMenu" THEN
				a := GenFancyStartMenu(); RETURN a(Plugin)
			ELSIF type^ = "BlockStartMenu" THEN
				a := GenBlockStartMenu(); RETURN a(Plugin)
			ELSE (* return default *)
				a := GenBlockStartMenu(); RETURN a(Plugin)
			END
		END Get;

	END PluginFactory;

	Plugin = OBJECT

		PROCEDURE Open;
		BEGIN HALT(311) END Open;

		PROCEDURE Close;
		BEGIN HALT(311) END Close;

		PROCEDURE ReopenMenuItemsShifted(upwards : BOOLEAN);
		BEGIN HALT(311) END ReopenMenuItemsShifted;

	END Plugin;

	SubMenuOpener* = OBJECT(WMComponents.Component)
	VAR filename : WMProperties.StringProperty;
		eRun* : EventListenerInfo;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			NEW(filename, NIL, Strings.NewString("Filename"), Strings.NewString("")); properties.Add(filename);
			NEW(eRun, Strings.NewString("Run"), Strings.NewString(""), SELF.Run); eventListeners.Add(eRun);
		END Init;

		PROCEDURE Run*(sender, par : ANY); (** Eventhandler *)
		VAR x, y : LONGINT; filename : String;
			rect : WMRectangles.Rectangle;
		BEGIN
			(* synchronize if not synchronized *)
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Run, sender, par)
			ELSE
				(* actual business logic *)
				filename := SELF.filename.Get();
				IF filename # NIL THEN
					rect := sender(WMComponents.VisualComponent).bounds.Get();
					sender(WMComponents.VisualComponent).ToWMCoordinates(0, 0, x, y);
					OpenPopup(x, y, filename^);
				 END
			END
		END Run;
	END SubMenuOpener;

	MenuButtons =  ARRAY MaxMenuButtons  OF WMStandardComponents.Button;
	SMOArr  =  ARRAY MaxMenuButtons  OF SubMenuOpener;

	FancyStartMenu = OBJECT(Plugin)
	VAR startMenu : WMComponents.FormWindow;
		nofLayouts, nofButtons, nofSMOs : LONGINT;
		menuButtons : MenuButtons;
		smos : SMOArr;

		PROCEDURE CountLayouts() : LONGINT;
		VAR i, n : LONGINT; done : BOOLEAN; s : Strings.String;
		BEGIN
			n := 0; done := FALSE;
			WHILE (i < LEN(layoutNames) - 1) & ~done DO
				s := layoutNames[i].Get();
				IF UTF8Strings.Compare(s^, FancyMenuDesc) # UTF8Strings.CmpEqual THEN
					INC(n)
				ELSE
					done := TRUE
				END;
				INC(i)
			END;
			RETURN n
		END CountLayouts;

		PROCEDURE FindSMO(c : XML.Content; VAR smo : SubMenuOpener);
		VAR enum : XMLObjects.Enumerator; found : BOOLEAN; ptr : ANY;
		BEGIN
			smo := NIL;
			IF c IS WMComponents.VisualComponent THEN
				enum := c(WMComponents.VisualComponent).GetContents();
				found := FALSE;
				WHILE enum.HasMoreElements() & ~found DO
					ptr := enum.GetNext();
					IF ptr IS SubMenuOpener THEN
						smo := ptr(SubMenuOpener);
						found := TRUE
					END
				END
			END;
		END FindSMO;

		PROCEDURE FindMenuButtonsSMO(c : XML.Content; VAR menuButtons : MenuButtons; VAR smos: SMOArr; VAR n, m : LONGINT);
		VAR enum : XMLObjects.Enumerator; i, j : LONGINT; ptr : ANY; s : Strings.String;
			b : WMStandardComponents.Button; smo : SubMenuOpener;
		BEGIN
			IF c IS WMComponents.VisualComponent THEN
				enum := c(WMComponents.VisualComponent).GetContents();
				i := 0; j := 0;
				WHILE enum.HasMoreElements() DO
					ptr := enum.GetNext();
					IF ptr IS WMStandardComponents.Button THEN
						b := ptr(WMStandardComponents.Button);
						s := b.caption.Get();
 						IF (s # NIL) & (UTF8Strings.Compare(s^, "") # UTF8Strings.CmpEqual) THEN
							menuButtons[i] := b; INC(i);
							FindSMO(b, smo);
							IF smo # NIL THEN smos[j] := smo; INC(j) END;
						END;
					END;
				END;
				n := i; m := j
			ELSE
				n := 0; m := 0;
			END;
		END FindMenuButtonsSMO;

		PROCEDURE Open;
		VAR c : XML.Content; width, height : LONGINT; view : WM.ViewPort; s : String;
		BEGIN
			nofLayouts := CountLayouts();
			s := layoutNames[pm.startIndex].Get();
			KernelLog.String("loading "); KernelLog.String(s^); KernelLog.Ln;
			c := WMComponents.Load(s^);
			IF (c # NIL) & (c IS WMComponents.VisualComponent) THEN
				FindMenuButtonsSMO(c, menuButtons, smos, nofButtons, nofSMOs);
				width := c(WMComponents.VisualComponent).bounds.GetWidth();
				height := c(WMComponents.VisualComponent).bounds.GetHeight();
				NEW(startMenu, width, height, TRUE);
				startMenu.SetTitle(Strings.NewString("StartMenu"));
				startMenu.pointerThreshold := 10;
				startMenu.DisableUpdate;
				startMenu.SetContent(c);
				startMenu.EnableUpdate;
				startMenu.Invalidate(startMenu.bounds);
				view := WM.GetDefaultView();
				manager := WM.GetDefaultManager();
				manager.Add(ENTIER(view.range.l), ENTIER(view.range.b) - height + 1, startMenu, {WM.FlagHidden});
			ELSE
				KernelLog.String("XML-file not correctly loaded"); KernelLog.Ln
			END
		END Open;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			IF startMenu # NIL THEN startMenu.Close END
		END Close;

		PROCEDURE ReplaceMenuButtonsSMO(CONST mb, newmb : MenuButtons; CONST smos, newsmos : SMOArr);
		VAR i : LONGINT; s : Strings.String;
		BEGIN
			FOR i := 0 TO nofButtons - 1 DO
				s := newmb[i].caption.Get();
				mb[i].caption.Set(s);
				s := newsmos[i].filename.Get();
				smos[i].filename.Set(s);
			END;
		END ReplaceMenuButtonsSMO;

		PROCEDURE ReopenMenuItemsShifted(upwards : BOOLEAN);
		VAR old, i : LONGINT; s : String; c : XML.Content;
			newMButtons : MenuButtons;
			newsmos : SMOArr;
			n, m : LONGINT;
		BEGIN
			old := pm.startIndex;
			IF upwards THEN
				pm.startIndex := (pm.startIndex + 1) MOD nofLayouts
			ELSE
				pm.startIndex := (pm.startIndex - 1) MOD nofLayouts
			END;
			IF old # pm.startIndex THEN
				s := layoutNames[pm.startIndex].Get();
				c := WMComponents.Load(s^);
				IF (c # NIL) & (c IS WMComponents.VisualComponent) THEN
					FindMenuButtonsSMO(c, newMButtons, newsmos, n, m);
					IF (nofButtons = nofSMOs) & (nofButtons = n) & (nofSMOs = m) THEN
						ReplaceMenuButtonsSMO(menuButtons, newMButtons, smos, newsmos);
						FOR i := 0 TO nofButtons - 1 DO
							menuButtons[i].Invalidate;
						END;
					ELSE
						KernelLog.String("layout "); KernelLog.String(s^); KernelLog.String(" does not match."); KernelLog.Ln
					END
				ELSE
					KernelLog.String("XML-file not correctly loaded"); KernelLog.Ln
				END
			END
		END ReopenMenuItemsShifted;

	END FancyStartMenu;

	BlockStartMenu = OBJECT(Plugin)
	VAR startMenu : MainMenu.Window;

		PROCEDURE Open;
		BEGIN
			NEW(startMenu);
			startMenu.SetOriginator(NIL); (* includes page loading *)
		END Open;

		PROCEDURE Close;
		BEGIN
			IF startMenu # NIL THEN startMenu.Close END
		END Close;

		PROCEDURE ReopenMenuItemsShifted(upwards : BOOLEAN);
		END ReopenMenuItemsShifted;

	END BlockStartMenu;

	(* the starter decouples the sensitive callback from the WindowManager. *)
	Starter = OBJECT
	VAR originator : ANY;

		PROCEDURE &Init*(o : ANY);
		BEGIN
			originator := o
		END Init;

	BEGIN {ACTIVE}
		pm.Refresh
	END Starter;


VAR
	stringPrototype, pluginName : WMProperties.StringProperty;
	layoutNames : ARRAY MaxMenus OF WMProperties.StringProperty;
	manager : WM.WindowManager;
	pm : PluginManager;
	p : Popup;
	closePopupMsg : ClosePopupMsg;

	PROCEDURE OpenPopup*(x, y : LONGINT; CONST filename : ARRAY OF CHAR);
	VAR m : WM.WindowManager;
		 c : XML.Content;
		width, height : LONGINT;
	BEGIN
		c := WMComponents.Load(filename);
		IF (c # NIL) & (c IS WMComponents.VisualComponent) THEN
			width := c(WMComponents.VisualComponent).bounds.GetWidth();
			height := c(WMComponents.VisualComponent).bounds.GetHeight();
			IF width <= 0 THEN width := 10 END; IF height <= 0 THEN height := 10 END;
			NEW(p, width, height, TRUE);
			p.SetContent(c);
			m := WM.GetDefaultManager(); m.Add(x, y-height, p, {WM.FlagHidden}); m.SetFocus(p)
		ELSE
			KernelLog.String(filename); KernelLog.String(" not correctly loaded"); KernelLog.Ln
		END
	END OpenPopup;

	PROCEDURE ClosePopup*;
	VAR msg : WMMessages.Message; manager : WM.WindowManager;
	BEGIN
		msg.msgType := WMMessages.MsgExt; msg.ext := closePopupMsg;
		manager := WM.GetDefaultManager();
		manager.Broadcast(msg);
	END ClosePopup;

	PROCEDURE GenSubMenuOpener*() : XML.Element;
	VAR smo : SubMenuOpener;
	BEGIN
		NEW(smo); RETURN smo
	END GenSubMenuOpener;

	PROCEDURE Open*;
	BEGIN
		pm.SetPlugin(pluginName.Get());
	END Open;

	(* load start menu with buttons shifted to the right *)
	PROCEDURE ShiftMenuItemsRight*;
	BEGIN
		pm.ShiftMenuItems(TRUE);
	END ShiftMenuItemsRight;

	(* load start menu with buttons shifted to the left *)
	PROCEDURE ShiftMenuItemsLeft*;
	BEGIN
		pm.ShiftMenuItems(FALSE);
	END ShiftMenuItemsLeft;

	(* This procedure is directly called by the window manager. It must be safe. *)
	PROCEDURE MessagePreview(VAR m : WMMessages.Message; VAR discard : BOOLEAN);
	VAR starter : Starter;
	BEGIN
		IF m.msgType = WMMessages.MsgKey THEN
			IF (m.y = 0FF1BH) & ((m.flags * Inputs.Ctrl # {}) OR (m.flags * Inputs.Meta # {})) THEN
				NEW(starter, m.originator); discard := TRUE
			END;
		ELSIF (m.msgType = WMMessages.MsgExt) & (m.ext = WMComponents.componentStyleMsg) THEN
			NEW(starter, m.originator);
		END
	END MessagePreview;

	PROCEDURE GenFancyStartMenu() : Plugin;
	VAR menu : FancyStartMenu;
	BEGIN NEW(menu); RETURN menu
	END GenFancyStartMenu;

	PROCEDURE GenBlockStartMenu() : Plugin;
	VAR menu : BlockStartMenu;
	BEGIN NEW(menu); RETURN menu
	END GenBlockStartMenu;

	PROCEDURE InitPrototypes;
	VAR plStartMenu : WMProperties.PropertyList;
		s0, s1 : ARRAY 128 OF CHAR;
		i : LONGINT;
	BEGIN
		NEW(plStartMenu); 	WMComponents.propertyListList.Add("StartMenu", plStartMenu);

		NEW(stringPrototype, NIL, Strings.NewString("Plugin"), Strings.NewString("Plug-in-object that creates start-menu and determines its properties"));
		stringPrototype.Set(Strings.NewString(DefaultPlugin));
		NEW(pluginName, stringPrototype, NIL, NIL); plStartMenu.Add(pluginName);

		FOR i := 0 TO LEN(layoutNames) - 1 DO
			Strings.IntToStr(i, s0);
			COPY("Layout", s1);
			Strings.Append(s1, s0);
			NEW(stringPrototype, NIL, Strings.NewString(s1), Strings.NewString("XML-file that determins content and layout of the fancy start-menu"));
			stringPrototype.Set(Strings.NewString(FancyMenuDesc));
			NEW(layoutNames[i], stringPrototype, NIL, NIL); plStartMenu.Add(layoutNames[i]);
		END;
	END InitPrototypes;

	PROCEDURE Cleanup;
	BEGIN
		IF pm # NIL THEN pm.Close END;
		manager.RemoveMessagePreview(MessagePreview)
	END Cleanup;

	PROCEDURE Fancy*;
	BEGIN
		pluginName.Set(Strings.NewString("FancyStartMenu"));
	END Fancy;

	PROCEDURE Block*;
	BEGIN
		pluginName.Set(Strings.NewString("BlockStartMenu"));
	END Block;

BEGIN
	NEW(pm);
	NEW(closePopupMsg);
	InitPrototypes;
	Modules.InstallTermHandler(Cleanup);
	manager := WM.GetDefaultManager();
	manager.InstallMessagePreview(MessagePreview);
END StartMenu.
