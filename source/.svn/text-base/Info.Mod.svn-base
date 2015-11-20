(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Info; (** AUTHOR "pjm/staubesv"; PURPOSE "System information"; *)

IMPORT
	SYSTEM, Machine, Heaps, Objects, Streams, Reflection, Modules, Commands, Options, Strings, D := Debugging, Kernel;

CONST
	AddressSize = SIZEOF(ADDRESS);

	RecordBlock = 1;
	ProtRecBlock = 2;
	ArrayBlock = 3;
	SystemBlock = 4;

	MaxNofTypes = 2048;

	(* Analyzer.Sort *)
	SortNone = 0;
	SortByCount = 1;
	SortBySize = 2;
	SortByTotalSize = 3; (* whereas TotalSize = Count * Size *)
	SortByName = 4;
	AllocatorHistorySize = 4096; (* recent history of allocators to be able to trace memory wasting sources *)

TYPE

	Type = RECORD
		ptag : ADDRESS;
		count : LONGINT;
		size : SIZE;
		type : SHORTINT;
		pc: ADDRESS;
	END;

	Analyzer = OBJECT
	VAR
		types : POINTER TO ARRAY OF Type;
		nofElements : LONGINT;

		(* global statistics *)
		nofHeapBlocks, nofFreeBlocks, nofSystemBlocks, nofRecordBlocks, nofProtRecBlocks, nofArrayBlocks: LONGINT;
		sizeHeapBlocks, sizeFreeBlocks, sizeSystemBlocks, sizeRecordBlocks, sizeProtRecBlocks, sizeArrayBlocks: SIZE;

		PROCEDURE &Init(size : LONGINT);
		BEGIN
			ASSERT(size > 0);
			NEW(types, size);
			Reset;
		END Init;

		PROCEDURE Reset;
		VAR i : LONGINT;
		BEGIN
			nofElements := 0;
			IF (types # NIL) THEN
				FOR i := 0 TO LEN(types)-1 DO
					types[i].ptag := Heaps.NilVal;
					types[i].count := 0;
					types[i].size := 0;
				END;
			END;
			nofHeapBlocks := 0; sizeHeapBlocks := 0;
			nofFreeBlocks := 0; sizeFreeBlocks := 0;
			nofSystemBlocks := 0; sizeSystemBlocks := 0;
			nofRecordBlocks := 0; sizeRecordBlocks := 0;
			nofProtRecBlocks := 0; sizeProtRecBlocks := 0;
			nofArrayBlocks := 0; sizeArrayBlocks := 0;
		END Reset;

		PROCEDURE SortBy(mode : LONGINT);
		VAR i, j : LONGINT; temp : Type;

			PROCEDURE IsGreaterThan(CONST entry1, entry2 : Type; mode : LONGINT) : BOOLEAN;
			VAR name1, name2: ARRAY 256 OF CHAR; count1,count2, size1, size2: LONGINT;
			BEGIN
				IF mode = SortByName THEN
					GetName(entry1.ptag,name1);
					GetName(entry2.ptag,name2);
					RETURN name1 > name2;
				ELSE

					count1 := entry1.count;
					size1 := entry1.size DIV count1;

					count2 := entry2.count;
					size2 := entry2.size DIV count2;

				RETURN
					((mode = SortByCount) & (count1 > count2)) OR
					((mode = SortBySize) & (size1 > size2)) OR
					((mode = SortByTotalSize) & (size1*count1 > size2 * count2))
					;
				END;

			END IsGreaterThan;

		BEGIN
			ASSERT((mode = SortByCount) OR (mode = SortBySize) OR (mode = SortByTotalSize) OR (mode=SortByName));
			(* sort descending... *)
			FOR i := 0 TO nofElements-1 DO
				FOR j := 1 TO nofElements-1 DO
					IF IsGreaterThan(types[j], types[j-1], mode) THEN
						temp := types[j-1];
						types[j-1] := types[j];
						types[j] := temp;
					END;
				END;
			END;
		END SortBy;

		PROCEDURE Add(CONST block : Heaps.HeapBlock; byPC: BOOLEAN);
		VAR type: SHORTINT;


			PROCEDURE AddByType(type: SHORTINT);
			VAR tag: ADDRESS; i: LONGINT;
			BEGIN
				SYSTEM.GET(block.dataAdr + Heaps.TypeDescOffset, tag);
				i := 0; WHILE (i < LEN(types)) & (i < nofElements) & (types[i].ptag # tag) DO INC(i) END;
				IF (i < nofElements) THEN
					INC(types[i].count);
					INC(types[i].size, block.size);
				ELSIF (i = nofElements) & (i < LEN(types)) THEN
					types[i].ptag := tag;
					types[i].count := 1;
					types[i].size := block.size;
					types[i].type := type;
					types[i].pc := 0;
					INC(nofElements)
				END;
			END AddByType;

			PROCEDURE AddByPC(type: SHORTINT);
			VAR pc: ADDRESS; i: LONGINT;
			BEGIN
				SYSTEM.GET(block.dataAdr + Heaps.HeapBlockOffset, pc);
				SYSTEM.GET(pc + Heaps.HeapBlockOffset, pc);
				IF pc # 0 THEN
					i := 0; WHILE (i < LEN(types)) & (i < nofElements) & (types[i].pc # pc) DO INC(i) END;
					IF (i < nofElements) THEN
						INC(types[i].count);
						INC(types[i].size, block.size);
					ELSIF (i = nofElements) & (i < LEN(types)) THEN
						types[i].ptag := 0;
						types[i].count := 1;
						types[i].size := block.size;
						types[i].type := type;
						types[i].pc := pc;
						INC(nofElements)
					END;
				END;
			END AddByPC;



		BEGIN
			INC(nofHeapBlocks); INC(sizeHeapBlocks, block.size);
			IF (block IS Heaps.RecordBlock) OR (block IS Heaps.ProtRecBlock) OR (block IS Heaps.ArrayBlock) THEN
				IF (block IS Heaps.ProtRecBlock) THEN
					type := ProtRecBlock;
					INC(nofProtRecBlocks); INC(sizeProtRecBlocks, block.size);
				ELSIF (block IS Heaps.RecordBlock) THEN
					type := RecordBlock;
					INC(nofRecordBlocks); INC(sizeRecordBlocks, block.size);
				ELSIF (block IS Heaps.ArrayBlock) THEN
					type := ArrayBlock;
					INC(nofArrayBlocks); INC(sizeArrayBlocks, block.size);
				ELSE
					HALT(99);
				END;
				IF byPC THEN
					AddByPC(type)
				ELSE
					(* all these heap blocks have a type tag *)
					AddByType(type)
				END;
			ELSIF (block IS Heaps.SystemBlock) THEN
				INC(nofSystemBlocks); INC(sizeSystemBlocks, block.size);
				(* system blocks do not have a type tag *)
				AddByPC(SystemBlock);
			ELSIF (block IS Heaps.FreeBlock) THEN
				INC(nofFreeBlocks); INC(sizeFreeBlocks, block.size);
			END;
		END Add;

		PROCEDURE ShowBlocks(CONST mask : ARRAY OF CHAR; out : Streams.Writer);
		VAR
			module : Modules.Module; typedesc : Modules.TypeDesc;
			size, totalSize: SIZE;
			startpc: ADDRESS;
			i, selected, total : LONGINT;
			string : ARRAY 256 OF CHAR; copy: ARRAY 256 OF CHAR;
		BEGIN
			ASSERT(out # NIL);
			size := 0; totalSize := 0;
			selected := 0; total := 0;
			FOR i := 0 TO nofElements-1 DO
				INC(total, types[i].count);
				module := NIL;
				IF (types[i].pc # 0) THEN
					module := Modules.ThisModuleByAdr(types[i].pc);
				ELSIF (types[i].ptag # 0) THEN
					Modules.ThisTypeByAdr(types[i].ptag, module, typedesc);
				END;
				IF (module # NIL)  THEN
					IF (types[i].ptag # 0) THEN
						string := "";
						COPY(module.name,copy);
						Strings.AppendX(string, copy);
						Strings.AppendX(string, ".");
						COPY(typedesc.name,copy);
						Strings.AppendX(string, copy);
					ELSE
						string := "";
						COPY(module.name,copy);
						Strings.AppendX(string, copy);
						Strings.AppendX(string, ".");
						Reflection.GetProcedureName(types[i].pc, copy,startpc);
						Strings.AppendX(string, copy);
						Strings.Append(string,":");
						Strings.IntToStr(types[i].pc - startpc, copy);
						Strings.Append(string,copy);
					END;

					IF Strings.Match(mask, string) THEN
						CASE types[i].type OF
							|RecordBlock: out.String("R ");
							|ProtRecBlock: out.String("P ");
							|ArrayBlock: out.String("A ");
							|SystemBlock: out.String("S ");
						ELSE
							out.String("U ");
						END;
						INC(selected, types[i].count);
						out.Int(types[i].count, 8); out.Char(" ");
						INC(size, types[i].size);
						out.Int(types[i].size DIV types[i].count, 6); out.String("B ");
						out.Int(types[i].size, 10); out.String("B ");
						out.String(string);
						out.String(" (total ");
						WriteB(types[i].size, out); out.String(")"); out.Ln
					END;
				END;
			END;
			out.Ln;
			IF (selected # total) THEN
				out.String("Selected "); out.Int(selected, 1); out.String(" of ");
				out.Int(total, 1); out.String(" dynamic records of ");
				out.Int(nofElements, 1); out.String(" unique types (total size : ");
				WriteB(size, out); out.String(" of "); WriteB(totalSize, out); out.String(")");
				out.Ln;
			ELSE
				out.Int(total, 1); out.String(" dynamic records of ");
				out.Int(nofElements, 1); out.String(" unique types found");
				out.String(" (total size : "); WriteB(sizeHeapBlocks, out); out.String(")");
				out.Ln;
			END;
		END ShowBlocks;

		PROCEDURE Show(out : Streams.Writer; CONST mask : ARRAY OF CHAR; sortMode : LONGINT; byPC: BOOLEAN);
		VAR nofUsedBlocks, sizeUsedBlocks : LONGINT;

			PROCEDURE ShowBlock(CONST name : ARRAY OF CHAR; nofBlocks: LONGINT; size: SIZE; totalNofBlocks: LONGINT; totalSize : SIZE; out : Streams.Writer);
			BEGIN
				out.Int(nofBlocks, 8); out.Char(" "); ShowPercent(nofBlocks, totalNofBlocks, out); out.Char(" ");
				out.String(name);
				out.String(" ("); WriteB(size, out); out.String(", "); ShowPercent(size, totalSize, out); out.String(")");
				out.Ln;
			END ShowBlock;

			PROCEDURE ShowPercent(cur, max : SIZE; out : Streams.Writer);
			VAR percent : LONGINT;
			BEGIN
				IF (max > 0) THEN
					percent := ENTIER(100 * (cur / max) + 0.5);
				ELSE
					percent := 0;
				END;
				IF (percent < 10) THEN out.String("  ");
				ELSIF (percent < 100) THEN out.Char(" ");
				END;
				out.Int(percent, 0); out.Char("%");
			END ShowPercent;

		BEGIN
			ASSERT(out # NIL);
			nofUsedBlocks := nofHeapBlocks - nofFreeBlocks;
			sizeUsedBlocks := sizeHeapBlocks - sizeFreeBlocks;
			out.Char(0EX); (* non-proportional font *)
			ShowBlock("HeapBlocks", nofHeapBlocks, sizeHeapBlocks, nofHeapBlocks, sizeHeapBlocks, out);
			ShowBlock("UsedBlocks", nofUsedBlocks, sizeUsedBlocks, nofHeapBlocks, sizeHeapBlocks, out);
			ShowBlock("FreeBlocks", nofFreeBlocks, sizeFreeBlocks, nofHeapBlocks, sizeHeapBlocks, out);
			out.Ln;
			ShowBlock("UsedBlocks", nofUsedBlocks, sizeUsedBlocks, nofUsedBlocks, sizeUsedBlocks, out);
			ShowBlock("SystemBlocks", nofSystemBlocks, sizeSystemBlocks, nofUsedBlocks, sizeUsedBlocks, out);
			ShowBlock("RecordBlocks", nofRecordBlocks, sizeRecordBlocks, nofUsedBlocks, sizeUsedBlocks, out);
			ShowBlock("ProtRectBlocks", nofProtRecBlocks, sizeProtRecBlocks, nofUsedBlocks, sizeUsedBlocks, out);
			ShowBlock("ArrayBlocks", nofArrayBlocks, sizeArrayBlocks, nofUsedBlocks, sizeUsedBlocks, out);

			IF (mask # "") THEN
				out.Ln;
				IF (sortMode = SortByCount) OR (sortMode = SortBySize) OR (sortMode = SortByTotalSize) OR (sortMode = SortByName) THEN
					SortBy(sortMode);
				END;
				ShowBlocks(mask, out);
			END;
			out.Char(0FX); (* proportional font *)
		END Show;

	END Analyzer;

VAR
	currentMarkValueAddress : ADDRESS;
	recentAllocators*: ARRAY AllocatorHistorySize OF RECORD pc*: ARRAY 3 OF ADDRESS; time*: HUGEINT END;
	numRecentAllocators*: LONGINT;

PROCEDURE LogAlloc(p: ANY);
VAR time: HUGEINT; bp: ADDRESS; i: LONGINT;pc: ADDRESS;
BEGIN
	time := Machine.GetTimer();

	bp := Machine.CurrentBP();

	SYSTEM.GET(bp+SIZEOF(ADDRESS),pc);

	FOR i := 0 TO LEN(recentAllocators[numRecentAllocators].pc)-1 DO
		recentAllocators[numRecentAllocators].pc[i] := pc;
		IF bp # 0 THEN
			SYSTEM.GET(bp, bp);
			SYSTEM.GET(bp+SIZEOF(ADDRESS),pc);
		END;
	END;

	recentAllocators[numRecentAllocators].time := time;
	INC(numRecentAllocators); numRecentAllocators := numRecentAllocators MOD LEN(recentAllocators);
END LogAlloc;


PROCEDURE WriteB(b : SIZE; out : Streams.Writer);
VAR shift : LONGINT; suffix : ARRAY 2 OF CHAR;
BEGIN
	IF b < 100*1024 THEN suffix := ""; shift := 0
	ELSIF b < 100*1024*1024 THEN suffix := "K"; shift := -10
	ELSE suffix := "M"; shift := -20
	END;
	IF b # ASH(ASH(b, shift), -shift) THEN out.Char("~") END;
	out.Int(ASH(b, shift), 1);
	IF TRUE THEN
		out.String(suffix); out.Char("B")
	ELSE
		out.Char(" ");
		out.String(suffix); out.String("byte");
		IF b # 1 THEN out.Char("s") END
	END
END WriteB;

(** Show the details of the specified module. *)

PROCEDURE ModuleDetails*(context : Commands.Context); (** [Options] module ~ *)
VAR
	m : Modules.Module; i, j, k: LONGINT;
	p, procAdr: ADDRESS;
	adr : ADDRESS;
	modn : ARRAY 33 OF CHAR;
	options : Options.Options;
BEGIN
	NEW(options);
	options.Add("d", "details", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		context.arg.SkipWhitespace; context.arg.String(modn);
		m := Modules.root;
		WHILE (m # NIL) & (m.name # modn) DO m := m.next END;
		IF m # NIL THEN
			context.out.String(m.name);
			context.out.String(" refcnt = "); context.out.Int(m.refcnt, 1);
			context.out.String(" sb ="); context.out.Hex(m.sb, 9);
			context.out.String(" dataSize = "); context.out.Int(LEN(m.data), 1);
			context.out.String(" staticTdSize = "); context.out.Int(LEN(m.staticTypeDescs), 1);
			context.out.String(" codeSize = "); context.out.Int(LEN(m.code), 1);
			context.out.String(" refSize = "); context.out.Int(LEN(m.refs), 1);
			context.out.String(" entries = "); context.out.Int(LEN(m.entry), 1);
			context.out.String(" commands = "); context.out.Int(LEN(m.command), 1);
			context.out.String(" modules = "); context.out.Int(LEN(m.module), 1);
			context.out.String(" types = "); context.out.Int(LEN(m.typeInfo), 1);
			context.out.String(" pointers = "); context.out.Int(LEN(m.ptrAdr), 1);
			context.out.Ln; context.out.String("  ptrAdr:");
			FOR i := 0 TO LEN(m.ptrAdr)-1 DO
				context.out.Char(" "); context.out.Int(m.ptrAdr[i]-m.sb, 1)
			END;
			context.out.Ln;
			IF options.GetFlag("details") THEN
				context.out.String("Pointer Details: ");
				IF (m.ptrAdr # NIL) THEN
					context.out.Ln;
					FOR i := 0 TO LEN(m.ptrAdr) - 1 DO
						context.out.Int(i, 0); context.out.String(": ");
						context.out.Address(m.ptrAdr[i]); context.out.String(" -> ");
						SYSTEM.GET(m.ptrAdr[i], adr);
						context.out.Address(adr);
						context.out.Ln;
					END;
				ELSE
					context.out.String("none"); context.out.Ln;
				END;
			END;
			FOR i := 0 TO LEN(m.typeInfo) - 1 DO
				context.out.Ln; context.out.String("  type:");
				context.out.Hex(m.typeInfo[i].tag, 9);
				context.out.Char(" "); context.out.String(m.typeInfo[i].name);
				context.out.Hex(SYSTEM.VAL(LONGINT, m.typeInfo[i].flags), 9);
					(* type descriptor info *)
				context.out.Ln; context.out.String("  typedesc1:");
				p := m.typeInfo[i].tag; (* address of static type descriptor *)
				REPEAT
					SYSTEM.GET(p, k);
					IF ABS(k) <= 4096 THEN context.out.Char(" "); context.out.Int(k, 1)
					ELSE context.out.Hex(k, 9)
					END;
					INC(p, AddressSize)
				UNTIL k < -40000000H;
					(* methods *)
				context.out.Ln; context.out.String("  typedescmths:");
				p := SYSTEM.VAL(ADDRESS, m.typeInfo[i].tag) + Modules.Mth0Ofs;
				j := 0;
				SYSTEM.GET(p, procAdr);
				WHILE procAdr # Heaps.MethodEndMarker DO
					context.out.Ln; context.out.Int(j, 3); context.out.Char(" ");
					Reflection.WriteProc(context.out, procAdr);
					DEC(p, AddressSize);
					SYSTEM.GET(p, procAdr);
					INC(j)
				END
			END;
			context.out.Ln
		END;
	END;
END ModuleDetails;

(** Find a procedure, given the absolute PC address. *)

PROCEDURE ModulePC*(context : Commands.Context);	(** pc *)
VAR pc : LONGINT;
BEGIN
	context.arg.SkipWhitespace; context.arg.Int(pc, FALSE);
	IF Modules.ThisModuleByAdr(pc) # NIL THEN
		Reflection.WriteProc(context.out, pc);
	ELSE
		context.out.Hex(pc, 8); context.out.String(" not found")
	END;
	context.out.Ln;
END ModulePC;

PROCEDURE AllObjects*(context : Commands.Context); (** [Options] mask ~ *)
VAR
	options : Options.Options; sortMode : LONGINT;
	analyzer : Analyzer;
	memBlock {UNTRACED}: Machine.MemoryBlock;
	heapBlock : Heaps.HeapBlock;
	p : ADDRESS;
	mask : ARRAY 128 OF CHAR;
BEGIN
	NEW(options);
	options.Add("s", "sort", Options.Integer);
	options.Add(0X, "pc", Options.Flag);
	IF options.Parse(context.arg, context.error) THEN
		IF ~options.GetInteger("sort", sortMode) THEN sortMode := SortNone; END;
		context.arg.SkipWhitespace; context.arg.String(mask);
		NEW(analyzer, MaxNofTypes);
		Machine.Acquire(Machine.Heaps);
		memBlock := Machine.memBlockHead;
		WHILE memBlock # NIL DO
			p := memBlock.beginBlockAdr;
			WHILE p # memBlock.endBlockAdr DO
				heapBlock := SYSTEM.VAL(Heaps.HeapBlock, p + Heaps.BlockHeaderSize); (* get heap block *)
				analyzer.Add(heapBlock, options.GetFlag("pc"));
				p := p + heapBlock.size
			END;
			memBlock := memBlock.next
		END;
		Machine.Release(Machine.Heaps);
		analyzer.Show(context.out, mask, sortMode, options.GetFlag("pc"));
	END;
END AllObjects;

PROCEDURE ShowRecentAllocators*(out: Streams.Writer; scale: HUGEINT);
VAR
	i,from,to,num, pcs: LONGINT;
	pc,startpc: ADDRESS;
	module: Modules.Module; name: ARRAY 256 OF CHAR;
	time: HUGEINT;
	timer: Kernel.MilliTimer;
BEGIN
	time := Machine.GetTimer();
	IF scale <= 0 THEN
	   Kernel.SetTimer( timer, 100 );  scale := Machine.GetTimer();
	   WHILE ~Kernel.Expired( timer ) DO END;
        scale := (Machine.GetTimer() - scale) DIV 100; (* 1 ms resolution *)
	END;
	out.String("----------- recent allocators, t = ");
	out.Hex(recentAllocators[i].time, -16);
	out.String(" ---------------"); out.Ln;
	Machine.Acquire(Machine.Heaps);
	i := numRecentAllocators;
	DEC(i); i := i MOD LEN(recentAllocators);
	from := i;
	pc := recentAllocators[i].pc[0];
	WHILE (i # numRecentAllocators) & (pc # 0) DO
		DEC(i); i := i MOD LEN(recentAllocators);
		pc := recentAllocators[i].pc[0];
	END;
	to := i;
	Machine.Release(Machine.Heaps);
	i := from; num := 0;
	WHILE i # to DO

		out.Int(num,1); out.String(": ");
		out.Hex(recentAllocators[i].time, -16);

		out.String("(");
		out.Int( SHORT((recentAllocators[i].time-time) DIV scale), 1);
		out.String(")");

		out.String(": ");

		FOR pcs := 0 TO LEN(recentAllocators[i].pc)-1 DO
			pc := recentAllocators[i].pc[pcs];

			module := Modules.ThisModuleByAdr(pc);
			out.String(module.name);
			out.String(".");
			Reflection.GetProcedureName(pc, name,startpc);
			out.String(name);
			out.String(":");
			out.Int(pc-startpc,1);
			out.String(" ");
		END;
		out.Ln;
		DEC(i); i := i MOD LEN(recentAllocators);
		INC(num);
	END;
END ShowRecentAllocators;

PROCEDURE ClearRecentAllocators*;
VAR i: LONGINT;
BEGIN
	Machine.Acquire(Machine.Heaps);
	i := (numRecentAllocators - 1) MOD LEN(recentAllocators);
	recentAllocators[i].pc[0] := 0;
	Machine.Release(Machine.Heaps);
END ClearRecentAllocators;

PROCEDURE AddAllocatorLogger*;
BEGIN
	Heaps.SetAllocationLogger(LogAlloc);
END AddAllocatorLogger;


PROCEDURE RecentAllocators*(context : Commands.Context); (** [Options] mask ~ *)
VAR
	options : Options.Options;
	scale: HUGEINT;
	num: LONGINT;
BEGIN
	NEW(options);
	options.Add("c", "clear", Options.Flag);
	options.Add("s", "scale", Options.Integer);
	IF options.Parse(context.arg, context.error) THEN
		IF options.GetInteger("scale", num) & (num > 0 ) THEN
			scale := num
		ELSE (* autoscale to ms *)
			scale := 0;
	     END;
	     ShowRecentAllocators(context.out, scale);
		IF options.GetFlag("clear") THEN ClearRecentAllocators END;
	END;
END RecentAllocators;

PROCEDURE TraceModule*(context : Commands.Context); (** moduleName mask ~ *)
VAR
	options : Options.Options; sortMode : LONGINT;
	analyzer : Analyzer;
	mask : ARRAY 128 OF CHAR;
	moduleName : Modules.Name; module : Modules.Module;
BEGIN
	NEW(options);
	options.Add("s", "sort", Options.Integer);
	IF options.Parse(context.arg, context.error) THEN
		IF ~options.GetInteger("sort", sortMode) THEN sortMode := SortNone; END;
		context.arg.SkipWhitespace; context.arg.String(moduleName);
		context.arg.SkipWhitespace; context.arg.String(mask);
		module := Modules.ModuleByName(moduleName);
		IF (module # NIL) THEN
			NEW(analyzer, MaxNofTypes);
			Machine.Acquire(Machine.Heaps);
			IncrementCurrentMarkValue;
			module.FindRoots;
			AnalyzeMarkedBlocks(analyzer);
			Machine.Release(Machine.Heaps);
			context.out.String("Heap block referenced by module "); context.out.String(moduleName); context.out.Char(":");
			context.out.Ln;
			analyzer.Show(context.out, mask, sortMode, FALSE);
		ELSE
			context.error.String("Module "); context.error.String(moduleName); context.error.String(" is not loaded."); context.error.Ln;
		END;
	END;
END TraceModule;

PROCEDURE TraceReference*(context : Commands.Context); (** ModuleName.VariableName mask ~ *)
VAR
	options : Options.Options; sortMode : LONGINT;
	analyzer : Analyzer; address : ADDRESS;
	module : Modules.Module; variable : Reflection.Variable;
	mask, modVar : ARRAY 256 OF CHAR; array : Strings.StringArray;
	varName : ARRAY 64 OF CHAR;
BEGIN
	NEW(options);
	options.Add("s", "sort", Options.Integer);
	IF options.Parse(context.arg, context.error) THEN
		IF ~options.GetInteger("sort", sortMode) THEN sortMode := SortNone; END;
		context.arg.SkipWhitespace; context.arg.String(modVar);
		context.arg.SkipWhitespace; context.arg.String(mask);
		array := Strings.Split(modVar, ".");
		IF (LEN(array) = 2) THEN
			module := Modules.ModuleByName(array[0]^);
			IF (module # NIL) THEN
				COPY(array[1]^, varName);
				IF Reflection.FindVar(module, varName, variable) THEN
					IF (variable.type = 13) OR (variable.type = 29) THEN
						NEW(analyzer, MaxNofTypes);
						context.out.String("Heap blocks reference by variable "); context.out.String(modVar);
						context.out.Char(":"); context.out.Ln;
						IF (variable.adr # 0) THEN
							SYSTEM.GET(variable.adr, address);
							MarkReference(analyzer, SYSTEM.VAL(ANY, address));
							analyzer.Show(context.out, mask, sortMode, FALSE);
						END;
					ELSE
						context.error.String("Variable is not a pointer"); context.error.Ln;
					END;
				ELSE
					context.error.String("Variable "); context.error.String(array[1]^); context.error.String(" not found");
					context.error.Ln;
				END;
			ELSE
				context.error.String("Module "); context.error.String(array[0]^); context.error.String(" not found");
				context.error.Ln;
			END;
		ELSE
			context.error.String("Expected ModuleName.VariableName parameter"); context.error.Ln;
		END;
	END;
END TraceReference;

PROCEDURE MarkReference(analyzer : Analyzer; ref : ANY);
BEGIN
	ASSERT(analyzer # NIL);
	Machine.Acquire(Machine.Heaps);
	IncrementCurrentMarkValue;
	Heaps.Mark(ref);
	AnalyzeMarkedBlocks(analyzer);
	Machine.Release(Machine.Heaps);
END MarkReference;

PROCEDURE TraceProcessID*(context : Commands.Context); (** ProcessID mask ~ *)
VAR
	options : Options.Options; sortMode : LONGINT;
	analyzer : Analyzer;
	process : Objects.Process;
	processID : LONGINT; mask : ARRAY 256 OF CHAR;
BEGIN
	NEW(options);
	options.Add("s", "sort", Options.Integer);
	IF options.Parse(context.arg, context.error) THEN
		IF ~options.GetInteger("sort", sortMode) THEN sortMode := SortNone; END;
		IF context.arg.GetInteger(processID, FALSE) THEN
			context.arg.SkipWhitespace; context.arg.String(mask);
			process := FindProcessByID(processID);
			IF (process # NIL) THEN
				NEW(analyzer, MaxNofTypes);
				Machine.Acquire(Machine.Heaps);
				IncrementCurrentMarkValue;
				process.FindRoots;
				Heaps.CheckCandidates;
				AnalyzeMarkedBlocks(analyzer);
				Machine.Release(Machine.Heaps);
				context.out.String("Heap blocks referenced by process ID = "); context.out.Int(processID, 0); context.out.Char(":");
				context.out.Ln;
				analyzer.Show(context.out, mask, sortMode, FALSE);
			ELSE
				context.error.String("Process ID = "); context.error.Int(processID, 0); context.error.String(" not found");
				context.error.Ln;
			END;
		ELSE
			context.error.String("Expected ProcessID parameter"); context.error.Ln;
		END;
	END;
END TraceProcessID;

PROCEDURE FindProcessByID(id : LONGINT) : Objects.Process;
VAR
	memBlock {UNTRACED}: Machine.MemoryBlock;
	heapBlock {UNTRACED}: Heaps.HeapBlock;
	blockAdr, tag : ADDRESS;
	process : Objects.Process;
	i : LONGINT;
BEGIN
	i := 0;
	Machine.Acquire(Machine.Heaps);
	process := NIL;
	memBlock := Machine.memBlockHead;
	WHILE (memBlock # NIL) & (process = NIL) DO
		blockAdr := memBlock.beginBlockAdr;
		WHILE (blockAdr # memBlock.endBlockAdr) & (process = NIL) DO
			heapBlock := SYSTEM.VAL(Heaps.HeapBlock, blockAdr + Heaps.BlockHeaderSize);
			IF (heapBlock IS Heaps.RecordBlock) THEN
				SYSTEM.GET(heapBlock.dataAdr + Heaps.TypeDescOffset, tag);
				IF (tag = SYSTEM.TYPECODE(Objects.Process)) THEN
					process := SYSTEM.VAL(Objects.Process, heapBlock.dataAdr);
					IF (process.id # id) THEN process := NIL; END;
				END;
			END;
			blockAdr := blockAdr + heapBlock.size
		END;
		memBlock := memBlock.next
	END;
	Machine.Release(Machine.Heaps);
	RETURN process;
END FindProcessByID;

(* Caller MUST hold Machine.Heaps lock!! *)
PROCEDURE AnalyzeMarkedBlocks(analyzer : Analyzer);
VAR
	memBlock {UNTRACED}: Machine.MemoryBlock;
	heapBlock : Heaps.HeapBlock;
	currentMarkValue : LONGINT;
	blockAdr : ADDRESS;
	mark : LONGINT;
BEGIN
	ASSERT(analyzer # NIL);
	currentMarkValue := GetCurrentMarkValue();
	memBlock := Machine.memBlockHead;
	WHILE memBlock # NIL DO
		blockAdr := memBlock.beginBlockAdr;
		WHILE blockAdr # memBlock.endBlockAdr DO
			heapBlock := SYSTEM.VAL(Heaps.HeapBlock, blockAdr + Heaps.BlockHeaderSize); (* get heap block *)
			mark := SYSTEM.GET32(blockAdr + Heaps.BlockHeaderSize); (* access to private field heapBlock.mark *)
			IF (mark = currentMarkValue) THEN
				analyzer.Add(heapBlock, FALSE);
				SYSTEM.PUT32(blockAdr + Heaps.BlockHeaderSize, currentMarkValue - 1);
			END;
			blockAdr := blockAdr + heapBlock.size
		END;
		memBlock := memBlock.next
	END;
	SetCurrentMarkValue(currentMarkValue - 1); (* restore Heaps.currentMarkValue *)
END AnalyzeMarkedBlocks;

PROCEDURE WriteType(adr : LONGINT; out : Streams.Writer);
VAR m : Modules.Module;  t : Modules.TypeDesc; name: ARRAY 256 OF CHAR;
BEGIN
	Modules.ThisTypeByAdr(adr, m, t);
	IF m # NIL THEN
		out.String(m.name);  out.Char(".");
		IF (t # NIL) THEN
			IF t.name = "" THEN out.String("TYPE") ELSE
				COPY(t.name,name);
			out.String(name) END
		ELSE
			out.String("NOTYPEDESC");
		END;
	ELSE
		out.String("NIL")
	END
END WriteType;

PROCEDURE GetName(adr: LONGINT; VAR name: ARRAY OF CHAR);
VAR  m : Modules.Module;  t : Modules.TypeDesc;
BEGIN
	Modules.ThisTypeByAdr(adr, m, t);
	name := "";
	IF m # NIL THEN
		COPY(m.name,name);
		IF (t # NIL) THEN
			Strings.Append(name,".");
			Strings.Append(name,t.name);
		END;
	END;
END GetName;

(* Access to private field Heaps.currentMarkValue *)

PROCEDURE GetCurrentMarkValue() : LONGINT;
BEGIN
	RETURN SYSTEM.GET32(currentMarkValueAddress);
END GetCurrentMarkValue;

PROCEDURE SetCurrentMarkValue(value : LONGINT);
BEGIN
	SYSTEM.PUT32(currentMarkValueAddress, value);
END SetCurrentMarkValue;

PROCEDURE IncrementCurrentMarkValue;
BEGIN
	SetCurrentMarkValue(GetCurrentMarkValue() + 1);
END IncrementCurrentMarkValue;

PROCEDURE GetCurrentMarkValueAddress() : ADDRESS;
VAR address : ADDRESS; module : Modules.Module; variable : Reflection.Variable;
BEGIN
	address := Heaps.NilVal;
	module := Modules.ModuleByName("Heaps");
	IF (module # NIL) THEN
		IF Reflection.FindVar(module, "currentMarkValue", variable) THEN
			ASSERT(variable.n = 1); (* currentMarkValue is not an array *)
			ASSERT(variable.type = 6); (*? type is LONGINT, currently no support for 64-bit addresses *)
			address := variable.adr;
		END;
	END;
	RETURN address;
END GetCurrentMarkValueAddress;

PROCEDURE Terminate;
BEGIN
	IF Heaps.allocationLogger = LogAlloc THEN Heaps.SetAllocationLogger(NIL) END;
END Terminate;

BEGIN
	currentMarkValueAddress := GetCurrentMarkValueAddress();
	ASSERT(currentMarkValueAddress # Heaps.NilVal);
	Modules.InstallTermHandler(Terminate);
END Info.

SystemTools.Free Info ~

Info.AllObjects ~
Info.AllObjects * ~

Info.AllObjects --sort=0 * ~
Info.AllObjects --sort=1 * ~
Info.AllObjects --sort=2 * ~

Info.TraceModule PET ~

Info.TraceModule Info ~
Info.TraceModule Info * ~

Info.TraceReference HotKeys.hotkeys ~
Info.TraceReference HotKeys.hotkeys * ~

Info.TraceProcessID 7180 * ~

Info.ModuleDetails -d Modules  ~

SystemTools.CollectGarbage ~


Compiler.Compile --symbolFilePrefix=/temp/objEO/ --objectFilePrefix=/temp/objEO/  Info.Mod ~

Info.AddAllocatorLogger
Info.RecentAllocators --clear   --scale=2400000 ~
Info.RecentAllocators    --scale=2400000 ~
Info.RecentAllocators --clear ~
Info.ClearRecentAllocators  ~



