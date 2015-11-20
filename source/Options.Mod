MODULE Options; (** AUTHOR "staubesv"; PURPOSE "Command line options parsing"; *)
(*
 * Simple framework that parses command line options.
 *
 * Usage:
 *
 *	1. 	Create Option object instance
 *
 *			NEW(options);
 *
 *	2.	Add options of type Flag, String or Integer
 *
 *			options.Add("h", "help", Flag);   			(* -h / --help option flags *)
 *			options.Add("s", "string", String); 		(* -s=Hello / --string="Hello World" *)
 *			options.Add("i", "integer", Integer); 		(* -i=76H / --integer=999 *)
 *
 *	3.	Parse options at the current position of the context argument stream (this will skip whitespace and options on the stream)
 *
 *			IF options.Parse(context.arg, context.out) THEN (* some useful work *) END;
 *
 *		Note: Parse will output an error message on the context error stream if option parsing fails
 *
 *	4.	Access options
 *
 *			IF options.GetFlag("help") THEN (* flag -h or --help is set *) END;
 *			IF options.GetString("string", string_variable) THEN
 *				(* If -s or --string was set, read the string argument into the string-variable *)
 *			END;
 *
 *
 * Options			= [ "-" Option [ {WhiteSpace "-" Option} ] ]
 * Option 			= "-" NameOption | CharOption
 * NameOption		= Name [Assignment]
 * CharOption		= Char [Assignment] | Flags
 * Flags =			= Char {Char}
 * Assignment 		= "=" (EnquotedString | Name | Char)
 * Name			=  Char Char {Char}
 * EnquotedString 	= " anyChars except quote " | ' anyChars except apostroph  '
 * Char 				= (32 < ORD(CHAR) < 127) & (ch # Assignment) & (ch # OptionDelimiter)
 *)

IMPORT
	KernelLog, Streams, Commands;

CONST

	(** Option Types *)
	Flag* = 0;
	String* = 1;
	Integer* = 2;

	Unknown = -1;

	MaxOptions = 64;

	OptionDelimiter = "-";
	Assignment = "=";

	Invalid = -1;

TYPE

	Name* = ARRAY 32 OF CHAR;
	Parameter* = ARRAY 256 OF CHAR;

	Option = RECORD
		isSet : BOOLEAN;
		timestamp : LONGINT;
		ch : CHAR; (* single character name *)
		name : Name; (* multi character name *)
		type : LONGINT; (* Flag, String or Integer *)
		value : LONGINT; (* Integer value if type = Integer *)
		string : Parameter; (* String value if type = String *)
	END;

TYPE

	Options* = OBJECT
	VAR
		options : ARRAY MaxOptions OF Option;
		nofOptions : LONGINT;

		arg : Streams.Reader;
		error : Streams.Writer;
		setError : BOOLEAN;

		timestamp : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			timestamp := 0;
			Reset;
		END Init;



		(**	Add option declaration.
			- Duplicate names are not allowed!
			- Numbers are not allowed as option character or as first character of an option name *)
		PROCEDURE Add*(ch : CHAR; CONST name : Name; type : LONGINT);
		VAR index : LONGINT; char : Name;
		BEGIN {EXCLUSIVE}
			IF (("0" <= ch) & (ch <= "9")) OR (("0" <= name[0]) & (name[0] <= "9")) THEN
				KernelLog.String("Command implementation error: Numbers are not allowed as first character of an option name. Ignore option ");
				KernelLog.Ln;
				RETURN;
			END;

			char[0] := ch; char[1] := 0X;
			index := FindOption(char);
			IF (index = Invalid) THEN index := FindOption(name); END;
			IF (index = Invalid) THEN
				IF (nofOptions < MaxOptions-1) THEN
					options[nofOptions].isSet := FALSE;
					options[nofOptions].ch := ch;
					options[nofOptions].name := name;
					options[nofOptions].type := type;
					INC(nofOptions);
				ELSE
					KernelLog.String("Command implementation error: Maximum number of option declarations exceeded. Ignore option ");
					KernelLog.Ln;
				END;
			ELSE
				KernelLog.String("Command implementation error: Duplicate option declaration. Ignore option .");
				KernelLog.Ln;
			END;
		END Add;

		(** Check whether an option of type Flag is set *)
		PROCEDURE GetFlag*(CONST name : Name) : BOOLEAN;
		VAR index : LONGINT;
		BEGIN {EXCLUSIVE}
			index := FindOption(name);
			IF (index # Invalid) THEN
				IF (options[index].type = Flag) THEN
					RETURN options[index].isSet;
				ELSE
					WrongUsage(options[index]);
				END;
			END;
			RETURN FALSE;
		END GetFlag;

		PROCEDURE SetFlag*(ch : CHAR; CONST name : Name) : BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN SetFlagIntern(ch, name, FALSE);
		END SetFlag;

		(** Check whether an option of type Integer is set and retrieve its value if so *)
		PROCEDURE GetInteger*( CONST name : Name; VAR integer : LONGINT) : BOOLEAN;
		VAR index : LONGINT;
		BEGIN {EXCLUSIVE}
			index := FindOption(name);
			IF (index # Invalid) THEN
				IF (options[index].type = Integer) THEN
					IF (options[index].isSet) THEN
						integer := options[index].value;
						RETURN TRUE;
					END;
				ELSE
					WrongUsage(options[index]);
				END;
			END;
			RETURN FALSE;
		END GetInteger;

		PROCEDURE SetInteger*(ch : CHAR; CONST name : Name; CONST string : ARRAY OF CHAR) : BOOLEAN;
		VAR index : LONGINT; optionName : Name;
		BEGIN {EXCLUSIVE}
			IF (ch = 0X) THEN optionName := name; ELSE optionName[0] := ch; optionName[1] := 0X; END;
			index := FindOption(optionName);
			IF (index # Invalid) & (options[index].type = Integer) THEN
				options[index].timestamp := timestamp;
				options[index].isSet := TRUE;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END SetInteger;

		(** Check whether an option of type String is set and retrieve its value if so *)
		PROCEDURE GetString*(CONST name : Name; VAR string : ARRAY OF CHAR) : BOOLEAN;
		VAR index : LONGINT;
		BEGIN {EXCLUSIVE}
			index := FindOption(name);
			IF (index # Invalid) THEN
				IF (options[index].type = String) THEN
					IF (options[index].isSet) THEN
						COPY(options[index].string, string);
						RETURN TRUE;
					END;
				ELSE
					WrongUsage(options[index]);
				END;
			END;
			RETURN FALSE;
		END GetString;

		PROCEDURE SetString*(ch : CHAR; CONST name : Name; CONST string : ARRAY OF CHAR) : BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN SetStringIntern(ch, name, string, FALSE);
		END SetString;

		(** Unset all options *)
		PROCEDURE Clear*;
		VAR i : LONGINT;
		BEGIN {EXCLUSIVE}
			FOR i :=	 0 TO nofOptions-1 DO
				options[i].isSet := FALSE;
			END;
		END Clear;

		(** Remove all declared options *)
		PROCEDURE Reset*;
		VAR i : LONGINT;
		BEGIN {EXCLUSIVE}
			nofOptions := 0; timestamp := 0;
			FOR i := 0 TO MaxOptions-1 DO
				options[i].isSet := FALSE;
				options[i].timestamp := 0;
				options[i].ch := 0X;
				options[i].name := "";
				options[i].type := Unknown;
				options[i].value := 0;
				options[i].string := "";
			END;
			setError := FALSE;
		END Reset;

		(** 	Parse options from the argument stream starting at the current position (skip whitespace).
			The actual options will be set as side effect when parsing.
		*)
		PROCEDURE Parse*(arg : Streams.Reader; error : Streams.Writer) : BOOLEAN;
		VAR succeeded : BOOLEAN;
		BEGIN {EXCLUSIVE}
			ASSERT(arg # NIL);
			SELF.arg := arg; SELF.error := error;
			INC(timestamp);
			arg.SkipWhitespace;
			setError := FALSE;
			succeeded := ParseOptions() & ~setError;
			IF ~succeeded & (error # NIL) THEN error.Update; END;
			RETURN succeeded;
		END Parse;

		PROCEDURE ParseString*(CONST string : ARRAY OF CHAR; error : Streams.Writer) : BOOLEAN;
		VAR reader : Streams.StringReader;
		BEGIN
			NEW(reader, LEN(string)); reader.SetRaw(string, 0, LEN(string));
			RETURN Parse(reader, error);
		END ParseString;

		(* Options = [ "-" Option [ WhiteSpace { "-" Option} ] ] *)
		PROCEDURE ParseOptions() : BOOLEAN;
		VAR ch : CHAR; oldPos : LONGINT;
		BEGIN
			oldPos := arg.Pos();
			ch := arg.Peek();
			WHILE (ch = OptionDelimiter) DO
				arg.Char(ch); (* consume OptionDelimiter *)
				ch := arg.Peek();
				IF ("0" <= ch) & (ch <= "9") THEN
					IF arg.CanSetPos() THEN
						arg.SetPos(oldPos);
					ELSE
						KernelLog.String("Options.ParseOptions: Warning: Streams integrity destroyed..."); KernelLog.Ln;
					END;
					RETURN TRUE;
				END;
				IF ~ParseOption() THEN
					RETURN FALSE;
				END;
				oldPos := arg.Pos();
				arg.SkipWhitespace;
				ch := arg.Peek();
			END;
			RETURN TRUE;
		END ParseOptions;

		(* Option = "-" NameOption | CharOption *)
		PROCEDURE ParseOption() : BOOLEAN;
		VAR ch : CHAR;
		BEGIN
			ch := arg.Peek();
			IF (ch = OptionDelimiter) THEN
				arg.Char(ch); (* consume OptionDelimiter *)
				RETURN ParseNameOption();
			ELSIF IsValidChar(ch) THEN
				RETURN ParseCharOption();
			ELSE
				IF (error # NIL) THEN
					ShowPos(arg.Pos());
					error.String('Expected "'); error.Char(OptionDelimiter);
					error.String('" or valid option char'); error.Ln;
				END;
				RETURN FALSE;
			END;
		END ParseOption;

		(*  NameOption	 = Name [Assignment] *)
		PROCEDURE ParseNameOption() : BOOLEAN;
		VAR ch : CHAR; name : Name; parameter : Parameter; ignoreHere : BOOLEAN;
		BEGIN
			IF ParseName(name, 0X) THEN
				ch := arg.Peek();
				IF (ch = Assignment) THEN
					IF ParseAssignment(parameter) THEN
						ignoreHere := SetStringIntern(0X, name, parameter, TRUE);
						RETURN TRUE;
					END;
				ELSIF (ch > " ") THEN
					IF (error # NIL) THEN
						ShowPos(arg.Pos());
						error.String("Expected white space"); error.Ln;
					END;
				ELSE
					ignoreHere := SetFlagIntern(0X, name, TRUE);
					RETURN TRUE;
				END;
			END;
			RETURN FALSE;
		END ParseNameOption;

		(*  Name = Char Char {Char} *)
		PROCEDURE ParseName(VAR name : ARRAY OF CHAR; firstChar : CHAR) : BOOLEAN;
		VAR ch : CHAR; i : LONGINT; pos : LONGINT;
		BEGIN
			pos := arg.Pos();
			IF (firstChar # 0X) OR ParseChar(name[0]) THEN
				IF ParseChar(name[1]) THEN
					i := 2;
					ch := arg.Peek();
					WHILE (i < LEN(name)-1) & IsValidChar(ch) DO
						arg.Char(name[i]); INC(i);
						ch := arg.Peek();
					END;
					name[i] := 0X;
					IF (i >= LEN(name)-1) & IsValidChar(ch) THEN
						IF (error # NIL) THEN ShowPos(pos); error.String(": Name is too long"); error.Ln; END;
					ELSE
						RETURN TRUE;
					END;
				END;
			END;
			RETURN FALSE;
		END ParseName;

		(* CharOption = Char [Assignment] | Flags *)
		PROCEDURE ParseCharOption() : BOOLEAN;
		VAR ch, optionChar : CHAR; parameter : Parameter; ignoreHere : BOOLEAN; count : LONGINT;
		BEGIN
			IF ParseChar(optionChar) THEN
				ch := arg.Peek();
				IF (ch = Assignment) THEN (* Char [Assignment] *)
					IF ParseAssignment(parameter) THEN
						ignoreHere := SetStringIntern(optionChar, "", parameter, TRUE);
						RETURN TRUE;
					ELSE
						RETURN FALSE;
					END;
				END;

				ignoreHere := SetFlagIntern(optionChar, "", TRUE);

				count := 1;
				ch := arg.Peek();
				WHILE IsValidChar(ch) & (count <= MaxOptions) DO (* Flags *)
					arg.Char(optionChar);
					ignoreHere := SetFlagIntern(optionChar, "", TRUE);
					INC(count);
					ch := arg.Peek();
				END;
				IF (ch = Assignment) THEN
					IF (error # NIL) THEN ShowPos(arg.Pos()); error.String(": Assignment to set of flags not allowed"); error.Ln; END;
				ELSIF (ch <= " ") THEN
					RETURN TRUE;
				ELSIF (count > MaxOptions) THEN
					(* SetFlagIntern will report this error *)
				ELSE
					IF (error # NIL) THEN ShowPos(arg.Pos()); error.String(": Expected option character"); error.Ln; END;
				END;
			END;
			RETURN FALSE;
		END ParseCharOption;

		(* Assignment  = "=" (EnquotedString | Name | Char) *)
		PROCEDURE ParseAssignment(VAR parameter : Parameter) : BOOLEAN;
		VAR ch : CHAR; delimiter : CHAR; i : LONGINT;
		BEGIN
			arg.Char(ch);
			ASSERT(ch = Assignment);
			ch := arg.Peek();
			IF (ch = '"') OR (ch = "'") THEN
				arg.Char(delimiter);
				ch := arg.Peek();
				i := 0;
				WHILE (i < LEN(parameter)-1) & (ch # delimiter) DO
					arg.Char(parameter[i]); INC(i);
					ch := arg.Peek();
				END;
				IF (ch = delimiter) THEN
					arg.Char(ch); (* consume delimiter *)
					RETURN TRUE;
				ELSIF (error #NIL) THEN
					ShowPos(arg.Pos());
					error.String("Parameter is too long"); error.Ln;
					error.Update;
				END;
			ELSIF IsValidChar(ch) THEN
				arg.Char(parameter[0]);
				ch := arg.Peek();
				IF IsValidChar(ch) THEN (* Name *)
					RETURN ParseName(parameter, ch);
				ELSE (* Char *)
					parameter[1] := 0X;
					RETURN TRUE;
				END;
			ELSIF (error # NIL) THEN
				ShowPos(arg.Pos());
				error.String("Expected assignment value"); error.Ln;
				error.Update;
			END;
			RETURN FALSE;
		END ParseAssignment;

		PROCEDURE ParseChar(VAR ch : CHAR) : BOOLEAN;
		BEGIN
			ch := arg.Peek();
			IF IsValidChar(ch) THEN
				arg.Char(ch);
				RETURN TRUE;
			ELSE
				IF (error # NIL) THEN
					ShowPos(arg.Pos());
					error.String("Expected option character"); error.Ln;
					error.Update;
				END;
				RETURN FALSE;
			END;
		END ParseChar;

		PROCEDURE SetFlagIntern(ch : CHAR; CONST name : Name; checkTimestamp : BOOLEAN) : BOOLEAN;
		VAR index : LONGINT; optionName : Name;
		BEGIN
			IF (ch = 0X) THEN optionName := name; ELSE optionName[0] := ch; optionName[1] := 0X; END;
			index := FindOption(optionName);
			IF (index # Invalid) THEN
				IF ~checkTimestamp OR (options[index].timestamp < timestamp) THEN
					IF (options[index].type = Flag) THEN
						options[index].timestamp := timestamp;
						options[index].isSet := TRUE;
						RETURN TRUE;
					ELSIF (error # NIL) THEN
						error.String("Option "); ShowOption(ch, name);
						error.String(" requires a parameter"); error.Ln;
					END;
				ELSIF (error # NIL) THEN
					error.String("Option "); ShowOption(ch, name);
					error.String(" set multiple times"); error.Ln;
				END;
			ELSIF (error # NIL) THEN
				error.String("Unknown option "); ShowOption(ch, name); error.Ln;
			END;
			setError := TRUE;
			RETURN FALSE;
		END SetFlagIntern;

		PROCEDURE SetStringIntern(ch : CHAR; CONST name : Name; CONST string : ARRAY OF CHAR; checkTimestamp : BOOLEAN) : BOOLEAN;
		VAR index : LONGINT; optionName : Name;
		BEGIN
			IF (ch = 0X) THEN optionName := name; ELSE optionName[0] := ch; optionName[1] := 0X; END;
			index := FindOption(optionName);
			IF (index # Invalid) THEN
				IF ~checkTimestamp OR (options[index].timestamp < timestamp) THEN
					IF (options[index].type = String) THEN
						options[index].timestamp := timestamp;
						options[index].isSet := TRUE;
						COPY(string, options[index].string);
						RETURN TRUE;
					ELSIF (options[index].type = Integer) THEN
						options[index].timestamp := timestamp;
						IF StringToInteger(string, options[index].value, TRUE) THEN
							options[index].isSet := TRUE;
							RETURN TRUE;
						ELSIF (error # NIL) THEN
							error.String("Option "); ShowOption(ch, name);
							error.String(" expects decimal number as parameter"); error.Ln;
						END;
					ELSIF (error # NIL) THEN
						error.String("Option "); ShowOption(ch, name);
						error.String(" does not have a parameter"); error.Ln;
					END;
				ELSIF (error # NIL) THEN
					error.String("Option "); ShowOption(ch, name);
					error.String(" set multiple times"); error.Ln;
				END;
			ELSIF (error # NIL) THEN
				error.String("Unknown option "); ShowOption(ch, name); error.Ln;
			END;
			setError := TRUE;
			RETURN FALSE;
		END SetStringIntern;

		(* Returns the index of option with character 'ch' or name 'name' or Invalid, if option not found *)
		PROCEDURE FindOption(CONST name : Name) : LONGINT;
		VAR ch : CHAR;  i : LONGINT;
		BEGIN
			IF (name[1] = 0X) THEN ch := name[0]; ELSE ch := 0X; END;
			FOR i := 0 TO nofOptions-1 DO
				IF ((options[i].ch # 0X) & (options[i].ch = ch)) OR ((options[i].name # "") & (options[i].name = name)) THEN
					RETURN i;
				END;
			END;
			RETURN Invalid;
		END FindOption;

		PROCEDURE WrongUsage(option : Option);
		BEGIN
			IF (error # NIL) THEN
				error.String("Warning: Option declaration does not match option usage.");
				error.Ln; error.Update;
			END;
		END WrongUsage;

		PROCEDURE ShowPos(pos : LONGINT);
		BEGIN
			IF (error # NIL) THEN
				error.String("Pos "); error.Int(pos, 2); error.String(": ");
			END;
		END ShowPos;

		PROCEDURE ShowOption(ch : CHAR; CONST name : Name);
		BEGIN
			IF (ch # 0X) THEN
				error.Char("-"); error.Char(ch);
			ELSE
				error.String("--"); error.String(name);
			END;
		END ShowOption;

		(** Debug: List all known options and their current values *)
		PROCEDURE Show*(out : Streams.Writer);
		VAR i : LONGINT;
		BEGIN {EXCLUSIVE}
			IF (nofOptions > 0) THEN
				FOR i := 0 TO (nofOptions-1) DO
					out.Int(i+1, 2); out.String(": ");
					IF (options[i].ch # 0X) THEN
						out.Char(options[i].ch);
						IF (options[i].name # "") THEN out.String(", "); END;
					END;
					IF (options[i].name # "") THEN
						out.String(options[i].name);
					END;
					out.String(", Set: ");
					IF options[i].isSet THEN out.String("Yes"); ELSE out.String("No"); END;
					out.String(", Type: ");
					CASE options[i].type OF
						|Flag:
							out.String("Flag");
						|String:
							out.String("String");
							IF (options[i].isSet) THEN out.String(" ("); out.String(options[i].string); out.String(")"); END;
						|Integer:
							out.String("Integer");
							IF (options[i].isSet) THEN out.String(" ("); out.Int(options[i].value, 0); out.String(")"); END;
					ELSE
						out.String("Unknown");
					END;
					out.Ln;
				END;
			ELSE
				out.String("No options set"); out.Ln;
			END;
			out.Update;
		END Show;

	END Options;

(** merge base options into options -- replacing only options that had not been set previously *)
PROCEDURE Merge*(VAR this: Options;  base: Options);
VAR i,index: LONGINT;
BEGIN
	IF (base # NIL) THEN
		IF this = NIL THEN
			this := base
		ELSE
			FOR i := 0 TO base.nofOptions-1 DO
				IF (base.options[i].isSet) THEN
					index := this.FindOption(base.options[i].name);
					IF ~this.options[i].isSet THEN
						this.options[index] := base.options[i]
					END
				END;
			END;
		END
	END;
END Merge;

PROCEDURE IsValidChar(ch : CHAR) : BOOLEAN;
BEGIN
	RETURN (" " < ch) & (ch < CHR(128)) & (ch # OptionDelimiter) & (ch # Assignment);
END IsValidChar;

PROCEDURE StringToInteger*(CONST string : ARRAY OF CHAR;  VAR x: LONGINT;  hex: BOOLEAN) : BOOLEAN;
VAR pos, vd, vh, sign, d: LONGINT;  ch: CHAR;  ok: BOOLEAN;
BEGIN
	IF (LEN(string) <= 0) THEN RETURN FALSE; END;

	pos := 0;
	IF (string[pos] = "-") THEN sign := -1; INC(pos);
	ELSIF (string[pos] = "+") THEN sign := 1; INC(pos);
	ELSE sign := 1;
	END;

	vd := 0;  vh := 0;  ok := FALSE; d := 0;
	LOOP
		IF (pos >= LEN(string)) THEN EXIT; END;
		ch := string[pos];
		IF (ch >= "0") & (ch <= "9") THEN
			d := ORD( ch ) - ORD( "0" );
		ELSIF hex & (CAP( ch ) >= "A") & (CAP( ch ) <= "F") THEN
			d := ORD( CAP( ch ) ) - ORD( "A" ) + 10;
		ELSE
			EXIT;
		END;
		vd := 10 * vd + d;  vh := 16 * vh + d; (* ignore overflow *)
		INC(pos); ok := TRUE
	END;
	IF hex & (CAP( ch ) = "H") THEN  (* optional "H" present *)
		vd := vh;   (* use the hex value *)
		INC(pos);
	END;
	x := sign * vd;
	RETURN ok & ((pos >= LEN(string)) OR (string[pos] <= " "));
END StringToInteger;

PROCEDURE Test*(context : Commands.Context);
VAR options : Options; string : ARRAY 32 OF CHAR;
BEGIN
	NEW(options);
	options.Add("f", "flag", Flag);
	options.Add("s", "string", String);
	options.Add("i", "integer", Integer);
	IF options.Parse(context.arg, context.error) THEN
		context.out.Ln;
		options.Show(context.out);
		context.arg.SkipWhitespace;
		context.arg.String(string);
		IF options.GetFlag("dw") THEN END;
		context.out.String("Parsed argument: "); context.out.String(string);
		context.out.Ln; context.out.Update;

		IF options.Parse(context.arg, context.error) THEN
			options.Show(context.out);
			context.out.Ln;
		END;

		context.out.String("Parsing a string..");
		context.out.Ln; context.out.Update;
		options.Clear;
		IF options.ParseString("--flag -s=Hello -i=99  ", context.error) THEN
			options.Show(context.out);
		END;
	END;
END Test;

END Options.

Options.Test --string="Hello World"  -i=3432 --flag "This is the first argument" --string="Override string option" ~

Options.Test  -i="99" --flag ~

Options.Test -afds -b --fdas ~

Options.Test -f  -s=fds ~

SystemTools.Free Options ~