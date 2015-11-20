MODULE TestFiles; (** AUTHOR "staubesv"; PURPOSE "Files  tester"; *)

IMPORT Commands, Options, Random, Strings, TestSuite, Streams, Files;

CONST
	Integer = 0;
	Boolean = 1;
	Char = 2;
	String = 3;

TYPE

	Tester = OBJECT (TestSuite.Tester)
	VAR
		log: Streams.Writer;
		file : Files.File;
		rider : Files.Rider;
		reader : Files.Reader;
		path : ARRAY 512 OF CHAR;
		lastCommandWasComment : BOOLEAN;

		readerBytesLength : LONGINT; (* last results from Reader.Bytes(... VAR len) *)
		byte : CHAR; (* last byte read *)
		buffer : Strings.String; (* last bytes read *)

		PROCEDURE &InitTester *(log: Streams.Writer; CONST path : ARRAY OF CHAR);
		BEGIN
			ASSERT(log # NIL);
			SELF.log := log;
			COPY(path, SELF.path);
			Strings.TrimWS(SELF.path);
			Reset;
		END InitTester;

		PROCEDURE Reset;
		BEGIN
			file := NIL;
			rider.eof := FALSE;
			rider.res := 0;
			rider.apos := 0;
			rider.bpos := 0;
			rider.hint := NIL;
			rider.file := NIL;
			rider.fs := NIL;
			reader := NIL;
			readerBytesLength := 0;
			byte := 0X;
			buffer := NIL;
			lastCommandWasComment := FALSE;
		END Reset;

		PROCEDURE OpenFile(CONST filename : ARRAY OF CHAR; VAR error : BOOLEAN);
		VAR fullname : Files.FileName;
		BEGIN
			COPY(path, fullname); Strings.Append(fullname, filename);
			log.String("Files.Old '"); log.String(fullname); log.String("' ... "); log.Update;
			file := Files.Old(fullname);
			IF (file # NIL) THEN
				Files.OpenReader(reader, file, 0);
				log.String("Ok");
			ELSE
				error := TRUE;
				log.String("Failed");
			END;
		END OpenFile;

		PROCEDURE CreateFile(CONST filename : ARRAY OF CHAR; VAR error : BOOLEAN);
		VAR fullname : Files.FileName;
		BEGIN
			COPY(path, fullname); Strings.Append(fullname, filename);
			log.String("Files.New '"); log.String(fullname); log.String("' ... "); log.Update;
			file := Files.New(fullname);
			IF (file # NIL) THEN
				Files.OpenReader(reader, file, 0);
				log.String("Ok");
			ELSE
				error := TRUE;
				log.String("Failed.");
			END;
		END CreateFile;

		PROCEDURE DeleteFile(CONST filename : ARRAY OF CHAR; VAR error : BOOLEAN);
		VAR fullname : Files.FileName; res : LONGINT;
		BEGIN
			COPY(path, fullname); Strings.Append(fullname, filename);
			log.String("DELETE '"); log.String(fullname); log.String("' ... "); log.Update;
			Files.Delete(fullname, res);
			IF (res = Files.Ok) THEN
				log.String("Ok");
			ELSE
				error := TRUE;
				log.String("File not found");
			END;
		END DeleteFile;

		PROCEDURE RegisterFile(VAR error : BOOLEAN);
		BEGIN
			log.String("Register current file ... "); log.Update;
			IF CheckOpen(error) THEN
				Files.Register(file);
				log.String("Ok");
			ELSE
				log.String("Failed");
			END;
		END RegisterFile;

		PROCEDURE CheckOpen(VAR error : BOOLEAN) : BOOLEAN;
		BEGIN
			IF (file = NIL) THEN
				log.String("Error: no open file");
				error := TRUE;
			ELSE
				error := FALSE;
			END;
			RETURN ~error;
		END CheckOpen;

		PROCEDURE FileSet(position : LONGINT; VAR error : BOOLEAN);
		BEGIN
			log.String("File.Pos := "); log.Int(position, 0); log.String(" ... "); log.Update;
			IF CheckOpen(error) THEN
				file.Set(rider, position);
				log.String("Ok");
			END;
 		END FileSet;

		PROCEDURE GetInteger(r : Streams.Reader; VAR integer : LONGINT) : BOOLEAN;
		BEGIN
			r.SkipWhitespace; r.Int(integer, FALSE);
			IF (r.res # Streams.Ok) THEN
				log.Ln; log.String("Parse error: Expected integer value, pos = "); log.Int(r.Pos(), 0); log.Ln;
			END;
			RETURN (r.res = Streams.Ok);
		END GetInteger;

		PROCEDURE GetString(r : Streams.Reader; VAR string : Strings.String) : BOOLEAN;
		VAR value : ARRAY 1024 OF CHAR;
		BEGIN
			r.SkipWhitespace; r.String(value);
			IF (r.res # Streams.Ok) THEN
				string := NIL;
				log.Ln; log.String("Parse error: Expected string value, pos = "); log.Int(r.Pos(), 0); log.Ln;
			ELSE
				string := Strings.NewString(value);
			END;
			RETURN (r.res = Streams.Ok);
		END GetString;

		PROCEDURE GetBoolean(r : Streams.Reader; VAR boolean : BOOLEAN) : BOOLEAN;
		VAR string : ARRAY 8 OF CHAR;
		BEGIN
			r.SkipWhitespace; r.String(string);
			IF (string = "TRUE") THEN boolean := TRUE;
			ELSIF (string = "FALSE") THEN boolean := FALSE;
			ELSE
				log.Ln; log.String("Parse error : Expected boolean value, pos = "); log.Int(r.Pos(), 0); log.Ln;
			END;
			RETURN (string = "TRUE") OR (string = "FALSE");
		END GetBoolean;

		PROCEDURE GetChar(r : Streams.Reader; VAR char : CHAR) : BOOLEAN;
		BEGIN
			r.SkipWhitespace; r.Char(char);
			IF (r.res # Streams.Ok) THEN
				log.Ln; log.String("Parse error: Expected character value, pos = "); log.Int(r.Pos(), 0); log.Ln;
			END;
			RETURN (r.res = Streams.Ok);
		END GetChar;

		PROCEDURE GetIndex(CONST string : ARRAY OF CHAR; VAR index : LONGINT) : BOOLEAN;
		VAR variable : ARRAY 64 OF CHAR;
		BEGIN
			ASSERT(Strings.Match("buffer*", string));
			COPY(string, variable);
			Strings.Delete(variable, 0, 6);
			IF (variable[0] = "[") & (variable[Strings.Length(variable)-1] = "]") THEN
				Strings.Delete(variable, 0, 1);
				variable[Strings.Length(variable)-1] := 0X;
				IF IsNumber(variable) THEN
					Strings.StrToInt(variable, index);
					RETURN TRUE;
				ELSE
					log.String("Parse error: Expected integer as index in "); log.String(string);
				END;
			ELSE
				log.String("Parse error: Expected index brackets [] in "); log.String(string);
			END;
			RETURN FALSE;
		END GetIndex;

		PROCEDURE Assert(r : Streams.Reader; VAR error, parseError : BOOLEAN);
		VAR variable : ARRAY 32 OF CHAR; index : LONGINT;

			PROCEDURE CheckInteger(CONST name : ARRAY OF CHAR;  variable : LONGINT; r : Streams.Reader; VAR error, parseError : BOOLEAN);
			VAR operator : ARRAY 4 OF CHAR; value : LONGINT;
			BEGIN
				r.SkipWhitespace; r.String(operator);
				IF GetInteger(r, value) THEN
					IF (operator = "=") THEN error := variable # value;
					ELSIF (operator = "#") THEN error := variable = value;
					ELSIF (operator = "<") THEN error := variable >= value;
					ELSIF (operator = "<=") THEN error := variable > value;
					ELSIF (operator = ">") THEN error := variable <= value;
					ELSIF (operator = ">=") THEN error := variable < value;
					ELSE
						parseError := TRUE;
						log.String("Parse error: Unsupported integer operator: "); log.String(operator);
						log.String(", pos = "); log.Int(r.Pos(), 0);
					END;
				ELSE
					parseError := TRUE;
				END;
				IF ~parseError THEN
					log.String("ASSERT "); log.String(name); log.Char(" "); log.String(operator); log.Char(" ");  log.Int(value, 0); log.String(" ... ");
					IF ~error THEN log.String("Ok"); ELSE log.String("Failed ("); log.Int(variable, 0); log.String(")");  END;
				END;
			END CheckInteger;

			PROCEDURE CheckBoolean(CONST name : ARRAY OF CHAR; variable : BOOLEAN; r : Streams.Reader; VAR error, parseError : BOOLEAN);
			VAR operator : ARRAY 4OF CHAR; value : BOOLEAN;
			BEGIN
				r.SkipWhitespace; r.String(operator);
				IF GetBoolean(r, value) THEN
					IF (operator = "=") THEN
						error := variable # value;
					ELSIF (operator = "#") THEN
						error := variable = value;
					ELSE
						parseError := TRUE;
						log.String("Parse error: Unsupported boolean operator: "); log.String(operator);
						log.String(", pos = "); log.Int(r.Pos(), 0);
					END;
				ELSE
					parseError := TRUE;
				END;
				IF ~parseError THEN
					log.String("ASSERT "); log.String(name); log.Char(" "); log.String(operator); log.Char(" ");
					IF value THEN log.String("TRUE"); ELSE log.String("FALSE"); END; log.String(" ... ");
					IF ~error THEN log.String("Ok"); ELSE log.String("Failed"); END;
				END;
			END CheckBoolean;

			PROCEDURE CheckChar(CONST name : ARRAY OF CHAR; variable : CHAR; r : Streams.Reader; VAR error, parseError : BOOLEAN);
			VAR operator : ARRAY 4 OF CHAR; value : CHAR;
			BEGIN
				r.SkipWhitespace; r.String(operator);
				IF GetChar(r, value) THEN
					IF (operator = "=") THEN error := variable # value;
					ELSIF (operator = "#") THEN error := variable = value;
					ELSE
						parseError := TRUE;
						log.String("Parse error: Unsupported character operator: "); log.String(operator);
					END;
				ELSE
					parseError := TRUE;
				END;
				IF ~parseError THEN
					log.String("ASSERT "); log.String(name); log.Char(" "); log.String(operator); log.Char(" ");
					log.Int(ORD(value), 0); log.String(" ... ");
					IF ~error THEN log.String("Ok"); ELSE log.String("Failed ("); log.Int(ORD(variable), 0); log.String(")"); END;
				END;
			END CheckChar;

			PROCEDURE CheckString(CONST name : ARRAY OF CHAR; CONST variable : Strings.String; r : Streams.Reader; VAR error, parseError : BOOLEAN);
			VAR operator : ARRAY 4 OF CHAR; value : Strings.String; i : LONGINT;
			BEGIN
				r.SkipWhitespace; r.String(operator);
				IF GetString(r, value) THEN
					ASSERT(value # NIL);
					IF (operator = "=") THEN
						error := ~StringsAreEqual(value, buffer);
					ELSIF (operator = "#") THEN
						error := StringsAreEqual(value, buffer);
					ELSE
						parseError := TRUE;
						log.String("Parse error: Unsupported string operator: "); log.String(operator);
					END;
				ELSE
					parseError := TRUE;
				END;
				IF ~parseError THEN
					log.String("ASSERT "); log.String(name); log.Char(" "); log.String(operator); log.Char(" ");
					i := 0;
					WHILE (i < LEN(value)) & (i < 20) & (value[i] # 0X) DO log.Char(value[i]); INC(i); END;
					log.String(" ... ");
					IF ~error THEN log.String("Ok"); ELSE log.String("Failed"); END;
				END;
			END CheckString;

		BEGIN
			variable := "";
			r.SkipWhitespace; r.String(variable);
			IF (variable # "") THEN
				IF (variable = "rider.res") THEN
					CheckInteger(variable, rider.res, r, error, parseError);
				ELSIF (variable = "rider.eof") THEN
					CheckBoolean(variable, rider.eof, r, error, parseError);
				ELSIF (variable = "reader.res") THEN
					CheckInteger(variable, reader.res, r, error, parseError);
				ELSIF (variable = "byte") THEN
					CheckChar(variable, byte, r, error, parseError);
				ELSIF (variable = "readerBytesLength") THEN
					CheckInteger(variable, readerBytesLength, r, error, parseError);
				ELSIF (variable = "buffer") THEN
					CheckString(variable, buffer, r, error, parseError);
				ELSIF Strings.Match("buffer*", variable) THEN
					IF GetIndex(variable, index) THEN
						IF (buffer # NIL) & (index < LEN(buffer)) THEN
							CheckChar(variable, buffer[index], r, error, parseError);
						ELSE
							error := TRUE;
						END;
					ELSE
						parseError := TRUE;
					END;
				ELSIF (variable = "File.Length()") & CheckOpen(error) THEN
					CheckInteger(variable, file.Length(), r, error, parseError);
				ELSIF (variable = "File.Pos()") & CheckOpen(error) THEN
					CheckInteger(variable, file.Pos(rider), r, error, parseError);
				ELSIF (variable = "Reader.Available()") & CheckOpen(error) THEN
					CheckInteger(variable, reader.Available(), r, error, parseError);
				ELSIF (variable = "Reader.Pos()") & CheckOpen(error) THEN
					CheckInteger(variable, reader.Pos(), r, error, parseError);
				ELSE
					parseError := TRUE;
					log.String("Parse error: Unknown variable "); log.String(variable);
					log.String(", pos = "); log.Int(r.Pos(), 0);
				END;
			ELSE
				parseError := TRUE;
				log.String("Parse error: Expected variable name in ASSERT, pos = "); log.Int(r.Pos(), 0);
			END;
		END Assert;

		PROCEDURE Set(r : Streams.Reader; VAR error, parseError : BOOLEAN);
		VAR
			variable, to : ARRAY 32 OF CHAR;
			charValue : CHAR; integerValue : LONGINT;  booleanValue : BOOLEAN; stringValue : Strings.String;
			set, i : LONGINT; index : LONGINT;

		BEGIN
			r.SkipWhitespace; r.String(variable);
			IF (variable = "rider.res") OR (variable = "rider.eof") OR (variable = "byte") OR (variable = "readerBytesLength") OR
				(variable = "buffer") OR Strings.Match("buffer*", variable) THEN
				r.SkipWhitespace; r.String(to);
				IF (to = "TO") THEN
					IF (variable = "rider.res") THEN
						set := Integer;
						IF GetInteger(r, integerValue) THEN rider.res := integerValue; ELSE parseError := TRUE; END;
					ELSIF (variable = "rider.eof") THEN
						set := Boolean;
						IF GetBoolean(r, booleanValue) THEN rider.eof := booleanValue; ELSE parseError := TRUE; END;
					ELSIF (variable = "reader.res") THEN
						set := Integer;
						IF GetInteger(r, integerValue) THEN reader.res := integerValue; ELSE parseError := TRUE; END;
					ELSIF (variable = "byte") THEN
						set := Char;
						IF GetChar(r, charValue) THEN byte := charValue; ELSE parseError := TRUE; END;
					ELSIF (variable = "readerBytesLength") THEN
						set := Integer;
						IF GetInteger(r, integerValue) THEN readerBytesLength := integerValue; ELSE parseError := TRUE; END;
					ELSIF (variable = "buffer") THEN
						set := String;
						IF GetString(r, stringValue) THEN
							ASSERT((stringValue # NIL) & (stringValue[LEN(stringValue)-1] = 0X));
							IF (buffer # NIL) & (LEN(buffer) >= LEN(stringValue)-1) THEN
								FOR i := 0 TO LEN(stringValue)-2 DO (* don-t include 0X *)
									buffer[i] := stringValue[i];
								END;
							ELSE
								error := TRUE;
							END;
						ELSE
							parseError := TRUE;
						END;
					ELSIF Strings.Match("buffer*", variable) THEN
						IF GetIndex(variable, index) THEN
							IF (buffer # NIL) & (index < LEN(buffer)) THEN
								IF GetChar(r, charValue) THEN
									buffer[index] := charValue;
								ELSE
									parseError := TRUE;
								END;
							ELSE
								error := TRUE;
							END;
						ELSE
							parseError := TRUE;
						END;
					END;
					IF ~parseError THEN
						log.String("SET "); log.String(variable); log.String(" to ");
						IF (set = Boolean) THEN
							IF booleanValue THEN log.String("TRUE"); ELSE log.String("FALSE"); END;
						ELSIF (set = Integer) THEN
							log.Int(integerValue, 0);
						ELSIF (set = Char) THEN
							log.Int(ORD(charValue), 0);
						ELSIF (set = String) THEN
							IF (stringValue # NIL) THEN
								i := 0;
								WHILE (i < LEN(stringValue)) & (i < 20) & (stringValue[i] # 0X) DO
									log.Char(stringValue[i]); INC(i);
								END;
								IF (i < LEN(stringValue)) & (stringValue[i] # 0X) THEN
									log.String(" ... ");
								END;
							ELSE
								log.String("NIL");
							END;
						END;
						IF ~error THEN log.String(" ... Ok"); ELSE log.String(" ... Failed"); END;
					END;
				ELSE
					parseError := TRUE;
					log.String("Parse error: Expected TO, pos = "); log.Int(r.Pos(), 0);
				END;
			ELSE
				parseError := TRUE;
				log.String("Parse error: Unknown variable in SET: "); log.String(variable); log.Int(r.Pos(), 0);
			END;
		END Set;

		PROCEDURE FileReadByte(VAR error : BOOLEAN);
		BEGIN
			IF CheckOpen(error) THEN
				log.String("File.Read ... "); log.Update;
				file.Read(rider, byte);
				log.String("value="); log.Int(ORD(byte), 0); log.String(", Ok");
			END;
		END FileReadByte;

		PROCEDURE FileWriteByte(VAR error : BOOLEAN);
		BEGIN
			IF CheckOpen(error) THEN
				log.String("File.Write: "); log.Int(ORD(byte), 0); log.String(" ... "); log.Update;
				file.Write(rider, byte);
				log.String("Ok");
			END;
		END FileWriteByte;

		PROCEDURE FileReadBytes(offset, length : LONGINT; VAR error : BOOLEAN);
		BEGIN
			IF CheckOpen(error) THEN
				log.String("File.ReadBytes "); log.Int(offset, 0); log.String(" "); log.Int(length, 0); log.String(" ... "); log.Update;
				file.ReadBytes(rider, buffer^, offset, length);
				log.String("Ok");
			END;
		END FileReadBytes;

		PROCEDURE FileWriteBytes(offset, length : LONGINT; VAR error : BOOLEAN);
		BEGIN
			IF CheckOpen(error) THEN
				log.String("File.WriteBytes "); log.Int(offset, 0); log.String(" "); log.Int(length, 0); log.String(" ... "); log.Update;
				file.WriteBytes(rider, buffer^, offset, length);
				log.String("Ok");
			END;
		END FileWriteBytes;

		PROCEDURE ReaderGet(VAR error : BOOLEAN);
		BEGIN
			IF CheckOpen(error) THEN
				log.String("Reader.Get ... "); log.Update;
				byte := reader.Get();
				log.String("value="); log.Int(ORD(byte), 0); log.String(", Ok");
			END;
		END ReaderGet;

		PROCEDURE ReaderBytes(offset, length : LONGINT; VAR error : BOOLEAN);
		BEGIN
			IF CheckOpen(error) THEN
				log.String("Reader.Bytes "); log.Int(offset, 0); log.String(" "); log.Int(length, 0); log.String("... "); log.Update;
				reader.Bytes(buffer^, offset, length, readerBytesLength);
				log.Int(readerBytesLength, 0); log.String(" bytes read, Ok");
			END;
		END ReaderBytes;

		PROCEDURE ReaderSetPos(position : LONGINT; VAR error : BOOLEAN);
		BEGIN
			IF CheckOpen(error) THEN
				log.String("Reader.SetPos "); log.Int(position, 0); log.String(" ... "); log.Update;
				reader.SetPos(position);
				log.String("Ok");
			END;
		END ReaderSetPos;

		PROCEDURE InitBuffer(length : LONGINT);

			PROCEDURE Clear;
			VAR i : LONGINT;
			BEGIN
				FOR i := 0 TO LEN(buffer)-1 DO
					buffer[i] := 0X;
				END;
			END Clear;

		BEGIN
			log.String("INITBUFFER "); log.Int(length, 0); log.String(" ... "); log.Update;
			IF (length = 0) THEN
				buffer := NIL;
			ELSIF (buffer # NIL) & (LEN(buffer) = length) THEN
				Clear;
			ELSE
				NEW(buffer, length);
				Clear;
			END;
			log.String("Ok");
		END InitBuffer;

		PROCEDURE CallCommand(r : Streams.Reader; VAR error, parseError : BOOLEAN);
		VAR
			context : Commands.Context;
			arg : Streams.StringReader;
			commandStr : ARRAY 128 OF CHAR; parameterStr : Strings.String;
			msg : ARRAY 128 OF CHAR;
			pos, res : LONGINT;
		BEGIN
			NEW(parameterStr, 4096); Strings.Truncate(parameterStr^, 0);
			r.SkipWhitespace; r.String(commandStr);
			r.Ln(parameterStr^);
			Strings.TrimWS(parameterStr^);
			pos := Strings.Pos("<path>", parameterStr^);
			WHILE (pos >= 0) DO
				Strings.Delete(parameterStr^, pos, Strings.Length("<path>"));
				Strings.Insert(path, parameterStr^, pos);
				pos := Strings.Pos("<path>", parameterStr^);
			END;

			log.String("CALL '"); log.String(parameterStr^); log.String("' ... "); log.Update;
			IF (commandStr # "") THEN
				NEW(arg, Strings.Length(parameterStr^));
				arg.SetRaw(parameterStr^, 0, Strings.Length(parameterStr^));
				NEW(context, NIL, arg, log, log, SELF);
				Commands.Activate(commandStr, context, {Commands.Wait}, res, msg);
				IF (res = Commands.Ok) THEN
					log.String("Ok");
				ELSE
					error := TRUE;
					log.String("Failed, "); log.String(msg); log.String(", res: "); log.Int(res, 0);
				END;
			ELSE
				parseError := TRUE;
				log.String("Parse error: Expected argument for CALL");
			END;
		END CallCommand;

		PROCEDURE ProcessCommand(r : Streams.Reader; VAR error, parseError, finished : BOOLEAN);
		VAR
			filename : Files.FileName;
			string : ARRAY 64 OF CHAR;
			offset, length, position : LONGINT;
		BEGIN
			error := FALSE; parseError := FALSE;
			IF ~r.GetString(string) THEN finished := TRUE; RETURN; ELSE finished := FALSE; END;
			IF ~lastCommandWasComment THEN log.String("    "); ELSE lastCommandWasComment := FALSE; END;
			IF (string = "Files.Old") THEN (* Files.Old <filename> *)
				r.SkipWhitespace; r.String(filename);
				OpenFile(filename, error);
			ELSIF (string = "Files.New") THEN (* Files.New <filename> *)
				r.SkipWhitespace; r.String(filename);
				CreateFile(filename, error);
			ELSIF (string = "DELETE") THEN (* DELETE <filename> (does not cause error) *)
				r.SkipWhitespace; r.String(filename);
				DeleteFile(filename, error); error := FALSE;
			ELSIF (string = "REGISTER") THEN (* REGISTER *)
				RegisterFile(error);
			ELSIF (string = "File.Set") & GetInteger(r, position) THEN (* File.Set <position> *)
				FileSet(position, error);
			ELSIF (string = "SET") THEN (* SET variable TO value *)
				Set(r, error, parseError);
			ELSIF (string = "ASSERT") THEN (* ASSERT <variable> <operator> <value> *)
				Assert(r, error, parseError);
			ELSIF (string = "File.Read")  THEN (* File.Read *)
				FileReadByte(error);
			ELSIF (string = "File.ReadBytes") & GetInteger(r, offset) & GetInteger(r, length) THEN (* File.ReadBytes offset length *)
				FileReadBytes(offset, length, error);
			ELSIF (string = "File.Write") THEN (* File.Write *)
				FileWriteByte(error);
			ELSIF (string = "File.WriteBytes") & GetInteger(r, offset) & GetInteger(r, length) THEN (* File.WriteBytes offset length *)
				FileWriteBytes(offset, length, error);
			ELSIF (string = "Reader.Get") THEN (* Reader.Get *)
				ReaderGet(error);
			ELSIF (string = "Reader.Bytes") & GetInteger(r, offset) & GetInteger(r, length) THEN (* Reader.Bytes offset length *)
				ReaderBytes(offset, length, error);
			ELSIF (string = "Reader.SetPos") & GetInteger(r, position) THEN (* Reader.SetPosition position *)
				ReaderSetPos(position, error);
			ELSIF (string = "INITBUFFER") & GetInteger(r, length) THEN (* INITBUFFER length *)
				InitBuffer(length);
			ELSIF (string = "CALL") THEN
				CallCommand(r, error, parseError);
			ELSIF (string[0] = "#") THEN (* comment *)
				lastCommandWasComment := TRUE;
				r.SkipLn;
			ELSE
				log.Ln; log.String("Parse Error: Expected command, but found: "); log.String(string); log.String(", pos = "); log.Int(r.Pos(), 0); log.Ln;
				parseError := TRUE;
			END;
			IF ~parseError & (string[0] # "#") THEN log.Ln; log.Update; END;
		END ProcessCommand;

		PROCEDURE Handle (r: Streams.Reader; pos : LONGINT; CONST name: ARRAY OF CHAR; testType: TestSuite.TestType): INTEGER;
		VAR result: INTEGER; error, parseError, finished, trapped: BOOLEAN;
		BEGIN
			trapped := TRUE;
			Reset;
			error := FALSE; parseError := FALSE;
			result := TestSuite.Failure;
			log.String ("testing: "); log.String (name); log.Update; log.Ln;
			REPEAT
				ProcessCommand(r, error, parseError, finished);
				log.Update;
			UNTIL (error OR parseError OR finished);

			trapped := FALSE;
			IF parseError THEN result := TestSuite.Failure;
			ELSIF error  THEN result := TestSuite.Negative;
			ELSE result := TestSuite.Positive;
			END;
		FINALLY
			IF trapped THEN log.String("TRAP"); END;
			log.Ln; log.Update;
			RETURN result;
		END Handle;

	END Tester;

(* string is 0X terminated, buffer is NOT 0X terminated *)
PROCEDURE StringsAreEqual(string, buffer : Strings.String) : BOOLEAN;
VAR i : LONGINT;
BEGIN
	IF (string # NIL) & (buffer # NIL) & (string[LEN(string)-1] = 0X) & (LEN(string) = LEN(buffer) + 1) THEN
		i := 0;
		WHILE (i < LEN(string) - 1) & (string[i] = buffer[i]) DO INC(i); END;
		RETURN (i >= LEN(string) - 1);
	END;
	RETURN FALSE;
END StringsAreEqual;

PROCEDURE IsNumber(CONST string : ARRAY OF CHAR) : BOOLEAN;
VAR i : LONGINT;
BEGIN
	IF ("0" <= string[0]) & (string[0] <= "9") THEN
		FOR i := 1 TO Strings.Length(string)-1 DO
			IF (string[i] < "0") & ("9" < string[i]) THEN
				RETURN FALSE;
			END;
		END;
		RETURN TRUE;
	END;
	RETURN FALSE;
END IsNumber;

PROCEDURE Test*(context : Commands.Context); (** [Options] TestFile(input) [TestResultFile] ~ *)
VAR options : Options.Options; tester: Tester; report: TestSuite.StreamReport; path : Files.FileName;
BEGIN
	NEW(options);
	options.Add("p", "path", Options.String);
	IF options.Parse(context.arg, context.out) THEN
		IF ~options.GetString("path", path) THEN path := ""; END;
		NEW(tester, context.out, path);
		NEW(report, context.out);
		TestSuite.Drive(context, tester);
		tester.Print(report);
	END;
END Test;

PROCEDURE RandomReadWrite*(context : Commands.Context); (** path filename seed nofRuns ~ *)
VAR
	path, filename, fullname : Files.FileName;
	seed, run, nofRuns, position, lastPosition, length0, temp, lastPercent : LONGINT;
	char, lastChar, ch : CHAR;
	file : Files.File; rider : Files.Rider;
	random : Random.Generator;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(path);
	context.arg.SkipWhitespace; context.arg.String(filename);
	context.arg.SkipWhitespace; context.arg.Int(seed, FALSE);
	context.arg.SkipWhitespace; context.arg.Int(nofRuns, FALSE);
	COPY(path, fullname); Strings.Append(fullname, filename);
	context.out.String("    RandomReadWrite on file '"); context.out.String(fullname); context.out.String("' (");
	context.out.Int(nofRuns, 0); context.out.String(" runs)' ... ");
	context.out.Update;
	file := Files.Old(fullname);
	IF (file # NIL) THEN
		NEW(random);
		random.InitSeed(seed);
		length0 := file.Length();
		run := 0;
		lastChar := 0X; lastPosition := 0; lastPercent := 0;
		context.out.String("0% "); context.out.Update;
		WHILE (run <= nofRuns) DO
			IF (100 * run DIV nofRuns >= lastPercent + 10) THEN
				lastPercent := lastPercent + 10;
				context.out.Int(lastPercent, 0); context.out.String("% "); context.out.Update;
			END;
			position := random.Dice(length0);
			temp := random.Dice(255) + 1;
			char := CHR(temp);
			file.Set(rider, position);
			ASSERT(file.Pos(rider) = position);
			file.Write(rider, char);
			ASSERT(rider.res = 0);
			ASSERT(rider.eof = FALSE);
			ASSERT(file.Length() = length0);
			IF (lastChar # 0X) THEN
				file.Set(rider, lastPosition);
				ASSERT(file.Pos(rider) = lastPosition);
				file.Read(rider, ch);
				ASSERT(rider.res = 0);
				ASSERT(rider.eof = FALSE);
				ASSERT(file.Length() = length0);
				ASSERT(ch = lastChar);
			END;
			lastChar := char;
			lastPosition := position;
			INC(run);
		END;
		context.out.String("Ok"); context.out.Ln;
	ELSE
		context.out.String("Failed (File not found)"); context.out.Ln; context.out.Update;
		HALT(99);
	END;
END RandomReadWrite;

PROCEDURE CreateTestFiles*(context : Commands.Context); (** [path] ~ *)
VAR path : Files.FileName; i : LONGINT;

	PROCEDURE CreateFile(CONST path, filename : ARRAY OF CHAR; size : LONGINT);
	VAR file : Files.File; rider : Files.Rider; fullname : Files.FileName;
	BEGIN
		COPY(path, fullname); Strings.Append(fullname, filename);
		context.out.String("Create test file '"); context.out.String(fullname); context.out.String("' ... ");
		context.out.Update;
		file := Files.New(fullname);
		IF (file # NIL) THEN
			file.Set(rider, 0);
			FOR i := 1 TO size DO
				IF (i MOD 2 = 0) THEN file.Write(rider, 1X) ELSE file.Write(rider, 0FFX); END;
			END;
			Files.Register(file);
			context.out.String("Ok");
		ELSE
			context.out.String("Failed");
		END;
		context.out.Ln;
	END CreateFile;

BEGIN
	path := ""; context.arg.SkipWhitespace; context.arg.String(path);
	CreateFile(path, "TestFile0.Bin", 0);
	CreateFile(path, "TestFile4096.Bin", 4096);
	CreateFile(path, "TestFile8192.Bin", 8192);
END CreateTestFiles;

END TestFiles.

TestFiles.CreateTestFiles ~

SystemTools.Free TestFiles TestSuite~

WMUtilities.Call TestFiles.Test Files.Test ~	 Verbose testing mode
WMUtilities.Call TestFiles.Test Files.Test Files.Test.tmp ~ Regression testing mode

SystemTools.DoCommands

	VirtualDisks.InstallRamdisk TEST 163840 ~
	Partitions.WriteMBR TEST#0 OBEMBR.Bin ~

	SystemTools.Show AosFS File System ~ SystemTools.Ln ~

	Partitions.Create TEST#1 76 9999 ~
	Partitions.Format TEST#1 AosFS ~
	Partitions.Mount TEST#1 AosFS TEST ~

	WMUtilities.Call --blocking TestFiles.Test --path="TEST:" Files.Test ~

	FSTools.Unmount TEST ~

	SystemTools.Show FatFS File System ~ SystemTools.Ln ~

	Partitions.ChangeType TEST#1 76 12 ~
	Partitions.Format TEST#1 FatFS ~
	Partitions.Mount TEST#1 FatFS TEST ~

	WMUtilities.Call --blocking TestFiles.Test --path="TEST:" Files.Test ~

	FSTools.Unmount TEST ~

	SystemTools.Show SSFS File System ~ SystemTools.Ln ~

	SSFS.Format TEST#1 ~
	SSFS.Mount TEST TEST#1 ~

	WMUtilities.Call --blocking TestFiles.Test --path="TEST:" Files.Test ~

	SSFS.Unmount TEST ~

	VirtualDisks.Uninstall TEST ~
~~
