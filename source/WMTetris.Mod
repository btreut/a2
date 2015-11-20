MODULE WMTetris;	(** AUTHOR "TF"; PURPOSE "Tetris with semitransparent blocks"; *)

IMPORT
	Modules, Kernel, Random, Strings,
	Raster, WMRasterScale, WMRectangles, WMGraphics, WMGraphicUtilities,
	WMMessages, WM := WMWindowManager, WMDialogs;

CONST

	Border = 10; (* window border in number of pixels *)

	BoxSize = 16;

	(* Width and height of game field in number of BoxSize's *)
	Width = 10;	Height = 30;

	(* Position of game field *)
	FieldOffsetX = 120;
	FieldOffsetY = Border;

	InfoOffsetX = Border;
	InfoOffsetY = 100;
	InfoWidth = FieldOffsetX - 2*Border;
	InfoHeight = 110 + 2 * Border;
	InfoLineHeight  = 20;

	WindowWidth = 1*Border + FieldOffsetX + Width*BoxSize;
	WindowHeight = 2*Border + Height*BoxSize;

	BevelBorder = 3;
	BlockSize = 5;

	NofBlocks = 7;
	RandomDrop = FALSE;

	LinesToLevelRatio = 10; (* level = lines DIV LinesToLevelRatio *)

	(* Additions bonus points when removing more than one line at once (1 line = 1 point) *)
	TwoLinesBonus = 6; (* 2 lines -> 8 points *)
	ThreeLinesBonus = 13; (* 3 lines -> 16 points *)
	FourLinesBonus = 46; (* 4 lines -> 50 points *)

	SameColorBonus = 50; (* Bonus when removing a line where all boxes have the same color *)
	LevelUpBonus = 20;

	Initialized = 0;
	Running = 5;
	Paused = 6;
	Restarting = 7;
	Finished = 8;
	Terminating = 9;
	Terminated = 10;

VAR
	colors : ARRAY NofBlocks + 1 OF Raster.Pixel;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;

	Block = ARRAY BlockSize, BlockSize OF CHAR;

	Window = OBJECT (WM.BufferWindow)
	VAR
		dropped : BOOLEAN;
		field : ARRAY Width OF ARRAY Height OF CHAR;
		rotBlock, block, nextBlock : Block;
		posX, posY : LONGINT;
		mode : Raster.Mode;
		random : Random.Generator;
		lines, blocks, delay, delayDec, level, points : LONGINT;

		generateNewBlock : BOOLEAN;

		timer : Kernel.Timer;
		state : LONGINT;

		backgroundImage : WMGraphics.Image;

		PROCEDURE &New*(alpha : BOOLEAN);
		VAR pixel : Raster.Pixel;
		BEGIN
			IncCount;
			Init(WindowWidth, WindowHeight, alpha);
			Raster.InitMode(mode, Raster.srcCopy); NEW(timer); NEW(random); random.InitSeed(Kernel.GetTicks());
			Raster.SetRGBA(pixel, 0C0H, 0C0H, 0CCH, 0CCH);
			Raster.Fill(img, 0, 0, WindowWidth, WindowHeight, pixel, mode);
			backgroundImage := WMGraphics.LoadImage("SaasFee.jpg", TRUE);
			IF (backgroundImage # NIL) THEN
				WMRasterScale.Scale(
					backgroundImage, WMRectangles.MakeRect(0, 0, backgroundImage.width, backgroundImage.height),
					img, WMRectangles.MakeRect(0, 0, img.width, img.height),
					WMRectangles.MakeRect(0, 0, img.width, img.height),
					WMRasterScale.ModeCopy, WMRasterScale.ScaleBilinear);
			END;
			(* Game field *)
			Raster.Fill(img, FieldOffsetX, FieldOffsetY, FieldOffsetX + Width*BoxSize, FieldOffsetY + Height*BoxSize, colors[0], mode);
			WMGraphicUtilities.DrawBevel(canvas, WMRectangles.MakeRect(
				FieldOffsetX - BevelBorder, FieldOffsetY - BevelBorder, FieldOffsetX + Width*BoxSize + BevelBorder, FieldOffsetY + Height*BoxSize + BevelBorder),
				2, TRUE, LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy);

			(* Preview panel *)
			Raster.Fill(img, Border, Border, FieldOffsetX - Border, Border + BlockSize*BoxSize, colors[0], mode);
			WMGraphicUtilities.DrawBevel(canvas, WMRectangles.MakeRect(
				Border - BevelBorder, Border - BevelBorder, FieldOffsetX - Border + BevelBorder, Border + BlockSize*BoxSize + BevelBorder),
				2, TRUE, LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy);
			Reset;
			pointerThreshold := 10;
			WM.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("WM Transparent Tetris"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMTetris.png", TRUE));
			state := Initialized;
		END New;

		PROCEDURE SetState(state : LONGINT);
		BEGIN {EXCLUSIVE}
			IF (SELF.state < Terminating) OR (state = Terminated) THEN
				SELF.state := state;
			END;
		END SetState;

		PROCEDURE AwaitState(state : LONGINT);
		BEGIN {EXCLUSIVE}
			AWAIT(SELF.state = state);
		END AwaitState;

		PROCEDURE DrawInfo;
		VAR string : ARRAY 128 OF CHAR; nbr : ARRAY 16 OF CHAR;

			PROCEDURE DrawLine(line : LONGINT; CONST string : ARRAY OF CHAR);
			BEGIN
				ASSERT(line >= 1);
				WMGraphics.DrawStringInRect(canvas,
					WMRectangles.MakeRect(
						InfoOffsetX + Border, InfoOffsetY + Border + (line-1) * InfoLineHeight,
						InfoOffsetX + InfoWidth - Border, InfoOffsetY + Border + line * InfoLineHeight),
					FALSE, WMGraphics.AlignCenter, WMGraphics.AlignTop, string);
			END DrawLine;

		BEGIN
			canvas.Fill(WMRectangles.MakeRect(InfoOffsetX, InfoOffsetY, FieldOffsetX - Border, InfoOffsetY + InfoHeight), LONGINT(0FFFFFFA0H), WMGraphics.ModeCopy);
			WMGraphicUtilities.DrawBevel(canvas, WMRectangles.MakeRect(
				InfoOffsetX - BevelBorder, InfoOffsetY - BevelBorder, FieldOffsetX - Border + BevelBorder, InfoOffsetY + InfoHeight + BevelBorder),
				2, TRUE, LONGINT(0FFFFFFFFH), WMGraphics.ModeCopy);
			canvas.SetColor(WMGraphics.Black);
			IF (state = Running) OR (state = Finished) THEN
				IF (state = Finished) THEN
					DrawLine(1, "Press 'Space'");
					DrawLine(2, "to restart!");
				END;
				(* Number of lines completed *)
				string := "Lines: "; Strings.IntToStr(lines, nbr); Strings.Append(string, nbr);
				DrawLine(3, string);
				(* Number of blocks *)
				string := "Blocks: "; Strings.IntToStr(blocks-1, nbr); Strings.Append(string, nbr);
				DrawLine(4, string);
				(* Level *)
	 			string := "Level: "; Strings.IntToStr(level, nbr); Strings.Append(string, nbr);
				DrawLine(5, string);
				(* Points *)
				string := "Points: "; Strings.IntToStr(points, nbr); Strings.Append(string, nbr);
				DrawLine(6, string);
			ELSIF (state = Initialized) THEN
				DrawLine(1, "Press 'Space'");
				DrawLine(2, "to start!");
			ELSIF (state = Paused) THEN
				DrawLine(1, "Press 'Space'");
				DrawLine(2, "to continue!");
			END;
			Invalidate(WMRectangles.MakeRect(
				InfoOffsetX - BevelBorder, InfoOffsetY - BevelBorder, FieldOffsetX - Border + BevelBorder, InfoOffsetY + InfoHeight + BevelBorder));
		END DrawInfo;

		PROCEDURE StyleChanged;
		BEGIN
			DrawInfo
		END StyleChanged;

		PROCEDURE RotateBlock(CONST block : Block) : Block;
		VAR i, j : INTEGER; temp : Block;
		BEGIN
			FOR i := 0 TO BlockSize - 1 DO FOR j := 0 TO BlockSize - 1 DO temp[j, i] := block[(BlockSize - 1) - i, j] END END;
			RETURN temp
		END RotateBlock;

		PROCEDURE DrawBox(x, y : LONGINT; color : CHAR);
		VAR pix : Raster.Pixel;
		BEGIN
			pix := colors [ORD(color)];
			IF (x >= 0) & (x < Width) & (y >= 0) & (y < Height) THEN
				Raster.Fill(img, FieldOffsetX + x * BoxSize, FieldOffsetY + y * BoxSize,
					FieldOffsetX + x * BoxSize+ BoxSize, FieldOffsetY + y * BoxSize + BoxSize, pix, mode);
				IF (color # 0X) THEN
					WMGraphicUtilities.RectGlassShade(canvas, WMRectangles.MakeRect(
						FieldOffsetX + x * BoxSize, FieldOffsetY + y * BoxSize,
						FieldOffsetX + x * BoxSize+ BoxSize, FieldOffsetY + y * BoxSize + BoxSize), 2, TRUE);
				END;
			END;
		END DrawBox;

		PROCEDURE DrawPreview(CONST block : Block);
		VAR
			i, j : LONGINT;

			PROCEDURE DrawBox(x, y : LONGINT; color : CHAR);
			VAR pix : Raster.Pixel;
			BEGIN
				pix := colors [ORD(color)];
				Raster.Fill(img, Border + x * BoxSize, Border + y * BoxSize,
					Border + x * BoxSize+ BoxSize, Border + y * BoxSize + BoxSize, pix, mode);
				IF (color # 0X) THEN
					WMGraphicUtilities.RectGlassShade(canvas, WMRectangles.MakeRect(
						Border + x * BoxSize, Border + y * BoxSize,
						Border + x * BoxSize+ BoxSize, Border + y * BoxSize + BoxSize), 2, TRUE);
				END;
			END DrawBox;

		BEGIN
			FOR i := 0 TO BlockSize - 1 DO
				FOR j := 0 TO BlockSize - 1 DO
					DrawBox(i, j, block[i, j]);
				END;
			END;
			Invalidate(WMRectangles.MakeRect(Border, Border, Border + BlockSize*BoxSize, Border + BlockSize*BoxSize));
		END DrawPreview;

		PROCEDURE SetBlock(x, y : LONGINT; clear : BOOLEAN);
		VAR i, j : LONGINT;
		BEGIN
			FOR i := 0 TO BlockSize - 1 DO FOR j := 0 TO BlockSize - 1 DO
				IF block[i, j] # 0X THEN
					IF (i + x < Width) & (j + y >= 0) & (j + y < Height) THEN
						IF clear THEN
							field[i + x, j + y] := 0X;
							DrawBox(i + x, j + y, 0X)
						ELSE field[i + x, j + y] := block[i, j];
							DrawBox(i + x, j + y, block[i, j])
						END
					END
				END
			END END
		END SetBlock;

		PROCEDURE HasDownCollision(x, y : LONGINT) : BOOLEAN;
		VAR i, j : LONGINT;
		BEGIN
			FOR i := 0 TO BlockSize - 1 DO FOR j := 0 TO BlockSize - 1 DO
				IF block[i, j] # 0X THEN
					IF (i + x < Width) & (j + y >= 0) THEN
						IF (j + y < Height) THEN
							IF (block[i, j] # 0X) & (field[i + x, j + y] # 0X) THEN RETURN TRUE END
						ELSIF block[i, j] # 0X THEN RETURN TRUE
						END
					ELSE RETURN TRUE
					END
				END
			END END;
			RETURN FALSE
		END HasDownCollision;

		PROCEDURE HasCollision(CONST bl : Block; x, y : LONGINT) : BOOLEAN;
		VAR i, j : LONGINT;
		BEGIN
			FOR i := 0 TO BlockSize - 1 DO FOR j := 0 TO BlockSize - 1 DO
				IF bl[i, j] # 0X THEN
					IF (i + x >= Width) OR (i + x < 0) OR (j + y >= Height) OR (field[i + x, j + y] # 0X) THEN RETURN TRUE END
				END
			END END;
			RETURN FALSE
		END HasCollision;

		PROCEDURE Move(dir : LONGINT) : BOOLEAN;
		VAR newX, newY : LONGINT; result : BOOLEAN;
		BEGIN
			newX := posX; newY := posY;
			IF dir = 0 THEN INC(newX)
			ELSIF dir = 1 THEN DEC(newX)
			ELSIF dir = 2 THEN INC(newY)
			END;

			SetBlock(posX, posY, TRUE);
			IF ~HasCollision(block, newX, newY) THEN posX := newX; posY := newY; result := TRUE
			ELSE result := FALSE
			END;
			SetBlock(posX, posY, FALSE);
			Invalidate(WMRectangles.MakeRect(FieldOffsetX + posX * BoxSize - BoxSize, FieldOffsetY + posY * BoxSize - BoxSize,
				FieldOffsetX + posX * BoxSize + BlockSize * BoxSize + BoxSize,  FieldOffsetY + posY * BoxSize + BlockSize*BoxSize +BoxSize));
			RETURN result
		END Move;

		PROCEDURE KeyEvent(ucs : LONGINT; flags: SET; keysym : LONGINT);
		VAR ignore : BOOLEAN;
			rotBlock : Block;
		BEGIN {EXCLUSIVE}
			IF (state >= Terminating) THEN
				RETURN;
			ELSIF (state = Initialized) THEN
				IF (keysym = 020H) THEN state := Running; END;
			ELSIF (state = Running) THEN
				IF (keysym = 0FF50H) OR (keysym = 0FF51H) THEN (* Move left *)
					ignore := Move(1);
				ELSIF (keysym = 0FF55H)OR (keysym = 0FF53H) THEN (* Move right *)
					ignore := Move(0)
				ELSIF (keysym = 0FF52H) THEN (* Rotate block *)
					SetBlock(posX, posY, TRUE);
					rotBlock := RotateBlock(block);
					IF ~HasCollision(rotBlock, posX, posY) THEN block := rotBlock END;
					SetBlock(posX, posY, FALSE);
					Invalidate(WMRectangles.MakeRect(
						FieldOffsetX + posX * BoxSize - BoxSize, FieldOffsetY + posY * BoxSize - BoxSize,
						FieldOffsetX + posX * BoxSize + BlockSize * BoxSize, FieldOffsetY + posY * BoxSize + BlockSize * BoxSize));
				ELSIF (keysym = 0FF54H) OR (keysym = 0FF0DH) OR (keysym = 20H) THEN (* Drop block *)
					dropped := TRUE;
				ELSIF (keysym = 070H) THEN (* p key *)
					state := Paused;
				END;
			ELSIF (state = Finished) THEN
				IF (keysym = 020H) THEN state := Restarting; END;
			ELSIF (state = Paused) THEN
				IF (keysym = 020H) OR (keysym = 070H)  THEN state := Running; END;
			END;
		END KeyEvent;

		PROCEDURE NewBlock() : Block;
		VAR
			newBlock : Block;
			i, j : LONGINT; kind : LONGINT;
			color : CHAR;

			PROCEDURE Set(x, y : LONGINT);
			BEGIN
				newBlock[x, y] := color
			END Set;

		BEGIN
			dropped := FALSE;
			posX := Width DIV 2 - 1; posY := 0;

			FOR i := 0 TO BlockSize - 1 DO FOR j := 0 TO BlockSize - 1 DO newBlock [i, j] := 0X END END;
			kind := random.Integer() MOD NofBlocks;

			color := CHR(1 + kind);

			CASE kind OF
				| 0 : Set(0, 2); Set(1, 2); Set(2, 2); Set(3, 2)
				| 1 : Set(1, 3); Set(2, 3); Set(3, 3); Set(2, 2)
				| 2 : Set(1, 1); Set(1, 2); Set(2, 2); Set(2, 3)
				| 3 : Set(2, 1); Set(1, 2); Set(2, 2); Set(1, 3)
				| 4 : Set(2, 1); Set(2, 2); Set(2, 3); Set(3, 3)
				| 5 : Set(2, 1); Set(2, 2); Set(2, 3); Set(1, 3)
				| 6 : Set(1, 1); Set(1, 2); Set(2, 1); Set(2, 2)
			END;
			INC(blocks);
			DrawPreview(newBlock);
			RETURN newBlock;
		END NewBlock;

		PROCEDURE RemoveLine(y : LONGINT);
		VAR i, j : LONGINT; oldLevel : LONGINT;
		BEGIN
			FOR i := 0 TO Width - 1 DO
				FOR j := y TO 1 BY - 1 DO
					field[i, j] := field[i, j - 1];
					DrawBox(i, j, field[i, j])
				END;
				field[i, 0] := 0X;
				DrawBox(i, 0, 0X)
			END;
			Invalidate(WMRectangles.MakeRect(FieldOffsetX, FieldOffsetY, FieldOffsetX + Width * BoxSize, FieldOffsetY + y * BoxSize + BoxSize));
			INC(lines);
			timer.Sleep(200);
			oldLevel := level;
			level := lines DIV LinesToLevelRatio;
			IF (oldLevel < level) & (delay > 10) THEN
				points := points + LevelUpBonus;
				DEC(delay, delayDec);
				IF delayDec >= 10 THEN delayDec := delayDec DIV 2 END
			END;
		END RemoveLine;

		PROCEDURE ClearLines;
		VAR y, x, c : LONGINT; linesRemoved : LONGINT; color : CHAR; sameColor : BOOLEAN;
		BEGIN
			linesRemoved := 0;
			y := Height - 1;
			WHILE y > 0 DO
				sameColor := TRUE; color := field[0, y];
				c := 0;
				FOR x := 0 TO Width - 1 DO
					IF field[x, y] # 0X THEN
						IF (field[x, y] # color) THEN
							sameColor := FALSE;
						END;
						INC(c);
					END;
				END;
				IF c = Width THEN
					RemoveLine(y);
					INC(linesRemoved);
					IF sameColor THEN points := points + SameColorBonus; END;
				ELSE
					DEC(y);
				END;
			END;
			IF (linesRemoved > 0) THEN
				points := points + linesRemoved;
				IF (linesRemoved = 2) THEN
					points := points + TwoLinesBonus;
				ELSIF (linesRemoved = 3) THEN
					points := points + ThreeLinesBonus;
				ELSIF (linesRemoved = 4) THEN
					points := points + FourLinesBonus;
				END;
			END;
		END ClearLines;

		PROCEDURE DropStep;
		VAR needNew : BOOLEAN;
		BEGIN {EXCLUSIVE}
			SetBlock(posX, posY, TRUE);
			IF ~HasDownCollision(posX, posY +1) THEN INC(posY); needNew := FALSE ELSE needNew := TRUE END;
			SetBlock(posX, posY, FALSE);
			Invalidate(WMRectangles.MakeRect(
				FieldOffsetX + posX * BoxSize - BoxSize, FieldOffsetY + posY * BoxSize - BoxSize,
				FieldOffsetX + posX * BoxSize + BlockSize * BoxSize, FieldOffsetY + posY * BoxSize + BlockSize*BoxSize));
			IF needNew THEN
				ClearLines;
				block := nextBlock;
				nextBlock := NewBlock();
				IF HasCollision(block, posX, posY) THEN
					state := Finished;
					WMDialogs.Information("Game Over", "You have lost the game");
				END;
			END;
		END DropStep;

		PROCEDURE Reset;
		VAR x,y : LONGINT;
		BEGIN
			FOR x := 0 TO Width-1 DO
				FOR y := 0 TO Height-1 DO
					field[x,y] := 0X
				END
			END;
			blocks := 0; lines := 0; points := 0; level := 0;
			delay :=150; delayDec := 30;
			Raster.Fill(img, FieldOffsetX, FieldOffsetY, FieldOffsetX + Width*BoxSize, FieldOffsetY + Height*BoxSize, colors[0], mode);
			Invalidate(WMRectangles.MakeRect(FieldOffsetX, FieldOffsetY, FieldOffsetX + Width*BoxSize, FieldOffsetY + Height*BoxSize));
		END Reset;

		PROCEDURE Close;
		BEGIN
			SetState(Terminating);
			timer.Wakeup;
			AwaitState(Terminated);
			Close^;
			DecCount;
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN
				Close;
			ELSE Handle^(x)
			END
		END Handle;

	BEGIN {ACTIVE}
		generateNewBlock := TRUE;
		block := NewBlock();
		nextBlock := NewBlock();
		LOOP
			DrawInfo;
			BEGIN {EXCLUSIVE} AWAIT((state = Running) OR (state = Restarting) OR (state = Terminating)); END;
			IF (state = Terminating) THEN
				EXIT;
			ELSIF (state = Restarting) THEN
				SetState(Running);
				Reset;
				block := NewBlock();
				nextBlock := NewBlock();
			ELSE
				IF ~dropped THEN timer.Sleep(delay) END;
				IF RandomDrop THEN
					CASE random.Dice(3) OF
						| 0 : IF Move(0) THEN END;
						| 1 : IF Move(1) THEN END;
						| 2 : SetBlock(posX, posY, TRUE);
							 rotBlock := RotateBlock(block);
							 IF ~HasCollision(rotBlock, posX, posY) THEN block := rotBlock END;
							 SetBlock(posX, posY, FALSE);
							 Invalidate(WMRectangles.MakeRect(
							 	FieldOffsetX + posX * BoxSize - BoxSize, FieldOffsetY + posY * BoxSize - BoxSize,
							 	FieldOffsetX + posX * BoxSize + BlockSize * BoxSize, FieldOffsetY + posY * BoxSize + BlockSize * BoxSize));
					END;
				END;
				DropStep;
			END;
		END;
		SetState(Terminated);
	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE Open*;
VAR winstance : Window;
BEGIN
	NEW(winstance, TRUE);
END Open;

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
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	Raster.SetRGBA(colors[0], 0, 0, 0, 0);
	Raster.SetRGBA(colors[1], 255, 0, 0, 128);
	Raster.SetRGBA(colors[2], 0, 255, 0, 128);
	Raster.SetRGBA(colors[3], 0, 0, 255, 128);
	Raster.SetRGBA(colors[4], 200, 200, 0, 200);
	Raster.SetRGBA(colors[5], 255, 0, 255, 128);
	Raster.SetRGBA(colors[6], 0, 255, 255, 200);
	Raster.SetRGBA(colors[7], 256, 128, 100, 200);
	Modules.InstallTermHandler(Cleanup)
END WMTetris.

SystemTools.Free WMTetris ~
WMTetris.Open ~