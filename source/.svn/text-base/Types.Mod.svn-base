MODULE Types; (** AUTHOR "staubesv"; PURPOSE "Generic types and type conversion"; *)

IMPORT
	Strings, Texts, TextUtilities, Repositories, Streams;

CONST

	(*
		res > Ok: Could convert but maybe lost precision / truncated string
		res = Ok; Conversion succeeded with no loss of precision
		res < Ok; Conversion errors
	*)
	Ok* = 0;

	Truncated* = 1;
	CannotConvert* = -10;
	ConversionError* = -11;
	TruncatedError* = -12; (* string truncation leads to error *)
	CannotRead* = -20;
	CannotWrite* = -21;
	TargetIsNIL* = -30;

TYPE

	Any* = RECORD END;

	(** Basic types *)

	Boolean* = RECORD(Any)
		value* : BOOLEAN;
	END;

	Integer* = RECORD(Any)
		value* : LONGINT;
	END;

	Real* = RECORD(Any)
		value* : REAL;
	END;

	Longreal* = RECORD(Any)
		value* : LONGREAL;
	END;

	Char* = RECORD(Any)
		value* : CHAR;
	END;

	String32* = RECORD(Any)
		value* : ARRAY 32 OF CHAR;
	END;

	String256* = RECORD(Any)
		value* : ARRAY 256 OF CHAR;
	END;

	String* = RECORD(Any)
		value* : Strings.String;
	END;

	DynamicString* = RECORD(Any) (** Initialize using NewString! *)
		value- : Strings.String; (* {value  # NIL} *)
		length : LONGINT; (* {(0 <= length) & (length < LEN(value))} *)
		bufferLength : LONGINT; (* {(0 <= bufferLength) & (bufferLength = LEN(value))} *)
	END;

	Set* = RECORD(Any)
		value* : SET;
	END;

	Text* = RECORD(Any)
		value* : Texts.Text;
	END;

	Object* = RECORD(Any)
		value* : Repositories.Component;
	END;

TYPE

	(** Generic types *)

	Generic* = RECORD(Any)
		Get* : Getter;
		Set* : Setter;
	END;

	(** Get own value and store it into target *)
	Getter* = PROCEDURE {DELEGATE} (CONST self : Generic; VAR target : Any; VAR res : LONGINT);

	(** Set own value from source *)
	Setter* = PROCEDURE {DELEGATE} (CONST self : Generic; CONST source : Any; VAR res : LONGINT);

VAR
	StrEmptyString : Strings.String;

PROCEDURE GetBoolean*(CONST source : Any; VAR value : BOOLEAN; VAR res : LONGINT);
VAR temp : ARRAY 2 OF CHAR; boolean : Boolean;
BEGIN
	res := Ok;
	IF (source IS Boolean) THEN
		value := source(Boolean).value;
	ELSIF (source IS Char) THEN
		temp[0] := source(Char).value;
		temp[1] := 0X;
		Strings.StrToBool(temp, value);
	ELSIF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			Strings.StrToBool(source(String).value^, value);
		ELSE
			res := ConversionError;
		END;
	ELSIF (source IS DynamicString) THEN
		Strings.StrToBool(source(String).value^, value);
	ELSIF (source IS String32) THEN
		Strings.StrToBool(source(String32).value, value);
	ELSIF (source IS String256) THEN
		Strings.StrToBool(source(String256).value, value);
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			source(Generic).Get(source(Generic), boolean, res);
			IF (res = Ok) THEN
				value := boolean.value;
			END;
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;
END GetBoolean;

PROCEDURE SetBoolean*(VAR target : Any; value : BOOLEAN; VAR res : LONGINT);
VAR temp : ARRAY 2 OF CHAR; boolean : Boolean;
BEGIN
	res := Ok;
	IF (target IS Boolean) THEN
		target(Boolean).value := value;
	ELSIF (target IS Char) THEN
		Strings.BoolToStr(value, temp);
		target(Char).value := temp[0];
	ELSIF (target IS String) THEN
		IF (target(String).value # NIL) THEN
			Strings.BoolToStr(value, target(String).value^);
		ELSE
			res := ConversionError;
		END;
	ELSIF (target IS DynamicString) THEN
		EnsureLength(target(DynamicString), 5);
		Strings.BoolToStr(value, target(DynamicString).value^);
	ELSIF (target IS String32) THEN
		Strings.BoolToStr(value, target(String32).value);
	ELSIF (target IS String256) THEN
		Strings.BoolToStr(value, target(String256).value);
	ELSIF (target IS Generic) THEN
		IF (target(Generic).Set # NIL) THEN
			boolean.value := value;
			target(Generic).Set(target(Generic), boolean, res);
		ELSE
			res := CannotWrite;
		END;
	ELSE
		res := CannotConvert;
	END;
END SetBoolean;

PROCEDURE GetInteger*(CONST source : Any; VAR value : LONGINT; VAR res : LONGINT);
VAR integer : Integer;
BEGIN
	res := Ok;
	IF (source IS Integer) THEN
		value := source(Integer).value;
	ELSIF (source IS Real) THEN
		value := ENTIER(source(Real).value);
	ELSIF (source IS Longreal) THEN
		value := ENTIER(source(Longreal).value);
	ELSIF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			Strings.StrToInt(source(String).value^, value);
		ELSE
			res := ConversionError;
		END;
	ELSIF (source IS DynamicString) THEN
		Strings.StrToInt(source(DynamicString).value^, value);
	ELSIF (source IS String32) THEN
		Strings.StrToInt(source(String32).value, value);
	ELSIF (source IS String256) THEN
		Strings.StrToInt(source(String256).value, value);
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			source(Generic).Get(source(Generic), integer, res);
			IF (res = Ok) THEN
				value := integer.value;
			END;
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;
END GetInteger;

PROCEDURE SetInteger*(VAR target : Any; value : LONGINT;  VAR res : LONGINT);
VAR integer : Integer;
BEGIN
	res := Ok;
	IF (target IS Integer) THEN
		target(Integer).value := value;
	ELSIF (target IS Real) THEN
		target(Real).value := value;
	ELSIF (target IS Longreal) THEN
		target(Longreal).value := value;
	ELSIF (target IS String) THEN
		EnsureStringLength(target(String).value, 11);
		Strings.IntToStr(value, target(String).value^);
		(*
		IF (target(String).value # NIL) THEN
			Strings.IntToStr(value, target(String).value^);
		ELSE
			res := ConversionError;
		END;
		*)
	ELSIF (target IS DynamicString) THEN
		EnsureLength(target(DynamicString), 11);
		Strings.IntToStr(value, target(DynamicString).value^);
	ELSIF (target IS String32) THEN
		Strings.IntToStr(value, target(String32).value);
	ELSIF (target IS String256) THEN
		Strings.IntToStr(value, target(String256).value);
	ELSIF (target IS Generic) THEN
		IF (target(Generic).Set # NIL) THEN
			integer.value := value;
			target(Generic).Set(target(Generic), integer, res);
		ELSE
			res := CannotWrite;
		END;
	ELSE
		res := CannotConvert;
	END;
END SetInteger;

PROCEDURE GetReal*(CONST source : Any; VAR value : REAL; VAR res : LONGINT);
VAR longreal : LONGREAL; real : Real;
BEGIN
	res := Ok;
	IF (source IS Real) THEN
		value := source(Real).value;
	ELSIF (source IS Longreal) THEN
		value := SHORT(source(Longreal).value);
	ELSIF (source IS Integer) THEN
		value := source(Integer).value;
	ELSIF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			Strings.StrToFloat(source(String).value^, longreal);
			value := SHORT(longreal);
		ELSE
			res := ConversionError;
		END;
	ELSIF (source IS DynamicString) THEN
		Strings.StrToFloat(source(DynamicString).value^, longreal);
		value := SHORT(longreal);
	ELSIF (source IS String32) THEN
		Strings.StrToFloat(source(String32).value, longreal);
		value := SHORT(longreal);
	ELSIF (source IS String256) THEN
		Strings.StrToFloat(source(String256).value, longreal);
		value := SHORT(longreal);
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			source(Generic).Get(source(Generic), real, res);
			IF (res = Ok) THEN
				value := real.value;
			END;
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;
END GetReal;

PROCEDURE SetReal*(VAR target : Any; value : REAL; VAR res : LONGINT);
VAR real : Real; w:Streams.StringWriter;
BEGIN
	res := Ok;
	IF (target IS Real) THEN
		target(Real).value := value;
	ELSIF (target IS Longreal) THEN
		target(Longreal).value := value;
	ELSIF (target IS Integer) THEN
		target(Integer).value := ENTIER(value);
	ELSIF (target IS String) THEN
		EnsureStringLength(target(String).value, 32);
		IF (target(String).value # NIL) THEN
			(*FloatToString(value, 8, target(String).value^);*)
			NEW(w,30); w.Float(value,24); w.Get(target(String).value^);
		ELSE
			res := ConversionError;
		END;
	ELSIF (target IS DynamicString) THEN
		EnsureLength(target(DynamicString), 32); (* TBD: max length of real? *)
		(*FloatToString(value, 8, target(DynamicString).value^);*)
		NEW(w,30); w.Float(value,24); w.Get(target(DynamicString).value^);
	ELSIF (target IS String32) THEN
		(*FloatToString(value, 8,  target(String32).value);*)
		NEW(w,30); w.Float(value,24); w.Get(target(String32).value);
	ELSIF (target IS String256) THEN
		(*FloatToString(value, 8, target(String256).value);*)
		NEW(w,30); w.Float(value,24); w.Get(target(String256).value);
	ELSIF (target IS Generic) THEN
		IF (target(Generic).Set # NIL) THEN
			real.value := value;
			target(Generic).Set(target(Generic), real, res);
		ELSE
			res := CannotWrite;
		END;
	ELSE
		res := CannotConvert;
	END;
END SetReal;

PROCEDURE GetLongreal*(CONST source : Any; VAR value : LONGREAL; VAR res : LONGINT);
VAR longreal : Longreal;
BEGIN
	res := Ok;
	IF (source IS Longreal) THEN
		value := source(Longreal).value;
	ELSIF (source IS Real) THEN
		value := source(Real).value;
	ELSIF (source IS Integer) THEN
		value := source(Integer).value;
	ELSIF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			Strings.StrToFloat(source(String).value^, value);
		ELSE
			res := ConversionError;
		END;
	ELSIF (source IS DynamicString) THEN
		Strings.StrToFloat(source(DynamicString).value^, value);
	ELSIF (source IS String32) THEN
		Strings.StrToFloat(source(String32).value, value);
	ELSIF (source IS String256) THEN
		Strings.StrToFloat(source(String256).value, value);
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			source(Generic).Get(source(Generic), longreal, res);
			IF (res = Ok) THEN
				value := longreal.value;
			END;
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;
END GetLongreal;

PROCEDURE SetLongreal*(VAR target : Any; value : LONGREAL; VAR res : LONGINT);
VAR longreal : Longreal; w:Streams.StringWriter;
BEGIN
	res := Ok;
	IF (target IS Longreal) THEN
		target(Longreal).value := value;
	ELSIF (target IS Real) THEN
		target(Real).value := SHORT(value);
	ELSIF (target IS Integer) THEN
		target(Integer).value := ENTIER(value);
	ELSIF (target IS String) THEN
		IF (target(String).value # NIL) THEN
			(*FloatToString(value, 8, target(String).value^);*)
			NEW(w,30); w.Float(value,24); w.Get(target(String).value^);
		ELSE
			res := ConversionError;
		END;
	ELSIF (target IS DynamicString) THEN
		EnsureLength(target(DynamicString), 128); (* TBD max length of longreal? *)
		(*FloatToString(value, 8, target(DynamicString).value^);*)
		NEW(w,30); w.Float(value,24); w.Get(target(DynamicString).value^);
	ELSIF (target IS String32) THEN
		(*FloatToString(value, 8, target(String32).value);*)
		NEW(w,30); w.Float(value,24); w.Get(target(String32).value);
	ELSIF (target IS String256) THEN
		(*FloatToString(value, 8, target(String256).value);*)
		NEW(w,30); w.Float(value,24); w.Get(target(String256).value);
	ELSIF (target IS Generic) THEN
		IF (target(Generic).Set # NIL) THEN
			longreal.value := value;
			target(Generic).Set(target(Generic), longreal, res);
		ELSE
			res := CannotWrite;
		END;
	ELSE
		res := CannotConvert;
	END;
END SetLongreal;

PROCEDURE GetChar*(CONST source : Any; VAR value : CHAR; VAR res : LONGINT);
VAR string : ARRAY 8 OF CHAR; char : Char;
BEGIN
	res := Ok;
	IF (source IS Char) THEN
		value := source(Char).value;
	ELSIF (source IS Boolean) THEN
		Strings.BoolToStr(source(Boolean).value, string);
		value := string[0];
	ELSIF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			value := source(String).value[0];
		ELSE
			res := ConversionError;
		END;
	ELSIF (source IS DynamicString) THEN
		value := source(DynamicString).value[0];
	ELSIF (source IS String32) THEN
		value := source(String32).value[0];
	ELSIF (source IS String256) THEN
		value := source(String256).value[0];
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			source(Generic).Get(source(Generic), char, res);
			IF (res = Ok) THEN
				value := char.value;
			END;
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;
END GetChar;

PROCEDURE SetChar*(VAR target : Any; value : CHAR; VAR res : LONGINT);
VAR temp : ARRAY 2 OF CHAR; char : Char;
BEGIN
	res := Ok;
	IF (target IS Char) THEN
		target(Char).value := value;
	ELSIF (target IS String) THEN
		IF (target(String).value # NIL) & (LEN(target(String).value) >= 2) THEN
			target(String).value[0] := value;
			target(String).value[1] := 0X;
		ELSE
			res := ConversionError;
		END;
	ELSIF (target IS DynamicString) THEN
		temp[0] := value;
		temp[1] := 0X;
		SetValue(target(DynamicString), temp);
	ELSIF (target IS String32) THEN
		target(String32).value[0] := value;
		target(String32).value[1] := 0X;
	ELSIF (target IS String256) THEN
		target(String256).value[0] := value;
		target(String256).value[1] := 0X;
	ELSIF (target IS Boolean) THEN
		temp[0] := value;
		temp[1] := 0X;
		Strings.StrToBool(temp, target(Boolean).value);
	ELSIF (target IS Generic) THEN
		IF (target(Generic).Set # NIL) THEN
			char.value := value;
			target(Generic).Set(target(Generic), char, res);
		ELSE
			res := CannotWrite;
		END;
	ELSE
		res := CannotConvert;
	END;
END SetChar;

PROCEDURE GetAOC*(CONST source : Any; VAR value : ARRAY OF CHAR; VAR res : LONGINT);
BEGIN
	res := Ok;
	IF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			COPY(source(String).value^, value);
			IF (Strings.Length(source(String).value^) >= LEN(value)) THEN
				res := Truncated;
			END;
		ELSE
			value := "";
		END;
	ELSIF (source IS DynamicString) THEN
		COPY(source(DynamicString).value^, value);
		IF (source(DynamicString).length >= LEN(value)) THEN
			res := Truncated;
		END;
	ELSIF (source IS String32) THEN
		COPY(source(String32).value, value);
	ELSIF (source IS String256) THEN
		COPY(source(String256).value, value);
	ELSIF (source IS Boolean) THEN
		Strings.BoolToStr(source(Boolean).value, value);
	ELSIF (source IS Integer) THEN
		Strings.IntToStr(source(Integer).value, value);
	ELSIF (source IS Real) THEN
		(* TODO *)
	ELSIF (source IS Longreal) THEN
		(* TODO *)
	ELSIF (source IS Char) THEN
		value[0] := source(Char).value;
		value[1] := 0X;
	ELSIF (source IS Object) THEN
		ComponentToString(source(Object).value, value, res);
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			(* TBD *)
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;
END GetAOC;

PROCEDURE EnsureStringLength(VAR s: Strings.String; length: LONGINT);
VAR l: LONGINT;
BEGIN
	IF (s = NIL) OR (Strings.Length(s^) < length) THEN
		NEW(s,length)
	END;
END EnsureStringLength;


PROCEDURE SetAOC*(VAR target : Any; CONST value : ARRAY OF CHAR; VAR res : LONGINT);
VAR temp : LONGREAL; string : String;
BEGIN
	res := Ok;
	IF (target IS String) THEN
		(*TRACE(Strings.Length(value));*)
		EnsureStringLength(target(String).value, Strings.Length(value)+1);
		COPY(value, target(String).value^);
		(*
		IF (target(String).value # NIL) THEN
			COPY(value, target(String).value^);
			IF (Strings.Length(value) >= LEN(target(String).value)) THEN
				res := Truncated;
			END;
		ELSE
			res := ConversionError;
		END;
		*)
	ELSIF (target IS DynamicString) THEN
		SetValue(target(DynamicString), value);
	ELSIF (target IS String32) THEN
		COPY(value, target(String32).value);
	ELSIF (target IS String256) THEN
		COPY(value, target(String256).value);
	ELSIF (target IS Boolean) THEN
		Strings.StrToBool(value, target(Boolean).value);
	ELSIF (target IS Integer) THEN
		Strings.StrToInt(value, target(Integer).value);
	ELSIF (target IS Real) THEN
		Strings.StrToFloat(value, temp);
		target(Real).value := SHORT(temp);
	ELSIF (target IS Char) THEN
		target(Char).value := value[0];
	ELSIF (target IS Object) THEN
		StringToComponent(value, target(Object).value, res);
	ELSIF (target IS Generic) THEN
		IF (target(Generic).Set # NIL) THEN
			string.value := Strings.NewString(value); (*? !!! *)
			target(Generic).Set(target(Generic), string, res);
		ELSE
			res := CannotWrite;
		END;
	ELSE
		res := CannotConvert;
	END;
END SetAOC;

PROCEDURE GetString*(CONST source : Any; VAR string : Strings.String; VAR res : LONGINT);
VAR
	value : ARRAY 64 OF CHAR; (*? !!! *)
	n: LONGINT;
BEGIN
	res := Ok;
	IF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			COPY(source(String).value^, value);
		ELSE
			res := ConversionError;
		END;
	ELSIF (source IS DynamicString) THEN

	ELSIF (source IS String32) THEN
		COPY(source(String32).value, value);
	ELSIF (source IS String256) THEN
		COPY(source(String256).value, value);
	ELSIF (source IS Boolean) THEN
		Strings.BoolToStr(source(Boolean).value, value);
	ELSIF (source IS Integer) THEN
		Strings.IntToStr(source(Integer).value, value);
	ELSIF (source IS Real) THEN
		(* TODO *)
	ELSIF (source IS Longreal) THEN
		(* TODO *)
	ELSIF (source IS Char) THEN
		value[0] := source(Char).value;
		value[1] := 0X;
	ELSIF (source IS Object) THEN
		ComponentToString(source(Object).value, value, res);
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			(* TBD *)
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;

	IF res = Ok THEN
		string := Strings.NewString(value);
	END;
END GetString;

PROCEDURE SetString*(VAR target : Any; value : Strings.String; VAR res : LONGINT);
BEGIN
	IF (value # NIL) THEN
		SetAOC(target, value^, res);
	ELSIF (target IS String) THEN
		target(String).value := value;
		res := Ok;
	ELSE (*? semantics *)
		res := CannotConvert;
	END;
END SetString;

PROCEDURE GetSet*(CONST source : Any; VAR value : SET; VAR res : LONGINT);
VAR set : Set;
BEGIN
	res := Ok;
	IF (source IS Set) THEN
		value := source(Set).value;
	ELSIF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			Strings.StrToSet(source(String).value^, value);
		ELSE
			res := ConversionError;
		END;
	ELSIF (source IS DynamicString) THEN
		Strings.StrToSet(source(DynamicString).value^, value);
	ELSIF (source IS String32) THEN
		Strings.StrToSet(source(String32).value, value);
	ELSIF (source IS String256) THEN
		Strings.StrToSet(source(String256).value, value);
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			source(Generic).Get(source(Generic), set, res);
			IF (res = Ok) THEN
				value := set.value;
			END;
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;
END GetSet;

PROCEDURE SetSet*(VAR target : Any; value : SET; VAR res : LONGINT);
VAR set : Set;
BEGIN
	res := Ok;
	IF (target IS Set) THEN
		target(Set).value := value;
	ELSIF (target IS String) THEN
		IF (target(String).value # NIL) THEN
			Strings.SetToStr(value, target(String).value^);
		ELSE
			res := ConversionError;
		END;
	ELSIF (target IS DynamicString) THEN
		EnsureLength(target(DynamicString), 64); (* TBD: Max length of set *)
		Strings.SetToStr(value, target(DynamicString).value^);
	ELSIF (target IS String32) THEN
		Strings.SetToStr(value, target(String32).value);
	ELSIF (target IS String256) THEN
		Strings.SetToStr(value, target(String256).value);
	ELSIF (target IS Generic) THEN
		IF (target(Generic).Set # NIL) THEN
			set.value := value;
			target(Generic).Set(target(Generic), set, res);
		ELSE
			res := CannotWrite;
		END;
	ELSE
		res := CannotConvert;
	END;
END SetSet;

PROCEDURE GetText*(CONST source : Any; VAR value : Texts.Text; VAR res : LONGINT);
VAR
	temp : ARRAY 64 OF CHAR;
	text : Text;

	PROCEDURE SetAsString(CONST string : ARRAY OF CHAR);
	BEGIN
		IF (value = NIL) THEN
			NEW(value);
			value.AcquireWrite;
		ELSE
			value.AcquireWrite;
			value.Delete(0, value.GetLength());
		END;
		value.InsertUTF8(0, string);
		value.ReleaseWrite;
	END SetAsString;

BEGIN
	res := Ok;
	IF (source IS Text) THEN
		value := source(Text).value;
	ELSIF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			SetAsString(source(String).value^);
		ELSE
			SetAsString(""); (*? semantics? *)
		END;
	ELSIF (source IS DynamicString) THEN
		SetAsString(source(String).value^);
	ELSIF (source IS String32) THEN
		SetAsString(source(String32).value);
	ELSIF (source IS String256) THEN
		SetAsString(source(String256).value);
	ELSIF (source IS Integer) THEN
		Strings.IntToStr(source(Integer).value, temp);
		SetAsString(temp);
	ELSIF (source IS Boolean) THEN
		Strings.BoolToStr(source(Boolean).value, temp);
		SetAsString(temp);
	ELSIF (source IS Set) THEN
		Strings.SetToStr(source(Set).value, temp);
		SetAsString(temp);
	ELSIF (source IS Char) THEN
		temp[0] := source(Char).value;
		temp[1] := 0X;
		SetAsString(temp);
	ELSIF (source IS Real) THEN
		Strings.FloatToStr(source(Real).value, 20, 8, 10, temp);
		SetAsString(temp);
	ELSIF (source IS Longreal) THEN
		Strings.FloatToStr(source(Longreal).value, 20, 8, 10, temp);
		SetAsString(temp);
	ELSIF (source IS Object) THEN
		ComponentToString(source(Object).value, temp, res);
		IF (res = Ok) THEN
			SetAsString(temp);
		END;
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			source(Generic).Get(source(Generic), text, res);
			IF (res = Ok) THEN
				value := text.value;
			END;
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;
END GetText;

PROCEDURE SetText*(VAR target : Any; CONST value : Texts.Text; VAR res : LONGINT);
VAR text : Text; temp : ARRAY 64 OF CHAR; lr : LONGREAL;
BEGIN
	res := Ok;
	IF (target IS Text) THEN
		target(Text).value := value;
	ELSIF (target IS String) THEN
		IF (target(String).value # NIL) THEN
			TextUtilities.TextToStr(value, target(String).value^); (*? no valid result code, e.g. truncation *)
		ELSE
			res := ConversionError;
		END;
	ELSIF (target IS DynamicString) THEN
		EnsureLength(target(DynamicString), 256); (* Text length in UTF8 *)
		TextUtilities.TextToStr(value, target(DynamicString).value^);
	ELSIF (target IS String32) THEN
		TextUtilities.TextToStr(value, target(String32).value); (*? no valid result code, e.g. truncation *)
	ELSIF (target IS String256) THEN
		TextUtilities.TextToStr(value, target(String256).value); (*? no valid result code, e.g. truncation *)
	ELSIF (target IS Integer) THEN
		TextUtilities.TextToStr(value, temp);
		Strings.StrToInt(temp, target(Integer).value);
	ELSIF (target IS Boolean) THEN
		TextUtilities.TextToStr(value, temp);
		Strings.StrToBool(temp, target(Boolean).value);
	ELSIF (target IS Set) THEN
		TextUtilities.TextToStr(value, temp);
		Strings.StrToSet(temp, target(Set).value);
	ELSIF (target IS Real) THEN
		TextUtilities.TextToStr(value, temp);
		Strings.StrToFloat(temp, lr);
		target(Real).value := SHORT(lr);
	ELSIF (target IS Longreal) THEN
		TextUtilities.TextToStr(value, temp);
		Strings.StrToFloat(temp, target(Longreal).value);
	ELSIF (target IS Generic) THEN
		IF (target(Generic).Set # NIL) THEN
			text.value := value;
			target(Generic).Set(target(Generic), text, res);
		ELSE
			res := CannotWrite;
		END;
	ELSE
		res := CannotConvert;
	END;
END SetText;

PROCEDURE GetObject*(CONST source : Any; VAR value : Repositories.Component; VAR res : LONGINT);
VAR object : Object;
BEGIN
	res := Ok;
	IF (source IS Object) THEN
		value := source(Object).value;
	ELSIF (source IS String32) THEN
		StringToComponent(source(String32).value, value, res);
	ELSIF (source IS String256) THEN
		StringToComponent(source(String256).value, value, res);
	ELSIF (source IS String) THEN
		IF (source(String).value # NIL) THEN
			StringToComponent(source(String).value^, value, res);
		ELSE
			res := ConversionError;
		END;
	ELSIF (source IS DynamicString) THEN
		StringToComponent(source(String).value^, value, res);
	ELSIF (source IS Generic) THEN
		IF (source(Generic).Get # NIL) THEN
			source(Generic).Get(source(Generic), object, res);
			IF (res = Ok) THEN
				value := object.value;
			END;
		ELSE
			res := CannotRead;
		END;
	ELSE
		res := CannotConvert;
	END;
END GetObject;

PROCEDURE SetObject*(VAR target : Any; CONST value : Repositories.Component; VAR res : LONGINT);
VAR object : Object;
BEGIN
	res := Ok;
	IF (target IS Object) THEN
		target(Object).value := value;
	ELSIF (target IS String32) THEN
		ComponentToString(value, target(String32).value, res);
	ELSIF (target IS String256) THEN
		ComponentToString(value, target(String256).value, res);
	ELSIF (target IS String) THEN
		ComponentToString(value, target(String).value^, res);
	ELSIF (target IS DynamicString) THEN
		EnsureLength(target(DynamicString), 256); (* TBD: max length of component name *)
		ComponentToString(value, target(DynamicString).value^, res);
	ELSIF (target IS Generic) THEN
		IF (target(Generic).Set # NIL) THEN
			object.value := value;
			target(Generic).Set(target(Generic), object, res);
		ELSE
			res := CannotWrite;
		END;
	ELSE
		res := CannotConvert;
	END;
END SetObject;

PROCEDURE Assign*(VAR to : Any; CONST from : Any; VAR res : LONGINT);
VAR string : String;
BEGIN
	IF (from IS Boolean) THEN
		SetBoolean(to, from(Boolean).value, res);
	ELSIF (from IS Integer) THEN
		SetInteger(to, from(Integer).value, res);
	ELSIF (from IS Real) THEN
		SetReal(to, from(Real).value, res);
	ELSIF (from IS Longreal) THEN
		SetLongreal(to, from(Longreal).value, res);
	ELSIF (from IS Char) THEN
		SetChar(to, from(Char).value, res);
	ELSIF (from IS String32) THEN
		SetAOC(to, from(String32).value, res);
	ELSIF (from IS String256) THEN
		SetAOC(to, from(String256).value, res);
	ELSIF (from IS String) THEN
		SetString(to, from(String).value, res);
	ELSIF (from IS DynamicString) THEN
		SetString(to, from(DynamicString).value, res);
	ELSIF (from IS Set) THEN
		SetSet(to, from(Set).value, res);
	ELSIF (from IS Text )THEN
		SetText(to, from(Text).value, res);
	ELSIF (from IS Object) THEN
		SetObject(to, from(Object).value, res);
	ELSIF (from IS Generic) THEN
		IF (from(Generic).Get # NIL) THEN
			from(Generic).Get(from(Generic), string, res);
			IF ( res = Ok) THEN
				SetString(to, string.value, res);
			END;
		ELSE
			res := CannotRead;
		END;
	END;
END Assign;

(* Helper procedures *)




PROCEDURE StringToComponent(CONST string : ARRAY OF CHAR; VAR component : Repositories.Component; VAR res : LONGINT);
VAR repositoryName, componentName : ARRAY 64 OF CHAR; componentID : LONGINT;
BEGIN
	component := NIL;
	IF Repositories.SplitName(string, repositoryName, componentName, componentID) THEN
		Repositories.GetComponent(repositoryName, componentName, componentID, component, res);
	ELSE
		res := 99; (*? TBD *)
	END;
END StringToComponent;

PROCEDURE ComponentToString(CONST component : Repositories.Component; VAR string : ARRAY OF CHAR; VAR res : LONGINT);
VAR repository : Repositories.Repository; componentName : Repositories.Name; nbr : ARRAY 16 OF CHAR; componentID : LONGINT;
BEGIN
	string := "";
	IF (component # NIL) THEN
		component.GetRepository(repository, componentName, componentID);
		IF (repository # NIL) THEN
			Strings.IntToStr(componentID, nbr);
			IF (Strings.Length(repository.name) + 1 + Strings.Length(componentName) + 1 + Strings.Length(nbr) + 1 <= LEN(string)) THEN
				COPY(repository.name, string);
				Strings.Append(string, Repositories.Delimiter);
				Strings.Append(string, componentName);
				Strings.Append(string, Repositories.Delimiter);
				Strings.Append(string, nbr);
				res := Ok;
			ELSE
				res := TruncatedError;
			END;
		ELSE
			res := 99; (*? TBD *)
		END;
	ELSE
		res := 99; (*? TBD *)
	END;
END ComponentToString;

(* DynamicString operations *)

PROCEDURE NewString*() : DynamicString;
VAR string : DynamicString;
BEGIN
	string.value := StrEmptyString;
	string.length := 0;
	string.bufferLength := 0; (* force allocation of new string when set *)
	RETURN string;
END NewString;

(* Ensure the <string> can hold at least minLength characters (excl. 0X-terminator) *)
PROCEDURE EnsureLength*(VAR string : DynamicString; minLength : LONGINT);
VAR newBuffer : Strings.String; i : LONGINT;
BEGIN
	ASSERT((string.value # NIL) & ((LEN(string.value) = string.bufferLength) OR (string.value = StrEmptyString)) & (minLength >= 0));
	IF (minLength + 1 >= string.bufferLength) THEN
		IF (string.bufferLength = 0) THEN string.bufferLength := 2; END;
		WHILE (minLength + 1 >=  string.bufferLength) DO
			string.bufferLength := 2 * string.bufferLength;
		END;
		NEW(newBuffer, string.bufferLength);
		FOR i := 0 TO string.length - 1 DO
			newBuffer[i] := string.value[i];
		END;
		newBuffer[string.length] := 0X;
		string.value := newBuffer;
	END;
END EnsureLength;

PROCEDURE SetValue*(VAR string : DynamicString; CONST value : ARRAY OF CHAR);
VAR length : LONGINT;
BEGIN
	length := Strings.Length(value);
	EnsureLength(string, length);
	COPY(value, string.value^);
	string.length := length;
END SetValue;

PROCEDURE Free*(VAR string : DynamicString);
BEGIN
	string.value := StrEmptyString;
	string.length := 0;
	string.bufferLength := 0; (* force allocation of new string when set *)
END Free;

PROCEDURE Append*(VAR string : DynamicString; CONST suffix : ARRAY OF CHAR);
VAR suffixLength : LONGINT;
BEGIN
	suffixLength := Strings.Length(suffix);
	EnsureLength(string, string.length + suffixLength);
	Strings.Append(string.value^, suffix);
	string.length := string.length + suffixLength;
END Append;

PROCEDURE GetLength*(CONST string : DynamicString) : LONGINT;
BEGIN
	RETURN string.length;
END GetLength;

PROCEDURE CleanString(VAR s: ARRAY OF CHAR);
VAR i, lead: LONGINT;
BEGIN
	i := 0;
	WHILE s[i] = " " DO INC(i) END;
	lead := i;
	WHILE s[i] # 0X DO s[i-lead] := s[i]; INC(i) END;
	DEC(i, lead);
	IF (i>0) & (s[i-1] =".") THEN DEC(i) END;
	s[i] := 0X;
END CleanString;

PROCEDURE FloatToString*(r: LONGREAL; fractionalDigits: LONGINT; VAR s: ARRAY OF CHAR);
BEGIN
	Strings.FloatToStr(r, 0, fractionalDigits, 0, s);
	CleanString(s);
END FloatToString;

PROCEDURE InitStrings;
BEGIN
	StrEmptyString := Strings.NewString("");
END InitStrings;

BEGIN
	InitStrings;
END Types.
