MODULE srLifeVox;	(* Soren Renner *)

IMPORT Random, Kernel, Math, srE, srBase,
srVoxel2, srM5Space;

CONST
	N = 32;
	M = 32;
	V= 10;
	A = 80;
	B = 20;
	C = 0.03;

VAR
	random:Random.Generator;
	STOP: BOOLEAN;

TYPE SREAL=srBase.SREAL;
TYPE Voxel = srBase.Voxel;

TYPE LifeVox*= OBJECT(Voxel);
VAR
	m : ARRAY M,N OF BOOLEAN;
	n: ARRAY M,N OF INTEGER;
	gen: INTEGER;
	i:LONGINT;

PROCEDURE &init*;
BEGIN
	seed;
	register;
END init;

PROCEDURE seed*;
VAR
	i,j:LONGINT;
BEGIN
	FOR i := 1 TO M - 2 DO
		FOR j := 1 TO N - 2 DO
			IF random.Dice(5) = 0 THEN m[i, j] := TRUE ELSE m[i, j] := FALSE END;
		END
	END;
END seed;

PROCEDURE tick;
VAR
	i, j: LONGINT;
BEGIN
	IF random.Dice(100) = 0 THEN seed END;
	FOR i := 1 TO M - 2 DO
		FOR j := 1 TO N - 2 DO
			n[i,j] := 0;
			IF m[i-1,j-1] THEN INC(n[i,j]) END;
			IF m[i-1,j] THEN INC(n[i,j]) END;
			IF m[i-1,j+1] THEN INC(n[i,j]) END;
			IF m[i,j-1] THEN INC(n[i,j]) END;
			IF m[i,j+1] THEN INC(n[i,j]) END;
			IF m[i+1,j-1] THEN INC(n[i,j]) END;
			IF m[i+1,j] THEN INC(n[i,j]) END;
			IF m[i+1,j+1] THEN INC(n[i,j]) END;
		END
	END;
	FOR i := 1 TO M - 2 DO
		FOR j := 1 TO N - 2 DO
			IF m[i,j] THEN IF (n[i,j]=2) OR (n[i,j]=3) THEN ELSE m[i,j] := FALSE END;
			ELSIF n[i,j]=3 THEN m[i,j] := TRUE END;
		END
	END
END tick;

PROCEDURE Shade (VAR ray: srBase.Ray);
VAR
	x,y: LONGINT;
	lx, ly: SREAL;
	nx, ny, nz: INTEGER;
	dot: SREAL;
	inside: BOOLEAN;
BEGIN
	CASE ray.face OF
		0: inside := TRUE
		|1: nx := -1
		|2: ny := -1
		|3: nz := -1
		|4: nx := 1
		|5: ny := 1
		|6: nz := 1
	ELSE
	END;
	CASE ray.face OF
		1: lx := ray.lxyz.y; ly :=  ray.lxyz.z;
		| 2:  lx := ray.lxyz.x; ly := ray.lxyz.z;
		| 3: lx := ray.lxyz.x; ly := ray.lxyz.y;
		| 4: lx := ray.lxyz.y; ly := ray.lxyz.z;
		| 5: lx := ray.lxyz.x; ly := ray.lxyz.z;
		| 6: lx := ray.lxyz.x; ly := ray.lxyz.y;
	ELSE
	END;
	lx := lx*M; ly := ly*N;
	x :=  ENTIER(lx); y :=  ENTIER(ly);
	IF x > (M-1) THEN x := M-1 END;
	IF y > (N-1) THEN y := N-1 END;
	IF inside THEN dot := 1 ELSE dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z) END;
	IF m[x,y] THEN
		lx :=  (x+1/2)-lx;
		lx := lx*lx;
		ly :=(y+1/2)-ly;
		ly := ly*ly;
	IF (lx+ly)< 0.70 THEN
			CASE ray.face OF
				|1: nx := -1
				|2: ny := -1
				|3: nz := -1
				|4: nx := 1
				|5: ny := 1
				|6: nz := 1
			ELSE
			END;
			CASE ray.face OF
				1: 	 ray.dxyz.x:= -ray.dxyz.x;
				|2:	ray.dxyz.y:= -ray.dxyz.y;
				|3:	ray.dxyz.z:= -ray.dxyz.z;
				|4: 	ray.dxyz.x:= -ray.dxyz.x;
				|5:	ray.dxyz.y:= -ray.dxyz.y;
				|6:	ray.dxyz.z:= -ray.dxyz.z;
			ELSE
			END;
			ray.a := dot*ray.a*(lx+ly)*5;
		(*	ray.changed := TRUE; *)
			ray.g := ray.g + ray.a*dot*(lx+ly)*5;
		ELSE
			ray.r := ray.r + ray.a*dot;
			ray.g := ray.g + ray.a*dot;
			ray.b := ray.b + ray.a*dot;
			ray.a := 0
		END
	ELSE
		ray.r := ray.r + ray.a*dot;
		ray.g := ray.g + ray.a*dot;
		ray.b := ray.b + ray.a*dot;
		ray.a := 0;
	END;
END Shade;
END LifeVox;

TYPE RDVox*= OBJECT(Voxel);
VAR
		m1,m2,n1,n2 : ARRAY M,N OF REAL;
		gen: INTEGER;
		i:LONGINT;
		BLUE, RED: Voxel;
		Cell: srM5Space.cell;

PROCEDURE &init*;
BEGIN
	passable:=FALSE;
END init;

PROCEDURE Shade (VAR ray: srBase.Ray);
VAR
	lx, ly: SREAL;
	color: srBase.COLOR;
	nx, ny, nz: INTEGER;
	dot: SREAL;
	inside: BOOLEAN;
BEGIN
	CASE ray.face OF
		1: lx := ray.lxyz.y; ly :=  ray.lxyz.z;
		| 2:  lx := ray.lxyz.x; ly := ray.lxyz.z;
		| 3: lx := ray.lxyz.x; ly := ray.lxyz.y;
		| 4: lx := ray.lxyz.y; ly := ray.lxyz.z;
		| 5: lx := ray.lxyz.x; ly := ray.lxyz.z;
		| 6: lx := ray.lxyz.x; ly := ray.lxyz.y;
	ELSE
	END;
	CASE ray.face OF
		0: inside := TRUE
		|1: nx := -1
		|2: ny := -1
		|3: nz := -1
		|4: nx := 1
		|5: ny := 1
		|6: nz := 1
	ELSE
	END;
	IF inside THEN dot := 1 ELSE dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z) END;
(*	TuringCoatWnd.shade(lx,ly,color); *)
	ray.r := ray.r + color.red * ray.ra*dot;
	ray.g := ray.g + color.green * ray.ga*dot;
	ray.b := ray.b + color.blue * ray.ba*dot;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;
END Shade;
END RDVox;

TYPE RDMirror*=OBJECT(RDVox);
PROCEDURE Shade (VAR ray: srBase.Ray);
VAR
	i, j: LONGINT;
	lx, ly: SREAL;
	inside: BOOLEAN;
	nx, ny, nz: SREAL;
BEGIN
	CASE ray.face OF
		0: inside := TRUE
		|1: nx := -1
		|2: ny := -1
		|3: nz := -1
		|4: nx := 1
		|5: ny := 1
		|6: nz := 1
	ELSE
	END;
	CASE ray.face OF
		1: lx := ray.lxyz.y; ly :=  ray.lxyz.z;
		| 2:  lx := ray.lxyz.x; ly := ray.lxyz.z;
		| 3: lx := ray.lxyz.x; ly := ray.lxyz.y;
		| 4: lx := ray.lxyz.y; ly := ray.lxyz.z;
		| 5: lx := ray.lxyz.x; ly := ray.lxyz.z;
		| 6: lx := ray.lxyz.x; ly := ray.lxyz.y;
	ELSE
	END;
	i :=  ENTIER(lx*(M-1)) MOD (M-1); j :=  ENTIER(ly*(N-1)) MOD (N-1);
	nx := nx + m1[i,j]/12;
	normalize(nx,ny,nz);
	reflect(ray.dxyz.x,ray.dxyz.y,ray.dxyz.z, nx,ny,nz);
	ray.changed := TRUE;
	ray.a := ray.a - 0.3;
END Shade;

END RDMirror;

TYPE RDVolVox*=OBJECT(Voxel);
VAR
	m1*,m2,n1,n2: ARRAY V,V,V OF REAL;
	gen: INTEGER;
	i:LONGINT;
	tock*: INTEGER;
	BLUE: Voxel;
	RED: Voxel;
	YELLOW: Voxel;
	timer: Kernel.Timer;
	frame: LONGINT;

PROCEDURE &init*(red,blue,yellow: Voxel);
BEGIN
	RED := red;
	BLUE := blue;
	YELLOW:= yellow;
	clear;
	seed;
	register;
	tock := 1;
END init;

PROCEDURE clear*;
VAR
	i,j,k:LONGINT;
BEGIN
	FOR i := 0 TO V - 1 DO
		FOR j := 0 TO V - 1 DO
			FOR k := 0 TO V - 1 DO
				m1[i, j,k] := 0;
				m2[i, j,k] := 0;
				n1[i, j,k] := 0;
				n2[i, j,k] := 0
			END
		END
	END;
	gen := 0;
END clear;

PROCEDURE seed*;
VAR
	i,j,k:LONGINT;
BEGIN
	FOR i := 0 TO V - 1 DO
		FOR j := 0 TO V - 1 DO
			FOR k := 0 TO V - 1 DO
				(* IF random.Dice(4) = 0 THEN m1[i, j,k] := 0.3  END *)
				IF ODD(i+j+k) THEN m1[i, j,k] := 0.3 END;
			END
		END
	END;
END seed;

PROCEDURE bounds (i, j, k: LONGINT; VAR out: BOOLEAN);
BEGIN
	IF (i < 0) OR (i > V-1) OR (j < 0) OR (j > V-1) OR (k < 0) OR (k > V-1) THEN
		out := TRUE
	ELSE
		out := FALSE
	END
END bounds;

PROCEDURE tick;
VAR
		i, j,k: LONGINT;
		A1, B1, C1, D1: REAL;
BEGIN
	INC(frame);
	IF TRUE OR (frame MOD tock = 0) THEN
	FOR i := 1 TO V - 2 DO
		FOR j := 1 TO V - 2 DO
			FOR k := 1 TO V - 2 DO
				n1[i, j,k] := m1[i - 1, j, k] + m1[i + 1, j, k] + m1[i, j - 1, k] + m1[i, j + 1, k]
				 + m1[i,j, k-1] +  m1[i, j, k+1];
			END
		END
	END;
	C1 := C;
	D1 := 1;
	IF D1 < 0 THEN D1 := 0 END;
	A1 := A;
	B1 := B;
	FOR i := 1 TO V - 2 DO
(*		A1 := A + i/10;
		B1 := B; *)
		FOR j := 1 TO V - 2 DO
			B1 := B1 + 0.08;
			FOR k := 1 TO V-1 DO
				(*  HERE ARE THE DIFFERENCE RULES! *)
				m1[i, j, k] := m1[i, j, k] + (n1[i, j, k] /A1 - m2[i, j, k])*D1;
				m2[i, j, k] := m2[i, j, k] +  (m1[i, j, k] /B1 - C1);
				IF m1[i, j, k] < 0 THEN m1[i, j, k] := 0 END;
				IF m2[i, j, k] < 0 THEN m2[i, j, k] := 0 END;
				IF m1[i, j, k] > 1 THEN m1[i, j, k] := 1 END;
				IF m2[i, j, k] > 1 THEN m2[i, j, k] := 1 END;
			END
		END;
	END;
	END;
 END tick;

PROCEDURE probe(x,y,z: SREAL):Voxel;
VAR
	X,Y,Z: SREAL;
	i,j,k: LONGINT;
	color: LONGINT;
BEGIN
	srBase.clamp3(x,y,z);
	X := x*V; Y := y*V; Z := z*V;
	i := ENTIER(X);
	j := ENTIER(Y);
	k := ENTIER(Z);
	color := ENTIER(10*m1[i,j,k]);
	IF color < 3 THEN
		RETURN(NIL)
	ELSE
		RETURN(YELLOW)
	END
END probe;

PROCEDURE Shade (VAR ray: srBase.Ray);
VAR
	oldxyz: srBase.PT;
	drx, dry, drz: SREAL;
	di, dj, dk: INTEGER;
	out: BOOLEAN;
	ijk: srBase.IPT;
	color: LONGINT;
BEGIN
		INC(ray.recursion);
		oldxyz := ray.xyz;
		ray.xyz.x := ray.lxyz.x * V- ray.dxyz.x / 1000000;
		ray.xyz.y := ray.lxyz.y * V- ray.dxyz.y / 1000000;
		ray.xyz.z := ray.lxyz.z * V- ray.dxyz.z / 1000000;
		srE.E(ray.xyz,ijk);
		bounds(ijk.i,ijk.j,ijk.k, out);
		IF ~out THEN
			ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
			ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
			ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
			color := ENTIER(10*m1[ijk.i,ijk.j,ijk.k]);
			CASE color OF
				0: RED.Shade(ray)
				|1: RED.Shade(ray)
				|2: RED.Shade(ray)
				|3: YELLOW.Shade(ray)
				|4: BLUE.Shade(ray)
				|5: YELLOW.Shade(ray)
				|6: BLUE.Shade(ray)
				|7: YELLOW.Shade(ray)
				|8: BLUE.Shade(ray)
				|9: YELLOW.Shade(ray)
			ELSE
				RED.Shade(ray)
			END;
(*			IF m1[ijk.i,ijk.j,ijk.k] > 0.50 THEN BLUE.Shade(ray)
			ELSIF m1[ijk.i,ijk.j,ijk.k] > 0.30 THEN YELLOW.Shade(ray)
			ELSE
				 RED.Shade(ray);
			END; *)
(*			IF m1[ijk.i,ijk.j,ijk.k] > 0.50 THEN
				IF ODD(ijk.i + ijk.j + ijk.k) THEN BLUE.Shade(ray) ELSE YELLOW.Shade(ray) END
			ELSE
				RED.Shade(ray);
			END; *)
		END;
		IF ~ray.changed THEN
			REPEAT
				ray.changed := FALSE;
				IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
				IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
				IF ray.dxyz.z< 0 THEN dk := - 1  ELSE dk := 1 END;
				REPEAT
					IF di > 0 THEN
						drx := ( (ijk.i + 1) - ray.xyz.x) / ray.dxyz.x
					ELSE
						drx :=  (ijk.i -  ray.xyz.x) / ray.dxyz.x
					END;
					IF dj > 0 THEN
						dry := ( (ijk.j + 1) - ray.xyz.y) / ray.dxyz.y
					ELSE
						dry :=  (ijk.j - ray.xyz.y) / ray.dxyz.y
					END;
					IF dk > 0 THEN
						drz := ( (ijk.k + 1) - ray.xyz.z) / ray.dxyz.z
					ELSE
						drz :=  (ijk.k - ray.xyz.z) / ray.dxyz.z
					END;
					IF (drx < dry) THEN
						IF (drx < drz ) THEN
							INC(ijk.i, di);
							IF di > 0 THEN ray.face := 1 ELSE ray.face := 4 END;
							ray.xyz.x := ray.xyz.x + drx * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drx * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drx * ray.dxyz.z
						ELSE
							INC(ijk.k, dk);
							IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
							ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
						END
					ELSIF (dry < drz) THEN
						INC(ijk.j, dj);
						IF dj > 0 THEN ray.face := 2 ELSE ray.face := 5 END;
						ray.xyz.x := ray.xyz.x + dry * ray.dxyz.x; ray.xyz.y := ray.xyz.y + dry * ray.dxyz.y; ray.xyz.z  := ray.xyz.z+ dry * ray.dxyz.z
					ELSE
						INC(ijk.k, dk);
						IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
						ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
					END;
					bounds(ijk.i,ijk.j,ijk.k, out);
					IF ~out THEN
						INC(ray.recursion);
						ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
						ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
						ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
						color := ENTIER(10*m1[ijk.i,ijk.j,ijk.k]);
						CASE color OF
							0: RED.Shade(ray)
							|1: RED.Shade(ray)
							|2: RED.Shade(ray)
							|3: YELLOW.Shade(ray)
							|4: BLUE.Shade(ray)
							|5: YELLOW.Shade(ray)
							|6: BLUE.Shade(ray)
							|7: YELLOW.Shade(ray)
							|8: BLUE.Shade(ray)
							|9: YELLOW.Shade(ray)
						ELSE
						END;
					(*	IF m1[ijk.i,ijk.j,ijk.k] > 0.50 THEN BLUE.Shade(ray)
						ELSIF m1[ijk.i,ijk.j,ijk.k] > 0.30 THEN YELLOW.Shade(ray)
						ELSE
							RED.Shade(ray);
						END; *)
			(*			IF m1[ijk.i,ijk.j,ijk.k] > 0.50 THEN
							IF ODD(ijk.i + ijk.j + ijk.k) THEN BLUE.Shade(ray) ELSE YELLOW.Shade(ray) END
						ELSE
							RED.Shade(ray);
						END; *)
					END;
				UNTIL   (ray.a < 0.1) OR out OR ray.changed;
			UNTIL   (ray.a < 0.1) OR out;
		END;
(*		ray.xyz.x := oldxyz.x + ray.xyz.x/V;
		ray.xyz.y := oldxyz.y + ray.xyz.y/V;
		ray.xyz.z := oldxyz.z + ray.xyz.z/V; *)
		ray.xyz := oldxyz;
		DEC(ray.recursion)
END Shade;

END RDVolVox;

TYPE RDCloud*=OBJECT(RDVolVox);

PROCEDURE tick;
VAR
		i, j,k: LONGINT;
		A1, B1, C1, D1: REAL;
BEGIN
	FOR i := 1 TO V - 2 DO
		FOR j := 1 TO V - 2 DO
			FOR k := 1 TO V - 2 DO
				n1[i, j,k] := m1[i - 1, j, k] + m1[i + 1, j, k] + m1[i, j - 1, k] + m1[i, j + 1, k]
				 + m1[i,j, k-1] +  m1[i, j, k+1];
			END
		END
	END;
	C1 := C;
	D1 := 1;
	IF D1 < 0 THEN D1 := 0 END;
	FOR i := 1 TO V - 2 DO
		A1 := A + i/10;
		B1 := B;
		FOR j := 1 TO V - 2 DO
			B1 := B1 + 0.08;
			FOR k := 1 TO V-1 DO
				(*  HERE ARE THE DIFFERENCE RULES! *)
				m1[i, j, k] := m1[i, j, k] + (n1[i, j, k] /A1 - m2[i, j, k])*D1;
				m2[i, j, k] := m2[i, j, k] +  (m1[i, j, k] /B1 - C1);
				IF m1[i, j, k] < 0 THEN m1[i, j, k] := 0 END;
				IF m2[i, j, k] < 0 THEN m2[i, j, k] := 0 END;
				IF m1[i, j, k] > 1 THEN m1[i, j, k] := 1 END;
				IF m2[i, j, k] > 1 THEN m2[i, j, k] := 1 END;
			END
		END;
	END;
END tick;

END RDCloud;

TYPE LifeBloc*=OBJECT(srVoxel2.Bloc2);
PROCEDURE & init*;
VAR
	l: LifeVox;
BEGIN
	NEW(l);
	blox[0,0,0] := l; blox[0,0,1] := l; blox[0,1,0] := l; blox[0,1,1] := l;
	blox[1,0,0] := l; blox[1,0,1] := l; blox[1,1,0] := l; blox[1,1,1] := l
END init;

END LifeBloc;

TYPE LifeBloc2*=OBJECT(srVoxel2.Bloc2);
PROCEDURE & init*;
VAR
	l: LifeBloc;
BEGIN
	NEW(l);
	blox[0,0,0] := l; blox[0,0,1] := l; blox[0,1,0] := l; blox[0,1,1] := l;
	blox[1,0,0] := l; blox[1,0,1] := l; blox[1,1,0] := l; blox[1,1,1] := l
END init;

END LifeBloc2;

PROCEDURE STOPGO*;
BEGIN
	STOP:= ~STOP;
END STOPGO;

PROCEDURE normalize(VAR x,y,z: SREAL);
VAR d: SREAL;
BEGIN
	d := Math.sqrt(x*x+y*y+z*z);  (* Norma! Liza! Ray! Front and center, oh dark thirty!*)
	x := x/d; y := y/d; z:=z/d;
END normalize;

PROCEDURE reflect(VAR x,y,z: SREAL; nx,ny,nz:SREAL);
VAR
	dot: SREAL;
BEGIN
	dot := x*nx+y*ny+z*nz;
	nx := 2*nx*dot; ny := 2*ny*dot; nz := 2*nz*dot;
	x := x-nx; y := y-ny; z := z-nz;
END reflect;


BEGIN
	NEW(random);
END srLifeVox.

