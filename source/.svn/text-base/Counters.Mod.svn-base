(* Atomic counters *)
(* Copyright (C) Florian Negele *)

(** Provides a counter type with the following atomic operations. *)
MODULE Counters;

IMPORT CPU;

(** Represents an atomic counter. *)
TYPE Counter* = RECORD value := 0: SIZE END;

(** Represents an atomic counter aligned for optimal cache behavior. *)
TYPE AlignedCounter* = RECORD (Counter) dummy {ALIGNED (CPU.CacheLineSize)} : RECORD END END;

(** Returns the current value of an atomic counter. *)
PROCEDURE Read- (VAR counter: Counter): SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED} RETURN CAS (counter.value, 0, 0);
END Read;

(** Atomically increments the value of an atomic counter by the specified amount and returns its previous value. *)
PROCEDURE Increment- (VAR counter: Counter; amount: SIZE): SIZE;
VAR value: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		value := CAS (counter.value, 0, 0);
		IF CAS (counter.value, value, value + amount) = value THEN EXIT END;
		CPU.Backoff;
	END;
	RETURN value;
END Increment;

(** Atomically decrements the value of an atomic counter by the specified amount and returns either its previous value or zero if the counter cannot be decremented. *)
PROCEDURE Decrement- (VAR counter: Counter; amount: SIZE): SIZE;
VAR value: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		value := CAS (counter.value, 0, 0);
		IF value < amount THEN EXIT END;
		IF CAS (counter.value, value, value - amount) = value THEN EXIT END;
		CPU.Backoff;
	END;
	RETURN value;
END Decrement;

(** Atomically increments the value of an atomic counter. *)
PROCEDURE Inc- (VAR counter: Counter);
VAR value: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		value := CAS (counter.value, 0, 0);
		ASSERT (value # MAX (SIZE));
		IF CAS (counter.value, value, value + 1) = value THEN EXIT END;
		CPU.Backoff;
	END;
END Inc;

(** Atomically decrements the value of an atomic counter. *)
PROCEDURE Dec- (VAR counter: Counter);
VAR value: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	LOOP
		value := CAS (counter.value, 0, 0);
		ASSERT (value # MIN (SIZE));
		IF CAS (counter.value, value, value - 1) = value THEN EXIT END;
		CPU.Backoff;
	END;
END Dec;

END Counters.
