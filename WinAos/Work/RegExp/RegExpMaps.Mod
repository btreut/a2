MODULE RegExpMaps; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Map container classes for use in RegExp engine"; *)

IMPORT
	Lists;
	
TYPE
	
	DFAStateNumMapItem = POINTER TO DFAStateNumMapItemDesc;
	DFAStateNumMapItemDesc* = RECORD
		lstStates: Lists.LongintList;
		iState-: LONGINT;
	END;
	
	DFAStateNumMap* = OBJECT
		VAR
			list: Lists.List;
			
		PROCEDURE &New*(options: SET);
		BEGIN
			NEW(list, Compare, options)
		END New;
		
		PROCEDURE Compare(anyFirst, anySecond: ANY): LONGINT;
		BEGIN
			RETURN Lists.CompareLongintLists(
				anyFirst(DFAStateNumMapItem)^.lstStates,
				anySecond(DFAStateNumMapItem)^.lstStates)
		END Compare;
		
		PROCEDURE Lock*;
		BEGIN
			list.Lock
		END Lock;
		
		PROCEDURE Unlock*;
		BEGIN
			list.Unlock
		END Unlock;
				
		PROCEDURE Add*(lstStates: Lists.LongintList; iState: LONGINT);
		VAR
			item: DFAStateNumMapItem;
		BEGIN
			NEW(item);
			item^.lstStates := lstStates;
			item^.iState := iState;
			list.Add(item)
		END Add;
			
		PROCEDURE Remove*(i: LONGINT);
		BEGIN
			list.Remove(i)
		END Remove;
		
		PROCEDURE IndexOf*(x: Lists.LongintList): LONGINT;
		VAR
			item: DFAStateNumMapItem;
		BEGIN
			NEW(item);
			item^.lstStates := x;
			RETURN list.IndexOf(item)
		END IndexOf;
		
		PROCEDURE GetCount*(): LONGINT;
		BEGIN
			RETURN list.GetCount()
		END GetCount;
		
		PROCEDURE GetItem*(i: LONGINT): DFAStateNumMapItemDesc;
		VAR
			item: ANY;
		BEGIN
			item := list.GetItem(i);
			RETURN item(DFAStateNumMapItem)^
		END GetItem;
			
	END DFAStateNumMap;
	
	Transition* = RECORD
		iState-: LONGINT;
		iData-: LONGINT;
	END;
	
	TransitionMapItem = POINTER TO TransitionMapItemDesc;
	TransitionMapItemDesc* = RECORD
		trans-: Transition;
		iState-: LONGINT;
	END;
	
	TransitionMap* = OBJECT
		VAR
			list: Lists.List;
			
		PROCEDURE &New*(options: SET);
		BEGIN
			NEW(list, Compare, options)
		END New;
		
		PROCEDURE Compare(anyFirst, anySecond: ANY): LONGINT;
		VAR
			itemFirst, itemSecond: TransitionMapItem;
		BEGIN
			itemFirst := anyFirst(TransitionMapItem);
			itemSecond := anySecond(TransitionMapItem);
			IF itemFirst.trans.iState < itemSecond.trans.iState THEN
				RETURN -1
			ELSIF itemFirst.trans.iState > itemSecond.trans.iState THEN
				RETURN 1
			ELSE
				IF itemFirst.trans.iData < itemSecond.trans.iData THEN
					RETURN -1
				ELSIF itemFirst.trans.iData > itemSecond.trans.iData THEN
					RETURN 1
				ELSE
					RETURN 0
				END
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
				
		PROCEDURE Add*(CONST trans: Transition; iState: LONGINT);
		VAR
			item: TransitionMapItem;
		BEGIN
			NEW(item);
			item^.trans := trans;
			item^.iState := iState;
			list.Add(item)
		END Add;
			
		PROCEDURE Remove*(i: LONGINT);
		BEGIN
			list.Remove(i)
		END Remove;
		
		PROCEDURE IndexOf*(CONST x: Transition): LONGINT;
		VAR
			item: TransitionMapItem;
		BEGIN
			NEW(item);
			item^.trans := x;
			RETURN list.IndexOf(item)
		END IndexOf;
		
		PROCEDURE GetCount*(): LONGINT;
		BEGIN
			RETURN list.GetCount()
		END GetCount;
		
		PROCEDURE GetItem*(i: LONGINT): TransitionMapItemDesc;
		VAR
			item: ANY;
		BEGIN
			item := list.GetItem(i);
			RETURN item(TransitionMapItem)^
		END GetItem;
			
	END TransitionMap;
	
	PROCEDURE NewTransition*(iState, iData: LONGINT): Transition;
	VAR
		x: Transition;
	BEGIN
		x.iState := iState;
		x.iData := iData;
		RETURN x
	END NewTransition;
	
END RegExpMaps.

