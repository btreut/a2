MODULE TFStringPool;

IMPORT
	Trace, Strings;
	
CONST
	BufSize = 1024;	
	
TYPE 
	Buffer = POINTER TO ARRAY BufSize OF CHAR;
	BufferList = POINTER TO ARRAY OF Buffer;	
	
	StringPool* = OBJECT
	VAR bufList : BufferList;
		end* : LONGINT;
		nofBufs : LONGINT;
		
		
		PROCEDURE &Init*;
		BEGIN
			end := 0;
			NEW(bufList, 1);
			nofBufs := LEN(bufList);
		END Init;
		
		PROCEDURE GrowBufList;
		VAR i : LONGINT;
			t : BufferList;
		BEGIN
			NEW(t, nofBufs * 2);
			FOR i := 0 TO nofBufs - 1 DO t[i] := bufList[i] END;
			bufList := t;
			nofBufs := LEN(bufList);
		END GrowBufList;
		
		PROCEDURE AddString*(CONST str : ARRAY OF CHAR) : LONGINT;
		VAR i, result, bufNr, bufPos : LONGINT; 
		BEGIN {EXCLUSIVE}
			result := end;
			i := 0;
			WHILE str[i] # 0X DO
				bufNr := end DIV BufSize; bufPos := end MOD BufSize;
				IF bufNr >= nofBufs THEN GrowBufList END;
				IF bufList[bufNr] = NIL THEN NEW(bufList[bufNr]) END;
				bufList[bufNr][bufPos] := str[i];
				INC(end); INC(i);
			END;
			bufNr := end DIV BufSize; 	bufPos := end MOD BufSize;
			IF bufNr >= nofBufs THEN GrowBufList END;
			IF bufList[bufNr] = NIL THEN NEW(bufList[bufNr]) END;
			bufList[bufNr][bufPos] := 0X;
			INC(end);
			RETURN result
		END AddString;
		
		PROCEDURE GetString*(i : LONGINT; VAR str : ARRAY OF CHAR);
		VAR ch : CHAR; j : LONGINT;
		BEGIN {EXCLUSIVE}
			j := 0;
			REPEAT 
				ch := bufList[i DIV BufSize][i MOD BufSize];
				str[j] := ch;
				INC(i); INC(j)
			UNTIL ch = 0X
		END GetString;
		
		PROCEDURE Equal*(a, b : LONGINT) : BOOLEAN;
		VAR ca, cb : CHAR;
		BEGIN {EXCLUSIVE}
			REPEAT 
				ca := bufList[a DIV BufSize][a MOD BufSize];
				cb := bufList[b DIV BufSize][b MOD BufSize];
				INC(a); INC(b)
			UNTIL (ca # cb) OR (ca = 0X);
			RETURN ca = cb 
		END Equal;
		
	END StringPool;

VAR
	s : StringPool;
	
PROCEDURE Test*(par : ANY) : ANY;
VAR x, y : ARRAY 128 OF CHAR;
	i : LONGINT;
	buf : POINTER TO ARRAY OF LONGINT;
BEGIN
	NEW(buf, 1000000);
	FOR i := 0 TO 1000000 - 1  DO
		Strings.IntToStr(i, x);
(*		Strings.Append(x, " - Huga"); *)
		buf[i] := s.AddString(x);
	END;

	FOR i := 0 TO 1000000 - 1  DO
		Strings.IntToStr(i, x);
(*		Strings.Append(x, " - Huga"); *)
		s.GetString(buf[i], y);
		IF x # y THEN Trace.String("Failed"); Trace.Ln;  END;
	END;
	Trace.String("done"); Trace.Ln; 

	RETURN NIL
END Test;
	
	
BEGIN
	NEW(s);

END TFStringPool.


TFStringPool.Test ~
S.Free TFStringPool ~