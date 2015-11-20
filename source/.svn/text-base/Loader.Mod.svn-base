(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Loader; (** AUTHOR "pjm"; PURPOSE "Active Oberon module loader plugin"; *)

(* cf. Linker *)

IMPORT SYSTEM, KernelLog, Commands, Heaps, Modules, Machine, Streams, Files;

CONST
	Ok = 0;
	FileNotFound = 3401;
	TagInvalid = 3402;
	FileCorrupt = 3403;
	(*FileTooShort = 3404;*)
	IncompatibleImport = 3405;
	IncompatibleModuleName = 3406;

	AddressSize = SIZEOF (ADDRESS);

	MaxStructs = 1024;	(* maximum number of structures in export block *)

	FileTag = 0BBX;				(* cf. PCM.Mod *)
	NoZeroCompress = 0ADX;	(* cf. PCM.Mod *)
	FileVersion* = 0B1X;			(* cf. PCM.Mod *)
	FileVersionOC=0B2X; (* preparation for object and symbol file for new Oberon Compiler *)
	CurrentFileVersion=0B4X;

		(* object model exports *)
	EUEnd = 0;  EURecord = 1;  EUobjScope = 0;  EUrecScope = 1;  EUerrScope = -1;
	EUProcFlagBit = 31;

	Sentinel = LONGINT(0FFFFFFFFH);

		(* compiler flags *)
	UsesDefinitions = 31;

	DefinitionModule = "Interfaces";	(* runtime module that supplies definition support *)

TYPE
	ObjHeader = RECORD (* data from object file header *)
		entries, commands, pointers, types, modules, links, dataLinks: LONGINT;
		codeSize, dataSize, refSize, constSize, exTableLen, procs, maxPtrs, crc: LONGINT;
		staticTdSize: LONGINT; (* ug *)
		name: Modules.Name
	END;

	DataLinkRec = RECORD
		mod: LONGINT;
		entry: LONGINT;
		fixups: LONGINT;
		ofs: POINTER TO ARRAY OF SIZE
	END;

	LinkRec = RECORD
		mod: LONGINT;
		entry: LONGINT;
		link: SIZE
	END;

	TypeRec = RECORD
		init: BOOLEAN;
		entry, methods, inhMethods, baseMod: LONGINT;
		baseEntry: ADDRESS;
	END;

VAR
	trace: BOOLEAN;

(* ReadHeader - Read object file header. *)

PROCEDURE ReadHeader(r: Streams.Reader; VAR h: ObjHeader; VAR res: LONGINT; VAR msg: ARRAY OF CHAR);
VAR symSize: LONGINT; flags: SET; ignore: Modules.Module; tag: CHAR;
BEGIN
	r.Char(tag);
	IF tag = FileTag THEN
		r.Char(tag);
		IF tag = NoZeroCompress THEN r.Char(tag) END;	(* no zero compression in symbol file *)
		IF (tag = FileVersion) OR (tag >= FileVersionOC) & (tag <= CurrentFileVersion) THEN
			IF tag = FileVersion THEN
			r.RawNum(symSize);
			ELSIF tag >= FileVersionOC THEN
			r.RawLInt(symSize)
			END;
			flags := {};
			r.SkipBytes(symSize);	(* skip symbols *)

			r.RawLInt(h.refSize);
			r.RawLInt(h.entries);
			r.RawLInt(h.commands);
			r.RawLInt(h.pointers);
			r.RawLInt(h.types);
			r.RawLInt(h.modules);
			r.RawLInt(h.dataLinks);
			r.RawLInt(h.links);
			r.RawLInt(h.dataSize);
			r.RawLInt(h.constSize);
			r.RawLInt(h.codeSize);
			r.RawLInt(h.exTableLen);
			r.RawLInt(h.procs);
			r.RawLInt(h.maxPtrs);
			r.RawLInt(h.staticTdSize); (* ug *)
			IF ORD(tag) >= 0B4H THEN r.RawLInt(h.crc) END;
			r.RawString(h.name);
			IF trace THEN
				KernelLog.String("  name: ");  KernelLog.String(h.name);
				KernelLog.String("  symSize: ");  KernelLog.Int(symSize, 1);
				KernelLog.String("  refSize: ");  KernelLog.Int(h.refSize, 1);  KernelLog.Ln;
				KernelLog.String("  entries: ");  KernelLog.Int(h.entries, 1);
				KernelLog.String("  commands: ");  KernelLog.Int(h.commands, 1);
				KernelLog.String("  pointers: ");  KernelLog.Int(h.pointers, 1);
				KernelLog.String("  types: ");  KernelLog.Int(h.types, 1);
				KernelLog.String("  modules: ");  KernelLog.Int(h.modules, 1);  KernelLog.Ln;
				KernelLog.String("  dataLinks: ");  KernelLog.Int(h.dataLinks, 1);
				KernelLog.String("  links: ");  KernelLog.Int(h.links, 1);
				KernelLog.String("  dataSize: ");  KernelLog.Int(h.dataSize, 1);
				KernelLog.String("  constSize: ");  KernelLog.Int(h.constSize, 1);
				KernelLog.String("  codeSize: ");  KernelLog.Int(h.codeSize, 1);  KernelLog.Ln;
				KernelLog.String("  exTableLen: ");  KernelLog.Int(h.exTableLen, 1);
				KernelLog.String("  procs: "); KernelLog.Int(h.procs, 1);
				KernelLog.String("  maxPtrs: "); KernelLog.Int(h.maxPtrs, 1);
				KernelLog.String("  staticTdSize: "); KernelLog.Int(h.staticTdSize, 1); KernelLog.Ln
			END;
			IF r.res # Streams.Ok THEN res := r.res END
		ELSE
			res := TagInvalid
		END
	ELSE
		res := TagInvalid
	END
END ReadHeader;

(* zero compressed strings don't like UTF-8 encoding *)
PROCEDURE ReadString8(r: Streams.Reader;  VAR str: ARRAY OF CHAR);
VAR i: LONGINT;  ch: CHAR;
BEGIN
	i := 0;
	r.Char(ch);
	WHILE ch # 0X DO
		str[i] := ch; INC(i);
		r.Char(ch);
	END;
	str[i] := 0X;
END ReadString8;

PROCEDURE AllocateModule(m: Modules.Module; h: ObjHeader);
VAR dataSize: SIZE;
BEGIN
	dataSize := SYSTEM.VAL(SIZE, h.dataSize) + (-h.dataSize) MOD 8;	(* round up to 8 to align constant block *)

	NEW(m.entry, h.entries);
	NEW(m.command, h.commands);
	NEW(m.ptrAdr, h.pointers);
	NEW(m.typeInfo, h.types);
	NEW(m.module, h.modules);
	NEW(m.data, dataSize + h.constSize);
	NEW(m.code, h.codeSize);
	NEW(m.staticTypeDescs, h.staticTdSize);
	NEW(m.refs, h.refSize);
	NEW(m.exTable, h.exTableLen);

	m.sb := ADDRESSOF(m.data[0]) + dataSize;	(* constants positive, data negative *)
END AllocateModule;

(* ReadEntryBlock - Read the entry block. *)

PROCEDURE ReadEntryBlock(r: Streams.Reader;  m: Modules.Module): BOOLEAN;
VAR tag: CHAR;  i, num: LONGINT;
BEGIN
	r.Char(tag);
	IF tag = 82X THEN	(* entry tag *)
		FOR i := 0 TO LEN(m.entry)-1 DO
			r.RawNum(num);
			m.entry[i] := num + ADDRESSOF(m.code[0])
		END;
		(*ASSERT((m.entries > 0) & (m.entry[0] = ADDRESSOF(m.code[0])));*)	(* entry[0] is beginning of code (cf. OPL.Init) *)
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReadEntryBlock;

(* ReadCommandBlock - Read the command block. *)

PROCEDURE ReadCommandBlock(r: Streams.Reader;  m: Modules.Module): BOOLEAN;
VAR tag : CHAR; i, adr : LONGINT;
BEGIN
	r.Char(tag);
	IF tag = 83X THEN (* command tag *)
		FOR i := 0 TO LEN(m.command)-1 DO
			r.RawNum(adr); m.command[i].argTdAdr := adr;
			r.RawNum(adr); m.command[i].retTdAdr := adr;
			r.RawString(m.command[i].name);
			r.RawNum(adr); m.command[i].entryAdr := adr;
			(* addresses will be fixed up later in FixupCommands *)
		END;
		RETURN TRUE
	ELSE
		RETURN FALSE
	END;
END ReadCommandBlock;

(* ReadPointerBlock - Read the pointer block. *)

PROCEDURE ReadPointerBlock(r: Streams.Reader;  m: Modules.Module): BOOLEAN;
VAR tag: CHAR;  i, num: LONGINT;
BEGIN
	r.Char(tag);
	IF tag = 84X THEN	(* pointer tag *)
		FOR i := 0 TO LEN(m.ptrAdr)-1 DO
			r.RawNum(num);
			ASSERT(num MOD AddressSize = 0);	(* no deep copy flag *)
			m.ptrAdr[i] := m.sb + num
		END;
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReadPointerBlock;

(* ReadImportBlock - Read the import block. *)

PROCEDURE ReadImportBlock(r: Streams.Reader;  m: Modules.Module;  VAR res: LONGINT;
		VAR msg: ARRAY OF CHAR): BOOLEAN;
VAR tag: CHAR;  i: LONGINT;  name: Modules.Name;
BEGIN
	r.Char(tag);
	IF tag = 85X THEN	(* import tag *)
		i := 0;
		WHILE (i # LEN(m.module)) & (res = Ok) DO
			ReadString8(r, name);
			m.module[i] := Modules.ThisModule(name, res, msg);	(* recursively load the imported module *)
			INC(i)
		END
	ELSE
		res := FileCorrupt
	END;
	RETURN res = Ok
END ReadImportBlock;

(* ReadDataLinkBlock - Read the data links block. *)

PROCEDURE ReadDataLinkBlock(r: Streams.Reader;  dataLinks: LONGINT;  VAR d: ARRAY OF DataLinkRec): BOOLEAN;
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

PROCEDURE ReadLinkBlock(r: Streams.Reader;  links, entries: LONGINT;  VAR l: ARRAY OF LinkRec; VAR f: ARRAY OF LONGINT; VAR caseTableSize: LONGINT): BOOLEAN;
VAR tag: CHAR;  i, num: LONGINT;
BEGIN
	r.Char(tag);
	IF tag = 86X THEN	(* links tag *)
		FOR i := 0 TO links-1 DO
			r.Char(tag);  l[i].mod := ORD(tag);
			r.Char(tag);  l[i].entry := ORD(tag);
			r.RawNum(num);  l[i].link := num
		END;
		FOR i := 0 TO entries-1 DO
			r.RawNum(num); f[i] := num;
		END;
		r.RawNum(caseTableSize);
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReadLinkBlock;

(* ReadConstBlock - Read the constant block. *)

PROCEDURE ReadConstBlock(r: Streams.Reader;  m: Modules.Module; h: ObjHeader): BOOLEAN;
VAR tag: CHAR;  i: LONGINT; t: ADDRESS;
BEGIN
	r.Char(tag);
	IF tag = 87X THEN	(* constant tag *)
		t := m.sb;
		FOR i := 0 TO h.constSize-1 DO
			r.Char(tag);  SYSTEM.PUT(t, tag);  INC(t)
		END;
		SYSTEM.GET(m.sb, t);  ASSERT(t = 0);
		SYSTEM.PUT(m.sb, m);	(* SELF *)
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReadConstBlock;

(* ReadExportBlock - Read the export block. *)

PROCEDURE ReadExportBlock(r: Streams.Reader;  m: Modules.Module): BOOLEAN;
TYPE ExportPtr = POINTER TO Modules.ExportDesc; (* this type is introduced to dereference fields of an ExportDesc variable *)
VAR tag: CHAR;  structs, i: LONGINT; struct: ARRAY MaxStructs OF ADDRESS;
	p {UNTRACED}: ExportPtr; (* this variable must be untraced since it will be casted from a pure address field, it is not a valid heap block *)

	PROCEDURE LoadScope(VAR scope: Modules.ExportDesc;  level, adr: LONGINT);
	VAR no1, no2, fp, off, num: LONGINT;
	BEGIN
		r.RawLInt(num);  scope.exports := num; (* fixed size *)
		no1 := 0;  no2 := 0;
		IF scope.exports # 0 THEN
			NEW(scope.dsc, scope.exports);
			scope.dsc[0].adr := adr
		END;
		IF level = EUrecScope THEN
			INC(structs); struct[structs] := SYSTEM.VAL(ADDRESS, ADDRESSOF(scope))
		END;
		r.RawNum(fp);
		WHILE fp # EUEnd DO
			IF fp = EURecord THEN
				r.RawNum(off);
				IF off < 0 THEN
					p := SYSTEM.VAL(ExportPtr, struct[-off]);
					scope.dsc[no2].exports := p.exports;
					scope.dsc[no2].dsc := p.dsc	(* old type *)
				ELSE
					LoadScope(scope.dsc[no2], EUrecScope, off)
				END
			ELSE
				IF level = EUobjScope THEN r.RawNum(adr); scope.dsc[no1].adr := adr END;
				scope.dsc[no1].fp := fp;  no2 := no1;  INC(no1)
			END;
			r.RawNum(fp)
		END
	END LoadScope;

BEGIN
	r.Char(tag);
	IF tag = 88X THEN	(* export tag *)
		structs := 0;
		FOR i := 0 TO MaxStructs - 1 DO struct[i] := Heaps.NilVal END;
		LoadScope(m.export, EUobjScope, 0);
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReadExportBlock;

(* ReadCodeBlock - Read the code block. *)

PROCEDURE ReadCodeBlock(r: Streams.Reader;  m: Modules.Module): BOOLEAN;
VAR tag: CHAR; ignore: LONGINT;
BEGIN
	r.Char(tag);
	IF tag = 89X THEN	(* code tag *)
		r.Bytes(m.code^, 0, LEN(m.code), ignore);
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReadCodeBlock;

(* ReadUseBlock - Read and check the use block. *)

PROCEDURE ReadUseBlock(r: Streams.Reader;  m: Modules.Module;  VAR dataLink: ARRAY OF DataLinkRec;
		VAR res: LONGINT;  VAR msg: ARRAY OF CHAR): BOOLEAN;
VAR tag: CHAR;  i: LONGINT;  name, prevname: ARRAY 256 OF CHAR; (*fof: not Modules.Name as name might consist of several identifiers, e.g. for methods *)
	mod: Modules.Module;

	PROCEDURE Err;
	BEGIN
		IF res = Ok THEN
			res := IncompatibleImport;
			COPY(m.name, msg);  Modules.Append(" incompatible with ", msg);  Modules.Append(mod.name, msg);
		END
	END Err;

	PROCEDURE FixupCall(code: ADDRESS; link: SIZE; fixval: ADDRESS);
	VAR nextlink: SIZE; opcode: CHAR;
	BEGIN
		REPEAT
			ASSERT((link >= 0) & (link < LEN(m.code)));
			SYSTEM.GET(code + link, nextlink);
			SYSTEM.GET(code + link - 1, opcode);	(* backward disassembly safe? *)
			IF opcode = 0E8X THEN	(* call instruction relative *)
				SYSTEM.PUT(code + link, fixval - (code + link + 4)) (* + 4: to next instruction *)
				(* relative, no further fixup required *)
			ELSE	(* move instruction absolute *)
				SYSTEM.PUT(code + link, fixval)
			END;
			link := nextlink
		UNTIL link = Sentinel
	END FixupCall;

	PROCEDURE FixupVar(code: ADDRESS; link: SIZE; fixval: ADDRESS);
	VAR i: LONGINT; val, adr: ADDRESS;
	BEGIN
		ASSERT(dataLink[link].mod # 0);	(* this must be non-local module (?) *)
		FOR i := 0 TO dataLink[link].fixups-1 DO
			adr := code + dataLink[link].ofs[i];
			SYSTEM.GET(adr, val);	(* non-zero for example with constant index into imported array *)
			SYSTEM.PUT(adr, val + fixval)
		END
	END FixupVar;

	PROCEDURE CheckScope(scope: Modules.ExportDesc;  level: LONGINT);
	VAR fp, i, link: LONGINT; adr: SIZE; tdadr: ADDRESS; tmpErr: BOOLEAN;
	BEGIN
		tmpErr := (level = EUerrScope);
		i := 0;  link := 0;
		r.RawNum(fp);
		WHILE fp # EUEnd DO
			IF fp = EURecord THEN
				r.RawNum(link);
				IF tmpErr THEN
					CheckScope(scope.dsc[i], EUerrScope)
				ELSE
					IF scope.dsc[i].dsc # NIL THEN
						IF link # 0 THEN
							adr := scope.dsc[i].dsc[0].adr;
							SYSTEM.GET(mod.sb + adr, tdadr);
							SYSTEM.PUT(m.sb-link, tdadr)	(* tdadr at tadr[0] *)
						END
					END;
					CheckScope(scope.dsc[i], EUrecScope)
				END
			ELSE
				prevname := name; ReadString8(r, name);
				IF level >= EUobjScope THEN
					tmpErr := FALSE;
					IF level = EUobjScope THEN r.RawNum(link) END;
					i := 0;  WHILE (i < scope.exports) & (scope.dsc[i].fp # fp) DO INC(i) END;
					IF i >= scope.exports THEN
						Err;  tmpErr := TRUE;  Modules.Append("/", msg);
						IF name = "@" THEN Modules.Append("@/",msg); Modules.Append(prevname, msg)
						ELSE Modules.Append(name, msg)
						END;
						DEC(i)
					ELSIF (level = EUobjScope) & (link # 0) THEN
						IF ~(EUProcFlagBit IN SYSTEM.VAL(SET, link)) THEN
							FixupVar(ADDRESSOF(m.code[0]), link, mod.sb + scope.dsc[i].adr)
						ELSE
							FixupCall(ADDRESSOF(m.code[0]), SYSTEM.VAL(SIZE, SYSTEM.VAL(SET, link) - {EUProcFlagBit}),
								scope.dsc[i].adr + ADDRESSOF(mod.code[0]))
						END
					END
				END
			END;
			r.RawNum(fp)
		END
	END CheckScope;

BEGIN
	r.Char(tag);
	IF tag = 8AX THEN	(* use tag *)
		i := 0;
		ReadString8(r, name);
		WHILE (name # "") & (res = Ok) DO
			mod := Modules.ThisModule(name, res, msg);
			IF res = Ok THEN
				CheckScope(mod.export, EUobjScope)
			END;
			ReadString8(r, name)
		END
	ELSE
		res := FileCorrupt
	END;
	RETURN res = Ok
END ReadUseBlock;

(* ReadTypeBlock - Read the type block. *)

PROCEDURE ReadTypeBlock(r: Streams.Reader;  m: Modules.Module;  VAR type: ARRAY OF TypeRec): BOOLEAN;
VAR
	tag: CHAR;  i, j, newMethods, pointers, method, entry, num: LONGINT;
	tdSize: LONGINT; (* ug *)
	recSize, ofs, totTdSize (* ug *): SIZE; base: ADDRESS;
	name: Modules.Name;  flags: SET;
	startAddr, tdAdr: ADDRESS;
	staticTypeBlock {UNTRACED}: Heaps.StaticTypeBlock;
BEGIN
	r.Char(tag);
	IF tag = 8BX THEN	(* type tag *)
		totTdSize := 0;
		IF LEN(m.staticTypeDescs) > 0 THEN
			startAddr := ADDRESSOF(m.staticTypeDescs[0]);
		END;
		FOR i := 0 TO LEN(type)-1 DO
			type[i].init := FALSE;
			r.RawNum(num); recSize := num;
			r.RawNum(num); type[i].entry := num;
			r.RawNum(num); type[i].baseMod := num;
			r.RawNum(num); type[i].baseEntry := num;
			r.RawNum(num); type[i].methods := ABS (num);
			IF num >= 0 THEN flags := {}	(* unprotected type *)
			ELSE flags := {Heaps.ProtTypeBit}	(* protected type *)
			END;
			r.RawNum(num); type[i].inhMethods := num;
			r.RawNum(newMethods);
			r.RawLInt(pointers);   (* fixed size *)
			r.RawString(name);
			r.RawLInt(tdSize);	(* ug *)
			NEW(m.typeInfo[i]);
			Heaps.FillStaticType(tdAdr, startAddr, SYSTEM.VAL(ADDRESS, m.typeInfo[i]), tdSize, recSize, pointers,
								Modules.MaxTags + type[i].methods);
			m.typeInfo[i].tag := tdAdr;
			m.typeInfo[i].flags := flags;
			m.typeInfo[i].mod := m;
			m.typeInfo[i].name := name;
			base := m.typeInfo[i].tag + Modules.Mth0Ofs;
			FOR j := 0 TO newMethods - 1 DO
				r.RawNum(method);
				r.RawNum(entry);
				SYSTEM.PUT(base - AddressSize*method, m.entry[entry]);
			END;
			(* other methods are left NIL *)
			staticTypeBlock := SYSTEM.VAL(Heaps.StaticTypeBlock, tdAdr);
			ASSERT(LEN(staticTypeBlock.pointerOffsets) = pointers);
			FOR j := 0 TO pointers - 1 DO
				r.RawNum(num); ofs := num;
				ASSERT(ofs MOD AddressSize  =  0);	(* no deep copy flag *)
				staticTypeBlock.pointerOffsets[j] := ofs;
				ASSERT(ADDRESSOF(staticTypeBlock.pointerOffsets[j]) < startAddr + tdSize)
			END;

			ASSERT(m.typeInfo[i].tag # 0);
			ASSERT( (ADDRESSOF(m.data[0]) <=  m.sb + type[i].entry) ,1001);
			ASSERT( (m.sb + type[i].entry+4  <= ADDRESSOF(m.data[LEN(m.data)-1])+1) ,1002 );

			SYSTEM.PUT(m.sb + type[i].entry, m.typeInfo[i].tag); (* patch in constant area *)

			startAddr := startAddr + tdSize;
			totTdSize := totTdSize + tdSize;
		END;
		ASSERT(totTdSize  = LEN(m.staticTypeDescs));;
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReadTypeBlock;

(* ReadRefBlock - Read the reference block. *)

PROCEDURE ReadRefBlock(r: Streams.Reader;  m: Modules.Module): BOOLEAN;
VAR tag: CHAR; ignore: LONGINT;
BEGIN
	r.Char(tag);
	IF tag = 8CX THEN	(* ref tag *)
		r.Bytes(m.refs^, 0, LEN(m.refs), ignore);
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReadRefBlock;

(* FixupGlobals - Fix up references to global variables. *)

PROCEDURE FixupGlobals(m: Modules.Module;  VAR dataLink: ARRAY OF DataLinkRec);
VAR i: LONGINT; t: SIZE; adr: ADDRESS;
BEGIN
	IF dataLink[0].mod = 0 THEN	(* local module has globals *)
		FOR i := 0 TO dataLink[0].fixups-1 DO
			adr := ADDRESSOF(m.code[0]) + dataLink[0].ofs[i];
			SYSTEM.GET(adr, t);  SYSTEM.PUT(adr, t + m.sb)
		END
	END
END FixupGlobals;

(* FixupLinks - Fix up other references. *)

PROCEDURE FixupLinks(m: Modules.Module;  VAR link: ARRAY OF LinkRec; VAR fixupCounts: ARRAY OF LONGINT; caseTableSize: LONGINT; VAR res: LONGINT);
VAR i: LONGINT;

	PROCEDURE FixRelative(ofs: SIZE; val: ADDRESS);
	VAR t: SIZE; adr: ADDRESS;
	BEGIN
		ASSERT(val # 0);
		WHILE ofs # Sentinel DO
			adr := ADDRESSOF(m.code[0])+ofs;
			SYSTEM.GET(adr, t);
			SYSTEM.PUT(adr, val - (adr+4));	(* fixup for relative CALL instruction => no relocation required *)
			ofs := t
		END
	END FixRelative;

	PROCEDURE FixEntry(ofs: SIZE; VAR fixupCounts: ARRAY OF LONGINT);
	VAR t: SIZE; adr: ADDRESS; i: LONGINT;
	BEGIN
		i := 0;
		WHILE ofs # Sentinel DO
			adr := ADDRESSOF(m.code[0])+ofs;
			SYSTEM.GET(adr, t);
			WHILE fixupCounts[i] = 0 DO INC(i) END;
			SYSTEM.PUT(adr, m.entry[i]);
			DEC(fixupCounts[i]);
			ofs := t
		END
	END FixEntry;

	PROCEDURE FixCase(ofs: SIZE; caseTableSize: LONGINT);
	VAR i: LONGINT; t: SIZE; adr: ADDRESS;
	BEGIN
		i := caseTableSize;
		WHILE i > 0 DO
			adr := m.sb+ofs;
			SYSTEM.GET(adr, t);
			SYSTEM.PUT(adr, ADDRESSOF(m.code[0]) + t);
			DEC(i); INC (ofs, AddressSize);
		END
	END FixCase;

BEGIN
	FOR i := 0 TO LEN(link)-1 DO
		ASSERT(link[i].mod = 0);	(* only fix local things *)
		CASE link[i].entry OF
			243..253: HALT(100); (* not supported any more, replaced by direct call *)
			|254: FixEntry(link[i].link, fixupCounts)	(* local procedure address *)
			|255: FixCase(link[i].link, caseTableSize)	(* case table *)
			ELSE res := 3406; RETURN				(* unknown fixup type *)
		END
	END
END FixupLinks;

(* When loader parsed the command block, the type descriptors have not yet been allocated so we could not fixup
the addresses -> do it now. *)
PROCEDURE FixupCommands(m : Modules.Module);
VAR i : LONGINT;
BEGIN
	FOR i := 0 TO LEN(m.command)-1 DO
		m.command[i].entryAdr := m.command[i].entryAdr + ADDRESSOF(m.code[0]);
		IF (m.command[i].argTdAdr > 1) THEN
			SYSTEM.GET(m.sb + m.command[i].argTdAdr, m.command[i].argTdAdr);
		END;
		IF (m.command[i].retTdAdr > 1)  THEN
			SYSTEM.GET(m.sb + m.command[i].retTdAdr, m.command[i].retTdAdr);
		END;
	END;
END FixupCommands;

(* InitType - Initialize a dynamic  type. *)

PROCEDURE InitType(m: Modules.Module;  VAR type: ARRAY OF TypeRec;  i: LONGINT);
VAR j, baseMod, extLevel: LONGINT; t: ADDRESS; root, baseTag, baseMth, baseRoot: ADDRESS; baseM: Modules.Module;
BEGIN
	IF ~type[i].init THEN
		(* init type for dynamic type descriptors *)
		root := m.typeInfo[i].tag;
		baseTag := root + Modules.Tag0Ofs;
		baseMth := root + Modules.Mth0Ofs;
		baseMod := type[i].baseMod; extLevel := 0;
		ASSERT(baseMod >= -1);
		IF baseMod # -1 THEN	(* extended type *)
			IF baseMod = 0 THEN	(* base type local *)
				j := 0;  WHILE type[j].entry # type[i].baseEntry DO INC(j) END;	(* find base type *)
				InitType(m, type, j);	(* and initialize it first *)
				baseM := m
			ELSE	(* base type imported *)
				baseM := m.module[baseMod-1];
				t := type[i].baseEntry;	(* fingerprint *)
				j := 0;  WHILE baseM.export.dsc[j].fp # t DO INC(j) END;	(* find base type *)
				type[i].baseEntry := baseM.export.dsc[j].dsc[0].adr
			END;
				(* copy base tags *)
			SYSTEM.GET(baseM.sb + type[i].baseEntry, baseRoot);
			SYSTEM.GET(baseRoot + Modules.Tag0Ofs, t);
			WHILE t # 0 DO
				SYSTEM.PUT(baseTag - AddressSize * extLevel, t);
				INC(extLevel);
				SYSTEM.GET(baseRoot + Modules.Tag0Ofs - AddressSize * extLevel, t)
			END;
				(* copy non-overwritten base methods *)
			FOR j := 0 TO type[i].inhMethods-1 DO
				SYSTEM.GET(baseMth - AddressSize * j, t);	(* existing method *)
				IF t = 0 THEN
					SYSTEM.GET(baseRoot + Modules.Mth0Ofs - AddressSize*j, t);	(* base method *)
					SYSTEM.PUT(baseMth - AddressSize * j, t)
				END;
			END
		END;
		m.typeInfo[i].flags := m.typeInfo[i].flags + SYSTEM.VAL(SET, extLevel);
		ASSERT(extLevel < Modules.MaxTags);

		SYSTEM.PUT(baseTag - AddressSize * extLevel, m.typeInfo[i].tag);		(* self *)

		(* init type for static type descriptors *)
		type[i].init := TRUE
	END
END InitType;

PROCEDURE ReadExTableBlock(r: Streams.Reader;  m: Modules.Module): BOOLEAN;
VAR
	tag: CHAR;
	pcFrom, pcTo, pcHandler, i: LONGINT;

	PROCEDURE SelectionSort(exTable: Modules.ExceptionTable);
	VAR
		p, q, min: LONGINT;
		entry: Modules.ExceptionTableEntry;
	BEGIN
		FOR p := 0 TO LEN(exTable) - 2 DO
			min := p;
			FOR q := p + 1 TO LEN(exTable) - 1 DO
				IF exTable[min].pcFrom > exTable[q].pcFrom THEN min := q END;
				entry := exTable[min]; exTable[min] := exTable[p]; exTable[p] := entry;
			END
		END
	END SelectionSort;

BEGIN
	r.Char(tag);
	IF tag = 8EX THEN
		FOR i := 0 TO LEN(m.exTable) -1 DO
			r.Char(tag);
			IF tag = 0FEX THEN
				r.RawNum(pcFrom);
				r.RawNum(pcTo);
				r.RawNum(pcHandler);
				m.exTable[i].pcFrom := pcFrom + ADDRESSOF(m.code[0]);
				m.exTable[i].pcTo := pcTo + ADDRESSOF(m.code[0]);
				m.exTable[i].pcHandler := pcHandler + ADDRESSOF(m.code[0]);
			ELSE
				RETURN FALSE;
			END;
		END;

		SelectionSort(m.exTable);
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END;

END ReadExTableBlock;

PROCEDURE ReadPtrsInProcBlock(r: Streams.Reader;  m: Modules.Module): BOOLEAN;
VAR tag: CHAR; i, j, codeoffset, beginOffset, endOffset, nofptrs, p : LONGINT;
	procTable: Modules.ProcTable; ptrTable: Modules.PtrTable;

	PROCEDURE Max(i, j : LONGINT) : LONGINT;
	BEGIN
		IF i > j THEN
			RETURN i
		ELSE
			RETURN j
		END
	END Max;

	PROCEDURE SwapProcTableEntries(p, q : LONGINT);
	VAR procentry : Modules.ProcTableEntry;
		k, i, basep, baseq: LONGINT; ptr: SIZE;
	BEGIN
		k := Max(procTable[p].noPtr, procTable[q].noPtr);
		IF k > 0 THEN (* swap entries in ptrTable first *)
			basep := p * m.maxPtrs; baseq := q * m.maxPtrs;
			FOR i := 0 TO k - 1 DO
				ptr := ptrTable[basep + i];
				ptrTable[basep + i] := ptrTable[baseq + i];
				ptrTable[baseq + i] := ptr
			END
		END;
		procentry := procTable[p];
		procTable[p] := procTable[q];
		procTable[q] := procentry
	END SwapProcTableEntries;

	PROCEDURE SortProcTable;
	VAR i, j, min : LONGINT;
	BEGIN
		FOR i := 0 TO m.noProcs - 2 DO
			min := i;
			FOR j := i + 1 TO m.noProcs - 1 DO
				IF procTable[j].pcFrom < procTable[min].pcFrom THEN min:= j END
			END;
			IF min # i THEN SwapProcTableEntries(i, min) END
		END
	END SortProcTable;

BEGIN
	r.Char(tag);
	IF tag = 8FX THEN
		NEW(procTable, m.noProcs); NEW(ptrTable, m.noProcs * m.maxPtrs); (* m.noProcs > 0 since the empty module contains the module body procedure *)
		m.procTable := procTable; m.ptrTable := ptrTable;
		FOR i := 0 TO m.noProcs - 1 DO
			r.RawNum(codeoffset);
			r.RawNum(beginOffset);
			r.RawNum(endOffset);
			r.RawLInt(nofptrs);	(* fixed size *)
			procTable[i].pcFrom := codeoffset + ADDRESSOF(m.code[0]);
			procTable[i].pcStatementBegin := beginOffset + ADDRESSOF(m.code[0]);
			procTable[i].pcStatementEnd := endOffset + ADDRESSOF(m.code[0]);
			procTable[i].noPtr := nofptrs;
			FOR j := 0 TO nofptrs - 1 DO
				r.RawNum(p);
				ptrTable[i * m.maxPtrs + j] := p
			END
		END;
		SortProcTable();
		m.firstProc := procTable[0].pcFrom;
		FOR i := 0 TO m.noProcs - 2 DO
			procTable[i].pcLimit := procTable[i + 1].pcFrom
		END;
		procTable[m.noProcs - 1].pcLimit := ADDRESSOF(m.code[0]) + LEN(m.code) + 1;   (* last element reserved for end of code segment,
																						    allow 1 byte extra, cf. Modules.ThisModuleByAdr *)
		procTable := NIL; ptrTable := NIL;
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END ReadPtrsInProcBlock;

(** LoadObj - Load an Active Oberon object file. *)

PROCEDURE LoadObj*(CONST name, fileName: ARRAY OF CHAR;  VAR res: LONGINT;  VAR msg: ARRAY OF CHAR): Modules.Module;
VAR
	f: Files.File; r: Files.Reader; h: ObjHeader; m: Modules.Module; i, caseTableSize: LONGINT;
	dataLink: POINTER TO ARRAY OF DataLinkRec;
	link: POINTER TO ARRAY OF LinkRec;
	fixupCounts : POINTER TO ARRAY OF LONGINT;
	type: POINTER TO ARRAY OF TypeRec;
BEGIN
	f := Files.Old(fileName);
	IF f # NIL THEN
		IF trace THEN KernelLog.String("Loading ");  KernelLog.String(fileName);  KernelLog.Ln END;
		res := Ok; msg[0] := 0X;
		Files.OpenReader(r, f, 0);
		ReadHeader(r, h, res, msg);
		IF res = Ok THEN
			IF h.name = name THEN
				NEW(m);
				i := 0;  WHILE h.name[i] # 0X DO m.name[i] := h.name[i];  INC(i) END;
				m.name[i] := 0X;
				m.noProcs := h.procs;
				m.maxPtrs := h.maxPtrs;
				m.crc := h.crc;
				AllocateModule(m,h);
				IF trace THEN
					KernelLog.Hex(ADDRESSOF(m.code[0]), 8);  KernelLog.Char(" ");
					KernelLog.String(m.name);  KernelLog.Hex(m.sb, 9);  KernelLog.Ln
				END;
				NEW(dataLink, h.dataLinks);  NEW(link, h.links);  NEW(fixupCounts, h.entries);
				NEW(type, h.types);
				IF ReadEntryBlock(r, m) & ReadCommandBlock(r, m) & ReadPointerBlock(r, m) &
						ReadImportBlock(r, m, res, msg) & ReadDataLinkBlock(r, h.dataLinks, dataLink^) &
						ReadLinkBlock(r, h.links, h.entries, link^, fixupCounts^, caseTableSize) & ReadConstBlock(r, m,h) & ReadExportBlock(r, m) &
						ReadCodeBlock(r, m) & ReadUseBlock(r, m, dataLink^, res, msg) &
						ReadTypeBlock(r, m, type^) & ReadExTableBlock(r, m)  & ReadPtrsInProcBlock(r, m)  &
						ReadRefBlock(r, m) THEN
					IF h.dataLinks # 0 THEN FixupGlobals(m, dataLink^) END;
					IF h.links # 0 THEN FixupLinks(m, link^, fixupCounts^, caseTableSize, res) END;
					IF h.commands # 0 THEN FixupCommands(m); END;
					IF res = Ok THEN
						FOR i := 0 TO LEN(type^)-1 DO InitType(m, type^, i) END
					END
				ELSE
					IF res = Ok THEN res := FileCorrupt END	(* do not overwrite lower-level error code *)
				END;
				dataLink := NIL;  link := NIL;  type := NIL
			ELSE
				res := IncompatibleModuleName;  COPY(fileName, msg);  Modules.Append(" incompatible module name", msg)
			END;
		END;
		IF (res # Ok) & (msg[0] = 0X) THEN COPY(fileName, msg);  Modules.Append(" corrupt", msg) END
	ELSE
		res := FileNotFound;  COPY(fileName, msg);  Modules.Append(" not found", msg)
	END;
	IF res # Ok THEN m := NIL END;
	RETURN m
END LoadObj;

PROCEDURE Trace*(context : Commands.Context);
BEGIN
	trace := ~trace;
	context.out.String("Loader: trace ");
	IF trace THEN context.out.String("on") ELSE context.out.String("off") END;
	context.out.Ln;
END Trace;

PROCEDURE Init;
VAR extension: ARRAY 32 OF CHAR;
BEGIN
	trace := FALSE;
	Machine.GetConfig("ObjectFileExtension", extension);
	IF extension = "" THEN
		COPY(Machine.DefaultObjectFileExtension, extension)
	END;
	Modules.AddLoader(extension, LoadObj); 
END Init;


BEGIN
	Init();
END Loader.

(*
11.05.98	pjm	Started
*)

SystemTools.Free Loader ~
