MODULE VNCServer;	(** AUTHOR "TF"; PURPOSE "New VNC Server"; *)

IMPORT
	SYSTEM, Streams, TCP, IP, WMRectangles,
	KernelLog, DES, Random, Machine, Kernel, Inputs, Raster,
	Strings;

CONST
	Version = "RFB 003.003";
	TraceVersion = 0;
	TraceAuthentication = 1;
	TraceMsg = 2;
	TraceKeyEvent = 3;
	Trace = {  } ;

	(* encodings *)
	EncRaw = 0; EncCopyRect = 1; EncRRE = 2; EncCoRRE= 4; EncHextile =5; EncZRLE = 16;

	(* Authentication constants *)
	AuthNone = 1; AuthVNC = 2; AuthOk = 0; AuthFailed = 1;

	(* hextile flags *)
	HexRaw = 1; HexBGSpecified = 2; HexFGSpecified = 4; HexAnySubrects = 8; HexSubrectsColoured = 16;

	MaxRect = 40;
	MaxWidth = 4096;
	MaxCutSize = 64 * 1024;
	BundleRectangles = TRUE;
	BigPackets = TRUE;
	SendFBUpdatePacketEarly = TRUE; (* the value of this is questionable *)

TYPE
	Rectangle = WMRectangles.Rectangle;
	RectBuf = POINTER TO ARRAY OF Rectangle;
	WorkBuf = POINTER TO ARRAY OF CHAR;
	String = Strings.String;
	VNCMouseListener* = PROCEDURE {DELEGATE} (x, y, dz : LONGINT; keys : SET);
	VNCKeyboardListener* = PROCEDURE {DELEGATE} (ucs : LONGINT; flags : SET; keysym : LONGINT);
	VNCClipboardListener* = PROCEDURE {DELEGATE} (text : String);
	VNCNofClientsActiveListener* = PROCEDURE {DELEGATE} (nofClients : LONGINT);

	PFHextile = ARRAY 16 * 16 OF LONGINT;

	VNCInfo* = OBJECT
	VAR
		name*, password* : ARRAY 64 OF CHAR;
		img* : Raster.Image;
		ml* : VNCMouseListener;
		kl* : VNCKeyboardListener;
		cutl* : VNCClipboardListener;
		ncal* : VNCNofClientsActiveListener;
		width*, height* : LONGINT;
		(** only used in service case *)
		connection* : TCP.Connection;
		agent* : VNCAgent; (** not valid in service init *)
	END VNCInfo;

	(* the service must fill in the VNCInfo structure. img must not be NIL *)
	VNCService* = PROCEDURE {DELEGATE} (vncInfo : VNCInfo);

	Agent = OBJECT
	VAR
		client: TCP.Connection;
		next: Agent; s: Server;
	END Agent;

	PixelFormat = RECORD
		sr, sg, sb : LONGINT;
		bpp, depth, rmax, gmax, bmax, rshift, gshift, bshift : LONGINT;
		bigendian, truecolor, native16 : BOOLEAN;
	END;

	UpdateQ = OBJECT
	VAR buffer : RectBuf;
		nofRect : LONGINT;
		clip : Rectangle;
		agent : VNCAgent;
		alive, allowed : BOOLEAN;

		PROCEDURE &Init*(agent : VNCAgent; w, h : LONGINT);
		BEGIN
			SELF.agent := agent; alive := TRUE;
			NEW(buffer, MaxRect);
			nofRect := 0; clip := WMRectangles.MakeRect(0, 0, w, h)
		END Init;

		PROCEDURE Add(VAR r : Rectangle);
		VAR i, a : LONGINT; e : Rectangle; done : BOOLEAN;
		BEGIN {EXCLUSIVE}
			WMRectangles.ClipRect(r, clip);
			IF WMRectangles.RectEmpty(r) THEN RETURN END;
			IF nofRect = 0 THEN buffer[0] := r; nofRect := 1
			ELSE
				a := WMRectangles.Area(r);
				i := 0; done := FALSE;
				WHILE ~done & (i < nofRect) DO
					e := r; WMRectangles.ExtendRect(e, buffer[i]);
					IF WMRectangles.Area(e) <= WMRectangles.Area(buffer[i]) + a THEN buffer[i] := e; done := TRUE END;
					INC(i)
				END;
				IF ~done THEN
					IF nofRect < MaxRect THEN buffer[nofRect] := r; INC(nofRect)
					ELSE WMRectangles.ExtendRect(buffer[0], r);
					END
				END
			END
		END Add;

		PROCEDURE GetBuffer(VAR nof : LONGINT; drawBuf : RectBuf);
		VAR r, e : Rectangle; i, j, a : LONGINT; done : BOOLEAN;
		BEGIN {EXCLUSIVE}
			drawBuf[0] := buffer[0]; nof := 1;
			FOR j := 1 TO nofRect - 1 DO
				r := buffer[j]; a := WMRectangles.Area(r);
				i := 0; done := FALSE;
				WHILE ~done & (i < nof) DO
					e := r; WMRectangles.ExtendRect(e, drawBuf[i]);
					IF WMRectangles.Area(e) <= WMRectangles.Area(drawBuf[i]) + a THEN drawBuf[i] := e; done := TRUE END;
					INC(i)
				END;
				IF ~done THEN
					ASSERT(nof < MaxRect);
					drawBuf[nof] := r; INC(nof)
				END
			END;
			nofRect := 0
		END GetBuffer;

		PROCEDURE Close;
		BEGIN {EXCLUSIVE}
			alive := FALSE
		END Close;

		PROCEDURE SetAllowed;
		BEGIN {EXCLUSIVE}
			allowed := TRUE
		END SetAllowed;

	BEGIN {ACTIVE}
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT(~alive OR allowed & (nofRect > 0));
				allowed := FALSE
			END;
			IF ~alive THEN EXIT END;
			agent.DoUpdates
		END
	END UpdateQ;

	VNCAgent* = OBJECT(Agent)
	VAR vncInfo : VNCInfo;
		in : Streams.Reader; out : Streams.Writer;
		pf : PixelFormat;
		traceStr : ARRAY 64 OF CHAR;
		encodings : SET; (* sencodings the client supports *)
		keyState : SET; (* set of currently pressed grey keys *)
		updateQ : UpdateQ;
		drawRectBuffer : RectBuf; (* declared as field to avoid stack clearing *)
		workBuffer : WorkBuf;
		allowUpdate : BOOLEAN;
		mode : Raster.Mode; (* chached mode to avoid bind *)
		pfHextile : PFHextile;

		PROCEDURE &Init*(server : Server; client : TCP.Connection; vncInfo : VNCInfo);
		BEGIN
			s := server; SELF.client := client; SELF.vncInfo := vncInfo;
			client.DelaySend(FALSE);
			NEW(in, client.Receive, 1024);
			NEW(out, client.Send,  4096);
			(* defaults *)
			pf.bigendian := FALSE; pf.truecolor := TRUE;
			pf.rmax := 31; pf.gmax := 63; pf.bmax := 31;
			pf.rshift := 11; pf.gshift := 5; pf.bshift := 0;
			pf.bpp := 16; pf.depth := 16;
			InitPixelFormat(pf);
			allowUpdate := FALSE;
			Raster.InitMode(mode, Raster.srcCopy);
			NEW(drawRectBuffer, MaxRect);
			NEW(workBuffer, MaxWidth * 4);
			NEW(updateQ, SELF, vncInfo.width, vncInfo.height)
		END Init;

		PROCEDURE SendVersion() : BOOLEAN;
		VAR clientVersion : ARRAY 12 OF CHAR; len : LONGINT;
		BEGIN
			out.String(Version); out.Char(0AX); out.Update();
			IF out.res # Streams.Ok THEN RETURN FALSE END;
			in.Bytes(clientVersion, 0, 12, len); clientVersion[11] := 0X;
			IF TraceVersion IN Trace THEN KernelLog.String("Client Version : "); KernelLog.String(clientVersion); KernelLog.Ln END;
			RETURN (clientVersion = Version)
		END SendVersion;

		PROCEDURE Authenticate() : BOOLEAN;
		VAR challenge, response, clear : ARRAY 16 OF CHAR;
			des : DES.DES; seq : Random.Sequence;
			i, len : LONGINT; ok : BOOLEAN;
		BEGIN
			Machine.AtomicInc(NnofAuthenticate);
			IF vncInfo.password = "" THEN
				Machine.AtomicInc(NnofAuthNone);
				out.Net32(AuthNone); out.Update; RETURN out.res = Streams.Ok
			ELSE
				Machine.AtomicInc(NnofAuthVNC);
				out.Net32(AuthVNC);
				(* initialize random number generator for challenge *)
				NEW(seq); seq.InitSeed(Kernel.GetTicks());

				(* generate and send challenge *)
				FOR i:=0 TO 15 DO challenge[i] := CHR(seq.Dice(256)); out.Char(challenge[i]) END; out.Update();
				IF out.res # Streams.Ok THEN RETURN FALSE END;

				NEW(des); des.SetKey(vncInfo.password);
				in.Bytes(response, 0, 16, len);
				des.Decrypt(response, 0, clear, 0); des.Decrypt(response, 8, clear, 8);
				(* check decrypted response against challenge *)
				ok := TRUE; FOR i := 0 TO 15 DO IF clear[i] # challenge[i] THEN ok := FALSE END END;
				(* inform client *)
				IF ~ok THEN
					IF TraceAuthentication IN Trace THEN KernelLog.String("Authentication error."); KernelLog.Ln END;
					Machine.AtomicInc(NnofAuthFailed);
					out.Net32(AuthFailed)
				ELSE
					IF TraceAuthentication IN Trace THEN KernelLog.String("Authenticated."); KernelLog.Ln END;
					Machine.AtomicInc(NnofAuthOk);
					out.Net32(AuthOk)
				END;
				out.Update;
				RETURN ok & (out.res = Streams.Ok)
			END
		END Authenticate;

		PROCEDURE CloseAllOtherClients;
		BEGIN
			s.CloseAllOthers(SELF)
		END CloseAllOtherClients;

		PROCEDURE Setup() : BOOLEAN;
		VAR len : LONGINT;
		BEGIN
			(* read the client initialization 5.1.3 *)
			IF in.Get() # 01X THEN CloseAllOtherClients END; (* Service *)

			(* send server initialization 5.1.4 *)
			out.Net16(vncInfo.width); out.Net16(vncInfo.height);

			(* pixelformat *)
			out.Char(CHR(pf.bpp)); out.Char(CHR(pf.depth));
			IF pf.bigendian THEN out.Char(1X) ELSE out.Char(0X) END;
			IF pf.truecolor THEN out.Char(1X) ELSE out.Char(0X) END;
			out.Net16(pf.rmax); out.Net16(pf.gmax); out.Net16(pf.bmax);
			out.Char(CHR(pf.rshift)); out.Char(CHR(pf.gshift)); out.Char(CHR(pf.bshift));
			out.Char(0X); out.Char(0X); out.Char(0X); (* padding *)

			(* name *)
			len := 0; WHILE vncInfo.name[len] # 0X DO INC(len) END;
			out.Net32(len); out.String(vncInfo.name);
			out.Update;

			RETURN out.res = Streams.Ok
		END Setup;

		PROCEDURE SetPixelFormat; (* 5.2.1 *)
		BEGIN
			(* skip padding *)
			in.SkipBytes(3);
			(* Pixel format *)
			pf.bpp := ORD(in.Get());
			pf.depth := ORD(in.Get());
			pf.bigendian := in.Get() = 1X;
			pf.truecolor := in.Get() = 1X;
			pf.rmax := in.Net16();
			pf.gmax := in.Net16();
			pf.bmax := in.Net16();
			pf.rshift := ORD(in.Get());
			pf.gshift := ORD(in.Get());
			pf.bshift := ORD(in.Get());
			(* skip padding *)
			in.SkipBytes(3);
			InitPixelFormat(pf)
		END SetPixelFormat;

		PROCEDURE InitPixelFormat(VAR pf : PixelFormat);
		VAR t : LONGINT;
		BEGIN
			t := pf.rmax; pf.sr := 0; WHILE t > 0 DO t := t DIV 2; INC(pf.sr) END; pf.sr := 8 - pf.sr;
			t := pf.gmax; pf.sg := 0; WHILE t > 0 DO t := t DIV 2; INC(pf.sg) END; pf.sg := 8 - pf.sg;
			t := pf.bmax; pf.sb := 0; WHILE t > 0 DO t := t DIV 2; INC(pf.sb) END; pf.sb := 8 - pf.sb;
			pf.native16 := (pf.rmax = 31) & (pf.gmax = 63) & (pf.bmax = 31) & (pf.rshift = 11) & (pf.gshift = 5) & (pf.bshift = 0)
		END InitPixelFormat;

(*		PROCEDURE TracePixelFormat(VAR pf : PixelFormat);
		BEGIN
			KernelLog.String("bpp: "); KernelLog.Int(pf.bpp, 4); KernelLog.Ln;
			KernelLog.String("depth: "); KernelLog.Int(pf.depth, 4); KernelLog.Ln;
			KernelLog.String("bigendian:");
			IF pf.bigendian THEN KernelLog.String("TRUE") ELSE KernelLog.String("FALSE") END; KernelLog.Ln;
			KernelLog.String("truecolor:");
			IF pf.truecolor THEN KernelLog.String("TRUE") ELSE KernelLog.String("FALSE") END; KernelLog.Ln;
			KernelLog.String("rmax: "); KernelLog.Int(pf.rmax, 4); KernelLog.Ln;
			KernelLog.String("gmax: "); KernelLog.Int(pf.gmax, 4); KernelLog.Ln;
			KernelLog.String("bmax: "); KernelLog.Int(pf.bmax, 4); KernelLog.Ln;
			KernelLog.String("rshift: "); KernelLog.Int(pf.rshift, 4); KernelLog.Ln;
			KernelLog.String("gshift: "); KernelLog.Int(pf.gshift, 4); KernelLog.Ln;
			KernelLog.String("bshift: "); KernelLog.Int(pf.bshift, 4); KernelLog.Ln;
		END TracePixelFormat;
*)
		(** is no longer specified in the 2002 revision of the protocol *)
		PROCEDURE FixupColorMapEntries;
		VAR nof, first  : LONGINT;
		BEGIN
			KernelLog.String("FixupColorMapEntries no longer supported... "); KernelLog.Ln;
			in.SkipBytes(1); first := in.Net16(); nof := in.Net16(); WHILE nof > 0 DO in.SkipBytes(6); DEC(nof) END
		END FixupColorMapEntries;

		(* supported encodings 5.2.3 *)
		PROCEDURE SetEncodings;
		VAR nof, e : LONGINT;
		BEGIN
			(* skip padding *)
			in.SkipBytes(1);
			encodings := {};
			nof := in.Net16();
			WHILE (nof > 0) DO e := in.Net32(); IF (e>=0) & (e < 32) THEN INCL(encodings, e) END; DEC(nof) END
		END SetEncodings;

		PROCEDURE SendRect(VAR r : Rectangle);
		BEGIN
			out.Net16(r.l); out.Net16(r.t); out.Net16(r.r - r.l); out.Net16(r.b - r.t);
			IF EncHextile IN encodings THEN
				out.Net32(5);
				SendHextile(out, vncInfo.img, mode, pf, workBuffer, pfHextile, r)
			ELSE
				out.Net32(0);
				SendRawRect(out, vncInfo.img, mode, pf, workBuffer, r)
			END
		END SendRect;

		PROCEDURE DoUpdates;
		VAR nof, i : LONGINT;
		BEGIN {EXCLUSIVE} (* must be exclusive to avoid sending collisions *)
			updateQ.GetBuffer(nof, drawRectBuffer);
			IF BundleRectangles THEN
				out.Char(0X); (* message type *) out.Char(0X); (* padding *)
				out.Net16(nof); (* number of rectangles *)
				IF SendFBUpdatePacketEarly THEN out.Update END;
				FOR i := 0 TO nof - 1 DO SendRect(drawRectBuffer[i]); IF ~BigPackets THEN out.Update END END;
				IF BigPackets THEN out.Update END
			ELSE
				FOR i := 0 TO nof - 1 DO
					out.Char(0X); (* message type *) out.Char(0X); (* padding *)
					out.Net16(1); (* number of rectangles *)
					SendRect(drawRectBuffer[i]);
					IF ~BigPackets THEN out.Update END
				END;
				IF BigPackets THEN out.Update END
			END;
		END DoUpdates;

		PROCEDURE AddDirty*(r : Rectangle);
		BEGIN
			updateQ.Add(r)
		END AddDirty;

		(* 5.2.4 *)
		PROCEDURE FBUpdateRequest;
		VAR rect, r : Rectangle;
		BEGIN
			IF in.Get() # 1X THEN r := WMRectangles.MakeRect(0, 0, vncInfo.width, vncInfo.height); updateQ.Add(r) END;
			rect.l := in.Net16(); rect.t := in.Net16();
			rect.r := rect.l + in.Net16(); rect.b := rect.t + in.Net16();
			(* ignoring the rect for now *)
			updateQ.SetAllowed
		END FBUpdateRequest;

		(* 5.2.5 *)
		PROCEDURE KeyEvent;
		VAR down : BOOLEAN;
			flags, greyKey : SET;
			ucs, keysym : LONGINT;
		BEGIN
			down := in.Get() = 1X;
			IF down THEN flags := {} ELSE flags := {Inputs.Release} END;
			in.SkipBytes(2); (* skip padding *)
			keysym := in.Net32();
			IF down & (keysym < 80H) THEN ucs := keysym ELSE ucs := 0 END;

			(* flags *)
			greyKey := {};
			CASE keysym OF
				| Inputs.KsShiftL : greyKey := {Inputs.LeftShift}
				| Inputs.KsShiftR : greyKey := {Inputs.RightShift}
				| Inputs.KsControlL : greyKey := {Inputs.LeftCtrl}
				| Inputs.KsControlR : greyKey := {Inputs.RightCtrl}
				| Inputs.KsMetaL : greyKey := {Inputs.LeftMeta}
				| Inputs.KsMetaR : greyKey := {Inputs.RightMeta}
				| Inputs.KsAltL : greyKey := {Inputs.LeftAlt}
				| Inputs.KsAltR : greyKey := {Inputs.RightAlt}
			ELSE
			END;
			IF down THEN
				CASE keysym OF
					| Inputs.KsBackSpace : ucs := 7FH (* backspace *)
					| Inputs.KsTab : ucs := 09H (* tab *)
					| Inputs.KsReturn : ucs := 0DH (* return/enter *)
					| Inputs.KsEscape : ucs := 01BH (* escape *)
					| Inputs.KsInsert : ucs := 0A0H (* insert *)
					| Inputs.KsDelete : ucs := 0A1H (* delete *)
					| Inputs.KsHome : ucs := 0A8H (* home *)
					| Inputs.KsEnd : ucs := 0A9H (* end *)
					| Inputs.KsPageUp : ucs := 0A2H (* pgup *)
					| Inputs.KsPageDown : ucs := 0A3H (* pgdn *)
					| Inputs.KsLeft : ucs := 0C4H (* left *)
					| Inputs.KsUp : ucs := 0C1H (* up *)
					| Inputs.KsRight : ucs := 0C3H (* right *)
					| Inputs.KsDown : ucs := 0C2H (* down *)
					| Inputs.KsF1: ucs := 0A4H (* f1 *)
					| Inputs.KsF2: ucs := 0A5H (* f2 *)
					| Inputs.KsF3: ucs := 01BH (* f3 *)
					| Inputs.KsF4: ucs := 0A7H (* f4 *)
					| Inputs.KsF5: ucs := 0F5H (* f5 *)
					| Inputs.KsF6: ucs := 0F6H (* f6 *)
					| Inputs.KsF7: ucs := 0F7H (* f7 *)
					| Inputs.KsF8: ucs := 0F8H (* f8 *)
					| Inputs.KsF9: ucs := 0F9H (* f9 *)
					| Inputs.KsF10: ucs := 0FAH (* f10 *)
					| Inputs.KsF11: ucs := 0FBH (* f11 *)
					| Inputs.KsF12: ucs := 0FCH (* f12 *)
				ELSE
				END
			END;
			IF down THEN keyState := keyState + greyKey ELSE keyState := keyState - greyKey END;
			IF keyState * Inputs.Ctrl # {} THEN
				IF (ucs > ORD('A')) & (ucs < ORD('Z')) THEN keysym := ucs - ORD('A') + 1 END; (* Ctrl-A - Ctrl-Z *)
				IF (ucs > ORD('a')) & (ucs < ORD('z')) THEN keysym := ucs - ORD('a') + 1 END; (* Ctrl-a - Ctrl-z *)
				ucs := 0;
			END;
			flags := flags + keyState;
			IF TraceKeyEvent IN Trace THEN KernelLog.String("Keysym = "); KernelLog.Hex(keysym, -4); KernelLog.Ln END;
			IF vncInfo.kl # NIL THEN vncInfo.kl(ucs, flags, keysym) END
		END KeyEvent;

		(* 5.2.6 *)
		PROCEDURE PointerEvent;
		VAR buttons : LONGINT; keys : SET; x, y, dz : LONGINT;
		BEGIN
			buttons := ORD(in.Get()); x := in.Net16(); y := in.Net16();
			keys := {};
			IF buttons MOD 2 = 1 THEN INCL(keys, 0) END;
			IF buttons DIV 2 MOD 2 = 1 THEN INCL(keys, 1) END;
			IF buttons DIV 4 MOD 2 = 1 THEN INCL(keys, 2) END;
			IF buttons DIV 8 MOD 2 = 1 THEN dz := -1 END;
			IF buttons DIV 16 MOD 2 = 1 THEN dz := +1 END;
			IF vncInfo.ml # NIL THEN vncInfo.ml(x, y, dz, keys) END
		END PointerEvent;

		(* 5.2.7 *)
		PROCEDURE ClientCutText;
		VAR i, len : LONGINT;
			text : String;
			skip : CHAR;
		BEGIN
			in.SkipBytes(3); (* padding *)
			len := in.Net32();
			NEW(text, Strings.Min(MaxCutSize, len + 1));
			FOR i := 0 TO len - 1 DO
				IF len < MaxCutSize - 1 THEN text[i] := in.Get() ELSE skip := in.Get() END;
			END;
			text[Strings.Min(MaxCutSize - 1, len)] := 0X;
			IF vncInfo.cutl # NIL THEN vncInfo.cutl(text) END;
		END ClientCutText;

		(** send a text as clipboard content to the client *)
		PROCEDURE SendClipboard*(text : String);
		VAR len : LONGINT;
		BEGIN {EXCLUSIVE}
			out.Char(3X); (* message type *)
			out.Char(0X); out.Char(0X); out.Char(0X); (* padding *)
			len := Strings.Length(text^);
			out.Net32(len);
			out.String(text^);
		END SendClipboard;


		(** 5.4.2 CopyRect Returns FALSE, if client does not support CopyRect
			this does not wait for fbupdatereq, does not flush *)
		PROCEDURE CopyRect*(srcx, srcy : LONGINT; dst : Rectangle) : BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF ~(EncCopyRect IN encodings) THEN RETURN FALSE END;
			out.Char(0X); (* message type *) out.Char(0X); (* padding *)
			out.Net16(1); (* number of rectangles *)
			out.Net16(dst.l); out.Net16(dst.t); out.Net16(dst.r - dst.l); out.Net16(dst.b - dst.t);
			out.Net32(1);
			out.Net16(srcx); out.Net16(srcy);
			RETURN TRUE
		END CopyRect;

		PROCEDURE Serve;
		VAR msgType : CHAR;
		BEGIN
			REPEAT
				msgType := in.Get();
				IF in.res = Streams.Ok THEN
					CASE msgType OF
						0X : SetPixelFormat; IF TraceMsg IN Trace THEN traceStr := "SetPixelFormat" END
						|1X: FixupColorMapEntries; IF TraceMsg IN Trace THEN traceStr := "FixupColorMapEntries" END
						|2X: SetEncodings; IF TraceMsg IN Trace THEN traceStr := "Encoding" END
						|3X: FBUpdateRequest; IF TraceMsg IN Trace THEN traceStr := "FBUpdate" END
						|4X: KeyEvent; IF TraceMsg IN Trace THEN traceStr := "KeyEvent" END
						|5X: PointerEvent; IF TraceMsg IN Trace THEN traceStr := "PointerEvent" END
						|6X: ClientCutText; IF TraceMsg IN Trace THEN traceStr := "ClientCutText" END
					ELSE IF TraceMsg IN Trace THEN traceStr := "unknown" END
					END;
					IF TraceMsg IN Trace THEN KernelLog.String("VNC request: "); KernelLog.String(traceStr); KernelLog.Ln END
				END
			UNTIL in.res # Streams.Ok
		END Serve;

	BEGIN {ACTIVE}
		IF SendVersion() & Authenticate() & Setup() THEN
			Machine.AtomicInc(NnofEnteredServe);
			Serve;
			Machine.AtomicInc(NnofLeftServer);
		END;
		client.Close;
		updateQ.Close;
		s.Remove(SELF);
	END VNCAgent;

	(** Wait for new TCP connections, start a VNC agent as soon as needed *)
	Server* = OBJECT
	VAR res: LONGINT; service, client: TCP.Connection; root : Agent; agent : VNCAgent;
		vncInfo : VNCInfo;
		nofAgents : LONGINT;
		stopped : BOOLEAN;
		init : VNCService;

		PROCEDURE &Open*(port: LONGINT; vncInfo : VNCInfo; init : VNCService; VAR res: LONGINT);
		BEGIN
			stopped := FALSE; SELF.vncInfo := vncInfo; SELF.init := init;
			NEW(service); service.Open(port, IP.NilAdr, TCP.NilPort, res);
			IF res = Streams.Ok THEN NEW(root); root.next := NIL
			ELSE service := NIL (* stop active body *)
			END;
			nofAgents := 0
		END Open;

		PROCEDURE CloseAllOthers(this : Agent);
		VAR p : Agent;
		BEGIN {EXCLUSIVE}
			p := root.next;
			WHILE p # NIL DO IF p # this THEN p.client.Close() END; p := p.next END;
		END CloseAllOthers;

		PROCEDURE Remove(a: Agent);
		VAR p: Agent;
		BEGIN
			BEGIN {EXCLUSIVE}
				p := root;
				WHILE (p.next # NIL) & (p.next # a) DO p := p.next END;
				IF p.next = a THEN p.next := a.next END;
				DEC(nofAgents)
			END;
			IF vncInfo.ncal # NIL THEN vncInfo.ncal(nofAgents) END
		END Remove;

		PROCEDURE AddDirty*(r : Rectangle);
		VAR p: Agent;
		BEGIN {EXCLUSIVE}
			p := root.next;
			WHILE (p # NIL) DO p(VNCAgent).AddDirty(r); p := p.next END;
		END AddDirty;

		PROCEDURE SendClipboard*(t : String);
		VAR p: Agent;
		BEGIN {EXCLUSIVE}
			p := root.next;
			WHILE (p # NIL) DO p(VNCAgent).SendClipboard(t); p := p.next END;
		END SendClipboard;

		PROCEDURE Close*;
		VAR p : Agent;
		BEGIN {EXCLUSIVE}
			service.Close();
			p := root.next;
			WHILE p # NIL DO p.client.Close(); p := p.next END;
			AWAIT(root.next = NIL);	(* wait for all agents to remove themselves *)
			AWAIT(stopped)	(* wait for service to terminate *)
		END Close;

	BEGIN {ACTIVE}
		IF service # NIL THEN
			LOOP
				service.Accept(client, res);
				IF res # Streams.Ok THEN EXIT END;
				IF init # NIL THEN
					NEW(vncInfo);
					vncInfo.connection := client;
					init(vncInfo);
					vncInfo.width := vncInfo.img.width;
					vncInfo.height := vncInfo.img.height
				END;
				NEW(agent, SELF, client, vncInfo);
				vncInfo.agent := agent;
				BEGIN {EXCLUSIVE}
					INC(nofAgents);
					agent.next := root.next; root.next := agent;
				END;
				IF vncInfo.ncal # NIL THEN vncInfo.ncal(nofAgents) END
			END
		END;
		BEGIN {EXCLUSIVE} stopped := TRUE END
	END Server;

VAR
	NnofAuthenticate-,
	NnofAuthNone-,
	NnofAuthVNC-, NnofAuthOk-, NnofAuthFailed-,
	NnofEnteredServe-, NnofLeftServer- : LONGINT;

PROCEDURE SendPixel(out : Streams.Writer; pix : LONGINT; VAR pf : PixelFormat);
BEGIN
	IF pf.depth = 8 THEN out.Char(CHR(pix))
	ELSIF pf.depth = 16 THEN
		IF pf.bigendian THEN out.Net16(pix) ELSE out.Char(CHR(pix MOD 100H)); out.Char(CHR(pix DIV 100H)) END
	ELSE
		IF pf.bigendian THEN out.Net32(pix) ELSE
			out.Char(CHR(pix MOD 100H)); out.Char(CHR(pix DIV 100H MOD 100H));
			out.Char(CHR(pix DIV 10000H MOD 100H)); out.Char(CHR(pix DIV 1000000H MOD 100H))
		END
	END
END SendPixel;

PROCEDURE SendRawRect(out : Streams.Writer; img : Raster.Image; VAR mode : Raster.Mode; VAR pf : PixelFormat; buf : WorkBuf; r : Rectangle);
VAR i, j, rh, rw : LONGINT; cb, cg, cr : LONGINT;
BEGIN
	rh := r.b - r.t; rw := r.r - r.l;
(*	KernelLog.String("w/h"); KernelLog.Int(rw, 5); KernelLog.Int(rh, 5);
	KernelLog.String("rect :"); KernelLog.Int(r.l, 5); KernelLog.Int(r.t, 5);KernelLog.Int(r.r, 5); KernelLog.Int(r.b, 5); KernelLog.Ln; *)
	IF pf.native16 THEN (* optimized 16 bit case *)
		FOR i := 0 TO rh - 1 DO
			Raster.GetPixels(img, r.l, r.t + i, rw, Raster.BGR565, buf^, 0, mode);
			out.Bytes(buf^, 0, 2*rw)
		END
	ELSE (* not so optimized generic case *)
		FOR i := 0 TO rh - 1 DO
			Raster.GetPixels(img, r.l, r.t + i, rw, Raster.BGR888, buf^, 0, mode);
			FOR j := 0 TO rw - 1 DO
				cb := LSH(ORD(buf[j * 3]), -pf.sb);
				cg := LSH(ORD(buf[j * 3 + 1]), -pf.sg);
				cr := LSH(ORD(buf[j * 3 + 2]), -pf.sr);
				SendPixel(out, LSH(cg, pf.gshift) + LSH(cb, pf.bshift) + LSH(cr, pf.rshift), pf)
			END
		END
	END
END SendRawRect;

PROCEDURE AnalyzeColors(VAR hextile : PFHextile; nofPixels : LONGINT; VAR bg, fg : LONGINT; VAR solid, mono : BOOLEAN);
VAR i, n0, n1, c0, c1, c : LONGINT;
BEGIN
	n0 := 0; n1 := 0; solid := TRUE; mono := TRUE;
	FOR i := 0 TO nofPixels - 1 DO
		c := hextile[i];
		IF n0 = 0 THEN c0 := c END;
		IF c = c0 THEN INC(n0)
		ELSE
			IF n1 = 0 THEN c1 := c; solid := FALSE END;
			IF c = c1 THEN INC(n1)
			ELSE mono := FALSE
			END
		END
	END;
	IF n0 > n1 THEN bg := c0; fg := c1 ELSE bg := c1; fg := c0 END
END AnalyzeColors;

PROCEDURE EncodeHextile(hextile : PFHextile; buf : WorkBuf; VAR pf : PixelFormat; w, h : LONGINT; bg, fg : LONGINT; mono : BOOLEAN;
	VAR nofRects : LONGINT) : LONGINT;
VAR pos, x, y, c, tx, ty, bypp, i, j : LONGINT; eq : BOOLEAN;
BEGIN
	pos := 0; nofRects := 0;
	IF pf.depth = 8 THEN bypp := 1
	ELSIF pf.depth = 16 THEN bypp := 2
	ELSE bypp := 4
	END;
	FOR y := 0 TO h - 1 DO
		FOR x := 0 TO w - 1 DO
			c := hextile[y * w + x];
			IF c # bg THEN
				tx := x + 1;
				(* in x direction *)
				WHILE (tx < w) & (hextile[y * w + tx] = c) DO INC(tx) END;
				ty := y + 1; eq := TRUE;
				WHILE (ty < h) & eq DO
					(* check a line *)
					j := x; WHILE (j < tx) & (hextile[ty * w + j] = c) DO INC(j) END;
					IF j < tx THEN eq := FALSE ELSE INC(ty) END;
				END;
				IF ~mono THEN
					(* send the pixel (move into procedure ?) *)
					IF pf.depth = 8 THEN buf[pos] := CHR(c); INC(pos)
					ELSIF pf.depth = 16 THEN
						IF pf.bigendian THEN buf[pos] := CHR(c DIV 256); INC(pos); buf[pos] := CHR(c MOD 256); INC(pos)
						ELSE buf[pos] := CHR(c MOD 256); INC(pos); buf[pos] := CHR(c DIV 256); INC(pos)
						END
					ELSE
						IF pf.bigendian THEN
							buf[pos] := CHR(c DIV 1000000H MOD 100H); INC(pos);
							buf[pos] := CHR(c DIV 10000H MOD 100H); INC(pos);
							buf[pos] := CHR(c DIV 100H MOD 100H); INC(pos);
							buf[pos] := CHR(c MOD 100H); INC(pos)
						ELSE
							buf[pos] := CHR(c MOD 100H); INC(pos);
							buf[pos] := CHR(c DIV 100H MOD 100H); INC(pos);
							buf[pos] := CHR(c DIV 10000H MOD 100H); INC(pos);
							buf[pos] := CHR(c DIV 1000000H MOD 100H); INC(pos)
						END
					END
				END;
				(* send rectangle coordinates *)
				buf[pos] := CHR(x * 16 + y); INC(pos);
				(* w, h *)
				buf[pos] := CHR((tx- x - 1) * 16 + (ty - y) - 1); INC(pos);
				INC(nofRects);
				(* clear the rectangle with bg col *)
				FOR j := y TO ty - 1 DO FOR i := x TO tx - 1 DO hextile[j * w + i] := bg END END;
				(* check if hextile is shorter than raw encoding *)
				IF pos >= w * h * bypp THEN RETURN 0 END
			END
		END
	END;
	RETURN pos
END EncodeHextile;

PROCEDURE SendHextile(out : Streams.Writer; img : Raster.Image; VAR mode : Raster.Mode; VAR pf : PixelFormat;
	buf : WorkBuf; VAR hextile : PFHextile; r : Rectangle);
VAR x, y, w, h, ofs, i, cb, cg, cr, bg, fg : LONGINT;
			validbg, validfg, mono, solid : BOOLEAN;
			newbg, newfg, encBytes, nofRects, flags : LONGINT;
			hextileFlags : SET;
BEGIN
	validbg := FALSE;
	y := r.t;
	WHILE y < r.b DO
		x := r.l;
		h := 16; IF r.b - y < 16 THEN h := r.b - y END; (* current hextile height *)
		WHILE x < r.r DO
			w := 16; IF r.r - x < 16 THEN w := r.r - x END; (* current hextile width *)
			(* copy the hexile pixels into workbuffer *)
			ofs := 0; FOR i := 0 TO h - 1  DO Raster.GetPixels(img, x, y + i, w, Raster.BGR888, buf^, ofs, mode); INC(ofs, w * 3) END;
			(* to pixelformat *)
			FOR i := 0 TO w * h - 1 DO
				cb := LSH(ORD(buf[i * 3]), -pf.sb);
				cg := LSH(ORD(buf[i * 3 + 1]), -pf.sg);
				cr := LSH(ORD(buf[i * 3 + 2]), -pf.sr);
				hextile[i] := LSH(cg, pf.gshift) + LSH(cb, pf.bshift) + LSH(cr, pf.rshift);
			END;
			AnalyzeColors(hextile, w * h, newbg, newfg, solid, mono);
			hextileFlags := {};
			IF ~validbg OR (newbg # bg) THEN validbg := TRUE; bg := newbg; INCL(hextileFlags, HexBGSpecified) END;
			IF ~solid THEN
				INCL(hextileFlags, HexAnySubrects);
				IF mono THEN IF ~validfg OR (newfg # fg) THEN validfg := TRUE; fg := newfg; INCL(hextileFlags, HexFGSpecified) END
				ELSE validfg := FALSE; INCL(hextileFlags, HexSubrectsColoured)
				END;
				encBytes := EncodeHextile(hextile, buf, pf, w, h, bg, fg, mono, nofRects);
				IF encBytes = 0 THEN (* hextile would need more bytes than raw *)
					validbg := FALSE; validfg := FALSE;
					hextileFlags := { HexRaw }
				END
			END;

			flags := 0; FOR i := 0 TO 31 DO IF i IN hextileFlags THEN INC(flags, i) END END;
			out.Char(CHR(flags));

			IF HexBGSpecified IN hextileFlags THEN SendPixel(out, bg, pf) END;
			IF HexFGSpecified IN hextileFlags THEN SendPixel(out, fg, pf) END;
			IF HexRaw IN hextileFlags THEN FOR i := 0 TO w * h - 1 DO SendPixel(out, hextile[i], pf); END
			ELSIF HexAnySubrects IN hextileFlags THEN
				out.Char(CHR(nofRects));
				out.Bytes(buf^, 0, encBytes)
			END;
			INC(x, 16)
		END;
		INC(y, 16)
	END
END SendHextile;

PROCEDURE OpenServer*(port : LONGINT; img : Raster.Image; name, password : ARRAY OF CHAR; ml : VNCMouseListener;
										kl : VNCKeyboardListener; cl : VNCClipboardListener; ncal : VNCNofClientsActiveListener) : Server;
VAR server : Server;
	 vncInfo : VNCInfo; res : LONGINT;
BEGIN
	NEW(vncInfo);
	COPY(password, vncInfo.password);
	COPY(name, vncInfo.name);
	vncInfo.width := img.width;
	vncInfo.height := img.height;
	vncInfo.img := img;
	vncInfo.ml := ml; vncInfo.kl := kl; vncInfo.cutl := cl; vncInfo.ncal := ncal;
	NEW(server, port, vncInfo, NIL, res);
	IF res # 0 THEN server := NIL END;
	RETURN server;
END OpenServer;

PROCEDURE OpenService*(port : LONGINT; init : VNCService) : Server;
VAR server : Server; res : LONGINT;
BEGIN
	NEW(server, port, NIL, init, res);
	IF res # 0 THEN server := NIL END;
	RETURN server;
END OpenService;

END VNCServer.

