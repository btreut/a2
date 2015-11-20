MODULE WMVT100; (* ejz,  ph *)
(* to do: nicer, dialog-free GUI*)

	IMPORT WMWindowManager, WMComponents, WMStandardComponents, WMGraphics, WMPopups, WMEditors, WMDialogs, WMMessages,
		Strings, Texts, Inputs, Streams, Commands, IP, DNS, TCP, Telnet, KernelLog, Modules;

	CONST
		Border = 2; BoxW = 8; BoxH = 18;
		Left = 0; Right = 2;
		Underscore = 0; Blink = 1;
		CursorKeyMode = 0; AppKeypadMode = 1; AutoWrapMode = 2; WindowSize = 31;
		
	TYPE 
		KillerMsg=OBJECT END KillerMsg;

	TYPE
		Connection = OBJECT (Telnet.Connection)
			VAR frame: Frame; mode: SET;

			PROCEDURE Do(option: CHAR);
			BEGIN
				IF option = Telnet.OptTerminalType THEN
					W.Char(Telnet.CmdIAC); W.Char(Telnet.CmdWILL); W.Char(Telnet.OptTerminalType)
				ELSIF option = Telnet.OptWindowSize THEN
					ASSERT((frame.cols < 255) & (frame.rows < 255));
					INCL(mode, WindowSize);
					W.Char(Telnet.CmdIAC); W.Char(Telnet.CmdSB);
					W.Char(Telnet.OptWindowSize);
					W.Char(CHR(frame.cols DIV 256));
					W.Char(CHR(frame.cols MOD 256));
					W.Char(CHR(frame.rows DIV 256));
					W.Char(CHR(frame.rows MOD 256));
					W.Char(Telnet.CmdIAC); W.Char(Telnet.CmdSE)
				ELSE
					Do^(option)
				END
			END Do;

			PROCEDURE SB(option: CHAR); 
				VAR ch: CHAR;
			BEGIN
				IF (option = Telnet.OptTerminalType) & (R.Peek() = 01X) THEN (* SEND *)
					INCL(flags, Telnet.VT100);
					R.Char(ch); (* 01X *)
					R.Char(ch); ASSERT(ch = Telnet.CmdIAC);
					R.Char(ch); ASSERT(ch = Telnet.CmdSE);
					W.Char(Telnet.CmdIAC); W.Char(Telnet.CmdSB);
					W.Char(Telnet.OptTerminalType);
					W.Char(0X); (* IS *)
					W.String("VT100");
					W.Char(Telnet.CmdIAC); W.Char(Telnet.CmdSE)
				ELSE
					SB^(option)
				END
			END SB;

			PROCEDURE ESC(ch: CHAR);
				VAR par: ARRAY 4 OF LONGINT; i, n: LONGINT; done: BOOLEAN;
			BEGIN
				IF ~(Telnet.VT100 IN flags) THEN RETURN END;
				R.Char(ch);
				IF ch = "[" THEN
					ch := R.Peek(); n := 0;
					IF ch = "?" THEN
						R.Char(ch); ch := R.Peek();
						IF (ch >= "0") & (ch <= "9") THEN
							REPEAT
								R.Int(par[n], FALSE); INC(n); R.Char(ch)
							UNTIL (n >= 4) OR (ch # " ")
						END
					ELSIF (ch >= "0") & (ch <= "9") THEN
						REPEAT
							R.Int(par[n], FALSE); INC(n); R.Char(ch)
						UNTIL (n >= 4) OR (ch # ";")
					ELSE
						ASSERT(ch < 07FX);
						R.Char(ch)
					END;
					done := FALSE;
					CASE ch OF
						"A": IF n = 1 THEN
										frame.Goto(frame.GetCol(), frame.GetRow()-par[0], TRUE);done := TRUE
									ELSE
										frame.Goto(frame.GetCol(), frame.GetRow()-1, TRUE);done := n = 0
									END;done := n = 0
						|"B": IF n = 1 THEN
										frame.Goto(frame.GetCol(), frame.GetRow()+par[0], TRUE);done := TRUE
									ELSE
										frame.Goto(frame.GetCol(), frame.GetRow()+1, TRUE);done := n = 0
									END
						|"C": IF n = 1 THEN
										frame.Goto(frame.GetCol()+par[0], frame.GetRow(), FALSE);done := TRUE
									ELSE
										frame.Goto(frame.GetCol()+1, frame.GetRow(), FALSE);done := n = 0
									END
						|"D": IF n = 1 THEN
										frame.Goto(frame.GetCol()-par[0], frame.GetRow(), FALSE);done := TRUE
									ELSE
										frame.Goto(frame.GetCol()-1, frame.GetRow(), FALSE);done := n = 0
									END
						|"H": IF n = 2 THEN
										frame.Goto(par[1]-1, par[0]-1, FALSE);done := TRUE
									ELSE
										frame.Goto(0, 0, FALSE);done := n = 0
									END
						|"J", "K":  frame.Erase(ch, par, n);done := TRUE
						|"h": IF n = 1 THEN
									IF par[0] = 1 THEN
										INCL(mode, CursorKeyMode);done := TRUE
									ELSIF par[0] = 7 THEN
										INCL(mode, AutoWrapMode);done := TRUE
									END
								END
						|"l": IF n = 1 THEN
									IF par[0] = 1 THEN
										EXCL(mode, CursorKeyMode);done := TRUE
									ELSIF par[0] = 7 THEN
										EXCL(mode, AutoWrapMode);done := TRUE
									END
								END
						|"m": frame.SetAttributes(par, n);done := TRUE
					ELSE
					END; 
					IF ~done THEN
						KernelLog.String("ESC [ ");
						i := 0;
						WHILE i < n DO
							KernelLog.Int(par[i], 0); INC(i);
							IF i < n THEN KernelLog.String(" ; ") END
						END;
						KernelLog.String(" "); KernelLog.Char(ch);
						KernelLog.String(" "); KernelLog.Ln()
					END
				ELSE
					CASE ch OF
						"=": INCL(mode, AppKeypadMode)
						|">": EXCL(mode, AppKeypadMode)
						|"D": frame.SetTop(frame.GetRow()+1)
						|"M": frame.SetTop(frame.GetRow()-1)
					ELSE KernelLog.String("ESC "); KernelLog.Hex(ORD(ch), 0); KernelLog.Ln()
					END
				END
			END ESC;

			PROCEDURE Consume(ch: CHAR);
				VAR buf: ARRAY 128 OF LONGINT; i, n: LONGINT;
			BEGIN
				CASE ch OF
					0X: (* NUL *)
					|07X: (* BEL *)
					|08X: frame.Goto(frame.GetCol()-1, frame.GetRow(), FALSE)
					|09X: frame.RightTab()
					|0AX: frame.Goto(0, frame.GetRow()+1, TRUE) (* was fused with below, but lone LFs may occur in some textual responses like HTML from some sites*)
					|0BX, 0CX: frame.Goto(frame.GetCol(), frame.GetRow()+1, TRUE)
					|0DX: IF R.Peek() = 0AX THEN
									R.Char(ch); frame.Goto(0, frame.GetRow()+1, TRUE)
								ELSE
									frame.Goto(0, frame.GetRow(), FALSE)
								END
					|01BX: ESC(ch)
					|07FX: frame.Delete()
				ELSE (* iso-8859-1 *)
					buf[0] := ORD(ch); i := 1; n := R.Available();
					IF n > 0 THEN
						IF n > 127 THEN n := 127 END; ch := R.Peek();
						WHILE (n > 0) & (ch >= 020X) & (ch <= 07EX) DO
							R.Char(ch); DEC(n);
							buf[i] := ORD(ch); INC(i);
							IF n > 0 THEN ch := R.Peek() END
						END
					END;
					frame.WriteChars(buf, i)
				END
			END Consume;

			PROCEDURE &Init*(C: Streams.Connection);
			BEGIN
				Init^(C); INCL(flags, Telnet.Telnet);
				mode := {}; frame := NIL
			END Init;

			PROCEDURE SetFrame(frame: Frame);
			BEGIN {EXCLUSIVE}
				SELF.frame := frame
			END SetFrame;

			PROCEDURE Setup;
			BEGIN {EXCLUSIVE}
				AWAIT(frame # NIL);
				IF Telnet.Telnet IN flags THEN
					W.Char(Telnet.CmdIAC); W.Char(Telnet.CmdDO); W.Char(Telnet.OptSupGoAhead);
					W.Char(Telnet.CmdIAC); W.Char(Telnet.CmdDO); W.Char(Telnet.OptEcho);
					W.Char(Telnet.CmdIAC); W.Char(Telnet.CmdWILL); W.Char(Telnet.OptTerminalType);
					W.Char(Telnet.CmdIAC); W.Char(Telnet.CmdWILL); W.Char(Telnet.OptWindowSize);
					W.Update()
				END
			END Setup;
		END Connection;

		Attribute = POINTER TO RECORD
			fnt: WMGraphics.Font;
			bg, fg: LONGINT;
			special: SET (* 0: underscore *)
		END;

		Char = RECORD
			attr: Attribute;
			char: LONGINT
		END;

		Data = POINTER TO ARRAY OF Char;

		Line = POINTER TO RECORD
			data: Data;
			t, b: LONGINT;
			next: Line
		END;

		Position = RECORD
			line: Line; ofs: LONGINT
		END;

		Frame = OBJECT (WMComponents.VisualComponent)
			VAR
				C: Connection;
				first, last, top: Line; bg: LONGINT;
				rows, cols, boxW, boxH, dX, dY: LONGINT;
				tabs: POINTER TO ARRAY OF BOOLEAN;
				attr: Attribute; cursor: Position;
				sel: RECORD beg, end: Position END;
				popup: WMPopups.Popup;
				doEcho:BOOLEAN;

			PROCEDURE GetCol(): LONGINT;
			BEGIN {EXCLUSIVE}
				RETURN cursor.ofs
			END GetCol;

			PROCEDURE GetRow(): LONGINT;
				VAR l: Line; row: LONGINT;
			BEGIN {EXCLUSIVE}
				l := top; row := 0;
				WHILE l # cursor.line DO
					l := l.next; INC(row)
				END;
				RETURN row
			END GetRow;

			PROCEDURE appendLine(): Line;
				VAR line: Line; i: LONGINT; ch: Char;
			BEGIN
				NEW(line); line.next := NIL;
				NEW(line.data, cols);
				ch.attr := attr; ch.char := 0;
				i := 0;
				WHILE i < cols DO
					line.data[i] := ch; INC(i)
				END;
				IF last # NIL THEN
					last.next := line; line.t := last.b
				ELSE
					line.t := dY
				END;
				last := line; line.b := line.t + boxH;
				RETURN line
			END appendLine;

			PROCEDURE AppendLine(): Line;
			BEGIN {EXCLUSIVE}
				RETURN appendLine()
			END AppendLine;

			PROCEDURE UpdateBox(line: Line; ofs: LONGINT);
				VAR update: WMGraphics.Rectangle;
			BEGIN
				update.l := dX + ofs*boxW; update.r := update.l + boxW;
				update.t := line.t; update.b := line.b;
				InvalidateRect(update)
			END UpdateBox;

			PROCEDURE UpdateRect(al, bl: Line; aofs, bofs: LONGINT; cur: SET);
				VAR tl: Line; tofs: LONGINT; update: WMGraphics.Rectangle; swapl, swapo: BOOLEAN;
			BEGIN
				swapl := FALSE; swapo := FALSE;
				IF al # bl THEN
					tl := al;
					WHILE (tl # NIL) & (tl # bl) DO
						tl := tl.next
					END;
					IF tl = NIL THEN swapl := TRUE; tl := al; al := bl; bl := tl END
				END;
				IF aofs > bofs THEN swapo := TRUE; tofs := aofs; aofs := bofs; bofs := tofs END;
				update.l := dX + aofs*boxW; update.r := dX + bofs*boxW + boxW;
				update.t := al.t; update.b := bl.b;
				IF cur # {} THEN
					IF 1 IN cur THEN
						IF swapl THEN cursor.line := bl ELSE cursor.line := al END
					ELSIF 2 IN cur THEN
						IF swapl THEN cursor.line := al ELSE cursor.line := bl END
					END;
					IF 3 IN cur THEN
						IF swapo THEN cursor.ofs := bofs ELSE cursor.ofs := aofs END
					ELSIF 4 IN cur THEN
						IF swapo THEN cursor.ofs := aofs ELSE cursor.ofs := bofs END
					END
				END;
				InvalidateRect(update)
			END UpdateRect;

			PROCEDURE UpdateAll;
				VAR update: WMGraphics.Rectangle;
			BEGIN
				update.l := 0; update.r := bounds.GetWidth();
				update.t := 0; update.b := bounds.GetHeight();
				InvalidateRect(update)
			END UpdateAll;


			
			PROCEDURE writeChars(VAR buf: ARRAY OF LONGINT; n: LONGINT);
				VAR l: Line; i, ofs: LONGINT; wrap: BOOLEAN;
			BEGIN 
				wrap := FALSE;
				l := cursor.line; ofs := cursor.ofs; i := 0;
				LOOP
					WHILE (i < n) & (ofs < cols) DO
						l.data[ofs].attr := attr; l.data[ofs].char := buf[i];
						INC(ofs); INC(i)
					END;
					IF (i < n) & (AutoWrapMode IN C.mode) THEN
						l := l.next; ofs := 0; wrap := TRUE;
						IF l = NIL THEN l := appendLine() END
					ELSE
						EXIT
					END
				END;
				IF wrap THEN
					cursor.ofs := ofs;
					UpdateRect(cursor.line, l, 0, cols-1, {2})
				ELSE
					UpdateRect(cursor.line, l, cursor.ofs, ofs, {4})
				END
			END writeChars;

			PROCEDURE WriteChars(VAR buf: ARRAY OF LONGINT; n: LONGINT);
			BEGIN {EXCLUSIVE}
				writeChars(buf,n);
			END WriteChars;

			PROCEDURE Delete;
				VAR l: Line; ofs: LONGINT;
			BEGIN {EXCLUSIVE}
				l := cursor.line; ofs := cursor.ofs;
				IF ofs > 0 THEN
					DEC(ofs); l.data[ofs].attr := attr; l.data[ofs].char := 0;
					UpdateRect(l, l, ofs, cursor.ofs, {3})
				END
			END Delete;

			PROCEDURE goto(col, row: LONGINT; scroll: BOOLEAN);
				VAR l: Line; y, b: LONGINT;
			BEGIN 
				(* top = row 0, < 0 => scroll up *)
				ASSERT(row >= 0);
				IF col < 0 THEN col := 0 ELSIF col >= cols THEN col := cols-1 END;
				y := dY + boxH; b := dY + rows*boxH; l := top;
				WHILE row > 0 DO
					l := l.next; DEC(row); INC(y, boxH);
					IF l = NIL THEN l := appendLine() END
				END;
				IF scroll & (y > b) & (top.next # NIL) THEN
					top := top.next; cursor.line := l; cursor.ofs := col;
					UpdateAll()
				ELSE
					UpdateRect(cursor.line, l, cursor.ofs, col, {2, 4})
				END
			END goto;


			PROCEDURE Goto(col, row: LONGINT; scroll: BOOLEAN);
			BEGIN {EXCLUSIVE}
				goto(col,row,scroll)
			END Goto;

			PROCEDURE SetTop(row: LONGINT);
			BEGIN {EXCLUSIVE}
				KernelLog.String("SetTop "); KernelLog.Int(row, 0); KernelLog.Ln();
				IF row < 0 THEN

				ELSIF row > 0 THEN

				END
			END SetTop;

			PROCEDURE RightTab;
				VAR l: Line; ofs: LONGINT; char: Char;
			BEGIN {EXCLUSIVE}
				char.attr := attr; char.char := 020H;
				l := cursor.line; ofs := cursor.ofs+1;
				WHILE (ofs < cols) & ~tabs[ofs] DO
					l.data[ofs] := char; INC(ofs)
				END;
				IF ofs = cursor.ofs THEN RETURN END;
				UpdateRect(l, l, cursor.ofs, ofs, {4})
			END RightTab;

			PROCEDURE EraseLine(l: Line; from, to: LONGINT);
				VAR i: LONGINT;
			BEGIN
				i := from;
				WHILE i <= to DO
					l.data[i].attr := attr; l.data[i].char := 0;
					INC(i)
				END
			END EraseLine;

			PROCEDURE Erase(mode: CHAR; par: ARRAY OF LONGINT; n: LONGINT);
			BEGIN {EXCLUSIVE}
				CASE mode OF
					"J": sel.beg.line := NIL; cursor.line := last; cursor.ofs := 0;
							top := last; EraseLine(top, 0, cols-1);
							UpdateAll()
					|"K": IF n = 0 THEN
								EraseLine(cursor.line, cursor.ofs, cols-1);
								UpdateRect(cursor.line, cursor.line, cursor.ofs, cols-1, {})
							ELSIF (n = 1) & (par[0] = 1) THEN
								EraseLine(cursor.line, 0, cursor.ofs);
								UpdateRect(cursor.line, cursor.line, 0, cursor.ofs, {})
							ELSIF (n = 1) & (par[0] = 2) THEN
								EraseLine(cursor.line, 0, cols-1);
								UpdateRect(cursor.line, cursor.line, 0, cols-1, {})
							END
				END
			END Erase;

			PROCEDURE NewAttr;
			BEGIN
				NEW(attr); attr.special := {};
				attr.fnt := WMGraphics.GetFont("Courier", 10, {});
				attr.bg := WMGraphics.RGBAToColor(255, 255, 255, 255);
				attr.fg := WMGraphics.RGBAToColor(0, 0, 0, 255)
			END NewAttr;
			

			PROCEDURE Bright;
				VAR style: SET;
			BEGIN
				style := attr.fnt.style;
				IF ~(WMGraphics.FontBold IN style) THEN
					INCL(style, WMGraphics.FontBold);
					attr.fnt := WMGraphics.GetFont(attr.fnt.name, attr.fnt.size, style)
				ELSE KernelLog.String("Bright"); KernelLog.Ln()
				END
			END Bright;

			PROCEDURE Dim;
				VAR style: SET;
			BEGIN
				style := attr.fnt.style;
				IF WMGraphics.FontBold IN style THEN
					EXCL(style, WMGraphics.FontBold);
					attr.fnt := WMGraphics.GetFont(attr.fnt.name, attr.fnt.size, style)
				ELSE KernelLog.String("Dim"); KernelLog.Ln()
 				END
			END Dim;

			PROCEDURE SetAttributes(attrs: ARRAY OF LONGINT; n: LONGINT);
				VAR c, i: LONGINT;
			BEGIN {EXCLUSIVE}
				NewAttr();
				i := 0;
				WHILE i < n DO
					CASE attrs[i] OF
						0: (* Reset *) NewAttr()
						|1: (* Bright *) Bright()
						|2: (* Dim *) Dim()
						|4: (* Underscore *) INCL(attr.special, Underscore)
						|5: (* Blink *) INCL(attr.special, Blink )
						|7: (* Reverse *) c := attr.bg; attr.bg := attr.fg; attr.fg := c
						|8: (* Hidden *) attr.fg := attr.bg
					ELSE
						KernelLog.String("attr "); KernelLog.Int(attrs[i], 0); KernelLog.Ln()
					END;
					INC(i)
				END
			END SetAttributes;

			PROCEDURE Draw(canvas: WMGraphics.Canvas);
				VAR l: Line; i, j, dy, bottom: LONGINT; attr: Attribute; char: Char; box: WMGraphics.Rectangle;
			BEGIN {EXCLUSIVE}
				canvas.Fill(canvas.clipRect, bg, WMGraphics.ModeCopy);
				l := first;
				WHILE l # top DO
					l.t := MIN(INTEGER); l.b := MIN(INTEGER); l := l.next
				END;
				attr := NIL; bottom := dY + rows*boxH;
				box.t := dY; box.b := dY + boxH; j := 0;
				WHILE (l # NIL) & (j < rows) & (box.b <= bottom) DO
					l.t := box.t; l.b := box.b;
					box.l := dX; box.r := dX + boxW; i := 0;
					WHILE i < cols DO
						char := l.data[i];
						IF char.attr # attr THEN
							attr := char.attr;
							canvas.SetColor(attr.fg);
							canvas.SetFont(attr.fnt);
							dy := attr.fnt.GetDescent()
						END;
						IF attr.bg # bg THEN
							canvas.Fill(box, attr.bg, WMGraphics.ModeCopy)
						END;
						IF char.char # 0 THEN
							attr.fnt.RenderChar(canvas, box.l, box.b-dy, char.char)
						END;
						IF Underscore IN attr.special THEN
							canvas.Line(box.l, box.b-dy+1, box.r-1, box.b-dy+1, attr.fg, WMGraphics.ModeCopy)
						END;
						INC(i); INC(box.l, boxW); INC(box.r, boxW)
					END;
					INC(j); l := l.next;
					INC(box.t, boxH); INC(box.b, boxH)
				END;
				WHILE l # NIL DO
					l.t := MAX(INTEGER); l.b := MAX(INTEGER); l := l.next
				END;
				IF hasFocus & (cursor.ofs >= 0) & (cursor.ofs < cols) THEN
					l := cursor.line; box.t := l.t; box.b := l.b;
					IF box.t < box.b THEN
						box.l := dX + cursor.ofs*boxW; box.r := box.l + boxW;
						canvas.Fill(box, WMGraphics.RGBAToColor(255, 0, 0, 192), WMGraphics.ModeSrcOverDst)
					ELSE
						FocusLost
					END
				END;
				IF sel.beg.line # NIL THEN
					IF sel.beg.line = sel.end.line THEN
						box.l := dX + sel.beg.ofs * boxW; box.r := dX + sel.end.ofs * boxW + boxW;
						box.t := sel.beg.line.t; box.b := sel.end.line.b;
						canvas.Fill(box, WMGraphics.RGBAToColor(0, 0, 255, 32), WMGraphics.ModeSrcOverDst)
					ELSE
						box.l := dX + sel.beg.ofs * boxW; box.r := dX + cols * boxW;
						box.t := sel.beg.line.t; box.b := sel.beg.line.b;
						canvas.Fill(box, WMGraphics.RGBAToColor(0, 0, 255, 32), WMGraphics.ModeSrcOverDst);
						l := sel.beg.line.next;
						WHILE l # sel.end.line DO
							box.l := dX; box.r := dX + cols * boxW;
							box.t := l.t; box.b := l.b;
							canvas.Fill(box, WMGraphics.RGBAToColor(0, 0, 255, 32), WMGraphics.ModeSrcOverDst);
							l := l.next
						END;
						box.l := dX; box.r := dX + sel.end.ofs * boxW + boxW;
						box.t := sel.end.line.t; box.b := sel.end.line.b;
						canvas.Fill(box, WMGraphics.RGBAToColor(0, 0, 255, 32), WMGraphics.ModeSrcOverDst)
					END
				END
			END Draw;

			PROCEDURE FocusReceived;
			BEGIN
				FocusReceived^();
				UpdateBox(cursor.line, cursor.ofs)
			END FocusReceived;

			PROCEDURE FocusLost;
			BEGIN
				FocusLost^();
				UpdateBox(cursor.line, cursor.ofs)
			END FocusLost;

			PROCEDURE LocateBox(x, y: LONGINT; VAR pos: Position);
				VAR l: Line; ofs, i: LONGINT;
			BEGIN
				IF x < dX THEN x := dX ELSIF x >= (dX + cols*boxW) THEN x := dX + cols*boxW-1 END;
				IF y < dY THEN y := dY ELSIF y >= (dY + rows*boxH) THEN y := dY + rows*boxH-1 END;
				pos.line := NIL; pos.ofs := -1;
				l := top;
				WHILE (l # NIL) & ~((l.t <= y) & (l.b > y)) DO
					l := l.next
				END;
				IF l # NIL THEN
					ofs := 0; i := dX;
					WHILE (ofs < cols) & ~((i <= x) & ((i+boxW) > x)) DO
						INC(ofs); INC(i, boxW)
					END;
					IF ofs < cols THEN
						pos.line := l; pos.ofs := ofs
					END
				END
			END LocateBox;

			PROCEDURE Copy;
				VAR
					l: Line; apos, pos, ofs, end: LONGINT; buf: ARRAY 2 OF LONGINT;
					attr: Attribute; tattr: Texts.Attributes;
			BEGIN {EXCLUSIVE}
				IF sel.beg.line = NIL THEN RETURN END;
				Texts.clipboard.AcquireRead();
				end := Texts.clipboard.GetLength();
				Texts.clipboard.ReleaseRead();
				Texts.clipboard.AcquireWrite();
				Texts.clipboard.Delete(0, end);
				pos := 0; buf[1] := 0; l := sel.beg.line;
				attr := NIL; tattr := NIL; apos := -1;
				LOOP
					IF l = sel.beg.line THEN
						ofs := sel.beg.ofs
					ELSE
						ofs := 0
					END;
					IF l = sel.end.line THEN
						end := sel.end.ofs+1
					ELSE
						end := cols
					END;
					WHILE ofs < end DO
						IF l.data[ofs].char # 0 THEN
							buf[0] := l.data[ofs].char;
							IF attr # l.data[ofs].attr THEN
								IF tattr # NIL THEN
									Texts.clipboard.SetAttributes(apos, pos-apos, tattr)
								END;
								apos := pos; attr := l.data[ofs].attr;
								NEW(tattr); NEW(tattr.fontInfo);
								tattr.color := attr.fg; tattr.bgcolor := attr.bg;
								COPY(attr.fnt.name, tattr.fontInfo.name);
								tattr.fontInfo.size := attr.fnt.size; tattr.fontInfo.style := attr.fnt.style
							END;
							Texts.clipboard.InsertUCS32(pos, buf); INC(pos)
						END;
						INC(ofs)
					END;
					IF l = sel.end.line THEN
						EXIT
					ELSE
						l := l.next;
						buf[0] := 0AH;
						Texts.clipboard.InsertUCS32(pos, buf); INC(pos)
					END
				END;
				IF tattr # NIL THEN
					Texts.clipboard.SetAttributes(apos, pos-apos, tattr)
				END;
				Texts.clipboard.ReleaseWrite()
			END Copy;

			PROCEDURE Paste;
				VAR R: Texts.TextReader; ch: LONGINT;
			BEGIN {EXCLUSIVE}
				Texts.clipboard.AcquireRead();
				NEW(R, Texts.clipboard);
				R.SetPosition(0);
				R.SetDirection(1);
				R.ReadCh(ch);
				WHILE ~R.eot DO
					IF (ch DIV 256) = 0 THEN C.W.Char(CHR(ch)) END;
					R.ReadCh(ch)
				END;
				Texts.clipboard.ReleaseRead();
				C.W.Update()
			END Paste;

			PROCEDURE ClickHandler(sender, par: ANY);
				VAR b: WMStandardComponents.Button; str: Strings.String;
			BEGIN
				popup.Close();
				b := sender(WMStandardComponents.Button);
				str := b.caption.Get();
				IF str^ = "Copy" THEN
					Copy()
				ELSIF str^ = "Paste" THEN
					Paste()
				END
			END ClickHandler;

			PROCEDURE PointerDown(x, y: LONGINT; keys: SET);
			BEGIN
				IF (Left IN keys) & hasFocus THEN
					LocateBox(x, y, sel.beg); sel.end := sel.beg
				ELSIF Right IN keys THEN
					ToWMCoordinates(x, y, x, y);
					popup.Popup(x, y)
				ELSE
					sel.beg.line := NIL; sel.beg.ofs := -1;
					sel.end := sel.beg
				END;
				UpdateAll()
			END PointerDown;

			PROCEDURE PointerMove(x, y: LONGINT; keys: SET);
				VAR pos: Position;
			BEGIN
				IF (Left IN keys) & (sel.beg.line # NIL) THEN
					LocateBox(x, y, pos);
					IF pos.line # NIL THEN
						IF pos.line.t > sel.beg.line.t THEN
							sel.end := pos
						ELSIF (pos.line = sel.beg.line) & (pos.ofs >= sel.beg.ofs) THEN
							sel.end := pos
						END;
						UpdateAll()
					END
				END
			END PointerMove;

			PROCEDURE WheelMove(dz: LONGINT);
				VAR l: Line;
			BEGIN
				IF (dz > 0) & (top.next # NIL) THEN
					top := top.next; UpdateAll()
				ELSIF (dz < 0) & (top # first) THEN
					l := first;
					WHILE l.next # top DO
						l := l.next
					END;
					top := l; UpdateAll()
				END
			END WheelMove;

			PROCEDURE PointerUp(x, y: LONGINT; keys: SET);
			END PointerUp;

			PROCEDURE CursorKey(keySym: LONGINT);
			BEGIN
				C.W.Char(01BX);
				IF CursorKeyMode IN C.mode THEN
					C.W.Char("O")
				ELSE
					C.W.Char("[")
				END;
				CASE keySym OF
					0FF51H: C.W.Char("D")
					|0FF52H: C.W.Char("A")
					|0FF53H: C.W.Char("C")
					|0FF54H: C.W.Char("B")
				END;
				C.W.Update()
			END CursorKey;

			PROCEDURE KeyEvent(ucs: LONGINT; flags: SET; VAR keySym: LONGINT);
			VAR echo: ARRAY 1 OF LONGINT; col:LONGINT;
			BEGIN
				IF ~(Inputs.Release IN flags) & hasFocus THEN
					IF (keySym DIV 256) = 0 THEN
						C.W.Char(CHR(keySym)); C.W.Update();
						
						IF doEcho THEN
							col:=attr.fg;
							attr.fg:=WMGraphics.Red;
							echo[0]:=keySym;
							writeChars(echo,1);
							attr.fg:=col;
						END;
						
					ELSIF (keySym DIV 256) = 0FFH THEN
						CASE keySym OF
							0FF51H .. 0FF54H: CursorKey(keySym)
							|0FF50H: (* Home *)
							|0FF57H: (* End *)
							|0FFFFH: (* Delete *)
							|0FF08H: C.W.Char(07FX); C.W.Update()
							|0FF0DH: 
								C.W.Char(0DX); C.W.Char(0AX);	C.W.Update(); (* insertion of 0AX after 0DX is not strictly raw TCP ! *)
								IF doEcho THEN goto(GetCol(), GetRow()+1, TRUE); goto(0, GetRow(), TRUE) END; (* if you do it in one step, the color is not currently handled well*)
							|0FF1BH: C.W.Char(01BX); C.W.Update()
							|0FF8DH: 
								IF AppKeypadMode IN C.mode THEN 
										C.W.Char(01BX); C.W.Char("O"); C.W.Char("M")
								ELSE	C.W.Char(0DX); C.W.Char(0AX)
								END;
								C.W.Update()
						ELSE
						END
					END
				END
			END KeyEvent;

			PROCEDURE resized;
				VAR l: Line; W, H, b, t, c, r, i: LONGINT; d: Data; ch: Char;
			BEGIN {EXCLUSIVE}
				W := bounds.GetWidth() - 2*Border;
				H := bounds.GetHeight() - 2*Border;
				c := W DIV BoxW; r := H DIV BoxH;
				boxW := W DIV c; boxH := H DIV r;
				dX := Border + (W - c*boxW) DIV 2;
				dY := Border + (H - r*boxH) DIV 2;
				l := top; t := dY; b := dY + boxH;
				WHILE l # NIL DO
					l.t := t; l.b := b; l := l.next;
					INC(t, boxH); INC(b, boxH)
				END;
				IF c # cols THEN
					ch.attr := attr; ch.char := 0;
					l := first;
					WHILE l # NIL DO
						NEW(d, c);
						i := 0;
						WHILE (i < c) & (i < cols) DO
							d[i] := l.data[i]; INC(i)
						END;
						WHILE i < c DO
							d[i] := ch; INC(i)
						END;
						l.data := d; l := l.next
					END
				END;
				IF (c # cols) OR (r # rows) THEN
					IF cursor.ofs >= c THEN cursor.ofs := c-1 END;
					l := cursor.line;
					IF l.b > (dY + r*boxH) THEN
						i := (l.b - (dY + r*boxH)) DIV boxH;
						l := top.next;
						WHILE (l # NIL) & (i > 0) DO
							top := l; l := l.next; DEC(i)
						END
					END;
					sel.beg.line := NIL; cols := c; rows := r;
					IF WindowSize IN C.mode THEN
						C.Do(Telnet.OptWindowSize)
					ELSE
						C.W.Char(Telnet.CmdIAC); C.W.Char(Telnet.CmdWILL); C.W.Char(Telnet.OptWindowSize)
					END
				END
			END resized;

			PROCEDURE Resized;
			BEGIN
				Resized^();
				resized()
			END Resized;

			PROCEDURE Initialize;
			BEGIN
				Initialize^();
				takesFocus.Set(TRUE);
			END Initialize;

			PROCEDURE &New*(C: Connection; cols, rows: LONGINT);
				VAR i: LONGINT;
			BEGIN
				Init(); 
				SetNameAsString(Strings.NewString("VT100Frame"));
				(*SetGenerator("WMVT100.GenFrame");*)
				SELF.C := C;
				SELF.rows := rows; SELF.cols := cols;
				NewAttr(); bg := WMGraphics.RGBAToColor(255, 255, 255, 255);
				last := NIL; first := AppendLine(); top := first;
				cursor.line := top; cursor.ofs := 0;
				boxW := 0; boxH := 0; dX := 0; dY := 0;
				NEW(tabs, cols+1);
				tabs[0] := FALSE; i := 1;
				WHILE i <= cols DO
					tabs[i] := (i MOD 8) = 0; INC(i)
				END;
				C.SetFrame(SELF);
				NEW(popup);
				popup.Add("Copy", ClickHandler);
				popup.Add("Paste", ClickHandler);
				doEcho:=TRUE;
			END New;
			
			
		END Frame;

		Window = OBJECT (WMComponents.FormWindow)
			VAR
				panel: WMStandardComponents.Panel;
				frame: Frame;
				


			PROCEDURE &New*(C: Connection);
				VAR
			BEGIN
				NEW(panel);
				panel.bounds.SetWidth(2*Border + 80*BoxW); panel.bounds.SetHeight(2*Border + 24*BoxH);
				NEW(frame, C, 80, 24); panel.AddContent(frame);
				frame.alignment.Set(WMComponents.AlignClient);
				Init(panel.bounds.GetWidth(), panel.bounds.GetHeight(), FALSE);
				SetContent(panel);
				manager := WMWindowManager.GetDefaultManager();
				manager.Add(100, 100, SELF, {WMWindowManager.FlagFrame, WMWindowManager.FlagClose})
			END New;
			
			PROCEDURE Handle(VAR x: WMMessages.Message);
			BEGIN
				IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
				ELSE Handle^(x)
				END;
			END Handle;

			PROCEDURE Close;
			BEGIN
				frame.C.Close();
				Close^();
				DecCount;
			END Close;
		END Window;
		
		
	VAR nofWindows:LONGINT;
	


	PROCEDURE Open*(CONST name: ARRAY OF CHAR; port:LONGINT; type:LONGINT; error:Streams.Writer):Window;
	VAR
		inst: Window;
		title: Strings.String; adr: IP.Adr; res: LONGINT;
		C: TCP.Connection; TC: Connection; 
	BEGIN
		IF port = 0 THEN port := 23 END;
		DNS.HostByName(name, adr, res);
		IF res # DNS.Ok THEN
			error.String(name); error.String(" invalid address");
			error.Ln(); RETURN NIL;
		END;
		NEW(C); C.Open(TCP.NilPort, adr, port, res);
		IF res # TCP.Ok THEN
			error.String(name); error.String(" open failed");
			error.Ln(); RETURN NIL;
		END;
		NEW(TC, C); 
			IF type=Telnet.Tcp THEN TC.flags:={Telnet.Echo}; title:=WMWindowManager.NewString("TCP Terminal");
			ELSIF type=Telnet.Telnet THEN TC.flags:={Telnet.Telnet}; title:=WMWindowManager.NewString("Telnet Terminal");
			ELSIF type=Telnet.VT100 THEN TC.flags:={Telnet.Telnet};  (*! add VT100?*) title:=WMWindowManager.NewString("VT100 Terminal");
			ELSE HALT(200) 
			END;
		NEW(inst, TC); inst.SetTitle(title);
		IncCount();
		RETURN inst
	END Open;

	PROCEDURE GetRemote(context : Commands.Context; VAR name: ARRAY OF CHAR; VAR port:LONGINT);
	VAR
		 sr: Streams.StringReader;
	BEGIN
		IF (context=NIL) OR  ~context.arg.GetString(name) OR ~ context.arg.GetInteger(port,FALSE) THEN
			IF WMDialogs.QueryString("Remote address and port", name) = WMDialogs.ResOk THEN 
				NEW(sr,256); sr.Set(name); 
				IF ~sr.GetString(name) OR ~ sr.GetInteger(port,FALSE) THEN 
					WMDialogs.Information("Connecting failed", "insufficient info on address, port"); RETURN
				END;
			ELSE
				WMDialogs.Information("Connect failed", "insufficient info on address, port"); RETURN
			END;
		END;	
	END GetRemote;

	PROCEDURE Start*(context : Commands.Context);
	VAR
		name,protocol: ARRAY 256 OF CHAR; port: LONGINT; 
		window:Window;
	BEGIN
		IF (context=NIL) OR ~context.arg.GetString(protocol) OR ((protocol#"Tcp")&(protocol#"Telnet")&(protocol#"VT100")) THEN
			IF ~(WMDialogs.QueryString("Please give protocol {Tcp,Telnet,VT100}", protocol) = WMDialogs.ResOk) THEN RETURN END;
		END;
		GetRemote(context, name, port);
		IF protocol="Tcp" THEN window:=Open(name, port, Telnet.Tcp, context.error);
		ELSIF protocol="Telnet" THEN window:=Open(name, port, Telnet.Telnet, context.error);
		ELSIF protocol="VT100" THEN window:=Open(name, port, Telnet.VT100, context.error);
		END;
	END Start;

	PROCEDURE IncCount;
	BEGIN {EXCLUSIVE}
		INC(nofWindows);
	END IncCount;

	PROCEDURE DecCount;
	BEGIN {EXCLUSIVE}
		DEC(nofWindows);
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
END WMVT100.

WMVT100.Open~

WMVT100.Start Tcp "127.0.0.1" 25~ (* TCP terminal, e.g. to test a SMTP server *)
WMVT100.Start Tcp "127.0.0.1" 80~ (* manual access to HTTP server *)
WMVT100.Start Telnet <server> <portNr>~ (* will include Telnet control characters *)
WMVT100.Start VT100 <server> <portNr>~ (* will include Telnet/VT100 control characters *)

SystemTools.Free WMVT100 ~	

from wikipedia: Telnet
All data octets except 0xff are transmitted over Telnet as is. 
Therefore, a Telnet client application may also be used to establish an interactive raw TCP session, 
and it is commonly believed that such session which does not use the IAC (0xff, or 255 in decimal) is functionally identical.
This is not the case, however, because there are other network virtual terminal (NVT) rules, 
such as the requirement for a bare carriage return character (CR, ASCII 13) to be followed by a NUL (ASCII 0) character or a LF character, 
that distinguish the telnet protocol from raw TCP sessions.
Another difference of Telnet from a raw TCP session is that Telnet is not 8-bit clean by default. 
8-bit mode may be negotiated, but high-bit-set octets may be garbled until this mode was requested, and it obviously will not be requested in non-Telnet connection. 
The standard suggests the interpretation of codes 0000-0176 as ASCII, but does not offer any meaning for high-bit-set data octets.