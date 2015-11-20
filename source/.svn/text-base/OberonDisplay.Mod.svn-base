(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE OberonDisplay;
(** AUTHOR "pjm"; PURPOSE "Aos display driver for WM window"; *)

IMPORT SYSTEM, Machine, Commands, Displays, Inputs, Modules, Plugins, Raster,
	WMRectangles, WMGraphics,
	WM := WMWindowManager;

CONST
	DefaultDisplayName = "Oberon";
	DefaultWidth = 1024;
	DefaultHeight = 768;

	AlphaCursor = 10;

	KeyBufSize = 64;

	Flip = FALSE;

	Cache = TRUE;

VAR
	nilpix : Raster.Pixel;

TYPE
	OberonWindow = OBJECT (WM.BufferWindow)
	VAR
		input : OberonInput;	(* initialized from outside *)

		curKeys : SET;
		curX, curY : LONGINT;	(* Coordinates of the mouse pointer while moving or when released. *)

		keyhead, keytail : LONGINT;
		keybuf : ARRAY KeyBufSize OF CHAR;

		keys : SET;
		break : BOOLEAN;
		fixMM : BOOLEAN;	(* Value TRUE denotes the presence of a 2-button mouse, Ctrl-key acts then as middle button. *)
		lastCtrl : BOOLEAN;	(* Value TRUE denotes Ctrl-key pressed. *)

		PROCEDURE IsHit(x, y  : LONGINT) : BOOLEAN;
		BEGIN RETURN TRUE;
		END IsHit;

		PROCEDURE Mouse(VAR x, y : INTEGER; VAR keys : SET);
		BEGIN {EXCLUSIVE}
			keys := {};
			IF 0 IN curKeys THEN INCL(keys, 2) END;
			IF 1 IN curKeys THEN INCL(keys, 1) END;
			IF 2 IN curKeys THEN INCL(keys, 0) END;
			IF 30 IN curKeys THEN IF curKeys={30} THEN INCL(keys, 30); END; curKeys := curKeys - {30} END; (*fof*)
			IF 31 IN curKeys THEN IF curKeys={31} THEN INCL(keys, 31); END; curKeys := curKeys - {31}  END;
			x := SHORT(curX);
			y := SHORT(curY)
		END Mouse;

		PROCEDURE PointerMove(x, y : LONGINT; keys :SET);
		BEGIN {EXCLUSIVE}
			curX := x; curY := y; curKeys := curKeys * {30, 31} + keys;
			IF fixMM &lastCtrl THEN INCL(curKeys, 1) END;
			IF input # NIL THEN input.timer.Wakeup END	(* have to check, because upcalls to us can start immediately *)
		END PointerMove;

		PROCEDURE WheelMove(dz : LONGINT); (*fof*)
		BEGIN
			IF dz > 0 THEN
				INCL(curKeys, 30);
			ELSIF dz < 0 THEN
				INCL(curKeys, 31);
			END;
			IF input # NIL THEN input.timer.Wakeup END	(* have to check, because upcalls to us can start immediately *)
		END WheelMove;

		PROCEDURE PointerUp(x, y : LONGINT; keys : SET);
		BEGIN {EXCLUSIVE}
			curX := x; curY := y; curKeys := keys;
			IF input # NIL THEN input.timer.Wakeup END
		END PointerUp;

			(* Keyboard handling *)
		PROCEDURE InsertKey(ch : CHAR; keysym : LONGINT; flags : SET);
		BEGIN
			keys := {};
			IF flags * Inputs.Shift # {} THEN INCL(keys, Inputs.SHIFT) END;
			IF flags * Inputs.Ctrl # {} THEN INCL(keys, Inputs.CTRL) END;
			IF flags * Inputs.Alt # {} THEN INCL(keys, Inputs.ALT) END;
			IF ch # 0X THEN
				IF (keytail+1) MOD KeyBufSize # keyhead THEN
					keybuf[keytail] := ch; keytail := (keytail+1) MOD KeyBufSize
				END;
				(*timer.WakeUp*)	(* always do wakeup because of race with Sleep *)
			ELSIF keysym = Inputs.KsBreak THEN	(* Break *)
				break := TRUE
				(*timer.WakeUp *)
			ELSE
				(* skip *)
			END
		END InsertKey;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			InsertKey(0FFX, 0, {})
		END Close;

		PROCEDURE KeyEvent(ucs : LONGINT; flags : SET; keysym : LONGINT);
		BEGIN {EXCLUSIVE}
			IF fixMM & ((flags * Inputs.Ctrl # {}) # lastCtrl)  THEN
				lastCtrl := flags * Inputs.Ctrl # {};
				IF lastCtrl THEN INCL(curKeys, 1) ELSE EXCL(curKeys, 1) END;
				IF input # NIL THEN input.timer.Wakeup END
			ELSE
				InsertKey(CHR(ucs), keysym, flags);
				IF input # NIL THEN input.timer.Wakeup END
			END;
		END KeyEvent;

		PROCEDURE Read(VAR ch : CHAR; VAR b : BOOLEAN);
		BEGIN {EXCLUSIVE}
			AWAIT(keyhead # keytail);
			ch := keybuf[keyhead]; keyhead := (keyhead+1) MOD KeyBufSize;
			b := break; break := FALSE
		END Read;

		PROCEDURE Available(VAR num : INTEGER; VAR b : BOOLEAN);
		BEGIN {EXCLUSIVE}
			num := SHORT((keytail-keyhead) MOD KeyBufSize);
			b := break; break := FALSE
		END Available;

		PROCEDURE KeyState(VAR k : SET);
		BEGIN {EXCLUSIVE}
			k := keys
		END KeyState;

	END OberonWindow;

TYPE
	OberonInput = OBJECT (Inputs.OberonInput)
		VAR window : OberonWindow;

		PROCEDURE Mouse(VAR x, y : INTEGER; VAR keys : SET);
		BEGIN
			window.Mouse(x, y, keys)
		END Mouse;

		PROCEDURE Read(VAR ch : CHAR; VAR b : BOOLEAN);
		BEGIN
			window.Read(ch, b)
		END Read;

		PROCEDURE Available(VAR num : INTEGER; VAR b : BOOLEAN);
		BEGIN
			window.Available(num, b)
		END Available;

		PROCEDURE KeyState(VAR k : SET);
		BEGIN
			window.KeyState(k)
		END KeyState;

	END OberonInput;

TYPE
	(* Implementation of the virtual display driver.
		A concrete Display must implement at least the Transfer function
		or initialize a linear frame buffer and call the InitFrameBuffer method.
	*)

	Display* = OBJECT (Displays.Display)	(* custom display object only accessed by Oberon (no EXCLUSIVE) *)
		VAR
			disp : OberonWindow;
			inp : OberonInput;
			bufimg : Raster.Image;
			mode, mode1 : Raster.Mode;
			ml, mt, mr, mb : LONGINT;

		PROCEDURE LocalAddDirty(l, t, r, b : LONGINT);
		BEGIN
			IF Cache THEN
				IF l < ml THEN ml := l END;	(* enlarge dirty rectangle *)
				IF t < mt THEN mt := t END;
				IF r > mr THEN mr := r END;
				IF b > mb THEN mb := b END
			ELSE
				disp.Invalidate(WMRectangles.MakeRect(l, t, r, b))
			END
		END LocalAddDirty;

		PROCEDURE Update;
		BEGIN
			IF Cache & (ml # MAX(LONGINT)) THEN
				disp.Invalidate(WMRectangles.MakeRect(ml, mt, mr, mb));	(* updated dirty rectangle *)
				ml := MAX(LONGINT); mt := MAX(LONGINT); mr := MIN(LONGINT); mb := MIN(LONGINT)
			END
		END Update;

		PROCEDURE Transfer*(VAR buf : ARRAY OF CHAR; ofs, stride, x, y, w, h, op : LONGINT);
		BEGIN
			Raster.InitMode(mode, Raster.srcCopy);
			IF Flip THEN
				Raster.Init(bufimg, w, h, disp.img.fmt, -stride, ADDRESSOF(buf[ofs]) + (h-1)*stride);
				IF op = Displays.get THEN
					Raster.Copy(disp.img, bufimg, x, height-y-h, x+w, height-y, 0, 0, mode)
				ELSIF op = Displays.set THEN
					Raster.Copy(bufimg, disp.img, 0, 0, w, h, x, height-y-h, mode);
					LocalAddDirty(x, height-y-h, x+w, height-y)
				ELSE (* skip *)
				END
			ELSE
				Raster.Init(bufimg, w, h, disp.img.fmt, stride, ADDRESSOF(buf[ofs]));
				IF op = Displays.get THEN
					Raster.Copy(disp.img, bufimg, x, y, x+w, y+h, 0, 0, mode)
				ELSIF op = Displays.set THEN
					Raster.Copy(bufimg, disp.img, 0, 0, w, h, x, y, mode);
					LocalAddDirty(x, y, x+w, y+h)
				ELSE (* skip *)
				END
			END
		END Transfer;

		PROCEDURE Fill*(col, x, y, w, h : LONGINT);
		VAR pixel: Raster.Pixel;
		BEGIN
			IF Flip THEN
				Fill^(col, x, y, w, h)	(* supermethod not exclusive *)
			ELSE
				Raster.InitMode(mode, Raster.srcCopy);
				IF ASH(col, 1) < 0 THEN	(* invert *)
					Raster.InitMode(mode, Raster.InvDst);
					Raster.Fill(disp.img, x, y, x+w, y+h, nilpix, mode)
				ELSE
					Raster.InitMode(mode, Raster.srcCopy);
					Raster.SetRGB(pixel, col DIV 10000H, col DIV 100H, col);
					Raster.Fill(disp.img, x, y, x+w, y+h, pixel, mode)
				END;
				LocalAddDirty(x, y, x+w,  y+h)
			END
		END Fill;

		PROCEDURE Dot*(col, x, y : LONGINT);
		VAR pixel: Raster.Pixel;
		BEGIN
			IF Flip THEN
				Dot^(col, x, y)	(* supermethod not exclusive *)
			ELSE
				IF ASH(col, 1) < 0 THEN	(* invert *)
					Raster.InitMode(mode, Raster.InvDst);
					Raster.Put(disp.img, x, y, nilpix, mode)
				ELSE
					Raster.InitMode(mode, Raster.srcCopy);
					Raster.SetRGB(pixel, col DIV 10000H, col DIV 100H, col);
					Raster.Put(disp.img, x, y, pixel, mode)
				END;
				LocalAddDirty(x, y, x+1, y+1)
			END
		END Dot;

		PROCEDURE Mask*(VAR buf : ARRAY OF CHAR; bitofs, stride, fg, bg, x, y, w, h : LONGINT);
		VAR p: ADDRESS; i, y0, h0 : LONGINT; s : SET; pixel, fgp, bgp : Raster.Pixel;
		BEGIN
			IF Flip THEN
				Mask^(buf, bitofs, stride, fg, bg, x, y, w, h)	(* supermethod not exclusive *)
			ELSE
				IF (w > 0) & (h > 0) THEN
					i := SYSTEM.VAL (LONGINT, ADDRESSOF(buf[0])) MOD 4;
					INC(bitofs, i * 8);
					p := ADDRESSOF(buf[0])-i + bitofs DIV 32 * 4;	(* p always aligned to 32-bit boundary *)
					bitofs := bitofs MOD 32; stride := stride*8;
					IF ASH(fg, 1) < 0 THEN	(* invert *)
						Raster.InitMode(mode, Raster.InvDst)
					ELSE
						Raster.InitMode(mode, Raster.srcCopy);
						Raster.SetRGB(fgp, fg DIV 10000H, fg DIV 100H, fg);
					END;
					IF ASH(bg, 1) < 0 THEN	(* invert *)
						Raster.InitMode(mode1, Raster.InvDst)
					ELSE
						Raster.InitMode(mode1, Raster.srcCopy);
						Raster.SetRGB(bgp, bg DIV 10000H, bg DIV 100H, bg);
					END;
					y0 := y; h0 := h;
					LOOP
						SYSTEM.GET(p, s); i := bitofs;
						LOOP
							IF (i MOD 32) IN s THEN
								IF fg >= 0 THEN Raster.Put(disp.img, x+i-bitofs, y, fgp, mode) END
							ELSE
								IF bg >= 0 THEN Raster.Put(disp.img, x+i-bitofs, y, bgp, mode1) END
							END;
							INC(i);
							IF i-bitofs = w THEN EXIT END;
							IF i MOD 32 = 0 THEN SYSTEM.GET(p+i DIV 8, s) END
						END;
						DEC(h);
						IF h = 0 THEN EXIT END;
						INC(y); INC(bitofs, stride);
						IF (bitofs >= 32) OR (bitofs < 0) THEN	(* moved outside s *)
							INC(p, bitofs DIV 32 * 4); bitofs := bitofs MOD 32
						END
					END;
					LocalAddDirty(x, y0, x+w, y0+h0)
				END
			END
		END Mask;

		PROCEDURE Copy*(sx, sy, w, h, dx, dy : LONGINT);
		BEGIN
			IF Flip THEN
				Copy^(sx, sy, w, h, dx, dy)	(* supermethod not exclusive *)
			ELSE
				Raster.InitMode(mode, Raster.srcCopy);
				Raster.Copy(disp.img, disp.img, sx, sy, sx+w, sy+h, dx, dy, mode);
				LocalAddDirty(dx, dy, dx+w,  dy+h)
			END
		END Copy;

		PROCEDURE &Init*(name : ARRAY OF CHAR; w, h, x, y : LONGINT);
		VAR res : LONGINT; ptr : WM.PointerInfo; pixel : Raster.Pixel; mode : Raster.Mode;
			s : ARRAY 16 OF CHAR;
		BEGIN
			ml := MAX(LONGINT); mt := MAX(LONGINT); mr := MIN(LONGINT); mb := MIN(LONGINT);
			width := w; height := h; offscreen := 0; unit := 10000;
			NEW(bufimg);
			NEW(disp, w, h, FALSE);
			Machine.GetConfig("MB", s);
			disp.fixMM := (s = "2") OR (s = "-2");
			NEW(inp);
			inp.window := disp; disp.input := inp;	(* "multiple inheritance" *)
			CASE disp.img.fmt.code OF
				| Raster.d8 :		format := Displays.index8
				| Raster.bgr565 :	format := Displays.color565
				| Raster.bgr888 :	format := Displays.color888
				| Raster.bgra8888 :	format := Displays.color8888
			END;
			IF ~Flip THEN
				NEW(ptr); ptr.hotX := 2; ptr.hotY := 2;
				NEW(ptr.img); Raster.Create(ptr.img, 4, 4, Raster.BGRA8888);
				Raster.SetRGBA(pixel, 255, 255, 255, AlphaCursor);
				Raster.InitMode(mode, Raster.srcCopy);
				Raster.Fill(ptr.img, 0, 0, 4, 4, pixel, mode);
				Raster.SetRGBA(pixel, 0, 0, 0, AlphaCursor);
				Raster.Fill(ptr.img, 1, 1, 3, 3, pixel, mode);
				disp.SetPointerInfo(ptr)
			END;
			IF Flip THEN
				disp.SetTitle(WM.NewString("Oberon for Bluebottle down under"))
			ELSE
				disp.SetTitle(WM.NewString("Oberon for Bluebottle"))
			END;
			disp.SetIcon(WMGraphics.LoadImage("WMIcons.tar://OberonDisplay.png", TRUE));
			WM.AddWindow(disp, x, y);
				(* Register virtual display driver *)
			SELF.desc := "WM virtual display driver";
			SELF.SetName(name);
			Displays.registry.Add(SELF, res);
			ASSERT(res = 0);

				(* Register virtual input driver *)
			inp.desc := "WM virtual input driver";
			inp.SetName(name);
			Inputs.oberonInput.Add(inp, res);
			ASSERT(res = 0)
		END Init;

		PROCEDURE Finalize;
		BEGIN
			IF disp = NIL THEN RETURN END;
			Inputs.oberonInput.Remove(inp);	(* Unregister virtual input driver *)
			Displays.registry.Remove(SELF);	(* Unregister virtual display driver *)
			disp.manager.Remove(disp);	(* close window *)
			(* bufimg := NIL; disp := NIL; inp := NIL;	remove the potentially endless traps *)(* cause further drawing calls to trap *)
			IF win = SELF THEN win := NIL END
		END Finalize;

	END Display;

VAR
	win : Display;

(** Usage: OberonDisplay.Install [ name ] width [ character ] height ~
		Default name: Oberon
		character: single character e.g. blank or "x"	*)
PROCEDURE Install*(context : Commands.Context);
VAR
	w, h : LONGINT; name : ARRAY 32 OF CHAR;
	dw, dh : LONGINT; disp : Plugins.Plugin;
	x, y : LONGINT;
BEGIN
	IF win = NIL THEN
		w := 0; h := 0; name := "";
		context.arg.SkipWhitespace; context.arg.String(name);
		context.arg.SkipWhitespace; context.arg.Int(w, FALSE);
		context.arg.SkipBytes(1); (* skip "x" or single space *)
		context.arg.SkipWhitespace; context.arg.Int(h, FALSE);
		x := 0; y := 0;
		context.arg.SkipWhitespace; context.arg.Int(x, FALSE);
		context.arg.SkipWhitespace; context.arg.Int(y, FALSE);

		IF name = "" THEN name := DefaultDisplayName END;

		IF (w <= 0) OR (h <= 0) THEN
			dw := DefaultWidth; dh := DefaultHeight;
			disp := Displays.registry.Get("");
			IF disp # NIL THEN
				WITH disp: Displays.Display DO
					dw := disp.width;
					dh := disp.height;
				END;
			END;
		END;
		IF w <= 0 THEN w := dw END;
		IF h <= 0 THEN h := dh END;
		NEW(win, name, w, h, x, y)
	END;
END Install;

PROCEDURE Remove*;
BEGIN
	IF win # NIL THEN win.disp.Close END;
END Remove;

PROCEDURE SwitchToWM*;
BEGIN
	IF win # NIL THEN
		(* send magic key to Oberon (assume Oberon.Loop will read it) *)
		win.disp.InsertKey(0FEX, Inputs.KsNil, {})
	END
END SwitchToWM;

PROCEDURE Cleanup;
BEGIN
	Remove;
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END OberonDisplay.

OberonDisplay.Install Oberon 1024x768;Oberon.Call System.Init Oberon ~

OberonDisplay.Install 1024 768;Oberon.Call System.Init ~

OberonDisplay.Remove ~

SystemTools.Free OberonDisplay ~


(*
o mode set every time?
o clean up at exit
o optimization: remove exclusive, factor out all modes (src, dst, mode combinations) [what about finalize?]
*)

Now OberonInput.Mod is to be removed and Aos.System.Mod simplified (OberonInput.Remove
is commentarized in LoadWM)
