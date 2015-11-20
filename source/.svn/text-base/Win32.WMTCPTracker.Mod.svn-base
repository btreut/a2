MODULE WMTCPTracker;	(** AUTHOR "pjm"; PURPOSE "Watch TCP connections"; *)
(* 21.11.2002 - tf : rewritten to use grid component...  *)
(* 11.01.2004 - tf : rewritten to use string grid, added discard button *)

IMPORT
	Modules, Commands, WMStandardComponents,
	IP, TCP, Kernel, WMRestorable, WMMessages,
	WMWindowManager, WMGraphics,
	WMComponents, Messages := WMMessages, Strings, WMGrids, WMStringGrids;

CONST
	Running = 0; Closing = 1; Closed = 2;	(* states *)

TYPE
	Closer = OBJECT
		VAR c: TCP.Connection;

		PROCEDURE &Init*(c: TCP.Connection);
		BEGIN
			SELF.c := c
		END Init;

	BEGIN {ACTIVE}
		c.Close
	END Closer;

	Discarder = OBJECT
		VAR c: TCP.Connection;

		PROCEDURE &Init*(c: TCP.Connection);
		BEGIN
			SELF.c := c
		END Init;

	BEGIN {ACTIVE}
		c.Discard
	END Discarder;

	ConnectionArray = POINTER TO ARRAY OF TCP.Connection;

	Window = OBJECT (WMComponents.FormWindow)
	VAR grid : WMStringGrids.StringGrid;
		delay : LONGINT;
		timer : Kernel.Timer;
		state : LONGINT;

		currentIndex, nofConnections : LONGINT;
		currentList : ConnectionArray;
		colWidth : WMGrids.Spacings;

		selectedConnection : TCP.Connection;
		detailPanel : WMStandardComponents.Panel;
		closeBtn, discardBtn : WMStandardComponents.Button;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			toolbar: WMStandardComponents.Panel;
			cBtn, dBtn : WMStandardComponents.Button;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(800, 400);
			panel.takesFocus.Set(TRUE);

			NEW(toolbar); toolbar.fillColor.Set(000FF00FFH); toolbar.bounds.SetHeight(20);
			toolbar.alignment.Set(WMComponents.AlignBottom);
			panel.AddContent(toolbar);
			detailPanel := toolbar;

			NEW(cBtn); cBtn.caption.SetAOC("Close selected connection (think 2x !)");
			cBtn.bounds.SetWidth(panel.bounds.GetWidth() DIV 2);
			cBtn.alignment.Set(WMComponents.AlignLeft);
			toolbar.AddContent(cBtn);
			cBtn.clDefault.Set(LONGINT(0FF0000FFH));
			SELF.closeBtn := cBtn;

			NEW(dBtn); dBtn.caption.SetAOC("Discard selected connection (think 2x !)");
			dBtn.bounds.SetWidth(panel.bounds.GetWidth() DIV 2);
			dBtn.alignment.Set(WMComponents.AlignLeft);
			toolbar.AddContent(dBtn);
			dBtn.clDefault.Set(LONGINT(0FF0000FFH));
			SELF.discardBtn := dBtn;

			NEW(grid); grid.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(grid);

			RETURN panel
		END CreateForm;

		PROCEDURE &New*(delay : LONGINT;  c : WMRestorable.Context);
		VAR str : ARRAY 256 OF CHAR;
			i, dx, dy, minWidth : LONGINT;
			 vc : WMComponents.VisualComponent;
			f  : WMGraphics.Font;
		BEGIN
			SELF.delay := delay;
			NEW(timer);
			NEW(currentList, 16 *  1024);
			vc := CreateForm();

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);

			f := WMGraphics.GetFont("Oberon", 12, {});
			grid.fixedCols.Set(4); grid.fixedRows.Set(1);
			grid.SetSelectionMode(WMGrids.GridSelectSingleRow);
			grid.Acquire;
			grid.model.Acquire;
			grid.model.SetNofCols(33);
			grid.model.SetNofRows(1);
			NEW(colWidth, 33);
			f.GetStringSize("-999999999", minWidth, dy);
			FOR i := 0 TO 33 - 1 DO
				GetTitleStr(i, str);
				f.GetStringSize(str, dx, dy);
				colWidth[i] := Strings.Max(dx + 4, minWidth);
				grid.model.SetCellText(i, 0, Strings.NewString(str));
				grid.model.SetTextAlign(i, 0, WMGraphics.AlignCenter);
			END;
			f.GetStringSize("999.999.999.999:99999", dx, dy); colWidth[0] := dx + 4;
			f.GetStringSize("SynReceived", dx, dy); colWidth[2] := dx + 4;
			f.GetStringSize("999.999.999.999", dx, dy); colWidth[3] := dx + 4;
			grid.SetColSpacings(colWidth);
			grid.model.Release;
			grid.Release;
			grid.onClick.Add(Click);

			detailPanel.visible.Set(FALSE);
			closeBtn.onClick.Add(CloseConnection);
			discardBtn.onClick.Add(DiscardConnection);

			IF c # NIL THEN WMRestorable.AddByContext(SELF, c)
			ELSE WMWindowManager.DefaultAddWindow(SELF)
			END;

			SetTitle(Strings.NewString("TCP Tracker"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMTCPTracker.png", TRUE));
			ScanConnections;
			grid.SetTopPosition(3, 1, TRUE);
			state := Running
		END New;

		PROCEDURE GetTitleStr(col: LONGINT; VAR x : ARRAY OF CHAR);
		BEGIN
			CASE col OF
				|0 : COPY("Remote", x)
				|1 : COPY("Local Port", x)
				|2 : COPY("State", x)
				|3 : COPY("Local IP", x)
				|4 : COPY("Idle", x)
				|5 : COPY("RecvAdv", x)
				|6 : COPY("SendNext", x)
				|7 : COPY("SendBuf", x)
				|8 : COPY("SendFree", x)
				|9 : COPY("SendWnd", x)
				|10 : COPY("SendCWnd", x)
				|11 : COPY("RecvFree", x)
				|12 : COPY("RecvWnd", x)
				|13 : COPY("RecvHW", x)
				|14 : COPY("SendUnack", x)
				|15 : COPY("SendMax", x)
				|16 : COPY("RTSN", x)
				|17 : COPY("WUSAN", x)
				|18 : COPY("RecvNext", x)
				|19 : COPY("WUSSN", x)
				|20 : COPY("LASN", x)
				|21 : COPY("SRTT", x)
				|22 : COPY("DupAcks", x)
				|23 : COPY("ReXmitT", x)
				|24 : COPY("Backoff", x)
				|25 : COPY("RTT", x)
				|26 : COPY("RTTVar", x)
				|27 : COPY("RTTMin", x)
				|28 : COPY("MaxSeg", x)
				|29 : COPY("ISS", x)
				|30 : COPY("IRS", x)
				|31 : COPY("SSThresh", x)
				|32 : COPY("Track", x)
			ELSE COPY("", x);
			END
		END GetTitleStr;

		PROCEDURE Click(sender, data : ANY);
		BEGIN
			IF (data # NIL) & (data IS TCP.Connection) (* & (data(TCP.Connection).state # TCP.Listen)*) THEN
				selectedConnection := data(TCP.Connection);
				detailPanel.visible.Set(TRUE)
			ELSE detailPanel.visible.Set(FALSE)
			END
		END Click;

		PROCEDURE CloseConnection(sender, data : ANY);
		VAR tc : TCP.Connection;
			killer : Closer;
		BEGIN
			tc := selectedConnection;
			IF tc # NIL THEN
				NEW(killer, tc);
				selectedConnection := NIL;
				detailPanel.visible.Set(FALSE)
			END
		END CloseConnection;

		PROCEDURE DiscardConnection(sender, data : ANY);
		VAR tc : TCP.Connection;
			killer : Discarder;
		BEGIN
			tc := selectedConnection;
			IF tc # NIL THEN
				NEW(killer, tc);
				selectedConnection := NIL;
				detailPanel.visible.Set(FALSE)
			END
		END DiscardConnection;

		PROCEDURE GetAlign(col : LONGINT) : LONGINT;
		BEGIN
			CASE col OF
				0..3 : RETURN WMGraphics.AlignCenter;
			ELSE RETURN WMGraphics.AlignRight
			END
		END GetAlign;

		PROCEDURE StateToString(state : LONGINT; VAR str : ARRAY OF CHAR);
		BEGIN
			CASE state OF
				TCP.Closed: COPY("Closed", str)
				|TCP.Listen: COPY("Listen", str)
				|TCP.SynSent: COPY("SynSent", str)
				|TCP.SynReceived: COPY("SynReceived", str)
				|TCP.Established: COPY("Established", str)
				|TCP.CloseWait: COPY("CloseWait", str)
				|TCP.FinWait1: COPY("FinWait1", str)
				|TCP.Closing: COPY("Closing", str)
				|TCP.LastAck: COPY("LastAck", str)
				|TCP.FinWait2: COPY("FinWait2", str)
				|TCP.TimeWait: COPY("TimeWait", str)
				ELSE COPY("Unknown", str)
			END
		END StateToString;

		PROCEDURE GetConnectionStr(x, col: LONGINT; VAR str : ARRAY OF CHAR); (*ALEX 2005.12.12 commented out inexistent properties*)
		VAR c : TCP.Connection;
				t : ConnectionArray;
				s : ARRAY 64 OF CHAR;
		BEGIN
			t := currentList; (* to prevent problems with not yet implemented shrinking *)
			COPY("", str);
			IF x < LEN(t) THEN
				c := t[x];
				IF c # NIL THEN
					CASE col OF
						|0 : IP.AdrToStr(c.fip, str); Strings.Append(str, ":"); Strings.IntToStr(c.fport, s); Strings.Append(str, s)
						|1 :  Strings.IntToStr(c.lport, str)
						|2 : StateToString(c.state, str)
						|3 : IF c.int # NIL THEN IP.AdrToStr(c.int.localAdr, str); ELSE COPY("n/a", str); END;
						|4: (*Strings.IntToStr(c.idle, str)*)
						|5 : (*Strings.IntToStr(c.rcvadv - c.irs, str)*)
						|6 : Strings.IntToStr(c.sndnxt - c.iss, str)
						|7: Strings.IntToStr(c.sndcc, str)
						|8 : (*Strings.IntToStr(c.sndspace, str)*)
						|9 : Strings.IntToStr(c.sndwnd, str)
						|10 : Strings.IntToStr(c.sndcwnd, str)
						|11 : (*Strings.IntToStr(c.rcvspace, str)*)
						|12 : Strings.IntToStr(c.rcvwnd, str)
						|13 : (*Strings.IntToStr(c.rcvhiwat, str)*)
						|14: (*Strings.IntToStr(c.snduna - c.iss, str)*)
						|15 : (*Strings.IntToStr(c.sndmax - c.iss, str)*)
						|16 : (*Strings.IntToStr(c.rtseq - c.iss, str)*)
						|17 : (*Strings.IntToStr(c.sndwl2 - c.iss, str)*)
						|18 : Strings.IntToStr(c.rcvnxt - c.irs, str)
						|19 : (*Strings.IntToStr(c.sndwl1 - c.irs, str)*)
						|20 : (*Strings.IntToStr(c.lastacksent - c.irs, str)*)
						|21 : Strings.IntToStr(c.srtt, str)
						|22 : (*Strings.IntToStr(c.dupacks, str)*)
						|23 : (*Strings.IntToStr(c.rxtcur, str)*)
						|24 : (*Strings.IntToStr(c.rxtshift, str)*)
						|25 : (*Strings.IntToStr(c.rtt, str)*)
						|26 : (*Strings.IntToStr(c.rttvar, str)*)
						|27 : (*Strings.IntToStr(c.rttmin, str)*)
						|28 : (*Strings.IntToStr(c.maxseg, str)*)
						|29 : Strings.IntToStr(c.iss, str)
						|30 : Strings.IntToStr(c.irs, str)
						|31 : (*Strings.IntToStr(c.sndssthresh, str) *)
						|32 : (*Strings.IntToStr(c.traceflow, str) *)
					ELSE
					END
				END;
			END
		END GetConnectionStr;

		PROCEDURE AddConnection(obj: ANY;  VAR cont: BOOLEAN); (*ALEX 2005.12.12 modified signature*)
		(*PROCEDURE AddConnection(c : TCP.Connection);*)
		VAR t : ConnectionArray; i : LONGINT;
		BEGIN
			IF currentIndex >= LEN(currentList) THEN (* grow the list *)
				NEW(t, LEN(currentList) * 2); FOR i := 0 TO currentIndex - 1 DO t[i] := currentList[i] END;
				currentList := t
			END;
			currentList[currentIndex] := obj(TCP.Connection);
			INC(currentIndex)
		END AddConnection;

		PROCEDURE ScanConnections;
		BEGIN {EXCLUSIVE}
			currentIndex := 0;
			TCP.pool.Enumerate(AddConnection);
			nofConnections := currentIndex
		END ScanConnections;

		PROCEDURE Update;
		VAR i, j : LONGINT; s : Strings.String;
		BEGIN
			ScanConnections;
			grid.model.Acquire;
			grid.model.SetNofRows(nofConnections + 1);
			FOR i := 0 TO nofConnections - 1 DO
				FOR j := 0 TO 33 - 1 DO
					s := grid.model.GetCellText(j, i + 1); (* recycle the string *)
					IF s = NIL THEN NEW(s, 64) END;
					GetConnectionStr(i, j, s^);
					grid.model.SetTextAlign(j, i + 1, GetAlign(j));
					grid.model.SetCellData(j, i + 1, currentList[i]);
					grid.model.SetCellText(j, i + 1, s)
				END
			END;
			grid.model.Release;
		END Update;

		PROCEDURE Join;
		BEGIN {EXCLUSIVE}
			AWAIT(state = Closed)
		END Join;

		PROCEDURE Close;	(* override *)
		BEGIN
			BEGIN {EXCLUSIVE}
				IF state = Running THEN state := Closing END;	(* multiple calls possible *)
				timer.Wakeup
			END;
			FreeWindow;
			Close^
		END Close;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) THEN
				IF (x.ext IS WMRestorable.Storage) THEN
					x.ext(WMRestorable.Storage).Add("WMTCPTracker", "WMTCPTracker.Restore", SELF, NIL)
				ELSE Handle^(x)
				END
			ELSE Handle^(x)
			END
		END Handle;

	BEGIN {ACTIVE}
		WHILE state = Running DO
			Update; grid.Invalidate(); timer.Sleep(delay)
		END;
		BEGIN {EXCLUSIVE} state := Closed END
	END Window;

VAR window : Window;

PROCEDURE FreeWindow;
BEGIN {EXCLUSIVE}
	window := NIL
END FreeWindow;

PROCEDURE Open*(context : Commands.Context);	(** [ms] *)
VAR delay: LONGINT;
BEGIN
	IF TCP.pool # NIL THEN
		IF ~context.arg.GetInteger(delay, FALSE) OR (delay < 1) THEN delay := 250 END;	(* default delay *)
		BEGIN {EXCLUSIVE}
			IF window = NIL THEN NEW(window, delay, NIL)
			ELSE WMWindowManager.DefaultBringToView(window, TRUE)
			END
		END
	ELSE context.error.String("TCP.pool = NIL"); context.error.Ln;
	END;
END Open;

PROCEDURE Restore*(context : WMRestorable.Context);
BEGIN{EXCLUSIVE}
	ASSERT(context # NIL);
	IF window = NIL THEN
		NEW(window, 250, context);
	ELSE
		WMWindowManager.DefaultBringToView(window, TRUE);
	END;
END Restore;


PROCEDURE Close*;
VAR w: Window;
BEGIN
	BEGIN {EXCLUSIVE} w := window END;	(* avoid race between Join call and FreeWindow *)
	IF w # NIL THEN w.Close; w.Join END;
END Close;

PROCEDURE Cleanup;
BEGIN
	Close;
END Cleanup;

BEGIN
	window := NIL;
	Modules.InstallTermHandler(Cleanup)
END WMTCPTracker.

SystemTools.Free WMTCPTracker WMStringGrids

WMTCPTracker.Open 250
TestServer.Open
TestServer.Close
WMTCPTracker.Close ~
