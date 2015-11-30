This subsystem contains WinAos and LinuxAos wrappers for FreeImage (v3.15.4)
Date 20-2-2013
#========================================================================================
# WHAT IS FREEIMAGE
#========================================================================================
FreeImage is an Open Source library project for developers who would like to support
popular graphics image formats like PNG, BMP, JPEG, TIFF and others as needed by today's 
multimedia applications. FreeImage is easy to use, fast, multithreading safe, compatible with all 
32-bit versions of Windows, and cross-platform (works both with Linux and Mac OS X).

#========================================================================================
# Installation
#========================================================================================
#WinAos: 
	Get the FreeImage.dll (v3.15.4) from http://freeimage.sourceforge.net/
	and put it 'Windows\System32' or 'Work' directory. 

#Linux: 
	Install 32 bit libfreeimage3 package using your package manager, for example;

      >	 sudo apt-get install libfreeimage3


Library functions are described in detail in FreeImage3154.pdf file.


#========================================================================================
# Compile the module list:
#========================================================================================
# LinuxAos:	
 Compiler.Compile Unix.FreeImageDll.Mod ~

# WinAos:	
 Compiler.Compile Win32.FreeImageDll.Mod ~
 
# examples, compile;
Compiler.Compile FreeImageUtils.Mod TestFreeImage.Mod TestFreeMeta.Mod TestFreeMemIO~ 

# Examples, run:

TestFreeImage.GetFormats ~
TestFreeImage.MakeFresnel ~
TestFreeImage.Open  <yourimagefile> ~ 

#Unload the module list:
SystemTools.FreeDownTo FreeImageDll ~


#========================================================================================
FEATURES
#========================================================================================
    reference: http://freeimage.sourceforge.net/

    * Ease of use. The library has been designed to be extremely simple in use. 
	Our motto is: make difficult things simple instead of simple things difficult.

    * Supports many formats, such as:
          o BMP files [reading, writing]
          o DDS files [reading]
          o Dr. Halo files [reading] *
          o GIF files [reading, writing]
          o HDR files [reading, writing]
          o ICO files [reading, writing]
          o IFF files [reading]
          o JBIG [reading, writing] **
          o JNG files [reading]
          o JPEG/JIF files [reading, writing]
          o KOALA files [reading]
          o LBM files [reading]
          o Kodak PhotoCD files [reading]
          o MNG files [reading]
          o PCX files [reading]
          o PBM files [reading, writing]
          o PGM files [reading, writing]
          o PNG files [reading, writing]
          o PPM files [reading, writing]
          o PhotoShop files [reading]
          o Sun RAS files [reading]
          o TARGA files [reading, writing]
          o TIFF files [reading, writing]
          o WBMP files [reading, writing]
          o XBM files [reading]
          o XPM files [reading, writing] 

      * only grayscale
      ** only via external plugin, might require a commercial license

    * Not limited to the local PC. The unique FreeImageIO structure makes it possible to load your images from 
    virtually anywhere. Possibilities include standalone files, memory, cabinet files and the Internet, all this without 
    recompiling the library!

    * Plugin driven. The internal engine is made completely modular using a clever plugin system. Easily write new plugins 
    and store them in DLL files or embed the plugins directly into your application!

    * Color conversion. FreeImage provides many functions to convert a bitmap from one bitdepth to another. 
    The library supports 1-, 4-, 8-, 16, 24- and 32-bit images, as well as integer, real and complex images.

    * Support for High Dynamic Range images. FreeImage supports RGB float images as well a 48-bit HDR images and 
    provides tone mapping operators to convert these images to 24-bit LDR images.

    * Directly access bitmap bits and palette. Functions are provided which allow you to directly access the bitmap 
    palette (if available) and bitmap bits.

    * Metadata support. Parse common metadata models attached to your bitmap. FreeImage supports Comments, 
    Exif (including GPS and maker notes), IPTC, Adobe XMP and GeoTIFF metadata models.

    * Written in portable C++, should compile on all 32-bit Windows, Linux and Mac OSX systems. 
    Full source code is provided.

    * Open Source Dual-License. You can choose the license that has the most advantages for you: 
    Use the liberal FreeImage Public License to use FreeImage commercially or the GNU General Public License to use 
    FreeImage into your open source project.

    * Easily integrates into DirectX and OpenGL. Only a minimum of programming is necessary to store a FreeImage bitmap 
    into a DirectDraw surface or to use FreeImage to load your Direct3D/OpenGL textures.

    * Provides basic image manipulation routines such as rotation, resizing, flipping or color adjustments, as well as lossless 
    JPEG transformations.

    * Provides test programs to "show-off" the library, compilable and startable on Windows 95, 98, NT, 2000 or on Linux. 
    
