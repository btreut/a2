MODULE Containers; (** AUTHOR "SAGE"; PURPOSE "Generic Containers for different base
	and complex types"; *)

(*
	2013/03/14 - SAGE: Dictionary Remove method implemented.
	2013/02/24 - SAGE: Renamed List to Vector (C++ STL notation), because it's more
		clear name for structure based on dynamic array and turned back to traditional
		list growths strategy (increasing array size twice). Added Dictionary class
		based on simple implementation (simple collision resolving technique and ) of
		hash table, suitable for making on top of it Map and Set structures in C++ STL
		notation. Moved Heap class from BinaryHeaps module.
	2013/02/10 - SAGE: Much more effective (for about 40% less comparisons needed in some
		algorithms) implementation of binary search algorithm. Binary search algorithm
		integer overflow bug of middle position calculation fixed. Special list growth
		strategy for preventing waste of memory.
*)

IMPORT
	Strings, UTF8Strings,
	Commands;

CONST
	VECTOR_SORTED* = 0;
	VECTOR_NO_DUPLICATES* = 1;
	BASE_DWORD = 32;

TYPE
	
	LongintArray = POINTER TO ARRAY OF LONGINT;
	
	SetArray = POINTER TO ARRAY OF SET;
	
	LongintItem* = POINTER TO RECORD
		value*: LONGINT;
	END;
	
	StringItem* = POINTER TO RECORD
		value*: Strings.String;
	END;
	
	AnyArray* = POINTER TO ARRAY OF ANY;

	(** CompareMethod defines a Method that compares two Objects.
		The Method then returns:
			-1	if the first Object is "smaller" then the second Object
			0	if both Objects are "equal"
			1	if the first Object is "greater" then the second Object. *)
	CompareMethod* = PROCEDURE {DELEGATE} (first, second: ANY): LONGINT;
	
	(** EqualityCompareMethod defines a Method that compares two Objects.
		The Methods then returns:
			TRUE	if both Objects are "equal". *)
	EqualityCompareMethod* = PROCEDURE {DELEGATE} (first, second: ANY): BOOLEAN;
	
	(** HashMethod defines a Method that returns hash code for Object.
		The Methods then returns:
			hash code. *)
	HashMethod* = PROCEDURE {DELEGATE} (item: ANY): LONGINT;

	(** Base Vector container *)	
	Vector* = OBJECT
	
		VAR
			array: AnyArray;
			
			nCount, nReadLock: LONGINT;
			
			compare: CompareMethod;
			
			bSorted, bNoDuplicates: BOOLEAN;
		
		PROCEDURE &Init*(compare: CompareMethod; options: SET);
		BEGIN
			SELF.compare := compare;
			nReadLock := 0;
			nCount := 0;
			bSorted := {VECTOR_SORTED} * options # {};
			bNoDuplicates := {VECTOR_NO_DUPLICATES} * options # {};
			NEW(array, 4)
		END Init;
		
		(** Lock prevents modifications to the list. All calls to Lock
			must be followed by a call to Unlock. Lock can be nested. *)
		PROCEDURE Lock;
		BEGIN {EXCLUSIVE}
			INC(nReadLock); ASSERT(nReadLock > 0)
		END Lock;

		(** Unlock removes one modification lock. All calls to Unlock
			must be preceeded by a call to Lock. *)
		PROCEDURE Unlock;
		BEGIN {EXCLUSIVE}
			DEC(nReadLock); ASSERT(nReadLock >= 0)
		END Unlock;
	
		PROCEDURE Grow;
		VAR
			old: AnyArray;
			nLen, i: LONGINT;
		BEGIN
			old := array;
			nLen := LEN(old);
			
			(*
			(*
				Special list growth strategy for
				preventing waste of memory.
				Same strategy used in Qt containers.
			*)
			IF nLen < 20 THEN
				INC(nLen, 4)
			ELSIF nLen < 4084 THEN
				nLen := nLen * 2 + 12
			ELSE
				INC(nLen, 2048)
			END;
			*)
			
			(*nLen := nLen + nLen DIV 2;*)
			
			nLen := nLen*2;
			
			NEW(array, nLen);
			FOR i := 0 TO LEN(old) - 1 DO
				array[i] := old[i]
			END
		END Grow;
		
		PROCEDURE FindSequentially(x: ANY): LONGINT;
		VAR
			i: LONGINT;
		BEGIN
			i := 0;
			WHILE i < nCount DO
				IF compare(x, array[i]) = 0 THEN
					RETURN i
				END;
				INC(i)
			END;
			RETURN -1
		END FindSequentially;

		(*
		PROCEDURE FindPosition(x: ANY): LONGINT;
		VAR
			lower, middle, upper: LONGINT;
			value: LONGINT;
		BEGIN
			IF count = 0 THEN RETURN 0 END;
			IF compare(list[0], x) > 0 THEN RETURN 0 END;
			IF compare(list[count-1], x) < 0 THEN RETURN count END;
			lower := 0;
			upper := count - 1;
			WHILE (upper - lower) > 1 DO

				middle := (upper + lower) DIV 2;

				value := compare(list[middle], x);
				IF value = 0 THEN RETURN middle END;
				IF value < 0 THEN
					lower := middle
				ELSE
					upper := middle
				END;
			END;
			IF compare(list[lower], x) = 0 THEN
				RETURN lower
			ELSE
				RETURN upper
			END;
		END FindPosition;
		*)
		
		PROCEDURE FindPosition(x: ANY; VAR bFound: BOOLEAN): LONGINT;
		VAR
			lower, middle, upper: LONGINT;
			value: LONGINT;
		BEGIN
			bFound := FALSE;
			IF nCount = 0 THEN RETURN 0 END;
			lower := 0;
			upper := nCount - 1;
			WHILE lower <= upper DO
				middle := lower + (upper - lower) DIV 2;
				value := compare(array[middle], x);
				IF value = 0 THEN
					bFound := TRUE;
					RETURN middle
				ELSIF value < 0 THEN
					lower := middle + 1
				ELSE
					upper := middle - 1
				END;
			END;
			IF lower <= upper THEN
				RETURN upper
			ELSE
				RETURN lower
			END;
		END FindPosition;
		
		(** return the index of an object. In a multi-process situation, the process calling the IndexOf method should
			call Lock before IndexOf and Unlock after the last use of an index based on IndexOf.
			If the object is not found, -1 is returned *)
		PROCEDURE IndexOf*(x: ANY): LONGINT;
		VAR
			pos: LONGINT;
			bFound: BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF bSorted THEN
				pos := FindPosition(x, bFound);
				IF bFound THEN
					RETURN pos
				ELSE
					RETURN -1
				END
			ELSE
				RETURN FindSequentially(x)
			END
		END IndexOf;
		
		(** return the number of objects in the list. If count is used for indexing elements (e.g. FOR - Loop) in a multi-process
			situation, the process calling the GetCount method should call Lock before GetCount and Unlock after the
			last use of an index based on GetCount *)
		PROCEDURE GetCount*():LONGINT;
		BEGIN
			RETURN nCount
		END GetCount;
		
		(** return an object based on an index. In a multi-process situation, GetItem is only safe in a locked region Lock / Unlock *)
		PROCEDURE GetItem*(pos: LONGINT): ANY;
		BEGIN
			ASSERT((pos >= 0) & (pos < nCount), 101);
			RETURN array[pos]
		END GetItem;

		(** Add an object to the list. Add may block if number of
			calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Add*(x: ANY);
		BEGIN {EXCLUSIVE}
			AWAIT(nReadLock = 0);
			IF bSorted THEN AddUnlocked(x) ELSE AppendUnlocked(x) END
		END Add;
		
		PROCEDURE Insert*(pos: LONGINT; x: ANY);
		BEGIN {EXCLUSIVE}
			AWAIT(nReadLock = 0);
			ASSERT((pos >= 0) & (pos < nCount), 101);
			IF bSorted THEN AddUnlocked(x) ELSE InsertUnlocked(pos, x) END
		END Insert;

		(** Does the actual Adding without locking (should already
			have been done by the caller) *)
		PROCEDURE AddUnlocked(x: ANY);
		VAR
			i, pos: LONGINT;
			bFound: BOOLEAN;
		BEGIN
			pos := FindPosition(x, bFound);
			IF bNoDuplicates THEN
				ASSERT(~bFound)
			END;
			IF nCount = LEN(array) THEN Grow END;
			i := nCount - 1;
			WHILE i >= pos DO
				array[i + 1] := array[i];
				DEC(i)
			END;
			array[pos] := x;
			INC(nCount)
		END AddUnlocked;
		
		PROCEDURE AppendUnlocked(x: ANY);
		BEGIN
			IF bNoDuplicates THEN
				ASSERT(FindSequentially(x) = -1)
			END;
			IF nCount = LEN(array) THEN Grow END;
			array[nCount] := x;
			INC(nCount)
		END AppendUnlocked;
		
		PROCEDURE InsertUnlocked(pos: LONGINT; x: ANY);
		VAR
			i: LONGINT;
		BEGIN
			IF bNoDuplicates THEN
				ASSERT(FindSequentially(x) = -1)
			END;
			IF nCount = LEN(array) THEN Grow END;
			i := nCount - 1;
			WHILE i >= pos DO
				array[i + 1] := array[i];
				DEC(i)
			END;
			array[pos] := x;
			INC(nCount)			
		END InsertUnlocked;

		(** Remove an object from the list. Remove may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Remove*(pos: LONGINT);
		BEGIN {EXCLUSIVE}
			AWAIT(nReadLock = 0);
			ASSERT((pos >= 0) & (pos < nCount), 101);
			RemoveUnlocked(pos)
		END Remove;

		(* Does the actual Removing without locking (should already have been done by the caller) *)
		PROCEDURE RemoveUnlocked(pos: LONGINT);
		BEGIN
			WHILE pos < nCount - 1 DO
				array[pos] := array[pos + 1];
				INC(pos)
			END;
			DEC(nCount);
			array[nCount] := NIL
		END RemoveUnlocked;

		(** atomic replace x by y. That means that x is removed and y is added to the SortedList *)
		(*PROCEDURE Replace*(x, y: ANY);
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			RemoveUnlocked(x);
			AddUnlocked(y);
		END Replace;*)

	END Vector;

	(** Custom Vector container for making on top of it of the vectors for any data types *)
	CustomVector* = OBJECT
		VAR
			vector*: Vector;
			
		PROCEDURE Lock*;
		BEGIN
			vector.Lock
		END Lock;
		
		PROCEDURE Unlock*;
		BEGIN
			vector.Unlock
		END Unlock;
		
		PROCEDURE Remove*(i: LONGINT);
		BEGIN
			vector.Remove(i)
		END Remove;
		
		PROCEDURE GetCount*(): LONGINT;
		BEGIN
			RETURN vector.GetCount()
		END GetCount;
		
		PROCEDURE IsEmpty*(): BOOLEAN;
		BEGIN
			RETURN vector.GetCount() = 0
		END IsEmpty;
			
	END CustomVector;
	
	(** Vector of LONGINTs *)
	LongintVector* = OBJECT(CustomVector)
			
		PROCEDURE &New*(options: SET);
		BEGIN
			NEW(vector, Compare, options)
		END New;
		
		PROCEDURE Compare(first, second: ANY): LONGINT;
		VAR
			nFirst, nSecond: LONGINT;
		BEGIN
			nFirst := first(LongintItem).value;
			nSecond := second(LongintItem).value;
			IF nFirst < nSecond THEN
				RETURN -1
			ELSIF nFirst > nSecond THEN
				RETURN 1
			ELSE
				RETURN 0
			END
		END Compare;
		
		PROCEDURE Add*(x: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			vector.Add(item)
		END Add;
		
		PROCEDURE Insert*(pos: LONGINT; x: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			vector.Insert(pos, item)
		END Insert;
		
		PROCEDURE IndexOf*(x: LONGINT): LONGINT;
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			RETURN vector.IndexOf(item)
		END IndexOf;
		
		PROCEDURE GetItem*(i: LONGINT): LONGINT;
		BEGIN
			RETURN vector.GetItem(i)(LongintItem).value
		END GetItem;
			
	END LongintVector;

	(** Vector of LONGINT vectors *)	
	LongintVectorVector* = OBJECT(CustomVector)
			
		PROCEDURE &New*(options: SET);
		BEGIN
			NEW(vector, Compare, options)
		END New;
		
		PROCEDURE Compare(first, second: ANY): LONGINT;
		BEGIN
			RETURN CompareLongintVectors(first(LongintVector), second(LongintVector))
		END Compare;
				
		PROCEDURE Add*(x: LongintVector);
		BEGIN
			vector.Add(x)
		END Add;
		
		PROCEDURE Insert*(pos: LONGINT; x: LongintVector);
		BEGIN
			vector.Insert(pos, x)
		END Insert;
		
		PROCEDURE IndexOf*(x: LongintVector): LONGINT;
		BEGIN
			RETURN vector.IndexOf(x)
		END IndexOf;
		
		PROCEDURE GetItem*(i: LONGINT): LongintVector;
		BEGIN
			RETURN vector.GetItem(i)(LongintVector)
		END GetItem;
		
	END LongintVectorVector;
	
	(** Vector of strings *)
	StringVector* = OBJECT(CustomVector)
			
		PROCEDURE &New*(options: SET);
		BEGIN
			NEW(vector, Compare, options)
		END New;
		
		PROCEDURE Compare(first, second: ANY): LONGINT;
		BEGIN
			RETURN UTF8Strings.Compare(first(StringItem).value^,
				second(StringItem).value^)
		END Compare;
				
		PROCEDURE Add*(CONST x: ARRAY OF CHAR);
		VAR
			item: StringItem;
		BEGIN
			NEW(item);
			item.value := Strings.NewString(x);
			vector.Add(item)
		END Add;
		
		PROCEDURE Insert*(pos: LONGINT; CONST x: ARRAY OF CHAR);
		VAR
			item: StringItem;
		BEGIN
			NEW(item);
			item.value := Strings.NewString(x);
			vector.Insert(pos, item)
		END Insert;
		
		PROCEDURE IndexOf*(CONST x: ARRAY OF CHAR): LONGINT;
		VAR
			item: StringItem;
		BEGIN
			NEW(item);
			item.value := Strings.NewString(x);
			RETURN vector.IndexOf(item)
		END IndexOf;
		
		PROCEDURE GetItem*(i: LONGINT): Strings.String;
		BEGIN
			RETURN vector.GetItem(i)(StringItem).value
		END GetItem;
		
	END StringVector;
	
	(** Base Dictionary container *)	
	Dictionary* = OBJECT
	VAR
		array: AnyArray;
		hashes: LongintArray;
		deleted: SetArray;
		
		iterator*: DictionaryIterator;
		
		nCount, iPrime-, nCollisions-: LONGINT;
		
		equal: EqualityCompareMethod;
		hash: HashMethod;
		
		PROCEDURE &Init*(equal: EqualityCompareMethod; hash: HashMethod);
		BEGIN
			SELF.equal := equal;
			SELF.hash := hash;
			nCount := 0;
			iPrime := 0;
			nCollisions := 0;
			InitArrays;
			NEW(iterator, SELF);
		END Init;
		
		PROCEDURE InitArrays;
		VAR
			i, prime: LONGINT;
		BEGIN
			prime := PRIMES[iPrime];
			NEW(array, prime);
			FOR i := 0 TO LEN(array) - 1 DO
				array[i] := NIL
			END;
			NEW(hashes, prime);
			NEW(deleted, prime DIV BASE_DWORD + 1);
			FOR i := 0 TO LEN(deleted) - 1 DO
				deleted[i] := {}
			END;
		END InitArrays;
		
		PROCEDURE Grow;
		VAR
			oldArray: AnyArray;
			oldHashes: LongintArray;
			oldDeleted: SetArray;
			i: LONGINT;
			
			PROCEDURE Deleted(i: LONGINT): BOOLEAN;
			VAR
				iDiv, iMod: LONGINT;
			BEGIN
				iDiv := i DIV BASE_DWORD;
				iMod := i MOD BASE_DWORD;
				RETURN oldDeleted[iDiv] * {iMod} # {}
			END Deleted;
			
		BEGIN
			oldArray := array;
			oldHashes := hashes;
			oldDeleted := deleted;
			INC(iPrime);
			
			InitArrays;
			iterator.Init(SELF);

			FOR i := 0 TO LEN(oldArray) - 1 DO
				IF (oldArray[i] # NIL) & ~Deleted(i) THEN
					ASSERT(~hashSearch(oldArray[i], TRUE, TRUE, oldHashes[i]))
				END
			END
		END Grow;
		
		PROCEDURE Delete(i: LONGINT);
		VAR
			iDiv, iMod: LONGINT;
		BEGIN
			iDiv := i DIV BASE_DWORD;
			iMod := i MOD BASE_DWORD;
			deleted[iDiv] := deleted[iDiv] + {iMod}
		END Delete;
		
		PROCEDURE Deleted(i: LONGINT): BOOLEAN;
		VAR
			iDiv, iMod: LONGINT;
		BEGIN
			iDiv := i DIV BASE_DWORD;
			iMod := i MOD BASE_DWORD;
			RETURN deleted[iDiv] * {iMod} # {}
		END Deleted;
		
		PROCEDURE GetCount(): LONGINT;
		BEGIN
			RETURN nCount
		END GetCount;
		
		PROCEDURE Add*(item: ANY);
		VAR
			nHashCode: LONGINT;
		BEGIN
			ASSERT(~hashSearch(item, TRUE, FALSE, nHashCode));
			INC(nCount);
			(* fill factor 5/8 = 0.625 (near to 0.63) *)
			IF (nCount*8) DIV 5 >= PRIMES[iPrime] THEN
				Grow
			END;
		END Add;
		
		PROCEDURE Contains*(item: ANY): BOOLEAN;
		VAR
			nHashCode: LONGINT;
		BEGIN
			RETURN hashSearch(item, FALSE, FALSE, nHashCode);
		END Contains;
		
		PROCEDURE Get*(item: ANY): ANY;
		VAR
			nHashCode: LONGINT;
			itemResult: ANY;
		BEGIN
			itemResult := NIL;
			IF hashSearch(item, FALSE, FALSE, nHashCode) THEN
				itemResult := array[nHashCode]
			END;
			RETURN itemResult;
		END Get;
		
		PROCEDURE Remove*(item: ANY);
		VAR
			nHashCode: LONGINT;
		BEGIN
			IF hashSearch(item, FALSE, FALSE, nHashCode) THEN
				Delete(nHashCode);
				DEC(nCount);
			END;
		END Remove;
		
		PROCEDURE hashSearch(item: ANY; bAddAllowed: BOOLEAN; bGrowOperation: BOOLEAN; VAR nHashCode: LONGINT): BOOLEAN;
		VAR
			d, nHash, h, prime: LONGINT;
			bFound, bExit, bOverflow: BOOLEAN;
		BEGIN
		
			IF bGrowOperation THEN
				nHash := nHashCode;
			ELSE
				nHash := ABS(hash(item));
			END;
			
			LOOP

				d := 1;
				bExit := FALSE;
				bFound := FALSE;
				bOverflow := FALSE;
				prime := PRIMES[iPrime];
				h := nHash MOD prime;

				WHILE ~(bFound OR bExit) DO
					IF (array[h] = NIL) OR (~bGrowOperation & (array[h] # NIL) & Deleted(h) & bAddAllowed) THEN (* new entry *)
						bExit := TRUE;
						IF bAddAllowed THEN
							array[h] := item;
							hashes[h] := nHash;
							nHashCode := h
						END
					ELSIF ~bGrowOperation & ~Deleted(h) & equal(array[h], item) THEN (* match *)
						bFound := TRUE;
						nHashCode := h;
					ELSE (* collision *)
						INC(nCollisions);
						h := h + d; d := d + 2;
						IF h >= prime THEN h := h - prime END;
						IF d = prime THEN (* Table owerflow! *)
							bExit := TRUE;
							bOverflow := bAddAllowed;
						END
					END
				END;
				
				IF bOverflow THEN
					Grow
				ELSE
					EXIT
				END
			
			END;

			RETURN bFound

		END hashSearch;
		
	END Dictionary;
	
	(** Iterator for sequental access to the Dictionary *)
	DictionaryIterator* = OBJECT
	VAR 
		iCurrentPos: LONGINT;
		dictionary: Dictionary;
		
		PROCEDURE &New*(dictionary: Dictionary);
		BEGIN
			Init(dictionary);
		END New;
		
		PROCEDURE Init(dictionary: Dictionary);
		BEGIN
			SELF.dictionary := dictionary;
			iCurrentPos := -1;
		END Init;
			
		PROCEDURE Reset*;
		BEGIN
			iCurrentPos := -1;
		END Reset;

		PROCEDURE HasNext*(): BOOLEAN;
		VAR
			i: LONGINT;
		BEGIN
			i := iCurrentPos;
			REPEAT
				INC(i);
			UNTIL (i >= LEN(dictionary.array)) OR ((dictionary.array[i] # NIL) & ~dictionary.Deleted(i));
			RETURN i < LEN(dictionary.array)
		END HasNext;

		PROCEDURE GetNext*(): ANY;
		VAR
			item: ANY;
		BEGIN
			REPEAT
				INC(iCurrentPos);
			UNTIL (iCurrentPos >= LEN(dictionary.array)) OR ((dictionary.array[iCurrentPos] # NIL) & ~dictionary.Deleted(iCurrentPos));
			item := NIL;
			IF iCurrentPos < LEN(dictionary.array) THEN
				item := dictionary.array[iCurrentPos];
			END;
			RETURN item
		END GetNext;
		
	END DictionaryIterator;
	
	(** Custom Set container for making on top of it of
		the sets (sets consists of only pure keys without any other data)
		and maps (maps consists of pairs key:value) for any data types *)
	CustomSet* = OBJECT
	VAR 
		dictionary*: Dictionary;
		
		PROCEDURE GetCount*(): LONGINT;
		BEGIN
			RETURN dictionary.GetCount()
		END GetCount;
		
		PROCEDURE IsEmpty*(): BOOLEAN;
		BEGIN
			RETURN dictionary.GetCount() = 0
		END IsEmpty;
		
		PROCEDURE Reset*;
		BEGIN
			dictionary.iterator.Reset
		END Reset;

		PROCEDURE HasNext*(): BOOLEAN;
		BEGIN
			RETURN dictionary.iterator.HasNext()
		END HasNext;
		
	END CustomSet;
	
	(** Set of LONGINTs *)
	LongintSet* = OBJECT(CustomSet)
		
		PROCEDURE LongintItemsEqual(first, second: ANY): BOOLEAN;
		BEGIN
			RETURN first(LongintItem).value = second(LongintItem).value
		END LongintItemsEqual;
		
		PROCEDURE LongintItemHash(item: ANY): LONGINT;
		BEGIN
			RETURN item(LongintItem).value
		END LongintItemHash;
		
		PROCEDURE &Init*;
		BEGIN
			NEW(dictionary, LongintItemsEqual, LongintItemHash);
		END Init;
		
		PROCEDURE Add*(x: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			dictionary.Add(item)
		END Add;
		
		PROCEDURE Remove*(x: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			dictionary.Remove(item)
		END Remove;
		
		PROCEDURE Contains*(x: LONGINT): BOOLEAN;
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			RETURN dictionary.Contains(item)
		END Contains;

		PROCEDURE GetNext*(): LONGINT;
		BEGIN
			RETURN dictionary.iterator.GetNext()(LongintItem).value
		END GetNext;
		
		PROCEDURE ToString*(): Strings.String;
		VAR
			a: ARRAY 32 OF CHAR;
			s: Strings.String;
		BEGIN
			Reset;
			s := Strings.NewString("{");
			WHILE HasNext() DO
				Strings.IntToStr(GetNext(), a);
				s := Strings.ConcatToNew(s^, a);
				IF HasNext() THEN
					s := Strings.ConcatToNew(s^, ", ")
				END
			END;
			s := Strings.ConcatToNew(s^, "}");
			RETURN s
		END ToString;

	END LongintSet;
	
	(** Set of Strings *)
	StringSet* = OBJECT(CustomSet)
		
		PROCEDURE StringsEqual(first, second: ANY): BOOLEAN;
		BEGIN
			RETURN first(StringItem).value^ = second(StringItem).value^
		END StringsEqual;
		
		PROCEDURE StringHash(item: ANY): LONGINT;
		BEGIN
			RETURN HashString(item(StringItem).value)
		END StringHash;
		
		PROCEDURE &Init*;
		BEGIN
			NEW(dictionary, StringsEqual, StringHash);
		END Init;
		
		PROCEDURE Add*(CONST x: ARRAY OF CHAR);
		VAR
			item: StringItem;
		BEGIN
			NEW(item);
			item.value := Strings.NewString(x);
			dictionary.Add(item)
		END Add;
		
		PROCEDURE Remove*(CONST x: ARRAY OF CHAR);
		VAR
			item: StringItem;
		BEGIN
			NEW(item);
			item.value := Strings.NewString(x);
			dictionary.Remove(item)
		END Remove;
		
		PROCEDURE Contains*(CONST x: ARRAY OF CHAR): BOOLEAN;
		VAR
			item: StringItem;
		BEGIN
			NEW(item);
			item.value := Strings.NewString(x);
			RETURN dictionary.Contains(item)
		END Contains;

		PROCEDURE GetNext*(): Strings.String;
		BEGIN
			RETURN dictionary.iterator.GetNext()(StringItem).value
		END GetNext;

	END StringSet;
	
	(** Set of LONGINT sets *)
	LongintSetSet* = OBJECT(CustomSet)
			
		PROCEDURE LongintSetsEqual(first, second: ANY): BOOLEAN;
		BEGIN
			RETURN EqualityCompareLongintSets(first(LongintSet), second(LongintSet))
		END LongintSetsEqual;
		
		PROCEDURE LongintSetHash(item: ANY): LONGINT;
		BEGIN
			RETURN HashLongintSet(item(LongintSet))
		END LongintSetHash;
		
		PROCEDURE &Init*;
		BEGIN
			NEW(dictionary, LongintSetsEqual, LongintSetHash)
		END Init;
		
		PROCEDURE Add*(x: LongintSet);
		BEGIN
			dictionary.Add(x)
		END Add;
		
		PROCEDURE Remove*(x: LongintSet);
		BEGIN
			dictionary.Remove(x)
		END Remove;
		
		PROCEDURE Contains*(x: LongintSet): BOOLEAN;
		BEGIN
			RETURN dictionary.Contains(x)
		END Contains;
		
		PROCEDURE GetNext*(): LongintSet;
		BEGIN
			RETURN dictionary.iterator.GetNext()(LongintSet)
		END GetNext;
		
	END LongintSetSet;
	
	(** Vector of LONGINT sets *)	
	LongintSetVector* = OBJECT(CustomVector)
			
		PROCEDURE &New*(options: SET);
		BEGIN
			NEW(vector, Compare, options)
		END New;
		
		PROCEDURE Compare(first, second: ANY): LONGINT;
		BEGIN
			RETURN CompareLongintSets(first(LongintSet), second(LongintSet))
		END Compare;
				
		PROCEDURE Add*(x: LongintSet);
		BEGIN
			vector.Add(x)
		END Add;
		
		PROCEDURE Insert*(pos: LONGINT; x: LongintSet);
		BEGIN
			vector.Insert(pos, x)
		END Insert;
		
		PROCEDURE IndexOf*(x: LongintSet): LONGINT;
		BEGIN
			RETURN vector.IndexOf(x)
		END IndexOf;
		
		PROCEDURE GetItem*(i: LONGINT): LongintSet;
		BEGIN
			RETURN vector.GetItem(i)(LongintSet)
		END GetItem;
		
	END LongintSetVector;
	
	(** Binary heap. *)
	Heap* = OBJECT
	
		VAR
			array: AnyArray;
			nCount, nReadLock: LONGINT;
			compare: CompareMethod;

		PROCEDURE &Init*(compare: CompareMethod);
		BEGIN
			SELF.compare := compare;
			nReadLock := 0;
			nCount := 0;
			NEW(array, 8)
		END Init;
		
		(** Lock prevents modifications to the list. All calls to Lock
			must be followed by a call to Unlock. Lock can be nested. *)
		PROCEDURE Lock*;
		BEGIN {EXCLUSIVE}
			INC(nReadLock); ASSERT(nReadLock > 0)
		END Lock;

		(** Unlock removes one modification lock. All calls to Unlock
			must be preceeded by a call to Lock. *)
		PROCEDURE Unlock*;
		BEGIN {EXCLUSIVE}
			DEC(nReadLock); ASSERT(nReadLock >= 0)
		END Unlock;
		
		PROCEDURE Grow;
		VAR
			old: AnyArray;
			i: LONGINT;
		BEGIN
			old := array;
			NEW(array, LEN(array) * 2);
			FOR i := 0 TO LEN(old) - 1 DO
				array[i] := old[i]
			END
		END Grow;
		
		(** return the number of objects in the list. If count is used for indexing elements (e.g. FOR - Loop) in a multi-process
			situation, the process calling the GetCount method should call Lock before GetCount and Unlock after the
			last use of an index based on GetCount *)
		PROCEDURE GetCount*():LONGINT;
		BEGIN
			RETURN nCount
		END GetCount;
		
		(** Add an object to the list. Add may block if number of
			calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Add*(x: ANY);
		BEGIN {EXCLUSIVE}
			AWAIT(nReadLock = 0);
			AddUnlocked(x);
		END Add;
		
		(** Does the actual Adding without locking (should already
			have been done by the caller) *)
		PROCEDURE AddUnlocked(x: ANY);
		VAR
			i, pos: LONGINT;
			tmp: ANY;
		BEGIN
			IF LEN(array) = nCount + 1 THEN Grow END;
			INC(nCount);
			array[nCount] := x;
			pos := nCount;
			LOOP
				i := pos DIV 2;
				IF (i > 0) & (compare(array[pos], array[i]) < 0) THEN
					tmp := array[i];
					array[i] := array[pos];
					array[pos] := tmp;
					pos := i
				ELSE EXIT END;
				IF pos = 1 THEN EXIT END
			END
		END AddUnlocked;
		
		PROCEDURE FindSequentially(x: ANY): LONGINT;
		VAR
			i: LONGINT;
		BEGIN
			i := 1;
			WHILE (i <= nCount) & (array[i] # x) DO
				INC(i)
			END;
			IF i <= nCount THEN
				RETURN i
			ELSE
				RETURN -1
			END
		END FindSequentially;
		
		PROCEDURE Update*(x: ANY);
		VAR
			pos: LONGINT;
			i: LONGINT;
			tmp: ANY;
		BEGIN
			pos := FindSequentially(x);
			IF pos > 0 THEN
				LOOP
					i := pos DIV 2;
					IF (i > 0) & (compare(array[pos], array[i]) < 0) THEN
						tmp := array[i];
						array[i] := array[pos];
						array[pos] := tmp;
						pos := i
					ELSE EXIT END;
					IF pos = 1 THEN EXIT END
				END
			END
		END Update;
		
		(** Remove an object from the list. Remove may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Remove*(): ANY;
		VAR
			x: ANY;
		BEGIN {EXCLUSIVE}
			IF nCount > 0 THEN
				AWAIT(nReadLock = 0);
				x := RemoveUnlocked();
				RETURN x
			ELSE
				RETURN NIL
			END
		END Remove;

		(* Does the actual Removing without locking (should already have been done by the caller) *)
		PROCEDURE RemoveUnlocked(): ANY;
		VAR
			i1, i2, u, v: LONGINT;
			x, tmp: ANY;
		BEGIN
			v := 1;
			x := array[v];
			array[v] := array[nCount];
			array[nCount] := NIL;
			DEC(nCount);
			LOOP
				u := v;
				i1 := 2 * u;
				i2 := 2 * u + 1;
				IF i2 <= nCount THEN
					IF compare(array[u], array[i1]) >= 0 THEN v := i1 END;
					IF compare(array[v], array[i2]) >= 0 THEN v := i2 END
				ELSIF i1 <= nCount THEN
					IF compare(array[u], array[i1]) >= 0 THEN v := i1 END
				END;
				IF u # v THEN
					tmp := array[u];
					array[u] := array[v];
					array[v] := tmp
				ELSE EXIT END
			END;
			RETURN x
		END RemoveUnlocked;
		
	END Heap;
	
	CustomHeap* = OBJECT
	
		VAR
			heap*: Heap;
			
		PROCEDURE Lock*;
		BEGIN
			heap.Lock
		END Lock;
		
		PROCEDURE Unlock*;
		BEGIN
			heap.Unlock
		END Unlock;
		
		PROCEDURE GetCount*(): LONGINT;
		BEGIN
			RETURN heap.GetCount()
		END GetCount;
		
		PROCEDURE IsEmpty*(): BOOLEAN;
		BEGIN
			RETURN heap.GetCount() = 0
		END IsEmpty;
			
	END CustomHeap;
	
	LongintHeap* = OBJECT(CustomHeap)
			
		PROCEDURE &New*;
		BEGIN
			NEW(heap, Compare)
		END New;
		
		PROCEDURE Compare(first, second: ANY): LONGINT;
		VAR
			nFirst, nSecond: LONGINT;
		BEGIN
			nFirst := first(LongintItem).value;
			nSecond := second(LongintItem).value;
			IF nFirst < nSecond THEN
				RETURN -1
			ELSIF nFirst > nSecond THEN
				RETURN 1
			ELSE
				RETURN 0
			END
		END Compare;
		
		PROCEDURE Add*(x: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			heap.Add(item);
		END Add;
		
		PROCEDURE Remove*(): LONGINT;
		BEGIN
			RETURN heap.Remove()(LongintItem).value
		END Remove;
		
	END LongintHeap;
	
	VAR
		PRIMES: ARRAY 27 OF LONGINT;
	
	PROCEDURE CompareLongintVectors*(first, second: LongintVector): LONGINT;
	VAR
		n, i, nRes: LONGINT;
	BEGIN
		n := MIN(first.GetCount(), second.GetCount());
		IF n = 0 THEN
			IF first.GetCount() > 0 THEN
				RETURN 1
			ELSIF second.GetCount() > 0 THEN
				RETURN -1
			ELSE
				RETURN 0
			END
		ELSE
			i := 0; nRes := 0;
			WHILE (i < n) & (nRes = 0) DO
				IF first.GetItem(i) < second.GetItem(i) THEN
					nRes := -1
				ELSIF first.GetItem(i) > second.GetItem(i) THEN
					nRes := 1
				ELSE
					nRes := 0
				END;
				INC(i)
			END;
			IF nRes # 0 THEN
				RETURN nRes
			ELSIF first.GetCount() > n THEN
				RETURN 1
			ELSIF second.GetCount() > n THEN
				RETURN -1
			ELSE
				RETURN 0
			END
		END
	END CompareLongintVectors;
	
	PROCEDURE CompareLongintSets*(first, second: LongintSet): LONGINT;
	VAR
		n, i, nRes, iF, iS: LONGINT;
	BEGIN
		n := MIN(first.GetCount(), second.GetCount());
		IF n = 0 THEN
			IF first.GetCount() > 0 THEN
				RETURN 1
			ELSIF second.GetCount() > 0 THEN
				RETURN -1
			ELSE
				RETURN 0
			END
		ELSE
			i := 0; nRes := 0;
			first.Reset;
			second.Reset;
			WHILE (i < n) & (nRes = 0) & first.HasNext() & second.HasNext() DO
				iF := first.GetNext();
				iS := second.GetNext();
				IF iF < iS THEN
					nRes := -1
				ELSIF iF > iS THEN
					nRes := 1
				ELSE
					nRes := 0
				END;
				INC(i)
			END;
			IF nRes # 0 THEN
				RETURN nRes
			ELSIF first.GetCount() > n THEN
				RETURN 1
			ELSIF second.GetCount() > n THEN
				RETURN -1
			ELSE
				RETURN 0
			END
		END
	END CompareLongintSets;
	
	PROCEDURE EqualityCompareLongintSets*(first, second: LongintSet): BOOLEAN;
	VAR
		bResult: BOOLEAN;
	BEGIN
		bResult := first.GetCount() = second.GetCount();
		first.Reset;
		WHILE bResult & first.HasNext() DO
			bResult := second.Contains(first.GetNext())
		END;
		RETURN bResult
	END EqualityCompareLongintSets;
	
	PROCEDURE HashLongintSet*(item: LongintSet): LONGINT;
	VAR
		i, iValue, iDivSum, iModSum, n: LONGINT;
	BEGIN
		iDivSum := 0;
		iModSum := 0;
		item.Reset;
		n := item.GetCount();
		IF n = 0 THEN
			RETURN 0
		ELSIF n > 8 THEN
			n := 8
		END;
		i := 0;
		WHILE item.HasNext() & (i < n) DO
			iValue := item.GetNext();
			INC(iDivSum, iValue DIV n); 
			INC(iModSum, iValue MOD n);
			INC(i)
		END;
		RETURN iDivSum + iModSum DIV n
	END HashLongintSet;
	
	PROCEDURE HashString*(item: Strings.String): LONGINT;
	VAR
		i, iValue, iDivSum, iModSum, n: LONGINT;
	BEGIN
		iDivSum := 0;
		iModSum := 0;
		n := Strings.Length(item^);
		IF n = 0 THEN
			RETURN 0
		ELSIF n > 8 THEN
			n := 8
		END;
		i := 0;
		WHILE i < n DO
			iValue := ORD(item^[i]);
			INC(iDivSum, iValue DIV n); 
			INC(iModSum, iValue MOD n);
			INC(i)
		END;
		RETURN iDivSum + iModSum DIV n
	END HashString;
	
	PROCEDURE InitPrimes;
	BEGIN
	
		PRIMES[0] := 17;
		PRIMES[1] := 31;
		PRIMES[2] := 67;
		PRIMES[3] := 127;
		PRIMES[4] := 257;
		PRIMES[5] := 509;
		PRIMES[6] := 1021;
		PRIMES[7] := 2053;
		PRIMES[8] := 4099;
		PRIMES[9] := 8191;
		PRIMES[10] := 16381;
		PRIMES[11] := 32771;
		PRIMES[12] := 65537;
		PRIMES[13] := 131071;
		PRIMES[14] := 262147;
		PRIMES[15] := 524287;
		PRIMES[16] := 1048573;
		PRIMES[17] := 2097143;
		PRIMES[18] := 4194301;
		PRIMES[19] := 8388617;
		PRIMES[20] := 16777213;
		PRIMES[21] := 33554467;
		PRIMES[22] := 67108859;
		PRIMES[23] := 134217757;
		PRIMES[24] := 268435459;
		PRIMES[25] := 536870909;
		PRIMES[26] := 1073741827;
		
	END InitPrimes;
	
	PROCEDURE StringSetTest*(context: Commands.Context);
	VAR
		vec: StringVector;
		set: StringSet;
		i: LONGINT;
	BEGIN
		context.out.Ln;
		NEW(vec, {});
		NEW(set);
		vec.Add("ONE");
		vec.Add("TWO");
		vec.Add("THREE");
		vec.Add("FOUR");
		vec.Add("FIVE");
		vec.Add("SIX");
		vec.Add("SEVEN");
		FOR i := 0 TO vec.IndexOf("THREE") DO
			set.Add(vec.GetItem(i)^)
		END;
		FOR i := 0 TO vec.GetCount() - 1 DO
			context.out.Char('"');
			context.out.String(vec.GetItem(i)^);
			context.out.String('" is ');
			IF set.Contains(vec.GetItem(i)^) THEN
				context.out.String("present.")
			ELSE
				context.out.String("absent!!!")
			END;
			context.out.Ln;
		END;
	END StringSetTest;
	
BEGIN

	InitPrimes;

END Containers.

SystemTools.Free Containers ~

Containers.StringSetTest ~



