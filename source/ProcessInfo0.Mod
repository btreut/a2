MODULE ProcessInfo0; (** AUTHOR "staubesv"; PURPOSE "Platform-dependent process interface"; *)

IMPORT
	SYSTEM, Machine, Heaps, Objects;

TYPE

	ProcessArray* = ARRAY OF Objects.Process;

PROCEDURE GetProcesses*(VAR array : ProcessArray; VAR nofProcesses : LONGINT);
VAR
	memBlock {UNTRACED}: Machine.MemoryBlock;
	heapBlock {UNTRACED}: Heaps.HeapBlock;
	process : Objects.Process;
	blockAdr, tag : ADDRESS;
	length, i : LONGINT;
BEGIN
	length := LEN(array); nofProcesses := 0;
	FOR i := 0 TO i-1 DO array[i] := NIL; END;
	Machine.Acquire(Machine.Heaps);
	memBlock := Machine.memBlockHead;
	WHILE (memBlock # NIL) DO
		blockAdr := memBlock.beginBlockAdr;
		WHILE (blockAdr # memBlock.endBlockAdr) DO
			heapBlock := SYSTEM.VAL(Heaps.HeapBlock, blockAdr + Heaps.BlockHeaderSize);
			IF (heapBlock IS Heaps.RecordBlock) THEN
				SYSTEM.GET(heapBlock.dataAdr + Heaps.TypeDescOffset, tag);
				IF (nofProcesses < length) & (tag = SYSTEM.TYPECODE(Objects.Process)) THEN
					process := SYSTEM.VAL(Objects.Process, heapBlock.dataAdr);
					IF (process.mode # Objects.Terminated) THEN
						array[nofProcesses] := process;
						INC(nofProcesses);
					END;
				END;
			END;
			blockAdr := blockAdr + heapBlock.size
		END;
		memBlock := memBlock.next
	END;
	Machine.Release(Machine.Heaps);
END GetProcesses;

PROCEDURE GetProcess*(id : LONGINT) : Objects.Process;
VAR
	memBlock {UNTRACED}: Machine.MemoryBlock;
	heapBlock {UNTRACED}: Heaps.HeapBlock;
	blockAdr, tag : ADDRESS;
	process : Objects.Process;
	i : LONGINT;
BEGIN
	i := 0;
	process := NIL;
	Machine.Acquire(Machine.Heaps);
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
END GetProcess;

END ProcessInfo0.
