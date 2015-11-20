(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE BootLinkerLoader;   (** AUTHOR "G.F." ; PURPOSE "UnixAos bootlinker"; *)

(* based on Oberon for Windows bootlinker (MH) and  MIPS bootlinker (RC) *)

(*! BootLinker specific parts are surrounded by: 
	(*! begin =============================*)
	(*! ============================== end *)
*)

IMPORT S := SYSTEM, Heaps := BootLinkerHeaps, Modules := BootLinkerModules, Streams, Files, Strings;

CONST	
	AddrSize = SIZEOF( ADDRESS );

	ObjSuffix* = ".Obj";  BuildDirectory* = "NewAos";

	Ok = 0;
	FileNotFound = 3401;
	TagInvalid = 3402;
	FileCorrupt = 3403;
	(*FileTooShort = 3404;*)
	IncompatibleImport = 3405;
	IncompatibleModuleName = 3406;

	MaxStructs = 1024;	(* maximum number of structures in export block *)

	FileTag = 0BBX;				(* cf. PCM.Mod *)
	NoZeroCompress = 0ADX;	(* cf. PCM.Mod *)
	FileVersion = 0B1X;			(* cf. PCM.Mod *)
	FileVersionOC=0B2X; (* preparation for object and symbol file for new Oberon Compiler *)
	CurrentFileVersion=0B4X;
	
		(* object model exports *)
	EUEnd = 0;  EURecord = 1;  EUobjScope = 0;  EUrecScope = 1;  EUerrScope = -1;
	EUProcFlagBit = 31;

	Sentinel = LONGINT(0FFFFFFFFH);


TYPE
	ObjHeader = RECORD  (* data in object file header *)
				entries			: LONGINT;
				commands	: LONGINT;
				pointers		: LONGINT;
				types			: LONGINT;
				modules		: LONGINT;
				links			: LONGINT;
				dataLinks		: LONGINT;
				refSize, codeSize, dataSize, constSize	: LONGINT;
				exTableLen	: LONGINT;
				procs			: LONGINT;
				maxPtrs		: LONGINT;
				staticTdSize	: LONGINT;
				crc				: LONGINT;
				name			: Modules.Name;
			END;

	LinkRec = RECORD
				mod	: LONGINT;
				entry	: LONGINT;
				link	: SIZE;
			END;

	DataLinkRec = RECORD
				mod	: LONGINT;
				entry	: LONGINT;
				fixups	: LONGINT;
				ofs		: POINTER TO ARRAY OF SIZE;
			END;

	TypeRec = RECORD
				init: BOOLEAN;
				entry, methods, inhMethods, baseMod: LONGINT;
				baseEntry: ADDRESS
			END;



(*! begin =============================================================*)

VAR
	lastMod: Modules.Module;

	dlsymAdr-, entrypoint-: ADDRESS;
	
	error: Streams.Writer;
	


	PROCEDURE TreatGlue( m: Modules.Module );
	VAR i, n: LONGINT; name: Modules.Name; 
	BEGIN
		INC( m.refcnt );   (* gets never unloaded *)

		dlsymAdr := m.sb - AddrSize;	(*! link to Unix (dlsym) *)
		
		n := 0;
		FOR i := 0 TO LEN( m.typeInfo ) - 1 DO
			name := m.typeInfo[i].name;
			IF name = "PtrElemDesc" THEN  Modules.ptrElemTag := m.typeInfo[i].tag ;  INC( n )  END;
		END;
		IF n # 1 THEN
			error.Ln;
			error.String( "### 'PtrElemDesc' not found in module Glue" );  error.Ln;
		END
	END TreatGlue;
	
(*! ============================================================= end *)
	
	

	(* ReadHeader - Read object file header. *)

	PROCEDURE ReadHeader( r: Streams.Reader; VAR h: ObjHeader; VAR res: LONGINT; VAR msg: ARRAY OF CHAR );
	VAR symSize: LONGINT; flags: SET; tag: CHAR;
	BEGIN
		r.Char( tag );
		IF tag = FileTag THEN
			r.Char( tag );
			IF tag = NoZeroCompress THEN  r.Char( tag )  END;	(* no zero compression in symbol file *)
			IF (tag = FileVersion) OR (tag >= FileVersionOC) & (tag <= CurrentFileVersion) THEN
				IF tag = FileVersion THEN
					r.RawNum( symSize );
				ELSIF tag >= FileVersionOC THEN
					r.RawLInt( symSize )
				END;
				flags := {};
				r.SkipBytes( symSize );	(* skip symbols *)

				r.RawLInt( h.refSize );
				r.RawLInt( h.entries );
				r.RawLInt( h.commands );
				r.RawLInt( h.pointers );
				r.RawLInt( h.types );
				r.RawLInt( h.modules );
				r.RawLInt( h.dataLinks );
				r.RawLInt( h.links );
				r.RawLInt( h.dataSize );
				r.RawLInt( h.constSize );
				r.RawLInt( h.codeSize );
				r.RawLInt( h.exTableLen );
				r.RawLInt( h.procs );
				r.RawLInt( h.maxPtrs );
				r.RawLInt( h.staticTdSize ); (* ug *)
				IF ORD(tag) >= 0B4H THEN  r.RawLInt( h.crc )  END;
				r.RawString( h.name );
				IF r.res # Streams.Ok THEN  res := r.res  END
			ELSE
				res := TagInvalid;  COPY( "invalid tag", msg )
			END
		ELSE
			res := TagInvalid; COPY( "invalid tag", msg )
		END
	END ReadHeader;


	PROCEDURE ReadString8( r: Streams.Reader;  VAR string: ARRAY OF CHAR );
	VAR i: LONGINT;  ch: CHAR;
	BEGIN
		i := 0;  r.Char( ch );
		WHILE ch # 0X DO  string[i] := ch;  INC( i );  r.Char( ch )  END;
		string[i] := 0X;
	END ReadString8;
	
	


(*! begin =============================================================*)

	PROCEDURE AllocateModule( m: Modules.Module; h: ObjHeader );
	CONST 
		LenOfs = 3*AddrSize;   (* offset of dimension 0 in array header *)
	VAR 
		dataSize: LONGINT;

		
		PROCEDURE NewSysArray( VAR ptr: ANY; elements, elemSize: LONGINT );
		BEGIN
			Heaps.NewSys( ptr, Heaps.ArraySize( elements, elemSize, 1 ) );
			S.PUT( S.VAL( ADDRESS, ptr ) + LenOfs, elements );   (* dimension *)
			Heaps.Relocate( ADDRESSOF( ptr ) )
		END NewSysArray;

		PROCEDURE NewPtrArray( VAR ptr: ANY; elements: LONGINT );
		VAR adr: ADDRESS;
		BEGIN
			IF elements = 0 THEN (* case of empty array is mapped to a SystemBlock *)
				NewSysArray( ptr, elements, AddrSize )
			ELSE
				Heaps.NewArr( ptr, Modules.ptrElemTag, elements, 1 );
				Heaps.Relocate( ADDRESSOF( ptr ) );
				adr := S.VAL( ADDRESS, ptr );
				S.PUT( adr + LenOfs, elements )  (* dimension *)
			END
		END NewPtrArray;


	BEGIN
		dataSize := h.dataSize + (-h.dataSize) MOD 8;   (* round up to 8 to align constant block *)

		NewSysArray( S.VAL( ANY, m.entry ), h.entries, AddrSize );
		NewSysArray( S.VAL( ANY, m.command ), h.commands, SIZEOF( Modules.Command ) );
		NewSysArray( S.VAL( ANY, m.ptrAdr ), h.pointers, AddrSize );
		NewPtrArray( S.VAL( ANY, m.typeInfo ), h.types );
		NewPtrArray( S.VAL( ANY, m.module ), h.modules );	
		NewSysArray( S.VAL( ANY, m.data ), dataSize + h.constSize, 1 );	
		NewSysArray( S.VAL( ANY, m.code ), h.codeSize, 1 );
		NewSysArray( S.VAL( ANY, m.staticTypeDescs ), h.staticTdSize, 1 );
		NewSysArray( S.VAL( ANY, m.refs ), h.refSize, 1 );
		NewSysArray( S.VAL( ANY, m.exTable ), h.exTableLen, SIZEOF( Modules.ExceptionTableEntry ) );

		m.sb := ADDRESSOF( m.data[0] ) + dataSize;   (* constants positive, data negative *)
		Heaps.Relocate( ADDRESSOF( m.sb ) );
	END AllocateModule;

(*! ============================================================= end *)


	(* ReadEntryBlock - Read the entry block. *)

	PROCEDURE ReadEntryBlock( r: Streams.Reader;  m: Modules.Module ): BOOLEAN;
	VAR tag: CHAR;  i, num: LONGINT;
	BEGIN
		r.Char(tag);
		IF tag = 82X THEN	(* entry tag *)
			FOR i := 0 TO LEN( m.entry ) - 1 DO
				r.RawNum(num);
				m.entry[i] := num + ADDRESSOF( m.code[0] );
				Heaps.Relocate( ADDRESSOF( m.entry[i] ) );
			END;
			(*ASSERT((m.entries > 0) & (m.entry[0] = ADDRESSOF(m.code[0])));*)	(* entry[0] is beginning of code (cf. OPL.Init) *)
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadEntryBlock;


	(* ReadCommandBlock - Read the command block. *)

	PROCEDURE ReadCommandBlock( r: Streams.Reader;  m: Modules.Module ): BOOLEAN;
	VAR tag: CHAR;  i, adr: LONGINT;
	BEGIN
		r.Char( tag );
		IF tag = 83X THEN  (* command tag *)
			FOR i := 0 TO LEN( m.command ) - 1 DO
				r.RawNum( adr );  m.command[i].argTdAdr := adr;
				r.RawNum( adr );  m.command[i].retTdAdr := adr;
				r.RawString( m.command[i].name );
				r.RawNum( adr );  m.command[i].entryAdr := adr;
				(* addresses will be fixed up later in FixupCommands *)
			END;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadCommandBlock;
	


	(* ReadPointerBlock - Read the pointer block. *)

	PROCEDURE ReadPointerBlock( r: Streams.Reader;  m: Modules.Module ): BOOLEAN;
	VAR tag: CHAR;  i, num: LONGINT;
	BEGIN
		r.Char(tag);
		IF tag = 84X THEN	(* pointer tag *)
			FOR i := 0 TO LEN( m.ptrAdr ) - 1 DO
				r.RawNum(num);
				ASSERT(num MOD AddrSize = 0);	(* no deep copy flag *)
				m.ptrAdr[i] := m.sb + num;
				Heaps.Relocate( ADDRESSOF( m.ptrAdr[i] ) );
			END;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadPointerBlock;


	(* ReadImportBlock - Read the import block. *)

	PROCEDURE ReadImportBlock(	r: Streams.Reader;  m: Modules.Module; 
									VAR res: LONGINT;  VAR msg: ARRAY OF CHAR ): BOOLEAN;
	VAR
		tag: CHAR;  i: LONGINT;  name: Modules.Name;
	BEGIN
		r.Char(tag);
		IF tag = 85X THEN	(* import tag *)
			i := 0;
			WHILE (i # LEN( m.module )) & (res = Ok) DO
				ReadString8( r, name );
				(* recursively load the imported module *)
				m.module[i] := Load( name, res, msg );
				Heaps.Relocate( ADDRESSOF( m.module[i] ) );
				INC( i )
			END
		ELSE
			res := FileCorrupt
		END;
		RETURN res = Ok
	END ReadImportBlock;


	(* ReadDataLinkBlock - Read the data links block. *)

	PROCEDURE ReadDataLinkBlock( r: Streams.Reader;  dataLinks: LONGINT;  VAR d: ARRAY OF DataLinkRec ): BOOLEAN;
	VAR tag: CHAR;  i, j, num: LONGINT;
	BEGIN
		r.Char(tag);
		IF tag = 8DX THEN	(* data links tag *)
			FOR i := 0 TO dataLinks-1 DO
				r.Char(tag);  d[i].mod := ORD(tag);
				r.RawNum(num);  d[i].entry := num;
				r.RawLInt(num);  d[i].fixups := num;  (* fixed size *)
				IF d[i].fixups > 0 THEN
					NEW(d[i].ofs, d[i].fixups);
					FOR j := 0 TO d[i].fixups-1 DO
						r.RawNum(num);  d[i].ofs[j] := num
					END
				ELSE
					d[i].ofs := NIL
				END
			END;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadDataLinkBlock;


	(* ReadLinkBlock - Read the link block. *)

	PROCEDURE ReadLinkBlock( r: Streams.Reader;
							  	links, entries: LONGINT;
								VAR l: ARRAY OF LinkRec;
								VAR f: ARRAY OF LONGINT;
								VAR caseTableSize: LONGINT ): BOOLEAN;
	VAR tag: CHAR;  i, num: LONGINT;
	BEGIN
		r.Char( tag );
		IF tag = 86X THEN  (* links tag *)
			FOR i := 0 TO links - 1 DO
				r.Char( tag );  l[i].mod := ORD( tag );  r.Char( tag );  l[i].entry := ORD( tag );
				r.RawNum( num );  l[i].link := num
			END;
			FOR i := 0 TO entries - 1 DO  r.RawNum( num );  f[i] := num;   END;
			r.RawNum( caseTableSize );
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadLinkBlock;


	(* ReadConstBlock - Read the constant block. *)

	PROCEDURE ReadConstBlock( r: Streams.Reader;  m: Modules.Module; h: ObjHeader ): BOOLEAN;
	VAR tag: CHAR;  i: LONGINT;  t: ADDRESS;
	BEGIN
		r.Char(tag);
		IF tag = 87X THEN	(* constant tag *)
			t := m.sb;
			FOR i := 0 TO h.constSize-1 DO
				r.Char(tag);  S.PUT(t, tag);  INC(t)
			END;
			S.GET(m.sb, t);  ASSERT(t = 0);
			S.PUT(m.sb, m);	(* SELF *)  Heaps.Relocate( m.sb );
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadConstBlock;



	PROCEDURE ReadExportBlock( r: Streams.Reader;  m: Modules.Module ): BOOLEAN;
	VAR 
		tag: CHAR;  struct: ARRAY MaxStructs OF ADDRESS;
		structs, i: LONGINT;
		p {UNTRACED}: Modules.ExportPtr; (* this variable must be untraced since it will be casted from a pure address field, it is not a valid heap block *)


		PROCEDURE LoadScope( VAR scope: Modules.ExportDesc;  level, adr: LONGINT );
		VAR no1, no2, fp, off, num: LONGINT;
		BEGIN
			r.RawLInt( num );  scope.exports := num; (* fixed size *)
			no1 := 0;  no2 := 0;

			IF scope.exports # 0 THEN
				Heaps.NewArr( S.VAL( ANY, scope.dsc ), Modules.expTag, scope.exports, 1 );
				Heaps.Relocate( ADDRESSOF( scope.dsc ) );
				scope.dsc[0].adr := adr
			END;
			IF level = EUrecScope THEN
				INC( structs );  struct[structs] := ADDRESSOF( scope )
			END;
			r.RawNum( fp );
			WHILE fp # EUEnd DO
				IF fp = EURecord THEN
					r.RawNum( off );
					IF off < 0 THEN
						p := S.VAL( Modules.ExportPtr, struct[-off] );
						scope.dsc[no2].exports := p.exports;
						scope.dsc[no2].dsc := p.dsc;   (* old type *)
						Heaps.Relocate( ADDRESSOF( scope.dsc[no2].dsc ) )
					ELSE
						LoadScope( scope.dsc[no2], EUrecScope, off )
					END
				ELSE
					IF level = EUobjScope THEN  r.RawNum( adr ); scope.dsc[no1].adr := adr  END;
					scope.dsc[no1].fp := fp;  no2 := no1;  INC( no1 )
				END;
				r.RawNum( fp )
			END
		END LoadScope;

	BEGIN
		r.Char(tag);
		IF tag = 88X THEN	(* export tag *)
			structs := 0;
			FOR i := 0 TO MaxStructs - 1 DO  struct[i] := Heaps.NilVal  END;
			LoadScope( m.export, EUobjScope, 0 );
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadExportBlock;



	(* ReadCodeBlock - Read the code block. *)

	PROCEDURE ReadCodeBlock( r: Streams.Reader;  m: Modules.Module ): BOOLEAN;
	VAR tag: CHAR; ignore: LONGINT;
	BEGIN
		r.Char(tag);
		IF tag = 89X THEN	(* code tag *)
			r.Bytes( m.code^, 0, LEN( m.code ), ignore );
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadCodeBlock;



	(* ReadUseBlock - Read and check the use block. *)
	
	PROCEDURE ReadUseBlock( r: Streams.Reader;  m: Modules.Module;  CONST dataLink: ARRAY OF DataLinkRec;
							   VAR res: LONGINT;  VAR msg: ARRAY OF CHAR
							   ): BOOLEAN;
	VAR tag: CHAR;  mod: Modules.Module;  prevname, name: ARRAY 256 OF CHAR;

		PROCEDURE Err;
		BEGIN
			IF res = Ok THEN
				res := IncompatibleImport;
				COPY( m.name, msg );  Strings.Append( msg, " incompatible with " );  Strings.Append( msg, mod.name );  
				Strings.Append( msg, "  :  " )
			END
		END Err;

		PROCEDURE FixupVar( code:ADDRESS;  link:SIZE;  fixval: ADDRESS );
		VAR i: LONGINT;  val, adr: ADDRESS;
		BEGIN
			ASSERT(dataLink[link].mod # 0);	(* this must be non-local module (?) *)
			FOR i := 0 TO dataLink[link].fixups - 1 DO
				adr := code + dataLink[link].ofs[i];
				S.GET( adr, val );
				S.PUT( adr, val + fixval );		Heaps.Relocate( adr );
			END
		END FixupVar;

		PROCEDURE FixupCall( code: ADDRESS;  link: SIZE;  fixval: ADDRESS );
		VAR nextlink: LONGINT;  opcode: CHAR;
		BEGIN
			REPEAT
				(*ASSERT( (link >= 0) & (link < m.codeSize) );  *)
				S.GET( code + link, nextlink );
				S.GET( code + link - 1, opcode );   (* backward disassembly safe? *)
				IF opcode = 0E8X THEN  (* call instruction relative *)
					S.PUT( code + link, fixval - (code + link + 4) ) (* + 4: to next instruction *)
					(* relative, no further fixup required *)
				ELSE  (* move instruction absolute *)
					S.PUT( code + link, fixval );  Heaps.Relocate( code + link )
				END;
				link := nextlink
			UNTIL link = Sentinel
		END FixupCall;
		
	
		PROCEDURE CheckScope( scope: Modules.ExportDesc;  level: INTEGER );
		VAR fp, link, i: LONGINT;  adr, tdadr: ADDRESS;  tmpErr: BOOLEAN; 
		BEGIN
			tmpErr := (level = EUerrScope);  i := 0;  link := 0;  r.RawNum( fp ); 
			WHILE fp # EUEnd DO
				IF fp = EURecord THEN
					r.RawNum( link );
					IF tmpErr THEN  CheckScope( scope.dsc[i], EUerrScope )
					ELSE
						IF scope.dsc[i].dsc # NIL THEN
							IF link # 0 THEN
								adr := scope.dsc[i].dsc[0].adr;
								S.GET( mod.sb + adr, tdadr );
								S.PUT( m.sb - link, tdadr );  
								Heaps.Relocate( m.sb - link )
							END
						END;
						CheckScope( scope.dsc[i], EUrecScope )
					END
				ELSE
					prevname := name;  ReadString8( r, name );  
					IF level >= EUobjScope THEN
						tmpErr := FALSE;
						IF level = EUobjScope THEN  r.RawNum( link )  END;
						i := 0;
						WHILE (i < scope.exports) & (scope.dsc[i].fp # fp) DO  INC( i )  END;
						IF i >= scope.exports THEN
							Err;  tmpErr := TRUE;  Strings.Append( msg, "/" );
							IF name = "@" THEN  Strings.Append( msg, "@/" );  Strings.Append( msg, prevname )
							ELSE  Strings.Append( msg, name )
							END;
						ELSIF (level = EUobjScope) & (link # 0) THEN
							IF ~(EUProcFlagBit IN S.VAL( SET, link )) THEN
								FixupVar( ADDRESSOF( m.code[0] ), link, mod.sb + scope.dsc[i].adr )
							ELSE
								FixupCall( ADDRESSOF( m.code[0] ),
										    S.VAL( SIZE, S.VAL( SET, link ) - {EUProcFlagBit} ),
										    scope.dsc[i].adr + ADDRESSOF( mod.code[0] ) )
							END
						END
					END
				END;
				r.RawNum( fp )
			END
		END CheckScope;

	BEGIN
		r.Char(tag);
		IF tag = 8AX THEN	(* use tag *)
			ReadString8( r, name );
			WHILE (name # "") & (res = 0) DO
				mod := Load( name, res, msg );
				IF mod # NIL THEN  CheckScope( mod.export, EUobjScope )  END;
				ReadString8( r, name )
			END ;
		ELSE
			res := FileCorrupt
		END;
		RETURN res = Ok
	END ReadUseBlock;	
		


	(* ReadTypeBlock - Read the type block. *)
	
	PROCEDURE ReadTypeBlock( r: Streams.Reader;  m: Modules.Module;  VAR type: ARRAY OF TypeRec ): BOOLEAN;
	VAR
		tag: CHAR;  i, j, num, newMethods, method, pointers, entry: LONGINT;
		tdSize: LONGINT; (* ug *)
		name: Modules.Name;  flags: SET;
		recSize, ofs, totTdSize: SIZE;
		startAddr, tdAdr, base: ADDRESS;
		sTB {UNTRACED}: Heaps.StaticTypeBlock;
	BEGIN
		r.Char(tag);
		IF tag = 8BX THEN	(* type tag *)
			totTdSize := 0;
			IF LEN( m.staticTypeDescs ) > 0 THEN  startAddr := ADDRESSOF(m.staticTypeDescs[0])  END;
			FOR i := 0 TO LEN( type ) - 1 DO
				flags := {};  type[i].init := FALSE;
				r.RawNum( num );  recSize := num;
				r.RawNum( num );  type[i].entry := num;
				r.RawNum( num );  type[i].baseMod := num;
				r.RawNum( num );  type[i].baseEntry := num;
				r.RawNum( num );  type[i].methods := ABS( num );
				IF num # 0 THEN  flags := {Heaps.ProtTypeBit}  END;
				r.RawNum( num );  type[i].inhMethods := num;
				r.RawNum( newMethods );
				r.RawLInt( pointers );
				r.RawString( name );
				r.RawLInt( tdSize );

				Heaps.NewRec( S.VAL( ANY, m.typeInfo[i] ), Modules.tdTag );
				Heaps.Relocate( ADDRESSOF( m.typeInfo[i] ) );
				Heaps.FillStaticType( tdAdr, startAddr, S.VAL( ADDRESS, m.typeInfo[i] ), tdSize, LONGINT(recSize), pointers,
									 Modules.MaxTags + type[i].methods);
				m.typeInfo[i].tag := tdAdr;	Heaps.Relocate( ADDRESSOF( m.typeInfo[i].tag ) );
				m.typeInfo[i].flags := flags;
				m.typeInfo[i].mod := m;		Heaps.Relocate( ADDRESSOF( m.typeInfo[i].mod ) );
				m.typeInfo[i].name := name;

				base := m.typeInfo[i].tag + Modules.Mth0Ofs;   (* read new methods *)
				FOR j := 0 TO newMethods - 1 DO
					r.RawNum( method );
					r.RawNum( entry );
					S.PUT( base - AddrSize*method, m.entry[entry] );
					Heaps.Relocate( base - AddrSize*method );
				END;
				(* other methods are left NIL *)
				sTB := S.VAL( Heaps.StaticTypeBlock, tdAdr );
				ASSERT( LEN( sTB.pointerOffsets ) = pointers );
				FOR j := 0 TO pointers - 1 DO
					r.RawNum( num );  ofs := num;
					ASSERT( ofs MOD 4 = 0 );   (* no deep copy flag *)
					sTB.pointerOffsets[j] := LONGINT(ofs);
					ASSERT( ADDRESSOF( sTB.pointerOffsets[j] ) < startAddr + tdSize )
				END;
				
				ASSERT( m.typeInfo[i].tag # 0 );
				ASSERT( ADDRESSOF( m.data[0] ) <=  m.sb + type[i].entry, 1001 );
				ASSERT( m.sb + type[i].entry+4  <= ADDRESSOF( m.data[LEN(m.data)-1])+1, 1002 );
				
				S.PUT( m.sb + type[i].entry, m.typeInfo[i].tag );    (* patch in constant area *)
				Heaps.Relocate( m.sb + type[i].entry );
				
				startAddr := startAddr + tdSize;
				totTdSize := totTdSize + tdSize;
			END;
			base := S.VAL( ADDRESS, m.typeInfo ) - AddrSize;
			S.PUT( base, Modules.ptrElemTag + 2(*ArrayBit*) );

			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadTypeBlock;


	
	(* ReadRefBlock - Read the reference block. *)

	PROCEDURE ReadRefBlock( r: Streams.Reader;  m: Modules.Module ): BOOLEAN;
	VAR tag: CHAR; ignore: LONGINT;
	BEGIN
		r.Char( tag );
		IF tag = 8CX THEN	(* ref tag *)
			r.Bytes( m.refs^, 0, LEN( m.refs ), ignore );
			RETURN TRUE
		ELSE
			RETURN FALSE
		END
	END ReadRefBlock;
	
	
	
	(* FixupGlobals - Fix up references to global variables. *)
	
	PROCEDURE FixupGlobals( m: Modules.Module;  CONST dataLink: ARRAY OF DataLinkRec );
	VAR i: LONGINT; t: SIZE;  adr: ADDRESS;
	BEGIN
		IF dataLink[0].mod = 0 THEN  (* local module has globals *)
			FOR i := 0 TO dataLink[0].fixups - 1 DO
				adr := ADDRESSOF( m.code[0] ) + dataLink[0].ofs[i];
				S.GET( adr, t );  S.PUT( adr, t + m.sb );  Heaps.Relocate( adr )
			END
		END
	END FixupGlobals;
	
	
	
	(* FixupLinks - Fix up other references. *)

	PROCEDURE FixupLinks( m: Modules.Module;  
							CONST link: ARRAY OF LinkRec;
							VAR fixupCounts: ARRAY OF LONGINT;
							caseTableSize: LONGINT;
							VAR res: LONGINT );
	VAR 
		codeadr: ADDRESS;  i: LONGINT;

		PROCEDURE FixRelative( ofs: SIZE;  val: ADDRESS );
		VAR t: SIZE;  adr: ADDRESS;
		BEGIN
			ASSERT( val # 0 );
			WHILE ofs # Sentinel DO
				adr := codeadr + ofs;  S.GET( adr, t );
				S.PUT( adr, val - (adr + 4) );   (* fixup for relative CALL instruction => no relocation required *)
				ofs := t
			END
		END FixRelative;

		PROCEDURE FixEntry( ofs: SIZE;  VAR fixupCounts: ARRAY OF LONGINT );
		VAR t: SIZE;  adr: ADDRESS;  i: LONGINT;
		BEGIN
			i := 0;
			WHILE ofs # Sentinel  DO
				adr := codeadr + ofs;  S.GET( adr, t );
				WHILE fixupCounts[i] = 0 DO  INC( i )  END;
				S.PUT( adr, m.entry[i] );  Heaps.Relocate( adr );
				DEC( fixupCounts[i] );  ofs := t
			END
		END FixEntry;

		PROCEDURE FixCase( ofs: SIZE; caseTableSize: LONGINT );
		VAR t: SIZE;  adr: ADDRESS; i: LONGINT;
		BEGIN
			i := caseTableSize;
			WHILE i > 0 DO
				adr := m.sb + ofs;  S.GET( adr, t );  S.PUT( adr, codeadr + t );  Heaps.Relocate( adr );
				DEC( i );  ofs := ofs + 4
			END
		END FixCase;

	BEGIN
		codeadr := ADDRESSOF( m.code[0] );
		FOR i := 0 TO LEN( link ) - 1 DO
			ASSERT( link[i].mod = 0 );   (* only fix local things *)
			CASE link[i].entry OF
			| 243 .. 253: HALT(100);	(* not supported any more, replaced by direct call *)
			| 254:   FixEntry( link[i].link, fixupCounts ) (* local procedure address *)
			| 255:   FixCase( link[i].link, caseTableSize ) (* case table *)
			ELSE
				res := 3406;  RETURN  (* unknown fixup type *)
			END
		END
	END FixupLinks;
	
	
	(*	When loader parsed the command block, the type descriptors had not yet been allocated
		so we could not fixup the addresses -> do it now. *)
	PROCEDURE FixupCommands( m: Modules.Module );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO LEN( m.command ) - 1 DO
			m.command[i].entryAdr := m.command[i].entryAdr + ADDRESSOF( m.code[0] );
			Heaps.Relocate( ADDRESSOF( m.command[i].entryAdr ) );
			IF m.command[i].argTdAdr > 1 THEN
				S.GET( m.sb + m.command[i].argTdAdr, m.command[i].argTdAdr );
				Heaps.Relocate( ADDRESSOF( m.command[i].argTdAdr ) )
			END;
			IF m.command[i].retTdAdr > 1 THEN
				S.GET( m.sb + m.command[i].retTdAdr, m.command[i].retTdAdr );
				Heaps.Relocate( ADDRESSOF( m.command[i].retTdAdr ) )
			END;
		END;
	END FixupCommands;



	(* InitType - Initialize a dynamic type. *)

	PROCEDURE InitType( m: Modules.Module;  VAR type: ARRAY OF TypeRec;  i: LONGINT );
	VAR 
		j, baseMod, extLevel: LONGINT;  t, root, baseTag, baseMth, baseRoot: ADDRESS;  baseM: Modules.Module;
	BEGIN
		IF ~type[i].init THEN
			root := m.typeInfo[i].tag;
			baseTag := root + Modules.Tag0Ofs;
			baseMth := root + Modules.Mth0Ofs;
			baseMod := type[i].baseMod;  extLevel := 0;
			ASSERT( baseMod >= -1 );
			IF baseMod # -1 THEN  (* extended type *)
				IF baseMod = 0 THEN  (* base type local *)
					j := 0;
					WHILE type[j].entry # type[i].baseEntry DO  INC( j )  END;   (* find base type *)
					InitType( m, type, j );   (* and initialize it first *)
					baseM := m
				ELSE  (* base type imported *)
					baseM := m.module[baseMod - 1];
					t := type[i].baseEntry;   (* fingerprint *)
					j := 0;
					WHILE baseM.export.dsc[j].fp # t DO  INC( j )  END;   (* find base type *)
					type[i].baseEntry := baseM.export.dsc[j].dsc[0].adr
				END;
				(* copy base tags *)
				S.GET( baseM.sb + type[i].baseEntry, baseRoot );
				S.GET( baseRoot + Modules.Tag0Ofs, t );
				WHILE t # 0 DO
					S.PUT( baseTag - AddrSize*extLevel, t );  Heaps.Relocate( baseTag - AddrSize*extLevel );
					INC( extLevel );
					S.GET( baseRoot + Modules.Tag0Ofs - AddrSize*extLevel, t )
				END;
				(* copy non-overwritten base methods *)
				FOR j := 0 TO type[i].inhMethods - 1 DO
					S.GET( baseMth - AddrSize*j, t );   (* existing method *)
					IF t = 0 THEN
						S.GET( baseRoot + Modules.Mth0Ofs - AddrSize*j, t );   (* base method *)
						S.PUT( baseMth - AddrSize*j, t );  Heaps.Relocate( baseMth - AddrSize*j )
					END;
				END
			END;
			m.typeInfo[i].flags := m.typeInfo[i].flags + S.VAL( SET, extLevel );
			ASSERT( extLevel < Modules.MaxTags );

			S.PUT( baseTag - AddrSize*extLevel, m.typeInfo[i].tag );    (* self *)
			Heaps.Relocate( baseTag - AddrSize*extLevel );

			(* init type for static type descriptors *)
			type[i].init := TRUE
		END
	END InitType;



	PROCEDURE ReadExTableBlock( r: Streams.Reader;  m: Modules.Module ): BOOLEAN;
	VAR tag: CHAR;  pcFrom, pcTo, pcHandler, i: LONGINT;

		PROCEDURE SelectionSort( exTable: Modules.ExceptionTable );
		VAR p, q, min: LONGINT;  entry: Modules.ExceptionTableEntry;
		BEGIN
			FOR p := 0 TO LEN( exTable ) - 2 DO
				min := p;
				FOR q := p + 1 TO LEN( exTable ) - 1 DO
					IF exTable[min].pcFrom > exTable[q].pcFrom THEN  min := q  END;
					entry := exTable[min];  exTable[min] := exTable[p];  exTable[p] := entry;
				END
			END
		END SelectionSort;

	BEGIN
		r.Char( tag );
		IF tag = 8EX THEN
			FOR i := 0 TO LEN( m.exTable ) - 1 DO
				r.Char( tag );
				IF tag = 0FEX THEN
					r.RawNum( pcFrom );
					r.RawNum( pcTo );
					r.RawNum( pcHandler );
					m.exTable[i].pcFrom := pcFrom + ADDRESSOF( m.code[0] );
					Heaps.Relocate( ADDRESSOF( m.exTable[i].pcFrom ) );
					m.exTable[i].pcTo := pcTo + ADDRESSOF( m.code[0] );
					Heaps.Relocate( ADDRESSOF( m.exTable[i].pcTo ) );
					m.exTable[i].pcHandler := pcHandler + ADDRESSOF( m.code[0] );
					Heaps.Relocate( ADDRESSOF( m.exTable[i].pcHandler ) )
				ELSE
					RETURN FALSE
				END;
			END;
			SelectionSort( m.exTable );
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END ReadExTableBlock;




	PROCEDURE ReadPtrsInProcBlock( r: Streams.Reader;  m: Modules.Module ): BOOLEAN;
	VAR
		tag: CHAR;  i, j, codeoffset, beginOffset, endOffset, nofptrs, p: LONGINT;
		procTable: Modules.ProcTable;  ptrTable: Modules.PtrTable;

		PROCEDURE Max( i, j: LONGINT ): LONGINT;
		BEGIN
			IF i > j THEN  RETURN i  ELSE  RETURN j  END
		END Max;

		PROCEDURE SwapProcTableEntries( p, q: LONGINT );
		VAR 
			procentry: Modules.ProcTableEntry;  
			k, i, basep, baseq: LONGINT;  ptr: SIZE;
		BEGIN
			k := Max( procTable[p].noPtr, procTable[q].noPtr );
			IF k > 0 THEN  (* swap entries in ptrTable first *)
				basep := p*m.maxPtrs;  baseq := q*m.maxPtrs;
				FOR i := 0 TO k - 1 DO
					ptr := ptrTable[basep + i];  ptrTable[basep + i] := ptrTable[baseq + i];  ptrTable[baseq + i] := ptr
				END
			END;
			procentry := procTable[p];  procTable[p] := procTable[q];  procTable[q] := procentry
		END SwapProcTableEntries;

		PROCEDURE SortProcTable;
		VAR i, j, min: LONGINT;
		BEGIN
			FOR i := 0 TO m.noProcs - 2 DO
				min := i;
				FOR j := i + 1 TO m.noProcs - 1 DO
					IF procTable[j].pcFrom < procTable[min].pcFrom THEN  min := j  END
				END;
				IF min # i THEN  SwapProcTableEntries( i, min )  END
			END
		END SortProcTable;

	BEGIN
		r.Char( tag );
		IF tag = 8FX THEN
			NEW( procTable, m.noProcs );  NEW( ptrTable, m.noProcs*m.maxPtrs );
			(* m.noProcs > 0 since the empty module contains the module body procedure *)
			FOR i := 0 TO m.noProcs - 1 DO
				r.RawNum( codeoffset );
				r.RawNum( beginOffset );
				r.RawNum( endOffset );
				r.RawLInt( nofptrs );   (* fixed size *)

				procTable[i].pcFrom := codeoffset + ADDRESSOF( m.code[0] );
				procTable[i].pcStatementBegin := beginOffset + ADDRESSOF( m.code[0] );
				procTable[i].pcStatementEnd := endOffset + ADDRESSOF( m.code[0] );
				procTable[i].noPtr := nofptrs;
				FOR j := 0 TO nofptrs - 1 DO  r.RawNum( p );  ptrTable[i*m.maxPtrs + j] := p;   END  ;
			END;
			SortProcTable();
			m.firstProc := procTable[0].pcFrom;  Heaps.Relocate( ADDRESSOF( m.firstProc ) );
			FOR i := 0 TO m.noProcs - 2 DO  procTable[i].pcLimit := procTable[i + 1].pcFrom  END;
			procTable[m.noProcs - 1].pcLimit := ADDRESSOF( m.code[0] ) + LEN( m.code ) + 1;
					(* last element reserved for end of code segment, allow 1 byte extra, cf. Modules.ThisModuleByAdr *)
					
			Modules.InsertProcOffsets(procTable, ptrTable, m.maxPtrs);
			procTable := NIL;  ptrTable := NIL;
			RETURN TRUE
		ELSE
			RETURN FALSE
		END;
	END ReadPtrsInProcBlock;
	



	PROCEDURE LoadObj( CONST name, fileName: ARRAY OF CHAR;  r: Streams.Reader;
						 	VAR res: LONGINT;  VAR msg: ARRAY OF CHAR
							): Modules.Module;
	VAR 	
		i, caseTableSize: LONGINT;   imp: Modules.Module;
		h: ObjHeader;
		links: POINTER TO ARRAY OF LinkRec;
		fixupCounts: POINTER TO ARRAY OF LONGINT;
		dataLink: POINTER TO ARRAY OF DataLinkRec;
		type: POINTER TO ARRAY OF TypeRec;
		m: Modules.Module;
	BEGIN
		res := Ok;
		ReadHeader( r, h, res, msg );
		IF res = Ok THEN
			IF h.name = name THEN

				Heaps.NewProtRec( S.VAL( ANY, m ), Modules.modTag );  

				imp := lastMod;
				IF imp # NIL THEN  imp.next := m;  Heaps.Relocate( ADDRESSOF( imp.next ) )   END;
				lastMod := m;
				IF Modules.root = NIL THEN  Modules.root := lastMod  END;
				m.init := FALSE;  m.refcnt := 0;  m.next := NIL;  m.export.dsc := NIL;  m.term := NIL;
				
				i := 0;  
				WHILE h.name[i] # 0X DO m.name[i] := h.name[i];  INC(i) END;
				m.name[i] := 0X;
				
				m.noProcs := h.procs;  m.maxPtrs := h.maxPtrs;  m.crc := h.crc;

				AllocateModule( m, h );

				NEW( dataLink, h.dataLinks );  NEW( links, h.links );  NEW( fixupCounts, h.entries );
				NEW( type, h.types );

				IF ReadEntryBlock( r, m ) & ReadCommandBlock( r, m ) & ReadPointerBlock( r, m ) &
					ReadImportBlock( r, m, res, msg ) & ReadDataLinkBlock( r, h.dataLinks, dataLink^ ) &
					ReadLinkBlock( r, h.links, h.entries, links^, fixupCounts^, caseTableSize ) &
					ReadConstBlock(r, m, h) & ReadExportBlock(r, m) & ReadCodeBlock( r, m ) &
					ReadUseBlock( r, m, dataLink^, res, msg ) & ReadTypeBlock( r, m, type^ ) &
					ReadExTableBlock( r, m ) & ReadPtrsInProcBlock( r, m )  & ReadRefBlock( r, m )
				THEN
(*! begin =============================================================*)
					IF m.name = "Glue" THEN  TreatGlue( m )
					ELSIF m.name = "Modules" THEN  Modules.FixupTypes( m ); 
					ELSIF m.name = "BootConsole" THEN  entrypoint := ADDRESSOF( m.code[0] )
					END;
(*! ============================================================= end *)
					IF h.dataLinks # 0 THEN  FixupGlobals( m, dataLink^ )  END;
					IF h.links # 0 THEN  FixupLinks( m, links^, fixupCounts^, caseTableSize, res )  END;
					IF h.commands # 0 THEN  FixupCommands( m )  END;
					IF res = Ok THEN
						FOR i := 0 TO LEN(type^) - 1 DO  InitType( m, type^, i )  END
					END;
					dataLink := NIL;  links := NIL;  type := NIL;
					m.init := TRUE;  m.published := TRUE;
				END
			END
		ELSE
			res := IncompatibleModuleName;  COPY(fileName, msg);  Strings.Append( msg, " incompatible module name" )
		END;
		IF (res # Ok) & (msg[0] = 0X) THEN  COPY(fileName, msg);  Strings.Append( msg, " corrupt" )  END;
		IF res # Ok THEN  m := NIL  END;
		RETURN m
	END LoadObj;




(*! begin =============================================================*)

	PROCEDURE Load*( CONST name: ARRAY OF CHAR; VAR res: LONGINT;  VAR msg:  ARRAY OF CHAR ): Modules.Module;
	VAR f: Files.File;  r: Files.Reader;
		fname: ARRAY 64 OF CHAR;
		m: Modules.Module;
	BEGIN
		m := Modules.root;  res := Ok;
		WHILE (m # NIL ) & (name # m.name) DO  m := m.next  END;
		IF m = NIL THEN
			fname := BuildDirectory;  Strings.Append( fname, "/" );
			Strings.Append( fname, name );  Strings.Append( fname, ObjSuffix );
			f := Files.Old( fname );
			IF f = NIL THEN
				msg := " file not found: ";  Strings.Append( msg, fname ); 
				res := FileNotFound;  RETURN  NIL
			END;
			Files.OpenReader( r, f, 0 );
			m := LoadObj( name, fname, r, res, msg )
		ELSIF ~m.init THEN
			msg := " cyclic import not allowed: ";  Strings.Append( msg, m.name );
			res := IncompatibleImport;
			m := NIL
		END;
		RETURN m
	END Load; 
	


	PROCEDURE Initialize*( w: Streams.Writer );
	BEGIN
		error := w;		
		dlsymAdr := 0;  entrypoint := 0
	END Initialize;
	
(*! ============================================================= end *)		

END BootLinkerLoader.



