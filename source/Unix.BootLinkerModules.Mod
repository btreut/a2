(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE BootLinkerModules;   (** AUTHOR "G.F." ; PURPOSE "UnixAos bootlinker"; *)

(* based on Oberon for Windows bootlinker (MH) and  MIPS bootlinker (RC) *)

(*! BootLinker specific parts are surrounded by: 
	(*! begin =============================*)
	(*! ============================== end *)
*)
	
IMPORT S := SYSTEM, Heaps := BootLinkerHeaps, Streams;


CONST
	AddrSize = SIZEOF( ADDRESS );

	MaxTags* = 16;   (* in type descriptor *)
	
	(** type descriptor field offsets relative to root (middle) *)
	Tag0Ofs* = -8;   (** first tag *)
	Mth0Ofs* = Tag0Ofs - 4*MaxTags;   (** first method *)
	Ptr0Ofs* = 4;   (** first pointer offset *)
	
	InitTableLen = 1024;
	InitPtrTableLen = 2048;

TYPE

	Name* = ARRAY 32 OF CHAR;
	TermHandler* = PROCEDURE;

	Command* = RECORD
				name*		: Name;		(* Name of the command *)
				argTdAdr*	: ADDRESS;	(* address of type descriptor of argument *)
				retTdAdr*	: ADDRESS;	(* address of type descriptor of return type, 0 if no type *)
				entryAdr*	: ADDRESS;	(* entry address of procedure *)
			END;


	ExportDesc* = RECORD
				fp*			: ADDRESS;
				adr*		: ADDRESS;
				exports*	: LONGINT;
				dsc*		: ExportArray
			END;

	ExportPtr* 		= POINTER TO ExportDesc;
	ExportArray*	= POINTER TO ARRAY OF ExportDesc;


	TypeDesc* = POINTER TO TypeDescRec;
	TypeDescRec* = RECORD
				tdSize*		: LONGINT;
				sentinel*	: LONGINT;	(*  = -4 *)
				tag*		: ADDRESS; 	(* pointer to static type descriptor, only used by linker and loader *)
				flags*		: SET;
				mod*		: Module;   	(** hint only, because module may have been freed *)
				name*		: Name;
			END;

	ExceptionTableEntry* = RECORD
				pcFrom*	: ADDRESS;
				pcTo*		: ADDRESS;
				pcHandler*	: ADDRESS;
			END;

	
	
	ExceptionTable* = POINTER TO ARRAY OF ExceptionTableEntry;

	ProcTableEntry* = RECORD
				pcFrom*			: ADDRESS;
				pcLimit*			: ADDRESS;
				pcStatementBegin*	: ADDRESS;
				pcStatementEnd*	: ADDRESS;
				noPtr*				: LONGINT
			END;
	
	ProcOffsetEntry* = RECORD
		data*: ProcTableEntry;	(* code offsets of procedures *)
		startIndex*: LONGINT;	(* index into global ptrOffsets table *)
	END;

	ProcOffsetTable* = POINTER TO ARRAY OF ProcOffsetEntry;
	
	ProcTable* = POINTER TO ARRAY OF ProcTableEntry;
	PtrTable* = POINTER TO ARRAY OF ADDRESS;

	Bytes* = POINTER TO ARRAY OF CHAR;
	

	Module* = OBJECT(Heaps.RootObject)
			VAR
				next*			: Module;
				name*		: Name;
				init*			: BOOLEAN;
				published*	: BOOLEAN;
				refcnt*		: LONGINT;
				sb*	 		: ADDRESS;
			
				entry*			: POINTER TO ARRAY OF ADDRESS;
				command*	: POINTER TO ARRAY OF Command;
				ptrAdr*		: POINTER TO ARRAY OF ADDRESS;
				typeInfo*		: POINTER TO ARRAY OF TypeDesc;
				module*		: POINTER TO ARRAY OF Module;

				procTable*	: ProcTable; (* information inserted by loader, removed after use in Publish *)
				ptrTable*		: PtrTable;  (* information inserted by loader, removed after use in Publish *)

				data*, code*, staticTypeDescs*, refs*: Bytes;

				export*		: ExportDesc;
				term*			: TermHandler;
				exTable*		: ExceptionTable;
				noProcs*		: LONGINT;
				firstProc*		: ADDRESS;   (* procedure with lowest PC in module *)
				maxPtrs*	:	 LONGINT;
				crc*			: LONGINT
			END Module;

	
	
VAR
	root*: Module;
	
	modTag-, expTag-, ptrElemTag*, tdTag-: ADDRESS;
	
	procOffsets-: ProcOffsetTable;	(* global table containing procedure code offsets and pointer offsets, sorted in ascending order of procedure code offsets *)
	numProcs-: LONGINT;			(* number of entries in procOffsets *)
	ptrOffsets-: PtrTable;
	numPtrs-: LONGINT;

	


(*! begin =============================================================*)

VAR
	error: Streams.Writer;
	
	PROCEDURE MakeTD;
		(* create temporary type tags which are needed for loading the  *)
		(* first modules (up to module Modules). When Modules has been  *)
		(* loaded they got replaced by the proper type tags (cf. FixupTypes) *)
	VAR 
		exp: ExportPtr;  mod: Module;
		ptr: POINTER TO RECORD a: ANY  END; 
		td: TypeDesc;  
	BEGIN
		NEW( exp );  S.GET( S.VAL( ADDRESS, exp ) - AddrSize, expTag );		
		NEW( td );  S.GET( S.VAL( ADDRESS, td ) - AddrSize, tdTag );		
		NEW( mod );  S.GET( S.VAL( ADDRESS, mod ) - AddrSize, modTag );	
		NEW( ptr );  S.GET( S.VAL( ADDRESS, ptr ) - AddrSize, ptrElemTag );
	END MakeTD;

	PROCEDURE PatchExport( VAR scope: ExportDesc;  tag: ADDRESS );
	VAR i: LONGINT;  t: ADDRESS;
	BEGIN
		S.GET( S.VAL( ADDRESS, scope.dsc ) - AddrSize, t );
		IF t # tag THEN
			S.PUT( S.VAL( ADDRESS, scope.dsc ) - AddrSize, tag );  i := 0;
			WHILE i < scope.exports DO
				IF scope.dsc[i].exports > 0 THEN  PatchExport( scope.dsc[i], tag )  END;
				INC( i )
			END
		END
	END PatchExport;
		
	PROCEDURE FixTypeDescs( m: Module );
	VAR i: LONGINT; 
	BEGIN
		S.PUT( S.VAL( ADDRESS, m.typeInfo ) - AddrSize, ptrElemTag + 2(*ArrayBit*) );
		FOR i := 0 TO LEN( m.typeInfo ) -1 DO
			S.PUT( S.VAL( ADDRESS, m.typeInfo[i] ) - AddrSize, tdTag );
		END;
		S.PUT( S.VAL( ADDRESS, m.module ) - AddrSize, ptrElemTag + 2(*ArrayBit*) );
		FOR i := 0 TO LEN( m.module ) -1 DO
			S.PUT( S.VAL( ADDRESS, m.module[i] ) - AddrSize, modTag );
		END;
		S.PUT( S.VAL( ADDRESS, m ) - AddrSize,  modTag );
		PatchExport( m.export, expTag + 2(*ArrayBit*) );
	END FixTypeDescs;

	
	PROCEDURE FixupTypes*( mod: Module );
	VAR i, n: LONGINT;  name: Name;  m: Module;
	BEGIN
		ASSERT( mod.name = "Modules" );
		n := 0;
		FOR i := 0 TO LEN( mod.typeInfo ) - 1 DO
			name := mod.typeInfo[i].name;
			IF name = "TypeDesc" THEN  tdTag := mod.typeInfo[i].tag;  INC( n )  END;
			IF name = "Module" THEN  modTag := mod.typeInfo[i].tag;  INC( n )  END;
			IF name = "ExportDesc" THEN  expTag := mod.typeInfo[i].tag;  INC( n )  END;
		END;
		IF n # 3 THEN
			error.Ln;
			error.String( "### not all expected types found in module 'Modules'" );  error.Ln;
		END;
		
		m := root;
		WHILE m # NIL DO  FixTypeDescs( m );  m := m.next  END;
	END FixupTypes;
	
(*! ============================================================= end *)	
	
	

	PROCEDURE RefReadNum( VAR pos: ADDRESS;  VAR i: LONGINT );
	VAR n: LONGINT;  shift: SHORTINT;  x: CHAR;
	BEGIN
		shift := 0;  n := 0;  S.GET( pos, x );  INC( pos );
		WHILE ORD( x ) >= 128 DO
			INC( n, ASH( ORD( x ) MOD 128, shift ) );  INC( shift, 7 );  S.GET( pos, x );  INC( pos );
		END;
		i := n + ASH( ORD( x ) MOD 64 - ORD( x ) DIV 64*64, shift )
	END RefReadNum;
	

	PROCEDURE RefReadName( VAR pos: ADDRESS;  VAR n: ARRAY OF CHAR );
	VAR i: INTEGER;  ch: CHAR;
	BEGIN
		i := 0;
		REPEAT  S.GET( pos, ch );  INC( pos );  n[i] := ch;  INC( i )  UNTIL ch = 0X;
	END RefReadName;
	

	PROCEDURE RefReadChar( VAR pos: ADDRESS;  VAR ch: CHAR );
	BEGIN
		S.GET( pos, ch );  INC( pos );
	END RefReadChar;
	

	PROCEDURE ProcByName*( CONST pname: ARRAY OF CHAR;  m: Module ): ADDRESS;
	CONST mBodyTag = 0F8X;  ProcRefTag = 0F9X;  VarTag = 1X;  VarParTag = 3X;
	VAR 
		pos, refend: ADDRESS; 
		adr, t, size, tdAdr: LONGINT;  ch: CHAR;  name: ARRAY 128 OF CHAR; 
		newObjectFile: BOOLEAN;
	BEGIN
		IF pname = "" THEN  RETURN 0  END;
		pos := ADDRESSOF( m.refs[0] );  refend := pos + LEN( m.refs^ );
		RefReadChar( pos, ch );
		newObjectFile := ch = 0FFX;  
		IF newObjectFile THEN  RefReadChar( pos, ch )  END;
		WHILE (pos <= refend) & ((ch = mBodyTag) OR (ch = ProcRefTag)) DO
			RefReadNum( pos, adr );
			IF newObjectFile THEN RefReadNum( pos, t )  END;
			IF ch = ProcRefTag THEN
				RefReadNum( pos, t );	(* nofPars *)
				INC( pos, 3 );		(* ret type, lev, slNeeded *)
				IF newObjectFile THEN  INC( pos, 6 )  END
			END;
			RefReadName( pos, name );
			IF name = pname THEN  RETURN ADDRESSOF( m.code[adr] )  END;
			RefReadChar( pos, ch );
			WHILE (VarTag <= ch) & (ch <= VarParTag) DO
				RefReadChar( pos, ch );   (* form *)
				IF ORD( ch ) >= 80H THEN  RefReadNum( pos, size )
				ELSIF ORD( ch ) >= 14H THEN  RefReadNum( pos, tdAdr )
				END;
				RefReadNum( pos, adr );  RefReadName( pos, name );  RefReadChar( pos, ch );
			END;
		END;
		error.Ln;
		error.String( "Error:  kernel routine '" );  error.String( m.name );  error.Char( '.' );  error.String( pname );  
		error.String( "' not found" );  error.Ln;  RETURN 0
	END ProcByName;


	PROCEDURE FindInsertionPos(VAR entry: ProcTableEntry; VAR pos: LONGINT): BOOLEAN;
	VAR l, r, x: LONGINT; success, isHit: BOOLEAN;
	BEGIN
		pos := -1;
		success := FALSE;
		IF numProcs = 0 THEN (* empty table *)
			pos := 0; success := TRUE
		ELSE
			l := 0; r := numProcs - 1;
			REPEAT
				x := (l + r) DIV 2;
				IF entry.pcLimit < procOffsets[x].data.pcFrom THEN r := x - 1 ELSE l := x + 1 END;
				isHit := ((x = 0) OR (procOffsets[x - 1].data.pcLimit <= entry.pcFrom)) & 
								   (entry.pcLimit <= procOffsets[x].data.pcFrom);
			UNTIL isHit OR (l > r);
			IF isHit THEN
				pos := x; success := TRUE
			ELSE
				IF (x = numProcs - 1) & (procOffsets[x].data.pcLimit <= entry.pcFrom) THEN
					pos := x + 1; success := TRUE
				END
			END
		END;
		RETURN success
	END FindInsertionPos;
	
	
	(* insert the procedure code offsets and pointer offsets of a single module into the global table *)
	PROCEDURE InsertProcOffsets*(procTable: ProcTable; ptrTable: PtrTable; maxPtr: LONGINT);
	VAR success: BOOLEAN; i, pos, poslast: LONGINT; 
	BEGIN
		(* this procedure is called by procedure Publish only and is protected by the Machine.Modules lock *)
		IF LEN(procTable) > 0 THEN
			ASSERT( numProcs + LEN(procTable) <= LEN(procOffsets) );
			
			(*! ptrTabe ignored in UnixAos *)
			
			success := FindInsertionPos(procTable[0], pos); 
			success := success & FindInsertionPos(procTable[LEN(procTable) - 1], poslast);

			IF success THEN
				FOR i := numProcs - 1 TO pos BY -1 DO 
					procOffsets[i + LEN(procTable)] := procOffsets[i] 
				END;
				FOR i := 0 TO LEN(procTable) - 1 DO
					procTable[i].noPtr := 0;	(* ignore the pointers *)
					procOffsets[pos + i].data := procTable[i];
					procOffsets[pos + i].startIndex := 0; 
				END;
				numProcs := numProcs + LEN(procTable);
			END
		END
	END InsertProcOffsets;




(*! begin =============================================================*)

	(* GetNum - Get a compressed refblk number. *)

	PROCEDURE GetNum( refs: Bytes;  VAR i, num: LONGINT );
	VAR n, s: LONGINT;  x: CHAR;
	BEGIN
		s := 0;  n := 0;  x := refs[i];  INC(i);
		WHILE ORD(x) >= 128 DO
			INC( n, ASH( ORD(x) - 128, s ) );  INC( s, 7 );
			x := refs[i];  INC(i)
		END;
		num := n + ASH( ORD(x) MOD 64 - ORD(x) DIV 64 * 64, s )
	END GetNum;
	

	(* VarByName - Find a global variable in the reference block. *)

	PROCEDURE VarByName( refs: Bytes;  CONST name: ARRAY OF CHAR ): SIZE;
	VAR mode: CHAR;  j, m, adr, type, t, i: LONGINT;  s: Name;  found: BOOLEAN;
	BEGIN
		ASSERT((refs[0] = 0F8X) & (refs[1] = 0X) & (refs[2] = "$") & (refs[3] = "$") & (refs[4] = 0X));
		m := LEN(refs^);  found := FALSE; i := 5;
		mode := refs[i];  INC(i);
		WHILE (i < m) & ((mode = 1X) OR (mode = 3X)) & ~found DO	(* var *)
			type := ORD(refs[i]);  INC(i);
			IF (type >= 81H) OR (type = 16H) OR (type = 1DH) THEN
				GetNum( refs, i, t )	(* dim/tdadr *)
			END;
			GetNum( refs, i, adr );	
			j := 0;  REPEAT s[j] := refs[i];  INC(i);  INC(j) UNTIL s[j-1] = 0X;
			IF s = name THEN found := TRUE
			ELSIF i < m THEN mode := refs[i];  INC(i)
			END
		END;
		IF found THEN
			ASSERT((mode = 1X) & ((type = 0DH) OR (type = 1DH) OR (type = 06H)))	(* pointer or LInt VAR *)
		ELSE
			adr := 0
		END;
		RETURN S.VAL( SIZE, adr )
	END VarByName;
	
	

	PROCEDURE AssignValue*( CONST modName, varName: ARRAY OF CHAR; value: LONGINT );
	VAR m: Module; ofs: SIZE;
	BEGIN
		m := root;
		WHILE (m # NIL) & (m.name # modName) DO m := m.next  END;
		IF m = NIL THEN
			error.String( "### AssignValue: module '" ); error.String( modName ); 
			error.String( "' not found" ); error.Ln;
		ELSE
			ofs := VarByName( m.refs, varName );
			IF ofs = 0 THEN
				error.String( "### AssignValue: variable '" ); 
				error.String( modName );  error.Char( '.' );  error.String( varName );
				error.String( "' not found" ); error.Ln
			ELSE
				S.PUT( m.sb + ofs, value );
			END
		END
	END AssignValue;
	
	
	PROCEDURE AssignAddress*( CONST modName, varName: ARRAY OF CHAR; value: ADDRESS );
	VAR m: Module; ofs: SIZE;
	BEGIN
		m := root;
		WHILE (m # NIL) & (m.name # modName) DO m := m.next  END;
		IF m = NIL THEN
			error.String( "### AssignAddress: module '" );  error.String( modName ); 
			error.String( "' not found" ); error.Ln;
		ELSE
			ofs := VarByName( m.refs, varName );
			IF ofs = 0 THEN
				error.String( "### AssignAddress: variable '" ); 
				error.String( modName );  error.Char( '.' );  error.String( varName );
				error.String( "' not found" ); error.Ln
			ELSE
				S.PUT( m.sb + ofs, value );
				Heaps.Relocate( m.sb + ofs ) 
			END
		END
	END AssignAddress;
	

	PROCEDURE RelocateProcOffsets*;	
	VAR i, j: LONGINT; a: ADDRESS;
	BEGIN
		FOR i := 0 TO numProcs - 1 DO
			a := ADDRESSOF( procOffsets[i].data.pcFrom );  j := 0;
			REPEAT
				Heaps.Relocate( a );  INC( a, AddrSize );  INC( j )
			UNTIL j = 4
		END
	END RelocateProcOffsets;

	PROCEDURE RelocatePtrOffsets*;
		(*!	
			pointer offsets are not used by the GC of UnixAos because
			I found no way to obtain the state (PC, SP, BP) of the
			active Objects (POSIX threads).
		*)
	END RelocatePtrOffsets;
	

	PROCEDURE NewSysArray( VAR p: ANY; numElems, elemSize: LONGINT);
	BEGIN
		Heaps.NewSys( p, Heaps.ArraySize( numElems, elemSize, 1 ) );
		S.PUT( S.VAL( ADDRESS, p ) + 3*AddrSize, numElems );	(* dimension *)
	END NewSysArray;

	
	PROCEDURE Initialize*( w: Streams.Writer );
	BEGIN
		error := w;
		
		MakeTD;
		
		NewSysArray( S.VAL( ANY, procOffsets ), InitTableLen, SIZEOF( ProcOffsetEntry ) );
		numProcs := 0; 
		NewSysArray( S.VAL( ANY, ptrOffsets ), InitPtrTableLen, AddrSize );
		numPtrs := 0; 
		root := NIL
	END Initialize;
	
(*! ============================================================= end *)

END BootLinkerModules.




