MODULE WebBrowser; (** AUTHOR "Simon L. Keel"; PURPOSE "Simple Web Browser GUI"; *)

IMPORT
	WebBrowserPanel, 
	Strings, KernelLog, WMGraphics, WMComponents, WMStandardComponents, WMWindowManager, WMEditors,
	Modules, WMRestorable, XML, WMRectangles, WMMessages, Commands, Files;

CONST
	HomePage = "http://bluebottle.ethz.ch";
	BrowserTitle = "BimBrowser";
	BookmarkPage = "file://bookmarks.html"; (* This URL is loaded when pressing the "Bookmarks"-button *)
	BookmarkFile = "bookmarks.html"; (* New bookmarks are appended to this file *)
	loadingNew = 0;
	loadingOld = 1;
	loadingNone = 2;

TYPE
	String = Strings.String;

	URLNode = POINTER TO RECORD
		url, title : String;
		back, forward : URLNode;
	END;

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		webPanel : WebBrowserPanel.WebPanel;
		topToolbar : WMStandardComponents.Panel;
		urlEdit : WMEditors.Editor;
		back, forward, reload, home, bookm, addBM, go : WMStandardComponents.Button;
		loadID : LONGINT;
		actualURL : URLNode;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
		BEGIN

			NEW(topToolbar); topToolbar.bounds.SetHeight(20); topToolbar.alignment.Set(WMComponents.AlignTop);

			NEW(panel); panel.bounds.SetExtents(1000, 650); panel.fillColor.Set(0FFFFFFFFH); panel.takesFocus.Set(TRUE);
			NEW(topToolbar); topToolbar.bounds.SetHeight(20); topToolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(topToolbar);

			NEW(back); back.caption.SetAOC("Back"); back.alignment.Set(WMComponents.AlignLeft);
			back.onClick.Add(Back);
			topToolbar.AddContent(back);

			NEW(forward); forward.caption.SetAOC("Forward"); forward.alignment.Set(WMComponents.AlignLeft);
			forward.onClick.Add(Forward);
			topToolbar.AddContent(forward);

			NEW(reload); reload.caption.SetAOC("Reload"); reload.alignment.Set(WMComponents.AlignLeft);
			reload.onClick.Add(Reload);
			topToolbar.AddContent(reload);

			NEW(home); home.caption.SetAOC("Home"); home.alignment.Set(WMComponents.AlignLeft);
			home.onClick.Add(Home);
			topToolbar.AddContent(home);

			NEW(bookm); bookm.caption.SetAOC("Bookmarks"); bookm.alignment.Set(WMComponents.AlignLeft);
			bookm.bounds.SetWidth(77);
			bookm.onClick.Add(Bookmarks);
			topToolbar.AddContent(bookm);

			NEW(addBM); addBM.caption.SetAOC("Add Bookmark"); addBM.alignment.Set(WMComponents.AlignLeft);
			addBM.bounds.SetWidth(97);
			addBM.onClick.Add(AddBookmark);
			topToolbar.AddContent(addBM);

			NEW(go); go.caption.SetAOC("Go"); go.alignment.Set(WMComponents.AlignRight);
			go.onClick.Add(Go);
			topToolbar.AddContent(go);

			NEW(urlEdit); urlEdit.alignment.Set(WMComponents.AlignClient);
			urlEdit.tv.textAlignV.Set(WMGraphics.AlignCenter);
			urlEdit.multiLine.Set(FALSE); urlEdit.bounds.SetWidth(500);
			topToolbar.AddContent(urlEdit); urlEdit.fillColor.Set(0FFFFFFFFH);
			urlEdit.tv.showBorder.Set(TRUE);
			urlEdit.tv.borders.Set(WMRectangles.MakeRect(3,3,1,1));
			urlEdit.onEnter.Add(Go);

			NEW(webPanel);
			 webPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(webPanel);

			webPanel.notify := Notify;
			webPanel.openNewWindow := OpenLinkFromString;
			webPanel.loadLink := LoadExternal;

			RETURN panel
		END CreateForm;

		PROCEDURE &New*(c : WMRestorable.Context; url : String);
		VAR
			vc : WMComponents.VisualComponent;
			xml : XML.Element;
			m : WMWindowManager.WindowManager;
			indent : LONGINT;
		BEGIN
			IncCount;
			loadID := 0;
			vc := CreateForm();
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WebBrowser.png", TRUE));

			IF c # NIL THEN
				(* restore the desktop *)
				WMRestorable.AddByContext(SELF, c);
				IF c.appData # NIL THEN
					xml := c.appData(XML.Element);
					url := xml.GetAttributeValue("url");
					Resized(GetWidth(), GetHeight())
				END
			ELSE
				WMWindowManager.DefaultAddWindow(SELF);
				indent := leftW.bounds.r;
				IF topW.bounds.b > indent THEN indent := topW.bounds.b; END;
				m := GetManager();
				m.SetWindowPos(SELF, (nofWindows-1) * indent + leftW.bounds.r, (nofWindows-1) * indent + topW.bounds.b);
			END;

			IF url = NIL THEN
				url := Strings.NewString(HomePage);
			END;

			NEW(actualURL);
			actualURL.url := Strings.NewString(url^);

			Load();

		END New;

		PROCEDURE Load;
		VAR
			s : String;
		BEGIN
			urlEdit.SetAsString(actualURL.url^);
			IF actualURL.title = NIL THEN
				SetTitle(Strings.NewString(BrowserTitle));
			ELSE
				s := Strings.ConcatToNew(actualURL.title^, " - ");
				s := Strings.ConcatToNew(s^, BrowserTitle);
				SetTitle(s);
			END;
			webPanel.url.Set(actualURL.url);
			webPanel.Load(loadID);
			loadID := (loadID + 1) MOD (MAX(LONGINT));
		END Load;

		PROCEDURE Go(sender, data : ANY);
		VAR
			urlNode : URLNode;
			urlAOC : ARRAY 1024 OF CHAR;
			i: LONGINT;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Go, sender, data)
			ELSE
				NEW(urlNode);
				urlEdit.GetAsString(urlAOC);
				i := Strings.Pos("://", urlAOC);
				IF i = -1 THEN
					urlNode.url := Strings.ConcatToNew("http://", urlAOC);
				ELSE
					urlNode.url := Strings.NewString(urlAOC);
				END;
				actualURL.forward := urlNode;
				urlNode.back := actualURL;
				actualURL := urlNode;
				Load();
			END;
		END Go;

		PROCEDURE Back(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Back, sender, data)
			ELSE
				IF actualURL.back # NIL THEN
					actualURL := actualURL.back;
					Load();
				END;
			END;
		END Back;

		PROCEDURE Forward(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Forward, sender, data)
			ELSE
				IF actualURL.forward # NIL THEN
					actualURL := actualURL.forward;
					Load();
				END;
			END;
		END Forward;

		PROCEDURE Reload(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Reload, sender, data)
			ELSE
				Load();
			END;
		END Reload;

		PROCEDURE Home(sender, data : ANY);
		VAR
			urlNode : URLNode;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Home, sender, data)
			ELSE
				NEW(urlNode);
				urlNode.url := Strings.NewString(HomePage);
				actualURL.forward := urlNode;
				urlNode.back := actualURL;
				actualURL := urlNode;
				Load();
			END;
		END Home;

		PROCEDURE Bookmarks(sender, data : ANY);
		VAR
			urlNode : URLNode;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Bookmarks, sender, data)
			ELSE
				NEW(urlNode);
				urlNode.url := Strings.NewString(BookmarkPage);
				actualURL.forward := urlNode;
				urlNode.back := actualURL;
				actualURL := urlNode;
				Load();
			END;
		END Bookmarks;

		PROCEDURE LoadExternal*(sender, data : ANY);
		VAR
			link, target : String;
			urlNode : URLNode;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.LoadExternal, sender, data)
			ELSE
				WebBrowserPanel.DecodeLinkData(data, link, target);
				NEW(urlNode);
				urlNode.url := Strings.NewString(link^);
				actualURL.forward := urlNode;
				urlNode.back := actualURL;
				actualURL := urlNode;
				Load();
			END;
		END LoadExternal;

		PROCEDURE Notify(sender, data : ANY);
		VAR
			msg : WebBrowserPanel.NotifyMsg;
			s : String;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Notify, sender, data)
			ELSE
				IF loadID # SELF.loadID THEN RETURN END;
				msg := data(WebBrowserPanel.NotifyMsg);
				IF msg.url # NIL THEN
					actualURL.url := Strings.NewString(msg.url^);
					urlEdit.SetAsString(actualURL.url^);
				END;
				IF (msg.title # NIL) & (msg.title^ # "") THEN
					actualURL.title := Strings.NewString(msg.title^);
					s := Strings.ConcatToNew(actualURL.title^, " - ");
					s := Strings.ConcatToNew(s^, BrowserTitle);
					SetTitle(s);
				END;
			END;
		END Notify;

		PROCEDURE AddBookmark(sender, data : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.AddBookmark, sender, data)
			ELSE
				IF actualURL.title # NIL THEN
					AddBookmarkToFile(actualURL.url^, actualURL.title^);
				ELSE
					AddBookmarkToFile(actualURL.url^, actualURL.url^);
				END;
			END;
		END AddBookmark;

		PROCEDURE Close;
		BEGIN
			webPanel.notify := NIL;
			webPanel.openNewWindow := NIL;
			webPanel.loadLink := NIL;
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		VAR
			data : XML.Element;
			a : XML.Attribute;
			n : ARRAY 16 OF CHAR;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS KillerMsg) THEN Close
				ELSIF (x.ext IS WMRestorable.Storage) THEN
					NEW(data);  n := "WebBrowserData"; data.SetName(n);
					NEW(a); n := "url"; a.SetName(n); a.SetValue(actualURL.url^); data.AddAttribute(a);
					x.ext(WMRestorable.Storage).Add("WebBrowser", "WebBrowser.Restore", SELF, data)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE AddBookmarkToFile(CONST link : ARRAY OF CHAR; title : ARRAY OF CHAR);
VAR
	file : Files.File;
	w : Files.Writer;
BEGIN
	Strings.TrimWS(title);
	file := Files.Old(BookmarkFile);
	IF file = NIL THEN
		file := Files.New(BookmarkFile);
		IF file = NIL THEN
			KernelLog.String("Writing "); KernelLog.String(BookmarkFile); KernelLog.String(" failed."); KernelLog.Ln;
			RETURN;
		END;
		Files.OpenWriter(w, file, 0);
		w.String('<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">'); w.Ln();
		w.String("<TITLE>Bookmarks</TITLE>"); w.Ln();
		w.String("<H1>Bookmarks</H1>"); w.Ln();
		w.Ln();
		w.String("<DL><P>"); w.Ln();
	ELSE
		Files.OpenWriter(w, file, file.Length());
	END;
	w.String('    <DT><A HREF="');
	w.String(link);
	w.String('">');
	w.String(title);
	w.String('</A>');
	w.Ln();
	w.Update();
	Files.Register(file);
	file.Update;
END AddBookmarkToFile;

PROCEDURE Open*;
VAR inst : Window;
BEGIN
	NEW(inst, NIL, NIL);
END Open;

PROCEDURE OpenURL*(context : Commands.Context);
VAR inst : Window; name : ARRAY 1024 OF CHAR;
BEGIN
	IF context.arg.GetString(name) THEN
		NEW(inst, NIL, Strings.NewString(name));
	END;
END OpenURL;

PROCEDURE OpenFile*(context : Commands.Context);
VAR inst : Window; prefix, name, path : ARRAY 1024 OF CHAR; urlpath, url : String; i,j:LONGINT;
BEGIN
	IF context.arg.GetString(name) THEN
		Files.SplitName(name, prefix, path);
		j:=0;
		FOR i:=0 TO Strings.Length(path)-1 DO
			IF path[i]#" " THEN name[j]:=path[i]
			ELSE name[j]:="%"; name[j+1]:="2"; name[j+2]:="0"; INC(j,2);
			END;
			INC(j);
		END;
		name[j]:=0X;
		path:="file://"; 
		IF prefix#"" THEN Strings.Append(path,prefix); Strings.Append(path,":"); END;
		url := Strings.ConcatToNew(path, name);
		NEW(inst, NIL, url);
	END;
END OpenFile;

PROCEDURE OpenLinkFromString*(url : String);
VAR inst : Window;
BEGIN
	NEW(inst, NIL, url);
END OpenLinkFromString;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
BEGIN
	NEW(w, context, NIL)
END Restore;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WebBrowser.

PC.Compile \s WMCharCodes.Mod NewHTTPClient.Mod Strings.Mod WebBrowserComponents.Mod XMLTransformer.Mod HTMLTransformer.Mod HTMLScanner.Mod HTMLParser.Mod WebBrowserPanel.Mod WebBrowser.Mod~

SystemTools.Free WebBrowser WebBrowserPanel HTMLParser HTMLScanner HTMLTransformer XMLTransformer WebBrowserComponents Utilities NewHTTPClient WMCharCodes~

WebBrowser.Open ~

WebBrowser.OpenURL http://www.google.com ~
WebBrowser.OpenURL  http://www.wikipedia.org~
WebBrowser.OpenURL http://www.wikipedia.org/wiki/man ~

WebBrowser.OpenFile OberonReport.html ~

