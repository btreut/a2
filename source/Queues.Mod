(* Lock-free queues *)
(* Copyright (C) Florian Negele *)

MODULE Queues;

IMPORT CPU, Processors;

CONST First = 0; Last = 0; Next = 1;

TYPE Node = POINTER {DISPOSABLE} TO RECORD next: Node; item: Item END;

(** Represents an abstract element of a queue. *)
TYPE Item* = OBJECT {DISPOSABLE}

	VAR node {UNTRACED} := NIL: Node;

	(** Finalizes the element by disposing any resources associated with it. *)
	PROCEDURE ~Finalize-;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		IF Acquire (node) THEN node.next := NIL; node.item := NIL; DISPOSE (node) END;
	END Finalize;

END Item;

(** Represents a first-in first-out data structure. *)
TYPE Queue* = RECORD first := NIL, last := NIL: Node END;

(** Represents a first-in first-out data structure which is aligned for optimal cache behavior. *)
TYPE AlignedQueue* = RECORD (Queue) dummy {ALIGNED (CPU.CacheLineSize)} : RECORD END END;

VAR processors: ARRAY Processors.Maximum OF RECORD hazard {UNTRACED}, pooled {UNTRACED}: ARRAY 2 OF Node; dummy {ALIGNED (CPU.CacheLineSize)} : RECORD END END;

PROCEDURE Swap (VAR shared {UNTRACED}, node {UNTRACED}: Node);
VAR current {UNTRACED}: Node;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	current := CAS (shared, NIL, NIL);
	IF CAS (shared, current, node) = current THEN node := current END;
END Swap;

PROCEDURE Acquire (VAR node {UNTRACED}: Node): BOOLEAN;
VAR index := 0: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WHILE (node # NIL) & (index # Processors.Maximum) DO
		IF node = processors[index].hazard[First] THEN Swap (processors[index].pooled[First], node); index := 0;
		ELSIF node = processors[index].hazard[Next] THEN Swap (processors[index].pooled[Next], node); index := 0;
		ELSE INC (index) END;
	END;
	RETURN node # NIL;
END Acquire;

PROCEDURE Initialize (VAR queue: Queue; VAR sentinel: Node);
VAR last: Node;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF ~Acquire (sentinel) THEN NEW (sentinel); ASSERT (sentinel # NIL) END;
	last := CAS (queue.last, NIL, sentinel);
	IF last = NIL THEN
		ASSERT (CAS (queue.first, NIL, sentinel) = NIL);
	ELSE
		DISPOSE (sentinel); sentinel := last;
	END;
END Initialize;

PROCEDURE Access (VAR node, reference: Node; pointer: SIZE);
VAR value: Node; index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	index := Processors.GetCurrentIndex ();
	LOOP
		processors[index].hazard[pointer] := node;
		value := CAS (reference, NIL, NIL);
		IF value = node THEN EXIT END;
		node := value;
	END;
END Access;

PROCEDURE Discard (pointer: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED} processors[Processors.GetCurrentIndex ()].hazard[pointer] := NIL;
END Discard;

(** Appends an element at the back of a queue. *)
PROCEDURE Enqueue- (item: Item; VAR queue: Queue);
VAR node {UNTRACED}, last, next: Node;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(* check for valid argument *)
	ASSERT (item # NIL);
	node := item.node; item.node := NIL;

	(* associate a node with the element *)
	IF ~Acquire (node) THEN NEW (node); ASSERT (node # NIL) END;
	node.next := NIL; node.item := item;

	LOOP
		(* associate a sentinel node with the queue *)
		last := CAS (queue.last, NIL, NIL);
		IF last = NIL THEN Initialize (queue, last) END;

		(* update the successor of the last node *)
		Access (last, queue.last, Last);
		next := CAS (last.next, NIL, node);
		IF next = NIL THEN EXIT END;

		(* update the last node since there is a successor *)
		IF CAS (queue.last, last, next) # last THEN CPU.Backoff END;
	END;

	(* update the last node of the queue *)
	ASSERT (CAS (queue.last, last, node) # NIL);
	Discard (Last);
END Enqueue;

(** Removes the first element at the front of a queue and returns it in a variable parameter. *)
(** If there are no elements in the queue, the procedure returns FALSE and sets the variable parameter to NIL. *)
PROCEDURE Dequeue- (VAR item: Item; VAR queue: Queue): BOOLEAN;
VAR first, next, last: Node;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		(* check whether the sentinel node exists *)
		first := CAS (queue.first, NIL, NIL);
		IF first = NIL THEN item := NIL; RETURN FALSE END;

		(* check whether the queue is empty *)
		Access (first, queue.first, First);
		next := CAS (first.next, NIL, NIL);
		Access (next, first.next, Next);
		IF next = NIL THEN item := NIL; Discard (First); Discard (Next); RETURN FALSE END;

		(* ensure queue consistency *)
		last := CAS (queue.last, first, next);
		item := next.item;

		(* update the sentinel node with its successor *)
		IF CAS (queue.first, first, next) = first THEN EXIT END;
		Discard (Next); CPU.Backoff;
	END;

	(* associate the previous sentinel node with the dequeued element *)
	item.node := first; Discard (First); Discard (Next); RETURN TRUE;
END Dequeue;

(** Disposes the elements of a queue. *)
PROCEDURE Dispose- (VAR queue {UNTRACED}: Queue);
VAR node {UNTRACED}, next {UNTRACED}: Node;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	node := queue.first;
	IF node = NIL THEN RETURN END;
	next := node.next; queue.first := NIL; queue.last := NIL;
	node.next := NIL; node.item := NIL; DISPOSE (node);
	WHILE next # NIL DO node := next; next := node.next; DISPOSE (node.item) END;
END Dispose;

(** Terminates the module and disposes all of its resources. *)
(** @topic Runtime Call *)
PROCEDURE Terminate-;
VAR index, pointer: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR index := 0 TO Processors.Maximum - 1 DO
		FOR pointer := First TO Next DO
			ASSERT (processors[index].hazard[pointer] = NIL);
			IF processors[index].pooled[pointer] # NIL THEN DISPOSE (processors[index].pooled[pointer]) END;
		END;
	END;
END Terminate;

END Queues.
