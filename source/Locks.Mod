MODULE Locks;	(** AUTHOR "TF"; PURPOSE "Highlevel locks (recursive, reader writer)"; *)

IMPORT
	SYSTEM, KernelLog, Objects, Streams, Reflection, Kernel;

CONST
	Statistics = TRUE;

TYPE

	(** Non-reentrant lock *)
	Lock* = OBJECT
	VAR
		lockedBy : ANY;

		PROCEDURE &New*;
		BEGIN
			lockedBy := NIL;
		END New;

		PROCEDURE Acquire*;
		VAR me : ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			ASSERT(lockedBy # me, 3005);
			AWAIT(lockedBy = NIL);
			lockedBy := me;
		END Acquire;

		PROCEDURE Release*;
		BEGIN {EXCLUSIVE}
			ASSERT(HasLock(), 3010);
			lockedBy := NIL;
		END Release;

		PROCEDURE HasLock*() : BOOLEAN;
		BEGIN
			RETURN lockedBy = Objects.ActiveObject();
		END HasLock;

	END Lock;

TYPE

	(** Implements a recursive lock *)
	RecursiveLock* = OBJECT
	VAR
		lockLevel : LONGINT;
		lockedBy : ANY;

		PROCEDURE &New*;
		BEGIN
			lockLevel := 0; lockedBy := NIL
		END New;

		(** acquire a lock on the object *)
		PROCEDURE Acquire*;
		VAR me : ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			IF lockedBy = me THEN
				ASSERT(lockLevel # -1, 3015); (* overflow *)
				INC(lockLevel);
			ELSE
				AWAIT(lockedBy = NIL);
				lockedBy := me; lockLevel := 1
			END;
		END Acquire;

		(** release the read/write lock on the object *)
		(** MUST hold lock *)
		PROCEDURE Release*;
		BEGIN {EXCLUSIVE}
			ASSERT(HasLock(), 3010);
			DEC(lockLevel);
			IF lockLevel = 0 THEN lockedBy := NIL END
		END Release;

		PROCEDURE HasLock*() : BOOLEAN;
		BEGIN
			RETURN lockedBy = Objects.ActiveObject();
		END HasLock;

	END RecursiveLock;

TYPE

	(** Reader/Writer Lock *)
	LockReleasedHandler* = PROCEDURE {DELEGATE} ;

	ReaderLockInfo = RECORD
		owner : ANY;
		lockLevel : LONGINT
	END;

	ReaderLockList = POINTER TO ARRAY OF ReaderLockInfo;

	(** Implements a Reader/Writer lock that can be taken by many readers at the same time, as long as no
	writer lock was taken. Only one writer lock is possible at one time. (MREW = Multi Read, Exclusive Write)
	Writers can starve. Possible remedies :
		simple : Don't let new readers in if a writer made an acquire.
		more complicated: Q all acquires and handle in order (optimizing readers)
		Readers trying to get a Writer lock result in a trap. Currently no upgrade.
	*)
	RWLock* = OBJECT
	VAR
		lockLevel : LONGINT;
		lockedBy : ANY; (* writer *)
		lastReader : ANY;
		nofReaders : LONGINT;
		readers : ReaderLockList;
		wlReleaseHandler : LockReleasedHandler;
		DEADLOCK : BOOLEAN;
		nofReadLocks, nofWriteLocks : LONGINT; (* statistics *)

		PROCEDURE &New*;
		BEGIN
			lockLevel := 0; lockedBy := NIL; lastReader := NIL;
			nofReaders := 0; NEW(readers, 4);
			wlReleaseHandler := NIL;
			DEADLOCK := FALSE;
			nofReadLocks := 0; nofWriteLocks := 0;
			RegisterLock(SELF);
		END New;

		(** acquire a write-lock on the object *)
		PROCEDURE AcquireWrite*;
		VAR me : ANY;
		BEGIN
			IF Statistics THEN INC(nofWriteLocks); END;
			me := Objects.ActiveObject();
			IF lockedBy = me THEN (* recursive use *)
				INC(lockLevel);
				ASSERT(lockLevel # -1, 3015)	(* overflow *)
			ELSE
				BEGIN {EXCLUSIVE}
					(* wait until no other writer and no reader has the lock *)
					ASSERT(~(lockedBy = me), 3020);
					ASSERT(~InternalHasReadLock(), 3021);
					AWAIT(DEADLOCK OR (lockedBy = NIL) & (nofReaders = 0));
					IF DEADLOCK THEN HALT(3099) END;
					lockedBy := me; lockLevel := 1
				END
			END
		END AcquireWrite;

		(** release the write-lock on the object. MUST hold lock *)
		PROCEDURE ReleaseWrite*;
		VAR inform : BOOLEAN;
		BEGIN
			inform := FALSE;
			BEGIN {EXCLUSIVE}
				ASSERT(HasWriteLock(), 3010);
				DEC(lockLevel);
				IF lockLevel = 0 THEN lockedBy := NIL; inform := TRUE END
			END;
			(* inform interested parties *)
			IF inform & (wlReleaseHandler # NIL) THEN wlReleaseHandler END
		END ReleaseWrite;

		(** Make sure, the calling process has this write-lock *)
		PROCEDURE HasWriteLock*(): BOOLEAN;
		BEGIN
			RETURN lockedBy = Objects.ActiveObject()
		END HasWriteLock;

		(** Returns the locklevel of the write lock. [Must hold write lock] *)
		PROCEDURE GetWLockLevel*() : LONGINT;
		BEGIN
			ASSERT(HasWriteLock(), 3000);
			RETURN lockLevel
		END GetWLockLevel;

		PROCEDURE SetLockReleasedHandler*(handler : LockReleasedHandler);
		BEGIN
			wlReleaseHandler := handler
		END SetLockReleasedHandler;

		(** acquire a read-lock on the object *)
		PROCEDURE AcquireRead*;
		VAR me : ANY; i : LONGINT; found : BOOLEAN; t : ReaderLockList;
		BEGIN {EXCLUSIVE}
			IF Statistics THEN INC(nofReadLocks); END;
			me := Objects.ActiveObject();
			AWAIT(DEADLOCK OR (lockedBy = NIL) OR (lockedBy = me));  (* write owner may acquire a read *)
			IF DEADLOCK THEN HALT(3099) END;
			lastReader := me;
			found := FALSE;
			i := 0; WHILE (i < nofReaders) & ~found DO
				IF readers[i].owner = me THEN found := TRUE; INC(readers[i].lockLevel); ASSERT(readers[i].lockLevel # -1, 3015) END;
				INC(i)
			END;
			IF ~found THEN
				IF nofReaders = LEN(readers) THEN
					NEW(t, nofReaders * 2); FOR i := 0 TO nofReaders - 1 DO t[i] := readers[i] END; readers := t;
				END;
				readers[nofReaders].owner := me; readers[nofReaders].lockLevel := 1;
				INC(nofReaders);
			END;
		END AcquireRead;

		(** release the read lock on the object. MUST hold lock *)
		PROCEDURE ReleaseRead*;
		VAR me : ANY; i : LONGINT; found : BOOLEAN;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			found := FALSE;
			i := 0; WHILE (i < nofReaders) & ~found DO
				IF readers[i].owner = me THEN found := TRUE; DEC(readers[i].lockLevel);
					IF readers[i].lockLevel = 0 THEN
						DEC(nofReaders);
						WHILE i < nofReaders DO readers[i] := readers[i + 1]; INC(i) END;
						readers[nofReaders].owner := NIL; (* for GC *)
						lastReader := readers[0].owner
					END;
				END;
				INC(i)
			END;
			ASSERT(found, 3010)
		END ReleaseRead;

		(** Make sure, the calling process has a read lock. A write lock implicitly holds the read lock *)
		PROCEDURE HasReadLock*() : BOOLEAN;
		VAR me : ANY;
		BEGIN
			me := Objects.ActiveObject();
			IF (lockedBy = me) OR (lastReader = me) THEN RETURN TRUE END; (* WriteLock has implicit ReadLock *)
			BEGIN {EXCLUSIVE}
				RETURN InternalHasReadLock()
			END
		END HasReadLock;

		PROCEDURE InternalHasReadLock(): BOOLEAN;
		VAR me : ANY; i : LONGINT;
		BEGIN
			me := Objects.ActiveObject();
			i := 0; WHILE (i < nofReaders) DO
				IF readers[i].owner = me THEN RETURN TRUE END;
				INC(i)
			END;
			RETURN FALSE
		END InternalHasReadLock;

		(** Remove all locks owned by the caller *)
		PROCEDURE Reset*;
		VAR i, j : LONGINT;me : ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			KernelLog.String("!!! LOCK RESET !!!");
			IF lockedBy = me THEN
				FOR i := 0 TO nofReaders - 1 DO readers[i].owner := NIL END; nofReaders := 0;
				lockLevel := 0; lockedBy := NIL;
				KernelLog.String(" --> Removed all locks ");
			ELSIF lockedBy = NIL THEN (* only remove locks owned by the caller *)
				FOR i := 0 TO nofReaders - 1 DO
					IF readers[i].owner = me THEN
						FOR j := i TO nofReaders - 2 DO readers[j] := readers[j+1] END;
						DEC(nofReaders); readers[nofReaders].owner:= NIL;
			    			KernelLog.String(" --> Removed a readlock");
					 END;
				END
			END
		END Reset;

		PROCEDURE SetDeadLock;
		BEGIN {EXCLUSIVE}
			DEADLOCK := TRUE
		END SetDeadLock;

		PROCEDURE WriteLock*;
		VAR w : Streams.Writer; tag: ADDRESS;
		BEGIN
			KernelLog.String("Lock held by : ");
			IF lockedBy = NIL THEN KernelLog.String("nobody")
			ELSE
				KernelLog.String("locked by = "); KernelLog.Address(lockedBy); KernelLog.Ln;
				KernelLog.String("me = "); KernelLog.Address(Objects.ActiveObject()); KernelLog.Ln;
				(*

				Streams.OpenWriter(w, KernelLog.Send);
				SYSTEM.GET (SYSTEM.VAL (ADDRESS, lockedBy) - SIZEOF (ADDRESS), tag);
				Reflection.WriteType(w, tag);
				w.String(" New Acquire by : ");
				SYSTEM.GET (SYSTEM.VAL (ADDRESS, Objects.ActiveObject()) - SIZEOF (ADDRESS), tag);
				Reflection.WriteType(w, tag);
				w.Update
				*)
			END;
			KernelLog.Ln;
		END WriteLock;

		PROCEDURE WriteStats*;
		BEGIN {EXCLUSIVE}
			KernelLog.String("nofReadLocks : "); KernelLog.Int(nofReadLocks, 4); KernelLog.Ln;
			KernelLog.String("nofWriteLocks : "); KernelLog.Int(nofWriteLocks, 4); KernelLog.Ln;
			KernelLog.String("current readers : "); KernelLog.Int(nofReaders, 4); KernelLog.Ln;
			KernelLog.String("current writer : "); IF lockedBy # NIL THEN KernelLog.String(" not NIL") ELSE KernelLog.String("is NIL") END;
		END WriteStats;

	END RWLock;

VAR
	locks : Kernel.FinalizedCollection;

PROCEDURE RegisterLock(x : ANY);
BEGIN
	locks.Add(x, NIL);
END RegisterLock;

PROCEDURE DL(obj: ANY; VAR cont: BOOLEAN);
BEGIN
	obj(RWLock).SetDeadLock; cont := TRUE;
END DL;

PROCEDURE DeadLock*;
BEGIN
	locks.Enumerate(DL);
END DeadLock;

BEGIN
	NEW(locks);
END Locks.


