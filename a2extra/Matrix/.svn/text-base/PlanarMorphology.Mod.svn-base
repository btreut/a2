MODULE PlanarMorphology; (** AUTHOR ""; PURPOSE ""; *)
(* Mathematical Morphology operators, see wikipedia "Mathematical Morphology".
They work on either binary or floating point datasets, have elegant interfaces and are suited for high performance,
by making use of suitable implementation features of MathArrays etcs.
*)

(* the 'simple' operator variants operate on pixel in 3*3 domain only.  
the other variants use arbitrary structuring element. 
operation can be restricted to certain dimensions indicated by SET; the empty set indicates all dimensions. (not yet implemented)
*)

IMPORT MatrixBase, Commands, MatrixUtilities, WMMatrix, Random;

TYPE BinaryPlane=ARRAY [*,*] OF BOOLEAN;
TYPE Plane=ARRAY [*,*] OF MatrixBase.Datatype;

VAR rand:Random.Generator;

(**
Number of nonzero elements in volume
*)	
PROCEDURE NNZ(s: BinaryPlane): LONGINT;
VAR
	k0,k1,n: LONGINT;
BEGIN
	n := 0;
	FOR k0:=0 TO LEN(s,0)-1 DO
		FOR k1:=0 TO LEN(s,1)-1 DO
			IF s[k0,k1] = TRUE THEN
				n := n + 1;
			END;	
		END;	
	END;
	RETURN n;
END NNZ;

(** Erosion operators for binary and real data *)

(** Erosion operator.  'simple' indicates handling of 8 nearest neighbours only. *)
PROCEDURE BinarySimpleErosion*(CONST t:BinaryPlane; directions:SET):BinaryPlane;
VAR res:BinaryPlane;
BEGIN
	IF (DIM(res)=0) OR (LEN(res,0)=0) OR (LEN(res,1)=0) THEN NEW(res, LEN(t)) END;
	NEW(res, LEN(t));
	res[1.., ..]:= t[1.., ..] & t[..LEN(t,0)-2, ..]; 
	res[..LEN(res,0)-2, ..]:= res[..LEN(res,0)-2, ..] & res[1.., ..]; 
	res[.., 1..]:= res[.., 1..] & res[.., ..LEN(res,1)-2]; 
	res[.., ..LEN(res,1)-2]:= res[.., ..LEN(res,1)-2] & res[.., 1..]; 
	RETURN res
END BinarySimpleErosion;

(**
	Erosion of 2D array t with structuring element se
*)
PROCEDURE BinaryErosion*(CONST t,se:BinaryPlane):BinaryPlane;
VAR 
	e:BinaryPlane;
	k0,k1,m0,m1: LONGINT;
BEGIN
	NEW(e, LEN(t));
	m0 := LEN(se,0) DIV 2;
	m1 := LEN(se,1) DIV 2;
	FOR k0 := 0 TO LEN(t,0)-1 DO	
		FOR k1 := 0 TO LEN(t,1)-1 DO	
			IF t[k0,k1] = TRUE THEN
				IF NNZ( t[k0-m0..k0+m0, k1-m1..k1+m1] & se) = NNZ(se) THEN
					e[k0,k1] := TRUE;				
				END;
			END;
		END;
	END;
	RETURN e;	
END BinaryErosion;

PROCEDURE SimpleErosion*(CONST t:Plane; directions:SET):Plane;
VAR res:Plane;
BEGIN
	IF (DIM(res)=0) OR (LEN(res,0)=0) OR (LEN(res,1)=0) THEN NEW(res, LEN(t)) END;
	NEW(res, LEN(t));
	res[1.., ..]:= MIN(t[1.., ..], t[..LEN(t,0)-2, ..]); 
	res[..LEN(res,0)-2, ..]:= MIN(res[..LEN(res,0)-2, ..], res[1.., ..]); 
	res[.., 1..]:= MIN(res[.., 1..], res[.., ..LEN(res,1)-2]); 
	res[.., ..LEN(res,1)-2]:= MIN(res[.., ..LEN(res,1)-2], res[.., 1..]); 
	RETURN res
END SimpleErosion;
(*
PROCEDURE Erosion(t:Plane; structure:Plane):Plane;
BEGIN
END Erosion;
*)


PROCEDURE BinarySimpleDilation*(CONST t:BinaryPlane; directions:SET):BinaryPlane;
VAR res:BinaryPlane;
BEGIN
	IF (DIM(res)=0) OR (LEN(res,0)=0) OR (LEN(res,1)=0) THEN NEW(res, LEN(t)) END;
	NEW(res, LEN(t));
	res[1.., ..]:= t[1.., ..] OR t[..LEN(t,0)-2, ..]; 
	res[..LEN(res,0)-2, ..]:= res[..LEN(res,0)-2, ..] OR res[1.., ..]; 
	(*TRACE(LEN(res,0),LEN(res,1));
	TRACE(LEN(res[.., 1..],0),LEN(res[.., 1..],1));
	TRACE(LEN(res[.., ..LEN(res,1)-2],0),LEN(res[.., ..LEN(res,1)-2],1));*)
	res[.., 1..]:= res[.., 1..] OR res[.., ..LEN(res,1)-2]; 
	res[.., ..LEN(res,1)-2]:= res[.., ..LEN(res,1)-2] OR res[.., 1..]; 
	RETURN res
END BinarySimpleDilation;

(**
	Dilation of 2D array t with structuring element se
*)
PROCEDURE BinaryDilation*(CONST t,se:BinaryPlane):BinaryPlane;
VAR 
	d:BinaryPlane;
	k0,k1,m0,m1: LONGINT;
BEGIN
	NEW(d, LEN(t));
	m0 := LEN(se,0) DIV 2;
	m1 := LEN(se,1) DIV 2;
	FOR k0 := 0 TO LEN(t,0)-1 DO	
		FOR k1 := 0 TO LEN(t,1)-1 DO	
			IF t[k0,k1] THEN
				d[k0-m0..k0+m0, k1-m1..k1+m1] := d[k0-m0..k0+m0, k1-m1..k1+m1] OR se;
			END;
		END;
	END;
	RETURN d;	
END BinaryDilation;


PROCEDURE SimpleDilation*(CONST t:Plane; directions:SET):Plane;
VAR res:Plane;
BEGIN
	IF (DIM(res)=0) OR (LEN(res,0)=0) OR (LEN(res,1)=0) THEN NEW(res, LEN(t)) END;
	NEW(res, LEN(t));
	res[1.., ..]:= MAX(t[1.., ..], t[..LEN(t,0)-2, ..]); 
	res[..LEN(res,0)-2, ..]:= MAX(res[..LEN(res,0)-2, ..], res[1.., ..]); 
	res[.., 1..]:= MAX(res[.., 1..], res[.., ..LEN(res,1)-2]); 
	res[.., ..LEN(res,1)-2]:= MAX(res[.., ..LEN(res,1)-2], res[.., 1..]); 
	RETURN res
END SimpleDilation;
(*
PROCEDURE Dilation(t:Plane; structure:Plane):Plane;
BEGIN
END Dilation;
*)
PROCEDURE BinarySimpleOpening*(CONST t:BinaryPlane; directions:SET):BinaryPlane;
BEGIN
	RETURN BinarySimpleDilation(BinarySimpleErosion(t,{}),{});
END BinarySimpleOpening;

PROCEDURE BinaryOpening*(CONST t, se: BinaryPlane):BinaryPlane;
BEGIN
	RETURN BinaryDilation(BinaryErosion(t,se),se);
END BinaryOpening;

PROCEDURE SimpleOpening*(CONST t:Plane; directions:SET):Plane;
BEGIN
	RETURN SimpleDilation(SimpleErosion(t,{}),{});
END SimpleOpening;

(*
PROCEDURE Opening(t:Plane; structure:Plane):Plane;
BEGIN
END Opening;
*)

PROCEDURE BinarySimpleClosure*(CONST t:BinaryPlane; directions:SET):BinaryPlane;
BEGIN
	RETURN BinarySimpleErosion(BinarySimpleDilation(t,{}),{});
END BinarySimpleClosure;

PROCEDURE BinaryClosure*(CONST t, se: BinaryPlane):BinaryPlane;
BEGIN
	RETURN BinaryErosion(BinaryDilation(t,se),se);
END BinaryClosure;

PROCEDURE SimpleClosure*(CONST t:Plane; directions:SET):Plane;
BEGIN
	RETURN SimpleErosion(SimpleDilation(t,{}),{});
END SimpleClosure;

(*
PROCEDURE Closure(t:Plane; structure:Plane):Plane;
BEGIN
END Closure;
*)

PROCEDURE BinaryOuterEdge*(CONST t:BinaryPlane; directions:SET):BinaryPlane;
BEGIN
	RETURN BinarySimpleDilation(t,{}) & ~t;
END BinaryOuterEdge;

PROCEDURE BinaryInnerEdge*(CONST t:BinaryPlane; directions:SET):BinaryPlane;
BEGIN
	RETURN t & ~BinarySimpleErosion(t,{});
END BinaryInnerEdge;


PROCEDURE TestBinary*(context:Commands.Context);
VAR imgB,imgB1,imgB2,imgB3,imgB4,imgB5,imgB6: ARRAY [*,*] OF BOOLEAN;
	img,img1,img2,img3,img4,img5,img6: ARRAY [*,*] OF MatrixBase.Datatype;
	i:LONGINT;
	window: WMMatrix.Window;
BEGIN
	IF TRUE THEN
		NEW(imgB, 100,100); 
		imgB[10,..]:=TRUE;
		imgB[20..21,..]:=TRUE;
		imgB[30..33,..]:=TRUE;
		imgB[..,10]:=TRUE;
		imgB[..,20..21]:=TRUE;
		imgB[..,30..33]:=TRUE;
		NEW(img, LEN(imgB));
		img:=MatrixUtilities.BoolToFloat(imgB);
		NEW(window, img, ""); window.AddWindow;
		
		imgB1:=BinarySimpleErosion(imgB,{});
		NEW(img1, LEN(imgB));
		img1:=MatrixUtilities.BoolToFloat(imgB1);
		NEW(window, img1, "Erosion"); window.AddWindow;
		
		imgB2:=BinarySimpleDilation(imgB,{});
		NEW(img2, LEN(imgB));
		img2:=MatrixUtilities.BoolToFloat(imgB2);
		NEW(window, img2, "Dilation"); window.AddWindow;
		
		imgB3:=BinarySimpleOpening(imgB,{});
		NEW(img3, LEN(imgB));
		img3:=MatrixUtilities.BoolToFloat(imgB3);
		NEW(window, img3, "Opening"); window.AddWindow;
		
		imgB4:=BinarySimpleClosure(imgB,{});
		NEW(img4, LEN(imgB));
		img4:=MatrixUtilities.BoolToFloat(imgB4);
		NEW(window, img4, "Closure"); window.AddWindow;
		
		imgB5:=BinarySimpleDilation(imgB,{}) & ~imgB;
		NEW(img5, LEN(imgB));
		img5:=MatrixUtilities.BoolToFloat(imgB5);
		NEW(window, img5, "OuterEdge"); window.AddWindow;
		
		imgB6:=imgB & ~BinarySimpleErosion(imgB,{}) ;
		NEW(img6, LEN(imgB));
		img6:=MatrixUtilities.BoolToFloat(imgB6);
		NEW(window, img6, "InnerEdge"); window.AddWindow;
	END;
END TestBinary;

PROCEDURE Test*(context:Commands.Context);
VAR imgB,imgB1,imgB2,imgB3,imgB4: Plane;
	img,img1,img2,img3,img4,img5,img6: Plane;
	i:LONGINT;
	window: WMMatrix.Window;
BEGIN
	IF TRUE THEN
		NEW(imgB, 100,100); 
		imgB[10,..]:=rand.Uniform();
		imgB[20..21,..]:=rand.Uniform();
		imgB[30..33,..]:=rand.Uniform();
		imgB[..,10]:=rand.Uniform();
		imgB[..,20..21]:=rand.Uniform();
		imgB[..,30..33]:=rand.Uniform();
		NEW(img, LEN(imgB));
		img:=imgB;
		NEW(window, img, ""); window.AddWindow;
		
		imgB1:=SimpleErosion(imgB,{});
		NEW(img1, LEN(imgB));
		img1:=imgB1;
		NEW(window, img1, "Erosion"); window.AddWindow;
		
		imgB2:=SimpleDilation(imgB,{});
		NEW(img2, LEN(imgB));
		img2:=imgB2;
		NEW(window, img2, "Dilation"); window.AddWindow;
		
		imgB3:=SimpleOpening(imgB,{});
		NEW(img3, LEN(imgB));
		img3:=imgB3;
		NEW(window, img3, "Opening"); window.AddWindow;
		
		imgB4:=SimpleClosure(imgB,{});
		NEW(img4, LEN(imgB));
		img4:=imgB4;
		NEW(window, img4, "Closure"); window.AddWindow;
	END;
END Test;

BEGIN
	NEW(rand);
END PlanarMorphology.

PlanarMorphology.Test~ 
PlanarMorphology.TestBinary~ 
