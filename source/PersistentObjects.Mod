MODULE PersistentObjects; (** AUTHOR "fof"; PURPOSE "objects that can be stored with a generic reader / writer"; *)
IMPORT XML, XMLParser, XMLScanner, Basic := FoxBasic, Strings, StringPool, Streams, Commands, FoxBasic, Files, XMLObjects, Modules, D:= Debugging;

CONST
	Persistent = 0;
	None* = -1; (* no index *)
	
	EnableTrace = FALSE;

TYPE
	(** the translation object is used to translate enumeration values to integers (and reverse) *)
	Translation* = OBJECT
	TYPE
		Entry = RECORD name: ARRAY 32 OF CHAR; key: LONGINT END;
		Table= POINTER TO ARRAY OF Entry;
	VAR
		table: Table;
		len: LONGINT;

		PROCEDURE & Init*;
		BEGIN len := 0; NEW(table,4);
		END Init;

		PROCEDURE Grow;
		VAR i: LONGINT; new: Table;
		BEGIN
			NEW(new, 2*LEN(table));
			FOR i := 0 TO LEN(table)-1 DO new[i] := table[i] END;
			table := new
		END Grow;

		PROCEDURE Add*(CONST name: ARRAY OF CHAR; key: LONGINT);
		VAR i: LONGINT;
		BEGIN
			IF len = LEN(table) THEN Grow END;
			COPY(name, table[len].name); table[len].key := key;
			INC(len);
		END Add;

		PROCEDURE Key*(CONST name: ARRAY OF CHAR; VAR key: LONGINT): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO len-1 DO
				IF table[i].name = name THEN key := table[i].key; RETURN TRUE END;
			END;
			RETURN FALSE
		END Key;

		PROCEDURE Name*(index: LONGINT; VAR name: ARRAY OF CHAR): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO len-1 DO
				IF table[i].key = index THEN COPY(table[i].name,name); RETURN TRUE END;
			END;
			HALT(100);
		END Name;

	END Translation;

	Action*=PROCEDURE {DELEGATE} (o: Object);

	Class* = ENUM Char*,Object*, String*, Integer*, Float*, Boolean*, Enum*, Name*, Range*, Set* END;

	Name= ARRAY 128 OF CHAR;

	Content*= OBJECT
	VAR
		class*: Class;
		name*, type*: Name;
		string*: Strings.String;
		persistent*: BOOLEAN;

		object*: Object;
		char*: CHAR;
		integer*: LONGINT;
		float*: LONGREAL;
		boolean*: BOOLEAN;
		translation*: Translation;
		range*: RANGE;
		set*: SET;

		success*: BOOLEAN;

		PROCEDURE SetClass*(class: Class; persistent: BOOLEAN);
		BEGIN
			SELF.class := class; SELF.persistent := persistent
		END SetClass;

		PROCEDURE GetChar*(VAR char: CHAR);
		BEGIN
			IF SELF.class = Class.Char THEN char := SELF.char; success := TRUE ELSE HALT(200) END;
		END GetChar;

		PROCEDURE SetChar*(char: CHAR);
		BEGIN
			SELF.class := Class.Char; SELF.char := char;success := TRUE; persistent := TRUE;
		END SetChar;

		PROCEDURE GetString*(VAR string: Strings.String);
		BEGIN
			IF SELF.class = Class.String THEN string := SELF.string; success := TRUE ELSE HALT(200) END;
		END GetString;

		PROCEDURE SetString*(string: Strings.String);
		BEGIN
			SELF.class := Class.String; SELF.string := string;success := TRUE; persistent := TRUE;
		END SetString;

		PROCEDURE SetAsString*(CONST s: ARRAY OF CHAR);
		VAR split: Strings.StringArray; first, last, step: LONGINT;
		BEGIN
			CASE class OF
				Class.String: string := Strings.NewString(s)
				|Class.Name: COPY(s, name);
				|Class.Boolean: boolean := (s="true") OR (s="1") OR (s="yes") OR (s="TRUE");
				|Class.Integer: Strings.StrToInt(s, integer);
				|Class.Float: Strings.StrToFloat(s, float);
				|Class.Enum:  Strings.StrToInt(s, integer);
				|Class.Range:
					split := Strings.Split(s, ":");
					Strings.StrToInt(split[0]^, first);
					IF (LEN(split) > 1) & (split[1]^ # "") THEN
						Strings.StrToInt(split[1]^, last)
					ELSE
						last := MAX(LONGINT)
					END;
					IF (LEN(split) >2) & (split[2]^ # "") THEN
						Strings.StrToInt(split[2]^, step)
					ELSE
						step := 1
					END;
					range := first .. last BY step;
				|Class.Set:
					Strings.StrToSet(s, set);
			ELSE HALT(100)
			END;
		END SetAsString;

		PROCEDURE Equals*(CONST s: ARRAY OF CHAR): BOOLEAN;
		VAR int: LONGINT; flt: LONGREAL; st: SET; split: Strings.StringArray; first, last, step: LONGINT;
		BEGIN
			CASE class OF
				Class.String: RETURN (string # NIL) & (string^ = s)
				|Class.Name: RETURN (s = name)
				|Class.Boolean: RETURN boolean = (s="true") OR (s="1") OR (s="yes") OR (s="TRUE");
				|Class.Integer: Strings.StrToInt(s, int); RETURN integer = int
				|Class.Float: Strings.StrToFloat(s, flt); RETURN float = flt
				|Class.Enum:  Strings.StrToInt(s, int); RETURN integer = int
				|Class.Range:
					split := Strings.Split(s, ":");
					Strings.StrToInt(split[0]^, first);
					IF (LEN(split) > 1) & (split[1]^ # "") THEN
						Strings.StrToInt(split[1]^, last)
					ELSE
						last := MAX(LONGINT)
					END;
					IF (LEN(split) >2) & (split[2]^ # "") THEN
						Strings.StrToInt(split[2]^, step)
					ELSE
						step := 1
					END;
					RETURN range = first .. last BY step;
				|Class.Set:
					Strings.StrToSet(s, st); RETURN set = st
			ELSE RETURN FALSE
			END;
		END Equals;

		PROCEDURE GetName*(VAR name: ARRAY OF CHAR);
		BEGIN
			IF SELF.class = Class.Name THEN COPY(SELF.name, name); success := TRUE ELSE HALT(200) END;
		END GetName;

		PROCEDURE SetName*(CONST name: ARRAY OF CHAR);
		BEGIN
			SELF.class := Class.Name; COPY(name, SELF.name);success := TRUE; persistent := TRUE;
		END SetName;

		PROCEDURE GetInteger*(VAR integer: LONGINT);
		BEGIN
			IF SELF.class = Class.Integer THEN integer := SELF.integer; success := TRUE ELSE HALT(200) END;
		END GetInteger;

		PROCEDURE SetInteger*(integer: LONGINT);
		BEGIN
			SELF.class := Class.Integer; SELF.integer := integer;success := TRUE; persistent := TRUE;
		END SetInteger;

		PROCEDURE GetSet*(VAR set: SET);
		BEGIN
			IF SELF.class = Class.Set THEN set := SELF.set; success := TRUE ELSE HALT(200) END;
		END GetSet;

		PROCEDURE SetSet*(set: SET);
		BEGIN
			SELF.class := Class.Set; SELF.set := set;success := TRUE; persistent := TRUE;
		END SetSet;

		PROCEDURE GetEnum*(translation: Translation; VAR integer: LONGINT);
		BEGIN
			SELF.translation := translation;
			IF SELF.class = Class.Enum THEN integer := SELF.integer; success := TRUE ELSE HALT(200) END;
		END GetEnum;

		PROCEDURE SetEnum*(translation: Translation; integer: LONGINT);
		BEGIN
			SELF.translation := translation;
			SELF.class := Class.Enum; SELF.integer := integer;  success := TRUE; persistent := TRUE;
		END SetEnum;

		PROCEDURE GetRange*(VAR range: RANGE);
		BEGIN
			IF SELF.class = Class.Range THEN range := SELF.range; success := TRUE ELSE HALT(200) END;
		END GetRange;

		PROCEDURE SetRange*(CONST range: RANGE);
		BEGIN
			SELF.class := Class.Range; SELF.range := range; success := TRUE; persistent := TRUE;
		END SetRange;

		PROCEDURE GetFloat*(VAR float: LONGREAL);
		BEGIN
			IF SELF.class = Class.Float THEN float := SELF.float; success := TRUE ELSE HALT(200) END;
		END GetFloat;

		PROCEDURE SetFloat*(float: LONGREAL);
		BEGIN
			SELF.class := Class.Float; SELF.float := float;success := TRUE; persistent := TRUE;
		END SetFloat;

		PROCEDURE GetBoolean*(VAR boolean: BOOLEAN);
		BEGIN
			IF SELF.class = Class.Boolean THEN boolean := SELF.boolean; success := TRUE ELSE HALT(200) END;
		END GetBoolean;

		PROCEDURE SetBoolean*(boolean: BOOLEAN);
		BEGIN
			SELF.class := Class.Boolean; SELF.boolean := boolean;success := TRUE; persistent := TRUE;
		END SetBoolean;

		PROCEDURE GetObject*(VAR object: Object);
		BEGIN
			IF SELF.class = Class.Object THEN object := SELF.object; success := TRUE ELSE HALT(200) END;
		END GetObject;

		PROCEDURE SetObject*(object: Object; CONST optionalType: ARRAY OF CHAR);
		BEGIN
			SELF.class := Class.Object; SELF.object := object; COPY(optionalType, SELF.type); success := TRUE; persistent := TRUE;
		END SetObject;

	END Content;

	Enumerator* = PROCEDURE{DELEGATE} (CONST name: ARRAY OF CHAR; array: BOOLEAN);

	(** the interpretation record contains interpretable strings that are associated with attributes of an object
		an interpreter can use the strings in order to resolve values at runtime.
	*)
	Interpretation*=
		POINTER TO RECORD
			name-, str-: Strings.String;
			next-: Interpretation;
		END;

	Object* = OBJECT
	VAR
		reader: Reader;
		writer: Writer;
		content: Content;
		action: Action;
		firstTranslation-: Interpretation;

	CONST
		StrType = "type";
	VAR
		type*: ARRAY 64 OF CHAR;

		PROCEDURE & InitObject *;
		BEGIN NEW(content); type := "Object";
		END InitObject;

		(*
		PROCEDURE Write*(w: Writer);
		BEGIN
		END Write;

		PROCEDURE Read*(w: Reader): BOOLEAN;
		BEGIN
			RETURN TRUE
		END Read;
		*)

		PROCEDURE ActionEnumerator(CONST name: ARRAY OF CHAR; array: BOOLEAN);
		VAR index: LONGINT;
		BEGIN
			index := 0;
			REPEAT
				Get(name, index, content);
				IF content.success THEN
					CASE content.class OF
						|Class.Object:
							IF content.object = NIL THEN (* break when no object any more in list *)
								content.success := FALSE
							ELSE
								action(content.object)
							END;
					ELSE
					END;
				END;
				INC(index);
			UNTIL ~content.success OR ~array
		END ActionEnumerator;

		PROCEDURE Traverse*(action: Action);
		BEGIN
			IF content = NIL THEN NEW(content) END;
			SELF.action := action;
			Enumerate(ActionEnumerator);
		END Traverse;

		PROCEDURE Enumerate*(enum: Enumerator);
		BEGIN enum(StrType,FALSE);
		END Enumerate;

		PROCEDURE Set*(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrType THEN c.GetName(type);
			ELSIF c.class = Class.Object THEN reader.Error("can not set attribute ", name);
			ELSIF reader # NIL THEN reader.Error("unsupported attribute (Set)", name);
			END;
		END Set;

		PROCEDURE Get*(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF name = StrType THEN c.SetName(type);
			ELSIF reader # NIL THEN reader.Error("unsupported attribute (Get)", name);
			END;
		END Get;

		PROCEDURE AddTranslation*(CONST name: ARRAY OF CHAR; str: Strings.String);
		VAR translation: Interpretation;
		BEGIN
			NEW(translation); translation.name := Strings.NewString(name); translation.str := str;
			translation.next := firstTranslation;
			firstTranslation := translation;
		END AddTranslation;

		PROCEDURE FindTranslation*(CONST name: ARRAY OF CHAR; VAR translation: Interpretation): BOOLEAN;
		BEGIN
			translation := firstTranslation;
			WHILE (translation # NIL) & (translation.name^ # name) DO
				translation := translation.next;
			END;
			RETURN translation # NIL;
		END FindTranslation;

		PROCEDURE RemoveTranslation*(CONST name: ARRAY OF CHAR): BOOLEAN;
		VAR translation, prev: Interpretation;
		BEGIN
			IF name = "*" THEN
				firstTranslation := NIL; RETURN TRUE
			END;

			prev := NIL;
			translation := firstTranslation;
			WHILE (translation # NIL) & ((translation.name^ # name)) DO
				prev := translation;
				translation := translation.next;
			END;
			IF translation # NIL THEN
				IF prev = NIL THEN firstTranslation := translation.next
				ELSE prev.next := translation.next
				END;
			END;
			RETURN translation # NIL;
		END RemoveTranslation;


		PROCEDURE ReadContent*(CONST name: ARRAY OF CHAR; array: BOOLEAN);
		VAR index: LONGINT; str: Strings.String;
		BEGIN
			index := 0;
			REPEAT
				Get(name, index, content);
				IF content.success (*& content.persistent*) THEN
					IF reader.AttributeNeedingTranslation(name, str) THEN
						AddTranslation(name, str);
					END;
					CASE content.class OF
						|Class.String: content.success := reader.StringAttribute(name, content.string);
						|Class.Object: content.success := reader.ReadObject(name, content.type, index, content.object);
						|Class.Name: content.success := reader.NameAttribute(name, content.name);
						|Class.Boolean: content.success := reader.BooleanAttribute(name, content.boolean);
						|Class.Integer: content.success := reader.IntegerAttribute(name, content.integer);
						|Class.Float: content.success := reader.FloatAttribute(name, content.float);
						|Class.Enum: content.success := reader.EnumAttribute(name, content.translation, content.integer)
						|Class.Range: content.success := reader.RangeAttribute(name, content.range)
						|Class.Set: content.success := reader.SetAttribute(name, content.set)
					END;
					IF content.success THEN
						Set(name, index, content)
					END;
				END;
				INC(index);
			UNTIL ~content.success OR ~array
		END ReadContent;

		PROCEDURE WriteContent*(CONST name: ARRAY OF CHAR; array: BOOLEAN);
		VAR index: LONGINT; translation: Interpretation;
		BEGIN
			index := 0;
			REPEAT
				content.success := FALSE;
				Get(name, index, content);
				IF content.persistent & (~array OR content.success) THEN
					IF FindTranslation(name, translation) THEN
						writer.StringAttribute(name, translation.str);
					ELSE
					CASE content.class OF
						|Class.String: writer.StringAttribute(name, content.string);
						|Class.Object:
							IF content.object = NIL THEN
								content.success := FALSE
							ELSE
								writer.WriteObject(name, index, content.object)
							END;
						|Class.Name: writer.NameAttribute(name, content.name);
						|Class.Boolean: writer.BooleanAttribute(name, content.boolean);
						|Class.Integer:  writer.IntegerAttribute(name, content.integer);
						|Class.Float: writer.FloatAttribute(name, content.float);
						|Class.Enum: writer.EnumAttribute(name, content.translation, content.integer)
						|Class.Range: writer.RangeAttribute(name, content.range)
						|Class.Set: writer.SetAttribute(name, content.set)
					END;
					END;
				END;
				INC(index);
			UNTIL ~array OR ~content.success
		END WriteContent;

		PROCEDURE Write*(w: Writer);
		VAR translation: Interpretation; prev: Writer;
		BEGIN
			prev := writer;
			IF content = NIL THEN NEW(content) END;
			writer := w;
			Enumerate(WriteContent);

			translation := firstTranslation;
			WHILE translation # NIL DO
				IF EnableTrace THEN D.Str("translation "); D.Str(translation.name^); D.Str("==>"); D.Str(translation.str^); D.Ln; END;
				translation := translation.next;
			END;
			writer := prev;
		END Write;

		PROCEDURE Read*(r: Reader): BOOLEAN;
		VAR prev: Reader;
		BEGIN
			IF content = NIL THEN NEW(content) END;
			prev := reader;
			reader := r;
			Enumerate(ReadContent);
			reader := prev;
			RETURN TRUE
		END Read;

		PROCEDURE Dump*(log: Streams.Writer; CONST name: ARRAY OF CHAR);
		VAR writer: Writer;
		BEGIN
			writer := NewXMLWriter(log);
			writer.WriteObject(name, None, SELF);
			writer.Close;
		END Dump;


	END Object;

	(** Object list *)
	ObjectList* = OBJECT (Object)
	VAR
		list*: FoxBasic.List;
		baseType*: Name;

		PROCEDURE &InitList*(initialSize: LONGINT; CONST baseType: ARRAY OF CHAR);
		BEGIN
			InitObject;
			NEW(list, initialSize);
			COPY(baseType, SELF.baseType);
			type := "ObjectList";
		END InitList;

		PROCEDURE Length*(): LONGINT;
		BEGIN RETURN list.Length()
		END Length;

		PROCEDURE GetElement*(i: LONGINT): Object;
		VAR obj: ANY;
		BEGIN
			IF (i >= 0) & (i < list.Length()) THEN
				obj := list.Get(i);
				IF obj # NIL THEN RETURN obj(Object); ELSE RETURN NIL; END;
			ELSE RETURN NIL;
			END;
		END GetElement;

		PROCEDURE SetElement*(i: LONGINT; o: Object);
		BEGIN
			(*WHILE list.Length() <= i DO list.Add(NIL) END;*)
			IF list.Length() = i THEN list.Add(o) ELSE list.Set(i,o) END;
		END SetElement;

		PROCEDURE Enumerate(enum: Enumerator);
		BEGIN
			Enumerate^(enum);
			enum("element", TRUE);
		END Enumerate;

		PROCEDURE Get*(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		BEGIN
			IF (name = "element") OR (name="") THEN
				c.SetObject(GetElement(index), baseType);
				c.success := TRUE; (* irrespective of content that can be nil, success should be considered given *)
			ELSE Get^(name, index, c)
			END;
		END Get;

		PROCEDURE Set*(CONST name: ARRAY OF CHAR; index: LONGINT; c: Content);
		VAR object: Object;
		BEGIN
			IF (name = "element") OR (name="") THEN
				c.GetObject(object); SetElement(index, object);
				c.success := TRUE;
			ELSE Set^(name, index, c)
			END;
		END Set;

		PROCEDURE Add*(o: Object);
		BEGIN
			list.Add(o)
		END Add;

		PROCEDURE Contains*(o: Object): BOOLEAN;
		BEGIN
			RETURN list.Contains(o);
		END Contains;

		PROCEDURE Traverse*(action: Action);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				action(GetElement(i));
			END;
		END Traverse;

		PROCEDURE IndexOf*(o: Object): LONGINT;
		BEGIN
			RETURN list.IndexOf(o)
		END IndexOf;

	END ObjectList;


	Generator = PROCEDURE {DELEGATE} (CONST type: ARRAY OF CHAR): Object;

	Reader* = OBJECT
	VAR generator: Generator;
		error: Streams.Writer;
		err-: BOOLEAN;
		filename*: Files.FileName; (* debugging *)

		PROCEDURE & InitReader(gen: Generator);
		BEGIN
			SELF.generator := gen;
			error := Commands.GetContext().error;
		END InitReader;

		PROCEDURE Error(CONST s1,s2: ARRAY OF CHAR);
		BEGIN
			err := TRUE;
			error.String("error in file "); error.String(filename); error.String(" ");
			error.Update;
		END Error;

		PROCEDURE StringAttribute*(CONST name: ARRAY OF CHAR; VAR str: Strings.String): BOOLEAN;
		END StringAttribute;

		PROCEDURE ReadObject*(CONST name, optionalType: ARRAY OF CHAR; index: LONGINT; VAR o: Object): BOOLEAN ;
		BEGIN
		END ReadObject;

		PROCEDURE NeedsTranslation(CONST s: ARRAY OF CHAR): BOOLEAN;
		VAR i: LONGINT; start: BOOLEAN;
		BEGIN
			i := 0; start := FALSE;
			WHILE s[i] # 0X DO
				IF s[i] = "?" THEN start := TRUE
				ELSIF start THEN
					IF s[i] = "{" THEN RETURN TRUE
					ELSE start := FALSE
					END;
				END;
				INC(i);
			END;
			RETURN FALSE
		END NeedsTranslation;

		PROCEDURE AttributeNeedingTranslation*(CONST name: ARRAY OF CHAR; VAR str: Strings.String): BOOLEAN;
		BEGIN
			IF StringAttribute(name, str) & NeedsTranslation(str^) THEN RETURN TRUE ELSE RETURN FALSE END;
		END AttributeNeedingTranslation;

		PROCEDURE NameAttribute*(CONST name: ARRAY OF CHAR; VAR str: ARRAY OF CHAR): BOOLEAN;
		VAR s: Strings.String;
		BEGIN
			IF StringAttribute(name, s) THEN COPY(s^, str); RETURN TRUE ELSE RETURN FALSE END;
		END NameAttribute;

		PROCEDURE BooleanAttribute*(CONST name: ARRAY OF CHAR; VAR value: BOOLEAN): BOOLEAN;
		VAR s: ARRAY 32 OF CHAR;
		BEGIN
			IF NameAttribute(name, s) THEN value := (s="true") OR (s="1") OR (s="yes") OR (s="TRUE"); RETURN TRUE ELSE RETURN FALSE END;
		END BooleanAttribute;

		PROCEDURE IntegerAttribute*(CONST name: ARRAY OF CHAR; VAR value: LONGINT): BOOLEAN;
		VAR s: ARRAY 64 OF CHAR; v: LONGINT;
		BEGIN
			IF NameAttribute(name, s) THEN Strings.StrToInt(s, v); value := v; RETURN TRUE ELSE RETURN FALSE END;
		END IntegerAttribute;

		PROCEDURE FloatAttribute*(CONST name: ARRAY OF CHAR; VAR value: LONGREAL): BOOLEAN;
		VAR str: ARRAY 64 OF CHAR;
		BEGIN
			IF NameAttribute(name, str) THEN
				Strings.StrToFloat(str, value);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END FloatAttribute;

		PROCEDURE EnumAttribute*(CONST name: ARRAY OF CHAR; translation: Translation; VAR value: LONGINT): BOOLEAN;
		VAR str: ARRAY 32 OF CHAR;
		BEGIN
			IF NameAttribute(name, str) & translation.Key(str, value) THEN RETURN TRUE ELSE RETURN FALSE END;
		END EnumAttribute;

		PROCEDURE RangeAttribute*(CONST name: ARRAY OF CHAR; VAR value: RANGE): BOOLEAN;
		VAR str: ARRAY 64 OF CHAR; first, last , step: LONGINT;  split:Strings.StringArray;
		BEGIN
			IF NameAttribute(name, str) THEN
				split := Strings.Split(str, ":");
				Strings.StrToInt(split[0]^, first);
				IF (LEN(split) > 1) & (split[1]^ # "") THEN
					Strings.StrToInt(split[1]^, last)
				ELSE
					last := MAX(LONGINT)
				END;
				IF (LEN(split) >2) & (split[2]^ # "") THEN
					Strings.StrToInt(split[2]^, step)
				ELSE
					step := 1
				END;
				value := first .. last BY step;
				RETURN TRUE
			ELSE
				RETURN FALSE
			END
		END RangeAttribute;

		PROCEDURE SetAttribute*(CONST name: ARRAY OF CHAR; VAR set: SET): BOOLEAN;
		VAR str: ARRAY 64 OF CHAR;
		BEGIN
			IF NameAttribute(name, str) THEN
				Strings.StrToSet(str, set);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END;
		END SetAttribute;

	END Reader;

	Writer* = OBJECT

		PROCEDURE & InitWriter*;
		BEGIN
		END InitWriter;

		PROCEDURE Close*;
		END Close;

		(* minimal interface to be implemented *)
		PROCEDURE NameAttribute*(CONST name, str: ARRAY OF CHAR);
		END NameAttribute;

		PROCEDURE WriteObject*(CONST name: ARRAY OF CHAR; index: LONGINT; o: Object);
		END WriteObject;

		PROCEDURE StartObjectArray*(CONST name: ARRAY OF CHAR);
		BEGIN
		END StartObjectArray;

		(* functions that provide necessary functionaliy based on minimal methods above but can be overwritten for optimisations *)
		PROCEDURE StringAttribute*(CONST name: ARRAY OF CHAR; str: Strings.String);
		BEGIN
			IF str #  NIL THEN
				NameAttribute(name, str^)
			END;
		END StringAttribute;

		PROCEDURE IntegerAttribute*(CONST name: ARRAY OF CHAR; value: HUGEINT);
		VAR str: ARRAY 64 OF CHAR;
		BEGIN
			Strings.IntToStr(SHORT(value), str);
			NameAttribute(name, str);
		END IntegerAttribute;

		PROCEDURE FloatAttribute*(CONST name: ARRAY OF CHAR; value: LONGREAL);
		VAR str: ARRAY 64 OF CHAR; sw: Streams.StringWriter;
		BEGIN
			NEW(sw, 32); sw.Float(value, 31); sw.Update;
			sw.Get(str); Strings.TrimWS(str); NameAttribute(name, str)
		END FloatAttribute;

		PROCEDURE BooleanAttribute*(CONST name: ARRAY OF CHAR; value: BOOLEAN);
		BEGIN
			IF value THEN NameAttribute(name,"true") ELSE NameAttribute(name,"false") END;
		END BooleanAttribute;

		PROCEDURE EnumAttribute*(CONST name: ARRAY OF CHAR; translation: Translation; value: LONGINT);
		VAR str: ARRAY 32 OF CHAR;
		BEGIN
			IF translation.Name(value, str) THEN NameAttribute(name, str) ELSE NameAttribute(name, "unknown") END;
		END EnumAttribute;

		PROCEDURE RangeAttribute*(CONST name: ARRAY OF CHAR; value: RANGE);
		VAR str: ARRAY 64 OF CHAR;
		BEGIN
			Strings.IntToStr(FIRST(value), str);
			Strings.Append(str, ":");
			IF LAST(value) # MAX(LONGINT) THEN
				Strings.AppendInt(str, LAST(value));
			END;
			IF STEP(value) # 1 THEN
				Strings.Append(str,":");
				Strings.AppendInt(str, STEP(value));
			END;
			NameAttribute(name, str);
		END RangeAttribute;

		PROCEDURE SetAttribute*(CONST name: ARRAY OF CHAR; value: SET);
		VAR str: ARRAY 64 OF CHAR;
		BEGIN
			Strings.SetToStr(value, str);
			NameAttribute(name, str);
		END SetAttribute;


	END Writer;

	WrittenTable = OBJECT (Basic.HashTable)
	TYPE
		ObjectId = POINTER TO RECORD num: LONGINT END;
	VAR length: LONGINT;

		PROCEDURE Enter(o: Object; VAR entry: LONGINT): BOOLEAN;
		VAR any: ANY; id: ObjectId;
		BEGIN
			any := Get(o);
			IF any # NIL THEN entry := any(ObjectId).num; RETURN FALSE
			ELSE entry := length; INC(length); NEW(id); id.num := entry; Put(o, id); RETURN TRUE
			END;
		END Enter;

	END WrittenTable;

	XMLWriter*= OBJECT (Writer)
	VAR w: Streams.Writer;
		document-: XML.Document; element: XML.Element; current: XML.Container;
		scope: Scope;
		written: WrittenTable;

		PROCEDURE & InitXMLWriter*(writer: Streams.Writer);
		BEGIN
			w := writer; NEW(document); NEW(written,16); current := document; NEW(scope,current);
		END InitXMLWriter;

		PROCEDURE Close;
		BEGIN
			IF w # NIL THEN
				document.Write(w,NIL,-1); w.Update;
			END
		END Close;

		PROCEDURE NameAttribute(CONST name, str: ARRAY OF CHAR);
		BEGIN
			element.SetAttributeValue(name, str);
		END NameAttribute;

		PROCEDURE Enter(CONST name: ARRAY OF CHAR; o: Object);
		VAR e: XML.Element;
		BEGIN
			NEW(e); e.SetName(name); current.AddContent(e);
			scope.EnterElement(e);
			scope.Enter(e); current := e; element := e;
		END Enter;

		PROCEDURE Exit(CONST name: ARRAY OF CHAR);
		BEGIN
			scope.Exit(current);
			IF (current IS XML.Element) THEN element := current(XML.Element) ELSE element := NIL END;
		END Exit;

		PROCEDURE WriteObject(CONST name: ARRAY OF CHAR; index: LONGINT; o: Object);
		VAR guid: LONGINT;
		BEGIN
			IF o # NIL THEN
				Enter(name,o);
				IF written.Enter(o,guid) THEN
					o.Write(SELF);
					IntegerAttribute("guid", guid);
				ELSE
					IntegerAttribute("guid_reference",guid)
				END;
				Exit(name);
			END;
		END WriteObject;

	END XMLWriter;

	ReadTable = OBJECT (Basic.List)

		PROCEDURE Enter(o: Object);
		BEGIN	 Add(o);
		END Enter;

		PROCEDURE GetObject(index: LONGINT): Object;
		BEGIN
			RETURN Get(index)(Object)
		END GetObject;

	END ReadTable;

	Element=POINTER TO RECORD
		index: LONGINT;
		e: XML.Element;
		next: Element;
	END;

	Symbol = POINTER TO RECORD
		name: LONGINT;
		first, last: Element;
		numberElements: LONGINT;
		next: Symbol;
	END;

	Stack = POINTER TO RECORD
		container: XML.Container;
		symbols: Basic.HashTableInt;
		firstSymbol: Symbol;
		used: Basic.HashTable;
		next: Stack
	END;

	Scope = OBJECT
	VAR
		stack: Stack;

		PROCEDURE & InitScope(c: XML.Container);
		BEGIN
			stack := NIL; Enter(c);
		END InitScope;

		PROCEDURE Enter(c: XML.Container);
		VAR new: Stack;
		BEGIN
			Use(c);
			NEW(new);
			new.container := c; NEW(new.symbols,32); NEW(new.used,4);
			new.next := stack;  new.firstSymbol := NIL;
			stack := new;
			Register(c);
		END Enter;

		PROCEDURE Register(c: XML.Container);
		VAR e: XML.Content;
		BEGIN
			e := c.GetFirst();
			WHILE e # NIL DO
				IF (e IS XML.Element) (* & ~scope.Used(e) *) THEN
					EnterElement(e(XML.Element));
				END;
				e := c.GetNext(e);
			END;
		END Register;

		PROCEDURE Exit(VAR c: XML.Container);
		BEGIN
			stack := stack.next;
			c := stack.container;
		END Exit;

		PROCEDURE Use(o: ANY);
		BEGIN
			IF (stack # NIL) & ~stack.used.Has(o) THEN stack.used.Put(o,o) END;
		END Use;

		PROCEDURE Used(o: ANY): BOOLEAN;
		BEGIN
			RETURN stack.used.Has(o)
		END Used;

		PROCEDURE AddSymbol(CONST name: ARRAY OF CHAR): Symbol;
		VAR id: LONGINT; any: ANY; symbol: Symbol;
		BEGIN
			id := StringPool.GetIndex1(name);
			any := stack.symbols.Get(id);
			IF any = NIL THEN
				NEW(symbol);
				stack.symbols.Put(id, symbol);
				symbol.name := id;
				symbol.next := stack.firstSymbol;
				symbol.numberElements := 0;
				stack.firstSymbol := symbol;
			ELSE
				symbol := any(Symbol)
			END;
			RETURN symbol
		END AddSymbol;

		PROCEDURE FindElement(CONST name: ARRAY OF CHAR; index: LONGINT): XML.Element;
		VAR id: LONGINT; any: ANY; symbol: Symbol; element: Element;
		BEGIN
			IF name = "" THEN
				symbol := stack.firstSymbol;
				WHILE (symbol # NIL) & (index >= symbol.numberElements) DO
					DEC(index, symbol.numberElements);
					symbol := symbol.next;
				END;
				IF symbol = NIL THEN RETURN NIL END;
			ELSE
				id := StringPool.GetIndex1(name);
				any := stack.symbols.Get(id);
				IF any = NIL THEN
					RETURN NIL
				ELSE
					symbol := any(Symbol)
				END;
			END;
			element := symbol.first;
			WHILE (element # NIL) &  (element.index < index) DO
				element := element.next;
			END;
			IF element = NIL THEN RETURN NIL
			ELSE RETURN element.e
			END;
		END FindElement;

		(* fifo *)
		PROCEDURE PutElement(symbol: Symbol; element: Element);
		BEGIN
			IF symbol.first = NIL THEN
				symbol.first := element; symbol.last := element; element.index := 0;
			ELSE
				element.index := symbol.last.index + 1;
				symbol.last.next := element; symbol.last := element
			END;
			INC(symbol.numberElements);
		END PutElement;

		PROCEDURE EnterElement(e: XML.Element);
		VAR name: Strings.String; symbol: Symbol; element: Element;
		BEGIN
			name := e.GetName();
			symbol := AddSymbol(name^);
			NEW(element); element.e := e;
			PutElement(symbol, element);
		END EnterElement;

		PROCEDURE Write(w: Streams.Writer);

			PROCEDURE WriteStack(s: Stack);
			VAR name: Strings.String;
			BEGIN
				IF s # NIL THEN
					WriteStack(s.next);
					IF s.container IS XML.Element THEN
						name := s.container(XML.Element).GetName();
						IF name # NIL THEN w.String("/"); w.String(name^) END
					END
				END;
			END WriteStack;

		BEGIN
			WriteStack(stack);
		END Write;

	END Scope;

	XMLReader* = OBJECT (Reader)
	VAR
		element: XML.Element;
		current: XML.Container;
		scope: Scope;
		read: ReadTable;

		PROCEDURE ReportXMLError(pos, line,col: LONGINT; CONST msg: ARRAY OF CHAR);
		BEGIN
			IF ~err THEN
				error.Char(CHR(9H)); error.Char(CHR(9H)); error.String("pos "); error.Int(pos, 6);
				error.String(", line "); error.Int(line, 0); error.String(", column "); error.Int(col, 0);
				error.String("    "); error.String(msg); error.Ln
			END;
			err := TRUE;
		END ReportXMLError;

		PROCEDURE & InitXMLReader*(reader: Streams.Reader; generator: Generator);
		VAR scanner: XMLScanner.Scanner; parser: XMLParser.Parser;
		BEGIN
			InitReader(generator);
			NEW(scanner, reader);
			NEW(parser, scanner);
			err := FALSE;
			parser.reportError := ReportXMLError;
			current := parser.Parse();
			NEW(scope, current);
			element := NIL;
			NEW(read,16);
		END InitXMLReader;

		PROCEDURE Error(CONST s1,s2: ARRAY OF CHAR);
		BEGIN
			err := TRUE;
			error.String("error in file "); error.String(filename); error.String(" ");
			error.String("in scope "); scope.Write(error); error.String(": "); error.String(s1); error.String(" "); error.String(s2); error.Ln;
			error.Update;
		END Error;

		PROCEDURE StringAttribute(CONST name: ARRAY OF CHAR; VAR str: Strings.String): BOOLEAN;
		BEGIN
			IF element # NIL THEN
				str := element.GetAttributeValue(name);
				scope.Use(element.GetAttribute(name));
			END;
			RETURN str # NIL;
		END StringAttribute;

		PROCEDURE Enter(CONST name: ARRAY OF CHAR; index: LONGINT; VAR o: Object): BOOLEAN;
		VAR e: XML.Element;
		BEGIN
			e := scope.FindElement(name, index);
			IF e # NIL THEN
				element := e;
				current := element;
				scope.Enter(current);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END;
		END Enter;

		PROCEDURE Exit(CONST name: ARRAY OF CHAR);
		BEGIN
			scope.Exit(current);
			IF current IS XML.Element THEN element := current(XML.Element) ELSE element := NIL END;
		END Exit;

		PROCEDURE CheckUse(o: ANY);
		VAR e: XML.Content; enum: XMLObjects.Enumerator; name: XML.String; a: ANY; n: ARRAY 512 OF CHAR;
			type: Modules.TypeDesc;
		BEGIN
			IF current IS XML.Element THEN
				enum := current(XML.Element).GetAttributes();
				WHILE enum.HasMoreElements() DO
					a := enum.GetNext();
					IF ~scope.Used(a) THEN
						name := a(XML.Attribute).GetName();
						type := Modules.TypeOf(o);
						COPY(name^, n);
						Strings.Append(n," in type ");
						Strings.Append(n, type.mod.name);
						Strings.Append(n,".");
						Strings.Append(n, type.name);
						Error("not used ", n);
					END;
				END;
			END;

			e := current.GetFirst();
			WHILE e # NIL DO
				IF (e IS XML.Element)  & ~scope.Used(e)  THEN
					name := e(XML.Element).GetName();
					type := Modules.TypeOf(o);
					COPY(name^, n);
					Strings.Append(n," in type ");
					Strings.Append(n,type.mod.name);
					Strings.Append(n,".");
					Strings.Append(n,type.name);
					Error("not used ", n);
				END;
				e := current.GetNext(e);
			END;
		END CheckUse;

		PROCEDURE ReadObject(CONST name, optionalType: ARRAY OF CHAR; index: LONGINT; VAR o: Object): BOOLEAN;
		VAR type: ARRAY 32 OF CHAR; id: LONGINT;
		BEGIN
			(*IF err THEN RETURN FALSE END;*)

			IF Enter(name, index, o) THEN
				IF IntegerAttribute("guid_reference", id) THEN
					o := read.GetObject(id);
				ELSE
					IF IntegerAttribute("guid", id) THEN (* ignore *) END;
					IF ~NameAttribute("type",type) THEN COPY(optionalType, type) END;
					o := generator(type);
					IF o = NIL THEN
						Error(name,"could not be created");
						Exit(name);
						RETURN FALSE
					ELSE
						read.Enter(o);
						IF ~o.Read(SELF) THEN
							Error(name,"could not be read");
						END;
					END;
				END;

				CheckUse(o);
				Exit(name);
				RETURN TRUE
			ELSE
				RETURN FALSE
			END;
		END ReadObject;

	END XMLReader;


PROCEDURE NewXMLWriter*(w: Streams.Writer): Writer;
VAR writer: XMLWriter;
BEGIN
	NEW(writer, w); RETURN writer
END NewXMLWriter;

PROCEDURE NewXMLReader*(r: Streams.Reader; generator: Generator): Reader;
VAR reader: XMLReader;
BEGIN
	NEW(reader, r, generator); RETURN reader
END NewXMLReader;

PROCEDURE Clone*(o: Object; gen: Generator): Object;
VAR w: XMLWriter; r : XMLReader; f: Files.File; writer: Files.Writer; reader: Files.Reader; clone: Object;
BEGIN
	f := Files.New(""); (* anonymous file *)
	Files.OpenWriter(writer,f,0);
	NEW(w, writer);
	w.WriteObject("object",None, o);
	w.Close;
	writer.Update;

	NEW(reader, f, 0);
	NEW(r,reader, gen);
	IF ~r.ReadObject("object","",None, clone) THEN TRACE(clone) END;
	RETURN clone
END Clone;

PROCEDURE Trace*(o: Object);
VAR w: Streams.Writer; writer: Writer;
BEGIN
	writer := NewXMLWriter(D.Log);
	writer.WriteObject("specification", None, o);
	writer.Close;
	D.Ln;
END Trace;



END PersistentObjects.
