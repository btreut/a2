MODULE PlanarEdgeDetectors; (** AUTHOR "Patrick Hunziker"; PURPOSE " various edge detectors"; **)

(* see also http://en.wikipedia.org/wiki/Scale_space and http://en.wikipedia.org/wiki/Edge_detection*)

(*
Usually, Smoothing and derivative operators are combined.
Due to the commutative property between the derivative operator and the Gaussian smoothing operator, 
such scale-space derivatives can equivalently be computed by convolving the original image with Gaussian derivative operators. 
For this reason they are often also referred to as Gaussian derivatives.
*)


IMPORT PlanarBase, PlanarNabla, PlanarMath, Mathe:=MathL, WMMatrix, Commands;

TYPE 
	Datatype=PlanarBase.Datatype;
	Line=PlanarBase.OneD;
	ScalarField*=PlanarNabla.ScalarField;
	VectorField*=PlanarNabla.VectorField;

(* nabla-based edge detector. For choice of 'sampling' parameters, see PlanarNabla.Mod *)
PROCEDURE DifferentialEdgeMagnitude*(CONST p:ScalarField; sampling: LONGINT):ScalarField;
BEGIN
	RETURN PlanarMath.Sqrt(PlanarMath.Sqr(PlanarNabla.dx(p,sampling)) + PlanarMath.Sqr(PlanarNabla.dy(p,sampling)));
END DifferentialEdgeMagnitude;

PROCEDURE DifferentialEdgeDirection*(CONST p:ScalarField; sampling:LONGINT):VectorField;
BEGIN
	RETURN PlanarNabla.Grad(p, sampling);
END DifferentialEdgeDirection;

PROCEDURE arctan2(x,y:LONGREAL):LONGREAL; (*arctan in range 0..2pi*)
BEGIN
	IF (x>0) & (y>=0) THEN RETURN Mathe.arctan(y/x)
	ELSIF (x>0) & (y<0) THEN RETURN Mathe.arctan(y/x)+2*Mathe.pi
	ELSIF x<0 THEN RETURN Mathe.arctan(y/x)+Mathe.pi	ELSIF (x=0) & (y>0) THEN RETURN Mathe.pi/2
	ELSIF (x=0) & (y<0) THEN RETURN 3*Mathe.pi/2
	ELSE (*( x=0) & (y=0) *) RETURN 0 (*or RETURN NaN ?*) 
	END
END arctan2;

PROCEDURE DifferentialEdgeAngle*(CONST p:ScalarField; sampling:LONGINT):ScalarField; (*! needs speedup - parallelize how ?*)
VAR vec:VectorField; x,y:LONGINT;
BEGIN
	vec:=DifferentialEdgeDirection(p, sampling);
	IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(p,0), LEN(p,1)) END;
	FOR y:=0 TO LEN(p,0)-1 DO
		FOR x:=0 TO LEN(p,1)-1 DO
			RESULT[y,x]:=arctan2(vec.x[y,x], vec.y[y,x]);
		END;
	END;
	RETURN RESULT
END DifferentialEdgeAngle;

(*Canny Edge Detector, with or without non-maximum suppression. Based on Code from TrueColorSnakes. In noisy data, needs pre-smoothing for best result *)
PROCEDURE Canny* (CONST in: ScalarField; NonMaxSuppression:BOOLEAN): ScalarField;
VAR line: Line;
	lines:ARRAY [*] OF Line;
	i,j,j2,i1,i2,iM1,iM2,h,hM2,hM1,h1,h2,dir, width, height: LONGINT;
	d1,deriv, pix, InvSqrt2: Datatype;
	nil: ScalarField;
BEGIN
	InvSqrt2:=1/Mathe.sqrt(2);
	width:=LEN(in,1); height:=LEN(in,0);
	IF height=0  THEN RETURN nil END;
	IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(in,0), LEN(in,1)); END;
	NEW(line, LEN(in,1)); 
	NEW(lines, 5, LEN(in,1));
	lines[0..2]:=in[0..2];
	lines[3]:= in[0];
	lines[4]:=in[0];
	h:=0;
	FOR j:=0 TO LEN(RESULT,0)-1 DO
		hM2:=(h-2) MOD 5; 
		hM1:=(h-1) MOD 5;
		h1:=(h+1) MOD 5; 
		h2:=(h+2) MOD 5;
		FOR i:=0 TO LEN(in,1)-1 DO
			iM1:=(i-1) MOD width; 
			i1:=(i+1) MOD width;
			iM2:=(i-2) MOD width; 
			i2:=(i+2) MOD width;
			
			deriv:=ABS(lines[h,i1]-lines[h,iM1]); dir:=0;
			d1:=ABS(lines[h1,i1]-lines[hM1,iM1]); 
			IF InvSqrt2*d1>deriv THEN deriv:=SHORT(ENTIER(InvSqrt2*d1)); dir:=1 END;
			d1:=ABS(lines[h1,i]-lines[hM1,i]); 
			IF d1>deriv THEN deriv:=d1; dir:=2 END;
			d1:=ABS(lines[h1,iM1]-lines[hM1,i1]); 
			IF InvSqrt2*d1>deriv THEN deriv:=SHORT(ENTIER(InvSqrt2*d1)); dir:=3 END;
			line[i]:=deriv;
			(*
			IF deriv>255 THEN line[i]:=255 (* 8 bit case *)
			ELSIF deriv<0 THEN line[i]:=0
			ELSE line[i]:=deriv
			END;
			*)
			IF NonMaxSuppression THEN 
				pix:=lines[h,i];
				CASE dir OF
					0: IF (ABS(lines[h,i2]-pix)>deriv) OR (ABS(lines[h,iM2]-pix)>deriv) THEN line[i]:=0 END;
					|1:IF (ABS(lines[h2,i2]-pix)>deriv) OR (ABS(lines[hM2,iM2]-pix)>deriv) THEN line[i]:=0 END;	
					|2:IF (ABS(lines[h2,i]-pix)>deriv) OR (ABS(lines[hM2,i]-pix)>deriv) THEN line[i]:=0 END;
					|3:IF (ABS(lines[h2,iM2]-pix)>deriv) OR (ABS(lines[hM2,i2]-pix)>deriv) THEN line[i]:=0 END;	
				END;
			END;
		END;
		RESULT[j]:=line;
		h:=(h+1) MOD 5;
		j2:=j+2;
		IF j2>=height THEN j2:=height-1 END;
		lines[(h+2) MOD 5]:= in[j2];
	END;
	RETURN RESULT
END Canny;

PROCEDURE NonMaximaSuppression*(CONST in:ScalarField):ScalarField; (* only partly working at the moment*)
VAR l, l0,l1,l2,l00: Line; out:ScalarField; i,j,len:LONGINT;
BEGIN
	NEW(out,LEN(in,0),LEN(in,1));
	len:=LEN(in,0);
	l00:=in[(i-1) MOD len]; 
	i:=1;
	WHILE i<LEN(in,0)-1 DO
		l0:=in[(i-1) MOD len]; l1:=in[i]; l2:=in[(i+1)MOD len]; 
		l:=in[i]; 
		FOR j:=1 TO LEN(in,1)-2 DO
			IF (l[j]<l00[j]) OR (l[j]<l2[j]) OR (l[j]<l1[j-1]) OR (l[j]<l1[j+1]) THEN l[j]:=0 END;
		END;
		out[i]:=l;
		l00:=l;
		INC(i);
	END;
	RETURN out
END NonMaximaSuppression;

PROCEDURE Test*;
VAR rect: ScalarField; vec: VectorField; window: WMMatrix.Window;
BEGIN
	NEW(rect, 100, 100); 
	rect[45..55,..]:=1; 
	rect[..,45..56]:=1; 
	rect[..50, 41..59]:=0.2;
	rect[..50, 42..58]:=0.5;
	rect[..50, 43..57]:=0.9;
	rect[..50, 44..56]:=1.4;
	rect[..50, 45..55]:=2;
	rect[..50, 46..54]:=3.1;
	rect[..50, 47..53]:=4;
	rect[..50, 48..52]:=4.5;
	rect[..50, 49..51]:=5;
	rect[..50, 50]:=5.4;
	
	NEW(window, rect, "original"); window.AddWindow;
	
	NEW(window, Canny(rect, FALSE), "Canny, plain"); window.AddWindow;
	NEW(window, Canny(rect, TRUE), "Canny suppressing non-maxima"); window.AddWindow;
	
	NEW(window, DifferentialEdgeMagnitude(rect, PlanarNabla.centered), "differential edge magnitude"); window.AddWindow;
	NEW(window, DifferentialEdgeAngle(rect, PlanarNabla.centered), "differential edge angle"); window.AddWindow;
	vec:= DifferentialEdgeDirection(rect, PlanarNabla.centered);
	NEW(window, vec.x, "edge direction x"); window.AddWindow;
	NEW(window, vec.y, "edge direction y"); window.AddWindow;
	
	NEW(window, PlanarNabla.Laplacian(rect, PlanarNabla.centered), "Laplacian"); window.AddWindow;

END Test;

(*
PROCEDURE TestFile*(context:Commands.Context);
VAR img: MatrixTIFFCodec.Image; filename: ARRAY 1024 OF CHAR;
	window: WMMatrix.Window;
BEGIN
	IF context.arg.GetString(filename) THEN
		img:=MatrixTIFFCodex(filename);
		IF img#NIL THEN img.ShowFrame(0); END;
	END;
END TestFile;
*)

END PlanarEdgeDetectors.


PlanarEdgeDetectors.Test

"C:/C/Documents and Settings/Pat/My Documents/Malaria/Discognosis FP7/Size Standards QLC/PS Beads/B_237_AA_1_Time 4.tif"
PlanarEdgeDetectors.Test
"C:/C/Documents and Settings/Pat/My Documents/Malaria/Discognosis FP7/Size Standards QLC/PS Beads/image_140703_002.tif"

