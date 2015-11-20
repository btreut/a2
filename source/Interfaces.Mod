(* Paco, Copyright 2002, Patrik Reali, ETH Zurich *)

MODULE Interfaces;	(** AUTHOR "prk"; PURPOSE "Runtime support for interfaces"; *)

IMPORT
	SYSTEM, Machine, Modules;

(*
	Interface
	Interface Implementation
		td => Interface
		+00: => Class TD
		+04: method0
		+08: method1
		....

	Internal organization:
		Hash Table (with double hashing)

*)

CONST
	TableSize = 8191; (* largest prime number < 8192; !!= (2<<13)-1!! *)
	TableSize1m  = TableSize - 1;

VAR
	table-: ARRAY TableSize OF ANY;

	(*statistic counters*)
	Nentries, Nlookups, NlookupsRep: LONGINT;
	Ncollisions: ARRAY 10 OF LONGINT;

PROCEDURE GetClass(p: ANY): ADDRESS;
VAR class: ADDRESS;
BEGIN
	SYSTEM.GET (SYSTEM.VAL (ADDRESS, p), class);
	RETURN class
END GetClass;

PROCEDURE GetInterface(p: ANY): ADDRESS;
VAR interface: ADDRESS;
BEGIN
	SYSTEM.GET (SYSTEM.VAL (ADDRESS, p) - SIZEOF (ADDRESS), interface);
	SYSTEM.GET (interface - SIZEOF (ADDRESS) * 2, interface);
	RETURN interface
END GetInterface;

PROCEDURE HashA*(val1, val2: ADDRESS): ADDRESS;
VAR x: ADDRESS;
BEGIN
	x := SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, ASH(val1,1)) / SYSTEM.VAL(SET, val2));
	RETURN x MOD TableSize
END HashA;

PROCEDURE HashB*(val1, val2: ADDRESS): ADDRESS;
VAR val: ADDRESS;
BEGIN
	val := ASH(val2,1);
	RETURN SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, val) / SYSTEM.VAL(SET, val2)) MOD (TableSize-1) + 1
END HashB;

PROCEDURE Register(vt: ANY);
	VAR class, intf, hash, step: ADDRESS; count: LONGINT; q: ANY;
BEGIN {EXCLUSIVE}
	ASSERT(Nentries < TableSize, 1000);
	class := GetClass(vt);
	intf := GetInterface(vt);
	hash := HashA(class, intf);
	step := HashB(class, intf);
	WHILE table[hash] # NIL DO
		q := table[hash];
		ASSERT((GetClass(q) # class) OR (GetInterface(q) # intf), 1001);
		INC(count);
		INC(hash, step);
		IF hash >= TableSize THEN DEC(hash, TableSize) END
	END;
	table[hash] := vt;
	IF count >= LEN(Ncollisions) THEN count := LEN(Ncollisions)-1 END;
	INC(Nentries);
	INC(Ncollisions[count])
END Register;

PROCEDURE Lookup(class, intf: ADDRESS): ANY;
	VAR vt: ANY; hash, step: ADDRESS;
BEGIN	(* can run concurrent with Register *)
	Machine.AtomicInc(Nlookups);
	hash := HashA(class, intf);
	vt := table[hash];
	IF (vt # NIL) & ((GetClass(vt) # class) OR (GetInterface(vt) # intf)) THEN
		step := HashB(class, intf);
		Machine.AtomicInc(NlookupsRep);
		REPEAT
			INC(hash, step);
			IF hash >= TableSize THEN DEC(hash, TableSize) END;
			vt := table[hash]
		UNTIL (vt = NIL) OR ((GetClass(vt) = class) & (GetInterface(vt) = intf))
	END;
	RETURN vt;
END Lookup;

PROCEDURE Cleanup;
BEGIN
	Modules.kernelProc[8] := 0;	(*245*)
	Modules.kernelProc[9] := 0;	(*244*)
END Cleanup;

PROCEDURE Init;
VAR i: LONGINT; lookup: PROCEDURE(class, intf: ADDRESS): ANY; register: PROCEDURE(vt: ANY);
BEGIN
	FOR i := 0 TO TableSize-1 DO  table[i] := NIL  END;
	register := Register; lookup := Lookup;
	Modules.InstallTermHandler(Cleanup);
	Modules.kernelProc[8] := SYSTEM.VAL(ADDRESS, lookup);	(*245*)
	Modules.kernelProc[9] := SYSTEM.VAL(ADDRESS, register);	(*244*)
END Init;

BEGIN
	Init
END Interfaces.

System.State Interfaces ~

(*
ToDo:
	Remove interface when a module is freed

Log:
	30.10.2001	prk	Fine tuning
	05.10.2001	prk	First Version
*)