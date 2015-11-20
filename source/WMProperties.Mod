MODULE WMProperties; (** AUTHOR "TF"; PURPOSE "Properties" *)

IMPORT
	WMRectangles, WMGraphics, Strings, Localization, Repositories, WMEvents, Locks, XML, XMLObjects, Streams, Commands, Modules, KernelLog, Models, Types;

TYPE
	String = Strings.String;

	Property* = OBJECT
	VAR
		name, info : String;
		prototype : Property;
		nonDefault : BOOLEAN;
		list : PropertyList; (* contains the list, the property is added to *)
		timestamp : LONGINT; (* incremented when property state is changed; *)
		repository: Repositories.Repository;

		object : Repositories.Component;

		repositoryName : Strings.String;
		componentName : Strings.String;
		generator : Strings.String;
		componentID : LONGINT;

		inLinkUpdate: BOOLEAN;

		PROCEDURE &New*(prototype : Property; name, info : String);
		BEGIN
			SELF.name := name;
			SELF.info := info;
			SELF.prototype := prototype;
			nonDefault := FALSE;
			list := NIL;
			timestamp := 0;
		END New;

		PROCEDURE ReplaceLink*(object: Repositories.Component);
		BEGIN
			IF SELF.object # object THEN
				IF (SELF.object # NIL) THEN SELF.object.onChanged.Remove(LinkChanged) END;
				SELF.object := object;
				IF object # NIL THEN object.onChanged.Add(LinkChanged); LinkChanged(SELF, object)  END;
			END;
		END ReplaceLink;

		PROCEDURE LinkChanged(sender, object: ANY);
		BEGIN
			AcquireWrite;
			inLinkUpdate := TRUE;
			UpdateProperty;
			inLinkUpdate := FALSE;
			ReleaseWrite;
		END LinkChanged;

		PROCEDURE SetLinkAsString*(CONST string : ARRAY OF CHAR);
		VAR repositoryName : ARRAY 256 OF CHAR; componentName : ARRAY 128 OF CHAR; componentID : LONGINT;
		context : Repositories.Context; res : LONGINT; object: Repositories.Component;
		BEGIN
			IF Repositories.IsCommandString(string) THEN
				AcquireWrite;
				SELF.repositoryName := NIL;
				SELF.componentName := NIL;
				SELF.componentID := 0;
				SELF.generator := Strings.NewString(string);
				ReplaceLink(NIL);
				NotDefault;
				Changed;
				ReleaseWrite;
			ELSIF Repositories.SplitName(string, repositoryName, componentName, componentID) THEN
				AcquireWrite;
				IF repositoryName # "" THEN
					SELF.repositoryName := Strings.NewString(repositoryName);
				ELSE (*ASSERT(repository # NIL);*)
				END;
				SELF.componentName := Strings.NewString(componentName);
				SELF.componentID := componentID;
				SELF.generator := NIL;
				ReplaceLink(NIL); (* invalidate reference *)
				NotDefault;
				Changed;
				ReleaseWrite;
			ELSE
				Reset;
			END;
		END SetLinkAsString;

		PROCEDURE GetLinkAsString*(VAR string : ARRAY OF CHAR);
		VAR nbrStr : ARRAY 16 OF CHAR;
		BEGIN
			AcquireRead;
			IF (SELF.generator # NIL) THEN
				COPY(SELF.generator^, string);
			ELSIF (repositoryName # NIL) & (componentName # NIL) THEN
				COPY(repositoryName^, string); Strings.Append(string, Repositories.Delimiter);
				Strings.Append(string, componentName^); Strings.Append(string, Repositories.Delimiter);
				Strings.IntToStr(componentID, nbrStr); Strings.Append(string, nbrStr);
			ELSE
				string := "";
			END;
			ReleaseRead;
		END GetLinkAsString;

		PROCEDURE IsLink(p: ANY): BOOLEAN;
		VAR s:Strings.String; xml: XML.Element; en:XMLObjects.Enumerator;
		BEGIN
			IF (p IS XML.Element) THEN
				xml := p(XML.Element);
				s := xml.GetName();
				IF s # NIL THEN
					IF s^ = "Object" THEN
						en := xml.GetContents();
						p := en.GetNext();
						NotDefault;
						IF (p # NIL ) & (p IS XML.Chars) THEN
							s := p(XML.Chars).GetStr();
							IF s # NIL THEN
								Strings.Trim(s^, " ");
								SetLinkAsString(s^);
								object := GetLink();
								RETURN TRUE
							END
						ELSIF (p # NIL) & (p IS XML.Element) THEN
							ReplaceLink( Repositories.ComponentFromXML(p(XML.Element)));
							object := GetLink();
							RETURN TRUE
						END
					END;
				END;
			END;
			RETURN FALSE
		END IsLink;

		PROCEDURE WriteLink*(w : Streams.Writer; context: ANY;  indent : LONGINT): BOOLEAN;
		VAR name : String; id,res: LONGINT; repository: Repositories.Repository; objectName: String;
		BEGIN
			IF object # NIL THEN
				Indent(w, indent);
				(*level := indent+1;*)
				w.Char("<"); w.String("Object"); w.Char(">");
				IF (context # NIL) & (context IS Repositories.StoreContext) THEN
					repository := context(Repositories.StoreContext).repository;
					id := 1;
					objectName := object.GetName();
					IF (objectName=NIL) OR (objectName^="") THEN objectName :=anonymous END;
					repository.PutComponent(object, objectName^,id,res);
					w.String(":"); (* <-- THIS repository *) w.String(objectName^); w.String(":"); w.Int(id, 0);
				ELSE
					ToStream(w);
				END;
				w.String("</"); w.String("Object"); w.Char(">"); w.Ln;
				RETURN TRUE
			END;
			RETURN FALSE;
		END WriteLink;

		PROCEDURE UpdateModel;
		BEGIN
		END UpdateModel;

		PROCEDURE UpdateProperty;
		BEGIN
		END UpdateProperty;

		PROCEDURE SetLink*(object : Repositories.Component);
		BEGIN
			AcquireWrite; (* TBD: Store object to repository *)
			IF (SELF.object # object) THEN ReplaceLink(object); Changed
			ELSIF ~ nonDefault THEN Changed END;
			NotDefault;
			ReleaseWrite;
		END SetLink;

		PROCEDURE GetLink*() : Repositories.Component;
		VAR object : Repositories.Component; context : Repositories.Context; res : LONGINT;
		BEGIN
			AcquireRead;
			object := SELF.object;
			ReleaseRead;
			(* late time generation of object for supporting of loading repositories *)
			IF (object = NIL) THEN
				IF (generator # NIL) THEN
					Repositories.CallCommand(generator^, context, res);
					IF (res = Repositories.Ok) & (context.object # NIL) & (context.object IS Repositories.Component) THEN
						object := context.object(Repositories.Component);
						SetLink(object)
					END;
				ELSIF (repositoryName # NIL) & (componentName # NIL) THEN
					Repositories.GetComponent(repositoryName^, componentName^, componentID, object, res);
					SetLink(object);
				ELSIF (componentName # NIL) & (repository # NIL) THEN
					object := repository.GetComponent(componentName^, componentID);
					SetLink(object);
				END;
			END;
			RETURN object
		END GetLink;



		PROCEDURE SetPrototype*(prototype : Property);
		BEGIN
			SELF.prototype := prototype;
			Stamp;
		END SetPrototype;

		PROCEDURE HasPrototype*() : BOOLEAN;
		BEGIN
			RETURN prototype # NIL
		END HasPrototype;

		(** Meta-data *)
		PROCEDURE GetInfo*() : String;
		BEGIN
			IF info # NIL THEN RETURN info
			ELSIF prototype # NIL THEN RETURN prototype.GetInfo()
			ELSE RETURN NIL
			END
		END GetInfo;

		PROCEDURE GetName*() : String;
		BEGIN
			IF name # NIL THEN RETURN name
			ELSIF prototype # NIL THEN RETURN prototype.GetName()
			ELSE RETURN NIL
			END
		END GetName;

		PROCEDURE Stamp*;
		BEGIN (* need protection? *)
			INC(timestamp)
		END Stamp;
		
		PROCEDURE GetTimestamp*() : LONGINT;
		BEGIN
			RETURN timestamp;
		END GetTimestamp;

		PROCEDURE Reset*;
		BEGIN
			AcquireWrite;
			IF nonDefault THEN nonDefault := FALSE; Changed END;
			ReleaseWrite
		END Reset;

		PROCEDURE Changed*; (** PROTECTED *)
		BEGIN
			IF list # NIL THEN list.Changed(SELF) END;
			Stamp;
		END Changed;

		PROCEDURE AcquireWrite*;
		BEGIN
			IF list # NIL THEN list.AcquireWrite END
		END AcquireWrite;

		PROCEDURE ReleaseWrite*;
		BEGIN
			IF list # NIL THEN list.ReleaseWrite END
		END ReleaseWrite;

		PROCEDURE AcquireRead*;
		BEGIN
			IF list # NIL THEN list.AcquireRead END
		END AcquireRead;

		PROCEDURE ReleaseRead*;
		BEGIN
			IF list # NIL THEN list.ReleaseRead END
		END ReleaseRead;

		PROCEDURE NotDefault*; (** PROTECTED *)
		BEGIN
			IF (nonDefault = FALSE) THEN
				nonDefault := TRUE;
				Stamp;
			END;
		END NotDefault;

		PROCEDURE GetIsDefault*() :  BOOLEAN;
		BEGIN
			RETURN ~nonDefault
		END GetIsDefault;

		PROCEDURE FromStream*(r : Streams.Reader); (** ABSTRACT *)
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer); (** ABSTRACT *)
		END ToStream;

		PROCEDURE FromXML*(xml : XML.Element);
		END FromXML;

		PROCEDURE ToXML*(VAR element: XML.Element);
		VAR name: String;
		BEGIN
			name := GetName();
			NEW(element); IF name # NIL THEN element.SetName(name^); END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		END WriteXML;

		PROCEDURE Finalize*;
		BEGIN
		END Finalize;

	END Property;

TYPE

	BooleanProperty* = OBJECT(Property)
	VAR
		value : BOOLEAN;

		PROCEDURE FromStream*(r : Streams.Reader);
		VAR token : ARRAY 5 OF CHAR; v : BOOLEAN;
		BEGIN
			AcquireWrite;
			NotDefault;
			r.Token(token); Strings.UpperCase(token); v := token = "TRUE";
			IF v # value THEN value := v; Changed END;
			ReleaseWrite
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer);
		BEGIN
			AcquireRead;
			IF Get() THEN w.String("true") ELSE w.String("false") END;
			ReleaseRead
		END ToStream;

		PROCEDURE UpdateProperty;
		VAR boolean: Types.Boolean; model: Models.Model; res: LONGINT;
		BEGIN
			IF GetModel(object, model) THEN
				 model.GetGeneric(boolean, res);
				 IF res = 0 THEN Set(boolean.value) END;
			END;
		END UpdateProperty;

		PROCEDURE UpdateModel;
		VAR type: Types.Boolean; model: Models.Model; res: LONGINT;
		BEGIN
			IF inLinkUpdate THEN RETURN END;
			IF GetModel(object, model) THEN
				type.value := value;
				model.SetGeneric(type, res);

			END;
		END UpdateModel;


		PROCEDURE Get*() : BOOLEAN;
		VAR r : BOOLEAN;
		BEGIN
			AcquireRead;
			IF nonDefault OR (prototype = NIL) THEN r := value
			ELSE r := prototype(BooleanProperty).Get()
			END;
			ReleaseRead;
			RETURN r
		END Get;

		PROCEDURE Set*(value : BOOLEAN);
		BEGIN
			AcquireWrite;
			IF value # SELF.value THEN SELF.value := value; Changed;
				IF (object # NIL) THEN UpdateModel END;
			ELSIF ~ nonDefault THEN Changed END;
			NotDefault;
			ReleaseWrite;
		END Set;

		PROCEDURE FromXML*(xml : XML.Element);
		VAR en : XMLObjects.Enumerator; p : ANY; s : String;
		BEGIN
			en := xml.GetContents();
			p := en.GetNext();
			value := FALSE; NotDefault;
			IF IsLink(p) THEN
			ELSIF p IS XML.Chars THEN
				s := p(XML.Chars).GetStr();
				IF s # NIL THEN
					Strings.Trim(s^, " "); Strings.LowerCase(s^);
					Set(s^ = "true")
				END
			END;
		END FromXML;

		PROCEDURE ToXML(VAR element: XML.Element);
		VAR chars: XML.ArrayChars; s: String;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewBoolean");
				NEW(chars); element.AddContent(chars);
				IF Get() THEN chars.SetStr("true") ELSE chars.SetStr("false") END;
				s := GetName();
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		VAR name : String;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("Nameless boolean property encountered. Ignored"); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				Indent(w, indent);
				w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewBoolean"'); w.Char(">");
				IF ~WriteLink(w,context,indent) THEN
					IF value THEN w.String("true") ELSE w.String("false") END;
				END;
				w.String("</"); w.String(name^); w.Char(">"); w.Ln;
			END
		END WriteXML;

	END BooleanProperty;


TYPE

	SetProperty* = OBJECT(Property)
	VAR
		value : SET;

		PROCEDURE IntToSet(h:LONGINT):SET;
		VAR i:LONGINT; set:SET;
		BEGIN
			i:=0;
			WHILE h#0 DO
				IF h MOD 2=1 THEN INCL(set,i) END;
				h:=h DIV 2;
				INC(i);
			END;
			RETURN set;
		END IntToSet;

		PROCEDURE SetToInt(set:SET):HUGEINT;
		VAR i:LONGINT; int:HUGEINT; s: String;
		BEGIN
			NEW(s, 18);
			FOR i:=31 TO 0 BY -1 DO
				int:=int * 2;
				IF i IN set THEN INC(int) END;
			END;
			RETURN int
		END SetToInt;

		PROCEDURE FromStream*(r : Streams.Reader);
		VAR token : ARRAY 10 OF CHAR; v : SET; i:LONGINT; res: LONGINT;
		BEGIN
			AcquireWrite;
			NotDefault;
			r.String(token); Strings.HexStrToInt(token,i,res);
			IF res=Strings.Ok THEN
				v:=IntToSet(i);
				IF v # value THEN value := v; Changed END;
			END;
			ReleaseWrite
		END FromStream;


(*! to discuss: should a SET be written explicitely ? readability  vs overhead*)
		PROCEDURE ToStream*(w : Streams.Writer);
		VAR s:ARRAY 10 OF CHAR;
		BEGIN
			AcquireRead;
			Strings.IntToHexStr(SetToInt(Get()),8,s);
			Strings.AppendChar(s,"H");
			w.String(s);
			ReleaseRead
		END ToStream;

		PROCEDURE UpdateProperty;
		VAR boolean: Types.Set; model: Models.Model; res: LONGINT;
		BEGIN
			IF GetModel(object, model) THEN
				 model.GetGeneric(boolean, res);
				 IF res = 0 THEN Set(boolean.value) END;
			END;
		END UpdateProperty;

		PROCEDURE UpdateModel;
		VAR type: Types.Set; model: Models.Model; res: LONGINT;
		BEGIN
			IF inLinkUpdate THEN RETURN END;
			IF GetModel(object, model) THEN
				type.value := value;
				model.SetGeneric(type, res);
			END;
		END UpdateModel;

		PROCEDURE Get*() : SET;
		VAR r : SET;
		BEGIN
			AcquireRead;
			IF nonDefault OR (prototype = NIL) THEN r := value
			ELSE r := prototype(SetProperty).Get()
			END;
			ReleaseRead;
			RETURN r
		END Get;

		PROCEDURE Set*(value : SET);
		BEGIN
			AcquireWrite;
			IF value # SELF.value THEN
				SELF.value := value;
				IF (object # NIL) THEN UpdateModel END;
				Changed
			ELSIF ~ nonDefault THEN Changed END;
			NotDefault;
			ReleaseWrite;
		END Set;

(*! to discuss: should a SET be written explicitely - readability at cost of overhead*)
		PROCEDURE FromXML*(xml : XML.Element);
		VAR en : XMLObjects.Enumerator; p : ANY; s : String; i:LONGINT;
		BEGIN
			en := xml.GetContents();
			p := en.GetNext();
			NotDefault;
			IF IsLink(p) THEN
			ELSIF p IS XML.Chars THEN
				s := p(XML.Chars).GetStr();
				IF s # NIL THEN
					Strings.Trim(s^, " ");
					Strings.StrToInt(s^,i);
					Set(IntToSet(i))
				END
			END
		END FromXML;

		PROCEDURE ToXML(VAR element: XML.Element);
		VAR chars: XML.ArrayChars;s: ARRAY 10 OF CHAR;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewSet");
				NEW(chars); element.AddContent(chars);
				Strings.IntToHexStr(SetToInt(value),8,s); Strings.AppendChar(s,"H");
				chars.SetStr(s);
			END;
		END ToXML;


		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		VAR name : String; s: ARRAY 10 OF CHAR;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("Nameless boolean property encountered. Ignored"); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				Indent(w, indent);
				w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewSet"'); w.Char(">");
				IF ~WriteLink(w,context,indent) THEN
					Strings.IntToHexStr(SetToInt(value),8,s); Strings.AppendChar(s,"H");
					w.String(s);
				END;
				w.String("</"); w.String(name^); w.Char(">"); w.Ln;
			END
		END WriteXML;

	END SetProperty;


TYPE
	(** Accessor property to an integer value. The range of possible values can be restricted. *)
	Int32Property* = OBJECT(Property)
	VAR
		value : LONGINT;
		min, max : LONGINT;
		bounded, silent : BOOLEAN;

		PROCEDURE UpdateProperty;
		VAR integer: Types.Integer; model: Models.Model; res: LONGINT;
		BEGIN
			IF GetModel(object, model) THEN
				 model.GetGeneric(integer, res);
				 IF res = 0 THEN Set(integer.value) END;
			END;
		END UpdateProperty;

		PROCEDURE UpdateModel;
		VAR type: Types.Integer; model: Models.Model; res: LONGINT;
		BEGIN
			IF inLinkUpdate THEN RETURN END;
			IF GetModel(object, model) THEN
				type.value := value;
				model.SetGeneric(type, res);
			END;
		END UpdateModel;

		(** Confines the possible input values between min and max. Implicitly activates the bounds check. If the current value
			lies outside the bounds, it is truncated to the nearest and a change notification is sent after the end of the transaction. *)
		PROCEDURE SetBounds*(min, max : LONGINT);
		BEGIN
			AcquireWrite;
			SELF.min := min; SELF.max := max; bounded := TRUE;
			Stamp;
			Set(value);
			ReleaseWrite
		END SetBounds;

		PROCEDURE GetBounds*(VAR min, max : LONGINT);
		BEGIN
			AcquireRead;
			min := SELF.min; max := SELF.max;
			ReleaseRead;
		END GetBounds;

		(** enables or disables the bounds of the value. If enabled, a change notification is sent if the current value had to be
			changed to lie within the bounds *)
		PROCEDURE SetIsBounded*(isBounded : BOOLEAN);
		BEGIN
			AcquireWrite;
			IF isBounded # bounded THEN
				bounded := isBounded;
				Stamp;
				Set(value);
			END;
			ReleaseWrite
		END SetIsBounded;

		PROCEDURE GetIsBounded*(VAR isBounded : BOOLEAN);
		BEGIN
			AcquireRead;
			isBounded := bounded;
			ReleaseRead;
		END GetIsBounded;

		PROCEDURE SetSilent*(isSilent : BOOLEAN);
		BEGIN
			AcquireWrite;
			IF isSilent # silent THEN
				silent := isSilent;
				Stamp;
			END;
			ReleaseWrite
		END SetSilent;

		PROCEDURE GetSilent*(VAR isSilent : BOOLEAN);
		BEGIN
			AcquireRead;
			isSilent := silent;
			ReleaseRead;
		END GetSilent;

		PROCEDURE Validate(v : LONGINT) : LONGINT;
		BEGIN
			IF bounded THEN RETURN Strings.Max(min, Strings.Min(max, v))
			ELSE RETURN v
			END
		END Validate;

		PROCEDURE FromStream*(r : Streams.Reader);
		VAR v : LONGINT;
		BEGIN
			AcquireWrite;
			r.Int(v, TRUE);
			Set(v);
			ReleaseWrite
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer);
		BEGIN
			AcquireRead;
			w.Int(value, 0);
			ReleaseRead
		END ToStream;

		PROCEDURE Get*() : LONGINT;
		VAR r : LONGINT;
		BEGIN
			AcquireRead;
			IF nonDefault OR (prototype = NIL) THEN r := value
			ELSE r := prototype(Int32Property).Get()
			END;
			ReleaseRead;
			RETURN r
		END Get;

		PROCEDURE Set*(value : LONGINT);
		BEGIN
			AcquireWrite;
			IF Validate(value) # SELF.value THEN
				SELF.value := Validate(value);
				IF ~silent THEN
					Changed;
					IF object # NIL THEN UpdateModel END;
				END
			ELSIF ~nonDefault & ~silent THEN
				Changed;
			END;
			NotDefault;
			ReleaseWrite
		END Set;



		PROCEDURE FromXML*(xml : XML.Element);
		VAR
			en : XMLObjects.Enumerator;
			p : ANY;
			s, mins, maxs : String;
		BEGIN
			AcquireWrite; NotDefault;
			mins := xml.GetAttributeValue("min");
			maxs := xml.GetAttributeValue("max");
			IF mins # NIL THEN Strings.StrToInt(mins^, min) ELSE min := MIN(LONGINT) END;
			IF maxs # NIL THEN Strings.StrToInt(maxs^, max) ELSE max := MAX(LONGINT) END;
			bounded := (mins # NIL) OR (maxs # NIL);
			en := xml.GetContents();
			IF en.HasMoreElements() THEN
				p := en.GetNext();
				IF IsLink(p) THEN
				ELSIF p IS XML.Chars THEN
					s := p(XML.Chars).GetStr();
					IF s # NIL THEN Strings.StrToInt(s^, value); Set(value) END
				END
			END;
			Stamp;
			ReleaseWrite
		END FromXML;

		PROCEDURE ToXML(VAR element: XML.Element);
		VAR chars: XML.ArrayChars;s: ARRAY 20 OF CHAR;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewInt32");
				element.AddContent(NewIntChars(value));
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY;  indent : LONGINT);
		VAR name : String;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("Nameless Int32 property encountered. Ignored"); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				Indent(w, indent);
				w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewInt32"'); w.Char(">");
				IF ~WriteLink(w,context,indent) THEN
					w.Int(value, 0);
				END;
				w.String("</"); w.String(name^); w.Char(">"); w.Ln
			END
		END WriteXML;

	END Int32Property;

TYPE

	(** Accessor property to an real value. The range of possible values can be restricted. *)
	RealProperty* = OBJECT(Property)
	VAR
		value : LONGREAL;
		min, max : LONGREAL;
		bounded, silent : BOOLEAN;

		(** Confines the possible input values between min and max. Implicitly activates the bounds check. If the current value
			lies outside the bounds, it is truncated to the nearest and a change notification is sent after the end of the transaction. *)
		PROCEDURE SetBounds*(min, max : LONGREAL);
		BEGIN
			AcquireWrite;
			SELF.min := min; SELF.max := max; bounded := TRUE;
			Stamp;
			Set(value);
			ReleaseWrite
		END SetBounds;

		PROCEDURE GetBounds*(VAR min, max : LONGREAL);
		BEGIN
			AcquireRead;
			min := SELF.min; max := SELF.max;
			ReleaseRead;
		END GetBounds;

		(** enables or disables the bounds of the value. If enabled, a change notification is sent if the current value had to be
			changed to lie within the bounds *)
		PROCEDURE SetIsBounded*(isBounded : BOOLEAN);
		BEGIN
			AcquireWrite;
			IF isBounded # bounded THEN
				bounded := isBounded;
				Stamp;
				Set(value);
			END;
			ReleaseWrite
		END SetIsBounded;

		PROCEDURE GetIsBounded*(VAR isBounded : BOOLEAN);
		BEGIN
			AcquireRead;
			isBounded := bounded;
			ReleaseRead;
		END GetIsBounded;

		PROCEDURE SetSilent*(isSilent : BOOLEAN);
		BEGIN
			AcquireWrite;
			IF isSilent # silent THEN
				silent := isSilent;
				Stamp;
			END;
			ReleaseWrite
		END SetSilent;

		PROCEDURE GetSilent*(VAR isSilent : BOOLEAN);
		BEGIN
			AcquireRead;
			isSilent := silent;
			ReleaseRead;
		END GetSilent;

		PROCEDURE Validate(v : LONGREAL) : LONGREAL;
		VAR result : LONGREAL;
		BEGIN
			result := v;
			IF bounded THEN
				IF (result < min) THEN result := min; ELSIF (result > max) THEN result := max; END;
			END;
			RETURN result;
		END Validate;

		PROCEDURE FromStream*(r : Streams.Reader);
		VAR temp : ARRAY 64 OF CHAR; value : LONGREAL;
		BEGIN
			r.String(temp);
			value := 0.0;
			Strings.StrToFloat(temp, value);
			Set(value);
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer);
		BEGIN
			AcquireRead;
			w.Float(value, 24);
			ReleaseRead
		END ToStream;

		PROCEDURE UpdateProperty;
		VAR boolean: Types.Longreal; model: Models.Model; res: LONGINT;
		BEGIN
			IF GetModel(object, model) THEN
				 model.GetGeneric(boolean, res);
				 IF res = 0 THEN Set(boolean.value) END;
			END;
		END UpdateProperty;

		PROCEDURE UpdateModel;
		VAR type: Types.Longreal; model: Models.Model; res: LONGINT;
		BEGIN
			IF inLinkUpdate THEN RETURN END;
			IF GetModel(object, model) THEN
				type.value := value;
				model.SetGeneric(type, res);
			END;
		END UpdateModel;

		PROCEDURE Get*() : LONGREAL;
		VAR r : LONGREAL;
		BEGIN
			AcquireRead;
			IF nonDefault OR (prototype = NIL) THEN r := value;
			ELSE r := prototype(RealProperty).Get();
			END;
			ReleaseRead;
			RETURN r
		END Get;

		PROCEDURE Set*(value : LONGREAL);
		BEGIN
			AcquireWrite;
			IF Validate(value) # SELF.value THEN
				SELF.value := Validate(value);
				IF ~silent THEN Changed
				END;
				IF (object # NIL) THEN UpdateModel END;
			ELSIF ~nonDefault & ~silent THEN
				Changed
			END;
			NotDefault;
			ReleaseWrite
		END Set;

		PROCEDURE FromXML*(xml : XML.Element);
		VAR
			en : XMLObjects.Enumerator;
			p : ANY;
			s, mins, maxs : String;
		BEGIN
			AcquireWrite; NotDefault;
			mins := xml.GetAttributeValue("min");
			maxs := xml.GetAttributeValue("max");
			IF mins # NIL THEN Strings.StrToFloat(mins^, min) ELSE min := MIN(LONGREAL) END;
			IF maxs # NIL THEN Strings.StrToFloat(maxs^, max) ELSE max := MAX(LONGREAL) END;
			bounded := (mins # NIL) OR (maxs # NIL);
			en := xml.GetContents();
			IF en.HasMoreElements() THEN
				p := en.GetNext();
					IF IsLink(p) THEN
					ELSIF p IS XML.Chars THEN
					s := p(XML.Chars).GetStr();
					IF s # NIL THEN Strings.StrToFloat(s^, value); Set(value) END
				END
			END;
			Stamp;
			ReleaseWrite
		END FromXML;

		PROCEDURE ToXML(VAR element: XML.Element);
		VAR chars: XML.ArrayChars;s: ARRAY 20 OF CHAR; w: Streams.StringWriter;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewReal");
				NEW(chars); element.AddContent(chars);
				NEW(w,30); w.Float(value,24); w.Get(s);
				chars.SetStr(s);
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		VAR name : String;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("Nameless Real property encountered. Ignored"); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				Indent(w, indent);
				w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewReal"'); w.Char(">");
				IF ~WriteLink(w,context,indent) THEN
					w.Float(value, 24);
				END;
				w.String("</"); w.String(name^); w.Char(">"); w.Ln
			END
		END WriteXML;

	END RealProperty;

TYPE

	StringProperty* = OBJECT(Property)
	VAR
		value, word : String;
		dictionary : Repositories.Dictionary;
		languages : Localization.Languages;
		translate : BOOLEAN;

		PROCEDURE &New*(prototype : Property; name, info : String);
		BEGIN
			New^(prototype, name, info);
			value := NIL; word := NIL;
			dictionary := NIL;
			languages := Localization.GetLanguagePreferences();
			translate := TRUE;
		END New;

		PROCEDURE SetTranslate*(translate : BOOLEAN);
		BEGIN
			AcquireWrite;
			IF (SELF.translate # translate) THEN
				SELF.translate := translate;
				IF ~translate THEN
					dictionary := NIL; word := NIL;
				ELSE
					Translate;
				END;
				NotDefault;
				Changed;
			END;
			ReleaseWrite;
		END SetTranslate;

		PROCEDURE Translate;
		VAR res : LONGINT; temp : Strings.String;
		BEGIN (* caller holds lock *)
			IF translate & (SELF.value # NIL) THEN
				Repositories.GetTranslationInfo(SELF.value^, dictionary, word, res);
				IF (dictionary # NIL) & (word # NIL) THEN
					temp := dictionary.Translate(word, languages);
					IF (temp # word) THEN
						value := temp;
					END;
				END;
			END;
		END Translate;

		PROCEDURE SetLanguage*(languages : Localization.Languages);
		BEGIN
			AcquireWrite;
			SELF.languages := languages;
			IF (dictionary # NIL) & (word # NIL) THEN
				value := dictionary.Translate(word, languages);
				NotDefault;
				Changed;
			END;
			ReleaseWrite;
		END SetLanguage;

		PROCEDURE FromStream*(r : Streams.Reader);
		VAR buffer : ARRAY 1024 OF CHAR; res : LONGINT;
		BEGIN
			AcquireWrite;
			XML.UTF8FromStream(buffer, r, res);
			value := Strings.NewString(buffer); Translate; NotDefault; Changed;
			ReleaseWrite
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer);
		BEGIN
			AcquireRead;
			IF (dictionary # NIL) & (word # NIL) THEN
				w.String("::"); w.String(dictionary.fullname^); w.String(":"); w.String(word^);
			ELSIF value # NIL THEN
				w.String(value^);
			END;
			ReleaseRead
		END ToStream;

		PROCEDURE Get*() : String;
		VAR r : String;
		BEGIN
			AcquireRead;
			IF nonDefault OR (prototype = NIL) THEN r := value
			ELSE r := prototype(StringProperty).Get()
			END;
			ReleaseRead;
			RETURN r
		END Get;

		PROCEDURE UpdateModel;
		VAR type: Types.String; model: Models.Model; res: LONGINT;
		BEGIN
			IF inLinkUpdate THEN RETURN END;
			IF GetModel(object, model) THEN
				type.value := value;
				model.SetGeneric(type, res);
			END;
		END UpdateModel;

		PROCEDURE Set*(value : String);
		BEGIN
			AcquireWrite;
				IF (value = SELF.value) (* reset with self must lead to update *) OR (value = NIL) OR (SELF.value = NIL) OR (value^ # SELF.value^) THEN
					SELF.value := value; Translate;Changed;
					IF (object # NIL) THEN UpdateModel END;
				ELSIF ~nonDefault THEN
					Changed
				END;
				NotDefault;
			ReleaseWrite
		END Set;

		PROCEDURE UpdateProperty;
		VAR type: Types.String; model: Models.Model; res: LONGINT;
		BEGIN
			IF GetModel(object, model) THEN
				type.value := value; (* pass pointer to string *)
				model.GetGeneric(type, res);
				 IF res = 0 THEN Set(type.value) END;
			END;
		END UpdateProperty;

		PROCEDURE GetAOC*(VAR value : ARRAY OF CHAR);
		BEGIN
			value := "";
			AcquireRead;
			IF (SELF.value # NIL) THEN
				COPY(SELF.value^, value);
			END;
			ReleaseRead;
		END GetAOC;

		PROCEDURE SetAOC*(CONST value : ARRAY OF CHAR);
		BEGIN
			AcquireWrite;
				Strings.SetAOC(value, SELF.value);
				Set(SELF.value);
			ReleaseWrite;
		END SetAOC;

		PROCEDURE FromXML*(xml : XML.Element);
		VAR en : XMLObjects.Enumerator; p : ANY;
		BEGIN
			en := xml.GetContents();
			p := en.GetNext();
			IF p # NIL THEN
				IF IsLink(p) THEN
				ELSIF p IS XML.Chars THEN
					Set(p(XML.Chars).GetStr())
				END
			ELSE
				Set(NIL)
			END
		END FromXML;

		PROCEDURE ToXML(VAR element: XML.Element);
		VAR chars: XML.ArrayChars;s: String; w: Streams.StringWriter; res,len: LONGINT;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewString");
				IF (value # NIL) OR ((dictionary # NIL) & (word # NIL)) THEN
					NEW(chars); element.AddContent(chars);
					len := 64;
					IF (value # NIL) THEN INC(len, LEN(value^)) END;
					NEW(w, len);
					IF (dictionary # NIL) & (word # NIL) THEN
						w.String("::");
						XML.UTF8ToStream(dictionary.fullname^, w, res);
						IF (res = XML.Ok) THEN
							w.String(":");
							XML.UTF8ToStream(word^, w, res);
						END;
					ELSE
						XML.UTF8ToStream(value^, w, res);
					END;
					NEW(s, w.Pos()+1); w.Get(s^);
					chars.SetStr(s^);
				END;
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		VAR name : String; res : LONGINT;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("WMProperties: Nameless string property encountered. Ignored "); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				IF (value # NIL) OR ((dictionary # NIL) & (word # NIL)) THEN
					Indent(w, indent);
					w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewString"'); w.Char(">");
					IF ~WriteLink(w,context,indent) THEN
						IF (dictionary # NIL) & (word # NIL) THEN
							w.String("::");
							XML.UTF8ToStream(dictionary.fullname^, w, res);
							IF (res = XML.Ok) THEN
								w.String(":");
								XML.UTF8ToStream(word^, w, res);
							END;
						ELSE
							XML.UTF8ToStream(value^, w, res);
						END;
					END;
					w.String("</"); w.String(name^); w.Char(">"); w.Ln;
					IF (res # XML.Ok) THEN
						KernelLog.String("WMProperties.StringProperty.WriteXML: Warning!"); KernelLog.Ln;
					END;
				END;
			END
		END WriteXML;

	END StringProperty;

TYPE

	ColorProperty* = OBJECT(Property)
	VAR
		value : LONGINT;

		(* TODO: read hex from CCG FontConverter *)
		PROCEDURE FromStream*(r : Streams.Reader);
		VAR v : LONGINT;
		BEGIN
			AcquireWrite;
			r.Int(v, TRUE); NotDefault;
			IF v # value THEN value := v; Changed END;
			ReleaseWrite
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer);
		BEGIN
			AcquireRead;
			w.Hex(value, -8);
			ReleaseRead
		END ToStream;

		PROCEDURE UpdateProperty;
		VAR boolean: Types.Integer; model: Models.Model; res: LONGINT;
		BEGIN
			IF GetModel(object, model) THEN
				 model.GetGeneric(boolean, res);
				 IF res = 0 THEN Set(boolean.value) END;
			END;
		END UpdateProperty;

		PROCEDURE UpdateModel;
		VAR type: Types.Integer; model: Models.Model; res: LONGINT;
		BEGIN
			IF inLinkUpdate THEN RETURN END;
			IF GetModel(object, model) THEN
				type.value := value;
				model.SetGeneric(type, res);
			END;
		END UpdateModel;

		PROCEDURE Get*() : LONGINT;
		VAR r : LONGINT;
		BEGIN
			AcquireRead;
			IF nonDefault OR (prototype = NIL) THEN r := value
			ELSE r := prototype(ColorProperty).Get()
			END;
			ReleaseRead;
			RETURN r
		END Get;

		PROCEDURE Set*(value : HUGEINT);
		BEGIN
			AcquireWrite;
			IF SHORT(value) # SELF.value THEN
				SELF.value := SHORT(value); Changed;
				IF (object # NIL) THEN UpdateModel END;
			ELSIF ~nonDefault THEN Changed
			END;
			NotDefault;
			ReleaseWrite
		END Set;

		PROCEDURE FromXML*(xml : XML.Element);
		VAR
			en : XMLObjects.Enumerator;
			p : ANY;
			s : String; res : LONGINT;
		BEGIN
			AcquireWrite;
			en := xml.GetContents();
			IF en.HasMoreElements() THEN
				p := en.GetNext();
				IF IsLink(p) THEN
				ELSIF p IS XML.Chars THEN
					s := p(XML.Chars).GetStr();
					IF s # NIL THEN Strings.HexStrToInt(s^, value, res) END; NotDefault
				END
			END;
			Stamp;
			ReleaseWrite
		END FromXML;

		PROCEDURE ToXML(VAR element: XML.Element);
		VAR chars: XML.ArrayChars;s: String; w: Streams.StringWriter; res: LONGINT;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewColor");
				NEW(chars); element.AddContent(chars);
				NEW(w,10 );
				w.Hex(value, -8);
				NEW(s, w.Pos()+1); w.Get(s^);
				chars.SetStr(s^);
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		VAR name : String;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("Nameless color property encountered. Ignored"); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				Indent(w, indent);
				w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewColor"'); w.Char(">");
				IF ~WriteLink(w,context,indent) THEN
					w.Hex(value, -8);
				END;
				w.String("</"); w.String(name^); w.Char(">"); w.Ln;
			END
		END WriteXML;

	END ColorProperty;

TYPE

	FontProperty* = OBJECT(Property)
	VAR
		font : WMGraphics.Font; (* { font # NIL } *)

		PROCEDURE &New*(prototype : Property; name, info : String);
		BEGIN
			New^(prototype, name, info);
			font := WMGraphics.GetDefaultFont();
		END New;

		PROCEDURE FromStream*(r : Streams.Reader);
		VAR font : WMGraphics.Font; name, temp : ARRAY 32 OF CHAR; size : LONGINT; style : SET;
		BEGIN
			AcquireWrite;
			NotDefault;
			name := ""; size := 0; style := {};
			IF r.GetString(name) & r.GetInteger(size, FALSE) & r.GetString(temp) THEN
				Strings.StrToSet(temp, style);
				IF size < 6 THEN size := 6 END;
				font := WMGraphics.GetFont(name, size, style);
				IF (font = NIL) THEN font := WMGraphics.GetDefaultFont(); END;
				IF (SELF.font # font) THEN SELF.font := font; Changed END;
			END;
			ReleaseWrite
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer);
		VAR font : WMGraphics.Font; temp : ARRAY 32 OF CHAR;
		BEGIN
			AcquireRead;
			font := Get();
			w.String(font.name); w.Char(" "); w.Int(font.size, 0); w.Char(" ");
			Strings.SetToStr(font.style, temp); w.String(temp);
			ReleaseRead
		END ToStream;

		PROCEDURE Get*() : WMGraphics.Font;
		VAR font : WMGraphics.Font;
		BEGIN
			AcquireRead;
			IF nonDefault OR (prototype = NIL) THEN font := SELF.font;
			ELSE font := prototype(FontProperty).Get()
			END;
			ReleaseRead;
			IF (font = NIL) THEN font := WMGraphics.GetDefaultFont(); END;
			ASSERT(font # NIL);
			RETURN font;
		END Get;

		PROCEDURE Set*(font : WMGraphics.Font);
		BEGIN
			IF (font = NIL) THEN font := WMGraphics.GetDefaultFont(); END;
			ASSERT(font # NIL);
			AcquireWrite;
			IF font # SELF.font THEN
				SELF.font := font; Changed;
				IF object # NIL THEN UpdateModel END;
			ELSIF ~ nonDefault THEN Changed END;
			NotDefault;
			ReleaseWrite;
		END Set;

		PROCEDURE GetFont*(VAR name : ARRAY OF CHAR; VAR size : LONGINT; VAR style : SET);
		VAR font : WMGraphics.Font;
		BEGIN
			font := Get();
			COPY(font.name, name); size := font.size; style := font.style;
		END GetFont;

		PROCEDURE SetFont*(CONST name : ARRAY OF CHAR; size : LONGINT; style : SET);
		VAR font : WMGraphics.Font;
		BEGIN
			IF size < 6 THEN size := 6 END;
			font := WMGraphics.GetFont(name, size, style);
			IF (font = NIL) THEN font := WMGraphics.GetDefaultFont(); END;
			ASSERT(font  # NIL);
			AcquireWrite;
			IF (SELF.font # font) THEN SELF.font := font; Changed; END;
			NotDefault;
			ReleaseWrite;
		END SetFont;

		PROCEDURE SetFontName*(CONST name : ARRAY OF CHAR);
		VAR font : WMGraphics.Font;
		BEGIN
			AcquireWrite;
			font := Get();
			IF (font.name # name) THEN
				font := WMGraphics.GetFont(name, font.size, font.style);
				IF (font = NIL) THEN font := WMGraphics.GetDefaultFont(); END;
				IF (SELF.font # font) THEN
					SELF.font := font;
					Changed;
				END;
			END;
			NotDefault;
			ReleaseWrite;
		END SetFontName;

		PROCEDURE GetFontName*(VAR name : ARRAY OF CHAR);
		VAR font : WMGraphics.Font;
		BEGIN
			font := Get();
			COPY(font.name, name);
		END GetFontName;

		PROCEDURE SetSize*(size : LONGINT);
		VAR font : WMGraphics.Font;
		BEGIN
			AcquireWrite;
			font := Get();
			IF size < 6 THEN size := 6 END;
			IF (font.size # size) THEN
				font := WMGraphics.GetFont(font.name, size, font.style);
				IF (font = NIL) THEN font := WMGraphics.GetDefaultFont(); END;
				IF (SELF.font # font) THEN
					SELF.font := font;
					Changed;
				END;
			END;
			NotDefault;
			ReleaseWrite;
		END SetSize;

		PROCEDURE GetSize*() : LONGINT;
		VAR font : WMGraphics.Font;
		BEGIN
			font := Get();
			RETURN font.size;
		END GetSize;

		PROCEDURE SetStyle*(style : SET);
		VAR font : WMGraphics.Font;
		BEGIN
			AcquireWrite;
			font := Get();
			IF (font.style # style) THEN
				font := WMGraphics.GetFont(font.name, font.size, style);
				IF (font = NIL) THEN font := WMGraphics.GetDefaultFont(); END;
				IF (SELF.font # font) THEN
					SELF.font := font;
					Changed;
				END;
			END;
			NotDefault;
			ReleaseWrite;
		END SetStyle;

		PROCEDURE GetSyle*() : SET;
		VAR font : WMGraphics.Font;
		BEGIN
			font := Get();
			RETURN font.style;
		END GetSyle;

		PROCEDURE FromXML*(xml : XML.Element);
		VAR s : String; name : ARRAY 32 OF CHAR; size : LONGINT; style : SET;
		BEGIN
			s := xml.GetAttributeValue("name");
			IF (s # NIL) THEN COPY(s^, name); ELSE name := ""; END;
			s := xml.GetAttributeValue("size");
			IF (s  # NIL) THEN Strings.StrToInt(s^, size); ELSE size := 0; END;
			s := xml.GetAttributeValue("style");
			IF (s # NIL) THEN Strings.StrToSet(s^, style); ELSE style := {}; END;
			SetFont(name, size, style);
		END FromXML;

		PROCEDURE ToXML(VAR element: XML.Element);
		VAR s: ARRAY 32 OF CHAR;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewFont");
				element.SetAttributeValue("name",font.name);
				Strings.IntToStr(font.size, s);
				element.SetAttributeValue("size",s);
				Strings.SetToStr(font.style, s);
				element.SetAttributeValue("style",s);
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		VAR name : String; font : WMGraphics.Font; temp : ARRAY 32 OF CHAR;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("Nameless boolean property encountered. Ignored"); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				font := Get();
				Indent(w, indent);
				w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewFont"');
				w.String(' name="'); w.String(font.name); w.String('" size="'); w.Int(font.size, 0); w.String('" style="');
				Strings.SetToStr(font.style, temp); w.String(temp); w.String('"');
				w.String("/>");
				w.Ln;
			END
		END WriteXML;

	END FontProperty;


TYPE
	(** Accessor property to an Point (in integer  coordinates). *)
	PointProperty*= OBJECT(Property)
	VAR
		value : WMGraphics.Point2d;

		PROCEDURE FromStream*(r : Streams.Reader);
		VAR new : WMGraphics.Point2d;
		BEGIN
			AcquireWrite;
			r.SkipWhitespace; r.Int(new.x, FALSE);
			r.SkipWhitespace; r.Int(new.y, FALSE);
			NotDefault;
			IF (new.x=value.x) & (new.y=value.y) THEN
				value := new;
				Changed;
			END;
			ReleaseWrite
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer);
		BEGIN
			AcquireRead;
			w.Int(value.x, 0); w.Char(" ");
			w.Int(value.y, 0);
			ReleaseRead
		END ToStream;


		PROCEDURE Get*() : WMGraphics.Point2d;
		VAR r : WMGraphics.Point2d;
		BEGIN
			AcquireRead;
			IF nonDefault OR (prototype = NIL) THEN r := value
			ELSE r := prototype(PointProperty).Get()
			END;
			ReleaseRead;
			RETURN r
		END Get;

		PROCEDURE Set*(value : WMGraphics.Point2d);
		BEGIN
			AcquireWrite;
			IF (SELF.value.x#value.x) OR (SELF.value.y#value.y) THEN
				SELF.value.x:=value.x;
				SELF.value.y:=value.y;
				IF object # NIL THEN UpdateModel END;
				Changed;
			ELSIF ~nonDefault THEN Changed
			END;
			NotDefault;
			ReleaseWrite
		END Set;

		PROCEDURE SetCoordinate*(x,y : LONGINT);
		BEGIN
			AcquireWrite;
			IF (x#value.x) OR (y#value.y) THEN
				value.x:=x; value.y:=y;
				Changed
			END;
			NotDefault;
			ReleaseWrite
		END SetCoordinate;

		PROCEDURE GetCoordinate*(VAR x,y: LONGINT);
		BEGIN
			x:=value.x; y:=value.y
		END GetCoordinate;


		PROCEDURE SetX*(x : LONGINT);
		BEGIN
			AcquireWrite;
			IF value.x # x THEN value.x := x; Changed END; NotDefault;
			ReleaseWrite
		END SetX;

		PROCEDURE SetY*(y : LONGINT);
		BEGIN
			AcquireWrite;
			IF value.y # y THEN value.y := y; Changed END; NotDefault;
			ReleaseWrite
		END SetY;

		PROCEDURE GetX*() : LONGINT;
		BEGIN
			RETURN value.x
		END GetX;

		PROCEDURE GetY*(): LONGINT;
		BEGIN
			RETURN value.y
		END GetY;

		PROCEDURE FromXML*(xml : XML.Element);
		VAR en : XMLObjects.Enumerator; p : ANY; s: String;
		BEGIN
			AcquireWrite;
			en := xml.GetContents();
			WHILE en.HasMoreElements() DO
				IF en.HasMoreElements() THEN
					p := en.GetNext();
					IF (p IS XML.Element) THEN
						s := p(XML.Element).GetName();
						IF s # NIL THEN
							IF s^ = "X" THEN SetX(ReadCharDataInt(p(XML.Element)))
							ELSIF s^ = "Y" THEN SetY(ReadCharDataInt(p(XML.Element)))
							END
						END
					END
				END
			END;
			Stamp;
			ReleaseWrite
		END FromXML;

		PROCEDURE ToXML(VAR element: XML.Element);
		VAR cs: ARRAY 10 OF CHAR; sub: XML.Element; t: WMGraphics.Point2d;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewPoint");
				t := Get();
				NEW(sub); sub.SetName("X"); element.AddContent(sub);
				sub.AddContent(NewIntChars(t.x));
				NEW(sub); sub.SetName("Y");element.AddContent(sub);
				sub.AddContent(NewIntChars(t.y));
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		VAR name : String; t : WMGraphics.Point2d;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("Nameless point property encountered. Ignored"); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				t := Get();
				Indent(w, indent);w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewPoint"'); w.Char(">"); w.Ln;
				Indent(w, indent + 1); w.String("<X>"); w.Int(t.x, 0); w.String("</X>"); w.Ln;
				Indent(w, indent + 1); w.String("<Y>"); w.Int(t.y, 0); w.String("</Y>"); w.Ln;
				Indent(w, indent); w.String("</"); w.String(name^); w.Char(">"); w.Ln;
			END
		END WriteXML;

	END PointProperty;


TYPE

	(** Accessor property to an integer value. The range of possible values can be restricted. *)
	RectangleProperty* = OBJECT(Property)
	VAR
		value : WMRectangles.Rectangle;

		PROCEDURE FromStream*(r : Streams.Reader);
		VAR new : WMRectangles.Rectangle;
		BEGIN
			AcquireWrite;
			r.SkipWhitespace; r.Int(new.l, FALSE);
			r.SkipWhitespace; r.Int(new.t, FALSE);
			r.SkipWhitespace; r.Int(new.r, FALSE);
			r.SkipWhitespace; r.Int(new.b, FALSE);
			NotDefault;
			IF ~WMRectangles.IsEqual(new, value) THEN
				value := new;
				Changed;
			END;
			ReleaseWrite
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer);
		BEGIN
			AcquireRead;
			w.Int(value.l, 0); w.Char(" "); w.Int(value.t, 0); w.Char(" ");
			w.Int(value.r, 0); w.Char(" "); w.Int(value.b, 0);
			ReleaseRead
		END ToStream;

		PROCEDURE Get*() : WMRectangles.Rectangle;
		VAR r : WMRectangles.Rectangle;
		BEGIN
			AcquireRead;
			IF nonDefault OR (prototype = NIL) THEN r := value
			ELSE r := prototype(RectangleProperty).Get()
			END;
			ReleaseRead;
			RETURN r
		END Get;

		PROCEDURE Set*(value : WMRectangles.Rectangle);
		BEGIN
			AcquireWrite;
			IF (SELF.value.l # value.l) OR (SELF.value.t # value.t) OR
				(SELF.value.r # value.r) OR (SELF.value.b # value.b) THEN
				SELF.value := value; Changed;
				IF object # NIL THEN UpdateModel END;
			ELSIF ~nonDefault THEN Changed
			END;
			NotDefault;
			ReleaseWrite
		END Set;

		PROCEDURE SetWidth*(w : LONGINT);
		BEGIN
			AcquireWrite;
			IF GetWidth() # w THEN Changed END; value.r := value.l + w; NotDefault;
			ReleaseWrite
		END SetWidth;

		PROCEDURE SetHeight*(h : LONGINT);
		BEGIN
			AcquireWrite;
			IF GetHeight() # h THEN Changed END; value.b := value.t + h; NotDefault;
			ReleaseWrite
		END SetHeight;

		PROCEDURE SetLeft*(l : LONGINT);
		BEGIN
			AcquireWrite;
			IF value.l # l THEN Changed END; value.r := l + GetWidth(); value.l := l; NotDefault;
			ReleaseWrite
		END SetLeft;

		PROCEDURE SetTop*(t : LONGINT);
		BEGIN
			AcquireWrite;
			IF value.t # t THEN Changed END; value.b := t + GetHeight(); value.t := t;  NotDefault;
			ReleaseWrite
		END SetTop;

		PROCEDURE SetRight*(r : LONGINT);
		BEGIN
			AcquireWrite;
			IF value.r # r THEN Changed END; value.r := r;  NotDefault;
			ReleaseWrite
		END SetRight;

		PROCEDURE SetBottom*(b : LONGINT);
		BEGIN
			AcquireWrite;
			IF value.b # b THEN Changed END; value.b := b; NotDefault;
			ReleaseWrite
		END SetBottom;

		PROCEDURE SetExtents*(w, h : LONGINT);
		BEGIN
			AcquireWrite; (* protective transaction *)
			SetWidth(w); SetHeight(h);
			ReleaseWrite
		END SetExtents;

		PROCEDURE GetWidth*() : LONGINT;
		VAR r : WMRectangles.Rectangle;
		BEGIN
			r := Get();
			RETURN r.r - r.l;
		END GetWidth;

		PROCEDURE GetHeight*() : LONGINT;
		VAR r : WMRectangles.Rectangle;
		BEGIN
			r := Get();
			RETURN r.b - r.t;
		END GetHeight;

		PROCEDURE GetLeft*() : LONGINT;
		VAR r : WMRectangles.Rectangle;
		BEGIN
			r := Get();
			RETURN r.l;
		END GetLeft;

		PROCEDURE GetTop*() : LONGINT;
		VAR r : WMRectangles.Rectangle;
		BEGIN
			r := Get();
			RETURN r.t;
		END GetTop;

		PROCEDURE GetRight*() : LONGINT;
		VAR r : WMRectangles.Rectangle;
		BEGIN
			r := Get();
			RETURN r.r;
		END GetRight;

		PROCEDURE GetBottom*() : LONGINT;
		VAR r : WMRectangles.Rectangle;
		BEGIN
			r := Get();
			RETURN r.b;
		END GetBottom;

		PROCEDURE GetExtents*(VAR width, height : LONGINT);
		VAR r : WMRectangles.Rectangle;
		BEGIN
			r := Get();
			width := r.r - r.l;
			height := r.b - r.t;
		END GetExtents;

		PROCEDURE FromXML*(xml : XML.Element);
		VAR en : XMLObjects.Enumerator; p : ANY; s: String;
		BEGIN
			AcquireWrite;
			en := xml.GetContents();
			WHILE en.HasMoreElements() DO
				IF en.HasMoreElements() THEN
					p := en.GetNext();
					IF (p IS XML.Element) THEN
						s := p(XML.Element).GetName();
						IF s # NIL THEN
							IF s^ = "Left" THEN SetLeft(ReadCharDataInt(p(XML.Element)))
							ELSIF s^ = "Top" THEN SetTop(ReadCharDataInt(p(XML.Element)))
							ELSIF s^ = "Right" THEN SetRight(ReadCharDataInt(p(XML.Element)))
							ELSIF s^ = "Bottom" THEN SetBottom(ReadCharDataInt(p(XML.Element)))
							ELSIF s^ = "Width" THEN SetWidth(ReadCharDataInt(p(XML.Element)))
							ELSIF s^ = "Height" THEN SetHeight(ReadCharDataInt(p(XML.Element)))
							END
						END
					END
				END
			END;
			Stamp;
			ReleaseWrite
		END FromXML;


		PROCEDURE ToXML(VAR element: XML.Element);
		VAR cs: ARRAY 10 OF CHAR; sub: XML.Element; t: WMRectangles.Rectangle;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewRectangle");
				t := Get();
				NEW(sub); sub.SetName("Left"); element.AddContent(sub);
				sub.AddContent(NewIntChars(t.l));
				NEW(sub); sub.SetName("Top");element.AddContent(sub);
				sub.AddContent(NewIntChars(t.t));
				NEW(sub); sub.SetName("Width");element.AddContent(sub);
				sub.AddContent(NewIntChars(t.r-t.l));
				NEW(sub); sub.SetName("Height");element.AddContent(sub);
				sub.AddContent(NewIntChars(t.b-t.t));
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		VAR name : String; t : WMRectangles.Rectangle;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("Nameless rectangle property encountered. Ignored"); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				t := Get();
				Indent(w, indent);w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewRectangle"'); w.Char(">"); w.Ln;
				Indent(w, indent + 1); w.String("<Left>"); w.Int(t.l, 0); w.String("</Left>"); w.Ln;
				Indent(w, indent + 1); w.String("<Top>"); w.Int(t.t, 0); w.String("</Top>"); w.Ln;
				Indent(w, indent + 1); w.String("<Width>"); w.Int(t.r-t.l, 0); w.String("</Width>"); w.Ln;
				Indent(w, indent + 1); w.String("<Height>"); w.Int(t.b-t.t, 0); w.String("</Height>"); w.Ln;
				Indent(w, indent); w.String("</"); w.String(name^); w.Char(">"); w.Ln;
			END
		END WriteXML;

	END RectangleProperty;

TYPE

	ReferenceProperty* = OBJECT(Property)
	VAR
		(*
		object : Repositories.Component;

		repositoryName : Strings.String;
		componentName : Strings.String;
		generator : Strings.String;
		componentID : LONGINT;
		*)
		(* temporary used in WriteXML *)
		level: LONGINT;

		PROCEDURE &NewRef*(prototype : Property; name, info : String);
		BEGIN
			New(prototype, name, info);
		END NewRef;

		PROCEDURE FromStream*(r : Streams.Reader);
		VAR
			fullname, repositoryName : ARRAY 256 OF CHAR; componentName : ARRAY 128 OF CHAR;
			writer : Streams.Writer; buffer : Strings.Buffer; ch : CHAR;
		BEGIN
			r.String(fullname);
			IF Repositories.IsCommandString(fullname) THEN
				AcquireWrite;
				SELF.repositoryName := NIL;
				SELF.componentName := NIL;
				componentID := 0;
				NEW(buffer, 256); writer := buffer.GetWriter();
				writer.String(fullname);
				WHILE (r.res = Streams.Ok) DO
					r.Char(ch); writer.Char(ch);
				END;
				SELF.generator := buffer.GetString();
				ReleaseWrite;
			ELSIF Repositories.SplitName(fullname, repositoryName, componentName, SELF.componentID) THEN
				AcquireWrite;
				NotDefault;
				SELF.repositoryName := Strings.NewString(repositoryName);
				SELF.componentName := Strings.NewString(componentName);
				generator := NIL;
				ReleaseWrite
			ELSE
				AcquireWrite;
				SELF.repositoryName := NIL;
				SELF.componentName := NIL;
				componentID := 0;
				generator := NIL;
				ReleaseWrite
			END;
		END FromStream;

		PROCEDURE ToStream*(w : Streams.Writer);
		BEGIN
			AcquireRead;
			IF (generator # NIL) THEN
				w.String(generator^);
			ELSIF (repositoryName # NIL) & (componentName # NIL) THEN
				w.String(repositoryName^); w.String(":"); w.String(componentName^); w.String(":"); w.Int(componentID, 0);
			ELSIF  (object # NIL) THEN
				w.Ln;
				Indent(w,level); object.Write(w, NIL, level);
				w.Ln; Indent(w,level-1);
			END;
			ReleaseRead
		END ToStream;

		PROCEDURE Get*() : Repositories.Component;
		VAR object : Repositories.Component; context : Repositories.Context; res : LONGINT;
		BEGIN
			AcquireRead;
			object := SELF.object;
			ReleaseRead;
			(* late time generation of object for supporting of loading repositories *)
			IF (object = NIL) THEN
				IF (generator # NIL) THEN
					Repositories.CallCommand(generator^, context, res);
					IF (res = Repositories.Ok) & (context.object # NIL) & (context.object IS Repositories.Component) THEN
						object := context.object(Repositories.Component);
						Set(object)
					END;
				ELSIF (repositoryName # NIL) & (componentName # NIL) THEN
					Repositories.GetComponent(repositoryName^, componentName^, componentID, object, res);
					Set(object);
				ELSIF (componentName # NIL) & (repository # NIL) THEN
					object := repository.GetComponent(componentName^, componentID);
					Set(object);
				END;
			END;
			RETURN object
		END Get;

		PROCEDURE Set*(object : Repositories.Component);
		BEGIN
			AcquireWrite; (* TBD: Store object to repository *)
			IF (SELF.object # object) THEN
				ReplaceLink(object); Changed;
			ELSIF ~ nonDefault THEN Changed END;
			NotDefault;
			ReleaseWrite;
		END Set;

		PROCEDURE LinkChanged(sender, object: ANY);
		BEGIN
			IF (list # NIL) THEN list.onLinkChanged.CallWithSender(SELF,object) END;
		END LinkChanged;

		PROCEDURE SetAsString*(CONST string : ARRAY OF CHAR);
		BEGIN
			SetLinkAsString(string)
		END SetAsString;

		PROCEDURE GetAsString*(VAR string : ARRAY OF CHAR);
		BEGIN
			GetLinkAsString(string)
		END GetAsString;

		PROCEDURE Reset;
		BEGIN
			AcquireWrite;
			ReplaceLink(NIL);
			repositoryName := NIL; componentName := NIL; componentID := 0;
			generator := NIL;
			NotDefault;
			Changed;
			ReleaseWrite;
		END Reset;

		PROCEDURE FromXML*(xml : XML.Element);
		VAR en : XMLObjects.Enumerator; p : ANY; s : String;
		BEGIN
			ReplaceLink(NIL);
			object := NIL;
			repositoryName := NIL; componentName := NIL;
			componentID := 0;
			en := xml.GetContents();
			p := en.GetNext();
			NotDefault;

			IF (p # NIL ) & (p IS XML.Chars) THEN
				s := p(XML.Chars).GetStr();
				IF s # NIL THEN
					Strings.Trim(s^, " ");
					SetAsString(s^);
					object := Get();
				END
			ELSIF (p # NIL) & (p IS XML.Element) THEN
				ReplaceLink( Repositories.ComponentFromXML(p(XML.Element)));
			END
		END FromXML;

		PROCEDURE ToXML(VAR element: XML.Element);
		VAR cs: ARRAY 10 OF CHAR; sub: XML.Element; t: WMRectangles.Rectangle;
		BEGIN
			IF (GetName # NIL) & nonDefault THEN
				ToXML^(element);
				element.SetAttributeValue("loader","WMProperties.NewReference");
				(*??? how to represent this ? *)
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY;  indent : LONGINT);
		VAR name : String; id,res: LONGINT; repository: Repositories.Repository; objectName: String;
		BEGIN
			name := GetName();
			IF name = NIL THEN KernelLog.String("Nameless boolean property encountered. Ignored"); KernelLog.Ln; RETURN END;
			IF nonDefault THEN
				Indent(w, indent);
				level := indent+1;
				w.Char("<"); w.String(name^); w.String(' loader="WMProperties.NewReference"'); w.Char(">");
				IF (context # NIL) & (context IS Repositories.StoreContext) & (object # NIL) THEN
					repository := context(Repositories.StoreContext).repository;
					id := 1;
					objectName := object.GetName();
					IF (objectName=NIL) OR (objectName^="") THEN objectName :=anonymous END;
					repository.PutComponent(object, objectName^,id,res);
					w.String(":"); (* <-- THIS repository *) w.String(objectName^); w.String(":"); w.Int(id, 0);
				ELSE
					ToStream(w);
				END;
				w.String("</"); w.String(name^); w.Char(">"); w.Ln;
			END
		END WriteXML;

		PROCEDURE Finalize*;
		BEGIN
			AcquireWrite;
			ReplaceLink(NIL);
			ReleaseWrite;
		END Finalize;

	END ReferenceProperty;

TYPE

	PropertyArray* = POINTER TO ARRAY OF Property;

	PropertyList* = OBJECT
	VAR
		properties : PropertyArray;
		nofProperties- : LONGINT;
		onPropertyChanged- : WMEvents.EventSource;
		onLinkChanged-: WMEvents.EventSource;
		lock : Locks.RWLock;
		upNofChanges : LONGINT;
		upChanged : Property;

		propertyChanged, linkChanged: WMEvents.EventListener;

		PROCEDURE &New*;
		BEGIN
			NEW(properties, 8);
			NEW(onPropertyChanged, SELF, StringProperties, StringPropertiesInfo, NIL);
			NEW(onLinkChanged, SELF, StringLinks, StringLinksInfo, NIL);
			NEW(lock)
		END New;

		(** acquire a write lock on the object *)
		PROCEDURE AcquireWrite*;
		BEGIN
			lock.AcquireWrite
		END AcquireWrite;

		(** release the write lock on the object *)
		PROCEDURE ReleaseWrite*;
		VAR
			removeLock : BOOLEAN;
			changed : Property; nofChanges : LONGINT;
		BEGIN
			removeLock := lock.GetWLockLevel() = 1;
			IF removeLock THEN
				changed := upChanged; nofChanges := upNofChanges;
				upNofChanges := 0; upChanged := NIL;
			END;
			lock.ReleaseWrite;
			IF removeLock THEN
				IF nofChanges = 1 THEN onPropertyChanged.Call(changed)
				ELSIF nofChanges > 0 THEN onPropertyChanged.Call(SELF)
				END
			END
		END ReleaseWrite;

		PROCEDURE AcquireRead;
		BEGIN
			lock.AcquireRead
		END AcquireRead;

		PROCEDURE ReleaseRead;
		BEGIN
			lock.ReleaseRead
		END ReleaseRead;

		PROCEDURE Add*(x : Property);
		BEGIN
			AcquireWrite;
			x.list := SELF;
			IF nofProperties = LEN(properties) THEN Grow END;
			properties[nofProperties] := x;
			INC(nofProperties);
			ReleaseWrite
		END Add;

		PROCEDURE Remove*(x : Property);
		VAR i : LONGINT;
		BEGIN
			AcquireWrite;
			i := 0; WHILE (i < nofProperties) & (properties[i] # x) DO INC(i) END;
			IF i < nofProperties THEN
				WHILE (i < nofProperties - 1) DO properties[i] := properties[i + 1]; INC(i) END;
				DEC(nofProperties);
				properties[nofProperties] := NIL
			END;
			ReleaseWrite
		END Remove;

		PROCEDURE Get*(CONST name : ARRAY OF CHAR) : Property;
		VAR property : Property; n : String; i : LONGINT;
		BEGIN
			AcquireRead;
			i := 0; property := NIL;
			WHILE (i < nofProperties) & (property = NIL) DO
				n := properties[i].GetName();
				IF (n # NIL) & (n^ = name) THEN
					property := properties[i];
				END;
				INC(i);
			END;
			ReleaseRead;
			RETURN property;
		END Get;

		PROCEDURE Grow;
		VAR new: PropertyArray; i : LONGINT;
		BEGIN
			NEW(new, LEN(properties) * 2);
			FOR i := 0 TO nofProperties - 1 DO new[i] := properties[i] END;
			properties := new
		END Grow;

		PROCEDURE Enumerate*() : PropertyArray;
		VAR current : PropertyArray; i : LONGINT;
		BEGIN
			AcquireWrite;
			NEW(current, nofProperties);
			FOR i := 0 TO nofProperties - 1 DO current[i] := properties[i] END;
			ReleaseWrite;
			RETURN current
		END Enumerate;

		PROCEDURE HasProperty*(CONST name : ARRAY OF CHAR) : BOOLEAN;
		VAR n : Strings.String; found : BOOLEAN; i : LONGINT;
		BEGIN
			found := FALSE;
			AcquireRead;
			i := 0;
			WHILE ~found & (i < nofProperties) DO
				n := properties[i].GetName();
				found := (n # NIL) & (n^ = name);
				INC(i);
			END;
			ReleaseRead;
			RETURN found;
		END HasProperty;

		PROCEDURE GetPropertyValue*(CONST name : ARRAY OF CHAR; VAR value : ARRAY OF CHAR) : BOOLEAN;
		VAR i : LONGINT; n : String; vs : Streams.StringWriter; len : LONGINT;
		BEGIN
			AcquireRead;
			i := 0;
			WHILE i < nofProperties DO
				n := properties[i].GetName();
				IF (n # NIL) & (n^ = name) THEN
					len := LEN(value);
					NEW(vs, LEN(value)); vs.GetRaw(value, len);
					properties[i].ToStream(vs);
					vs.Get(value);
					ReleaseRead;
					RETURN TRUE;
				END;
				INC(i);
			END;
			ReleaseRead;
			RETURN FALSE;
		END GetPropertyValue;

		PROCEDURE SetPropertyValue*(CONST name, value: ARRAY OF CHAR) : BOOLEAN;
		VAR i : LONGINT; n : String; vs : Streams.StringReader;
		BEGIN
			AcquireWrite;
			i := 0;
			WHILE i < nofProperties DO
				n := properties[i].GetName();
				IF (n # NIL) & (n^ = name) THEN
					NEW(vs, LEN(value)); vs.SetRaw(value, 0, LEN(value));
					properties[i].FromStream(vs); i := nofProperties
				END;
				INC(i)
			END;
			ReleaseWrite;
			RETURN (i > nofProperties) (* if no success, then i=nofProperties;  patch PH 06/12 *)
		END SetPropertyValue;

		PROCEDURE SetXML*(xml : XML.Element);
		VAR
			en : XMLObjects.Enumerator;
			p : ANY; s, n : String; i : LONGINT;
			repository: Repositories.Repository;
		BEGIN
			AcquireWrite;
			IF xml IS Repositories.Properties THEN repository := xml(Repositories.Properties).repository ELSE repository := NIL END;
			en := xml.GetContents();
			WHILE en.HasMoreElements() DO
				p := en.GetNext();
				IF p IS XML.Element THEN
					s := p(XML.Element).GetName();
					i := 0;
					WHILE i < nofProperties DO
						properties[i].repository := repository;
						n := properties[i].GetName();
						IF (n # NIL) & (n^ = s^) THEN
							properties[i].FromXML(p(XML.Element)); i := nofProperties
						END;
						INC(i)
					END
				END
			END;
			ReleaseWrite
		END SetXML;

		PROCEDURE FromXML*(xml: XML.Element);
		VAR generator: PROCEDURE(): Property;
		VAR
			property: Property;
			l: Strings.String;
			en : XMLObjects.Enumerator;
			p : ANY; s, n : String; i : LONGINT;
			moduleName, procedureName: Modules.Name;
			res: LONGINT; msg: ARRAY 32 OF CHAR;
			found: BOOLEAN;
		BEGIN
			IF xml # NIL THEN
				AcquireWrite;
				en := xml.GetContents();
				WHILE en.HasMoreElements() DO
					p := en.GetNext();
					IF p IS XML.Element THEN
						s := p(XML.Element).GetName();

						(* check if property is already there (and potentially linked in application, in which case it should not be reinstalled *)
						i := 0; found := FALSE;
						WHILE (i < nofProperties) & ~found DO
							n := properties[i].GetName();
							IF (n # NIL) & (n^ = s^) THEN
								found := TRUE;
								properties[i].FromXML(p(XML.Element)); i := nofProperties
							END;
							INC(i)
						END;
						IF ~found THEN
							l := p(XML.Element).GetAttributeValue("loader");
							IF l # NIL THEN
								Commands.Split(l^, moduleName, procedureName, res, msg);
								IF (res = Commands.Ok) THEN
									GETPROCEDURE(moduleName, procedureName, generator);
									IF (generator # NIL) THEN
										property := generator();
										IF (property # NIL) THEN
											property.New(NIL, s, NIL);
											property.FromXML(p(XML.Element));
											Add(property);
										END;
									END;
								END;
							END;
						END;
					END
				END;
				ReleaseWrite
			END;
		END FromXML;

		PROCEDURE ToXML*(VAR element: XML.Element);
		VAR sub: XML.Element; i : LONGINT; self: ANY;
		BEGIN
			NEW(element); element.SetName("Properties");
			FOR i := 0 TO nofProperties-1 DO
				sub := NIL;
				properties[i].ToXML(sub);
				IF sub # NIL THEN
					element.AddContent(sub);
				END;
			END;
		END ToXML;

		PROCEDURE WriteXML*(w : Streams.Writer; context: ANY; indent : LONGINT);
		VAR i : LONGINT;
		BEGIN
			w.Ln;
			Indent(w, indent + 1);
			w.String("<Properties>"); w.Ln;
			AcquireRead;

			FOR i := 0 TO nofProperties - 1 DO
				properties[i].WriteXML(w, context, indent + 2)
			END;
			Indent(w, indent + 1);
			w.String("</Properties>");
			ReleaseRead
		END WriteXML;

		(*
		PROCEDURE ToRepository*(CONST repository: ARRAY OF CHAR; w : Streams.Writer; indent : LONGINT);
		VAR i : LONGINT;
		BEGIN
			w.Ln;
			Indent(w, indent + 1);
			w.String("<Properties>"); w.Ln;
			AcquireRead;
			FOR i := 0 TO nofProperties - 1 DO
				properties[i].ToRepository(repository, w, indent + 2)
			END;
			Indent(w, indent + 1);
			w.String("</Properties>");
			ReleaseRead
		END ToRepository;
		*)

		PROCEDURE Changed(p : Property);
		BEGIN (* {EXCLUSIVE} *)
			IF p # upChanged THEN INC(upNofChanges); upChanged := p END;
		END Changed;

		PROCEDURE Finalize*;
		VAR i: LONGINT;
		BEGIN
			AcquireWrite;
			FOR i := 0 TO nofProperties - 1 DO
				properties[i].Finalize
			END;
			ReleaseWrite;
		END Finalize;


	END PropertyList;

	Properties* = Repositories.Properties;
VAR
	StringProperties, StringLinks : String;
	StringPropertiesInfo, StringLinksInfo : String;
	anonymous: String;

PROCEDURE Indent(w : Streams.Writer; indent : LONGINT);
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO indent - 1 DO w.Char(9X) END
END Indent;

PROCEDURE ReadCharDataInt(xml : XML.Element) : LONGINT;
VAR en : XMLObjects.Enumerator;
	p : ANY; s : String; value : LONGINT;
BEGIN
	value := 0;
	en := xml.GetContents();
	IF en.HasMoreElements() THEN
		p := en.GetNext();
		IF p IS XML.Chars THEN
			s := p(XML.Chars).GetStr();
			IF s # NIL THEN Strings.StrToInt(s^, value) END
		END;
	END;
	RETURN value
END ReadCharDataInt;

PROCEDURE NewIntChars(i: LONGINT): XML.Chars;
VAR chars: XML.ArrayChars; s: ARRAY 32 OF CHAR;
BEGIN
	NEW(chars);
	Strings.IntToStr(i, s);
	chars.SetStr(s);
	RETURN chars
END NewIntChars;


PROCEDURE NewBoolean*(): Property;
VAR property: BooleanProperty;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewBoolean;

PROCEDURE NewSet*(): Property;
VAR property: SetProperty;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewSet;

PROCEDURE NewInt32*(): Property;
VAR property: Int32Property;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewInt32;

PROCEDURE NewReal*(): Property;
VAR property: RealProperty;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewReal;

PROCEDURE NewString*(): Property;
VAR property: StringProperty;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewString;

PROCEDURE NewColor*(): Property;
VAR property: ColorProperty;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewColor;

PROCEDURE NewFont*(): Property;
VAR property: FontProperty;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewFont;

PROCEDURE NewPoint*(): Property;
VAR property: PointProperty;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewPoint;

PROCEDURE NewRectangle*(): Property;
VAR property: RectangleProperty;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewRectangle;

PROCEDURE NewReference*(): Property;
VAR property: ReferenceProperty;
BEGIN NEW(property,NIL,NIL,NIL); RETURN property
END NewReference;

(* Get a model from either a property reference or a model pointer *)
PROCEDURE GetModel*(ref: ANY; VAR m: Models.Model): BOOLEAN;
BEGIN
	IF (ref # NIL) & (ref IS ReferenceProperty) THEN ref := ref(ReferenceProperty).Get() END;
	IF (ref # NIL) & (ref IS Models.Model) THEN m := ref(Models.Model); RETURN TRUE END;
	RETURN FALSE
END GetModel;

BEGIN
	StringProperties := Strings.NewString("PropertyChanged");
	StringLinks := Strings.NewString("LinkChanged");
	StringPropertiesInfo := Strings.NewString("the event is called if a property in the list is changed");
	StringLinksInfo := Strings.NewString("the event is called if a link in a reference property in the list is changed");
	anonymous := Strings.NewString("ANONYMOUS");
END WMProperties.

