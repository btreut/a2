(** AUTHOR "Michael Szediwy"; PURPOSE "Ports the System.State to an Aos window. There is new an auto-refresh feature."; *)
MODULE WMModuleState;

IMPORT
	SYSTEM,
	Streams,
	Modules,
	TextUtilities,
	WMComponents,
	WMEditors,
	WMGraphics,
	WMStandardComponents,
	WMDialogs,
	WMWindowManager,
	Commands,
	WMRectangles,
	Kernel;

CONST
	MaxString = 64;
	MaxArray = 10;
	RefreshOff = "Refresh is off";
	RefreshOn = "Refresh is on";

TYPE Bytes = Modules.Bytes;

TYPE StateWindow= OBJECT(WMComponents.FormWindow)
	VAR
		tw-: TextUtilities.TextWriter;
		panel : WMStandardComponents.Panel;
		out- : WMEditors.Editor;
		open : BOOLEAN;
		refresh: WMStandardComponents.Button;
		refreshOn: BOOLEAN;
		timer : Kernel.Timer;
		module: Modules.Module;
		interval: LONGINT;
		autorefresh: WMStandardComponents.Checkbox;

	PROCEDURE &New*(title : ARRAY OF CHAR; interval: LONGINT; name: Modules.Name);
	VAR  toolbar: WMStandardComponents.Panel;
		load, clear : WMStandardComponents.Button;
		font: WMGraphics.Font;
		dx, dy: LONGINT;
		bearing : WMRectangles.Rectangle;
		label: WMStandardComponents.Label;
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
		font := clear.GetFont();
		font.GetStringSize(" Clear ", dx, dy);
		clear.bounds.SetWidth(dx);
		toolbar.AddContent(clear);

		NEW(load);
		load.alignment.Set(WMComponents.AlignLeft);
		load.SetCaption("Load module");
		load.onClick.Add(Load);
		font := load.GetFont();
		font.GetStringSize(" Load module ", dx, dy);
		load.bounds.SetWidth(dx);
		toolbar.AddContent(load);

		NEW(refresh);
		refresh.alignment.Set(WMComponents.AlignLeft);
		refresh.SetCaption("Refresh");
		refresh.onClick.Add(Refresh);
		font := refresh.GetFont();
		font.GetStringSize(" Refresh ", dx, dy);
		refresh.bounds.SetWidth(dx);
		refreshOn := FALSE;
		toolbar.AddContent(refresh);

		bearing := WMRectangles.MakeRect(3, 3, 3, 3);

		NEW(autorefresh);
		autorefresh.onClick.Add(RefreshSwitch);
		autorefresh.bearing.Set(bearing);
		autorefresh.bounds.SetWidth(14);
		autorefresh.alignment.Set(WMComponents.AlignRight);
		toolbar.AddContent(autorefresh);
		autorefresh.state.Set(0);

		NEW(label);
		font := label.GetFont();
		font.GetStringSize(" auto-refresh ", dx, dy);
		label.bounds.SetWidth(dx);
		label.SetCaption("auto-refresh");
		label.textColor.Set(0000000FFH);
		label.alignment.Set(WMComponents.AlignRight);
		toolbar.AddContent(label);


		NEW(out); out.alignment.Set(WMComponents.AlignClient); out.tv.showBorder.Set(TRUE); panel.AddContent(out);
		Init(panel.bounds.GetWidth(), panel.bounds.GetHeight(), FALSE);
		SetContent(panel);
		manager := WMWindowManager.GetDefaultManager();
		SetTitle(WMComponents.NewString(title));

		WMWindowManager.DefaultAddWindow(SELF);
		NEW(tw, out.text);
		open := TRUE;

		SELF.interval := interval;
		NEW(timer);

		IF name # "" THEN
			out.text.AcquireWrite();
			OutState(name);
			out.text.ReleaseWrite();
		ELSE
			Load(NIL, NIL);
		END;

	END New;

	PROCEDURE Close;
	BEGIN
		open := FALSE;
		BEGIN{EXCLUSIVE}
			refreshOn := FALSE;
		END;
		Remove(SELF);
		Close^
	END Close;

	PROCEDURE ClearText(sender, data : ANY);
	BEGIN
		out.text.AcquireWrite();
		out.text.Delete(0, out.text.GetLength());
		out.tv.firstLine.Set(0); out.tv.cursor.SetPosition(0);
		out.text.ReleaseWrite();
	END ClearText;

	PROCEDURE Load(sender, data : ANY);
	VAR
		dr: LONGINT;
		name: Modules.Name;
		temp: BOOLEAN;
	BEGIN
		temp := refreshOn;
		BEGIN {EXCLUSIVE}
			refreshOn := FALSE;
		END;
		dr := WMDialogs.QueryString("Enter module name", name);
		IF dr = WMDialogs.ResOk THEN
			out.text.AcquireWrite();
			OutState(name);
			out.text.ReleaseWrite();
		END;

		BEGIN {EXCLUSIVE}
			refreshOn := temp;
		END;

	END Load;

	(* Should be surrounded by out.text.AcquireWrite(); ... out.text.ReleaseWrite();*)
	PROCEDURE OutState(name: Modules.Name);
	VAR
		i, refpos: LONGINT;
		mod: Modules.Module;
		refs: Bytes;
		ch: CHAR;
		nameDis: Modules.Name;
	BEGIN
		out.text.Delete(0, out.text.GetLength());
		out.tv.firstLine.Set(0); out.tv.cursor.SetPosition(0);

		IF name = ""  THEN
			IF SELF.module = NIL THEN
				RETURN;
			ELSE
				nameDis := module.name;
				mod := module;

				tw.SetFontStyle({0});
				tw.String(nameDis);
				tw.SetFontStyle({});
				IF mod # NIL THEN
					SELF.module := mod;
					tw.String("  SB = ");
					tw.Hex(mod.sb, 0); tw.Char("H");  tw.Ln();
					refs := SYSTEM.VAL(Bytes, mod.refs);
					IF (refs # NIL) & (LEN(mod.refs) # 0) THEN
						refpos := FindProc(refs, 0);	(* assume module body is at PC = 0 (not true for OMI) *)
						IF refpos # -1 THEN
							REPEAT ch := refs[refpos];  INC(refpos) UNTIL ch = 0X;
							Variables(refs, refpos, mod.sb, tw)
						END
					END
				ELSE
					tw.String(" not loaded");  tw.Ln();
				END;

			tw.Update();

			END;
		ELSE
			(* New module: Have to do some work. *)
			i := 0;  WHILE (name[i] # 0X) & (name[i] # ".") DO INC(i) END; name[i] := 0X;
			mod := Modules.root;
			WHILE (mod # NIL) & (mod.name # name) DO mod := mod.next END;
			nameDis := name;

			tw.SetFontStyle({0});
			tw.String(nameDis);
			tw.SetFontStyle({});
			IF mod # NIL THEN
				SELF.module := mod;
				tw.String("  SB =");
				tw.Hex(mod.sb, 0); tw.Char("H");  tw.Ln();
				refs := SYSTEM.VAL(Bytes, mod.refs);
				IF (refs # NIL) & (LEN(mod.refs) # 0) THEN
					refpos := FindProc(refs, 0);	(* assume module body is at PC = 0 (not true for OMI) *)
					IF refpos # -1 THEN
						REPEAT ch := refs[refpos];  INC(refpos) UNTIL ch = 0X;
						Variables(refs, refpos, mod.sb, tw)
					END
				END
			ELSE
				tw.String(" not loaded");  tw.Ln();
			END;

			tw.Update();

		END;

	END OutState;


	PROCEDURE RefreshSwitch(sender, data : ANY);
	BEGIN
		BEGIN {EXCLUSIVE}	(* Else the waiting process may not be found *)
			refreshOn := ~ refreshOn;
		END;
		IF refreshOn THEN
			refresh.onClick.Remove(Refresh);
			(*refresh.caption.SetAOC(RefreshOn); *)
		ELSE
			(* refresh.caption.SetAOC(RefreshOff);*)
			refresh.onClick.Add(Refresh);
		END;
	END RefreshSwitch;

	PROCEDURE Refresh(sender, data : ANY);
	BEGIN
		out.text.AcquireWrite();
		OutState("");
		out.text.ReleaseWrite();
	END Refresh;

	PROCEDURE SetInterval*(interval: LONGINT);
	BEGIN
		SELF.interval := interval;
	END SetInterval;


	PROCEDURE Variables(refs: Bytes;  i: LONGINT; base: ADDRESS; w:Streams.Writer);
	VAR
		mode, ch: CHAR;
		m, type, n, lval, size, tmp1, tdadr: LONGINT;
		adr, tmp2: ADDRESS;
		etc: BOOLEAN;
		sval: SHORTINT;
		ival: INTEGER;
		tmp: Bytes;
		set: SET;
		rval: REAL;
		lrval: LONGREAL;
	BEGIN
		m := LEN(refs^);  mode := refs[i];  INC(i);
		WHILE (i < m) & (mode >= 1X) & (mode <= 3X) DO	(* var *)
			type := ORD(refs[i]);  INC(i);  etc := FALSE;
			IF type > 80H THEN
				IF type = 83H THEN type := 15 ELSE DEC(type, 80H) END;
				GetNum(refs, i, n)
			ELSIF (type = 16H) OR (type = 1DH) THEN
				GetNum(refs, i, tdadr); n := 1
			ELSE
				IF type = 15 THEN n := MaxString (* best guess *) ELSE n := 1 END
			END;
			GetNum(refs, i, tmp1); adr := tmp1;
			tw.SetFontColor(00BF00FFH);
			w.Char(9X);  ch := refs[i];  INC(i);
			WHILE ch # 0X DO w.Char(ch);  ch := refs[i];  INC(i) END;
			tw.SetFontColor(WMGraphics.Black);
			w.String(" = ");
			tw.SetFontColor(WMGraphics.Blue);
			INC(adr, base);
			IF n = 0 THEN	(* open array *)
				SYSTEM.GET(adr+4, n)	(* real LEN from stack *)
			END;
			IF type = 15 THEN
				IF n > MaxString THEN etc := TRUE;  n := MaxString END
			ELSE
				IF n > MaxArray THEN etc := TRUE;  n := MaxArray END
			END;
			IF mode # 1X THEN SYSTEM.GET(adr, adr) END;	(* indirect *)
			IF (adr >= -4) & (adr < 4096) THEN
				w.String("NIL reference (");  w.Hex( adr,0);  w.String("H )")
			ELSE
				IF type = 15 THEN
					w.Char(22X);
					LOOP
						IF n = 0 THEN EXIT END;
						SYSTEM.GET(adr, ch);  INC(adr);
						IF (ch < " ") OR (ch > "~") THEN EXIT END;
						w.Char(ch);  DEC(n)
					END;
					w.Char(22X);  etc := (ch # 0X)
				ELSE
					CASE type OF
						1..4: size := 1
						|5: size := 2
						|6..7,9,13,14,29: size := 4
						|8, 16: size := 8
						|22: size := 0; ASSERT(n <= 1)
					ELSE
						w.String("bad type ");  w.Int(type, 1);  n := 0
					END;
					WHILE n > 0 DO
						CASE type OF
							1,3:	(* BYTE, CHAR *)
								SYSTEM.GET(adr, ch);
								IF (ch > " ") & (ch <= "~") THEN w.Char(ch)
								ELSE w.Hex( ORD(ch), 0);  w.Char("X")
								END
							|2:	(* BOOLEAN *)
								SYSTEM.GET(adr, ch);
								IF ch = 0X THEN w.String("FALSE")
								ELSIF ch = 1X THEN w.String("TRUE")
								ELSE w.Int(ORD(ch), 1)
								END
							|4:	(* SHORTINT *)
								SYSTEM.GET(adr, sval);  w.Int( sval, 1)
							|5:	(* INTEGER *)
								SYSTEM.GET(adr, ival);  w.Int( ival, 1)
							|6:	(* LONGINT *)
								SYSTEM.GET(adr, lval);  w.Int( lval, 1)
							|7:	(* REAL *)
								SYSTEM.GET(adr, rval);  w.RawReal(rval)
							|8:	(* LONGREAL *)
								SYSTEM.GET(adr, lrval);  w.RawLReal(lrval)
							|9:	(* SET *)
								SYSTEM.GET(adr, set);  w.Set(set)
							|13, 29:	(* POINTER *)
								SYSTEM.GET(adr, lval);  w.Hex( lval, 0);  w.Char("H")
							|14:	(* PROC *)
								SYSTEM.GET(adr, lval);
								IF lval = 0 THEN w.String("NIL")
								ELSE WriteProc(Modules.ThisModuleByAdr(lval), lval, -1, tmp, tmp1, tmp2, w)
								END
							|16:	(* HUGEINT *)
								w.Hex( SYSTEM.GET32(adr+4), 0);
								w.Hex( SYSTEM.GET32(adr), 0)
							|22:	(* RECORD *)
								w.Hex( tdadr, 0);  w.Char("H")
						END;
						DEC(n);  INC(adr, size);
						IF n > 0 THEN w.String(", ") END
					END
				END
			END;
			IF etc THEN w.String(" ...") END;
			w.Ln();
			IF i < m THEN mode := refs[i];  INC(i) END
		END;
		tw.SetFontColor(WMGraphics.Black);
	END Variables;


	(* FindProc - Find a procedure in the reference block.  Return index of name, or -1 if not found. *)
	PROCEDURE FindProc(refs: Bytes;  ofs: ADDRESS): LONGINT;
	VAR i, m, t, proc: LONGINT;  ch: CHAR;
	BEGIN
		proc := -1;  i := 0;  m := LEN(refs^);
		ch := refs[i];  INC(i);
		WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO	(* proc *)
			GetNum(refs, i, t);	(* pofs *)
			IF t > ofs THEN	(* previous procedure was the one *)
				ch := 0X	(* stop search *)
			ELSE	(* ~found *)
				IF ch = 0F9X THEN
					GetNum(refs, i, t);	(* nofPars *)
					INC(i, 3)	(* RetType, procLev, slFlag *)
				END;
				proc := i;	(* remember this position, just before the name *)
				REPEAT ch := refs[i];  INC(i) UNTIL ch = 0X;	(* pname *)
				IF i < m THEN
					ch := refs[i];  INC(i);	(* 1X | 3X | 0F8X | 0F9X *)
					WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO	(* var *)
						ch := refs[i];  INC(i);	(* type *)
						IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
							GetNum(refs, i, t)	(* dim/tdadr *)
						END;
						GetNum(refs, i, t);	(* vofs *)
						REPEAT ch := refs[i];  INC(i) UNTIL ch = 0X;	(* vname *)
						IF i < m THEN ch := refs[i];  INC(i) END	(* 1X | 3X | 0F8X | 0F9X *)
					END
				END
			END
		END;
		IF (proc = -1) & (i # 0) THEN proc := i END;	(* first procedure *)
		RETURN proc
	END FindProc;

	PROCEDURE WriteProc(mod: Modules.Module;  pc, fp: ADDRESS;  VAR refs: Bytes;  VAR refpos: LONGINT; VAR base: ADDRESS; w: Streams.Writer);
	VAR ch: CHAR;
	BEGIN
		refpos := -1;
		IF mod = NIL THEN
			w.String("Unknown PC =");  w.Hex(pc,0);  w.Char("H");
			IF fp # -1 THEN
				w.String(" EBP =");  w.Hex(fp, 0);  w.Char("H")
			END
		ELSE
			w.String(mod.name);
			DEC(pc, ADDRESSOF(mod.code[0]));
			refs := SYSTEM.VAL(Bytes, mod.refs);
			IF (refs # NIL) & (LEN(mod.refs) # 0) THEN
				refpos := FindProc(refs, pc);
				IF refpos # -1 THEN
					w.Char(".");
					ch := refs[refpos];  INC(refpos);
					IF ch = "$" THEN base := mod.sb ELSE base := fp END;	(* for variables *)
					WHILE ch # 0X DO w.Char(ch);  ch := refs[refpos];  INC(refpos) END
				END
			END;
			w.String("  PC = "); w.Address(pc)
		END
	END WriteProc;




	PROCEDURE GetNum(refs: Bytes;  VAR i, num: LONGINT);
	VAR n, s: LONGINT;  x: CHAR;
	BEGIN
		s := 0;  n := 0;  x := refs[i];  INC(i);
		WHILE ORD(x) >= 128 DO
			INC(n, ASH(ORD(x) - 128, s));  INC(s, 7);  x := refs[i];  INC(i)
		END;
		num := n + ASH(ORD(x) MOD 64 - ORD(x) DIV 64 * 64, s)
	END GetNum;

BEGIN {ACTIVE}

	LOOP
		BEGIN {EXCLUSIVE}
			AWAIT(refreshOn);
		END;
		Refresh(NIL, NIL);
		timer.Sleep(interval)
	END;

END StateWindow;


TYPE WinCollection = POINTER TO ARRAY OF StateWindow;

VAR
	stateWins: WinCollection;
	nrWins: LONGINT;


PROCEDURE Remove(stateWin: StateWindow);
VAR
	i, j: LONGINT;
	wins: WinCollection;
BEGIN {EXCLUSIVE}
	i := 0;

	WHILE (i < LEN(stateWins)) & (stateWins[i] # stateWin) DO
		INC(i)
	END;

	IF stateWins[i] = stateWin THEN

		NEW(wins, LEN(stateWins) - 1);
		FOR j := 0 TO i - 1 DO
			wins[j] := stateWins[j];
		END;

		FOR j := i + 1 TO LEN(stateWins) - 1 DO
			wins[j-1] := stateWins[j];
		END;

		DEC(nrWins);

		stateWins := wins;

	ELSE
		(* Not found. *)
	END;

END Remove;


(* Usage: WMModuleState.Open modulename [ms] ~ *)
PROCEDURE Open*(context : Commands.Context);
VAR
	interval, i: LONGINT;
	name: Modules.Name;
	wins: WinCollection;
	stateWin: StateWindow;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(name);
	context.arg.SkipWhitespace; context.arg.Int(interval, FALSE);
	IF interval < 1 THEN interval := 2000 END;	(* default interval *)

	NEW(stateWin, "Module State", interval, name);
 	INC(nrWins);
 	BEGIN {EXCLUSIVE}
 		IF stateWins = NIL THEN
 			NEW(stateWins, 1);
 			stateWins[0] := stateWin;
		ELSE
	 	 	NEW(wins, LEN(stateWins) + 1);
		 	FOR i := 0 TO LEN(stateWins) - 1 DO
		 		wins[i] := stateWins[i];
		 	END;
		 	wins[LEN(stateWins)] := stateWin;

		 	stateWins := wins;
		 END;
	END;
END Open;


END WMModuleState.

SystemTools.Free WMModuleState ~
WMModuleState.Open ~
