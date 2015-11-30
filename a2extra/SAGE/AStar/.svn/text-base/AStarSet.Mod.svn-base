MODULE AStarSet; (** AUTHOR ""; PURPOSE ""; *)

IMPORT

	SYSTEM, MathL, Modules, Commands, Raster, WMWindowManager,
	WMDialogs, WMGraphics, WMRectangles, Strings,
	Containers, KernelLog, PreciseTimer;

CONST

	A_STAR = "A* Pathfinder";
	
	(* Multiplier for costs rounding *)
	ROUND_BASE = 40;
	
	(*
		Matrix that helps to answer
		the question "which cells should be
		additionally wallkable to get here from
		central cell (encoded as 12)"
		
		0  1  2  3  4
		5  6  7  8  9
		10 11 12 13 14
		15 16 17 18 19
		20 21 22 23 24
	*)

	(*
	TEST_5X5 = [
		[{0, 1, 5, 6, 7, 11},				{1, 6, 7},			{2, 7},			{3, 7, 8},			{3, 4, 7, 8, 9, 13}],
		[{5, 6, 11},									{6, 7, 11},		{7},				{7, 8, 13},		{8, 9, 13}],
		[{10, 11},										{11},						{},					{13},						{13, 14}],
		[{11, 15, 16},								{11, 16, 17},	{17},				{13, 17, 18},	{13, 18, 19}],
		[{11, 15, 16, 17, 20, 21},	{16, 17, 21},	{17, 22},		{17, 18, 23},	{13, 17, 18, 19, 23, 24}]
		];*)
		
	TEST_5X5 = [
		[{0, 1, 5, 6, 7, 11},				{1, 2, 6, 7, 11},			{2, 7},			{2, 3, 7, 8, 13},			{3, 4, 7, 8, 9, 13}],
		[{5, 6, 7, 10, 11},									{6, 7, 11},		{7},				{7, 8, 13},		{7, 8, 9, 13, 14}],
		[{10, 11},										{11},						{},					{13},						{13, 14}],
		[{10, 11, 15, 16, 17},								{11, 16, 17},	{17},				{13, 17, 18},	{13, 14, 17, 18, 19}],
		[{11, 15, 16, 17, 20, 21},	{11, 16, 17, 21, 22},	{17, 22},		{13, 17, 18, 22, 23},	{13, 17, 18, 19, 23, 24}]
		];
		
	(* Same for 3x3 matrix
		0	1	2
		3	4	5
		6	7	8
	*)
		
	TEST_3X3 = [
		[{0, 1, 3},	{1},	{1, 2, 5}],
		[{3},					{},		{5}],
		[{3, 6, 7},	{7},	{5, 7, 8}]
		];
	
	TEST_MATRIX = TEST_5X5;
	
	TEST_MAX = LEN(TEST_MATRIX, 0) DIV 2;

	WORLD =
		[
			[8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 4, 4, 6, 4, 4, 6, 4, 6, 4, 4, 4, 6, 4],
			[8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4],
			[8, 0, 3, 3, 0, 0, 0, 0, 0, 0, 8, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6],
			[8, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6],
			[8, 0, 3, 3, 0, 0, 0, 0, 0, 0, 8, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4],
			[8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 4, 0, 0, 0, 0, 0, 6, 6, 6, 0, 6, 4, 6],
			[8, 8, 8, 8, 0, 0, 8, 8, 8, 8, 8, 8, 4, 4, 4, 4, 4, 4, 6, 0, 0, 0, 0, 0, 6],
			[7, 7, 7, 7, 0, 0, 7, 7, 7, 7, 0, 8, 0, 8, 0, 8, 0, 8, 4, 0, 4, 0, 6, 0, 6],
			[7, 7, 0, 0, 0, 0, 0, 0, 0, 7, 8, 0, 8, 0, 8, 0, 8, 8, 6, 0, 0, 0, 0, 0, 6],
			[7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 6, 0, 0, 0, 0, 0, 4],
			[7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 6, 0, 6, 0, 6, 0, 6],
			[7, 7, 0, 0, 0, 0, 0, 0, 0, 7, 8, 0, 8, 0, 8, 0, 8, 8, 6, 4, 6, 0, 6, 6, 6],
			[7, 7, 7, 7, 0, 0, 7, 7, 7, 7, 8, 8, 4, 0, 6, 8, 4, 8, 3, 3, 3, 0, 3, 3, 3],
			[2, 2, 2, 2, 0, 0, 2, 2, 2, 2, 4, 6, 4, 0, 0, 6, 0, 6, 3, 0, 0, 0, 0, 0, 3],
			[2, 2, 0, 0, 0, 0, 0, 0, 2, 2, 4, 0, 0, 0, 0, 0, 0, 4, 3, 0, 0, 0, 0, 0, 3],
			[2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 0, 0, 0, 0, 0, 0, 4, 3, 0, 0, 0, 0, 0, 3],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 4, 4, 4, 4, 4, 6, 0, 6, 3, 3, 0, 0, 0, 3, 3],
			[2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 1, 2, 2, 2, 6, 6, 0, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 4, 4, 4, 4, 4, 6, 0, 6, 3, 3, 0, 0, 0, 3, 3],
			[2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 1, 2, 2, 2, 6, 6, 0, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5],
			[2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 5, 0, 5, 0, 5, 0, 5, 0, 5],
			[2, 2, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 0, 5, 0, 5, 0, 0, 0, 5, 5],
			[2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5]
		];

	MAP_HEIGHT = LEN(WORLD, 0);
	MAP_WIDTH = LEN(WORLD, 1);

TYPE

	PointDesc = RECORD
		x, y: LONGINT;
	END;

	(** Data used for A* pathfinding *)
	Node = POINTER TO RECORD
		nodeParent: Node;
		(* World coordinates *)
		p: PointDesc;
		(* Costs *)
		F, G, H: LONGINT;
		(* Beeng in Open or Closed list *)
		bOpen: BOOLEAN;
	END;

	(** Binary node's heap. F cost used as a key *)
	NodeFHeap = OBJECT(Containers.CustomHeap)
			
		PROCEDURE &New;
		BEGIN
			NEW(heap, Compare)
		END New;
		
		PROCEDURE Compare(first, second: ANY): LONGINT;
		VAR
			nFirst, nSecond: LONGINT;
		BEGIN
			nFirst := first(Node).F;
			nSecond := second(Node).F;
			IF nFirst < nSecond THEN
				RETURN -1
			ELSIF nFirst > nSecond THEN
				RETURN 1
			ELSE
				RETURN 0
			END
		END Compare;
		
		PROCEDURE Add(x: Node);
		BEGIN
			heap.Add(x)
		END Add;
		
		PROCEDURE Update(x: Node);
		BEGIN
			heap.Update(x)
		END Update;
		
		PROCEDURE Remove(): Node;
		VAR
			x: ANY;
		BEGIN
			x := heap.Remove();
			IF x # NIL THEN
				RETURN x(Node)
			ELSE
				RETURN NIL
			END
		END Remove;
	
		PROCEDURE GetCount(): LONGINT;
		BEGIN
			RETURN heap.GetCount()
		END GetCount;
		
	END NodeFHeap;
	
	(** Node's map. (X, Y) pair used as a key *)
	NodeXYMap = OBJECT(Containers.CustomVector)
			
		PROCEDURE &New;
		BEGIN
			NEW(vector, Compare, {Containers.VECTOR_SORTED , Containers.VECTOR_NO_DUPLICATES})
		END New;
		
		PROCEDURE Compare(first, second: ANY): LONGINT;
		VAR
			nodeFirst, nodeSecond: Node;
		BEGIN
			nodeFirst := first(Node);
			nodeSecond := second(Node);
			IF nodeFirst.p.x < nodeSecond.p.x THEN
				RETURN -1
			ELSIF nodeFirst.p.x > nodeSecond.p.x THEN
				RETURN 1
			ELSE
				IF nodeFirst.p.y < nodeSecond.p.y THEN
					RETURN -1
				ELSIF nodeFirst.p.y > nodeSecond.p.y THEN
					RETURN 1
				ELSE
					RETURN 0
				END
			END
		END Compare;
		
		PROCEDURE Add(x: Node);
		BEGIN
			vector.Add(x)
		END Add;
			
		PROCEDURE IndexOf(x: Node): LONGINT;
		BEGIN
			RETURN vector.IndexOf(x)
		END IndexOf;
		
		PROCEDURE GetItem(i: LONGINT): Node;
		BEGIN
			RETURN vector.GetItem(i)(Node)
		END GetItem;
			
	END NodeXYMap;

	Window = OBJECT(WMWindowManager.BufferWindow)
		VAR
			bufPixels, bufMapPixels, bufNodePixels: POINTER TO ARRAY OF CHAR;
			nMapPixelsWidth, nMapPixelsHeight, nMapCellWidth: LONGINT;

			bPointerDown: BOOLEAN;
			ptCell, ptStart, ptStop: PointDesc;
			bSetStart, bSetStop: BOOLEAN;
			nodeStopForth, nodeStopBack,
			nodeBest, nodeWorst: Node;

			context: Commands.Context;

		PROCEDURE &New;
		BEGIN
			bPointerDown := FALSE;
			bSetStart := FALSE;
			bSetStop := FALSE;
			nMapCellWidth := 20;
			nMapPixelsWidth := nMapCellWidth * (MAP_WIDTH - 2) + 2;
			nMapPixelsHeight := nMapCellWidth * (MAP_HEIGHT - 2) + 2;
			NEW(bufPixels, nMapPixelsWidth * nMapPixelsHeight * 4);
			NEW(bufMapPixels, nMapPixelsWidth * nMapPixelsHeight * 4);
			NEW(bufNodePixels, nMapCellWidth * nMapCellWidth * 4);
			PaintMap;
			PaintNode;
			Init(nMapPixelsWidth, nMapPixelsHeight, FALSE);
			WMWindowManager.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString(A_STAR));
			SetPointerInfo(manager.pointerCrosshair);
			Frame;
		END New;

		PROCEDURE Draw(canvas: WMGraphics.Canvas; w, h, q: LONGINT);
		VAR
			n: LONGINT;
			
			PROCEDURE DrawPath(nodePath: Node; color: WMGraphics.Color);
			VAR
				node: Node;
			BEGIN
				node := nodePath;
				WHILE node # NIL DO
					IF node.nodeParent # NIL THEN
						canvas.Line(
							(node.p.x - 1) * nMapCellWidth + n,
							(node.p.y - 1) * nMapCellWidth + n,
							(node.nodeParent.p.x - 1) * nMapCellWidth + n,
							(node.nodeParent.p.y - 1) * nMapCellWidth + n,
							color, WMGraphics.ModeCopy)
					END;
					node := node.nodeParent
				END;
			END DrawPath;
			
		BEGIN
			Draw^(canvas, w, h, q);
			n := nMapCellWidth DIV 2;
			IF bSetStart & bSetStop THEN
				(* Draw paths *)
				DrawPath(nodeWorst, LONGINT(0888888FFH));
				DrawPath(nodeBest, WMGraphics.Red);
			ELSIF bSetStart THEN
				(* Draw start point *)
				canvas.SetPixel((ptStart.x - 1) * nMapCellWidth + n,
					(ptStart.y - 1) * nMapCellWidth + n,
					WMGraphics.Cyan, WMGraphics.ModeSrcOverDst)
			END
		END Draw;

		PROCEDURE Frame;
		VAR
			y: LONGINT;
			mode: Raster.Mode;
		BEGIN
			(* Draw map *)
			Raster.InitMode(mode, Raster.srcCopy);
			FOR y := 0 TO nMapPixelsHeight - 1 DO
				Raster.PutPixels(img, 0, y, nMapPixelsWidth, Raster.BGRA8888,
					bufMapPixels^, y * nMapPixelsWidth * 4, mode)
			END;
			(*FOR y := 0 TO nMapPixelsHeight - 1 DO
				FOR x := 0 TO nMapPixelsWidth  - 1 DO
					pixel[0] := bufMapPixels^[y * nMapPixelsWidth * 4 + x * 4];
					pixel[1] := bufMapPixels^[y * nMapPixelsWidth * 4 + x * 4 + 1];
					pixel[2] := bufMapPixels^[y * nMapPixelsWidth * 4 + x * 4 + 2];
					pixel[3] := bufMapPixels^[y * nMapPixelsWidth * 4 + x * 4 + 3];
					IF ORD(pixel[1]) > 0 THEN
						canvas.SetPixel(x, y, WMGraphics.White, WMGraphics.ModeCopy);
					ELSE
						canvas.SetPixel(x, y, WMGraphics.Black, WMGraphics.ModeCopy);
					END;
				END
			END;*)
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
		END Frame;

		PROCEDURE PaintMap;
		VAR
			x, y, tileX, tileY, x2, y2: LONGINT;
			pixelWall, pixelFloor: Raster.Pixel;
			bTop, bBottom, bLeft, bRight: BOOLEAN;
		BEGIN
			pixelWall[Raster.r] := 080X;
			pixelWall[Raster.g] := 050X;
			pixelWall[Raster.b] := 0X;
			pixelWall[Raster.a] := 020X;
			pixelFloor[Raster.r] := 0X;
			pixelFloor[Raster.g] := 0X;
			pixelFloor[Raster.b] := 0X;
			pixelFloor[Raster.a] := 020X;
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
					IF WORLD[y, x] > 0 THEN
						bBottom := (y + 1 <= MAP_HEIGHT - 2) & (WORLD[y + 1, x] = 0);
						bTop := (y - 1 >= 1) & (WORLD[y - 1, x] = 0);
						bLeft := (x - 1 >= 1) & (WORLD[y, x - 1] = 0);
						bRight := (x + 1 <= MAP_WIDTH - 2) & (WORLD[y, x + 1] = 0);
						FOR y2 := 0 TO nMapCellWidth - 1 DO
							FOR x2 := 0 TO nMapCellWidth - 1 DO
								IF ((x2 = 0) & bLeft) OR ((y2 = 0) & bTop) OR
									((x2 = nMapCellWidth - 1) & bRight) OR
									((y2 = nMapCellWidth - 1) & bBottom) OR
									((x2 + y2) MOD 5 = 0)
								THEN
									SYSTEM.PUT32(SYSTEM.ADR(bufMapPixels^[0]) +
										nMapPixelsWidth * 4 * (tileY + y2) + 4 * (tileX + x2),
										SYSTEM.VAL(LONGINT, pixelWall))
								END
							END
						END
					END;
					INC(tileX, nMapCellWidth)
				END;
				INC(tileY, nMapCellWidth)
			END
		END PaintMap;

		PROCEDURE PaintNode;
		VAR
			x, y: LONGINT;
			pixelNode: Raster.Pixel;
		BEGIN
			pixelNode[Raster.r] := 0X;
			pixelNode[Raster.g] := 0AAX;
			pixelNode[Raster.b] := 055X;
			pixelNode[Raster.a] := 050X;
			FOR y := 0 TO nMapCellWidth - 1 DO
				FOR x := 0 TO nMapCellWidth - 1 DO
					SYSTEM.PUT32(SYSTEM.ADR(bufNodePixels^[0]) + nMapCellWidth * 4 * y + 4 * x,
						SYSTEM.VAL(LONGINT, pixelNode))
				END
			END
		END PaintNode;

		PROCEDURE Close;
		BEGIN
			Close^;
			instance := NIL
		END Close;

		PROCEDURE PointerDown(x, y : LONGINT; keys : SET);
		BEGIN
			bPointerDown := FALSE;
			IF IsHit(x, y) THEN
				ptCell.x := x DIV nMapCellWidth + 1;
				ptCell.y := y DIV nMapCellWidth + 1;
				bPointerDown := WORLD[ptCell.y, ptCell.x] = 0
			END
		END PointerDown;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		VAR
			t: HUGEINT;
			i: LONGINT;
			str: ARRAY 16 OF CHAR;
		BEGIN
			IF IsHit(x, y) & bPointerDown &
				(ptCell.x = x DIV nMapCellWidth + 1) &
				(ptCell.y = y DIV nMapCellWidth + 1)
			THEN
				IF (~bSetStart & ~bSetStop) OR (bSetStart & bSetStop) THEN
					ptStart.x := ptCell.x;
					ptStart.y := ptCell.y;
					bSetStart := TRUE;
					bSetStop := FALSE
				ELSIF bSetStart & ~bSetStop THEN
					ptStop.x := ptCell.x;
					ptStop.y := ptCell.y;
					bSetStop := TRUE;
					FindPath(ptStart, ptStop, nodeStopForth);
					FindPath(ptStop, ptStart, nodeStopBack);
					IF (nodeStopForth # NIL) & (nodeStopBack # NIL) THEN
						(* Select shortest path *)
						IF nodeStopForth.G < nodeStopBack.G THEN
							nodeBest := nodeStopForth;
							nodeWorst := nodeStopBack
						ELSE
							nodeBest := nodeStopBack;
							nodeWorst := nodeStopForth; 
						END;
						KernelLog.Ln;
						KernelLog.String("Best G: ");
						Strings.FloatToStr(nodeBest.G / ROUND_BASE, 0, 2, 0, str);
						Strings.TrimLeft(str, 20X);
						KernelLog.String(str);
						KernelLog.String(", worst G: ");
						Strings.FloatToStr(nodeWorst.G / ROUND_BASE, 0, 2, 0, str);
						Strings.TrimLeft(str, 20X);
						KernelLog.String(str);
						KernelLog.Ln;
					END;
				END;
				Frame
			END;
			bPointerDown := FALSE
		END PointerUp;

	END Window;

VAR
	instance: Window;
	costs: ARRAY TEST_MAX + 1 OF ARRAY TEST_MAX + 1 OF LONGINT;
	walkability: ARRAY MAP_HEIGHT OF ARRAY MAP_WIDTH OF SET;

	PROCEDURE InitWalkability;
	VAR
		y, x, dx, dy, nx, ny, iSet: LONGINT;
	BEGIN
		FOR y := 0 TO MAP_HEIGHT - 1 DO
			FOR x := 0 TO MAP_WIDTH - 1 DO
				walkability[y, x] := {};
				(*
					Encoding of map cells.
					For dx=0 and dy=0
					the iSet=12
					
					0  1  2  3  4
					5  6  7  8  9
					10 11 12 13 14
					15 16 17 18 19
					20 21 22 23 24
				*)
				iSet := 0;
				FOR dy := -TEST_MAX TO TEST_MAX DO
					FOR dx := -TEST_MAX TO TEST_MAX DO
						ny := y + dy;
						nx := x + dx;
						IF (0 <= ny) & (ny < MAP_HEIGHT) &
							(0 <= nx) & (nx < MAP_WIDTH) &
							(WORLD[ny, nx] = 0)
						THEN
							INCL(walkability[y, x], iSet);
						END;
						INC(iSet)
					END
				END
			END
		END
	END InitWalkability;

	PROCEDURE InitCosts;
	VAR
		i, j: LONGINT;
	BEGIN
		FOR i := 0 TO LEN(costs, 0) - 1 DO
			FOR j := 0 TO LEN(costs, 1) - 1 DO
				costs[i, j] := 
					ENTIER(MathL.sqrt(i * i + j * j) * ROUND_BASE + 0.5)
			END
		END;
	END InitCosts;
	
	PROCEDURE NewNode(nodeParent: Node; x, y: LONGINT; ptStop: PointDesc): Node;
	VAR
		node: Node;
	BEGIN
		NEW(node);
		node.nodeParent := nodeParent;
		IF nodeParent = NIL THEN
			(** absolute start position *)
			node.p.x := x;
			node.p.y := y;
			node.G := 0
		ELSE
			(** relative to parent position *)
			ASSERT((x # 0) OR (y # 0));
			node.p.x := nodeParent.p.x + x;
			node.p.y := nodeParent.p.y + y;
			node.G := nodeParent.G + costs[ABS(x), ABS(y)]
		END;
		(** estimation to target position *)
		node.H := (ABS(node.p.x - ptStop.x) + ABS(node.p.y - ptStop.y)) * 10;
		(** total cost *)
		node.F := node.G + node.H;
		node.bOpen := TRUE;
		RETURN node
	END NewNode;
	
	PROCEDURE AddAdjacentNodes(heapOpen: NodeFHeap; mapXY: NodeXYMap; node: Node; ptStop: PointDesc);
	VAR
		dx, dy: LONGINT;
		i: LONGINT;
		G: LONGINT;
		nodeNew, nodeTmp: Node;
		set: SET;
	BEGIN

		FOR dy := -TEST_MAX TO TEST_MAX DO
			FOR dx := -TEST_MAX TO TEST_MAX DO
				set := TEST_MATRIX[dy + TEST_MAX, dx + TEST_MAX];
				IF (set # {}) & (walkability[node.p.y, node.p.x] * set = set) THEN
					nodeNew := NewNode(node, dx, dy, ptStop);
					i := mapXY.IndexOf(nodeNew);
					IF i = -1 THEN
						heapOpen.Add(nodeNew);
						mapXY.Add(nodeNew)
					ELSE
						nodeTmp := mapXY.GetItem(i);
						(* Figure out G cost *)
						G := node.G + costs[ABS(dx), ABS(dy)];
						IF G < nodeTmp.G THEN
							nodeTmp.nodeParent := node;
							nodeTmp.G := G;
							nodeTmp.F := nodeTmp.H + G;
							heapOpen.Update(nodeTmp)
						END
					END
				END
			END
		END
	END AddAdjacentNodes;
	
	PROCEDURE FindPath(ptStart, ptStop: PointDesc; VAR nodeStop: Node);
	VAR
		node, nodeStart: Node;
		heapOpen: NodeFHeap;
		mapXY: NodeXYMap;
		iStop, nRes: LONGINT;
	BEGIN
	
		nodeStart := NewNode(NIL, ptStart.x, ptStart.y, ptStop);
		nodeStop := NewNode(NIL, ptStop.x, ptStop.y, ptStop);
	
		NEW(heapOpen);
		NEW(mapXY);

		mapXY.Add(nodeStart);
		heapOpen.Add(nodeStart);
		REPEAT
			node := heapOpen.Remove();
			IF node # NIL THEN
				node.bOpen := FALSE;
				AddAdjacentNodes(heapOpen, mapXY, node, ptStop)
			END;
			iStop := mapXY.IndexOf(nodeStop)
		UNTIL ((iStop >= 0) & ~mapXY.GetItem(iStop).bOpen) OR
			(heapOpen.GetCount() = 0);
		
		IF heapOpen.GetCount() = 0 THEN
			nRes := WMDialogs.Message(WMDialogs.TError, A_STAR,
			  "There is no path!", {WMDialogs.ResOk});
			nodeStop := NIL  
		ELSE
			nodeStart := mapXY.GetItem(mapXY.IndexOf(nodeStart));
			nodeStop := mapXY.GetItem(iStop);
			(*KernelLog.String("H: ");
			KernelLog.Int(nodeStart.H, 0);
			KernelLog.Ln;
			KernelLog.String("G: ");
			KernelLog.Int(nodeStop.G, 0);
			KernelLog.Ln;*)
		END;
		
		(*KernelLog.Ln;
		KernelLog.Ln;
		KernelLog.String("nCompAdd: ");
		KernelLog.Int(heapOpen.heap.nCompAdd, 0);
		KernelLog.Ln;
		KernelLog.String("nCompRemove: ");
		KernelLog.Int(heapOpen.heap.nCompRemove, 0);
		KernelLog.Ln;*)
		
	END FindPath;

	PROCEDURE Open*(context: Commands.Context);
	BEGIN
		IF instance # NIL THEN RETURN END;
		InitCosts;
		InitWalkability;
		NEW(instance);
		instance.context := context;
	END Open;

	PROCEDURE Cleanup;
	BEGIN
		IF instance # NIL THEN
			instance.Close
		END
	END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END AStarSet.

AStarSet.Open ~
SystemTools.Free AStarSet Containers ~


