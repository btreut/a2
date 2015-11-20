MODULE FoxBasic;   (**  AUTHOR "fof"; PURPOSE "Oberon Compiler: basic helpers: strings, lists, hash tables, graphs, indented writer";  **)
(* (c) fof ETH Zürich, 2009 *)


IMPORT KernelLog, StringPool, Strings, Streams, Diagnostics, Files, SYSTEM, ObjectFile, D:= Debugging;

CONST
	(* error numbers *)
	(* first 255 tokens reserved for expected symbol error message *)
	UndeclaredIdentifier* = 256;
	MultiplyDefinedIdentifier* = 257;
	NumberIllegalCharacter* = 258;
	StringIllegalCharacter* = 259;
	NoMatchProcedureName* = 260;
	CommentNotClosed* = 261;
	IllegalCharacterValue* = 262;
	ValueStartIncorrectSymbol* = 263;
	IllegalyMarkedIdentifier* = 264;
	IdentifierNoType* = 265;
	IdentifierNoRecordType* = 266;
	IdentifierNoObjectType* = 267;
	ImportNotAvailable* = 268;
	RecursiveTypeDeclaration* = 269;
	NumberTooLarge* = 270;
	IdentifierTooLong* = 271;
	StringTooLong* = 272;

	InitListSize = 4;
	InitErrMsgSize = 300;	(* initial size of array of error messages *)

	(* value of constant NIL *)
	nilval* = 0;

	ExportedUnicodeSupport* = FALSE;

	(* target machine minimum values of basic types expressed in host machine format: *)
	MinSInt* = -80H;
	MinInt* = -8000H;
	MinLInt* = -80000000H;   (* i386: -2147483648*)

	(* target machine maximum values of basic types expressed in host machine format: *)
	MaxSInt* = 7FH;
	MaxInt* = 7FFFH;
	MaxLInt* = 7FFFFFFFH;   (* i386: 2147483647*)
	MaxSet* = 31;   (* must be >= 15, else the bootstraped compiler cannot run (IN-tests) *)

	invalidString*=-1;

TYPE
	(*
	String* = POINTER TO ARRAY OF CHAR;
	*)
	String* = StringPool.Index;
	SegmentedName*= ObjectFile.SegmentedName;
	FileName*= Files.FileName;
	SectionName*= ARRAY 256 OF CHAR;
	MessageString*= ARRAY 256 OF CHAR;

	ObjectArray = POINTER TO ARRAY OF ANY;
	IntegerArray = POINTER TO ARRAY OF LONGINT;

	ErrorMsgs = POINTER TO ARRAY OF StringPool.Index;

	ComparisonFunction = PROCEDURE {DELEGATE} (object1, object2: ANY): BOOLEAN;

	List* = OBJECT  (* by Luc Bläser *)
	VAR
		list: ObjectArray;
		count-: LONGINT;
		multipleAllowed*: BOOLEAN;
		nilAllowed*: BOOLEAN;

		PROCEDURE & InitList*(initialSize: LONGINT) ;
		BEGIN
			IF initialSize <= 0 THEN initialSize := 8 END;
			INC( lists );  NEW( list, initialSize );  count := 0;  multipleAllowed := FALSE;  nilAllowed := FALSE
		END InitList;

		PROCEDURE Length*( ): LONGINT;
		BEGIN
			RETURN count
		END Length;

		PROCEDURE Grow;
		VAR old: ObjectArray;  i: LONGINT;
		BEGIN
			INC( enlarged );  old := list;  NEW( list, (LEN( list ) * 3+1) DIV 2 (* more optimal for first-fit memory allocators *) ) ;
			FOR i := 0 TO count - 1 DO list[i] := old[i] END
		END Grow;

		PROCEDURE Get*( i: LONGINT ): ANY;
		BEGIN
			IF (i < 0) OR (i >= count) THEN HALT( 101 ) END;
			RETURN list[i]
		END Get;

		PROCEDURE Set*(i: LONGINT; x: ANY);
		BEGIN
			IF (i < 0) OR (i >= count) THEN HALT( 101 ) END;
			list[i] := x;
		END Set;

		PROCEDURE Add*( x: ANY );
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL ) END;
			IF ~multipleAllowed THEN ASSERT( ~debug OR ~Contains( x ) ) END;   (* already contained *)
			IF count = LEN( list ) THEN Grow END;
			list[count] := x;  INC( count )
		END Add;

		PROCEDURE Prepend*(x: ANY);
		VAR i: LONGINT;
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL ) END;
			IF ~multipleAllowed THEN ASSERT( debug OR ~Contains( x ) ) END;   (* already contained *)
			IF count = LEN( list ) THEN Grow END;

			FOR i := count-1  TO 0 BY - 1 DO
				list[i+1] := list[i];
			END;
			list[0] := x; INC(count);
		END Prepend;

		PROCEDURE Append*(x: List);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO x.Length() - 1 DO
				IF multipleAllowed OR (~debug OR ~Contains(x.Get(i))) THEN
					Add(x.Get(i));
				END;
			END;
		END Append;

		PROCEDURE Remove*( x: ANY );
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (i < count) & (list[i] # x) DO INC( i ) END;
			IF i < count THEN
				WHILE (i < count - 1) DO list[i] := list[i + 1];  INC( i ) END;
				DEC( count );  list[count] := NIL
			END
		END Remove;

		PROCEDURE RemoveByIndex*( i: LONGINT );
		BEGIN
			IF i < count THEN
				WHILE (i < count - 1) DO list[i] := list[i + 1];  INC( i ) END;
				DEC( count );  list[count] := NIL
			END
		END RemoveByIndex;

		PROCEDURE Insert*( i: LONGINT; x: ANY );
		VAR j: LONGINT;
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL ) END;
			IF ~multipleAllowed THEN ASSERT( ~debug OR ~Contains( x ) ) END;   (* already contained *)

			IF count = LEN( list ) THEN Grow END; INC( count );

			j := count - 2;
			WHILE (j >= i) DO list[j+1] := list[j]; DEC( j ) END;
			list[i] := x;
		END Insert;

		PROCEDURE Replace*( x, y: ANY );
		VAR i: LONGINT;
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL );  ASSERT( y # NIL ) END;
			i := IndexOf( x );
			IF i >= 0 THEN list[i] := y END
		END Replace;

		PROCEDURE ReplaceByIndex*( i: LONGINT;  x: ANY );
		BEGIN
			IF ~nilAllowed THEN ASSERT( x # NIL ) END;
			IF (i >= 0) & (i < count) THEN list[i] := x
					ELSE HALT( 101 ) (* out of boundaries *)
			END
		END ReplaceByIndex;

		(** If the object is not present, -1 is returned *)
		PROCEDURE IndexOf*( x: ANY ): LONGINT;
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE i < count DO
				IF list[i] = x THEN RETURN i END;
				INC( i )
			END;
			RETURN -1
		END IndexOf;

		PROCEDURE Contains*( x: ANY ): BOOLEAN;
		BEGIN
			RETURN IndexOf( x ) # -1
		END Contains;

		PROCEDURE Clear*;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO count - 1 DO list[i] := NIL END;
			count := 0
		END Clear;

		PROCEDURE GrowAndSet*(i: LONGINT; x: ANY);
		BEGIN
			IF (i<0) THEN HALT(101) END;
			WHILE i>=LEN(list) DO Grow END;
			list[i] := x;
			INC(i); IF count < i THEN count := i END;
		END GrowAndSet;

		PROCEDURE Sort*(comparisonFunction: ComparisonFunction);
		BEGIN
			IF count > 0 THEN
				QuickSort(comparisonFunction, 0, count - 1)
			END
		END Sort;

		PROCEDURE QuickSort(comparisonFunction: ComparisonFunction; lo, hi: LONGINT);
		VAR
			i, j: LONGINT;
			x, t: ANY;
		BEGIN
			i := lo; j := hi;
			x := list[(lo + hi) DIV 2];

			WHILE i <= j DO
				WHILE comparisonFunction(list[i], x) DO INC(i) END;
				WHILE comparisonFunction(x, list[j]) DO DEC(j) END;

				IF i <= j THEN
					(*IF (i < j) & comparisonFunction(list[j], list[i]) THEN*)
						t := list[i]; list[i] := list[j]; list[j] := t; (* swap i and j *)
					(*END;*)

					INC(i); DEC(j)
				END
			END;

			IF lo < j THEN QuickSort(comparisonFunction, lo, j) END;
			IF i < hi THEN QuickSort(comparisonFunction, i, hi) END
		END QuickSort;
	END List;

	IntegerList* = OBJECT
	VAR list: IntegerArray;
		count-: LONGINT;

		PROCEDURE & InitList*(initialSize: LONGINT) ;
		BEGIN
			INC( lists );  NEW( list, initialSize );  count := 0;
		END InitList;

		PROCEDURE Length*( ): LONGINT;
		BEGIN RETURN count END Length;

		PROCEDURE Grow;
		VAR old: IntegerArray;  i: LONGINT;
		BEGIN
			INC( enlarged );  old := list;  NEW( list, LEN( list ) * 4 );
			FOR i := 0 TO count - 1 DO list[i] := old[i] END
		END Grow;

		PROCEDURE Get*( i: LONGINT ): LONGINT;
		BEGIN
			IF (i < 0) OR (i >= count) THEN HALT( 101 ) END;
			RETURN list[i]
		END Get;

		PROCEDURE Set*(i: LONGINT; x: LONGINT);
		BEGIN
			IF (i < 0) OR (i >= count) THEN HALT( 101 ) END;
			list[i] := x;
		END Set;

		PROCEDURE Add*( x: LONGINT );
		BEGIN
			IF count = LEN( list ) THEN Grow END;
			list[count] := x;  INC( count )
		END Add;

		PROCEDURE Prepend*(x: LONGINT);
		VAR i: LONGINT;
		BEGIN
			IF count = LEN( list ) THEN Grow END;

			FOR i := count-1  TO 0 BY - 1 DO
				list[i+1] := list[i];
			END;
			list[0] := x; INC(count);
		END Prepend;

		PROCEDURE Append*(x: IntegerList);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO x.Length() - 1 DO
				Add(x.Get(i));
			END;
		END Append;

		PROCEDURE Remove*( x: LONGINT );
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE (i < count) & (list[i] # x) DO INC( i ) END;
			IF i < count THEN
				WHILE (i < count - 1) DO list[i] := list[i + 1];  INC( i ) END;
				DEC( count );
			END
		END Remove;

		PROCEDURE RemoveByIndex*( i: LONGINT );
		BEGIN
			IF i < count THEN
				WHILE (i < count - 1) DO list[i] := list[i + 1];  INC( i ) END;
				DEC( count );
			END
		END RemoveByIndex;

		PROCEDURE Insert*( i,x: LONGINT);
		VAR j: LONGINT;
		BEGIN
			ASSERT((i >= 0) & (i < count));

			IF count = LEN( list ) THEN Grow END; INC( count );

			j := count - 2;
			WHILE (j >= i) DO list[j+1] := list[j]; DEC( j ) END;
			list[i] := x;
		END Insert;

		PROCEDURE Replace*( x, y: LONGINT );
		VAR i: LONGINT;
		BEGIN
			i := IndexOf( x );
			IF i >= 0 THEN list[i] := y END
		END Replace;

		PROCEDURE IndexOf*( x: LONGINT ): LONGINT;
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE i < count DO
				IF list[i] = x THEN RETURN i END;
				INC( i )
			END;
			RETURN -1
		END IndexOf;

		PROCEDURE Contains*( x: LONGINT ): BOOLEAN;
		BEGIN RETURN IndexOf( x ) # -1; END Contains;

		PROCEDURE Clear*;
		BEGIN count := 0 END Clear;

	END IntegerList;

	(* Supports get, add, contain, append in O(1) *)
	Bag* = OBJECT
	VAR
		count-: LONGINT;
		list: List;

		PROCEDURE & InitBag* ;
		BEGIN
			Clear();
		END InitBag;

		PROCEDURE Length*( ): LONGINT;
		BEGIN
			RETURN list.Length();
		END Length;

		PROCEDURE Get*( i: LONGINT ): ANY;
		BEGIN RETURN list.Get(i); END Get;

		PROCEDURE Add*( x: ANY );
		BEGIN
			ASSERT( x # NIL );
			IF ~Contains(x) THEN
				list.Add(x);
			END;
		END Add;

		PROCEDURE Append*(x: Bag);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO x.Length() - 1 DO
				IF ~Contains(x.Get(i)) THEN
					Add(x.Get(i));
				END;
			END;
		END Append;

		PROCEDURE Remove*( x: ANY );
		BEGIN
			list.Remove(x);
		END Remove;

		PROCEDURE Contains*( x: ANY ): BOOLEAN;
		BEGIN RETURN list.Contains(x); END Contains;

		PROCEDURE Clear*;
		BEGIN
			count := 0;
			NEW(list,InitListSize);
			list.multipleAllowed := TRUE; list.nilAllowed := TRUE;
		END Clear;

	END Bag;

	(* Supports get, add, contain, append in O(1) *)
	IntegerBag* = OBJECT
	VAR
		count-: LONGINT;
		list: IntegerList;

		PROCEDURE & InitBag* ;
		BEGIN
			Clear();
		END InitBag;

		PROCEDURE Length*( ): LONGINT;
		BEGIN
			RETURN list.Length();
		END Length;

		PROCEDURE Get*( i: LONGINT ):LONGINT;
		BEGIN RETURN list.Get(i); END Get;

		PROCEDURE Add*( x: LONGINT );
		BEGIN
			IF ~Contains(x) THEN
				list.Add(x);
			END;
		END Add;

		PROCEDURE Append*(x: IntegerBag);
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO x.Length() - 1 DO
				IF ~Contains(x.Get(i)) THEN
					Add(x.Get(i));
				END;
			END;
		END Append;

		PROCEDURE Remove*(x: LONGINT );
		BEGIN
			list.Remove(x);
		END Remove;

		PROCEDURE Contains*( x: LONGINT ): BOOLEAN;
		BEGIN RETURN list.Contains(x); END Contains;

		PROCEDURE Clear*;
		BEGIN
			count := 0;
			NEW(list,InitListSize);
		END Clear;

	END IntegerBag;

	HashEntryAny = RECORD
		key, value: ANY;
		valueInt: LONGINT;
	END;

	HashEntryInt = RECORD
		key, valueInt: LONGINT;
		value: ANY;
	END;


	HashAnyArray = POINTER TO ARRAY OF HashEntryAny;
	HashIntArray = POINTER TO ARRAY OF HashEntryInt;

	HashTable* = OBJECT
	VAR
		table: HashAnyArray;
		size: LONGINT;
		used-: LONGINT;
		maxLoadFactor: REAL;

		(* Interface *)

		PROCEDURE & Init* (initialSize: LONGINT);
		BEGIN
			ASSERT(initialSize > 2);
			NEW(table, initialSize);
			size := initialSize;
			used := 0;
			maxLoadFactor := 0.75;
		END Init;

		PROCEDURE Put*(key, value: ANY);
		VAR hash: LONGINT;
		BEGIN
			ASSERT(used < size);
			ASSERT(key # NIL);
			hash := HashValue(key);
			IF table[hash].key = NIL THEN
				INC(used, 1);
			ELSE
				ASSERT(table[hash].key = key);
			END;
			table[hash].key := key;
			table[hash].value := value;

			IF (used / size) > maxLoadFactor THEN Grow END;
		END Put;

		PROCEDURE Get*(key: ANY):ANY;
		BEGIN
			RETURN table[HashValue(key)].value;
		END Get;

		PROCEDURE Has*(key: ANY):BOOLEAN;
		BEGIN
			RETURN table[HashValue(key)].key = key;
		END Has;

		PROCEDURE Length*():LONGINT;
		BEGIN RETURN used; END Length;

		PROCEDURE Clear*;
		VAR i: LONGINT;
		BEGIN FOR i := 0 TO size - 1 DO table[i].key := NIL; table[i].value := NIL; table[i].valueInt := 0 END; END Clear;

		(* Interface for integer values *)

		PROCEDURE PutInt*(key: ANY; value: LONGINT);
		VAR hash: LONGINT;
		BEGIN
			ASSERT(used < size);
			hash := HashValue(key);
			IF table[hash].key = NIL THEN
				INC(used, 1);
			END;
			table[hash].key := key;
			table[hash].valueInt := value;
			IF (used / size) > maxLoadFactor THEN Grow END;
		END PutInt;

		PROCEDURE GetInt*(key: ANY):LONGINT;
		BEGIN RETURN table[HashValue(key)].valueInt; END GetInt;

		(* Internals *)

		(* only correctly working, if NIL key cannot be entered *)
		PROCEDURE HashValue(key: ANY):LONGINT;
		VAR value, h1, h2, i: LONGINT;
		BEGIN
			value := SYSTEM.VAL(LONGINT, key) DIV SIZEOF(ADDRESS);
			i := 0;
			h1 := value MOD size;
			h2 := 1; (* Linear probing *)
			REPEAT
				value := (h1 + i*h2) MOD size;
				INC(i);
			UNTIL((table[value].key = NIL) OR (table[value].key = key) OR (i > size));
			ASSERT((table[value].key = NIL) & (table[value].value = NIL) OR (table[value].key = key));
			RETURN value;
		END HashValue;

		PROCEDURE Grow;
		VAR oldTable: HashAnyArray; oldSize, i: LONGINT; key: ANY;
		BEGIN
			oldSize := size;
			oldTable := table;
			Init(size*2);
			FOR i := 0 TO oldSize-1 DO
				key := oldTable[i].key;
				IF key # NIL THEN
					IF oldTable[i].value # NIL THEN
						Put(key, oldTable[i].value);
					ELSE
						PutInt(key, oldTable[i].valueInt);
					END;
				END;
			END;
		END Grow;

	END HashTable;

	IntIterator*= OBJECT
	VAR
		table: HashIntArray;
		count : LONGINT;
		
		PROCEDURE & Init(t: HashIntArray);
		BEGIN
			table := t;
			count := -1;
		END Init;
		
		PROCEDURE GetNext*(VAR key: LONGINT; VAR value: ANY): BOOLEAN;
		BEGIN
			REPEAT
				INC(count);
			UNTIL (count = LEN(table)) OR (table[count].value # NIL);
			IF count = LEN(table) THEN 
				RETURN FALSE
			END;
			key := table[count].key;
			value := table[count].value;
			RETURN TRUE;
		END GetNext;
		
		
	END IntIterator;

	HashTableInt* = OBJECT
	VAR
		table: HashIntArray;
		size: LONGINT;
		used-: LONGINT;
		maxLoadFactor: REAL;

		(* Interface *)

		PROCEDURE & Init* (initialSize: LONGINT);
		BEGIN
			ASSERT(initialSize > 2);
			NEW(table, initialSize);
			size := initialSize;
			used := 0;
			maxLoadFactor := 0.75;
		END Init;

		PROCEDURE Put*(key: LONGINT; value: ANY);
		VAR hash: LONGINT;
		BEGIN
			ASSERT(key # 0);
			ASSERT(used < size);
			hash := HashValue(key);
			IF table[hash].key = 0 THEN
				INC(used, 1);
			END;
			table[hash].key := key;
			table[hash].value := value;
			IF (used / size) > maxLoadFactor THEN Grow END;
		END Put;

		PROCEDURE Get*(key: LONGINT):ANY;
		BEGIN
			RETURN table[HashValue(key)].value;
		END Get;

		PROCEDURE Has*(key: LONGINT):BOOLEAN;
		BEGIN
			RETURN table[HashValue(key)].key = key;
		END Has;

		PROCEDURE Length*():LONGINT;
		BEGIN RETURN used; END Length;

		PROCEDURE Clear*;
		VAR i: LONGINT;
		BEGIN FOR i := 0 TO size - 1 DO table[i].key := 0; END; END Clear;

		(* Interface for integer values *)

		PROCEDURE PutInt*(key, value: LONGINT);
		VAR hash: LONGINT;
		BEGIN
			(*ASSERT(key # 0);*)
			ASSERT(used < size);
			hash := HashValue(key);
			IF table[hash].key = 0 THEN
				INC(used, 1);
			END;
			table[hash].key := key;
			table[hash].valueInt := value;
			IF (used / size) > maxLoadFactor THEN Grow END;
		END PutInt;

		PROCEDURE GetInt*(key: LONGINT):LONGINT;
		BEGIN RETURN table[HashValue(key)].valueInt; END GetInt;

		(* Internals *)

		PROCEDURE HashValue(key: LONGINT):LONGINT;
		VAR value, h1, h2, i: LONGINT;
		BEGIN
			i := 0;
			value := key;
			h1 := key MOD size;
			h2 := 1; (* Linear probing *)
			REPEAT
				value := (h1 + i*h2) MOD size;
				INC(i);
			UNTIL((table[value].key = 0) OR (table[value].key = key) OR (i > size));
			ASSERT((table[value].key = 0) OR (table[value].key = key));
			RETURN value;
		END HashValue;

		PROCEDURE Grow;
		VAR oldTable: HashIntArray; oldSize, i, key: LONGINT;
		BEGIN
			oldSize := size;
			oldTable := table;
			Init(size*2);
			FOR i := 0 TO oldSize-1 DO
				key := oldTable[i].key;
				IF key # 0 THEN
					IF oldTable[i].value # NIL THEN
						Put(key, oldTable[i].value);
					ELSE
						PutInt(key, oldTable[i].valueInt);
					END;
				END;
			END;
		END Grow;

		PROCEDURE GetIterator*(): IntIterator;
		VAR iterator: IntIterator;
		BEGIN
			NEW(iterator, table);
			RETURN iterator;
		END GetIterator;
		
	END HashTableInt;

	HashEntrySegmentedName = RECORD
		key: ObjectFile.SegmentedName; (* key[0]= MIN(LONGINT) <=> empty *)
		value: ANY;
	END;
	HashSegmentedNameArray = POINTER TO ARRAY OF HashEntrySegmentedName;

	HashTableSegmentedName* = OBJECT
	VAR
		table: HashSegmentedNameArray;
		size: LONGINT;
		used-: LONGINT;
		maxLoadFactor: REAL;

		(* Interface *)

		PROCEDURE & Init* (initialSize: LONGINT);
		BEGIN
			ASSERT(initialSize > 2);
			NEW(table, initialSize);
			size := initialSize;
			used := 0;
			maxLoadFactor := 0.75;
			Clear;
		END Init;

		PROCEDURE Put*(CONST key: SegmentedName; value: ANY);
		VAR hash: LONGINT;
		BEGIN
			ASSERT(used < size);
			hash := HashValue(key);
			IF table[hash].key[0] < 0 THEN
				INC(used, 1);
			END;
			table[hash].key := key;
			table[hash].value := value;
			IF (used / size) > maxLoadFactor THEN Grow END;
		END Put;

		PROCEDURE Get*(CONST key: SegmentedName):ANY;
		BEGIN
			RETURN table[HashValue(key)].value;
		END Get;

		PROCEDURE Has*(CONST key: SegmentedName):BOOLEAN;
		BEGIN
			RETURN table[HashValue(key)].key = key;
		END Has;

		PROCEDURE Length*():LONGINT;
		BEGIN RETURN used; END Length;

		PROCEDURE Clear*;
		VAR i: LONGINT;
		BEGIN FOR i := 0 TO size - 1 DO table[i].key[0] := -1; END; END Clear;

		(* Internals *)
		PROCEDURE Hash*(CONST name: SegmentedName): LONGINT;
		VAR fp,i: LONGINT;
		BEGIN
			fp := name[0]; i := 1;
			WHILE (i<LEN(name)) & (name[i] >= 0) DO
				fp:=SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, ROT(fp, 7)) / SYSTEM.VAL(SET, name[i]));
				INC(i);
			END;
			RETURN fp
		END Hash;

		PROCEDURE HashValue(CONST key: SegmentedName):LONGINT;
		VAR value, h,i: LONGINT;
		BEGIN
			ASSERT(key[0] >= 0);
			h := Hash(key);
			i := 0;
			REPEAT
				value := (h + i) MOD size;
				INC(i);
			UNTIL((table[value].key[0] < 0) OR (table[value].key = key) OR (i > size));
			ASSERT((table[value].key[0] <0 ) OR (table[value].key = key));
			RETURN value;
		END HashValue;

		PROCEDURE Grow;
		VAR oldTable: HashSegmentedNameArray; oldSize, i: LONGINT; key: SegmentedName;
		BEGIN
			oldSize := size;
			oldTable := table;
			Init(size*2);
			FOR i := 0 TO oldSize-1 DO
				key := oldTable[i].key;
				IF key[0] # MIN(LONGINT) THEN
					IF oldTable[i].value # NIL THEN
						Put(key, oldTable[i].value);
					END;
				END;
			END;
		END Grow;

	END HashTableSegmentedName;


	(* Hash table supporting 2 keys *)
	HashTable2D* = OBJECT(HashTable);
	VAR
		initialSize: LONGINT;

		(* Interface *)

		PROCEDURE & Init* (initialSize: LONGINT);
		BEGIN
			Init^(initialSize);
			SELF.initialSize := initialSize;
		END Init;

		PROCEDURE Get2D*(key1, key2: ANY):ANY;
		VAR
			any: ANY;
			second: HashTable;
		BEGIN
			any := Get(key1);
			second := any(HashTable);
			RETURN second.Get(key2);
		END Get2D;

		PROCEDURE Put2D*(key1, key2, value: ANY);
		VAR
			any: ANY;
			second: HashTable;
		BEGIN
			IF ~Has(key1) THEN
				NEW(second, initialSize);
				Put(key1, second);
			ELSE
				any := Get(key1);
				second := any(HashTable);
			END;
			second.Put(key2, value);
		END Put2D;

		PROCEDURE Has2D*(key1, key2: ANY):BOOLEAN;
		VAR
			any: ANY;
			second: HashTable;
		BEGIN
			IF ~Has(key1) THEN RETURN FALSE; END;
			any := Get(key1);
			second := any(HashTable);
			RETURN second.Has(key2);
		END Has2D;

	END HashTable2D;

	(* Data structure implementing a stack using lists *)
	Stack* = OBJECT
	VAR
		list: List;

		PROCEDURE & Init*;
		BEGIN NEW(list,InitListSize); END Init;

		(* Push on top of stack *)
		PROCEDURE Push*(x: ANY);
		BEGIN list.Add(x); END Push;

		(* Get top element *)
		PROCEDURE Peek*():ANY;
		BEGIN RETURN list.Get(list.Length() - 1); END Peek;

		(* Get and remove top element *)
		PROCEDURE Pop*():ANY;
		VAR old: ANY;
		BEGIN
			old := Peek();
			RemoveTop();
			RETURN old;
		END Pop;

		(* Remove top element without reading it *)
		PROCEDURE RemoveTop*;
		BEGIN list.RemoveByIndex(list.Length() - 1); END RemoveTop;

		(* Check if empty *)
		PROCEDURE Empty*():BOOLEAN;
		BEGIN RETURN list.Length() = 0; END Empty;

		PROCEDURE Length*():LONGINT;
		BEGIN RETURN list.count; END Length;

	END Stack;

	(* Data structure implementing a stack using lists *)
	IntegerStack* = OBJECT
	VAR
		list: IntegerList;

		PROCEDURE & Init*;
		BEGIN NEW(list,InitListSize); END Init;

		(* Push on top of stack *)
		PROCEDURE Push*(x: LONGINT);
		BEGIN list.Add(x); END Push;

		(* Get top element *)
		PROCEDURE Peek*():LONGINT;
		BEGIN RETURN list.Get(list.Length() - 1); END Peek;

		(* Get and remove top element *)
		PROCEDURE Pop*():LONGINT;
		VAR old: LONGINT;
		BEGIN
			old := Peek();
			RemoveTop();
			RETURN old;
		END Pop;

		(* Remove top element without reading it *)
		PROCEDURE RemoveTop*;
		BEGIN list.RemoveByIndex(list.Length() - 1); END RemoveTop;

		(* Check if empty *)
		PROCEDURE Empty*():BOOLEAN;
		BEGIN RETURN list.Length() = 0; END Empty;

		PROCEDURE Length*():LONGINT;
		BEGIN RETURN list.count; END Length;

	END IntegerStack;

	QueueEntry = POINTER TO RECORD
		value: ANY;
		next: QueueEntry;
	END;

	Queue* = OBJECT
	VAR
		top, last: QueueEntry;

		PROCEDURE & Init *;
		BEGIN
			top := NIL; last := NIL;
		END Init;

		(* Add to end of queue *)
		PROCEDURE Append*(x: ANY);
		VAR entry: QueueEntry;
		BEGIN
			NEW(entry);
			entry.value := x;

			IF top = NIL THEN
				top := entry;
			ELSE
				last.next := entry;
			END;

			last := entry;
		END Append;

		(* Get top element *)
		PROCEDURE Peek*():ANY;
		BEGIN
			RETURN top.value;
		END Peek;

		(* Get and remove top element *)
		PROCEDURE Pop*():ANY;
		VAR old: QueueEntry;
		BEGIN
			ASSERT(~Empty());
			old := top;
			top := top.next;
			RETURN old.value;
		END Pop;

		(* Check if empty *)
		PROCEDURE Empty*():BOOLEAN;
		BEGIN
			RETURN top = NIL;
		END Empty;

	END Queue;

	PQItem = RECORD
		key: LONGINT;
		value: ANY;
	END;

	PQItemList = POINTER TO ARRAY OF PQItem;

	(* Priority queue using binary heap *)
	PriorityQueue* = OBJECT
	VAR
		heap: PQItemList;
		count-: LONGINT;

		(** Interface **)

		PROCEDURE & Init(size: LONGINT);
		BEGIN
			NEW(heap, size + 1);
			count := 0;
		END Init;

		PROCEDURE Min*():ANY; (* O(n) *)
		BEGIN
			ASSERT(count > 0);
			RETURN heap[1].value;
		END Min;

		PROCEDURE RemoveMin*():ANY; (* O(log n) *)
		VAR min: ANY;
		BEGIN
			min := Min();
			heap[1] := heap[count];
			DEC(count);
			IF count > 0 THEN BubbleDown(1); END;
			RETURN min;
		END RemoveMin;

		PROCEDURE Insert*(key: LONGINT; value: ANY); (* O(log n) *)
		VAR index: LONGINT;
		BEGIN
			INC(count);
			index := count;
			heap[index].key := key;
			heap[index].value := value;
			BubbleUp(index);
		END Insert;

		PROCEDURE Empty*():BOOLEAN;
		BEGIN
			RETURN count = 0;
		END Empty;

		(** Implementation **)

		PROCEDURE BubbleUp(VAR index: LONGINT);
		VAR swap: PQItem;
		BEGIN
			WHILE (index > 1) & (heap[index].key < heap[index DIV 2].key) DO
				swap := heap[index DIV 2];
				heap[index DIV 2] := heap[index];
				heap[index] := swap;
				index := index DIV 2;
			END;
		END BubbleUp;

		PROCEDURE BubbleDown(index: LONGINT);
		VAR min, minkey: LONGINT; swap: PQItem;

			PROCEDURE Child(child: LONGINT);
			BEGIN
				IF (child <= count) & (heap[child].key < minkey) THEN
					min := child;
					minkey := heap[child].key;
				END;
			END Child;
		BEGIN
			REPEAT
				min := 0;
				minkey := heap[index].key;
				Child(index * 2);
				Child((index * 2) + 1);
				IF min # 0 THEN
					swap := heap[min];
					heap[min] := heap[index];
					heap[index] := swap;
					index := min;
				END;
			UNTIL
				min = 0;
		END BubbleDown;

	END PriorityQueue;

	IndexList = POINTER TO ARRAY OF LONGINT;

	Edge* = OBJECT
	VAR
		from-, to-: Block;

		PROCEDURE Accept(v: GraphVisitor);
		BEGIN v.VisitEdge(SELF); END Accept;

	END Edge;

	Graph* = OBJECT
	VAR
		firstBlock*, lastBlock-: Block;
		blocks*: BlockList;
		edges-: EdgeList;
		edgesLookup: HashTable2D;

		PROCEDURE & Init *;
		BEGIN
			NEW(blocks,InitListSize);
			NEW(edges,InitListSize);
			NEW(edgesLookup, 1024);
		END Init;

		PROCEDURE AddBlock*(block: Block);
		BEGIN
			IF blocks.Length() = 0 THEN firstBlock := block; END;
			block.index := blocks.Length();
			blocks.Add(block);
			lastBlock := block;
		END AddBlock;

		PROCEDURE Connect*(from, to: Block);
		VAR edge: Edge;
		BEGIN
			IF edgesLookup.Has2D(from, to) THEN RETURN; END;
			from.successors.Add(to);
			to.predecessors.Add(from);

			NEW(edge);
			edge.from := from;
			edge.to := to;
			edges.Add(edge);
			edgesLookup.Put2D(from, to, edge);
		END Connect;

		PROCEDURE Split*(from, to: Block);
		BEGIN
			from.successors.Remove(to);
			to.predecessors.Remove(from);

			edges.Remove(edgesLookup.Get2D(from, to));
		END Split;

		(* Reorder blocks so that they form a reverse post order *)
		PROCEDURE ReIndex*;
		VAR b: Block; i: LONGINT; done: POINTER TO ARRAY OF BOOLEAN; new: BlockList;

			PROCEDURE Work(b: Block);
			VAR i: LONGINT; p: Block;
			BEGIN
				done[b.index] := TRUE;

				FOR i := 0 TO b.successors.Length() - 1 DO
					p := b.successors.GetBlock(i);
					IF ~done[p.index] THEN
						Work(p);
					END;
				END;

				new.Add(b);
			END Work;
		BEGIN
			NEW(new,InitListSize);
			NEW(done, blocks.Length());
			i := 0;

			Work(blocks.GetBlock(0));

			NEW(blocks,InitListSize);
			FOR i := new.Length() - 1 TO 0 BY -1 DO
				b := new.GetBlock(i);
				b.index := blocks.Length();
				blocks.Add(b);
			END;
		END ReIndex;

		(* Calculate dominance tree. Algorithm taken from:
		    "A simple, fast dominance algorithm" (Cooper, Harvey, Kennedy) *)
		PROCEDURE CalculateDominance*;
		VAR
			doms: IndexList;
			i, j, len, runner, newIdom: LONGINT;
			changed: BOOLEAN;
			block, pred: Block;

			PROCEDURE Intersect(b1, b2: LONGINT):LONGINT;
			BEGIN
				WHILE(b1 # b2) DO
					WHILE(b1 > b2) DO
						IF b1 = doms[b1] THEN HALT(100); END;
						b1 := doms[b1];
					END;
					WHILE(b2 > b1) DO
						IF b2 = doms[b2] THEN HALT(100); END;
						b2 := doms[b2];
					END;
				END;

				RETURN b1;
			END Intersect;

		BEGIN
			(* Initialize the arrays *)
			len := blocks.Length();

			NEW(doms, len);
			FOR i := 0 TO len - 1 DO
				doms[i] := -1;
			END;
			doms[0] := 0;

			(* Iteration loop *)
			changed := TRUE;
			WHILE(changed) DO
				changed := FALSE;

				FOR i := 1 TO len - 1 DO
					block := blocks.GetBlock(i);
					pred := block.predecessors.GetBlock(0);
					newIdom := pred.index;
					FOR j := 1 TO block.predecessors.Length() - 1 DO
						pred := block.predecessors.GetBlock(j);
						IF doms[pred.index] # -1 THEN
							newIdom := Intersect(pred.index, newIdom);
						END;
					END;
					IF doms[i] # newIdom THEN
						doms[i] := newIdom;
						changed := TRUE;
					END;
				END;
			END;

			FOR i := 0 TO len - 1 DO
				block := blocks.GetBlock(i);

				(* Set immediate dominators *)
				block.immediateDominator := doms[i];

				(* Calculate frontier *)
				IF block.predecessors.Length() >= 2 THEN
					FOR j := 0 TO block.predecessors.Length() - 1 DO
						pred := block.predecessors.GetBlock(j);
						runner := pred.index;
						WHILE runner # doms[block.index] DO
							pred := blocks.GetBlock(runner);
							IF ~pred.dominanceFrontier.Contains(block) THEN
								pred.dominanceFrontier.Add(block);
							END;
							runner := doms[runner];
						END;
					END;
				END;
			END;
		END CalculateDominance;

	END Graph;

	BlockList* = OBJECT(List)
	VAR
		PROCEDURE GetBlock*(i: LONGINT):Block;
		VAR block: ANY;
		BEGIN
			block := Get(i);
			RETURN block(Block);
		END GetBlock;

		PROCEDURE GetIndex*(i: LONGINT):LONGINT;
		VAR block: Block;
		BEGIN
			block := GetBlock(i);
			RETURN block.index;
		END GetIndex;

	END BlockList;

	EdgeList* = OBJECT(List)
	VAR
		PROCEDURE GetEdge*(i: LONGINT):Edge;
		VAR
			edge: ANY;
		BEGIN
			edge := Get(i);
			RETURN edge(Edge);
		END GetEdge;
	END EdgeList;

	Block* = OBJECT
	VAR
		predecessors-, successors-, dominanceFrontier-: BlockList;
		index*, immediateDominator*: LONGINT;

		PROCEDURE & Init*;
		BEGIN
			NEW(predecessors,InitListSize);
			NEW(successors,InitListSize);
			NEW(dominanceFrontier,InitListSize);
		END Init;

		PROCEDURE Accept(v: GraphVisitor);
		BEGIN v.VisitBlock(SELF); END Accept;

		PROCEDURE PredecessorIndex*(block: Block):LONGINT;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO predecessors.Length() - 1 DO
				IF predecessors.Get(i) = block THEN
					RETURN i;
				END;
			END;
			HALT(100);
		END PredecessorIndex;
	END Block;

	ContentFunction = PROCEDURE {DELEGATE} (block: Block);

	GraphVisitor* = OBJECT
	VAR
		block-: Block;
		edge-: Edge;
		graph-: Graph;

		PROCEDURE VisitEdge*(edge: Edge);
		BEGIN END VisitEdge;

		PROCEDURE VisitBlock*(block: Block);
		BEGIN END VisitBlock;

		PROCEDURE VisitGraph*(graph: Graph);
		VAR i: LONGINT;
		BEGIN
			SELF.graph := graph;
			FOR i := 0 TO graph.blocks.Length() - 1 DO
				block := graph.blocks.GetBlock(i);
				block.Accept(SELF);
			END;

			FOR i := 0 TO graph.edges.Length() - 1 DO
				edge := graph.edges.GetEdge(i);
				edge.Accept(SELF);
			END;
		END VisitGraph;

	END GraphVisitor;

	(** Outputs a .dot file which can be parsed into a graph by GraphViz *)
	GraphPrinter* = OBJECT(GraphVisitor)
	VAR
		active-: Block;
		writer-: Streams.Writer;
		content: ContentFunction;

		PROCEDURE VisitEdge*(edge: Edge);
		BEGIN
			writer.String("block"); writer.Int(edge.from.index, 0);
			writer.String("->");
			writer.String("block"); writer.Int(edge.to.index, 0);
			writer.String(";"); writer.Ln;
		END VisitEdge;

		PROCEDURE VisitBlock(block: Block);
		VAR
			i: LONGINT;
			dom: Block;
		BEGIN
			writer.String("block");
			writer.Int(block.index, 0);

			writer.String(' [ label=<<table border="0" cellpadding="1" cellspacing="1"><tr><td>#');
			writer.Int(block.index, 0);
			writer.String("</td><td>idom=");
			writer.Int(block.immediateDominator, 0);
			writer.String("</td><td>df=");
			FOR i := 0 TO block.dominanceFrontier.Length() - 1 DO
				dom := block.dominanceFrontier.GetBlock(i);
				writer.Int(dom.index, 0);
				writer.String(" ");
			END;
			writer.String("</td></tr>");

			content(block);

			writer.String('</table>>]; ');
			writer.Ln;
		END VisitBlock;

		PROCEDURE VisitGraph*(graph: Graph);
		BEGIN
			SELF.graph := graph;

			(* Print header of dot file *)
			writer.String("digraph G {"); writer.Ln;

			(* Print all blocks *)
			writer.String("node [shape=box]; ");
			VisitGraph^(graph);

			(* Footer *)
			writer.Ln;
			writer.String("overlap=false;"); writer.Ln;
			writer.String('label=" Created with OC";'); writer.Ln;
			writer.String("fontsize=12;"); writer.Ln;
			writer.String("}");
		END VisitGraph;

		PROCEDURE SetWriter*(w: Streams.Writer);
		BEGIN
			writer := w;
		END SetWriter;

		PROCEDURE & Init*(c: ContentFunction);
		BEGIN
			content := c;
		END Init;

	END GraphPrinter;

	IntegerObject = OBJECT
	END IntegerObject;

	Writer* = OBJECT (Streams.Writer)
	VAR
		indent-: LONGINT;
		doindent: BOOLEAN;
		w-: Streams.Writer;

		PROCEDURE InitBasicWriter*( w: Streams.Writer );
		BEGIN
			SELF.w := w; indent := 0; doindent := TRUE;
		END InitBasicWriter;

		PROCEDURE & InitW(w: Streams.Writer); (* protect against use of NEW *)
		BEGIN InitBasicWriter(w);
		END InitW;

		PROCEDURE Reset*;
		BEGIN w.Reset;
		END Reset;

		PROCEDURE CanSetPos*( ): BOOLEAN;
		BEGIN RETURN w.CanSetPos();
		END CanSetPos;

		PROCEDURE SetPos*( pos: LONGINT );
		BEGIN w.SetPos(pos);
		END SetPos;

		PROCEDURE Update*;
		BEGIN w.Update;
		END Update;

		PROCEDURE Pos*( ): LONGINT;
		BEGIN RETURN w.Pos()
		END Pos;

		PROCEDURE Indent;
		VAR i: LONGINT;
		BEGIN
			IF doindent THEN
				FOR i := 0 TO indent-1 DO
					w.Char(9X);
				END;
				doindent := FALSE
			END;
		END Indent;

		PROCEDURE Char*( x: CHAR );
		BEGIN Indent; w.Char(x);
		END Char;

		PROCEDURE Bytes*(CONST x: ARRAY OF CHAR;  ofs, len: LONGINT );
		BEGIN  w.Bytes(x,ofs,len);
		END Bytes;

		PROCEDURE RawSInt*( x: SHORTINT );
		BEGIN  w.RawSInt(x)
		END RawSInt;

		PROCEDURE RawInt*( x: INTEGER );
		BEGIN  w.RawInt(x)
		END RawInt;

		PROCEDURE RawLInt*( x: LONGINT );
		BEGIN  w.RawLInt(x)
		END RawLInt;

		PROCEDURE RawHInt*( x: HUGEINT );
		BEGIN  w.RawHInt(x)
		END RawHInt;

		PROCEDURE Net32*( x: LONGINT );
		BEGIN  w.Net32(x)
		END Net32;

		PROCEDURE Net16*( x: LONGINT );
		BEGIN  w.Net16(x)
		END Net16;

		PROCEDURE Net8*( x: LONGINT );
		BEGIN  w.Net8(x)
		END Net8;

		PROCEDURE RawSet*( x: SET );
		BEGIN  w.RawSet(x)
		END RawSet;

		PROCEDURE RawBool*( x: BOOLEAN );
		BEGIN  w.RawBool(x)
		END RawBool;

		PROCEDURE RawReal*( x: REAL );
		BEGIN  w.RawReal(x)
		END RawReal;

		PROCEDURE RawLReal*( x: LONGREAL );
		BEGIN  w.RawLReal(x)
		END RawLReal;

		PROCEDURE RawString*(CONST x: ARRAY OF CHAR );
		BEGIN  w.RawString(x)
		END RawString;

		PROCEDURE RawNum*( x: LONGINT );
		BEGIN  w.RawNum(x)
		END RawNum;

		PROCEDURE Ln*;
		BEGIN w.Ln; doindent := TRUE;
		END Ln;

		PROCEDURE String*(CONST x: ARRAY OF CHAR );
		BEGIN Indent; w.String(x)
		END String;

		PROCEDURE Int*( x: HUGEINT; wd: LONGINT );
		BEGIN Indent; w.Int(x,wd)
		END Int;

		PROCEDURE Set*( s: SET );   (* from P. Saladin *)
		BEGIN Indent; w.Set(s)
		END Set;

		PROCEDURE Hex*(x: HUGEINT; wd: LONGINT );
		BEGIN Indent; w.Hex(x,wd)
		END Hex;

		PROCEDURE Address* (x: ADDRESS);
		BEGIN Indent; w.Address(x)
		END Address;

		PROCEDURE Date*( t, d: LONGINT );
		BEGIN Indent; w.Date(t,d)
		END Date;

		PROCEDURE Date822*( t, d, tz: LONGINT );
		BEGIN Indent; w.Date822(t,d,tz)
		END Date822;

		PROCEDURE Float*( x: LONGREAL;  n: LONGINT );
		BEGIN Indent; w.Float(x,n)
		END Float;

		PROCEDURE FloatFix*( x: LONGREAL;  n, f, D: LONGINT );
		BEGIN Indent; w.FloatFix(x,n,f,D)
		END FloatFix;

		PROCEDURE SetIndent*(i: LONGINT);
		BEGIN
			indent := i
		END SetIndent;

		PROCEDURE IncIndent*;
		BEGIN INC(indent)
		END IncIndent;

		PROCEDURE DecIndent*;
		BEGIN DEC(indent)
		END DecIndent;

		PROCEDURE BeginAlert*;
		END BeginAlert;

		PROCEDURE EndAlert*;
		END EndAlert;

		PROCEDURE BeginKeyword*;
		BEGIN
		END BeginKeyword;

		PROCEDURE EndKeyword*;
		BEGIN
		END EndKeyword;

		PROCEDURE BeginComment*;
		END BeginComment;

		PROCEDURE EndComment*;
		END EndComment;

		PROCEDURE AlertString*(CONST s: ARRAY OF CHAR);
		BEGIN
			BeginAlert; w.String(s); EndAlert;
		END AlertString;

	END Writer;

	CRC32Stream* = OBJECT(Streams.Writer) (* from CRC.Mod *)
	VAR
		crc : LONGINT;

		PROCEDURE  &InitStream*;
		BEGIN
			crc := LONGINT(0FFFFFFFFH);
			InitWriter(Send, 256)
		END InitStream;

		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
		VAR idx: LONGINT;
		BEGIN
			WHILE len > 0 DO
				idx := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, crc) / SYSTEM.VAL(SET, LONG(ORD(buf[ofs])))) MOD 100H;
				crc := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, CRC32Table[idx])/SYSTEM.VAL(SET, LSH(crc, -8)));
				DEC(len); INC(ofs)
			END;
			res := Streams.Ok
		END Send;

		PROCEDURE GetCRC*():LONGINT;
		BEGIN
			Update();
			RETURN SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, crc)/{0..31})
		END GetCRC;

	END CRC32Stream;

	TracingDiagnostics=OBJECT (Diagnostics.Diagnostics)
	VAR diagnostics: Diagnostics.Diagnostics;

		PROCEDURE &InitDiagnostics(diagnostics: Diagnostics.Diagnostics);
		BEGIN
			SELF.diagnostics := diagnostics
		END InitDiagnostics;

		PROCEDURE Error(CONST source: ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				diagnostics.Error(source,position,errorCode,message);
			END;
			D.Ln;
			D.String(" ---------------------- TRACE for COMPILER ERROR  < ");
			D.String(source);
			IF position # Diagnostics.Invalid THEN D.String("@"); D.Int(position,1) END;
			IF errorCode # Diagnostics.Invalid THEN D.String(" "); D.Int(errorCode,1); END;
			D.String(" "); D.String(message);
			D.String(" > ---------------------- ");
			D.TraceBack
		END Error;

		PROCEDURE Warning*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				diagnostics.Warning(source,position,errorCode,message);
			END;
		END Warning;

		PROCEDURE Information*(CONST source : ARRAY OF CHAR; position, errorCode : LONGINT; CONST message : ARRAY OF CHAR);
		BEGIN
			IF diagnostics # NIL THEN
				diagnostics.Information(source,position,errorCode,message);
			END;
		END Information;

	END TracingDiagnostics;

	DebugWriterFactory*= PROCEDURE{DELEGATE} (CONST title: ARRAY OF CHAR): Streams.Writer;
	WriterFactory*=PROCEDURE{DELEGATE} (w: Streams.Writer): Writer;
	DiagnosticsFactory*=PROCEDURE{DELEGATE} (w: Streams.Writer): Diagnostics.Diagnostics;

VAR
	lists-: LONGINT;  enlarged-: LONGINT;  strings-: LONGINT; integerObjects: HashTableInt;
	errMsg: ErrorMsgs;	(*error messages*)
	emptyString-: String;
	debug: BOOLEAN;
	getDebugWriter: DebugWriterFactory;
	getWriter: WriterFactory;
	getDiagnostics: DiagnosticsFactory;
	CRC32Table: ARRAY 256 OF SET;

	(* Make a string out of a series of characters. *)
	PROCEDURE MakeString*( CONST s: ARRAY OF CHAR ): String;
	(* VAR str: String;  *)
	BEGIN
		INC( strings );
		(*
		(* allocation based *)
		NEW( str, Strings.Length( s ) +1);  COPY( s, str^ );  RETURN str;
		*)
		RETURN StringPool.GetIndex1( s )
	END MakeString;

	PROCEDURE GetString*(s: String; VAR str: ARRAY OF CHAR);
	BEGIN
		StringPool.GetString(s,str);
	END GetString;

	PROCEDURE StringEqual*( s, t: String ): BOOLEAN;
	BEGIN
		RETURN s = t;
		(*
		(* allocation based *)
		RETURN s^ = t^
		*)
	END StringEqual;

	PROCEDURE GetErrorMessage*(err: LONGINT; CONST msg: ARRAY OF CHAR; VAR res: ARRAY OF CHAR);
	VAR str: ARRAY 128 OF CHAR;
	BEGIN
		res := "";
		IF (errMsg # NIL) & (0 <= err) & (err < LEN(errMsg)) THEN
			StringPool.GetString(errMsg[err], str);
			Strings.Append(res,str);
			Strings.Append(res, " ");
		END;
		Strings.Append(res, msg);
	END GetErrorMessage;

	(** SetErrorMsg - Set message for error n *)

	PROCEDURE SetErrorMessage*(n: LONGINT; CONST  msg: ARRAY OF CHAR);
	BEGIN
		IF errMsg = NIL THEN NEW(errMsg, InitErrMsgSize) END;
		WHILE LEN(errMsg^) < n DO Expand(errMsg) END;
		StringPool.GetIndex(msg, errMsg[n])
	END SetErrorMessage;

	PROCEDURE SetErrorExpected*(n: LONGINT; CONST msg: ARRAY OF CHAR);
	VAR err: ARRAY 256 OF CHAR;
	BEGIN
		err := "missing '";
		Strings.Append(err,msg);
		Strings.Append(err, "'");
		SetErrorMessage(n,err);
	END SetErrorExpected;

	PROCEDURE AppendNumber*(VAR s: ARRAY OF CHAR; num: LONGINT);
	VAR nums: ARRAY 32 OF CHAR;
	BEGIN
		Strings.IntToStr(num,nums);
		Strings.Append(s,nums);
	END AppendNumber;

	PROCEDURE InitSegmentedName*(VAR name: SegmentedName);
	VAR i: LONGINT;
	BEGIN FOR i := 0 TO LEN(name)-1 DO name[i] := -1 END;
	END InitSegmentedName;

	PROCEDURE ToSegmentedName*(CONST name: ARRAY OF CHAR; VAR pooledName: SegmentedName);
	BEGIN
		ObjectFile.StringToSegmentedName(name,pooledName);
	END ToSegmentedName;

	PROCEDURE SegmentedNameToString*(CONST pooledName: SegmentedName; VAR name: ARRAY OF CHAR);
	BEGIN
		ObjectFile.SegmentedNameToString(pooledName, name);
	END SegmentedNameToString;

	PROCEDURE WriteSegmentedName*(w: Streams.Writer; name: SegmentedName);
	VAR sectionName: ObjectFile.SectionName;
	BEGIN
		SegmentedNameToString(name, sectionName);
		w.String(sectionName);
	END WriteSegmentedName;

	PROCEDURE AppendToSegmentedName*(VAR name: SegmentedName; CONST this: ARRAY OF CHAR);
	VAR i,j: LONGINT; string: ObjectFile.SectionName;
	BEGIN
		i := 0;
		WHILE (i<LEN(name)) & (name[i] >= 0)  DO
			INC(i)
		END;
		IF (this[0] = ".") & (i < LEN(name)) THEN (* suffix *)
			j := 0;
			WHILE this[j+1] # 0X DO
				string[j] := this[j+1];
				INC(j);
			END;
			string[j] := 0X;
			name[i] := StringPool.GetIndex1(string);
			IF i<LEN(name)-1 THEN name[i+1] := -1 END;
		ELSE
			StringPool.GetString(name[i-1], string);
			Strings.Append(string, this);
			name[i-1] := StringPool.GetIndex1(string);
		END;
	END AppendToSegmentedName;

	(* suffix using separation character "." *)
	PROCEDURE SuffixSegmentedName*(VAR name: SegmentedName; this: StringPool.Index);
	VAR string, suffix: ObjectFile.SectionName; i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < LEN(name)) & (name[i] >= 0) DO
			INC(i);
		END;
		IF i < LEN(name) THEN (* suffix *)
			name[i] := this;
			IF i<LEN(name)-1 THEN name[i+1] := -1 END;
		ELSE
			StringPool.GetString(name[i-1], string);
			StringPool.GetString(this, suffix);
			Strings.Append(string,".");
			Strings.Append(string, suffix);
			name[i-1] := StringPool.GetIndex1(string);
		END;
	END SuffixSegmentedName;

	PROCEDURE SegmentedNameEndsWith*(CONST name: SegmentedName; CONST this: ARRAY OF CHAR): BOOLEAN;
	VAR string: ObjectFile.SectionName; i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i< LEN(name)) & (name[i] >= 0) DO
			INC(i);
		END;
		DEC(i);
		IF i < 0 THEN
			RETURN FALSE
		ELSE
			StringPool.GetString(name[i],string);
			RETURN Strings.EndsWith(this, string);
		END
	END SegmentedNameEndsWith;

	PROCEDURE RemoveSuffix*(VAR name: SegmentedName);
	VAR i,pos,pos0: LONGINT;string: ObjectFile.SectionName;
	BEGIN
		i := 0;
		WHILE  (i< LEN(name)) & (name[i] >= 0) DO
			INC(i);
		END;
		ASSERT(i>0);
		IF i < LEN(name) THEN (* name[i] = empty *) name[i-1] := -1
		ELSE (* i = LEN(name), name[i] = nonempty *)
			DEC(i);
			StringPool.GetString(name[i],string);
		pos0 := 0; pos := 0;
		WHILE (pos0 < LEN(string)) & (string[pos0] # 0X) DO
			IF string[pos0] = "." THEN pos := pos0 END;
			INC(pos0);
		END;
		IF pos = 0 THEN (* no dot in name or name starts with dot *)
				name[i] := -1
		ELSE (* remove last part in name *)
			string[pos] := 0X;
				name[i] := StringPool.GetIndex1(string);
		END;
		END;
	END RemoveSuffix;
	
	PROCEDURE GetSuffix*(CONST name: SegmentedName; VAR string: ARRAY OF CHAR);
	VAR i,pos,pos0: LONGINT;
	BEGIN
		i := 0;
		WHILE  (i< LEN(name)) & (name[i] >= 0) DO
			INC(i);
		END;
		ASSERT(i>0);
		StringPool.GetString(name[i-1],string);
		IF i = LEN(name) THEN
			pos0 := 0; pos := 0;
			WHILE (pos0 < LEN(string)) & (string[pos0] # 0X) DO
				IF string[pos0] = "." THEN pos := pos0 END;
				INC(pos0);
			END;
			IF pos # 0 THEN (* no dot in name or name starts with dot *)
				pos0 := 0;
				REPEAT 
					INC(pos); (* start with character after "." *)
					string[pos0] := string[pos];
					INC(pos0);
				UNTIL string[pos]  = 0X;
			END;
		END;
	END GetSuffix;


	PROCEDURE IsPrefix*(CONST prefix, of: SegmentedName): BOOLEAN;
	VAR prefixS, ofS: SectionName; i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i< LEN(prefix)) & (prefix[i] = of[i]) DO INC(i) END;

		IF i = LEN(prefix) THEN RETURN TRUE (* identical *)
		ELSE (* prefix[i] # of[i] *)
			IF prefix[i] < 0 THEN RETURN TRUE
			ELSIF of[i] < 0 THEN RETURN FALSE
			ELSIF (i<LEN(prefix)-1) THEN RETURN FALSE
			ELSE
				StringPool.GetString(prefix[i], prefixS);
				StringPool.GetString(of[i], ofS);
			RETURN Strings.StartsWith(prefixS, 0, ofS)
			END
		END;
	END IsPrefix;

	PROCEDURE Expand(VAR oldAry: ErrorMsgs);
	VAR
		len, i: LONGINT;
		newAry: ErrorMsgs;
	BEGIN
		IF oldAry = NIL THEN RETURN END;
		len := LEN(oldAry^);
		NEW(newAry, len * 2);
		FOR i := 0 TO len-1 DO
			newAry[i] := oldAry[i];
		END;
		oldAry := newAry;
	END Expand;

	PROCEDURE Concat*(VAR result: ARRAY OF CHAR; CONST prefix, name, suffix: ARRAY OF CHAR);
	VAR i, j: LONGINT;
	BEGIN
		i := 0; WHILE prefix[i] # 0X DO  result[i] := prefix[i];  INC(i)  END;
		j := 0; WHILE name[j] # 0X DO  result[i+j] := name[j];  INC(j)  END;
		INC(i, j);
		j := 0; WHILE suffix[j] # 0X DO result[i+j] := suffix[j]; INC(j)  END;
		result[i+j] := 0X;
	END Concat;

	PROCEDURE Lowercase*(CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
	VAR ch: CHAR; i: LONGINT;
	BEGIN
		i := 0;
		REPEAT
			ch := name[i];
			IF (ch >= 'A') & (ch <= 'Z') THEN
				ch := CHR(ORD(ch)-ORD('A')+ORD('a'));
			END;
			result[i] := ch; INC(i);
		UNTIL ch = 0X;
	END Lowercase;

	PROCEDURE Uppercase*(CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
	VAR ch: CHAR; i: LONGINT;
	BEGIN
		i := 0;
		REPEAT
			ch := name[i];
			IF (ch >= 'a') & (ch <= 'z') THEN
				ch := CHR(ORD(ch)-ORD('a')+ORD('A'));
			END;
			result[i] := ch; INC(i);
		UNTIL ch = 0X;
	END Uppercase;

	PROCEDURE GetIntegerObj*(value: LONGINT):ANY;
	VAR obj: IntegerObject;
	BEGIN
		IF integerObjects.Has(value) THEN
			RETURN integerObjects.Get(value);
		END;
		NEW(obj);
		integerObjects.Put(value, obj);
		RETURN obj;
	END GetIntegerObj;

	PROCEDURE Align*(VAR offset: LONGINT; alignment: LONGINT);
	BEGIN
		IF alignment >0  THEN
			INC(offset,(-offset) MOD alignment);
		ELSIF alignment < 0 THEN
			DEC(offset,offset MOD (-alignment));
		END;
	END Align;

	PROCEDURE InitErrorMessages;
	BEGIN
		SetErrorMessage(UndeclaredIdentifier, "undeclared identifier");
		SetErrorMessage(MultiplyDefinedIdentifier, "multiply defined identifier");
		SetErrorMessage(NumberIllegalCharacter, "illegal character in number");
		SetErrorMessage(StringIllegalCharacter, "illegal character in string");
		SetErrorMessage(NoMatchProcedureName, "procedure name does not match");
		SetErrorMessage(CommentNotClosed, "comment not closed");
		SetErrorMessage(IllegalCharacterValue, "illegal character value");
		SetErrorMessage(ValueStartIncorrectSymbol, "value starts with incorrect symbol");
		SetErrorMessage(IllegalyMarkedIdentifier, "illegaly marked identifier");
		SetErrorMessage(IdentifierNoType, "identifier is not a type");
		SetErrorMessage(IdentifierNoRecordType, "identifier is not a record type");
		SetErrorMessage(IdentifierNoObjectType, "identifier is not an object type");
		SetErrorMessage(ImportNotAvailable, "import is not available");
		SetErrorMessage(RecursiveTypeDeclaration, "recursive type declaration");
		SetErrorMessage(NumberTooLarge, "number too large");
		SetErrorMessage(IdentifierTooLong, "identifier too long");
		SetErrorMessage(StringTooLong, "string too long");
	END InitErrorMessages;

	PROCEDURE ActivateDebug*;
	BEGIN
		debug := TRUE;
	END ActivateDebug;

	PROCEDURE Test*;
	VAR table: HashTableInt; dump: LONGINT;
	BEGIN
		NEW(table, 32);
		table.PutInt(32, -4);
		dump := table.GetInt(32);
		HALT(100);
	END Test;

	PROCEDURE GetFileReader*(CONST filename: ARRAY OF CHAR): Streams.Reader;
	VAR
		file: Files.File; fileReader: Files.Reader; offset: LONGINT;
	BEGIN
		(* Optimisation: skip header of oberon files and return a file reader instead of default text reader*)
		file := Files.Old (filename);
		IF file = NIL THEN RETURN NIL END;
		NEW (fileReader, file, 0);
		IF (fileReader.Get () = 0F0X) & (fileReader.Get () = 001X) THEN
			offset := ORD (fileReader.Get ());
			INC (offset, LONG (ORD (fileReader.Get ())) * 0100H);
			fileReader.SetPos(offset);
		ELSE fileReader.SetPos(0)
		END;
		RETURN fileReader
	END GetFileReader;

	PROCEDURE GetWriter*(w: Streams.Writer): Writer;
	VAR writer: Writer;
	BEGIN
		ASSERT(w # NIL);
		IF w IS Writer THEN RETURN w(Writer)
		ELSIF getWriter = NIL THEN
			NEW(writer,w); RETURN writer
		ELSE RETURN getWriter(w)
		END;
	END GetWriter;

	PROCEDURE GetDebugWriter*(CONST title: ARRAY OF CHAR): Streams.Writer;
	VAR w: Streams.Writer;
	BEGIN
		IF getDebugWriter # NIL THEN  w:= getDebugWriter(title)
		ELSE NEW(w, KernelLog.Send,1024)
		END;
		RETURN w;
	END GetDebugWriter;

	PROCEDURE GetDiagnostics*(w: Streams.Writer): Diagnostics.Diagnostics;
	VAR diagnostics: Diagnostics.StreamDiagnostics;
	BEGIN
		IF getDiagnostics # NIL THEN RETURN getDiagnostics(w)
		ELSE NEW(diagnostics,w); RETURN diagnostics
		END;
	END GetDiagnostics;
	
	PROCEDURE GetDefaultDiagnostics*(): Diagnostics.Diagnostics;
	VAR w: Streams.Writer;
	BEGIN
		NEW(w, KernelLog.Send,128);
		RETURN GetDiagnostics(w);
	END GetDefaultDiagnostics;
	

	PROCEDURE InitWindowWriter;
	VAR install: PROCEDURE;
	BEGIN
		getDebugWriter := NIL; getWriter := NIL;
		GETPROCEDURE("FoxA2Interface","Install",install);
		IF install # NIL THEN install END;
	END InitWindowWriter;

	PROCEDURE InstallWriterFactory*(writer: WriterFactory; debug: DebugWriterFactory; diagnostics: DiagnosticsFactory);
	BEGIN
		 getWriter := writer;
		 getDebugWriter := debug;
		 getDiagnostics := diagnostics;
	END InstallWriterFactory;

	PROCEDURE Replace(VAR in: ARRAY OF CHAR; CONST this, by: ARRAY OF CHAR);
	VAR pos: LONGINT;
	BEGIN
		pos := Strings.Pos(this,in);
		IF pos >= 0 THEN
			Strings.Delete(in,pos,Strings.Length(this));
			Strings.Insert(by, in, pos);
		END;
	END Replace;

	PROCEDURE MessageS*(CONST format, s0: ARRAY OF CHAR): MessageString;
	VAR message: MessageString;
	BEGIN
		COPY(format, message);
		Replace(message,"%0",s0);
		RETURN message
	END MessageS;

	PROCEDURE MessageSS*(CONST format, s0, s1: ARRAY OF CHAR): MessageString;
	VAR message: MessageString;
	BEGIN
		COPY(format, message);
		Replace(message,"%0",s0);
		Replace(message,"%1",s1);
		RETURN message
	END MessageSS;

	PROCEDURE MessageI*(CONST format: ARRAY OF CHAR; i0: LONGINT): MessageString;
	VAR message: MessageString; number: ARRAY 32 OF CHAR;
	BEGIN
		COPY(format, message);
		Strings.IntToStr(i0,number);
		Replace(message,"%0",number);
	END MessageI;

	PROCEDURE MessageSI*(CONST format: ARRAY OF CHAR; CONST s0: ARRAY OF CHAR; i1: LONGINT): MessageString;
	VAR message: MessageString; number: ARRAY 32 OF CHAR;
	BEGIN
		COPY(format, message);
		Replace(message,"%0",s0);
		Strings.IntToStr(i1,number);
		Replace(message,"%1",number);
	END MessageSI;

		(*
		Get next available name from stream ignoring comments and end of comment brackets
		Returns TRUE on success, returns FALSE on end of stream, on error or if "~" or ";" encountered.
		Scanner based on Peek() feature of stream. Necessary to make it restartable.
	*)
	PROCEDURE GetStringParameter*(r: Streams.Reader; VAR string: ARRAY OF CHAR): BOOLEAN;
	VAR ch: CHAR; i: LONGINT; done,error: BOOLEAN;

		PROCEDURE Next;
		BEGIN r.Char(ch); ch := r.Peek();
		END Next;

		PROCEDURE Append(ch: CHAR);
		BEGIN string[i] := ch; INC(i)
		END Append;

		PROCEDURE SkipWhitespace;
		BEGIN WHILE (ch <= " ") & (ch # 0X) DO Next END;
		END SkipWhitespace;

		PROCEDURE Comment;
		VAR done: BOOLEAN;
		BEGIN
			done := FALSE;
			Next;
			REPEAT
				CASE ch OF
				|"(": Next; IF ch = "*" THEN Comment; SkipWhitespace END;
				|"*": Next; IF ch =")" THEN Next; done:= TRUE END;
				| 0X: done := TRUE;
				ELSE Next;
				END;
			UNTIL done;
		END Comment;

		PROCEDURE String(delimiter: CHAR);
		VAR done: BOOLEAN;
		BEGIN
			done := FALSE; Next;
			REPEAT
				IF ch = delimiter THEN done := TRUE; Next;
				ELSIF ch = 0X THEN done := TRUE; error := TRUE;
				ELSE Append(ch); Next;
				END;
			UNTIL done OR (i=LEN(string)-1);
		END String;

	BEGIN
		i := 0; done := FALSE;
		ch := r.Peek(); (* restart scanning *)
		SkipWhitespace;
		REPEAT
			CASE ch OF
				"(": Next; IF ch = "*" THEN Comment ; SkipWhitespace ELSE Append(ch) END;
				| "*": Next; IF ch = ")" THEN Next; SkipWhitespace ELSE Append(ch) END;
				| '"', "'": done := TRUE; IF i = 0 THEN String(ch) END;
				| 0X .. ' ', '~', ';': done := TRUE;
			ELSE
				Append(ch);
				Next;
			END;
		UNTIL done OR (i = LEN(string)-1);
		string[i] := 0X;
		RETURN (i > 0) & done & ~error;
	END GetStringParameter;

	PROCEDURE GetTracingDiagnostics*(diagnostics: Diagnostics.Diagnostics): Diagnostics.Diagnostics;
	VAR tracing: TracingDiagnostics;
	BEGIN
		NEW(tracing, diagnostics); RETURN tracing
	END GetTracingDiagnostics;

	PROCEDURE InitTable32;
	CONST poly = LONGINT(0EDB88320H);
	VAR n, c, k: LONGINT;
	BEGIN
		FOR n := 0 TO 255 DO
			c := n;
			FOR k := 0 TO 7 DO
				IF ODD(c) THEN c := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, poly) / SYSTEM.VAL(SET, LSH(c, -1)))
				ELSE c := LSH(c, -1)
				END
			END;
			CRC32Table[n] := SYSTEM.VAL(SET, c)
		END
	END InitTable32;

BEGIN
	InitErrorMessages;
	InitWindowWriter;
	InitTable32;
	lists := 0;  enlarged := 0;  strings := 0;
	emptyString := MakeString("");
	debug := FALSE;
	NEW(integerObjects, 128);
END FoxBasic.

FoxBasic.ActivateDebug ~


FoxBasic.Test ~