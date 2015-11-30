 (** AUTHOR "BohdanT"; PURPOSE "Just for fun"; based on http://js1k.com/2010-xmas/demo/856*)
MODULE WMXmas;

IMPORT
	Modules, WMComponents, WM := WMWindowManager, WMMessages, WMStandardComponents,
	Strings,WMRectangles, WMGraphics, Raster,M:=Math,Random, KernelLog, Kernel, WMWindowManager;

CONST
	Trace = FALSE;
	size = 32; W=446;U=16;
sc = (*sincos table for draw circle*)
[[1.00000000,0.00000000],
[0.99518473,0.09801714],
[0.98078528,0.19509033],
[0.95694034,0.29028468],
[0.92387953,0.38268344],
[0.88192125,0.47139676],
[0.83146961,0.55557023],
[0.77301043,0.63439332]];

TYPE
	Elem = ARRAY 4 OF REAL;
	
	XTree*=OBJECT(WMStandardComponents.Panel)
	VAR
		alive : BOOLEAN;
			timer : Kernel.Timer;
			c:WMGraphics.BufferCanvas;
			sprites:ARRAY 14 OF  Raster.Image;
			J:ARRAY 4279 OF Elem;
			count:LONGINT;
			A,D:REAL;
			RND:Random.Generator;
			  fnt:WMGraphics.Font;

	PROCEDURE &Init*;
	BEGIN
		Init^;
		fnt := WMGraphics.GetFont("Vera", 40, {0});
		alive:=TRUE;
		NEW(RND);RND.InitSeed(Kernel.GetTicks());
		NEW(timer);
		CreateSprites();
		CreateArray();
	END Init;
	PROCEDURE CreateBall*(size:LONGINT;VAR image: Raster.Image;f:LONGINT);
	VAR i,r,I : LONGINT;
		p : ARRAY 64 OF WMGraphics.Point2d;
		X,Y,x,y:REAL;
		color:LONGINT;
		c:WMGraphics.BufferCanvas;
	BEGIN
		NEW(image);
		Raster.Create(image, size, size, Raster.BGRA8888);
		NEW(c,image);
		c.Fill(WMRectangles.MakeRect(0, 0, size, size),0,WMGraphics.ModeCopy);
		I:=96;
		FOR r:=0 TO 7  DO
		X:=U-r/3;Y:=24-r/2;
(*			IF f=0 THEN 
				color:=WMGraphics.RGBAToColor(205,205,215,38H);
			ELSIF f=1 THEN
				color:=WMGraphics.RGBAToColor((147+I),128+I,I,80H)
			ELSE 
				color:=WMGraphics.RGBAToColor((147+I),0,I,80H);
			END;*)
			IF f=0 THEN 
				color:=WMGraphics.RGBAToColor(205,215,205,38H);
			ELSIF f=1 THEN
				color:=WMGraphics.RGBAToColor((147+I),I,128+I,80H)
			ELSE 
				color:=WMGraphics.RGBAToColor((147+I),0,I,80H);
			END;
			I:=r*U;
			
			FOR i := 0 TO 8-1 DO 
				IF f=0 THEN
					x := (4-(r)/2) *sc[i,0];y := (4-(r)/2) * sc[i,1];
				ELSE
					x := (8-r) *sc[i,0];y := (8-r) * sc[i,1];
				END;
				p[00+i].x := ENTIER(X + x+0.5);p[00+i].y := ENTIER(Y + y+0.5);
				p[15-i].x := ENTIER(X +y+0.5 );p[15-i].y := ENTIER(Y +x+0.5 );
				p[16+i].x := ENTIER(X -y+0.5 );p[16+i].y := ENTIER(Y +x+0.5 );
				p[31-i].x := ENTIER(X - x+0.5);p[31-i].y := ENTIER(Y +y +0.5);
		(**************)
				p[32+i].x := ENTIER(X - x+0.5);p[32+i].y := ENTIER(Y - y+0.5);
				p[47-i].x := ENTIER(X -y+0.5) ;p[47-i].y := ENTIER(Y - x+0.5);
				p[i+48].x := ENTIER(X +y+0.5) ;p[i+48].y := ENTIER(Y -x+0.5) ;
				p[63-i].x := ENTIER(X +x+0.5) ;p[63-i].y := ENTIER(Y -y+0.5 );
			END;
			c.FillPolygonFlat(p, 64, color, WMGraphics.ModeCopy);
		END;
	END CreateBall;

	PROCEDURE CreateSprites;
	VAR
		i,k:INTEGER;
		x,y,D,B,L:REAL;
		R:LONGINT;
	BEGIN
		FOR k:=0 TO 10 DO 
			NEW(sprites[k]);
			Raster.Create(sprites[k], size, size, Raster.BGRA8888);
			NEW(c,sprites[k]);
			c.Fill(WMRectangles.MakeRect(0, 0, size, size),0,WMGraphics.ModeCopy);
			i:=0;
			WHILE i<400 DO
				INC(i);
				x:=M.sin(i);
				y:=RND.Dice(360)/180-1;
				D:=x*x+y*y;
				B:=M.sqrt(D-x/0.9-1.5*y+1);
				L:=k/9;
				R:=ENTIER(67*(B+1)*(L+0.8)) DIV 2;
				IF D<1 THEN
  					c.Line(ENTIER(U+x*8),ENTIER(U+y*8),ENTIER(U+x*U),ENTIER(U+y*U),WMGraphics.RGBAToColor(R,ENTIER(R+B*L),40,25),WMGraphics.ModeSrcOverDst);
				END;
			END
		END;
		CreateBall(32,sprites[11],1);
		CreateBall(32,sprites[12],2);
		CreateBall(32,sprites[13],0);

	END CreateSprites;

	PROCEDURE CreateArray;
	VAR
	k:LONGINT;
	R,i:LONGINT;
	H,P,x,y,z,jj:REAL;
	rando:REAL;
	BEGIN
		k:=0;count:=0;
		WHILE(k<200)DO
			x:=0;z:=0;i:=0;jj:=0;
			H:=k+M.sqrt(k)*25;
			y:=H;
			R:=RND.Dice(W);
			WHILE(jj<H)DO
				P:=3;
				x:=x+M.sin(R)*P+RND.Dice(6)-3;
				z:=z+M.sin(R-11)*P+RND.Dice(6)-3;
				y:=y+RND.Dice(U)-8;
				IF ((jj+U)>H) & (RND.Dice(1000)>800) THEN
					J[count,0]:=x;
					J[count,1]:=y;
					J[count,2]:=z;
					rando:=RND.Dice(400)/100;
					J[count,3]:=ENTIER((jj/H*20+rando)/2);
				ELSE
					J[count,0]:=x;
					J[count,1]:=y;
					J[count,2]:=z;
					J[count,3]:=ENTIER((jj/H*20)/2);
				END;
				INC(count);
				jj:=jj+U;
			END;
			INC(k);
		END;
		IF Trace THEN KernelLog.String("CreateArray= "); KernelLog.Int(count, 0); KernelLog.Ln; END;
	END CreateArray;

		PROCEDURE GetOberon*; END GetOberon;
		
		PROCEDURE comp(CONST m, l: Elem): BOOLEAN;
		VAR
		 tmp:REAL;
		BEGIN
			tmp:=(m[2]-l[2])*A+(l[0]-m[0])*M.sin(D);
			RETURN tmp>0;
		END comp;
		PROCEDURE QuickSort(lo, hi: LONGINT);

		VAR i, j: LONGINT; x, t: Elem;
		BEGIN
(*		KernelLog.String("QuickSort lo= "); KernelLog.Int(lo, 0); 
		KernelLog.String(" hi= "); KernelLog.Int(hi, 0); KernelLog.Ln;*)
			i := lo; j := hi;
			x := J[(lo+hi) DIV 2];
			
			WHILE (i <= j) DO
				WHILE (comp(J[i], x)) DO INC(i) END;
				WHILE (comp(x, J[j])) DO DEC(j) END;
				IF (i <= j) THEN
					t := J[i]; J[i] := J[j]; J[j] := t;
					INC(i); DEC(j)
				END
			END;
			
			IF (lo < j) THEN QuickSort(lo, j) END;
			IF (i < hi) THEN QuickSort(i, hi) END
		END QuickSort;



		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		VAR
			i:LONGINT;
			L:Elem;
		BEGIN
			DrawBackground^(canvas);
			canvas.SetColor(WMGraphics.Green);
(*			FOR i:=0 TO 9 DO
				canvas.DrawImage(i*32,20,sprites[i],WMGraphics.ModeSrcOverDst);
			END;*)
			
			c.Fill(GetClientRect(),0,WMGraphics.ModeCopy);
			SetFont(fnt);

			A:=M.sin(D-11);
			QuickSort(0, count-1);
			i:=0;
(*			KernelLog.String("di= "); KernelLog.Int(count, 0); KernelLog.Ln;*)
			WHILE(i<count) DO
				L:=J[i];
				canvas.DrawImage(ENTIER(207+L[0]*A+L[2]*M.sin(D)),ENTIER(L[1]/2),sprites[ENTIER(L[3]+1)],WMGraphics.ModeSrcOverDst);
				INC(i);
				IF i MOD 7=0 THEN
					canvas.DrawImage(
					
					ENTIER( 157*i*i+M.sin(D*5+i*i)*5) MOD 460,
					ENTIER(113*i+(D*i)/60) MOD ENTIER(290+i/99),
					sprites[13],WMGraphics.ModeSrcOverDst);
				END;
			END;
(*			canvas.DrawString(U,W-U,"Happy New Year!!!");*)

			D:=D+3.14/360;
		END DrawBackground;

		PROCEDURE Finalize*; (** PROTECTED *)
		BEGIN
			timer.Wakeup; BEGIN {EXCLUSIVE} alive := FALSE END; Finalize^
		END Finalize;


	BEGIN {ACTIVE}
		WHILE alive DO timer.Sleep(10); Invalidate; END;
	END XTree;
	
	Window* = OBJECT (WMComponents.FormWindow)
	VAR
		xTree:XTree;
		dragging, resizing : BOOLEAN;
		lastX, lastY : LONGINT;

		PROCEDURE CreateForm () : WMComponents.VisualComponent;
		VAR panel : WMStandardComponents.Panel;
		BEGIN
			NEW (panel); panel.bounds.SetExtents (W, W-2*U); (*panel.fillColor.Set (0FFFFFFFFH);*)

			NEW(xTree);
			xTree.bounds.SetWidth(W);
			xTree.bounds.SetHeight(W);

			 panel.AddContent(xTree);
			 
			RETURN panel
		END CreateForm;

		PROCEDURE &New;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			IncCount;	(* A *)
			vc := CreateForm ();
			Init (vc.bounds.GetWidth (), vc.bounds.GetHeight (), FALSE);
			SetContent (vc);
			useAlpha := TRUE;

			manager := WMWindowManager.GetDefaultManager();
			manager.Add(100, 100 , SELF, {WMWindowManager.FlagHidden, WMWindowManager.FlagStayOnTop,WM.FlagNoFocus});

(*			WM.DefaultAddWindow (SELF);*)
			SetTitle (Strings.NewString ("Happy New Year!!!"));
		END New;

		PROCEDURE Close*;
		BEGIN
			Close^;
			DecCount		(* B *)
		END Close;

		PROCEDURE PointerDown(x, y:LONGINT; keys:SET);
		BEGIN
			lastX := bounds.l + x; lastY:=bounds.t + y;
			IF keys = {0} THEN
				dragging := TRUE
			END;
		END PointerDown;

		PROCEDURE PointerMove(x,y:LONGINT; keys:SET);
		VAR dx, dy, width, height : LONGINT;
		BEGIN
			IF dragging THEN
				x := bounds.l + x; y := bounds.t + y; dx := x - lastX; dy := y - lastY;
				lastX := lastX + dx; lastY := lastY + dy;
				IF (dx # 0) OR (dy # 0) THEN
						manager.SetWindowPos(SELF, bounds.l + dx, bounds.t + dy);
				END;
			END;
		END PointerMove;

		PROCEDURE PointerUp(x, y:LONGINT; keys:SET);
		BEGIN
			dragging := FALSE;
		END PointerUp;



		PROCEDURE Handle*(VAR x: WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN xTree.Finalize; Close
			ELSE Handle^ (x)
			END
		END Handle;			

	END Window;

	KillerMsg = OBJECT	(* D *)
	END KillerMsg; 	

VAR
	nofWindows : LONGINT;

(** Standard multiple windows controlled by number, non-restorable. *)
PROCEDURE Open* ;
VAR winstance : Window;
BEGIN
	NEW (winstance);
END Open;

PROCEDURE IncCount;	(* E *)
BEGIN {EXCLUSIVE}
	INC (nofWindows);
END IncCount;		

PROCEDURE DecCount;	(* F *)
BEGIN {EXCLUSIVE}
	DEC (nofWindows);
END DecCount;	

PROCEDURE Cleanup;	(* G *)
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW (die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager ();
	m.Broadcast (msg);
	AWAIT (nofWindows = 0)
END Cleanup;

BEGIN
	Modules.InstallTermHandler (Cleanup);

	(* Additional BEGIN processing. *)
END WMXmas.

WMXmas.Open ~
SystemTools.Free WMXmas ~
WMDebugger.Open WMXmas.Mod~


