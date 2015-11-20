(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE DisplayLinear; (** AUTHOR "pjm"; PURPOSE "Linear framebuffer display driver"; *)

(*
Config strings:
	DWidth=1024	Display width
	DHeight=768	Display height
	DDepth=16	Display depth
	DMem=?	Display memory size in bytes
	Init=?	Init program.

The Init program is a 8086 machine code program in hexadecimal.  It has to initialize the specified display mode, possibly by making display BIOS calls, and leave the 32-bit physical address of the frame buffer in DX:CX.
*)

IMPORT SYSTEM, Machine, KernelLog, MemCache, Displays, Strings, Commands, Options, Modules;

VAR
	d: Displays.Display;

PROCEDURE GetVal(name: ARRAY OF CHAR;  default: LONGINT): LONGINT;
VAR v: LONGINT;  s: ARRAY 10 OF CHAR;  p: LONGINT;
BEGIN
	Machine.GetConfig(name, s);
	IF s[0] = 0X THEN
		v := default
	ELSE
		p := 0;  v := Machine.StrToInt(p, s)
	END;
	RETURN v
END GetVal;

PROCEDURE Install*(context: Commands.Context);
VAR options: Options.Options;
BEGIN
	NEW(options);
	options.Add("r", "reverse", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		IF options.GetFlag("r") THEN Displays.Reverse() END;
	END;
END Install;

PROCEDURE InitPalette;
VAR col: LONGINT; ch: CHAR;
BEGIN
	Machine.Portin8(3DAH, ch);
	Machine.Portout8(3C0H, 11X);
	Machine.Portout8(3C0H, 0X);	(* palette entry 0 is black *)
	Machine.Portout8(3C0H, 20X);
	FOR col := 0 TO 255 DO
		Machine.Portout8(3C8H, CHR(col));
		Machine.Portout8(3C9H, CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, col) * {5..7}) DIV 4));
		Machine.Portout8(3C9H, CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(col, 7-4)) * {5..7}) DIV 4));
		Machine.Portout8(3C9H, CHR(SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ASH(col, 7-1)) * {6..7}) DIV 4))
	END
END InitPalette;

PROCEDURE Init;
VAR w, h, f, mem, res: LONGINT; ts : ARRAY 16 OF CHAR; padr, vadr: ADDRESS;
BEGIN
	w := GetVal("DWidth", 1024); h := GetVal("DHeight", 768);
	CASE GetVal("DDepth", 16) DIV 8 OF
		1: f := Displays.index8; InitPalette
		|2: f := Displays.color565
		|3: f := Displays.color888
		|4: f := Displays.color8888
	END;
	mem := GetVal("DMem", 0)*1024;
	IF mem = 0 THEN	(* compute default *)
		mem := 512*1024;
		WHILE w*h*f >= mem DO mem := mem*2 END
	END;
	Machine.GetInit(1, SYSTEM.VAL(LONGINT,padr));	(* DX:CX from Init code *)
	ASSERT((padr # 0) & (padr MOD 4096 = 0));
	IF GetVal("DCache", 1) = 1 THEN
		MemCache.GlobalSetCacheProperties(padr, mem, MemCache.WC, res);
		IF res # 0 THEN
			KernelLog.Enter; KernelLog.String("DisplayLinear: GlobalSetCacheProperties = ");
			KernelLog.Int(res, 1); KernelLog.Exit
		END
	END;
	(* KernelLog.ScreenOff; *)
	Machine.MapPhysical(padr, mem, vadr);
	Machine.Fill32(vadr, mem, 0);	(* clear video memory *)
	NEW(d);
	d.width := w; d.height := h; d.offscreen := mem DIV (w*f) - h;
	d.format := f; d.unit := 10000;
	d.InitFrameBuffer(vadr, mem, w * f);
	d.desc := "Generic linear framebuffer driver (";
	Strings.IntToStr(d.width, ts); Strings.Append(d.desc, ts);
	Strings.Append(d.desc, "x");
	Strings.IntToStr(d.height, ts);  Strings.Append(d.desc, ts);
	Strings.Append(d.desc, "x");
	Strings.IntToStr(d.format, ts);  Strings.Append(d.desc, ts);
	Strings.Append(d.desc, ")");
	Displays.registry.Add(d, res);
	ASSERT(res = 0)
END Init;

PROCEDURE CleanUp;
BEGIN
	ASSERT (d # NIL);
	Machine.Fill32(d.fbadr, d.fbsize, 0);	(* clear video memory *)
END CleanUp;

BEGIN
	Init;
	Modules.InstallTermHandler(CleanUp);
END DisplayLinear.

