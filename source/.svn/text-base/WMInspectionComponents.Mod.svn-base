MODULE WMInspectionComponents; (** AUTHOR "staubesv"; PURPOSE "Components for component inspection"; *)
(**

	This module implements some components that are used by component inspection tools.

	PropertyPanel
		StandardProperties(ComponentElement)
		ExtendedProperties(ComponentElement)
		EventSources(ComponentElement)
		EventListeners(ComponentElement)

		whereas

		StandardProperties displays all properties common to all components and visual components
		ExtendedProperties is a property sheet the displays all other properties
		EventSources displays the event sources of a component
		EventListeners displays the event listeners of a component

		The ExtendedProperties component is a automatically generated property sheet consisting of
			BooleanPropertyView, Int32PropertyView, RectanglePropertyView, StringPropertyView and ColorPropertyView components

	RepositoryPanel
		Displays the repository the component is bound to (if any)
		Offers a button to bind the component to a repository

*)

IMPORT
	SYSTEM,
	Modules, Kernel, KernelLog, Strings, Inputs, Files, XML, XMLObjects, Repositories, Types, Models, WMDialogs, WMUtilities,
	WMMessages, WMWindowManager,
	WMRectangles, WMGraphics, WMEvents, WMProperties, WMComponents, WMStandardComponents,
	WMEditors, WMColorComponents, WMDropDownLists, WMTabComponents, WMScrollableComponents, Raster, D:= Debugging,
	Streams, WMDropTarget, Commands;

CONST
	Ok = 0;
	CannotHandle = 1;

	LineHeight = 20;
	LineBearing = 2;

	NameWidth = 80;

	(** maximum number of property sheet cache entries per instance *)
	MaxNofCacheEntries = 20;

	ModelWindowWidth = 320; ModelWindowHeight = 80;

TYPE
	SetStringProcedure = PROCEDURE {DELEGATE} (CONST string : ARRAY OF CHAR; position : LONGINT; VAR res : LONGINT);

	DropTarget = OBJECT(WMDropTarget.DropTarget)
	VAR
		originator : ANY;
		setString : SetStringProcedure;
		position : LONGINT;

		PROCEDURE &Init(originator : ANY; setString : SetStringProcedure; position : LONGINT);
		BEGIN
			ASSERT(setString # NIL);
			SELF.originator := originator;
			SELF.setString := setString;
			SELF.position := position;
		END Init;

		PROCEDURE GetInterface(type : LONGINT) : WMDropTarget.DropInterface;
		VAR sdi : DropString;
		BEGIN
			IF (type = WMDropTarget.TypeString) THEN
				NEW(sdi, originator, setString, position); RETURN sdi;
			ELSE
				RETURN NIL;
			END;
		END GetInterface;

	END DropTarget;

	DropString = OBJECT(WMDropTarget.DropString)
	VAR
		originator : ANY;
		setString : SetStringProcedure;
		position : LONGINT;

		PROCEDURE &Init(originator : ANY; setString : SetStringProcedure; position : LONGINT);
		BEGIN
			ASSERT(setString # NIL);
			SELF.originator := originator;
			SELF.setString := setString;
			SELF.position := position;
		END Init;

		PROCEDURE Set(CONST string : ARRAY OF CHAR; VAR res : LONGINT);
		BEGIN
			setString(string, position, res);
		END Set;

	END DropString;


	(** Base class of property view classes used by ExtendedProperties component *)
	PropertyView = OBJECT(WMComponents.VisualComponent)
	VAR
		property : WMProperties.Property;
		name, info : Strings.String;
		type : ARRAY 32 OF CHAR;
		ofsName, ofsInfo : LONGINT;
		lastTimestamp : LONGINT;

		next : PropertyView;

		nameLabel, infoLabel, adrLabel : WMStandardComponents.Label;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("PropertyView"));
			property := NIL;
			ofsName := 0; ofsInfo := 200;
			alignment.Set(WMComponents.AlignTop);
			bounds.SetHeight(LineHeight);
			bearing.Set(WMRectangles.MakeRect(LineBearing, LineBearing, LineBearing, LineBearing));
			next := NIL;

			NEW(nameLabel); nameLabel.alignment.Set(WMComponents.AlignLeft);
			nameLabel.bounds.SetWidth(NameWidth);
			nameLabel.fillColor.Set(0);
			nameLabel.bearing.Set(WMRectangles.MakeRect(2, 0, 2, 0));
			AddContent(nameLabel);
			nameLabel.onStartDrag.Add(InfoLabelStartDrag); (* trick to make popup *)
			nameLabel.SetExtPointerMoveHandler(InfoLabelMove);

			NEW(infoLabel); infoLabel.alignment.Set(WMComponents.AlignLeft);
			infoLabel.bounds.SetWidth(20);
			infoLabel.fillColor.Set(0);
			infoLabel.alignH.Set(WMGraphics.AlignCenter);
			AddContent(infoLabel);
			infoLabel.onStartDrag.Add(InfoLabelStartDrag); (* trick to make popup *)
			infoLabel.SetExtPointerMoveHandler(InfoLabelMove);

			NEW(adrLabel); adrLabel.alignment.Set(WMComponents.AlignLeft);
			adrLabel.bounds.SetWidth(40);
			adrLabel.fillColor.Set(0CCCCFFFFH);
			adrLabel.bearing.Set(WMRectangles.MakeRect(2, 0, 2, 0));
			AddContent(adrLabel);
			adrLabel.onStartDrag.Add(MyStartDrag);
			adrLabel.SetExtPointerMoveHandler(AdrLabelMove);
			adrLabel.SetExtDragDroppedHandler(MyDragDropped);

		END Init;

		PROCEDURE UpdateAdrLabel(object : XML.Element);
		VAR string : Types.String32; res : LONGINT; nbrStr : ARRAY 17 OF CHAR; t: Modules.TypeDesc;
		BEGIN
			IF (object # NIL) THEN
				t := Modules.TypeOf(object);
				COPY(t.name, nbrStr);
				adrLabel.caption.SetAOC(nbrStr);
				adrLabel.fillColor.Set(0CCFFH);
				adrLabel.textColor.Set(WMGraphics.White);
			ELSE
				adrLabel.caption.SetAOC("NIL");
				adrLabel.fillColor.Set(0CCCCFFFFH);
				adrLabel.textColor.Set(WMGraphics.Black);
			END;
		END UpdateAdrLabel;

		PROCEDURE AdrLabelMove(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR dx, dy, dp, d : LONGINT; f : REAL; tmax, tmin : LONGINT;
		BEGIN
			IF keys = {0} THEN adrLabel.AutoStartDrag END;
		END AdrLabelMove;

		PROCEDURE MyStartDrag(sender, data: ANY);
		VAR w,h: LONGINT; img: WMGraphics.Image; canvas: WMGraphics.BufferCanvas;
		BEGIN
			NEW(img);
			adrLabel.bounds.GetExtents(w,h);
			Raster.Create(img, w,h, Raster.BGRA8888);
			NEW(canvas,img);
			adrLabel.Draw(canvas);
			IF StartDrag(property.GetLink(),img,0,0,NIL,NIL) THEN END;
		END MyStartDrag;

		PROCEDURE InfoLabelMove(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR dx, dy, dp, d : LONGINT; f : REAL; tmax, tmin : LONGINT;
		BEGIN
			IF keys = {0} THEN infoLabel.AutoStartDrag END;
		END InfoLabelMove;

		PROCEDURE InfoLabelStartDrag(sender, data: ANY);
		VAR w,h: LONGINT; img: WMGraphics.Image; canvas: WMGraphics.BufferCanvas; font: WMGraphics.Font; string: Strings.String;
		BEGIN
			IF info # NIL THEN string := info
			ELSIF name # NIL THEN string := name
			ELSE RETURN
			END;
			IF string = NIL THEN RETURN END;
			NEW(img);
			font := GetFont();
			font.GetStringSize(string^,w,h);
			INC(w,20); INC(h,5);
			Raster.Create(img, w,h, Raster.BGRA8888);
			NEW(canvas,img);
			canvas.SetFont(font);
			canvas.SetColor(LONGINT(0FFFFFFFFH));
			canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), LONGINT(0333333FFH), WMGraphics.ModeCopy);
			WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(0, 0, w, h), FALSE, 1, 1, string^);
			IF StartDrag(NIL,img,0,0,NIL,NIL) THEN END;
		END InfoLabelStartDrag;

		PROCEDURE MyDragDropped(x,y: LONGINT; dragInfo: WMWindowManager.DragInfo; VAR handled: BOOLEAN);
		VAR ref,sender: ANY; dt: DropTarget; pos: LONGINT;
		BEGIN
			ref := dragInfo.data;
			sender := dragInfo.sender;
			IF (ref # NIL) & (ref IS Repositories.Component) THEN
				property.SetLink(ref(Repositories.Component));
				handled := TRUE;
				UpdateAdrLabel(property.GetLink());
			ELSIF ref = NIL THEN
				property.SetLink(NIL);
				handled := TRUE;
				UpdateAdrLabel(property.GetLink());

				NEW(dt, SELF, SetDroppedString, pos);
				dragInfo.data := dt;
				ConfirmDrag(TRUE, dragInfo);
			ELSE HALT(100);
			END;
		END MyDragDropped;

		PROCEDURE SetDroppedString( CONST string : ARRAY OF CHAR; position : LONGINT; VAR res : LONGINT);
		VAR object: ANY; gen: XML.GeneratorProcedure; moduleName, procedureName ,msg: Modules.Name; element: XML.Element;

		BEGIN
			Commands.Split(string, moduleName, procedureName, res, msg);
			IF (res = Commands.Ok) THEN
				GETPROCEDURE(moduleName, procedureName, gen);
			END;
			IF gen # NIL THEN
				element := gen();
				IF (element # NIL) & (element IS Repositories.Component) THEN
					property.SetLink(element(Repositories.Component));
					res := 1;
					RETURN
				END;
			END;
			property.SetLinkAsString(string);
			object := property.GetLink();
			res := 1; (* to avoid removal of source *)
		END SetDroppedString;

		(* Apply the settings of the view to the property *)
		PROCEDURE Apply(force : BOOLEAN);
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		BEGIN
			IF property # NIL THEN
				UpdateAdrLabel(property.GetLink())
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		END IsCompatible;

		PROCEDURE Enable;
		END Enable;

		PROCEDURE Disable;
		END Disable;

		PROCEDURE Draw(canvas : WMGraphics.Canvas);
		BEGIN
			Draw^(canvas);
			(*
			IF (ofsName >= 0) THEN
				IF (name # NIL) THEN
					canvas.DrawString(ofsName, 14, name^);
				ELSE
					canvas.DrawString(ofsName, 14, "NoName");
				END;
			END;
			IF (ofsInfo >= 0) THEN
				IF (info # NIL) THEN
					canvas.DrawString(ofsInfo, 14, info^);
				ELSE
					canvas.DrawString(ofsInfo, 14, "NoDescription");
				END;
			END;
			*)
		END Draw;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			SELF.property := property;
			IF (property # NIL) THEN
				GetPropertyType(property, type);
				name := property.GetName();
				info := property.GetInfo();
				lastTimestamp := property.GetTimestamp() - 1;
				IF (info # NIL) & (info^ # "") THEN
					infoLabel.caption.SetAOC("i");
					infoLabel.fillColor.Set(0FFFF88FFH);
				ELSE
					infoLabel.caption.SetAOC("");
					infoLabel.fillColor.Set(0);
				END;
				IF name # NIL THEN
					nameLabel.caption.SetAOC(name^);
					nameLabel.fillColor.Set(0FFFF88FFH);
				ELSE
					nameLabel.caption.SetAOC("Unnamed");
					nameLabel.fillColor.Set(0);
				END;
			ELSE
				nameLabel.caption.SetAOC("");
				infoLabel.caption.SetAOC("");
				nameLabel.fillColor.Set(0);
				infoLabel.fillColor.Set(0);
				name := NIL;
				info := NIL;
			END;
		END SetProperty;

	END PropertyView;

TYPE
	EnumeratorProc = PROCEDURE {DELEGATE} (p : PropertyView; force : BOOLEAN);

	PropertyViewArray = POINTER TO ARRAY OF PropertyView;

	PropertyViewList = OBJECT
	VAR
		head, tail : PropertyView;
		nofElements : LONGINT;

		PROCEDURE &Init;
		BEGIN
			head := NIL; tail := NIL;
			nofElements := 0;
		END Init;

		PROCEDURE Add(p : PropertyView);
		BEGIN {EXCLUSIVE}
			ASSERT((p # NIL) & (p.next = NIL));
			IF (head = NIL) THEN
				ASSERT(tail = NIL);
				head := p; tail := p;
			ELSE
				tail.next := p;
				tail := p;
			END;
			INC(nofElements);
		END Add;

		PROCEDURE RemoveAll;
		BEGIN {EXCLUSIVE}
			head := NIL; tail := NIL;
			nofElements := 0;
		END RemoveAll;

		PROCEDURE Enumerate(enumeratorProc : EnumeratorProc; force : BOOLEAN);
		VAR p : PropertyView;
		BEGIN {EXCLUSIVE}
			ASSERT(enumeratorProc # NIL);
			p := head;
			WHILE (p # NIL) DO
				enumeratorProc(p, force);
				IF (p.next # NIL) THEN
					p := p.next (PropertyView);
				ELSE
					p := NIL;
				END;
			END;
		END Enumerate;

		PROCEDURE GetAll() : PropertyViewArray;
		VAR pva : PropertyViewArray; cur : PropertyView; i : LONGINT;
		BEGIN
			IF (nofElements > 0) THEN
				NEW(pva, nofElements);
				cur := head;
				FOR i := 0 TO nofElements - 1 DO
					pva[i] := cur; cur := cur.next;
				END;
			ELSE
				pva := NIL;
			END;
			RETURN pva;
		END GetAll;

	END PropertyViewList;

TYPE

	BooleanPropertyView = OBJECT(PropertyView)
	VAR
		boolean : WMProperties.BooleanProperty;
		checkbox : WMStandardComponents.Checkbox;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrBooleanPropertyView);

			NEW(checkbox); checkbox.alignment.Set(WMComponents.AlignLeft);
			checkbox.bounds.SetWidth(LineHeight);
			checkbox.onClick.Add(CheckboxClicked);
			AddContent(checkbox);
		END Init;

		PROCEDURE Apply(force : BOOLEAN);
		VAR boolean : WMProperties.BooleanProperty; value : BOOLEAN; state : LONGINT;
		BEGIN
			boolean := SELF.boolean;
			IF (boolean # NIL) THEN
				state := checkbox.state.Get();
				value := boolean.Get();
				IF force OR ((value & (state # WMStandardComponents.Checked)) OR (~value & (state # WMStandardComponents.Unchecked))) THEN
					IF (state = WMStandardComponents.Checked) THEN
						boolean.Set(TRUE);
					ELSIF (state = WMStandardComponents.Unchecked) THEN
						boolean.Set(FALSE);
					ELSE
						HALT(99);
					END;
				END;
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR boolean : WMProperties.BooleanProperty; state : LONGINT;
		BEGIN
			Synchronize^(force);
			boolean := SELF.boolean;
			IF (boolean # NIL) & (force OR (lastTimestamp # boolean.GetTimestamp())) THEN
				lastTimestamp := boolean.GetTimestamp();
				IF (boolean.Get()) THEN
					state := WMStandardComponents.Checked;
				ELSE
					state := WMStandardComponents.Unchecked;
				END;
				checkbox.state.Set(state);
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL) & (property IS WMProperties.BooleanProperty);
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			checkbox.enabled.Set(TRUE);
		END Enable;

		PROCEDURE Disable;
		BEGIN
			checkbox.enabled.Set(FALSE);
		END Disable;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.BooleanProperty)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.boolean := property (WMProperties.BooleanProperty);
			ELSE
				SELF.boolean := NIL;
				checkbox.state.Set(WMStandardComponents.Unchecked);
			END;
		END SetProperty;

		PROCEDURE CheckboxClicked(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END CheckboxClicked;

	END BooleanPropertyView;

TYPE

	Int32PropertyView = OBJECT(PropertyView)
	VAR
		int32 : WMProperties.Int32Property;
		editor : WMEditors.TextField;
		outOfDate : BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrInt32PropertyView);
			outOfDate := FALSE;

			NEW(editor); editor.alignment.Set(WMComponents.AlignLeft);
			editor.type.Set(WMEditors.Decimal);
			editor.bounds.SetWidth(80);
			editor.onEnter.Add(EnterPressed);
			editor.onChanged.Add(EditorContentChanged);
			AddContent(editor);
		END Init;

		PROCEDURE Apply(force : BOOLEAN);
		VAR int32 : WMProperties.Int32Property; string : ARRAY 256 OF CHAR; value : LONGINT;
		BEGIN
			int32 := SELF.int32;
			IF (int32 # NIL) THEN
				editor.GetAsString(string);
				Strings.StrToInt(string, value);
				IF force OR (value # int32.Get()) THEN
					int32.Set(value);
				ELSE
					SetOutOfDate(FALSE);
				END;
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR int32 : WMProperties.Int32Property; value : LONGINT; string : ARRAY 256 OF CHAR;
		BEGIN
			Synchronize^(force);
			int32 := SELF.int32;
			IF (int32 # NIL) & (force OR (lastTimestamp # int32.GetTimestamp())) THEN
				lastTimestamp := int32.GetTimestamp();
				value := int32.Get();
				Strings.IntToStr(value, string);
				editor.SetAsString(string);
				SetOutOfDate(FALSE);
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL) & (property IS WMProperties.Int32Property);
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			editor.enabled.Set(TRUE);
		END Enable;

		PROCEDURE Disable;
		BEGIN
			editor.enabled.Set(FALSE);
		END Disable;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.Int32Property)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.int32 := property (WMProperties.Int32Property);
			ELSE
				SELF.int32 := NIL;
				editor.SetAsString("");
			END;
		END SetProperty;

		PROCEDURE SetOutOfDate(value : BOOLEAN);
		BEGIN
			IF (outOfDate # value) THEN
				outOfDate := value;
				IF outOfDate THEN
					editor.fillColor.Set(LONGINT(0FFFF0099H));
				ELSE
					editor.fillColor.Set(WMGraphics.White);
				END;
			END;
		END SetOutOfDate;

		PROCEDURE EditorContentChanged(sender, data : ANY);
		BEGIN
			SetOutOfDate(TRUE);
		END EditorContentChanged;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END EnterPressed;

	END Int32PropertyView;

TYPE

	RealPropertyView = OBJECT(PropertyView)
	VAR
		real : WMProperties.RealProperty;
		editor : WMEditors.TextField;
		outOfDate : BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrRealPropertyView);
			outOfDate := FALSE;

			NEW(editor); editor.alignment.Set(WMComponents.AlignLeft);
			editor.type.Set(WMEditors.Ascii);
			editor.bounds.SetWidth(80);
			editor.onEnter.Add(EnterPressed);
			editor.onChanged.Add(EditorContentChanged);
			AddContent(editor);
		END Init;

		PROCEDURE Apply(force : BOOLEAN);
		VAR real : WMProperties.RealProperty; string : ARRAY 256 OF CHAR; value : LONGREAL;
		BEGIN
			real := SELF.real;
			IF (real # NIL) THEN
				editor.GetAsString(string);
				Strings.StrToFloat(string, value);
				IF force OR (value # real.Get()) THEN
					real.Set(value);
				ELSE
					SetOutOfDate(FALSE);
				END;
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR real : WMProperties.RealProperty; value : LONGREAL; string : ARRAY 256 OF CHAR; sw: Streams.StringWriter;
		BEGIN
			Synchronize^(force);
			real := SELF.real;
			IF (real # NIL) & (force OR (lastTimestamp # real.GetTimestamp())) THEN
				lastTimestamp := real.GetTimestamp();
				value := real.Get();
				(*Strings.FloatToStr(value, 0, 16, 0, string);*) (*PH2012*)(*! to do: this string procedure is not suited for exponents*)
				(*workaround: *)
				NEW(sw, 30);
				sw.Float(value,24);
				sw.Get(string);
				editor.SetAsString(string);
				SetOutOfDate(FALSE);
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL) & (property IS WMProperties.RealProperty);
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			editor.enabled.Set(TRUE);
		END Enable;

		PROCEDURE Disable;
		BEGIN
			editor.enabled.Set(FALSE);
		END Disable;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.RealProperty)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.real := property (WMProperties.RealProperty);
			ELSE
				SELF.real := NIL;
				editor.SetAsString("");
			END;
		END SetProperty;

		PROCEDURE SetOutOfDate(value : BOOLEAN);
		BEGIN
			IF (outOfDate # value) THEN
				outOfDate := value;
				IF outOfDate THEN
					editor.fillColor.Set(LONGINT(0FFFF0099H));
				ELSE
					editor.fillColor.Set(WMGraphics.White);
				END;
			END;
		END SetOutOfDate;

		PROCEDURE EditorContentChanged(sender, data : ANY);
		BEGIN
			SetOutOfDate(TRUE);
		END EditorContentChanged;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END EnterPressed;

	END RealPropertyView;

TYPE

	RectanglePropertyView = OBJECT(PropertyView)
	VAR
		rectangle : WMProperties.RectangleProperty;
		editLeft, editTop, editRight, editBottom, editWidth, editHeight : WMEditors.TextField;
		enabled, outOfDate : SET;

		PROCEDURE &New(wh : BOOLEAN);
		BEGIN
			Init;
			SetNameAsString(StrRectanglePropertyView);
			ofsInfo := -1;
			CreateEditor("Left:", editLeft, 0);
			CreateEditor("Top:", editTop, 0);
			CreateEditor("Right: ", editRight, 0);
			CreateEditor("Bottom:", editBottom, 0);
			IF wh THEN
				CreateEditor("Width: ", editWidth, 0);
				CreateEditor("Height:", editHeight, 0);
			END;
			enabled := {0..5};
			outOfDate := {};
		END New;

		PROCEDURE UpdateEditorStates;

			PROCEDURE UpdateState(editor : WMEditors.TextField; number: LONGINT);
			BEGIN
				IF (number IN enabled) THEN
					editor.enabled.Set(TRUE);
					IF (number IN outOfDate) THEN
						editor.fillColor.Set(LONGINT(0FFFF0099H));
					ELSE
						editor.fillColor.Set(WMGraphics.White);
					END;
				ELSE
					editor.enabled.Set(FALSE);
					editor.fillColor.Set(0CCCCCCCCH);
				END;
			END UpdateState;

		BEGIN
			UpdateState(editLeft, 0);
			UpdateState(editTop, 1);
			UpdateState(editRight, 2);
			UpdateState(editBottom, 3);
			IF (editWidth # NIL) THEN UpdateState(editWidth, 4); END;
			IF (editHeight # NIL) THEN UpdateState(editHeight, 5); END;
		END UpdateEditorStates;

		PROCEDURE Apply(force : BOOLEAN);
		VAR rectangle : WMProperties.RectangleProperty; rect, r : WMRectangles.Rectangle; string : ARRAY 32 OF CHAR;
			width, height: LONGINT;
		BEGIN
			rectangle := SELF.rectangle;
			IF (rectangle # NIL) THEN
				editLeft.GetAsString(string); Strings.StrToInt(string, rect.l);
				editTop.GetAsString(string); Strings.StrToInt(string, rect.t);
				editRight.GetAsString(string); Strings.StrToInt(string, rect.r);
				editBottom.GetAsString(string); Strings.StrToInt(string, rect.b);
				IF editWidth # NIL THEN editWidth.GetAsString(string); Strings.StrToInt(string, width) ELSE width := rect.r-rect.l END;
				IF editHeight # NIL THEN editHeight.GetAsString(string); Strings.StrToInt(string, height) ELSE height := rect.t- rect.b END;
				IF 5 IN outOfDate THEN rect.t := rect.b - height END;
				IF 4 IN outOfDate THEN rect.r := rect.l + width END;
				r := rectangle.Get();
				IF force OR ~WMRectangles.IsEqual(r, rect) THEN
					rectangle.Set(rect);
				ELSE
					SetOutOfDate({});
				END;
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR rectangle : WMProperties.RectangleProperty; rect : WMRectangles.Rectangle; string : ARRAY 32 OF CHAR;
		BEGIN
			Synchronize^(force);
			rectangle := SELF.rectangle;
			IF (rectangle # NIL) & (force OR (lastTimestamp # rectangle.GetTimestamp())) THEN
				lastTimestamp := rectangle.GetTimestamp();
				rect := rectangle.Get();
				Strings.IntToStr(rect.l, string); editLeft.SetAsString(string);
				Strings.IntToStr(rect.t, string); editTop.SetAsString(string);
				Strings.IntToStr(rect.r, string); editRight.SetAsString(string);
				Strings.IntToStr(rect.b, string); editBottom.SetAsString(string);
				IF (editWidth # NIL) & (editHeight # NIL) THEN
					Strings.IntToStr(rect.r - rect.l, string); editWidth.SetAsString(string);
					Strings.IntToStr(rect.b - rect.t, string); editHeight.SetAsString(string);
				END;
				SetOutOfDate({});
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL) & (property IS WMProperties.RectangleProperty);
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			UpdateEditorStates;
		END Enable;

		PROCEDURE Disable;
		BEGIN
			editLeft.enabled.Set(FALSE); editTop.enabled.Set(FALSE); editRight.enabled.Set(FALSE); editBottom.enabled.Set(FALSE);
			IF (editWidth # NIL) THEN editWidth.enabled.Set(FALSE); END;
			IF (editHeight # NIL) THEN editHeight.enabled.Set(FALSE); END;
		END Disable;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.RectangleProperty)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.rectangle := property (WMProperties.RectangleProperty);
			ELSE
				SELF.rectangle := NIL;
				editLeft.SetAsString(""); editTop.SetAsString(""); editRight.SetAsString(""); editBottom.SetAsString("");
				IF (editWidth # NIL) & (editHeight # NIL) THEN editWidth.SetAsString(""); editHeight.SetAsString(""); END;
			END;
		END SetProperty;

		PROCEDURE SetEnabled(value : SET);
		BEGIN
			IF (value # enabled) THEN
				enabled := value;
				UpdateEditorStates;
			END;
		END SetEnabled;

		PROCEDURE SetOutOfDate(value : SET);
		BEGIN
			IF (outOfDate # value) THEN
				outOfDate := value;
				UpdateEditorStates;
			END;
		END SetOutOfDate;

		PROCEDURE EditorContentChanged(sender, data : ANY);
		VAR s : SET;
		BEGIN
			s := outOfDate;
			IF (sender = editLeft) THEN INCL(s, 0);
			ELSIF (sender = editTop) THEN INCL(s, 1);
			ELSIF (sender = editRight) THEN INCL(s, 2);
			ELSIF (sender = editBottom) THEN INCL(s, 3);
			ELSIF (sender = editWidth) THEN INCL(s, 4);
			ELSIF (sender = editHeight) THEN INCL(s, 5);
			END;
			SetOutOfDate(s);
		END EditorContentChanged;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END EnterPressed;

		PROCEDURE CreateEditor(CONST caption : ARRAY OF CHAR; VAR editor : WMEditors.TextField; leftBearing : LONGINT);
		VAR label : WMStandardComponents.Label;
		BEGIN
			NEW(label); label.alignment.Set(WMComponents.AlignLeft);
			label.bounds.SetWidth(50);
			label.alignH.Set(WMGraphics.AlignCenter);
			label.caption.SetAOC(caption);
			IF (leftBearing # 0) THEN
				label.bearing.Set(WMRectangles.MakeRect(leftBearing, 0, 0, 0));
			END;
			AddContent(label);

			NEW(editor); editor.alignment.Set(WMComponents.AlignLeft);
			editor.bounds.SetWidth(40);
			editor.onEnter.Add(EnterPressed);
			editor.onChanged.Add(EditorContentChanged);
			editor.type.Set(WMEditors.Decimal);
			AddContent(editor);
		END CreateEditor;

	END RectanglePropertyView;

TYPE
	PointPropertyView = OBJECT(PropertyView)
	VAR
		point : WMProperties.PointProperty;
		editX, editY : WMEditors.TextField;
		enabled, outOfDate : SET;

		PROCEDURE &New(wh : BOOLEAN);
		BEGIN
			Init;
			SetNameAsString(StrPointPropertyView);
			ofsInfo := -1;
			CreateEditor("X:", editX, 0);
			CreateEditor("Y:", editY, 0);
			enabled := {0..5};
			outOfDate := {};
		END New;

		PROCEDURE UpdateEditorStates;

			PROCEDURE UpdateState(editor : WMEditors.TextField; number: LONGINT);
			BEGIN
				IF (number IN enabled) THEN
					editor.enabled.Set(TRUE);
					IF (number IN outOfDate) THEN
						editor.fillColor.Set(LONGINT(0FFFF0099H));
					ELSE
						editor.fillColor.Set(WMGraphics.White);
					END;
				ELSE
					editor.enabled.Set(FALSE);
					editor.fillColor.Set(0CCCCCCCCH);
				END;
			END UpdateState;

		BEGIN
			UpdateState(editX, 0);
			UpdateState(editY, 1);
		END UpdateEditorStates;

		PROCEDURE Apply(force : BOOLEAN);
		VAR point : WMProperties.PointProperty; pnt, p : WMGraphics.Point2d; string : ARRAY 32 OF CHAR;
		BEGIN
			point := SELF.point;
			IF (point # NIL) THEN
				editX.GetAsString(string); Strings.StrToInt(string, pnt.x);
				editY.GetAsString(string); Strings.StrToInt(string, pnt.y);
				p := point.Get();
				IF force OR (p.x#pnt.x) OR (p.y#pnt.y)  THEN
					point.Set(pnt);
				ELSE
					SetOutOfDate({});
				END;
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR point : WMProperties.PointProperty; pnt : WMGraphics.Point2d; string : ARRAY 32 OF CHAR;
		BEGIN
			Synchronize^(force);
			point := SELF.point;
			IF (point # NIL) & (force OR (lastTimestamp # point.GetTimestamp())) THEN
				lastTimestamp := point.GetTimestamp();
				pnt := point.Get();
				Strings.IntToStr(pnt.x, string); editX.SetAsString(string);
				Strings.IntToStr(pnt.y, string); editY.SetAsString(string);
				SetOutOfDate({});
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL) & (property IS WMProperties.PointProperty);
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			UpdateEditorStates;
		END Enable;

		PROCEDURE Disable;
		BEGIN
			editX.enabled.Set(FALSE); editY.enabled.Set(FALSE);
		END Disable;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.PointProperty)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.point := property (WMProperties.PointProperty);
			ELSE
				SELF.point := NIL;
				editX.SetAsString(""); editY.SetAsString("");
			END;
		END SetProperty;

		PROCEDURE SetEnabled(value : SET);
		BEGIN
			IF (value # enabled) THEN
				enabled := value;
				UpdateEditorStates;
			END;
		END SetEnabled;

		PROCEDURE SetOutOfDate(value : SET);
		BEGIN
			IF (outOfDate # value) THEN
				outOfDate := value;
				UpdateEditorStates;
			END;
		END SetOutOfDate;

		PROCEDURE EditorContentChanged(sender, data : ANY);
		VAR s : SET;
		BEGIN
			s := outOfDate;
			IF (sender = editX) THEN INCL(s, 0);
			ELSIF (sender = editY) THEN INCL(s, 1);
			END;
			SetOutOfDate(s);
		END EditorContentChanged;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END EnterPressed;

		PROCEDURE CreateEditor(CONST caption : ARRAY OF CHAR; VAR editor : WMEditors.TextField; leftBearing : LONGINT);
		VAR label : WMStandardComponents.Label;
		BEGIN
			NEW(label); label.alignment.Set(WMComponents.AlignLeft);
			label.bounds.SetWidth(50);
			label.alignH.Set(WMGraphics.AlignCenter);
			label.caption.SetAOC(caption);
			IF (leftBearing # 0) THEN
				label.bearing.Set(WMRectangles.MakeRect(leftBearing, 0, 0, 0));
			END;
			AddContent(label);

			NEW(editor); editor.alignment.Set(WMComponents.AlignLeft);
			editor.bounds.SetWidth(40);
			editor.onEnter.Add(EnterPressed);
			editor.onChanged.Add(EditorContentChanged);
			editor.type.Set(WMEditors.Decimal);
			AddContent(editor);
		END CreateEditor;

	END PointPropertyView;


TYPE

	StringPropertyView = OBJECT(PropertyView)
	VAR
		string : WMProperties.StringProperty;
		editor : WMEditors.TextField;
		outOfDate : BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrStringPropertyView);
			ofsInfo := -1;
			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.onChanged.Add(EditorContentChanged);
			editor.onEnter.Add(EnterPressed);
			AddContent(editor);
			outOfDate := FALSE;
		END Init;

		PROCEDURE Apply(force : BOOLEAN);
		VAR string : WMProperties.StringProperty; value, oldValue : ARRAY 1024 OF CHAR;
		BEGIN
			string := SELF.string;
			IF (string # NIL) THEN
				editor.GetAsString(value);
				string.GetAOC(oldValue);
				IF force OR (value # oldValue) THEN
					string.SetAOC(value);
				ELSE
					SetOutOfDate(FALSE);
				END;
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR string : WMProperties.StringProperty; value : Strings.String;
		BEGIN
			Synchronize^(force);
			string := SELF.string;
			IF (string # NIL) & (force OR (lastTimestamp # string.GetTimestamp())) THEN
				lastTimestamp := string.GetTimestamp();
				value := string.Get();
				IF (value # NIL) THEN editor.SetAsString(value^); ELSE editor.SetAsString(""); END;
				SetOutOfDate(FALSE);
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL) & (property IS WMProperties.StringProperty);
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			editor.enabled.Set(TRUE);
		END Enable;

		PROCEDURE Disable;
		BEGIN
			editor.enabled.Set(FALSE);
		END Disable;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.StringProperty)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.string := property (WMProperties.StringProperty);
			ELSE
				SELF.string := NIL;
				editor.SetAsString("");
			END;
		END SetProperty;

		PROCEDURE SetOutOfDate(value : BOOLEAN);
		BEGIN
			IF (outOfDate # value) THEN
				outOfDate := value;
				IF outOfDate THEN
					editor.fillColor.Set(LONGINT(0FFFF0099H));
				ELSE
					editor.fillColor.Set(WMGraphics.White);
				END;
			END;
		END SetOutOfDate;

		PROCEDURE EditorContentChanged(sender, data : ANY);
		BEGIN
			SetOutOfDate(TRUE);
		END EditorContentChanged;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END EnterPressed;

	END StringPropertyView;

TYPE

	ColorPropertyView = OBJECT(PropertyView)
	VAR
		color : WMProperties.ColorProperty;
		editor : WMEditors.TextField;
		colorPot : WMColorComponents.ColorPot;
		res : LONGINT;
		outOfDate : BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrColorPropertyView);
			outOfDate := FALSE;

			NEW(colorPot); colorPot.alignment.Set(WMComponents.AlignLeft);
			colorPot.bounds.SetWidth(20);
			colorPot.SetExternalColorChangeHandler(ColorDropped);
			AddContent(colorPot);

			NEW(editor); editor.alignment.Set(WMComponents.AlignLeft);
			editor.type.Set(WMEditors.Hex);
			editor.bounds.SetWidth(70);
			editor.onEnter.Add(EnterPressed);
			editor.onChanged.Add(EditorContentChanged);
			AddContent(editor);
		END Init;

		PROCEDURE Apply(force : BOOLEAN);
		VAR color : WMProperties.ColorProperty; string : ARRAY 16 OF CHAR; value : LONGINT;
		BEGIN
			color := SELF.color;
			IF (color # NIL) THEN
				editor.GetAsString(string);
				Strings.HexStrToInt(string, value, res);
				IF force OR (value # color.Get()) THEN
					color.Set(value);
					colorPot.fillColor.Set(value);
				ELSE
					SetOutOfDate(FALSE);
				END;
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR color : WMProperties.ColorProperty;  string : ARRAY 16 OF CHAR; value : LONGINT;
		BEGIN
			Synchronize^(force);
			color := SELF.color;
			IF (color # NIL) & (force OR (lastTimestamp # color.GetTimestamp())) THEN
				lastTimestamp := color.GetTimestamp();
				value := color.Get();
				Strings.IntToHexStr(value, 8, string);
				editor.SetAsString(string);
				colorPot.fillColor.Set(value);
				SetOutOfDate(FALSE);
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL) & (property IS WMProperties.ColorProperty);
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			editor.enabled.Set(TRUE); colorPot.enabled.Set(TRUE);
		END Enable;

		PROCEDURE Disable;
		BEGIN
			editor.enabled.Set(FALSE); colorPot.enabled.Set(FALSE);
		END Disable;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.ColorProperty)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.color := property (WMProperties.ColorProperty);
			ELSE
				SELF.color := NIL;
				editor.SetAsString("");
				colorPot.fillColor.Set(0);
			END;
		END SetProperty;

		PROCEDURE SetOutOfDate(value : BOOLEAN);
		BEGIN
			IF (outOfDate # value) THEN
				outOfDate := value;
				IF outOfDate THEN
					editor.fillColor.Set(LONGINT(0FFFF0099H));
				ELSE
					editor.fillColor.Set(WMGraphics.White);
				END;
			END;
		END SetOutOfDate;

		PROCEDURE EditorContentChanged(sender, data : ANY);
		BEGIN
			SetOutOfDate(TRUE);
		END EditorContentChanged;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END EnterPressed;

		PROCEDURE ColorDropped(sender, data : ANY);
		VAR color : WMProperties.ColorProperty;
		BEGIN
			color := SELF.color;
			IF (color # NIL) & (data # NIL) & (data IS WMColorComponents.Color) THEN
				color.Set(data(WMColorComponents.Color).value);
			END;
		END ColorDropped;

	END ColorPropertyView;

TYPE

	FontPropertyView = OBJECT(PropertyView)
	VAR
		font : WMProperties.FontProperty;
		editName, editSize, editStyle : WMEditors.TextField;

		outOfDate : SET;

		PROCEDURE &New;
		BEGIN
			Init;
			SetNameAsString(StrFontPropertyView);
			ofsInfo := -1;
			NEW(editName); editName.alignment.Set(WMComponents.AlignLeft);
			editName.bounds.SetWidth(80);
			editName.onEnter.Add(EnterPressed);
			editName.onChanged.Add(EditorContentChanged);
			editName.type.Set(WMEditors.Unicode);
			AddContent(editName);
			CreateEditor("Size:", editSize, 0);
			CreateEditor("Style: ", editStyle, 0);
			editStyle.SetAsString("{}");
			outOfDate := {};
		END New;

		PROCEDURE UpdateEditorStates;

			PROCEDURE UpdateState(editor : WMEditors.TextField; number: LONGINT);
			BEGIN
				IF (number IN outOfDate) THEN
					editor.fillColor.Set(LONGINT(0FFFF0099H));
				ELSE
					editor.fillColor.Set(WMGraphics.White);
				END;
			END UpdateState;

		BEGIN
			UpdateState(editName, 0);
			UpdateState(editSize, 1);
			UpdateState(editStyle, 2);
		END UpdateEditorStates;

		PROCEDURE Apply(force : BOOLEAN);
		VAR font : WMProperties.FontProperty; f : WMGraphics.Font; temp, name : ARRAY 32 OF CHAR; size : LONGINT; style : SET;
		BEGIN
			font := SELF.font;
			IF (font # NIL) THEN
				editName.GetAsString(name);
				editSize.GetAsString(temp); Strings.StrToInt(temp, size);
				editStyle.GetAsString(temp); Strings.StrToSet(temp, style);
				f := WMGraphics.GetFont(name, size, style);
				IF (f = NIL) THEN f := WMGraphics.GetDefaultFont(); END;
				IF force OR ~(f = font.Get()) THEN
					font.Set(f);
				ELSE
					SetOutOfDate({});
				END;
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR font : WMProperties.FontProperty; name, temp : ARRAY 32 OF CHAR; size : LONGINT; style : SET;
		BEGIN
			Synchronize^(force);
			font := SELF.font;
			IF (font # NIL) & (force OR (lastTimestamp # font.GetTimestamp())) THEN
				lastTimestamp := font.GetTimestamp();
				font.GetFont(name, size, style);
				editName.SetAsString(name);
				Strings.IntToStr(size, temp); editSize.SetAsString(temp);
				Strings.SetToStr(style, temp); editStyle.SetAsString(temp);
				SetOutOfDate({});
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL) & (property IS WMProperties.FontProperty);
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			editName.enabled.Set(TRUE); editSize.enabled.Set(TRUE); editStyle.enabled.Set(TRUE);
		END Enable;

		PROCEDURE Disable;
		BEGIN
			editName.enabled.Set(FALSE); editSize.enabled.Set(FALSE); editStyle.enabled.Set(FALSE);
		END Disable;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.FontProperty)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.font := property (WMProperties.FontProperty);
			ELSE
				SELF.font := NIL;
				editName.SetAsString(""); editSize.SetAsString(""); editStyle.SetAsString("{}");
			END;
		END SetProperty;

		PROCEDURE SetOutOfDate(value : SET);
		BEGIN
			IF (outOfDate # value) THEN
				outOfDate := value;
				UpdateEditorStates;
			END;
		END SetOutOfDate;

		PROCEDURE EditorContentChanged(sender, data : ANY);
		VAR s : SET;
		BEGIN
			s := outOfDate;
			IF (sender = editName) THEN INCL(s, 0);
			ELSIF (sender = editSize) THEN INCL(s, 1);
			ELSIF (sender = editStyle) THEN INCL(s, 2);
			END;
			SetOutOfDate(s);
		END EditorContentChanged;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END EnterPressed;

		PROCEDURE CreateEditor(CONST caption : ARRAY OF CHAR; VAR editor : WMEditors.TextField; leftBearing : LONGINT);
		VAR label : WMStandardComponents.Label;
		BEGIN
			NEW(label); label.alignment.Set(WMComponents.AlignLeft);
			label.bounds.SetWidth(50);
			label.alignH.Set(WMGraphics.AlignCenter);
			label.caption.SetAOC(caption);
			IF (leftBearing # 0) THEN
				label.bearing.Set(WMRectangles.MakeRect(leftBearing, 0, 0, 0));
			END;
			AddContent(label);

			NEW(editor); editor.alignment.Set(WMComponents.AlignLeft);
			editor.bounds.SetWidth(40);
			editor.onEnter.Add(EnterPressed);
			editor.onChanged.Add(EditorContentChanged);
			editor.type.Set(WMEditors.Ascii);
			AddContent(editor);
		END CreateEditor;

	END FontPropertyView;

TYPE

	ReferencePropertyView = OBJECT(PropertyView)
	VAR
		reference : WMProperties.ReferenceProperty;
		object : XML.Element;
		editor : WMEditors.TextField;
		button : WMStandardComponents.Button;
		outOfDate : BOOLEAN;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrReferencePropertyView);
			ofsInfo := -1;
			reference := NIL;
			object := NIL;

			(*
			NEW(adrLabel); adrLabel.alignment.Set(WMComponents.AlignLeft);
			adrLabel.bounds.SetWidth(60);
			adrLabel.fillColor.Set(0CCCCCCCH);
			AddContent(adrLabel);
			adrLabel.onStartDrag.Add(MyStartDrag);
			adrLabel.SetExtPointerMoveHandler(AdrLabelMove);
			adrLabel.SetExtDragDroppedHandler(MyDragDropped);
			*)
			NEW(button); button.alignment.Set(WMComponents.AlignRight);
			button.bounds.SetWidth(60);
			button.fillColor.Set(WMGraphics.Red);
			button.enabled.Set(FALSE);
			button.onClick.Add(HandleButton);
			AddContent(button);
			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.type.Set(WMEditors.Ascii);
			editor.onEnter.Add(EnterPressed);
			editor.onChanged.Add(EditorContentChanged);
			AddContent(editor);
			outOfDate := FALSE;
		END Init;

		PROCEDURE AdrLabelMove(x, y : LONGINT; keys : SET; VAR handled : BOOLEAN);
		VAR dx, dy, dp, d : LONGINT; f : REAL; tmax, tmin : LONGINT;
		BEGIN
			IF keys = {0} THEN adrLabel.AutoStartDrag END;
		END AdrLabelMove;

		PROCEDURE MyStartDrag(sender, data: ANY);
		VAR w,h: LONGINT; img: WMGraphics.Image; canvas: WMGraphics.BufferCanvas;
		BEGIN
			NEW(img);
			adrLabel.bounds.GetExtents(w,h);
			Raster.Create(img, w,h, Raster.BGRA8888);
			NEW(canvas,img);
			adrLabel.Draw(canvas);
			IF StartDrag(reference.Get(),img,0,0,NIL,NIL) THEN END;
		END MyStartDrag;

		PROCEDURE HandleButton(sender, data : ANY);
		VAR object : XML.Element; modelView : ModelView; window : Window; propertyPanel: PropertyPanel;
		BEGIN
			object := SELF.object;
			IF (object # NIL) & (object IS Models.Model) THEN
				NEW(modelView); modelView.SetModel(object(Models.Model));
				modelView.bounds.SetExtents(ModelWindowWidth, ModelWindowHeight);
				modelView.fillColor.Set(WMGraphics.White);
				NEW(window, modelView);
			END;
			IF (object # NIL) & (object IS WMComponents.Component) THEN
				NEW(propertyPanel);
				propertyPanel.bounds.SetExtents(300,300);
				propertyPanel.fillColor.Set(WMGraphics.Yellow);
				NEW(window, propertyPanel);
				propertyPanel.SetComponent(SELF,object);
			END;
		END HandleButton;

		PROCEDURE Apply(force : BOOLEAN);
		VAR reference : WMProperties.ReferenceProperty; string, oldString : ARRAY 256 OF CHAR; stringType: Types.String256; res: LONGINT;
		BEGIN
			reference := SELF.reference;
			IF (reference # NIL) THEN
				editor.GetAsString(string);
				object := reference.Get();
				IF object # NIL THEN
					IF (object IS Models.Model) THEN
						COPY(string, stringType.value);
						object(Models.Model).SetGeneric(stringType, res);
						SetOutOfDate(FALSE);
					END;
				ELSE
					reference.GetAsString(oldString);
					IF force OR (string # oldString) THEN
						reference.SetAsString(string);
						object := reference.Get();
						UpdateButton(object);
					ELSE
						SetOutOfDate(FALSE);
					END;
				END
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR reference : WMProperties.ReferenceProperty;string : ARRAY 256 OF CHAR; stringType: Types.String256; res: LONGINT;
		BEGIN
			reference := SELF.reference;
			IF (reference # NIL) & (force OR (lastTimestamp # reference.GetTimestamp())) THEN
				lastTimestamp := reference.GetTimestamp();
				reference.GetAsString(string);
				object := reference.Get();
				UpdateButton(object);
				UpdateAdrLabel(object);
				IF (object # NIL) & (object IS Models.Model) THEN
					object(Models.Model).GetGeneric(stringType,res);
					IF res = Models.Ok THEN COPY(stringType.value, string) END;
				END;
				editor.SetAsString(string);
				SetOutOfDate(FALSE);
			END;
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL) & (property IS WMProperties.ReferenceProperty);
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			editor.enabled.Set(TRUE);
		END Enable;

		PROCEDURE Disable;
		BEGIN
			editor.enabled.Set(FALSE);
		END Disable;

		PROCEDURE UpdateButton(object : XML.Element);
		VAR string : Types.String32; res : LONGINT; nbrStr : ARRAY 17 OF CHAR; t: Modules.TypeDesc;
		BEGIN
			IF (object # NIL) THEN
				button.fillColor.Set(WMGraphics.Green);
				IF (object IS Models.Model) THEN
					button.enabled.Set(TRUE);
					object(Models.Model).GetGeneric(string, res);
					IF (res = Models.Ok) THEN
						button.caption.SetAOC(string.value);
					ELSE
						button.caption.Set(StrNoCaption);
					END;
				ELSIF (object IS WMComponents.Component) THEN
					button.enabled.Set(TRUE);
					button.caption.SetAOC("(component)");
				ELSE
					button.enabled.Set(FALSE);
					button.caption.Set(StrNoCaption);
				END;
			ELSE
				button.enabled.Set(FALSE);
				button.fillColor.Set(WMGraphics.Red);
				button.caption.Set(StrNoCaption);
			END;
		END UpdateButton;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.ReferenceProperty)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.reference := property (WMProperties.ReferenceProperty);
				SELF.object := NIL;
			ELSE
				SELF.reference := NIL;
				SELF.object := NIL;
				editor.SetAsString("");
			END;
			UpdateButton(SELF.object);
			UpdateAdrLabel(SELF.object);
		END SetProperty;

		PROCEDURE SetOutOfDate(value : BOOLEAN);
		BEGIN
			IF (outOfDate # value) THEN
				outOfDate := value;
				IF outOfDate THEN
					editor.fillColor.Set(LONGINT(0FFFF0099H));
				ELSE
					editor.fillColor.Set(WMGraphics.White);
				END;
			END;
		END SetOutOfDate;

		PROCEDURE EditorContentChanged(sender, data : ANY);
		BEGIN
			SetOutOfDate(TRUE);
		END EditorContentChanged;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END EnterPressed;

	END ReferencePropertyView;

TYPE

	AlignmentPropertyView = OBJECT(PropertyView)
	VAR
		int32 : WMProperties.Int32Property;
		alignment_chooser : WMDropDownLists.DropDownList;

		PROCEDURE &Init;
		VAR res : LONGINT;
		BEGIN
			Init^;
			SetNameAsString(StrAlignmentPropertyView);
			ofsInfo := -1;
			NEW(alignment_chooser);
			alignment_chooser.alignment.Set(WMComponents.AlignLeft);
			alignment_chooser.maxGridHeight.Set(200);
			alignment_chooser.bounds.SetWidth(100);
			alignment_chooser.mode.Set(WMDropDownLists.Mode_SelectOnly);
			alignment_chooser.model.Acquire;
			alignment_chooser.model.Add(WMComponents.AlignNone, "None", res); ASSERT(res = WMDropDownLists.Ok);
			alignment_chooser.model.Add(WMComponents.AlignLeft, "Left", res); ASSERT(res = WMDropDownLists.Ok);
			alignment_chooser.model.Add(WMComponents.AlignTop, "Top", res); ASSERT(res = WMDropDownLists.Ok);
			alignment_chooser.model.Add(WMComponents.AlignRight, "Right", res); ASSERT(res = WMDropDownLists.Ok);
			alignment_chooser.model.Add(WMComponents.AlignBottom, "Bottom", res); ASSERT(res = WMDropDownLists.Ok);
			alignment_chooser.model.Add(WMComponents.AlignClient, "Client", res); ASSERT(res = WMDropDownLists.Ok);
			alignment_chooser.model.Add(WMComponents.AlignRelative, "Relative", res); ASSERT(res = WMDropDownLists.Ok);
			alignment_chooser.model.Release;
			alignment_chooser.onSelect.Add(AlignmentSelected);
			AddContent(alignment_chooser);
		END Init;

		PROCEDURE Apply(force : BOOLEAN);
		VAR int32 : WMProperties.Int32Property; e : WMDropDownLists.Entry;
		BEGIN
			int32 := SELF.int32;
			IF (int32 # NIL) THEN
				e := alignment_chooser.GetSelection();
				IF (e # NIL) & (force OR (e.key # int32.Get())) THEN
					int32.Set(e.key);
				END;
			END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		VAR int32 : WMProperties.Int32Property;
		BEGIN
			Synchronize^(force);
			int32 := SELF.int32;
			IF (int32 # NIL) & (force OR (lastTimestamp # int32.GetTimestamp())) THEN
				lastTimestamp := int32.GetTimestamp();
				alignment_chooser.SelectKey(int32.Get());
			END;
		END Synchronize;

		PROCEDURE SetProperty(property : WMProperties.Property);
		BEGIN
			ASSERT((property = NIL) OR ((property # NIL) & (property IS WMProperties.Int32Property)));
			SetProperty^(property);
			IF (property # NIL) THEN
				SELF.int32 := property (WMProperties.Int32Property);
			ELSE
				SELF.int32 := NIL;
				alignment_chooser.SetSelection(NIL);
			END;
		END SetProperty;

		PROCEDURE AlignmentSelected(sender, data : ANY);
		BEGIN
			Apply(FALSE);
		END AlignmentSelected;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN FALSE; (* only to be used by VisualComponentView *)
		END IsCompatible;

		PROCEDURE Enable;
		BEGIN
			alignment_chooser.enabled.Set(TRUE);
		END Enable;

		PROCEDURE Disable;
		BEGIN
			alignment_chooser.enabled.Set(FALSE);
		END Disable;

	END AlignmentPropertyView;

TYPE

	UnknownPropertyView = OBJECT(PropertyView)

		PROCEDURE Apply(force : BOOLEAN);
		BEGIN
			(* do nothing *)
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		BEGIN
			(* do nothing *)
		END Synchronize;

		PROCEDURE IsCompatible(property : WMProperties.Property) : BOOLEAN;
		BEGIN
			RETURN (property # NIL);
		END IsCompatible;

		PROCEDURE &Init;
		VAR label : WMStandardComponents.Label;
		BEGIN
			Init^;
			SetNameAsString(StrUnknownPropertyView);
			NEW(label); label.alignment.Set(WMComponents.AlignLeft);
			label.bounds.SetWidth(70);
			label.fillColor.Set(WMGraphics.Red);
			label.caption.SetAOC("Unknown");
			label.alignH.Set(WMGraphics.AlignCenter);
			label.bearing.Set(WMRectangles.MakeRect(NameWidth, 0, 0, 0));
			AddContent(label);
		END Init;

	END UnknownPropertyView;

TYPE

	EventSourceView = OBJECT(WMComponents.VisualComponent)
	VAR
		event : WMEvents.EventSource;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrEventSourceView);
			alignment.Set(WMComponents.AlignTop);
			bounds.SetHeight(LineHeight);
			fillColor.Set(WMGraphics.White);
		END Init;

		PROCEDURE Apply;
		BEGIN
			KernelLog.String("Not Implemented"); KernelLog.Ln;
		END Apply;

		PROCEDURE Refresh;
		BEGIN
			KernelLog.String("Not Implemented"); KernelLog.Ln;
		END Refresh;

		PROCEDURE SetEventSource(event : WMEvents.EventSource);
		VAR
			nameLabel, infoLabel : WMStandardComponents.Label;
		BEGIN
			ASSERT(event # NIL);
			SELF.event := event;
			NEW(nameLabel); nameLabel.alignment.Set(WMComponents.AlignLeft);
			nameLabel.bounds.SetWidth(80);
			nameLabel.textColor.Set(WMGraphics.Black);
			nameLabel.caption.Set(event.GetName());
			AddContent(nameLabel);

			NEW(infoLabel); infoLabel.alignment.Set(WMComponents.AlignClient);
			infoLabel.textColor.Set(WMGraphics.Black);
			infoLabel.caption.Set(event.GetInfo());
			AddContent(infoLabel);
		END SetEventSource;

	END EventSourceView;

TYPE

	EventListenerView = OBJECT(WMComponents.VisualComponent)
	VAR
		event : WMEvents.EventListenerInfo;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrEventListenerView);
			alignment.Set(WMComponents.AlignTop);
			bounds.SetHeight(LineHeight);
		END Init;

		PROCEDURE Apply;
		BEGIN
			KernelLog.String("Not Implemented"); KernelLog.Ln;
		END Apply;

		PROCEDURE Refresh;
		BEGIN
			KernelLog.String("Not Implemented"); KernelLog.Ln;
		END Refresh;

		PROCEDURE SetEventListener(event : WMEvents.EventListenerInfo);
		VAR
			nameLabel, infoLabel : WMStandardComponents.Label;
		BEGIN
			ASSERT(event # NIL);
			SELF.event := event;
			NEW(nameLabel); nameLabel.alignment.Set(WMComponents.AlignClient);
			nameLabel.textColor.Set(WMGraphics.Black);
			nameLabel.caption.Set(event.GetName());
			AddContent(nameLabel);

			NEW(infoLabel); infoLabel.alignment.Set(WMComponents.AlignLeft);
			infoLabel.bounds.SetWidth(200);
			infoLabel.textColor.Set(WMGraphics.Black);
			infoLabel.caption.Set(event.GetInfo());
			AddContent(infoLabel);
		END SetEventListener;

	END EventListenerView;

TYPE

	ComponentView = OBJECT(WMComponents.VisualComponent)
	VAR
		initializedView: BooleanPropertyView;
		idView, uidView : StringPropertyView;
		enabledView : BooleanPropertyView;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("ComponentView"));
			NEW(initializedView); AddContent(initializedView);
			NEW(idView); AddContent(idView);
			NEW(uidView); AddContent(uidView);
			NEW(enabledView); AddContent(enabledView);

			bounds.SetHeight(initializedView.bounds.GetHeight() + idView.bounds.GetHeight() + uidView.bounds.GetHeight() + enabledView.bounds.GetHeight() + 6 * LineBearing);
		END Init;

		PROCEDURE ResetProperties;
		BEGIN
			initializedView.SetProperty(NIL);
			idView.SetProperty(NIL);
			uidView.SetProperty(NIL);
			enabledView.SetProperty(NIL);
		END ResetProperties;

		PROCEDURE SetProperty(property : WMProperties.Property; VAR res : LONGINT);
		VAR name : Strings.String;
		BEGIN
			res := Ok;
			name := property.GetName();
			IF (name # NIL) THEN
				IF (name^ = "Initialized") & (property IS WMProperties.BooleanProperty) THEN
					initializedView.SetProperty(property);
				ELSIF (name^ = "ID") & (property IS WMProperties.StringProperty) THEN
					idView.SetProperty(property);
				ELSIF (name^ = "UID") & (property IS WMProperties.StringProperty) THEN
					uidView.SetProperty(property);
				ELSIF (name^ = "Enabled") & (property IS WMProperties.BooleanProperty) THEN
					enabledView.SetProperty(property);
				ELSE
					res := CannotHandle;
				END;
			ELSE
				res := CannotHandle;
			END;
		END SetProperty;

		PROCEDURE Apply;
		BEGIN
			initializedView.Apply(FALSE); (*not editable*)
			idView.Apply(FALSE);
			uidView.Apply(FALSE);
			enabledView.Apply(FALSE);
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		BEGIN
			initializedView.Synchronize(force);
			idView.Synchronize(force);
			uidView.Synchronize(force);
			enabledView.Synchronize(force);
		END Synchronize;

		PROCEDURE Enable;
		BEGIN
			(*initializedView.Enable;*)
			idView.Enable;
			uidView.Enable;
			enabledView.Enable;
		END Enable;

		PROCEDURE Disable;
		BEGIN
			(*initializedView.Disable;*)
			idView.Disable;
			uidView.Disable;
			enabledView.Disable;
		END Disable;

	END ComponentView;

TYPE

	VisualComponentView = OBJECT(WMComponents.VisualComponent)
	VAR
		alignmentView : AlignmentPropertyView;
		boundsView : RectanglePropertyView;
		bearingView : RectanglePropertyView;

		fillColorView : ColorPropertyView;
		visibleView, takesFocusView, needsTabView, editModeView : BooleanPropertyView;

		focusNextView, focusPrevView : StringPropertyView;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("VisualComponentView"));
			NEW(alignmentView); AddContent(alignmentView);
			NEW(boundsView, TRUE); AddContent(boundsView);
			NEW(bearingView, FALSE); AddContent(bearingView);
			NEW(fillColorView); AddContent(fillColorView);
			NEW(visibleView); AddContent(visibleView);
			NEW(editModeView); AddContent(editModeView);
			NEW(needsTabView); AddContent(needsTabView);
			NEW(takesFocusView); AddContent(takesFocusView);
			NEW(focusPrevView); AddContent(focusPrevView);
			NEW(focusNextView); AddContent(focusNextView);


			bounds.SetHeight(18 * LineBearing +
				alignmentView.bounds.GetHeight() +
				boundsView.bounds.GetHeight() + bearingView.bounds.GetHeight() +
				fillColorView.bounds.GetHeight() + visibleView.bounds.GetHeight() +
				takesFocusView.bounds.GetHeight() + needsTabView.bounds.GetHeight() +
				focusPrevView.bounds.GetHeight() + focusNextView.bounds.GetHeight() + editModeView.bounds.GetHeight()
			);
		END Init;

		PROCEDURE Initialize;
		BEGIN
			Initialize^;
			ResetProperties;
		END Initialize;

		PROCEDURE ResetProperties;
		BEGIN
			alignmentView.SetProperty(NIL);
			boundsView.SetProperty(NIL);
			bearingView.SetProperty(NIL);
			fillColorView.SetProperty(NIL);
			visibleView.SetProperty(NIL);
			takesFocusView.SetProperty(NIL);
			needsTabView.SetProperty(NIL);
			focusPrevView.SetProperty(NIL);
			focusNextView.SetProperty(NIL);
			editModeView.SetProperty(NIL);
		END ResetProperties;

		PROCEDURE SetAlignment(alignmentMode : LONGINT);
		VAR s : SET;
		BEGIN
			IF (alignmentMode < WMComponents.AlignNone) OR (WMComponents.AlignClient < alignmentMode) THEN
				alignmentMode := WMComponents.AlignNone;
			END;
			CASE alignmentMode OF
				|WMComponents.AlignNone: s := {0..5};
				|WMComponents.AlignLeft: s := {4};
				|WMComponents.AlignRight: s := {4};
				|WMComponents.AlignTop: s := {5};
				|WMComponents.AlignBottom: s := {5};
				|WMComponents.AlignClient: s := {};
				|WMComponents.AlignRelative: s := {}
			ELSE
				HALT(99);
			END;
			boundsView.SetEnabled(s);
		END SetAlignment;

		PROCEDURE SetProperty(property : WMProperties.Property; VAR res : LONGINT);
		VAR name : Strings.String;
		BEGIN
			res := Ok;
			name := property.GetName();
			IF (name # NIL) THEN
				IF (name^ = "Bounds") & (property IS WMProperties.RectangleProperty) THEN
					boundsView.SetProperty(property);
				ELSIF (name^ = "Bearing") & (property IS WMProperties.RectangleProperty) THEN
					bearingView.SetProperty(property);
				ELSIF (name ^ = "Alignment") & (property IS WMProperties.Int32Property) THEN
					alignmentView.SetProperty(property);
				ELSIF (name^ = "FillColor") & (property IS WMProperties.ColorProperty) THEN
					fillColorView.SetProperty(property);
				ELSIF (name^ = "Visible") & (property IS WMProperties.BooleanProperty) THEN
					visibleView.SetProperty(property);
				ELSIF (name^ = "NeedsTab") & (property IS WMProperties.BooleanProperty) THEN
					needsTabView.SetProperty(property);
				ELSIF (name^ = "TakesFocus") & (property IS WMProperties.BooleanProperty) THEN
					takesFocusView.SetProperty(property);
				ELSIF (name^ = "FocusPrevious") & (property IS WMProperties.StringProperty) THEN
					focusPrevView.SetProperty(property);
				ELSIF (name^ = "FocusNext") & (property IS WMProperties.StringProperty) THEN
					focusNextView.SetProperty(property);
				ELSIF (name^ = "EditMode") & (property IS WMProperties.BooleanProperty) THEN
					editModeView.SetProperty(property)
				ELSE
					res := CannotHandle;
				END;
			ELSE
				res := CannotHandle;
			END;
		END SetProperty;

		PROCEDURE Apply;
		BEGIN
			alignmentView.Apply(FALSE);
			IF alignmentView.int32 # NIL THEN SetAlignment(alignmentView.int32.Get()); END;
			boundsView.Apply(FALSE);
			bearingView.Apply(FALSE);
			fillColorView.Apply(FALSE);
			visibleView.Apply(FALSE);
			needsTabView.Apply(FALSE);
			takesFocusView.Apply(FALSE);
			focusPrevView.Apply(FALSE);
			focusNextView.Apply(FALSE);
			editModeView.Apply(FALSE);
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		BEGIN
			alignmentView.Synchronize(force);
			IF (alignmentView.int32 # NIL) THEN SetAlignment(alignmentView.int32.Get()); END;
			boundsView.Synchronize(force);
			bearingView.Synchronize(force);
			fillColorView.Synchronize(force);
			visibleView.Synchronize(force);
			needsTabView.Synchronize(force);
			takesFocusView.Synchronize(force);
			focusPrevView.Synchronize(force);
			focusNextView.Synchronize(force);
			editModeView.Synchronize(force);
		END Synchronize;

		PROCEDURE Enable;
		BEGIN
			alignmentView.Enable;
			IF (alignmentView.int32 # NIL) THEN SetAlignment(alignmentView.int32.Get()); END;
			boundsView.Enable;
			bearingView.Enable;
			fillColorView.Enable;
			visibleView.Enable;
			needsTabView.Enable;
			takesFocusView.Enable;
			focusPrevView.Enable;
			focusNextView.Enable;
			editModeView.Enable;
		END Enable;

		PROCEDURE Disable;
		BEGIN
			alignmentView.Disable;
			boundsView.Disable;
			bearingView.Disable;
			fillColorView.Disable;
			visibleView.Disable;
			needsTabView.Disable;
			takesFocusView.Disable;
			focusPrevView.Disable;
			focusNextView.Disable;
			editModeView.Disable;
		END Disable;

	END VisualComponentView;

TYPE

	ComponentElement* = OBJECT(WMComponents.VisualComponent)
	VAR
		component : WMComponents.Component;
		nofElements : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("ComponentElement"));
			component := NIL;
			nofElements := 0;
		END Init;

		PROCEDURE CountNofElements(component : WMComponents.Component);
		END CountNofElements;

		PROCEDURE GetNofElements*() : LONGINT;
		BEGIN
			RETURN nofElements;
		END GetNofElements;

		PROCEDURE SetComponent*(component : WMComponents.Component);
		BEGIN
			HALT(301);
		END SetComponent;

		PROCEDURE Apply*;
		BEGIN
			HALT(301);
		END Apply;

		PROCEDURE Synchronize*(force : BOOLEAN);
		BEGIN
			HALT(301);
		END Synchronize;

	END ComponentElement;

TYPE

	(** Displays and edits all properties that are common to Component and VisualComponent classes *)
	StandardProperties* = OBJECT(ComponentElement)
	VAR
		componentView : ComponentView;
		visualComponentView : VisualComponentView;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrStandardProperties);

			NEW(componentView); componentView.alignment.Set(WMComponents.AlignTop);
			AddContent(componentView);

			NEW(visualComponentView); visualComponentView.alignment.Set(WMComponents.AlignTop);
			AddContent(visualComponentView);
			fillColor.Set(WMGraphics.Blue);

			bounds.SetHeight(componentView.bounds.GetHeight() + visualComponentView.bounds.GetHeight() + 2 * LineBearing);
		END Init;

		PROCEDURE CountNofElements(component : WMComponents.Component);
		VAR propertyArray : WMProperties.PropertyArray;  i : LONGINT;
		BEGIN
			nofElements := 0;
			IF (component # NIL) THEN
				propertyArray := component.properties.Enumerate();
				IF (propertyArray # NIL) THEN
					FOR i := 0 TO LEN(propertyArray) - 1 DO
						IF IsComponentProperty(propertyArray[i]) OR IsVisualComponentProperty(propertyArray[i]) THEN
							INC(nofElements);
						END;
					END;
				END;
			END;
		END CountNofElements;

		PROCEDURE SetProperties(component : WMComponents.Component);
		VAR propertyArray : WMProperties.PropertyArray; res, i : LONGINT;
			init:WMProperties.BooleanProperty;
		BEGIN
			ASSERT(component # NIL);
			NEW(init, WMProperties.NewBoolean(), Strings.NewString("Initialized"), Strings.NewString("component is initialized (readonly field). Required for proper function. "));
			init.Set(component.initialized);
			componentView.SetProperty(init, res); 
			componentView.initializedView.Disable; (*! currently readonly. tbd: allow modification by inspector *)
			nofElements := 0;
			propertyArray := component.properties.Enumerate();
			IF (propertyArray # NIL) THEN
				FOR i := 0 TO LEN(propertyArray)-1 DO
					IF IsComponentProperty(propertyArray[i]) THEN
						componentView.SetProperty(propertyArray[i], res);
						ASSERT(res = Ok);
						INC(nofElements);
					ELSIF IsVisualComponentProperty(propertyArray[i])  THEN
						visualComponentView.SetProperty(propertyArray[i], res);
						ASSERT(res = Ok);
						INC(nofElements);
					END;
				END;
			END;
		END SetProperties;

		PROCEDURE SetComponent*(component : WMComponents.Component);
		BEGIN
			IF (component # SELF.component) THEN
				DisableUpdate;
				Acquire;
				SELF.component := component;
				componentView.ResetProperties;
				visualComponentView.ResetProperties;
				IF (component # NIL) THEN
					SetProperties(component);
					componentView.visible.Set(TRUE);
					IF (component IS WMComponents.VisualComponent) THEN
						visualComponentView.visible.Set(TRUE);
					ELSE
						visualComponentView.visible.Set(FALSE);
					END;
				ELSE
					nofElements := 0;
					componentView.visible.Set(FALSE);
					visualComponentView.visible.Set(FALSE);
				END;
				Release;
				Synchronize(TRUE);
				EnableUpdate;
				Invalidate;
			END;
		END SetComponent;

		PROCEDURE Apply*;
		BEGIN
			Acquire;
			IF (componentView.visible.Get()) THEN componentView.Apply; END;
			IF (visualComponentView.visible.Get()) THEN visualComponentView.Apply; END;
			Release;
		END Apply;

		PROCEDURE Synchronize*(force : BOOLEAN);
		BEGIN
			Acquire;
			IF (componentView.visible.Get()) THEN componentView.Synchronize(force); END;
			IF (visualComponentView.visible.Get()) THEN visualComponentView.Synchronize(force); END;
			Release;
			Invalidate;
		END Synchronize;

		PROCEDURE Enable;
		BEGIN
			componentView.Enable;
			visualComponentView.Enable;
		END Enable;

		PROCEDURE Disable;
		BEGIN
			componentView.Disable;
			visualComponentView.Disable;
		END Disable;

	END StandardProperties;

TYPE

	CacheEntry = POINTER TO RECORD
		ps : ExtendedProperties;
		milliTimer : Kernel.MilliTimer;
		next : CacheEntry;
	END;

	PropertySheetCache = OBJECT
	VAR
		entries : CacheEntry;
		nofEntries : LONGINT;

		PROCEDURE &Init;
		BEGIN
			entries := NIL;
			nofEntries := 0;
		END Init;

		PROCEDURE Find(component : WMComponents.Component) : ExtendedProperties;
		VAR result : ExtendedProperties; e : CacheEntry;
		BEGIN
			ASSERT(component # NIL);
			result := NIL;
			e := entries;
			WHILE (e # NIL) & ~e.ps.IsCompatible(component) DO e := e.next; END;
			IF (e # NIL) THEN
				result := e.ps;
				Kernel.SetTimer(e.milliTimer, 0);
				ASSERT(result.GetParent() # NIL);
			END;
			RETURN result;
		END Find;

		PROCEDURE FindLRU() : CacheEntry;
		VAR age, currentAge : LONGINT; lru, e : CacheEntry;
		BEGIN
			age := 0;
			lru := NIL;
			e := entries;
			WHILE (e # NIL) DO
				currentAge := Kernel.Elapsed(e.milliTimer);
				IF (currentAge > age) THEN
					age := currentAge;
					lru := e;
				END;
				e := e.next;
			END;
			RETURN lru;
		END FindLRU;

		PROCEDURE Add(ps : ExtendedProperties);
		VAR e : CacheEntry; parent : XML.Element;
		BEGIN
			ASSERT((ps # NIL) & (ps.GetParent() # NIL));
			IF (nofEntries < MaxNofCacheEntries) THEN
				NEW(e); e.ps := ps;
				e.next := entries; entries := e;
			ELSE
				e := FindLRU();
				ASSERT((e # NIL) & (e.ps.GetParent() # NIL));
				parent := e.ps.GetParent();
				parent.RemoveContent(e.ps);
				e.ps := ps;
			END;
			INC(nofEntries);
			Kernel.SetTimer(e.milliTimer, 0);
		END Add;

	END PropertySheetCache;

TYPE
	ExtendedPropertiesView = OBJECT(ComponentElement)
	VAR
		cache : PropertySheetCache;
		current : ExtendedProperties;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(StrExtendedPropertiesView);
			NEW(cache);
			current := NIL;
		END Init;

		PROCEDURE CountNofElements(component : WMComponents.Component);
		BEGIN
			nofElements := CountExtendedProperties(component);
		END CountNofElements;

		PROCEDURE SetComponent(component : WMComponents.Component);
		VAR ps : ExtendedProperties; generateNew : BOOLEAN;
		BEGIN
			DisableUpdate;
			IF (component # NIL) THEN
				IF (current # NIL) THEN
					current.visible.Set(FALSE);
					current.ClearProperties;
				END;
				ps := cache.Find(component);
				IF (ps # NIL) THEN
					current := ps;
					generateNew := ~current.UpdateProperties(component);
					IF ~generateNew THEN
						current.Synchronize(TRUE);
						current.visible.Set(TRUE);
					ELSE
						current.visible.Set(FALSE);
					END;
				ELSE
					generateNew := TRUE;
				END;
				IF generateNew THEN
					NEW(ps);
					ps.SetComponent(component);
					ps.alignment.Set(WMComponents.AlignTop);
					AddContent(ps);
					current := ps;
					cache.Add(ps);
				END;
				ASSERT(current # NIL);
				bounds.SetHeight(current.bounds.GetHeight());
				nofElements := current.nofElements;
			ELSE
				nofElements := 0;
				IF (current # NIL) THEN
					current.visible.Set(FALSE);
					current.ClearProperties;
				END;
			END;
			EnableUpdate;
			Invalidate;
		END SetComponent;

		PROCEDURE Apply;
		BEGIN
			IF (current # NIL) THEN current.Apply; END;
		END Apply;

		PROCEDURE Synchronize(force : BOOLEAN);
		BEGIN
			IF (current # NIL) THEN current.Synchronize(force); END;
		END Synchronize;

		PROCEDURE Enable;
		BEGIN
			IF (current # NIL) THEN current.Enable; END;
		END Enable;

		PROCEDURE Disable;
		BEGIN
			IF (current # NIL) THEN current.Disable; END;
		END Disable;

	END ExtendedPropertiesView;

TYPE

	ExtendedProperties* = OBJECT(ComponentElement)
	VAR
		list : PropertyViewList;
		content : WMStandardComponents.Panel;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrExtendedProperties);
			NEW(list);
			content := NIL;
		END Init;

		PROCEDURE CountNofElements(component : WMComponents.Component);
		BEGIN
			nofElements := CountExtendedProperties(component);
		END CountNofElements;

		PROCEDURE ClearProperty(pv : PropertyView; ignore : BOOLEAN);
		BEGIN
			pv.SetProperty(NIL);
		END ClearProperty;

		PROCEDURE ClearProperties;
		BEGIN
			list.Enumerate(ClearProperty, TRUE);
		END ClearProperties;

		PROCEDURE IsCompatible(component : WMComponents.Component) : BOOLEAN;
		VAR pa : WMProperties.PropertyArray; pva : PropertyViewArray; i, j : LONGINT; compatible : BOOLEAN;
		BEGIN
			pva := list.GetAll();
			IF (component # NIL) THEN pa := component.properties.Enumerate(); ELSE pa := NIL; END;
			IF (pva = NIL) & (pa = NIL) THEN
				compatible := TRUE;
			ELSIF (pa # NIL) & (pva = NIL) THEN
				compatible := TRUE;
				i := 0;
				WHILE compatible & (i < LEN(pa)) DO
					compatible := IsComponentProperty(pa[i]) OR IsVisualComponentProperty(pa[i]);
					INC(i);
				END;
			ELSIF (pa # NIL) & (pva # NIL) & (LEN(pa) >= LEN(pva)) THEN
				compatible := TRUE;
				i := 0; j := 0;
				WHILE compatible & (i < LEN(pa)) & (j < LEN(pva))  DO
					IF ~IsComponentProperty(pa[i]) & ~IsVisualComponentProperty(pa[i]) THEN
						compatible := pva[j].IsCompatible(pa[i]);
						INC(j);
					END;
					INC(i);
				END;
				compatible := compatible & (i = LEN(pa)) & (j = LEN(pva));
			ELSE
				compatible := FALSE;
			END;
			RETURN compatible;
		END IsCompatible;

		PROCEDURE UpdateProperties(component : WMComponents.Component) : BOOLEAN;
		VAR pa : WMProperties.PropertyArray; pva : PropertyViewArray; i, j : LONGINT; ok : BOOLEAN;
		BEGIN
			ASSERT(component # NIL);
			pa := component.properties.Enumerate();
			pva := list.GetAll();
			IF (pa = NIL) & (pva = NIL) THEN
				ok := TRUE;
			ELSIF (pa # NIL) & (pva = NIL) THEN
				ok := TRUE;
				i := 0;
				WHILE ok & (i < LEN(pa)) DO
					ok := IsComponentProperty(pa[i]) OR IsVisualComponentProperty(pa[i]);
					INC(i);
				END;
			ELSIF (pa # NIL) & (pva # NIL) & (LEN(pa) >= LEN(pva)) THEN
				ok := TRUE;
				i := 0; j := 0;
				WHILE ok & (i < LEN(pa)) & (j < LEN(pva)) DO
					IF ~IsComponentProperty(pa[i]) & ~IsVisualComponentProperty(pa[i]) THEN
						ok := pva[j].IsCompatible(pa[i]);
						IF ok THEN
							pva[j].SetProperty(pa[i]);
							INC(j);
						END;
					END;
					INC(i);
				END;
				ok := ok & (i = LEN(pa)) & (j = LEN(pva));
			ELSE
				ok := FALSE;
			END;
			RETURN ok;
		END UpdateProperties;

		PROCEDURE SetProperties(component : WMComponents.Component);
		VAR
			propertyArray : WMProperties.PropertyArray;
			property : WMProperties.Property;
			booleanView : BooleanPropertyView;
			int32View : Int32PropertyView;
			realView : RealPropertyView;
			referenceView : ReferencePropertyView;
			fontView : FontPropertyView;
			rectangleView : RectanglePropertyView;
			pointView: PointPropertyView;
			stringView : StringPropertyView;
			colorView : ColorPropertyView;
			unknownView : UnknownPropertyView;
			height, i : LONGINT;
		BEGIN
			ASSERT(component # NIL);
			list.RemoveAll;
			height := 0;
			propertyArray := component.properties.Enumerate();
			IF (propertyArray # NIL) & (LEN(propertyArray) > 0) THEN
				NEW(content); content.alignment.Set(WMComponents.AlignClient);
				FOR i := 0 TO LEN(propertyArray)-1 DO
					property := propertyArray[i];
					IF ~IsComponentProperty(property) & ~ IsVisualComponentProperty(property) THEN
						INC(height, 2*LineBearing);
						IF (property IS WMProperties.BooleanProperty) THEN
							NEW(booleanView); booleanView.SetProperty(property (WMProperties.BooleanProperty));
							content.AddContent(booleanView);
							list.Add(booleanView);
							INC(height, booleanView.bounds.GetHeight());
							INC(nofElements);
						ELSIF (property IS WMProperties.Int32Property) THEN
							NEW(int32View); int32View.SetProperty(property (WMProperties.Int32Property));
							content.AddContent(int32View);
							list.Add(int32View);
							INC(height, int32View.bounds.GetHeight());
							INC(nofElements);
						ELSIF (property IS WMProperties.RealProperty) THEN
							NEW(realView); realView.SetProperty(property (WMProperties.RealProperty));
							content.AddContent(realView);
							list.Add(realView);
							INC(height, realView.bounds.GetHeight());
							INC(nofElements);
						ELSIF (property IS WMProperties.StringProperty) THEN
							NEW(stringView); stringView.SetProperty(property (WMProperties.StringProperty));
							content.AddContent(stringView);
							list.Add(stringView);
							INC(height, stringView.bounds.GetHeight());
							INC(nofElements);
						ELSIF (property IS WMProperties.RectangleProperty) THEN
							NEW(rectangleView, TRUE); rectangleView.SetProperty(property (WMProperties.RectangleProperty));
							content.AddContent(rectangleView);
							list.Add(rectangleView);
							INC(height, rectangleView.bounds.GetHeight());
							INC(nofElements);

						ELSIF (property IS WMProperties.PointProperty) THEN
							NEW(pointView, TRUE); pointView.SetProperty(property (WMProperties.PointProperty));
							content.AddContent(pointView);
							list.Add(pointView);
							INC(height, pointView.bounds.GetHeight());
							INC(nofElements);
						ELSIF  (property IS WMProperties.ColorProperty) THEN
							NEW(colorView); colorView.SetProperty(property (WMProperties.ColorProperty));
							content.AddContent(colorView);
							list.Add(colorView);
							INC(height, colorView.bounds.GetHeight());
							INC(nofElements);
						ELSIF (property IS WMProperties.FontProperty) THEN
							NEW(fontView); fontView.SetProperty(property (WMProperties.FontProperty));
							content.AddContent(fontView);
							list.Add(fontView);
							INC(height, fontView.bounds.GetHeight());
							INC(nofElements);
						ELSIF  (property IS WMProperties.ReferenceProperty) THEN
							NEW(referenceView); referenceView.SetProperty(property (WMProperties.ReferenceProperty));
							content.AddContent(referenceView);
							list.Add(referenceView);
							INC(height, referenceView.bounds.GetHeight());
							INC(nofElements);
						ELSE
							NEW(unknownView); unknownView.SetProperty(property);
							content.AddContent(unknownView);
							INC(height, unknownView.bounds.GetHeight());
							INC(nofElements);
						END;
					END;
				END;
				AddContent(content);
			END;
			bounds.SetHeight(height);
		END SetProperties;

		PROCEDURE SetComponent*(component : WMComponents.Component);
		BEGIN
			IF (component # SELF.component) THEN
				Acquire;
				SELF.component := component;
				nofElements := 0;
				IF (content # NIL) THEN RemoveContent(content); END;
				IF (component # NIL) THEN
					SetProperties(component);
				END;
				Release;
				Synchronize(TRUE);
			END;
		END SetComponent;

		PROCEDURE ApplyToView(p : PropertyView; force : BOOLEAN);
		BEGIN
			ASSERT(p # NIL);
			p.Apply(FALSE);
		END ApplyToView;

		PROCEDURE SynchronizeToModel(p : PropertyView; force : BOOLEAN);
		BEGIN
			ASSERT(p # NIL);
			p.Synchronize(force);
		END SynchronizeToModel;

		PROCEDURE Apply*;
		BEGIN
			Acquire;
			list.Enumerate(ApplyToView, FALSE);
			Release;
		END Apply;

		PROCEDURE Synchronize*(force : BOOLEAN);
		BEGIN
			Acquire;
			list.Enumerate(SynchronizeToModel, force);
			Release;
		END Synchronize;

		PROCEDURE SetEnabled(p : PropertyView; enabled : BOOLEAN);
		BEGIN
			ASSERT(p # NIL);
			IF enabled THEN p.Enable; ELSE p.Disable; END;
		END SetEnabled;

		PROCEDURE Enable;
		BEGIN
			Acquire;
			list.Enumerate(SetEnabled, TRUE);
			Release;
		END Enable;

		PROCEDURE Disable;
		BEGIN
			Acquire;
			list.Enumerate(SetEnabled, FALSE);
			Release;
		END Disable;

	END ExtendedProperties;

TYPE

	EventSources* = OBJECT(ComponentElement)
	VAR
		content : WMStandardComponents.Panel;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrEventSources);
			alignment.Set(WMComponents.AlignTop);
			content := NIL;
		END Init;

		PROCEDURE CountNofElements(component : WMComponents.Component);
		VAR eventsArray : WMEvents.EventSourceArray;
		BEGIN
			nofElements := 0;
			IF (component # NIL) THEN
				eventsArray := component.events.Enumerate();
				IF (eventsArray # NIL) THEN
					nofElements := LEN(eventsArray);
				END;
			END;
		END CountNofElements;

		PROCEDURE SetComponent*(component : WMComponents.Component);
		VAR eventsArray : WMEvents.EventSourceArray; source : EventSourceView;  height, i : LONGINT;
		BEGIN
			IF (component # SELF.component) THEN
				height := 0; nofElements := 0;
				Acquire;
				SELF.component := component;
				IF (content # NIL) THEN RemoveContent(content); END;
				IF (component # NIL) THEN
					eventsArray := component.events.Enumerate();
					IF (eventsArray # NIL) THEN
						NEW(content); content.alignment.Set(WMComponents.AlignClient);
						FOR i := 0 TO LEN(eventsArray)-1 DO
							NEW(source); source.SetEventSource(eventsArray[i]);
							content.AddContent(source);
							INC(height, source.bounds.GetHeight()+ 2*LineBearing);
						END;
						nofElements := LEN(eventsArray);
						AddContent(content);
					END;
				END;
				bounds.SetHeight(height);
				Release;
			END;
		END SetComponent;

		PROCEDURE Apply*;
		BEGIN

		END Apply;

		PROCEDURE Synchronize*(force : BOOLEAN);
		BEGIN

		END Synchronize;

	END EventSources;

TYPE

	EventListeners* = OBJECT(ComponentElement)
	VAR
		content : WMStandardComponents.Panel;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrEventListeners);
			alignment.Set(WMComponents.AlignTop);
			content := NIL;
		END Init;

		PROCEDURE CountNofElements(component : WMComponents.Component);
		VAR eventsArray : WMEvents.EventListenerArray;
		BEGIN
			nofElements := 0;
			IF (component # NIL) THEN
				eventsArray := component.eventListeners.Enumerate();
				IF (eventsArray # NIL) THEN
					nofElements := LEN(eventsArray);
				END;
			END;
		END CountNofElements;

		PROCEDURE SetComponent*(component : WMComponents.Component);
		VAR eventsArray : WMEvents.EventListenerArray; listener : EventListenerView; height, i : LONGINT;
		BEGIN
			IF (component # SELF.component) THEN
				height := 0; nofElements := 0;
				Acquire;
				SELF.component := component;
				IF (content # NIL) THEN RemoveContent(content); END;
				IF (component # NIL) THEN
					eventsArray := component.eventListeners.Enumerate();
					IF (eventsArray # NIL) THEN
						NEW(content); content.alignment.Set(WMComponents.AlignClient);
						FOR i := 0 TO LEN(eventsArray)-1 DO
							NEW(listener); listener.SetEventListener(eventsArray[i]);
							content.AddContent(listener);
							INC(height, listener.bounds.GetHeight() + 2*LineBearing);
						END;
						nofElements := LEN(eventsArray);
						AddContent(content);
					END;
				END;
				bounds.SetHeight(height);
				Release;
			END;
		END SetComponent;

		PROCEDURE Apply*;
		BEGIN

		END Apply;

		PROCEDURE Synchronize*(force : BOOLEAN);
		BEGIN

		END Synchronize;

	END EventListeners;

TYPE

	AttributeView = OBJECT(WMComponents.VisualComponent)
	VAR
		attribute : XML.Attribute; element : XML.Element;
		outOfDate : BOOLEAN;
		editor : WMEditors.TextField;
		next : AttributeView;

		PROCEDURE &Init;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("AttributeView"));
			attribute := NIL; element := NIL;
			outOfDate := FALSE;

			alignment.Set(WMComponents.AlignTop);
			bounds.SetHeight(LineHeight);
			bearing.Set(WMRectangles.MakeRect(LineBearing, LineBearing, LineBearing, LineBearing));

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.type.Set(WMEditors.Ascii);
			editor.bearing.Set(WMRectangles.MakeRect(NameWidth, 0, 0, 0));
			editor.onEnter.Add(EnterPressed);
			editor.onChanged.Add(EditorContentChanged);
			AddContent(editor);

			next := NIL;
		END Init;

		PROCEDURE SetAttribute(attribute : XML.Attribute);
		BEGIN
			SELF.attribute := attribute;
		END SetAttribute;

		PROCEDURE Apply;
		VAR attribute : XML.Attribute; string : ARRAY 1024 OF CHAR;
		BEGIN
			attribute := SELF.attribute;
			IF (attribute # NIL) THEN
				editor.GetAsString(string);
				attribute.SetValue(string);
				SetOutOfDate(FALSE);
			END;
		END Apply;

		PROCEDURE Synchronize;
		VAR attribute : XML.Attribute; value : Strings.String;
		BEGIN
			attribute := SELF.attribute;
			IF (attribute # NIL) THEN
				value := attribute.GetValue();
				IF (value # NIL) THEN
					editor.SetAsString(value^);
				ELSE
					editor.SetAsString("");
				END;
			ELSE
				editor.SetAsString("");
			END;
			SetOutOfDate(FALSE);
		END Synchronize;

		PROCEDURE SetOutOfDate(value : BOOLEAN);
		BEGIN
			IF (outOfDate # value) THEN
				outOfDate := value;
				IF outOfDate THEN
					editor.fillColor.Set(LONGINT(0FFFF0099H));
				ELSE
					editor.fillColor.Set(WMGraphics.White);
				END;
			END;
		END SetOutOfDate;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			Apply;
		END EnterPressed;

		PROCEDURE EditorContentChanged(sender, data : ANY);
		BEGIN
			SetOutOfDate(TRUE);
		END EditorContentChanged;

		PROCEDURE DrawForeground(canvas : WMGraphics.Canvas);
		VAR attribute : XML.Attribute; name : Strings.String;
		BEGIN
			DrawForeground^(canvas);
			attribute := SELF.attribute;
			IF (attribute # NIL) THEN
				name := attribute.GetName();
				canvas.DrawString(0, 14, name^);
			ELSE
				canvas.DrawString(0, 14, "NoName");
			END;
		END DrawForeground;

	END AttributeView;

TYPE

	Attributes* = OBJECT(ComponentElement)
	VAR
		(* add/remove attributes *)
		controlPanel : WMStandardComponents.Panel;
		nameEditor, valueEditor : WMEditors.TextField;
		removeBtn, addBtn : WMStandardComponents.Button;

		(* display attributes *)
		views : AttributeView;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("Attributes"));
			
			NEW(controlPanel); controlPanel.alignment.Set(WMComponents.AlignTop);
			controlPanel.bounds.SetHeight(LineHeight);
			controlPanel.bearing.Set(WMRectangles.MakeRect(LineBearing, LineBearing, LineBearing, LineBearing));
			AddContent(controlPanel);

			NEW(removeBtn); removeBtn.alignment.Set(WMComponents.AlignRight);
			removeBtn.caption.SetAOC("Remove");
			removeBtn.onClick.Add(RemoveAttributeHandler);
			controlPanel.AddContent(removeBtn);

			NEW(addBtn); addBtn.alignment.Set(WMComponents.AlignRight);
			addBtn.caption.SetAOC("Add");
			addBtn.onClick.Add(AddAttributeHandler);
			controlPanel.AddContent(addBtn);

			NEW(nameEditor); nameEditor.alignment.Set(WMComponents.AlignLeft);
			nameEditor.bounds.SetWidth(NameWidth);
			nameEditor.type.Set(WMEditors.Ascii);
			nameEditor.onEnter.Add(EnterPressed);
			nameEditor.uid.SetAOC("nameEditor");
			nameEditor.focusPrevious.SetAOC("&valueEditor");
			nameEditor.focusNext.SetAOC("&valueEditor");
			controlPanel.AddContent(nameEditor);

			NEW(valueEditor); valueEditor.alignment.Set(WMComponents.AlignClient);
			valueEditor.type.Set(WMEditors.Ascii);
			valueEditor.onEnter.Add(EnterPressed);
			valueEditor.uid.SetAOC("valueEditor");
			valueEditor.focusPrevious.SetAOC("&nameEditor");
			valueEditor.focusNext.SetAOC("&nameEditor");
			controlPanel.AddContent(valueEditor);

			bounds.SetHeight(controlPanel.bounds.GetHeight() + 2*LineBearing);

			views := NewAttributeView();
		END Init;

		PROCEDURE EnterPressed(sender, data : ANY);
		BEGIN
			AddAttributeHandler(sender, data);
		END EnterPressed;

		PROCEDURE RemoveAttributeHandler(sender, data : ANY);
		VAR attributeName : ARRAY 256 OF CHAR;
		BEGIN
			nameEditor.GetAsString(attributeName);
			Strings.TrimWS(attributeName);
			IF (component # NIL) THEN
				component.RemoveAttribute(attributeName);
				Synchronize(TRUE);
			END;
		END RemoveAttributeHandler;

		PROCEDURE AddAttributeHandler(sender, data : ANY);
		VAR attributeName, attributeValue : ARRAY 256 OF CHAR;
		BEGIN
			IF (component # NIL) THEN
				nameEditor.GetAsString(attributeName);
				Strings.TrimWS(attributeName);
				IF (attributeName # "") THEN
					valueEditor.GetAsString(attributeValue);
					component.SetAttributeValue(attributeName, attributeValue);
					Synchronize(TRUE);
				END;
			END;
		END AddAttributeHandler;

		PROCEDURE NewAttributeView() : AttributeView;
		VAR v : AttributeView;
		BEGIN
			NEW(v); v.alignment.Set(WMComponents.AlignTop);
			v.bounds.SetHeight(LineHeight);
			v.bearing.Set(WMRectangles.MakeRect(LineBearing, LineBearing, LineBearing, LineBearing));
			AddContent(v);
			RETURN v;
		END NewAttributeView;

		PROCEDURE CountNofElements(component : WMComponents.Component);
		VAR enumerator : XMLObjects.Enumerator; ignore : ANY;
		BEGIN
			nofElements := 0;
			IF (component # NIL) THEN
				enumerator := component.GetAttributes();
				WHILE enumerator.HasMoreElements() DO
					ignore := enumerator.GetNext();
					INC(nofElements);
				END;
			END;
		END CountNofElements;

		PROCEDURE SetAttributes(element : XML.Element);
		VAR
			v, last : AttributeView; enumerator : XMLObjects.Enumerator; ptr : ANY;
			height : LONGINT;
		BEGIN
			Acquire;
			height := LineHeight + 2*LineBearing; (* add/remove panel *)
			v := views;
			WHILE (v # NIL) DO
				v.SetAttribute(NIL); v.visible.Set(FALSE);
				v := v.next;
			END;
			nofElements := 0;
			IF (element # NIL) THEN
				v := views; last := views;
				enumerator := element.GetAttributes();
				WHILE enumerator.HasMoreElements() DO
					ptr := enumerator.GetNext();
					IF (ptr IS XML.Attribute) THEN
						INC(nofElements);
						IF (v = NIL) THEN
							v := NewAttributeView();
							last.next := v;
						END;
						v.SetAttribute(ptr(XML.Attribute));
						v.visible.Set(TRUE);
						v.Synchronize;
						height := height + v.bounds.GetHeight() + 2*LineBearing;
						last := v;
						v := v.next;
					END;
				END;
			END;
			Release;
			bounds.SetHeight(height);
			Reset(NIL, NIL);
			Invalidate;
		END SetAttributes;

		PROCEDURE SetComponent*(component : WMComponents.Component);
		BEGIN
			IF (component # SELF.component) THEN
				DisableUpdate;
				Acquire;
				SELF.component := component;
				controlPanel.visible.Set(component # NIL);
				SetAttributes(component);
				Release;
				EnableUpdate;
				Invalidate;
			END;
		END SetComponent;

		PROCEDURE Apply*;
		VAR v : AttributeView;
		BEGIN
			v := views;
			WHILE (v # NIL) DO v.Apply; v := v.next; END;
		END Apply;

		PROCEDURE Synchronize*(force : BOOLEAN);
		BEGIN
			SetAttributes(SELF.component);
		END Synchronize;

	END Attributes;

CONST
	(* PropertyPanel.state *)
	State_Waiting = 0;
	State_Synchronize = 1;
	State_SynchronizeForce = 2;
	State_Terminating = 99;
	State_Terminated = 100;

	NofTabs = 5;

TYPE

	PropertyPanel* = OBJECT(WMComponents.VisualComponent)
	VAR
		component : WMComponents.Component;

		standardProperties : StandardProperties;
		extendedProperties : ExtendedPropertiesView;
		eventListeners : EventListeners;
		eventSources : EventSources;
		attributes : Attributes;

		autoRefreshBtn, refreshBtn, applyBtn : WMStandardComponents.Button;

		autoRefresh : BOOLEAN;

		tabs : WMTabComponents.Tabs;
		tabList : ARRAY NofTabs OF WMTabComponents.Tab;
		tabPanels : ARRAY NofTabs OF ComponentElement;
		tabNofElements : ARRAY NofTabs OF LONGINT;
		tabCaptions : ARRAY NofTabs OF ARRAY 128 OF CHAR;

		tabPanel : WMScrollableComponents.ScrollableContainer;
		curTabPanel : ComponentElement;
		curTab : WMTabComponents.Tab;

		(* active body *)
		state, internalState : LONGINT;
		timer : Kernel.Timer;

		PROCEDURE &Init*;
		VAR panel, toolbar : WMStandardComponents.Panel;  i : LONGINT;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("PropertyPanel"));
			state := State_Waiting; internalState := state;
			NEW(timer);

			NEW(panel); panel.alignment.Set(WMComponents.AlignClient);

			NEW(tabs);  tabs.bounds.SetHeight(20); tabs.alignment.Set(WMComponents.AlignTop);
			tabs.onSelectTab.Add(TabSelected);
			panel.AddContent(tabs);

			NEW(toolbar); toolbar.alignment.Set(WMComponents.AlignBottom);
			toolbar.bounds.SetHeight(20);
			toolbar.bearing.Set(WMRectangles.MakeRect(2*LineBearing, LineBearing, 2*LineBearing, LineBearing));
			panel.AddContent(toolbar);

			NEW(applyBtn); applyBtn.alignment.Set(WMComponents.AlignRight);
			applyBtn.caption.SetAOC("Apply");
			applyBtn.onClick.Add(ButtonHandler);
			toolbar.AddContent(applyBtn);

			NEW(refreshBtn); refreshBtn.alignment.Set(WMComponents.AlignRight);
			refreshBtn.caption.SetAOC("Refresh");
			refreshBtn.onClick.Add(ButtonHandler);
			toolbar.AddContent(refreshBtn);

			NEW(autoRefreshBtn); autoRefreshBtn.alignment.Set(WMComponents.AlignLeft);
			autoRefreshBtn.caption.SetAOC("AutoRefresh");
			autoRefreshBtn.isToggle.Set(TRUE);
			autoRefreshBtn.SetPressed(TRUE);
			autoRefreshBtn.onClick.Add(ButtonHandler);
			autoRefreshBtn.bounds.SetWidth(80);
			toolbar.AddContent(autoRefreshBtn);

			autoRefresh := autoRefreshBtn.GetPressed();

			NEW(tabPanel); tabPanel.alignment.Set(WMComponents.AlignClient);
			panel.AddContent(tabPanel);

			NEW(standardProperties); tabPanels[0] := standardProperties;
			NEW(extendedProperties); tabPanels[1] := extendedProperties;
			NEW(eventSources); tabPanels[2] := eventSources;
			NEW(eventListeners); tabPanels[3] := eventListeners;
			NEW(attributes); tabPanels[4] := attributes;

			FOR i := 0 TO NofTabs-1 DO
				tabNofElements[i] := -1; (* force update *)
				tabPanels[i].alignment.Set(WMComponents.AlignTop);
				tabPanel.AddContent(tabPanels[i]);
				tabPanels[i].visible.Set(FALSE);
				tabPanels[i].fillColor.Set(WMGraphics.White);
				tabPanels[i].bearing.Set(WMRectangles.MakeRect(10, 10, 10, 10));
				tabList[i] := tabs.NewTab(); tabs.AddTab(tabList[i]);
				CASE i OF
					|0: tabCaptions[i] := "Standard Properties";
					|1: tabCaptions[i] := "Extended Properties";
					|2: tabCaptions[i] := "Event Sources";
					|3: tabCaptions[i] := "Event Listeners";
					|4: tabCaptions[i] := "Attributes";
				ELSE
					HALT(99);
				END;
				tabs.SetTabData(tabList[i], tabPanels[i]);
			END;
			UpdateTabCaptions;

			curTabPanel := standardProperties; curTab := tabList[0]; curTabPanel.visible.Set(TRUE);
			AddContent(panel);
		END Init;

		PROCEDURE UpdateTabCaptions;
		VAR caption : ARRAY 128 OF CHAR; nbr : ARRAY 8 OF CHAR; nofElements, i : LONGINT;
		BEGIN
			FOR i := 0 TO NofTabs - 1 DO
				CASE i OF
					|0: nofElements := standardProperties.GetNofElements();
					|1: nofElements := extendedProperties.GetNofElements();
					|2: nofElements := eventSources.GetNofElements();
					|3: nofElements := eventListeners.GetNofElements();
					|4: nofElements := attributes.GetNofElements();
				ELSE
					HALT(99);
				END;
				IF (nofElements # tabNofElements[i]) THEN
					tabNofElements[i] := nofElements;
					COPY(tabCaptions[i], caption);
					Strings.Append(caption, " (");
					Strings.IntToStr(nofElements, nbr); Strings.Append(caption, nbr);
					Strings.Append(caption, ")");
					tabs.SetTabCaption(tabList[i], Strings.NewString(caption));
				END;
			END;
		END UpdateTabCaptions;

		PROCEDURE SetState(state : LONGINT);
		BEGIN {EXCLUSIVE}
			IF (SELF.state < State_Terminating) THEN
				SELF.state := state;
			END;
		END SetState;

		PROCEDURE PropertyListChanged(sender, data : ANY);
		BEGIN
			SetState(State_Synchronize);
		END PropertyListChanged;

		PROCEDURE LinkChanged(sender, data : ANY);
		BEGIN
			SetState(State_SynchronizeForce);
		END LinkChanged;

		PROCEDURE SetComponent*(sender, component : ANY);
		BEGIN
			IF ~IsCallFromSequencer() THEN
				 sequencer.ScheduleEvent(SELF.SetComponent, sender, component)
			ELSE
				IF (component # NIL) & (component IS WMComponents.Component) THEN
					SetComponentInternal(component(WMComponents.Component));
				ELSE
					SetComponentInternal(NIL);
				END;
			END;
		END SetComponent;

		PROCEDURE Enable;
		BEGIN
			standardProperties.Enable;
			extendedProperties.Enable;
		END Enable;

		PROCEDURE Disable;
		BEGIN
			standardProperties.Disable;
			extendedProperties.Disable;
		END Disable;

		PROCEDURE SetComponentInternal*(component : WMComponents.Component);
		VAR vc : WMComponents.VisualComponent;
		BEGIN
			ASSERT(IsCallFromSequencer());
			IF (component # SELF.component) THEN
				IF (SELF.component # NIL) THEN
					SELF.component.properties.onPropertyChanged.Remove(PropertyListChanged);
					SELF.component.properties.onLinkChanged.Remove(LinkChanged)
				END;
				SELF.component := component;
				vc := curTabPanel;
				IF (vc = standardProperties) THEN standardProperties.SetComponent(component);
				ELSE standardProperties.CountNofElements(component);
				END;
				IF (vc = extendedProperties) THEN extendedProperties.SetComponent(component);
				ELSE extendedProperties.CountNofElements(component);
				END;
				IF (vc = eventSources) THEN eventSources.SetComponent(component);
				ELSE eventSources.CountNofElements(component);
				END;
				IF (vc = eventListeners) THEN	 eventListeners.SetComponent(component);
				ELSE eventListeners.CountNofElements(component);
				END;
				IF (vc = attributes) THEN attributes.SetComponent(component);
				ELSE attributes.CountNofElements(component);
				END;
				IF (component # NIL) THEN
					component.properties.onPropertyChanged.Add(PropertyListChanged);
					component.properties.onLinkChanged.Add(LinkChanged);
				END;
				DisableUpdate;
				UpdateTabCaptions;
				vc.Resized;
				tabPanel.Reset(NIL, NIL);
				IF (component # NIL) THEN
					IF component.IsLocked() THEN Disable; ELSE Enable; END;
				END;
				EnableUpdate;
				Invalidate;
			END;
		END SetComponentInternal;

		PROCEDURE TabSelected(sender, data : ANY);
		VAR tab : WMTabComponents.Tab;
		BEGIN
			IF (data # NIL) & (data IS WMTabComponents.Tab) THEN
				DisableUpdate;
				tab := data(WMTabComponents.Tab);
				IF (tab.data # NIL) & (tab.data IS WMComponents.VisualComponent) THEN
					curTabPanel.visible.Set(FALSE);
					curTab := tab;
					curTabPanel := tab.data(ComponentElement);
					IF (curTabPanel = standardProperties) THEN
						standardProperties.SetComponent(component);
					ELSIF (curTabPanel = extendedProperties) THEN
						extendedProperties.SetComponent(component);
					ELSIF (curTabPanel = eventSources) THEN
						eventSources.SetComponent(component);
					ELSIF (curTabPanel = eventListeners) THEN
						eventListeners.SetComponent(component);
					ELSIF (curTabPanel = attributes) THEN
						attributes.SetComponent(component);
					END;
					curTabPanel.visible.Set(TRUE);
					tabPanel.Reset(SELF, NIL);
				END;
				EnableUpdate;
				tabPanel.Invalidate;
			END;
		END TabSelected;

		PROCEDURE ButtonHandler(sender, data : ANY);
		BEGIN
			IF (sender = refreshBtn) THEN
				SetState(State_SynchronizeForce);
				timer.Wakeup;
			ELSIF (sender = applyBtn) THEN
				curTabPanel.Apply;
			ELSIF (sender = autoRefreshBtn) THEN
				autoRefresh := autoRefreshBtn.GetPressed();
				IF autoRefresh THEN
					SetState(State_SynchronizeForce);
					timer.Wakeup;
				END;
			END;
		END ButtonHandler;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF (component # NIL) THEN
				component.properties.onPropertyChanged.Remove(PropertyListChanged);
				component.properties.onLinkChanged.Remove(LinkChanged);
			END;
			BEGIN {EXCLUSIVE} state := State_Terminating; END;
			BEGIN {EXCLUSIVE} AWAIT(state = State_Terminated); END;
		END Finalize;

		PROCEDURE Synchronize(force : BOOLEAN);
		BEGIN
			IF autoRefresh THEN
				standardProperties.Synchronize(force);
				extendedProperties.Synchronize(force);
				attributes.Synchronize(force);
			END;
		END Synchronize;

	BEGIN {ACTIVE}
		WHILE (state < State_Terminating) DO
			BEGIN {EXCLUSIVE}
				AWAIT(state # State_Waiting);
				internalState := state;
				IF (state < State_Terminating) THEN state := State_Waiting; END;
			END;
			IF (internalState = State_Synchronize) THEN
				Synchronize(FALSE);
			ELSIF (internalState = State_SynchronizeForce) THEN
				Synchronize(TRUE);
			ELSIF (internalState # State_Terminating) THEN
				timer.Sleep(30);
			END;
		END;
		BEGIN {EXCLUSIVE} state := State_Terminated; END;
	END PropertyPanel;

TYPE

	RepositoryPanel* = OBJECT(WMComponents.VisualComponent)
	VAR
		component : Repositories.Component;
		lastTimestamp : LONGINT;

		repositoryName : WMStandardComponents.Label;
		editor : WMEditors.TextField;
		storeBtn, unbindBtn, removeBtn, updateBtn : WMStandardComponents.Button;

		state : LONGINT;
		timer : Kernel.Timer;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("RepositoryPanel"));
			state := State_Waiting;
			NEW(timer);
			CreateContent;
		END Init;

		PROCEDURE CreateContent;
		VAR line : WMStandardComponents.Panel;
		BEGIN
			line := CreateLine();
			line.AddContent(CreateLabel("Repository:", 80, WMComponents.AlignLeft));

			NEW(updateBtn); updateBtn.alignment.Set(WMComponents.AlignRight);
			updateBtn.caption.SetAOC("Update");
			updateBtn.onClick.Add(HandleUpdateButton);
			line.AddContent(updateBtn);

			NEW(removeBtn); removeBtn.alignment.Set(WMComponents.AlignRight);
			removeBtn.caption.SetAOC("Remove");
			removeBtn.onClick.Add(HandleRemoveButton);
			line.AddContent(removeBtn);

			NEW(unbindBtn); unbindBtn.alignment.Set(WMComponents.AlignRight);
			unbindBtn.caption.SetAOC("Unbind");
			unbindBtn.onClick.Add(HandleUnbindButton);
			line.AddContent(unbindBtn);

			NEW(repositoryName); repositoryName.alignment.Set(WMComponents.AlignClient);
			line.AddContent(repositoryName);

			AddContent(line);

			line := CreateLine();

			NEW(storeBtn); storeBtn.alignment.Set(WMComponents.AlignLeft);
			storeBtn.bounds.SetWidth(80);
			storeBtn.caption.SetAOC("Store into:");
			storeBtn.onClick.Add(HandleStoreButton);
			line.AddContent(storeBtn);

			NEW(editor); editor.alignment.Set(WMComponents.AlignClient);
			editor.type.Set(WMEditors.Ascii);
			editor.fillColor.Set(WMGraphics.White);
			line.AddContent(editor);

			AddContent(line);
		END CreateContent;

		PROCEDURE HandleStoreButton(sender, data : ANY);
		VAR
			component : Repositories.Component; repository : Repositories.Repository;
			name, repositoryName, componentName : ARRAY 256 OF CHAR; id, res : LONGINT;
			filename : Files.FileName;
		BEGIN
			component := SELF.component;
			IF (component # NIL) THEN
				editor.GetAsString(name);
				IF Repositories.SplitName(name, repositoryName, componentName, id) THEN
					repository := Repositories.ThisRepository(repositoryName);
					IF (repository = NIL) THEN
						res := WMDialogs.Message(WMDialogs.TQuestion, "Question", "Repository not found, create new repository?", {WMDialogs.ResYes, WMDialogs.ResNo});
						IF (res = WMDialogs.ResYes) THEN
							COPY(repositoryName, filename); Strings.Append(filename, "."); Strings.Append(filename, Repositories.DefaultFileExtension);
							Repositories.CreateRepository(filename, res);
							IF (res = Repositories.Ok) THEN
								repository := Repositories.ThisRepository(repositoryName);
								IF (repository = NIL) THEN
									WMDialogs.Error("Error", "Could not load just created repository");
								END;
							ELSE
								WMDialogs.Error("Error", "Could not create repository");
							END;
						END;
					END;
					IF (repository # NIL) THEN
						repository.PutComponent(component, componentName, id, res);
						IF (res # Repositories.Ok) THEN
							WMDialogs.Error("Error", "Could not put component into repository");
						END;
					END;
				ELSE
					WMDialogs.Error("Error", "Invalid repository:component:refnum value");
				END;
			END;
		END HandleStoreButton;

		PROCEDURE HandleRemoveButton(sender, data : ANY);
		VAR component : Repositories.Component; ignore : Repositories.Name; repository : Repositories.Repository; refNum, res : LONGINT;
		BEGIN
			component := SELF.component;
			IF (component # NIL) THEN
				component.GetRepository(repository, ignore, refNum);
				IF (repository # NIL) THEN
					repository.Remove(component, res);
					IF (res # Repositories.Ok) THEN
						WMDialogs.Error("Error", "Component removal failed");
					END;
				ELSE
					WMDialogs.Error("Error", "Component is not bound to a repository");
				END;
			END;
		END HandleRemoveButton;

		PROCEDURE HandleUpdateButton(sender, data : ANY);
		VAR component : Repositories.Component; ignore : Repositories.Name;  repository : Repositories.Repository; refNum, res : LONGINT;
		BEGIN
			component := SELF.component;
			IF (component # NIL) THEN
				component.GetRepository(repository, ignore, refNum);
				IF (repository # NIL) THEN
					repository.Store(res);
					IF (res # Repositories.Ok) THEN
						WMDialogs.Error("Error", "Could not store repository");
					END;
				ELSE
					WMDialogs.Error("Error", "Component is not bound to a repository");
				END;
			END;
		END HandleUpdateButton;

		PROCEDURE HandleUnbindButton(sender, data : ANY);
		VAR component : Repositories.Component; ignore : Repositories.Name;  repository : Repositories.Repository; refNum : LONGINT;
		BEGIN
			component := SELF.component;
			IF (component # NIL) THEN
				component.GetRepository(repository, ignore, refNum);
				IF (repository # NIL) THEN
					repository.Unbind(component);
				ELSE
					WMDialogs.Error("Error", "Component is not bound to a repository");
				END;
			END;
		END HandleUnbindButton;

		PROCEDURE SetComponent*(component : WMComponents.Component);
		BEGIN
			SELF.component := component;
			IF (component # NIL) THEN lastTimestamp := component.timestamp - 1; ELSE lastTimestamp := -1; END;
			timer.Wakeup; (* force update *)
		END SetComponent;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			BEGIN {EXCLUSIVE} state := State_Terminating; END;
			timer.Wakeup;
			BEGIN {EXCLUSIVE} AWAIT(state = State_Terminated); END;
		END Finalize;

		PROCEDURE Update;
		VAR
			component : Repositories.Component; repository : Repositories.Repository; cname : Repositories.Name;
			caption : Strings.String; refNum : LONGINT;
		BEGIN
			component := SELF.component;
			IF (component # NIL) THEN
				IF (lastTimestamp # component.timestamp) THEN
					lastTimestamp := component.timestamp;
					component.GetRepository(repository, cname, refNum);
					IF (repository # NIL) THEN
						caption := Repositories.NewJoinName(repository.name, cname, refNum);
						repositoryName.caption.Set(caption);
					ELSE
						repositoryName.caption.SetAOC("");
					END;
				END;
			ELSIF (lastTimestamp = -1) THEN
				lastTimestamp := 0;
				repositoryName.caption.SetAOC("");
			END;
		END Update;

	BEGIN {ACTIVE}
		WHILE (state < State_Terminating) DO
			Update;
			timer.Sleep(200);
		END;
		BEGIN {EXCLUSIVE} state := State_Terminated; END;
	END RepositoryPanel;

TYPE

	XMLPanel* = OBJECT(WMComponents.VisualComponent)
	VAR
		component : Repositories.Component;
		showBtn : WMStandardComponents.Button;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(Strings.NewString("XMLPanel"));
			component := NIL;

			NEW(showBtn); showBtn.alignment.Set(WMComponents.AlignLeft);
			showBtn.bounds.SetWidth(80);
			showBtn.caption.SetAOC("Show XML");
			showBtn.onClick.Add(HandleShowBtn);
			showBtn.enabled.Set(FALSE);
			AddContent(showBtn);
		END Init;

		PROCEDURE HandleShowBtn(sender, data : ANY);
		VAR component : Repositories.Component; writer : WMUtilities.WindowWriter; name : Strings.String;
		BEGIN
			component := SELF.component;
			IF (component # NIL) THEN
				name := component.GetName();
				IF (name = NIL) THEN name := Strings.NewString("NoName"); END;
				NEW(writer, name^, 640, 480, FALSE);
				component.Write(writer,NIL, 0);
				writer.Update;
			END;
		END HandleShowBtn;

		PROCEDURE SetComponent*(component : WMComponents.Component);
		BEGIN
			SELF.component := component;
			showBtn.enabled.Set(component # NIL);
		END SetComponent;

	END XMLPanel;

TYPE

	ModelView* = OBJECT(WMComponents.VisualComponent)
	VAR
		model : Models.Model;
		typeLabel : WMStandardComponents.Label;
		editor : WMEditors.Editor;
		autoRefreshBtn : WMStandardComponents.Button;

		autoRefresh : BOOLEAN;

		PROCEDURE &Init*;
		VAR panel : WMStandardComponents.Panel; label : WMStandardComponents.Label;
		BEGIN
			Init^;
			SetNameAsString(StrModelView);
			model := NIL;
			bearing.Set(WMRectangles.MakeRect(LineBearing, LineBearing, LineBearing, LineBearing));
			autoRefresh := FALSE;

			NEW(panel); panel.alignment.Set(WMComponents.AlignTop);
			panel.bounds.SetHeight(LineHeight);
			AddInternalComponent(panel);

			NEW(label); label.alignment.Set(WMComponents.AlignLeft);
			label.bounds.SetWidth(80);
			label.caption.Set(StrType);
			panel.AddInternalComponent(label);

			NEW(typeLabel); typeLabel.alignment.Set(WMComponents.AlignClient);
			typeLabel.caption.Set(StrNoCaption);
			panel.AddInternalComponent(typeLabel);

			NEW(autoRefreshBtn); autoRefreshBtn.alignment.Set(WMComponents.AlignBottom);
			autoRefreshBtn.bounds.SetHeight(20);
			autoRefreshBtn.caption.SetAOC("AutoRefresh");
			autoRefreshBtn.isToggle.Set(TRUE);
			autoRefreshBtn.SetPressed(autoRefresh);
			autoRefreshBtn.onClick.Add(HandleAutoRefreshBtn);
			AddInternalComponent(autoRefreshBtn);

			NEW(editor);
			editor.alignment.Set(WMComponents.AlignClient);
			editor.tv.showBorder.Set(TRUE);
			editor.tv.borders.Set(WMRectangles.MakeRect(1, 1, 1, 1));
			editor.tv.SetExtKeyEventHandler(EditorKeyEvent);
			AddInternalComponent(editor);
		END Init;

		PROCEDURE HandleAutoRefreshBtn(sender, data : ANY);
		BEGIN
			IF autoRefresh THEN
				autoRefresh := FALSE;
			ELSE
				autoRefresh := TRUE;
				ModelChanged(NIL, NIL);
			END;
		END HandleAutoRefreshBtn;

		PROCEDURE EditorKeyEvent(ucs : LONGINT; flags : SET; VAR keySym : LONGINT; VAR handled : BOOLEAN);
		BEGIN
			IF (keySym = Inputs.KsReturn) & (Inputs.Shift * flags # {}) THEN
				HandleShiftReturn;
				handled := TRUE;
			ELSIF (keySym = Inputs.KsEscape) THEN
				ModelChanged(NIL, NIL);
				handled := TRUE;
			ELSE
				editor.KeyPressed(ucs, flags, keySym, handled);
			END;
		END EditorKeyEvent;

		PROCEDURE HandleShiftReturn;
		VAR model : Models.Model; string : Types.DynamicString; length, res : LONGINT;
		BEGIN
			model := SELF.model;
			IF (model # NIL) THEN
				string := Types.NewString();
				editor.text.AcquireRead;
				length := editor.text.GetLength();
				Types.EnsureLength(string, 5*length); (* UTF8 uses at most 5 bytes for encoding Unicode characters *)
				editor.GetAsString(string.value^);
				editor.text.ReleaseRead;
				model.SetGeneric(string, res);
			ELSE
				editor.SetAsString("");
			END;
		END HandleShiftReturn;

		PROCEDURE SetModel*(model : Models.Model);
		VAR string : Types.DynamicString; res : LONGINT;
		BEGIN
			Acquire;
			IF (SELF.model # NIL) THEN SELF.model.onChanged.Remove(ModelChanged); END;
			SELF.model := model;
			IF (SELF.model # NIL) THEN
				SELF.model.onChanged.Add(ModelChanged);
				typeLabel.caption.Set(GetModelTypeString(SELF.model));

				IF model IS Models.Text THEN
					editor.SetText(model(Models.Text).Get());
				ELSE
					string := Types.NewString();
					SELF.model.GetGeneric(string, res);
					IF (res = Types.Ok) THEN
						editor.SetAsString(string.value^);
					ELSE
						editor.SetAsString("<ERROR>");
					END;
				END;
			ELSE
				typeLabel.caption.Set(StrNoCaption);
				editor.SetAsString("");
			END;
			Release;
			Invalidate;
		END SetModel;

		PROCEDURE ModelChanged(sender, data : ANY);
		VAR model : Models.Model; string : Types.String256; res : LONGINT;
		BEGIN
			IF autoRefresh THEN
				model := SELF.model;
				IF (model # NIL) THEN
					model.GetGeneric(string, res);
					IF (res = Types.Ok) THEN
						editor.SetAsString(string.value);
					ELSE
						editor.SetAsString("[ERROR]");
					END;
				ELSE
					editor.SetAsString("");
				END;
			END;
		END ModelChanged;

		PROCEDURE Finalize;
		BEGIN
			Finalize^;
			IF (model # NIL) THEN model.onChanged.Remove(ModelChanged); END;
		END Finalize;

	END ModelView;

TYPE

	KillerMsg = OBJECT END KillerMsg;

	Window* = OBJECT(WMComponents.FormWindow)

		PROCEDURE &New*(vc : WMComponents.VisualComponent);
		BEGIN
			ASSERT((vc # NIL) & (vc.bounds.GetWidth() > 0) & (vc.bounds.GetHeight() > 0));
			Init(vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE);
			vc.alignment.Set(WMComponents.AlignClient);
			SetTitle(StrWindowTitle);
			SetContent(vc);
			IncCount;
			WMWindowManager.DefaultAddWindow(SELF);
		END New;

		PROCEDURE Close;
		BEGIN
			Close^;
			DecCount
		END Close;

		PROCEDURE Handle(VAR x : WMMessages.Message);
		BEGIN
			IF (x.msgType = WMMessages.MsgExt) & (x.ext # NIL) & (x.ext IS KillerMsg) THEN Close;
			ELSE Handle^(x)
			END
		END Handle;

	END Window;

VAR
	nofWindows : LONGINT;

	StrNotAvailable, StrNoCaption, StrType,
	StrComponentInfo, StrStandardProperties, StrExtendedProperties, StrExtendedPropertiesView, StrEventListeners, StrEventSources,
	StrBooleanPropertyView, StrInt32PropertyView, StrRealPropertyView, StrRectanglePropertyView, StrPointPropertyView,
	StrStringPropertyView,
	StrColorPropertyView, StrEventSourceView, StrEventListenerView, StrUnknownPropertyView,
	StrFontPropertyView, StrReferencePropertyView, StrAlignmentPropertyView, StrModelView : Strings.String;
	StrBoolean, StrInteger, StrBoundedInteger, StrReal, StrLongreal, StrChar,
	StrString, StrSet, StrText, StrContainer, StrCustom, StrNil : Strings.String;
	StrWindowTitle : Strings.String;

PROCEDURE GetModelTypeString(model : Models.Model) : Strings.String;
VAR string : Strings.String;
BEGIN
	IF (model = NIL) THEN string := StrNil;
	ELSIF (model IS Models.Boolean) THEN string := StrBoolean;
	ELSIF (model IS Models.Integer) THEN string := StrInteger;
	ELSIF (model IS Models.Real) THEN string := StrReal;
	ELSIF (model IS Models.Longreal) THEN string := StrLongreal;
	ELSIF (model IS Models.Char) THEN string := StrChar;
	ELSIF (model IS Models.String) THEN string := StrString;
	ELSIF (model IS Models.Set) THEN string := StrSet;
	ELSIF (model IS Models.Text) THEN string := StrText;
	ELSIF (model IS Models.Container) THEN string := StrContainer;
	ELSE string := StrCustom;
	END;
	ASSERT(string # NIL);
	RETURN string;
END GetModelTypeString;

PROCEDURE IsComponentProperty(property : WMProperties.Property) : BOOLEAN;
VAR name : Strings.String;
BEGIN
	ASSERT(property # NIL);
	name := property.GetName();
	RETURN (name # NIL) & (
		((name^ = "ID") & (property IS WMProperties.StringProperty)) OR
		((name^ = "UID") & (property IS WMProperties.StringProperty)) OR
		((name^ = "Enabled") & (property IS WMProperties.BooleanProperty))
	);
END IsComponentProperty;

PROCEDURE IsVisualComponentProperty(property : WMProperties.Property) : BOOLEAN;
VAR name : Strings.String;
BEGIN
	ASSERT(property # NIL);
	name := property.GetName();
	RETURN (name # NIL) & (
		((name^ = "Bounds") & (property IS WMProperties.RectangleProperty)) OR
		((name^ = "Bearing") & (property IS WMProperties.RectangleProperty)) OR
		((name ^ = "Alignment") & (property IS WMProperties.Int32Property)) OR
		((name^ = "FillColor") & (property IS WMProperties.ColorProperty)) OR
		((name^ = "Visible") & (property IS WMProperties.BooleanProperty)) OR
		((name^ = "TakesFocus") & (property IS WMProperties.BooleanProperty)) OR
		((name^ = "NeedsTab") & (property IS WMProperties.BooleanProperty)) OR
		((name^ = "FocusNext") & (property IS WMProperties.StringProperty)) OR
		((name^ = "FocusPrevious") & (property IS WMProperties.StringProperty)) OR
		((name^ = "EditMode") & (property IS WMProperties.BooleanProperty))
	);
END IsVisualComponentProperty;

PROCEDURE CountExtendedProperties(component : WMComponents.Component) : LONGINT;
VAR propertyArray : WMProperties.PropertyArray; nofElements, i : LONGINT;
BEGIN
	nofElements := 0;
	IF (component # NIL) THEN
		propertyArray := component.properties.Enumerate();
		IF (propertyArray # NIL) THEN
			FOR i := 0 TO LEN(propertyArray) - 1 DO
				IF ~IsComponentProperty(propertyArray[i]) & ~IsVisualComponentProperty(propertyArray[i]) THEN
					INC(nofElements);
				END;
			END;
		END;
	END;
	RETURN nofElements;
END CountExtendedProperties;

PROCEDURE CreateLine*() : WMStandardComponents.Panel;
VAR panel : WMStandardComponents.Panel;
BEGIN
	NEW(panel); panel.alignment.Set(WMComponents.AlignTop);
	panel.bounds.SetHeight(LineHeight);
	panel.bearing.Set(WMRectangles.MakeRect(LineBearing, LineBearing, LineBearing, LineBearing));
	RETURN panel;
END CreateLine;

PROCEDURE CreateLabel*(CONST caption : ARRAY OF CHAR; width, alignment : LONGINT) : WMStandardComponents.Label;
VAR label : WMStandardComponents.Label;
BEGIN
	NEW(label); label.alignment.Set(WMComponents.AlignLeft);
	label.caption.SetAOC(caption);
	label.bounds.SetWidth(width);
	label.alignH.Set(alignment);
	RETURN label;
END CreateLabel;

PROCEDURE CreateEditor*(width : LONGINT) : WMEditors.TextField;
VAR editor : WMEditors.TextField;
BEGIN
	NEW(editor); editor.alignment.Set(WMComponents.AlignLeft);
	editor.bounds.SetWidth(width);
	RETURN editor;
END CreateEditor;

PROCEDURE GetPropertyType(property : WMProperties.Property; VAR string : ARRAY OF CHAR);
BEGIN
	ASSERT(property # NIL);
	IF (property IS WMProperties	.BooleanProperty) THEN string := "Boolean";
	ELSIF (property IS WMProperties.Int32Property) THEN string := "Integer";
	ELSIF (property IS WMProperties.StringProperty) THEN string := "String";
	ELSIF (property IS WMProperties.RectangleProperty) THEN string := "Rectangle";
	ELSIF (property IS WMProperties.PointProperty) THEN string := "Point";
	ELSIF (property IS WMProperties.ColorProperty) THEN string := "Color";
	ELSE
		string := "Other";
	END;
END GetPropertyType;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows)
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows)
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WMWindowManager.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die);
	msg.ext := die;
	msg.msgType := WMMessages.MsgExt;
	m := WMWindowManager.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0)
END Cleanup;

PROCEDURE InitStrings;
BEGIN
	StrNoCaption := Strings.NewString("");
	StrNotAvailable := Strings.NewString("<n/a>");
	StrType := Strings.NewString("Type : ");
	StrComponentInfo := Strings.NewString("ComponentInfo");
	StrStandardProperties := Strings.NewString("StandardProperties");
	StrExtendedProperties := Strings.NewString("ExtendedProperties");
	StrExtendedPropertiesView := Strings.NewString("ExtendedPropertiesView");
	StrEventListeners := Strings.NewString("EventListeners");
	StrEventSources := Strings.NewString("EventSources");
	StrBooleanPropertyView := Strings.NewString("BooleanPropertyView");
	StrInt32PropertyView := Strings.NewString("Int32PropertyView");
	StrRealPropertyView := Strings.NewString("RealPropertyView");
	StrRectanglePropertyView := Strings.NewString("RectanglePropertyView");
	StrPointPropertyView := Strings.NewString("PointPropertyView");
	StrStringPropertyView := Strings.NewString("StringPropertyView");
	StrColorPropertyView := Strings.NewString("ColorPropertyView");
	StrFontPropertyView := Strings.NewString("FontPropertyView");
	StrEventSourceView := Strings.NewString("EventSourceView");
	StrEventListenerView := Strings.NewString("EventListenerView");
	StrUnknownPropertyView := Strings.NewString("UnknownPropertyView");
	StrReferencePropertyView := Strings.NewString("ReferencePropertyView");
	StrAlignmentPropertyView := Strings.NewString("AlignmentPropertyView");
	StrModelView := Strings.NewString("ModelView");
	StrBoolean := Strings.NewString("Boolean");
	StrInteger := Strings.NewString("Integer");
	StrBoundedInteger := Strings.NewString("Bounded Integer");
	StrReal := Strings.NewString("Real");
	StrLongreal := Strings.NewString("Longreal");
	StrChar := Strings.NewString("Char");
	StrString := Strings.NewString("String");
	StrSet := Strings.NewString("Set");
	StrText := Strings.NewString("Text");
	StrContainer := Strings.NewString("Container");
	StrCustom := Strings.NewString("Userdefined");
	StrNil := Strings.NewString("NIL");
	StrWindowTitle := Strings.NewString("Reference");
END InitStrings;

BEGIN
	nofWindows := 0;
	InitStrings;
	Modules.InstallTermHandler(Cleanup);
END WMInspectionComponents.

SystemTools.FreeDownTo WMInspectionComponents ~


