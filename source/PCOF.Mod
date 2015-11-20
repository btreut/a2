(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCOF; (** AUTHOR "prk / be"; PURPOSE "Parallel Compiler: object file plug-in"; *)

IMPORT
	SYSTEM, KernelLog,
	StringPool, PCDebug, PCBT, PCLIR, PCM, PCT, PCOM, Diagnostics;

CONST
	AddressSize = SIZEOF(ADDRESS);

	TraceUse = FALSE;
	Optimize = FALSE;

	NewRefSection = TRUE;

	Sentinel = LONGINT(0FFFFFFFFH);

	EUEnd = 0X; EURecord = 1X; EUProcFlag = LONGINT(080000000H);


TYPE
	StringBuf = ARRAY 256 OF CHAR;

	OffsetList = POINTER TO RECORD
		offset : LONGINT;
		nextOffset : OffsetList
	END;

	ExTableEntry = POINTER TO RECORD
		pcFrom, pcTo, pcHandler: LONGINT;
		next: ExTableEntry;
	END;


VAR
	refSize: LONGINT;
	nofCmds, nofImp, nofVarCons, nofLinks: INTEGER;
	dsize: LONGINT;

	globR: PCM.Rider;	(* used for OutReference *)

		(* stat counters *)
	Nreschedule0, Nreschedule1, Nreschedule2: LONGINT;

	exTable: ExTableEntry;
	exTableLen: LONGINT;

(* ---------- Helper Procedures -------------- *)

PROCEDURE OutRefType(t: PCT.Struct; procHeader: BOOLEAN);
VAR val, off, dim, td: LONGINT; u: PCT.Struct; tdptr: PCBT.GlobalVariable;
BEGIN
	td := 0; off := 0; dim := 0;
	IF ~procHeader (*& (t IS PCT.Array) *) THEN
		IF (t IS PCT.Array) THEN  (** fof  *)
		WITH t: PCT.Array DO
			off := 80H;
			u := t.base;
			IF ~(u IS PCT.Basic) THEN u := PCT.Ptr END;
			IF t.mode = PCT.static THEN  dim := t.len  END
		END;
		t := u
(** fof >> *)
		ELSIF (t IS PCT.EnhArray) THEN
			WITH t: PCT.EnhArray DO
				off := 80H;  u := t.base;
				IF ~(u IS PCT.Basic) THEN u := PCT.Ptr END;
				IF (t.mode = PCT.static) THEN dim := t.len END
			END;
			t := u
		ELSIF (t IS PCT.Tensor) THEN
			WITH t: PCT.Tensor DO
				off := 80H;  u := t.base;
				 u := PCT.Ptr ;
			END;
			t := u
		END;
(** << fof  *)
	END;
	IF t = PCT.Int64 THEN
		val := 10H
	ELSIF t = PCT.Char16 THEN
		val := PCT.Int16.sym(PCOM.Struct).fp
	ELSIF t = PCT.Char32 THEN
		val := PCT.Int32.sym(PCOM.Struct).fp
	ELSIF t IS PCT.Basic THEN
		val := t.sym(PCOM.Struct).fp
	ELSIF t = PCT.NoType THEN
		val := 0
	ELSIF t IS PCT.Record THEN
		val := 16H;
		tdptr := t.size(PCBT.RecSize).td;
		IF tdptr # NIL THEN  td := tdptr.offset  ELSE  val := 6  END
	ELSIF procHeader & PCT.IsPointer(t) THEN
		val := 0DH
	ELSIF t IS PCT.Pointer THEN
		WITH t: PCT.Pointer DO
			IF t.baseR # NIL  (* IS PCT.Record *) THEN
				val := 1DH;
				tdptr := t.base.size(PCBT.RecSize).td;
				IF tdptr # NIL THEN  td := tdptr.offset  ELSE  val := 0DH  END
			ELSE
				val := 0DH
			END
		END;
	ELSIF t = PCT.Ptr THEN
		val := 0DH;
	ELSIF t IS PCT.Delegate THEN
		val := 0EH
	ELSIF procHeader & (t IS PCT.Array) THEN
		WITH t: PCT.Array DO
			IF t.mode = PCT.static THEN val := 12H
			ELSIF t.mode = PCT.open THEN val := 15H
			ELSE HALT(98)
			END
		END
(** fof >> *)
	ELSIF procHeader & (t IS PCT.EnhArray) THEN
		WITH t: PCT.EnhArray DO
			IF t.mode = PCT.static THEN val := 12H
			ELSIF t.mode = PCT.open THEN val := 15H
			ELSE HALT( 98 )
			END
		END
	ELSIF procHeader & (t IS PCT.Tensor) THEN
		val := 15H; (* ???? *)
(** << fof  *)
	ELSE
		HALT(99)
	END;
	IF procHeader THEN
		PCM.RefW(globR, CHR(val))
	ELSE
		PCM.RefW(globR, CHR(off+val));
		IF off = 80H THEN  PCM.RefWNum(globR, dim)
		ELSIF td # 0 THEN  PCM.RefWNum(globR, td)
		END
	END
END OutRefType;

PROCEDURE OutRefVar(p: PCT.Variable; isRef: BOOLEAN);
VAR arr: PCT.Array; dim, off: LONGINT; type: PCT.Struct; name: StringBuf;earr: PCT.EnhArray;   (*fof*)
BEGIN
	StringPool.GetString(p.name, name);
	IF NewRefSection THEN
		IF isRef THEN PCM.RefW(globR, 3X) ELSE PCM.RefW(globR, 1X) END;
		OutRefType(p.type, FALSE);
		PCM.RefWNum(globR, p.adr(PCBT.Variable).offset);
		PCM.RefWString(globR, name)
	ELSE
		type := p.type;
		IF (type IS PCT.Record) THEN
			(*skip*)
		ELSIF (type IS PCT.Array) & ~(type(PCT.Array).base IS PCT.Basic) THEN
			(*skip*)
(** fof >> *)
		ELSIF (type IS PCT.EnhArray) & (type( PCT.EnhArray ).base IS PCT.Basic) THEN
		(* skip *)
(** << fof  *)
		ELSIF (type = PCT.Int64) THEN
			(*skip*)
		ELSE
			IF isRef THEN PCM.RefW(globR, 3X) ELSE PCM.RefW(globR, 1X) END;
			off := 0; dim := 0;
			IF type IS PCT.Array THEN
				off := 80H; dim := 1;
				REPEAT
					arr := type(PCT.Array);
					dim := dim * arr.len;
					type := arr.base
				UNTIL ~(type IS PCT.Array)
			END;
(** fof >> *)
			IF type IS PCT.EnhArray THEN
				off := 80H;  dim := 1;
				REPEAT earr := type( PCT.EnhArray );  dim := dim * earr.len;  type := earr.base UNTIL ~(type IS PCT.EnhArray)
			END;
(** << fof  *)
			IF type = PCT.Byte THEN PCM.RefW(globR, CHR(off+1))
			ELSIF type = PCT.Bool THEN PCM.RefW(globR, CHR(off+2))
			ELSIF type = PCT.Char8 THEN PCM.RefW(globR, CHR(off+3))
			ELSIF type = PCT.Char16 THEN PCM.RefW(globR, CHR(off+5))
			ELSIF type = PCT.Char32 THEN PCM.RefW(globR, CHR(off+6))
			ELSIF type = PCT.Int8 THEN PCM.RefW(globR, CHR(off+4))
			ELSIF type = PCT.Int16 THEN PCM.RefW(globR, CHR(off+5))
			ELSIF type = PCT.Int32 THEN PCM.RefW(globR, CHR(off+6))
			ELSIF type = PCT.Float32 THEN PCM.RefW(globR, CHR(off+7))
			ELSIF type = PCT.Float64 THEN PCM.RefW(globR, CHR(off+8))
			ELSIF type = PCT.Set THEN PCM.RefW(globR, CHR(off+9))
			ELSIF PCT.IsPointer(type) THEN PCM.RefW(globR, CHR(off+0DH))
			ELSIF type IS PCT.Delegate THEN PCM.RefW(globR, CHR(off+0EH))
			END;
			IF off = 80H THEN PCM.RefW(globR, CHR(dim)) END;
			PCM.RefWNum(globR, p.adr(PCBT.Variable).offset);
			PCM.RefWString(globR, name);
		END
	END;
END OutRefVar;

(* fof 070731 moved warnings to PCP : removed CheckAll, CheckModules here *)
PROCEDURE OutReference(scope: PCT.Scope);
VAR  owner: PCT.Proc; i: LONGINT; var: PCT.Variable; par: PCT.Parameter; name: StringBuf; entry: ExTableEntry; mod: PCT.Module;
BEGIN
(*
	IF (scope.code = NIL) THEN RETURN  END;
*)

	IF scope IS PCT.ModScope THEN
		PCM.RefW(globR, 0F8X);
		COPY("$$", name);
		PCM.RefWNum(globR, 0); (* offset *)
		PCM.RefWString(globR, "$$"); (* name *)
		var := scope.firstVar;
		WHILE var # NIL DO OutRefVar(var, FALSE); var := var.nextVar END;

		mod := scope(PCT.ModScope).owner;

		IF mod.adr(PCBT.Module).finallyOff > -1 THEN

			NEW(entry);
			entry.pcFrom := 0;
			entry.pcTo := mod.adr(PCBT.Module).finallyOff;
			entry.pcHandler := mod.adr(PCBT.Module).finallyOff;
			entry.next := NIL;

			IF exTable # NIL THEN
				entry.next := exTable;
			END;

			exTable := entry;

			INC(exTableLen);
		END;

	ELSIF scope IS PCT.ProcScope THEN
		WITH scope: PCT.ProcScope DO
			owner := scope.ownerO;
			IF ~(PCT.Inline IN owner.flags) THEN
				IF NewRefSection THEN
					PCM.RefW(globR, 0F9X);
					PCM.RefWNum(globR, owner.adr(PCBT.Procedure).codeoffset);
					PCM.RefWNum(globR, scope.parCount);
					OutRefType(owner.type, TRUE);
					PCM.RefWNum(globR, owner.level);
					PCM.RefWNum(globR, 0)
				ELSE
					PCM.RefW(globR, 0F8X);
					PCM.RefWNum(globR, owner.adr(PCBT.Procedure).codeoffset);
				END;
				IF owner IS PCT.Method THEN
					WITH owner: PCT.Method DO
						PCT.GetTypeName(owner.boundTo, name);
						i := 0;
						WHILE name[i] # 0X DO PCM.RefW(globR, name[i]); INC(i) END;
						PCM.RefW(globR, ".")
					END
				END;
				StringPool.GetString(owner.name, name);
				PCM.RefWString(globR, name);
				par := scope.firstPar;
				WHILE par # NIL DO OutRefVar(par, par.ref); par := par.nextPar END;
				var := scope.firstVar;
				WHILE var # NIL DO OutRefVar(var, FALSE); var := var.nextVar END
			END;

			IF owner.adr(PCBT.Procedure). finallyOff > -1 THEN

				NEW(entry);
				entry.pcFrom := owner.adr(PCBT.Procedure).codeoffset;
				entry.pcTo := owner.adr(PCBT.Procedure).finallyOff;
				entry.pcHandler := owner.adr(PCBT.Procedure).finallyOff;
				entry.next := NIL;

				IF exTable # NIL THEN
					entry.next := exTable;
				END;

				exTable := entry;
				INC(exTableLen);
			END;
		END;
	END
END OutReference;

PROCEDURE Generate*(VAR R: PCM.Rider; scope: PCT.ModScope;  VAR codeSize: LONGINT);
VAR commands: ARRAY 128 OF PCT.Proc;
	i, nofptrs, nofProcs, maxPtrs, EntriesPos, PtrPos, nofProcsPos, maxPtrsPos, LinksPos, VarConsPos: LONGINT;
	typeDescsSize, typeDescsSizePos: LONGINT; (* ug: temporary *)
	adr: PCBT.Module; mod: PCT.Module;  sym: PCOM.Module; emptyR: PCM.Rider;
	code: PCLIR.CodeArray; str: StringBuf; hdrCodeSize, addressFactor: LONGINT;

	PROCEDURE UseModule(m: PCBT.Module);
	BEGIN
		IF m.nr = 0 THEN
			INC(nofImp);
			m.nr := -1	(*mark*)
		END
	END UseModule;

	PROCEDURE FindCommands;
	VAR proc : PCT.Proc;
	BEGIN
		nofCmds := 0;
		proc := scope.firstProc;
		WHILE (proc # NIL) DO
			IF (proc.vis = PCT.Public) & (~(PCT.Inline IN proc.flags) OR (PCT.Indexer IN proc.flags)) THEN
				IF PCT.GetProcedureAllowed(proc.scope, proc.type) THEN
					commands[nofCmds] := proc; INC(nofCmds);
				END;
			END;
			proc := proc.nextProc
		END;
	END FindCommands;

	PROCEDURE CollectInfo;
	VAR proc: PCT.Proc; o: PCT.Symbol; p: PCBT.GlobalVariable; rec: PCT.Record; bsym: PCOM.Struct;
	BEGIN
		globR := R;  PCT.TraverseScopes(scope, OutReference);  R := globR; globR := emptyR;
		FindCommands;

		(* detect imported modules *)
		IF mod.imports # NIL THEN
			i := 0;
			WHILE (i < LEN(mod.imports)) & (mod.imports[i] # NIL) DO
				mod.imports[i].adr(PCBT.Module).nr := 0;
				INC(i)
			END;
			nofImp := 0;
			o := scope.sorted;
			WHILE o # NIL DO
				IF (o IS PCT.Module) & (o.adr # PCT.System.adr) THEN  UseModule(o.adr(PCBT.Module)) END;
				o := o.sorted;
			END;
			p := adr.ExtVars;
			WHILE p # PCBT.sentinel DO
				IF p.link # NIL THEN UseModule(p.owner) END;
				p := p.next
			END;
			rec := scope.records;
			WHILE rec # NIL DO
				IF (rec.brec # NIL) & (rec.brec.sym # NIL) THEN
					bsym := rec.brec.sym(PCOM.Struct);
					IF bsym.mod # scope.owner THEN UseModule(bsym.mod.adr(PCBT.Module)) END
				END;
				rec := rec.link;
 				ASSERT(rec # scope.records, MAX(INTEGER));
 					(* Fix bug, sometimes this assertion fails. *)
 					(* fof 070920: done, cf. PCC.MakeTD *)
			END
		END;
(*
		IF mod.imports # NIL THEN
			nofImp := SHORT(LEN(mod.imports));
			WHILE (mod.imports[nofImp-1] = NIL) DO DEC(nofImp) END
		END
*)
	END CollectInfo;

	PROCEDURE OutPtrs(offset: LONGINT;  type: PCT.Struct; debug : BOOLEAN);
	VAR  i, n, off: LONGINT;  f: PCT.Variable; scope: PCT.Scope;  base: PCT.Struct; size: PCBT.Size;
		name: StringBuf; state: LONGINT;
	BEGIN
		IF type.size(PCBT.Size).containPtrs THEN
			IF PCT.IsPointer(type) THEN
				PCM.ObjWNum(R, offset); INC(nofptrs);
				IF debug THEN
					KernelLog.Int(offset, 0); KernelLog.String(" "); (* KernelLog.Ln; *)
				END
			ELSIF PCT.IsDynamicDelegate(type) THEN
				PCM.ObjWNum(R, offset+4); INC(nofptrs);
				IF debug THEN
					KernelLog.Int(offset+4, 0); KernelLog.String(" "); (* KernelLog.Ln; *)
				END
			ELSIF type IS PCT.Record THEN
				WITH type: PCT.Record DO
					IF type.brec # NIL THEN OutPtrs(offset, type.brec, debug)  END;
					scope := type.scope;
				END;
				f := scope.firstVar;
				WHILE  f # NIL  DO
					IF ~(PCM.Untraced IN f.flags) THEN
						StringPool.GetString(f.name, name); state := scope.state;
						ASSERT(state >= PCT.structallocated);
						type := f.type;  off := f.adr(PCBT.Variable).offset;
						OutPtrs(offset+off, type, debug)
					END;
					f := f.nextVar
				END;
			ELSIF type IS PCT.Array THEN
				WITH type: PCT.Array DO
					IF type.mode = PCT.static THEN
						n := type.len;
						base := type.base;
						WHILE (base IS PCT.Array) DO
							type := base(PCT.Array); base := type.base;
							ASSERT(type.mode = PCT.static);
							n := n * type.len
						END;
						size := base.size(PCBT.Size);
						IF size.containPtrs THEN
							FOR i := 0 TO n-1 DO OutPtrs(offset+i*size.size, base, debug)  END
						END
					ELSE
						PCDebug.ToDo(PCDebug.NotImplemented);	(*find pointers in the array, call NewPtr for each one*)
					END
				END
(** fof >> *)
				ELSIF type IS PCT.EnhArray THEN
					WITH type: PCT.EnhArray DO
						IF type.mode = PCT.static THEN
							n := type.len;  base := type.base;
							WHILE (base IS PCT.EnhArray) DO type := base( PCT.EnhArray );  base := type.base;
								ASSERT ( (type.mode = PCT.static) );
								n := n * type.len
							END;
							size := base.size( PCBT.Size );
							IF size.containPtrs THEN
								FOR i := 0 TO n - 1 DO OutPtrs( offset + i * size.size, base,FALSE ) END
							END
						ELSE
							PCM.ObjWNum( R, offset );  INC( nofptrs );
							(* pointer to array in heap is located at first position ! *)
							(*
							PCDebug.ToDo( PCDebug.NotImplemented );   (*find pointers in the array, call NewPtr for each one*)
							*)
						END
					END
				ELSIF type IS PCT.Tensor THEN
					WITH type: PCT.Tensor DO
						PCM.ObjWNum(R,offset); INC(nofptrs);
					END;
(** << fof  *)
			END
		END
	END OutPtrs;

	PROCEDURE FixupList(l: PCBT.Fixup;  addressFactor: LONGINT; base: ADDRESS; sentinel: LONGINT; prev: PCBT.Fixup; VAR tail: PCBT.Fixup);
	(* Insert fixup list into code *)
		VAR offset: LONGINT;
	BEGIN
		tail := NIL;
		IF l # NIL THEN
			IF prev # NIL THEN
				SYSTEM.PUT(base + prev.offset*addressFactor, l.offset);
			END;
			offset := l.offset;
			tail := l;
			l := l.next;
			WHILE l # NIL DO
				SYSTEM.PUT(base+offset*addressFactor, l.offset);
				offset := l.offset;
				tail := l;
				l := l.next;
			END;
			SYSTEM.PUT(base+offset*addressFactor, sentinel);
		END;
	END FixupList;

	PROCEDURE InsertFixupLists(addressFactor: LONGINT);
		VAR p: PCBT.Procedure; i: LONGINT; codebase: ADDRESS; dummy : PCBT.Fixup;
	BEGIN
		codebase := ADDRESSOF(code[0]);
		FOR i := 0 TO PCBT.NofSysCalls-1 DO
			IF i # PCBT.casetable THEN
				FixupList(adr.syscalls[i], addressFactor, codebase, Sentinel, NIL, dummy)
			END
		END;
		p := adr.ExtProcs;
		WHILE p # PCBT.psentinel DO
			ASSERT(p.owner # PCBT.context);
			FixupList(p.link, addressFactor, codebase, Sentinel, NIL, dummy);
			p := p.next
		END;
	END InsertFixupLists;

	PROCEDURE EntryBlock(addressFactor: LONGINT);
	VAR nofEntries, firstOffset: LONGINT; codebase: ADDRESS;

		PROCEDURE Traverse(p: PCBT.Procedure);
		VAR prev, tail : PCBT.Fixup;
		BEGIN
			prev := NIL;
			WHILE p # PCBT.psentinel DO
				IF (p.public) OR (p.link # NIL) OR (p IS PCBT.Method) THEN
					PCM.ObjWNum(R, p.codeoffset);
					p.entryNr := nofEntries;
					INC(nofEntries);
					FixupList(p.link, addressFactor, codebase, Sentinel, prev, tail);
					IF tail # NIL THEN
						prev := tail
					END;
					IF (p.link # NIL) & (firstOffset = -1) THEN
						firstOffset := p.link.offset
					END;
				END;
				p := p.next
			END
		END Traverse;

	BEGIN
		PCM.ObjW(R, 82X);
		nofEntries := 0;
		codebase := ADDRESSOF(code[0]);
		firstOffset := -1;
		Traverse(adr.OwnProcs);
(*
		Traverse(adr.ExtProcs);
*)
		IF firstOffset # -1 THEN adr.UseSyscall(PCBT.procaddr, firstOffset) END;
		IF nofEntries # 0 THEN PCM.ObjWLIntAt(R, EntriesPos, nofEntries) END
	END EntryBlock;

	PROCEDURE CommandBlock;
	VAR i: LONGINT; str: StringBuf;

		PROCEDURE WriteType(type : PCT.Struct);
		VAR size : PCBT.RecSize; num : LONGINT;
		BEGIN
			ASSERT((type # NIL) & ((type = PCT.NoType) OR (type IS PCT.Record) OR ((type IS PCT.Pointer) & (type(PCT.Pointer).baseR # NIL))));
			num := 0;
			IF (type = PCT.NoType) THEN
				(* num = 0 *)
			ELSIF (type IS PCT.Record) THEN
				size := type(PCT.Record).size(PCBT.RecSize);
			ELSE
				size := type(PCT.Pointer).baseR.size(PCBT.RecSize);
			END;
			IF (type # PCT.NoType) THEN
				IF (size.td # NIL) THEN
					num := size.td.offset;
				ELSE
					KernelLog.String("ERROR: size.td = NIL"); KernelLog.Ln; (* TODO: CHECK WHY THIS HAPPENS *)
				END;
			END;
			PCM.ObjWNum(R, num);
		END WriteType;

	BEGIN
		PCM.ObjW(R, 83X);
		i := 0;
		WHILE i < nofCmds DO

			IF (commands[i].scope.formalParCount = 0) THEN
				PCM.ObjWNum(R, 0);
			ELSIF (commands[i].scope.formalParCount = 1) & (commands[i].scope.firstPar.type = PCT.Ptr) THEN
				PCM.ObjWNum(R, 1); (* ANY , TO BE REMOVED *)
			ELSE
				WriteType(commands[i].scope.firstPar.type);
			END;

			IF (commands[i].type = PCT.Ptr) THEN
				PCM.ObjWNum(R, 1); (* ANY, TO BE REMOVED *)
			ELSE
				WriteType(commands[i].type);
			END;

			(* cmdName cmdOffset 4) *)
			StringPool.GetString(commands[i].name, str);
			PCM.ObjWName(R, str);
			PCM.ObjWNum(R, commands[i].adr(PCBT.Procedure).codeoffset);
			INC(i);
		END;
	END CommandBlock;

	PROCEDURE PointerBlock;
	VAR   p: PCT.Variable;
	BEGIN
		PCM.ObjW(R, 84X);
		nofptrs := 0;
		p := scope.firstVar;
		WHILE p # NIL DO
			IF ~(PCM.Untraced IN p.flags) & (p.adr # NIL) THEN
				OutPtrs(p.adr(PCBT.GlobalVariable).offset, p.type, FALSE)  (* debug = FALSE *)
			END;
			p := p.nextVar
		END;
		p := scope.firstHiddenVar;
		WHILE p # NIL DO
			IF p.adr # NIL THEN (* ug: checking for PCM.Untraced not necessary here, flags of hidden variables always {} *)
				OutPtrs(p.adr(PCBT.GlobalVariable).offset, p.type, FALSE)	(* debug = FALSE *)
			END;
			p := p.nextVar
		END;
		IF nofptrs > MAX(INTEGER) THEN PCM.Error(222, 0, "") END;
		IF nofptrs # 0 THEN PCM.ObjWLIntAt(R, PtrPos, nofptrs) END;
	END PointerBlock;

	PROCEDURE ImportBlock;
	VAR  i, j, k: LONGINT;  m: PCT.Module;  str: StringBuf; adr: PCBT.Module;
	BEGIN
		PCM.ObjW(R, 85X);
		IF mod.imports # NIL THEN
			i := 0; j := 0;
			k := LEN(mod.imports);
			WHILE (i < k) & (mod.imports[i] # NIL) DO
				m := mod.imports[i];
				adr := m.adr(PCBT.Module);
				IF adr.nr = -1 THEN
					INC(j); adr.nr := SHORT(j);
					StringPool.GetString(m.name, str); PCM.ObjWName(R, str);
				END;
				INC(i)
			END
		END;
		ASSERT(j = nofImp);
	END ImportBlock;
(*
	PROCEDURE ImportBlock;
	VAR  i, j, k, len: LONGINT;  m: PCT.Module;  str: StringBuf; adr: PCBT.Module;
	BEGIN
		PCM.ObjW(R, 85X);
		IF mod.imports # NIL THEN
			j := 0;
			k := LEN(mod.imports);
			REPEAT  DEC(k)  UNTIL (k < 0) OR (mod.imports[k] # NIL);
			i := 0;
			WHILE (i <= k) DO
				m := mod.imports[i];
				adr := m.adr(PCBT.Module);
				IF adr.nr = -1 THEN
					INC(j); adr.nr := SHORT(j);
					StringPool.GetString(m.name, str); PCM.ObjWName(R, str);
				END;
				INC(i)
			END
		END;
		ASSERT(j = nofImp);
	END ImportBlock;
*)
	PROCEDURE VarConsBlock;
	VAR p: PCBT.GlobalVariable;  pos, count: LONGINT;

		PROCEDURE FixList(p: PCBT.Fixup);
		BEGIN
			WHILE p # NIL DO
				PCM.ObjWNum(R, p.offset); p := p.next; INC(count)
			END
		END FixList;

	BEGIN
		PCM.ObjW(R, 8DX);
		(*first pass: local GVars*)
		nofVarCons := 0;
		PCM.ObjW(R, 0X);  PCM.ObjWNum(R, -1);  PCM.ObjWGetPos(R, pos);  PCM.ObjWLInt(R, -1);
		p := adr.OwnVars;  count := 0;
		WHILE p # PCBT.sentinel DO
			FixList(p.link);
			ASSERT(p.entryNo = PCBT.UndefEntryNo);
			p := p.next
		END;
		PCM.ObjWLIntAt(R, pos, count);
		INC(nofVarCons);

		(*second pass: imported GVars*)
		p := adr.ExtVars;
		WHILE p # PCBT.sentinel DO
			IF (p.link # NIL) THEN
				p.entryNo := nofVarCons;	(* remember the position for the UseSection *)
				count := 0;  INC(nofVarCons);
				PCM.ObjW(R, CHR(p.owner.nr));  PCM.ObjWNum(R, 0);  PCM.ObjWGetPos(R, pos);  PCM.ObjWLInt(R, -1);
				FixList(p.link);
				PCM.ObjWLIntAt(R, pos, count);
			END;
			p := p.next
		END;
	END VarConsBlock;

	PROCEDURE LinkBlock;
		VAR nofLinks: LONGINT; p: PCBT.Procedure; count : LONGINT;

		(* ug *)
		PROCEDURE CountFixups(p: PCBT.Procedure; VAR count: LONGINT);
		VAR f : PCBT.Fixup;
		BEGIN
			count := 0;
			f := p.link;
			WHILE f # NIL DO
				INC(count);
				f := f.next;
			END
		END CountFixups;

	BEGIN
		PCM.ObjW(R, 86X);
		FOR i := 0 TO PCBT.NofSysCalls-1 DO
			IF adr.syscalls[i] # NIL THEN
				PCM.ObjW(R, 0X);  PCM.ObjW(R, PCLIR.CG.SysCallMap[i]);  PCM.ObjWNum(R, adr.syscalls[i].offset);
				INC(nofLinks)
			END
		END;
		(* ug *)
		p := adr.OwnProcs;
		WHILE p # PCBT.psentinel DO
			IF (p.public) OR (p.link # NIL) OR (p IS PCBT.Method) THEN
				CountFixups(p, count);
				PCM.ObjWNum(R, count)
			END;
			p := p.next;
		END;
		PCM.ObjWNum(R, adr.casetablesize);
		IF nofLinks # 0 THEN PCM.ObjWLIntAt(R, LinksPos, nofLinks) END
	END LinkBlock;

	PROCEDURE UseBlock;
	VAR  m: PCT.Module;
		e, i: LONGINT; modname, name: StringBuf;
		v: PCT.Variable; p: PCT.Proc; t: PCT.Type; c: PCT.Value;

		PROCEDURE UseEntry(m: PCT.Module; p: PCT.Symbol; offset: LONGINT);
		BEGIN
			StringPool.GetString(p.name, name);
			PCOM.FPrintObj(p, m);
			PCM.ObjWNum(R, p.sym(PCOM.Symbol).fp);
			PCM.ObjWName(R, name);
			PCM.ObjWNum(R, offset);
		END UseEntry;

		PROCEDURE UseType(t: PCT.Struct);
			VAR size: PCBT.RecSize; sym: PCOM.Struct; j: LONGINT;
		BEGIN
			LOOP
				IF t IS PCT.Pointer THEN	t := t(PCT.Pointer).base
				ELSIF t IS PCT.Array THEN	t := t(PCT.Array).base
(** fof >> *)
				ELSIF t IS PCT.EnhArray THEN
					t := t( PCT.EnhArray ).base
				ELSIF t IS PCT.Tensor THEN
					t := t( PCT.Tensor).base
(** << fof  *)
				ELSE	EXIT
				END
			END;
			IF (t IS PCT.Record) THEN
				WITH t: PCT.Record DO
					size := t.size(PCBT.RecSize);
					IF (size.td # NIL) THEN
						IF (t.scope.module = m) THEN
							sym := t.sym(PCOM.Struct);
							IF (t.owner # NIL) & (t.owner.sym = NIL) THEN  PCOM.FPrintObj(t.owner, m)  END;
							PCM.ObjW(R, EURecord);
							PCM.ObjWNum(R, -size.td.offset);
							(*! fof: weakened consistency for new compiler, should  be replaced by new fp rules
							IF t.pvused THEN
								PCM.ObjWNum(R, sym.pvfp);
								PCM.ObjWName(R, "@");
							ELSIF t.pbused THEN
								PCM.ObjWNum(R, sym.pbfp);
								PCM.ObjWName(R, "@")
							END;
							*)
							PCM.ObjW(R, EUEnd);
							size.td := NIL;	(*avoid double tracing*)
						ELSE
							(* aliasing of imported type: schedule module for emission in use list *)
							j := i+1;
							LOOP
								IF j = LEN(mod.imports) THEN
									INC(Nreschedule0);
									PCT.ExtendModArray(mod.imports);
									mod.imports[j] := t.scope.module;
									EXIT
								ELSIF mod.imports[j] = NIL THEN
									INC(Nreschedule1);
									mod.imports[j] := t.scope.module;
									EXIT
								ELSIF mod.imports[j] = t.scope.module THEN
									INC(Nreschedule2);
									EXIT
								END;
								INC(j)
							END
						END
					END
				END
			END
		END UseType;

	BEGIN
		PCM.ObjW(R, 8AX);
		IF mod.imports # NIL THEN
			i := 0;
			WHILE (i < LEN(mod.imports)) & (mod.imports[i] # NIL) DO
				m := mod.imports[i];
				ASSERT(m = m.scope.owner);
				StringPool.GetString(m.name, modname);
				PCM.ObjWName(R, modname);
				IF TraceUse THEN  PCM.LogWLn; PCM.LogWStr("Use: "); PCM.LogWStr(modname)  END;

				c := m.scope.firstValue;
				WHILE c # NIL DO
					IF (PCT.used IN c.flags) & (c.vis # PCT.Internal) THEN UseEntry(m, c, 0) END;
					EXCL(c.flags, PCT.used);
					c := c.nextVal
				END;
				v := m.scope.firstVar;
				WHILE v # NIL DO
					e := v.adr(PCBT.GlobalVariable).entryNo;
					IF (e # PCBT.UndefEntryNo) THEN
						UseEntry(m, v, e); UseType(v.type);
						IF Optimize THEN
							v.adr(PCBT.GlobalVariable).entryNo := PCBT.UndefEntryNo
						ELSE
							ASSERT(v.adr(PCBT.GlobalVariable).next # NIL, 500);
							ASSERT(v.adr(PCBT.GlobalVariable).link # NIL, 501);
						END
					END;
					v := v.nextVar
				END;
				t := m.scope.firstType;
				WHILE t # NIL DO
					IF (PCT.used IN t.flags) & (t.vis # PCT.Internal) THEN UseEntry(m, t, 0); UseType(t.type) END;
					EXCL(t.flags, PCT.used);
					t := t.nextType
				END;
				p := m.scope.firstProc;
				WHILE p # NIL DO
					IF (p.adr # NIL) & (p.adr(PCBT.Procedure).link # NIL) THEN
						UseEntry(m, p, p.adr(PCBT.Procedure).link.offset + EUProcFlag)
					ELSIF (p.flags * {PCT.used, PCT.Inline} = {PCT.used, PCT.Inline}) & (p.vis # PCT.Internal) THEN
						UseEntry(m, p, 0)
					END;
					p := p.nextProc
				END;
				PCM.ObjW(R, 0X);
				INC(i)
			END
		END;
		PCM.ObjW(R, 0X)
	END UseBlock;

	(*
		ExportSection = count { fp link [ Type ] }
		Type = 1 ( ref | (link count pbfp pvfp [Type] {fldfp [Type] | mthfp} 0 ) )

		Vars: link < 0 (offset[SB])
		Proc: link > 0 (offset[code base])
		Other: link = 0
	*)
	PROCEDURE ExportBlock;
	TYPE ExpList = POINTER TO ARRAY OF LONGINT;
	VAR count, nofstr: INTEGER;  pos: LONGINT;
		explist: ExpList; exppos, explen: LONGINT;
		v: PCT.Variable; p: PCT.Proc; t: PCT.Type; c: PCT.Value;

		PROCEDURE ExportType(t: PCT.Struct);
		VAR count: INTEGER;  pos: LONGINT;  sym: PCOM.Struct;  p: PCT.Proc; v: PCT.Variable;
		BEGIN
			WHILE (t IS PCT.Pointer) OR (t IS PCT.Array) DO
				IF t IS PCT.Pointer THEN  t := t(PCT.Pointer).base  ELSE  t := t(PCT.Array).base  END
			END;
(** fof >> *)
			WHILE (t IS PCT.EnhArray) DO t := t( PCT.EnhArray ).base END;
			IF (t IS PCT.Tensor) THEN t := t(PCT.Tensor).base END;
(** << fof  *)
			sym := t.sym(PCOM.Struct);
			IF (t IS PCT.Record) & ((sym.mod = NIL)OR(sym.mod = mod)) THEN
				WITH t: PCT.Record DO
					PCM.ObjW(R, EURecord);
					IF sym.uref # 0 THEN
						PCM.ObjWNum(R, -sym.uref)
					ELSE
						count := 0;
						INC(nofstr);  sym.uref := nofstr;	(*remember it's exported*)
						PCM.ObjWNum(R, t.size(PCBT.RecSize).td.offset);	(* link address in the constant section*)
						PCM.ObjWGetPos(R, pos);  PCM.ObjWLInt(R, 2);	(* number of entries *)
						ExportType(t.btyp);
						PCM.ObjWNum(R, sym.pbfp);  PCM.ObjWNum(R, sym.pvfp);
						v := t.scope.firstVar;
						WHILE v # NIL DO
							IF v.vis # PCT.Internal THEN
								PCM.ObjWNum(R, v.sym(PCOM.Symbol).fp); ExportType(v.type); INC(count);
							END;
							v := v.nextVar
						END;
						p := t.scope.firstProc;
						WHILE p # NIL DO
							IF (p.vis # PCT.Internal) & (p # t.scope.body) THEN
								PCM.ObjWNum(R, p.sym(PCOM.Symbol).fp); INC(count);
							END;
							p := p.nextProc
						END;
						IF count # 0 THEN  PCM.ObjWLIntAt(R, pos, count+2) END;
						PCM.ObjW(R, EUEnd)
					END
				END
			END;
		END ExportType;

		PROCEDURE ExportSymbol(p: PCT.Symbol; offset: LONGINT; s: PCT.Symbol);
			VAR i, fp: LONGINT; name,prefix: ARRAY 256 OF CHAR; explist2: ExpList;
		BEGIN
			StringPool.GetString(p.name, name);
			fp := p.sym(PCOM.Symbol).fp;

			IF s # NIL THEN
				StringPool.GetString(s.name,prefix);

				PCOM.FPrintName(fp,prefix);

			END;
			FOR i := 0 TO exppos-1 DO
				IF fp = explist[i] THEN  PCM.ErrorN(280, Diagnostics.Invalid, p.name) END
			END;
			IF exppos >= explen THEN
				NEW(explist2, 2*explen);
				SYSTEM.MOVE(ADDRESSOF(explist[0]), ADDRESSOF(explist2[0]), 4*explen);
				explist := explist2; explen := 2*explen
			END;
			explist[exppos] := fp; INC(exppos);
			PCM.ObjWNum(R, fp);
			PCM.ObjWNum(R, offset);
			INC(count);
		END ExportSymbol;

		PROCEDURE ExportMethods(s: PCT.Symbol);
		VAR sym: PCOM.Struct;  p: PCT.Proc; t: PCT.Struct;
		BEGIN
			t := s.type;
			WHILE (t IS PCT.Pointer) OR (t IS PCT.Array) DO
				IF t IS PCT.Pointer THEN  t := t(PCT.Pointer).base  ELSE  t := t(PCT.Array).base  END
			END;
			WHILE (t IS PCT.EnhArray) DO t := t( PCT.EnhArray ).base END;
			IF (t IS PCT.Tensor) THEN t := t(PCT.Tensor).base END;

			sym := t.sym(PCOM.Struct);
			IF (t IS PCT.Record) & ((sym.mod = NIL)OR(sym.mod = mod)) THEN
				WITH t: PCT.Record DO
					p := t.scope.firstProc;
					WHILE p # NIL DO
						IF (p.vis # PCT.Internal) (*& ~(PCT.Inline IN p.flags)*) THEN
							ExportSymbol(p, p.adr(PCBT.Procedure).codeoffset,s);
						END;
						p := p.nextProc
					END
				END
			END;
		END ExportMethods;

	BEGIN
		PCM.ObjW(R, 88X);
		PCM.ObjWGetPos(R, pos);  PCM.ObjWLInt(R, 0);
		nofstr := 0;  count := 0;  exppos := 0;
		NEW(explist, 256); explen := 256;
		c := scope.firstValue;
		WHILE c # NIL DO
			IF c.vis # PCT.Internal THEN
				ExportSymbol(c, 0,NIL);
			END;
			c := c.nextVal
		END;
		v := scope.firstVar;
		WHILE v # NIL DO
			IF v.vis # PCT.Internal THEN
				ExportSymbol(v, v.adr(PCBT.GlobalVariable).offset,NIL);
				ExportType(v.type)
			END;
			v := v.nextVar
		END;
		t := scope.firstType;
		WHILE t # NIL DO
			IF t.vis # PCT.Internal THEN
				ExportSymbol(t, 0,NIL);
				ExportType(t.type)
			END;
			t:= t.nextType
		END;
		p := scope.firstProc;
		WHILE p # NIL DO
			IF (p.vis # PCT.Internal) (*& ~(PCT.Inline IN p.flags)*) THEN
				ExportSymbol(p, p.adr(PCBT.Procedure).codeoffset,NIL);
			END;
			p := p.nextProc
		END;
		t := scope.firstType;
		WHILE t # NIL DO
			IF t.vis # PCT.Internal THEN
				ExportMethods(t);
			END;
			t:= t.nextType
		END;

		IF count # 0 THEN  PCM.ObjWLIntAt(R, pos, count)  END;
		PCM.ObjW(R, EUEnd)
	END ExportBlock;

	PROCEDURE RawBlock(tag: CHAR;  size: LONGINT;  VAR block: ARRAY OF CHAR);
	VAR i: LONGINT;
	BEGIN
		PCM.ObjW(R, tag);
		i := 0;
		WHILE i < size DO PCM.ObjW(R, block[i]); INC(i)  END
	END RawBlock;

	PROCEDURE WriteType(rec: PCT.Record; VAR tdSize: LONGINT (* ug *));
	CONST MaxTags = 16; (* ug: temporary solution, Modules.MaxTags *)
	VAR  size: PCBT.RecSize;  nofptrsPos, tdSizePos, oldmth: LONGINT;  base: PCT.Record;  m: PCT.Method;
		adr: PCBT.Method;  bsym: PCOM.Struct;  name, name2: StringBuf;
		basenr: INTEGER; baseid: LONGINT;
		upperPartTdSize, lowerPartTdSize: LONGINT;
	BEGIN
		PCT.GetTypeName(rec, name);
		size := rec.size(PCBT.RecSize);
		PCM.ObjWNum(R, size.size);
		PCM.ObjWNum(R, size.td.offset);
		IF rec.brec = NIL THEN
			oldmth := 0;
			basenr := -1;
			baseid := -1
		ELSE
			base := rec.brec;
			basenr := 0;
			IF (base.sym # NIL) THEN
				bsym := base.sym(PCOM.Struct);
				ASSERT(bsym.mod # NIL);
				IF bsym.mod # scope.owner THEN basenr := SHORT(bsym.mod.adr(PCBT.Module).nr) END
			END;
			IF basenr = 0 THEN
				baseid := base.size(PCBT.RecSize).td.offset
			ELSIF base.owner = NIL THEN
				baseid := base.ptr.owner.sym(PCOM.Symbol).fp
			ELSE
				StringPool.GetString(base.owner.name, name2);
				baseid := base.owner.sym(PCOM.Symbol).fp
			END;
			oldmth := base.size(PCBT.RecSize).nofMethods;
		END;
		PCM.ObjWNum(R, basenr);
		PCM.ObjWNum(R, baseid);
		IF rec.scope.IsProtected () THEN
			PCM.ObjWNum(R, -size.nofMethods);			(* NofMethods *)
		ELSE
			PCM.ObjWNum(R, size.nofMethods);			(* NofMethods *)
		END;
		PCM.ObjWNum(R, oldmth);					(* InheritedMethods *)
		PCM.ObjWNum(R, size.nofLocalMethods);	(* NewMethods *)
		PCM.ObjWGetPos(R, nofptrsPos);
		PCM.ObjWLInt(R, 0);
		PCM.ObjWName(R, name);
		PCM.ObjWGetPos(R, tdSizePos);
		PCM.ObjWLInt(R, 0);

		(*New Methods in Record*)
		i := 0; m := rec.scope.firstMeth;
		WHILE m # NIL DO
			IF ~(PCT.Inline IN m.flags) OR (PCT.Indexer IN m.flags) THEN
				adr := m.adr(PCBT.Method);
				PCM.ObjWNum(R, adr.mthNo);
				PCM.ObjWNum(R, adr.entryNr);
				INC(i);
			END;
			m := m.nextMeth
		END;
		ASSERT(i = size.nofLocalMethods, 500);	(*sanity check*)

		(* Ptrs in Record *)
		nofptrs := 0;
		OutPtrs(0, rec, FALSE);  (* debug = FALSE *)
		IF nofptrs > MAX(INTEGER) THEN PCM.Error(221, 0, "") END;
		IF nofptrs # 0 THEN PCM.ObjWLIntAt(R, nofptrsPos, nofptrs) END;

(* ug *)	upperPartTdSize := AddressSize * (MaxTags + size.nofMethods + 1 + 1); (* tags, methods, methods end marker (sentinel), address of TypeInfo *)
(* ug *)	(* lowerPartTdSize := AddressSize * (1 + nofptrs + 1); (* recsize, no. pointers and sentinel *)  *)
(* ug *)	lowerPartTdSize := AddressSize * (2 + (4 + nofptrs) + 1); (* SIZEOF(Heaps.StaticTypeDesc), data part of dynamic array of pointer offsets,
																 padding field to observe 0 mod 8 boundary of dynamic array *)
(* ug *)	tdSize := upperPartTdSize + lowerPartTdSize;

(* ug *)	PCM.ObjWLIntAt(R, tdSizePos, tdSize)
	END WriteType;

	PROCEDURE WriteInterface(rec: PCT.Record);
	VAR  size: PCBT.RecSize; name: StringBuf;
	BEGIN
		PCT.GetTypeName(rec, name);
		size := rec.size(PCBT.RecSize);
		PCM.ObjWNum(R, 4 + 4*rec.scope.procCount);
		PCM.ObjWNum(R, size.td.offset);
		PCM.ObjWNum(R, -1);
		PCM.ObjWNum(R, -1);
		PCM.ObjWNum(R, 0);	(* NofMethods *)
		PCM.ObjWNum(R, 0);	(* InheritedMethods *)
		PCM.ObjWNum(R, 0);	(* NewMethods *)
		PCM.ObjWLInt(R, 0);      	(* no. pointers (fixed size) *)
		PCM.ObjWName(R, name);
	END WriteInterface;

	PROCEDURE TypeBlock;
	VAR  rec: PCT.Record; tdSize: LONGINT; (* ug *)
	BEGIN  PCM.ObjW(R, 8BX);
		typeDescsSize := 0; (* ug *)
		rec := scope.records;
		WHILE rec # NIL DO
			IF PCT.interface IN rec.mode THEN
				WriteInterface(rec)
			ELSE
				WriteType(rec, tdSize); (* ug *)
				typeDescsSize := typeDescsSize + tdSize (* ug *)
			END;
			rec := rec.link
		END;
		PCM.ObjWLIntAt(R, typeDescsSizePos, typeDescsSize); (* ug *)
		rec := scope.records;
		WHILE rec # NIL DO
			rec.size(PCBT.RecSize).td := NIL;
			rec := rec.link
		END;
	END TypeBlock;

	(* 	Stores the exception handle table in the following format
		ExceptionHandlerTable 	::= 8EX {ExceptionTableEntry}
		ExceptionTableEntry 	::= 0FFX pcFrom(4 bytes) pcTo(4 bytes) pcHandler(4 bytes)

		Since there is only one FINALLY  in every procedure, method, body, ... we don't need
		to obtain an order for nesting.
	*)
	PROCEDURE ExTableBlock;
	VAR
		entry: ExTableEntry;
	BEGIN
		PCM.ObjW(R, 8EX);
		entry := exTable;
		WHILE entry # NIL DO
			PCM.ObjW(R, 0FEX);
			PCM.ObjWNum(R, entry.pcFrom);
			PCM.ObjWNum(R, entry.pcTo);
			PCM.ObjWNum(R, entry.pcHandler);
			entry := entry.next;
		END;
	END ExTableBlock;

	(* ug *)
	PROCEDURE PointerInProcBlock;

		PROCEDURE PointerOffsets(s : PCT.Scope; codeoffset, beginOffset, endOffset: LONGINT);
		VAR v: PCT.Variable; p: PCT.Proc; t: PCT.Type; par: PCT.Parameter;
			rs: PCT.RecScope; adr: PCBT.Procedure;
			nofPtrPos : LONGINT;
		BEGIN
			IF s # NIL THEN
				IF s IS PCT.ModScope THEN
					PCM.ObjWNum(R, codeoffset);
					PCM.ObjWNum(R, beginOffset);
					PCM.ObjWNum(R, endOffset);
					PCM.ObjWLInt(R, 0);			(* nofptrs *)
					INC(nofProcs);
				ELSIF s IS PCT.ProcScope THEN
					PCM.ObjWNum(R, codeoffset);
					PCM.ObjWNum(R, beginOffset);
					PCM.ObjWNum(R, endOffset);
					nofptrs := 0;
					PCM.ObjWGetPos(R, nofPtrPos); PCM.ObjWLInt(R, nofptrs);
					v := s.firstVar;
					WHILE v # NIL DO
						IF (v.adr # NIL) & ~(PCM.Untraced IN v.flags) THEN OutPtrs(v.adr(PCBT.Variable).offset, v.type, FALSE) (* debug = FALSE *) END;
						v := v.nextVar
					END;
					v := s.firstHiddenVar;
					WHILE v # NIL DO
						IF v.adr # NIL THEN OutPtrs(v.adr(PCBT.Variable).offset, v.type, FALSE) (* debug = FALSE *) END;
						v := v.nextVar
					END;
					par := s(PCT.ProcScope).firstPar;
					WHILE par # NIL DO
						IF ~par.ref THEN
							OutPtrs(par.adr(PCBT.Variable).offset, par.type, FALSE) (* debug = FALSE *)
						END;
						par := par.nextPar
					END;
					PCM.ObjWLIntAt(R, nofPtrPos, nofptrs);
 					IF nofptrs > maxPtrs THEN maxPtrs := nofptrs END;
					INC(nofProcs);
				END;
				p := s.firstProc;
				WHILE p # NIL DO
					adr := p.adr(PCBT.Procedure);
					IF adr.codeoffset # 0 THEN
						PointerOffsets(p.scope, adr.codeoffset, adr.beginOffset, adr.endOffset)
					END;
					p := p.nextProc
				END;
				t := s.firstType;
				WHILE t # NIL DO
					IF (t.type IS PCT.Pointer) & (t.type(PCT.Pointer).base IS PCT.Record)THEN
						rs := t.type(PCT.Pointer).baseR.scope;
						PointerOffsets(rs, 0, 0, 0)
					END;
					t := t.nextType
				END
			END
		END PointerOffsets;

	BEGIN
		PCM.ObjW(R, 8FX);
		nofProcs := 0;
		maxPtrs := 0;
		PointerOffsets(scope, adr.codeoffset, adr.beginOffset, adr.endOffset);
		PCM.ObjWLIntAt(R, nofProcsPos, nofProcs);
		PCM.ObjWLIntAt(R, maxPtrsPos, maxPtrs);
	END PointerInProcBlock;
	(* ug *)

BEGIN
	exTable := NIL; exTableLen := 0;
	mod := scope.owner;
	adr := mod.adr(PCBT.Module);
	sym := NIL;
	IF mod.sym # NIL THEN  sym := mod.sym(PCOM.Module)  END;
	PCLIR.CG.GetCode(code, codeSize, hdrCodeSize, addressFactor);
	InsertFixupLists(addressFactor);
	CollectInfo;
	dsize := adr.locsize;
	ASSERT(codeSize < PCLIR.CG.MaxCodeSize);	(*objfile restriction*)
(* header block *)
	PCM.ObjWLInt (R, PCM.RefSize(R)+1);
	PCM.ObjWGetPos(R, EntriesPos); PCM.ObjWLInt (R, 0);
	PCM.ObjWLInt (R, nofCmds);
	PCM.ObjWGetPos(R, PtrPos); PCM.ObjWLInt (R, 0);
	PCM.ObjWLInt (R, scope.nofRecs);
	PCM.ObjWLInt (R, nofImp);
	PCM.ObjWGetPos(R, VarConsPos); PCM.ObjWLInt (R, 0);
	PCM.ObjWGetPos(R, LinksPos); PCM.ObjWLInt (R, 0);
	PCM.ObjWLInt (R, dsize);
	PCM.ObjWLInt (R, adr.constsize);
	PCM.ObjWLInt (R, hdrCodeSize);
	PCM.ObjWLInt(R, exTableLen);
	PCM.ObjWGetPos(R, nofProcsPos); PCM.ObjWLInt(R, 0); (* ug *)
	PCM.ObjWGetPos(R, maxPtrsPos); PCM.ObjWLInt(R, 0); (* ug *)
	PCM.ObjWGetPos(R, typeDescsSizePos); PCM.ObjWLInt(R, 0); (* ug *)
	StringPool.GetString(mod.name, str); PCM.ObjWName (R, str);

	EntryBlock(addressFactor);
	CommandBlock;
	PointerBlock;
	ImportBlock;
	VarConsBlock;
	IF nofVarCons # 0 THEN PCM.ObjWLIntAt(R, VarConsPos, nofVarCons) END;
	LinkBlock;
	RawBlock(87X, adr.constsize, adr.const^);
	ExportBlock;
	RawBlock(89X, codeSize, code^);
	UseBlock;
	TypeBlock;
	ExTableBlock;
	PointerInProcBlock; (* ug *)
(* ref block *)
	PCM.ObjW(R, 8CX);

	PCM.CloseObj(R);

	adr.ResetLists;
END Generate;

PROCEDURE Init*;
BEGIN
	refSize := 0;
	nofCmds := 0;
	nofImp := 0;
	nofVarCons := 0;  nofLinks := 0;
	dsize := 0;
END Init;

PROCEDURE Install*;
BEGIN
	Init();
	PCBT.generate := Generate
END Install;

BEGIN
	IF TraceUse THEN PCM.LogWLn; PCM.LogWStr("PCOF.TraceUse on") END;
	PCBT.generate := Generate
END PCOF.

(*
	20.02.02	be	refinement in the code generator plugin
	13.04.02	prk	export and use of inlined assembler procedures fixed
	18.03.02	prk	PCBT code cleanup and redesign
	20.02.02	be	refinement in the code generator plugin
	23.01.02	prk	fixed bug in use list with aliases of imported types
	22.01.02	prk	ToDo list moved to PCDebug
	28.11.01	prk	import section: list only used modules
	27.08.01	prk	scope.unsorted list removed; use var, proc, const and type lists instead
	16.08.01	prk	keep PCBT.Variable offset, ignore for imported vars
	11.08.01	prk	Fixup and use lists for procedures in PCBT cleaned up
	10.08.01	prk	PCBT.Procedure: imported: BOOLEAN replaced by owner: Module
	06.08.01	prk	make code generator and object file generator indipendent
	02.08.01	prk	Aos-Style Commands added to the Command list (by pjm)
	02.07.01	prk	access flags, new design
	27.06.01	prk	StringPool cleaned up
	14.06.01	prk	type descs for dynamic arrays of ptrs generated by the compiler
	06.06.01	prk	use string pool for object names
	29.05.01    be	syscall structures moved to backend (PCLIR & code generators)
	28.05.01	prk	don't insert invisible symbols in the "use" section
	28.05.01	prk	issue error 221/222 when more than MAX(INTEGER) pointers in global data / record
	03.05.01	be	Installable code generators
	26.03.01	prk	New Reference Section format
	25.03.01	prk	limited HUGEINT implementation (as abstract type)
	14.03.01	prk	OutRefs, don't list ARRAYs of user defined types
	14.03.01	prk	OutRefs, don't list inlined procedures
*)