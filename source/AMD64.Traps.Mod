MODULE Traps;	(** AUTHOR "pjm"; PURPOSE "Trap handling and symbolic debugging"; *)

IMPORT SYSTEM, Machine, KernelLog, Streams, Modules, Objects, Kernel, Reflection, TrapWriters;

CONST
	RecursiveLimit = 2;		(* normally 1 or 2 - how many recursive traps to display before stopping *)
	TraceVerbose = FALSE;
	TestTrap = TRUE;

	(* Process termination halt codes *)
	halt* = Objects.halt;
	haltUnbreakable* = Objects.haltUnbreakable;

TYPE
	Variable* = RECORD	(** variable descriptor *)
		adr-: ADDRESS;
		type-, size-, n-, tdadr-: LONGINT
	END;


VAR
	trapState: ARRAY Machine.MaxCPU OF LONGINT;	(* indexed by Machine.ID() *)
	modes: ARRAY 25 OF CHAR;
	flags: ARRAY 13 OF CHAR;



	(* Write flag values. *)
	PROCEDURE Flags(w: Streams.Writer; s: SET);
	VAR i: SHORTINT; ch: CHAR;
	BEGIN
		FOR i := 0 TO 11 DO
			ch := flags[i];
			IF ch # "!" THEN
				IF i IN s THEN ch := CAP(ch) END;
				w.Char(ch)
			END
		END;
		w.String(" iopl"); w.Int(ASH(SYSTEM.VAL(LONGINT, s * {12,13}), -12), 1)
	END Flags;

	(** Display trap state. *)
	PROCEDURE  Show*(p: Objects.Process; VAR int: Machine.State; VAR exc: Machine.ExceptionState; long: BOOLEAN);
	VAR id: LONGINT; overflow: BOOLEAN; w: Streams.Writer;

		PROCEDURE Val(CONST s: ARRAY OF CHAR; val: HUGEINT);
		BEGIN
			w.Char(" "); w.String(s); w.Char("="); w.Hex(val, -8)
		END Val;

	BEGIN
		overflow := FALSE;
		w := TrapWriters.GetWriter();
		w.Update;	(* flush previous output stuck in global writer w *)
		w.Char(1X);	(* "start of trap" *)
		id := Machine.ID();
		INC(trapState[id]);
		IF trapState[id] > RecursiveLimit THEN
			w.String(" [Recursive TRAP]")
		ELSE
			(* output first line *)
			w.String("["); w.Int(trapState[id], 1); w.String("] ");
			w.String("TRAP "); w.Int(SHORT(exc.halt), 1);
			w.String(" PL"); w.Int(SHORT(int.CS) MOD 4, 2); w.Char(" ");
			CASE exc.halt OF
				-14:	(* page fault *)
					IF (int.CS MOD 4 > Machine.KernelLevel) & (exc.pf+4 = int.SP) THEN
						w.String("stack overflow"); overflow := TRUE
					END
				|0: w.String("division error")
				|1: w.String("WITH guard failed")
				|2: w.String("CASE invalid")
				|3: w.String("RETURN missing")
				|4: w.String("integer overflow")
				|5: w.String("implicit type guard failed")
				|6: w.String("type guard failed")
				|7: w.String("index out of range")
				|8: w.String("ASSERT failed")
				|9: w.String("array dimension error")
				|14: w.String("out of memory")
				|16: w.String("procedure returned")
				ELSE
					IF (exc.halt > MAX(INTEGER)+1) OR (exc.halt < MIN(INTEGER)) THEN
						w.String("module freed?")
					END
			END;
			IF exc.locks # {} THEN
				w.String(", Locks: "); w.Set(exc.locks)
			END;
			w.Char(" "); w.String(Machine.version);
			IF long THEN
				w.Char(0EX);	(* "fixed font" *)
				w.Ln;
				(* output values *)
				Val("CS:", int.CS); Val("CR0", exc.CR[0]);
				Val("FPU", SYSTEM.VAL(LONGINT, exc.FPU[1] * {0..15} + LSH(exc.FPU[2], 16))); w.Ln;
				Val("PC", int.PC); Val("RSI", int.RSI); Val("RDI", int.RDI); Val("SP", exc.SP); Val("CR2", exc.CR[2]);
				Val("PID", id); w.Ln;
				Val("RAX", int.RAX); Val("RBX", int.RBX); Val("RCX", int.RCX); Val("RDX", int.RDX); Val("CR3", exc.CR[3]);
				Val("LCK", SYSTEM.VAL(LONGINT, exc.locks)); w.Ln;
				Val("BP", int.BP); Val("ERR", int.ERR); Val("CR4", exc.CR[4]);
				Val("TMR", Kernel.GetTicks()); w.Ln;
				IF SYSTEM.VAL(CHAR, exc.DR[7]) # 0X THEN	(* some breakpoints enabled *)
					Val("DR0", exc.DR[0]); Val("DR1", exc.DR[1]); Val("DR2", exc.DR[2]); Val("DR3", exc.DR[3]);
					Val("DR6", exc.DR[6]); Val("DR7", exc.DR[7]); w.Ln
				END;
				w.String(" FLAGS: "); Flags(w, int.FLAGS);
				w.Char(0FX);	(* "proportional font" *)
				w.Char(" "); w.Set(int.FLAGS); w.Ln;
				(*IF int.INT = Machine.UD THEN KernelLog.Memory(int.PC, 16) END*)	(* show bad instruction *)
			ELSE
				w.Ln
			END;
			w.String("Process:"); Reflection.WriteProcess(w, p); w.Ln;
			(*IF exc.halt = 1301 THEN	(* lock timeout - see Machine *)
				KernelLog.Memory(ADDRESSOF(Machine.trapState[0]), LEN(Machine.trapState) *
					(ADDRESSOF(Machine.trapState[1]) - ADDRESSOF(Machine.trapState[0])));
				w.Hex(SYSTEM.VAL(LONGINT, Machine.trapLocksBusy), 8); w.Ln
			END;
			IF (int.INT = Machine.PF) & (ABS(int.PC-exc.CR[2]) < 100H) THEN	(* PF close to PC *)
				KernelLog.Memory(int.ESP-16, 64)	(* show stack *)
			END;*)
			Reflection.StackTraceBack(w, int.PC, int.BP, Objects.GetStackBottom(p), long, overflow);
		END;
		w.String("---------------------------------"); w.Ln;
		w.Char(02X);	(* "end of trap" *)
		w.Update;
		TrapWriters.Trapped();
		trapState[id] := 0
	END Show;

	PROCEDURE SetLastExceptionState(ex: Machine.ExceptionState);
	VAR id: LONGINT;
	BEGIN
		id := Machine.AcquirePreemption();
		Objects.running[id].exp := ex;
		Machine.ReleasePreemption;
	END SetLastExceptionState;

	PROCEDURE GetLastExceptionState*(): Machine.ExceptionState;
	VAR
		id: LONGINT;
		ex: Machine.ExceptionState;
	BEGIN
		id := Machine.AcquirePreemption();
		ex := Objects.running[id].exp;
		Machine.ReleasePreemption;
		RETURN ex;
	END GetLastExceptionState;

	(**  Handles an exception. Interrupts are on during this procedure. *)
	PROCEDURE HandleException(VAR int: Machine.State; VAR exc: Machine.ExceptionState; VAR handled: BOOLEAN);
	VAR
		bp, sp, pc, handler: ADDRESS;
	BEGIN
		bp := int.BP; sp := int.SP; pc := int.PC;
		handler := Modules.GetExceptionHandler(pc);
	 	IF handler # -1 THEN (* Handler in the current PAF *)
			int.PC := handler; handled := TRUE;
			SetTrapVariable(pc, bp); SetLastExceptionState(exc)
		ELSE
			WHILE (bp # 0) & (handler = -1) DO
				SYSTEM.GET(bp + 4, pc);
				pc := pc - 1; (*  CALL instruction, machine dependant!!! *)
				handler := Modules.GetExceptionHandler(pc);
				sp :=  bp; (* Save the old basepointer into the stack pointer *)
				SYSTEM.GET(bp, bp) (* Unwind PAF *)
			END;
			IF handler = -1 THEN
				handled := FALSE;
			ELSE
				int.PC := handler; int.BP := bp; int.SP := sp;
				SetTrapVariable(pc, bp); SetLastExceptionState(exc);
				handled := TRUE
			END
		END
	END HandleException;

	PROCEDURE SetTrapVariable(pc, fp: ADDRESS);
	VAR
		varadr: ADDRESS;
	BEGIN
		varadr := Reflection.GetVariableAdr(pc, fp, "trap");
		IF varadr # -1 THEN
			SYSTEM.PUT8(varadr, 1)
		END
	END SetTrapVariable;

	(* Unbreakable stack trace back with regard to every FINALLY on the way *)
	PROCEDURE Unbreakable(p: Objects.Process; VAR int: Machine.State; VAR exc: Machine.ExceptionState; VAR handled: BOOLEAN);
	VAR
		bp, bpSave, pc, handler, bpBottom:ADDRESS;
		hasFinally : BOOLEAN;
	BEGIN
		bp := int.BP;
		pc := int.PC;
		hasFinally := FALSE;

		handler := Modules.GetExceptionHandler(pc);

		(* Handler in the current PAF *)
	 	IF handler # -1 THEN
			int.PC := handler;
			hasFinally := TRUE;
			SetTrapVariable(pc, bp);
		END;

		(* The first waypoint is the bp of the top PAF *)
		bpSave := bp;

		WHILE (bp # 0) DO
			(* Did we reach the last PAF? *)
			SYSTEM.GET(bp, pc);
			IF (pc = 0) THEN
				bpBottom := bp; (* Save the FP of the last PAF *)
			END;

			(* Get the return pc *)
			SYSTEM.GET(bp + SIZEOF(ADDRESS), pc);

			handler := Modules.GetExceptionHandler(pc);

			(* Save the last framepointer as stackpointer *)
			IF ~hasFinally THEN
				int.SP :=  bp;
			END;

			SYSTEM.GET(bp, bp);

			(* Here bp may be 0. *)

			IF (handler # -1) & (bp # 0)  THEN (* If Objects.Terminate has a FINALLY this doesn't work !!! *)
				IF hasFinally THEN
					(* Connect Finally to Finally *)
					SYSTEM.PUT(bpSave + SIZEOF(ADDRESS), handler); (* Adapt the return pc *)
					SYSTEM.PUT(bpSave, bp); (* Adapt the dynamic link *)
					bpSave := bp;
				ELSE
					int.PC := handler;
					int.BP := bp;
					bpSave := bp;
					hasFinally := TRUE;
				END;
				SetTrapVariable(pc, bp)
			END
		END;

		(* Now bp =  0, bottom of the stack, so link the last known return PC to the Termination *)
		IF ~hasFinally THEN
			SYSTEM.GET(bpBottom + SIZEOF(ADDRESS), pc); (* PC of the Terminate *)
			int.PC := pc;
			int.BP := bpBottom;
		ELSIF bpSave # bpBottom THEN
			SYSTEM.GET(bpBottom + SIZEOF(ADDRESS), pc); (* PC of the Terminate *)
			SYSTEM.PUT(bpSave + SIZEOF(ADDRESS), pc);
			SetLastExceptionState(exc)
		END;

		handled := TRUE; (* If FALSE the process could be restarted, may be this is the meaning? *)

	END Unbreakable;

	(* General exception handler. *)
	PROCEDURE Exception(VAR int: Machine.State);
	VAR t: Objects.Process; exc: Machine.ExceptionState; user, traceTrap, handled: BOOLEAN;
	BEGIN	(* interrupts off *)
		t := Objects.running[Machine.ID()];	(* t is running process *)
		handled := FALSE;
		Machine.GetExceptionState(int, exc);
		user := (int.CS MOD 4 > Machine.KernelLevel);
		traceTrap := (exc.locks = {}) & (exc.halt >= MAX(INTEGER)) & (exc.halt <= MAX(INTEGER)+1);

		Show(t, int, exc, exc.halt # MAX(INTEGER)+1);	(* Always show the trap info!*)

		IF exc.halt = haltUnbreakable THEN
			Unbreakable(t, int, exc, handled)
		ELSIF ~ traceTrap THEN
			HandleException( int, exc, handled)
		END;

		IF ~handled THEN
			(* Taken from Machine to allow the FINALLY in the kernel *)
			exc.locks := Machine.BreakAll();
			Machine.Sti();
			IF ~traceTrap THEN	(* trap *)
				IF user THEN	(* return to outer level *)
					IF TraceVerbose THEN
						KernelLog.Enter;
						KernelLog.String("Jump");  KernelLog.Hex(t.restartPC, 9);
						KernelLog.Hex(t.restartSP, 9);  KernelLog.Hex(t.stack.high, 9);
						KernelLog.Exit
					END;
					INCL(int.FLAGS, Machine.IFBit);	(* enable interrupts *)
					int.BP := 0; int.SP := t.restartSP;	(* reset stack *)
					int.PC := t.restartPC;	(* restart object body or terminate *)
				ELSE	(* trap was in kernel (interrupt handler) *)	(* fixme: recover from trap in stack traceback *)
					KernelLog.Enter;  KernelLog.String("Kernel halt");  KernelLog.Exit;
					Machine.Shutdown(FALSE)
				END
			END
		END;

		IF Objects.PleaseHalt IN t.flags THEN
			EXCL(t.flags, Objects.PleaseHalt);
			IF Objects.Unbreakable IN t.flags THEN EXCL(t.flags, Objects.Unbreakable) END;
			IF Objects.SelfTermination IN t.flags THEN EXCL(t.flags, Objects.SelfTermination) END
		END
	END Exception;

	(* Page fault handler. *)
	PROCEDURE PageFault(VAR state: Machine.State);
	VAR t: Objects.Process;
	BEGIN
		t := Objects.running[Machine.ID()];
		IF Machine.IFBit IN state.FLAGS THEN	(* enable interrupts again if they were enabled *)
			Machine.Sti()	(* avoid Processors.StopAll deadlock when waiting for locks below (fixme: remove) *)
		END;
		IF (t = NIL) OR ~Machine.ExtendStack(t.stack, Machine.CR2()) THEN
			IF TraceVerbose THEN
				IF t = NIL THEN
					KernelLog.Enter;  KernelLog.String("GrowStack running=NIL");
					KernelLog.Hex(state.PC, 9);  KernelLog.Exit
				ELSE
					KernelLog.Enter;
					KernelLog.String("GrowStack failed, pf="); KernelLog.Hex(Machine.CR2(), 8);
					KernelLog.String(" adr="); KernelLog.Hex(t.stack.adr, 8);
					KernelLog.String(" high="); KernelLog.Hex(t.stack.high, 8);
					(*KernelLog.Ln; KernelLog.Memory(t.stack.adr, 256);*)
					KernelLog.Exit
				END
			END;
			Exception(state)
		ELSE
			IF TraceVerbose THEN
				KernelLog.Enter;  KernelLog.String("GrowStack");
				KernelLog.Hex(t.stack.adr, 9);  KernelLog.Hex(t.stack.high, 9);  KernelLog.Exit
			END
		END
	END PageFault;

	PROCEDURE Init;
	VAR i: LONGINT; s: ARRAY 8 OF CHAR;
	BEGIN
		IF TestTrap THEN
			Machine.GetConfig("TestTrap", s);
			IF s[0] = "1" THEN HALT(98) END
		END;
		FOR i := 0 TO Machine.MaxCPU-1 DO trapState[i] := 0 END;
		Machine.InstallHandler(PageFault, Machine.PF);
		FOR i := 0 TO 31 DO
			IF ~(i IN {Machine.PF}) THEN	(* PF handler above *)
				Machine.InstallHandler(Exception, i)
			END
		END;
		IF TestTrap & (s[0] = "2") THEN HALT(99) END
	END Init;

BEGIN
	modes := " rdy run awl awc awe rip";	(* 4 characters per mode from Objects.Ready to Objects.Terminated *)
	flags := "c!p!a!zstido";	(* bottom flags, !=reserved *)
	Init
END Traps.

(*
12.03.1998	pjm	Started
06.08.1998	pjm	Exported Show and removed AosException upcall installation & Modules lock
10.12.1998	pjm	New refblk
23.06.1999	pjm	State added
*)

(*
to do:
o stack overflow message is not correctly displayed in case of dynamic arrays (EDI = CR2, ESP # CR2)
o fix KernelLog.Memory calls removed when switching to Streams
o fix use of KernelLog lock in Show
o if allowing modification of variables using their descriptors, it should also have reference to module to avoid gc after free.
*)
