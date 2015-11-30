MODULE VirtualKBD;(** AUTHOR "BohdanT"; PURPOSE "need for use"; *)
IMPORT Strings,Files, XML,XMLScanner,XMLParser,XMLObjects, Inputs,TFClasses;
TYPE
	KeyCap* = ARRAY 16 OF CHAR;
	VKey* = OBJECT
		VAR
			c1*,c2*, (*Key code Normal/Caps*)
			cap1*,cap2*: KeyCap ; (*Key caption Normal/Caps*)
			l*,t*: LONGINT;
			height*: LONGINT;
			width*: LONGINT;
			scan*: LONGINT;(*Key Scan code*)
			data*:ANY;(*link to visual button*)
		PROCEDURE &Init;
		BEGIN
		END Init;

	END VKey;

	Keyboard* = OBJECT
	VAR
		name*:ARRAY 32 OF CHAR;
		file*:ARRAY 128 OF CHAR;
	END Keyboard;

	VKeyList* = OBJECT(TFClasses.List)
		VAR
			l*,t*:LONGINT;
	END VKeyList;
VAR
 keys*:VKeyList;
 keyBoards*:TFClasses.List;

(**  value *)
PROCEDURE StringToKeysym(CONST string : ARRAY OF CHAR) : LONGINT;
VAR keysym : LONGINT;
BEGIN
	keysym := -1;(*//NoKeysym;*)
	IF Strings.Match("BACKSPACE", string) THEN keysym := Inputs.KsBackSpace;
	ELSIF Strings.Match("TAB", string) THEN keysym := Inputs.KsTab;
	ELSIF Strings.Match("RETURN", string) THEN keysym := Inputs.KsReturn;
	ELSIF Strings.Match("PAUSE", string) THEN keysym := Inputs.KsPause;
	ELSIF Strings.Match("SCROLLLOCK", string) THEN keysym := Inputs.KsScrollLock;
	ELSIF Strings.Match("SYS", string) OR Strings.Match("SYSREQ", string) THEN keysym := Inputs.KsSysReq;
	ELSIF Strings.Match("ESC", string) OR Strings.Match("ESCAPE", string) THEN keysym := Inputs.KsEscape;
	ELSIF Strings.Match("DEL", string) OR Strings.Match("DELETE", string) THEN keysym := Inputs.KsDelete;
	ELSIF Strings.Match("HOME", string) THEN keysym := Inputs.KsHome;
	ELSIF Strings.Match("LEFT", string) THEN keysym := Inputs.KsLeft;
	ELSIF Strings.Match("UP", string) THEN keysym := Inputs.KsUp;
	ELSIF Strings.Match("RIGHT", string) THEN keysym := Inputs.KsRight;
	ELSIF Strings.Match("DOWN", string) THEN keysym := Inputs.KsDown;
	ELSIF Strings.Match("PAGEUP", string) THEN keysym := Inputs.KsPageUp;
	ELSIF Strings.Match("PAGEDOWN", string) THEN keysym := Inputs.KsPageDown;
	ELSIF Strings.Match("END", string) THEN keysym := Inputs.KsEnd;
	ELSIF Strings.Match("PRINT", string) THEN keysym := Inputs.KsPrint;
	ELSIF Strings.Match("INS", string) OR Strings.Match("INSERT", string) THEN keysym := Inputs.KsInsert;
	ELSIF Strings.Match("MENU", string) THEN keysym := Inputs.KsMenu;
	ELSIF Strings.Match("BREAK", string) THEN keysym := Inputs.KsBreak;
	ELSIF Strings.Match("NUMLOCK", string) THEN keysym := Inputs.KsNumLock;
	ELSIF Strings.Match("KPENTER", string) THEN keysym := Inputs.KsKPEnter;
	ELSIF Strings.Match("KPMULTIPLY", string) THEN keysym := Inputs.KsKPMultiply;
	ELSIF Strings.Match("KPADD", string) THEN keysym := Inputs.KsKPAdd;
	ELSIF Strings.Match("KPSUB", string) OR Strings.Match("KPSUBTRACT", string) THEN keysym := Inputs.KsKPSubtract;
	ELSIF Strings.Match("KPDECIMAL", string) THEN keysym := Inputs.KsKPDecimal;
	ELSIF Strings.Match("KPDIV", string) OR Strings.Match("KPDIVIDE", string) THEN keysym := Inputs.KsKPDivide;
	ELSIF Strings.Match("F1", string) THEN keysym := Inputs.KsF1;
	ELSIF Strings.Match("F2", string) THEN keysym := Inputs.KsF2;
	ELSIF Strings.Match("F3", string) THEN keysym := Inputs.KsF3;
	ELSIF Strings.Match("F4", string) THEN keysym := Inputs.KsF4;
	ELSIF Strings.Match("F5", string) THEN keysym := Inputs.KsF5;
	ELSIF Strings.Match("F6", string) THEN keysym := Inputs.KsF6;
	ELSIF Strings.Match("F7", string) THEN keysym := Inputs.KsF7;
	ELSIF Strings.Match("F8", string) THEN keysym := Inputs.KsF8;
	ELSIF Strings.Match("F9", string) THEN keysym := Inputs.KsF9;
	ELSIF Strings.Match("F10", string) THEN keysym := Inputs.KsF10;
	ELSIF Strings.Match("F11", string) THEN keysym := Inputs.KsF11;
	ELSIF Strings.Match("F12", string) THEN keysym := Inputs.KsF12;
	END;
	RETURN keysym;
END StringToKeysym;

PROCEDURE LoadVKeyTable* (CONST filename: ARRAY OF CHAR);
VAR
	f: Files.File; reader: Files.Reader;
	scanner: XMLScanner.Scanner; parser: XMLParser.Parser;
	xmlVKeys : XML.Document; enum: XMLObjects.Enumerator;
	e : XML.Element; 
	s : XML.String;
	p : ANY;
	maxl,l,t,dw,dh:LONGINT;
	PROCEDURE ReadLine(enum: XMLObjects.Enumerator);
	VAR
		e : XML.Element; 
		s : XML.String;
		ch : VKey;
	BEGIN
		l:=0;
		WHILE enum.HasMoreElements() DO
			p := enum.GetNext();
			IF p IS XML.Element THEN
				e := p(XML.Element);
				s := e.GetName();
				IF (s # NIL) & (s^ = "key") THEN
					NEW(ch);
					s := e.GetAttributeValue ("c1");
					IF s # NIL THEN
						COPY (s^, ch.c1);ch.cap1:=ch.c1;
						keys.Add(ch);
						s := e.GetAttributeValue ("c2");
						IF s # NIL THEN
							COPY (s^, ch.c2);ch.cap2:=ch.c2;
						END;
					END;
					s := e.GetAttributeValue ("scan");
					IF s#NIL THEN
						ch.scan:=StringToKeysym(s^)
					END;
						
					s := e.GetAttributeValue ("width");
					IF s#NIL THEN
						Strings.StrToInt (s^, ch.width)
					ELSE
						ch.width:=dw;
					END;
					s := e.GetAttributeValue ("height");
					IF s#NIL THEN
						Strings.StrToInt (s^, ch.height)
					ELSE
						ch.height:=dh;
					END;
					ch.l:=l; l:=l+ch.width;ch.t:=t;
				END;
			END;
		END;
		t:=t+dh;
		IF l>maxl THEN maxl:=l; END;
	END ReadLine;

BEGIN
	IF keys = NIL THEN
		NEW(keys)
	END;
	keys.Clear;
	t:=0;l:=0;maxl:=0;
	xmlVKeys := NIL;
	f := Files.Old (filename);
	IF f # NIL THEN
		NEW(reader, f, 0);
		NEW(scanner, reader);
		NEW(parser, scanner);
		xmlVKeys := parser.Parse();
		IF xmlVKeys # NIL THEN
			e := xmlVKeys.GetRoot();
			enum := e.GetContents();
			WHILE enum.HasMoreElements() DO
				p := enum.GetNext();
				IF p IS XML.Element THEN
					e := p(XML.Element);
					s := e.GetName();
					IF (s # NIL) & (s^ = "Line") THEN
						s := e.GetAttributeValue ("width");
						IF s#NIL THEN
							Strings.StrToInt (s^, dw)
						ELSE
							dw:=54;
						END;
						s := e.GetAttributeValue ("height");
						IF s#NIL THEN
							Strings.StrToInt (s^, dh)
						ELSE
							dh:=54;
						END;
						ReadLine(e.GetContents());
					END
				END
			END
		END
	END;
	keys.l:=maxl;
	keys.t:=t;
END LoadVKeyTable;
END VirtualKBD.