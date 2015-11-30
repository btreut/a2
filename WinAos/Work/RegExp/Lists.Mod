MODULE Lists; (** AUTHOR "SAGE"; PURPOSE "Generic lists for different base and complex types"; *)

(*
	Parts taken from TFClasses.Mod
*)

CONST
	LIST_SORTED* = 0;
	LIST_NO_DUPLICATES* = 1;

TYPE
	
	ObjectArray* = POINTER TO ARRAY OF ANY;

	(** CompareMethod defines a Method that compares two Objects.
		The Methods then returns:
			-1	if the first Object is "smaller" then the second Object
			0	if both Objects are "equal"
			1	if the first Object is "greater" then the second Object. *)
	CompareMethod* = PROCEDURE {DELEGATE} (first, second: ANY): LONGINT;

	List* = OBJECT
	VAR
		list: ObjectArray;
		count: LONGINT;
		readLock: LONGINT;
		compare: CompareMethod;
		bSorted, bNoDuplicates: BOOLEAN;

		PROCEDURE &Init*(m: CompareMethod; options: SET);
		BEGIN
			compare := m;
			readLock := 0;
			count := 0;
			bSorted := {LIST_SORTED} * options # {};
			bNoDuplicates := {LIST_NO_DUPLICATES} * options # {};
			NEW(list, 8)
		END Init;
		
		(** Lock prevents modifications to the list. All calls to Lock
			must be followed by a call to Unlock. Lock can be nested. *)
		PROCEDURE Lock*;
		BEGIN {EXCLUSIVE}
			INC(readLock); ASSERT(readLock > 0)
		END Lock;

		(** Unlock removes one modification lock. All calls to Unlock
			must be preceeded by a call to Lock. *)
		PROCEDURE Unlock*;
		BEGIN {EXCLUSIVE}
			DEC(readLock); ASSERT(readLock >= 0)
		END Unlock;
		
		PROCEDURE Grow;
		VAR
			old: ObjectArray;
			i: LONGINT;
		BEGIN
			old := list;
			NEW(list, LEN(list) * 2);
			FOR i := 0 TO count - 1 DO
				list[i] := old[i]
			END
		END Grow;
		
		PROCEDURE FindSequentially(x: ANY): LONGINT;
		VAR
			i: LONGINT;
		BEGIN
			i := 0;
			WHILE i < count DO
				IF compare(x, list[i]) = 0 THEN
					RETURN i
				END;
				INC(i)
			END;
			RETURN -1
		END FindSequentially;

		PROCEDURE FindPosition(x: ANY): LONGINT;
		VAR
			lowerBound, upperBound: LONGINT;
			middle: LONGINT;
			value: LONGINT;
		BEGIN
			IF count = 0 THEN RETURN 0; END;
			IF compare(list[0], x) >= 1 THEN RETURN 0; END;
			IF compare(list[count-1], x) <= -1 THEN RETURN count; END;
			lowerBound := 0;
			upperBound := count - 1;
			WHILE (upperBound - lowerBound) > 1 DO
				middle := (lowerBound + upperBound) DIV 2;
				value := compare(list[middle], x);
				IF value = 0 THEN RETURN middle; END;
				IF value < 0 THEN
					lowerBound := middle;
				ELSE
					upperBound := middle;
				END;
			END;
			IF compare(list[lowerBound], x) = 0 THEN
				RETURN lowerBound;
			ELSE
				RETURN upperBound;
			END;
		END FindPosition;
		
		(** return the index of an object. In a multi-process situation, the process calling the IndexOf method should
			call Lock before IndexOf and Unlock after the last use of an index based on IndexOf.
			If the object is not found, -1 is returned *)
		PROCEDURE IndexOf*(x: ANY): LONGINT;
		VAR
			pos: LONGINT;
		BEGIN {EXCLUSIVE}
			IF bSorted THEN
				pos := FindPosition(x);
				IF (pos < count) & (list[pos] # NIL) & (compare(x, list[pos]) = 0) THEN
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
			RETURN count
		END GetCount;
		
		(** return an object based on an index. In a multi-process situation, GetItem is only safe in a locked region Lock / Unlock *)
		PROCEDURE GetItem*(pos: LONGINT): ANY;
		BEGIN
			ASSERT((pos >= 0) & (pos < count), 101);
			RETURN list[pos]
		END GetItem;

		(** Add an object to the list. Add may block if number of
			calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Add*(x: ANY);
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			IF bSorted THEN AddUnlocked(x) ELSE AppendUnlocked(x) END
		END Add;
		
		PROCEDURE Insert*(pos: LONGINT; x: ANY);
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			ASSERT((pos >= 0) & (pos < count), 101);
			IF bSorted THEN AddUnlocked(x) ELSE InsertUnlocked(pos, x) END
		END Insert;

		(** Does the actual Adding without locking (should already
			have been done by the caller) *)
		PROCEDURE AddUnlocked(x: ANY);
		VAR i, pos: LONGINT;
		BEGIN
			pos := FindPosition(x);
			IF bNoDuplicates & (pos < count) & (list[pos] # NIL) THEN
				ASSERT(compare(x, list[pos]) # 0)
			END;
			IF count = LEN(list) THEN Grow END;
			i := count - 1;
			WHILE i >= pos DO
				list[i + 1] := list[i];
				DEC(i)
			END;
			list[pos] := x;
			INC(count)
		END AddUnlocked;
		
		PROCEDURE AppendUnlocked(x: ANY);
		BEGIN
			IF bNoDuplicates THEN
				ASSERT(FindSequentially(x) = -1)
			END;
			IF count = LEN(list) THEN Grow END;
			list[count] := x;
			INC(count)
		END AppendUnlocked;
		
		PROCEDURE InsertUnlocked(pos: LONGINT; x: ANY);
		VAR
			i: LONGINT;
		BEGIN
			IF bNoDuplicates THEN
				ASSERT(FindSequentially(x) = -1)
			END;
			IF count = LEN(list) THEN Grow END;
			i := count - 1;
			WHILE i >= pos DO
				list[i + 1] := list[i];
				DEC(i)
			END;
			list[pos] := x;
			INC(count)			
		END InsertUnlocked;

		(** Remove an object from the list. Remove may block if number of calls to Lock is bigger than the number of calls to Unlock *)
		PROCEDURE Remove*(pos: LONGINT);
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			ASSERT((pos >= 0) & (pos < count), 101);
			RemoveUnlocked(pos)
		END Remove;

		(* Does the actual Removing without locking (should already have been done by the caller) *)
		PROCEDURE RemoveUnlocked(pos: LONGINT);
		BEGIN
			WHILE pos < count - 1 DO
				list[pos] := list[pos + 1];
				INC(pos)
			END;
			DEC(count);
			list[count] := NIL
		END RemoveUnlocked;

		(** atomic replace x by y. That means that x is removed and y is added to the SortedList *)
		(*PROCEDURE Replace*(x, y: ANY);
		BEGIN {EXCLUSIVE}
			AWAIT(readLock = 0);
			RemoveUnlocked(x);
			AddUnlocked(y);
		END Replace;*)

	END List;
	
	LongintItem* = POINTER TO RECORD
		value: LONGINT;
	END;
	
	LongintList* = OBJECT
		VAR
			list: List;
			
		PROCEDURE &New*(options: SET);
		BEGIN
			NEW(list, Compare, options)
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
		
		PROCEDURE Lock*;
		BEGIN
			list.Lock
		END Lock;
		
		PROCEDURE Unlock*;
		BEGIN
			list.Unlock
		END Unlock;
				
		PROCEDURE Add*(x: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			list.Add(item)
		END Add;
		
		PROCEDURE Insert*(pos: LONGINT; x: LONGINT);
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			list.Insert(pos, item)
		END Insert;
		
		PROCEDURE Remove*(i: LONGINT);
		BEGIN
			list.Remove(i)
		END Remove;
		
		PROCEDURE IndexOf*(x: LONGINT): LONGINT;
		VAR
			item: LongintItem;
		BEGIN
			NEW(item);
			item.value := x;
			RETURN list.IndexOf(item)
		END IndexOf;
		
		PROCEDURE GetCount*(): LONGINT;
		BEGIN
			RETURN list.GetCount()
		END GetCount;
		
		PROCEDURE GetItem*(i: LONGINT): LONGINT;
		VAR
			item: ANY;
		BEGIN
			item := list.GetItem(i);
			RETURN item(LongintItem).value
		END GetItem;
			
	END LongintList;
	
	LongintListList* = OBJECT
		VAR
			list: List;
			
		PROCEDURE &New*(options: SET);
		BEGIN
			NEW(list, Compare, options)
		END New;
		
		PROCEDURE Compare(first, second: ANY): LONGINT;
		BEGIN
			RETURN CompareLongintLists(first(LongintList), second(LongintList))
		END Compare;
		
		PROCEDURE Lock*;
		BEGIN
			list.Lock
		END Lock;
		
		PROCEDURE Unlock*;
		BEGIN
			list.Unlock
		END Unlock;
				
		PROCEDURE Add*(x: LongintList);
		BEGIN
			list.Add(x)
		END Add;
			
		PROCEDURE Remove*(i: LONGINT);
		BEGIN
			list.Remove(i)
		END Remove;
		
		PROCEDURE IndexOf*(x: LongintList): LONGINT;
		BEGIN
			RETURN list.IndexOf(x)
		END IndexOf;
		
		PROCEDURE GetCount*(): LONGINT;
		BEGIN
			RETURN list.GetCount()
		END GetCount;
		
		PROCEDURE GetItem*(i: LONGINT): LongintList;
		VAR
			item: ANY;
		BEGIN
			item := list.GetItem(i);
			RETURN item(LongintList)
		END GetItem;
		
	END LongintListList;
	
	PROCEDURE CompareLongintLists*(itemFirst, itemSecond: LongintList): LONGINT;
	VAR
		n, i, nRes: LONGINT;
	BEGIN
		n := MIN(itemFirst.GetCount(), itemSecond.GetCount());
		IF n = 0 THEN
			IF itemFirst.GetCount() > 0 THEN
				RETURN 1
			ELSIF itemSecond.GetCount() > 0 THEN
				RETURN -1
			ELSE
				RETURN 0
			END
		ELSE
			i := 0; nRes := 0;
			WHILE (i < n) & (nRes = 0) DO
				IF itemFirst.GetItem(i) < itemSecond.GetItem(i) THEN
					nRes := -1
				ELSIF itemFirst.GetItem(i) > itemSecond.GetItem(i) THEN
					nRes := 1
				ELSE
					nRes := 0
				END;
				INC(i)
			END;
			IF nRes # 0 THEN
				RETURN nRes
			ELSIF itemFirst.GetCount() > n THEN
				RETURN 1
			ELSIF itemSecond.GetCount() > n THEN
				RETURN -1
			ELSE
				RETURN 0
			END
		END
	END CompareLongintLists;

END Lists.

