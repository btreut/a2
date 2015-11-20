MODULE EFIA2Loader; (** AUTHOR "Matthias Frei"; PURPOSE "EFI A2 Boot Loader"; *)

IMPORT
	SYSTEM, EFI, Machine := EFIMachine, EFILib, EFIFileProtocol, EFIGraphicsOutput, Trace;

CONST
	traceDebug = TRUE;

	(* address to which the executable will be loaded to. Loaded to arbitrary address if  = -1 *)
	kernelAddress = 1000H;
	(* address to which the executable relocates itself. Ignored if -1 *)
(*	kernelRelocAddress = 01000000H;*)
	kernelRelocAddress = -1;
	(* address at which the boot table is generated. Arbitrary if -1 *)
	bootTableAddress = -1;

VAR
	bootTableBegin : ADDRESS; (* address at which boot table is really located. Can be equal to bootTableAddress *)
	bootTableEnd : ADDRESS; (* bootTableBegin + current size of bootTable - sizeof sentinel (=5) + 1. *)
	bootTableCfgStrEntry : ADDRESS; (* address of the config string entry (type 8) of the boot table *)

	(* search a mode that with the preferred horizontal and vertical resolution. Returns the corresponding mode
	number or -1 if no such mode is found or if an error occurs *)
	PROCEDURE SearchGraphicsMode(prot : EFIGraphicsOutput.Protocol; prefWidth, prefHeight, prefDepth, prefFormat : LONGINT): LONGINT;
	VAR
		mode : EFIGraphicsOutput.GraphicsMode;
		info : EFIGraphicsOutput.GraphicsModeInfo;
		sizeofInfo : EFI.Int;
		maxMode : EFI.Int32;
		i : LONGINT;
		status : EFI.Status;
	BEGIN
		(* the currently set mode stores the number of available modes. Valid mode numbers are 0 to maxMode-1 *)
		mode := prot.Mode;
		maxMode := mode.MaxMode;

		(* enumerate all modes *)
		FOR i := 0 TO maxMode-1 DO
			(* get info about mode i *)
			status := prot.QueryMode(prot, i, sizeofInfo, info); (* ignore sizeofInfo. Just some compatibility stuff *)
			IF (status # EFI.Success) THEN
				RETURN -1;
			END;
			(* now check whether this is the mode we are looking for *)
(*			IF (prefWidth = info.HorizontalResolution) & (prefHeight = info.VerticalResolution)
					& (prefFormat = info.PixelFormat) & (prefDepth = 32) THEN (* all pixel formats are 32 bit *) *)
			IF (prefWidth = info.HorizontalResolution) & (prefHeight = info.VerticalResolution)
					& (prefDepth = 32) THEN (* all pixel formats are 32 bit *) 					
					
				RETURN i;
			END;
		END;
		RETURN -1;
	END SearchGraphicsMode;

	PROCEDURE GetFrameBuffer(prefWidth, prefHeight, prefDepth, prefFormat : LONGINT; VAR framebufAddr : ADDRESS; VAR framebufSize : SIZE): EFI.Status;
	VAR
		handle : EFI.Handle;
		handleBuf : ARRAY 128 OF EFI.Handle;
		handleBufSize, i : EFI.Int;
		prot : EFI.Protocol; goProt : EFIGraphicsOutput.Protocol;
		modeNumber : LONGINT;
		framebufPhysAddr : EFI.PhysicalAddress;
		status : EFI.Status;
	BEGIN
		handleBufSize := LEN(handleBuf)*SIZEOF(EFI.Handle);
		status := EFI.table.BS.LocateHandle(EFI.ByProtocol, EFIGraphicsOutput.GUID, 0, handleBufSize, handleBuf);
		IF status = EFI.Success THEN
			i := handleBufSize DIV SIZEOF(EFI.Handle); (* probably either 0 or 1. *)
			WHILE i > 0 DO
				DEC(i);
				handle := handleBuf[i];
				status := EFI.table.BS.HandleProtocol(handle, EFIGraphicsOutput.GUID, prot);
				goProt := SYSTEM.VAL(EFIGraphicsOutput.Protocol, prot);
				IF status = EFI.Success THEN
					modeNumber := SearchGraphicsMode(goProt, prefWidth, prefHeight, prefDepth, prefFormat);
					IF modeNumber >= 0 THEN
						status := goProt.SetMode(goProt, modeNumber);
						IF (status = EFI.Success) & (goProt.Mode.Mode = modeNumber) THEN
							framebufPhysAddr := goProt.Mode.FrameBufferBase;
							framebufAddr := SYSTEM.VAL(ADDRESS, framebufPhysAddr);
							framebufSize := goProt.Mode.FrameBufferSize;
							RETURN EFI.Success;
						END;
					END;
				END;
			END;
		END;
		RETURN EFI.Error;
	END GetFrameBuffer;

	(* Prints all available graphics modes where PixelFormat # BltOnly *)
	PROCEDURE PrintGraphicsModes;
	VAR
		handle : EFI.Handle;
		handleBuf : ARRAY 512 OF EFI.Handle;
		handleBufSize, i: EFI.Int;  j : LONGINT;
		prot : EFI.Protocol; goProt : EFIGraphicsOutput.Protocol;
		mode : EFIGraphicsOutput.GraphicsMode;
		info : EFIGraphicsOutput.GraphicsModeInfo;
		sizeofInfo : EFI.Int;
		maxMode : EFI.Int32;
		status : EFI.Status;

	BEGIN
		handleBufSize := LEN(handleBuf)*SIZEOF(EFI.Handle);
		status := EFI.table.BS.LocateHandle(EFI.ByProtocol, EFIGraphicsOutput.GUID, 0, handleBufSize, handleBuf);
		IF status = EFI.Success THEN
			i := handleBufSize DIV SIZEOF(EFI.Handle); (* probably either 0 or 1. *)
			IF (i = 0) THEN
				Trace.String(" - none - "); Trace.Ln;
			END;
			WHILE i > 0 DO
				DEC(i);
				handle := handleBuf[i];
				status := EFI.table.BS.HandleProtocol(handle, EFIGraphicsOutput.GUID, prot);
				goProt := SYSTEM.VAL(EFIGraphicsOutput.Protocol, prot);
				IF status = EFI.Success THEN
					(* the currently set mode stores the number of available modes. Valid mode numbers are 0 to maxMode-1 *)
					mode := goProt.Mode;
					maxMode := mode.MaxMode;

					(* enumerate all modes *)
					FOR j := 0 TO maxMode-1 DO
						(* get info about mode j *)
						status := goProt.QueryMode(goProt, j, sizeofInfo, info); (* ignore sizeofInfo. Just some compatibility stuff *)
						IF (status # EFI.Success) THEN
							RETURN;
						END;
						Trace.Int(info.HorizontalResolution, 0); Trace.String("x");
						Trace.Int(info.VerticalResolution, 0); Trace.String("x");
						Trace.Int(32, 0); Trace.String(" - ");
						CASE info.PixelFormat OF
							EFIGraphicsOutput.PFRGBX8Bit : Trace.String("RGB");
							| EFIGraphicsOutput.PFBGRX8Bit : Trace.String("BGR");
							| EFIGraphicsOutput.PFBitMask : Trace.String("R: "); Trace.Hex(info.PixelBitmask.RedMask,8);
								Trace.String("G: "); Trace.Hex(info.PixelBitmask.GreenMask,8);
								Trace.String("B: "); Trace.Hex(info.PixelBitmask.BlueMask,8);
							| EFIGraphicsOutput.PFBltOnly : Trace.String("Blocktransfer only - no physical framebuffer");
						END;
						Trace.Ln;
					END;
				END;
			END;
		ELSE
			Trace.String("Error while accessing GraphicsOutputProtocol.");Trace.Ln;
			EFILib.ReportError(status);
		END;
	END PrintGraphicsModes;

	(* Loads the configuration file and creates the corresponding boot-table. *)
	PROCEDURE LoadBootTable(CONST configFileName : ARRAY OF EFI.Char16; VAR btAddr : ADDRESS) : EFI.Status;
	VAR
		configFile : EFIFileProtocol.Protocol;
		cfAddr, cfPos, cfEnd : ADDRESS;
		btAddrPhys : EFI.PhysicalAddress;
		btPos : ADDRESS;
		status : EFI.Status;

		type : LONGINT;
		fileSize : LONGINT;

		cfgname, cfgval : ADDRESS;
		cfgnamelen, cfgvallen : LONGINT;

		parseError : BOOLEAN;

		ramSize : EFI.Int64;

		PROCEDURE ReportError(at : ADDRESS);
		VAR status : EFI.Status;
		BEGIN
			parseError := TRUE;
			Trace.String("Sytnax error in file ");
			status := EFI.table.ConOut.OutputString(EFI.table.ConOut, configFileName); (* configFileName is a Unicode string *)
			Trace.String(" at position ");
			Trace.Address(at);
			Trace.Ln;
		END ReportError;

		PROCEDURE IsWhitespace(ch : CHAR) : BOOLEAN;
		BEGIN
			RETURN (ch = ' ') OR (ch = 09X) OR (ch = 0AX); (* space, tab or newline *)
		END IsWhitespace;

		(* searches the next configuration entry in the config file and returns the positions and lengths of its name and value *)
		PROCEDURE ReadConfig (VAR name : ADDRESS; VAR namelen : LONGINT; VAR val : ADDRESS; VAR vallen : LONGINT) : BOOLEAN;
		VAR ch : CHAR;
		BEGIN
			(* skip whitespace *)
			IF (cfPos # cfEnd) THEN SYSTEM.GET(cfPos, ch); INC(cfPos); END;
			WHILE (cfPos # cfEnd) & IsWhitespace(ch) DO
				SYSTEM.GET(cfPos, ch); INC(cfPos);
			END;

			IF (ch = '~') THEN RETURN FALSE; END;

			name := cfPos-1;
			namelen := 0;
			(* skip name *)
			WHILE (cfPos # cfEnd) & (ch # '=') & ~IsWhitespace(ch)  DO
				INC(namelen);
				SYSTEM.GET(cfPos, ch); INC(cfPos);
			END;

			(* skip whitespace before = *)
			WHILE (cfPos # cfEnd) & IsWhitespace(ch) DO
				SYSTEM.GET(cfPos, ch); INC(cfPos);
			END;
			IF (ch # '=') THEN ReportError(cfPos - cfAddr); RETURN FALSE; END;
			IF (cfPos # cfEnd) THEN SYSTEM.GET(cfPos, ch); INC(cfPos); END;

			(* skip whitespace after = *)
			WHILE (cfPos # cfEnd) & IsWhitespace(ch) DO
				SYSTEM.GET(cfPos, ch); INC(cfPos);
			END;
			IF (ch # '"') THEN ReportError(cfPos - cfAddr); RETURN FALSE; END;
			IF (cfPos # cfEnd) THEN SYSTEM.GET(cfPos, ch); INC(cfPos); END;

			val := cfPos-1;
			vallen := 0;
			(* skip val *)
			WHILE (cfPos # cfEnd) & (ch # '"') DO
				INC(vallen);
				SYSTEM.GET(cfPos, ch); INC(cfPos);
			END;
			IF (ch # '"') THEN ReportError(cfPos - cfAddr); RETURN FALSE; END;

			IF  (name = cfEnd) OR (val = cfEnd) THEN
				RETURN FALSE;
			END;
			RETURN TRUE;
		END ReadConfig;

	BEGIN
		(* open and load the configuration file *)
		configFile := EFILib.OpenFile(configFileName);
		IF (configFile = NIL) THEN
			Trace.String("Error: Could not find file ");
			status := EFI.table.ConOut.OutputString(EFI.table.ConOut, configFileName);
			Trace.Ln;
			RETURN EFI.ErrNotFound;
		END;
		cfAddr := -1; (* don't care *)
		status := EFILib.LoadFile(configFile, cfAddr);
		IF (status # EFI.Success) THEN
			RETURN status;
		END;
		fileSize := SHORT(EFILib.GetFileSize(configFile));
		cfPos := cfAddr;
		cfEnd := cfAddr + fileSize;

		(* allocate memory for the boot table *)
		btAddrPhys := bootTableAddress;
		status := EFILib.AllocateMemory(btAddrPhys, SHORT(fileSize DIV EFI.PageSize) + 3); (* a few additional pages *)
		(* now bootTablePhAddr contains the base address of the allocated pages *)
		IF status # EFI.Success THEN
			RETURN status;
		END;
		bootTableBegin := SYSTEM.VAL(ADDRESS,btAddrPhys);
		btAddr := bootTableBegin; (* out *)
		btPos := bootTableBegin;

		(* boot memory/top of low memory. Trying to stay compatible with OBL.Asm *)
		type := 3;
		SYSTEM.PUT32(btPos, type); INC(btPos, 4);
		SYSTEM.PUT32(btPos, 16); INC(btPos, 4); (* entry size *)
		SYSTEM.PUT32(btPos, 0); INC(btPos, 4); (* boot memory address (?) *)
		SYSTEM.PUT32(btPos, 640*1024); INC(btPos, 4); (* boot memory size (in bytes) *)

		(* free memory/extended memory size *)
		status := EFILib.GetMemorySize(ramSize);
		type := 4;
		SYSTEM.PUT32(btPos, type); INC(btPos, 4);
		SYSTEM.PUT32(btPos, 16); INC(btPos, 4); (* entry size *)
		SYSTEM.PUT32(btPos, 100000H); INC(btPos, 4); (* extended memory address *)
		SYSTEM.PUT32(btPos, SHORT(ramSize) - 100000H); INC(btPos, 4); (* extended memory size *)
		IF traceDebug THEN
			Trace.String("DEBUG: ramsize: "); Trace.Hex(SHORT(ramSize), 0); Trace.String("H B"); Trace.Ln;
		END;

		(* config strings; Parse the configuration file and copy the content to the boot table *)
		type := 8;
		(* write a config string entry 'header'. *)
		bootTableCfgStrEntry := btPos;
		SYSTEM.PUT32(btPos, type); INC(btPos, 4);
		SYSTEM.PUT32(btPos, 0); INC(btPos, 4); (* reserve space for the size field *)

		bootTableEnd := btPos;
		(* write trailer - will be overwritten by addconfig *)
		SYSTEM.PUT8(btPos, 0); INC(btPos);
		SYSTEM.PUT32(btPos, -1); INC(btPos, 4);

		parseError := FALSE;
		WHILE (ReadConfig(cfgname, cfgnamelen, cfgval, cfgvallen))  DO
			AddConfigA(cfgname, cfgnamelen, cfgval, cfgvallen);
		END;

		IF (parseError) THEN
			RETURN EFI.Error;
		ELSE
			RETURN EFI.Success;
		END;
	END LoadBootTable;

	PROCEDURE AddConfig(CONST name, val : ARRAY OF CHAR);
	VAR strlenName, strlenVal : LONGINT;
	BEGIN
		strlenName:=0; WHILE (name[strlenName] # 0X) & (strlenName < LEN(name)) DO INC(strlenName); END;
		strlenVal:=0; WHILE (val[strlenVal] # 0X) & (strlenVal < LEN(val)) DO INC(strlenVal); END;

		AddConfigA(ADDRESSOF(name[0]), strlenName, ADDRESSOF(val[0]), strlenVal);
	END AddConfig;

	(* add a config string entry to the boot table. The table always ends with a termination symbol which is overwritten
	if another entry is added. The lengths must not include a terminating 0. *)
	PROCEDURE AddConfigA(name : ADDRESS; namelen : LONGINT; val : ADDRESS; vallen : LONGINT);
	VAR btEnd : ADDRESS;
	cfgStrSize : SIZE;
	BEGIN
		btEnd := bootTableEnd;
		SYSTEM.MOVE(name,btEnd,namelen);
		INC(btEnd,namelen);
		SYSTEM.PUT(btEnd, 0); INC(btEnd); (*separator *)
		SYSTEM.MOVE(val,btEnd,vallen);
		INC(btEnd,vallen);
		SYSTEM.PUT(btEnd, 0); INC(btEnd); (*separator *)

		INC(bootTableEnd, namelen + 1 + vallen + 1);

		SYSTEM.PUT(btEnd, 0); INC(btEnd); (* marks the end of the config string entry *)
		SYSTEM.PUT32(btEnd, -1); (* marks the end of the table *)
		(* do not increment bootTableEnd here again. the 0 and the -1 will be overwritten if another entry is added *)

		cfgStrSize := bootTableEnd + 1 - bootTableCfgStrEntry; (* size including the 0 byte of the trailer *)
		SYSTEM.PUT32(bootTableCfgStrEntry + 4, cfgStrSize);
	END AddConfigA;

	(* search in the config string entries of the boot table (NOT in the config file) for the configuration with name 'name' *)
	PROCEDURE GetConfig(CONST name : ARRAY OF CHAR; VAR val : ARRAY OF CHAR);
	VAR btIdx : ADDRESS; i : LONGINT; ch : CHAR;
	BEGIN
		btIdx := bootTableCfgStrEntry + 8; (* skip type and size fields *)
		(* copied from I386.Machine.Mod - GetConfig *)
		LOOP
			SYSTEM.GET(btIdx,ch);
			IF ch = 0X THEN EXIT END;
			i := 0;
			LOOP
				SYSTEM.GET(btIdx,ch);
				IF (ch # name[i]) OR (name[i] = 0X) THEN EXIT END;
				INC (i); INC (btIdx)
			END;
			IF (ch = 0X) & (name[i] = 0X) THEN	(* found: (src^ = 0X) & (name[i] = 0X) *)
				i := 0;
				REPEAT
					INC (btIdx); SYSTEM.GET(btIdx,ch); val[i] := ch; INC (i);
					IF i = LEN(val) THEN val[i - 1] := 0X; RETURN END	(* val too short *)
				UNTIL ch = 0X;
				val[i] := 0X; RETURN
			ELSE
				WHILE ch # 0X DO	(* skip to end of name *)
					INC (btIdx); SYSTEM.GET(btIdx,ch);
				END;
				INC (btIdx);
				REPEAT	(* skip to end of value *)
					SYSTEM.GET(btIdx,ch); INC (btIdx)
				UNTIL ch = 0X
			END
		END;
		val[0] := 0X
	END GetConfig;

	PROCEDURE Allocate(allocAddr: EFI.PhysicalAddress; kernelPages: LONGINT): EFI.Status;
	VAR allocAdrCopy : EFI.PhysicalAddress; chunkPages: LONGINT; status: EFI.Status;
	BEGIN
		chunkPages := kernelPages;
		chunkPages := 1;
		REPEAT
			allocAdrCopy := allocAddr; (* to protect allocAddr from being overwritten in AllocateMemory *)
			status := EFILib.AllocateMemory(allocAdrCopy, chunkPages);
			IF status = EFI.Success THEN
				DEC(kernelPages, chunkPages);
				allocAddr := allocAddr + EFI.PageSize*chunkPages;
			ELSE
				TRACE(kernelPages, chunkPages, allocAddr, status);
				chunkPages := chunkPages DIV 2;
				IF chunkPages > kernelPages THEN chunkPages := kernelPages END;
			END;
		UNTIL (kernelPages = 0) OR (chunkPages = 0);
		RETURN status;
	END Allocate;

	(* 	loads the kernel image to kernelAddress if possible. Otherwise loads it to somewhere else and return WarnWriteFailure.
		Allocates makes sure the memory at kernelRelocAddress is allocated (by us or by someone else) s.t.
		the boot table will certainly not be allocated there.
	*)
	PROCEDURE LoadKernel(CONST kernelFileName : ARRAY OF EFI.Char16; VAR kernelAddr: ADDRESS; VAR kernelSize : LONGINT) : EFI.Status;
	VAR
		loadAddr : ADDRESS;
		allocAddr : EFI.PhysicalAddress;
		kernelImageFile : EFIFileProtocol.Protocol;
		kernelPages : LONGINT;
		i : LONGINT;
		status : EFI.Status;
	BEGIN
		kernelImageFile := EFILib.OpenFile(kernelFileName);
		IF (kernelImageFile # NIL) THEN
			kernelSize := SHORT(EFILib.GetFileSize(kernelImageFile));
			TRACE(kernelSize);
			kernelPages := (kernelSize DIV EFI.PageSize) + 1;

			(* allocate all memory at kernelRelocAddress *)
			IF (kernelRelocAddress # -1) THEN
				(*status := Allocate(kernelRelocAddress, kernelPages);*)
				TRACE(status);
				(*
				allocAddr := kernelRelocAddress;
				status := EFILib.AllocateMemory(allocAddr, kernelPages);
				TRACE(status);
				(* try to make sure all pages are allocated somehow *)
				IF (status # EFI.Success) THEN
					FOR i := 0 TO kernelPages DO
						status := EFI.Success;
						status := EFILib.AllocateMemory(allocAddr, 1);
						TRACE(status, allocAddr);
						allocAddr := allocAddr + EFI.PageSize;
					END;
				END;
				*)
			END;

			loadAddr := kernelRelocAddress;
			(*loadAddr := 400000H; *)

			allocAddr:= 0;  (*we use the variable to reserve page 0 and 1 *)
			status := EFILib.AllocateMemory(allocAddr, 2); (* allocate page 0 and 1 to be sure the kernel is not put there *)
			IF status # EFI.Success THEN
				Trace.String("could not allocate page 0 and 1 - this might be a problem for the relocation process");
			END;
			loadAddr := -1;  (*we let EFI decide where to put it *)

			status := EFILib.LoadFile(kernelImageFile, loadAddr);
			IF (status = EFI.Success ) THEN
				TRACE(loadAddr);
				kernelAddr := loadAddr;
				TRACE(kernelAddress);
				RETURN EFI.Success;
			ELSE
				TRACE("could not load kernel with fixed adr");
				(* try to recover: load it anywhere and relocate it later. make sure all pages at kernelAddress are allocated *)
				(*status := Allocate(kernelAddress, kernelPages);*)
				TRACE(status);
				(*
				allocAddr := kernelAddress;
				FOR i := 0 TO kernelPages DO
					status := EFI.Success;
					status := EFILib.AllocateMemory(allocAddr, 1);
					TRACE(status, allocAddr);
					allocAddr := allocAddr + EFI.PageSize;
				END;
				*)

				loadAddr := -1;
				status := EFILib.LoadFile(kernelImageFile, loadAddr);
				TRACE(status);
				IF (status = EFI.Success) THEN
					TRACE("loaded kernel to ", loadAddr);
					kernelAddr := loadAddr;
					TRACE(kernelAddress);
					RETURN EFI.WarnWriteFailure;
				ELSE
					RETURN EFI.Error;
				END;
			END;
		ELSE
			Trace.String("Error: Could not find file ");
			status := EFI.table.ConOut.OutputString(EFI.table.ConOut, kernelFileName);
			Trace.Ln;
			RETURN EFI.ErrNotFound;
		END;
	END LoadKernel;

	PROCEDURE LoadA2;
	VAR
		kernelAddr, btAddr, fbAddr, highAddr, memmapAddr: ADDRESS;
		fbSize: EFI.Int;
		adr: EFI.PhysicalAddress;
		kernelSize: LONGINT;
		kernelStat, btStat, fbStat, status, memmapStat : EFI.Status;
		kernelFileName, configFileName, arg : ARRAY 128 OF EFI.Char16;
		val : ARRAY 100 OF CHAR;
		i, dWidth, dHeight, dDepth, dFormat : LONGINT;
		size: EFI.Int64;
		buf : ARRAY 100 OF EFI.Char16;
	BEGIN
		Trace.String("Starting"); Trace.Ln;

		status := EFILib.GetMemorySize(size);
		TRACE(size);

		IF EFILib.GetNextArg(kernelFileName) & EFILib.GetNextArg(configFileName) THEN
			(* load the kernel file into memory *)
			kernelStat := LoadKernel(kernelFileName, kernelAddr, kernelSize);
			(* parse the configuration file and generate the boot table *)
			btStat := LoadBootTable(configFileName, btAddr);

			IF (btStat = EFI.Success) THEN
				(* get the configurations for the framebuffer and get the address of the corresponding framebuffer *)
				GetConfig("DWidth",val); i:=0; dWidth := EFILib.StringToInt(i, val);
				GetConfig("DHeight",val); i:=0; dHeight := EFILib.StringToInt(i, val);
				GetConfig("DDepth",val); i:=0; dDepth := EFILib.StringToInt(i, val);
				dFormat := EFIGraphicsOutput.PFBGRX8Bit;  (* Displays.Mod uses BGR *)

				fbStat := GetFrameBuffer(dWidth,dHeight,dDepth, dFormat, fbAddr, fbSize);
				TRACE(fbAddr);

				IF (fbStat = EFI.Success) THEN
					(* Does not work because IntToString does not function properly for large numbers.
					GetConfig("DMem", val);
					IF (val = "") THEN
						Trace.String("DEBUG: fbSize:"); Trace.Int(fbSize, 0); Trace.Ln;
						EFILib.IntToString(fbSize, val);
						AddConfig("DMem", val);
					ELSE
						i:= 0;
						IF (fbSize # EFILib.StringToInt(i, val)) THEN
							Trace.String("Warning: Configurated framebuffer size DMem = ");
							Trace.String(val);
							Trace.String(" does not match actual framebuffer size of ");
							Trace.Int(fbSize, 0);
							Trace.String("."); Trace.Ln;
						END;
					END;

					*)
				ELSE
					Trace.String("Warning: Requested display mode ");
					Trace.Int(dWidth,0); Trace.String("x"); Trace.Int(dHeight,0); Trace.String("x"); Trace.Int(dDepth,0);
					Trace.String(" not available in BGR mode. Available modes are :"); Trace.Ln;
					PrintGraphicsModes; Trace.Ln;
					Trace.String("Continuing happily."); Trace.Ln;
				END;
			END;
			IF traceDebug THEN
				Trace.String("DEBUG: Kernel at ");Trace.Address(kernelAddr);Trace.Ln;
				Trace.String("DEBUG: BootTable at ");Trace.Address(btAddr);Trace.Ln;
				Trace.String("DEBUG: FrameBuffer at "); Trace.Address(fbAddr); Trace.Ln;				
				(*
				Trace.String("DEBUG: boot table:"); Trace.Ln; Trace.Memory(bootTableBegin, bootTableEnd-bootTableBegin + 5);
				*)
			END;

			IF (EFILib.GetNextArg(arg) & (CHR(arg[0]) = '-') & (CHR(arg[1]) = 'd')) THEN
				Trace.Ln;
				Trace.String("Dry Run Complete"); Trace.Ln;
				RETURN;
			END;

			(*
			Trace.Memory(kernelAddress, 100);
			*)
			
			memmapStat := EFILib.GetMemoryMapping(adr);
			memmapAddr := SYSTEM.VAL(ADDRESS,adr);
			TRACE(memmapAddr);
			IF (memmapStat = EFI.Success ) THEN
				Trace.Ln;
				Trace.String("saved memory mappings");
			ELSE
				Trace.Ln;
				Trace.String("failed to saved memory mappings");			
			END;


			IF ((kernelStat = EFI.Success) OR (kernelStat = EFI.WarnWriteFailure)) & (btStat = EFI.Success) THEN
				TRACE(kernelAddr, btAddr, kernelSize, fbAddr);

				Trace.String("Shutting down Boot Services - WTF?!"); Trace.Ln;
				status := EFILib.ExitBootServices();
(*				status := EFI.Success;*)
				IF status = EFI.Success THEN
					(* sshhhhhht!!!  nomore EFITrace from here on *)

					Machine.JumpTo(kernelAddr, btAddr, kernelSize, fbAddr, memmapAddr);					
					(*
					SYSTEM.MOVE(kernelAddr, kernelAddress, kernelSize);
					
					
					
					kernelAddr := kernelAddress;
					IF (kernelStat = EFI.WarnWriteFailure) THEN
						(* couldn't allocate suitable memory portion before. Relocate it to the correct load address, EFI is not running anymore! *)

					END;
					Machine.JumpTo(kernelAddr, btAddr, 0, fbAddr);*)
				ELSE
					Trace.String("Could not exit boot services"); Trace.Ln;
				END;
			ELSE
				Trace.String("Error! ");
				IF ~((kernelStat = EFI.Success) OR (kernelStat = EFI.WarnWriteFailure)) THEN
					Trace.String("Kernel could not be loaded. ");
				END;
				IF ~(btStat = EFI.Success) THEN
					Trace.String("Boot table could not be loaded. ");
				END;
				Trace.String("Aborting"); Trace.Ln;
			END;
		ELSE
			Trace.String("Arguments not correct. Usage:");Trace.Ln;Trace.String("name.efi kernel config"); Trace.Ln;
		END;

		(* If we come here, something went wrong! Cleanup the memory, such that we can try another time *)
		EFILib.FreeMemory;
	END LoadA2;

BEGIN
	LoadA2;
END EFIA2Loader.

PET.Open EFI.Tool ~