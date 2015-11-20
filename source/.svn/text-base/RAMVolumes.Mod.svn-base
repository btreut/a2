(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE RAMVolumes; (** AUTHOR "pjm"; PURPOSE "RAM-based volume"; *)

(* AosFS.Volume implementation in ram. *)

IMPORT SYSTEM, Files;

CONST
	DirMark = LONGINT(9B1EA38DH);	(* for NatFS and AosFS *)

TYPE
	Volume* = OBJECT (Files.Volume)
		VAR
			data: POINTER TO ARRAY OF POINTER TO ARRAY OF CHAR;

		(** Get block from adr [1..size] of volume vol *)
		PROCEDURE GetBlock*(adr: LONGINT; VAR blk: ARRAY OF CHAR);
		VAR i: LONGINT;
		BEGIN
			IF (adr < 1) OR (adr > size) THEN SYSTEM.HALT(15) END;
			ASSERT(LEN(blk) >= blockSize);	(* index check *)
			IF data[adr-1] # NIL THEN
				SYSTEM.MOVE(ADDRESSOF(data[adr-1]^[0]), ADDRESSOF(blk[0]), blockSize)
			ELSE
				FOR i := 0 TO blockSize-1 DO blk[i] := 0X END
			END
		END GetBlock;

		(** Put block to adr [1..size] of volume vol *)
		PROCEDURE PutBlock*(adr: LONGINT; VAR blk: ARRAY OF CHAR);
		BEGIN
			IF (adr < 1) OR (adr > size) THEN SYSTEM.HALT(15) END;
			ASSERT(LEN(blk) >= blockSize);	(* index check *)
			IF data[adr-1] = NIL THEN NEW(data[adr-1], blockSize) END;
			SYSTEM.MOVE(ADDRESSOF(blk[0]), ADDRESSOF(data[adr-1]^[0]), blockSize)
		END PutBlock;

		PROCEDURE Finalize*;
		BEGIN
			data := NIL;
			Finalize^	(* see note in Files *)
		END Finalize;

	END Volume;

VAR
	count: LONGINT;

PROCEDURE GetCount(): LONGINT;
BEGIN {EXCLUSIVE}
	INC(count); RETURN count
END GetCount;

(** Generate a new ram volume object. Files.Par: size blocksize .  If size < 0, use as percentage of free memory. *)
PROCEDURE New*(context : Files.Parameters);
VAR vol: Volume; size, vbs : LONGINT;
BEGIN
	context.vol := NIL;
	IF context.arg.GetInteger(size, FALSE) & context.arg.GetInteger(vbs, FALSE) & (size # 0) & (vbs > 0) THEN
		NEW(vol); NEW(vol.data, size);
		NEW(vol.data[0], vbs);	(* hack: pre-format with empty AosFS *)
		SYSTEM.PUT32(ADDRESSOF(vol.data[0]^[0]), DirMark);
		vol.name := "RAM"; Files.AppendInt(GetCount(), vol.name);
		vol.blockSize := vbs;
		vol.Init({}, size, 0);
		context.vol := vol;
	ELSE
		context.error.String("RAMVolumes: bad parameters"); context.error.Ln;
	END;
END New;

(*
(* Clean up when module freed. *)
PROCEDURE Cleanup;
VAR fs: Files.FileSystem;
BEGIN
	IF Modules.shutdown = Modules.None THEN
		REPEAT	(* unmount all file systems using our volume *)
			fs := Files.First();	(* look for fs to unmount *)
			WHILE (fs # NIL) & ((fs.vol = NIL) OR ~(fs.vol IS Volume)) DO
				fs := Files.Next(fs)
			END;
			IF fs # NIL THEN Files.Remove(fs) END
		UNTIL fs = NIL
	END
END Cleanup;
*)

BEGIN
	count := -1
END RAMVolumes.
