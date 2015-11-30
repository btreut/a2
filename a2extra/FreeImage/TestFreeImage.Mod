MODULE TestFreeImage; (*fnecati* AUTHOR ""; PURPOSE "test module for FreeImage examples"; *)

IMPORT
	FI := FreeImageDll, FIUtils:= FreeImageUtils, KernelLog, Strings, 
	Commands, WM := WMWindowManager, Raster, 
	WMGraphics, Math, WMComponents, WMStandardComponents, SYSTEM;

TYPE
	FIBITMAP=FI.FIBITMAP;

TYPE 
	PicView* = OBJECT(WM.BufferWindow)
		
		PROCEDURE &New*(w, h: LONGINT);
		BEGIN
			Init(w, h, FALSE);
			WM.DefaultAddWindow(SELF);
		END New;
		
		PROCEDURE SetImage*(p: Raster.Image; CONST title: ARRAY OF CHAR);
		VAR mode: Raster.Mode;
		BEGIN
			SetTitle(Strings.NewString(title));
			Raster.InitMode(mode,  Raster.srcCopy);
			Raster.Copy(p, img, 0, 0, p.width, p.height, 0, 0, mode);
			Invalidate(WMGraphics.MakeRectangle(0,0, p.width, p.height));
		END SetImage;
		
	END PicView;

TYPE 
	PicPanel* = OBJECT(WMComponents.FormWindow)
		VAR impanel: WMStandardComponents.ImagePanel;
		
		PROCEDURE &New*(w, h: LONGINT);
		BEGIN
			Init(w, h, TRUE);
			NEW(impanel); impanel.bounds.SetWidth(256);
			impanel.alignment.Set(WMComponents.AlignClient);
			
			SetContent(impanel);
			WM.DefaultAddWindow(SELF);
		END New;
		
		PROCEDURE SetImage*(p: WMGraphics.Image; CONST title: ARRAY OF CHAR);
		BEGIN
			SetTitle(Strings.NewString(title));
			impanel.SetImage(SELF, p);
(*			impanel.Invalidate(); *)
			Invalidate(WMGraphics.MakeRectangle(0,0, GetWidth(), GetHeight()));
		END SetImage;
		
	END PicPanel;

(** show FreeImage's supported image read/write formats  *)
PROCEDURE GetFormats*;
VAR
	str, format, description, ext : Strings.String;
	icc: CHAR;
	count: LONGINT;
	fif: FI.IMAGE_FORMAT;
BEGIN
	IF FI.IsLittleEndian() THEN
		KernelLog.String("System is LittleEndian"); KernelLog.Ln; 
	ELSE
		KernelLog.String("System is NOT LittleEndian"); KernelLog.Ln; 
	END;
	
	(* print version & copyright infos *)
	str := FI.GetVersion();
	KernelLog.String("FreeImage Version: "); KernelLog.String(str^); KernelLog.Ln; 
	str := FI.GetCopyrightMessage();
	KernelLog.String("FreeImage Copyright Message: "); KernelLog.String(str^); KernelLog.Ln; 
	
	(* Print input formats (including external plugins) known by the library *)
	KernelLog.String('================================='); KernelLog.Ln;
	KernelLog.String('=== Supported image reading formats ===='); KernelLog.Ln;
	KernelLog.String('================================='); KernelLog.Ln;
	count :=  FI.GetFIFCount();
	IF count > 0 THEN 
		KernelLog.String("FORMAT;   DESCRIPTION;   EXTENSIONS;   ICC PROFILES"); KernelLog.Ln; 		
	END;	
	
	FOR fif := 0 TO count - 1 DO
		IF FI.FIFSupportsReading(fif) THEN
			format := FI.GetFormatFromFIF(fif);
			description := FI.GetFIFDescription(fif);			
			ext := FI.GetFIFExtensionList(fif);
			icc := "*";
			IF FI.FIFSupportsICCProfiles(fif) THEN
				KernelLog.String(format^); KernelLog.String(":           "); 
				KernelLog.String(description^); KernelLog.String(";          ");
				KernelLog.String(ext^); KernelLog.Char(";");
				KernelLog.Char(icc); KernelLog.Ln; 
			ELSE
				KernelLog.String(format^); KernelLog.String(":            "); 
				KernelLog.String(description^); KernelLog.String(";          ");
				KernelLog.String(ext^); KernelLog.Char(";"); KernelLog.Ln; 
			END;	
		END
	END;

	(* Print output formats (including plugins) known by the library
	 for each export format, supported bitdepths are given *)
	 
	KernelLog.String('================================='); KernelLog.Ln;
	KernelLog.String('=== Supported image export formats ===='); KernelLog.Ln;
	IF count > 0 THEN 
		KernelLog.String("FORMAT;  DESCRIPTION;  EXTENSIONS;  ICC PROFILES"); KernelLog.Ln; 
	END;	
	
	FOR fif := 0 TO count - 1 DO

		IF FI.FIFSupportsWriting(fif) THEN
			format := FI.GetFormatFromFIF(fif);
			description := FI.GetFIFDescription(fif);
			ext := FI.GetFIFExtensionList(fif);
			icc := "*";
			KernelLog.String(format^); KernelLog.String(":          ");
			KernelLog.String(description^); KernelLog.String(";          ");
			KernelLog.String(ext^); KernelLog.Char(";"); 
			IF FI.FIFSupportsExportBPP(fif, 1) THEN KernelLog.String("1 "); END;
			IF FI.FIFSupportsExportBPP(fif, 4) THEN KernelLog.String("4 "); END;
			IF FI.FIFSupportsExportBPP(fif, 8) THEN KernelLog.String("8 "); END;
			IF FI.FIFSupportsExportBPP(fif, 16) THEN KernelLog.String("16 "); END;
			IF FI.FIFSupportsExportBPP(fif, 24) THEN KernelLog.String("24 "); END;
			IF FI.FIFSupportsExportBPP(fif, 32) THEN KernelLog.String("32 "); END;
			IF FI.FIFSupportsICCProfiles(fif) THEN
				KernelLog.Char(";"); KernelLog.Char(icc); 
			ELSE
				KernelLog.String(";"); 
			END;

			KernelLog.Ln; 
		END
	END	
END GetFormats;
	
(** load and image and show it *)
PROCEDURE Open*(context: Commands.Context);
VAR fname: ARRAY 128 OF CHAR;
	tdib, dib: FIBITMAP;
	pw: PicView;
	img: WMGraphics.Image;
	w, h, i, j, Bpp: LONGINT;
	bits: ADDRESS;
	pix: Raster.Pixel;
	mode: Raster.Mode;
	res: BOOLEAN;
	pp: PicPanel;
BEGIN
	context.arg.SkipWhitespace();
	IF ~context.arg.GetString(fname) THEN RETURN END;
	tdib := FI.LoadImage(fname, 0);
	IF tdib # NIL THEN
			
	(*	KernelLog.String("FI.GetBPP(tdib)= "); KernelLog.Int(FI.GetBPP(tdib), 0); KernelLog.Ln; 
		KernelLog.String("FI.GetWidth(tdib)= "); KernelLog.Int(FI.GetWidth(tdib), 0); KernelLog.Ln; 
		KernelLog.String("FI.GetHeight(tdib)= "); KernelLog.Int(FI.GetHeight(tdib), 0); KernelLog.Ln; 
	*)		
		IF FI.GetBPP(tdib) # 32 THEN 
			dib := FI.ConvertTo32Bits(tdib); 
			FI.Unload(tdib);
			tdib := dib
		END;
		
		res := FI.FlipVertical(tdib);

		w := FI.GetWidth(tdib); h := FI.GetHeight(tdib);
		Bpp := FI.GetBPP(tdib);
	
		NEW(img);
		Raster.Create(img, w, h, Raster.BGRA8888); (* 32 bitpp *) 
	(*	Raster.Create(img, w, h, Raster.BGR888); (* 24 bitpp *) *)
	
		bits := FI.GetBits(tdib);
		
		SYSTEM.MOVE(bits, img.adr, w*h*(Bpp DIV 8));
	
		(*
		Raster.InitMode(mode,  Raster.srcCopy);
		FOR j:=0 TO h-1 DO
			FOR i :=0 TO w-1 DO
				GetPixel32(tdib, i, h-j-1, pix);
				Raster.Put(img, i, j, pix, mode);
			END;
		END;
		*)
		FI.Unload(tdib);
	
		(* show in WMWindow *)
	(*	NEW(pw, img.width, img.height);
		pw.SetImage(img, fname);
*)
		NEW(pp, 600, 600);
		pp.SetImage(img, fname);
		KernelLog.String("Open Ok."); KernelLog.Ln; 
	END;	
END Open;

(** load an HDR format image and show it *)
PROCEDURE OpenHDR*(context: Commands.Context);
VAR fname: ARRAY 128 OF CHAR;
	tdib, dib: FIBITMAP;
	pw: PicView;
	img: WMGraphics.Image;
	w, h, i, j, Bpp: LONGINT;
	bits: ADDRESS;
	pix: Raster.Pixel;
	mode: Raster.Mode;
	res: BOOLEAN;
BEGIN
	context.arg.SkipWhitespace();
	IF ~context.arg.GetString(fname) THEN RETURN END;
	tdib := FI.Load(FI.FIF_HDR, fname, 0);
	IF tdib # NIL THEN
	
	(*	KernelLog.String("FI.GetBPP(tdib)= "); KernelLog.Int(FI.GetBPP(tdib), 0); KernelLog.Ln; 
		KernelLog.String("FI.GetWidth(tdib)= "); KernelLog.Int(FI.GetWidth(tdib), 0); KernelLog.Ln; 
		KernelLog.String("FI.GetHeight(tdib)= "); KernelLog.Int(FI.GetHeight(tdib), 0); KernelLog.Ln; 
	*)	
		(* dib := FI.ToneMapping(tdib, FI.FITMO_DRAGO03, 0.0, 0.0); *)
(*		dib := FI.ToneMapping(tdib, FI.FITMO_FATTAL02, 0.0, 0.0); *)
		dib := FI.ToneMapping(tdib, FI.FITMO_REINHARD05, 0.0, 0.0); 

		(* dib := FI.TmoReinhard05(tdib, 0.5, 1.0);  *)
		FI.Unload(tdib);		
		res := FI.FlipVertical(dib);
		tdib := dib;

		w := FI.GetWidth(tdib); h := FI.GetHeight(tdib);
		Bpp := FI.GetBPP(tdib);
	
		NEW(img);
		(*	Raster.Create(img, w, h, Raster.BGRA8888); (* 32 bitpp *) *)
		Raster.Create(img, w, h, Raster.BGR888); (* 24 bitpp *)
	
		bits := FI.GetBits(tdib);
		SYSTEM.MOVE(bits, img.adr, w*h*(Bpp DIV 8));
	
		(*
		Raster.InitMode(mode,  Raster.srcCopy);
		FOR j:=0 TO h-1 DO
			FOR i :=0 TO w-1 DO
				GetPixel32(tdib, i, h-j-1, pix);
				Raster.Put(img, i, j, pix, mode);
			END;
		END;
		*)
		FI.Unload(tdib);
	
		NEW(pw, img.width, img.height);
		pw.SetImage(img, fname);

		KernelLog.String("OpenHDR Ok."); KernelLog.Ln; 
	END;	
END OpenHDR;

(** load an image using WMGraphics and save it as jpg using FreeImage *)
PROCEDURE SaveJPG*(context: Commands.Context);
VAR fname: ARRAY 128 OF CHAR;
	tdib: FIBITMAP;
	img: Raster.Image;
	w, h, i, j: LONGINT;
	pix: Raster.Pixel;
	mode: Raster.Mode;
BEGIN
	IF ~context.arg.GetString(fname) THEN RETURN END;
	img := WMGraphics.LoadImage(fname, FALSE );	
	IF img = NIL THEN RETURN END;	
	
	w := img.width; h := img.height;
	
	
	tdib := FI.Allocate(w, h, 24, 0, 0, 0);
	
	IF tdib = NIL THEN RETURN END; 

			
	Raster.InitMode(mode,  Raster.srcCopy);
	
	FOR j:=0 TO h-1 DO
		FOR i :=0 TO w-1 DO
			Raster.Get(img, i, j, pix, mode);
			FIUtils.PutPixel24(tdib, i, h-j-1, pix);
		END;
	END;
	
	Strings.Append(fname, ".jpg");
	IF FI.SaveImage(tdib, fname, 0) THEN
		KernelLog.String(fname); KernelLog.String(" is saved"); KernelLog.Ln; 
	ELSE
		KernelLog.String(fname); KernelLog.String(" is NOT saved"); KernelLog.Ln; 
	END;
	FI.Unload(tdib);

END SaveJPG;

(* Make fresnel lens pattern image and save it, adapted from FreeImage source distribution *)
PROCEDURE MakeFresnel*;
VAR 
	im: FI.FIBITMAP;

	w, h, scale: LONGINT;
	sinTab: ARRAY 256 OF CHAR;

	i, j, x, y: LONGINT;
	cX, cY, d: LONGINT;
	pal: FI.PtrPALETTE;			
	imgbits: ADDRESS;
			
BEGIN
	w := 512; h := 512;
	(* allocate 8 bit dib *)
	im := FI.Allocate(w, h, 8, 0, 0, 0);
	IF im = NIL THEN
		KernelLog.String('Error in Allocate '); KernelLog.Ln;
		RETURN
	END;

	(* build a gray scale palette *)
	pal := FI.GetPalette(im);
	FOR i := 0 TO 255 DO
		pal[i].rgbRed := CHR(i);
		pal[i].rgbGreen := CHR(i);
		pal[i].rgbBlue := CHR(i);
		pal[i].rgbReserved := CHR(i);
	END;

	(* build the sinus table *)
	FOR i := 0 TO 255 DO
		sinTab[i] := CHR(ENTIER((127.5 * Math.sin(Math.pi * (i - 127.5) / 127.5) + 127.5)))
	END;

	cX := w DIV 2;
	cY := h DIV 2;

	(* Create a zone plate *)
	i := h - 1;
	y := - cY;
	scale := 256;

	WHILE i >= 0 DO
		imgbits := FI.GetScanLine(im, i);
		j := w - 1;
		x := - cX;
		WHILE j >= 0 DO
			d := SHORT(ENTIER(((x * x + y * y) / scale) * 255));
			SYSTEM.PUT(imgbits, sinTab[d MOD 256 ]);
			INC(x);
			DEC(j);
			INC(imgbits);
		END;
		INC(y);
		DEC(i)
	END;

	IF FI.SaveImage(im, "freefresel.png",0) THEN
		KernelLog.String("Make Fresnel Ok."); KernelLog.Ln; 
	END;

	FI.Unload(im);
	
END MakeFresnel;
	

BEGIN

END TestFreeImage.


TestFreeImage.Open E:/WinAosSvn/WinAos/Work/EarthMap.png  ~

TestFreeImage.Open "E:/WinAosSvn/WinAos/Work/earth_rectangular_04.jpg" ~


TestFreeImage.OpenHDR E:/WinAosSvn/WinAos/Work/test8_Ref.hdr ~
TestFreeImage.OpenHDR FreeImage/campus_probe.hdr ~

TestFreeImage.Open ./s3010027.jpg ~ 
./s3010027.jpg
sel1.jpg ~ 

TestFreeImage.Open E:/WinAosSvn/WinAos/Work/IMG_20130714_172908.jpg ~

TestFreeImage.Open  DSC_7163.JPG ~

E:/WinAosSvn/WinAos/Work/IMG_20130714_172908.jpg
E:/WinAosSvn/source/Clouds.jp2 ~


E:/WinAosSvn/WinAos/Work/EarthMap.png
TestFreeImage.Open E:/WinAosSvn/source/Rainbow.jp2 ~ 

E:/WinAosSvn/source/Rainbow.jp2
E:/WinAosSvn/source/Rainbow.jp2

TestFreeImage.SaveJPG  "Seashore2.png" ~

TestFreeImage.GetFormats ~

TestFreeImage.MakeFresnel ~ 


DSC_7713.JPG
DSC_7713.NEF

SystemTools.Free TestFreeImage  FreeImageUtils FreeImageDll~

SystemTools.FreeDownTo FreeImageDll ~ 
