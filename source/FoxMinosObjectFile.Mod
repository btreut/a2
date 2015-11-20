MODULE FoxMinosObjectFile; (** AUTHOR "fof"; PURPOSE "Oberon Compiler Minos Object File Writer"; *)

IMPORT
	Scanner := FoxScanner, Basic := FoxBasic, SyntaxTree := FoxSyntaxTree, Global := FoxGlobal, SemanticChecker := FoxSemanticChecker, FingerPrinter := FoxFingerPrinter, Sections := FoxSections,
	Streams, D := Debugging, Files, SYSTEM,Strings, BinaryCode := FoxBinaryCode, KernelLog, Diagnostics, SymbolFileFormat := FoxTextualSymbolFile, Options,
	Formats := FoxFormats, IntermediateCode := FoxIntermediateCode, Machine
	;


CONST
	Trace=FALSE;


TYPE Name=ARRAY 256 OF CHAR;
	ByteArray = POINTER TO ARRAY OF CHAR;

TYPE

	Fixup = OBJECT
	VAR
		nextFixup: Fixup;
		fixup: BinaryCode.Fixup;
		fixupSection: Sections.Section;
	END Fixup;

	ObjectFileFormat*= OBJECT (Formats.ObjectFileFormat)
	VAR extension,prefix: Basic.FileName;

		PROCEDURE Export*(module: Formats.GeneratedModule; symbolFileFormat: Formats.SymbolFileFormat): BOOLEAN;
		VAR symbolFile: Files.File; moduleName: SyntaxTree.IdentifierString; fileName: Files.FileName; f: Files.File; w: Files.Writer;
		VAR varSize, codeSize: LONGINT; VAR code: ByteArray; bodyOffset: LONGINT; error: BOOLEAN;
		BEGIN
			Global.ModuleFileName(module.module.name,module.module.context,moduleName);
			Basic.Concat(fileName,prefix,moduleName,extension);
			IF Trace THEN D.Str("FoxBinaryObjectFile.ObjectFileFormat.Export "); D.Str(moduleName); D.Ln; END;

			IF ~(module IS Sections.Module) THEN
				diagnostics.Error(module.module.sourceName,Diagnostics.Invalid,Diagnostics.Invalid,"generated module format does not match object file format");
				RETURN FALSE;
			ELSIF module.findPC # MAX(LONGINT) THEN
				MakeSectionOffsets(module(Sections.Module),varSize, codeSize, bodyOffset, code);
				RETURN FindPC(module.findPC,module(Sections.Module),diagnostics);
			ELSE
				WITH module: Sections.Module DO
					f := Files.New(fileName);
					ASSERT(f # NIL);
					NEW(w,f,0);

					error := ~WriteObjectFile(w,module,symbolFile, diagnostics);
					w.Update;
					Files.Register(f);
					RETURN ~error
				END;
			END;
		END Export;

		PROCEDURE DefineOptions*(options: Options.Options);
		BEGIN
			options.Add(0X,"objectFileExtension",Options.String);
			options.Add(0X,"objectFilePrefix",Options.String);
		END DefineOptions;

		PROCEDURE GetOptions*(options: Options.Options);
		BEGIN
			IF ~options.GetString("objectFileExtension",extension) THEN
				extension := ".arm"
			END;
			IF ~options.GetString("objectFilePrefix",prefix) THEN prefix := "" END
		END GetOptions;

		PROCEDURE DefaultSymbolFileFormat(): Formats.SymbolFileFormat;
		BEGIN RETURN SymbolFileFormat.Get();
		END DefaultSymbolFileFormat;

		PROCEDURE ForceModuleBodies(): BOOLEAN; (* necessary in binary object file format as bodies not recognizable later on *)
		BEGIN RETURN TRUE
		END ForceModuleBodies;

		PROCEDURE GetExtension(VAR ext: ARRAY OF CHAR);
		BEGIN COPY(extension, ext)
		END GetExtension;

	END ObjectFileFormat;

	(*
		this procedure converts the section-based representation of fixups into a symbol based representation
	*)
	PROCEDURE GetFixups(diagnostics: Diagnostics.Diagnostics; module: Sections.Module; symbol: Sections.Section; VAR first: Fixup): LONGINT;
	VAR temp: Fixup; fixup: BinaryCode.Fixup; nr :LONGINT; i: LONGINT; section: Sections.Section; sectionList: Sections.SectionList;

		PROCEDURE Do;
		BEGIN
			FOR i := 0 TO sectionList.Length() - 1 DO
				section := sectionList.GetSection(i);
				IF (section.type # Sections.InlineCodeSection) & (section.type # Sections.InitCodeSection) THEN
					IF section(IntermediateCode.Section).resolved # NIL THEN
					fixup := section(IntermediateCode.Section).resolved.fixupList.firstFixup;
					WHILE (fixup # NIL) DO
						IF (fixup.symbol.name = symbol.name) THEN
							INC(nr);
							NEW(temp);
							temp.fixup := fixup;
							temp.fixupSection := section;
							temp.nextFixup := first;
							IF fixup.displacement # 0 THEN
								diagnostics.Error(module.moduleName,Diagnostics.Invalid, Diagnostics.Invalid,"Fixups with displacement # 0 not supported in Minos Object File.");
							END;
							first := temp;
						END;
						fixup := fixup.nextFixup;
					END;
					END
				END
			END;
		END Do;

	BEGIN
		first := NIL; nr := 0;
		sectionList := module.allSections; Do;
		sectionList := module.importedSections; Do;
		RETURN nr
	END GetFixups;

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

	PROCEDURE MakeSectionOffsets(module: Sections.Module; VAR varSize, codeSize, bodyOffset: LONGINT; VAR code: ByteArray);
	VAR symbolName: SyntaxTree.IdentifierString; symbol: SyntaxTree.Symbol; binarySection: BinaryCode.Section;

		PROCEDURE Copy(section: BinaryCode.Section; to: ByteArray; offset: LONGINT);
		VAR i,ofs: LONGINT;
		BEGIN
			ofs := (offset );
			FOR i := 0 TO ((section.pc-1) ) DO
				to[i+ofs] := CHR(section.os.bits.GetBits(i*8,8));
			END;
		END Copy;

		(*
		PROCEDURE ReportSection(section: Sections.Section);
		BEGIN
			D.String("Section ");  Basic.WriteSegmentedName(D.Log, section.name); D.String(" allocated at "); D.Int(section.offset,1); D.Ln;
		END ReportSection;
		*)

		(*
		not necessary
		*)

		(* link body as first section: entry[0] = 0 *)
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
						(*ReportSection(section)*)
					END;
				END
			END;
		END FirstOffsets;


		(* note: if 'caseSections' is TRUE, only case table sections are processed, otherwise only regular sections (imported symbol/system call sections are never processed) *)
		PROCEDURE SetOffsets(sectionList: Sections.SectionList);
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
				ELSE symbolName := "";
				END;

				IF section.symbol = module.module.moduleScope.bodyProcedure THEN
				ELSIF symbolName = "@moduleSelf" THEN
				ELSIF section.type = Sections.ConstSection THEN
					 IF binarySection.os.alignment # 0 THEN
					 	INC(codeSize,(-codeSize) MOD binarySection.os.alignment);
					 END;
					  section.SetOffset(codeSize); INC(codeSize,binarySection.pc); (* global constants: in code *)
					  Basic.Align(codeSize, 4); (* word alignment *)
						(*ReportSection(section)*)
				ELSIF (section.type = Sections.CodeSection) OR (section.type = Sections.BodyCodeSection) THEN
					(*IF section.symbol = module.module.moduleScope.bodyProcedure THEN
						bodyOffset := codeSize
					END;
					*)
					section.SetOffset(codeSize); INC(codeSize, binarySection.pc);
					Basic.Align(codeSize, 4); (* word alignment *)
					(*ReportSection(section)*)
 				ELSIF section.type = Sections.VarSection THEN
					INC(varSize, binarySection.pc);
					IF binarySection.os.alignment # 0 THEN
					 	INC(varSize,(-varSize) MOD binarySection.os.alignment);
					END;
					section.SetOffset(-varSize); (* global variables: negative offset *)
					(*ReportSection(section)*)
				END
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
				IF (section.type = Sections.CodeSection) OR (section.type = Sections.BodyCodeSection) OR (section.type = Sections.ConstSection) THEN
					Copy(binarySection,code,section.offset);
				END
			END;
		END CopySections;

	BEGIN

		FirstOffsets(module.allSections); (* regular sections *)

		SetOffsets(module.allSections); (* regular sections and case table sections -- a case table is a special case of a constant section *)
		NEW(code,codeSize );
		CopySections(module.allSections); (* regular sections *)
	END MakeSectionOffsets;

	PROCEDURE WriteObjectFile*(w:Streams.Writer; module: Sections.Module; symbolFile: Files.File; diagnostics: Diagnostics.Diagnostics): BOOLEAN;
	VAR codeSize, dataSize, bodyOffset: LONGINT;
		moduleScope: SyntaxTree.ModuleScope; fingerprinter: FingerPrinter.FingerPrinter;
		code: ByteArray;
		fp: SyntaxTree.FingerPrint;
		error : BOOLEAN;
		(** helper procedures *)
		PROCEDURE GetEntries(moduleScope: SyntaxTree.ModuleScope; VAR numberEntries: LONGINT; VAR entries: ARRAY 256 OF IntermediateCode.Section);
		VAR symbol: SyntaxTree.Symbol; p: Sections.Section;

			PROCEDURE ConstantNeedsSection(constant: SyntaxTree.Constant): BOOLEAN;
			BEGIN
				RETURN constant.type.resolved IS SyntaxTree.StringType
			END ConstantNeedsSection;

			PROCEDURE TypeNeedsSection(type: SyntaxTree.TypeDeclaration): BOOLEAN;
			BEGIN
				RETURN (type.declaredType.resolved IS SyntaxTree.RecordType)
			END TypeNeedsSection;


		BEGIN
			numberEntries := 0;
			symbol := moduleScope.firstSymbol;
			WHILE symbol # NIL DO
				IF (symbol.access * SyntaxTree.Public # {}) THEN
					IF (symbol IS SyntaxTree.Procedure) & ~(symbol(SyntaxTree.Procedure).isInline)
							OR (symbol IS SyntaxTree.Variable)
							OR (symbol IS SyntaxTree.TypeDeclaration) & TypeNeedsSection(symbol(SyntaxTree.TypeDeclaration))
							OR (symbol IS SyntaxTree.Constant) & (ConstantNeedsSection(symbol(SyntaxTree.Constant))) THEN
						INC(numberEntries); (* start at 1 !! *)
						p := module.allSections.FindBySymbol(symbol);
						IF p = NIL THEN
							p := module.importedSections.FindBySymbol(symbol);
						END;
						IF p # NIL THEN
							entries[numberEntries] := p(IntermediateCode.Section);
							IF Trace THEN
								IF moduleScope = module.module.moduleScope (* self *) THEN
									D.String("Entry "); D.Int(numberEntries,1); D.String(": "); D.Str0(symbol.name); D.String(" @"); D.Int(p.offset,1); D.Ln;
								END;
							END;
						ELSE
							IF Trace THEN
								IF moduleScope = module.module.moduleScope (* self *) THEN
									D.String("did not find entry for "); D.Str0(symbol.name); D.Ln;
								END
							END;
							entries[numberEntries] := NIL;
						END;
					END;
				END;
				symbol := symbol.nextSymbol;
			END;
		END GetEntries;

		PROCEDURE Put32(offset: LONGINT; number: LONGINT);
		BEGIN
			IF Trace THEN
				D.String("put32 at offset "); D.Int(offset,1);D.String(" : "); D.Hex(number,-8); D.Ln;
			END;
			code[offset] := CHR(number MOD 100H);
			INC(offset); number := number DIV 100H;
			code[offset] := CHR(number MOD 100H);
			INC(offset); number := number DIV 100H;
			code[offset] := CHR(number MOD 100H);
			INC(offset); number := number DIV 100H;
			code[offset] := CHR(number MOD 100H);
		END Put32;

		PROCEDURE Get32(offset: LONGINT): LONGINT;
		BEGIN
			RETURN ORD(code[offset]) + 100H*ORD(code[offset+1]) + 10000H * ORD(code[offset+2]) + 1000000H*ORD(code[offset+3]);
		END Get32;

		(* ObjectFile = name:String key:Int fixSelf:Int Imports Commands Entries Data Code *)
		PROCEDURE ObjectFile(bodyOffset: LONGINT);
		VAR moduleName: Name;

			PROCEDURE Resolve(fixup: BinaryCode.Fixup);
			BEGIN
				IF fixup.resolved = NIL THEN fixup.resolved := module.allSections.FindByName(fixup.symbol.name) END;
				IF fixup.resolved = NIL THEN fixup.resolved := module.importedSections.FindByName(fixup.symbol.name) END;
			END Resolve;

			PROCEDURE InModule(s: Basic.SegmentedName):BOOLEAN;
			VAR
				section: Sections.Section;
				i: LONGINT;
			BEGIN
				FOR i := 0 TO module.allSections.Length() - 1 DO
					section := module.allSections.GetSection(i);
					IF section.name = s THEN RETURN TRUE END
				END;
				RETURN FALSE
			END InModule;

			(* go through list of all sections and all fixups in sections and if it is a self fixup, chain it *)
			PROCEDURE FixSelf(): LONGINT;
			VAR prev,this,patch: LONGINT; section: Sections.Section;
				binarySection: BinaryCode.Section; fixup: BinaryCode.Fixup; i,patchOffset: LONGINT;
				msg, name: ARRAY  256 OF CHAR;
			BEGIN
				prev := 0;
				FOR i := 0 TO module.allSections.Length() - 1 DO
					section := module.allSections.GetSection(i);
					IF  (section.type # Sections.InitCodeSection) THEN
						binarySection := section(IntermediateCode.Section).resolved;
						fixup := binarySection.fixupList.firstFixup;
						WHILE fixup # NIL DO
							IF (fixup.mode = BinaryCode.Relative)  & InModule(fixup.symbol.name) THEN
								diagnostics.Error(module.moduleName,Diagnostics.Invalid, Diagnostics.Invalid,"Relative self fixup not supported by Minos Object File.");
							ELSIF (fixup.mode = BinaryCode.Absolute) & InModule(fixup.symbol.name) THEN
								this := section.offset  + fixup.offset; (* location of the fixup *)
								(*
								ASSERT(this < 8000H);
								ASSERT(this >= -8000H);
								*)
								Resolve(fixup);
								patchOffset := (fixup.resolved.offset + fixup.displacement);
								IF (patchOffset DIV 4 >= 8000H) OR (patchOffset DIV 4< -8000H)
									OR (patchOffset MOD 4 # 0)
								 THEN
									msg := "fixup problem: ";
									Basic.SegmentedNameToString(fixup.symbol.name, name);
									Strings.Append(msg, name);
									Strings.Append(msg," : ");
									Strings.AppendInt(msg, patchOffset);

									diagnostics.Error(module.moduleName,Diagnostics.Invalid, Diagnostics.Invalid,msg);

									error := TRUE
								END;
								patch := prev DIV 4 + 10000H * (patchOffset DIV 4);
								IF Trace THEN
									D.String("fix self "); Basic.WriteSegmentedName(D.Log, section.name); D.String("+"); D.Int(fixup.offset,1);
									D.String(" -> ");
									Basic.WriteSegmentedName(D.Log, fixup.symbol.name); D.String("+"); D.Int(fixup.displacement,1) ;
									D.Ln;
								END;
								Put32(this, patch);
								prev := this;
							ELSE (* external fixup, handled in imports *)
							END;
							fixup := fixup.nextFixup;
						END
					END
				END;

				RETURN prev DIV 4
			END FixSelf;

		BEGIN
			Global.ModuleFileName(module.module.name,module.module.context,moduleName);
			fp := fingerprinter.SymbolFP(module.module);
			w.RawString(moduleName); w.RawLInt(fp.public);
			w.RawLInt(FixSelf());
			Imports;
			Commands;
			Entries(bodyOffset);
			Data;
			Code;
		END ObjectFile;

		(* Imports = {name:String key:Int fix:Int} 0X:Char *)
		PROCEDURE Imports;
		VAR name: Name; import: SyntaxTree.Import; number: LONGINT; numberEntries: LONGINT; entries: ARRAY 256 OF IntermediateCode.Section;

			PROCEDURE IsFirstOccurence(import: SyntaxTree.Import): BOOLEAN; (*! inefficient *)
			VAR i: SyntaxTree.Import;
			BEGIN
				i := moduleScope.firstImport;
				WHILE (i # NIL) & (i.module # import.module) DO
					i := i.nextImport;
				END;
				RETURN i = import
			END IsFirstOccurence;

			PROCEDURE MakeFixups(): LONGINT;
			VAR prev,this,instr,i: LONGINT; section: Sections.Section; first: Fixup; numberFixups: LONGINT;
			BEGIN
				prev := 0;
				FOR i := 1 TO numberEntries DO
					section := entries[i];
					IF section # NIL THEN
						numberFixups := GetFixups(diagnostics, module, section, first);
						IF Trace THEN
							D.Int(numberFixups,1); D.String(" fixups "); Basic.WriteSegmentedName(D.Log, section.name); D.Ln;
						END;
						WHILE first # NIL DO
							this := first.fixupSection.offset  + first.fixup.offset;
							instr := Get32(this);
							ASSERT(prev < 10000H); ASSERT(i < 100H);
							(*
								31 ... 24 | 23 .. 16 | 16 .. 0
								opCode | pno | next
							*)
							instr := instr MOD 1000000H + i * 10000H + prev DIV 4;
							Put32(this, instr);
							prev := this;
							first := first.nextFixup;
						END;
					END;
				END;
				IF Trace THEN D.String(" fixup chain starting at "); D.Int(prev,1); D.Ln END;
				RETURN prev DIV 4
			END MakeFixups;

		BEGIN
			import := moduleScope.firstImport;
			WHILE(import # NIL) DO
				IF ~Global.IsSystemModule(import.module) & IsFirstOccurence(import) THEN
					Global.ModuleFileName(import.module.name,import.module.context,name);
					IF Trace THEN
						D.Str("Import module : "); D.Str(name); D.Ln;
					END;
					w.RawString(name);
					fp := fingerprinter.SymbolFP(import.module);
					w.RawLInt(fp.public);

					(* get all imported entries of imported module *)
					GetEntries(import.module.moduleScope, numberEntries, entries);
					(* generate fixups to all non-zero entries *)
					w.RawLInt(MakeFixups());
				END;
				import := import.nextImport;
			END;
			w.Char(0X);
		END Imports;

		(* Commands = {name:String offset:Int} 0X:Char *)
		PROCEDURE Commands;
		VAR
			procedure : SyntaxTree.Procedure; procedureType: SyntaxTree.ProcedureType;
			p: Sections.Section; name: Name; numberParameters, i: LONGINT;
		BEGIN
			FOR i := 0 TO module.allSections.Length() - 1 DO
				p := module.allSections.GetSection(i);
				IF (p.type # Sections.InitCodeSection) & (p.symbol # NIL) & (p.symbol IS SyntaxTree.Procedure)  THEN
					procedure := p.symbol(SyntaxTree.Procedure);
					procedureType := procedure.type(SyntaxTree.ProcedureType);
					IF (SyntaxTree.PublicRead IN procedure.access) & ~(procedure.isInline) & ~(procedureType.isDelegate) & (procedureType.numberParameters = 0) THEN
						procedure.GetName(name);
						IF Trace THEN
							D.Str("Command : "); D.Str(name); D.Str(" @ "); D.Int(p.offset ,1);
						END;
						w.RawString(name);
						w.RawLInt(p.offset DIV 4);
						IF Trace THEN D.Ln END
					END
				END
			END;
			w.Char(0X);
		END Commands;

		(* noEntries:Int BodyEntry {entry:Int32}:noEntries *)
		PROCEDURE Entries(bodyOffset: LONGINT);
		VAR
			i,numberEntries: LONGINT; entry: ARRAY 256 OF IntermediateCode.Section; (* more is not allowed anyway in the runtime system *)
		BEGIN
			GetEntries(moduleScope, numberEntries, entry);
			w.RawLInt(numberEntries);
			w.RawLInt(0); (* body entry: body is fixed at position 0, cf. MakeSectionOffsets *)
			FOR i := 1 TO numberEntries DO
				ASSERT(entry[i].offset MOD 4 = 0);
				w.RawLInt(entry[i].offset DIV 4); (* entries here must be byte wise because jumps take place with absolute fixup - I cannot distinguish here *)
			END;
		END Entries;

		(* dataSize:Int32 *)
		PROCEDURE Data;
		BEGIN
			w.RawLInt(dataSize);
		END Data;

		(* codeLen:Int32 {code:Int32}:codeLen *)
		PROCEDURE Code;
		VAR i: LONGINT;
		BEGIN
			ASSERT(codeSize MOD 4 = 0);
			w.RawLInt(codeSize DIV 4);
			FOR i := 0 TO codeSize-1 DO
				w.Char(code[i]);
			END;
		END Code;

	BEGIN
		error := FALSE;
		moduleScope := module.module.moduleScope;
		NEW(fingerprinter,module.system);
		MakeSectionOffsets(module,dataSize,codeSize,bodyOffset,code); (* --> all sections are now assembled as one piece in code *)
		ObjectFile(bodyOffset);
		w.Update;
		RETURN ~error
	END WriteObjectFile;

	PROCEDURE Get*(): Formats.ObjectFileFormat;
	VAR objectFileFormat: ObjectFileFormat;
	BEGIN NEW(objectFileFormat); RETURN objectFileFormat
	END Get;

END FoxMinosObjectFile.

SystemTools.Free FoxMinosObjectFile ~
