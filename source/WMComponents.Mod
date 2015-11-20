MODULE WMComponents;	(** AUTHOR "TF"; PURPOSE "Component Framework based on XML"; *)
(**

-- 	Events: --

	Each VisualComponent can produce keyboard and mouse events which can trigger A2 commands.
	The command string for a given event can by specified by the usage of XML attributes and component properties.
	The following attributes are defined:

	Keyboard:  	onReturn, onEscape, onKeyPressed, onKeyReleased
	Mouse: 		onLeftClick, onRightClick, onMiddleClick, onClick

	The command strings are processed (macro substitution) before the actual command is called.

-- 	Macro substitution: --

	General form: "^" [namespace ":"] macrostring

	A macro always start with MacroCharacter ("^"). The next occurence of a whitespace character determines the end of the macro.
	Two consequent MacroCharacter's ("^^") will be replaced by the MacroCharacter ("^") not triggering macro substitution at all.

	The user can install MacroHandlerProcedures for a given namespace. At most one handler per namespace can be installed.
	If the namespace is omitted, the default macro handler is triggered.

	The DefaultMacroHandler currently supports the following macro substitutions:

	^selection			is replaced by the last selection of the user
	^clipboard			is replaced by the content of the clipboard

	^attribute=[component "."] attribute
	^property=[component "."] property

	is replaced by the value of <attribute> or <property>. 
	If the component qualifier is omitted, <attribute> or <property> is supposed to be an attribute or property of the originator of the event.

	If no MacroHandlerProcedure is found for a given macro, no substitution takes place.
	Example:

	onLeftClick = SystemTools.Show ^attribute=generator
	onMiddleClick = SystemTools.Show ^property=FillColor

*)

(*PH 08/14: 
- avoid parallel call of FormWindow.SetContent, Component.AddContent, Form.InvalidateRect by different processes, through use of EXCLUSIVE sections.
- send an "invalidate content" message to a window after it appears on the display, which is handled after "form" field is ready
- restructure FormWindow.SetContent() to assure coherent displays and to assure FormWindow.content is consistent 
*)

IMPORT
	KernelLog, Inputs, Streams, Events, Files, Texts, TextUtilities,
	XML, XMLScanner, XMLParser, XMLObjects, Codecs, Localization, Repositories,
	Messages := WMMessages, Rectangles := WMRectangles,
	WMEvents, WMProperties, WMGraphics, Strings, WM := WMWindowManager, Raster,
	Commands, Modules, Kernel, Locks, Objects, WMDropTarget;

CONST
	Ok* = 0;
	DuplicateNamespace* = 1;

	AlignNone* = 0; AlignLeft* = 1; AlignTop* = 2; AlignRight* = 3; AlignBottom* = 4; AlignClient* = 5; AlignRelative*=6;

	None=0; Left=1; Right=2; Lower=3; Upper=4; LowerRight=5; UpperRight=6; LowerLeft=7; UpperLeft=8; Inside = 9;
	MaxRel = 16*1024;


	MaxComponentNameSize* = 64; (* including 0X *)

	TraceFocus = 0;
	TraceFinalize = 1;
	Trace = {};

	(* Enable event logging? *)
	Logging = TRUE;

	(* Macro handling *)

	(* General form of macro: MacroCharacter [Namespace + NamespaceCharacter] MacroName *)

	MacroCharacter = "^";
	NamespaceCharacter = ":";

	NoNamespace = "";

	(* Namespace used if no namespace is specified *)
	DefaultNamespace = "system";

	(* Macros names of default macro handler *)
	MacroSelection = "selection";
	MacroClipboard = "clipboard";
	MacroAttributePrefix = "attribute=";
	MacroPropertyPrefix = "property=";
	CanYield = TRUE;
	
	(*temporary - to be removed*)
	FlagDirty=13;

TYPE
	(** Installable event preview handlers. Are called by the components sequencer thread *)
	PointerHandler*  = PROCEDURE {DELEGATE} (x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
	PointerLeaveHandler* = PROCEDURE {DELEGATE} (VAR handled : BOOLEAN);
	DragDropHandler* = PROCEDURE {DELEGATE} (x, y : LONGINT; dragInfo : WM.DragInfo; VAR handled : BOOLEAN);
	DragResultHandler* = PROCEDURE {DELEGATE} (accepted : BOOLEAN; recipient : ANY; dragInfo : WM.DragInfo; VAR handled : BOOLEAN);
	DragAutoStartHandler* = PROCEDURE {DELEGATE} (VAR handled : BOOLEAN);
	FocusHandler* = PROCEDURE {DELEGATE} (hasFocus : BOOLEAN);
	ContextMenuHandler* = PROCEDURE {DELEGATE} (sender : ANY; x, y: LONGINT);
	KeyEventHandler* = PROCEDURE {DELEGATE} (ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
	DrawHandler* = PROCEDURE {DELEGATE} (canvas : WMGraphics.Canvas);
	Recursion*= ENUM None*, FromComponent*, FromBottom* END;

TYPE
	SetStringProcedure = PROCEDURE {DELEGATE} (CONST string : ARRAY OF CHAR; x,y : LONGINT; VAR res : LONGINT);

	DropTarget = OBJECT(WMDropTarget.DropTarget)
	VAR
		originator : ANY;
		setString : SetStringProcedure;
		x,y : LONGINT;

		PROCEDURE &Init(originator : ANY; setString : SetStringProcedure; x,y : LONGINT);
		BEGIN
			ASSERT(setString # NIL);
			SELF.originator := originator;
			SELF.setString := setString;
			SELF.x := x;
			SELF.y := y;
		END Init;

		PROCEDURE GetInterface(type : LONGINT) : WMDropTarget.DropInterface;
		VAR sdi : DropString;
		BEGIN
			IF (type = WMDropTarget.TypeString) THEN
				NEW(sdi, originator, setString, x,y); RETURN sdi;
			ELSE
				RETURN NIL;
			END;
		END GetInterface;

	END DropTarget;

	DropString = OBJECT(WMDropTarget.DropString)
	VAR
		originator : ANY;
		setString : SetStringProcedure;
		x,y : LONGINT;

		PROCEDURE &Init(originator : ANY; setString : SetStringProcedure; x,y : LONGINT);
		BEGIN
			ASSERT(setString # NIL);
			SELF.originator := originator;
			SELF.setString := setString;
			SELF.x := x; SELF.y := y;
		END Init;

		PROCEDURE Set(CONST string : ARRAY OF CHAR; VAR res : LONGINT);
		BEGIN
			setString(string, x,y, res);
		END Set;

	END DropString;

	LanguageExtension* = POINTER TO RECORD(Messages.MessageExtension)
		languages* : Localization.Languages;
	END;

	ToggleEditMode* = POINTER TO RECORD
		recursion*: Recursion;
	END;

	Event* = RECORD
	END;

	KeyPressedEvent* = RECORD(Event)
		ucs- : LONGINT;
		flags- : SET;
		keysym- : LONGINT;
	END;

	PointerEvent* = RECORD(Event)
		x-, y-, z- : LONGINT;
		keys- : SET;
	END;

	EventContext* = OBJECT(Repositories.Context)
	VAR
		originator- : Component; (** {originator # NIL} *)
		command- : Strings.String; (** {command # NIL}, immutable *)
		timestamp- : LONGINT;

		PROCEDURE &New*(originator : Component; command : Strings.String; in, arg : Streams.Reader; out, error : Streams.Writer; caller : OBJECT);
		BEGIN
			ASSERT((originator # NIL) & (command # NIL));
			SELF.originator := originator;
			SELF.command := command;
			Init(in, arg, out, error, caller);
		END New;

	END EventContext;

	PointerContext* = OBJECT(EventContext)
	VAR
		pointer- : PointerEvent;
	END PointerContext;

	KeyContext* = OBJECT(EventContext)
	VAR
		key- : KeyPressedEvent;
	END KeyContext;

TYPE
	(** Basic component *)

	ComponentStyleChanged = OBJECT
	END ComponentStyleChanged;

	Component* = OBJECT(Repositories.Component)
	VAR
		sequencer- : Messages.MsgSequencer;
		initialized- : BOOLEAN;

		properties- : WMProperties.PropertyList;
		events- : WMEvents.EventSourceList;
		eventListeners- : WMEvents.EventListenerList;

		id-, uid- : WMProperties.StringProperty;
		enabled- : WMProperties.BooleanProperty;

		 (* discard property changes that come from a property change within the same component*)
		inPropertyUpdate, inLinkUpdate : BOOLEAN;

		(* If TRUE, this component is supposed to be created and managed by its parent. It is not externalized. *)
		internal- : BOOLEAN;

		(* after Init() , calling Reset() implicitely by insertion into FormWindow or explicitely, thereby triggering Initialize() is required to render component responsive to messages *)
		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrComponent);
			sequencer := NIL;
			initialized := FALSE;
			NEW(properties); properties.onPropertyChanged.Add(SELF.InternalPropertyChanged); properties.onLinkChanged.Add(SELF.InternalLinkChanged);
			NEW(events);
			NEW(eventListeners);
			NEW(id, PrototypeID, NIL, NIL); properties.Add(id);
			NEW(uid, PrototypeUID, NIL, NIL); properties.Add(uid);
			NEW(enabled, PrototypeEnabled, NIL, NIL); properties.Add(enabled);
			inPropertyUpdate := FALSE;
			inLinkUpdate := FALSE;
			internal := FALSE;
			SetGenerator("WMComponents.NewComponent");
		END Init;


		PROCEDURE Write*(w : Streams.Writer;context: ANY; level : LONGINT);
		VAR enum: XMLObjects.Enumerator; c: ANY; name : Strings.String; nextLevel : LONGINT;
		BEGIN
			IF IsLocked() THEN (* D.String("Component.Write: islocked"); D.Ln; *) RETURN; END;
			IF ~internal THEN
				name := GetName();
				w.Char('<'); IF name = NIL THEN w.String("_NILNAME_") ELSE w.String(name^) END;
				WriteAttributes(w, context, level);
				w.Char('>');
				properties.WriteXML(w, context, level);
				nextLevel := level + 1;
			ELSE
				(* D.String("Component.Write: isInternal"); D.Ln; *)
				nextLevel := level;
			END;
			enum := GetContents();
			WHILE enum.HasMoreElements() DO
				c := enum.GetNext();
				IF ~(c IS WMProperties.Properties) THEN
					IF ~((c IS Component) & ((c(Component).internal) OR c(Component).IsLocked())) THEN NewLine(w, 0); NewLine(w, nextLevel); END;
					c(XML.Content).Write(w, context, nextLevel); 
					(*c(Component).Write(w, context, nextLevel)*) 
				END;
			END;
			IF ~internal THEN
				NewLine(w, level);
				w.String("</"); IF name = NIL THEN w.String("_NILNAME_") ELSE w.String(name^); END;  w.Char('>')
			END;
		END Write;

		(*
		PROCEDURE ToRepository*(CONST repository: ARRAY OF CHAR; w: Streams.Writer; level: LONGINT);
		VAR enum: XMLObjects.Enumerator; c: ANY; name : Strings.String; nextLevel : LONGINT;
		BEGIN
			IF IsLocked() THEN RETURN; END;
			IF ~internal THEN
				name := GetName();
				w.Char('<'); IF name = NIL THEN w.String("_NILNAME_") ELSE w.String(name^) END;
				WriteAttributes(w, NIL, level);
				w.Char('>');
				properties.ToRepository(repository,w, level);
				nextLevel := level + 1;
			ELSE
				nextLevel := level;
			END;
			enum := GetContents();
			WHILE enum.HasMoreElements() DO
				c := enum.GetNext();
				IF ~(c IS WMProperties.Properties) THEN
					IF ~((c IS Component) & ((c(Component).internal) OR c(Component).IsLocked())) THEN NewLine(w, 0); NewLine(w, nextLevel); END;
					IF (c IS Repositories.Component) THEN
						c(Repositories.Component).ToRepository(repository, w, level);
					ELSE
						c(XML.Content).Write(w, NIL, nextLevel);
					END;
				END;
			END;
			IF ~internal THEN
				NewLine(w, level);
				w.String("</"); IF name = NIL THEN w.String("_NILNAME_") ELSE w.String(name^); END;  w.Char('>')
			END;
		END ToRepository;
		*)

		PROCEDURE FromXML*(xml: XML.Element);
		VAR component: Component; enum: XMLObjects.Enumerator; c: ANY; element: XML.Element;
		BEGIN
			element := GetElementByName(xml,"Properties");
			IF (element = NIL) & (xml IS Component) THEN (* trick to get XML description of properties if not already there (new components) *)
				xml(Component).properties.ToXML(element)
			END;
			properties.FromXML(element);

			(* was: supercall to Repositories *)
			enum := xml.GetContents();
			WHILE enum.HasMoreElements() DO
				c := enum.GetNext();
				IF c IS XML.Element THEN
					IF ~(c IS Component) OR ~c(Component).internal THEN
						component := ComponentFromXML(c(XML.Element));
						IF component # NIL THEN
							AddContent(component)
						END;
					END;
				END;
			END;
			
			enum :=xml.GetAttributes();
			WHILE enum.HasMoreElements() DO
				c := enum.GetNext();
				IF c(XML.Attribute).GetName()^ # "generator" THEN
					SetAttributeValue(c(XML.Attribute).GetName()^, c(XML.Attribute).GetValue()^);
				END;
			END;
			
			(*Initialize;*) (* redundant *)
		END FromXML;

		PROCEDURE IsCallFromSequencer*():BOOLEAN;
		BEGIN
			ASSERT (sequencer # NIL);
			RETURN sequencer.IsCallFromSequencer()
		END IsCallFromSequencer;

		PROCEDURE AssertLock*;
		BEGIN
			ASSERT((sequencer = NIL) OR sequencer.IsCallFromSequencer() OR sequencer.lock.HasReadLock())
		END AssertLock;

		(** Atomically set the components sequencer *)
		PROCEDURE SetSequencer*(s : Messages.MsgSequencer);
		VAR old : Messages.MsgSequencer; c : XML.Content;
		BEGIN
			old := sequencer;
			IF old # NIL THEN old.lock.AcquireWrite() END;
			sequencer := s;
			c := GetFirst();
			WHILE (c # NIL) DO
				IF c IS Component THEN c(Component).SetSequencer(s);  END; (*? what happens to old sequencers/active objects ?*)
				c := GetNext(c);
			END;
			IF old # NIL THEN old.lock.ReleaseWrite() END
		END SetSequencer;

		PROCEDURE Acquire*;
		BEGIN
			IF sequencer # NIL THEN sequencer.lock.AcquireWrite END
		END Acquire;

		PROCEDURE Release*;
		BEGIN
			IF sequencer # NIL THEN sequencer.lock.ReleaseWrite END
		END Release;

		PROCEDURE CheckReadLock*;
		BEGIN
			IF (sequencer # NIL) & (~sequencer.lock.HasReadLock()) THEN
				KernelLog.String("WMComponents.Component.CheckReadLock: FAILED!"); KernelLog.Ln;
				sequencer.lock.WriteLock
			END;
			IF sequencer # NIL THEN ASSERT(sequencer.lock.HasReadLock()) END
		END CheckReadLock;

		(** AddContent adds a content (element or subtree) to the element. Called mainly by the XMLParser.
		*)
		PROCEDURE AddContent*(c : XML.Content);
		VAR m:Messages.Message;  rect:Rectangles.Rectangle;
		BEGIN
			ASSERT(c # NIL);
			Acquire;
			BEGIN {EXCLUSIVE}
				IF c IS WMProperties.Properties THEN
					properties.SetXML(c(WMProperties.Properties)); 
				ELSIF c IS Component THEN
					IF (sequencer # c(Component).sequencer) THEN 
						IF sequencer#NIL THEN 
							c(Component).SetSequencer(sequencer); 
							c(Component).Reset(SELF,NIL); (* will be scheduled by sequencer. implied RecacheProperties*)
							IF (SELF IS VisualComponent) & ( c IS VisualComponent) THEN (* todo: move to VisualComponent*)
								sequencer.ScheduleEvent(SELF(VisualComponent).InvalidateCommand, SELF, NIL); 
							END;
						ELSE (* no tree traversal - is less costly *)
							c(Component).sequencer:=NIL; 
							c(Component).initialized:=FALSE; (*? is this necessary/correct ?*)
						END;
					END;
				ELSIF ~(c IS XML.Comment) THEN
					RETURN
				END;
			END;

			(*Acquire;*)
			AddContent^(c);
			Release;
		END AddContent;

		PROCEDURE RemoveContent*(c : XML.Content);
		BEGIN
			(*ASSERT(c # NIL);*)
			IF c = NIL THEN RETURN END;
			Acquire;
			RemoveContent^(c);
			Release;
		END RemoveContent;

		(** Add internal component. Internal components are supposed to be created and managed by its parent component.
			Internal components and their subcomponents are not externalized *)
		PROCEDURE AddInternalComponent*(component : Component);
		BEGIN
			IF (component # NIL) THEN
				component.internal := TRUE;
				AddContent(component);
			END;
		END AddInternalComponent;

		(** Return the root element of the component hierarchy. This is not necessarily the same as the
			root element of XML since it is possible to have multiple component hierarchies in an XML file *)
		PROCEDURE GetComponentRoot*(): Component;
		VAR p, c : XML.Element;
		BEGIN
			c := SELF;
			LOOP
				p := c.GetParent();
				IF (p # NIL) & (p IS Component) THEN c := p ELSE RETURN c(Component) END
			END
		END GetComponentRoot;

		PROCEDURE Find*(id : ARRAY OF CHAR) : Component;
		VAR
			root, component : Component;

			PROCEDURE IsUID(CONST id : ARRAY OF CHAR) : BOOLEAN;
			BEGIN
				RETURN id[0] = "&";
			END IsUID;

			PROCEDURE RemoveAmpersand(VAR id : ARRAY OF CHAR);
			VAR i : LONGINT;
			BEGIN
				ASSERT(id[0] = "&");
				FOR i := 0 TO LEN(id)-2 DO
					id[i] := id[i + 1];
				END;
			END RemoveAmpersand;

		BEGIN
			component := NIL;
			IF IsUID(id) THEN
				RemoveAmpersand(id);
				root := GetComponentRoot();
				component := root.FindByUID(id);
			ELSE
				component := FindByPath(id, 0);
			END;
			RETURN component;
		END Find;

		(** Find a sub component by its uid *)
		PROCEDURE FindByUID*(CONST uid : ARRAY OF CHAR) : Component;
		VAR c : XML.Content; result : Component; s : Strings.String;
		BEGIN
			IF (uid = "") THEN RETURN NIL END;
			s := SELF.uid.Get();
			IF (s # NIL) & (s^ = uid) THEN
				RETURN SELF
			ELSE
				result := NIL;
				Acquire;
				c := GetFirst();
				WHILE (result = NIL) & (c # NIL) DO
					IF (c IS Component) THEN result := c(Component).FindByUID(uid) END;
					c := GetNext(c);
				END;
				Release;
				RETURN result
			END
		END FindByUID;

		(** find a component by relative path *)
		PROCEDURE FindByPath*(CONST path : ARRAY OF CHAR; pos : LONGINT) : Component;
		VAR component : Component;
		BEGIN
			Acquire;
			component := FindRelativePath(SELF, path, pos);
			Release;
			RETURN component;
		END FindByPath;

		PROCEDURE StringToComponent*(str : Strings.String) : Component;
		VAR
			id : ARRAY 100 OF CHAR;
			isUID : BOOLEAN;
			ch : CHAR;
			sr : Streams.StringReader;
			r, target : Component;
		BEGIN
			NEW(sr, LEN(str)); sr.Set(str^);
			isUID := FALSE; IF sr.Peek() = "%" THEN isUID := TRUE; ch := sr.Get() END;
			sr.Token(id);
			IF isUID THEN r := GetComponentRoot(); target := r.FindByUID(id);
				IF target  = NIL THEN KernelLog.String("StringToComponent : UID target not found: "); KernelLog.String(id); KernelLog.Ln; END
			ELSE target := FindByPath(id, 0);
				IF target  = NIL THEN KernelLog.String("StringToComponent : Path target not found: "); KernelLog.String(id); KernelLog.Ln; END
			END;
			RETURN target
		END StringToComponent;

		(** Search a CompCommand by string *)
		PROCEDURE StringToCompCommand*(eventstr : Strings.String) : WMEvents.EventListener;
		VAR
			id, name : ARRAY 100 OF CHAR;
			isUID : BOOLEAN;
			ch : CHAR;
			sr : Streams.StringReader;
			r, target : Component;
		BEGIN
			NEW(sr, LEN(eventstr)); sr.Set(eventstr^);
			isUID := FALSE; IF sr.Peek() = "%" THEN isUID := TRUE; ch := sr.Get() END;
			sr.Token(id); sr.SkipWhitespace; sr.Token(name);

			IF isUID THEN r := GetComponentRoot(); target := r.FindByUID(id);
				IF target  = NIL THEN KernelLog.String("StringToEvent : UID target not found: "); KernelLog.String(id); KernelLog.Ln; END
			ELSE target := FindByPath(id, 0);
				IF target  = NIL THEN KernelLog.String("StringToEvent : Path target not found: "); KernelLog.String(id); KernelLog.Ln; END
			END;
			IF target # NIL THEN RETURN target.eventListeners.GetHandlerByName(NewString(name))
			ELSE RETURN NIL
			END
		END StringToCompCommand;

		(** The Finalize Method is asynchronous since queuing could result in modules being freed before finalize ispropagated..
		 	Active components should terminate, external resources should be released *)
		PROCEDURE Finalize*; (** PROTECTED *)
		VAR c : XML.Content;
		BEGIN
			IF TraceFinalize IN Trace THEN IF uid # NIL THEN (* KernelLog.String(uid.string) *)  KernelLog.String(".Finalize") END END;
			Acquire;
			c := GetFirst();
			WHILE (c # NIL) DO
				IF (c IS Component) THEN c(Component).Finalize END;
				c := GetNext(c);
			END;
			properties.Finalize;
			Release;
		END Finalize;

		(* reset/initialize a hierarchy of components *)
		PROCEDURE Reset*(sender, data : ANY); (** PROTECTED *)
		VAR c : XML.Content;
		BEGIN
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.Reset, sender, data);
				IF CanYield THEN Objects.Yield END;
			ELSE
				BEGIN	 
					RecacheProperties;
					c := GetFirst();
					WHILE (c # NIL) DO
						IF c IS Component THEN 
							c(Component).Reset(sender, data) 
						END;
						c := GetNext(c);
					END;		
					IF ~initialized THEN Initialize END; (*component is ready when children are ready *)
				END;
			END
		END Reset;

		(* Initialize is called by Reset() and is required to render components responsive *)
		PROCEDURE Initialize*; (** PROTECTED *)
		BEGIN
			BEGIN{EXCLUSIVE}
			initialized := TRUE
			END;
		END Initialize;

		(** Internal interface of the message handler. This method may only be called via the Handle method.
		Components that need to handle messages should implement HandleInternal. *)
		PROCEDURE HandleInternal*(VAR msg : Messages.Message); (** PROTECTED *)
		VAR pa : WMProperties.PropertyArray; i : LONGINT;
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF (msg.msgType = Messages.MsgSetLanguage) & (msg.ext # NIL) & (msg.ext IS LanguageExtension) THEN
				pa := properties.Enumerate();
				IF (pa # NIL) THEN
					FOR i := 0 TO LEN(pa) - 1 DO
						IF (pa[i] # NIL) & (pa[i] IS WMProperties.StringProperty) THEN
							pa[i](WMProperties.StringProperty).SetLanguage(msg.ext(LanguageExtension).languages);
						END;
					END;
				END;
				LanguageChanged(msg.ext(LanguageExtension).languages);
				BroadcastSubcomponents(msg);
			END;
		END HandleInternal;

		(** External interface to the message handler. Asynchronous messages are synchronized by
		the sequencer of the Container *)
		PROCEDURE Handle*(VAR msg : Messages.Message); (** FINAL *)
		VAR s : Strings.String;
		BEGIN
			(* if asynchronous call --> synchronize *)
			IF sequencer=NIL THEN RETURN
			ELSIF ~IsCallFromSequencer() THEN
				IF ~sequencer.Add(msg) THEN
					s := uid.Get();
					KernelLog.String("A message sent to ");
					IF s # NIL THEN KernelLog.String(s^) ELSE KernelLog.String(" <uid = NIL>") END;
					KernelLog.String(" was discarded")
				END;
				IF CanYield THEN Objects.Yield END (* give the sequencer an immediate chance to react -- important on single-processor machines *)
			ELSE HandleInternal(msg) END
		END Handle;

		(** Broadcast a message to all direct subcomponents. The subcomponent can then decide
		whether to further propagate the message to its children or not *)
		PROCEDURE BroadcastSubcomponents*(VAR msg : Messages.Message); (** FINAL *)
		VAR c : XML.Content;
		BEGIN
			Acquire;
			c := GetFirst();
			WHILE (c # NIL) DO
				IF c IS Component THEN c(Component).Handle(msg) END;
				c := GetNext(c);
			END;
			Release
		END BroadcastSubcomponents;

		(* not to be called from user *)
		PROCEDURE LanguageChanged*(languages : Localization.Languages);
		BEGIN
			ASSERT(languages # NIL);
			ASSERT(IsCallFromSequencer());
		END LanguageChanged;

		(* LinkChanged can be called to inform about changes of the state of links (i.e. objects in reference properties)
			Unlike PropertyChanged which informs about an actual replacement of the link *)
		PROCEDURE LinkChanged*(sender, link: ANY);
		BEGIN ASSERT(IsCallFromSequencer());
		END LinkChanged;

		(* will be called synchronously if a property of the component changes. May not be called directly. 
			Call Invalidate in this procedure whenever a property changed that impacts the visualization.
			No such messages are sent until the component is initialized *)
		PROCEDURE PropertyChanged*(sender, property : ANY);(** PROTECTED *)
		BEGIN ASSERT(IsCallFromSequencer());
		END PropertyChanged;

		(** called by the internal property changed handler via the sequencer, either if multiple properties have
			changed or a Reset occured. The PropertyChanged method is called, too in case of multi-property changes
		 	The component should call the inherited RecacheProperties method.
		 	Do not call Invalidate in RecacheProperties, but rather in PropertyChanged(). *)
		PROCEDURE RecacheProperties*;
		BEGIN
		END RecacheProperties;

		PROCEDURE InternalPropertyChanged(sender, property : ANY);
		BEGIN
			IF ~initialized THEN RETURN END;
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.InternalPropertyChanged, sender, property);
				IF CanYield THEN Objects.Yield END;
			ELSE
				IF ~inPropertyUpdate THEN
					inPropertyUpdate := TRUE;
					IF property = properties THEN RecacheProperties END;
					PropertyChanged(sender, property);
					inPropertyUpdate := FALSE
				END;
			END
		END InternalPropertyChanged;

		PROCEDURE InternalLinkChanged(sender, property : ANY);
		BEGIN
			IF ~initialized THEN RETURN END;
			IF ~IsCallFromSequencer() THEN
				sequencer.ScheduleEvent(SELF.InternalLinkChanged, sender, property);
				IF CanYield THEN Objects.Yield END;
			ELSE
				IF ~inLinkUpdate THEN
					inLinkUpdate := TRUE;
					LinkChanged(sender, property);
					inLinkUpdate := FALSE
				END;
			END
		END InternalLinkChanged;

	END Component;

TYPE

	Macro* = ARRAY 128 OF CHAR;

	(** Installable macro handler procedure. {(originator # NIL) & (w # NIL)} *)
	MacroHandlerProcedure* = PROCEDURE {DELEGATE} (CONST macro : Macro; originator : Component; w : Streams.Writer; VAR handled : BOOLEAN);

	Namespace = ARRAY 16 OF CHAR;

	MacroHandler = POINTER TO RECORD
		handler : MacroHandlerProcedure;
		namespace : Namespace;
		next : MacroHandler;
	END;

TYPE

	(** Basic visual component *)
	VisualComponent* = OBJECT(Component)
	VAR
		bounds-, bearing-, relativeBounds-: WMProperties.RectangleProperty;
		alignment- : WMProperties.Int32Property;
		fillColor- : WMProperties.ColorProperty;
		font- : WMProperties.FontProperty;
		scaleFont-: WMProperties.Int32Property;
		visible-, takesFocus-, needsTab-, editMode- : WMProperties.BooleanProperty;
		focusPrevious-, focusNext- : WMProperties.StringProperty;
		model- : WMProperties.ReferenceProperty;
		onStartDrag- : WMEvents.EventSource;
		canvasState- : WMGraphics.CanvasState; (** PROTECTED *)
		fPointerOwner : VisualComponent;
		hasFocus- : BOOLEAN;
		focusComponent : VisualComponent; (** Subcomponent that has the keyboard focus, if any *)
		extPointerDown, extPointerUp, extPointerMove : PointerHandler;
		extPointerLeave : PointerLeaveHandler;
		extDragOver, extDragDropped : DragDropHandler;
		extDragResult : DragResultHandler;
		extKeyEvent : KeyEventHandler;
		extDraw : DrawHandler;
		extFocus : FocusHandler;
		extContextMenu : ContextMenuHandler;
		extGetPositionOwner : GetPositionOwnerHandler;
		layoutManager : LayoutManager;
		aligning* : BOOLEAN;
		pointerInfo : WM.PointerInfo;
		editRegion: LONGINT;
		editX, editY: LONGINT;
		keyFlags: SET; (*! remove *)
		oldPointerInfo : WM.PointerInfo;


		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetGenerator("WMComponents.NewVisualComponent");
			SetNameAsString(StrVisualComponent);

			NEW(bounds, PrototypeBounds, NIL, NIL); properties.Add(bounds);
			NEW(relativeBounds, PrototypeBoundsRelative, NIL, NIL); properties.Add(relativeBounds);
			NEW(bearing, PrototypeBearing, NIL, NIL); properties.Add(bearing);
			NEW(alignment, PrototypeAlignment, NIL, NIL); properties.Add(alignment);
			NEW(fillColor, PrototypeFillColor, NIL, NIL); properties.Add(fillColor);
			NEW(visible, PrototypeVisible, NIL, NIL); properties.Add(visible);
			NEW(takesFocus, PrototypeTakesFocus, NIL, NIL); properties.Add(takesFocus);
			NEW(needsTab, PrototypeNeedsTab, NIL, NIL); properties.Add(needsTab);
			NEW(focusPrevious, PrototypeFocusPrevious, NIL, NIL); properties.Add(focusPrevious);
			NEW(focusNext, PrototypeFocusNext, NIL, NIL); properties.Add(focusNext);
			NEW(editMode, PrototypeEditMode, NIL,NIL); properties.Add(editMode); editMode.Set(FALSE);
			NEW(model, ModelPrototype, NIL, NIL); properties.Add(model);
			NEW(font, PrototypeFont, NIL, NIL); properties.Add(font);
			NEW(scaleFont, PrototypeScaleFont, NIL,NIL); properties.Add(scaleFont);

			NEW(onStartDrag, SELF, GSonStartDrag,GSonStartDragInfo, SELF.StringToCompCommand);
			events.Add(onStartDrag);
			extGetPositionOwner := NIL;

			aligning := FALSE; fPointerOwner := SELF; focusComponent := SELF;
		END Init;

		(** Focus handling *)
		PROCEDURE TraceFocusChain*;
		BEGIN
			KernelLog.String(" -> ");
			ShowComponent(SELF);
			IF focusComponent = SELF THEN
				KernelLog.String(" <END>"); KernelLog.Ln;
			ELSIF focusComponent = NIL THEN
				KernelLog.String("ERROR focusComponent is NIL"); KernelLog.Ln;
			ELSE
				focusComponent.TraceFocusChain;
			END;
		END TraceFocusChain;

		(** Set the keyboard focus chain to this component its takesFocus field is set and unset the old chain *)
		PROCEDURE SetFocus*;
		VAR root, vc : VisualComponent; p : XML.Element;
		BEGIN
			Acquire;
			IF (takesFocus.Get() OR editMode.Get()) & visible.Get() THEN
				IF TraceFocus IN Trace THEN KernelLog.String("Set focus to: "); ShowComponent(SELF); KernelLog.Ln; END;

				root := GetVisualComponentRoot();
				IF (root IS Form) THEN root(Form).lastFocusComponent := SELF; END;

				(* unset the old focus chain *)
				(* find the leaf component that has the focus *)
				vc := root;
				WHILE (vc # NIL) & (vc.focusComponent # NIL) & (vc.focusComponent # vc) DO vc := vc.focusComponent; END;

				(* clear the focus chain until the root or this component *)
				p := vc;
				WHILE (p # SELF) & (p # NIL) & (p IS VisualComponent) DO
					vc := p(VisualComponent);
					vc.focusComponent := vc;
					vc.FocusLost;
					IF (vc.extFocus # NIL) THEN vc.extFocus(FALSE); END;
					p := p.GetParent();
				END;

				(* set the new chain *)
				vc := SELF; vc.focusComponent := SELF;
				WHILE (vc # NIL) DO
					IF ~vc.hasFocus THEN
						vc.FocusReceived;
						IF vc.extFocus # NIL THEN vc.extFocus(TRUE) END;
					END;
					p := vc.GetParent();
					IF (p # NIL) & (p IS VisualComponent) THEN
						p(VisualComponent).focusComponent := vc; vc := p(VisualComponent);
					ELSE
						vc := NIL;
					END;
				END;
			ELSE (* component does not take focus or is not visible *)
				IF TraceFocus IN Trace THEN ShowComponent(SELF); KernelLog.String("does not take focus."); KernelLog.Ln END;
			END;
			Release;
		END SetFocus;

		PROCEDURE FocusReceived*;
		BEGIN
			hasFocus := TRUE
		END FocusReceived;

		PROCEDURE FocusLost*;
		BEGIN
			hasFocus := FALSE
		END FocusLost;

		PROCEDURE SetFocusTo(CONST id : ARRAY OF CHAR);
		VAR vc : Component;
		BEGIN
			vc := Find(id);
			IF (vc # NIL) & (vc IS VisualComponent) THEN
				vc(VisualComponent).SetFocus;
			ELSE
				KernelLog.String("Warning: WMComponents.VisualComponent.SetFocusTo: Component ");
				KernelLog.String(id); KernelLog.String(" not found."); KernelLog.Ln;
			END;
		END SetFocusTo;

		PROCEDURE FocusNext*;
		VAR string : Strings.String;
		BEGIN
			string := focusNext.Get();
			IF (string # NIL) THEN
				SetFocusTo(string^);
			END;
		END FocusNext;

		PROCEDURE FocusPrev*;
		VAR string : Strings.String;
		BEGIN
			string := focusPrevious.Get();
			IF (string # NIL) THEN
				SetFocusTo(string^);
			END;
		END FocusPrev;

		(* LinkChanged can be called to inform about changes of the state of links (i.e. objects in reference properties)
			Unlike PropertyChanged which informs about an actual replacement of the link *)
		PROCEDURE LinkChanged*(sender, link: ANY);
		BEGIN
			IF sender = model THEN
				Invalidate
			END;
		END LinkChanged;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		BEGIN
			IF property = bounds THEN
				(*ScaleFont(bounds.GetHeight(), scaleFont.Get());*)
				Resized (*implicit Invalidate*)
			ELSIF property = bearing THEN Resized;
			(* ELSIF bounds=relativeBounds  THEN ? *)
			ELSIF property = alignment THEN AlignmentChanged; Invalidate (*moved here from implicit Invalidate*)
			ELSIF property = fillColor THEN Invalidate;
			ELSIF property = font THEN
				IF scaleFont.Get() # 0 THEN
					ScaleFont(bounds.GetHeight(), scaleFont.Get()); (* implicit Invalidate*)
				END;
				Invalidate;
			ELSIF (property = scaleFont) THEN ScaleFont(bounds.GetHeight(),scaleFont.Get());  (*implicit Invalidate*)
			ELSIF property = visible THEN Resized (*Implicit Invalidate*)
			(* ELSIF takesFocus, needsTab...*)			
			ELSIF property = editMode THEN Invalidate;
			ELSIF property = model THEN LinkChanged(model, model.Get()); Invalidate;
			ELSE PropertyChanged^(sender, property)
			END;
		END PropertyChanged;

		PROCEDURE RecacheProperties;
		BEGIN
			RecacheProperties^;
			IF scaleFont.Get() # 0 THEN ScaleFont(bounds.GetHeight(), scaleFont.Get()) END;
			IF (model # NIL) & (model.Get() # NIL) THEN LinkChanged(model,model.Get()) END;
		END RecacheProperties;

		(** Get the root of visible components. Not neccessarily the same as GetComponentRoot() OR GetRoot() *)
		PROCEDURE GetVisualComponentRoot*(): VisualComponent;
		VAR p, c : XML.Element;
		BEGIN
			c := SELF;
			LOOP
				p := c.GetParent();
				IF (p # NIL) & (p IS VisualComponent) THEN c := p
				ELSE RETURN c(VisualComponent)
				END
			END
		END GetVisualComponentRoot;

		PROCEDURE AdaptRelativeBounds(inner: Rectangles.Rectangle; parent: XML.Element);
		VAR  outer: Rectangles.Rectangle;
		BEGIN
			Acquire;
			IF (parent # NIL) & (parent IS VisualComponent) THEN
				(* inner := bounds.Get();*)
				outer := parent(VisualComponent).bounds.Get();
				IF (outer.b - outer.t > 0) & (outer.r - outer.l > 0) THEN
					relativeBounds.Set(Rectangles.MakeRect( (inner.l * MaxRel) DIV (outer.r-outer.l), (inner.t * MaxRel) DIV (outer.b-outer.t),
						(inner.r * MaxRel) DIV (outer.r - outer.l), (inner.b * MaxRel) DIV (outer.b - outer.t)));
				END;
			END;
			Release
		END AdaptRelativeBounds;

		(** Position handling *)
		PROCEDURE AlignmentChanged;
		VAR p : XML.Element; inner, outer: Rectangles.Rectangle;
		BEGIN
			Acquire;
			IF alignment.Get()= AlignRelative THEN
				AdaptRelativeBounds(bounds.Get(), GetParent());
			END;
			p := SELF.GetParent();
			IF (p # NIL) & (p IS VisualComponent) THEN
				p(VisualComponent).AlignSubComponents
			END;
			(*Invalidate;*)
			Release
		END AlignmentChanged;

		(** Get the bounds of the component *)
		PROCEDURE GetClientRect*() : Rectangles.Rectangle;
		VAR r, t : Rectangles.Rectangle;
		BEGIN
			r := bounds.Get();
			t := Rectangles.MakeRect(0, 0, r.r - r.l, r.b - r.t);
			RETURN t
		END GetClientRect;

		PROCEDURE SetLayoutManager*(layoutManager : LayoutManager);
		BEGIN
			Acquire;
			SELF.layoutManager := layoutManager;
			Release
		END SetLayoutManager;

		PROCEDURE AlignEvent(sender, data: ANY);
		BEGIN
			AlignSubComponents;
		END AlignEvent;

		PROCEDURE AlignSubComponents*;
		VAR c : XML.Content; vc : VisualComponent;
			r, b, rel : Rectangles.Rectangle;
		BEGIN
			Acquire;
			IF (sequencer # NIL)  & ~IsCallFromSequencer() THEN 	sequencer.ScheduleEvent(SELF.AlignEvent, NIL,NIL); Release; RETURN
			ELSIF sequencer = NIL THEN Release; RETURN
			END;
			IF aligning THEN Release; RETURN END;
			DisableUpdate;
			aligning := TRUE;
			IF layoutManager # NIL THEN layoutManager(SELF)
			ELSE
				r := GetClientRect();
				c := GetFirst();
				WHILE (c # NIL) DO
					IF c IS VisualComponent THEN
						vc := c(VisualComponent);
						IF vc.visible.Get() THEN
							b := vc.bearing.Get();
							CASE vc.alignment.Get() OF
							| AlignTop : vc.bounds.Set(Rectangles.MakeRect(r.l + b.l , r.t + b.t, r.r - b.r, r.t + b.t + vc.bounds.GetHeight())); INC(r.t, vc.bounds.GetHeight() + b.t + b.b)
							| AlignLeft : vc.bounds.Set(Rectangles.MakeRect(r.l + b.l, r.t + b.t, r.l + b.l + vc.bounds.GetWidth(), r.b - b.b)); INC(r.l, vc.bounds.GetWidth() + b.l + b.r)
							| AlignBottom : vc.bounds.Set(Rectangles.MakeRect(r.l + b.l, r.b - vc.bounds.GetHeight() - b.b, r.r - b.r, r.b - b.b)); DEC(r.b, vc.bounds.GetHeight() + b.t + b.b)
							| AlignRight : vc.bounds.Set(Rectangles.MakeRect(r.r - vc.bounds.GetWidth() - b.r , r.t + b.t, r.r - b.r, r.b - b.b)); DEC(r.r, vc.bounds.GetWidth() + b.l + b.r);
							| AlignClient : IF ~Rectangles.RectEmpty(r) THEN vc.bounds.Set(Rectangles.MakeRect(r.l + b.l , r.t + b.t, r.r - b.r, r.b  - b.b)) END
							| AlignRelative:
								IF ~editMode.Get() THEN
									rel := vc.relativeBounds.Get();
									vc.bounds.Set(Rectangles.MakeRect(r.l + ((r.r-r.l)*rel.l+MaxRel DIV 2) DIV MaxRel, r.t + ((r.b-r.t)*rel.t+MaxRel DIV 2) DIV MaxRel,
													r.l + ((r.r-r.l)*rel.r +MaxRel DIV 2) DIV MaxRel, r.t+((r.b-r.t)*rel.b + MaxRel DIV 2) DIV MaxRel));
								ELSE
									vc.AdaptRelativeBounds(vc.bounds.Get(),SELF);
								END;
							ELSE (* nothing *)
							END;
						END;
					END;
					c := GetNext(c);
				END;
			END;
			EnableUpdate;
			aligning := FALSE;
			Release;
		END AlignSubComponents;

		PROCEDURE Initialize*;
		BEGIN
			Initialize^;
			AlignSubComponents;
		END Initialize;

	(** Locating *)
		(** transform the local component coordinates into global window manager coordinates *)
		PROCEDURE ToWMCoordinates*(x, y : LONGINT; VAR gx, gy : LONGINT);
		VAR cr : Component; tc : XML.Element; r : Rectangles.Rectangle;
		BEGIN
			gx := x; gy := y; tc := SELF;
			REPEAT
				IF (tc # NIL) & (tc IS VisualComponent) THEN
					r := tc(VisualComponent).bounds.Get();
					INC(gx, r.l); INC(gy, r.t)
				END;
				tc := tc.GetParent()
			UNTIL (tc = NIL) OR ~(tc IS VisualComponent);
			cr := GetComponentRoot();
			IF (cr # NIL) & (cr IS Form) THEN
				INC(gx, cr(Form).window.bounds.l);
				INC(gy, cr(Form).window.bounds.t)
			END
		END ToWMCoordinates;

		(** Return if the component is hit at (x, y) in component coordinates *)
		PROCEDURE IsHit*(x, y: LONGINT): BOOLEAN;
		BEGIN
			RETURN visible.Get() & enabled.Get() &  Rectangles.PointInRect(x, y, GetClientRect())
		END IsHit;

		(** Return the topmost first child component at (x, y) *)
		PROCEDURE GetPositionOwner*(x, y: LONGINT): VisualComponent;
		VAR c: XML.Content; result, vc : VisualComponent; r : Rectangles.Rectangle;
		BEGIN
			Acquire;
			result := SELF;
			c := GetFirst();
			WHILE (c # NIL) DO
				IF c IS VisualComponent THEN
					vc := c(VisualComponent);
					r := vc.bounds.Get();
					IF Rectangles.PointInRect(x, y, r) & vc.IsHit(x - r.l, y - r.t)  THEN
						result := vc
					END;
				END;
				c := GetNext(c);
			END;
			Release;
			RETURN result
		END GetPositionOwner;

		(** DragOver is called via the message handler. The should call manager.SetDragAccept(SELF, .... *)
		PROCEDURE DragOver*(x, y: LONGINT; dragInfo : WM.DragInfo);
		END DragOver;

		(** Dropped is called via the message handler to indicate an item has been dropped. *)
		PROCEDURE DragDropped*(x, y: LONGINT; dragInfo : WM.DragInfo);
		BEGIN
			IF dragInfo.onReject # NIL THEN dragInfo.onReject(SELF,dragInfo) END;
		END DragDropped;

		(*
		PROCEDURE EditDragOver(x,y: LONGINT; dragInfo: WMWindowManager.DragInfo);
		BEGIN
		END EditDragOver;
		*)

		PROCEDURE FromXML(xml: XML.Element);
		BEGIN
			FromXML^(xml);
		END FromXML;

		(*
		PROCEDURE AddContent*(c : XML.Content);
		VAR m:Messages.Message;
		BEGIN
			AddContent^(c);
			IF c IS VisualComponent THEN
				m.sender:=SELF (*c*); (*move to VisualComponent ?*)
				m.msgType := Messages.MsgInvalidate;
				m.msgSubType := Messages.MsgSubAll;
				(* SELF(VisualComponent).Invalidate ...*)
				IF sequencer.Add(m) THEN  END; 
			END;
		END AddContent;
		*)


		PROCEDURE AddVisualComponent(c :VisualComponent; x, y : LONGINT);
		VAR bounds : Rectangles.Rectangle;canvas: WMGraphics.BufferCanvas; relativeAlignment: BOOLEAN;
		BEGIN
			ASSERT(c # NIL);
			
			IF (c.bounds.GetWidth() < 10) OR (c.bounds.GetHeight() < 10) THEN
				c.bounds.SetExtents(40, 20);
			END;
			bounds := c.bounds.Get();
			Rectangles.MoveRel(bounds, x, y);
			c.bounds.Set(bounds);
			c.AdaptRelativeBounds(c.bounds.Get(), SELF);
			(*
			IF c.sequencer # sequencer THEN c.SetSequencer(sequencer) END; (* redundant - implicit in AddContent *)
			c.Reset(NIL, NIL); (*currently redundant - already in happens Component.AddContent() *)
			c.RecacheProperties; (*currently redundant - already in happens Reset() *)
			*)
			Acquire;
			AddContent(c);
			Release;
		END AddVisualComponent;
		
		PROCEDURE EditDragDropped(x,y: LONGINT; dragInfo: WM.DragInfo): BOOLEAN;
		VAR data: ANY; e: ComponentListEntry; parent: XML.Element; dt: DropTarget; pos: LONGINT;
		BEGIN
			data := dragInfo.data;
			IF (data # NIL) & (data IS VisualComponent)  THEN
				IF dragInfo.sender # SELF THEN
					IF dragInfo.onAccept # NIL THEN dragInfo.onAccept(SELF,dragInfo) END;
					data(VisualComponent).bounds.Set(Rectangles.MakeRect(0, 0, data(VisualComponent).bounds.GetWidth(), data(VisualComponent).bounds.GetHeight()));
					AddVisualComponent(data(VisualComponent),x+dragInfo.offsetX,y+dragInfo.offsetY);
					Invalidate;
				ELSE
					parent := GetParent();
					IF parent = NIL THEN RETURN FALSE END;
					x := x + bounds.GetLeft();
					y := y + bounds.GetTop();
					RETURN parent(VisualComponent).EditDragDropped(x,y,dragInfo);
				END;
				RETURN TRUE
			ELSIF (data # NIL) & (data IS Repositories.Component) THEN
				IF dragInfo.onAccept # NIL THEN dragInfo.onAccept(SELF,dragInfo) END;
				model.Set(data(Repositories.Component));
				RETURN TRUE
			ELSIF (data # NIL) & (data IS SelectionList) THEN
				IF (dragInfo.sender # SELF) & ~data(SelectionList).Has(SELF) THEN
					IF dragInfo.onAccept # NIL THEN dragInfo.onAccept(SELF,dragInfo) END;
					e := data(SelectionList).first;
					WHILE e # NIL DO
						e.component.bounds.Set(Rectangles.MakeRect(0, 0, e.component.bounds.GetWidth(), e.component.bounds.GetHeight()));
						ASSERT(e.component IS VisualComponent);
						AddVisualComponent(e.component,x+e.dx+dragInfo.offsetX, y+e.dy + dragInfo.offsetY);
						e := e.next;
					END;
					Invalidate;
				ELSE
					parent := GetParent();
					IF parent = NIL THEN RETURN FALSE END;
					x := x + bounds.GetLeft();
					y := y + bounds.GetTop();
					RETURN parent(VisualComponent).EditDragDropped(x,y,dragInfo);
				END;
				RETURN TRUE
			ELSE
				NEW(dt, SELF, SetDroppedString, x,y);
				dragInfo.data := dt;
				ConfirmDrag(TRUE, dragInfo);
				RETURN FALSE
			END;
		END EditDragDropped;

		PROCEDURE SetDroppedString( CONST string : ARRAY OF CHAR; x,y : LONGINT; VAR res : LONGINT);
		VAR gen: XML.GeneratorProcedure; moduleName, procedureName ,msg: Modules.Name; element: XML.Element;
			context: Repositories.Context; repositoryName, componentName: ARRAY 265 OF CHAR; componentID: LONGINT; object: Repositories.Component;
		BEGIN
			Commands.Split(string, moduleName, procedureName, res, msg);
			IF (res = Commands.Ok) THEN
				GETPROCEDURE(moduleName, procedureName, gen);
			END;
			IF gen # NIL THEN
				element := gen();
			ELSIF Repositories.IsCommandString(string) THEN
				Repositories.CallCommand(string, context, res);
				IF (res = Repositories.Ok) & (context.object # NIL) & (context.object IS Repositories.Component) THEN
					element := context.object(Repositories.Component);
				END;
			ELSIF Repositories.SplitName(string, repositoryName, componentName, componentID) THEN
				Repositories.GetComponent(repositoryName, componentName, componentID, object, res);
				element := object;
			END;

			IF (element # NIL) & (element IS VisualComponent) THEN
				AddVisualComponent(element(VisualComponent),x,y);
				Invalidate;
			ELSIF (element # NIL) & (element IS Repositories.Component) THEN
				model.Set(element(Repositories.Component))
			END;
			res := 1; (* to avoid removal of source *)
		END SetDroppedString;

		(** Is called via the message handler to inform about the result of a recent drag operation *)
		PROCEDURE DragResult*(accepted : BOOLEAN; recipient : ANY; dragInfo : WM.DragInfo);
		END DragResult;

		(** Start a drag operation. *)
		PROCEDURE StartDrag*(data : ANY; img : WMGraphics.Image; offsetX, offsetY: LONGINT; onAccept, onReject : Messages.CompCommand) : BOOLEAN;
		VAR rc : Component;
		BEGIN
			rc := GetVisualComponentRoot();
			IF (rc # NIL) & (rc IS Form) THEN
				RETURN rc(Form).window.StartDrag(SELF, data, img, offsetX, offsetY, onAccept, onReject)
			ELSE
				RETURN FALSE
			END
		END StartDrag;

		(** confirm a drag operation. *)
		PROCEDURE ConfirmDrag*(accept : BOOLEAN; dragInfo : WM.DragInfo);
		VAR rc : Component;
		BEGIN
			rc := GetVisualComponentRoot();
			IF (rc # NIL) & (rc IS Form) THEN rc(Form).window.ConfirmDrag(accept, dragInfo)
			END
		END ConfirmDrag;

		(** Is called by the component if it detects a default drag action. The subclass should then call StartDrag with
			the respective coordinates. If it wants to start the drag operation *)
		PROCEDURE AutoStartDrag*;
		BEGIN
			onStartDrag.Call(NIL)
		END AutoStartDrag;

		(** Is called by the component if it detects a request for a context menu. The subclass should open the
		context menu if applicable *)
		PROCEDURE ShowContextMenu*(x, y : LONGINT);
		BEGIN
			IF extContextMenu # NIL THEN extContextMenu(SELF, x, y) END;
		END ShowContextMenu;

	(** Special methods *)
		PROCEDURE Resized*;
		VAR p : XML.Element;
		BEGIN
			(*
			AdaptRelativeBounds(GetParent());
			*)
			IF sequencer # NIL THEN ASSERT(sequencer.lock.HasWriteLock()) END;
			DisableUpdate;
			p := SELF.GetParent();
			IF  (p # NIL) & (p IS VisualComponent) & (alignment.Get() # AlignNone) THEN p(VisualComponent).AlignSubComponents END;
			IF visible.Get() THEN
				AlignSubComponents;
				IF scaleFont.Get() # 0 THEN ScaleFont(bounds.GetHeight(), scaleFont.Get()) END;
			END;
			EnableUpdate;
			IF (p # NIL) & (p IS VisualComponent) THEN p(VisualComponent).Invalidate
			ELSE Invalidate()
			END
		END Resized;

		(** Is called before any sub-components are drawn *)
		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		VAR color : LONGINT; name:Strings.String;
		BEGIN
			(* message tracing
			IF sequencer = Messages.debug THEN
				D.Enter;
				D.Ln;
				D.String("##############"); D.Ln;
				name := GetName();
				IF name # NIL THEN D.String(name^); D.Ln; END;
				name := id.Get();
				IF name # NIL THEN D.String(name^); D.Ln; END;
				D.Int(Kernel.GetTicks(),1); D.Ln;
				(*D.TraceBack;*)
				D.Exit;
			END;
			*)
			CheckReadLock;
			color := fillColor.Get();
			IF color # 0 THEN canvas.Fill(GetClientRect(), color, WMGraphics.ModeSrcOverDst) END;
		END DrawBackground;

		(** Is called after all sub-components are drawn *)
		PROCEDURE DrawForeground*(canvas : WMGraphics.Canvas);
		END DrawForeground;

		PROCEDURE DrawSelection(canvas : WMGraphics.Canvas);
		VAR r,r0: Rectangles.Rectangle; x,y,x0,y0: LONGINT; color: LONGINT;

			PROCEDURE MarkSelected(r: Rectangles.Rectangle; w, color: LONGINT);
			VAR r0: Rectangles.Rectangle;
			BEGIN
				r0 :=r; r0.r := r.l+w; r0.b := r.t+w;
				canvas.Fill(r0, color, WMGraphics.ModeSrcOverDst);
				r0 :=r; r0.r := r.l+w; r0.t := r.b-w;
				canvas.Fill(r0, color, WMGraphics.ModeSrcOverDst);
				r0 :=r; r0.l := r.r-w; r0.b := r.t+w;
				canvas.Fill(r0, color, WMGraphics.ModeSrcOverDst);
				r0 :=r; r0.l := r.r-w; r0.t := r.b-w;
				canvas.Fill(r0, color, WMGraphics.ModeSrcOverDst);

				r0 := r; r0.l := r.r-1; canvas.Fill(r0,color, WMGraphics.ModeSrcOverDst);
				r0 := r; r0.r := r.l+1; canvas.Fill(r0,color, WMGraphics.ModeSrcOverDst);
				r0 := r; r0.b := r.t+1; canvas.Fill(r0,color, WMGraphics.ModeSrcOverDst);
				r0 := r; r0.t := r.b-1; canvas.Fill(r0,color, WMGraphics.ModeSrcOverDst);

			END MarkSelected;

		BEGIN
			CheckReadLock;
			r := GetClientRect();
			IF editMode.Get() THEN
				y := r.t + (-r.t) MOD 8;
				y0 := 0;
				WHILE y < r.b DO
					r0.t := y; r0.b := y+2;
					x := r.l + (-r.l) MOD 8;  x0 := 0;
					WHILE x < r.r DO
						r0.l := x; r0.r := x+2;
						IF ODD(x DIV 8+y DIV 8) THEN color := 060H;
						ELSE color := LONGINT(0FFFFFF60H);
						END;
						canvas.Fill(r0,color, WMGraphics.ModeSrcOverDst);
						INC(x,8); INC(x0);
					END;
					INC(y,8);INC(y0);
				END;
			END;
			IF selection.Has(SELF) THEN
				IF selection.state = 0 THEN
					MarkSelected(r,8,LONGINT(080H));
				ELSE
					MarkSelected(r,8,LONGINT(0FFFFFFFF80H));
				END;
			END;
		END DrawSelection;


		PROCEDURE DrawSubComponents*(canvas : WMGraphics.Canvas);
		VAR c : XML.Content; vc : VisualComponent; cr, r : Rectangles.Rectangle;
		BEGIN
			CheckReadLock;
			canvas.GetClipRect(cr);
			canvas.SaveState(canvasState);
			(* draw all sub-components *)
			c := GetFirst();
			WHILE (c # NIL) DO
				IF c IS VisualComponent THEN
					vc := c(VisualComponent); r := vc.bounds.Get();
					IF Rectangles.Intersect(r, cr) THEN (* only draw if the component has a chance to be visible *)
						canvas.SetClipRect(r); canvas.SetClipMode({WMGraphics.ClipRect});
						canvas.ClipRectAsNewLimits(r.l,  r.t);
						vc.Draw(canvas);
						canvas.RestoreState(canvasState);
					END;
				END;
				c := GetNext(c);
			END;
		END DrawSubComponents;

		PROCEDURE GetFont*() : WMGraphics.Font;
		BEGIN
			IF font.Get() = NIL THEN RETURN WMGraphics.GetDefaultFont()
			ELSE RETURN font.Get()
			END
		END GetFont;

		PROCEDURE SetFont*(font : WMGraphics.Font);
		BEGIN
			Acquire;
			IF SELF.font.Get() # font THEN
				SELF.font.Set(font);
				(*?Invalidate()*) (* Invalidate already in PropertyChanged() *)
			END;
			Release
		END SetFont;

		PROCEDURE ScaleFont*(height: LONGINT; percent: LONGINT);
		VAR fh,newSize: LONGINT; f: WMGraphics.Font;
		BEGIN
			IF height < 4 THEN height := 4 END;
			IF percent <= 0 THEN RETURN END;
			Acquire;
			f := GetFont();
			f := WMGraphics.GetFont(f.name, 100, f.style); (* expensive ? *)
			fh := f.GetAscent() + f.GetDescent();
			fh := height * percent DIV fh;

			IF fh > 100 THEN fh := fh - fh MOD 8
			ELSIF fh > 32 THEN fh := fh - fh MOD 4
			ELSIF fh > 12 THEN fh := fh - fh MOD 2
			END;
			IF font.GetSize() # fh THEN
				font.SetSize(fh);
				Invalidate;
			END;
			Release;
		END ScaleFont;

		(** Called by the component owner whenever a redraw to a canvas is needed. Caller must hold hierarchy lock *)
		PROCEDURE Draw*(canvas : WMGraphics.Canvas);
		VAR command: Strings.String; event: Event;
		BEGIN
			(*
				can lead to deadlock:
				we hold the lock "lock"
				onDraw tries to get the Objects lock, but this may be held by other component (should better not, but did, dead: WMPartitionsComponents.OperationEventHandler


			command := GetAttributeValue("onDraw");
			IF (command # NIL) THEN HandleEvent(event, SELF, command); END;
			*)
			CheckReadLock;
			IF ~visible.Get() THEN RETURN END;
			canvas.SaveState(canvasState);
			IF font # NIL THEN canvas.SetFont(font.Get()) END;
			DrawBackground(canvas);
			IF extDraw # NIL THEN extDraw(canvas) END;
			DrawSelection(canvas);
			DrawSubComponents(canvas);
			DrawForeground(canvas);
			canvas.RestoreState(canvasState)
		END Draw;

		(** declare a rectangle area as dirty *)
		PROCEDURE InvalidateRect*(r: Rectangles.Rectangle);
		VAR parent : XML.Element;
			m : Messages.Message; b : Rectangles.Rectangle;
		BEGIN
			IF ~initialized THEN RETURN END;
			IF ~visible.Get() THEN RETURN END;
			IF ~IsCallFromSequencer() THEN
				m.msgType := Messages.MsgInvalidate;
				m.msgSubType := Messages.MsgSubRectangle;
				(*
				m.msgType := Messages.MsgExt;
				m.ext := invalidateRectMsg;
				*)
				m.x := r.l; m.y := r.t; m.dx := r.r; m.dy := r.b; m.sender := SELF;
				IF sequencer.Add(m) THEN IF CanYield THEN Objects.Yield END END;
			ELSE
				parent := GetParent();
				IF (parent # NIL) & (parent IS VisualComponent) THEN
					b := bounds.Get();
					Rectangles.MoveRel(r, b.l, b.t);
					parent(VisualComponent).InvalidateRect(r)
				END
			END
		END InvalidateRect;

		PROCEDURE InvalidateCommand*(sender, par : ANY);
		VAR m: Messages.Message; r, b: Rectangles.Rectangle; client: VisualComponent; parent: XML.Element;
		BEGIN
			IF ~initialized OR ~visible.Get() THEN RETURN END; (*? double call to visible.Get here and below. Which one is better ?*)
			IF ~IsCallFromSequencer() OR ~visible.Get() THEN
				r := GetClientRect();
				client := SELF;
				parent := GetParent();
				WHILE (parent # NIL) & (parent IS VisualComponent) DO
					IF ~parent(VisualComponent).visible.Get() THEN RETURN END;
					b := client.bounds.Get();
					Rectangles.MoveRel(r, b.l, b.t);
					client := parent(VisualComponent);
					parent := client.GetParent();
				END;
				m.msgType := Messages.MsgInvalidate;
				m.msgSubType := Messages.MsgSubRectangle;
				m.x := r.l; m.y := r.t; m.dx := r.r; m.dy := r.b;
				m.sender := client;
				IF sequencer.Add(m) THEN IF CanYield THEN Objects.Yield END END;
			ELSE
				InvalidateRect(GetClientRect());
			END;
		END InvalidateCommand;

		PROCEDURE Invalidate*; (* For convenience in component internal use *)
		BEGIN
			InvalidateCommand(SELF, NIL)
		END Invalidate;

		(** recursively disable the redrawing of any components in the hierarchy *)
		(** dont forget to re-enable it ;-). Use with care to optimize sub-component operations *)
		PROCEDURE DisableUpdate*;
		VAR vc: VisualComponent;
		BEGIN
			ASSERT(IsCallFromSequencer());
			vc := GetVisualComponentRoot();
			IF (vc # NIL) & (vc IS Form) THEN  vc(Form).DisableUpdate() END
		END DisableUpdate;

		(** recursively enable the redrawing of any components in the hierarchy *)
		(** Only enable drawing if it was disabled before, but dont forget it, then ! *)
		PROCEDURE EnableUpdate*;
		VAR vc: VisualComponent;
		BEGIN
			ASSERT(IsCallFromSequencer());
			vc := GetVisualComponentRoot();
			IF (vc # NIL) & (vc IS Form) THEN  vc(Form).EnableUpdate() END
		END EnableUpdate;

		PROCEDURE GetInternalPointerInfo*() : WM.PointerInfo;
		VAR vc: VisualComponent;
		BEGIN
			ASSERT(IsCallFromSequencer());
			vc := GetVisualComponentRoot();
			IF (vc # NIL) & (vc IS Form) THEN
				RETURN vc(Form).GetPointerInfo()
			ELSE
				RETURN NIL
			END
		END GetInternalPointerInfo;

		PROCEDURE SetInternalPointerInfo*(pi : WM.PointerInfo);
		VAR vc: VisualComponent;
		BEGIN
			AssertLock;
			vc := GetVisualComponentRoot();
			IF (vc # NIL) & (vc IS Form) THEN vc(Form).SetPointerInfo(pi) END
		END SetInternalPointerInfo;

		PROCEDURE SetPointerInfo*(pi : WM.PointerInfo);
		BEGIN
			Acquire;
			SetInternalPointerInfo(pi);
			pointerInfo := pi;
			Release
		END SetPointerInfo;

		PROCEDURE GetPointerInfo*() : WM.PointerInfo;
		BEGIN
			RETURN pointerInfo
		END GetPointerInfo;

	(**  User interaction messages *)
		PROCEDURE SetExtPointerLeaveHandler*(handler : PointerLeaveHandler);
		BEGIN
			Acquire; extPointerLeave := handler; Release
		END SetExtPointerLeaveHandler;

		PROCEDURE SetExtPointerDownHandler*(handler : PointerHandler);
		BEGIN
			Acquire; extPointerDown := handler; Release
		END SetExtPointerDownHandler;

		PROCEDURE SetExtPointerMoveHandler*(handler : PointerHandler);
		BEGIN
			Acquire; extPointerMove := handler; Release
		END SetExtPointerMoveHandler;

		PROCEDURE SetExtPointerUpHandler*(handler : PointerHandler);
		BEGIN
			Acquire; extPointerUp := handler; Release
		END SetExtPointerUpHandler;

		PROCEDURE SetExtDragOverHandler*(handler : DragDropHandler);
		BEGIN
			Acquire; extDragOver := handler; Release
		END SetExtDragOverHandler;

		PROCEDURE SetExtDragDroppedHandler*(handler : DragDropHandler);
		BEGIN
			Acquire; extDragDropped := handler; Release
		END SetExtDragDroppedHandler;

		PROCEDURE SetExtDragResultHandler*(handler : DragResultHandler);
		BEGIN
			Acquire; extDragResult := handler; Release
		END SetExtDragResultHandler;

		PROCEDURE SetExtKeyEventHandler*(handler : KeyEventHandler);
		BEGIN
			Acquire; extKeyEvent := handler; Release
		END SetExtKeyEventHandler;

		PROCEDURE SetExtDrawHandler*(handler : DrawHandler);
		BEGIN
			Acquire; extDraw := handler; Release
		END SetExtDrawHandler;

		PROCEDURE SetExtFocusHandler*(handler : FocusHandler);
		BEGIN
			Acquire; extFocus := handler; Release
		END SetExtFocusHandler;

		PROCEDURE SetExtContextMenuHandler*(handler : ContextMenuHandler);
		BEGIN
			Acquire; extContextMenu := handler; Release
		END SetExtContextMenuHandler;

		PROCEDURE SetExtGetPositionOwnerHandler*(handler : GetPositionOwnerHandler);
		BEGIN
			Acquire; extGetPositionOwner := handler; Release;
		END SetExtGetPositionOwnerHandler;

		(** Indicates the pointing device has left the component without a key pressed down.
			May only be called from the sequencer thread.
			Components interested in this message can override this method instead of searching for the message in HandleInternal. *)
		PROCEDURE PointerLeave*; (** PROTECTED *)
		BEGIN ASSERT(IsCallFromSequencer());
		END PointerLeave;

	(** Indicates one of the pointer keys went down. keys is the set of buttons currently pressed. x, y is the position in component
		coordinates.
		May only be called from the sequencer thread.
		Components interested in this message can override this method instead of searching for the message in HandleInternal. *)
		PROCEDURE PointerDown*(x, y: LONGINT; keys: SET); (** PROTECTED *)
		BEGIN ASSERT(IsCallFromSequencer());
			IF keys = {2} THEN ShowContextMenu(x, y)
			END;
		END PointerDown;

	(** Indicates the pointer was moved. keys is the set of buttons currently pressed. x, y is the position in component
		coordinates.
		May only be called from the sequencer thread.
		Components interested in this message can override this method instead of searching for the message in HandleInternal. *)
		PROCEDURE PointerMove*(x, y: LONGINT; keys: SET); (** PROTECTED *)
		BEGIN ASSERT(IsCallFromSequencer());
		END PointerMove;

		PROCEDURE WheelMove*(dz: LONGINT); (** PROTECTED *)
		BEGIN ASSERT(IsCallFromSequencer());
		END WheelMove;

	(** Indicates one of the pointer keys went up. keys is the set of buttons currently pressed. x, y is the position in component
		coordinates.
		May only be called from the sequencer thread.
		Components interested in this message can override this method instead of searching for the message in HandleInternal. *)
		PROCEDURE PointerUp*(x, y: LONGINT; keys: SET); (** PROTECTED *)
		BEGIN ASSERT(IsCallFromSequencer());
		END PointerUp;

	(** The component can determine wheter the key was pressed or released by examining the
		Inputs.Release flag in flags. ucs contains the unicode equivalent of the key. Special input editors
		send the generated unicode characters via KeyEvent.
		May only be called from the sequencer thread.
		Components interested in this message can override this method instead of searching for the message in HandleInternal. *)
		PROCEDURE KeyEvent*(ucs : LONGINT; flags: SET; VAR keySym: LONGINT); (** PROTECTED *)
		BEGIN ASSERT(IsCallFromSequencer());
		END KeyEvent;

		PROCEDURE EditKeyEvents(ucs : LONGINT; flags: SET; VAR keySym: LONGINT): BOOLEAN; (** FINAL *)
		VAR event : KeyPressedEvent; command : Strings.String; scale: LONGINT;
			clone: Repositories.Component; parent: XML.Content; parentEditMode: BOOLEAN;
			enum: XMLObjects.Enumerator; obj: ANY;
		BEGIN
			ASSERT(IsCallFromSequencer());
			event.ucs := ucs; event.flags := flags; event.keysym := keySym;

			parent := GetParent();
			IF (parent # NIL) & (parent IS VisualComponent) & parent(VisualComponent).editMode.Get() THEN
				parentEditMode := TRUE
			ELSE
				parentEditMode := FALSE
			END;

			IF ({Inputs.Release} * flags = {}) THEN
				IF (keySym = Inputs.KsF1) & (Inputs.Shift * flags # {}) THEN
					SetEditMode(~editMode.Get(), FALSE);
					RETURN TRUE
				ELSIF (keySym = Inputs.KsEscape) THEN
					selection.Reset(NIL);
					RETURN FALSE
				ELSIF parentEditMode OR editMode.Get() THEN
					IF Inputs.Shift * flags # {} THEN scale := 1 ELSE scale := 4 END;
					IF keySym = Inputs.KsLeft THEN selection.Shift(-scale,0); RETURN TRUE
					ELSIF keySym = Inputs.KsRight THEN selection.Shift(scale,0); RETURN TRUE
					ELSIF keySym = Inputs.KsDown THEN selection.Shift(0,scale); RETURN TRUE
					ELSIF keySym = Inputs.KsUp THEN selection.Shift(0,-scale); RETURN TRUE
					ELSIF keySym=4 (* CTRL-D *) THEN
						clone := Clone(selection.first.component);
						parent := selection.first.component.GetParent(); parent(Component).AddContent(clone);
						RETURN TRUE
					ELSIF keySym=1 THEN (* CTRL-A *)
						enum := GetContents();
						WHILE enum.HasMoreElements() DO
							obj := enum.GetNext();
							IF obj IS VisualComponent THEN
								selection.Add(obj(VisualComponent))
							END;
						END;
					ELSIF keySym = Inputs.KsDelete THEN
						RemoveSelection();
						RETURN TRUE
					END;
				END
			END;
			RETURN FALSE;
		END EditKeyEvents;


		PROCEDURE CheckKeyEvents(ucs : LONGINT; flags: SET; VAR keySym: LONGINT); (** FINAL *)
		VAR event : KeyPressedEvent; command : Strings.String; scale: LONGINT; clone: Repositories.Component; parent: XML.Content;
		BEGIN
			ASSERT(IsCallFromSequencer());
			event.ucs := ucs; event.flags := flags; event.keysym := keySym;

			IF ({Inputs.Release} * flags = {}) THEN
				IF (keySym = Inputs.KsReturn) THEN
					command := GetAttributeValue("onReturn");
				ELSIF (keySym = Inputs.KsEscape) THEN
					command := GetAttributeValue("onEscape");
					selection.Reset(NIL);
				(*ELSIF (keySym = Inputs.KsF1) & (Inputs.Shift * flags # {}) THEN
					SetEditMode(~editMode.Get(), TRUE);
				   ELSIF editMode.Get() THEN
					IF Inputs.Shift * flags # {} THEN scale := 1 ELSE scale := 4 END;
					IF keySym = Inputs.KsLeft THEN selection.Shift(-scale,0)
					ELSIF keySym = Inputs.KsRight THEN selection.Shift(scale,0)
					ELSIF keySym = Inputs.KsDown THEN selection.Shift(0,scale)
					ELSIF keySym = Inputs.KsUp THEN selection.Shift(0,-scale)
					ELSIF keySym=4 (* CTRL-D *) THEN
						clone := Clone(selection.first.component);
						parent := selection.first.component.GetParent(); parent(Component).AddContent(clone);
					ELSIF keySym = Inputs.KsDelete THEN
						RemoveSelection();
					END;
				*)
				END;
				IF (command # NIL) THEN HandleEvent(event, SELF, command); END;

				command := GetAttributeValue("onKeyPressed");
				IF (command # NIL) THEN HandleEvent(event, SELF, command); END;
			ELSE
				command := GetAttributeValue("onKeyReleased");
				IF (command # NIL) THEN HandleEvent(event, SELF, command); END;
			END;
		END CheckKeyEvents;

		PROCEDURE CheckPointerEvent(x, y, z : LONGINT; keys : SET);
		VAR event : PointerEvent; command : Strings.String;
		BEGIN
			ASSERT(IsCallFromSequencer());
			event.x := x; event.y := y; event.z := z; event.keys := keys;

			IF ({0} * keys = {0}) THEN
				command := GetAttributeValue("onLeftClick");
			ELSIF ({2} * keys = {2}) THEN
				command := GetAttributeValue("onRightClick");
			ELSIF ({1} * keys = {1}) THEN
				command := GetAttributeValue("onMiddleClick");
			END;
			IF (command # NIL) THEN HandleEvent(event, SELF, command); END;

			command := GetAttributeValue("onClick");
			IF (command # NIL) THEN HandleEvent(event, SELF, command); END;
		END CheckPointerEvent;

		PROCEDURE CheckPointerUpEvent(x, y, z : LONGINT; keys : SET);
		VAR event : PointerEvent; command : Strings.String;
		BEGIN
			ASSERT(IsCallFromSequencer());
			event.x := x; event.y := y; event.z := z; event.keys := keys;

			command := GetAttributeValue("onRelease");
			IF (command # NIL) THEN HandleEvent(event, SELF, command); END;
		END CheckPointerUpEvent;

		PROCEDURE InEditBounds(x,y: LONGINT): LONGINT;
		CONST Border = 8;
		VAR left, right, top, bottom: LONGINT;
		BEGIN
			left := bounds.GetLeft();
			right := bounds.GetRight();
			top := bounds.GetTop();
			bottom := bounds.GetBottom();

			INC(x,left); INC(y,top); (* relative -> absolute *)

			IF  (ABS(left-x) <= Border) THEN
				IF  (ABS(top-y) <= Border) THEN
					RETURN UpperLeft
				ELSIF (ABS(bottom-y) <= Border) THEN
					RETURN LowerLeft
				ELSE
					RETURN Left
				END
			ELSIF (ABS(right-x) <= Border)  THEN
				IF  (ABS(top-y) <= Border) THEN
					RETURN UpperRight
				ELSIF (ABS(bottom-y) <= Border) THEN
					RETURN LowerRight
				ELSE
					RETURN Right
				END
			ELSIF  (ABS(y-top) <= Border) THEN
				RETURN Upper
			ELSIF (ABS(bottom-y) <= Border) THEN
				RETURN Lower
			ELSIF (x > left+Border) & (x < right-Border) & (y > top+Border) & (y< bottom-Border) THEN
				RETURN Inside
			ELSE
				RETURN None
			END;
		END InEditBounds;

		PROCEDURE Edit(VAR msg: Messages.Message);
		VAR region: LONGINT; dx,dy: LONGINT; b: Rectangles.Rectangle; manager: WM.WindowManager;
			w,h: LONGINT; img: WMGraphics.Image; canvas: WMGraphics.BufferCanvas; e: ComponentListEntry;
			alignRelative : BOOLEAN;
		BEGIN
			IF msg.msgSubType = Messages.MsgSubPointerUp THEN
				editRegion := None;
				SetPointerInfo(oldPointerInfo);
				RETURN
			END;
			dx := msg.x-editX; dy := msg.y-editY;
			b := bounds.Get();
			IF editRegion = Right THEN
				b.r := b.r + dx
			ELSIF editRegion = Left THEN
				b.l := b.l + dx; dx := 0;
			ELSIF editRegion = Lower THEN
				b.b := b.b + dy
			ELSIF editRegion = Upper THEN
				b.t := b.t + dy; dy := 0;
			ELSIF editRegion = LowerLeft THEN
				b.b := b.b + dy;
				b.l := b.l + dx; dx := 0;
			ELSIF editRegion = LowerRight THEN
				b.b := b.b + dy;
				b.r := b.r + dx
			ELSIF editRegion = UpperLeft THEN
				b.t := b.t + dy; dy := 0;
				b.l := b.l + dx; dx := 0;
			ELSIF editRegion = UpperRight THEN
				b.t := b.t + dy; dy := 0;
				b.r := b.r + dx
			ELSIF (editRegion = Inside) & ((dx # 0) OR (dy # 0)) THEN
				img := selection.ToImg(SELF,e);
				IF e # NIL THEN
					IF StartDrag(selection,img,-msg.x-e.dx,-msg.y-e.dy, EditMoved,NIL) THEN END;
				END;
				RETURN
			END;
			AdaptRelativeBounds(b, GetParent());
			bounds.Set(b);
			editX := editX + dx; editY := editY + dy;
		END Edit;

		PROCEDURE SetEditMode*(mode: BOOLEAN; recurse: BOOLEAN);
		VAR vc: VisualComponent; c: XML.Content;
		BEGIN
			Acquire;
			editMode.Set(mode);
			IF recurse THEN
				c := GetFirst();
				WHILE (c # NIL) DO
					IF c IS VisualComponent THEN
						vc := c(VisualComponent);
						vc.SetEditMode(mode, TRUE);
					END;
					c := GetNext(c);
				END;
			END;
			Release;
		END SetEditMode;

		PROCEDURE EditMoved(sender, data: ANY);
		VAR parent: XML.Element; ldata: ANY; e: ComponentListEntry;
		BEGIN
			IF (sender # SELF)  THEN
				IF (data # NIL) & (data IS WM.DragInfo) THEN
					ldata := data(WM.DragInfo).data;
					IF (ldata # NIL) & (ldata IS XML.Element) THEN
						parent := ldata(XML.Element).GetParent();
						parent.RemoveContent(ldata(XML.Element));
						parent(VisualComponent).Invalidate;
					ELSIF (ldata # NIL) & (ldata IS SelectionList) THEN
						e := ldata(SelectionList).first;
						WHILE e # NIL DO
							parent := e.component.GetParent();
							ldata := e.component;
							parent.RemoveContent(ldata(XML.Element));
							parent(VisualComponent).Invalidate;
							e := e.next;
						END;
					END;
				END;
			END;
		END EditMoved;

		PROCEDURE HandleInternal*(VAR msg : Messages.Message); (** PROTECTED *)
		VAR
			po : VisualComponent; nm : Messages.Message; handled : BOOLEAN; b : Rectangles.Rectangle;
			r, v : VisualComponent;
			p : XML.Element;
			keyFlags: SET; manager : WM.WindowManager;
			currentEditRegion: LONGINT;
			parent: XML.Element;
			parentEditMode: BOOLEAN;

		BEGIN
			ASSERT(IsCallFromSequencer());
			handled := FALSE;
			IF msg.msgType = Messages.MsgPointer THEN
				parent := GetParent();
				IF (parent # NIL) & (parent IS VisualComponent) & parent(VisualComponent).editMode.Get() THEN
					parentEditMode := TRUE
				ELSE
					parentEditMode := FALSE
				END;

				IF msg.msgSubType = Messages.MsgSubPointerMove THEN
					IF (msg.flags * {0, 1, 2} = {}) OR (fPointerOwner = NIL)  THEN
						IF parentEditMode & ~editMode.Get() THEN fPointerOwner := SELF; handled := TRUE
						ELSIF ~parentEditMode & (extGetPositionOwner # NIL) THEN extGetPositionOwner(msg.x, msg.y, fPointerOwner, handled);
						END;
						IF ~handled THEN
							po := GetPositionOwner(msg.x, msg.y);
							IF po # fPointerOwner THEN
								nm.msgType := Messages.MsgPointer;
								nm.msgSubType := Messages.MsgSubPointerLeave;
								HandleInternal(nm)
							END;
							fPointerOwner := po
						ELSE
							handled := FALSE;
						END;
					END
				END;
				IF (fPointerOwner = SELF) THEN
					IF (msg.originator # NIL) & (msg.originator IS WM.ViewPort) THEN
						manager := msg.originator(WM.ViewPort).manager;
						msg.originator(WM.ViewPort).GetKeyState(keyFlags);
					END;

					IF parentEditMode & (editRegion # None) THEN
						Edit(msg)
					ELSE
						IF msg.msgSubType = Messages.MsgSubPointerMove THEN
							IF (parentEditMode) & (msg.originator # NIL) & (msg.originator IS WM.ViewPort) THEN
								currentEditRegion := InEditBounds(msg.x, msg.y);
								CASE currentEditRegion OF
									| Lower, Upper: SetPointerInfo(manager.pointerUpDown)
									| Left, Right:SetPointerInfo(manager.pointerLeftRight)
									| LowerLeft, UpperRight:SetPointerInfo(manager.pointerURDL)
									| UpperLeft, LowerRight: SetPointerInfo(manager.pointerULDR)
									| Inside: SetPointerInfo(manager.pointerMove)
								ELSE
									IF oldPointerInfo # NIL THEN
										SetPointerInfo(oldPointerInfo); oldPointerInfo := NIL;
									ELSE oldPointerInfo := GetPointerInfo();
									END;
								END;
							END;

							IF extPointerMove # NIL THEN extPointerMove(msg.x, msg.y, msg.flags, handled) END;
							SetInternalPointerInfo(pointerInfo);
							IF ~handled THEN PointerMove(msg.x, msg.y, msg.flags) END;
							IF msg.dz # 0 THEN WheelMove(msg.dz) END
						ELSIF msg.msgSubType = Messages.MsgSubPointerDown THEN
							IF parentEditMode THEN
								editRegion := InEditBounds(msg.x, msg.y);
							END;
							(*
							IF (msg.originator # NIL) & (msg.originator IS WM.ViewPort) THEN
								msg.originator(WM.ViewPort).GetKeyState(keyFlags);
								IF (keyFlags # {}) & (keyFlags <= Inputs.Ctrl) THEN editRegion := InEditBounds(msg.x, msg.y) ELSE editRegion := None END;
							ELSE
								editRegion := None
							END;
							*)
							IF editRegion # None THEN
								IF (keyFlags # {}) & (keyFlags <= Inputs.Shift) THEN
									selection.Toggle(SELF)
								ELSIF ~selection.Has(SELF) THEN selection.Reset(SELF)
								END;
								manager := msg.originator(WM.ViewPort).manager;
								editX := msg.x; editY := msg.y;
							ELSE
								IF extPointerDown # NIL THEN extPointerDown(msg.x, msg.y, msg.flags, handled) END;
								IF ~handled THEN PointerDown(msg.x, msg.y, msg.flags) END;
							END;
							SetFocus
						ELSIF msg.msgSubType = Messages.MsgSubPointerUp THEN
							IF extPointerUp # NIL THEN extPointerUp(msg.x, msg.y, msg.flags, handled) END;
							IF ~handled THEN PointerUp(msg.x, msg.y, msg.flags) END
						ELSIF msg.msgSubType = Messages.MsgSubPointerLeave THEN
							IF extPointerLeave # NIL THEN extPointerLeave(handled) END;
							IF ~handled THEN PointerLeave END
						END;
						IF ~parentEditMode & (msg.flags * {0, 1, 2} # {}) THEN
							IF (msg.msgSubType = Messages.MsgSubPointerDown) THEN
								CheckPointerEvent(msg.x, msg.y, msg.z, msg.flags);
							ELSIF msg.msgSubType = Messages.MsgSubPointerUp  THEN
								CheckPointerUpEvent(msg.x, msg.y, msg.z, msg.flags);
							END;
						END;
					END;
				ELSE
					b := fPointerOwner.bounds.Get();
					msg.x := msg.x - b.l; msg.y := msg.y - b.t;
					 fPointerOwner.Handle(msg)
				END
			ELSIF msg.msgType = Messages.MsgKey THEN
				IF focusComponent # SELF THEN focusComponent.Handle(msg)
				ELSIF EditKeyEvents(msg.x, msg.flags, msg.y) THEN
					handled := TRUE;
				ELSIF (visible.Get()) THEN
					IF ~needsTab.Get() & (msg.y = 0FF09H) THEN
						IF (Inputs.Shift * msg.flags # {}) THEN FocusPrev ELSE FocusNext END
					ELSIF msg.y = 0FF67H THEN ShowContextMenu(0, 0)
					ELSE
						IF extKeyEvent # NIL THEN extKeyEvent(msg.x, msg.flags, msg.y, handled) END;
						IF ~handled THEN KeyEvent(msg.x, msg.flags, msg.y) END;
						CheckKeyEvents(msg.x, msg.flags, msg.y);
					END
				END;
			ELSIF msg.msgType = Messages.MsgDrag THEN
				IF extGetPositionOwner # NIL THEN extGetPositionOwner(msg.x, msg.y, po, handled); END;
				IF ~handled THEN
					po := GetPositionOwner(msg.x, msg.y);
				ELSE
					handled := FALSE;
				END;
				IF (po # SELF) & editMode.Get() & (~po.editMode.Get() OR (msg.ext # NIL) & (msg.ext(WM.DragInfo).data=po)) THEN
					po := SELF
				ELSIF (msg.ext # NIL) & (msg.ext(WM.DragInfo).data # NIL) & (msg.ext(WM.DragInfo).data IS ToggleEditMode) & (msg.ext(WM.DragInfo).data(ToggleEditMode).recursion = Recursion.FromBottom) THEN
					po := SELF
				END;
				IF (po # SELF) THEN (* Let child handle the drag and drop message *)
					b := po.bounds.Get();
					msg.x := msg.x - b.l; msg.y := msg.y - b.t;
					po.Handle(msg)
				ELSE (* handle the drag and drop message *)
					IF msg.msgSubType = Messages.MsgDragOver THEN
						IF (msg.ext # NIL) THEN
							IF extDragOver # NIL THEN extDragOver(msg.x, msg.y, msg.ext(WM.DragInfo), handled) END;
							IF ~handled THEN po.DragOver(msg.x, msg.y, msg.ext(WM.DragInfo)) END
						END
					ELSIF msg.msgSubType = Messages.MsgDragDropped THEN
						IF (msg.ext # NIL) THEN
							IF (msg.ext(WM.DragInfo).data # NIL) & (msg.ext(WM.DragInfo).data IS ToggleEditMode) THEN
								SetEditMode(~editMode.Get(), msg.ext(WM.DragInfo).data(ToggleEditMode).recursion # Recursion.None);
								Invalidate;
							ELSIF editMode.Get() THEN
								handled := EditDragDropped(msg.x,msg.y,msg.ext(WM.DragInfo));
							ELSIF extDragDropped # NIL THEN
								extDragDropped(msg.x, msg.y, msg.ext(WM.DragInfo), handled)
							END;
							IF ~handled THEN
								po.DragDropped(msg.x, msg.y, msg.ext(WM.DragInfo))
							END
						END
					END
				END
			ELSIF (msg.msgType = Messages.MsgFocus) & (msg.msgSubType = Messages.MsgSubFocusLost) THEN
				(* unset the old focus chain *)
				r := GetVisualComponentRoot(); (* find the leaf component that has the focus *)
				WHILE (r # NIL) & (r.focusComponent # NIL) & (r.focusComponent # r) DO r := r.focusComponent END;
				p := r; (* clear the focus chain until the root or this component *)
				WHILE (p # SELF) & (p # NIL) & (p IS VisualComponent) DO
					v := p(VisualComponent);
					v.focusComponent := v;
					v.FocusLost; IF v.extFocus # NIL THEN v.extFocus(FALSE) END; p := p.GetParent()
				END;
			ELSIF msg.msgType = Messages.MsgInvalidate THEN
				IF msg.msgSubType = Messages.MsgSubAll THEN
					msg.sender(VisualComponent).InvalidateRect(GetClientRect());
				ELSIF msg.msgSubType = Messages.MsgSubRectangle THEN
					msg.sender(VisualComponent).InvalidateRect(Rectangles.MakeRect(msg.x, msg.y, msg.dx, msg.dy));
				ELSE (* nothing  to do *)
				END;
			ELSIF msg.msgType = Messages.MsgExt THEN
				IF msg.ext = invalidateRectMsg THEN
					TRACE("WARNING: OLD MESSAGE FORM");
					msg.sender(VisualComponent).InvalidateRect(Rectangles.MakeRect(msg.x, msg.y, msg.dx, msg.dy))
				ELSE
					BroadcastSubcomponents(msg);
				END
			ELSE HandleInternal^(msg)
			END;
		END HandleInternal;
	END VisualComponent;

	GetPositionOwnerHandler* = PROCEDURE {DELEGATE} (x, y : LONGINT; VAR positionOwner : VisualComponent; VAR handled : BOOLEAN);

TYPE

	(* Layout Manager *)
	LayoutManager* = PROCEDURE {DELEGATE} (vc : VisualComponent);


	FormWindow* = OBJECT(WM.DoubleBufferWindow)
	VAR
		form- : Form;
		cs : WMGraphics.CanvasState;
		disableUpdate : LONGINT;
		content : VisualComponent;
		scaling* : BOOLEAN;

		PROCEDURE ToXML*():XML.Content;
		VAR winx: XML.Element; a: XML.Attribute; string: ARRAY 128 OF CHAR; title:Strings.String;
		BEGIN {EXCLUSIVE}
			NEW(winx); winx.SetName("FormWindow");
			NEW(a); a.SetName("name"); 
				title:=GetTitle(); IF title=NIL THEN a.SetValue("componentWindow") ELSE a.SetValue(title^) END; 
				winx.AddAttribute(a);
			NEW(a); a.SetName("loader"); a.SetValue("WMComponents.FormWindowGen"); winx.AddAttribute(a);
			NEW(a); a.SetName("l"); Strings.IntToStr(bounds.l, string); a.SetValue(string); winx.AddAttribute(a);
			NEW(a); a.SetName("t"); Strings.IntToStr(bounds.t, string); a.SetValue(string); winx.AddAttribute(a);
			NEW(a); a.SetName("r"); Strings.IntToStr(bounds.r, string); a.SetValue(string); winx.AddAttribute(a);
			NEW(a); a.SetName("b"); Strings.IntToStr(bounds.b, string); a.SetValue(string); winx.AddAttribute(a);
			NEW(a); a.SetName("flags"); Strings.SetToStr(flags, string); a.SetValue(string); winx.AddAttribute(a);
			NEW(a); a.SetName("canvasGenerator"); a.SetValue(canvas.generator^); winx.AddAttribute(a);
			winx.AddContent(form);
			RETURN winx
		END ToXML;
		
		PROCEDURE LoadComponents*(xml: XML.Element);
		VAR component: Repositories.Component; 
		BEGIN
			IF xml # NIL THEN
				component := Repositories.ComponentFromXML(xml);
				IF (component # NIL) & (component IS VisualComponent) THEN
					SetContent(component);
				ELSE
					KernelLog.String("formwindow could not load content"); KernelLog.Ln;
				END;
			END;
		END LoadComponents;

		PROCEDURE StoreComponents*(): XML.Element;
		BEGIN RETURN content (* do not store form separately *)
		END StoreComponents;

		PROCEDURE SetContent*(x : XML.Content);
		VAR c: XML.Content;
			m:Messages.Message;
		BEGIN 
			IF sequencer # NIL THEN sequencer.WaitFree() END;
			BEGIN{EXCLUSIVE} 
				INC(disableUpdate);
				INCL(flags, 13); (* render windows background non-displayed*)
				IF form # NIL THEN form.Finalize; form.sequencer.Stop; content:=NIL END;
				IF x IS Form THEN
					form := x(Form);
					form.initialized:=FALSE;
					form.SetWindow(SELF); (* includes new sequencer *)
					c:=form.GetFirst(); (* get first VisualComponent content of form*)
					WHILE (c#NIL) & (c IS XML.Container) & ~(c IS VisualComponent) DO
						c:=c(XML.Container).GetNext(c);
					END;
					IF c#NIL THEN form.RemoveContent(c) END; (* avoid duplicates. will be added in a systematic way below in AddContent *)
				ELSE
					NEW(form, SELF); (* includes new sequencer; initialized=FALSE *)
					form.uid.Set(NewString("form"));
					c:=x;
				END;
				IF (c#NIL) & (c IS VisualComponent) THEN 
					content := c(VisualComponent);
					form.initialized:=TRUE;
					form.AddContent(content);
					form.focusComponent := content;
					form.fPointerOwner := content;
				END;
				DEC(disableUpdate);
			END;			
			form.Initialize;
			form.Invalidate;
		END SetContent;

		PROCEDURE DisableUpdate*;
		BEGIN {EXCLUSIVE}
			INC(disableUpdate);
			ASSERT(disableUpdate # -1);	(* overflow *)
		END DisableUpdate;

		PROCEDURE EnableUpdate*;
		BEGIN {EXCLUSIVE}
			DEC(disableUpdate);
			ASSERT(disableUpdate # -1);	(* underflow *)
		END EnableUpdate;

		PROCEDURE Resized( width, height: LONGINT);
		BEGIN
			IF ~scaling THEN
				DisableUpdate;
				form.Acquire;
				ReInit(width, height);
				form.Release;
				form.bounds.Set(Rectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
				content.bounds.Set(Rectangles.MakeRect(0, 0, GetWidth(), GetHeight()));
				EnableUpdate;
				form.Invalidate()
			END
		END Resized;

		PROCEDURE Trap():BOOLEAN;
		BEGIN
			KernelLog.String("WMComponents.FormWindow.Trap !!! --> Resetting Locks "); KernelLog.Ln;
			form.sequencer.lock.Reset;
			RETURN TRUE
		END Trap;

		PROCEDURE Update(rect : Rectangles.Rectangle);
		BEGIN
			(*KernelLog.String("Update "); KernelLog.Int(disableUpdate,0); KernelLog.Ln;*)
			IF disableUpdate > 0 THEN RETURN END;
			form.Acquire;
			canvas.SaveState(cs);
			canvas.SetClipRect(rect);
			canvas.ClipRectAsNewLimits(0, 0);
			IF Raster.alpha IN img.fmt.components THEN
				canvas.Fill(rect, 0H, WMGraphics.ModeCopy)
			ELSE
				canvas.Fill(rect, 0H (*0FFH*), Raster.clear(*WMGraphics.ModeCopy*))
			END;
			form.Draw(canvas);
			canvas.RestoreState(cs);
			form.Release;
			CopyRect(rect);
			Invalidate(rect)
		END Update;
		
		PROCEDURE Handle*(VAR m : Messages.Message);
		VAR pendingM: Messages.Message;
		BEGIN
			Handle^(m);
			
			IF (m.msgType = Messages.MsgExt) & (m.ext # NIL) THEN
				IF (m.ext = componentStyleMsg) THEN CSChanged
				END;
			ELSIF (m.msgType = Messages.MsgFocus) & (m.msgSubType = Messages.MsgSubFocusGot) THEN
				IF (form # NIL) & (form.lastFocusComponent # NIL) THEN
					form.lastFocusComponent.SetFocus;
				END;
			ELSIF (m.msgType = Messages.MsgSetLanguage) & (m.ext # NIL) & (m.ext IS LanguageExtension) THEN
				LanguageChanged(m.ext(LanguageExtension).languages);
			ELSIF (m.msgType=Messages.MsgInvalidate) THEN  (* sent by WindowManager when a window is added to display space to assure it is up-to-date*)
				IF form=NIL THEN RETURN 
				ELSE m.sender:=form; (* will be passed to form below, which will call sender.InvalidateRect *)
				END;
			END;
			IF (TraceFocus IN Trace) THEN
				IF  (m.msgType = Messages.MsgFocus) THEN
					IF (m.msgSubType = Messages.MsgSubFocusGot) THEN
						KernelLog.String("Got Focus: "); form.TraceFocusChain;
					ELSIF (m.msgSubType = Messages.MsgSubMasterFocusGot) THEN
						KernelLog.String("Got Master Focus: "); form.TraceFocusChain;
					END;
				ELSIF (m.msgType = Messages.MsgKey) & (m.x = ORD("f"))  THEN
					KernelLog.String("Focus chain: "); form.TraceFocusChain;
				END;
			END;
			
			IF (form # NIL) THEN form.Handle(m); END;
		END Handle;

		PROCEDURE LanguageChanged*(languages : Localization.Languages);
		BEGIN
			ASSERT(languages # NIL);
		END LanguageChanged;

		PROCEDURE CSChanged*;
		BEGIN
			DisableUpdate; (* the components are going to redraw like crazy *)
			form.Acquire;
			form.Reset(SELF, NIL);
			form.Release;
			EnableUpdate;
		END CSChanged;

		PROCEDURE Close*;
		BEGIN
			Close^; (* remove the form to avoid further messages *)
			IF form # NIL THEN
				form.Acquire;
				form.Finalize; form.sequencer.Stop;
				form.Release
			END;
		END Close;
	END FormWindow;

	Form* = OBJECT(VisualComponent)
	VAR
		window- : FormWindow;
		lastFocusComponent : VisualComponent;

		PROCEDURE &New*(window : FormWindow);
		BEGIN 
			Init;
			SetGenerator("WMComponents.NewForm");
			lastFocusComponent := NIL;
			SetNameAsString(StrForm);
			SetWindow(window);
		END New;
		
		PROCEDURE SetWindow*(window: FormWindow);
		VAR seq: Messages.MsgSequencer; 
		BEGIN {EXCLUSIVE}
			IF window # NIL THEN
				SELF.window := window; 
				window.form := SELF; 
				bounds.Set(Rectangles.MakeRect(0, 0, window.GetWidth(), window.GetHeight()));
				NEW(seq, Handle); seq.SetTrapHandler(window.Trap); SetSequencer(seq);
			END;
		END SetWindow;

		PROCEDURE GetPointerInfo*() : WM.PointerInfo;
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF window # NIL THEN RETURN window.pointerInfo ELSE RETURN NIL END
		END GetPointerInfo;

		PROCEDURE SetPointerInfo*(pi : WM.PointerInfo);
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF window # NIL THEN window.SetPointerInfo(pi) END;
		END SetPointerInfo;

		PROCEDURE DisableUpdate*;
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF window # NIL THEN window.DisableUpdate END
		END DisableUpdate;

		PROCEDURE EnableUpdate*;
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF window # NIL THEN window.EnableUpdate END
		END EnableUpdate;

		PROCEDURE InvalidateRect*(rect : Rectangles.Rectangle);
		BEGIN 
			IF window # NIL THEN 
				BEGIN{EXCLUSIVE} AWAIT(initialized) END;
				window.Update(rect) 
			END;
		END InvalidateRect;

		PROCEDURE PropertyChanged*(sender, property : ANY);
		VAR w,h: LONGINT;
		BEGIN
			IF property = bounds THEN
				IF ~ Rectangles.IsEqual(window.bounds, bounds.Get()) THEN
					bounds.GetExtents(w,h);
					IF window # NIL THEN
						window.manager.SetWindowSize(window,w,h);
					END;
				ELSE
					(*ScaleFont(bounds.GetHeight(), scaleFont.Get());*)
					Resized
				END;
			END
		END PropertyChanged;
	END Form;

TYPE
	(** PropertyLists for style support *)
	PropertyListEntry = POINTER TO RECORD
		next : PropertyListEntry;
		name : Strings.String;
		list : WMProperties.PropertyList;
	END;

	ListArray* = POINTER TO ARRAY OF WMProperties.PropertyList;

	PropertyListList* = OBJECT
	VAR
		first : PropertyListEntry;

		PROCEDURE Find*(CONST name : ARRAY OF CHAR) : WMProperties.PropertyList;
		VAR cur : PropertyListEntry;
		BEGIN {EXCLUSIVE}
			cur := first;
			WHILE (cur # NIL) & (cur.name^ # name) DO cur := cur.next END;
			IF cur # NIL THEN RETURN cur.list
			ELSE RETURN NIL
			END
		END Find;

		PROCEDURE RemoveInternal(CONST name : ARRAY OF CHAR);
		VAR cur : PropertyListEntry;
		BEGIN
			IF first = NIL THEN RETURN END;
			IF (first # NIL) & (first.name^ = name) THEN first := first.next
			ELSE
				cur := first;
				WHILE (cur.next # NIL) DO
					IF (cur.next.name^ = name) THEN cur.next := cur.next.next END;
					cur := cur.next
				END
			END
		END RemoveInternal;

		PROCEDURE Remove*(CONST name : ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			RemoveInternal(name)
		END Remove;

		PROCEDURE Add*(CONST name : ARRAY OF CHAR; pl : WMProperties.PropertyList);
		VAR new : PropertyListEntry;
		BEGIN {EXCLUSIVE}
			RemoveInternal(name);
			NEW(new); new.name := NewString(name); new.list := pl; new.next := first; first := new
		END Add;

		PROCEDURE Enumerate*() : ListArray;
		VAR array : ListArray; current : PropertyListEntry; i : LONGINT;
		BEGIN {EXCLUSIVE}
			i := 0;
			current := first;
			WHILE current # NIL DO INC(i); current := current.next	END;
			NEW(array, i );
			current := first;
			i := 0;
			WHILE current # NIL DO
				array[i] := current.list;
				INC(i);
				current := current.next
			END;
			RETURN array
		END Enumerate;

		PROCEDURE UpdateStyle*;
		VAR
			en : XMLObjects.Enumerator;
			p : ANY; s : Strings.String;
			pl : WMProperties.PropertyList;
		BEGIN
			IF currentStyle = NIL THEN RETURN END;
			en := currentStyle.GetContents();
			WHILE en.HasMoreElements() DO
				p := en.GetNext();
				IF p IS XML.Element THEN
					s := p(XML.Element).GetName();
					pl := propertyListList.Find(s^);
					IF pl # NIL THEN pl.SetXML(p(XML.Element)) END
				END
			END
		END UpdateStyle;

	END PropertyListList;

	ComponentListEntry= POINTER TO RECORD
		component: VisualComponent;
		dx,dy: LONGINT;
		next: ComponentListEntry
	END;

	SelectionArray* = POINTER TO ARRAY OF VisualComponent;

	SelectionList*= OBJECT
	VAR first, last: ComponentListEntry; number: LONGINT; state: LONGINT; timer: Kernel.Timer;
		onChanged-: WMEvents.EventSource;
		lock: Locks.RecursiveLock;

		PROCEDURE &Init;
		BEGIN
			NEW(lock);
			first := NIL; last := NIL; number := 0; state := 0; NEW(onChanged, NIL, NIL, NIL, NIL);
		END Init;

		PROCEDURE Reset(this: VisualComponent);
		VAR entry: ComponentListEntry;
		BEGIN
			lock.Acquire;
			entry := first;
			first := NIL; last := NIL; number := 0;
			WHILE entry # NIL DO entry.component.Invalidate; entry := entry.next END;
			lock.Release;
			Add(this);
			onChanged.Call(SELF);
		END Reset;

		PROCEDURE Has*(this: ANY): BOOLEAN;
		VAR entry: ComponentListEntry;
		BEGIN
			IF first = NIL THEN RETURN FALSE END; (* no lock for usual case *)
			lock.Acquire;
			entry := first;
			WHILE (entry # NIL) & (entry.component # this) DO entry := entry.next END;
			lock.Release;
			RETURN entry # NIL
		END Has;

		PROCEDURE Add*(this: VisualComponent);
		VAR entry: ComponentListEntry;
		BEGIN
			IF (this = NIL) OR Has(this) THEN RETURN END;
			lock.Acquire;
			NEW(entry); entry.component := this; entry.next := NIL;
			IF last = NIL THEN
				ASSERT(first = NIL);
				first := entry; last := entry;
			ELSE
				last.next := entry; last := entry
			END;
			INC(number);
			lock.Release;
			this.Invalidate;
			onChanged.Call(SELF);
		END Add;

		PROCEDURE Remove*(this: VisualComponent);
		VAR entry, prev: ComponentListEntry;
		BEGIN
			lock.Acquire;
			entry := first; prev := NIL;
			WHILE (entry # NIL) & (entry.component # this) DO
				prev := entry;
				entry := entry.next;
			END;
			IF entry = NIL THEN lock.Release; RETURN END;
			IF prev # NIL THEN prev.next := entry.next END;
			IF entry = first THEN first := first.next END;
			IF entry = last THEN last := prev END;
			DEC(number);
			lock.Release;
			this.Invalidate;
			onChanged.Call(SELF);
		END Remove;


		PROCEDURE GetSelection*(): SelectionArray;
		VAR array: SelectionArray; i: LONGINT; e: ComponentListEntry;
		BEGIN
			lock.Acquire;
			NEW(array, number);
			e := first; i := 0;
			WHILE e # NIL DO
				array[i] := e.component;
				INC(i);
				e := e.next;
			END;
			lock.Release;
			RETURN array;
		END GetSelection;

		PROCEDURE Toggle*(this: VisualComponent);
		BEGIN
			IF Has(this) THEN Remove(this) ELSE Add(this) END;
		END Toggle;

		PROCEDURE Update;
		VAR e: ComponentListEntry;
		BEGIN
			e := first;
			WHILE e # NIL DO
				e.component.Invalidate;
				e := e.next;
			END;
		END Update;

		PROCEDURE Shift(dx, dy: LONGINT);
		VAR e: ComponentListEntry; rect: Rectangles.Rectangle;
		BEGIN
			e := first;
			WHILE e # NIL DO
				rect := e.component.bounds.Get();
				INC(rect.l,dx); INC(rect.r,dx);
				INC(rect.t,dy); INC(rect.b,dy);
				e.component.AdaptRelativeBounds(rect,e.component.GetParent());
				e.component.bounds.Set(rect);
				e := e.next
			END;
		END Shift;

		PROCEDURE ToImg(start: VisualComponent; VAR this: ComponentListEntry): WMGraphics.Image;
		VAR l,t,r,b: LONGINT; e: ComponentListEntry; rect: Rectangles.Rectangle; img, image: WMGraphics.Image; w,h: LONGINT;
			canvas: WMGraphics.BufferCanvas; srcCopy: Raster.Mode;
		BEGIN
			l := MAX(LONGINT); r := MIN(LONGINT);
			t := MAX(LONGINT); b := MIN(LONGINT);
			e := first;
			WHILE e # NIL DO
				rect := e.component(VisualComponent).bounds.Get();
				IF rect.l < l THEN l := rect.l END;
				IF rect.r > r THEN r := rect.r END;
				IF rect.t < t THEN t := rect.t END;
				IF rect.b > b THEN b := rect.b END;
				e := e.next;
			END;
			Raster.InitMode(srcCopy, Raster.srcCopy);
			NEW(image);
			w := r-l+1; h := b-t+1;
			Raster.Create(image, w,h, Raster.BGRA8888);
			e := first;
			WHILE e # NIL DO
				rect := e.component.bounds.Get();
				NEW(img);
				Raster.Create(img,rect.r-rect.l+1, rect.b-rect.t+1, Raster.BGRA8888);
				NEW(canvas,img);
				e.component.Draw(canvas);
				Raster.Copy(img,image,0,0,img.width-1, img.height-1,rect.l-l, rect.t-t, srcCopy);
				e.dx := rect.l-l; e.dy := rect.t-t;
				IF e.component = start THEN this := e END;
				e := e.next
			END;
			RETURN image
		END ToImg;



	BEGIN {ACTIVE}
		NEW(timer);
		LOOP
			timer.Sleep(400);
			state := (state + 1) MOD 2;
			Update;
		END
	END SelectionList;



	WindowGenerator*= PROCEDURE(xml: XML.Content): WM.Window;

VAR
	hasErrors : BOOLEAN; (* accessed only from  	 (EXCLUSIVE) *)
	invalidateRectMsg- : Messages.MessageExtension; (* used as unique ID *)

	PrototypeID, PrototypeUID : WMProperties.StringProperty;
	PrototypeBounds-, PrototypeBoundsRelative-, PrototypeBearing : WMProperties.RectangleProperty;
	PrototypeEnabled : WMProperties.BooleanProperty;
	PrototypeFillColor : WMProperties.ColorProperty;
	PrototypeAlignment : WMProperties.Int32Property;
	PrototypeVisible, PrototypeTakesFocus, PrototypeNeedsTab, PrototypeEditMode: WMProperties.BooleanProperty;
	PrototypeScaleFont: WMProperties.Int32Property;
	PrototypeFocusPrevious, PrototypeFocusNext : WMProperties.StringProperty;
	PrototypeFont- : WMProperties.FontProperty;
	StrComponent, StrVisualComponent, StrForm, StrFormWindow, StrModel, StrModelInfo : Strings.String;
	GSonStartDrag, GSonStartDragInfo : Strings.String;
	ModelPrototype-: WMProperties.ReferenceProperty;

	propertyListList- : PropertyListList;
	currentStyle- : XML.Element;
	componentStyleMsg- : ComponentStyleChanged;

	timestamp : LONGINT;

	macroHandlers : MacroHandler; (* the head of the list is always the DefaultMacroHandler *)
	selection-: SelectionList;
(*
PROCEDURE ResetInternal(parent:Component);
VAR c: XML.Content;
BEGIN
	IF ~parent.initialized THEN parent.Initialize END;
	(*parent.RecacheProperties;*)
	c := parent.GetFirst();
	WHILE (c # NIL) DO
		IF c IS Component THEN 
			ResetInternal(c(Component)) 
		END;
		c := parent.GetNext(c);
	END;
END ResetInternal;
*)

PROCEDURE IsWhiteSpace(ch : CHAR) : BOOLEAN;
BEGIN
	RETURN ch <= " ";
END IsWhiteSpace;

PROCEDURE SkipWhiteSpace(CONST string : ARRAY OF CHAR; VAR index : LONGINT);
VAR length : LONGINT;
BEGIN
	length := LEN(string);
	WHILE (index < length) & (string[index] # 0X) & IsWhiteSpace(string[index]) DO INC(index); END;
	ASSERT(index < LEN(string));
END SkipWhiteSpace;

PROCEDURE ReadWord*(CONST string : ARRAY OF CHAR; VAR word : ARRAY OF CHAR; VAR index : LONGINT) : BOOLEAN;
VAR length, wordLength, i : LONGINT;
BEGIN
	SkipWhiteSpace(string, index);
	length := LEN(string);
	wordLength := LEN(word);
	i := 0;
	WHILE (index < length) & (string[index] # 0X) & ~IsWhiteSpace(string[index]) & (i < wordLength) DO
		word[i] := string[index];
		INC(i);
		INC(index);
	END;
	IF (i < wordLength) THEN word[i] := 0X; END;
	ASSERT(index < LEN(string));
	RETURN (i > 0) & (index < length) & (i < wordLength);
END ReadWord;

(* Split <string> into two strings separated by <separator> *)
PROCEDURE SplitMacroString(CONST string : ARRAY OF CHAR; VAR namespace, name : ARRAY OF CHAR; separator : CHAR);
VAR i, j : LONGINT;
BEGIN
	ASSERT((LEN(namespace) >= LEN(string)) & (LEN(name) >= LEN(string)));
	i := 0;
	WHILE (i < LEN(string)) & (string[i] # 0X) & (string[i] # separator) DO
		namespace[i] := string[i];
		INC(i);
	END;
	namespace[i] := 0X;

	INC(i); (* skip separator *)

	j := 0;
	WHILE (i < LEN(string)) & (string[i] # 0X) DO
		name[j] := string[i];
		INC(i); INC(j);
	END;
	name[j] := 0X;

	IF (name = "") THEN COPY(namespace, name); COPY(NoNamespace, namespace); END; (* no namespace *)
END SplitMacroString;

PROCEDURE ReportError(CONST text, argument1, argument2 : ARRAY OF CHAR);
VAR
	message : Events.Message;
	textIdx, messageIdx : LONGINT;
	secondArgument : BOOLEAN;

	PROCEDURE Append(VAR message : ARRAY OF CHAR; CONST argument : ARRAY OF CHAR; VAR index : LONGINT);
	VAR i : LONGINT;
	BEGIN
		i := 0;
		WHILE (i < LEN(argument)) & (argument[i] # 0X) & (index < LEN(message) - 1) DO
			message[index] := argument[i];
			INC(i);
			INC(index);
		END;
	END Append;

BEGIN
	secondArgument := FALSE;
	textIdx := 0;
	messageIdx := 0;
	WHILE (textIdx < LEN(text)) & (text[textIdx] # 0X) & (messageIdx < LEN(message) - 1) DO
		IF (text[textIdx] # "%") THEN
			message[messageIdx] := text[textIdx];
			INC(messageIdx);
		ELSE
			IF ~secondArgument THEN
				secondArgument := TRUE;
				Append(message, argument1, messageIdx);
			ELSE
				Append(message, argument2, messageIdx);
			END;
		END;
		INC(textIdx);
	END;
	message[messageIdx] := 0X;
	Events.AddEvent("Components", Events.Error, 0, 0, 0, message, FALSE);
END ReportError;

PROCEDURE GetArgumentStream*(command: Strings.String; offset: LONGINT; VAR arguments: Streams.StringReader);
VAR i: LONGINT;
BEGIN
	IF command = NIL THEN arguments := NIL; RETURN END;
	i := offset;
	WHILE (i < LEN(command)) & (command[i] # 0X) DO INC(i); END;
	IF (i # offset) THEN
		NEW(arguments, i - offset + 1);
		arguments.SetRaw(command^, offset, i - offset + 1);
	ELSE
		arguments := NIL;
	END;
END GetArgumentStream;

PROCEDURE GenerateContext*(oldCommand, command : Strings.String; index : LONGINT; originator : Component; CONST event : Event) : EventContext;
VAR
	context : EventContext; pointerContext : PointerContext; keyContext : KeyContext;
	arguments : Streams.StringReader;
	i : LONGINT;
BEGIN
	ASSERT((command # NIL) & (0 <= index) & (index < LEN(command)));
	ASSERT(originator # NIL);
	GetArgumentStream(command,index,arguments);
	IF (event IS PointerEvent) THEN
		NEW(pointerContext, originator, oldCommand, NIL, arguments, NIL, NIL, NIL); pointerContext.pointer := event(PointerEvent);
		context := pointerContext;
	ELSIF (event IS KeyPressedEvent) THEN
		NEW(keyContext, originator, oldCommand, NIL, arguments, NIL, NIL, NIL); keyContext.key := event(KeyPressedEvent);
		context := keyContext;
	ELSE
		NEW(context, originator, oldCommand, NIL, arguments, NIL, NIL, NIL);
	END;
	BEGIN {EXCLUSIVE}
		context.timestamp := timestamp;
		INC(timestamp);
	END;
	ASSERT(context # NIL);
	RETURN context;
END GenerateContext;

PROCEDURE HandleEvent*(CONST event : Event; originator : Component; command : Strings.String);
VAR
	commandString : ARRAY 128 OF CHAR;
	newCommand : Strings.String;
	context : EventContext;
	msg : Events.Message;
	index : LONGINT;
BEGIN
	ASSERT((originator # NIL) & (command # NIL));
	index := 0;
	IF Logging THEN
		COPY(command^, msg);
		Events.AddEvent("Components", Events.Information, 0, 0, 0, msg, FALSE);
	END;

	SubstituteMacros(command, newCommand, originator);

	IF ReadWord(newCommand^, commandString, index) THEN
		context := GenerateContext(command, newCommand, index, originator, event);
		Commands.Activate(commandString, context, {}, context.result, msg); (* asynchronous call since holding the originators lock! *)
		IF (context.result # Commands.Ok) THEN
			Events.AddEvent("Components", Events.Error, 0, 0, 0, msg, FALSE);
		END;
	ELSE
		Events.AddEvent("Components", Events.Error, 0, 0, 0, "Expected command", FALSE);
	END;
END HandleEvent;

PROCEDURE ContainsMacros(CONST string : ARRAY OF CHAR) : BOOLEAN;
VAR result : BOOLEAN; length, i : LONGINT;
BEGIN
	result := FALSE;
	i := 0; length := LEN(string);
	WHILE (i < length) & (string[i] # 0X) & ~result DO
		IF (string[i] = MacroCharacter) THEN
			result := (i + 1 < length) & (string[i+1] # MacroCharacter);
			IF ~result THEN (* two consequent MacroCharacter's are used to escape *)
				INC(i); (*skip string[i+1] *)
			END;
		END;
		INC(i);
	END;
	RETURN result;
END ContainsMacros;

PROCEDURE WriteSelectionToStream(w : Streams.Writer);
VAR text : Texts.Text; from, to : Texts.TextPosition; a, b : LONGINT;
BEGIN
	ASSERT(w # NIL);
	IF Texts.GetLastSelection(text, from, to) THEN
		text.AcquireRead;
		a := Strings.Min(from.GetPosition(), to.GetPosition());
		b := Strings.Max(from.GetPosition(), to.GetPosition());
		IF (text.GetLength() > 0) THEN
			TextUtilities.SubTextToStream(text, a, b - a + 1, w);
		END;
		text.ReleaseRead;
	END;
END WriteSelectionToStream;

PROCEDURE SubstituteMacro(CONST command : Strings.String; VAR index : LONGINT; originator : Component; w : Streams.Writer);
VAR oldIndex : LONGINT; macro, namespace, name : Macro; handler : MacroHandlerProcedure; handled : BOOLEAN;
BEGIN
	ASSERT((command # NIL) & (0 <= index) & (index < LEN(command)) & (command[index] = MacroCharacter));
	ASSERT(originator # NIL);
	ASSERT(w # NIL);
	oldIndex := index;
	INC(index); (* skip MacroCharacter *)
	IF ReadWord(command^, macro, index) THEN (*? TBD error handling *)
		SplitMacroString(macro, namespace, name, NamespaceCharacter);
		IF (namespace = NoNamespace) OR (namespace = DefaultNamespace) THEN
			handler := DefaultMacroHandler;
		ELSE
			BEGIN {EXCLUSIVE}
				handler := FindMacroHandler(namespace);
			END;
		END;

		handled := FALSE;
		IF (handler # NIL) THEN handler(name, originator, w, handled); END;

		IF ~handled THEN
			w.Char(MacroCharacter); w.String(macro); (* don't substitute *)
		END;
	END;
	ASSERT(index > oldIndex);
END SubstituteMacro;

PROCEDURE SubstituteMacros*(CONST command : Strings.String; VAR newCommand : Strings.String; originator : Component);
VAR index, oldIndex, length : LONGINT; w : Streams.Writer; buffer : Strings.Buffer;
BEGIN
	ASSERT((command # NIL) & (originator # NIL));
	IF ContainsMacros(command^) THEN
		NEW(buffer, 256);
		w := buffer.GetWriter();
		index := 0; length := LEN(command^);
		WHILE (index < length) & (command[index] # 0X) DO
			oldIndex := index;
			IF (command[index] = MacroCharacter) THEN
				IF (index + 1 < length) & (command[index + 1] = MacroCharacter) THEN (* escape *)
					w.Char(MacroCharacter);
					index := index + 2; (* skip both MacroCharacter's *)
				ELSE
					(* substitute macro *)
					SubstituteMacro(command, index, originator, w);
				END;
			ELSE
				w.Char(command[index]);
				INC(index);
			END;
			ASSERT(index > oldIndex);
		END;
		newCommand := buffer.GetString();
	ELSE
		newCommand := command;
	END;
	ASSERT(newCommand # NIL);
END SubstituteMacros;

PROCEDURE GetAttributeValue(originator : Component; CONST fullname : ARRAY OF CHAR) : Strings.String;
VAR value : Strings.String; c : Component; component, attribute : ARRAY 64 OF CHAR;
BEGIN
	ASSERT(originator # NIL);
	value := NIL;
	Strings.GetExtension(fullname, component, attribute);
	IF (attribute = "") THEN
		COPY(component, attribute);
		COPY("", component);
	END;
	IF (component[0] = "@") THEN component[0] := "&"; END; (*? TBD: Hack to avoid ampersand in XML *)

	IF (component = "") THEN
		c := originator;
	ELSE
		c := originator.Find(component);
	END;

	IF (c # NIL) THEN
		IF c.HasAttribute(attribute) THEN
			RETURN c.GetAttributeValue(attribute);
		ELSE
			ReportError("Attribute % of component % not found", attribute, component);
		END;
	ELSE
		ReportError("Component % not found", component, "");
	END;
	RETURN value;
END GetAttributeValue;

PROCEDURE GetPropertyValue(originator : Component; CONST fullname : ARRAY OF CHAR) : Strings.String;
VAR value : ARRAY 256 OF CHAR; string:Strings.String; c : Component; component, property : ARRAY 64 OF CHAR;
BEGIN
	ASSERT(originator # NIL);
	Strings.GetExtension(fullname, component, property);
	IF (property = "") THEN COPY(component, property); COPY("", component);
	END;
	IF (component[0] = "@") THEN component[0] := "&"; END; (*? TBD: Hack to avoid ampersand in XML *)
	IF (component = "") THEN c := originator;
	ELSE c := originator.Find(component);
	END;
	IF (c # NIL) THEN
		IF c.properties.GetPropertyValue(property,value) THEN RETURN Strings.NewString(value)
		ELSE ReportError("Property % of component % not found", property, component);
		END;
	ELSE ReportError("Component % not found", component, "");
	END;
	RETURN NIL;

END GetPropertyValue;

PROCEDURE DefaultMacroHandler(CONST macro : Macro; originator : Component; w : Streams.Writer; VAR handled : BOOLEAN);
VAR string, value : Strings.String;
BEGIN
	ASSERT((originator # NIL) & (w # NIL));
	handled := TRUE;
	IF (macro = MacroSelection) THEN
		WriteSelectionToStream(w);
	ELSIF (macro = MacroClipboard) THEN
		TextUtilities.TextToStream(Texts.clipboard, w);
	ELSIF Strings.StartsWith(MacroAttributePrefix, 0, macro) THEN
		string := Strings.Substring(Strings.Length(MacroAttributePrefix), Strings.Length(macro), macro);
		value := GetAttributeValue(originator, string^);
		IF (value # NIL) THEN
			w.String(value^);
		ELSE
			handled := FALSE;
		END;
	ELSIF Strings.StartsWith(MacroPropertyPrefix, 0, macro) THEN
		string := Strings.Substring(Strings.Length(MacroPropertyPrefix), Strings.Length(macro), macro);
		value := GetPropertyValue(originator,string^);
		IF (value # NIL) THEN
			w.String(value^);
		ELSE
			handled := FALSE;
		END;
	ELSE
		handled := FALSE;
	END;
END DefaultMacroHandler;

PROCEDURE FindMacroHandler(CONST namespace : ARRAY OF CHAR) : MacroHandlerProcedure;
VAR node : MacroHandler; handler : MacroHandlerProcedure;
BEGIN (* caller must hold module lock! *)
	node := macroHandlers;
	WHILE (node # NIL) & (node.namespace # namespace) DO node := node.next; END;
	IF (node # NIL) THEN
		handler := node.handler;
	ELSE
		handler := NIL;
	END;
	RETURN handler;
END FindMacroHandler;

PROCEDURE AddMacroHandler*(CONST namespace : Namespace; handler : MacroHandlerProcedure; VAR res : LONGINT);
VAR new, node : MacroHandler; h : MacroHandlerProcedure;
BEGIN {EXCLUSIVE}
	ASSERT((namespace # NoNamespace) & (handler # NIL));
	ASSERT(macroHandlers # NIL);
	h := FindMacroHandler(namespace);
	IF (h = NIL) THEN (* append new handler to list *)
		NEW(new);
		new.handler := handler;
		new.namespace := namespace;
		new.next := NIL;
		node := macroHandlers;
		WHILE (node.next # NIL) DO node := node.next; END;
		node.next := new;
		res := Ok;
	ELSE
		res := DuplicateNamespace;
	END;
END AddMacroHandler;

PROCEDURE RemoveMacroHandler*(handler : MacroHandlerProcedure);
VAR node : MacroHandler;
BEGIN {EXCLUSIVE}
	ASSERT((handler # NIL) & (handler # DefaultMacroHandler));
	ASSERT(macroHandlers # NIL);
	node := macroHandlers;
	WHILE (node.next # NIL) & (node.next.handler # handler) DO node := node.next; END;
	ASSERT((node.next # NIL) & (node.next.handler = handler));
	node.next := node.next.next;
END RemoveMacroHandler;

PROCEDURE SetAttribute*(context : Commands.Context); (** component attribute value ~ *)
VAR originator, target : Component; name, attribute, value : ARRAY 128 OF CHAR; (*? TBD array size *)
BEGIN
	IF (context IS EventContext) THEN
		originator := context(EventContext).originator;
		IF context.arg.GetString(name) & context.arg.GetString(attribute) & context.arg.GetString(value) THEN
			target := originator.Find(name);
			IF (target # NIL) THEN
				IF target.HasAttribute(attribute) THEN
					target.SetAttributeValue(attribute, value);
				ELSE
					context.result := Commands.CommandError;
				END;
			ELSE
				context.result := Commands.CommandError;
			END;
		ELSE
			context.error.String("Expected component name, attribute and value parameters"); context.error.Ln;
			context.result := Commands.CommandParseError;
		END;
	ELSE
		context.error.String("Command requires EventContext."); context.error.Ln;
		context.result := Commands.CommandParseError;
	END;
END SetAttribute;

(** Activate a string of commands, including their parameters.
	The string is parsed from left to right and Activate is called for every command.
	Parsing stops at the end of the string, or when Activate returns an error.
	The flags are applied to every command, i.e., for sequential execution,
	use the Wait flag (the caller waits until all commands return).
	Syntax:
		cmds = [mode " " ] cmd {";" cmd} .
		mode = "PAR" | "SEQ" .
		cmd = mod ["." proc] [" " params] .
		params = {<any character except ";">} .

	REMARK: For now, this is almost the same as Commands.Call. This procedure will either be enhanced to
	support some component-related macro substitution or be replaced by Commands.Call
*)

PROCEDURE Call*(cmds : ARRAY OF CHAR; caller : Component; flags : SET; VAR res : LONGINT; VAR msg : ARRAY OF CHAR);
VAR
	context : Commands.Context; arg : Streams.StringReader;
	buffer : Strings.Buffer; w : Streams.Writer; par : Strings.String;
	length, i, k : LONGINT;

	PROCEDURE Expand(CONST string : ARRAY OF CHAR; w : Streams.Writer; start : LONGINT; VAR end : LONGINT);
	VAR
		component : Component;
		componentStr, attributeStr : ARRAY 256 OF CHAR;
		property : WMProperties.Property; attribute : XML.Attribute;
		value : Strings.String;
		lastDotIdx, i, j : LONGINT; error : BOOLEAN;
	BEGIN
		ASSERT((string[start] = "&") & (start + 1 < LEN(string)) & (w # NIL));
		end := start; WHILE (end < LEN(string)) & (string[end] # 0X) & (string[end] # ";") & (string[end] > " ") DO INC(end); END;
		DEC(end);

		lastDotIdx := end;
		WHILE (lastDotIdx > start) & (string[lastDotIdx] # ".") DO DEC(lastDotIdx); END;
		error := (lastDotIdx <= start); (* missing dot *)

		IF ~error THEN
			i := start + 1; (* skip ampersand *)
			IF (string[i] = "&") OR (string[i] = "/") THEN
				j := 0;
				WHILE (i < lastDotIdx) & (j < LEN(componentStr) - 1) DO
					componentStr[j] := string[i];
					INC(i); INC(j);
				END;
				componentStr[j] := 0X;
				component := caller.Find(componentStr);
			ELSE
				componentStr := "";
				component := caller;
			END;
			ASSERT(string[i] = ".");
			INC(i); (* skip dot *)
			attributeStr := "";
			j := 0;
			WHILE (j < LEN(attributeStr)) & (i <= end) DO
				attributeStr[j] := string[i];
				INC(i); INC(j);
			END;
			error := (attributeStr = "");
			IF ~error THEN
				IF (component # NIL) THEN
					property := component.properties.Get(attributeStr);
					IF (property # NIL) THEN
						property.ToStream(w);
					ELSE
						attribute := component.GetAttribute(attributeStr);
						IF (attribute # NIL) THEN
							value := attribute.GetValue();
							IF (value # NIL) THEN w.String(value^); ELSE w.String("NIL"); END;
						ELSE
							error := TRUE;
						END;
					END;
				ELSE
					error := TRUE;
				END;
			END;
		END;
		IF error THEN (* don't expand macro *)
			FOR i := start TO end DO w.Char(string[i]); END;
		END;
		ASSERT(end >= start);
	END Expand;

BEGIN
	ASSERT(caller # NIL);
	NEW(buffer, LEN(cmds)); w := buffer.GetWriter();
	IF Strings.StartsWith2(Repositories.CommandPrefix, cmds) THEN i := Strings.Length(Repositories.CommandPrefix); ELSE i := 0; END;
	LOOP
		buffer.Clear;
		w.Reset;
		k := 0;
		WHILE (i < LEN(cmds)) & (cmds[i] # " ") & (cmds[i] # 09X) & (cmds[i] # 0DX) & (cmds[i] # 0AX) & (cmds[i] # 0X) & (cmds[i] # ";") DO cmds[k] := cmds[i]; INC(k); INC(i); END;
		IF k = 0 THEN EXIT; END;	(* end of string *)
		IF (i < LEN(cmds)) & (cmds[i] # ";") & (cmds[i] # 0X) THEN (* parameters *)
			INC(i); (* skip delimiter *)
			WHILE (i < LEN(cmds)) & (cmds[i] # 0X) & (cmds[i] # ";") DO
				IF (cmds[i] = "&") & (i + 1 < LEN(cmds)) & ((cmds[i+1] = "&") OR (cmds[i+1] = ".") OR (cmds[i+1] = "/")) THEN
					Expand(cmds, w, i, i);
				ELSE
					w.Char(cmds[i]);
				END;
				INC(i);
			END;
		END;
		IF (i < LEN(cmds)) & (cmds[i] = ";") THEN (* skip command delimiter *) INC(i); END;
		cmds[k] := 0X;
		length := buffer.GetLength();
		IF (length > 0) THEN
			par := buffer.GetString();
			NEW(arg, length + 1); arg.SetRaw(par^, 0, length + 1);
		ELSE
			arg := NIL;
		END;
		NEW(context, NIL, arg, NIL, NIL, caller);
		Commands.Activate(cmds, context, flags, res, msg);
		IF (res # Commands.Ok) THEN KernelLog.String("WMComponents.Call error, res = "); KernelLog.Int(res, 0); KernelLog.Ln; EXIT; END;
	END;
END Call;

PROCEDURE GetComponent*(CONST name : ARRAY OF CHAR) : Component;
VAR component : Component; c : Repositories.Component; res : LONGINT;
BEGIN
	component := NIL;
	Repositories.GetComponentByString(name, c, res);
	IF (res = Repositories.Ok) THEN
		IF (c # NIL) & (c IS Component) THEN
			component := c (Component);
		ELSE
			KernelLog.String("WMComponents.GetComponent: Could not generate component ");
			KernelLog.String(name); KernelLog.String(": Wrong type"); KernelLog.Ln;
		END;
	ELSE
		KernelLog.String("WMComponents.GetComponent: Could not generate component ");
		KernelLog.String(name); KernelLog.String(", res: "); KernelLog.Int(res, 0); KernelLog.Ln;
	END;
	RETURN component;
END GetComponent;

PROCEDURE GetVisualComponent*(CONST name : ARRAY OF CHAR) : VisualComponent;
VAR component : VisualComponent; c : Repositories.Component; res : LONGINT;
BEGIN
	component := NIL;
	Repositories.GetComponentByString(name, c, res);
	IF (res = Repositories.Ok) THEN
		IF (c # NIL) & (c IS VisualComponent) THEN
			component := c (VisualComponent);
		ELSE
			KernelLog.String("WMComponents.GetVisualComponent: Could not generate component ");
			KernelLog.String(name); KernelLog.String(": Wrong type"); KernelLog.Ln;
		END;
	ELSE
		KernelLog.String("WMComponents.GetVisualComponent: Could not generate component ");
		KernelLog.String(name); KernelLog.String(", res: "); KernelLog.Int(res, 0); KernelLog.Ln;
	END;
	RETURN component;
END GetVisualComponent;

PROCEDURE SetStyle*(style : XML.Element);
BEGIN
	SetStyleInternal(style)
END SetStyle;

PROCEDURE SetStyleInternal(style : XML.Element);
VAR msg : Messages.Message;  m : WM.WindowManager;
BEGIN
	currentStyle := style;
	IF propertyListList # NIL THEN propertyListList.UpdateStyle END;

	msg.msgType := Messages.MsgExt; msg.ext := componentStyleMsg;
	m := WM.GetDefaultManager();
	m.Broadcast(msg)
END SetStyleInternal;

PROCEDURE FindRelativePath(x : Component; CONST path : ARRAY OF CHAR; pos : LONGINT) : Component;
VAR c : XML.Content;
	sn : ARRAY MaxComponentNameSize OF CHAR;
	i : LONGINT; id : Strings.String;
BEGIN
	IF x = NIL THEN RETURN NIL
	ELSIF path[pos] = 0X THEN RETURN x
	ELSIF (pos = 0) & (path[0] = "/") THEN RETURN FindRelativePath(x.GetComponentRoot(), path, pos + 1)
	ELSIF (path[pos] = ".") & (path[pos + 1] = ".") THEN
		INC(pos, 2); IF path[pos]="/" THEN INC(pos) END;
		c := x.GetParent();
		IF (c # NIL) & (c IS Component) THEN
			RETURN FindRelativePath(c(Component), path, pos)
		ELSE
			RETURN NIL
		END
	ELSE
		i := 0; WHILE (i < MaxComponentNameSize - 1) & (path[pos] # 0X) & (path[pos] # "/") DO
			sn[i] := path[pos]; INC(i); INC(pos)
		END;
		IF (path[pos] = "/") THEN INC(pos) END;
		sn[i] := 0X;
		c := x.GetFirst();
		WHILE (c # NIL) DO
			IF (c IS Component) THEN
				id := c(Component).id.Get();
				IF (id # NIL) & (id^ = sn) THEN
					RETURN FindRelativePath(c(Component), path, pos);
				END;
			END;
			c := x.GetNext(c);
		END;
		RETURN NIL
	END
END FindRelativePath;

(* Report errors while parsing *)
PROCEDURE Error(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
BEGIN
	KernelLog.String("Parse error at pos "); KernelLog.Int(pos, 5); KernelLog.String(" in line "); KernelLog.Int(line, 5);
	KernelLog.String(" row "); KernelLog.Int(row, 5); KernelLog.String(" - "); KernelLog.String(msg); KernelLog.Ln;
	hasErrors := TRUE
END Error;

(** Load an XML file. Return NIL if errors occured *)
PROCEDURE Load*(CONST filename : ARRAY OF CHAR) : XML.Content;
VAR scanner : XMLScanner.Scanner;
	parser : XMLParser.Parser;
	doc : XML.Document;
	in : Streams.Reader;
BEGIN {EXCLUSIVE}
	hasErrors := FALSE;
	in := Codecs.OpenInputStream(filename);
	IF in # NIL THEN
		NEW(scanner, in); scanner.reportError := Error;
		NEW(parser, scanner); parser.reportError := Error;
		parser.elemReg := Repositories.registry; doc := parser.Parse();
		IF hasErrors THEN RETURN NIL END;
		RETURN doc.GetRoot()
	END;
	RETURN NIL
END Load;

PROCEDURE FormWindowGen*(xml:XML.Content): WM.Window; 
VAR winx: XML.Element; formx: XML.Content; window: FormWindow; name, string:Strings.String; canvas:WMGraphics.BufferCanvas;
	canvasGenerator: WMGraphics.CanvasGenerator;
	moduleName, procedureName : Modules.Name;
	msg : ARRAY 128 OF CHAR;
	res: LONGINT;
	l,t,r,b: LONGINT;
BEGIN
	IF xml IS XML.Element THEN
		winx:=xml(XML.Element);
		string:=winx.GetName();
		IF string^="FormWindow" THEN
			string:=winx.GetAttributeValue("l"); Strings.StrToInt(string^,l);
			string:=winx.GetAttributeValue("t"); Strings.StrToInt(string^,t);
			string:=winx.GetAttributeValue("r"); Strings.StrToInt(string^,r);
			string:=winx.GetAttributeValue("b"); Strings.StrToInt(string^,b);
			NEW(window, r-l, b-t, TRUE);
			name:=winx.GetAttributeValue("name"); window.SetTitle(name);
			window.bounds.r:=r; window.bounds.l:=l; window.bounds.t:=t; window.bounds.b:=b;
			string:=winx.GetAttributeValue("flags"); Strings.StrToSet(string^,window.flags);
			string:=winx.GetAttributeValue("canvasGenerator"); (* allow to plug in alternative canvas versions,e.g. WMGraphicsGfx.Canvas *)
			IF (string#NIL) THEN
				Commands.Split(string^, moduleName, procedureName, res, msg);
				IF (res = Commands.Ok) THEN
					GETPROCEDURE(moduleName, procedureName, canvasGenerator);
					IF (canvasGenerator # NIL) THEN
						window.SetCanvasGenerator(canvasGenerator);
					END;
				END;
			END;
			
			formx:=winx.GetFirst(); (* this typically has name="Form" *)
			IF (formx#NIL)&(formx IS XML.Element) THEN
				window.LoadComponents(formx(XML.Element)); (* at the price of duplication of component tree construction ...*)
				window.form.Reset(NIL,NIL);
			ELSE window:=NIL;
			END;
		END;
	END;
	RETURN window
END FormWindowGen;

(* generic loading of any form window using the generator procedure supplied in the XML as 'loader' attribute *)
PROCEDURE LoadFormWindow*(xml:XML.Content): WM.Window;
VAR winx: XML.Element; window: WM.Window; formWindow:FormWindow;
formx, c:Component;
	name, string, load:Strings.String;
	moduleName, procedureName : Modules.Name;
	msg : ARRAY 128 OF CHAR;
	res: LONGINT;
	gen:WindowGenerator;
	bounds:Rectangles.Rectangle;
BEGIN
	IF xml IS XML.Element THEN
		winx:=xml(XML.Element);
		name:=winx.GetName();
		IF name^="FormWindow" THEN
			string:=winx.GetAttributeValue("loader");
			Commands.Split(string^, moduleName, procedureName, res, msg);
			IF (res = Commands.Ok) THEN
				GETPROCEDURE(moduleName, procedureName, gen);
				IF (gen # NIL) THEN
					window:=gen(xml);
				END;
			END;
		ELSE (*generate FormWindow from generic Visual Component*)
			c:=ComponentFromXML(xml(XML.Element));
			IF (c#NIL) & (c IS VisualComponent) THEN
				bounds:=c(VisualComponent).bounds.Get();
				NEW(formWindow, bounds.r-bounds.l, bounds.b-bounds.t, TRUE);
				formWindow.SetContent(c);
				(*formWindow.SetTitle(c.GetName());*)
				window:=formWindow;
			END;
		END;
	END;
	RETURN window
END LoadFormWindow;

(** Open form window and build its component tree *)
PROCEDURE Open*(context : Commands.Context); 
VAR filename: Files.FileName; window: WM.Window; xml:XML.Content;
BEGIN
	IF context.arg.GetString(filename) & (Strings.Length(filename)>0) THEN
		xml:=Load(filename); (* here, the xml tree is already constructed, however not in the right sequence for component contruction ( [Init()..loadProperties()..Initialize()] )*)
		window:=LoadFormWindow(xml);
		IF window#NIL THEN 
			WM.AddWindow(window,window.bounds.l,window.bounds.t); 
		END;
	END;
END Open;

PROCEDURE LoadStyleInternal(CONST filename : ARRAY OF CHAR);
VAR f : Files.File;
	scanner : XMLScanner.Scanner;
	parser : XMLParser.Parser;
	reader : Files.Reader;
	doc : XML.Document;
BEGIN
	hasErrors := FALSE;
	f := Files.Old(filename);
	IF f # NIL THEN
		NEW(reader, f, 0);
		NEW(scanner, reader); scanner.reportError := Error;
		NEW(parser, scanner); parser.reportError := Error;
		parser.elemReg := Repositories.registry; doc := parser.Parse();
		IF hasErrors THEN KernelLog.String("Stylefile not ok"); KernelLog.Ln
		ELSE
			SetStyleInternal(doc.GetRoot())
		END
	END
END LoadStyleInternal;

(** Load Component registry file. Return NIL if errors occured *)
PROCEDURE LoadStyle*(context : Commands.Context);
VAR filename : ARRAY 64 OF CHAR;
BEGIN {EXCLUSIVE}
	IF context.arg.GetString(filename) THEN
		LoadStyleInternal(filename);
	ELSE
		context.result := Commands.CommandParseError;
	END;
END LoadStyle;

PROCEDURE NewString*(CONST x : ARRAY OF CHAR) : Strings.String;
VAR t : Strings.String;
BEGIN
	NEW(t, LEN(x)); COPY(x, t^); RETURN t
END NewString;

PROCEDURE InitStrings;
BEGIN
	StrComponent := NewString("Component");
	StrVisualComponent := NewString("VisualComponent");
	StrForm := NewString("Form");
	StrFormWindow := NewString("FormWindow");
	GSonStartDrag := NewString("onStartDrag");
	GSonStartDragInfo := NewString("Event generated whenever a drag is started");
	StrModel := NewString("Model");
	StrModelInfo := NewString("Model used by component");
END InitStrings;

PROCEDURE InitPrototypes;
BEGIN
	(* General component properties *)
	NEW(PrototypeID, NIL, NewString("ID"),
		NewString("identifier of the component"));
	NEW(PrototypeUID, NIL, NewString("UID"),
		NewString("unique identifier of the component"));
	NEW(PrototypeEnabled, NIL, NewString("Enabled"),
		NewString("defines if the component is enabled"));
	PrototypeEnabled.Set(TRUE);
	(* Visual component properties *)
	NEW(PrototypeBounds, NIL, NewString("Bounds"),
		NewString("the bounding box of the component in parent coordinates"));
	NEW(PrototypeBoundsRelative, NIL, NewString("RelBounds"),
		NewString("the bounding box of the component in relative parent coordinates"));
	NEW(PrototypeBearing, NIL, NewString("Bearing"),
		NewString("the bearing (empty space) aroung the component if auto aligned"));
	NEW(PrototypeFillColor, NIL, NewString("FillColor"),
		NewString("the main fill color of the component. i.e. background"));
	NEW(PrototypeAlignment, NIL, NewString("Alignment"),
		NewString("defines the alignment none, left, right, top, bottom or client"));
	PrototypeAlignment.Set(0);

	NEW(PrototypeVisible, NIL, NewString("Visible"),
		NewString("defines if the component is visible"));
	PrototypeVisible.Set(TRUE);

	NEW(PrototypeTakesFocus, NIL, NewString("TakesFocus"),
		NewString("defines if the component takes the keyboard focus"));
	NEW(PrototypeNeedsTab, NIL, NewString("NeedsTab"),
		NewString("defines if the component handles the tabulator key"));
	NEW(PrototypeFocusPrevious, NIL, NewString("FocusPrevious"), NewString("Previous focus component ID"));
	PrototypeFocusPrevious.Set(NIL);
	NEW(PrototypeFocusNext, NIL, NewString("FocusNext"), NewString("Next focus component ID"));
	PrototypeFocusNext.Set(NIL);
	NEW(PrototypeEditMode, NIL, NewString("EditMode"), NewString("defines if the contents of the component can be edited"));
	PrototypeEditMode.Set(FALSE);
	NEW(PrototypeFont, NIL, NewString("Font"), NewString("Font"));
	PrototypeFont.Set(WMGraphics.GetDefaultFont());
	NEW(PrototypeScaleFont, NIL, Strings.NewString("ScaleFont"), Strings.NewString("percentage that fonts scales with height (0=none)"));
	NEW(ModelPrototype, NIL, StrModel, StrModelInfo);
END InitPrototypes;

PROCEDURE ShowComponent(component : Component);
VAR string : Strings.String;
BEGIN
	IF (component # NIL) THEN
		string := component.GetName();
		IF (string # NIL) THEN KernelLog.String(string^); ELSE KernelLog.String("NoName"); END;
		KernelLog.String(" [");
		string := component.uid.Get();
		IF (string # NIL) THEN KernelLog.String(string^); ELSE KernelLog.String("NIL"); END;
		IF (component IS VisualComponent) THEN
			KernelLog.String(", "); KernelLog.Boolean(component(VisualComponent).takesFocus.Get());
		END;
		KernelLog.String("]");
	ELSE
		KernelLog.String("NIL?");
	END;
END ShowComponent;

PROCEDURE NewLine(w : Streams.Writer; level : LONGINT);
BEGIN
	w.Ln; WHILE level > 0 DO w.Char(09X); DEC(level) END
END NewLine;

PROCEDURE InstallDefaultMacroHandler;
BEGIN
	NEW(macroHandlers);
	macroHandlers.handler := DefaultMacroHandler;
	macroHandlers.namespace := DefaultNamespace;
	macroHandlers.next := NIL;
END InstallDefaultMacroHandler;

(*! ---- xml tool --- move to where appropriate *)
PROCEDURE GetElementByName(parent : XML.Element; CONST name : ARRAY OF CHAR) : XML.Element;
VAR elem : XML.Element; enum : XMLObjects.Enumerator; ptr : ANY; string : Strings.String;
BEGIN
	IF parent # NIL THEN
		enum := parent.GetContents(); enum.Reset();
		WHILE enum.HasMoreElements() DO
			ptr := enum.GetNext();
			IF ptr IS XML.Element THEN
				elem := ptr (XML.Element);
				string := elem.GetName();
				IF (string # NIL) & (string^ = name) THEN
					RETURN elem;
				END;
			END;
		END;
 	END;
 	RETURN NIL;
END GetElementByName;

PROCEDURE NewComponent*(): XML.Element;
VAR component: Component;
BEGIN NEW(component); RETURN component;
END NewComponent;

PROCEDURE NewVisualComponent*(): XML.Element;
VAR component: VisualComponent;
BEGIN NEW(component); RETURN component;
END NewVisualComponent;

(* does not work like this its own because a form is statically bound to a window, but for completeness.. *)
PROCEDURE NewForm*(): XML.Element;
VAR component: Form;
BEGIN NEW(component, NIL); RETURN component
END NewForm;

PROCEDURE Align*(context: Commands.Context);
VAR width,height,bwidth,bheight: LONGINT; entry: ComponentListEntry; b,rect: Rectangles.Rectangle; string: ARRAY 32 OF CHAR; l,t: LONGINT; done: BOOLEAN;
BEGIN
	entry := selection.first;
	rect.l := MAX(LONGINT); rect.r := MIN(LONGINT);
	rect.t := MAX(LONGINT); rect.b := MIN(LONGINT);
	width := 0; height := 0;

	WHILE entry # NIL DO
		b := entry.component.bounds.Get();
		bwidth := b.r-b.l; bheight := b.b-b.t;
		IF b.l < rect.l THEN rect.l := b.l END;
		IF b.r > rect.r THEN rect.r := b.r END;
		IF b.t < rect.t THEN rect.t := b.t END;
		IF b.b > rect.b THEN rect.b := b.b END;
		IF width < bwidth THEN width := bwidth END;
		IF height < bheight THEN height := bheight END;
		entry := entry.next
	END;

	done := FALSE;
	WHILE ~done & context.arg.GetString(string) DO
		l := rect.l; t := rect.t;
		entry := selection.first;
		WHILE ~done & (entry # NIL) DO
			b := entry.component.bounds.Get(); bwidth := b.r-b.l; bheight := b.b-b.t;
			entry.component.AdaptRelativeBounds(b,entry.component.GetParent());
			IF string = "left" THEN b.l := rect.l; b.r := rect.l + bwidth;
			ELSIF string = "right" THEN b.r := rect.r; b.l := rect.r-bwidth
			ELSIF string = "top" THEN b.t := rect.t; b.b := rect.t + bheight;
			ELSIF string = "bottom" THEN b.b := rect.b; b.t := rect.b-bheight
			ELSIF string = "width" THEN b.r := b.l + width;
			ELSIF string = "height" THEN b.b := b.t + height;
			ELSIF string = "size" THEN b.r := b.l + width; b.b := b.t + height;
			ELSIF string = "hcenter" THEN b.l := (rect.l+rect.r) DIV 2 - bwidth DIV 2; b.r := b.l + bwidth;
			ELSIF string = "vcenter" THEN b.t := (rect.t + rect.b) DIV 2 - bheight DIV 2; b.b := b.t + bheight;
			ELSIF string = "horizontal" THEN b.l := l; b.r := b.l + bwidth; l := b.r+1
			ELSIF string = "vertical" THEN b.t := t; b.b := b.t + bheight; t := b.b + 1;
			ELSIF string = "none" THEN  entry.component.alignment.Set(AlignNone)
			ELSIF string = "relative" THEN  entry.component.alignment.Set(AlignRelative)
			ELSE done := TRUE
			END;
			entry.component.AdaptRelativeBounds(b,entry.component.GetParent());
			entry.component.bounds.Set(b);
			entry := entry.next
		END;
	END;

END Align;

PROCEDURE SetProperty*(context: Commands.Context);
VAR name, value: ARRAY 256 OF CHAR; entry: ComponentListEntry;
BEGIN
	IF context.arg.GetString(name) & context.arg.GetString(value) THEN
		entry := selection.first;
		WHILE entry # NIL DO
			IF entry.component.properties.SetPropertyValue(name, value) THEN END;
			entry := entry.next;
		END;
	END;
END SetProperty;

PROCEDURE RemoveSelection*;
VAR entry: ComponentListEntry; parent: XML.Element;
BEGIN
	entry := selection.first;
	WHILE entry # NIL DO
		parent := entry.component.GetParent();
		IF parent # NIL THEN parent(VisualComponent).RemoveContent(entry.component); parent(VisualComponent).Invalidate END;
		entry := entry.next
	END;
END RemoveSelection;


PROCEDURE ComponentFromXML*(xml: XML.Element): Component;
VAR generator: PROCEDURE(): XML.Element;
VAR
	l,name: Strings.String;
	moduleName, procedureName: Modules.Name;
	res: LONGINT; msg: ARRAY 32 OF CHAR;
	component: Component;
	element: XML.Element;
BEGIN
	component := NIL;
	IF xml # NIL THEN
		name := xml.GetName();
		l := xml.GetAttributeValue("generator");
		IF l # NIL THEN
			Commands.Split(l^, moduleName, procedureName, res, msg);
			IF (res = Commands.Ok) THEN
				GETPROCEDURE(moduleName, procedureName, generator);
				IF (generator # NIL) THEN
					element := generator();
					IF (element # NIL) & (element IS Component) THEN
						component := element(Component);
						component.SetName(name^);
						component.FromXML(xml);
					END;
				ELSE KernelLog.String("WMComponents error: invalid generator "); KernelLog.String(l^); KernelLog.Ln;
				END;
			ELSE KernelLog.String("WMComponents error: could not generate component "); KernelLog.String(l^); KernelLog.Ln;
			END;
		END;
	END;
	RETURN component
END ComponentFromXML;

PROCEDURE Clone*(x: Component): Repositories.Component;
BEGIN
	RETURN ComponentFromXML(x)
END Clone;


BEGIN
	timestamp := 0;
	NEW(componentStyleMsg);
	NEW(propertyListList);
	InitStrings;
	InitPrototypes;
	NEW(invalidateRectMsg);
	InstallDefaultMacroHandler;
	NEW(selection);
END WMComponents.

WMComponents.Open Test.Cwd ~
WMComponents.Open DictEntry.wm ~

The message sequencer contains a reader writer lock that can be used to block the hierarchy.
Each message-call from the sequencer posesses the writer lock.

WMComponents.LoadStyle ComponentStyle.XML  ~

If a focusComponent is set in an non-focus container-component, the focus can not escape the "isolated" component group