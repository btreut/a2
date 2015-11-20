MODULE DynamicWebpagePlugin; (** AUTHOR "Luc Blaeser"; PURPOSE "HTTP Webserver Plugin for Dynamic Webpages"; *)

IMPORT
	DynamicWebpage, HTTPSupport, HTTPSession, WebHTTP, WebHTTPServer, Files, Dates, Strings, Streams, Commands,
	KernelLog, XML, XMLScanner, XMLParser, XMLObjects, DynamicStrings, TFClasses, Configuration, Modules;

CONST
	DEBUG = FALSE; (* disply debug information *)
	ShowRegisteredElements = FALSE; (* show all registered active elements *)

	PluginName = "Dynamic Webpage Plugin";

	PreTransformation = TRUE;
	PostTransformation = FALSE;

	MaxTransformationDepth = 40; (* maxmimum number of recursive steps to transform a transformation result *)
	DocType = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">';

TYPE
	DynamicWebpagePlugin = OBJECT (WebHTTPServer.HTTPPlugin)
		PROCEDURE &Init*(CONST name: WebHTTPServer.Name);
		BEGIN
			Init^(PluginName)
		END Init;

		PROCEDURE CanHandle(host: WebHTTPServer.Host; VAR request: WebHTTP.RequestHeader; secure : BOOLEAN) : BOOLEAN;
		VAR name, ext: Files.FileName; f: Files.File; newuri : ARRAY 4096 OF CHAR;
		BEGIN
			HTTPSupport.RemoveVariablesFromURI(request.uri, newuri);
			IF (request.method IN {WebHTTP.GetM, WebHTTP.PostM, WebHTTP.HeadM}) THEN
				IF (newuri[Strings.Length(newuri)-1] = "/") THEN (* check for default webpage "index.dxp" *)
					COPY(host.prefix, name); Strings.Append(name, newuri);
					Strings.Append(name, DynamicWebpage.DefaultWebpage);
					f := Files.Old(name);
					RETURN (f # NIL)
				ELSE
					Files.SplitExtension(newuri, name, ext);
					Strings.UpperCase(ext);
					RETURN (ext = DynamicWebpage.DynamicWebpageExtension)
				END
			ELSE
				RETURN FALSE
			END
		END CanHandle;

		PROCEDURE Handle*(host: WebHTTPServer.Host; VAR requestHeader: WebHTTP.RequestHeader; VAR reply: WebHTTP.ResponseHeader;
				VAR in: Streams.Reader; VAR out: Streams.Writer);
		VAR chunker: WebHTTP.ChunkedOutStream; w: Streams.Writer; f: Files.File; backupUri: ARRAY 4096 OF CHAR;
			request: HTTPSupport.HTTPRequest; session: HTTPSession.Session;
		BEGIN
			(* requestHeader.method IN {WebHTTP.GetM, WebHTTP.PostM, WebHTTP.HeadM} *)
			NEW(request, requestHeader, in);

			WebHTTP.SetAdditionalFieldValue(requestHeader.additionalFields, "If-Modified-Since", " ");   (* prohibit conditional get for dynamic webpages  *)
			WebHTTPServer.GetDefaultResponseHeader(requestHeader, reply);
			IF (request.shortUri[Strings.Length(request.shortUri)-1] = "/") THEN (* get default webpage "index.dxp" in a directory *)
				Strings.Append(request.shortUri, DynamicWebpage.DefaultWebpage);
				Strings.Concat("http://", requestHeader.host, reply.contentlocation);
				Strings.Append(reply.contentlocation, request.shortUri);
			END;

			(* LocateResource works only with variable-free URI in requestHeader *)
			COPY(requestHeader.uri, backupUri); COPY(request.shortUri, requestHeader.uri);
			LocateResource(host, requestHeader, reply, f); (* sets also reply.statuscode *)
			COPY(backupUri, requestHeader.uri);

			IF ((f # NIL) & ((reply.statuscode = WebHTTP.OK) OR (reply.statuscode = WebHTTP.NotModified))) THEN
				reply.statuscode := WebHTTP.OK;
				Strings.FormatDateTime(WebHTTP.DateTimeFormat, Dates.Now(), reply.lastmodified); (* dynamic webpages have no last modified *)
				WebHTTP.SetAdditionalFieldValue(reply.additionalFields, "Expires", reply.lastmodified);
					(* deny web caching; Expires=0 is illegal but often used to deny web caching *)
				WebHTTP.SetAdditionalFieldValue(reply.additionalFields, "Pragma", "no-cache");  (* deny web caching *)
				COPY("text/html", reply.contenttype); (* result is XHTML *)

				NEW(chunker, w, out, requestHeader, reply);
				WebHTTP.SendResponseHeader(reply, out);

				session := HTTPSession.GetSession(request);
				session.IncreaseLifeTime;

				(* detect whether the user has used the back or refresh button of the navigation bar *)
				IF (BackRefreshButtonWasPressed(request, session)) THEN
					HandleBackRefreshButtonError(request, w)
				ELSE
					HandleClientAction(request); (* first handle a client event *)

					IF ((requestHeader.method = WebHTTP.GetM) OR (requestHeader.method = WebHTTP.PostM)) THEN
						GenerateDynamicWebpage(f, request, w)
					END
				END;
				chunker.Close
			ELSIF (reply.statuscode = WebHTTP.ObjectMoved) THEN
				NEW(chunker, w, out, requestHeader, reply);
				WebHTTP.SendResponseHeader(reply, out);

				w.String(DocType); w.Ln;
				w.String("<html><head><title>Document Moved</title></head>"); w.Ln;
				w.String('<body><h1>Document Moved</h1>This document may be found <a href="http://');
				w.String(requestHeader.uri); w.String(">here</a>.<hr/><address>");
				w.String(WebHTTPServer.ServerVersion); w.String("</address></body></html>"); w.Ln;
				w.Update;
				chunker.Close
			ELSIF ((reply.statuscode = WebHTTP.NotFound) OR (f = NIL)) THEN
				reply.statuscode := WebHTTP.NotFound;
				NEW(chunker, w, out, requestHeader, reply);
				WebHTTP.SendResponseHeader(reply, out);

				w.String(DocType); w.Ln;
				w.String("<html><head><title>404 - Not Found</title></head>");
				w.String("<body>HTTP 404 - File Not Found<hr/><address>");
				w.String(WebHTTPServer.ServerVersion); w.String("</address></body></html>");
				w.Ln;
				w.Update;
				chunker.Close
			ELSE
				reply.statuscode := WebHTTP.NotImplemented;
				WebHTTP.WriteStatus(reply, out)
			END
		END Handle;
	END DynamicWebpagePlugin;

	ParserError = POINTER TO RECORD
		pos, line, row: LONGINT;
		msg: ARRAY 1024 OF CHAR
	END;

	SessionStateFullElement = OBJECT
		VAR
			(* each statefull object instance is identified by an object id (constructed out of file and explicit id in xml representation) *)
			objectId: Strings.String;
			session: HTTPSession.Session;
			activeElem: DynamicWebpage.StateFullActiveElement;
			eventHandlers: DynamicWebpage.EventHandlerList;

		PROCEDURE &Init*(id: Strings.String; sess: HTTPSession.Session; elem: DynamicWebpage.StateFullActiveElement;
			handlerList : DynamicWebpage.EventHandlerList);
		BEGIN (* id # NIL & sess # NIL & elem # NIL *)
			NEW(objectId, LEN(id)); COPY(id^, objectId^);
			session := sess; activeElem := elem; eventHandlers:= handlerList
		END Init;
	END SessionStateFullElement;

	(* Abstracts the creation and delegation to a statefull or stateless active element instances.
	    The type of the active element (stateless or statefull) is defined by the creation on the first access
	    Stateless active elements are singleton and used by all sessions. Statefull active elements belong
	    to exactly one session and have multiple instances identified explicitly by the webpage file and
	    an "id" attribute in the XML representation. *)
	ActiveElementFactory = OBJECT
		VAR
			moduleName: ARRAY 128 OF CHAR;
			activeElemDesc: DynamicWebpage.ActiveElementDescriptor;

			(* used if it is a stateless active element, otherwise NIL *)
			stateLessActiveElem: DynamicWebpage.StateLessActiveElement; (* singleton *)
			stateLessEventHandlers: DynamicWebpage.EventHandlerList;

			(* used if it is a statefull active element, otherwise NIL *)
			stateFullActiveElems: TFClasses.List; (* List of SessionStateFullElement *)

		PROCEDURE &Init*(module: Strings.String; desc: DynamicWebpage.ActiveElementDescriptor);
		BEGIN
			ASSERT(module # NIL); ASSERT(desc # NIL); ASSERT(desc.factory # NIL);
			COPY(module^, moduleName); activeElemDesc := desc
		END Init;

		PROCEDURE SessionExpired(session: HTTPSession.Session);
		VAR sessionElem: SessionStateFullElement; expElemList: TFClasses.List; (* List of SessionStateFullElement *)
			i : LONGINT; p: ANY;
		BEGIN {EXCLUSIVE}
			(* there could be multiple instances of a statefull active element belonging to session *)
			NEW(expElemList);
			stateFullActiveElems.Lock;
			FOR i := 0 TO stateFullActiveElems.GetCount()-1 DO
				p := stateFullActiveElems.GetItem(i); sessionElem := p(SessionStateFullElement); (* sessionElem # NIL *)
				IF (sessionElem.session = session) THEN
					expElemList.Add(sessionElem)
				END
			END;
			stateFullActiveElems.Unlock;
			FOR i:= 0 TO expElemList.GetCount()-1 DO
				p := expElemList.GetItem(i);
				stateFullActiveElems.Remove(p)
			END;
			IF (DEBUG) THEN
				KernelLog.String("Statefull active element instances '"); KernelLog.String(activeElemDesc.elementName);
				KernelLog.String("' in module '"); KernelLog.String(moduleName); KernelLog.String("' have been freed for session '");
				KernelLog.String(session.sessionId); KernelLog.String("'."); KernelLog.Ln
			END
		END SessionExpired;

		(* must be called before disposing the object *)
		PROCEDURE PrepareDisposal;
		BEGIN
			IF (stateFullActiveElems # NIL) THEN (* contains statefull active element *)
				HTTPSession.RemoveExpirationHandler(SessionExpired)
			END
		END PrepareDisposal;

		(* objectId is only used if a statefull active element is requested, otherwise objectId can be NIL *)
		PROCEDURE GetElementInstance(session : HTTPSession.Session; objectId: Strings.String) : DynamicWebpage.ActiveElement;
		VAR i: LONGINT; p: ANY; sessionElem: SessionStateFullElement; elem: DynamicWebpage.ActiveElement;
			stateFullElem: DynamicWebpage.StateFullActiveElement; eventHandlerList: DynamicWebpage.EventHandlerList;
		BEGIN {EXCLUSIVE}
			IF (stateLessActiveElem # NIL) THEN (* it is a stateless active element *)
				RETURN stateLessActiveElem
			ELSIF (stateFullActiveElems # NIL) THEN (* it is a statefull active element *)
				IF (objectId # NIL) THEN
					stateFullActiveElems.Lock;
					FOR i := 0 TO stateFullActiveElems.GetCount()-1 DO
						p := stateFullActiveElems.GetItem(i); sessionElem := p(SessionStateFullElement);
						(* sessionElem # NIL & sessionElem.objectId # NIL *)
						IF ((sessionElem.session = session) & (sessionElem.objectId^ = objectId^)) THEN
							stateFullActiveElems.Unlock;
							RETURN sessionElem.activeElem;
						END
					END;
					stateFullActiveElems.Unlock;
					(* create a new statefull element *)
					elem := activeElemDesc.factory();
					(* elem # NIL since there was already a statefull element instance created by this factory method *)
					stateFullElem := elem(DynamicWebpage.StateFullActiveElement);
					eventHandlerList := elem.GetEventHandlers();
					NEW(sessionElem, objectId, session, stateFullElem, eventHandlerList);
					stateFullActiveElems.Add(sessionElem);
					RETURN elem
				ELSE
					KernelLog.String("Dynamic Webpage Plugin: The statefull active element '");
					KernelLog.String(activeElemDesc.elementName); KernelLog.String("' in module '");
					KernelLog.String(moduleName); KernelLog.String("' must be used together with an id in a webpage file.");
					KernelLog.Ln;
					RETURN NIL
				END
			ELSE (* it is not yet determined if it is a statefull or stateless active element *)
				elem := activeElemDesc.factory();
				IF (elem # NIL) THEN
					IF (elem IS DynamicWebpage.StateFullActiveElement) THEN
						IF (objectId # NIL) THEN
							(* initialize as statefull active element factory *)
							NEW(stateFullActiveElems);
							HTTPSession.AddExpirationHandler(SessionExpired);

							stateFullElem := elem(DynamicWebpage.StateFullActiveElement);
							eventHandlerList := elem.GetEventHandlers();
							NEW(sessionElem, objectId, session, stateFullElem, eventHandlerList);
							stateFullActiveElems.Add(sessionElem);
							RETURN stateFullElem
						ELSE
							KernelLog.String("Dynamic Webpage Plugin: The statefull active element '");
							KernelLog.String(activeElemDesc.elementName); KernelLog.String("' in module '");
							KernelLog.String(moduleName); KernelLog.String("' must be used together with an attribute '");
							KernelLog.String(DynamicWebpage.XMLAttributeObjectIdName); KernelLog.String("'.");
							KernelLog.Ln;
							RETURN NIL
						END
					ELSIF (elem IS DynamicWebpage.StateLessActiveElement) THEN
						(* initialize as stateless active element factory *)
						stateLessActiveElem := elem(DynamicWebpage.StateLessActiveElement);
						stateLessEventHandlers := elem.GetEventHandlers();
						RETURN elem
					ELSE (* elem IS DynamicWebpage.ActiveElement *)
						KernelLog.String("Dynamic Webpage Plugin: The active element '");
						KernelLog.String(activeElemDesc.elementName); KernelLog.String("' in module '");
						KernelLog.String(moduleName); KernelLog.String("' must be either a stateless or statefull active element.");
						KernelLog.Ln;
						RETURN NIL
					END
				ELSE
					KernelLog.String("Dynamic Webpage Plugin: Invalid result from the factory for the active element '");
					KernelLog.String(activeElemDesc.elementName); KernelLog.String("' in module '");
					KernelLog.String(moduleName); KernelLog.String("'"); KernelLog.Ln;
					RETURN NIL
				END
			END
		END GetElementInstance;

		(* objectId is only used for statefull activ elements and is NIL  in case of stateless active elements *)
		PROCEDURE FindEventHandler(session: HTTPSession.Session; objectId: Strings.String; CONST handlerName: ARRAY OF CHAR) : DynamicWebpage.EventHandler;
		VAR elem: DynamicWebpage.ActiveElement; sessionElem: SessionStateFullElement; p: ANY; i : LONGINT;

			PROCEDURE GetEventHandlerFromList(eventList: DynamicWebpage.EventHandlerList) : DynamicWebpage.EventHandler;
			VAR j: LONGINT;
			BEGIN
				IF (eventList # NIL) THEN
					FOR j := 0 TO LEN(eventList^)-1 DO
						IF (eventList[j] # NIL) THEN
							IF (eventList[j].methodName = handlerName) THEN
								RETURN eventList[j].handler
							END
						ELSE
							KernelLog.String("Dynamic Webpage Plugin: The "); KernelLog.Int(j, 0);
							KernelLog.String(".th event handler is not defined in the event handler list in the active element '");
							KernelLog.String(activeElemDesc.elementName); KernelLog.String("' in module '");
							KernelLog.String(moduleName); KernelLog.String("'"); KernelLog.Ln
						END
					END
				END;
				RETURN NIL
			END GetEventHandlerFromList;

		BEGIN
			elem := GetElementInstance(session, objectId); (* this guarantees that the needed active element instance is now present *)
			IF ((elem # NIL) & (elem IS DynamicWebpage.StateLessActiveElement)) THEN (* it is a stateless active element *)
				RETURN GetEventHandlerFromList(stateLessEventHandlers)
			ELSIF ((objectId # NIL) & (elem # NIL) & (elem IS DynamicWebpage.StateFullActiveElement)) THEN (* it is a statefull active element *)
				(* stateFullActiveElems # NIL by GetElementInstance *)
				stateFullActiveElems.Lock;
				FOR i := 0 TO stateFullActiveElems.GetCount()-1 DO
					p := stateFullActiveElems.GetItem(i); sessionElem := p(SessionStateFullElement); (* sessionElem # NIL *)
					IF ((sessionElem.session = session) & (sessionElem.objectId^ = objectId^)) THEN
						stateFullActiveElems.Unlock;
						RETURN GetEventHandlerFromList(sessionElem.eventHandlers);
					END
				END;
				stateFullActiveElems.Unlock;
				RETURN NIL
			ELSE (* error message already displayed by GetElementInstance *)
				RETURN NIL
			END
		END FindEventHandler;

	END ActiveElementFactory;

	VAR
		dynamicPagePlugin: DynamicWebpagePlugin; (* singleton instance to be able to uninstall *)
		lockServingHosts: BOOLEAN; (* lock hold when operating on servingHosts *)
		servingHosts: TFClasses.List; (* List of WebHTTPServer.Host *)
		registeredActiveElemFact: TFClasses.List; (* List of ActiveElementFactory *)
		parserError: ParserError; (* since there is no DELEGATE for the reportErrorHandler XML-Module possible *)

	(* Returns true iff back or refresh button was pressed and increases the state counter if back button was not pressed *)
	PROCEDURE BackRefreshButtonWasPressed(request: HTTPSupport.HTTPRequest; session: HTTPSession.Session) : BOOLEAN;
	VAR httpVar: HTTPSupport.HTTPVariable; httpCounter, sessionCounter: LONGINT; p: ANY;
		dynStr: DynamicStrings.DynamicString; str: Strings.String; numberStr: ARRAY 14 OF CHAR;
	BEGIN (* request # NIL & session # NIL *)
		httpVar := request.GetVariableByName(DynamicWebpage.StateCounterVariable);
		httpCounter := 0;
		IF (httpVar # NIL) THEN
			Strings.StrToInt(httpVar.value, httpCounter);
			p := session.GetVariableValue(DynamicWebpage.StateCounterVariable);
			IF ((p # NIL) & (p IS DynamicStrings.DynamicString)) THEN
				dynStr := p(DynamicStrings.DynamicString); str := dynStr.ToArrOfChar(); (* str # NIL *)
				Strings.StrToInt(str^, sessionCounter);
				IF (httpCounter < sessionCounter) THEN
					RETURN TRUE
				END
			END
		END;
		INC(sessionCounter);
		Strings.IntToStr(sessionCounter, numberStr); NEW(dynStr); dynStr.Append(numberStr);
		session.AddVariableValue(DynamicWebpage.StateCounterVariable, dynStr);
		RETURN FALSE
	END BackRefreshButtonWasPressed;

	(* handle the case that the user has used the back button of the browser's navigation bar *)
	PROCEDURE HandleBackRefreshButtonError(request: HTTPSupport.HTTPRequest; w: Streams.Writer);
	VAR sessionId: HTTPSession.SessionId;
	BEGIN
		HTTPSession.GetSessionId(request, sessionId);
		w.String(DocType); w.Ln;
		w.String("<html><head><title>Do not use the back or refresh button</title></head>"); w.Ln;
		w.String("<body><h1>Do not use the back or refresh button in the navigation bar</h1>");
		w.String("Using the back or refresh button in the navigation bar of this browser is not allowed when using dynamic ");
		w.String("webpages.<br/>To continue click ");w.String('<a href="');
		w.String(request.shortUri); w.String("?");
		w.String(HTTPSession.HTTPVarSessionIdName); w.String("="); w.String(sessionId);
		w.String('">here</a>.<hr/><address>'); w.String(WebHTTPServer.ServerVersion);
		w.String("</address></body></html>"); w.Ln;
		w.Update;
	END HandleBackRefreshButtonError;

	PROCEDURE GenerateDynamicWebpage(f: Files.File; request: HTTPSupport.HTTPRequest; w: Streams.Writer);
	VAR scanner: XMLScanner.Scanner; parser: XMLParser.Parser; doc: XML.Document;
		root: XML.Element; rootContent: XML.Content; errormsg: ARRAY 1024 OF CHAR;
		reader : Files.Reader;
	BEGIN  (* f # NIL *)
		NEW(reader, f, 0);
		NEW(scanner, reader);
		NEW(parser, scanner);
		scanner.reportError := ReportXMLParserScannerError;
		parser.reportError := ReportXMLParserScannerError;
		BEGIN {EXCLUSIVE}
			(* the error handler needs additional information about the file and writer but is not a delegate *)
			parserError := NIL;
			doc := parser.Parse();
			IF (parserError # NIL) THEN
				Strings.Concat("Error while parsing: ", parserError.msg, errormsg);
				ReportGeneratorError(f, w, parserError.pos, parserError.line, parserError.row, errormsg);
				doc := NIL
			END
		END;

		IF doc # NIL THEN
			rootContent := doc;
			IF (TransformXMLTree(f, rootContent, request, 0, w)) THEN (* transformation worked successfully *)
				(* SetDocument should be provided by the XML module *)
				IF (rootContent IS XML.Element) THEN
					root := rootContent(XML.Element);
				ELSE
				    (* Error "transformation result has not a root element"*)
				END;
				w.String(DocType); w.Ln;
				doc.Write(w, NIL, 0); (* externalize transformation result *)
			END
		END;
		w.Update
	END GenerateDynamicWebpage;

	(* returns true iff the transformation worked without an error *)
	PROCEDURE TransformXMLTree(file: Files.File; VAR n: XML.Content; VAR request: HTTPSupport.HTTPRequest;
		transformationDepth: INTEGER;  w: Streams.Writer) : BOOLEAN;
	VAR enum, resultEnum: XMLObjects.Enumerator; pChild, pResultChild: ANY; elem: XML.Element;
		child, newChild, resultChild: XML.Content; errormsg: ARRAY 256 OF CHAR; wasTransformed: BOOLEAN;
		elemName : Strings.String; container, snapshot, resultContainer: XML.Container;
	BEGIN
		IF ((n # NIL) & (n IS XML.Element) & (transformationDepth > MaxTransformationDepth)) THEN
			elem := n(XML.Element); elemName := elem.GetName();
			Strings.Concat("In element '", elemName^, errormsg);
			Strings.Append(errormsg, "': Maximum recursive transformation steps reached. There could be an endless loop in a transformation procedure.");
			ReportGeneratorError(file, w, elem.GetPos(), 0, 0, errormsg);
			KernelLog.String("Error in Stream: "); KernelLog.String(errormsg); KernelLog.Ln;
			RETURN FALSE (* stop the further traversal *)
		ELSIF ((n # NIL) & (n IS XML.Container)) THEN
			(* pre-postorder traversal with recursive traversal of the post transformation result
			    increase transformation depth only if it is a transformation of the transformation result *)
			wasTransformed := FALSE;

			(* pre transformation *)
			IF (n IS XML.Element) THEN
				elem := n(XML.Element);
				IF (IsActive(elem))THEN
					IF (~TransformActiveElement(file, n, PreTransformation, request, w)) THEN RETURN FALSE END;
					wasTransformed := TRUE
				END
			END;

			IF ((n # NIL) & (n IS XML.Container)) THEN (* transformation result of PreTransform could be not a container *)
				container := n(XML.Container);
				(* no modification while iteration allowed, extract first the contents into a snapshot *)
				ExtractContentsOfContainer(container, snapshot);
				enum := snapshot.GetContents();
				WHILE (enum.HasMoreElements()) DO
					pChild := enum.GetNext(); child := pChild(XML.Content); newChild := child;
					IF (~TransformXMLTree(file, newChild, request, transformationDepth, w)) THEN RETURN FALSE END;
					IF (newChild # NIL) THEN
						IF ((newChild IS XML.Container) & (~(newChild IS XML.Element))) THEN (* avoid nested containers *)
							resultContainer := newChild(XML.Container);
							resultEnum := resultContainer.GetContents();
							WHILE(resultEnum.HasMoreElements()) DO
								pResultChild := resultEnum.GetNext(); resultChild := pResultChild(XML.Content);
								container.AddContent(resultChild)
							END
						ELSE
							container.AddContent(newChild)
						END
					END
				END;

				(* post transformation *)
				IF (n IS XML.Element) THEN
					elem := n(XML.Element);
					IF (IsActive(elem)) THEN
						IF (~TransformActiveElement(file, n, PostTransformation, request, w)) THEN RETURN FALSE END
					END
				END
			END;
			IF (wasTransformed) THEN
				(* transformation of the transformation result is needed *)
				IF (~TransformXMLTree(file, n, request, transformationDepth+1, w)) THEN RETURN FALSE END;
				IF (DEBUG) THEN Log(elem) END
			END
		END; (* transformation result could be not a container *)
		RETURN TRUE
	END TransformXMLTree;

	PROCEDURE Log(elem: XML.Element);
	VAR sw: Streams.StringWriter; w: Streams.Writer; msg: ARRAY 1024 OF CHAR;
	BEGIN
		NEW(sw, LEN(msg)); w := sw; elem.Write(w, NIL, 0);
		sw.Get(msg); KernelLog.String(msg); KernelLog.Ln
	END Log;

	PROCEDURE ExtractContentsOfContainer(input: XML.Container; VAR output: XML.Container);
	VAR e: XMLObjects.Enumerator; p : ANY; child: XML.Content;
	BEGIN
		NEW(output);
		(* first copy contents to output *)
		e := input.GetContents();
		WHILE (e.HasMoreElements()) DO
			p := e.GetNext(); child := p(XML.Content);
			output.AddContent(child);
		END;

		(* then remove contents from input *)
		e := output.GetContents();
		WHILE (e.HasMoreElements()) DO
			p := e.GetNext(); child := p(XML.Content);
			input.RemoveContent(child);
		END
	END ExtractContentsOfContainer;

	PROCEDURE IsActive(n : XML.Element) : BOOLEAN;
	VAR module, obj: Strings.String;
	BEGIN (* n # NIL *)
		ExtractModuleObjectName(n, module, obj);
		(* check whether the module is declared to represent an active namespace *)
		IF ((module # NIL) & (obj # NIL)) THEN
			RETURN IsModuleRegistered(module^)
		ELSE
			RETURN FALSE
		END
	END IsActive;

	(* get the objectId if specfified used for statefull active elements *)
	PROCEDURE GetObjectId(CONST id: ARRAY OF CHAR; request: HTTPSupport.HTTPRequest) : Strings.String;
	VAR objectId: Strings.String;
	BEGIN
		(* the object id is composed by the actual uri and id attribute for the active element *)
		(* '&' does occur neither in a xml attribute nor in shortUri *)
		NEW(objectId, LEN(id)+Strings.Length(request.shortUri)+1);
		Strings.Concat(request.shortUri, "&", objectId^);
		Strings.Append(objectId^, id);
		RETURN objectId
	END GetObjectId;

	(** if isPreTransformation is TRUE then PreTansform() is called otherwise PostTransform(),
	 *  returns true iff the transformation worked without an error *)
	PROCEDURE TransformActiveElement(file: Files.File; VAR n: XML.Content; isPreTransformation: BOOLEAN;
		request: HTTPSupport.HTTPRequest; w: Streams.Writer) : BOOLEAN;
	VAR moduleName, objName, elemName, objectId, oidAttrVal: Strings.String; elem: XML.Element;
		activeElemFact: ActiveElementFactory; errormsg: ARRAY 256 OF CHAR; activeElem: DynamicWebpage.ActiveElement;
		session: HTTPSession.Session;
		BEGIN (* n IS XML.ELement & IsActive(n) is TRUE *)
		elem := n(XML.Element); elemName := elem.GetName();

		IF (DEBUG) THEN KernelLog.String(elemName^); KernelLog.String(" is active"); KernelLog.Ln END;

		ExtractModuleObjectName(elem, moduleName, objName);
		(* moduleName # NIL & objName # NIL since IsActive(n) = TRUE *)
		activeElemFact := FindActiveElemFactory(moduleName^, objName^);
		IF (activeElemFact # NIL) THEN
			session := HTTPSession.GetSession(request);

			oidAttrVal := elem.GetAttributeValue(DynamicWebpage.XMLAttributeObjectIdName);
			IF (oidAttrVal # NIL) THEN (* seems to be a statefull active element *)
				objectId := GetObjectId(oidAttrVal^, request);
			ELSE (* seems to be a stateless active element *)
				objectId := NIL
			END;

			activeElem := activeElemFact.GetElementInstance(session, objectId);
			IF (activeElem # NIL) THEN
				(* here would be an exception handler fine *)
				IF (isPreTransformation) THEN
					n := activeElem.PreTransform(elem, request)
				ELSE
					n := activeElem.Transform(elem, request)
				END
			ELSE
				Strings.Concat("In element '", elemName^, errormsg);
				Strings.Append(errormsg, "': Could not create an instance for the active element '");
				Strings.Append(errormsg, moduleName^); Strings.Append(errormsg, ".");
				Strings.Append(errormsg, objName^);
				Strings.Append(errormsg, "'. If you use a statefull active element then you must identify the instance with the xml attribute '");
				Strings.Append(errormsg, DynamicWebpage.XMLAttributeObjectIdName); Strings.Append(errormsg, "'.");
				ReportGeneratorError(file, w, elem.GetPos(), 0, 0, errormsg);
				KernelLog.String("Error in Stream: "); KernelLog.String(errormsg); KernelLog.Ln;
				RETURN FALSE (* stop transformation process *)
			END
		ELSE
			Strings.Concat("In element '", elemName^, errormsg);
			Strings.Append(errormsg, "': The active element '");
			Strings.Append(errormsg, moduleName^); Strings.Append(errormsg, ".");
			Strings.Append(errormsg, objName^); Strings.Append(errormsg, "' is not defined.");
			ReportGeneratorError(file, w, elem.GetPos(), 0, 0, errormsg);
			KernelLog.String("Error in Stream: "); KernelLog.String(errormsg); KernelLog.Ln;
			RETURN FALSE (* stop transformation process *)
		END;

		RETURN TRUE
	END TransformActiveElement;

	PROCEDURE IsModuleRegistered(CONST moduleName: ARRAY OF CHAR) : BOOLEAN;
	VAR i : LONGINT; p : ANY; obj: ActiveElementFactory;
	BEGIN
		registeredActiveElemFact.Lock;
		FOR i := 0 TO registeredActiveElemFact.GetCount()-1 DO
			p := registeredActiveElemFact.GetItem(i);
			obj := p(ActiveElementFactory);
			IF (obj.moduleName = moduleName) THEN
				registeredActiveElemFact.Unlock;
				RETURN TRUE
			END
		END;
		registeredActiveElemFact.Unlock;
		RETURN FALSE
	END IsModuleRegistered;

	PROCEDURE FindActiveElemFactory(CONST moduleName, objName: ARRAY OF CHAR) : ActiveElementFactory;
	VAR i : LONGINT; p : ANY; obj: ActiveElementFactory;
	BEGIN
		registeredActiveElemFact.Lock;
		FOR i := 0 TO registeredActiveElemFact.GetCount()-1 DO
			p := registeredActiveElemFact.GetItem(i);
			obj := p(ActiveElementFactory);
			IF ((obj.moduleName = moduleName) & (obj.activeElemDesc.elementName = objName)) THEN
				registeredActiveElemFact.Unlock;
				RETURN obj
			END
		END;
		registeredActiveElemFact.Unlock;
		RETURN NIL
	END FindActiveElemFactory;

	PROCEDURE ExtractModuleObjectName(n: XML.Element; VAR moduleName: Strings.String; VAR objName: Strings.String);
	VAR elemNameDyn : DynamicStrings.DynamicString; elemName, namespaceId, attrVal: Strings.String;
		pos: LONGINT; attrName: ARRAY 128 OF CHAR; attr: XML.Attribute; tempElem : XML.Element;
	BEGIN (* n # NIL *)
		moduleName := NIL; objName := NIL;
		elemName := n.GetName();
		DynamicStrings.Search(":", elemName^, pos);
		IF ((pos > 0) & (Strings.Length(elemName^) > pos+1)) THEN (* elemName^ = "a:b" and len(a) > 0 and len(b) > 0 *)
			NEW(elemNameDyn); elemNameDyn.FromArrOfChar(elemName);
			namespaceId := elemNameDyn.Extract(0, pos);
			Strings.Concat("xmlns:", namespaceId^, attrName);

			(* look for the namespace declaration recursively in parent elements *)
			tempElem := n; attr := NIL;
			WHILE ((tempElem # NIL) & (attr = NIL)) DO
				attr := tempElem.GetAttribute(attrName);
				tempElem := tempElem.GetParent();
			END;
			IF (attr # NIL) THEN
				attrVal := attr.GetValue();
				moduleName := attrVal; objName := elemNameDyn.Extract(pos+1, Strings.Length(elemName^)-pos)
			END
		END
	END ExtractModuleObjectName;

	PROCEDURE ReportGeneratorError(f: Files.File; w: Streams.Writer; pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
		VAR fname: Files.FileName;
	BEGIN
		IF (f # NIL) THEN
			f.GetName(fname);
		ELSE
			COPY("?", fname);
		END;
		KernelLog.String("DynamicWebpagePlugin while processing file '"); KernelLog.String(fname);  KernelLog.String("':");
		KernelLog.Ln; KernelLog.String("pos "); KernelLog.Int(pos, 6); KernelLog.String(", line "); KernelLog.Int(line, 0);
		KernelLog.String(", row "); KernelLog.Int(row, 0); KernelLog.String("    "); KernelLog.String(msg); KernelLog.Ln;

		w.String(DocType); w.Ln;
		w.String("<html><head><title>Error while processing dynamic webpage</title></head>");
		w.Ln; w.String("<body><h1>Error while processing dynamic webpage</h1><p>file '");
		w.String(fname); w.String("' pos "); w.Int(pos, 6);
		w.String(", line "); w.Int(line, 0); w.String(", row ");
		w.Int(row, 0); w.String("  "); w.String(msg); w.Ln;
		w.String("</p><hr/><address>"); w.String(WebHTTPServer.ServerVersion);
		w.String("</address></body></html>")
	END ReportGeneratorError;

	PROCEDURE ReportXMLParserScannerError(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR); (* Error handler for the XML parser *)
	BEGIN
		NEW(parserError); parserError.pos := pos; parserError.line := line; COPY(msg, parserError.msg)
	END ReportXMLParserScannerError;

	PROCEDURE HandleClientAction(request: HTTPSupport.HTTPRequest);
	VAR moduleVar, objectVar, methodVar, objectIdVar, var: HTTPSupport.HTTPVariable; par: DynamicWebpage.Parameter;
		params : DynamicWebpage.ParameterList; paramTempList : TFClasses.List; activeFact: ActiveElementFactory;
		handler: DynamicWebpage.EventHandler; p : ANY; varPrefix : ARRAY 40 OF CHAR;
		i, prefixLength, restLength: LONGINT; session: HTTPSession.Session; objectId: Strings.String;
	BEGIN
		prefixLength := Strings.Length(DynamicWebpage.HTTPVarCommandParamPrefix);
		moduleVar := request.GetVariableByName(DynamicWebpage.HTTPVarCommandModule);
		objectVar := request.GetVariableByName(DynamicWebpage.HTTPVarCommandObject);
		objectIdVar := request.GetVariableByName(DynamicWebpage.HTTPVarCommandObjectId);
		methodVar := request.GetVariableByName(DynamicWebpage.HTTPVarCommandMethod);

		IF (DEBUG) THEN
			IF (moduleVar # NIL) THEN KernelLog.String(moduleVar.value) END;
			KernelLog.String(".");
			IF (objectVar # NIL) THEN KernelLog.String(objectVar.value) END;
			KernelLog.String(".");
			IF (methodVar # NIL) THEN KernelLog.String(methodVar.value) END;
			IF (objectIdVar # NIL) THEN KernelLog.String(" id="); KernelLog.String(objectIdVar.value) END;
			KernelLog.Ln
		END;

		IF ((moduleVar # NIL) & (objectVar # NIL) & (methodVar # NIL)) THEN
			(* search all parameters *)
			NEW(paramTempList);
			request.variables.Lock;
			FOR i := 0 TO request.variables.GetCount()-1 DO
				p := request.variables.GetItem(i); var := p(HTTPSupport.HTTPVariable);
				Strings.Copy(var.name, 0, prefixLength, varPrefix);
				restLength := Strings.Length(var.name)-prefixLength;
				IF ((varPrefix = DynamicWebpage.HTTPVarCommandParamPrefix) & (restLength > 0)) THEN
					NEW(par); NEW(par.name, restLength+1);
					Strings.Copy(var.name, prefixLength, restLength, par.name^);
					NEW(par.value, Strings.Length(var.value)+1); COPY(var.value, par.value^);
					paramTempList.Add(par)
				END
			END;
			request.variables.Unlock;
			NEW(params);
			IF paramTempList.GetCount() > 0 THEN
				NEW(params.parameters, paramTempList.GetCount());
				FOR i := 0 TO paramTempList.GetCount()-1 DO
					p := paramTempList.GetItem(i); params.parameters[i] := p(DynamicWebpage.Parameter)
				END
			ELSE
				params.parameters := NIL
			END;

			(* invoke the event delegate *)
			activeFact := FindActiveElemFactory(moduleVar.value, objectVar.value);
			IF (activeFact # NIL) THEN
				session := HTTPSession.GetSession(request);

				IF (objectIdVar # NIL) THEN
					objectId:= GetObjectId(objectIdVar.value, request)
				ELSE
					objectId := NIL
				END;

				handler := activeFact.FindEventHandler(session, objectId, methodVar.value);
				IF (handler # NIL) THEN
					(* here would be an exception handler fine *)
					handler(request, params)
				ELSE
					KernelLog.String("Dynamic Webpage Plugin: Event handler '"); KernelLog.String(methodVar.value);
					KernelLog.String("' in "); KernelLog.String(moduleVar.value); KernelLog.String("."); KernelLog.String(objectVar.value);
					KernelLog.String(" is not registered to handle webclient events. If you use a statefull active element then you");
					KernelLog.String(" have to specify the instance id."); KernelLog.Ln
				END
			ELSE
				KernelLog.String("Dynamic Webpage Plugin: Active element ");
				KernelLog.String(moduleVar.value); KernelLog.String("."); KernelLog.String(objectVar.value);
				KernelLog.String(" is not registered."); KernelLog.Ln
			END
		END
	END HandleClientAction;

	PROCEDURE ClearFactoryList;
	VAR p: ANY; fact: ActiveElementFactory; i: LONGINT;
	BEGIN
		IF (registeredActiveElemFact # NIL) THEN
			registeredActiveElemFact.Lock;
			FOR i := 0 TO registeredActiveElemFact.GetCount()-1 DO
				p := registeredActiveElemFact.GetItem(i); fact := p(ActiveElementFactory); (* fact # NIL *)
				fact.PrepareDisposal
			END;
			registeredActiveElemFact.Unlock;
			registeredActiveElemFact := NIL
		END
	END ClearFactoryList;

	PROCEDURE ReadRegisteredModules;
	VAR elem, child: XML.Element; enum: XMLObjects.Enumerator; p: ANY; childName, moduleName: Strings.String;
		attr: XML.Attribute;
	BEGIN
		ClearFactoryList;
		NEW(registeredActiveElemFact);
		IF (Configuration.config # NIL) THEN
			elem := Configuration.config.GetRoot();
			elem := Configuration.GetNamedElement(elem, "Section", DynamicWebpage.ConfigurationSupperSectionName);
			IF (elem # NIL) THEN
				elem := Configuration.GetNamedElement(elem, "Section", DynamicWebpage.ConfigurationSubSectionName);
				IF (elem # NIL) THEN
					enum := elem.GetContents();
					WHILE (enum.HasMoreElements()) DO
						p := enum.GetNext();
						IF (p IS XML.Element) THEN
							child := p(XML.Element); childName := child.GetName();
							IF (childName^ = "Setting") THEN
								attr := child.GetAttribute("value");
								IF (attr # NIL) THEN
									moduleName := attr.GetValue();
									RegisterModuleByName(moduleName)
								END
							END
						END
					END
				ELSE
					KernelLog.String("Dynamic Webpage plugin: In Configuration.XML under '");
					KernelLog.String(DynamicWebpage.ConfigurationSupperSectionName); KernelLog.String("' is no section '");
					KernelLog.String(DynamicWebpage.ConfigurationSubSectionName); KernelLog.String(" defined."); KernelLog.Ln
				END
			ELSE
				KernelLog.String("Dynamic Webpage plugin: In Configuration.XML is no section '");
				KernelLog.String(DynamicWebpage.ConfigurationSupperSectionName); KernelLog.String("' defined."); KernelLog.Ln
			END
		ELSE
			KernelLog.String("Dynamic Webpage plugin: Cannot open Configuration.XML"); KernelLog.Ln
		END
	END ReadRegisteredModules;

	PROCEDURE RegisterModuleByName(moduleName: Strings.String);
	VAR module: Modules.Module; factory : DynamicWebpage.ActiveElementDescSetFactory; i, res: LONGINT;
		msg: ARRAY 1024 OF CHAR; desc: DynamicWebpage.ActiveElementDescriptor;
		descList: DynamicWebpage.ActiveElementDescSet;
	BEGIN
		(* load the module if not already loaded *)
		module := Modules.ThisModule(moduleName^, res, msg);
		IF ((res = 0) & (module # NIL)) THEN
			GETPROCEDURE(moduleName^, DynamicWebpage.ProcNameGetDescriptors, factory);
			IF (factory # NIL) THEN
				descList := factory();
				IF (descList # NIL) THEN (* register all present descriptors *)
					FOR i := 0 TO descList.GetCount()-1 DO
						desc := descList.GetItem(i);
						RegisterActiveElement(moduleName, desc)
					END
				ELSE
					KernelLog.String("Dynamic Webpage Plugin: Wrong result type from procedure '");
					KernelLog.String(DynamicWebpage.ProcNameGetDescriptors); KernelLog.String("' in module '");
					KernelLog.String(moduleName^); KernelLog.String("'"); KernelLog.Ln
				END
			ELSE
				KernelLog.String("Dynamic Webpage Plugin: Procedure '"); KernelLog.String(DynamicWebpage.ProcNameGetDescriptors);
				KernelLog.String("' in module '"); KernelLog.String(moduleName^); KernelLog.String("' is not present."); KernelLog.Ln
			END
		ELSE
			KernelLog.String("Dynamic Webpage Plugin: Module '"); KernelLog.String(moduleName^);
			KernelLog.String("' is not present."); KernelLog.Ln
		END
	END RegisterModuleByName;

	PROCEDURE RegisterActiveElement(moduleName: Strings.String; desc: DynamicWebpage.ActiveElementDescriptor);
	VAR activeElemFact : ActiveElementFactory;
	BEGIN
		IF (desc.factory # NIL) THEN
			NEW(activeElemFact, moduleName, desc);
			(* the new active element instance is created by the first usage and it is then determined by the dynamic type of
				factory method result whether it is a statefull or stateless active element *)
			registeredActiveElemFact.Add(activeElemFact);
			IF ((DEBUG) OR (ShowRegisteredElements)) THEN
				KernelLog.String("Active element '"); KernelLog.String(moduleName^); KernelLog.String(".");
				KernelLog.String(desc.elementName); KernelLog.String("' has been registered."); KernelLog.Ln
			END
		ELSE
			KernelLog.String("Dynamic Webpage Plugin: No factory method defined for active element '");
			KernelLog.String(desc.elementName); KernelLog.String("' in module '");
			KernelLog.String(moduleName^); KernelLog.String("'"); KernelLog.Ln
		END
	END RegisterActiveElement;

	PROCEDURE LockServingHosts;
	BEGIN {EXCLUSIVE}
		AWAIT(~lockServingHosts); lockServingHosts := TRUE
	END LockServingHosts;

	PROCEDURE UnlockServingHosts;
	BEGIN {EXCLUSIVE}
		lockServingHosts := FALSE
	END UnlockServingHosts;

	PROCEDURE Install*(context : Commands.Context); (** [{host}]. Host may include wildcards. *)
	VAR host: ARRAY 1024 OF CHAR; hl: WebHTTPServer.HostList;
	BEGIN
		LockServingHosts;
		IF dynamicPagePlugin = NIL THEN  (* Singleton *)
			NEW(dynamicPagePlugin, PluginName)
		END;

		IF (servingHosts.GetCount() = 0) THEN
			ReadRegisteredModules
		END;

		REPEAT
			context.arg.String(host); Strings.Trim(host, " ");
			hl := WebHTTPServer.FindHosts(host);
			IF (hl # NIL) THEN
				WHILE (hl # NIL) DO
					context.out.String(PluginName);
					IF (servingHosts.IndexOf(hl.host) >= 0) THEN
						context.out.String(" already installed at ")
					ELSE
						hl.host.AddPlugin(dynamicPagePlugin);
						servingHosts.Add(hl.host);
						context.out.String(" added to ")
					END;
					IF (hl.host.name = "") THEN context.out.String("default host ")
					ELSE context.out.String(hl.host.name)
					END;
					context.out.Ln;
					hl := hl.next
				END
			ELSE
				context.error.String("Host '"); context.error.String(host); context.error.String("' not present."); context.error.Ln
			END
		UNTIL ((context.arg.res # Streams.Ok) OR (Strings.Length(host) = 0));
		UnlockServingHosts;
	END Install;

	PROCEDURE ModuleTerminator;
	VAR p: ANY; h: WebHTTPServer.Host; i : LONGINT;
	BEGIN
		LockServingHosts;
		FOR i := 0 TO servingHosts.GetCount()-1 DO
			p := servingHosts.GetItem(i); h := p(WebHTTPServer.Host);
			UnInstallHost(h)
		END;
		UnlockServingHosts;
		ClearFactoryList
	END ModuleTerminator;

	PROCEDURE UnInstallHost(host: WebHTTPServer.Host);
	BEGIN
		host.RemovePlugin(dynamicPagePlugin);
		KernelLog.String(PluginName); KernelLog.String(" removed from ");
		IF (host.name = "") THEN KernelLog.String("default host ")
		ELSE KernelLog.String(host.name)
		END;
		KernelLog.Ln
	END UnInstallHost;

	PROCEDURE Uninstall*(context : Commands.Context); (** [{host}]. Host may include wildcards *)
	VAR host: ARRAY 1024 OF CHAR; hl: WebHTTPServer.HostList;
	BEGIN
		IF dynamicPagePlugin # NIL THEN
			LockServingHosts;
			REPEAT
				context.arg.String(host); Strings.Trim(host, " ");
				hl := WebHTTPServer.FindHosts(host);
				IF (hl # NIL) THEN
					WHILE (hl # NIL) DO
						UnInstallHost(hl.host);
						servingHosts.Remove(hl.host);
						hl := hl.next
					END
				ELSE
					context.error.String("Host '"); context.error.String(host); context.error.String("' not present."); context.error.Ln
				END
			UNTIL ((context.arg.res # Streams.Ok) OR (Strings.Length(host) = 0));
			UnlockServingHosts
		ELSE
			context.error.String(PluginName); context.error.String(" is not installed"); context.error.Ln
		END;

		IF (servingHosts.GetCount() = 0) THEN
			ClearFactoryList
		END;
	END Uninstall;

BEGIN
	NEW(servingHosts); lockServingHosts := FALSE;
	Modules.InstallTermHandler(ModuleTerminator)
END DynamicWebpagePlugin.

SystemTools.Free DynamicWebpagePlugin~
SystemTools.Free WebHTTPServerTools WebHTTPServer WebHTTP~

DynamicWebpagePlugin.Install ~
DynamicWebpagePlugin.Uninstall ~