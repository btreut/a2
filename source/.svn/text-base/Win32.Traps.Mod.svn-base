(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Traps;   (** AUTHOR "pjm"; PURPOSE "Trap handling and symbolic debugging"; *)

IMPORT SYSTEM, Kernel32, Machine, TrapWriters,  KernelLog, Streams, Modules, Objects, Kernel,  Reflection, SystemVersion;

CONST
	RecursiveLimit = 16;   (* normally 1 or 2 - how many recursive traps to display before stopping *)
	TraceVerbose = FALSE;  TestTrap = TRUE;
	TrapMaxCharacters = 32*1024;
	(* Process termination halt codes *)
	halt* = Objects.halt;  haltUnbreakable* = Objects.haltUnbreakable;

TYPE


VAR
	modes: ARRAY 25 OF CHAR;
	flags: ARRAY 13 OF CHAR;
	trapState: LONGINT;
	check: Objects.Process;
	(* Get a compressed refblk number. *)

	(** Display trap state. *)
	PROCEDURE Show*( p: Objects.Process;  VAR int: Kernel32.Context;  VAR exc: Kernel32.ExceptionRecord;  long: BOOLEAN );
	VAR  overflow: BOOLEAN;
		desc: ARRAY 128 OF CHAR;
		code: LONGINT;
		pc: LONGINT; (*ALEX 2005.12.08*)
		w: Streams.Writer;

		(* Write flag values. *)
		PROCEDURE Flags( w: Streams.Writer;  s: SET );
		VAR i: SHORTINT;  ch: CHAR;
		BEGIN
			FOR i := 0 TO 11 DO
				ch := flags[i];
				IF ch # "!" THEN
					IF i IN s THEN ch := CAP( ch ) END;
					w.Char( ch )
				END
			END;
			w.String( " iopl" );  w.Int( ASH( SYSTEM.VAL( LONGINT, s * {12, 13} ), -12 ), 1 )
		END Flags;

		PROCEDURE Val( CONST s: ARRAY OF CHAR;  val: LONGINT );
		BEGIN
			w.Char( " " );  w.String( s );  w.Char( "=" );  w.Hex( val, -8 )
		END Val;
	(** Append this to to. *)
		PROCEDURE StrAppend( VAR to (** in/out *) : ARRAY OF CHAR;  CONST this: ARRAY OF CHAR );
		VAR i, j, l: LONGINT;
		BEGIN
			i := 0;
			WHILE to[i] # 0X DO INC( i ) END;
			l := LEN( to ) - 1;  j := 0;
			WHILE (i < l) & (this[j] # 0X) DO to[i] := this[j];  INC( i );  INC( j ) END;
			to[i] := 0X
		END StrAppend;

	(** Convert an integer into a string. *)
		PROCEDURE StrIntToStr( val: LONGINT;  VAR str: ARRAY OF CHAR );
		VAR i, j: LONGINT;
			digits: ARRAY 16 OF LONGINT;
		BEGIN
			IF val = MIN( LONGINT ) THEN COPY( "-2147483648", str );  RETURN END;
			IF val < 0 THEN val := -val;  str[0] := "-";  j := 1 ELSE j := 0 END;
			i := 0;
			REPEAT digits[i] := val MOD 10;  INC( i );  val := val DIV 10 UNTIL val = 0;
			DEC( i );
			WHILE i >= 0 DO str[j] := CHR( digits[i] + ORD( "0" ) );  INC( j );  DEC( i ) END;
			str[j] := 0X
		END StrIntToStr;

		PROCEDURE GetDescription;
		VAR	code : LONGINT; arg: ARRAY 16 OF CHAR;
		BEGIN
			IF exc.ExceptionCode = Kernel32.ExceptionGuardPage THEN COPY( "guard page violation", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionBreakPoint THEN
				SYSTEM.GET( int.SP, code );  StrIntToStr( code, desc );  StrAppend( desc, "  " );
				IF code = 1 THEN StrAppend( desc, "WITH guard failed" )
				ELSIF code = 2 THEN StrAppend( desc, "CASE invalid" )
				ELSIF code = 3 THEN StrAppend( desc, "RETURN missing" )
				ELSIF code = 5 THEN StrAppend( desc, "Implicit type guard failed" )
				ELSIF code = 6 THEN StrAppend( desc, "Type guard failed" )
				ELSIF code = 7 THEN StrAppend( desc, "Index out of range" )
				ELSIF code = 8 THEN StrAppend( desc, "ASSERT failed" )
				ELSIF code = 9 THEN StrAppend( desc, "Array dimension error" )
				ELSIF code=10 THEN StrAppend(desc, "Array allocation error" ); (* fof *)
				ELSIF code = 13 THEN StrAppend( desc, "Keyboard interrupt" )
				ELSIF code = 14 THEN StrAppend( desc, "Out of memory" )
				ELSIF code = 15 THEN StrAppend( desc, "Deadlock (active objects)" );
				ELSIF code = 16 THEN StrAppend( desc, "Procedure returned" );
				ELSIF code = 23 THEN StrAppend( desc, "Exceptions.Raise" )
				ELSE StrAppend( desc, "HALT statement" )
				END
			ELSIF exc.ExceptionCode = Kernel32.ExceptionSingleStep THEN COPY( "single step", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionAccessViolation THEN COPY( "access violation", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionIllegalInstruction THEN COPY( "illegal instruction", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionArrayBoundsExceeded THEN COPY( "index out of range", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionFltDenormalOperand THEN COPY( "FPU: denormal operand", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionFltDivideByZero THEN COPY( "FPU: divide by zero", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionFltInexactResult THEN COPY( "FPU: inexact result", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionFltInvalidOperation THEN COPY( "FPU: invalid operation", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionFltOverflow THEN COPY( "FPU: overflow", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionFltStackCheck THEN COPY( "FPU: stack check", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionFltUndeflow THEN COPY( "FPU: undeflow", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionIntDivideByZero THEN COPY( "integer division by zero", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionIntOverflow THEN COPY( "integer overflow", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionPrivInstruction THEN COPY( "privileged instruction", desc )
			ELSIF exc.ExceptionCode = Kernel32.ExceptionStackOverflow THEN COPY( "stack overflow", desc )
			ELSE StrIntToStr( exc.ExceptionCode, arg );  COPY( "exception ", desc );  StrAppend( desc, arg )
			END
		END GetDescription;

	BEGIN
		overflow := FALSE;
		Machine.Acquire( Machine.KernelLog );   (* like KernelLog.Enter, but without output *)
		w := TrapWriters.GetWriter();
		w.Update;   (* flush previous output stuck in global writer w *)
		w.Char( 1X );   (* "start of trap" *)

		INC( trapState );
		IF trapState > RecursiveLimit THEN w.String( " [Recursive TRAP]" );
			trapState := 0;
		ELSE
			(* output first line *)
			SYSTEM.GET( int.SP, code );

			w.String( "TRAP " );  w.Int( code, 1 ); w.String( " [" );  w.Int( trapState, 1 );  w.String( "]" );   w.String( " PL" );
			w.Int( int.CS MOD 4, 2 );  w.Char( " " );  GetDescription();
			(*
		CASE exc.halt OF
			-14:	(* page fault *)
				IF (int.CS MOD 4 > Machine.KernelLevel) & (exc.pf+4 = int.ESP) THEN
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
			ELSE
				IF (exc.halt > MAX(INTEGER)+1) OR (exc.halt < MIN(INTEGER)) THEN
					w.String("module freed?")
				END
		END;
		*)
			w.String( desc );  	w.Ln;		w.Update;

			(*
		IF exc.locks # {} THEN
			w.String(", Locks: "); w.Set(exc.locks)
		END;
		*)
			w.String( "System: " );  w.String( Machine.version ); 
			w.String(" Kernel_CRC="); w.Hex(SystemVersion.BootCRC,8); 
			w.String(" Uptime="); w.Hex(Machine.GetTimer()- Machine.boottime, 8);
			(*w.String( " Uptime=" );  w.Hex(Machine.GetTimer()-Machine.boottime, -8);*)
			IF long THEN
				w.Char( 0EX );   (* "fixed font" *)
				w.Ln;
				w.String("Processor:");
				(* output values *)
				Val( "CS", int.CS );  Val( "DS", int.DS );  Val( "ES", int.ES );  Val( "SS", int.SS );   (* Val("CR0", int.CR[0]);*)
				(*
			Val("FPU", SYSTEM.VAL(LONGINT, int.FPU[1] * {0..15} + LSH(int.FPU[2], 16))); w.Ln;
			*)

				Val( "PC", int.PC );  Val( "ESI", int.ESI );  Val( "EDI", int.EDI );  Val( "ESP", int.SP );
				(*
			Val("CR2", int.CR[2]);
			*)
				Val( "PID", p.id ); Val( "EAX", int.EAX );  Val( "EBX", int.EBX );  Val( "ECX", int.ECX );  Val( "EDX", int.EDX );
				(*
			Val("CR3", int.CR[3]);
			Val("LCK", SYSTEM.VAL(LONGINT, int.locks)); w.Ln;
			*)
				Val( "EBP", int.BP );  Val( "FS", int.FS );  Val( "GS", int.GS );   (* Val("ERR", int.ERR); Val("CR4", int.CR[4]); *)
				Val( "TMR", Kernel.GetTicks() ); (* w.Ln;*)
				IF SYSTEM.VAL( CHAR, int.DR7 ) # 0X THEN  (* some breakpoints enabled *)
					Val( "DR0", int.DR0 );  Val( "DR1", int.DR1 );  Val( "DR2", int.DR2 );  Val( "DR3", int.DR3 );  Val( "DR6", int.DR6 );
					Val( "DR7", int.DR7 );  w.Ln
				END;
				w.Ln; w.String( " FLAGS: " );  Flags( w, SYSTEM.VAL( SET, int.FLAGS ) );
				w.Char( 0FX );   (* "proportional font" *)
				w.Char( " " );  w.Set( SYSTEM.VAL( SET, int.FLAGS ) );  w.Ln;
				w.String(" Features="); w.Set(Machine.features); w.Set(Machine.features2); w.Ln;
				(*IF int.INT = Machine.UD THEN KernelLog.Memory(int.PC, 16) END*)  (* show bad instruction *)
			ELSE w.Ln
			END;
			w.Update;

			w.String( "Process:" );  Reflection.WriteProcess( w, p );  w.Ln;
			(*IF exc.halt = 1301 THEN	(* lock timeout - see Machine *)
			KernelLog.Memory(ADDRESSOF(Machine.trapState[0]), LEN(Machine.trapState) *
				(ADDRESSOF(Machine.trapState[1]) - ADDRESSOF(Machine.trapState[0])));
			w.Hex(SYSTEM.VAL(LONGINT, Machine.trapLocksBusy), 8); w.Ln
		END;
		IF (int.INT = Machine.PF) & (ABS(int.PC-exc.CR[2]) < 100H) THEN	(* PF close to EIP *)
			KernelLog.Memory(int.ESP-16, 64)	(* show stack *)
		END;*)
				(*ALEX 2005.12.08 when calling a pointer to a function and the pointer is NULL meaning eip=NULL*)
			IF int.PC = 0 THEN SYSTEM.GET( int.SP, pc ) ELSE pc := int.PC END;
			w.String( "StackTraceBack:" );  w.Ln;
			Reflection.StackTraceBack( w, pc, int.BP, Objects.GetStackBottom(p), long, overflow )
		END;
		w.String("---------------------------------"); w.Ln;
		w.Char(02X);	(* "end of trap" *)
		w.Update;
		TrapWriters.Trapped;
	FINALLY
		Machine.Release( Machine.KernelLog );   (* like KernelLog.Exit, but without output *)
		trapState := 0
	END Show;

	PROCEDURE SetLastExceptionState( ex: Kernel32.Context );
	(*
	VAR id: LONGINT;
	BEGIN
	id := Machine.AcquirePreemption();
	Objects.running[id].exp := ex;
	Machine.ReleasePreemption();
	*)
	END SetLastExceptionState;


	(**  Handles an exception. Interrupts are on during this procedure. *)
	PROCEDURE HandleException( VAR int: Kernel32.Context;  VAR exc: Kernel32.ExceptionRecord;  VAR handled: BOOLEAN );
	VAR fp, sp, pc, handler: LONGINT;
	BEGIN
		fp := int.BP;  sp := int.SP;  pc := int.PC;  handler := Modules.GetExceptionHandler( pc );
		IF handler # -1 THEN  (* Handler in the current PAF *)
			int.PC := handler;  handled := TRUE;  SetTrapVariable( pc, fp );  SetLastExceptionState( int )
		ELSE
			WHILE (fp # 0) & (handler = -1) DO
				SYSTEM.GET( fp + 4, pc );
				pc := pc - 1;   (*  CALL instruction, machine dependant!!! *)
				handler := Modules.GetExceptionHandler( pc );
				sp := fp;   (* Save the old framepointer into the stack pointer *)
				SYSTEM.GET( fp, fp ) (* Unwind PAF *)
			END;
			IF handler = -1 THEN handled := FALSE;
			ELSE
				int.PC := handler;  int.BP := fp;  int.SP := sp;  SetTrapVariable( pc, fp );
				SetLastExceptionState( int );  handled := TRUE
			END
		END
	END HandleException;

	PROCEDURE SetTrapVariable( pc, fp: LONGINT );
	VAR varadr: LONGINT;
	BEGIN
		varadr := Reflection.GetVariableAdr( pc, fp, "trap" );
		IF varadr # -1 THEN SYSTEM.PUT8( varadr, 1 ) END
	END SetTrapVariable;

	(* Unbreakable stack trace back with regard to every FINALLY on the way *)
	PROCEDURE Unbreakable( p: Objects.Process;  VAR int: Kernel32.Context;  VAR exc: Kernel32.ExceptionRecord;
											 VAR handled: BOOLEAN );
	VAR ebp, ebpSave, pc, handler, ebpBottom: LONGINT;  hasFinally: BOOLEAN;
	BEGIN
		ebp := int.BP;  pc := int.PC;  hasFinally := FALSE;

		handler := Modules.GetExceptionHandler( pc );

		(* Handler in the current PAF *)
		IF handler # -1 THEN int.PC := handler;  hasFinally := TRUE;  SetTrapVariable( pc, ebp );  END;

		(* The first waypoint is the ebp of the top PAF *)
		ebpSave := ebp;

		WHILE (ebp # 0) DO
			(* Did we reach the last PAF? *)
			SYSTEM.GET( ebp, pc );
			IF (pc = 0) THEN
				ebpBottom := ebp;   (* Save the FP of the last PAF *)
			END;

			(* Get the return pc *)
			SYSTEM.GET( ebp + 4, pc );

			handler := Modules.GetExceptionHandler( pc );

			(* Save the last framepointer as stackpointer *)
			IF ~hasFinally THEN int.SP := ebp;  END;

			SYSTEM.GET( ebp, ebp );

			(* Here ebp may be 0. *)

			IF (handler # -1) & (ebp # 0) THEN  (* If Objects.Terminate has a FINALLY this doesn't work !!! *)
				IF hasFinally THEN
					(* Connect Finally to Finally *)
					SYSTEM.PUT( ebpSave + 4, handler );   (* Adapt the return pc *)
					SYSTEM.PUT( ebpSave, ebp );   (* Adapt the dynamic link *)
					ebpSave := ebp;
				ELSE int.PC := handler;  int.BP := ebp;  ebpSave := ebp;  hasFinally := TRUE;
				END;
				SetTrapVariable( pc, ebp )
			END
		END;

		(* Now ebp =  0, bottom of the stack, so link the last known return PC to the Termination *)
		IF ~hasFinally THEN
			SYSTEM.GET( ebpBottom + 4, pc );   (* PC of the Terminate *)
			int.PC := pc;  int.BP := ebpBottom;
		ELSIF ebpSave # ebpBottom THEN
			SYSTEM.GET( ebpBottom + 4, pc );   (* PC of the Terminate *)
			SYSTEM.PUT( ebpSave + 4, pc );  SetLastExceptionState( int )
		END;

		handled := TRUE;   (* If FALSE the process could be restarted, may be this is the meaning? *)

	END Unbreakable;

	(* General exception handler. *)
	PROCEDURE Exception( VAR int: Kernel32.Context;  VAR exc: Kernel32.ExceptionRecord;  VAR handled: BOOLEAN );
	VAR t: Objects.Process;  user, traceTrap: BOOLEAN;   exchalt: LONGINT;
	BEGIN  (* interrupts off *)
		t := Objects.CurrentProcess();
		check := t;
		(*
		t := Objects.running[Machine.ID()];	(* t is running process *)
		*)
		handled := FALSE;
		(*
		Machine.GetExceptionState(int, exc);
		*)
		user := (int.CS MOD 4 > 0 (* Machine.KernelLevel*) );  SYSTEM.GET( int.SP, exchalt );

		(*
		traceTrap := (exc.locks = {}) & (exc.halt >= MAX(INTEGER)) & (exc.halt <= MAX(INTEGER)+1);
		*)
		traceTrap := FALSE;

		Show( t, int, exc,  (* exc.halt # MAX(INTEGER)+1*) TRUE );   (* Always show the trap info!*)

		IF exchalt = haltUnbreakable THEN Unbreakable( t, int, exc, handled )
		ELSIF ~traceTrap THEN HandleException( int, exc, handled )
		END;

		IF ~handled THEN
		(* Taken from Machine to allow the FINALLY in the kernel *)

			(*
		locks := Machine.BreakAll();
		SYSTEM.STI();
		*)
			IF ~traceTrap THEN  (* trap *)
				IF user THEN  (* return to outer level *)
					IF TraceVerbose THEN
						KernelLog.Enter;  KernelLog.String( "Jump" );  KernelLog.Hex( t.restartPC, 9 );
						KernelLog.Hex( t.restartSP, 9 );   (* KernelLog.Hex(t.stack.high, 9);*)
						KernelLog.Exit
					END;
					(*
				INCL(SYSTEM.VAL(SET,int.EFLAGS), Machine.IFBit);	(* enable interrupts *)
				*)
					int.BP := 0;  int.SP := t.restartSP;   (* reset stack *)
					int.PC := t.restartPC;   (* restart object body or terminate *)
				ELSE  (* trap was in kernel (interrupt handler) *)  (* fixme: recover from trap in stack traceback *)
					KernelLog.Enter;  KernelLog.String( "Kernel halt" );  KernelLog.Exit;  Machine.Shutdown( FALSE )
				END
			END
		END;

		IF Objects.PleaseHalt IN t.flags THEN
			EXCL( t.flags, Objects.PleaseHalt );
			IF Objects.Unbreakable IN t.flags THEN EXCL( t.flags, Objects.Unbreakable ) END;
			IF Objects.SelfTermination IN t.flags THEN EXCL( t.flags, Objects.SelfTermination ) END
		END;
		check := NIL;
	FINALLY
		(* if trap occurs in this procedure, then go on working right here *)
	END Exception;

	PROCEDURE Init;
	VAR
		s: ARRAY 8 OF CHAR;
	BEGIN
		IF TestTrap THEN
			Machine.GetConfig( "TestTrap", s );
			IF s[0] = "1" THEN HALT( 98 ) END
		END;

		IF TestTrap & (s[0] = "2") THEN HALT( 99 ) END;
		Objects.InstallExceptionHandler( Exception );  KernelLog.String( "Traps: TrapHandler installed" );  KernelLog.Ln;
	END Init;

	PROCEDURE Install*; (* for loading this module *)
	BEGIN
		TrapWriters.InstallTraceWriter
	END Install;

BEGIN
	modes := " rdy run awl awc awe rip";   (* 4 characters per mode from Objects.Ready to Objects.Terminated *)
	flags := "c!p!a!zstido";   (* bottom flags, !=reserved *)
	Init
END Traps.

SystemTools.FreeDownTo Traps ~

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
