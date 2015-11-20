MODULE WMPerfMonPluginHeap; (** AUTHOR "staubesv"; PURPOSE "Performance Monitor plugin for Heaps statistics"; *)

IMPORT
	SYSTEM, Machine, Heaps, Modules, WMGraphics, WMPerfMonPlugins;

CONST
	ModuleName = "WMPerfMonPluginHeap";

	BlockSize = 32; (* {BlockSize = Heaps.BlockSize} *)

TYPE
	SizeArray = ARRAY 27 OF LONGINT;

	BlocksHelper = OBJECT(WMPerfMonPlugins.Helper)
	VAR
		blocks, recblks, sysblks, arrblks, protrecblks, freeblks, unknowns : LONGINT;
		blockssize, recblksize, sysblksize, arrblksize, protrecblksize, freeblksize, unknownsize : SIZE;
		heapsize : SIZE;
		blockSizes, recblkSizes, sysblkSizes, arrblkSizes, protrecblkSizes, freeblkSizes : SizeArray;

		PROCEDURE Update;
		VAR p : ADDRESS; memBlock {UNTRACED}: Machine.MemoryBlock; heapBlock: Heaps.HeapBlock;
		BEGIN
			blocks := 0; recblks := 0; sysblks := 0; arrblks := 0;
			protrecblks := 0; freeblks := 0;
			blockssize := 0; recblksize := 0; sysblksize := 0; arrblksize := 0;
			protrecblksize := 0; freeblksize := 0;
			ClearSizeArrays;
			Machine.Acquire(Machine.Heaps);
			heapsize := 0;
			memBlock := Machine.memBlockHead;
			WHILE memBlock # NIL DO
				p := memBlock.beginBlockAdr;
				WHILE p # memBlock.endBlockAdr DO
					heapBlock := SYSTEM.VAL(Heaps.HeapBlock, p + Heaps.BlockHeaderSize); (* get heap block *)
					INC(blocks);
					INC(blockssize, heapBlock.size);
					IF ~(heapBlock IS Heaps.FreeBlock) THEN
						AddSize(heapBlock.size, blockSizes);
					END;
					IF heapBlock IS Heaps.SystemBlock THEN
						INC(sysblks); INC(sysblksize, heapBlock.size);
						AddSize(heapBlock.size, sysblkSizes);
					ELSIF heapBlock IS Heaps.ProtRecBlock THEN
						INC(protrecblks); INC(protrecblksize, heapBlock.size);
						AddSize(heapBlock.size, protrecblkSizes);
					ELSIF heapBlock IS Heaps.RecordBlock THEN
						INC(recblks); INC(recblksize, heapBlock.size);
						AddSize(heapBlock.size, recblkSizes);
					ELSIF heapBlock IS Heaps.ArrayBlock THEN
						INC(arrblks); INC(arrblksize, heapBlock.size);
						AddSize(heapBlock.size, arrblkSizes);
					ELSIF heapBlock IS Heaps.FreeBlock THEN
						INC(freeblks); INC(freeblksize, heapBlock.size);
						AddSize(heapBlock.size, freeblkSizes);
					END;
					p := p + heapBlock.size
				END;
				heapsize := heapsize + memBlock.endBlockAdr - memBlock.beginBlockAdr;
				memBlock := memBlock.next
			END;
			Machine.Release(Machine.Heaps);
		END Update;

		PROCEDURE ClearSizeArrays;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO 26 DO
				blockSizes[i] := 0;
				recblkSizes[i] := 0;
				sysblkSizes[i] := 0;
				arrblkSizes[i] := 0;
				protrecblkSizes[i] := 0;
				freeblkSizes[i] := 0;
			END;
		END ClearSizeArrays;

		PROCEDURE AddSize(size : SIZE; VAR array : SizeArray);
		CONST K = 1024; M = 1024*1024;
		BEGIN
			IF (size <= 320) THEN
				INC(array[(size DIV 32) - 1]);
			ELSIF (size < 1*K) THEN INC(array[10]);
			ELSIF (size < 2*K) THEN INC(array[11]);
			ELSIF (size < 4*K) THEN INC(array[12]);
			ELSIF (size < 8*K) THEN INC(array[13]);
			ELSIF (size < 16*K) THEN INC(array[14]);
			ELSIF (size < 32*K) THEN INC(array[15]);
			ELSIF (size < 64*K) THEN INC(array[16]);
			ELSIF (size < 128*K) THEN INC(array[17]);
			ELSIF (size < 256*K) THEN INC(array[18]);
			ELSIF (size < 512*K) THEN INC(array[19]);
			ELSIF (size < 1*M) THEN INC(array[20]);
			ELSIF (size < 2*M) THEN INC(array[21]);
			ELSIF (size < 4*M) THEN INC(array[22]);
			ELSIF (size < 8*M) THEN INC(array[23]);
			ELSIF (size < 16*M) THEN INC(array[24]);
			ELSIF (size < 32*M) THEN INC(array[25]);
			ELSE
				INC(array[26]);
			END;
		END AddSize;

	END BlocksHelper;

TYPE

	Blocks = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		h : BlocksHelper;

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "Blocks"; p.description := "Number and types of blocks on the heap"; p.modulename := ModuleName;
			p.autoMax := TRUE; p.noSuperSampling := TRUE; (* since expensive *)
			p.minDigits := 9; p.fraction := 0;
			p.helper := blocksHelper; h := blocksHelper;

			NEW(ds, 7);
			ds[0].name := "blocks"; ds[0].color := WMGraphics.White; INCL(ds[0].flags, WMPerfMonPlugins.Sum);
			ds[1].name := "recblocks"; ds[1].color := WMGraphics.Green;
			ds[2].name := "sysblocks"; ds[2].color := WMGraphics.Red;
			ds[3].name := "arrblocks"; ds[3].color := WMGraphics.Blue;
			ds[4].name := "protrecblocks"; ds[4].color := WMGraphics.Magenta;
			ds[5].name := "freeblocks"; ds[5].color := WMGraphics.Yellow;
			ds[6].name := "unknown"; ds[6].color := WMGraphics.Black;
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset;
		BEGIN
			dataset[0] := h.blocks;
			dataset[1] := h.recblks;
			dataset[2] := h.sysblks;
			dataset[3] := h.arrblks;
			dataset[4] := h.protrecblks;
			dataset[5] := h.freeblks;
			dataset[6] := h.unknowns;
		END UpdateDataset;

	END Blocks;

TYPE

	BlockTotalSizes = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		h : BlocksHelper;

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.name := "TotalBlockSizes"; p.description := "Total sizes of blocks on the heap"; p.modulename := ModuleName;
			p.autoMax := TRUE; p.noSuperSampling := TRUE; (* since expensive *)
			p.minDigits := 9; p.fraction := 0; p.unit := "KB";
			p.helper := blocksHelper; h := blocksHelper;

			NEW(ds, 7);
			ds[0].name := "blocks"; ds[0].color := WMGraphics.White; INCL(ds[0].flags, WMPerfMonPlugins.Sum);
			ds[1].name := "recblocks"; ds[1].color := WMGraphics.Green;
			ds[2].name := "sysblocks"; ds[2].color := WMGraphics.Red;
			ds[3].name := "arrblocks"; ds[3].color := WMGraphics.Blue;
			ds[4].name := "protrecblocks"; ds[4].color := WMGraphics.Magenta;
			ds[5].name := "freeblocks"; ds[5].color := WMGraphics.Yellow;
			ds[6].name := "unknown"; ds[6].color := WMGraphics.Black;
			p.datasetDescriptor := ds;
		END Init;

		PROCEDURE UpdateDataset;
		BEGIN
			dataset[0] := h.blockssize;
			dataset[1] := h.recblksize;
			dataset[2] := h.sysblksize;
			dataset[3] := h.arrblksize;
			dataset[4] := h.protrecblksize;
			dataset[5] := h.freeblksize;
			dataset[6] := h.unknownsize;
		END UpdateDataset;

	END BlockTotalSizes;

TYPE

	BlockSizesBase = OBJECT(WMPerfMonPlugins.Plugin)
	VAR
		h : BlocksHelper;

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		VAR ds : WMPerfMonPlugins.DatasetDescriptor;
		BEGIN
			p.modulename := ModuleName;
			p.autoMax := TRUE; p.noSuperSampling := TRUE;
			p.minDigits := 9; p.fraction := 0; p.unit := "KB";
			p.helper := blocksHelper; h := blocksHelper;

			NEW(ds, 27);
			ds[0].name := "32B";
			ds[1].name := "64B";
			ds[2].name := "92B";
			ds[3].name := "128B";
			ds[4].name := "160B";
			ds[5].name := "192B";
			ds[6].name := "224B";
			ds[7].name := "256B";
			ds[8].name := "288B";
			ds[9].name := "320B";
			ds[10].name := "320B-1KB";
			ds[11].name := "1-2KB";
			ds[12].name := "2-4KB";
			ds[13].name := "4-8KB";
			ds[14].name := "8-16KB";
			ds[15].name := "16-32KB";
			ds[16].name := "32-64KB";
			ds[17].name := "64-128KB";
			ds[18].name := "128-256KB";
			ds[19].name := "256-512KB";
			ds[20].name := "0.5-1MB";
			ds[21].name := "1-2MB";
			ds[22].name := "2-4MB";
			ds[23].name := "4-8MB";
			ds[24].name := "8-16MB";
			ds[25].name := "16-32MB";
			ds[26].name := ">32MB";
			p.datasetDescriptor := ds;
		END Init;

	END BlockSizesBase;

TYPE

	BlockSizes = OBJECT(BlockSizesBase)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			Init^(p);
			p.name := "BlockSizes"; p.description := "Sizes of non-free blocks on the heap";
		END Init;

		PROCEDURE UpdateDataset;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(h.blockSizes)-1 DO
				dataset[i] := h.blockSizes[i];
			END;
		END UpdateDataset;

	END BlockSizes;

	SysBlockSizes = OBJECT(BlockSizesBase)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			Init^(p);
			p.name := "SysBlockSizes"; p.description := "Sizes of system blocks on the heap";
		END Init;

		PROCEDURE UpdateDataset;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(h.sysblkSizes)-1 DO
				dataset[i] := h.sysblkSizes[i];
			END;
		END UpdateDataset;

	END SysBlockSizes;

	RecBlockSizes = OBJECT(BlockSizesBase)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			Init^(p);
			p.name := "RecBlockSizes"; p.description := "Sizes of record blocks on the heap";
		END Init;

		PROCEDURE UpdateDataset;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(h.recblkSizes)-1 DO
				dataset[i] := h.recblkSizes[i];
			END;
		END UpdateDataset;

	END RecBlockSizes;

	ProtRecBlockSizes = OBJECT(BlockSizesBase)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			Init^(p);
			p.name := "ProtRecBlockSizes"; p.description := "Sizes of protected record  blocks on the heap";
		END Init;

		PROCEDURE UpdateDataset;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(h.protrecblkSizes)-1 DO
				dataset[i] := h.protrecblkSizes[i];
			END;
		END UpdateDataset;

	END ProtRecBlockSizes;

	ArrBlockSizes = OBJECT(BlockSizesBase)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			Init^(p);
			p.name := "ArrayBlockSizes"; p.description := "Sizes of array blocks on the heap";
		END Init;

		PROCEDURE UpdateDataset;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(h.arrblkSizes)-1 DO
				dataset[i] := h.arrblkSizes[i];
			END;
		END UpdateDataset;

	END ArrBlockSizes;

	FreeBlockSizes = OBJECT(BlockSizesBase)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			Init^(p);
			p.name := "FreeBlockSizes"; p.description := "Sizes of free blocks on the heap";
		END Init;

		PROCEDURE UpdateDataset;
		VAR i : LONGINT;
		BEGIN
			FOR i := 0 TO LEN(h.freeblkSizes)-1 DO
				dataset[i] := h.freeblkSizes[i];
			END;
		END UpdateDataset;

	END FreeBlockSizes;

TYPE

	GcRuns = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			p.name := "GcRuns"; p.description := "Number of times the GC has been run since system start"; p.modulename := ModuleName;
			p.noSuperSampling := TRUE;
			p.autoMax := TRUE; p.minDigits := 5;
		END Init;

		PROCEDURE UpdateDataset;
		BEGIN
			dataset[0] := Heaps.Ngc;
		END UpdateDataset;

	END GcRuns;

TYPE

	NewBlockCalls = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			p.name := "NewBlocks"; p.description := "Number of times Heaps.NewBlock has been called since system startup";
			p.modulename := ModuleName;
			p.noSuperSampling := TRUE;
			p.autoMax := TRUE; p.minDigits := 5;
		END Init;

		PROCEDURE UpdateDataset;
		BEGIN
			dataset[0] := Heaps.Nnew;
		END UpdateDataset;

	END NewBlockCalls;

TYPE

	BytesAllocated = OBJECT(WMPerfMonPlugins.Plugin)

		PROCEDURE Init(p : WMPerfMonPlugins.Parameter);
		BEGIN
			p.name := "KBAllocated"; p.description := "KBytes allocated since system start"; p.modulename := ModuleName;
			p.noSuperSampling := TRUE; p.unit := "KB";
			p.autoMax := TRUE; p.minDigits := 5;
		END Init;

		PROCEDURE UpdateDataset;
		BEGIN
			dataset[0] := Heaps.NnewBytes DIV 1024;
		END UpdateDataset;

	END BytesAllocated;

VAR
	blocksHelper : BlocksHelper;

PROCEDURE Install*;
END Install;

PROCEDURE InitPlugins;
VAR
	par : WMPerfMonPlugins.Parameter;
	blocks : Blocks; blockTotalSizes : BlockTotalSizes;
	blockSizes : BlockSizes;
	sysBlockSizes : SysBlockSizes;
	recBlockSizes : RecBlockSizes;
	protRecBlockSizes : ProtRecBlockSizes;
	arrBlockSizes : ArrBlockSizes;
	freeBlockSizes : FreeBlockSizes;
	gcRuns : GcRuns;
	newBlockCalls : NewBlockCalls; bytesAllocated : BytesAllocated;
BEGIN
	NEW(par); NEW(blocks, par);
	NEW(par); NEW(blockTotalSizes, par);
	NEW(par); NEW(blockSizes, par);
	NEW(par); NEW(sysBlockSizes, par);
	NEW(par); NEW(recBlockSizes, par);
	NEW(par); NEW(protRecBlockSizes, par);
	NEW(par); NEW(arrBlockSizes, par);
	NEW(par); NEW(freeBlockSizes, par);
	NEW(par); NEW(gcRuns, par);
	NEW(par); NEW(newBlockCalls, par);
	NEW(par); NEW(bytesAllocated, par);
END InitPlugins;

PROCEDURE Cleanup;
BEGIN
	IF Heaps.Stats THEN
		WMPerfMonPlugins.updater.RemoveByModuleName(ModuleName);
	END;
END Cleanup;

BEGIN
	ASSERT(BlockSize = Heaps.BlockSize);
	NEW(blocksHelper);
	InitPlugins;
	Modules.InstallTermHandler(Cleanup);
END WMPerfMonPluginHeap.

WMPerfMonPluginHeap.Install ~   SystemTools.Free WMPerfMonPluginHeap ~
