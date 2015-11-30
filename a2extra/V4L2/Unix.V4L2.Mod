MODULE V4L2; (** AUTHOR "fnecati"; PURPOSE "video4linux2 definitions and structures "; *)

IMPORT Unix;
(* NOTE: Some union structures are not translated and tested yet *)

TYPE 
	__u64* = HUGEINT;
	__s64* = HUGEINT;
	__u32* = LONGINT;
	__s32* = LONGINT;
	__u16* = INTEGER;
	__u8* = CHAR;
(* ----------------- *)
(* ioctl.h *)

	(* ioctl command encoding: 32 bits total, command in lower 16 bits,
	 * size of the parameter structure in the lower 14 bits of the
	 * upper 16 bits.
	 * Encoding the size of the parameter structure in the ioctl request
	 * is useful for catching programs compiled with old versions
	 * and to avoid overwriting user space outside the user buffer area.
	 * The highest 2 bits are reserved for indicating the ``access mode''.
	 * NOTE: This limits the max parameter size to 16kB -1 !
	 *)
	
	(*
	 * The following is for compatibility across the various Linux
	 * platforms.  The generic ioctl numbering scheme doesn't really enforce
	 * a type field.  De facto, however, the top 8 bits of the lower 16
	 * bits are indeed used as a type field, so we might just as well make
	 * this explicit here.  Please be sure to use the decoding macros
	 * below from now on.
	 *)
	CONST IOC_NRBITS* = 8;
		 IOC_TYPEBITS* = 8;
	
	(*
	 * Let any architecture override either of the following before
	 * including this file.
	 *)
	
		IOC_SIZEBITS* =	14;
		IOC_DIRBITS* =	2;
		
	 IOC_NRMASK* = LSH(1, IOC_NRBITS)-1;
	 IOC_TYPEMASK* = LSH(1 ,IOC_TYPEBITS)-1;
	 IOC_SIZEMASK* = LSH(1, IOC_SIZEBITS)-1;
	 IOC_DIRMASK* = LSH(1, IOC_DIRBITS)-1;
	
	 IOC_NRSHIFT* = 0;
	 IOC_TYPESHIFT* = IOC_NRSHIFT+IOC_NRBITS;
	 IOC_SIZESHIFT* = IOC_TYPESHIFT+IOC_TYPEBITS;
	 IOC_DIRSHIFT* = IOC_SIZESHIFT+IOC_SIZEBITS;
	
	(*
	 * Direction bits, which any architecture can choose to override
	 * before including this file.
	 *)
	
	IOC_NONE* = 0;
	
	IOC_WRITE* = 1;
	
	IOC_READ* = 2;


(* ----------------- *)

	(*! video2.h *)
	(*
	 * Common stuff for both V4L1 and V4L2
	 * Moved from videodev.h
	 *)
CONST 
	VIDEO_MAX_FRAME * = 32;
	VIDEO_MAX_PLANES* = 8;
	
	(* These defines are V4L1 specific and should not be used with the V4L2 API!
	   They will be removed from this header in the future. *)

	VID_TYPE_CAPTURE * = 1;	(* Can capture *)
	 VID_TYPE_TUNER * = 2;	(* Can tune *)
	 VID_TYPE_TELETEXT * = 4;	(* Does teletext *)
	 VID_TYPE_OVERLAY * = 8;	(* Overlay onto frame buffer *)
	 VID_TYPE_CHROMAKEY * = 16;	(* Overlay by chromakey *)
	 VID_TYPE_CLIPPING * = 32;	(* Can clip *)
	 VID_TYPE_FRAMERAM * = 64;	(* Uses the frame buffer memory *)
	 VID_TYPE_SCALES * = 128;	(* Scalable *)
	 VID_TYPE_MONOCHROME * = 256;	(* Monochrome only *)
	 VID_TYPE_SUBCAPTURE * = 512;	(* Can capture subareas of the image *)
	 VID_TYPE_MPEG_DECOxDER * = 1024;	(*! Can decode MPEG streams *)
	 VID_TYPE_MPEG_ENCOxDER * = 2048;	(*! Can encode MPEG streams *)
	 VID_TYPE_MJPEG_DECOxDER * = 4096;	(*! Can decode MJPEG streams *)
	 VID_TYPE_MJPEG_ENCOxDER * = 8192;	(*! Can encode MJPEG streams *)
	
	(*	M I S C E L L A N E O U S  *)

	(*!	E N U M S  *)

TYPE v4l2_field * = LONGINT; (*enum*)
	CONST
	V4L2_FIELD_ANY      * = 0; (* driver can choose from none,
						 top, bottom, interlaced
						 depending on whatever it thinks
						 is approximate ... *)
	V4L2_FIELD_NONE * = 1; (* this device has no fields ... *)
	V4L2_FIELD_TOP * = 2; (* top field only *)
	V4L2_FIELD_BOTTOM * = 3; (* bottom field only *)
	V4L2_FIELD_INTERLACED * = 4; (* both fields interlaced *)
	V4L2_FIELD_SEQ_TB * = 5; (* both fields sequential into one
						 buffer, top-bottom order *)
	V4L2_FIELD_SEQ_BT * = 6; (* same as above + bottom-top order *)
	V4L2_FIELD_ALTERNATE * = 7; (* both fields alternating into
						 separate buffers *)
	V4L2_FIELD_INTERLACED_TB * = 8; (* both fields interlaced, top field
						 first and the top field is
						 transmitted first *)
	V4L2_FIELD_INTERLACED_BT * = 9; (* both fields interlaced, top field
						 first and the bottom field is
						 transmitted first *)

TYPE  v4l2_buf_type * = LONGINT; (*enum*)
CONST V4L2_BUF_TYPE_VIDEO_CAPTURE        * = 1;
		V4L2_BUF_TYPE_VIDEO_OUTPUT         * = 2;
		V4L2_BUF_TYPE_VIDEO_OVERLAY        * = 3;
		V4L2_BUF_TYPE_VBI_CAPTURE          * = 4;
		V4L2_BUF_TYPE_VBI_OUTPUT           * = 5;
		V4L2_BUF_TYPE_SLICED_VBI_CAPTURE   * = 6;
		V4L2_BUF_TYPE_SLICED_VBI_OUTPUT    * = 7;
		(* #if 1 *)
		(* Experimental *)
		V4L2_BUF_TYPE_VIDEO_OUTPUT_OVERLAY * = 8;
		(* #endif*)
		V4L2_BUF_TYPE_PRIVATE * = 080H;
						 
TYPE v4l2_tuner_type * = LONGINT(*enum*);
	CONST 
		V4L2_TUNER_RADIO * = 1;
		V4L2_TUNER_ANALOG_TV * = 2;
		V4L2_TUNER_DIGITAL_TV * = 3;
	
TYPE v4l2_memory * = LONGINT(*enum*);
	CONST 
		V4L2_MEMORY_MMAP * = 1; 
		V4L2_MEMORY_USERPTR * = 2; 
		V4L2_MEMORY_OVERLAY * = 3; 
	
	(* see also http://vektor.theorem.ca/graphics/ycbcr/ *)
TYPE v4l2_colorspace * = LONGINT (*enum*);
	CONST 
		 (* ITU-R 601 -- broadcast NTSC/PAL *)
		V4L2_COLORSPACE_SMPTE170M * = 1;
		
		 (* 1125-Line (US) HDTV *)
		V4L2_COLORSPACE_SMPTE240M * = 2; 
		
		 (* HD and modern captures. *)
		V4L2_COLORSPACE_REC709 * = 3; 
		
		 (* broken BT878 extents (601, luma range 16-253 instead of 16-235) *)
		V4L2_COLORSPACE_BT878 * = 4; 
		
		 (* These should be useful.  Assume 601 extents. *)
		V4L2_COLORSPACE_470_SYSTEM_M * = 5;
		V4L2_COLORSPACE_470_SYSTEM_BG * = 6;
		
		 (* I know there will be cameras that send this.  So, this is
		* unspecified chromaticities and full 0-255 on each of the
		* Y'CbCr components
		*)
		V4L2_COLORSPACE_JPEG * = 7;
		
		 (* For RGB colourspaces, this is probably a good start. *)
		V4L2_COLORSPACE_SRGB * = 8;

TYPE v4l2_priority * = LONGINT;(*enum*);
	CONST 
		V4L2_PRIORITY_UNSET * = 0;
		V4L2_PRIORITY_BACKGROUND * = 1;
		V4L2_PRIORITY_INTERACTIVE * = 2;
		V4L2_PRIORITY_RECORD * = 3;
		 V4L2_PRIORITY_DEFAULT * = V4L2_PRIORITY_INTERACTIVE;

	TYPE v4l2_rect * = RECORD 
		left* : __s32;
		top* : __s32;
		width* : __s32;
		height* : __s32;
	END;

	TYPE v4l2_fract * = RECORD 
		numerator* : __u32;
		denominator* : __u32;
	END;
	
	(*!	D R I V E R   C A P A B I L I T I E S  *)
TYPE v4l2_capability *  = RECORD 
		driver* : ARRAY 16 OF __u8;	(* i.e. "bttv" *)
		card* : ARRAY 32 OF __u8;	(* i.e. "Hauppauge WinTV" *)
		bus_info* : ARRAY 32 OF __u8;	(* "PCI:" + pci_name(pci_dev) *)
		version* : __u32;        (* should use KERNEL_VERSION() *)
		capabilities* : __u32;	(* Device capabilities *)
		reserved* : ARRAY 4 OF __u32;
	END;
	
	 (* Values for 'capabilities' field *)
 CONST 
	 V4L2_CAP_VIDEO_CAPTURE * = 000000001H;  (* Is a video capture device *)
	 V4L2_CAP_VIDEO_OUTPUT * = 000000002H;  (* Is a video output device *)
	 V4L2_CAP_VIDEO_OVERLAY * = 000000004H;  (* Can do video overlay *)
	 V4L2_CAP_VBI_CAPTURE * = 000000010H;  (* Is a raw VBI capture device *)
	 V4L2_CAP_VBI_OUTPUT * = 000000020H;  (* Is a raw VBI output device *)
	 V4L2_CAP_SLICED_VBI_CAPTURE * = 000000040H;  (* Is a sliced VBI capture device *)
	 V4L2_CAP_SLICED_VBI_OUTPUT * = 000000080H;  (* Is a sliced VBI output device *)
	 V4L2_CAP_RDS_CAPTURE * = 000000100H;  (* RDS data capture *)
	 V4L2_CAP_VIDEO_OUTPUT_OVERLAY * = 000000200H;  (* Can do video output overlay *)
	 V4L2_CAP_HW_FREQ_SEEK * = 000000400H;  (* Can do hardware frequency seek  *)
	 V4L2_CAP_RDS_OUTPUT * = 000000800H;  (* Is an RDS encoder *)

	 V4L2_CAP_TUNER * = 000010000H;  (* has a tuner *)
	 V4L2_CAP_AUDIO * = 000020000H;  (* has audio support *)
	 V4L2_CAP_RADIO * = 000040000H;  (* is a radio device *)
	 V4L2_CAP_MODULATOR * = 000080000H;  (* has a modulator *)

	 V4L2_CAP_READWRITE * = 001000000H;  (* read/write systemcalls *)
	 V4L2_CAP_ASYNCIO * = 002000000H;  (* async I/O *)
	 V4L2_CAP_STREAMING * = 004000000H;  (* streaming I/O ioctls *)

	(*!	V I D E O   I M A G E   F O R M A T  *)
	TYPE v4l2_pix_format * = RECORD 
		width* : __u32;
		height* : __u32;
		pixelformat* : __u32;
		field* : v4l2_field;
		bytesperline* : __u32;	(* for padding, zero if unused *)
		sizeimage* : __u32;
		colorspace* : v4l2_colorspace;
		priv* : __u32;		(* private data, depends on pixelformat *)
	END;
	
	(*!	F O R M A T   E N U M E R A T I O N  *)
	TYPE v4l2_fmtdesc* = RECORD 
		index* : __u32;             (* Format number      *)
		ztype* : v4l2_buf_type;              (* buffer type        *)
		flags* : __u32;
		description* : ARRAY 32 OF __u8;   (* Description string *)
		pixelformat* : __u32;       (* Format fourcc      *)
		reserved* : ARRAY 4 OF __u32;
	END;
	
CONST 
	V4L2_FMT_FLAG_COMPRESSED * = 00001H;
	V4L2_FMT_FLAG_EMULATED * = 00002H;
	
(*! #if 1 *)

	(* Experimental Frame Size and frame rate enumeration *)
	
	(*!	F R A M E   S I Z E   E N U M E R A T I O N *)
TYPE v4l2_frmsizetypes* = LONGINT(*enum*);
CONST 
		V4L2_FRMSIZE_TYPE_DISCRETE* = 1;
		V4L2_FRMSIZE_TYPE_CONTINUOUS* = 2;
		V4L2_FRMSIZE_TYPE_STEPWISE* = 3;
	
TYPE v4l2_frmsize_discrete * = RECORD 
		width* : __u32;		(* Frame width [pixel] *)
		height* : __u32;		(* Frame height [pixel] *)
	END;

TYPE v4l2_frmsize_stepwise * = RECORD 
		min_width* : __u32;	(* Minimum frame width [pixel] *)
		max_width* : __u32;	(* Maximum frame width [pixel] *)
		step_width* : __u32;	(* Frame width step size [pixel] *)
		min_height* : __u32;	(* Minimum frame height [pixel] *)
		max_height* : __u32;	(* Maximum frame height [pixel] *)
		step_height* : __u32;	(* Frame height step size [pixel] *)
	END;

TYPE Data6 =  ARRAY 24 OF CHAR; (* discrete or stepwise: SIZEOF (v4l2_frmsize_stepwise) *)	
TYPE v4l2_frmsizeenum * = RECORD 
		index* : __u32;		(* Frame size number *)
		pixel_format* : __u32;	(* Pixel format *)
		ztype* : __u32;		(* Frame size type the device supports. *)
				
		uni* : Data6;	(* Frame size *)
(*			discrete: v4l2_frmsize_discrete;
			stepwise: v4l2_frmsize_stepwise;	*)
			
		reserved*: ARRAY 2 OF __u32; 			(* Reserved space for future use *)
	END;
	
	(*
	 *	F R A M E   R A T E   E N U M E R A T I O N
	 *)
	TYPE v4l2_frmivaltypes* = LONGINT (*enum*);
	CONST 
		V4L2_FRMIVAL_TYPE_DISCRETE* = 1;
		V4L2_FRMIVAL_TYPE_CONTINUOUS* = 2;
		V4L2_FRMIVAL_TYPE_STEPWISE* = 3;
	
	
	TYPE v4l2_frmival_stepwise * = RECORD 
		min*: v4l2_fract;		(* Minimum frame interval [s] *)
		max*: v4l2_fract;		(* Maximum frame interval [s] *)
		step*: v4l2_fract;		(* Frame interval step size [s] *)
	END;
	
	TYPE v4l2_frmivalenum * = RECORD 
		index*: __u32;		(* Frame format index *)
		pixel_format*: __u32;	(* Pixel format *)
		width*: __u32;		(* Frame width *)
		height*: __u32;		(* Frame height *)
		ztype*: __u32;		(* Frame interval type the device supports. *)
		
		uni* : Data6; (* Frame interval *)
		(*	discrete: v4l2_fract;
			stepwise: v4l2_frmival_stepwise;*)
		
		reserved*: ARRAY 2 OF __u32; 	(* Reserved space for future use *)
	END;;

(*! #endif *)
	
	(*!	T I M E C O D E *)
	TYPE v4l2_timecode * = RECORD 
		ztype* : __u32;
		flags* : __u32;
		frames* : __u8;
		seconds* : __u8;
		minutes* : __u8;
		hours* : __u8;
		userbits* : ARRAY 4 OF __u8;
	END;
	
	(*  Type  *)
	CONST V4L2_TC_TYPE_24FPS * = 1;
	 V4L2_TC_TYPE_25FPS * = 2;
	 V4L2_TC_TYPE_30FPS * = 3;
	 V4L2_TC_TYPE_50FPS * = 4;
	 V4L2_TC_TYPE_60FPS * = 5;
	
	(*  Flags  *)
	 V4L2_TC_FLAG_DROPFRAME * = 00001H; (* "drop-frame" mode *)
	 V4L2_TC_FLAG_COLORFRAME * = 00002H;
	 V4L2_TC_USERBITS_field * = 0000CH;
	 V4L2_TC_USERBITS_USERDEFINED * = 00000H;
	 V4L2_TC_USERBITS_8BITCHARS * = 00008H;
	(* The above is based on SMPTE timecodes *)


	TYPE v4l2_jpegcompression * = RECORD 
		quality*: INTEGER;
		
		APPn*: INTEGER;              (* Number of APP segment to be written,  must be 0..15 *)
		APP_len*: INTEGER;           (* Length of data in JPEG APPn segment *)
		APP_data*: ARRAY 60 OF CHAR;      (* Data in the JPEG APPn segment. *)
		
		COM_len*: INTEGER;           (* Length of data in JPEG COM segment *)
		COM_data*: ARRAY 60 OF CHAR;      (* Data in JPEG COM segment *)
		
		jpeg_markers* : __u32;     (* Which markers should go into the JPEG
		* output. Unless you exactly know what
		* you do, leave them untouched.
		* Inluding less markers will make the
		* resulting code smaller, but there will
		* be fewer applications which can read it.
		* The presence of the APP and COM marker
		* is influenced by APP_len and COM_len
		* ONLY, not by this property! *)
	END;
		
	CONST 
		V4L2_JPEG_MARKER_DHT* = 8;
		(* Define Huffman Tables *)
		V4L2_JPEG_MARKER_DQT* = 16;    (* Define Quantization Tables *)
		V4L2_JPEG_MARKER_DRI* = 32;    (* Define Restart Interval *)
		V4L2_JPEG_MARKER_COM* = 64;    (* Comment segment *)
		V4L2_JPEG_MARKER_APP* = 128;    (* App segment, driver will allways use APP0 *)
						
	(*!	M E M O R Y - M A P P I N G   B U F F E R S  *)
	
	TYPE v4l2_requestbuffers * = RECORD 
		count* : __u32;
		ztype* : v4l2_buf_type;
		memory* : v4l2_memory;
		reserved* : ARRAY 2 OF __u32;
	END;
	
	union8* =ARRAY 8 OF CHAR; (* u32 + insigned long *)
	
	TYPE v4l2_buffer * = RECORD 
		index* : __u32;
		ztype* : v4l2_buf_type;
		bytesused* : __u32;
		flags* : __u32;
		field* : v4l2_field;
		timestamp* : Unix.Itimerval;
		timecode* : v4l2_timecode;
		sequence* : __u32;
		
		(* memory location *)
		memory* : v4l2_memory;
	
	(*	TYPE union526 * = RECORD 
			CASE union:INTEGER OF 
			1 : (offset: __u32);
			2 : (userptr: LONGINT);
		END; *) 
		m* : union8;
		 length* : __u32; 
		input* : __u32; 
		reserved* : __u32; 
	END ;
	
	(*  Flags for 'flags' field *)
	CONST V4L2_BUF_FLAG_MAPPED * = 00001H;  (* Buffer is mapped (flag) *)
	 V4L2_BUF_FLAG_QUEUED * = 00002H;	(* Buffer is queued for processing *)
	 V4L2_BUF_FLAG_DONE * = 00004H;	(* Buffer is ready *)
	 V4L2_BUF_FLAG_KEYFRAME * = 00008H;	(* Image is a keyframe (I-frame) *)
	 V4L2_BUF_FLAG_PFRAME * = 00010H;	(* Image is a P-frame *)
	 V4L2_BUF_FLAG_BFRAME * = 00020H;	(* Image is a B-frame *)
	(* Buffer is ready, but the data contained within is corrupted. *)
	 V4L2_BUF_FLAG_ERROR * = 00040H;
	 V4L2_BUF_FLAG_TIMECxODE * = 00100H;	(*! timecode field is valid *)
	 V4L2_BUF_FLAG_INPUT * = 00200H;  (* input field is valid *)
	
	(*!	O V E R L A Y   P R E V I E W *)
	
	TYPE v4l2_framebuffer * = RECORD 
		capability* : __u32;
		flags* : __u32;
		(* FIXME* : in theory we should pass something like PCI device + memory
		* region + offset instead of some physical address *)
		base* : LONGINT; (* pointer, address *)
		fmt* : v4l2_pix_format;
	END;
	
	(*  Flags for the 'capability' field. Read only *)
CONST 
	V4L2_FBUF_CAP_EXTERNOVERLAY * = 00001H;
	 V4L2_FBUF_CAP_CHROMAKEY * = 00002H;
	 V4L2_FBUF_CAP_LIST_CLIPPING * = 00004H;
	 V4L2_FBUF_CAP_BITMAP_CLIPPING * = 00008H;
	 V4L2_FBUF_CAP_LOCAL_ALPHA * = 00010H;
	 V4L2_FBUF_CAP_GLOBAL_ALPHA * = 00020H;
	 V4L2_FBUF_CAP_LOCAL_INV_ALPHA * = 00040H;
	 V4L2_FBUF_CAP_SRC_CHROMAKEY * = 00080H;
	(*  Flags for the 'flags' field. *)
	 V4L2_FBUF_FLAG_PRIMARY * = 00001H;
	 V4L2_FBUF_FLAG_OVERLAY * = 00002H;
	 V4L2_FBUF_FLAG_CHROMAKEY * = 00004H;
	 V4L2_FBUF_FLAG_LOCAL_ALPHA * = 00008H;
	 V4L2_FBUF_FLAG_GLOBAL_ALPHA * = 00010H;
	 V4L2_FBUF_FLAG_LOCAL_INV_ALPHA * = 00020H;
	 V4L2_FBUF_FLAG_SRC_CHROMAKEY * = 00040H;
	
	
	TYPE v4l2_Pclip * = POINTER TO v4l2_clip;
	TYPE v4l2_clip * = RECORD 
		c* : v4l2_rect;
		next* : v4l2_Pclip;
	END;
	
	TYPE v4l2_window * = RECORD 
		w* : v4l2_rect;
		field* : v4l2_field;
		chromakey* : __u32;
		clips* : v4l2_Pclip;
		clipcount* : __u32;
		bitmap* : LONGINT; (* address *)
		global_alpha* : __u8;
	END;
	
	(*!	C A P T U R E   P A R A M E T E R S *)
TYPE v4l2_captureparm * = RECORD 
		capability* : __u32;	  (*  Supported modes *)
		capturemode* : __u32;	  (*  Current mode *)
		timeperframe* : v4l2_fract;  (*  Time per frame in .1us units *)
		extendedmode* : __u32;  (*  Driver-specific extensions *)
		readbuffers* : __u32;   (*  # of buffers for read *)
		reserved* : ARRAY 4 OF __u32;
	END;
	
	(*  Flags for 'capability' and 'capturemode' fields *)
CONST V4L2_MODE_HIGHQUALITY * = 00001H;	(*  High quality imaging mode *)
	 V4L2_CAP_TIMEPERFRAME * = 01000H;	(*  timeperframe field is supported *)
	
	TYPE v4l2_outputparm * = RECORD 
		capability* : __u32;	 (*  Supported modes *)
		outputmode* : __u32;	 (*  Current mode *)
		timeperframe* : v4l2_fract; (*  Time per frame in seconds *)
		extendedmode* : __u32; (*  Driver-specific extensions *)
		writebuffers* : __u32; (*  # of buffers for write *)
		reserved* : ARRAY 4 OF __u32;
	END;
	
	(*!	I N P U T   I M A G E   C R O P P I N G  *)
	TYPE v4l2_cropcap * = RECORD 
		ztype* : v4l2_buf_type;
		bounds* : v4l2_rect;
		defrect* : v4l2_rect;
		pixelaspect* : v4l2_fract;
	END;
	
	TYPE v4l2_crop * = RECORD 
		ztype* : v4l2_buf_type;
		c* : v4l2_rect;
	END;
	
	(*!   A N A L O G   V I D E O   S T A N D A R D *)
	
	TYPE v4l2_std_id * = __u64;
	
	(* one bit for each *)
	CONST V4L2_STD_PAL_B * = v4l2_std_id(000000001H);
	 V4L2_STD_PAL_B1 * = v4l2_std_id(000000002H);
	 V4L2_STD_PAL_G * = v4l2_std_id(000000004H);
	 V4L2_STD_PAL_H * = v4l2_std_id(000000008H);
	 V4L2_STD_PAL_I * = v4l2_std_id(000000010H);
	 V4L2_STD_PAL_D * = v4l2_std_id(000000020H);
	 V4L2_STD_PAL_D1 * = v4l2_std_id(000000040H);
	 V4L2_STD_PAL_K * = v4l2_std_id(000000080H);
	
	 V4L2_STD_PAL_M * = v4l2_std_id(000000100H);
	 V4L2_STD_PAL_N * = v4l2_std_id(000000200H);
	 V4L2_STD_PAL_Nc * = v4l2_std_id(000000400H);
	 V4L2_STD_PAL_60 * = v4l2_std_id(000000800H);
	
	 V4L2_STD_NTSC_M * = v4l2_std_id(000001000H);
	 V4L2_STD_NTSC_M_JP * = v4l2_std_id(000002000H);
	 V4L2_STD_NTSC_443 * = v4l2_std_id(000004000H);
	 V4L2_STD_NTSC_M_KR * = v4l2_std_id(000008000H);
	
	 V4L2_STD_SECAM_B * = v4l2_std_id(000010000H);
	 V4L2_STD_SECAM_D * = v4l2_std_id(000020000H);
	 V4L2_STD_SECAM_G * = v4l2_std_id(000040000H);
	 V4L2_STD_SECAM_H * = v4l2_std_id(000080000H);
	 V4L2_STD_SECAM_K * = v4l2_std_id(000100000H);
	 V4L2_STD_SECAM_K1 * = v4l2_std_id(000200000H);
	 V4L2_STD_SECAM_L * = v4l2_std_id(000400000H);
	 V4L2_STD_SECAM_LC * = v4l2_std_id(000800000H);
	
	(* ATSC/HDTV *)
	 V4L2_STD_ATSC_8_VSB * = v4l2_std_id(001000000H);
	 V4L2_STD_ATSC_16_VSB * = v4l2_std_id(002000000H);
	
	(* FIXME:
	   Although std_id is 64 bits, there is an issue on PPC32 architecture that
	   makes switch(__u64) to break. So, there's a hack on v4l2-common.c rounding
	   this value to 32 bits.
	   As, currently, the max value is for V4L2_STD_ATSC_16_VSB (30 bits wide),
	   it should work fine. However, if needed to add more than two standards,
	   v4l2-common.c should be fixed.
	 *)
	
	(* some merged standards *)
	 V4L2_STD_MN * = V4L2_STD_PAL_M + V4L2_STD_PAL_N + V4L2_STD_PAL_Nc + V4L2_STD_NTSC;
	 V4L2_STD_B * = V4L2_STD_PAL_B + V4L2_STD_PAL_B1 + V4L2_STD_SECAM_B;
	 V4L2_STD_GH * = V4L2_STD_PAL_G + V4L2_STD_PAL_H + V4L2_STD_SECAM_G + V4L2_STD_SECAM_H;
	 V4L2_STD_DK * = V4L2_STD_PAL_DK + V4L2_STD_SECAM_DK;
	
	(* some common needed stuff *)
	 V4L2_STD_PAL_BG * = V4L2_STD_PAL_B + V4L2_STD_PAL_B1 + V4L2_STD_PAL_G;
	 V4L2_STD_PAL_DK * = V4L2_STD_PAL_D + V4L2_STD_PAL_D1 + V4L2_STD_PAL_K;
	 V4L2_STD_PAL * = V4L2_STD_PAL_BG + V4L2_STD_PAL_DK + V4L2_STD_PAL_H + V4L2_STD_PAL_I;
	 V4L2_STD_NTSC * = V4L2_STD_NTSC_M + V4L2_STD_NTSC_M_JP + V4L2_STD_NTSC_M_KR;
	 V4L2_STD_SECAM_DK * = V4L2_STD_SECAM_D + V4L2_STD_SECAM_K + V4L2_STD_SECAM_K1;
	 V4L2_STD_SECAM * = V4L2_STD_SECAM_B + V4L2_STD_SECAM_G + V4L2_STD_SECAM_H + V4L2_STD_SECAM_DK + V4L2_STD_SECAM_L + V4L2_STD_SECAM_LC;
	
	 V4L2_STD_525_60 * = V4L2_STD_PAL_M + V4L2_STD_PAL_60 + V4L2_STD_NTSC + V4L2_STD_NTSC_443;
	 V4L2_STD_625_50 * = V4L2_STD_PAL + V4L2_STD_PAL_N + V4L2_STD_PAL_Nc + V4L2_STD_SECAM;
	 V4L2_STD_ATSC * = V4L2_STD_ATSC_8_VSB + V4L2_STD_ATSC_16_VSB;
	
	 V4L2_STD_UNKNOWN * = 0;
	 V4L2_STD_ALL * = V4L2_STD_525_60 + V4L2_STD_625_50;

	TYPE v4l2_standard * = RECORD 
		index* : __u32;
		id* : v4l2_std_id;
		name* : ARRAY 24 OF __u8;
		frameperiod* : v4l2_fract; (* Frames, not fields *)
		framelines* : __u32;
		reserved* : ARRAY 4 OF __u32;
	END;
	
	(*! V I D E O	T I M I N G S	D V	P R E S E T  *)
	TYPE v4l2_dv_preset * = RECORD 
		preset* : __u32;
		reserved* : ARRAY 4 OF __u32;
	END;
	
	(*! D V	P R E S E T S	E N U M E R A T I O N	 *)
	TYPE v4l2_dv_enum_preset * = RECORD 
		index* : __u32;
		preset* : __u32;
		name* : ARRAY 32 OF __u8; (* Name of the preset timing *)
		width* : __u32;
		height* : __u32;
		reserved* : ARRAY 4 OF __u32;
	END;
	
	(*  D V	P R E S E T	V A L U E S *)
	CONST V4L2_DV_INVALID * = 0;
	 V4L2_DV_480P59_94 * = 1; (* BT.1362 *)
	 V4L2_DV_576P50 * = 2; (* BT.1362 *)
	 V4L2_DV_720P24 * = 3; (* SMPTE 296M *)
	 V4L2_DV_720P25 * = 4; (* SMPTE 296M *)
	 V4L2_DV_720P30 * = 5; (* SMPTE 296M *)
	 V4L2_DV_720P50 * = 6; (* SMPTE 296M *)
	 V4L2_DV_720P59_94 * = 7; (* SMPTE 274M *)
	 V4L2_DV_720P60 * = 8; (* SMPTE 274M/296M *)
	 V4L2_DV_1080I29_97 * = 9; (* BT.1120/ SMPTE 274M *)
	 V4L2_DV_1080I30 * = 10; (* BT.1120/ SMPTE 274M *)
	 V4L2_DV_1080I25 * = 11; (* BT.1120 *)
	 V4L2_DV_1080I50 * = 12; (* SMPTE 296M *)
	 V4L2_DV_1080I60 * = 13; (* SMPTE 296M *)
	 V4L2_DV_1080P24 * = 14; (* SMPTE 296M *)
	 V4L2_DV_1080P25 * = 15; (* SMPTE 296M *)
	 V4L2_DV_1080P30 * = 16; (* SMPTE 296M *)
	 V4L2_DV_1080P50 * = 17; (* BT.1120 *)
	 V4L2_DV_1080P60 * = 18; (* BT.1120 *)
	
	(*	D V 	B T	T I M I N G S *)
	
	(* BT.656/BT.1120 timing data *)
	TYPE v4l2_bt_timings * = RECORD 
		width* : __u32;		(* width in pixels *)
		height* : __u32;		(* height in lines *)
		interlaced* : __u32;	(* Interlaced or progressive *)
		polarities* : __u32;	(* Positive or negative polarity *)
		pixelclock* : __u64;	(* Pixel clock in HZ. Ex. 74.25MHz->74250000 *)
		hfrontporch* : __u32;	(* Horizpontal front porch in pixels *)
		hsync* : __u32;		(* Horizontal Sync length in pixels *)
		hbackporch* : __u32;	(* Horizontal back porch in pixels *)
		vfrontporch* : __u32;	(* Vertical front porch in pixels *)
		vsync* : __u32;		(* Vertical Sync length in lines *)
		vbackporch* : __u32;	(* Vertical back porch in lines *)
		il_vfrontporch* : __u32;	(* Vertical front porch for bottom field of
		* interlaced field formats
		*)
		il_vsync* : __u32;	(* Vertical sync length for bottom field of
		* interlaced field formats
		*)
		il_vbackporch* : __u32;	(* Vertical back porch for bottom field of
		* interlaced field formats
		*)
		reserved* : ARRAY 16 OF __u32;
	END;

	(* Interlaced or progressive format *)
CONST 
	V4L2_DV_PROGRESSIVE * = 0;
	V4L2_DV_INTERLACED * = 1;
	
	(* Polarities. If bit is not set, it is assumed to be negative polarity *)
	V4L2_DV_VSYNC_POS_POL * = 000000001H;
	V4L2_DV_HSYNC_POS_POL * = 000000002H;
	

	(*!!!!!! DV timings *)
	TYPE Data47* = ARRAY 47 OF __u32;
	TYPE v4l2_dv_timings * = RECORD 
		ztype*: __u32;
	(*	TYPE union817 * = RECORD 
			CASE union:INTEGER OF 
			bt: v4l2_bt_timings;
			reserved: ARRAY 32 OF __u32;
		END;
		*)
		data*: Data47;
	END;
	
	(* Values for the type field *)
	CONST V4L2_DV_BT_656_1120 * = 0;	(* BT.656/1120 timing type *)

	(*!	V I D E O   I N P U T S *)
TYPE v4l2_input * = RECORD 
		index* : __u32;		(*  Which input *)
		name* : ARRAY 32 OF __u8;		(*  Label *)
		ztype* : __u32;		(*  Type of input *)
		audioset* : __u32;		(*  Associated audios (bitfield) *)
		tuner* : __u32;             (*  Associated tuner *)
		std* : v4l2_std_id;
		status* : __u32;
		capabilities* : __u32;
		reserved* : ARRAY 3 OF __u32;
	END;

(*  Values for the 'type' field *)
CONST 
	V4L2_INPUT_TYPE_TUNER * = 1;
	 V4L2_INPUT_TYPE_CAMERA * = 2;

	(* field 'status' - general *)
	 V4L2_IN_ST_NO_POWER * = 000000001H;  (* Attached device is off *)
	 V4L2_IN_ST_NO_SIGNAL * = 000000002H;
	 V4L2_IN_ST_NO_COLOR * = 000000004H;
	
	(* field 'status' - sensor orientation *)
	(* If sensor is mounted upside down set both bits *)
	 V4L2_IN_ST_HFLIP * = 000000010H; (* Frames are flipped horizontally *)
	 V4L2_IN_ST_VFLIP * = 000000020H; (* Frames are flipped vertically *)
	
	(* field 'status' - analog *)
	 V4L2_IN_ST_NO_H_LOCK * = 000000100H;  (* No horizontal sync lock *)
	 V4L2_IN_ST_COLOR_KILL * = 000000200H;  (* Color killer is active *)
	
	(* field 'status' - digital *)
	 V4L2_IN_ST_NO_SYNC * = 000010000H;  (* No synchronization lock *)
	 V4L2_IN_ST_NO_EQU * = 000020000H;  (* No equalizer lock *)
	 V4L2_IN_ST_NO_CARRIER * = 000040000H;  (* Carrier recovery failed *)
	
	(* field 'status' - VCR and set-top box *)
	 V4L2_IN_ST_MACROVISION * = 001000000H;  (* Macrovision detected *)
	 V4L2_IN_ST_NO_ACCESS * = 002000000H;  (* Conditional access denied *)
	 V4L2_IN_ST_VTR * = 004000000H;  (* VTR time constant *)
	
	(* capabilities flags *)
	 V4L2_IN_CAP_PRESETS * = 000000001H; (* Supports S_DV_PRESET *)
	 V4L2_IN_CAP_CUSTOM_TIMINGS * = 000000002H; (* Supports S_DV_TIMINGS *)
	 V4L2_IN_CAP_STD * = 000000004H; (* Supports S_STD *)

	(*!  V I D E O   O U T P U T S  *)
	TYPE v4l2_output * = RECORD 
		index* : __u32;		(*  Which output *)
		name* : ARRAY 32 OF __u8;		(*  Label *)
		ztype* : __u32;		(*  Type of output *)
		audioset* : __u32;		(*  Associated audios (bitfield) *)
		modulator* : __u32;         (*  Associated modulator *)
		std* : v4l2_std_id;
		capabilities* : __u32;
		reserved* : ARRAY 3 OF __u32;
	END;
	
	(*  Values for the 'type' field *)
CONST V4L2_OUTPUT_TYPE_MODULATOR * = 1;
	 V4L2_OUTPUT_TYPE_ANALOG * = 2;
	 V4L2_OUTPUT_TYPE_ANALOGVGAOVERLAY * = 3;
	
	(* capabilities flags *)
	 V4L2_OUT_CAP_PRESETS * = 000000001H; (* Supports S_DV_PRESET *)
	 V4L2_OUT_CAP_CUSTOM_TIMINGS * = 000000002H; (* Supports S_DV_TIMINGS *)
	 V4L2_OUT_CAP_STD * = 000000004H; (* Supports S_STD *)

	(*!	C O N T R O L S *)
	TYPE v4l2_control * = RECORD 
		id* : __u32;
		value* : __s32;
	END;
	
	TYPE v4l2_ext_control * = RECORD 
		id* : __u32;
		size* : __u32;
		reserved2* : ARRAY 1 OF __u32;
		data*: __s64;  
	(*	TYPE union909 * = RECORD 
			CASE union:INTEGER OF 
			1 : (value: __s32);
			2 : (value64: __s64);
			3 : (string: ARRAY OF CHAR);
		END;
	*)
	END;

TYPE v4l2_ext_controls * = RECORD 
		ctrl_class* : __u32;
		count* : __u32;
		error_idx* : __u32;
		reserved* : ARRAY 2 OF __u32;
		controls* : POINTER TO v4l2_ext_control;
	END;
	
	(*  Values for ctrl_class field *)
CONST 
	V4L2_CTRL_CLASS_USER * = 000980000H;	(* Old-style 'user' controls *)
	 V4L2_CTRL_CLASS_MPEG * = 000990000H;	(* MPEG-compression controls *)
	 V4L2_CTRL_CLASS_CAMERA * = 0009A0000H;	(* Camera class controls *)
	 V4L2_CTRL_CLASS_FM_TX * = 0009B0000H;	(* FM Modulator control class *)

	 V4L2_CTRL_ID_MASK * = 00FFFFFFFH;

(*	 
	(*# todo be converted  *)
	V4L2_CTRL_ID_MASK      	  (0x0fffffff)
	V4L2_CTRL_ID2CLASS(id)    ((id) & 0x0fff0000UL)
	V4L2_CTRL_DRIVER_PRIV(id) (((id) & 0xffff) >= 0x1000)
*)	

	TYPE v4l2_ctrl_type * = LONGINT(*enum*);
	CONST 
		V4L2_CTRL_TYPE_INTEGER * = 1;
		V4L2_CTRL_TYPE_BOOLEAN * = 2;
		V4L2_CTRL_TYPE_MENU * = 3;
		V4L2_CTRL_TYPE_BUTTON * = 4;
		V4L2_CTRL_TYPE_INTEGER64 * = 5;
		V4L2_CTRL_TYPE_CTRL_CLASS * = 6;
		V4L2_CTRL_TYPE_STRING * = 7;
		V4L2_CTRL_TYPE_BITMASK* = 8;
	
	(*  Used in the VIDIOC_QUERYCTRL ioctl for querying controls *)
	TYPE v4l2_queryctrl * = RECORD 
		id* : __u32;
		ztype* : v4l2_ctrl_type;
		name* : ARRAY 32 OF __u8;	(* Whatever *)
		minimum* : __s32;	(* Note signedness *)
		maximum* : __s32;
		step* : __s32;
		default_value* : __s32;
		flags* : __u32;
		reserved* : ARRAY 2 OF __u32;
	END;
	
	(*  Used in the VIDIOC_QUERYMENU ioctl for querying menu items *)
	TYPE v4l2_querymenu * = RECORD 
		id* : __u32;
		index* : __u32;
		name* : ARRAY 32 OF __u8;	(* Whatever *)
		reserved* : __u32;
	END;
	
	(*  Control flags  *)
CONST 
	V4L2_CTRL_FLAG_DISABLED * = 00001H;
	 V4L2_CTRL_FLAG_GRABBED * = 00002H;
	 V4L2_CTRL_FLAG_READ_ONLY * = 00004H;
	 V4L2_CTRL_FLAG_UPDATE * = 00008H;
	 V4L2_CTRL_FLAG_INACTIVE * = 00010H;
	 V4L2_CTRL_FLAG_SLIDER * = 00020H;
	 V4L2_CTRL_FLAG_WRITE_ONLY * = 00040H;
	
	(*  Query flag, to be ORed with the control ID *)
	 V4L2_CTRL_FLAG_NEXT_CTRL * = 080000000H;
	
	(*  User-class control IDs defined by V4L2 *)
	 V4L2_CID_BASE * = V4L2_CTRL_CLASS_USER + 0900H;
	 V4L2_CID_USER_BASE * = V4L2_CID_BASE;
	(*  IDs reserved for driver specific controls *)
	 V4L2_CID_PRIVATE_BASE * = 008000000H;
	
	 V4L2_CID_USER_CLASS * = V4L2_CTRL_CLASS_USER + 1;
	 V4L2_CID_BRIGHTNESS * = V4L2_CID_BASE+0;
	 V4L2_CID_CONTRAST * = V4L2_CID_BASE+1;
	 V4L2_CID_SATURATION * = V4L2_CID_BASE+2;
	 V4L2_CID_HUE * = V4L2_CID_BASE+3;
	 V4L2_CID_AUDIO_VOLUME * = V4L2_CID_BASE+5;
	 V4L2_CID_AUDIO_BALANCE * = V4L2_CID_BASE+6;
	 V4L2_CID_AUDIO_BASS * = V4L2_CID_BASE+7;
	 V4L2_CID_AUDIO_TREBLE * = V4L2_CID_BASE+8;
	 V4L2_CID_AUDIO_MUTE * = V4L2_CID_BASE+9;
	 V4L2_CID_AUDIO_LOUDNESS * = V4L2_CID_BASE+10;
	 V4L2_CID_BLACK_LEVEL * = V4L2_CID_BASE+11; (* Deprecated *)
	 V4L2_CID_AUTO_WHITE_BALANCE * = V4L2_CID_BASE+12;
	 V4L2_CID_DO_WHITE_BALANCE * = V4L2_CID_BASE+13;
	 V4L2_CID_RED_BALANCE * = V4L2_CID_BASE+14;
	 V4L2_CID_BLUE_BALANCE * = V4L2_CID_BASE+15;
	 V4L2_CID_GAMMA * = V4L2_CID_BASE+16;
	 V4L2_CID_WHITENESS * = V4L2_CID_GAMMA; (* Deprecated *)
	 V4L2_CID_EXPOSURE * = V4L2_CID_BASE+17;
	 V4L2_CID_AUTOGAIN * = V4L2_CID_BASE+18;
	 V4L2_CID_GAIN * = V4L2_CID_BASE+19;
	 V4L2_CID_HFLIP * = V4L2_CID_BASE+20;
	 V4L2_CID_VFLIP * = V4L2_CID_BASE+21;
	
	(* Deprecated; use V4L2_CID_PAN_RESET and V4L2_CID_TILT_RESET *)
	 V4L2_CID_HCENTER * = V4L2_CID_BASE+22;
	 V4L2_CID_VCENTER * = V4L2_CID_BASE+23;
	
	 V4L2_CID_POWER_LINE_FREQUENCY * = V4L2_CID_BASE+24;
	TYPE v4l2_power_line_frequency * = LONGINT(*enum*);
	CONST 
		V4L2_CID_POWER_LINE_FREQUENCY_DISABLED * = 0;
		V4L2_CID_POWER_LINE_FREQUENCY_50HZ * = 1;
		V4L2_CID_POWER_LINE_FREQUENCY_60HZ * = 2;
		V4L2_CID_POWER_LINE_FREQUENCY_AUTO* = 3;
		
	 V4L2_CID_HUE_AUTO * = V4L2_CID_BASE+25;
	 V4L2_CID_WHITE_BALANCE_TEMPERATURE * = V4L2_CID_BASE+26;
	 V4L2_CID_SHARPNESS * = V4L2_CID_BASE+27;
	 V4L2_CID_BACKLIGHT_COMPENSATION * = V4L2_CID_BASE+28;
	 V4L2_CID_CHROMA_AGC * = V4L2_CID_BASE+29;
	 V4L2_CID_COLOR_KILLER * = V4L2_CID_BASE+30;
	 V4L2_CID_COLORFX * = V4L2_CID_BASE+31;
	 
	TYPE v4l2_colorfx * = LONGINT(*enum*);
	CONST 
		V4L2_COLORFX_NONE * = 0;
		V4L2_COLORFX_BW * = 1;
		V4L2_COLORFX_SEPIA * = 2;
		V4L2_COLORFX_NEGATIVE * = 3;
		V4L2_COLORFX_EMBOSS * = 4;
		V4L2_COLORFX_SKETCH * = 5;
		V4L2_COLORFX_SKY_BLUE * = 6;
		V4L2_COLORFX_GRASS_GREEN * = 7;
		V4L2_COLORFX_SKIN_WHITEN * = 8;
		V4L2_COLORFX_VIVID * = 9;
	
	
	 V4L2_CID_AUTOBRIGHTNESS * = V4L2_CID_BASE+32;
	 V4L2_CID_BAND_STOP_FILTER * = V4L2_CID_BASE+33;
	
	 V4L2_CID_ROTATE * = V4L2_CID_BASE+34;
	 V4L2_CID_BG_COLOR * = V4L2_CID_BASE+35;
	
	 V4L2_CID_CHROMA_GAIN * = V4L2_CID_BASE+36;
	
	 V4L2_CID_ILLUMINATORS_1 * = V4L2_CID_BASE+37;
	 V4L2_CID_ILLUMINATORS_2 * = V4L2_CID_BASE+38;
	
	(* last CID + 1 *)
	 V4L2_CID_LASTP1 * = V4L2_CID_BASE+39;
	
	(*  MPEG-class control IDs defined by V4L2 *)
	 V4L2_CID_MPEG_BASE * = V4L2_CTRL_CLASS_MPEG + 0900H;
	 V4L2_CID_MPEG_CLASS * = V4L2_CTRL_CLASS_MPEG + 1;
	(*! check above enumeration constants  *)
	
	(*  MPEG streams *)
	 V4L2_CID_MPEG_STREAM_TYPE * = V4L2_CID_MPEG_BASE+0;
	TYPE v4l2_mpeg_stream_type * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_STREAM_TYPE_MPEG2_PS * = 0;(* MPEG-2 program stream *)
		V4L2_MPEG_STREAM_TYPE_MPEG2_TS * = 1;(* MPEG-2 transport stream *)
		V4L2_MPEG_STREAM_TYPE_MPEG1_SS * = 2;(* MPEG-1 system stream *)
		V4L2_MPEG_STREAM_TYPE_MPEG2_DVD * = 3; (* MPEG-2 DVD-compatible stream *)
		V4L2_MPEG_STREAM_TYPE_MPEG1_VCD * = 4;(* MPEG-1 VCD-compatible stream *)
		V4L2_MPEG_STREAM_TYPE_MPEG2_SVCD * = 5;(* MPEG-2 SVCD-compatible stream *)
	
		V4L2_CID_MPEG_STREAM_PID_PMT * = V4L2_CID_MPEG_BASE+1;
		V4L2_CID_MPEG_STREAM_PID_AUDIO * = V4L2_CID_MPEG_BASE+2;
		V4L2_CID_MPEG_STREAM_PID_VIDEO * = V4L2_CID_MPEG_BASE+3;
		V4L2_CID_MPEG_STREAM_PID_PCR * = V4L2_CID_MPEG_BASE+4;
		V4L2_CID_MPEG_STREAM_PES_ID_AUDIO * = V4L2_CID_MPEG_BASE+5;
		V4L2_CID_MPEG_STREAM_PES_ID_VIDEO * = V4L2_CID_MPEG_BASE+6;
		V4L2_CID_MPEG_STREAM_VBI_FMT * = V4L2_CID_MPEG_BASE+7;
	
	TYPE v4l2_mpeg_stream_vbi_fmt * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_STREAM_VBI_FMT_NONE * = 0;   (* No VBI in the MPEG stream *)
		V4L2_MPEG_STREAM_VBI_FMT_IVTV * = 1;   (* VBI in private packets, IVTV format *)
	
	
	(*  MPEG audio *)
	CONST V4L2_CID_MPEG_AUDIO_SAMPLING_FREQ * = V4L2_CID_MPEG_BASE+100;
	TYPE v4l2_mpeg_audio_sampling_freq * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_SAMPLING_FREQ_44100 * = 0;
		V4L2_MPEG_AUDIO_SAMPLING_FREQ_48000 * = 1;
		V4L2_MPEG_AUDIO_SAMPLING_FREQ_32000 * = 2;
	
	CONST V4L2_CID_MPEG_AUDIO_ENCODING * = V4L2_CID_MPEG_BASE+101;
	TYPE v4l2_mpeg_audio_encoding * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_ENCODING_LAYER_1 * = 0;
		V4L2_MPEG_AUDIO_ENCODING_LAYER_2 * = 1;
		V4L2_MPEG_AUDIO_ENCODING_LAYER_3 * = 2;
		V4L2_MPEG_AUDIO_ENCODING_AAC * = 3;
		V4L2_MPEG_AUDIO_ENCODING_AC3 * = 4;
	
	CONST V4L2_CID_MPEG_AUDIO_L1_BITRATE * = V4L2_CID_MPEG_BASE+102;
	TYPE v4l2_mpeg_audio_l1_bitrate * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_L1_BITRATE_32K * = 0;
		V4L2_MPEG_AUDIO_L1_BITRATE_64K * = 1;
		V4L2_MPEG_AUDIO_L1_BITRATE_96K * = 2;
		V4L2_MPEG_AUDIO_L1_BITRATE_128K * = 3;
		V4L2_MPEG_AUDIO_L1_BITRATE_160K * = 4;
		V4L2_MPEG_AUDIO_L1_BITRATE_192K * = 5;
		V4L2_MPEG_AUDIO_L1_BITRATE_224K * = 6;
		V4L2_MPEG_AUDIO_L1_BITRATE_256K * = 7;
		V4L2_MPEG_AUDIO_L1_BITRATE_288K * = 8;
		V4L2_MPEG_AUDIO_L1_BITRATE_320K * = 9;
		V4L2_MPEG_AUDIO_L1_BITRATE_352K * = 10;
		V4L2_MPEG_AUDIO_L1_BITRATE_384K * = 11;
		V4L2_MPEG_AUDIO_L1_BITRATE_416K * = 12;
		V4L2_MPEG_AUDIO_L1_BITRATE_448K * = 13;
	
	CONST V4L2_CID_MPEG_AUDIO_L2_BITRATE * = V4L2_CID_MPEG_BASE+103;
	TYPE v4l2_mpeg_audio_l2_bitrate * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_L2_BITRATE_32K * = 0;
		V4L2_MPEG_AUDIO_L2_BITRATE_48K * = 1;
		V4L2_MPEG_AUDIO_L2_BITRATE_56K * = 2;
		V4L2_MPEG_AUDIO_L2_BITRATE_64K * = 3;
		V4L2_MPEG_AUDIO_L2_BITRATE_80K * = 4;
		V4L2_MPEG_AUDIO_L2_BITRATE_96K * = 5;
		 V4L2_MPEG_AUDIO_L2_BITRATE_112K * = 6;
		V4L2_MPEG_AUDIO_L2_BITRATE_128K * = 7;
		V4L2_MPEG_AUDIO_L2_BITRATE_160K * = 8;
		V4L2_MPEG_AUDIO_L2_BITRATE_192K * = 9;
		V4L2_MPEG_AUDIO_L2_BITRATE_224K * = 10;
		V4L2_MPEG_AUDIO_L2_BITRATE_256K * = 11;
		V4L2_MPEG_AUDIO_L2_BITRATE_320K * = 12;
		V4L2_MPEG_AUDIO_L2_BITRATE_384K * = 13;
	
	CONST V4L2_CID_MPEG_AUDIO_L3_BITRATE * = V4L2_CID_MPEG_BASE+104;
	TYPE v4l2_mpeg_audio_l3_bitrate * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_L3_BITRATE_32K * = 0;
		V4L2_MPEG_AUDIO_L3_BITRATE_40K * = 1;
		V4L2_MPEG_AUDIO_L3_BITRATE_48K * = 2;
		V4L2_MPEG_AUDIO_L3_BITRATE_56K * = 3;
		V4L2_MPEG_AUDIO_L3_BITRATE_64K * = 4;
		V4L2_MPEG_AUDIO_L3_BITRATE_80K * = 5;
		V4L2_MPEG_AUDIO_L3_BITRATE_96K * = 6;
		V4L2_MPEG_AUDIO_L3_BITRATE_112K * = 7;
		V4L2_MPEG_AUDIO_L3_BITRATE_128K * = 8;
		V4L2_MPEG_AUDIO_L3_BITRATE_160K * = 9;
		V4L2_MPEG_AUDIO_L3_BITRATE_192K * = 10;
		V4L2_MPEG_AUDIO_L3_BITRATE_224K * = 11;
		V4L2_MPEG_AUDIO_L3_BITRATE_256K * = 12;
		V4L2_MPEG_AUDIO_L3_BITRATE_320K * = 13;
	
	CONST V4L2_CID_MPEG_AUDIO_MODE * = V4L2_CID_MPEG_BASE+105;
	TYPE v4l2_mpeg_audio_mode * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_MODE_STEREO * = 0;
		V4L2_MPEG_AUDIO_MODE_JOINT_STEREO * = 1;
		V4L2_MPEG_AUDIO_MODE_DUAL * = 2;
		V4L2_MPEG_AUDIO_MODE_MONO * = 3;
	
	CONST V4L2_CID_MPEG_AUDIO_MODE_EXTENSION * = V4L2_CID_MPEG_BASE+106;
	TYPE v4l2_mpeg_audio_mode_extension * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_MODE_EXTENSION_BOUND_4 * = 0;
		V4L2_MPEG_AUDIO_MODE_EXTENSION_BOUND_8 * = 1;
		V4L2_MPEG_AUDIO_MODE_EXTENSION_BOUND_12 * = 2;
		V4L2_MPEG_AUDIO_MODE_EXTENSION_BOUND_16 * = 3;
	
	CONST V4L2_CID_MPEG_AUDIO_EMPHASIS * = V4L2_CID_MPEG_BASE+107;
	TYPE v4l2_mpeg_audio_emphasis * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_EMPHASIS_NONE * = 0;
		V4L2_MPEG_AUDIO_EMPHASIS_50_DIV_15_uS * = 1;
		V4L2_MPEG_AUDIO_EMPHASIS_CCITT_J17 * = 2;
	
	CONST V4L2_CID_MPEG_AUDIO_CRC * = V4L2_CID_MPEG_BASE+108;
	TYPE v4l2_mpeg_audio_crc * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_CRC_NONE * = 0;
		V4L2_MPEG_AUDIO_CRC_CRC16 * = 1;
	
	CONST V4L2_CID_MPEG_AUDIO_MUTE * = V4L2_CID_MPEG_BASE+109;
	CONST V4L2_CID_MPEG_AUDIO_AAC_BITRATE * = V4L2_CID_MPEG_BASE+110;
	CONST V4L2_CID_MPEG_AUDIO_AC3_BITRATE * = V4L2_CID_MPEG_BASE+111;
	TYPE v4l2_mpeg_audio_ac3_bitrate * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_AUDIO_AC3_BITRATE_32K * = 0;
		V4L2_MPEG_AUDIO_AC3_BITRATE_40K * = 1;
		V4L2_MPEG_AUDIO_AC3_BITRATE_48K * = 2;
		V4L2_MPEG_AUDIO_AC3_BITRATE_56K * = 3;
		V4L2_MPEG_AUDIO_AC3_BITRATE_64K * = 4;
		V4L2_MPEG_AUDIO_AC3_BITRATE_80K * = 5;
		V4L2_MPEG_AUDIO_AC3_BITRATE_96K * = 6;
		V4L2_MPEG_AUDIO_AC3_BITRATE_112K * = 7;
		V4L2_MPEG_AUDIO_AC3_BITRATE_128K * = 8;
		V4L2_MPEG_AUDIO_AC3_BITRATE_160K * = 9;
		V4L2_MPEG_AUDIO_AC3_BITRATE_192K * = 10;
		V4L2_MPEG_AUDIO_AC3_BITRATE_224K * = 11;
		V4L2_MPEG_AUDIO_AC3_BITRATE_256K * = 12;
		V4L2_MPEG_AUDIO_AC3_BITRATE_320K * = 13;
		V4L2_MPEG_AUDIO_AC3_BITRATE_384K * = 14;
		V4L2_MPEG_AUDIO_AC3_BITRATE_448K * = 15;
		V4L2_MPEG_AUDIO_AC3_BITRATE_512K * = 16;
		V4L2_MPEG_AUDIO_AC3_BITRATE_576K * = 17;
		V4L2_MPEG_AUDIO_AC3_BITRATE_640K * = 18;
	
	
	(*  MPEG video *)
	CONST V4L2_CID_MPEG_VIDEO_ENCODING * = V4L2_CID_MPEG_BASE+200;
	TYPE v4l2_mpeg_video_encoding * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_VIDEO_ENCODING_MPEG_1 * = 0;
		V4L2_MPEG_VIDEO_ENCODING_MPEG_2 * = 1;
		V4L2_MPEG_VIDEO_ENCODING_MPEG_4_AVC * = 2;	
		V4L2_CID_MPEG_VIDEO_ASPECT * = V4L2_CID_MPEG_BASE+201;
		
	TYPE v4l2_mpeg_video_aspect * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_VIDEO_ASPECT_1x1 * = 0;
		V4L2_MPEG_VIDEO_ASPECT_4x3 * = 1;
		V4L2_MPEG_VIDEO_ASPECT_16x9 * = 2;
		V4L2_MPEG_VIDEO_ASPECT_221x100 * = 3;
	
	 	V4L2_CID_MPEG_VIDEO_B_FRAMES * = V4L2_CID_MPEG_BASE+202;
	 	V4L2_CID_MPEG_VIDEO_GOP_SIZE * = V4L2_CID_MPEG_BASE+203;
	 	V4L2_CID_MPEG_VIDEO_GOP_CLOSURE * = V4L2_CID_MPEG_BASE+204;
	 	V4L2_CID_MPEG_VIDEO_PULLDOWN * = V4L2_CID_MPEG_BASE+205;
	 	V4L2_CID_MPEG_VIDEO_BITRATE_MODE * = V4L2_CID_MPEG_BASE+206;
	 	
	TYPE v4l2_mpeg_video_bitrate_mode * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_VIDEO_BITRATE_MODE_VBR * = 0;
		V4L2_MPEG_VIDEO_BITRATE_MODE_CBR * = 1;
	
		V4L2_CID_MPEG_VIDEO_BITRATE * = V4L2_CID_MPEG_BASE+207;
		V4L2_CID_MPEG_VIDEO_BITRATE_PEAK * = V4L2_CID_MPEG_BASE+208;
		V4L2_CID_MPEG_VIDEO_TEMPORAL_DECIMATION * = V4L2_CID_MPEG_BASE+209;
		V4L2_CID_MPEG_VIDEO_MUTE * = V4L2_CID_MPEG_BASE+210;
		V4L2_CID_MPEG_VIDEO_MUTE_YUV * = V4L2_CID_MPEG_BASE+211;
	
		(*  MPEG-class control IDs specific to the CX2341x driver as defined by V4L2 *)
		V4L2_CID_MPEG_CX2341X_BASE * = V4L2_CTRL_CLASS_MPEG + 01000H;
		V4L2_CID_MPEG_CX2341X_VIDEO_SPATIAL_FILTER_MODE * = V4L2_CID_MPEG_CX2341X_BASE+0;
		
	TYPE v4l2_mpeg_cx2341x_video_spatial_filter_mode * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_CX2341X_VIDEO_SPATIAL_FILTER_MODE_MANUAL * = 0;
		V4L2_MPEG_CX2341X_VIDEO_SPATIAL_FILTER_MODE_AUTO * = 1;
	
	 	V4L2_CID_MPEG_CX2341X_VIDEO_SPATIAL_FILTER * = V4L2_CID_MPEG_CX2341X_BASE+1;
	 	V4L2_CID_MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE * = V4L2_CID_MPEG_CX2341X_BASE+2;
	 	
	TYPE v4l2_mpeg_cx2341x_video_luma_spatial_filter_type * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_OFF * = 0;
		V4L2_MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_1D_HOR * = 1;
		V4L2_MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_1D_VERT * = 2;
		V4L2_MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_2D_HV_SEPARABLE * = 3;
		V4L2_MPEG_CX2341X_VIDEO_LUMA_SPATIAL_FILTER_TYPE_2D_SYM_NON_SEPARABLE * = 4;
	
		V4L2_CID_MPEG_CX2341X_VIDEO_CHROMA_SPATIAL_FILTER_TYPE * = V4L2_CID_MPEG_CX2341X_BASE+3;
		
	TYPE v4l2_mpeg_cx2341x_video_chroma_spatial_filter_type * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_CX2341X_VIDEO_CHROMA_SPATIAL_FILTER_TYPE_OFF * = 0;
		V4L2_MPEG_CX2341X_VIDEO_CHROMA_SPATIAL_FILTER_TYPE_1D_HOR * = 1;
	
		V4L2_CID_MPEG_CX2341X_VIDEO_TEMPORAL_FILTER_MODE * = V4L2_CID_MPEG_CX2341X_BASE+4;
		
	TYPE v4l2_mpeg_cx2341x_video_temporal_filter_mode * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_CX2341X_VIDEO_TEMPORAL_FILTER_MODE_MANUAL * = 0;
		V4L2_MPEG_CX2341X_VIDEO_TEMPORAL_FILTER_MODE_AUTO * = 1;
	
	 	V4L2_CID_MPEG_CX2341X_VIDEO_TEMPORAL_FILTER * = V4L2_CID_MPEG_CX2341X_BASE+5;
	 	V4L2_CID_MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE * = V4L2_CID_MPEG_CX2341X_BASE+6;
	 	
	TYPE v4l2_mpeg_cx2341x_video_median_filter_type * = LONGINT(*enum*);
	CONST 
		V4L2_MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_OFF * = 0;
		V4L2_MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_HOR * = 1;
		V4L2_MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_VERT * = 2;
		V4L2_MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_HOR_VERT * = 3;
		V4L2_MPEG_CX2341X_VIDEO_MEDIAN_FILTER_TYPE_DIAG * = 4;
	
	 	V4L2_CID_MPEG_CX2341X_VIDEO_LUMA_MEDIAN_FILTER_BOTTOM * = V4L2_CID_MPEG_CX2341X_BASE+7;
	 	V4L2_CID_MPEG_CX2341X_VIDEO_LUMA_MEDIAN_FILTER_TOP * = V4L2_CID_MPEG_CX2341X_BASE+8;
	 	V4L2_CID_MPEG_CX2341X_VIDEO_CHROMA_MEDIAN_FILTER_BOTTOM * = V4L2_CID_MPEG_CX2341X_BASE+9;
	 	V4L2_CID_MPEG_CX2341X_VIDEO_CHROMA_MEDIAN_FILTER_TOP * = V4L2_CID_MPEG_CX2341X_BASE+10;
	 	V4L2_CID_MPEG_CX2341X_STREAM_INSERT_NAV_PACKETS * = V4L2_CID_MPEG_CX2341X_BASE+11;
	
		(*  Camera class control IDs *)
		V4L2_CID_CAMERA_CLASS_BASE * = V4L2_CTRL_CLASS_CAMERA + 0900H;
		V4L2_CID_CAMERA_CLASS * = V4L2_CTRL_CLASS_CAMERA + 1;
	
		V4L2_CID_EXPOSURE_AUTO * = V4L2_CID_CAMERA_CLASS_BASE+1;
		
	TYPE v4l2_exposure_auto_type * = LONGINT (*enum*);
	CONST 
		V4L2_EXPOSURE_AUTO * = 0;
		V4L2_EXPOSURE_MANUAL * = 1;
		V4L2_EXPOSURE_SHUTTER_PRIORITY * = 2;
		V4L2_EXPOSURE_APERTURE_PRIORITY * = 3;
		
	 	V4L2_CID_EXPOSURE_ABSOLUTE * = V4L2_CID_CAMERA_CLASS_BASE+2;
	
	 	V4L2_CID_EXPOSURE_AUTO_PRIORITY * = V4L2_CID_CAMERA_CLASS_BASE+3;
	
	 	V4L2_CID_PAN_RELATIVE * = V4L2_CID_CAMERA_CLASS_BASE+4;
	 	V4L2_CID_TILT_RELATIVE * = V4L2_CID_CAMERA_CLASS_BASE+5;
	 	V4L2_CID_PAN_RESET * = V4L2_CID_CAMERA_CLASS_BASE+6;
	 	V4L2_CID_TILT_RESET * = V4L2_CID_CAMERA_CLASS_BASE+7;
	
	 	V4L2_CID_PAN_ABSOLUTE * = V4L2_CID_CAMERA_CLASS_BASE+8;
	 	V4L2_CID_TILT_ABSOLUTE * = V4L2_CID_CAMERA_CLASS_BASE+9;
	
	 	V4L2_CID_FOCUS_ABSOLUTE * = V4L2_CID_CAMERA_CLASS_BASE+10;
	 	V4L2_CID_FOCUS_RELATIVE * = V4L2_CID_CAMERA_CLASS_BASE+11;
	 	V4L2_CID_FOCUS_AUTO * = V4L2_CID_CAMERA_CLASS_BASE+12;
	
	 	V4L2_CID_ZOOM_ABSOLUTE * = V4L2_CID_CAMERA_CLASS_BASE+13;
	 	V4L2_CID_ZOOM_RELATIVE * = V4L2_CID_CAMERA_CLASS_BASE+14;
	 	V4L2_CID_ZOOM_CONTINUOUS * = V4L2_CID_CAMERA_CLASS_BASE+15;
	
	 	V4L2_CID_PRIVACY * = V4L2_CID_CAMERA_CLASS_BASE+16;
	
	 	V4L2_CID_IRIS_ABSOLUTE * = V4L2_CID_CAMERA_CLASS_BASE+17;
	 	V4L2_CID_IRIS_RELATIVE * = V4L2_CID_CAMERA_CLASS_BASE+18;
	
		(* FM Modulator class control IDs *)
		V4L2_CID_FM_TX_CLASS_BASE * = V4L2_CTRL_CLASS_FM_TX + 0900H;
		V4L2_CID_FM_TX_CLASS * = V4L2_CTRL_CLASS_FM_TX + 1;
	
		V4L2_CID_RDS_TX_DEVIATION * = V4L2_CID_FM_TX_CLASS_BASE + 1;
		V4L2_CID_RDS_TX_PI * = V4L2_CID_FM_TX_CLASS_BASE + 2;
		V4L2_CID_RDS_TX_PTY * = V4L2_CID_FM_TX_CLASS_BASE + 3;
		V4L2_CID_RDS_TX_PS_NAME * = V4L2_CID_FM_TX_CLASS_BASE + 5;
		V4L2_CID_RDS_TX_RADIO_TEXT * = V4L2_CID_FM_TX_CLASS_BASE + 6;
	
		V4L2_CID_AUDIO_LIMITER_ENABLED * = V4L2_CID_FM_TX_CLASS_BASE + 64;
		V4L2_CID_AUDIO_LIMITER_RELEASE_TIME * = V4L2_CID_FM_TX_CLASS_BASE + 65;
		V4L2_CID_AUDIO_LIMITER_DEVIATION * = V4L2_CID_FM_TX_CLASS_BASE + 66;
	
		V4L2_CID_AUDIO_COMPRESSION_ENABLED * = V4L2_CID_FM_TX_CLASS_BASE + 80;
		V4L2_CID_AUDIO_COMPRESSION_GAIN * = V4L2_CID_FM_TX_CLASS_BASE + 81;
		V4L2_CID_AUDIO_COMPRESSION_THRESHOLD * = V4L2_CID_FM_TX_CLASS_BASE + 82;
		V4L2_CID_AUDIO_COMPRESSION_ATTACK_TIME * = V4L2_CID_FM_TX_CLASS_BASE + 83;
		V4L2_CID_AUDIO_COMPRESSION_RELEASE_TIME * = V4L2_CID_FM_TX_CLASS_BASE + 84;
	
		V4L2_CID_PILOT_TONE_ENABLED * = V4L2_CID_FM_TX_CLASS_BASE + 96;
		V4L2_CID_PILOT_TONE_DEVIATION * = V4L2_CID_FM_TX_CLASS_BASE + 97;
		V4L2_CID_PILOT_TONE_FREQUENCY * = V4L2_CID_FM_TX_CLASS_BASE + 98;
	
		V4L2_CID_TUNE_PREEMPHASIS * = V4L2_CID_FM_TX_CLASS_BASE + 112;
		
	TYPE v4l2_preemphasis * = LONGINT(*enum*);
	CONST 
		V4L2_PREEMPHASIS_DISABLED * = 0;
		V4L2_PREEMPHASIS_50_uS * = 1;
		V4L2_PREEMPHASIS_75_uS * = 2;
	
		V4L2_CID_TUNE_POWER_LEVEL * = V4L2_CID_FM_TX_CLASS_BASE + 113;
		V4L2_CID_TUNE_ANTENNA_CAPACITOR * = V4L2_CID_FM_TX_CLASS_BASE + 114;
	
	(*!	T U N I N G *)
	TYPE v4l2_tuner * = RECORD 
		index* : __u32;
		name* : ARRAY 32 OF __u8;
		ztype* : v4l2_tuner_type;
		capability* : __u32;
		rangelow* : __u32;
		rangehigh* : __u32;
		rxsubchans* : __u32;
		audmode* : __u32;
		signal* : __s32;
		afc* : __s32;
		reserved* : ARRAY 4 OF __u32;
	END;
	
	TYPE v4l2_modulator * = RECORD 
		index* : __u32;
		name* : ARRAY 32 OF __u8;
		capability* : __u32;
		rangelow* : __u32;
		rangehigh* : __u32;
		txsubchans* : __u32;
		reserved* : ARRAY 4 OF __u32;
	END;
	
	(*  Flags for the 'capability' field *)
	CONST 
		V4L2_TUNER_CAP_LOW * = 00001H;
		V4L2_TUNER_CAP_NORM * = 00002H;
		V4L2_TUNER_CAP_STEREO * = 00010H;
		V4L2_TUNER_CAP_LANG2 * = 00020H;
		V4L2_TUNER_CAP_SAP * = 00020H;
		V4L2_TUNER_CAP_LANG1 * = 00040H;
		V4L2_TUNER_CAP_RDS * = 00080H;
		V4L2_TUNER_CAP_RDS_BLOCK_IO * = 00100H;
		V4L2_TUNER_CAP_RDS_CONTROLS * = 00200H;
	
		(*  Flags for the 'rxsubchans' field *)
		V4L2_TUNER_SUB_MONO * = 00001H;
		V4L2_TUNER_SUB_STEREO * = 00002H;
		V4L2_TUNER_SUB_LANG2 * = 00004H;
		V4L2_TUNER_SUB_SAP * = 00004H;
		V4L2_TUNER_SUB_LANG1 * = 00008H;
		V4L2_TUNER_SUB_RDS * = 00010H;
	
		(*  Values for the 'audmode' field *)
		V4L2_TUNER_MODE_MONO * = 00000H;
		V4L2_TUNER_MODE_STEREO * = 00001H;
		V4L2_TUNER_MODE_LANG2 * = 00002H;
		V4L2_TUNER_MODE_SAP * = 00002H;
		V4L2_TUNER_MODE_LANG1 * = 00003H;
		V4L2_TUNER_MODE_LANG1_LANG2 * = 00004H;
	
	TYPE v4l2_frequency * = RECORD 
		tuner* : __u32;
		ztype* : v4l2_tuner_type;
		frequency* : __u32;
		reserved* : ARRAY 8 OF __u32;
	END;
	
	TYPE v4l2_hw_freq_seek * = RECORD 
		tuner* : __u32;
		ztype* : v4l2_tuner_type;
		seek_upward* : __u32;
		wrap_around* : __u32;
		spacing* : __u32;
		reserved* : ARRAY 7 OF __u32;
	END;
	
	(*!	R D S *)
	
	TYPE v4l2_rds_data * = RECORD 
		lsb* : __u8;
		msb* : __u8;
		block* : __u8;
	END;

	CONST 
		V4L2_RDS_BLOCK_MSK * = 07H;
		V4L2_RDS_BLOCK_A * = 0;
		V4L2_RDS_BLOCK_B * = 1;
		V4L2_RDS_BLOCK_C * = 2;
		V4L2_RDS_BLOCK_D * = 3;
		V4L2_RDS_BLOCK_C_ALT * = 4;
		V4L2_RDS_BLOCK_INVALID * = 7;

		V4L2_RDS_BLOCK_CORRECTED * = 040X;
		V4L2_RDS_BLOCK_ERROR * = 080X;

	(*!	A U D I O  *)
TYPE v4l2_audio * = RECORD 
		index* : __u32;
		name* : ARRAY 32 OF __u8;
		capability* : __u32;
		mode* : __u32;
		reserved* : ARRAY 2 OF __u32;
	END;
	
	(*  Flags for the 'capability' field *)
	CONST  
		V4L2_AUDCAP_STEREO * = 000001H;
	 	V4L2_AUDCAP_AVL * = 000002H;
	 
	 (*  Flags for the 'mode' field *)
	V4L2_AUDMODE_AVL * = 000001H;
	
	TYPE v4l2_audioout * = RECORD 
		index* : __u32;
		name* : ARRAY 32 OF __u8;
		capability* : __u32;
		mode* : __u32;
		reserved* : ARRAY 2 OF __u32;
	END;
	
	(*!
		M P E G   S E R V I C E S
	
		NOTE: EXPERIMENTAL API
	*)
	(*!  #if 1 *)
	
 CONST 
	V4L2_ENC_IDX_FRAME_I * = 0;
	V4L2_ENC_IDX_FRAME_P * = 1;
	V4L2_ENC_IDX_FRAME_B * = 2;
	V4L2_ENC_IDX_FRAME_MASK * = 0FH;
	
	TYPE v4l2_enc_idx_entry * = RECORD 
		offset* : __u64;
		pts* : __u64;
		length* : __u32;
		flags* : __u32;
		reserved* : ARRAY 2 OF __u32;
	END;
	
	CONST V4L2_ENC_IDX_ENTRIES * = 64;
	TYPE v4l2_enc_idx * = RECORD 
		entries* : __u32;
		entries_cap* : __u32;
		reserved* : ARRAY 4 OF __u32;
		entry* : ARRAY V4L2_ENC_IDX_ENTRIES OF v4l2_enc_idx_entry;
	END;
	
	
CONST 
	V4L2_ENC_CMD_START * = 0;
	 V4L2_ENC_CMD_STOP * = 1;
	 V4L2_ENC_CMD_PAUSE * = 2;
	 V4L2_ENC_CMD_RESUME * = 3;
	
	(* Flags for V4L2_ENC_CMD_STOP *)
	CONST V4L2_ENC_CMD_STOP_AT_GOP_END * = 1; (* 1 SHL  0 *);
	
	TYPE DataRaw*=RECORD data*: ARRAY 8 OF __u32; END;
	TYPE v4l2_encoder_cmd * = RECORD 
		cmd* : __u32;
		flags* : __u32;
		raw*: DataRaw;
				(*
				union:
				data* : ARRAY 8 OF __u32;
				*)
	END;

	(*! #endif *)
	
	
	(*!
	 *	D A T A   S E R V I C E S   ( V B I )
	 *
	 *	Data services API by Michael Schime
	 *)
	
	(* Raw VBI *)
	TYPE v4l2_vbi_format * = RECORD 
		sampling_rate* : __u32;		(* in 1 Hz *)
		offset* : __u32;
		samples_per_line* : __u32;
		sample_format* : __u32;		(* V4L2_PIX_FMT_* *)
		start* : ARRAY 2 OF __s32;
		count* : ARRAY 2 OF __u32;
		flags* : __u32;			(* V4L2_VBI_* *)
		reserved* : ARRAY 2 OF __u32;		(* must be zero *)
	END;
	
	(*!  VBI flags  *)
	
	
	CONST V4L2_VBI_UNSYNC * = 1; (* 1 SHL 0 *);
	CONST V4L2_VBI_INTERLACED * = 2; (*1 SHL 1;*)
	
	(* Sliced VBI
	 *
	 *    This implements is a proposal V4L2 API to allow SLICED VBI
	 * required for some hardware encoders. It should change without
	 * notice in the definitive implementation.
	 *)
	
	TYPE v4l2_sliced_vbi_format * = RECORD 
		service_set*: __u16;
		(* service_lines[0][...] specifies lines 0-23 (1-23 used) of the first field
		service_lines[1][...] specifies lines 0-23 (1-23 used) of the second field
		(equals frame lines 313-336 for 625 line video
		standards, 263-286 for 525 line standards) *)
		service_lines*: ARRAY 2, 24 OF __u16;
		io_size*: __u32;
		reserved*: ARRAY 2 OF __u32;            (* must be zero *)
	END;
	
	(* Teletext World System Teletext
	   (WST), defined on ITU-R BT.653-2 *)
	CONST 
		V4L2_SLICED_TELETEXT_B * = 00001H;
		(* Video Program System, defined on ETS 300 231*)
		V4L2_SLICED_VPS * = 00400H;
		(* Closed Caption, defined on EIA-608 *)
		V4L2_SLICED_CAPTION_525 * = 01000H;
		(* Wide Screen System, defined on ITU-R BT1119.1 *)
		V4L2_SLICED_WSS_625 * = 04000H;
	
		V4L2_SLICED_VBI_525 * = V4L2_SLICED_CAPTION_525;
		V4L2_SLICED_VBI_625 * = V4L2_SLICED_TELETEXT_B + V4L2_SLICED_VPS + V4L2_SLICED_WSS_625;
	
	TYPE v4l2_sliced_vbi_cap * = RECORD 
		service_set*: __u16;
		(* service_lines[0][...] specifies lines 0-23 (1-23 used) of the first field
		service_lines[1][...] specifies lines 0-23 (1-23 used) of the second field
		(equals frame lines 313-336 for 625 line video
		standards, 263-286 for 525 line standards) *)
		service_lines*: ARRAY 2, 24 OF __u16;
		ztype*: v4l2_buf_type;
		reserved*: ARRAY 3 OF __u32;    (* must be 0 *)
	END;
	
	TYPE v4l2_sliced_vbi_data * = RECORD 
		id*: __u32;
		field*: __u32;          (* 0: first field, 1: second field *)
		line*: __u32;           (* 1-23 *)
		reserved*: __u32;       (* must be 0 *)
		data*: ARRAY 48 OF __u8;
	END;
	
	(*
	 * Sliced VBI data inserted into MPEG Streams
	 *)
	
	(*
	 * V4L2_MPEG_STREAM_VBI_FMT_IVTV:
	 *
	 * Structure of payload contained in an MPEG 2 Private Stream 1 PES Packet in an
	 * MPEG-2 Program Pack that contains V4L2_MPEG_STREAM_VBI_FMT_IVTV Sliced VBI
	 * data
	 *
	 * Note, the MPEG-2 Program Pack and Private Stream 1 PES packet header
	 * definitions are not included here.  See the MPEG-2 specifications for details
	 * on these headers.
	 *)
	
	(* Line type IDs *)
	CONST 
		V4L2_MPEG_VBI_IVTV_TELETEXT_B * = 1;
		V4L2_MPEG_VBI_IVTV_CAPTION_525 * = 4;
		V4L2_MPEG_VBI_IVTV_WSS_625 * = 5;
		V4L2_MPEG_VBI_IVTV_VPS * = 7;
	
	TYPE v4l2_mpeg_vbi_itv0_line * = RECORD 
		id*: __u8;	(* One of V4L2_MPEG_VBI_IVTV_* above *)
		data*: ARRAY 42 OF __u8;	(* Sliced VBI data for the line *)
	END;

(*	TYPE v4l2_mpeg_vbi_itv0 * = RECORD 
		linemask: ARRAY 2 OF __le32; (* Bitmasks of VBI service lines present *)
		line: ARRAY 35 OF v4l2_mpeg_vbi_itv0_line;
	END;
*)	
	TYPE v4l2_mpeg_vbi_ITV0 * = RECORD 
		line*: ARRAY 36 OF v4l2_mpeg_vbi_itv0_line;
	END;

	CONST V4L2_MPEG_VBI_IVTV_MAGIC0 * = 'itv0';
		V4L2_MPEG_VBI_IVTV_MAGIC1 * = 'ITV0';
(*	
	TYPE v4l2_mpeg_vbi_fmt_ivtv * = RECORD 
		magic: ARRAY 4 OF __u8;
		TYPE  * = RECORD 
			CASE union:INTEGER OF 
			itv0: v4l2_mpeg_vbi_itv0;
			ITV0: v4l2_mpeg_vbi_ITV0;
		END;
	END v4l2_mpeg_vbi_fmt_ivtv;
	
	*)
	

	(*!	A G G R E G A T E   S T R U C T U R E S *)


(**
 * struct v4l2_plane_pix_format - additional, per-plane format definition
 * @sizeimage:		maximum size in bytes required for data, for which
 *			this plane will be used
 * @bytesperline:	distance in bytes between the leftmost pixels in two
 *			adjacent lines
 *)
TYPE v4l2_plane_pix_format* = RECORD
			sizeimage*: __u32;
			bytesperline*: __u16;
			reserved*: ARRAY 7 OF __u16;
END;

(**
 * struct v4l2_pix_format_mplane - multiplanar format definition
 * @width:		image width in pixels
 * @height:		image height in pixels
 * @pixelformat:	little endian four character code (fourcc)
 * @field:		field order (for interlaced video)
 * @colorspace:		supplemental to pixelformat
 * @plane_fmt:		per-plane information
 * @num_planes:		number of planes for this format
 *)
TYPE v4l2_pix_format_mplane* = RECORD
			width*: __u32;
			height*: __u32;
			pixelformat* : __u32;
			field*: v4l2_field;
			colorspace*: v4l2_colorspace;

			plane_fmt*: ARRAY VIDEO_MAX_PLANES OF v4l2_plane_pix_format;
			num_planes* : __u8;
			reserved* : ARRAY 11 OF __u8;
	END;


	(* Stream data format *)
	TYPE D200* = ARRAY 200 OF CHAR;
		
	TYPE v4l2_format * = RECORD 
		ztype* : v4l2_buf_type;
	(*	TYPE  * = RECORD 
			CASE union:INTEGER OF 
			pix* : v4l2_pix_format; (* V4L2_BUF_TYPE_VIDEO_CAPTURE *)
			pix_mp* : v4l2_pix_format_mplane; (* V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE *)
			win* : v4l2_window;     (* V4L2_BUF_TYPE_VIDEO_OVERLAY *)
			vbi* : v4l2_vbi_format;     (* V4L2_BUF_TYPE_VBI_CAPTURE *)
			sliced* : v4l2_sliced_vbi_format;  (* V4L2_BUF_TYPE_SLICED_VBI_CAPTURE *)
			raw_data* : ARRAY 200 OF __u8;                   (* user-defined *)
		END;
	*)	
		 fmt*: D200;
		
	END;
	
	
	(*	Stream type-dependent parameters  *)
	TYPE v4l2_streamparm * = RECORD 
		ztype* : v4l2_buf_type;
	(*	TYPE  * = RECORD 
			CASE union:INTEGER OF 
			capture* : v4l2_captureparm;
			output* : v4l2_outputparm;
			raw_data* : ARRAY 200 OF __u8;  (* user-defined *)
		END; *)
		parm*: D200;
	
	END;
	
	(*!	E V E N T S  *)
	
	CONST 
		V4L2_EVENT_ALL * = 0;
		V4L2_EVENT_VSYNC * = 1;
		V4L2_EVENT_EOS * = 2;
		V4L2_EVENT_PRIVATE_START * = 008000000H;
	
	(* Payload for V4L2_EVENT_VSYNC *)
	TYPE v4l2_event_vsync * = RECORD 
		(* Can be V4L2_FIELD_ANY, _NONE, _TOP or _BOTTOM *)
		field* : LONGINT; (* address *)
	END;

	TYPE Data64* = ARRAY 64 OF CHAR;
	TYPE v4l2_event * = RECORD 
		type* : __u32;
(*
		TYPE u=RECORD
		vsync:  v4l2_event_vsync;
		data: ARRAY 64 OF __u8;
		END;
*)		
		u* : Data64;

		pending* : __u32; 
		sequence * : __u32; 
		(*! timestamp: timespec; *)   (*! <------ neded timespec structure definition *)
		reserved* : ARRAY 9 OF __u32; 
	END;
	
	TYPE v4l2_event_subscription * = RECORD 
		type* : __u32;
		reserved* : ARRAY 7 OF __u32;
	END;
	
	(*!
	 *	A D V A N C E D   D E B U G G I N G
	 *	NOTE: EXPERIMENTAL API, NEVER RELY ON THIS IN APPLICATIONS!
	 *	FOR DEBUGGING, TESTING AND INTERNAL USE ONLY! *)
	
	
	(* VIDIOC_DBG_G_REGISTER and VIDIOC_DBG_S_REGISTER *)
	
	CONST 
		V4L2_CHIP_MATCH_HOST * = 0;  (* Match against chip ID on host (0 for the host) *)
		V4L2_CHIP_MATCH_I2C_DRIVER * = 1;  (* Match against I2C driver name *)
		V4L2_CHIP_MATCH_I2C_ADDR * = 2;  (* Match against I2C 7-bit address *)
		V4L2_CHIP_MATCH_AC97 * = 3;  (* Match against anciliary AC97 chip *)
	
	TYPE Data32* = ARRAY 32 OF CHAR;
	TYPE v4l2_dbg_match * = RECORD 
		type*: __u32; (* Match type *)
		(*
		TYPE  * = RECORD 
			CASE union:INTEGER OF (* Match this chip, meaning determined by type *)
			1 : (addr: __u32);
			2 : (name: ARRAY 32 OF CHAR);
		END;
		*)
		data*: Data32;
	END ;
	
	TYPE v4l2_dbg_register * = RECORD 
		match*: v4l2_dbg_match;
		size*: __u32;	(* register size in bytes *)
		reg*: __u64;
		val*: __u64;
	END;
	 (* VIDIOC_DBG_G_CHIP_IDENT *)
	TYPE v4l2_dbg_chip_ident * = RECORD 
		match*: v4l2_dbg_match;
		ident*: __u32;       (* chip identifier as specified in <media/v4l2-chip-ident.h> *)
		revision*: __u32;    (* chip revision, chip specific *)
	END;


(*!	I O C T L   C O D E S   F O R   V I D E O   D E V I C E S *)
VAR

	 VIDIOC_QUERYCAP -,   
	 VIDIOC_RESERVED -,   
	 VIDIOC_ENUM_FMT-, 
	 VIDIOC_G_FMT -,   
	 VIDIOC_S_FMT -,   
	 VIDIOC_REQBUFS -,   
	 VIDIOC_QUERYBUF -,   
	 VIDIOC_G_FBUF -,   
	 VIDIOC_S_FBUF -,   
	 VIDIOC_OVERLAY -,   
	 VIDIOC_QBUF -,   
	 VIDIOC_DQBUF -,  
	 VIDIOC_STREAMON -,   
	 VIDIOC_STREAMOFF -,   
	 VIDIOC_G_PARM -,   
	 VIDIOC_S_PARM -,   
	 VIDIOC_G_STD -,   
	 VIDIOC_S_STD -,   
	 VIDIOC_ENUMSTD -,   
	 VIDIOC_ENUMINPUT -,   
	 VIDIOC_G_CTRL -,   
	 VIDIOC_S_CTRL -,   
	 VIDIOC_G_TUNER -,   
	 VIDIOC_S_TUNER -,   
	 VIDIOC_G_AUDIO -,   
	 VIDIOC_S_AUDIO -,   
	 VIDIOC_QUERYCTRL -,   
	 VIDIOC_QUERYMENU -,   
	 VIDIOC_G_INPUT -,   
	 VIDIOC_S_INPUT -,  
	 VIDIOC_G_OUTPUT -,   
	 VIDIOC_S_OUTPUT -,   
	 VIDIOC_ENUMOUTPUT -,   
	 VIDIOC_G_AUDOUT -,   
	 VIDIOC_S_AUDOUT -,   
	 VIDIOC_G_MODULATOR -,   
	 VIDIOC_S_MODULATOR -,   
	 VIDIOC_G_FREQUENCY -,   
	 VIDIOC_S_FREQUENCY -,  
	 VIDIOC_CROPCAP -,   
	 VIDIOC_G_CROP -,   
	 VIDIOC_S_CROP -,   
	 VIDIOC_G_JPEGCOMP -,   
	 VIDIOC_S_JPEGCOMP -,   
	 VIDIOC_QUERYSTD -,   
	 VIDIOC_TRY_FMT -,   
	 VIDIOC_ENUMAUDIO -,   
	 VIDIOC_ENUMAUDOUT -,   
	 VIDIOC_G_PRIORITY -,   
	 VIDIOC_S_PRIORITY -,   
	 VIDIOC_G_SLICED_VBI_CAP -,   
	 VIDIOC_LOG_STATUS -,   
	 VIDIOC_G_EXT_CTRLS -,   
	 VIDIOC_S_EXT_CTRLS -,   
	 VIDIOC_TRY_EXT_CTRLS -,   
	(* #if 1 *)
	 VIDIOC_ENUM_FRAMESIZES -,   
	 VIDIOC_ENUM_FRAMEINTERVALS -,   
	 VIDIOC_G_ENC_INDEX -,   
	 VIDIOC_ENCOxDER_CMD -,   (*! ??? *)
	 VIDIOC_TRY_ENCOxDER_CMD -,   (*! ?? *)
	(* #endif *)
	
	(* #if 1 *)
	(* Experimental, meant for debugging, testing and internal use.
	Only implemented if CONFIG_VIDEO_ADV_DEBUG is defined.
	You must be root to use these ioctls. Never use these in applications! *)
	
	 VIDIOC_DBG_S_REGISTER -,   
	 VIDIOC_DBG_G_REGISTER -,   
	
	(* Experimental, meant for debugging, testing and internal use.
	Never use this ioctl in applications! *)
	 VIDIOC_DBG_G_CHIP_IDENT -,   
	(* #endif *)
	
	 VIDIOC_S_HW_FREQ_SEEK -,   
	 VIDIOC_ENUM_DV_PRESETS -,   
	 VIDIOC_S_DV_PRESET -,   
	 VIDIOC_G_DV_PRESET -,   
	 VIDIOC_QUERY_DV_PRESET -,   
	 VIDIOC_S_DV_TIMINGS -,   
	 VIDIOC_G_DV_TIMINGS -,   
	 VIDIOC_DQEVENT -,   
	 VIDIOC_SUBSCRIBE_EVENT -,   
	 VIDIOC_UNSUBSCRIBE_EVENT - : LONGINT;   


(*!  Pixel format FOURCC  depth  Description  *)
VAR
		(* RGB formats *)
	 V4L2_PIX_FMT_RGB332 - ,  
	 V4L2_PIX_FMT_RGB444 - , 
	 V4L2_PIX_FMT_RGB555 - ,
	 V4L2_PIX_FMT_RGB565 - , 
	 V4L2_PIX_FMT_RGB555X - , 
	 V4L2_PIX_FMT_RGB565X - , 
	 V4L2_PIX_FMT_BGR666 - , 
	 V4L2_PIX_FMT_BGR24 - , 
	 V4L2_PIX_FMT_RGB24 - , 
	 V4L2_PIX_FMT_BGR32 - , 
	 V4L2_PIX_FMT_RGB32 - , 

	(* Grey formats *)
	 V4L2_PIX_FMT_GREY - , 
	 V4L2_PIX_FMT_Y4 - , 
	 V4L2_PIX_FMT_Y6 - ,
	 V4L2_PIX_FMT_Y10 - , 
	 V4L2_PIX_FMT_Y16 - , 

	(* Palette formats *)
	 V4L2_PIX_FMT_PAL8 - , 

	(* Luminance+Chrominance formats *)
	 V4L2_PIX_FMT_YVU410 - , 
	 V4L2_PIX_FMT_YVU420 - , 
	 V4L2_PIX_FMT_YUYV - , 
	 V4L2_PIX_FMT_YYUV - , 
	 V4L2_PIX_FMT_YVYU - , 
	 V4L2_PIX_FMT_UYVY - , 
	 V4L2_PIX_FMT_VYUY - , 
	 V4L2_PIX_FMT_YUV422P - , 
	 V4L2_PIX_FMT_YUV411P - , 
	 V4L2_PIX_FMT_Y41P - , 
	 V4L2_PIX_FMT_YUV444 - , 
	 V4L2_PIX_FMT_YUV555 - , 
	 V4L2_PIX_FMT_YUV565 - , 
	 V4L2_PIX_FMT_YUV32 - , 
	 V4L2_PIX_FMT_YUV410 - , 
	 V4L2_PIX_FMT_YUV420 - , 
	 V4L2_PIX_FMT_HI240 - , 
	 V4L2_PIX_FMT_HM12 - , 
	
	(* two planes -- one Y, one Cr + Cb interleaved  *)
	 V4L2_PIX_FMT_NV12 - , 
	 V4L2_PIX_FMT_NV21 - , 
	 V4L2_PIX_FMT_NV16 - , 
	 V4L2_PIX_FMT_NV61 - , 
	
	(* Bayer formats - see http://www.siliconimaging.com/RGB%20Bayer.htm *)
	 V4L2_PIX_FMT_SBGGR8 - , 
	 V4L2_PIX_FMT_SGBRG8 - , 
	 V4L2_PIX_FMT_SGRBG8 - , 
	 V4L2_PIX_FMT_SRGGB8 - , 
	 V4L2_PIX_FMT_SBGGR10 - , 
	 V4L2_PIX_FMT_SGBRG10 - , 
	 V4L2_PIX_FMT_SGRBG10 - , 
	 V4L2_PIX_FMT_SRGGB10 - , 
	(* 10bit raw bayer DPCM compressed to 8 bits *)
	 V4L2_PIX_FMT_SGRBG10DPCM8 - , 
	(*
	* 10bit raw bayer, expanded to 16 bits
	* xxxxrrrrrrrrrrxxxxgggggggggg xxxxggggggggggxxxxbbbbbbbbbb...
	*)
	 V4L2_PIX_FMT_SBGGR16 - , 
	
		(* compressed formats *)
	 V4L2_PIX_FMT_MJPEG - , 
	 V4L2_PIX_FMT_JPEG - , 
	 V4L2_PIX_FMT_DV - , 
	 V4L2_PIX_FMT_MPEG - , 
	
	(*  Vendor-specific formats   *)
	 V4L2_PIX_FMT_CPIA1 - , 
	 V4L2_PIX_FMT_WNVA - , 
	 V4L2_PIX_FMT_SN9C10X - , 
	 V4L2_PIX_FMT_SN9C20X_I420 - , 
	 V4L2_PIX_FMT_PWC1 - , 
	 V4L2_PIX_FMT_PWC2 - , 
	 V4L2_PIX_FMT_ET61X251 - , 
	 V4L2_PIX_FMT_SPCA501 - , 
	 V4L2_PIX_FMT_SPCA505 - , 
	 V4L2_PIX_FMT_SPCA508 - , 
	 V4L2_PIX_FMT_SPCA561 - , 
	 V4L2_PIX_FMT_PAC207 - , 
	 V4L2_PIX_FMT_MR97310A - , 
	 V4L2_PIX_FMT_SN9C2028 - , 
	 V4L2_PIX_FMT_SQ905C - , 
	 V4L2_PIX_FMT_PJPG - , 
	 V4L2_PIX_FMT_OV511 - , 
	 V4L2_PIX_FMT_OV518 - , 
	 V4L2_PIX_FMT_STV0680 - , 
	 V4L2_PIX_FMT_TM6000 - , 
	 V4L2_PIX_FMT_CIT_YYVYUY - , 
	 V4L2_PIX_FMT_KONICA420 - : LONGINT; 
	 

	(* Four-character-code (FOURCC) *)
	PROCEDURE fourcc* (a, b, c, d: CHAR): LONGINT;
	BEGIN
		RETURN ORD(d) * 1000000H + ORD(c) * 10000H + ORD(b) * 100H + ORD(a);
	END fourcc;

	PROCEDURE IOC (dir, ztype, nr, size: LONGINT): LONGINT;
	BEGIN
		RETURN LSH(dir, IOC_DIRSHIFT) +
		LSH(ztype, IOC_TYPESHIFT) +
		LSH( nr, IOC_NRSHIFT) +
		LSH( size, IOC_SIZESHIFT);
	END IOC;

	
	(*!	Initialize I O C T L   C O D E S   F O R   V I D E O   D E V I C E S *)
	 PROCEDURE InitCTLS();
	 BEGIN
	 
	 VIDIOC_QUERYCAP := IOC(IOC_READ, ORD('V'),  0, SIZEOF(v4l2_capability));
	 VIDIOC_RESERVED := IOC(IOC_NONE, ORD('V'),  1, 0);
	 
	 VIDIOC_ENUM_FMT := IOC( IOC_READ + IOC_WRITE, ORD('V'),  2, SIZEOF(v4l2_fmtdesc));
	 (*! check size of v4l2_format *)
	VIDIOC_G_FMT := IOC(IOC_READ + IOC_WRITE, ORD('V'),  4, SIZEOF(v4l2_format));  
	 VIDIOC_S_FMT := IOC(IOC_READ + IOC_WRITE, ORD('V'),  5, SIZEOF(v4l2_format));
	 VIDIOC_REQBUFS := IOC(IOC_READ + IOC_WRITE, ORD('V'),  8, SIZEOF(v4l2_requestbuffers));
	 VIDIOC_QUERYBUF := IOC(IOC_READ + IOC_WRITE, ORD('V'),  9, SIZEOF(v4l2_buffer));
	  VIDIOC_G_FBUF := IOC(IOC_READ, ORD('V'), 10, SIZEOF(v4l2_framebuffer));
	 VIDIOC_S_FBUF := IOC(IOC_WRITE, ORD('V'), 11, SIZEOF(v4l2_framebuffer));
	 VIDIOC_OVERLAY := IOC(IOC_WRITE, ORD('V'), 14, SIZEOF(LONGINT)); (* int *)
	 VIDIOC_QBUF := IOC(IOC_READ + IOC_WRITE, ORD('V'), 15, SIZEOF(v4l2_buffer));
	 VIDIOC_DQBUF := IOC(IOC_READ + IOC_WRITE, ORD('V'), 17, SIZEOF(v4l2_buffer));
	 VIDIOC_STREAMON := IOC(IOC_WRITE, ORD('V'), 18, SIZEOF(LONGINT));
	 VIDIOC_STREAMOFF := IOC(IOC_WRITE, ORD('V'), 19, SIZEOF(LONGINT));
	 VIDIOC_G_PARM := IOC(IOC_READ + IOC_WRITE, ORD('V'), 21, SIZEOF(v4l2_streamparm));
	 VIDIOC_S_PARM := IOC(IOC_READ + IOC_WRITE, ORD('V'), 22, SIZEOF(v4l2_streamparm));
	 VIDIOC_G_STD := IOC(IOC_READ, ORD('V'), 23, SIZEOF(v4l2_std_id));
	 VIDIOC_S_STD := IOC(IOC_WRITE, ORD('V'), 24, SIZEOF(v4l2_std_id));
	 
	 VIDIOC_ENUMSTD := IOC(IOC_READ + IOC_WRITE, ORD('V'), 25, SIZEOF( v4l2_standard));
	 VIDIOC_ENUMINPUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 26, SIZEOF( v4l2_input));
	 VIDIOC_G_CTRL := IOC(IOC_READ + IOC_WRITE, ORD('V'), 27, SIZEOF( v4l2_control));
	 VIDIOC_S_CTRL := IOC(IOC_READ + IOC_WRITE, ORD('V'), 28, SIZEOF( v4l2_control));
	 VIDIOC_G_TUNER := IOC(IOC_READ + IOC_WRITE, ORD('V'), 29, SIZEOF( v4l2_tuner));
	 VIDIOC_S_TUNER := IOC(IOC_WRITE, ORD('V'), 30, SIZEOF( v4l2_tuner));
	
	 VIDIOC_G_AUDIO := IOC(IOC_READ, ORD('V'), 33, SIZEOF(v4l2_audio));
	 VIDIOC_S_AUDIO := IOC(IOC_WRITE, ORD('V'), 34, SIZEOF(v4l2_audio));
	 
	 VIDIOC_QUERYCTRL := IOC(IOC_READ + IOC_WRITE, ORD('V'), 36, SIZEOF( v4l2_queryctrl));
	 VIDIOC_QUERYMENU := IOC(IOC_READ + IOC_WRITE, ORD('V'), 37, SIZEOF( v4l2_querymenu));
	 VIDIOC_G_INPUT := IOC(IOC_READ, ORD('V'), 38, SIZEOF(__u32));
	 VIDIOC_S_INPUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 39, SIZEOF(__u32));
	 VIDIOC_G_OUTPUT := IOC(IOC_READ, ORD('V'), 46, SIZEOF(__u32));
	 VIDIOC_S_OUTPUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 47, SIZEOF(__u32));
	 
	 VIDIOC_ENUMOUTPUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 48, SIZEOF( v4l2_output));
	 VIDIOC_G_AUDOUT := IOC(IOC_READ, ORD('V'), 49, SIZEOF( v4l2_audioout));
	 VIDIOC_S_AUDOUT := IOC(IOC_WRITE, ORD('V'), 50, SIZEOF( v4l2_audioout));
	 VIDIOC_G_MODULATOR := IOC(IOC_READ + IOC_WRITE, ORD('V'), 54, SIZEOF( v4l2_modulator));
	 VIDIOC_S_MODULATOR := IOC(IOC_WRITE, ORD('V'), 55, SIZEOF( v4l2_modulator));
	 
	 
	 VIDIOC_G_FREQUENCY := IOC(IOC_READ + IOC_WRITE, ORD('V'), 56, SIZEOF(v4l2_frequency));
	 VIDIOC_S_FREQUENCY := IOC(IOC_WRITE, ORD('V'), 57, SIZEOF(v4l2_frequency));
	 VIDIOC_CROPCAP := IOC(IOC_READ + IOC_WRITE, ORD('V'), 58, SIZEOF(v4l2_cropcap));
	 VIDIOC_G_CROP := IOC(IOC_READ + IOC_WRITE, ORD('V'), 59, SIZEOF(v4l2_crop));
	
	 VIDIOC_S_CROP := IOC(IOC_WRITE, ORD('V'), 60, SIZEOF(v4l2_crop));

	 VIDIOC_G_JPEGCOMP := IOC(IOC_READ, ORD('V'), 61, SIZEOF( v4l2_jpegcompression));
	 VIDIOC_S_JPEGCOMP := IOC(IOC_WRITE, ORD('V'), 62, SIZEOF( v4l2_jpegcompression));
	 VIDIOC_QUERYSTD := IOC(IOC_READ, ORD('V'), 63, SIZEOF(v4l2_std_id));
	 VIDIOC_TRY_FMT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 64, SIZEOF( v4l2_format));
	 VIDIOC_ENUMAUDIO := IOC(IOC_READ + IOC_WRITE, ORD('V'), 65, SIZEOF( v4l2_audio));
	 VIDIOC_ENUMAUDOUT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 66, SIZEOF( v4l2_audioout));
	 VIDIOC_G_PRIORITY := IOC(IOC_READ, ORD('V'), 67, SIZEOF(v4l2_priority));
	 VIDIOC_S_PRIORITY := IOC(IOC_WRITE, ORD('V'), 68, SIZEOF(v4l2_priority));
	 VIDIOC_G_SLICED_VBI_CAP := IOC(IOC_READ + IOC_WRITE, ORD('V'), 69, SIZEOF( v4l2_sliced_vbi_cap));
	 VIDIOC_LOG_STATUS := IOC(IOC_NONE, ORD('V'), 70, 0); 
	 VIDIOC_G_EXT_CTRLS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 71, SIZEOF( v4l2_ext_controls));
	 VIDIOC_S_EXT_CTRLS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 72, SIZEOF( v4l2_ext_controls));
	 VIDIOC_TRY_EXT_CTRLS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 73, SIZEOF( v4l2_ext_controls));
	(* #if 1 *)
	 VIDIOC_ENUM_FRAMESIZES := IOC(IOC_READ + IOC_WRITE, ORD('V'), 74, SIZEOF( v4l2_frmsizeenum));
	 VIDIOC_ENUM_FRAMEINTERVALS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 75, SIZEOF( v4l2_frmivalenum));
	 VIDIOC_G_ENC_INDEX := IOC(IOC_READ, ORD('V'), 76, SIZEOF( v4l2_enc_idx));
	 VIDIOC_ENCOxDER_CMD := IOC(IOC_READ + IOC_WRITE, ORD('V'), 77, SIZEOF( v4l2_encoder_cmd));
	 VIDIOC_TRY_ENCOxDER_CMD := IOC(IOC_READ + IOC_WRITE, ORD('V'), 78, SIZEOF( v4l2_encoder_cmd));
	(* #endif *)
	
	(* #if 1 *)
	(* Experimental, meant for debugging, testing and internal use.
	Only implemented if CONFIG_VIDEO_ADV_DEBUG is defined.
	You must be root to use these ioctls. Never use these in applications! *)
	 VIDIOC_DBG_S_REGISTER := IOC(IOC_WRITE, ORD('V'), 79, SIZEOF( v4l2_dbg_register));
	 VIDIOC_DBG_G_REGISTER := IOC(IOC_READ + IOC_WRITE, ORD('V'), 80, SIZEOF( v4l2_dbg_register));
	
	(* Experimental, meant for debugging, testing and internal use.
	Never use this ioctl in applications! *)
	 VIDIOC_DBG_G_CHIP_IDENT := IOC(IOC_READ + IOC_WRITE, ORD('V'), 81, SIZEOF( v4l2_dbg_chip_ident));
	(* #endif *)
	
	 VIDIOC_S_HW_FREQ_SEEK := IOC(IOC_WRITE, ORD('V'), 82, SIZEOF( v4l2_hw_freq_seek));
	 VIDIOC_ENUM_DV_PRESETS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 83, SIZEOF( v4l2_dv_enum_preset));
	 VIDIOC_S_DV_PRESET := IOC(IOC_READ + IOC_WRITE, ORD('V'), 84, SIZEOF( v4l2_dv_preset));
	 VIDIOC_G_DV_PRESET := IOC(IOC_READ + IOC_WRITE, ORD('V'), 85, SIZEOF( v4l2_dv_preset));
	 VIDIOC_QUERY_DV_PRESET := IOC(IOC_READ, ORD('V'),  86, SIZEOF( v4l2_dv_preset));
	 VIDIOC_S_DV_TIMINGS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 87, SIZEOF( v4l2_dv_timings));
	 VIDIOC_G_DV_TIMINGS := IOC(IOC_READ + IOC_WRITE, ORD('V'), 88, SIZEOF( v4l2_dv_timings));
	 VIDIOC_DQEVENT := IOC(IOC_READ, ORD('V'), 89, SIZEOF( v4l2_event));
	 VIDIOC_SUBSCRIBE_EVENT := IOC(IOC_WRITE, ORD('V'), 90, SIZEOF( v4l2_event_subscription));
	 VIDIOC_UNSUBSCRIBE_EVENT := IOC(IOC_WRITE, ORD('V'), 91, SIZEOF( v4l2_event_subscription));
	

(*	 BASE_VIDIOC_PRIVATE := 192; *)		(* 192-255 are private *)
 

	(* -----     Pixel format   FOURCC  depth  Description ------ *)

		(* RGB formats *)
	 V4L2_PIX_FMT_RGB332 := fourcc('R', 'G', 'B', '1'); (*  8  RGB-3-3-2     *)
	 V4L2_PIX_FMT_RGB444 := fourcc('R', '4', '4', '4'); (* 16  xxxxrrrr ggggbbbb *)
	 V4L2_PIX_FMT_RGB555 := fourcc('R', 'G', 'B', 'O'); (* 16  RGB-5-5-5     *)
	 V4L2_PIX_FMT_RGB565 := fourcc('R', 'G', 'B', 'P'); (* 16  RGB-5-6-5     *)
	 V4L2_PIX_FMT_RGB555X := fourcc('R', 'G', 'B', 'Q'); (* 16  RGB-5-5-5 BE  *)
	 V4L2_PIX_FMT_RGB565X := fourcc('R', 'G', 'B', 'R'); (* 16  RGB-5-6-5 BE  *)
	 V4L2_PIX_FMT_BGR666 := fourcc('B', 'G', 'R', 'H'); (* 18  BGR-6-6-6	  *)
	 V4L2_PIX_FMT_BGR24 := fourcc('B', 'G', 'R', '3'); (* 24  BGR-8-8-8     *)
	 V4L2_PIX_FMT_RGB24 := fourcc('R', 'G', 'B', '3'); (* 24  RGB-8-8-8     *)
	 V4L2_PIX_FMT_BGR32 := fourcc('B', 'G', 'R', '4'); (* 32  BGR-8-8-8-8   *)
	 V4L2_PIX_FMT_RGB32 := fourcc('R', 'G', 'B', '4'); (* 32  RGB-8-8-8-8   *)

	(* Grey formats *)
	 V4L2_PIX_FMT_GREY := fourcc('G', 'R', 'E', 'Y'); (*  8  Greyscale     *)
	 V4L2_PIX_FMT_Y4 := fourcc('Y', '0', '4', ' '); (*  4  Greyscale     *)
	 V4L2_PIX_FMT_Y6 := fourcc('Y', '0', '6', ' '); (*  6  Greyscale     *)
	 V4L2_PIX_FMT_Y10 := fourcc('Y', '1', '0', ' '); (* 10  Greyscale     *)
	 V4L2_PIX_FMT_Y16 := fourcc('Y', '1', '6', ' '); (* 16  Greyscale     *)

	(* Palette formats *)
	 V4L2_PIX_FMT_PAL8 := fourcc('P', 'A', 'L', '8'); (*  8  8-bit palette *)

	(* Luminance+Chrominance formats *)
	 V4L2_PIX_FMT_YVU410 := fourcc('Y', 'V', 'U', '9'); (*  9  YVU 4:1:0     *)
	 V4L2_PIX_FMT_YVU420 := fourcc('Y', 'V', '1', '2'); (* 12  YVU 4:2:0     *)
	 V4L2_PIX_FMT_YUYV := fourcc('Y', 'U', 'Y', 'V'); (* 16  YUV 4:2:2     *)
	 V4L2_PIX_FMT_YYUV := fourcc('Y', 'Y', 'U', 'V'); (* 16  YUV 4:2:2     *)
	 V4L2_PIX_FMT_YVYU := fourcc('Y', 'V', 'Y', 'U'); (* 16 YVU 4:2:2 *)
	 V4L2_PIX_FMT_UYVY := fourcc('U', 'Y', 'V', 'Y'); (* 16  YUV 4:2:2     *)
	 V4L2_PIX_FMT_VYUY := fourcc('V', 'Y', 'U', 'Y'); (* 16  YUV 4:2:2     *)
	 V4L2_PIX_FMT_YUV422P := fourcc('4', '2', '2', 'P'); (* 16  YVU422 planar *)
	 V4L2_PIX_FMT_YUV411P := fourcc('4', '1', '1', 'P'); (* 16  YVU411 planar *)
	 V4L2_PIX_FMT_Y41P := fourcc('Y', '4', '1', 'P'); (* 12  YUV 4:1:1     *)
	 V4L2_PIX_FMT_YUV444 := fourcc('Y', '4', '4', '4'); (* 16  xxxxyyyy uuuuvvvv *)
	 V4L2_PIX_FMT_YUV555 := fourcc('Y', 'U', 'V', 'O'); (* 16  YUV-5-5-5     *)
	 V4L2_PIX_FMT_YUV565 := fourcc('Y', 'U', 'V', 'P'); (* 16  YUV-5-6-5     *)
	 V4L2_PIX_FMT_YUV32 := fourcc('Y', 'U', 'V', '4'); (* 32  YUV-8-8-8-8   *)
	 V4L2_PIX_FMT_YUV410 := fourcc('Y', 'U', 'V', '9'); (*  9  YUV 4:1:0     *)
	 V4L2_PIX_FMT_YUV420 := fourcc('Y', 'U', '1', '2'); (* 12  YUV 4:2:0     *)
	 V4L2_PIX_FMT_HI240 := fourcc('H', 'I', '2', '4'); (*  8  8-bit color   *)
	 V4L2_PIX_FMT_HM12 := fourcc('H', 'M', '1', '2'); (*  8  YUV 4:2:0 16x16 macroblocks *)
	
	(* two planes -- one Y, one Cr + Cb interleaved  *)
	 V4L2_PIX_FMT_NV12 := fourcc('N', 'V', '1', '2'); (* 12  Y/CbCr 4:2:0  *)
	 V4L2_PIX_FMT_NV21 := fourcc('N', 'V', '2', '1'); (* 12  Y/CrCb 4:2:0  *)
	 V4L2_PIX_FMT_NV16 := fourcc('N', 'V', '1', '6'); (* 16  Y/CbCr 4:2:2  *)
	 V4L2_PIX_FMT_NV61 := fourcc('N', 'V', '6', '1'); (* 16  Y/CrCb 4:2:2  *)
	
	(* Bayer formats - see http://www.siliconimaging.com/RGB%20Bayer.htm *)
	 V4L2_PIX_FMT_SBGGR8 := fourcc('B', 'A', '8', '1'); (*  8  BGBG.. GRGR.. *)
	 V4L2_PIX_FMT_SGBRG8 := fourcc('G', 'B', 'R', 'G'); (*  8  GBGB.. RGRG.. *)
	 V4L2_PIX_FMT_SGRBG8 := fourcc('G', 'R', 'B', 'G'); (*  8  GRGR.. BGBG.. *)
	 V4L2_PIX_FMT_SRGGB8 := fourcc('R', 'G', 'G', 'B'); (*  8  RGRG.. GBGB.. *)
	 V4L2_PIX_FMT_SBGGR10 := fourcc('B', 'G', '1', '0'); (* 10  BGBG.. GRGR.. *)
	 V4L2_PIX_FMT_SGBRG10 := fourcc('G', 'B', '1', '0'); (* 10  GBGB.. RGRG.. *)
	 V4L2_PIX_FMT_SGRBG10 := fourcc('B', 'A', '1', '0'); (* 10  GRGR.. BGBG.. *)
	 V4L2_PIX_FMT_SRGGB10 := fourcc('R', 'G', '1', '0'); (* 10  RGRG.. GBGB.. *)
	(* 10bit raw bayer DPCM compressed to 8 bits *)
	 V4L2_PIX_FMT_SGRBG10DPCM8 := fourcc('B', 'D', '1', '0');
	(*
	* 10bit raw bayer, expanded to 16 bits
	* xxxxrrrrrrrrrrxxxxgggggggggg xxxxggggggggggxxxxbbbbbbbbbb...
	*)
	 V4L2_PIX_FMT_SBGGR16 := fourcc('B', 'Y', 'R', '2'); (* 16  BGBG.. GRGR.. *)
	
		(* compressed formats *)
	 V4L2_PIX_FMT_MJPEG := fourcc('M', 'J', 'P', 'G'); (* Motion-JPEG   *)
	 V4L2_PIX_FMT_JPEG := fourcc('J', 'P', 'E', 'G'); (* JFIF JPEG     *)
	 V4L2_PIX_FMT_DV := fourcc('d', 'v', 's', 'd'); (* 1394          *)
	 V4L2_PIX_FMT_MPEG := fourcc('M', 'P', 'E', 'G'); (* MPEG-1/2/4    *)
	
	(*  Vendor-specific formats   *)
	 V4L2_PIX_FMT_CPIA1 := fourcc('C', 'P', 'I', 'A'); (* cpia1 YUV *)
	 V4L2_PIX_FMT_WNVA := fourcc('W', 'N', 'V', 'A'); (* Winnov hw compress *)
	 V4L2_PIX_FMT_SN9C10X := fourcc('S', '9', '1', '0'); (* SN9C10x compression *)
	 V4L2_PIX_FMT_SN9C20X_I420 := fourcc('S', '9', '2', '0'); (* SN9C20x YUV 4:2:0 *)
	 V4L2_PIX_FMT_PWC1 := fourcc('P', 'W', 'C', '1'); (* pwc older webcam *)
	 V4L2_PIX_FMT_PWC2 := fourcc('P', 'W', 'C', '2'); (* pwc newer webcam *)
	 V4L2_PIX_FMT_ET61X251 := fourcc('E', '6', '2', '5'); (* ET61X251 compression *)
	 V4L2_PIX_FMT_SPCA501 := fourcc('S', '5', '0', '1'); (* YUYV per line *)
	 V4L2_PIX_FMT_SPCA505 := fourcc('S', '5', '0', '5'); (* YYUV per line *)
	 V4L2_PIX_FMT_SPCA508 := fourcc('S', '5', '0', '8'); (* YUVY per line *)
	 V4L2_PIX_FMT_SPCA561 := fourcc('S', '5', '6', '1'); (* compressed GBRG bayer *)
	 V4L2_PIX_FMT_PAC207 := fourcc('P', '2', '0', '7'); (* compressed BGGR bayer *)
	 V4L2_PIX_FMT_MR97310A := fourcc('M', '3', '1', '0'); (* compressed BGGR bayer *)
	 V4L2_PIX_FMT_SN9C2028 := fourcc('S', 'O', 'N', 'X'); (* compressed GBRG bayer *)
	 V4L2_PIX_FMT_SQ905C := fourcc('9', '0', '5', 'C'); (* compressed RGGB bayer *)
	 V4L2_PIX_FMT_PJPG := fourcc('P', 'J', 'P', 'G'); (* Pixart 73xx JPEG *)
	 V4L2_PIX_FMT_OV511 := fourcc('O', '5', '1', '1'); (* ov511 JPEG *)
	 V4L2_PIX_FMT_OV518 := fourcc('O', '5', '1', '8'); (* ov518 JPEG *)
	 V4L2_PIX_FMT_STV0680 := fourcc('S', '6', '8', '0'); (* stv0680 bayer *)
	 V4L2_PIX_FMT_TM6000 := fourcc('T', 'M', '6', '0'); (* tm5600/tm60x0 *)
	 V4L2_PIX_FMT_CIT_YYVYUY := fourcc('C', 'I', 'T', 'V'); (* one line of Y then 1 line of VYUY *)
	 V4L2_PIX_FMT_KONICA420 := fourcc('K', 'O', 'N', 'I'); (* YUV420 planar in blocks of 256 pixels *)

END InitCTLS;

	
BEGIN	
	InitCTLS();
END V4L2.


SystemTools.Free V4L2 ~ 

