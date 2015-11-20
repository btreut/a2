MODULE StaticLinker;	(* AUTHOR "negelef"; PURPOSE "Static Object File Linker"; *)

IMPORT Commands, Options, Diagnostics, Files, GenericLinker, ObjectFile, BitSets, Strings, Streams;

TYPE
	ExportName = ARRAY 128 OF CHAR;

	PatchBlock*= POINTER TO RECORD
		baseAdr: LONGINT;
		addresses: LONGINT;
		address: ARRAY 1024 OF LONGINT;
		next: PatchBlock;
	END;

	RelocationInfo= OBJECT
	CONST blockSize=4096;
	VAR
		patchBlock: PatchBlock;

		PROCEDURE & Init;
		BEGIN
			patchBlock := NIL;
		END Init;

		PROCEDURE GetPatchBlock(adr: LONGINT): PatchBlock;
		VAR p, t: PatchBlock;
		BEGIN
			t := patchBlock;
			IF (patchBlock = NIL) OR (patchBlock.baseAdr > adr) THEN
				NEW(p); p.next := patchBlock; patchBlock := p; p.baseAdr := adr;
			ELSIF patchBlock.baseAdr = adr THEN p := patchBlock
			ELSE
				t := patchBlock;
				WHILE (t.next # NIL) & (t.next.baseAdr <= adr) DO
					t := t.next;
				END;
				IF t.baseAdr = adr THEN p := t
				ELSE
					NEW(p); p.next := t.next; t.next := p; p.baseAdr := adr
				END;
			END;
			RETURN p
		END GetPatchBlock;

		PROCEDURE AddReloc(adr: LONGINT);
		VAR aligned: LONGINT; p: PatchBlock;
		BEGIN
			aligned := adr - adr MOD blockSize;
			p := GetPatchBlock(aligned);
			p.address[p.addresses] := adr (*- aligned*); INC(p.addresses);
		END AddReloc;

	END RelocationInfo;

	ExportInfo=OBJECT
	VAR
		exports: LONGINT;
		name: ExportName;
		symbolNames: POINTER TO ARRAY OF ExportName;
		exportNames: POINTER TO ARRAY OF ExportName;
		exportAddresses: POINTER TO ARRAY OF GenericLinker.Address;

		PROCEDURE &Init;
		BEGIN
			exports := 0;
		END Init;

		PROCEDURE Swap(i,j: LONGINT);
		VAR name: ExportName; adr: LONGINT;
		BEGIN
			name := exportNames[i]; exportNames[i] := exportNames[j]; exportNames[j] := name;
			name := symbolNames[i]; symbolNames[i] := symbolNames[j]; symbolNames[j] := name;
			adr := exportAddresses[i]; exportAddresses[i] := exportAddresses[j]; exportAddresses[j] := adr;
		END Swap;

		PROCEDURE QuickSort(lo, hi: LONGINT);
		VAR
			i, j,m: LONGINT;
			x, t: ANY;
		BEGIN
			i := lo; j := hi; m := (lo + hi) DIV 2;

			WHILE i <= j DO
				WHILE exportNames[i] < exportNames[m] DO INC(i) END;
				WHILE exportNames[m] < exportNames[j] DO DEC(j) END;

				IF i <= j THEN
					IF m = i THEN  m := j (* pivot will be moved by Swap *)
					ELSIF m = j THEN  m := i (* pivot will be moved by Swap *)
					END; 
					Swap(i,j);
					INC(i); DEC(j)
				END
			END;

			IF lo < j THEN QuickSort( lo, j) END;
			IF i < hi THEN QuickSort(i, hi) END
		END QuickSort;

		PROCEDURE Sort;
		BEGIN
			QuickSort(0, exports-1)
		END Sort;

	END ExportInfo;

	Arrangement* = OBJECT (GenericLinker.Arrangement);
	VAR
		displacement: GenericLinker.Address;
		bits: BitSets.BitSet;
		maxUnitSize: ObjectFile.Bits;

		exportInfo: ExportInfo;
		relocInfo: RelocationInfo;

	PROCEDURE & InitArrangement* (displacement: GenericLinker.Address);
	BEGIN
		
	 SELF.displacement := displacement; maxUnitSize := 1; NEW (bits, 0); exportInfo := NIL; NEW(relocInfo);
	END InitArrangement;

	PROCEDURE Allocate* (CONST section: ObjectFile.Section): GenericLinker.Address;
	VAR address, alignment: ObjectFile.Bits; i: LONGINT; name: ObjectFile.SegmentedName;
	BEGIN
		IF section.unit > maxUnitSize THEN maxUnitSize := section.unit END;
		IF section.fixed THEN
			address := (section.alignment - displacement) * section.unit;
		ELSE
			address := bits.GetSize (); alignment := section.alignment * section.unit;
			IF alignment = 0 THEN alignment := section.unit; END;
			INC (address, (alignment - address MOD alignment) MOD alignment);
		END;
		IF bits.GetSize () < section.bits.GetSize () + address THEN
			bits.Resize (address + section.bits.GetSize ());
		END;
		(*dest pos is for some reason negative*)
		ASSERT(address>=0);
		BitSets.CopyBits (section.bits, 0, bits, address, section.bits.GetSize ());

		IF exportInfo # NIL THEN
			FOR i := 0 TO exportInfo.exports-1 DO
				ObjectFile.StringToSegmentedName(exportInfo.symbolNames[i], name);
				IF name= section.identifier.name THEN
					exportInfo.exportAddresses[i] := address DIV section.unit + displacement;
				END;
			END
		END;

		RETURN address DIV section.unit + displacement;
	END Allocate;

	PROCEDURE SizeInBits*(): LONGINT;
	BEGIN RETURN bits.GetSize()
	END SizeInBits;

	PROCEDURE Patch* (pos, value: GenericLinker.Address; offset, bits, unit: ObjectFile.Bits);
	BEGIN SELF.bits.SetBits ((pos - displacement) * unit + offset, bits, value);
	END Patch;

	PROCEDURE CheckReloc(target: LONGINT; pattern: ObjectFile.Pattern; CONST patch: ObjectFile.Patch);
	VAR i: LONGINT;
	BEGIN
		IF (pattern.mode = ObjectFile.Absolute) & (relocInfo # NIL) THEN
			relocInfo.AddReloc(target+patch.offset);
		END;
	END CheckReloc;


END Arrangement;

TYPE FileFormat = PROCEDURE (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);

PROCEDURE Align(this, to: LONGINT): LONGINT;
BEGIN
	this := this + (-this) MOD to;
	RETURN this;
END Align;

PROCEDURE ReadObjectFile*(CONST moduleName, path, extension: ARRAY OF CHAR; linker: GenericLinker.Linker);
VAR fileName: Files.FileName; file: Files.File; reader: Files.Reader;
BEGIN
	linker.Information (moduleName, "processing");
	IF path # "" THEN Files.JoinPath (path, moduleName, fileName); ELSE COPY(moduleName,fileName); END;
	file := Files.Old (fileName);
	IF file = NIL THEN (* try with extension *)
		Files.JoinExtension (fileName, extension, fileName);
		file := Files.Old (fileName);
	END;
	IF file = NIL THEN (* try without extension *)
		
	END;
	IF file = NIL THEN linker.Error (fileName, "failed to open file"); RETURN; END;
	Files.OpenReader (reader, file, 0);
	GenericLinker.Process (reader, linker) ;
	IF reader.res # Files.Ok THEN linker.Error (fileName, "failed to parse"); END;
END ReadObjectFile;

PROCEDURE WriteOutputFile* (arrangement: Arrangement; CONST fileName: Files.FileName; linker: GenericLinker.Linker; fileFormat: FileFormat);
VAR file: Files.File; writer: Files.Writer; msg: ARRAY 64 OF CHAR; number: ARRAY 32 OF CHAR;
BEGIN
	file := Files.New (fileName);
	Files.OpenWriter (writer, file, 0);
	fileFormat (linker, arrangement, writer);
	writer.Update; Files.Register (file);
	msg := "written ";
	Strings.IntToStr(arrangement.SizeInBits(), number);
	Strings.Append(msg, number);
	Strings.Append(msg, " bits (= ");
	Strings.IntToStr(arrangement.SizeInBits() DIV arrangement.maxUnitSize, number);
	Strings.Append(msg, number);
	Strings.Append(msg, " units).");
	linker.Information (fileName, msg);
END WriteOutputFile;

PROCEDURE WriteBinaryFile (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO arrangement.bits.GetSize () - 1 BY 8 DO
		writer.Char (CHR (arrangement.bits.GetBits (i, 8)));
	END;
END WriteBinaryFile;



PROCEDURE WriteTRMFile (arrangement: Arrangement; writer: Files.Writer; bitsPerLine, lines:LONGINT);
VAR i,j,size,end,nonZeroInLeadingNibble,leadingzeros: LONGINT;
	PROCEDURE GetBits(pos: LONGINT): LONGINT;
	BEGIN
		IF pos >= size THEN RETURN 0
		ELSIF pos+4 > size THEN RETURN arrangement.bits.GetBits(pos,size-pos)
		ELSE RETURN arrangement.bits.GetBits(pos,4)
		END;
	END GetBits;
	PROCEDURE GetFirstNibble(pos: LONGINT): LONGINT;
	BEGIN
		RETURN arrangement.bits.GetBits(pos,nonZeroInLeadingNibble);
	END GetFirstNibble;
BEGIN
(*allow line size not divisible by 4 by padding the line to a multiple of 4 bits with leading zeros*)	
	size := arrangement.bits.GetSize();
	
	end := (size-1) DIV bitsPerLine + 1;
	
	(*
	D.String("bits per line: ");D.Int(bitsPerLine,0);
	D.String("  number of bits: ");D.Int(size,0);
	D.String("  number of words: ");D.Int(end,0);D.Ln;
	*)
	
	nonZeroInLeadingNibble:=bitsPerLine MOD 4;
	FOR i := 0 TO end-1 DO
		(*be aware we are writing msb first here*)
		(*padded first nibble*)
		IF nonZeroInLeadingNibble > 0 THEN
			writer.Char(ObjectFile.NibbleToCharacter(GetFirstNibble(i*bitsPerLine+bitsPerLine-nonZeroInLeadingNibble) ) ) ; 
		END;
		(*rest of the instruction word*)
		FOR j := bitsPerLine DIV 4 -1 TO 0 BY -1 DO
			writer.Char(ObjectFile.NibbleToCharacter(GetBits(i*bitsPerLine+j*4)));
		END;
		writer.Ln;
	END;
	IF end > 0 THEN (* allow at least one block, if size = 0 *)
		lines := (((end-1) DIV lines)+1)*lines; (* round up to next multiple of lines *)
	END;
	FOR i := end TO lines -1 DO
		FOR j:=1 TO bitsPerLine DIV 4 BY 1 DO
			writer.Char('f');
		END;
		
		writer.Ln;
	END;
END WriteTRMFile;

PROCEDURE WriteTRMCodeFile* (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN 
	WriteTRMFile (arrangement, writer, arrangement.maxUnitSize,1024);
END WriteTRMCodeFile;

PROCEDURE WriteTRMDataFile* (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN WriteTRMFile (arrangement, writer, 32,512);
END WriteTRMDataFile;

PROCEDURE WritePEFile (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer; bitmode, subSystem: INTEGER; isDLL: BOOLEAN);
CONST DOSText = "This program cannot be run in DOS mode.$";
CONST DOSHeaderSize = 64; DOSCodeSize = 14; DOSTextSize = 40; DOSStubSize = ((DOSHeaderSize + DOSCodeSize + DOSTextSize + 15) DIV 16) * 16;
CONST FileAlignment = 200H; SectionAlignment = 1000H; HeaderSize = 24; SectionHeaderSize = 40; DirectoryEntries = 16;
VAR OptionalHeaderSize, CodeSize, AlignedCodeSize, HeadersSize, BaseCodeAddress, BaseAddress: LONGINT; exportInfo: ExportInfo; relocInfo: RelocationInfo;
	pos: LONGINT;

	PROCEDURE Reserve (size: LONGINT);
	BEGIN INC(pos, size); WHILE size # 0 DO writer.Char (0X); DEC (size); END;
	END Reserve;

	PROCEDURE WriteBYTE (value: LONGINT);
	BEGIN writer.Char (CHR (value)); INC(pos);
	END WriteBYTE;

	PROCEDURE WriteWORD (value: LONGINT);
	BEGIN WriteBYTE (value MOD 100H); WriteBYTE (value DIV 100H);
	END WriteWORD;

	PROCEDURE WriteDWORD (value: LONGINT);
	BEGIN WriteWORD (value MOD 10000H); WriteWORD (value DIV 10000H);
	END WriteDWORD;

	PROCEDURE WritePTR (value: LONGINT);
	BEGIN WriteDWORD (value); IF bitmode = 64 THEN WriteDWORD (0) END;
	END WritePTR;

	PROCEDURE WriteString(s: ARRAY OF CHAR);
	BEGIN
		writer.String(s); INC(pos, Strings.Length(s));
	END WriteString;

	PROCEDURE WriteString0(s: ARRAY OF CHAR);
	BEGIN
		WriteString(s); WriteBYTE(0);
	END WriteString0;

	PROCEDURE AlignTo(alignment: LONGINT);
	BEGIN alignment := Align(pos, alignment); Reserve(alignment - pos);
	END AlignTo;

	PROCEDURE ReserveTo(p: LONGINT);
	BEGIN ASSERT(p >= pos); Reserve(p-pos);
	END ReserveTo;

	PROCEDURE HasExports(): BOOLEAN;
	BEGIN
		RETURN (exportInfo # NIL) & (exportInfo.exports # 0)
	END HasExports;

	PROCEDURE ExportTableSize(): LONGINT;
	VAR i,offset: LONGINT;
	BEGIN
		IF ~HasExports() THEN RETURN 0 END;

		offset := 40 + Strings.Length(exportInfo.name)+1;
		FOR i := 0 TO exportInfo.exports-1 DO
			INC(offset, Strings.Length(exportInfo.exportNames[i])+1);
			INC(offset, 10);
		END;
		RETURN offset
	END ExportTableSize;

	PROCEDURE AlignedExportTableSize(): LONGINT;
	BEGIN
		RETURN Align(ExportTableSize(), SectionAlignment);
	END AlignedExportTableSize;

	PROCEDURE HasRelocs(): BOOLEAN;
	BEGIN
		RETURN (relocInfo # NIL) & (relocInfo.patchBlock # NIL)
	END HasRelocs;

	PROCEDURE RelocTableSize(): LONGINT;
	VAR p: PatchBlock; size: LONGINT;
	BEGIN
		IF ~HasRelocs() THEN RETURN 0 END;
		size := 0;
		p := relocInfo.patchBlock;
		WHILE p # NIL DO
			INC(size, 8 + p.addresses * 2);
			IF ODD(p.addresses) THEN INC(size, 2) END;
			p := p.next
		END;
		RETURN size
	END RelocTableSize;

	PROCEDURE AlignedRelocTableSize(): LONGINT;
	BEGIN RETURN Align(RelocTableSize(), SectionAlignment);
	END AlignedRelocTableSize;

	PROCEDURE SectionHeaderOffset(): LONGINT;
	BEGIN RETURN DOSStubSize + HeaderSize + OptionalHeaderSize
	END SectionHeaderOffset;

	PROCEDURE WriteDOSStub;
	BEGIN
		WriteWORD (5A4DH);	(* e_magic *)
		WriteWORD (DOSStubSize);	(* e_cblp *)
		WriteWORD (1);	(* e_cp *)
		WriteWORD (0);	(* e_crlc *)
		WriteWORD (DOSHeaderSize DIV 16);	(* e_cparhdr *)
		WriteWORD (0);	(* e_minalloc *)
		WriteWORD (0);	(* e_maxalloc *)
		WriteWORD (0);	(* e_ss *)
		WriteWORD (0);	(* e_sp *)
		WriteWORD (0);	(* e_csum *)
		WriteWORD (0);	(* e_ip *)
		WriteWORD (0);	(* e_cs *)
		WriteWORD (DOSHeaderSize);	(* e_lfarlc *)
		WriteWORD (0);	(* e_ovno *)
		Reserve (32);	(* e_res *)
		WriteDWORD (DOSStubSize);	(* e_lfanew *)

		WriteBYTE (00EH); WriteBYTE (01FH); WriteBYTE (0BAH); WriteWORD (DOSCodeSize);
		WriteBYTE (0B4H); WriteBYTE (009H); WriteBYTE (0CDH); WriteBYTE (021H); WriteBYTE (0B8H);
		WriteBYTE (001H); WriteBYTE (04CH); WriteBYTE (0CDH); WriteBYTE (021H); WriteString (DOSText);

		Reserve (DOSStubSize - DOSHeaderSize - DOSCodeSize - DOSTextSize);
	END WriteDOSStub;

	PROCEDURE WriteHeader;
	VAR characteristics, sections: LONGINT;
	BEGIN
		WriteDWORD (000004550H);	(* Signature *)
		IF bitmode = 64 THEN
			WriteWORD (08664H);	(* Machine *)
		ELSE
			WriteWORD (0014CH);	(* Machine *)
		END;
		sections := 1;
		IF HasRelocs() THEN INC(sections) END;
		IF HasExports()THEN INC(sections) END;
		WriteWORD (sections);	(* NumberOfSections *)
		WriteDWORD (0);	(* TimeDateStamp *)
		WriteDWORD (0);	(* PointerToSymbolTable *)
		WriteDWORD (0);	(* NumberOfSymbols *)
		WriteWORD (OptionalHeaderSize);	(* SizeOfOptionalHeader *)

		characteristics := 222H;
		IF ~HasRelocs() THEN characteristics := characteristics + 1 END;
		IF isDLL THEN characteristics := characteristics + 2000H END;
		IF bitmode#64 THEN characteristics := characteristics + 100H END;

		WriteWORD(characteristics);
	END WriteHeader;

	PROCEDURE WriteOptionalHeader;
	VAR ImageSize: LONGINT;
	BEGIN
		ImageSize := Align(BaseCodeAddress+AlignedCodeSize+AlignedExportTableSize()+AlignedRelocTableSize(), SectionAlignment);

		(* 0 *) IF bitmode = 64 THEN
			WriteWORD (0020BH);	(* Magic *)
		ELSE
			WriteWORD (0010BH);	(* Magic *)
		END;
		(* 2 *) WriteBYTE (0);	(* MajorLinkerVersion *)
		(* 3 *) WriteBYTE (0);	(* MinorLinkerVersion *)
		(* 4 *) WriteDWORD (CodeSize);	(* SizeOfCode *)
		(* 8 *) WriteDWORD (0);	(* SizeOfInitializedData *)
		(* 12 *) WriteDWORD (0);	(* SizeOfUninitializedData *)
		(* 16 *) WriteDWORD (BaseCodeAddress);	(* AddressOfEntryPoint *)
		(* 20 *) WriteDWORD (BaseCodeAddress);	(* BaseOfCode *)
		(* 24 *) IF bitmode # 64 THEN
			WriteDWORD (ImageSize);	(* BaseOfData *)
		END;
		(* 28 / 24 *) WritePTR (arrangement.displacement - BaseCodeAddress);	(* ImageBase *)
		(* 32 *) WriteDWORD (SectionAlignment);	(* SectionAlignment *)
		(* 36 *)WriteDWORD (FileAlignment);	(* FileAlignment *)
		(* 40 *)WriteWORD (4);	(* MajorOperatingSystemVersion *)
		(* 42 *)WriteWORD (0);	(* MinorOperatingSystemVersion *)
		(* 44 *)WriteWORD (0);	(* MajorImageVersion *)
		(* 46 *)WriteWORD (0);	(* MinorImageVersion *)
		(* 48 *)WriteWORD (4);	(* MajorSubsystemVersion *)
		(* 50 *)WriteWORD (0);	(* MinorSubsystemVersion *)
		(* 52 *)WriteDWORD (0);	(* Win32VersionValue *)
		(* 56 *)WriteDWORD (ImageSize);	(* SizeOfImage *)
		(* 60 *)WriteDWORD (HeadersSize);	(* SizeOfHeaders *)
		(* 64 *)WriteDWORD (0);	(* CheckSum *)
		(* 68 *)WriteWORD (subSystem);	(* Subsystem *)
		(* 70 *)IF isDLL THEN WriteWORD (40H);	(* DllCharacteristics *)
				ELSE WriteWORD(0)
				END;
		(* 72 *)WritePTR (0100000H);	(* SizeOfStackReserve *)
		(* 76 / 80 *)WritePTR (01000H);	(* SizeOfStackCommit *)
		(* 80 / 88 *)WritePTR (0100000H);	(* SizeOfHeapReserve *)
		(* 84 / 96 *)WritePTR (01000H);	(* SizeOfHeapCommit *)
		(* 88 / 104 *)WriteDWORD (0);			(* LoaderFlags *)
		(* 92 / 108  *)WriteDWORD (DirectoryEntries);	(* NumberOfRvaAndSizes *)

		IF HasExports() THEN
		(* 96 / 112 *) WriteDWORD(BaseCodeAddress + AlignedCodeSize); WriteDWORD(ExportTableSize());  (* location and size of export table *)
		ELSE Reserve(8)
		END;
		(* 104 / 120 *) WriteDWORD (BaseCodeAddress +8) ; WriteDWORD (40); (* location and size of of idata section *)
		Reserve (3 * 8);
		IF HasRelocs() THEN
			WriteDWORD (BaseCodeAddress + AlignedCodeSize+AlignedExportTableSize()) ; WriteDWORD (RelocTableSize()); (* location and size of of reloc section *)
		ELSE Reserve(8)
		END;
		Reserve ((DirectoryEntries - 6) * 8);
	END WriteOptionalHeader;

	PROCEDURE WriteSections;
	VAR ExportNameTableAddress, i, offset: LONGINT; p: PatchBlock;
	BEGIN

		(* code section header *)
		(* 0 *) WriteString (".text"); Reserve (3);	(* Name *)
		(* 8 *) WriteDWORD (CodeSize);	(* VirtualSize *)
		(* 12 *) WriteDWORD (BaseCodeAddress);	(* VirtualAddress *)
		(* 16 *) WriteDWORD (AlignedCodeSize);	(* SizeOfRawData *)
		(* 20 *) WriteDWORD (BaseCodeAddress);	(* PointerToRawData *)
		(* 24 *) WriteDWORD (0);	(* PointerToRelocations *)
		(* 28 *) WriteDWORD (0);	(* PointerToLinenumbers *)
		(* 32 *) WriteWORD (0);	(* NumberOfRelocations *)
		(* 34 *) WriteWORD (0);	(* NumberOfLinenumbers *)
		(* 36 *) WriteDWORD (LONGINT (0E0000020H));	(* Characteristics *)

		IF HasExports() THEN
			(* export table header *)
			(* 0 *) WriteString(".edata"); Reserve(2); (* name *)
			(* 8 *) WriteDWORD(ExportTableSize()); (* virtual size *)
			(* 12 *) WriteDWORD(BaseCodeAddress + AlignedCodeSize (* address *));
			(* 16 *) WriteDWORD(AlignedExportTableSize()); (* raw data size *)
			(* 20 *) WriteDWORD(BaseCodeAddress + AlignedCodeSize); (* raw data pointer *)
			(* 24 *) WriteDWORD (0);	(* PointerToRelocations *)
			(* 28 *) WriteDWORD (0);	(* PointerToLinenumbers *)
			(* 32 *) WriteWORD (0);	(* NumberOfRelocations *)
			(* 34 *) WriteWORD (0);	(* NumberOfLinenumbers *)
			(* 36 *) WriteDWORD (LONGINT (040000000H));	(* Characteristics *)
		END;

		IF HasRelocs() THEN
			(* reloc table header *)
			(* 0 *) WriteString(".reloc"); Reserve(2); (* name *)
			(* 8 *) WriteDWORD(RelocTableSize()); (* virtual size *)
			(* 12 *) WriteDWORD(BaseCodeAddress + AlignedCodeSize + AlignedExportTableSize() (* address *));
			(* 16 *) WriteDWORD(AlignedRelocTableSize()); (* raw data size *)
			(* 20 *) WriteDWORD(BaseCodeAddress + AlignedCodeSize+ AlignedExportTableSize()); (* raw data pointer *)
			(* 24 *) WriteDWORD (0);	(* PointerToRelocations *)
			(* 28 *) WriteDWORD (0);	(* PointerToLinenumbers *)
			(* 32 *) WriteWORD (0);	(* NumberOfRelocations *)
			(* 34 *) WriteWORD (0);	(* NumberOfLinenumbers *)
			(* 36 *) WriteDWORD (LONGINT (040000000H));	(* Characteristics *)
		END;

		(* 40 / 80 / 120 *) ReserveTo(BaseCodeAddress);

	 	(**** code section *****)
	 	(* BaseCodeAddress *)
	 	WriteBinaryFile (linker, arrangement, writer); INC(pos, arrangement.bits.GetSize () DIV 8);
	 	(* BaseCodeAddress +CodeSize *)
		Reserve (AlignedCodeSize-CodeSize);
		(* BaseCodeAddress + AlignedCodeSize *)

		IF HasExports() THEN
			(***** export section *****)
			(* BaseCodeAddress + AlignedCodeSize  *)
			(* 0 *) WriteDWORD(0); (* reserved *)
			(* 4 *) WriteDWORD(0); (* time / date *)
			(* 6 *) WriteWORD(0); (* major version *)
			(* 8 *) WriteWORD(0); (* minor version *)
			(* 12 *) WriteDWORD(BaseCodeAddress+AlignedCodeSize + 40 + 10* exportInfo.exports); (* RVA of DLL name *)
			(* 16 *) WriteDWORD(1); (* start ordinal number *)
			(* 20 *) WriteDWORD(exportInfo.exports); (* number of entries in export table *)
			(* 24 *) WriteDWORD(exportInfo.exports); (* number of entries in name pointer table *)
			(* 28 *) WriteDWORD(BaseCodeAddress+AlignedCodeSize + 40 ); (* export address table RVA *)
			(* 32 *) WriteDWORD(BaseCodeAddress+AlignedCodeSize + 40 + 4* exportInfo.exports); (* name pointer RVA *)
			(* 36 *) WriteDWORD(BaseCodeAddress+AlignedCodeSize + 40 + 8* exportInfo.exports); (* ordinal table RVA *)
			(* 40 *)

			(* export address table *)
			FOR i := 0 TO exportInfo.exports-1 DO
				ASSERT(exportInfo.exportAddresses[i] # 0);
				WriteDWORD(exportInfo.exportAddresses[i]-BaseAddress+BaseCodeAddress); (* RVA ! *)
			END;

			(* export name pointer table *)
			(* 40 + 4 * Number exports *)
			ExportNameTableAddress := BaseCodeAddress + AlignedCodeSize + 40 + 10* exportInfo.exports ;
			offset := Strings.Length(exportInfo.name)+1;
			FOR i := 0 TO exportInfo.exports-1 DO
				WriteDWORD(ExportNameTableAddress + offset);
				INC(offset, Strings.Length(exportInfo.exportNames[i])+1);
			END;

			(* export ordinal table *)
			(* 40 + 8* NumberExports  *)
			FOR i := 0 TO exportInfo.exports-1 DO
				WriteWORD(i);
			END;

			(* 40 + 10* NumberExports *)
			(* export name table *)
			WriteString0(exportInfo.name);
			FOR i := 0 TO exportInfo.exports-1 DO
				WriteString0(exportInfo.exportNames[i]); (* 0x terminated *)
			END;
			Reserve(AlignedExportTableSize() - ExportTableSize());
		END;

		IF HasRelocs() THEN
			p := relocInfo.patchBlock;
			WHILE p # NIL DO
				WriteDWORD(p.baseAdr -BaseAddress+BaseCodeAddress) (* RVA  of block *);
				WriteDWORD(8+p.addresses*2+2*(p.addresses MOD 2)); (* number bytes of this block *)
				FOR i := 0 TO p.addresses-1 DO
					WriteWORD(p.address[i] - p.baseAdr+ 3000H);(* block-relative addresses, highlow *)
				END;
				AlignTo(4);
				p := p.next;
			END;
			Reserve(AlignedRelocTableSize() - RelocTableSize());
		END;
	END WriteSections;

BEGIN
	pos := 0;
	exportInfo := arrangement.exportInfo;
	relocInfo := arrangement.relocInfo;
	IF HasExports() THEN exportInfo.Sort END;
	BaseAddress := arrangement.displacement; (* ASSERT (arrangement.displacement = BaseAddress); *)
	OptionalHeaderSize := 96 + DirectoryEntries * 8;
	IF bitmode = 64 THEN INC (OptionalHeaderSize, 16); END;
	CodeSize := arrangement.bits.GetSize () DIV 8;
	AlignedCodeSize := Align(CodeSize, SectionAlignment);
	HeadersSize :=  Align(DOSStubSize + HeaderSize + OptionalHeaderSize + SectionHeaderSize, FileAlignment);
	BaseCodeAddress := Align(HeadersSize, SectionAlignment);

	WriteDOSStub; WriteHeader; WriteOptionalHeader; WriteSections;
END WritePEFile;

PROCEDURE WriteDLL32File (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN WritePEFile (linker, arrangement, writer, 32, 2, TRUE);
END WriteDLL32File;

PROCEDURE WriteDLL64File (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN WritePEFile (linker, arrangement, writer, 64, 2, TRUE);
END WriteDLL64File;

PROCEDURE WritePE32File (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN WritePEFile (linker, arrangement, writer, 32, 2, FALSE);
END WritePE32File;

PROCEDURE WritePE64File (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN WritePEFile (linker, arrangement, writer, 64, 2, FALSE);
END WritePE64File;

PROCEDURE WritePE32CUIFile (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN WritePEFile (linker, arrangement, writer, 32, 3, FALSE);
END WritePE32CUIFile;

PROCEDURE WritePE64CUIFile (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN WritePEFile (linker, arrangement, writer, 64, 3, FALSE);
END WritePE64CUIFile;

PROCEDURE WriteEFI32File (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN WritePEFile (linker, arrangement, writer, 32, 10, FALSE);
END WriteEFI32File;

PROCEDURE WriteEFI64File (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
BEGIN WritePEFile (linker, arrangement, writer, 64, 10, FALSE);
END WriteEFI64File;

PROCEDURE WriteELFFile (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
CONST ELFHeaderSize = 52; ProgramHeaderSize = 32; HeadersSize = ELFHeaderSize + ProgramHeaderSize;
CONST BaseAddress = 08048000H; EntryAddress = BaseAddress + HeadersSize;

	PROCEDURE Reserve (size: LONGINT);
	BEGIN WHILE size # 0 DO writer.Char (0X); DEC (size); END;
	END Reserve;

	PROCEDURE WriteByte (value: LONGINT);
	BEGIN writer.Char (CHR (value));
	END WriteByte;

	PROCEDURE WriteHalf (value: LONGINT);
	BEGIN WriteByte (value MOD 100H); WriteByte (value DIV 100H);
	END WriteHalf;

	PROCEDURE WriteWord (value: LONGINT);
	BEGIN WriteHalf (value MOD 10000H); WriteHalf (value DIV 10000H);
	END WriteWord;

	PROCEDURE WriteELFHeader;
	BEGIN
		WriteByte (7FH);	(* e_ident[EI_MAG0] *)
		WriteByte (ORD('E'));	(* e_ident[EI_MAG1] *)
		WriteByte (ORD('L'));	(* e_ident[EI_MAG2] *)
		WriteByte (ORD('F'));	(* e_ident[EI_MAG3] *)
		WriteByte (1);		(* e_ident[EI_CLASS] *)
		WriteByte (1);		(* e_ident[EI_DATA] *)
		WriteByte (1);		(* e_ident[EI_VERSION] *)
		WriteByte (0);		(* e_ident[EI_PAD] *)
		Reserve (8);		(* e_ident[EI_NIDENT] *)
		WriteHalf (2);		(* e_type *)
		WriteHalf (3);		(* e_machine *)
		WriteWord (1);	(* e_version *)
		WriteWord (EntryAddress);	(* e_entry *)
		WriteWord (ELFHeaderSize);	(* e_phoff *)
		WriteWord (0);	(* e_phoff *)
		WriteWord (0);	(* e_flags *)
		WriteHalf (ELFHeaderSize);	(* e_ehsize *)
		WriteHalf (ProgramHeaderSize);	(* e_phentsize *)
		WriteHalf (1);		(* e_phnum *)
		WriteHalf (0);		(* e_shentsize *)
		WriteHalf (0);		(* e_shnum *)
		WriteHalf (0);		(* e_shstrndx *)
	END WriteELFHeader;

	PROCEDURE WriteProgramHeader;
	VAR FileSize: LONGINT;
	BEGIN
		FileSize := HeadersSize + arrangement.bits.GetSize () DIV 8;

		WriteWord (1);		(* p_type *)
		WriteWord (0);		(* p_offset *)
		WriteWord (BaseAddress);	(* p_vaddr *)
		WriteWord (0);		(* p_paddr *)
		WriteWord (FileSize);	(* p_filesz *)
		WriteWord (FileSize);	(* p_memsz *)
		WriteWord (7);		(* p_flags *)
		WriteWord (1000H);	(* p_align *)
	END WriteProgramHeader;

BEGIN
	ASSERT (arrangement.displacement = BaseAddress);
	WriteELFHeader;
	WriteProgramHeader;
 	WriteBinaryFile (linker, arrangement, writer);
END WriteELFFile;

PROCEDURE WriteMachOFile (linker: GenericLinker.Linker; arrangement: Arrangement; writer: Files.Writer);
CONST SegmentName = "__TEXT"; SectionName = "__text";
CONST MachHeaderSize = 28; LoadCommandSize = 124; ThreadCommandSize = 80;
CONST CommandsSize = LoadCommandSize + ThreadCommandSize; Start = MachHeaderSize + CommandsSize;
CONST BaseAddress = 000010E8H;

	PROCEDURE Write (value: LONGINT);
	BEGIN writer.Char (CHR (value)); writer.Char (CHR (value DIV 100H)); writer.Char (CHR (value DIV 10000H)); writer.Char (CHR (value DIV 1000000H));
	END Write;

	PROCEDURE WriteName (CONST name: ARRAY OF CHAR);
	VAR i: INTEGER;
	BEGIN i := 0; WHILE name[i] # 0X DO writer.Char (name[i]); INC (i); END;
		WHILE i # 16 DO writer.Char (0X); INC (i); END;
	END WriteName;

	PROCEDURE WriteMachHeader;
	BEGIN
		Write (LONGINT (0FEEDFACEH));	(* magic *)
		Write (7);	(* cputype *)
		Write (3);	(* cpusubtype *)
		Write (2);	(* filetype *)
		Write (2);	(* ncmds *)
		Write (CommandsSize);	(* sizeofcmds *)
		Write (0);	(* flags *)
	END WriteMachHeader;

	 PROCEDURE WriteLoadCommand;
	 VAR FileSize: LONGINT;
	 BEGIN
		FileSize := MachHeaderSize + CommandsSize + arrangement.bits.GetSize () DIV 8;

		Write (1);	(* cmd *)
		Write (LoadCommandSize);	(* cmdsize *)
		WriteName (SegmentName);	(* segname *)
		Write (BaseAddress - Start);	(* vmaddr *)
		Write (FileSize);	(* vmsize *)
		Write (0);	(* fileoff *)
		Write (FileSize);	(* filesize *)
		Write (7);	(* maxprot *)
		Write (7);	(* initprot *)
		Write (1);	(* nsects *)
		Write (0);	(* flags *)

		WriteName (SectionName);	(* sectname *)
		WriteName (SegmentName);	(* segname *)
		Write (BaseAddress);	(* addr *)
		Write (arrangement.bits.GetSize () DIV 8);	(* size *)
		Write (Start);	(* offset *)
		Write (2);	(* align *)
		Write (0);	(* reloff *)
		Write (0);	(* nreloc *)
		Write (0);	(* flags *)
		Write (0);	(* reserved1 *)
		Write (0);	(* reserved2 *)
	END WriteLoadCommand;

	PROCEDURE WriteThreadCommand;
	BEGIN
		Write (5);	(* cmd *)
		Write (ThreadCommandSize);	(* cmdsize *)
		Write (1);	(* flavor *)
		Write (16);	(* count *)

		Write (0);	(* eax *)
		Write (0);	(* ebx *)
		Write (0);	(* ecx *)
		Write (0);	(* edx *)
		Write (0);	(* edi *)
		Write (0);	(* esi *)
		Write (0);	(* ebp *)
		Write (0);	(* esp *)
		Write (0);	(* ss *)
		Write (0);	(* eflags *)
		Write (BaseAddress);	(* eip *)
		Write (0);	(* cs *)
		Write (0);	(* ds *)
		Write (0);	(* es *)
		Write (0);	(* fs *)
		Write (0);	(* gs *)
	END WriteThreadCommand;

BEGIN
	ASSERT (arrangement.displacement = BaseAddress);
	WriteMachHeader;
	WriteLoadCommand;
	WriteThreadCommand;
 	WriteBinaryFile (linker, arrangement, writer);
END WriteMachOFile;

PROCEDURE GetFileFormat (options: Options.Options; CONST name: Options.Name; default: FileFormat): FileFormat;
VAR format: ARRAY 10 OF CHAR;
BEGIN
	IF ~options.GetString (name, format) THEN RETURN default;
	ELSIF format = "TRMCode" THEN RETURN WriteTRMCodeFile;
	ELSIF format = "TRMData" THEN RETURN WriteTRMDataFile;
	ELSIF format = "PE32" THEN RETURN WritePE32File;
	ELSIF format = "PE64" THEN RETURN WritePE64File;
	ELSIF format = "PE32CUI" THEN RETURN WritePE32CUIFile;
	ELSIF format = "PE64CUI" THEN RETURN WritePE64CUIFile;
	ELSIF format = "EFI32" THEN RETURN WriteEFI32File;
	ELSIF format = "EFI64" THEN RETURN WriteEFI64File;
	ELSIF format = "ELF" THEN RETURN WriteELFFile;
	ELSIF format = "MACHO" THEN RETURN WriteMachOFile;
	ELSIF format = "DLL32" THEN RETURN WriteDLL32File;
	ELSIF format = "DLL64" THEN RETURN WriteDLL64File;
	ELSE RETURN default; END;
END GetFileFormat;

PROCEDURE ParseExports(CONST names: ARRAY OF CHAR): ExportInfo;
VAR number: LONGINT; info: ExportInfo; pos: LONGINT; name: ExportName;

	PROCEDURE SkipWhitespace;
	BEGIN WHILE (names[pos] # 0X) & (names[pos] <= " ") DO INC(pos) END;
	END SkipWhitespace;

	PROCEDURE ReadName(VAR name: ARRAY OF CHAR): BOOLEAN;
	VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE (names[pos] # 0X) & (names[pos] > " ") & (names[pos] # ",") & (names[pos] # "=") DO name[i] := names[pos]; INC(i); INC(pos) END;
		name[i] := 0X;
		RETURN i > 0;
	END ReadName;

	PROCEDURE ParseEntry(VAR symbolName, exportName: ARRAY OF CHAR): BOOLEAN;
	BEGIN
		SkipWhitespace;
		IF ReadName(symbolName) THEN
			SkipWhitespace;
			IF names[pos] = "=" THEN
				INC(pos); SkipWhitespace;
				IF ~ReadName(exportName) THEN RETURN FALSE END;
				SkipWhitespace;
			ELSE COPY(symbolName, exportName);
			END;
			IF names[pos] = "," THEN INC(pos); SkipWhitespace END;
			RETURN TRUE
		ELSE RETURN FALSE
		END;
	END ParseEntry;

BEGIN
	pos := 0; number := 0;
	WHILE ParseEntry(name, name) DO INC(number) END;
	IF (names[pos] # 0X) OR (number = 0)  THEN RETURN NIL END;

	NEW(info);
	NEW(info.symbolNames, number);
	NEW(info.exportNames, number);
	NEW(info.exportAddresses, number);
	info.exports := number;

	number := 0; pos := 0;
	WHILE (names[pos] # 0X) & ParseEntry(info.symbolNames[number], info.exportNames[number]) DO
		INC(number)
	END;
	RETURN info
END ParseExports;

PROCEDURE CheckExports(info: ExportInfo; error: Streams.Writer): BOOLEAN;
VAR success: BOOLEAN; i: LONGINT;
BEGIN
	IF info = NIL THEN RETURN TRUE END;
	success := TRUE;
	FOR i := 0 TO info.exports-1 DO
		IF info.exportAddresses[i] = 0 THEN
			error.String("Export symbol not found: "); error.String(info.symbolNames[i]); error.String(" (= ");
			error.String(info.exportNames[i]); error.String(")"); error.Ln;
			success := FALSE;
		END;
	END;
	RETURN success
END CheckExports;


PROCEDURE Link* (context: Commands.Context);
VAR options: Options.Options;
	silent, useAll, strict: BOOLEAN;
	codeFileFormat, dataFileFormat: FileFormat;
	codeDisplacement, dataDisplacement: GenericLinker.Address;
	path, extension, codeFileName, dataFileName, moduleName, logFileName, tempName: Files.FileName;
	diagnostics: Diagnostics.StreamDiagnostics; code, data: Arrangement; linker: GenericLinker.Linker;
	linkRoot: ARRAY 256 OF CHAR; logFile: Files.File; log: Files.Writer;
	use: SET;
	exportString: ARRAY 1024 OF CHAR;
	error: BOOLEAN;
BEGIN
	NEW (options);
	options.Add (0X, "silent", Options.Flag);
	options.Add ('a', "useAll", Options.Flag);
	options.Add ('s', "strict", Options.Flag);
	options.Add (0X, "path", Options.String); options.Add (0X, "extension", Options.String);
	options.Add (0X, "fileName", Options.String); options.Add (0X, "dataFileName", Options.String);
	options.Add (0X, "displacement", Options.Integer); options.Add (0X, "dataDisplacement", Options.Integer);
	options.Add (0X, "fileFormat", Options.String); options.Add (0X, "dataFileFormat", Options.String);
	options.Add (0X, "logFileName", Options.String);
	options.Add(0X,"linkRoot", Options.String);
	options.Add(0X,"exports", Options.String);
	IF ~options.Parse (context.arg, context.error) THEN context.result := Commands.CommandParseError; RETURN; END;
	silent := options.GetFlag ("silent");
	useAll := options.GetFlag ("useAll");
	strict := options.GetFlag ("strict");
	IF ~options.GetString ("path", path) THEN path := ""; END;
	IF ~options.GetString ("extension", extension) THEN extension := ObjectFile.DefaultExtension; END;
	IF ~options.GetString ("fileName", codeFileName) THEN codeFileName := "linker.bin"; END;
	IF ~options.GetString ("dataFileName", dataFileName) THEN dataFileName := codeFileName; END;
	IF ~options.GetString ("logFileName", logFileName) THEN
		COPY(codeFileName, logFileName); Files.SplitExtension(logFileName,logFileName,tempName); Files.JoinExtension(logFileName,"log",logFileName);
	END;
	IF ~options.GetInteger ("displacement", codeDisplacement) THEN codeDisplacement := 0; END;
	IF ~options.GetInteger ("dataDisplacement", codeDisplacement) THEN dataDisplacement := codeDisplacement; END;
	codeFileFormat := GetFileFormat (options, "fileFormat", WriteBinaryFile);
	dataFileFormat := GetFileFormat (options, "dataFileFormat", codeFileFormat);

	NEW (code, codeDisplacement);
	IF options.GetString("exports", exportString) THEN
		code.exportInfo := ParseExports(exportString);
		IF code.exportInfo = NIL THEN
			context.error.String("Syntax error in export list or empty export list."); context.error.Ln;
		ELSE
			COPY(codeFileName, code.exportInfo.name);
		END;
	END;
	IF codeFileName # dataFileName THEN NEW (data, dataDisplacement); ELSE data := code; END;
	NEW (diagnostics, context.error);
	logFile := Files.New(logFileName);
	IF logFile # NIL THEN NEW(log, logFile,0) ELSE log := NIL END;
	IF useAll THEN use := GenericLinker.UseAll ELSE use := GenericLinker.UseInitCode END;
	NEW (linker, diagnostics, log, use, code, data);

	IF options.GetString("linkRoot",linkRoot) THEN linker.SetLinkRoot(linkRoot) END;

	WHILE ~linker.error & context.arg.GetString (moduleName) DO
		ReadObjectFile (moduleName, path, extension, linker);
		IF strict & ~linker.error THEN linker.Resolve END;
	END;
	(* do linking after having read in all blocks to account for potential constraints *)
	IF ~linker.error THEN linker.Link; END;

	error := linker.error;
	error := error OR ~CheckExports(code.exportInfo, context.error);

	IF ~error THEN
		IF (code.displacement # 0) & (linker.log # NIL) THEN linker.log.String("code displacement 0"); linker.log.Hex(code.displacement,-8); linker.log.String("H"); linker.log.Ln END;
		WriteOutputFile (code, codeFileName, linker, codeFileFormat);
		IF data # code THEN
			IF (data.displacement # 0) & (linker.log # NIL) THEN linker.log.String("data displacement 0"); linker.log.Hex(data.displacement,-8); linker.log.String("H"); linker.log.Ln END;
			WriteOutputFile (data, dataFileName, linker, dataFileFormat);
		END;
		IF ~silent THEN
			context.out.String("Link successful. Written files: ");
			context.out.String(codeFileName);
			IF data # code THEN context.out.String(", "); context.out.String(dataFileName) END;
			IF logFile # NIL THEN context.out.String(", "); context.out.String(logFileName); END;

			context.out.Ln
		END;
		IF log # NIL THEN
			log.Update; Files.Register(logFile);
		END;
	END;

	IF error THEN context.result := Commands.CommandError; END;
END Link;

END StaticLinker.

StaticLinker.Link --fileName=test.exe --fileFormat=PE32 --displacement=401000H Test ~
StaticLinker.Link --fileName=a.out --fileFormat=ELF --displacement=08048000H Test ~
StaticLinker.Link --fileName=a.out --fileFormat=MACHO --displacement=000010E8H Test ~




