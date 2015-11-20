MODULE Traps;	(** AUTHOR "pjm"; PURPOSE "Trap handling and symbolic debugging"; *)

IMPORT SYSTEM, Machine, KernelLog, Streams, Modules, Objects, Kernel, Reflection, TrapWriters;

CONST
	RecursiveLimit = 2;		(* normally 1 or 2 - how many recursive traps to display before stopping *)
	TraceVerbose = FALSE;
	TestTrap = TRUE;

	(* Process termination halt codes *)
	halt* = Objects.halt;
	haltUnbreakable* = Objects.haltUnbreakable;

	(** Trap Numbers -- Do not modify: these are related to the compiler code generation. *)
(*
		WithTrap* = 1; (* generated when a WITH statement fails *)
		CaseTrap* = 2; (* generated when a case statement without else block fails *)
		ReturnTrap* = 3;
		TypeEqualTrap* = 5;
		TypeCheckTrap* = 6;
		IndexCheckTrap* = 7; (* generated when index is out of bounds or range is invalid *)
		AssertTrap* = 8; (* generated when an assert fails *)
		ArraySizeTrap* = 9;
		ArrayFormTrap*=10; (* indicates that array cannot be (re-)allocated since shape, type or size does not match *)
		SetElementTrap*=11; (* indicates that a set element is out of MIN(SET)...MAX(SET) *)
		NegativeDivisorTrap*=12;
		NoReturnTrap*=16; (* indicates that a procedure marked no return did return *)

		ELSIF code = 13 THEN StrAppend( desc, "Keyboard interrupt" )
		ELSIF code = 14 THEN StrAppend( desc, "Out of memory" )
		ELSIF code = 15 THEN StrAppend( desc, "Deadlock (active objects)" );
		ELSIF code = 16 THEN StrAppend( desc, "Procedure returned" );
		ELSIF code = 23 THEN StrAppend( desc, "Exceptions.Raise" )
*)

	DivisionError = 0;
	WithError = 1;						(* Compiler generated *)
	CaseError = 2;						(* Compiler generated *)
	ReturnError = 3;					(* Compiler generated *)
	IntOverflow = 4;
	ImplicitTypeGuardError = 5;		(* Compiler generated *)
	TypeGuardError = 6;				(* Compiler generated *)
	IndexOutOfRange = 7;				(* Compiler generated *)
	AssertError = 8;					(* Compiler generated *)
	ArraySize = 9;						(* Compiler generated *)
	ArrayForm = 10;					(* Compiler generated *)
	SetElement = 11;					(* Compiler generated *)
	NegativeDivisor = 12;				(* Compiler generated *)
	KeyboardInt = 13;
	OutOfMemory = 14;
	Deadlock = 15;
	ProcedureReturned = 16;			(* Compiler generated *)
	UndefinedInstn = 17;				(* ARM specific *)
	NilPointer = 18;					(* ARM specific *)
	MemoryError = 19;				(* ARM specific *)
	ExceptionRaised = 23;
	ProcessResurrected = 2201;
	RecursiveExclusive = 2203;
	AwaitOutsideExclusive = 2204;

	(** Trap descriptions, human-readable *)
(*
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
*)
	DivisionErrorDesc = "division error";
	WithErrorDesc = "WITH guard failed";
	CaseErrorDesc = "CASE invalid";
	ReturnErrorDesc = "RETURN missing";
	IntOverflowDesc = "integer overflow";
	ImplicitTypeGuardErrorDesc = "implicit type guard failed";
	TypeGuardErrorDesc = "type guard failed";
	IndexOutOfRangeDesc = "index out of range";
	AssertErrorDesc = "ASSERT failed";
	ArraySizeDesc = "array dimension error";
	ArrayFormDesc = "invalid array shape";
	SetElementDesc = "invalid SET element";
	NegativeDivisorDesc = "negative divisor";
	KeyboardIntDesc = "keyboard interrupt";
	OutOfMemoryDesc = "out of memory";
	DeadlockDesc = "deadlock";
	ProcedureReturnedDesc = "procedure returned";
	UndefinedInstnDesc = "undefined instruction";
	NilPointerDesc = "NIL pointer";
	MemoryErrorDesc = "invalid memory location";
	ExceptionRaisedDesc = "exception";
	ProcessResurrectedDesc = "process resurrected";
	RecursiveExclusiveDesc = "recursive entrance in EXCLUSIVE section";
	AwaitOutsideExclusiveDesc = "AWAIT statement outside EXCLUSIVE section";	

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
			w.String("TRAP "); w.Int(SHORT(exc.halt), 1); w.String(" ");
			CASE exc.halt OF
				 DivisionError: w.String(DivisionErrorDesc)
				|WithError: w.String(WithErrorDesc)
				|CaseError: w.String(CaseErrorDesc)
				|ReturnError: w.String(ReturnErrorDesc)
				|IntOverflow: w.String(IntOverflowDesc)
				|ImplicitTypeGuardError: w.String(ImplicitTypeGuardErrorDesc)
				|TypeGuardError: w.String(TypeGuardErrorDesc)
				|IndexOutOfRange: w.String(IndexOutOfRangeDesc)
				|AssertError: w.String(AssertErrorDesc)
				|ArraySize: w.String(ArraySizeDesc)
				|ArrayForm: w.String(ArrayFormDesc)
				|SetElement: w.String(SetElementDesc)
				|NegativeDivisor: w.String(NegativeDivisorDesc)
				|KeyboardInt: w.String(KeyboardIntDesc)
				|OutOfMemory: w.String(OutOfMemoryDesc)
				|Deadlock: w.String(DeadlockDesc)
				|ProcedureReturned: w.String(ProcedureReturnedDesc)
				|UndefinedInstn: w.String(UndefinedInstnDesc); w.String(": "); w.Hex(exc.instn,-8)
				|NilPointer: w.String(NilPointerDesc)
				|MemoryError: w.String(MemoryErrorDesc); w.String(" at "); w.Address(exc.pf)
				|ExceptionRaised: w.String(ExceptionRaisedDesc)
				|ProcessResurrected: w.String(ProcessResurrectedDesc)
				|RecursiveExclusive: w.String(RecursiveExclusiveDesc)
				|AwaitOutsideExclusive: w.String(AwaitOutsideExclusiveDesc)
			ELSE
				w.String("HALT statement: ");
				w.Int(exc.halt, 0)
			END;
			IF exc.locks # {} THEN
				w.String(", Locks: "); w.Set(exc.locks)
			END;
			w.Char(" "); w.String(Machine.version);
			IF long THEN
				w.Char(0EX);	(* "fixed font" *)
				w.Ln;
				(* output values *)
				Val("R0", int.R[0]); Val("R1", int.R[1]); Val("R2", int.R[2]); Val("R3", int.R[3]);
				Val("R4", int.R[4]); Val("R5", int.R[5]); Val("R6", int.R[6]); Val("R7", int.R[7]);
				Val("R8", int.R[8]); Val("R9", int.R[9]); Val("R10", int.R[10]); Val("R11", int.R[11]);
				Val("FP", int.BP); Val("SP", int.SP); Val("LR", int.LR); Val("PC", int.PC);
				Val("PSR", int.PSR);
				Val("TMR", Kernel.GetTicks()); w.Ln
			ELSE
				w.Ln
			END;
			IF exc.halt = UndefinedInstn THEN
				Val("Instruction", exc.instn)
			ELSIF exc.halt = MemoryError THEN
				Val("Location", exc.pf);
				IF exc.status # - 1 THEN
					Val("Status", exc.status)
				END
			END;
			w.String("Process:"); Reflection.WriteProcess(w, p); w.Ln;
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
		user := TRUE;
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
			Machine.EnableInterrupts();
			IF ~traceTrap THEN	(* trap *)
				IF user THEN	(* return to outer level *)
					IF TraceVerbose THEN
						KernelLog.Enter;
						KernelLog.String("Jump");  KernelLog.Hex(t.restartPC, 9);
						KernelLog.Hex(t.restartSP, 9);  KernelLog.Hex(t.stack.high, 9);
						KernelLog.Exit
					END;
					(*INCL(int.FLAGS, Machine.IFBit);	(* enable interrupts *)*)
					int.BP := t.restartSP; int.SP := t.restartSP;	(* reset stack *)
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
	VAR
		t: Objects.Process;
		adr: ADDRESS;
		ignored: LONGINT;
	BEGIN
		t := Objects.running[Machine.ID()];
		Machine.GetPageFault(adr, ignored);
		(*IF Machine.IFBit IN state.FLAGS THEN	(* enable interrupts again if they were enabled *)
			Machine.Sti()	(* avoid Processors.StopAll deadlock when waiting for locks below (fixme: remove) *)
		END;*)
		IF adr > 4096 THEN
			(* Not a NIL pointer, maybe stack overflow? *)
			IF (t = NIL) OR ~Machine.ExtendStack(t.stack, adr) THEN
				IF TraceVerbose THEN
					IF t = NIL THEN
						KernelLog.Enter;  KernelLog.String("GrowStack running=NIL");
						KernelLog.Hex(state.PC, 9);  KernelLog.Exit
					ELSE
						KernelLog.Enter;
						KernelLog.String("GrowStack failed, pf="); KernelLog.Hex(adr, 8);
						KernelLog.String(" adr="); KernelLog.Hex(t.stack.adr, 8);
						KernelLog.String(" high="); KernelLog.Hex(t.stack.high, 8);
						KernelLog.Exit
					END
				END;
				Exception(state)
			ELSE
				IF TraceVerbose THEN
					KernelLog.Enter;  KernelLog.String("GrowStack");
					KernelLog.Hex(t.stack.adr, 9);  KernelLog.Hex(t.stack.high, 9);  KernelLog.Exit
				END
			END;
		ELSE
			Exception(state)
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

		Machine.InstallExceptionHandler(PageFault, Machine.Data);
		Machine.InstallExceptionHandler(PageFault, Machine.Prefetch);
		Machine.InstallExceptionHandler(Exception, Machine.Undef);
		Machine.InstallExceptionHandler(Exception, Machine.Swi);
		Machine.InstallExceptionHandler(Exception, Machine.Fiq);
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
