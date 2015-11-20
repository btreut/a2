MODULE WMPerfMonAlerts; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor Alert plugin"; *)
(**
 * History:
 *
 *	15.05.2007	Bugfix: Return NIL if document could not be loaded/parsed in procedure LoadXmlDocument (staubesv)
 *	06.08.2007	Added FirstValueChangedBy and LastValueChangedBy triggers (staubesv)
 *)

IMPORT
	KernelLog, Modules, Commands, Streams, Files, Events, Strings,
	XML, XMLObjects, XMLScanner, XMLParser,
	WMPerfMonPlugins;

CONST

	Ok* = 0;
	Error* = 1;

	DefaultAlertFile = "WMPerfMonAlerts.XML";

	(** Types *)
	Sticky* = 0;			(* Execute the onAlertCommand one time *)
	SingleShot* = 1;		(* Execute the onAlertCommand one time. When the alert is over, execute the onLeaveAlertCommand on time *)
	MultiShot* = 2;		(* Execute the command each time the alert is triggered *)

	(** Triggers *)
	Invalid* = -1;
	Undefined* = 0;
	Greater* = 1;
	GreaterOrEqual* = 2;
	Equals* = 3;
	NotEquals* = 4;
	Less* = 5;
	LessOrEqual* = 6;
	OutOfInterval* = 7;
	InInterval* = 8;
	FirstValueChangedBy* = 9;
	LastValueChangedBy* = 10;


	(* Alert states *)
	Off* = 0;		(** Alert is ignored/not detected *)
	On* = 1;		(**	Alert is on *)
	Triggered* = 2;	(** Alert has been triggered *)
	Reset* = 3; 		(** Reset alert stats. Set alert state to AlertOn *)

	XmlElementAlert = "Alert";
	XmlAttributeFullname = "fullname";

	XmlAttributeType = "type";

	XmlAttributeValue1 = "value1";
	XmlAttributeValue2 = "value2";

	XmlAttributeOnAlertCommand = "onAlert";
	XmlAttributeOnLeaveAlertCommand = "onLeave";

	XmlAttributeTrigger = "trigger";
	XmlGreater = ">";
	XmlGreaterOrEqual = ">=";
	XmlEquals = "=";
	XmlNotEquals = "!=";
	XmlLess = "<";
	XmlLessOrEqual = "<=";
	XmlOutOfInterval = "out";
	XmlInInterval = "in";
	XmlFirstValueChangedBy = "changedBy0";
	XmlLastValueChangedBy = "changedBy";

	ShowOnKernelLog = FALSE;
	GenerateEvents = TRUE;
	EventOriginator = "WMPerfMonAlerts";

TYPE

	AlertInfo* = RECORD
		id- : LONGINT;
		fullname- : ARRAY 256 OF CHAR;
		type- : LONGINT;

		state- : LONGINT;

		(* alert trigger *)
		trigger- : LONGINT;
		value1-, value2- : LONGREAL;
		violation- :LONGREAL; (* value that triggered trigger *)
		nbrOfViolations- : LONGINT;

		lastValueIsValid : BOOLEAN;
		lastValue : LONGREAL;

		(* command activated when trigger is triggered *)
		onAlertCommand- : XML.String;

		(* command activated when state changes from alert = TRUE to alert = FALSE *)
		onLeaveAlertCommand- : XML.String;
	END;

	AlertObject = OBJECT
	VAR
		info : AlertInfo;

		onAlertCalled, onLeaveCalled : BOOLEAN;

		(* for internal use *)
		plugin : WMPerfMonPlugins.Plugin;
		lastState : LONGINT;
		datasetIdx : LONGINT;
		next : AlertObject;

		PROCEDURE SetState(state : LONGINT);
		VAR oldState : LONGINT;
		BEGIN
			ASSERT((state = Off) OR (state = On) OR (state = Triggered) OR (state = Reset));
			oldState := info.state;
			info.state := state;
			IF state = Reset THEN
				ResetState;
			END;
		END SetState;

		PROCEDURE ResetState;
		BEGIN
			info.state := On;
			info.violation := 0;
			info.nbrOfViolations := 0;
			onAlertCalled := FALSE;
			onLeaveCalled := FALSE;
		END ResetState;

		PROCEDURE Alert(value : LONGREAL);
		BEGIN
			info.state := Triggered;
			info.violation := value;
			INC(info.nbrOfViolations);
		END Alert;

		PROCEDURE AlarmTriggered() : BOOLEAN;
		VAR value : LONGREAL; triggered : BOOLEAN;
		BEGIN
			IF info.state = Off THEN RETURN FALSE; END;
			lastState := info.state;
			value := plugin.dataset[datasetIdx];
			triggered := FALSE;
			CASE info.trigger OF
				|Undefined:
				|Greater: IF (value > info.value1) THEN triggered := TRUE; END;
				|GreaterOrEqual: IF (value >= info.value1) THEN triggered := TRUE; END;
				|Equals: IF (value = info.value1) THEN triggered := TRUE; END;
				|NotEquals: IF (value # info.value1) THEN triggered := TRUE; END;
				|Less: IF (value < info.value1) THEN triggered := TRUE; END;
				|LessOrEqual: IF (value <= info.value1) THEN triggered := TRUE; END;
				|OutOfInterval: IF (value < info.value1) OR (value > info.value2) THEN triggered := TRUE; END;
				|InInterval: IF (value >= info.value1) & (value <= info.value2) THEN triggered := TRUE; END;
				|FirstValueChangedBy, LastValueChangedBy:
					IF (info.lastValueIsValid) THEN
						IF (info.value1 = 0) & (value # info.lastValue) THEN triggered := TRUE;
						ELSIF (info.value1 < 0) & (value <= info.lastValue - info.value1) THEN triggered := TRUE;
						ELSIF (info.value1 > 0) & (value >= info.lastValue + info.value1) THEN triggered := TRUE;
						END;
					END;
			ELSE
			END;
			IF triggered THEN
				Alert(value);
			ELSIF (info.type # Sticky) THEN
				info.state := On;
			END;
			HandleAlert(lastState, triggered);
			IF (info.trigger = LastValueChangedBy) OR ((info.trigger = FirstValueChangedBy) & (info.lastValueIsValid = FALSE)) THEN
				info.lastValue := value;
				info.lastValueIsValid := TRUE;
			END;
			IF (info.type = Sticky) THEN triggered := (info.state = Triggered); END;
			RETURN triggered;
		END AlarmTriggered;

		PROCEDURE HandleAlert(lastState : LONGINT; triggered : BOOLEAN);
		VAR string : Events.Message;
		BEGIN
			IF triggered THEN
				IF (info.type = Sticky) OR (info.type = SingleShot) THEN
					IF ~onAlertCalled THEN
						IF GenerateEvents THEN
							GetFullTriggerString(info, string);
							Events.Add(GetEvent(string, 1), FALSE);
						END;
						ExecuteCommand(info.onAlertCommand);
						onAlertCalled := TRUE;
					END;
				ELSIF (info.type = MultiShot) THEN
					IF GenerateEvents THEN
						GetFullTriggerString(info, string);
						Events.Add(GetEvent(string, 1), FALSE);
					END;
					ExecuteCommand(info.onAlertCommand);
				END;
			ELSE
				IF lastState =  Triggered THEN
					IF (info.type = Sticky) OR (info.type = MultiShot) THEN (* do nothing *)
					ELSIF (info.type = SingleShot) THEN
						ExecuteCommand(info.onLeaveAlertCommand);
					END;
				END;
			END;
		END HandleAlert;

		PROCEDURE Finalize;
		BEGIN
			plugin.DecNbrOfClients;
		END Finalize;

		PROCEDURE ToXML() : XML.Element;
		VAR elem : XML.Element; string : ARRAY 16 OF CHAR;
		BEGIN
			NEW(elem); elem.SetName(	XmlElementAlert);
			elem.SetAttributeValue(XmlAttributeFullname, info.fullname);
			GetTypeString(info.type, string); elem.SetAttributeValue(XmlAttributeType, string);
			GetTriggerString(info.trigger, string); elem.SetAttributeValue(XmlAttributeTrigger, string);
			GetLongrealString(info.value1, string); elem.SetAttributeValue(XmlAttributeValue1, string);
			GetLongrealString(info.value2, string); elem.SetAttributeValue(XmlAttributeValue2, string);
			IF info.onAlertCommand # NIL THEN
				elem.SetAttributeValue(XmlAttributeOnAlertCommand, info.onAlertCommand^);
			ELSE
				elem.SetAttributeValue(XmlAttributeOnAlertCommand, "");
			END;
			IF info.onLeaveAlertCommand # NIL THEN
				elem.SetAttributeValue(XmlAttributeOnLeaveAlertCommand, info.onAlertCommand^);
			ELSE
				elem.SetAttributeValue(XmlAttributeOnLeaveAlertCommand, "");
			END;
			RETURN elem;
		END ToXML;

		PROCEDURE Show(details : BOOLEAN; out : Streams.Writer);
		VAR string : ARRAY 16 OF CHAR;
		BEGIN
			out.String("UID: "); out.Int(info.id, 0); out.String(": ");
			out.String(info.fullname);

			out.String(", type: ");
			CASE info.type OF
				|Sticky: out.String("Sticky");
				|SingleShot: out.String("Singleshot");
				|MultiShot: out.String("Multishot");
			ELSE
				out.String("Unknown");
			END;

			out.String(", trigger: ");
			CASE info.trigger OF
				|Undefined: out.String("none");
				|Greater: out.String("value > "); GetLongrealString(info.value1, string); out.String(string);
				|GreaterOrEqual: out.String("value >= "); GetLongrealString(info.value1, string); out.String(string);
				|Equals: out.String("value = "); GetLongrealString(info.value1, string); out.String(string);
				|NotEquals: out.String("value != "); GetLongrealString(info.value1, string); out.String(string);
				|Less: out.String("value < "); GetLongrealString(info.value1, string); out.String(string);
				|LessOrEqual: out.String("value <= "); GetLongrealString(info.value1, string); out.String(string);
				|OutOfInterval:
					out.String("value not in ["); GetLongrealString(info.value1, string); out.String(string); out.String(", ");
					GetLongrealString(info.value2, string); out.String(string); out.String("]");
				|InInterval:
					out.String("value in ["); GetLongrealString(info.value1, string); out.String(string);
					out.String(", "); GetLongrealString(info.value2, string); out.String(string); out.String("]");
			ELSE
				out.String("unknown");
			END;
			out.String(", violation: "); out.Int(ENTIER(info.violation), 0);
			out.String(", nbrOfViolations: "); out.Int(info.nbrOfViolations, 0);
			IF details THEN
				out.Ln;
				out.String("   onAlert: ");
				IF info.onAlertCommand = NIL THEN out.String("none"); ELSE out.String(info.onAlertCommand^); END;
				out.Ln;
				out.String("   onLeaveAlert: ");
				IF info.onLeaveAlertCommand = NIL THEN out.String("none"); ELSE out.String(info.onLeaveAlertCommand^); END;
			END;
			out.Ln;
		END Show;

		PROCEDURE &Init*(CONST fullname : ARRAY OF CHAR; plugin : WMPerfMonPlugins.Plugin; datasetIdx : LONGINT);
		BEGIN
			ASSERT(plugin # NIL);
			ASSERT((0 <= datasetIdx) & (datasetIdx < LEN(plugin.p.datasetDescriptor)));
			COPY(fullname, SELF.info.fullname);
			SELF.plugin := plugin;
			SELF.datasetIdx := datasetIdx;
			plugin.IncNbrOfClients;
			info.state := On;
		END Init;

	END AlertObject;

	Alerts* = POINTER TO ARRAY OF AlertInfo;

	Status* = RECORD
		enabled- : BOOLEAN;
		filename- : ARRAY 256 OF CHAR;
		nbrOfRules- : LONGINT;
		nbrOfAlerts- : LONGINT;
		stamp- : LONGINT; (** incremented each time a alert rule is added or removed *)
	END;

VAR
	alerts : AlertObject;
	alertsEnabled : BOOLEAN;
	alertFile : ARRAY 256 OF CHAR;
	nbrOfRules, nbrOfAlerts : LONGINT;
	stamp : LONGINT;
	uniqueID : LONGINT;

	(* XML scanner/parser *)
	xmlHasErrors : BOOLEAN;

PROCEDURE Add*(CONST fullname : ARRAY OF CHAR; type, trigger : LONGINT; value1, value2 : LONGREAL; onAlert, onLeave : XML.String; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
VAR a, alert : AlertObject; plugin : WMPerfMonPlugins.Plugin; index : LONGINT;
BEGIN {EXCLUSIVE}
	plugin := WMPerfMonPlugins.updater.GetByFullname(fullname, index, msg);
	IF plugin # NIL THEN
		NEW(alert, fullname, plugin, index);
		alert.info.id := uniqueID; INC(uniqueID);
		alert.info.type := type;
		alert.info.trigger := trigger;
		alert.info.value1 := value1;
		alert.info.value2 := value2;
		alert.info.onAlertCommand := onAlert;
		alert.info.onLeaveAlertCommand := onLeave;
		alert.info.lastValueIsValid := FALSE;
		alert.next := NIL;
		INC(nbrOfRules);
		IF alerts = NIL THEN
			alerts := alert;
		ELSE
			a := alerts; WHILE (a.next # NIL) DO a := a.next; END;
			a.next := alert;
		END;
		INC(stamp);
	ELSE
		res := Error;
	END;
END Add;

PROCEDURE AddByString*(CONST string : ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
VAR alert : AlertInfo; r : Streams.StringReader;
BEGIN
	NEW(r, LEN(string)); r.SetRaw(string, 0, LEN(string));
	ParseAlert(r, alert, msg, res);
	IF res = Ok THEN
		Add(alert.fullname, alert.type, alert.trigger, alert.value1, alert.value2, alert.onAlertCommand, alert.onLeaveAlertCommand, msg, res);
	END;
END AddByString;

PROCEDURE AddByStream(r : Streams.Reader; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
VAR alert : AlertInfo;
BEGIN
	ParseAlert(r, alert, msg, res);
	IF res = Ok THEN
		Add(alert.fullname, alert.type, alert.trigger, alert.value1, alert.value2, alert.onAlertCommand, alert.onLeaveAlertCommand, msg, res);
	END;
END AddByStream;

PROCEDURE AddByCommand*(context : Commands.Context);
VAR msg : ARRAY 128 OF CHAR; res : LONGINT;
BEGIN
	AddByStream(context.arg, msg, res);
	IF res = Ok THEN
		context.out.String("Alert added."); context.out.Ln;
	ELSE
		context.error.String("Error: "); context.error.String(msg); context.error.Ln;
	END;
END AddByCommand;

(* Remove alert from the global alert list *)
PROCEDURE RemoveAlertX(alert : AlertObject);
VAR a : AlertObject;
BEGIN
	ASSERT(alert # NIL);
	alert.Finalize;
	INC(stamp);
	DEC(nbrOfRules);
	IF (alerts = alert) THEN
		alerts := alerts.next;
	ELSE
		a := alerts;
		WHILE (a.next # NIL) & (a.next # alert) DO a := a.next; END;
		IF (a.next # NIL) THEN
			a.next := a.next.next;
		END;
	END;
END RemoveAlertX;

PROCEDURE RemoveAlerts*(CONST fullname : ARRAY OF CHAR) : LONGINT;
VAR a : AlertObject; nofRemoved : LONGINT; done : BOOLEAN;
BEGIN {EXCLUSIVE}
	nofRemoved := 0;
	done := FALSE;
	WHILE ~done DO
		a := alerts;
		WHILE (a # NIL) & (a.info.fullname # fullname) DO a := a.next; END;
		IF (a # NIL) THEN (* found *)
			RemoveAlertX(a);
			INC(nofRemoved);
		ELSE
			done := TRUE;
		END;
	END;
	RETURN nofRemoved;
END RemoveAlerts;

PROCEDURE RemoveAlertByID*(id : LONGINT) : LONGINT;
VAR a : AlertObject; nofRemoved : LONGINT; done : BOOLEAN;
BEGIN {EXCLUSIVE}
	nofRemoved := 0;
	done := FALSE;
	WHILE ~done DO
		a := alerts;
		WHILE (a # NIL) & (a.info.id # id) DO a := a.next; END;
		IF (a # NIL) THEN (* found *)
			RemoveAlertX(a);
			INC(nofRemoved);
		ELSE
			done := TRUE;
		END;
	END;
	RETURN nofRemoved;
END RemoveAlertByID;

PROCEDURE SetStateByID*(id, state : LONGINT; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
VAR alert : AlertObject;
BEGIN {EXCLUSIVE}
	ASSERT((state = Off) OR (state = On) OR (state = Triggered) OR (state = Reset));
	alert := GetByIdX(id);
	IF alert # NIL THEN
		alert.SetState(state);
		INC(stamp);
		res := Ok;
	ELSE
		msg := "Alert not found"; res := Error;
	END;
END SetStateByID;

PROCEDURE GetByIdX(id : LONGINT) : AlertObject;
VAR a : AlertObject;
BEGIN
	a := alerts;
	WHILE (a # NIL) & (a.info.id # id) DO a := a.next; END;
	RETURN a;
END GetByIdX;

PROCEDURE HandleEvents(events : SET; perf : REAL);
BEGIN
	IF WMPerfMonPlugins.EventSampleLoopDone IN events THEN
		CheckAlerts;
	END;
END HandleEvents;

PROCEDURE CheckAlerts;
VAR a : AlertObject; failed : LONGINT;
BEGIN {EXCLUSIVE}
	IF alertsEnabled THEN
		a := alerts;
		WHILE (a # NIL) DO
			IF a.AlarmTriggered() THEN
				INC(stamp);
				INC(failed);
				IF ShowOnKernelLog THEN a.Show(FALSE,NIL); END;
			END;
			a := a.next;
		END;
	END;
	nbrOfAlerts := failed;
END CheckAlerts;

PROCEDURE ExecuteCommand(command : XML.String);
VAR msg : ARRAY 128 OF CHAR; res : LONGINT;
BEGIN
	IF command # NIL THEN
		Commands.Call(command^, {}, res, msg);
		IF res # Commands.Ok THEN
			KernelLog.String("WMPerfMonAlerts: Could not execute command '");
			KernelLog.String(command^); KernelLog.String("', res: "); KernelLog.Int(res, 0);
			KernelLog.String(" ("); KernelLog.String(msg); KernelLog.String(")");
			KernelLog.Ln;
		END;
	END;
END ExecuteCommand;

PROCEDURE GetAttributeValue(elem : XML.Element; CONST name : ARRAY OF CHAR) : XML.String;
VAR attr : XML.Attribute; string : XML.String;
BEGIN
	IF elem # NIL THEN
		attr := elem.GetAttribute(name);
		IF attr # NIL THEN
			string := attr.GetValue();
		END;
	END;
	RETURN string;
END GetAttributeValue;

PROCEDURE GetLongreal(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR res : LONGINT) : LONGREAL;
VAR string : XML.String; nbr : LONGREAL;
BEGIN
	res := Error;
	string := GetAttributeValue(elem, name);
	IF (string # NIL) THEN
		Strings.StrToFloat(string^, nbr);
		res := Ok;
	END;
	RETURN nbr;
END GetLongreal;

PROCEDURE GetLongrealString(value : LONGREAL; VAR string : ARRAY OF CHAR);
BEGIN
	Strings.FloatToStr(value, 10, 10, 3, string);
END GetLongrealString;

PROCEDURE GetTriggerPtr(string : XML.String) : LONGINT;
VAR trigger : LONGINT;
BEGIN
	trigger := Invalid;
	IF string # NIL THEN
		trigger := GetTrigger(string^);
	END;
	RETURN trigger;
END GetTriggerPtr;

PROCEDURE GetTrigger(CONST string : ARRAY OF CHAR) : LONGINT;
VAR trigger : LONGINT;
BEGIN
	IF string = XmlGreater THEN trigger := Greater;
	ELSIF string = XmlGreaterOrEqual THEN trigger := GreaterOrEqual;
	ELSIF string = XmlEquals THEN trigger := Equals;
	ELSIF string = XmlNotEquals THEN trigger := NotEquals;
	ELSIF string = XmlLess THEN trigger := Less;
	ELSIF string = XmlLessOrEqual THEN trigger := LessOrEqual;
	ELSIF string = XmlOutOfInterval THEN trigger := OutOfInterval;
	ELSIF string = XmlInInterval THEN trigger := InInterval;
	ELSIF string = XmlFirstValueChangedBy THEN trigger := FirstValueChangedBy;
	ELSIF string = XmlLastValueChangedBy THEN trigger := LastValueChangedBy;
	ELSE trigger := Invalid;
	END;
	RETURN trigger;
END GetTrigger;

PROCEDURE GetTriggerString(trigger : LONGINT; VAR string: ARRAY OF CHAR);
BEGIN
	CASE trigger OF
		|Greater: string := XmlGreater;
		|GreaterOrEqual: string := XmlGreaterOrEqual;
		|Equals: string := XmlEquals;
		|NotEquals: string := XmlNotEquals;
		|Less: string := XmlLess;
		|LessOrEqual: string := XmlLessOrEqual;
		|OutOfInterval: string := XmlOutOfInterval;
		|InInterval: string := XmlInInterval;
		|FirstValueChangedBy: string := XmlFirstValueChangedBy;
		|LastValueChangedBy: string := XmlLastValueChangedBy;
	ELSE
		string := "Invalid";
	END;
END GetTriggerString;

PROCEDURE GetTypePtr(string : XML.String) : LONGINT;
VAR type : LONGINT;
BEGIN
	type := Invalid;
	IF string # NIL THEN
		type := GetType(string^);
	END;
	RETURN type;
END GetTypePtr;

PROCEDURE GetType(string : ARRAY OF CHAR) : LONGINT;
VAR type : LONGINT;
BEGIN
	Strings.UpperCase(string);
	IF string = "STICKY" THEN type := Sticky;
	ELSIF string = "SINGLESHOT" THEN type := SingleShot;
	ELSIF string = "MULTISHOT" THEN type := MultiShot;
	ELSE type := Invalid;
	END;
	RETURN type;
END GetType;

PROCEDURE GetStateString*(state : LONGINT; VAR string : ARRAY OF CHAR);
BEGIN
	CASE state OF
		|Off: string := "Off";
		|On: string := "On";
		|Triggered: string := "ALERT";
		|Reset: string := "Reset";
	ELSE
		string := "UNKNOWN";
	END;
END GetStateString;

PROCEDURE GetTypeString*(type : LONGINT; VAR string : ARRAY OF CHAR);
BEGIN
	CASE type OF
		|Sticky: string := "Sticky";
		|SingleShot: string := "Singleshot";
		|MultiShot: string := "Multishot";
	ELSE
		string := "Unknown";
	END;
END GetTypeString;

PROCEDURE GetFullTriggerString*(ai : AlertInfo; VAR string : ARRAY OF CHAR);
VAR value1, value2 : ARRAY 16 OF CHAR;
BEGIN
	Strings.FloatToStr(ai.value1, 8, 2, 0, value1);
	Strings.FloatToStr(ai.value2, 8, 2, 0, value2);
	string := "";
	CASE ai.trigger OF
		|Undefined: string := "Undefined";
		|Greater: Strings.Append(string, ai.fullname); Strings.Append(string, " > "); Strings.Append(string, value1);
		|GreaterOrEqual: Strings.Append(string, ai.fullname); Strings.Append(string, " >= "); Strings.Append(string, value1);
		|Equals: Strings.Append(string, ai.fullname); Strings.Append(string, " = "); Strings.Append(string, value1);
		|NotEquals: Strings.Append(string, ai.fullname); Strings.Append(string, " # "); Strings.Append(string, value1);
		|Less: Strings.Append(string, ai.fullname); Strings.Append(string, " < "); Strings.Append(string, value1);
		|LessOrEqual: Strings.Append(string, ai.fullname); Strings.Append(string, " <= "); Strings.Append(string, value1);
		|OutOfInterval:
			Strings.Append(string, ai.fullname);  Strings.Append(string, " not in [");
			Strings.Append(string, value1); Strings.Append(string, ", "); Strings.Append(string, value2); Strings.Append(string, "]");
		|InInterval:
			Strings.Append(string, ai.fullname);  Strings.Append(string, " in [");
			Strings.Append(string, value1); Strings.Append(string, ", "); Strings.Append(string, value2); Strings.Append(string, "]");
		|FirstValueChangedBy, LastValueChangedBy:
			IF (ai.trigger = FirstValueChangedBy) THEN Strings.Append(string, "Initial value of "); END;
			Strings.Append(string, ai.fullname); 	Strings.Append(string, " has changed by ");
			Strings.Append(string, value1);
	ELSE
		string := "Invalid";
	END;
END GetFullTriggerString;

PROCEDURE GetEvent(CONST message : Events.Message; code : SHORTINT) : Events.Event;
VAR event : Events.Event;
BEGIN
	event.originator := EventOriginator;
	event.type := Events.Alert;
	event.class := 2; (* Performance Monitor *)
	event.subclass := 1; (* Alerts *)
	event.code := code;
	event.message := message;
	RETURN event;
END GetEvent;

(* Parses string: fullname type trigger value1 value2  "onAlertCommand" "onLeaveCommand" *)
PROCEDURE ParseAlert*(r: Streams.Reader; VAR alert : AlertInfo; VAR msg : ARRAY OF CHAR; res : LONGINT);
VAR string : ARRAY 256 OF CHAR;
BEGIN
	(* parse fullname *)
	r.SkipWhitespace; r.String(string);
	IF (r.res # Streams.Ok) OR (string = "") THEN
		msg := "Could not parse full name"; res := Error;
		RETURN;
	END;
	COPY(string, alert.fullname);

	(* parse type *)
	r.SkipWhitespace; r.String(string);
	IF (r.res # Streams.Ok) OR (string = "") THEN
		msg := "Could not parse type parameter"; res := Error;
		RETURN;
	END;
	alert.type := GetType(string);
	IF alert.type = Invalid THEN
		msg := "Invalid type parameter"; res := Error;
		RETURN;
	END;

	(* parse trigger *)
	r.SkipWhitespace; r.String(string);
	IF (r.res # Streams.Ok) OR (string = "") THEN
		msg := "Could not parse trigger parameter"; res := Error;
		RETURN;
	END;
	alert.trigger := GetTrigger(string);
	IF alert.trigger = Invalid THEN
		msg := "Invalid trigger parameter"; res := Error;
		RETURN;
	END;

	(* parse value 1 *)
	r.SkipWhitespace; r.String(string);
	IF (r.res # Streams.Ok) THEN
		msg := "Could not parse value 1 parameter"; res := Error;
		RETURN;
	END;
	Strings.StrToFloat(string, alert.value1);

	(* parse value 2 *)
	r.SkipWhitespace; r.String(string);
	IF (r.res # Streams.Ok) THEN
		msg := "Could not parse value 2 parameter"; res := Error;
		RETURN;
	END;
	Strings.StrToFloat(string, alert.value2);

	(* parse onAlertCommand *)
	r.SkipWhitespace; r.String(string);
	IF (r.res # Streams.Ok) THEN
		msg := "Could not parse onAlertCommand parameter"; res := Error;
		RETURN;
	END;
	IF string	# "none" THEN
		alert.onAlertCommand := Strings.NewString(string);
	END;

	(* parse onLeaveCommand *)
	r.SkipWhitespace; r.String(string);
	IF (r.res # Streams.Ok) THEN
		msg := "Could not parse onLeaveAlertCommand parameter"; res := Error;
		RETURN;
	END;
	IF string # "none" THEN
		alert.onLeaveAlertCommand := Strings.NewString(string);
	END;
	res := Ok;
END ParseAlert;

PROCEDURE ParseXmlAlert(elem : XML.Element; VAR msg : ARRAY OF CHAR) : AlertObject;
VAR
	alert : AlertObject; string : XML.String;
	fullname : ARRAY 256 OF CHAR; type, trigger : LONGINT;  value1, value2 : LONGREAL;
	plugin : WMPerfMonPlugins.Plugin;
	index, res : LONGINT;
BEGIN
	ASSERT(elem # NIL);
	string := GetAttributeValue(elem, XmlAttributeFullname);
	IF string # NIL THEN
		COPY(string^, fullname);
		trigger := GetTriggerPtr(GetAttributeValue(elem, XmlAttributeTrigger));
		IF trigger # Invalid THEN
			type := GetTypePtr(GetAttributeValue(elem, XmlAttributeType));
			IF type # Invalid THEN
				value1 := GetLongreal(elem, XmlAttributeValue1, res);
				IF (res = Ok) & (trigger = OutOfInterval) THEN
					value2 := GetLongreal(elem, XmlAttributeValue2, res);
				END;
				IF (res = Ok) THEN
					plugin := WMPerfMonPlugins.updater.GetByFullname(fullname, index, msg);
					IF plugin # NIL THEN
						NEW(alert, fullname, plugin, index);
						alert.info.id := uniqueID; INC(uniqueID);
						alert.info.type := type;
						alert.info.trigger := trigger;
						alert.info.value1 := value1;
						alert.info.value2 := value2;
						alert.info.lastValueIsValid := FALSE;
						alert.info.onAlertCommand := GetAttributeValue(elem, XmlAttributeOnAlertCommand);
						alert.info.onLeaveAlertCommand := GetAttributeValue(elem, XmlAttributeOnLeaveAlertCommand);
					ELSE
						msg := "Plugin "; Strings.Append(msg, fullname); Strings.Append(msg, " not found");
					END;
				ELSE msg := "Could not parse value1/value2 attributes of "; Strings.Append(msg, fullname);
				END;
			ELSE msg := "Attribute "; Strings.Append(msg, XmlAttributeType); Strings.Append(msg, " not found or invalid in "); Strings.Append(msg, fullname);
			END;
		ELSE msg := "Attribute "; Strings.Append(msg, XmlAttributeTrigger); Strings.Append(msg, " not found or invalid in "); Strings.Append(msg, fullname);
		END;
	ELSE msg := "Attribute "; Strings.Append(msg, XmlAttributeFullname); Strings.Append(msg, " not found ");
	END;
	RETURN alert;
END ParseXmlAlert;

PROCEDURE ParseXmlDocument(document : XML.Document; VAR msg : ARRAY OF CHAR; VAR nbrOfRules, res : LONGINT) : AlertObject;
VAR elem : XML.Element; enum : XMLObjects.Enumerator; listHead, alert : AlertObject; ptr : ANY; string : XML.String;
BEGIN
	ASSERT(document # NIL);
	elem := document.GetRoot();
	IF elem # NIL THEN
		enum := elem.GetContents();
		WHILE enum.HasMoreElements() DO
			ptr := enum.GetNext();
			IF ptr IS XML.Element THEN
				elem := ptr (XML.Element);
				string := elem.GetName();
				IF (string # NIL) & (string^ = XmlElementAlert) THEN
					alert := ParseXmlAlert(elem, msg);
					IF alert # NIL THEN
						INC(nbrOfRules);
						IF listHead = NIL THEN listHead := alert;
						ELSE
							alert.next := listHead;
							listHead := alert;
						END;
					ELSE
						listHead := NIL;
						res := Error;
					END;
				END;
			END;
		END;
	ELSE
		msg := "No root element in document"; res := Error;
	END;
	RETURN listHead;
END ParseXmlDocument;

PROCEDURE ReportError(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
BEGIN
	xmlHasErrors := TRUE;
END ReportError;

PROCEDURE LoadXmlDocument(CONST filename : ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : LONGINT) : XML.Document;
VAR
	scanner : XMLScanner.Scanner; parser : XMLParser.Parser; document : XML.Document;
	in : Files.Reader; f : Files.File;
BEGIN
	document := NIL;
	f := Files.Old(filename);
	IF f # NIL THEN
		Files.OpenReader(in, f, 0);
		IF in # NIL THEN
			xmlHasErrors := FALSE;
			NEW(scanner, in); scanner.reportError := ReportError;
			NEW(parser, scanner); parser.reportError := ReportError;
			document := parser.Parse();
			IF (document # NIL) & ~xmlHasErrors THEN
				res := Ok;
			ELSE msg := "XML parsing failed"; res := Error;
			END;
		ELSE msg := "Could not open reader on file"; res := Error;
		END;
	ELSE msg := "File not found"; res := Error;
	END;
	xmlHasErrors := FALSE;
	RETURN document;
END LoadXmlDocument;

PROCEDURE GetStatus*() : Status;
VAR status : Status;
BEGIN {EXCLUSIVE}
	status.enabled := alertsEnabled;
	COPY(alertFile, status.filename);
	status.nbrOfRules := nbrOfRules;
	status.nbrOfAlerts := nbrOfAlerts;
	status.stamp := stamp;
	RETURN status;
END GetStatus;

PROCEDURE GetAlerts*() : Alerts;
VAR result : Alerts; a : AlertObject; i : LONGINT;
BEGIN {EXCLUSIVE}
	result := NIL;
	IF nbrOfRules > 0 THEN
		NEW(result, nbrOfRules);
		a := alerts;
		i := 0;
		WHILE (a # NIL) DO
			result[i] := a.info;
			INC(i);
			a := a.next;
		END;
	END;
	RETURN result;
END GetAlerts;

PROCEDURE SetRulesX(CONST filename : ARRAY OF CHAR; alertList : AlertObject; nbrOfRulesP : LONGINT; append : BOOLEAN);
VAR a : AlertObject;
BEGIN
	IF ~append THEN
		UnloadX;
		nbrOfRules := nbrOfRulesP;
	ELSE
		nbrOfRules := nbrOfRules + nbrOfRulesP;
	END;
	COPY(filename, alertFile);
	INC(stamp);
	IF alerts = NIL THEN
		alerts := alertList;
	ELSE
		a := alerts;
		WHILE (a.next # NIL) DO a := a.next; END;
		a.next := alertList;
	END;
END SetRulesX;

PROCEDURE GetRulesAsXmlX() : XML.Element;
VAR a : AlertObject; elem : XML.Element;
BEGIN
	IF alerts # NIL THEN
		NEW(elem); elem.SetName("Alerts");
		a := alerts;
		WHILE(a # NIL) DO
			elem.AddContent(a.ToXML());
			a := a.next;
		END;
	END;
	RETURN elem;
END GetRulesAsXmlX;

PROCEDURE LoadRuleFileX(CONST filename : ARRAY OF CHAR; VAR alerts : AlertObject; VAR nbrOfRules : LONGINT; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
VAR document : XML.Document;
BEGIN
	document := LoadXmlDocument(filename, msg, res);
	IF res = Ok THEN
		alerts := ParseXmlDocument(document, msg, nbrOfRules, res);
	END;
END LoadRuleFileX;

PROCEDURE StoreRuleFileX(CONST filename : ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
VAR file : Files.File; rules : XML.Element; w : Files.Writer;
BEGIN
	file := Files.New(filename);
	IF file # NIL THEN
		rules := GetRulesAsXmlX();
		IF rules # NIL THEN
			Files.OpenWriter(w, file, 0);
			w.String('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'); w.Ln;
			rules.Write(w, NIL, 0);
			w.Update;
			Files.Register(file);
		ELSE
			msg := "No rules available"; res := Error;
		END;
	ELSE
		msg := "File "; Strings.Append(msg, filename); Strings.Append(msg, " not found"); res := Error;
	END;
END StoreRuleFileX;

PROCEDURE LoadRules*(CONST filename : ARRAY OF CHAR; append : BOOLEAN; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
VAR alerts : AlertObject; nbrOfRules : LONGINT;
BEGIN {EXCLUSIVE}
	LoadRuleFileX(filename, alerts, nbrOfRules, msg, res);
	IF res = Ok THEN
		SetRulesX(filename, alerts, nbrOfRules, append);
	END;
END LoadRules;

PROCEDURE StoreRules*(CONST filename : ARRAY OF CHAR; VAR msg : ARRAY OF CHAR; VAR res : LONGINT);
BEGIN {EXCLUSIVE}
	StoreRuleFileX(filename, msg, res);
END StoreRules;

PROCEDURE Load*(context : Commands.Context); (** [filename] ~ *)
VAR filename, msg : ARRAY 256 OF CHAR; nbrOfRules, res : LONGINT; alerts : AlertObject;
BEGIN {EXCLUSIVE}
	IF ~context.arg.GetString(filename) THEN filename := DefaultAlertFile; END;
	LoadRuleFileX(filename, alerts, nbrOfRules, msg, res);
	IF res = Ok THEN
		SetRulesX(filename, alerts, nbrOfRules, FALSE);
		context.out.String("WMPerfMonAlerts: Loaded "); context.out.Int(nbrOfRules, 0);
		context.out.String(" rules from file "); context.out.String(filename); context.out.Ln;
	ELSE
		context.error.String("WMPerfMonAlerts: Could not load alert file ("); context.error.String(msg); context.error.String(")"); context.error.Ln;
	END;
END Load;

PROCEDURE Store*(context : Commands.Context); (** filename ~ *)
VAR filename, msg : ARRAY 256 OF CHAR; res : LONGINT;
BEGIN {EXCLUSIVE}
	context.arg.SkipWhitespace; context.arg.String(filename);
	StoreRuleFileX(filename, msg, res);
	IF res = Ok THEN
		context.out.String("WMPerfMonAlerts: Stored rules into file "); context.out.String(filename); context.out.Ln;
	ELSE
		context.error.String("WMPerfMonAlerts: Could not store alerts to file ("); context.error.String(msg); context.error.String(")"); context.error.Ln;
	END;
END Store;

PROCEDURE Show*(context : Commands.Context); (** ~ *)
VAR a : AlertObject; nbr : LONGINT;
BEGIN {EXCLUSIVE}
	context.out.String("WMPerfMonAlerts status: Alerts are ");
	IF alertsEnabled THEN context.out.String("ENABLED"); ELSE context.out.String("DISABLED"); END; context.out.Ln;
	context.out.String("Ruleset:"); context.out.Ln;
	IF alerts = NIL THEN
		context.out.String("No Rules loaded."); context.out.Ln;
	ELSE
		nbr := 0;
		a := alerts;
		WHILE (a # NIL) DO
			INC(nbr);
			context.out.Int(nbr, 2); context.out.String(": "); a.Show(TRUE, context.out);
			a := a.next;
		END;
	END;
END Show;

PROCEDURE EnableAlerts*;
BEGIN {EXCLUSIVE}
	IF GenerateEvents THEN Events.Add(GetEvent("Performance monitor alerts enabled.", 0), FALSE); END;
	alertsEnabled := TRUE;
	INC(stamp);
END EnableAlerts;

PROCEDURE DisableAlerts*;
BEGIN {EXCLUSIVE}
	alertsEnabled := FALSE;
	INC(stamp);
	IF GenerateEvents THEN Events.Add(GetEvent("Performance monitor alerts disabled.", 0), FALSE); END;
END DisableAlerts;

PROCEDURE Enable*(context : Commands.Context);
BEGIN
	EnableAlerts;
	context.out.String("WMPerfMonAlerts: Alerts ENABLED."); context.out.Ln;
END Enable;

PROCEDURE Disable*(context : Commands.Context);
BEGIN
	DisableAlerts;
	context.out.String("WMPerfMonAlerts: Alerts DISABLED."); context.out.Ln;
END Disable;

PROCEDURE UnloadX;
VAR a : AlertObject;
BEGIN
	a := alerts;
	WHILE (a # NIL) DO
		a.Finalize; a := a.next;
	END;
	nbrOfRules := 0;
	INC(stamp);
	alerts := NIL;
END UnloadX;

PROCEDURE Cleanup;
BEGIN
	alertsEnabled := FALSE;
	WMPerfMonPlugins.updater.RemoveListener(HandleEvents);
	BEGIN {EXCLUSIVE} UnloadX; END;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	alertsEnabled := TRUE; stamp := 1;
	nbrOfRules := 0; nbrOfAlerts := 0; uniqueID := 0;
	xmlHasErrors := FALSE;
	alertFile := "";
	WMPerfMonPlugins.updater.AddListener({WMPerfMonPlugins.EventSampleLoopDone}, HandleEvents);
END WMPerfMonAlerts.

WMPerfMonAlerts.Load ~	WMPerfMonAlerts.Show ~	SystemTools.Free WMPerfMonAlerts ~

WMPerfMonAlerts.Disable ~  WMPerfMonAlerts.Enabled ~