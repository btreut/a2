MODULE BitSets;	(** AUTHOR "negelef"; PURPOSE "generic bit container"; *)

IMPORT SYSTEM;

CONST Elements = MAX (SET) - MIN (SET) + 1;

TYPE Data = POINTER TO ARRAY OF SET;

TYPE BitSet* = OBJECT
	VAR size: SIZE;
	VAR data: Data;

	PROCEDURE & InitBitSet* (size: LONGINT);
	BEGIN SELF.size := size; Resize (size);
	END InitBitSet;

	PROCEDURE Zero*;
	VAR i: SIZE;
	BEGIN FOR i := 0 TO LEN(data)-1 DO data[i] := {} END;
	END Zero;

	PROCEDURE Resize* (size: SIZE);
	VAR newData: Data; i: SIZE;
	BEGIN
		ASSERT (size >= 0);
		SELF.size := size;
		size := MAX (size - 1, 0) DIV Elements + 1;
		IF data # NIL THEN
			IF size <= LEN (data) THEN RETURN; END;
			size := MAX (size, LEN (data) * 2);
		END;
		NEW (newData, size);
		IF data # NIL THEN
			FOR i := 0 TO LEN (data) - 1 DO newData[i] := data[i]; END;
		END;
		data := newData;
	END Resize;

	PROCEDURE GetSize* (): SIZE;
	BEGIN RETURN size;
	END GetSize;

	PROCEDURE SetBit* (pos: SIZE; value: BOOLEAN);
	BEGIN
		ASSERT (pos >= 0); ASSERT (pos < size);
		IF value THEN
			INCL (data[pos DIV Elements], pos MOD Elements);
		ELSE
			EXCL (data[pos DIV Elements], pos MOD Elements);
		END;
	END SetBit;

	PROCEDURE GetBit* (pos: SIZE): BOOLEAN;
	BEGIN
		ASSERT (pos >= 0); ASSERT (pos < size);
		RETURN pos MOD Elements IN data[pos DIV Elements];
	END GetBit;

	PROCEDURE SetBits* (startPos: SIZE; bits, value: LONGINT);
	VAR adr: ADDRESS;
	BEGIN
		ASSERT (startPos >= 0); ASSERT (startPos+bits <= size);
		IF (bits = 8) & (startPos MOD 8 = 0) THEN
			adr := ADDRESS OF data[0] + startPos DIV 8;
			SYSTEM.PUT(adr, CHR(value));
		ELSE
			WHILE bits > 0 DO
				SetBit (startPos, ODD (value)); value := value DIV 2;
				INC(startPos); DEC(bits)
			END;
			WHILE bits < 0 DO
				SetBit (startPos, ODD (value)); value := value DIV 2;
				DEC(startPos); INC(bits)
			END;
		END;
	END SetBits;
	
	PROCEDURE SetBytes*(startPos: SIZE; bytes: LONGINT; CONST values: ARRAY OF CHAR);
	VAR adr: ADDRESS; i: SIZE;
	BEGIN
		ASSERT (startPos >= 0); ASSERT (startPos+8*bytes <= size); ASSERT(startPos MOD 8 = 0);
		adr := ADDRESS OF data[0] + startPos DIV 8;
		SYSTEM.MOVE(ADDRESS OF values[0], adr, bytes);
	END SetBytes;

	PROCEDURE GetBits* (startPos: SIZE; bits: LONGINT): LONGINT;
	VAR value: LONGINT; adr: ADDRESS;
	BEGIN
		ASSERT (startPos >= 0); ASSERT (startPos+bits <= size);
		IF (bits = 8) & (startPos MOD 8 =0) THEN
			adr := ADDRESS OF data[0] + startPos DIV 8;
			value := SYSTEM.GET8(adr)
		ELSE
			INC (startPos, bits); value := 0;
			WHILE bits > 0 DO
				value := value*2; DEC (startPos); DEC (bits);
				IF GetBit (startPos) THEN INC (value) END;
			END;
			WHILE bits < 0 DO
				value := value*2; INC (startPos); INC (bits);
				IF GetBit (startPos) THEN INC (value) END;
			END;
		END;
		RETURN value;
	END GetBits;

	PROCEDURE CopyTo*(address: ADDRESS; bits: SIZE);
	BEGIN
		ASSERT(bits MOD 8 = 0);
		SYSTEM.MOVE(ADDRESS OF data[0], address, bits DIV 8);
	END CopyTo;

END BitSet;

PROCEDURE CopyBits* (source: BitSet; sourcePos: LONGINT; dest: BitSet; destPos, count: LONGINT);
CONST setSize= MAX(SET)+1;
BEGIN
	ASSERT (count >= 0);
	IF sourcePos MOD setSize = destPos MOD setSize THEN
		WHILE (count # 0) & (sourcePos MOD setSize # 0) DO
			dest.SetBit (destPos, source.GetBit (sourcePos));
			INC (sourcePos); INC (destPos); DEC (count);
		END;
		WHILE (count > 31) DO
			dest.data[destPos DIV setSize] := source.data[sourcePos DIV setSize];
			INC(sourcePos,setSize); INC(destPos,setSize); DEC(count,setSize);
		END;
		WHILE count # 0 DO
			dest.SetBit (destPos, source.GetBit (sourcePos));
			INC (sourcePos); INC (destPos); DEC (count);
		END;
	ELSE
		WHILE count # 0 DO
			dest.SetBit (destPos, source.GetBit (sourcePos));
			INC (sourcePos); INC (destPos); DEC (count);
		END;
	END;
END CopyBits;



END BitSets.

