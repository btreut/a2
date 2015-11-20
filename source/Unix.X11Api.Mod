MODULE X11Api; (** AUTHOR "fnecati"; PURPOSE "some missing types, const and functions in Unix.X11.Mod"; *)

IMPORT
	X11, Unix, Modules, SYSTEM;

TYPE 
	PChar* = POINTER TO ARRAY OF CHAR;

	VisualPtr = X11.VisualPtr;
	VisualInfoPtr*  = POINTER TO X11.VisualInfo; 
	DisplayPtr* = X11.DisplayPtr;
	Window * = X11.Window;
	Time* = X11.Time;
	Pixmap = X11.Pixmap;
	Cursor* = X11.Cursor;
	Atom* = X11.Atom;
	XID* = LONGINT;

	Drawable* = X11.Drawable;
	Colormap* = X11.Colormap;
	ComposeStatus* = RECORD 
		composePtr*: LONGINT; 	(* state table pointer *)
		charsMatched*: LONGINT;  (* match state *)
	 END ;
	 
	KeySym* = X11.KeySym;
	
	(* Cursor control & motion *)
	(* X11/keysymdef.h *)
CONST

	XK_Home* = 	0FF50H;
	XK_Left* = 	0FF51H;  (* Move left, left arrow *)
	XK_Up* = 	0FF52H;  (* Move up, up arrow *)
	XK_Right* = 	0FF53H;  (* Move right, right arrow *)
	XK_Down* = 	0FF54H;  (* Move down, down arrow *)
	XK_Prior* = 	0FF55H;  (* Prior, previous *)
	XK_Page_Up* = 	0FF55H;
	XK_Next* = 	0FF56H;  (* Next *)
	XK_Page_Down* = 0FF56H;
	XK_End* = 	0FF57H;  (* EOL *)
	XK_Begin* = 	0FF58H;  (* BOL *)

	XK_Escape* = 0FF1BH;
	XK_F1* =0FFBEH;
	
	(*  X11/X.h *)
(* ****************************************************************
                       RESERVED RESOURCE AND CONSTANT DEFINITIONS
**************************************************************** *)
 
	None* = 0;	(* universal null resource or null atom *)
	ParentRelative* = 1;	(* background pixmap in CreateWindow
					    and ChangeWindowAttributes *)
	CopyFromParent* = 0;	(* border pixmap in CreateWindow
					       and ChangeWindowAttributes
					   special VisualID and special window
					       class passed to CreateWindow *)
	PointerWindow* = 0;	(* destination window in SendEvent *)
	InputFocus* = 1;	(* destination window in SendEvent *)
	PointerRoot* = 1;	(* focus window in SetInputFocus *)
	AnyPropertyType* = 0;	(* special Atom, passed to GetProperty *)
	AnyKey* = 0;	(* special Key Code, passed to GrabKey *)
	AnyButton* = 0;	(* special Button Code, passed to GrabButton *)
	AllTemporary* = 0;	(* special Resource ID passed to KillClient *)
	CurrentTime* = 0;	(* special Time *)
	NoSymbol* = 0;	(* special KeySym *)


	(* EVENT DEFINITIONS
	  Input Event Masks. Used as event-mask window attribute and as arguments
	   to Grab requests.  Not to be confused with event names. *)

CONST
	NoEventMask* = 0H;  KeyPressMask* = 1H; KeyReleaseMask* = 2H;
	ButtonPressMask* = 4H;  ButtonReleaseMask* = 8H;  EnterWindowMask* = 10H;  
	LeaveWindowMask* = 20H;  PointerMotionMask* = 40H;  PointerMotionHintMask* = 80H;  
	Button1MotionMask* = 100H; Button2MotionMask* = 200H; Button3MotionMask* = 400H; 
	Button4MotionMask* = 800H;  Button5MotionMask* = 1000H;  ButtonMotionMask* = 2000H;
	KeymapStateMask* = 4000H; ExposureMask* = 8000H; VisibilityChangeMask* = 10000H; 
	StructureNotifyMask* = 20000H; ResizeRedirectMask* = 40000H; SubstructureNotifyMask* = 80000H; 
	SubstructureRedirectMask* = 100000H; FocusChangeMask * = 200000H; PropertyChangeMask* = 400000H; 
	ColormapChangeMask* = 800000H; OwnerGrabButtonMask* = 1000000H; 

	(* Event names.  Used in "type" field in XEvent structures.  Not to be
	confused with event masks above.  They start from 2 because 0 and 1
	are reserved in the protocol for errors and replies. *)

CONST
	KeyPress* = 2;  KeyRelease* =3;  ButtonPress* = 4;  ButtonRelease* = 5;  MotionNotify* =6;
	EnterNotify* = 7; LeaveNotify* =8;  FocusIn* = 9;  FocusOut* = 10;  KeymapNotify* = 11;
	Expose* = 12;  GraphicsExpose* = 13;  NoExpose* = 14;  VisibilityNotify* = 15;
	CreateNotify* = 16; DestroyNotify* = 17; UnmapNotify* = 18;  MapNotify* = 19;
	MapRequest* = 20;  ReparentNotify* = 21; ConfigureNotify* = 22; ConfigureRequest* = 23;
	GravityNotify* = 24; ResizeRequest* =	25; CirculateNotify* = 26; CirculateRequest* = 27;
	PropertyNotify* = 28; SelectionClear* = 29; SelectionRequest* =30; SelectionNotify* = 31;
	ColormapNotify* = 32;  ClientMessage* = 33;  MappingNotify* = 34;  GenericEvent* = 35;
	LASTEvent* =		36;	 (* must be bigger than any event # *)


	(* Key masks. Used as modifiers to GrabButton and GrabKey, results of QueryPointer,
	state in various key-, mouse-, and button-related events. *)

	ShiftMask* = 0;  LockMask* = 1;  ControlMask* = 2;
	Mod1Mask* = 3;  Mod2Mask* = 4;  Mod3Mask* = 5;
	Mod4Mask* = 6;   Mod5Mask* = 7;

	(* modifier names.  Used to build a SetModifierMapping request or
	to read a GetModifierMapping request.  These correspond to the
	masks defined above. *)
	ShiftMapIndex* =	0;  LockMapIndex* = 1; ControlMapIndex* = 2;
	Mod1MapIndex* =	3; Mod2MapIndex* = 4; Mod3MapIndex* = 5;
	Mod4MapIndex* =	6; Mod5MapIndex* = 7;

	(* button masks.  Used in same manner as Key masks above. Not to be confused
	with button names below. *)
	Button1Mask* = 8; Button2Mask* = 9; Button3Mask* = 10;
	Button4Mask* = 11; Button5Mask* = 12;
  
	AnyModifier* = 15;  (* used in GrabButton, GrabKey *)

	(* button names. Used as arguments to GrabButton and as detail in ButtonPress
	and ButtonRelease events.  Not to be confused with button masks above.
	Note that 0 is already defined above as "AnyButton".  *)

	Button1* = 1; Button2* = 2; Button3* = 3;
	Button4* = 4; Button5* = 5;

	(* Notify modes *)
	NotifyNormal* = 0; NotifyGrab* = 1; NotifyUngrab* = 2; NotifyWhileGrabbed* =	3;

	NotifyHint* = 1; (* for MotionNotify events *)
		       
	(* Notify detail *)
	NotifyAncestor* = 0; NotifyVirtual* = 1; NotifyInferior* = 2; NotifyNonlinear* = 3;
	NotifyNonlinearVirtual* = 4; NotifyPointer* = 5; NotifyPointerRoot* = 6;
	NotifyDetailNone* = 7;

	(* Visibility notify *)
	VisibilityUnobscured* =  0; VisibilityPartiallyObscured* = 1; VisibilityFullyObscured* = 2;

	(* Circulation request *)
	PlaceOnTop* = 0; PlaceOnBottom* = 1;

	(* protocol families *)
	FamilyInternet* = 0; (* IPv4 *)  FamilyDECnet* = 1;  FamilyChaos* = 2; FamilyInternet6* = 6; (* IPv6 *)

	(* authentication families not tied to a specific protocol *)
	FamilyServerInterpreted* = 5;

	(* Property notification *)
	PropertyNewValue* = 0;  PropertyDelete* = 1;

	(* Color Map notification *)
	ColormapUninstalled* = 0; ColormapInstalled* = 1;

	(* GrabPointer, GrabButton, GrabKeyboard, GrabKey Modes *)
	GrabModeSync* = 0;  GrabModeAsync* = 1;

	(* GrabPointer, GrabKeyboard reply status *)
	GrabSuccess* = 0; AlreadyGrabbed* = 1; GrabInvalidTime* = 2; GrabNotViewable* = 3; GrabFrozen* = 4;

	(* AllowEvents modes *)
	AsyncPointer* = 0; SyncPointer* = 1; ReplayPointer* = 2; AsyncKeyboard* = 3;
	SyncKeyboard* = 4; ReplayKeyboard* = 5; AsyncBoth* = 6; SyncBoth* = 7;

	(* Used in SetInputFocus, GetInputFocus *)
	RevertToNone* = None;  RevertToPointerRoot* = PointerRoot; RevertToParent* = 2;
  


(* ****************************************************************
						 ERROR CODES  
 **************************************************************** *)

CONST
	Success* =	 0; (* everything's okay *)
	BadRequest* = 1; (* bad request code *)
	BadValue* =	   2;	(* int parameter out of range *)
	BadWindow* = 3; (* parameter not a Window *)
	BadPixmap* =	4; (* parameter not a Pixmap *)
	BadAtom* = 5; (* parameter not an Atom *)
	BadCursor* = 6; (* parameter not a Cursor *)
	BadFont* = 7; (* parameter not a Font *)
	BadMatch* = 8; (* parameter mismatch *)
	BadDrawable* = 9; (* parameter not a Pixmap or Window *)
	BadAccess* = 10; (* depending on context:
				 - key/button already grabbed
				 - attempt to free an illegal 
				   cmap entry 
				- attempt to store into a read-only 
				   color map entry.
 				- attempt to modify the access control
				   list from other than the local host.
				*)
	BadAlloc* = 11; (* insufficient resources *)
	BadColor* = 12; (* no such colormap *)
	BadGC* = 13; (* parameter not a GC *)
	BadIDChoice* = 14; (* choice not in range or already used *)
	BadName* = 15; (* font or color name doesn't exist *)
	BadLength* = 16;	(* Request length incorrect *)
	BadImplementation* = 17;	(* server is defective *)

	FirstExtensionError* = 128;
	LastExtensionError* = 255;
  

(* ****************************************************************
						 WINDOW DEFINITIONS 
 **************************************************************** *)
	
	(*  Window classes used by CreateWindow *)
	(* Note that CopyFromParent is already defined as 0 above *)
	InputOutput* = 1; InputOnly* = 2;

	(* Window attributes for CreateWindow and ChangeWindowAttributes *)
	CWBackPixmap* = 1H; CWBackPixel* = 2H; CWBorderPixmap* = 4H; CWBorderPixel* = 8H;
	CWBitGravity* = 10H; CWWinGravity* = 20H; CWBackingStore* = 40H;  CWBackingPlanes* = 80;
	CWBackingPixel* = 100H; CWOverrideRedirect* = 200H; CWSaveUnder* =400H; CWEventMask* =800H;
	CWDontPropagate* =1000H; CWColormap* = 2000H; CWCursor* =4000H;

	(* ConfigureWindow structure *)
	CWX* = 1H;  CWY* = 2H; CWWidth* = 4H; CWHeight* = 8H; CWBorderWidth* = 10H;
	CWSibling* = 20H; CWStackMode* = 40H;

	(* Bit Gravity *)
	ForgetGravity* = 0; NorthWestGravity* = 1; NorthGravity* = 2; NorthEastGravity* = 3;
	WestGravity* = 4; CenterGravity *= 5; EastGravity* = 6; SouthWestGravity* = 7;
	SouthGravity* = 8; SouthEastGravity* = 9; StaticGravity* = 10;

	(* Window gravity + bit gravity above *)
	UnmapGravity* = 0;

	(* Used in CreateWindow for backing-store hint *)
	NotUseful* = 0; WhenMapped* = 1; Always*= 2;

	(* Used in GetWindowAttributes reply *)
	IsUnmapped* = 0; IsUnviewable* = 1; IsViewable*= 2;

	(* Used in ChangeSaveSet *)
	SetModeInsert* = 0; SetModeDelete* = 1;

	(* Used in ChangeCloseDownMode *)
	DestroyAll* = 0; RetainPermanent* = 1; RetainTemporary* = 2;

	(* Window stacking method (in configureWindow) *)
	Above* =  0; Below* =1; TopIf* = 2; BottomIf* = 3; Opposite* = 4;

	(* Circulation direction *)
	RaiseLowest* = 0; LowerHighest* = 1;

	(* Property modes *)
	PropModeReplace* = 0; PropModePrepend* = 1; PropModeAppend * = 2;

(* ****************************************************************
                            GRAPHICS DEFINITIONS  not translated yet
 **************************************************************** *)



(* **************************************************************** 
                                             FONTS 
************************************************************* *)
(* used in QueryFont -- draw direction *)
	FontLeftToRight* = 0;
	FontRightToLeft* = 1;
	FontChange* = 255;

(* **************************************************************** 
                                            IMAGING 
 ************************************************************** *)
(* ImageFormat -- PutImage, GetImage *)
	XYBitmap* = 0; (* depth 1, XYFormat *)
	XYPixmap* = 1; (* depth == drawable depth *)
	ZPixmap* = 2; (* depth == drawable depth *)


(* **************************************************************** 
                                         COLOR MAP STUFF
***************************************************************** *)
(* For CreateColormap *)
	AllocNone* = 0;	(* create map with no entries *)
	AllocAll* = 1;	(* allocate entire map writeable *)

(* Flags used in StoreNamedColor, StoreColors *)
	DoRed* = 1H; DoGreen* = 2H; DoBlue* = 4H;

(* **************************************************************** 
                                           CURSOR STUFF  
 **************************************************************** *)
(* QueryBestSize Class *)
	CursorShape* = 0; (* largest size that can be displayed *)
	TileShape* = 1; (* size tiled fastest *)
	StippleShape* = 2; (* size stippled fastest *)

(* **************************************************************** 
                                      KEYBOARD/POINTER STUFF
 **************************************************************** *)

	AutoRepeatModeOff*= 0; AutoRepeatModeOn* = 1; AutoRepeatModeDefault* = 2;
	
	LedModeOff* = 0; LedModeOn* = 1;

	(* masks for ChangeKeyboardControl *)
	KBKeyClickPercent* =  1H;  KBBellPercent* =  2H; KBBellPitch* =  4H; 	KBBellDuration* =  8H;
	KBLed* =  10H; KBLedMode* =  20H; KBKey* =  40H; KBAutoRepeatMode* =  80;
	
	MappingSuccess* = 0; MappingBusy* = 1; MappingFailed* = 2;
	MappingModifier* = 0; MappingKeyboard* = 1; MappingPointer* = 2;

(* ****************************************************************
                                              SCREEN SAVER STUFF 
 **************************************************************** *)
  DontPreferBlanking* = 0; PreferBlanking* = 1; DefaultBlanking* = 2;
  DisableScreenSaver* = 0; DisableScreenInterval* = 0;
  DontAllowExposures* = 0; AllowExposures* = 1; DefaultExposures* =2;

(* for ForceScreenSaver *)
  ScreenSaverReset* = 0; ScreenSaverActive* = 1;

(* ****************************************************************
                             HOSTS AND CONNECTIONS
 **************************************************************** *)

	(* for ChangeHosts *)
 	HostInsert* = 0; HostDelete* = 1;

	(* for ChangeAccessControl *)
	EnableAccess* = 1; DisableAccess* = 0;

	(* Display classes  used in opening the connection 
	  Note that the statically allocated ones are even numbered and the
	  dynamically changeable ones are odd numbered *)

	StaticGray* = 0; GrayScale* = 1; StaticColor* = 2; PseudoColor* = 3;
	TrueColor* = 4;  DirectColor* = 5;

	(* Byte order  used in imageByteOrder and bitmapBitOrder *)
	LSBFirst* = 0; MSBFirst* = 1;


(* ****************************************************************
						ATOMS  <X11/Xatom.h> 
 **************************************************************** *)
	
	(* Do not change!  Changing this file implies a protocol change! *)
	XA_PRIMARY * = 1;  XA_SECONDARY * = 2;  XA_ARC * = 3;  XA_ATOM * = 4;  XA_BITMAP * = 5;
	XA_CARDINAL * = 6;  XA_COLORMAP * = 7;  XA_CURSOR * = 8;  XA_CUT_BUFFER0 * = 9;
	XA_CUT_BUFFER1 * = 10;  XA_CUT_BUFFER2 * = 11;  XA_CUT_BUFFER3 * = 12;  XA_CUT_BUFFER4 * = 13;
	XA_CUT_BUFFER5 * = 14;  XA_CUT_BUFFER6 * = 15;  XA_CUT_BUFFER7 * = 16;  XA_DRAWABLE * = 17;
	XA_FONT * = 18;  XA_INTEGER * = 19;  XA_PIXMAP * = 20;  XA_POINT * = 21;  XA_RECTANGLE * = 22;
	XA_RESOURCE_MANAGER * = 23;  XA_RGB_COLOR_MAP * = 24;  XA_RGB_BEST_MAP * = 25;
	XA_RGB_BLUE_MAP * = 26;  XA_RGB_DEFAULT_MAP * = 27;  XA_RGB_GRAY_MAP * = 28;
	XA_RGB_GREEN_MAP * = 29;  XA_RGB_RED_MAP * = 30;  XA_STRING * = 31;  XA_VISUALID * = 32;
	XA_WINDOW * = 33;  XA_WM_COMMAND * = 34;  XA_WM_HINTS * = 35;  XA_WM_CLIENT_MACHINE * = 36;
	XA_WM_ICON_NAME * = 37;  XA_WM_ICON_SIZE * = 38;  XA_WM_NAME * = 39;  XA_WM_NORMAL_HINTS * = 40;
	XA_WM_SIZE_HINTS * = 41;  XA_WM_ZOOM_HINTS * = 42;  XA_MIN_SPACE * = 43;  XA_NORM_SPACE * = 44;
	XA_MAX_SPACE * = 45;  XA_END_SPACE * = 46;  XA_SUPERSCRIPT_X * = 47;  XA_SUPERSCRIPT_Y * = 48;
	XA_SUBSCRIPT_X * = 49;  XA_SUBSCRIPT_Y * = 50;  XA_UNDERLINE_POSITION * = 51;  XA_UNDERLINE_THICKNESS * = 52;
	XA_STRIKEOUT_ASCENT * = 53;  XA_STRIKEOUT_DESCENT * = 54;  XA_ITALIC_ANGLE * = 55;
	XA_X_HEIGHT * = 56;  XA_QUAD_WIDTH * = 57;  XA_WEIGHT * = 58;  XA_POINT_SIZE * = 59;
	XA_RESOLUTION * = 60;  XA_COPYRIGHT * = 61;  XA_NOTICE * = 62;  XA_FONT_NAME * = 63;
	XA_FAMILY_NAME * = 64;  XA_FULL_NAME * = 65;  XA_CAP_HEIGHT * = 66;  XA_WM_CLASS * = 67;
	XA_WM_TRANSIENT_FOR * = 68;  XA_LAST_PREDEFINED * = 68;

(* ****************************************************************
			CURSORS  <X11/Xcursorfont.h> 
 **************************************************************** *)
CONST
	 XC_num_glyphs* = 154; 
	 XC_X_cursor* = 0;  XC_arrow* = 2;  XC_based_arrow_down* = 4; XC_based_arrow_up* = 6;
	 XC_boat* = 8; XC_bogosity* = 10; XC_bottom_left_corner* = 12; XC_bottom_right_corner* = 14;
	 XC_bottom_side* = 16; XC_bottom_tee* = 18; XC_box_spiral* = 20; XC_center_ptr* = 22;
	 XC_circle* = 24; XC_clock* = 26; XC_coffee_mug* = 28; XC_cross* = 30; XC_cross_reverse* = 32;
	 XC_crosshair* = 34; XC_diamond_cross* = 36; XC_dot* = 38; XC_dotbox* = 40; XC_double_arrow* = 42;
	 XC_draft_large* = 44; XC_draft_small* = 46; XC_draped_box* = 48; XC_exchange* = 50;
	 XC_fleur* = 52; XC_gobbler* = 54; XC_gumby* = 56; XC_hand1* = 58; XC_hand2* = 60;
	 XC_heart* = 62; XC_icon* = 64; XC_iron_cross* = 66; XC_left_ptr* = 68; XC_left_side* = 70;
	 XC_left_tee* = 72; XC_leftbutton* = 74; XC_ll_angle* = 76; XC_lr_angle* = 78; XC_man* = 80;
	 XC_middlebutton* = 82; XC_mouse* = 84; XC_pencil* = 86; XC_pirate* = 88; XC_plus* = 90;
	 XC_question_arrow* = 92; XC_right_ptr* = 94; XC_right_side* = 96; XC_right_tee* = 98;
	 XC_rightbutton* = 100; XC_rtl_logo* = 102; XC_sailboat* = 104; XC_sb_down_arrow* = 106;
	 XC_sb_h_double_arrow* = 108; XC_sb_left_arrow* = 110; XC_sb_right_arrow* = 112; 
	 XC_sb_up_arrow* = 114; XC_sb_v_double_arrow* = 116; XC_shuttle* = 118; XC_sizing* = 120;
	 XC_spider* = 122; XC_spraycan* = 124; XC_star* = 126; XC_target* = 128; XC_tcross* = 130;
	 XC_top_left_arrow* = 132; XC_top_left_corner* = 134; XC_top_right_corner* = 136;
	 XC_top_side* = 138; XC_top_tee* = 140; XC_trek* = 142; XC_ul_angle* = 144;
	 XC_umbrella* = 146; XC_ur_angle* = 148; XC_watch* = 150; XC_xterm* = 152;

(* *********************************************** *)
	(* X11/Xlib.h*) 	
(* *********************************************** *)
TYPE	
	Bool* = LONGINT;
	Status* = LONGINT;

CONST 
	True* = 1; False* = 0;
	QueuedAlready* = 0; QueuedAfterReading* = 1; QueuedAfterFlush* = 2;
	
TYPE 
	XSetWindowAttributes* = RECORD
		backgroundPixmap*: Pixmap; (* background, None, or ParentRelative *)
		backgroundPixel*: LONGINT;(* background pixel *)
		borderPixmap*: Pixmap;    (* border of the window or CopyFromParent *)
		borderPixel*: LONGINT;(* border pixel value *)
		bitGravity*: LONGINT;         (* one of bit gravity values *)
		winGravity*: LONGINT;         (* one of the window gravity values *)
		backingStore*: LONGINT;       (* NotUseful, WhenMapped, Always *)
		backingPlanes*: LONGINT;(* planes to be preserved if possible *)
		backingPixel*: LONGINT;(* value to use in restoring planes *)
		saveUnder*: BOOLEAN;         (* should bits under be saved? (popups) *)
		eventMask*:  LONGINT;         (* set of events that should be saved *)
		doNotPropagateMask*: LONGINT;(* set of events that should not propagate *)
		overrideRedirect*: BOOLEAN;  (* boolean value for override_redirect *)
		colormap*: Colormap;       (* color map to be associated with window *)
		cursor*: Cursor ;           (* cursor to be displayed (or None) *)
	END ;
    	   
	XWindowAttributes* = RECORD
		x*, y*: LONGINT;			(* location of window *)
		width*, height*: LONGINT;		(* width and height of window *)
		borderWidth*: LONGINT;			(* border width of window *)
		depth*: LONGINT;			(* depth of window *)
		visual* : VisualPtr;			(* the associated visual structure *)
		root* : Window;				(* root of screen containing window *)
		class*: LONGINT;			(* InputOutput, InputOnly*)
		bitGravity*: LONGINT;			(* one of the bit gravity values *)
		winGravity*: LONGINT;			(* one of the window gravity values *)
		backingStore*: LONGINT;		(* NotUseful, WhenMapped, Always *)
		backingPlanes*: LONGINT;		(* planes to be preserved if possible *)
		backingPixel*: LONGINT;		(* value to be used when restoring planes *)
		saveUnder*: BOOLEAN;			(* boolean, should bits under be saved? *)
		colormap*: Colormap;			(* color map to be associated with window *)
		mapInstalled*: BOOLEAN;		(* boolean, is color map currently installed*)
		mapState*: LONGINT;		(* IsUnmapped, IsUnviewable, IsViewable *)
		allEventMasks*: LONGINT;		(* set of events all people have interest in*)
		yourEventMask*: LONGINT;		(* my event mask *)
		doNotPropagateMask*: LONGINT;	(* set of events that should not propagate *)
		overrideRedirect*: BOOLEAN;		(* boolean value for override-redirect *)
		screen*: LONGINT; (*X11.Screen;*)			(* back pointer to correct screen *)
	END;

	(* Data structure for host setting; getting routines. *)
	TYPE XHostAddress* = RECORD
			family* : LONGINT;		(* for example FamilyInternet *)
			length* : LONGINT;		(* length of address, in bytes *)
			address*: ADDRESS;		(* pointer to where to find the bytes *)
		END;

	(* Data structure for ServerFamilyInterpreted addresses in host routines *)
	TYPE XServerInterpretedAddress* = RECORD
			typelength*: LONGINT;		(* length of type string, in bytes *)
			valuelength*: LONGINT;	(* length of value string, in bytes *)
			type*: ADDRESS;		(* pointer to where to find the type string *)
			value*: ADDRESS;		(* pointer to where to find the address *)
		END;


	(* Data structure for XReconfigureWindow *)
	TYPE XWindowChanges * = RECORD
			x*, y*: LONGINT;
			width*, height* : LONGINT;
	 	   	borderWidth*: LONGINT;
			sibling* : Window;
	 	   	stackMode*: LONGINT;
		END;


	(* new version containing base_width, base_height, and win_gravity fields;
	  used with WM_NORMAL_HINTS.
	 *)
	TYPE DataAspect*=RECORD 
			x*: LONGINT;	(* numerator *)
			y*: LONGINT;	(* denominator *)
		END;		
		
	TYPE XSizeHints* = RECORD 
			flags*: LONGINT;	(* marks which fields in this structure are defined *) (* HUGEINT ?*)
			x*, y*: LONGINT;		(* obsolete for new window mgrs, but clients *)
			width*, height*: LONGINT;	(* should set so old wm's don't mess up *)
			minWidth*, minHeight*: LONGINT;
			maxWidth*, maxHeight*: LONGINT;
			widthInc*, heightInc*: LONGINT;
			maxAspect*, minAspect*: DataAspect;
			baseWidth*, baseHeight*: LONGINT;		(* added by ICCCM version 1 *)
			winGravity*: LONGINT;			(* added by ICCCM version 1 *)
		END;
	
	(*  The next block of definitions are for window manager properties that
	  clients and applications use for communication. *)
	
	(* flags argument in size hints *)
	CONST 
		USPosition * =  1H; (* user specified x, y *)
		USSize * =   2H; (* user specified width, height *)
		PPosition * =  4H; (* program specified position *)
		PSize * =   8H; (* program specified size *)
		PMinSize * =   10H; (* program specified minimum size *)
		PMaxSize * =   20H; (* program specified maximum size *)
		PResizeInc * =   40H; (* program specified resize increments *)
		PAspect * =   80H; (* program specified min and max aspect ratios *)
		PBaseSize * =   100H; (* program specified base for incrementing *)
		PWinGravity * =  200H; (* program specified window gravity *)

	(* ******************************************** *)
	(* ******************************************** *)
	 (* Definitions of specific events. from  X11lib.h *)	 

	(*! 
		 This union is defined so Xlib can always use the same sized
 		event structure internally, to avoid memory fragmentation.
	
		In C,  XEvent type is union of all event types with size of 192 bytes , 
		In Oberon, other event fields are padded with chars to prevent memory leaks. 
		Use type casting to obtain real event type.	
 *)

	TYPE XEvent* = RECORD   (* size of this event is 192 bytes *)  
			typ* : LONGINT;		(* of event, must bot be changed; first element *)
			serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
			sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
			display* : DisplayPtr;	(* Display the event was read from *)
			window* : Window;	        (* "event" window it is reported relative to *)			
			pad*: ARRAY 172 OF CHAR;  (* 192-SIZEOF(previoustypes),  type cast to corresponding event type*)
	END;

	TYPE XAnyEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;(* Display the event was read from *)
		window* : Window;	(* window on which event was requested in event mask *)
	END;
	
	TYPE XKeyEvent * = RECORD 
		typ* : LONGINT;		(* of event *)
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;	        (* "event" window it is reported relative to *)
		root* : Window;	        (* root window that the event occurred on *)
		subwindow* : Window;	(* child window *)
		time* : Time;		(* milliseconds *)
		x*, y* : LONGINT;		(* pointer x, y coordinates in event window *)
		xRoot*, yRoot* : LONGINT;	(* coordinates relative to root *)
		state* : SET;	(* key or button mask *)
		keycode* : LONGINT(*word*);	(* detail *)
		sameScreen* : BOOLEAN;	(* same screen flag *)
	END;
	TYPE XKeyPressedEvent* = XKeyEvent;
	TYPE XKeyReleasedEvent* = XKeyEvent;
	
	TYPE XButtonEvent * = RECORD 
		typ* : LONGINT;		(* of event *)
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;	        (* "event" window it is reported relative to *)
		root* : Window;	        (* root window that the event occurred on *)
		subwindow* : Window;	(* child window *)
		time* : Time;		(* milliseconds *)
		x*, y* : LONGINT;		(* pointer x, y coordinates in event window *)
		xRoot*, yRoot* : LONGINT;	(* coordinates relative to root *)
		state* : SET;	(* key or button mask *)
		button* : LONGINT(*word*);	(* detail *)
		sameScreen* : BOOLEAN;	(* same screen flag *)
	END;
	TYPE XButtonPressedEvent* = XButtonEvent;
	TYPE XButtonReleasedEvent* = XButtonEvent;
	
	TYPE XMotionEvent * = RECORD 
		typ* : LONGINT;		(* of event *)
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;	        (* "event" window reported relative to *)
		root* : Window;	        (* root window that the event occurred on *)
		subwindow* : Window;	(* child window *)
		time* : Time;		(* milliseconds *)
		x*, y* : LONGINT;		(* pointer x, y coordinates in event window *)
		xRoot*, yRoot* : LONGINT;	(* coordinates relative to root *)
		state* : SET;	(* key or button mask *)
		isHint* : CHAR;		(* detail *)
		sameScreen* : BOOLEAN;	(* same screen flag *)
	END;
	TYPE PointerMovedEvent* = XMotionEvent;
	
	TYPE  XCrossingEvent * = RECORD 
		typ* : LONGINT;		(* of event *)
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;	        (* "event" window reported relative to *)
		root* : Window;	        (* root window that the event occurred on *)
		subwindow* : Window;	(* child window *)
		time* : Time;		(* milliseconds *)
		x*, y* : LONGINT;		(* pointer x, y coordinates in event window *)
		xRoot*, yRoot* : LONGINT;	(* coordinates relative to root *)
		mode* : LONGINT;		(* NotifyNormal, NotifyGrab, NotifyUngrab *)
		detail* : LONGINT;
		(*
		* NotifyAncestor, NotifyVirtual, NotifyInferior,
		* NotifyNonlinear,NotifyNonlinearVirtual
		*)
		sameScreen* : BOOLEAN;	(* same screen flag *)
		focus* : BOOLEAN;		(* boolean focus *)
		state* : SET;	(* key or button mask *)
	END;
	TYPE XEnterWindowEvent* = XCrossingEvent;
	TYPE XLeaveWindowEvent* = XCrossingEvent;
	
	TYPE XFocusChangeEvent * = RECORD 
		typ* : LONGINT;		(* FocusIn or FocusOut *)
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;		(* window of event *)
		mode* : LONGINT;		(* NotifyNormal, NotifyWhileGrabbed, NotifyGrab, NotifyUngrab *)
		detail* : LONGINT;
		(*
		* NotifyAncestor, NotifyVirtual, NotifyInferior,
		* NotifyNonlinear,NotifyNonlinearVirtual, NotifyPointer,
		* NotifyPointerRoot, NotifyDetailNone
		*)
	END;
	TYPE XFocusInEvent* = XFocusChangeEvent;
	TYPE XFocusOutEvent* = XFocusChangeEvent;
	
	(* generated on EnterWindow and FocusIn  when KeyMapState selected *)
	TYPE XKeymapEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;
		keyVector* : ARRAY 32 OF CHAR;
	END;
	
	TYPE XExposeEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;
		x*, y* : LONGINT;
		width*, height* : LONGINT;
		count* : LONGINT;		(* if non-zero, at least this many more *)
	END;
	
	TYPE XGraphicsExposeEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		drawable* : Drawable;
		x*, y* : LONGINT;
		width*, height* : LONGINT;
		count* : LONGINT;		(* if non-zero, at least this many more *)
		majorCode* : LONGINT;		(* core is CopyArea or CopyPlane *)
		minorCode* : LONGINT;		(* not defined in the core *)
	END;
	
	TYPE XNoExposeEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		drawable* : Drawable;
		majorCode* : LONGINT;		(* core is CopyArea or CopyPlane *)
		minorCode* : LONGINT;		(* not defined in the core *)
	END;
	
	TYPE XVisibilityEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;
		state* : LONGINT;		(* Visibility state *)
	END;
	
	TYPE XCreateWindowEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		parent* : Window;		(* parent of the window *)
		window* : Window;		(* window id of window created *)
		x*, y* : LONGINT;		(* window location *)
		width*, height* : LONGINT;	(* size of window *)
		borderWidth* : LONGINT;	(* border width *)
		overrideRedirect* : BOOLEAN;	(* creation should be overridden *)
	END;
	
	TYPE XDestroyWindowEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		event* : Window;
		window* : Window;
	END;
	
	TYPE XUnmapEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		event* : Window;
		window* : Window;
		fromConfigure* : BOOLEAN;
	END;
	
	TYPE XMapEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		event* : Window;
		window* : Window;
		overrideRedirect* : BOOLEAN;	(* boolean, is override set... *)
	END;
	
	TYPE XMapRequestEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		parent* : Window;
		window* : Window;
	END;
	
	TYPE XReparentEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		event* : Window;
		window* : Window;
		parent* : Window;
		x*, y* : LONGINT;
		overrideRedirect* : BOOLEAN;
	END;
	
	TYPE XConfigureEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		event* : Window;
		window* : Window;
		x*, y* : LONGINT;
		width*, height* : LONGINT;
		borderWidth* : LONGINT;
		above* : Window;
		overrideRedirect* : BOOLEAN;
	END;
	
	TYPE XGravityEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		event* : Window;
		window* : Window;
		x*, y* : LONGINT;
	END;
	
	TYPE XResizeRequestEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;
		width*, height* : LONGINT;
	END;
	
	TYPE XConfigureRequestEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		parent* : Window;
		window* : Window;
		x*, y* : LONGINT;
		width*, height* : LONGINT;
		borderWidth* : LONGINT;
		above* : Window;
		detail* : LONGINT;		(* Above, Below, TopIf, BottomIf, Opposite *)
		valueMask* : LONGINT(*unsigned*);
	END;
	
	TYPE XCirculateEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		event* : Window;
		window* : Window;
		place* : LONGINT;		(* PlaceOnTop, PlaceOnBottom *)
	END;
	
	TYPE XCirculateRequestEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		parent* : Window;
		window* : Window;
		place* : LONGINT;		(* PlaceOnTop, PlaceOnBottom *)
	END;
	
	TYPE XPropertyEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;
		atom* : Atom;
		time* : Time;
		state* : LONGINT;		(* NewValue, Deleted *)
	END;
	
	TYPE XSelectionClearEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;
		selection* : Atom;
		time* : Time;
	END;
	
	TYPE XSelectionRequestEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		owner* : Window;
		requestor* : Window;
		selection* : Atom;
		target* : Atom;
		property* : Atom;
		time* : Time;
	END;
	
	TYPE XSelectionEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		requestor* : Window;
		selection* : Atom;
		target* : Atom;
		property* : Atom;		(* ATOM or None *)
		time* : Time;
	END;
	
	TYPE Data40 * = ARRAY 40 OF CHAR; (* max of these is 40 bytes*)
		 Data40b* = ARRAY 20 OF CHAR; (* 20x 8 bits *)
		 Data40s* = ARRAY 10 OF INTEGER; (* 10x 16 bits *)
		 Data40l* = ARRAY 5 OF LONGINT; (* 5x 32 bits *)
	TYPE XClientMessageEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;
		messageType* : Atom;
		format* : LONGINT;
		data*: Data40;
			(* any of these, union 
			b* : ARRAY 20 OF CHAR;
			s* : ARRAY 10 OF INTEGER;
			l* : ARRAY 5 OF LONGINT;
			*)
	END; 
	
	TYPE XMappingEvent * = RECORD 
		typ* : LONGINT;
		serial* : LONGINT(*unsigned*);	(* # of last request processed by server *)
		sendEvent* : BOOLEAN;	(* true if this came from a SendEvent request *)
		display* : DisplayPtr;	(* Display the event was read from *)
		window* : Window;		(* unused *)
		request* : LONGINT;		(* one of MappingModifier, MappingKeyboard, MappingPointer *)
		firstKeycode* : LONGINT;	(* first keycode *)
		count* : LONGINT;		(* defines range of change w. firstKeycode*)
	END;
	
	TYPE XErrorEvent * = RECORD 
		typ* : LONGINT;
		display* : DisplayPtr;	(* Display the event was read from *)
		resourceid* : XID;		(* resource id *)
		serial* : LONGINT(*unsigned*);	(* serial number of failed request *)
		errorCode* : CHAR(*unsigned*);	(* error code of failed request *)
		requestCode* : CHAR(*unsigned*);	(* Major op-code of failed request *)
		minorCode* : CHAR(*unsigned*);	(* Minor op-code of failed request *)
	END;
	
	
	(* ************************************************************** *)	 
	(*  GenericEvent.  This event is the standard event for all newer extensions. *)
	
	TYPE XGenericEvent * = RECORD 
		typ* : LONGINT;         (* of event. Always GenericEvent *)
		serial* : LONGINT(*unsigned*);       (* # of last request processed *)
		sendEvent* : BOOLEAN;   (* true if from SendEvent request *)
		display* : DisplayPtr;     (* Display the event was read from *)
		extension* : LONGINT;    (* major opcode of extension that caused the event *)
		evtype* : LONGINT;       (* actual event type. *)
	END;
	
	TYPE XGenericEventCookie * = RECORD 
		typ* : LONGINT;         (* of event. Always GenericEvent *)
		serial* : LONGINT(*unsigned*);       (* # of last request processed *)
		sendEvent* : BOOLEAN;   (* true if from SendEvent request *)
		display* : DisplayPtr;     (* Display the event was read from *)
		extension* : LONGINT;    (* major opcode of extension that caused the event *)
		evtype* : LONGINT;       (* actual event type. *)
		cookie* : LONGINT(*word*);
		data* : ADDRESS;
	END;


CONST 
(* Action for EWMH client messages *)
	NET_WM_STATE_REMOVE* = 0;
	NET_WM_STATE_ADD* =1;
	NET_WM_STATE_TOGGLE* = 2;
	
	(*! ----------FONTS, from Xutil.h ------------------ *)

TYPE

	(* Extensions need a way to hang private data on some structures.
	called to free private storage 
		free_private_proc* = PROCEDURE (extension: ExtData): LONGINT;*)
	
	ExtData* = POINTER TO ExtDataDesc;
	ExtDataDesc* = RECORD
		number*: LONGINT;		(* number returned by XRegisterExtension *)
		next*: ExtData;	(* next item on list of data for structure *)
		free_private*: ADDRESS;	(* called to free private storage *)
		extension* : ExtData;
		private_data*: ADDRESS;	(* data private to this extension. *)
	END;

	(* per character font metric information. *)
	CharStruct* = RECORD
		lbearing*: INTEGER;	(* origin to left edge of raster *)
		rbearing*: INTEGER;	(* origin to right edge of raster *)
		width*: INTEGER;		(* advance to next char's origin *)
		ascent*: INTEGER;		(* baseline to top edge of raster *)
		descent*: INTEGER;	(* baseline to bottom edge of raster *)
		attributes*: INTEGER;	(* per char flags (not predefined) *)
	END;

	(* To allow arbitrary information with fonts, there are additional properties returned. *)
	FontProp* = RECORD
		name*: Atom;
		card32*: LONGINT;
	END;

	FontStruct* = POINTER TO FontStructDesc;
	FontStructDesc* = RECORD
		ext_data*: ExtData;	(* hook for extension to hang data *)
		fid*: X11.Font;            (* Font id for this font *)
		direction*: LONGINT;	(* hint about direction the font is painted *)
		min_char_or_byte2*: LONGINT;(* first character *)
		max_char_or_byte2*: LONGINT;(* last character *)
		min_byte1*: LONGINT;	(* first row that exists *)
		max_byte1*: LONGINT;	(* last row that exists *)
		all_chars_exist*: X11.Bool;(* flag if all characters have non-zero size*)
		default_char*: LONGINT;	(* char to print for undefined character *)
		n_properties*: LONGINT;   (* how many properties there are *)
		properties*: ADDRESS; (*POINTER TO ARRAY OF FontProp; *)	(* pointer to array of additional properties*)
		min_bounds*: CharStruct;	(* minimum bounds over all existing char*)
		max_bounds*: CharStruct;	(* maximum bounds over all existing char*)
		per_char*: ADDRESS; (*POINTER TO ARRAY OF CharStruct;*)	(* first_char to last_char information *)
		ascent*: LONGINT;		(* log. extent above baseline for spacing *)
		descent*: LONGINT;	(* log. descent below baseline for spacing *)
	END;


	(* new structure for manipulating TEXT properties; used with WM_NAME,
		WM_ICON_NAME, WM_CLIENT_MACHINE, and WM_COMMAND. *)
	XTextProperty* = RECORD
		value*: ADDRESS;		(* same as Property routines *)
		encoding*: Atom;		(* prop type *)
		format*: LONGINT;	(* prop data format: 8, 16, or 32 *)
		nitems*: LONGINT;	(* number of data items in value *)
	END;

(*! ------------------- ends  Xutil.h ----------- *)	

VAR
	xlib: ADDRESS;
	
	OpenDisplay- : PROCEDURE {C} (CONST name: ARRAY OF CHAR): DisplayPtr;
	CloseDisplay- : PROCEDURE {C} (display:DisplayPtr): LONGINT;
	CreateWindow- : PROCEDURE {C} (display: DisplayPtr; parent: Window; x, y: LONGINT; width, height, borderWidth, depth, class: LONGINT; visual: VisualPtr; valuemask: LONGINT;  VAR attributes: XSetWindowAttributes ): Window;
	DestroyWindow-: PROCEDURE {C}(display:DisplayPtr; win: Window): LONGINT;
	DisplayWidthMM-: PROCEDURE {C} (d: DisplayPtr; screen: LONGINT ): LONGINT;
	FreeColormap- : PROCEDURE {C} (display: DisplayPtr; colormap: Colormap);
	FreeCursor- : PROCEDURE {C} (display: DisplayPtr;  cursor: Cursor);
	XGetAtomName- : PROCEDURE {C} (display: DisplayPtr; atom: Atom): LONGINT;
	GetWindowAttributes- : PROCEDURE {C} (display: DisplayPtr; win: Window; VAR attr: XWindowAttributes): LONGINT;
	
	GetWindowProperty-: PROCEDURE {C} (d: DisplayPtr; w: Window; property: Atom;
											offset, length: LONGINT;  delete: Bool;  reqtype: Atom;  VAR typ: Atom;
											VAR format, nitems, bytesafter, prop: LONGINT ): LONGINT;

	GrabKeyboard-: PROCEDURE {C} (display: DisplayPtr; grabwindow: Window; ownerevents: Bool; pointermode, keyboardmode: LONGINT; time: Time): LONGINT;
	GrabPointer-: PROCEDURE {C} (display:DisplayPtr; grabwindow: Window; ownerevents: Bool; eventmask: LONGINT; pointermode, keyboardmode: LONGINT; confineto: Window; cursor: Cursor; time: Time): LONGINT;
	InternAtom-: PROCEDURE {C} (display: DisplayPtr; CONST name: ARRAY OF CHAR;  onlyifexists: Bool ): Atom;
	LookupKeysym- : PROCEDURE {C} (CONST event: XKeyEvent; index: LONGINT): KeySym;
	LookupString-:	PROCEDURE {C} (VAR event: XKeyEvent; VAR buf: ARRAY OF CHAR;  bufsize: LONGINT; VAR keysym: KeySym; VAR cstat: ComposeStatus ): LONGINT;
	MapWindow- : PROCEDURE {C} (display: DisplayPtr; win: Window);
	NextEvent-: PROCEDURE {C} (d: DisplayPtr; VAR event: XEvent );
	Pending- : PROCEDURE {C} (display: DisplayPtr): LONGINT;
	RaiseWindow-: PROCEDURE {C}(display: DisplayPtr; win: Window);
	RootWindow-: PROCEDURE {C}(display: DisplayPtr; screen: LONGINT): Window;	
	SendEvent-: PROCEDURE {C} (d: DisplayPtr; w: Window; propagate: Bool; eventmask: LONGINT; event: ADDRESS ): Bool;
	
	SetNormalHints-: PROCEDURE {C} (d: DisplayPtr; w: Window; VAR hints: XSizeHints);
	GetNormalHints-: PROCEDURE {C} (d: DisplayPtr; w: Window; VAR hints: XSizeHints): Status;
	
	SetStandardProperties-: PROCEDURE {C} (display: DisplayPtr; w: Window; CONST winName: ARRAY OF CHAR; 
							CONST iconName: ARRAY OF CHAR; iconpixmap: Pixmap;  argv: ADDRESS; argc: LONGINT; VAR hints: XSizeHints);
	SetWMProtocols-: PROCEDURE {C} (display: DisplayPtr; win: Window; protoclos: ADDRESS (* ARRAY OF Atoms *); count: LONGINT): LONGINT;
	StoreName- : PROCEDURE {C} (display: DisplayPtr; win: Window; CONST s: ARRAY OF CHAR): LONGINT;
	UnmapWindow- : PROCEDURE {C} (display: DisplayPtr; win: Window);	

	WarpPointer- : PROCEDURE {C} (display: DisplayPtr; srcwin, destwin: Window; srcx, srcy: LONGINT; srcwidth, srcheight: LONGINT; destx, desty: LONGINT);

	(* cut and paste delegates *)
	SendSelection*:	 PROCEDURE {DELEGATE} (VAR event: XSelectionRequestEvent );
	ReceiveSelection*:  PROCEDURE {DELEGATE} (VAR event: XSelectionEvent );
	ClearSelection*: PROCEDURE {DELEGATE} ;

	CheckTypedEvent-: PROCEDURE {C} (display: DisplayPtr; eventType: LONGINT; VAR event: XEvent): Bool;
	CheckMaskEvent-: PROCEDURE {C} (display: DisplayPtr; eventMask: LONGINT; VAR event: XEvent): Bool;

	CheckTypedWindowEvent-: PROCEDURE {C} (display: DisplayPtr; window: Window; eventType: LONGINT; VAR event: XEvent): Bool;
	CheckWindowEvent-: PROCEDURE {C} (display: DisplayPtr; window: Window; eventMask: LONGINT; VAR event: XEvent): Bool;
	
	(* Font *)
	LoadQueryFont-: PROCEDURE {C} (display: DisplayPtr; name: ADDRESS): FontStruct;
	QueryFont- : PROCEDURE {C} (display: DisplayPtr; name: ADDRESS): FontStruct;

	KeycodeToKeysym-: PROCEDURE {C} (disp: DisplayPtr; keycode: LONGINT; index: LONGINT): KeySym;
	KeysymToKeycode-: PROCEDURE {C} (disp: DisplayPtr; keysym: KeySym): LONGINT;

	XKeysymToString-  : PROCEDURE {C} (keysym: KeySym): ADDRESS;
	
	(* helper procedure *)
	PROCEDURE GetStringFromAddress*(adr: ADDRESS): PChar;
	VAR
		adr1: ADDRESS;
		name: PChar;
		i, cnt: LONGINT;
		ch: CHAR;
	BEGIN
		cnt := 0;
		adr1 := adr;
		(* count # of characters *)
		SYSTEM.GET(adr1, ch); 
		WHILE ch # 0X DO
			INC(cnt); INC(adr1);
			SYSTEM.GET(adr1, ch);
		END;
		IF cnt > 0 THEN
			(* copy characters to name *)
			adr1 := adr;
			NEW(name, cnt+1);
			FOR i :=0 TO cnt-1 DO
				SYSTEM.GET(adr1, ch); name[i] := ch; INC(adr1);
			END;
		END;
		RETURN name;		
	END GetStringFromAddress;
	
	(* wrapper procedure for XKeysymToString *)
	PROCEDURE KeysymToString*(keysym: KeySym): PChar;
	VAR adr: ADDRESS;
		name: PChar;
	BEGIN
		adr := XKeysymToString(keysym);
		name := GetStringFromAddress(adr);
		RETURN name;
	END KeysymToString;
		
	(* wrapper procedure for XGetAtomName  *)
	PROCEDURE GetAtomName*(display: DisplayPtr; atom: Atom): PChar;
	VAR adr: ADDRESS;
		name: PChar;
	BEGIN
		adr := XGetAtomName(display, atom);
		name := GetStringFromAddress(adr);
		X11.Free(adr); (* free resulting string *)
		RETURN name;
	END GetAtomName;

	
PROCEDURE LoadX11Functions;
BEGIN

		xlib := Unix.Dlopen( Unix.libX11name, 2 );
		Unix.Dlsym( xlib, "XOpenDisplay", ADDRESSOF( OpenDisplay));
		Unix.Dlsym( xlib, "XCloseDisplay", ADDRESSOF( CloseDisplay));
		Unix.Dlsym( xlib, "XCreateWindow", ADDRESSOF( CreateWindow));
		Unix.Dlsym( xlib, "XDestroyWindow", ADDRESSOF( DestroyWindow));
		Unix.Dlsym( xlib, "XDisplayWidthMM", ADDRESSOF( DisplayWidthMM));
		Unix.Dlsym( xlib, "XFreeColormap", ADDRESSOF( FreeColormap));
		Unix.Dlsym( xlib, "XFreeCursor", ADDRESSOF( FreeCursor));
		Unix.Dlsym( xlib, "XGetAtomName", ADDRESSOF( XGetAtomName));
		Unix.Dlsym( xlib, "XGetNormalHints", ADDRESSOF( GetNormalHints));		
		Unix.Dlsym( xlib, "XGetWindowAttributes", ADDRESSOF( GetWindowAttributes));
		Unix.Dlsym( xlib, "XGetWindowProperty", ADDRESSOF( GetWindowProperty));
		Unix.Dlsym( xlib, "XGrabKeyboard", ADDRESSOF( GrabKeyboard));
		Unix.Dlsym( xlib, "XGrabPointer", ADDRESSOF( GrabPointer));
		Unix.Dlsym( xlib, "XInternAtom", ADDRESSOF( InternAtom));
		Unix.Dlsym( xlib, "XLookupKeysym", ADDRESSOF( LookupKeysym));
		Unix.Dlsym( xlib, "XLookupString", ADDRESSOF( LookupString));
		Unix.Dlsym( xlib, "XMapWindow", ADDRESSOF( MapWindow));
		Unix.Dlsym( xlib, "XNextEvent", ADDRESSOF( NextEvent));
		Unix.Dlsym( xlib, "XUnmapWindow", ADDRESSOF( UnmapWindow));
		Unix.Dlsym( xlib, "XPending", ADDRESSOF( Pending));
		Unix.Dlsym( xlib, "XRaiseWindow", ADDRESSOF( RaiseWindow));
		Unix.Dlsym( xlib, "XRootWindow", ADDRESSOF( RootWindow));
		Unix.Dlsym( xlib, "XSendEvent", ADDRESSOF( SendEvent));
		Unix.Dlsym( xlib, "XSetNormalHints", ADDRESSOF( SetNormalHints));
		Unix.Dlsym( xlib, "XSetStandardProperties", ADDRESSOF( SetStandardProperties));
		Unix.Dlsym( xlib, "XSetWMProtocols", ADDRESSOF( SetWMProtocols));
		Unix.Dlsym( xlib, "XStoreName", ADDRESSOF( StoreName));
		Unix.Dlsym( xlib, "XWarpPointer", ADDRESSOF( WarpPointer));		
		Unix.Dlsym( xlib, "XCheckTypedEvent", ADDRESSOF( CheckTypedEvent));
		Unix.Dlsym( xlib, "XCheckMaskEvent", ADDRESSOF( CheckMaskEvent));
		Unix.Dlsym( xlib, "XCheckTypedWindowEvent", ADDRESSOF( CheckTypedWindowEvent));
		Unix.Dlsym( xlib, "XCheckWindowEvent", ADDRESSOF( CheckWindowEvent));		
		Unix.Dlsym(xlib, 'XLoadQueryFont', ADDRESSOF( LoadQueryFont));
		Unix.Dlsym(xlib, 'XQueryFont', ADDRESSOF( QueryFont));
		Unix.Dlsym(xlib, "XKeycodeToKeysym", ADDRESSOF(KeycodeToKeysym));
		Unix.Dlsym(xlib, "XKeysymToKeycode", ADDRESSOF(KeysymToKeycode));
		Unix.Dlsym(xlib, "XKeysymToString", ADDRESSOF(XKeysymToString));
END LoadX11Functions;

PROCEDURE OnClose;
BEGIN
	IF xlib # 0 THEN
     	Unix.Dlclose(xlib);
	END;
END OnClose;

	
BEGIN
	LoadX11Functions;
	Modules.InstallTermHandler(OnClose) ;
END X11Api.
