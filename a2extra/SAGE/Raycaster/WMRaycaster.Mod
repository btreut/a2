MODULE WMRaycaster; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Lode's Computer Graphics Raycasting Tutorial ported to Active Oberon. Raycasting III: Sprites"; *)

IMPORT
	SYSTEM, Events, PreciseTimer, Modules, Inputs, Strings, Commands, Raster, Files,
	WM := WMWindowManager, Rectangles := WMRectangles,
	Math := Math, Graphics := WMGraphics;
	
CONST

	DEBUGLOG = FALSE;
	EventClass = 3;
	EventSubclass = 3;
	moduleName = "Test";
	
	THREADS = 4;

	BENCHMARK = TRUE;
	TESTS = 50;
	
	DATA_FILE = "WMRaycasterData.zip";
	DATA_PATH = "pics/";

	worldMap =
		[
			[8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 4, 4, 6, 4, 4, 6, 4, 6, 4, 4, 4, 6, 4],
			[8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4],
			[8, 0, 3, 3, 0, 0, 0, 0, 0, 8, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6],
			[8, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6],
			[8, 0, 3, 3, 0, 0, 0, 0, 0, 8, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4],
			[8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 4, 0, 0, 0, 0, 0, 6, 6, 6, 0, 6, 4, 6],
			[8, 8, 8, 8, 0, 8, 8, 8, 8, 8, 8, 4, 4, 4, 4, 4, 4, 6, 0, 0, 0, 0, 0, 6],
			[7, 7, 7, 7, 0, 7, 7, 7, 7, 0, 8, 0, 8, 0, 8, 0, 8, 4, 0, 4, 0, 6, 0, 6],
			[7, 7, 0, 0, 0, 0, 0, 0, 7, 8, 0, 8, 0, 8, 0, 8, 8, 6, 0, 0, 0, 0, 0, 6],
			[7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 6, 0, 0, 0, 0, 0, 4],
			[7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 6, 0, 6, 0, 6, 0, 6],
			[7, 7, 0, 0, 0, 0, 0, 0, 7, 8, 0, 8, 0, 8, 0, 8, 8, 6, 4, 6, 0, 6, 6, 6],
			[7, 7, 7, 7, 0, 7, 7, 7, 7, 8, 8, 4, 0, 6, 8, 4, 8, 3, 3, 3, 0, 3, 3, 3],
			[2, 2, 2, 2, 0, 2, 2, 2, 2, 4, 6, 4, 0, 0, 6, 0, 6, 3, 0, 0, 0, 0, 0, 3],
			[2, 2, 0, 0, 0, 0, 0, 2, 2, 4, 0, 0, 0, 0, 0, 0, 4, 3, 0, 0, 0, 0, 0, 3],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 4, 3, 0, 0, 0, 0, 0, 3],
			[1, 0, 0, 0, 0, 0, 0, 0, 1, 4, 4, 4, 4, 4, 6, 0, 6, 3, 3, 0, 0, 0, 3, 3],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 1, 2, 2, 2, 6, 6, 0, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5]
		];
		
	MAP_HEIGHT = LEN(worldMap, 0);
	MAP_WIDTH = LEN(worldMap, 1);
		
	SpriteX = 0;
	SpriteY = 1;
	SpriteTexture = 2;
		
	(** Sprites: x pos, y pos, texture num *)
	sprites = 
		[
			(** green light in front of playerstart *)
			[20.5, 11.5, 10],
			
			(** devil *)
			[20.0, 11.0, 11],
			  
			(** green lights in every room *)
			[18.5, 4.5, 10],
			[10.0, 4.5, 10],
			[10.0, 12.5, 10],
			[3.5, 6.5, 10],
			[3.5, 20.5, 10],
			[3.5, 14.5, 10],
			[14.5, 20.5, 10],
			  
			(** row of pillars in front of wall: fisheye test *)
			[18.5, 10.5, 9],
			[18.5, 11.5, 9],
			[18.5, 12.5, 9],
			  
			(** some barrels around the map *)
			[21.5, 1.5, 8],
			[15.5, 1.5, 8],
			[16.0, 1.8, 8],
			[16.2, 1.2, 8],
			[3.5,  2.5, 8],
			[9.5, 15.5, 8],
			[10.0, 15.1, 8],
			[10.5, 15.8, 8]
		];
	
	numSprites = LEN(sprites, 0);

	SCREEN_WIDTH = 640;
	SCREEN_HEIGHT = 480;
	
	(** parameters for scaling and moving the sprites *)
	uDiv = 1.0;
	vDiv = 1.0;
	vMove = 0.0;
	
	ceilingTexture = 6;
	floorTexture = 3;
	
TYPE

	Texture = RECORD
		width, height: LONGINT;
		bSprite: BOOLEAN; (* texture is sprite *)
		pixels: POINTER TO ARRAY OF Raster.Pixel;
		pixelsDark: POINTER TO ARRAY OF Raster.Pixel;
		mask: POINTER TO ARRAY OF BOOLEAN;
	END;

	TextureArray = POINTER TO ARRAY OF Texture;

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
	
	ThreadData = POINTER TO RECORD
		id: LONGINT;
		nThreadComputedBuckets: LONGINT;
	END;
	
	RenderThread = OBJECT
	VAR
		w: RaycasterWindow;
		td: ThreadData;
		bi, iXStart, iXEnd: LONGINT;
		str1, str2: ARRAY 64 OF CHAR;
	
	PROCEDURE &New(w: RaycasterWindow; td: ThreadData);
	BEGIN
		SELF.w := w;
		SELF.td := td;
		w.IncActiveThreads
	END New;
	
	PROCEDURE Render;
	VAR
		cameraX, (** x-coordinate in camera space *)
		rayDirX, rayDirY,
		sideDistX, sideDistY, (** length of ray from current position to next x or y-side *)
		deltaDistX, deltaDistY,
		perpWallDist,
		wallX, (** where exactly the wall was hit *)
		floorXWall, floorYWall, (** x, y position of the floor texel at the bottom of the wall *)
		distWall, weight,
		currentFloorX, currentFloorY,
		rayDirX2, rayDirY2: REAL;
		mapX, mapY,
		stepX, stepY, (** what direction to step in x or y-direction (either +1 or -1) *)
		side, (** was a NS or a EW wall hit? *)
		lineHeight, drawStart, drawEnd, texNum, texX, d,
		texWidth, texHeight,
		pixelOffset, floorPixelOffset, ceilingPixelOffset,
		x, y: LONGINT;
	BEGIN
		FOR x := iXStart TO iXEnd DO
		
			(** calculate ray position and direction *)
			cameraX := 2 * x / SCREEN_WIDTH - 1;
			rayDirX := w.dirX + w.planeX * cameraX;
			rayDirY := w.dirY + w.planeY * cameraX;
			
			(** which box of the map we're in *)
			mapX := ENTIER(w.posX);
			mapY := ENTIER(w.posY);
			       
			(** length of ray from one x or y-side to next x or y-side *)
			rayDirX2 := rayDirX * rayDirX;
			rayDirY2 := rayDirY * rayDirY;
			deltaDistX := Math.sqrt(1 + rayDirY2 / rayDirX2);
			deltaDistY := Math.sqrt(1 + rayDirX2 / rayDirY2);
			       			
			(** calculate step and initial sideDist *)
			IF rayDirX < 0 THEN
				stepX := -1;
				sideDistX := (w.posX - mapX) * deltaDistX
			ELSE
				stepX := 1;
				sideDistX := (mapX + 1.0 - w.posX) * deltaDistX
			END;
			IF rayDirY < 0 THEN
				stepY := -1;
				sideDistY := (w.posY - mapY) * deltaDistY;
			ELSE
				stepY := 1;
				sideDistY := (mapY + 1.0 - w.posY) * deltaDistY;
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
			UNTIL worldMap[mapX, mapY] > 0;
			
			(** Calculate distance of perpendicular ray (calculate distance projected on camera direction) (oblique distance will give fisheye effect!) *)
			(** calculate value of wallX *)
			IF side = 0 THEN
				perpWallDist := (mapX - w.posX + (1 - stepX) / 2) / rayDirX;
				wallX := w.posY + perpWallDist * rayDirY
			ELSE
				perpWallDist := (mapY - w.posY + (1 - stepY) / 2) / rayDirY;
				wallX := w.posX + perpWallDist * rayDirX
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
			texNum := worldMap[mapX, mapY] - 1; (** 1 subtracted from it so that texture 0 can be used! *)
			texWidth := w.textures[texNum].width;
			texHeight := w.textures[texNum].height;
			       
			(** x coordinate on the texture *)
			texX := ENTIER(wallX * texWidth);
			IF ((side = 0) & (rayDirX > 0)) OR ((side = 1) & (rayDirY < 0)) THEN
				texX := texWidth - texX - 1
			END;
			
			d := -SCREEN_HEIGHT DIV 2 + lineHeight DIV 2;
			pixelOffset := SCREEN_WIDTH * 4 * drawStart + x * 4;
			FOR y := drawStart TO drawEnd DO
				IF side = 1 THEN
					SYSTEM.PUT32(ADDRESSOF(w.bufferPixels[pixelOffset]) ,
						SYSTEM.VAL(LONGINT, w.textures[texNum].pixelsDark[texWidth * (((y + d) * texHeight) DIV lineHeight) + texX]))
				ELSE
					SYSTEM.PUT32(ADDRESSOF(w.bufferPixels[pixelOffset]),
						SYSTEM.VAL(LONGINT, w.textures[texNum].pixels[texWidth * (((y + d) * texHeight) DIV lineHeight) + texX]))
				END;
				INC(pixelOffset, SCREEN_WIDTH * 4)
			END;
			
			(** SET THE ZBUFFER FOR THE SPRITE CASTING *)
			w.ZBuffer[x] := perpWallDist; (** perpendicular distance is used *)
			
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
      
			distWall := perpWallDist;
			w.distPlayer := 0.0;

			(** draw the floor from drawEnd to the bottom of the screen *)
			floorPixelOffset := SCREEN_WIDTH * 4 * (drawEnd + 1) + x * 4;
			ceilingPixelOffset := SCREEN_WIDTH * 4 * (SCREEN_HEIGHT - drawEnd - 2) + x * 4;
			FOR y := drawEnd + 1 TO SCREEN_HEIGHT - 1 DO
				weight := (w.currentDistLookUp[y] - w.distPlayer) / (perpWallDist - w.distPlayer);
				currentFloorX := weight * floorXWall + (1.0 - weight) * w.posX;
				currentFloorY := weight * floorYWall + (1.0 - weight) * w.posY;
				(** floor *)
				SYSTEM.PUT32(ADDRESSOF(w.bufferPixels[floorPixelOffset]),
					SYSTEM.VAL(LONGINT, w.textures[floorTexture].pixelsDark[w.floorTexWidth * (ENTIER(currentFloorY * w.floorTexHeight) MOD w.floorTexHeight) +
						(ENTIER(currentFloorX * w.floorTexWidth) MOD w.floorTexWidth)]));
				INC(floorPixelOffset, SCREEN_WIDTH * 4);
				(** ceiling (symmetrical!) *)
				SYSTEM.PUT32(ADDRESSOF(w.bufferPixels[ceilingPixelOffset]),
					SYSTEM.VAL(LONGINT, w.textures[ceilingTexture].pixels[w.ceilingTexWidth * (ENTIER(currentFloorY * w.ceilingTexHeight) MOD w.ceilingTexHeight) +
						(ENTIER(currentFloorX * w.ceilingTexWidth) MOD w.ceilingTexWidth)]));
				DEC(ceilingPixelOffset, SCREEN_WIDTH * 4)
			END
		END
	END Render;
	
	BEGIN {ACTIVE}
		WHILE w.GetNextBucket(bi) DO
			INC(td.nThreadComputedBuckets);
			iXStart := bi * w.nBucketSizeX;
			iXEnd := iXStart + w.nBucketSizeX - 1;
			IF DEBUGLOG THEN
				COPY("CalcThread # ", str1);
				Strings.IntToStr(td.id, str2);
				Strings.Append(str1, str2);
				Strings.Append(str1, ", computing bucket # ");
				Strings.IntToStr(bi, str2);
				Strings.Append(str1, str2);
				Strings.Append(str1, "...");
				Log(Events.Information, 0, str1, TRUE);
			END;
			Render;
		END;
		w.DecActiveThreads
	END RenderThread;

	RaycasterWindow* = OBJECT(WM.BufferWindow)
	VAR
		alpha, bDead: BOOLEAN;
		font: Graphics.Font;
		(** Lookup table for speedup *)
		textures: TextureArray;
		currentDistLookUp: ARRAY SCREEN_HEIGHT OF REAL;
		bufferPixels: POINTER TO ARRAY OF CHAR;
		posX, posY: REAL;  (** x and y start position *)
		dirX, dirY: REAL; (** initial direction vector *)
		planeX, planeY: REAL; (** the 2d raycaster version of camera plane *)
		moveSpeed, (** the constant value is in squares/second *)
		rotSpeed: REAL; (** the constant value is in radians/second *)
		fpsCounter: FPSCounter;
		floorTexWidth, floorTexHeight, ceilingTexWidth, ceilingTexHeight: LONGINT;
		distPlayer: REAL;
		
		(** 1D Zbuffer *)
		ZBuffer: ARRAY SCREEN_WIDTH OF REAL;
		
		
		nActiveThreads, nBucketsX, nBucketSizeX, nBucketsComputed: LONGINT;
		
	PROCEDURE IncActiveThreads;
	BEGIN {EXCLUSIVE}
		INC(nActiveThreads)
	END IncActiveThreads;
	
	PROCEDURE DecActiveThreads;
	BEGIN {EXCLUSIVE}
		DEC(nActiveThreads)
	END DecActiveThreads;
	
	PROCEDURE GetNextBucket(VAR bi: LONGINT): BOOLEAN;
	BEGIN 
	(*  pthread_mutex_lock(&rc->threadMutex); *)
		BEGIN {EXCLUSIVE}
			bi := nBucketsComputed;
			INC(nBucketsComputed);
		END;
	(*  pthread_mutex_unlock(&rc->threadMutex); *)
		RETURN bi < nBucketsX;
	END GetNextBucket;
	
	PROCEDURE Terminate;
	BEGIN
		bDead := TRUE;
		BEGIN {EXCLUSIVE}
			AWAIT(nActiveThreads = 0)
		END;
	END Terminate;
		
	PROCEDURE &New(textures: TextureArray; alpha: BOOLEAN);
	VAR
		y: LONGINT;
	BEGIN
		bDead := FALSE;
		nActiveThreads := 0;
		SELF.textures := textures;
		SELF.alpha := alpha;
		posX := 22;
		posY := 11.5;
		dirX := -1;
		dirY := 0;
		planeX := 0;
		planeY := 0.66;
		FOR y := 0 TO SCREEN_HEIGHT - 1 DO
			currentDistLookUp[y] := SCREEN_HEIGHT / (2.0 * y - SCREEN_HEIGHT)
		END;
		NEW(bufferPixels, SCREEN_WIDTH * SCREEN_HEIGHT * 4);
		NEW(fpsCounter, 200);
		Init(SCREEN_WIDTH, SCREEN_HEIGHT, alpha);
		WM.DefaultAddWindow(SELF);
		SetTitle(Strings.NewString("Textured raycaster with floor, ceiling and sprites"));
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
		t, tTest: HUGEINT;
		mode: Raster.Mode;
		
		(** arrays used to sort the sprites *)
		spriteOrder: ARRAY numSprites OF LONGINT;
		spriteDistance: ARRAY numSprites OF REAL;
		
		texX, texY, d,
		spriteScreenX, vMoveScreen,
		texWidth, texHeight,
		pixelOffset, 
		spritePixelOffset,
		spriteHeight, drawStartY, drawEndY,
		spriteWidth, drawStartX, drawEndX,
		stripe, y, i, iTexture: LONGINT;
		
		spriteX, spriteY, invDet,
		transformX, transformY: REAL;
		
		nThreadsTotal: LONGINT;
		threads: POINTER TO ARRAY OF RenderThread;
		iTest, iThread: LONGINT;
		td: ThreadData;
		
		str: ARRAY 16 OF CHAR;
		
		PROCEDURE ThreadsRun;
		BEGIN
			nBucketsComputed := 0;
			nActiveThreads := 0;
			FOR iThread := 0 TO nThreadsTotal - 1 DO
				NEW(td);
				td.id := iThread;
				td.nThreadComputedBuckets := 0;
				NEW(threads^[iThread], SELF, td)
			END;
			BEGIN {EXCLUSIVE}
				AWAIT(nActiveThreads = 0)
			END;
		END ThreadsRun;
		
		PROCEDURE RenderFrame(bBenchmark: BOOLEAN);
		BEGIN
			NEW(threads, nThreadsTotal);
		
			nBucketsX := nThreadsTotal * 4;
			nBucketSizeX := SCREEN_WIDTH DIV nBucketsX;
			
			IF bBenchmark THEN
				context.out.String("nThreadsTotal: ");
				context.out.Int(nThreadsTotal, 1);
				context.out.String(", nBucketsX: ");
				context.out.Int(nBucketsX, 1);
				context.out.String(", bucketSizeX: ");
				context.out.Int(nBucketSizeX, 1);
			END;

			IF bBenchmark THEN
				tTest := PreciseTimer.GetTicks();
			END;
			
			IF bBenchmark THEN
				FOR iTest := 0 TO TESTS - 1 DO
					ThreadsRun;
				END;
			ELSE
				ThreadsRun;
			END;
			
			IF bBenchmark THEN
				Strings.FloatToStr(PreciseTimer.GetTime(PreciseTimer.GetTicks() - tTest) / TESTS, 0, 4, 0, str);
				context.out.String(", time elapsed: ");
				context.out.String(str);
				context.out.Ln;
				context.out.String("nThreadComputedBuckets: [");
				FOR iThread := 0 TO nThreadsTotal - 1 DO
					IF iThread # 0 THEN
						context.out.String(", ");
					END;
					context.out.Int(threads^[iThread].td.nThreadComputedBuckets, 1);
				END;
				context.out.String("]");
				context.out.Ln;
			END;
		
		END RenderFrame;
		
	BEGIN
	
		IF bDead THEN RETURN END;

		t := PreciseTimer.GetTicks();
	
		distPlayer := 0.0;
		
		floorTexWidth := textures[floorTexture].width;
		floorTexHeight := textures[floorTexture].height;
		ceilingTexWidth := textures[ceilingTexture].width;
		ceilingTexHeight := textures[ceilingTexture].height;
		
		IF BENCHMARK THEN
			nThreadsTotal := 1;
			WHILE nThreadsTotal < (THREADS + 1) DO
				RenderFrame(BENCHMARK);
				nThreadsTotal := nThreadsTotal * 2; 
			END;
		ELSE
			nThreadsTotal := THREADS;
			RenderFrame(BENCHMARK);
		END;
		
		(** SPRITE CASTING *)

		(** sort sprites from far to close *)
		FOR i := 0 TO numSprites - 1 DO
			spriteOrder[i] := i;
			spriteDistance[i] := ((posX - sprites[i, SpriteX]) * (posX - sprites[i, SpriteX]) + (posY - sprites[i, SpriteY]) * (posY - sprites[i, SpriteY])); (** sqrt not taken, unneeded *)
		END;

		CombSort(spriteOrder, spriteDistance, numSprites);
		
		(** after sorting the sprites, do the projection and draw them *)
		FOR i := 0 TO numSprites - 1 DO
			iTexture := ENTIER(sprites[spriteOrder[i], SpriteTexture]);
			texWidth := textures[iTexture].width;
			texHeight := textures[iTexture].height;
			
			(** translate sprite position to relative to camera *)
			spriteX := sprites[spriteOrder[i], SpriteX] - posX;
			spriteY := sprites[spriteOrder[i], SpriteY] - posY;

			(** transform sprite with the inverse camera matrix *)
			(**  [ planeX   dirX ] -1                                       [ dirY      -dirX ] *)
			(**  [               ]       =  1/(planeX*dirY-dirX*planeY) *   [                 ] *)
			(**  [ planeY   dirY ]                                          [ -planeY  planeX ] *)
			
			invDet := 1.0 / (planeX * dirY - dirX * planeY); (** required for correct matrix multiplication *)
			transformX := invDet * (dirY * spriteX - dirX * spriteY);
			transformY := invDet * (-planeY * spriteX + planeX * spriteY); (** this is actually the depth inside the screen, that what Z is in 3D *)
			spriteScreenX := ENTIER((SCREEN_WIDTH / 2) * (1 + transformX / transformY));
			
			vMoveScreen := ENTIER(vMove / transformY);
			
			(** calculate height of the sprite on screen *)
			spriteHeight := ENTIER((SCREEN_HEIGHT / ABS(transformY)) / vDiv); (** using "transformY" instead of the real distance prevents fisheye *)
			d := -SCREEN_HEIGHT DIV 2 + spriteHeight DIV 2;

			(** calculate lowest and highest pixel to fill in current stripe *)
			drawStartY := -spriteHeight DIV 2 + SCREEN_HEIGHT DIV 2 + vMoveScreen;
			IF drawStartY < 0 THEN drawStartY := 0 END;
			drawEndY := spriteHeight DIV 2 + SCREEN_HEIGHT DIV 2 + vMoveScreen;
			IF drawEndY >= SCREEN_HEIGHT THEN drawEndY := SCREEN_HEIGHT - 1 END;
			
			(** calculate width of the sprite *)
			spriteWidth := ENTIER((SCREEN_HEIGHT / ABS(transformY)) / uDiv);
			drawStartX := -spriteWidth DIV 2 + spriteScreenX;
			IF drawStartX < 0 THEN drawStartX := 0 END;
			drawEndX := spriteWidth DIV 2 + spriteScreenX;
			IF drawEndX >= SCREEN_WIDTH THEN drawEndX := SCREEN_WIDTH - 1 END;
			
			(** loop through every vertical stripe of the sprite on screen *)
			FOR stripe := drawStartX TO drawEndX - 1 DO
				texX := ENTIER(256 * (stripe - (-spriteWidth / 2 + spriteScreenX)) * texWidth / spriteWidth) DIV 256;
				(** the conditions in the if are: *)
				(** 1) it's in front of camera plane so you don't see things behind you *)
				(** 2) it's on the screen (left) *)
				(** 3) it's on the screen (right) *)
				(** 4) ZBuffer, with perpendicular distance *)
				IF (transformY > 0) & (stripe > 0) & (stripe < SCREEN_WIDTH) & (transformY < ZBuffer[stripe]) THEN
					(** for every pixel of the current stripe *)
					pixelOffset := SCREEN_WIDTH * 4 * drawStartY + stripe * 4;
					FOR y := drawStartY TO drawEndY - 1 DO
						texY := (((y - vMoveScreen + d) * texHeight) DIV spriteHeight);
						(** paint pixel if it isn't black, black is the invisible color *)
						spritePixelOffset := texWidth * texY + texX;
						IF textures[iTexture].mask[spritePixelOffset] THEN
							SYSTEM.PUT32(ADDRESSOF(bufferPixels[pixelOffset]),
								SYSTEM.VAL(LONGINT, textures[iTexture].pixels[spritePixelOffset]))
						END;
						INC(pixelOffset, SCREEN_WIDTH * 4)
					END
				END
			END
		END;
		
		Raster.InitMode(mode, Raster.srcCopy);
		FOR y := 0 TO SCREEN_HEIGHT - 1 DO
			Raster.PutPixels(img, 0, y, SCREEN_WIDTH, Raster.BGRA8888, bufferPixels^, y * SCREEN_WIDTH * 4, mode)
		END;
		Invalidate(Rectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
		fpsCounter.AddTimeMeasure(PreciseTimer.GetTime(PreciseTimer.GetTicks() - t));
		moveSpeed := fpsCounter.GetAverageFrameTime() * 4.5;
		rotSpeed := fpsCounter.GetAverageFrameTime() * 2.0;
		
	END Frame;
			
	PROCEDURE Close;
	BEGIN
		Terminate;
		Close^;
		instance:=NIL
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
		IF (x >= 0) & (x < MAP_WIDTH) & (y >= 0) & (y < MAP_HEIGHT) & (worldMap[x, y] = 0) THEN
			posX := posX + dirX * fDist
		END;
		x := ENTIER(posX);
		y := ENTIER(posY + dirY * fDist);
		IF (x >= 0) & (x < MAP_WIDTH) & (y >= 0) & (y < MAP_HEIGHT) & (worldMap[x, y] = 0) THEN
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
		ELSIF keysym = Inputs.KsEscape THEN
			Close
		ELSE
		END
	END KeyEvent;
		
	END RaycasterWindow;
	

VAR
	context: Commands.Context;
	instance: RaycasterWindow;
	
PROCEDURE Log(type, code : SHORTINT; msg: ARRAY OF CHAR; showOnKernelLog : BOOLEAN);
VAR message : Events.Message;
BEGIN
	COPY(msg, message);
	Events.AddEvent(moduleName, type, EventClass, EventSubclass, code, message, showOnKernelLog);
END Log;
	
(** sort algorithm *)
PROCEDURE CombSort(VAR order: ARRAY OF LONGINT; VAR dist: ARRAY OF REAL; amount: LONGINT);
VAR
	gap, i, j: LONGINT;
	tmpOrder: LONGINT;
	tmpDist: REAL;
	swapped: BOOLEAN;
BEGIN
	gap := amount;
	swapped := FALSE;
	WHILE (gap > 1) OR swapped DO
		(** shrink factor 1.3 *)
		gap := (gap * 10) DIV 13;
		IF (gap = 9) OR (gap = 10) THEN gap := 11 END;
		IF gap < 1 THEN gap := 1 END;
		swapped := FALSE;
		FOR i := 0 TO amount - gap - 1 DO
			j := i + gap;
			IF dist[i] < dist[j] THEN
				tmpDist := dist[i];
				dist[i] := dist[j];
				dist[j] := tmpDist;
				tmpOrder := order[i];
				order[i] := order[j];
				order[j] := tmpOrder;
				swapped := TRUE
			END
		END
	END
END CombSort;
	
PROCEDURE LoadTexture(CONST strPath, strName: ARRAY OF CHAR; VAR tex: Texture; bSprite: BOOLEAN): BOOLEAN;
VAR
	image: Graphics.Image;
	bResult: BOOLEAN;
	mode: Raster.Mode;
	x, y, offset: LONGINT;
	pixel: Raster.Pixel;
	strFullPath: ARRAY 256 OF CHAR;
BEGIN
	bResult := FALSE;
	tex.bSprite := bSprite;
	Strings.Concat(strPath, strName, strFullPath);
	image := Graphics.LoadImage(strFullPath, FALSE);
	IF image # NIL THEN
		bResult := TRUE;
		tex.width := image.width;
		tex.height := image.height;
		NEW(tex.pixels, image.width * image.height);
		IF bSprite THEN
			NEW(tex.mask, image.width * image.height)
		ELSE
			NEW(tex.pixelsDark, image.width * image.height)
		END;
		Raster.InitMode(mode, Raster.srcCopy);
		FOR x := 0 TO tex.width - 1 DO
			FOR y := 0 TO tex.height - 1 DO
				Raster.Get(image, x, y, pixel, mode);
				offset := tex.width * y + x;
				tex.pixels[offset] := pixel;
				IF bSprite THEN
					tex.mask[offset] := ~((pixel[Raster.r] = 0X) & (pixel[Raster.g] = 0X) & (pixel[Raster.b] = 0X))
				ELSE
					tex.pixelsDark[offset][Raster.b] :=  CHR(ORD(pixel[Raster.b]) DIV 2);
					tex.pixelsDark[offset][Raster.g] :=  CHR(ORD(pixel[Raster.g]) DIV 2);
					tex.pixelsDark[offset][Raster.r] :=  CHR(ORD(pixel[Raster.r]) DIV 2);
					tex.pixelsDark[offset][Raster.a] :=  pixel[Raster.a]
				END
			END
		END
	END;
	RETURN bResult
END LoadTexture;
	
PROCEDURE Open*(c: Commands.Context);
VAR
	texArchive: Files.File;
	bError: BOOLEAN;
	strPath: ARRAY 256 OF CHAR;
	textures: TextureArray;
BEGIN
	IF instance # NIL THEN RETURN END;
	context := c;
	context.out.Ln;
	texArchive := Files.Old(DATA_FILE);
	bError := ~(texArchive # NIL);
	IF ~bError THEN
		context.out.String("Loading textures..."); context.out.Ln;
		Strings.Concat(DATA_FILE, "://", strPath);
		Strings.Concat(strPath, DATA_PATH, strPath);
		NEW(textures, 12);
		bError := bError OR ~LoadTexture(strPath, "eagle.png", textures[0], FALSE);
		bError := bError OR ~LoadTexture(strPath, "redbrick.png", textures[1], FALSE);
		bError := bError OR ~LoadTexture(strPath, "purplestone.png", textures[2], FALSE);
		bError := bError OR ~LoadTexture(strPath, "greystone.png", textures[3], FALSE);
		bError := bError OR ~LoadTexture(strPath, "bluestone.png", textures[4], FALSE);
		bError := bError OR ~LoadTexture(strPath, "mossy.png", textures[5], FALSE);
		bError := bError OR ~LoadTexture(strPath, "wood.png", textures[6], FALSE);
		bError := bError OR ~LoadTexture(strPath, "colorstone.png", textures[7], FALSE);
		IF ~bError THEN
			context.out.String("Loading sprite textures..."); context.out.Ln;
			bError := bError OR ~LoadTexture(strPath, "barrel.png", textures[8], TRUE);
			bError := bError OR ~LoadTexture(strPath, "pillar.png", textures[9], TRUE);
			bError := bError OR ~LoadTexture(strPath, "greenlight.png", textures[10], TRUE);
			bError := bError OR ~LoadTexture(strPath, "devil.png", textures[11], TRUE)
		END;
		IF ~bError THEN
			context.out.String("Textures loaded successfully"); context.out.Ln;
			NEW(instance, textures, FALSE)
		END
	END
END Open;

PROCEDURE Cleanup;
BEGIN
	IF instance # NIL THEN
		instance.Terminate;
		instance.Close
	END
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END WMRaycaster.

WMRaycaster.Open ~
SystemTools.Free WMRaycaster ~

Pentium(R) Dual-Core CPU T4200 @ 2.00 GHz:

nThreadsTotal: 1, nBucketsX: 4, bucketSizeX: 160, time elapsed:   0.0107
nThreadComputedBuckets: [4]
nThreadsTotal: 2, nBucketsX: 8, bucketSizeX: 80, time elapsed:   0.0060
nThreadComputedBuckets: [4, 4]
nThreadsTotal: 4, nBucketsX: 16, bucketSizeX: 40, time elapsed:   0.0061
nThreadComputedBuckets: [0, 0, 8, 8]