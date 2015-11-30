MODULE WMScribble;    (** AUTHOR "TF"; PURPOSE "Example program"; *)

IMPORT SYSTEM, Raster, WMWindowManager, Strings, WMGraphics, WMRectangles, Modules, WMDialogs;

CONST

    MAP =
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
    
    MAP_HEIGHT = LEN(MAP, 0);
    MAP_WIDTH = LEN(MAP, 1);
    
    CELL_WIDTH    = 20;

TYPE
    ScribbleWindow = OBJECT (WMWindowManager.BufferWindow);
    VAR lx, ly : LONGINT;
    
        mode: Raster.Mode;

        PROCEDURE &New*;
        BEGIN
            Init(nMapPixelsWidth, nMapPixelsHeight, FALSE);
            WMWindowManager.AddWindow(SELF, 200, 200);
            SetTitle(Strings.NewString("Scribble Example"));
            SetIcon(WMGraphics.LoadImage("WMIcons.tar://WMScribble.png", TRUE));
            canvas.Fill(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()), WMGraphics.White, WMGraphics.ModeCopy);
            Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
            SetPointerInfo(manager.pointerCrosshair)
        END New;

        PROCEDURE PointerMove(x, y : LONGINT; keys : SET);
        BEGIN
            IF 0 IN keys THEN canvas.Line(lx, ly, x, y, WMGraphics.Blue, WMGraphics.ModeSrcOverDst);
                Invalidate(
                    WMRectangles.MakeRect(Strings.Min(lx, x), Strings.Min(ly, y), Strings.Max(lx, x) + 1, Strings.Max(ly, y) + 1)
                )
             END;
            lx := x; ly := y
        END PointerMove;

        PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
        BEGIN
            lx := x; ly := y;
            IF 2 IN keys THEN
                canvas.Fill(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()), WMGraphics.White, WMGraphics.ModeCopy);
                Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
            END
        END PointerDown;

        PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; keySym : LONGINT);
        VAR res, y: LONGINT; filename : ARRAY 128 OF CHAR;
        BEGIN
            IF ucs = ORD("s") THEN
                filename := "scribble.bmp";
                IF WMDialogs.QueryString("Save as :", filename) = WMDialogs.ResOk THEN
                    WMGraphics.StoreImage(img, filename, res);
                    IF res # 0 THEN
                        WMDialogs.Error("Sorry", "The image could not be stored. Try another file name.");
                    END
                END
            ELSIF ucs = ORD("b") THEN
                Raster.InitMode(mode, Raster.srcCopy);
                FOR y := 0 TO nMapPixelsHeight - 1 DO
                    Raster.PutPixels(img, 0, y, nMapPixelsWidth, Raster.BGRA8888,
                        bufMapPixels^, y * nMapPixelsWidth * 4, mode)
                END;
                Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
            END
        END KeyEvent;
    END ScribbleWindow;

VAR s : ScribbleWindow;

    bufMapPixels: POINTER TO ARRAY OF CHAR;
    nMapPixelsWidth, nMapPixelsHeight: LONGINT;

    PROCEDURE InitMapPixels;
    VAR
        x, y, tileX, tileY, x2, y2: LONGINT;
        pixelWall, pixelFloor: Raster.Pixel;
        bTop, bBottom, bLeft, bRight: BOOLEAN;
    BEGIN
        NEW(bufMapPixels, nMapPixelsWidth * nMapPixelsHeight * 4);
        pixelWall[Raster.r] := 080X;
        pixelWall[Raster.g] := 050X;
        pixelWall[Raster.b] := 0X;
        pixelWall[Raster.a] := 020X;
        pixelFloor[Raster.r] := 0X;
        pixelFloor[Raster.g] := 0X;
        pixelFloor[Raster.b] := 0X;
        pixelFloor[Raster.a] := 0X;
        (* draw border *)
        
        FOR y := 0 TO nMapPixelsHeight - 1 DO
            FOR x := 0 TO nMapPixelsWidth - 1 DO
                IF (x = 0) OR (x = nMapPixelsWidth - 1) OR
                    (y = 0) OR (y = nMapPixelsHeight - 1)
                THEN
                    SYSTEM.PUT32(SYSTEM.ADR(bufMapPixels^[0]) + nMapPixelsWidth * 4 * y + 4 * x,
                        SYSTEM.VAL(LONGINT, pixelWall))
                ELSE
                    SYSTEM.PUT32(SYSTEM.ADR(bufMapPixels^[0]) + nMapPixelsWidth * 4 * y + 4 * x,
                        SYSTEM.VAL(LONGINT, pixelFloor))
                END
            END
        END;
        
        tileY := 1;
        FOR y := 1 TO MAP_HEIGHT - 2 DO
            tileX := 1;
            FOR x := 1 TO MAP_WIDTH - 2 DO
                IF MAP[y, x] > 0 THEN
                    bBottom := (y + 1 <= MAP_HEIGHT - 2) & (MAP[y + 1, x] = 0);
                    bTop := (y - 1 >= 1) & (MAP[y - 1, x] = 0);
                    bLeft := (x - 1 >= 1) & (MAP[y, x - 1] = 0);
                    bRight := (x + 1 <= MAP_WIDTH - 2) & (MAP[y, x + 1] = 0);
                    FOR y2 := 0 TO CELL_WIDTH - 1 DO
                        FOR x2 := 0 TO CELL_WIDTH - 1 DO
                            IF ((x2 = 0) & bLeft) OR ((y2 = 0) & bTop) OR
                                ((x2 = CELL_WIDTH - 1) & bRight) OR
                                ((y2 = CELL_WIDTH - 1) & bBottom) OR
                                ((x2 + y2) MOD 5 = 0)
                            THEN
                                SYSTEM.PUT32(SYSTEM.ADR(bufMapPixels^[0]) +
                                    nMapPixelsWidth * 4 * (tileY + y2) + 4 * (tileX + x2),
                                    SYSTEM.VAL(LONGINT, pixelWall))
                            END
                        END
                    END
                END;
                INC(tileX, CELL_WIDTH)
            END;
            INC(tileY, CELL_WIDTH)
        END
        
    END InitMapPixels;

PROCEDURE Open*;
BEGIN {EXCLUSIVE}
    IF s # NIL THEN s.Close END;
    nMapPixelsWidth := CELL_WIDTH * (MAP_WIDTH - 2) + 2;
    nMapPixelsHeight := CELL_WIDTH * (MAP_HEIGHT - 2) + 2;
    InitMapPixels;
    NEW(s);
END Open;

PROCEDURE Cleanup;
BEGIN
    IF s # NIL THEN s.Close END
END Cleanup;

BEGIN
    Modules.InstallTermHandler(Cleanup)
END WMScribble.

SystemTools.Free WMScribble ~
WMScribble.Open ~
WMPicView.Open scribble.bmp ~



