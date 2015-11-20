(* Aos Runtime: PE object file plug-in, Copyright 2004, Emil J. Zeller, ETH Zürich *)

(* Paco, Copyright 2000 - 2002, Patrik Reali, ETH Zurich *)

MODULE PCOFPE; (** AUTHOR "ejz"; PURPOSE "Parallel Compiler: PE object file plug-in"; *)
	IMPORT SYSTEM, KernelLog, StringPool, PCDebug, PCBT, PCLIR, PCM, PCT, PCOM, Dates, Strings, Streams, Files, Clock, Diagnostics;

	CONST
		Loader = "AosRuntime"; Heap = "AosRuntime"; Active = "Objects";

		ImageDosSignature = 05A4DH; (* MZ *)
		ImageNtSignature = 000004550H; (* PE00 *)
		EXEImageBase = 0400000H; DLLImageBase = 010000000H;

		ImageSubsystemUnknown = 0;
		ImageSubsystemNative = 1;
		ImageSubsystemWindowsGui = 2;
		ImageSubsystemWindowsCui = 3;

		ImageNumberOfDirectoryEntries = 16;

		ImageFileRelocsStripped = 0;
		ImageFileExecutableImage = 1;
		ImageFileLineNumsStripped = 2;
		ImageFileLocalSymsStripped = 3;
		ImageFile32BitMachine = 8;
		ImageFileDll = 13;
		ImageFileMachineI386 = 014CH;
		ImageOptionalMagic = 010BH;
		MajorLinkerVersion = 0X; MinorLinkerVersion = 0X;
		ImageSizeOfShortName = 8;
		ImageScnCntCode = 5;
		ImageScnCntInitializedData = 6;
		ImageScnMemDiscardable = 25;
		ImageScnMemExecute = 29;
		ImageScnMemRead = 30;
		ImageScnMemWrite = 31;

		PageSize = 01000H; SectorSize = 0200H;
		DefaultFileAlign = SectorSize; DefaultSectionAlign = PageSize;
		BaseRVA = DefaultSectionAlign;
		DefaultHeapSize = 64*1024; DefaultStackSize = 1024*1024;

		ImageDirectoryEntryExport = 0;
		ImageDirectoryEntryImport = 1;
		ImageDirectoryEntryBasereloc = 5;
		ImageDirectoryEntryIAT = 12;

		ImageRelBasedHighLow = 3;

		ModeDef = 0; ModeDLL = 1; ModeEXE = 2;

		EUEnd = 0X; EURecord = 1X; EUProcFlag = LONGINT(080000000H);

	TYPE
		ImageFileHeader = RECORD
			Machine: INTEGER;
			NumberOfSections: INTEGER;
			TimeDateStamp: LONGINT;
			PointerToSymbolTable: LONGINT;
			NumberOfSymbols: LONGINT;
			SizeOfOptionalHeader: INTEGER;
			Characteristics: INTEGER
		END;

		ImageDataDirectory = RECORD
			VirtualAddress, Size: LONGINT
		END;

		ImageOptionalHeader = RECORD
			Magic: INTEGER;
			MajorLinkerVersion, MinorLinkerVersion: CHAR;
			SizeOfCode, SizeOfInitializedData, SizeOfUninitializedData,
			AddressOfEntryPoint,
			BaseOfCode, BaseOfData, ImageBase,
			SectionAlignment, FileAlignment: LONGINT;
			MajorOperatingSystemVersion, MinorOperatingSystemVersion,
			MajorImageVersion, MinorImageVersion,
			MajorSubsystemVersion, MinorSubsystemVersion: INTEGER;
			Win32VersionValue,
			SizeOfImage, SizeOfHeaders,
			CheckSum: LONGINT;
			Subsystem,
			DllCharacteristics: INTEGER;
			SizeOfStackReserve, SizeOfStackCommit,
			SizeOfHeapReserve, SizeOfHeapCommit,
			LoaderFlags, NumberOfRvaAndSizes: LONGINT;
			DataDirectory: ARRAY ImageNumberOfDirectoryEntries OF ImageDataDirectory
		END;

		ImageSectionHeader = RECORD
			Name: ARRAY ImageSizeOfShortName OF CHAR;
			VirtualSize: LONGINT;
			VirtualAddress: LONGINT;
			SizeOfRawData: LONGINT;
			PointerToRawData: LONGINT;
			PointerToRelocations: LONGINT;
			PointerToLinenumbers: LONGINT;
			NumberOfRelocations: INTEGER;
			NumberOfLinenumbers: INTEGER;
			Characteristics: SET
		END;

		ImageExportDirectory = RECORD
			Characteristics, TimeDateStamp: LONGINT;
			MajorVersion, MinorVersion: INTEGER;
			Name, Base, NumberOfFunctions, NumberOfNames,
			AddressOfFunctions, AddressOfNames, AddressOfNameOrdinals: LONGINT
		END;

		ImageImportDescriptor = RECORD
			Characteristics, TimeDateStamp, ForwarderChain, Name, FirstThunk: LONGINT
		END;

		Bytes = POINTER TO ARRAY OF CHAR;
		Name = ARRAY 256 OF CHAR;

		ExportFPList = POINTER TO ARRAY OF LONGINT;

		SectionReader = OBJECT (Streams.Reader)
			VAR sect: Section; org, ofs: LONGINT;

			PROCEDURE Receive(VAR buf: ARRAY OF CHAR; ofs, size, min: LONGINT; VAR len, res: LONGINT);
			BEGIN
				len := sect.used - SELF.ofs;
				IF len > 0 THEN
					IF len > size THEN len := size END;
					SYSTEM.MOVE(ADDRESSOF(sect.data[SELF.ofs]), ADDRESSOF(buf[ofs]), len);
					INC(SELF.ofs, len)
				END;
				IF len < min THEN
					res := Streams.EOF
				ELSE
					res := Streams.Ok
				END
			END Receive;

			PROCEDURE Pos(): LONGINT;
			BEGIN
				RETURN org + Pos^()
			END Pos;

			PROCEDURE SetPos(ofs: LONGINT);
			BEGIN
				Reset();
				SELF.org := ofs; SELF.ofs := ofs
			END SetPos;

			PROCEDURE &Open*(sect: Section; ofs: LONGINT);
			BEGIN
				InitReader(SELF.Receive, 4); (* is only used for small fixups *)
				SELF.sect := sect; SELF.org := ofs; SELF.ofs := ofs
			END Open;
		END SectionReader;

		SectionWriter = OBJECT (Streams.Writer)
			VAR sect: Section; org, ofs: LONGINT;

			PROCEDURE Send(CONST buf: ARRAY OF CHAR; ofs, len: LONGINT; propagate: BOOLEAN; VAR res: LONGINT);
			BEGIN
				res := Streams.Ok; IF len <= 0 THEN RETURN END;
				IF (SELF.ofs + len) > sect.len THEN sect.Resize(SELF.ofs + len) END;
				SYSTEM.MOVE(ADDRESSOF(buf[ofs]), ADDRESSOF(sect.data[SELF.ofs]), len);
				INC(SELF.ofs, len);
				IF SELF.ofs > sect.used THEN sect.used := SELF.ofs END
			END Send;

			PROCEDURE Pos(): LONGINT;
			BEGIN
				RETURN org + Pos^()
			END Pos;

			PROCEDURE SetPos(ofs: LONGINT);
			BEGIN
				Update(); Reset();
				SELF.org := ofs; SELF.ofs := ofs
			END SetPos;

			PROCEDURE &Open*(sect: Section; ofs: LONGINT);
			BEGIN
				InitWriter(SELF.Send, PageSize);
				SELF.sect := sect; SELF.org := ofs; SELF.ofs := ofs
			END Open;
		END SectionWriter;

		Section = OBJECT
			VAR
				head: ImageSectionHeader;
				data: Bytes; len, used: LONGINT;
				imports: ImportReloc; relocs: BaseReloc;
				W: SectionWriter; R: SectionReader;
				next: Section;

			PROCEDURE Resize(min: LONGINT);
				VAR data: Bytes; i: LONGINT;
			BEGIN
				ASSERT(min > len);
				min := Align(min, PageSize); NEW(data, min); i := len;
				IF i > 0 THEN
					SYSTEM.MOVE(ADDRESSOF(SELF.data[0]), ADDRESSOF(data[0]), i)
				END;
				WHILE i < min DO data[i] := 0X; INC(i) END;
				SELF.data := data; len := min
			END Resize;

			PROCEDURE SetBase(VAR base: LONGINT);
				VAR s: SET;
			BEGIN
				SELF.head.VirtualAddress := base;
				s := SYSTEM.VAL(SET, SELF.head.Characteristics);
				IF (ImageScnCntCode IN s) OR (ImageScnCntInitializedData IN s) THEN
					SELF.head.VirtualSize := SELF.used
				ELSE
					ASSERT(SELF.head.VirtualSize > 0)
				END;
				INC(base, Align(SELF.head.VirtualSize, DefaultSectionAlign))
			END SetBase;

			PROCEDURE &New*(pe: PEModule; name: ARRAY OF CHAR; chars: SET);
				VAR p, s: Section;
			BEGIN
				SELF.W := NIL; SELF.R := NIL;
				SELF.next := NIL;
				p := NIL; s := pe.sects;
				WHILE s # NIL DO
					p := s; s := s.next
				END;
				IF p # NIL THEN
					p.next := SELF
				ELSE
					pe.sects := SELF
				END;
				INC(pe.fileHdr.NumberOfSections);
				SELF.data := NIL; SELF.used := 0; SELF.len := 0;
				COPY(name, SELF.head.Name); SELF.head.Characteristics := chars;
				SELF.head.VirtualSize := 0; SELF.head.VirtualAddress := 0;
				SELF.head.SizeOfRawData := 0; SELF.head.PointerToRawData := 0;
				SELF.head.NumberOfRelocations := 0; SELF.head.PointerToRelocations := 0;
				SELF.head.NumberOfLinenumbers := 0; SELF.head.PointerToLinenumbers := 0;
				SELF.imports := NIL; SELF.relocs := NIL;
				NEW(W, SELF, 0); NEW(R, SELF, 0)
			END New;
		END Section;

		BaseReloc = POINTER TO RECORD
			ofs: LONGINT; base: Section;
			next: BaseReloc
		END;

		ImportMod = POINTER TO RECORD
			desc: ImageImportDescriptor;
			name: Name; objs: ImportObj;
			next: ImportMod
		END;

		ImportObj = POINTER TO RECORD
			name: Name; next: ImportObj;
			iat: LONGINT
		END;

		ImportReloc = POINTER TO RECORD
			ofs: LONGINT; obj: ImportObj;
			next: ImportReloc;
			iat, abs, uofs: BOOLEAN
		END;

		ExportObj = POINTER TO RECORD
			name: Name;
			sect: Section; ofs: LONGINT;
			next: ExportObj
		END;

		PEModule = OBJECT
			VAR
				name: Files.FileName;
				mod: PCT.Module; adr: PCBT.Module;
				codearr: PCLIR.CodeArray; hdrCodeSize, addressFactor: LONGINT;
				fileHdr: ImageFileHeader; optHdr: ImageOptionalHeader;
				sects, type, var, const, code, idata, edata, reloc: Section;
				exports: ExportObj; imports: ImportMod;
				explist: ExportFPList; exppos, explen, nofstr, nofImp, count: LONGINT;
				desc: RECORD
					modules, commands, methods, pointers, exports, imports, types: LONGINT;
					iatfix: LONGINT
				END;

			PROCEDURE AddImportMod(name: ARRAY OF CHAR): ImportMod;
				VAR mod: ImportMod;
			BEGIN
				mod := imports;
				WHILE (mod # NIL) & (mod.name # name) DO
					mod := mod.next
				END;
				IF mod = NIL THEN
					NEW(mod); COPY(name, mod.name); mod.objs := NIL;
					mod.desc.Characteristics := 0; mod.desc.TimeDateStamp := fileHdr.TimeDateStamp;
					mod.desc.ForwarderChain := 0; mod.desc.Name := 0; mod.desc.FirstThunk := 0;
					mod.next := imports; imports := mod
				END;
				RETURN mod
			END AddImportMod;

			PROCEDURE FixupSysCall(l: PCBT.Fixup; entry: LONGINT);
				VAR
					rt: ImportMod; name: Name; obj: ImportObj; W: SectionWriter; p: PCT.Proc; offset: LONGINT;
					idx: StringPool.Index;
			BEGIN
				rt := NIL;
				CASE entry OF
					|246: name := "Unlock"
					|247: name := "Lock"
					|249: name := "Await"
					|250: name := "CreateProcess"
					|251: name := "NewArr"
					|252: name := "NewSys"
					|253: name := "NewRec"
				ELSE
					HALT(99)
				END;
				IF (entry >= 246) & (entry <= 250) & (SELF.name # Active) THEN
					rt := AddImportMod(Active)
				END;
				IF (entry >= 251) & (entry <= 253) & (SELF.name # Heap) THEN
					rt := AddImportMod(Heap)
				END;
				IF rt # NIL THEN
					obj := AddImportObj(rt, name); p := NIL
				ELSE
					StringPool.GetIndex(name, idx);
					p := mod.scope.firstProc;
					WHILE (p # NIL) & (p.name # idx) DO
						p := p.nextProc
					END;
					ASSERT(p # NIL)
				END;
				W := code.W;
				WHILE l # NIL DO
					offset := l.offset*addressFactor;
					W.SetPos(offset);
					IF rt # NIL THEN
						AddImportReloc(code, offset, obj, FALSE, FALSE, FALSE);
						W.RawLInt(0)
					ELSE
						W.RawLInt(p.adr(PCBT.Procedure).codeoffset-(offset+4))
					END;
					l := l.next
				END;
				W.Update()
			END FixupSysCall;

			PROCEDURE FixupCase(l: PCBT.Fixup);
				VAR offset: LONGINT;
			BEGIN
				WHILE l # NIL DO
					offset := l.offset*addressFactor;
					AddOfsReloc(const, offset, code);
					l := l.next
				END
			END FixupCase;

			PROCEDURE FixupLinks;
				VAR entry, i: LONGINT;
			BEGIN
				i := 0;
				WHILE i < PCBT.NofSysCalls DO
					IF adr.syscalls[i] # NIL THEN
						entry := ORD(PCLIR.CG.SysCallMap[i]);
						CASE entry OF
							246..253: FixupSysCall(adr.syscalls[i], entry)
							|255: FixupCase(adr.syscalls[i])
						ELSE
							HALT(99)	(* unknown entry *)
						END
					END;
					INC(i)
				END
			END FixupLinks;

			PROCEDURE TypeAlign4;
				VAR W: SectionWriter; n: LONGINT;
			BEGIN
				n := type.used MOD 4;
				IF n # 0 THEN
					W := type.W; W.SetPos(type.used);
					n := 4-n;
					WHILE n > 0 DO W.Char(0X); DEC(n) END;
					W.Update()
				END
			END TypeAlign4;

			PROCEDURE Commands;
				VAR W: SectionWriter; proc: PCT.Proc; name: Name; ofs: LONGINT;
			BEGIN
				TypeAlign4(); desc.commands := type.used;
(* possible improvment: store only export ordinal, name and address from edata export table *)
				W := type.W; W.SetPos(type.used);
				proc := mod.scope.firstProc;
				WHILE (proc # NIL) DO
					IF (proc.vis = PCT.Public) & ~(PCT.Inline IN proc.flags) THEN
						ofs := proc.adr(PCBT.Procedure).codeoffset;
						IF (proc.scope.firstPar = NIL) & (proc.type = PCT.NoType) THEN
							StringPool.GetString(proc.name, name);
							W.Bytes(name, 0, 32);
							AddOfsReloc(type, W.Pos(), code);
							W.RawLInt(ofs); W.RawLInt(0)
						ELSIF (proc.scope.firstPar # NIL) & (proc.scope.firstPar.nextPar = NIL) & (proc.scope.firstPar.type = PCT.Ptr) & (proc.type = PCT.Ptr) THEN
							StringPool.GetString(proc.name, name);
							W.Bytes(name, 0, 32);
							AddOfsReloc(type, W.Pos()+4, code);
							W.RawLInt(0); W.RawLInt(ofs)
						END
					END;
					proc := proc.nextProc
				END;
				name := "";
				W.Bytes(name, 0, 32); (* sentinel *)
				W.RawLInt(0); W.RawLInt(0);
				W.Update()
			END Commands;

			PROCEDURE UseModule(m: PCBT.Module);
			BEGIN
				IF m.nr = 0 THEN INC(nofImp); m.nr := -1 END
			END UseModule;

			PROCEDURE UseModules;
				VAR
					o: PCT.Symbol; p: PCBT.GlobalVariable; rec: PCT.Record; bsym: PCOM.Struct; i, j: LONGINT;
					m: PCT.Module; adr: PCBT.Module; name: Name; im: ImportMod; W: SectionWriter;
			BEGIN
				TypeAlign4(); desc.modules := type.used;
				W := type.W; W.SetPos(type.used);
				(* detect imported modules *)
				IF mod.imports = NIL THEN W.RawLInt(0); W.Update(); RETURN END;
				i := 0;
				WHILE (i < LEN(mod.imports)) & (mod.imports[i] # NIL) DO
					mod.imports[i].adr(PCBT.Module).nr := 0;
					INC(i)
				END;
				nofImp := 0;
				o := mod.scope.sorted;
				WHILE o # NIL DO
					IF (o IS PCT.Module) & (o.adr # PCT.System.adr) THEN UseModule(o.adr(PCBT.Module)) END;
					o := o.sorted;
				END;
				p := SELF.adr.ExtVars;
				WHILE p # PCBT.sentinel DO
					IF p.link # NIL THEN UseModule(p.owner) END;
					p := p.next
				END;
				rec := mod.scope.records;
				WHILE rec # NIL DO
					IF (rec.brec # NIL) & (rec.brec.sym # NIL) THEN
						bsym := rec.brec.sym(PCOM.Struct);
						IF bsym.mod # mod.scope.owner THEN UseModule(bsym.mod.adr(PCBT.Module)) END
					END;
					rec := rec.link
				END;
				W.RawLInt(nofImp);
				i := 0; j := 0;
				WHILE (i < LEN(mod.imports)) & (mod.imports[i] # NIL) DO
					m := mod.imports[i];
					adr := m.adr(PCBT.Module);
					IF adr.nr = -1 THEN
						INC(j); adr.nr := SHORT(j);
						StringPool.GetString(m.name, name);
						W.RawString(name);
						im := AddImportMod(name)
					END;
					INC(i)
				END;
				W.Update()
			END UseModules;

			PROCEDURE FixupProc(p: PCBT.Procedure);
				VAR W: SectionWriter; l: PCBT.Fixup; offset: LONGINT;
			BEGIN
				W := code.W; l := p.link;
				WHILE l # NIL DO
					offset := l.offset*addressFactor;
ASSERT(code.data[offset-1] # 0E8X);
					AddOfsReloc(code, offset, code);
					W.SetPos(offset); W.RawLInt(p.codeoffset);
					l := l.next
				END;
				W.Update()
			END FixupProc;

			PROCEDURE FixupOwnProcs;
				VAR W: SectionWriter; p: PCBT.Procedure; nofMethods: LONGINT;
			BEGIN
				TypeAlign4(); desc.methods := type.used;
				W := type.W; W.SetPos(type.used);
				nofMethods := 0;
				p := adr.OwnProcs;
				WHILE p # PCBT.psentinel DO
					IF (p.public) OR (p.link # NIL) OR (p IS PCBT.Method) THEN
						IF p IS PCBT.Method THEN
							p.entryNr := nofMethods; INC(nofMethods);
							AddOfsReloc(type, W.Pos(), code);
							W.RawLInt(p.codeoffset)
						END;
						IF p.link # NIL THEN FixupProc(p) END
					END;
					p := p.next
				END;
				W.RawLInt(0); (* sentinel *)
				W.Update()
			END FixupOwnProcs;

			PROCEDURE PtrAdr(W: SectionWriter; offset: LONGINT; type: PCT.Struct; fixadr: BOOLEAN);
				VAR i, n, off: LONGINT; f: PCT.Variable; scope: PCT.Scope; base: PCT.Struct; size: PCBT.Size;
			BEGIN
				IF ~type.size(PCBT.Size).containPtrs THEN RETURN END;
				IF PCT.IsPointer(type) THEN
					IF fixadr THEN AddOfsReloc(SELF.type, W.Pos(), var) END;
					W.RawLInt(offset)
				ELSIF (type IS PCT.Delegate) & ~(PCT.StaticMethodsOnly IN type.flags) THEN
					IF fixadr THEN AddOfsReloc(SELF.type, W.Pos(), var) END;
					W.RawLInt(offset+4)
				ELSIF type IS PCT.Record THEN
					WITH type: PCT.Record DO
						IF type.brec # NIL THEN PtrAdr(W, offset, type.brec, fixadr) END;
						scope := type.scope;
					END;
					f := scope.firstVar;
					WHILE f # NIL DO
						IF ~(PCM.Untraced IN f.flags) THEN
							ASSERT(scope.state >= PCT.structallocated);
							type := f.type; off := f.adr(PCBT.Variable).offset;
							PtrAdr(W, offset+off, type, fixadr)
						END;
						f := f.nextVar
					END
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
								FOR i := 0 TO n-1 DO PtrAdr(W, offset+i*size.size, base, fixadr) END
							END
						ELSE
							PCDebug.ToDo(PCDebug.NotImplemented);	(*find pointers in the array, call NewPtr for each one*)
						END
					END
				END
			END PtrAdr;

			PROCEDURE Pointers;
				VAR W: SectionWriter; p: PCT.Variable;
			BEGIN
				TypeAlign4(); desc.pointers := type.used;
				W := type.W; W.SetPos(type.used);
				p := mod.scope.firstVar;
				WHILE p # NIL DO
					IF ~(PCM.Untraced IN p.flags) THEN
						PtrAdr(W, var.head.VirtualSize + p.adr(PCBT.GlobalVariable).offset, p.type, TRUE)
					END;
					p := p.nextVar
				END;
				W.RawLInt(0); (* sentinel *)
				W.Update()
			END Pointers;

			PROCEDURE FixupVar(p: PCBT.GlobalVariable);
				VAR W: SectionWriter; R: SectionReader; l: PCBT.Fixup; offset, x: LONGINT;
			BEGIN
				W := code.W; R := code.R; l := p.link;
				WHILE l # NIL DO
					offset := l.offset*addressFactor;
					R.SetPos(offset); R.RawLInt(x);
					W.SetPos(offset);
					IF p.offset < 0 THEN (* var *)
						AddOfsReloc(code, offset, var);
						W.RawLInt(var.head.VirtualSize + x)
					ELSE (* const *)
						AddOfsReloc(code, offset, const);
						W.RawLInt(x)
					END;
					l := l.next
				END;
				W.Update()
			END FixupVar;

			PROCEDURE FixupOwnVars;
				VAR p: PCBT.GlobalVariable;
			BEGIN
				p := adr.OwnVars;
				WHILE p # PCBT.sentinel DO
					IF p.link # NIL THEN FixupVar(p) END;
					ASSERT(p.entryNo = PCBT.UndefEntryNo);
					p := p.next
				END
			END FixupOwnVars;

			PROCEDURE AddExport(sect: Section; ofs: LONGINT; name: ARRAY OF CHAR);
				VAR p, n, e: ExportObj;
			BEGIN
				p := NIL; n := exports;
				WHILE (n # NIL) & (n.name < name) DO
					p := n; n := n.next
				END;
				IF (n = NIL) OR (n.name > name) THEN
					NEW(e); COPY(name, e.name);
					e.sect := sect; e.ofs := ofs;
					e.next := n;
					IF p # NIL THEN
						p.next := e
					ELSE
						exports := e
					END
				ELSE
					HALT(99)
				END
			END AddExport;

			PROCEDURE ExportType(W: SectionWriter; t: PCT.Struct);
				VAR sym: PCOM.Struct; p: PCT.Proc; v: PCT.Variable; count, pos, bak: LONGINT;
			BEGIN
				WHILE (t IS PCT.Pointer) OR (t IS PCT.Array) DO
					IF t IS PCT.Pointer THEN t := t(PCT.Pointer).base ELSE t := t(PCT.Array).base END
				END;
				sym := t.sym(PCOM.Struct);
				IF (t IS PCT.Record) & ((sym.mod = NIL) OR (sym.mod = mod)) THEN
					WITH t: PCT.Record DO
						W.Char(EURecord);
						IF sym.uref # 0 THEN
							W.RawNum(-sym.uref)
						ELSE
							count := 0;
							INC(nofstr); sym.uref := nofstr;	(*remember it's exported*)
							W.RawNum(t.size(PCBT.RecSize).td.offset);	(* link address in the constant section*)
							pos := W.Pos(); W.RawInt(2);	(* number of entries *)
							ExportType(W, t.btyp);
							W.RawNum(sym.pbfp); W.RawNum(sym.pvfp);
							v := t.scope.firstVar;
							WHILE p # NIL DO
								IF v.vis # PCT.Internal THEN
									W.RawNum(v.sym(PCOM.Symbol).fp); ExportType(W, v.type); INC(count)
								END;
								v := v.nextVar
							END;
							p := t.scope.firstProc;
							WHILE p # NIL DO
								IF (p.vis # PCT.Internal) & (p # t.scope.body) THEN
									W.RawNum(p.sym(PCOM.Symbol).fp); INC(count)
								END;
								p := p.nextProc
							END;
							IF count # 0 THEN
								bak := W.Pos(); W.SetPos(pos);
								W.RawInt(SHORT(count+2));
								W.SetPos(bak)
							END;
							W.Char(EUEnd)
						END
					END
				END
			END ExportType;

			PROCEDURE ExportSymbol(W: SectionWriter; p: PCT.Symbol; sect: Section; ofs: LONGINT);
				VAR i, fp: LONGINT; name: Name; explist2: ExportFPList;
			BEGIN
				StringPool.GetString(p.name, name);
				fp := p.sym(PCOM.Symbol).fp;
				FOR i := 0 TO exppos-1 DO
					IF fp = explist[i] THEN PCM.ErrorN(280, Diagnostics.Invalid, p.name) END
				END;
				IF exppos >= explen THEN
					NEW(explist2, 2*explen);
					SYSTEM.MOVE(ADDRESSOF(explist[0]), ADDRESSOF(explist2[0]), 4*explen);
					explist := explist2; explen := 2*explen
				END;
				explist[exppos] := fp; INC(exppos);
				IF sect # NIL THEN AddExport(sect, ofs, name) END;
				W.RawNum(fp); W.RawNum(ofs);
				INC(count)
			END ExportSymbol;

			PROCEDURE ExportConsts(W: SectionWriter);
				VAR c: PCT.Value;
			BEGIN
				c := mod.scope.firstValue;
				WHILE c # NIL DO
					IF c.vis # PCT.Internal THEN
						IF (c.adr # NIL) & (c.adr IS PCBT.GlobalVariable) THEN
							ExportSymbol(W, c, const, c.adr(PCBT.GlobalVariable).offset)
						ELSE
							ExportSymbol(W, c, NIL, 0)
						END
					END;
					c := c.nextVal
				END
			END ExportConsts;

			PROCEDURE ExportVars(W: SectionWriter);
				VAR v: PCT.Variable;
			BEGIN
				v := mod.scope.firstVar;
				WHILE v # NIL DO
					IF v.vis # PCT.Internal THEN
						ExportSymbol(W, v, var, var.head.VirtualSize + v.adr(PCBT.GlobalVariable).offset);
						ExportType(W, v.type)
					END;
					v := v.nextVar
				END
			END ExportVars;

			PROCEDURE ExportTypes(W: SectionWriter);
				VAR t: PCT.Type;
			BEGIN
				t := mod.scope.firstType;
				WHILE t # NIL DO
					IF t.vis # PCT.Internal THEN
						ExportSymbol(W, t, NIL, 0);
						ExportType(W, t.type)
					END;
					t := t.nextType
				END
			END ExportTypes;

			PROCEDURE ExportProcs(W: SectionWriter);
				VAR p: PCT.Proc;
			BEGIN
				p := mod.scope.firstProc;
				WHILE p # NIL DO
					IF p.vis # PCT.Internal THEN
						ExportSymbol(W, p, code, p.adr(PCBT.Procedure).codeoffset);
					END;
					p := p.nextProc
				END
			END ExportProcs;

			PROCEDURE CheckExport(name: ARRAY OF CHAR);
				VAR e: ExportObj; idx: StringPool.Index; p: PCT.Proc;
			BEGIN
				e := exports;
				WHILE (e # NIL) & (e.name < name) DO
					e := e.next
				END;
				IF (e # NIL) & (e.name = name) THEN RETURN END;
				StringPool.GetIndex(name, idx);
				p := mod.scope.firstProc;
				WHILE (p # NIL) & (p.name # idx) DO
					p := p.nextProc
				END;
				ASSERT(p # NIL);
				AddExport(code, p.adr(PCBT.Procedure).codeoffset, name)
			END CheckExport;

			PROCEDURE Exports;
				VAR W: SectionWriter; i, pos: LONGINT;
			BEGIN
				TypeAlign4(); desc.exports := type.used;
				NEW(explist, 256); exppos := 0; explen := 256;
				nofstr := 0; count := 0; pos := type.used;
				W := type.W; W.SetPos(pos); W.RawInt(0);
				ExportConsts(W);
				ExportVars(W);
				ExportTypes(W);
				ExportProcs(W);
				IF count # 0 THEN
					i := W.Pos(); W.SetPos(pos);
					W.RawInt(SHORT(count));
					W.SetPos(i)
				END;
				W.Char(EUEnd);
				W.Update();
				IF name = Loader THEN
					CheckExport("DllMain"); CheckExport("WinMain")
				END;
				IF name = Heap THEN
					CheckExport("NewArr"); CheckExport("NewSys"); CheckExport("NewRec")
				END;
				IF name = Active THEN
					CheckExport("Unlock"); CheckExport("Lock"); CheckExport("Await"); CheckExport("CreateProcess")
				END
			END Exports;

			PROCEDURE UseEntry(W: SectionWriter; m: PCT.Module; p: PCT.Symbol; offset: LONGINT; imp: ImportMod): ImportObj;
				VAR name: Name;
			BEGIN
				StringPool.GetString(p.name, name);
				PCOM.FPrintObj(p, m);
				W.RawNum(p.sym(PCOM.Symbol).fp);
				W.RawString(name);
				W.RawNum(offset);
				IF imp # NIL THEN
					RETURN AddImportObj(imp, name)
				END;
				RETURN NIL
			END UseEntry;

			PROCEDURE UseType(W: SectionWriter; m: PCT.Module; i: LONGINT; t: PCT.Struct);
				VAR size: PCBT.RecSize; sym: PCOM.Struct; j: LONGINT;
			BEGIN
				LOOP
					IF t IS PCT.Pointer THEN t := t(PCT.Pointer).base
					ELSIF t IS PCT.Array THEN t := t(PCT.Array).base
					ELSE EXIT
					END
				END;
				IF ~(t IS PCT.Record) THEN RETURN END;
				WITH t: PCT.Record DO
					size := t.size(PCBT.RecSize);
					IF (size.td # NIL) THEN
						IF (t.scope.module = m) THEN
							sym := t.sym(PCOM.Struct);
							IF (t.owner # NIL) & (t.owner.sym = NIL) THEN PCOM.FPrintObj(t.owner, m) END;
							W.Char(EURecord);
							W.RawNum(-size.td.offset);
							IF t.pvused THEN
								W.RawNum(sym.pvfp);
								W.RawString("@");
							ELSIF t.pbused THEN
								W.RawNum(sym.pbfp);
								W.RawString("@")
							END;
							W.Char(EUEnd);
							size.td := NIL	(*avoid double tracing*)
						ELSE
								(* aliasing of imported type: schedule module for emission in use list *)
							j := i+1;
							LOOP
								IF j = LEN(mod.imports) THEN
									PCT.ExtendModArray(mod.imports);
									mod.imports[j] := t.scope.module;
									EXIT
								ELSIF mod.imports[j] = NIL THEN
									mod.imports[j] := t.scope.module;
									EXIT
								ELSIF mod.imports[j] = t.scope.module THEN
									EXIT
								END;
								INC(j)
							END
						END
					END
				END
			END UseType;

			PROCEDURE ImportConsts(W: SectionWriter; m: PCT.Module);
				VAR c: PCT.Value; obj: ImportObj;
			BEGIN
				c := m.scope.firstValue;
				WHILE c # NIL DO
					IF (PCT.used IN c.flags) & (c.vis # PCT.Internal) THEN obj := UseEntry(W, m, c, 0, NIL) END;
					EXCL(c.flags, PCT.used);
					c := c.nextVal
				END
			END ImportConsts;

			PROCEDURE ImportVars(W: SectionWriter; m: PCT.Module; i: LONGINT; imp: ImportMod);
				VAR
					p: PCBT.GlobalVariable; v: PCT.Variable; e: LONGINT; obj: ImportObj; nofVarCons: INTEGER;
					l: PCBT.Fixup; offset: LONGINT; F: SectionWriter;
			BEGIN
				nofVarCons := 1;
				p := adr.ExtVars;
				WHILE p # PCBT.sentinel DO
					IF p.link # NIL THEN
						p.entryNo := nofVarCons; INC(nofVarCons)
					END;
					p := p.next
				END;
				v := m.scope.firstVar;
				WHILE v # NIL DO
					e := v.adr(PCBT.GlobalVariable).entryNo;
					IF (e # PCBT.UndefEntryNo) THEN
						obj := UseEntry(W, m, v, e, imp); UseType(W, m, i, v.type);
						F := code.W;
						l := v.adr(PCBT.GlobalVariable).link;
						WHILE l # NIL DO
							offset := l.offset*addressFactor;
							F.SetPos(offset);
							AddImportReloc(code, offset, obj, FALSE, TRUE, SYSTEM.GET32(ADDRESSOF(code.data[offset])) # 0);
							l := l.next
						END;
						F.Update()
					END;
					v := v.nextVar
				END
			END ImportVars;

			PROCEDURE ImportTypes(W: SectionWriter; m: PCT.Module; i: LONGINT);
				VAR t: PCT.Type; obj: ImportObj;
			BEGIN
				t := m.scope.firstType;
				WHILE t # NIL DO
					IF (PCT.used IN t.flags) & (t.vis # PCT.Internal) THEN
						obj := UseEntry(W, m, t, 0, NIL); UseType(W, m, i, t.type)
					END;
					EXCL(t.flags, PCT.used);
					t := t.nextType
				END
			END ImportTypes;

			PROCEDURE ImportProcs(W: SectionWriter; m: PCT.Module; imp: ImportMod);
				VAR p: PCT.Proc; obj: ImportObj; l: PCBT.Fixup; offset: LONGINT; F: SectionWriter;
			BEGIN
				p := m.scope.firstProc;
				WHILE p # NIL DO
					IF (p.adr # NIL) & (p.adr(PCBT.Procedure).link # NIL) THEN
						obj := UseEntry(W, m, p, p.adr(PCBT.Procedure).link.offset + EUProcFlag, imp);
						F := code.W;
						l := p.adr(PCBT.Procedure).link;
						WHILE l # NIL DO
							offset := l.offset*addressFactor;
							F.SetPos(offset);
							IF code.data[offset-1] = 0E8X THEN	(* call instruction relative *)
								AddImportReloc(code, offset, obj, FALSE, FALSE, FALSE)
							ELSE
								AddImportReloc(code, offset, obj, FALSE, TRUE, FALSE)
							END;
							l := l.next
						END;
						F.Update()
					ELSIF (p.flags * {PCT.used, PCT.Inline} = {PCT.used, PCT.Inline}) & (p.vis # PCT.Internal) THEN
						obj := UseEntry(W, m, p, 0, NIL)
					END;
					p := p.nextProc
				END
			END ImportProcs;

			PROCEDURE Imports;
				VAR W: SectionWriter; m: PCT.Module; name: Name; i: LONGINT; imp: ImportMod;
			BEGIN
				TypeAlign4(); desc.imports := type.used;
				W := type.W; W.SetPos(type.used);
				IF mod.imports = NIL THEN W.Char(0X); W.Update(); RETURN END;
				i := 0;
				WHILE (i < LEN(mod.imports)) & (mod.imports[i] # NIL) DO
					m := mod.imports[i];
					ASSERT(m = m.scope.owner);
					StringPool.GetString(m.name, name);
					imp := AddImportMod(name);
					W.RawString(name);
					ImportConsts(W, m);
					ImportVars(W, m, i, imp);
					ImportTypes(W, m, i);
					ImportProcs(W, m, imp);
					W.Char(0X);
					INC(i)
				END;
				W.Char(0X);
				W.Update()
			END Imports;

			PROCEDURE WriteType(W: SectionWriter; rec: PCT.Record);
				VAR
					size: PCBT.RecSize; pos, i, oldmth: LONGINT; base: PCT.Record; m: PCT.Method;
					adr: PCBT.Method; bsym: PCOM.Struct; name, name2: Name;
					basenr: INTEGER; baseid, nofptrs: LONGINT;
			BEGIN
				PCT.GetTypeName(rec, name);
				size := rec.size(PCBT.RecSize);
				W.RawLInt(size.size);
				W.RawInt(SHORT(size.td.offset));
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
						IF bsym.mod # mod.scope.owner THEN basenr := SHORT(bsym.mod.adr(PCBT.Module).nr) END
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
				W.RawInt(basenr);
				W.RawLInt(baseid);
				W.RawInt(SHORT(size.nofMethods));	(*NofMethods*)
				W.RawInt(SHORT(oldmth));	(*InheritedMethods*)
				W.RawInt(SHORT(size.nofLocalMethods));	(*NewMethods*)
				pos := W.Pos();
				W.RawInt(0);
				W.RawString(name);

				(*New Methods in Record*)
				i := 0; m := rec.scope.firstMeth;
				WHILE m # NIL DO
					adr := m.adr(PCBT.Method);
					W.RawInt(SHORT(adr.mthNo));
					W.RawInt(SHORT(adr.entryNr));
					INC(i);
					m := m.nextMeth
				END;
				ASSERT(i = size.nofLocalMethods, 500);	(*sanity check*)

				(* Ptrs in Record *)
				i := W.Pos();
				PtrAdr(W, 0, rec, FALSE);
				nofptrs := (W.Pos() - i) DIV 4;
				IF nofptrs > MAX(INTEGER) THEN PCM.Error(221, Diagnostics.Invalid, "") END;
				IF nofptrs # 0 THEN
					i := W.Pos(); W.SetPos(pos);
					W.RawInt(SHORT(nofptrs));
					W.SetPos(i)
				END
			END WriteType;

			PROCEDURE Types;
				VAR W: SectionWriter; rec: PCT.Record;
			BEGIN
				TypeAlign4(); desc.types := type.used;
				W := type.W; W.SetPos(type.used);
				W.RawLInt(mod.scope.nofRecs);
				rec := mod.scope.records;
				WHILE rec # NIL DO
					IF PCT.interface IN rec.mode THEN
						HALT(99)
					ELSE
						WriteType(W, rec)
					END;
					rec := rec.link
				END;
				rec := mod.scope.records;
				WHILE rec # NIL DO
					rec.size(PCBT.RecSize).td := NIL;
					rec := rec.link
				END;
				W.Update()
			END Types;

			PROCEDURE PutName(W: SectionWriter; name: ARRAY OF CHAR);
			BEGIN
				W.RawString(name);
				IF (W.Pos() MOD 2) = 1 THEN W.Char(0X) END
			END PutName;

			PROCEDURE ModDesc;
				VAR W: SectionWriter; sect: Section; r: ImportReloc;
			BEGIN
				W := type.W; W.SetPos(type.used);
				W.RawLInt(0); (* hmod *)
				AddOfsReloc(type, W.Pos(), type); (* image base *)
				W.RawLInt(-BaseRVA);
				AddOfsReloc(type, W.Pos(), type);
				W.RawLInt(desc.modules);
				AddOfsReloc(type, W.Pos(), type);
				W.RawLInt(desc.commands);
				AddOfsReloc(type, W.Pos(), type);
				W.RawLInt(desc.methods);
				AddOfsReloc(type, W.Pos(), type);
				W.RawLInt(desc.pointers);
				AddOfsReloc(type, W.Pos(), type);
				W.RawLInt(desc.exports);
				AddOfsReloc(type, W.Pos(), type);
				W.RawLInt(desc.imports);
				AddOfsReloc(type, W.Pos(), type);
				W.RawLInt(desc.types);
				IF var # NIL THEN
					AddOfsReloc(type, W.Pos(), var)
				ELSE
					AddOfsReloc(type, W.Pos(), const)
				END;
				W.RawLInt(0);
				AddOfsReloc(type, W.Pos(), const);
				W.RawLInt(const.used-1);
				AddOfsReloc(type, W.Pos(), code);
				W.RawLInt(0);
				AddOfsReloc(type, W.Pos(), code);
				W.RawLInt(code.used-1);
				AddOfsReloc(type, W.Pos(), const); (* SB *)
				W.RawLInt(0);
				AddOfsReloc(type, W.Pos(), idata);
				W.RawLInt(0);
				AddOfsReloc(type, W.Pos(), edata);
				W.RawLInt(0);
				desc.iatfix := W.Pos();
				sect := sects;
				WHILE sect # NIL DO
					r := sect.imports;
					WHILE r # NIL DO
						IF ~r.iat THEN
							W.RawInt(0); W.RawLInt(0); W.RawLInt(0)
						END;
						r := r.next
					END;
					sect := sect.next
				END;
				W.RawInt(-1); W.RawLInt(0); W.RawLInt(0);
				W.Update()
			END ModDesc;

			PROCEDURE IATFix;
				VAR W: SectionWriter; sect: Section; r: ImportReloc;
			BEGIN
				W := type.W; W.SetPos(desc.iatfix);
(*
	iat fixup table
		mode	code-ofs
		iat address
	mode
		0: uofs
		1: abs
		2: 0 = code / 1 = data
		15: end
*)
				sect := sects;
				WHILE sect # NIL DO
					r := sect.imports;
					WHILE r # NIL DO
						IF ~r.iat THEN
							IF sect = code THEN
								IF r.abs THEN
									IF r.uofs THEN
										W.RawInt(3)
									ELSE
										W.RawInt(2)
									END
								ELSE
									ASSERT(~r.uofs);
									W.RawInt(0)
								END;
								AddOfsReloc(type, W.Pos(), code);
								W.RawLInt(r.ofs);
								AddOfsReloc(type, W.Pos(), idata);
								W.RawLInt(r.obj.iat - idata.head.VirtualAddress)
							ELSE
								HALT(99)
							END
						END;
						r := r.next
					END;
					sect := sect.next
				END;
				W.RawInt(-1); W.RawLInt(0); W.RawLInt(0);
				W.Update()
			END IATFix;

			PROCEDURE GenStub;
				VAR
					W: SectionWriter; loader: ImportMod; obj: ImportObj;
					p: PCT.Proc; idx: StringPool.Index; main: ARRAY 8 OF CHAR;
			BEGIN
				optHdr.AddressOfEntryPoint := code.used;
(* EBX, ESI, EDI are caller saved, EAX & ECX are used for stack init *)
				W := code.W; W.SetPos(code.used);
				W.Char(0BAX); (* MOV EDX, mod *)
				TypeAlign4();
				AddOfsReloc(code, W.Pos(), type);
				W.RawLInt(type.used); (* ModDesc *)
				IF name # Loader THEN
					loader := AddImportMod(Loader);
					W.Char(0FFX); W.Char(025X); (* JMP Main *)
					IF mode = ModeDLL THEN
						obj := AddImportObj(loader, "DllMain")
					ELSIF mode = ModeEXE THEN
						obj := AddImportObj(loader, "WinMain")
					ELSE
						HALT(99)
					END;
					AddImportReloc(code, W.Pos(), obj, TRUE, TRUE, FALSE);
					W.RawLInt(0)
				ELSE
					ASSERT(mode = ModeDLL);
					main := "DllMain";
					StringPool.GetIndex(main, idx);
					p := mod.scope.firstProc;
					WHILE (p # NIL) & (p.name # idx) DO
						p := p.nextProc
					END;
					ASSERT(p # NIL);
					W.Char(0E9X); (* JMP Main *)
					W.RawLInt(p.adr(PCBT.Procedure).codeoffset-(W.Pos()+4))
				END;
				W.Update();
				ModDesc()
			END GenStub;

			PROCEDURE GenIData(base: LONGINT);
				VAR W: SectionWriter; p, mod: ImportMod; obj: ImportObj; sect: Section; r: ImportReloc; i, j, ofs: LONGINT;
			BEGIN
				IF name # Loader THEN
					p := NIL; mod := imports;
					WHILE (mod # NIL) & (mod.name # Loader) DO
						p := mod; mod := mod.next
					END;
					ASSERT(mod # NIL);
					IF p # NIL THEN
						p.next := mod.next;
						mod.next := imports;
						imports := mod
					END
				END;
				idata.head.VirtualAddress := base;
				optHdr.DataDirectory[ImageDirectoryEntryImport].VirtualAddress := base;
				W := idata.W; W.SetPos(0);
				mod := imports;
				WHILE mod # NIL DO
					WriteImageImportDescriptor(W, mod.desc);
					mod := mod.next
				END;
				i := 0;
				WHILE i < SIZEOF(ImageImportDescriptor) DO
					W.Char(0X); INC(i)
				END;
				optHdr.DataDirectory[ImageDirectoryEntryImport].Size := W.Pos();
				mod := imports;
				WHILE mod # NIL DO
					mod.desc.Characteristics := W.Pos();
					obj := mod.objs;
					WHILE obj # NIL DO
						W.RawLInt(0); obj := obj.next
					END;
					W.RawLInt(0);
					mod := mod.next
				END;
				ofs := W.Pos();
				optHdr.DataDirectory[ImageDirectoryEntryIAT].VirtualAddress := base + ofs;
				mod := imports;
				WHILE mod # NIL DO
					mod.desc.FirstThunk := W.Pos();
					obj := mod.objs;
					WHILE obj # NIL DO
						W.RawLInt(0); obj := obj.next
					END;
					W.RawLInt(0);
					mod := mod.next
				END;
				W.Update();
				optHdr.DataDirectory[ImageDirectoryEntryIAT].Size := W.Pos() - ofs;
				mod := imports; i := 0;
				WHILE mod # NIL DO
					obj := mod.objs; j := 0;
					WHILE obj # NIL DO
						W.SetPos(mod.desc.Characteristics + j);
						W.RawLInt(base + idata.used);
						W.SetPos(mod.desc.FirstThunk + j);
						obj.iat := base + mod.desc.FirstThunk + j;
						W.RawLInt(base + idata.used);
						W.SetPos(idata.used);
						W.RawInt(0);
						PutName(W, obj.name);
						obj := obj.next; INC(j, 4)
					END;
					W.Update();
					mod.desc.Characteristics := base + mod.desc.Characteristics;
					mod.desc.Name := base + idata.used;
					mod.desc.FirstThunk := base + mod.desc.FirstThunk;
					W.SetPos(i);
					WriteImageImportDescriptor(W, mod.desc);
					W.SetPos(idata.used);
					PutName(W, mod.name);
					W.Update();
					mod := mod.next; INC(i, SIZEOF(ImageImportDescriptor))
				END;
				sect := sects;
				WHILE sect # NIL DO
					r := sect.imports;
					WHILE r # NIL DO
						IF r.iat THEN
							ASSERT(r.abs & ~r.uofs);
							AddOfsReloc(sect, r.ofs, idata);
							W := sect.W; W.SetPos(r.ofs);
							W.RawLInt(r.obj.iat - base)
						END;
						r := r.next
					END;
					sect := sect.next
				END;
				W.Update()
			END GenIData;

			PROCEDURE GenEData(base: LONGINT);
				VAR W: SectionWriter; dir: ImageExportDirectory; e: ExportObj; fix, i, n: LONGINT;
			BEGIN
				edata.head.VirtualAddress := base;
				optHdr.DataDirectory[ImageDirectoryEntryExport].VirtualAddress := base;
				e := exports; n := 0;
				WHILE e # NIL DO
					e := e.next; INC(n)
				END;
				dir.Characteristics := 0;
				dir.TimeDateStamp := fileHdr.TimeDateStamp;
				dir.MajorVersion := 0;
				dir.MinorVersion := 0;
				dir.Name := 0;
				dir.Base := 1;
				dir.NumberOfFunctions := n;
				dir.NumberOfNames := n;
				dir.AddressOfFunctions := 0;
				dir.AddressOfNames := 0;
				dir.AddressOfNameOrdinals := 0;
				W := edata.W; W.SetPos(0);
				WriteImageExportDirectory(W, dir);
				dir.AddressOfFunctions := base + W.Pos();
				e := exports;
				WHILE e # NIL DO
					W.RawLInt(e.sect.head.VirtualAddress + e.ofs);
					e := e.next
				END;
				dir.AddressOfNames := base + W.Pos();
				fix := W.Pos(); i := 0;
				WHILE i < n DO
					W.RawLInt(0); INC(i)
				END;
				dir.AddressOfNameOrdinals := base + W.Pos();
				i := 0;
				WHILE i < n DO
					W.RawInt(SHORT(i)); INC(i)
				END;
				dir.Name := base + W.Pos();
				PutName(W, name);
				e := exports;
				WHILE e # NIL DO
					W.SetPos(fix);
					W.RawLInt(base + edata.used);
					W.SetPos(edata.used);
					PutName(W, e.name);
					W.Update();
					e := e.next; INC(fix, 4)
				END;
				W.SetPos(0);
				WriteImageExportDirectory(W, dir);
				W.Update();
				optHdr.DataDirectory[ImageDirectoryEntryExport].Size := edata.used
			END GenEData;

			PROCEDURE BeginBlock(W: SectionWriter; adr: LONGINT; VAR blockva, blocksize, blockfix: LONGINT);
			BEGIN
				blockva := adr - (adr MOD PageSize); blocksize := 8;
				W.RawLInt(blockva);
				blockfix := W.Pos();
				W.RawLInt(blocksize)
			END BeginBlock;

			PROCEDURE EndBlock(W: SectionWriter; blockfix: LONGINT; VAR blocksize: LONGINT);
				VAR ofs: LONGINT;
			BEGIN
				W.RawInt(0); INC(blocksize, 2);
				IF (blocksize MOD 4) # 0 THEN
					W.RawInt(0); INC(blocksize, 2)
				END;
				ofs := W.Pos(); W.SetPos(blockfix);
				W.RawLInt(blocksize);
				W.SetPos(ofs)
			END EndBlock;

			PROCEDURE LocalRelocs;
				VAR W: SectionWriter; R: SectionReader; sect: Section; r: BaseReloc; x: LONGINT;
			BEGIN
				sect := sects;
				WHILE sect # NIL DO
					W := sect.W; R := sect.R;
					r := sect.relocs;
					WHILE r # NIL DO
						R.SetPos(r.ofs);
						R.RawLInt(x);
						W.SetPos(r.ofs);
						W.RawLInt(x + optHdr.ImageBase + r.base.head.VirtualAddress);
						r := r.next
					END;
					W.Update();
					sect := sect.next
				END
			END LocalRelocs;

			PROCEDURE GenReloc(base: LONGINT);
				VAR
					W: SectionWriter; sect: Section; r: BaseReloc;
					blockva, blocksize, blockfix, bak, x: LONGINT;
			BEGIN
				reloc.head.VirtualAddress := base;
				optHdr.DataDirectory[ImageDirectoryEntryBasereloc].VirtualAddress := base;
				LocalRelocs();
				blockva := BaseRVA-PageSize; blocksize := 0; blockfix := -1;
				W := reloc.W;
				bak := 0; sect := sects;
				WHILE sect # NIL DO
					r := sect.relocs;
					WHILE r # NIL DO
						x := sect.head.VirtualAddress + r.ofs;
						ASSERT(x > bak);
						IF x >= (blockva+PageSize) THEN
							IF blockfix >= 0 THEN EndBlock(W, blockfix, blocksize) END;
							BeginBlock(W, x, blockva, blocksize, blockfix)
						END;
						bak := x; DEC(x, blockva);
						W.RawInt(SHORT(x + LSH(SYSTEM.VAL(LONGINT, ImageRelBasedHighLow), 12)));
						INC(blocksize, 2);
						r := r.next
					END;
					sect := sect.next
				END;
				IF blockfix >= 0 THEN EndBlock(W, blockfix, blocksize) END;
				W.Update();
				optHdr.DataDirectory[ImageDirectoryEntryBasereloc].Size := reloc.used
			END GenReloc;

			PROCEDURE ToFile;
				VAR file: Files.FileName; F: Files.File; W: Files.Writer; sect: Section; i, size: LONGINT; s: SET;
			BEGIN
				IF PCM.prefix # "" THEN
					COPY(PCM.prefix, file);
					Strings.Append(file, name)
				ELSE
					COPY(name, file)
				END;
				IF mode = ModeEXE THEN
					Strings.Append(file, ".EXE")
				ELSIF mode = ModeDLL THEN
					Strings.Append(file, ".DLL")
				ELSE
					HALT(99)
				END;
KernelLog.String("PCOFPE "); KernelLog.String(file);
				SELF.optHdr.BaseOfCode := SELF.code.head.VirtualAddress;
				F := Files.New(file);
				Files.OpenWriter(W, F, 0);
				W.RawInt(ImageDosSignature);
				i := W.Pos(); WHILE i < 60 DO W.Char(0X); INC(i) END;
				W.RawLInt(128);
				i := W.Pos(); WHILE i < 128 DO W.Char(0X); INC(i) END;
				size := 128 + 4 + SIZEOF(ImageFileHeader) + SIZEOF(ImageOptionalHeader) + SELF.fileHdr.NumberOfSections*SIZEOF(ImageSectionHeader);
				size := Align(size, DefaultFileAlign);
				SELF.optHdr.SizeOfHeaders := size;
				size := Align(size, DefaultSectionAlign);
				sect := SELF.sects;
				WHILE sect # NIL DO
					s := SYSTEM.VAL(SET, sect.head.Characteristics);
					IF ImageScnCntCode IN s THEN
						INC(SELF.optHdr.SizeOfCode, Align(sect.head.VirtualSize, DefaultSectionAlign))
					ELSIF ImageScnCntInitializedData IN s THEN
						INC(SELF.optHdr.SizeOfInitializedData, Align(sect.head.VirtualSize, DefaultSectionAlign))
					ELSE
						INC(SELF.optHdr.SizeOfUninitializedData, Align(sect.head.VirtualSize, DefaultSectionAlign))
					END;
					INC(size, Align(sect.head.VirtualSize, DefaultSectionAlign));
					sect := sect.next
				END;
				SELF.optHdr.SizeOfImage := size;
				W.RawLInt(ImageNtSignature);
				WriteImageFileHeader(W, SELF.fileHdr);
				WriteImageOptionalHeader(W, SELF.optHdr);
				i := SELF.optHdr.SizeOfHeaders;
				sect := SELF.sects;
				WHILE sect # NIL DO
					IF sect.used > 0 THEN
						ASSERT(sect.head.VirtualSize = sect.used);
						sect.head.SizeOfRawData := Align(sect.used, DefaultFileAlign);
						sect.head.PointerToRawData := i; INC(i, sect.head.SizeOfRawData)
					ELSE
						sect.head.SizeOfRawData := 0; sect.head.PointerToRawData := 0
					END;
					WriteImageSectionHeader(W, sect.head);
					sect := sect.next
				END;
				i := W.Pos(); WHILE i < SELF.optHdr.SizeOfHeaders DO W.Char(0X); INC(i) END;
				sect := SELF.sects;
				WHILE sect # NIL DO
					IF sect.head.SizeOfRawData > 0 THEN
						W.Bytes(sect.data^, 0, sect.used);
						i := sect.used;
						WHILE i < sect.head.SizeOfRawData DO W.Char(0X); INC(i) END
					END;
					sect := sect.next
				END;
				W.Update();
				Files.Register(F)
;KernelLog.String(" "); KernelLog.Int(F.Length(), 0); KernelLog.Ln()
			END ToFile;

			PROCEDURE &New*(mod: PCT.Module; adr: PCBT.Module);
				VAR i: LONGINT; s: SET;
			BEGIN
				SELF.mod := mod; SELF.adr := adr;
				SELF.fileHdr.Machine := ImageFileMachineI386;
				SELF.fileHdr.NumberOfSections := 0;
				SELF.fileHdr.TimeDateStamp := TimeDateStamp();
				SELF.fileHdr.PointerToSymbolTable := 0;
				SELF.fileHdr.NumberOfSymbols := 0;
				SELF.fileHdr.SizeOfOptionalHeader := SIZEOF(ImageOptionalHeader);
				s := {ImageFileExecutableImage, ImageFile32BitMachine, ImageFileLineNumsStripped, ImageFileLocalSymsStripped};
				IF mode = ModeEXE THEN
					INCL(s, ImageFileRelocsStripped)
				ELSIF mode = ModeDLL THEN
					INCL(s, ImageFileDll)
				ELSE
					HALT(99)
				END;
				SELF.fileHdr.Characteristics := SYSTEM.VAL(INTEGER, s);
				SELF.optHdr.Magic := ImageOptionalMagic;
				SELF.optHdr.MajorLinkerVersion := MajorLinkerVersion;
				SELF.optHdr.MinorLinkerVersion := MinorLinkerVersion;
				SELF.optHdr.SizeOfCode := 0;
				SELF.optHdr.SizeOfInitializedData := 0;
				SELF.optHdr.SizeOfUninitializedData := 0;
				SELF.optHdr.AddressOfEntryPoint := 0;
				SELF.optHdr.BaseOfCode := 0;
				SELF.optHdr.BaseOfData := 0;
				IF mode = ModeEXE THEN
					SELF.optHdr.ImageBase := EXEImageBase
				ELSIF mode = ModeDLL THEN
					SELF.optHdr.ImageBase := DLLImageBase
				ELSE
					HALT(99)
				END;
				SELF.optHdr.SectionAlignment := DefaultSectionAlign;
				SELF.optHdr.FileAlignment := DefaultFileAlign;
				SELF.optHdr.MajorOperatingSystemVersion := 4;
				SELF.optHdr.MinorOperatingSystemVersion := 0;
				SELF.optHdr.MajorImageVersion := 0;
				SELF.optHdr.MinorImageVersion := 0;
				SELF.optHdr.MajorSubsystemVersion := 4;
				SELF.optHdr.MinorSubsystemVersion := 0;
				SELF.optHdr.Win32VersionValue := 0;
				SELF.optHdr.SizeOfImage := 0;
				SELF.optHdr.SizeOfHeaders := 0;
				SELF.optHdr.CheckSum := 0;
				IF mode = ModeEXE THEN
					SELF.optHdr.Subsystem := SHORT(subsystem)
				ELSIF mode = ModeDLL THEN
					SELF.optHdr.Subsystem := ImageSubsystemUnknown
				ELSE
					HALT(99)
				END;
				SELF.optHdr.DllCharacteristics := 0;
				SELF.optHdr.SizeOfStackReserve := DefaultStackSize;
				SELF.optHdr.SizeOfStackCommit := PageSize;
				SELF.optHdr.SizeOfHeapReserve := DefaultHeapSize;
				SELF.optHdr.SizeOfHeapCommit := PageSize;
				SELF.optHdr.LoaderFlags := 0;
				SELF.optHdr.NumberOfRvaAndSizes := ImageNumberOfDirectoryEntries;
				i := 0;
				WHILE i < ImageNumberOfDirectoryEntries DO
					SELF.optHdr.DataDirectory[i].VirtualAddress := 0;
					SELF.optHdr.DataDirectory[i].Size := 0;
					INC(i)
				END;
				SELF.sects := NIL; SELF.exports := NIL; SELF.imports := NIL;
				NEW(SELF.type, SELF, ".type", {ImageScnCntInitializedData, ImageScnMemRead, ImageScnMemWrite});
				IF adr.locsize > 0 THEN
					NEW(SELF.var, SELF, ".var", {ImageScnMemRead, ImageScnMemWrite})
				ELSE
					SELF.var := NIL
				END;
				NEW(SELF.const, SELF, ".const", {ImageScnCntInitializedData, ImageScnMemRead, ImageScnMemWrite});
				NEW(SELF.code, SELF, ".code", {ImageScnCntCode, ImageScnMemRead, ImageScnMemWrite, ImageScnMemExecute});
				NEW(SELF.idata, SELF, ".idata", {ImageScnCntInitializedData, ImageScnMemRead});
				NEW(SELF.edata, SELF, ".edata", {ImageScnCntInitializedData, ImageScnMemRead});
				IF mode = ModeDLL THEN
					NEW(SELF.reloc, SELF, ".reloc", {ImageScnCntInitializedData, ImageScnMemDiscardable, ImageScnMemRead})
				ELSE
					SELF.reloc := NIL
				END;

			END New;
		END PEModule;

	VAR
		mode: LONGINT; (* ModeDef, ModeDLL, ModeEXE *)
		subsystem: LONGINT; (* ImageSubsystemWindowsCui, ImageSubsystemWindowsGui *)

	PROCEDURE WriteImageFileHeader(W: Streams.Writer; VAR head: ImageFileHeader);
	BEGIN
		W.RawInt(head.Machine);
		W.RawInt(head.NumberOfSections);
		W.RawLInt(head.TimeDateStamp);
		W.RawLInt(head.PointerToSymbolTable);
		W.RawLInt(head.NumberOfSymbols);
		W.RawInt(head.SizeOfOptionalHeader);
		W.RawInt(head.Characteristics)
	END WriteImageFileHeader;

	PROCEDURE WriteImageOptionalHeader(W: Streams.Writer; VAR head: ImageOptionalHeader);
		VAR i: LONGINT;
	BEGIN
		W.RawInt(head.Magic);
		W.Char(head.MajorLinkerVersion);
		W.Char(head.MinorLinkerVersion);
		W.RawLInt(head.SizeOfCode);
		W.RawLInt(head.SizeOfInitializedData);
		W.RawLInt(head.SizeOfUninitializedData);
		W.RawLInt(head.AddressOfEntryPoint);
		W.RawLInt(head.BaseOfCode);
		W.RawLInt(head.BaseOfData);
		W.RawLInt(head.ImageBase);
		W.RawLInt(head.SectionAlignment);
		W.RawLInt(head.FileAlignment);
		W.RawInt(head.MajorOperatingSystemVersion);
		W.RawInt(head.MinorOperatingSystemVersion);
		W.RawInt(head.MajorImageVersion);
		W.RawInt(head.MinorImageVersion);
		W.RawInt(head.MajorSubsystemVersion);
		W.RawInt(head.MinorSubsystemVersion);
		W.RawLInt(head.Win32VersionValue);
		W.RawLInt(head.SizeOfImage);
		W.RawLInt(head.SizeOfHeaders);
		W.RawLInt(head.CheckSum);
		W.RawInt(head.Subsystem);
		W.RawInt(head.DllCharacteristics);
		W.RawLInt(head.SizeOfStackReserve);
		W.RawLInt(head.SizeOfStackCommit);
		W.RawLInt(head.SizeOfHeapReserve);
		W.RawLInt(head.SizeOfHeapCommit);
		W.RawLInt(head.LoaderFlags);
		W.RawLInt(head.NumberOfRvaAndSizes);
		i := 0;
		WHILE i < ImageNumberOfDirectoryEntries DO
			W.RawLInt(head.DataDirectory[i].VirtualAddress);
			W.RawLInt(head.DataDirectory[i].Size);
			INC(i)
		END
	END WriteImageOptionalHeader;

	PROCEDURE WriteImageSectionHeader(W: Streams.Writer; VAR head: ImageSectionHeader);
	BEGIN
		W.Bytes(head.Name, 0, ImageSizeOfShortName);
		W.RawLInt(head.VirtualSize);
		W.RawLInt(head.VirtualAddress);
		W.RawLInt(head.SizeOfRawData);
		W.RawLInt(head.PointerToRawData);
		W.RawLInt(head.PointerToRelocations);
		W.RawLInt(head.PointerToLinenumbers);
		W.RawInt(head.NumberOfRelocations);
		W.RawInt(head.NumberOfLinenumbers);
		W.RawSet(head.Characteristics)
	END WriteImageSectionHeader;

	PROCEDURE WriteImageImportDescriptor(W: Streams.Writer; VAR desc: ImageImportDescriptor);
	BEGIN
		W.RawLInt(desc.Characteristics);
		W.RawLInt(desc.TimeDateStamp);
		W.RawLInt(desc.ForwarderChain);
		W.RawLInt(desc.Name);
		W.RawLInt(desc.FirstThunk)
	END WriteImageImportDescriptor;

	PROCEDURE WriteImageExportDirectory(W: Streams.Writer; VAR dir: ImageExportDirectory);
	BEGIN
		W.RawLInt(dir.Characteristics);
		W.RawLInt(dir.TimeDateStamp);
		W.RawInt(dir.MajorVersion);
		W.RawInt(dir.MinorVersion);
		W.RawLInt(dir.Name);
		W.RawLInt(dir.Base);
		W.RawLInt(dir.NumberOfFunctions);
		W.RawLInt(dir.NumberOfNames);
		W.RawLInt(dir.AddressOfFunctions);
		W.RawLInt(dir.AddressOfNames);
		W.RawLInt(dir.AddressOfNameOrdinals)
	END WriteImageExportDirectory;

	PROCEDURE TimeDateStamp(): LONGINT;
		(* number of seconds since 1.1.1970 UTC *)
		VAR now: Dates.DateTime; A: ARRAY 12 OF LONGINT; y, days: LONGINT;
	BEGIN
		now := Dates.Now();
		ASSERT((now.year >= 1970) & (now.year < 2100));
		A[0] := 0; A[1] := 31; A[2] := 59; A[3] := 90; A[4] := 120; A[5] := 151; A[6] := 181;
		A[7] := 212; A[8] := 243; A[9] := 273; A[10] := 304; A[11] := 334;
		y := now.year - 1970;
		days := y*365 + (y DIV 4) + A[now.month-1] + now.day - 1;
		IF Dates.LeapYear(now.year) & (now.month > 2) THEN INC(days) END;
		RETURN now.second + 60*(now.minute - Clock.tz + 60*(now.hour + 24*days))
	END TimeDateStamp;

	PROCEDURE AddOfsReloc(sect: Section; ofs: LONGINT; base: Section);
		(* value at sect:ofs must be relocated to base + value *)
		VAR p, r, n: BaseReloc;
	BEGIN
		p := NIL; r := sect.relocs;
		WHILE (r # NIL) & (r.ofs < ofs) DO
			p := r; r := r.next
		END;
		ASSERT((p = NIL) OR (p.ofs < ofs));
		ASSERT((r = NIL) OR (r.ofs > ofs));
		NEW(n); n.next := r; n.base := base; n.ofs := ofs;
		IF p # NIL THEN p.next := n ELSE sect.relocs := n END
	END AddOfsReloc;

	PROCEDURE AddImportObj(mod: ImportMod; name: ARRAY OF CHAR): ImportObj;
		VAR p, n, obj: ImportObj;
	BEGIN
		p := NIL; n := mod.objs;
		WHILE (n # NIL) & (n.name < name) DO
			p := n; n := n.next
		END;
		IF (n = NIL) OR (n.name > name) THEN
			NEW(obj); COPY(name, obj.name); obj.iat := 0; obj.next := n;
			IF p # NIL THEN p.next := obj ELSE mod.objs := obj END;
			RETURN obj
		ELSE
			RETURN n
		END
	END AddImportObj;

	PROCEDURE AddImportReloc(sect: Section; offset: LONGINT; obj: ImportObj; iat, abs, ofs: BOOLEAN);
		(*
			value at sect:ofs must be fixed up to iat[obj]
			iat = TRUE	iat relative
			iat = FALSE	absolute, copy value from iat table
		*)
		VAR p, i, n: ImportReloc;
	BEGIN
		ASSERT((iat & abs & ~ofs) OR (~iat & (abs OR ~ofs)));
		p := NIL; i := sect.imports;
		WHILE (i # NIL) & (i.ofs < offset) DO
			p := i; i := i.next
		END;
		ASSERT((p = NIL) OR (p.ofs < offset));
		ASSERT((i = NIL) OR (i.ofs > offset));
		NEW(n); n.next := i; n.ofs := offset; n.obj := obj; n.iat := iat;
		n.abs := abs; n.uofs := ofs;
		IF p # NIL THEN p.next := n ELSE sect.imports := n END
	END AddImportReloc;

	PROCEDURE Align(value, align: LONGINT): LONGINT;
	BEGIN
		RETURN value + ((align-(value MOD align)) MOD align)
	END Align;

	PROCEDURE Generate*(VAR R: PCM.Rider; scope: PCT.ModScope; VAR codeSize: LONGINT);
		VAR pe: PEModule; base: LONGINT; W: SectionWriter;
	BEGIN
		PCM.CloseObj(R); (* write symbol only object file *)
		NEW(pe, scope.owner, scope.owner.adr(PCBT.Module)); base := BaseRVA;
		StringPool.GetString(pe.mod.name, pe.name);
		PCLIR.CG.GetCode(pe.codearr, codeSize, pe.hdrCodeSize, pe.addressFactor);
		W := pe.const.W; W.SetPos(0);
		W.Bytes(pe.adr.const^, 0, pe.adr.constsize);
		W.Update();
		W := pe.code.W; W.SetPos(0);
		W.Bytes(pe.codearr^, 0, codeSize);
		W.Update();
		IF pe.var # NIL THEN
			(* var: padding for proper sb offsets *)
			pe.var.head.VirtualSize := Align(pe.adr.locsize, PageSize)
		END;
		pe.FixupLinks(); (* InsertFixupLists:, LinkBlock only SysCalls & Case *)
(*
	CollectInfo: to do: ref block
*)
		pe.Commands(); (* CollectInfo, CommandBlock *)
		pe.UseModules(); (* CollectInfo, ImportBlock *)
		pe.FixupOwnProcs(); (* EntryBlock, LinkBlock: entries only for methods *)
		pe.Pointers(); (* PointerBlock *)
		pe.FixupOwnVars(); (* VarConsBlock: only OwnVars *)
		pe.Exports(); (* ExportBlock *)
		pe.Imports(); (* UseBlock, InsertFixupLists, VarConsBlock *)
		pe.Types(); (* TypeBlock *)
		pe.GenStub();
		pe.type.SetBase(base);
		IF pe.var # NIL THEN
			pe.var.SetBase(base)
		END;
		pe.const.SetBase(base);
		INC(pe.optHdr.AddressOfEntryPoint, base);
		pe.code.SetBase(base);
		pe.GenIData(base);
		pe.IATFix();
		pe.idata.SetBase(base);
		pe.GenEData(base);
		pe.edata.SetBase(base);
		IF mode = ModeDLL THEN
			pe.GenReloc(base);
			pe.reloc.SetBase(base)
		ELSE
			pe.LocalRelocs()
		END;
		pe.ToFile()
	END Generate;

	PROCEDURE SetDLL*;
	BEGIN
		mode := ModeDLL;
	END SetDLL;

	PROCEDURE SetEXE*;
	BEGIN
		mode := ModeEXE;
	END SetEXE;

	PROCEDURE SetCUI*;
	BEGIN
		subsystem := ImageSubsystemWindowsCui;
	END SetCUI;

	PROCEDURE SetGUI*;
	BEGIN
		subsystem := ImageSubsystemWindowsGui;
	END SetGUI;

	PROCEDURE Install*;
	BEGIN
		PCBT.generate := Generate
	END Install;

BEGIN
	mode := ModeDLL;
	subsystem := ImageSubsystemWindowsCui
END PCOFPE.

System.Free PCOFPE ~

PC.Compile \s \.Syw \FPE *	PC.Compile \s \.Syw \FPE \X *
