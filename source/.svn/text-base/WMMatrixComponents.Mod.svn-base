MODULE WMMatrixComponents;(**  AUTHOR "Patrick Hunziker"; PURPOSE "Graph & Grid Rendering of Matrix";  **)

IMPORT
	KernelLog,
	Strings, MatrixModels, XML,
	WMGraphics, WMProperties, WMComponents;

CONST
	(** line styles *)
	line* = 0;
	dot* = 1;

	(** dataorder: organisation/meaning of data in matrix *)
	YYYY* = 0;   (** 1D graphs *)
	XYYY* = 1;   (** first row is X, other rows are Y *)
	XYXY* = 2;   (** XY data pairwise in matrix rows *)
	XYZ* = 3;   (** col=x, row=y, value=z *)

TYPE
	Datatype = REAL;
	Matrix = ARRAY [*,*] OF Datatype;
	Point = ARRAY [*] OF Datatype;
	IntPoint = ARRAY [*] OF LONGINT;

TYPE

	(* Base class of matrix views *)
	MatrixBase = OBJECT(WMComponents.VisualComponent)
	VAR
		hightClue-, depthClue- : WMProperties.BooleanProperty;
		hightClueI, depthClueI : BOOLEAN;

		model : WMProperties.ReferenceProperty;
		modelI : MatrixModels.MatrixModel;

		projection : Matrix;
		widthI, heightI : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			NEW(hightClue, PrototypeHightClue, NIL, NIL); properties.Add(hightClue);
			NEW(depthClue, PrototypeDepthClue, NIL, NIL); properties.Add(depthClue);
			NEW(model, PrototypeModel, NIL, NIL); properties.Add(model);
			projection:= [[0.9, 0.1, 0],[-0.1,0.9,0.1],[0,-0.1,0.9]]; (* default projection *)
		END Init;

		PROCEDURE Initialize;
		BEGIN
			Initialize^;
			RecacheProperties;
		END Initialize;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = bounds) THEN
				widthI := bounds.GetWidth();
				heightI := bounds.GetHeight();
				PropertyChanged^(sender, property);
			ELSIF (property = hightClue) THEN
				hightClueI := hightClue.Get();
				Invalidate;
			ELSIF (property = depthClue) THEN
				depthClueI := depthClue.Get();
				Invalidate;
			ELSIF (property = model) THEN
				CheckModel;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			widthI := bounds.GetWidth();
			heightI := bounds.GetHeight();
			hightClueI := hightClue.Get();
			depthClueI := depthClue.Get();
			CheckModel;
		END RecacheProperties;
		
		PROCEDURE CheckModel;
		VAR newModel : XML.Element;
		BEGIN
			newModel := model.Get();
			IF (newModel # modelI) THEN
				IF (newModel # NIL) & (newModel IS MatrixModels.MatrixModel) THEN
					SetModel(newModel(MatrixModels.MatrixModel));
				ELSE
					SetModel(NIL);
				END;
			END;
		END CheckModel;
		
		PROCEDURE SetModel(model : MatrixModels.MatrixModel);
		BEGIN
			IF (model #  modelI) THEN
				KernelLog.String("MODELSET");
				IF (modelI # NIL) THEN modelI.onChanged.Remove(ModelChanged); END;
				modelI := model;
				IF (modelI # NIL) THEN modelI.onChanged.Add(ModelChanged); END;
				Invalidate;
			END;
		END SetModel;
		
		PROCEDURE ModelChanged(sender, data : ANY);
		BEGIN
			Invalidate;
		END ModelChanged;
		
		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF (modelI # NIL) THEN modelI.onChanged.Remove(ModelChanged); END;
		END Finalize;

	END MatrixBase;

TYPE

	MatrixGrid* = OBJECT(MatrixBase)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrMatrixGrid);
			SetGenerator("WMMatrixComponents.GenMatrixGrid");
		END Init;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			depth, x, y, col : LONGINT;
			x0, y0, z0 : REAL;
			p : Point; p0, p1 : IntPoint;
			scale : REAL; zscale, zrange, minz: REAL;
		BEGIN
			DrawBackground^(canvas);
			IF (modelI = NIL) THEN RETURN; END;
			NEW(p,3); NEW(p0,3);NEW(p1,3);
			x0:=MAX(LEN(modelI.matrix,0),LEN(modelI.matrix,1)) / 2;
			y0:=x0;
			scale:= widthI/MAX(LEN(modelI.matrix,0),LEN(modelI.matrix,1));
			z0:=  (MAX(modelI.matrix)+MIN(modelI.matrix))/2;
			minz:=MIN(modelI.matrix);
			zrange:=MAX(modelI.matrix)-MIN(modelI.matrix);
			zscale:= heightI / zrange;
			FOR y:=0 TO LEN(modelI.matrix,0)-1 DO
				FOR x:=0 TO LEN(modelI.matrix,1)-1 DO
					p:= [0.85*scale*(x-x0), 0.85*scale*(y-y0), 0.85*zscale*(modelI.matrix[y,x]-z0)]; (* to do: used p[2] for color heightI encoding*)
					p1 := ENTIER(projection * p + [scale*x0,scale*y0, zscale*z0]); (*project, scale, convert to pixel coordinate*)
					IF (x#0) THEN
						Clamp(0,widthI-1,p0[0]); Clamp(0,widthI-1,p1[0]); (* strange: points should ~fit into window, but are far off ... Out.Int(p1[2]) *)
						Clamp(0,heightI-1,p0[2]); Clamp(0,heightI-1,p1[2]);
						IF hightClueI THEN col:=ENTIER((modelI.matrix[y,x]-minz)/zrange*255) ELSE col:=255 END;
						IF depthClueI THEN depth:= ENTIER((widthI-p0[1]) * 192 / widthI)  +64 ELSE depth:=255 END;
						canvas.Line(p0[0],p0[2], p1[0], p1[2], (255-col)*256*256 +col*256 +depth, WMGraphics.ModeSrcOverDst);
					END;
					p0:=p1;
				END;
			END;
			FOR x:=0 TO LEN(modelI.matrix,1)-1 DO
				FOR y:=0 TO LEN(modelI.matrix,0)-1 DO
					p:= [0.85*scale*(x-x0), 0.85*scale*(y-y0), 0.85*zscale*(modelI.matrix[y,x]-z0)];
					p1 := ENTIER(projection * p + [scale*x0,scale*y0, zscale*z0] ); (*project, convert to pixel coordinate*) (* to do: color encoding*)
					IF (y#0) THEN
						Clamp(0,widthI-1,p0[0]); Clamp(0,widthI-1,p1[0]);
						Clamp(0,heightI-1,p0[2]); Clamp(0,heightI-1,p1[2]);
						IF hightClueI THEN col:=ENTIER((modelI.matrix[y,x]-minz)/zrange*255) ELSE col:=255 END;
						IF depthClueI THEN depth:= ENTIER((widthI-p0[1]) * 192 / widthI)+64 ELSE depth:=255 END;
						canvas.Line(p0[0],p0[2], p1[0], p1[2], (255-col)*256*256 +col*256 +depth, WMGraphics.ModeSrcOverDst);
					END;
					p0:=p1;
				END;
			END;
		END DrawBackground;

	END MatrixGrid;

TYPE

	Curve= OBJECT
	VAR
		linecol*: LONGINT;
		linestyle*: LONGINT;
		beg*, end*: LONGINT;
		next: Curve;
	END Curve;

	Graph= OBJECT
	VAR
		(*matrix: Matrix;*)
		curves* : Curve;
		X0, Y0, W, H : LONGINT;
		minx, miny, maxx, maxy, scalex, scaley : LONGREAL;
	END Graph;

TYPE

	MatrixGraph* = OBJECT(MatrixBase)
	VAR
		autoscaleX-, autoscaleY- : WMProperties.BooleanProperty;
		autoscaleXI, autoscaleYI : BOOLEAN;

		dataOrder- : WMProperties.Int32Property;
		dataOrderI : LONGINT;

		graph : Graph;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrMatrixGraph);
			SetGenerator("WMMatrixComponents.GenMatrixGraph");
			NEW(autoscaleX, PrototypeAutoscaleX, NIL, NIL); properties.Add(autoscaleX);
			NEW(autoscaleY, PrototypeAutoscaleY, NIL, NIL); properties.Add(autoscaleY);
			NEW(dataOrder, PrototypeDataOrder, NIL, NIL); properties.Add(dataOrder);
			NEW(graph);
			autoscaleXI := TRUE; autoscaleYI := TRUE;
		END Init;

		PROCEDURE ReinitGraph;
		BEGIN
			graph.X0 := widthI DIV 10; graph.W := widthI - 2*graph.X0;
			graph.Y0 := heightI DIV 10; graph.H := heightI - 2*graph.Y0;
		END ReinitGraph;

		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN
			IF (property = bounds) THEN
				PropertyChanged^(sender, property);
				ReinitGraph;
				Invalidate;
			ELSIF (property = autoscaleX) OR (property = autoscaleY) OR (property = dataOrder) THEN
				autoscaleXI := autoscaleX.Get();
				autoscaleYI := autoscaleY.Get();
				dataOrderI := dataOrder.Get();
				Invalidate;
			ELSE
				PropertyChanged^(sender, property);
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			ReinitGraph;
			autoscaleXI := autoscaleY.Get();
			autoscaleYI := autoscaleY.Get();
			dataOrderI := dataOrder.Get();
		END RecacheProperties;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			i,j:LONGINT;
			c: Curve;
		BEGIN
			DrawBackground^(canvas);
			IF (modelI = NIL) THEN RETURN; END;
			CASE dataOrderI OF
				YYYY: (*all rows contain curve Y data*)
					IF autoscaleXI THEN
						graph.minx:=0;
						graph.maxx:=LEN(modelI.matrix,1)-1;
						graph.scalex:= graph.W/(graph.maxx-graph.minx);
					END;
					IF autoscaleYI THEN
						graph.miny:=MIN(modelI.matrix);
						graph.maxy:=MAX(modelI.matrix);
						graph.scaley:=graph.H/(graph.maxy-graph.miny);
					END;
					c:=graph.curves;
					FOR j:=0 TO LEN(modelI.matrix,0)-1 DO
						FOR i:=0 TO LEN(modelI.matrix,1)-2 DO
							canvas.Line(ENTIER((i-graph.minx)*graph.scalex)+graph.X0, heightI - graph.Y0 -ENTIER ((modelI.matrix[j,i]-graph.miny)*graph.scaley),
										ENTIER((i-graph.minx+1)*graph.scalex)+graph.X0, heightI-graph.Y0-ENTIER ((modelI.matrix[j,i+1]-graph.miny)*graph.scaley),
										c.linecol, WMGraphics.ModeSrcOverDst);
						END;
						c:=c.next;
					END;
				| XYXY:
					IF autoscaleXI THEN
						graph.minx:=MIN(modelI.matrix[.. BY 2]);
						graph.maxx:=MAX(modelI.matrix[.. BY 2]);
						graph.scalex:= graph.W/(graph.maxx-graph.minx);
					END;
					IF autoscaleYI THEN
						graph.miny:=MIN(modelI.matrix[1.. BY 2]);
						graph.maxy:=MAX(modelI.matrix[1.. BY 2]);
						graph.scaley:=graph.H/(graph.maxy-graph.miny);
					END;
					c:=graph.curves;
					FOR j:=0 TO LEN(modelI.matrix,0)-1 BY 2 DO
						FOR i:=0 TO LEN(modelI.matrix,1)-2 DO
							canvas.Line(graph.X0+ENTIER ((modelI.matrix[j,i]-graph.minx)*graph.scalex), heightI - graph.Y0 -ENTIER ((modelI.matrix[j+1,i]-graph.miny)*graph.scaley),
										graph.X0+ENTIER ((modelI.matrix[j,i+1]-graph.minx)*graph.scalex), heightI-graph.Y0-ENTIER ((modelI.matrix[j+1,i+1]-graph.miny)*graph.scaley),
										c.linecol, WMGraphics.ModeSrcOverDst);
						END;
						c:=c.next;
					END;
				ELSE HALT(200);
			END;
		END DrawBackground;

	END MatrixGraph;

VAR
	StrMatrixGrid, StrMatrixGraph : Strings.String;

	PrototypeHightClue, PrototypeDepthClue : WMProperties.BooleanProperty;
	PrototypeAutoscaleX, PrototypeAutoscaleY : WMProperties.BooleanProperty;
	PrototypeDataOrder : WMProperties.Int32Property;
	PrototypeModel : WMProperties.ReferenceProperty;

(* cyclic symmetry *)
PROCEDURE Clamp(x0, x1 : LONGINT; VAR x : LONGINT);
BEGIN
	x := (x - x0) MOD (x1 + 1- x0) + x0;
END Clamp;

PROCEDURE GenMatrixGrid*() : XML.Element;
VAR grid : MatrixGrid;
BEGIN
	NEW(grid); RETURN grid;
END GenMatrixGrid;

PROCEDURE GenMatrixGraph*() : XML.Element;
VAR graph : MatrixGraph;
BEGIN
	NEW(graph); RETURN graph;
END GenMatrixGraph;

PROCEDURE InitStrings;
BEGIN
	StrMatrixGrid := Strings.NewString("MatrixGrid");
	StrMatrixGraph := Strings.NewString("MatrixGraph");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	NEW(PrototypeHightClue, NIL, Strings.NewString("HightClue"), Strings.NewString("description"));
	PrototypeHightClue.Set(TRUE);

	NEW(PrototypeDepthClue, NIL, Strings.NewString("DepthClue"), Strings.NewString("description"));
	PrototypeDepthClue.Set(TRUE);

	NEW(PrototypeAutoscaleX, NIL, Strings.NewString("AutoscaleX"), Strings.NewString("Automatically scale X axis?"));
	PrototypeAutoscaleX.Set(TRUE);

	NEW(PrototypeAutoscaleY, NIL, Strings.NewString("AutoscaleY"), Strings.NewString("Automatically scale Y axis?"));
	PrototypeAutoscaleY.Set(TRUE);

	NEW(PrototypeDataOrder, NIL, Strings.NewString("DataOrder"), Strings.NewString("description"));
	PrototypeDataOrder.Set(YYYY);

	NEW(PrototypeModel, NIL, Strings.NewString("Model"), Strings.NewString("Matrix model"));
	PrototypeModel.Set(NIL);
END InitPrototypes;

BEGIN
	InitStrings;
	InitPrototypes;
END WMMatrixComponents.
