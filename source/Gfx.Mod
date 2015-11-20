(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Gfx; (** portable *)	(* eos  *)
(** AUTHOR "eos"; PURPOSE "High-level, device independent 2D-graphics"; *)

	(*
		11.2.98 - changed behaviour of GetOutline if current line width is zero: calculates dashed path instead of outline (eos)
		11.2.98 - eliminated offset parameter from subpath begin since it can be simulated by modifying the dash phase
		16.2.98 - DrawPath now accepts current path
		17.2.98 - ...but only if Record is not included in mode
		17.2.98 - added RenderPath
		19.2.98 - simplified cap and join styles to procedures
		19.2.98 - eliminated clip path (was not correct, anyway), introduced GetClipRect instead
		6.3.98 - fixed bug in GetDashOutline (started last dash twice even if fully drawn)
		18.9.98 - several changes: renaming, added stroke pattern and rect/ellipse methods, text is now part of path model,
			standard colors
		9.12.98 - adaptation to new GfxMaps
		10.3.99 - separate dash pattern into on/off arrays
		13.5.99 - remodeled cap and join styles
		13.5.99 - eliminated 'erase'
		2.6.99 - bugfix in GetStrokeOutline and GetDashOutline (forgot to consume GfxPaths.Exit after subpath)
		8.6.99 - made GetPolyOutline automatically close open subpaths
		25.8.99 - use GfxImages instead of GfxMaps
		6.10.99 - save and restore graphics state, MoveTo and Close
		13.02.2000 - added ClipArea, replaced SaveClip/RestoreClip by GetClip/SetClip, fine-grained SaveState semantics
		26.02.2000 - allow font change within path
		27.02.2000 - added DrawArc
		29.03.2000 - made default flatness 1/2
		25.05.2000 - no longer imports Texts and Oberon
		12.06.2001 - made tmpPath and dashPath ctxt fields to allow concurrency
	*)

	IMPORT
		Math, GfxMatrix, GfxImages, GfxPaths, GfxFonts;


	CONST
		Version* = "Gfx 2.0/eos 25.05.2000";

		Record* = 0; Fill* = 1; Clip* = 2; Stroke* = 3; EvenOdd* = 4;	(** drawing mode elements **)
		InPath* = 5; InSubpath* = 6;	(** context state **)
		MaxDashPatSize* = 8;	(** maximal number of dash entries **)
		NoJoin* = 0; MiterJoin* = 1; BevelJoin* = 2; RoundJoin* = 3;	(** join styles **)
		NoCap* = 0; ButtCap* = 1; SquareCap* = 2; RoundCap* = 3;	(** cap styles **)

		(** state elements **)
		fillColPat* = 0; strokeColPat* = 1; lineWidth* = 2; dashPat* = 3; capStyle* = 4; joinStyle* = 5; styleLimit* = 6;
		flatness* = 7; font* = 8; ctm* = 9; clip* = 10;
		strokeAttr* = {strokeColPat..styleLimit};
		attr* = {fillColPat..font}; all* = attr + {ctm, clip};


	TYPE
		(** graphics context **)
		Context* = POINTER TO ContextDesc;

		(** color type **)
		Color* = RECORD
			r*, g*, b*, a*: INTEGER;
		END;

		(** fill patterns **)
		Pattern* = POINTER TO PatternDesc;
		PatternDesc* = RECORD
			img*: GfxImages.Image;	(** replicated image map **)
			px*, py*: REAL;	(** pinpoint coordinates **)
		END;

		(** line join and cap styles **)
		JoinStyle* = SHORTINT;
		CapStyle* = SHORTINT;

		(** abstract clip areas **)
		ClipArea* = POINTER TO ClipAreaDesc;
		ClipAreaDesc* = RECORD END;

		(** context methods **)
		Methods* = POINTER TO MethodBlock;
		MethodBlock* = RECORD
			(** initialization **)
			reset*: PROCEDURE (ctxt: Context);

			(** current transformation matrix **)
			resetCTM*: PROCEDURE (ctxt: Context);
			setCTM*: PROCEDURE (ctxt: Context; VAR mat: GfxMatrix.Matrix);
			translate*: PROCEDURE (ctxt: Context; dx, dy: REAL);
			scale*: PROCEDURE (ctxt: Context; sx, sy: REAL);
			rotate*: PROCEDURE (ctxt: Context; sin, cos: REAL);
			concat*: PROCEDURE (ctxt: Context; VAR mat: GfxMatrix.Matrix);

			(** clipping **)
			resetClip*: PROCEDURE (ctxt: Context);
			getClipRect*: PROCEDURE (ctxt: Context; VAR llx, lly, urx, ury: REAL);
			getClip*: PROCEDURE (ctxt: Context): ClipArea;
			setClip*: PROCEDURE (ctxt: Context; clip: ClipArea);

			(** graphics state **)
			setStrokeColor*: PROCEDURE (ctxt: Context; color: Color);
			setStrokePattern*: PROCEDURE (ctxt: Context; pat: Pattern);
			setFillColor*: PROCEDURE (ctxt: Context; color: Color);
			setFillPattern*: PROCEDURE (ctxt: Context; pat: Pattern);
			setLineWidth*: PROCEDURE (ctxt: Context; width: REAL);
			setDashPattern*: PROCEDURE (ctxt: Context; VAR on, off: ARRAY OF REAL; len: LONGINT; phase: REAL);
			setCapStyle*: PROCEDURE (ctxt: Context; style: CapStyle);
			setJoinStyle*: PROCEDURE (ctxt: Context; style: JoinStyle);
			setStyleLimit*: PROCEDURE (ctxt: Context; limit: REAL);
			setFlatness*: PROCEDURE (ctxt: Context; flatness: REAL);
			setFont*: PROCEDURE (ctxt: Context; font: GfxFonts.Font);
			getWidth*: PROCEDURE (ctxt: Context; VAR str: ARRAY OF CHAR; VAR dx, dy: REAL);

			(** current path **)
			begin*: PROCEDURE (ctxt: Context; mode: SET);
			end*: PROCEDURE (ctxt: Context);
			enter*: PROCEDURE (ctxt: Context; x, y, dx, dy: REAL);
			exit*: PROCEDURE (ctxt: Context; dx, dy: REAL);
			close*: PROCEDURE (ctxt: Context);
			line*: PROCEDURE (ctxt: Context; x, y: REAL);
			arc*: PROCEDURE (ctxt: Context; x, y, x0, y0, x1, y1, x2, y2: REAL);
			bezier*: PROCEDURE (ctxt: Context; x, y, x1, y1, x2, y2: REAL);
			show*: PROCEDURE (ctxt: Context; x, y: REAL; VAR str: ARRAY OF CHAR);
			flatten*: PROCEDURE (ctxt: Context);
			outline*: PROCEDURE (ctxt: Context);
			render*: PROCEDURE (ctxt: Context; mode: SET);

			(** painting operators (potential for optimization) **)
			rect*: PROCEDURE (ctxt: Context; x0, y0, x1, y1: REAL);
			ellipse*: PROCEDURE (ctxt: Context; x, y, rx, ry: REAL);

			(** images and patterns **)
			image*: PROCEDURE (ctxt: Context; x, y: REAL; img: GfxImages.Image; VAR filter: GfxImages.Filter);
			newPattern*: PROCEDURE (ctxt: Context; img: GfxImages.Image; px, py: REAL): Pattern;
		END;

		(** graphics context (continued) **)
		ContextDesc* = RECORD
			do*: Methods;	(** methods associated with context **)
			mode*: SET;	(** current drawing mode **)
			path*: GfxPaths.Path;	(** current path in device coordinates (updated only if mode contains the 'Record' flag) **)
			cpx*, cpy*: REAL;	(** current point in user coordinates **)
			ctm*: GfxMatrix.Matrix;	(** current transformation matrix **)
			cam*: GfxMatrix.Matrix;	(** current attribute matrix (frozen ctm while inside path) **)
			strokeCol*, fillCol*: Color;	(** current stroke and fill color **)
			strokePat*, fillPat*: Pattern;	(** current stroke and fill pattern **)
			lineWidth*: REAL;	(** current line width **)
			dashPatOn*, dashPatOff*: ARRAY MaxDashPatSize OF REAL;	(** line dash array **)
			dashPatLen*: LONGINT;	(** number of valid elements in dash arrays **)
			dashPhase*: REAL;	(** offset for first dash **)
			dashPeriod*: REAL;	(** sum of dash element lengths **)
			capStyle*: CapStyle;	(** line cap style **)
			joinStyle*: JoinStyle;	(** line join style **)
			styleLimit*: REAL;	(** determines area that may be rendered to by styles **)
			flatness*: REAL;	(** current flatness tolerance (in device coordinates) **)
			font*: GfxFonts.Font;	(** current font **)
			dashPath: GfxPaths.Path;	(* path for temporarily storing dashes *)
			tmpPath: GfxPaths.Path;
		END;

		(** graphics state **)
		State* = RECORD
			saved: SET;
			strokeCol, fillCol: Color; strokePat, fillPat: Pattern;
			lineWidth: REAL;
			dashPatOn, dashPatOff: ARRAY MaxDashPatSize OF REAL;
			dashPatLen: LONGINT; dashPhase: REAL;
			capStyle: CapStyle; joinStyle: JoinStyle; styleLimit: REAL;
			flatness: REAL;
			font: GfxFonts.Font;
			ctm: GfxMatrix.Matrix;
			clip: ClipArea;
		END;

		PathData = RECORD (GfxPaths.EnumData)
			path: GfxPaths.Path;
		END;


	VAR
		Black*, White*, Red*, Green*, Blue*, Cyan*, Magenta*, Yellow*, LGrey*, MGrey*, DGrey*: Color;	(** standard colors **)
		DefaultCap*: CapStyle;	(** default line cap style (initially butt caps) **)
		DefaultJoin*: JoinStyle;	(** default line join style (initially miter joins) **)
	(*	DashPath: GfxPaths.Path;	(* path for temporarily storing dashes *)
		TmpPath: GfxPaths.Path; *)


	(**--- Contexts ---**)

	(** reset context to default values **)
	PROCEDURE Reset* (ctxt: Context);
	BEGIN
		ctxt.do.reset(ctxt)
	END Reset;

	(** initialize context values to defaults **)
	PROCEDURE Init* (ctxt: Context);
	BEGIN
		ctxt.ctm := GfxMatrix.Identity; ctxt.cam := ctxt.ctm;
		ctxt.strokeCol := Black; ctxt.strokePat := NIL;
		ctxt.fillCol := Black; ctxt.fillPat := NIL;
		ctxt.lineWidth := 1;
		ctxt.dashPatLen := 0; ctxt.dashPhase := 0; ctxt.dashPeriod := 0;
		ctxt.capStyle := DefaultCap; ctxt.joinStyle := DefaultJoin; ctxt.styleLimit := 5;
		ctxt.mode := {};
		ctxt.path := NIL;
		ctxt.cpx := 0; ctxt.cpy := 0;
		ctxt.flatness := 0.5;
		ctxt.font := GfxFonts.Default;
		IF ctxt.tmpPath = NIL THEN
			NEW(ctxt.tmpPath);
		END;
		IF ctxt.dashPath = NIL THEN
			NEW(ctxt.dashPath)
		END;
	END Init;

	(** save and restore graphics state **)
	PROCEDURE Save* (ctxt: Context; elems: SET; VAR state: State);
		VAR i: LONGINT;
	BEGIN
		state.saved := elems;
		state.strokeCol := ctxt.strokeCol; state.strokePat := ctxt.strokePat;
		state.fillCol := ctxt.fillCol; state.fillPat := ctxt.fillPat;
		state.lineWidth := ctxt.lineWidth;
		IF dashPat IN elems THEN
			state.dashPatLen := ctxt.dashPatLen; state.dashPhase := ctxt.dashPhase;
			i := 0;
			WHILE i < ctxt.dashPatLen DO
				state.dashPatOn[i] := ctxt.dashPatOn[i]; state.dashPatOff[i] := ctxt.dashPatOff[i]; INC(i)
			END
		END;
		state.capStyle := ctxt.capStyle; state.joinStyle := ctxt.joinStyle; state.styleLimit := ctxt.styleLimit;
		state.flatness := ctxt.flatness;
		state.font := ctxt.font;
		IF ctm IN elems THEN
			state.ctm := ctxt.ctm
		END;
		IF clip IN elems THEN
			state.clip := ctxt.do.getClip(ctxt)
		END
	END Save;

	PROCEDURE Restore* (ctxt: Context; state: State);
		VAR do: Methods;
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		do := ctxt.do;
		IF strokeColPat IN state.saved THEN
			do.setStrokeColor(ctxt, state.strokeCol);
			do.setStrokePattern(ctxt, state.strokePat)
		END;
		IF fillColPat IN state.saved THEN
			do.setFillColor(ctxt, state.fillCol);
			do.setFillPattern(ctxt, state.fillPat)
		END;
		IF lineWidth IN state.saved THEN
			do.setLineWidth(ctxt, state.lineWidth)
		END;
		IF dashPat IN state.saved THEN
			do.setDashPattern(ctxt, state.dashPatOn, state.dashPatOff, state.dashPatLen, state.dashPhase)
		END;
		IF capStyle IN state.saved THEN
			do.setCapStyle(ctxt, state.capStyle)
		END;
		IF joinStyle IN state.saved THEN
			do.setJoinStyle(ctxt, state.joinStyle)
		END;
		IF styleLimit IN state.saved THEN
			do.setStyleLimit(ctxt, state.styleLimit)
		END;
		IF flatness IN state.saved THEN
			do.setFlatness(ctxt, state.flatness)
		END;
		IF font IN state.saved THEN
			do.setFont(ctxt, state.font)
		END;
		IF ctm IN state.saved THEN
			do.setCTM(ctxt, state.ctm)
		END;
		IF clip IN state.saved THEN
			do.setClip(ctxt, state.clip)
		END
	END Restore;


	(**--- Coordinate System ---**)

	(** reset current transformation matrix **)
	PROCEDURE ResetCTM* (ctxt: Context);
	BEGIN
		ctxt.do.resetCTM(ctxt)
	END ResetCTM;

	(** set current transformation matrix **)
	PROCEDURE SetCTM* (ctxt: Context; VAR mat: GfxMatrix.Matrix);
	BEGIN
		ctxt.do.setCTM(ctxt, mat)
	END SetCTM;

	(** translate coordinate system **)
	PROCEDURE Translate* (ctxt: Context; dx, dy: REAL);
	BEGIN
		ctxt.do.translate(ctxt, dx, dy)
	END Translate;

	(** scale coordinate system at origin **)
	PROCEDURE Scale* (ctxt: Context; sx, sy: REAL);
	BEGIN
		ctxt.do.scale(ctxt, sx, sy)
	END Scale;

	(** scale coordinate system at specified point **)
	PROCEDURE ScaleAt* (ctxt: Context; sx, sy, x, y: REAL);
	BEGIN
		ctxt.do.translate(ctxt, x, y);
		ctxt.do.scale(ctxt, sx, sy);
		ctxt.do.translate(ctxt, -x, -y)
	END ScaleAt;

	(** rotate coordinate system at origin **)
	PROCEDURE Rotate* (ctxt: Context; sin, cos: REAL);
	BEGIN
		ctxt.do.rotate(ctxt, sin, cos)
	END Rotate;

	(** rotate coordinate system at specified point **)
	PROCEDURE RotateAt* (ctxt: Context; sin, cos, x, y: REAL);
	BEGIN
		ctxt.do.translate(ctxt, x, y);
		ctxt.do.rotate(ctxt, sin, cos);
		ctxt.do.translate(ctxt, -x, -y)
	END RotateAt;

	(** concat transformation matrix to CTM **)
	PROCEDURE Concat* (ctxt: Context; VAR mat: GfxMatrix.Matrix);
	BEGIN
		ctxt.do.concat(ctxt, mat)
	END Concat;


	(**--- Clipping ---**)

	(** reset clip path **)
	PROCEDURE ResetClip* (ctxt: Context);
	BEGIN
		ctxt.do.resetClip(ctxt)
	END ResetClip;

	(** get bounding box of clipping path in user coordinates **)
	PROCEDURE GetClipRect* (ctxt: Context; VAR llx, lly, urx, ury: REAL);
	BEGIN
		ctxt.do.getClipRect(ctxt, llx, lly, urx, ury)
	END GetClipRect;

	(** get current clipping area **)
	PROCEDURE GetClip* (ctxt: Context): ClipArea;
	BEGIN
		RETURN ctxt.do.getClip(ctxt)
	END GetClip;

	(** restore saved clipping path **)
	PROCEDURE SetClip* (ctxt: Context; clip: ClipArea);
	BEGIN
		ctxt.do.setClip(ctxt, clip)
	END SetClip;


	(**--- Graphics State ---**)

	(** set stroke color **)
	PROCEDURE SetStrokeColor* (ctxt: Context; color: Color);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.setStrokeColor(ctxt, color)
	END SetStrokeColor;

	(** set stroke pattern (NIL = solid) **)
	PROCEDURE SetStrokePattern* (ctxt: Context; pat: Pattern);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.setStrokePattern(ctxt, pat)
	END SetStrokePattern;

	(** set fill color **)
	PROCEDURE SetFillColor* (ctxt: Context; color: Color);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.setFillColor(ctxt, color)
	END SetFillColor;

	(** set fill pattern (NIL = solid) **)
	PROCEDURE SetFillPattern* (ctxt: Context; pat: Pattern);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.setFillPattern(ctxt, pat)
	END SetFillPattern;

	(** set line width **)
	PROCEDURE SetLineWidth* (ctxt: Context; width: REAL);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ASSERT(width >= 0.0, 101);
		ctxt.do.setLineWidth(ctxt, width)
	END SetLineWidth;

	(** set dash pattern **)
	PROCEDURE SetDashPattern* (ctxt: Context; VAR on, off: ARRAY OF REAL; len: LONGINT; phase: REAL);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ASSERT((len <= LEN(on)) & (len <= LEN(off)), 101);
		ctxt.do.setDashPattern(ctxt, on, off, len, phase)
	END SetDashPattern;

	(** copy values from parameter, and calculate dash period **)
	PROCEDURE SetDashArray* (ctxt: Context; VAR on, off: ARRAY OF REAL; len: LONGINT);
	BEGIN
		ctxt.dashPatLen := len;
		ctxt.dashPeriod := 0;
		IF len > 0 THEN
			REPEAT
				DEC(len);
				ctxt.dashPatOn[len] := on[len]; ctxt.dashPatOff[len] := off[len];
				ctxt.dashPeriod := ctxt.dashPeriod + on[len] + off[len]
			UNTIL len = 0
		END;
		ASSERT((ctxt.dashPatLen = 0) OR (ctxt.dashPeriod # 0), 120)
	END SetDashArray;

	(** set line cap style **)
	PROCEDURE SetCapStyle* (ctxt: Context; style: CapStyle);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ASSERT((NoCap <= style) & (style <= RoundCap), 101);
		ctxt.do.setCapStyle(ctxt, style)
	END SetCapStyle;

	(** set line join style **)
	PROCEDURE SetJoinStyle* (ctxt: Context; style: JoinStyle);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ASSERT((NoJoin <= style) & (style <= RoundJoin), 101);
		ctxt.do.setJoinStyle(ctxt, style)
	END SetJoinStyle;

	(** set style border factor **)
	PROCEDURE SetStyleLimit* (ctxt: Context; limit: REAL);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.setStyleLimit(ctxt, limit)
	END SetStyleLimit;

	(** set flatness parameter **)
	PROCEDURE SetFlatness* (ctxt: Context; flatness: REAL);
	BEGIN
		ctxt.do.setFlatness(ctxt, flatness)
	END SetFlatness;

	(** set current font **)
	PROCEDURE SetFont* (ctxt: Context; font: GfxFonts.Font);
	BEGIN
		ASSERT(font # NIL, 100);
		ctxt.do.setFont(ctxt, font)
	END SetFont;

	(** set current font using name and size **)
	PROCEDURE SetFontName* (ctxt: Context; fontname: ARRAY OF CHAR; size: INTEGER);
		VAR font: GfxFonts.Font;
	BEGIN
		font := GfxFonts.OpenSize(fontname, size);
		IF font = NIL THEN font := GfxFonts.Default END;
		ctxt.do.setFont(ctxt, font)
	END SetFontName;

	(** calculate distance that current point would move if given string were rendered **)
	PROCEDURE GetStringWidth* (ctxt: Context; str: ARRAY OF CHAR; VAR dx, dy: REAL);
	BEGIN
		ctxt.do.getWidth(ctxt, str, dx, dy)
	END GetStringWidth;


	(**--- Current Path ---**)

	(** start new path **)
	PROCEDURE Begin* (ctxt: Context; mode: SET);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.begin(ctxt, mode);
		INCL(ctxt.mode, InPath)
	END Begin;

	(** exit current subpath (if open) and end current path **)
	PROCEDURE End* (ctxt: Context);
	BEGIN
		ASSERT(InPath IN ctxt.mode, 100);
		IF InSubpath IN ctxt.mode THEN ctxt.do.exit(ctxt, 0, 0) END;
		ctxt.do.end(ctxt);
		EXCL(ctxt.mode, InPath)
	END End;

	(** end current subpath (if open) and begin new subpath **)
	PROCEDURE MoveTo* (ctxt: Context; x, y: REAL);
	BEGIN
		ASSERT(InPath IN ctxt.mode, 100);
		IF InSubpath IN ctxt.mode THEN ctxt.do.exit(ctxt, 0, 0) END;
		ctxt.do.enter(ctxt, x, y, 0, 0);
		INCL(ctxt.mode, InSubpath)
	END MoveTo;

	(** start subpath at inner point **)
	PROCEDURE Enter* (ctxt: Context; x, y, dx, dy: REAL);
	BEGIN
		ASSERT(InPath IN ctxt.mode, 100);
		IF InSubpath IN ctxt.mode THEN ctxt.do.exit(ctxt, 0, 0) END;
		ctxt.do.enter(ctxt, x, y, dx, dy);
		INCL(ctxt.mode, InSubpath)
	END Enter;

	(** end subpath at inner point **)
	PROCEDURE Exit* (ctxt: Context; dx, dy: REAL);
	BEGIN
		ASSERT(InSubpath IN ctxt.mode, 100);
		ctxt.do.exit(ctxt, dx, dy);
		EXCL(ctxt.mode, InSubpath)
	END Exit;

	(** close current subpath **)
	PROCEDURE Close* (ctxt: Context);
	BEGIN
		ASSERT(InSubpath IN ctxt.mode, 100);
		ctxt.do.close(ctxt);
		EXCL(ctxt.mode, InSubpath)
	END Close;

	(** append line to current path **)
	PROCEDURE LineTo* (ctxt: Context; x, y: REAL);
	BEGIN
		ASSERT(InSubpath IN ctxt.mode, 100);
		ctxt.do.line(ctxt, x, y)
	END LineTo;

	(** append arc to current path **)
	PROCEDURE ArcTo* (ctxt: Context; x, y, x0, y0, x1, y1, x2, y2: REAL);
	BEGIN
		ASSERT(InSubpath IN ctxt.mode, 100);
		ctxt.do.arc(ctxt, x, y, x0, y0, x1, y1, x2, y2)
	END ArcTo;

	(** append cubic bezier to current path **)
	PROCEDURE BezierTo* (ctxt: Context; x, y, x1, y1, x2, y2: REAL);
	BEGIN
		ASSERT(InSubpath IN ctxt.mode, 100);
		ctxt.do.bezier(ctxt, x, y, x1, y1, x2, y2)
	END BezierTo;

	(** append character outlines to current path at given point; advance current point to position after last character **)
	PROCEDURE ShowAt* (ctxt: Context; x, y: REAL; str: ARRAY OF CHAR);
	BEGIN
		ASSERT(InPath IN ctxt.mode, 100);
		IF InSubpath IN ctxt.mode THEN ctxt.do.exit(ctxt, 0, 0) END;
		ctxt.do.show(ctxt, x, y, str)
	END ShowAt;

	(** append character outlines to current path at current point; advance current point to position after last character **)
	PROCEDURE Show* (ctxt: Context; str: ARRAY OF CHAR);
	BEGIN
		ASSERT(InPath IN ctxt.mode, 100);
		IF InSubpath IN ctxt.mode THEN ctxt.do.exit(ctxt, 0, 0) END;
		ctxt.do.show(ctxt, ctxt.cpx, ctxt.cpy, str)
	END Show;


	(**--- Path Flattening ---**)

	(** replace arcs and beziers in current path by approximation using straight lines **)
	PROCEDURE Flatten* (ctxt: Context);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.flatten(ctxt)
	END Flatten;

	PROCEDURE EnumPathElem (VAR data: GfxPaths.EnumData);
	BEGIN
		WITH data: PathData DO
			CASE data.elem OF
			| GfxPaths.Enter: GfxPaths.AddEnter(data.path, data.x, data.y, data.dx, data.dy)
			| GfxPaths.Line: GfxPaths.AddLine(data.path, data.x, data.y)
			| GfxPaths.Exit: GfxPaths.AddExit(data.path, data.dx, data.dy)
			END
		END
	END EnumPathElem;

	(** store flattened current path in given path  **)
	PROCEDURE GetFlattenedPath* (ctxt: Context; path: GfxPaths.Path);
		VAR data: PathData;
	BEGIN
		ASSERT(ctxt.path # path, 100);
		GfxPaths.Clear(path);
		data.path := path;
		GfxPaths.EnumFlattened(ctxt.path, ctxt.flatness, EnumPathElem, data)
	END GetFlattenedPath;


	(**--- Cap Styles ---**)

	PROCEDURE EnterCapStyle* (ctxt: Context; x, y, dx, dy: REAL; path: GfxPaths.Path);
	BEGIN
		IF ctxt.capStyle = ButtCap THEN
			GfxPaths.AddEnter(path, x, y, dy, -dx);
			GfxPaths.AddLine(path, x + dy, y - dx)
		ELSIF ctxt.capStyle = SquareCap THEN
			GfxPaths.AddEnter(path, x - dx, y - dy, dy, -dx);
			GfxPaths.AddLine(path, x - dx + dy, y - dy - dx);
			GfxPaths.AddLine(path, x + dy, y - dx)
		ELSIF ctxt.capStyle = RoundCap THEN
			GfxPaths.AddEnter(path, x - dx, y - dy, dy, -dx);
			GfxPaths.AddArc(path, x + dy, y - dx, x, y, x - dx, y - dy, x + dy, y - dx)
		ELSE
			GfxPaths.AddEnter(path, x + dy, y - dx, 0, 0)
		END
	END EnterCapStyle;

	PROCEDURE AddCapStyle* (ctxt: Context; x, y, dx, dy: REAL; path: GfxPaths.Path);
	BEGIN
		IF ctxt.capStyle = ButtCap THEN
			GfxPaths.AddLine(path, x + dy, y - dx)
		ELSIF ctxt.capStyle = SquareCap THEN
			GfxPaths.AddLine(path, x - dx - dy, y - dy + dx);
			GfxPaths.AddLine(path, x - dx + dy, y - dy - dx);
			GfxPaths.AddLine(path, x + dy, y - dx)
		ELSIF ctxt.capStyle = RoundCap THEN
			GfxPaths.AddArc(path, x + dy, y - dx, x, y, x - dy, y + dx, x - dx, y - dy)
		ELSE
			GfxPaths.AddExit(path, 0, 0);
			GfxPaths.AddEnter(path, x + dy, y - dx, 0, 0)
		END
	END AddCapStyle;

	PROCEDURE ExitCapStyle* (ctxt: Context; x, y, dx, dy: REAL; path: GfxPaths.Path);
	BEGIN
		IF ctxt.capStyle = ButtCap THEN
			GfxPaths.AddLine(path, x, y);
			GfxPaths.AddExit(path, dy, -dx)
		ELSIF ctxt.capStyle = SquareCap THEN
			GfxPaths.AddLine(path, x - dx - dy, y - dy + dx);
			GfxPaths.AddLine(path, x - dx, y - dy);
			GfxPaths.AddExit(path, dy, -dx)
		ELSIF ctxt.capStyle = RoundCap THEN
			GfxPaths.AddArc(path, x - dx, y - dy, x, y, x - dy, y + dx, x - dx, y - dy);
			GfxPaths.AddExit(path, dy, -dx)
		ELSE
			GfxPaths.AddExit(path, 0, 0)
		END
	END ExitCapStyle;


	(**--- Join Styles ---**)

	(** return if half axis vector (in device coordinates) exceeds style limit **)
	PROCEDURE ExceedsLimit* (ctxt: Context; hx, hy: REAL): BOOLEAN;
		VAR limit: REAL;
	BEGIN
		GfxMatrix.ApplyToDist(ctxt.cam, 0.5*ctxt.lineWidth * ctxt.styleLimit, limit);
		RETURN hx * hx + hy * hy > limit * limit
	END ExceedsLimit;

	PROCEDURE EnterJoinStyle* (ctxt: Context; x, y, idx, idy, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
		VAR ix, iy, t: REAL;
	BEGIN
		IF (ctxt.joinStyle = BevelJoin) OR (ctxt.joinStyle = MiterJoin) & ExceedsLimit(ctxt, hx, hy) THEN
			GfxPaths.IntersectLines(x, y, hx, hy, x + ody, y - odx, -hy, hx, ix, iy);
			GfxPaths.AddEnter(path, ix, iy, -hy, hx);
			GfxPaths.AddLine(path, x + ody, y - odx)
		ELSIF ctxt.joinStyle = MiterJoin THEN
			GfxPaths.AddEnter(path, x + hx, y + hy, idx, idy);
			GfxPaths.AddLine(path, x + ody, y - odx)
		ELSIF ctxt.joinStyle = RoundJoin THEN
			t := Math.sqrt((odx * odx + ody * ody)/(hx * hx + hy * hy));
			GfxPaths.AddEnter(path, x + t * hx, y + t * hy, -hy, hx);
			GfxPaths.AddArc(path, x + ody, y - odx, x, y, x - odx, y - ody, x + ody, y - odx)
		ELSE
			GfxPaths.AddEnter(path, x + ody, y - odx, 0, 0)
		END
	END EnterJoinStyle;

	PROCEDURE AddJoinStyle* (ctxt: Context; x, y, idx, idy, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
	BEGIN
		IF (ctxt.joinStyle = BevelJoin) OR (ctxt.joinStyle = MiterJoin) & ExceedsLimit(ctxt, hx, hy) THEN
			GfxPaths.AddLine(path, x + ody, y - odx)
		ELSIF ctxt.joinStyle = MiterJoin THEN
			GfxPaths.AddLine(path, x + hx, y + hy);
			GfxPaths.AddLine(path, x + ody, y - odx)
		ELSIF ctxt.joinStyle = RoundJoin THEN
			GfxPaths.AddArc(path, x + ody, y - odx, x, y, x - odx, y - ody, x + ody, y - odx)
		ELSE
			GfxPaths.AddExit(path, 0, 0);
			GfxPaths.AddEnter(path, x + ody, y - odx, 0, 0)
		END
	END AddJoinStyle;

	PROCEDURE ExitJoinStyle* (ctxt: Context; x, y, idx, idy, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
		VAR ix, iy, t: REAL;
	BEGIN
		IF (ctxt.joinStyle = BevelJoin) OR (ctxt.joinStyle = MiterJoin) & ExceedsLimit(ctxt, hx, hy) THEN
			GfxPaths.IntersectLines(x, y, hx, hy, x + idy, y - idx, -hy, hx, ix, iy);
			GfxPaths.AddLine(path, ix, iy);
			GfxPaths.AddExit(path, -hy, hx)
		ELSIF ctxt.joinStyle = MiterJoin THEN
			GfxPaths.AddLine(path, x + hx, y + hy);
			GfxPaths.AddExit(path, odx, ody)
		ELSIF ctxt.joinStyle = RoundJoin THEN
			t := Math.sqrt((odx * odx + ody * ody)/(hx * hx + hy * hy));
			GfxPaths.AddArc(path, x + t * hx, y + t * hy, x, y, x - idx, y - idy, x + idy, y - idx);
			GfxPaths.AddExit(path, -hy, hx)
		ELSE
			GfxPaths.AddExit(path, 0, 0)
		END
	END ExitJoinStyle;


	(**--- Path Outline ---**)

	(** replace current path by outline of area which would be drawn to if the path were stroked **)
	PROCEDURE Outline* (ctxt: Context);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.outline(ctxt)
	END Outline;

	(** return vector scaled to given length **)
	PROCEDURE GetNormVector* (x, y, len: REAL; VAR nx, ny: REAL);
		VAR t: REAL;
	BEGIN
		t := len/Math.sqrt(x * x + y * y);
		nx := t * x; ny := t * y
	END GetNormVector;

	(** return vector to outer corner of two joining vectors whose lengths correspond to line width **)
	PROCEDURE GetHalfAxisVector* (idx, idy, odx, ody: REAL; VAR hx, hy: REAL);
		VAR cprod, t: REAL;
	BEGIN
		cprod := idx * ody - idy * odx;
		IF ABS(cprod) < 1.0E-3 THEN
			hx := 0; hy := 0
		ELSE	(* intersect outer border lines to find half axis vector *)
			t := ((idy - ody) * ody + (idx - odx) * odx)/cprod;
			IF cprod > 0 THEN	(* left turn *)
				hx := idy - t * idx; hy := -(idx + t * idy)
			ELSE	(* right turn *)
				hx := t * idx - idy; hy := idx + t * idy
			END
		END
	END GetHalfAxisVector;

	PROCEDURE AddEnterJoinStyle (ctxt: Context; x, y, hx, hy, odx, ody: REAL; path: GfxPaths.Path);
		VAR ix, iy, t: REAL;
	BEGIN
		IF (ctxt.joinStyle = BevelJoin) OR (ctxt.joinStyle = MiterJoin) & ExceedsLimit(ctxt, hx, hy) THEN
			GfxPaths.IntersectLines(x, y, hx, hy, x + ody, y - odx, -hy, hx, ix, iy);
			GfxPaths.AddLine(path, ix, iy); GfxPaths.AddLine(path, x + ody, y - odx)
		ELSIF ctxt.joinStyle = MiterJoin THEN
			GfxPaths.AddLine(path, x + hx, y + hy); GfxPaths.AddLine(path, x + ody, y - odx)
		ELSIF ctxt.joinStyle = RoundJoin THEN
			t := Math.sqrt((odx * odx + ody * ody)/(hx * hx + hy * hy));
			GfxPaths.AddLine(path, x + t * hx, y + t * hy);
			GfxPaths.AddArc(path, x + ody, y - odx, x, y, x - odx, y - ody, x + ody, y - odx)
		ELSE
			GfxPaths.AddLine(path, x + ody, y - odx)
		END
	END AddEnterJoinStyle;

	PROCEDURE AddExitJoinStyle (ctxt: Context; x, y, idx, idy, hx, hy: REAL; path: GfxPaths.Path);
		VAR ix, iy, t: REAL;
	BEGIN
		IF (ctxt.joinStyle = BevelJoin) OR (ctxt.joinStyle = MiterJoin) & ExceedsLimit(ctxt, hx, hy) THEN
			GfxPaths.IntersectLines(x, y, hx, hy, x + idy, y - idx, -hy, hx, ix, iy);
			GfxPaths.AddLine(path, ix, iy)
		ELSIF ctxt.joinStyle = MiterJoin THEN
			GfxPaths.AddLine(path, x + hx, y + hy)
		ELSIF ctxt.joinStyle = RoundJoin THEN
			t := Math.sqrt((idx * idx + idy * idy)/(hx * hx + hy * hy));
			GfxPaths.AddArc(path, x + t * hx, y + t * hy, x, y, x - idx, y - idy, x + idy, y - idx)
		END;
		GfxPaths.AddLine(path, x - hx, y - hy)
	END AddExitJoinStyle;

	PROCEDURE GetPolyOutline (ctxt: Context; VAR x, y: ARRAY OF REAL; n: LONGINT; dxi, dyi, dxo, dyo: REAL; dst: GfxPaths.Path);
		VAR closed: BOOLEAN; width, odx, ody, idx, idy, hx, hy: REAL; i, j: LONGINT;
	BEGIN
		closed := (x[n] = x[0]) & (y[n] = y[0]);
		GfxMatrix.ApplyToDist(ctxt.cam, 0.5*ctxt.lineWidth, width);
		GetNormVector(x[1] - x[0], y[1] - y[0], width, odx, ody);
		IF (dxi = 0) & (dyi = 0) THEN
			EnterCapStyle(ctxt, x[0], y[0], odx, ody, dst)
		ELSE
			GetNormVector(dxi, dyi, width, idx, idy);
			GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
			IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
				IF closed THEN
					GfxPaths.AddEnter(dst, x[0] + ody, y[0] - odx, dxi, dyi)
				ELSE
					GfxPaths.AddEnter(dst, x[0] - ody, y[0] + odx, ody, -odx);
					GfxPaths.AddLine(dst, x[0] + ody, y[0] - odx)
				END
			ELSIF idx * ody > idy * odx THEN	(* starts with left turn *)
				IF closed THEN
					EnterJoinStyle(ctxt, x[0], y[0], idx, idy, hx, hy, odx, ody, dst)
				ELSE
					GfxPaths.AddEnter(dst, x[0] - hx, y[0] - hy, ody, -odx);
					AddEnterJoinStyle(ctxt, x[0], y[0], hx, hy, odx, ody, dst)
				END
			ELSE
				IF closed THEN
					GfxPaths.AddEnter(dst, x[0] - hx, y[0] - hy, dxi, dyi)
				ELSE
					GfxPaths.AddEnter(dst, x[0] + hx, y[0] + hy, -hx, -hy);
					GfxPaths.AddLine(dst, x[0] - hx, y[0] - hy)
				END
			END
		END;

		i := 1; j := 2;
		WHILE j <= n DO
			idx := odx; idy := ody;
			GetNormVector(x[j] - x[i], y[j] - y[i], width, odx, ody);
			GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
			IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
				GfxPaths.AddLine(dst, x[i] + idy, y[i] - idx)
			ELSIF idx * ody > idy * odx THEN	(* left turn => outer join *)
				GfxPaths.AddLine(dst, x[i] + idy, y[i] - idx);
				AddJoinStyle(ctxt, x[i], y[i], idx, idy, hx, hy, odx, ody, dst)
			ELSE	(* right turn => inner join *)
				GfxPaths.AddLine(dst, x[i] - hx, y[i] - hy)
			END;
			i := j; INC(j)
		END;

		idx := odx; idy := ody;
		IF (dxo = 0) & (dyo = 0) THEN
			GfxPaths.AddLine(dst, x[n] + ody, y[n] - odx);
			AddCapStyle(ctxt, x[n], y[n], -odx, -ody, dst)
		ELSE
			GfxPaths.AddLine(dst, x[n] + idy, y[n] - idx);
			GetNormVector(dxo, dyo, width, odx, ody);
			GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
			IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
				IF closed THEN
					GfxPaths.AddExit(dst, odx, ody);
					GfxPaths.AddEnter(dst, x[n] - idy, y[n] + idx, -dxo, -dyo)
				ELSE
					GfxPaths.AddLine(dst, x[n] - idy, y[n] + idx)
				END
			ELSIF idx * ody > idy * odx THEN	(* ends in left turn *)
				IF closed THEN
					ExitJoinStyle(ctxt, x[n], y[n], idx, idy, hx, hy, odx, ody, dst);
					GfxPaths.AddEnter(dst, x[n] - hx, y[n] - hy, -dxo, -dyo)
				ELSE
					AddExitJoinStyle(ctxt, x[n], y[n], idx, idy, hx, hy, dst)
				END
			ELSE
				GfxPaths.AddLine(dst, x[n] - hx, y[n] - hy);
				IF closed THEN
					GfxPaths.AddExit(dst, dxo, dyo);
					EnterJoinStyle(ctxt, x[n], y[n], -odx, -ody, -hx, -hy, -idx, -idy, dst)
				ELSE
					AddEnterJoinStyle(ctxt, x[n], y[n], -hx, -hy, -idx, -idy, dst)
				END
			END
		END;

		odx := -idx; ody := -idy;
		i := n-1; j := n-2;
		WHILE j >= 0 DO
			idx := odx; idy := ody;
			GetNormVector(x[j] - x[i], y[j] - y[i], width, odx, ody);
			GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
			IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
				GfxPaths.AddLine(dst, x[i] + idy, y[i] - idx)
			ELSIF idx * ody > idy * odx THEN	(* left turn => outer join *)
				GfxPaths.AddLine(dst, x[i] + idy, y[i] - idx);
				AddJoinStyle(ctxt, x[i], y[i], idx, idy, hx, hy, odx, ody, dst)
			ELSE	(* right turn => inner join *)
				GfxPaths.AddLine(dst, x[i] - hx, y[i] - hy)
			END;
			i := j; DEC(j)
		END;

		IF (dxi = 0) & (dyi = 0) THEN
			GfxPaths.AddLine(dst, x[0] + ody, y[0] - odx);
			ExitCapStyle(ctxt, x[0], y[0], -odx, -ody, dst)
		ELSE
			idx := odx; idy := ody;
			GetNormVector(-dxi, -dyi, width, odx, ody);
			GetHalfAxisVector(idx, idy, odx, ody, hx, hy);
			GfxPaths.AddLine(dst, x[0] + idy, y[0] - idx);
			IF (hx = 0) & (hy = 0) THEN	(* collinear vectors *)
				IF closed THEN
					GfxPaths.AddExit(dst, -dxi, -dyi)
				ELSE
					GfxPaths.AddExit(dst, -idy, idx)
				END
			ELSIF idx * ody > idy * odx THEN	(* left turn *)
				IF closed THEN
					ExitJoinStyle(ctxt, x[0], y[0], idx, idy, hx, hy, odx, ody, dst)
				ELSE
					AddExitJoinStyle(ctxt, x[0], y[0], idx, idy, hx, hy, dst);
					GfxPaths.AddExit(dst, -idx, -idy)
				END
			ELSE
				GfxPaths.AddLine(dst, x[0] - hx, y[0] - hy);
				IF closed THEN
					GfxPaths.AddExit(dst, -dxi, -dyi)
				ELSE
					GfxPaths.AddExit(dst, hx, hy)
				END
			END
		END
	END GetPolyOutline;

	PROCEDURE GetStrokeOutline (ctxt: Context; VAR scan: GfxPaths.Scanner; dst: GfxPaths.Path);
		CONST last = 127;
		VAR x, y: ARRAY last+1 OF REAL; dxi, dyi, dxo, dyo: REAL; n: LONGINT;
	BEGIN
		ASSERT(scan.elem = GfxPaths.Enter);
		x[0] := scan.x; y[0] := scan.y; dxi := scan.dx; dyi := scan.dy;
		GfxPaths.Scan(scan); n := 0;
		WHILE scan.elem = GfxPaths.Line DO
			IF n < last THEN
				INC(n); x[n] := scan.x; y[n] := scan.y
			ELSE
				dxo := scan.x - x[n]; dyo := scan.y - y[n];
				GetPolyOutline(ctxt, x, y, n, dxi, dyi, dxo, dyo, dst);
				dxi := x[n] - x[n-1]; dyi := y[n] - y[n-1];
				x[0] := x[n]; y[0] := y[n];
				x[1] := scan.x; y[1] := scan.y;
				n := 1
			END;
			GfxPaths.Scan(scan)
		END;
		IF n > 0 THEN
			GetPolyOutline(ctxt, x, y, n, dxi, dyi, scan.dx, scan.dy, dst)
		END;
		GfxPaths.Scan(scan)
	END GetStrokeOutline;

	(** get offset values and pattern index of visible and invisible dash part at start of subpath (in device space) **)
	PROCEDURE GetDashOffsets* (ctxt: Context; offset: REAL; VAR beg, end, next: REAL; VAR idx: LONGINT);
		VAR phase, period, len: REAL;
	BEGIN
		idx := 0;
		GfxMatrix.ApplyToDist(ctxt.cam, ctxt.dashPhase, phase);
		GfxMatrix.ApplyToDist(ctxt.cam, ctxt.dashPeriod, period);
		beg := ENTIER((phase + offset)/period) * period - phase;	(* offset - period < beg <= offset *)
		LOOP
			GfxMatrix.ApplyToDist(ctxt.cam, ctxt.dashPatOn[idx], len);
			end := beg + len;
			GfxMatrix.ApplyToDist(ctxt.cam, ctxt.dashPatOff[idx], len);
			next := end + len;
			idx := (idx+1) MOD ctxt.dashPatLen;
			IF next > offset THEN EXIT END;
			beg := next
		END
	END GetDashOffsets;

	PROCEDURE GetDashOutline (ctxt: Context; VAR scan: GfxPaths.Scanner; dst: GfxPaths.Path);
		VAR
			width, cx, cy, dx, dy, beg, end, next, offset, len, cos, sin, wdx, wdy, endOff, dash, nx, ny: REAL;
			index: LONGINT; dscan: GfxPaths.Scanner;
	BEGIN
		GfxMatrix.ApplyToDist(ctxt.cam, 0.5*ctxt.lineWidth, width);
		ASSERT(scan.elem = GfxPaths.Enter);
		cx := scan.x; cy := scan.y; dx := scan.dx; dy := scan.dy;
		GfxPaths.Scan(scan);
		GetDashOffsets(ctxt, 0, beg, end, next, index);
		IF 0 < end THEN	(* starts within dash *)
			IF width = 0 THEN
				GfxPaths.AddEnter(dst, cx, cy, dx, dy)
			ELSE
				GfxPaths.Clear(ctxt.dashPath);
				GfxPaths.AddEnter(ctxt.dashPath, cx, cy, dx, dy)
			END
		END;
		offset := 0;
		WHILE scan.elem = GfxPaths.Line DO
			dx := scan.x - cx; dy := scan.y - cy;
			len := Math.sqrt(dx * dx + dy * dy);
			cos := dx/len; sin := dy/len;
			endOff := offset + len;
			IF offset < end THEN	(* begin of line is within dash *)
				IF end <= endOff THEN	(* end of current dash comes before end of line => finish current dash *)
					len := end - offset;
					IF width = 0 THEN
						GfxPaths.AddLine(dst, cx + len * cos, cy + len * sin);
						GfxPaths.AddExit(dst, 0, 0)
					ELSE
						GfxPaths.AddLine(ctxt.dashPath, cx + len * cos, cy + len * sin);
						GfxPaths.AddExit(ctxt.dashPath, 0, 0);
						GfxPaths.Open(dscan, ctxt.dashPath, 0);
						GetStrokeOutline(ctxt, dscan, dst)
					END
				ELSIF width = 0 THEN	(* continue current dash to end of line *)
					GfxPaths.AddLine(dst, scan.x, scan.y)
				ELSE
					GfxPaths.AddLine(ctxt.dashPath, scan.x, scan.y)
				END
			END;
			IF next < endOff THEN	(* next dash starts before end of line => draw complete dashes *)
				wdx := width * cos; wdy := width * sin;
				beg := offset;
				REPEAT
					len := next - beg;
					cx := cx + len * cos; cy := cy + len * sin;
					beg := next;
					GfxMatrix.ApplyToDist(ctxt.cam, ctxt.dashPatOn[index], dash);
					end := beg + dash;
					GfxMatrix.ApplyToDist(ctxt.cam, ctxt.dashPatOff[index], dash);
					next := end + dash;
					index := (index+1) MOD ctxt.dashPatLen;
					IF end <= endOff THEN	(* next dash can be fully drawn *)
						len := end - beg;
						nx := cx + len * cos; ny := cy + len * sin;
						IF width = 0 THEN
							GfxPaths.AddEnter(dst, cx, cy, 0, 0);
							GfxPaths.AddLine(dst, nx, ny);
							GfxPaths.AddExit(dst, 0, 0)
						ELSE
							EnterCapStyle(ctxt, cx, cy, wdx, wdy, dst);
							GfxPaths.AddLine(dst, nx + wdy, ny - wdx);
							AddCapStyle(ctxt, nx, ny, -wdx, -wdy, dst);
							GfxPaths.AddLine(dst, cx - wdy, cy + wdx);
							ExitCapStyle(ctxt, cx, cy, wdx, wdy, dst)
						END
					END
				UNTIL next >= endOff;
				IF endOff < end THEN	(* next dash not complete => hasn't been started yet *)
					IF width = 0 THEN
						GfxPaths.AddEnter(dst, cx, cy, 0, 0);
						GfxPaths.AddLine(dst, scan.x, scan.y)
					ELSE
						GfxPaths.Clear(ctxt.dashPath);
						GfxPaths.AddEnter(ctxt.dashPath, cx, cy, 0, 0);
						GfxPaths.AddLine(ctxt.dashPath, scan.x, scan.y)
					END
				END
			END;
			cx := scan.x; cy := scan.y; offset := endOff;
			GfxPaths.Scan(scan)
		END;
		ASSERT(scan.elem = GfxPaths.Exit);
		IF offset < end THEN	(* currently within dash => end properly *)
			IF width = 0 THEN
				GfxPaths.AddExit(dst, scan.dx, scan.dy)
			ELSE
				GfxPaths.AddExit(ctxt.dashPath, scan.dx, scan.dy);
				GfxPaths.Open(dscan, ctxt.dashPath, 0);
				GetStrokeOutline(ctxt, dscan, dst)
			END
		END;
		GfxPaths.Scan(scan)
	END GetDashOutline;

	(** store outline/dashes of current path in specified path **)
	PROCEDURE GetOutline* (ctxt: Context; dst: GfxPaths.Path);
		VAR scan: GfxPaths.Scanner;
	BEGIN
		ASSERT(dst # ctxt.path, 100);
		ctxt.do.flatten(ctxt);
		GfxPaths.Clear(dst);
		GfxPaths.Open(scan, ctxt.path, 0);
		WHILE scan.elem = GfxPaths.Enter DO
			IF ctxt.dashPatLen > 0 THEN
				GetDashOutline(ctxt, scan, dst)
			ELSE
				GetStrokeOutline(ctxt, scan, dst)
			END
		END
	END GetOutline;


	(**--- Drawing Operations ---**)

	(** draw current path in requested mode **)
	PROCEDURE Render* (ctxt: Context; mode: SET);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		EXCL(mode, Record);
		IF mode # {} THEN
			ctxt.do.render(ctxt, mode)
		END
	END Render;

	(** draw given path in requested mode **)
	PROCEDURE DrawPath* (ctxt: Context; path: GfxPaths.Path; mode: SET);
		VAR scan: GfxPaths.Scanner;
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		IF path = ctxt.path THEN
			Render(ctxt, mode)
		ELSE
			ctxt.do.begin(ctxt, mode);
			GfxPaths.Open(scan, path, 0);
			WHILE scan.elem # GfxPaths.Stop DO
				CASE scan.elem OF
				| GfxPaths.Enter: ctxt.do.enter(ctxt, scan.x, scan.y, scan.dx, scan.dy)
				| GfxPaths.Line: ctxt.do.line(ctxt, scan.x, scan.y);
				| GfxPaths.Arc: ctxt.do.arc(ctxt, scan.x, scan.y, scan.x0, scan.y0, scan.x1, scan.y1, scan.x2, scan.y2)
				| GfxPaths.Bezier: ctxt.do.bezier(ctxt, scan.x, scan.y, scan.x1, scan.y1, scan.x2, scan.y2)
				| GfxPaths.Exit: ctxt.do.exit(ctxt, scan.dx, scan.dy)
				END;
				GfxPaths.Scan(scan);
			END;
			ctxt.do.end(ctxt)
		END
	END DrawPath;

	(** draw line in requested mode **)
	PROCEDURE DrawLine* (ctxt: Context; x0, y0, x1, y1: REAL; mode: SET);
	BEGIN
		IF (x0=x1)&(y0=y1) THEN RETURN END; (*optimization PH 2012*)
		ASSERT(~(InPath IN ctxt.mode), 100);
		ASSERT(mode * {Fill, Clip, EvenOdd} = {}, 101);
		ctxt.do.begin(ctxt, mode);
		ctxt.do.enter(ctxt, x0, y0, 0, 0);
		ctxt.do.line(ctxt, x1, y1);
		ctxt.do.exit(ctxt, 0, 0);
		ctxt.do.end(ctxt)
	END DrawLine;

	(** draw arc in requested mode (start and end angle in radians; negative radius for clockwise arc) **)
	PROCEDURE DrawArc* (ctxt: Context; x, y, r, start, end: REAL; mode: SET);
		VAR x1, y1, x2, y2: REAL;
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ASSERT(mode * {Fill, Clip, EvenOdd} = {}, 101);
		IF r > 0 THEN x1 := x + r; y1 := y; x2 := x; y2 := y + r
		ELSIF r < 0 THEN r := -r; x1 := x; y1 := y + r; x2 := x + r; y2 := y
		ELSE RETURN
		END;
		ctxt.do.begin(ctxt, mode);
		ctxt.do.enter(ctxt, x + r * Math.cos(start), y + r * Math.sin(start), 0, 0);
		ctxt.do.arc(ctxt, x + r * Math.cos(end), y + r * Math.sin(end), x, y, x1, y1, x2, y2);
		ctxt.do.end(ctxt)
	END DrawArc;

	(** draw rectangle in requested mode **)
	PROCEDURE DrawRect* (ctxt: Context; x0, y0, x1, y1: REAL; mode: SET);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.begin(ctxt, mode);
		ctxt.do.rect(ctxt, x0, y0, x1, y1);
		ctxt.do.end(ctxt)
	END DrawRect;

	(** draw circle in requested mode (clockwise if r > 0, counterclockwise if r < 0) **)
	PROCEDURE DrawCircle* (ctxt: Context; x, y, r: REAL; mode: SET);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.begin(ctxt, mode);
		ctxt.do.ellipse(ctxt, x, y, r, ABS(r));
		ctxt.do.end(ctxt)
	END DrawCircle;

	(** draw ellipse in requested mode (clockwise if rx*ry > 0, counterclockwise if rx*ry < 0) **)
	PROCEDURE DrawEllipse* (ctxt: Context; x, y, rx, ry: REAL; mode: SET);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.begin(ctxt, mode);
		ctxt.do.ellipse(ctxt, x, y, rx, ry);
		ctxt.do.end(ctxt)
	END DrawEllipse;

	(** draw string at given coordinates and move current point to string end **)
	PROCEDURE DrawStringAt* (ctxt: Context; x, y: REAL; str: ARRAY OF CHAR);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.begin(ctxt, {Fill});
		ctxt.do.show(ctxt, x, y, str);
		ctxt.do.end(ctxt)
	END DrawStringAt;

	(** draw string at current point and move current point to string end **)
	PROCEDURE DrawString* (ctxt: Context; str: ARRAY OF CHAR);
	BEGIN
		ASSERT(~(InPath IN ctxt.mode), 100);
		ctxt.do.begin(ctxt, {Fill});
		ctxt.do.show(ctxt, ctxt.cpx, ctxt.cpy, str);
		ctxt.do.end(ctxt)
	END DrawString;


	(**--- Images and Patterns ---**)

	(** draw image at given point **)
	PROCEDURE DrawImageAt* (ctxt: Context; x, y: REAL; img: GfxImages.Image; VAR filter: GfxImages.Filter);
	BEGIN
		ctxt.do.image(ctxt, x, y, img, filter)
	END DrawImageAt;

	(** return new pattern **)
	PROCEDURE NewPattern* (ctxt: Context; img: GfxImages.Image; px, py: REAL): Pattern;
	BEGIN
		RETURN ctxt.do.newPattern(ctxt, img, px, py)
	END NewPattern;


	(**--- Default Methods ---**)

	PROCEDURE DefResetContext* (ctxt: Context);
	BEGIN
		Init(ctxt);
		ctxt.do.resetClip(ctxt);
		ctxt.do.resetCTM(ctxt)
	END DefResetContext;

	PROCEDURE DefSetCTM* (ctxt: Context; VAR mat: GfxMatrix.Matrix);
	BEGIN
		ctxt.ctm := mat
	END DefSetCTM;

	PROCEDURE DefTranslate* (ctxt: Context; dx, dy: REAL);
	BEGIN
		GfxMatrix.Translate(ctxt.ctm, dx, dy, ctxt.ctm)
	END DefTranslate;

	PROCEDURE DefScale* (ctxt: Context; sx, sy: REAL);
	BEGIN
		GfxMatrix.Scale(ctxt.ctm, sx, sy, ctxt.ctm)
	END DefScale;

	PROCEDURE DefRotate* (ctxt: Context; sin, cos: REAL);
	BEGIN
		GfxMatrix.Rotate(ctxt.ctm, sin, cos, ctxt.ctm)
	END DefRotate;

	PROCEDURE DefConcat* (ctxt: Context; VAR mat: GfxMatrix.Matrix);
	BEGIN
		GfxMatrix.Concat(mat, ctxt.ctm, ctxt.ctm)
	END DefConcat;

	PROCEDURE DefSetStrokeColor* (ctxt: Context; color: Color);
	BEGIN
		ctxt.strokeCol := color
	END DefSetStrokeColor;

	PROCEDURE DefSetStrokePattern* (ctxt: Context; pat: Pattern);
	BEGIN
		ctxt.strokePat := pat
	END DefSetStrokePattern;

	PROCEDURE DefSetFillColor* (ctxt: Context; color: Color);
	BEGIN
		ctxt.fillCol := color
	END DefSetFillColor;

	PROCEDURE DefSetFillPattern* (ctxt: Context; pat: Pattern);
	BEGIN
		ctxt.fillPat := pat
	END DefSetFillPattern;

	PROCEDURE DefSetLineWidth* (ctxt: Context; width: REAL);
	BEGIN
		ctxt.lineWidth := width
	END DefSetLineWidth;

	PROCEDURE DefSetDashPattern* (ctxt: Context; VAR on, off: ARRAY OF REAL; len: LONGINT; phase: REAL);
	BEGIN
		SetDashArray(ctxt, on, off, len);
		ctxt.dashPhase := phase
	END DefSetDashPattern;

	PROCEDURE DefSetCapStyle* (ctxt: Context; style: CapStyle);
	BEGIN
		ctxt.capStyle := style
	END DefSetCapStyle;

	PROCEDURE DefSetJoinStyle* (ctxt: Context; style: JoinStyle);
	BEGIN
		ctxt.joinStyle := style
	END DefSetJoinStyle;

	PROCEDURE DefSetStyleLimit* (ctxt: Context; limit: REAL);
	BEGIN
		ctxt.styleLimit := limit
	END DefSetStyleLimit;

	PROCEDURE DefSetFlatness* (ctxt: Context; flatness: REAL);
	BEGIN
		ctxt.flatness := flatness
	END DefSetFlatness;

	PROCEDURE DefSetFont* (ctxt: Context; font: GfxFonts.Font);
	BEGIN
		ctxt.font := font
	END DefSetFont;

	PROCEDURE DefGetStringWidth* (ctxt: Context; VAR str: ARRAY OF CHAR; VAR dx, dy: REAL);
	BEGIN
		GfxFonts.GetStringWidth(ctxt.font, str, dx, dy)
	END DefGetStringWidth;

	PROCEDURE DefFlatten* (ctxt: Context);
	BEGIN
		GetFlattenedPath(ctxt, ctxt.tmpPath);
		GfxPaths.Copy(ctxt.tmpPath, ctxt.path);
		GfxPaths.Clear(ctxt.tmpPath)
	END DefFlatten;

	PROCEDURE DefOutline* (ctxt: Context);
	BEGIN
		GetOutline(ctxt, ctxt.tmpPath);
		GfxPaths.Copy(ctxt.tmpPath, ctxt.path);
		GfxPaths.Clear(ctxt.tmpPath)
	END DefOutline;

	PROCEDURE DefRect* (ctxt: Context; x0, y0, x1, y1: REAL);
	BEGIN
		ctxt.do.enter(ctxt, x0, y0, 0, y0 - y1);
		ctxt.do.line(ctxt, x1, y0); ctxt.do.line(ctxt, x1, y1); ctxt.do.line(ctxt, x0, y1); ctxt.do.line(ctxt, x0, y0);
		ctxt.do.exit(ctxt, x1 - x0, 0)
	END DefRect;

	PROCEDURE DefEllipse* (ctxt: Context; x, y, rx, ry: REAL);
		VAR xr: REAL;
	BEGIN
		xr := x + rx;
		IF xr # x THEN
			ctxt.do.enter(ctxt, xr, y, 0, ry);
			ctxt.do.arc(ctxt, xr, y, x, y, xr, y, x, y + ry);
			ctxt.do.exit(ctxt, 0, ry)
		END
	END DefEllipse;

	PROCEDURE DefNewPattern* (ctxt: Context; img: GfxImages.Image; px, py: REAL): Pattern;
		VAR pat: Pattern;
	BEGIN
		NEW(pat); pat.img := img; pat.px := px; pat.py := py;
		RETURN pat
	END DefNewPattern;


	(*--- Initialization of Standard Colors ---*)

	PROCEDURE InitColors;
		PROCEDURE init (VAR col: Color; r, g, b: INTEGER);
		BEGIN
			col.r := r; col.g := g; col.b := b; col.a := 255
		END init;
	BEGIN
		init(Black, 0, 0, 0); init(White, 255, 255, 255); init(Red, 255, 0, 0); init(Green, 0, 255, 0); init(Blue, 0, 0, 255);
		init(Cyan, 0, 255, 255); init(Magenta, 255, 0, 255); init(Yellow, 255, 255, 0);
		init(LGrey, 192, 192, 192); init(MGrey, 160, 160, 160); init(DGrey, 128, 128, 128)
	END InitColors;


BEGIN
	InitColors;
	DefaultCap := ButtCap; DefaultJoin := MiterJoin
END Gfx.
