(*
// Copyright (c) www.scratchapixel.com August, 2007
// All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.

	Translated to Active Oberon by Yaroslav Romanchenko (SAGE), 2015

*)

MODULE Lesson7;

IMPORT
	Math, Events, Strings, Files, Commands, PreciseTimer,
	
	(*lib := Lib3D_SSE*)
	lib := Lib3D
	
	;

CONST

	DEBUGLOG = FALSE;
	TESTS = 1;
	EventClass = 3;
	EventSubclass = 3;
	moduleName = "Test";

	R = 0;
	G = 1;
	B = 2;

TYPE

	Vector = lib.Vector;

	ThreadData = POINTER TO RECORD
		id: LONGINT;
		rc: lib.RenderContext;
		nThreadComputedBuckets: LONGINT;
		nSecondaryRays: LONGINT;
	END;

	CalcThread = OBJECT
	VAR
		td: ThreadData;
		bi, by, bx: LONGINT;
		b: lib.Bucket;
		str1, str2: ARRAY 64 OF CHAR;
		FrmLineCur, FrmLinePrev: lib.FrameBuffer;

	PROCEDURE &New(td: ThreadData);
	BEGIN
		SELF.td := td;
		IncActiveThreads(td.rc);
	END New;

	BEGIN {ACTIVE}
		td.nSecondaryRays := 0;
		NEW(FrmLineCur, rc.options.imageWidth);
		NEW(FrmLinePrev, rc.options.imageWidth);
		WHILE GetNextBucket(td.rc, bi) DO
			INC(td.nThreadComputedBuckets);
			(* // compute Bucket coordinates *)
			bx := bi MOD td.rc.nBucketsX; (* // column index *)
			by := bi DIV td.rc.nBucketsY; (* // row index *)
			b.x0 := bx * td.rc.options.bucketSizeX;
			b.x1 := b.x0 + td.rc.options.bucketSizeX - 1;
			b.y0 := by * td.rc.options.bucketSizeY;
			b.y1 := b.y0 + td.rc.options.bucketSizeY - 1;
			
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
			
			b.FrmLineCur := FrmLineCur;
			b.FrmLinePrev := FrmLinePrev;
			lib.RenderBucket(td.rc, b);
			INC(td.nSecondaryRays, b.nSecondaryRays);
		END;
		DecActiveThreads(td.rc);
	END CalcThread;

VAR
	context: Commands.Context;
	rc: lib.RenderContext;
	
(** Vector constructor *)
PROCEDURE vector(x, y, z, dummy = 0 : REAL): Vector;
VAR
	v: Vector;
BEGIN
	v[0] := x;
	v[1] := y;
	v[2] := z;
	v[3] := dummy;
	RETURN v
END vector;
	
PROCEDURE Log(type, code : SHORTINT; msg: ARRAY OF CHAR; showOnKernelLog : BOOLEAN);
VAR message : Events.Message;
BEGIN
	COPY(msg, message);
	Events.AddEvent(moduleName, type, EventClass, EventSubclass, code, message, showOnKernelLog);
END Log;

PROCEDURE ceil(x: REAL): LONGINT;
BEGIN
	RETURN -ENTIER(-x)
END ceil;

PROCEDURE floor(x: REAL): LONGINT;
BEGIN
	RETURN ENTIER(x)
END floor;

PROCEDURE tan(x: REAL): REAL;
BEGIN
	RETURN Math.sin(x) / Math.cos(x)
END tan;

PROCEDURE GetNextBucket(rc: lib.RenderContext; VAR bi: LONGINT): BOOLEAN;
BEGIN 
(*  pthread_mutex_lock(&rc->threadMutex); *)
	BEGIN {EXCLUSIVE}
		bi := rc.nComputedBuckets;
		INC(rc.nComputedBuckets);
	END;
(*  pthread_mutex_unlock(&rc->threadMutex); *)
	RETURN bi < rc.nBucketsTotal;
END GetNextBucket;

PROCEDURE IncActiveThreads(rc: lib.RenderContext);
BEGIN {EXCLUSIVE}
	INC(rc.nActiveThreads)
END IncActiveThreads;

PROCEDURE DecActiveThreads(rc: lib.RenderContext);
BEGIN {EXCLUSIVE}
	DEC(rc.nActiveThreads)
END DecActiveThreads;

PROCEDURE Render(rc: lib.RenderContext);
VAR
	w, h, xmin, ymin, xmax, ymax: LONGINT;
	iThread, iTest: LONGINT;
	threads: POINTER TO ARRAY OF CalcThread;
	td: ThreadData;
	t: HUGEINT;
	str: ARRAY 16 OF CHAR;
BEGIN
	(* compute screen window coordinates *)
	w := rc.options.imageWidth;
	h := rc.options.imageHeight;
	rc.options.frameAspectRatio := w / h;
	IF rc.options.frameAspectRatio > 1 THEN
		rc.screenWindow.left := -rc.options.frameAspectRatio;
		rc.screenWindow.right := rc.options.frameAspectRatio;
		rc.screenWindow.top := 1;
		rc.screenWindow.bottom := -1
	ELSE
		rc.screenWindow.left := -1;
		rc.screenWindow.right := 1;
		rc.screenWindow.top := 1 / rc.options.frameAspectRatio;
		rc.screenWindow.bottom := -1 / rc.options.frameAspectRatio
	END;

	(* transform ray_t to pixel space to world space *)
	rc.dx := (rc.screenWindow.right - rc.screenWindow.left)/w;
	rc.dy := (rc.screenWindow.top - rc.screenWindow.bottom)/h;

	(* compute prim ray_t scaling factor based on field of view *)
	rc.angle := tan(rc.options.fieldOfView * 0.5 * Math.pi / 180.0);

	(* compute crop window coordinates in raster space *)
	xmin := ceil(rc.options.cropWindow.xmin * w);
	ymin := ceil(rc.options.cropWindow.ymin * h);
	xmax := ceil(rc.options.cropWindow.xmax * w);
	ymax := ceil(rc.options.cropWindow.ymax * h);
	
	rc.nThreadsTotal := 1;
	
	WHILE rc.nThreadsTotal < 9 DO
	
		NEW(threads, rc.nThreadsTotal);
	
		rc.nBucketsX := rc.nThreadsTotal * 2;
		rc.nBucketsY := rc.nThreadsTotal * 2;
		rc.nBucketsTotal := rc.nBucketsX * rc.nBucketsY;
		rc.options.bucketSizeX := rc.options.imageWidth DIV rc.nBucketsX;
		rc.options.bucketSizeY := rc.options.imageHeight DIV rc.nBucketsY;
		
		context.out.String("nThreadsTotal: ");
		context.out.Int(rc.nThreadsTotal, 1);
		context.out.String(", bucket size: ");
		context.out.Int(rc.options.bucketSizeX, 1);
		context.out.String(" x ");
		context.out.Int(rc.options.bucketSizeY, 1);
		context.out.String(", nBucketsTotal: ");
		context.out.Int(rc.nBucketsTotal, 1);

		t := PreciseTimer.GetTicks();
		
		FOR iTest := 0 TO TESTS - 1 DO
			rc.nComputedBuckets := 0;
			rc.nActiveThreads := 0;
			FOR iThread := 0 TO rc.nThreadsTotal - 1 DO
				NEW(td);
				td.id := iThread;
				td.rc := rc;
				td.nThreadComputedBuckets := 0;
				NEW(threads^[iThread], td)
			END;
			BEGIN {EXCLUSIVE}
				AWAIT(rc.nActiveThreads = 0)
			END;
		END;
		
		Strings.FloatToStr(
			PreciseTimer.GetTime(PreciseTimer.GetTicks() - t) / TESTS, 0, 4, 0, str);
		context.out.String(", time elapsed: ");
		context.out.String(str);
		context.out.Ln;
		context.out.String("nThreadComputedBuckets: [");
		FOR iThread := 0 TO rc.nThreadsTotal - 1 DO
			IF iThread # 0 THEN
				context.out.String(", ");
			END;
			context.out.Int(threads^[iThread].td.nThreadComputedBuckets, 1);
		END;
		context.out.String("]");
		context.out.Ln;
		context.out.String("nSecondaryRays: [");
		FOR iThread := 0 TO rc.nThreadsTotal - 1 DO
			IF iThread # 0 THEN
				context.out.String(", ");
			END;
			context.out.Int(threads^[iThread].td.nSecondaryRays, 1);
		END;
		context.out.String("]");
		context.out.Ln;
		
		rc.nThreadsTotal := rc.nThreadsTotal * 2; 
		
	END;

	lib.GammaCorrection(rc);
	
END Render;

PROCEDURE SaveToFile(pix: lib.FrameBuffer; w: LONGINT; h: LONGINT; CONST dspyName: ARRAY OF CHAR);
VAR
	fileName: ARRAY lib.MAXBUFFER OF CHAR;
	file: Files.File;
	stream: Files.Writer;
	r, g, b: CHAR;
	p: Vector;
	i, j: LONGINT;
BEGIN
	Strings.Concat(dspyName, ".ppm", fileName);
	file := Files.New(fileName);
	IF file # NIL THEN
		Files.OpenWriter(stream, file, 0);
		stream.String("P6"); stream.Char(0DX);
		stream.Int(w, 0); stream.String(" "); stream.Int(h, 0); stream.Char(0DX);
		stream.Int(255, 0); stream.Char(0DX);
		FOR j := 0 TO h - 1 DO
			FOR i := 0 TO w - 1 DO
				p := pix[j * w + i];
				(* // clamp and quantize *)
				lib.clamp(p);
				r := CHR(floor(p[R] * 255 + 0.5));
				g := CHR(floor(p[G] * 255 + 0.5));
				b := CHR(floor(p[B] * 255 + 0.5));
				stream.Char(r);
				stream.Char(g);
				stream.Char(b)
			END
		END;
		stream.Update;
		Files.Register(file)
	ELSE
		context.out.String("can't open ");
		context.out.String(fileName);
		context.out.Ln
	END
END SaveToFile;

(*
//------------------------------------------------------------------------------
// RI API
// Check the RenderMan Interface specification PDF file for more information
//------------------------------------------------------------------------------
*)

PROCEDURE RiBegin(): lib.RenderContext;
BEGIN

	NEW(rc);
	rc.options.imageWidth := 640;
	rc.options.imageHeight := 480;
	rc.options.cropWindow.xmin := 0;
	rc.options.cropWindow.ymin := 0;
	rc.options.cropWindow.xmax := 1;
	rc.options.cropWindow.ymax := 1;
	rc.options.fieldOfView := 45;
	rc.options.gamma := 1.0;
	
	(* Depth of tracing *)
	rc.options.nTracingDepth := 3;
	(* Color distance threshold *)
	rc.options.fAAThreshold := 0.05;
	(* Antialiasing levels *)
	rc.options.nAALevels := 3;

	COPY("untitled", rc.options.displayName);
	
	RETURN rc;
END RiBegin;

PROCEDURE RiEnd;
BEGIN
	(* free((options_t* )rc->options);
	free(rc); *)
END RiEnd;

PROCEDURE RiWorldBegin(rc: lib.RenderContext);
VAR
	tmp: REAL;
	v: Vector;
BEGIN
	(* // check if crop window coordinates are valid *)
	IF rc.options.cropWindow.xmin > rc.options.cropWindow.xmax THEN
		tmp := rc.options.cropWindow.xmin;
		rc.options.cropWindow.xmin := rc.options.cropWindow.xmax;
		rc.options.cropWindow.xmax := tmp
	END;
	IF rc.options.cropWindow.ymin > rc.options.cropWindow.ymax THEN
		tmp := rc.options.cropWindow.ymin;
		rc.options.cropWindow.ymin := rc.options.cropWindow.ymax;
		rc.options.cropWindow.ymax := tmp
	END;
	rc.options.cropWindow.xmin := MIN(1, MAX(0, rc.options.cropWindow.xmin));
	rc.options.cropWindow.ymin := MIN(1, MAX(0, rc.options.cropWindow.ymin));
	rc.options.cropWindow.xmax := MIN(1, MAX(0, rc.options.cropWindow.xmax));
	rc.options.cropWindow.ymax := MIN(1, MAX(0, rc.options.cropWindow.ymax));
	
	(** Create world *)
	rc.clBackground := vector(0.5, 0.62, 0.78);
	rc.nObjects := 4;
	NEW(rc.objects, rc.nObjects);
	rc.objects[0] := lib.CreateObject(vector(0, 0, 15), 3,
		vector(0.5, 0.7, 0.5), lib.GLASS, FALSE);
	rc.objects[1] := lib.CreateObject(vector(-4.5, 4.5, 17), 1.8,
		vector(1, 0.3, 0.3), lib.DIFFUSE, FALSE);
	v := vector(-4, -2, -1.5);
	lib.normalize(v);
	rc.objects[2] := lib.CreateDisk(vector(2, 4.5, 30), 15, v,
		vector(1, 0, 1), lib.MATTE, FALSE);
	rc.light.object := lib.CreateObject(vector(3, 3, 10), 0.5,
		vector(50, 50, 50), lib.MATTE, TRUE);
	rc.objects[3] := rc.light.object;
	
	rc.funcTrace := lib.Trace;
	
END RiWorldBegin;

PROCEDURE RiWorldEnd(rc: lib.RenderContext);
BEGIN
	(* // allocate memory for the frameBuffer *)
	NEW(rc.FrmBuf, rc.options.imageWidth * rc.options.imageHeight);
	Render(rc);
	SaveToFile(rc.FrmBuf, rc.options.imageWidth, rc.options.imageHeight,
		rc.options.displayName);
	(* free(rc.frameBuffer); <-- not needed*)
END RiWorldEnd;

PROCEDURE Main*(c: Commands.Context);
BEGIN
	IF rc = NIL THEN
		context := c;
		rc := RiBegin();
		RiWorldBegin(rc);
		RiWorldEnd(rc);
		RiEnd;
	END;
END Main;

BEGIN
	rc := NIL;
END Lesson7.

Lesson7.Main ~

SystemTools.Free Lesson7 Lib3D Lib3D_SSE ~

Pentium(R) Dual-Core CPU T4200 @ 2.00 GHz (2 cores, 2 threads):

nThreadsTotal: 1, bucket size: 320 x 240, nBucketsTotal: 4, time elapsed:   2.3558
nThreadComputedBuckets: [4]
nSecondaryRays: [36384]
nThreadsTotal: 2, bucket size: 160 x 120, nBucketsTotal: 16, time elapsed:   1.1991
nThreadComputedBuckets: [8, 8]
nSecondaryRays: [26584, 27244]
nThreadsTotal: 4, bucket size: 80 x 60, nBucketsTotal: 64, time elapsed:   1.2955
nThreadComputedBuckets: [27, 14, 9, 14]
nSecondaryRays: [35932, 20848, 13040, 18688]
nThreadsTotal: 8, bucket size: 40 x 30, nBucketsTotal: 256, time elapsed:   1.4348
nThreadComputedBuckets: [60, 46, 57, 39, 10, 6, 17, 21]
nSecondaryRays: [37496, 28664, 33124, 23060, 5528, 3816, 10740, 13656]


Intel Core i5 650 @ 3.20 GHz (2 cores, 4 threads):


