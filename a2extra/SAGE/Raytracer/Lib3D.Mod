(**
	3D library by Yaroslav Romanchenko (SAGE), 2015
*)

MODULE Lib3D;

IMPORT

	Math, Strings, Commands;

CONST

	MAXBUFFER* = 256;

	(* Material types *)
	MATTE* = 1;
	DIFFUSE* = 2;
	GLASS* = 3;

	INFINITY = 1.0E6;
	EPSILON = 1.0E-6;

	X = 0;
	Y = 1;
	Z = 2;

	R = 0;
	G = 1;
	B = 2;

	px00 = 0;
	px10 = 1;
	px01 = 2;
	px11 = 3;

	TEST_CULL = TRUE;

TYPE

	(**
		Base type that may represent
		a point (x,y,z), a vector (x,y,z),
		a color (r,g,b)
		or any set of 4 values
		for that vector operations should
		be applied.
		From this point of view 4th member
		involved in all operations also.
	*)
	Vector* = ARRAY 4 OF REAL;

	(**
		Ray of light with origin point
		and direction
	*)
	Ray* = RECORD
		pt*, vn*: Vector;
	END;

	(**
		Hit structure that holds full information
		about hit: distance, point and normal
	*)
	Hit = RECORD
		mint, maxt: REAL;
		pt, vn: Vector;
		object: Object;
	END;

	(* Base object is usually a sphere or light source *)
	Object* = OBJECT
	VAR
		next: Object;										(* Next object in list*)
		pt: Vector;											(* Object center *)
		color: Vector;										(* Color *)
		iMaterial: INTEGER;							(* Material *)
		bLight: BOOLEAN;									(* Light source or not *)
		fRefractionIndex: REAL;					(* Index of refraction *)
		intersect: IntersectFunction;		(* Intersection test function *)

		r, r2: REAL;											(* Radius and square radius of sphere *)

	PROCEDURE &New(
		CONST pt: Vector; r: REAL; CONST color: Vector;
		iMaterial: INTEGER; bLight: BOOLEAN);
	BEGIN
		SELF.pt := pt;
		SELF.color := color;
		SELF.iMaterial := iMaterial;
		SELF.bLight := bLight;
		fRefractionIndex := 1.3;

		SELF.r := r;
		r2 := r * r;
		intersect := IntersectSphereGeometric

	END New;

	END Object;

	Cone = OBJECT(Object)
	VAR
		h: REAL;

	PROCEDURE &New(
		CONST pt: Vector; r: REAL; CONST color: Vector;
		iMaterial: INTEGER; bLight: BOOLEAN);
	BEGIN
		New^(pt, r, color, iMaterial, bLight);
		intersect := IntersectConeQuadratic;
	END New;

	END Cone;

	Cylinder = OBJECT(Object)
	VAR
		zmin, zmax: REAL;

	PROCEDURE &New(
		CONST pt: Vector; r: REAL; CONST color: Vector;
		iMaterial: INTEGER; bLight: BOOLEAN);
	BEGIN
		New^(pt, r, color, iMaterial, bLight);
		intersect := IntersectCylinderQuadratic;
	END New;

	END Cylinder;

	Disk = OBJECT(Object)
	VAR
		vn: Vector;

	PROCEDURE &New(
		CONST pt: Vector; r: REAL; CONST color: Vector;
		iMaterial: INTEGER; bLight: BOOLEAN);
	BEGIN
		New^(pt, r, color, iMaterial, bLight);
		intersect := IntersectDisk;
	END New;

	END Disk;

	(**
		Light source
	*)
	Light = RECORD
		object*: Object
	END;

	CropWindow* = RECORD
		xmin*, ymin*, xmax*, ymax*: REAL;
	END;

	Options* = RECORD
		(* camera options *)
		imageWidth*: LONGINT;
		imageHeight*: LONGINT;
		frameAspectRatio*: REAL;
		bucketSizeX*, bucketSizeY*: LONGINT;
		cropWindow*: CropWindow;
		fieldOfView*: REAL;
		nTracingDepth*: LONGINT; (* Depth of tracing *)
		(* Antialiasing options *)
		fAAThreshold*: REAL; (* Color distance threshold *)
		nAALevels*: LONGINT; (* Antialiasing levels *)
		bShowAAPixels*: BOOLEAN;
		(* display options *)
		displayName*: ARRAY MAXBUFFER OF CHAR;
		gamma*: REAL;
	END;

	ScreenWindow* = RECORD
		left*, right*, top*, bottom*: REAL;
	END;

	FrameBuffer* = POINTER TO ARRAY OF Vector;

	TraceFunction* = PROCEDURE {DELEGATE}
		(rc: RenderContext; ray: Ray; depth: LONGINT): Vector;
	IntersectFunction* = PROCEDURE {DELEGATE}
		(object: Object; CONST ray: Ray; VAR hit: Hit): BOOLEAN;

	RenderContext* = POINTER TO RECORD
		options*: Options;
		(* multi-threading related *)
		nBucketsX*, nBucketsY*: LONGINT;
		nComputedBuckets*, nBucketsTotal*: LONGINT;
		nActiveThreads*, nThreadsTotal*: LONGINT;
		(* frame buffer *)
		FrmBuf*: FrameBuffer;
		screenWindow*: ScreenWindow;
		(* to compute prim ray_t direction *)
		dx*, dy*: REAL;
		angle*: REAL;
		(* world *)
		objects*: Object;
		light*: Light;
		clBackground*: Vector;
		funcTrace*: TraceFunction;
	END;

	Bucket* = RECORD
		x0*, y0*, x1*, y1*: LONGINT;
		nSecondaryRays*: LONGINT;
		(* Line pixel buffers for antialising purposes
		  They will be initated once per computing thread *)
		FrmLineCur*, FrmLinePrev*: FrameBuffer;
	END;

VAR
	ZeroVector-,
	XAxisVector-, YAxisVector-, ZAxisVector-,
	XAxisVectorNeg-, YAxisVectorNeg-, ZAxisVectorNeg-: Vector;
	Black-, Red-, Green-, Yellow-,
	Blue-, Magenta-, Cyan-, White-: Vector;

	context: Commands.Context;

(** Vector operations *)

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

(** Vector length
	length := Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
*)
PROCEDURE length(CONST v: Vector): REAL;
BEGIN
	RETURN Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3]);
END length;

(** Vector normalization
	fLen2 := v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3];
	IF fLen2 > 0 THEN
		fInvSqrt := 1 / Math.sqrt(fLen2);
		v[0] := v[0] * fInvSqrt;
		v[1] := v[1] * fInvSqrt;
		v[2] := v[2] * fInvSqrt;
		v[3] := v[3] * fInvSqrt
	END
*)
PROCEDURE normalize*(VAR v: Vector);
VAR
	fLen2, fInvSqrt: REAL;
BEGIN
	fLen2 := v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3];
	IF fLen2 > 0 THEN
		fInvSqrt := 1 / Math.sqrt(fLen2);
		v[0] := v[0] * fInvSqrt;
		v[1] := v[1] * fInvSqrt;
		v[2] := v[2] * fInvSqrt;
		v[3] := v[3] * fInvSqrt
	END
END normalize;

(** Vector dot product
	fDot := v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3]
*)
PROCEDURE "+*"(CONST v1, v2: Vector): REAL;
BEGIN
	RETURN v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3]
END "+*";

(** Vector cross product
	v3[0] := v1[1] * v2[2] - v1[2] * v2[1];
	v3[1] := v1[2] * v2[0] - v1[0] * v2[2];
	v3[2] := v1[0] * v2[1] - v1[1] * v2[0]
*)
PROCEDURE cross(VAR v3: Vector; CONST v1, v2: Vector);
BEGIN
	v3[0] := v1[1] * v2[2] - v1[2] * v2[1];
	v3[1] := v1[2] * v2[0] - v1[0] * v2[2];
	v3[2] := v1[0] * v2[1] - v1[1] * v2[0]
END cross;

(** Vector multipliation with scalar *)
PROCEDURE "*"(CONST v: Vector; f: REAL): Vector;
BEGIN
	RETURN vector(v[0] * f, v[1] * f, v[2] * f, v[3] * f)
END "*";
PROCEDURE "*"(f: REAL; CONST v: Vector): Vector;
BEGIN
	RETURN vector(v[0] * f, v[1] * f, v[2] * f, v[3] * f)
END "*";

(** Vector division by scalar *)
PROCEDURE "/"(CONST v: Vector; f: REAL): Vector;
BEGIN
	RETURN vector(v[X] / f, v[Y] / f, v[Z] / f, v[3] / f)
END "/";

(** Vector multiplication
	v3 := vector(v1[0] * v2[0], v1[1] * v2[1], v1[2] * v2[2], v1[3] * v2[3])
*)
PROCEDURE "*"(CONST v1, v2: Vector): Vector;
BEGIN
	RETURN vector(v1[0] * v2[0], v1[1] * v2[1], v1[2] * v2[2], v1[3] * v2[3])
END "*";

(** Vector substraction
	v3 := vector(v1[0] - v2[0], v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3])
*)
PROCEDURE "-"(CONST v1, v2: Vector): Vector;
BEGIN
	RETURN vector(v1[0] - v2[0], v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3])
END "-";

(** Vector addition
	v3 := vector(v1[0] + v2[0], v1[1] + v2[1], v1[2] + v2[2], v1[3] + v2[3])
*)
PROCEDURE "+"(CONST v1, v2: Vector): Vector;
BEGIN
	RETURN vector(v1[0] + v2[0], v1[1] + v2[1], v1[2] + v2[2], v1[3] + v2[3])
END "+";

(** Vector negation *)
PROCEDURE "-"(VAR v: Vector): Vector;
BEGIN
	RETURN vector(-v[0], -v[1], -v[2], -v[3])
END "-";

(** Point to point distance
	v := p1 - p2;
	dist := Math.sqrt(v +* v)
*)
PROCEDURE dist*(CONST p1, p2: Vector): REAL;
VAR
	v: Vector;
BEGIN
	v := p1 - p2;
	RETURN Math.sqrt(v +* v)
END dist;

(** Color clamp *)
PROCEDURE clamp*(VAR c: Vector);
BEGIN
	IF c[R] > 1.0 THEN
		c[R] := 1.0
	END;
	IF c[G] > 1.0 THEN
		c[G] := 1.0
	END;
	IF c[B] > 1.0 THEN
		c[B] := 1.0
	END
END clamp;

PROCEDURE ComputePrimaryRay*(rc: RenderContext; i, j: LONGINT; VAR ray: Ray);
VAR
	f: REAL;
	angle: REAL;
	dx: REAL;
	dy: REAL;
BEGIN
	f := rc.options.fieldOfView * 0.5 * Math.pi / 180.0;
	angle := Math.sin(f) / Math.cos(f);
	ray.pt := ZeroVector;
	dx := 2 * rc.options.frameAspectRatio / rc.options.imageWidth;
	dy := 2 / rc.options.imageHeight;
	ray.vn := vector(angle * ((i + 0.5) * dx - rc.options.frameAspectRatio),
		angle * (-(j + 0.5) * dy + 1), 1);
	normalize(ray.vn);
END ComputePrimaryRay;

PROCEDURE ComputeSecondaryRays*(rc: RenderContext;
	i, j, fDelta: REAL; VAR ray00, ray10, ray01, ray11: Ray);
VAR
	f: REAL;
	angle: REAL;
	dx: REAL;
	dy: REAL;
BEGIN
	f := rc.options.fieldOfView * 0.5 * Math.pi / 180.0;
	angle := Math.sin(f) / Math.cos(f);
	ray00.pt := ZeroVector;
	ray10.pt := ZeroVector;
	ray01.pt := ZeroVector;
	ray11.pt := ZeroVector;
	dx := 2 * rc.options.frameAspectRatio / rc.options.imageWidth;
	dy := 2 / rc.options.imageHeight;

	ray00.vn := vector(angle * ((i - fDelta) * dx - rc.options.frameAspectRatio),
		angle * (-(j - fDelta) * dy + 1), 1);
	ray10.vn := vector(angle * ((i + fDelta) * dx - rc.options.frameAspectRatio),
	  angle * (-(j - fDelta) * dy + 1), 1);
	ray01.vn := vector(angle * ((i - fDelta) * dx - rc.options.frameAspectRatio),
	  angle * (-(j + fDelta) * dy + 1), 1);
	ray11.vn := vector(angle * ((i + fDelta) * dx - rc.options.frameAspectRatio),
	  angle * (-(j + fDelta) * dy + 1), 1);

	normalize(ray00.vn);
	normalize(ray10.vn);
	normalize(ray01.vn);
	normalize(ray11.vn);
END ComputeSecondaryRays;

(** Ray-sphere intersection using geometric method.
	Is a bit faster than quadratic method.
*)
PROCEDURE IntersectSphereGeometric(object: Object; CONST ray: Ray; VAR hit: Hit): BOOLEAN;
VAR
	vRayPtObjPt: Vector;
	fRayPtObjPtDist2, fProjToRayDist, fPerpLen2, fSurfDist2, t: REAL;
	bOutside: BOOLEAN;
BEGIN
	(* Vector from ray point to sphere center point (not normalized) *)
	vRayPtObjPt := object.pt - ray.pt;
	(* Square distance from ray point to sphere center point *)
	fRayPtObjPtDist2 := vRayPtObjPt +* vRayPtObjPt;
	(* Distance to point on ray closest to sphere center,
		line drawn from sphere center is perpendicular to ray in this point
		(length of projection of vRayPtObjPt vector to ray) *)
	fProjToRayDist := vRayPtObjPt +* ray.vn;
	(* Ray point is outside of sphere or inside *)
	bOutside := (fRayPtObjPtDist2 > object.r2);

	IF (fProjToRayDist < 0) & bOutside THEN
		RETURN FALSE
	END;

	(* Square distance from sphere center to closest point on ray.
		Just use Pythagorean theorem here *)
	fPerpLen2 := fRayPtObjPtDist2 - fProjToRayDist * fProjToRayDist;
	(* Square distance from closest point on ray to sphere surface *)
	fSurfDist2 := object.r2 - fPerpLen2;

	IF fSurfDist2 < 0 THEN
		RETURN FALSE
	END;

	(* Distance from ray point to sphere surface hit point *)
	IF bOutside THEN
		t := fProjToRayDist - Math.sqrt(fSurfDist2)
	ELSE
		t := fProjToRayDist + Math.sqrt(fSurfDist2)
	END;

	IF (t < 0) OR (t > hit.maxt) THEN
		RETURN FALSE
	END;

	hit.maxt := t;
	hit.object := object;
	hit.pt := ray.pt + ray.vn * t;
	hit.vn := hit.pt - object.pt;
	normalize(hit.vn);

	RETURN TRUE
END IntersectSphereGeometric;

PROCEDURE IntersectTriangle*(CONST va, vb, vc: Vector; rayOrig, rayDir: Vector; VAR t, u, v: REAL): BOOLEAN;
VAR
	v0_to_v1, v0_to_v2, n, v0_to_p, ab_x_ap, v1_to_v2, v1_to_p, bc_x_bp, v2_to_p, ca_x_cp: Vector;
	nd, d, v_num, u_num, denom: REAL;
	p: Vector;
BEGIN
	(* compute triangle's normal *)
	v0_to_v1 := vb - va;
	v0_to_v2 := vc - va;
	(* doesn't need to normalized *)
	cross(n, v0_to_v1, v0_to_v2);

	(*
		step 1: find P
	*)

	(* if ray and plane are parallel, they don't intersect ! *)
	nd := n +* rayDir;
	IF nd = 0.0 THEN
		RETURN FALSE
	END;

	d := n +* va;
	t := (d - (n +* rayOrig)) / nd;
	IF t < 0.0 THEN
		RETURN FALSE (* triangle is behind the ray, return *)
	END;

	p[0] := rayOrig[0] + t * rayDir[0];
	p[1] := rayOrig[1] + t * rayDir[1];
	p[2] := rayOrig[2] + t * rayDir[2];

	(*
		step 2: inside-outside test
	*)

	(* edge 1 *)

	v0_to_p := p - va;
	cross(ab_x_ap, v0_to_v1, v0_to_p);
	v_num := n +* ab_x_ap;
	IF v_num < 0.0 THEN
		RETURN FALSE
	END;

	(* // edge 2 *)

	v1_to_v2 := vc - vb;
	v1_to_p := p - vb;
	cross(bc_x_bp, v1_to_v2, v1_to_p);
	IF n +* bc_x_bp < 0 THEN
		RETURN FALSE
	END;

	(* // edge 3 *)

	v2_to_p := p - vc;
	(* // reuse v0_to_v2 instead of computing v2_to_v0 but then inverse the order
	// in the cross product.
	// ca_x_cp=v0_to_v2 x v2_to_p ==>
	// ca_x_cp=v2_to_p  x v0_to_v2 *)
	cross(ca_x_cp, v2_to_p, v0_to_v2);
	u_num := n +* ca_x_cp;
	IF u_num < 0 THEN
		RETURN FALSE
	END;

	(* compute barycentric coordinates *)
	denom := n +* n;
	u := u_num / denom;
	v := v_num / denom;

	RETURN TRUE

END IntersectTriangle;

(* Implementation of the Moller-Trumbore algorithm *)
PROCEDURE IntersectTriangleMollerTrumbore*(CONST ptA, ptB, ptC: Vector; ray: Ray; VAR t, u, v: REAL): BOOLEAN;
VAR
	vE1, vE2: Vector; (* Triangle edges *)
	vP, vT, vQ: Vector;
	fDet, fInvDet: REAL;
BEGIN

	vE1 := ptB - ptA;
	vE2 := ptC - ptA;

	cross(vP, ray.vn, vE2);
	fDet := vE1 +* vP;

	IF TEST_CULL THEN
		IF fDet < EPSILON THEN
			RETURN FALSE
		END
	ELSE
		IF (fDet > -EPSILON) & (fDet < EPSILON) THEN
			RETURN FALSE
		END
	END;

	(* prepare to compute u *)
	vT := ray.pt - ptA;

	(* do not mult by fInvDet *)
	u := vT +* vP;

	IF (u < 0) OR (u > fDet) THEN (* test bounds using fDet *)
		RETURN FALSE
	END;

	(* prepare to compute v *)
	cross(vQ, vT, vE1);

	(* do not mult by inv_det *)
	v := ray.vn +* vQ;

	IF (v < 0) OR (v > fDet) OR (u + v > fDet) THEN (* test bounds using fDet *)
		RETURN FALSE
	END;

	(* ray intersects triangle, compute t and normalize u and v *)
	fInvDet := 1.0 / fDet;

	t := vE1 +* vQ;

	t := t * fInvDet;
	u := u * fInvDet;
	v := v * fInvDet;

	RETURN TRUE

END IntersectTriangleMollerTrumbore;


(**
	Find roots of a quadratic equation. For floating point computation, this
	algorithm is more robust than the usual quadratic formula.
	Inputs:
		float a, b, c: quadratic equation coefficients
	Outputs:
		float r0, r1: solutions (roots) to the quadratic equation
	Return:
		TRUE if the discriminant is positive, FALSE otherwise
*)
PROCEDURE SolveQuadratic(a, b, c: REAL; VAR r0, r1: REAL): BOOLEAN;
VAR
	fDiscrim, q, f: REAL;
BEGIN
	(* Compute discriminant *)
	fDiscrim := b * b - 4.0 * a * c;
	IF fDiscrim < 0 THEN
		(* No real roots, return *)
		RETURN FALSE
	END;
	(* Use the quadratic formula to find r0 and r1 *)
	IF b < 0 THEN
		q := -0.5 * (b - Math.sqrt(fDiscrim))
	ELSE
		q := -0.5 * (b + Math.sqrt(fDiscrim))
	END;
	r0 := q / a;
	r1 := c / q;
	(* Swap roots if r0 > r1, but, only if r1 > 0 *)
	IF (r1 > 0) & (r0 > r1) THEN
		f := r0;
		r0 := r1;
		r1 := f
	END;
	RETURN TRUE
END SolveQuadratic;

(**
	Compute ray-cone intersection (algebraic method)
*)
PROCEDURE IntersectConeQuadratic(object: Object; CONST ray: Ray; VAR hit: Hit): BOOLEAN;
VAR
	cone: Cone;
	a, b, c, k, h, pz, t0, t1: REAL;
	o: Vector;
BEGIN
	cone := object(Cone);
(*
	vecSub(o, ptRay, ptCenter);
	k := radius / height;
	k := k * k;
	h := o.z - height;
	(* substitute ray parametric equation into eq 1 and compute *)
	a := vnRay.x * vnRay.x + vnRay.y * vnRay.y - k * vnRay.z * vnRay.z;
	b := 2 * (vnRay.x * o.x + vnRay.y * o.y - k * vnRay.z * h);
	c := o.x * o.x + o.y * o.y - k * h * h;
*)
	o := ray.pt - cone.pt;
	(* Compute quadratic cone coefficients *)
	k := cone.r / cone.h;
	k := k * k;
	h := o[2] - cone.h;
	a := ray.vn[0] * ray.vn[0] + ray.vn[1] * ray.vn[1] - k * ray.vn[2] * ray.vn[2];
	b := 2 * (ray.vn[0] * o[0] + ray.vn[1] * o[1] - k * ray.vn[2] * h);
	c := o[0] * o[0] + o[1] * o[1] - k * h * h;

	IF ~SolveQuadratic(a, b, c, t0, t1) THEN
		RETURN FALSE
	END;

	IF (t0 < 0) OR (t0 > hit.maxt) THEN
		RETURN FALSE
	END;
	hit.maxt := t0;
	hit.object := object;
	hit.pt := ray.pt + ray.vn * t0;
	(* TODO: compute hit.vn *)
	hit.vn := ZAxisVector;

	(* compute p.z *)
	pz := o[2] + t0 * ray.vn[2];
	RETURN (pz >= 0) & (pz <= cone.h)
END IntersectConeQuadratic;

(**
	Compute the intersection of ray and a cylinder (algebraic method)
*)
PROCEDURE IntersectCylinderQuadratic(object: Object; CONST ray: Ray; VAR hit: Hit): BOOLEAN;
VAR
	cylinder: Cylinder;
	a, b, c, pz, t0, t1: REAL;
	o: Vector;
BEGIN
	cylinder := object(Cylinder);
(*
	vecSub(o, ptRay, ptCenter);
	(* substitute ray parametric equation into eq 1 and compute *)
	a := vnRay.x * vnRay.x + vnRay.y * vnRay.y;
	b := 2 * (vnRay.x * o.x + vnRay.y * o.y);
	c := o.x * o.x + o.y * o.y - radius * radius;
*)
	o := ray.pt - cylinder.pt;
	(* substitute ray parametric equation into eq 1 and compute *)
	a := ray.vn[0] * ray.vn[0] + ray.vn[1] * ray.vn[1];
	b := 2 * (ray.vn[0] * o[0] + ray.vn[1] * o[1]);
	c := o[0] * o[0] + o[1] * o[1] - cylinder.r * cylinder.r;

	IF ~SolveQuadratic(a, b, c, t0, t1) THEN
		RETURN FALSE
	END;

	IF (t0 < 0) OR (t0 > hit.maxt) THEN
		RETURN FALSE
	END;
	hit.maxt := t0;
	hit.object := object;
	hit.pt := ray.pt + ray.vn * t0;
	(* TODO: compute hit.vn *)
	hit.vn := ZAxisVector;

	(* compute p.z *)
	pz := o[2] + t0 * ray.vn[2];
	RETURN (pz >= cylinder.zmin) & (pz <= cylinder.zmax)
END IntersectCylinderQuadratic;

(**
	Compute ray-plane intersection
*)
PROCEDURE IntersectPlane(CONST pt, vn: Vector; CONST ray: Ray; VAR t: REAL): BOOLEAN;
VAR
	denom, d: REAL;
BEGIN
	(* If the ray and the plane are parallel, reject intersection *)
	denom := ray.vn +* vn;
	IF ABS(denom) < EPSILON THEN
		RETURN FALSE
	END;
	(* Compute d (we assume the plane normal is a unit vector) *)
	d := vn +* pt;
	(* Compute distance t *)
	t := (d - (ray.pt +* vn)) / denom;
	RETURN t > 0
END IntersectPlane;

PROCEDURE IntersectDisk(object: Object; CONST ray: Ray; VAR hit: Hit): BOOLEAN;
VAR
	disk: Disk;
	t: REAL;
	phit: Vector;

	PROCEDURE Compute(vn: Vector): BOOLEAN;
	BEGIN
		IF ray.vn +* vn < 0 THEN
			vn := -vn
		END;
		phit := (ray.pt + t * ray.vn) - disk.pt;
		IF disk.r2 >= phit +* phit THEN
			hit.maxt := t;
			hit.object := object;
			hit.pt := phit;
			hit.vn := vn;
			RETURN TRUE
		END;
		RETURN FALSE
	END Compute;

BEGIN
	disk := object(Disk);
	
	(*
	IF disk.vn +* ray.vn < 0 THEN
		IF IntersectPlane(disk.pt, -disk.vn, ray, t) &
			~((t < 0) OR (t > hit.maxt))
		THEN
			RETURN Compute(-disk.vn)
		END
	ELSIF disk.vn +* ray.vn > 0 THEN
		IF IntersectPlane(disk.pt, disk.vn, ray, t) &
			~((t < 0) OR (t > hit.maxt))
		THEN
			RETURN Compute(disk.vn)
		END
	END;
	*)
	
	IF IntersectPlane(disk.pt, disk.vn, ray, t) &
		~((t < 0) OR (t > hit.maxt))
	THEN
		RETURN Compute(disk.vn)
	(*ELSIF IntersectPlane(disk.pt, disk.vn, ray, t) &
		~((t < 0) OR (t > hit.maxt))
	THEN
		RETURN Compute(disk.vn)*)
	END;
	
	RETURN FALSE
END IntersectDisk;

(** Ray-sphere intersection using quadratic method.
	Is a bit slower than geometric method.
*)
PROCEDURE IntersectSphereQuadratic(object: Object; CONST ray: Ray; VAR hit: Hit): BOOLEAN;
VAR
	a, b, c, t0, t1: REAL;
	o: Vector;
BEGIN
	o := ray.pt - object.pt;
	a := ray.vn +* ray.vn;
	b := 2 * (o +* ray.vn);
	c := (o +* o) - object.r2;

	IF ~SolveQuadratic(a, b, c, t0, t1) THEN
		RETURN FALSE
	END;

	IF (t0 < 0) OR (t0 > hit.maxt) THEN
		RETURN FALSE
	END;
	hit.maxt := t0;
	hit.object := object;
	hit.pt := ray.pt + ray.vn * t0;
	hit.vn := hit.pt - object.pt;
	normalize(hit.vn);

	RETURN TRUE
END IntersectSphereQuadratic;


PROCEDURE snell(CONST incidentRay: Vector; CONST surfaceNormal: Vector; n1: REAL; n2: REAL; VAR reflectionDir: Vector; VAR refractionDir: Vector);
VAR
	n1n2: REAL;
	cost1: REAL;
	cost2: REAL;
BEGIN
	n1n2 := n1 / n2;

	cost1 := incidentRay +* surfaceNormal;

	cost2 := Math.sqrt(1.0 - (n1n2 * n1n2) * (1.0 - cost1 * cost1));
	reflectionDir := incidentRay - surfaceNormal * (2 * cost1);
	refractionDir := incidentRay * n1n2 + surfaceNormal * (cost2 - n1n2 * cost1)
END snell;

PROCEDURE fresnel(etai: REAL; etat: REAL; cosi: REAL; cost: REAL; VAR Kr: REAL);
VAR
	Rp: REAL;
	Rs: REAL;
BEGIN
	Rp := ((etat * cosi) - (etai * cost)) / ((etat * cosi) + (etai * cost));
	Rs := ((etai * cosi) - (etat * cost)) / ((etai * cosi) + (etat * cost));
	Kr := (Rp * Rp + Rs * Rs) * 0.5;
END fresnel;

PROCEDURE Trace*(rc: RenderContext; ray: Ray; depth: LONGINT): Vector;
VAR
	bias: REAL;
	obj: Object;
	hit: Hit;
	reflectionRay, refractionRay: Ray;
	cosi: REAL;
	cost: REAL;
	Kr: REAL;
	reflectionColor: Vector;
	refractionColor: Vector;
	lightColor: Vector;
	shadowRay: Ray;
	isInShadow: BOOLEAN;
	exit: BOOLEAN;
	len: REAL;
	LdotN: REAL;
BEGIN
	IF depth > rc.options.nTracingDepth THEN
		RETURN rc.clBackground
	END;

	bias := 0.001;
	hit.maxt := INFINITY;
	hit.mint := 0;
	hit.object := NIL;

	obj := rc.objects;
	WHILE obj # NIL DO
		IF obj.intersect(obj, ray, hit) THEN
			(*IF hit.dist < hitMin.dist THEN
				hitMin := hit;
				object := obj
			END*)
		END;
		obj := obj.next
	END;

	IF hit.object = NIL THEN
		RETURN rc.clBackground
	END;

	IF hit.object.iMaterial = GLASS THEN
		(* compute reflection and refraction direction *)
		reflectionRay.pt := hit.pt + hit.vn * bias;
		refractionRay.pt := hit.pt - hit.vn * bias;
		snell(ray.vn, -hit.vn, 1.0, hit.object.fRefractionIndex,
			reflectionRay.vn, refractionRay.vn);
		normalize(reflectionRay.vn);
		normalize(refractionRay.vn);

		cosi := ray.vn +* (-hit.vn);
		cost := refractionRay.vn +* (-hit.vn);

		fresnel(1.0, hit.object.fRefractionIndex, cosi, cost, Kr);
		IF Kr < 0.0 THEN
			Kr := 0.0
		ELSIF Kr > 1.0 THEN
			Kr := 1.0
		END;
		reflectionColor := Trace(rc, reflectionRay, depth + 1);
		refractionColor := Trace(rc, refractionRay, depth + 1);
		RETURN hit.object.color * refractionColor * (1 - Kr) + reflectionColor * Kr
	END;

	IF hit.object.iMaterial = MATTE THEN
		RETURN hit.object.color
	END;

	isInShadow := FALSE;
	shadowRay.pt := hit.pt + hit.vn * bias;
	shadowRay.vn := rc.light.object.pt - hit.pt;
	len := length(shadowRay.vn);
	normalize(shadowRay.vn);

	LdotN := shadowRay.vn +* hit.vn;

	IF LdotN < 0 THEN
		RETURN ZeroVector
	END;
	lightColor := rc.light.object.color;
	obj := rc.objects; exit := FALSE;

	(* Reset hit structure *)
	hit.maxt := INFINITY;
	hit.mint := 0;

	WHILE (obj # NIL) & ~exit DO
		IF ~(obj.bLight) &
			(obj.intersect(obj, shadowRay, hit))
		THEN
			IF obj.iMaterial = GLASS THEN
				(* attenuate light color by glass color *)
				lightColor := lightColor * obj.color;
			ELSE
				isInShadow := TRUE;
			END;
			exit := TRUE
		END;
		obj := obj.next
	END;
	lightColor := lightColor / (len * len);
	IF isInShadow THEN
		RETURN ZeroVector
	ELSE
		RETURN hit.object.color * lightColor * LdotN
	END
END Trace;

PROCEDURE Refine*(rc: RenderContext; fX, fY: REAL; nLevel: LONGINT; CONST cFrmBuf: Vector): Vector;
VAR
	fDelta: REAL;
	ray00, ray10, ray01, ray11: Ray;
	c00, c10, c01, c11, cAvg: Vector;
	fSum: REAL;
	(* [px00, px10, px01, px11] *)
	vDst: Vector;
BEGIN

	fDelta := 1 / Pow2(rc.options.nAALevels - nLevel + 2);

	(* Trace additional 4 rays *)
	ComputeSecondaryRays(rc, fX, fY, fDelta,
	  ray00, ray10, ray01, ray11);

	c00 := rc.funcTrace(rc, ray00, 0);
	c10 := rc.funcTrace(rc, ray10, 0);
	c01 := rc.funcTrace(rc, ray01, 0);
	c11 := rc.funcTrace(rc, ray11, 0);

	clamp(c00);
	clamp(c10);
	clamp(c01);
	clamp(c11);

	(* [px00, px10, px01, px11] *)
	vDst := vector(dist(cFrmBuf, c00), dist(cFrmBuf, c10),
		dist(cFrmBuf, c01), dist(cFrmBuf, c11));

	IF nLevel > 1 THEN

		IF vDst[px00] > rc.options.fAAThreshold THEN
			c00 := Refine(rc, fX - fDelta, fY - fDelta, nLevel - 1, c00);
			vDst[px00] := dist(cFrmBuf, c00)
		END;

		IF vDst[px10] > rc.options.fAAThreshold THEN
			c10 := Refine(rc, fX + fDelta, fY - fDelta, nLevel - 1, c10);
			vDst[px10] := dist(cFrmBuf, c10)
		END;

		IF vDst[px01] > rc.options.fAAThreshold THEN
			c01 := Refine(rc, fX - fDelta, fY + fDelta, nLevel - 1, c01);
			vDst[px01] := dist(cFrmBuf, c01)
		END;

		IF vDst[px11] > rc.options.fAAThreshold THEN
			c11 := Refine(rc, fX + fDelta, fY + fDelta, nLevel - 1, c11);
			vDst[px11] := dist(cFrmBuf, c11)
		END

	END;

	IF (vDst[px00] > rc.options.fAAThreshold) OR (vDst[px10] > rc.options.fAAThreshold) OR
	  (vDst[px01] > rc.options.fAAThreshold) OR (vDst[px11] > rc.options.fAAThreshold)
	THEN

		fSum := vDst[px00] + vDst[px10] + vDst[px01] + vDst[px11];
		vDst := vDst / fSum;

		cAvg := (c00 * vDst[px00] + c10 * vDst[px10] + c01 * vDst[px01] + c11 * vDst[px11] + cFrmBuf) / 2;

		RETURN cAvg

	END;

	RETURN cFrmBuf

END Refine;

PROCEDURE RenderBucket*(rc: RenderContext; VAR b: Bucket);
VAR
	i, j, nPix, w: LONGINT;
	ray: Ray;
	pix: Vector;
	bBucketEdge: BOOLEAN;
	FrmTmp: FrameBuffer;
BEGIN

	(* First pass of rendering *)
	FOR j := b.y0 TO b.y1 DO
		FOR i := b.x0 TO b.x1 DO
			(* Index of pixel in Frame Buffer *)
			nPix := j * rc.options.imageWidth + i;
			(* Compute primary ray *)
			ComputePrimaryRay(rc, i, j, ray);
			(* Trace ray *)
			rc.FrmBuf[nPix] := rc.funcTrace(rc, ray, 0);
			(* Limit values *)
			clamp(rc.FrmBuf[nPix]);
		END
	END;

	(* Antialiasing *)
	w := rc.options.imageWidth;
	b.nSecondaryRays := 0;
	FOR j := b.y0 TO b.y1 DO
		FOR i := b.x0 TO b.x1 DO
			b.FrmLineCur[i] := rc.FrmBuf[j * w + i]
		END;
		FOR i := b.x0 TO b.x1 DO
			(* Index of pixel in Frame Buffer *)
			nPix := j * w + i;
			pix := rc.FrmBuf[nPix];
			(* Pixel is on edge of bucket frame *)
			bBucketEdge := (i = b.x0) OR (j = b.y0) OR (i = b.x1) OR (j = b.y1);
			IF bBucketEdge OR
				(~bBucketEdge &
					((dist(pix, b.FrmLinePrev[i - 1]) > rc.options.fAAThreshold) OR
					(dist(pix, b.FrmLinePrev[i]) > rc.options.fAAThreshold) OR
					(dist(pix, b.FrmLinePrev[i + 1]) > rc.options.fAAThreshold) OR
					(dist(pix, b.FrmLineCur[i - 1]) > rc.options.fAAThreshold) OR
					(dist(pix, b.FrmLineCur[i + 1]) > rc.options.fAAThreshold) OR
					(dist(pix, rc.FrmBuf[(j + 1) * w + (i - 1)]) > rc.options.fAAThreshold) OR
					(dist(pix, rc.FrmBuf[(j + 1) * w + i]) > rc.options.fAAThreshold) OR
					(dist(pix, rc.FrmBuf[(j + 1) * w + (i + 1)]) > rc.options.fAAThreshold)))
			THEN
				INC(b.nSecondaryRays, 4);
				IF rc.options.bShowAAPixels THEN
					rc.FrmBuf[nPix] := vector(0.0, 0.0, 1.0)
				ELSE
					rc.FrmBuf[nPix] := Refine(rc, i + 0.5, j + 0.5,
						rc.options.nAALevels, rc.FrmBuf[nPix])
				END;
			END
		END;
		FrmTmp := b.FrmLinePrev;
		b.FrmLinePrev := b.FrmLineCur;
		b.FrmLineCur := FrmTmp;
	END;
END RenderBucket;

PROCEDURE GammaCorrection*(rc: RenderContext);
VAR
	iPix: LONGINT;
BEGIN
	IF rc.options.gamma # 1 THEN
		FOR iPix := 0 TO LEN(rc.FrmBuf^) - 1 DO
			rc.FrmBuf[iPix][0] := pow(rc.FrmBuf[iPix][0], rc.options.gamma);
			rc.FrmBuf[iPix][1] := pow(rc.FrmBuf[iPix][1], rc.options.gamma);
			rc.FrmBuf[iPix][2] := pow(rc.FrmBuf[iPix][2], rc.options.gamma)
		END
	END
END GammaCorrection;

PROCEDURE CreateObject*(
	rc: RenderContext; pt: Vector; r: REAL; CONST color: Vector;
	iMaterial: INTEGER; bLight: BOOLEAN): Object;
VAR
	object: Object;
BEGIN
	NEW(object, pt, r, color, iMaterial, bLight);
	object.next := rc.objects;
	rc.objects := object;
	RETURN object
END CreateObject;

PROCEDURE CreateCone*(
	rc: RenderContext; pt: Vector; r: REAL; CONST color: Vector;
	iMaterial: INTEGER; h: REAL): Object;
VAR
	object: Cone;
BEGIN
	NEW(object, pt, r, color, iMaterial, FALSE);
	object.next := rc.objects;
	rc.objects := object;
	object.h := h;
	RETURN object
END CreateCone;

PROCEDURE CreateCylinder*(
	rc: RenderContext; pt: Vector; r: REAL; CONST color: Vector;
	iMaterial: INTEGER; zmin, zmax: REAL): Object;
VAR
	object: Cylinder;
BEGIN
	NEW(object, pt, r, color, iMaterial, FALSE);
	object.next := rc.objects;
	rc.objects := object;
	object.zmin := zmin;
	object.zmax := zmax;
	RETURN object
END CreateCylinder;

PROCEDURE CreateDisk*(
	rc: RenderContext; pt: Vector; r: REAL; CONST color: Vector;
	iMaterial: INTEGER; CONST vn: Vector): Object;
VAR
	object: Disk;
BEGIN
	NEW(object, pt, r, color, iMaterial, FALSE);
	object.next := rc.objects;
	rc.objects := object;
	object.vn := vn;
	RETURN object
END CreateDisk;

PROCEDURE pow(x, y: REAL): REAL;
BEGIN
	IF x = 0.0 THEN
		RETURN 0.0
	ELSE
		RETURN Math.exp(y * Math.ln(x))
	END
END pow;

PROCEDURE Pow2(nPow: LONGINT): LONGINT;
VAR
	i, nRes: LONGINT;
BEGIN
	nRes := 1;
	FOR i := 0 TO nPow - 1 DO
		nRes := nRes * 2
	END;
	RETURN nRes
END Pow2;

PROCEDURE Init;
BEGIN
	ZeroVector		:= vector(0, 0, 0);

	XAxisVector		:= vector(1, 0, 0);
	YAxisVector		:= vector(0, 1, 0);
	ZAxisVector		:= vector(0, 0, 1);

	XAxisVectorNeg	:= -XAxisVector;
	YAxisVectorNeg	:= -YAxisVector;
	ZAxisVectorNeg	:= -ZAxisVector;

	Black				:= vector(0, 0, 0);
	Red					:= vector(1, 0, 0);
	Green				:= vector(0, 1, 0);
	Yellow			:= vector(1, 1, 0);
	Blue				:= vector(0, 0, 1);
	Magenta			:= vector(1, 0, 1);
	Cyan				:= vector(0, 1, 1);
	White				:= vector(1, 1, 1);

END Init;

PROCEDURE OutFloat(c: Commands.Context; f: REAL);
VAR
	str: ARRAY 16 OF CHAR;
BEGIN
	Strings.FloatToStr(f, 0, 4, 0, str);
	Strings.Trim(str, 20X);
	c.out.String(str);
END OutFloat;

PROCEDURE OutVector(c: Commands.Context; v: Vector);
VAR
	str1: ARRAY 64 OF CHAR;
	str2: ARRAY 16 OF CHAR;
BEGIN
	COPY("(", str1);
	Strings.FloatToStr(v[0], 0, 4, 0, str2);
	Strings.Trim(str2, 20X);
	Strings.Append(str1, str2);
	Strings.Append(str1, ", ");
	Strings.FloatToStr(v[1], 0, 4, 0, str2);
	Strings.Trim(str2, 20X);
	Strings.Append(str1, str2);
	Strings.Append(str1, ", ");
	Strings.FloatToStr(v[2], 0, 4, 0, str2);
	Strings.Trim(str2, 20X);
	Strings.Append(str1, str2);
	Strings.Append(str1, ", ");
	Strings.FloatToStr(v[3], 0, 4, 0, str2);
	Strings.Trim(str2, 20X);
	Strings.Append(str1, str2);
	Strings.Append(str1, ")");
	c.out.String(str1);
END OutVector;

(*
	Ray vn: (-0.9806, 0.1961, 0.0000, 0.0000)

	First ray pt: (12.0000, 0.0000, 0.0000, 0.0000), hit distance: 10.1980
	Second ray pt: (1.9019, 2.0196, 0.0000, 0.0000), hit distance: 3.0379

	First ray pt: (12.0000, 0.0000, 0.0000, 0.0000), hit distance: 10.1980
	Second ray pt: (1.9019, 2.0196, 0.0000, 0.0000), hit distance: 3.0379
*)
PROCEDURE Test*(c: Commands.Context);
VAR
	object: Object;
	ray: Ray;
	hit: Hit;
	intersect: IntersectFunction;

	PROCEDURE TestProc;
	BEGIN
		ray.pt := vector(12, 0, 0);
		hit.maxt := INFINITY;
		hit.mint := 0;
		IF intersect(object, ray, hit) THEN
			c.out.String("First ray pt: ");
			OutVector(c, ray.pt);
			c.out.String(", hit distance: ");
			OutFloat(c, hit.maxt);
			c.out.Ln;
			ray.pt := ray.pt + (hit.maxt + 0.1) * ray.vn;
			hit.maxt := INFINITY;
			hit.mint := 0;
			IF intersect(object, ray, hit) THEN
				c.out.String("Second ray pt: ");
				OutVector(c, ray.pt);
				c.out.String(", hit distance: ");
				OutFloat(c, hit.maxt);
				c.out.Ln;
			END;
		END;
	END TestProc;

BEGIN

	context := c;

	NEW(object, ZeroVector, 2 * Math.sqrt(2), ZeroVector, 0, FALSE);

	ray.vn := vector(2, 2, 0) - vector(12, 0, 0);
	normalize(ray.vn);

	c.out.Ln;
	c.out.String("Ray vn: ");
	OutVector(c, ray.vn);
	c.out.Ln;
	c.out.Ln;

	intersect := IntersectSphereGeometric;
	TestProc;
	c.out.Ln;

	intersect := IntersectSphereQuadratic;
	TestProc;
	c.out.Ln;

END Test;

BEGIN
	Init
END Lib3D.

Lib3D.Test ~

SystemTools.Free Lib3D ~
