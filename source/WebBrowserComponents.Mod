MODULE WebBrowserComponents;	(** AUTHOR "Simon L. Keel"; PURPOSE "components used by the WebBrowser-modules"; *)

IMPORT
	Strings, WMStandardComponents, WMGraphics, WMRectangles, WMEvents, WebHTTP, NewHTTPClient, Streams, Files,
	Raster, Codecs, KernelLog, WMComponents, WMTextView, Texts, TextUtilities, WMWindowManager,
	XML, SVG, SVGLoader;

CONST
	verbose = TRUE;
	MaxHTTPConnections = 16;
	MaxHTTPConnectionPerServer = 3;

TYPE
	String = Strings.String;
	VisualComponent = WMComponents.VisualComponent;

	SVGPanel* = OBJECT(VisualComponent)
	VAR
		img : SVG.Document;

		PROCEDURE & New*(svg: XML.Element);
		BEGIN
			Init;

			IF verbose THEN KernelLog.String("---Rendering SVG... "); END;

			img := SVGLoader.LoadSVGEmbedded(svg);

			IF img # NIL THEN
				bounds.SetExtents(img.width, img.height);
				IF verbose THEN KernelLog.String("done."); KernelLog.Ln(); END;
			ELSE
				bounds.SetExtents(15, 15);
				IF verbose THEN KernelLog.String("failed."); KernelLog.Ln(); END;
			END
		END New;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			w, h : LONGINT;
		BEGIN
			DrawBackground^(canvas);
			w := bounds.GetWidth();
			h := bounds.GetHeight();
			IF img # NIL THEN
				canvas.ScaleImage(img, WMRectangles.MakeRect(0, 0, img.width, img.height), WMRectangles.MakeRect(0, 0, w, h), WMGraphics.ModeCopy, 2)
			ELSE
				canvas.Line(0, 0, w-1, 0, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(0, 0, 0, h-1, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(0, h-1, w-1, h-1, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(w-1, 0, w-1, h-1, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(0, 0, w-1, h-1, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(0, h-1, w-1, 0, 0FFH, WMGraphics.ModeSrcOverDst);
			END;
		END DrawBackground;

	END SVGPanel;

	SVGLinkPanel* = OBJECT(SVGPanel)
	VAR
		onClick : WMEvents.EventSource;
		msg : ANY;

		PROCEDURE & Create*(svg: XML.Element; loadLink : WMEvents.EventListener; msg : ANY);
		BEGIN
			New(svg);
			NEW(onClick, SELF, NIL, NIL, SELF.StringToCompCommand);
			events.Add(onClick);
			onClick.Add(loadLink);
			SELF.msg := msg;
			SetPointerInfo(manager.pointerLink);
		END Create;

		PROCEDURE PointerDown(x, y: LONGINT; keys : SET);
		BEGIN
			onClick.Call(msg);
			PointerDown^(x, y, keys);
		END PointerDown;
	END SVGLinkPanel;

	(** just shows an image, stretches the image to fit to the property "bounds" (initial size = image size) *)
	StretchImagePanel* = OBJECT(VisualComponent)
	VAR
		img : WMGraphics.Image;

		PROCEDURE & New*(rc : ResourceConnection; url : String; x, y : LONGINT);
		BEGIN
			Init;
			IF rc = NIL THEN
				rc := GetResourceConnection(url);
			END;
			IF (rc # NIL) & (rc.reader # NIL) THEN
				IF verbose THEN KernelLog.String("---Loading StretchImagePanel. Url: "); KernelLog.String(rc.url^); KernelLog.String("... "); END;
				IF ~Strings.StartsWith2("image/", rc.mimeType^) THEN rc.mimeType := GetMimeType(rc.url^) END;
				img := LoadImage(rc.reader, rc.mimeType^, rc.url^);
				IF img # NIL THEN
					IF (x < 0) OR (y < 0) THEN
						x := img.width;
						y := img.height;
					END;
					bounds.SetExtents(x, y);
				END;
				IF verbose THEN KernelLog.String("done."); KernelLog.Ln(); END;
			END;
			IF (rc = NIL) OR (rc.reader = NIL) OR (img = NIL) THEN
				fillColor.Set(0FFFFFFFFH);
				IF (x < 0) OR (y < 0) THEN
					x := 15;
					y := 15;
				END;
				bounds.SetExtents(x, y);
			END;
			IF rc # NIL THEN rc.Release() END;
		END New;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			w, h : LONGINT;
		BEGIN
			DrawBackground^(canvas);
			w := bounds.GetWidth();
			h := bounds.GetHeight();
			IF img # NIL THEN
				canvas.ScaleImage(img, WMRectangles.MakeRect(0, 0, img.width, img.height), WMRectangles.MakeRect(0, 0, w, h), WMGraphics.ModeCopy, 2)
			ELSE
				canvas.Line(0, 0, w-1, 0, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(0, 0, 0, h-1, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(0, h-1, w-1, h-1, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(w-1, 0, w-1, h-1, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(0, 0, w-1, h-1, 0FFH, WMGraphics.ModeSrcOverDst);
				canvas.Line(0, h-1, w-1, 0, 0FFH, WMGraphics.ModeSrcOverDst);
			END;
		END DrawBackground;

	END StretchImagePanel;

	StretchImageLinkPanel* = OBJECT(StretchImagePanel)
	VAR
		onClick : WMEvents.EventSource;
		msg : ANY;

		PROCEDURE & Create*(rc : ResourceConnection; url : String; x, y : LONGINT; loadLink : WMEvents.EventListener; msg : ANY);
		BEGIN
			New(rc, url, x, y);
			NEW(onClick, SELF, NIL, NIL, SELF.StringToCompCommand);
			events.Add(onClick);
			onClick.Add(loadLink);
			SELF.msg := msg;
			SetPointerInfo(manager.pointerLink);
		END Create;

		PROCEDURE PointerDown(x, y: LONGINT; keys : SET);
		BEGIN
			onClick.Call(msg);
			PointerDown^(x, y, keys);
		END PointerDown;

	END StretchImageLinkPanel;

	TileImagePanel* = OBJECT(VisualComponent)
	VAR
		img : WMGraphics.Image;

		PROCEDURE & New*(rc : ResourceConnection; url : String);
		BEGIN
			Init;
			alignment.Set(WMComponents.AlignClient);
			IF rc = NIL THEN
				rc := GetResourceConnection(url);
			END;
			IF (rc # NIL) & (rc.reader # NIL) THEN
				IF verbose THEN KernelLog.String("---Loading TileImagePanel. Url: "); KernelLog.String(rc.url^); KernelLog.String("... "); END;
				IF ~Strings.StartsWith2("image/", rc.mimeType^) THEN rc.mimeType := GetMimeType(rc.url^) END;
				img := LoadImage(rc.reader, rc.mimeType^, rc.url^);
				IF verbose THEN KernelLog.String("done."); KernelLog.Ln(); END;
			END;
			IF rc # NIL THEN rc.Release() END;
		END New;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			w, h, i, j, wCnt, hCnt : LONGINT;
		BEGIN
			DrawBackground^(canvas);
			IF img # NIL THEN
				w := bounds.GetWidth();
				h := bounds.GetHeight();
				wCnt := w DIV img.width;
				IF (wCnt * img.width) # w THEN INC(wCnt); END;
				hCnt := h DIV img.height;
				IF (hCnt * img.height) # h THEN INC(hCnt); END;
				FOR i := 1 TO wCnt DO
					FOR j := 1 TO hCnt DO
						canvas.DrawImage((i-1)*img.width, (j-1)*img.height, img, WMGraphics.ModeSrcOverDst);
					END;
				END;
			END
		END DrawBackground;

	END TileImagePanel;

	HR* = OBJECT(VisualComponent)
	VAR
		x : LONGINT;

		PROCEDURE & New*(x : LONGINT);
		BEGIN
			Init;
			ParentTvWidthChanged(x);
		END New;

		PROCEDURE ParentTvWidthChanged*(x : LONGINT);
		BEGIN
			DEC(x, 30);
			IF x < 10 THEN x := 10 END;
			SELF.x := x;
			bounds.SetExtents(x, 2);
		END ParentTvWidthChanged;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		BEGIN
			DrawBackground^(canvas);
			canvas.Line(0, 0, x-1, 0, LONGINT(0808080FFH), WMGraphics.ModeSrcOverDst);
			canvas.Line(0, 1, x-1, 1, LONGINT(0C0C0C0FFH), WMGraphics.ModeSrcOverDst);
		END DrawBackground;
	END HR;

	ShortText* = OBJECT(VisualComponent)
	VAR
		textView : WMTextView.TextView;

		PROCEDURE & New*(txt : ARRAY OF CHAR);
		VAR
			errorText : Texts.Text;
			textWriter : TextUtilities.TextWriter;
		BEGIN
			Init;
			NEW(textView);
			textView.alignment.Set(WMComponents.AlignClient);
			NEW(errorText);
			NEW(textWriter, errorText);
			textWriter.SetFontSize(20);
			textWriter.SetVerticalOffset(20);
			textWriter.String(txt);
			textWriter.Update;
			textView.SetText(errorText);
			AddContent(textView);
			alignment.Set(WMComponents.AlignClient);
		END New;

	END ShortText;

	TextPanel* = OBJECT(VisualComponent)

		PROCEDURE & New*(rc : ResourceConnection; url : String);
		VAR
			vScrollbar : WMStandardComponents.Scrollbar;
			hScrollbar : WMStandardComponents.Scrollbar;
			tv : WMTextView.TextView;
			isoDecoder : Codecs.TextDecoder;
			result : LONGINT;
		BEGIN
			Init;
			takesFocus.Set(FALSE);
			alignment.Set(WMComponents.AlignClient);
			NEW(vScrollbar);
			vScrollbar.alignment.Set(WMComponents.AlignRight);
			AddContent(vScrollbar);
			NEW(hScrollbar);
			hScrollbar.alignment.Set(WMComponents.AlignBottom);
			hScrollbar.vertical.Set(FALSE);
			AddContent(hScrollbar);
			IF rc = NIL THEN
				rc := GetResourceConnection(url);
			END;
			IF (rc # NIL) & (rc.reader # NIL) THEN
				IF verbose THEN KernelLog.String("---Loading TextPanel. Url: "); KernelLog.String(rc.url^); KernelLog.String("... "); END;
				NEW(tv);
				tv.alignment.Set(WMComponents.AlignClient);
				tv.SetScrollbars(hScrollbar, vScrollbar);
				AddContent(tv);
				isoDecoder := Codecs.GetTextDecoder("ISO8859-1");
				isoDecoder.Open(rc.reader, result);
				tv.SetText(isoDecoder.GetText());
				tv.cursor.SetPosition(0);
				IF verbose THEN KernelLog.String("done."); KernelLog.Ln(); END;
			END;
			IF rc # NIL THEN rc.Release() END;
		END New;

	END TextPanel;

	HTTPConnectionPool* = OBJECT
	VAR
		connection : ARRAY MaxHTTPConnections OF ResourceConnection;
		conCnt : LONGINT;
(*logW : MultiLogger.LogWindow;
log : Streams.Writer;*)
		PROCEDURE & Init*;
		BEGIN
			conCnt := 0;
(*NEW(logW, "HTTPConnectionPool", log);*)
		END Init;

		PROCEDURE Get*(url : String) : ResourceConnection;
		BEGIN {EXCLUSIVE}
			RETURN PrivateGet(url);
		END Get;

		PROCEDURE PrivateGet(url : String) : ResourceConnection;
		VAR
			server, newServer : String;
			index : LONGINT;
			i : LONGINT;
			con : ResourceConnection;
			charset: WebHTTP.AdditionalField;
			reader : Streams.Reader;
			result : LONGINT;
			cnt : LONGINT;
		BEGIN
			server := GetServer(url^);

			AWAIT((conCnt < MaxHTTPConnections) & (ServerCnt(server) < MaxHTTPConnectionPerServer));

			index := -1; i := 0;
			WHILE((index = -1) & (i < MaxHTTPConnections)) DO
				(* search for non-busy connection of the same server... *)
				IF (connection[i] # NIL) & (connection[i].server^ = server^) & (~connection[i].busy) THEN
					index := i;
				END;
				(* ... if none is found, search for empty index *)
				IF (i = MaxHTTPConnections - 1) & (index = -1) THEN
					i := 0;
					WHILE((index = -1) & (i < MaxHTTPConnections)) DO
						IF connection[i] = NIL THEN
							index := i;
						END;
						INC(i);
					END;
					(* ... if none is found, take the next non-busy connection. *)
					IF index = -1 THEN
						i := 0;
						WHILE((index = -1) & (i < MaxHTTPConnections)) DO
							IF ~connection[i].busy THEN
								index := i;
							END;
							INC(i);
						END;
					END;
					ASSERT(index >= 0);
				END;
				INC(i);
			END;
			ASSERT(index >= 0);
(*log.String("Get: "); log.String(url^); log.String(" Index: "); log.Int(index, 0); log.Ln(); log.Update();*)
			con := connection[index];
			IF con = NIL THEN
				NEW(connection[index]);
				con := connection[index];
				con.index := index;
				con.server := server;
				NEW(con.http);
				con.http.requestHeader.useragent := "BimBrowser (bluebottle.ethz.ch)";
				IF Strings.Pos("google.", url^) # -1 THEN (* only to get UTF-8 charset *)
					con.http.requestHeader.useragent := "Mozilla/5.0";
				END;
				NEW(charset);
				charset.key := "Accept-Charset:";
				charset.value := "UTF-8,ISO-8859-1";
				con.http.requestHeader.additionalFields := charset;
			END;
			con.busy := TRUE;

			cnt := 0;
			LOOP
				con.http.Get(url^, TRUE, reader, result);
				IF (cnt < 16) & (result = 0) & ((con.http.responseHeader.statuscode >= 301) & (con.http.responseHeader.statuscode <= 303)) THEN (* "Moved" or "See Other" *)
					IF Strings.Pos("://", con.http.responseHeader.location) = -1 THEN
						IF ~Strings.StartsWith2("/", con.http.responseHeader.location) THEN
							url := Strings.ConcatToNew(server^, "/");
							url := Strings.ConcatToNew(url^, con.http.responseHeader.location);
						ELSE
							url := Strings.ConcatToNew(server^, con.http.responseHeader.location);
						END;
					ELSE
						url := Strings.NewString(con.http.responseHeader.location);
						newServer := GetServer(con.http.responseHeader.location);
						IF server^ # newServer^ THEN
							con.busy := FALSE;
							RETURN PrivateGet(url);
						END;
					END;
					IF verbose THEN KernelLog.String("---Redirecting to "); KernelLog.String(url^); KernelLog.Ln(); END;
					WHILE reader.Get() # 0X DO END;
					INC(cnt);
				ELSE
					EXIT;
				END;
			END;
			con.url := url;
			con.mimeType := Strings.NewString(con.http.responseHeader.contenttype);
			Strings.TrimWS(con.mimeType^);
			con.reader := reader;
			con.released := FALSE;
			IF result # 0 THEN
				con.busy := FALSE;
				RETURN NIL;
			ELSE
				INC(conCnt);
				RETURN con;
			END;
		END PrivateGet;

		PROCEDURE Release(rc : ResourceConnection);
		BEGIN {EXCLUSIVE}
			connection[rc.index].busy := FALSE;
			DEC(conCnt);
		END Release;

		PROCEDURE ServerCnt(server : String) : LONGINT;
		VAR
			cnt, i : LONGINT;
		BEGIN
			cnt := 0;
			FOR i := 0 TO MaxHTTPConnections - 1 DO
				IF (connection[i] # NIL) & (connection[i].server^ = server^) & (connection[i].busy) THEN INC(cnt) END;
			END;
			RETURN cnt;
		END ServerCnt;

		PROCEDURE GetServer(VAR url : ARRAY OF CHAR) : String;
		VAR
			end : LONGINT;
		BEGIN
			end := Strings.IndexOfByte('/', Strings.Pos("://", url) + 3, url);
			IF end = -1 THEN end := Strings.Length(url) END;
			RETURN Strings.Substring(0, end, url);
		END GetServer;

	END HTTPConnectionPool;

	ResourceConnection* = OBJECT
	VAR
		url- : String;
		mimeType- : String;
		reader- : Streams.Reader;
		http : NewHTTPClient.HTTPConnection;
		busy : BOOLEAN;
		index : LONGINT;
		server : String;
		released : BOOLEAN;

		PROCEDURE Stop*;
		BEGIN {EXCLUSIVE}
			IF ~released & (http # NIL) THEN
				http.Close();
				server := Strings.NewString("");
			END;
		END Stop;

		PROCEDURE Release*;
		BEGIN {EXCLUSIVE}
			released := TRUE;
			IF http # NIL THEN
				httpConnectionPool.Release(SELF);
			END;
		END Release;

	END ResourceConnection;


VAR
	manager : WMWindowManager.WindowManager;
	httpConnectionPool* : HTTPConnectionPool;

PROCEDURE GetResourceConnection*(url : String) : ResourceConnection;
VAR
	pos : LONGINT;
	protocol : String;
	filename : String;
	connection : ResourceConnection;
	file : Files.File;
	fileReader : Files.Reader;
BEGIN
	Strings.TrimWS(url^);
	pos := Strings.Pos("://", url^);
	IF pos = -1 THEN
		IF verbose THEN KernelLog.String("Unknown Protocol: "); KernelLog.String(url^); KernelLog.Ln(); END;
		RETURN NIL;
	END;
	protocol := Strings.Substring(0, pos, url^);
	IF (pos + 3) >= Strings.Length(url^) THEN
		IF verbose THEN KernelLog.String("Bad URL: "); KernelLog.String(url^); KernelLog.Ln(); END;
		RETURN NIL;
	END;
	filename := Strings.Substring2(pos+3, url^);
	ClearFilename(filename^);

	IF protocol^ = "http" THEN
		RETURN httpConnectionPool.Get(url);
	ELSIF protocol^ = "file" THEN
		file := Files.Old(filename^);
		IF file = NIL THEN
			IF verbose THEN KernelLog.String("file not found: "); KernelLog.String(url^); KernelLog.Ln(); END;
			RETURN NIL;
		END;
		Files.OpenReader(fileReader, file, 0);
		NEW(connection);
		connection.url := url;
		connection.mimeType := GetMimeType(filename^);
		connection.reader := fileReader;
		RETURN connection;
	ELSE
		IF verbose THEN KernelLog.String("Unknown Protocol: "); KernelLog.String(protocol^); KernelLog.Ln(); END;
		RETURN NIL;
	END;
END GetResourceConnection;

PROCEDURE ClearFilename( VAR name: ARRAY OF CHAR );  (* strip positioning info appended to filename *)
VAR i: LONGINT;
BEGIN
	i := 0;
	LOOP
		IF name[i] < '.' THEN  name[i] := 0X  END;
		IF name[i] = 0X THEN  EXIT  END;
		INC( i );
		IF i >= LEN( name ) THEN  EXIT  END
	END
END ClearFilename;

PROCEDURE GetMimeType(VAR filename : ARRAY OF CHAR) : String;
VAR
	dotPos : LONGINT;
	appendix : String;
BEGIN
	Strings.TrimWS(filename);
	dotPos := Strings.LastIndexOfByte2('.', filename);
	IF  (dotPos = -1) OR (dotPos = Strings.Length(filename) - 1) THEN
		RETURN Strings.NewString(filename);
	END;
	appendix := Strings.Substring2(dotPos + 1, filename);
	Strings.LowerCase(appendix^);
	IF appendix^ = "html" THEN RETURN Strings.NewString("text/html"); END;
	IF appendix^ = "htm" THEN RETURN Strings.NewString("text/html"); END;
	IF appendix^ = "txt" THEN RETURN Strings.NewString("text/plain"); END;
	IF appendix^ = "jpg" THEN RETURN Strings.NewString("image/jpeg"); END;
	IF appendix^ = "jpeg" THEN RETURN Strings.NewString("image/jpeg"); END;
	IF appendix^ = "jpe" THEN RETURN Strings.NewString("image/jpeg"); END;
	IF appendix^ = "jp2" THEN RETURN Strings.NewString("image/jp2"); END;
	IF appendix^ = "png" THEN RETURN Strings.NewString("image/png"); END;
	IF appendix^ = "bmp" THEN RETURN Strings.NewString("image/bmp"); END;
	IF appendix^ = "gif" THEN RETURN Strings.NewString("image/gif"); END;
	IF appendix^ = "svg" THEN RETURN Strings.NewString("image/svg+xml"); END;
	IF appendix^ = "xml" THEN RETURN Strings.NewString("application/xml"); END;
	IF appendix^ = "pdf" THEN RETURN Strings.NewString("application/pdf"); END;
	RETURN appendix;
END GetMimeType;

PROCEDURE LoadImage*(reader : Streams.Reader; mimeType : ARRAY OF CHAR; name : ARRAY OF CHAR): WMGraphics.Image;
VAR
	img : WMGraphics.Image;
	res, w, h, x : LONGINT;
	decoder : Codecs.ImageDecoder;
	ext : String;

	PROCEDURE GetExtensionForMimeType(VAR mimeType : ARRAY OF CHAR) : String;
	BEGIN
		IF Strings.StartsWith2("image/jpeg", mimeType) THEN RETURN Strings.NewString("JPG"); END;
		IF Strings.StartsWith2("image/jp2", mimeType) THEN RETURN Strings.NewString("JP2"); END;
		IF Strings.StartsWith2("image/png", mimeType) THEN RETURN Strings.NewString("PNG"); END;
		IF Strings.StartsWith2("image/bmp", mimeType) THEN RETURN Strings.NewString("BMP"); END;
		IF Strings.StartsWith2("image/gif", mimeType) THEN RETURN Strings.NewString("GIF"); END;
		IF Strings.StartsWith2("image/svg+xml", mimeType) THEN RETURN Strings.NewString("SVG"); END;
		RETURN Strings.NewString("");
	END GetExtensionForMimeType;

BEGIN
	IF reader = NIL THEN RETURN NIL END;
	ext := GetExtensionForMimeType(mimeType);
	decoder := Codecs.GetImageDecoder(ext^);
	IF decoder = NIL THEN
		KernelLog.String("No decoder found for "); KernelLog.String(mimeType); KernelLog.Ln;
		RETURN NIL
	END;
	decoder.Open(reader, res);
	IF res = 0 THEN
		decoder.GetImageInfo(w, h, x, x);
		NEW(img);
		Raster.Create(img, w, h, Raster.BGRA8888);
		decoder.Render(img);
		NEW(img.key, LEN(name)); COPY(name, img.key^);
	END;
	RETURN img
END LoadImage;

BEGIN
	manager := WMWindowManager.GetDefaultManager();
	NEW(httpConnectionPool);
END WebBrowserComponents.
