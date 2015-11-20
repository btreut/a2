(* Generic runtime support *)
(* Copyright (C) Florian Negele *)

MODULE Runtime;

IMPORT SYSTEM, BaseTypes, Trace;

TYPE TrapHandler* = PROCEDURE (number: SIZE);

VAR trapHandler*: TrapHandler;

(* compare strings,
	returns 0 if strings are equal,
	returns +1 if left is lexicographic greater than right,
	returns -1 if left is lexicographics smaller than right
	traps if src or destination is not 0X terminated and comparison is not finished
*)
PROCEDURE CompareString*(CONST left,right: ARRAY OF CHAR): SHORTINT;
VAR i: LONGINT; res: SHORTINT; l,r: CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	i := 0; res := 0;
	LOOP
		l := left[i]; 		(* index check included *)
		r := right[i];		(* index check included *)
		IF (res = 0) THEN
			IF (l > r) THEN
				res := 1; EXIT
			ELSIF (l<r) THEN
				res := -1; EXIT
			ELSIF l=0X THEN
				EXIT
			END;
		END;
		INC(i);
	END;
	RETURN res
END CompareString;

(* copy string from src to dest, emits trap if not 0X terminated or destination too short *)
PROCEDURE CopyString*(VAR dest: ARRAY OF CHAR; CONST src: ARRAY OF CHAR);
VAR i: LONGINT; ch :CHAR; l1,l2: LONGINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	(*
	i := 0;
	REPEAT
		ch := src[i];		(* index check included *)
		dest[i] := ch;	(* index check included *)
		INC(i);
	UNTIL ch=0X;
	*)

	(*! currently implemented: old PACO semantics *)
	l1 := LEN(dest);
	l2 := LEN(src);
	IF l2 < l1 THEN l1 := l2 END;
	SYSTEM.MOVE(ADDRESSOF(src[0]),ADDRESSOF(dest[0]),l1);
	dest[l1-1] := 0X; (* this implies that COPY assumes a string *)
END CopyString;

PROCEDURE EnsureAllocatedStack*(size: SIZE);
VAR i: ADDRESS; temp: ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO size BY 4096 DO
		SYSTEM.GET(ADDRESSOF(i)-i,temp);
		(*
		SYSTEM.PUT(ADDRESSOF(val)-i,0);
		*)
	END;
(*
CODE{SYSTEM.i386}
	MOV EAX, [EBP+size]
	SHR EAX,12 ; divide by 4096
	MOV ECX,-4
start:
	MOV EDX,[EBP+ECX]
	SUB ECX,4096
	TST EAX
	DEC EAX
	JNZ start
*)
END EnsureAllocatedStack;

(** This procedure aborts the program and prints the number of the trap that caused the program to fail. *)
(** The compiler calls this procedure for HALT statements or for unsatisfied ASSERT statements. *)
PROCEDURE {NORETURN} Trap- (number: SIZE);
PROCEDURE Abort EXTERN "Environment.Abort";
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF trapHandler # NIL THEN
		trapHandler (number);
	ELSE
		Trace.Red; Trace.String ("trap: "); Trace.Int (number, 0); Trace.Ln;
		Trace.Default; Trace.StackFrames (1, 8, 20 * SIZE OF ADDRESS);
	 END;
	Abort;
END Trap;

(** This procedure acquires memory and returns the address to the first byte or NIL if the allocation fails. *)
(** The compiler implements all NEW statements with a call to this procedure. *)
PROCEDURE New- (size: SIZE): ADDRESS;
VAR result: ADDRESS; tries: SIZE;
PROCEDURE CollectGarbage EXTERN "GarbageCollector.Collect";
PROCEDURE Allocate EXTERN "Environment.Allocate" (size: SIZE): ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR tries := 1 TO 10 DO
		result := Allocate (size);
		IF result # NIL THEN RETURN result END;
		CollectGarbage;
	END;
	RETURN NIL;
END New;

(** This procedure releases memory that was previously acquired by a call to the [[Runtime.New]] procedure. *)
(** The compiler implements DISPOSE statements on types marked as disposable with a call to this procedure. *)
PROCEDURE Dispose- (VAR pointer {UNTRACED}: BaseTypes.Pointer);
PROCEDURE Deallocate EXTERN "Environment.Deallocate" (address: ADDRESS);
PROCEDURE Watch EXTERN "GarbageCollector.Watch" (pointer {UNTRACED}: BaseTypes.Pointer);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (pointer # NIL);
	IF pointer IS BaseTypes.Object THEN pointer(BaseTypes.Object).Finalize END;
	IF (pointer IS BaseTypes.Pointer) & (pointer(BaseTypes.Pointer).nextWatched = NIL) THEN Watch (pointer(BaseTypes.Pointer));
	ELSE Deallocate (pointer) END; pointer := NIL;
END Dispose;

END Runtime.

Runtime.Obw