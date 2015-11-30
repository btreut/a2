(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMInterfaces;

IMPORT
	JVMConsole,
	SYSTEM, AosModules;

CONST
	TableSize = 8191; (* largest prime number < 8192; !!= (2<<13)-1!! *)
	TableSize1m  = TableSize - 1;
	
	Trace = FALSE;
	
TYPE
	VTable* = POINTER TO VTableDesc;
	VTableDesc* = RECORD
		tdesc-: AosModules.TypeTag (*  class implementing the Interface *)
	END;
		                 		
VAR
	td-: AosModules.TypeDesc; 	(** cached: td of VTableDesc *)
	
	InterfaceTable-: ARRAY TableSize OF VTable;
	
	(*statistic counters*)
	Nentries, Niterations: LONGINT;

	infoInfo: JVMConsole.LoggingInfo;

PROCEDURE GetTypeTag(p: PTR): AosModules.TypeTag;
VAR t: AosModules.TypeTag;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(LONGINT, p) - 4, t);
	RETURN t
END GetTypeTag;

PROCEDURE GetTypeDesc(p: PTR): AosModules.TypeDesc;
VAR t: AosModules.TypeDesc;
BEGIN
	SYSTEM.GET(SYSTEM.VAL(LONGINT, GetTypeTag(p)) - 4, t);
	RETURN t
END GetTypeDesc;
		
(* this is a little bit slow; three times slower than the version below !!						
PROCEDURE HashA*(val1, val2: LONGINT): LONGINT;
VAR x: LONGINT;
BEGIN	
	x := JS.XOR(ASH(val1,1), val2);	
	RETURN x MOD TableSize
END HashA;
*)

(* this Hashfunction runs reasonably fast *)
PROCEDURE -HashA(val1, val2: AosModules.TypeTag):LONGINT;
CODE{SYSTEM.i386}
	POP EAX
	POP EBX
	SHL EBX, 1
	XOR EAX, EBX
	MOV EBX, EAX
	AND EBX, 1FFFH (* r1 *)
	SHR EAX, 13 (*  eax >> 13 *)
	MOV ECX, EAX 
	AND EAX, 1FFFH (* r2 *)
	SHR ECX, 13 (*  eax >> 13 *) (* n *)		
	ADD EAX, ECX 
	ADD EAX, EBX
	CMP EAX, TableSize
	JL stop	
	Loop:
	SUB EAX, TableSize
	Test:
	CMP EAX, TableSize
	JA Loop
	stop:	
END HashA;

(* 
PROCEDURE HashB*(val1, val2: LONGINT): LONGINT;
VAR val: LONGINT;
BEGIN	
	val := ASH(val2,1);	
	RETURN JS.XOR(val1,  val) MOD (TableSize-1) + 1
END HashB;
*)

(* optimized version *)
PROCEDURE -HashB(val1, val2: AosModules.TypeTag): LONGINT;
CODE{SYSTEM.i386}
	POP EBX
	POP EAX
	SHL EBX, 1
	XOR EAX, EBX
	MOV EBX, EAX
	AND EBX, 01FFFH (* r1 *)
	SHR EAX, 13 (*  eax >> 13 *)
	MOV ECX, EAX 
	AND EAX, 1FFFH (* r2 *)
	SHR ECX, 13 (*  eax >> 13 *) (* n *) 
	SHL ECX, 1
	ADD EAX, ECX
	SHL EAX, 1
	ADD EAX, EBX
	CMP EAX, TableSize1m
	JL stop	
	Loop:
	SUB EAX, TableSize1m
	Test:
	CMP EAX, TableSize1m
	JA Loop
	stop:	
	ADD EAX, 1
END HashB;


PROCEDURE Insert*(classTd, interfaceTd: AosModules.TypeTag;  val: VTable):BOOLEAN;
VAR  B, index: LONGINT;
BEGIN {EXCLUSIVE}
	ASSERT(GetTypeTag(val) = interfaceTd);
	Niterations := 0;
	(* one empty entry is used as sentinel; 
	    see Nievergelt/Hinrichs Algorithms & Datastructures; Prentice Hall
	    or Ottman/Widmeyer .. for further explanation 
	*)
	val.tdesc := classTd;
	IF Nentries >= TableSize-1 THEN RETURN FALSE END;
	index := HashA(classTd, interfaceTd); B := HashB(classTd, interfaceTd);	
	WHILE InterfaceTable[index] # NIL DO
		INC(Niterations);
		INC(index, B); 
		IF index >= TableSize THEN DEC(index,TableSize) END
	END;
	InterfaceTable[index] := val;
	INC(Nentries);
	RETURN TRUE
END Insert;

PROCEDURE Lookup*(classTd, interfaceTd: AosModules.TypeTag): VTable;
VAR B, index: LONGINT; val: VTable;
	td: AosModules.TypeDesc;
BEGIN
	IF Trace THEN
		JVMConsole.String(infoInfo, "IL "); 
		SYSTEM.GET(SYSTEM.VAL(LONGINT, classTd)-4, td);
		JVMConsole.String(infoInfo, td.name);
		JVMConsole.String(infoInfo, "  ");
		SYSTEM.GET(SYSTEM.VAL(LONGINT, interfaceTd)-4, td);
		JVMConsole.String(infoInfo, td.name);
		JVMConsole.Ln(infoInfo);
	END;
	index := HashA(classTd, interfaceTd); 	
	B := HashB(classTd, interfaceTd);
	val := InterfaceTable[index];
	WHILE (val # NIL) & ((val.tdesc # classTd) OR (GetTypeTag(val) # interfaceTd)) DO
		INC(index, B);
		IF index >= TableSize THEN DEC(index, TableSize) END;
		val := InterfaceTable[index]
	END;
	RETURN val			
END Lookup;

PROCEDURE Init;
VAR i: LONGINT;
BEGIN
	td := AosModules.ThisType(SELF(AosModules.Module), "VTableDesc");
	FOR i := 0 TO TableSize-1 DO  InterfaceTable[i] := NIL  END
END Init;

BEGIN
	infoInfo.kind := JVMConsole.Info; infoInfo.source := JVMConsole.VM;
	Init
END JVMInterfaces.

(*
	30.07.03	prk	Logging functions, add kind and source; filtering support
	12.02.03	prk	Logging functions, use same interface as AosOut
	19.03.02	prk	trace informations improved
	16.08.01	prk	Remove use of Oberon modules, use only Aos ones
	27.05.01	prk	interfaces cleanup
*)