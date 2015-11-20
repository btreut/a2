MODULE W3dExplorer;	(** AUTHOR "TF"; PURPOSE "Simple 3d viewer"; *)

IMPORT
		MathL, Vectors := W3dVectors, Matrix := W3dMatrix, AbstractWorld := W3dAbstractWorld,
		World := W3dWorld, WM := WMWindowManager, Random, Raster, Kernel, KernelLog, Strings,
		ObjectGenerator := W3dObjectGenerator, WMGraphics, WMRectangles;

TYPE
	Explorer = OBJECT (WM.BufferWindow)
	VAR
		lookat: Vectors.TVector3d;
		radius, angle, height : LONGREAL;
		quality : LONGINT;

		mouseKeys : SET;

		world : World.World;

		oldX, oldY : LONGINT;

		random : Random.Generator;
		message : Raster.Image;

		PROCEDURE FillIn;
		VAR x: AbstractWorld.Object;
			v0, v1, v2, v3 : AbstractWorld.Vertex;
			tex : AbstractWorld.Texture;
			timg, img : Raster.Image;
			mode : Raster.Mode;
		BEGIN
			x := world.CreateObject();
		(*	NEW(timg); Raster.Load(timg, "Clown.Pict", res); *)
			timg := WMGraphics.LoadImage("BluebottlePic0.png", TRUE);
			NEW(img); Raster.Create(img, timg.width, timg.height, Raster.BGR565);
			Raster.InitMode(mode, Raster.srcCopy);
			Raster.Copy(timg, img, 0, 0, timg.width, timg.height, 0, 0, mode);
			tex := x.AddTexture(img);
(*			tex := NIL; *)
			v0 := x.AddVertex(Vectors.Vector3d(0,0,0));
			v1 := x.AddVertex(Vectors.Vector3d(100,0,0));
			v2 := x.AddVertex(Vectors.Vector3d(0,100,0));
			v3 := x.AddVertex(Vectors.Vector3d(100,100,0));
			v0.SetUV(0, 0); v1.SetUV(1, 0); v2.SetUV(0, 1); v3.SetUV(1, 1);
			x.AddTriangle(v0, v1, v3, 0FAFH, tex, FALSE, FALSE); x.AddTriangle(v0, v3, v2, 03AFH, tex, FALSE, FALSE);

			v0 := x.AddVertex(Vectors.Vector3d(80,0,1));
			v1 := x.AddVertex(Vectors.Vector3d(80,0,100));
			v2 := x.AddVertex(Vectors.Vector3d(80,100,1));
			v3 := x.AddVertex(Vectors.Vector3d(80,100,100));
			v0.SetUV(0, 0); v1.SetUV(1, 0); v2.SetUV(0, 1); v3.SetUV(1, 1);
			x.AddTriangle(v0, v1, v3, 0FAFH, tex, FALSE, FALSE); x.AddTriangle(v0, v3, v2, 03AFH, tex, FALSE, FALSE);

			world.AddObject(x);
			x := world.CreateObject(); ObjectGenerator.Arrow(Matrix.Identity4x4, 100, 140, 10, 20, 10, x, 0FAF0H); world.AddObject(x);
			x := world.CreateObject(); ObjectGenerator.Arrow(Matrix.PositionMatrix(Vectors.Vector3d(0,0,0),
				Vectors.Cross(Vectors.Vector3d(1,0,0), Vectors.Vector3d(0,1,0)), Vectors.Vector3d(0,1,0)), 100, 140, 10, 20, 10,
				x, 0FFH);
				world.AddObject(x);
			x := world.CreateObject(); ObjectGenerator.Arrow(Matrix.PositionMatrix(Vectors.Vector3d(0,0,0),
					Vectors.Vector3d(0,1,0), Vectors.Vector3d(-1,0,0)), 100, 140, 10, 20, 10,
				x, 0FF0H);
				world.AddObject(x);

			x := world.CreateObject(); ObjectGenerator.Sphere(Matrix.Translation4x4(100, 50, 0), 10, 10, x, 0FAFH); world.AddObject(x);
		END FillIn;

		PROCEDURE &Init*(w, h : LONGINT; alpha : BOOLEAN);
		VAR mc : WMGraphics.BufferCanvas;
		BEGIN
			Init^(w, h, FALSE);
			NEW(random); NEW(canvas, img);
			NEW(world, w, h, 0FFFFFFH); FillIn;
			WM.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("3d Explorer"));
			radius := 2000; angle := 0; height := 0;
			quality := 0;
			NEW(message); Raster.Create(message, 300, 50, Raster.BGRA8888);
			NEW(mc, message); mc.Fill(WMRectangles.MakeRect(0, 0, 300, 50), 0FF80H, WMGraphics.ModeCopy);
			mc.SetColor(LONGINT(0FFFFFFFFH));
			WMGraphics.DrawStringInRect(mc, WMRectangles.MakeRect(0, 0, 300, 50), FALSE,
				WMGraphics.AlignCenter, WMGraphics.AlignTop,
			"Press left mouse button and move mouse to rotate");
			WMGraphics.DrawStringInRect(mc, WMRectangles.MakeRect(0, 25, 300, 50), FALSE,
				WMGraphics.AlignCenter, WMGraphics.AlignTop,
			"Additionally press right button to zoom");
			Render;
		END Init;

		PROCEDURE SpeedCheck;
		VAR i, t1 : LONGINT; t: Kernel.MilliTimer;
				pos, dir, up : Vectors.TVector3d;
		BEGIN
			KernelLog.String("please wait ... ");
			Kernel.SetTimer(t, 0);
			FOR i := 0 TO 359 DO
				radius := 300; angle := i / 180 * 3.14159; height := 50;
				pos := Vectors.VAdd3(lookat, Vectors.Vector3d(MathL.cos(angle) * radius, 0, MathL.sin(angle) * radius)); pos.y := height;
				lookat := Vectors.Vector3d(lookat.x, height, lookat.z);
				dir := Vectors.VNormed3(Vectors.VSub3(lookat, pos));
				up := Vectors.Vector3d(0, 1, 0);
				world.SetCamera(pos, dir, up); world.Render(img, FALSE);
				Invalidate(WMRectangles.MakeRect(0,0,img.width, img.height));
			END;
			t1 := Kernel.Elapsed(t);
			KernelLog.String("Time : "); KernelLog.Int(t1, 5); KernelLog.String("ms"); KernelLog.Ln;
		END SpeedCheck;

		PROCEDURE Render;
		VAR pos, dir, up : Vectors.TVector3d;
		BEGIN
			pos := Vectors.VAdd3(lookat, Vectors.Vector3d(MathL.cos(angle) * radius, 0, MathL.sin(angle) * radius)); pos.y := height;
			lookat := Vectors.Vector3d(lookat.x, height, lookat.z);
			dir := Vectors.VNormed3(Vectors.VSub3(lookat, pos));
			up := Vectors.Vector3d(0, 1, 0);
			world.SetCamera(pos, dir, up); world.Render(img, FALSE);
			canvas.DrawImage(img.width DIV 2 - message.width DIV 2, img.height - message.height,
				message, WMGraphics.ModeSrcOverDst);
			Invalidate(WMRectangles.MakeRect(0,0,img.width, img.height))
		END Render;

		PROCEDURE PointerDown(x, y:LONGINT; keys:SET);
		BEGIN
			mouseKeys := (keys * {0, 1, 2});
			oldX := x; oldY := y;
		END PointerDown;

		PROCEDURE PointerMove(x, y: LONGINT; keys : SET);
		BEGIN
			IF mouseKeys * {0} # {} THEN
				IF mouseKeys * {2} # {} THEN
					radius := radius - (y - oldY) * 10; IF radius < 10 THEN radius := 10 END;
				ELSE
					height := height + (y - oldY)
				END;
				angle := angle - (x - oldX) / img.width * 3.141;
				Render
			END;
			oldX := x; oldY := y
		END PointerMove;

		PROCEDURE PointerUp(x, y:LONGINT; keys:SET);
		BEGIN
			mouseKeys := (keys * {0, 1, 2})
		END PointerUp;

		PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; keysym : LONGINT);
		BEGIN
			IF ucs = ORD("0") THEN world.quality := 0; Render END;
			IF ucs = ORD("1") THEN world.quality := 1; Render END;
			IF ucs = ORD("2") THEN world.quality := 2; Render END;
			IF ucs = ORD("3") THEN world.quality := 3; Render END;
			IF ucs = ORD("s") THEN SpeedCheck END
		END KeyEvent;

		PROCEDURE Close;
		BEGIN
			manager.Remove(SELF)
		END Close;
	END Explorer;

PROCEDURE Open*;
VAR w : Explorer;
BEGIN
	NEW(w, 640, 480, FALSE);
END Open;

END W3dExplorer.


W3dExplorer.Open ~
SystemTools.Free W3dExplorer
SystemTools.Free W3dExplorer W3dWorld W3dRasterizer W3dObjectGenerator W3dAbstractWorld W3dGeometry W3dMatrix W3dVectors~

Keys 0: Affine 1: SubDivision 2: Perspective 3: Wireframe s: Speed-Test
New: Near Plane Clipping (retriangulating); Frustum Object culling with Bounding-Spheres


Compiler.Compile \s W3dVectors.Mod W3dMatrix.Mod W3dGeometry.Mod W3dAbstractWorld.Mod W3dObjectGenerator.Mod
W3dRasterizer.Mod W3dWorld.Mod W3dExplorer.Mod ~

PC.Compile W3dVectors.Mod W3dMatrix.Mod W3dGeometry.Mod W3dAbstractWorld.Mod W3dObjectGenerator.Mod
W3dRasterizer.Mod W3dWorld.Mod W3dExplorer.Mod ~

