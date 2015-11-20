(** AUTHOR "Michael Szediwy"; PURPOSE "Debug Log";
	- Shares the interface with KernelLog
	-

Todo:
	- Mulit-Line support via Enter & Exit
*)
MODULE DebugLog;

IMPORT SYSTEM, Objects, Machine, Streams, Modules, Random, TextUtilities,
	Dates, Strings, WMComponents, WMEditors, WMGraphics, WMStandardComponents,
	WM := WMWindowManager;

CONST
	Title = "Debug Log";
	InitListSize = 8;

TYPE
	LogWindow = OBJECT(WMComponents.FormWindow)
	VAR
		tw- : TextUtilities.TextWriter;
		panel : WMStandardComponents.Panel;
		out- : WMEditors.Editor;
		open : BOOLEAN;

		PROCEDURE &New*(CONST title : ARRAY OF CHAR);
		VAR  toolbar : WMStandardComponents.Panel;
			clear : WMStandardComponents.Button;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(640, 420); panel.fillColor.Set(WMGraphics.RGBAToColor(255, 255, 255, 255));

			NEW(toolbar);
			toolbar.bounds.SetHeight(20);
			toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);

			NEW(clear);
			clear.alignment.Set(WMComponents.AlignLeft);
			clear.SetCaption("Clear");
			clear.onClick.Add(ClearText);
			toolbar.AddContent(clear);

			NEW(out); out.alignment.Set(WMComponents.AlignClient); out.tv.showBorder.Set(TRUE); panel.AddContent(out);
			Init(panel.bounds.GetWidth(), panel.bounds.GetHeight(), FALSE);
			SetContent(panel);
			manager := WM.GetDefaultManager();
			SetTitle(WMComponents.NewString(title));


			WM.DefaultAddWindow(SELF);
			NEW(tw, out.text);
			open := TRUE
		END New;

		PROCEDURE Close;
		BEGIN
			open := FALSE;
			Close^
		END Close;

		PROCEDURE  ClearText(sender, data : ANY);
		BEGIN
			out.text.AcquireWrite();
			out.text.Delete(0, out.text.GetLength());
			out.tv.firstLine.Set(0); out.tv.cursor.SetPosition(0);
			out.text.ReleaseWrite()
		END ClearText;

	END LogWindow;

	TraceSubscriber = OBJECT
	VAR
		processID : LONGINT;
		color : WMGraphics.Color; (* Color property *)
		date : BOOLEAN; (* Default setting whether the date is printed or not *)

		PROCEDURE &New*(processID : LONGINT; color : WMGraphics.Color; date : BOOLEAN);
		BEGIN
			SELF.processID := processID;
			SELF.color := color;
			SELF.date := date
		END New;

	END TraceSubscriber;

	SubscriberList = POINTER TO ARRAY OF TraceSubscriber;

VAR
	logwindow : LogWindow;
	nrSubscriptions : LONGINT;
	subscriptions : SubscriberList;
	gen : Random.Sequence;
	defaultColor : WMGraphics.Color;
	me : Modules.Module;
	date : BOOLEAN;

PROCEDURE AlreadySubscribed(processID : LONGINT; VAR sub : TraceSubscriber) : BOOLEAN;
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO nrSubscriptions - 1 DO
		IF subscriptions[i].processID = processID THEN
			IF sub # NIL THEN sub := subscriptions[i] END;
			RETURN  TRUE
		END
	END;
	sub := NIL;
	RETURN FALSE
END AlreadySubscribed;

(* From now on tracing is with or without the date string *)
PROCEDURE SetDate*(new : BOOLEAN);
BEGIN {EXCLUSIVE}
	date := new
END SetDate;

(* Get the current date property. *)
PROCEDURE GetDate*() : BOOLEAN;
BEGIN {EXCLUSIVE}
	RETURN date
END GetDate;

PROCEDURE GetNextColor() : WMGraphics.Color;
VAR r, g, b : LONGINT;
BEGIN
	IF gen = NIL THEN
		NEW(gen);
		gen.InitSeed(1291)
	END;

	r := gen.Integer() MOD 100H;
	g := gen.Integer() MOD 100H;
	b := gen.Integer() MOD 100H;

	RETURN WMGraphics.RGBAToColor(r,g,b,0FFH)
END GetNextColor;

PROCEDURE Grow;
VAR tmp : SubscriberList; i : LONGINT;
BEGIN
	NEW(tmp, 2 * LEN(subscriptions));
	FOR i := 0 TO LEN(subscriptions) - 1 DO
		tmp[i] := subscriptions[i]
	END;
	subscriptions := tmp;
END Grow;

PROCEDURE Subscribe(processID : LONGINT);
VAR sub : TraceSubscriber; color :  WMGraphics.Color;
BEGIN
	color := GetNextColor(); (* Get a random color *)
	NEW(sub, processID, color, date);
	IF LEN(subscriptions) = nrSubscriptions THEN Grow END;
	subscriptions[nrSubscriptions] := sub;
	INC(nrSubscriptions)
END Subscribe;

PROCEDURE GetColor(processID : LONGINT) : WMGraphics.Color;
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO LEN(subscriptions) - 1 DO
		IF subscriptions[i].processID = processID THEN
			RETURN subscriptions[i].color
		END
	END;
	RETURN defaultColor
END GetColor;

PROCEDURE GetSubscription(processID : LONGINT) : TraceSubscriber;
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO nrSubscriptions - 1 DO
		IF subscriptions[i].processID = processID THEN
			RETURN subscriptions[i]
		END
	END;
	RETURN NIL
END GetSubscription;

PROCEDURE TraceIdString;
VAR
	bp, pc, nextbp : ADDRESS;
	methadr, i : LONGINT;
	module : Modules.Module;
	process : Objects.Process;
	now, name : ARRAY 128 OF CHAR;
	ch : CHAR;
	out : Streams.Writer;
	sub : TraceSubscriber;
BEGIN
	IF logwindow = NIL THEN NEW(logwindow, Title) END;
	out := logwindow.tw;
	process := Objects.CurrentProcess();

	IF ~AlreadySubscribed(process.id, sub) THEN
		Subscribe(process.id);
	END;

	sub := GetSubscription(process.id);

	(* sub must not be NIL *)
	IF sub.date # date THEN
		date := sub.date
	END;

	(* Find the caller outside of this module *)
	bp := Machine.CurrentBP ();
	REPEAT
		SYSTEM.GET(bp + SIZEOF (ADDRESS), pc);
		module := Modules.ThisModuleByAdr(pc);
		SYSTEM.GET(bp, bp);
		SYSTEM.GET(bp, nextbp)
	UNTIL (module # me) OR (nextbp = 0);

	(* IF bp = 0 the previous PC is kept. This is the PC of the last PAF. *)

	(* Compute module pc *)
	DEC(pc, ADDRESSOF(module.code[0]));
	methadr := FindProc(module.refs, pc);

	IF methadr # -1 THEN
		i := 0;
		ch := module.refs[methadr]; INC(methadr);
		WHILE ch # 0X DO
			name[i] := ch;
			ch := module.refs[methadr];
			INC(methadr);
			INC(i)
		END
	END;

	name[i] := 0X;

	logwindow.tw.SetFontColor(GetColor(process.id));

	IF date THEN
		Strings.FormatDateTime("yyyy.mm.dd hh.nn.ss ", Dates.Now(), now);
		out.String(now);
		out.String(" ")
	END;
	out.String("P"); out.Int(process.procID, 0);out.String(".");out.Int(process.id, 0);
	out.Char(" ");out.String(module.name);out.Char(".");out.String(name);out.String("[");
	out.Address(pc); out.String("]> ")
END TraceIdString;

(* Trace a string *)
PROCEDURE String*(CONST str : ARRAY OF CHAR);
VAR out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.String(str);
	out.Ln();
	out.Update()
END String;

PROCEDURE TwoStrings*(CONST str1, str2 : ARRAY OF CHAR);
VAR out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.String(str1);
	out.String(str2);
	out.Ln();
	out.Update()
END TwoStrings;

PROCEDURE Boolean*(x : BOOLEAN);
BEGIN
	IF x THEN String("TRUE") ELSE String("FALSE") END
END Boolean;

PROCEDURE TraceDebugBoolean*(CONST name : ARRAY OF CHAR; x : BOOLEAN);
BEGIN
	IF x THEN
		TraceDebugString(name, "TRUE")
	ELSE
		TraceDebugString(name, "FALSE")
	END
END TraceDebugBoolean;

(** Write a block of memory in hex. *)
PROCEDURE Memory*(adr: ADDRESS; size : SIZE);
VAR i, j : ADDRESS; ch : CHAR; out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.Ln;
	out.Char(0EX);	(* "fixed font" *)
	size := adr+size-1;
	FOR i := adr TO size BY 16 DO
		out.Address(i);
		FOR j := i TO i+15 DO
			IF j <= size THEN
				SYSTEM.GET(j, ch);
				out.Hex(ORD(ch), -3)
			ELSE
				out.String("   ")
			END
		END;
		out.String(" ");
		FOR j := i TO i+15 DO
			IF j <= size THEN
				SYSTEM.GET(j, ch);
				IF (ch < " ") OR (ch >= CHR(127)) THEN ch := "." END;
				out.Char(ch)
			END
		END;
		out.Ln
	END;
	out.Char(0FX);	(* "proportional font" *)
	out.Ln(); out.Update()
END Memory;

(** Write a buffer in hex. *)
PROCEDURE Buffer*(VAR buf : ARRAY OF CHAR; ofs, len : LONGINT);
BEGIN
	Memory(ADDRESSOF(buf[ofs]), len)
END Buffer;

(** Write "x" as a hexadecimal number.  "w" is the field width.  Always prints 16 digits. *)
PROCEDURE HIntHex*(x : HUGEINT; w : LONGINT);
VAR
	out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.Hex(SHORT (ASH(x, -32)), w-8);
	out.Hex(SHORT (x), 8);
	out.Ln(); out.Update();
END HIntHex;

(** Write "x" as a decimal number with a power-of-two multiplier (K, M or G), followed by "suffix". "w" is the field width, excluding "suffix". *)
PROCEDURE IntSuffix*(x, w : LONGINT; CONST suffix : ARRAY OF CHAR);
CONST K = 1024; M = K*K; G = K*M;
VAR mult : CHAR; out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	IF x MOD K # 0 THEN
		out.Int(x, w)
	ELSE
		IF x MOD M # 0 THEN mult := "K"; x := x DIV K
		ELSIF x MOD G # 0 THEN mult := "M"; x := x DIV M
		ELSE mult := "G"; x := x DIV G
		END;
		out.Int(x, w-1); out.Char(mult)
	END;
	out.String(suffix);
	out.Ln(); out.Update()
END IntSuffix;

PROCEDURE Enter*;
END Enter;

PROCEDURE Exit*;
END Exit;

PROCEDURE GetWriter*() : Streams.Writer;
VAR x : Streams.Writer;
BEGIN
	NEW(x, Send, 128);
	RETURN x
END GetWriter;

(* UNSAFE *)
(** Send the specified characters to the trace output (cf. Streams.Sender). *)
PROCEDURE Send*(CONST buf : ARRAY OF CHAR; ofs, len : LONGINT; propagate : BOOLEAN; VAR res : LONGINT);
VAR i : LONGINT; str : POINTER TO ARRAY OF CHAR;
BEGIN
	NEW(str, len + 1);
	FOR i := 0 TO len - 1 DO
		str[i] := buf[ofs + i];
	END;
	String(str^);
	res := Streams.Ok
END Send;

(* Outputs [name] = [value] *)
PROCEDURE TraceDebugString*(CONST name, value : ARRAY OF CHAR);
VAR out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.String(name);
	out.String(" = ");
	out.String(value);
	out.Ln();
	out.Update()
END TraceDebugString;


(* Trace no message only ID *)
PROCEDURE Ln*;
VAR out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.Ln();
	out.Update()
END Ln;

PROCEDURE Int*(x, w : LONGINT);
VAR out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.Int(x,w);
	out.Ln();
	out.Update()
END Int;

(* Outputs [name] = [value] *)
PROCEDURE TraceDebugInt*(CONST name : ARRAY OF CHAR;  value, w : LONGINT);
VAR
	out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.String(name);
	out.String(" = ");
	out.Int(value, w);
	out.Ln();
	out.Update();

END TraceDebugInt;

PROCEDURE Hex*(x, w : LONGINT);
VAR
	out : Streams.Writer;
BEGIN {EXCLUSIVE}

	TraceIdString();
	out := logwindow.tw;
	out.Hex(x,w);
	out.Ln();
	out.Update()
END Hex;

(* Outputs [name] = [value] *)
PROCEDURE TraceDebugHex*(CONST name : ARRAY OF CHAR;  value, w : LONGINT);
VAR
	out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.String(name);
	out.String(" = ");
	out.Hex(value,w);
	out.Ln();
	out.Update()
END TraceDebugHex;

PROCEDURE Char*(c : CHAR);
VAR
	out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.Char(c);
	out.Ln();
	out.Update()
END Char;

(* Outputs [name] = [value] *)
PROCEDURE TraceDebugChar*(CONST name : ARRAY OF CHAR;  c : CHAR);
VAR
	out : Streams.Writer;
BEGIN {EXCLUSIVE}

	TraceIdString();
	out := logwindow.tw;
	out.String(name);
	out.String(" = ");
	out.Char(c);
	out.Ln();
	out.Update();
END TraceDebugChar;

PROCEDURE Set*(s : SET);
VAR
	out : Streams.Writer;
BEGIN {EXCLUSIVE}

	TraceIdString();
	out := logwindow.tw;
	out.Set(s);
	out.Ln();
	out.Update()
END Set;

(* Outputs [name] = [value] *)
PROCEDURE TraceDebugSet*(CONST name : ARRAY OF CHAR;  s : SET);
VAR
	out : Streams.Writer;
BEGIN {EXCLUSIVE}
	TraceIdString();
	out := logwindow.tw;
	out.String(name);
	out.String(" = ");
	out.Set(s);
	out.Ln();
	out.Update()
END TraceDebugSet;

(*
	These parameter overwrites the the parameter given in a trace procedure.
	Parameter:
		color: The print color for this process.
		date: 	TRUE, The date will be printed for this process.
				FALSE, The date won't be printed for this process.
		overwrite:	TRUE, If the process is already subscribed this parameter indicates
						that the settings are ready to override.
					FALSE, The oposite of TRUE ;-)
*)
PROCEDURE SubscribeProcess*(color : WMGraphics.Color; date, overwrite : BOOLEAN);
VAR
	sub : TraceSubscriber;
	processID : LONGINT;
	p : Objects.Process;
BEGIN {EXCLUSIVE}
	p := Objects.CurrentProcess();
	processID := p.id;

	IF (AlreadySubscribed(processID, sub)) & ~(overwrite)  THEN
		RETURN
	ELSIF AlreadySubscribed(processID, sub) THEN
		IF ~CheckColor(color) THEN
			color := sub.color;
			String("Invalid Color! Left old color.")
		END;
		sub.date := date
	ELSE
		IF ~CheckColor(color) THEN
			color := GetNextColor();
			String("Invalid Color! New color choosen.")
		END;
		NEW(sub, processID, color, date);
		IF LEN(subscriptions) = nrSubscriptions THEN
			Grow
		END;
		subscriptions[nrSubscriptions] := sub;
		INC(nrSubscriptions)
	END
END SubscribeProcess;


PROCEDURE CheckColor(color : WMGraphics.Color) : BOOLEAN;
VAR
	r, g, b, a : LONGINT;
BEGIN
	WMGraphics.ColorToRGBA(color, r, g, b, a);
	RETURN
			( r >= 0 )
		& 	( g >= 0)
		& 	( b >= 0)
		& 	( r <= 255)
		& 	( g <= 255)
		& 	( b <= 255)
		&	( a = 0FFH);
END CheckColor;

(* Find a procedure in the reference block.  Return index of name, or -1 if not found. *)
PROCEDURE FindProc(refs : Modules.Bytes; modpc : ADDRESS) : LONGINT;
VAR i, m, t, proc : LONGINT; ch : CHAR;
BEGIN
	proc := -1; i := 0; m := LEN(refs^);
	ch := refs[i]; INC(i);
	WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO	(* proc *)
		GetNum(refs, i, t);	(* pofs *)
		IF t > modpc THEN	(* previous procedure was the one *)
			ch := 0X	(* stop search *)
		ELSE	(* ~found *)
			IF ch = 0F9X THEN
				GetNum(refs, i, t);	(* nofPars *)
				INC(i, 3)	(* RetType, procLev, slFlag *)
			END;
			proc := i;	(* remember this position, just before the name *)
			REPEAT ch := refs[i]; INC(i) UNTIL ch = 0X;	(* pname *)
			IF i < m THEN
				ch := refs[i]; INC(i);	(* 1X | 3X | 0F8X | 0F9X *)
				WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO	(* var *)
					ch := refs[i]; INC(i);	(* type *)
					IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
						GetNum(refs, i, t)	(* dim/tdadr *)
					END;
					GetNum(refs, i, t);	(* vofs *)
					REPEAT ch := refs[i]; INC(i) UNTIL ch = 0X;	(* vname *)
					IF i < m THEN ch := refs[i]; INC(i) END	(* 1X | 3X | 0F8X | 0F9X *)
				END
			END
		END
	END;
	IF (proc = -1) & (i # 0) THEN proc := i END;	(* first procedure *)
	RETURN proc
END FindProc;

(* Get a compressed refblk number. *)
PROCEDURE GetNum(refs : Modules.Bytes; VAR i, num : LONGINT);
VAR n, s : LONGINT; x : CHAR;
BEGIN
	s := 0; n := 0;
	x := refs[i]; INC(i);
	WHILE ORD(x) >= 128 DO
		INC(n, ASH(ORD(x) - 128, s));
		INC(s, 7);
		x := refs[i]; INC(i)
	END;
	num := n + ASH(ORD(x) MOD 64 - ORD(x) DIV 64 * 64, s)
END GetNum;

PROCEDURE Open*;
BEGIN
	IntOpen();
END Open;

PROCEDURE IntOpen;
BEGIN {EXCLUSIVE}
	IF logwindow # NIL THEN
		IF ~logwindow.open THEN
			WM.DefaultAddWindow(logwindow);
		ELSE
			WM.DefaultBringToView(logwindow, TRUE)
		END
	ELSE
		NEW(logwindow, Title)
	END
END IntOpen;

PROCEDURE Close;
BEGIN {EXCLUSIVE}
	IF (logwindow # NIL) & (logwindow.open) THEN
		logwindow.Close();
	END;
END Close;

BEGIN
	date := FALSE;
	nrSubscriptions := 0;
	NEW(subscriptions, InitListSize);
	defaultColor := WMGraphics.RGBAToColor(0,0,0,255);
	me := Modules.ThisModuleByAdr(Machine.CurrentPC());
	Modules.InstallTermHandler(Close)
END DebugLog.

DebugLog.Open ~
SystemTools.Free DebugLog ~
