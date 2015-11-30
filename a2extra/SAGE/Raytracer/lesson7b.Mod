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
//
//  c++ -o render lesson7b.cpp -O3 -Wall

Translated to Active Oberon by Yaroslav Romanchenko (SAGE) August, 2008
*)

MODULE lesson7b;

(*
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <cmath>
#include <pthread.h>
*)

IMPORT
	Math, Strings, Files, Commands;

(*
#define MAXBUFFER 256
*)

CONST
	MAXBUFFER = 256;

(*
typedef struct vector_t { float x, y, z; };
typedef struct point_t  { float x, y, z; };
typedef struct color_t  { float r, g, b; };
typedef struct ray_t
{
  point_t orig;
  vector_t dir;
};
*)

TYPE
	
	vector_t = RECORD
		x, y, z: REAL;
	END;

	color_t = RECORD
		r, g, b: REAL;
	END;

	ray_t = RECORD
		orig: vector_t;
		dir: vector_t;
	END;

(*
typedef struct cropWindow_t { float xmin, ymin, xmax, ymax; };
typedef struct screenWindow_t { float left, right, top, bottom; };
*)

	cropWindow_t = RECORD
		xmin, ymin, xmax, ymax: REAL;
	END;

	screenWindow_t = RECORD
		left, right, top, bottom: REAL;
	END;

(*
typedef struct options_t
{
  // camera options_t
  uint imageWidth;
  uint imageHeight;
  uint bucketSize;
  cropWindow_t cropWindow;
  float fieldOfView;
  // display options_t
  char displayName[MAXBUFFER];
  float gamma;
  color_t backgroundColor;
};
*)

	options_t = RECORD
		(* // camera options_t *)
		imageWidth: LONGINT;
		imageHeight: LONGINT;
		bucketSize: LONGINT;
		cropWindow: cropWindow_t;
		fieldOfView: REAL;
		(* // display options_t *)
		displayName: ARRAY MAXBUFFER OF CHAR;
		gamma: REAL;
		backgroundColor: color_t;
	END;

(*
typedef struct renderContext_t
{
  const options_t *options;
  // multi-threading related
  uint numBucketsX, numBucketsY, totalNumBuckets;
  uint numComputedBuckets;
  uint numThreads;
  pthread_mutex_t threadMutex;
  // frameBuffer
  color_t *frameBuffer;
  screenWindow_t screenWindow;
  // to compute prim ray_t direction
  float dx, dy;
  float angle;
};
*)

	frameBuffer_t = POINTER TO ARRAY OF color_t;

	renderContext_t = RECORD
		options: options_t;
		(* // multi-threading related *)
		numBucketsX, numBucketsY, totalNumBuckets: LONGINT;
		numComputedBuckets: LONGINT;
		numThreads: LONGINT;
		(* pthread_mutex_t threadMutex; *)
		(* // frameBuffer *)
		frameBuffer: frameBuffer_t;
		screenWindow: screenWindow_t;
		(* // to compute prim ray_t direction *)
		dx, dy: REAL;
		angle: REAL;
	END;

(*
typedef struct threadData_t
{
  uint id;
  renderContext_t *rc;
  uint numBuckets;
};
*)

	threadData_t = RECORD
		id: LONGINT;
		rc: renderContext_t;
		numBuckets: LONGINT;
	END;

(*
typedef struct bucket_t { uint x0, y0, x1, y1; };
*)

	bucket_t = RECORD
		x0, y0, x1, y1: LONGINT;
	END;

	calcThread = OBJECT
	VAR
		alive, terminated: BOOLEAN;
		td: threadData_t;
		bi, by, bx: LONGINT;
		b: bucket_t;

	PROCEDURE &New(td: threadData_t);
	BEGIN
		SELF.td := td;
		alive := TRUE;
		terminated := FALSE
	END New;

	(* PROCEDURE Terminate;
	BEGIN
		alive := FALSE;
		AwaitTerminated
	END Terminate; *)
	
	PROCEDURE AwaitTerminated;
	BEGIN {EXCLUSIVE}
		AWAIT(terminated)
	END AwaitTerminated;

	BEGIN {ACTIVE}
		WHILE alive DO
			alive := getNextBucket(td.rc, bi);
			IF alive THEN
				INC(td.numBuckets);
				(* // compute bucket_t coordinates *)
				bx := bi MOD td.rc.numBucketsX; (* // column index *)
				by := bi DIV td.rc.numBucketsX; (* // row index *)
				b.x0 := bx * td.rc.options.bucketSize;
				b.y0 := by * td.rc.options.bucketSize;
				b.x1 := b.x0 + td.rc.options.bucketSize - 1;
				b.y1 := b.y1 + td.rc.options.bucketSize - 1;
				(* // clip *)
				IF b.x1 > td.rc.options.imageWidth - 1 THEN
					b.x1 := td.rc.options.imageWidth - 1
				END;
				IF b.y1 > td.rc.options.imageHeight - 1 THEN
					b.y1 := td.rc.options.imageHeight - 1
				END;
				renderBucket(td.rc, b)
			END
		END;
		BEGIN {EXCLUSIVE}
			terminated := TRUE
		END
	END calcThread;

(*
options_t options;
renderContext_t *rc = NULL;
*)

VAR
	context: Commands.Context;
	options: options_t;
	rc: renderContext_t;
	ctr: vector_t; (* sphere center *)
	threads: POINTER TO ARRAY OF calcThread;

(*
// use ceil() from std math lib
// use floor() from std math lib
#define CLAMP(x, l, h) (((x) > (h)) ? (h) : (((x) < (l)) ? (l) : (x)))
#define MIN(x, y) (x < y ? x : y)
#define MAX(x, y) (x > y ? x : y)
*)

PROCEDURE ceil(x: REAL): LONGINT;
BEGIN
	RETURN -ENTIER(-x)
END ceil;

PROCEDURE floor(x: REAL): LONGINT;
BEGIN
	RETURN ENTIER(x)
END floor;

PROCEDURE clamp(x, l, h: REAL): REAL;
BEGIN
	IF x > h THEN
		RETURN h
	ELSIF x < l THEN
		RETURN l
	ELSE
		RETURN x
	END
END clamp;

PROCEDURE pow(x, y: REAL): REAL;
BEGIN
	IF x = 0.0 THEN
		RETURN 0.0
	ELSE
		RETURN Math.exp(y * Math.ln(x))
	END
END pow;

PROCEDURE tan(x: REAL): REAL;
BEGIN
	RETURN Math.sin(x) / Math.cos(x)
END tan;

(* // math functions *)

PROCEDURE vecNormalize(VAR v: vector_t);
VAR
	len, lenInv: REAL;
BEGIN
	len := v.x * v.x + v.y * v.y + v.z * v.z;
	IF len > 0.0 THEN
		lenInv := 1.0 / Math.sqrt(len);
		v.x := v.x * lenInv;
		v.y := v.y * lenInv;
		v.z := v.z * lenInv
	END
END vecNormalize;

PROCEDURE vecSub(VAR c: vector_t; a: vector_t; b: vector_t);
BEGIN
	c.x := a.x - b.x;
	c.y := a.y - b.y;
	c.z := a.z - b.z
END vecSub;

PROCEDURE vecDot(a: vector_t; b: vector_t): REAL;
BEGIN
	RETURN a.x*b.x + a.y*b.y + a.z*b.z
END vecDot;

(* PROCEDURE vecLength(v: vector_t): REAL;
BEGIN
	RETURN Math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
END vecLength; *)

(*
/*
// Find roots of a quadratic equation. For floating point computation, this
// algorithm is more robust than the usual quadratic formula.
// Inputs:
//   float a, b, c: quadratic equation coefficients
// Outputs:
//   float r0, r1: solutions (roots) to the quadratic equation
// Return:
//  1 if tthe discriminant is positive, 0 otherwise
*/
static inline 
int solveQuadratic(float a, float b, float c, float *r0, float *r1)
{
  // compute discriminant
  float discrim = b*b - 4.f*a*c;
  if (discrim < 0) // no real roots, return
    return 0;
  // use the quadratic formula to find t0 and t1
  float q;
  if (b < 0) 
    q = -.5f*(b - sqrtf(discrim));
  else
    q = -.5f*(b + sqrtf(discrim));
  *r0 = q/a;
  *r1 = c/q;
  return 1;
}
*)

PROCEDURE solveQuadratic(a: REAL; b: REAL; c: REAL; VAR r0: REAL; VAR r1: REAL): BOOLEAN;
VAR
	discrim, q: REAL;
BEGIN
	(* // compute discriminant *)
	discrim := b * b - 4.0 * a * c;
	IF discrim < 0.0 THEN (* // no real roots, return *)
		RETURN FALSE
	END;
	(* // use the quadratic formula to find t0 and t1 *)
	IF b < 0.0 THEN
		q := -0.5 * (b - Math.sqrt(discrim))
	ELSE
		q := -0.5 * (b + Math.sqrt(discrim))
	END;
	r0 := q/a;
	r1 := c/q;
	RETURN TRUE
END solveQuadratic;


(*
/*
// Compute the intersection of ray and a sphere (algebraic method)
// Inputs:
//  point rayOrig : ray origin
//  point rayDir  : ray direction
//  point ctr     : sphere center
//  float rad     : sphere radius
// Outputs:
//  float t       : intersection distance along the ray
// Return:
//  1 if there's intersection, 0 otherwise
*/
static int intersectSphere(const point_t *rayOrig, const vector_t *rayDir,
  const point_t *ctr, float rad, float *t0, float *t1)
{
#if 0
 return 0;
#else
  point_t o;
  o.x = rayOrig->x - ctr->x;
  o.y = rayOrig->y - ctr->y;
  o.z = rayOrig->z - ctr->z;
  // substitute ray parametric equation into eq 1 and compute
  // coefficients A, B, C
  float a = rayDir->x*rayDir->x + rayDir->y*rayDir->y + rayDir->z*rayDir->z;
  float b = 2*(o.x*rayDir->x + o.y*rayDir->y + o.z*rayDir->z);
  float c = o.x*o.x + o.y*o.y + o.z*o.z - rad*rad;
  return solveQuadratic(a, b, c, t0, t1);
#endif  
}
*)

PROCEDURE intersectSphere(rayOrig: vector_t; rayDir: vector_t; ctr: vector_t; rad: REAL; VAR t0, t1: REAL): BOOLEAN;
VAR
	a, b, c: REAL;
	o: vector_t;
BEGIN
	vecSub(o, rayOrig, ctr);
	(* substitute ray parametric equation into eq 1 and compute *)
	(* coefficients A, B, C *)
	a := vecDot(rayDir, rayDir);
	b := 2 * vecDot(o, rayDir);
	c := vecDot(o, o) - rad * rad;
	RETURN solveQuadratic(a, b, c, t0, t1)
END intersectSphere;

PROCEDURE renderBucket(VAR rc: renderContext_t; b: bucket_t);
VAR
	i, j, nPix: LONGINT;
	t0, t1: REAL;
	ray: ray_t; (* // prim ray *)
BEGIN
	(* context.out.String("renderBucket"); context.out.Ln; *)
	FOR j := b.y0 TO b.y1 DO
		FOR i := b.x0 TO b.x1 DO
			nPix := j * rc.options.imageWidth + i;
			ray.orig.x := 0.0;
			ray.orig.y := 0.0;
			ray.orig.z := 0.0;
			rc.frameBuffer[nPix] := rc.options.backgroundColor;
			ray.dir.x := ((i + 0.5) * rc.dx + rc.screenWindow.left) * rc.angle;
			ray.dir.y := (-(j + 0.5) * rc.dy + rc.screenWindow.top) * rc.angle;
			ray.dir.z := 1;
			vecNormalize(ray.dir); 
			IF intersectSphere(ray.orig, ray.dir, ctr, 1.0, t0, t1) THEN
				rc.frameBuffer[nPix].r := 1.0;
				rc.frameBuffer[nPix].g := 1.0;
				rc.frameBuffer[nPix].b := 1.0
			END
		END
	END
END renderBucket;

PROCEDURE getNextBucket(VAR rc: renderContext_t; VAR bi: LONGINT): BOOLEAN;
BEGIN
(*  pthread_mutex_lock(&rc->threadMutex); *)
	BEGIN {EXCLUSIVE}
		bi := rc.numComputedBuckets;
		INC(rc.numComputedBuckets)
	END;
(*  pthread_mutex_unlock(&rc->threadMutex); *)
	RETURN bi < rc.totalNumBuckets;
END getNextBucket;

PROCEDURE render(VAR rc: renderContext_t);
VAR
	w, h, xmin, ymin, xmax, ymax, i: LONGINT;
	frameAspectRatio: REAL;
	td: threadData_t;
BEGIN
	(* // compute screen window coordinates *)
	w := rc.options.imageWidth;
	h := rc.options.imageHeight;
	frameAspectRatio := w / h;
	IF frameAspectRatio > 1 THEN
		rc.screenWindow.left := -frameAspectRatio;
		rc.screenWindow.right := frameAspectRatio;
		rc.screenWindow.top := 1;
		rc.screenWindow.bottom := -1
	ELSE
		rc.screenWindow.left := -1;
		rc.screenWindow.right := 1;
		rc.screenWindow.top := 1/frameAspectRatio;
		rc.screenWindow.bottom := -1/frameAspectRatio
	END;

	(* // transform ray_t to pixel space to world space *)
	rc.dx := (rc.screenWindow.right - rc.screenWindow.left)/w;
	rc.dy := (rc.screenWindow.top - rc.screenWindow.bottom)/h;

	(* // compute prim ray_t scaling factor based on field of view *)
	rc.angle := tan(rc.options.fieldOfView * 0.5 * Math.pi / 180.0);

	(* // compute crop window coordinates in raster space *)
	xmin := ceil(rc.options.cropWindow.xmin * w);
	ymin := ceil(rc.options.cropWindow.ymin * h);
	xmax := ceil(rc.options.cropWindow.xmax * w);
	ymax := ceil(rc.options.cropWindow.ymax * h);

	rc.numBucketsX := ceil((xmax-xmin)/rc.options.bucketSize);
	rc.numBucketsY := ceil((ymax-ymin)/rc.options.bucketSize);
	rc.totalNumBuckets := rc.numBucketsX * rc.numBucketsY;
	rc.numComputedBuckets := 0;
	rc.numThreads := 2;

	(* // create threads *)
	
	NEW(threads, rc.numThreads);
	FOR i := 0 TO rc.numThreads - 1 DO
		td.id := i;
		td.rc := rc;
		td.numBuckets := 0;
		NEW(threads[i], td);
	END;
	
	context.out.String("Threads created"); context.out.Ln; 
	
	FOR i := 0 TO rc.numThreads - 1 DO
		threads[i].AwaitTerminated
	END;
	
	context.out.String("Threads terminated"); context.out.Ln; 

	(* //gamma correction *)
	IF rc.options.gamma # 1 THEN
		FOR i := 0 TO w * h - 1 DO
			rc.frameBuffer[i].r := pow(rc.frameBuffer[i].r, rc.options.gamma);
			rc.frameBuffer[i].g := pow(rc.frameBuffer[i].g, rc.options.gamma);
			rc.frameBuffer[i].b := pow(rc.frameBuffer[i].b, rc.options.gamma)
		END
	END;
	
	(* //output statistics in XML *)

	(* // free memory
	free(td);
	free(threads); *)
END render;

PROCEDURE saveToFile(pix: frameBuffer_t; w: LONGINT; h: LONGINT; CONST dspyName: ARRAY OF CHAR);
VAR
	fileName: ARRAY MAXBUFFER OF CHAR;
	file: Files.File;
	stream: Files.Writer;
	r, g, b: CHAR;
	p: color_t;
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
				r := CHR(floor(clamp(p.r, 0, 1) * 255 + 0.5));
				g := CHR(floor(clamp(p.g, 0, 1) * 255 + 0.5));
				b := CHR(floor(clamp(p.b, 0, 1) * 255 + 0.5));
				stream.Char(r);
				stream.Char(g);
				stream.Char(b)
			END
		END;
		stream.Update;
		Files.Register(file);
		context.out.String("File ");
		context.out.String(fileName);
		context.out.String(" created");
		context.out.Ln
	ELSE
		context.out.String("can't open ");
		context.out.String(fileName);
		context.out.Ln
	END
END saveToFile;

(*
//------------------------------------------------------------------------------
// RI API
// Check the RenderMan Interface specification PDF file for more information
//------------------------------------------------------------------------------
*)

PROCEDURE RiBegin;
BEGIN
	(* rc = (renderContext_t* )malloc(sizeof(renderContext_t)); *)
	options.imageWidth := 640;
	options.imageHeight := 480;
	options.bucketSize := 32;
	options.cropWindow.xmin := 0;
	options.cropWindow.ymin := 0;
	options.cropWindow.xmax := 1;
	options.cropWindow.ymax := 1;
	options.fieldOfView := 90;
	options.gamma := 1;
	(* char defaultDspyName[MAXBUFFER] = "untitled";
	strcpy((char* )options.displayName, defaultDspyName); *)
	COPY("untitled", options.displayName);
	(* memset(&options.backgroundColor, 0x0, sizeof(color_t)); *)
	options.backgroundColor.r := 0.0;
	options.backgroundColor.g := 0.0;
	options.backgroundColor.b := 0.0
END RiBegin;

PROCEDURE RiEnd;
BEGIN
	(* free((options_t* )rc->options);
	free(rc); *)
END RiEnd;

PROCEDURE RiWorldBegin;
VAR
	tmp: REAL;
BEGIN
	(* // check if crop window coordinates are valid *)
	IF options.cropWindow.xmin > options.cropWindow.xmax THEN
		tmp := options.cropWindow.xmin;
		options.cropWindow.xmin := options.cropWindow.xmax;
		options.cropWindow.xmax := tmp
	END;
	IF options.cropWindow.ymin > options.cropWindow.ymax THEN
		tmp := options.cropWindow.ymin;
		options.cropWindow.ymin := options.cropWindow.ymax;
		options.cropWindow.ymax := tmp
	END;
	options.cropWindow.xmin := MIN(1, MAX(0, options.cropWindow.xmin));
	options.cropWindow.ymin := MIN(1, MAX(0, options.cropWindow.ymin));
	options.cropWindow.xmax := MIN(1, MAX(0, options.cropWindow.xmax));
	options.cropWindow.ymax := MIN(1, MAX(0, options.cropWindow.ymax));
	rc.options := options
END RiWorldBegin;

PROCEDURE RiWorldEnd;
BEGIN
	(* // allocate memory for the frameBuffer *)
	NEW(rc.frameBuffer, rc.options.imageWidth * rc.options.imageHeight);
	render(rc);
	saveToFile(rc.frameBuffer, rc.options.imageWidth, rc.options.imageHeight,
		rc.options.displayName);
	(* free(rc.frameBuffer); <-- not needed*)
END RiWorldEnd;

PROCEDURE init;
BEGIN
	ctr.x := 0.0; ctr.y := 0.0; ctr.z := 2.0;
END init;

PROCEDURE main*(c: Commands.Context);
BEGIN
	context := c;
	RiBegin;
	RiWorldBegin;
	RiWorldEnd;
	RiEnd
END main;

BEGIN
	init
END lesson7b.main~

SystemTools.Free lesson7b~