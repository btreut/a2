MODULE StringPool;	(** prk  **) (** AUTHOR "prk"; PURPOSE "StringPool"; *)

IMPORT
		SYSTEM,
		KernelLog;	(*debug only*)

(**
	StringPool stores strings of any length. Equal strings have the same index.
	String with index 0 is guaranteed to be the empty string.
*)


CONST
	(* Module Configuration *)
	StringPoolSize0 = 1024*256;	(* initial string pool size *)
	HashTableSize0 = 1024;	(* initial hash table size *)


TYPE
	(* Helper Structures *)
	Index* = LONGINT;
	StringPool = POINTER TO ARRAY OF CHAR;

VAR
	pool: StringPool;
	poolLen: LONGINT;
	poolIndex: POINTER TO ARRAY OF LONGINT;
	poolIndexSize: LONGINT;	(* LEN(poolIndex)-1 *)

	ALastGet,
	AStrings, AGetString, ACompareString, ACompareString0, AStringCmpHit, ASearchHits, ASearchMisses: LONGINT;
	AInsertHashRetries: ARRAY 10 OF LONGINT;
	ASearchHashRetries: ARRAY 10 OF LONGINT;

	(** ----------------- String Pool functions ------------------ *)

	(* Hash - Return an Hash value in [0, poolIndexSize[ *)

	PROCEDURE Hash(CONST str: ARRAY OF CHAR): LONGINT;
		VAR i, h: LONGINT;  ch: CHAR;
	BEGIN
		i := 0; ch := str[0]; h := 0;
		WHILE ch # 0X DO
			h :=SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ROT(h, 7)) / SYSTEM.VAL(SET, LONG(ORD(ch))));
			INC(i); ch := str[i]
		END;
		h := h MOD poolIndexSize;
		RETURN h
	END Hash;

	(* GrowPool - increase string pool size *)

	PROCEDURE GrowPool;
		VAR new: StringPool;
	BEGIN
		NEW(new, 2*LEN(pool));
		SYSTEM.MOVE(ADDRESSOF(pool[0]), ADDRESSOF(new[0]), LEN(pool));
		pool := new
	END GrowPool;

	(* GrowHashTable - Increase Hash table size and recompute all entries *)

	PROCEDURE GrowHashTable;
		VAR i, t, h, idx, idx0: LONGINT; ch: CHAR;
	BEGIN
		t := (poolIndexSize+1)*2;
		NEW(poolIndex, t);
		FOR i := 0 TO t-1 DO  poolIndex[i] := -1  END;
		FOR i := 0 TO LEN(AInsertHashRetries)-1 DO AInsertHashRetries[i] := 0 END;
		poolIndexSize := t-1;

		(* re-fill the hash-table *)
		idx := 0;
		WHILE idx < poolLen DO
			(*hash*)
			idx0 := idx; h := 0;
			ch := pool[idx];
			WHILE ch # 0X DO
				h :=SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ROT(h, 7)) / SYSTEM.VAL(SET, LONG(ORD(ch))));
				INC(idx); ch := pool[idx]
			END;
			h := h MOD poolIndexSize;
			INC(idx);	(*skip 0X*)

			i := 0;
			WHILE poolIndex[h] # -1 DO
				INC(i);
				INC(h);
				IF h >= poolIndexSize THEN  DEC(h, poolIndexSize)  END
			END;
			IF i >= LEN(AInsertHashRetries) THEN i := LEN(AInsertHashRetries)-1 END;
			INC(AInsertHashRetries[i]);

			poolIndex[h] := idx0
		END
	END GrowHashTable;

	(** GetString - Get a string from the string pool *)

	PROCEDURE GetString*(index: Index; VAR str: ARRAY OF CHAR);
		VAR i: LONGINT; ch: CHAR;
	BEGIN
		ALastGet := index;
		INC(AGetString);
		i := 0;
		REPEAT
			ch := pool[index+i]; str[i] := ch; INC(i)
		UNTIL ch = 0X
	END GetString;

	(* AddToPool - Add a string to the pool *)

	PROCEDURE AddToPool(VAR index: Index; CONST str: ARRAY OF CHAR);
	VAR i: LONGINT; ch: CHAR;
	BEGIN
		INC(AStrings);
		IF LEN(str) > LEN(pool) - poolLen THEN GrowPool END;
		i := 0; index := poolLen;
		REPEAT
			ch := str[i]; pool[poolLen+i] := ch; INC(i)
		UNTIL ch = 0X;
		INC(poolLen, i);
	END AddToPool;

	(** GetIndex - Retrieve a string from the pool, add if not present *)

	PROCEDURE GetIndex*(CONST str: ARRAY OF CHAR;  VAR index: Index);
		VAR i, h, idx: LONGINT;
	BEGIN {EXCLUSIVE}
		IF AStrings > poolIndexSize DIV 4 THEN GrowHashTable END;
		h := Hash(str);
		idx := poolIndex[h];
		i := 0;
		LOOP
			IF (idx = -1) THEN	(* miss *)
				INC(ASearchMisses);
				IF i >= 10 THEN i := 9 END;
				INC(AInsertHashRetries[i]);
				AddToPool(index, str);
				poolIndex[h] := index;
				EXIT
			ELSIF (CompareString0(idx, str) = 0) THEN
				INC(ASearchHits);
				IF i >= LEN(ASearchHashRetries) THEN i := LEN(ASearchHashRetries)-1 END;
				INC(ASearchHashRetries[i]);
				index := idx;
				EXIT
			END;
			INC(i);
			ASSERT(i < poolIndexSize);
			INC(h);
			IF h >= poolIndexSize THEN DEC(h, poolIndexSize) END;
			idx := poolIndex[h]
		END;
	END GetIndex;

	PROCEDURE GetIndex1*(CONST str: ARRAY OF CHAR): LONGINT;
		VAR idx: LONGINT;
	BEGIN
		GetIndex(str, idx); RETURN idx
	END GetIndex1;

	(** Compare two strings
		CompareString = 0 <==> Str(index1) = Str(index2)
		CompareString < 0 <==> Str(index1) < Str(index2)
		CompareString > 0 <==> Str(index1) > Str(index2)
	*)

	PROCEDURE CompareString*(index1, index2: Index): LONGINT;
		VAR  ch: CHAR;
	BEGIN
		INC(ACompareString);
		IF index1 = index2 THEN
			INC(AStringCmpHit); RETURN 0
		END;
		ch := pool[index1];
		WHILE (ch # 0X) & (ch = pool[index2]) DO
			INC(index1); INC(index2);
			ch := pool[index1]
		END;
		RETURN ORD(ch) - ORD(pool[index2])
	END CompareString;

	PROCEDURE CompareString0*(index: Index;  CONST str: ARRAY OF CHAR): LONGINT;
		(* using VAR str makes the _whole_ compiler 10% faster!!! *)
		VAR  ch1, ch2: CHAR; i: LONGINT;
	BEGIN
		INC(ACompareString0); i := 0;
		REPEAT
			ch1 := pool[index+i];
			ch2 := str[i];
			INC(i)
		UNTIL (ch1 = 0X) OR (ch1 # ch2);
		RETURN ORD(ch1) - ORD(ch2)
	END CompareString0;

(*
	optimized version (no index checks)

	PROCEDURE CompareString0*(index: Index;  VAR str: ARRAY OF CHAR): LONGINT;
		(* using VAR str makes the _whole_ compiler 10% faster!!! *)
		VAR  ch1, ch2: CHAR; adr1, adr2: ADDRESS; i: LONGINT;
	BEGIN
		INC(ACompareString0);
		adr1 := ADDRESSOF(pool[index]);
		adr2 := ADDRESSOF(str[0]);
		REPEAT
			SYSTEM.GET(adr1+i, ch1);
			SYSTEM.GET(adr2+i, ch2);
			INC(i)
		UNTIL (ch1 = 0X) OR (ch1 # ch2);

		RETURN ORD(ch1) - ORD(ch2)
	END CompareString0;
*)

	PROCEDURE DumpPool*;
		VAR i: LONGINT; ch: CHAR;
	BEGIN
		KernelLog.String("StringPool.Dump:");
		KernelLog.String("size = "); KernelLog.Int(poolLen,1);
		KernelLog.Ln;
		KernelLog.Int(0, 4); KernelLog.String(": ");
		i := 0;
		WHILE i < poolLen DO
			ch := pool[i]; INC(i);
			IF ch = 0X THEN
				KernelLog.Ln; KernelLog.Int(i, 4); KernelLog.String(": ");
			ELSE
				KernelLog.Char(ch)
			END
		END;
	END DumpPool;

	PROCEDURE Init;
		VAR i: LONGINT; str: ARRAY 2 OF CHAR;
	BEGIN
		NEW(pool, StringPoolSize0);
		NEW(poolIndex, HashTableSize0);
		poolIndexSize := HashTableSize0-1;
		FOR i := 0 TO poolIndexSize DO poolIndex[i] := -1 END;
		str := "";
		AddToPool(i, str);
	END Init;

BEGIN
	Init;
END StringPool.

(*
ToDo:
* store string len in the pool, use it when retrieving (SYS.MOVE). In this case entries should be aligned

Log:
	15.03.02	prk	ALastGet added; DumpPool improved
	08.02.02	prk	use Aos instead of Oberon modules
	27.06.01	prk	first version
*)