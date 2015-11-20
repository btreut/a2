MODULE EFILib; (** AUTHOR "Matthias Frei"; PURPOSE "EFI API"; *)

IMPORT SYSTEM, EFI, EFIFileProtocol, EFISimpleFS, EFILoadedImage, Trace;

TYPE Allocation = RECORD
	baseAddress: EFI.PhysicalAddress;
	numPages: EFI.Int;
END;
TYPE PtrToLongString = POINTER TO ARRAY 1024 OF EFI.Char16; (* to be able to use system.val etc.*)

CONST
	maxAllocations = 128;
VAR
	(* memory allocation *)
	allocations : ARRAY maxAllocations OF Allocation;
	numAllocations : LONGINT;

	(* argument parsing *)
	args : PtrToLongString;
	argLen : LONGINT;
	argPos : LONGINT;

(* allocate memory pages. If addr = -1 (=FFFFFFFFFH) then a page at an arbitrary position will be allocated. *)
PROCEDURE AllocateMemory*(VAR addr : EFI.PhysicalAddress; numPages : EFI.Int) : EFI.Status;
VAR
	status : EFI.Status;
	allocationType : EFI.Int;
BEGIN
	IF numAllocations < maxAllocations-1 THEN
		IF addr = -1 THEN
			allocationType := EFI.AllocateAnyPage;
		ELSE
			allocationType := EFI.AllocateAddress;
		END;
		status := EFI.table.BS.AllocatePages(allocationType, EFI.MTLoaderData, numPages, addr);
		IF status = EFI.Success THEN
			allocations[numAllocations].baseAddress := addr;
			allocations[numAllocations].numPages := numPages;
			INC(numAllocations);
		ELSE
			addr := 0;
		END;
		RETURN status;
	ELSE
		RETURN EFI.Error;
	END;
END AllocateMemory;

(* free all pages allocated by AllocateMemory *)
PROCEDURE FreeMemory*;
VAR
	status : EFI.Status;
	i : LONGINT;
BEGIN
	FOR i := 0 TO numAllocations - 1 DO
		status := EFI.table.BS.FreePages(allocations[i].baseAddress, allocations[i].numPages);
	END;
END FreeMemory;


PROCEDURE GetMemoryMapping*(VAR adr: EFI.PhysicalAddress) : EFI.Status;
CONST
	approxMemMapSize = 2048; (* we actually can not resize the buffer. just hope its enough *)
VAR
	MemMapSize, MapKey, DescriptorSize: EFI.Int;  DescriptorVersion : EFI.Int32;
	status : EFI.Status;
	MemMap : ARRAY approxMemMapSize OF EFI.MemoryDescriptor;
	MemMapElement : EFI.MemoryDescriptorPointer;
	i, numEntries : EFI.Int;
	hi, numcritEntries : HUGEINT;
	memsize : HUGEINT;
	tmp : EFI.PhysicalAddress;
BEGIN
	MemMapSize := LEN(MemMap)*SIZEOF(EFI.MemoryDescriptor);
	status := EFI.table.BS.GetMemoryMap(MemMapSize, MemMap, MapKey, DescriptorSize, DescriptorVersion);
	IF status = EFI.ErrBufferTooSmall THEN
		(* we cant resize. We are doomed!*)
		RETURN status;
	END;

	adr := -1;
	TRACE(status);
	TRACE(adr);
	status :=AllocateMemory(adr, 10); (* a few additional pages *)
	(* now bootTablePhAddr contains the base address of the allocated pages *)
	TRACE(status);
	TRACE(adr);
	IF status # EFI.Success THEN
		RETURN status;
	END;
	TRACE(status);
	numcritEntries := 0;
	MemMapSize := LEN(MemMap)*SIZEOF(EFI.MemoryDescriptor);
	status := EFI.table.BS.GetMemoryMap(MemMapSize, MemMap, MapKey, DescriptorSize, DescriptorVersion);
	IF status = EFI.ErrBufferTooSmall THEN
		(* we cant resize. We are doomed!*)
		RETURN status;
	END;

	numEntries := MemMapSize DIV DescriptorSize; (*DIV SIZEOF(EFI.MemoryDescriptor); *)


	tmp := 0H;
	memsize := 0;
	FOR i := 0 TO numEntries-1 DO
		MemMapElement := SYSTEM.VAL(EFI.MemoryDescriptorPointer, ADDRESSOF(MemMap[0])+i*DescriptorSize);
(*		IF (MemMapElement.Type #  EFI.MTConventionalMemory *)
		IF ( (MemMapElement.Type = EFI.MTRuntimeServicesCode) OR ( MemMapElement.Type = EFI.MTRuntimeServicesData)
			OR (MemMapElement.Type = EFI.MTUnusableMemory) OR (MemMapElement.Type = EFI.MTACPIReclaimMemory)
			OR (MemMapElement.Type = EFI.MTACPIMemoryNVSM) OR (MemMapElement.Type = EFI.MTMemoryMappedIO)
			OR (MemMapElement.Type = EFI.MTMemoryMappedIOPortSpace) OR (MemMapElement.Type = EFI.MTPalCode)
			OR (MemMapElement.Type = EFI.MTLoaderCode) OR (MemMapElement.Type = EFI.MTLoaderData)
			OR (MemMapElement.Type = EFI.MTReserved)
			OR (MemMapElement.Type = EFI.MTBootServicesCode) OR (MemMapElement.Type = EFI.MTBootServicesData) (* this line shouldnt be - but it freezes if i touch that memory *)



			)THEN
(*			Trace.Ln;
			Trace.Address(MemMapElement.PhysicalStart);
			Trace.String(" - " );
			Trace.Address(MemMapElement.PhysicalStart+MemMapElement.NumberOfPages*LONG(EFI.PageSize));
			Trace.String(" X ");
			Trace.Address(MemMapElement.VirtualStart);
			Trace.String(" - " );
			Trace.Address(MemMapElement.VirtualStart+MemMapElement.NumberOfPages*LONG(EFI.PageSize));
			*)
			IF (tmp # MemMapElement.PhysicalStart) THEN
				SYSTEM.PUT(ADDRESS(adr+(numcritEntries*2+1+1)*8), MemMapElement.PhysicalStart);
				tmp := MemMapElement.PhysicalStart+MemMapElement.NumberOfPages*LONG(EFI.PageSize);
				SYSTEM.PUT(ADDRESS(adr+(numcritEntries*2+1+1+1)*8), tmp);
				numcritEntries := 	numcritEntries +1;
			ELSE
				numcritEntries := 	numcritEntries -1;
				tmp := MemMapElement.PhysicalStart+MemMapElement.NumberOfPages*LONG(EFI.PageSize);
				SYSTEM.PUT(ADDRESS(adr+(numcritEntries*2+1+1+1)*8), tmp);
				numcritEntries := 	numcritEntries +1;
			END;
		END;
		memsize := memsize + MemMapElement.NumberOfPages;
	END;

	FOR hi:= 0 TO numcritEntries-1 DO
		SYSTEM.GET(ADDRESS(adr+(hi*2+1+1)*8), tmp);
		TRACE(tmp);
		SYSTEM.GET(ADDRESS(adr+(hi*2+1+1+1)*8), tmp);
		TRACE(tmp);
	END;



	SYSTEM.PUT(ADDRESS(adr),numcritEntries);
	SYSTEM.PUT(ADDRESS(adr+8),memsize);
	TRACE(adr);
	RETURN EFI.Success;
END GetMemoryMapping;

(* find the size of the RAM by investigating the entries of the EFI Memory Map.  *)
PROCEDURE GetMemorySize*(VAR memsize : EFI.Int64 ) : EFI.Status;
CONST
	approxMemMapSize = 2048; (* we actually can not resize the buffer. just hope its enough *)
VAR
	MemMapSize, MapKey, DescriptorSize: EFI.Int;  DescriptorVersion : EFI.Int32;
	status : EFI.Status;
	MemMap : ARRAY approxMemMapSize OF EFI.MemoryDescriptor;
	MemMapElement : EFI.MemoryDescriptorPointer;
	i, numEntries : EFI.Int;
BEGIN
	MemMapSize := LEN(MemMap)*SIZEOF(EFI.MemoryDescriptor);
	status := EFI.table.BS.GetMemoryMap(MemMapSize, MemMap, MapKey, DescriptorSize, DescriptorVersion);
	IF status = EFI.ErrBufferTooSmall THEN
		(* we cant resize. We are doomed!*)
		RETURN status;
	END;

	numEntries := MemMapSize DIV DescriptorSize; (*DIV SIZEOF(EFI.MemoryDescriptor); *)
	memsize := 0;

	Trace.Ln();
	Trace.Address(MemMapSize);
	Trace.Ln();
	Trace.Address(SIZEOF(EFI.MemoryDescriptor));
	Trace.Ln();
	Trace.Address(36);
	Trace.Ln();
	Trace.Address(DescriptorSize);
	Trace.Ln();
	Trace.Address(DescriptorVersion);
	Trace.Ln();
	Trace.Ln();
	FOR i := 0 TO numEntries-1 DO
		MemMapElement := SYSTEM.VAL(EFI.MemoryDescriptorPointer, ADDRESSOF(MemMap[0])+i*DescriptorSize);
	(*
			MTLoaderCode* = 1;
	MTLoaderData* = 2;
	MTBootServicesCode* = 3;
	MTBootServicesData* = 4;
	MTRuntimeServicesCode* = 5;
	MTRuntimeServicesData* = 6;
	MTConventionalMemory*= 7;
	MTUnusableMemory* = 8;
	MTACPIReclaimMemorz* = 9;
	MTACPIMemoryNVSM* = 10;
	MTMemoryMappedIO* = 11;
	MTMemoryMappedIOPortSpace* = 12;
	MTPalCode* = 13;
	MTMaxMemoryType* = 14;
		*)
(*	IF (TRUE) THEN*)

		memsize := memsize + MemMapElement.NumberOfPages;
		(*IF (memsize < MemMap[i].PhysicalStart + MemMap[i].NumberOfPages*LONG(EFI.PageSize)) THEN
			memsize := MemMap[i].PhysicalStart + MemMap[i].NumberOfPages*LONG(EFI.PageSize);
		END;*)
	END;
	memsize := memsize * LONG(EFI.PageSize);
	Trace.Address(LONG(EFI.PageSize));
	Trace.Ln();
	Trace.Hex(memsize,8);
	Trace.Ln();
(*	memsize := SYSTEM.GET32(ADDRESSOF(memsize)+4); (* BUG! where ? *)*)

	RETURN EFI.Success;
END GetMemorySize;

(* stop bootservices. The idea is that we get the current memory map, s.t. the OS is aware of EFI allocated memory. We dont
care so we just throw it away *)
PROCEDURE ExitBootServices*(): EFI.Status;
CONST
	approxMemMapSize = 2048; (* we actually can not resize the buffer. just hope its enough *)
VAR
	MemMapSize, MapKey, DescriptorSize: EFI.Int; DescriptorVersion : EFI.Int32;
	status : EFI.Status;
	MemMap : ARRAY approxMemMapSize OF EFI.MemoryDescriptor;
BEGIN
	MemMapSize := LEN(MemMap)*SIZEOF(EFI.MemoryDescriptor);
	REPEAT
		status := EFI.table.BS.GetMemoryMap(MemMapSize, MemMap, MapKey, DescriptorSize, DescriptorVersion);
		IF status = EFI.ErrBufferTooSmall THEN
			(* we cant resize. We are doomed! *)
			RETURN status;
		END;
		status := EFI.table.BS.ExitBootServices(EFI.imageHandle, MapKey);
	UNTIL status = EFI.Success;

	(*
     EFI.table.ConsoleInHandle := 0H;
     EFI.table.ConIn:= NIL;
	EFI.table.ConsoleOutHandle:= 0H;
	EFI.table.ConOut:= NIL;
	EFI.table.StandardErrorHandle:= 0H;
	EFI.table.StdErr:= NIL;
	EFI.table.BS:= NIL;*)

	RETURN EFI.Success;
END ExitBootServices;

(* Get the arguments given to the image *)
PROCEDURE GetArgs*(VAR loadOptionsSize : LONGINT; VAR loadOptions : EFILoadedImage.PtrToArrayOfByte) : EFI.Status;
VAR
	prot : EFI.Protocol; loadedImage : EFILoadedImage.Protocol;
	status : EFI.Status;
BEGIN
	status := EFI.table.BS.HandleProtocol(EFI.imageHandle, EFILoadedImage.GUID, prot);
	IF status = EFI.Success THEN
		loadedImage := SYSTEM.VAL(EFILoadedImage.Protocol, prot);
		loadOptionsSize := loadedImage.LoadOptionsSize;
		loadOptions := loadedImage.LoadOptions;
	END;
	RETURN status;
END GetArgs;

(* (re-) initialize variables for GetNextArg. Automatically called by at the first call to GetNextArg. Can be used to reset GetNextArg.
Assumes that EFI-Shell passes commandline as a string in the form "imagename (arguments)*" like e.g. unix shells do. *)
PROCEDURE InitArgs*() : EFI.Status;
VAR
	prot : EFI.Protocol; loadedImage : EFILoadedImage.Protocol;
	status : EFI.Status;
	loadOptionsSize : LONGINT;
	loadOptions : EFILoadedImage.PtrToArrayOfByte;
BEGIN
	status := EFI.table.BS.HandleProtocol(EFI.imageHandle, EFILoadedImage.GUID, prot); (* not using GetArgs since we want access to other fields of the loadedImage-protocol *)
	IF status = EFI.Success THEN
		loadedImage := SYSTEM.VAL(EFILoadedImage.Protocol, prot);
		loadOptionsSize := loadedImage.LoadOptionsSize;
		loadOptions := loadedImage.LoadOptions;

		(* setup GetNextArg variables *)
		args:= SYSTEM.VAL(PtrToLongString, loadOptions);
		argLen := loadOptionsSize DIV 2; (* 16-bit characters *)
		argPos := 0;

		(* skip the 'imagename' by skipping the first word of the load options *)
		(* Do not skip if the image was not loaded directly by the firmware bootmanager.
		This should be useful to not have to type the name of the image as an argument when starting directly
		from the bootmanager while still being compatible to the EFI-Shell.
		ParentHandle should be NULL if the image was loaded by the firmware bootmanager. *)
		(* Apparently this does not work (at least it does not in qemu-EFI) although it should - therefore commented out
		IF (loadedImage.ParentHandle # 0) THEN *)

		WHILE (argPos < argLen) & (args[argPos] # 0) & (args[argPos] # ORD(' ')) DO
			INC(argPos);
		END;

		(*END; *)
	ELSE
		ReportError(status);
	END;
	RETURN status;
END InitArgs;

(* read one argument after another. Returns true iff successfully parsed.
Treats ' ' (blank) as seperator between arguments. (text between '"' is NOT merged into one argument.
 *)
PROCEDURE GetNextArg*(VAR arg : ARRAY OF EFI.Char16) : BOOLEAN;
VAR
	status : EFI.Status;
	i : LONGINT;
BEGIN
	IF args = NIL THEN
		status := InitArgs();
		IF (status # EFI.Success) THEN
			RETURN FALSE;
		END;
	END;

	(* skip whitspace *)
	WHILE (argPos < argLen) & (args[argPos] = ORD(' ')) DO INC(argPos); END;

	i := 0;
	WHILE (i < LEN(arg)) & (argPos < argLen) & (args[argPos] # 0) & (args[argPos] # ORD(' ')) DO
		arg[i] := args[argPos];
		INC(i); INC(argPos);
	END;

	RETURN (i > 0);
END GetNextArg;

(* read a string from simpleInputInterface *)
PROCEDURE ReadString*(VAR buf : ARRAY OF EFI.Char16);
CONST ScanCodeNull = 0; (* if ScanCode = 0 then UnicodeChar is valid. Else a special key was hit (e.g ESC, Fx,..) *)
	CharLF = 0AH;
	CharCR = 0DH;
VAR key : EFI.InputKey; i : LONGINT;
	status : EFI.Status;
	ConIn : POINTER TO EFI.SimpleInputInterface;
	ConOut : POINTER TO EFI.SimpleTextOutputInterface;
	newline, cursorEnabled : BOOLEAN;
	lastChar : ARRAY 2 OF EFI.Char16;
BEGIN
	ConIn := EFI.table.ConIn;
	ConOut := EFI.table.ConOut;
	lastChar[1] := 0;
	cursorEnabled := ConOut.Mode.CursorVisible;
	IF (~cursorEnabled) THEN
		status := ConOut.EnableCursor(ConOut, TRUE);
	END;
	status := ConIn.Reset(ConIn, FALSE);
	newline := FALSE; i := 0;
	WHILE (i < LEN(buf)-1) & (~newline) DO
		status := ConIn.ReadKey(ConIn, key);
		IF (status = EFI.Success) & (key.ScanCode = ScanCodeNull) THEN
			IF (key.UnicodeChar # CharLF) & (key.UnicodeChar # CharCR) THEN
				buf[i] := key.UnicodeChar;
				lastChar[0] := key.UnicodeChar;
			ELSE
				buf[i] := 0H;
				newline := TRUE;
				lastChar[0] := key.UnicodeChar;
			END;
			status := ConOut.OutputString(ConOut, lastChar);
			INC(i);
		END;
	END;
	buf[LEN(buf)-1] := 0H;
	IF (~cursorEnabled) THEN
		status := ConOut.EnableCursor(ConOut, FALSE);
	END;
END ReadString;

(* convert signed integer to a string *)
PROCEDURE IntToString* (CONST x : LONGINT; VAR s : ARRAY OF CHAR);
VAR i, x0, slen, start : LONGINT;
BEGIN
	IF x = MIN (LONGINT) THEN
		s := "-2147483648";
		RETURN;
	END;

	slen := LEN(s)-1;
	IF (slen > 11) THEN
		slen := 11;
	END;
	s[slen] := 0X;

	start := 0;
	IF (x < 0) & ( slen > 0 ) THEN
		x0 := -x;
		s[0] := '-'; start := 1;
	END;
	i := slen;
	WHILE ( i > start ) DO
		DEC(i);
		s[i] := CHR (x0 MOD 10 + 30H);
		x0 := x0 DIV 10;
	END;
END IntToString;

(* Copied from I386.Machine.Mod - StrToInt *)
(** Convert a string to an integer. Parameter i specifies where in the string scanning should begin (usually 0 in the first call). Scanning stops at the first non-valid character, and i returns the updated position. Parameter s is the string to be scanned. The value is returned as result, or 0 if not valid. Syntax: number = ["-"] digit {digit} ["H" | "h"] . digit = "0" | ... "9" | "A" .. "F" | "a" .. "f" . If the number contains any hexdecimal letter, or if it ends in "H" or "h", it is interpreted as hexadecimal. *)
PROCEDURE StringToInt* (VAR i: LONGINT; CONST s: ARRAY OF CHAR): LONGINT;
VAR vd, vh, sgn, d: LONGINT; hex: BOOLEAN;
BEGIN
	vd := 0; vh := 0; hex := FALSE;
	IF s[i] = "-" THEN sgn := -1; INC (i) ELSE sgn := 1 END;
	LOOP
		IF (s[i] >= "0") & (s[i] <= "9") THEN d := ORD (s[i])-ORD ("0")
		ELSIF (CAP (s[i]) >= "A") & (CAP (s[i]) <= "F") THEN d := ORD (CAP (s[i]))-ORD ("A") + 10; hex := TRUE
		ELSE EXIT
		END;
		vd := 10*vd + d; vh := 16*vh + d;
		INC (i)
	END;
	IF CAP (s[i]) = "H" THEN hex := TRUE; INC (i) END;	(* optional H *)
	IF hex THEN vd := vh END;
	RETURN sgn * vd
END StringToInt;

(* copy the String 'str' to the char16-String 'lstr'. If 'lstr' is shorter than 'str' the prefix fitting into 'lstr' is copied. *)
PROCEDURE StringToLongString*(CONST str : ARRAY OF CHAR; VAR lstr : ARRAY OF EFI.Char16);
VAR strlen, lstrlen,i : LONGINT;
BEGIN
	strlen := LEN(str);
	lstrlen := LEN(lstr);
	i := 0;
	WHILE (i < strlen) & (i < lstrlen) & (ORD(str[i]) # 0) DO
		lstr[i] := ORD(str[i]);
		INC(i);
	END;
	IF lstrlen > 0 THEN
		lstr[i] := 0;
	END;
END StringToLongString;

(* returns the protocol identified by 'guid'. If there are multiple handles that handle this protocol, one is chosen arbitrarily *)
PROCEDURE GetProtocol*(CONST guid : EFI.GUID; VAR prot : EFI.Protocol) : EFI.Status;
VAR
	handle : EFI.Handle;
	handleBuf : ARRAY 512 OF EFI.Handle; (* make it large enough, we cant resize easily *)
	handleBufSize, i : EFI.Int;
	status : EFI.Status;
BEGIN
	handleBufSize := LEN(handleBuf) * SIZEOF(EFI.Handle);
	status := EFI.table.BS.LocateHandle(EFI.ByProtocol, guid, 0, handleBufSize, handleBuf);
	IF (status = EFI.Success) & (handleBufSize > 0) THEN
		i := handleBufSize DIV SIZEOF(EFI.Handle);
		WHILE(i>0) DO
			DEC(i);
			handle := handleBuf[i];
			status := EFI.table.BS.HandleProtocol(handle, guid, prot);
			IF status = EFI.Success THEN RETURN EFI.Success; END;
		END;
		RETURN EFI.Error;
	END;
	RETURN status;
END GetProtocol;

PROCEDURE GetFileSize*(file : EFIFileProtocol.Protocol) : EFI.Int64;
VAR
	status : EFI.Status;
	infoBuf : EFIFileProtocol.FileInfo;
	infoBufSize : EFI.Int;
	fileSize : EFI.Int64;
BEGIN
	infoBufSize := SIZEOF(EFIFileProtocol.FileInfo);
	status := file.GetInfo(file, EFIFileProtocol.FileInfoGUID, infoBufSize, infoBuf);
	IF (status = EFI.Success) THEN
		fileSize := infoBuf.FileSize;
	END;
	RETURN fileSize;
END GetFileSize;

(* search 'fn' on all devices that handle the SimpleFS protocol (= FAT partitions) and open it read-write *)
PROCEDURE OpenFile*(CONST fn : ARRAY OF EFI.Char16) : EFIFileProtocol.Protocol;
VAR
	status : EFI.Status;
	handleBuf : ARRAY 128 OF EFI.Handle; (* make it large enough, we cant resize easily *)
	handleBufSize : EFI.Int;
	file : EFIFileProtocol.Protocol;
	done : BOOLEAN;
	iter : LONGINT;
BEGIN
	(* get all devices (or device drivers, handlers or what ever) that support the EFISimpleFS *)
	handleBufSize := LEN(handleBuf) * SIZEOF(EFI.Handle);
	status := EFI.table.BS.LocateHandle(EFI.ByProtocol, EFISimpleFS.GUID, 0, handleBufSize, handleBuf);
	IF (status = EFI.Success) & (handleBufSize > 0) THEN
		done := FALSE;
		iter := 0;
		(* look for the file on each device *)
		WHILE (iter < handleBufSize DIV SIZEOF(EFI.Handle)) & (~done) DO
			file := OpenFileOnDevice(fn, handleBuf[iter]);
			IF (file # NIL) THEN
				done := TRUE;
			END;
			INC(iter);
		END;
	ELSE
		file := NIL;
	END;
	RETURN file;
END OpenFile;

(* look for file 'fn' on device 'deviceHandle' and try to open it read-write. Returns NIL if not found *)
PROCEDURE OpenFileOnDevice(CONST fn : ARRAY OF EFI.Char16; deviceHandle : EFI.Handle)  : EFIFileProtocol.Protocol;
VAR
	root : EFIFileProtocol.Protocol;
	file : EFIFileProtocol.Protocol;
	protSimpleFS : EFISimpleFS.Protocol;
	prot : EFI.Protocol;
	status : EFI.Status;
BEGIN
	file := NIL;
	(* first get a SimpleFS-Protocol for handle *)
	status := EFI.table.BS.HandleProtocol(deviceHandle, EFISimpleFS.GUID, prot);
	protSimpleFS := SYSTEM.VAL(EFISimpleFS.Protocol,prot);
	IF (status = EFI.Success) & (protSimpleFS # NIL) THEN
		(* get a File-descriptor thingy for the root directory *)
		status := protSimpleFS.OpenVolume(protSimpleFS, root);
		IF (status = EFI.Success) THEN
			status := root.Open(root, file, fn, EFIFileProtocol.ModeRead, 0);
			IF (status # EFI.Success) THEN
				file := NIL;
			END;
		END;
	END;
	RETURN file;
END OpenFileOnDevice;

(* allocate memory and copy the content of the file to memory. If loadAddr = -1 an arbitrary memory page will be allocated *)
PROCEDURE LoadFile*(file : EFIFileProtocol.Protocol; VAR loadAddr : ADDRESS) : EFI.Status;
VAR
	status : EFI.Status;
	fileSize : EFI.Int64;
	numPages : EFI.Int;
	addr : EFI.PhysicalAddress;
	memSize : EFI.Int;
BEGIN
	fileSize :=  GetFileSize(file);
	numPages := SHORT(fileSize DIV EFI.PageSize) + 1;

	addr := loadAddr;
	status := AllocateMemory(addr, numPages);
	(* now addr contains the base address of the allocated pages *)
	IF status = EFI.Success THEN
		loadAddr := SYSTEM.VAL(ADDRESS, addr);
		memSize := SYSTEM.VAL(EFI.Int, fileSize);
		status := file.Read(file, memSize, loadAddr);
	END;
	RETURN status;
END LoadFile;

(* Reports a description of the error code *)
PROCEDURE ReportError*(status : EFI.Status);
BEGIN
(*
	CASE status OF
		|EFI.Success : Trace.String("Success");
		(* Warnings *)
		| EFI.WarnUnknownGlyph : Trace.String("Warning : Unknown Glyph");
		| EFI.WarnDeleteFailure : Trace.String("Warning : Delete Failure");
		| EFI.WarnWriteFailure : Trace.String("Warning : Write Failure");
		| EFI.WarnBufferTooSmall : Trace.String("Warning : Buffer Too Small");
		(* Errors*)
		| EFI.ErrLoadError : Trace.String("Error : Load Error");
		| EFI.ErrInvalidParameter : Trace.String("Error : Invalid Parameter");
		| EFI.ErrUnsupported : Trace.String("Error : Unsupported");
		| EFI.ErrBadBufferSize : Trace.String("Error : Bad Buffer Size");
		| EFI.ErrBufferTooSmall : Trace.String("Error : Buffer Too Small");
		(* ... TODO ... *)
		| EFI.ErrNotFound :  Trace.String("Error : Not Found");
		(* ... TODO ... *)
		| EFI.ErrEndOfFile : Trace.String("Error : End Of File");
		| EFI.ErrInvalidLanguage : Trace.String("Error : Invalid Language");
	END;
	*)
	Trace.String("Error Code: "); Trace.Int(LONGINT(status - EFI.Error), 0);
	Trace.Ln;
END ReportError;

BEGIN
	numAllocations := 0;
	args := NIL;
END EFILib.