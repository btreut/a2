(**AUTHOR "BohdanT"; PURPOSE: "MS Windows DLL loader for A2" *)
(** based on Maxim Gumerov library http://www.rsdn.ru/article/baseserv/peloader.xml *)

MODULE DLL;
IMPORT SYSTEM,Machine,Kernel32,Heaps,BIT,Strings,Files,KernelLog,Modules;
CONST
	IMAGE_SCN_MEM_NOT_CACHED		= 04000000H; (*Section is not cachable. *)
	IMAGE_SCN_MEM_EXECUTE			= 20000000H;  (* Section is executable. *)
	IMAGE_SCN_MEM_READ				= 40000000H;  (* Section is readable. *)
	IMAGE_SCN_MEM_WRITE				= SHORT(80000000H);  (*Section is writeable. *)

	PAGE_NOACCESS = 1;
	PAGE_READONLY = 2;
	PAGE_READWRITE = 4;
	PAGE_WRITECOPY = 8;
	PAGE_EXECUTE = 10H;
	PAGE_EXECUTE_READ = 20H;
	PAGE_EXECUTE_READWRITE = 40H;
	PAGE_EXECUTE_WRITECOPY = 80H;
	PAGE_NOCACHE = 200H;
	
	IMAGE_DIRECTORY_ENTRY_EXPORT		=0;		(*Export Directory *)
	IMAGE_DIRECTORY_ENTRY_BASERELOC	=5;
	IMAGE_DIRECTORY_ENTRY_IMPORT		=1;
	ImageNumberOfDirectoryEntries			=16;
  
TYPE
	String=Strings.String;
	PImageDosHeader = POINTER TO ImageDosHeader;
  ImageDosHeader = RECORD      (* DOS .EXE header                  *)
      e_magic1,e_magic2: CHAR;                    (* Magic number                     *)
      e_cblp: INTEGER;                     (* Bytes on last page of file       *)
      e_cp: INTEGER;                       (* Pages in file                    *)
      e_crlc: INTEGER;                     (* Relocations                      *)
      e_cparhdr: INTEGER;                  (* Size of header in paragraphs     *)
      e_minalloc: INTEGER;                 (* Minimum extra paragraphs needed  *)
      e_maxalloc: INTEGER;                 (* Maximum extra paragraphs needed  *)
      e_ss: INTEGER;                       (* Initial (relative) SS value      *)
      e_sp: INTEGER;                       (* Initial SP value                 *)
      e_csum: INTEGER;                     (* Checksum                         *)
      e_ip: INTEGER;                       (* Initial IP value                 *)
      e_cs: INTEGER;                       (* Initial (relative) CS value      *)
      e_lfarlc: INTEGER;                   (* File address of relocation table *)
      e_ovno: INTEGER;                     (* Overlay number                   *)
      e_res: ARRAY 4 OF INTEGER;      (* Reserved words                   *)
      e_oemid: INTEGER;                    (* OEM identifier (for e_oeminfo)   *)
      e_oeminfo: INTEGER;                  (* OEM information; e_oemid specific*)
      e_res2: ARRAY 10 OF INTEGER;     (* Reserved words                   *)
      lfanew: LONGINT;                 (* File address of new exe header   *)
  END;

	ImageImportDescriptor = POINTER TO RECORD
		OriginalFirstThunk: LONGINT;
		TimeDateStamp: LONGINT;
		ForwarderChain: LONGINT;
		Name: LONGINT;
		FirstThunk: LONGINT;
	END;

	ImageBaseRelocation = POINTER TO RECORD
		VirtualAddress: LONGINT;
		SizeOfBlock: LONGINT;
	END;

	TDllEntryProc* = PROCEDURE {WINAPI} (hinstDLL: LONGINT; dwReason: LONGINT; lpvReserved: LONGINT): BOOLEAN ;

	TItemsArray*=POINTER TO ARRAY OF RECORD name-:String;p-:LONGINT END;

	TLibArray* =RECORD
		nofitems-:LONGINT;
		items-:TItemsArray;
	END;
	
	TLibInfo* = POINTER TO RECORD (*in future mast be hide*)
		ImageBase: LONGINT;
		DllProc-: TDllEntryProc;
		LibsUsed-: TLibArray;
		Exports-: TLibArray;
	END;

	PImageSectionHeader = POINTER TO ImageSectionHeader;
	ImageSectionHeader = RECORD
		Name: ARRAY 8-1 OF CHAR;
		Misc: LONGINT;
		VirtualAddress: SYSTEM.ADDRESS;
		SizeOfRawData: LONGINT;
		PointerToRawData: SYSTEM.ADDRESS;
		PointerToRelocations: SYSTEM.ADDRESS;
		PointerToLinenumbers: SYSTEM.ADDRESS;
		NumberOfRelocations: INTEGER;
		NumberOfLinenumbers: INTEGER;
		Characteristics: LONGINT;
	END;

	ImageFileHeader=RECORD
		Machine: INTEGER;
		NumberOfSections: INTEGER;
		TimeDateStamp: LONGINT;
		PointerToSymbolTable: LONGINT;
		NumberOfSymbols: LONGINT;
		SizeOfOptionalHeader: INTEGER;
		Characteristics: INTEGER;
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


	PImageNtHeaders=POINTER TO ImageNtHeaders;
	ImageNtHeaders=RECORD
		Signature: LONGINT;
		FileHeader: ImageFileHeader;
		OptionalHeader: ImageOptionalHeader;
	END;

	ImageExportDirectory = POINTER TO RECORD
		Characteristics, TimeDateStamp: LONGINT;
		MajorVersion, MinorVersion: INTEGER;
		Name, Base, NumberOfFunctions, NumberOfNames,
		AddressOfFunctions, AddressOfNames, AddressOfNameOrdinals: LONGINT
	END;


  TSections = POINTER TO ARRAY OF ImageSectionHeader;

  Proc=PROCEDURE;
CONST
  IMPORTED_NAME_OFFSET = 00000002H;
  IMAGE_ORDINAL_FLAG32 = SHORT(80000000H);
  IMAGE_ORDINAL_MASK32 = 0000FFFFH;
 VAR
  proc:Proc;
PROCEDURE -Int3;
CODE{SYSTEM.i386}
	INT 3
END Int3;
(**Retrieve a procedure address given a module name, the procedure name *)
PROCEDURE GetProcedure(CONST moduleName, procedureName : ARRAY OF CHAR; VAR entryAdr : LONGINT);
VAR 
	mod : Modules.Module; ignoreMsg : ARRAY 32 OF CHAR; 
	m, i, j, ofs, t, res : LONGINT;
	ch:CHAR;
	n: ARRAY 64 OF CHAR;
	(* Get a compressed refblk number. *)
	PROCEDURE GetNum( refs: Modules.Bytes;  VAR i, num: LONGINT );  
	VAR n, s: LONGINT;  x: CHAR;  
	BEGIN 
		s := 0;  n := 0;  x := refs[i];  INC( i );  
		WHILE ORD( x ) >= 128 DO INC( n, ASH( ORD( x ) - 128, s ) );  INC( s, 7 );  x := refs[i];  INC( i ) END;  
		num := n + ASH( ORD( x ) MOD 64 - ORD( x ) DIV 64 * 64, s )
	END GetNum; 
BEGIN
	entryAdr:=0;
	mod := Modules.ThisModule(moduleName, res, ignoreMsg);
	IF res=0 THEN
		i := 0; m := LEN(mod.refs^);
		ch := mod.refs[i]; INC(i);
		WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) DO	(* proc *)
			GetNum(mod.refs, i, ofs);	(* pofs *)
			IF ch = 0F9X THEN
				GetNum(mod.refs, i, t);	(* nofPars *)
				INC(i, 3)	(* RetType, procLev, slFlag *)
			END;
			j:=0;
			REPEAT
				n[j]:= mod.refs[i];
				INC(i);INC(j);
			UNTIL n[j-1]=0X;
			IF n=procedureName THEN 
				entryAdr:=ofs+mod.firstProc;
				ch:=0X;
			ELSE
				IF i < m THEN
					ch := mod.refs[i]; INC(i);	(* 1X | 3X | 0F8X | 0F9X *)
					WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO	(* var *)
						ch := mod.refs[i]; INC(i);	(* type *)
						IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
							GetNum(mod.refs, i, t)	(* dim/tdadr *)
						END;
						GetNum(mod.refs, i, t);	(* vofs *)
						REPEAT ch := mod.refs[i]; INC(i) UNTIL ch = 0X;	(* vname *)
						IF i < m THEN ch := mod.refs[i]; INC(i) END	(* 1X | 3X | 0F8X | 0F9X *)
					END
				END
			END;
		END;
	END;
END GetProcedure;

(**Unload lybrary *)
PROCEDURE FreeLibrary*(VAR LoadedLib: TLibInfo);
VAR
  ObjectLoop: LONGINT;
BEGIN
(*  Result := False;
  with LoadedLib do
  begin
    if @DllProc # nil then
    begin
       DllProc(HModule(LoadedLib.ImageBase), DLL_PROCESS_DETACH, nil);
    end;
    for ObjectLoop := 0 to Length(LibsUsed) - 1 do
    begin
      if ObjectLoop >= Length(LibsUsed) then Exit;
      FreeLibrary(GetModuleHandle(pchar(LibsUsed[ObjectLoop])));
    end;
    SetLength(LibsUsed, 0);
  end;
  VirtualFree(LoadedLib.ImageBase, 0, MEM_RELEASE);
  Result := True;*)
END FreeLibrary;
	PROCEDURE Add(VAR a: TLibArray; text: ARRAY OF CHAR;p:LONGINT);
	VAR
		new:TItemsArray;
		i:LONGINT;
	BEGIN
		IF a.nofitems = LEN(a.items) THEN 
			NEW(new, LEN(a.items) * 2);
			FOR i := 0 TO a.nofitems - 1 DO new[i] := a.items[i] END;
			a.items := new;
		END;
		a.items[a.nofitems].name:=Strings.NewString(text);
		a.items[a.nofitems].p:=p;
		INC(a.nofitems);
	END Add;


	PROCEDURE Find(a: TLibArray; text: ARRAY OF CHAR; VAR Index: LONGINT): BOOLEAN;
	VAR
		i: LONGINT;
	BEGIN
		FOR i := 0 TO a.nofitems- 1 DO
			IF a.items[i].name^=text THEN
				Index := i;
				RETURN TRUE;
			END;
		END;
		RETURN FALSE;   
	END Find;

PROCEDURE GetProcAddress*(CONST hModule:TLibInfo; procName:ARRAY OF CHAR; VAR adr:LONGINT);
VAR
 idx:LONGINT;
BEGIN
	IF Find(hModule.Exports,procName,idx) THEN
		adr:=hModule.Exports.items[idx].p;
	ELSE
		adr:=0;
	END;
END GetProcAddress;
PROCEDURE xLoadLibrary*(Src: SYSTEM.ADDRESS): TLibInfo;
VAR
	nofstrings:LONGINT;

	DosHead:PImageDosHeader;
	tmp:LONGINT;
	imageBase: ANY;
	imageBaseDelta: LONGINT;
	imageNtHeaders: POINTER TO ImageNtHeaders;
	pSections: SYSTEM.ADDRESS;
	section:PImageSectionHeader;
	sectionLoop: LONGINT;
	SectionBase: ANY;
	VirtualSectionSize, RawSectionSize: LONGINT;
	OldProtect: LONGINT;
	NewLibInfo: TLibInfo;
	i,totalsize:LONGINT;
	PROCEDURE StrToInt(s: String): LONGINT;
	VAR
	 res:LONGINT;
	BEGIN
		Strings.StrToInt (s^, res);
		RETURN res;
	END StrToInt;

	PROCEDURE InitList(VAR a:TLibArray);
	BEGIN
		a.nofitems:=0;
		NEW(a.items, 5);
	END InitList;
	
	PROCEDURE GetSectionProtection(ImageScn: LONGINT): LONGINT;
	VAR
		result:LONGINT;
	BEGIN
		result:=0;
		IF  BIT.LAND(ImageScn,IMAGE_SCN_MEM_NOT_CACHED) # 0 THEN
			result := BIT.LOR(result,PAGE_NOCACHE);
		END;
		IF BIT.LAND(ImageScn,IMAGE_SCN_MEM_EXECUTE) # 0 THEN
			IF BIT.LAND(ImageScn,IMAGE_SCN_MEM_READ)# 0 THEN
				IF BIT.LAND(ImageScn,IMAGE_SCN_MEM_WRITE)# 0 THEN
					result := BIT.LOR(result,PAGE_EXECUTE_READWRITE)
				ELSE
					result := BIT.LOR(result,PAGE_EXECUTE_READ)
				END;
			ELSIF BIT.LAND(ImageScn,IMAGE_SCN_MEM_WRITE) # 0 THEN
				result := BIT.LOR(result,PAGE_EXECUTE_WRITECOPY);
			ELSE
				result := BIT.LOR(result,PAGE_EXECUTE)
			END;
		ELSIF BIT.LAND(ImageScn,IMAGE_SCN_MEM_READ)# 0 THEN
			IF BIT.LAND(ImageScn,IMAGE_SCN_MEM_WRITE) # 0 THEN
				result := BIT.LOR(result,PAGE_READWRITE)
			ELSE
				result := BIT.LOR(result,PAGE_READONLY)
			END;
		ELSIF BIT.LAND(ImageScn,IMAGE_SCN_MEM_WRITE) # 0 THEN
			result := BIT.LOR(result,PAGE_WRITECOPY)
		ELSE
			result := BIT.LOR(result,PAGE_NOACCESS);
		END;
		RETURN result;
	END GetSectionProtection;

	PROCEDURE ProcessExports(PExports: ImageExportDirectory; BlockSize: LONGINT);
	TYPE
		Str=ARRAY 255 OF CHAR;
	VAR
		i,j: LONGINT;
		ImportedFn: LONGINT;
		PFnName: LONGINT;
		FnName:Str;
		ch:CHAR;
		FnIndex: INTEGER;
		p:LONGINT;
		
		PROCEDURE IsForwarderString(data: LONGINT): BOOLEAN;
		VAR
		 tmp:LONGINT;
		BEGIN
			tmp:=SYSTEM.VAL(LONGINT,PExports);
			RETURN (data > tmp)&((data - tmp)<BlockSize);
		END IsForwarderString;

		PROCEDURE GetForwardedSymbol(ForwarderString: String):LONGINT;
		VAR
			sForwarderString, DllName: Strings.String;
			ForwarderLoop: LONGINT;
			LibHandle: LONGINT;
			i:LONGINT;
		BEGIN
			i:=Strings.Pos('.', ForwarderString^);
			NEW(DllName,i);
			Strings.Copy(ForwarderString^, 0, i,DllName^);
			
			IF ~Find(NewLibInfo.LibsUsed, DllName^, ForwarderLoop) THEN
				LibHandle := Kernel32.LoadLibrary(DllName^);(*TODO:now for test in WinAos*)
				Add(NewLibInfo.LibsUsed, DllName^,LibHandle);
			ELSE
				LibHandle := NewLibInfo.LibsUsed.items[ForwarderLoop].p;
			END;
			HALT(23); (*TODO 1*)
			
(*			IF ForwarderString^ = '#' THEN ForwarderString := pointer(StrToInt((ForwarderString + 1)));END;*)
			RETURN 	Kernel32.getProcAddress(LibHandle, ForwarderString^);
		END GetForwardedSymbol;

	BEGIN 
	KernelLog.String("PExports.NumberOfNames= "); KernelLog.Int(PExports.NumberOfNames, 0); KernelLog.Ln;
		FOR i := 0 TO PExports.NumberOfNames - 1 DO
			SYSTEM.GET(PExports.AddressOfNames + NewLibInfo.ImageBase+i*4,PFnName);
			
			PFnName:=PFnName + NewLibInfo.ImageBase;
			j:=0;
			REPEAT
				SYSTEM.GET(PFnName+j,ch);
				FnName[j]:=ch;
				INC(j);
			UNTIL ch=0X;
			
			SYSTEM.GET(PExports.AddressOfNameOrdinals + NewLibInfo.ImageBase+i*2,FnIndex);
(*			KernelLog.Memory(PExports.AddressOfNameOrdinals + NewLibInfo.ImageBase+i*4,32);*)
			SYSTEM.GET(PExports.AddressOfFunctions + NewLibInfo.ImageBase+4*FnIndex,p);
			p:=p+NewLibInfo.ImageBase;
			proc:=SYSTEM.VAL(Proc,p);
			Add(NewLibInfo.Exports,FnName,p);
			KernelLog.String("ExportFnName:"); KernelLog.String(FnName); KernelLog.String("= "); KernelLog.Hex(p, 0); KernelLog.Ln;
(*			KernelLog.Memory(p,32);*)
			IF IsForwarderString(SYSTEM.VAL(LONGINT,p))THEN
				HALT(23); (*TODO 1*)
(*				GetForwardedSymbol(SYSTEM.VAL(String,Imports[ImportedFn].ProcVar));*)
			END;
		END;
	END ProcessExports;
	
	PROCEDURE ProcessRelocs(PRelocs:ImageBaseRelocation);
	VAR
		PReloc: ImageBaseRelocation;
		RelocsSize: LONGINT;
		tmp:INTEGER;
		tmp1,Reloc: SYSTEM.ADDRESS;
		ModCount: LONGINT;
		RelocLoop: LONGINT;
		
	BEGIN
		PReloc := PRelocs;
		RelocsSize := imageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size;
		KernelLog.String("ProcessReloc= "); KernelLog.Int(RelocsSize, 0); KernelLog.Ln;
(*		KernelLog.Memory(SYSTEM.VAL(LONGINT,PRelocs),RelocsSize);*)
		WHILE SYSTEM.VAL(LONGINT,PReloc) - SYSTEM.VAL(LONGINT,PRelocs) < RelocsSize DO
			ModCount := (PReloc.SizeOfBlock-8(*SYSTEM.SIZEOF(ImageBaseRelocation)*)) DIV 2;
			Reloc := SYSTEM.VAL(LONGINT,PReloc)+8;
(*			KernelLog.String("============================================================================================ "); KernelLog.Ln;
			KernelLog.String("ModCount= "); KernelLog.Int(ModCount, 0); KernelLog.Ln;*)
			FOR RelocLoop := 0 TO ModCount - 1 DO
(*				KernelLog.String("Reloc= "); KernelLog.Int(Reloc, 0); KernelLog.Ln;*)
				SYSTEM.GET(Reloc,tmp);
(*				KernelLog.String("tmp= "); KernelLog.Int(tmp, 0); KernelLog.Ln;*)
				
				IF BIT.LAND(tmp,0F000H) # 0 THEN 
					SYSTEM.GET(NewLibInfo.ImageBase + PReloc.VirtualAddress + BIT.LAND(tmp,0FFFH) ,tmp1);
(*					KernelLog.String("tmp1= "); KernelLog.Int(tmp1, 0); 
					KernelLog.String(" =tmp1+delta= "); KernelLog.Int(tmp1+imageBaseDelta, 0); KernelLog.Ln;*)
					SYSTEM.PUT(NewLibInfo.ImageBase + PReloc.VirtualAddress + BIT.LAND(tmp,0FFFH),tmp1+imageBaseDelta);
				END;
				Reloc:=Reloc+2;
			END;
			PReloc:=SYSTEM.VAL(ImageBaseRelocation,Reloc);
		END;
(*		KernelLog.Memory(SYSTEM.VAL(LONGINT,PRelocs),RelocsSize);*)

	END ProcessRelocs;

	PROCEDURE ProcessImports(PImports: ImageImportDescriptor);
	TYPE
		Str = ARRAY 255 OF CHAR;
	VAR
		pImport: ImageImportDescriptor;
		ImportAdr,Import: LONGINT;
		PImportedName: Str;
		LibHandle: LONGINT;
		ProcAddress: LONGINT;
		PLibName: Str;
		ImportLoop: LONGINT;
		tmp,i:LONGINT;
		ch:CHAR;
		tmppr:Proc;
		PROCEDURE IsImportByOrdinal(ImportDescriptor: LONGINT; HLib: LONGINT): BOOLEAN;
		BEGIN
			RETURN BIT.LAND(ImportDescriptor,IMAGE_ORDINAL_FLAG32) # 0;
		END IsImportByOrdinal;

	BEGIN
		pImport := PImports;
		KernelLog.String("ProcessImports= "); KernelLog.Int(SYSTEM.VAL(LONGINT,pImport),0); KernelLog.Ln;
		WHILE pImport.Name#0 DO
			i:=0;
(*			KernelLog.Memory(SYSTEM.VAL(LONGINT,pImport.Name+NewLibInfo.ImageBase+i),32);*)
			REPEAT
				SYSTEM.GET(pImport.Name+NewLibInfo.ImageBase+i,ch);
				PLibName[i]:=ch;
				INC(i);
(*			KernelLog.Char(ch);*)
			UNTIL ch=0X;
			KernelLog.String("PLibName:"); KernelLog.String(PLibName);
			
			IF ~Find(NewLibInfo.LibsUsed, PLibName, ImportLoop) THEN
				LibHandle := Kernel32.LoadLibrary(PLibName);
				Add(NewLibInfo.LibsUsed, PLibName,LibHandle);
				KernelLog.String("=NEW ");  KernelLog.Ln;
			ELSE
				LibHandle := NewLibInfo.LibsUsed.items[ImportLoop].p;
				KernelLog.String("=LibHandle= "); KernelLog.Int(LibHandle, 0); KernelLog.Ln;
			END;
			
			IF pImport.TimeDateStamp = 0 THEN
				ImportAdr:=pImport.FirstThunk+NewLibInfo.ImageBase;
			ELSE
				ImportAdr:=pImport.OriginalFirstThunk+NewLibInfo.ImageBase;
			END;
			SYSTEM.GET(ImportAdr,Import);
			WHILE Import # 0 DO
(*				KernelLog.String("import= "); KernelLog.Int(Import, 0); KernelLog.Ln;*)
				IF IsImportByOrdinal(Import, LibHandle) THEN
					HALT(24);
(*TODO:					ProcAddress := Kernel32.GetProcAddress(LibHandle, BIT.LAND(Import,0FFFFH));*)
				ELSE
					i:=0;
					REPEAT
						SYSTEM.GET((Import + NewLibInfo.ImageBase + IMPORTED_NAME_OFFSET)+i,ch);
						PImportedName[i]:=ch;
						INC(i);
					UNTIL ch=0X;

					KernelLog.String("PImportedName= "); KernelLog.String(PImportedName); KernelLog.Ln;
					IF PLibName="TestDll" THEN 
						GetProcedure(PLibName,PImportedName,ProcAddress);
						KernelLog.String("===== "); KernelLog.Int(ProcAddress,0); KernelLog.Ln;
					ELSE
						Kernel32.GetProcAddress(LibHandle, PImportedName,ProcAddress);
					END;
(*					KernelLog.String("ProcAddress= "); KernelLog.Int(ProcAddress, 0); KernelLog.Ln;*)
				END;
				SYSTEM.PUT(ImportAdr,ProcAddress);
				ImportAdr:=ImportAdr+4;
				SYSTEM.GET(ImportAdr,Import)
			END;
			pImport:=SYSTEM.VAL(ImageImportDescriptor,SYSTEM.VAL(LONGINT,pImport)+014H);
		END;
	END ProcessImports;

BEGIN

(*	KernelLog.Ln;
	KernelLog.Memory(Src, 64);
	KernelLog.String("Src"); KernelLog.Int(Src, 0); KernelLog.Ln;
	SYSTEM.MOVE(SYSTEM.ADR(Src),SYSTEM.ADR(DosHead), 4);*)
	NEW(NewLibInfo);
	DosHead:=SYSTEM.VAL(PImageDosHeader,Src);
	tmp:=Src+ DosHead.lfanew;
	
	imageNtHeaders:=SYSTEM.VAL(PImageNtHeaders,tmp);
	
(*	KernelLog.String("imageNtHeaders.OptionalHeader.SizeOfImage= "); KernelLog.Int(imageNtHeaders.OptionalHeader.SizeOfImage, 0); *)
	

	
	Heaps.NewSys(imageBase, imageNtHeaders.OptionalHeader.SizeOfImage,FALSE); (*allocate new memory block for dll*)
	NewLibInfo.ImageBase := SYSTEM.VAL(LONGINT,imageBase);(*save imageBase adress*)
	Machine.Fill32(NewLibInfo.ImageBase, imageNtHeaders.OptionalHeader.SizeOfImage,0);(*clear memory*)

	imageBaseDelta:=NewLibInfo.ImageBase- imageNtHeaders.OptionalHeader.ImageBase;
	SYSTEM.MOVE(Src, NewLibInfo.ImageBase, imageNtHeaders.OptionalHeader.SizeOfHeaders);
	
	section := SYSTEM.VAL(PImageSectionHeader,SYSTEM.ADR(imageNtHeaders.OptionalHeader) + imageNtHeaders.FileHeader.SizeOfOptionalHeader);
(*	KernelLog.String("imageNtHeaders.FileHeader.NumberOfSections= "); KernelLog.Int(imageNtHeaders.FileHeader.NumberOfSections,0); KernelLog.Ln;*)
	FOR sectionLoop := 0 TO imageNtHeaders.FileHeader.NumberOfSections - 1 DO
		VirtualSectionSize := section.Misc;
(*		KernelLog.String("VirtualSectionSize ="); KernelLog.Int(VirtualSectionSize, 0); KernelLog.Ln;*)
		RawSectionSize := section.SizeOfRawData;
		IF VirtualSectionSize < RawSectionSize THEN
			VirtualSectionSize := BIT.LXOR(VirtualSectionSize,RawSectionSize);
			RawSectionSize := BIT.LXOR(VirtualSectionSize,RawSectionSize);
			VirtualSectionSize := BIT.LXOR(VirtualSectionSize,RawSectionSize);
		END;
		SectionBase :=SYSTEM.VAL(ANY, section.VirtualAddress + NewLibInfo.ImageBase);
		SYSTEM.MOVE(Src + section.PointerToRawData, SYSTEM.VAL(LONGINT,SectionBase), RawSectionSize);
		section:=SYSTEM.VAL(PImageSectionHeader,SYSTEM.VAL(LONGINT,section)+SYSTEM.SIZEOF(ImageSectionHeader));
	END;
	
	
	NewLibInfo.DllProc := SYSTEM.VAL(TDllEntryProc,imageNtHeaders.OptionalHeader.AddressOfEntryPoint + NewLibInfo.ImageBase);
	InitList(NewLibInfo.LibsUsed);
	InitList(NewLibInfo.Exports);
	
	IF imageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress # 0 THEN 
		ProcessRelocs(SYSTEM.VAL(ImageBaseRelocation,imageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress + NewLibInfo.ImageBase)); 
	END;
	IF imageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress # 0 THEN 
		ProcessImports(SYSTEM.VAL(ImageImportDescriptor,imageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress + NewLibInfo.ImageBase)); 
	END;
	IF imageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress#0 THEN 
		ProcessExports(SYSTEM.VAL(ImageExportDirectory,imageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress + NewLibInfo.ImageBase),imageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].Size);
	END;
	KernelLog.String("DllProc= "); KernelLog.Ln;
	KernelLog.Memory(SYSTEM.VAL(LONGINT,NewLibInfo.DllProc),32);
(*	RETURN NIL;
	Int3;*)
	
	IF NewLibInfo.DllProc(NewLibInfo.ImageBase,1, 0) THEN
		RETURN NewLibInfo
	ELSE
		RETURN NIL
	END
	
END xLoadLibrary;

PROCEDURE LoadLibrary*(name:ARRAY OF CHAR):TLibInfo;
TYPE Buf=POINTER TO ARRAY OF CHAR;
VAR
	f:Files.File;
	r: Files.Rider;
	buf:Buf;
BEGIN
	f := Files.Old (name);
	f.Set(r, 0);
	NEW(buf, f.Length());
	r.file.ReadBytes(r, buf^, 0, f.Length());
	 RETURN xLoadLibrary(SYSTEM.ADR(buf[0]));
END LoadLibrary;


PROCEDURE TestLoad*;
TYPE
 proc1= PROCEDURE(a,b:LONGINT);
VAR
	lib:TLibInfo;
	proc:Proc;
	tmp,adr:LONGINT;
BEGIN
	GetProcedure("KernelLog","Int",adr);
	KernelLog.String("di= "); 	KernelLog.Int(adr, 0); KernelLog.Ln;(*di= 4347951*)
	lib:=LoadLibrary("Testa2.dll");
	GetProcAddress(lib,"helloword2", adr);
	proc:=SYSTEM.VAL(Proc,adr);
	Int3;
	proc;
END TestLoad;
PROCEDURE Test*;
TYPE Buf=POINTER TO ARRAY OF CHAR;
VAR
	f:Files.File;
	r: Files.Rider;
	buf:Buf;
BEGIN
	f := Files.Old('Testa2.dll');
	f.Set(r, 0);
	NEW(buf, f.Length()*2);
	r.file.ReadBytes(r, buf^, 0, f.Length()*2);
END Test;

END DLL.TestLoad~
DLL.Test