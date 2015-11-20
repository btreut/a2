(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Glue;   (** AUTHOR "G.F."; PURPOSE "Interface to the dynamic linker of Unix" *)


IMPORT S := SYSTEM, Trace;

TYPE	
	PtrElemDesc* = RECORD  a: ANY  END;	(* used by BootLinker only *)
		(* has same type descriptor as element of ARRAY OF POINTER TO ... *)

CONST
	AddrSize = SIZEOF( ADDRESS );


VAR
	(* the first variable ("AA...") gets initialized by the bootfile loader *)
	AAgetadr	: ADDRESS;	(* address of procedure dlsym *)

	dlsym-	: PROCEDURE {C} ( handle: ADDRESS;  name: ADDRESS; adr: ADDRESS );
	dlopen-	: PROCEDURE {C} ( pathname: ADDRESS;  mode: LONGINT ): ADDRESS;
	dlclose-	: PROCEDURE {C} ( handle: ADDRESS );
	cout		: PROCEDURE {C} ( c: CHAR );	(* output to Unix stdout *)

	debug-		: SET;	(* value of environment variable  AOSDEBUG  *)


	stackBottom-	: ADDRESS;	(* of main thread *)


	PROCEDURE Char ( c: CHAR );
	BEGIN
		cout( c )
	END Char;



	PROCEDURE Init;
	VAR i: LONGINT;
	BEGIN
		S.MOVE( ADDRESSOF( AAgetadr ), ADDRESSOF( dlsym ), AddrSize );
		
		dlsym( 0, ADDRESSOF( "dlopen" ), ADDRESSOF( dlopen ) );
		dlsym( 0, ADDRESSOF( "dlclose" ), ADDRESSOF( dlclose ) );
		
		dlsym( 0, ADDRESSOF( "debug" ), ADDRESSOF( debug ) );
		dlsym( 0, ADDRESSOF( "cout" ), ADDRESSOF( cout ) );
		
		stackBottom := ADDRESSOF( i ) + 2*AddrSize;
		
		Trace.Char := Char;
	END Init;

BEGIN
	Init;
END Glue.
