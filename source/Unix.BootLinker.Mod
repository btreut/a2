(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE BootLinker;   (** AUTHOR "G.F." ; PURPOSE "UnixAos bootlinker"; *)

(* based on Oberon for Windows bootlinker (MH) and  MIPS bootlinker (RC) *)


IMPORT S := SYSTEM, Heaps := BootLinkerHeaps,  Modules := BootLinkerModules, Loader := BootLinkerLoader, 
		Commands, Streams, Files, Strings;

VAR
	out: Streams.Writer;
	error: Streams.Writer;


	

	PROCEDURE OutBootfile( CONST fileName: ARRAY OF CHAR );
	CONST	
		AddrSize = SIZEOF( ADDRESS );
	VAR 
		f: Files.File;  w: Files.Writer;  startOffset, i: LONGINT;  top, adr: ADDRESS;
	BEGIN
		startOffset := Heaps.BlockSize - AddrSize;
		top := Heaps.beginFree;

		f := Files.New( fileName );  Files.OpenWriter( w, f, 0 );
		
		(* output heap *)
		w.RawLInt( LONGINT(AddrSize*8) );
		w.RawHInt( HUGEINT(Heaps.heapAdr) );
		w.RawLInt( LONGINT( Heaps.BootHeapSize) );
		adr := Heaps.heapAdr + startOffset;
		w.RawLInt( LONGINT(startOffset) );  
		w.RawLInt( LONGINT(top - adr) );
		WHILE adr < top DO  S.GET( adr, i );  w.RawLInt( i );  INC( adr, 4 )  END;
		
		
		w.RawLInt( LONGINT(Loader.entrypoint - Heaps.heapAdr) );  
		w.RawLInt( LONGINT(Loader.dlsymAdr - Heaps.heapAdr) );  
		

		(* output relocate information *)
		w.RawNum( Heaps.numRelocations );  i := 0;
		WHILE i < Heaps.numRelocations DO  
			w.RawNum( LONGINT( Heaps.relocAddr[i] - Heaps.heapAdr ) );  INC( i )  
		END;
		
		w.Update;  Files.Register( f );

		out.String( "heap size (used heap space): " );  
		out.Int( LONGINT(Heaps.BootHeapSize DIV 1024), 0 ); out.String( " KB (" );
		out.Int( LONGINT((Heaps.beginFree - Heaps.heapAdr) DIV 1024), 0 );
		out.String( " KB), relocations: " );  out.Int( Heaps.numRelocations, 0 );
		out.Ln
	END OutBootfile;


	PROCEDURE Link*( context: Commands.Context );
	CONST
		Ok = 0;
	VAR 
		fileName, moduleName, fullPath: Modules.Name;
		token: ARRAY 8 OF CHAR;
		m: Modules.Module;
		res: LONGINT;  msg: ARRAY 128 OF CHAR;
	BEGIN
		out := context.out;  error := context.error;
		
		IF	~context.arg.GetString( fileName ) OR 
			~context.arg.GetString( token ) OR (token # ":=") THEN
				error.String( "wrong parameter(s), terminating" ); error.Ln;  error.Update;  
				RETURN
		END;
		
		fullPath := Loader.BuildDirectory; Strings.Append( fullPath, "/" ); Strings.Append( fullPath, fileName );
		out.String( "UnixAos BootLinker creating " );  out.String( fullPath );  out.Ln;
		
		Heaps.Initialize( context.error );
		Modules.Initialize( context.error );;
		Loader.Initialize( context.error );
						
		res := Ok;
		IF context.arg.GetString( moduleName ) THEN
			REPEAT
				out.String( "    " );  out.String( moduleName );  out.Ln;
				m := Loader.Load( moduleName, res, msg );
				IF m = NIL THEN  
					error.String( "loading module failed: " );  error.String( msg );  error.Ln
				 END;
			UNTIL ~context.arg.GetString( moduleName ) OR (m = NIL);
			
			IF res = Ok THEN  
				Modules.AssignAddress( "Modules", "root", S.VAL( ADDRESS, Modules.root ) );
	
				Modules.RelocateProcOffsets;
				Modules.AssignAddress( "Modules", "procOffsets", S.VAL( ADDRESS, Modules.procOffsets ) );
				Modules.AssignValue( "Modules", "numProcs", Modules.numProcs );
				
				Modules.RelocatePtrOffsets;
				Modules.AssignAddress( "Modules", "ptrOffsets", S.VAL( ADDRESS, Modules.ptrOffsets ) );
				Modules.AssignValue( "Modules", "numPtrs", Modules.numPtrs );

				OutBootfile( fullPath )  
			END;
			out.Ln
		ELSE  
			error.String( "parameter error, module names missing, terminating" ); error.Ln
		END;
		out.Update; error.Update
	END Link;



END BootLinker.


Compiler.Compile
	Unix.BootLinkerHeaps.Mod  Unix.BootLinkerModules.Mod  Unix.BootLinkerLoader.Mod  Unix.BootLinker.Mod ~

SystemTools.Free  BootLinker BootLinkerLoader  BootLinkerModules  BootLinkerHeaps ~




BootLinker.Link  bootFileName := modName0 modName1 ... ~

	All module names must be listed and topologically sorted.

Boot File Format:


	architecture		(* LONGINT,  32 or 64 *)
	heapAddr		(* HUGEINT *)
	heapSize		(* LONGINT *)
	startOffset		(* LONGINT *)
	usedHeap		(* LONGINT *)
	{heapValue}		(* usedHeap DIV 4 times LONGINT *)
	entryOffset		(* LONGINT, Aos entry point *) 
	dlsymOffset		(* LONGINT, location which receives the address of (Unix)'dlsym' *)
	nofPtr 			(* NUMBER *)
	{offset}			(* nofPtr times relocation offset (NUMBER) *)

	All numbers in the relocate information part are in compact format and relative to
	heapAdr.
