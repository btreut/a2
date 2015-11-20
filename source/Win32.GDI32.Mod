(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE GDI32;  (** non-portable / source: Win32.GDI32.Mod *)	(* ejz *)
IMPORT SYSTEM, Kernel32, User32;

	(** This module defines all the Win32 GDI32 APIs used by Oberon.
	Note this module is part of the Oberon inner-core and must be linked with PELinker. *)

CONST
	(** SetBkMode iBkMode values *)
	Transparent* = 1;  Opaque* = 2;
	(** BitBlt/PatBlt dwRop values *)
	PatCopy* = 0F00021H;  PatInvert* = 05A0049H;  DstInvert* = 0550009H;
	SrcInvert* = 0660046H;  SrcCopy* = 0CC0020H;  SrcPaint* = 0EE0086H;  SrcAnd* = 08800C6H;  NotSrcCopy* = 0330008H;
	(** GetDeviceCaps nIndex values *)
	HorzRes* = 8;  VertRes* = 10;  BitsPixel* = 12;  LogPixelsX* = 88;  LogPixelsY* = 90;
	PhysicalWidth* = 110;  PhysicalHeight* = 111;  PhysicalOffsetX* = 112;  PhysicalOffsetY* = 113;
	(** SetROP2 fnDrawMode values *)
	R2NotCopyPen* = 4;  R2Not* = 6;  R2NotXOrPen* = 10;  R2Nop* = 11;  R2CopyPen* = 13;
	(** CreatePen  fnPenStyle values *)
	PSSolid* = 0;
	(** GetStockObject fnObject values *)
	NullBrush* = 5;  NullPen* = 8;
	(** LogFont/EnumLogFont face name lengths *)
	LFFaceSize* = 32;  LFFullFaceSize* = 64;
	(** LogFont lfWeight values *)
	FWThin* = 100;  FWLight* = 300;  FWNormal* = 400;  FWMedium* = 500;  FWBold* = 700;
	(** EnumFontFamilies FontType values *)
	RasterFontType* = 0;  TrueTypeFontType* = 2;
	(** BitmapInfo biCompression values *)
	BIRGB* = 0;
	(** GetDIBits/SetDIBitsToDevice/StretchDIBits uUsage/fuColorUse/iUsage values *)
	DIBRGBColors* = 0;  DIBPalColors* = 1;
	(** GetMapMode/SetMapMode fnMapMode values *)
	MMText* = 1;  MMTwips* = 6;
	(** SetTextAlign fMode values *)
	TALeft* = {};  TABaseline* = {3, 4};
	(** GetGlyphOutline uFormat values *)
	GGOMetrics* = 0;  GGOBitmap* = 1;  GGONative* = 2;  GGOGray2Bitmap* = 4;  GGOGray4Bitmap* = 5;  GGOGray8Bitmap* = 6;
	(** ExtSelectClipRgn fnMode values *)
	RgnAnd* = 1;  RgnOr* = 2;  RgnXOr* = 3;  RgnDiff* = 4;  RgnCopy* = 5;

	NullRegion* = 1;  SimpleRegion* = 2;  ComplexRegion* = 3;

	RDHRectangles* = 1;

TYPE
	(** handle types for different gdi objects *)
	HGDIObj* = User32.HGDIObj;
	HFont* = User32.HFont;
	HBrush* = User32.HBrush;
	HRgn* = User32.HRgn;
	HBitmap* = User32.HBitmap;
	HPen* = HGDIObj;
	HMetafile* = HGDIObj;
	HEnhMetafile* = HGDIObj;

	(** The COLORREF value is used to specify an RGB color. *)
	ColorRef* = User32.ColorRef;

	(** The LOGFONT structure defines the attributes of a font. *)
	LogFont* = RECORD
		lfHeight*, lfWidth*, lfEscapement*, lfOrientation*, lfWeight*: LONGINT;
		lfItalic*, lfUnderline*, lfStrikeOut*: BOOLEAN;
		lfCharSet*, lfOutPrecision*, lfClipPrecision*, lfQuality*, lfPitchAndFamily*: SHORTINT;
		lfFaceName*: ARRAY LFFaceSize OF CHAR
	END;

	(** The ENUMLOGFONT structure defines the attributes of a font, the complete name of a font, and the style of a font. *)
	EnumLogFont* = RECORD
		elfLogFont*: LogFont;
		elfFullName*: ARRAY LFFullFaceSize OF CHAR;
		elfStyle*: ARRAY LFFaceSize OF CHAR
	END;

	(** The TEXTMETRIC structure contains basic information about a physical font. *)
	TextMetric* = RECORD
		tmHeight*, tmAscent*, tmDescent*, tmInternalLeading*, tmExternalLeading*: LONGINT;
		tmAveCharWidth*, tmMaxCharWidth*, tmWeight*, tmOverhang*: LONGINT;
		tmDigitizedAspectX*, tmDigitizedAspectY*: LONGINT;
		tmFirstChar*, tmLastChar*, tmDefaultChar*, tmBreakChar*: CHAR;
		tmItalic*, tmUnderlined*, tmStruckOut*: BOOLEAN;
		tmPitchAndFamily*, tmCharSet*: SHORTINT
	END;

	(** The EnumFontFamProc function is an application definedßcallback function used with the EnumFontFamilies
			function. *)
	EnumFontFamProc* = PROCEDURE {WINAPI} (VAR lpelf: EnumLogFont;  VAR lpntm: TextMetric;  FontType: SET;  lParam: User32.LParam): LONGINT;

	(** The EnumFontsProc function is an application definedßcallback function that processes font data from the EnumFonts
			function. *)
	EnumFontsProc* = PROCEDURE {WINAPI} (VAR lplf: LogFont;  VAR lptm: TextMetric;  dwType: SET;  lpData: User32.LParam): LONGINT;

	(** The ABC structure contains the width of a character in a TrueType font. *)
	ABC* = RECORD
		abcA*, abcB*, abcC*: LONGINT
	END;

	(** The BITMAPINFOHEADER structure contains information about the dimensions and color format of a DIB. *)
	BitmapInfoHeader* = RECORD
		biSize*, biWidth*, biHeight*: LONGINT;
		biPlanes*, biBitCount*: INTEGER;
		biCompression*, biSizeImage*: LONGINT;
		biXPelsPerMeter*, biYPelsPerMeter*: LONGINT;
		biClrUsed*, biClrImportant*: LONGINT
	END;

	(** The BITMAPINFO structure defines the dimensions and color information for a Win32 DIB. *)
	BitmapInfo* = RECORD
		bmiHeader*: BitmapInfoHeader;
	END;

	(** The DOCINFO structure contains the input and output file names and other information used by the StartDoc
			function. *)
	DocInfo* = RECORD
		cbSize*: LONGINT;
		lpszDocName*, lpszOutput*, lpszDatatype*: Kernel32.LPSTR;
		fwType*: LONGINT
	END;

	(** The PALETTEENTRY structure specifies the color and usage of an entry in a logical palette. *)
	PaletteEntry* = RECORD
		peRed*, peGreen*, peBlue*, peFlags*: CHAR
	END;

	(** The LOGPALETTE structure defines a logical palette. *)
	LogPalette* = RECORD
		palVersion*, palNumEntries*: INTEGER;
		palPalEntry*: ARRAY 1 OF PaletteEntry
	END;

	(** The GLYPHMETRICS structure contains information about the placement and orientation of a glyph in a character
			cell. *)
	GlyphMetrics* = RECORD
		gmBlackBoxX*, gmBlackBoxY*: LONGINT;
		gmptGlyphOrigin*: User32.Point;
		gmCellIncX*, gmCellIncY*: INTEGER
	END;

	(** The FIXED structure contains the integral and fractional parts of a fixed-point real number. *)
	Fixed* = RECORD
		fract*, value*: INTEGER
	END;

	(** The MAT2 structure contains the values for a transformation matrix used by the GetGlyphOutline function. *)
	Mat2* = RECORD
		eM11*, eM12*: Fixed;
		eM21*, eM22*: Fixed
	END;

	RgnDataHeader* = RECORD
		dwSize*, iType*, nCount*, nRgnSize*: LONGINT;
		rcBound*: User32.Rect
	END;

VAR
	(** The AddFontResource function adds the font resource from the specified file to the system font table. *)
	AddFontResource-: PROCEDURE {WINAPI} (VAR lpszFilename: ARRAY   OF CHAR): LONGINT;
	(** The BitBlt function performs a bit-block transfer of the color data corresponding to a rectangle of pixels from the
			specified source device context into a destination device context. *)
	BitBlt-: PROCEDURE {WINAPI} (hdcDest: User32.HDC;  nXDest, nYDest, nWidth, nHeight: LONGINT;  hdcSrc: User32.HDC;  nXSrc, nYSrc, dwRop: LONGINT): Kernel32.BOOL;
	(** The CloseEnhMetaFile function closes an enhanced-metafile device context and returns a handle that identifies an
			enhanced-format metafile. *)
	CloseEnhMetaFile-: PROCEDURE {WINAPI} (hdc: User32.HDC): HEnhMetafile;
	(** The CloseMetaFile function closes a metafile device context and returns a handle that identifies a Windows-format
			metafile. *)
	CloseMetaFile-: PROCEDURE {WINAPI} (hdc: User32.HDC): HMetafile;
	(** The CreateBitmap function creates a bitmap with the specified width, height, and color format
			(color planes and bits-per-pixel). *)
	CreateBitmap-: PROCEDURE {WINAPI} (nWidth, nHeight, cPlanes, cBitsPerPixel: LONGINT;  VAR lpvBits: ARRAY   OF SYSTEM.BYTE): HBitmap;
	(** The CreateCompatibleBitmap function creates a bitmap compatible with the device that is associated with the
			specified device context. *)
	CreateCompatibleBitmap-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nWidth, nHeight: LONGINT): HBitmap;
	(** The CreateCompatibleDC function creates a memory device context (DC) compatible with the specified device. *)
	CreateCompatibleDC-: PROCEDURE {WINAPI} (hdc: User32.HDC): User32.HDC;
	(** The CreateDC function creates a device context (DC) for a device by using the specified name. *)
	CreateDC-: PROCEDURE {WINAPI} (VAR lpszDriver, lpszDevice, lpszOuput: ARRAY   OF CHAR;  lpInitData: ANY): User32.HDC;
(**	The CreateDIBSection function creates a DIB that applications can write to directly. The function gives you a pointer to the location of the bitmap bit values. You can supply a handle to a file-mapping object that the function will use to create the bitmap, or you can let the system allocate the memory for the bitmap.
*) 	CreateDIBSection-: PROCEDURE {WINAPI} (hdc: User32.HDC; 	VAR lpbi: BitmapInfo; iUsage:LONGINT; VAR adr: LONGINT; hSection: LONGINT;
dwOffset: LONGINT):HBitmap;
	(** The CreateEnhMetaFile function creates a device context for an enhanced-format metafile. *)
	CreateEnhMetaFile-: PROCEDURE {WINAPI} (VAR hdcRef: User32.HDC;  VAR lpFilename: ARRAY   OF CHAR;  VAR lpRect: User32.Rect; VAR  lpDescription: ARRAY   OF CHAR): User32.HDC;
	(** The CreateFontIndirect function creates a logical font that has the specified characteristics. *)
	CreateFontIndirect-: PROCEDURE {WINAPI} (VAR lplf: LogFont): HFont;
	(** The CreateHatchBrush function creates a logical brush that has the specified hatch pattern and color. *)
	CreateHatchBrush-: PROCEDURE {WINAPI} (fnStyle: LONGINT;  clrref: ColorRef): HBrush;
	(** The CreateMetaFile function creates a device context for a Windows-format metafile. *)
	CreateMetaFile-: PROCEDURE {WINAPI} (VAR lpszFile: ARRAY   OF CHAR): User32.HDC;
	(** The CreatePatternBrush function creates a logical brush with the specified bitmap pattern. *)
	CreatePatternBrush-: PROCEDURE {WINAPI} (hbmp: HBitmap): HBrush;
	(** The CreatePen function creates a logical pen that has the specified style, width, and color. *)
	CreatePen-: PROCEDURE {WINAPI} (fnPenStyle, nWidth: LONGINT;  crColor: ColorRef): HPen;
	(** The CreateSolidBrush function creates a logical brush that has the specified solid color. *)
	CreateSolidBrush-: PROCEDURE {WINAPI} (crColor: ColorRef): HBrush;
	(** The CreateRectRgn function creates a rectangular region. *)
	CreateRectRgn-: PROCEDURE {WINAPI} (nLeftRect, nTopRect, nRightRect, nBottomRect: LONGINT): HRgn;
	(** The CreateRectRgnIndirect function creates a rectangular region. *)
	CreateRectRgnIndirect-: PROCEDURE {WINAPI} (lprc: User32.Rect): HRgn;
	(** The DeleteDC function deletes the specified device context (DC). *)
	DeleteDC-: PROCEDURE {WINAPI} (hdc: User32.HDC): Kernel32.BOOL;
	(** The DeleteObject function deletes a logical pen, brush, font, bitmap, region, or palette, freeing all system
			resources associated with the object. *)
	DeleteObject-: PROCEDURE {WINAPI} (hObject: HGDIObj): Kernel32.BOOL;
	(** The DPtoLP function converts device coordinates into logical coordinates. *)
	DPtoLP-: PROCEDURE {WINAPI} (hdc: User32.HDC; VAR  lpPoints: ARRAY   OF User32.Point;  nCount: LONGINT): Kernel32.BOOL;
	(** The Ellipse function draws an ellipse. *)
	Ellipse-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nLeftRect, nTopRect, nRightRect, nBottomRect: LONGINT): Kernel32.BOOL;
	(** The EndDoc function ends a print job. *)
	EndDoc-: PROCEDURE {WINAPI} (hdc: User32.HDC): LONGINT;
	(** The EndPage function informs the device that the application has finished writing to a page. *)
	EndPage-: PROCEDURE {WINAPI} (hdc: User32.HDC): LONGINT;
	(** The EnumFontFamilies function enumerates the fonts in a specified font family that are available on a specified
			device. *)
	EnumFontFamilies-: PROCEDURE {WINAPI} (hdc: User32.HDC;  VAR lpszFamily: ARRAY   OF CHAR;  lpEnumFontFamProc: EnumFontFamProc;  lParam: User32.LParam): LONGINT;
	(** The EnumFonts function enumerates the fonts available on a specified device. *)
	EnumFonts-: PROCEDURE {WINAPI} (hdc: User32.HDC;  VAR lpFaceName: ARRAY   OF CHAR;  lpFontFunc: EnumFontsProc;  lParam: User32.LParam): LONGINT;
	(** The ExtSelectClipRgn function combines the specified region with the current clipping region by using the
			specified mode. *)
	ExtSelectClipRgn-: PROCEDURE {WINAPI} (hdc: User32.HDC;  hrgn: HRgn;  fnMode: LONGINT): LONGINT;
	(** The GdiFlush function flushes the calling thread's current batch. *)
	GdiFlush-: PROCEDURE {WINAPI} (): Kernel32.BOOL;
	(** The GetBitmapBits function copies the bitmap bits of a specified bitmap into a buffer. *)
	GetBitmapBits-: PROCEDURE {WINAPI} (hbmp: HBitmap;  cbBuffer: LONGINT;  lpvBits: ADDRESS): LONGINT;
	(** The GetCharABCWidths function retrieves the widths, in logical units, of consecutive characters in a specified range
			from the current TrueType font. *)
	GetCharABCWidths-: PROCEDURE {WINAPI} (hdc: User32.HDC;  uFirstChar, uLastChar: LONGINT;  VAR lpabc: ABC): Kernel32.BOOL;
	(** The GetCharWidth32 function retrieves the widths, in logical coordinates, of consecutive characters in a specified
			range from the current font. *)
	GetCharWidth32-: PROCEDURE {WINAPI} (hdc: User32.HDC;  iFirstChar, iLastChar: LONGINT;  VAR lpBuffer: ARRAY   OF LONGINT): Kernel32.BOOL;
	(** The GetClipBox function retrieves the dimensions of the tightest bounding rectangle that can be
			drawn around the current visible area on the device. *)
	GetClipBox-: PROCEDURE {WINAPI} (hdc: User32.HDC;  VAR lprc: User32.Rect): LONGINT;
	(** The GetClipRgn function retrieves a handle identifying the current application-defined clipping
			region for the specified device context. *)
	GetClipRgn-: PROCEDURE {WINAPI} (hdc: User32.HDC;  hrgn: HRgn): LONGINT;
	(** The GetDeviceCaps function retrieves device-specific information about the specified device. *)
	GetDeviceCaps-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nIndex: LONGINT): LONGINT;
	(** The GetDIBits function retrieves the bits of the specified bitmap and copies them into a buffer using the specified
			format. *)
	GetDIBits-: PROCEDURE {WINAPI} (hdc: User32.HDC;  hbmp: HBitmap;  uStartScanLine, cScanLines: LONGINT;  lpvBits: ADDRESS;  VAR lpbi: BitmapInfo;  uUsage: LONGINT): LONGINT;
	(** The GetGlyphOutline function retrieves the outline or bitmap for a character in the TrueType font that is selected
			into the specified device context. *)
	GetGlyphOutline-: PROCEDURE {WINAPI} (hdc: User32.HDC;  uChar, uFormat: LONGINT;  lpgm: GlyphMetrics;  cbBuffer: LONGINT;  VAR lpvBuffer: ARRAY   OF SYSTEM.BYTE;  lpmat2: Mat2): LONGINT;
	(** The GetMapMode function retrieves the current mapping mode. *)
	GetMapMode-: PROCEDURE {WINAPI} (hdc: User32.HDC): LONGINT;
	(** The GetNearestColor function retrieves a color value identifying a color from the system palette that
			will be displayed when the specified color value is used. *)
	GetNearestColor-: PROCEDURE {WINAPI} (hdc: User32.HDC;  crColor: ColorRef): ColorRef;
	(** The GetRegionData function fills the specified buffer with data describing a region. *)
	GetRegionData-: PROCEDURE {WINAPI} (hRgn: HRgn;  dwCount: LONGINT;  VAR lpRgnData: RgnDataHeader): LONGINT;
	(** The GetStockObject function retrieves a handle to one of the stock pens, brushes, fonts, or palettes. *)
	GetStockObject-: PROCEDURE {WINAPI} (fnObject: LONGINT): HGDIObj;
	(** The GetSystemPaletteEntries function retrieves a range of palette entries from the system palette that is associated
			with the specified device context (DC). *)
	GetSystemPaletteEntries-: PROCEDURE {WINAPI} (hdc: User32.HDC;  iStartIndex, nEntries: LONGINT;  VAR lppe: ARRAY   OF PaletteEntry): LONGINT;
	(** The GetTextExtentPoint function computes the width and height of the specified string of text. *)
	GetTextExtentPoint-: PROCEDURE {WINAPI} (hDC: User32.HDC;  VAR lpString: ARRAY   OF CHAR;  cbString: LONGINT;  VAR lpSize: User32.Size): Kernel32.BOOL;
	(** The GetTextMetrics function fills the specified buffer with the metrics for the currently selected font. *)
	GetTextMetrics-: PROCEDURE {WINAPI} (hDC: User32.HDC;  VAR lptm: TextMetric): Kernel32.BOOL;
	(** The IntersectClipRect function creates a new clipping region from the intersection of the current clipping region
			and the specified rectangle. *)
	IntersectClipRect-: PROCEDURE {WINAPI} (hDC: User32.HDC;  nLeftRect, nTopRect, nRightRect, nBottomRect: LONGINT): LONGINT;
	(** The LineTo function draws a line from the current position up to, but not including, the specified point. *)
	LineTo-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nXEnd, nYEnd: LONGINT): Kernel32.BOOL;
	(** The LPtoDP function converts logical coordinates into device coordinates. *)
	LPtoDP-: PROCEDURE {WINAPI} (hdc: User32.HDC;  VAR lpPoints: ARRAY   OF User32.Point;  nCount: LONGINT): Kernel32.BOOL;
	(** The MoveToEx function updates the current position to the specified point and optionally returns the previous
			position. *)
	MoveToEx-: PROCEDURE {WINAPI} (hdc: User32.HDC;  X, Y: LONGINT;  VAR lpPoint: User32.Rect): Kernel32.BOOL;
	(** The PatBlt function paints the specified rectangle using the brush that is currently selected into the specified device
			context. *)
	PatBlt-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nXLeft, nLeft, nWidth, nHeight, dwRop: LONGINT): Kernel32.BOOL;
	(** The PlayEnhMetaFile function displays the picture stored in the specified enhanced-format metafile. *)
	PlayEnhMetaFile-: PROCEDURE {WINAPI} (hdc: User32.HDC;  hemf: HEnhMetafile;  lpRect: User32.Rect): Kernel32.BOOL;
	(** The PlayMetaFile function displays the picture stored in the given Windows-format metafile on the specified device. *)
	PlayMetaFile-: PROCEDURE {WINAPI} (hdc: User32.HDC;  hmf: HMetafile): Kernel32.BOOL;
	(** The Rectangle function draws a rectangle. *)
	Rectangle-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nLeftRect, nTopRect, nRightRect, nBottomRect: LONGINT): Kernel32.BOOL;
	(** The RemoveFontResource function removes the fonts in the specified file from the system font table. *)
	RemoveFontResource-: PROCEDURE {WINAPI} (VAR lpFileName: ARRAY   OF CHAR): Kernel32.BOOL;
	(** The RestoreDC function restores a device context (DC) to the specified state. *)
	RestoreDC-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nSavedDC: LONGINT): Kernel32.BOOL;
	(** The SaveDC function saves the current state of the specified device context (DC) by copying data describing selected
			objects and graphic modes (such as the bitmap, brush, palette, font, pen, region, drawing mode, and mapping mode)
			to a context stack. *)
	SaveDC-: PROCEDURE {WINAPI} (hdc: User32.HDC): LONGINT;
	(** The SelectClipRgn function selects a region as the current clipping region for the specified device context. *)
	SelectClipRgn-: PROCEDURE {WINAPI} (hdc: User32.HDC;  hrgn: HRgn): LONGINT;
	(** The SelectObject function selects an object into the specified device context (DC). *)
	SelectObject-: PROCEDURE {WINAPI} (hdc: User32.HDC;  hgdiobj: HGDIObj): HGDIObj;
	(** The SetBkColor function sets the current background color to the specified color value, or to the nearest physical
			color if the device cannot represent the specified color value. *)
	SetBkColor-: PROCEDURE {WINAPI} (hdc: User32.HDC;  crColor: ColorRef): ColorRef;
	(** The SetBkMode function sets the background mix mode of the specified device context. *)
	SetBkMode-: PROCEDURE {WINAPI} (hdc: User32.HDC;  iBkMode: LONGINT): LONGINT;
	(** The SetBrushOrgEx function sets the brush origin that GDI assigns to the next brush an application selects into the
			specified device context. *)
	SetBrushOrgEx-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nXOrg, nYOrg: LONGINT;  VAR lppt: User32.Point): Kernel32.BOOL;
	(** The SetDIBitsToDevice function sets the pixels in the specified rectangle on the device that is associated with the
			destination device context using color data from a DIB. *)
	SetDIBitsToDevice-: PROCEDURE {WINAPI} (hdc: User32.HDC;  XDest, YDest, dwWidth, dwHeight, XSrc, YSrc, uStartScan, cScanLines: LONGINT;
	lpvBits: ADDRESS;  VAR lpbmi: BitmapInfo;  fuColorUse: LONGINT): LONGINT;
	(** The SetMapMode function sets the mapping mode of the specified device context. *)
	SetMapMode-: PROCEDURE {WINAPI} (hdc: User32.HDC;  fnMapMode: LONGINT): LONGINT;
	(** The SetROP2 function sets the current foreground mix mode. *)
	SetROP2-: PROCEDURE {WINAPI} (hdc: User32.HDC;  fnDrawMode: LONGINT): LONGINT;
	(** The SetTextAlign function sets the text-alignment flags for the specified device context. *)
	SetTextAlign-: PROCEDURE {WINAPI} (hdc: User32.HDC;  fMode: SET): LONGINT;
	(** The SetTextColor function sets the text color for the specified device context to the specified color. *)
	SetTextColor-: PROCEDURE {WINAPI} (hdc: User32.HDC;  crColor: ColorRef): ColorRef;
	(** The SetWindowExtEx function sets the horizontal and vertical extents of the window for a device context by using
			the specified values. *)
	SetWindowExtEx-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nXExtent, nYExtent: LONGINT;  VAR lpSize: User32.Size): Kernel32.BOOL;
	(** The SetWindowOrgEx function specifies which window point maps to the viewport origin (0,0). *)
	SetWindowOrgEx-: PROCEDURE {WINAPI} (hdc: User32.HDC;  X, Y: LONGINT;  VAR lpPoint: User32.Point): Kernel32.BOOL;
	(** The StartDoc function starts a print job. *)
	StartDoc-: PROCEDURE {WINAPI} (hdc: User32.HDC;  VAR lpdi: DocInfo): LONGINT;
	(** The StartPage function prepares the printer driver to accept data. *)
	StartPage-: PROCEDURE {WINAPI} (hdc: User32.HDC): LONGINT;
	(** The StretchDIBits function copies the color data for a rectangle of pixels in a DIB to the specified destination
			rectangle. *)
	(** The StretchBlt function copies a bitmap from a source rectangle into a destination rectangle, stretching or
			compressing the bitmap to fit the dimensions of the destination rectangle, if necessary. *)
	StretchBlt-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nXOriginDest, nYOriginDest, nWidthDest, nHeightDest: LONGINT;
	 hdcSrc: User32.HDC;  nXOriginSrc, nYOriginSrc, nWidthSrc, nHeightSrc, dwRop: LONGINT): Kernel32.BOOL;
	StretchDIBits-: PROCEDURE {WINAPI} (hdc: User32.HDC;  XDest, YDest, nDestWidth, nDestHeight, XSrc, YSrc, nSrcWidth, nSrcHeight: LONGINT;
	lpBits: ADDRESS;  VAR lpBitsInfo: BitmapInfo;  iUsage, dwRop: LONGINT): LONGINT;
	(** The TextOut function writes a character string at the specified location, using the currently selected font,
			background color, and text color. *)
	TextOut-: PROCEDURE {WINAPI} (hdc: User32.HDC;  nXStart, nYStart: LONGINT;  VAR lpString: ARRAY   OF CHAR;  cbString: LONGINT): Kernel32.BOOL;
	T-: ARRAY 256 OF CHAR;

	(** RGB selects a red, green, blue (RGB) color based on the arguments supplied. *)
PROCEDURE RGB*(red, green, blue: LONGINT): ColorRef;
BEGIN
	RETURN red + ASH(green, 8) + ASH(blue, 16)
END RGB;

	(** The Red retrieves an intensity value for the red component of a red, green, blue (RGB) value. *)
PROCEDURE Red*(col: ColorRef): LONGINT;
BEGIN
	RETURN col MOD 256
END Red;

	(** The Green retrieves an intensity value for the green component of a red, green, blue (RGB) value. *)
PROCEDURE Green*(col: ColorRef): LONGINT;
BEGIN
	RETURN ASH(col, -8) MOD 256
END Green;

	(** The Blue retrieves an intensity value for the blue component of a red, green, blue (RGB) value. *)
PROCEDURE Blue*(col: ColorRef): LONGINT;
BEGIN
	RETURN ASH(col, -16) MOD 256
END Blue;

PROCEDURE GetProcAddress(hModule: ADDRESS; VAR adr: ADDRESS; procName: ARRAY OF CHAR);
BEGIN
	Kernel32.GetProcAddress(hModule,procName,adr);
END GetProcAddress;


PROCEDURE Init;
VAR i, p, v, x: LONGINT;
 mod: Kernel32.HMODULE; str: ARRAY 32 OF CHAR;
BEGIN
	FOR i := 0 TO 255 DO
		v := i;  x := 0;  p := 128;
		WHILE v > 0 DO
			x := x + p*(v MOD 2);
			p := p DIV 2;  v := v DIV 2
		END;
		T[i] := CHR(255-x)
	END;
	str := "GDI32.DLL";
	mod := Kernel32.LoadLibrary(str);

GetProcAddress(mod,SYSTEM.VAL(ADDRESS,AddFontResource ),"AddFontResourceA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,BitBlt ),"BitBlt");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CloseEnhMetaFile ),"CloseEnhMetaFile");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CloseMetaFile ),"CloseMetaFile");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateBitmap ),"CreateBitmap");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateCompatibleBitmap ),"CreateCompatibleBitmap");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateCompatibleDC ),"CreateCompatibleDC");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateDC ),"CreateDCA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateDIBSection ),"CreateDIBSection");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateEnhMetaFile ),"CreateEnhMetaFileA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateFontIndirect ),"CreateFontIndirectA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateHatchBrush ),"CreateHatchBrush");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateMetaFile ),"CreateMetaFileA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreatePatternBrush ),"CreatePatternBrush");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreatePen ),"CreatePen");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateSolidBrush ),"CreateSolidBrush");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateRectRgn ),"CreateRectRgn");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,CreateRectRgnIndirect ),"CreateRectRgnIndirect");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,DeleteDC ),"DeleteDC");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,DeleteObject ),"DeleteObject");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,DPtoLP ),"DPtoLP");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,Ellipse ),"Ellipse");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,EndDoc ),"EndDoc");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,EndPage ),"EndPage");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,EnumFontFamilies ),"EnumFontFamiliesA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,EnumFonts ),"EnumFontsA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,ExtSelectClipRgn ),"ExtSelectClipRgn");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GdiFlush ),"GdiFlush");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetBitmapBits ),"GetBitmapBits");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetCharABCWidths ),"GetCharABCWidthsA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetCharWidth32 ),"GetCharWidth32A");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetClipBox ),"GetClipBox");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetClipRgn ),"GetClipRgn");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetDeviceCaps ),"GetDeviceCaps");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetDIBits ),"GetDIBits");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetGlyphOutline ),"GetGlyphOutlineA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetMapMode ),"GetMapMode");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetNearestColor ),"GetNearestColor");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetRegionData ),"GetRegionData");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetStockObject ),"GetStockObject");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetSystemPaletteEntries ),"GetSystemPaletteEntries");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetTextExtentPoint ),"GetTextExtentPointA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,GetTextMetrics ),"GetTextMetricsA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,IntersectClipRect ),"IntersectClipRect");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,LineTo ),"LineTo");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,LPtoDP ),"LPtoDP");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,MoveToEx ),"MoveToEx");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,PatBlt ),"PatBlt");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,PlayEnhMetaFile ),"PlayEnhMetaFile");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,PlayMetaFile ),"PlayMetaFile");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,Rectangle ),"Rectangle");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RemoveFontResource ),"RemoveFontResourceA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,RestoreDC ),"RestoreDC");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SaveDC ),"SaveDC");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SelectClipRgn ),"SelectClipRgn");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SelectObject ),"SelectObject");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetBkColor ),"SetBkColor");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetBkMode ),"SetBkMode");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetBrushOrgEx ),"SetBrushOrgEx");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetDIBitsToDevice ),"SetDIBitsToDevice");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetMapMode ),"SetMapMode");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetROP2 ),"SetROP2");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetTextAlign ),"SetTextAlign");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetTextColor ),"SetTextColor");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetWindowExtEx ),"SetWindowExtEx");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,SetWindowOrgEx ),"SetWindowOrgEx");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,StartDoc ),"StartDocA");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,StartPage ),"StartPage");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,StretchBlt ),"StretchBlt");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,StretchDIBits ),"StretchDIBits");
GetProcAddress(mod,SYSTEM.VAL(ADDRESS,TextOut ),"TextOutA");

END Init;
BEGIN
	Init()
END GDI32.