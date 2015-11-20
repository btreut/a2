(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE DiskFS; (** AUTHOR "pjm"; PURPOSE "Aos disk file system"; *)

IMPORT SYSTEM, Machine, KernelLog, Modules, Clock, Files, Kernel;

CONST
	MinVolSize = 4;

	SectorFactor = 29;

	(* WARNING: When the maximum length of filenames is changed, volumes must be re-formatted!!! *)
	FileNameLength = 128; (* includes 0X *)

	SectorTableSize = 128;
	SectorSize = 4096;
	IndexSize = SectorSize DIV 4;
	DiskAdrSize = 4; (* bytes *)

	HeaderSize =  4 (* mark *) + FileNameLength + 4*4 (* aleng, bleng, time, date *) + (SectorTableSize+1)*DiskAdrSize;

	DirEntrySize = FileNameLength + 2*DiskAdrSize (* adr, p *);
	DirPgHeaderSize = 2*4 (* mark, m *) + DiskAdrSize (* p0 *) + 4 (* min. FillerSize *);
	DirPgSize = (SectorSize - DirPgHeaderSize) DIV DirEntrySize;
	FillerSize = (SectorSize - DirPgHeaderSize) MOD DirEntrySize + 4 (* min. FillerSize *);

	DirRootAdr = 1*SectorFactor;
	N = DirPgSize DIV 2;

	DirMark = LONGINT(9B1EA38DH);
	HeaderMark = LONGINT(9BA71D86H);

	MapIndexSize = (SectorSize-4) DIV 4;
	MapSize = SectorSize DIV SIZEOF (SET);	(* {MapSize MOD SIZEOF (SET) = 0} *)
	MapMark = LONGINT(9C2F977FH);

	MaxBufs = 1024;
	InitHint = 200*SectorFactor;

	Closed = 0X; Opening = 1X; Opened = 2X; Closing = 3X;

	SetSize = MAX (SET) + 1;

TYPE
	DiskSector = RECORD END;	(* Oberon Sector, size SectorSize *)
	DiskSectorArr = ARRAY SectorSize OF CHAR;

	DiskAdr = LONGINT;
	FileName = ARRAY FileNameLength OF CHAR;
	SectorTable = ARRAY SectorTableSize OF DiskAdr;

	FileHeader = RECORD (DiskSector)   (* allocated in the first page of each file on disk *)
		mark: LONGINT;
		name: FileName;
		aleng, bleng: LONGINT;
		date, time: LONGINT;
		sec: SectorTable;
		ext: DiskAdr;
		data: ARRAY SectorSize-HeaderSize OF CHAR
	END;

	IndexSector = RECORD (DiskSector)
		x: ARRAY IndexSize OF DiskAdr
	END;

	DataSector = RECORD (DiskSector)
		B: ARRAY SectorSize OF CHAR
	END;

	DirEntry = RECORD	(*B-tree node*)
		name: FileName;
		adr: DiskAdr; (*sec no of file header*)
		p: DiskAdr  (*sec no of descendant in directory*)
	END;

	DirPage = RECORD (DiskSector)
		mark: LONGINT;
		m: LONGINT;
		p0: DiskAdr; (*sec no of left descendant in directory*)
		fill: ARRAY FillerSize OF CHAR;
		e: ARRAY DirPgSize OF DirEntry
	END;

	MapIndex = RECORD (DiskSector)
		mark: LONGINT;
		index: ARRAY MapIndexSize OF DiskAdr
	END;

	MapSector = RECORD (DiskSector)
		map: ARRAY MapSize OF SET
	END;

	Buffer = POINTER TO RECORD (Files.Hint)
		apos, lim: LONGINT;
		mod: BOOLEAN;
		next: Buffer;
		data: DataSector
	END;

	SuperIndex = POINTER TO RECORD
		adr: DiskAdr;
		mod: BOOLEAN;
		sub: ARRAY IndexSize OF SubIndex
	END;

	SubIndex = POINTER TO RECORD
		adr: DiskAdr;
		mod: BOOLEAN;
		sec: IndexSector
	END;

TYPE
	Directory = OBJECT
		VAR
			vol: Files.Volume;
			state: CHAR;
			lastSectorReserved: BOOLEAN;

		(* "exported" methods: Search, Insert, Delete *)

		PROCEDURE Search(VAR name: FileName; VAR A: DiskAdr);
		VAR i, L, R: LONGINT; dadr: DiskAdr; a: DirPage;
		BEGIN {EXCLUSIVE}
			ASSERT(state = Opened);
			dadr := DirRootAdr;
			LOOP
				GetSector(vol, dadr, a);
				ASSERT(a.mark = DirMark);
				L := 0; R := a.m; (*binary search*)
				WHILE L < R DO
					i := (L+R) DIV 2;
					IF name <= a.e[i].name THEN R := i ELSE L := i+1 END
				END ;
				IF (R < a.m) & (name = a.e[R].name) THEN
					A := a.e[R].adr; EXIT (*found*)
				END ;
				IF R = 0 THEN dadr := a.p0 ELSE dadr := a.e[R-1].p END ;
				IF dadr = 0 THEN A := 0; EXIT  (*not found*) END
			END
		END Search;

		PROCEDURE insert(VAR name: FileName; dpg0:  DiskAdr; VAR h: BOOLEAN; VAR v: DirEntry; fad: DiskAdr);
		(*h = "tree has become higher and v is ascending element"*)
		VAR ch: CHAR; i, j, L, R: LONGINT; dpg1: DiskAdr; u: DirEntry; a: DirPage;
		BEGIN (*~h*)
			ASSERT(state = Opened);
			GetSector(vol, dpg0, a);
			L := 0; R := a.m; (*binary search*)
			WHILE L < R DO
				i := (L+R) DIV 2;
				IF name <= a.e[i].name THEN R := i ELSE L := i+1 END
			END ;
			IF (R < a.m) & (name = a.e[R].name) THEN
				a.e[R].adr := fad; PutSector(vol, dpg0, a)  (*replace*)
			ELSE (*not on this page*)
				IF R = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[R-1].p END ;
				IF dpg1 = 0 THEN (*not in tree, insert*)
					u.adr := fad; u.p := 0; h := TRUE; j := 0;
					REPEAT ch := name[j]; u.name[j] := ch; INC(j)
					UNTIL ch = 0X;
					WHILE j < FileNameLength DO u.name[j] := 0X; INC(j) END
				ELSE
					insert(name, dpg1, h, u, fad)
				END ;
				IF h THEN (*insert u to the left of e[R]*)
					IF a.m < DirPgSize THEN
						h := FALSE; i := a.m;
						WHILE i > R DO DEC(i); a.e[i+1] := a.e[i] END ;
						a.e[R] := u; INC(a.m)
					ELSE (*split page and assign the middle element to v*)
						a.m := N; a.mark := DirMark;
						IF R < N THEN (*insert in left half*)
							v := a.e[N-1]; i := N-1;
							WHILE i > R DO DEC(i); a.e[i+1] := a.e[i] END ;
							a.e[R] := u; PutSector(vol, dpg0, a);
							AllocSector(vol, dpg0, dpg0); i := 0;
							WHILE i < N DO a.e[i] := a.e[i+N]; INC(i) END
						ELSE (*insert in right half*)
							PutSector(vol, dpg0, a);
							AllocSector(vol, dpg0, dpg0); DEC(R, N); i := 0;
							IF R = 0 THEN v := u
							ELSE v := a.e[N];
								WHILE i < R-1 DO a.e[i] := a.e[N+1+i]; INC(i) END ;
								a.e[i] := u; INC(i)
							END ;
							WHILE i < N DO a.e[i] := a.e[N+i]; INC(i) END
						END ;
						a.p0 := v.p; v.p := dpg0
					END ;
					PutSector(vol, dpg0, a)
				END
			END
		END insert;

		PROCEDURE Insert(VAR name: FileName; fad: DiskAdr);
		VAR oldroot: DiskAdr; h: BOOLEAN; U: DirEntry; a: DirPage;
		BEGIN {EXCLUSIVE}
			h := FALSE;
			insert(name, DirRootAdr, h, U, fad);
			IF h THEN (*root overflow*)
				GetSector(vol, DirRootAdr, a);
				AllocSector(vol, DirRootAdr, oldroot); PutSector(vol, oldroot, a);
				a.mark := DirMark; a.m := 1; a.p0 := oldroot; a.e[0] := U;
				PutSector(vol, DirRootAdr, a)
			END
		END Insert;

		PROCEDURE underflow(VAR c: DirPage; (*ancestor page*) dpg0:  DiskAdr; s: LONGINT; (*insertion point in c*)
				VAR h: BOOLEAN); (*c undersize*)
		VAR i, k: LONGINT; dpg1: DiskAdr; a, b: DirPage; (*a := underflowing page, b := neighbouring page*)
		BEGIN
			GetSector(vol, dpg0, a);
			(*h & a.m = N-1 & dpg0 = c.e[s-1].p*)
			IF s < c.m THEN (*b := page to the right of a*)
				dpg1 := c.e[s].p; GetSector(vol, dpg1, b);
				k := (b.m-N+1) DIV 2; (*k = no. of items available on page b*)
				a.e[N-1] := c.e[s]; a.e[N-1].p := b.p0;
				IF k > 0 THEN
					(*move k-1 items from b to a, one to c*) i := 0;
					WHILE i < k-1 DO a.e[i+N] := b.e[i]; INC(i) END ;
					c.e[s] := b.e[i]; b.p0 := c.e[s].p;
					c.e[s].p := dpg1; DEC(b.m, k); i := 0;
					WHILE i < b.m DO b.e[i] := b.e[i+k]; INC(i) END ;
					PutSector(vol, dpg1, b); a.m := N-1+k; h := FALSE
				ELSE (*merge pages a and b, discard b*) i := 0;
					WHILE i < N DO a.e[i+N] := b.e[i]; INC(i) END ;
					i := s; DEC(c.m);
					WHILE i < c.m DO c.e[i] := c.e[i+1]; INC(i) END ;
					a.m := 2*N; h := c.m < N;
					FreeSector(vol, dpg1) (* free b *)
				END ;
				PutSector(vol, dpg0, a)
			ELSE (*b := page to the left of a*) DEC(s);
				IF s = 0 THEN dpg1 := c.p0 ELSE dpg1 := c.e[s-1].p END ;
				GetSector(vol, dpg1, b);
				k := (b.m-N+1) DIV 2; (*k = no. of items available on page b*)
				IF k > 0 THEN
					i := N-1;
					WHILE i > 0 DO DEC(i); a.e[i+k] := a.e[i] END ;
					i := k-1; a.e[i] := c.e[s]; a.e[i].p := a.p0;
					(*move k-1 items from b to a, one to c*) DEC(b.m, k);
					WHILE i > 0 DO DEC(i); a.e[i] := b.e[i+b.m+1] END ;
					c.e[s] := b.e[b.m]; a.p0 := c.e[s].p;
					c.e[s].p := dpg0; a.m := N-1+k; h := FALSE;
					PutSector(vol, dpg0, a)
				ELSE (*merge pages a and b, discard a*)
					c.e[s].p := a.p0; b.e[N] := c.e[s]; i := 0;
					WHILE i < N-1 DO b.e[i+N+1] := a.e[i]; INC(i) END ;
					b.m := 2*N; DEC(c.m); h := c.m < N;
					FreeSector(vol, dpg0) (* free a *)
				END ;
				PutSector(vol, dpg1, b)
			END
		END underflow;

		PROCEDURE delete(VAR name: FileName; dpg0: DiskAdr; VAR h: BOOLEAN; VAR fad: DiskAdr);
		(*search and delete entry with key name; if a page underflow arises,
			balance with adjacent page or merge; h := "page dpg0 is undersize"*)
		VAR i, L, R: LONGINT; dpg1: DiskAdr; a: DirPage;

			PROCEDURE del(dpg1: DiskAdr; VAR h: BOOLEAN);
				VAR dpg2: DiskAdr; (*global: a, R*) b: DirPage;
			BEGIN
				GetSector(vol, dpg1, b); dpg2 := b.e[b.m-1].p;
				IF dpg2 # 0 THEN del(dpg2, h);
					IF h THEN underflow(b, dpg2, b.m, h); PutSector(vol, dpg1, b) END
				ELSE
					b.e[b.m-1].p := a.e[R].p; a.e[R] := b.e[b.m-1];
					DEC(b.m); h := b.m < N; PutSector(vol, dpg1, b)
				END
			END del;

		BEGIN (*~h*)
			ASSERT(state = Opened);
			GetSector(vol, dpg0, a);
			L := 0; R := a.m; (*binary search*)
			WHILE L < R DO
				i := (L+R) DIV 2;
				IF name <= a.e[i].name THEN R := i ELSE L := i+1 END
			END ;
			IF R = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[R-1].p END ;
			IF (R < a.m) & (name = a.e[R].name) THEN
				(*found, now delete*) fad := a.e[R].adr;
				IF dpg1 = 0 THEN  (*a is a leaf page*)
					DEC(a.m); h := a.m < N; i := R;
					WHILE i < a.m DO a.e[i] := a.e[i+1]; INC(i) END
				ELSE del(dpg1, h);
					IF h THEN underflow(a, dpg1, R, h) END
				END ;
				PutSector(vol, dpg0, a)
			ELSIF dpg1 # 0 THEN
				delete(name, dpg1, h, fad);
				IF h THEN underflow(a, dpg1, R, h); PutSector(vol, dpg0, a) END
			ELSE (*not in tree*) fad := 0
			END
		END delete;

		PROCEDURE Delete(VAR name: FileName; VAR fad: DiskAdr);
		VAR h: BOOLEAN; newroot: DiskAdr; a: DirPage;
		BEGIN {EXCLUSIVE}
			h := FALSE;
			delete(name, DirRootAdr, h, fad);
			IF h THEN (*root underflow*)
				GetSector(vol, DirRootAdr, a);
				IF (a.m = 0) & (a.p0 # 0) THEN
					newroot := a.p0; GetSector(vol, newroot, a);
					PutSector(vol, DirRootAdr, a); (*discard newroot*)
					FreeSector(vol, newroot)
				END
			END
		END Delete;

		PROCEDURE Startup;
		VAR
			j, sec, size, q, free, thres: LONGINT; mi: MapIndex; ms: MapSector;
			s: ARRAY 10 OF CHAR; found: BOOLEAN;
		BEGIN	(* only called from Init *)
			size := vol.size; found := FALSE;
			IF (vol.Available() = size) & (size # 0) THEN	(* all sectors available *)
				GetSector(vol, size*SectorFactor, mi);
				IF mi.mark = MapMark THEN
					j := 0;	(* check consistency of index *)
					WHILE (j # MapIndexSize) & (mi.index[j] >= 0) & (mi.index[j] MOD SectorFactor = 0) DO
						INC(j)
					END;
					IF j = MapIndexSize THEN
						found := TRUE;
						mi.mark := 0; PutSector(vol, size*SectorFactor, mi);	(* invalidate index *)
						j := 0; sec := 1; q := 0;
						LOOP
							IF (j = MapIndexSize) OR (mi.index[j] = 0) THEN EXIT END;
							GetSector(vol, mi.index[j], ms);
							REPEAT
								IF (sec MOD SetSize) IN ms.map[sec DIV SetSize MOD MapSize] THEN
									MarkSector(vol, sec*SectorFactor);
									INC(q)
								END;
								IF sec = size THEN EXIT END;
								INC(sec)
							UNTIL sec MOD (MapSize*SetSize) = 0;
							INC(j)
						END;
						Machine.GetConfig("DiskGC", s);
						thres := 0; j := 0;
						WHILE s[j] # 0X DO thres := thres*10+(ORD(s[j])-48); INC(j) END;
						IF thres < 10 THEN thres := 10
						ELSIF thres > 100 THEN thres := 100
						END;
						ASSERT(q = size-vol.Available());
						free := vol.Available()*100 DIV size;
						IF (free > thres) & (vol.Available() > 100000H DIV SectorSize) THEN
							state := Opened
						ELSE	(* undo *)
							FOR j := SectorFactor TO size*SectorFactor BY SectorFactor DO
								IF Marked(vol, j) THEN FreeSector(vol, j) END
							END;
							ASSERT(vol.Available() = size);
							KernelLog.String("DiskFS: "); KernelLog.Int(free, 1);
							KernelLog.String("% free, forcing disk GC on ");
							KernelLog.String(vol.name); KernelLog.Ln
						END
					END
				END;
				IF ~found THEN
					KernelLog.String("DiskFS: Index not found on ");
					KernelLog.String(vol.name); KernelLog.Ln
				END
			END
		END Startup;

		PROCEDURE &Init*(vol: Files.Volume);
		VAR k: LONGINT; A: ARRAY 2000 OF DiskAdr; files: LONGINT; bad: BOOLEAN;

			PROCEDURE MarkSectors;
			VAR L, R, i, j, n: LONGINT; x: DiskAdr; hd: FileHeader; sup, sub: IndexSector;

				PROCEDURE sift(L, R: LONGINT);
					VAR i, j: LONGINT; x: DiskAdr;
				BEGIN j := L; x := A[j];
					LOOP i := j; j := 2*j + 1;
						IF (j+1 < R) & (A[j] < A[j+1]) THEN INC(j) END ;
						IF (j >= R) OR (x > A[j]) THEN EXIT END ;
						A[i] := A[j]
					END ;
					A[i] := x
				END sift;

			BEGIN
				KernelLog.String(" marking");
				L := k DIV 2; R := k; (*heapsort*)
				WHILE L > 0 DO DEC(L); sift(L, R) END ;
				WHILE R > 0 DO
					DEC(R); x := A[0]; A[0] := A[R]; A[R] := x; sift(L, R)
				END;
				WHILE L < k DO
					bad := FALSE; INC(files);
					IF files MOD 128 = 0 THEN KernelLog.Char(".") END;
					GetSector(vol, A[L], hd);
					IF hd.aleng < SectorTableSize THEN
						j := hd.aleng + 1;
						REPEAT
							DEC(j);
							IF hd.sec[j] # 0 THEN MarkSector(vol, hd.sec[j]) ELSE hd.aleng := j-1; bad := TRUE END
						UNTIL j = 0
					ELSE
						j := SectorTableSize;
						REPEAT
							DEC(j);
							IF hd.sec[j] # 0 THEN MarkSector(vol, hd.sec[j]) ELSE hd.aleng := j-1; bad := TRUE END
						UNTIL j = 0;
						IF hd.ext = 0 THEN hd.aleng := SectorTableSize-1; bad := TRUE END;
						IF ~bad THEN
							MarkSector(vol, hd.ext); GetSector(vol, hd.ext, sup);
							n := (hd.aleng - SectorTableSize) DIV IndexSize; i := 0;
							WHILE (i <= n) & ~bad DO
								IF sup.x[i] # 0 THEN
									MarkSector(vol, sup.x[i]); GetSector(vol, sup.x[i], sub);
									IF i < n THEN j := IndexSize
									ELSE j := (hd.aleng - SectorTableSize) MOD IndexSize + 1
									END;
									REPEAT
										DEC(j);
										IF (sub.x[j] MOD SectorFactor = 0) & (sub.x[j] > 0) THEN
											MarkSector(vol, sub.x[j])
										ELSE
											bad := TRUE
										END
									UNTIL j = 0;
									INC(i)
								ELSE bad := TRUE
								END;
								IF bad THEN
									IF i = 0 THEN hd.aleng := SectorTableSize-1
									ELSE hd.aleng := SectorTableSize + (i-1) * IndexSize
									END
								END
							END
						END
					END;
					IF bad THEN
						KernelLog.Ln; KernelLog.String(hd.name); KernelLog.String(" truncated");
						hd.bleng := SectorSize; IF hd.aleng < 0 THEN hd.aleng := 0 (* really bad *) END;
						PutSector(vol, A[L], hd)
					END;
					INC(L)
				END
			END MarkSectors;

			PROCEDURE TraverseDir(dpg: DiskAdr);
				VAR i: LONGINT; a: DirPage;
			BEGIN
				GetSector(vol, dpg, a); MarkSector(vol, dpg); i := 0;
				WHILE i < a.m DO
					A[k] := a.e[i].adr;
(*
					IF A[k] = 0DEADDEADH THEN
						KernelLog.Enter; KernelLog.Int(dpg DIV SectorFactor, 1); KernelLog.Char(" "); KernelLog.Int(k, 1); KernelLog.Exit
					END;
*)
					INC(k); INC(i);
					IF k = 2000 THEN MarkSectors; k := 0 END
				END ;
				IF a.p0 # 0 THEN
					TraverseDir(a.p0); i := 0;
					WHILE i < a.m DO
						TraverseDir(a.e[i].p); INC(i)
					END
				END
			END TraverseDir;

		BEGIN
			SELF.vol := vol; lastSectorReserved := FALSE;
			IF ~(Files.ReadOnly IN vol.flags) THEN
				state := Opening; k := 0;
				Startup;
				IF state # Opened THEN
					files := 0; KernelLog.String("DiskFS: Scanning ");
					KernelLog.String(vol.name); KernelLog.String("...");
					TraverseDir(DirRootAdr);
					MarkSectors;
					KernelLog.Int(files, 6); KernelLog.String(" files"); KernelLog.Ln;
					state := Opened
				END;
				IF ~Marked(vol, vol.size*SectorFactor) THEN	(* last sector still free *)
					MarkSector(vol, vol.size*SectorFactor); lastSectorReserved := TRUE	(* allocate it *)
				END;
				KernelLog.String("DiskFS: "); KernelLog.Int(vol.Available() * (SectorSize DIV 1024), 1);
				KernelLog.String("K of "); KernelLog.Int(vol.size * (SectorSize DIV 1024), 1);
				KernelLog.String("K available on "); KernelLog.String(vol.name);
				KernelLog.Ln
			ELSE
				state := Opened
			END
		END Init;

		PROCEDURE Cleanup;
		VAR i, j, p, q, sec, size: LONGINT; mi: MapIndex; ms: MapSector;
		BEGIN {EXCLUSIVE}
			(*KernelLog.String("DiskFS: Cleanup "); KernelLog.String(vol.name); KernelLog.Ln;*)
			state := Closing;
			size := vol.size; i := size*SectorFactor;
			IF ~(Files.ReadOnly IN vol.flags) THEN
				IF lastSectorReserved THEN FreeSector(vol, i); lastSectorReserved := FALSE END;
				IF ~Marked(vol, i) THEN	(* last sector is available for us *)
					j := 0; sec := 1; q := 0;
					LOOP
						REPEAT DEC(i, SectorFactor) UNTIL (i = 0) OR ~Marked(vol, i);	(* find a free sector *)
						IF i = 0 THEN RETURN END;	(* no more space, don't commit *)
						mi.index[j] := i; INC(j);
						FOR p := 0 TO MapSize-1 DO ms.map[p] := {} END;
						REPEAT
							IF Marked(vol, sec*SectorFactor) THEN
								INCL(ms.map[sec DIV SetSize MOD MapSize], sec MOD SetSize);
								INC(q)
							END;
							IF sec = size THEN
								PutSector(vol, i, ms);
								EXIT
							END;
							INC(sec)
						UNTIL sec MOD (MapSize*SetSize) = 0;
						PutSector(vol, i, ms)
					END;
					WHILE j # MapIndexSize DO mi.index[j] := 0; INC(j) END;
					mi.mark := MapMark;
					PutSector(vol, size*SectorFactor, mi);	(* commit *)
					KernelLog.String("DiskFS: Map saved on ");
					KernelLog.String(vol.name); KernelLog.Ln
				(*ELSE
					KernelLog.String("DiskFS: sector in use "); KernelLog.Int(size, 1); KernelLog.Ln*)
				END
			(*ELSE
				KernelLog.String("DiskFS: Read-only"); KernelLog.Ln*)
			END;
			state := Closed; vol := NIL
		END Cleanup;

	END Directory;

TYPE
	FileSystem = OBJECT (Files.FileSystem)	(* our file system type *)
		VAR
			dir: Directory;
			finalizeFiles: Kernel.FinalizedCollection;
			openFiles: DiskAdrList;
				(* all files that are registered, must be stored separately of finalizeFiles because of race
					between Delete0/Rename0 and deferred execution of file close finalizer *)
			tempRegFileSec: DiskAdrList; (* temporary used for PurgeOpenedFile *)

		PROCEDURE &Init*;
		BEGIN NEW(finalizeFiles); NEW(openFiles); NEW(tempRegFileSec)
		END Init;

		PROCEDURE New0(name: ARRAY OF CHAR): Files.File;
		VAR i, res: LONGINT; f: File; buf: Buffer; head {UNTRACED}: POINTER {UNSAFE} TO FileHeader; namebuf: FileName;
		BEGIN {EXCLUSIVE}
			f := NIL; Check(name, namebuf, res);
			IF res <= 0 THEN
				NEW(buf); buf.apos := 0; buf.mod := TRUE; buf.lim := HeaderSize; buf.next := buf;
				head := ADDRESSOF(buf.data);
				head.mark := HeaderMark;
				head.aleng := 0; head.bleng := HeaderSize; head.name := namebuf;
				Clock.Get(head.time, head.date);
				NEW(f); f.fs := SELF; f.key := 0; f.aleng := 0; f.bleng := HeaderSize; f.modH := TRUE;
				f.time := head.time; f.date := head.date;
				f.firstbuf := buf; f.nofbufs := 1; f.name := namebuf; f.sechint := InitHint;
				f.registered := (f.name[0] = 0X);
				f.ext := NIL; i := 0;
				REPEAT f.sec[i] := 0; head.sec[i] := 0; INC(i) UNTIL i = SectorTableSize;
				finalizeFiles.Add(f, Collect);
			ELSE
				KernelLog.String("DiskFS: "); KernelLog.String(name); KernelLog.String(", res: "); KernelLog.Int(res, 0); KernelLog.Ln;
			END;
			RETURN f
		END New0;

		PROCEDURE Old0(name: ARRAY OF CHAR): Files.File;
		VAR
			i, k, res: LONGINT; f: File; header: DiskAdr; buf: Buffer; head {UNTRACED}: POINTER {UNSAFE} TO FileHeader;
			namebuf: FileName; super: SuperIndex; sub: SubIndex; sec: IndexSector;
		BEGIN {EXCLUSIVE}
			f := NIL; Check(name, namebuf, res);
			IF res = 0 THEN
				dir.Search(namebuf, header);
				IF header # 0 THEN
					NEW(buf); buf.apos := 0; buf.next := buf; buf.mod := FALSE;

					GetSector(vol, header, buf.data);
					head := ADDRESSOF(buf.data);

					NEW(f); f.fs := SELF; f.key := header;
					f.aleng := head.aleng; f.bleng := head.bleng;
					f.time := head.time; f.date := head.date;
					IF f.aleng = 0 THEN buf.lim := f.bleng ELSE buf.lim := SectorSize END;
					f.firstbuf := buf; f.nofbufs := 1;
					f.name := namebuf; f.registered := TRUE;
					f.sec := head.sec;
					k := (f.aleng + (IndexSize-SectorTableSize)) DIV IndexSize;
					IF k # 0 THEN
						NEW(super); super.adr := head.ext; super.mod := FALSE; f.ext := super;
						GetSector(vol, super.adr, sec); i := 0;
						WHILE i # k DO
							NEW(sub); sub.adr := sec.x[i]; sub.mod := FALSE; super.sub[i] := sub;
							GetSector(vol, sub.adr, sub.sec); INC(i)
						END;
						WHILE i # IndexSize DO super.sub[i] := NIL; INC(i) END
					ELSE
						f.ext := NIL
					END;
					f.sechint := header; f.modH := FALSE;
					finalizeFiles.Add(f, Collect); openFiles.Add(f.key)
				END
			END;
			RETURN f
		END Old0;

		PROCEDURE Delete0(name: ARRAY OF CHAR; VAR key, res: LONGINT);
		VAR adr: DiskAdr; namebuf: FileName; head: FileHeader;
		BEGIN {EXCLUSIVE}
			Check(name, namebuf, res);
			IF res = 0 THEN
				dir.Delete(namebuf, adr);
				key := adr;
				IF adr # 0 THEN
					IF ~openFiles.Contains(adr) THEN
						PurgeByAdr(adr)
					ELSE
						GetSector(vol, adr, head);
						head.mark := HeaderMark+1;	(* invalidate mark *)
						PutSector(vol, adr, head)
					END
				ELSE
					res := 2
				END
			ELSE
				key := 0
			END
		END Delete0;

		PROCEDURE Rename0(old, new: ARRAY OF CHAR; f: Files.File; VAR res: LONGINT);
		VAR adr, newAdr: DiskAdr; oldbuf, newbuf: FileName;  head: FileHeader;
		BEGIN {EXCLUSIVE}
			Check(old, oldbuf, res);
			IF res = 0 THEN
				Check(new, newbuf, res);
				IF res = 0 THEN
					dir.Delete(oldbuf, adr);
					IF adr # 0 THEN
						dir.Search(newbuf, newAdr); ASSERT(adr # newAdr);
						IF (newAdr # 0) & ~openFiles.Contains(newAdr) THEN
							PurgeByAdr(newAdr)
						END;
						IF f # NIL THEN	(* file is open *)
							ASSERT(f.key = adr);	(* it's key must match *)
							f(File).name := newbuf
						END;
						dir.Insert(newbuf, adr);
						GetSector(vol, adr, head);
						head.name := newbuf;
						PutSector(vol, adr, head)
					ELSE res := 2
					END
				END
			END
		END Rename0;

		PROCEDURE Enumerate0(mask: ARRAY OF CHAR; flags: SET; enum: Files.Enumerator);
		VAR b: BOOLEAN; fh: FileHeader; fn: ARRAY Files.PrefixLength+FileNameLength OF CHAR;
		BEGIN {EXCLUSIVE}
			b := TRUE; enumerate(SELF, mask, DirRootAdr, flags, enum, b, fh, fn)
		END Enumerate0;

		PROCEDURE FileKey(name: ARRAY OF CHAR): LONGINT;
			VAR res: LONGINT; namebuf: FileName; header: DiskAdr;
		BEGIN {EXCLUSIVE}
			header := 0;
			Check(name, namebuf, res);
			IF res = 0 THEN
				dir.Search(namebuf, header)
			END;
			RETURN header
		END FileKey;

		(* exlcusive lock must be acquired, result in tempRegFileSec *)
		PROCEDURE CollectRegisteredFileSectors(adr: DiskAdr);
		VAR hd: FileHeader; i, p, m, n: LONGINT; super, sub: IndexSector;
		BEGIN
			tempRegFileSec.Clear;
			GetSector(vol, adr, hd);
			tempRegFileSec.Add(adr);
			ASSERT(hd.sec[0] = adr);
			IF hd.aleng < SectorTableSize THEN m := hd.aleng + 1 ELSE m := SectorTableSize END; p := 1;
			WHILE p < m DO
				IF hd.sec[p] # 0 THEN tempRegFileSec.Add(hd.sec[p]) END;
				INC(p)
			END;
			IF (hd.aleng >= SectorTableSize) & (hd.ext # 0) THEN
				GetSector(vol, hd.ext, super); tempRegFileSec.Add(hd.ext);
				n := (hd.aleng - SectorTableSize) DIV IndexSize; i := 0;
				WHILE i <= n DO
					IF super.x[i] # 0 THEN
						GetSector(vol, super.x[i], sub); tempRegFileSec.Add(super.x[i]);
						IF i < n THEN m := IndexSize
						ELSE m := (hd.aleng - SectorTableSize) MOD IndexSize + 1
						END;
						p := 0;
						WHILE p < m DO
							IF sub.x[p] # 0 THEN tempRegFileSec.Add(sub.x[p]) END;
							INC(p)
						END
					END;
					INC(i)
				END
			END
		END CollectRegisteredFileSectors;

		(* exlcusive lock must be acquired! *)
		PROCEDURE PurgeByAdr(adr: DiskAdr);
		VAR hd: FileHeader; i, p, m, n: LONGINT; super, sub: IndexSector;
		BEGIN
			GetSector(vol, adr, hd);
			FreeSector(vol, adr);
			ASSERT(hd.sec[0] = adr);
			IF hd.aleng < SectorTableSize THEN m := hd.aleng + 1 ELSE m := SectorTableSize END; p := 1;
			WHILE p < m DO
				IF hd.sec[p] # 0 THEN FreeSector(vol, hd.sec[p]) END;
				INC(p)
			END;
			IF (hd.aleng >= SectorTableSize) & (hd.ext # 0) THEN
				GetSector(vol, hd.ext, super); FreeSector(vol, hd.ext);
				n := (hd.aleng - SectorTableSize) DIV IndexSize; i := 0;
				WHILE i <= n DO
					IF super.x[i] # 0 THEN
						GetSector(vol, super.x[i], sub); FreeSector(vol, super.x[i]);
						IF i < n THEN m := IndexSize
						ELSE m := (hd.aleng - SectorTableSize) MOD IndexSize + 1
						END;
						p := 0;
						WHILE p < m DO
							IF sub.x[p] # 0 THEN FreeSector(vol, sub.x[p]) END;
							INC(p)
						END
					END;
					INC(i)
				END
			END
		END PurgeByAdr;

		(* purge all sectors of f except the sectors in 'except', except may be NIL *)
		PROCEDURE PurgeOpenedFile(f: File; except: DiskAdrList);
		VAR i, p, m, n: LONGINT; super, sub: IndexSector;

			PROCEDURE FreeExcept(sec: DiskAdr);
			BEGIN
				IF (except = NIL) OR ~except.Contains(sec) THEN FreeSector(vol, sec) END
			END FreeExcept;

		BEGIN
			IF f.aleng < SectorTableSize THEN m := f.aleng + 1 ELSE m := SectorTableSize END; p := 0; (* include sec[0] *)
			WHILE p < m DO
				IF f.sec[p] # 0 THEN FreeExcept(f.sec[p]) END;
				INC(p)
			END;
			IF (f.aleng >= SectorTableSize) & (f.ext # NIL) & (f.ext.adr # 0) THEN
				GetSector(vol, f.ext.adr, super); FreeExcept(f.ext.adr);
				n := (f.aleng - SectorTableSize) DIV IndexSize; i := 0;
				WHILE i <= n DO
					IF super.x[i] # 0 THEN
						GetSector(vol, super.x[i], sub); FreeExcept(super.x[i]);
						IF i < n THEN m := IndexSize
						ELSE m := (f.aleng - SectorTableSize) MOD IndexSize + 1
						END;
						p := 0;
						WHILE p < m DO
							IF sub.x[p] # 0 THEN FreeExcept(sub.x[p]) END;
							INC(p)
						END
					END;
					INC(i)
				END
			END
		END PurgeOpenedFile;

		PROCEDURE Close(f: File);
		VAR adr: DiskAdr;
		BEGIN {EXCLUSIVE}
			IF f.key # 0 THEN
				ASSERT(openFiles.Contains(f.key));
				openFiles.Remove(f.key);
				dir.Search(f.name, adr);
				IF (adr = 0) OR (adr # f.key) THEN (* deleted or overwritten *)
					PurgeOpenedFile(f, NIL)
				ELSE
					CollectRegisteredFileSectors(adr);
					PurgeOpenedFile(f, tempRegFileSec);
					tempRegFileSec.Clear
				END
			ELSE
				PurgeOpenedFile(f, NIL)
			END
		END Close;

		PROCEDURE Finalize;
		BEGIN {EXCLUSIVE}
			dir.Cleanup();
			vol.Finalize;
			Finalize^	(* see note in Files *)
		END Finalize;

	END FileSystem;

	DiskAdrArray = POINTER TO ARRAY OF DiskAdr;

	(* analogous to TFClasses.List *)
	DiskAdrList = OBJECT
		VAR
			list : DiskAdrArray;
			count : LONGINT;

		PROCEDURE &New*;
		BEGIN NEW(list, 8); count := 0
		END New;

		PROCEDURE GetCount() : LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN count
		END GetCount;

		PROCEDURE Grow;
		VAR old: DiskAdrArray; i : LONGINT;
		BEGIN
			old := list;
			NEW(list, LEN(list)*2);
			FOR i := 0 TO count-1 DO list[i] := old[i] END
		END Grow;

		PROCEDURE Add(x: DiskAdr);
		BEGIN {EXCLUSIVE}
			ASSERT(x # 0);
			IF count = LEN(list) THEN Grow END;
			list[count] := x;
			INC(count)
		END Add;

		PROCEDURE Remove(x: DiskAdr);
		VAR i : LONGINT;
		BEGIN {EXCLUSIVE}
			ASSERT(x # 0);
			i := 0; WHILE (i < count) & (list[i] # x) DO INC(i) END;
			IF i < count THEN
				WHILE (i < count-1) DO list[i] := list[i+1]; INC(i) END;
				DEC(count);
				list[count] := 0
			END
		END Remove;

		PROCEDURE Clear;
		VAR i : LONGINT;
		BEGIN {EXCLUSIVE}
			FOR i := 0 TO count - 1 DO list[i] := 0 END;
			count := 0
		END Clear;

		PROCEDURE Contains(x: DiskAdr) : BOOLEAN;
		VAR i: LONGINT;
		BEGIN {EXCLUSIVE}
			i := 0 ; WHILE i < count DO IF list[i] = x THEN RETURN TRUE END; INC(i) END;
			RETURN FALSE
		END Contains;
	END DiskAdrList;

TYPE
	File = OBJECT (Files.File)
		VAR
			aleng, bleng: LONGINT;
			nofbufs: LONGINT;
			modH, registered: BOOLEAN;
			firstbuf: Buffer;
			sechint: DiskAdr;
			name: FileName;
			time, date: LONGINT;
			ext: SuperIndex;
			sec: SectorTable;

		PROCEDURE Set(VAR r: Files.Rider; pos: LONGINT);
		VAR a, b: LONGINT;
		BEGIN {EXCLUSIVE}
			r.eof := FALSE; r.res := 0; r.file := SELF; r.fs := fs;
			IF pos < 0 THEN
				a := 0; b := HeaderSize
			ELSIF pos < aleng*SectorSize + bleng - HeaderSize THEN
				a := (pos + HeaderSize) DIV SectorSize; b := (pos + HeaderSize) MOD SectorSize
			ELSE
				a := aleng; b := bleng
			END;
			r.apos := a; r.bpos := b; r.hint := firstbuf
		END Set;

		PROCEDURE Pos(VAR r: Files.Rider): LONGINT;
		BEGIN
			RETURN r.apos*SectorSize + r.bpos - HeaderSize
		END Pos;

		PROCEDURE Read(VAR r: Files.Rider; VAR x: CHAR);
		VAR buf: Buffer;
		BEGIN {EXCLUSIVE}
			buf := r.hint(Buffer);
			IF r.apos # buf.apos THEN buf := GetBuf(SELF, r.apos); r.hint := buf END;
			IF r.bpos < buf.lim THEN
				x := buf.data.B[r.bpos]; INC(r.bpos)
			ELSIF r.apos < aleng THEN
				INC(r.apos);
				buf := SearchBuf(SELF, r.apos);
				IF buf = NIL THEN
					buf := r.hint(Buffer);
					IF buf.mod THEN WriteBuf(SELF, buf) END ;
					ReadBuf(SELF, buf, r.apos)
				ELSE
					r.hint := buf
				END;
				ASSERT(buf.lim > 0);
				x := buf.data.B[0]; r.bpos := 1
			ELSE
				x := 0X; r.eof := TRUE
			END
		END Read;

		PROCEDURE ReadBytes(VAR r: Files.Rider; VAR x: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR src: ADDRESS; m: LONGINT; buf: Buffer;
		BEGIN {EXCLUSIVE}
			IF LEN(x)-ofs < len THEN SYSTEM.HALT(19) END;
			IF len > 0 THEN
				buf := r.hint(Buffer);
				IF r.apos # buf.apos THEN buf := GetBuf(SELF, r.apos); r.hint := buf END;
				LOOP
					IF len <= 0 THEN EXIT END ;
					src := ADDRESSOF(buf.data.B[0]) + r.bpos; m := r.bpos + len;
					IF m <= buf.lim THEN
						SYSTEM.MOVE(src, ADDRESSOF(x[ofs]), len); r.bpos := m; r.res := 0; EXIT
					ELSIF buf.lim = SectorSize THEN
						m := buf.lim - r.bpos;
						IF m > 0 THEN SYSTEM.MOVE(src, ADDRESSOF(x[ofs]), m); INC(ofs, m); DEC(len, m) END ;
						IF r.apos < aleng THEN
							INC(r.apos); r.bpos := 0; buf := SearchBuf(SELF, r.apos);
							IF buf = NIL THEN
								buf := r.hint(Buffer);
								IF buf.mod THEN WriteBuf(SELF, buf) END ;
								ReadBuf(SELF, buf, r.apos)
							ELSE
								r.hint := buf
							END
						ELSE
							r.bpos := buf.lim; r.res := len; r.eof := TRUE; EXIT
						END
					ELSE
						m := buf.lim - r.bpos;
						IF m > 0 THEN SYSTEM.MOVE(src, ADDRESSOF(x[ofs]), m); r.bpos := buf.lim END ;
						r.res := len - m; r.eof := TRUE; EXIT
					END
				END;
			ELSE
				r.res := 0
			END
		END ReadBytes;

		PROCEDURE Write(VAR r: Files.Rider; x: CHAR);
		VAR buf: Buffer;
		BEGIN {EXCLUSIVE}
			buf := r.hint(Buffer);
			IF r.apos # buf.apos THEN buf := GetBuf(SELF, r.apos); r.hint := buf END;
			IF r.bpos >= buf.lim THEN
				IF r.bpos < SectorSize THEN
					INC(buf.lim); INC(bleng); modH := TRUE
				ELSE
					WriteBuf(SELF, buf); INC(r.apos); buf := SearchBuf(SELF, r.apos);
					IF buf = NIL THEN
						buf := r.hint(Buffer);
						IF r.apos <= aleng THEN
							ReadBuf(SELF, buf, r.apos)
						ELSE
							buf.apos := r.apos; buf.lim := 1; INC(aleng); bleng := 1; modH := TRUE;
							IF (aleng - SectorTableSize) MOD IndexSize = 0 THEN NewSub(SELF) END
						END
					ELSE
						r.hint := buf
					END;
					r.bpos := 0
				END
			END;
			buf.data.B[r.bpos] := x; INC(r.bpos); buf.mod := TRUE
		END Write;

		PROCEDURE WriteBytes(VAR r: Files.Rider; CONST x: ARRAY OF CHAR; ofs, len: LONGINT);
		VAR src, dst: ADDRESS; m: LONGINT; buf: Buffer;
		BEGIN {EXCLUSIVE}
			IF LEN(x)-ofs < len THEN SYSTEM.HALT(19) END;
			IF len > 0 THEN
				buf := r.hint(Buffer);
				IF r.apos # buf.apos THEN buf := GetBuf(SELF, r.apos); r.hint := buf END;
				LOOP
					IF len <= 0 THEN EXIT END;
					buf.mod := TRUE; dst := ADDRESSOF(buf.data.B[0]) + r.bpos; m := r.bpos + len;
					IF m <= buf.lim THEN
						SYSTEM.MOVE(ADDRESSOF(x[ofs]), dst, len); r.bpos := m; EXIT
					ELSIF m <= SectorSize THEN
						SYSTEM.MOVE(ADDRESSOF(x[ofs]), dst, len); r.bpos := m;
						bleng := m; buf.lim := m; modH := TRUE; EXIT
					ELSE
						m := SectorSize - r.bpos;
						IF m > 0 THEN SYSTEM.MOVE(ADDRESSOF(x[ofs]), dst, m); INC(ofs, m); DEC(len, m) END;
						WriteBuf(SELF, buf); INC(r.apos); r.bpos := 0; buf := SearchBuf(SELF, r.apos);
						IF buf = NIL THEN
							buf := r.hint(Buffer);
							IF r.apos <= aleng THEN ReadBuf(SELF, buf, r.apos)
							ELSE
								buf.apos := r.apos; buf.lim := 0; INC(aleng); bleng := 0; modH := TRUE;
								IF (aleng - SectorTableSize) MOD IndexSize = 0 THEN NewSub(SELF) END
							END
						ELSE
							r.hint := buf
						END
					END
				END
			END
		END WriteBytes;

		PROCEDURE Length(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN aleng*SectorSize + bleng - HeaderSize
		END Length;

		PROCEDURE GetDate(VAR t, d: LONGINT);
		BEGIN {EXCLUSIVE}
			t := time; d := date
		END GetDate;

		PROCEDURE SetDate(t, d: LONGINT);
		BEGIN {EXCLUSIVE}
			modH := TRUE; time := t; date := d
		END SetDate;

		PROCEDURE GetName(VAR name: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			Files.JoinName(fs.prefix, SELF.name, name)
		END GetName;

		PROCEDURE Register0(VAR res: LONGINT);
		VAR oldAdr: DiskAdr; fs0: FileSystem;
		BEGIN {EXCLUSIVE}
			Unbuffer(SELF);
			IF ~registered & (name # "") THEN
				fs0 := fs(FileSystem);
				fs0.dir.Search(name, oldAdr);
				fs0.dir.Insert(name, sec[0]);
				registered := TRUE; key := sec[0];
				fs0.openFiles.Add(key);
				IF (oldAdr # 0) & ~fs0.openFiles.Contains(oldAdr) THEN (* overwrite not opened file *)
					ASSERT(oldAdr # key);
					fs0.PurgeByAdr(oldAdr)
				END;
				res := 0
			ELSE
				res := 1
			END
		END Register0;

		PROCEDURE Update;
		BEGIN {EXCLUSIVE}
			Unbuffer(SELF)
		END Update;

	END File;

PROCEDURE Collect(f: ANY);
VAR file: File; fs: FileSystem;
BEGIN
	file := f(File);
	IF file.fs # NIL THEN
		fs := file.fs(FileSystem);
		IF (fs.vol # NIL) & ~(Files.ReadOnly IN fs.vol.flags) THEN fs.Close(file) END
	END
END Collect;

PROCEDURE GetSector(vol: Files.Volume; src: DiskAdr;  VAR dest: DiskSector);
BEGIN
	IF src MOD SectorFactor # 0 THEN SYSTEM.HALT(15) END;
	vol.GetBlock(src DIV SectorFactor, SYSTEM.VAL(DiskSectorArr, dest))
END GetSector;

PROCEDURE PutSector(vol: Files.Volume;  dest: DiskAdr;  VAR src: DiskSector);
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	IF dest MOD SectorFactor # 0 THEN SYSTEM.HALT(15) END;
	vol.PutBlock(dest DIV SectorFactor, SYSTEM.VAL(DiskSectorArr, src))
END PutSector;

PROCEDURE AllocSector(vol: Files.Volume;  hint: DiskAdr;  VAR sec: DiskAdr);
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	vol.AllocBlock(hint DIV SectorFactor, sec);
	sec := sec * SectorFactor
END AllocSector;

PROCEDURE MarkSector(vol: Files.Volume;  sec: LONGINT);
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	vol.MarkBlock(sec DIV SectorFactor)
END MarkSector;

PROCEDURE FreeSector(vol: Files.Volume;  sec: LONGINT);
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	ASSERT(Marked(vol, sec));
	vol.FreeBlock(sec DIV SectorFactor)
END FreeSector;

PROCEDURE Marked(vol: Files.Volume;  sec: LONGINT): BOOLEAN;
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	RETURN vol.Marked(sec DIV SectorFactor)
END Marked;

PROCEDURE Match*(mask, name: ARRAY OF CHAR): BOOLEAN;
VAR m,n, om, on: LONGINT; f: BOOLEAN;
BEGIN
	m := 0; n := 0; om := -1;
	f := TRUE;
	LOOP
		IF (mask[m] = "*") THEN
			om := m; INC(m);
			WHILE (name[n] # 0X) & (name[n] # mask[m]) DO INC(n) END;
			on := n
		ELSIF (mask[m] = "?") THEN
			IF (name[n] = 0X) THEN f := FALSE; EXIT END;
			INC(m); INC(n)
		ELSE
			IF (mask[m] # name[n]) THEN
				IF (om = -1) THEN f := FALSE; EXIT
				ELSIF (name[n] # 0X) THEN (* try the next position *)
					m := om; n := on + 1;
					IF (name[n] = 0X) THEN f := FALSE; EXIT END
				ELSE
					f := FALSE; EXIT
				END
			ELSE INC(m); INC(n)
			END
		END;
		IF (mask[m] = 0X) & ((name[n] = 0X) OR (om=-1)) THEN EXIT END
	END;
	RETURN f & (name[n] = 0X)
END Match;

PROCEDURE enumerate(fs: Files.FileSystem; VAR mask: ARRAY OF CHAR; dpg: DiskAdr; flags: SET; enum: Files.Enumerator; VAR continue: BOOLEAN; VAR fh: FileHeader; VAR fn: ARRAY OF CHAR);
VAR i, diff: LONGINT; dpg1: DiskAdr; a: DirPage; time, date, size: LONGINT;
BEGIN
	GetSector(fs.vol, dpg, a); i := 0;
	WHILE (i < a.m) & continue DO
(*		MatchPrefix(mask, a.e[i].name, pos, diff); *)
		IF i = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[i-1].p END;
		IF diff >= 0 THEN (* matching prefix *)
			IF dpg1 # 0 THEN enumerate(fs, mask, dpg1, flags, enum, continue, fh, fn) END;
			IF diff = 0 THEN
				IF continue & ((mask = "") OR Match(mask, a.e[i].name)) THEN
					time := 0; date := 0; size := 0;
					IF flags * {Files.EnumTime, Files.EnumSize} # {} THEN
						GetSector(fs.vol, a.e[i].adr, fh);
						IF Files.EnumTime IN flags THEN
							time := fh.time; date := fh.date
						END;
						IF Files.EnumSize IN flags THEN
							size := fh.aleng*SectorSize + fh.bleng - HeaderSize
						END
					END;
					Files.JoinName(fs.prefix, a.e[i].name, fn);
					enum.PutEntry(fn, {}, time, date, size)
				END
			ELSE continue := FALSE
			END
		END;
		INC(i)
	END;
	IF continue & (i > 0) & (a.e[i-1].p # 0) THEN
		enumerate(fs, mask, a.e[i-1].p, flags, enum, continue, fh, fn)
	END
END enumerate;

(* Check a file name. *)

PROCEDURE Check(VAR s: ARRAY OF CHAR; VAR name: FileName; VAR res: LONGINT);
VAR i, k: LONGINT; ch: CHAR;
BEGIN
	ch := s[0]; i := 0; k := 0;
	IF (ch = 0X) THEN name[0] := 0X; res := -1
	ELSE
		IF (ch = Files.PathDelimiter) THEN k := 1; ch := s[k] END;	(* skip first path delimiter *)
		LOOP
			IF (ch < " ") OR (ch = ":") OR (ch = Files.PathDelimiter) THEN res := 3; EXIT END;
			name[i] := ch; INC(i); INC(k); ch := s[k];
			IF (ch = 0X) THEN
				WHILE (i < FileNameLength) DO name[i] := 0X; INC(i) END;
				res := 0; EXIT
			END;
			IF (i = FileNameLength-1) THEN res := 4; EXIT END
		END
	END
END Check;

PROCEDURE UpdateHeader(f: File; VAR h: FileHeader);
BEGIN
	h.aleng := f.aleng; h.bleng := f.bleng;
	h.sec := f.sec;
	IF f.ext # NIL THEN h.ext := f.ext.adr ELSE h.ext := 0 END;
	h.date := f.date; h.time := f.time
END UpdateHeader;

PROCEDURE ReadBuf(f: File; buf: Buffer; pos: LONGINT);
VAR sec: DiskAdr; xpos: LONGINT;
BEGIN
	IF pos < SectorTableSize THEN
		sec := f.sec[pos]
	ELSE
		xpos := pos-SectorTableSize;
		sec := f.ext.sub[xpos DIV IndexSize].sec.x[xpos MOD IndexSize]
	END;
	GetSector(f.fs.vol, sec, buf.data);
	IF pos < f.aleng THEN buf.lim := SectorSize ELSE buf.lim := f.bleng END;
	buf.apos := pos; buf.mod := FALSE
END ReadBuf;

PROCEDURE NewSuper(f: File);
VAR i: LONGINT; super: SuperIndex;
BEGIN
	NEW(super); super.adr := 0; super.mod := TRUE; f.modH := TRUE; f.ext := super;
	FOR i := 0 TO IndexSize-1 DO super.sub[i] := NIL END
END NewSuper;

PROCEDURE WriteBuf(f: File; buf: Buffer);
VAR i, k, xpos: LONGINT; secadr: DiskAdr; super: SuperIndex; sub: SubIndex; vol: Files.Volume;
BEGIN
	vol := f.fs.vol;
	Clock.Get(f.time, f.date); f.modH := TRUE;
	IF buf.apos < SectorTableSize THEN
		secadr := f.sec[buf.apos];
		IF secadr = 0 THEN
			AllocSector(vol, f.sechint, secadr);
			f.modH := TRUE; f.sec[buf.apos] := secadr; f.sechint := secadr
		END;
		IF buf.apos = 0 THEN
			UpdateHeader(f, SYSTEM.VAL(FileHeader, buf.data)); f.modH := FALSE
		END
	ELSE
		super := f.ext;
		IF super = NIL THEN NewSuper(f); super := f.ext END;
		xpos := buf.apos-SectorTableSize;
		i := xpos DIV IndexSize; sub := super.sub[i];
		IF sub = NIL THEN
			NEW(sub); sub.adr := 0; sub.sec.x[0] := 0; super.sub[i] := sub; super.mod := TRUE
		END;
		k := xpos MOD IndexSize; secadr := sub.sec.x[k];
		IF secadr = 0 THEN
			AllocSector(vol, f.sechint, secadr); f.sechint := secadr;
			sub.mod := TRUE; sub.sec.x[k] := secadr
		END
	END;
	PutSector(vol, secadr, buf.data); buf.mod := FALSE
END WriteBuf;

PROCEDURE SearchBuf(f: File; pos: LONGINT): Buffer;
VAR buf: Buffer;
BEGIN
	buf := f.firstbuf;
	LOOP
		IF buf.apos = pos THEN EXIT END;
		buf := buf.next;
		IF buf = f.firstbuf THEN buf := NIL; EXIT END
	END;
	RETURN buf
END SearchBuf;

PROCEDURE GetBuf(f: File; pos: LONGINT): Buffer;
VAR buf: Buffer;
BEGIN
	buf := f.firstbuf;
	LOOP
		IF buf.apos = pos THEN EXIT END;
		IF buf.next = f.firstbuf THEN
			IF f.nofbufs < MaxBufs THEN (* allocate new buffer *)
				NEW(buf); buf.next := f.firstbuf.next; f.firstbuf.next := buf;
				INC(f.nofbufs)
			ELSE (* take one of the buffers *)
				f.firstbuf := buf;
				IF buf.mod THEN WriteBuf(f, buf) END
			END;
			buf.apos := pos;
			IF pos <= f.aleng THEN ReadBuf(f, buf, pos) END;
			EXIT
		END;
		buf := buf.next
	END;
	RETURN buf
END GetBuf;

PROCEDURE Unbuffer(f: File);
VAR
	i, k: LONGINT; buf: Buffer; super: SuperIndex; sub: SubIndex; head: FileHeader;
	sec: IndexSector; vol: Files.Volume;
BEGIN
	vol := f.fs.vol;
	buf := f.firstbuf;
	REPEAT
		IF buf.mod THEN WriteBuf(f, buf) END;
		buf := buf.next
	UNTIL buf = f.firstbuf;
	super := f.ext;
	IF super # NIL THEN
		k := (f.aleng + (IndexSize-SectorTableSize)) DIV IndexSize; i := 0;
		WHILE i # k DO
			sub := super.sub[i]; INC(i);
			IF sub.mod THEN
				IF sub.adr = 0 THEN
					AllocSector(vol, f.sechint, sub.adr); f.sechint := sub.adr;
					super.mod := TRUE
				END;
				PutSector(vol, sub.adr, sub.sec); sub.mod := FALSE
			END
		END;
		IF super.mod THEN
			IF super.adr = 0 THEN
				AllocSector(vol, f.sechint, super.adr); f.sechint := super.adr;
				f.modH := TRUE
			END;
			i := 0;
			WHILE i # k DO sec.x[i] := super.sub[i].adr; INC(i) END;
			WHILE i # IndexSize DO sec.x[i] := 0; INC(i) END;
			PutSector(vol, super.adr, sec); super.mod := FALSE
		END
	END;
	IF f.modH THEN
		GetSector(vol, f.sec[0], head); UpdateHeader(f, head);
		PutSector(vol, f.sec[0], head); f.modH := FALSE
	END
END Unbuffer;

PROCEDURE NewSub(f: File);
VAR i, k: LONGINT; sub: SubIndex;
BEGIN
	k := (f.aleng - SectorTableSize) DIV IndexSize;
	IF k = IndexSize THEN SYSTEM.HALT(18) END;
	NEW(sub); sub.adr := 0; sub.mod := TRUE;
	FOR i := 0 TO IndexSize-1 DO sub.sec.x[i] := 0 END;
	IF f.ext = NIL THEN NewSuper(f) END;
	f.ext.sub[k] := sub
END NewSub;

(** Generate a new file system object.  Files.NewVol has volume parameter, Files.Par has mount prefix. *)
PROCEDURE NewFS*(context : Files.Parameters);
VAR fs: FileSystem; fh: FileHeader;
BEGIN
	IF Files.This(context.prefix) = NIL THEN
		IF (context.vol.blockSize = SectorSize) & (context.vol.size >= MinVolSize) THEN
			GetSector(context.vol, DirRootAdr, fh);
			IF fh.mark = DirMark THEN	(* assume it is an Aos filesystem *)
				NEW(fs);  fs.vol := context.vol;
				ASSERT(context.vol.size < MAX(LONGINT) DIV SectorFactor);
				fs.desc := "AosFS";
				NEW(fs.dir, context.vol);	(* initialize directory and volume *)
				ASSERT(fs.dir.state = Opened);	(* will have to undo changes to vol before continuing *)
				Files.Add(fs, context.prefix)
			ELSE
				context.error.String("DiskFS: File system not found on ");
				context.error.String(context.vol.name);  context.error.Ln
			END
		ELSE
			context.error.String("DiskFS: Bad volume size");  context.error.Ln
		END
	ELSE
		context.error.String("DiskFS: ");  context.error.String(context.prefix);
		context.error.String(" already in use");  context.error.Ln
	END;
END NewFS;

(* Clean up when module unloaded. *)

PROCEDURE Cleanup;
VAR ft: Files.FileSystemTable; i: LONGINT;
BEGIN
	IF Modules.shutdown = Modules.None THEN
		Files.GetList(ft);
		IF ft # NIL THEN
			FOR i := 0 TO LEN(ft^)-1 DO
				IF ft[i] IS FileSystem THEN Files.Remove(ft[i]) END
			END
		END
	END
END Cleanup;

BEGIN
	ASSERT((SIZEOF(FileHeader) = SectorSize) & (SIZEOF(IndexSector) = SectorSize) & (SIZEOF(DataSector) = SectorSize) &
			(SIZEOF(DirPage) = SectorSize) & (SIZEOF(MapIndex) = SectorSize) & (SIZEOF(MapSector) = SectorSize) &
			(DirPgSize MOD 2 = 0));
	Modules.InstallTermHandler(Cleanup);
END DiskFS.

(*
	aleng * SectorSize + bleng = length (including header)
	apos * SectorSize + bpos = current position
	0 <= bpos <= lim <= SectorSize
	0 <= apos <= aleng < SectorTableSize + IndexSize*IndexSize
	(apos < aleng) & (lim = SectorSize) OR (apos = aleng)

	Methods with {} notation are explicitly unprotected.  They must be called only from a protected context.
*)

(*
	04.02.2004	lb			Prevent disk space leaks during system run (disk GC)
	03.01.2006	staubesv	Avoid longint overflow that caused disk gc even if not necessary
*)