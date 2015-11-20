MODULE UsbHidParser; (** AUTHOR "ottigerm"; PURPOSE "HID Items parser with error codes" *)
(**
 * Bluebottle USB HID Items Module
 *
 * This is the module providing item parsing as described in Device Class Definition for HID Version 1.11
 *
 * Overview:
 *
 *	Main Items		As described on page 28
 *	Global Items	As described on page 35
 *	Local Items		As described on page 39
 *
 * History:
 *
 *	02.06.2006	History started (ottigerm)
 *	27.09.2006	Version 1.0
 *)

IMPORT  SYSTEM, KernelLog, UsbHid, Usbdi, UsbHidErrors, HidParserExt := UsbHidParserExt, UsbHidReport;

CONST

	Trace*							= 	FALSE;
	Debug*							= 	FALSE;

	ShortItemBTypeMain 			= 	0H;
	ShortItemBTypeGlobal 			= 	1H;
	ShortItemBTypeLocal 			= 	2H;
	ShortItemBTypeReserved		= 	3H;

	UndefinedState* 				= 	UsbHidReport.UndefinedState;

	StatusCodeOk* 					=   	1;
	StatusCodeFailed*				=   	0;

	(*Enum for global state*)
	IDUsagePage					=   	HidParserExt.ParseIDUsagePage;
	IDLogicalMinimum				=   	HidParserExt.ParseIDLogicalMinimum;
	IDLogicalMaximum				=   	HidParserExt.ParseIDLogicalMaximum;
	IDPhysicalMinimum 				=   	HidParserExt.ParseIDPhysicalMinimum;
	IDPhysicalMaximum 			=   	HidParserExt.ParseIDPhysicalMaximum;
	IDUnitExponent					=   	HidParserExt.ParseIDUnitExponent;
	IDUnit							=   	HidParserExt.ParseIDUnit;
	IDReportSize					=   	HidParserExt.ParseIDReportSize;
	IDReportID						=   	HidParserExt.ParseIDReportID;
	IDReportCount					=   	HidParserExt.ParseIDReportCount;
	LengthGlobalState				=  	10;

	(*Enum for local state*)
	IDLocalUsage					=  	HidParserExt.ParseIDUsage;
	IDLocalUsageMinimum			=   	HidParserExt.ParseIDUsageMinimum;
	IDLocalUsageMaximum			=   	HidParserExt.ParseIDUsageMaximum;
	IDLocalDesignatorIndex			=   	HidParserExt.ParseIDDesignatorIndex;
	IDLocalDesignatorMinimum		=   	HidParserExt.ParseIDDesignatorMinimum;
	IDLocalDesignatorMaximum		=   	HidParserExt.ParseIDDesignatorMaximum;
	IDLocalStringIndex 				=   	HidParserExt.ParseIDStringIndex-1;
	IDLocalStringMinimum			=   	HidParserExt.ParseIDStringMinimum-1;
	IDLocalStringMaximum			=   	HidParserExt.ParseIDStringMaximum-1;
	IDLocalDelimiter				=   	HidParserExt.ParseIDDelimiter-1;
	LengthLocalState				=  	10;
	IDLocalExtUsage				=   	HidParserExt.ParseIDUsage;
	IDLocalExtUsageMinimum		=   	HidParserExt.ParseIDUsageMinimum;
	IDLocalExtUsageMaximum		=   	HidParserExt.ParseIDUsageMaximum;
	LengthExtLocalState			=   	3;
	IDLocalAddStringIndex			=   	4;

	(*Main state*)
	IDMainIsConstant*				= 	HidParserExt.ParseIDDataConstant;
	IDMainIsVariable*				= 	HidParserExt.ParseIDArrayVariable;
	IDMainIsRelative*				= 	HidParserExt.ParseIDAbsoluteRelative;
	IDMainIsWrap*					= 	HidParserExt.ParseIDNoWrapWrap;
	IDMainIsNonLinear*				= 	HidParserExt.ParseIDLinearNonLinear;
	IDMainIsNoPreferred*			= 	HidParserExt.ParseIDPreferdStateNoPreferd;
	IDMainIsNullState*				= 	HidParserExt.ParseIDNoNullPositionNullState;
	IDMainIsVolatile*				= 	HidParserExt.ParseIDNonVolatileVolatile;
	IDMainIsBufferedBytes*			= 	HidParserExt.ParseIDBitFieldBufferedByte;

	(*Main item tag*)
	IDMainItemInput				=	08H;
	IDMainItemOutput				=	09H;
	IDMainItemFeature				=	0BH;
	IDMainItemCollection			=	0AH;
	IDMainItemEndCollection		=	0CH;

TYPE

	(*as defined in device class definition for HID Version 1.11, p. 26, 6.2.2 ShortItems*)
	Item = RECORD
		bSize : LONGINT;	(*bit 0,1: size of data*)
		bType : LONGINT;	(*bit 2,3: Main, Global, Local or Reserved(Longitem) Type*)
		bTag : LONGINT;	(*bit 4-7: index in the main, global or local tag table*)
		data : LONGINT;		(*data to read after byte 0 depending on bSize*)
	END;

	(*holding the main state*)
	MainState  =  LONGINT;

	(*holding the state of all possible global states*)
	GlobalState = POINTER TO RECORD
		(*UsagePage, Logical Min, Logical Max, Physical Min, Physical Max, Unit Exp, Unit, ReportSize, ReportID, ReportCount*)
		state : ARRAY LengthGlobalState OF LONGINT;
		(*for detecting erros in the hid descriptor*)
		isReadByMain : ARRAY LengthGlobalState OF BOOLEAN;
		(*used when Push or Pop item is found. Push puts the actual global state at the beginning of the list; pop gets the first list item*)
		next : GlobalState;
	END;

	LocalState = POINTER TO RECORD
		(*Usage, Usage Min, Usage Max, Designator Index, Designator Maximum, String Index, String Minimum, String Maximum, Delimiter*)
		state : ARRAY LengthLocalState 	OF LONGINT;
		(*for detecting errors in the hid descriptor; usage Min and usage Max can have extensions*)
		ext 	: ARRAY LengthExtLocalState OF LONGINT;
	END;

	UsageQueueItem = POINTER TO RECORD
		usage : LONGINT;
		usagePage : LONGINT;
		arrLen : LONGINT;
		next : UsageQueueItem;
	END;

	PtrToUsageTupleArr = UsbHidReport.PtrToUsageTupleArr;

	(*Linked list for managing holding usages: there can be multiple usages between main items, so we need a dynamic datatype*)
	UsageQueue=OBJECT
	VAR
		first, last : UsageQueueItem;
		totalLen : LONGINT;

		(*adds the usage[0..arrLen-1] to the end of HIDUsageQueue
		* 	param:	usage	the usage to add
		*			arrLen	if more usages, the total number of usages
		*			usageExt	the usagePage
		*)
		PROCEDURE Add*(usage,  arrLen, usageExt: LONGINT);
		BEGIN
			(*empty list*)
			IF (last = NIL) THEN
				NEW(last);
				first := last;
			ELSE
				NEW(last.next);
				last := last.next;
			END;
			last.usage := usage;
			last.usagePage := usageExt;
			last.arrLen:= arrLen;
			totalLen:= totalLen + arrLen;
		END Add;

		(*returns an UsbHidReport.UsageDictionary
		*	param:
		* 	return: UsbHidReport.UsageDictionary
		*)
		PROCEDURE CreateUsageDictionary():UsbHidReport.UsageDictionary;
		VAR
			cursor:					UsageQueueItem;
			usageQueueCounter, i:	LONGINT;
			dict:					UsbHidReport.UsageDictionary;
		BEGIN
			(*first count the length of usageQueue*)
			cursor := first;
			WHILE (cursor # NIL) DO
				cursor := cursor.next;
				usageQueueCounter :=  usageQueueCounter + 1;
			END;
			IF (usageQueueCounter>0) THEN
				NEW(dict);
				NEW(dict.elements,usageQueueCounter);
				cursor := first;
				FOR i:= 0 TO usageQueueCounter-1 DO
					dict.elements[i].firstUsageID 	:= cursor.usage;
					dict.elements[i].otherUsagePage	:= cursor.usagePage;
					dict.elements[i].nofFollowing 	:= cursor.arrLen-1;
					cursor := cursor.next;
				END;
				(*KernelLog.String("added usageDictionary with "); KernelLog.Int(usageQueueCounter,0); KernelLog.String(" elements."); KernelLog.Ln;*)
			END;
			RETURN dict;
		END CreateUsageDictionary;

		(*returns an array of usageTuples
		*	param: the number of elements wanted in the array
		* 	return: pointer to the usage tuple array
		*)
		PROCEDURE CreateUsageTupleArray(reportCount: LONGINT; isArrayFlagSet:BOOLEAN): PtrToUsageTupleArr ;
		VAR
			i,index:		LONGINT;
			cursor:		UsageQueueItem;
			usageArr : 	PtrToUsageTupleArr ;
		BEGIN
			IF(totalLen>0) THEN
				NEW(usageArr, reportCount);
				cursor := first;
				index := 0;
				WHILE(cursor#NIL) DO
					FOR i:=0 TO cursor.arrLen-1 DO
						NEW(usageArr[index]);
						IF UsbHidReport.UseUsageDictionaryExt THEN
							(*depending on the array flag, we cannot predict the usageId, because the usageId will be and not the usageValue*)
							IF isArrayFlagSet THEN
								usageArr[index].usageID := UndefinedState;
							ELSE
								usageArr[index].usageID := cursor.usage+i;
							END;
						ELSE
							usageArr[index].usageID := cursor.usage+i;
						END;
						IF UsbHidReport.Debug THEN
							KernelLog.String("Created usage entry for usage "); KernelLog.Int(usageArr[index].usageID,0); KernelLog.Ln;
						END;
						IF (index>=reportCount-1) THEN
							RETURN usageArr;
						END;
						index := index + 1;
					END;

					(*if report count greater than the total of usages, we have to fill up the
						reportCount - usagesFilledUp usages with the last usage id+1, +2 +3, ...*)
					IF((cursor.next=NIL)&(reportCount>index)) THEN
						i:=0;
						WHILE(index<reportCount) DO
							NEW(usageArr[index]);
							usageArr[index].usageID := cursor.usage + cursor.arrLen+i;
							i := i + 1;
							index := index+1;
							IF Debug THEN
								KernelLog.String('UsbHidParser:CreateUsageTupleArray: reportCount>usages, fill up with usage '); KernelLog.Int(cursor.usage+cursor.arrLen+i-1,0);
								KernelLog.Ln;
							END;
						END;
					END;
					cursor := cursor.next;
				END;
			ELSE
				RETURN NIL;
			END;
			RETURN usageArr;
		END CreateUsageTupleArray;

		(*reset the usage queue *)
		PROCEDURE EmptyUsageQueue;
		BEGIN
			first:=NIL;
			last:=NIL;
			totalLen:= 0;
		END EmptyUsageQueue;

		PROCEDURE &Init*;
		BEGIN
			totalLen := 0;
		END Init;

	END UsageQueue;

TYPE

	(*managing the global state*)
	GlobalStateObject* = OBJECT
	VAR
		firstGlobalState, globalState, gsCursor 	: GlobalState;

		(*returns the actual state of globalState
		* 	param: i	the i th globalState, f.e. 0 means UsagePage
		* 	return: globalState [i]
		*)
		PROCEDURE State(i:SHORTINT):LONGINT;
		BEGIN
			IF ((i>=0) & (i < LengthGlobalState)) THEN
				RETURN globalState.state[i];
			ELSE
				RETURN UndefinedState;
			END;
		END State;

		(*push globalState on the stack, the new globalState is empty *)
		PROCEDURE Push;
		VAR i : LONGINT;
		BEGIN
			NEW(globalState.next);
			(*assign all values from globalState to globalState.next*)
			FOR i:= 0 TO LengthGlobalState-1 DO
				globalState.next.state[i] := globalState.state[i];
				globalState.next.isReadByMain[i] := globalState.isReadByMain[i];
			END;
			globalState:=globalState.next;
		END Push;

		(*pop globalState from stack and overwrites the current one *)
		PROCEDURE Pop():BOOLEAN;
		BEGIN
			IF(globalState=firstGlobalState) THEN
				RETURN FALSE;
			ELSE
				gsCursor := firstGlobalState;
				WHILE (gsCursor.next # globalState) DO
					gsCursor := gsCursor.next;
				END;
				globalState := gsCursor;
				globalState.next := NIL;
				RETURN TRUE;
			END;
		END Pop;

		(*deletes the global state
		 * 	param: data		the global state
		*)
		PROCEDURE CleanGlobalState(data: GlobalState);
		BEGIN
			data.state[IDUsagePage]:= 			UndefinedState;
			data.state[IDLogicalMinimum]:= 		UndefinedState;
			data.state[IDLogicalMaximum]:= 	UndefinedState;
			data.state[IDPhysicalMinimum]:= 	UndefinedState;
			data.state[IDPhysicalMaximum]:= 	UndefinedState;
			data.state[IDUnitExponent]:= 		UndefinedState;
			data.state[IDUnit]:= 				UndefinedState;
			data.state[IDReportSize]:= 			UndefinedState;
			data.state[IDReportID]:= 			UndefinedState;
			data.state[IDReportCount]:= 		UndefinedState;

			data.isReadByMain[IDUsagePage]:= 			FALSE;
			data.isReadByMain[IDLogicalMinimum]:= 	FALSE;
			data.isReadByMain[IDLogicalMaximum]:= 	FALSE;
			data.isReadByMain[IDPhysicalMinimum]:= 	FALSE;
			data.isReadByMain[IDPhysicalMaximum]:= 	FALSE;
			data.isReadByMain[IDUnitExponent]:= 		FALSE;
			data.isReadByMain[IDUnit]:= 				FALSE;
			data.isReadByMain[IDReportSize]:= 			FALSE;
			data.isReadByMain[IDReportID]:= 			FALSE;
			data.isReadByMain[IDReportCount]:= 		FALSE;

			data.next:=									NIL;
		END CleanGlobalState;

		(*sets the globalState field to newValue
		*   adds GlobalItemsGeneral GlobalItemRedundantlyDeclared error to errorList, if field is already declared with newValue
		*   itemNr is the index of the current parsing item
		* 	param: 	errorList			where to send detected error
		*			globalStateField		the indext on the globalState table
		*			newValue			the value to insert at position globalStateField in the globalState
		*			itemNr				used for errorList; to store information at which item an error detected, when found
		*)
		PROCEDURE SetState( VAR errorList: UsbHidErrors.ErrorList; globalStateField: LONGINT; newValue, itemNr:LONGINT);
		BEGIN
			IF((globalStateField<0) OR (globalStateField>LengthGlobalState)) THEN
				RETURN;
			END;
			IF(globalState.isReadByMain[globalStateField]=FALSE) THEN
				globalState.isReadByMain[globalStateField]:= TRUE;
				globalState.state[globalStateField] := newValue;
			ELSE
				(*ERROR already defined*)
				errorList.Add(itemNr, UsbHidErrors.GlobalItemGeneral, 0H);
			END;
		END SetState;

		(*resets all states in the global state*)
		PROCEDURE ResetGlobalStateFlags;
		VAR i : LONGINT;
		BEGIN
			FOR i:=0 TO LengthGlobalState-1 DO
				globalState.isReadByMain[i]:=FALSE;
			END;
		END ResetGlobalStateFlags;

		(*checks the global state and generates error messages, must only be called by ParseMainItem
		 * 	errorList			where to send detected error
		 	itemNr				used for errorList; to store information at which item an error detected, when found
		* 	return: 				FALSE,	if system can not continue because of fatal errors
		*						TRUE,	otherwise
		*)
		PROCEDURE VerifyGlobalState( VAR errorList: UsbHidErrors.ErrorList; itemNr: LONGINT):BOOLEAN;
		VAR
			minReportSize, maxReportSize: 	LONGINT;
			mustStop:						BOOLEAN;
		BEGIN
			mustStop:= FALSE;

			IF((globalState.state[IDUsagePage] = UndefinedState) OR
					(globalState.state[IDLogicalMinimum] = UndefinedState) OR
					(globalState.state[IDLogicalMaximum] = UndefinedState) OR
					(globalState.state[IDReportSize] = UndefinedState) OR
					(globalState.state[IDReportCount] = UndefinedState)) THEN
				errorList.Add(itemNr, UsbHidErrors.MainItemInput, 0H);
				mustStop:=TRUE;
			END;

			IF((globalState.state[IDPhysicalMinimum]#UndefinedState)OR(globalState.state[IDPhysicalMaximum]#UndefinedState)) THEN
				IF(globalState.state[IDPhysicalMaximum]=UndefinedState) THEN
					errorList.Add(itemNr, UsbHidErrors.GlobalItemPhysicalMinimum, 0H);
				END;
				IF(globalState.state[IDPhysicalMinimum]=UndefinedState) THEN
					errorList.Add(itemNr, UsbHidErrors.GlobalItemPhysicalMaximum, 0H);
				END;
			END;

			IF((globalState.state[IDReportSize]>0) & (globalState.state[IDReportSize]<=32)) THEN
				(*logicalMinimum and logicalMaximum must not exceed 4 bytes, so the reportSize must be in [1,32]*)
				minReportSize:=1;
				maxReportSize:=LSH(minReportSize,globalState.state[IDReportSize]);
				IF((globalState.state[IDLogicalMaximum]-globalState.state[IDLogicalMinimum])>=maxReportSize) THEN
					errorList.Add(itemNr, UsbHidErrors.GlobalItemLogicalMinimum, 0);
					errorList.Add(itemNr, UsbHidErrors.GlobalItemLogicalMaximum, 0);
				END;
			END;
			RETURN mustStop;
		END VerifyGlobalState;

		(*for debugging uses*)
		PROCEDURE PrintGlobalState*(data: GlobalState);
		BEGIN
			KernelLog.String("local state table:"); KernelLog.Ln;
			KernelLog.String("data.state[IDUsagePage]: "); 			KernelLog.Int(data.state[IDUsagePage],0); 			KernelLog.Ln;
			KernelLog.String("data.state[IDLogicalMinimum]: "); 	KernelLog.Int(data.state[IDLogicalMinimum],0); 	KernelLog.Ln;
			KernelLog.String("data.state[IDLogicalMaximum]: "); 	KernelLog.Int(data.state[IDLogicalMaximum],0); 	KernelLog.Ln;
			KernelLog.String("data.state[IDPhysicalMinimum]: "); 	KernelLog.Int(data.state[IDPhysicalMinimum],0); 	KernelLog.Ln;
			KernelLog.String("data.state[IDPhysicalMaximum]: "); 	KernelLog.Int(data.state[IDPhysicalMaximum],0); 	KernelLog.Ln;
			KernelLog.String("data.state[IDUnitExponent]: "); 		KernelLog.Int(data.state[IDUnitExponent],0); 		KernelLog.Ln;
			KernelLog.String("data.state[IDUnit]: "); 				KernelLog.Int(data.state[IDUnit],0); 				KernelLog.Ln;
			KernelLog.String("data.state[IDReportSize]: "); 			KernelLog.Int(data.state[IDReportSize],0); 			KernelLog.Ln;
			KernelLog.String("data.state[IDReportID]: "); 			KernelLog.Int(data.state[IDReportID],0); 			KernelLog.Ln;
			KernelLog.String("data.state[IDReportCount]: "); 		KernelLog.Int(data.state[IDReportCount],0); 		KernelLog.Ln;
			KernelLog.Ln;
		END PrintGlobalState;

	BEGIN
		NEW(globalState);
		firstGlobalState := globalState;
		CleanGlobalState(globalState);
		globalState.next := NIL;
	END GlobalStateObject;

TYPE

	(*managing the local state*)
	LocalStateObj*=OBJECT
	VAR
		localState	: LocalState;
		usageQueue: UsageQueue;

		(*returns the actual state of localState
		* 	param: i	the i th localState, f.e. 0 means Usage
		* 	return: localState [i]
		*)
		PROCEDURE State(i:LONGINT):LONGINT;
		BEGIN
			IF ((i>=0) & (i < LengthLocalState)) THEN
				RETURN localState.state[i];
			ELSE
				RETURN UndefinedState;
			END;
		END State;

		(*returns an UsbHidReport.UsageDictionary
		*	param:
		* 	return: UsbHidReport.UsageDictionary
		*)
		PROCEDURE CreateUsageDictionary(): UsbHidReport.UsageDictionary;
		BEGIN
			RETURN usageQueue.CreateUsageDictionary();
		END CreateUsageDictionary;

		(*return pointer to array of usageTuple
		*	param: reportCount	the number of usages to create totally
		* 	return: pointer to array of usageTuple
		*)
		PROCEDURE CreateUsageArray(reportCount: LONGINT;isArrayFlagSet:BOOLEAN): PtrToUsageTupleArr ;
		BEGIN
			RETURN usageQueue.CreateUsageTupleArray(reportCount,isArrayFlagSet);
		END CreateUsageArray;

		(* creates a usageQueueItem depending on LocalState(IDLocalUsageMinimum and IDLocalStateUsageMaximum) and when mainState has set flag
		* flag IsVariable to 1 then all the usages from UsageMinimum to UsageMaximum are added, means UsageMinimum,...UsageMaximum.
		* else only the first globalState.State(IDReportCount) from UsageMinimum beginning are created
		*        means UsageMinimum, UsageMinimum+1,...UsageMinimum+globalState.State(IDReportCount)-1.
		* please use verifyLocalState before using CreateUsageArray
		*	param:	mainState	the current main state
					globalState	globalState object holding the current globalState
		* 	return: 	pointer to array of usageTuple
		*)
		PROCEDURE AppendUsageMinMaxArray(mainState: MainState; globalState: GlobalStateObject);
		VAR
			usageMin, usageMax:	LONGINT;
			usageExt:				LONGINT;
			set:						SET;
		BEGIN
			(*depending on mainState[IDMainIsVariable] we do not have to allocate usageTuple for all usageMinimum to usageMaximum:
				so, if IDMainIsVariable=0 (means we have array fields and not variable fields) we only have to allocate ReportCount usageTuples*)
			set := SYSTEM.VAL(SET, mainState);
			usageMin := State(IDLocalUsageMinimum);
			usageMax := State(IDLocalUsageMaximum);
			usageExt:= Ext(IDLocalExtUsageMinimum);

			IF(IDMainIsVariable IN set) THEN
				IF ((usageMin#UndefinedState) & (usageMax#UndefinedState) & (usageMax>=usageMin)) THEN
					usageQueue.Add(usageMin, usageMax-usageMin+1, usageExt);
				ELSE
					(*Do not allocate anything, so the usageQueue is still empty*)
				END;
			ELSE
				IF ((usageMin#UndefinedState) & (usageMax#UndefinedState) & (usageMax>=usageMin)) THEN
					IF UsbHidReport.UseUsageDictionaryExt THEN
						usageQueue.Add(usageMin, usageMax-usageMin+1,usageExt);
					ELSE
						usageQueue.Add(usageMin,globalState.State(IDReportCount),usageExt);
					END;
				END;
				IF UsbHidReport.Debug THEN
					KernelLog.String("UsbHidParser::LocalStateObj.AppendUsageMinMaxArray:");
					KernelLog.String(" found Constant bit in mainState and added only ReportCount usageTuples");
					KernelLog.Ln;
				END;
			END;
		END AppendUsageMinMaxArray;

		(*set the actual state of localState[i]
		* 	param: 	i		the i th localState, f.e. 0 means Usage
					value 	the value to store at localState[i], the higher 16bits are stored as usagePage, if i is set to Usage/UsageMin or UsageMax
		*)
		PROCEDURE SetState(i, value:LONGINT);
		BEGIN
			IF ((i>=0) & (i < LengthLocalState)) THEN
				(*as described at page 41 32bit values for Usage only the lower 16bits identify the usage, the higher 16bits define the usage page*)
				CASE i OF
					IDLocalUsage:
						localState.state[i] := value MOD 10000H;
						SetExt(IDLocalExtUsage, value DIV 10000H);
						(*KernelLog.String("usage added"); KernelLog.Ln;*)
						usageQueue.Add(value MOD 10000H,1,value DIV 10000H);
					|IDLocalUsageMinimum:
						localState.state[i] := value MOD 10000H;
						SetExt(IDLocalExtUsageMinimum, value DIV 10000H);
						(*KernelLog.String("usage min"); KernelLog.Ln;*)
					|IDLocalUsageMaximum:
						localState.state[i] := value MOD 10000H;
						SetExt(IDLocalExtUsageMaximum, value DIV 10000H);
						(*KernelLog.String("usage max"); KernelLog.Ln;*)
					ELSE
						localState.state[i] := value;
				END
			END;
			IF(i=IDLocalUsage) THEN

			END;
		END SetState;

		(*get extention i of localState
		* 	param: 	i		index of extention
		*)
		PROCEDURE Ext(i:LONGINT):LONGINT;
		BEGIN
			IF ((i>=0) & (i < LengthExtLocalState)) THEN
				RETURN localState.ext[i];
			ELSE
				RETURN UndefinedState;
			END;
		END Ext;

		(*set extention i of localState
		* 	param: 	i		index of extention
		*			value	value to store at ext[i]
		*)
		PROCEDURE SetExt(i, value:LONGINT);
		BEGIN
			IF ((i>=0) & (i < LengthExtLocalState)) THEN
				localState.ext[i] := value;
			END;
		END SetExt;

		(*clean all states and extentions of localState*)
		PROCEDURE CleanLocalState;
		BEGIN
			localState.state[IDLocalUsage]:= 				UndefinedState;
			localState.state[IDLocalUsageMinimum]:= 		UndefinedState;
			localState.state[IDLocalUsageMaximum]:= 		UndefinedState;
			localState.state[IDLocalDesignatorIndex]:= 		UndefinedState;
			localState.state[IDLocalDesignatorMinimum]:= 	UndefinedState;
			localState.state[IDLocalDesignatorMaximum]:=	UndefinedState;
			localState.state[IDLocalStringIndex]:= 			UndefinedState;
			localState.state[IDLocalStringMinimum]:= 		UndefinedState;
			localState.state[IDLocalStringMaximum]:= 		UndefinedState;
			localState.state[IDLocalDelimiter]:= 				UndefinedState;

			localState.ext[IDLocalExtUsageMinimum]:= 		UndefinedState;
			localState.ext[IDLocalExtUsageMaximum]:= 		UndefinedState;
			usageQueue.EmptyUsageQueue();
		END CleanLocalState;

		(*print the local statem, for debugging uses
		* 	param: 	data	localState to print
		*)
		PROCEDURE PrintLocalState*(data: LocalState);
		BEGIN
			KernelLog.String("global state table:"); KernelLog.Ln;
			KernelLog.String("data.Usage: "); 				KernelLog.Int(data.state[IDLocalUsage],0); 					KernelLog.Ln;
			KernelLog.String("data.UsageMinimum: "); 		KernelLog.Int(data.state[IDLocalUsageMinimum],0); 		KernelLog.Ln;
			KernelLog.String("data.UsageMaximum: "); 	KernelLog.Int(data.state[IDLocalUsageMaximum],0); 		KernelLog.Ln;
			KernelLog.String("data.DesignatorIndex: "); 	KernelLog.Int(data.state[IDLocalDesignatorIndex],0); 		KernelLog.Ln;
			KernelLog.String("data.DesignatorMinimum: "); KernelLog.Int(data.state[IDLocalDesignatorMinimum],0); 	KernelLog.Ln;
			KernelLog.String("data.DesignatorMaximum: ");KernelLog.Int(data.state[IDLocalDesignatorMaximum],0); 	KernelLog.Ln;
			KernelLog.String("data.StringIndex: "); 			KernelLog.Int(data.state[IDLocalStringIndex],0); 			KernelLog.Ln;
			KernelLog.String("data.StringMinimum: "); 		KernelLog.Int(data.state[IDLocalStringMinimum],0);			KernelLog.Ln;
			KernelLog.String("data.StringMaximum: "); 	KernelLog.Int(data.state[IDLocalStringMaximum],0); 		KernelLog.Ln;
			KernelLog.String("data.Delimiter: "); 			KernelLog.Int(data.state[IDLocalDelimiter],0); 				KernelLog.Ln;
			KernelLog.String("ext.UsageMinimum: "); 		KernelLog.Int(data.ext[IDLocalExtUsageMinimum],0); 		KernelLog.Ln;
			KernelLog.String("data.UsageMaximum: "); 	KernelLog.Int(data.ext[IDLocalExtUsageMaximum],0);		KernelLog.Ln;
			KernelLog.Ln;
		END PrintLocalState;

		(*checks the local state and generates error messages, must only be called by ParseMainItem
		* 	param: 	errorList		where to send errors
		*			itemNr			for errorList; the current item number parsed
		*)
		PROCEDURE VerifyLocalState(VAR errorList: UsbHidErrors.ErrorList; itemNr: LONGINT);
		BEGIN
			IF(localState.state[IDLocalUsage]=UndefinedState) THEN
				(*check first if usageMinimum and usageMaximum is set*)
				IF((localState.state[IDLocalUsageMinimum]=UndefinedState)OR(localState.state[IDLocalUsageMaximum]=UndefinedState)) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemUsage,0H);
				END;
			END;

			(*only check if at least one of UsageMinimum and UsageMaximum is set*)
			IF ((localState.state[IDLocalUsageMinimum]#UndefinedState)OR(localState.state[IDLocalUsageMaximum]#UndefinedState)) THEN
				IF(localState.state[IDLocalUsageMinimum]=UndefinedState) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemUsageMaximum, 0H);
				END;
				IF(localState.state[IDLocalUsageMaximum]=UndefinedState) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemUsageMinimum, 0H);
				END;
				IF(localState.state[IDLocalUsageMinimum]>localState.state[IDLocalUsageMaximum]) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemUsageMaximum, 1H);
					errorList.Add(itemNr, UsbHidErrors.LocalItemUsageMinimum, 1H);
				END;
				IF(localState.ext[IDLocalExtUsageMinimum]#localState.ext[IDLocalExtUsageMaximum]) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemUsageMinimum, 3H);
					errorList.Add(itemNr, UsbHidErrors.LocalItemUsageMaximum, 2H);
				END;
			END;

			IF ((localState.state[IDLocalDesignatorMinimum]#UndefinedState)OR(localState.state[IDLocalDesignatorMaximum]#UndefinedState)) THEN
				IF(localState.state[IDLocalDesignatorMinimum]=UndefinedState) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemDesignatorMaximum, 0H);
				END;
				IF(localState.state[IDLocalDesignatorMaximum]=UndefinedState) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemDesignatorMinimum, 0H);
				END;
				IF(localState.state[IDLocalDesignatorMinimum]>localState.state[IDLocalDesignatorMaximum]) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemDesignatorMaximum, 1H);
					errorList.Add(itemNr, UsbHidErrors.LocalItemDesignatorMinimum, 1H);
				END;
			END;

			IF ((localState.state[IDLocalStringMinimum]#UndefinedState)OR(localState.state[IDLocalStringMaximum]#UndefinedState)) THEN
				IF(localState.state[IDLocalStringMinimum]=UndefinedState) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemStringMaximum, 0H);
				END;
				IF(localState.state[IDLocalStringMaximum]=UndefinedState) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemStringMinimum, 0H);
				END;
				IF(localState.state[IDLocalStringMinimum]>localState.state[IDLocalStringMaximum]) THEN
					errorList.Add(itemNr, UsbHidErrors.LocalItemStringMaximum, 1H);
					errorList.Add(itemNr, UsbHidErrors.LocalItemStringMinimum, 1H);
				END;
			END;
		END VerifyLocalState;

		PROCEDURE &Init*;
		BEGIN
			NEW(localState);
			NEW(usageQueue);
			CleanLocalState;
		END Init;

	END LocalStateObj;

	(* parses the hid descriptor, genererates error list*)
	ItemParser* = OBJECT
	VAR
		(** Initialized by USB driver before Connect() is called *)
		mainState								: MainState;
		globalState								: GlobalStateObject;
		localState 								: LocalStateObj;
		errorList*								: UsbHidErrors.ErrorList;
		inputOutputFeatureParsed				: BOOLEAN;
		depth									: LONGINT;
		reportManager							: UsbHidReport.HidReportManager;

		(*	converts an unsigned long to a signed long, depending on the nofBytes used
		* 	param: 	nofBytes		the number of bytes used
		*			data			the long int to convert
		*)
		PROCEDURE ToSignedLong*(nofBytes, data : LONGINT): LONGINT;
		VAR returnValue : LONGINT;
		BEGIN
			returnValue := data;
			CASE nofBytes OF
				 1:
				 	IF(data>=80H) THEN
					 	returnValue := data- 100H;
					END;
				|2:
				 	IF(data>=8000H) THEN
				 		returnValue := data- 10000H;
			 	END;
				|4:
					IF(data>=80000000H) THEN
						(*unhappy with that expression but could not write data - 100000000H*)
						returnValue := data- LONGINT(0FFFFFFFFH) - LONGINT(0FFFFFFFFH) - 2;
					END;
				ELSE
				returnValue := 0;
			END;
			RETURN returnValue;
		END ToSignedLong;

		(*	create new hid report from globalState and localState
		* 	param: 	reportType		IDMainItemInput, IDMainItemOutput or IDMainItemFeature
		*	return:	hidReport		new created HidReport
		*)
		PROCEDURE CreateHidReport(reportType, itemNr: LONGINT):UsbHidReport.HidReport;
		VAR
			hidReport:		UsbHidReport.HidReport;
			isArrayFlagSet:	BOOLEAN;
			diff, maxVal:	LONGINT;
		BEGIN
			IF(reportType=IDMainItemInput) THEN
				NEW(hidReport);
				hidReport.reportID 			:= globalState.State(IDReportID);
				hidReport.reportType		:= reportType;
				hidReport.reportSize		:= globalState.State(IDReportSize);
				hidReport.usagePage		:= globalState.State(IDUsagePage);
				hidReport.mainState		:= mainState;
				(*hidReport.reportOffset		:= UndefinedState;*)
				hidReport.reportCount		:= globalState.State(IDReportCount);
				hidReport.logicalMinimum	:= globalState.State(IDLogicalMinimum);
				hidReport.logicalMaximum	:= globalState.State(IDLogicalMaximum);
				hidReport.physicalMinimum	:= globalState.State(IDPhysicalMinimum);
				hidReport.physicalMaximum	:= globalState.State(IDPhysicalMaximum);
				hidReport.unitExponent		:= globalState.State(IDUnitExponent);
				hidReport.unit				:= globalState.State(IDUnit);

				isArrayFlagSet := {IDMainIsVariable} * SYSTEM.VAL(SET,mainState) = {};

				IF UsbHidReport.UseUsageDictionaryExt THEN
					(*only append the usageDictionary when mainState has set array flag (usageID sent but not usageValues)*)
					IF isArrayFlagSet THEN
						hidReport.supportedUsages := localState.CreateUsageDictionary();
					END;
				END;
				hidReport.usages := localState.CreateUsageArray(hidReport.reportCount, isArrayFlagSet);
			END;
			(*check the remaining possible errors*)

			(*reportSize too small*)
			diff:=hidReport.logicalMaximum-hidReport.logicalMinimum;
			maxVal := SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,{hidReport.reportSize}));
			IF((diff>maxVal)&(hidReport.reportSize<32)) THEN
				errorList.Add(itemNr, UsbHidErrors.GlobalItemLogicalMinimum,0H);
				errorList.Add(itemNr, UsbHidErrors.GlobalItemLogicalMaximum,0H);
			END;

			(*array has to have logical Minimum=1 &
				logical Maximum=maxUsage*)
			IF( {IDMainIsVariable,IDMainIsConstant} * SYSTEM.VAL(SET,hidReport.mainState)={})THEN
				(*no tested device cares about this rule
				IF hidReport.logicalMinimum#1 THEN
					errorList.Add(itemNr, UsbHidErrors.GlobalItemLogicalMinimum,2H);
				END;
				*)

				IF UsbHidReport.UseUsageDictionaryExt THEN
					maxVal := reportManager.DictSize(hidReport.supportedUsages);
					IF(maxVal#hidReport.logicalMaximum-hidReport.logicalMinimum+1) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemLogicalMaximum,2H);
					END;
				END;
			END;
			RETURN hidReport;
		END CreateHidReport;

		(*	return reference to reportManager
		*	return:	reportManager	where all report infos are stored
		*)
		PROCEDURE GetReportManager*(): UsbHidReport.HidReportManager;
		BEGIN
			RETURN reportManager;
		END GetReportManager;

		(*parse main item
		* 	param: 	si			to get bTag, bSize and data params
		*			itemNr		used for errorList
		*)
		PROCEDURE ParseMainItem*(si: Item; itemNr: LONGINT);
		VAR
			checkLocalState : 	BOOLEAN;
			aReport:			UsbHidReport.HidReport;

			PROCEDURE VerifyMainPreconditions;
			BEGIN
				IF(globalState.State(IDLogicalMinimum)>=globalState.State(IDLogicalMaximum)) THEN
					IF globalState.State(IDLogicalMinimum)#UndefinedState THEN
						errorList.Add(itemNr, UsbHidErrors.MainItemInput, 3);
					END;
				END;

				IF(globalState.State(IDPhysicalMinimum)>=globalState.State(IDPhysicalMaximum)) THEN
					IF globalState.State(IDPhysicalMinimum)#UndefinedState THEN
						errorList.Add(itemNr, UsbHidErrors.MainItemInput, 3);
					END;
				END;


				IF globalState.State(IDUsagePage) = UndefinedState THEN
					errorList.Add(itemNr, UsbHidErrors.MainItemInput, 0);
					IF Trace THEN KernelLog.String("Usage Page must be defined prior"); END;
				END;

				IF globalState.State(IDLogicalMinimum) = UndefinedState THEN
					errorList.Add(itemNr, UsbHidErrors.MainItemInput, 0);
					IF Trace THEN KernelLog.String("Logical Min must be defined prior"); END;
				END;

				IF globalState.State(IDLogicalMaximum) = UndefinedState THEN
					errorList.Add(itemNr, UsbHidErrors.MainItemInput, 0);
					IF Trace THEN KernelLog.String("Logical Max must be defined prior"); END;
				END;

				IF globalState.State(IDReportSize) = UndefinedState THEN
					errorList.Add(itemNr, UsbHidErrors.MainItemInput, 0);
					IF Trace THEN KernelLog.String("Report Size must be defined prior"); END;
				END;

				IF globalState.State(IDReportCount) = UndefinedState THEN
					errorList.Add(itemNr, UsbHidErrors.MainItemInput, 0);
					IF Trace THEN KernelLog.String("Report Count must be defined prior"); END;
				END;
			END VerifyMainPreconditions;

		BEGIN
			IF (Trace OR Debug) THEN
				HidParserExt.ParseMainItem(si.bTag,si.bSize, si.data, itemNr, depth);
			END;
			checkLocalState := TRUE;

			CASE si.bTag OF
				IDMainItemInput: (*Input Item*)
					IF IDMainIsConstant IN SYSTEM.VAL(SET, si.data) THEN
						checkLocalState := FALSE;
					END;
					inputOutputFeatureParsed := TRUE;
					mainState:= si.data;
					VerifyMainPreconditions;
					(*usages are only added to local state if mainState has not set the constant flag*)
					localState.AppendUsageMinMaxArray(mainState, globalState);
					aReport := CreateHidReport(IDMainItemInput,itemNr);
					IF ((aReport.usages = NIL) & ({IDMainIsConstant} * SYSTEM.VAL(SET,aReport.mainState)={})) THEN
						errorList.Add(itemNr, UsbHidErrors.MainItemInput, 0);
					END;
					reportManager.AddReport(aReport);
				|IDMainItemOutput: (*Output Item*)
					IF IDMainIsConstant IN SYSTEM.VAL(SET, si.data) THEN
						checkLocalState := FALSE;
					END;
					inputOutputFeatureParsed := TRUE;
					mainState:= si.data;
					VerifyMainPreconditions;
					(*localState.AppendUsageMinMaxArray(mainState, globalState);
					reportManager.AddReport(CreateHidReport(IDMainItemOutput));*)
				|IDMainItemFeature: (*Feature Item*)
					IF IDMainIsConstant IN SYSTEM.VAL(SET, si.data) THEN
						checkLocalState := FALSE;
					END;
					inputOutputFeatureParsed := TRUE;
					mainState:= si.data;
					VerifyMainPreconditions;
					(*localState.AppendUsageMinMaxArray(mainState, globalState);
					reportManager.AddReport(CreateHidReport(IDMainItemFeature));*)
				|IDMainItemCollection: (*Collection*)
					INC(depth);
					IF (si.data>6H) THEN
						IF si.data < 8FH THEN
							errorList.Add(itemNr, UsbHidErrors.UnknownItem, 003FH);
						ELSE
							(*non standard is treated as an error*)
							errorList.Add(itemNr, UsbHidErrors.UnknownItem, 003FH);
						END;
					END;
					IF ((reportManager.OnTopLevel()=FALSE) & (si.data=1H)) THEN
						errorList.Add(itemNr, UsbHidErrors.MainItemCollection, 2H);
					END;
					reportManager.BeginCollection(si.data, globalState.State(IDUsagePage), localState.State(IDLocalUsage));
					checkLocalState := FALSE;
				|IDMainItemEndCollection: (*End Collection*)
					DEC(depth);
					checkLocalState := FALSE;
					IF reportManager.OnTopLevel() THEN
						errorList.Add(itemNr, UsbHidErrors.MainItemEndCollection, 0);
					END;
					reportManager.EndCollection;
				ELSE
					errorList.Add(itemNr, UsbHidErrors.UnknownItem, 003FH);
			END;

			IF (checkLocalState) THEN
				localState.VerifyLocalState(errorList, itemNr);
				IF(globalState.VerifyGlobalState(errorList, itemNr)=FALSE) THEN
				END;
			END;
			IF(inputOutputFeatureParsed=TRUE) THEN
			END;
			globalState.ResetGlobalStateFlags;
			localState.CleanLocalState;
		END ParseMainItem;

		(*parse global item
		* 	param: 	si			to get bTag, bSize and data params
		*			itemNr		used for errorList
		*)
		PROCEDURE ParseGlobalItem*( si: Item; itemNr: LONGINT);
		VAR temp : LONGINT;
		BEGIN
			IF (Trace OR Debug) THEN
				IF((si.bTag=1H) OR (si.bTag=2H)) THEN
					temp := si.data;
					HidParserExt.ParseGlobalItem(si.bTag, si.bSize, ToSignedLong(si.bSize,temp), itemNr, depth);
				ELSE
					HidParserExt.ParseGlobalItem(si.bTag, si.bSize, si.data, itemNr, depth);
				END;
			END;
			CASE si.bTag OF
				0H: (*Usage Page *)
					globalState.SetState(errorList, IDUsagePage, si.data, itemNr);
					IF((inputOutputFeatureParsed= TRUE)&(globalState.State(IDUsagePage)=UndefinedState)) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemUsagePage, 2H);
					END;
					CASE si.data OF
						(*REFERENCE: p. 4 HID Usage Tables*)
						0H:
							(*Undefined*)
							errorList.Add(itemNr, UsbHidErrors.GlobalItemUsagePage, 0H);
						|1H: (*Generic Desktop Controls*)
						|2H: (*Simulation Controls*)
						|3H: (*VR Controls*)
						|4H: (*Sport Controls *)
						|5H: (*Game Controls*)
						|6H: (*Generic Device Controls*)
						|7H: (*Keyboard/Keypad*)
						|8H: (*LEDs*)
						|9H: (*Button*)
						|0AH: (*Ordinal*)
						|0BH: (*Telephony*)
						|0CH: (*Consumer*)
						|0DH: (*Digitizer*)
						|0EH: (*Reserved*)
						|0FH: (*PID Page*)
						|10H: (*Unicode*)
						(*
						|11H: (*Reserved*)
						|12H: (*Reserved*)
						|13H: (*Reserved*)
						*)
						|14H: (*Alphanumeric Display*)
						(* from 15h tol 3fH
						|15H-3fH: (*Reserved*)*)
						|40: (*Medical Instruments*)
						(* from 41H tol 7fH
						|41H-7fH: (*Reserved*)*)
						|81H: (*Monitor pages*)
						|82H: (*Monitor pages*)
						|83H: (*Monitor pages*)
						|84H: (*Power pages*)
						|85H: (*Power pages*)
						|86H: (*Power pages*)
						|87H: (*Power pages*)
						(* from 88H tol 8BH
						|41H-7fH: (*Reserved*)*)
						|8CH: (*Bar Code Scanner page*)
						|8DH: (*Scale page*)
						|8EH: (*Magnetic Stripe reading (MSR) Devices*)
						|8FH: (*Reserved Point of Sale pages*)
						ELSE
							 (*Reserved*)
							IF(si.data>0FFFFH) THEN
								errorList.Add(itemNr, UsbHidErrors.GlobalItemUsagePage, 1H);
							END;
							errorList.Add(itemNr, UsbHidErrors.UnknownItem, 003FH);
					END;
				|1H: (*Logical Minimum *)
					(*Locigal Minimum can be negative, the value needs to be interpreted as signed int 2s complement*)
					globalState.SetState(errorList, IDLogicalMinimum, ToSignedLong(si.bSize, si.data), itemNr);
					IF((inputOutputFeatureParsed= TRUE)&(globalState.State(IDLogicalMinimum)=UndefinedState)) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemLogicalMinimum, 1H);
					END;
				|2H: (*Logical Maximum*)
					(*Locigal Maximum could be negative, the value needs to be interpreted as signed int 2s complement*)
					globalState.SetState(errorList, IDLogicalMaximum, ToSignedLong(si.bSize, si.data), itemNr);
					IF((inputOutputFeatureParsed= TRUE)&(globalState.State(IDLogicalMaximum)=UndefinedState)) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemLogicalMaximum, 1H);
					END;
				|3H: (*Physical Minimum *)
					globalState.SetState(errorList, IDPhysicalMinimum, si.data, itemNr);
				|4H: (*Physical Maximum*)
					globalState.SetState(errorList, IDPhysicalMaximum, si.data, itemNr);
				|5H: (*Unit Exponent*)
					globalState.SetState(errorList, IDUnitExponent, si.data, itemNr);
					(*nice to have:  zehner exponent decodieren gemäss seite 38*)
				|6H: (*Unit*)
					globalState.SetState(errorList, IDUnit, si.data, itemNr);
				|7H: (*Report Size*)
					globalState.SetState(errorList, IDReportSize, si.data, itemNr);
					IF((inputOutputFeatureParsed= TRUE)&(globalState.State(IDReportSize)=UndefinedState)) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemReportSize, 1H);
					END;
				|8H: (*Report ID*)
					globalState.SetState(errorList, IDReportID, si.data, itemNr);
					IF((inputOutputFeatureParsed= TRUE)&(globalState.State(IDReportID)=UndefinedState)) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemReportID, 2H);
					END;
					IF(si.data=0) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemReportID, 0H);
					ELSE
						IF(si.data>255) THEN
							errorList.Add(itemNr, UsbHidErrors.GlobalItemReportID, 1H);
						END;
					END;
					IF (reportManager.OnTopLevel()) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemReportID, 3H);
						errorList.Add(itemNr, UsbHidErrors.GlobalItemReportID, 4H);
					END;
				|9H: (*Report Count *)
					globalState.SetState(errorList, IDReportCount, si.data, itemNr);
					IF(si.data=0) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemReportCount, 0H);
					END;
				|10: (*Push*)
					(*do push*)
					globalState.Push;
					IF(si.bSize#0) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemPush, 1H);
					END;
				|11: (*Pop*)
					(*do pop: first check if globalState = firstGlobalState,
						then check start at firstGlobalState and find the second last element in the list, when found, delete the last*)
					IF(globalState.Pop()=FALSE) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemPop, 0H);
					END;
					IF(si.bSize#0) THEN
						errorList.Add(itemNr, UsbHidErrors.GlobalItemPop, 1H);
					END;
				ELSE
					(*Reserved*)
					errorList.Add(itemNr, UsbHidErrors.UnknownItem, 003FH);
				END;
		END ParseGlobalItem;

		(*parse local item
		* 	param: 	si			to get bTag, bSize and data params
		*			itemNr		used for errorList
		*)
		PROCEDURE ParseLocalItem*(si: Item; itemNr: LONGINT);
		BEGIN
			IF (Trace OR Debug) THEN
				HidParserExt.ParseLocalItem(si.bTag, si.bSize, si.data,  itemNr, depth, globalState.State(IDUsagePage));
			END;
			(*as described in HID Parser Error Codes page 3, all local item checks for errors and warnings (except delimiter) are checked
			   when the parser encounters the next main item*)
			CASE si.bTag OF
				0H:	(*Usage*)
					(*as described at page 41 32bit values for Usage only the lower 16bits identify the usage, the higher 16bits define the usage page*)
					localState.SetState(IDLocalUsage, si.data);
				|1H: (*Usage Minimum*)
					(*as described at page 41 32bit values for UsageMinimum only the lower 16bits identify the usageMinimum, the higher 16bits define the usage page*)
					localState.SetState(IDLocalUsageMinimum, si.data);
				|2H: (*Usage Maximum*)
					(*as described at page 41 32bit values for UsageMaximum only the lower 12bits identify the usageMaximum, the higher 16bits define the usage page*)
					localState.SetState(IDLocalUsageMaximum, si.data);
				|3H: (*Designator Index*)
					localState.SetState(IDLocalDesignatorIndex, si.data);
				|4H: (*Designator Minimum*)
					localState.SetState(IDLocalDesignatorMinimum, si.data);
				|5H: (*Designator Maximum*)
					localState.SetState(IDLocalDesignatorMaximum, si.data);
				(*|6H: (*RESERVED*)*)
				|7H: (*String Index*)
					localState.SetState(IDLocalStringIndex, si.data);
				|8H: (*String Minimum*)
					localState.SetState(IDLocalStringMinimum, si.data);
				|9H: (*String Maximum*)
					localState.SetState(IDLocalStringMaximum, si.data);
				|0AH: (*Delimiter*)
					CASE si.data OF
						0: (*open set*)
							IF (localState.State(IDLocalDelimiter)#UndefinedState) THEN
								errorList.Add(itemNr, UsbHidErrors.LocalItemDelimiter, 1H);
							END;
							localState.SetState(IDLocalDelimiter, si.data);
						|1H: (*close set*)
							IF(localState.State(IDLocalDelimiter)=UndefinedState) THEN
								(*there is no corresponding open set*)
								errorList.Add(itemNr, UsbHidErrors.LocalItemDelimiter, 2H);
							END;
							localState.SetState(IDLocalDelimiter, si.data);
						ELSE (*NOT DEFINED*)
							errorList.Add(itemNr, UsbHidErrors.LocalItemDelimiter, 0H);
					END;
				ELSE (*RESERVED*)
				errorList.Add(itemNr, UsbHidErrors.UnknownItem, 003FH);
			END;
		END ParseLocalItem;

		(*parse long item (not used in Device Class Definition for HID Version 1.11, long item is reserved; when found in hid descriptor, it is
		*	ignored and simply skipped
		* 	param: 	li				to get bTag and bSize params
		*			reportBuffer		to read data
		*			len				the len to read on the reportBuffer
		*			startIndex		position where to begin read on reportBuffer
		*			itemNr			used for errorList
		*)
		PROCEDURE ParseLongItem*(li: Item; reportBuffer: Usbdi.BufferPtr; len, startIndex, itemNr : LONGINT);
		BEGIN
			errorList.Add(itemNr, UsbHidErrors.UnknownItem, 003EH);
		END ParseLongItem;

		(*parses the report descriptor
		* 	param: 	hidDescriptor	the hid descriptor
					reportBuffer		data of hid report descriptor
		*	return:	TRUE 	if successfull
					FALSE 	otherwise
		*)
		PROCEDURE ParseReportDescriptor*(hidDescriptor : UsbHid.HidDescriptor; reportBuffer : Usbdi.BufferPtr): BOOLEAN;
		VAR
			itemCounter :	LONGINT;
			cur : 			LONGINT;
			item :			POINTER TO Item;
			hidCollection:	UsbHidReport.HidCollection;
		BEGIN
			NEW(item);
			itemCounter := 0;
			cur := 0;

			IF Trace THEN
				KernelLog.Ln;
				KernelLog.String("Report Descriptor Content:");
				KernelLog.Ln;
			END;

			LOOP
				(*catch report buffer overflow*)
				IF cur >= hidDescriptor.wDescriptorLength-1 THEN EXIT; END;

				(*init si*)
				item.bSize := ORD(reportBuffer[cur]) MOD 4;
				(*as defined on page 26, Device Class Definition for HID*)
				IF (item.bSize = 3) THEN INC(item.bSize); END;
				item.bType := (ORD(reportBuffer[cur]) DIV 4) MOD 4;
				item.bTag := (ORD(reportBuffer[cur]) DIV 16) MOD 16;
				INC(cur);

				(*get the data depending on si.bSize*)
				IF (item.bType # ShortItemBTypeReserved) THEN
					IF (item.bSize#0) THEN
						CASE item.bSize OF
							1:
				 				item.data:= ORD(reportBuffer[cur]);
				 			|2:
								item.data:= ORD(reportBuffer[cur+1]);
								item.data:= 100H*item.data+ORD(reportBuffer[cur]);
							|4:
								item.data:= ORD(reportBuffer[cur+3]);
								item.data:= 100H*item.data + ORD(reportBuffer[cur+2]);
								item.data:= 100H*item.data + ORD(reportBuffer[cur+1]);
								item.data:= 100H*item.data + ORD(reportBuffer[cur]);
						END;
						IF(item.data<0) THEN
							KernelLog.String("item.data<0 at index: "); KernelLog.Int(cur,0);KernelLog.Ln;
							KernelLog.String("item.bSize is "); KernelLog.Int(item.bSize,2); KernelLog.Ln;
						END;
					ELSE
						item.data:= 0;
					END;

					(*identifying shortitem*)
					CASE (item.bType) OF
						ShortItemBTypeMain:
							(*ShortItem Main*)
							IF Debug THEN KernelLog.Int(itemCounter, 4); KernelLog.String(" main  "); END;
							ParseMainItem(item^, itemCounter);
						|ShortItemBTypeGlobal:
							(*ShortItem Global*)
							IF Debug THEN KernelLog.Int(itemCounter, 4); KernelLog.String(" global"); END;
							ParseGlobalItem(item^, itemCounter);
						|ShortItemBTypeLocal:
							(*ShortItem Local*)
							IF Debug THEN KernelLog.Int(itemCounter, 4); KernelLog.String(" local  "); END;
							ParseLocalItem(item^, itemCounter);
						ELSE
							RETURN FALSE;
					END;

					INC(cur, item.bSize);
				ELSE
					(*long item*)
					(*cur is at beginning of the longiten item, index of bTag, bType and bSize*)
					IF (item.bSize#0) THEN
						(*Detect reportBuffer overflow:
							cur: current position of shortItemTag,
							1 : (shortItemTag+1) holds the dataSize,
							ORD(reportBuffer[cur+1]): the length of data to read after dataSize in Byte
						*)
						IF((cur+1+ORD(reportBuffer[cur+1]))<hidDescriptor.wDescriptorLength) THEN
							ParseLongItem(item^, reportBuffer, ORD(reportBuffer[cur+1]), cur+1, itemCounter);
							(*EvalStatusCode(hidStatusCode);*)
						END;
						INC(cur,ORD(reportBuffer[cur+1]) +1);
					END;
				END;
				INC(itemCounter);
			END; (*LOOP*)
			IF UsbHidReport.Debug THEN
				KernelLog.String("Starting report layout:"); KernelLog.Ln;
				hidCollection := reportManager.GetCollection(-1,-1);
				KernelLog.String("Searching Mouse Collection (usagePage 1 and usage 2):"); KernelLog.Ln;
				hidCollection := reportManager.GetCollection(1,2);
				IF (hidCollection#NIL) THEN
					KernelLog.String("Mouse Collection found:"); KernelLog.Ln;
					KernelLog.String("usagePage: "); KernelLog.Int(hidCollection.usagePage,0);
					KernelLog.String(", usage: "); KernelLog.Int(hidCollection.usage,0);
				ELSE
					KernelLog.String("Mouse Collection not found");
				END;
				KernelLog.Ln;
			END;
			IF (reportManager.OnTopLevel()= FALSE) THEN
				errorList.Add(itemCounter, UsbHidErrors.MainItemCollection, 0);
			END;

			RETURN TRUE;
		END ParseReportDescriptor;

		(*when detaching the device*)
		PROCEDURE Disconnect*;
		BEGIN
			errorList := NIL;
		END Disconnect;

		PROCEDURE &Init*;
		BEGIN
			NEW(globalState);
			NEW(localState);
			NEW(errorList);
			IF Debug THEN KernelLog.String("ItemParser is initialized"); KernelLog.Ln; END;
			inputOutputFeatureParsed := FALSE;
			IF Debug THEN
				depth := 1;
			ELSE
				depth := 0;
			END;
			NEW(reportManager);
		END Init;
	END ItemParser;

END UsbHidParser.

SystemTools.Free UsbHidParser UsbHidParserExt~