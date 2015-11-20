MODULE ReleaseVisualizer;(** AUTHOR "TF"; PURPOSE "Generate module overview poster"; *)

IMPORT
	Streams, Modules, KernelLog, Commands, Options, Strings, Files, WMRectangles,
	Texts, TextUtilities, Scanner := ReleaseVisualizerScanner, PDF,
	WMMessages, WMGraphics, WMGraphicUtilities, WMWindowManager, WMComponents, WMStandardComponents;

CONST
	BoxH = 100; VSpace = 20;
	BoxW = 200; HSpace = 20;
	E = 0; N = 1; W = 2; S = 3;
	KeepAwayDist = 5;

	TraceSC = FALSE;

	DefaultContext = "A2";

TYPE

	Import* = POINTER TO RECORD
		m* : ModuleInfo;
		next* : Import;
	END;

	ModuleInfo* = OBJECT
	VAR
		name*, context* : ARRAY 32 OF CHAR;
		desc*, file* : Strings.String;
		author*, purpose* : Strings.String;
		imports* : Import;
		linesOfCode : LONGINT;
		ok* : BOOLEAN;
		maxdepth : LONGINT;
		level* : LONGINT;
		nofTotalImports* : LONGINT; (* how often the module is imported *)
		nofDirectImports* : LONGINT; (* how often the module is imported directly*)
		icMod : ModuleInfo;
		icDecision : BOOLEAN;
		reference* : ANY;
		group*, subgroup* : LONGINT;
		subsystems* : SET;

		PROCEDURE Dump(details : BOOLEAN);
		VAR import : Import;
		BEGIN
			KernelLog.String(name); KernelLog.String(" IN "); KernelLog.String(context); KernelLog.String(": ");
			KernelLog.String("D = "); KernelLog.Int(nofDirectImports, 0);
			KernelLog.String(", T = "); KernelLog.Int(nofTotalImports, 0);
			KernelLog.String(", mD = "); KernelLog.Int(maxdepth, 0);
			KernelLog.String(", group = "); KernelLog.Int(group, 0);
			KernelLog.String(", sGroup = "); KernelLog.Int(subgroup, 0);
			IF details THEN
				KernelLog.String(" [");
				import := imports;
				WHILE (import	# NIL) DO
					KernelLog.String(import.m.name);
					import := import.next;
					IF (import # NIL) THEN KernelLog.String(", "); END;
				END;
				KernelLog.String("]");
			END;
			KernelLog.Ln;
		END Dump;

		PROCEDURE &Init(CONST name, context : ARRAY OF CHAR);
		BEGIN
			ASSERT((name # "") & (context # ""));
			COPY(name, SELF.name);
			COPY(context, SELF.context);
			desc := NIL; file := NIL; author := NIL; purpose := NIL;
			imports := NIL;
			linesOfCode := 0;
			ok := FALSE;
			maxdepth := -1;
			level := 0;
			nofTotalImports := 0; nofDirectImports := 0;
			icMod := NIL;
			icDecision := FALSE;
			reference := NIL;
			group := 0; subgroup := 0;
			subsystems := {};
		END Init;

	END ModuleInfo;

	ModuleArray* = POINTER TO ARRAY OF ModuleInfo;

	ModuleList* = OBJECT
	VAR
		modules* : ModuleArray;
		nofModules* : LONGINT;
		errors : BOOLEAN;
		s : Scanner.Scanner;

		currentModule : ModuleInfo;
		currentFile : Files.FileName;

		PROCEDURE &Init;
		BEGIN
			NEW(modules, 128); nofModules := 0;
			errors := FALSE;
			s := NIL;
			currentModule := NIL;
			currentFile := "";
		END Init;

		PROCEDURE Grow;
		VAR n : ModuleArray; i : LONGINT;
		BEGIN
			NEW(n, LEN(modules) * 2);
			FOR i := 0 TO nofModules - 1 DO n[i] := modules[i] END;
			modules := n;
		END Grow;

		PROCEDURE CalcNofDirectImports;
		VAR import : Import; i : LONGINT;
		BEGIN
			FOR i := 0 TO nofModules - 1 DO
				import := modules[i].imports;
				WHILE import # NIL DO
					INC(import.m.nofDirectImports);
					import := import.next
				END
			END
		END CalcNofDirectImports;

		PROCEDURE CalcTotalImports*;
		VAR import : Import; i : LONGINT;
		BEGIN
			CalcNofDirectImports;
			FOR i := 0 TO nofModules - 1 DO
				import := modules[i].imports;
				WHILE import # NIL DO
					INC(import.m.nofTotalImports, import.m.nofDirectImports);
					import := import.next
				END
			END
		END CalcTotalImports;

		PROCEDURE CalcLevels*(maxLevel : LONGINT);
		VAR imp : Import; i, j, l, pass : LONGINT; changed : BOOLEAN;
		BEGIN
			FOR i := 0 TO nofModules - 1 DO
				IF modules[i].nofTotalImports = 0 THEN modules[i].level := maxLevel;
				ELSE modules[i].level := GetDepth(modules[i]);
				END;
			END;
			changed := TRUE;
			pass := 0;
			WHILE changed DO
				changed := FALSE;
				INC(pass);
				KernelLog.String("Improving level structure, pass "); KernelLog.Int(pass, 0); KernelLog.Ln;
				FOR i := 0 TO nofModules - 1 DO
					IF modules[i].nofTotalImports # 0 THEN
						l := MAX(LONGINT);
						FOR j := 0 TO nofModules - 1 DO
							imp := modules[j].imports;
							WHILE imp # NIL DO
								IF imp.m =  modules[i] THEN
									l := Strings.Min(l, modules[j].level -1);
								END;
								imp := imp.next
							END
						END;
						IF modules[i].level # l THEN
							modules[i].level := l;
							changed := TRUE;
						END
					END
				END;
			END
		END CalcLevels;

		PROCEDURE GetDepth*(m : ModuleInfo) : LONGINT;
		VAR imp : Import; d, max : LONGINT;
		BEGIN
			IF m.maxdepth # -1 THEN RETURN m.maxdepth END;
			max := -1;
			imp := m.imports;
			WHILE imp # NIL DO
				d := GetDepth(imp.m);
				IF d > max THEN max := d END;
				imp := imp.next
			END;
			m.maxdepth := max + 1;
			RETURN m.maxdepth
		END GetDepth;

		(* directly or indirectly imports *)
		PROCEDURE Imports*(m, i : ModuleInfo) : BOOLEAN;
		VAR imp : Import;
		BEGIN
			IF m.icMod = i THEN RETURN m.icDecision END;
			imp := m.imports;
			WHILE imp # NIL DO
				IF (imp.m = i) OR Imports(imp.m, i) THEN
					m.icMod := i; m.icDecision := TRUE;
					RETURN TRUE
				END;
				imp := imp.next
			END;
			m.icMod := i; m.icDecision := FALSE;
			RETURN FALSE
		END Imports;

		PROCEDURE Dump*(details : BOOLEAN);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO nofModules - 1 DO
				modules[i].Dump(details);
			END;
		END Dump;

		PROCEDURE GetModule*(CONST name, context : ARRAY OF CHAR) : ModuleInfo;
		VAR i : LONGINT;
		BEGIN
			i := 0; WHILE (i < nofModules) & ((modules[i].name # name) OR (modules[i].context # context)) DO INC(i) END;
			IF i < nofModules THEN
				RETURN modules[i]
			ELSE
				IF nofModules >= LEN(modules) - 1 THEN Grow END;
				NEW(modules[nofModules], name, context);
				INC(nofModules);
				RETURN modules[i]
			END
		END GetModule;

		PROCEDURE AddImport*(m : ModuleInfo; CONST importName, context : ARRAY OF CHAR);
		VAR il : Import;
		BEGIN
			IF importName = "SYSTEM" THEN RETURN END;
			NEW(il); il.m := GetModule(importName, context);
			il.next := m.imports; m.imports := il
		END AddImport;

		PROCEDURE Error(CONST str : ARRAY OF CHAR);
		BEGIN
			KernelLog.String(currentFile);
			IF (s # NIL) THEN KernelLog.String("@"); KernelLog.Int(s.errpos, 0); END;
			KernelLog.String(" : "); KernelLog.String(str); KernelLog.Ln;
			errors := TRUE;
		END Error;

		PROCEDURE Eat(sym : LONGINT);
		BEGIN
			IF s.sym = sym THEN Next;
			ELSE
				KernelLog.String(currentFile); KernelLog.String("@"); KernelLog.Int(s.errpos, 0);
				KernelLog.String(" : sym = "); KernelLog.Int(sym, 0); KernelLog.String(" expected");
				KernelLog.String(", found sym = "); KernelLog.Int(s.sym, 0); KernelLog.Ln;
			END
		END Eat;

		(* add the comment to the currents tructure *)
		PROCEDURE CommentToStructure;
		VAR
			str : Strings.String;
			sr : Streams.StringReader;
			t : ARRAY 16 OF CHAR;
			author : ARRAY 32 OF CHAR;
			purpose : ARRAY 1024 OF CHAR;
		BEGIN
			str := s.commentStr.GetString();
			NEW(sr, s.commentStr.GetLength());
			sr.Set(str^);
			WHILE sr.res = 0 DO
				sr.SkipWhitespace;
				sr.Token(t);
				IF t = "AUTHOR" THEN
					sr.SkipWhitespace;
					sr.String(author);
					currentModule.author := Strings.NewString(author);
				END;
				IF t = "PURPOSE" THEN
					sr.SkipWhitespace;
					sr.String(purpose);
					currentModule.purpose := Strings.NewString(purpose);
				END;
			END
		END CommentToStructure;

		PROCEDURE Next;
		BEGIN
			s.Next;
			WHILE s.sym = Scanner.comment DO
				CommentToStructure;
				s.Next
			END
		END Next;

		PROCEDURE ParseImports;
		VAR modName, context : ARRAY 64 OF CHAR;
		BEGIN
			WHILE s.sym = Scanner.ident DO
				COPY(s.str, modName);
				Next;
				IF s.sym = Scanner.becomes THEN
					Next;
					IF s.sym = Scanner.ident  THEN
						COPY(s.str, modName);
						Next;
					ELSE
						Error("Expected module identifier");
					END;
				END;
				IF (s.sym = Scanner.in) THEN
					Next;
					IF (s.sym = Scanner.ident) THEN
						COPY(s.str, context);
						Next;
					ELSE
						Error("Expected context identifier");
					END;
				ELSE
					COPY(DefaultContext, context);
				END;
				AddImport(currentModule, modName, context);
				IF s.sym = Scanner.comma THEN Next END;
			END;
			Eat(Scanner.semicolon)
		END ParseImports;

		PROCEDURE ParseModule;
		VAR moduleName, context : ARRAY 64 OF CHAR;
		BEGIN
			IF s.sym = Scanner.module THEN
				Next;
				IF s.sym = Scanner.ident THEN
					COPY(s.str, moduleName);
					Next;
					IF s.sym = Scanner.in THEN
						Next;
						IF s.sym = Scanner.ident THEN
							COPY(s.str, context);
							Next;
						ELSE Error("Context identifier expected");
						END;
					ELSE
						COPY(DefaultContext, context);
					END;
					currentModule := GetModule(moduleName, context);
				ELSE Error("Module identifier expected");
				END;
				Eat(Scanner.semicolon);
			ELSE Error("Module expected")
			END;

			IF s.sym = Scanner.import THEN
				Next;
				ParseImports;
			END
		END ParseModule;

		PROCEDURE ScanModule(CONST filename : ARRAY OF CHAR);
		VAR text : Texts.Text; format, res : LONGINT; s : Scanner.Scanner;
		BEGIN
			COPY(filename, currentFile);
			NEW(text);
			TextUtilities.LoadAuto(text, filename, format, res);
			IF res # 0 THEN
				KernelLog.String(filename); KernelLog.String(" not found"); KernelLog.Ln;
				RETURN
			END;
			s := Scanner.InitWithText(text, 0);
			SELF.s := s;
			Next; (* establish one look ahead *)
			currentModule := NIL;
			ParseModule;
			IF (currentModule # NIL) THEN
				currentModule.linesOfCode := CountLines(text);
			END;
		END ScanModule;

		PROCEDURE ScanForModules(CONST filemask : ARRAY OF CHAR; out : Streams.Writer);
		VAR enum : Files.Enumerator; name : ARRAY 256 OF CHAR; flags : SET; time, date, size, nofFiles : LONGINT;
		BEGIN
			IF (out # NIL) THEN out.String("Scanning modules "); out.String(filemask); out.String(" ... "); out.Update; END;
			nofModules := 0;
			NEW(enum);
			enum.Open(filemask, {});
			WHILE enum.HasMoreEntries() DO
				IF enum.GetEntry(name, flags, time, date, size) & ~(Files.Directory IN flags) THEN
					INC(nofFiles);
					ScanModule(name)
				END
			END;
			IF (out # NIL) THEN out.Int(nofFiles, 0); out.String(" files found."); out.Ln; out.Update; END;
		END ScanForModules;

	END ModuleList;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	RealRect* = RECORD l*, t*, r*, b* : LONGREAL; END;
	Point = RECORD x, y : LONGREAL END;
	PointArray = POINTER TO ARRAY OF Point;

	Object = OBJECT
	VAR
		aabb: RealRect;
		parent : Object;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; dx, dy, fx, fy : LONGREAL);
		BEGIN
		END Draw;

	END Object;

	ObjectList = POINTER TO ARRAY OF Object;

	Graphic = OBJECT (Object)
	VAR
		list : ObjectList;
		nofObj : LONGINT;

		PROCEDURE &Init;
		BEGIN
			NEW(list, 8);
		END Init;

		PROCEDURE Add(o : Object);
		VAR nl : ObjectList; i : LONGINT;
		BEGIN
			o.parent := SELF;
			IF nofObj >= LEN(list) THEN
				NEW(nl, LEN(list) * 2);
				FOR i := 0 TO LEN(list) - 1 DO nl[i] := list[i] END;
				list := nl
			END;
			list[nofObj] := o;
			INC(nofObj)
		END Add;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; dx, dy, fx, fy : LONGREAL);
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO nofObj - 1 DO
				list[i].Draw(canvas, dx + fx * aabb.l, dy + fy * aabb.t, fx, fy);
			END
		END Draw;

	END Graphic;

	Rectangle = OBJECT(Object)

		PROCEDURE Draw(canvas : WMGraphics.Canvas; dx, dy, fx, fy : LONGREAL);
		BEGIN
			WMGraphicUtilities.DrawRect(canvas,
				WMRectangles.MakeRect(ENTIER(dx + fx * aabb.l), ENTIER(dy + fy * aabb.t),
										ENTIER(dx + fx * aabb.r), ENTIER(dy + fy * aabb.b)),
				0FFH, WMGraphics.ModeCopy);
		END Draw;

	END Rectangle;

	Line = OBJECT(Object)

		PROCEDURE Draw(canvas : WMGraphics.Canvas; dx, dy, fx, fy : LONGREAL);
		BEGIN
			canvas.Line(ENTIER(dx + fx * aabb.l), ENTIER(dy + fy * aabb.t), ENTIER(dx + fx * aabb.r), ENTIER(dy + fy * aabb.b),
				0FFH, WMGraphics.ModeCopy);
		END Draw;

	END Line;

	Title  = OBJECT(Object)
	VAR title : ARRAY 100 OF CHAR;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; dx, dy, fx, fy : LONGREAL);
		BEGIN
			canvas.SetFont(WMGraphics.GetFont("Vera", ENTIER(75 * fy + 0.5),  {}));
			IF canvas IS PDF.PDFCanvas THEN canvas(PDF.PDFCanvas).PDFSetFont("Courier", ENTIER(75 * SHORT(fy)), {}) END;
			canvas.DrawString(ENTIER(dx + aabb.l * fx), ENTIER(dy + (aabb.t + 75) * fy), title);
		END Draw;

	END Title;

TYPE

	SmartConnector = OBJECT (Object)
	VAR
		from, to : Object;
		way : PointArray;
		nofPoints : LONGINT;
		a, b : Point;

		PROCEDURE &Init;
		BEGIN
			NEW(way, 150);
		END Init;

		PROCEDURE SetFromTo(f, t : Object);
		BEGIN
			from := f;
			to := t;
			CalcPath
		END SetFromTo;

		PROCEDURE CalcDirs(p, d : Point; VAR alternate : LONGINT; VAR d0, d1 : LONGREAL) : LONGINT;
		VAR l, t : BOOLEAN; dir : LONGINT;
		BEGIN
			l := p.x > d.x; t := p.y > d.y;
			IF ABS(p.x - d.x) > ABS(p.y - d.y) THEN
				IF l THEN dir := W ELSE dir := E END;
				IF t THEN alternate := N ELSE alternate := S END;
				d0 := ABS(p.x - d.x);
				d1 := ABS(p.y - d.y);
			ELSE
				IF t THEN dir := N ELSE dir := S END;
				IF l THEN alternate := W ELSE alternate := E END;
				d0 := ABS(p.y - d.y);
				d1 := ABS(p.x - d.x);
			END;
			IF d1 < 0.01 THEN d1 := 10; END;
			RETURN dir
		END CalcDirs;

		PROCEDURE HasIntersection(p : Point; d : LONGINT; VAR mdist : LONGREAL; VAR colBox : RealRect) : BOOLEAN;
		VAR g : Graphic;
			o : Object;
			dist : LONGREAL;
			inter, first : BOOLEAN;
			i : LONGINT;
		BEGIN
			IF (parent # NIL) & (parent IS Graphic) THEN
				g := parent(Graphic);
				first := TRUE;
				FOR i := 0 TO g.nofObj - 1 DO
					o := g.list[i];
					IF (o # NIL) & (o IS ModuleBox) THEN
						inter := FALSE;
						CASE d OF
							|E : IF (o.aabb.l > p.x) & (p.y >= o.aabb.t - KeepAwayDist) & (p.y <= o.aabb.b + KeepAwayDist) THEN dist := o.aabb.l - p.x; inter := TRUE END
							|N : IF (o.aabb.b < p.y) & (p.x >= o.aabb.l - KeepAwayDist) & (p.x <= o.aabb.r + KeepAwayDist) THEN dist := p.y - o.aabb.b; inter := TRUE END
							|W : IF (o.aabb.r < p.x) & (p.y >= o.aabb.t - KeepAwayDist) & (p.y <= o.aabb.b + KeepAwayDist) THEN dist := p.x - o.aabb.r; inter := TRUE END
							|S :  IF (o.aabb.t > p.y) & (p.x >= o.aabb.l - KeepAwayDist) & (p.x <= o.aabb.r + KeepAwayDist) THEN dist := o.aabb.t - p.y; inter := TRUE END
						END;
						IF inter THEN
							IF first THEN mdist := dist; first := FALSE; colBox := o.aabb;
							ELSE
								IF dist < mdist THEN
									colBox := o.aabb;
									mdist := dist
								END
							END
						END
					END
				END
			END;
			RETURN ~first
		END HasIntersection;

		PROCEDURE Go(VAR p : Point; d : LONGINT; dist : LONGREAL);
		BEGIN
			IF TraceSC THEN KernelLog.String("Going "); END;
			CASE d OF
				|E : p.x := p.x + dist ;IF TraceSC THEN KernelLog.String("East ") END;
				|N : p.y := p.y - dist ;IF TraceSC THEN KernelLog.String("North ") END;
				|W : p.x := p.x - dist ;IF TraceSC THEN KernelLog.String("West ") END;
				|S : p.y := p.y + dist ;IF TraceSC THEN KernelLog.String("South ") END;
			END;
			IF TraceSC THEN KernelLog.Int(ENTIER(dist), 0); KernelLog.Ln END;
		END Go;

		PROCEDURE CalcPath;
		VAR  p : Point;
			d, altd, lc, lastDir : LONGINT;
			d0, d1, dist : LONGREAL;
			colBox : RealRect;
			ta, tb : Point;
			rla, rlb : LONGREAL;
		BEGIN
			a.x := (from.aabb.l + from.aabb.r) / 2; a.y := (from.aabb.t + from.aabb.b) / 2;
			b.x := (to.aabb.l + to.aabb.r) / 2; b.y := (to.aabb.t + to.aabb.b) / 2;
			IF from IS ModuleBox THEN rla := from(ModuleBox).rellayerpos ELSE rla := 10 END;
			IF to IS ModuleBox THEN rlb := to(ModuleBox).rellayerpos ELSE rlb := 10 END;

			(* define start and end position *)
			d := CalcDirs(a, b, altd, d0, d1);
			d := N;
			CASE d OF
				|E : a.x := from.aabb.r; b.x := to.aabb.l; ta := a; ta.x := ta.x + rla; tb := b; tb.x := tb.x - rlb;
				|N : a.y := from.aabb.t; b.y := to.aabb.b; ta := a; ta.y := ta.y - rla; tb := b; tb.y := tb.y + rlb;
				|W : a.x := from.aabb.l; b.x := to.aabb.r; ta := a; ta.x := ta.x - rla; tb := b; tb.x := tb.x + rlb;
				|S : a.y := from.aabb.b; b.y := to.aabb.t; ta := a; ta.y := ta.y + rla; tb := b; tb.y := tb.y - rlb;
			END;

			lc := 0;
			nofPoints := 0;
			way[nofPoints] := a; INC(nofPoints);
			way[nofPoints] := ta; INC(nofPoints);
			p := ta; lastDir := d;
			WHILE (lc < 100) & ((ABS(p.x - tb.x) > 0.001) OR (ABS(p.y - tb.y) > 0.001)) DO
				d := CalcDirs(p, tb, altd, d0, d1);
				(* never go back *)
				IF (lastDir + 2) MOD 4= d THEN d := altd; d0 := d1 END;
				IF HasIntersection(p, d, dist, colBox) & (dist < d0) THEN
					IF dist - KeepAwayDist > BoxH THEN
						Go(p, d, dist - KeepAwayDist);
					ELSE
						CASE lastDir OF
							|W : Go(p, lastDir, p.x - colBox.l + KeepAwayDist + 1);
							|N : Go(p, lastDir, p.y - colBox.t  + KeepAwayDist + 1);
							|E : Go(p, lastDir, colBox.r - p.x + KeepAwayDist + 1);
							|S : Go(p, lastDir, colBox.t - p.y  + KeepAwayDist + 1);
						END;
					END
				ELSE
					Go(p, d, d0);
					lastDir := d
				END;

				IF nofPoints > 140 THEN
					p := tb;
					KernelLog.String("Failed."); KernelLog.Ln;
				END;
				way[nofPoints] := p; INC(nofPoints);
				INC(lc)
			END;
			way[nofPoints] := b; INC(nofPoints);
		END CalcPath;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; dx, dy, fx, fy : LONGREAL);
		VAR i : LONGINT;
		BEGIN
			FOR i := 1 TO nofPoints - 1 DO
				canvas.Line(ENTIER(dx + fx * way[i - 1].x), ENTIER(dy + fy * way[i - 1].y),
							ENTIER(dx + fx * way[i].x), ENTIER(dy + fy * way[i].y), 0FFH, WMGraphics.ModeCopy);
			END
		END Draw;
	END SmartConnector;

	ModuleBox = OBJECT(Rectangle)
	VAR
		name, info : ARRAY 64 OF CHAR;
		color : LONGINT;
		m : ModuleInfo;
		rellayerpos : LONGREAL;

		PROCEDURE Draw(canvas : WMGraphics.Canvas; dx, dy, fx, fy : LONGREAL);
		VAR
			r, rect : WMRectangles.Rectangle;
			ty : LONGREAL;
			sec : ARRAY 30 OF CHAR;
			i, l : LONGINT;
		BEGIN
			r := WMRectangles.MakeRect(ENTIER(dx + fx * aabb.l), ENTIER(dy + fy * aabb.t),
										ENTIER(dx + fx * aabb.r), ENTIER(dy + fy * aabb.b));
			canvas.Fill(r, color, WMGraphics.ModeCopy);
			Draw^(canvas, dx, dy, fx, fy);
			canvas.SetFont(WMGraphics.GetFont("Oberon", ENTIER(15 * fy + 0.5),  {WMGraphics.FontBold}));

			IF canvas IS PDF.PDFCanvas THEN canvas(PDF.PDFCanvas).PDFSetFont("Courier", ENTIER(12 * SHORT(fy)), {WMGraphics.FontBold}) END;
			ty := 15;
			canvas.DrawString(ENTIER(r.l + fx), r.t + ENTIER(ty * fy), name);
			canvas.Line(r.l, r.t + ENTIER((ty + 3) * fy), r.r, r.t + ENTIER((ty + 3) * fy), 0FFH,WMGraphics.ModeCopy);

			ty := ty + 15;
			canvas.SetFont(WMGraphics.GetFont("Oberon", ENTIER(15 * fy + 0.5),  {}));
			IF canvas IS PDF.PDFCanvas THEN canvas(PDF.PDFCanvas).PDFSetFont("Courier", ENTIER(12 * SHORT(fy)), {}) END;
			canvas.DrawString(ENTIER(r.l + fx), r.t + ENTIER(ty * fy), info);
			ty := ty + 15;
			IF m.author # NIL THEN
				canvas.DrawString(ENTIER(r.l + fx), r.t + ENTIER(ty * fy), m.author^);
				ty := ty + 15
			 END;
			IF m.purpose # NIL THEN
				canvas.SetColor(WMGraphics.Black);
				rect := WMRectangles.MakeRect(r.l + ENTIER(fx), r.t + ENTIER((ty - 15) * fy), r.r, r.b);
				WMGraphics.DrawStringInRect(canvas, rect, TRUE, WMComponents.AlignTop, WMComponents.AlignLeft, m.purpose^);

	(*			i := 0; l := Strings.Length(m.purpose^);
				WHILE i < l DO
					Strings.Copy(m.purpose^, i, Strings.Min(25, l - i), sec);
					canvas.DrawString(ENTIER(r.l + fx), r.t + ENTIER(ty * fy), sec);
					ty := ty + 15;
					INC(i, 25)
				END *)
			END;

		END Draw;

	END ModuleBox;

	DrawSpace = OBJECT(WMComponents.VisualComponent)
	VAR
		g : Graphic;
		dx, dy : LONGREAL;

		PROCEDURE &Init;
		BEGIN
			Init^;
			NEW(g);
		END Init;

		PROCEDURE XSetPos(dx, dy : LONGREAL);
		BEGIN
			SELF.dx := dx; SELF.dy := dy;
			Invalidate;
		END XSetPos;

		PROCEDURE Draw(canvas : WMGraphics.Canvas);
		BEGIN
			g.Draw(canvas, -dx, -dy, 0.5, 0.5);
		END Draw;

	END DrawSpace;

	SubSystemInfo = RECORD
		mn : ARRAY 64 OF CHAR;
		m : ModuleInfo;
		color : LONGINT;
		nr, group : LONGINT;
		propagate : BOOLEAN; (* modules that import modules from this subsystem are part of the subsystem? *)
	END;

	SubSystems = OBJECT
	VAR
		s : ARRAY 1024 OF SubSystemInfo;
		scount, colorTable : ARRAY 64 OF LONGINT;
		nofSubSystemInfo : LONGINT;
		ml : ModuleList;

		PROCEDURE AddSubSystem(nr : LONGINT; CONST baseModule, context : ARRAY OF CHAR; color, group : LONGINT; propagate : BOOLEAN);
		BEGIN
			COPY(baseModule, s[nr].mn);
			s[nofSubSystemInfo].m := ml.GetModule(baseModule, context);
			s[nofSubSystemInfo].color := color;
			s[nofSubSystemInfo].nr := nr;
			s[nofSubSystemInfo].group := group;
			s[nofSubSystemInfo].propagate := propagate;
			colorTable[nr] := color;
			INC(nofSubSystemInfo)
		END AddSubSystem;

		PROCEDURE GetColor(snr : LONGINT) : LONGINT;
		VAR i, res : LONGINT;
		BEGIN
			res := LONGINT(0FF0000FFH);
			FOR i := 0 TO nofSubSystemInfo - 1 DO
				IF s[i].nr = snr THEN res := s[i].color END
			END;
			RETURN res
		END GetColor;

		PROCEDURE &Init(ml : ModuleList);
		CONST
			ColorRuntime = LONGINT(0A0A0FFFFH);
			ColorUsb = LONGINT(0A0A0A0FFH);
		VAR
			i, j : LONGINT;
		BEGIN
			ASSERT(ml # NIL);
			SELF.ml := ml;
			i := 32; j := 32;
			DEC(j); DEC(j);
				AddSubSystem(i, "Trace", "A2", LONGINT(ColorRuntime), j, FALSE);
				AddSubSystem(i, "Machine", "A2", LONGINT(ColorRuntime), j, FALSE);
				AddSubSystem(i, "Heaps", "A2", LONGINT(ColorRuntime), j, FALSE);
				AddSubSystem(i, "Modules", "A2", LONGINT(ColorRuntime), j, FALSE);
				AddSubSystem(i, "Objects", "A2", LONGINT(ColorRuntime), j, FALSE);
				AddSubSystem(i, "Kernel", "A2", LONGINT(ColorRuntime), j, FALSE);
			DEC(j); DEC(i);
				AddSubSystem(i, "Sound", "A2", 0008080FFH, j, TRUE);
			DEC(j); DEC(i);
				AddSubSystem(i, "WMPerfMonPlugins", "A2", LONGINT(0FF0000FFH), j, TRUE);
			DEC(j); DEC(i);
				AddSubSystem(i, "UsbDebug", "A2", LONGINT(ColorUsb), j, TRUE);
				AddSubSystem(i, "UsbDriverLoader", "A2", LONGINT(ColorUsb), j, TRUE);
				AddSubSystem(i, "Usbdi", "A2", LONGINT(ColorUsb), j, TRUE);
				AddSubSystem(i, "UsbHcdi", "A2", LONGINT(ColorUsb), j, TRUE);
				AddSubSystem(i, "UsbHidUP", "A2", LONGINT(ColorUsb), j, TRUE);
			DEC(j); DEC(i);
				AddSubSystem(i, "Bluetooth", "A2", 0000080FFH, j, TRUE);
			DEC(j); DEC(i);
				AddSubSystem(i, "FoxBasic", "A2", 06060FFFFH, j, TRUE);
				AddSubSystem(i, "BitSets", "A2", 06060FFFFH, j, TRUE);
				AddSubSystem(i, "Runtime", "A2", 06060FFFFH, j, TRUE);
				AddSubSystem(i, "ObjectFile", "A2", 06060FFFFH, j, TRUE);
				AddSubSystem(i, "FoxProgTools", "A2", 06060FFFFH, j, TRUE);
			DEC(j); DEC(i);
				AddSubSystem(i, "StringPool", "A2", 0008000FFH, j, TRUE);
				AddSubSystem(i, "PCDebug", "A2", 0008000FFH, j, TRUE);
			DEC(j);	DEC(i);
				AddSubSystem(i, "Network", "A2", LONGINT(0800080FFH), j, TRUE);
					DEC(i);
				AddSubSystem(i, "WebHTTPServer", "A2", LONGINT(08000C0FFH), j, TRUE);
			DEC(j);	DEC(i);
				AddSubSystem(i, "WindowManager", "A2", LONGINT(0FFFF80FFH), j, TRUE);
				AddSubSystem(i, "WMWindowManager", "A2", LONGINT(0FFFF80FFH), j, TRUE);
					DEC(i);
				AddSubSystem(i, "WMComponents", "A2", LONGINT(0FF8080FFH), j, TRUE);
					DEC(i);
				AddSubSystem(i, "XMLScanner", "A2", LONGINT(0800080FFH), 0, TRUE);
				AddSubSystem(i, "XMLObjects", "A2", LONGINT(0800080FFH), 0, TRUE);
		END Init;

		PROCEDURE CheckModule(m : ModuleInfo);
		VAR i : LONGINT;
		BEGIN
			ASSERT((m # NIL) & (m.group = 0) & (m.subgroup = 0));
			FOR i := 0 TO nofSubSystemInfo - 1 DO
				IF s[i].m # NIL THEN
					IF (s[i].propagate & ml.Imports(m, s[i].m)) OR (m = s[i].m) THEN
						IF m.group = 0 THEN m.group := s[i].group END;
						IF m.subgroup = 0 THEN m.subgroup := s[i].nr END;
						INCL(m.subsystems, s[i].nr); INC(scount[s[i].nr])
					END;
				END
			END
		END CheckModule;

	END SubSystems;

	ModuleInfoList = POINTER TO ARRAY OF ModuleInfo;

	Level = RECORD
		n : LONGINT;
		m : ModuleInfoList;
		groupLength, groupStart : ARRAY 32 OF LONGINT;
		(* starting from 0 *)
		nofGroups : LONGINT;
		groupCounts : ARRAY 32 OF LONGINT;
		groupSlots : ARRAY 32 OF LONGINT;
		yAdvance : LONGINT;
	END;

	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		label: WMStandardComponents.Label;
		viewer : DrawSpace;
		hScroll, vScroll : WMStandardComponents.Scrollbar;

		range : WMRectangles.Rectangle;
		ml : ModuleList;
		subSystems : SubSystems;

		PROCEDURE CreateForm(): WMComponents.VisualComponent;
		VAR panel, toolbar : WMStandardComponents.Panel; button : WMStandardComponents.Button;
		BEGIN
			NEW(panel); panel.bounds.SetExtents(800, 700); panel.fillColor.Set(0FFFFFFFFH); panel.takesFocus.Set(TRUE);

			NEW(toolbar); toolbar.fillColor.Set(000FF00FFH); toolbar.bounds.SetHeight(20); toolbar.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(toolbar);

			NEW(button); button.alignment.Set(WMComponents.AlignLeft); button.caption.SetAOC("PDF");
			button.onClick.Add(WritePDF);
			toolbar.AddContent(button);

			NEW(label); label.bounds.SetHeight(20); label.alignment.Set(WMComponents.AlignTop);
			panel.AddContent(label);

			NEW(hScroll); hScroll.alignment.Set(WMComponents.AlignBottom); hScroll.vertical.Set(FALSE); panel.AddContent(hScroll);
			hScroll.onPositionChanged.Add(ScrollbarsChanged);

			NEW(vScroll); vScroll.alignment.Set(WMComponents.AlignRight); panel.AddContent(vScroll);
			vScroll.onPositionChanged.Add(ScrollbarsChanged);

			NEW(viewer); viewer.alignment.Set(WMComponents.AlignClient); panel.AddContent(viewer);

			RETURN panel
		END CreateForm;

		PROCEDURE &New(ml : ModuleList);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			ASSERT(ml # NIL);
			SELF.ml := ml;

			IncCount;
			vc := CreateForm();

			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			SetContent(vc);

			 WMWindowManager.DefaultAddWindow(SELF);
			SetTitle(Strings.NewString("Release Visualizer"));

			NEW(subSystems, ml);
			Populate;
		END New;

		PROCEDURE ScrollbarsChanged(sender, data : ANY);
		BEGIN
			viewer.Acquire;
			viewer.XSetPos(hScroll.pos.Get(), vScroll.pos.Get());
			viewer.Release;
		END ScrollbarsChanged;

		PROCEDURE WritePDF(sender, data : ANY);
		VAR pdfPage : WMGraphics.Canvas; pdfCreator : PDF.PDFCreator; minf : REAL;
		BEGIN
			NEW(pdfCreator);
			pdfPage := pdfCreator.NewPage(PDF.PageA0, TRUE, PDF.Unitmm100);
			viewer.Acquire;
			KernelLog.String("Creating PDF structure ... "); KernelLog.Ln;
			minf := (pdfPage.limits.r - pdfPage.limits.l) / (range.r - range.l + 100);
			IF (pdfPage.limits.b - pdfPage.limits.t) / (range.b - range.t) < minf THEN
				minf := (pdfPage.limits.b - pdfPage.limits.t) / (range.b - range.t + 100)
			END;
			viewer.g.Draw(pdfPage, range.l + 50, range.t + 50, minf, minf);
			KernelLog.String("done, store PDF in file Test.pdf ... "); KernelLog.Ln;
			viewer.Release;
			pdfCreator.Store("Test.pdf");
			KernelLog.String("done."); KernelLog.Ln;
		END WritePDF;

		PROCEDURE Populate;
		VAR mb : ModuleBox;
			i, j, k  : LONGINT;
			levels : POINTER TO ARRAY OF Level;
			s : ARRAY 10 OF CHAR;
			m: ModuleInfo;
			maxDepth : LONGINT;
			ssStartPos, ms : ARRAY 32 OF LONGINT;
			sp : LONGINT;
			r : Line;
			t : Title;
			maxW, lastG, g, gc, y : LONGINT;
			maxProb, maxProbGroup, totSlots : LONGINT;

			PROCEDURE Compare(m0, m1 : ModuleInfo) : BOOLEAN;
			VAR a, b, c : LONGINT;
			BEGIN
				IF m0.group> m1.group THEN RETURN TRUE
				ELSIF m0.group < m1.group THEN RETURN FALSE
				END;
				IF m0.subgroup> m1.subgroup THEN RETURN TRUE
				ELSIF m0.subgroup < m1.subgroup THEN RETURN FALSE
				END;
				c := 31;
				WHILE c > 0 DO
					a := c; WHILE (a > 0) & ~(a IN m0.subsystems) DO DEC(a) END;
					b :=c; WHILE (b > 0) & ~(b IN m1.subsystems) DO DEC(b) END;
					IF a < b THEN RETURN TRUE
					ELSIF a > b THEN RETURN FALSE
					END;
					DEC(c);
				END;
				RETURN m0.nofDirectImports < m1.nofDirectImports
			END Compare;

			PROCEDURE QuickSort(data : ModuleInfoList ; lo, hi: LONGINT);
			VAR i, j : LONGINT;
				t, x : ModuleInfo;
			BEGIN
				i := lo; j := hi; x := data[(lo+hi) DIV 2];
				WHILE (i <= j) DO
					WHILE Compare(data[i], x)  DO INC(i) END;
					WHILE Compare(x, data[j]) DO DEC(j) END;
					IF (i <= j) THEN
						t := data[i]; data[i] := data[j]; data[j] := t;
						INC(i); DEC(j)
					END
				END;

				IF lo < j THEN QuickSort(data, lo, j) END;
				IF i < hi THEN QuickSort(data, i, hi) END
			END QuickSort;

		BEGIN
			ASSERT(ml # NIL);
			NEW(r);
			KernelLog.String("Found "); KernelLog.Int(ml.nofModules, 0); KernelLog.String(" modules."); KernelLog.Ln;

			KernelLog.String("Compute imports statistics ... ");
			ml.CalcTotalImports;
			KernelLog.String("done."); KernelLog.Ln;

			(* find max depth used *)
			maxDepth := 0;
			FOR i := 0 TO ml.nofModules - 1 DO
				m := ml.modules[i];
				m.reference := NIL;
				m.subsystems := {};
				subSystems.CheckModule(m);
				maxDepth := Strings.Max(maxDepth, ml.GetDepth(m));
			END;
			INC(maxDepth);

			KernelLog.String("Calculating levels ...");
			ml.CalcLevels(maxDepth);
			KernelLog.String("done."); KernelLog.Ln;

			NEW(levels, maxDepth + 1);

			(* store the data in the levels *)
			FOR i := 0 TO ml.nofModules - 1 DO
				m := ml.modules[i];
					IF levels[m.level].m = NIL THEN NEW(levels[m.level].m, ml.nofModules) (* worst case *)END;
					levels[m.level].m[levels[m.level].n] := m;
					INC(levels[m.level].n);
			END;

			FOR j := 0 TO 31 DO ms[j] := 0 END;
			FOR i := 0 TO LEN(levels) - 1 DO
				IF levels[i].m # NIL THEN
					QuickSort(levels[i].m, 0, levels[i].n - 1);

					(* calc members of most important subsystem *)
					FOR j := 0 TO 31 DO levels[i].groupLength[j] := 0 END;

					lastG := levels[i].m[0].group; g := 0;
					FOR j := 0 TO levels[i].n - 1 DO
						m := levels[i].m[j];
						IF m.group # lastG THEN INC(g); lastG := m.group END;
						INC(levels[i].groupCounts[g]);
						INC(levels[i].groupLength[m.group]);
					END;
					levels[i].groupStart[0] := 0;
					FOR j := 1 TO 31 DO levels[i].groupStart[j] := levels[i].groupStart[j - 1] + levels[i].groupLength[j - 1] END;
					(* calculate max length for each group *)
					levels[i].nofGroups := 0;
					FOR j := 0 TO 31 DO
						ms[j] := Strings.Max(ms[j], levels[i].groupLength[j]);
						IF levels[i].groupLength[j] > 0 THEN INC(levels[i].nofGroups) END;
					END;
					j := 0;
				END
			END;

			(* calc subsystem start pos*)
			ssStartPos[0] := 0;
			FOR i := 1 TO 31 DO
				ssStartPos[i] := ssStartPos[i - 1] + ms[i - 1];
			END;

			maxW := 40;

			(* allocate slots *)
			FOR i := 0 TO LEN(levels) - 1 DO
				levels[i].yAdvance := 1;
				IF levels[i].n < maxW THEN
					FOR j := 0 TO levels[i].nofGroups -1 DO levels[i].groupSlots[j] := levels[i].groupCounts[j] END;
				ELSE
					totSlots := 0;
					FOR j := 0 TO levels[i].nofGroups -1 DO
						levels[i].groupSlots[j] := Strings.Max(1, levels[i].groupCounts[j] * (maxW DIV 2 (* spare space for leveling out *))  DIV levels[i].n);
						INC(totSlots, levels[i].groupSlots[j])
					END;
					(* level out *)
					FOR k := 0 TO maxW - totSlots - 1 DO
						(* find worst group *)
						maxProb := -1;
						FOR j := 0 TO levels[i].nofGroups -1 DO
							IF levels[i].groupCounts[j] DIV levels[i].groupSlots[j] > maxProb THEN
								maxProbGroup := j; maxProb := levels[i].groupCounts[j] DIV levels[i].groupSlots[j];
							END
						END;
						(* increase slot *)
						INC(levels[i].groupSlots[maxProbGroup])
					END;
					(* calc yAdvance *)
					FOR j := 0 TO levels[i].nofGroups -1 DO
						levels[i].yAdvance := Strings.Max(levels[i].yAdvance, levels[i].groupCounts[j] DIV levels[i].groupSlots[j] + 1);
					END;

				END
			END;

			y := 1;
			FOR i := 0 TO LEN(levels) - 1 DO
				IF levels[i].n < maxW THEN sp := (maxW - levels[i].n) DIV 2 ELSE sp := 0 END;
				IF levels[i].m # NIL THEN
					g := 0; lastG := levels[i].m[0].group; gc := 0;
					FOR j := 0 TO levels[i].n - 1 DO
						m := levels[i].m[j];

						IF m.group # lastG THEN
							sp := sp + levels[i].groupSlots[g];
							INC(g); lastG := m.group; gc := 0
						END;

						NEW(mb);
						mb.color := subSystems.GetColor(m.subgroup);
						mb.aabb.l := (sp + gc MOD levels[i].groupSlots[g])* (BoxW + HSpace) ; mb.aabb.r := mb.aabb.l + BoxW;
						mb.aabb.t := (y + gc DIV levels[i].groupSlots[g]) * (BoxH + VSpace); mb.aabb.b := mb.aabb.t + BoxH;
						mb.rellayerpos := (VSpace - 5) - (j / levels[i].n) * (VSpace / 2);
						range.l := Strings.Min(range.l, ENTIER(mb.aabb.l));
						range.t:= Strings.Min(range.t, ENTIER(mb.aabb.t));
						range.r := Strings.Max(range.r, ENTIER(mb.aabb.r));
						range.b := Strings.Max(range.b, ENTIER(mb.aabb.b));
						IF m.file # NIL THEN COPY(m.file^, mb.name);
						ELSE COPY(m.name, mb.name);
						END;
						m.reference := mb;
						mb.m := m;
						Strings.Append(mb.info, "Imports: ");
						Strings.IntToStr(m.nofTotalImports, s); Strings.Append(mb.info, s); Strings.Append(mb.info, "/");
						Strings.IntToStr(m.nofDirectImports, s); Strings.Append(mb.info,s);
						Strings.IntToStr(m.linesOfCode, s); Strings.Append(mb.info, " LOC: "); Strings.Append(mb.info, s);
						viewer.Acquire;
						viewer.g.Add(mb);
						viewer.Release;
						INC(gc)
					END;
					INC(y, levels[i].yAdvance);
					NEW(r); r.aabb.l := 0; r.aabb.r := maxW * (BoxW + HSpace);
							r.aabb.t := y * (BoxH + HSpace) - HSpace DIV 2;
							r.aabb.b := y * (BoxH + HSpace) - HSpace DIV 2;

					viewer.Acquire;
					viewer.g.Add(r);
					viewer.Release;
				END
			END;

			NEW(t);
			t.aabb.l := (range.l + range.r) DIV 2 - 50;
			t.aabb.t := range.t;
			t.title := "A2 Release Modules";
			viewer.Acquire;
			viewer.g.Add(t);
			viewer.Release;

			(* links *)

				(*	NEW(sl);
					viewer.Acquire;
					viewer.g.Add(sl);
					m := ml.GetModule("PET");
					m1 := ml.GetModule("AosFS");
					sl.SetFromTo(m.reference(ModuleBox), m1.reference(ModuleBox));
					viewer.Release;  *)

	(*		count := 0;
			FOR i := 0 TO ml.nofModules - 1 DO
				m := ml.modules[i];
				IF m.reference # NIL THEN
					imp := m.imports;
					WHILE imp # NIL DO
						IF imp.m.reference # NIL THEN
							NEW(sl);
							viewer.Acquire;
							viewer.g.Add(sl);
							INC(count);
							sl.SetFromTo(m.reference(ModuleBox), imp.m.reference(ModuleBox));
							viewer.Release;
						END;
						imp := imp.next
					END
				END
			END;
			KernelLog.String("count = "); KernelLog.Int(count, 0); KernelLog.Ln;  *)
			hScroll.min.Set(range.l);
			vScroll.min.Set(range.t);
			hScroll.max.Set(range.r);
			vScroll.max.Set(range.b);
			viewer.Invalidate
		END Populate;

		PROCEDURE Close;
		BEGIN
			DecCount;
			Close^;
		END Close;

		PROCEDURE Handle(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

PROCEDURE CountLines(text : Texts.Text) : LONGINT;
VAR reader : Texts.TextReader; char32 : Texts.Char32; nofLines : LONGINT;
BEGIN
	ASSERT(text # NIL);
	NEW(reader, text);
	text.AcquireRead;
	nofLines := 1;
	REPEAT
		reader.ReadCh(char32);
		IF (char32 = Texts.NewLineChar) THEN INC(nofLines); END;
	UNTIL reader.eot;
	text.ReleaseRead;
	RETURN nofLines;
END CountLines;

PROCEDURE Open*(context : Commands.Context); (** [Options] [filemask] ~ *)
VAR options : Options.Options; filemask : Files.FileName; moduleList : ModuleList; window : Window;
BEGIN
	NEW(options);
	options.Add("t", "trace", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		filemask := "";
		IF ~context.arg.GetString(filemask) THEN COPY("*.Mod", filemask); END;
		NEW(moduleList);
		moduleList.ScanForModules(filemask, context.out);
		NEW(window, moduleList);
		IF options.GetFlag("trace") THEN
			moduleList.Dump(TRUE);
		END;
	END;
END Open;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup)
END ReleaseVisualizer.

SystemTools.Free ReleaseVisualizer ~

ReleaseVisualizerScan ~

ReleaseVisualizer.Open ~

ReleaseVisualizer.Open ../TestA2/*.Mod ~

ReleaseVisualizer.Open --trace ../TestA2/*.Mod ~