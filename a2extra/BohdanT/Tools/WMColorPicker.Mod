MODULE WMColorPicker; (** AUTHOR "BohdanT"; PURPOSE "Powerful color picker dialog"; December 14-17, 2014 *)

IMPORT
	KernelLog, Strings, Math, Texts, UTF8Strings,
	(* visual part *)

	WMRectangles, WMWindowManager, WMProperties,  WMComponents, WMStandardComponents, WMEditors, 
	WMGraphics, WMGraphicUtilities, WMEvents, 
	WM := WMWindowManager, WMDialogs, WMColorComponents;

CONST
	stRed* = 0; stGreen*= 1; stBlue* = 2; stHue* = 3; stSat* = 4; stLum* = 5; 
	Cap = "RGBHSLLab";

	K1d3		= 0.333333333333333; (*1/3*)
	K16d116	= 0.137931034482759; (*16/116*)
	K1d2p4		= 0.416666666666667; (*1/2.4*)

	CustomCount	=	24;
	
StdPalette = 
[[0FF8080FFH, 0FFFF80FFH, 080FF80FFH, 000FF80FFH, 080FFFFFFH, 00080FFFFH, 0FF80C0FFH, 0FF80FFFFH],
 [0FF0000FFH, 0FFFF00FFH, 080FF00FFH, 000FF40FFH, 000FFFFFFH, 00080C0FFH, 08080C0FFH, 0FF00FFFFH],
 [0804080FFH, 0FF8040FFH, 000FF00FFH, 0008080FFH, 0004080FFH, 08080FFFFH, 0800040FFH, 0FF0080FFH],
 [0800000FFH, 0FF8000FFH, 0008000FFH, 0008040FFH, 00000FFFFH, 00000A0FFH, 0800080FFH, 08000FFFFH],
 [0400000FFH, 0804000FFH, 0004000FFH, 0004040FFH, 0000080FFH, 0000040FFH, 0400040FFH, 0400080FFH],
 [0000000FFH, 0808000FFH, 0808040FFH, 0808080FFH, 0408080FFH, 0C0C0C0FFH, 0400040FFH, 0FFFFFFFFH]];
TYPE
	
	TextField = OBJECT(WMEditors.TextField)
	VAR
		owner : PickColorDlg;
		(*This is need for update of type spector & gradient when select text editor*)
		(* *)
		PROCEDURE FocusReceived*; 
		VAR
			i : LONGINT;
		BEGIN
			FOR i:=0 TO 8 DO (*find selected editor*)
				IF SELF=owner.editorial[i] THEN ActiveGrad:=i END;
			END;
			owner.spec.UpdateCur;
			owner.grad.UpdateCur;
			owner.spec.Invalidate;			
			owner.grad.Invalidate;			
			FocusReceived^;
		END FocusReceived;
	END TextField;
	
	ColorInd* = OBJECT(WMColorComponents.ColorPot)
	VAR
(*		color-: WMProperties.ColorProperty;*)
		updatePanels, updateEditors:BOOLEAN;(*!Stupid*)
		owner:PickColorDlg;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			updateEditors:=TRUE;
			updatePanels:=TRUE;
			SetNameAsString(Strings.NewString("ColorInd"));
			fillColor.Set(LONGINT(0008080FFH));
(*			SetExternalColorChangeHandler(ColorChanged);*)
		END Init;

		PROCEDURE PropertyChanged*(sender, data : ANY);
		VAR
			tempString : ARRAY 256 OF CHAR;
			c, R, G, B : LONGINT;
			H, S, L : REAL;
			LL, a, b : REAL;
		BEGIN
			Invalidate;
			PropertyChanged^(sender, data);

			IF (owner.coledit#NIL) THEN 
				c:=fillColor.Get();
				Strings.IntToHexStr(c, 8, tempString);

				owner.coledit.SetAsString(tempString);
				IF (updatePanels) THEN
					owner.grad.UpdateCur;
					owner.spec.UpdateCur;
					owner.spec.Invalidate;			
					owner.grad.Invalidate;			
				END;
				IF updateEditors THEN
					ColorToRGB(c,R,G,B);
					Strings.IntToStr(R, tempString);owner.editorial[0].SetAsString(tempString);
					Strings.IntToStr(G, tempString);owner.editorial[1].SetAsString(tempString);
					Strings.IntToStr(B, tempString);owner.editorial[2].SetAsString(tempString);
					ColorToHSL(c, H, S, L);
					Strings.IntToStr(ENTIER(H*360+0.5), tempString);owner.editorial[3].SetAsString(tempString);
					Strings.IntToStr(ENTIER(S*100+0.5), tempString); owner.editorial[4].SetAsString(tempString);
					Strings.IntToStr(ENTIER(L*100+0.5), tempString); owner.editorial[5].SetAsString(tempString);
					ColorToLab(c, LL, a, b);
					Strings.IntToStr(ENTIER(LL), tempString);owner.editorial[6].SetAsString(tempString);
					Strings.IntToStr(ENTIER(a), tempString); owner.editorial[7].SetAsString(tempString);
					Strings.IntToStr(ENTIER(b), tempString); owner.editorial[8].SetAsString(tempString);
				END;
			END;
		END PropertyChanged;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR mode : LONGINT;
			 rect : WMGraphics.Rectangle; 
		BEGIN
			rect := GetClientRect();
			DrawBackground^(canvas);
			DrawBevel(canvas, rect, TRUE,  mode);			
		END DrawBackground;
	END ColorInd;


	ColorBut = OBJECT(WMColorComponents.ColorPot)
	VAR
		onSelect- : WMEvents.EventSource;
		
		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("ColorBut"));
			NEW(onSelect, SELF, Strings.NewString("onSelect"), NIL, NIL); events.Add(onSelect);
		END Init;
		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR mode, mid, borderWidth : LONGINT;
			 rect : WMGraphics.Rectangle; 
		BEGIN
			IF ~visible.Get() THEN RETURN END;
			Acquire;
			mid := fillColor.Get();

			rect := GetClientRect();
			mode := WMGraphics.ModeSrcOverDst;
			borderWidth := 1;
			IF mid # 0 THEN canvas.Fill(WMRectangles.ResizeRect(rect,-3), mid, mode) END;
			DrawBevel(canvas, rect, TRUE,  mode);
			IF SELF=selected THEN
				WMGraphicUtilities.DrawRect(canvas, rect, LONGINT(0FF000080H), mode);
			END;

			Release
		END DrawBackground;
		PROCEDURE PointerDown(x, y: LONGINT; keys : SET); (** PROTECTED *)
		VAR
			o:ColorBut;
		BEGIN
			IF selected=SELF THEN RETURN END;
			o:=selected;
			selected:=SELF;
			IF o#NIL THEN o.Invalidate(); END;

			onSelect.Call(NIL);

			Invalidate();
			PointerDown^(x, y, keys);
		END PointerDown;

		PROCEDURE DragDropped(x, y : LONGINT; dragInfo : WMWindowManager.DragInfo);
		BEGIN
			ConfirmDrag(FALSE, NIL);
		END DragDropped;



	END ColorBut;
VAR
	selected:ColorBut;
	manager : WMWindowManager.WindowManager;

TYPE
	Gradient* = OBJECT(WMStandardComponents.Panel)
	VAR
		gRect : WMRectangles.Rectangle;
		gw, gh : LONGINT;
		position- : LONGINT;
		down : BOOLEAN;
		posX-, posY-:LONGINT;
		spec:Spectrum;
		owner : PickColorDlg;
		
		PROCEDURE SetPosition*(val:LONGINT);

		BEGIN
			position:=255-val;

				owner.colorInd.updatePanels:=FALSE;
				
				 CASE ActiveGrad OF
					 |0:owner.colorInd.fillColor.Set( RGBToColor( position, spec.CurY, spec.CurX));
					 |1:owner.colorInd.fillColor.Set( RGBToColor( spec.CurY, position, spec.CurX));
					 |2:owner.colorInd.fillColor.Set( RGBToColor( spec.CurY, spec.CurX, position));

					 |3:owner.colorInd.fillColor.Set( HSLToColor( position/255, spec.CurX/255, spec.CurY/255));
					 |4:owner.colorInd.fillColor.Set( HSLToColor( spec.CurX/255, position/255, spec.CurY/255));
					 |5:owner.colorInd.fillColor.Set( HSLToColor( spec.CurX/255, spec.CurY/255, position/255));
					 
					 |6:owner.colorInd.fillColor.Set( LabToColor( position * 100/255,   spec.CurX - 127, spec.CurY - 127));
		 			 |7:owner.colorInd.fillColor.Set( LabToColor( spec.CurY * 100/255, position - 127, spec.CurX - 127));
					 |8:owner.colorInd.fillColor.Set( LabToColor( spec.CurY * 100/255, spec.CurX - 127, position - 127));
				 ELSE
				 END;
				owner.colorInd.updatePanels:=TRUE;
 				owner.spec.Invalidate();

			Invalidate();
		END SetPosition;

		PROCEDURE UpdateCur;
		VAR
			c:LONGINT;
			R, G, B : LONGINT;
			H, S, L : REAL;
			LL, a, b :REAL;
		BEGIN
			c:=owner.colorInd.fillColor.Get();

			ColorToRGB(c, R, G, B);
			ColorToHSL(c, H, S, L);
			ColorToLab(c, LL, a, b);
			
				 CASE ActiveGrad OF
					 |0:position:=R;
					 |1:position:=G;
					 |2:position:=B;
					 |3:position:=ENTIER(H*255);
					 |4:position:=ENTIER(S*250);
					 |5:position:=ENTIER(L*250);
					 |6:position:=ENTIER(LL*255/100);
		 			 |7:position:=ENTIER(a+127);
					 |8:position:=ENTIER(b+127);
				ELSE
				END;
		END UpdateCur;


		PROCEDURE PointerDown(x, y: LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			down:=TRUE;
			SetPosition((MIN(MAX(y,gRect.t),gRect.b)-gRect.t)*255 DIV gh);
			PointerDown^(x, y, keys)
		END PointerDown;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET); (** PROTECTED *)

		BEGIN
			IF down THEN
				SetPosition((MIN(MAX(y,gRect.t),gRect.b)-gRect.t)*255 DIV gh);
			END;
			PointerMove^(x, y, keys)
		END PointerMove;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			down:=FALSE;
			PointerUp^(x, y, keys)
		END PointerUp;

		
		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("Gradient"));
		END Init;

		PROCEDURE DrawGradientS(canvas : WMGraphics.Canvas; H, L: REAL);
		VAR
			y : LONGINT;
			S : REAL;
		BEGIN
			FOR y := 0 TO gh DO
				S := (gh-y) / gh;
				canvas.Line(0, y, gw, y, HSLToColor(H,S,L),WMGraphics.ModeCopy)
			END;
		END DrawGradientS;

		PROCEDURE DrawGradientH(canvas : WMGraphics.Canvas; S, L: REAL);
		VAR
			y : LONGINT;
			H : REAL;
		BEGIN
			FOR y := 0 TO gh DO
				H := (gh-y) / gh;
				canvas.Line(0, y, gw, y, HSLToColor(H,S,L),WMGraphics.ModeCopy)
			END;
		END DrawGradientH;

		PROCEDURE DrawGradientL(canvas : WMGraphics.Canvas; S, H: REAL);
		VAR
			y : LONGINT;
			L : REAL;
			color : LONGINT;
		BEGIN
			FOR y := 0 TO gh DO
				L := (gh-y) / gh ;
				color := HSLToColor(H,S,L);
				canvas.Line(0, y, gw, y, color,WMGraphics.ModeCopy)
			END;
		END DrawGradientL;

		PROCEDURE DrawGradientR(canvas : WMGraphics.Canvas; G, B :LONGINT);
		VAR
			y : LONGINT;
			R : LONGINT;
		BEGIN
			FOR y := 0 TO gh DO
				R := ((gh-y) * 255) DIV gh;
				canvas.Line(0, y, gw, y, RGBToColor(R, G, B),WMGraphics.ModeCopy)
			END;
		END DrawGradientR;

		PROCEDURE	DrawGradientG(canvas : WMGraphics.Canvas; R, B :LONGINT);
		VAR
			y : LONGINT;
			G : LONGINT;
		BEGIN
			FOR y := 0 TO gh DO
				G := ((gh-y) * 255) DIV gh;
				canvas.Line(0, y, gw, y, RGBToColor(R, G, B),WMGraphics.ModeCopy)
			END;
		END DrawGradientG;

		PROCEDURE	DrawGradientB(canvas : WMGraphics.Canvas; R, G :LONGINT);
		VAR
			y : LONGINT;
			B : LONGINT;
		BEGIN
			FOR y := 0 TO gh DO
				B := ((gh-y) * 255) DIV gh;
				canvas.Line(0, y, gw, y, RGBToColor(R, G, B),WMGraphics.ModeCopy)
			END;
		END DrawGradientB;

		PROCEDURE	DrawGradientLL(canvas : WMGraphics.Canvas; a, b :REAL);
		VAR
			y : LONGINT;
			LL : REAL;
		BEGIN
			FOR y := 0 TO gh DO
				LL := ((gh-y) * 100) / gh;
				canvas.Line(0, y, gw, y, LabToColor(LL, a, b),WMGraphics.ModeCopy)
			END;
		END DrawGradientLL;
		PROCEDURE	DrawGradienta(canvas : WMGraphics.Canvas; L, b :REAL);
		VAR
			y : LONGINT;
			a : REAL;
		BEGIN
			FOR y := 0 TO gh DO
				a := ((gh-y) * 255) / gh - 127;
				canvas.Line(0, y, gw, y, LabToColor(L, a, b),WMGraphics.ModeCopy)
			END;
		END DrawGradienta;
		PROCEDURE	DrawGradientb(canvas : WMGraphics.Canvas; L, a :REAL);
		VAR
			y : LONGINT;
			b : REAL;
		BEGIN
			FOR y := 0 TO gh DO
				b := ((gh-y) * 255) / gh -127;
				canvas.Line(0, y, gw, y, LabToColor(L, a, b),WMGraphics.ModeCopy)
			END;
		END DrawGradientb;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			mode : LONGINT;
			y : LONGINT;
			r : WMGraphics.Rectangle;
			canvasState : WMGraphics.CanvasState;
		BEGIN
			gRect := GetClientRect();
			INC(gRect.l,imgArrR.width);
			DEC(gRect.r,imgArrL.width);
			IF gRect.r<gRect.l THEN gRect.r:=gRect.l+1 END;
			mode := WMGraphics.ModeSrcOverDst;
			DrawBevel(canvas, gRect, TRUE,  mode);			
			gRect:=WMRectangles.ResizeRect(gRect,-3);
			gw:=gRect.r-gRect.l;
			gh:=gRect.b-gRect.t;
			canvas.SaveState(canvasState);
			r := bounds.Get();
			canvas.SetClipRect(gRect);
			canvas.ClipRectAsNewLimits(gRect.l, gRect.t);
			 canvas.SetClipMode({WMGraphics.ClipRect});
			 CASE ActiveGrad OF
				 |0:DrawGradientR(canvas, spec.CurY, spec.CurX);
				 |1:DrawGradientG(canvas, spec.CurY, spec.CurX);
				 |2:DrawGradientB(canvas, spec.CurY, spec.CurX);
				 |3:DrawGradientH(canvas, spec.CurX/255, spec.CurY/255);
				 |4:DrawGradientS(canvas, spec.CurX/255, spec.CurY/255);
				 |5:DrawGradientL(canvas, spec.CurY/255, spec.CurX/255);
				 |6:DrawGradientLL(canvas, spec.CurX-127, spec.CurY-127);
	 			 |7:DrawGradienta(canvas, spec.CurY*100/255, spec.CurX-127);
				 |8:DrawGradientb(canvas, spec.CurY*100/255, spec.CurX-127);
			 ELSE
			 END;

			canvas.RestoreState(canvasState);

			y:=(255-position)*gh DIV 255;
			canvas.DrawImage(0,gRect.t+y-imgArrR.height DIV 2,imgArrR, mode);
			canvas.DrawImage(bounds.GetWidth()-imgArrL.width,gRect.t+y-imgArrL.height DIV 2,imgArrL, mode);
			
		END DrawBackground;
		
	END Gradient;


	Spectrum* = OBJECT(WMStandardComponents.Panel)
	VAR
		down:BOOLEAN;
		pointer:WM.PointerInfo;
		CurX,CurY:LONGINT;
		gw,gh:LONGINT;
		gRect : WMRectangles.Rectangle;
		grad:Gradient;
		owner : PickColorDlg;

		PROCEDURE SetPosition(x,y:LONGINT);
		BEGIN
				CurX:= (MIN(MAX(x,gRect.l),gRect.r)-gRect.l)*255 DIV gw;
				CurY:= 255-(MIN(MAX(y,gRect.t),gRect.b)-gRect.t)*255 DIV gh;
				owner.colorInd.updatePanels:=FALSE;
				 CASE ActiveGrad OF
					 |0:owner.colorInd.fillColor.Set(RGBToColor( grad.position, CurY, CurX));
					 |1:owner.colorInd.fillColor.Set(RGBToColor( CurY, grad.position, CurX));
					 |2:owner.colorInd.fillColor.Set(RGBToColor( CurY, CurX, grad.position));
					 
					 |3:owner.colorInd.fillColor.Set(HSLToColor( grad.position/255, CurX/255, CurY/255));
					 |4:owner.colorInd.fillColor.Set(HSLToColor( CurX/255, grad.position/255, CurY/255));
					 |5:owner.colorInd.fillColor.Set(HSLToColor( CurX/255,CurY/255,  grad.position/255));
					 
					 |6:owner.colorInd.fillColor.Set(LabToColor(grad.position*100/255, CurX-127,CurY-127));
		 			 |7:owner.colorInd.fillColor.Set(LabToColor(CurY*100/255, grad.position-127,CurX-127));
					 |8:owner.colorInd.fillColor.Set(LabToColor(CurY*100/255,CurX-127, grad.position-127));
				 ELSE
				 END;
				owner.colorInd.updatePanels:=TRUE;

				owner.grad.Invalidate();
				Invalidate();
			
		END SetPosition;
		
		PROCEDURE PointerDown(x, y: LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			down:=TRUE;
			PointerDown^(x, y, keys);
			SetPosition(x, y);
		END PointerDown;

		PROCEDURE PointerMove(x, y : LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			SetPointerInfo(pointer);
			IF down THEN
				SetPosition(x, y);
			END;
			PointerMove^(x, y, keys);
		END PointerMove;

		PROCEDURE UpdateCur;
		VAR
			c:LONGINT;
			R, G, B : LONGINT;
			H, S, L : REAL;
			LL, a, b :REAL;
		BEGIN
			c:=owner.colorInd.fillColor.Get();
			ColorToRGB(c, R, G, B);
			ColorToHSL(c, H, S, L);
			ColorToLab(c, LL, a, b);
			
				 CASE ActiveGrad OF
					 |0:CurY:=G;CurX:=B;
					 |1:CurY:=R;CurX:=B;
					 |2:CurY:=R;CurX:=G;
					 |3:CurX:=ENTIER(S*255);CurY:=ENTIER(L*255);
					 |4:CurX:=ENTIER(H*255);CurY:=ENTIER(L*255);
					 |5:CurX:=ENTIER(H*255);CurY:=ENTIER(S*255);
					 |6:CurX:=ENTIER(a+127);CurY:=ENTIER(b+127);
		 			 |7:CurY:=ENTIER(LL*255/100);CurX:=ENTIER(b+127);
					 |8:CurY:=ENTIER(LL*255/100);CurX:=ENTIER(a+127);
				ELSE
				END;
		END UpdateCur;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET); (** PROTECTED *)
		BEGIN
			down:=FALSE;
			PointerUp^(x, y, keys)
		END PointerUp;

	
		PROCEDURE &Init;
		BEGIN
			Init^;
			NEW(pointer);
			pointer.hotX:=8;
			pointer.hotY:=8; 
			pointer.img:=imgMouse;
			SetNameAsString(Strings.NewString("Spectrum"));
			
		END Init;

		PROCEDURE DrawSpectrumSL(canvas : WMGraphics.Canvas; H: REAL);
		VAR
			x,y : LONGINT;
			S,L : REAL;
		BEGIN
			FOR y := 0 TO gh DO
				L := (gh-y) / gh;
				FOR x := 0 TO gw DO 
					S := x / gw ;
					canvas.SetPixel(x, y, HSLToColor(H,S,L),WMGraphics.ModeCopy)
				END;
			END;
		END DrawSpectrumSL;

		PROCEDURE DrawSpectrumHS(canvas : WMGraphics.Canvas; L: REAL);
		VAR
			x,y: LONGINT;
			H,S: REAL;
		BEGIN
			FOR y := 0 TO gh DO
				S := (gh-y) / gh;
				FOR x := 0 TO gw DO 
					H := x / gw;
					canvas.SetPixel(x, y, HSLToColor(H,S,L),WMGraphics.ModeCopy)
				END;
			END;
		END DrawSpectrumHS;

		PROCEDURE DrawSpectrumHL(canvas : WMGraphics.Canvas; S: REAL);
		VAR
			x, y: LONGINT;
			H,L: REAL;
		BEGIN
			FOR y := 0 TO gh DO
				L := (gh-y) / gh ;
				FOR x := 0 TO gw DO 
					H := x / gw;
					canvas.SetPixel(x, y, HSLToColor(H,S,L),WMGraphics.ModeCopy)
			 	END;
			END;
		END DrawSpectrumHL;

		PROCEDURE DrawSpectrumGB(canvas : WMGraphics.Canvas; R: LONGINT);
		VAR
			x,y: LONGINT;
			G,B: LONGINT;
		BEGIN
			FOR y := 0 TO gh DO
				G := ((gh-y) * 255) DIV gh;
				FOR x := 0 TO gw DO
					B := (x * 255) DIV gw;
					canvas.SetPixel(x, y, RGBToColor(R, G, B), WMGraphics.ModeCopy)
				END;
			END;
		END DrawSpectrumGB;

		PROCEDURE DrawSpectrumRB(canvas : WMGraphics.Canvas; G: LONGINT);
		VAR
			x,y: LONGINT;
			R,B: LONGINT;
		BEGIN
			FOR y := 0 TO gh DO
				R := ((gh-y) * 255) DIV gh;
				FOR x := 0 TO gw  DO
					B := (x * 255) DIV gw;
					canvas.SetPixel(x, y, RGBToColor(R, G, B), WMGraphics.ModeCopy)
				END;
			END;
		END DrawSpectrumRB;

		PROCEDURE	DrawSpectrumRG(canvas : WMGraphics.Canvas; B: LONGINT);
		VAR
			x,y: LONGINT;
			R,G: LONGINT;
		BEGIN
			FOR y := 0 TO gh DO
				R := ((gh-y) * 255) DIV gh;
				FOR x := 0 TO gw DO
					G := (x * 255) DIV gw ;
					canvas.SetPixel(x, y, RGBToColor(R, G, B), WMGraphics.ModeCopy)
				END;
			END;
		END DrawSpectrumRG;

		PROCEDURE	DrawSpectrumab(canvas : WMGraphics.Canvas; L: REAL);
		VAR
			x,y: LONGINT;
			a,b: REAL;
		BEGIN
			FOR y := 0 TO gh DO
				b := ((gh-y) * 255) / gh - 127;
				FOR x := 0 TO gw DO
					a := (x * 255) / gw - 127;
					canvas.SetPixel(x, y, LabToColor(L, a, b), WMGraphics.ModeCopy)
				END;
			END;
		END DrawSpectrumab;

		PROCEDURE	DrawSpectrumLb(canvas : WMGraphics.Canvas; a: REAL);
		VAR
			x,y: LONGINT;
			L,b: REAL;
		BEGIN
			FOR y := 0 TO gh DO
				L := ((gh-y) * 100) / gh;
				FOR x := 0 TO gw DO
					b := (x * 255) / gw -127;
					canvas.SetPixel(x, y, LabToColor(L, a, b), WMGraphics.ModeCopy)
				END;
			END;
		END DrawSpectrumLb;
		
		PROCEDURE	DrawSpectrumLa(canvas : WMGraphics.Canvas; b: REAL);
		VAR
			x,y: LONGINT;
			L,a: REAL;
		BEGIN
			FOR y := 0 TO gh DO
				L := ((gh-y) * 100) / gh;
				FOR x := 0 TO gw DO
					a := (x * 255) / gw -127;
					canvas.SetPixel(x, y, LabToColor(L, a, b), WMGraphics.ModeCopy)
				END;
			END;
		END DrawSpectrumLa;
		
		
		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			mode : LONGINT;
			r : WMGraphics.Rectangle;
			canvasState : WMGraphics.CanvasState;
		BEGIN
			gRect := GetClientRect();	mode := WMGraphics.ModeSrcOverDst;
			DrawBevel(canvas, gRect, TRUE,  mode);			
			gRect:=WMRectangles.ResizeRect(gRect,-3);
			gw:=gRect.r-gRect.l;
			gh:=gRect.b-gRect.t;
			canvas.SaveState(canvasState);
			r := bounds.Get();
			canvas.SetClipRect(gRect);
			canvas.ClipRectAsNewLimits(gRect.l, gRect.t);
			canvas.SetClipMode({WMGraphics.ClipRect});
			
			 CASE ActiveGrad OF
				 |0:DrawSpectrumGB(canvas, grad.position);
				 |1:DrawSpectrumRB(canvas, grad.position);
				 |2:DrawSpectrumRG(canvas, grad.position);
				 |3:DrawSpectrumSL(canvas, (grad.position/255));
				 |4:DrawSpectrumHL(canvas, (grad.position/255));
				 |5:DrawSpectrumHS(canvas, (grad.position/255));
				 |6:DrawSpectrumab(canvas, (grad.position*100/255));
	 			 |7:DrawSpectrumLb(canvas, (grad.position-127));
				 |8:DrawSpectrumLa(canvas, (grad.position-127));
			 ELSE
			 END;
			(*DrawSpectrumHS(canvas,0.50);*)
			canvas.DrawImage(CurX-(imgCursor.height) DIV 2-1,(255-CurY)-(imgCursor.height) DIV 2-1,imgCursor, WMGraphics.ModeSrcOverDst);
			canvas.RestoreState(canvasState);
		END DrawBackground;
		
	END Spectrum;

	PickColorDlg* = OBJECT (WMDialogs.Dialog)
		VAR
			colorInd-:ColorInd;
			spec:Spectrum;
			grad:Gradient;
			palette:ARRAY CustomCount OF ColorBut;
			palettei:LONGINT;
			coledit: WMEditors.TextField;
			editorial : ARRAY 9 OF WMEditors.TextField;

		PROCEDURE CreateForm() : WMComponents.VisualComponent;
		VAR
			panel : WMStandardComponents.Panel;
			button:WMStandardComponents.Button;
			lab : WMStandardComponents.Label;
			but: ColorBut;
			i,j:LONGINT;
			PROCEDURE AddLabEd(l,r,n:LONGINT);
			VAR
				s : ARRAY 3 OF CHAR;
				edit : TextField;
			BEGIN
				s:="X:";
				s[0]:=Cap[n];
				NEW(lab); lab.caption.SetAOC(s);lab.bounds.SetExtents(60, 20);
				lab.bounds.SetLeft(l);lab.bounds.SetTop(r);
				panel.AddContent(lab);
				NEW(edit);edit.owner:=SELF;
				 edit.SetAsString("0");edit.bounds.SetWidth(40);edit.alignment.Set(WMComponents.AlignRight);edit.fillColor.Set(LONGINT(0FFFFFFFFH));
				edit.onChanged.Add(UpdateColors);
				editorial[n]:=edit;
				lab.AddContent(edit);
			END AddLabEd;
			
		BEGIN
			NEW(panel);
			panel.bounds.SetExtents(536, 360);
			panel.fillColor.Set(LONGINT(0D4D0C8FFH));

			NEW(lab);lab.bounds.SetExtents(122, 19); lab.bounds.SetLeft(12);lab.bounds.SetTop(10);lab.caption.SetAOC("Basic colors:");
			panel.AddContent(lab);
			
			FOR i:=0 TO 5 DO
				FOR j:=0 TO 7 DO
					NEW(but);
					but.bounds.SetExtents(22, 19); but.bounds.SetLeft(j*25+12);but.bounds.SetTop(22*i+35);
					but.fillColor.Set(StdPalette[i,j]);
					but.onSelect.Add(SetColor);
					panel.AddContent(but);
				
				END;
			END;

			NEW(lab);lab.bounds.SetExtents(122, 19); lab.bounds.SetLeft(12);lab.bounds.SetTop(175);lab.caption.SetAOC("Custom colors:");
			panel.AddContent(lab);


			FOR i:=0 TO 2 DO
				FOR j:=0 TO 7 DO
					NEW(but);
					but.bounds.SetExtents(22, 19); but.bounds.SetLeft(j*25+12);but.bounds.SetTop(22*i+200);
					but.fillColor.Set(userPalette[i*8+j]);
					but.onSelect.Add(SetColor);
					panel.AddContent(but);
					palette[i*8+j]:=but;
				
				END;
			END;

			
			NEW(spec);spec.owner:=SELF;spec.bounds.SetExtents(256+6, 256+6);spec.bounds.SetLeft(230-3);spec.bounds.SetTop(10-3);
			panel.AddContent(spec);
			
			NEW(grad);grad.owner:=SELF;grad.bounds.SetExtents(22+18, 256+6);grad.bounds.SetLeft(490);grad.bounds.SetTop(10-3);
			panel.AddContent(grad);
			NEW(colorInd);colorInd.owner:=SELF;
			colorInd.bounds.SetExtents(64, 44);colorInd.bounds.SetLeft(460);colorInd.bounds.SetTop(280);
			panel.AddContent(colorInd);

			grad.spec:=spec; 
			spec.grad:=grad; 
			
			
			NEW(lab); lab.caption.SetAOC("#:");lab.bounds.SetExtents(76, 20);
			lab.bounds.SetLeft(448);lab.bounds.SetTop(325);
			panel.AddContent(lab);
			NEW(coledit); coledit.SetAsString("123456");coledit.bounds.SetWidth(64);coledit.alignment.Set(WMComponents.AlignRight);coledit.fillColor.Set(LONGINT(0FFFFFFFFH));
			coledit.onChanged.Add(OnEditColorChange);
			lab.AddContent(coledit);
			
			
			NEW(button);button.bounds.SetExtents(200, 24); button.caption.SetAOC("Add to Custom Colors");
			button.bounds.SetLeft(12);button.bounds.SetTop(275);button.onClick.Add(AddToColors);
			panel.AddContent(button);

			NEW(button);button.bounds.SetExtents(100, 24); button.caption.SetAOC("To Clipboard");
			button.bounds.SetLeft(12);button.bounds.SetTop(300);
			button.onClick.Add(CopyToClip);
			panel.AddContent(button);

			NEW(button);button.bounds.SetExtents(100, 24); button.caption.SetAOC("Instert to Text");
			button.bounds.SetLeft(112);button.bounds.SetTop(300);
			button.onClick.Add(CopyToText);
			panel.AddContent(button);

(*			ok := InstantiateButton(OkBtnId, "Ok"); line.AddContent(ok);
			ok.bounds.SetWidth(ButtonWidth); ok.alignment.Set(WMComponents.AlignRight);



			NEW(button);button.bounds.SetExtents(100, 24); button.caption.SetAOC("OK");
			button.bounds.SetLeft(12);button.bounds.SetTop(325);
			panel.AddContent(button);
*)
			NEW(button);button.bounds.SetExtents(100, 24); button.caption.SetAOC("OK");
			button.onClick.Add(Ok);
			button.bounds.SetLeft(12);button.bounds.SetTop(325);
			panel.AddContent(button);

(*			abort := InstantiateButton(AbortBtnId, "Abort"); line.AddContent(abort);
			abort.bounds.SetWidth(ButtonWidth); abort.alignment.Set(WMComponents.AlignRight);
*)

			NEW(button);button.bounds.SetExtents(100, 24); button.caption.SetAOC("Cancel");
			button.onClick.Add(Abort);
			button.bounds.SetLeft(112);button.bounds.SetTop(325);
			panel.AddContent(button);
			
			FOR i:=0 TO 2 DO
				FOR j:=0 TO 2 DO
					AddLabEd(220+i*80,275+j*25,i*3+j);
				END;
			END;
			RETURN panel
		END CreateForm;
		
		PROCEDURE Ok*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := WMDialogs.ResOk
		END Ok;

		PROCEDURE Abort*(sender, data:ANY);
		BEGIN {EXCLUSIVE}
			result := WMDialogs.ResAbort
		END Abort;

		
		PROCEDURE SetColor(sender, data : ANY);
		BEGIN
			WITH sender:ColorBut DO
				colorInd.fillColor.Set(sender.fillColor.Get());
			ELSE
				KernelLog.String("putin := bastard"); KernelLog.Ln; 
			END
		END SetColor;

		PROCEDURE AddToColors(sender, data : ANY);
		BEGIN
			palette[palettei].fillColor.Set(colorInd.fillColor.Get());
			INC(palettei);IF palettei=16 THEN palettei:=0 END;
		END AddToColors;
		
		PROCEDURE UpdateColors(sender, data : ANY);
		VAR
			i, j, n :LONGINT;
			string:ARRAY 32 OF CHAR;
			a1,a2,a3:LONGINT;
		BEGIN
			FOR i:=0 TO 8 DO
				IF sender=editorial[i] THEN n:=i END;
			END;
			colorInd.updateEditors:=FALSE;
			j:=n DIV 3;
				editorial[j*3].GetAsString(string); Strings.StrToInt(string, a1);
				editorial[j*3+1].GetAsString(string); Strings.StrToInt(string, a2);
				editorial[j*3+2].GetAsString(string); Strings.StrToInt(string, a3);
			CASE j OF
			 |0:colorInd.fillColor.Set(RGBToColor(a1,a2,a3));
			 |1:colorInd.fillColor.Set(HSLToColor(a1,a2,a3));
			 |2:colorInd.fillColor.Set(LabToColor(a1,a2,a3));
			END;
			colorInd.updateEditors:=TRUE;
			
		END UpdateColors;
		
		PROCEDURE CopyToClip(sender, data : ANY);
		VAR
			s:ARRAY 32 OF CHAR;
			buf : Texts.PUCS32String;
			idx:LONGINT;
		BEGIN
				Texts.clipboard.AcquireWrite;
				IF (Texts.clipboard.GetLength() > 0) THEN Texts.clipboard.Delete(0, Texts.clipboard.GetLength()) END;
				coledit.GetAsString(s);
				Strings.Concat("0",s,s);
				Strings.Append(s, "H");

				NEW(buf, Strings.Length(s)*2);
				idx:=0;
				UTF8Strings.UTF8toUnicode(s, buf^, idx);
				Texts.clipboard.InsertUCS32(idx, buf^);
				Texts.clipboard.ReleaseWrite;
		END CopyToClip;
		PROCEDURE CopyToText(sander,data:ANY);
		VAR	text : Texts.Text; from, to : Texts.TextPosition;
				a : LONGINT;
			buf : Texts.PUCS32String;
			idx:LONGINT;
			s:ARRAY 32 OF CHAR;
		BEGIN
			IF Texts.GetLastSelection(text, from, to) THEN
				text.AcquireWrite; text.AcquireRead;
				coledit.GetAsString(s);
				Strings.Concat("LONGINT(0",s,s);
				Strings.Append(s, "H)");
				NEW(buf, Strings.Length(s)*2);
				idx:=0;
				UTF8Strings.UTF8toUnicode(s, buf^, idx);
				a:=from.GetPosition();
				text.InsertUCS32(a, buf^);
				text.ReleaseRead; text.ReleaseWrite; 
			END;
		END CopyToText;
				
		
		PROCEDURE &New*;
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			palettei:=0;
			vc := CreateForm ();
			Init (vc.bounds.GetWidth (), vc.bounds.GetHeight (), FALSE);
			SetContent (vc);
			icon := WMGraphics.LoadImage("WMColorPicker.zip://palette.png", TRUE);

			SetIcon(icon);
			
(*			WM.DefaultAddWindow (SELF);*)
			
			SetTitle (Strings.NewString ("Color picker dialog"));
		END New;

		PROCEDURE OnEditColorChange(sander, data :ANY);
		VAR
			string : ARRAY 32 OF CHAR;
			col,res:LONGINT;
		BEGIN
			coledit.GetAsString(string); Strings.HexStrToInt(string, col, res);  colorInd.fillColor.Set(col);
		END OnEditColorChange;

	END PickColorDlg;
	
	
	
	
PROCEDURE DrawBevel*(canvas : WMGraphics.Canvas; rect : WMRectangles.Rectangle; down : BOOLEAN; mode : LONGINT);
VAR c11, c12, c21,c22 : LONGINT;
BEGIN
	IF down THEN 
		c11:=LONGINT(0808080FFH);
		c12:=LONGINT(0404040FFH);
		c21:=LONGINT(0D4D0C8FFH);
		c22:=LONGINT(0FFFFFFFFH);
	ELSE 
		c21:=LONGINT(0808080FFH);
		c22:=LONGINT(0404040FFH);
		c11:=LONGINT(0D4D0C8FFH);
		c12:=LONGINT(0FFFFFFFFH);
	END;
	canvas.Fill(WMRectangles.MakeRect(rect.l  , rect.t , rect.r , rect.t  + 1), c21, mode);
	canvas.Fill(WMRectangles.MakeRect(rect.l , rect.t  + 1, rect.l  + 1, rect.b ), c21, mode);
	canvas.Fill(WMRectangles.MakeRect(rect.l + 1 , rect.b - 1 , rect.r , rect.b ), c21, mode);
	canvas.Fill(WMRectangles.MakeRect(rect.r - 1 , rect.t + 1 , rect.r , rect.b  - 1), c21, mode);

	rect:=WMRectangles.ResizeRect(rect,-1);	
	canvas.Fill(WMRectangles.MakeRect(rect.l  , rect.t , rect.r , rect.t  + 1), c11, mode);
	canvas.Fill(WMRectangles.MakeRect(rect.l , rect.t  + 1, rect.l  + 1, rect.b ), c11, mode);
	canvas.Fill(WMRectangles.MakeRect(rect.l + 1 , rect.b - 1 , rect.r , rect.b ), c22, mode);
	canvas.Fill(WMRectangles.MakeRect(rect.r - 1 , rect.t + 1 , rect.r , rect.b  - 1), c22, mode);
	rect:=WMRectangles.ResizeRect(rect,-1);
	canvas.Fill(WMRectangles.MakeRect(rect.l  , rect.t , rect.r , rect.t  + 1), c12, mode);
	canvas.Fill(WMRectangles.MakeRect(rect.l , rect.t  + 1, rect.l  + 1, rect.b ), c12, mode);
	canvas.Fill(WMRectangles.MakeRect(rect.l + 1 , rect.b - 1 , rect.r , rect.b ), c21, mode);
	canvas.Fill(WMRectangles.MakeRect(rect.r - 1 , rect.t + 1 , rect.r , rect.b  - 1), c21, mode);
END DrawBevel;

PROCEDURE ColorToRGB*(color : LONGINT; VAR r, g, b : LONGINT);
BEGIN
	r := (color DIV 1000000H) MOD 100H;
	g := (color DIV 10000H) MOD 100H;
	b := (color DIV 100H) MOD 100H;
END ColorToRGB;

PROCEDURE RGBToColor*(r, g, b: LONGINT): LONGINT;
BEGIN
	RETURN r * 1000000H + g * 10000H + b * 100H+0FFH (*no alpha*)
END RGBToColor;

PROCEDURE HSLToColor(H, S, L: REAL): LONGINT;
VAR
	M1, M2: REAL;
	R, G, B: LONGINT;
	PROCEDURE HueToColourValue(Hue: REAL) : LONGINT;
	VAR
		V : REAL;
	BEGIN
		IF Hue < 0 THEN Hue := Hue + 1 
		ELSIF Hue > 1 THEN Hue := Hue - 1; END;

		IF 6 * Hue < 1 THEN
			V := M1 + (M2 - M1) * Hue * 6
		ELSIF 2 * Hue < 1 THEN
			V := M2
		ELSIF 3 * Hue < 2 THEN
			V := M1 + (M2 - M1) * (2/3 - Hue) * 6
		ELSE
			V := M1;
		END;
		RETURN	ENTIER(255 * V+0.5)
	END HueToColourValue;

BEGIN
	IF S = 0 THEN
		R := ENTIER (255 * L+0.5);
		G := R;
		B := R
	ELSE
		IF L <= 0.5 THEN M2 := L * (1 + S) ELSE M2 := L + S - L * S; END;
		M1 := 2 * L - M2;
		R := HueToColourValue (H + 1/3);
		G := HueToColourValue (H);
		B := HueToColourValue (H - 1/3)
	END;
	RETURN RGBToColor(R, G, B);
END HSLToColor;

PROCEDURE ColorToHSL(color: LONGINT; VAR H, S, L: REAL);
VAR
  r, g, b : LONGINT;
  R, G, B : REAL;
  DR, DG, DB, D, Cmax, Cmin: REAL;

BEGIN
	ColorToRGB(color, r, g, b);
	R := r / 255;
	G := g / 255;
	B := b / 255;
	Cmax := MAX(R, MAX(G, B));
	Cmin := MIN(R, MIN(G, B));

	(* luminosity: *)
	L := (Cmax + Cmin) / 2;

	IF Cmax = Cmin THEN  (*grey*)
		H := 0; (* it's actually undefined *)
		S := 0;
	ELSE
		D := Cmax - Cmin;
		
		(* Saturation *)
		IF L < 0.5 THEN S := D / (Cmax + Cmin) ELSE S := D / (2 - Cmax - Cmin); END;
		
		(* Hue *)
		DR := (((Cmax - R) / 6) + (D / 2)) / D;
		DG := (((Cmax - G) / 6) + (D / 2)) / D;
		DB := (((Cmax - B) / 6) + (D / 2)) / D;

		IF R = Cmax THEN H := (DB - DG)
		ELSIF G = Cmax THEN  H := (1 / 3) + DR - DB
		ELSE H := (2 / 3) + DG - DR; 
		END;

	      IF H < 0 THEN H:=H + 1 END;
	      IF H > 1 THEN H := H - 1 END;
	END
END ColorToHSL;

PROCEDURE ColorToLab(color: LONGINT;VAR L,a,b:REAL);
VAR
	X, y, Z : REAL;
	R, G, B : REAL;
	iR, iG, iB : LONGINT;

BEGIN
(*Public Function RGB_CieLAB(ByVal R, ByVal G, ByVal B,   ByRef cL As Single, ByRef cA As Single, ByRef cB As Single)*)
                
	ColorToRGB(color, iR, iG, iB); R:=iR/255; G:=iG/255; B:=iB/255;

	IF (R > 0.04045) THEN R := Math.exp(2.4*Math.ln((R + 0.055) / 1.055)) ELSE R := R / 12.92 END;
	IF (G > 0.04045) THEN G := Math.exp(2.4*Math.ln((G + 0.055) / 1.055)) ELSE G := G / 12.92 END;
	IF (B > 0.04045) THEN B := Math.exp(2.4*Math.ln((B + 0.055) / 1.055)) ELSE B := B / 12.92 END;

	(* Observer. = 2Â°, Illuminant = D65 *)
    X := R * 0.4124 + G * 0.3576 + B * 0.1805;
    y := R * 0.2126 + G * 0.7152 + B * 0.0722;
    Z := R * 0.0193 + G * 0.1192 + B * 0.9505;

	X := X / 0.95047;       (*Observer= 2Â°, Illuminant= D65*)
(*	Y = Y / 1 nothing to do! *)
	Z := Z / 1.08883;

	IF (X > 0.008856) THEN X := Math.exp(K1d3*Math.ln(X)) ELSE X := (7.787 * X) + (K16d116) END;
	IF (y > 0.008856) THEN y := Math.exp(K1d3*Math.ln(y)) ELSE y := (7.787 * y) + (K16d116) END;
	IF (Z > 0.008856) THEN Z := Math.exp(K1d3*Math.ln(Z)) ELSE Z := (7.787 * Z) + (K16d116) END;

    L := 116 * y - 16;
    a := 500 * (X - y);
    b := 200 * (y - Z);

END ColorToLab;

PROCEDURE LabToColor(L,a,b:REAL): LONGINT;
VAR
	X, y, Z : REAL;
	X3, Y3, Z3 : REAL;
	R, G, B : REAL;
	iR, iG, iB : LONGINT;
BEGIN
    
    y := (L + 16) / 116;
    X := a / 500 + y;
    Z := y - b / 200;

    X3 := X * X * X;
    Y3 := y * y * y;
    Z3 := Z * Z * Z;


	IF (X3 > 0.008856) THEN X := X3 ELSE X := (X - K16d116) / 7.787 END;
	IF (Y3 > 0.008856) THEN y := Y3 ELSE y := (y - K16d116) / 7.787 END;
	IF (Z3 > 0.008856) THEN Z := Z3 ELSE Z := (Z - K16d116) / 7.787 END;

	X := X * 0.95047;	(*Observer= 2Â°, Illuminant= D65*)
	(*Y = Y * 1*)
	Z := Z * 1.08883;


	R := (X * 3.2406 + y * (-1.5372) + Z * (-0.4986));
	G := (X * (-0.9689) + y * 1.8758 + Z * 0.0415);
	B := (X * 0.0557 + y * (-0.204) + Z * 1.057);
		
	IF (R > 0.0031308) THEN R := (1.055 * Math.exp(K1d2p4*Math.ln(R)) - 0.055) ELSE R := 12.92 * R END;
	IF (G > 0.0031308) THEN G := (1.055 * Math.exp(K1d2p4*Math.ln(G)) - 0.055) ELSE G := 12.92 * G END;
	IF (B > 0.0031308) THEN B := (1.055 * Math.exp(K1d2p4*Math.ln(B)) - 0.055) ELSE B := 12.92 * B END;


	iR:=ENTIER(MIN(MAX(0,R*255+0.5), 255));
	iG:=ENTIER(MIN(MAX(0,G*255+0.5), 255));
	iB:=ENTIER(MIN(MAX(0,B*255+0.5), 255));
	RETURN RGBToColor(iR,iG,iB);
END LabToColor;



VAR 
	userPalette* : ARRAY CustomCount OF LONGINT;
	ListFilterProt : WMProperties.StringProperty;
	imgArrR,imgArrL : WMGraphics.Image;
	imgMouse : WMGraphics.Image;
	imgCursor : WMGraphics.Image;
	ActiveGrad : LONGINT;
PROCEDURE InitPrototypes;
BEGIN
	NEW(ListFilterProt, NIL, Strings.NewString("Filter"), Strings.NewString("display list filter"));
END InitPrototypes;

(** Open a ColorPickDialog  at x:y position with default value color.
	Return ResOk or ResAbort. If res is ResOk color contains the selected color. Color is not changed if
	res is ResAbort *)
PROCEDURE PickColorXY*(x, y : LONGINT; VAR color : LONGINT) : LONGINT;
VAR qsd : PickColorDlg;
BEGIN
	NEW(qsd);
	IF ~qsd.errors THEN
		qsd.colorInd.fillColor.Set(color);
		qsd.x := x; qsd.y := y; qsd.Show; 
		IF qsd.result = WMDialogs.ResOk THEN color:=qsd.colorInd.fillColor.Get() END;
		RETURN qsd.result
	ELSE RETURN WMDialogs.ResDialogFailure
	END
END PickColorXY;

(** Open a ColorPickDialog  at default position with default value color.
	Return ResOk or ResAbort. If res is ResOk color contains the selected color. Color is not changed if
	res is ResAbort *)
PROCEDURE PickColor*(VAR color : LONGINT) : LONGINT;
BEGIN
	RETURN PickColorXY(100, 100, color)
END PickColor;


PROCEDURE Open*;
VAR color : LONGINT;
BEGIN
	color := LONGINT(06B3711FFH);
	KernelLog.Int(PickColor(color), 5);
	KernelLog.String("Result = "); KernelLog.Hex(color,8); KernelLog.Ln;
END Open;


BEGIN
	imgArrL:=WMGraphics.LoadImage("WMColorPicker.zip://ArrL.png", TRUE);
	imgArrR:=WMGraphics.LoadImage("WMColorPicker.zip://ArrR.png", TRUE);
	imgMouse:=WMGraphics.LoadImage("WMColorPicker.zip://mouse.png", TRUE);
	imgCursor:=WMGraphics.LoadImage("WMColorPicker.zip://Cursor.png", TRUE);
	ActiveGrad:=5;
	InitPrototypes;
	manager := WMWindowManager.GetDefaultManager();
END WMColorPicker.


SystemTools.Free WMColorPicker ~
SystemTools.FreeDownTo WMColorPicker ~

WMColorPicker.Open ~
WMDebugger.Open WMColorPicker.Mod~