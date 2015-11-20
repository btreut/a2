MODULE MatrixModels; (** AUTHOR ""; PURPOSE ""; *)

IMPORT
	Streams, Strings, XML, Types, Models;

CONST
	EmptyMatrix = "[ ]";

TYPE

	Datatype* = REAL;
	Matrix* = ARRAY [*,*] OF Datatype;

	MatrixValue* = RECORD(Types.Generic)
		value* : Matrix;
	END;

TYPE

	MatrixModel* = OBJECT (Models.Model)
	VAR
		matrix* : Matrix; (* protected access only! *)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrMatrix);
		END Init;

		PROCEDURE Set*(matrix : Matrix);
		BEGIN
			AcquireWrite;
			SELF.matrix := matrix;
			Changed;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : Matrix;
		BEGIN
			RETURN matrix;
		END Get;

		(** Generically set data of model. Implicit type conversion if necessary and possible *)
		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : LONGINT); (** abstract *)
		VAR matrix : Matrix;
		BEGIN
			GetMatrix(value, matrix, res);
			IF (res = Types.Ok) THEN Set(matrix); END;
		END SetGeneric;

		(** Generically get data of model. Implicit type conversion if necessary and possible *)
		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : LONGINT); (** abstract *)
		BEGIN
			AcquireRead;
			SetMatrix(value, matrix, res);
			ReleaseRead;
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : LONGINT); (** protected *)
		VAR column, row, nofColumns, nofRows : LONGINT;
		BEGIN
			WriteValue^(w, level);
			nofColumns := LEN(matrix, 0);
			nofRows := LEN(matrix, 1);
			IF (nofColumns = 0) & (nofRows = 0) THEN
				w.String(EmptyMatrix);
			ELSIF (nofRows = 1) THEN (* print on same line *)
				w.String("[");
				FOR column := 0 TO nofColumns - 1 DO
					w.Float(matrix[column, 0], 0);
					IF (column # nofColumns - 1) THEN w.String(", "); END;
				END;
				w.String("]");
			ELSE
				Models.NewLine(w, level + 1);
				w.String("[");
				FOR row := 0 TO nofRows - 1 DO
					Models.NewLine(w, level + 2);
					w.String("[");
					FOR column := 0 TO nofColumns - 1 DO
						w.Float(matrix[column, row], 0);
						IF (column # nofColumns - 1) THEN w.String(", "); END;
					END;
					w.String("]");
				END;
				Models.NewLine(w, level + 1);
				w.String("]");
				Models.NewLine(w, level);
			END;
		END WriteValue;

	END MatrixModel;

VAR
	StrMatrix : Strings.String;

PROCEDURE GetStringLength(CONST matrix : Matrix) : LONGINT;
VAR length, nofColumns, nofRows : LONGINT;
BEGIN
	length := 0;
	nofColumns := LEN(matrix, 0);
	nofRows := LEN(matrix, 1);
	IF (nofColumns = 0) & (nofRows = 0) THEN
		length := Strings.Length(EmptyMatrix);
	ELSE
		length := 1024; (* TBD *)
	END;
	RETURN length;
END GetStringLength;

PROCEDURE MatrixToString(CONST matrix : Matrix; VAR string : ARRAY OF CHAR; VAR res : LONGINT);
VAR length, nofColumns, nofRows, column, row,  i : LONGINT; error : BOOLEAN;

	PROCEDURE Append(VAR string : ARRAY OF CHAR; VAR index : LONGINT; CONST suffix : ARRAY OF CHAR) : BOOLEAN;
	VAR result : BOOLEAN; length, i : LONGINT;
	BEGIN
		length := Strings.Length(suffix);
		ASSERT(length > 0);
		result := (index + length < LEN(string));
		IF result THEN
			FOR i := 0 TO length - 1 DO
				string[index] := suffix[i];
				INC(index);
			END;
			ASSERT(index < LEN(string));
			string[index] := 0X;
		END;
		RETURN result;
	END Append;

	PROCEDURE AppendFloat(VAR string : ARRAY OF CHAR; VAR index : LONGINT; float : LONGREAL) : BOOLEAN;
	VAR floatStr : ARRAY 128 OF CHAR;
	BEGIN
		Strings.FloatToStr(float, 0, 10, 4, floatStr);
		RETURN Append(string, index, floatStr);
	END AppendFloat;

BEGIN
	res := Types.TruncatedError;
	length := LEN(string) - 1; (* 0X terminated *)
	nofColumns := LEN(matrix, 0);
	nofRows := LEN(matrix, 1);
	IF (nofColumns = 0) & (nofRows = 0) THEN
		IF (length >= Strings.Length(EmptyMatrix)) THEN
			COPY(EmptyMatrix, string);
			res := Types.Ok;
		END;
	ELSE
		i := 0;
		IF Append(string, i, "[") THEN
			error := FALSE;
			row := 0;
			WHILE (row < nofRows) & ~error DO
				IF (nofRows > 1) THEN error := error OR ~Append(string, i, "["); END;
				column := 0;
				WHILE (column < nofColumns) & ~error DO
					error := error OR ~AppendFloat(string, i, matrix[column, row]);
					INC(column);
					IF (column # nofColumns) THEN error := error OR ~Append(string, i, ", "); END;
				END;
				IF (nofRows > 1) THEN error := error OR ~Append(string, i, "]"); END;
				INC(row);
			END;
			IF ~error & Append(string, i, "]") THEN
				res := Types.Ok;
			END;
		END;
	END;
END MatrixToString;

PROCEDURE StringToMatrix(CONST string : ARRAY OF CHAR; VAR matrix : Matrix; VAR res : LONGINT);
VAR
	nofColumns, nofRows, column, row, length, index : LONGINT;

	PROCEDURE IsWhitespace(character : CHAR) : BOOLEAN;
	BEGIN
		RETURN (character <= " ") & (character # 0X);
	END IsWhitespace;

	PROCEDURE SkipWhitespace(CONST string : ARRAY OF CHAR; length : LONGINT; VAR index : LONGINT);
	BEGIN
		ASSERT(length < LEN(string));
		WHILE (index < length) & (string[index] # 0X) & IsWhitespace(string[index]) DO INC(index); END;
		ASSERT(index <= length);
	END SkipWhitespace;

	PROCEDURE CountFloats(CONST string : ARRAY OF CHAR; length : LONGINT; VAR index : LONGINT) : LONGINT;
	VAR nofFloats : LONGINT;
	BEGIN
		nofFloats := 1;
		WHILE (index < length) & (string[index] # "]") DO
			IF (string[index] = ",") THEN INC(nofFloats); END;
			INC(index);
		END;
		IF (string[index] # "]") THEN nofFloats := -1; END;
		ASSERT(index < length);
		RETURN nofFloats;
	END CountFloats;

	PROCEDURE Consume(CONST string : ARRAY OF CHAR; character : CHAR; VAR index : LONGINT) : BOOLEAN;
	VAR result : BOOLEAN;
	BEGIN
		result := (index < LEN(string)) & (string[index] = character);
		IF result THEN INC(index); END;
		RETURN result;
	END Consume;

	PROCEDURE GetDimensions(CONST string : ARRAY OF CHAR; length : LONGINT; VAR nofColumns, nofRows : LONGINT; VAR res : LONGINT);
	CONST Start = 0; ExpectRow = 1; ReadingRow = 2; Error = 9; Done = 10;
	VAR oldIndex, index : LONGINT; state, nofFloats : LONGINT;
	BEGIN
		res := Types.CannotConvert;
		index := 0;
		SkipWhitespace(string, length, index);
		IF Consume(string, "[", index) THEN
			state := Start;
			oldIndex := index - 1;
			WHILE (index < length) & (state # Done) & (state # Error) DO
				ASSERT(index > oldIndex);
				oldIndex := index;
				SkipWhitespace(string, length, index);
				ASSERT((state = Start) OR (state = ExpectRow) OR (state = ReadingRow));
				CASE string[index] OF
					|"[":
						IF (state = Start) OR (state = ExpectRow) THEN
							state := ReadingRow;
							INC(nofRows);
							INC(index); (* consume "[" *)
						ELSE
							state := Error;
						END;
					|"]":
						IF (state = Start) OR (state = ExpectRow) THEN
							state := Done;
						ELSE
							state := ExpectRow;
						END;
						INC(index); (* consume "]" *)
					|"0".."9", "-", "+":
						IF (state = Start) THEN (* single row matrix *)
							nofRows := 1;
							nofFloats := CountFloats(string, length, index);
							IF (nofFloats > 0) & Consume(string, "]", index) THEN
								nofColumns := nofFloats;
								state := Done;
							ELSE
								state := Error;
							END;
						ELSIF (state = ReadingRow) THEN
							nofFloats := CountFloats(string, length, index);
							IF (nofFloats > 0) & ((nofColumns = 0) OR (nofColumns = nofFloats)) & Consume(string, "]", index) THEN
								state := ExpectRow;
								nofColumns := nofFloats;
							ELSE
								state := Error;
							END;
						ELSE
							state := Error;
						END;
				ELSE
					state := Error;
				END;
			END;
			IF (state = Done) THEN
				SkipWhitespace(string, length, index);
				IF (string[index] = 0X) THEN
					res := Types.Ok;
				END;
			END;
		END;
	END GetDimensions;

	PROCEDURE ReadFloat(CONST string : ARRAY OF CHAR; VAR index : LONGINT) : LONGREAL;
	VAR floatStr : ARRAY 128 OF CHAR; float : LONGREAL; i : LONGINT;
	BEGIN
		i := 0;
		WHILE (string[index] # ",") & (string[index] # "]") DO
			floatStr[i] := string[index];
			INC(index);
		END;
		Strings.StrToFloat(floatStr, float);
		RETURN float;
	END ReadFloat;

BEGIN
	length := Strings.Length(string);
	GetDimensions(string, length, nofColumns, nofRows, res);
	IF (res = Types.Ok) THEN
		IF (nofColumns = 0) & (nofRows = 0) THEN
			NEW(matrix, 0, 0);
		ELSE
			(* Note: GetDimensions already performed a rudimentary string structure check, so we don't have to
				check for the string structure here again *)
			index := 0;
			SkipWhitespace(string, length, index);
			ASSERT(string[index] = "[");
			INC(index); (* skip "[" *)
			NEW(matrix, nofColumns, nofRows);
			IF (nofRows = 1) THEN
				FOR column := 0 TO nofColumns - 1 DO
					SkipWhitespace(string, length, index);
					matrix[column, 0] := SHORT(ReadFloat(string, index));
					IF (column < nofColumns - 1) THEN
						ASSERT(string[index] = ",");
						INC(index); (* skip "," *)
					END;
				END;
				SkipWhitespace(string, length, index);
				ASSERT(string[index] = "]");
			ELSE
				FOR row := 0 TO nofRows - 1 DO
					SkipWhitespace(string, length, index);
					ASSERT(string[index] = "[");
					INC(index); (* skip "[" *)
					FOR column := 0 TO nofColumns - 1 DO
						SkipWhitespace(string, length, index);
						matrix[column, row] := SHORT(ReadFloat(string, index));
						IF (column < nofColumns - 1) THEN
							ASSERT(string[index] = ",");
							INC(index); (* skip "," *)
						END;
					END;
					SkipWhitespace(string, length, index);
					ASSERT(string[index] = "]");
					INC(index); (* skip "]" *)
				END;
			END;
		END;
	END;
END StringToMatrix;

PROCEDURE GetMatrix(CONST source : Types.Any; VAR value : Matrix; VAR res : LONGINT);
VAR matrixValue : MatrixValue;
BEGIN
	res := Types.Ok;
	IF (source IS MatrixValue) THEN
		value := source(MatrixValue).value;
	ELSIF (source IS Types.String32) THEN
		StringToMatrix(source(Types.String32).value, value, res);
	ELSIF (source IS Types.String256) THEN
		StringToMatrix(source(Types.String256).value, value, res);
	ELSIF (source IS Types.String) THEN
		IF (source(Types.String).value # NIL) THEN
			StringToMatrix(source(Types.String).value^, value, res);
		ELSE
			res := Types.ConversionError;
		END;
	ELSIF (source IS Types.DynamicString) THEN
		StringToMatrix(source(Types.DynamicString).value^, value, res);
	ELSIF (source IS Types.Generic) THEN
		IF (source(Types.Generic).Get # NIL) THEN
			source(Types.Generic).Get(source(Types.Generic), matrixValue, res);
			IF (res = Types.Ok) THEN value := matrixValue.value; END;
		ELSE
			res := Types.CannotRead;
		END;
	ELSE
		res := Types.CannotConvert;
	END;
END GetMatrix;

PROCEDURE SetMatrix(VAR target : Types.Any; CONST value : Matrix; VAR res : LONGINT);
VAR matrixValue : MatrixValue;
BEGIN
	res := Types.Ok;
	IF (target IS MatrixValue) THEN
		target(MatrixValue).value := value;
	ELSIF (target IS Types.String32) THEN
		MatrixToString(value, target(Types.String32).value, res);
	ELSIF (target IS Types.String256) THEN
		MatrixToString(value, target(Types.String256).value, res);
	ELSIF (target IS Types.String) THEN
		IF (target(Types.String).value # NIL) THEN
			MatrixToString(value, target(Types.String).value^, res);
		ELSE
			res := Types.ConversionError;
		END;
	ELSIF (target IS Types.DynamicString) THEN
		Types.EnsureLength(target(Types.DynamicString), GetStringLength(value));
		MatrixToString(value, target(Types.DynamicString).value^, res);
	ELSIF (target IS Types.Generic) THEN
		IF (target(Types.Generic).Set # NIL) THEN
			matrixValue.value := value;
			target(Types.Generic).Set(target(Types.Generic), matrixValue, res);
		ELSE
			res := Types.CannotWrite;
		END;
	ELSE
		res := Types.CannotConvert;
	END;
END SetMatrix;

PROCEDURE MatrixValueGetter(CONST self : Types.Generic; VAR target : Types.Any; VAR res : LONGINT);
BEGIN
	ASSERT(self IS MatrixValue);
	SetMatrix(target, self(MatrixValue).value, res);
END MatrixValueGetter;

PROCEDURE MatrixValueSetter(CONST self : Types.Generic; CONST source : Types.Any; VAR res : LONGINT);
BEGIN
	ASSERT(self IS MatrixValue);
	GetMatrix(source, self(MatrixValue).value, res);
END MatrixValueSetter;

PROCEDURE GetMatrixValue*() : MatrixValue;
VAR matrixValue : MatrixValue;
BEGIN
	matrixValue.Get := MatrixValueGetter;
	matrixValue.Set := MatrixValueSetter;
	RETURN matrixValue;
END GetMatrixValue;

PROCEDURE GenMatrixModel*() : XML.Element;
VAR matrix : MatrixModel;
BEGIN
	NEW(matrix); RETURN matrix;
END GenMatrixModel;

PROCEDURE InitStrings;
BEGIN
	StrMatrix := Strings.NewString("Matrix");
END InitStrings;

BEGIN
	InitStrings;
END MatrixModels.
