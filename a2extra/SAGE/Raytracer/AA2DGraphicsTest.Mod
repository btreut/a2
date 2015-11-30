MODULE AA2DGraphicsTest; (** AUTHOR "SAGE"; PURPOSE "Anti-Aliased 2D Graphics test module"; *)

(** History:

	2009-02-01: First release (SAGE)
	
*)

IMPORT
	AA2DGraphics, WMGraphics, Commands;
	
VAR
	context: Commands.Context;

PROCEDURE Test*(con: Commands.Context);
VAR
	image: WMGraphics.Image;
	aaImage: AA2DGraphics.AA2DImage;
	iObject, iMaterial, iVertex1, iVertex2, iVertex3, iVertex4, nRes: LONGINT;
	
BEGIN

	IF context # NIL THEN RETURN END;
	
  context := con;
  
	image := WMGraphics.LoadImage("mars.png", TRUE);
	NEW(aaImage, image);

	iVertex1 := aaImage.AddVertex(AA2DGraphics.NewVertex(image.width / 5 - 0.5, image.height / 5 - 0.5));
	iVertex2 := aaImage.AddVertex(AA2DGraphics.NewVertex(image.width - 1.5, 1.5));
	iVertex3 := aaImage.AddVertex(AA2DGraphics.NewVertex(1.5, image.height - 1.5));
	iVertex4 := aaImage.AddVertex(AA2DGraphics.NewVertex(image.width - image.width / 5 - 0.5, image.height - image.height / 5 - 0.5));
	iMaterial := aaImage.AddMaterial(AA2DGraphics.NewColor(1.0, 0.0, 1.0, 0.75));
	iObject := aaImage.AddObject();
	aaImage.AddFacet(AA2DGraphics.NewFace(iVertex1, iVertex2, iVertex3), iMaterial, iObject);
	aaImage.AddFacet(AA2DGraphics.NewFace(iVertex3, iVertex2, iVertex4), iMaterial, iObject);
	
	iVertex1 := aaImage.AddVertex(AA2DGraphics.NewVertex(1.5, 1.5));
	iVertex2 := aaImage.AddVertex(AA2DGraphics.NewVertex(image.width - image.width / 5 - 0.5, image.height / 5 - 0.5));
	iVertex3 := aaImage.AddVertex(AA2DGraphics.NewVertex(image.width - 1.5, image.height - 1.5));
	iVertex4 := aaImage.AddVertex(AA2DGraphics.NewVertex(image.width / 5 - 0.5, image.height - image.height / 5 - 0.5));
	iMaterial := aaImage.AddMaterial(AA2DGraphics.NewColor(0.0, 1.0, 0.0, 0.3));
	iObject := aaImage.AddObject();
	aaImage.AddFacet(AA2DGraphics.NewFace(iVertex1, iVertex2, iVertex4), iMaterial, iObject);
	aaImage.AddFacet(AA2DGraphics.NewFace(iVertex4, iVertex2, iVertex3), iMaterial, iObject);
		
	WMGraphics.StoreImage(aaImage.Render(3), "aa.bmp", nRes);
	
	context.out.Ln;
	context.out.String("Done!");
	context.out.Ln;
	
END Test;

BEGIN

	context := NIL;

END AA2DGraphicsTest.Test ~

SystemTools.Free AA2DGraphicsTest AA2DGraphics ~