MODULE VideoExample; (** AUTHOR "thomas.frey@alumni.ethz.ch"; PURPOSE "Webcam support for WinA2"; *)
(*PH 100317: proposal for more video formats from webcams and built-in cameras delivering YUV422 data *)

IMPORT
	Modules, Kernel, KernelLog, SYSTEM, Unix, Objects, WMDialogs,
	WMWindowManager, Strings, WMRectangles, WMGraphics, Raster,
	Codecs, Commands, Files, Streams,
	lib := libv4l2, V := V4L2, BIT;
	
CONST
		 devname = "/dev/video0";

TYPE
	FrameHandler* = PROCEDURE {DELEGATE} (buffer : Raster.Image);
	PreviewWindow* = OBJECT (WMWindowManager.BufferWindow);
		PROCEDURE &New*(width, height : LONGINT);
		BEGIN
			Init(width, height, FALSE);
			WMWindowManager.AddWindow(SELF, 200, 200);
			SetTitle(Strings.NewString("Preview Window: "));
			
			canvas.Fill(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()), WMGraphics.White, WMGraphics.ModeCopy);
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
		END New;
		(* Overwrite draw procedure because we do not want any interpolation *)
		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		BEGIN
			Draw^(canvas, w, h, 0);
		END Draw;

		PROCEDURE KeyEvent (ucs: LONGINT; flags: SET; keysym: LONGINT);
		BEGIN
			CASE CHR(ucs) OF
				| "s": SaveImage;
				| "q": Close;
			ELSE
			END;
		END KeyEvent;
			
		PROCEDURE SaveImage;
		VAR res: LONGINT;
			fname: ARRAY 128 OF CHAR;
		BEGIN
			fname:="captured1.bmp";
			IF WMDialogs.QueryString(" Save File name: ",fname)=WMDialogs.ResOk THEN
				WMGraphics.StoreImage(img, fname,res);
			END;
		END SaveImage;
					
	END PreviewWindow;

	Starter* = OBJECT
	VAR opened, stopped : BOOLEAN;

		PROCEDURE &Open;
		BEGIN {EXCLUSIVE}
			stopped := FALSE;
			IF s # NIL THEN s.Close END; 
			NEW(s, camWidth, camHeight);
			opened := TRUE;
		END Open;

		PROCEDURE Stop;
		BEGIN {EXCLUSIVE}
			stopped := TRUE;
			opened := FALSE;
			KernelLog.String("Stoped"); KernelLog.Ln; 
		END Stop;


	BEGIN {ACTIVE}
		stopped := FALSE;

		WHILE opened DO
			IF ~ stopped THEN 
				FrameReceived();
				Objects.Sleep( 1);
			END;	
		END;	
		
		(*CloseDevice();*)

	END Starter;

VAR
	s : PreviewWindow;
	
	fd: LONGINT; (* device file handle *)
	buffer : Raster.Image;  (* captured image buffer *)
	starter : Starter;
	camWidth, camHeight: LONGINT;
	
	frameHandler : FrameHandler;

(* Sends a single image through the video processing pipeline. *)
PROCEDURE SimulateImage*(context : Commands.Context); (** filename ~ *)
VAR
	fn, name : Files.FileName;
	res, w, h, x : LONGINT;
	dec : Codecs.ImageDecoder;
	rdr : Streams.Reader;
	ext : ARRAY 16 OF CHAR;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(fn);
	Strings.Trim(fn, '"');
	Strings.GetExtension(fn, name, ext);
	Strings.UpperCase(ext);
	dec := Codecs.GetImageDecoder(ext);
	IF dec = NIL THEN
		context.error.String("No decoder found for "); context.error.String(ext); context.error.Ln;
		RETURN
	END;
	rdr := Codecs.OpenInputStream(fn);
	IF rdr # NIL THEN
		dec.Open(rdr, res);
		IF res = 0 THEN
			dec.GetImageInfo(w, h, x, x);
			IF (buffer = NIL) THEN NEW(buffer); Raster.Create(buffer, w, h, Raster.BGR888) END;
			IF s = NIL THEN NEW(s, buffer.width, buffer.height) END;
			dec.Render(buffer);
			IF (frameHandler # NIL) & (buffer # NIL) THEN frameHandler(buffer) END;
			IF buffer # NIL THEN s.canvas.DrawImage(0, 0, buffer, WMGraphics.ModeCopy) END;
			s.Invalidate(WMRectangles.MakeRect(0, 0, s.GetWidth(), s.GetHeight()))
		ELSE
			context.error.String("WMPicView: Could not open decoder for file "); context.error.String(fn); context.error.Ln;
		END;
	ELSE
		context.error.String("WMPicView: Could not open inputstream for file "); context.error.String(fn); context.error.Ln;
	END;
END SimulateImage;


PROCEDURE ReadFrame();
VAR
	fds: Unix.FdSet;
	tv: Unix.Timeval;
	r: LONGINT;
	(* --------for ioctl ------------ *)
	PROCEDURE FDZERO(VAR fs: Unix.FdSet);
	VAR i: LONGINT;
	BEGIN
		FOR i:=0 TO LEN(fs)-1 DO
			fs[i] := {};
		END;
	END FDZERO;

	PROCEDURE FDSET(fd: LONGINT; VAR fs: Unix.FdSet);
	BEGIN
		INCL( fs[fd DIV 32],  fd MOD 32 );
	END FDSET;
	
BEGIN

		
	FDZERO(fds);
	FDSET(fd, fds);
	tv.sec := 2;
	tv.usec := 0;
	r := Unix.select(fd+1, SYSTEM.VAL(Unix.FdSetPtr, ADDRESSOF(fds)), NIL, NIL, tv);
	IF r = -1 THEN 
		RETURN;
	END;

	 IF -1 = lib.v4l2_read(fd, ADDRESSOF(buffer.mem[0]), buffer.width*buffer.height*3) THEN	 	
	 	RETURN;
	END;
				 
END ReadFrame;

PROCEDURE CloseDevice();
VAR err: LONGINT;
BEGIN
	IF fd>0 THEN	
 		err := lib.v4l2_close(fd);
 		KernelLog.String("device closed"); KernelLog.Ln; 
 		fd := 0;
 	ELSE
 		KernelLog.String("device is allready closed"); KernelLog.Ln; 
	END; 		
END CloseDevice;

PROCEDURE OpenDevice(CONST devicename: ARRAY OF CHAR): BOOLEAN;
BEGIN
 	fd := lib.v4l2_open(ADDRESSOF(devicename), Unix.rdwr, {});
 	IF fd = -1 THEN
 		KernelLog.String("Error: Could not open video device : "); KernelLog.String(devname); KernelLog.Ln;
 		RETURN FALSE;
 	END;	
	KernelLog.String("video device opened: "); KernelLog.String(devname); KernelLog.Ln; 	 	
	RETURN (fd > 0);
END OpenDevice;

PROCEDURE InitDevice();
VAR
        cap: V.v4l2_capability;
        cropcap: V.v4l2_cropcap;
        crop: V.v4l2_crop;
	fmt: V.v4l2_format;
        min: LONGINT;	
 	pix: V.v4l2_pix_format;

	err: LONGINT;
	
BEGIN
 	 err := xioctl(fd, V.VIDIOC_QUERYCAP, ADDRESSOF(cap));

	KernelLog.String("------------------------------"); KernelLog.Ln; 
	KernelLog.String("VIDIOC_QUERYCAP:"); KernelLog.Ln; 
	KernelLog.String("cap.driver= "); KernelLog.String(cap.driver); KernelLog.Ln; 
	KernelLog.String("cap.card= "); KernelLog.String(cap.card); KernelLog.Ln; 
	KernelLog.String("cap.businfo= "); KernelLog.String(cap.bus_info); KernelLog.Ln; 

	KernelLog.String("------------------------------"); KernelLog.Ln; 	
	IF BIT.LAND(cap.capabilities, V.V4L2_CAP_VIDEO_CAPTURE) = 0 THEN
		KernelLog.String(devname); KernelLog.String(" is not video capture device"); KernelLog.Ln;
	END;

	IF BIT.LAND(cap.capabilities, V.V4L2_CAP_READWRITE) = 0 THEN
		KernelLog.String(devname); KernelLog.String(" does not support read i/o"); KernelLog.Ln;
	END;

	IF BIT.LAND(cap.capabilities, V.V4L2_CAP_STREAMING) = 0 THEN
		KernelLog.String(devname); KernelLog.String(" does not support streaming i/o"); KernelLog.Ln;
	END;

(* Select video input, video standard and tune here. *)

(*	cropcap.ztype := V.V4L2_BUF_TYPE_VIDEO_CAPTURE; 	(* -------- *)
	IF 0 = xioctl(fd, V.VIDIOC_CROPCAP, ADDRESSOF(cropcap)) THEN
		crop.ztype := V.V4L2_BUF_TYPE_VIDEO_CAPTURE;
		crop.c := cropcap.defrect; (* reset to default *)
		IF (-1 = xioctl(fd, V.VIDIOC_S_CROP, ADDRESSOF(crop))) THEN
			IF Unix.EINVAL=Unix.errno()  THEN
				KernelLog.String("Cropping not supported."); KernelLog.Ln; 
			END;
		END;
	END;
*)
                
 	      fmt.ztype := V.V4L2_BUF_TYPE_VIDEO_CAPTURE;
 	    
 	 	pix.width := camWidth;
 	 	pix.height := camHeight;
 	 	pix.pixelformat := V.V4L2_PIX_FMT_BGR24; (*V.V4L2_PIX_FMT_YUV420;*)
 	 	pix.field := V.V4L2_FIELD_INTERLACED; 
 	(* 	pix.field := V.V4L2_FIELD_NONE;*)
 	 	fmt.fmt := SYSTEM.VAL(V.D200, pix);
 
                IF -1 = xioctl(fd, V.VIDIOC_S_FMT, ADDRESSOF(fmt) ) THEN
                   
                        KernelLog.String("error: VIDIOC_S_FMT."); KernelLog.Ln;
                        ASSERT(TRUE, 101);
                RETURN; 
                END;
    
    (* Note VIDIOC_S_FMT may change width and height. *)
    
       (* Buggy driver paranoia. *)
       pix := SYSTEM.VAL(V.v4l2_pix_format, fmt.fmt); (* convert union struct to pix_format type *)
	IF pix.pixelformat # V.V4L2_PIX_FMT_BGR24 THEN
		KernelLog.String("libv4l didn't accept BGR24 format."); KernelLog.Ln; 
	END;

	     IF (pix.width # camWidth) OR (pix.height # camHeight) THEN
                KernelLog.String("Warning: driver is sending image at ");
                KernelLog.Int(pix.width, 0);  KernelLog.Int(pix.height, 0); KernelLog.Ln; 
            END;
            
        min := pix.width * 2;
        IF (pix.bytesperline < min) THEN
                pix.bytesperline := min;
        END;        
        min := pix.bytesperline * pix.height;
        IF (pix.sizeimage < min) THEN
                pix.sizeimage := min;
	END;
	KernelLog.String("pix.sizeimage= "); KernelLog.Int(pix.sizeimage, 0); KernelLog.Ln; 
	KernelLog.String("pix.width= "); KernelLog.Int(pix.width, 0); KernelLog.Ln; 
	KernelLog.String("pix.height= "); KernelLog.Int(pix.height, 0); KernelLog.Ln; 
	
	camWidth := pix.width;
	camHeight := pix.height;

  	fmt.fmt := SYSTEM.VAL(V.D200, pix);

	NEW(buffer);
	Raster.Create(buffer, camWidth, camHeight, Raster.BGR888);
	
END InitDevice;


PROCEDURE xioctl(fh, request: LONGINT; arg: ADDRESS): LONGINT;
BEGIN
	RETURN  lib.v4l2_ioctl(fh, request, arg);
END xioctl;

PROCEDURE FrameReceived ();
VAR
	trap : BOOLEAN;
	t0, t1: LONGINT;
	ts: ARRAY 8  OF CHAR;
BEGIN
	trap := TRUE;
		t0 := Kernel.GetTicks();
	
		ReadFrame();
	
		IF (frameHandler # NIL) & (buffer # NIL) THEN frameHandler(buffer) END;
		IF s # NIL THEN
				s.canvas.DrawImage(0, 0, buffer, WMGraphics.ModeCopy);
				t1 :=  Kernel.GetTicks();
				t0 := t1 - t0;
				Strings.IntToStr(t0, ts);
				s.canvas.DrawString(100,100, ts);
				s.Invalidate(WMRectangles.MakeRect(0, 0, s.GetWidth(), s.GetHeight()))
		END;		
	trap := FALSE;
FINALLY
	IF trap THEN
		KernelLog.String("Handler failed, removing it."); KernelLog.Ln;
		frameHandler := NIL
	END;
END FrameReceived;


PROCEDURE SnapshotFirstPossible*;
VAR
	timer : Kernel.Timer;

BEGIN
	IF s # NIL THEN s.Close END; 
	NEW(s, camWidth, camHeight);
	KernelLog.String("Started"); KernelLog.Ln;
	NEW(timer);
	timer.Sleep(10000);
	ReadFrame();
END SnapshotFirstPossible;

PROCEDURE Start*;
BEGIN
	IF starter # NIL THEN starter.Stop(); END;
	IF fd > 0 THEN CloseDevice(); END;
	
	IF OpenDevice(devname) THEN
		
		InitDevice();
		NEW(starter);
	END;	
END Start;

PROCEDURE Stop*;
BEGIN
	IF starter # NIL THEN
		starter.Stop;
	END;	
END Stop;

PROCEDURE EnumControls*;
VAR 
	queryctrl: V.v4l2_queryctrl;

	id, res: LONGINT;
	
	PROCEDURE EnumerateMenus;
	VAR k: LONGINT;
		querymenu: V.v4l2_querymenu;
	BEGIN
		KernelLog.String("   Menu items: "); KernelLog.Ln; 
		FOR k := queryctrl.minimum TO queryctrl.maximum DO
			querymenu.index := k;
			IF (0 = xioctl (fd, V.VIDIOC_QUERYMENU, ADDRESSOF(querymenu))) THEN
				KernelLog.String(querymenu.name); KernelLog.Ln; 
			END;
		END;
	END EnumerateMenus;
	
BEGIN
	FOR id := V.V4L2_CID_BASE TO V.V4L2_CID_LASTP1 -1 DO
			queryctrl.id := id;
			res := xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl));
			IF (0 = res ) THEN
					IF BIT.LAND(queryctrl.flags,  V.V4L2_CTRL_FLAG_DISABLED)=1 THEN
					
					ELSE
						KernelLog.String("queryctrl.name= "); KernelLog.String(queryctrl.name); KernelLog.Ln; 
						IF queryctrl.ztype = V.V4L2_CTRL_TYPE_MENU THEN
							EnumerateMenus();

						END;	
					END;
			ELSE
					
			END;		
	END;
END EnumControls;

(** *)
PROCEDURE SetBrightness*(par: Commands.Context);
VAR
	queryctrl : V.v4l2_queryctrl ;
	control: V.v4l2_control;
	val: LONGINT;
BEGIN
	IF ~ par.arg.GetInteger(val, FALSE) THEN RETURN; END;
	
	queryctrl.id := V.V4L2_CID_BRIGHTNESS;
	IF (-1 = xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl))) THEN
		IF Unix.errno() # Unix.EINVAL THEN
			KernelLog.String("VIDIOC_QUERYCTRL"); KernelLog.Ln; 
			RETURN;
	
		ELSE
			KernelLog.String ("V4L2_CID_BRIGHTNESS is not supported"); KernelLog.Ln; 
		END;	

	ELSIF BIT.LAND(queryctrl.flags , V.V4L2_CTRL_FLAG_DISABLED) = 1 THEN
			KernelLog.String ("V4L2_CID_BRIGHTNESS is not supported"); KernelLog.Ln; 
			
	ELSE

		control.id := V.V4L2_CID_BRIGHTNESS;
		control.value := val; (* queryctrl.default_value;*)

		IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
			KernelLog.String ("VIDIOC_S_CTRL"); KernelLog.Ln; 
		END;
	END;
END SetBrightness;


(** set auto brightness menu control: on, off *)
PROCEDURE AutoBrightness*;
VAR
	querymenu : V.v4l2_querymenu;
	queryctrl : V.v4l2_queryctrl ;
	control: V.v4l2_control;
	val: LONGINT;
BEGIN
	
	queryctrl.id := V.V4L2_CID_AUTOBRIGHTNESS;
	
	IF (0 = xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl))) THEN
		KernelLog.String("found V4L2_CID_AUTOBRIGHTNESS" ); KernelLog.Ln;
		KernelLog.String(queryctrl.name); KernelLog.Ln; 
		
		control.id := V.V4L2_CID_AUTOBRIGHTNESS;
		IF (0 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(control))) THEN
			KernelLog.String("control.val= "); KernelLog.Int(control.value, 0); KernelLog.Ln;
			IF control.value= 0 THEN
				control.value := 1;
			ELSE
				control.value := 0;
			END;
			IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
				KernelLog.String ("Error: Auto Brightness  VIDIOC_S_CTRL"); KernelLog.Ln; 
			END;
		ELSE
			KernelLog.String ("Error: Auto Brightness  VIDIOC_G_CTRL"); KernelLog.Ln; 	
		END;
(*		IF BIT.LAND(queryctrl.flags,  V.V4L2_CTRL_FLAG_DISABLED)= V.V4L2_CTRL_FLAG_DISABLED THEN
			
			KernelLog.String ("V4L2_CID_AUTOBRIGHTNESS V4L2_CTRL_FLAG_DISABLED"); KernelLog.Ln; 
		ELSE
			KernelLog.String ("V4L2_CID_AUTOBRIGHTNESS -NOT- V4L2_CTRL_FLAG_DISABLED"); KernelLog.Ln; 
		END;
		*)
	ELSE
		KernelLog.String ("V4L2_CID_AUTOBRIGHTNESS is not found"); KernelLog.Ln; 
	END;	
END AutoBrightness;

(** *)
PROCEDURE SetContrast*(par: Commands.Context);
VAR
	queryctrl : V.v4l2_queryctrl ;
	control: V.v4l2_control;
	val: LONGINT;
BEGIN
	IF ~ par.arg.GetInteger(val, FALSE) THEN RETURN; END;
	
		queryctrl.id := V.V4L2_CID_CONTRAST;
		IF (-1 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(queryctrl))) THEN
			IF Unix.errno() # Unix.EINVAL THEN
				KernelLog.String("ERROR: SetContrast VIDIOC_QUERYCTRL"); KernelLog.Ln; 
				RETURN;
			ELSE
				KernelLog.String ("V4L2_CID_CONTRAST is not supported"); KernelLog.Ln; 
			END;
			
		ELSE
			control.id := V.V4L2_CID_CONTRAST;
			control.value := val; (* queryctrl.default_value;*)

			IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
				KernelLog.String ("Error: SetContrast VIDIOC_S_CTRL"); KernelLog.Ln; 
			END;
		END;	
END SetContrast;

(** *)
PROCEDURE IncContrast*;
VAR
	queryctrl : V.v4l2_queryctrl;
	control: V.v4l2_control;
	val: LONGINT;
BEGIN
	
	queryctrl.id := V.V4L2_CID_CONTRAST;
	IF (0 = xioctl (fd, V.VIDIOC_QUERYCTRL, ADDRESSOF(queryctrl))) THEN
	
		control.id := V.V4L2_CID_CONTRAST;	
		IF (0 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(control))) THEN
			
			control.value := control.value + queryctrl.step; 
					
				(* The driver may clamp the value or return ERANGE, ignored here *)
			IF (0 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
			
			ELSE
				KernelLog.String ("Error: IncContrast VIDIOC_S_CTRL"); KernelLog.Ln;
			END;
		ELSE
			KernelLog.String ("Error: IncContrast VIDIOC_G_CTRL"); KernelLog.Ln; 		
		END;
	ELSE 
		KernelLog.String ("Error: IncContrast VIDIOC_QUERYCTRL"); KernelLog.Ln; 			
	END;

END IncContrast;

PROCEDURE DecContrast*;
VAR
	control: V.v4l2_control;
	val: LONGINT;
BEGIN

	control.id := V.V4L2_CID_CONTRAST;
	IF (0 = xioctl (fd, V.VIDIOC_G_CTRL, ADDRESSOF(control))) THEN	
		control.value := control.value - 10; (* queryctrl.default_value;*)

		(* The driver may clamp the value or return ERANGE, ignored here *)
		IF (-1 = xioctl (fd, V.VIDIOC_S_CTRL, ADDRESSOF(control))) THEN
			IF  (Unix.errno() # Unix.ERANGE) THEN
				KernelLog.String ("Error: SetContrast VIDIOC_S_CTRL"); KernelLog.Ln; 
			END;
		END;
	ELSIF (Unix.errno() # Unix.EINVAL) THEN
		KernelLog.String ("Error: SetContrast VIDIOC_G_CTRL"); KernelLog.Ln; 
	END;
END DecContrast;

PROCEDURE InstallFrameHandler*(handler : FrameHandler);
BEGIN 
	frameHandler := handler
END InstallFrameHandler;

PROCEDURE Cleanup;
BEGIN
	IF starter # NIL THEN starter.Stop END;
	CloseDevice();
	IF s # NIL THEN s.Close END
END Cleanup;

BEGIN
	 camWidth := 640; (* default *)
	 camHeight := 480;
	Modules.InstallTermHandler(Cleanup)
END VideoExample.


!VideoExample.SimulateImage "test.png ~

VideoExample.Start ~

VideoExample.EnumControls ~

VideoExample.SetBrightness 30 ~ 

VideoExample.AutoBrightness  ~ 

VideoExample.SetContrast 50 ~ 

VideoExample.IncContrast~ 
VideoExample.DecContrast~ 

VideoExample.Stop ~

VideoExample.SnapshotFirstPossible ~ 

SystemTools.Free VideoExample  libv4l2 V4L2 ~
