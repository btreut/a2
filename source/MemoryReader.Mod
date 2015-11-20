(** AUTHOR "rg"; PURPOSE "Memory reader"; *)

MODULE MemoryReader;

IMPORT SYSTEM, Streams;

CONST
	DefaultReaderSize = 64;

TYPE
	Reader* = OBJECT (Streams.Reader)
		VAR
			memoryAdr: ADDRESS;
			available : LONGINT;

		PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min : LONGINT; VAR len, res: LONGINT);
		BEGIN
			ASSERT(ofs+size <= LEN(buf));
			IF available # 0 THEN
				IF size >= available THEN len := available
				ELSE len := size END;
				SYSTEM.MOVE(memoryAdr, ADDRESSOF(buf[0])+ofs, len);
				INC(memoryAdr, len);
				DEC(available, len);
				res := Streams.Ok
			ELSE
				len := 0;
				res := Streams.EOF
			END
		END Receive;

		PROCEDURE &InitMemoryReader*(memoryAdr: ADDRESS; length : LONGINT);
		BEGIN
			SELF.memoryAdr := memoryAdr;
			available := length;
			InitReader(Receive, DefaultReaderSize);
		END InitMemoryReader;
	END Reader;

END MemoryReader.