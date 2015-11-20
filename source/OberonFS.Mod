(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE OberonFS; (** AUTHOR "pjm"; PURPOSE "Native Oberon file system"; *)

IMPORT SYSTEM, Machine, KernelLog, Modules, Clock, Files;

CONST
	MinVolSize = 4;

	SF = 29;	(* SectorFactor *)
	FnLength = 32;	(* includes 0X *)
	STS = 64;	(* SecTabSize *)
	ETS = 12;	(* ExTabSize *)
	SS = 2048;	(* SectorSize *)
	XS = SS DIV 4;	(* IndexSize *)
	HS = 352;	(* HeaderSize *)

	DirRootAdr = 1*SF;
	DirPgSize = 50;
	N = DirPgSize DIV 2;

	DirMark = LONGINT(9B1EA38DH);
	HeaderMark = LONGINT(9BA71D86H);

	FillerSize = 36;

	MapIndexSize = (SS-4) DIV 4;
	MapSize = SS DIV SIZEOF (SET);	(* {MapSize MOD 8*SIZEOF(SET) = 0} *)
	MapMark = LONGINT(9C2F977FH);

	MaxBufs = 4;
	InitHint = 200*SF;

	Closed = 0X; Opening = 1X; Opened = 2X; Closing = 3X;

	SetSize = MAX (SET) + 1;

TYPE
	DiskSector = RECORD END;	(* Oberon Sector, size SS *)
	DiskSectorArr = ARRAY SS OF CHAR;

	DiskAdr = LONGINT;
	FileName = ARRAY FnLength OF CHAR;
	SectorTable = ARRAY STS OF DiskAdr;
	ExtensionTable = ARRAY ETS OF DiskAdr;

	FileHeader = RECORD (DiskSector)   (* allocated in the first page of each file on disk *)
		mark: LONGINT;
		name: FileName;
		aleng, bleng: INTEGER;
		date, time: LONGINT;
		ext: ExtensionTable;
		sec: SectorTable;
		data: ARRAY SS-HS OF CHAR
	END;

	IndexSector = RECORD (DiskSector)
		x: ARRAY XS OF DiskAdr
	END;

	DataSector = RECORD (DiskSector)
		B: ARRAY SS OF CHAR
	END;

	DirEntry = RECORD	(*B-tree node*)
		name: FileName;
		adr: DiskAdr; (*sec no of file header*)
		p: DiskAdr  (*sec no of descendant in directory*)
	END;

	DirPage = RECORD (DiskSector)
		mark: LONGINT;
		m: INTEGER;
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

	FileHd = POINTER TO FileHeader;

	Buffer = POINTER TO RECORD (Files.Hint)
		apos, lim: LONGINT;
		mod: BOOLEAN;
		next: Buffer;
		data: DataSector
	END;

	Index = POINTER TO RECORD
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
					WHILE j < FnLength DO u.name[j] := 0X; INC(j) END
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
					c.e[s].p := dpg1; DEC(b.m, SHORT(k)); i := 0;
					WHILE i < b.m DO b.e[i] := b.e[i+k]; INC(i) END ;
					PutSector(vol, dpg1, b); a.m := SHORT(N-1+k); h := FALSE
				ELSE (*merge pages a and b, discard b*) i := 0;
					WHILE i < N DO a.e[i+N] := b.e[i]; INC(i) END ;
					i := s; DEC(c.m);
					WHILE i < c.m DO c.e[i] := c.e[i+1]; INC(i) END ;
					a.m := 2*N; h := c.m < N
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
					(*move k-1 items from b to a, one to c*) DEC(b.m, SHORT(k));
					WHILE i > 0 DO DEC(i); a.e[i] := b.e[i+b.m+1] END ;
					c.e[s] := b.e[b.m]; a.p0 := c.e[s].p;
					c.e[s].p := dpg0; a.m := SHORT(N-1+k); h := FALSE;
					PutSector(vol, dpg0, a)
				ELSE (*merge pages a and b, discard a*)
					c.e[s].p := a.p0; b.e[N] := c.e[s]; i := 0;
					WHILE i < N-1 DO b.e[i+N+1] := a.e[i]; INC(i) END ;
					b.m := 2*N; DEC(c.m); h := c.m < N
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
					PutSector(vol, DirRootAdr, a) (*discard newroot*)
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
				GetSector(vol, size*SF, mi);
				IF mi.mark = MapMark THEN
					j := 0;	(* check consistency of index *)
					WHILE (j # MapIndexSize) & (mi.index[j] >= 0) & (mi.index[j] MOD SF = 0) DO
						INC(j)
					END;
					IF j = MapIndexSize THEN
						found := TRUE;
						mi.mark := 0; PutSector(vol, size*SF, mi);	(* invalidate index *)
						j := 0; sec := 1; q := 0;
						LOOP
							IF (j = MapIndexSize) OR (mi.index[j] = 0) THEN EXIT END;
							GetSector(vol, mi.index[j], ms);
							REPEAT
								IF (sec MOD SetSize) IN ms.map[sec DIV SetSize MOD MapSize] THEN
									MarkSector(vol, sec*SF);
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
						IF (free > thres) & (vol.Available()*SS > 100000H) THEN
							state := Opened
						ELSE	(* undo *)
							FOR j := SF TO size*SF BY SF DO
								IF Marked(vol, j) THEN FreeSector(vol, j) END
							END;
							ASSERT(vol.Available() = size);
							KernelLog.String("OberonFS: "); KernelLog.Int(free, 1);
							KernelLog.String("% free, forcing disk GC on ");
							KernelLog.String(vol.name); KernelLog.Ln
						END
					END
				END;
				IF ~found THEN
					KernelLog.String("OberonFS: Index not found on ");
					KernelLog.String(vol.name); KernelLog.Ln
				END
			END
		END Startup;

		PROCEDURE &Init*(vol: Files.Volume);
		VAR k: LONGINT; A: ARRAY 2000 OF DiskAdr; files: LONGINT; bad: BOOLEAN;

			PROCEDURE MarkSectors;
			VAR L, R, i, j, n: LONGINT; x: DiskAdr; hd: FileHeader; B: IndexSector;

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
					IF hd.aleng < STS THEN
						j := hd.aleng + 1;
						REPEAT
							DEC(j);
							IF hd.sec[j] # 0 THEN MarkSector(vol, hd.sec[j])
							ELSE hd.aleng := SHORT(j-1); bad := TRUE
							END
						UNTIL j = 0
					ELSE
						j := STS;
						REPEAT
							DEC(j);
							IF hd.sec[j] # 0 THEN MarkSector(vol, hd.sec[j])
							ELSE hd.aleng := SHORT(j-1); bad := TRUE
							END
						UNTIL j = 0;
						n := (hd.aleng - STS) DIV XS; i := 0;
						WHILE (i <= n) & ~bad DO
							IF hd.ext[i] # 0 THEN
								MarkSector(vol, hd.ext[i]); GetSector(vol, hd.ext[i], B);
								IF i < n THEN j := XS
								ELSE j := (hd.aleng - STS) MOD XS + 1
								END;
								REPEAT
									DEC(j);
									IF (B.x[j] MOD SF = 0) & (B.x[j] > 0) THEN
										MarkSector(vol, B.x[j])
									ELSE
										bad := TRUE
									END
								UNTIL j = 0;
								INC(i)
							ELSE bad := TRUE
							END;
							IF bad THEN
								IF i = 0 THEN hd.aleng := STS-1
								ELSE hd.aleng := SHORT(STS + (i-1) * XS)
								END
							END
						END
					END;
					IF bad THEN
						KernelLog.Ln; KernelLog.String(hd.name); KernelLog.String(" truncated");
						hd.bleng := SS; IF hd.aleng < 0 THEN hd.aleng := 0 (* really bad *) END;
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
					A[k] := a.e[i].adr; INC(k); INC(i);
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
					files := 0; KernelLog.String("OberonFS: Scanning ");
					KernelLog.String(vol.name); KernelLog.String("...");
					TraverseDir(DirRootAdr); MarkSectors;
					KernelLog.Int(files, 6); KernelLog.String(" files"); KernelLog.Ln;
					state := Opened
				END;
				IF ~Marked(vol, vol.size*SF) THEN	(* last sector still free *)
					MarkSector(vol, vol.size*SF); lastSectorReserved := TRUE	(* allocate it *)
				END;
				KernelLog.String("OberonFS: "); KernelLog.Int(vol.Available() * (SS DIV 1024), 1);
				KernelLog.String("K of "); KernelLog.Int(vol.size * (SS DIV 1024), 1);
				KernelLog.String("K available on "); KernelLog.String(vol.name);
				KernelLog.Ln
			ELSE
				state := Opened
			END
		END Init;

		PROCEDURE Cleanup;
		VAR i, j, p, q, sec, size: LONGINT; mi: MapIndex; ms: MapSector;
		BEGIN {EXCLUSIVE}
			state := Closing;
			size := vol.size; i := size*SF;
			IF ~(Files.ReadOnly IN vol.flags) THEN
				IF lastSectorReserved THEN FreeSector(vol, i); lastSectorReserved := FALSE END;
				IF ~Marked(vol, i) THEN	(* last sector is available for us *)
					j := 0; sec := 1; q := 0;
					LOOP
						REPEAT DEC(i, SF) UNTIL (i = 0) OR ~Marked(vol, i);	(* find a free sector *)
						IF i = 0 THEN RETURN END;	(* no more space, don't commit *)
						mi.index[j] := i; INC(j);
						FOR p := 0 TO MapSize-1 DO ms.map[p] := {} END;
						REPEAT
							IF Marked(vol, sec*SF) THEN
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
					PutSector(vol, size*SF, mi);	(* commit *)
					KernelLog.String("OberonFS: Map saved on ");
					KernelLog.String(vol.name); KernelLog.Ln
				END
			END;
			state := Closed; vol := NIL
		END Cleanup;

	END Directory;

TYPE
	FileSystem = OBJECT (Files.FileSystem)	(* our file system type *)
		VAR dir: Directory;

		PROCEDURE New0(name: ARRAY OF CHAR): Files.File;
		VAR i, res: LONGINT; f: File; buf: Buffer; head: FileHd; namebuf: FileName;
		BEGIN {EXCLUSIVE}
			f := NIL; Check(name, namebuf, res);
			IF res <= 0 THEN
				NEW(buf); buf.apos := 0; buf.mod := TRUE; buf.lim := HS; buf.next := buf;
				head := SYSTEM.VAL(FileHd, ADDRESSOF(buf.data));
				head.mark := HeaderMark;
				head.aleng := 0; head.bleng := HS; head.name := namebuf;
				Clock.Get(head.time, head.date);
				NEW(f); f.fs := SELF; f.key := 0; f.aleng := 0; f.bleng := HS; f.modH := TRUE;
				f.time := head.time; f.date := head.date;
				f.firstbuf := buf; f.nofbufs := 1; f.name := namebuf; f.sechint := InitHint;
				f.registered := (f.name[0] = 0X);
				i := 0; REPEAT f.ext[i] := NIL; head.ext[i] := 0; INC(i) UNTIL i = ETS;
				i := 0; REPEAT f.sec[i] := 0; head.sec[i] := 0; INC(i) UNTIL i = STS
			END;
			RETURN f
		END New0;

		PROCEDURE Old0(name: ARRAY OF CHAR): Files.File;
		VAR
			i, k, res: LONGINT; f: File; header: DiskAdr; buf: Buffer; head: FileHd;
			namebuf: FileName; inxpg: Index;
		BEGIN {EXCLUSIVE}
			f := NIL; Check(name, namebuf, res);
			IF res = 0 THEN
				dir.Search(namebuf, header);
				IF header # 0 THEN
					NEW(buf); buf.apos := 0; buf.next := buf; buf.mod := FALSE;

					GetSector(vol, header, buf.data);
					head := SYSTEM.VAL(FileHd, ADDRESSOF(buf.data));

					NEW(f); f.fs := SELF; f.key := header;
					f.aleng := head.aleng; f.bleng := head.bleng;
					f.time := head.time; f.date := head.date;
					IF f.aleng = 0 THEN buf.lim := f.bleng ELSE buf.lim := SS END;
					f.firstbuf := buf; f.nofbufs := 1;
					f.name := namebuf; f.registered := TRUE;
					f.sec := head.sec;
					k := (f.aleng + (XS-STS)) DIV XS; i := 0;
					WHILE i < k DO
						NEW(inxpg); inxpg.adr := head.ext[i]; inxpg.mod := FALSE;
						GetSector(vol, inxpg.adr, inxpg.sec); f.ext[i] := inxpg; INC(i)
					END;
					WHILE i < ETS DO f.ext[i] := NIL; INC(i) END;
					f.sechint := header; f.modH := FALSE
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
					GetSector(vol, adr, head);
					head.mark := HeaderMark+1;	(* invalidate mark *)
					PutSector(vol, adr, head)
				ELSE
					res := 2
				END
			ELSE
				key := 0
			END
		END Delete0;

		PROCEDURE Rename0(old, new: ARRAY OF CHAR; f: Files.File; VAR res: LONGINT);
		VAR adr: DiskAdr; oldbuf, newbuf: FileName;  head: FileHeader;
		BEGIN {EXCLUSIVE}
			Check(old, oldbuf, res);
			IF res = 0 THEN
				Check(new, newbuf, res);
				IF res = 0 THEN
					dir.Delete(oldbuf, adr);
					IF adr # 0 THEN
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
		VAR b: BOOLEAN; fh: FileHeader; fn: ARRAY Files.PrefixLength+FnLength OF CHAR;
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

		PROCEDURE Finalize;
		BEGIN {EXCLUSIVE}
			dir.Cleanup();
			vol.Finalize;
			Finalize^	(* see note in Files *)
		END Finalize;

	END FileSystem;

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
			ext: ARRAY ETS OF Index;
			sec: SectorTable;

		PROCEDURE Set(VAR r: Files.Rider; pos: LONGINT);
		VAR a, b: LONGINT;
		BEGIN {EXCLUSIVE}
			r.eof := FALSE; r.res := 0; r.file := SELF; r.fs := fs;
			IF pos < 0 THEN
				a := 0; b := HS
			ELSIF pos < aleng*SS + bleng - HS THEN
				a := (pos + HS) DIV SS; b := (pos + HS) MOD SS
			ELSE
				a := aleng; b := bleng
			END;
			r.apos := a; r.bpos := b; r.hint := firstbuf
		END Set;

		PROCEDURE Pos(VAR r: Files.Rider): LONGINT;
		BEGIN
			RETURN r.apos*SS + r.bpos - HS
		END Pos;

		PROCEDURE Read(VAR r: Files.Rider; VAR x: CHAR);
		VAR buf: Buffer;
		BEGIN {EXCLUSIVE}
			ASSERT(r.file = SELF);
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
			ASSERT(r.file = SELF);
			IF LEN(x)-ofs < len THEN SYSTEM.HALT(19) END ;
			buf := r.hint(Buffer);
			IF r.apos # buf.apos THEN buf := GetBuf(SELF, r.apos); r.hint := buf END;
			LOOP
				IF len <= 0 THEN EXIT END ;
				src := ADDRESSOF(buf.data.B[0]) + r.bpos; m := r.bpos + len;
				IF m <= buf.lim THEN
					SYSTEM.MOVE(src, ADDRESSOF(x[ofs]), len); r.bpos := m; r.res := 0; EXIT
				ELSIF buf.lim = SS THEN
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
		END ReadBytes;

		PROCEDURE Write(VAR r: Files.Rider; x: CHAR);
		VAR buf: Buffer;
		BEGIN {EXCLUSIVE}
			ASSERT(r.file = SELF);
			buf := r.hint(Buffer);
			IF r.apos # buf.apos THEN buf := GetBuf(SELF, r.apos); r.hint := buf END;
			IF r.bpos >= buf.lim THEN
				IF r.bpos < SS THEN
					INC(buf.lim); INC(bleng); modH := TRUE
				ELSE
					WriteBuf(SELF, buf); INC(r.apos); buf := SearchBuf(SELF, r.apos);
					IF buf = NIL THEN
						buf := r.hint(Buffer);
						IF r.apos <= aleng THEN
							ReadBuf(SELF, buf, r.apos)
						ELSE
							buf.apos := r.apos; buf.lim := 1; INC(aleng); bleng := 1; modH := TRUE;
							IF (aleng - STS) MOD XS = 0 THEN NewExt(SELF) END
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
		VAR dst: ADDRESS; m: LONGINT; buf: Buffer;
		BEGIN {EXCLUSIVE}
			ASSERT(r.file = SELF);
			IF LEN(x)-ofs < len THEN SYSTEM.HALT(19) END;
			buf := r.hint(Buffer);
			IF r.apos # buf.apos THEN buf := GetBuf(SELF, r.apos); r.hint := buf END;
			LOOP
				IF len <= 0 THEN EXIT END;
				buf.mod := TRUE; dst := ADDRESSOF(buf.data.B[0]) + r.bpos; m := r.bpos + len;
				IF m <= buf.lim THEN
					SYSTEM.MOVE(ADDRESSOF(x[ofs]), dst, len); r.bpos := m; EXIT
				ELSIF m <= SS THEN
					SYSTEM.MOVE(ADDRESSOF(x[ofs]), dst, len); r.bpos := m;
					bleng := m; buf.lim := m; modH := TRUE; EXIT
				ELSE
					m := SS - r.bpos;
					IF m > 0 THEN SYSTEM.MOVE(ADDRESSOF(x[ofs]), dst, m); INC(ofs, m); DEC(len, m) END;
					WriteBuf(SELF, buf); INC(r.apos); r.bpos := 0; buf := SearchBuf(SELF, r.apos);
					IF buf = NIL THEN
						buf := r.hint(Buffer);
						IF r.apos <= aleng THEN ReadBuf(SELF, buf, r.apos)
						ELSE
							buf.apos := r.apos; buf.lim := 0; INC(aleng); bleng := 0; modH := TRUE;
							IF (aleng - STS) MOD XS = 0 THEN NewExt(SELF) END
						END
					ELSE
						r.hint := buf
					END
				END
			END
		END WriteBytes;

		PROCEDURE Length(): LONGINT;
		BEGIN {EXCLUSIVE}
			RETURN aleng*SS + bleng - HS
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
		BEGIN {EXCLUSIVE}
			Unbuffer(SELF);
			IF ~registered & (name # "") THEN
				fs(FileSystem).dir.Insert(name, sec[0]);
				registered := TRUE; key := sec[0];
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

PROCEDURE GetSector(vol: Files.Volume; src: DiskAdr;  VAR dest: DiskSector);
BEGIN
	IF src MOD SF # 0 THEN SYSTEM.HALT(15) END;
	vol.GetBlock(src DIV SF, SYSTEM.VAL(DiskSectorArr, dest))
END GetSector;

PROCEDURE PutSector(vol: Files.Volume;  dest: DiskAdr;  VAR src: DiskSector);
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	IF dest MOD SF # 0 THEN SYSTEM.HALT(15) END;
	vol.PutBlock(dest DIV SF, SYSTEM.VAL(DiskSectorArr, src))
END PutSector;

PROCEDURE AllocSector(vol: Files.Volume;  hint: DiskAdr;  VAR sec: DiskAdr);
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	vol.AllocBlock(hint DIV SF, sec);
	sec := sec * SF
END AllocSector;

PROCEDURE MarkSector(vol: Files.Volume;  sec: LONGINT);
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	vol.MarkBlock(sec DIV SF)
END MarkSector;

PROCEDURE FreeSector(vol: Files.Volume;  sec: LONGINT);
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	vol.FreeBlock(sec DIV SF)
END FreeSector;

PROCEDURE Marked(vol: Files.Volume;  sec: LONGINT): BOOLEAN;
BEGIN
	ASSERT(~(Files.ReadOnly IN vol.flags));
	RETURN vol.Marked(sec DIV SF)
END Marked;

PROCEDURE MatchPrefix(VAR mask, name: ARRAY OF CHAR; VAR pos, diff: LONGINT);
BEGIN
	pos := 0;
	LOOP
		IF mask[pos] = 0X THEN
			pos := -1; diff := 0; EXIT	(* no "*" found, match all files with this prefix *)
		ELSIF mask[pos] = "*" THEN
			IF mask[pos+1] = 0X THEN pos := -1 END;	(* "*" found at end, match all files with this prefix *)
			diff := 0; EXIT	(* "*" found, do Match *)
		END;
		diff := ORD(name[pos]) - ORD(mask[pos]);
		IF diff # 0 THEN EXIT END;
		INC(pos)
	END
END MatchPrefix;

PROCEDURE Match(pos: LONGINT; VAR pat, name: ARRAY OF CHAR): BOOLEAN;
VAR i0, i1, j0, j1: LONGINT; f: BOOLEAN;
BEGIN
	f := TRUE;
	IF pos # -1 THEN
		i0 := pos; j0 := pos;
		LOOP
			IF pat[i0] = "*" THEN
				INC(i0);
				IF pat[i0] = 0X THEN EXIT END
			ELSE
				IF name[j0] # 0X THEN f := FALSE END;
				EXIT
			END;
			f := FALSE;
			LOOP
				IF name[j0] = 0X THEN EXIT END;
				i1 := i0; j1 := j0;
				LOOP
					IF (pat[i1] = 0X) OR (pat[i1] = "*") THEN f := TRUE; EXIT END;
					IF pat[i1] # name[j1] THEN EXIT END;
					INC(i1); INC(j1)
				END;
				IF f THEN j0 := j1; i0 := i1; EXIT END;
				INC(j0)
			END;
			IF ~f THEN EXIT END
		END
	END;
	RETURN f & (name[0] # 0X)
END Match;

PROCEDURE enumerate(fs: Files.FileSystem; VAR mask: ARRAY OF CHAR; dpg: DiskAdr; flags: SET; enum: Files.Enumerator; VAR continue: BOOLEAN; VAR fh: FileHeader; VAR fn: ARRAY OF CHAR);
VAR i, pos, diff: LONGINT; dpg1: DiskAdr; a: DirPage; time, date, size: LONGINT;
BEGIN
	GetSector(fs.vol, dpg, a); i := 0;
	WHILE (i < a.m) & continue DO
		MatchPrefix(mask, a.e[i].name, pos, diff);
		IF i = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[i-1].p END;
		IF diff >= 0 THEN (* matching prefix *)
			IF dpg1 # 0 THEN enumerate(fs, mask, dpg1, flags, enum, continue, fh, fn) END;
			IF diff = 0 THEN
				IF continue & Match(pos, mask, a.e[i].name) THEN
					time := 0; date := 0; size := 0;
					IF flags * {Files.EnumTime, Files.EnumSize} # {} THEN
						GetSector(fs.vol, a.e[i].adr, fh);
						IF Files.EnumTime IN flags THEN
							time := fh.time; date := fh.date
						END;
						IF Files.EnumSize IN flags THEN
							size := LONG(fh.aleng)*SS + fh.bleng - HS
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
	VAR i: LONGINT; ch: CHAR;
BEGIN
	ch := s[0]; i := 0;
	IF ("A" <= CAP(ch)) & (CAP(ch) <= "Z") THEN
		LOOP name[i] := ch; INC(i); ch := s[i];
			IF ch = 0X THEN
				WHILE i < FnLength DO name[i] := 0X; INC(i) END ;
				res := 0; EXIT
			END ;
			IF ~(("A" <= CAP(ch)) & (CAP(ch) <= "Z")
				OR ("0" <= ch) & (ch <= "9") OR (ch = ".")) THEN res := 3; EXIT
			END ;
			IF i = FnLength-1 THEN res := 4; EXIT END
		END
	ELSIF ch = 0X THEN name[0] := 0X; res := -1
	ELSE res := 3
	END
END Check;

PROCEDURE UpdateHeader(f: File; VAR h: FileHeader);
VAR k: LONGINT;
BEGIN
	h.aleng := SHORT(f.aleng); h.bleng := SHORT(f.bleng);
	h.sec := f.sec; k := (f.aleng + (XS-STS)) DIV XS;
	WHILE k > 0 DO DEC(k); h.ext[k] := f.ext[k].adr END;
	h.date := f.date; h.time := f.time
END UpdateHeader;

PROCEDURE ReadBuf(f: File; buf: Buffer; pos: LONGINT);
VAR sec: DiskAdr;
BEGIN
	IF pos < STS THEN
		sec := f.sec[pos]
	ELSE
		sec := f.ext[(pos-STS) DIV XS].sec.x[(pos-STS) MOD XS]
	END;
	GetSector(f.fs.vol, sec, buf.data);
	IF pos < f.aleng THEN buf.lim := SS ELSE buf.lim := f.bleng END;
	buf.apos := pos; buf.mod := FALSE
END ReadBuf;

PROCEDURE WriteBuf(f: File; buf: Buffer);
VAR i, k: LONGINT; secadr: DiskAdr; inx: Index; vol: Files.Volume;
BEGIN
	vol := f.fs.vol;
	Clock.Get(f.time, f.date); f.modH := TRUE;
	IF buf.apos < STS THEN
		secadr := f.sec[buf.apos];
		IF secadr = 0 THEN
			AllocSector(vol, f.sechint, secadr);
			f.modH := TRUE; f.sec[buf.apos] := secadr; f.sechint := secadr
		END;
		IF buf.apos = 0 THEN
			UpdateHeader(f, SYSTEM.VAL(FileHeader, buf.data)); f.modH := FALSE
		END
	ELSE
		i := (buf.apos - STS) DIV XS; inx := f.ext[i];
		IF inx = NIL THEN
			NEW(inx); inx.adr := 0; inx.sec.x[0] := 0; f.ext[i] := inx; f.modH := TRUE
		END;
		k := (buf.apos - STS) MOD XS; secadr := inx.sec.x[k];
		IF secadr = 0 THEN
			AllocSector(vol, f.sechint, secadr);
			f.modH := TRUE; inx.mod := TRUE; inx.sec.x[k] := secadr; f.sechint := secadr
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
VAR i, k: LONGINT; buf: Buffer; inx: Index; head: FileHeader; vol: Files.Volume;
BEGIN
	vol := f.fs.vol;
	buf := f.firstbuf;
	REPEAT
		IF buf.mod THEN WriteBuf(f, buf) END;
		buf := buf.next
	UNTIL buf = f.firstbuf;
	k := (f.aleng + (XS-STS)) DIV XS; i := 0;
	WHILE i < k DO
		inx := f.ext[i]; INC(i);
		IF inx.mod THEN
			IF inx.adr = 0 THEN
				AllocSector(vol, f.sechint, inx.adr); f.sechint := inx.adr; f.modH := TRUE
			END;
			PutSector(vol, inx.adr, inx.sec); inx.mod := FALSE
		END
	END;
	IF f.modH THEN
		GetSector(vol, f.sec[0], head); UpdateHeader(f, head);
		PutSector(vol, f.sec[0], head); f.modH := FALSE
	END
END Unbuffer;

PROCEDURE NewExt(f: File);
VAR i, k: LONGINT; ext: Index;
BEGIN
	k := (f.aleng - STS) DIV XS;
	IF k = ETS THEN SYSTEM.HALT(18) END;
	NEW(ext); ext.adr := 0; ext.mod := TRUE;
	f.ext[k] := ext; i := XS;
	REPEAT DEC(i); ext.sec.x[i] := 0 UNTIL i = 0
END NewExt;

(** Generate a new file system object.  Files.NewVol has volume parameter, Files.Par has mount prefix. *)
PROCEDURE NewFS*(context : Files.Parameters);
VAR fs: FileSystem; fh: FileHeader;
BEGIN
	IF Files.This(context.prefix) = NIL THEN
		IF (context.vol.blockSize = SS) & (context.vol.size >= MinVolSize) THEN
			GetSector(context.vol, DirRootAdr, fh);
			IF fh.mark = DirMark THEN	(* assume it is an old-format Native filesystem *)
				NEW(fs);  fs.vol := context.vol;
				ASSERT(context.vol.size < MAX(LONGINT) DIV SF);
				fs.desc := "NatFS";
				NEW(fs.dir, context.vol);	(* initialize directory and volume *)
				ASSERT(fs.dir.state = Opened);	(* will have to undo changes to vol before continuing *)
				Files.Add(fs, context.prefix)
			ELSE
				context.error.String("OberonFS: File system not found on ");
				context.error.String(context.vol.name);  context.error.Ln
			END
		ELSE
			context.error.String("OberonFS: Bad volume size");  context.error.Ln
		END
	ELSE
		context.error.String("OberonFS: ");  context.error.String(context.prefix);
		context.error.String(" already in use");  context.error.Ln
	END;
END NewFS;

(* Clean up when module freed. *)
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
	ASSERT((SIZEOF(FileHeader) = SS) & (SIZEOF(IndexSector) = SS) & (SIZEOF(DataSector) = SS) &
			(SIZEOF(DirPage) = SS) & (SIZEOF(MapIndex) = SS) & (SIZEOF(MapSector) = SS));
	Modules.InstallTermHandler(Cleanup)
END OberonFS.

(*
	aleng * SS + bleng = length (including header)
	apos * SS + bpos = current position
	0 <= bpos <= lim <= SS
	0 <= apos <= aleng < STS
	(apos < aleng) & (lim = SS) OR (apos = aleng)
*)
