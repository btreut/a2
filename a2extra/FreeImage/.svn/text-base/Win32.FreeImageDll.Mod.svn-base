MODULE FreeImageDll; (** AUTHOR "fnecati"; PURPOSE "FreeImage interface for WinAos"; *)

IMPORT 
	SYSTEM, Kernel32, Strings, Modules, KernelLog;

(* Date:  20-12- 2013 
Wrapper for FreeImage.dll (v3.15.4).
	http://freeimage.sourceforge.net/
*)

(*  Handle, Memory I/O,  Zlib Compression routines are not tested , and, line conversion routines  are not translated yet. *)

CONST
	libname="FreeImage.dll";
VAR 
	lib: LONGINT;
	
CONST
	
(*  Version information ------------------------------------------------------ *)
	MAJOR_VERSION* = 3;
	MINOR_VERSION* = 15;
	RELEASE_SERIAL* = 4;
		
	(* Indexes for byte arrays, masks and shifts for treating pixels as words
	These coincide with the order of RGBQUAD and RGBTRIPLE
	Little Endian (x86 / MS Windows, Linux) : BGR(A) order *)

	FI_RGBA_RED* = 2;
	FI_RGBA_GREEN* = 1;
	FI_RGBA_BLUE* = 0;
	FI_RGBA_ALPHA* = 3;
	FI_RGBA_RED_MASK* = 00FF0000H;
	FI_RGBA_GREEN_MASK* = 0000FF00H;
	FI_RGBA_BLUE_MASK* = 000000FFH;
	FI_RGBA_ALPHA_MASK* = 0FF000000H;
	FI_RGBA_RED_SHIFT* = 16;
	FI_RGBA_GREEN_SHIFT* = 8;
	FI_RGBA_BLUE_SHIFT* = 0;
	FI_RGBA_ALPHA_SHIFT* = 24;

	(* Little Endian (x86 / MaxOSX) : RGB(A) order *)
(*	FI_RGBA_RED* = 0;
	FI_RGBA_GREEN* = 1;
	FI_RGBA_BLUE* = 2;
	FI_RGBA_ALPHA* = 3;
	FI_RGBA_RED_MASK* = 000000FFH;
	FI_RGBA_GREEN_MASK* = 0000FF00H;
	FI_RGBA_BLUE_MASK* = 00FF0000H;
	FI_RGBA_ALPHA_MASK* = 0FF000000H;
	FI_RGBA_RED_SHIFT* = 0;
	FI_RGBA_GREEN_SHIFT* = 8;
	FI_RGBA_BLUE_SHIFT* = 16;
	FI_RGBA_ALPHA_SHIFT* = 24;
*)

	(* --------------------------------------------------------------------------
	The 16bit macros only include masks and shifts,
	since each color element is not byte aligned
	--------------------------------------------------------------------------*)

CONST
	FI16_555_RED_MASK* = 7C00H;
	FI16_555_GREEN_MASK* = 03E0H;
	FI16_555_BLUE_MASK* = 001FH;
	FI16_555_RED_SHIFT* = 10;
	FI16_555_GREEN_SHIFT* = 5;
	FI16_555_BLUE_SHIFT* = 0;
	FI16_565_RED_MASK* = 0F800H;
	FI16_565_GREEN_MASK* = 07E0H;
	FI16_565_BLUE_MASK* = 001FH;
	FI16_565_RED_SHIFT* = 11;
	FI16_565_GREEN_SHIFT* = 5;
	FI16_565_BLUE_SHIFT* = 0;

	(*	ICC profile support *)
CONST
	FIICC_DEFAULT* = 0H;
	FIICC_COLOR_IS_CMYK*	 = 1H;

CONST
	(* I/O image format identifiers. *)
TYPE IMAGE_FORMAT* = LONGINT;
CONST
	FIF_UNKNOWN* = -1;
	FIF_BMP* = 0;
	FIF_ICO* = 1;
	FIF_JPEG* = 2;
	FIF_JNG* = 3;
	FIF_KOALA* = 4;
	FIF_LBM* = 5;
	FIF_IFF* = FIF_LBM;
	FIF_MNG* = 6;
	FIF_PBM* = 7;
	FIF_PBMRAW* = 8;
	FIF_PCD* = 9;
	FIF_PCX* = 10;
	FIF_PGM* = 11;
	FIF_PGMRAW* = 12;
	FIF_PNG* = 13;
	FIF_PPM* = 14;
	FIF_PPMRAW* = 15;
	FIF_RAS* = 16;
	FIF_TARGA* = 17;
	FIF_TIFF* = 18;
	FIF_WBMP* = 19;
	FIF_PSD* = 20;
	FIF_CUT* = 21;
	FIF_XBM* = 22;
	FIF_XPM* = 23;
	FIF_DDS* = 24;
	FIF_GIF* = 25;
	FIF_HDR* = 26;
	FIF_FAXG3* = 27;
	FIF_SGI* = 28;
	FIF_EXR* = 29;
	FIF_J2K* = 30;
	FIF_JP2* = 31;
	FIF_PFM* = 32;
	FIF_PICT* = 33;
	FIF_RAW* = 34;
			
	(* Image type used in FreeImage.*)
TYPE IMAGE_TYPE* = LONGINT;
CONST
	FIT_UNKNOWN* = 0; 	(* unknown type *)
	FIT_BITMAP* = 1; 	(* standard image			: 1-, 4-, 8-, 16-, 24-, 32-bit *)
	FIT_UINT16*	 = 2; 	(* array of unsigned short	: unsigned 16-bit *)
	FIT_INT16*	 = 3; 	(* array of short			: signed 16-bit *)
	FIT_UINT32*	 = 4; 	(* array of unsigned long	: unsigned 32-bit *)
	FIT_INT32*	 = 5; 	(* array of long			: signed 32-bit *)
	FIT_FLOAT*	 = 6; 	(* array of float			: 32-bit IEEE floating point *)
	FIT_DOUBLE*	 = 7; 	(* array of double			: 64-bit IEEE floating point *)
	FIT_COMPLEX*	 = 8; 	(* array of FICOMPLEX		: 2 x 64-bit IEEE  floating point *)
	FIT_RGB16*	 = 9; 	(* 48-bit RGB image			: 3 x 16-bit *)
	FIT_RGBA16*	 = 10; 	(* 64-bit RGBA image		: 4 x 16-bit *)
	FIT_RGBF*	 = 11; 	(* 96-bit RGB float image	: 3 x 32-bit IEEE floating point *)
	FIT_RGBAF*	 = 12; 	(* 128-bit RGBA float image	: 4 x 32-bit IEEE floating point *)

	(* Image color type used in FreeImage. *)
TYPE IMAGE_COLOR_TYPE* = LONGINT;
CONST
	FIC_MINISWHITE* = 0; 		(* min value is white *)
	FIC_MINISBLACK* = 1; 		(* min value is black *)
	FIC_RGB* = 2; 		(* RGB color model *)
	FIC_PALETTE* = 3; 		(* color map indexed *)
	FIC_RGBALPHA* = 4; 		(* RGB color model with alpha channel *)
	FIC_CMYK* = 5; 		(* CMYK color model *)

	(* Color quantization algorithms. Constants used in FreeImage_ColorQuantize. *)
TYPE IMAGE_QUANTIZE* = LONGINT;
CONST
	FIQ_WUQUANT* = 0; 		(* Xiaolin Wu color quantization algorithm *)
	FIQ_NNQUANT* = 1; 			(* NeuQuant neural-net quantization algorithm by Anthony Dekker *)

	(* Dithering algorithms. Constants used FreeImage_Dither. *)
TYPE IMAGE_DITHER* = LONGINT;
CONST
	FID_FS* = 0; 	(* Floyd & Steinberg error diffusion *)
	FID_BAYER4x4* = 1; 	(* Bayer ordered dispersed dot dithering (order 2 dithering matrix)*)
	FID_BAYER8x8* = 2; 	(* Bayer ordered dispersed dot dithering (order 3 dithering matrix)*)
	FID_CLUSTER6x6* = 3; 	(* Ordered clustered dot dithering (order 3 - 6x6 matrix)*)
	FID_CLUSTER8x8* = 4; 	(* Ordered clustered dot dithering (order 4 - 8x8 matrix)*)
	FID_CLUSTER16x16* = 5; (* Ordered clustered dot dithering (order 8 - 16x16 matrix)*)
	FID_BAYER16x16* = 6; (* Bayer ordered dispersed dot dithering (order 4 dithering matrix)*)

	(* Lossless JPEG transformations Constants used in FreeImage_JPEGTransform	*)
TYPE IMAGE_JPEG_OPERATION* = LONGINT;
CONST
	FIJPEG_OP_NONE* = 0; 	(* no transformation *)
	FIJPEG_OP_FLIP_H* = 1; 	(* horizontal flip *)
	FIJPEG_OP_FLIP_V* = 2; 	(* vertical flip *)
	FIJPEG_OP_TRANSPOSE* = 3; 	(* transpose across UL-to-LR axis *)
	FIJPEG_OP_TRANSVERSE* = 4; 	(* transpose across UR-to-LL axis *)
	FIJPEG_OP_ROTATE_90* = 5; 	(* 90-degree clockwise rotation *)
	FIJPEG_OP_ROTATE_180*	= 6; 	 (* 180-degree rotation *)
	FIJPEG_OP_ROTATE_270*	= 7; 	(* 270-degree clockwise (or 90 ccw) *)

	(* Tone mapping operators. Constants used in FreeImage_ToneMapping. *)
TYPE IMAGE_TMO* = LONGINT;
CONST
	FITMO_DRAGO03* = 0; (* Adaptive logarithmic mapping (F. Drago, 2003) *)
	FITMO_REINHARD05* = 1; (* Dynamic range reduction inspired by photoreceptor physiology (E. Reinhard, 2005) *)
	FITMO_FATTAL02*  = 2;	(* Gradient domain high dynamic range compression (R. Fattal, 2002) *)

	(* Upsampling / downsampling filters. Constants used in FreeImage_Rescale. *)
TYPE IMAGE_FILTER* = LONGINT;
CONST
	FILTER_BOX* = 0; 	(* Box, pulse, Fourier window, 1st order (constant) b-spline *)
	FILTER_BICUBIC* = 1; 	(* Mitchell & Netravali's two-param cubic filter *)
	FILTER_BILINEAR* = 2; 	(* Bilinear filter *)
	FILTER_BSPLINE* = 3; 	(* 4th order (cubic) b-spline *)
	FILTER_CATMULLROM* = 4; 	(* Catmull-Rom spline, Overhauser spline *)
	FILTER_LANCZOS3* = 5; 	 (* Lanczos3 filter *)

	(* Color channels. Constants used in color manipulation routines. *)
TYPE IMAGE_COLOR_CHANNEL* = LONGINT;
CONST
	FICC_RGB* = 0; (* Use red, green and blue channels *)
	FICC_RED* = 1; (* Use red channel *)
	FICC_GREEN* = 2; (* Use green channel *)
	FICC_BLUE* = 3; (* Use blue channel *)
	FICC_ALPHA* = 4; (* Use alpha channel *)
	FICC_BLACK* = 5; (* Use black channel *)
	FICC_REAL* = 6; (* Complex images: use real part *)
	FICC_IMAG* = 7; (* Complex images: use imaginary part *)
	FICC_MAG* = 8; (* Complex images: use magnitude *)
	FICC_PHASE* = 9; 	 (* Complex images: use phase *)

	(* Metadata support ---------------------- *)
	(*  Tag data type information (based on TIFF specifications)
	Note: RATIONALs are the ratio of two 32-bit integer values. *)
		
TYPE IMAGE_MDTYPE* = LONGINT;
CONST
	FIDT_NOTYPE* = 0; 	(* placeholder *)
	FIDT_BYTE* = 1; 	(* 8-bit unsigned integer *)
	FIDT_ASCII* = 2; 	(* 8-bit bytes w/ last byte null *)
	FIDT_SHORT* = 3; 	(* 16-bit unsigned integer *)
	FIDT_LONG* = 4; 	(* 32-bit unsigned integer *)
	FIDT_RATIONAL* = 5; 	(* 64-bit unsigned fraction *)
	FIDT_SBYTE* = 6; 	(* 8-bit signed integer *)
	FIDT_UNDEFINED* = 7; 	(* 8-bit untyped data *)
	FIDT_SSHORT* = 8; 	(* 16-bit signed integer *)
	FIDT_SLONG* = 9; 	(* 32-bit signed integer *)
	FIDT_SRATIONAL* = 10; 	(* 64-bit signed fraction *)
	FIDT_FLOAT* = 11; 	(* 32-bit IEEE floating point *)
	FIDT_DOUBLE* = 12; 	(* 64-bit IEEE floating point *)
	FIDT_IFD* = 13; 	(* 32-bit unsigned integer (offset)*)
	FIDT_PALETTE* = 14; 	(* 32-bit RGBQUAD *)
	FIDT_LONG8* = 16;	(* 64-bit unsigned integer *)
	FIDT_SLONG8* = 17; (* 64-bit signed integer *)
	FIDT_IFD8* = 18;	(* 64-bit unsigned integer (offset) *)

	(*  Metadata models supported by FreeImage *)
TYPE IMAGE_MDMODEL* = LONGINT;
CONST
	FIMD_NODATA* = -1;
	FIMD_COMMENTS* = 0; 	(* single comment or keywords *)
	FIMD_EXIF_MAIN* = 1; 	(* Exif-TIFF metadata *)
	FIMD_EXIF_EXIF* = 2; 	(* Exif-specific metadata *)
	FIMD_EXIF_GPS* = 3; 	(* Exif GPS metadata *)
	FIMD_EXIF_MAKERNOTE* = 4; 	(* Exif maker note metadata *)
	FIMD_EXIF_INTEROP* = 5; 	(* Exif interoperability metadata *)
	FIMD_IPTC* = 6; 	(* IPTC/NAA metadata *)
	FIMD_XMP* = 7; 	(* Abobe XMP metadata *)
	FIMD_GEOTIFF* = 8; 	(* GeoTIFF metadata *)
	FIMD_ANIMATION* = 9; 	(* Animation metadata *)
	FIMD_CUSTOM* = 10; (* Used to attach other metadata types to a dib *)
	FIMD_EXIF_RAW* = 11;	(* Exif metadata as a raw buffer *)

	(*  Load / Save flag constants  *)
TYPE  IMAGE_FLAGS*=LONGINT;
CONST
	FIF_LOAD_NOPIXELS* = 8000H; (* loading: load the image header only (not supported by all plugins, default to full loading) *)

	BMP_DEFAULT* = 0;
	BMP_SAVE_RLE* = 1;
	CUT_DEFAULT* = 0;
	DDS_DEFAULT* = 0;
	EXR_DEFAULT*=	0;		(* save data as half with piz-based wavelet compression *)
	EXR_FLOAT*=0001H;	(* save data as float instead of as half (not recommended) *)
	EXR_NONE*=0002H;	(* save with no compression *) 
	EXR_ZIP*=0004H;	(* save with zlib compression, in blocks of 16 scan lines *)
	EXR_PIZ*=0008H;	(* save with piz-based wavelet compression *)
	EXR_PXR24*=0010H;	(* save with lossy 24-bit float compression *)
	EXR_B44*=0020H;	(* save with lossy 44% float compression - goes to 22% when combined with EXR_LC *)
	EXR_LC*=0040H;	(* save images with one luminance and two chroma channels, rather than as RGB (lossy compression) *)
		
	FAXG3_DEFAULT* = 0;
	GIF_DEFAULT* = 0;
	GIF_LOAD256* = 1; 		(*  Load the image as a 256 color image with ununsed palette entries, if it's 16 or 2 color *)
	GIF_PLAYBACK* = 2; 		(* 'Play' the GIF to generate each frame (as 32bpp) instead of returning raw frame data when loading *)
	HDR_DEFAULT* = 0;
	ICO_DEFAULT* = 0;
	ICO_MAKEALPHA* = 1; 		(*  convert to 32bpp and create an alpha channel from the AND-mask when loading *)
	IFF_DEFAULT* = 0;
	J2K_DEFAULT* = 0;		(* save with a 16:1 rate *)
	JP2_DEFAULT* = 0;		(* save with a 16:1 rate *)	 	
	JPEG_DEFAULT* = 0;
	JPEG_FAST* = 1;
	JPEG_ACCURATE* = 2;
	JPEG_CMYK* = 01000H; 	(*  load separated CMYK "as is" (use | to combine with other flags) *)
	JPEG_EXIFROTATE* = 0008H;	(* load and rotate according to Exif 'Orientation' tag if available *)
	JPEG_GREYSCALE* =0010H;	(* load and convert to a 8-bit greyscale image *)
		
	JPEG_QUALITYSUPERB* = 080H;
	JPEG_QUALITYGOOD* = 0100H;
	JPEG_QUALITYNORMAL* = 0200H;
	JPEG_QUALITYAVERAGE* = 0400H;
	JPEG_QUALITYBAD* = 0800H;
	JPEG_PROGRESSIVE* = 02000H; (*save as a progressive-JPEG (use | to combine with other flags) *)
	JPEG_SUBSAMPLING_411*=1000H;		(* save with high 4x1 chroma subsampling (4:1:1)  *)
	JPEG_SUBSAMPLING_420*= 4000H;		(* save with medium 2x2 medium chroma subsampling (4:2:0) - default value *)
	JPEG_SUBSAMPLING_422* = 8000H;		(* save with low 2x1 chroma subsampling (4:2:2)  *)
	JPEG_SUBSAMPLING_444*= 10000H;	(* save with no chroma subsampling (4:4:4) *)
	JPEG_OPTIMIZE* = 20000H; (* on saving, compute optimal Huffman coding tables (can reduce a few percent of file size) *)
	JPEG_BASELINE* = 40000H; (* save basic JPEG, without metadata or any markers *)
		
	KOALA_DEFAULT* = 0;
	LBM_DEFAULT* = 0;
	MNG_DEFAULT* = 0;
	PCD_DEFAULT* = 0;
	PCD_BASE* = 1; 		(* load the bitmap sized 768 x 512 *)
	PCD_BASEDIV4* = 2; 		(*  load the bitmap sized 384 x 256 *)
	PCD_BASEDIV16* = 3; 		(*  load the bitmap sized 192 x 128 *)
	PCX_DEFAULT* = 0;
	PFM_DEFAULT* = 0;
	PICT_DEFAULT* =  0;
	PNG_DEFAULT* = 0;
	PNG_IGNOREGAMMA* = 1; 		(*  avoid gamma correction *)
	PNG_Z_BEST_SPEED* =	0001H;	(* save using ZLib level 1 compression flag (default value is 6) *)
	PNG_Z_DEFAULT_COMPRESSION*=	0006H;	(* save using ZLib level 6 compression flag (default recommended value) *)
	PNG_Z_BEST_COMPRESSION*=0009H;	(* save using ZLib level 9 compression flag (default value is 6) *)
	PNG_Z_NO_COMPRESSION*=	0100H;	(* save without ZLib compression *)
	PNG_INTERLACED*=	0200H;	(* save using Adam7 interlacing (use | to combine with other save flags)*)		
	PNM_DEFAULT* = 0;
	PNM_SAVE_RAW* = 0; (*  If set the writer saves in RAW format (i.e. P4, P5 or P6) *)
	PNM_SAVE_ASCII* = 1; (* If set the writer saves in ASCII format (i.e. P1, P2 or P3) *)
	PSD_DEFAULT* = 0;
	PSD_CMYK* = 1;	(* reads tags for separated CMYK (default is conversion to RGB) *)
	PSD_LAB* =	2; (* reads tags for CIELab (default is conversion to RGB) *)
		
	RAS_DEFAULT* = 0;
	RAW_DEFAULT* = 0;		(* load the file as linear RGB 48-bit *)
	RAW_PREVIEW* = 1;		(* try to load the embedded JPEG preview with included Exif Data or default to RGB 24-bit *)
	RAW_DISPLAY* = 2;		(* load the file as RGB 24-bit *)
	RAW_HALFSIZE* = 4;		(* output a half-size color image *)
		
	SGI_DEFAULT* = 0;
	TARGA_DEFAULT* = 0;
	TARGA_LOAD_RGB888* = 1; (*  If set the loader converts RGB555 and ARGB8888 -> RGB888. *)
	TARGA_SAVE_RLE* = 2;		(* If set, the writer saves with RLE compression *)
		
	TIFF_DEFAULT* = 0;
	TIFF_CMYK* = 00001H; 	(*  reads/stores tags for separated CMYK (use | to combine with compression flags) *)
	TIFF_PACKBITS* = 00100H; (*  save using PACKBITS compression *)
	TIFF_DEFLATE* = 00200H; (*  save using DEFLATE compression (a.k.a. ZLIB compression) *)
	TIFF_ADOBE_DEFLATE* = 00400H; (*  save using ADOBE DEFLATE compression *)
	TIFF_NONE* = 00800H; (*  save without any compression *)
	TIFF_CCITTFAX3* = 01000H; (*  save using CCITT Group 3 fax encoding *)
	TIFF_CCITTFAX4* = 02000H; (*  save using CCITT Group 4 fax encoding *)
	TIFF_LZW* = 04000H; 	(* save using LZW compression *)
	TIFF_JPEG* = 08000H; 	(*  save using JPEG compression *)
	TIFF_LOGLUV* = 10000H; (* save using LogLuv compression *)
	WBMP_DEFAULT* = 0;
	XBM_DEFAULT* = 0;
	XPM_DEFAULT* = 0;


(*  Background filling options ---------------------------------------------------------
	Constants used in FreeImage_FillBackground and FreeImage_EnlargeCanvas *)

	COLOR_IS_RGB_COLOR* = 0H;	(* RGBQUAD color is a RGB color (contains no valid alpha channel) *)
	COLOR_IS_RGBA_COLOR* = 1H;	(* RGBQUAD color is a RGBA color (contains a valid alpha channel) *)
	COLOR_FIND_EQUAL_COLOR* = 2H;	(* For palettized images: lookup equal RGB color from palette *)
	COLOR_ALPHA_IS_INDEX* =  4H;	(* The color's rgbReserved member (alpha) contains the palette index to be used *)
	COLOR_PALETTE_SEARCH_MASK* =	(COLOR_FIND_EQUAL_COLOR  + COLOR_ALPHA_IS_INDEX);	(* No color lookup is performed *)

TYPE
	RGBQUAD* = RECORD
		rgbBlue*: CHAR;
		rgbGreen*: CHAR;
		rgbRed*: CHAR;
		rgbReserved*: CHAR
	END;

	RGBTRIPLE* = RECORD
		rgbtBlue*: CHAR;
		rgbtGreen*: CHAR;
		rgbtRed*: CHAR
	END;

	PtrBITMAPINFOHEADER* = POINTER TO BITMAPINFOHEADER;
	BITMAPINFOHEADER* = RECORD 
		biSize*: LONGINT;
		biWidth*: LONGINT;
		biHeight*: LONGINT;
		biPlanes*: INTEGER;
		biBitCount*: INTEGER;
		biCompression*: LONGINT;
		biSizeImage*: LONGINT;
		biXPelsPerMeter*: LONGINT;
		biYPelsPerMeter*: LONGINT;
		biClrUsed*: LONGINT;
		biClrImportant*: LONGINT;
	END;


	PtrBITMAPINFO* = POINTER TO BITMAPINFO;
	BITMAPINFO* = RECORD 
		bmiHeader*: BITMAPINFOHEADER;
		bmiColors*: ARRAY  1 OF RGBQUAD;
	END;

	(* 48-bit RGB *)
	 FIRGB16* = RECORD
	 	red*: INTEGER;
		green*: INTEGER;
		blue*: INTEGER
  	END;

	(* 64-bit RGBA *)
	 FIRGBA16* = RECORD
	 	red*: INTEGER;
   		green*: INTEGER;
 		blue*: INTEGER;
 		alpha*: INTEGER
 	END;

	(* 96-bit RGB Float *)
	 FIRGBF* = RECORD
  		red*: REAL;
  		green*: REAL;
  		blue*: REAL
  	END;

	(* 128-bit RGBA Float	*)
	FIRGBAF* = RECORD
		red*: REAL;
		green*: REAL;
		blue*: REAL;
		alpha*: REAL
	END;

		(* Data structure for COMPLEX type (complex number) *)
	FICOMPLEX* = RECORD
		r*: LONGREAL; (* real part *)
		i*: LONGREAL; (* imaginary part *)
	END;

	LUT* = ARRAY  256 OF CHAR; (* aded for compatibility to v3.10.0, GetAdjustColorsLookupTable, etc. *)
(*
	(* used for easy accessing to pixels of various image types, see Scanline procs. ( Necati) *)
	PtrLineRGB* = POINTER TO ARRAY OF RGBTRIPLE; (* for accessing 24 bit lines, RGB *)
	PtrLineRGBA* = POINTER TO ARRAY OF RGBQUAD; (* for accessing 32 bit lines, RGBA *)
	PtrFISINT16* = POINTER TO ARRAY OF INTEGER; (* for 16 bit integers *)
	PtrFIINT32* = POINTER TO ARRAY OF LONGINT; (* for 32 bit integers *)
	PtrFIFLOAT* = POINTER TO ARRAY OF REAL; (* for 32 bit real *)
	PtrFIDOUBLE* = POINTER TO ARRAY OF LONGREAL; (* for 64 bit real *)

	PtrFICOMPLEX* = POINTER TO ARRAY OF FICOMPLEX; (* 2x64 bits real, Complex *)
	PtrFIRGB16* = POINTER TO ARRAY OF FIRGB16; (* for 48-bit RGB, 3x16 bits *)
	PtrFIRGBA16* = POINTER TO ARRAY OF FIRGBA16; (* 64-bit RGBA, 4x16 bits *)
	PtrFIRGBF* = POINTER TO ARRAY OF FIRGBF; (* 96-bit RGB Float, 3*32 bits *)
	PtrFIRGBAF* = POINTER TO ARRAY OF FIRGBAF; (* 128-bit RGBA Float, 4x32 bits *)
*)		
	Palette* = ARRAY 256 OF RGBQUAD;
	PtrPALETTE* = POINTER TO Palette;

	(* File IO routines *)
	FHandle* =  ADDRESS;
	PSint* = POINTER TO ARRAY OF INTEGER;
	Pint* = POINTER TO ARRAY OF LONGINT;
	FI_ReadProc* = PROCEDURE (buffer: ADDRESS; size: LONGINT; count: LONGINT; handle: FHandle): LONGINT;
	FI_WriteProc* = PROCEDURE (buffer: ADDRESS; size: LONGINT; count: LONGINT; handle: FHandle): LONGINT;
	FI_SeekProc* = PROCEDURE (handle: FHandle; offset: LONGINT; origin: LONGINT): PSint;
	FI_TellProc* = PROCEDURE (handle: FHandle): Pint;

	
	FreeImageIO* = POINTER TO RECORD
		read_proc *: FI_ReadProc; (* pointer to the function used to read data *)
		write_proc*: FI_WriteProc; (* pointer to the function used to write data *)
		seek_proc*: FI_SeekProc; (* pointer to the function used to seek *)
		tell_proc*: FI_TellProc; (* pointer to the function used to aquire the current position *)
	END;

	FIMEMORY* = POINTER TO RECORD END;(* Handle to a memory I/O stream *)
	FIBITMAP* = POINTER TO RECORD END; (* Handle to a FreeImage bitmap *)
	FIMULTIBITMAP* = POINTER TO RECORD  END; (* handle to a multibitmap *)
	FIMETADATA* = POINTER TO RECORD END; (*Handle to a metadata model*)
	FITAG* = POINTER TO RECORD END; (*Handle to a FreeImage tag *)
	FIICCPROFILE* = POINTER TO RECORD
		flags*: INTEGER; (* info flag *)
		size*: LONGINT; (* profile's size measured in bytes *)
		data*: ADDRESS; (* points to a block of contiguous memory containing the profile*)
	END;


	OutputMessageFunction* = PROCEDURE {C} (fif: IMAGE_FORMAT; msg: Strings.String);
	OutputMessageFunctionStdCall* = PROCEDURE {WINAPI} (fif: IMAGE_FORMAT;  msg: Strings.String);
	

CONST
(* constants used in FreeImage_Seek for Origin parameter *)
	SEEK_SET* = 0;
	SEEK_CUR* = 1;
	SEEK_END* = 2;

VAR
	(* Init/Error routines -------------------------------- *)
	(* is not required for dynamic linking *)
(*	
	Initialise- : PROCEDURE {WINAPI} (load_local_plugins_only: BOOLEAN);
	DeInitialise-: PROCEDURE {WINAPI}();
*)

	(* Version routines -------------------------------- *)
	getVersion-: PROCEDURE {WINAPI}(): ADDRESS;
	getCopyrightMessage-: PROCEDURE {WINAPI}(): ADDRESS;

	(* Message output functions -------------------------------- *)
	SetOutputMessage-: PROCEDURE {WINAPI} (omf: OutputMessageFunction);
	SetOutputMessageStdCall-: PROCEDURE {WINAPI} (omf: OutputMessageFunctionStdCall);

	(* Allocate/Clone/Unload routines -------------------------------- *)
	Allocate-: PROCEDURE {WINAPI} (width, height: LONGINT; bpp: LONGINT; red_mask, green_mask, blue_mask: LONGINT): FIBITMAP;
	AllocateT-: PROCEDURE {WINAPI} (type: IMAGE_TYPE; width, height: LONGINT; bpp: LONGINT; red_mask, green_mask, blue_mask: LONGINT): FIBITMAP;
	Clone-: PROCEDURE {WINAPI}(dib: FIBITMAP): FIBITMAP;
	Unload-: PROCEDURE {WINAPI} (dib: FIBITMAP);

	(* Header loading routines -------------------------------- *)
	HasPixels-: PROCEDURE {WINAPI} (dib: FIBITMAP): BOOLEAN ;

	(* Load/Save routines -------------------------------- *)
	Load-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; CONST filename: ARRAY OF CHAR; flags: IMAGE_FLAGS): FIBITMAP;
	(*LoadU-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; CONST filename: ARRAY OF CHAR16; flags: IMAGE_FLAGS): FIBITMAP;*)
	Save-: PROCEDURE {WINAPI}(fif: IMAGE_FORMAT; dib: FIBITMAP; CONST filename: ARRAY OF CHAR; flags: IMAGE_FLAGS): BOOLEAN;

	(*SaveU-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; dib: FIBITMAP; filename: PCharU; flags: IMAGE_FLAGS): BOOLEAN;
	LoadFromHandle-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; io: FreeImageIO; hadle: LONGINT; flags: LONGINT): FIBITMAP;
	SaveToHandle-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; dib: FIBITMAP; io: FreeImageIO ; handle: LONGINT;  flags: LONGINT): BOOLEAN;
	*)



	(* Memory I/O stream routines  -------------------------------- *)

	(* NOT TESTED *)
	OpenMemory-: PROCEDURE {WINAPI} (data: ADDRESS; size_in_bytes: LONGINT): FIMEMORY;
	CloseMemory-: PROCEDURE {WINAPI} (stream: FIMEMORY);
	LoadFromMemory-: PROCEDURE {WINAPI}  (fif: IMAGE_FORMAT; stream: FIMEMORY; flags: LONGINT): FIBITMAP;
	SaveToMemory-: PROCEDURE {WINAPI}  (fif: IMAGE_FORMAT; dib: FIBITMAP; stream: FIMEMORY; flags: LONGINT): BOOLEAN;
	TellMemory-: PROCEDURE {WINAPI}  (stream: FIMEMORY): LONGINT;
	SeekMemory-: PROCEDURE {WINAPI}  (stream: FIMEMORY; offset: LONGINT; origin: LONGINT): BOOLEAN;
	AcquireMemory-: PROCEDURE {WINAPI}  (stream: FIMEMORY;  VAR data: ADDRESS; VAR size_in_bytes: LONGINT): BOOLEAN;
	ReadMemory-: PROCEDURE {WINAPI}(buffer: ADDRESS; size: LONGINT; count: LONGINT; stream: FIMEMORY): LONGINT;
	WriteMemory-: PROCEDURE {WINAPI} (buffer: ADDRESS; size: LONGINT; count: LONGINT; stream: FIMEMORY): LONGINT;
	LoadMultiBitmapFromMemory-: PROCEDURE {WINAPI}  (fif: IMAGE_FORMAT; stream: FIMEMORY; flags: LONGINT): FIMULTIBITMAP;
	SaveMultiBitmapToMemory-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; bitmap: FIMULTIBITMAP; stream: FIMEMORY; flags: LONGINT): BOOLEAN;
	
	(* Plugin Interface -------------------------------- *)
	GetFIFCount-: PROCEDURE {WINAPI} (): LONGINT;
	SetPluginEnabled-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; enable: BOOLEAN): LONGINT;
	IsPluginEnabled-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT): LONGINT;
	GetFIFFromFormat-: PROCEDURE {WINAPI} (CONST format: ARRAY OF CHAR): IMAGE_FORMAT;
	GetFIFFromMime-: PROCEDURE {WINAPI} (CONST format: ARRAY OF CHAR): IMAGE_FORMAT;
	getFormatFromFIF-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT): ADDRESS;
	getFIFExtensionList-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT): ADDRESS;
	getFIFDescription-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT): ADDRESS;
	getFIFRegExpr-: PROCEDURE {WINAPI}  (fif: IMAGE_FORMAT): ADDRESS;

	GetFIFFromFilename- : PROCEDURE {WINAPI} (CONST fname: ARRAY OF CHAR): IMAGE_FORMAT;
	GetFIFFromFilenameU-: PROCEDURE {WINAPI} (CONST fname: ARRAY OF CHAR16): IMAGE_FORMAT;

	FIFSupportsReading-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT): BOOLEAN;
	FIFSupportsWriting-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT): BOOLEAN;


	FIFSupportsExportBPP-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; bpp: LONGINT): BOOLEAN;
	FIFSupportsExportType-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; image_type: IMAGE_TYPE): BOOLEAN;
	FIFSupportsICCProfiles-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT): BOOLEAN;
	FIFSupportsNoPixels-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT): BOOLEAN;

	
	(* Multipaging interface -------------------------------- *)

	OpenMultiBitmap-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; CONST filename: ARRAY OF CHAR; create_new, read_only, keep_cache_in_memory: BOOLEAN): FIMULTIBITMAP;
	OpenMultiBitmapFromHandle-: PROCEDURE {WINAPI}  (fif: IMAGE_FORMAT ; io: FreeImageIO; handle: LONGINT;  flags: LONGINT): FIMULTIBITMAP; 
	SaveMultiBitmapToHandle-: PROCEDURE {WINAPI} (fif: IMAGE_FORMAT; bitmap: FIMULTIBITMAP; io: FreeImageIO;  handle: FHandle;  flags: LONGINT): BOOLEAN;
	CloseMultiBitmap-: PROCEDURE {WINAPI} (bitmap: FIMULTIBITMAP; flags: LONGINT): BOOLEAN;
	GetPageCount-: PROCEDURE {WINAPI}  (bitmap: FIMULTIBITMAP): LONGINT;
	AppendPage-: PROCEDURE {WINAPI}  (bitmap: FIMULTIBITMAP; data: FIBITMAP);
	InsertPage-: PROCEDURE {WINAPI} (bitmap: FIMULTIBITMAP; page: LONGINT; data: FIBITMAP);
	DeletePage-: PROCEDURE {WINAPI}  (bitmap: FIMULTIBITMAP; page: LONGINT);
	LockPage-: PROCEDURE {WINAPI} (bitmap: FIMULTIBITMAP; page: LONGINT): FIBITMAP;
	UnlockPage-: PROCEDURE {WINAPI}  (bitmap: FIMULTIBITMAP; page: FIBITMAP; changed: BOOLEAN);
	MovePage-: PROCEDURE {WINAPI} (bitmap: FIMULTIBITMAP; target, source: LONGINT): BOOLEAN;
	GetLockedPageNumbers-: PROCEDURE {WINAPI}  (bitmap: FIMULTIBITMAP; VAR pages: LONGINT; VAR count: LONGINT): BOOLEAN;


	(* Filetype request routines -------------------------------- *)
	GetFileType-: PROCEDURE {WINAPI} (CONST filename: ARRAY OF CHAR; size: LONGINT): IMAGE_FORMAT;
	GetFileTypeU-: PROCEDURE {WINAPI} (CONST filename: ARRAY OF CHAR16; size: LONGINT): IMAGE_FORMAT;
	GetFileTypeFromHandle-: PROCEDURE {WINAPI} (io: FreeImageIO; handle: LONGINT; size: LONGINT): IMAGE_FORMAT;
	GetFileTypeFromMemory-: PROCEDURE {WINAPI} (stream: FIMEMORY; size: LONGINT ): IMAGE_FORMAT;
	

	(* ImageType request routine -------------------------------- *)
	GetImageType-: PROCEDURE{WINAPI} (dib: FIBITMAP): IMAGE_TYPE;

	(* FreeImage helper routines -------------------------------- *)
	
	IsLittleEndian-: PROCEDURE {WINAPI} (): BOOLEAN;
	LookupX11Color-: PROCEDURE {WINAPI} (CONST szColor: ARRAY OF CHAR; VAR nRed, nGreen, nBlue: LONGINT): BOOLEAN;
	LookupSVGColor-: PROCEDURE {WINAPI} (CONST szColor: ARRAY OF CHAR; VAR nRed, nGreen, nBlue: LONGINT): BOOLEAN;

	(* Pixels access routines -------------------------------- *)
	GetBits-:  PROCEDURE {WINAPI} (dib: FIBITMAP): ADDRESS;
	GetScanLine-: PROCEDURE {WINAPI} (dib: FIBITMAP; scanline: LONGINT): ADDRESS;
	GetPixelColor-: PROCEDURE {WINAPI} (dib: FIBITMAP; x, y: LONGINT; VAR value: RGBQUAD);
	SetPixelColor-: PROCEDURE {WINAPI} (dib: FIBITMAP; x, y: LONGINT; CONST value: RGBQUAD);
	GetPixelIndex-: PROCEDURE {WINAPI} (dib: FIBITMAP; x, y: LONGINT; VAR value: CHAR): BOOLEAN;
	SetPixelIndex-: PROCEDURE {WINAPI} (dib: FIBITMAP; x, y: LONGINT; VAR value: CHAR): BOOLEAN;

	(* ****************************** *)
	(* utilitiy procedures for different type of image line pixels, necati *)
(*
	GetScanLineRGB-: PROCEDURE {WINAPI}  (dib: FIBITMAP; scanline: LONGINT): PtrLineRGB;
	GetScanLineRGBA-: PROCEDURE {WINAPI} (dib: FIBITMAP; scanline: LONGINT): PtrLineRGBA;
	GetScanLine16-: PROCEDURE {WINAPI}  (dib: FIBITMAP; scanline: LONGINT):PtrFISINT16;
	GetScanLine32-: PROCEDURE {WINAPI} (dib: FIBITMAP; scanline: LONGINT): PtrFIINT32;

	GetScanLineFloat-: PROCEDURE {WINAPI} (dib: FIBITMAP; scanline: LONGINT): PtrFIFLOAT;
	GetScanLineDouble-: PROCEDURE {WINAPI}  (dib: FIBITMAP; scanline: LONGINT): PtrFIDOUBLE;
	GetScanLineComplex-: PROCEDURE {WINAPI}  (dib: FIBITMAP; scanline: LONGINT):PtrFICOMPLEX;
	GetScanLineFRGB16-: PROCEDURE  {WINAPI}  (dib: FIBITMAP; scanline: LONGINT): PtrFIRGB16;
	GetScanLineFRGBA16-: PROCEDURE {WINAPI} (dib: FIBITMAP; scanline: LONGINT): PtrFIRGBA16;
	GetScanLineFRGBF-: PROCEDURE {WINAPI}  (dib: FIBITMAP; scanline: LONGINT): PtrFIRGBF;
	GetScanLineFRGBAF-: PROCEDURE {WINAPI} (dib: FIBITMAP; scanline: LONGINT): PtrFIRGBAF;
      *)

	(* DIB info routines -------------------------------- *)
	GetColorsUsed-: PROCEDURE {WINAPI}  (dib: FIBITMAP): LONGINT;
	GetBPP-: PROCEDURE {WINAPI}  (dib: FIBITMAP): LONGINT;
	GetWidth-: PROCEDURE {WINAPI}  (dib: FIBITMAP): LONGINT;
	GetHeight-: PROCEDURE {WINAPI}  (dib: FIBITMAP): LONGINT;
	GetLine-: PROCEDURE {WINAPI}  (dib: FIBITMAP): LONGINT;
	GetPitch-: PROCEDURE {WINAPI}  (dib: FIBITMAP): LONGINT;
	GetDIBSize-: PROCEDURE {WINAPI}  (dib: FIBITMAP): LONGINT;
	GetPalette-: PROCEDURE {WINAPI}  (dib: FIBITMAP): PtrPALETTE;	
	GetDotsPerMeterX-: PROCEDURE {WINAPI} (dib: FIBITMAP): LONGINT;
	GetDotsPerMeterY-: PROCEDURE {WINAPI} (dib: FIBITMAP): LONGINT;
	SetDotsPerMeterX-: PROCEDURE {WINAPI} (dib: FIBITMAP; res: LONGINT);
	SetDotsPerMeterY-: PROCEDURE {WINAPI} (dib: FIBITMAP; res: LONGINT);
	GetInfoHeader-: PROCEDURE {WINAPI} (dib: FIBITMAP): PtrBITMAPINFOHEADER;
	GetInfo-: PROCEDURE {WINAPI} (dib: FIBITMAP): PtrBITMAPINFO;
	GetColorType-: PROCEDURE {WINAPI} (dib: LONGINT): LONGINT;
	GetRedMask-: PROCEDURE {WINAPI} (dib: FIBITMAP): LONGINT;
	GetGreenMask-: PROCEDURE {WINAPI} (dib: FIBITMAP): LONGINT;
	GetBlueMask-: PROCEDURE {WINAPI} (dib: FIBITMAP): LONGINT;
	GetTransparencyCount-: PROCEDURE {WINAPI} (dib: FIBITMAP): LONGINT;
	GetTransparencyTable-: PROCEDURE {WINAPI} (dib: FIBITMAP): LONGINT;
	SetTransparent-: PROCEDURE {WINAPI} (dib: FIBITMAP; enabled: BOOLEAN);
	SetTransparencyTable-: PROCEDURE {WINAPI} (dib: FIBITMAP; table: ADDRESS; count: LONGINT);
	IsTransparent-: PROCEDURE {WINAPI} (dib: FIBITMAP): BOOLEAN;
	SetTransparentIndex-: PROCEDURE {WINAPI} (dib:FIBITMAP; index: LONGINT);
	GetTransparentIndex-: PROCEDURE {WINAPI} (dib:FIBITMAP): LONGINT;
	HasBackgroundColor-: PROCEDURE {WINAPI} (dib: FIBITMAP): BOOLEAN;
	GetBackgroundColor-: PROCEDURE {WINAPI} (dib: FIBITMAP; VAR bkcolor: RGBQUAD): BOOLEAN;
	SetBackgroundColor-: PROCEDURE {WINAPI} (dib: FIBITMAP;  bkcolor: RGBQUAD): BOOLEAN;
	GetThumbnail-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIBITMAP;
	SetThumbnail-: PROCEDURE  {WINAPI} (dib: FIBITMAP;  thumbnail: FIBITMAP): BOOLEAN;
	
	(* ICC profile routines -------------------------------- *)

	GetICCProfile-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIICCPROFILE;
	CreateICCProfile-: PROCEDURE {WINAPI} (dib: FIBITMAP; data: ADDRESS; size: LONGINT): FIICCPROFILE;
	DestroyICCProfile-: PROCEDURE {WINAPI} (dib: FIBITMAP);

	(* Line Conversion Routines : not translated yet -------------------------------- *)

	(*  Smart conversion routines -------------------------------- *)
	ConvertTo4Bits-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIBITMAP;
	ConvertTo8Bits-: PROCEDURE  {WINAPI}  (dib: FIBITMAP): FIBITMAP;
	ConvertToGreyscale-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIBITMAP;
	ConvertTo16Bits555-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIBITMAP;
	ConvertTo16Bits565-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIBITMAP;
	ConvertTo24Bits-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIBITMAP;
	ConvertTo32Bits-: PROCEDURE {WINAPI}  (dib: FIBITMAP): FIBITMAP;
	ColorQuantize-: PROCEDURE {WINAPI}  (dib: FIBITMAP; quantize: IMAGE_QUANTIZE): FIBITMAP;
	ColorQuantizeEx-: PROCEDURE {WINAPI} (dib: FIBITMAP; quantize: IMAGE_QUANTIZE; PaletteSize: LONGINT; ReserveSize: LONGINT; ReservePalette: RGBQUAD): FIBITMAP;
	Threshold-: PROCEDURE {WINAPI}  (dib: FIBITMAP; T: SHORTINT): FIBITMAP;
	Dither-: PROCEDURE {WINAPI}  (dib: FIBITMAP; algorithm: IMAGE_DITHER): FIBITMAP;
	ConvertFromRawBits-: PROCEDURE {WINAPI} (bits: LONGINT; width, height, pitch: LONGINT; bpp, red_mask, green_mask, blue_mask: LONGINT; topdown: BOOLEAN): FIBITMAP;
	ConvertToRawBits-: PROCEDURE {WINAPI}  (bits: LONGINT; dib: FIBITMAP; pitch: LONGINT; bpp, red_mask, green_mask, blue_mask: LONGINT; topdown: BOOLEAN);
	ConvertToFloat-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIBITMAP;
	ConvertToRGBF-: PROCEDURE {WINAPI}  (dib: FIBITMAP): FIBITMAP;
	ConvertToUINT16-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIBITMAP;
	ConvertToRGB16-: PROCEDURE {WINAPI} (dib: FIBITMAP): FIBITMAP;

	ConvertToStandardType-: PROCEDURE {WINAPI}  (src: FIBITMAP; scale_linear: BOOLEAN): FIBITMAP;
	ConvertToType-: PROCEDURE {WINAPI}  (src: FIBITMAP; dst_type: IMAGE_TYPE; scale_linear: BOOLEAN): FIBITMAP;

	(* tone mapping operators *)
	ToneMapping-: PROCEDURE {WINAPI}  (dib: FIBITMAP; tmo: IMAGE_TMO; first_param, second_param: LONGREAL): FIBITMAP;
	TmoDrago03-: PROCEDURE {WINAPI}  (src: FIBITMAP; gamma, exposure: LONGREAL): FIBITMAP;

	TmoReinhard05-: PROCEDURE {WINAPI}  (src: FIBITMAP; intensity, contrast: LONGREAL): FIBITMAP;
	TmoReinhard05Ex-: PROCEDURE {WINAPI} (src: FIBITMAP; intensity, contrast, adaptation, color_correction: LONGREAL): FIBITMAP;
	TmoFattal02-: PROCEDURE {WINAPI} (src: FIBITMAP; color_saturation,  attenuation: LONGREAL): FIBITMAP;
	
	(* ZLib interface -------------------------------- *)

	ZLibCompress-: PROCEDURE {WINAPI} (target: ADDRESS; target_size: LONGINT; source: ADDRESS; source_size: LONGINT): LONGINT;
	ZLibUncompress-: PROCEDURE {WINAPI} (target: ADDRESS; target_size: LONGINT; source: ADDRESS; source_size: LONGINT): LONGINT;
	ZLibGZip-: PROCEDURE {WINAPI} (target: ADDRESS; target_size: LONGINT; source: ADDRESS; source_size: LONGINT): LONGINT;
	ZLibGUnzip-: PROCEDURE {WINAPI} (target: ADDRESS; target_size: LONGINT; source: ADDRESS; source_size: LONGINT): LONGINT;
	ZLibCRC32-: PROCEDURE {WINAPI} (crc: LONGINT; source: ADDRESS; source_size: LONGINT): LONGINT;

	(*   Metadata routines -------------------------------- *)
	(* tag creation / destruction*)
	CreateTag- : PROCEDURE {WINAPI} (): FITAG;
	DeleteTag-: PROCEDURE {WINAPI} (tag: FITAG);
	CloneTag-: PROCEDURE {WINAPI} (tag: FITAG): FITAG;

	 (* tag getters and setters *)
	getTagKey-: PROCEDURE {WINAPI} (tag: FITAG): ADDRESS;
	getTagDescription-: PROCEDURE {WINAPI} (tag: FITAG): ADDRESS;
	GetTagID-: PROCEDURE {WINAPI} (tag: FITAG): LONGINT;
	GetTagType-: PROCEDURE {WINAPI} (tag: FITAG): IMAGE_MDTYPE;
	GetTagCount-: PROCEDURE {WINAPI} (tag: FITAG): LONGINT;
	GetTagLength-: PROCEDURE {WINAPI} (tag: FITAG): LONGINT;
	GetTagValue-: PROCEDURE {WINAPI} (tag: FITAG): ADDRESS;
	SetTagKey-: PROCEDURE {WINAPI} (tag: FITAG; CONST key: ARRAY OF CHAR): BOOLEAN;
	SetTagDescription-: PROCEDURE {WINAPI} (tag: FITAG; CONST description: ARRAY OF CHAR): BOOLEAN;
	SetTagID-: PROCEDURE {WINAPI} (tag: FITAG; id: LONGINT): BOOLEAN;
	SetTagType-: PROCEDURE {WINAPI} (tag: FITAG; atype: IMAGE_MDTYPE): BOOLEAN;
	SetTagCount-: PROCEDURE {WINAPI} (tag: FITAG; count: LONGINT): BOOLEAN;
	SetTagLength-: PROCEDURE {WINAPI} (tag: FITAG; length: LONGINT): BOOLEAN;
	SetTagValue-: PROCEDURE {WINAPI} (tag: FITAG; value: ADDRESS): BOOLEAN;

	(* iterator*)
	FindFirstMetadata-: PROCEDURE {WINAPI} (model: IMAGE_MDMODEL; dib: FIBITMAP; VAR tag: FITAG): FIMETADATA;
	FindNextMetadata-: PROCEDURE {WINAPI} (mdhandle: FIMETADATA; VAR tag: FITAG): BOOLEAN;
	FindCloseMetadata-: PROCEDURE {WINAPI} (mdhandle: FIMETADATA);

	 (* metadata setter and getter *)
	SetMetadata-: PROCEDURE {WINAPI} (model: IMAGE_MDMODEL; dib: FIBITMAP; CONST key: ARRAY OF CHAR; tag: FITAG): BOOLEAN;
	GetMetadata-: PROCEDURE {WINAPI} (model: IMAGE_MDMODEL; dib: FIBITMAP; CONST key: ARRAY OF CHAR; VAR tag: FITAG): BOOLEAN;

	(* helpers *)
	GetMetadataCount-: PROCEDURE {WINAPI} (model: IMAGE_MDMODEL; dib: FIBITMAP): LONGINT;
	CloneMetadata-: PROCEDURE {WINAPI} ( dst, src: FIBITMAP): BOOLEAN;
	 (* tag to C string conversion *)
	tagToString-: PROCEDURE {WINAPI} (model: IMAGE_MDMODEL; tag: FITAG; make: ADDRESS): ADDRESS;
	
	(* Image manipulation toolkit -------------------------------- *)
		(* rotation and flipping *)
	(*  @deprecated see FreeImage_Rotate *)
	RotateClassic-: PROCEDURE {WINAPI} (dib: FIBITMAP; angle: LONGREAL): FIBITMAP;
	Rotate-:  PROCEDURE {WINAPI}(dib: FIBITMAP; angle: LONGREAL; bkcolor: LONGINT): FIBITMAP;

	RotateEx-: PROCEDURE {WINAPI} (dib: FIBITMAP; angle: LONGREAL; x_shift, y_shift, x_origin, y_origin: LONGREAL; use_mask: BOOLEAN): FIBITMAP;
	FlipHorizontal-: PROCEDURE {WINAPI} (dib: FIBITMAP): BOOLEAN;
	FlipVertical-: PROCEDURE {WINAPI}(dib: FIBITMAP): BOOLEAN;
	JPEGTransform-: PROCEDURE {WINAPI} (CONST srcfile, dstfile: ARRAY OF CHAR; operation: IMAGE_JPEG_OPERATION; perfect: BOOLEAN): BOOLEAN;

	JPEGTransformU-: PROCEDURE {WINAPI} (CONST srcfile, dstfile: ARRAY OF CHAR16; operation: IMAGE_JPEG_OPERATION; perfect: BOOLEAN):  BOOLEAN;


		(* upsampling / downsampling *)
	Rescale-: PROCEDURE {WINAPI} (dib: FIBITMAP; dst_width, dst_height: LONGINT; filter: IMAGE_FILTER): FIBITMAP;
	MakeThumbnail-:  PROCEDURE {WINAPI} (dib: FIBITMAP; max_pixel_size: LONGINT; convert: BOOLEAN): FIBITMAP;

		(* color manipulation routines (point operations)*)
	AdjustCurve-: PROCEDURE {WINAPI} (dib: FIBITMAP;  LUT: ADDRESS; (* ARRAY OF CHAR *) channel: IMAGE_COLOR_CHANNEL): BOOLEAN;
	AdjustGamma-: PROCEDURE {WINAPI} (dib: FIBITMAP; gamma: LONGREAL): BOOLEAN;
	AdjustBrightness-: PROCEDURE {WINAPI} (dib: FIBITMAP; percentage: LONGREAL): BOOLEAN;
	AdjustContrast-: PROCEDURE {WINAPI}  (dib: FIBITMAP; percentage: LONGREAL): BOOLEAN;
	Invert-: PROCEDURE {WINAPI} (dib: FIBITMAP): BOOLEAN;
	GetHistogram-: PROCEDURE {WINAPI} (dib: FIBITMAP; histo: ADDRESS; (* ARRAY OF LONGINT;*)  channel: IMAGE_COLOR_CHANNEL): BOOLEAN;
	GetAdjustColorsLookupTable-: PROCEDURE {WINAPI} (VAR LUT: Palette; brightness,  contrast,  gamma: LONGREAL; invert: BOOLEAN): LONGINT;
	AdjustColors-: PROCEDURE {WINAPI} (dib: FIBITMAP; brightness, contrast, gamma: LONGREAL; invert: BOOLEAN);
	ApplyColorMapping-: PROCEDURE {WINAPI} (dib: FIBITMAP; VAR srccolors, dstcolors: Palette; count: LONGINT;  ignore_alpha, swap: LONGINT): LONGINT;
	SwapColors-: PROCEDURE {WINAPI} (dib: FIBITMAP; VAR  color_a, color_b: Palette ; ignore_alpha: BOOLEAN): LONGINT;
	ApplyPaletteIndexMapping-: PROCEDURE {WINAPI} (dib: FIBITMAP; VAR  srcindices,	dstindices: LUT; count: LONGINT;swap: BOOLEAN): LONGINT;
	SwapPaletteIndices-: PROCEDURE {WINAPI} (dib: FIBITMAP; VAR index_a, index_b: LUT): LONGINT;


	(* channel processing routines -------------------------------- *)
	GetChannel-: PROCEDURE {WINAPI}  (dib: FIBITMAP; channel: IMAGE_COLOR_CHANNEL): FIBITMAP;
	SetChannel-: PROCEDURE {WINAPI}  (dib: FIBITMAP; dib8: FIBITMAP; channel: IMAGE_COLOR_CHANNEL): BOOLEAN;
	GetComplexChannel-: PROCEDURE {WINAPI} (dib: FIBITMAP; channel: IMAGE_COLOR_CHANNEL): FIBITMAP;
	SetComplexChannel-: PROCEDURE {WINAPI} (dst: FIBITMAP; src: FIBITMAP; channel: IMAGE_COLOR_CHANNEL): BOOLEAN;

	(* copy / paste / composite routines -------------------------------- *)
	Copy-: PROCEDURE {WINAPI} (dib: FIBITMAP; left, top, right, bottom: LONGINT): FIBITMAP;
	Paste-: PROCEDURE {WINAPI} (dst: FIBITMAP; src: FIBITMAP; left, top, alpha: LONGINT): BOOLEAN;
	Composite-: PROCEDURE {WINAPI} (fg: FIBITMAP; useFileBkg: BOOLEAN; appBkColor: RGBQUAD; bg: FIBITMAP): FIBITMAP;
	JPEGCrop-: PROCEDURE {WINAPI} (CONST srcfile, dstfile: ARRAY OF CHAR; left, top, right, bottom: LONGINT): BOOLEAN;
	JPEGCropU-: PROCEDURE {WINAPI} (CONST srcfile, dstfile: ARRAY OF CHAR16;  left,  top, right, bottom: LONGINT): BOOLEAN;
	PreMultiplyWithAlpha-: PROCEDURE {WINAPI} (dib: FIBITMAP): BOOLEAN;


	(*  background filling routines -------------------------------- *)
	FillBackground-: PROCEDURE {WINAPI} (dib: FIBITMAP ;  color: LONGINT; options: LONGINT): BOOLEAN;
	EnlargeCanvas-: PROCEDURE {WINAPI} (src: FIBITMAP;   left,  top, right,  bottom: LONGINT; color: LONGINT;  options: LONGINT): FIBITMAP;
	(*
	AllocateEx-: PROCEDURE {WINAPI} (width, height, bpp: LONGINT; color: RGBQUAD;  options : LONGINT; const RGBQUAD *palette FI_DEFAULT(NULL); red_mask, green_mask, blue_mask LONGINT): FIBITMAP;
	AllocateExT-: PROCEDURE {WINAPI} (type: IMAGE_TYPE;  width,  height,  bpp: LONGINT; const void * color, int options FI_DEFAULT(0), const RGBQUAD *palette FI_DEFAULT(NULL); red_mask, green_mask, blue_mask: LONGINT): FIBITMAP;
	*)

	(* miscellaneous algorithms -------------------------------- *)
	MultigridPoissonSolver-: PROCEDURE {WINAPI} (Laplacian: FIBITMAP; ncycle:LONGINT): FIBITMAP;

(** Wrapper for Kernel32.getProcAddress. *)
PROCEDURE GetProcAddress*( hModule: Kernel32.HMODULE;  CONST procName: ARRAY OF CHAR;  adr: ADDRESS );
VAR padr: ADDRESS;
BEGIN
	padr := Kernel32.getProcAddress( hModule, procName );
	SYSTEM.PUT(adr, padr);
END GetProcAddress;

PROCEDURE InitFunctions;
BEGIN
	lib := Kernel32.LoadLibrary(libname);
	ASSERT(lib # 0,102);

	(* Init / Error routines *)
(*	GetProcAddress(lib, "_FreeImage_Initialise@4", ADDRESSOF( Initialise ));
	GetProcAddress(lib, "_FreeImage_DeInitialise@0", ADDRESSOF( DeInitialise ));
*)	
	(* Version routines*)
	GetProcAddress(lib, "_FreeImage_GetVersion@0", ADDRESSOF( getVersion ));
	GetProcAddress(lib, "_FreeImage_GetCopyrightMessage@0", ADDRESSOF( getCopyrightMessage ));
	(* Message output functions *)
	GetProcAddress(lib, "_FreeImage_SetOutputMessage@4", ADDRESSOF( SetOutputMessage ));
	GetProcAddress(lib, "_FreeImage_SetOutputMessageStdCall@4", ADDRESSOF( SetOutputMessageStdCall ));
	
	(* Allocate / Clone / Unload routines*)
	GetProcAddress(lib, "_FreeImage_Allocate@24", ADDRESSOF( Allocate ));
	GetProcAddress(lib, "_FreeImage_AllocateT@28", ADDRESSOF( AllocateT ));
	GetProcAddress(lib, "_FreeImage_Clone@4", ADDRESSOF( Clone ));
	GetProcAddress(lib, "_FreeImage_Unload@4", ADDRESSOF( Unload ));
	
	(* Header loading routines *)
	GetProcAddress(lib, "_FreeImage_HasPixels@4", ADDRESSOF( HasPixels ));
	
	(* Load/Save routines *)	
	GetProcAddress(lib, "_FreeImage_Load@12", ADDRESSOF( Load ));

	GetProcAddress(lib, "_FreeImage_Save@16", ADDRESSOF( Save ));

	(* Memory I/O stream routines *)
	GetProcAddress(lib, "_FreeImage_OpenMemory@8", ADDRESSOF( OpenMemory));
	GetProcAddress(lib, "_FreeImage_CloseMemory@4", ADDRESSOF( CloseMemory));
	GetProcAddress(lib, "_FreeImage_LoadFromMemory@12", ADDRESSOF( LoadFromMemory));
	GetProcAddress(lib, "_FreeImage_SaveToMemory@16", ADDRESSOF( SaveToMemory));
	GetProcAddress(lib, "_FreeImage_TellMemory@4", ADDRESSOF( TellMemory));
	GetProcAddress(lib, "_FreeImage_SeekMemory@12", ADDRESSOF( SeekMemory));
	GetProcAddress(lib, "_FreeImage_AcquireMemory@12", ADDRESSOF( AcquireMemory));
	GetProcAddress(lib, "_FreeImage_ReadMemory@16", ADDRESSOF( ReadMemory));
	GetProcAddress(lib, "_FreeImage_WriteMemory@16", ADDRESSOF( WriteMemory));
	GetProcAddress(lib, "_FreeImage_LoadMultiBitmapFromMemory@12", ADDRESSOF( LoadMultiBitmapFromMemory));
	GetProcAddress(lib, "_FreeImage_SaveMultiBitmapToMemory@16", ADDRESSOF( SaveMultiBitmapToMemory));
	
	(* Plugin Interface *)
	GetProcAddress(lib, "_FreeImage_GetFIFCount@0", ADDRESSOF( GetFIFCount));
	GetProcAddress(lib, "_FreeImage_SetPluginEnabled@8", ADDRESSOF( SetPluginEnabled));
	GetProcAddress(lib, "_FreeImage_IsPluginEnabled@4", ADDRESSOF( IsPluginEnabled));
	GetProcAddress(lib, "_FreeImage_GetFIFFromFormat@4", ADDRESSOF( GetFIFFromFormat));
	GetProcAddress(lib, "_FreeImage_GetFIFFromMime@4", ADDRESSOF( GetFIFFromMime));
	GetProcAddress(lib, "_FreeImage_GetFormatFromFIF@4", ADDRESSOF( getFormatFromFIF));
	GetProcAddress(lib, "_FreeImage_GetFIFExtensionList@4", ADDRESSOF( getFIFExtensionList));
	GetProcAddress(lib, "_FreeImage_GetFIFDescription@4", ADDRESSOF( getFIFDescription));
	GetProcAddress(lib, "_FreeImage_GetFIFRegExpr@4", ADDRESSOF( getFIFRegExpr));
	GetProcAddress(lib, "_FreeImage_GetFIFFromFilename@4", ADDRESSOF( GetFIFFromFilename));
	GetProcAddress(lib, "_FreeImage_GetFIFFromFilenameU@4", ADDRESSOF( GetFIFFromFilenameU));
	GetProcAddress(lib, "_FreeImage_FIFSupportsReading@4", ADDRESSOF( FIFSupportsReading));
	GetProcAddress(lib, "_FreeImage_FIFSupportsWriting@4", ADDRESSOF( FIFSupportsWriting));
	GetProcAddress(lib, "_FreeImage_FIFSupportsExportBPP@8", ADDRESSOF( FIFSupportsExportBPP));
	GetProcAddress(lib, "_FreeImage_FIFSupportsExportType@8", ADDRESSOF( FIFSupportsExportType));
	GetProcAddress(lib, "_FreeImage_FIFSupportsICCProfiles@4", ADDRESSOF( FIFSupportsICCProfiles));
	GetProcAddress(lib, "_FreeImage_FIFSupportsNoPixels@4", ADDRESSOF( FIFSupportsNoPixels));
	
	(* Multipaging interface *)

	GetProcAddress(lib, "_FreeImage_OpenMultiBitmap@24", ADDRESSOF( OpenMultiBitmap));
	GetProcAddress(lib, "_FreeImage_OpenMultiBitmapFromHandle@16", ADDRESSOF( OpenMultiBitmapFromHandle));
	GetProcAddress(lib, "_FreeImage_SaveMultiBitmapToHandle@20", ADDRESSOF( SaveMultiBitmapToHandle));
	GetProcAddress(lib, "_FreeImage_CloseMultiBitmap@8", ADDRESSOF( CloseMultiBitmap));
	GetProcAddress(lib, "_FreeImage_GetPageCount@4", ADDRESSOF( GetPageCount));
	GetProcAddress(lib, "_FreeImage_AppendPage@8", ADDRESSOF( AppendPage));
	GetProcAddress(lib, "_FreeImage_InsertPage@12", ADDRESSOF( InsertPage));
	GetProcAddress(lib, "_FreeImage_DeletePage@8", ADDRESSOF( DeletePage));
	GetProcAddress(lib, "_FreeImage_LockPage@8", ADDRESSOF( LockPage));
	GetProcAddress(lib, "_FreeImage_UnlockPage@12", ADDRESSOF( UnlockPage));
	GetProcAddress(lib, "_FreeImage_MovePage@12", ADDRESSOF( MovePage));
	GetProcAddress(lib, "_FreeImage_GetLockedPageNumbers@12", ADDRESSOF( GetLockedPageNumbers));

	(* Filetype request routines *)
	GetProcAddress(lib, "_FreeImage_GetFileType@8", ADDRESSOF( GetFileType));
	GetProcAddress(lib, "_FreeImage_GetFileTypeU@8", ADDRESSOF( GetFileTypeU));
	GetProcAddress(lib, "_FreeImage_GetFileTypeFromMemory@8", ADDRESSOF( GetFileTypeFromMemory));
	GetProcAddress(lib, "_FreeImage_GetFileTypeFromHandle@12", ADDRESSOF( GetFileTypeFromHandle));

	(* Image type request routine *)	
	GetProcAddress(lib, "_FreeImage_GetImageType@4", ADDRESSOF( GetImageType));
	
	(* FreeImage helper routines *)
	GetProcAddress(lib, "_FreeImage_IsLittleEndian@0", ADDRESSOF( IsLittleEndian));
	GetProcAddress(lib, "_FreeImage_LookupX11Color@16", ADDRESSOF( LookupX11Color));
	GetProcAddress(lib, "_FreeImage_LookupSVGColor@16", ADDRESSOF( LookupSVGColor));
		
	(* Pixel access routines *)
	GetProcAddress(lib, "_FreeImage_GetBits@4", ADDRESSOF( GetBits));
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLine));
	
	GetProcAddress(lib, "_FreeImage_GetPixelIndex@16", ADDRESSOF( GetPixelIndex));
	GetProcAddress(lib, "_FreeImage_GetPixelColor@16", ADDRESSOF( GetPixelColor));
	GetProcAddress(lib, "_FreeImage_SetPixelIndex@16", ADDRESSOF( SetPixelIndex));
	GetProcAddress(lib, "_FreeImage_SetPixelColor@16", ADDRESSOF( SetPixelColor));

(*
	GetProcAddress(lib, "_FreeImage_GetScanLine@8", ADDRESSOF( GetScanLineRGB));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLineRGBA));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLine16));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLine32));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLineFloat));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLineDouble));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLineComplex));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLineFRGB16));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLineFRGBA16));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLineFRGBF));
	GetProcAddress(lib, "_FreeImage_GetScanLine", ADDRESSOF( GetScanLineFRGBAF));
	*)	

	(* DIB info routines *)
	GetProcAddress(lib, "_FreeImage_GetColorsUsed@4", ADDRESSOF( GetColorsUsed));
	GetProcAddress(lib, "_FreeImage_GetBPP@4", ADDRESSOF( GetBPP));
	GetProcAddress(lib, "_FreeImage_GetWidth@4", ADDRESSOF( GetWidth));
	GetProcAddress(lib, "_FreeImage_GetHeight@4", ADDRESSOF( GetHeight));
	GetProcAddress(lib, "_FreeImage_GetLine@4", ADDRESSOF( GetLine));
	GetProcAddress(lib, "_FreeImage_GetPitch@4", ADDRESSOF( GetPitch));
	GetProcAddress(lib, "_FreeImage_GetDIBSize@4", ADDRESSOF( GetDIBSize));
	GetProcAddress(lib, "_FreeImage_GetPalette@4", ADDRESSOF( GetPalette));
	GetProcAddress(lib, "_FreeImage_GetDotsPerMeterX@4", ADDRESSOF( GetDotsPerMeterX));
	GetProcAddress(lib, "_FreeImage_GetDotsPerMeterY@4", ADDRESSOF( GetDotsPerMeterY));
	GetProcAddress(lib, "_FreeImage_SetDotsPerMeterX@8", ADDRESSOF( SetDotsPerMeterX));
	GetProcAddress(lib, "_FreeImage_SetDotsPerMeterY@8", ADDRESSOF( SetDotsPerMeterY));
	GetProcAddress(lib, "_FreeImage_GetInfoHeader@4", ADDRESSOF( GetInfoHeader));
	GetProcAddress(lib, "_FreeImage_GetInfo@4", ADDRESSOF( GetInfo));
	GetProcAddress(lib, "_FreeImage_GetColorType@4", ADDRESSOF( GetColorType));
	GetProcAddress(lib, "_FreeImage_GetRedMask@4", ADDRESSOF( GetRedMask));
	GetProcAddress(lib, "_FreeImage_GetGreenMask@4", ADDRESSOF( GetGreenMask));
	GetProcAddress(lib, "_FreeImage_GetBlueMask@4", ADDRESSOF( GetBlueMask));
	GetProcAddress(lib, "_FreeImage_GetTransparencyCount@4", ADDRESSOF( GetTransparencyCount));
	GetProcAddress(lib, "_FreeImage_GetTransparencyTable@4", ADDRESSOF( GetTransparencyTable));
	GetProcAddress(lib, "_FreeImage_SetTransparent@8", ADDRESSOF( SetTransparent));
	GetProcAddress(lib, "_FreeImage_SetTransparencyTable@12", ADDRESSOF( SetTransparencyTable));
	GetProcAddress(lib, "_FreeImage_IsTransparent@4", ADDRESSOF( IsTransparent));
	GetProcAddress(lib, "_FreeImage_SetTransparentIndex@8", ADDRESSOF( SetTransparentIndex));
	GetProcAddress(lib, "_FreeImage_GetTransparentIndex@4", ADDRESSOF( GetTransparentIndex));
	GetProcAddress(lib, "_FreeImage_HasBackgroundColor@4", ADDRESSOF( HasBackgroundColor));
	GetProcAddress(lib, "_FreeImage_GetBackgroundColor@8", ADDRESSOF( GetBackgroundColor));
	GetProcAddress(lib, "_FreeImage_SetBackgroundColor@8", ADDRESSOF( SetBackgroundColor));
	GetProcAddress(lib, "_FreeImage_GetThumbnail@4", ADDRESSOF( GetThumbnail));
	GetProcAddress(lib, "_FreeImage_SetThumbnail@8", ADDRESSOF( SetThumbnail));
	
	(* ICC profile routines *)
	GetProcAddress(lib, "_FreeImage_GetICCProfile@4", ADDRESSOF( GetICCProfile));
	GetProcAddress(lib, "_FreeImage_CreateICCProfile@12", ADDRESSOF( CreateICCProfile));
	GetProcAddress(lib, "_FreeImage_DestroyICCProfile@4", ADDRESSOF( DestroyICCProfile));	

	(* Line conversion routines *)
	
	(* Smart conversion routines *)
	GetProcAddress(lib, "_FreeImage_ConvertTo4Bits@4", ADDRESSOF( ConvertTo4Bits));
	GetProcAddress(lib, "_FreeImage_ConvertTo8Bits@4", ADDRESSOF( ConvertTo8Bits));
	GetProcAddress(lib, "_FreeImage_ConvertToGreyscale@4", ADDRESSOF( ConvertToGreyscale));
	GetProcAddress(lib, "_FreeImage_ConvertTo16Bits555@4", ADDRESSOF( ConvertTo16Bits555));
	GetProcAddress(lib, "_FreeImage_ConvertTo16Bits565@4", ADDRESSOF( ConvertTo16Bits565));

	GetProcAddress(lib, "_FreeImage_ConvertTo24Bits@4", ADDRESSOF( ConvertTo24Bits));
	GetProcAddress(lib, "_FreeImage_ConvertTo32Bits@4", ADDRESSOF( ConvertTo32Bits));
	GetProcAddress(lib, "_FreeImage_ColorQuantize@8", ADDRESSOF( ColorQuantize));
	GetProcAddress(lib, "_FreeImage_ColorQuantizeEx@20", ADDRESSOF( ColorQuantizeEx));
	GetProcAddress(lib, "_FreeImage_Threshold@8", ADDRESSOF( Threshold));

	GetProcAddress(lib, "_FreeImage_Dither@8", ADDRESSOF( Dither));
	GetProcAddress(lib, "_FreeImage_ConvertFromRawBits@36", ADDRESSOF( ConvertFromRawBits));
	GetProcAddress(lib, "_FreeImage_ConvertToRawBits@32", ADDRESSOF( ConvertToRawBits));
	GetProcAddress(lib, "_FreeImage_ConvertToFloat@4", ADDRESSOF( ConvertToFloat));

	GetProcAddress(lib, "_FreeImage_ConvertToRGBF@4", ADDRESSOF( ConvertToRGBF));
	GetProcAddress(lib, "_FreeImage_ConvertToUINT16@4", ADDRESSOF( ConvertToUINT16));
	GetProcAddress(lib, "_FreeImage_ConvertToRGB16@4", ADDRESSOF( ConvertToRGB16));


	GetProcAddress(lib, "_FreeImage_ConvertToStandardType@8", ADDRESSOF( ConvertToStandardType));
	GetProcAddress(lib, "_FreeImage_ConvertToType@12", ADDRESSOF( ConvertToType));

	(* tone mapping operators *)
	GetProcAddress(lib, "_FreeImage_ToneMapping@24", ADDRESSOF( ToneMapping));
	GetProcAddress(lib, "_FreeImage_TmoDrago03@20", ADDRESSOF( TmoDrago03));
	GetProcAddress(lib, "_FreeImage_TmoReinhard05@20", ADDRESSOF( TmoReinhard05));
	GetProcAddress(lib, "_FreeImage_TmoReinhard05Ex@36", ADDRESSOF( TmoReinhard05Ex));
	GetProcAddress(lib, "_FreeImage_TmoFattal02@20", ADDRESSOF( TmoFattal02));
	
	(* ZLib interface *)
	GetProcAddress(lib, "_FreeImage_ZLibCompress@16", ADDRESSOF( ZLibCompress));
	GetProcAddress(lib, "_FreeImage_ZLibUncompress@16", ADDRESSOF( ZLibUncompress));
	GetProcAddress(lib, "_FreeImage_ZLibGZip@16", ADDRESSOF( ZLibGZip));
	GetProcAddress(lib, "_FreeImage_ZLibGUnzip@16", ADDRESSOF( ZLibGUnzip));
	GetProcAddress(lib, "_FreeImage_ZLibCRC32@12", ADDRESSOF( ZLibCRC32));
	
	(* Metadata routines *)
		(* tag creation / destruction *)
		GetProcAddress(lib, "_FreeImage_CreateTag@0", ADDRESSOF( CreateTag));
		GetProcAddress(lib, "_FreeImage_DeleteTag@4", ADDRESSOF( DeleteTag));
		GetProcAddress(lib, "_FreeImage_CloneTag@4", ADDRESSOF( CloneTag));
		(* tag getters and setters *)
		GetProcAddress(lib, "_FreeImage_GetTagKey@4", ADDRESSOF( getTagKey));
		GetProcAddress(lib, "_FreeImage_GetTagDescription@4", ADDRESSOF( getTagDescription));
		GetProcAddress(lib, "_FreeImage_GetTagID@4", ADDRESSOF( GetTagID));
		GetProcAddress(lib, "_FreeImage_GetTagType@4", ADDRESSOF( GetTagType));
		GetProcAddress(lib, "_FreeImage_GetTagCount@4", ADDRESSOF( GetTagCount));
		GetProcAddress(lib, "_FreeImage_GetTagLength@4", ADDRESSOF( GetTagLength));
		GetProcAddress(lib, "_FreeImage_GetTagValue@4", ADDRESSOF( GetTagValue));
		GetProcAddress(lib, "_FreeImage_SetTagKey@8", ADDRESSOF( SetTagKey));
		GetProcAddress(lib, "_FreeImage_SetTagDescription@8", ADDRESSOF( SetTagDescription));
		GetProcAddress(lib, "_FreeImage_SetTagID@8", ADDRESSOF( SetTagID));
		GetProcAddress(lib, "_FreeImage_SetTagType@8", ADDRESSOF( SetTagType));
		GetProcAddress(lib, "_FreeImage_SetTagCount@8", ADDRESSOF( SetTagCount));
		GetProcAddress(lib, "_FreeImage_SetTagLength@8", ADDRESSOF( SetTagLength));
		GetProcAddress(lib, "_FreeImage_SetTagValue@8", ADDRESSOF( SetTagValue));
		(* iterator *)
		GetProcAddress(lib, "_FreeImage_FindFirstMetadata@12", ADDRESSOF( FindFirstMetadata));
		GetProcAddress(lib, "_FreeImage_FindNextMetadata@8", ADDRESSOF( FindNextMetadata));	
		GetProcAddress(lib, "_FreeImage_FindCloseMetadata@4", ADDRESSOF( FindCloseMetadata));

		(* metadata setter and getter *)
		GetProcAddress(lib, "_FreeImage_SetMetadata@16", ADDRESSOF( SetMetadata));
		GetProcAddress(lib, "_FreeImage_GetMetadata@16", ADDRESSOF( GetMetadata));				
		(*  helpers *)
		GetProcAddress(lib, "_FreeImage_GetMetadataCount@8", ADDRESSOF( GetMetadataCount));	
		GetProcAddress(lib, "_FreeImage_CloneMetadata@8", ADDRESSOF( CloneMetadata));			
		(*  tag to C string conversion *)
		GetProcAddress(lib, "_FreeImage_TagToString@12", ADDRESSOF( tagToString));		

	(* Image manipulation toolkit *)
	(* rotation and flipping *)
	GetProcAddress(lib, "_FreeImage_RotateClassic@12", ADDRESSOF( RotateClassic));
	GetProcAddress(lib, "_FreeImage_Rotate@16", ADDRESSOF( Rotate));
	GetProcAddress(lib, "_FreeImage_RotateEx@48", ADDRESSOF( RotateEx));
	GetProcAddress(lib, "_FreeImage_FlipHorizontal@4", ADDRESSOF( FlipHorizontal));
	GetProcAddress(lib, "_FreeImage_FlipVertical@4", ADDRESSOF( FlipVertical));
	GetProcAddress(lib, "_FreeImage_JPEGTransform@16", ADDRESSOF( JPEGTransform));
	GetProcAddress(lib, "_FreeImage_JPEGTransformU@16", ADDRESSOF( JPEGTransformU));
	
	(* upsampling / downsampling *)
	GetProcAddress(lib, "_FreeImage_Rescale@16", ADDRESSOF( Rescale));
	GetProcAddress(lib, "_FreeImage_MakeThumbnail@12", ADDRESSOF( MakeThumbnail));
	(* color manipulation routines (point operations)*)
	GetProcAddress(lib, "_FreeImage_AdjustCurve@12", ADDRESSOF( AdjustCurve));
	GetProcAddress(lib, "_FreeImage_AdjustGamma@12", ADDRESSOF( AdjustGamma));
	GetProcAddress(lib, "_FreeImage_AdjustBrightness@12", ADDRESSOF( AdjustBrightness));
	GetProcAddress(lib, "_FreeImage_AdjustContrast@12", ADDRESSOF( AdjustContrast));
	GetProcAddress(lib, "_FreeImage_Invert@4", ADDRESSOF( Invert));
	GetProcAddress(lib, "_FreeImage_GetHistogram@12", ADDRESSOF( GetHistogram));
	GetProcAddress(lib, "_FreeImage_GetAdjustColorsLookupTable@32", ADDRESSOF( GetAdjustColorsLookupTable));
	GetProcAddress(lib, "_FreeImage_AdjustColors@32", ADDRESSOF( AdjustColors));
	GetProcAddress(lib, "_FreeImage_ApplyColorMapping@24", ADDRESSOF( ApplyColorMapping));
	GetProcAddress(lib, "_FreeImage_SwapColors@16", ADDRESSOF( SwapColors));
	GetProcAddress(lib, "_FreeImage_ApplyPaletteIndexMapping@20", ADDRESSOF( ApplyPaletteIndexMapping));
	GetProcAddress(lib, "_FreeImage_SwapPaletteIndices@12", ADDRESSOF( SwapPaletteIndices));
	(* channel processing routines*)
	GetProcAddress(lib, "_FreeImage_GetChannel@8", ADDRESSOF( GetChannel));
	GetProcAddress(lib, "_FreeImage_SetChannel@12", ADDRESSOF( SetChannel));
	GetProcAddress(lib, "_FreeImage_GetComplexChannel@8", ADDRESSOF( GetComplexChannel));
	GetProcAddress(lib, "_FreeImage_SetComplexChannel@12", ADDRESSOF( SetComplexChannel));
	(* copy / paste / composite routines*)
	GetProcAddress(lib, "_FreeImage_Copy@20", ADDRESSOF( Copy));
	GetProcAddress(lib, "_FreeImage_Paste@20", ADDRESSOF( Paste));
	GetProcAddress(lib, "_FreeImage_Composite@16", ADDRESSOF( Composite));
	GetProcAddress(lib, "_FreeImage_JPEGCrop@24", ADDRESSOF( JPEGCrop));
	GetProcAddress(lib, "_FreeImage_JPEGCropU@24", ADDRESSOF( JPEGCropU));
	GetProcAddress(lib, "_FreeImage_PreMultiplyWithAlpha@4", ADDRESSOF( PreMultiplyWithAlpha));
	(*  background filling routines *)
	GetProcAddress(lib, "_FreeImage_FillBackground@12", ADDRESSOF( FillBackground));
	GetProcAddress(lib, "_FreeImage_EnlargeCanvas@28", ADDRESSOF( EnlargeCanvas));
(*	GetProcAddress(lib, "_FreeImage_AllocateEx@36", ADDRESSOF( AllocateEx));
	GetProcAddress(lib, "_FreeImage_AllocateExT@40", ADDRESSOF( AllocateExT)); *)
	(* miscellaneous algorithms*)
	GetProcAddress(lib, "_FreeImage_MultigridPoissonSolver@8", ADDRESSOF( MultigridPoissonSolver));
	
END InitFunctions;


PROCEDURE OnClose;
VAR res: LONGINT;
BEGIN
	IF lib # Kernel32.NULL THEN
		res := Kernel32.FreeLibrary(lib);
		KernelLog.String(libname); KernelLog.String(" unloaded."); KernelLog.Ln;
	END;
END OnClose;

(* utilities  *)

(* Get string from address  *)
PROCEDURE GetStringFromAddr*(adr: ADDRESS): Strings.String;
VAR  sadr: ADDRESS;
	cnt: LONGINT;
	ch: CHAR;
	s: Strings.String;
BEGIN
	IF adr # 0 THEN
		(* find length  *)
		sadr := adr;
		cnt  := 0;		
		SYSTEM.GET(sadr,ch);
		WHILE (ch # 0X) DO  INC(cnt); INC(sadr); SYSTEM.GET(sadr,ch); END;
		
		(* then, copy string *)
		NEW(s, cnt+1);
		SYSTEM.MOVE(adr, ADDRESSOF(s[0]), cnt);
	END;
	
	RETURN s;
END GetStringFromAddr;

(* wrapper procedure for getVersion() *)
PROCEDURE GetVersion*():Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getVersion();
	v := GetStringFromAddr(adr);
	RETURN v;
END GetVersion;

(* wrapper procedure for getCopyrightMessage() *)
PROCEDURE GetCopyrightMessage*():Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getCopyrightMessage();
	v := GetStringFromAddr(adr);
	RETURN v;
END GetCopyrightMessage;

(* wrapper procedure for getFormatFromFIF *)
PROCEDURE GetFormatFromFIF* (fif: IMAGE_FORMAT): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getFormatFromFIF(fif);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetFormatFromFIF;

(* wrapper procedure for getFIFExtensionList *)
PROCEDURE GetFIFExtensionList* (fif: IMAGE_FORMAT): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getFIFExtensionList(fif);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetFIFExtensionList;

(* wrapper procedure for getFIFDescription *)
PROCEDURE GetFIFDescription* (fif: IMAGE_FORMAT): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getFIFDescription(fif);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetFIFDescription;

(* wrapper procedure for getFIFRegExpr *)
PROCEDURE GetFIFRegExpr* (fif: IMAGE_FORMAT): Strings.String;
VAR adr: ADDRESS;
	v: Strings.String;
BEGIN
	adr := getFIFRegExpr(fif);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetFIFRegExpr;

(* wrapper procedure for getTagKey *)
PROCEDURE GetTagKey*(tag: FITAG): Strings.String;
VAR v: Strings.String;
	adr: ADDRESS;
BEGIN
	adr := getTagKey(tag);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetTagKey;

(* wrapper procedure for getTagDescription *)
PROCEDURE GetTagDescription*(tag: FITAG): Strings.String;
VAR v: Strings.String;
	adr: ADDRESS;
BEGIN
	adr := getTagDescription(tag);
	v := GetStringFromAddr(adr);
	RETURN v;
END GetTagDescription;

(* wrapper procedure for tagToString *)
PROCEDURE TagToString*(model: IMAGE_MDMODEL; tag: FITAG): Strings.String;
VAR v: Strings.String;
	adr: ADDRESS;
BEGIN
	adr := tagToString(model, tag, NIL);
	v := GetStringFromAddr(adr);
	RETURN v;
END TagToString;

(* Utilitiy functions, load file fname as FIBITMAP with flags *)
PROCEDURE LoadImage* (CONST fname: ARRAY OF CHAR; flags: IMAGE_FLAGS): FIBITMAP;
VAR
	type: IMAGE_FORMAT;
	tdib: FIBITMAP;
BEGIN
	type := GetFileType(fname, 0);

	IF type = FIF_UNKNOWN THEN
		KernelLog.String("Unkonwn Format: "); KernelLog.String(fname); 
		KernelLog.Int(type, 5); KernelLog.Ln; 
		type := GetFIFFromFilename(fname)
	END;

	IF (type # FIF_UNKNOWN) & FIFSupportsReading(type) THEN
		(* KernelLog.Int(type, 0); KernelLog.String(" Supported reading: "); KernelLog.Ln; *)
		tdib := Load(type, fname, flags);
		RETURN tdib
	ELSE
		RETURN NIL
	END
END LoadImage;

(* save FITMAP image to a file named fname *)
PROCEDURE SaveImage* (dib: FIBITMAP; CONST fname: ARRAY OF CHAR; flags: IMAGE_FLAGS): BOOLEAN;
VAR
	cansave, success: BOOLEAN;
	fif: IMAGE_FORMAT;
	type: IMAGE_TYPE;
	bpp: LONGINT;
BEGIN
	success := FALSE;
	fif := GetFIFFromFilename(fname);
	IF fif # FIF_UNKNOWN THEN
		type := GetImageType(dib);
		IF type = FIT_BITMAP THEN
			bpp := GetBPP(dib);
			cansave := FIFSupportsWriting(fif) & FIFSupportsExportBPP(fif, bpp)
		ELSE
			cansave := FIFSupportsExportType(fif, type)
		END;
		IF cansave THEN
			success := Save(fif, dib, fname, flags)
		END
	END;
	RETURN success
END SaveImage;

(* called by FreeImage when error occurs *)
PROCEDURE {WINAPI} MyOutputMessageFunction(fif: IMAGE_FORMAT;  msg: Strings.String);
BEGIN	
	IF msg # NIL THEN
		KernelLog.String("FreeImage ERROR: "); KernelLog.String(msg^); 
		KernelLog.String(", FIF_FORMAT= "); KernelLog.Int(fif, 0);
		KernelLog.Ln; 
	END;	
END MyOutputMessageFunction;

BEGIN
	InitFunctions();
	Modules.InstallTermHandler(OnClose);
	SetOutputMessageStdCall(MyOutputMessageFunction);
END FreeImageDll.
