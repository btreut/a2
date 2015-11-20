MODULE ComponentViewer;	(** AUTHOR "TF"; PURPOSE "Testbed for the component system"; *)

IMPORT
	Modules, Commands, Options, XML, Repositories, WMMessages, WMWindowManager, WMComponents,
	WMRestorable, Streams, D:= Debugging, Files, WMRectangles;

CONST
	DefaultWidth = 320;
	DefaultHeight = 240;
	InvalidPosition* =MIN(LONGINT);

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window* = OBJECT(WMComponents.FormWindow)

		PROCEDURE RestoreWindow*(c : WMRestorable.Context);
		BEGIN
			ReInit(c.r-c.l, c.b-c.t);
			(*
			Init(c.r - c.l, c.b - c.t, FALSE);
			*)
			IF c.appData # NIL THEN
				DisableUpdate;
				LoadComponents(c.appData(XML.Element));
				EnableUpdate;
			END;
			WMRestorable.AddByContext(SELF, c);
			Resized(c.r-c.l,c.b-c.t);
		END RestoreWindow;

		PROCEDURE &InitWindow(width, height : LONGINT; alpha : BOOLEAN);
		BEGIN
			IncCount;
			Init(width, height, alpha);
		END InitWindow;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR m : WMMessages.Message);
		VAR data: XML.Element;
		BEGIN
			IF (m.msgType = WMMessages.MsgExt) & (m.ext # NIL) THEN
				IF  (m.ext IS KillerMsg) THEN Close
				ELSIF (m.ext IS WMRestorable.Storage) THEN
					data := StoreComponents();
					m.ext(WMRestorable.Storage).Add("ComponentViewer", "ComponentViewer.Restore", SELF, data)
				ELSE Handle^(m);
				END;
			ELSE Handle^(m);
			END;
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE DoShow*( vc: WMComponents.VisualComponent; VAR window: Window; x,y,width, height: LONGINT; client, alpha, fullscreen: BOOLEAN;flags: SET);
VAR
	fx,fy,fw,fh: LONGINT;
	viewPort: WMWindowManager.ViewPort;
	manager: WMWindowManager.WindowManager;
BEGIN
	IF width # 0 THEN
		vc.bounds.SetWidth(width);
	ELSE
		width := vc.bounds.GetWidth();
		IF (width <= 0) THEN width := DefaultWidth; vc.bounds.SetWidth(width) END;
	END;
	IF height # 0 THEN
		vc.bounds.SetHeight(height);
	ELSE
		height := vc.bounds.GetHeight();
		IF (height <= 0) THEN height := DefaultHeight; vc.bounds.SetHeight(height) END;
	END;
	IF client THEN vc.alignment.Set(WMComponents.AlignClient) END;
	IF fullscreen THEN
		viewPort := WMWindowManager.GetDefaultView();
		fx := 0; fy := 0; fw := 1; fh := 1; (* full screen on screen number 4 *)
		x := fx * viewPort.width0;
		y := fy * viewPort.height0;
		width := fw* viewPort.width0;
		height := fh * viewPort.height0;
	END;

	IF window = NIL THEN
		NEW(window, width, height, alpha);
		window.SetTitle(vc.GetName());
		window.SetContent(vc);
		window.flags := window.flags + flags;
		manager := WMWindowManager.GetDefaultManager();
		IF (x = InvalidPosition) OR (y = InvalidPosition) THEN
			WMWindowManager.GetNextPosition(window, manager, WMWindowManager.GetDefaultView(),x,y);
		ELSIF fullscreen THEN
			x := 0; y := 0
		END;
		manager := WMWindowManager.GetDefaultManager();
		IF vc.sequencer # NIL THEN vc.sequencer.WaitFree() END;
		manager.Add(x, y, window, flags);
	ELSE
		window.SetContent(vc);
	END;
END DoShow;

PROCEDURE DoLoad*(CONST filename: ARRAY OF CHAR; error: Streams.Writer): WMComponents.VisualComponent;
VAR
	repositoryName, componentName : ARRAY 128 OF CHAR;
	moduleName, procedureName : Modules.Name;
	ignoreMsg : ARRAY 1 OF CHAR;
	generatorProc : XML.GeneratorProcedure;
	c : XML.Content; component : Repositories.Component;
	id, res : LONGINT;
BEGIN
	IF Repositories.SplitName(filename, repositoryName, componentName, id) & (repositoryName # "") THEN
		(* Retrieve component from repository *)
		Repositories.GetComponentByString(filename, component, res);
		IF (res = Repositories.Ok) THEN
			c := component;
		ELSIF error # NIL THEN
			error.String("Could not load "); error.String(filename);
			error.String(" from repository, res: "); error.Int(res, 0); error.Ln;
		END;
	ELSE
		Commands.Split(filename, moduleName, procedureName, res, ignoreMsg);
		IF (res = Commands.Ok) THEN
			(* Assume argument is a generator procedure *)
			GETPROCEDURE(moduleName, procedureName, generatorProc);
			IF (generatorProc # NIL) THEN
				c := generatorProc();
			ELSE
				(* Maybe argument is a filename *)
				c := WMComponents.Load(filename);
			END;
		ELSE
			(* Load component from XML file *)
			c := WMComponents.Load(filename);
		END;
	END;
	IF ( c # NIL ) & (c IS WMComponents.VisualComponent) THEN RETURN c(WMComponents.VisualComponent) ELSE RETURN NIL END;
END DoLoad;

PROCEDURE DoOpen*(CONST filename: ARRAY OF CHAR; error: Streams.Writer; x,y,width, height: LONGINT; client, alpha, fullscreen: BOOLEAN; flags:SET): WMComponents.VisualComponent;
VAR
	window : Window;
	c : WMComponents.VisualComponent
BEGIN
	c := DoLoad(filename, error);

	IF (c # NIL)  THEN
		DoShow(c(WMComponents.VisualComponent), window, x,y,width,height, client, alpha, fullscreen, flags);
	ELSIF error # NIL THEN
		IF (c = NIL) THEN error.String("Could not load/generate component "); error.String(filename);
		ELSE error.String(filename); error.String(" is not a VisualComponent.");
		END;
		error.Ln;
	END;
	IF (c # NIL) & (c IS WMComponents.VisualComponent) THEN RETURN c(WMComponents.VisualComponent)
	ELSE RETURN NIL
	END
END DoOpen;


PROCEDURE Open*(context : Commands.Context); (** [Options] <RepositoryName:ComponentName:ID> | <ModuleName.ProcedureName> | <Filename> ~ *)
VAR
	options : Options.Options;
	filename : ARRAY 128 OF CHAR;
	x,y, width, height: LONGINT;
	flags: SET;
	c: WMComponents.Component;
BEGIN
	NEW(options);
	options.Add("x", "xPosition", Options.Integer);
	options.Add("y", "yPosition", Options.Integer);
	options.Add("h", "height", Options.Integer);
	options.Add("w", "width", Options.Integer);
	options.Add("c", "client", Options.Flag);
	options.Add("a","alpha", Options.Flag);
	options.Add("f","fullscreen", Options.Flag);
	options.Add("n","noFocus", Options.Flag);
	options.Add("t","onTop", Options.Flag);
	options.Add("F","noFrame",Options.Flag);
	IF options.Parse(context.arg, context.error) & context.arg.GetString(filename) THEN
		IF ~options.GetInteger("width",width) THEN width := 0 END;
		IF ~options.GetInteger("height",height) THEN height := 0 END;
		IF ~options.GetInteger("x",x) THEN x := InvalidPosition END;
		IF ~options.GetInteger("y",y) THEN y := InvalidPosition END;
		IF options.GetFlag("fullscreen") THEN flags := {} ELSE flags := {WMWindowManager.FlagFrame, WMWindowManager.FlagClose, WMWindowManager.FlagMinimize} END;
		IF options.GetFlag("noFrame") THEN flags := {} ELSE flags := {WMWindowManager.FlagFrame, WMWindowManager.FlagClose, WMWindowManager.FlagMinimize} END;
		IF options.GetFlag("noFocus") THEN INCL(flags, WMWindowManager.FlagNoFocus) END;
		IF options.GetFlag("onTop") THEN INCL(flags, WMWindowManager.FlagStayOnTop) END;
		c := DoOpen(filename, context.error, x , y, width, height, options.GetFlag("client"), options.GetFlag("alpha"), options.GetFlag("fullscreen"), flags);
	ELSE
		context.error.String("Usage: ComponentViewer.Open [Options] <string> ~"); context.error.Ln;
	END;
END Open;

PROCEDURE Store*(context: Commands.Context);
VAR
	filename, name, ext, formName : ARRAY 256 OF CHAR;
	form: WMComponents.Component;
	id,res: LONGINT;
	originator: WMComponents.Component;
	parent: XML.Element;
BEGIN{EXCLUSIVE}
	context.arg.SkipWhitespace; context.arg.String(filename); D.String(filename); D.Ln;

	IF (context # NIL) & (context IS WMComponents.EventContext) THEN
		originator := context(WMComponents.EventContext).originator;
		parent := originator.GetParent();
		WHILE (parent # NIL) & (parent IS WMComponents.Component) & ~(parent IS WMComponents.Form) DO
			originator := parent(WMComponents.Component);
			parent := originator.GetParent();
		END;
	END;
	form := originator;
	(*form := GetForm(current);*)
	IF (form # NIL) & (filename # "") THEN
		Repositories.CreateRepository(filename,res);
		ASSERT(res = Repositories.Ok);
		Files.SplitExtension(filename, name, ext);
		id:= 1;
		COPY(form.GetName()^,formName);
		Repositories.PutComponent(form,name,form.GetName()^,id,res);
		ASSERT(res = Repositories.Ok);
		Repositories.StoreRepository(name,res);
		ASSERT(res = Repositories.Ok);
		Repositories.UnloadRepository(name,res);
		ASSERT(res = Repositories.Ok);
		context.out.String("stored component in repository "); context.out.String(filename); context.out.Ln;
	END;
FINALLY
END Store;


PROCEDURE Restore*(context : WMRestorable.Context);
VAR w : Window;
BEGIN
	IF context # NIL THEN
		NEW(w, 100,100,FALSE);
		w.RestoreWindow(context);
	END;
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
VAR
	die : KillerMsg;
	msg : WMMessages.Message;
	m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	(*AWAIT(nofWindows = 0)*)
END Cleanup;

BEGIN
	nofWindows := 0;
	Modules.InstallTermHandler(Cleanup)
END ComponentViewer.

SystemTools.Free ComponentViewer ~
ComponentViewer.Open FractalDemo.XML ~

ComponentViewer.Open --width=128 --height=64 --client WMStandardComponents.GenButton ~