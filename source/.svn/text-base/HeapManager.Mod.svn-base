(* Non-blocking heaps *)
(* Copyright (C) Florian Negele *)

(** The HeapManager module provides a lock-free data structure called Heap that handles memory management. *)
(** A heap manages the allocation and deallocation of blocks of various sizes within a contiguous memory region. *)
MODULE HeapManager;

IMPORT CPU, Processors;

(* The minimal size of a memory block *)
CONST BlockSize = SIZE OF ADDRESS * 8;

(* Representation of a memory block *)
TYPE Block = POINTER {UNSAFE} TO RECORD index: SIZE; next {UNTRACED}: Block END;

(** Represents a heap which manages a contiguous memory region. *)
(** Heaps have to be initialised using the HeapManager.Initialize procedure before they are available for memory allocations. *)
(* A heap is structured into a buddy system of memory blocks of various sizes. *)
(* It maintains a free list for each different size of blocks. *)
TYPE Heap* = RECORD
	free: ARRAY SIZE OF ADDRESS * 8 OF RECORD first {UNTRACED}, pooled {UNTRACED}: Block END;
	begin, end: ADDRESS; sentinel := 0: SIZE;
END;

VAR processors: ARRAY Processors.Maximum OF RECORD hazard {UNTRACED}: Block; dummy {ALIGNED (CPU.CacheLineSize)} : RECORD END END;

(* Computes the index of a block that has the given size. *)
PROCEDURE GetIndex (size: SIZE): SIZE;
VAR result := 0: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	size := (size - 1) DIV BlockSize;
	WHILE size # 0 DO INC (result); size := size DIV 2 END;
	RETURN result;
END GetIndex;

(** Initializes a heap that manages the memory region encompassed by the specified address range. *)
(** The memory area must be owned by the caller and may not overlap with other heaps. *)
(** This procedure must be called once before memory can be allocated from the corresponding heap. *)
PROCEDURE Initialize- (VAR heap: Heap; begin, end: ADDRESS);
VAR index: SIZE; next: ADDRESS; first {UNTRACED}: Block;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid arguments *)
	ASSERT (begin # NIL);
	ASSERT (end >= begin + BlockSize);

	(* setup heap size and align memory region *)
	begin := begin + (BlockSize - (begin + SIZE OF ADDRESS) MOD BlockSize) MOD BlockSize;
	end := begin + (end - begin) DIV BlockSize * BlockSize; heap.begin := begin; heap.end := end;

	(* setup all blocks and map the memory range as unallocated *)
	heap.sentinel := GetIndex (end - begin + BlockSize); index := heap.sentinel - 1;
	REPEAT
		LOOP
			next := begin + ASH (BlockSize, index);
			IF next <= end THEN EXIT END;
			DEC (index); heap.free[index].first := NIL;
		END;
		first := begin; first.next := heap.free[index].first;
		heap.free[index].first := first; begin := next;
	UNTIL begin = end;
	WHILE index # 0 DO DEC (index); heap.free[index].first := NIL END;
	REPEAT heap.free[index].pooled := NIL; INC (index) UNTIL index = heap.sentinel;
END Initialize;

PROCEDURE Access (VAR first {UNTRACED}: Block): {UNTRACED} Block;
VAR index: SIZE; value {UNTRACED}: Block;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	value := CAS (first, NIL, NIL);
	index := Processors.GetCurrentIndex ();
	REPEAT
		processors[index].hazard := value;
		value := CAS (first, NIL, NIL);
	UNTIL processors[index].hazard = value;
	RETURN value;
END Access;

PROCEDURE Discard;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	processors[Processors.GetCurrentIndex ()].hazard := NIL;
END Discard;

PROCEDURE IsHazardous (block {UNTRACED}: Block): BOOLEAN;
VAR index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR index := 0 TO Processors.Maximum - 1 DO
		IF block = processors[index].hazard THEN RETURN TRUE END;
	END;
	RETURN FALSE;
END IsHazardous;

PROCEDURE Pool (block {UNTRACED}: Block; index: SIZE; VAR heap: Heap);
VAR pooled {UNTRACED}: Block;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		pooled := CAS (heap.free[index].pooled, NIL, NIL); block.next := pooled;
		IF CAS (heap.free[index].pooled, pooled, block) = pooled THEN RETURN END;
		CPU.Backoff;
	END;
END Pool;

PROCEDURE Acquire (index: SIZE; VAR heap: Heap): {UNTRACED} Block;
VAR first {UNTRACED}, value {UNTRACED}: Block;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	first := CAS (heap.free[index].pooled, NIL, NIL);
	IF (first # NIL) & (CAS (heap.free[index].pooled, first, NIL) = first) THEN
		REPEAT value := first.next; Release (first, index, heap); first := value UNTIL first = NIL;
	END;
	LOOP
		first := Access (heap.free[index].first);
		IF first = NIL THEN Discard; RETURN NIL END;
		value := CAS (heap.free[index].first, first, first.next);
		Discard; IF value = first THEN EXIT END;
		CPU.Backoff;
	END;
	RETURN first;
END Acquire;

PROCEDURE Release (block {UNTRACED}: Block; index: SIZE; VAR heap: Heap);
VAR size: SIZE; buddy {UNTRACED}, first {UNTRACED}, value {UNTRACED}: Block;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	size := ASH (BlockSize, index);
	LOOP
		IF IsHazardous (block) THEN Pool (block, index, heap); RETURN END;
		LOOP
			first := Access (heap.free[index].first); IF first = NIL THEN Discard; EXIT END;
			IF ODD ((ADDRESS OF block^ - heap.begin) DIV size) THEN buddy := ADDRESS OF block^ - size ELSE buddy := ADDRESS OF block^ + size END;
			IF buddy # first THEN Discard; EXIT END; value := CAS (heap.free[index].first, first, first.next);
			Discard; IF value # first THEN first := value; EXIT END; INC (index); size := size * 2;
			IF ADDRESS OF buddy^ < ADDRESS OF block^ THEN block := buddy; IF IsHazardous (block) THEN Pool (block, index, heap); RETURN END END;
		END;
		block.next := first;
		IF CAS (heap.free[index].first, first, block) = first THEN EXIT END;
		CPU.Backoff;
	END;
END Release;

(** Allocates a block of memory with the requested size from the specified heap. *)
(** The return value is the first address of the allocated memory, or NIL if the heap as no more free memory. *)
PROCEDURE Allocate- (size: SIZE; VAR heap: Heap): ADDRESS;
VAR index, current: SIZE; result: ADDRESS; block {UNTRACED}: Block;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid arguments *)
	ASSERT (size # 0);
	ASSERT (heap.sentinel # 0);
	index := GetIndex (size + SIZE OF ADDRESS);
	IF index >= heap.sentinel THEN RETURN NIL END;
	current := index; size := ASH (BlockSize, index);
	LOOP
		result := Acquire (current, heap);
		IF result # NIL THEN EXIT END;
		INC (current); size := size * 2;
		IF current = heap.sentinel THEN RETURN NIL END;
	END;
	WHILE current # index DO
		DEC (current); size := size DIV 2;
		Release (result + size, current, heap);
	END;
	block := result; block.index := index;
	RETURN result + SIZE OF ADDRESS;
END Allocate;

(** Deallocates a memory block that was previously allocated using a call to the HeapManager.Allocate procedure. *)
PROCEDURE Deallocate- (address: ADDRESS; VAR heap: Heap);
VAR block {UNTRACED}: Block; index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (heap.sentinel # 0);
	ASSERT (IsValid (address, heap));
	block := address - SIZE OF ADDRESS; index := block.index;
	ASSERT (index < heap.sentinel);
	Release (block, index, heap);
END Deallocate;

(** Checks whether an address is a valid heap address. *)
PROCEDURE IsValid- (address: ADDRESS; CONST heap: Heap): BOOLEAN;
BEGIN {UNCOOPERATIVE, UNCHECKED} RETURN (address >= heap.begin + SIZE OF ADDRESS) & (address < heap.end) & ((address MOD BlockSize) = 0);
END IsValid;

(** Returns the size of an allocated block of memory. *)
PROCEDURE GetSize- (address: ADDRESS; CONST heap: Heap): SIZE;
VAR block {UNTRACED}: Block; index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (heap.sentinel # 0);
	ASSERT (IsValid (address, heap));
	block := address - SIZE OF ADDRESS; index := block.index;
	ASSERT (index < heap.sentinel);
	RETURN ASH (BlockSize, index);
END GetSize;

END HeapManager.
