MODULE RaycasterMaze; (** AUTHOR "SAGE"; PURPOSE "Wolfenstein 3D like raycasting game engine with maze generator"; *)

(*
Raycasting game engine tutorial:
	http://www.student.kuleuven.be/~m0216922/CG/raycasting.html
	http://www.student.kuleuven.be/~m0216922/CG/raycasting2.html
	http://www.student.kuleuven.be/~m0216922/CG/raycasting3.html
Maze generation tutorial:
	http://www.mazeworks.com/mazegen/mazetut/index.htm
*)

IMPORT
	SYSTEM, PreciseTimer, Modules, Inputs, Strings (*:= Utilities*), Commands, Raster,
	WM := WMWindowManager, Rectangles := WMRectangles,
	Math := Math, Graphics := WMGraphics, Random;
	
CONST

	DATA_FILE = "WMRaycasterData.zip";
	DATA_PATH = "hqtex/";

	INIT_SEED = FALSE;

	CELLS_X = 9;
	CELLS_Y = 9;
	MAP_WIDTH = CELLS_X * 2 + 1;
	MAP_HEIGHT = CELLS_Y * 2 + 1;
	CELLS_TOTAL = CELLS_X * CELLS_Y;
	MAP_DRAW_START_X = 10;
	MAP_DRAW_START_Y = 20;
	MAP_SCALE = 60;
	
	SCREEN_WIDTH = 480;
	SCREEN_HEIGHT = 360;
		
	ceilingTexture = 1;
	floorTexture = 2;

TYPE

	MouseObj = OBJECT(Inputs.Sink)
	VAR
		threshold, speedup: LONGINT;
		(*x, y, z: LONGINT;*)
		bFirst: BOOLEAN;
		
		PROCEDURE &Init*(t, s: LONGINT);
		BEGIN
			bFirst := TRUE;
			Inputs.mouse.Register(SELF);
			threshold := t; speedup := s
		END Init;
		
		PROCEDURE Handle(VAR msg: Inputs.Message);
		VAR dx, dy, dz: LONGINT;
		BEGIN {EXCLUSIVE}
			IF (msg IS Inputs.MouseMsg) OR (msg IS Inputs.AbsMouseMsg) THEN
				IF msg IS Inputs.MouseMsg THEN
					WITH msg: Inputs.MouseMsg DO
						dx := msg.dx; dy := msg.dy; dz := msg.dz
					END
				(*ELSIF msg IS Inputs.AbsMouseMsg THEN
					WITH msg: Inputs.AbsMouseMsg DO
						IF bFirst THEN
							bFirst := FALSE;
							x := msg.x;  y := msg.y;  z := msg.z;
							dx := 0; dy := 0; dz := 0
						ELSE
							(*dx := x - msg.x; x := msg.x;
							dy := y - msg.y; y := msg.y;
							dz := z - msg.z; z := msg.z*)
							IF msg.dx # 0 THEN dx := x - msg.dx; x := msg.dx ELSE dx := msg.x - x; x := msg.x END;
							IF msg.dy # 0 THEN dy := y - msg.dy; y := msg.dy  ELSE dy := msg.y - y; y := msg.y END;
							IF msg.dz # 0 THEN dz := msg.dz  ELSE dz := msg.z - z; z := msg.z END
						END
					END*)
				END;
				IF (ABS(dx) > threshold) OR (ABS(dy) > threshold) THEN
					dx := dx * speedup DIV 10; dy := dy * speedup DIV 10
				END;
				IF dx # 0 THEN
					instance.Rotate(-dx)
				END;
				IF dy # 0 THEN
					instance.Move(-dy)
				END
			END
		END Handle;
		
	END MouseObj;
	

	FPSCounter = OBJECT
	VAR
		nCount, nMaxMeasuresCount: LONGINT;
		fTimeAverage, fTimeAverageOld, fFPSAverage: REAL;
		
	PROCEDURE &New(nMaxMeasuresCount: LONGINT);
	BEGIN
		SELF.nMaxMeasuresCount := nMaxMeasuresCount;
		nCount := 0;
		fTimeAverage := 0.0;
		fTimeAverageOld := 0.0;
	END New;
	
	PROCEDURE AddTimeMeasure(fTime: REAL);
	BEGIN
		INC(nCount);
		fTimeAverageOld := fTimeAverage;
		IF nCount > nMaxMeasuresCount THEN nCount := ENTIER(nMaxMeasuresCount * 0.9) END;
		fTimeAverage := (fTimeAverageOld * (nCount - 1) + fTime) / nCount;
		fFPSAverage := 1 / fTimeAverage;
		fFPSAverage := ENTIER(fFPSAverage * 10 + 0.5) / 10;
	END AddTimeMeasure;
	
	PROCEDURE GetAverageFrameTime(): REAL;
	BEGIN
		RETURN fTimeAverage
	END GetAverageFrameTime;
	
	PROCEDURE GetAverageFPS(): REAL;
	BEGIN
		RETURN fFPSAverage
	END GetAverageFPS;
	
	END FPSCounter;

	RaycasterWindow* = OBJECT(WM.BufferWindow)
	VAR
		alpha, bShowMap: BOOLEAN;
		font: Graphics.Font;
		
	PROCEDURE &New(alpha: BOOLEAN);
	BEGIN
		SELF.alpha:=alpha;
		bShowMap := FALSE;
		Init(SCREEN_WIDTH, SCREEN_HEIGHT, alpha);
		WM.DefaultAddWindow(SELF);
		SetTitle(Strings.NewString("Textured raycaster with floor and ceiling"));
		canvas.SetColor(Graphics.White);
		font := canvas.GetFont();
		Frame;
	END New;
	
	PROCEDURE Draw(canvas: Graphics.Canvas; w, h, q: LONGINT);
	VAR
		str: ARRAY 30 OF CHAR;
		font: Graphics.Font;
		textWidth, textHeight: LONGINT;
	BEGIN
		Draw^(canvas, w, h, q);
		canvas.SetColor(Graphics.White);
		font := canvas.GetFont();
		Strings.FloatToStr(fpsCounter.GetAverageFPS(), 0, 1, 0, str);
		Strings.Concat("FPS:", str, str);
		font.GetStringSize(str, textWidth, textHeight);
		canvas.DrawString(4, textHeight + 4, str);
	END Draw;
	
	PROCEDURE Frame;
	VAR
		cameraX, (** x-coordinate in camera space *)
		rayPosX, rayPosY, rayDirX, rayDirY,
		sideDistX, sideDistY, (** length of ray from current position to next x or y-side *)
		deltaDistX, deltaDistY,
		perpWallDist,
		wallX, (** where exactly the wall was hit *)
		floorXWall, floorYWall, (** x, y position of the floor texel at the bottom of the wall *)
		distPlayer, weight,
		currentFloorX, currentFloorY, rayDirX2, rayDirY2: REAL;
		mapX, mapY,
		stepX, stepY, (** what direction to step in x or y-direction (either +1 or -1) *)
		lineHeight, texNum, texX, d: LONGINT;
		side: LONGINT; (** was a NS or a EW wall hit? *)
		x, y, drawStart, drawEnd, tileX, tileY: LONGINT;
		mode: Raster.Mode;
		texWidth, texHeight,
		floorTexWidth, floorTexHeight,
		ceilingTexWidth, ceilingTexHeight,
		pixelOffset, floorPixelOffset, ceilingPixelOffset: LONGINT;
		t: HUGEINT;
		rect: Rectangles.Rectangle;
		
	BEGIN
	
		t := PreciseTimer.GetTicks();
		
		rayPosX := posX;
		rayPosY := posY;
		
		distPlayer := 0.0;
		
		floorTexWidth := textures[floorTexture].width;
		floorTexHeight := textures[floorTexture].height;
		ceilingTexWidth := textures[ceilingTexture].width;
		ceilingTexHeight := textures[ceilingTexture].height;
		
		FOR x := 0 TO SCREEN_WIDTH - 1 DO
		
			(** calculate ray position and direction *)
			cameraX := 2 * x / SCREEN_WIDTH - 1;
			rayDirX := dirX + planeX * cameraX;
			rayDirY := dirY + planeY * cameraX;
			
			(** which box of the map we're in *)
			mapX := ENTIER(rayPosX);
			mapY := ENTIER(rayPosY);

			(** length of ray from one x or y-side to next x or y-side *)
			rayDirX2 := rayDirX * rayDirX;
			rayDirY2 := rayDirY * rayDirY;
			deltaDistX := Math.sqrt(1 + rayDirY2 / rayDirX2);
			deltaDistY := Math.sqrt(1 + rayDirX2 / rayDirY2);
			       			
			(** calculate step and initial sideDist *)
			IF rayDirX < 0 THEN
				stepX := -1;
				sideDistX := (rayPosX - mapX) * deltaDistX
			ELSE
				stepX := 1;
				sideDistX := (mapX + 1.0 - rayPosX) * deltaDistX
			END;
			IF rayDirY < 0 THEN
				stepY := -1;
				sideDistY := (rayPosY - mapY) * deltaDistY
			ELSE
				stepY := 1;
				sideDistY := (mapY + 1.0 - rayPosY) * deltaDistY
			END;
			
			(** perform DDA *)
			(** Check if ray has hit a wall *)
			REPEAT
				(** jump to next map square, OR in x-direction, OR in y-direction *)
				IF sideDistX < sideDistY THEN
					sideDistX := sideDistX + deltaDistX;
					INC(mapX, stepX);
					side := 0
				ELSE
					sideDistY := sideDistY + deltaDistY;
					INC(mapY, stepY);
					side := 1
				END
			UNTIL worldMap[mapX][mapY] > 0;
			
			(** Calculate distance of perpendicular ray (calculate distance projected on camera direction) (oblique distance will give fisheye effect!) *)
			(** calculate value of wallX *)
			IF side = 0 THEN
				perpWallDist := (mapX - rayPosX + (1 - stepX) / 2) / rayDirX;
				wallX := rayPosY + perpWallDist * rayDirY
			ELSE
				perpWallDist := (mapY - rayPosY + (1 - stepY) / 2) / rayDirY;
				wallX := rayPosX + perpWallDist * rayDirX
			END;
			perpWallDist := ABS(perpWallDist);
			wallX := wallX - ENTIER(wallX);
			      
			(** Calculate height of line to draw on screen *)
			lineHeight := ENTIER(SCREEN_HEIGHT / perpWallDist);
			
			(** calculate lowest and highest pixel to fill in current stripe *)
			drawStart := -lineHeight DIV 2 + SCREEN_HEIGHT DIV 2;
			IF drawStart < 0 THEN drawStart := 0 END;
			drawEnd := lineHeight DIV 2 + SCREEN_HEIGHT DIV 2 - 1;
			IF drawEnd >= SCREEN_HEIGHT THEN drawEnd := SCREEN_HEIGHT - 1 END;
			
			(** texturing calculations *)
			texNum := worldMap[mapX][mapY] - 1; (** 1 subtracted from it so that texture 0 can be used! *)
			texWidth := textures[texNum].width;
			texHeight := textures[texNum].height;
			       
			(** x coordinate on the texture *)
			texX := ENTIER(wallX * texWidth);
			IF ((side = 0) & (rayDirX > 0)) OR ((side = 1) & (rayDirY < 0)) THEN
				texX := texWidth - texX - 1
			END;
			
			d := -SCREEN_HEIGHT DIV 2 + lineHeight DIV 2;
			pixelOffset := SCREEN_WIDTH * 4 * drawStart + x * 4;
			FOR y := drawStart TO drawEnd DO
				
				(* This code leads to error on perpWallDist values close to 0.0 *)
				(*d := y * 256 - SCREEN_HEIGHT * 128 + lineHeight * 128;  (** 256 and 128 factors to avoid floats *)
				texY := ((d * texHeight) DIV lineHeight) DIV 256;*)
				
				(*texY := ((y - SCREEN_HEIGHT DIV 2 + lineHeight DIV 2) * texHeight) DIV lineHeight;*)
				
				(*texY := ((y + d) * texHeight) DIV lineHeight;*)
				
				(** make color darker for y-sides: R, G and B byte each divided through two with a "shift" and an "and" *)
				IF side = 1 THEN
					SYSTEM.PUT32(ADDRESSOF(bufferPixels[pixelOffset]),
						SYSTEM.VAL(LONGINT, textures[texNum].pixelsDark[texWidth * (((y + d) * texHeight) DIV lineHeight) + texX]))
				ELSE
					SYSTEM.PUT32(ADDRESSOF(bufferPixels[pixelOffset]),
						SYSTEM.VAL(LONGINT, textures[texNum].pixels[texWidth * (((y + d) * texHeight) DIV lineHeight) + texX]))
				END;
				INC(pixelOffset, SCREEN_WIDTH * 4)

				(*bufferPixels[pixelOffset + Raster.b] := pixel[Raster.b];
				bufferPixels[pixelOffset + Raster.g] := pixel[Raster.g];
				bufferPixels[pixelOffset + Raster.r] := pixel[Raster.r];
				bufferPixels[pixelOffset + Raster.a] := pixel[Raster.a]*)
				
			END;
			
			(** FLOOR CASTING *)
			      
			(** 4 different wall directions possible *)
			IF (side = 0) & (rayDirX > 0) THEN
				floorXWall := mapX;
				floorYWall := mapY + wallX
			ELSIF (side = 0) & (rayDirX < 0) THEN
				floorXWall := mapX + 1.0;
				floorYWall := mapY + wallX
			ELSIF(side = 1) & (rayDirY > 0) THEN
				floorXWall := mapX + wallX;
				floorYWall := mapY
			ELSE
				floorXWall := mapX + wallX;
				floorYWall := mapY + 1.0
			END;
      
			(*IF (drawEnd < 0) THEN drawEnd := h END;*) (** becomes < 0 when the integer overflows *)
		      
			(** draw the floor from drawEnd to the bottom of the screen *)
			floorPixelOffset := SCREEN_WIDTH * 4 * (drawEnd + 1) + x * 4;
			ceilingPixelOffset := SCREEN_WIDTH * 4 * (SCREEN_HEIGHT - drawEnd - 2) + x * 4;
			FOR y := drawEnd + 1 TO SCREEN_HEIGHT - 1 DO
				(*currentDist := SCREEN_HEIGHT / (2.0 * y - SCREEN_HEIGHT);*) 
				weight := (currentDistLookUp[y] - distPlayer) / (perpWallDist - distPlayer);
				currentFloorX := weight * floorXWall + (1.0 - weight) * posX;
				currentFloorY := weight * floorYWall + (1.0 - weight) * posY;
				
				(** floor *)
				(*floorTexX := (ENTIER(currentFloorX * floorTexWidth) MOD floorTexWidth);
				floorTexY := (ENTIER(currentFloorY * floorTexHeight) MOD floorTexHeight);
				pixel := textures[floorTexture].pixelsDark[floorTexWidth * floorTexY + floorTexX];
				bufferPixels[pixelOffset + Raster.b] := pixel[Raster.b];
				bufferPixels[pixelOffset + Raster.g] := pixel[Raster.g];
				bufferPixels[pixelOffset + Raster.r] := pixel[Raster.r];
				bufferPixels[pixelOffset + Raster.a] := pixel[Raster.a];*)
				SYSTEM.PUT32(ADDRESSOF(bufferPixels[floorPixelOffset]),
					SYSTEM.VAL(LONGINT, textures[floorTexture].pixelsDark[floorTexWidth * (ENTIER(currentFloorY * floorTexHeight) MOD floorTexHeight) +
						(ENTIER(currentFloorX * floorTexWidth) MOD floorTexWidth)]));
				INC(floorPixelOffset, SCREEN_WIDTH * 4);
				
				(** ceiling (symmetrical!) *)
				(*ceilingTexX := (ENTIER(currentFloorX * ceilingTexWidth) MOD ceilingTexWidth);
				ceilingTexY := (ENTIER(currentFloorY * ceilingTexHeight) MOD ceilingTexHeight);
				pixel := textures[ceilingTexture].pixels[ceilingTexWidth * ceilingTexY + ceilingTexX];
				bufferPixels[pixelOffset + Raster.b] := pixel[Raster.b];
				bufferPixels[pixelOffset + Raster.g] := pixel[Raster.g];
				bufferPixels[pixelOffset + Raster.r] := pixel[Raster.r];
				bufferPixels[pixelOffset + Raster.a] := pixel[Raster.a];*)
				SYSTEM.PUT32(ADDRESSOF(bufferPixels[ceilingPixelOffset]),
					SYSTEM.VAL(LONGINT, textures[ceilingTexture].pixels[ceilingTexWidth * (ENTIER(currentFloorY * ceilingTexHeight) MOD ceilingTexHeight) +
						(ENTIER(currentFloorX * ceilingTexWidth) MOD ceilingTexWidth)]));
				DEC(ceilingPixelOffset, SCREEN_WIDTH * 4)
			END
		END;
		
		Raster.InitMode(mode, Raster.srcCopy);
		
		IF bShowMap THEN
			(* Draw maze *)
			FOR y := 0 TO LevelMapHeight - 1 DO
				BlendSrcOverDst(bufferLevelMapPixels^, bufferPixels^, y * LevelMapWidth * 4,
					(y + MAP_DRAW_START_Y) * SCREEN_WIDTH * 4 + MAP_DRAW_START_X * 4, LevelMapWidth)
			END;
			(* Draw player *)
			tileX := levelMapCellWidth * (ENTIER(rayPosX) - 1) + MAP_DRAW_START_X + 1;
			tileY := levelMapCellWidth * (MAP_HEIGHT - ENTIER(rayPosY) - 2) + MAP_DRAW_START_Y + 1;
			FOR y := 0 TO levelMapCellWidth - 1 DO
				BlendSrcOverDst(bufferPlayerPixels^, bufferPixels^, y * levelMapCellWidth * 4,
					(y + tileY) * SCREEN_WIDTH * 4 + tileX * 4, levelMapCellWidth)
			END
		END;
		
		FOR y := 0 TO SCREEN_HEIGHT - 1 DO
			Raster.PutPixels(img, 0, y, SCREEN_WIDTH, Raster.BGRA8888, bufferPixels^, y * SCREEN_WIDTH * 4, mode)
		END;
		(*PutPixels(img, 0, 0, SCREEN_WIDTH, Raster.BGRA8888, bufferPixels^, 0, mode);*)

		rect := Rectangles.MakeRect(0, 0, GetWidth(), GetHeight());
		Rectangles.MoveRel(rect, bounds.l, bounds.t);
		Rectangles.ClipRect(rect, bounds);
		manager.AddDirty(rect);
		
		fpsCounter.AddTimeMeasure(PreciseTimer.GetTime(PreciseTimer.GetTicks() - t));
		
		moveSpeed := fpsCounter.GetAverageFrameTime() * 4.5;
		rotSpeed := fpsCounter.GetAverageFrameTime() * 2.0;
		
	END Frame;
			
	PROCEDURE Close;
	BEGIN
		Close^;
		instance := NIL;
		UnInstallMessageHandler
	END Close;
	
	PROCEDURE Rotate(dx: LONGINT);
	VAR
		fAngle, fSin, fCos: REAL;
		oldDirX, oldPlaneX: REAL;
	BEGIN
		IF dx # 0 THEN
			fAngle := dx * rotSpeed;
			fSin := Math.sin(fAngle);
			fCos := Math.cos(fAngle);
			oldDirX := dirX;
			dirX := dirX * fCos - dirY * fSin;
			dirY := oldDirX * fSin + dirY * fCos;
			oldPlaneX := planeX;
			planeX := planeX * fCos - planeY * fSin;
			planeY := oldPlaneX * fSin + planeY * fCos;
			Frame
		END
	END Rotate;
	
	PROCEDURE Move(dy: LONGINT);
	VAR
		fDist: REAL;
		x, y: LONGINT;
	BEGIN
		fDist := dy * moveSpeed;
		x := ENTIER(posX + dirX * fDist);
		y := ENTIER(posY);
		IF (x >= 0) & (x < MAP_WIDTH) & (y >= 0) & (y < MAP_HEIGHT) & (worldMap[x][y] = 0) THEN
			posX := posX + dirX * fDist
		END;
		x := ENTIER(posX);
		y := ENTIER(posY + dirY * fDist);
		IF (x >= 0) & (x < MAP_WIDTH) & (y >= 0) & (y < MAP_HEIGHT) & (worldMap[x][y] = 0) THEN
			posY := posY + dirY * fDist
		END;
		Frame
	END Move;

	PROCEDURE KeyEvent(ucs: LONGINT; flags: SET; keysym: LONGINT);
	BEGIN
		IF keysym = Inputs.KsLeft THEN
			Rotate(1)
		ELSIF keysym = Inputs.KsUp THEN
			IF flags * Inputs.Shift # {} THEN
				(** Run *)
				Move(2)
			ELSE
				Move(1)
			END
		ELSIF keysym = Inputs.KsRight THEN
			Rotate(-1)
		ELSIF keysym = Inputs.KsDown THEN
				Move(-1)
		ELSIF keysym = Inputs.KsTab THEN
			bShowMap := ~bShowMap;
			Frame
		ELSIF keysym = Inputs.KsEscape THEN
			Close
		ELSE
		END
	END KeyEvent;
		
	END RaycasterWindow;
	
	(*TTexture = ARRAY texWidth * texHeight OF Raster.Pixel;*)
	TTexture = RECORD
		width, height: LONGINT;
		pixels: POINTER TO ARRAY OF Raster.Pixel;
		pixelsDark: POINTER TO ARRAY OF Raster.Pixel;
	END;
	
VAR

	mouse: MouseObj;

	worldMap: ARRAY MAP_WIDTH, MAP_HEIGHT OF SHORTINT;
	(*worldMap: ARRAY MAP_HEIGHT OF ARRAY MAP_WIDTH OF SHORTINT;*)
	stack: ARRAY CELLS_TOTAL OF
		RECORD
			x, y: INTEGER
		END;
	stackTop, cellsVisited: INTEGER;
	random: Random.Generator;

	textures: ARRAY 8 OF TTexture;
	
	currentDistLookUp: ARRAY SCREEN_HEIGHT OF REAL;
	
	bufferPixels, bufferLevelMapPixels, bufferPlayerPixels: POINTER TO ARRAY OF CHAR;
	
	LevelMapWidth, LevelMapHeight, levelMapCellWidth: LONGINT;

	instance: RaycasterWindow;
	posX, posY: REAL;  (** x and y start position *)
	dirX, dirY: REAL; (** initial direction vector *)
	planeX, planeY: REAL; (** the 2d raycaster version of camera plane *)
	moveSpeed, (** the constant value is in squares/second *)
	rotSpeed: REAL; (** the constant value is in radians/second *)
	
	fpsCounter: FPSCounter;
	
	(*manager: WM.WindowManager;*)
	
	(*oldX, oldY: LONGINT;
	bFirstMsg: BOOLEAN;*)

PROCEDURE BlendSrcOverDst(CONST src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR; srcOffSet, dstOffSet, w: LONGINT);
VAR
	fs, fd, i: LONGINT;
BEGIN
	fs := 255;
	FOR i := 0 TO w - 1 DO
		fd := 255 - ORD(src[srcOffSet + Raster.a]);
		IF fd = 0 THEN
			SYSTEM.PUT32(ADDRESSOF(dst[dstOffSet]),
				SYSTEM.VAL(LONGINT, src[srcOffSet]))
		ELSIF fd # 255 THEN
			dst[dstOffSet] := Raster.Clamp[200H + (fs * ORD(src[srcOffSet]) + fd * ORD(dst[dstOffSet])) DIV 255];
			dst[dstOffSet + 1] := Raster.Clamp[200H + (fs * ORD(src[srcOffSet + 1]) + fd * ORD(dst[dstOffSet + 1])) DIV 255];
			dst[dstOffSet + 2] := Raster.Clamp[200H + (fs * ORD(src[srcOffSet + 2]) + fd * ORD(dst[dstOffSet + 2])) DIV 255];
			dst[dstOffSet + 3] := Raster.Clamp[200H + (fs * ORD(src[srcOffSet + 3]) + fd * ORD(dst[dstOffSet + 3])) DIV 255]
		END;
		INC(srcOffSet, 4);
		INC(dstOffSet, 4)
	END
END BlendSrcOverDst;
	
PROCEDURE LoadTexture(CONST strPath, strName: ARRAY OF CHAR; VAR tex: TTexture): BOOLEAN;
VAR
	image: Graphics.Image;
	bResult: BOOLEAN;
	mode: Raster.Mode;
	x, y, offset: LONGINT;
	pixel: Raster.Pixel;
	strFullPath: ARRAY 256 OF CHAR;
BEGIN
	bResult := FALSE;
	Strings.Concat(strPath, strName, strFullPath);
	image := Graphics.LoadImage(strFullPath, FALSE);
	IF image # NIL THEN
		bResult := TRUE;
		tex.width := image.width;
		tex.height := image.height;
		NEW(tex.pixels, image.width * image.height);
		NEW(tex.pixelsDark, image.width * image.height);
		Raster.InitMode(mode, Raster.srcCopy);
		FOR x := 0 TO tex.width - 1 DO
			FOR y := 0 TO tex.height - 1 DO
				Raster.Get(image, x, y, pixel, mode);
				offset := tex.width * y + x;
				tex.pixels[offset] := pixel;
				tex.pixelsDark[offset][Raster.b] :=  CHR(ORD(pixel[Raster.b]) DIV 2);
				tex.pixelsDark[offset][Raster.g] :=  CHR(ORD(pixel[Raster.g]) DIV 2);
				tex.pixelsDark[offset][Raster.r] :=  CHR(ORD(pixel[Raster.r]) DIV 2);
				tex.pixelsDark[offset][Raster.a] :=  pixel[Raster.a]
			END
		END
	END;
	RETURN bResult
END LoadTexture;

PROCEDURE mapClear;
VAR
	x, y: INTEGER;
BEGIN
	FOR y := 0 TO MAP_HEIGHT - 1 DO
		FOR x := 0 TO MAP_WIDTH - 1 DO
			IF (x MOD 2 = 1) & (y MOD 2 = 1) THEN
				worldMap[x, y] := -1
			ELSE
				worldMap[x, y] := 1
			END
		END
	END	
END mapClear;

PROCEDURE paintMaze;
VAR
	x, y, ny, tileX, tileY, x2, y2: LONGINT;
	pixelWall, pixelFloor: Raster.Pixel;
	bTop, bBottom, bLeft, bRight: BOOLEAN;
BEGIN
	pixelWall[Raster.r] := 080X;	pixelWall[Raster.g] := 050X;	pixelWall[Raster.b] := 0X;	pixelWall[Raster.a] := 020X;
	pixelFloor[Raster.r] := 0X;		pixelFloor[Raster.g] := 0X;		pixelFloor[Raster.b] := 0X;		pixelFloor[Raster.a] := 0X;
	(* draw border *)
	FOR y := 0 TO LevelMapHeight - 1 DO
		FOR x := 0 TO LevelMapWidth - 1 DO
			IF (x = 0) OR (x = LevelMapWidth - 1) OR (y = 0) OR (y = LevelMapHeight - 1) THEN
				SYSTEM.PUT32(ADDRESSOF(bufferLevelMapPixels[LevelMapWidth * 4 * y + 4 * x]),
					SYSTEM.VAL(LONGINT, pixelWall))
			ELSE
				SYSTEM.PUT32(ADDRESSOF(bufferLevelMapPixels[LevelMapWidth * 4 * y + 4 * x]),
					SYSTEM.VAL(LONGINT, pixelFloor))
			END
		END
	END;
	tileY := 1;
	FOR y := 1 TO MAP_HEIGHT - 2 DO
		ny := MAP_HEIGHT - y - 1;
		tileX := 1;
		FOR x := 1 TO MAP_WIDTH - 2 DO
			IF worldMap[x, ny] > 0 THEN
				bTop := (ny + 1 <= MAP_HEIGHT - 2) & (worldMap[x, ny + 1] = 0);
				bBottom := (ny - 1 >= 1) & (worldMap[x, ny - 1] = 0);
				bLeft := (x - 1 >= 1) & (worldMap[x - 1, ny] = 0);
				bRight := (x + 1 <= MAP_WIDTH - 2) & (worldMap[x + 1, ny] = 0);
				FOR y2 := 0 TO levelMapCellWidth - 1 DO
					FOR x2 := 0 TO levelMapCellWidth - 1 DO
						IF ((x2 = 0) & bLeft) OR ((y2 = 0) & bTop) OR
							((x2 = levelMapCellWidth - 1) & bRight) OR ((y2 = levelMapCellWidth - 1) & bBottom) OR
							((x2 + y2) MOD 5 = 0)
						THEN
							SYSTEM.PUT32(ADDRESSOF(bufferLevelMapPixels[LevelMapWidth * 4 * (tileY + y2) + 4 * (tileX + x2)]),
								SYSTEM.VAL(LONGINT, pixelWall))
						END
					END
				END
			END;
			INC(tileX, levelMapCellWidth)
		END;
		INC(tileY, levelMapCellWidth)
	END
END paintMaze;

PROCEDURE paintPlayer;
VAR
	x, y: LONGINT;
	pixelPlayer: Raster.Pixel;
BEGIN
	pixelPlayer[Raster.r] := 0X;		pixelPlayer[Raster.g] := 0AAX;		pixelPlayer[Raster.b] := 055X;		pixelPlayer[Raster.a] := 050X;
	FOR y := 0 TO levelMapCellWidth - 1 DO
		FOR x := 0 TO levelMapCellWidth - 1 DO
			SYSTEM.PUT32(ADDRESSOF(bufferPlayerPixels[levelMapCellWidth * 4 * y + 4 * x]),
				SYSTEM.VAL(LONGINT, pixelPlayer))
		END
	END
END paintPlayer;

PROCEDURE generateMaze;
VAR
	curX, curY, neighborDir: INTEGER;

	PROCEDURE neighborTest(x, y: INTEGER): BOOLEAN;
	BEGIN
		(* cell is in map range and not visited *)
		RETURN (x > 0) & (x < MAP_WIDTH) & (y > 0) & (y < MAP_HEIGHT) & (worldMap[x, y] = -1)
	END neighborTest;

	(* find not visited neighbor *)
	PROCEDURE neighborFind(curX, curY: INTEGER; VAR dir: INTEGER): BOOLEAN;
	VAR
		bFound, b0, b1, b2, b3: BOOLEAN;
	BEGIN
		bFound := FALSE; b0 := FALSE; b1 := FALSE; b2 := FALSE; b3 := FALSE;
		WHILE ~bFound & ~(b0 & b1 & b2 & b3) DO
			dir := SHORT(random.Dice(4));
			CASE dir OF
				0: bFound := neighborTest(curX - 2, curY); b0 := TRUE
				| 1: bFound := neighborTest(curX, curY - 2); b1 := TRUE
				| 2: bFound := neighborTest(curX + 2, curY); b2 := TRUE
				| 3: bFound := neighborTest(curX, curY + 2); b3 := TRUE
			ELSE
			END
		END;
		RETURN bFound
	END neighborFind;
	
BEGIN
	curX := SHORT(random.Dice(CELLS_X)) * 2 + 1;
	curY := SHORT(random.Dice(CELLS_Y)) * 2 + 1;
	(* stack is empty *)
	stackTop := -1;
	(* mark cell as visited *)
	worldMap[curX, curY] := 0;
	cellsVisited := 1;
	WHILE cellsVisited < CELLS_TOTAL DO
		IF neighborFind(curX, curY, neighborDir) THEN
			(* push current cell to stack *)
			INC(stackTop); stack[stackTop].x := curX; stack[stackTop].y := curY;
			(* remove wall between current cell and found neighbor and make neighbor the next current cell *)
			CASE neighborDir OF
				0: worldMap[curX - 1, curY] := 0; curX := curX - 2
				| 1: worldMap[curX, curY - 1] := 0; curY := curY - 2
				| 2: worldMap[curX + 1, curY] := 0; curX := curX + 2
				| 3: worldMap[curX, curY + 1] := 0; curY := curY + 2
			ELSE
			END;
			(* mark cell as visited *)
			worldMap[curX, curY] := 0;
			INC(cellsVisited)
		ELSE
			(* pop cell from top of stack *)
			curX := stack[stackTop].x; curY := stack[stackTop].y; DEC(stackTop)
		END
	END
END generateMaze;

(* Message preview handler for window manager. MUST NOT TRAP!!! *)
(*PROCEDURE MessageHandler(VAR msg: WMMessages.Message; VAR discard: BOOLEAN);
BEGIN
	discard := FALSE;
	IF (instance # NIL) & (msg.msgType = WMMessages.MsgPointer) &
		(msg.msgSubType = WMMessages.MsgSubPointerMove)
	THEN
		BEGIN {EXCLUSIVE}
			IF ~bFirstMsg THEN
				IF oldX # msg.x THEN
					instance.Rotate(oldX - msg.x)
				END;
				IF oldY # msg.y THEN
					instance.Move(oldY - msg.y)
				END;
			ELSE
				bFirstMsg := FALSE
			END;
			oldX := msg.x;
			oldY := msg.y
		END
	END
END MessageHandler;*)

PROCEDURE InstallMessageHandler;
BEGIN
	(*manager := WM.GetDefaultManager();
	IF manager # NIL THEN
		bFirstMsg := TRUE;
		manager.InstallMessagePreview(MessageHandler)
	END*)
	NEW(mouse, 5, 15)
END InstallMessageHandler;

PROCEDURE UnInstallMessageHandler;
BEGIN
	(*IF manager # NIL THEN
		manager.RemoveMessagePreview(MessageHandler);
		manager := NIL
	END*)
	Inputs.mouse.Unregister(mouse)
END UnInstallMessageHandler;

PROCEDURE mapView*(context: Commands.Context);
VAR
	x, y, ny: INTEGER;
BEGIN
	context.out.Ln;
	FOR y := 0 TO MAP_HEIGHT - 1 DO
		FOR x := 0 TO MAP_WIDTH - 1 DO
			ny := MAP_HEIGHT - y - 1;
			IF worldMap[x, ny] > 0 THEN
				context.out.String("██")
			ELSIF (x = ENTIER(posX)) & (ny = ENTIER(posY)) THEN
				context.out.String("▓▓")
			ELSE
				context.out.String("░░")
			END
		END;
		context.out.Ln
	END
END mapView;
	
PROCEDURE Open*(context: Commands.Context);
VAR
	y: LONGINT;
	bError: BOOLEAN;
	strPath: ARRAY 256 OF CHAR;
BEGIN
	IF instance # NIL THEN RETURN END;
	
	context.out.Ln;
	
	context.out.String("Loading textures..."); context.out.Ln;
	bError := FALSE;
	
	Strings.Concat(DATA_FILE, "://", strPath);
	Strings.Concat(strPath, DATA_PATH, strPath);
		
	bError := bError OR ~LoadTexture(strPath, "brick04.png", textures[0]);
	bError := bError OR ~LoadTexture(strPath, "slate.png", textures[1]);
	bError := bError OR ~LoadTexture(strPath, "stone2.png", textures[2]);
	
	IF ~bError THEN
		context.out.String("Textures loaded successfully"); context.out.Ln;
		
		IF INIT_SEED THEN
			random.InitSeed(SHORT(PreciseTimer.GetTicks()))
		END;
		
		levelMapCellWidth := MIN((((SCREEN_WIDTH - MAP_DRAW_START_X - 2) * MAP_SCALE) DIV 100) DIV (MAP_WIDTH - 2),
			(((SCREEN_HEIGHT - MAP_DRAW_START_Y - 2) * MAP_SCALE) DIV 100) DIV (MAP_HEIGHT - 2));
		LevelMapWidth := levelMapCellWidth * (MAP_WIDTH - 2) + 2;
		LevelMapHeight := levelMapCellWidth * (MAP_HEIGHT - 2) + 2;
	
		NEW(bufferLevelMapPixels, LevelMapWidth * LevelMapHeight * 4);
		NEW(bufferPlayerPixels, levelMapCellWidth * levelMapCellWidth * 4);
		
		posX := SHORT(random.Dice(CELLS_X)) * 2 + 1;
		posY := SHORT(random.Dice(CELLS_Y)) * 2 + 1;
		
		(* place player at centre of cell *)
		posX := posX + 0.5;
		posY := posY + 0.5;
		
		dirX := -1;
		dirY := 0;
		planeX := 0;
		planeY := 0.66;
		
		mapClear;
		
		context.out.String("Generating maze..."); context.out.Ln;
		generateMaze;
		context.out.String("Maze generated"); context.out.Ln;
		
		paintMaze;
		paintPlayer;
		
		FOR y := 0 TO SCREEN_HEIGHT - 1 DO
			currentDistLookUp[y] := SCREEN_HEIGHT / (2.0 * y - SCREEN_HEIGHT)
		END;
		
		NEW(bufferPixels, SCREEN_WIDTH * SCREEN_HEIGHT * 4);
		
		NEW(fpsCounter, 200);
		
		NEW(instance, FALSE);
		
		InstallMessageHandler
		
	END

END Open;

PROCEDURE Cleanup;
BEGIN
	IF instance # NIL THEN
		instance.Close
	END
END Cleanup;

BEGIN
	NEW(random);
	Modules.InstallTermHandler(Cleanup)
END RaycasterMaze.

RaycasterMaze.Open ~
SystemTools.Free RaycasterMaze ~

