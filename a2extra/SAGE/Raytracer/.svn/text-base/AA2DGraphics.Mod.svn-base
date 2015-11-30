MODULE AA2DGraphics; (** AUTHOR "SAGE"; PURPOSE "Anti-Aliased 2D Graphics module"; *)

(** History:

	2009-02-01: First release (SAGE)

*)

IMPORT
	WMGraphics, Raster, Math, Kernel;

CONST
	MIN_LEN = 4;
	EPSILON = 1.0E-12;
	DIST = 1 / 255 - EPSILON;

TYPE

	(* R, G, B, A *)
	Color* = ARRAY 4 OF REAL;
	
	Vertex* = ARRAY 2 OF REAL;
	VertexArray = POINTER TO ARRAY OF Vertex;
	
	AABB* = RECORD
		vMin*, vMax*: Vertex;
	END;	

	Material* = RECORD
		color*: Color;
	END;	
	MaterialArray = POINTER TO ARRAY OF Material;
	
	Face* = ARRAY 3 OF LONGINT;
	
	Facet* = RECORD
		face*: Face;
		(* index in MaterialArray *)
		iMaterial-: LONGINT;
		(* index in MaterialArray *)
		iObject-: LONGINT;
		vector0, vector1: Vertex;
		fDot00, fDot01, fDot11, fInvDenom: REAL;
	END;
	FacetArray = POINTER TO ARRAY OF Facet;

	Object* = RECORD
		bAABBSet-: BOOLEAN;
		aabb-: AABB;
	END;
	ObjectArray = POINTER TO ARRAY OF Object;

	AA2DImage* = OBJECT
	VAR
		background: WMGraphics.Image;
		newImage-: WMGraphics.Image;
		
		vertices: VertexArray;
		facets: FacetArray;
		materials: MaterialArray;
		objects: ObjectArray;

		nVertices-: LONGINT;
		nFacets-:  LONGINT;
		nMaterials-:  LONGINT;
		nObjects-:  LONGINT;
		
		frameBuffer: POINTER TO ARRAY OF ARRAY OF Color;
		frameLineCur, frameLinePrev: POINTER TO ARRAY OF Color;
		hitBuffer: POINTER TO ARRAY OF ARRAY OF BOOLEAN;
		
		nAALevels:  LONGINT;
		
		nRenderingTime-: LONGINT;
		
	PROCEDURE &New*(image: WMGraphics.Image);
	BEGIN
		background := image;
		
		NEW(newImage);
		Raster.Create(newImage, background.width, background.height, Raster.BGRA8888);
		
		NEW(frameBuffer, background.width, background.height);
		NEW(hitBuffer, background.width, background.height);
		NEW(frameLineCur, background.width);
		NEW(frameLinePrev, background.width);
		
		ResetObjects;
		NEW(vertices, MIN_LEN);
		NEW(facets, MIN_LEN);
		NEW(materials, MIN_LEN);
		NEW(objects, MIN_LEN);
	END New;
	
	PROCEDURE ResetObjects*;
	BEGIN
		nVertices := 0;
		nFacets := 0;
		nMaterials := 0;
		nObjects := 0
	END ResetObjects;
	
	PROCEDURE AddObject*(): LONGINT;
	VAR
		iObject: LONGINT;
		oldObjects: ObjectArray;
	BEGIN
		INC(nObjects);
		IF nObjects > LEN(objects) THEN
			oldObjects := objects;
			NEW(objects, LEN(objects) * 2);
			FOR iObject := 0 TO LEN(oldObjects) - 1 DO
				objects[iObject] := oldObjects[iObject]
			END
		END;
		iObject := nObjects - 1;
		objects[iObject].bAABBSet := FALSE;
		RETURN iObject
	END AddObject;
	
	PROCEDURE AddMaterial*(color: Color): LONGINT;
	VAR
		iMaterial: LONGINT;
		oldMaterials: MaterialArray;
	BEGIN
		INC(nMaterials);
		IF nMaterials > LEN(materials) THEN
			oldMaterials := materials;
			NEW(materials, LEN(materials) * 2);
			FOR iMaterial := 0 TO LEN(oldMaterials) - 1 DO
				materials[iMaterial] := oldMaterials[iMaterial]
			END
		END;
		iMaterial := nMaterials - 1;
		materials[iMaterial].color := color;
		RETURN iMaterial
	END AddMaterial;
	
	PROCEDURE AddVertex*(vertex: Vertex): LONGINT;
	VAR
		iVertex: LONGINT;
		oldVertices: VertexArray;
	BEGIN
		INC(nVertices);
		IF nVertices > LEN(vertices) THEN
			oldVertices := vertices;
			NEW(vertices, LEN(vertices) * 2);
			FOR iVertex := 0 TO LEN(oldVertices) - 1 DO
				vertices[iVertex] := oldVertices[iVertex]
			END
		END;
		iVertex := nVertices - 1;
		vertices[iVertex] := vertex;
		RETURN iVertex		
	END AddVertex;
	
	PROCEDURE AddFacet*(face: Face; iMaterial, iObject: LONGINT);
	VAR
		iFacet: LONGINT;
		oldFacets: FacetArray;
	BEGIN
		INC(nFacets);
		IF nFacets > LEN(facets) THEN
			oldFacets := facets;
			NEW(facets, LEN(facets) * 2);
			FOR iFacet := 0 TO LEN(oldFacets) - 1 DO
				facets[iFacet] := oldFacets[iFacet]
			END
		END;
		iFacet := nFacets - 1;
		facets[iFacet].face := face;
		
		IF ~objects[iObject].bAABBSet THEN
			objects[iObject].bAABBSet := TRUE;
			objects[iObject].aabb.vMin[0] := MIN(MIN(vertices[face[0]][0], vertices[face[1]][0]), vertices[face[2]][0]);
			objects[iObject].aabb.vMin[1] := MIN(MIN(vertices[face[0]][1], vertices[face[1]][1]), vertices[face[2]][1]);
			objects[iObject].aabb.vMax[0] := MAX(MAX(vertices[face[0]][0], vertices[face[1]][0]), vertices[face[2]][0]);
			objects[iObject].aabb.vMax[1] := MAX(MAX(vertices[face[0]][1], vertices[face[1]][1]), vertices[face[2]][1])
		ELSE
			objects[iObject].aabb.vMin[0] := MIN(objects[iObject].aabb.vMin[0], MIN(MIN(vertices[face[0]][0], vertices[face[1]][0]), vertices[face[2]][0]));
			objects[iObject].aabb.vMin[1] := MIN(objects[iObject].aabb.vMin[1], MIN(MIN(vertices[face[0]][1], vertices[face[1]][1]), vertices[face[2]][1]));
			objects[iObject].aabb.vMax[0] := MAX(objects[iObject].aabb.vMax[0], MAX(MAX(vertices[face[0]][0], vertices[face[1]][0]), vertices[face[2]][0]));
			objects[iObject].aabb.vMax[1] := MAX(objects[iObject].aabb.vMax[1], MAX(MAX(vertices[face[0]][1], vertices[face[1]][1]), vertices[face[2]][1]))
		END;
		
		(* facets[iFacet].vector0 := vertices[face[2]] - vertices[face[0]]; *)
		facets[iFacet].vector0[0] := vertices[face[2]][0] - vertices[face[0]][0];
		facets[iFacet].vector0[1] := vertices[face[2]][1] - vertices[face[0]][1];
		
		(* facets[iFacet].vector1 := vertices[face[1]] - vertices[face[0]]; *)
		facets[iFacet].vector1[0] := vertices[face[1]][0] - vertices[face[0]][0];
		facets[iFacet].vector1[1] := vertices[face[1]][1] - vertices[face[0]][1];
		
		(* facets[iFacet].fDot00 := dot(facets[iFacet].vector0, facets[iFacet].vector0) *)
		facets[iFacet].fDot00 := facets[iFacet].vector0[0] * facets[iFacet].vector0[0] + facets[iFacet].vector0[1] * facets[iFacet].vector0[1];
		
		(* facets[iFacet].fDot01 := dot(vector0, vector1) *)
		facets[iFacet].fDot01 := facets[iFacet].vector0[0] * facets[iFacet].vector1[0] + facets[iFacet].vector0[1] * facets[iFacet].vector1[1];
		
		(* facets[iFacet].fDot11 := dot(vector1, vector1) *)
		facets[iFacet].fDot11 := facets[iFacet].vector1[0] * facets[iFacet].vector1[0] + facets[iFacet].vector1[1] * facets[iFacet].vector1[1];
		
		facets[iFacet].fInvDenom := 1 / (facets[iFacet].fDot00 * facets[iFacet].fDot11 -
			facets[iFacet].fDot01 * facets[iFacet].fDot01);
		
		facets[iFacet].iMaterial := iMaterial;
		facets[iFacet].iObject := iObject;
	END AddFacet;
	
	PROCEDURE PointInAABB(fX, fY: REAL; iObject: LONGINT): BOOLEAN;
	BEGIN
		RETURN (fX >= objects[iObject].aabb.vMin[0]) & (fX <= objects[iObject].aabb.vMax[0]) &
			(fY >= objects[iObject].aabb.vMin[1]) & (fY <= objects[iObject].aabb.vMax[1])
	END PointInAABB;
	
	PROCEDURE PointInTriangle(fX, fY: REAL; iFacet: LONGINT): BOOLEAN;
	VAR
		vector2: Vertex;
		fDot02, fDot12, u, v: REAL;
	BEGIN
		vector2[0] := fX - vertices[facets[iFacet].face[0]][0];
		vector2[1] := fY - vertices[facets[iFacet].face[0]][1];
		fDot02 := facets[iFacet].vector0[0] * vector2[0] + facets[iFacet].vector0[1] * vector2[1];
		fDot12 := facets[iFacet].vector1[0] * vector2[0] + facets[iFacet].vector1[1] * vector2[1];
		u := (facets[iFacet].fDot11 * fDot02 - facets[iFacet].fDot01 * fDot12) * facets[iFacet].fInvDenom;
		(*
		IF u < 0 THEN
			RETURN FALSE
		END;
		v := (facets[iFacet].fDot00 * fDot12 - facets[iFacet].fDot01 * fDot02) * facets[iFacet].fInvDenom;
		RETURN (v > 0) & (u + v < 1)
		*)
		IF u < EPSILON THEN
			RETURN FALSE
		END;
		v := (facets[iFacet].fDot00 * fDot12 - facets[iFacet].fDot01 * fDot02) * facets[iFacet].fInvDenom;
		RETURN (v > -EPSILON) & (u + v < 1 + EPSILON)
	END PointInTriangle;
	
	PROCEDURE Refine(fX, fY: REAL; nLevel: LONGINT; CONST pixelColor, bufferColor: Color): Color;
	VAR
		iObject, iFacet: LONGINT;
		color00, color10, color01, color11, colorAvg, color: Color;
		fDelta, fAlpha, fMAlpha, fDistance00, fDistance10, fDistance01, fDistance11, fDistance: REAL;
	BEGIN

		fDelta := 1 / Pow2(nAALevels - nLevel + 2);

		color00 := pixelColor;
		color10 := pixelColor;
		color01 := pixelColor;
		color11 := pixelColor;

		FOR iObject := 0 TO nObjects - 1 DO
			IF PointInAABB(fX - fDelta, fY - fDelta, iObject) OR PointInAABB(fX + fDelta, fY - fDelta, iObject) OR
				PointInAABB(fX - fDelta, fY + fDelta, iObject) OR PointInAABB(fX + fDelta, fY + fDelta, iObject)
			THEN
				FOR iFacet := 0 TO nFacets - 1 DO
					IF facets[iFacet].iObject = iObject THEN
						fAlpha := materials[facets[iFacet].iMaterial].color[3];
						fMAlpha := 1 - fAlpha;
						color[0] := materials[facets[iFacet].iMaterial].color[0] * fAlpha;
						color[1] := materials[facets[iFacet].iMaterial].color[1] * fAlpha;
						color[2] := materials[facets[iFacet].iMaterial].color[2] * fAlpha;
						color[3] := fAlpha * fAlpha;
						IF PointInTriangle(fX - fDelta, fY - fDelta, iFacet) THEN
							color00[0] := color00[0] * fMAlpha + color[0];
							color00[1] := color00[1] * fMAlpha + color[1];
							color00[2] := color00[2] * fMAlpha + color[2];
							color00[3] := color00[3] * fMAlpha + color[3]
						END;
						IF PointInTriangle(fX + fDelta, fY - fDelta, iFacet) THEN
							color10[0] := color10[0] * fMAlpha + color[0];
							color10[1] := color10[1] * fMAlpha + color[1];
							color10[2] := color10[2] * fMAlpha + color[2];
							color10[3] := color10[3] * fMAlpha + color[3]
						END;
						IF PointInTriangle(fX - fDelta, fY + fDelta, iFacet) THEN
							color01[0] := color01[0] * fMAlpha + color[0];
							color01[1] := color01[1] * fMAlpha + color[1];
							color01[2] := color01[2] * fMAlpha + color[2];
							color01[3] := color01[3] * fMAlpha + color[3]
						END;
						IF PointInTriangle(fX + fDelta, fY + fDelta, iFacet) THEN
							color11[0] := color11[0] * fMAlpha + color[0];
							color11[1] := color11[1] * fMAlpha + color[1];
							color11[2] := color11[2] * fMAlpha + color[2];
							color11[3] := color11[3] * fMAlpha + color[3]
						END
					END
				END
			END
		END;

		IF nLevel > 1 THEN
			IF ColorDistance(bufferColor, color00) >= DIST THEN
				color00 := Refine(fX - fDelta, fY - fDelta, nLevel - 1, pixelColor, color00);
			END;
			
			IF ColorDistance(bufferColor, color10) >= DIST THEN
				color10 := Refine(fX + fDelta, fY - fDelta, nLevel - 1, pixelColor, color10);
			END;
			
			IF ColorDistance(bufferColor, color01) >= DIST THEN
				color01 := Refine(fX - fDelta, fY + fDelta, nLevel - 1, pixelColor, color01);
			END;
			
			IF ColorDistance(bufferColor, color11) >= DIST THEN
				color11 := Refine(fX + fDelta, fY + fDelta, nLevel - 1, pixelColor, color11)
			END
		END;
		
		fDistance00 := ColorDistance(bufferColor, color00);
		fDistance10 := ColorDistance(bufferColor, color10);
		fDistance01 := ColorDistance(bufferColor, color01);
		fDistance11 := ColorDistance(bufferColor, color11);
		
		IF (fDistance00 >= DIST) OR (fDistance10 >= DIST) OR (fDistance01 >= DIST) OR (fDistance11 >= DIST) THEN
			
			fDistance := fDistance00 + fDistance10 + fDistance01 + fDistance11;
			
			fDistance00 := fDistance00 / fDistance;
			fDistance10 := fDistance10 / fDistance;
			fDistance01 := fDistance01 / fDistance;
			fDistance11 := fDistance11 / fDistance;

			colorAvg[0] := (color00[0] * fDistance00 + color10[0] * fDistance10 + color01[0] * fDistance01 + color11[0] * fDistance11 + bufferColor[0]) * 0.5;
			colorAvg[1] := (color00[1] * fDistance00 + color10[1] * fDistance10 + color01[1] * fDistance01 + color11[1] * fDistance11 + bufferColor[1]) * 0.5;
			colorAvg[2] := (color00[2] * fDistance00 + color10[2] * fDistance10 + color01[2] * fDistance01 + color11[2] * fDistance11 + bufferColor[2]) * 0.5;
			colorAvg[3] := (color00[3] * fDistance00 + color10[3] * fDistance10 + color01[3] * fDistance01 + color11[3] * fDistance11 + bufferColor[3]) * 0.5;

			RETURN colorAvg

		END;

		RETURN bufferColor

	END Refine;
	
	PROCEDURE Render*(aaLevels: LONGINT): WMGraphics.Image;
	VAR
		iX, iY, iObject, iFacet: LONGINT;
		pixel: Raster.Pixel;
		mode: Raster.Mode;
		pixelColor: Color;
		fAlpha, fMAlpha: REAL;
		
		timer: Kernel.MilliTimer;

	BEGIN

		Kernel.SetTimer(timer, 0);

		nAALevels := aaLevels;
		
		IF nAALevels > 0 THEN
		
			Raster.InitMode(mode, Raster.srcCopy);
			FOR iY := 0 TO background.height - 1 DO
				FOR iX := 0 TO background.width - 1 DO
					Raster.Get(background, iX, iY, pixel, mode);
					frameBuffer[iX, iY] := PixelToColor(pixel);
					hitBuffer[iX, iY] := FALSE;
					FOR iObject := 0 TO nObjects - 1 DO
						IF PointInAABB(iX + 0.5, iY + 0.5, iObject) THEN
							FOR iFacet := 0 TO nFacets - 1 DO
								IF (facets[iFacet].iObject = iObject) & PointInTriangle(iX + 0.5, iY + 0.5, iFacet) THEN
									hitBuffer[iX, iY] := TRUE;
									fAlpha := materials[facets[iFacet].iMaterial].color[3];
									fMAlpha := 1 - fAlpha;
									frameBuffer[iX, iY][0] := frameBuffer[iX, iY][0] * fMAlpha + materials[facets[iFacet].iMaterial].color[0] * fAlpha;
									frameBuffer[iX, iY][1] := frameBuffer[iX, iY][1] * fMAlpha + materials[facets[iFacet].iMaterial].color[1] * fAlpha;
									frameBuffer[iX, iY][2] := frameBuffer[iX, iY][2] * fMAlpha + materials[facets[iFacet].iMaterial].color[2] * fAlpha;
									frameBuffer[iX, iY][3] := frameBuffer[iX, iY][3] * fMAlpha + fAlpha * fAlpha
								END
							END
						END
					END
				END
			END;
			
			(* Analyze edges *)
			FOR iY := 0 TO background.height - 1 DO
				FOR iX := 0 TO background.width - 1 DO
					frameLineCur[iX] := frameBuffer[iX, iY]
				END;
				FOR iX := 1 TO background.width - 2 DO
					IF (iY # 0) & (iY # background.height - 1) &
						(hitBuffer[iX - 1, iY - 1] OR hitBuffer[iX, iY - 1] OR hitBuffer[iX + 1, iY - 1] OR
						hitBuffer[iX - 1, iY] OR hitBuffer[iX, iY] OR hitBuffer[iX + 1, iY] OR
						hitBuffer[iX - 1, iY + 1] OR hitBuffer[iX, iY + 1] OR hitBuffer[iX + 1, iY + 1]) &
						((ColorDistance(frameLineCur[iX], frameLinePrev[iX - 1]) >= DIST) OR
						(ColorDistance(frameLineCur[iX], frameLinePrev[iX]) >= DIST) OR
						(ColorDistance(frameLineCur[iX], frameLinePrev[iX + 1]) >= DIST) OR
						(ColorDistance(frameLineCur[iX], frameLineCur[iX - 1]) >= DIST) OR
						(ColorDistance(frameLineCur[iX], frameLineCur[iX + 1]) >= DIST) OR
						(ColorDistance(frameLineCur[iX], frameBuffer[iX - 1, iY + 1]) >= DIST) OR
						(ColorDistance(frameLineCur[iX], frameBuffer[iX, iY + 1]) >= DIST) OR
						(ColorDistance(frameLineCur[iX], frameBuffer[iX + 1, iY + 1]) >= DIST))
					THEN
					
						(* frameBuffer[iX, iY] := NewColor(1.0, 0.0, 0.0, 1.0); *)
						
						Raster.Get(background, iX, iY, pixel, mode);
						pixelColor := PixelToColor(pixel);
						frameBuffer[iX, iY] := Refine(iX + 0.5, iY + 0.5, nAALevels, pixelColor, frameBuffer[iX, iY])
						
					END
				END;
				FOR iX := 0 TO background.width - 1 DO
					frameLinePrev[iX] := frameLineCur[iX]
				END
			END;
			
			Raster.InitMode(mode, Raster.srcCopy);
			FOR iY := 0 TO background.height - 1 DO
				FOR iX := 0 TO background.width - 1 DO
					pixel := ColorToPixel(frameBuffer[iX, iY]);
					Raster.Put(newImage, iX, iY, pixel, mode)
				END
			END
		END;
		
		nRenderingTime := Kernel.Elapsed(timer);

		RETURN newImage

	END Render;

	END AA2DImage;
	
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

PROCEDURE ColorDistance(CONST c1, c2: Color): REAL;
VAR
	c: Color;
BEGIN
	c[0] := c1[0] - c2[0];
	c[1] := c1[1] - c2[1];
	c[2] := c1[2] - c2[2];
	c[3] := c1[3] - c2[3];
	RETURN Math.sqrt(c[0] * c[0] + c[1] * c[1] + c[2] * c[2] + c[3] * c[3])
END ColorDistance;
	
PROCEDURE NewColor*(r, g, b, a: REAL): Color;
VAR
	c: Color;
BEGIN
	c[0] := r;
	c[1] := g;
	c[2] := b;
	c[3] := a;
	RETURN c
END NewColor;

PROCEDURE RGBAToColor*(rgba: LONGINT): Color;
VAR
	c: Color;
	r, g, b, a: LONGINT;
BEGIN
	WMGraphics.ColorToRGBA(rgba, r, g, b, a);
	c[0] := r / 255;
	c[1] := g / 255;
	c[2] := b / 255;
	c[3] := a / 255;
	RETURN c
END RGBAToColor;

PROCEDURE PixelToColor*(CONST pixel: Raster.Pixel): Color;
VAR
	c: Color;
BEGIN
	c[0] := ORD(pixel[2]) / 255;
	c[1] := ORD(pixel[1]) / 255;
	c[2] := ORD(pixel[0]) / 255;
	c[3] := ORD(pixel[3]) / 255;
	RETURN c
END PixelToColor;

PROCEDURE ColorToPixel*(CONST color: Color): Raster.Pixel;
VAR
	pixel: Raster.Pixel;
BEGIN
	pixel[2] := CHR(ENTIER(color[0] * 255));
	pixel[1] := CHR(ENTIER(color[1] * 255));
	pixel[0] := CHR(ENTIER(color[2] * 255));
	pixel[3] := CHR(ENTIER(color[3] * 255));
	RETURN pixel
END ColorToPixel;

PROCEDURE NewVertex*(x, y: REAL): Vertex;
VAR
	v: Vertex;
BEGIN
	v[0] := x;
	v[1] := y;
	RETURN v
END NewVertex;

PROCEDURE NewFace*(iVertex1, iVertex2, iVertex3: LONGINT): Face;
VAR
	face: Face;
BEGIN
	face[0] := iVertex1;
	face[1] := iVertex2;
	face[2] := iVertex3;
	RETURN face
END NewFace;

END AA2DGraphics.

SystemTools.Free AA2DGraphics ~