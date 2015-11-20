(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Configuration; (** AUTHOR "pjm"; PURPOSE "XML-based configuration"; *)

IMPORT KernelLog, Strings, Files, XMLObjects, XML, XMLScanner, XMLParser;

CONST
	Ok* = 0;
	ElementNotFound* = 10001;
	AttributeNotFound* = 10002;
	WrongType* = 10003;
	Error* = 10004;

	SaveConfigFile = "Save.Configuration.XML";
	MyConfigFile = "MyConfiguration.XML";
	ConfigFile = "Configuration.XML";

	(* element and attribute names - must match DTD in ConfigFile *)
	Section = "Section"; Setting = "Setting";
	NameAttr = "name"; ValueAttr = "value";

VAR
	config*: XML.Document;	(** internalized config file *)
	error : BOOLEAN;

(** In the children of element "parent", find an element with name "type" and "NameAttr" attribute "name". *)
PROCEDURE GetNamedElement*(parent: XML.Element; CONST type, name: ARRAY OF CHAR): XML.Element;
VAR enum: XMLObjects.Enumerator; p: ANY; e: XML.Element; s: XML.String;
BEGIN
	enum := parent.GetContents();
	WHILE enum.HasMoreElements() DO
		p := enum.GetNext();
		IF p IS XML.Element THEN
			e := p(XML.Element); s := e.GetName();
			IF (s # NIL) & (s^ = type) THEN	(* correct element name *)
				s := e.GetAttributeValue(NameAttr);
				IF (s # NIL) & (s^ = name) THEN	(* correct element name attribute *)
					RETURN e
				END
			END
		END
	END;
	RETURN NIL
END GetNamedElement;

PROCEDURE GetSection*(CONST key : ARRAY OF CHAR) : XML.Element;
BEGIN {EXCLUSIVE}
	RETURN GetElementX(Section, key);
END GetSection;

PROCEDURE GetSetting*(CONST key : ARRAY OF CHAR) : XML.Element;
BEGIN {EXCLUSIVE}
	RETURN GetElementX(Setting, key);
END GetSetting;

PROCEDURE GetElementX(CONST type, key : ARRAY OF CHAR) : XML.Element;
VAR e : XML.Element; name : ARRAY 64 OF CHAR; i, j : LONGINT;
BEGIN
	IF (config # NIL) THEN
		i := 0; e := config.GetRoot();
		WHILE (e # NIL) DO
			j := 0; WHILE (key[i] # 0X) & (key[i] # ".") DO name[j] := key[i]; INC(i); INC(j) END;
			name[j] := 0X;
			IF key[i] = 0X THEN	(* look for setting *)
				e := GetNamedElement(e, type, name);
				IF e # NIL THEN	(* found *)
					RETURN e;
				END
			ELSE	(* look for section *)
				INC(i);	(* skip '.' *)
				e := GetNamedElement(e, Section, name);
			END;
		END;
	END;
	RETURN NIL;
END GetElementX;

(** 	Find the setting specified by the key, which is a path name through the sections to the setting, and return its value. *)
PROCEDURE Get*(CONST key: ARRAY OF CHAR; VAR val: ARRAY OF CHAR; VAR res : LONGINT);
VAR e: XML.Element; s: Strings.String; a: XML.Attribute;
BEGIN {EXCLUSIVE}
	e := GetElementX(Setting, key);
	IF (e # NIL) THEN
		s := e.GetName();
		IF (s # NIL) & (s^ = Setting) THEN
			a := e.GetAttribute(ValueAttr);
			IF (a # NIL) THEN
				s := a.GetValue();
				IF (s # NIL) THEN
					IF (Strings.Length(s^) < LEN(val)) THEN
						COPY(s^, val);
						res := Ok;
					ELSE
						res := Error;
					END;
				ELSE
					res := Error;
				END
			ELSE
				res := AttributeNotFound;
			END;
		ELSE
			res := Error;
		END;
	ELSE
		res := ElementNotFound;
	END;
END Get;

PROCEDURE GetBoolean*(CONST key : ARRAY OF CHAR; VAR value : BOOLEAN; VAR res : LONGINT);
VAR string : ARRAY 8 OF CHAR;
BEGIN
	Get(key, string, res);
	IF (res = Ok) THEN
		Strings.UpperCase(string);
		Strings.TrimWS(string);
		IF (string = "TRUE") THEN value := TRUE;
		ELSIF (string = "FALSE") THEN value := FALSE;
		ELSE
			res := WrongType;
		END;
	END;
END GetBoolean;

PROCEDURE GetColor*(CONST key : ARRAY OF CHAR; VAR value : LONGINT; VAR res : LONGINT);
VAR string : ARRAY 16 OF CHAR; tempres : LONGINT;
BEGIN
	Get(key, string, res);
	IF (res = Ok) THEN
		Strings.TrimWS(string);
		Strings.HexStrToInt(string, value, tempres);
		IF tempres # Strings.Ok THEN res := Error; END;
	END;
END GetColor;


PROCEDURE GetInteger*(CONST key : ARRAY OF CHAR; VAR value : LONGINT; VAR res : LONGINT);
VAR string : ARRAY 16 OF CHAR;
BEGIN
	Get(key, string, res);
	IF (res = Ok) THEN
		Strings.TrimWS(string);
		Strings.StrToInt(string, value);
	END;
END GetInteger;

(** update (or insert if necessairy) the setting specified by the key. if the specified section/setting is not yet existing, it will be created *)
PROCEDURE Put*(CONST key, val : ARRAY OF CHAR; VAR res : LONGINT);
VAR e, child : XML.Element; i, j : LONGINT; name : ARRAY 64 OF CHAR;
BEGIN {EXCLUSIVE}
	res := Ok;
	IF config # NIL THEN
		i := 0; e := config.GetRoot();
		WHILE key[i] # 0X DO
			j := 0; WHILE (key[i] # 0X) & (key[i] # '.') DO name[j] := key[i]; INC(i); INC(j) END;
			IF key[i] = '.' THEN (* section *)
				child := GetNamedElement(e, Section, name);
				IF child = NIL THEN (* create section *)
					NEW(child); e.AddContent(child);
					child.SetName(Section); child.SetAttributeValue("name", name)
				END;
				e := child; INC(i) (* skip '.' *)
			ELSE (* setting *)
				child := GetNamedElement(e, Setting, name);
				IF child = NIL THEN (* create setting *)
					NEW(child); e.AddContent(child);
					child.SetName(Setting); child.SetAttributeValue("name", name)
				END;
				child.SetAttributeValue("value", val)
			END
		END;
		WriteConfig();
	ELSE
		res := Error;
	END
END Put;

PROCEDURE PutBoolean*(CONST key : ARRAY OF CHAR; value : BOOLEAN; VAR res : LONGINT);
BEGIN
	IF value THEN Put(key, "TRUE", res) ELSE Put(key, "FALSE", res); END;
END PutBoolean;

PROCEDURE PutColor*(CONST key : ARRAY OF CHAR; value : LONGINT; VAR res : LONGINT);
VAR string : ARRAY 9 OF CHAR;
BEGIN
	Strings.IntToHexStr(value, 8, string);
	Put(key, string, res);
END PutColor;

PROCEDURE PutInteger*(CONST key : ARRAY OF CHAR; value : LONGINT; VAR res : LONGINT);
VAR string : ARRAY 16 OF CHAR;
BEGIN
	Strings.IntToStr(value, string);
	Put(key, string, res);
END PutInteger;

PROCEDURE WriteConfig;
VAR f : Files.File; out : Files.Writer;
BEGIN
	IF config # NIL THEN
		f := Files.New(ConfigFile);
		Files.OpenWriter(out, f, 0);
		config.Write(out, NIL, 0);
		out.Update();
		Files.Register(f)
	END
END WriteConfig;

PROCEDURE TrapHandler(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
BEGIN
	IF ~error THEN
		KernelLog.String("Error in ");
		KernelLog.String(ConfigFile);
		KernelLog.String(" at position ");
		KernelLog.String("pos= "); KernelLog.Int(pos, 0); KernelLog.String(" line= "); KernelLog.Int(line, 0); KernelLog.String(" row= "); KernelLog.Int(row, 0);
		KernelLog.String(" switching to "); KernelLog.String(SaveConfigFile); KernelLog.String(" !"); KernelLog.Ln
	ELSE
		KernelLog.String("Error in ");
		KernelLog.String(SaveConfigFile); KernelLog.String(" giving up!"); KernelLog.Ln;
	END;
	error := TRUE; config := NIL
END TrapHandler;

(** Internalize the config file. *)
PROCEDURE Init*;
VAR f: Files.File; scanner: XMLScanner.Scanner; parser: XMLParser.Parser; r: Files.Reader;
BEGIN {EXCLUSIVE}
	error := FALSE;
	config := NIL;
	f := Files.Old(MyConfigFile);
	IF f = NIL THEN
		f := Files.Old(ConfigFile);
	END;
	IF f # NIL THEN
		NEW(r, f, 0);
		NEW(scanner, r); NEW(parser, scanner); parser.reportError := TrapHandler; config := parser.Parse();
		IF error THEN
			f := Files.Old(SaveConfigFile);
			IF f # NIL THEN
				NEW(r, f, 0);
				NEW(scanner, r); NEW(parser, scanner); parser.reportError := TrapHandler; config := parser.Parse()
			END
		END
	END;
END Init;

BEGIN
	Init;
END Configuration.

SystemTools.Free Configuration ~

PET.Open Configuration.XML

