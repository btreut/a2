MODULE RegExpNFA; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Nondeterministic Finite Automaton (NFA) class.
	Thompson's construction algorithm implementation"; *)

(*
// This code is in the public domain - feel free to do anything you 
// wish with it.
//
// Eli Bendersky (spur4444@yahoo.com)
//
*)

IMPORT
	Commands, Lists;

CONST
	NODE_TYPE_NONE* = 0;
	NODE_TYPE_EPS* = -1;
	NODE_TYPE_DATA* = 1;

TYPE
	
	Table = POINTER TO ARRAY OF ARRAY OF
		RECORD
			iType-: SHORTINT;
			iData-: LONGINT;
		END;

	NFA* = OBJECT
		VAR
			aTable-: Table;
			nSize-, iInitial-, iFinal-: LONGINT;
			lstInputs-: Lists.LongintList;
	
		PROCEDURE &New*(nSize: LONGINT; iInitial, iFinal: LONGINT);
		VAR
			iFrom, iTo: LONGINT;
		BEGIN
			SELF.nSize := nSize;
			SELF.iInitial := iInitial;
			SELF.iFinal := iFinal;
			NEW(lstInputs, {Lists.LIST_SORTED, Lists.LIST_NO_DUPLICATES});
			NEW(aTable, nSize, nSize);
			FOR iFrom := 0 TO nSize - 1 DO
				FOR iTo := 0 TO nSize - 1 DO
					aTable[iFrom, iTo].iType := NODE_TYPE_NONE
				END
			END
		END New;

		PROCEDURE IsLegalState(iState: LONGINT): BOOLEAN;
		BEGIN
			RETURN (iState >= 0) & (iState < nSize)
		END IsLegalState;
		
		PROCEDURE AddTrans(iFrom, iTo: LONGINT; iType: SHORTINT; iData: LONGINT);
		BEGIN 
			ASSERT(IsLegalState(iFrom));
			ASSERT(IsLegalState(iTo));
			aTable[iFrom, iTo].iType := iType;
			aTable[iFrom, iTo].iData := iData;
			IF (iType = NODE_TYPE_DATA) & (lstInputs.IndexOf(iData) = -1) THEN
				lstInputs.Add(iData)
			END
		END AddTrans;
		
		PROCEDURE ShiftStates(iShift: LONGINT);
		VAR
			nNewSize, iFrom, iTo: LONGINT;
			aNewTable: Table;
		BEGIN
			nNewSize := nSize + iShift;
			IF nNewSize < 1 THEN
				RETURN
			END;
			NEW(aNewTable, nNewSize, nNewSize);
			FOR iFrom := 0 TO nNewSize - 1 DO
				FOR iTo := 0 TO nNewSize - 1 DO
					IF (iFrom < nSize) & (iTo < nSize) THEN
						aNewTable[iFrom, iTo] := aTable[iFrom, iTo]
					ELSE
						aNewTable[iFrom, iTo].iType := NODE_TYPE_NONE
					END
				END
			END;
			(* copy all the transitions to the new table, at their
			new locations 	*)
			FOR iFrom := 0 TO nSize - 1 DO
				FOR iTo := 0 TO nSize - 1 DO
					aNewTable[iFrom + iShift, iTo + iShift] := aTable[iFrom, iTo]
				END
			END;
			(* update the NFA members *)
			nSize := nNewSize;
			INC(iInitial, iShift);
			INC(iFinal, iShift);
			aTable := aNewTable
		END ShiftStates;

		PROCEDURE FillStates(nfaOther: NFA);
		VAR
			iFrom, iTo, i: LONGINT;
		BEGIN
			ASSERT(nfaOther.nSize <= nSize);
			FOR iFrom := 0 TO nfaOther.nSize - 1 DO
				FOR iTo := 0 TO nfaOther.nSize - 1 DO
					aTable[iFrom, iTo] := nfaOther.aTable[iFrom, iTo]
				END
			END;
			FOR i := 0 TO nfaOther.lstInputs.GetCount() - 1 DO
				IF lstInputs.IndexOf(nfaOther.lstInputs.GetItem(i)) = -1 THEN
					lstInputs.Add(nfaOther.lstInputs.GetItem(i))
				END
			END
		END FillStates;

		PROCEDURE AppendEmptyState;
		VAR
			nNewSize, iFrom, iTo: LONGINT;
			aNewTable: Table;
		BEGIN
			nNewSize := nSize + 1;
			NEW(aNewTable, nNewSize, nNewSize);
			FOR iFrom := 0 TO nNewSize - 1 DO
				FOR iTo := 0 TO nNewSize - 1 DO
					IF (iFrom < nSize) & (iTo < nSize) THEN
						aNewTable[iFrom, iTo] := aTable[iFrom, iTo]
					ELSE
						aNewTable[iFrom, iTo].iType := NODE_TYPE_NONE
					END
				END
			END;
			nSize := nNewSize;
			aTable := aNewTable
		END AppendEmptyState;
		
		PROCEDURE Show*(context: Commands.Context);
		VAR
			iFrom, iTo, i: LONGINT;
		BEGIN
			context.out.Ln;
			context.out.String("This NFA has ");
			context.out.Int(nSize, 0);
			context.out.String(" states: 0 - ");
			context.out.Int(nSize - 1, 0);
			context.out.Ln;
			context.out.String("The initial state is ");
			context.out.Int(iInitial, 0);
			context.out.Ln;
			context.out.String("The final state is ");
			context.out.Int(iFinal, 0);
			context.out.Ln;
			context.out.String("Inputs: ");
			FOR i := 0 TO lstInputs.GetCount() - 1 DO
				context.out.Char("'");
				context.out.Char(CHR(lstInputs.GetItem(i)));
				context.out.String("' ")
			END;
			context.out.Ln;
			FOR iFrom := 0 TO nSize - 1 DO
				FOR iTo := 0 TO nSize - 1 DO
					IF aTable[iFrom, iTo].iType # NODE_TYPE_NONE THEN
						context.out.String("Transition from ");
						context.out.Int(iFrom, 0);
						context.out.String(" to ");
						context.out.Int(iTo, 0);
						context.out.String(" on input ");
						IF aTable[iFrom, iTo].iType = NODE_TYPE_EPS THEN
							context.out.String("EPS");
							context.out.Ln
						ELSE
							context.out.Char("'");
							context.out.Char(CHR(aTable[iFrom, iTo].iData));
							context.out.Char("'");
							context.out.Ln
						END
					END
				END
			END
		END Show;

	END NFA;

	(* NFA building functions
	Using Thompson Construction, build NFAs from basic inputs or 
	compositions of other NFAs. *)

	(* Builds a basic, single input NFA *)
	PROCEDURE BuildNFABasic*(iType: SHORTINT; iData: LONGINT): NFA;
	VAR
		nfaBasic: NFA;
	BEGIN
		NEW(nfaBasic, 2, 0, 1);
		nfaBasic.AddTrans(0, 1, iType, iData);
		RETURN nfaBasic
	END BuildNFABasic;
	
	(* Builds an alternation of nfa1 and nfa2 (nfa1|nfa2) *)
	PROCEDURE BuildNFAAlter*(nfa1, nfa2: NFA): NFA;
	VAR
		nfaNew: NFA;
	BEGIN
		(* How this is done: the new nfa must contain all the states in
		nfa1 and nfa2, plus a new initial and final states. 
		First will come the new initial state, then nfa1's states, then
		nfa2's states, then the new final state	*)
		(* make room for the new initial state *)
		nfa1.ShiftStates(1);
		(* make room for nfa1 *)
		nfa2.ShiftStates(nfa1.nSize);
		(* create a new nfa and initialize it with (the shifted) nfa2 *)
		NEW(nfaNew, nfa2.nSize, nfa2.iInitial, nfa2.iFinal);
		nfaNew.FillStates(nfa2);
		(* nfa1's states take their places in new_nfa *)
		nfaNew.FillStates(nfa1);
		(* Set new initial state and the transitions from it *)
		nfaNew.AddTrans(0, nfa1.iInitial, NODE_TYPE_EPS, 0);
		nfaNew.AddTrans(0, nfa2.iInitial, NODE_TYPE_EPS, 0);
		nfaNew.iInitial := 0;
		(* Make up space for the new final state *)
		nfaNew.AppendEmptyState;
		(* Set new final state *)
		nfaNew.iFinal := nfaNew.nSize - 1;
		nfaNew.AddTrans(nfa1.iFinal, nfaNew.iFinal, NODE_TYPE_EPS, 0);
		nfaNew.AddTrans(nfa2.iFinal, nfaNew.iFinal, NODE_TYPE_EPS, 0);	
		RETURN nfaNew
	END BuildNFAAlter;
	
	(* Builds a concatenation of nfa1 and nfa2 (nfa1nfa2) *)
	PROCEDURE BuildNFAConcat*(nfa1, nfa2: NFA): NFA;
	VAR
		nfaNew: NFA;
	BEGIN
		(* How this is done: First will come nfa1, then nfa2 (its 
		initial state replaced with nfa1's final state) 	*)
		nfa2.ShiftStates(nfa1.nSize - 1);
		(* create a new nfa and initialize it with (the shifted) nfa2 *)
		NEW(nfaNew, nfa2.nSize, nfa2.iInitial, nfa2.iFinal);
		nfaNew.FillStates(nfa2);
		(* nfa1's states take their places in nfaNew
		note: nfa1's final state overwrites nfa2's initial state,
		thus we get the desired merge automagically (the transition
		from nfa2's initial state now transits from nfa1's final state) *)
		nfaNew.FillStates(nfa1);
		(* set the new initial state (the final state stays nfa2's final state,
		and was already copied) *)
		nfaNew.iInitial := nfa1.iInitial;
		RETURN nfaNew
	END BuildNFAConcat;
	
	(* Builds a star (kleene closure) of nfa (nfa* ) *)
	PROCEDURE BuildNFAStar*(nfa: NFA): NFA;
	BEGIN
		(* How this is done: First will come the new initial state,
		then nfa, then the new final state *)
		(* make room for the new initial state *)
		nfa.ShiftStates(1);
		(* make room for the new final state *)
		nfa.AppendEmptyState;
		(*add new transitions *)
		nfa.AddTrans(nfa.iFinal, nfa.iInitial, NODE_TYPE_EPS, 0);
		nfa.AddTrans(0, nfa.iInitial, NODE_TYPE_EPS, 0);
		nfa.AddTrans(nfa.iFinal, nfa.nSize - 1, NODE_TYPE_EPS, 0);
		nfa.AddTrans(0, nfa.nSize - 1, NODE_TYPE_EPS, 0);
		nfa.iInitial := 0;
		nfa.iFinal := nfa.nSize - 1;
		RETURN nfa
	END BuildNFAStar;

END RegExpNFA.
