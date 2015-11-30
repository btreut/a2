MODULE RegExpSubsetConstruct; (** AUTHOR "Yaroslav Romanchenko (SAGE)"; PURPOSE "Subset construction algorithm implementation"; *)

(*
// This code is in the public domain - feel free to do anything you 
// wish with it.
//
// Eli Bendersky (spur4444@yahoo.com)
//
*)

IMPORT
	Lists, RegExpMaps,
	RegExpNFA, RegExpDFA;

	PROCEDURE EpsClosure*(nfa: RegExpNFA.NFA; lstStates: Lists.LongintList): Lists.LongintList;
	VAR
		lstEpsClosure, lstUnchecked: Lists.LongintList;
		i, iFrom, iTo: LONGINT;
	BEGIN
		NEW(lstEpsClosure, {Lists.LIST_SORTED, Lists.LIST_NO_DUPLICATES});
		NEW(lstUnchecked, {});
		FOR i := 0 TO lstStates.GetCount() - 1 DO
			lstEpsClosure.Add(lstStates.GetItem(i));
			lstUnchecked.Add(lstStates.GetItem(i))
		END;
		WHILE lstUnchecked.GetCount() # 0 DO
			i := lstUnchecked.GetCount() - 1;
			iFrom := lstUnchecked.GetItem(i);
			lstUnchecked.Remove(i);
			FOR iTo := 0 TO nfa.nSize - 1 DO
				IF (nfa.aTable[iFrom, iTo].iType = RegExpNFA.NODE_TYPE_EPS) &
					(lstEpsClosure.IndexOf(iTo) = -1)
				THEN
					lstEpsClosure.Add(iTo);
					lstUnchecked.Add(iTo)
				END
			END
		END;
		RETURN lstEpsClosure
	END EpsClosure;
	
	PROCEDURE Move*(nfa: RegExpNFA.NFA; lstStates: Lists.LongintList; iData: LONGINT): Lists.LongintList;
	VAR
		lstResult: Lists.LongintList;
 		i, iFrom, iTo: LONGINT;
	BEGIN
		NEW(lstResult, {Lists.LIST_SORTED, Lists.LIST_NO_DUPLICATES});
		FOR i := 0 TO lstStates.GetCount() - 1 DO
			iFrom := lstStates.GetItem(i);
			FOR iTo := 0 TO nfa.nSize - 1 DO
				IF (nfa.aTable[iFrom, iTo].iType = RegExpNFA.NODE_TYPE_DATA) &
					(nfa.aTable[iFrom, iTo].iData = iData)
				THEN
					lstResult.Add(iTo)
				END
			END
		END;
		RETURN lstResult
	END Move;

	PROCEDURE SubsetConstruct*(nfa: RegExpNFA.NFA): RegExpDFA.DFA;
	VAR
		dfa: RegExpDFA.DFA;
		trans: RegExpMaps.Transition;
		lstlstMarked, lstlstUnmarked: Lists.LongintListList;
		mapDFAStateNum: RegExpMaps.DFAStateNumMap;
		lstNFAInitial, lstFirst, lstAState, lstNext: Lists.LongintList;
		iNewState, iInput, i: LONGINT;
		
		PROCEDURE gen_new_state(): LONGINT;
		BEGIN
			INC(iNewState);
			RETURN iNewState
		END gen_new_state;
		
	BEGIN
		NEW(dfa);
		NEW(lstNFAInitial, {});
		NEW(lstlstMarked, {Lists.LIST_SORTED, Lists.LIST_NO_DUPLICATES});
		NEW(lstlstUnmarked, {Lists.LIST_SORTED, Lists.LIST_NO_DUPLICATES});
		NEW(mapDFAStateNum, {Lists.LIST_SORTED, Lists.LIST_NO_DUPLICATES});
		iNewState := 0;
		lstNFAInitial.Add(nfa.iInitial);
		lstFirst := EpsClosure(nfa, lstNFAInitial);
		lstlstUnmarked.Add(lstFirst);
		dfa.iInitial := gen_new_state();
		mapDFAStateNum.Add(lstFirst, dfa.iInitial);
		WHILE lstlstUnmarked.GetCount() # 0 DO
			lstAState := lstlstUnmarked.GetItem(0);
			lstlstUnmarked.Remove(0);
			lstlstMarked.Add(lstAState);
			IF lstAState.IndexOf(nfa.iFinal) # -1 THEN
				i := mapDFAStateNum.IndexOf(lstAState);
				IF i # -1 THEN
					dfa.lstFinal.Add(mapDFAStateNum.GetItem(i).iState)
				END
			END;
			FOR iInput := 0 TO nfa.lstInputs.GetCount() - 1 DO
				lstNext := EpsClosure(nfa,
					Move(nfa, lstAState, nfa.lstInputs.GetItem(iInput)));
				IF (lstlstUnmarked.IndexOf(lstNext) = -1) &
					(lstlstMarked.IndexOf(lstNext) = -1)
				THEN
					lstlstUnmarked.Add(lstNext);
					mapDFAStateNum.Add(lstNext, gen_new_state())
				END;
				i := mapDFAStateNum.IndexOf(lstAState);
				IF i # -1 THEN
					trans := RegExpMaps.NewTransition(
						mapDFAStateNum.GetItem(i).iState,
						nfa.lstInputs.GetItem(iInput));
					i := mapDFAStateNum.IndexOf(lstNext);
					IF (i # -1) & (dfa.mapTransition.IndexOf(trans) = -1) THEN
						dfa.mapTransition.Add(trans,
							mapDFAStateNum.GetItem(i).iState)
					END
				END
			END 
		END;
		dfa.nStates := mapDFAStateNum.GetCount();
		RETURN dfa
	END SubsetConstruct;

END RegExpSubsetConstruct.

