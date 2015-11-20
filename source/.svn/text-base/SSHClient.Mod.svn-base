MODULE SSHClient; 	(** AUTHOR "G.F.";  PURPOSE "Secure Shell"; *)

(* derived from WMVT100.Mod by ejz, modified to use an SSH connection instead of telnet *)


	IMPORT
		WMWindowManager, WMComponents, WMStandardComponents, WMG := WMGraphics,
		WMPopups, WMMessages, WMEditors, WMRectangles, Commands, Files,
		Strings, Texts, Inputs, Streams, Out := KernelLog, SSHAuthorize, SSH, Beep;


	CONST
		TerminalWidth = 80;
		TerminalHeight = 24;

		Border = 2; BoxW = 8; BoxH = 18;

		Left = 0; Right = 2;
		Underscore = 0; Blink = 1;
		CursorKeyMode = 0; AppKeypadMode = 1; AutoWrapMode = 2;

		ESC = 1BX; DEL = 07FX; CR = 0DX; NL = 0AX;

	VAR
		hexd: ARRAY 17 OF CHAR;

	TYPE
		WindowCloser = PROCEDURE {DELEGATE};

		Attribute = POINTER TO RECORD
			fnt: WMG.Font;
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
				rows, cols, boxW, boxH, dX, dY: LONGINT;
				chan: SSH.Channel;
				r: Streams.Reader; w: Streams.Writer;
				mode: SET;
				closeWindow: WindowCloser;

				first, top: Line; bg: LONGINT;
				scrollTop, scrollBottom: Line;
				scrollBegin, scrollEnd: LONGINT;

				tabs: POINTER TO ARRAY OF BOOLEAN;
				attr: Attribute;
				cursor: Position;
				old:	RECORD
						attr: Attribute;
						offs: LONGINT;
						row: LONGINT
					END;
				sel:	RECORD
						beg, end: Position
					END;
				popup: WMPopups.Popup;



			PROCEDURE EFill;
		(*	VAR i, j, w: INTEGER; line: Line; char: Char;	*)
			BEGIN
				(*
				i := 1; w := cols; char.ch := "E"; char.attr := none;
				WHILE i <= rows DO j := 1; line := t.line[i]; line.len := w;
					WHILE j <= w DO line.ch[j] := char; INC(j) END;
					INC(i)
				END;
				t.notify(t, update, 1, 1, t.height, t.width, t.cursor)
				*)
			END EFill;

			PROCEDURE GetCol(): LONGINT;
			BEGIN {EXCLUSIVE}
				RETURN cursor.ofs
			END GetCol;

			PROCEDURE GetRow(): LONGINT;
			VAR l: Line; row: LONGINT;
			BEGIN {EXCLUSIVE}
				l := top;  row := 0;
				WHILE l # cursor.line DO
					l := l.next; INC( row )
				END;
				RETURN row
			END GetRow;


			PROCEDURE GetNewLine(): Line;
			VAR line: Line; i: LONGINT; ch: Char;
			BEGIN
				NEW( line ); line.next := NIL;
				NEW( line.data, cols );
				ch.attr := attr; ch.char := 0;
				FOR i := 0 TO cols - 1 DO  line.data[i] := ch  END;
				RETURN line
			END GetNewLine;


			PROCEDURE AppendLine( pred: Line ): Line;
			VAR line: Line;
			BEGIN
				line := GetNewLine();
				IF pred # NIL THEN
					line.next := pred.next;
					pred.next := line;
					IF pred.b >= dY THEN  line.t := pred.b  ELSE  line.t := dY  END
				ELSE
					line.t := dY;
				END;
				line.b := line.t + boxH;
				RETURN line
			END AppendLine;



			PROCEDURE UpdateBox(line: Line; ofs: LONGINT);
			VAR update: WMG.Rectangle;
			BEGIN
				update.l := dX + ofs*boxW; update.r := update.l + boxW;
				update.t := line.t; update.b := line.b;
				InvalidateRect(update)
			END UpdateBox;

			PROCEDURE UpdateRect(al, bl: Line; aofs, bofs: LONGINT; cur: SET);
			VAR tl: Line; tofs: LONGINT; update: WMG.Rectangle; swapl, swapo: BOOLEAN;
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
			VAR update: WMG.Rectangle;
			BEGIN
				update.l := 0; update.r := bounds.GetWidth();
				update.t := 0; update.b := bounds.GetHeight();
				InvalidateRect(update)
			END UpdateAll;


			PROCEDURE WriteChars( CONST buf: ARRAY OF CHAR; n: LONGINT);
			VAR prev, l: Line; i, ofs: LONGINT; wrap: BOOLEAN;
			BEGIN {EXCLUSIVE}
				wrap := FALSE;
				l := cursor.line;  ofs := cursor.ofs;  i := 0;
				LOOP
					WHILE (i < n) & (ofs < cols) DO
						l.data[ofs].attr := attr;
						l.data[ofs].char := ORD( buf[i] );
						INC( ofs ); INC( i )
					END;
					IF (i < n) & (AutoWrapMode IN mode) THEN
						prev := l;  l := l.next;  ofs := 0;  wrap := TRUE;
						IF l = NIL THEN
							l := AppendLine( prev )
						END
					ELSE
						EXIT
					END
				END;
				IF wrap THEN
					cursor.ofs := ofs;
					UpdateRect( cursor.line, l, 0, cols-1, {2} )
				ELSE
					UpdateRect( cursor.line, l, cursor.ofs, ofs, {4} )
				END
			END WriteChars;



			PROCEDURE Delete;
			VAR l: Line; ofs: LONGINT;
			BEGIN {EXCLUSIVE}
				l := cursor.line;  ofs := cursor.ofs;
				IF ofs > 0 THEN
					DEC( ofs );
					l.data[ofs].attr := attr;
					l.data[ofs].char := 0;
					UpdateRect( l, l, ofs, cursor.ofs, {3} )
				END
			END Delete;


			PROCEDURE GetLine( n: LONGINT ): Line;
			VAR line: Line;
			BEGIN
				line := top;
				WHILE (n > 0) & (line # NIL) DO  line := line.next;  DEC( n )  END;
				RETURN line
			END GetLine;

			PROCEDURE GetLastLine( ): Line;
			VAR line: Line;
			BEGIN
				line := top;
				WHILE line.next # NIL DO  line := line.next  END;
				RETURN line
			END GetLastLine;


			PROCEDURE SetScrollRegion;
			BEGIN
				scrollTop := GetLine( scrollBegin );
				scrollBottom := GetLine( scrollEnd );
			END SetScrollRegion;

			PROCEDURE Goto( row, col: LONGINT );
			VAR l: Line; hl, lines: LONGINT;
			BEGIN {EXCLUSIVE}
				IF col < 0 THEN  col := 0  ELSIF col >= cols THEN  col := cols - 1  END;

				l := first;  hl := 1;
				WHILE l # top DO  INC( hl );  l := l.next  END;
				WHILE hl > 512 DO  first := first.next;  DEC( hl )  END;	(* limit history *)
				lines := 1;

				WHILE row > 0 DO
					IF l.next = NIL THEN
						l := AppendLine( l );
					ELSE
						l := l.next
					END;
					DEC( row );  INC( lines )
				END;

				IF lines > rows THEN
					top := top.next;
					cursor.line := l; cursor.ofs := 0;
					UpdateAll()
				ELSE
					UpdateRect( cursor.line, l, cursor.ofs, col, {2, 4} )
				END;
				SetScrollRegion;
				SetOffsets;
			END Goto;


			PROCEDURE SetOffsets;
			VAR l: Line; y: LONGINT;
			BEGIN
				l := top; y := dY;
				REPEAT
					l.t := y;  INC( y, BoxH );  l.b := y;
					l := l.next
				UNTIL l = NIL
			END SetOffsets;


			PROCEDURE MoveLines( down: BOOLEAN );
			VAR prev, l, newtop: Line;
			BEGIN
				l := first; prev := NIL;
				WHILE l # scrollTop DO  prev := l;  l := l.next  END;
				IF down THEN
					l := GetNewLine( );
					l.next := scrollTop;
					IF prev # NIL THEN
						prev.next := l;
						IF top = scrollTop THEN top := l  END
					ELSE  first := l;  top := l
					END;
					WHILE (l # scrollBottom) & (l.next # NIL) DO  prev := l; l := l.next  END;
					prev.next := l.next; (* unlink bottom line *)
				ELSE	(* up *)
					WHILE (l # scrollBottom) & (l.next # NIL) DO  l := l.next  END;
					l := AppendLine( l );
					newtop := scrollTop.next;
					prev.next := newtop;	(* unlink top line *)
					IF top = scrollTop THEN  top := newtop  END;
					IF first = scrollTop THEN  first := newtop  END;
				END;
				SetScrollRegion;
				SetOffsets
			END MoveLines;

			PROCEDURE Scroll( down: BOOLEAN );
			BEGIN {EXCLUSIVE}
				MoveLines( down );
				IF down THEN
					cursor.line := scrollTop; cursor.ofs := 0;
					UpdateAll
				ELSE
					cursor.line := scrollBottom; cursor.ofs := 0;
					UpdateAll
				END
			END Scroll;


			PROCEDURE SetMargins( beg, end: LONGINT );
			BEGIN {EXCLUSIVE}
				scrollBegin := beg - 1;
				scrollEnd := end - 1 ;
				SetScrollRegion
			END SetMargins;


			PROCEDURE RightTab;
			VAR l: Line; ofs: LONGINT; char: Char;
			BEGIN {EXCLUSIVE}
				char.attr := attr; char.char := 020H;
				l := cursor.line;  ofs := cursor.ofs + 1;
				WHILE (ofs < cols) & ~tabs[ofs] DO
					l.data[ofs] := char;  INC( ofs )
				END;
				IF ofs = cursor.ofs THEN  RETURN  END;
				UpdateRect( l, l, cursor.ofs, ofs, {4} )
			END RightTab;

			PROCEDURE EraseLine( l: Line; from, to: LONGINT );
			VAR i: LONGINT;
			BEGIN
				i := from;
				WHILE i <= to DO
					l.data[i].attr := attr;  l.data[i].char := 0;
					INC( i )
				END
			END EraseLine;

			PROCEDURE Erase( mode: CHAR;  CONST par: ARRAY OF LONGINT;  n: LONGINT );
			BEGIN {EXCLUSIVE}
				CASE mode OF
				|"J":
					sel.beg.line := NIL;
					top := GetLastLine();
					cursor.line := top; cursor.ofs := 0;
					EraseLine( top, 0, cols-1 );
					UpdateAll();
					SetScrollRegion;
				|"K":
					IF n = 0 THEN
						EraseLine( cursor.line, cursor.ofs, cols-1 );
						UpdateRect( cursor.line, cursor.line, cursor.ofs, cols-1, {} )
					ELSIF (n = 1) & (par[0] = 1) THEN
						EraseLine( cursor.line, 0, cursor.ofs );
						UpdateRect( cursor.line, cursor.line, 0, cursor.ofs, {} )
					ELSIF (n = 1) & (par[0] = 2) THEN
						EraseLine( cursor.line, 0, cols-1 );
						UpdateRect( cursor.line, cursor.line, 0, cols-1, {} )
					END
				END
			END Erase;

			PROCEDURE NewAttr;
			VAR f: Files.File;
			BEGIN
				NEW(attr); attr.special := {};
				f := Files.Old( "Veramono_bd.ttf" );
				IF f # NIL THEN
				(*	attr.fnt := WMG.GetFont( "Dejavumono", 12, {} ) *)
					attr.fnt := WMG.GetFont( "Veramono", 12, {0} )
				ELSE
					attr.fnt := WMG.GetFont( "Courier", 12, {} )
				END;
				attr.bg := WMG.RGBAToColor( 255, 255, 255, 255 );
				attr.fg := WMG.RGBAToColor( 0, 0, 0, 255 )
			END NewAttr;

			PROCEDURE Bright;
			VAR style: SET;
			BEGIN
				style := attr.fnt.style;
				IF ~(WMG.FontBold IN style) THEN
					INCL( style, WMG.FontBold );
					attr.fnt := WMG.GetFont( attr.fnt.name, attr.fnt.size, style )
				ELSE
Out.String("Bright"); Out.Ln()
				END
			END Bright;

			PROCEDURE Dim;
			VAR style: SET;
			BEGIN
				style := attr.fnt.style;
				IF WMG.FontBold IN style THEN
					EXCL( style, WMG.FontBold );
					attr.fnt := WMG.GetFont( attr.fnt.name, attr.fnt.size, style )
				ELSE
Out.String("Dim"); Out.Ln()
				END
			END Dim;

			PROCEDURE SetAttributes( CONST attrs: ARRAY OF LONGINT; n: LONGINT );
			VAR c, i: LONGINT;
			BEGIN {EXCLUSIVE}
				NewAttr();
				i := 0;
				WHILE i < n DO
					CASE attrs[i] OF
					|0: (* Reset *) NewAttr()
					|1: (* Bright *) Bright()
					|2: (* Dim *) Dim()
					|4: (* Underscore *) INCL( attr.special, Underscore )
					|5: (* Blink *) INCL( attr.special, Blink )
					|7: (* Reverse *) c := attr.bg; attr.bg := attr.fg; attr.fg := c
					|8: (* Hidden *) attr.fg := attr.bg
					ELSE
Out.String("attr "); Out.Int(attrs[i], 0); Out.Ln()
					END;
					INC(i)
				END
			END SetAttributes;

			PROCEDURE Draw( canvas: WMG.Canvas );
			VAR
				l: Line; i, j, dy, bottom: LONGINT; attr: Attribute; char: Char;
				box: WMG.Rectangle;
			BEGIN {EXCLUSIVE}
				canvas.Fill( canvas.clipRect, bg, WMG.ModeCopy );
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
							canvas.SetColor( attr.fg );
							canvas.SetFont( attr.fnt );
							dy := attr.fnt.GetDescent()
						END;
						IF attr.bg # bg THEN
							canvas.Fill( box, attr.bg, WMG.ModeCopy )
						END;
						IF char.char # 0 THEN
							attr.fnt.RenderChar( canvas, box.l, box.b-dy, char.char )
						END;
						IF Underscore IN attr.special THEN
							canvas.Line( box.l, box.b-dy+1, box.r-1, box.b-dy+1, attr.fg, WMG.ModeCopy )
						END;
						INC( i ); INC( box.l, boxW ); INC( box.r, boxW )
					END;
					INC( j ); l := l.next;
					INC( box.t, boxH ); INC( box.b, boxH )
				END;

				WHILE l # NIL DO
					l.t := MAX(INTEGER); l.b := MAX(INTEGER); l := l.next
				END;

				IF hasFocus & (cursor.ofs >= 0) & (cursor.ofs < cols) THEN
					l := cursor.line; box.t := l.t; box.b := l.b;
					IF box.t < box.b THEN
						box.l := dX + cursor.ofs*boxW; box.r := box.l + boxW;
						canvas.Fill( box, WMG.RGBAToColor( 255, 0, 0, 192 ), WMG.ModeSrcOverDst )
					ELSE
						FocusLost
					END
				END;
				IF sel.beg.line # NIL THEN
					IF sel.beg.line = sel.end.line THEN
						box.l := dX + sel.beg.ofs * boxW; box.r := dX + sel.end.ofs * boxW + boxW;
						box.t := sel.beg.line.t; box.b := sel.end.line.b;
						canvas.Fill( box, WMG.RGBAToColor( 0, 0, 255, 32 ), WMG.ModeSrcOverDst )
					ELSE
						box.l := dX + sel.beg.ofs * boxW; box.r := dX + cols * boxW;
						box.t := sel.beg.line.t; box.b := sel.beg.line.b;
						canvas.Fill( box, WMG.RGBAToColor( 0, 0, 255, 32 ), WMG.ModeSrcOverDst );
						l := sel.beg.line.next;
						WHILE l # sel.end.line DO
							box.l := dX; box.r := dX + cols * boxW;
							box.t := l.t; box.b := l.b;
							canvas.Fill( box, WMG.RGBAToColor( 0, 0, 255, 32 ), WMG.ModeSrcOverDst );
							l := l.next
						END;
						box.l := dX; box.r := dX + sel.end.ofs * boxW + boxW;
						box.t := sel.end.line.t; box.b := sel.end.line.b;
						canvas.Fill( box, WMG.RGBAToColor( 0, 0, 255, 32 ), WMG.ModeSrcOverDst )
					END
				END
			END Draw;

			PROCEDURE MoveCursor( dr, dc: LONGINT );
			VAR col, currrow: LONGINT;
			BEGIN
				col := GetCol() + dc;
				IF col < 0 THEN  col := 0  END;
				currrow := GetRow();
				IF (currrow = scrollEnd) & (dr > 0) THEN
					IF currrow < rows - 1 THEN  Scroll( FALSE );  Goto( currrow, col )
					ELSE Goto( currrow + 1, col )
					END
				ELSIF (currrow = scrollBegin) & (dr < 0) THEN  Scroll( TRUE );  Goto( currrow, col )
				ELSE  Goto( currrow + dr, col )
				END
			END MoveCursor;

			PROCEDURE ESCSequence(ch: CHAR);
			VAR
				par: ARRAY 4 OF LONGINT; i, n: LONGINT;
			BEGIN
				r.Char( ch );
				IF ch = "[" THEN
					ch := r.Peek(); n := 0;
					IF ch = "?" THEN
						r.Char( ch ); ch := r.Peek();
						IF (ch >= "0") & (ch <= "9") THEN
							REPEAT
								r.Int( par[n], FALSE );  INC( n );
								r.Char( ch )
							UNTIL (n >= 4) OR (ch # " ")
						END
					ELSIF (ch >= "0") & (ch <= "9") THEN
						REPEAT
							r.Int( par[n], FALSE ); INC( n );
							r.Char( ch )
						UNTIL (n >= 4) OR (ch # ";")
					ELSE
ASSERT( ch < DEL );
						r.Char( ch )
					END;
					CASE ch OF
					|"A":
						IF n = 1 THEN  MoveCursor( -par[0], 0 )  ELSE  MoveCursor( -1, 0 )  END
					|"B":
						IF n = 1 THEN  MoveCursor( par[0], 0 )  ELSE  MoveCursor( 1, 0 )  END
					|"C":
						IF n = 1 THEN  MoveCursor( 0, par[0] )  ELSE  MoveCursor( 0, 1 )  END
					|"D":
						IF n = 1 THEN  MoveCursor( 0, -par[0] )  ELSE  MoveCursor( 0, -1 )  END
					|"H":
						IF n = 2 THEN  Goto( par[0] - 1, par[1] - 1 )  ELSE  Goto( 0, 0 )  END
					|"J", "K":
						Erase( ch, par, n )
					|"h":
						IF n = 1 THEN
							IF par[0] = 1 THEN  INCL( mode, CursorKeyMode )
							ELSIF par[0] = 7 THEN  INCL( mode, AutoWrapMode )
							END
						END
					|"l":
						IF n = 1 THEN
							IF par[0] = 1 THEN  EXCL( mode, CursorKeyMode )
							ELSIF par[0] = 7 THEN  EXCL( mode, AutoWrapMode )
							END
						END
					|"m":
						SetAttributes( par, n )
					| "r":
						SetMargins( par[0], par[1] )
					ELSE
Out.Ln;  Out.String( "got unknown sequence ESC [ " );
i := 0;
WHILE i < n DO
	Out.Int( par[i], 0 );  INC( i );
	IF i < n THEN  Out.String( " ; " )  END
END;
Out.Char( ch );  Out.Ln;
					END
				ELSE
					CASE ch OF
					|"7":
						old.attr := attr;
						old.offs := GetCol();
						old.row := GetRow()
					|"8":
						IF r.Peek( ) = '#' THEN  r.Char( ch );  EFill
						ELSE  attr := old.attr;  Goto( old.row, old.offs )
						END
					|"=":
						INCL( mode, AppKeypadMode )
					|">":
						EXCL( mode, AppKeypadMode )
					|"D":
						IF GetRow() = scrollEnd THEN  Scroll( FALSE )
						ELSE  Goto( GetRow() + 1, GetCol() )
						END
					|"M":
						IF GetRow() = scrollBegin THEN  Scroll( TRUE )
						ELSE  Goto( GetRow() - 1, GetCol() )
						END
					ELSE
Out.String("got unknown sequence ESC ");
IF (ch >= ' ') & (ch <= '~') THEN  Out.Char( "'" ); Out.Char( ch ); Out.Char( "'" )
ELSE  Out.Hex( ORD( ch ), 2 ); Out.Char( 'X' )
END;
Out.Ln;
					END
				END
			END ESCSequence;


			PROCEDURE Consume( ch: CHAR );
			VAR buf: ARRAY 256 OF CHAR; i, n: LONGINT;
			BEGIN
				CASE ch OF
				|  0X: (* NUL *)
				|07X: Beep.Beep( 1000 )
				|08X: MoveCursor( 0, -1 )
				|09X: RightTab()
				|NL, 0BX, 0CX:
					MoveCursor( 1, -1000 )
				|CR:
					IF r.Peek() = NL THEN
						r.Char( ch );
						MoveCursor( 1, -1000 )
					ELSE
						MoveCursor( 0, -1000 )
					END
				|ESC: ESCSequence(ch)
				|DEL: Delete()
				ELSE (* iso-8859-1 *)
					buf[0] := ch;  i := 1;  n := r.Available();
					IF n > 0 THEN
						IF n > 127 THEN  n := 127  END;
						ch := r.Peek();
						WHILE (n > 0) & (ch >= ' ') & (ch <= '~') DO
							r.Char( ch ); DEC( n );
							buf[i] := ch; INC( i );
							IF n > 0 THEN  ch := r.Peek()  END
						END
					END;
					WriteChars( buf, i )
				END
			END Consume;


			PROCEDURE FocusReceived;
			BEGIN
				FocusReceived^();
				UpdateBox( cursor.line, cursor.ofs )
			END FocusReceived;

			PROCEDURE FocusLost;
			BEGIN
				FocusLost^();
				UpdateBox( cursor.line, cursor.ofs )
			END FocusLost;

			PROCEDURE LocateBox( x, y: LONGINT; VAR pos: Position );
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
				Texts.clipboard.Delete( 0, end );
				pos := 0;  buf[1] := 0;  l := sel.beg.line;
				attr := NIL;  tattr := NIL;  apos := -1;
				LOOP
					IF l = sel.beg.line THEN  ofs := sel.beg.ofs  ELSE  ofs := 0  END;
					IF l = sel.end.line THEN  end := sel.end.ofs + 1  ELSE  end := cols  END;
					WHILE ofs < end DO
						IF l.data[ofs].char # 0 THEN
							buf[0] := l.data[ofs].char;
							IF attr # l.data[ofs].attr THEN
								IF tattr # NIL THEN
									Texts.clipboard.SetAttributes( apos, pos - apos, tattr )
								END;
								apos := pos;  attr := l.data[ofs].attr;
								NEW( tattr );  NEW( tattr.fontInfo );
								tattr.color := attr.fg;  tattr.bgcolor := attr.bg;
								COPY( attr.fnt.name, tattr.fontInfo.name );
								tattr.fontInfo.size := attr.fnt.size;
								tattr.fontInfo.style := attr.fnt.style
							END;
							Texts.clipboard.InsertUCS32( pos, buf );  INC( pos )
						END;
						INC( ofs )
					END;
					IF l = sel.end.line THEN
						EXIT
					ELSE
						l := l.next;
						buf[0] := 0AH;
						Texts.clipboard.InsertUCS32( pos, buf );  INC( pos )
					END
				END;
				IF tattr # NIL THEN
					Texts.clipboard.SetAttributes( apos, pos - apos, tattr )
				END;
				Texts.clipboard.ReleaseWrite()
			END Copy;

			PROCEDURE Paste;
			VAR R: Texts.TextReader; ch: LONGINT;
			BEGIN {EXCLUSIVE}
				Texts.clipboard.AcquireRead();
				NEW( R, Texts.clipboard );
				R.SetPosition( 0 );
				R.SetDirection( 1 );
				R.ReadCh( ch );
				WHILE ~R.eot DO
					IF (ch DIV 256) = 0 THEN w.Char( CHR( ch ) ) END;
					R.ReadCh( ch )
				END;
				Texts.clipboard.ReleaseRead();
				w.Update()
			END Paste;

			PROCEDURE ClickHandler( sender, par: ANY );
			VAR b: WMStandardComponents.Button; str: Strings.String;
			BEGIN
				popup.Close();
				b := sender( WMStandardComponents.Button );
				str := b.caption.Get();
				IF str^ = "Copy" THEN
					Copy()
				ELSIF str^ = "Paste" THEN
					Paste()
				END
			END ClickHandler;

			PROCEDURE PointerDown( x, y: LONGINT; keys: SET );
			BEGIN
				IF (Left IN keys) & hasFocus THEN
					LocateBox( x, y, sel.beg );  sel.end := sel.beg
				ELSIF Right IN keys THEN
					ToWMCoordinates(x, y, x, y);
					popup.Popup( x, y )
				ELSE
					sel.beg.line := NIL;  sel.beg.ofs := -1;
					sel.end := sel.beg
				END;
				UpdateAll()
			END PointerDown;

			PROCEDURE PointerMove( x, y: LONGINT; keys: SET );
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


			PROCEDURE PointerUp( x, y: LONGINT; keys: SET );
			END PointerUp;

			PROCEDURE CursorKey( keySym: LONGINT );
			BEGIN
				w.Char( ESC );
				IF CursorKeyMode IN mode THEN  w.Char( "O" )
				ELSE  w.Char( "[" )
				END;
				CASE keySym OF
				|0FF51H: w.Char( "D" )
				|0FF52H: w.Char( "A" )
				|0FF53H: w.Char( "C" )
				|0FF54H: w.Char( "B" )
				ELSE
				END;
				w.Update()
			END CursorKey;

			PROCEDURE KeyEvent( ucs: LONGINT; flags: SET; VAR keySym: LONGINT );
			BEGIN
				IF chan = NIL THEN  RETURN  END;

				IF ~(Inputs.Release IN flags) & hasFocus THEN
					IF (keySym DIV 256) = 0 THEN
						w.Char( CHR( keySym ) );  w.Update()
					ELSIF (keySym DIV 256) = 0FFH THEN
						CASE keySym OF
						|0FF51H .. 0FF54H:
							CursorKey(keySym)
						|0FF50H: (* Home *)
						|0FF55H: (* PgUp *)
						|0FF56H: (* PgDown *)
						|0FF57H: (* End *)
						|0FF63H: (* Insert *)
						|0FFFFH: (* Delete *)
						|0FF08H:
							w.Char( DEL );  w.Update()
						|0FF09H:
							w.Char( 9X );  w.Update()
						|0FF0DH:
							w.Char( CR );  w.Update()
						|0FF1BH:
							w.Char( ESC );  w.Update()
						|0FF8DH:
							IF AppKeypadMode IN mode THEN
								w.Char( ESC ); w.Char( "O" ); w.Char( "M" )
							ELSE
								w.Char( CR )
							END;
							w.Update()
						ELSE
						END
					END
				END
			END KeyEvent;

			PROCEDURE Handle( VAR m : WMMessages.Message );
			BEGIN
				IF m.msgType = WMMessages.MsgKey THEN
					IF m.y MOD 256 = 9 THEN  KeyEvent( m.x, m.flags, m.y )
					ELSE  Handle^( m )
					END;
				ELSE Handle^( m )
				END
			END Handle;


			PROCEDURE resized;
			VAR l: Line; W, H, c, r, i: LONGINT; d: Data; ch: Char;
			BEGIN {EXCLUSIVE}
				W := bounds.GetWidth() - 2*Border;
				H := bounds.GetHeight() - 2*Border;
				c := W DIV BoxW; r := H DIV BoxH;
				boxW := W DIV c; boxH := H DIV r;
				dX := Border + (W - c*boxW) DIV 2;
				dY := Border + (H - r*boxH) DIV 2;

				SetOffsets;
				IF c # cols THEN
					ch.attr := attr;  ch.char := 0;
					l := first;
					WHILE l # NIL DO
						NEW( d, c );  i := 0;
						WHILE (i < c) & (i < cols) DO  d[i] := l.data[i];  INC( i )  END;
						WHILE i < c DO  d[i] := ch;  INC( i )  END;
						l.data := d; l := l.next
					END
				END;
				IF (c # cols) OR (r # rows) THEN
					IF cursor.ofs >= c THEN  cursor.ofs := c - 1  END;
					l := cursor.line;
					IF l.b > (dY + r*boxH) THEN
						i := (l.b - (dY + r*boxH)) DIV boxH;
						l := top.next;
						WHILE (l # NIL) & (i > 0) DO  top := l;  l := l.next;  DEC( i )  END
					END;
					IF (rows # r) & (scrollEnd = rows - 1) THEN
						scrollEnd := r - 1;  scrollBottom := GetLine( r )
					END;
					sel.beg.line := NIL;  cols := c;  rows := r;
				END;
			END resized;

			PROCEDURE Resized;
			BEGIN
				Resized^();
				resized();
				IF chan # NIL THEN  chan.WindowChange( cols, rows )  END
			END Resized;		

			PROCEDURE Initialize;
			BEGIN
				Initialize^();
				Resized;
				takesFocus.Set( TRUE );
				Invalidate()
			END Initialize;

			PROCEDURE SetChannel( c: SSH.Channel );
			BEGIN{EXCLUSIVE}
				chan := c;
				Streams.OpenReader( r, chan.Receive );
				Streams.OpenWriter( w, chan.Send );
				mode := {};
				chan.WindowChange( cols, rows )
			END SetChannel;

			PROCEDURE &New*( cols, rows: LONGINT; close: WindowCloser );
			VAR i: LONGINT;
			BEGIN
				Init();
				closeWindow := close;
				SELF.rows := rows;  SELF.cols := cols;
				NewAttr();
				bg := WMG.RGBAToColor( 255, 255, 255, 255 );
				first := AppendLine( NIL );
				top := first;
				scrollBegin := 0;  scrollEnd := rows - 1;
				SetScrollRegion;
				cursor.line := top;  cursor.ofs := 0;
				boxW := 0;  boxH := 0;  dX := 0;  dY := 0;
				NEW( tabs, cols + 1 );
				tabs[0] := FALSE;  i := 1;
				WHILE i <= cols DO  tabs[i] := (i MOD 8) = 0;  INC( i )  END;
				NEW( popup );
					popup.Add( "Copy", ClickHandler );
					popup.Add( "Paste", ClickHandler )
			END New;

			PROCEDURE Setup;
			BEGIN {EXCLUSIVE}
				AWAIT( chan # NIL );
			END Setup;

			PROCEDURE Dispatch;
			VAR ch: CHAR;
			BEGIN
				r.Char( ch );
				WHILE (chan.state = SSH.ChanOpen) & (r.res = Streams.Ok) DO
					Consume( ch );
					r.Char( ch )
				END
			END Dispatch;

		BEGIN {ACTIVE}
			Setup();
			Dispatch();
			IF closeWindow # NIL THEN closeWindow END;
		END Frame;




		Window = OBJECT( WMComponents.FormWindow )
		VAR
			toolbar: WMStandardComponents.Panel;
			address, user: WMEditors.Editor;
			connect, help : WMStandardComponents.Button;

			sshConn: SSHAuthorize.Connection;
			sshChan: SSH.Channel;
			frame: Frame;

			PROCEDURE &New;
			VAR vc: WMComponents.VisualComponent;
			BEGIN
				vc := CreateForm();
				Init( vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE );
				SetContent( vc );
				SetTitle( WMWindowManager.NewString( "SSH Client" ) );
				WMWindowManager.DefaultAddWindow( SELF )
			END New;


			PROCEDURE CreateForm( ): WMComponents.VisualComponent;
			VAR
				panel: WMStandardComponents.Panel;
				label : WMStandardComponents.Label;
			BEGIN
				NEW( panel );
					panel.bounds.SetWidth( 2*Border + TerminalWidth*BoxW );
					panel.bounds.SetHeight( 2*Border + TerminalHeight*BoxH + 20 );
					panel.fillColor.Set( LONGINT( 0FFFFFFFFH ) );

				NEW( toolbar );
					toolbar.bounds.SetHeight( 20 );
					toolbar.alignment.Set( WMComponents.AlignTop );
					toolbar.fillColor.Set( LONGINT( 0CCCCCCFFH ) );

				NEW( label );
					label.bounds.SetWidth( 40 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( " Host: " );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);

				NEW( address );
					address.bounds.SetWidth( 250 );
					address.alignment.Set( WMComponents.AlignLeft );
					address.tv.textAlignV.Set(WMG.AlignCenter);
					address.multiLine.Set( FALSE );
					address.fillColor.Set( LONGINT( 0FFFFFFFFH ) );
					address.tv.showBorder.Set( TRUE );
					address.tv.borders.Set( WMRectangles.MakeRect( 3,3,1,1 ) );
					address.onEnter.Add( ConnectHandler );
					address.SetAsString( "einstein.math.uni-bremen.de" );
				toolbar.AddContent( address );

				NEW( label );
					label.bounds.SetWidth( 40 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( " User: " );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent( label );

				NEW( user );
					user.bounds.SetWidth( 100 );
					user.alignment.Set( WMComponents.AlignLeft );
					user.tv.textAlignV.Set(WMG.AlignCenter);
					user.multiLine.Set( FALSE );
					user.fillColor.Set( LONGINT( 0FFFFFFFFH ) );
					user.tv.showBorder.Set( TRUE );
					user.tv.borders.Set( WMRectangles.MakeRect( 3,3,1,1 ) );
					user.onEnter.Add( ConnectHandler );
					user.SetAsString( "fld" );
				toolbar.AddContent( user );


				NEW( connect );
					connect.bounds.SetWidth( 100 );
					connect.alignment.Set( WMComponents.AlignLeft );
					connect.caption.SetAOC( "Connect" );
					connect.onClick.Add( ConnectHandler );
				toolbar.AddContent( connect );

				NEW( help );
					help.bounds.SetWidth( 100 );
					help.alignment.Set( WMComponents.AlignRight );
					help.caption.SetAOC( " Help " );
					help.onClick.Add( HelpHandler );

				toolbar.AddContent( help );
				panel.AddContent( toolbar );

				NEW( frame, TerminalWidth, TerminalHeight, Close );
				frame.alignment.Set( WMComponents.AlignClient );
				panel.AddContent( frame );
				Init( panel.bounds.GetWidth(), panel.bounds.GetHeight(), FALSE );

				RETURN panel
			END CreateForm;


			PROCEDURE Connected( ): BOOLEAN;
			BEGIN
				RETURN (sshChan # NIL) & (sshChan.state = SSH.ChanOpen)
			END Connected;


			PROCEDURE ConnectHandler( sender, data: ANY );
			VAR host, uid: ARRAY 64 OF CHAR;
			BEGIN
				address.GetAsString( host );
				IF host = "" THEN
					Beep.Beep( 1000 );
					Out.String( "no hostname specified" ); Out.Ln;  RETURN
				END;
				user.GetAsString( uid );
				IF uid = "" THEN
					Beep.Beep( 1000 );
					Out.String( "user name missing" ); Out.Ln;  RETURN
				END;
				IF Connected() THEN
					Beep.Beep( 1000 );
					Out.String( "still connected" ); Out.Ln;  RETURN
				END;

				sshConn := SSHAuthorize.OpenConnection( host, uid );
				IF sshConn # NIL THEN
					sshChan := SSH.OpenSession( sshConn, TRUE (*interactive *) );
					frame.SetChannel( sshChan )
				END
			END ConnectHandler;

			PROCEDURE HelpHandler( sender, data: ANY );
			VAR res: LONGINT; msg: ARRAY 128 OF CHAR;
			BEGIN
				Commands.Call( "PAR Notepad.Open SSH.Tool ~", {}, res, msg );
				IF res # Commands.Ok THEN  Out.String( msg ); Out.Ln  END;
			END HelpHandler;


			PROCEDURE Close;
			BEGIN
				IF Connected( ) THEN
					sshConn.Disconnect( 11, "" );
				END;
				Close^
			END Close;

	END Window;



	PROCEDURE Open*;
	VAR inst: Window;
	BEGIN
		NEW( inst );
	END Open;



BEGIN
	hexd := "0123456789ABCDEF"
END SSHClient.



SSHGlobals.SetDebug 15 ~

SSHClient.Open ~

SystemTools.Free SSHClient SSH ~



home, end, delete, insert, pageup, pagedown

emacs
pine
pico
lynx


