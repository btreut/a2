(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMExceptions;

IMPORT
		AosHeap,
		PCDebug, JC := JVMConsole, JT := JVMTypes,
		SYSTEM, AosActive, AosModules, AosInterrupts, AosOut, 
		Refs := JVMRefs, JS := JVMSystem;
	
CONST
	EnableExceptions* = TRUE;
	Trace =  TRUE;
	TraceExceptions = FALSE;
	TraceMiss = FALSE;	(* dump global exception table when no match *)
	
VAR
	infoInfo: JC.LoggingInfo;
	
TYPE
	ExceptionClass* = PTR;

	EvaluateProc* =  PROCEDURE(e: ExceptionClass; adr: LONGINT): BOOLEAN;
	
	Catch* = RECORD
		start*, end*, handler* : LONGINT;
		ex* : PTR; (* class of exception, that will be handled by this handler*)
		handlesIt* : EvaluateProc
	END;
		
	CatchTable* = POINTER TO ARRAY OF Catch;
								
	ExceptionHandler* = POINTER TO ExceptionHandlerDesc;
	ExceptionHandlerDesc* = RECORD
		left, right : ExceptionHandler;
		balance : SHORTINT; (* balance< 0 => left subtree is higher; 
											   balance= 0 => both subtrees equal; 
											   balance> 0 right subtree is higher*)
		start, end : LONGINT;
		catch : CatchTable;
		inner : BOOLEAN;
		module : AosModules.Module
	END;
	
	Exception *= POINTER TO RECORD nr :LONGINT END;
	
VAR
	handlers : ExceptionHandler;
	HandleInner : LONGINT;
		
	(** upcall to translate trap numbers into Exception Objects *)														
	TranslateTrap* : PROCEDURE( error : LONGINT; VAR mapped : BOOLEAN ): LONGINT;

	(** upcall to allow saving of the current stack state, bevor the Program continues and
	      overwrites the stack *)
	SaveStack*: PROCEDURE( adr, orig, size, pc : LONGINT );


	PROCEDURE DumpException(obj: LONGINT);
		VAR tag: LONGINT; desc: AosModules.TypeDesc;
	BEGIN
(*
		SYSTEM.GET(obj-4, tag);
		SYSTEM.GET(tag-4, desc);
*)
		JC.String(infoInfo, "Exception ");
(*
		JC.String(desc.name);
*)
		JC.Ln(infoInfo)
	END DumpException;

	PROCEDURE TraceException(VAR int: AosInterrupts.Stateme: ARRAY OF CHAR; val: LONGINT);
		BEGIN JC.String(infoInfo, "  "); JC.String(infoInfo, name); JC.String(infoInfo, " = "); JC.Hex(infoInfo, val, 0)
		END Reg;
		
	BEGIN
		JC.String(infoInfo, "TRAP "); JC.Int(infoInfo, exc.halt, 0); Reg("EIP", int.EIP);
(*
		IF (exc.halt = 7) OR (exc.halt = -14) THEN
			PCDebug.GetProcedure(int.EIP, name);
			JC.String(name);
		END;
*)
		JC.Ln(infoInfo);
(*
		AosHeap.GetHeapInfo(total, free, largest);
		JC.Int(total, 0); JC.String("  "); JC.Int(free, 0); JC.String("  "); JC.Int(largest, 0); JC.Ln;
*)

(*
		SYSTEM.GET(exc.ESP, sp);
		Reg("[ESP]", sp);
		JC.Ln;
		m := AosModules.ThisModuleByAdr(int.EIP);
		IF m # NIL THEN
			JC.String(m.name); JC.Ln
		END;
		FOR i := 1 TO 13 DO
			SYSTEM.GET(exc.ESP+4*i, sp);
			JC.Int(4*i, 0); JC.String("  "); JC.Hex(sp, 0); JC.Ln
		END;
*)
(*
		SYSTEM.GET(exc.ESP+4, sp);
		Reg("[ESP+4]", sp);
		PCDebug.GetTypeName(SYSTEM.VAL(PTR, sp), name);
		JC.String(m.name); JC.Ln
*)
(*
		PCDebug.GetTypeName(SYSTEM.VAL(PTR, int.EAX), name);
		JC.String(name); JC.Ln;
		SYSTEM.GET(exc.ESP, sp);
		PCDebug.GetProcedure(sp, name);
		JC.String(name); JC.Ln;
*)
(*
		IF (no = -6) THEN
			SYSTEM.GET(esp, pc);
			PCDebug.GetProcedure(pc, name);
			JC.String("   "); JC.String(name); Reg("EBP", ebp); JC.Ln;
		ELSIF (no # -14) OR (pf # -4) THEN
			PCDebug.GetProcedure(pc, name);
			JC.String("   "); JC.String(name); Reg("EBP", ebp); JC.Ln;
			name[3] := 0X;
			IF name = "NIL" THEN
				SYSTEM.GET(esp, pc);
				PCDebug.GetProcedure(pc, name); JC.String("   "); JC.String(name); Reg("EBP", ebp); JC.Ln;
			END;
			c := 0; ebp0 := MIN(LONGINT);
			WHILE (c < 0) & (ebp > ebp0) & (ebp < 0) DO
				ebp0 := ebp;
				SYSTEM.GET(ebp+4, pc);
				SYSTEM.GET(ebp, ebp);
				PCDebug.GetProcedure(pc, name);
				JC.String("   "); JC.String(name); Reg("EBP", ebp); JC.Ln;
				INC(c);
			END
		END
*)
	END TraceException;


	(** creation of a registry entry for a exception handler *)								
	PROCEDURE CreateHandler*( VAR handler :ExceptionHandler; start, end : LONGINT; 
							catchTable : CatchTable; mod : AosModules.Module );
	BEGIN
		ASSERT(start < end, 500);
		NEW( handler ); handler.start := start; handler.end := end; handler.catch := catchTable; 
		handler.module := mod;  handler.balance := 0
	END CreateHandler;
	
	(** frees all entries of the handler registry *)
	PROCEDURE FreeAll*;
	BEGIN{EXCLUSIVE}
		handlers := NIL
	END FreeAll;
	
	(** frees all entries of the specified module *)
	PROCEDURE UnregisterModule*( mod : AosModules.Module );
	VAR ref : Refs.Ref;
		base, adr : LONGINT;
		height : BOOLEAN;
	BEGIN{EXCLUSIVE}
		base := JS.GetCodeBase( mod );
		ref := Refs.NextRef( mod, NIL );
		WHILE ref#NIL DO
			adr := ref.offset+base; 
			UnregisterHandler( adr , handlers, height );
			ref := Refs.NextRef( mod, ref )			
		END		
	END UnregisterModule;
	
	(** Insert a HandlerEntry into the HandlerRegistry *)
	PROCEDURE RegisterHandler*( h : ExceptionHandler );
	VAR height : SHORTINT;
	BEGIN{EXCLUSIVE}
		RegisterExHandler( handlers, h, height )
	END RegisterHandler;
	
	PROCEDURE RegisterExHandler( VAR root : ExceptionHandler; handler: ExceptionHandler; VAR height : SHORTINT );
	VAR p, q : ExceptionHandler;	
	BEGIN		
		IF root = NIL THEN root := handler; height := 1; RETURN END;
		IF root.start > handler.end THEN RegisterExHandler( root.left, handler, height );						
			DEC( root.balance, height );
			IF root.balance = 0 THEN height := 0
			ELSIF root.balance = -2 THEN height := 0;
				p := root.left;
				IF p.balance =  1 THEN 		(* double rotation *)
					q := p.right; 
					IF q.balance = 1 THEN root.balance := 0; p.balance := -1
					ELSE root.balance := 1; p.balance := 0 END;
					p.right := q.left; q.left := p; root.left := q.right; q.right := root; root := q			
				ELSIF p.balance = -1 THEN  (* single rotation *)					
					root.balance := 0; p.balance := 0;
					root.left := p.right; p.right := root; root := p; 
				END
			END
		ELSIF root.end < handler.start THEN RegisterExHandler( root.right, handler, height );
			INC( root.balance, height );
			IF root.balance = 0 THEN height := 0
			ELSIF root.balance = 2 THEN height := 0;
				p := root.right;
				IF p.balance = -1 THEN (* double rotation *)
					q := p.left;
					IF q.balance = 1 THEN root.balance := -1; p.balance := 0
					ELSE root.balance := 0; p.balance := 1 END;
					p.left := q.right; q.right := p; root.right := q.left; q.left := root; root := q
				ELSIF p.balance = 1 THEN (*single rotation *)
					root.balance := 0; p.balance := 0;
					root.right := p.left; p.left := root; root := p
				END
			END				
		ELSE
			AosOut.String( "Handler for pc in { "); 
			AosOut.Int(  handler.start, 5 ); AosOut.String("..");AosOut.Int(  handler.end, 5 );
			AosOut.String( "} already installed!" ); AosOut.Ln
		END;						
	END RegisterExHandler;
	
	
	PROCEDURE UnregisterHandler( start :LONGINT;  VAR h : ExceptionHandler; VAR height : BOOLEAN );	
	VAR q : ExceptionHandler;
	
	(* left subtree decreased in height *)
	PROCEDURE BalanceLeft( VAR p : ExceptionHandler; VAR height : BOOLEAN );
	VAR q, r : ExceptionHandler; bal : SHORTINT;
	BEGIN
		CASE p.balance OF
		-1: p.balance := 0
		|0: p.balance := 1; height := FALSE
		|1: q := p.right; bal := q.balance;
			  IF bal >= 0 THEN (* single rotation *)
			  	p.right := q.left; q.left := p; 
			  	IF bal = 0 THEN p.balance := 1; q.balance := -1; height := FALSE
			  	ELSE p.balance :=  0; q.balance := 0 END;
			  	p := q
			  ELSE (* double rotation *)
			  	r := q.left; bal := r.balance;
			  	q.left := r.right; r.left := q;
			  	p.right := r.left; r.left := p;
			  	IF bal = 1 THEN p.balance := -1 ELSE p.balance := 0 END;
			  	IF bal = -1 THEN q.balance := 1 ELSE q.balance := 0 END;
			  	p := r; p.balance := 0
			  END
		END
	END BalanceLeft;
	
	(* right subtree decreased in height *)
	PROCEDURE BalanceRight( VAR p : ExceptionHandler; VAR height : BOOLEAN );
	VAR q, r : ExceptionHandler; bal : SHORTINT;
	BEGIN
		CASE p.balance OF
		1 : p.balance := 0
		|0 : p.balance := -1; height := FALSE;
		|-1: q:= p.left; bal := q.balance;
			  IF bal <= 0 THEN
			  	p.left := q.right; q.right := p;
			  	IF bal = 0 THEN p.balance := -1; q.balance := 1; height := FALSE
			  	ELSE p.balance := 0; q.balance := 0 END;
			  	p := q
			  ELSE
			  	r := q.right; bal := r.balance;
			  	q.right := r.left; r.left := q;
			  	p.left := r.right; r.right := p;
			  	IF bal = -1 THEN p.balance := 1 ELSE p.balance := 0 END;
			  	IF bal = 1 THEN q.balance := -1  ELSE q.balance := 0 END;
			  	p := r; p.balance := 0
			  END
		END
	END BalanceRight;
	
	PROCEDURE Del( VAR p : ExceptionHandler; VAR height : BOOLEAN );
	BEGIN
		IF p.right # NIL THEN Del( p.right, height );
			IF height THEN BalanceRight( p, height ) END
		ELSE
			q.start := p.start; q.end:= p.end; q.module := p.module;
			q.catch := p.catch; q.inner := p.inner; height := TRUE;
			p := p.left
		END			
	END Del;
	
	BEGIN
		IF h = NIL THEN  RETURN
		ELSIF h.start > start THEN  UnregisterHandler( start, h.left, height ); 
			IF height THEN BalanceLeft( h, height ) END
		ELSIF h.start < start THEN  UnregisterHandler( start, h.right, height );
			IF height THEN BalanceRight( h, height ) END
		ELSE
			q := h;
			IF q.right = NIL THEN h := q.left; height := TRUE
			ELSIF q.left = NIL THEN h := q.right; height := TRUE
			ELSE Del( q.left, height );
				IF height THEN BalanceLeft( h, height ) END
			END
		END;
	END UnregisterHandler;

	PROCEDURE FindExHandler( root : ExceptionHandler; pc : LONGINT ):ExceptionHandler;
	BEGIN
		IF root = NIL THEN RETURN NIL END;
		IF pc < root.start THEN RETURN FindExHandler( root.left, pc )
		ELSIF pc > root.end THEN RETURN FindExHandler( root.right, pc )
		ELSE RETURN root
		END
	END FindExHandler;

	PROCEDURE ListHandlers( root: ExceptionHandler );
	VAR i, base: LONGINT; m: AosModules.Module;
	
		PROCEDURE Range(a, b: LONGINT);
		BEGIN AosOut.Int(a, 6); AosOut.String(" - "); AosOut.Int(b, 6)
		END Range;
		
	BEGIN
		IF root = NIL THEN RETURN END;
		ListHandlers( root.left );
		(* this must be written in the kernel log *)
		m := AosModules.ThisModuleByAdr(root.start);
		IF m # NIL THEN
			base := SYSTEM.ADR(m.code[0]);
			AosOut.String(m.name);
		ELSE
			base := 0;
			AosOut.String( "Handler for pc ");
		END;
		Range(root.start-base, root.end-base); AosOut.Ln;
		FOR i := 0 TO LEN( root.catch^)-1 DO
			Range(root.catch[i].start-base, root.catch[i].end-base);
			AosOut.String(" --> ");
			AosOut.Int( root.catch[i].handler-base, 0 ); AosOut.Ln
		END;
		ListHandlers( root.right );
	END ListHandlers;

	PROCEDURE Translate( err: LONGINT; VAR mapped : BOOLEAN ): LONGINT;
	BEGIN
		mapped := FALSE;
		RETURN err
	END Translate;
		
	PROCEDURE ThrowException*( exception : PTR );
	BEGIN
		HALT( 0CAFEH );	(* just make a software trap *)
	END ThrowException;
	
	
	PROCEDURE InvokeInnerHandler( handler : ExceptionHandler; topofstack, fp, i : LONGINT );
	VAR adr, parsize, sp, eax, edx : LONGINT;
			ref : Refs.Ref;
			huge : HUGEINT;			
	BEGIN
		AosOut.String( "InvokeInnerHandler()"); AosOut.Ln;		
		adr := handler.catch[i].handler;
		ref := Refs.FindRefForAdr( handler.module, adr );
		AosOut.String( ref.name ); AosOut.Ln;
		parsize := Refs.GetParamSize( ref );
		IF parsize = 4 THEN huge := InvokeInner4( handler.catch[i].handler, topofstack, fp )
		ELSIF parsize = 8 THEN huge := InvokeInner8( handler.catch[i].handler, topofstack, fp );
		ELSE HALT( 99 ) 
		END;	
		JS.GetLowHigh( huge, eax, edx );
		(* what the size of parameters to remove from the stack *)									
		ref := Refs.FindRefForAdr( handler.module, handler.start );
		AosOut.String( ref.name ); AosOut.Ln;
		parsize := Refs.GetParamSize( ref );		
		adr := JS.GetRetPC( fp); 
		AosOut.Hex( adr - JS.GetCodeBase( handler.module ),  12 ); AosOut.Ln;
		sp := fp+parsize+8; 
		fp := JS.PreviousFP( fp );		
		JS.Resume( sp, fp, adr, edx, eax )
	END InvokeInnerHandler;
	
	PROCEDURE InvokeInner4( adr, val, fp : LONGINT ):HUGEINT;
	CODE{SYSTEM.i386}
		MOV EAX, adr[EBP]		(* adress of the method to invoke *)
		PUSH EBP						(* the FramePointer has to be saved *)
		PUSH val[EBP]				(* this is a parameter of the exception handler *)
		MOV EBP, fp[EBP]		   (* set the FramePointer of the Outer Method *)
		CALL EAX						(* invoke the inner mehtod *)
		POP EBP						 (* restore the FramePointer *)
	END InvokeInner4;
	
	PROCEDURE InvokeInner8(  adr, val, fp : LONGINT ):HUGEINT;
	CODE{SYSTEM.i386}
		MOV EAX, adr[EBP]		(* adress of the method to invoke *)
		PUSH EBP						(* the FramePointer has to be saved *)
		PUSH val[EBP]				(* this is a parameter of the exception handler *)
		MOV EBP, fp[EBP]		   (* set the FramePointer of the Outer Method *)
		PUSH EBP						(* if the handler references a outer variable, the ebp of the outer frame is pushed *)
		CALL EAX						(* invoke the inner mehtod *)
		POP EBP						 (* restore the FramePointer *)
	END InvokeInner8;
	
	
	PROCEDURE TypeName(adr: LONGINT);
		VAR tt: LONGINT; td: AosModules.TypeDesc;
	BEGIN
		SYSTEM.GET(adr-4, tt);
		SYSTEM.GET(tt-4, td);
		AosOut.String("Exception = "); AosOut.String(td.name); AosOut.Ln;
	END TypeName;
	
	(* this handler handles only "synchrounous" Exceptions; it can be used also in Linux Oberon
	*)
	PROCEDURE HandleException*( p: AosActive.Process;  VAR int: AosInterrupts.State; VAR exc: AosInterrupts.ExceptionState;
														 VAR resume: BOOLEAN);
	VAR handler : ExceptionHandler;
			pc, fp, topofstack, i, len, lastfp, size, origpc, origfp, stacksize : LONGINT;
			ref : Refs.Ref;
			dump: ARRAY 32 OF LONGINT; pos: LONGINT; mod: AosModules.Module;
	BEGIN
		IF Trace THEN AosOut.String("HandleException "); AosOut.Int(exc.halt, 0); AosOut.Ln END;
		pc := int.EIP; fp := int.EBP; origpc := pc; origfp := fp;					 (* save original frame pointer *)
		IF exc.halt = 0CAFEH THEN
			SYSTEM.GET( fp+8, topofstack ); 		(* if trap is invoked from a throw *)
			pc := JS.GetRetPC( fp); fp := JS.PreviousFP( fp ); 	 
		ELSE 
			IF TraceExceptions  THEN TraceException(int, exc) END;
			topofstack := TranslateTrap( exc.halt, resume );
			IF ~resume THEN  RETURN END
		END;
		AosOut.String("Seek Exception"); AosOut.Ln;
(*
		DumpException(topofstack);
*)
		REPEAT
			IF pos < 32 THEN dump[pos] := pc; INC(pos) END;
			handler := FindExHandler( handlers, pc );			
			IF (handler # NIL) & (handler.catch # NIL) THEN
				i := 0; len := LEN(handler.catch^);				 
				WHILE (i < len) & 
							~(( handler.catch[i].start < pc) & (handler.catch[i].end >= pc ) &
								handler.catch[i].handlesIt( handler.catch[i].ex, topofstack )) DO INC( i ) 
				END;
				IF i < len THEN 										
					ref := Refs.FindRefForAdr( handler.module, pc );
					IF ref = NIL THEN AosOut.String( "no reference found " ); resume := FALSE; RETURN END;	
					size := Refs.GetLocalSize( ref ); 
					stacksize := fp - origfp + 4;					
					IF stacksize > 0 THEN SaveStack( topofstack, origfp, stacksize, origpc  ) 
					ELSE resume := FALSE; RETURN END;					
					IF handler.inner THEN (* quit the privileged level and invoke handle inner .. *)
					(* push parameters of handler *)						
						int.ESP := fp-size;						
						DEC( int.ESP, 4 ); SYSTEM.PUT( int.ESP, SYSTEM.VAL( LONGINT, handler ) );
						DEC( int.ESP, 4 ); SYSTEM.PUT( int.ESP, topofstack );
						DEC( int.ESP, 4 ); SYSTEM.PUT( int.ESP, fp );
						DEC( int.ESP, 4 ); SYSTEM.PUT( int.ESP, i );
						DEC( int.ESP, 4 ); SYSTEM.PUT( int.ESP, SYSTEM.VAL( LONGINT, 0 ) ); (* here should be the pc of contination*)																		
						int.EIP := HandleInner;						
						int.EBP := int.ESP;
						resume := TRUE;
						RETURN																				
					ELSE																							
						int.ESP := fp-size-4;												
						SYSTEM.PUT( int.ESP, topofstack );					
						int.EIP := handler.catch[i].handler; int.EBP := fp;
						stacksize := fp - origfp + 4;					
						resume := TRUE;
						RETURN					
					END					
				END
			END;									
			lastfp := fp; 						
			pc := JS.GetRetPC( fp ); fp := JS.PreviousFP( fp )
		UNTIL ( fp= 0 );
		IF TraceMiss THEN
			TypeName(topofstack);
			FOR i := 0 TO pos-1 DO
				mod := AosModules.ThisModuleByAdr(dump[i]);
				IF mod = NIL THEN AosOut.String("NIL")
				ELSE
					AosOut.String(mod.name); AosOut.Char(".");
					ref := Refs.FindRefForAdr(mod, dump[i]);
					AosOut.String(ref.name)
				END;
				AosOut.Ln;
			END;
			ListHandlers( handlers )
		END;
		resume := FALSE
	END HandleException;

	PROCEDURE DummySave( adr, orig, size, pc : LONGINT );
	BEGIN END DummySave;
		
	PROCEDURE init;
	VAR handle : PROCEDURE( h : ExceptionHandler; ex, fp, i : LONGINT );
	BEGIN
		handle := InvokeInnerHandler;		
		HandleInner := SYSTEM.VAL( LONGINT, handle );
		SaveStack := DummySave;
		TranslateTrap := Translate		
	END init;
	
	PROCEDURE InstallOberonExHandler*( module, procname, handlername : ARRAY OF CHAR;
																   type : PTR; EvalProc : EvaluateProc );
	VAR ref : Refs.Ref;
			mod : AosModules.Module;	   
			catch : CatchTable;                                                            
			base, res : LONGINT; height : SHORTINT;
			h : ExceptionHandler;
			msg : ARRAY 32 OF CHAR;
	BEGIN
		NEW( catch, 1 );
		mod := AosModules.ThisModule( module, res, msg ); base := JS.GetCodeBase( mod );
		ref :=Refs.FindRefForName( mod, procname ); catch[0].start := ref.offset+ base;
		ref := Refs.NextRef( mod, ref ); catch[0].end := ref.offset+base -1;
		ref := Refs.FindRefForName( mod, handlername );
		catch[0].handler := ref.offset+base;
		catch[0].ex := type; catch[0].handlesIt := EvalProc;
		CreateHandler( h, catch[0].start, catch[0].end, catch, mod );
		h.inner := TRUE;
		RegisterExHandler( handlers, h, height )
	END InstallOberonExHandler;	                                                               
	
	(** prints registered Handlers to AosOut *)
	PROCEDURE ShowHandlers*;
	BEGIN ListHandlers( handlers )
	END ShowHandlers;
	
	(** with save stack, the whole stack down to the stackframe of the handler was
	      saved into an array of LONGINT; this funktion retrieves the information out of this array;	      
	      - stack is the saved stack. (in)
	      - offset is the original adress of the greatest SP value ( in )
	      - topmostfp is the array-index of the topmost stack-frame; starts with 0; (in out)
	      - mod :Module of prozedure that owns the stackframe (out )
	      - ref : Information of the stackframe
	*)
	PROCEDURE NextStackFrameRef*( VAR stack : ARRAY OF CHAR; offset :LONGINT;	
															 VAR topmostfp, pc : LONGINT;
															 VAR mod : AosModules.Module; VAR ref : Refs.Ref );
	VAR size : LONGINT;
			var : Refs.Var;															 
	BEGIN
		mod := NIL; ref := NIL;
		(* AosOut.String("stacksize :"); AosOut.Int( LEN(stack), 12 ); AosOut.Ln;
		*)
		IF (topmostfp >= LEN(stack)-4) THEN RETURN END;		
		SYSTEM.GET( SYSTEM.ADR(stack[topmostfp])+4, pc);
		SYSTEM.GET( SYSTEM.ADR(stack[topmostfp]), topmostfp );
		DEC( topmostfp, offset );
		
		mod := AosModules.ThisModuleByAdr( pc );
		IF mod = NIL THEN RETURN END;		
		ref := Refs.FindRefForAdr( mod, pc );
		IF ref = NIL THEN RETURN END;
		var := ref.var;
		WHILE var #NIL DO 			
			CASE var.type OF
				1X,2X,3X,4X:size := 1;
				|5X: size := 2;
				|6X,7X,13X,14X :size := 4;
				|8X,16X:size := 8
				ELSE size :=0;
			END;
			(*
			IF size # 0 THEN
				SYSTEM.MOVE( SYSTEM.ADR(stack[topmostfp])+var.offset, var.value, size );
			ELSE
				var.value := topmostfp + var.offset
			END;
			*)
			var := var.next
		END								 															 
	END NextStackFrameRef;															
	                                                         
	
BEGIN		
	infoInfo.kind := JC.Info; infoInfo.source := JC.VM;
	init;
END JVMExceptions.

System.Free JVMExceptions~
JVMExceptions.ShowHandlers

(*
	30.07.03	prk	Logging functions, add kind and source; filtering support
	12.02.03	prk	Logging functions, use same interface as AosOut
	19.03.02	prk	trace informations improved
	22.10.01	prk	debug facilities improved
	26.03.01	prk	Adapted for Paco
*)IER\R