MODULE VolumeMorphology; (** AUTHOR "Patrick Hunziker, Dima Shulga"; PURPOSE "Mathematical Morphology operators in 3¦D"; *)

(** Mathematical Morphology operators, see wikipedia "Mathematical Morphology":
Erosion, Dilation, Opening, Closure. 
Edge. 

They work on either binary or floating point datasets, have concise interfaces and are suited for high performance,
by making use of suitable implementation features of MathArrays etcs.

Applications include edge detection with noise elimination.
*)

(* the 'simple' operator variants operate on voxel in 3*3* domain only.  
the other variants use an arbitrary structuring element. 
operation can be restricted to certain dimensions; the empty set parameter indicates all dimensions. (not yet implemented)
*)

(*! to do: choice of directions not yet imiplemented.*)

IMPORT MatrixBase, WMStack, Commands, MatrixUtilities, Random;

TYPE BinaryVolume*=ARRAY [*,*,*] OF BOOLEAN;
TYPE Volume*=ARRAY [*,*,*] OF MatrixBase.Datatype;

VAR rand: Random.Generator;

(**
Number of nonzero elements in volume
*)	
PROCEDURE NNZ(s: BinaryVolume): LONGINT;
VAR
	k0,k1,k2,n: LONGINT;
BEGIN
	n := 0;
	FOR k0:=0 TO LEN(s,0)-1 DO
		FOR k1:=0 TO LEN(s,1)-1 DO
			FOR k2:=0 TO LEN(s,2)-1 DO
				IF s[k0,k1,k2] = TRUE THEN
					n := n + 1;
				END;	
			END;	
		END;	
	END;
	RETURN n;
END NNZ;

(* replace by generic ALL(x,y,op) as soon as the compiler supports it*)
PROCEDURE All2(CONST x: ARRAY [?] OF MatrixBase.Datatype; y: ARRAY [?] OF BOOLEAN; func: PROCEDURE{DELEGATE}(v: MatrixBase.Datatype; w:BOOLEAN): MatrixBase.Datatype): ARRAY [?] OF MatrixBase.Datatype;
VAR i: LONGINT;
BEGIN
	IF DIM(x) = 1 THEN (* last level of recursion *)
		FOR i := 0 TO LEN(x,0)-1 DO
			RESULT[i] := func(x[i],y[i]);
		END;
	ELSE
		FOR i := 0 TO LEN(x,0)-1 DO
			RESULT[i,?] := All2(x[i,?],y[i,?],func);
		END;
	END;
	RETURN RESULT;
END All2;


PROCEDURE BinarySimpleErosion*(CONST t:BinaryVolume; directions:SET):BinaryVolume;
VAR l0,l1,l2: LONGINT;
BEGIN
	IF (DIM(RESULT)=0) OR (LEN(RESULT,0)=0) THEN NEW(RESULT, LEN(t)) END;
	l0:=LEN(t,0); l1:=LEN(t,1); l2:=LEN(t,2);
	RESULT[1.., ..,..]:= t[1.., ..,..] & t[..l0-2, ..,..]; 
	RESULT[..l0-2, ..,..]:= RESULT[..l0-2, ..,..] & RESULT[1.., ..,..]; 
	RESULT[.., 1.., ..]:= RESULT[.., 1.., ..] & RESULT[.., ..l1-2, ..]; 
	RESULT[.., ..l1-2, ..]:= RESULT[.., ..l1-2, ..] & RESULT[.., 1.., ..]; 
	RESULT[.., .., 1..]:= RESULT[.., .., 1..] & RESULT[.., .., ..l2-2]; 
	RESULT[.., .., ..l2-2]:= RESULT[.., .., ..l2-2] & RESULT[.., .., 1..]; 
	RETURN RESULT
END BinarySimpleErosion;



(**
	Erosion of 3D volume t with structuring element se. 
	Dima Shulga 2015
*)
PROCEDURE BinaryErosion*(CONST t,se:BinaryVolume):BinaryVolume;
VAR 
	e:BinaryVolume;
	k0,k1,k2,m0,m1,m2: LONGINT;
BEGIN
	NEW(e, LEN(t));
	m0 := LEN(se,0) DIV 2;
	m1 := LEN(se,1) DIV 2;
	m2 := LEN(se,2) DIV 2;
	FOR k0 := 0 TO LEN(t,0)-1 DO	
		FOR k1 := 0 TO LEN(t,1)-1 DO	
			FOR k2 := 0 TO LEN(t,2)-1 DO
				IF t[k0,k1,k2] = TRUE THEN
					IF NNZ( t[k0-m0..k0+m0, k1-m1..k1+m1, k2-m2..k2+m2] & se) = NNZ(se) THEN
						e[k0,k1,k2] := TRUE;				
					END;
				END;
			END;
		END;
	END;
	RETURN e;	
END BinaryErosion;


PROCEDURE SimpleErosion*(CONST t:Volume; directions:SET):Volume;
VAR  l0,l1,l2: LONGINT;
BEGIN
	IF (DIM(RESULT)=0) OR (LEN(RESULT,0)=0) THEN NEW(RESULT, LEN(t)) END;
	l0:=LEN(t,0); l1:=LEN(t,1); l2:=LEN(t,2);
	RESULT[1.., ..,..]:= MIN(t[1.., ..,..], t[..l0-2, ..,..]); 
	RESULT[..l0-2, ..,..]:= MIN(RESULT[..l0-2, ..,..], RESULT[1.., ..,..]); 
	RESULT[.., 1.., ..]:= MIN(RESULT[.., 1.., ..], RESULT[.., ..l1-2, ..]); 
	RESULT[.., ..l1-2, ..]:= MIN(RESULT[.., ..l1-2, ..], RESULT[.., 1.., ..]); 
	RESULT[.., .., 1..]:= MIN(RESULT[.., .., 1..], RESULT[.., .., ..l2-2]); 
	RESULT[.., .., ..l2-2]:= MIN(RESULT[.., .., ..l2-2], RESULT[.., .., 1..]); 
	RETURN RESULT
END SimpleErosion;


(**
	Erosion of 3D volume with structuring element
	volume: volume to be processed
	se: structuring element 
*)
PROCEDURE Erosion*(CONST volume,se:Volume):Volume;
VAR 
	e,c:Volume;
	k0,k1,k2,m0,m1,m2: LONGINT;	
BEGIN
		HALT(200); (*! do do: use generic ALL operator. (will be delivered by Alexey for binary procedures)
		use it with 
			PROCEDURE Mask(data: Datatype; selector: BOOLEAN): Datatype;
		Remove dependence from module Spaces.
		Use 
		*)
(*
	NEW(e, LEN(volume));
	NEW(c,LEN(se));
	m0 := LEN(se,0) DIV 2;
	m1 := LEN(se,1) DIV 2;
	m2 := LEN(se,2) DIV 2;
	FOR k0 := m0 TO LEN(volume,0)-1-m0 DO	
		FOR k1 := m1 TO LEN(volume,1)-1-m1 DO	
			FOR k2 := m2 TO LEN(volume,2)-1-m2 DO
				c := volume[k0-m0..k0+m0, k1-m1..k1+m1, k2-m2..k2+m2];											
				c := All2(c,se,MaskCondition); 									
				e[k0,k1,k2] := MIN(c[*]);
			END;
		END;
	END;
	*)
	RETURN e;	
END Erosion;

PROCEDURE BinarySimpleDilation*(CONST t:BinaryVolume; directions:SET):BinaryVolume;
VAR l0,l1,l2: LONGINT;
BEGIN
	IF (DIM(RESULT)=0) OR (LEN(RESULT,0)=0) THEN NEW(RESULT, LEN(t)) END;
	l0:=LEN(t,0); l1:=LEN(t,1); l2:=LEN(t,2);
	RESULT[1.., ..,..]:= t[1.., ..,..] OR t[..l0-2, ..,..]; 
	RESULT[..l0-2, ..,..]:= RESULT[..l0-2, ..,..] OR RESULT[1.., ..,..]; 
	RESULT[.., 1.., ..]:= RESULT[.., 1.., ..] OR RESULT[.., ..l1-2, ..]; 
	RESULT[.., ..l1-2, ..]:= RESULT[.., ..l1-2, ..] OR RESULT[.., 1.., ..]; 
	RESULT[.., .., 1..]:= RESULT[.., .., 1..] OR RESULT[.., .., ..l2-2]; 
	RESULT[.., .., ..l2-2]:= RESULT[.., .., ..l2-2] OR RESULT[.., .., 1..]; 
	RETURN RESULT
END BinarySimpleDilation;

(**
	Dilation of 3D volume t with structuring element se
*)
PROCEDURE BinaryDilation*(CONST t,se:BinaryVolume):BinaryVolume;
VAR 
	d:BinaryVolume;
	k0,k1,k2,m0,m1,m2: LONGINT;
BEGIN
	NEW(d, LEN(t));
	m0 := LEN(se,0) DIV 2;
	m1 := LEN(se,1) DIV 2;
	m2 := LEN(se,2) DIV 2;
	FOR k0 := 0 TO LEN(t,0)-1 DO	
		FOR k1 := 0 TO LEN(t,1)-1 DO	
			FOR k2 := 0 TO LEN(t,2)-1 DO
				IF t[k0,k1,k2] = TRUE THEN
					d[k0-m0..k0+m0, k1-m1..k1+m1, k2-m2..k2+m2] := d[k0-m0..k0+m0, k1-m1..k1+m1, k2-m2..k2+m2] OR se;
				END;
			END;
		END;
	END;
	RETURN d;	
END BinaryDilation;


PROCEDURE SimpleDilation*(CONST t:Volume; directions:SET):Volume;
VAR l0,l1,l2: LONGINT;
BEGIN
	IF (DIM(RESULT)=0) OR (LEN(RESULT,0)=0) THEN NEW(RESULT, LEN(t)) END;
	l0:=LEN(t,0); l1:=LEN(t,1); l2:=LEN(t,2);
	RESULT[1.., ..,..]:= MAX(t[1.., ..,..], t[..l0-2, ..,..]); 
	RESULT[..l0-2, ..,..]:= MAX(RESULT[..l0-2, ..,..], RESULT[1.., ..,..]); 
	RESULT[.., 1.., ..]:= MAX(RESULT[.., 1.., ..], RESULT[.., ..l1-2, ..]); 
	RESULT[.., ..l1-2, ..]:= MAX(RESULT[.., ..l1-2, ..], RESULT[.., 1.., ..]); 
	RESULT[.., .., 1..]:= MAX(RESULT[.., .., 1..], RESULT[.., .., ..l2-2]); 
	RESULT[.., .., ..l2-2]:= MAX(RESULT[.., .., ..l2-2], RESULT[.., .., 1..]); 
	RETURN RESULT
END SimpleDilation;

(**
	Dilation of 3D volume with structuring element
	volume: volume to be processed
	se: structuring element
*)
PROCEDURE Dilation*(CONST volume,se:Volume):Volume;
VAR 
	d,c:Volume;
	k0,k1,k2,m0,m1,m2: LONGINT;	
BEGIN
	HALT(200); (*! do do: use generic ALL operator. Remove dependence from module Spaces*)
	(*
	NEW(d, LEN(volume));
	NEW(c,LEN(volume));
	m0 := LEN(se,0) DIV 2;
	m1 := LEN(se,1) DIV 2;
	m2 := LEN(se,2) DIV 2;
	FOR k0 := m0 TO LEN(volume,0)-1-m0 DO	
		FOR k1 := m1 TO LEN(volume,1)-1-m1 DO	
			FOR k2 := m2 TO LEN(volume,2)-1-m2 DO
				c := volume[k0-m0..k0+m0, k1-m1..k1+m1, k2-m2..k2+m2];
				c := Spaces.ForAll2(c,se,MaskCondition); 									
				d[k0,k1,k2] := MAX(c[*]);
			END;
		END;
	END;
	*)
	RETURN d;	
END Dilation;

PROCEDURE BinarySimpleOpening*(CONST t:BinaryVolume; directions:SET):BinaryVolume;
BEGIN
	RETURN BinarySimpleDilation(BinarySimpleErosion(t,{}),{});
END BinarySimpleOpening;

PROCEDURE BinaryOpening*(CONST t, se: BinaryVolume):BinaryVolume;
BEGIN
	RETURN BinaryDilation(BinaryErosion(t,se),se);
END BinaryOpening;

PROCEDURE SimpleOpening*(CONST t:Volume; directions:SET):Volume;
BEGIN
	RETURN SimpleDilation(SimpleErosion(t,{}),{});
END SimpleOpening;

PROCEDURE BinarySimpleClosure*(CONST t:BinaryVolume; directions:SET):BinaryVolume;
BEGIN
	RETURN BinarySimpleErosion(BinarySimpleDilation(t,{}),{});
END BinarySimpleClosure;

PROCEDURE BinaryClosure*(CONST t, se: BinaryVolume):BinaryVolume;
BEGIN
	RETURN BinaryErosion(BinaryDilation(t,se),se);
END BinaryClosure;

PROCEDURE SimpleClosure*(CONST t:Volume; directions:SET):Volume;
BEGIN
	RETURN SimpleErosion(SimpleDilation(t,{}),{});
END SimpleClosure;
(*
PROCEDURE Closure(t:CONST Volume; CONST structure:Volume):Volume;
BEGIN
END Closure;
*)
PROCEDURE BinaryOuterEdge*(CONST t:BinaryVolume; directions:SET):BinaryVolume;
BEGIN
	RETURN BinarySimpleDilation(t,{}) & ~t;
END BinaryOuterEdge;

PROCEDURE BinaryInnerEdge*(CONST t:BinaryVolume; directions:SET):BinaryVolume;
BEGIN
	RETURN t & ~BinarySimpleErosion(t,{});
END BinaryInnerEdge;

PROCEDURE TestBinary*(context:Commands.Context);
VAR imgB,imgB1,imgB2,imgB3,imgB4,imgB5,imgB6: ARRAY [*,*,*] OF BOOLEAN;
	img,img1,img2,img3,img4,img5,img6: ARRAY [*,*,*] OF MatrixBase.Datatype;
	window: WMStack.Window;
BEGIN
	IF TRUE THEN
		NEW(imgB, 50,50,100); 
		imgB[10,..,..]:=TRUE;
		imgB[20..21,..,..]:=TRUE;
		imgB[30..33,..,..]:=TRUE;
		imgB[..,10,..]:=TRUE;
		imgB[..,20..21,..]:=TRUE;
		imgB[..,30..33,..]:=TRUE;
		imgB[..,..,10]:=TRUE;
		imgB[..,..,20..21]:=TRUE;
		imgB[..,..,30..33]:=TRUE;
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
VAR imgB, imgB1, imgB2, imgB3, imgB4: Volume;
	img, img1, img2, img3, img4, img5, img6: Volume;
	window: WMStack.Window;
BEGIN
	IF TRUE THEN
		NEW(imgB, 50,50,100); 
		imgB[10,..,..]:=rand.Uniform();
		imgB[20..21,..,..]:=rand.Uniform();
		imgB[30..33,..,..]:=rand.Uniform();
		imgB[..,10,..]:=rand.Uniform();
		imgB[..,20..21,..]:=rand.Uniform();
		imgB[..,30..33,..]:=rand.Uniform();
		imgB[..,..,10]:=rand.Uniform();
		imgB[..,..,20..21]:=rand.Uniform();
		imgB[..,..,30..33]:=rand.Uniform();
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
	NEW(rand)
END VolumeMorphology.

VolumeMorphology.Test ~
VolumeMorphology.TestBinary ~

SystemTools.FreeDownTo VolumeMorphology ~
SystemTools.FreeDownTo WMMatrix ~
SystemTools.FreeDownTo WMStack ~