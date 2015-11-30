MODULE Ncaster; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	SYSTEM, Kernel32, Modules, Inputs, Kernel, Strings, BIT, Commands, Raster, Files,
	WM := WMWindowManager, Rectangles := WMRectangles,
	Math := Math, Graphics := WMGraphics;
	
CONST

	worldMap =
	[
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	2,	2,	2,	2,	2,	0,	0,	0,	0,	6,	1,	1,	1,	6,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	2,	0,	0,	0,	2,	0,	0,	0,	0,	1,	0,	0,	0,	1,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	2,	0,	0,	0,	1,	1,	1,	1,	1,	1,	0,	0,	0,	3,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	2,	0,	0,	0,	2,	0,	0,	1,	0,	1,	0,	0,	0,	1,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	2,	2,	0,	2,	2,	1,	1,	1,	0,	6,	1,	1,	1,	6,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	1,	1,	1,	1,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	1,	0,	0,	0,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	0,	0,	0,	1,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	1,	0,	0,	0,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	1,	1,	1,	1,	1,	1,	1,	2,	2,	2,	2,	2,	2,	2,	2,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	0,	0,	0,	0,	0,	0,	0,	1,	1,	1,	1,	1,	1,	1,	1,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	2,	2,	2,	2,	2,	2,	2,	2,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0]
	];

	heightMap =
	[
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	1,	1,	1,	1,	1,	0,	0,	0,	0,	2,	1,	2,	1,	2,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	1,	0,	0,	0,	1,	0,	0,	0,	0,	1,	0,	0,	0,	1,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	1,	0,	0,	0,	2,	1,	1,	1,	1,	2,	0,	0,	0,	1,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	1,	0,	0,	0,	1,	0,	0,	1.8,	0,	1,	0,	0,	0,	1,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	1,	1,	0,	1,	1,	1.2,	1.4,	1.6,	0,	2,	1,	2,	1,	2,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0.8,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0.6,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0.4,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0.2,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	1,	0.8,	0.6,	0.4,	0.2,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	1,	0,	0,	0,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	0,	0,	0,	1,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	1,	0,	0,	0,	0,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	1,	1,	1,	1,	1,	1,	2,	2,	2,	2,	2,	2,	2,	2,	2,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	0,	0,	0,	0,	0,	0,	0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	2,	2,	2,	2,	2,	2,	2,	2,	2,	0,	0,	0,	0,	0,	1,	0],
		[0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	1,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0]
	];

	altMap =
	[
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	1,	1,	1,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	1,	1,	1,	1,	1,	1,	1,	1,	1,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0],
		[0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0,	0]
	];
	
	mapHeight = LEN(worldMap, 0);
	mapWidth = LEN(worldMap, 1);
	
	ceilingTexture = 0;
	floorTexture = 2;

	screenWidth = 400;
	screenHeight = 300;
	
TYPE

	RaycasterWindow* = OBJECT(WM.BufferWindow)
	VAR
		alpha: BOOLEAN;
		font: Graphics.Font;
		
	PROCEDURE &New(alpha: BOOLEAN);
	BEGIN
		SELF.alpha:=alpha;
		Init(screenWidth, screenHeight, alpha);
		WM.DefaultAddWindow(SELF);
		SetTitle(Strings.NewString("Textured raycaster with floor and ceiling"));
		canvas.SetColor(Graphics.White);
		font := canvas.GetFont();
		Frame;
	END New;
	
	PROCEDURE Frame;
	VAR
		cameraX, (** x-coordinate in camera space *)
		rayPosX, rayPosY, rayDirX, rayDirY,
		sideDistX, sideDistY, (** length of ray from current position to next x or y-side *)
		deltaDistX, deltaDistY,
		perpWallDist,
		wallX, (** where exactly the wall was hit *)
		floorXWall, floorYWall, (** x, y position of the floor texel at the bottom of the wall *)
		distWall, distPlayer, currentDist, weight,
		currentFloorX, currentFloorY: REAL;
		mapX, mapY,
		stepX, stepY, (** what direction to step in x or y-direction (either +1 or -1) *)
		side, (** was a NS or a EW wall hit? *)
		lineHeight, drawStart, drawEnd, texNum, texX, texY, d,
		floorTexX, floorTexY,
		ceilingTexX, ceilingTexY,
		checkerBoardPattern: LONGINT;
		bHit: BOOLEAN; (** was there a wall hit? *)
		time, x, y, color: LONGINT;
		frameTime, frameTimeAverage, fps, fpsAverage: REAL;
		str1, str2, str: ARRAY 30 OF CHAR;
		pixel: Raster.Pixel;
		mode: Raster.Mode;
		red, green, blue, alpha,
		texWidth, texHeight,
		floorTexWidth, floorTexHeight,
		ceilingTexWidth, ceilingTexHeight, pixelOffset, textWidth, textHeight: LONGINT;
		
		freq, t1, t2: HUGEINT;
		
		colbuf: ARRAY screenHeight OF BOOLEAN;
		
		hwall, awall, nextD, texD: REAL;
		
		nextX, nextY, nextSide,
		lo, lw, lone, nlo, nlw,
		fstart, fend,
		wstart, wend,
		bstart, bend,
		swstart, swend,
		sfstart, sfend,
		sbstart, sbend,
		pxcount: LONGINT;
		
	BEGIN
	
		INC(framesCount);

		(*time := Kernel.GetTicks();*)
		
		freq := GetFreq();
		t1 := GetTimer();
		
		Raster.InitMode (mode, Raster.srcCopy);
		
		FOR y := 0 TO screenHeight - 1 DO
			FOR x := 0 TO screenWidth - 1 DO
				pixelOffset := screenWidth * y * 4 + x * 4;
				bufferPixels[pixelOffset + Raster.b] := 0X;
				bufferPixels[pixelOffset + Raster.g] := 0X;
				bufferPixels[pixelOffset + Raster.r] := 0X;
				bufferPixels[pixelOffset + Raster.a] := CHR(0FFH)
			END
		END;
		
		(*canvas.Fill(Rectangles.MakeRect(0, 0, GetWidth(), GetHeight()), Graphics.Black, Graphics.ModeSrcOverDst);*)
		FOR x := 0 TO screenWidth - 1 DO

			rayPosX := posX;
			rayPosY := posY;
			(** which box of the map we're in *)
			mapX := ENTIER(rayPosX);
			mapY := ENTIER(rayPosY);
		
			(** calculate ray position and direction *)
			cameraX := 2 * x / screenWidth - 1;

			rayDirX := dirX + planeX * cameraX;
			rayDirY := dirY + planeY * cameraX;
			       
			(** length of ray from one x or y-side to next x or y-side *)
			deltaDistX := Math.sqrt(1 + (rayDirY * rayDirY) / (rayDirX * rayDirX));
			deltaDistY := Math.sqrt(1 + (rayDirX * rayDirX) / (rayDirY * rayDirY));
			       			
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
				sideDistY := (rayPosY - mapY) * deltaDistY;
			ELSE
				stepY := 1;
				sideDistY := (mapY + 1.0 - rayPosY) * deltaDistY;
			END;
			
			FOR y := 0 TO screenHeight - 1 DO
				colbuf[y] := FALSE
			END;
			
			pxcount := 0;
			
			LOOP
				IF sideDistX < sideDistY THEN
					sideDistX := sideDistX + deltaDistX;
					INC(mapX, stepX);
					side := 0
				ELSE
					sideDistY := sideDistY + deltaDistY;
					INC(mapY, stepY);
					side := 1
				END;
				
				IF ~((mapX > 0) & (mapX < mapWidth) & (mapY > 0) & (mapY < mapHeight) & (pxcount < screenHeight)) THEN
					EXIT
				END;
				
				IF worldMap[mapX][mapY] > 0 THEN
					texNum := worldMap[mapX][mapY] - 1;
					hwall := heightMap[mapX][mapY];
					awall := altMap[mapX][mapY];
					texWidth := textures[texNum].width;
					texHeight := textures[texNum].height;
					
					(** Calculate distance of perpendicular ray (calculate distance projected on camera direction) (oblique distance will give fisheye effect!) *)
					IF side = 0 THEN
						perpWallDist := ABS((mapX - rayPosX + (1 - stepX) / 2) / rayDirX)
					ELSE
						perpWallDist := ABS((mapY - rayPosY + (1 - stepY) / 2) / rayDirY)
					END;
					
					IF sideDistX < sideDistY THEN
						nextX := mapX + stepX;
						nextSide := 0
					ELSE
						nextY := mapY + stepY;
						nextSide := 1
					END;
					
					IF side = 0 THEN
						nextD := ABS((nextX - rayPosX + (1 - stepX) / 2) / rayDirX)
					ELSE
						nextD := ABS((nextY - rayPosY + (1 - stepY) / 2) / rayDirY)
					END;
					
					lo := ENTIER(screenHeight * (0.5 - heye / perpWallDist + awall / perpWallDist));
					lw := ENTIER(screenHeight * hwall / perpWallDist);
					lone := ENTIER(screenHeight / perpWallDist);
					nlo := ENTIER(screenHeight * (0.5 - heye / nextD + awall / nextD));
					nlw := ENTIER(screenHeight * hwall / nextD);
					fstart := screenHeight - nlo - nlw; 
					fend := screenHeight - lo - lw - 1;
					wstart := screenHeight - lo - lw - 1; (* !!!! *)
					wend := screenHeight - lo - 1;
					bstart := screenHeight - lo;
					bend := screenHeight - nlo;
					
					(** calculate value of wallX *)
					IF side = 1 THEN
						wallX := rayPosX + ((mapY - rayPosY + (1 - stepY) / 2) / rayDirY) * rayDirX
					ELSE
						wallX := rayPosY + ((mapX - rayPosX + (1 - stepX) / 2) / rayDirX) * rayDirY
					END;
					wallX := wallX - ENTIER(wallX);
					       
					(** x coordinate on the texture *)
					texX := ENTIER(wallX * texWidth);
					IF ((side = 0) & (rayDirX > 0)) OR ((side = 1) & (rayDirY < 0)) THEN texX := texWidth - texX - 1 END;
					
					texY := 0;
					
					texD := texHeight / lone;
					
					swstart := MAX(wstart, 0);
					swend := MIN(wend, screenHeight - 1);
					
					IF swend = screenHeight - 1 THEN
						texY := ENTIER((wend - screenHeight + 1) * texD)
					END;
					
					FOR y := swstart TO swend DO
						IF ~colbuf[y] THEN
							pixelOffset := screenWidth * y * 4 + x * 4;
							(*pixel := textures[texNum].pixels[texWidth * texY + texX];
							bufferPixels[pixelOffset + Raster.b] := pixel[Raster.b];
							bufferPixels[pixelOffset + Raster.g] := pixel[Raster.g];
							bufferPixels[pixelOffset + Raster.r] := pixel[Raster.r];
							bufferPixels[pixelOffset + Raster.a] := pixel[Raster.a];*)
							bufferPixels[pixelOffset + Raster.b] := CHR(80H);
							bufferPixels[pixelOffset + Raster.g] := CHR(0FFH);
							bufferPixels[pixelOffset + Raster.r] := CHR(80H);
							bufferPixels[pixelOffset + Raster.a] := CHR(0FFH);
							colbuf[y] := TRUE;
							INC(pxcount)
						END;
						INC(texY, ENTIER(texD))
					END;
					
					(** floor loop *)
					sfstart := MAX(fstart, 0);
					sfend := MIN(fend, screenHeight - 1);
					
					FOR y := sfstart TO sfend DO
						IF ~colbuf[y] THEN
							pixelOffset := screenWidth * y * 4 + x * 4;
							bufferPixels[pixelOffset + Raster.b] := CHR(80H);
							bufferPixels[pixelOffset + Raster.g] := CHR(80H);
							bufferPixels[pixelOffset + Raster.r] := CHR(80H);
							bufferPixels[pixelOffset + Raster.a] := CHR(0FFH);
							colbuf[y] := TRUE;
							INC(pxcount)
						END
					END;
					
					(** bottom loop *)
					sbstart := MAX(bstart, 0);
					sbend := MIN(bend, screenHeight - 1);
					
					FOR y := sbstart TO sbend DO
						IF ~colbuf[y] THEN
							pixelOffset := screenWidth * y * 4 + x * 4;
							bufferPixels[pixelOffset + Raster.b] := CHR(80H);
							bufferPixels[pixelOffset + Raster.g] := CHR(80H);
							bufferPixels[pixelOffset + Raster.r] := CHR(80H);
							bufferPixels[pixelOffset + Raster.a] := CHR(0FFH);
							colbuf[y] := TRUE;
							INC(pxcount)
						END
					END
					
				END
				
			END
			
		END;
		
		FOR y := 0 TO screenHeight - 1 DO
			Raster.PutPixels(buffer, 0, y, screenWidth, Raster.BGRA8888, bufferPixels^, y * screenWidth * 4, mode)
		END;
		canvas.DrawImage(0, 0, buffer, Graphics.ModeSrcOverDst);
		
		(*time := Kernel.GetTicks() - time;
		IF time = 0 THEN time := 15 END;
		frameTime := time / 1000;*)
		
		t2 := GetTimer();
		frameTime := (t2 - t1) / freq;
		fps := 1 / frameTime;
		
		frameTimeSum := frameTimeSum + frameTime;
		frameTimeAverage := frameTimeSum / framesCount;
		fpsAverage := 1 / frameTimeAverage;
		
		moveSpeed := frameTimeAverage * 5.0;
		rotSpeed := frameTimeAverage * 3.0;
		
		Strings.FloatToStr(fps, 0, 2, 0, str1);
		Strings.FloatToStr(fpsAverage, 0, 2, 0, str2);
		Strings.TrimLeft(str2, 20X);
		Strings.Concat("FPS:", str1, str);
		Strings.Concat(str, " (", str);
		Strings.Concat(str, str2, str);
		Strings.Concat(str, ")", str);
		font.GetStringSize(str, textWidth, textHeight);
		canvas.DrawString(4, textHeight, str);
	
		Invalidate(Rectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
		
	END Frame;
			
	PROCEDURE Close;
	BEGIN
		Close^;
		instance:=NIL
	END Close;

	PROCEDURE KeyEvent* (ucs: LONGINT; flags: SET; keysym: LONGINT);
	VAR
		oldDirX, oldPlaneX: REAL;
	BEGIN
		IF keysym = 0FF51H THEN (* Cursor Left *)
			oldDirX := dirX;
			dirX := dirX * Math.cos(rotSpeed) - dirY * Math.sin(rotSpeed);
			dirY := oldDirX * Math.sin(rotSpeed) + dirY * Math.cos(rotSpeed);
			oldPlaneX := planeX;
			planeX := planeX * Math.cos(rotSpeed) - planeY * Math.sin(rotSpeed);
			planeY := oldPlaneX * Math.sin(rotSpeed) + planeY * Math.cos(rotSpeed);
			Frame
		ELSIF keysym = 0FF52H THEN (* Cursor Up *)
			IF flags * Inputs.Shift # {} THEN
				(** Run *)
				IF worldMap[ENTIER(posX + dirX * moveSpeed)][ENTIER(posY)] = 0 THEN posX := posX + dirX * 2 * moveSpeed END;
				IF worldMap[ENTIER(posX)][ENTIER(posY + dirY * moveSpeed)] = 0 THEN posY := posY + dirY * 2 * moveSpeed END
			ELSE
				IF worldMap[ENTIER(posX + dirX * moveSpeed)][ENTIER(posY)] = 0 THEN posX := posX + dirX * moveSpeed END;
				IF worldMap[ENTIER(posX)][ENTIER(posY + dirY * moveSpeed)] = 0 THEN posY := posY + dirY * moveSpeed END
			END;
			Frame
		ELSIF keysym = 0FF53H THEN (* Cursor Right *)
			oldDirX := dirX;
			dirX := dirX * Math.cos(-rotSpeed) - dirY * Math.sin(-rotSpeed);
			dirY := oldDirX * Math.sin(-rotSpeed) + dirY * Math.cos(-rotSpeed);
			oldPlaneX := planeX;
			planeX := planeX * Math.cos(-rotSpeed) - planeY * Math.sin(-rotSpeed);
			planeY := oldPlaneX * Math.sin(-rotSpeed) + planeY * Math.cos(-rotSpeed);
			Frame
		ELSIF keysym = 0FF54H THEN (* Cursor Down *)
			IF worldMap[ENTIER(posX - dirX * moveSpeed)][ENTIER(posY)] = 0 THEN posX := posX - dirX * moveSpeed END;
			IF worldMap[ENTIER(posX)][ENTIER(posY - dirY * moveSpeed)] = 0 THEN posY := posY - dirY * moveSpeed END;
			Frame
		ELSE
		END
	END KeyEvent;
		
	END RaycasterWindow;
	
	(*TTexture = ARRAY texWidth * texHeight OF Raster.Pixel;*)
	TTexture = RECORD
		width, height: LONGINT;
		pixels: POINTER TO ARRAY OF Raster.Pixel;
	END;
	
VAR

	textures: ARRAY 8 OF TTexture;
	
	buffer: Raster.Image;
	
	bufferPixels: POINTER TO ARRAY OF CHAR;

	instance: RaycasterWindow;
	posX, posY: REAL;  (** x and y start position *)
	dirX, dirY: REAL; (** initial direction vector *)
	planeX, planeY: REAL; (** the 2d raycaster version of camera plane *)
	heye: REAL;
	
	moveSpeed, (** the constant value is in squares/second *)
	rotSpeed: REAL; (** the constant value is in radians/second *)
	
	framesCount: LONGINT;
	frameTimeSum: REAL;
	
PROCEDURE GetTimer():HUGEINT;
VAR t : HUGEINT;
	res : Kernel32.BOOL;
BEGIN
	res := Kernel32.QueryPerformanceCounter(SYSTEM.VAL(Kernel32.LargeInteger, t));
	RETURN t;
END GetTimer;

PROCEDURE GetFreq():HUGEINT;
VAR t : HUGEINT;
	res : Kernel32.BOOL;
BEGIN
	res := Kernel32.QueryPerformanceFrequency(SYSTEM.VAL(Kernel32.LargeInteger, t));
	RETURN t;
END GetFreq;
	
PROCEDURE LoadTexture(CONST strPath: ARRAY OF CHAR; VAR tex: TTexture): BOOLEAN;
VAR
	image: Graphics.Image;
	bResult: BOOLEAN;
	mode: Raster.Mode;
	x, y: LONGINT;
BEGIN
	bResult := FALSE;
	image := Graphics.LoadImage(strPath, FALSE);
	IF (image # NIL) (*& (image.width = texWidth) & (image.height = texHeight)*) THEN
		bResult := TRUE;
		tex.width := image.width;
		tex.height := image.height;
		NEW(tex.pixels, image.width * image.height);
		Raster.InitMode(mode, Raster.srcCopy);
		FOR x := 0 TO tex.width - 1 DO
			FOR y := 0 TO tex.height - 1 DO
				Raster.Get(image, x, y, tex.pixels[tex.width * y + x], mode)
			END
		END
	END;
	RETURN bResult
END LoadTexture;
	
PROCEDURE Open*(context: Commands.Context);
VAR
	x, y, xorcolor, ycolor, xycolor: LONGINT;
	bError: BOOLEAN;
BEGIN
	IF instance # NIL THEN RETURN END;
	posX := 6;
	posY := 5.5;
	dirX := -1;
	dirY := 0;
	planeX := 0;
	planeY := 0.66;
	heye := 0.5;
	
	context.out.Ln;
	
	context.out.String("Loading textures..."); context.out.Ln;
	bError := FALSE;
	bError := bError OR ~LoadTexture("wolftex.zip://pics/eagle.png", textures[0]);
	bError := bError OR ~LoadTexture("wolftex.zip://pics/redbrick.png", textures[1]);
	bError := bError OR ~LoadTexture("wolftex.zip://pics/purplestone.png", textures[2]);
	bError := bError OR ~LoadTexture("wolftex.zip://pics/greystone.png", textures[3]);
	bError := bError OR ~LoadTexture("wolftex.zip://pics/bluestone.png", textures[4]);
	bError := bError OR ~LoadTexture("wolftex.zip://pics/mossy.png", textures[5]);
	bError := bError OR ~LoadTexture("wolftex.zip://pics/wood.png", textures[6]);
	bError := bError OR ~LoadTexture("wolftex.zip://pics/colorstone.png", textures[7]);
	
	IF ~bError THEN
		context.out.String("Textures loaded successfully"); context.out.Ln;
		
		NEW(bufferPixels, screenWidth * screenHeight * 4);
		
		NEW(buffer);
		Raster.Create(buffer, screenWidth, screenHeight, Raster.BGRA8888);
		
		framesCount := 0;
		frameTimeSum := 0.0;
		
		NEW(instance, FALSE);
	END

END Open;

PROCEDURE Cleanup;
BEGIN
	IF instance # NIL THEN instance.Close END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);

END Ncaster.

Ncaster.Open ~
SystemTools.Free Ncaster ~