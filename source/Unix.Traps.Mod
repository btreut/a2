(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Traps;  (** AUTHOR "G.F."; PURPOSE "Exception Trap and symbolic debugging"; *)

(* 2000.02.06	g.f.	UnixOberon release 2.3.6d	*)
(* 2006.07.09	g.f.	UnixAos version	*)

IMPORT S := SYSTEM, Trace, Glue, Unix, Objects, Machine, Heaps, Streams, Modules, Reflection, 
		TrapWriters, Commands, StdIO;  

CONST
	AddrSize = SIZEOF( ADDRESS );
	
TYPE 		
	SigHandler = PROCEDURE ( sig: LONGINT; scp, ucp, dum: ADDRESS );  
	
	ExceptionHandler = RECORD  pc, fp, sp: ADDRESS  END;
	
VAR 
	InstallSignalHandler: PROCEDURE{C} ( h: SigHandler );  
	
	TrapHandlingLevel: INTEGER;  
	
	trace: BOOLEAN;  
	
	unix: Commands.Context;
		
	
	PROCEDURE Append( VAR ar: ARRAY OF CHAR;  CONST this: ARRAY OF CHAR );
	VAR i, j: LONGINT;
	BEGIN
		i := 0;  j := 0;
		WHILE ar[i] # 0X DO  INC( i )  END;
		WHILE (i < LEN( ar ) - 1) & (this[j] # 0X) DO  ar[i] := this[j];  INC( i );  INC( j )  END;
		ar[i] := 0X
	END Append;
	
	
	PROCEDURE TimeTag( w: Streams.Writer );
	VAR 
		tv: Unix.Timeval;  tz: Unix.Timezone;  t: Unix.TmPtr;  ret: LONGINT;
			
		PROCEDURE Int( i: LONGINT );
		BEGIN
			IF i < 10 THEN  w.Char( '0' )  END;
			w.Int( i, 0 )
		END Int;
			
	BEGIN
		ret := Unix.gettimeofday( tv, tz );
		t := Unix.localtime( tv );
		w.Int( 1900 + t.year, 4 );  w.Char( '/' );  Int( t.mon + 1 );  w.Char( '/' );  Int( t.mday );  
		w.String( "  " );  Int( t.hour );  w.Char( ':' );  Int( t.min );  w.Ln;
	END TimeTag;
	
	
		
	PROCEDURE FinishTrap( w: Streams.Writer;  p: Objects.Process );
	VAR tag: ADDRESS;  td: Modules.TypeDesc;  name: ARRAY 72 OF CHAR;
	BEGIN
		w.Char( 2X );   (* end of trap text *) 
		w.Update;
		TrapWriters.Trapped;
			
		S.GET( S.VAL( ADDRESS, p.obj ) - AddrSize, tag );
		S.GET( tag - AddrSize, td );  
		IF td.mod # NIL THEN  
			COPY( td.mod.name, name );  Append( name,  "." );  Append( name, td.name );
			IF name = "Oberon.System.OberonRunner" THEN  UnlockOberon  END
		END;
		TrapHandlingLevel := 0;
		Machine.Release( Machine.Trap )
	END FinishTrap;
	
	

	PROCEDURE Trap( sig: LONGINT;  ucp: Unix.Ucontext;  fatalerror: BOOLEAN );  
	VAR 
		pc, sp, bp: ADDRESS;  
		trapno: LONGINT;  
		process: Objects.Process;  
		handler: ExceptionHandler;  
		w: Streams.Writer;
	BEGIN 
		INC( TrapHandlingLevel ); 
		IF trace THEN  
			Trace.String( "Aos Trap:  signal = " );  Trace.Int( sig, 0 );  
			Trace.String( ",  ucp = " );  Trace.Hex( S.VAL( ADDRESS, ucp ), -8 );  
			Trace.String( ", traphandling  level = " ); Trace.Int( TrapHandlingLevel, 1 );  
			Trace.Ln;  
		END;  
				
		IF fatalerror THEN  
			w := unix.error  
		ELSE  
			w := TrapWriters.GetWriter();
			w.Char( 1X );   (* begin of trap text *) 
		END;
		w.Ln;  
		w.String( Machine.version ); w.String( "   " );  TimeTag( w );  w.Ln;
		IF TrapHandlingLevel = 1 THEN  
			IF ~fatalerror THEN  Machine.Acquire( Machine.Trap )  END;
			w.String( "Trap " ) 
		ELSE  
			w.String( "==== recursive Trap" )  
		END;  
		CASE sig OF 
		| 1:		w.String( "1 (Hangup signal)" );   
		| 2:  	w.String( "2 (User interrupt)" );   
		| 3:		w.String( "3 (Quit signal)" );   
		| 4:  	w.String( "4 (Illegal instruction)" );   
		| 5:   	w.String( "5." );  
				sp := ucp.mc.r_sp;
				S.GET( sp, trapno );  w.Int( trapno, 0 );  
				CASE trapno OF 
				| 1:       w.String( "  (WITH guard failed)" ) 
				| 2:       w.String( "  (CASE invalid)" ) 
				| 3:       w.String( "  (RETURN missing)" ) 
				| 5:       w.String( "  (Implicit type guard failed)" ) 
				| 6:       w.String( "  (Type guard failed)" ) 
				| 7:       w.String( "  (Index out of range)" ) 
				| 8:       w.String( "  (ASSERT failed)" ) 
				| 9:       w.String( "  (Array dimension error)" ) 
				ELSE 
					IF trapno >= 30 THEN  w.String( "  (programmed HALT)" )  
					ELSE  w.String( "  (unknown exception, division error?)" )   
					END  
				END;   
		|  8:	w.String( "8 (Arithmetic exception)" );   
		|10: 	w.String( "10 (Bus Error)" ) 
		|11:	w.String( "11 (Segmentation violation)" ) 
		|13:	w.String( "13 (Broken pipe)" ) 
		|14:	w.String( "14 (Alarm signal)" ) 
		ELSE 
			w.String( "(Signal " );  w.Int( sig, 0 );  w.Char( ')' );  
		END;  
		w.Ln;
		IF TrapHandlingLevel = 1 THEN
			process := Objects.CurrentProcess( ); 
			pc := ucp.mc.r_pc;  bp := ucp.mc.r_bp;
			IF pc = 0 THEN  
				(* assume call of procedure variable with value NIL *)
				S.GET( sp, pc );   (* get return address on top of stack *)
			END;  	
			w.Ln;
			w.String( "    sp = " );  w.Address( sp );  w.String( ", fp = " );  w.Address( bp ); 
			w.String( ", pc = " );  w.Address( pc );  w.Ln;  
			w.Ln;  
			Reflection.StackTraceBack( w, pc, bp, Objects.GetStackBottom( process ), TRUE, FALSE );
			SearchExceptionHandler( process, ucp, handler ); 
		END;
		w.Ln; w.Ln; 
		w.String("----------------------------------------------------"); w.Ln; 
		
		IF fatalerror OR (TrapHandlingLevel > 2) THEN  Machine.Shutdown( FALSE )  END;
		
		FinishTrap( w, process );
		
		IF handler.pc # 0 THEN  
			IF Unix.Version # "Darwin" THEN
				(* in the Darwin port Unix.ModifyContext fails with bus error. Stack alignment problem? *)
				w.Ln;  
				w.String( "### program continues with exception handler ###" );   w.Ln;
				
				Unix.ModifyContext( ucp, handler.pc, handler.fp, handler.sp );
				RETURN  (*! to exception handler !! *)  
			END
		END;
			
		IF Machine.standaloneAppl THEN	
			unix.error.Ln;  unix.error.Ln;
			unix.error.String( "### Program aborted. Stack traceback in logfile" );  unix.error.Ln;
			unix.error.Update;
			Machine.Shutdown( FALSE )
		ELSIF TrapHandlingLevel > 1 THEN 
			Objects.Terminate
		ELSE
			Objects.ExitTrap() 
		END
	END Trap;  
	
	
	PROCEDURE UnlockOberon;
	CONST OberonKernel = "Oberon.Kernel";
	VAR c: PROCEDURE;
	BEGIN
		IF Modules.ModuleByName( OberonKernel ) # NIL THEN
			GETPROCEDURE( OberonKernel, "UnlockOberon", c );
			IF c # NIL THEN  c  END
		END;
	END UnlockOberon;
	

	PROCEDURE SearchExceptionHandler( process: Objects.Process;  cont: Unix.Ucontext;  VAR handler: ExceptionHandler );  
	VAR entry, fp, sp, pc: ADDRESS;
	BEGIN 
		handler.pc := 0;  (* no handler *)
		pc := cont.mc.r_pc;  fp := cont.mc.r_bp;  sp := cont.mc.r_sp;
		IF pc = 0 THEN  
			(* assume call of procedure variable with value NIL *)
			S.GET( sp, pc );   (* get return address on top of stack *)
		END;  
		entry := Modules.GetExceptionHandler( pc );   
		WHILE (entry = -1) & (fp <= process.stackBottom) DO  
			S.GET( fp + AddrSize, pc );  
			pc := pc - 1;   (*  CALL instruction, machine dependent!!! *)
			entry := Modules.GetExceptionHandler( pc );  
			sp := fp;   (* Save the old framepointer into the stack pointer *)
			S.GET( fp, fp ) (* Unwind PAF *)
		END;  
		IF entry # -1 THEN 
			handler.pc := entry;  handler.fp := fp;  handler.sp := sp
		END  
	END SearchExceptionHandler;  
	
	
	PROCEDURE SignalHandler( signal: LONGINT;  scp, ucp, dummy: ADDRESS );   
		(* 'dummy' for 16 byte stack alignment, MacOS! *)
	BEGIN 
		IF ~(signal IN  {1, 2, 14, 15}) (* SIGHUP, SIGINT, SIGALRM, SIGTERM *) THEN  
			IF trace THEN  
				Trace.String( "Traps.SignalHander: received signal " );  
				Trace.Int( signal, 1 );  Trace.Ln  
			END;
			IF Heaps.collecting THEN  
				Trace.Ln;  Trace.String( "PANIC: Trap " );  Trace.Int( signal, 0 );  
				Trace.String( " in garbage collector" );  Trace.Ln;  Trace.Ln;
				Machine.Release( Machine.Heaps );
				Trap( signal, S.VAL( Unix.Ucontext, ucp ), TRUE )  
			ELSE  
				Trap( signal, S.VAL( Unix.Ucontext, ucp ), FALSE )  
			END  
		END
	END SignalHandler;  
	


BEGIN 
	trace := 3 IN Glue.debug; 
	Unix.Dlsym( 0, "InstallTrap", ADDRESSOF( InstallSignalHandler ) );
	InstallSignalHandler( SignalHandler );
	unix := StdIO.env
END Traps.
