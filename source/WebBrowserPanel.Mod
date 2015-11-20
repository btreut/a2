MODULE WebBrowserPanel; (** AUTHOR "Simon L. Keel"; PURPOSE "components for loading and displaying web-pages"; *)

IMPORT
	HTMLScanner, HTMLParser, HTMLTransformer, WebBrowserComponents,
	WMComponents, WMProperties, WMTextView, WMStandardComponents, Texts, WMEvents, TextUtilities,
	Codecs, XML, XMLObjects, Strings, KernelLog, Messages := WMMessages;

CONST
	verbose = TRUE;
	modeSourceCode = 0;
	modeParsedHtml = 1;
	modeBbtXml = 2;
	modeBbtText = 3;
	outputMode = modeBbtText;
	typePercent = 0;
	typeParts = 1;
	typeFix = 2;

TYPE
	String = Strings.String;
	VisualComponent = WMComponents.VisualComponent;

	NotifyMsg* = POINTER TO RECORD
		url* : String;
		title* : String;
		loadID* : LONGINT;
	END;

	LoadedMsg* = POINTER TO RECORD
		vc : VisualComponent;
		url : String;
		title : String;
	END;

	FrameNode = POINTER TO RECORD
		next : FrameNode;
		name : String;
		scrolling : BOOLEAN;
		size : LONGINT;
		relative : BOOLEAN;
		panel : VisualComponent;
		isLast : BOOLEAN;
	END;

	FrameslotNode = POINTER TO RECORD
		next : FrameslotNode;
		size : LONGINT;
		type : LONGINT;
	END;

	FramesetNode = POINTER TO RECORD
		next : FramesetNode;
		frameset : XML.Element;
		src : String;
		name : String;
		scrolling : BOOLEAN;
	END;

	WebPanel* = OBJECT (VisualComponent)
	VAR
		url- : WMProperties.StringProperty;
		notify* : WMEvents.EventListener;
		openNewWindow* : PROCEDURE {DELEGATE} (url : String);
		loadLink* : WMEvents.EventListener;
		vc : VisualComponent;
		loadingText : WebBrowserComponents.ShortText;
		pending : BOOLEAN;
		loadID : LONGINT;

		PROCEDURE &Init*;
		VAR
			s : String;
		BEGIN
			Init^;
			takesFocus.Set(FALSE);
			NEW(url, NIL, Strings.NewString("WebPanel URL"), Strings.NewString("Stores the URL of a WebPanel"));
			s := Strings.NewString("   Loading...");
			NEW(loadingText, s^);
			pending := FALSE;
		END Init;

		PROCEDURE Load*(loadID : LONGINT);
		VAR
			cl : ContentLoader;
		BEGIN  (*{EXCLUSIVE}  ??*)
			IF ~pending THEN
				pending := TRUE;
				SELF.loadID := loadID;
				IF vc # NIL THEN
					RemoveContent(vc);
				END;
				AddContent(loadingText);
				Reset(SELF, NIL);
				AlignSubComponents();
				Invalidate();
				NEW(cl, SELF);
			END;
		END Load;

		PROCEDURE Loaded(sender, data : ANY);
		VAR
			msg : LoadedMsg;
			notifyMsg : NotifyMsg;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.Loaded, sender, data)
			ELSE
				RemoveContent(loadingText);
				msg := data(LoadedMsg);
				vc := msg.vc;
				AddContent(vc);
				NEW(notifyMsg);
				notifyMsg.url := msg.url;
				notifyMsg.title := msg.title;
				notifyMsg.loadID := loadID;
				notify(SELF, notifyMsg);
				Reset(SELF, NIL);
				AlignSubComponents();
				Invalidate();
				pending := FALSE;
			END;
		END Loaded;

		PROCEDURE LoadLink(sender, data : ANY);
		VAR
			link, target : String;
			targetLow : String;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.LoadLink, sender, data)
			ELSE
				DecodeLinkData(data, link, target);
				IF Strings.StartsWith2("#", link^) THEN
					(* TODO: notify WebBrowser.Window about new URL !! *)
				ELSE
					targetLow := Strings.LowerCaseInNew(target^);
					IF (target^ = "") OR (targetLow^ = "_self") OR (targetLow^ = "_top") OR (targetLow^ = "_parent") THEN
						IF loadLink # NIL THEN
							loadLink(SELF, data);
						ELSE
							url.Set(link);
							Load(-1);
						END;
					ELSE
						IF openNewWindow # NIL THEN
							openNewWindow(link);
						END;
					END;
				END;
			END;
		END LoadLink;

	END WebPanel;

	ContentLoader = OBJECT
	VAR
		webPanel : WebPanel;
		msg : LoadedMsg;
		vc : VisualComponent;
		url : String;
		title : String;
		encodedUrl: ARRAY 1024 OF CHAR;

		PROCEDURE &New*(webPanel : WebPanel);
		BEGIN
			SELF.webPanel := webPanel;
		END New;

	BEGIN {ACTIVE}
		NEW(msg);
		msg.url := webPanel.url.Get();
		IF verbose THEN KernelLog.String("ContentLoader: Loading: "); KernelLog.String(msg.url^); KernelLog.Ln; END;
		msg.vc := GetContent(msg.url, msg.title, webPanel.bounds.GetWidth(), webPanel.bounds.GetHeight(), TRUE, webPanel.LoadLink, NIL);
		webPanel.Loaded(SELF, msg);
		IF verbose THEN KernelLog.String("ContentLoader: Loading done."); KernelLog.Ln; END;
	END ContentLoader;

	HTMLPanel = OBJECT (VisualComponent)
	VAR
		rc : WebBrowserComponents.ResourceConnection;
		width : LONGINT;
		height : LONGINT;
		scrollbars : BOOLEAN;
		loadLink : WMEvents.EventListener;
		charset : String;
		frameName : String;
		firstResize : BOOLEAN;
		tv : WMTextView.TextView;
		text : Texts.Text;
		blankText : Texts.Text;
		vScrollbar : WMStandardComponents.Scrollbar;
		hScrollbar : WMStandardComponents.Scrollbar;
		scanner : HTMLScanner.Scanner;
		parser : HTMLParser.Parser;
		transformer : HTMLTransformer.Transformer;
		xmlDoc : XML.Document;
		textWriter : TextUtilities.TextWriter;
		bgImage : WebBrowserComponents.TileImagePanel;
		decoder : Codecs.TextDecoder;
		bbtDecoder : TextUtilities.BluebottleDecoder;
		encoder : Codecs.TextEncoder;
		res : LONGINT;
		contents: XMLObjects.Enumerator;
		content: ANY;
		framesetElem : XML.Element;
		frameset : FramesetPanel;
		titleElem : XML.Element;
		item : HTMLTransformer.EmbeddedObject;

		PROCEDURE &New*(VAR title : String; rc :WebBrowserComponents.ResourceConnection; width : LONGINT; height : LONGINT; scrollbars : BOOLEAN; loadLink : WMEvents.EventListener; charset : String; frameName : String);
		VAR
			sharpPos : LONGINT;
			wrp : WMTextView.LinkWrapper;
			sequencer : Messages.MsgSequencer;
		BEGIN
			Init;
			NEW(sequencer, Handle);
			SetSequencer(sequencer);
			takesFocus.Set(FALSE);
			SELF.rc := rc;
			SELF.width := width;
			SELF.height := height;
			SELF.scrollbars := scrollbars;
			SELF.loadLink := loadLink;
			SELF.charset := charset;
			SELF.frameName := frameName;
			alignment.Set(WMComponents.AlignClient);
			firstResize := TRUE;
			Load(title);
			(* doesn't work... *)
			sharpPos := Strings.LastIndexOfByte2("#", rc.url^);
			IF sharpPos # -1 THEN
				NEW(wrp);
				wrp.link := Strings.Substring2(sharpPos, rc.url^);
				tv.LinkClicked(SELF, wrp);
			END;
		END New;

		PROCEDURE Load(VAR title : String);
		BEGIN
			IF verbose THEN KernelLog.String("---Loading HTMLPanel. Url: "); KernelLog.String(rc.url^); KernelLog.Ln(); END;
			IF outputMode = modeSourceCode THEN
				decoder := Codecs.GetTextDecoder("ISO8859-1");
				decoder.Open(rc.reader, res);
				NEW(text);
				NEW(textWriter, text);
				encoder := Codecs.GetTextEncoder("UTF-8");
				encoder.Open(textWriter);
				encoder.WriteText(decoder.GetText(), res);
				textWriter.Update;
				(* Show *)
				NEW(vScrollbar);
				vScrollbar.alignment.Set(WMComponents.AlignRight);
				AddContent(vScrollbar);
				NEW(hScrollbar);
				hScrollbar.alignment.Set(WMComponents.AlignBottom);
				hScrollbar.vertical.Set(FALSE);
				AddContent(hScrollbar);
				NEW(tv);
				tv.alignment.Set(WMComponents.AlignClient);
				AddContent(tv);
				tv.SetScrollbars(hScrollbar, vScrollbar);
				tv.SetText(text);
				tv.firstLine.Set(0);
			ELSIF outputMode = modeParsedHtml THEN
				(* Parse the page *)
				NEW(scanner, rc.reader);
				NEW(parser, scanner);
				IF verbose THEN KernelLog.String("-Parsing "); KernelLog.String(rc.url^); KernelLog.Ln(); END;
				xmlDoc := parser.Parse();
				IF verbose THEN KernelLog.String("-Parsing done."); KernelLog.Ln(); END;
				NEW(text);
				NEW(textWriter, text);
				xmlDoc.Write(textWriter, NIL,  0);
				textWriter.Update;
				(* Show *)
				NEW(vScrollbar);
				vScrollbar.alignment.Set(WMComponents.AlignRight);
				AddContent(vScrollbar);
				NEW(hScrollbar);
				hScrollbar.alignment.Set(WMComponents.AlignBottom);
				hScrollbar.vertical.Set(FALSE);
				AddContent(hScrollbar);
				NEW(tv);
				tv.alignment.Set(WMComponents.AlignClient);
				AddContent(tv);
				tv.SetScrollbars(hScrollbar, vScrollbar);
				tv.SetText(text);
				tv.firstLine.Set(0);
			ELSIF outputMode = modeBbtXml THEN
				(* Parse the page *)
				NEW(scanner, rc.reader);
				NEW(parser, scanner);
				IF verbose THEN KernelLog.String("--Parsing "); KernelLog.String(rc.url^); KernelLog.Ln(); END;
				xmlDoc := parser.Parse();
				IF verbose THEN KernelLog.String("--Parsing done."); KernelLog.Ln(); END;
				(* Transform the document *)
				NEW(transformer, xmlDoc, rc.url, width, NIL, charset, NIL);
				xmlDoc := transformer.Transform();
				NEW(text);
				NEW(textWriter, text);
				xmlDoc.Write(textWriter, NIL, 0);
				textWriter.Update;
				(* Show *)
				NEW(vScrollbar);
				vScrollbar.alignment.Set(WMComponents.AlignRight);
				AddContent(vScrollbar);
				NEW(hScrollbar);
				hScrollbar.alignment.Set(WMComponents.AlignBottom);
				hScrollbar.vertical.Set(FALSE);
				AddContent(hScrollbar);
				NEW(tv);
				tv.alignment.Set(WMComponents.AlignClient);
				AddContent(tv);
				tv.SetScrollbars(hScrollbar, vScrollbar);
				tv.SetText(text);
				tv.firstLine.Set(0);
			ELSE (* outputMode = modeBbtText *)
				(* Parse the page *)
				NEW(scanner, rc.reader);
				NEW(parser, scanner);
				IF verbose THEN KernelLog.String("---Parsing "); KernelLog.String(rc.url^); KernelLog.Ln(); END;
				xmlDoc := parser.Parse();
				IF verbose THEN KernelLog.String("---Parsing done."); KernelLog.Ln(); END;
				(* Check for FRAMESET *)
				contents := xmlDoc.GetContents();
				WHILE contents.HasMoreElements() & (framesetElem = NIL) DO
					content := contents.GetNext();
					IF content IS XML.Element THEN
						framesetElem := GetElement("FRAMESET", content(XML.Element));
					END;
				END;
				IF framesetElem = NIL THEN
					(* Transform the document *)
					NEW(transformer, xmlDoc, rc.url, width, loadLink, charset, frameName);
					xmlDoc := transformer.Transform();
					title := transformer.title;
					fillColor.Set(transformer.pageBgColor * 0100H + 0FFH);
					IF transformer.bgImage # NIL THEN
						NEW(bgImage, NIL, transformer.bgImage);
						AddContent(bgImage);
					END;
					NEW(bbtDecoder);
					bbtDecoder.OpenXML(xmlDoc);
					text := bbtDecoder.GetText();
					(* Show *)
					NEW(tv);
					tv.alignment.Set(WMComponents.AlignClient);
					tv.onLinkClicked.Add(loadLink);
					IF scrollbars THEN
						NEW(vScrollbar);
						vScrollbar.alignment.Set(WMComponents.AlignRight);
						AddContent(vScrollbar);
						NEW(hScrollbar);
						hScrollbar.alignment.Set(WMComponents.AlignBottom);
						hScrollbar.vertical.Set(FALSE);
						AddContent(hScrollbar);
						tv.SetScrollbars(hScrollbar, vScrollbar);
					END;
					AddContent(tv);
					tv.SetText(text);
					tv.firstLine.Set(0);
				ELSE
					NEW(frameset, framesetElem, rc.url, width, height, loadLink);
					AddContent(frameset);
					contents := xmlDoc.GetContents();
					WHILE contents.HasMoreElements() & (titleElem = NIL) DO
						content := contents.GetNext();
						IF content IS XML.Element THEN
							titleElem := GetElement("TITLE", content(XML.Element));
						END;
					END;
					IF titleElem # NIL THEN
						title := NIL;
						contents := titleElem.GetContents();
						WHILE contents.HasMoreElements() & (title = NIL) DO
							content := contents.GetNext();
							IF content IS XML.ArrayChars THEN
								title := content(XML.ArrayChars).GetStr();
								Strings.TrimWS(title^);
								title := HTMLTransformer.TransformCharEnt(title);
							END;
						END;
					END;
				END;
			END;
			rc.Release();
		END Load;

		PROCEDURE Resized*;
		VAR
			item : HTMLTransformer.EmbeddedObject;
			width : LONGINT;
		BEGIN
			Resized^;
			(* ignore first resize, because webPanel is not drawn for the first time yet! *)
			IF firstResize THEN firstResize := FALSE; RETURN END;
			IF transformer # NIL THEN
				width := bounds.GetWidth();
				item := transformer.embeddedObjectsList;
				WHILE item # NIL DO
					IF item.object IS WebBrowserComponents.HR THEN
						item.object(WebBrowserComponents.HR).ParentTvWidthChanged(width);
					ELSIF item.object IS HTMLTransformer.Table THEN
						item.object(HTMLTransformer.Table).ParentTvWidthChanged(width);
					END;
					item := item.prev;
				END;
				IF tv # NIL THEN
					(* Resets the TextView, such that all embedded objects are new aligned! *)
					tv.SetText(text);
				END;
			END;
		END Resized;

	END HTMLPanel;

	FramesetPanel = OBJECT (VisualComponent)
	VAR
		framesetElem : XML.Element;
		baseAddress : String;
		width : LONGINT;
		height : LONGINT;
		loadLink : WMEvents.EventListener;
		frameborderSize : LONGINT;
		totalFixSizes : LONGINT;
		nodeIsCol : BOOLEAN;
		firstFrame : FrameNode;

		PROCEDURE &New*(framesetElem : XML.Element; baseAddress : String; width : LONGINT; height : LONGINT; loadLink : WMEvents.EventListener);
		BEGIN
			Init;
			SELF.framesetElem := framesetElem;
			SELF.baseAddress := baseAddress;
			SELF.width := width;
			SELF.height := height;
			SELF.loadLink := loadLink;
			takesFocus.Set(FALSE);
			alignment.Set(WMComponents.AlignClient);
			BuildFrameList();
			AddFramesToPanel();
		END New;

		PROCEDURE BuildFrameList;
		VAR
			frameItem : FrameNode;
			framesetItem : FramesetNode;
			url, dummyTitle : String;
			frameSlots : FrameslotNode;
			framesets : FramesetNode;
			slotItem : FrameslotNode;
			framesetPanel : FramesetPanel;
			fWidth, fHeight : LONGINT;
			lastFrame : FrameNode;
		BEGIN
			ParseFramesetAttr(framesetElem, frameSlots, frameborderSize, totalFixSizes, nodeIsCol);
			ParseFramesetContent(framesetElem, framesets);

			(* add frames and framesets to frame-list *)
			framesetItem := framesets;
			slotItem := frameSlots;
			WHILE (slotItem # NIL) & (framesetItem # NIL) DO
				NEW(frameItem);
				frameItem.name := framesetItem.name;
				frameItem.scrolling := framesetItem.scrolling;
				frameItem.size := slotItem.size;
				IF slotItem.type = typeFix THEN
					frameItem.relative := FALSE;
				ELSE
					frameItem.relative := TRUE;
				END;
				fWidth := GetFrameWidth(frameItem);
				fHeight := GetFrameHeight(frameItem);
				(* new frame or frameset *)
				IF framesetItem.frameset # NIL THEN
					NEW(framesetPanel, framesetItem.frameset, baseAddress, fWidth, fHeight, LoadLink);
					frameItem.panel := framesetPanel;
				ELSE
					IF (frameItem.name = NIL) OR (frameItem.name^ = "") THEN
						frameItem.name := GetNewFrameName();
					END;
					url := HTMLTransformer.ResolveAddress(baseAddress, framesetItem.src);
					frameItem.panel := GetContent(url, dummyTitle, fWidth, fHeight, frameItem.scrolling, LoadLink, frameItem.name);
				END;
				frameItem.isLast := FALSE;
				IF lastFrame # NIL THEN
					lastFrame.next := frameItem;
				ELSE
					firstFrame := frameItem;
				END;
				lastFrame := frameItem;

				slotItem := slotItem.next;
				framesetItem := framesetItem.next;
			END;
			IF lastFrame # NIL THEN
				lastFrame.isLast := TRUE;
			END;

			(* set frame alignment *)
			frameItem := firstFrame;
			WHILE frameItem # NIL DO
				AlignFrame(frameItem);
				frameItem := frameItem.next;
			END;
		END BuildFrameList;

		PROCEDURE GetFrameWidth(frameItem : FrameNode) : LONGINT;
		VAR
			fWidth : LONGINT;
		BEGIN
			(* calculate frame-width *)
			IF nodeIsCol THEN
				IF frameItem.relative THEN
					fWidth := ENTIER((width-totalFixSizes) / 100 * frameItem.size) - frameborderSize;
				ELSE
					fWidth := frameItem.size - frameborderSize;
				END;
			ELSE
				fWidth := width;
			END;
			IF fWidth < 1 THEN fWidth := 1 END;
			RETURN fWidth;
		END GetFrameWidth;

		PROCEDURE GetFrameHeight(frameItem : FrameNode) : LONGINT;
		VAR
			fHeight : LONGINT;
		BEGIN
			(* calculate frame-height *)
			IF ~nodeIsCol THEN
				IF frameItem.relative THEN
					fHeight := ENTIER((height-totalFixSizes) / 100 * frameItem.size) - frameborderSize;
				ELSE
					fHeight := frameItem.size - frameborderSize;
				END;
			ELSE
				fHeight := height;
			END;
			IF fHeight < 1 THEN fHeight := 1 END;
			RETURN fHeight;
		END GetFrameHeight;

		PROCEDURE AlignFrame(frameItem : FrameNode);
		VAR
			resizer: WMStandardComponents.Resizer;
		BEGIN
			IF ~frameItem.isLast THEN
				(* add resizer and set its width *)
				NEW(resizer);
				frameItem.panel.AddContent(resizer);
				IF nodeIsCol THEN
					resizer.alignment.Set(WMComponents.AlignRight);
					resizer.bounds.SetWidth(frameborderSize);
				ELSE
					resizer.alignment.Set(WMComponents.AlignBottom);
					resizer.bounds.SetHeight(frameborderSize);
				END;
				(* set frame alignment *)
				IF nodeIsCol THEN
					frameItem.panel.alignment.Set(WMComponents.AlignLeft);
				ELSE
					frameItem.panel.alignment.Set(WMComponents.AlignTop);
				END;
			ELSE
				(* set frame alignment for last frame*)
				frameItem.panel.alignment.Set(WMComponents.AlignClient);
			END;
		END AlignFrame;

		PROCEDURE Resize;
		VAR
			frameItem : FrameNode;
		BEGIN
			frameItem := firstFrame;
			WHILE frameItem # NIL DO
				IF nodeIsCol THEN
					IF frameItem.relative THEN
						frameItem.panel.bounds.SetWidth(ENTIER((width-totalFixSizes) / 100 * frameItem.size));
					ELSE
						frameItem.panel.bounds.SetWidth(frameItem.size);
					END;
				ELSE
					IF frameItem.relative THEN
						frameItem.panel.bounds.SetHeight(ENTIER((height-totalFixSizes) / 100 * frameItem.size));
					ELSE
						frameItem.panel.bounds.SetHeight(frameItem.size);
					END;
				END;
				frameItem := frameItem.next;
			END;
		END Resize;

		PROCEDURE Resized*;
		BEGIN
			width := bounds.GetWidth();
			height := bounds.GetHeight();
			Resize;
			Resized^;
		END Resized;

		PROCEDURE RemoveFramesFromPanel;
		VAR
			frameItem : FrameNode;
		BEGIN
			frameItem := firstFrame;
			WHILE frameItem # NIL DO
				RemoveContent(frameItem.panel);
				frameItem := frameItem.next;
			END;
		END RemoveFramesFromPanel;

		PROCEDURE AddFramesToPanel;
		VAR
			frameItem : FrameNode;
		BEGIN
			frameItem := firstFrame;
			WHILE frameItem # NIL DO
				AddContent(frameItem.panel);
				frameItem := frameItem.next;
			END;
			Resize();
		END AddFramesToPanel;

		PROCEDURE LoadLink(sender, data : ANY);
		VAR
			link, target, 	targetLow : String;
		BEGIN
			IF ~IsCallFromSequencer() THEN sequencer.ScheduleEvent(SELF.LoadLink, sender, data)
			ELSE
				DecodeLinkData(data, link, target);
				IF ~Strings.StartsWith2("#", link^) THEN
					targetLow := Strings.LowerCaseInNew(target^);
					IF (targetLow^ = "_parent") OR (targetLow^ = "_top") OR (targetLow^ = "_blank") THEN
						loadLink(NIL, data);
					ELSIF ~FindAndReloadFrame(link, target) THEN
						loadLink(NIL, data);
					END;
				END;
			END;
		END LoadLink;

		PROCEDURE FindAndReloadFrame(link, target : String) : BOOLEAN;
		VAR
			frameItem : FrameNode;
			framesetPanel : FramesetPanel;
			targetLow : String;
			url, dummyTitle : String;
			fWidth, fHeight : LONGINT;
		BEGIN
			frameItem := firstFrame;
			WHILE frameItem # NIL DO
				IF frameItem.name = NIL THEN
					(* frameItem is a frameset *)
					framesetPanel := frameItem.panel(FramesetPanel);
					IF framesetPanel.FindAndReloadFrame(link, target) THEN
						RETURN TRUE;
					END;
				ELSE
					(* frameItem is a frame *)
					targetLow := Strings.LowerCaseInNew(target^);
					IF (target^ = frameItem.name^) OR (targetLow^ = "_self") THEN
						RemoveFramesFromPanel();
						fWidth := GetFrameWidth(frameItem);
						fHeight := GetFrameHeight(frameItem);
						url := HTMLTransformer.ResolveAddress(baseAddress, link);
						frameItem.panel := GetContent(url, dummyTitle, fWidth, fHeight, frameItem.scrolling, LoadLink, frameItem.name);
						AlignFrame(frameItem);
						AddFramesToPanel;
						Reset(SELF, NIL);
						AlignSubComponents();
						Invalidate();
						RETURN TRUE;
					END;
				END;
				frameItem := frameItem.next;
			END;
			RETURN FALSE;
		END FindAndReloadFrame;

	END FramesetPanel;


VAR
	frameNameCount : LONGINT;

PROCEDURE GetContent(VAR url : String; VAR title : String; initWidth : LONGINT; initHeight : LONGINT; scrollbars : BOOLEAN; loadLink : WMEvents.EventListener; frameName : String) : VisualComponent;
VAR
	rc : WebBrowserComponents.ResourceConnection;
	panel : VisualComponent;
	errorText : WebBrowserComponents.ShortText;
	image : WebBrowserComponents.StretchImagePanel;
	htmlPanel : HTMLPanel;
	textPanel : WebBrowserComponents.TextPanel;
	s : String;
	charset : String;
	charsetPos : LONGINT;
BEGIN

	rc := WebBrowserComponents.GetResourceConnection(url);
	IF rc = NIL THEN
		IF verbose THEN KernelLog.String("Not found: "); KernelLog.String(url^); KernelLog.Ln; END;
		s := Strings.ConcatToNew("   Not found: ", url^);
		NEW(errorText, s^);
		panel := errorText;
	ELSE
		url := rc.url;
		IF Strings.StartsWith2("text/html", rc.mimeType^) OR (rc.mimeType^ = "") THEN
			s := Strings.LowerCaseInNew(rc.mimeType^);
			IF Strings.Pos("charset", s^) >= 0 THEN
				charsetPos := Strings.IndexOfByte('=', charsetPos, rc.mimeType^) + 1;
				IF (charsetPos >= 0) & (charsetPos < Strings.Length(rc.mimeType^)) THEN
					charset := Strings.Substring2(charsetPos, rc.mimeType^);
					Strings.TrimWS(charset^);
				END;
			END;
			NEW(htmlPanel, title, rc, initWidth, initHeight, scrollbars, loadLink, charset, frameName);
			panel := htmlPanel;
		ELSIF Strings.StartsWith2("text/plain", rc.mimeType^) OR Strings.StartsWith2("application/xml", rc.mimeType^) THEN
			NEW(textPanel, rc, NIL);
			panel := textPanel;
		ELSIF Strings.StartsWith2("image/", rc.mimeType^) THEN
			NEW(image, rc, NIL, -1, -1);
			panel := image;
		ELSE
			IF verbose THEN KernelLog.String("Unknown content type: "); KernelLog.String(rc.mimeType^); KernelLog.Ln; END;
			s := Strings.ConcatToNew("   Unknown content type: ", rc.mimeType^);
			NEW(errorText, s^);
			panel := errorText;
			rc.Stop();
			rc.Release();
		END;
	END;
	RETURN panel;
END GetContent;

PROCEDURE DecodeLinkData*(data : ANY; VAR link : String; VAR target : String);
VAR
	linkValue : String;
	urlPos, len : LONGINT;
BEGIN
	linkValue := data(WMTextView.LinkWrapper).link;
	IF Strings.StartsWith2("#", linkValue^) THEN
		link := linkValue;
		target := Strings.NewString("_self");
	ELSE
		urlPos := Strings.Pos(";url=", linkValue^);
		target := Strings.Substring(7, urlPos, linkValue^);
		len := Strings.Length(linkValue^);
		IF len > (urlPos + 5) THEN
			link := Strings.Substring(urlPos + 5, len, linkValue^);
		ELSE
			link := Strings.NewString("");
		END;
	END;
END DecodeLinkData;

PROCEDURE GetElement(name : ARRAY OF CHAR; root : XML.Element) : XML.Element;
VAR
	rootName : String;
	contents: XMLObjects.Enumerator;
	content: ANY;
	retElement: XML.Element;
BEGIN
	IF root = NIL THEN RETURN NIL; END;
	rootName := root.GetName();
	IF rootName^ = name THEN RETURN root; END;
	contents := root.GetContents();
	WHILE contents.HasMoreElements() & (retElement = NIL) DO
		content := contents.GetNext();
		IF content IS XML.Element THEN
			retElement := GetElement(name, content(XML.Element));
		END;
	END;
	RETURN retElement;
END GetElement;

PROCEDURE ParseFramesetAttr(frameset : XML.Element; VAR frameSlots : FrameslotNode; VAR frameborderSize : LONGINT; VAR fixSizes : LONGINT; VAR nodeIsCol : BOOLEAN);
VAR
	s : String;
	rowsNode : FrameslotNode;
	colsNode : FrameslotNode;
	rowsCount : LONGINT;
	colsCount : LONGINT;
	rowsfixSizes : LONGINT;
	colsfixSizes : LONGINT;
BEGIN
	rowsCount := 0;
	colsCount := 0;
	s := HTMLTransformer.GetElemAttributeValue(frameset, "rows", FALSE);
	IF s # NIL THEN
		ParseFramesetRowsOrCols(s, rowsNode, rowsCount, rowsfixSizes);
	END;
	s := HTMLTransformer.GetElemAttributeValue(frameset, "cols", FALSE);
	IF s # NIL THEN
		ParseFramesetRowsOrCols(s, colsNode, colsCount, colsfixSizes);
	END;
	IF (rowsCount = 0) & (colsCount = 0) THEN
		NEW(frameSlots);
		fixSizes := 0;
		nodeIsCol := FALSE;
		frameSlots.size := 100;
		frameSlots.type := typePercent;
	ELSIF rowsCount >= colsCount THEN
		frameSlots := rowsNode;
		fixSizes := rowsfixSizes;
		nodeIsCol := FALSE;
	ELSE
		frameSlots := colsNode;
		fixSizes := colsfixSizes;
		nodeIsCol := TRUE;
	END;

	(* frameborder-width *)
	frameborderSize := 6;
	s := HTMLTransformer.GetElemAttributeValue(frameset, "frameborder", FALSE);
	IF s # NIL THEN
		Strings.TrimWS(s^);
		Strings.StrToInt(s^, frameborderSize);
	ELSE
		s := HTMLTransformer.GetElemAttributeValue(frameset, "border", FALSE);
		IF s # NIL THEN
			Strings.TrimWS(s^);
			Strings.StrToInt(s^, frameborderSize);
		END;
	END;

END ParseFramesetAttr;

PROCEDURE ParseFramesetRowsOrCols(attrValue : String; VAR firstSlot : FrameslotNode; VAR nodeCount : LONGINT; VAR fixSizes : LONGINT);
VAR
	start : LONGINT;
	comma : LONGINT;
	s : String;
	sizeStr : String;
	size : LONGINT;
	type : LONGINT;
	slotItem : FrameslotNode;
	lastSlot : FrameslotNode;
	prevSlot : FrameslotNode;
	percents : LONGINT;
	parts : LONGINT;
	factor : REAL;
	onePart : LONGINT;
BEGIN
	percents := 0;
	parts := 0;
	fixSizes := 0;
	firstSlot := NIL;

	start := 0;
	REPEAT
		comma := Strings.IndexOfByte(',', start, attrValue^);
		IF comma = -1 THEN
			s := Strings.Substring2(start, attrValue^);
		ELSE
			s := Strings.Substring(start, comma, attrValue^);
			start := comma+1;
		END;
		Strings.TrimWS(s^);
		IF Strings.EndsWith("%", s^) THEN
			sizeStr := Strings.Substring(0, Strings.Length(s^)-1, s^);
			Strings.StrToInt(sizeStr^, size);
			type := typePercent;
		ELSIF Strings.EndsWith("*", s^) THEN
			IF Strings.Length(s^) = 1 THEN
				size := 1;
			ELSE
				sizeStr := Strings.Substring(0, Strings.Length(s^)-1, s^);
				Strings.TrimWS(sizeStr^);
				Strings.StrToInt(sizeStr^, size);
			END;
			type := typeParts;
		ELSE
			Strings.StrToInt(s^, size);
			type := typeFix;
		END;
		IF size > 0 THEN
			NEW(slotItem);
			slotItem.size := size;
			slotItem.type := type;
			IF type = typePercent THEN
				percents := percents + size;
			ELSIF type = typeParts THEN
				parts := parts + size;
			ELSE
				fixSizes := fixSizes + size;
			END;
			IF lastSlot # NIL THEN
				lastSlot.next := slotItem;
				lastSlot := slotItem;
			ELSE
				firstSlot := slotItem;
				lastSlot := slotItem;
			END;
		END;
	UNTIL comma = -1;

	IF (percents > 100) OR (parts = 0) THEN
		IF percents > 0 THEN
			factor := 100 / percents;
		END;
		onePart := 0;
	ELSE
		factor := 1;
		onePart := ENTIER((100 - percents) / parts);
	END;

	nodeCount := 0;
	slotItem := firstSlot;
	prevSlot := NIL;
	WHILE slotItem # NIL DO
		IF slotItem.type = typePercent THEN
			slotItem.size := ENTIER(slotItem.size * factor);
		ELSIF slotItem.type = typeParts THEN
			slotItem.size := slotItem.size * onePart;
		END;
		IF slotItem.size = 0 THEN
			IF prevSlot # NIL THEN
				prevSlot.next := slotItem.next;
			ELSE
				(* prevSlot remains NIL *)
				firstSlot := slotItem.next;
			END;
		ELSE
			INC(nodeCount);
			prevSlot := slotItem;
		END;
		slotItem := slotItem.next;
	END;

END ParseFramesetRowsOrCols;

PROCEDURE ParseFramesetContent(frameset : XML.Element; VAR first : FramesetNode);
VAR
	last : FramesetNode;
	node : FramesetNode;
	enum : XMLObjects.Enumerator;
	p : ANY;
	frame : XML.Element;
	name : String;
	s : String;
BEGIN
	first := NIL;
	last := NIL;
	enum := frameset.GetContents();
	WHILE enum.HasMoreElements() DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			frame := p(XML.Element);
			name := frame.GetName();
			IF name^ = "FRAMESET" THEN
				NEW(node);
				node.frameset := frame;
				IF last # NIL THEN
					last.next := node;
					last := node;
				ELSE
					first := node;
					last := node;
				END;
			ELSIF name^ = "FRAME" THEN
				s := HTMLTransformer.GetElemAttributeValue(frame, "src", FALSE);
				IF s # NIL THEN
					Strings.TrimWS(s^);
					IF s^ # "" THEN
						NEW(node);
						node.src := s;
						s := HTMLTransformer.GetElemAttributeValue(frame, "name", FALSE);
						IF s # NIL THEN
							Strings.TrimWS(s^);
							node.name := s;
						END;
						node.scrolling := TRUE;
						s := HTMLTransformer.GetElemAttributeValue(frame, "scrolling", TRUE);
						IF s # NIL THEN
							Strings.TrimWS(s^);
							IF s^ = "no" THEN
								node.scrolling := FALSE;
							END;
						END;
						IF last # NIL THEN
							last.next := node;
							last := node;
						ELSE
							first := node;
							last := node;
						END;
					END;
				END;
			END;
		END;
	END;
END ParseFramesetContent;

PROCEDURE GetNewFrameName() : String;
VAR
	id : ARRAY 28 OF CHAR;
	nr : ARRAY 8 OF CHAR;
BEGIN {EXCLUSIVE}
	id := "BimBrowser-Frame-ID-";
	Strings.IntToStr(frameNameCount, nr);
	Strings.Append(id, nr);
	INC(frameNameCount);
	RETURN Strings.NewString(id);
END GetNewFrameName;

BEGIN
	frameNameCount := 0;
END WebBrowserPanel.
