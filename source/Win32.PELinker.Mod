(* Copyright (c) 1994 - 2000 Emil J. Zeller *)

MODULE PELinker;   (** non-portable / source: Win32.PELinker.Mod *)  (* ejz  *)

IMPORT SYSTEM, Streams, Files, Dates, Strings, KernelLog, Commands, Options, Texts, TextUtilities, UTF8Strings, Linker0, Linker1;

CONST
	DefaultFileExtension = ".Obw";

	NULL = 0;

	ImageDosSignature = 05A4DH;   (* MZ *)
	ImageNtSignature = 000004550H;   (* PE00 *)
	ImageFileRelocsStripped = 00001H;   (* Relocation info stripped from file. *)
	ImageFileExecutableImage = 00002H;   (* File is executable (i.e. no unresolved externel references). *)
	ImageFileLineNumsStripped = 00004H;   (* Line nunbers stripped from file. *)
	ImageFileLocalSymsStripped = 00008H;   (* Local symbols stripped from file. *)
	ImageFileLargeAddressAware = 00020H;   (* App can handle > 2gb addresses. *)

	ImageFile32BitMachine = 00100H;   (* 32 bit word machine. *)

	ImageFileDll = 02000H;   (* File is a DLL. *)

	ImageFileMachineI386 = 014CH;   (* Intel 386. *)
	ImageNumberofDirectoryEntries = 16;  ImageOptionalMagic = 010BH;
	ImageSubsystemNative = 1;   (* Image doesn't require a subsystem. *)
	ImageSubsystemWindowsGui = 2;   (* Image runs in the Windows GUI subsystem. *)
	ImageSubsystemWindowsCui = 3;   (* Image runs in the Windows character subsystem. *)
	ImageDirectoryEntryExport = 0;   (* Export Directory *)
	ImageDirectoryEntryImport = 1;   (* Import Directory *)
	ImageDirectoryEntryResource = 2;   (* Resource Directory *)

	ImageDirectoryEntryBasereloc = 5;   (* Base Relocation Table *)

	ImageDirectoryEntryIat = 12;   (* Import Address Table *)
	ImageSizeofShortName = 8;

	ImageScnCntCode = 000000020H;   (* Section contains code. *)
	ImageScnCntInitializedData = 000000040H;   (* Section contains initialized data. *)
	ImageScnCntUninitializedData = 000000080H;   (* Section contains uninitialized data. *)
	ImageScnMemDiscardable = 02000000H;   (* Section can be discarded. *)
	ImageScnNotPaged = SHORT(08000000H);   (* Section is not paged. *)
	ImageScnMemShared = 010000000H;   (* Section is shareable. *)
	ImageScnMemExecute = 020000000H;   (* Section is executable. *)
	ImageScnMemRead = 040000000H;   (* Section is readable. *)
	ImageScnMemWrite = LONGINT(080000000H);   (* Section is writeable. *)
	ImageRelBasedAbsolute = 0;  ImageRelBasedHigh = 1;  ImageRelBasedLow = 2;  ImageRelBasedHighLow = 3;
	ImageRelBasedHighAdj = 4;  ImageRelBasedMipsJmpAddr = 5;  ImageRelBasedSection = 6;  ImageRelBasedRel32 = 7;

	RtCursor = 1;  RtIcon = 3;  RtGroupCursor = RtCursor + 11;  RtGroupIcon = RtIcon + 11;  RtVersion = 16;

	DefaultLanguage = 0400H;  VsFfiSignature = LONGINT(0FEEF04BDH);  VsFfiStrucVersion = 000010000H;  VsFfiFileFlagsMask = 00000003FH;
	VosNtWindows32 = 000040004H;  VftApp = 000000001H;  VftDll = 000000002H;  Vft2Unknown = 000000000H;

	MajorLinkerVersion = CHR( 0 );  MinorLinkerVersion = CHR( 90 );  PageSize = 01000H;  SectorSize = 0200H;
	DefaultFileAlign = SectorSize;  DefaultSectionAlign = PageSize;  BaseRVA = DefaultSectionAlign;  DefaultHeapSize = 64 * 1024;
	DefaultStackSize = 1024 * 1024;  DefaultImageSubsystem = ImageSubsystemWindowsGui;  DefaultEXEImageBase = 0400000H;
	DefaultDLLImageBase = 010000000H;  DefaultStub = "stub.exe";

	MaxRelocs = 16 * 1024;

TYPE
	Buffer = POINTER TO ARRAY OF CHAR;

	ImageDosHeader = RECORD  (* DOS .EXE header *)
		emagic: INTEGER;   (* Magic number *)
		ecblp: INTEGER;   (* Bytes on last page of file *)
		ecp: INTEGER;   (* Pages in file *)
		ecrlc: INTEGER;   (* Relocations *)
		ecparhdr: INTEGER;   (* Size of header in paragraphs *)
		eminalloc: INTEGER;   (* Minimum extra paragraphs needed *)
		emaxalloc: INTEGER;   (* Maximum extra paragraphs needed *)
		ess: INTEGER;   (* Initial (relative) SS value *)
		esp: INTEGER;   (* Initial SP value *)
		ecsum: INTEGER;   (* Checksum *)
		eip: INTEGER;   (* Initial IP value *)
		ecs: INTEGER;   (* Initial (relative) CS value *)
		elfarlc: INTEGER;   (* File address of relocation table *)
		eovno: INTEGER;   (* Overlay number *)
		eres: ARRAY 4 OF INTEGER;   (* Reserved words *)
		eoemid: INTEGER;   (* OEM identifier (for e_oeminfo) *)
		eoeminfo: INTEGER;   (* OEM information; e_oemid specific *)
		eres2: ARRAY 10 OF INTEGER;   (* Reserved words *)
		elfanew: LONGINT (* File address of new exe header *)
	END;

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
		VirtualAddress: LONGINT;
		Size: LONGINT
	END;

	ImageOptionalHeader = RECORD
	(* Standard fields. *)
		Magic: INTEGER;
		MajorLinkerVersion: CHAR;
		MinorLinkerVersion: CHAR;
		SizeOfCode: LONGINT;
		SizeOfInitializedData: LONGINT;
		SizeOfUninitializedData: LONGINT;
		AddressOfEntryPoint: LONGINT;
		BaseOfCode: LONGINT;
		BaseOfData: LONGINT;
		(* NT additional fields. *)
		ImageBase: LONGINT;
		SectionAlignment: LONGINT;
		FileAlignment: LONGINT;
		MajorOperatingSystemVersion: INTEGER;
		MinorOperatingSystemVersion: INTEGER;
		MajorImageVersion: INTEGER;
		MinorImageVersion: INTEGER;
		MajorSubsystemVersion: INTEGER;
		MinorSubsystemVersion: INTEGER;
		Win32VersionValue: LONGINT;
		SizeOfImage: LONGINT;
		SizeOfHeaders: LONGINT;
		CheckSum: LONGINT;
		Subsystem: INTEGER;
		DllCharacteristics: INTEGER;
		SizeOfStackReserve: LONGINT;
		SizeOfStackCommit: LONGINT;
		SizeOfHeapReserve: LONGINT;
		SizeOfHeapCommit: LONGINT;
		LoaderFlags: LONGINT;
		NumberOfRvaAndSizes: LONGINT;
		DataDirectory: ARRAY ImageNumberofDirectoryEntries OF ImageDataDirectory
	END;

	ImageSectionHeader = RECORD
		Name: ARRAY ImageSizeofShortName OF CHAR;
		VirtualSize: LONGINT;
		VirtualAddress: LONGINT;
		SizeOfRawData: LONGINT;
		PointerToRawData: LONGINT;
		PointerToRelocations: LONGINT;
		PointerToLinenumbers: LONGINT;
		NumberOfRelocations: INTEGER;
		NumberOfLinenumbers: INTEGER;
		Characteristics: LONGINT;
	END;

	ImageImportDescriptor = RECORD
		Characteristics: LONGINT;   (* 0 for terminating null import descriptor *)
		(* RVA to original unbound IAT *)
		TimeDateStamp: LONGINT;   (* 0 if not bound, *)
		(* -1 if bound, and real date\time stamp *)
		(* in IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT (new BIND) *)
		(* O.W. date/time stamp of DLL bound to (Old BIND) *)
		ForwarderChain: LONGINT;   (* -1 if no forwarders *)
		Name: LONGINT;
		FirstThunk: LONGINT (* RVA to IAT (if bound this IAT has actual addresses) *)
	END;

	ImageExportDirectory = RECORD
		Characteristics: LONGINT;
		TimeDateStamp: LONGINT;
		MajorVersion: INTEGER;
		MinorVersion: INTEGER;
		Name: LONGINT;
		Base: LONGINT;
		NumberOfFunctions: LONGINT;
		NumberOfNames: LONGINT;
		AddressOfFunctions: LONGINT;
		AddressOfNames: LONGINT;
		AddressOfNameOrdinals: LONGINT
	END;

	ImageBaseRelocation = RECORD
		VirtualAddress: LONGINT;
		SizeOfBlock: LONGINT
	END;

	ImageResourceDirectory = RECORD
		Characteristics: LONGINT;
		TimeDateStamp: LONGINT;
		MajorVersion: INTEGER;
		MinorVersion: INTEGER;
		NumberOfNamedEntries: INTEGER;
		NumberOfIdEntries: INTEGER
		(* ImageResourceDirectoryEntry DirectoryEntries[]; *)
	END;

	ImageResourceDirectoryEntry = RECORD
		Name: LONGINT;
		OffsetToData: LONGINT
	END;

	ImageResourceDataEntry = RECORD
		OffsetToData: LONGINT;
		Size: LONGINT;
		CodePage: LONGINT;
		Reserved: LONGINT
	END;

	ResourceHeader = RECORD
		reserved, type, count: INTEGER
	END;

	Bitmapinfoheader = RECORD
		biSize: LONGINT;
		biWidth: LONGINT;
		biHeight: LONGINT;
		biPlanes: INTEGER;
		biBitCount: INTEGER;
		biCompression: LONGINT;
		biSizeImage: LONGINT;
		biXpelsPerMeter: LONGINT;
		biYpelsPerMeter: LONGINT;
		biClrUsed: LONGINT;
		biClrImportant: LONGINT
	END;

	IconDirEntry = RECORD
		width, height, colorCount, res: CHAR;
		planes, bitCount: INTEGER;
		bytes: LONGINT;
		name: INTEGER
	END;

	CursorDirEntry = RECORD
		width, height, planes, bitCount: INTEGER;
		bytes: LONGINT;
		name: INTEGER
	END;

	VsFixedFileInfo = RECORD
		dwSignature: LONGINT;   (* e.g. 0xfeef04bd *)
		dwStrucVersion: LONGINT;   (* e.g. 0x00000042 = "0.42" *)
		dwFileVersionMs: LONGINT;   (* e.g. 0x00030075 = "3.75" *)
		dwFileVersionLs: LONGINT;   (* e.g. 0x00000031 = "0.31" *)
		dwProductVersionMs: LONGINT;   (* e.g. 0x00030010 = "3.10" *)
		dwProductVersionLs: LONGINT;   (* e.g. 0x00000031 = "0.31" *)
		dwFileFlagsMask: LONGINT;   (* = 0x3F for version "0.42" *)
		dwFileFlags: LONGINT;   (* e.g. VFF_DEBUG | VFF_PRERELEASE *)
		dwFileOs: LONGINT;   (* e.g. VOS_DOS_WINDOWS16 *)
		dwFileType: LONGINT;   (* e.g. VFT_DRIVER *)
		dwFileSubtype: LONGINT;   (* e.g. VFT2_DRV_KEYBOARD *)
		dwFileDateMs: LONGINT;   (* e.g. 0 *)
		dwFileDateLs: LONGINT (* e.g. 0 *)
	END;

	NameList = POINTER TO RECORD
		name: Files.FileName;
		next: NameList
	END;

	ValueList = POINTER TO RECORD (NameList)
		value: Files.FileName
	END;

	EntryList = POINTER TO RECORD (ValueList)
		entry, fixup: LONGINT
	END;

	ImportList = POINTER TO RECORD (NameList)
		impDesc: ImageImportDescriptor;
		entries: EntryList
	END;

	ExportEntryList = POINTER TO RECORD (EntryList)
		nextOrd: ExportEntryList
	END;

	ResList = POINTER TO RECORD (EntryList)
		adr: LONGINT;
		head: ResourceHeader
	END;

	IconList = POINTER TO RECORD (ResList)
		dentry: IconDirEntry
	END;

	CursorList = POINTER TO RECORD (ResList)
		dentry: CursorDirEntry
	END;

	ScanProc = PROCEDURE ( reader: Streams.Reader; verbose : BOOLEAN; log : Streams.Writer );

	FindAdrDataStructure = POINTER TO RECORD
		moduleName: Linker0.Name;
		refs {UNTRACED}: Linker0.Bytes;
		module{UNTRACED} : Linker0.Module;
		next: FindAdrDataStructure;
	END;

VAR
	image, stub: Files.FileName;  isEXE: BOOLEAN;  imgHead: ImageOptionalHeader;
	text, idata, edata, reloc, rsrc: ImageSectionHeader;  version: ValueList;  imports: ImportList;
	exports, exportOrds: ExportEntryList;  modules: NameList;  icons: IconList;  cursors: CursorList;
	relocs: ARRAY MaxRelocs OF LONGINT;
	nRelocs: LONGINT;
	OberonToISO: ARRAY 256 OF CHAR;
	log: Streams.Writer;  refs: FindAdrDataStructure;

	PROCEDURE Error( CONST str1, str2: ARRAY OF CHAR );
	VAR msg: ARRAY 256 OF CHAR;
	BEGIN
		log.Update();  COPY( str1, msg );  Strings.Append( msg, str2 );  KernelLog.String( msg );  KernelLog.Ln;  HALT( 100 );
	END Error;

	PROCEDURE Assert( cond: BOOLEAN;  CONST str1, str2: ARRAY OF CHAR );
	BEGIN
		IF ~cond THEN Error( str1, str2 ) END
	END Assert;

	PROCEDURE LongOr( a, b: LONGINT ): LONGINT;
	BEGIN
		RETURN SYSTEM.VAL( LONGINT, SYSTEM.VAL( SET, a ) + SYSTEM.VAL( SET, b ) )
	END LongOr;

	PROCEDURE SetHighBit( VAR i: LONGINT );
	BEGIN
		INCL( SYSTEM.VAL( SET, i ), 31 )
	END SetHighBit;

	PROCEDURE Align( value, align: LONGINT ): LONGINT;
	BEGIN
		RETURN value + ((align - (value MOD align)) MOD align)
	END Align;

	PROCEDURE FileAlign( R: Streams.Writer;  align: LONGINT;  pad: CHAR );
	VAR n: LONGINT;
	BEGIN
		n := R.Pos();  n := Align( n, align ) - n;
		WHILE n > 0 DO R.Char( pad );  DEC( n ) END
	END FileAlign;

	PROCEDURE InitImageOptionalHeader( VAR head: ImageOptionalHeader );
	VAR i: LONGINT;
	BEGIN
		head.Magic := ImageOptionalMagic;  head.MajorLinkerVersion := MajorLinkerVersion;
		head.MinorLinkerVersion := MinorLinkerVersion;  head.SizeOfCode := 0;  head.SizeOfInitializedData := 0;
		head.SizeOfUninitializedData := 0;  head.AddressOfEntryPoint := 0;  head.BaseOfCode := 0;  head.BaseOfData := 0;
		head.ImageBase := 0;  head.SectionAlignment := DefaultSectionAlign;  head.FileAlignment := DefaultFileAlign;
		head.MajorOperatingSystemVersion := 4;  head.MinorOperatingSystemVersion := 0;  head.MajorImageVersion := 0;
		head.MinorImageVersion := 0;  head.MajorSubsystemVersion := 4;  head.MinorSubsystemVersion := 0;
		head.Win32VersionValue := 0;  head.SizeOfImage := 0;  head.SizeOfHeaders := DefaultFileAlign;  head.CheckSum := 0;
		head.Subsystem := DefaultImageSubsystem;  head.DllCharacteristics := 0;  head.SizeOfStackReserve := DefaultStackSize;
		head.SizeOfStackCommit := PageSize;  head.SizeOfHeapReserve := DefaultHeapSize;  head.SizeOfHeapCommit := PageSize;
		head.LoaderFlags := 0;  head.NumberOfRvaAndSizes := ImageNumberofDirectoryEntries;
		FOR i := 0 TO ImageNumberofDirectoryEntries - 1 DO
			head.DataDirectory[i].VirtualAddress := 0;  head.DataDirectory[i].Size := 0
		END
	END InitImageOptionalHeader;

	PROCEDURE InitSectionHeader( VAR head: ImageSectionHeader;  CONST name: ARRAY OF CHAR;  scnCnt, scnMem: LONGINT );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO ImageSizeofShortName - 1 DO head.Name[i] := 0X END;
		COPY( name, head.Name );  head.VirtualSize := 0;  head.VirtualAddress := 0;  head.SizeOfRawData := 0;
		head.PointerToRawData := 0;  head.PointerToRelocations := 0;  head.PointerToLinenumbers := 0;
		head.NumberOfRelocations := 0;  head.NumberOfLinenumbers := 0;  head.Characteristics := LongOr( scnCnt, scnMem )
	END InitSectionHeader;

	PROCEDURE InitImageImportDescriptor( VAR impDesc: ImageImportDescriptor );
	BEGIN
		impDesc.Characteristics := 0;  impDesc.TimeDateStamp := 0;  impDesc.ForwarderChain := 0;  impDesc.Name := 0;
		impDesc.FirstThunk := 0
	END InitImageImportDescriptor;

	PROCEDURE TimeDateStamp( ): LONGINT;
	VAR days, secs, y, m: LONGINT;  st: Dates.DateTime;
	BEGIN
		st := Dates.Now();  days := 0;
		FOR y := 1970 TO st.year - 1 DO
			IF Dates.LeapYear( y ) THEN INC( days, 366 ) ELSE INC( days, 365 ) END;
		END;
		FOR m := 1 TO st.month - 1 DO INC( days, Dates.NofDays( st.year, st.month ) );  END;
		INC( days, st.day - 1 );  secs := st.second + 60 * (st.minute + 60 * (st.hour + 24 * days));  RETURN secs
	END TimeDateStamp;

	PROCEDURE WriteImageHeader( R: Streams.Writer;  sections: INTEGER );
	VAR F: Files.File;  sR: Files.Reader;  dosHead: ImageDosHeader;  imgHead: ImageFileHeader;  char: LONGINT;  ch: CHAR;
		ignore: LONGINT;
	TYPE tSize = ARRAY SIZEOF( ImageDosHeader ) OF CHAR;
		imgHeadA = ARRAY SIZEOF( ImageFileHeader ) OF CHAR;

	BEGIN
		F := Files.Old( stub );  NEW( sR, F, 0 );  Assert( F # NIL , stub, " Files.Old failed" );
		sR.Bytes( SYSTEM.VAL( tSize, dosHead ), 0, SIZEOF( ImageDosHeader ), ignore );
		Assert( dosHead.emagic = ImageDosSignature, stub, " not a valid stub file" );  R.Update();  dosHead.elfanew := Align( F.Length(), 16 );
		R.Bytes( SYSTEM.VAL( tSize, dosHead ), 0, SIZEOF( ImageDosHeader ) );  sR.Char( ch );
		WHILE sR.res = Streams.Ok DO  (* was: WHILE ~sr.eof *)
			R.Char( ch );  sR.Char( ch )
		END;
		FileAlign( R, 16, 0X );  imgHead.Machine := ImageFileMachineI386;  imgHead.NumberOfSections := sections;
		imgHead.TimeDateStamp := TimeDateStamp();  imgHead.PointerToSymbolTable := 0;  imgHead.NumberOfSymbols := 0;
		imgHead.SizeOfOptionalHeader := SIZEOF( ImageOptionalHeader );
		char := LongOr( ImageFileExecutableImage, ImageFile32BitMachine );
		IF isEXE THEN char := LongOr( char, ImageFileRelocsStripped ) ELSE char := LongOr( char, ImageFileDll ) END;
		char := LongOr( char, ImageFileLineNumsStripped );  char := LongOr( char, ImageFileLocalSymsStripped );
		char := LongOr( char, ImageFileLargeAddressAware );
		imgHead.Characteristics := SHORT( char );  R.RawLInt( ImageNtSignature );
		R.Bytes( SYSTEM.VAL( imgHeadA, imgHead ), 0, SIZEOF( ImageFileHeader ) )
	END WriteImageHeader;

	PROCEDURE IsNameChar( ch: CHAR ): BOOLEAN;
	BEGIN
		RETURN ("a" <= ch) & ("z" >= ch) OR ("A" <= ch) & ("Z" >= ch) OR (ch = ".") OR ("0" <= ch) & (ch <= "9") OR (ch = ".");
	END IsNameChar;

	PROCEDURE ScanName( R: Streams.Reader;  VAR name: ARRAY OF CHAR );
	VAR i: LONGINT;  ch, och: CHAR;
	BEGIN
		R.SkipWhitespace;  i := 0;  ch := R.Peek();

		IF (ch = '"') OR (ch = "'") THEN
			och := ch;  R.Char( ch );
			REPEAT R.Char( name[i] );  INC( i );  UNTIL (R.Peek() = och) OR (R.Peek() = 0X) (* eof *) ;
			R.Char( ch );  name[i] := 0X;
		ELSIF ("a" <= ch) & ("z" >= ch) OR ("A" <= ch) & ("Z" >= ch) THEN
			REPEAT R.Char( name[i] );  INC( i );  UNTIL ~IsNameChar( R.Peek() );
			name[i] := 0X;
		ELSE Error( "name expected", "" )
		END;
	END ScanName;

	PROCEDURE ScanString( R: Streams.Reader;  VAR str: ARRAY OF CHAR );
	BEGIN
		R.SkipWhitespace; R.String( str );
	END ScanString;

	PROCEDURE ScanInt( R: Streams.Reader;  VAR i: LONGINT );
	BEGIN
		R.SkipWhitespace; R.Int( i, FALSE );
	END ScanInt;

	PROCEDURE Expect( R: Streams.Reader;  ch: CHAR );
	VAR c: CHAR;
		s: ARRAY 2 OF CHAR;
	BEGIN
		R.SkipWhitespace; R.Char( c );
		IF c # ch THEN s[0] := ch;  s[1] := 0X;  Error( s, " expected" ) END;
	END Expect;

	PROCEDURE Clean;
	BEGIN
		version := NIL;  imports := NIL;  exports := NIL;  exportOrds := NIL;  modules := NIL;  icons := NIL;  cursors := NIL;
	END Clean;

	PROCEDURE Init;
	VAR readWrite, readWriteExec, readDisc: LONGINT;
	BEGIN
		Clean();  image := "";  COPY( DefaultStub, stub );  isEXE := TRUE;
		readWrite := LongOr( ImageScnMemRead, ImageScnMemWrite );
		readWriteExec := LongOr( readWrite, ImageScnMemExecute );
		readDisc := LongOr( ImageScnMemRead, ImageScnMemDiscardable );  InitImageOptionalHeader( imgHead );  nRelocs := 0;
		InitSectionHeader( text, ".text", ImageScnCntCode, readWriteExec );
		InitSectionHeader( reloc, ".reloc", ImageScnCntInitializedData, readDisc );
		InitSectionHeader( idata, ".idata", ImageScnCntInitializedData, readWrite );
		InitSectionHeader( edata, ".edata", ImageScnCntInitializedData, ImageScnMemRead );
		InitSectionHeader( rsrc, ".rsrc", ImageScnCntInitializedData, ImageScnMemRead );  NEW( imports );  imports.next := NIL;
		imports.name := "";  imports.entries := NIL;
	END Init;

	PROCEDURE ScanVersion( reader: Streams.Reader; verbose : BOOLEAN; log : Streams.Writer );
	VAR val: ValueList;
	BEGIN
		NEW( val );  val.next := version;  version := val;
		ScanName( reader, val.name );  Expect( reader, "=" );
		ScanName( reader, val.value );
		IF verbose THEN log.String( val.name );  log.String( " = " );  log.String( val.value ); END;
	END ScanVersion;

	PROCEDURE ScanImport( reader: Streams.Reader;  verbose : BOOLEAN; log : Streams.Writer);
	VAR p, q: NameList;  imp: EntryList;  lib: ImportList;  libname: Files.FileName;  i, j: LONGINT;
	BEGIN
		NEW( imp );  imp.next := NIL;  ScanName( reader, imp.name );

		Expect( reader, "=" );  ScanName( reader, imp.value );

		i := 0;
		WHILE (imp.value[i] # 0X) & (imp.value[i] # ".") DO libname[i] := imp.value[i];  INC( i ) END;
		IF imp.value[i] # "." THEN
			libname := "";   (* pseudo lib *)
			Strings.UpperCase( imp.value )
		ELSE
			libname[i] := 0X;  Strings.Append( libname, ".DLL" );  INC( i );  j := 0;
			WHILE imp.value[i] # 0X DO imp.value[j] := imp.value[i];  INC( i );  INC( j ) END;
			imp.value[j] := 0X
		END;

		IF verbose THEN log.String( imp.name );  log.String( " = " );  log.String( imp.value ); END;

		p := imports;
		WHILE (p # NIL ) & (p.name # libname) DO p := p.next END;
		IF p = NIL THEN
			NEW( lib );  COPY( libname, lib.name );  lib.entries := NIL;  InitImageImportDescriptor( lib.impDesc );  q := imports;
			p := imports.next;
			WHILE (p # NIL ) & (p.name < lib.name) DO q := p;  p := p.next END;
			lib.next := p;  q.next := lib
		ELSE lib := p( ImportList )
		END;
		q := NIL;  p := lib.entries;
		WHILE (p # NIL ) & (p( EntryList ).value < imp.value) DO q := p;  p := p.next END;
		imp.next := p;
		IF q # NIL THEN q.next := imp ELSE lib.entries := imp END
	END ScanImport;

	PROCEDURE ScanExport( reader: Streams.Reader; verbose : BOOLEAN; log : Streams.Writer );
	VAR exp, e: ExportEntryList;  p, q: NameList;
	BEGIN
		NEW( exp );  exp.next := NIL;  exp.nextOrd := NIL;  ScanName( reader, exp.name );
		Expect( reader, "=" );  ScanName( reader, exp.value );
		IF verbose THEN log.String( exp.name );  log.String( " = " );  log.String( exp.value );  END;
		q := NIL;
		p := exports;
		WHILE (p # NIL ) & (p( NameList ).name < exp.name) DO q := p;  p := p.next END;
		Assert( (p = NIL ) OR (p( NameList ).name > exp.name), exp.name, " exported names must be unique" );  exp.next := p;
		IF q # NIL THEN q.next := exp ELSE exports := exp END;
		IF exp.entry > 0 THEN
			q := NIL;  e := exportOrds;
			WHILE (e # NIL ) & (e.entry < exp.entry) DO q := e;  e := e.nextOrd END;
			Assert( (e = NIL ) OR (e.entry > exp.entry), exp.name, " exported ordinals must be unique" );  exp.nextOrd := e;
			IF q # NIL THEN q( ExportEntryList ).nextOrd := exp ELSE exportOrds := exp END
		ELSE exp.nextOrd := exportOrds;  exportOrds := exp
		END
	END ScanExport;

	PROCEDURE ScanModule( reader: Streams.Reader; verbose : BOOLEAN; log : Streams.Writer );
	VAR mod, m: NameList;
	BEGIN
		NEW( mod ); ScanName( reader, mod.name );
		IF verbose THEN log.String( mod.name ); END;
		mod.next := NIL;
		IF modules # NIL THEN
			m := modules;
			WHILE m.next # NIL DO m := m.next END;
			m.next := mod
		ELSE modules := mod
		END
	END ScanModule;

	PROCEDURE ScanIcon( reader: Streams.Reader; verbose : BOOLEAN; log : Streams.Writer );
	VAR ico: IconList;  p, q: NameList;
	BEGIN
		NEW( ico );  ico.next := NIL;  ScanName( reader, ico.name );  Strings.UpperCase( ico.name );  Expect( reader, "=" );
		ScanName( reader, ico.value );  q := NIL;  p := icons;
		IF verbose THEN log.String( ico.name );  log.String( " = " );  log.String( ico.value ); END;
		WHILE (p # NIL ) & (p.name < ico.name) DO q := p;  p := p.next END;
		ico.next := p;
		IF q # NIL THEN q.next := ico ELSE icons := ico END
	END ScanIcon;

	PROCEDURE ScanCursor( reader: Streams.Reader; verbose : BOOLEAN; log : Streams.Writer );
	VAR cur: CursorList;  p, q: NameList;
	BEGIN
		NEW( cur );  cur.next := NIL;  ScanName( reader, cur.name );  Strings.UpperCase( cur.name );  Expect( reader, "=" );
		ScanName( reader, cur.value );  q := NIL;  p := cursors;
		IF verbose THEN log.String( cur.name );  log.String( " = " );  log.String( cur.value );  END;
		WHILE (p # NIL ) & (p.name < cur.name) DO q := p;  p := p.next END;
		cur.next := p;
		IF q # NIL THEN q.next := cur ELSE cursors := cur END
	END ScanCursor;

	PROCEDURE ScanList( reader: Streams.Reader;  entry: ScanProc; verbose : BOOLEAN; log : Streams.Writer );
	VAR c: CHAR;
	BEGIN
		IF verbose THEN log.Ln;  log.String( " -> " ); END;
		entry( reader, verbose, log );  reader.SkipWhitespace();
		WHILE (reader.Peek() = ",") DO
			reader.SkipWhitespace; reader.Char( c );
			IF verbose THEN log.Ln;  log.String( " -> " ); END;
			entry( reader, verbose, log );
		END;
	END ScanList;

	PROCEDURE Concat( CONST s0, s1, s2: ARRAY OF CHAR;  VAR s3: ARRAY OF CHAR );
	BEGIN
		Strings.Concat(s0,s1,s3);
		Strings.Concat(s3,s2,s3);
	END Concat;

	PROCEDURE ScanLinkText( reader: Streams.Reader; verbose : BOOLEAN; log : Streams.Writer);
	VAR keyword: ARRAY 32 OF CHAR;
		pos, j: LONGINT;  k: LONGINT;
	BEGIN
		WHILE reader.GetString( keyword ) DO
			IF verbose THEN log.String( keyword ); END;
			Strings.UpperCase( keyword ); pos := reader.Pos();
			IF keyword = "PROGRAM" THEN
				ScanName( reader, image );  Concat( (*Linker1.prefix*) "", image, ".EXE", image );
				IF verbose THEN log.String( " " );  log.String( image ); END;
				isEXE := TRUE;
				IF imgHead.ImageBase = 0 THEN imgHead.ImageBase := DefaultEXEImageBase END
			ELSIF keyword = "LIBRARY" THEN
				ScanName( reader, image );  Concat( (*Linker1.prefix*) "", image, ".DLL", image );
				IF verbose THEN log.String( " " );  log.String( image ); END;
				isEXE := FALSE;
				IF imgHead.ImageBase = 0 THEN imgHead.ImageBase := DefaultDLLImageBase END
			ELSIF keyword = "STUB" THEN
				ScanString( reader, stub );
				IF verbose THEN log.String( " " );  log.String( stub ); END;
			ELSIF keyword = "HEAPSIZE" THEN
				reader.SkipWhitespace; reader.Int( imgHead.SizeOfHeapReserve, TRUE );
				imgHead.SizeOfHeapReserve := Align( imgHead.SizeOfHeapReserve, PageSize );
				IF verbose THEN log.Hex( imgHead.SizeOfHeapReserve, 10 );  log.String( "H" ); END;
				IF imgHead.SizeOfHeapReserve > 0 THEN imgHead.SizeOfHeapCommit := PageSize ELSE imgHead.SizeOfHeapCommit := 0 END
			ELSIF keyword = "STACKSIZE" THEN
				reader.SkipWhitespace; reader.Int( imgHead.SizeOfStackReserve, TRUE );
				imgHead.SizeOfStackReserve := Align( imgHead.SizeOfStackReserve, PageSize );
				IF verbose THEN log.Hex( imgHead.SizeOfStackReserve, 10 );  log.String( "H" ); END;
				IF imgHead.SizeOfStackReserve > 0 THEN imgHead.SizeOfStackCommit := PageSize ELSE imgHead.SizeOfStackCommit := 0 END
			ELSIF keyword = "BASE" THEN
				reader.SkipWhitespace; reader.Int( imgHead.ImageBase, TRUE );
				IF verbose THEN log.Hex( imgHead.ImageBase, 10 );  log.String( "H" ); END;
				ScanInt( reader, imgHead.ImageBase )
			ELSIF keyword = "IMGVERSION" THEN
				reader.SkipWhitespace; reader.String( keyword );   (* read until whitespace *)
				k := 0;  Strings.StrToIntPos( keyword, j, k );  imgHead.MajorImageVersion := SHORT( j );
				IF keyword[k] = "." THEN INC( k );  Strings.StrToIntPos( keyword, j, k );  imgHead.MinorImageVersion := SHORT( j ) END;
				IF verbose THEN log.String( " " );  log.Int( imgHead.MajorImageVersion, 1 );  log.String( "." );  log.Int( imgHead.MinorImageVersion, 1 ); END;
			ELSIF keyword = "VERSION" THEN ScanList( reader, ScanVersion, verbose, log)
			ELSIF keyword = "SUBSYSTEM" THEN
				ScanName( reader, keyword );  Strings.UpperCase( keyword );
				IF verbose THEN log.String( " " );  log.String( keyword ); END;
				IF keyword = "GUI" THEN imgHead.Subsystem := ImageSubsystemWindowsGui
				ELSIF keyword = "CUI" THEN imgHead.Subsystem := ImageSubsystemWindowsCui
				ELSIF keyword = "NATIVE" THEN imgHead.Subsystem := ImageSubsystemNative
				ELSE Error( "unknown subsystem ", keyword )
				END
			ELSIF keyword = "IMPORTS" THEN ScanList( reader, ScanImport, verbose, log )
			ELSIF keyword = "EXPORTS" THEN ScanList( reader, ScanExport, verbose, log )
			ELSIF keyword = "MODULES" THEN ScanList( reader, ScanModule, verbose, log )
			ELSIF keyword = "ICONS" THEN ScanList( reader, ScanIcon, verbose, log )
			ELSIF keyword = "CURSORS" THEN ScanList( reader, ScanCursor, verbose, log )
			ELSE Error( "unknown keyword ", keyword )
			END;
			IF verbose THEN log.Ln;  log.Update; END;
		END
	END ScanLinkText;

	PROCEDURE AddReloc( offs, val: LONGINT );
	BEGIN
		IF ~isEXE & (val # 0) THEN
			ASSERT( val >= imgHead.ImageBase );
			IF nRelocs < MaxRelocs THEN relocs[nRelocs] := text.VirtualAddress + offs;  INC( nRelocs ) ELSE Error( "Too many relocations", "" ) END;
		END
	END AddReloc;

	PROCEDURE AddFileReloc( R: Streams.Writer;  val: LONGINT );
	VAR offs: LONGINT;
	BEGIN
		IF ~isEXE & (val # 0) THEN offs := R.Pos() - text.PointerToRawData;  AddReloc( offs, val ) END
	END AddFileReloc;

	PROCEDURE SplitName( CONST name: ARRAY OF CHAR;  VAR moduleName, selectorName: ARRAY OF CHAR );
	VAR i, j: LONGINT;
	BEGIN
		i := 0;
		WHILE (name[i] # 0X) & (name[i] # ".") DO moduleName[i] := name[i];  INC( i );  END;
		moduleName[i] := 0X;
		IF (name[i] = ".") THEN
			INC( i );  j := 0;
			WHILE name[i] # 0X DO selectorName[j] := name[i];  INC( i );  INC( j ) END;
			selectorName[j] := 0X;
		ELSE selectorName := ""
		END
	END SplitName;

	PROCEDURE WriteText( R: Streams.Writer;  offs: LONGINT );
	VAR adr, pos, heapSize, unload, exit: LONGINT;  name, obj: NameList;
	BEGIN
		heapSize := R.Pos() - text.PointerToRawData;
		imgHead.AddressOfEntryPoint := text.VirtualAddress + R.Pos() - text.PointerToRawData;
		R.Char( CHR( 053H ) );   (* PUSH EBX *)
		R.Char( CHR( 055H ) );   (* PUSH EBP *)
		R.Char( CHR( 056H ) );   (* PUSH ESI *)
		R.Char( CHR( 057H ) );   (* PUSH EDI *)
		IF ~isEXE THEN
			R.Char( CHR( 08BH ) );   (* MOV EBX, ReasonForCall *)
			R.Char( CHR( 05CH ) );  R.Char( CHR( 024H ) );  R.Char( CHR( 018H ) );
			R.Char( CHR( 083H ) );   (* CMP EBX, 0 *)
			R.Char( CHR( 0FBH ) );  R.Char( CHR( 000H ) );
			R.Char( CHR( 00FH ) );   (* JNE x *)
			R.Char( CHR( 085H ) );  R.RawLInt( 005H );
			R.Char( CHR( 0E9H ) );   (* JMP DLLUnload *)
			unload := R.Pos();  R.RawLInt( 0 );
			(* x: *)
			R.Char( CHR( 083H ) );   (* CMP EBX, 1 *)
			R.Char( CHR( 0FBH ) );  R.Char( CHR( 001H ) );
			R.Char( CHR( 00FH ) );   (* JNE Exit *)
			R.Char( CHR( 085H ) );  exit := R.Pos();  R.RawLInt( 0 );
			(* DLLLoad: *)
		END;

		(* fixup dll imports *)
		name := imports.next;
		WHILE name # NIL DO
			obj := name( ImportList ).entries;
			WHILE obj # NIL DO
				WITH obj: EntryList DO
					adr := GetVariableAdr( obj.name );
					R.Char( CHR( 08BH ) );   (* MOX EBX, [imgHead.ImageBase+obj.dllAdr] *)
					R.Char( CHR( 01DH ) );  obj.fixup := R.Pos();  AddFileReloc( R, imgHead.ImageBase );  R.RawLInt( 0 (*obj.dllAdr*) );
					R.Char( CHR( 089H ) );   (* MOX [adr], EBX *)
					R.Char( CHR( 01DH ) );  AddFileReloc( R, adr );  R.RawLInt( adr )
				END;
				obj := obj.next
			END;
			name := name.next
		END;

		(* loader fixups *)
		obj := imports.entries;
		WHILE obj # NIL DO
			WITH obj: EntryList DO
				adr := GetVariableAdr( obj.name );
				IF obj.value = "HEAPSIZE" THEN
					R.Char( CHR( 0BBH ) );   (* MOX EBX, HeapSize *)
					R.RawLInt( heapSize )
				ELSIF obj.value = "HEAPADR" THEN
					R.Char( CHR( 0BBH ) );   (* MOX EBX, HeapAdr *)
					AddFileReloc( R, imgHead.ImageBase + text.VirtualAddress );  R.RawLInt( imgHead.ImageBase + text.VirtualAddress )
				ELSIF obj.value = "HINSTANCE" THEN
					IF isEXE THEN
						R.Char( CHR( 0BBH ) );   (* MOX EBX, NULL *)
						R.RawLInt( NULL )
					ELSE
						R.Char( CHR( 08BH ) );   (* MOV EBX, x[ESP] *)
						R.Char( CHR( 05CH ) );  R.Char( CHR( 024H ) );
						R.Char( CHR( 014H ) ) (* x *)
					END
				ELSE Error( obj.value, ": unknown entry" )
				END;
				R.Char( CHR( 089H ) );   (* MOX [adr], EBX *)
				R.Char( CHR( 01DH ) );  AddFileReloc( R, adr );  R.RawLInt( adr )
			END;
			obj := obj.next
		END;
		(* init calls *)
		pos := R.Pos();  R.Char( CHR( 0E8H ) );   (* CALL *) R.RawLInt( text.PointerToRawData + offs - pos - 5 );
		IF ~isEXE THEN
			R.Char( CHR( 0E9H ) );   (* JMP Exit *)
			R.RawLInt( 5 );
			(* DLLUnload: *)
			pos := R.Pos();  R.SetPos( unload );  R.RawLInt( pos - unload - 4 );  R.SetPos( text.PointerToRawData + offs + 1 );
			R.RawLInt( adr );  R.SetPos( pos );
			R.Char( CHR( 0E8H ) );   (* CALL first module (Kernel32) *)
			R.RawLInt( text.PointerToRawData + offs + adr - pos );  pos := R.Pos();  R.SetPos( exit );  R.RawLInt( pos - exit - 4 );
			R.SetPos( pos )
			(* Exit: *)
		END;

		R.Char( CHR( 05FH ) );   (* POP EDI *)
		R.Char( CHR( 05EH ) );   (* POP ESI *)
		R.Char( CHR( 05DH ) );   (* POP EBP *)
		R.Char( CHR( 05BH ) );   (* POP EBX *)
		IF isEXE THEN
			R.Char( CHR( 0B8H ) );  R.RawLInt( 0 );   (* MOV EAX, 0 *)
			R.Char( CHR( 0C3H ) ) (* RET *)
		ELSE
			R.Char( CHR( 0B8H ) );  R.RawLInt( -1 );   (* MOV EAX, TRUE *)
			R.Char( CHR( 0C2H ) );  R.Char( CHR( 00CH ) );  R.Char( CHR( 000H ) ) (* RET 12 *)
		END;
		text.VirtualSize := R.Pos() - text.PointerToRawData;
		FileAlign( R, DefaultFileAlign, CHR( 0CCH ) );   (* INT 3 *)
		text.SizeOfRawData := R.Pos() - text.PointerToRawData
	END WriteText;

	PROCEDURE WriteIData( R: Files.Writer;  F: Files.File );
	VAR
		name, obj, imps: NameList;  pos, p, i, shift, adr: LONGINT;
	TYPE ImageImportDescriptorA = ARRAY SIZEOF( ImageImportDescriptor ) OF CHAR;
	BEGIN
		imps := imports.next;  idata.PointerToRawData := R.Pos();
		idata.VirtualAddress := text.VirtualAddress + Align( text.SizeOfRawData, DefaultSectionAlign );
		imgHead.DataDirectory[ImageDirectoryEntryImport].VirtualAddress := idata.VirtualAddress;
		shift := idata.VirtualAddress - idata.PointerToRawData;  name := imps;
		WHILE name # NIL DO
			R.Bytes( SYSTEM.VAL( ImageImportDescriptorA, name( ImportList ).impDesc ), 0, SIZEOF( ImageImportDescriptor ) );
			name := name.next
		END;
		FOR i := 0 TO SIZEOF( ImageImportDescriptor ) - 1 DO R.Char( 0X ) END;
		imgHead.DataDirectory[ImageDirectoryEntryImport].Size := R.Pos() - idata.PointerToRawData;  name := imps;
		WHILE name # NIL DO
			WITH name: ImportList DO
				R.Update();  name.impDesc.Characteristics := F.Length();  R.SetPos( name.impDesc.Characteristics );  obj := name.entries;
				WHILE obj # NIL DO R.RawLInt( 0 );  obj := obj.next END;
				R.RawLInt( 0 )
			END;
			name := name.next
		END;
		pos := R.Pos();  imgHead.DataDirectory[ImageDirectoryEntryIat].VirtualAddress := pos + shift;  name := imps;
		WHILE name # NIL DO
			WITH name: ImportList DO
				R.Update();  name.impDesc.FirstThunk := F.Length();  R.SetPos( name.impDesc.FirstThunk );  obj := name.entries;
				WHILE obj # NIL DO R.RawLInt( 0 );  obj := obj.next END;
				R.RawLInt( 0 )
			END;
			name := name.next
		END;
		imgHead.DataDirectory[ImageDirectoryEntryIat].Size := R.Pos() - pos;  R.SetPos( idata.PointerToRawData );  name := imps;
		WHILE name # NIL DO
			WITH name: ImportList DO
				pos := R.Pos();  i := 0;  obj := name.entries;
				WHILE obj # NIL DO
					WITH obj: EntryList DO
						R.Update();  p := F.Length();  R.SetPos( p );  R.RawInt( SHORT( obj.entry ) );  R.RawString( obj.value );
						FileAlign( R, 2, 0X );  p := p + shift;  R.SetPos( name.impDesc.Characteristics + i * 4 );  R.RawLInt( p );
						adr := name.impDesc.FirstThunk + i * 4;  R.SetPos( adr );  R.RawLInt( p );  R.SetPos( obj.fixup );
						R.RawLInt( imgHead.ImageBase + adr + shift )
					END;
					obj := obj.next;  INC( i )
				END;
				R.Update();  name.impDesc.Name := F.Length();  R.SetPos( name.impDesc.Name );  R.RawString( name.name );
				FileAlign( R, 2, 0X );  name.impDesc.Characteristics := name.impDesc.Characteristics + shift;
				name.impDesc.FirstThunk := name.impDesc.FirstThunk + shift;  name.impDesc.Name := name.impDesc.Name + shift;
				R.SetPos( pos );  R.Bytes( SYSTEM.VAL( ImageImportDescriptorA, name.impDesc ), 0, SIZEOF( ImageImportDescriptor ) )
			END;
			name := name.next
		END;
		R.Update();  R.SetPos( F.Length() );  idata.VirtualSize := R.Pos() - idata.PointerToRawData;
		FileAlign( R, DefaultFileAlign, 0X );  idata.SizeOfRawData := R.Pos() - idata.PointerToRawData
	END WriteIData;

	PROCEDURE AssignExportOrdinals( ): LONGINT;
	VAR e, f, g, next, new: ExportEntryList;  n: LONGINT;
	BEGIN
		f := NIL;  e := exportOrds;
		WHILE (e # NIL ) & (e.entry <= 0) DO f := e;  e := e.nextOrd END;
		IF f # NIL THEN f.nextOrd := NIL END;
		new := e;  e := exportOrds;
		WHILE e # NIL DO
			next := e.nextOrd;  g := NIL;  f := new;  n := 1;
			WHILE (f # NIL ) & (f.entry = n) DO g := f;  f := f.nextOrd;  INC( n ) END;
			e.entry := n;  e.nextOrd := f;
			IF g # NIL THEN g.nextOrd := e ELSE new := e END;
			e := next
		END;
		e := new;  n := 1;
		WHILE (e # NIL ) & (e.entry = n) DO
			KernelLog.String( e.name );  KernelLog.String( " " );  KernelLog.Int( e.entry, 1 );  KernelLog.Ln();  e := e.nextOrd;  INC( n )
		END;
		(* Assert(e = NIL, e.name, " exported ordinals must be unique") *)
		IF e # NIL THEN Error( e.name, " exported ordinals must be unique" ) END;
		exportOrds := new;  RETURN n - 1
	END AssignExportOrdinals;

	PROCEDURE WriteEData( R: Streams.Writer );
	VAR  (* F: Files.File; *) head: ImageExportDirectory;  adr, i, n, pos, fix: LONGINT;  e: ExportEntryList;  p: NameList;
	TYPE headA = ARRAY SIZEOF( ImageExportDirectory ) OF CHAR;
	BEGIN
		n := AssignExportOrdinals();
		edata.PointerToRawData := R.Pos();   (*  F := Files.Base(R);*)
		edata.VirtualAddress := idata.VirtualAddress + Align( idata.SizeOfRawData, DefaultSectionAlign );
		imgHead.DataDirectory[ImageDirectoryEntryExport].VirtualAddress := edata.VirtualAddress;  head.Characteristics := 0;
		head.TimeDateStamp := TimeDateStamp();  head.MajorVersion := 0;  head.MinorVersion := 0;  head.Base := 1;
		head.NumberOfFunctions := n;  head.NumberOfNames := n;
		head.AddressOfFunctions := edata.VirtualAddress + SIZEOF( ImageExportDirectory );
		head.AddressOfNames := head.AddressOfFunctions + n * 4;  head.AddressOfNameOrdinals := head.AddressOfNames + n * 4;
		head.Name := head.AddressOfNameOrdinals + n * 2;  R.Bytes( SYSTEM.VAL( headA, head ), 0, SIZEOF( ImageExportDirectory ) );
		e := exportOrds;
		WHILE e # NIL DO adr := GetProcAdr( e.value );  R.RawLInt( adr - imgHead.ImageBase );  e := e.nextOrd END;
		fix := R.Pos();
		FOR i := 1 TO n DO R.RawLInt( 0 ) END;
		p := exports;
		WHILE p # NIL DO R.RawInt( SHORT( p( ExportEntryList ).entry - head.Base ) );  p := p.next END;
		R.RawString( image );  FileAlign( R, 2, 0X );  p := exports;
		WHILE p # NIL DO
			pos := R.Pos();  R.SetPos( fix );  R.RawLInt( pos - edata.PointerToRawData + edata.VirtualAddress );  R.SetPos( pos );
			INC( fix, 4 );  R.RawString( p.name );  FileAlign( R, 2, 0X );  p := p.next
		END;
		edata.VirtualSize := R.Pos() - edata.PointerToRawData;
		imgHead.DataDirectory[ImageDirectoryEntryExport].Size := edata.VirtualSize;  FileAlign( R, DefaultFileAlign, 0X );
		edata.SizeOfRawData := R.Pos() - edata.PointerToRawData
	END WriteEData;

	PROCEDURE QuickSortRelocs( lo, hi: LONGINT );
	VAR i, j, t, rva: LONGINT;
	BEGIN
		IF lo < hi THEN
			i := lo;  j := hi;  rva := relocs[(lo + hi) DIV 2];
			REPEAT
				WHILE relocs[i] < rva DO INC( i ) END;
				WHILE rva < relocs[j] DO DEC( j ) END;
				IF i <= j THEN t := relocs[i];  relocs[i] := relocs[j];  relocs[j] := t;  INC( i );  DEC( j ) END
			UNTIL i > j;
			QuickSortRelocs( lo, j );  QuickSortRelocs( i, hi )
		END
	END QuickSortRelocs;

	PROCEDURE WriteOffs( R: Streams.Writer;  offs, type: LONGINT );
	BEGIN
		R.RawInt( SHORT( ASH( type, 12 ) + offs ) )
	END WriteOffs;

	PROCEDURE WriteReloc( R: Streams.Writer );
	VAR head: ImageBaseRelocation;  last, this, i, fix: LONGINT;
	CONST size = SIZEOF( ImageBaseRelocation );
	TYPE sType = ARRAY size OF CHAR;

		PROCEDURE BeginHeader;
		CONST size = SIZEOF( ImageBaseRelocation );
		TYPE sType = ARRAY size OF CHAR;
		BEGIN
			fix := R.Pos();  head.VirtualAddress := this - (this MOD PageSize);  head.SizeOfBlock := SIZEOF( ImageBaseRelocation );
			R.Bytes( SYSTEM.VAL( sType, head ), 0, SIZEOF( ImageBaseRelocation ) )
		END BeginHeader;

		PROCEDURE EndHeader;
		VAR pos: LONGINT;
		BEGIN
			WriteOffs( R, 0, ImageRelBasedAbsolute );  INC( head.SizeOfBlock, 2 );
			IF (head.SizeOfBlock MOD 4) # 0 THEN WriteOffs( R, 0, ImageRelBasedAbsolute );  INC( head.SizeOfBlock, 2 ) END;
			pos := R.Pos();  R.SetPos( fix );  R.Bytes( SYSTEM.VAL( sType, head ), 0, SIZEOF( ImageBaseRelocation ) );  R.SetPos( pos )
		END EndHeader;

	BEGIN
		reloc.PointerToRawData := R.Pos();   (* F := Files.Base(R);*)
		IF exports # NIL THEN reloc.VirtualAddress := edata.VirtualAddress + Align( edata.SizeOfRawData, DefaultSectionAlign )
		ELSE reloc.VirtualAddress := idata.VirtualAddress + Align( idata.SizeOfRawData, DefaultSectionAlign )
		END;
		imgHead.DataDirectory[ImageDirectoryEntryBasereloc].VirtualAddress := reloc.VirtualAddress;
		QuickSortRelocs( 0, nRelocs - 1 );  i := 0;  this := relocs[0];  last := -1;  BeginHeader();
		WHILE i < nRelocs DO
			IF this # last THEN
				ASSERT( this > last );
				IF this >= (head.VirtualAddress + PageSize) THEN EndHeader();  BeginHeader() END;
				ASSERT( (this >= text.VirtualAddress) & (this <= (text.VirtualAddress + text.VirtualSize)) );
				WriteOffs( R, this - head.VirtualAddress, ImageRelBasedHighLow );  INC( head.SizeOfBlock, 2 );  last := this
			END;
			INC( i );  this := relocs[i]
		END;
		EndHeader();  reloc.VirtualSize := R.Pos() - reloc.PointerToRawData;
		imgHead.DataDirectory[ImageDirectoryEntryBasereloc].Size := reloc.VirtualSize;  FileAlign( R, DefaultFileAlign, 0X );
		reloc.SizeOfRawData := R.Pos() - reloc.PointerToRawData
	END WriteReloc;

	PROCEDURE WriteResDir( R: Streams.Writer;  named, id: LONGINT );
	VAR dir: ImageResourceDirectory;
	CONST size = SIZEOF( ImageResourceDirectory );
	TYPE tSize = ARRAY size OF CHAR;
	BEGIN
		dir.Characteristics := 0;  dir.TimeDateStamp := TimeDateStamp();  dir.MajorVersion := 0;  dir.MinorVersion := 0;
		dir.NumberOfNamedEntries := SHORT( named );  dir.NumberOfIdEntries := SHORT( id );
		R.Bytes( SYSTEM.VAL( tSize, dir ), 0, SIZEOF( ImageResourceDirectory ) )
	END WriteResDir;

	PROCEDURE WriteResEntry( R: Streams.Writer;  name, offset: LONGINT;  leaf: BOOLEAN );
	VAR entry: ImageResourceDirectoryEntry;
	CONST size = SIZEOF( ImageResourceDirectoryEntry );
	TYPE sType = ARRAY size OF CHAR;
	BEGIN
		entry.Name := name;  entry.OffsetToData := offset;
		IF leaf THEN SetHighBit( entry.OffsetToData ) END;
		R.Bytes( SYSTEM.VAL( sType, entry ), 0, SIZEOF( ImageResourceDirectoryEntry ) )
	END WriteResEntry;

	PROCEDURE WriteUString( R: Streams.Writer;  CONST str: ARRAY OF CHAR;  zero: BOOLEAN );
	VAR i: LONGINT;
	BEGIN
		i := 0;
		WHILE str[i] # 0X DO R.Char( OberonToISO[ORD( str[i] )] );  R.Char( 0X );  INC( i ) END;
		IF zero THEN R.Char( 0X );  R.Char( 0X ) END
	END WriteUString;

	PROCEDURE WriteResNameTable( R: Streams.Writer;  res: ResList );
	VAR name: NameList;
	BEGIN
		name := res;
		WHILE name # NIL DO
			WITH name: ResList DO
				name.adr := R.Pos() - rsrc.PointerToRawData;  SetHighBit( name.adr );
				R.RawInt( SHORT( Strings.Length( name.name ) ) );  WriteUString( R, name.name, FALSE )
			END;
			name := name.next
		END
	END WriteResNameTable;

	PROCEDURE WriteResLeafDir( R: Streams.Writer;  res: ResList );
	VAR name: NameList;
	BEGIN
		name := res;
		WHILE name # NIL DO
			WITH name: ResList DO WriteResDir( R, 0, 1 );  WriteResEntry( R, DefaultLanguage, name.adr, FALSE )
			END;
			name := name.next
		END
	END WriteResLeafDir;

	PROCEDURE CopyIcon( icoRes: IconList;  rR: Streams.Writer );
	VAR F: Files.File;  R: Files.Reader;  bHead: Bitmapinfoheader;  offs, i: LONGINT;  ch: CHAR;  ignore: LONGINT;
	CONST size = SIZEOF( ResourceHeader );
	TYPE tSize = ARRAY size OF CHAR;
		tSize2 = ARRAY 12 OF CHAR;
		tSize3 = ARRAY SIZEOF( Bitmapinfoheader ) OF CHAR;
	BEGIN
		F := Files.Old( icoRes.value );
		IF F # NIL THEN
			NEW( R, F, 0 );  R.Bytes( SYSTEM.VAL( tSize, icoRes.head ), 0, 6, ignore );
			IF (icoRes.head.reserved = 0) & (icoRes.head.type = 1) & (icoRes.head.count = 1) THEN
				R.Bytes( SYSTEM.VAL( tSize2, icoRes.dentry ), 0, 12, ignore );  R.RawLInt( offs );  R.SetPos( offs );
				R.Bytes( SYSTEM.VAL( tSize3, bHead ), 0, SIZEOF( Bitmapinfoheader ), ignore );  icoRes.dentry.planes := bHead.biPlanes;
				icoRes.dentry.bitCount := bHead.biBitCount;  R.SetPos( offs );
				FOR i := 1 TO icoRes.dentry.bytes DO R.Char( ch );  rR.Char( ch ) END;
				RETURN
			END
		END;
		Error( icoRes.value, " invalid icon file" )
	END CopyIcon;

	PROCEDURE CopyCursor( curRes: CursorList;  VAR rR: Streams.Writer );
	VAR F: Files.File;  R: Files.Reader;  bHead: Bitmapinfoheader;  offs, i: LONGINT;  x, y: INTEGER;  ch: CHAR;  ignore: LONGINT;
	CONST size = SIZEOF( ResourceHeader );
	TYPE tSize = ARRAY size OF CHAR;
		tSize2 = ARRAY SIZEOF( Bitmapinfoheader ) OF CHAR;
	BEGIN
		F := Files.Old( curRes.value );
		IF F # NIL THEN
			NEW( R, F, 0 );  R.Bytes( SYSTEM.VAL( tSize, curRes.head ), 0, 6, ignore );
			IF (curRes.head.reserved = 0) & (curRes.head.type = 2) & (curRes.head.count = 1) THEN
				R.RawLInt( i );  R.RawInt( x );  R.RawInt( y );  R.RawLInt( curRes.dentry.bytes );  R.RawLInt( offs );  R.SetPos( offs );
				R.Bytes( SYSTEM.VAL( tSize2, bHead ), 0, SIZEOF( Bitmapinfoheader ), ignore );
				curRes.dentry.width := SHORT( bHead.biWidth );  curRes.dentry.height := SHORT( bHead.biHeight );
				curRes.dentry.planes := bHead.biPlanes;  curRes.dentry.bitCount := bHead.biBitCount;  rR.RawInt( x );  rR.RawInt( y );
				R.SetPos( offs );
				FOR i := 1 TO curRes.dentry.bytes DO R.Char( ch );  rR.Char( ch ) END;
				INC( curRes.dentry.bytes, 4 );  RETURN
			END
		END;
		Error( curRes.value, " invalid cursor file" )
	END CopyCursor;

	PROCEDURE WriteVersionRes( R: Streams.Writer );
	VAR info: VsFixedFileInfo;  ver: NameList;  fix, fix0, fix1, fix2, ret: LONGINT;
	TYPE infoA = ARRAY SIZEOF( VsFixedFileInfo ) OF CHAR;
	BEGIN
		fix0 := R.Pos();  R.RawInt( 0 );  R.RawInt( SIZEOF( VsFixedFileInfo ) );  R.RawInt( 0 );  WriteUString( R, "VS_VERSION_INFO", TRUE );
		FileAlign( R, 4, 0X );  info.dwSignature := VsFfiSignature;  info.dwStrucVersion := VsFfiStrucVersion;
		info.dwFileVersionMs := imgHead.MajorImageVersion;  info.dwFileVersionLs := imgHead.MinorImageVersion;
		info.dwProductVersionMs := imgHead.MajorImageVersion;  info.dwProductVersionLs := imgHead.MinorImageVersion;
		info.dwFileFlagsMask := VsFfiFileFlagsMask;  info.dwFileFlags := 0;  info.dwFileOs := VosNtWindows32;
		IF isEXE THEN info.dwFileType := VftApp ELSE info.dwFileType := VftDll END;
		info.dwFileSubtype := Vft2Unknown;  info.dwFileDateMs := 0;  info.dwFileDateLs := 0;
		R.Bytes( SYSTEM.VAL( infoA, info ), 0, SIZEOF( VsFixedFileInfo ) );  fix1 := R.Pos();  R.RawInt( 0 );  R.RawInt( 0 );  R.RawInt( 1 );
		WriteUString( R, "StringFileInfo", TRUE );  FileAlign( R, 4, 0X );  fix2 := R.Pos();  R.RawInt( 0 );  R.RawInt( 0 );  R.RawInt( 1 );
		WriteUString( R, "040904e4", TRUE );  FileAlign( R, 4, 0X );  ver := version;
		WHILE ver # NIL DO
			WITH ver: ValueList DO
				fix := R.Pos();  R.RawInt( 0 );  R.RawInt( SHORT( Strings.Length( ver.value ) + 1 ) );  R.RawInt( 1 );
				WriteUString( R, ver.name, TRUE );  FileAlign( R, 4, 0X );  WriteUString( R, ver.value, TRUE );  ret := R.Pos();
				R.SetPos( fix );  R.RawInt( SHORT( ret - fix ) );  R.SetPos( ret );  FileAlign( R, 4, 0X )
			END;
			ver := ver.next
		END;
		ret := R.Pos();  R.SetPos( fix0 );  R.RawInt( SHORT( ret - fix0 ) );  R.SetPos( fix1 );  R.RawInt( SHORT( ret - fix1 ) );
		R.SetPos( fix2 );  R.RawInt( SHORT( ret - fix2 ) );  R.SetPos( ret )
	END WriteVersionRes;

	PROCEDURE WriteRSRC( R: Streams.Writer );
	VAR
		name: NameList;  data: ImageResourceDataEntry;
		n, pos, base, fix1, fix2, curPos, icoPos, grpCurPos, grpIcoPos, verPos: LONGINT;
	TYPE ImageResourceDirectoryEntryA = ARRAY SIZEOF( ImageResourceDirectoryEntry ) OF CHAR;
		A6 = ARRAY 6 OF CHAR;
		A14 = ARRAY 14 OF CHAR;
	BEGIN
		rsrc.PointerToRawData := R.Pos();   (* F := Files.Base(R);*)
		IF ~isEXE THEN rsrc.VirtualAddress := reloc.VirtualAddress + Align( reloc.SizeOfRawData, DefaultSectionAlign )
		ELSIF exports # NIL THEN rsrc.VirtualAddress := edata.VirtualAddress + Align( edata.SizeOfRawData, DefaultSectionAlign )
		ELSE rsrc.VirtualAddress := idata.VirtualAddress + Align( idata.SizeOfRawData, DefaultSectionAlign )
		END;
		imgHead.DataDirectory[ImageDirectoryEntryResource].VirtualAddress := rsrc.VirtualAddress;
		IF (icons # NIL ) & (cursors # NIL ) THEN WriteResDir( R, 0, 5 )
		ELSIF (icons # NIL ) OR (cursors # NIL ) THEN WriteResDir( R, 0, 3 )
		ELSE WriteResDir( R, 0, 1 )
		END;
		IF cursors # NIL THEN curPos := R.Pos();  WriteResEntry( R, RtCursor, 0, FALSE ) END;
		IF icons # NIL THEN icoPos := R.Pos();  WriteResEntry( R, RtIcon, 0, FALSE ) END;
		IF cursors # NIL THEN grpCurPos := R.Pos();  WriteResEntry( R, RtGroupCursor, 0, FALSE ) END;
		IF icons # NIL THEN grpIcoPos := R.Pos();  WriteResEntry( R, RtGroupIcon, 0, FALSE ) END;
		verPos := R.Pos();  WriteResEntry( R, RtVersion, 0, FALSE );
		IF cursors # NIL THEN
			name := cursors;  n := 0;
			WHILE name # NIL DO
				WITH name: CursorList DO INC( n );  name.dentry.name := SHORT( n )
				END;
				name := name.next
			END;
			WriteResNameTable( R, cursors );  FileAlign( R, 4, 0X );  pos := R.Pos();  base := pos - rsrc.PointerToRawData;
			R.SetPos( curPos );  WriteResEntry( R, RtCursor, base, TRUE );
			base := base + SIZEOF( ImageResourceDirectory ) + n * SIZEOF( ImageResourceDirectoryEntry );  R.SetPos( grpCurPos );
			WriteResEntry( R, RtGroupCursor, base, TRUE );
			base := base + SIZEOF( ImageResourceDirectory ) + n * SIZEOF( ImageResourceDirectoryEntry );  R.SetPos( pos );
			WriteResDir( R, 0, n );  name := cursors;
			WHILE name # NIL DO
				WITH name: CursorList DO
					WriteResEntry( R, name.dentry.name, base, TRUE );
					base := base + SIZEOF( ImageResourceDirectory ) + SIZEOF( ImageResourceDirectoryEntry )
				END;
				name := name.next
			END;
			WriteResDir( R, n, 0 );  name := cursors;
			WHILE name # NIL DO
				WITH name: ResList DO
					WriteResEntry( R, name.adr, base, TRUE );
					base := base + SIZEOF( ImageResourceDirectory ) + SIZEOF( ImageResourceDirectoryEntry )
				END;
				name := name.next
			END;
			fix1 := R.Pos();  WriteResLeafDir( R, cursors );  fix2 := R.Pos();  WriteResLeafDir( R, cursors );  name := cursors;
			WHILE name # NIL DO
				WITH name: CursorList DO
					pos := R.Pos();  name.adr := pos - rsrc.PointerToRawData;
					data.OffsetToData := pos - rsrc.PointerToRawData + rsrc.VirtualAddress + SIZEOF( ImageResourceDataEntry );
					data.Size := 0;  data.CodePage := 0;  data.Reserved := 0;
					R.Bytes( SYSTEM.VAL( ImageResourceDirectoryEntryA, data ), 0, SIZEOF( ImageResourceDataEntry ) );
					data.Size := R.Pos();  CopyCursor( name, R );  data.Size := R.Pos() - data.Size;  R.SetPos( pos );
					R.Bytes( SYSTEM.VAL( ImageResourceDirectoryEntryA, data ), 0, SIZEOF( ImageResourceDataEntry ) );
					R.SetPos( R.Pos() + data.Size );  FileAlign( R, 8, 0X )
				END;
				name := name.next
			END;
			pos := R.Pos();  R.SetPos( fix1 );  WriteResLeafDir( R, cursors );  R.SetPos( pos );  name := cursors;
			WHILE name # NIL DO
				WITH name: CursorList DO
					pos := R.Pos();  name.adr := pos - rsrc.PointerToRawData;
					data.OffsetToData := pos - rsrc.PointerToRawData + rsrc.VirtualAddress + SIZEOF( ImageResourceDataEntry );
					data.Size := 6 + 14;  data.CodePage := 0;  data.Reserved := 0;
					R.Bytes( SYSTEM.VAL( ImageResourceDirectoryEntryA, data ), 0, SIZEOF( ImageResourceDataEntry ) );
					R.Bytes( SYSTEM.VAL( A6, name.head ), 0, 6 );  R.Bytes( SYSTEM.VAL( A14, name.dentry ), 0, 14 );  FileAlign( R, 4, 0X )
				END;
				name := name.next
			END;
			pos := R.Pos();  R.SetPos( fix2 );  WriteResLeafDir( R, cursors );  R.SetPos( pos )
		END;
		IF icons # NIL THEN
			name := icons;  n := 0;
			WHILE name # NIL DO
				WITH name: IconList DO INC( n );  name.dentry.name := SHORT( n )
				END;
				name := name.next
			END;
			WriteResNameTable( R, icons );  FileAlign( R, 4, 0X );  pos := R.Pos();  base := pos - rsrc.PointerToRawData;
			R.SetPos( icoPos );  WriteResEntry( R, RtIcon, base, TRUE );
			base := base + SIZEOF( ImageResourceDirectory ) + n * SIZEOF( ImageResourceDirectoryEntry );  R.SetPos( grpIcoPos );
			WriteResEntry( R, RtGroupIcon, base, TRUE );
			base := base + SIZEOF( ImageResourceDirectory ) + n * SIZEOF( ImageResourceDirectoryEntry );  R.SetPos( pos );
			WriteResDir( R, 0, n );  name := icons;
			WHILE name # NIL DO
				WITH name: IconList DO
					WriteResEntry( R, name.dentry.name, base, TRUE );
					base := base + SIZEOF( ImageResourceDirectory ) + SIZEOF( ImageResourceDirectoryEntry )
				END;
				name := name.next
			END;
			WriteResDir( R, n, 0 );  name := icons;
			WHILE name # NIL DO
				WITH name: ResList DO
					WriteResEntry( R, name.adr, base, TRUE );
					base := base + SIZEOF( ImageResourceDirectory ) + SIZEOF( ImageResourceDirectoryEntry )
				END;
				name := name.next
			END;
			fix1 := R.Pos();  WriteResLeafDir( R, icons );  fix2 := R.Pos();  WriteResLeafDir( R, icons );  name := icons;
			WHILE name # NIL DO
				WITH name: IconList DO
					pos := R.Pos();  name.adr := pos - rsrc.PointerToRawData;
					data.OffsetToData := pos - rsrc.PointerToRawData + rsrc.VirtualAddress + SIZEOF( ImageResourceDataEntry );
					data.Size := 0;  data.CodePage := 0;  data.Reserved := 0;
					R.Bytes( SYSTEM.VAL( ImageResourceDirectoryEntryA, data ), 0, SIZEOF( ImageResourceDataEntry ) );
					data.Size := R.Pos();  CopyIcon( name, R );  data.Size := R.Pos() - data.Size;  R.SetPos( pos );
					R.Bytes( SYSTEM.VAL( ImageResourceDirectoryEntryA, data ), 0, SIZEOF( ImageResourceDataEntry ) );
					R.SetPos( R.Pos() + data.Size );  FileAlign( R, 8, 0X )
				END;
				name := name.next
			END;
			pos := R.Pos();  R.SetPos( fix1 );  WriteResLeafDir( R, icons );  R.SetPos( pos );  name := icons;
			WHILE name # NIL DO
				WITH name: IconList DO
					pos := R.Pos();  name.adr := pos - rsrc.PointerToRawData;
					data.OffsetToData := pos - rsrc.PointerToRawData + rsrc.VirtualAddress + SIZEOF( ImageResourceDataEntry );
					data.Size := 6 + 14;  data.CodePage := 0;  data.Reserved := 0;
					R.Bytes( SYSTEM.VAL( ImageResourceDirectoryEntryA, data ), 0, SIZEOF( ImageResourceDataEntry ) );
					R.Bytes( SYSTEM.VAL( A6, name.head ), 0, 6 );  R.Bytes( SYSTEM.VAL( A14, name.dentry ), 0, 14 );  FileAlign( R, 4, 0X )
				END;
				name := name.next
			END;
			pos := R.Pos();  R.SetPos( fix2 );  WriteResLeafDir( R, icons );  R.SetPos( pos )
		END;
		pos := R.Pos();  R.SetPos( verPos );  WriteResEntry( R, RtVersion, pos - rsrc.PointerToRawData, TRUE );  R.SetPos( pos );
		WriteResDir( R, 0, 1 );
		WriteResEntry( R, 1, pos - rsrc.PointerToRawData + SIZEOF( ImageResourceDirectory ) + SIZEOF( ImageResourceDirectoryEntry ),
								  TRUE );
		pos := R.Pos();  WriteResDir( R, 0, 1 );
		WriteResEntry( R, DefaultLanguage,
								  pos - rsrc.PointerToRawData + SIZEOF( ImageResourceDirectory ) + SIZEOF( ImageResourceDirectoryEntry ), FALSE );
		verPos := R.Pos();  data.OffsetToData := 0;  data.Size := 0;  data.CodePage := 0;  data.Reserved := 0;
		R.Bytes( SYSTEM.VAL( ImageResourceDirectoryEntryA, data ), 0, SIZEOF( ImageResourceDataEntry ) );  FileAlign( R, 16, 0X );
		pos := R.Pos();  data.OffsetToData := pos - rsrc.PointerToRawData + rsrc.VirtualAddress;  WriteVersionRes( R );  pos := R.Pos();
		data.Size := pos - verPos - SIZEOF( ImageResourceDataEntry );  R.SetPos( verPos );
		R.Bytes( SYSTEM.VAL( ImageResourceDirectoryEntryA, data ), 0, SIZEOF( ImageResourceDataEntry ) );  R.SetPos( pos );
		rsrc.VirtualSize := R.Pos() - rsrc.PointerToRawData;
		imgHead.DataDirectory[ImageDirectoryEntryResource].Size := rsrc.VirtualSize;  FileAlign( R, DefaultFileAlign, 0X );
		rsrc.SizeOfRawData := R.Pos() - rsrc.PointerToRawData
	END WriteRSRC;

(* GetNum - Get a compressed refblk number. *)

	PROCEDURE GetNum( refs: Linker0.Bytes;  VAR i, num: LONGINT );
	VAR n, s: LONGINT;  x: CHAR;
	BEGIN
		s := 0;  n := 0;  x := refs[i];  INC( i );
		WHILE ORD( x ) >= 128 DO INC( n, ASH( ORD( x ) - 128, s ) );  INC( s, 7 );  x := refs[i];  INC( i ) END;
		num := n + ASH( ORD( x ) MOD 64 - ORD( x ) DIV 64 * 64, s )
	END GetNum;

	PROCEDURE FindAdr( CONST refs: Linker0.Bytes;  CONST pat: ARRAY OF CHAR;  proc, var: BOOLEAN ): LONGINT;   (* cf. System.FindProc *)
	VAR i, j, m, t, ofs: LONGINT;  ch: CHAR;  found: BOOLEAN;
	BEGIN
		i := 0;  m := LEN( refs^ );  ch := refs[i];  INC( i );
		WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO  (* proc *)
			GetNum( refs, i, ofs );   (* pofs *)
			IF ch = 0F9X THEN
				GetNum( refs, i, t );   (* nofPars *)
				INC( i, 3 ) (* RetType, procLev, slFlag *)
			END;
			found := TRUE;  j := 0;
			REPEAT ch := refs[i];  found := found & (ch = pat[j]);  INC( j );  INC( i ) UNTIL ch = 0X;   (* pname *)
			IF found & proc THEN RETURN ofs END;
			IF i < m THEN
				ch := refs[i];  INC( i );   (* 1X | 3X | 0F8X | 0F9X *)
				WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO  (* var *)
					ch := refs[i];  INC( i );   (* type *)
					IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
						GetNum( refs, i, t ) (* dim/tdadr *)
					END;
					GetNum( refs, i, ofs );   (* vofs *)
					found := TRUE;  j := 0;
					REPEAT ch := refs[i];  found := found & (ch = pat[j]);  INC( j );  INC( i ) UNTIL ch = 0X;   (* vname *)
					IF found & var THEN RETURN ofs END;
					IF i < m THEN ch := refs[i];  INC( i ) END  (* 1X | 3X | 0F8X | 0F9X *)
				END
			END
		END;
		RETURN 0
	END FindAdr;

	PROCEDURE GetProcAdr( CONST name: ARRAY OF CHAR ): ADDRESS;
	BEGIN
		HALT( 200 );   (* to be implemented ! *)
		RETURN 0
	END GetProcAdr;

	PROCEDURE GetVariableAdr( CONST name: ARRAY OF CHAR ): ADDRESS;
	VAR moduleName, variableName: ARRAY 256 OF CHAR;
		adr: ADDRESS;  ref: FindAdrDataStructure;
	BEGIN
		SplitName( name, moduleName, variableName );  ref := GetRefs( moduleName );
		adr := ref.module.sb + FindAdr( ref.refs, variableName, FALSE , TRUE );  RETURN adr;
	END GetVariableAdr;

	PROCEDURE GetRefs( CONST moduleName: ARRAY OF CHAR ): FindAdrDataStructure;
	VAR ref: FindAdrDataStructure;
	BEGIN
		ref := refs;
		WHILE (ref # NIL ) DO
			IF ref.moduleName = moduleName THEN RETURN ref END;
			ref := ref.next;
		END;
		RETURN NIL;
	END GetRefs;

	PROCEDURE InitWithText( t: Texts.Text;  pos: LONGINT ): Streams.Reader;
	VAR buffer: Buffer;  len, i, j, ch: LONGINT;  r: Texts.TextReader;  bytesPerChar: LONGINT;  reader: Streams.StringReader;

		PROCEDURE ExpandBuf( newSize: LONGINT );
		VAR newBuf: Buffer;  i: LONGINT;
		BEGIN
			IF LEN( buffer^ ) >= newSize THEN RETURN END;
			NEW( newBuf, newSize );
			FOR i := 0 TO LEN( buffer^ ) - 1 DO newBuf[i] := buffer[i];  END;
			FOR i := LEN( buffer^ ) TO newSize - 1 DO newBuf[i] := 0X;  END;
			buffer := newBuf;
		END ExpandBuf;

	BEGIN
		t.AcquireRead;  len := t.GetLength();  bytesPerChar := 2;
		NEW( buffer, len * bytesPerChar );   (* UTF8 encoded characters use up to 5 bytes *)
		NEW( r, t );  r.SetPosition( pos );  j := 0;
		FOR i := 0 TO len - 1 DO
			r.ReadCh( ch );
			WHILE ~UTF8Strings.EncodeChar( ch, buffer^, j ) DO
				(* buffer too small *)
				INC( bytesPerChar );  ExpandBuf( bytesPerChar * len );
			END;
		END;
		t.ReleaseRead;  NEW( reader, LEN( buffer ) );  reader.Set( buffer^ );  RETURN reader;
	END InitWithText;

	PROCEDURE DoLink( T: Texts.Text;  CONST pref, dest, suff: ARRAY OF CHAR;  verbose : BOOLEAN; log: Streams.Writer ): BOOLEAN;
	VAR oldF, F: Files.File;  W: Files.Writer;  mod: Linker0.Module;  ref: FindAdrDataStructure;  base: LONGINT;  name: NameList;
		msg: ARRAY 256 OF CHAR;
		sections: INTEGER;  done: BOOLEAN;  res, offs: LONGINT;
		imageFilename, path, filename : Files.FileName;

	TYPE imgHeadA = ARRAY SIZEOF( ImageOptionalHeader ) OF CHAR;
		textA = ARRAY SIZEOF( ImageSectionHeader ) OF CHAR;

	BEGIN
		Init();  offs := 0;
		IF verbose THEN log.Ln; log.String("------------------------"); log.Ln; END;
		ScanLinkText( InitWithText( T, 0 ), verbose, log );
		sections := 3;   (* .text, .idata, .rsrc *)
		IF verbose THEN
			log.String("------------------------"); log.Ln;
			log.String("Linking "); log.String(image);
		END;
		IF (dest # "") THEN
			Files.SplitPath(dest, path, filename);
			COPY(dest, imageFilename);
			IF (filename = "") THEN
				Strings.Append(imageFilename, image);
			ELSE
				COPY(filename, image);
			END;
		ELSE
			COPY(image, imageFilename);
		END;
		oldF := Files.Old( imageFilename);
		F := Files.New( imageFilename );
		log.String(" into "); log.String(imageFilename);
		IF (oldF # NIL) THEN log.String(" (overwrite)"); oldF := NIL; END;
		log.String(" ... "); log.Ln; log.Update;
		NEW( W, F, 0 );  Assert( F # NIL , image, " Files.New failed" );  WriteImageHeader( W, sections );
		imgHead.SizeOfHeaders := W.Pos();  W.Bytes( SYSTEM.VAL( imgHeadA, imgHead ), 0, SIZEOF( ImageOptionalHeader ) );
		W.Bytes( SYSTEM.VAL( textA, text ), 0, SIZEOF( ImageSectionHeader ) );
		W.Bytes( SYSTEM.VAL( textA, idata ), 0, SIZEOF( ImageSectionHeader ) );
		IF exports # NIL THEN W.Bytes( SYSTEM.VAL( textA, edata ), 0, SIZEOF( ImageSectionHeader ) );  INC( sections ) END;
		IF ~isEXE THEN W.Bytes( SYSTEM.VAL( textA, reloc ), 0, SIZEOF( ImageSectionHeader ) );  INC( sections ) END;
		W.Bytes( SYSTEM.VAL( textA, rsrc ), 0, SIZEOF( ImageSectionHeader ) );  FileAlign( W, DefaultFileAlign, 0X );
		text.VirtualAddress := BaseRVA;  base := imgHead.ImageBase + text.VirtualAddress;

		Linker0.Open( pref, suff, base, NIL );  name := modules;
		WHILE name # NIL DO
			IF verbose THEN log.String( "  " );  log.String( name.name );  log.Ln();  log.Update; END;
			mod := Linker0.ThisModule( name.name, res, msg );
			name := name.next
		END;
		text.PointerToRawData := W.Pos();

		(* modules become unaccessible after Linker1.EndLink since fields are relocated, therefore keep link here: *)
		mod := SYSTEM.VAL( Linker0.Module, Linker0.root );  refs := NIL;
		WHILE mod # NIL DO
			NEW( ref );  ref.next := refs;  refs := ref;  ref.moduleName := mod.name;  ref.module := mod;  ref.refs := mod.refs;
			mod := mod.next;
		END;

		Linker0.Close( W, base, res, "", log );  WriteText( W, offs );  WriteIData( W, F );
		IF exports # NIL THEN WriteEData( W ) END;
		IF ~isEXE THEN WriteReloc( W ) END;
		WriteRSRC( W );  imgHead.SizeOfCode := text.SizeOfRawData;
		imgHead.SizeOfInitializedData := idata.SizeOfRawData + rsrc.SizeOfRawData;  imgHead.SizeOfUninitializedData := 0;
		imgHead.BaseOfCode := text.VirtualAddress;  imgHead.BaseOfData := 0;
		imgHead.SizeOfHeaders := imgHead.SizeOfHeaders + SIZEOF( ImageOptionalHeader ) + sections * SIZEOF( ImageSectionHeader );
		imgHead.SizeOfHeaders := Align( imgHead.SizeOfHeaders, DefaultFileAlign );
		imgHead.SizeOfImage :=
			Align( imgHead.SizeOfHeaders, DefaultSectionAlign ) + Align( text.SizeOfRawData, DefaultSectionAlign ) +
												 Align( idata.SizeOfRawData, DefaultSectionAlign ) +
												 Align( edata.SizeOfRawData, DefaultSectionAlign ) +
												 Align( reloc.SizeOfRawData, DefaultSectionAlign ) +
												 Align( rsrc.SizeOfRawData, DefaultSectionAlign );
		W.SetPos( 0 );  WriteImageHeader( W, sections );
		W.Bytes( SYSTEM.VAL( imgHeadA, imgHead ), 0, SIZEOF( ImageOptionalHeader ) );
		W.Bytes( SYSTEM.VAL( textA, text ), 0, SIZEOF( ImageSectionHeader ) );
		W.Bytes( SYSTEM.VAL( textA, idata ), 0, SIZEOF( ImageSectionHeader ) );
		IF exports # NIL THEN W.Bytes( SYSTEM.VAL( textA, edata ), 0, SIZEOF( ImageSectionHeader ) ) END;
		IF ~isEXE THEN W.Bytes( SYSTEM.VAL( textA, reloc ), 0, SIZEOF( ImageSectionHeader ) ) END;
		W.Bytes( SYSTEM.VAL( textA, rsrc ), 0, SIZEOF( ImageSectionHeader ) );  W.Update();  F.Update;  Files.Register( F );
		log.String( " done" );  done := TRUE;  Clean();  log.Ln();  log.Update();  RETURN done
	END DoLink;

(** PELinker.Link .Link-file *)
	PROCEDURE Link*( context: Commands.Context );
	VAR
		options : Options.Options; done: BOOLEAN;
		pref, dest, suff, filename: Files.FileName;  T: Texts.Text;  format, res: LONGINT;
	BEGIN {EXCLUSIVE}
		NEW(options);
		options.Add("p", "path", Options.String);
		options.Add("d", "destination", Options.String);
		options.Add("v", "verbose", Options.Flag);
		options.Add("e", "extension", Options.String);
		IF options.Parse(context.arg, context.out) THEN
			IF ~options.GetString("path", pref) THEN pref := ""; END;
			IF ~options.GetString("destination", dest) THEN dest := ""; END;
			IF ~options.GetString("extension", suff) THEN suff := DefaultFileExtension; END;
			log := context.out;
			context.out.String("PELinker.Link ");
			IF context.arg.GetString( filename ) THEN
				NEW( T );  TextUtilities.LoadAuto( T, filename, format, res );
				IF (res = 0) THEN
					context.out.String( "linking " );  context.out.String( filename );  context.out.String(" (");
					context.out.String("Extension: "); context.out.String(suff);
					context.out.String(", Path: "); context.out.String(pref);
					context.out.String(") ");
					done := DoLink( T, pref, dest, suff, options.GetFlag("verbose"), context.out );
				ELSE
					context.out.String("Could not open file "); context.out.String(filename); context.out.Ln;
				END;
			END;
		END;
	END Link;

	PROCEDURE InitModule;
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO 255 DO OberonToISO[i] := CHR( i ) END;
		OberonToISO[128] := CHR( 196 );  OberonToISO[129] := CHR( 214 );  OberonToISO[130] := CHR( 220 );
		OberonToISO[150] := CHR( 223 );  OberonToISO[139] := CHR( 224 );  OberonToISO[148] := CHR( 225 );
		OberonToISO[134] := CHR( 226 );  OberonToISO[131] := CHR( 228 );  OberonToISO[147] := CHR( 231 );
		OberonToISO[140] := CHR( 232 );  OberonToISO[144] := CHR( 233 );  OberonToISO[135] := CHR( 234 );
		OberonToISO[145] := CHR( 235 );  OberonToISO[141] := CHR( 236 );  OberonToISO[136] := CHR( 238 );
		OberonToISO[146] := CHR( 239 );  OberonToISO[149] := CHR( 241 );  OberonToISO[142] := CHR( 242 );
		OberonToISO[137] := CHR( 244 );  OberonToISO[132] := CHR( 246 );  OberonToISO[143] := CHR( 249 );
		OberonToISO[138] := CHR( 251 );  OberonToISO[133] := CHR( 252 );

	END InitModule;

BEGIN
	InitModule;
END PELinker.

SystemTools.Free PELinker ~

PELinker.Link Win32.Aos.Link ~

PELinker.Link -v --path=../obj/ --extension=.Obw --destination=../a2.exe Win32.Aos.Link ~

PET.Open Win32.Aos.Link ~
