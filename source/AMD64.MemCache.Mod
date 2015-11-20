(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE MemCache; (** AUTHOR "pjm"; PURPOSE "Memory cache control"; *)

IMPORT SYSTEM, Machine;

CONST
		(** cache properties *)
	UC* = 0; WC* = 1; WT* = 4; WP* = 5; WB* = 6;

	PS = 4096;	(* page size in bytes *)
	M = 100000H;	(* 1K, 1M, 1G *)

	Ok = 0;

TYPE
	SetCacheMessage = POINTER TO RECORD (Machine.Message)
		physAdr: ADDRESS; size, type: LONGINT;
		res: ARRAY Machine.MaxCPU OF LONGINT
	END;

(* Return the value of the MTTRcap register. *)

PROCEDURE -GetMTTRcapLow(): SET;
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	MOV ECX, 0FEH	; MTTRcap
	RDMSR
END GetMTTRcapLow;

(*
(* Return the value of the MTTRdefType register. *)

PROCEDURE -GetMTTRdefTypeLow(): SET;
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	XOR RAX, RAX
	MOV ECX, 2FFH	; MTTRdefType
	RDMSR
END GetMTTRdefTypeLow;
*)

(* Return the value of the specified MTTRphysBase register. *)

PROCEDURE -GetMTTRphysBaseLow(n: ADDRESS): SET;
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	XOR RAX, RAX
	POP RCX
	SHL RCX, 1
	ADD RCX, 200H	; MTTRphysBase0
	RDMSR
END GetMTTRphysBaseLow;

(* Return the value of the specified MTTRphysMask register. *)

PROCEDURE -GetMTTRphysMaskLow(n: ADDRESS): SET;
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	XOR RAX, RAX
	POP RCX
	SHL RCX, 1
	ADD RCX, 201H	; MTTRphysMask0
	RDMSR
END GetMTTRphysMaskLow;

(* Set the specified MTTRphysBase register. *)

PROCEDURE -SetMTTRphysBase(n: ADDRESS; high, low: SET);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	POP RAX
	POP RDX
	POP RCX
	SHL RCX, 1
	ADD RCX, 200H	; MTTRphysBase0
	WRMSR
END SetMTTRphysBase;

(* Set the specified MTTRphysMask register. *)

PROCEDURE -SetMTTRphysMask(n: ADDRESS; high, low: SET);
CODE {SYSTEM.AMD64, SYSTEM.Privileged}
	POP RAX
	POP RDX
	POP RCX
	SHL RCX, 1
	ADD RCX, 201H	; MTTRphysMask0
	WRMSR
END SetMTTRphysMask;

(** Set the cache properties of the specified physical memory area on the current processor. {physAdr, size MOD PS = 0}  Must be called from supervisor mode. *)

PROCEDURE LocalSetCacheProperties*(physAdr: ADDRESS; size, type: LONGINT; VAR res: LONGINT);
VAR i, n, f: LONGINT; mask, base: SET; j, k: ADDRESS;
BEGIN
	ASSERT((physAdr MOD PS = 0) & (size MOD PS = 0) & (size # 0));
	IF (physAdr >= M) OR (physAdr < 0) THEN
		k := size; WHILE k > 0 DO k := ASH(k, 1) END;	(* shift highest set bit into bit 31 *)
		IF k = 80000000H THEN	(* only one bit was set => size is power of 2 *)
			IF physAdr MOD size = 0 THEN
				Machine.Acquire(Machine.Memory);	(* hack *)
				IF Machine.MTTR IN Machine.features THEN	(* MTTRs supported *)
					mask := GetMTTRcapLow();
					IF (type # WC) OR (10 IN mask) THEN
						n := SYSTEM.VAL(LONGINT, mask * {0..7});
						i := 0; f := -1; res := Ok;
						WHILE (i # n) & (res = Ok) DO
							mask := GetMTTRphysMaskLow(i);
							IF 11 IN mask THEN	(* entry is valid *)
								mask := mask * {12..MAX(SET)};
								base := GetMTTRphysBaseLow(i) * mask;
								j := physAdr; k := physAdr+size;
								WHILE (j # k) & (SYSTEM.VAL(SET, j) * mask # base) DO INC(j, PS) END;	(* performance! *)
								IF j # k THEN res := 1508 END	(* cache type of region already set *)
							ELSE
								IF f = -1 THEN f := i END	(* first free entry *)
							END;
							INC(i)
						END;
						IF res = Ok THEN
							IF f # -1 THEN
								SetMTTRphysBase(f, {}, SYSTEM.VAL(SET, physAdr) * {12..31} + SYSTEM.VAL(SET, type) * {0..7});
								SetMTTRphysMask(f, {0..3}, (-SYSTEM.VAL(SET, size-1)) * {12..31} + {11})
							ELSE
								res := 1506	(* out of cache control entries *)
							END
						ELSE
							(* skip *)
						END
					ELSE
						res := 1511	(* region type not supported *)
					END
				ELSE
					res := 1505	(* MTTRs not supported *)
				END;
				Machine.Release(Machine.Memory)
			ELSE
				res := 1510	(* region base must be aligned on size *)
			END
		ELSE
			res := 1509	(* region size must be power of 2 *)
		END
	ELSE
		res := 1507	(* implementation restriction - fixed entries not supported *)
	END
END LocalSetCacheProperties;

PROCEDURE HandleSetCacheProperties(id: LONGINT; CONST state: Machine.State; msg: Machine.Message);
BEGIN
	WITH msg: SetCacheMessage DO
		(* to do: page 11-25 *)
		LocalSetCacheProperties(msg.physAdr, msg.size, msg.type, msg.res[id])
	END
END HandleSetCacheProperties;

(** Broadcast a LocalSetCacheProperties operation to all processors. *)

PROCEDURE GlobalSetCacheProperties*(physAdr: ADDRESS; size, type: LONGINT; VAR res: LONGINT);
VAR i: LONGINT; msg: SetCacheMessage;
BEGIN
	NEW(msg); msg.physAdr := physAdr; msg.size := size; msg.type := type;
	FOR i := 0 TO Machine.MaxCPU-1 DO msg.res[i] := 2304 END;	(* default result *)
	Machine.Broadcast(HandleSetCacheProperties, msg, {Machine.Self, Machine.FrontBarrier, Machine.BackBarrier});
	res := 0;
	FOR i := 0 TO Machine.MaxCPU-1 DO
		IF (res = 0) & (msg.res[i] # 0) THEN res := msg.res[i] END	(* return first non-ok result found *)
	END
END GlobalSetCacheProperties;

(** Disable all caching on the current processor. *)

PROCEDURE LocalDisableCaching*;
CODE {SYSTEM.Pentium, SYSTEM.Privileged}
	PUSHFD
	CLI

	MOV EAX, CR0
	OR EAX, 40000000H
	AND EAX, 0DFFFFFFFH
	MOV CR0, EAX

	WBINVD

	MOV EAX, CR4
	AND EAX, 0FFFFFF7FH
	MOV CR4, EAX

	MOV EAX, CR3
	MOV CR3, EAX

	MOV ECX, 2FFH	; MTTRdefType
	MOV EAX, 0
	MOV EDX, 0
	WRMSR

	WBINVD

	MOV EAX, CR3
	MOV CR3, EAX

	MOV EAX, CR0
	OR EAX, 60000000H
	MOV CR0, EAX

	POPFD
END LocalDisableCaching;

PROCEDURE HandleDisableCaching(id: LONGINT; CONST state: Machine.State; msg: Machine.Message);
BEGIN
	LocalDisableCaching
END HandleDisableCaching;

(** Broadcast a LocalDisableCaching operation to all processors. *)

PROCEDURE GlobalDisableCaching*;
BEGIN
	Machine.Broadcast(HandleDisableCaching, NIL, {Machine.Self, Machine.FrontBarrier, Machine.BackBarrier})
END GlobalDisableCaching;

END MemCache.

(*
to do:
o change error codes
*)
