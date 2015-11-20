(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Profiler;	(* pjm *)

(* Aos statistical profiler *)

IMPORT SYSTEM, KernelLog, Streams, Commands, Machine, Modules, Kernel;

CONST
	Divisor = 4;
	MaxRanges = 64;
	MaxModules = 256;
	MaxSpace = 65536;

	WaitTime = 100;	(* ms *)

TYPE
	Range = RECORD
		lowAdr, highAdr: ADDRESS;
		count: POINTER TO ARRAY OF LONGINT
	END;

	Bytes = Modules.Bytes;

VAR
	size, outside, total: LONGINT;
	range: ARRAY MaxRanges OF Range;
	running: BOOLEAN;

PROCEDURE HandleTimer(id: LONGINT; CONST state: Machine.State);
VAR low, high, i: LONGINT;
BEGIN
	Machine.AtomicInc(total);
	low := 0; high := size;
	LOOP
		IF low >= high THEN Machine.AtomicInc(outside); EXIT END;
		i := low + (high-low) DIV 2;
		IF state.PC >= range[i].lowAdr THEN
			IF state.PC <= range[i].highAdr THEN	(* found *)
				Machine.AtomicInc(range[i].count[(state.PC-range[i].lowAdr) DIV Divisor]);
				EXIT
			ELSE
				low := i+1
			END
		ELSE
			high := i
		END
	END
END HandleTimer;

PROCEDURE GetRanges(VAR n: LONGINT; VAR range: ARRAY OF Range);
VAR m: Modules.Module; i, j: LONGINT; lowAdr, highAdr: ADDRESS; a: ARRAY MaxModules OF Range;
BEGIN
		(* get & sort - assume module list does not change during this loop *)
	m := Modules.root; n := 0;
	WHILE m # NIL DO
		lowAdr := ADDRESSOF(m.code[0]);
		highAdr := lowAdr + LEN(m.code);
			(* insert sort *)
		i := 0; WHILE (i # n) & (lowAdr > a[i].lowAdr) DO INC(i) END;
		FOR j := n-1 TO i BY -1 DO a[j+1] := a[j] END;
		a[i].lowAdr := lowAdr; a[i].highAdr := highAdr; INC(n);
		m := m.next
	END;
		(* combine ranges that are close enough together *)
	i := 0;
	WHILE i < n-1 DO
		IF a[i+1].lowAdr - a[i].highAdr < MaxSpace THEN
			a[i].highAdr := a[i+1].highAdr;
			DEC(n);
			FOR j := i+1 TO n-1 DO a[j] := a[j+1] END
		ELSE
			INC(i)
		END
	END;
	IF n > LEN(range) THEN
		KernelLog.Enter; KernelLog.String("Warning: Only using first ");
		KernelLog.Int(LEN(range), 1); KernelLog.String(" of ");
		KernelLog.Int(n, 1); KernelLog.String(" ranges"); KernelLog.Exit;
		n := LEN(range)
	END;
	FOR i := 0 TO n-1 DO
		NEW(a[i].count, SIZE(a[i].highAdr-a[i].lowAdr) DIV Divisor);
		range[i] := a[i]
	END
END GetRanges;

PROCEDURE Start*(context : Commands.Context);
BEGIN
	IF running THEN
		StopProfiler;
	END;
	GetRanges(size, range);
	outside := 0; total := 0;
	Machine.InstallEventHandler(HandleTimer);
	running := TRUE;
	context.out.String("Profiler started."); context.out.Ln;
END Start;

PROCEDURE StopProfiler;
BEGIN
	Machine.InstallEventHandler(NIL);
	running := FALSE;
END StopProfiler;


PROCEDURE Stop*(context : Commands.Context);
BEGIN
	IF running THEN
		StopProfiler;
		context.out.String("Profiler stopped."); context.out.Ln;
	ELSE
		context.out.String("Profiler is not running."); context.out.Ln;
	END;
END Stop;

PROCEDURE Continue*(context : Commands.Context);
BEGIN
	IF ~running & (size # 0) THEN
		Machine.InstallEventHandler(HandleTimer);
		running := TRUE;
		context.out.String("Profiler continues."); context.out.Ln;
	ELSE
		context.out.String("Profiler is already running."); context.out.Ln;
	END;
END Continue;

PROCEDURE GetNum(refs: Bytes;  VAR i, num: LONGINT);
VAR n, s: LONGINT;  x: CHAR;
BEGIN
	s := 0;  n := 0;  x := refs[i];  INC(i);
	WHILE ORD(x) >= 128 DO
		INC(n, ASH(ORD(x) - 128, s));  INC(s, 7);  x := refs[i];  INC(i)
	END;
	num := n + ASH(ORD(x) MOD 64 - ORD(x) DIV 64 * 64, s)
END GetNum;

(*
	Reference = {OldRef | ProcRef} .
	OldRef = 0F8X offset/n name/s {Variable} .
	ProcRef = 0F9X offset/n nofPars/n RetType procLev/1 slFlag/1 name/s {Variable} .
	RetType = 0X | Var | ArrayType | Record .
	ArrayType = 12X | 14X | 15X .	(* static array, dynamic array, open array *)
	Record = 16X .
	Variable = VarMode (Var | ArrayVar | RecordVar ) offset/n name/s .
	VarMode = 1X | 3X .	(* direct, indirect *)
	Var = 1X .. 0FX .	(* byte, boolean, char, shortint, integer, longint, real, longreal, set, ptr, proc, string *)
	ArrayVar = (81X .. 8EX) dim/n .	(* byte, boolean, char, shortint, integer, longint, real, longreal, set, ptr, proc *)
	RecordVar = (16X | 1DX) tdadr/n .	(* record, recordpointer *)
*)

(* FindProc - Find a procedure in the reference block.  Return index of name, or -1 if not found. *)

PROCEDURE FindProc(refs: Bytes;  ofs: LONGINT): LONGINT;
VAR i, m, t, proc: LONGINT;  ch: CHAR;
BEGIN
	proc := -1;  i := 0;  m := LEN(refs^);
	ch := refs[i];  INC(i);
	WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO	(* proc *)
		GetNum(refs, i, t);	(* pofs *)
		IF t > ofs THEN	(* previous procedure was the one *)
			ch := 0X	(* stop search *)
		ELSE	(* ~found *)
			IF ch = 0F9X THEN
				GetNum(refs, i, t);	(* nofPars *)
				INC(i, 3)	(* RetType, procLev, slFlag *)
			END;
			proc := i;	(* remember this position, just before the name *)
			REPEAT ch := refs[i];  INC(i) UNTIL ch = 0X;	(* pname *)
			IF i < m THEN
				ch := refs[i];  INC(i);	(* 1X | 3X | 0F8X | 0F9X *)
				WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO	(* var *)
					ch := refs[i];  INC(i);	(* type *)
					IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
						GetNum(refs, i, t)	(* dim/tdadr *)
					END;
					GetNum(refs, i, t);	(* vofs *)
					REPEAT ch := refs[i];  INC(i) UNTIL ch = 0X;	(* vname *)
					IF i < m THEN ch := refs[i];  INC(i) END	(* 1X | 3X | 0F8X | 0F9X *)
				END
			END
		END
	END;
	IF (proc = -1) & (i # 0) THEN proc := i END;	(* first procedure *)
	RETURN proc
END FindProc;

PROCEDURE GetProc(mod: Modules.Module;  VAR pc: ADDRESS;  VAR procname: ARRAY OF CHAR);
VAR refpos, i: LONGINT; refs: Bytes; ch: CHAR;
BEGIN
	refpos := -1;
	DEC(pc, ADDRESSOF(mod.code[0]));
	refs := SYSTEM.VAL(Bytes, mod.refs);
	IF (refs # NIL) & (LEN(mod.refs) # 0) THEN
		refpos := FindProc(refs, SYSTEM.VAL (LONGINT, pc));
		IF refpos # -1 THEN
			ch := refs[refpos];  INC(refpos);  i := 0;
			WHILE ch # 0X DO
				procname[i] := ch;  ch := refs[refpos];  INC(refpos);  INC(i)
			END;
			procname[i] := 0X
		END
	END
END GetProc;

PROCEDURE ShowStats(out : Streams.Writer);
VAR sum, i: LONGINT;
BEGIN
	sum := 0;
	FOR i := 0 TO size-1 DO
		INC(sum, LEN(range[i].count)*SIZEOF(LONGINT))
	END;
	out.Int(total, 1); out.String(" samples, ");
	out.Int(outside, 1); out.String(" unknown, ");
	out.Int(size, 1); out.String(" ranges, ");
	out.Int(sum DIV 1024, 1); out.String("KB,");
	IF ~running THEN out.String(" not") END;
	out.String(" running");
	out.Ln(); out.Ln()
END ShowStats;

PROCEDURE ShowDetail*(context : Commands.Context);
VAR i, j, per: LONGINT; pc: ADDRESS; m: Modules.Module; procname: ARRAY 64 OF CHAR;
BEGIN
	ShowStats(context.out);
	FOR i := 0 TO size-1 DO
		FOR j := 0 TO LEN(range[i].count)-1 DO
			IF range[i].count[j] # 0 THEN
				pc := range[i].lowAdr + j*Divisor;
				m := Modules.ThisModuleByAdr(pc);
				IF m # NIL THEN
					GetProc(m, pc, procname);
					context.out.String(m.name); context.out.Char("."); context.out.String(procname);
					context.out.String(" PC="); context.out.Address(pc)
				ELSE
					context.out.String("PC ="); context.out.Address(pc)
				END;
				context.out.Char(" "); context.out.Int(range[i].count[j], 1);
				IF ~running & (total # 0) THEN
					per := ENTIER(range[i].count[j]/total*100 + 0.5);
					IF per # 0 THEN
						context.out.Char(" "); context.out.Int(per, 1); context.out.Char("%")
					END
				END;
				context.out.Ln()
			END
		END
	END;
END ShowDetail;

PROCEDURE Hex(x: ADDRESS; VAR buf: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
	j := SIZEOF(ADDRESS) * 2;
	FOR i := j-1 TO 0 BY -1 DO
		buf[i] := CHR(x MOD 10H + 48);
		IF buf[i] > "9" THEN
			buf[i] := CHR(ORD(buf[i]) - 48 + 65 - 10)
		END;
		x := x DIV 10H
	END;
	buf[j] := 0X
END Hex;

PROCEDURE ShowProcs*(context : Commands.Context);
TYPE
	List = POINTER TO RECORD
		next: List;
		m: Modules.Module;
		procname: ARRAY 64 OF CHAR;
		count: LONGINT
	END;

VAR
	i, j, sum, per: LONGINT; pc: ADDRESS; m, prev: Modules.Module; root: List;
	procname, prevname: ARRAY 64 OF CHAR;

	PROCEDURE Output;
	VAR n, p: List;
	BEGIN
		IF prevname # "" THEN
			NEW(n); n.m := prev; COPY(prevname, n.procname); n.count := sum;
			p := root;
			WHILE (p.next # NIL) & (p.next.count >= n.count) DO p := p.next END;
			n.next := p.next; p.next := n;
			sum := 0
		END;
		prevname := procname; prev := m
	END Output;

BEGIN
	ShowStats(context.out);
	prev := NIL; prevname := ""; sum := 0; NEW(root); root.next := NIL;
	FOR i := 0 TO size-1 DO
		FOR j := 0 TO LEN(range[i].count)-1 DO
			IF range[i].count[j] # 0 THEN
				pc := range[i].lowAdr + j*Divisor;
				m := Modules.ThisModuleByAdr(pc);
				IF m # NIL THEN GetProc(m, pc, procname) ELSE Hex(pc, procname) END;
				IF (m # prev) OR (procname # prevname) THEN Output END;
				INC(sum, range[i].count[j])
			END
		END
	END;
	Output;
	LOOP
		root := root.next;
		IF root = NIL THEN EXIT END;
		context.out.Int(root.count, 1); context.out.Char(" ");
		IF root.m # NIL THEN context.out.String(root.m.name) ELSE context.out.String("Unknown") END;
		context.out.Char("."); context.out.String(root.procname);
		IF ~running & (total # 0) THEN
			per := ENTIER(root.count/total*100 + 0.5);
			IF per # 0 THEN
				context.out.Char(" "); context.out.Int(per, 1); context.out.Char("%")
			END
		END;
		context.out.Ln()
	END;
END ShowProcs;

PROCEDURE Cleanup;
VAR t: Kernel.MilliTimer;
BEGIN
	IF running THEN
		StopProfiler;
		Kernel.SetTimer(t, WaitTime);
		REPEAT UNTIL Kernel.Expired(t)	(* wait for all handlers to terminate *)
	END
END Cleanup;

BEGIN
	running := FALSE;
	Modules.InstallTermHandler(Cleanup)
END Profiler.

Profiler.Oba
Profiler.Start
Profiler.Stop
Profiler.Continue
Profiler.ShowProcs
Profiler.ShowDetail

Configuration.DoCommands
Profiler.Delay 1000
Attributes.Echo Start ~
Profiler.Start
Profiler.Delay 5000
Profiler.Stop
Attributes.Echo Stop ~
Profiler.ShowProcs
~

System.State Profiler ~

System.Free Profiler ~
