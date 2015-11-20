MODULE FoxBinaryObjectFile; (** AUTHOR "fof"; PURPOSE "Oberon Compiler Object File Writer"; *)

IMPORT
	Scanner := FoxScanner, Basic := FoxBasic, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, SemanticChecker := FoxSemanticChecker, FingerPrinter := FoxFingerPrinter, Sections := FoxSections,
	Streams, D := Debugging, Files, SYSTEM,Strings, BinaryCode := FoxBinaryCode, KernelLog, Diagnostics, SymbolFileFormat := FoxBinarySymbolFile, Options,
	Formats := FoxFormats, IntermediateCode := FoxIntermediateCode, Machine
	;

(** Object File Format
	ObjectFile       =  ofFileTag ofNoZeroCompression ofFileVersion
	                    symbolFileSize:RawLInt SymbolFile
	                    Header Entries Commands  Pointers Imports VarConstLinks
	                    Links Constants Exports Code Use Types
	                    ExceptionTable PtrsInProcBlock References.

	SymbolFile        = {Char}:symbolFileSize

	Header            = refSize:RawLInt numberEntries:RawLInt numberCommands:RawLInt
	                    numberPointers:RawLInt numberTypes:RawLInt numberImports:RawLInt
	                    numberVarConstLinks:RawLInt numberLinks:RawLInt dataSize:RawLInt
	                    constSize:RawLInt codeSize:RawLInt exTableLen:RawLInt numberProcs:RawLInt
	                    maxPtrs:RawLInt typeDescSize:RawLInt crc:RawLInt moduleName:RawString

	Entries           = 82X:Char { entryOffset:RawNum }:numberEntries

	Commands          = 83X:Char { firstParTypeOfs:RawNum returnTypeOfs:RawNum
	                             commandName:RawString cmdOffset:RawNum }:numberCommands

	Pointers          = 84X {pointerOffset:RawNum}:numberPointers

	Imports           = 85X { moduleName:String }:numberImports

	VarConstLinks     = 8DX { VarConstLinkEntry }:numberVarConstLinks
	VarConstLinkEntry = modNumber:Char entry:RawNum
	                    fixupCount:RawLInt { offset:RawNum }:fixupCount

	Links             = 86X {LinkEntry}:numberLinks {fixupCount:RawNum}:numberEntries
	                    caseTableSize:RawNum
	LinkEntry         = moduleNumber:Char entryNumber:Char offset:RawNum

	Constants         = 87X {character:Char}:constSize

	Exports           = 88X numberExports:RawLInt {ExportEntry}:numberExpor
	ExportEntry       = fingerPrint:RawNum offset:RawNum [1X ExportType]
	ExportType        = reference<0:RawNum
	                    | typeDescriptorOffset:RawNum numberEntries:RawLInt [1X ExportType]
	                      {fingerPrint:RawNum [1X ExportType]}:numberEntries 0X

	Code              = 89X {character:Char}:codeSize

	Use               = 08AX {UsedModules} 0X
	UsedModules       = moduleName:RawString {UsedEntry} 0X
	UsedEntry         = fingerPrint:RawNum name:RawString number:RawNum [1X UsedType]
	UsedType          = typeDescOfs:RawNum [fingerPrint:RawNum "@"] 0X

	Types             = 08BX {TypeEntry}:numberTypes
	TypeEntry         = recordSize:RawNum entry:RawNum
	                    baseModule:RawNum baseEntry:RawNum
	                    methods:RawNum inheritedMethods:RawNum newMethods:RawNum
	                    pointers:RawNum name:RawString typeDescriptorSize:RawLInt
	                    {method:RawNum entry:RawNum}:newMethods
	                    {offset:RawNum}:pointers

	ExceptionTable    = 08EX { ExTableEntry }:exTableLength
	ExTableEntry      = 0FEX pcFrom:RawNum pcTo:RawNum pcHandler:RawNum

	PtrsInProcs       = 08FX {ProcEntry}:numberProcs
	ProcEntry         = codeOfs:RawNum beginOfs:RawNum endOfs:RawNum
	                    numberPointers:RawLInt {pointer:RawNum}:numberPointers

	References        = 08CX RSScope { RSProcedure }
	Scope             = 0F8X codeOffset:RawNum "$$" {Variable}
	Procedure         = 0F9X codeOffset:RawNum numberParameters:RawNum ReturnType
	                    level:RawNum 0X name:RawString {Parameter} {Variable}

	ReturnType        = 0X | BaseType | rfStaticArray | rfDynamicArray | rfOpenArray | rfRecord

	Parameter         = Variable
	Variable          = VariableMode Type variableOffset:RawNum variableName:RawString
	VariableMode      = rfIndirect | rfDirect

	Type              = BaseType | ArrayType | RecordType
	BaseType          = rfByte  | rfSet | rfAny
	                    | rfBoolean | rfChar8 | rfChar16 | rfChar32
	                    | rfShortint | rfInteger | rfLongint | rfHugeint
	                    | rfReal | rfLongreal |
	                    | rfString | rfPointer | rfAll | rfSame | rfRange
	                    | rfComplex | rfLongcomplex
	ArrayType         = 80H+BaseType:RawNum dim:RawNum
	RecordType        = (rfRecord | rfRecordPointer) tdAdr:RawNum
**)


CONST

	ofFileTag = 0BBX;				(* same constants are defined in Linker and Loader *)
	ofNoZeroCompress = 0ADX;	(* do. *)
	ofFileVersion = SymbolFileFormat.FileVersionCurrent;			(* do. *)

	ofEUEnd = 0X;
	ofEURecord = 1X;
	ofEUProcFlag = LONGINT(080000000H);

	(** system calls *)
	DefaultNofSysCalls = 12;
	NewRec = 0;  NewArr = 1;  NewSys = 2;  CaseTable = 3;  ProcAddr = 4;
	Lock = 5;  Unlock = 6;  Start = 7;  Await = 8; InterfaceLookup = 9;
	RegisterInterface = 10; GetProcedure = 11;
	Trace = FALSE;


TYPE Name=ARRAY 256 OF CHAR;
	ByteArray = POINTER TO ARRAY OF CHAR;

TYPE

	ObjectFileFormat*= OBJECT (Formats.ObjectFileFormat)

		PROCEDURE & InitObjectFileFormat;
		BEGIN
			Init; SetExtension(Machine.DefaultObjectFileExtension);
		END InitObjectFileFormat;

		PROCEDURE Export*(module: Formats.GeneratedModule; symbolFileFormat: Formats.SymbolFileFormat): BOOLEAN;
		VAR symbolFile: Files.File; moduleName: SyntaxTree.IdentifierString; fileName: Files.FileName; f: Files.File; w: Files.Writer;
		VAR constSize, varSize, codeSize, caseTableSize: LONGINT; VAR const, code: ByteArray;
		BEGIN
			Global.ModuleFileName(module.module.name,module.module.context,moduleName);
			Basic.Concat(fileName,path,moduleName,extension);
			IF Trace THEN D.Str("FoxBinaryObjectFile.ObjectFileFormat.Export "); D.Str(moduleName); D.Ln; END;

			IF ~(module IS Sections.Module) THEN
				diagnostics.Error(module.module.sourceName,Diagnostics.Invalid,Diagnostics.Invalid,"generated module format does not match object file format");
				RETURN FALSE;
			ELSIF module.findPC # MAX(LONGINT) THEN
				MakeSectionOffsets(module(Sections.Module),constSize, varSize, codeSize, caseTableSize,const,code);
				RETURN FindPC(module.findPC,module(Sections.Module),diagnostics);
			ELSE

				WITH module: Sections.Module DO
					IF (symbolFileFormat # NIL) & (symbolFileFormat IS SymbolFileFormat.BinarySymbolFile) THEN
						symbolFile := symbolFileFormat(SymbolFileFormat.BinarySymbolFile).file;
					ELSE
						symbolFile := NIL
					END;
					f := Files.New(fileName);
					ASSERT(f # NIL);
					(*
					IF dump # NIL THEN
						dump.String("generated file "); dump.String(fileName); dump.Ln; dump.Update;
					END;
					*)
					NEW(w,f,0);

					WriteObjectFile(w,module,symbolFile);
					w.Update;
					Files.Register(f);
					RETURN TRUE
				END;
			END;

		END Export;

		PROCEDURE DefineOptions*(options: Options.Options);
		BEGIN
			options.Add(0X,"objectFileExtension",Options.String);
		END DefineOptions;

		PROCEDURE GetOptions*(options: Options.Options);
		VAR extension: Files.FileName;
		BEGIN
			IF options.GetString("objectFileExtension",extension) THEN
				SetExtension(extension);
			END;
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat(): Formats.SymbolFileFormat;
		BEGIN RETURN SymbolFileFormat.Get();
		END DefaultSymbolFileFormat;

		PROCEDURE ForceModuleBodies(): BOOLEAN; (* necessary in binary object file format as bodies not recognizable later on *)
		BEGIN RETURN TRUE
		END ForceModuleBodies;

	END ObjectFileFormat;

	Fixup = OBJECT
	VAR
		nextFixup: Fixup;
		fixup: BinaryCode.Fixup;
		fixupSection: Sections.Section;
	END Fixup;

	Section=OBJECT (* proprietary format for this object file format *)
	VAR
		name: Basic.SegmentedName;
		symbol: SyntaxTree.Symbol;
		entryNumber: LONGINT;
		offset: LONGINT;
		fixups: Fixup; (* fixups other way round: who references to this section *)
		numberFixups: LONGINT;
		type: LONGINT;
		resolved: BinaryCode.Section;
		isCaseTable: BOOLEAN;
		referenced: BOOLEAN;


		PROCEDURE SetEntryNumber(num: LONGINT);
		BEGIN
			entryNumber := num
		END SetEntryNumber;

		PROCEDURE SetSymbol(s: SyntaxTree.Symbol);
		BEGIN
			symbol := s;
		END SetSymbol;

		PROCEDURE &Init(CONST name: Basic.SegmentedName);
		BEGIN SELF.name := name; fixups := NIL; symbol := NIL; entryNumber := 0; numberFixups := 0;
		END Init;

		PROCEDURE AddFixup(fixup: BinaryCode.Fixup; fixupSection: Sections.Section);
		VAR next: Fixup;
		BEGIN
			NEW(next);
			next.fixup := fixup;
			next.fixupSection := fixupSection;
			next.nextFixup := fixups;
			fixups := next;
			INC(numberFixups);
		END AddFixup;

		PROCEDURE Dump(w: Streams.Writer);
		VAR fixup: Fixup; n: Basic.SegmentedName;
		BEGIN
			Basic.WriteSegmentedName(w,name);
			w.String(" : ");
			IF symbol = NIL THEN w.String("NIL")
			ELSE Global.GetSymbolSegmentedName(symbol, n); Basic.WriteSegmentedName(w,n);
			END;
			IF referenced THEN w.String("(referenced)") END;
			w.Ln;
			w.String("no fixups:"); w.Int(numberFixups,1); w.Ln;
			fixup := fixups;
			WHILE fixup # NIL DO
				w.String("fixup in "); Basic.WriteSegmentedName(w,fixups.fixupSection.name); w.String(" "); fixup.fixup.Dump(w); w.Ln;
				fixup := fixup.nextFixup;
			END;
		END Dump;

	END Section;

	SectionNameLookup = OBJECT(Basic.HashTableSegmentedName); (* SyntaxTree.Symbol _> Symbol *)

		PROCEDURE GetSection(CONST name: Basic.SegmentedName):Section;
		VAR p: ANY;
		BEGIN
			p := Get(name);
			IF p # NIL THEN RETURN p(Section) ELSE RETURN NIL END;
		END GetSection;

		PROCEDURE PutSection(CONST name:Basic.SegmentedName; section: Section);
		BEGIN
			Put(name, section);
		END PutSection;

	END SectionNameLookup;

	SymbolLookup = OBJECT(Basic.HashTable); (* SyntaxTree.Symbol _> Symbol *)

		PROCEDURE GetSection(s: SyntaxTree.Symbol):Section;
		VAR p: ANY;
		BEGIN
			p := Get(s);
			IF p # NIL THEN RETURN p(Section) ELSE RETURN NIL END;
		END GetSection;

		PROCEDURE PutSection(symbol: SyntaxTree.Symbol; section: Section);
		BEGIN
			Put(symbol, section);
		END PutSection;

	END SymbolLookup;


	SectionList= OBJECT (Basic.List)
	VAR
		lookup: SectionNameLookup;
		symbolLookup: SymbolLookup;

		PROCEDURE &Init;
		BEGIN
			InitList(16);
			NEW(lookup,16);
			NEW(symbolLookup, 16);
		END Init;

		PROCEDURE AddSection(name: Basic.SegmentedName): Section;
		VAR section: Section;
		BEGIN
			section := lookup.GetSection(name);
			IF section = NIL THEN
				NEW(section, name);
				lookup.Put(name, section);
				Add(section);
			END;
			RETURN section
		END AddSection;

		PROCEDURE BySymbol(symbol: SyntaxTree.Symbol): Section;
		VAR name: Basic.SegmentedName;
		BEGIN
			RETURN symbolLookup.GetSection(symbol);
		END BySymbol;


		PROCEDURE GetSection(i: LONGINT): Section;
		VAR any: ANY;
		BEGIN
			any := Get(i);
			RETURN any(Section)
		END GetSection;

		PROCEDURE Dump(w: Streams.Writer);
		VAR section: Section; i: LONGINT;
		BEGIN
			FOR i := 0 TO Length()-1 DO
				section := GetSection(i); section.Dump(w);
			END;
		END Dump;


	END SectionList;

	VAR SysCallMap : ARRAY DefaultNofSysCalls OF CHAR;

	(*
	PROCEDURE GetFixups(module: Sections.Module; symbol: Sections.Section; VAR first: Fixup): LONGINT;
	VAR temp: Fixup; fixup: BinaryCode.Fixup; nr :LONGINT;

		(* only regular sections *)
		PROCEDURE DoSections(sectionList: Sections.SectionList);
		VAR
			i: LONGINT;
			section: Sections.Section;
		BEGIN
			FOR i := 0 TO sectionList.Length() - 1 DO
				section := sectionList.GetSection(i);
				IF (section.type # Sections.InlineCodeSection) & (section.type # Sections.InitCodeSection) THEN
					fixup := section(IntermediateCode.Section).resolved.fixupList.firstFixup;
					WHILE (fixup # NIL) DO
						IF (fixup.symbol = symbol.name) THEN
							INC(nr);
							NEW(temp);
							temp.fixup := fixup;
							temp.fixupSection := section;
							temp.nextFixup := first;
							first := temp;
						END;
						fixup := fixup.nextFixup;
					END
				END
			END;
		END DoSections;

	BEGIN
		first := NIL; nr := 0;
		DoSections(module.allSections); (* only regular sections *)
		(* Sections(module.caseTables.first); *)
		RETURN nr
	END GetFixups;
	*)

	PROCEDURE FindPC(pc: LONGINT; module: Sections.Module; diagnostics: Diagnostics.Diagnostics): BOOLEAN;
	VAR
		section:Sections.Section; binarySection: BinaryCode.Section; label: BinaryCode.LabelList;
		i: LONGINT;
	BEGIN
		FOR i := 0 TO module.allSections.Length() - 1 DO
			section := module.allSections.GetSection(i);
			binarySection := section(IntermediateCode.Section).resolved;
			IF ((section.offset ) <= pc) & (pc < (section.offset +binarySection.pc )) THEN
				label := binarySection.labels;
				WHILE (label # NIL) & ((label.offset  + section.offset ) > pc) DO
					label := label.prev;
				END;
				IF label # NIL THEN
					diagnostics.Information(module.module.sourceName,label.position,Diagnostics.Invalid," pc position");
					RETURN TRUE
				END;
			END
		END;
		diagnostics.Error(module.module.sourceName,Diagnostics.Invalid,Diagnostics.Invalid," could not locate pc");
		RETURN FALSE
	END FindPC;


	PROCEDURE MakeSectionOffsets(module: Sections.Module; VAR constSize, varSize, codeSize, caseTableSize: LONGINT; VAR const, code: ByteArray);
	VAR symbolName: SyntaxTree.IdentifierString; symbol: SyntaxTree.Symbol; binarySection: BinaryCode.Section;
		pc: LONGINT;

		(*
		PROCEDURE InModule(s: Sections.Section):BOOLEAN;
		VAR
			section: Sections.Section;
			i: LONGINT;
		BEGIN
			FOR i := 0 TO module.allSections.Length() - 1 DO
				section := module.allSections.GetSection(i);
				IF section = s THEN RETURN TRUE END
			END;
			RETURN FALSE
		END InModule;
		*)

		PROCEDURE FixupSections;
		VAR
			section: Sections.Section; dest, i: LONGINT; fixup,next: BinaryCode.Fixup; symbol: Sections.Section;
		BEGIN
			FOR i := 0 TO module.allSections.Length() - 1 DO
				section := module.allSections.GetSection(i);
				binarySection := section(IntermediateCode.Section).resolved;
				fixup := binarySection.fixupList.firstFixup;
				binarySection.fixupList.InitFixupList; (* remove all fixups from list *)
				WHILE fixup # NIL DO
					next := fixup.nextFixup;
					symbol := module.allSections.FindByName(fixup.symbol.name);
					IF symbol # NIL THEN
						symbol.SetReferenced(TRUE);
					ELSIF Trace THEN
						D.String("fixup symbol not found: "); Basic.WriteSegmentedName(D.Log, fixup.symbol.name); D.Ln;
					END;
					IF (fixup.mode = BinaryCode.Relative) & (symbol # NIL) THEN (* relative offset within module *)
						dest := (symbol.offset + fixup.displacement) - (section.offset + fixup.offset);
						ASSERT(fixup.symbolOffset = 0);
						binarySection.PutDWordAt(fixup.offset, dest);
						(* fixup done, does not need to be put back to list *)
					ELSIF (fixup.mode = BinaryCode.Absolute) & (symbol # NIL) THEN (* absolute offset within module *)
						dest := symbol.offset + fixup.displacement;
						binarySection.PutDWordAt(fixup.offset, dest);
						binarySection.fixupList.AddFixup(fixup); (* (re-)insert fixup into fixup list *)
					ELSIF (fixup.mode = BinaryCode.Absolute) THEN (* absolute fixup on imported symbol *)
						dest := fixup.displacement;
						binarySection.PutDWordAt(fixup.offset, dest);
						binarySection.fixupList.AddFixup(fixup); (* (re-)insert fixup into fixup list *)
					ELSE binarySection.fixupList.AddFixup(fixup); (* keep fixup as is: relative fixup on imported symbol *)
					END;
					fixup := next;
				END
			END;
		END FixupSections;

		PROCEDURE Copy(section: BinaryCode.Section; to: ByteArray; offset: LONGINT);
		VAR i,ofs: LONGINT;
		BEGIN
			ofs := (offset );
			FOR i := 0 TO ((section.pc-1) ) DO
				to[i+ofs] := CHR(section.os.bits.GetBits(i*8,8));
			END;
		END Copy;

		(* only regular sections *)
		PROCEDURE FirstOffsets(sectionList: Sections.SectionList);
		VAR
			section: Sections.Section;
			i: LONGINT;
		BEGIN
			FOR i := 0 TO sectionList.Length() - 1 DO
				section := sectionList.GetSection(i);
				binarySection := section(IntermediateCode.Section).resolved;
				symbol := section.symbol;
				IF symbol # NIL THEN
					symbol.GetName(symbolName);
					IF section.symbol = module.module.moduleScope.bodyProcedure THEN
						section.SetOffset(0); INC(codeSize,binarySection.pc);
					ELSIF symbolName = "@moduleSelf" THEN
						section.SetOffset(0); INC(constSize,binarySection.pc);
					END;
				END
			END;
		END FirstOffsets;

		(* note: if 'caseSections' is TRUE, only case table sections are processed, otherwise only regular sections (imported symbol/system call sections are never processed) *)
		PROCEDURE SetOffsets(sectionList: Sections.SectionList; caseTables: BOOLEAN);
		VAR
			section: Sections.Section;
			i: LONGINT;
		BEGIN
			FOR i := 0 TO sectionList.Length() - 1 DO
				section := sectionList.GetSection(i);
				IF section.isCaseTable = caseTables THEN
					binarySection := section(IntermediateCode.Section).resolved;
					symbol := section.symbol;
					IF symbol # NIL THEN
						symbol.GetName(symbolName);
					ELSE symbolName := "";
					END;

					IF section.symbol = module.module.moduleScope.bodyProcedure THEN
					ELSIF symbolName = "@moduleSelf" THEN
					ELSIF section.type = Sections.ConstSection THEN
						 IF binarySection.os.alignment # 0 THEN
						 	INC(constSize,(-constSize) MOD binarySection.os.alignment);
						 END;
						  section.SetOffset(constSize); INC(constSize,binarySection.pc); (* global constants: positive offset *)
					ELSIF (section.type = Sections.CodeSection) OR (section.type = Sections.BodyCodeSection) THEN
						section.SetOffset(codeSize); INC(codeSize, binarySection.pc);
					ELSIF section.type = Sections.VarSection THEN
						 INC(varSize, binarySection.pc);
						 IF binarySection.os.alignment # 0 THEN
						 	INC(varSize,(-varSize) MOD binarySection.os.alignment);
						 END;
						 section.SetOffset(-varSize); (* global variables: negative offset *)
					END
				END;
			END;
		END SetOffsets;

		(* note: if 'caseSections' is TRUE, only case table sections are processed, otherwise only regular sections (imported symbol/system call sections are never processed) *)
		PROCEDURE CopySections(sectionList: Sections.SectionList);
		VAR
			section: Sections.Section;
			i: LONGINT;
		BEGIN
			FOR i := 0 TO sectionList.Length() - 1 DO
				section := sectionList.GetSection(i);
				binarySection := section(IntermediateCode.Section).resolved;
				IF section.type = Sections.ConstSection THEN
					Copy(binarySection,const,section.offset);
				ELSIF (section.type = Sections.CodeSection) OR (section.type = Sections.BodyCodeSection) THEN
					Copy(binarySection,code,section.offset);
				END
			END;
		END CopySections;



	BEGIN
		FirstOffsets(module.allSections); (* regular sections *)
		SetOffsets(module.allSections,FALSE); (* regular sections *)
		pc := constSize;
		SetOffsets(module.allSections, TRUE); (* case table sections *)
		caseTableSize := (constSize -pc) DIV 4 ;
		FixupSections;

		NEW(const,constSize ); NEW(code,codeSize );
		CopySections(module.allSections); (* regular sections *)
	END MakeSectionOffsets;

	PROCEDURE WriteObjectFile*(w:Streams.Writer; module: Sections.Module; symbolFile: Files.File);
	VAR moduleName: Name; refSize, numberEntries,numberCommands,numberPointers,numberTypes,numberImports,
		numberVarConstLinks,numberLinks: LONGINT;
		dataSize,constSize,codeSize,caseTableSize: LONGINT;
		exTableLen,numberProcs,maxPtrs,typeDescSize: LONGINT; headerPos,endPos: LONGINT;
		moduleScope: SyntaxTree.ModuleScope; fingerprinter: FingerPrinter.FingerPrinter;
		const, code: ByteArray; procedureFixupOffset : LONGINT;
		crc: LONGINT; crc32: Basic.CRC32Stream;

		symbols, importedSymbols: SectionList; (* list of sections with fixups in the other direction, needed for this particular object file format *)

		PROCEDURE RawLIntAt(at: LONGINT; val: LONGINT);
		VAR pos: LONGINT;
		BEGIN
			pos := w.Pos(); w.SetPos(at); w.RawLInt(val); w.SetPos(pos);
		END RawLIntAt;

		PROCEDURE AppendFile(f: Files.File;  to: Streams.Writer);
		VAR buffer: ARRAY 1024 OF CHAR;  r: Files.Reader;  read: LONGINT;
		BEGIN
			Files.OpenReader(r, f, 0);
			REPEAT
				r.Bytes(buffer, 0, 1024, read);
				to.Bytes(buffer, 0, read)
			UNTIL read # 1024
		END AppendFile;

		PROCEDURE SymbolFile; (* write symbol file *)
		BEGIN
			IF Trace THEN D.Str("FoxObjectFile.SymbolFile Length at pos "); D.Int(w.Pos(),1); D.Ln END;

			IF symbolFile # NIL THEN
				w.RawLInt(symbolFile.Length()); (* could also be patched later, if length was not known here *)
				IF Trace THEN D.Str("FoxObjectFile.SymbolFile at pos "); D.Int(w.Pos(),1); D.Ln END;
				AppendFile(symbolFile,w);
			ELSE
				IF Trace THEN D.Str("FoxObjectFile.SymbolFile: no symbol file!"); D.Ln END;
				w.RawLInt(0);
			END;
		END SymbolFile;

		(* Header =
			refSize:4 numberEntries:4 numberCommands:4 numberPointers:4
			numberTypes:4 numberImports:4 numberVarConstLinks:4 numberLinks:4
			dataSize:4 constSize:4 codeSize:4 exTableLen:4 numberProcs:4 maxPtrs:4
			typeDescSize:4 crc:4 moduleName:String
		*)
		PROCEDURE Header;
		BEGIN
			headerPos := w.Pos();
			w.RawLInt(refSize);
			w.RawLInt(numberEntries);
			w.RawLInt(numberCommands);
			w.RawLInt(numberPointers);
			w.RawLInt(numberTypes);
			w.RawLInt(numberImports);
			w.RawLInt(numberVarConstLinks);
			w.RawLInt(numberLinks);
			w.RawLInt((dataSize )); ASSERT(dataSize >= 0);
			w.RawLInt((constSize ));
			w.RawLInt((codeSize ));
			w.RawLInt(exTableLen);
			w.RawLInt(numberProcs);
			w.RawLInt(maxPtrs);
			w.RawLInt(typeDescSize);
			w.RawLInt(crc);
			IF Trace THEN D.Str("moduleName:"); D.Str(moduleName); D.Ln; END;
			w.RawString(moduleName);
		END Header;

		(* Entries = 82X {entryOffset}:numberEntries *)
		PROCEDURE Entries;
		VAR
			p: Section; procedure: SyntaxTree.Procedure; procedureType : SyntaxTree.ProcedureType;
			prev,tail: Fixup; firstOffset: LONGINT; name: SyntaxTree.IdentifierString; fixups, i: LONGINT; fixup: Fixup;
		CONST
			FixupSentinel = LONGINT(0FFFFFFFFH);


			PROCEDURE FixupList(l,prev: Fixup; VAR tail: Fixup);
			(* Insert fixup list into code *)
			VAR offset: LONGINT;

				PROCEDURE Put32(offset: LONGINT; number: LONGINT);
				BEGIN
					code[offset] := CHR(number MOD 256);
					INC(offset); number := number DIV 256;
					code[offset] := CHR(number MOD 256);
					INC(offset); number := number DIV 256;
					code[offset] := CHR(number MOD 256);
					INC(offset); number := number DIV 256;
					code[offset] := CHR(number MOD 256);
				END Put32;

			BEGIN
				tail := NIL;
				IF l # NIL THEN
					IF prev # NIL THEN
						Put32((prev.fixupSection.offset +prev.fixup.offset ),(l.fixupSection.offset + l.fixup.offset ));
					END;
					offset := (l.fixupSection.offset  + l.fixup.offset );
					tail := l;
					l := l.nextFixup;
					WHILE (l# NIL) DO
						Put32(offset,(l.fixupSection.offset + l.fixup.offset ));
						offset := (l.fixupSection.offset + l.fixup.offset );
						tail := l;
						l := l.nextFixup;
					END;
					Put32(offset,FixupSentinel);
				END;
			END FixupList;


		BEGIN
			w.Char(82X);
			numberEntries := 0; tail := NIL; prev := NIL; firstOffset := -1;
			FOR i := 0 TO symbols.Length() - 1 DO
				p := symbols.GetSection(i);
				IF  (p.symbol # NIL) & (p.symbol IS SyntaxTree.Procedure) & ~p.symbol(SyntaxTree.Procedure).isInline THEN
					fixup := p.fixups;
					p.symbol.GetName(name); (*debugging*)
					procedure := p.symbol(SyntaxTree.Procedure);
					procedureType := procedure.type(SyntaxTree.ProcedureType);
					(* entry for public procedures and all methods *)
					IF (procedure.access*SyntaxTree.Public # {}) OR (procedureType.isDelegate) OR (fixup # NIL) 	THEN
						p.SetEntryNumber(numberEntries);
						w.RawNum((p.offset )); INC(numberEntries);

						FixupList(fixup, prev, tail); (* absolute fixups, relative procedure fixups have already been done during code generation *)
						IF tail # NIL THEN
							prev := tail
						END;
						IF (fixup # NIL) & (firstOffset = -1) THEN
							firstOffset := (fixup.fixupSection.offset + fixup.fixup.offset );
						END
					END
				END
			END;
			procedureFixupOffset := firstOffset;

		END Entries;

		(* Commands =
			83X {firstParTypeOffset:Num returnParTypeOffset:Num cmdName:String cmdOffset:Num}:numberCommands
		*)
		PROCEDURE Commands;
		VAR
			procedure : SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
			p: Section; name: Name; numberParameters, i: LONGINT;

			(* Returns TRUE if the built-in function GETPROCEDURE can be used with this procedure type *)
			PROCEDURE GetProcedureAllowed() : BOOLEAN;

				PROCEDURE TypeAllowed(type : SyntaxTree.Type) : BOOLEAN;
				BEGIN
					RETURN
						(type = NIL) OR
						(type.resolved IS SyntaxTree.RecordType) OR
						(type.resolved IS SyntaxTree.PointerType) & (type.resolved(SyntaxTree.PointerType).pointerBase.resolved IS SyntaxTree.RecordType);
				END TypeAllowed;

			BEGIN
				numberParameters := procedureType.numberParameters;
				RETURN
					(numberParameters = 0) & TypeAllowed(procedureType.returnType) OR
					(numberParameters = 1) & TypeAllowed(procedureType.firstParameter.type) & TypeAllowed(procedureType.returnType) OR
					(numberParameters = 1) & (procedureType.firstParameter.type.resolved IS SyntaxTree.AnyType) & (procedureType.returnType # NIL) & (procedureType.returnType.resolved IS SyntaxTree.AnyType);
			END GetProcedureAllowed;

			PROCEDURE WriteType(type : SyntaxTree.Type);
			VAR typeDeclaration: SyntaxTree.TypeDeclaration; section: Section;
				name: SyntaxTree.IdentifierString;
			BEGIN
				IF type = NIL THEN
					w.RawNum(0);
						IF Trace THEN
							D.String(", t="); D.Int(0,1);
						END;
				ELSIF (type.resolved IS SyntaxTree.AnyType) OR (type.resolved IS SyntaxTree.ObjectType) THEN
					w.RawNum(1);
						IF Trace THEN
							D.String(", t="); D.Int(1,1);
						END;
				ELSE
					type := type.resolved;
					IF type IS SyntaxTree.PointerType THEN
						type := type(SyntaxTree.PointerType).pointerBase.resolved;
					END;
					typeDeclaration := type.typeDeclaration; (* must be non-nil *)
					typeDeclaration.GetName(name);
					section := symbols.BySymbol(type.typeDeclaration);
					ASSERT(section # NIL);
					w.RawNum((section.offset )); (* type descriptor section offset *)
					IF Trace THEN
						D.String(", t="); D.Int(section.offset ,1);
					END;
				END;
			END WriteType;

		BEGIN
			w.Char(83X);
			FOR i := 0 TO symbols.Length() - 1 DO
				p := symbols.GetSection(i);
				IF (p.symbol # NIL) & (p.symbol IS SyntaxTree.Procedure)  THEN
					procedure := p.symbol(SyntaxTree.Procedure);
					procedureType := procedure.type(SyntaxTree.ProcedureType);
					IF (SyntaxTree.PublicWrite IN procedure.access) & ~(procedure.isInline) & ~(procedureType.isDelegate) & GetProcedureAllowed() THEN
						procedure.GetName(name);
						IF Trace THEN
							D.Str("Command : "); D.Str(name); D.Str(" @ "); D.Int(p.offset ,1);
						END;
						numberParameters := procedureType.numberParameters;
						(* offset of type of first parameter *)
						IF (numberParameters = 0 ) THEN WriteType(NIL)
						ELSE WriteType(procedureType.firstParameter.type)
						END;
						(* offset of type of return parameter *)
						WriteType(procedureType.returnType);
						(* command name *)
						w.RawString(name);
						(* command code offset *)
						w.RawNum((p.offset ));
						INC(numberCommands);
						IF Trace THEN
								D.Ln
							END
						END
					END
				END
		END Commands;

		(* OutPointers delivers
			{pointerOffset}
		*)
		PROCEDURE OutPointers(offset: LONGINT; type: SyntaxTree.Type; VAR numberPointers: LONGINT);
		VAR variable: SyntaxTree.Variable; i,n,size: LONGINT; base: SyntaxTree.Type;
		BEGIN
			type := type.resolved;
			IF type IS SyntaxTree.AnyType THEN
				ASSERT(offset MOD 4 = 0);
				w.RawNum((offset )); INC(numberPointers);
				IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1); D.Ln; END;
			ELSIF type IS SyntaxTree.PointerType THEN
				ASSERT(offset MOD 4 = 0);
				w.RawNum((offset )); INC(numberPointers);
				IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1);D.Ln;  END;
			ELSIF (type IS SyntaxTree.ProcedureType) & (type(SyntaxTree.ProcedureType).isDelegate) THEN
				ASSERT(offset MOD 4 = 0);
				w.RawNum((offset )+module.system.addressSize DIV 8 ); INC(numberPointers);
				IF Trace THEN D.Str("ptr at offset="); D.Int(offset+module.system.addressSize DIV 8,1); END;
			ELSIF (type IS SyntaxTree.RecordType) THEN
				(* never treat a record like a pointer, even if the pointer field is set! *)
				WITH type: SyntaxTree.RecordType DO
					base := type.GetBaseRecord();
					IF base  # NIL THEN
						OutPointers(offset,base,numberPointers);
					END;
					variable := type.recordScope.firstVariable;
					WHILE(variable # NIL) DO
						IF ~(variable.untraced) THEN
							OutPointers(offset+variable.offsetInBits DIV 8,variable.type,numberPointers);
						END;
						variable := variable.nextVariable;

					END;
				END;
			ELSIF (type IS SyntaxTree.ArrayType) THEN
				WITH type: SyntaxTree.ArrayType DO
					IF type.form= SyntaxTree.Static THEN
						n := type.staticLength;
						base := type.arrayBase.resolved;
						WHILE(base IS SyntaxTree.ArrayType) DO
							type := base(SyntaxTree.ArrayType);
							n := n* type.staticLength;
							base := type.arrayBase.resolved;
						END;
						size := module.system.AlignedSizeOf(base) DIV 8;
						IF SemanticChecker.ContainsPointer(base) THEN
							ASSERT(n<1000000); (* not more than one million pointers on the stack ... *)
							FOR i := 0 TO n-1 DO
								OutPointers(offset+i*size,base,numberPointers);
							END;
						END;
					ELSE
						ASSERT(offset MOD 4 = 0);

						w.RawNum((offset )); INC(numberPointers);
						IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1); D.Ln; END;
					END;
				END;
			ELSIF (type IS SyntaxTree.MathArrayType) THEN
				WITH type: SyntaxTree.MathArrayType DO
					IF type.form = SyntaxTree.Static THEN
						n := type.staticLength;
						base := type.arrayBase.resolved;
						WHILE(base IS SyntaxTree.MathArrayType) DO
							type := base(SyntaxTree.MathArrayType);
							n := n* type.staticLength;
							base := type.arrayBase.resolved;
						END;
						size := module.system.AlignedSizeOf(base) DIV 8;
						IF SemanticChecker.ContainsPointer(base) THEN
							ASSERT(n<1000000); (* not more than one million pointers on the stack ... *)
							FOR i := 0 TO n-1 DO
								OutPointers(offset+i*size,base,numberPointers);
							END;
						END;
					ELSE
						ASSERT(offset MOD 4 = 0);
						w.RawNum((offset )); INC(numberPointers); (* GC relevant pointer is at offset 0 *)
						IF Trace THEN D.Str("ptr at offset="); D.Int(offset,1); D.Ln; END;
					END
				END;
			(* ELSE no pointers in type *)
			END;
		END OutPointers;

		(* Pointers =
			84X { pointerOffset:Num}:numberPointers
		*)
		PROCEDURE Pointers;
		VAR
			s: Section; variable: SyntaxTree.Variable;
			i: LONGINT;
		BEGIN
			w.Char(84X);
			numberPointers := 0;
			IF Trace THEN D.Str("Global Pointers: "); D.Ln; END;
			FOR i := 0 TO symbols.Length() - 1 DO
				s := symbols.GetSection(i);
				IF (s.symbol # NIL) & (s.symbol IS SyntaxTree.Variable) THEN
					variable := s.symbol(SyntaxTree.Variable);
					IF ~(variable.untraced) THEN
						OutPointers(s.offset, variable.type, numberPointers);
					END
				END
			END
		END Pointers;

		PROCEDURE IsFirstOccurence(import: SyntaxTree.Import): BOOLEAN; (*! inefficient *)
		VAR i: SyntaxTree.Import;
		BEGIN
			i := moduleScope.firstImport;
			WHILE (i # NIL) & (i.module # import.module) DO
				i := i.nextImport;
			END;
			RETURN i = import
		END IsFirstOccurence;

		(* Imports =
			85X { moduleName:String }:numberImports
		*)
		PROCEDURE Imports;
		VAR name: Name; import: SyntaxTree.Import;
		BEGIN
			w.Char(85X);
			numberImports := 0;
			import := moduleScope.firstImport;
			WHILE(import # NIL) DO
				IF ~Global.IsSystemModule(import.module) & IsFirstOccurence(import) THEN
					Global.ModuleFileName(import.module.name,import.module.context,name);
					w.RawString(name); INC(numberImports);
					IF Trace THEN
						D.Str("Import module : "); D.Str(name); D.Ln;
					END;
				END;
				import := import.nextImport;
			END;
		END Imports;

		(*? should this be coded fix in a separate module list ? *)
		(* Module Number returns the position of a module in the written import list *)
		PROCEDURE ModuleNumber(m: SyntaxTree.Module): LONGINT;
		VAR number: LONGINT; import: SyntaxTree.Import;
		BEGIN
			number := 1;
			import := moduleScope.firstImport;
			WHILE(import # NIL) & (import.module # m) DO
				IF ~Global.IsSystemModule(import.module)  & IsFirstOccurence(import) THEN
					INC(number);
				END;
				import := import.nextImport;
			END;
			RETURN number;
		END ModuleNumber;

		(*
			VarConstLinks = 8DX {VarConstLinkEntry}: numberVarConstLinks
			VarConstLinkEntry = modNumber:1 entry:Number fixupCount:4 {offset:Number}:fixupCount}
		*)
		PROCEDURE VarConstLinks;
		VAR
			fixups: LONGINT; fixupsPosition: LONGINT;
			s: Section; fixup: Fixup; temp, i: LONGINT;
			sym: Section;

			PROCEDURE Fixups(f: Fixup);
			BEGIN
				WHILE f # NIL DO
					IF Trace THEN
						D.String("fixup "); D.Int(f.fixupSection.offset +f.fixup.offset ,1); D.Ln;
					END;
					w.RawNum((f.fixupSection.offset  + f.fixup.offset )); INC(fixups);
					f := f.nextFixup;
				END;
			END Fixups;

		BEGIN
			w.Char(8DX);
			numberVarConstLinks := 0;

			(* global variables and constants of this module *)
			w.Char(0X); (* module Number = 0 => this module *)
			w.RawNum(-1); (* entry = -1 => this module *)
			fixupsPosition := w.Pos(); fixups := 0;
			w.RawLInt(fixups); (* number of fixups, to be patche *)

			IF Trace THEN D.Str("VarConstLinks:Procedures"); D.Ln; END;

			FOR i := 0 TO symbols.Length() - 1 DO
				s := symbols.GetSection(i);
				IF ~s.isCaseTable THEN
				IF (s.symbol=NIL) OR (s.symbol # NIL) & ~(s.symbol IS SyntaxTree.Procedure) THEN
					IF Trace THEN D.String("varconstlink, procedure "); Basic.WriteSegmentedName(D.Log, s.name); D.Ln END;
					Fixups(s.fixups);
				END
				END;
			END;

			(*! can be merged with previous -- for testing consistency *)
			FOR i := 0 TO symbols.Length() - 1 DO
				s := symbols.GetSection(i);
				IF s.isCaseTable THEN
				ASSERT(s.symbol # NIL);
				IF (s.symbol # NIL) & ~(s.symbol IS SyntaxTree.Procedure) THEN
					Fixups(s.fixups);
				END
				END;
			END;

			(*
			IF Trace THEN D.Str("VarConstLinks:CaseTables"); D.Ln; END;

			FOR i := 0 TO module.allSections.Length() - 1 DO
				s := module.allSections.GetSection(i);
				IF s.kind = Sections.CaseTableKind THEN
					IF (s.symbol # NIL) & ~(s.symbol IS SyntaxTree.Procedure) THEN (* includes case symbol! *)
						temp := GetFixups(module,s,fixup);
						Fixups(fixup);
					END
				END
			END;
			*)

			RawLIntAt(fixupsPosition,fixups); (* fixups count patched *)

			INC(numberVarConstLinks);

			IF Trace THEN D.Str("VarConstLinks:ImportedSymbols"); D.Ln; END;
			(* imported global variables and constants *)

			FOR i := 0 TO importedSymbols.Length()-1 DO
				sym := importedSymbols.GetSection(i);
				IF (sym.symbol=NIL) OR (sym.symbol # NIL) & ~(sym.symbol IS SyntaxTree.Procedure) THEN
					ASSERT(sym.numberFixups > 0);
					sym.entryNumber := numberVarConstLinks;
					INC(numberVarConstLinks);
					w.Char(CHR(ModuleNumber(sym.symbol.scope.ownerModule)));
					w.RawNum(0); (* entry = 0 =>  importing module *)
					w.RawLInt(sym.numberFixups); (* number of fixups, to be patched *)
					Fixups(sym.fixups);
				END;
			END;

		END VarConstLinks;


		(*
			Links = 86X {LinkEntry:Number}:numberLinks {FixupCount:Number}:numberEntries caseTableSize:Number
			LinkEntry = moduleNumber:1 entryNumber:1 offset:Number
		*)
		PROCEDURE Links;
		VAR
			p: Section; procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType; i, counter: LONGINT; temp: LONGINT; fixup: Fixup; fixups: LONGINT;
		CONST
			FixupSentinel = LONGINT(0FFFFFFFFH);

			(* Insert fixup list into code *)
			PROCEDURE FixupList(l: Fixup): LONGINT;
			VAR
				offset,first: LONGINT;

				PROCEDURE Put32(offset: LONGINT; number: LONGINT);
				BEGIN
					code[offset] := CHR(number MOD 256);
					INC(offset); number := number DIV 256;
					code[offset] := CHR(number MOD 256);
					INC(offset); number := number DIV 256;
					code[offset] := CHR(number MOD 256);
					INC(offset); number := number DIV 256;
					code[offset] := CHR(number MOD 256);
				END Put32;

			BEGIN
				offset := (l.fixupSection.offset +l.fixup.offset );first := offset;
				l := l.nextFixup;
				WHILE l # NIL DO
					Put32(offset,(l.fixupSection.offset +l.fixup.offset ));
					offset := (l.fixupSection.offset +l.fixup.offset );
					l := l.nextFixup;
				END;
				Put32(offset,FixupSentinel);
				RETURN first;
			END FixupList;

		BEGIN
			w.Char(86X);
			numberLinks := 0;
			(* system call sections removed: replaced by procedure calls *)

			IF procedureFixupOffset #-1 THEN
				w.Char(0X); w.Char(SysCallMap[ProcAddr]); w.RawNum(procedureFixupOffset);
				INC(numberLinks);
			END;
			IF caseTableSize > 0 THEN
				w.Char(0X); w.Char(SysCallMap[CaseTable]); w.RawNum((constSize -caseTableSize *4));
				INC(numberLinks);
				(* case table is fixuped by the loader using offset of case table in constant section
					it is impossible to have disjoint case tables here
				*)
			END;

			counter := 0;
			(* cf. Entries *)
			FOR i := 0 TO symbols.Length() - 1 DO
				p := symbols.GetSection(i);
				IF (p.symbol # NIL) & (p.symbol IS SyntaxTree.Procedure) & ~p.symbol(SyntaxTree.Procedure).isInline THEN
				fixup := p.fixups;
				procedure := p.symbol(SyntaxTree.Procedure);
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				IF (procedure.access * SyntaxTree.Public # {}) OR (procedureType.isDelegate) OR (fixup # NIL) THEN
					w.RawNum(p.numberFixups);
					INC(counter);
					END
				END
			END;
			ASSERT(counter = numberEntries);
			w.RawNum((caseTableSize ));
		END Links;

		(* Constants = 87X {character:1} *)
		PROCEDURE Constants;
		VAR i: LONGINT;
		BEGIN
			w.Char(87X);
			FOR i := 0 TO ((constSize-1) ) DO
				w.Char(const[i]);
				crc32.Char(const[i]);
			END;
		END Constants;

		(* Exports *)
		PROCEDURE Exports;
		VAR numberExports,numberExportsPosition: LONGINT; constant: SyntaxTree.Constant;
			variable: SyntaxTree.Variable; procedure : SyntaxTree.Procedure; typeDeclaration : SyntaxTree.TypeDeclaration;
			typeNumber: LONGINT; name: ARRAY 256 OF CHAR;

			PROCEDURE ExportType(type: SyntaxTree.Type);
			VAR destination: Section; ref: LONGINT; count: LONGINT; countPos: LONGINT;
				variable: SyntaxTree.Variable; procedure: SyntaxTree.Procedure; fingerPrint: SyntaxTree.FingerPrint;
				initialType: SyntaxTree.Type;
			BEGIN
				IF type = NIL THEN RETURN END; (* no type *)

				type := type.resolved;

				(* fof: thjs can cause a repetitive entry of the same type *)
				initialType := type;
				WHILE (type IS SyntaxTree.PointerType) OR (type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.MathArrayType) DO
					IF type IS SyntaxTree.PointerType THEN
						type := type(SyntaxTree.PointerType).pointerBase.resolved;
					ELSIF type IS SyntaxTree.ArrayType THEN
						type := type(SyntaxTree.ArrayType).arrayBase.resolved;
					ELSE
						type := type(SyntaxTree.MathArrayType).arrayBase.resolved;
					END;
					IF type = initialType THEN RETURN END; (* avoid cycles *)
				END;


				IF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).recordScope.ownerModule = module.module)  THEN
					w.Char(ofEURecord);
					destination := symbols.BySymbol(type.typeDeclaration);
					ASSERT(destination # NIL);

					ref := destination.entryNumber;
					IF ref # 0 THEN
						w.RawNum(-ref);
						IF Trace THEN D.Str("already referenced as "); D.Int(ref,1); D.Ln END;
					ELSE
						count := 0; (* number of exported entries *)
						INC(typeNumber); (* reference number to this type *)
						destination.SetEntryNumber(typeNumber);
						IF Trace THEN D.Str("register as "); D.Int(typeNumber,1); D.Ln END;
						w.RawNum((destination.offset ));
						countPos := w.Pos();
						w.RawLInt(2);
						ExportType(type(SyntaxTree.RecordType).baseType);
						fingerPrint := fingerprinter.TypeFP(type);
						(*
						ASSERT(fingerPrint.privateFP # 0); (* may not be zero by object file format: would be interpreted as end of section *)
						ASSERT(fingerPrint.publicFP # 0); (* ^ ^ *)
						*)
						IF Trace THEN D.Str("export type fp "); D.Int(fingerPrint.private,1); D.Str(","); D.Int(fingerPrint.public,1); D.Ln END;
						w.RawNum(fingerPrint.private); w.RawNum(fingerPrint.public);
						variable := type(SyntaxTree.RecordType).recordScope.firstVariable;
						WHILE variable # NIL DO
							IF variable.access * SyntaxTree.Public # {} THEN
								fingerPrint := fingerprinter.SymbolFP(variable);
								w.RawNum(fingerPrint.shallow);
								ExportType(variable.type);
								INC(count);
							END;
							variable := variable.nextVariable;
						END;
						procedure := type(SyntaxTree.RecordType).recordScope.firstProcedure;
						WHILE procedure # NIL DO
							IF (procedure.access * SyntaxTree.Public # {}) & ~(procedure.isInline) THEN
								fingerPrint := fingerprinter.SymbolFP(procedure);
								w.RawNum(fingerPrint.shallow);
								INC(count);
							END;
							procedure := procedure.nextProcedure;
						END;
						IF count # 0 THEN RawLIntAt(countPos,count+2) END;
						w.Char(ofEUEnd);
					END;
				END;
			END ExportType;

			PROCEDURE SymbolOffset(symbol: SyntaxTree.Symbol): LONGINT;
			VAR s: Section; name: SyntaxTree.IdentifierString;
			BEGIN
				IF (symbol IS SyntaxTree.Procedure) & (symbol(SyntaxTree.Procedure).isInline) THEN
					RETURN 0
				END;
				symbol.GetName(name); (* debugging *)
				s := symbols.BySymbol(symbol); (* TODO *)
				ASSERT(s#NIL);
				RETURN (s.offset);
			END SymbolOffset;

			PROCEDURE ExportSymbol(symbol: SyntaxTree.Symbol; offset: LONGINT;CONST prefix: ARRAY OF CHAR);
			VAR fingerPrint: SyntaxTree.FingerPrint; fp: LONGINT;
			BEGIN

				fingerPrint := fingerprinter.SymbolFP(symbol);
				fp := fingerPrint.shallow;

				(*
				IF prefix # "" THEN (* make unique by object name prefix *)
					FingerPrint.FPString(fp,prefix)
				END;
				*)

				w.RawNum(fp);
				(*! check for duplicate fingerprint *)
				w.RawNum(offset );

				IF Trace  THEN
					symbol.GetName(name);
					D.Str("FoxObjectFile.Exports.ExportSymbol ");
					IF prefix # "" THEN D.Str(prefix); D.Str(".") END;
					D.Str(name);
					D.Str(" : ");
					D.Hex(fp,-8); D.Ln;
				END;

			END ExportSymbol;

			PROCEDURE ExportMethods(typeDeclaration: SyntaxTree.TypeDeclaration);
			VAR name: SyntaxTree.IdentifierString; type: SyntaxTree.Type;  fingerPrint: SyntaxTree.FingerPrint; initialType: SyntaxTree.Type;
			BEGIN
				type := typeDeclaration.declaredType;
				typeDeclaration.GetName(name);
				type := type.resolved; initialType := type;
				WHILE (type IS SyntaxTree.PointerType) OR (type IS SyntaxTree.ArrayType) OR (type IS SyntaxTree.MathArrayType) DO
					IF type IS SyntaxTree.PointerType THEN
						type := type(SyntaxTree.PointerType).pointerBase.resolved;
					ELSIF type IS SyntaxTree.ArrayType THEN
						type := type(SyntaxTree.ArrayType).arrayBase.resolved;
					ELSE
						type := type(SyntaxTree.MathArrayType).arrayBase.resolved;
					END;
					IF type = initialType THEN RETURN END; (* avoid circles *)
				END;
				IF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).recordScope.ownerModule = module.module)  THEN
					fingerPrint := fingerprinter.TypeFP(type); (* make sure that fingerprint has traversed all methods ... *)
					procedure := type(SyntaxTree.RecordType).recordScope.firstProcedure;
					WHILE procedure # NIL DO
						IF (procedure.access * SyntaxTree.Public # {}) THEN
							ExportSymbol(procedure,SymbolOffset(procedure),name);
							INC(numberExports);
						END;
						procedure := procedure.nextProcedure;
					END;
				END;
			END ExportMethods;

		BEGIN
			w.Char(88X);
			numberExports := 0; typeNumber := 0;
			numberExportsPosition := w.Pos();
			w.RawLInt(numberExports);
			(*! in the end anything that has an offset should be present in the BackendStructures.Module,
			therefore the list can also be traverse from the respective Backend structure *)
			(* constants *)
			constant := moduleScope.firstConstant;
			WHILE constant # NIL DO
				IF (constant.access * SyntaxTree.Public # {})  THEN
					IF Trace THEN
						constant.GetName(name);
						D.String("Constant:"); D.String(name); D.Ln;
					END;
					IF (~(constant.type IS SyntaxTree.BasicType)) THEN
						ExportSymbol(constant,SymbolOffset(constant),"");
					ELSE
						ExportSymbol(constant,0,"")
					END;
					INC(numberExports);
				END;
				constant := constant.nextConstant;
			END;
			(* global variables *)
			variable := moduleScope.firstVariable;
			WHILE variable # NIL DO
				IF variable.access * SyntaxTree.Public # {} THEN
					IF Trace THEN
						variable.GetName(name);
						D.String("Variable:"); D.String(name); D.Ln;
					END;
					ExportSymbol(variable,SymbolOffset(variable),"");
					ExportType(variable.type);
					INC(numberExports);
				END;
				variable := variable.nextVariable;
			END;
			(* type declarations *)
			typeDeclaration := moduleScope.firstTypeDeclaration;
			WHILE typeDeclaration # NIL DO
				IF TRUE (* typeDeclaration.access * SyntaxTree.Public # {} *) THEN
					IF Trace THEN
						typeDeclaration.GetName(name);
						D.String("TypeDeclaration:"); D.String(name); D.Ln;
					END;
					ExportSymbol(typeDeclaration,0,"");
					ExportType(typeDeclaration.declaredType);
					INC(numberExports);
				END;
				typeDeclaration := typeDeclaration.nextTypeDeclaration
			END;
			(* exported procedures *)
			procedure := moduleScope.firstProcedure;
			WHILE procedure # NIL DO
				IF (procedure.access* SyntaxTree.Public # {}) THEN
					IF Trace THEN
						procedure.GetName(name);
						D.String("Procedure:"); D.String(name); D.Ln;
					END;
					ExportSymbol(procedure,SymbolOffset(procedure),"");
					INC(numberExports);
				END;
				procedure := procedure.nextProcedure;
			END;
			(* exported methods *)
			typeDeclaration := moduleScope.firstTypeDeclaration;
			WHILE typeDeclaration # NIL DO
				IF typeDeclaration.access * SyntaxTree.Public # {} THEN
					ExportMethods(typeDeclaration);
				END;
				typeDeclaration := typeDeclaration.nextTypeDeclaration
			END;

			RawLIntAt(numberExportsPosition,numberExports);
			w.Char(0X);
		END Exports;


		(* Code = 89X {character:1} *)
		PROCEDURE Code;
		VAR i: LONGINT;
		BEGIN
			w.Char(89X);
			FOR i := 0 TO ((codeSize-1) ) DO
				w.Char(code[i]);
				crc32.Char(code[i]);
			END;
		END Code;

		(*
			Use = 08AX {UsedModules} 0X
			UsedModules = moduleName:String {UsedConstant | UsedVariable | UsedProcedure | UsedType } 0X
			UsedConstant = FP:Number constName:String 0X
			UsedVariable = FP:Number varName:String fixlist:Number [1X UsedRecord]
			UsedProcedure = FP:Number procName:String offset:Number
			UsedType = FP:Number typeName:String 0X [1X UsedRecord]
			UsedRecord = tdentry:Number [FP "@"] 0X
		*)
		PROCEDURE Use;
		VAR import: SyntaxTree.Import; name: SyntaxTree.IdentifierString; importedModule: SyntaxTree.Module; s: Section;
			constant: SyntaxTree.Constant; variable: SyntaxTree.Variable; typeDeclaration: SyntaxTree.TypeDeclaration; procedure: SyntaxTree.Procedure;
			type: SyntaxTree.Type;fixup: Fixup; fixups: LONGINT; sym: Section;

			PROCEDURE UseEntry(module: SyntaxTree.Module; symbol: SyntaxTree.Symbol; offsetInBytes: LONGINT; CONST prefix: ARRAY OF CHAR);
			VAR name,suffix: Basic.SectionName; fingerPrint: SyntaxTree.FingerPrint; fp: LONGINT;
			BEGIN
				symbol.GetName(suffix);
				IF prefix # "" THEN
					COPY(prefix,name); Strings.Append(name,"."); Strings.Append(name,suffix);
				ELSE
					name := suffix;
				END;
				fingerPrint := fingerprinter.SymbolFP(symbol);
				fp := fingerPrint.shallow;

				(*
				IF prefix # "" THEN FingerPrint.FPString(fp,prefix) END;
				*)

				w.RawNum(fp);
				IF Trace THEN
					D.Str("FoxObjectFile.Use ");
					D.Str(suffix);
					D.Str(" : "); D.Hex(SYSTEM.VAL(LONGINT,symbol),-8); D.Str(" : ");
					D.Hex(fp,-8);
					D.String(" @ ");
					D.Int(offsetInBytes-ofEUProcFlag,1);
					D.Ln;
				END;

				w.RawString(name);
				w.RawNum(offsetInBytes);
			END UseEntry;

			PROCEDURE UseType(type: SyntaxTree.Type);
			VAR t: Section; fingerPrint: SyntaxTree.FingerPrint; name: SyntaxTree.IdentifierString;
			BEGIN
				type := type.resolved;
				LOOP
					IF type IS SyntaxTree.PointerType THEN type := type(SyntaxTree.PointerType).pointerBase.resolved;
					ELSIF type IS SyntaxTree.ArrayType THEN type := type(SyntaxTree.ArrayType).arrayBase.resolved;
					ELSIF type IS SyntaxTree.MathArrayType THEN type := type(SyntaxTree.MathArrayType).arrayBase.resolved;
					ELSE EXIT
					END;
				END;

				IF type IS SyntaxTree.RecordType THEN
					WITH type: SyntaxTree.RecordType DO
						type.typeDeclaration.GetName(name); (* debugging *)
						IF type.recordScope.ownerModule = importedModule THEN (* type belongs to currently processed module *)
							IF Trace  THEN D.Str("UseTypeFP:"); D.Str(name); D.Str("?"); D.Ln END;
							t := symbols.BySymbol(type.typeDeclaration); (* TODO *)
							IF (t # NIL) & (t.referenced) (*(t.fixups # NIL)*) THEN
								t.referenced := FALSE;

								fingerPrint := fingerprinter.TypeFP(type);
								w.Char(ofEURecord);
								w.RawNum(-(t.offset ));
								(* privateFP never set in old compiler *)
								IF Trace  THEN D.Str("UseTypeFP:"); D.Str(name); D.Str(":"); D.Int(fingerPrint.public,1); D.Ln END;
								w.RawNum(fingerPrint.public);
								w.RawString("@");

								w.Char(ofEUEnd);
							END;
						ELSE
							(* nothing to be done? => module must be added to import section, this must be done by the semantic checker *)
						END
					END
				END

			END UseType;

			PROCEDURE UseMethods(typeDeclaration: SyntaxTree.TypeDeclaration);
			VAR procedure: SyntaxTree.Procedure; sym: Section; prefix: SyntaxTree.IdentifierString; fingerPrint: SyntaxTree.FingerPrint; type: SyntaxTree.Type;
				fixup: Fixup; fixups: LONGINT;
			BEGIN
				typeDeclaration.GetName(prefix);
				type := typeDeclaration.declaredType.resolved;
				LOOP
					IF type IS SyntaxTree.PointerType THEN type := type(SyntaxTree.PointerType).pointerBase.resolved;
					(*!???? => problems with name prefix. Necessary to treat arrays here?
					ELSIF type IS SyntaxTree.ArrayType THEN type := type(SyntaxTree.ArrayType).arrayBase.resolved;
					ELSIF type IS SyntaxTree.MathArrayType THEN type := type(SyntaxTree.MathArrayType).arrayBase.resolved;
					*)
					ELSE EXIT
					END;
				END;

				IF (type IS SyntaxTree.RecordType) & (type.scope.ownerModule = importedModule) (* do not take alias *) THEN

					fingerPrint := fingerprinter.TypeFP(type); (* make sure that type is fingerprinted including all methods *)

					procedure := type(SyntaxTree.RecordType).recordScope.firstProcedure;
					WHILE procedure # NIL DO
						sym := importedSymbols.BySymbol(procedure);
						IF sym # NIL THEN
							fixup := sym.fixups;
							UseEntry(importedModule,procedure,(fixup.fixupSection.offset + fixup.fixup.offset )+ofEUProcFlag,prefix);
						END;
						procedure := procedure.nextProcedure
					END
				END
			END UseMethods;

		BEGIN
			w.Char(08AX);
			import := moduleScope.firstImport;
			WHILE(import # NIL) DO (*! in a new object file this would not necessarily be ordered by imports (?) *)
				IF (import.module # module.system.systemModule[import.module.case]) & IsFirstOccurence(import) THEN
					importedModule := import.module;
					ASSERT(importedModule # NIL);
					ASSERT(importedModule # module.system.systemModule[0]);
					ASSERT(importedModule # module.system.systemModule[1]);

					Global.ModuleFileName(import.module.name,import.module.context,name);
					w.RawString(name);
					IF Trace THEN
						D.Str("Use module : "); D.Str(name); D.Ln;
					END;

					constant := importedModule.moduleScope.firstConstant;
					WHILE constant # NIL DO
						sym := importedSymbols.BySymbol(constant);
						IF sym # NIL THEN UseEntry(importedModule,constant,0,"") END;
						constant := constant.nextConstant
					END;
					variable := importedModule.moduleScope.firstVariable;
					WHILE variable # NIL DO
						sym :=  importedSymbols.BySymbol(variable);
						IF sym # NIL THEN
							UseEntry(importedModule,variable,sym.entryNumber,"");
							UseType(variable.type);
						END;
						variable := variable.nextVariable
					END;
					typeDeclaration := importedModule.moduleScope.firstTypeDeclaration;
					WHILE typeDeclaration # NIL DO
						type := typeDeclaration.declaredType;
						IF type IS SyntaxTree.PointerType THEN type := type(SyntaxTree.PointerType).pointerBase END;
						sym := symbols.BySymbol(typeDeclaration); (* only if has been used -- contained in module sections: alias *)
						IF (sym # NIL) & (sym.referenced) THEN
							UseEntry(importedModule,typeDeclaration,0,"");
							UseType(typeDeclaration.declaredType);
						END;
						typeDeclaration := typeDeclaration.nextTypeDeclaration
					END;

					procedure := importedModule.moduleScope.firstProcedure;
					WHILE procedure # NIL DO
						IF ~procedure.isInline THEN
							sym := importedSymbols.BySymbol(procedure);
							IF sym # NIL THEN
								fixup := sym.fixups;
								UseEntry(importedModule,procedure,(fixup.fixupSection.offset + fixup.fixup.offset )+ofEUProcFlag,"");
							END;
						END;
						procedure := procedure.nextProcedure
					END;

					typeDeclaration := importedModule.moduleScope.firstTypeDeclaration;
					WHILE typeDeclaration # NIL DO
						IF ~(typeDeclaration.declaredType IS SyntaxTree.QualifiedType) (* alias *) THEN
							UseMethods(typeDeclaration);
						END;
						typeDeclaration := typeDeclaration.nextTypeDeclaration
					END;

					w.Char(0X);
				END;
				import := import.nextImport;
			END;

			w.Char(0X);
		END Use;

		PROCEDURE WriteType(d:Section; type: SyntaxTree.RecordType; VAR tdSize: LONGINT (* ug *));
		CONST MaxTags = 16; (* ug: temporary solution, Modules.MaxTags *)
		VAR
			tdSizePos, oldmth,newmeth: LONGINT;  base: SyntaxTree.RecordType;
			name: SyntaxTree.IdentifierString;
			baseModule: LONGINT; baseEntry: LONGINT;
			upperPartTdSize, lowerPartTdSize: LONGINT;
			size: LONGINT;

			numberPointersPosition: LONGINT;
			numberPointers: LONGINT;
			destination: Section;
			procedure: Section;
			fp: SyntaxTree.FingerPrint;
			m: SyntaxTree.Procedure;
			i: LONGINT;
			typeDeclaration: SyntaxTree.TypeDeclaration;

		BEGIN
			name := "@@";
			ASSERT(type.typeDeclaration # NIL);
			type.typeDeclaration.GetName(name);
			size := module.system.AlignedSizeOf(type) DIV 8;
			w.RawNum(size );
			w.RawNum((d.offset )); (* type descriptor pointer address, patched by loader to type desciptor address *)

			base := type.GetBaseRecord();
			IF (base = NIL)  THEN (* no base type *)
				oldmth := 0;
				baseModule := -1;
				baseEntry := -1
			ELSE
				baseModule := 0; (* base type in local module *)
				IF (base.typeDeclaration # NIL) & (base.typeDeclaration.scope # NIL) & (base.typeDeclaration.scope.ownerModule # moduleScope.ownerModule) THEN (* base type in other module *)
					baseModule := ModuleNumber(base.typeDeclaration.scope.ownerModule);
					typeDeclaration := base.typeDeclaration;
					ASSERT(baseModule # 0);
				ELSE
					typeDeclaration := NIL;
				END;
				IF baseModule = 0 THEN
					destination := symbols.BySymbol(base.typeDeclaration); (*TODO*)
					ASSERT(destination # NIL);
					baseEntry := (destination.offset );  (* destination must be non-nil *)
				ELSIF (typeDeclaration # NIL) THEN
					fp := fingerprinter.SymbolFP(typeDeclaration);
					baseEntry := fp.shallow;
				ELSE
					HALT(100);
				(* ELSE
					base := base(SyntaxTree.PointerType).pointerBase;
					fp := fingerprinter.SymbolFP(base.typeDeclaration);
					baseEntry := fp.FP;
				*)
				END;
				oldmth := base.recordScope.numberMethods;
			END;
			w.RawNum(baseModule);
			w.RawNum(baseEntry);

			newmeth := 0;
			m := type.recordScope.firstProcedure;
			WHILE (m# NIL) DO
				INC(newmeth); (*! check that this is not an inline procedure *)
				m := m.nextProcedure;
			END;

			IF type.IsProtected()  THEN
				w.RawNum(-type.recordScope.numberMethods); 	(* number methods total *)
			ELSE
				w.RawNum(type.recordScope.numberMethods); 	(* number methods total *)
			END;
			w.RawNum(oldmth); 				(* inherited methods total *)
			w.RawNum(newmeth); 				(* new methods (overridden or new) *)
			numberPointersPosition:= w.Pos();
			w.RawLInt(0);
			w.RawString(name);
			tdSizePos := w.Pos();
			w.RawLInt(0);

			i := 0;
			m := type.recordScope.firstProcedure;
			WHILE (m#NIL) DO
				IF ~(m.isInline) THEN
					procedure := symbols.BySymbol(m); (*TODO*)
					ASSERT(procedure # NIL);
					m.GetName(name);

					w.RawNum(procedure.symbol(SyntaxTree.Procedure).methodNumber);
					w.RawNum(procedure.entryNumber);
					INC(i);
				END;
				m := m.nextProcedure;
			END;

			(* Ptrs in Record *)
			numberPointers := 0;
			IF Trace THEN D.Str("pointers of type: "); D.Ln; END;
			OutPointers(0, type, numberPointers);  (* debug = FALSE *)

			IF numberPointers # 0 THEN RawLIntAt(numberPointersPosition,numberPointers) END;

			(* ug *)	upperPartTdSize := module.system.addressSize DIV 8 * (MaxTags + type.recordScope.numberMethods  + 1 + 1); (* tags, methods, methods end marker (sentinel), address of TypeInfo *)
			(* ug *)	lowerPartTdSize := module.system.addressSize DIV 8 * (2 + (4 + numberPointers) + 1);
			(* ug *)	tdSize := upperPartTdSize + lowerPartTdSize;

			(* ug *)	RawLIntAt(tdSizePos, tdSize)	;
		END WriteType;

		PROCEDURE Types;
		VAR
			t: Section; tdSize, i: LONGINT;
			typeDeclaration: SyntaxTree.TypeDeclaration; type: SyntaxTree.Type;
			name: ARRAY 256 OF CHAR;
		BEGIN
			w.Char(08BX);
			numberTypes := 0; typeDescSize := 0;

			FOR i := 0 TO symbols.Length() - 1 DO
				t := symbols.GetSection(i);
				IF (t.symbol # NIL) & (t.symbol IS SyntaxTree.TypeDeclaration) THEN
					typeDeclaration := t.symbol(SyntaxTree.TypeDeclaration);
					type := typeDeclaration.declaredType;
					typeDeclaration.GetName(name);
					IF type IS SyntaxTree.PointerType THEN
						IF type(SyntaxTree.PointerType).pointerBase.resolved.typeDeclaration = typeDeclaration THEN (* avoid duplicate declarations *)
							 type := type(SyntaxTree.PointerType).pointerBase.resolved;
						END;
					END;
					IF Trace THEN D.Str("FoxObjectFile.Types: "); D.String(name); D.Ln; END;
					IF (type IS SyntaxTree.RecordType) & (type(SyntaxTree.RecordType).recordScope.ownerModule = moduleScope.ownerModule) OR (type(SyntaxTree.RecordType).recordScope.ownerModule = NIL) THEN
						t := symbols.BySymbol(type.typeDeclaration);
						ASSERT(t # NIL);
						WriteType(t,type(SyntaxTree.RecordType),tdSize);
						INC(typeDescSize,tdSize);
						INC(numberTypes);
					END;
				END
			END
		END Types;

		(* 	Stores the exception handle table in the following format
			ExceptionHandlerTable 	::= 8EX {ExceptionTableEntry}
			ExceptionTableEntry 	::= 0FFX pcFrom(4 bytes) pcTo(4 bytes) pcHandler(4 bytes)

			Since there is only one FINALLY  in every procedure, method, body, ... we don't need
			to obtain an order for nesting.
		*)
		PROCEDURE ExceptionTable;
		VAR
			p: Section; pcFrom, pcTo, pcHandler, i: LONGINT;
			binarySection: BinaryCode.Section;
		BEGIN
			exTableLen := 0;
			w.Char(08EX);

			FOR i := 0 TO symbols.Length() - 1 DO
				p := symbols.GetSection(i);
				IF (p.type = Sections.CodeSection) OR (p.type= Sections.BodyCodeSection) THEN
					binarySection := p.resolved;
					IF binarySection.finally >= 0 THEN
						pcFrom := p.offset;
						pcTo := binarySection.finally+pcFrom;
						pcHandler := binarySection.finally+pcFrom;
						w.Char(0FEX);
						w.RawNum(pcFrom);
						w.RawNum(pcTo);
						w.RawNum(pcHandler);
						INC(exTableLen);
					END;
				END
			END;

		END ExceptionTable;

		PROCEDURE PtrsInProcBlock;
		VAR
			i, counter: LONGINT; destination: Section;

			PROCEDURE PointerOffsets(destination : Section);
			VAR
				numberPointers,numberPointersPos: LONGINT; procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
				variable: SyntaxTree.Variable; parameter: SyntaxTree.Parameter;
			BEGIN
				(*!
				ASSERT(destination.offset <= destination.beginOffset);
				ASSERT(destination.beginOffset <= destination.endOffset);
				*)

				w.RawNum((destination.offset ));
				w.RawNum(destination.offset+destination.resolved.validPAFEnter);
				w.RawNum(destination.offset+destination.resolved.validPAFExit);
				(*!
				w.RawNum(destination.beginOffset);
				w.RawNum(destination.endOffset);
				*)
				numberPointers := 0;
				numberPointersPos := w.Pos();
				w.RawLInt(0);
				procedure := destination.symbol(SyntaxTree.Procedure);
				procedureType := procedure.type(SyntaxTree.ProcedureType);
				variable := procedure.procedureScope.firstVariable;
				WHILE(variable # NIL) DO
					IF ~(variable.untraced) THEN
						OutPointers(variable.offsetInBits DIV 8,variable.type,numberPointers);
					END;
					variable := variable.nextVariable
				END;
				parameter := procedureType.firstParameter;
				WHILE(parameter # NIL) DO
					IF ~(parameter.untraced) THEN
						OutPointers(parameter.offsetInBits DIV 8,parameter.type,numberPointers);
					END;
					parameter := parameter.nextParameter;
				END;
				(*
				parameter := procedureType.selfParameter;
				IF parameter # NIL THEN
					OutPointers(parameter.offsetInBits DIV 8,parameter.type,numberPointers);
				END;
				*)
				RawLIntAt(numberPointersPos,numberPointers);
				IF numberPointers > maxPtrs THEN
					maxPtrs := numberPointers
				END;
			END PointerOffsets;

		BEGIN
			w.Char(08FX);
			IF Trace THEN D.Str("FoxObjectFile.PtrsInProcBlock"); D.Ln; END;
			maxPtrs := 0;
			counter := 0;
			FOR i := 0 TO symbols.Length() - 1 DO
				destination := symbols.GetSection(i);
				IF (destination.type # Sections.InitCodeSection) & (destination.symbol # NIL) & (destination.symbol IS SyntaxTree.Procedure) & ~destination.symbol(SyntaxTree.Procedure).isInline THEN
					IF Trace THEN D.Str("pointers in "); Basic.WriteSegmentedName(D.Log,destination.name); D.Ln END;
					PointerOffsets(destination);
					INC(counter);
				END
			END;
			numberProcs := counter;
		END PtrsInProcBlock;

		PROCEDURE References;
		CONST
			rfDirect = 1X; rfIndirect = 3X;
			rfStaticArray= 12X; rfDynamicArray=14X; rfOpenArray=15X;
			rfByte = 1X; rfBoolean = 2X; rfChar8=3X; rfShortint=04X; rfInteger = 05X; rfLongint = 06X;
			rfReal = 07X; rfLongreal = 08X; rfSet = 09X; rfDelegate = 0EX;  rfString = 0FH; rfPointer = 0DX; rfHugeint = 10X;
			rfChar16=11X; rfChar32=12X; rfAll=13X; rfSame=14X; rfRange=15X; rfRecord=16X; rfComplex = 17X; rfLongcomplex = 18X;
			rfRecordPointer=1DX;
			rfArrayFlag = 80X;
		VAR
			start, i: LONGINT; s: Section;

			PROCEDURE BaseType(type: SyntaxTree.Type): CHAR;
			VAR char: CHAR;
			BEGIN
				IF type = NIL THEN char := rfLongint
				ELSIF type  IS SyntaxTree.ByteType THEN char := rfByte
				ELSIF type IS SyntaxTree.BooleanType THEN char := rfBoolean
				ELSIF type IS SyntaxTree.CharacterType THEN
					IF type.sizeInBits = 8 THEN char := rfChar8
					ELSIF type.sizeInBits = 16 THEN char := rfChar16
					ELSIF type.sizeInBits = 32 THEN char := rfChar32
					END;
				ELSIF (type IS SyntaxTree.IntegerType) OR (type IS SyntaxTree.AddressType) OR (type IS SyntaxTree.SizeType) THEN
					IF type.sizeInBits = 8 THEN char := rfShortint
					ELSIF type.sizeInBits = 16 THEN char := rfInteger
					ELSIF type.sizeInBits = 32 THEN char := rfLongint
					ELSIF type.sizeInBits =64 THEN char := rfHugeint
					END;
				ELSIF type IS SyntaxTree.SizeType THEN char := rfLongint
				ELSIF type IS SyntaxTree.FloatType THEN
					IF type.sizeInBits = 32 THEN char := rfReal
					ELSIF type.sizeInBits = 64 THEN char := rfLongreal
					END;
				ELSIF type IS SyntaxTree.ComplexType THEN
					IF type.sizeInBits = 64 THEN char := rfComplex
					ELSIF type.sizeInBits = 128 THEN char := rfLongcomplex
					END;
				ELSIF type IS SyntaxTree.SetType THEN char := rfSet
				ELSIF type IS SyntaxTree.AnyType THEN char := rfPointer
				ELSIF type IS SyntaxTree.ObjectType THEN char := rfPointer
				ELSIF type IS SyntaxTree.PointerType THEN char := rfPointer
				ELSIF type IS SyntaxTree.ProcedureType THEN char := rfDelegate
				ELSIF type IS SyntaxTree.RangeType THEN char := rfRange
				ELSE char := rfShortint; (*RETURN (* ARRAY OF unknown (record): do not write anything *)*)
				END;
				RETURN char
			END BaseType;

			PROCEDURE RecordType(type: SyntaxTree.RecordType);
			VAR destination: Section; name: SyntaxTree.IdentifierString;
			BEGIN
				destination := symbols.BySymbol(type.typeDeclaration);
				IF destination = NIL THEN destination := importedSymbols.BySymbol(type.typeDeclaration) END;

				IF destination = NIL THEN
					(* imported unused record type *)
					w.Char(0X); (* nil type *)
					type.typeDeclaration.GetName(name);
					(*
					this happens when a symbol from a different module is used but the type desciptor is not necessary to be present in the current module
					D.Str("Warning: Unreferenced record type encountered: "); D.String(name); D.String(" unused? "); D.Ln;
					*)
				ELSE
					IF type.pointerType # NIL THEN
						w.Char(rfRecordPointer)
					ELSE
						w.Char(rfRecord);
					END;
					w.RawNum((destination.offset ));
				END;
			END RecordType;

			PROCEDURE StaticArrayLength(type: SyntaxTree.ArrayType; VAR baseType: SyntaxTree.Type): LONGINT;
			BEGIN
				baseType := type.arrayBase.resolved;
				IF type.form = SyntaxTree.Static THEN
					IF baseType IS SyntaxTree.ArrayType THEN
						RETURN type.staticLength * StaticArrayLength(baseType(SyntaxTree.ArrayType),baseType)
					ELSE
						RETURN type.staticLength
					END
				ELSE
					RETURN 0
				END;
			END StaticArrayLength;

			PROCEDURE ArrayType(type: SyntaxTree.ArrayType);
			VAR length: LONGINT; baseType: SyntaxTree.Type; char: CHAR;
			BEGIN
				length := StaticArrayLength(type, baseType);
				char := BaseType(baseType);
				IF type.form # SyntaxTree.Open THEN
					w.Char(CHR(ORD(char)+ORD(rfArrayFlag)));
					w.RawNum(length)
				ELSE
					length :=0;
					(*length := 1+SemanticChecker.Dimension(type,{SyntaxTree.Open});*)
					w.Char(CHR(ORD(char)+ORD(rfArrayFlag)));
					w.RawNum(length)
				END;
			END ArrayType;

			PROCEDURE StaticMathArrayLength(type: SyntaxTree.MathArrayType; VAR baseType: SyntaxTree.Type): LONGINT;
			BEGIN
				baseType := type.arrayBase;
				IF baseType # NIL THEN
					baseType := baseType.resolved;
				END;
				IF type.form = SyntaxTree.Static THEN
					IF (baseType # NIL) & (baseType IS SyntaxTree.MathArrayType) THEN
						RETURN type.staticLength * StaticMathArrayLength(baseType(SyntaxTree.MathArrayType),baseType)
					ELSE
						RETURN type.staticLength
					END
				ELSE
					RETURN 0
				END;
			END StaticMathArrayLength;

			PROCEDURE MathArrayType(type: SyntaxTree.MathArrayType);
			VAR length: LONGINT; baseType: SyntaxTree.Type; char: CHAR;
			BEGIN
				length := StaticMathArrayLength(type, baseType);
				char :=  BaseType(baseType);
				IF type.form = SyntaxTree.Open THEN
					char := BaseType(module.system.addressType);
					length := 5+2*SemanticChecker.Dimension(type,{SyntaxTree.Open});
					w.Char(CHR(ORD(char)+ORD(rfArrayFlag)));
					w.RawNum(length)
				ELSIF type.form=SyntaxTree.Tensor THEN
					char := BaseType(module.system.addressType);
					w.Char(CHR(ORD(char)));
				ELSE
					w.Char(CHR(ORD(char)+ORD(rfArrayFlag)));
					w.RawNum(length)
				END;
			END MathArrayType;

			PROCEDURE Type(type: SyntaxTree.Type);
			BEGIN
				IF type = NIL THEN w.Char(0X); RETURN ELSE type := type.resolved END;

				IF type IS SyntaxTree.BasicType THEN
					w.Char(BaseType(type))
				ELSIF type IS SyntaxTree.RecordType THEN
					RecordType(type(SyntaxTree.RecordType));
				ELSIF type IS SyntaxTree.ArrayType THEN
					ArrayType(type(SyntaxTree.ArrayType))
				ELSIF type IS SyntaxTree.EnumerationType THEN
					w.Char(BaseType(module.system.longintType))
				ELSIF type IS SyntaxTree.PointerType THEN
					IF type(SyntaxTree.PointerType).pointerBase IS SyntaxTree.RecordType THEN
						RecordType(type(SyntaxTree.PointerType).pointerBase(SyntaxTree.RecordType));
					ELSE
						w.Char(BaseType(type))
					END;
				ELSIF type IS SyntaxTree.ProcedureType THEN
					w.Char(BaseType(type));
				ELSIF type IS SyntaxTree.MathArrayType THEN
					MathArrayType(type(SyntaxTree.MathArrayType));
				ELSE HALT(200)
				END;
			END Type;

			PROCEDURE WriteVariable(variable: SyntaxTree.Variable; indirect: BOOLEAN);
				VAR name: ARRAY 256 OF CHAR;
			BEGIN
				IF variable.externalName # NIL THEN RETURN END;
				IF indirect THEN w.Char(rfIndirect) ELSE w.Char(rfDirect) END;
				variable.GetName(name);
				Type(variable.type);
				w.RawNum((variable.offsetInBits DIV 8));
				w.RawString(name);
			END WriteVariable;

			PROCEDURE WriteParameter(variable: SyntaxTree.Parameter; indirect: BOOLEAN);
			VAR name: ARRAY 256 OF CHAR;
			BEGIN
				IF indirect THEN w.Char(rfIndirect) ELSE w.Char(rfDirect) END;
				variable.GetName(name);
				Type(variable.type);
				w.RawNum((variable.offsetInBits DIV 8));
				variable.GetName(name);
				w.RawString(name);
			END WriteParameter;

			PROCEDURE ReturnType(type: SyntaxTree.Type);
			BEGIN
				IF type = NIL THEN w.Char(0X); RETURN ELSE type := type.resolved END;

				IF type IS SyntaxTree.ArrayType THEN
					WITH type: SyntaxTree.ArrayType DO
						IF type.form = SyntaxTree.Static THEN w.Char(rfStaticArray)
						ELSE w.Char(rfOpenArray)
						END
					END
				ELSIF type IS SyntaxTree.MathArrayType THEN
					WITH type: SyntaxTree.MathArrayType DO
						IF type.form = SyntaxTree.Static THEN w.Char(rfStaticArray)
						ELSE w.Char(rfOpenArray)
						END
					END
				ELSIF type IS SyntaxTree.RecordType THEN
					w.Char(rfRecord);
				ELSE
					w.Char(BaseType(type));
				END;
			END ReturnType;

			PROCEDURE DeclarationName(typeDeclaration: SyntaxTree.TypeDeclaration; VAR name: ARRAY OF CHAR);
			BEGIN
				IF typeDeclaration = NIL THEN COPY("@ANONYMOUS",name)
				ELSE typeDeclaration.GetName(name)
				END;
			END DeclarationName;


			PROCEDURE Procedure(s: Section);
			VAR procedure: SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
				 parameter: SyntaxTree.Parameter; variable: SyntaxTree.Variable;
				 name,recordName: ARRAY 256 OF CHAR;
				 record: SyntaxTree.RecordType;  i: LONGINT;


			BEGIN
				procedure := s.symbol(SyntaxTree.Procedure); (*! check for variable or type symbol for object body *)
				(*procedure.name,name);*)
				Global.GetSymbolNameInScope(procedure,moduleScope,name);
				procedureType := procedure.type(SyntaxTree.ProcedureType);


				w.Char(0F9X);
				w.RawNum((s.offset ));
				w.RawNum(procedureType.numberParameters);
				ReturnType(procedureType.returnType);
				w.RawNum(0); (*! level *)
				w.RawNum(0);
				(*
				IF procedure.scope IS SyntaxTree.RecordScope THEN (* add object name *)
					record := procedure.scope(SyntaxTree.RecordScope).ownerRecord;
					recordName := "";
					IF record.pointerType # NIL THEN
						DeclarationName(record.pointerType.typeDeclaration,recordName);
					ELSE
						DeclarationName(record.typeDeclaration,recordName);
					END;
					i := 0;
					WHILE recordName[i] # 0X DO
						w.Char(recordName[i]); INC(i);
					END;
					w.Char(".");
				END;
				*)
				w.RawString(name);
				parameter := procedureType.firstParameter;
				WHILE(parameter # NIL) DO
					WriteParameter(parameter,parameter.kind # SyntaxTree.ValueParameter); (*!treat  exceptions !*)
					parameter := parameter.nextParameter;
				END;
				(*
				parameter := procedureType.selfParameter;
				IF parameter # NIL THEN
					WriteParameter(parameter,parameter.kind # SyntaxTree.ValueParameter); (*!treat  exceptions !*)
				END;
				*)
				variable := procedure.procedureScope.firstVariable;
				WHILE(variable # NIL) DO
					WriteVariable(variable,FALSE);
					variable := variable.nextVariable;
				END;
			END Procedure;

			PROCEDURE Scope(s: Section);
			VAR variable: SyntaxTree.Variable;
			BEGIN
				w.Char(0F8X);
				w.RawNum((s.offset ));
				w.RawString("$$");
				variable := moduleScope.firstVariable;
				WHILE(variable # NIL) DO
					WriteVariable(variable,FALSE);
					variable := variable.nextVariable;
				END;
			END Scope;


		BEGIN
			start := w.Pos();
			w.Char(08CX);

			FOR i := 0 TO symbols.Length() - 1 DO
				s := symbols.GetSection(i);
				IF (s.symbol = moduleScope.bodyProcedure) THEN
					Scope(s) (*! must be first procedure in ref section *)
				END
			END;

			FOR i := 0 TO symbols.Length() - 1 DO
				s := symbols.GetSection(i);
				IF (s.symbol = moduleScope.bodyProcedure) THEN (* already done, see above *)
				ELSIF(s.symbol # NIL) & (s.symbol IS SyntaxTree.Procedure) & ~s.symbol(SyntaxTree.Procedure).isInline THEN
					Procedure(s)
				END
			END;
			refSize := w.Pos()-start;
		END References;


		PROCEDURE LinkFixups;
		VAR
			section: Section; symbol: SyntaxTree.Symbol; fixups, i: LONGINT; fixup: Fixup; bfixup: BinaryCode.Fixup;

			PROCEDURE Put32(code: ByteArray; offset: LONGINT; number: LONGINT);
			BEGIN
				code[offset] := CHR(number MOD 256);
				INC(offset); number := number DIV 256;
				code[offset] := CHR(number MOD 256);
				INC(offset); number := number DIV 256;
				code[offset] := CHR(number MOD 256);
				INC(offset); number := number DIV 256;
				code[offset] := CHR(number MOD 256);
			END Put32;

			PROCEDURE Link(first: Fixup);
			VAR this,prev: LONGINT;fixup: Fixup;
			CONST Sentinel = LONGINT(0FFFFFFFFH);
			BEGIN
				fixup := first;
				prev := -1;
				WHILE fixup # NIL DO
					this :=  (fixup.fixupSection.offset +fixup.fixup.offset );
					IF prev # -1 THEN
						Put32(code,prev,this);
						IF Trace THEN
							D.String("link: "); D.Int(prev,1); D.String(":"); D.Int(this,1); D.Ln;
						END;
					END;
					prev := this;
					fixup := fixup.nextFixup;
				END;
				IF prev # -1 THEN
					Put32(code,prev,Sentinel);
					IF Trace THEN
						D.String("link: "); D.Int(prev,1); D.String(":"); D.Int(Sentinel,1); D.Ln;
					END;
				END;
			END Link;

		BEGIN
			IF Trace THEN D.Str("LinkFixups"); D.Ln; END;
			FOR i := 0 TO importedSymbols.Length()-1 DO
				section := importedSymbols.GetSection(i);
				symbol := section.symbol;
				IF (symbol # NIL) & (symbol IS SyntaxTree.Procedure) THEN
					Link(section.fixups);
				END;
			END;

		END LinkFixups;

		PROCEDURE MakeSections;
		VAR i: LONGINT; fixup: BinaryCode.Fixup; section: Sections.Section; symbol: Section;
			imported: BOOLEAN;

				PROCEDURE Enter(section: Sections.Section; symbols: SectionList; VAR symbol: Section): BOOLEAN;
				BEGIN
					IF section # NIL THEN
						symbol := symbols.AddSection(section.name);
						symbol.isCaseTable := section.isCaseTable;
						symbol.referenced := section.referenced;
						symbol.offset := section.offset;
						symbol.type := section.type;
						symbol.resolved := section(IntermediateCode.Section).resolved;
						IF (section.symbol # NIL) & (symbol.symbol = NIL) THEN
							symbol.symbol := section.symbol;
							symbols.symbolLookup.Put(symbol.symbol, symbol)
						END;
						RETURN TRUE
					ELSE
						RETURN FALSE
					END;
				END Enter;


		BEGIN
			NEW(symbols); NEW(importedSymbols);

			(* enter all sections first to keep ordering *)
			FOR i := 0 TO module.allSections.Length() - 1 DO
				section := module.allSections.GetSection(i);
				IF (section.type # Sections.InlineCodeSection) & (section.type # Sections.InitCodeSection) & ~section.isCaseTable THEN
					IF Enter(section, symbols,symbol) THEN END;
				END;
			END;

			FOR i := 0 TO module.allSections.Length() - 1 DO
				section := module.allSections.GetSection(i);
				IF (section.type # Sections.InlineCodeSection) & (section.type # Sections.InitCodeSection) & ~section.isCaseTable THEN
					(* IF Enter(section, symbols,symbol) THEN END;*)
					fixup := section(IntermediateCode.Section).resolved.fixupList.firstFixup;
					WHILE (fixup # NIL) DO
						IF Enter(module.allSections.FindByName(fixup.symbol.name), symbols,symbol) THEN
							symbol.AddFixup(fixup, section);
						END;
						IF Enter(module.importedSections.FindByName(fixup.symbol.name), importedSymbols,symbol) THEN
							symbol.AddFixup(fixup, section)
						END;
						fixup := fixup.nextFixup;
					END
				END
			END;

			IF Trace THEN
				D.String("imported sections(module) "); D.Ln;
				module.importedSections.Dump(D.Log); D.Ln;
				D.String("sections(module) "); D.Ln;
				module.allSections.Dump(D.Log); D.Ln;

				D.String("imported: "); D.Ln; importedSymbols.Dump(D.Log);
				D.String("not imported: "); D.Ln; symbols.Dump(D.Log);
				D.Ln;
			END;

		END MakeSections;


		(* ObjectFile =
			ofFileTag ofNoZeroCompression ofFileVersion
			SymbolFile
			Header
			Entries
			Commands
			Pointers
			Imports
			VarConstLinks
			Links
			Constants
			Exports
			Code
			Use
			Types
			ExceptionTable
			PtrsInProcBlock
			References
		*)
	BEGIN
		MakeSectionOffsets(module,constSize,dataSize,codeSize,caseTableSize,const,code);
		MakeSections;
		(* from here on we do not need IntermediateCode.Sections any more *)
		LinkFixups;

		IF Trace THEN module.Dump(D.Log);D.Ln; D.Update; END;

		NEW(fingerprinter,module.system);
		(* module.module.name,moduleName);*)
		Global.ModuleFileName(module.module.name,module.module.context,moduleName);
		NEW(crc32);

		IF Trace THEN D.Str("module: "); D.Str(moduleName); D.Ln END;
		moduleScope := module.module.moduleScope;
		w.Char(ofFileTag);
		w.Char(ofNoZeroCompress);
		w.Char(ofFileVersion);
		SymbolFile;
		Header; Entries; Commands; Pointers; Imports; VarConstLinks; Links;
		Constants; Exports; Code; Use; Types; ExceptionTable; PtrsInProcBlock; References;
		endPos := w.Pos();
		w.SetPos(headerPos);
		crc := crc32.GetCRC();
		Header;
		w.SetPos(endPos);
		w.Update;
	END WriteObjectFile;

	PROCEDURE Get*(): Formats.ObjectFileFormat;
	VAR objectFileFormat: ObjectFileFormat;
	BEGIN NEW(objectFileFormat); RETURN objectFileFormat
	END Get;

BEGIN
		SysCallMap[CaseTable] := 0FFX;
		SysCallMap[ProcAddr] := 0FEX;
		SysCallMap[NewRec] := 0FDX;
		SysCallMap[NewSys] := 0FCX;
		SysCallMap[NewArr] := 0FBX;
		SysCallMap[Start] := CHR(250);
		SysCallMap[Await] := CHR(249);
		SysCallMap[Lock] := CHR(247);
		SysCallMap[Unlock] := CHR(246);
		SysCallMap[InterfaceLookup] := CHR(245);
		SysCallMap[RegisterInterface] := CHR(244);
		SysCallMap[GetProcedure] := CHR(243);
END FoxBinaryObjectFile.
