MODULE WMApplications; (** AUTHOR "staubesv"; PURPOSE "Application Launcher"; *)

IMPORT
	KernelLog,
	Streams, Modules, Commands, Inputs, Strings, XML, XMLObjects, Repositories,
	WMGraphics, WMComponents, WMMessages, WMRestorable, WMWindowManager;

CONST
	Ok = 0;
	RepositoryNotFound = 1;
	ApplicationNotFound = 2;
	ParseError = 3;

	DefaultWidth = 640;
	DefaultHeight = 480;
	DefaultAlpha = FALSE;

	(* Default window flags *)
	FlagFrame = TRUE;
	FlagClose = TRUE;
	FlagMinimize = TRUE;
	FlagStayOnTop = FALSE;
	FlagStayOnBottom = FALSE;
	FlagNoFocus = FALSE;
	FlagNavigation = FALSE;
	FlagHidden = FALSE;
	FlagNoResizing = FALSE;

	Mode_Standard = 0;
	Mode_Move = 1;
	Mode_ResizeLeft = 2;
	Mode_ResizeTopLeft = 3;
	Mode_ResizeTop = 4;
	Mode_ResizeTopRight = 5;
	Mode_ResizeRight = 6;
	Mode_ResizeBottomRight = 7;
	Mode_ResizeBottom = 8;
	Mode_ResizeBottomLeft = 9;

	ResizeAreaSize = 10;

	MinimumWidth = 20;
	MinimumHeight = 20;

TYPE

	WindowInfo = RECORD
		title : Strings.String;
		icon : Strings.String;
		width, height : LONGINT;
		alpha : BOOLEAN;
		flags : SET;
		alternativeMoveResize : BOOLEAN;
	END;

	ApplicationInfo = RECORD
		repository : Repositories.Repository; (* {repository # NIL} *)
		name : Repositories.Name;
		content : WMComponents.VisualComponent;
		window : WindowInfo;
	END;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	Window = OBJECT (WMComponents.FormWindow)
	VAR
		name : Repositories.Name;
		repository : Repositories.Repository;

		PROCEDURE &New(CONST info : ApplicationInfo; context : WMRestorable.Context);
		BEGIN
			ASSERT(info.repository # NIL);
			repository := info.repository;
			COPY(info.name, name);

			IF (context = NIL) THEN
				Init(info.window.width, info.window.height, info.window.alpha);
			ELSE
				Init(context.r - context.l, context.b - context.t, info.window.alpha);
			END;

			IF (info.content # NIL) THEN
				info.content.alignment.Set(WMComponents.AlignClient);
				SetContent(info.content);
			END;

			IF (info.window.title # NIL) THEN
				SetTitle(info.window.title);
			END;

			IF (info.window.icon # NIL) THEN
				SetIcon(WMGraphics.LoadImage(info.window.icon^, TRUE));
			END;

			IF (context # NIL) THEN
				WMRestorable.AddByContext(SELF, context);
			ELSE
				WMWindowManager.ExtAddWindow(SELF, 100, 100, info.window.flags)
			END;
			IncCount;
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount;
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		VAR data : XML.Element;
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS WMRestorable.Storage) THEN
					NEW(data); data.SetName("Data");
					data.SetAttributeValue("repository", repository.name);
					data.SetAttributeValue("name", repository.name);
					x.ext(WMRestorable.Storage).Add(name, "WMApplications.Restore", SELF, data);
				ELSIF (x.ext IS KillerMsg) THEN
					Close;
				ELSE
					Handle^(x)
				END
			ELSE
				Handle^(x)
			END
		END Handle;

	END Window;

TYPE

	GadgetWindow = OBJECT(Window);
	VAR
		lastX, lastY : LONGINT;
		mode : LONGINT;
		resized : BOOLEAN;
		viewport : WMWindowManager.ViewPort;

		PROCEDURE &New(CONST info : ApplicationInfo; context : WMRestorable.Context);
		BEGIN
			New^(info, context);
			mode := Mode_Standard;
			resized := FALSE;
			viewport := WMWindowManager.GetDefaultView();
			ASSERT(viewport # NIL);
		END New;

		PROCEDURE GetMode(x, y : LONGINT) : LONGINT;
		VAR mode, width, height : LONGINT;
		BEGIN
			width := bounds.r - bounds.l; height := bounds.b - bounds.t;
			IF (x <= ResizeAreaSize) THEN
				IF (y <= ResizeAreaSize) THEN
					mode := Mode_ResizeTopLeft;
				ELSIF (y >= height - ResizeAreaSize) THEN
					mode := Mode_ResizeBottomLeft;
				ELSE
					mode := Mode_ResizeLeft;
				END;
			ELSIF (x >= width - ResizeAreaSize) THEN
				IF (y <= ResizeAreaSize) THEN
					mode := Mode_ResizeTopRight;
				ELSIF (y >= height - ResizeAreaSize) THEN
					mode := Mode_ResizeBottomRight;
				ELSE
					mode := Mode_ResizeRight;
				END;
			ELSIF (y <= ResizeAreaSize) THEN
				mode := Mode_ResizeTop;
			ELSIF (y >= height - ResizeAreaSize) THEN
				mode := Mode_ResizeBottom;
			ELSE
				mode := Mode_Move;
			END;
			IF (WMWindowManager.FlagNoResizing IN flags) & (mode # Mode_Standard) THEN
				mode := Mode_Move;
			END;
			RETURN mode;
		END GetMode;

		PROCEDURE UpdatePointerInfo(mode : LONGINT);
		VAR info : WMWindowManager.PointerInfo;
		BEGIN
			CASE mode OF
				| Mode_ResizeLeft: info := manager.pointerLeftRight;
				| Mode_ResizeRight: info := manager.pointerLeftRight;
				| Mode_ResizeTop: info := manager.pointerUpDown;
				| Mode_ResizeBottom: info := manager.pointerUpDown;
				| Mode_ResizeTopLeft: info := manager.pointerULDR;
				| Mode_ResizeTopRight: info := manager.pointerURDL;
				| Mode_ResizeBottomLeft: info := manager.pointerURDL;
				| Mode_ResizeBottomRight: info := manager.pointerULDR;
				| Mode_Move: info := manager.pointerMove;
			ELSE
				info := manager.pointerStandard;
			END;
			SetPointerInfo(info);
		END UpdatePointerInfo;

		PROCEDURE MoveOrResize() : BOOLEAN;
		VAR state : SET;
		BEGIN
			viewport.GetKeyState(state);
			RETURN (Inputs.LeftCtrl IN state);
		END MoveOrResize;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		BEGIN
			PointerDown^(x, y, keys);
			lastX := bounds.l + x; lastY:=bounds.t + y;
			IF (0 IN keys) & MoveOrResize() & (mode = Mode_Standard) THEN
				mode := GetMode(x, y);
				UpdatePointerInfo(mode);
			END;
		END PointerDown;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
		VAR dx, dy, width, height, newWidth, newHeight, moveX, moveY, tempMode : LONGINT;
		BEGIN
			PointerMove^(x, y, keys);
			IF MoveOrResize() & (mode = Mode_Standard) THEN
				tempMode := GetMode(x, y);
				IF (tempMode # mode) THEN UpdatePointerInfo(tempMode); END;
			END;

			IF (mode # Mode_Standard) THEN
				width := GetWidth(); height := GetHeight();
				newWidth := width; newHeight := height;
				x := bounds.l + x; y := bounds.t + y;
				dx := x - lastX; dy := y - lastY;
				lastX := lastX + dx; lastY := lastY + dy;
				moveX := 0; moveY := 0;
				IF (mode = Mode_Move) THEN
					moveX := dx; moveY := dy;
				ELSE
					CASE mode OF
						| Mode_ResizeLeft: newWidth := width - dx; moveX := dx;
						| Mode_ResizeRight: newWidth := width + dx;
						| Mode_ResizeTop: newHeight := height - dy; moveY := dy;
						| Mode_ResizeBottom: newHeight := height + dy;
						| Mode_ResizeTopLeft:
							newWidth := width - dx; moveX := dx;
							newHeight := height - dy; moveY := dy;
						| Mode_ResizeTopRight:
							newWidth := width + dx;
							newHeight := height - dy; moveY := dy;
						| Mode_ResizeBottomLeft:
							newWidth := width - dx; moveX := dx;
							newHeight := height + dy;
						| Mode_ResizeBottomRight:
							newWidth := width + dx;
							newHeight := height + dy;
					ELSE
						newWidth := width; newHeight := height;
					END;
				END;
				IF (newWidth < MinimumWidth) THEN
					IF (moveX # 0) THEN moveX := moveX - (newWidth - MinimumWidth); END;
					newWidth := MinimumWidth;
				END;
				IF (newHeight < MinimumHeight) THEN
					IF (moveY # 0) THEN moveY := moveY - (newHeight - MinimumHeight); END;
					newHeight := MinimumHeight;
				END;
				IF (newWidth # width) OR (newHeight # height) THEN
					manager.SetWindowSize(SELF, newWidth, newHeight); resized := TRUE;
				END;
				IF (moveX # 0) OR (moveY # 0) THEN
					manager.SetWindowPos(SELF, bounds.l + moveX, bounds.t + moveY);
				END;
			END;
		END PointerMove;

		PROCEDURE Handle*(VAR m : WMMessages.Message);
		BEGIN
			IF MoveOrResize() & (m.msgType = WMMessages.MsgPointer) THEN
				IF m.msgSubType = WMMessages.MsgSubPointerMove THEN PointerMove(m.x, m.y, m.flags)
				ELSIF m.msgSubType = WMMessages.MsgSubPointerDown THEN PointerDown(m.x, m.y, m.flags)
				ELSIF m.msgSubType = WMMessages.MsgSubPointerUp THEN PointerUp(m.x, m.y, m.flags)
				ELSIF m.msgSubType = WMMessages.MsgSubPointerLeave THEN PointerLeave
				END
			ELSE
				Handle^(m);
			END;
		END Handle;

		PROCEDURE PointerUp(x, y:LONGINT; keys:SET);
		BEGIN
			PointerUp^(x, y, keys);
			IF (mode # Mode_Standard) & ~(0 IN keys) THEN
				mode := Mode_Standard;
				UpdatePointerInfo(mode);
				IF resized THEN
					Resized(GetWidth(), GetHeight());
				END;
			END;
		END PointerUp;

		PROCEDURE PointerLeave;
		BEGIN
			PointerLeave^;
		END PointerLeave;

	END GadgetWindow;

VAR
	nofWindows : LONGINT;

PROCEDURE Open*(context : Commands.Context);
VAR
	fullName, repositoryName, applicationName : ARRAY 128 OF CHAR;
	refNum, res : LONGINT;
	info : ApplicationInfo;
	window : Window;
	gadgetWindow : GadgetWindow;
BEGIN
	fullName := "";
	context.arg.SkipWhitespace; context.arg.String(fullName);
	IF Repositories.SplitName(fullName, repositoryName, applicationName, refNum) THEN
		res := GetApplicationInfo(repositoryName, applicationName, info);
		IF (res = Ok) THEN
			IF ~info.window.alternativeMoveResize THEN
				NEW(window, info, NIL);
			ELSE
				NEW(gadgetWindow, info, NIL);
			END;
		ELSIF (res = RepositoryNotFound) THEN
			context.error.String("Repository "); context.error.String(repositoryName);
			context.error.String(" not found."); context.error.Ln;
		ELSIF (res = ApplicationNotFound) THEN
			context.error.String("Application "); context.error.String(applicationName);
			context.error.String(" not found in repository "); context.error.String(repositoryName);
			context.error.Ln;
		ELSIF (res = ParseError) THEN
			context.error.String("Application parse error."); context.error.Ln;
		ELSE
			context.error.String("res = "); context.error.Int(res, 0); context.error.Ln;
		END;
	ELSE
		context.error.String(fullName); context.error.String(" not valid."); context.error.Ln;
	END;
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
VAR
	repositoryName, applicationName : Repositories.Name; string : Strings.String;
	window : Window;
	info : ApplicationInfo;
	writer : Streams.Writer;
	res : LONGINT;
BEGIN
	ASSERT((context # NIL) & (context.appData # NIL));
	string := context.appData.GetAttributeValue("repository");
	IF (string # NIL) THEN
		COPY(string^, repositoryName);
		string := context.appData.GetAttributeValue("name");
		IF (string # NIL) THEN
			COPY(string^, applicationName);
			res := GetApplicationInfo(repositoryName, applicationName, info);
			IF (res = Ok) THEN
				NEW(window, info, context);
			ELSE
				NEW(writer, KernelLog.Send, 128);
				ShowRes(res, repositoryName, applicationName, writer);
			END;
		ELSE
			KernelLog.String("WMApplications.Restore failed"); KernelLog.Ln;
		END;
	ELSE
		KernelLog.String("WMApplications.Restore failed"); KernelLog.Ln;
	END;
END Restore;

PROCEDURE ShowRes(res : LONGINT; CONST repositoryName, applicationName : ARRAY OF CHAR; out : Streams.Writer);
BEGIN
	ASSERT(out # NIL);
	CASE res OF
		| Ok:
			out.String("Ok");
		| RepositoryNotFound:
			out.String("Repository "); out.String(repositoryName); out.String(" not found."); out.Ln;
		| ApplicationNotFound:
			out.String("Application "); out.String(applicationName);
			out.String(" not found in repository "); out.String(repositoryName); out.Ln;
		| ParseError:
			out.String("Application parse error."); out.Ln;
	ELSE
		out.String("res = "); out.Int(res, 0); out.Ln;
	END;
	out.Update;
END ShowRes;

PROCEDURE GetApplicationInfo(CONST repositoryName, applicationName : ARRAY OF CHAR; VAR info : ApplicationInfo) : LONGINT;
VAR repository : Repositories.Repository; application : XML.Element; res : LONGINT;
BEGIN
	repository := Repositories.ThisRepository(repositoryName);
	IF (repository # NIL) THEN
		application := GetApplication(repository, applicationName);
		IF (application # NIL) THEN
			IF ParseApplication(applicationName, application, info) THEN info.repository := repository; res := Ok;
			ELSE res := ParseError;
			END;
		ELSE res := ApplicationNotFound;
		END;
	ELSE res := RepositoryNotFound;
	END;
	RETURN res;
END GetApplicationInfo;

PROCEDURE ParseApplication(CONST applicationName : ARRAY OF CHAR; CONST application : XML.Element; VAR info : ApplicationInfo) : BOOLEAN;
VAR enumerator : XMLObjects.Enumerator; ptr : ANY; string : Strings.String; component : Repositories.Component; res : LONGINT;

	PROCEDURE GetFlags(element : XML.Element) : SET;
	VAR flags : SET; value : BOOLEAN;
	BEGIN
		ASSERT(element # NIL);
		flags := {};

		IF ~GetBoolean(element, "frame", value) THEN value := FlagFrame; END;
		IF value THEN INCL(flags, WMWindowManager.FlagFrame); END;

		IF ~GetBoolean(element, "closeBtn", value) THEN value := FlagClose; END;
		IF value THEN INCL(flags, WMWindowManager.FlagClose); END;

		IF ~GetBoolean(element, "minimizeBtn", value) THEN value := FlagMinimize; END;
		IF value THEN INCL(flags, WMWindowManager.FlagMinimize); END;

		IF ~GetBoolean(element, "stayOnTop", value) THEN value := FlagStayOnTop; END;
		IF value THEN INCL(flags, WMWindowManager.FlagStayOnTop); END;

		IF ~GetBoolean(element, "nofocus", value) THEN value := FlagNoFocus; END;
		IF value THEN INCL(flags, WMWindowManager.FlagNoFocus); END;

		IF ~GetBoolean(element, "stayOnBottom", value) THEN value := FlagStayOnBottom; END;
		IF value THEN INCL(flags, WMWindowManager.FlagStayOnBottom); END;

		IF ~GetBoolean(element, "navigation", value) THEN value := FlagNavigation; END;
		IF value THEN INCL(flags, WMWindowManager.FlagNavigation); END;

		IF ~GetBoolean(element, "hidden", value) THEN value := FlagHidden; END;
		IF value THEN INCL(flags, WMWindowManager.FlagHidden); END;

		IF ~GetBoolean(element, "noResizing", value) THEN value := FlagNoResizing; END;
		IF value THEN INCL(flags, WMWindowManager.FlagNoResizing); END;

		RETURN flags;
	END GetFlags;

BEGIN
	ASSERT(application # NIL);
	COPY(applicationName, info.name);
	enumerator := application.GetContents();
	WHILE enumerator.HasMoreElements() DO
		ptr := enumerator.GetNext();
		IF (ptr # NIL) THEN
			IF (ptr IS XML.Element) THEN
				string := ptr(XML.Element).GetName();
				IF (string # NIL) & (string^ = "Window") THEN
					info.window.title := ptr(XML.Element).GetAttributeValue("title");
					info.window.icon := ptr(XML.Element).GetAttributeValue("icon");
					IF ~GetInteger(ptr(XML.Element), "width", info.window.width) THEN info.window.width := DefaultWidth; END;
					IF ~GetInteger(ptr(XML.Element), "height", info.window.height) THEN info.window.height := DefaultHeight; END;
					IF ~GetBoolean(ptr(XML.Element), "alpha", info.window.alpha) THEN info.window.alpha := DefaultAlpha; END;
					info.window.flags := GetFlags(ptr(XML.Element));
					IF ~GetBoolean(ptr(XML.Element), "alternativeMoveResize", info.window.alternativeMoveResize) THEN
						info.window.alternativeMoveResize := FALSE;
					END;
				ELSE
					KernelLog.String("He2_??"); KernelLog.Ln;
				END;
			ELSIF (ptr IS XML.Chars) THEN
				string := ptr(XML.Chars).GetStr();
				IF (string # NIL) THEN
					Repositories.GetComponentByString(string^, component, res);
					IF (res = Repositories.Ok) THEN
						IF (component IS WMComponents.VisualComponent) THEN
							info.content := component(WMComponents.VisualComponent);
						ELSE
							KernelLog.String("Component is not a visual components."); KernelLog.Ln;
						END;
					ELSE
						KernelLog.String("Component not found"); KernelLog.Ln;
					END;
				END;
			ELSE
				KernelLog.String("HEEE??"); KernelLog.Ln;
			END;
		END;
	END;
	RETURN info.content # NIL;
END ParseApplication;

PROCEDURE GetApplication(repository : Repositories.Repository; CONST applicationName : ARRAY OF CHAR) : XML.Element;
VAR result : XML.Element; enumerator : XMLObjects.Enumerator; ptr : ANY; string : Strings.String;
BEGIN
	ASSERT(repository # NIL);
	result := NIL;
	enumerator := repository.GetApplicationEnumerator();
	IF (enumerator # NIL) THEN
		WHILE (result = NIL) & enumerator.HasMoreElements() DO
			ptr := enumerator.GetNext();
			IF (ptr # NIL) & (ptr IS XML.Element) THEN
				string := ptr(XML.Element).GetName();
				IF (string # NIL) & (string^ = "Application") THEN
					string := ptr(XML.Element).GetAttributeValue("name");
					IF (string # NIL) & (string^ = applicationName) THEN
						result := ptr(XML.Element);
					END;
				END;
			END;
		END;
	END;
	RETURN result;
END GetApplication;

PROCEDURE GetInteger(element : XML.Element; CONST attributeName : ARRAY OF CHAR; VAR value : LONGINT) : BOOLEAN;
VAR string : Strings.String;
BEGIN
	ASSERT(element # NIL);
	string := element.GetAttributeValue(attributeName);
	IF (string # NIL) THEN
		Strings.StrToInt(string^, value);
	END;
	RETURN (string # NIL);
END GetInteger;

PROCEDURE GetBoolean(element : XML.Element; CONST attributeName : ARRAY OF CHAR; VAR value : BOOLEAN) : BOOLEAN;
VAR string : Strings.String;
BEGIN
	ASSERT(element # NIL);
	string := element.GetAttributeValue(attributeName);
	IF (string # NIL) THEN
		Strings.StrToBool(string^, value);
	END;
	RETURN (string # NIL);
END GetBoolean;

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
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	nofWindows := 0;
	Modules.InstallTermHandler(Cleanup);
END WMApplications.

WMApplications.Open RepositoryName::ApplicationName ~

WMApplications.Open test:test:0 ~

WMApplications.Open System:ObjectTracker ~

SystemTools.Free WMApplications ~
