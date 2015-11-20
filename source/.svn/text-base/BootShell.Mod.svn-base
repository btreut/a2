MODULE BootShell; (** AUTHOR "staubesv"; PURPOSE "Simple VGA text mode shell"; *)

IMPORT
	SYSTEM, KernelLog, Machine, Modules, Streams, Commands, Inputs, Strings, Locks;

CONST
	Version = "A2 Bootshell v1.0";

	LineWidth = 80; TraceHeight = 25;
	TraceBase = 0B8000H; (* default screen buffer *)

	BufferHeight = 2048; (* lines *)

	BufferSize = BufferHeight * LineWidth; (* characters *)

	TAB = 09X;
	CR = 0DX;
	LF = 0AX;
	SPACE = " ";

	Mode_Insert = 0;
	Mode_Overwrite = 1;

	Black = 0;
	Blue = 1;
	Green = 2;
	Cyan = 3;
	Red = 4;
	Magenta = 5;
	Brown = 6;
	White = 7;
	Gray = 8;
	LightBlue = 9;
	LightGreen = 10;
	LightCyan = 11;
	LightRed = 12;
	LightMagenta = 13;
	Yellow = 14;
	BrightWhite = 15;

TYPE

	(* Copied from Shell.mod *)
	CommandsString = POINTER TO RECORD
		prev, next: CommandsString;
		string: Strings.String;
	END;

	CommandHistoryObject = OBJECT
	VAR
		first, current: CommandsString;

		PROCEDURE GetNextCommand() : Strings.String;
		VAR string : Strings.String;
		BEGIN
			IF first # NIL THEN
				IF current = NIL THEN current := first ELSE current := current.next END;
				string := current.string;
			ELSE
				string := NIL;
			END;
			RETURN string;
		END GetNextCommand;

		PROCEDURE GetPreviousCommand() : Strings.String;
		VAR string : Strings.String;
		BEGIN
			IF first # NIL THEN
				IF current = NIL THEN current := first.prev ELSE current := current.prev END;
				string := current.string;
			ELSE
				string := NIL;
			END;
			RETURN string;
		END GetPreviousCommand;

		PROCEDURE AddCommand(string : Strings.String);
		VAR command: CommandsString;
		BEGIN
			ASSERT((string # NIL) & (string^ # ""));
			command := first;
			IF command # NIL THEN
				WHILE (command.string^ # string^) & (command.next # first) DO command := command.next END;
				IF command.string^ # string^ THEN command := NIL END
			END;
			IF command # NIL THEN
				IF first = command THEN first := command.next END;
				command.prev.next := command.next;
				command.next.prev := command.prev;
			ELSE
				NEW (command);
				command.string := string;
			END;
			IF first = NIL THEN
				first := command; first.next := first; first.prev := first
			ELSE
				command.prev := first.prev; command.next := first;
				first.prev.next := command; first.prev := command;
			END;
			current := NIL;
		END AddCommand;

		PROCEDURE &Init*;
		BEGIN first := NIL; current := NIL;
		END Init;

	END CommandHistoryObject;

TYPE

	Character = RECORD
		ch : CHAR;
		color : SHORTINT;
	END;

	Line = ARRAY LineWidth OF Character;

	TextBuffer = OBJECT
	VAR
		defaultColor : SHORTINT;
		currentColor : SHORTINT;

		(* ring buffer of lines *)
		lines : ARRAY BufferHeight OF Line;

		(* index of first line in ring buffer *)
		firstLine, lastLine : LONGINT;

		(* index of line currently shown on top of the display *)
		firstLineShown : LONGINT;

		(* start and end of currently edited text *)
		editStartPosition, editEndPosition : LONGINT;

		(* character position of cursor *)
		cursorPosition : LONGINT;

		mode : LONGINT;

		lock : Locks.RecursiveLock;

		PROCEDURE &Init*;
		BEGIN
			mode := Mode_Insert;
			NEW(lock);
			lock.Acquire;
			Clear;
			lock.Release;
		END Init;

		PROCEDURE Clear;
		VAR i : LONGINT;
		BEGIN
			ASSERT(lock.HasLock());
			firstLine := 0; lastLine := 0;
			firstLineShown := 0;
			cursorPosition := 0;
			editStartPosition := 0; editEndPosition := 0;
			SetColor(White, Black);
			defaultColor := White + 10H * Black;
			FOR i := 0 TO LEN(lines)-1 DO
				ClearLine(lines[i], 0, LineWidth-1, defaultColor);
			END;
			Invalidate(SELF);
		END Clear;

		PROCEDURE SetColor(foreground, background : SHORTINT);
		BEGIN
			currentColor := foreground + 10H * background;
		END SetColor;

		PROCEDURE SetEditStart;
		BEGIN
			editStartPosition := cursorPosition;
			editEndPosition := cursorPosition;
		END SetEditStart;

		PROCEDURE Send( CONST data: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR i : LONGINT;
		BEGIN
			lock.Acquire;
			FOR i := ofs TO ofs + len - 1 DO
				CharInternal(data[i]);
			END;
			CheckVisibility;
			Invalidate(SELF);
			lock.Release;
			res := Streams.Ok;
		END Send;

		PROCEDURE String(CONST string : ARRAY OF CHAR);
		VAR i : LONGINT;
		BEGIN
			lock.Acquire;
			i := 0;
			WHILE (i < LEN(string)) & (string[i] # 0X) DO
				CharInternal(string[i]);
				INC(i);
			END;
			CheckVisibility;
			Invalidate(SELF);
			lock.Release;
		END String;

		PROCEDURE Char(ch : CHAR);
		BEGIN
			lock.Acquire;
			CharInternal(ch);
			CheckVisibility;
			Invalidate(SELF);
			lock.Release;
		END Char;

		PROCEDURE CheckVisibility;
		BEGIN
			ASSERT(lock.HasLock());
			IF (Difference(lastLine, firstLineShown, LEN(lines)) > TraceHeight - 1) THEN
				firstLineShown := Subtract(lastLine, TraceHeight - 1, LEN(lines));
				Invalidate(SELF);
			END;
		END CheckVisibility;

		PROCEDURE NextLine;
		BEGIN
			ASSERT(lock.HasLock());
			lastLine := Add(lastLine, 1, BufferHeight);
			ClearLine(lines[lastLine], 0, LineWidth-1, defaultColor);
			IF (lastLine = firstLine) THEN
				firstLine := Add(firstLine, 1, BufferHeight);
				IF (firstLineShown = lastLine) THEN
					firstLineShown := firstLine;
				END;
			END;
		END NextLine;

		PROCEDURE MoveCharactersToRight;
		VAR current, previous : LONGINT;
		BEGIN
			ASSERT(editStartPosition # editEndPosition);
			IF (editEndPosition = LineWidth-1) THEN (* reserve new line in advance *)
				NextLine;
			END;
			editEndPosition := Add(editEndPosition, 1, BufferSize);
			current := editEndPosition;
			WHILE (current # cursorPosition) DO
				previous := Subtract(current, 1, BufferSize);
				lines[current DIV LineWidth][current MOD LineWidth] := lines[previous DIV LineWidth][previous MOD LineWidth];
				current := previous;
			END;
		END MoveCharactersToRight;

		PROCEDURE MoveCharactersToLeft;
		VAR current, next : LONGINT;
		BEGIN
			ASSERT(editStartPosition # editEndPosition);
			IF (editEndPosition = 0) THEN (* line will be removed *)
				lastLine := Subtract(lastLine, 1, LEN(lines));
			END;
			current := cursorPosition;
			REPEAT
				next := Add(current, 1, BufferSize);
				lines[current DIV LineWidth][current MOD LineWidth] := lines[next DIV LineWidth][next MOD LineWidth];
				current := next;
			UNTIL (next = editEndPosition);
			editEndPosition := Subtract(editEndPosition, 1, BufferSize);
		END MoveCharactersToLeft;

		PROCEDURE CharInternal(ch : CHAR);
		VAR index : LONGINT;
		BEGIN
			ASSERT(lock.HasLock());
			IF (ch = CR) THEN (* ignore *)
			ELSIF (ch = LF) THEN
				ClearLine(lines[cursorPosition DIV LineWidth], cursorPosition MOD LineWidth, LineWidth-1, currentColor);
				NextLine;
				cursorPosition := Add(cursorPosition, LineWidth - (cursorPosition MOD LineWidth), BufferSize);
				editEndPosition := cursorPosition;
			ELSIF (SPACE <= ch) & (ORD(ch) < 128) THEN
				index := cursorPosition DIV LineWidth;
				IF (cursorPosition = editEndPosition) THEN (* append *)
					ASSERT(index = lastLine);
					lines[index][cursorPosition MOD LineWidth].ch := ch;
					lines[index][cursorPosition MOD LineWidth].color := currentColor;
					cursorPosition := Add(cursorPosition, 1, BufferSize);
					editEndPosition := cursorPosition;
					IF (cursorPosition DIV LineWidth # index) THEN
						NextLine;
					END;
				ELSE
					IF (mode # Mode_Overwrite) THEN
						MoveCharactersToRight;
					END;
					lines[index][cursorPosition MOD LineWidth].ch := ch;
					lines[index][cursorPosition MOD LineWidth].color := currentColor;
					cursorPosition := Add(cursorPosition, 1, BufferSize);
				END;
			END;
		END CharInternal;

		PROCEDURE DeleteCurrentLine;
		VAR i : LONGINT;
		BEGIN
			lock.Acquire;
			i := editStartPosition;
			LOOP
				lines[i DIV LineWidth][i MOD LineWidth].ch := SPACE;
				IF (i = editEndPosition) THEN EXIT; END;
				INC(i);
			END;
			cursorPosition := editStartPosition;
			editEndPosition := editStartPosition;
			lastLine := editStartPosition DIV LineWidth;
			lock.Release;
		END DeleteCurrentLine;

		PROCEDURE GetCurrentLine() : Strings.String;
		VAR string : Strings.String; i, length : LONGINT;
		BEGIN
			lock.Acquire;
			length := Difference(editEndPosition, editStartPosition, BufferSize);
			NEW(string, length + 1);
			i := 0;
			WHILE (i < length - 1) DO
				string[i] := lines[(editStartPosition + i) DIV LineWidth][(editStartPosition + i) MOD LineWidth].ch;
				INC(i);
			END;
			string[length-1] := 0X;
			lock.Release;
			RETURN string;
		END GetCurrentLine;

		PROCEDURE Home;
		BEGIN
			lock.Acquire;
			IF (cursorPosition # editStartPosition) THEN
				cursorPosition := editStartPosition;
				Invalidate(SELF);
			END;
			lock.Release;
		END Home;

		PROCEDURE End;
		BEGIN
			lock.Acquire;
			IF (cursorPosition # editEndPosition) THEN
				cursorPosition := editEndPosition;
				Invalidate(SELF);
			END;
			lock.Release;
		END End;

		PROCEDURE Backspace;
		BEGIN
			lock.Acquire;
			IF (cursorPosition # editStartPosition) THEN
				cursorPosition := Subtract(cursorPosition, 1, BufferSize);
				MoveCharactersToLeft;
				Invalidate(SELF);
			END;
			lock.Release;
		END Backspace;

		PROCEDURE Delete;
		BEGIN
			lock.Acquire;
			IF (cursorPosition # editEndPosition) THEN
				MoveCharactersToLeft;
				Invalidate(SELF);
			END;
			lock.Release;
		END Delete;

		PROCEDURE ScrollUp(nofLines : LONGINT);
		VAR d : LONGINT;
		BEGIN
			lock.Acquire;
			d := Difference(firstLineShown, firstLine, LEN(lines));
			nofLines := Min(nofLines, d - 1);
			IF (nofLines > 0) THEN
				firstLineShown := Subtract(firstLineShown, nofLines, LEN(lines));
			END;
			Invalidate(SELF);
			lock.Release;
		END ScrollUp;

		PROCEDURE ScrollDown(nofLines : LONGINT);
		VAR d : LONGINT;
		BEGIN
			lock.Acquire;
			d := Difference(lastLine, firstLineShown, LEN(lines));
			nofLines := Min(nofLines, d - 1);
			IF (nofLines > 0) THEN
				firstLineShown := Add(firstLineShown, nofLines, LEN(lines));
			END;
			Invalidate(SELF);
			lock.Release;
		END ScrollDown;

		PROCEDURE CursorLeft;
		VAR oldCursorPosition : LONGINT;
		BEGIN
			lock.Acquire;
			IF (cursorPosition # editStartPosition) THEN
				oldCursorPosition := cursorPosition;
				cursorPosition := Subtract(cursorPosition, 1, BufferSize);
				Invalidate(SELF);
			END;
			lock.Release;
		END CursorLeft;

		PROCEDURE CursorRight;
		VAR oldCursorPosition : LONGINT;
		BEGIN
			lock.Acquire;
			IF (cursorPosition # editEndPosition) THEN
				oldCursorPosition := cursorPosition;
				cursorPosition := Add(cursorPosition, 1, BufferSize);
				Invalidate(SELF);
			END;
			lock.Release;
		END CursorRight;

		PROCEDURE Dump(out : Streams.Writer);
		VAR i, j : LONGINT;
		BEGIN
			ASSERT(out # NIL);
			lock.Acquire;
			out.String("firstLine = "); out.Int(firstLine, 0); out.String(", lastLine = "); out.Int(lastLine, 0); out.Ln;
			out.String("firstLineShown = "); out.Int(firstLineShown, 0); out.Ln;
			out.String("cursorPosition = "); out.Int(cursorPosition, 0); out.Ln;
			out.String("editStartPosition = "); out.Int(editStartPosition, 0); out.String(", editEndPosition = "); out.Int(editEndPosition, 0); out.Ln;
			i := firstLine;
			LOOP
				FOR j := 0 TO LineWidth-1 DO
					out.Char(lines[i MOD LEN(lines)][j].ch);
				END;
				out.Ln;
				IF (i = lastLine) THEN EXIT; END;
				INC(i);
			END;
			out.Ln;
			lock.Release;
		END Dump;

	END TextBuffer;

TYPE

	Shell = OBJECT(Inputs.Sink)
	VAR
		textBuffer : TextBuffer;
		history : CommandHistoryObject;

		PROCEDURE &Init;
		BEGIN
			NEW(textBuffer);
			textBuffer.lock.Acquire;
			textBuffer.SetColor(Yellow, Black);
			textBuffer.String(Version);
			textBuffer.Char(LF);
			Prompt;
			textBuffer.SetEditStart;
			textBuffer.lock.Release;
			NEW(history);
			Inputs.keyboard.Register(SELF);
		END Init;

		PROCEDURE Handle(VAR msg: Inputs.Message);
		BEGIN
			IF (msg IS Inputs.KeyboardMsg) & (msg(Inputs.KeyboardMsg).flags * {Inputs.Release} = {}) THEN
				WITH msg:Inputs.KeyboardMsg DO
					IF (msg.keysym = Inputs.KsPageUp) THEN
						IF (msg.flags * Inputs.Shift # {}) THEN textBuffer.ScrollUp(1); ELSE textBuffer.ScrollUp(TraceHeight); END;
					ELSIF (msg.keysym = Inputs.KsPageDown) THEN
						IF (msg.flags * Inputs.Shift # {}) THEN textBuffer.ScrollDown(1); ELSE textBuffer.ScrollDown(TraceHeight); END;
					ELSIF (msg.keysym = Inputs.KsLeft) THEN
						textBuffer.CursorLeft;
					ELSIF (msg.keysym = Inputs.KsRight) THEN
						textBuffer.CursorRight;
					ELSIF (msg.keysym = Inputs.KsUp) THEN
						CommandHistory(FALSE);
					ELSIF (msg.keysym = Inputs.KsDown) THEN
						CommandHistory(TRUE);
					ELSIF (msg.keysym = Inputs.KsHome) THEN
						textBuffer.Home;
					ELSIF (msg.keysym = Inputs.KsEnd) THEN
						textBuffer.End;
					ELSIF (msg.keysym = Inputs.KsDelete) THEN
						textBuffer.Delete;
					ELSIF (msg.keysym = Inputs.KsBackSpace) THEN
						textBuffer.Backspace;
					ELSIF (msg.keysym = Inputs.KsReturn) THEN
						textBuffer.lock.Acquire;
						textBuffer.cursorPosition := textBuffer.editEndPosition;
						textBuffer.Char(LF);
						textBuffer.lock.Release;
						Execute;
						textBuffer.lock.Acquire;
						textBuffer.Char(LF);
						Prompt;
						textBuffer.SetEditStart;
						textBuffer.lock.Release;
					ELSIF (msg.ch = LF) OR ((SPACE <= msg.ch) & (ORD(msg.ch) < 128)) THEN
						textBuffer.Char(msg.ch);
					END;
				END;
			END;
		END Handle;

		PROCEDURE CommandHistory(next : BOOLEAN);
		VAR string : Strings.String;
		BEGIN
			textBuffer.lock.Acquire;
			IF next THEN
				string := history.GetNextCommand();
			ELSE
				string := history.GetPreviousCommand();
			END;
			IF (string # NIL) THEN
				textBuffer.DeleteCurrentLine;
				textBuffer.String(string^);
			END;
			textBuffer.lock.Release;
		END CommandHistory;

		PROCEDURE Prompt;
		BEGIN
			textBuffer.SetColor(LightBlue, Black);
			textBuffer.String("A2>");
			textBuffer.SetColor(White, Black);
		END Prompt;

		PROCEDURE Execute;
		VAR
			context : Commands.Context; writer : Streams.Writer; arg : Streams.StringReader;
			commandLine : Strings.String;
			nbr : ARRAY 8 OF CHAR;
			msg, command : ARRAY 128 OF CHAR;
			i, length, res : LONGINT;
		BEGIN
			commandLine := textBuffer.GetCurrentLine();
			Strings.TrimWS(commandLine^);

			IF (commandLine^ # "") THEN
				history.AddCommand(commandLine);
			END;

			length := Strings.Length(commandLine^);

			i := 0;
			WHILE (i < length) & ~IsWhitespace(commandLine[i]) & (i < LEN(command) - 1) DO
				command[i] := commandLine[i];
				INC(i);
			END;
			command[i] := 0X;

			IF (command = "exit") THEN
				Close;
			ELSIF (command = "clear") THEN
				textBuffer.lock.Acquire;
				textBuffer.Clear;
				textBuffer.lock.Release;
			ELSIF (command = "version") THEN
				textBuffer.lock.Acquire;
				textBuffer.String(Version);
				textBuffer.lock.Release;
			ELSIF (command = "") THEN
				(* ignore *)
			ELSE
				IF (i < length) THEN
					NEW(arg, length - i);
					arg.SetRaw(commandLine^, i, length - i);
				ELSE
					NEW(arg, 1); arg.Set("");
				END;

				NEW(writer, textBuffer.Send, 256);
				NEW(context, NIL, arg, writer, writer, SELF);

				Commands.Activate(command, context, {Commands.Wait}, res, msg);

				context.out.Update; context.error.Update;

				IF (res # Commands.Ok) THEN
					textBuffer.lock.Acquire;
					textBuffer.SetColor(Red, Black);
					textBuffer.String("Command execution error, res = ");
					Strings.IntToStr(res, nbr);
					textBuffer.String(nbr);
					textBuffer.String(" ("); textBuffer.String(msg); textBuffer.String(")");
					textBuffer.Char(LF);
					textBuffer.SetColor(White, Black);
					textBuffer.lock.Release;
				END;
			END;
		END Execute;

		PROCEDURE Quit;
		BEGIN
			Inputs.keyboard.Unregister(SELF);
		END Quit;

	END Shell;

VAR
	shell : Shell;

PROCEDURE Subtract(position, value, bufferSize : LONGINT) : LONGINT;
VAR result : LONGINT;
BEGIN
	ASSERT((0 <= position) & (position < bufferSize));
	value := value MOD bufferSize;
	IF (position - value >= 0) THEN result := position - value;
	ELSE result := bufferSize - 1 - (value - position);
	END;
	ASSERT((0 <= result) & (result < bufferSize));
	RETURN result;
END Subtract;

PROCEDURE Add(position, value, bufferSize : LONGINT) : LONGINT;
VAR result : LONGINT;
BEGIN
	ASSERT((0 <= position) & (position < bufferSize));
	result := (position + value) MOD bufferSize;
	ASSERT((0 <= result) & (result < bufferSize));
	RETURN result;
END Add;

PROCEDURE Difference(end, start, bufferSize : LONGINT) : LONGINT;
VAR result : LONGINT;
BEGIN
	IF (end >= start) THEN
		result := end - start + 1;
	ELSE
		result := (end + 1) + (bufferSize - start + 1);
	END;
	RETURN result;
END Difference;

PROCEDURE ClearLine(VAR line : Line; from, to : LONGINT; color : SHORTINT);
VAR i : LONGINT;
BEGIN
	ASSERT((0 <= from) & (from < LineWidth));
	ASSERT((0 <= to) & (to < LineWidth));
	FOR i := from TO to DO
		line[i].ch := SPACE;
		line[i].color := color;
	END;
END ClearLine;

PROCEDURE IsWhitespace(ch : CHAR) : BOOLEAN;
BEGIN
	RETURN (ch = SPACE) OR (ch = TAB) OR (ch = CR) OR (ch = LF);
END IsWhitespace;

PROCEDURE Min(a, b : LONGINT) : LONGINT;
BEGIN
	IF (a <= b) THEN RETURN a; ELSE RETURN b; END;
END Min;

PROCEDURE Invalidate(textBuffer : TextBuffer);
VAR offset, index, i, nofLines : LONGINT; line : Line; character : Character; ch : CHAR;
BEGIN
	ASSERT(textBuffer # NIL);
	ASSERT(textBuffer.lock.HasLock());
	offset := 0;
	nofLines := 1;
	index := textBuffer.firstLineShown;
	LOOP
		line := textBuffer.lines[index MOD LEN(textBuffer.lines)];
		FOR i := 0 TO LineWidth-1 DO
			character := line[i];
			IF (character.ch = TAB) THEN ch := SPACE; ELSE ch := character.ch; END;
			SYSTEM.PUT16(TraceBase + offset, ORD(ch) + 100H * character.color);
			INC(offset, 2);
		END;
		IF (index = textBuffer.lastLine) OR (nofLines = TraceHeight) THEN EXIT; END;
		INC(index);
		INC(nofLines);
	END;
	WHILE (nofLines < TraceHeight) DO
		FOR i := 0 TO LineWidth-1 DO
			SYSTEM.PUT16(TraceBase + offset, ORD(SPACE));
			INC(offset, 2);
		END;
		INC(nofLines);
	END;
	UpdateCursor(textBuffer);
END Invalidate;

PROCEDURE Open*;
BEGIN {EXCLUSIVE}
	IF (shell = NIL) THEN
		KernelLog.String("BootShell: Starting shell..."); KernelLog.Ln;
		NEW(shell);
	END;
END Open;

PROCEDURE Close*;
BEGIN {EXCLUSIVE}
	IF (shell # NIL) THEN
		shell.Quit;
		shell := NIL;
	END;
END Close;

PROCEDURE Dump*(context : Commands.Context);
BEGIN {EXCLUSIVE}
	IF (shell # NIL) THEN
		shell.textBuffer.Dump(context.out);
	ELSE
		context.out.String("BootShell not started."); context.out.Ln;
	END;
END Dump;

PROCEDURE UpdateCursor(textBuffer : TextBuffer);
VAR cursorLocation : LONGINT;
BEGIN
	ASSERT(textBuffer # NIL);
	ASSERT(textBuffer.lock.HasLock());
	cursorLocation := Subtract(textBuffer.cursorPosition, textBuffer.firstLineShown * LineWidth, BufferSize);
	Machine.Portout8(3D4H, 0EX); (* Select cursor location high register *)
	Machine.Portout8(3D5H, CHR(cursorLocation DIV 100H));
	Machine.Portout8(3D4H, 0FX); (* Select cursor location low register *)
	Machine.Portout8(3D5H, CHR(cursorLocation MOD 100H));
END UpdateCursor;

PROCEDURE Cleanup;
BEGIN
	Close;
END Cleanup;

PROCEDURE Init;
VAR value : ARRAY 32 OF CHAR;
BEGIN
	Machine.GetConfig("Diagnosis", value);
	Strings.TrimWS(value);
	IF (value = "1") THEN
		Open;
		BEGIN {EXCLUSIVE} AWAIT(shell = NIL); END;
	END;
END Init;

BEGIN
	Modules.InstallTermHandler(Cleanup);
	Init;
END BootShell.

SystemTools.DoCommands

	Linker.Link \P../Test/ \.Obx ../Test/IDE.Bin 0100000H 1000H Kernel Traps
		ATADisks DiskVolumes DiskFS Keyboard BootShell BootConsole ~

	VirtualDisks.Install VM0 E:/Private/A2/WinAos/VM/Old-f001.vmdk ~

	Partitions.UpdateBootFile VM0#1 ../Test/IDE.Bin ~

	VirtualDisks.Uninstall VM0 ~
~~~

SystemTools.DoCommands

	FSTools.DeleteFiles BootShell.img ~

	VirtualDisks.Create BootShell.img 2048 512 ~
	VirtualDisks.Install -c=80 -h=2 -s=18 -b=512 VDISK0 BootShell.img ~

	Linker.Link \P../Test/ \.Obx ../Test/CD.Bin 0100000H 1000H Kernel Traps ProcessInfo SystemTools Keyboard BootShell BootConsole ~

	Partitions.Format VDISK0#0 AosFS 640 ../Test/CD.Bin ~

	Partitions.SetConfig VDISK0#0
		TraceMode="4" TracePort="1" TraceBPS="115200"
		ExtMemSize="64"
		MaxProcs="-1"
		Diagnosis="1"
	~
	VirtualDisks.Uninstall VDISK0 ~

	IsoImages.Make A2Diagnosis.iso BootShell.img ~

~~
