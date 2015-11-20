(* ETH Oberon, Copyright 2002 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Heaps;	(** AUTHOR "G.F."; PURPOSE "Heap management and garbage collector"; *)

IMPORT S := SYSTEM, Trace, Unix, Machine;


CONST
	Stats* = TRUE; (* maintain statistical counters *)
	
	AddrSize = SIZEOF( ADDRESS );
	SizeSize = SIZEOF( SIZE );


	FlagsOfs = AddrSize * 3;				(* flags offset in TypeDesc *)
	ModOfs* = AddrSize * 4;			(* moduleAdr offset in TypeDesc *)
(*	TypeNameOfs = AddrSize * 5;		(* type name offset in TypeDesc *)
	ModNameOfs = AddrSize * 2;		(* module name offset in ModuleDesc *)
*)	
	NilVal* = 0;
	
	MethodEndMarker* = -40000000H;   (* marks the end of the method addresses, used in Info.ModuleDetails *)

	ArrayAlignment = 8;
	HeapBlockOffset* = - 2*AddrSize;
	TypeDescOffset* = -AddrSize;
	
	MaxMarkDepth = 8000;

	ThruputBarrier = Machine.MemBlockSize;

	(* ----------------- object finalization ------------------------------*)

TYPE
	Finalizer* = PROCEDURE {DELEGATE}( obj: ANY );

	FinalizerNode* = POINTER TO RECORD
				objWeak*{UNTRACED}: ANY;		(* weak reference to checked object *)
				markAdr: ADDRESS;   			(* address of type tag of object *)
				nextFin: FinalizerNode;   		(* in finalization list *)
				objStrong*: ANY;   				(* strong reference to object to be finalized *)
				finalizer*{UNTRACED}: Finalizer;	(* finalizer, if any *)
				finalizerStrong: Finalizer			(* strong ref. to the obj that is referenced by the finalyzer, if any *)
			END;

VAR
	checkRoot: FinalizerNode;   (* list of checked objects (contains weak references to the checked objects) *)
	finalizeRoot: FinalizerNode;   (* objects scheduled for finalization (contains references to scheduled objects) *)

	(* ------------------------- Heap ------------------------------- *)
CONST
	BlockSize = 32;
	MaxFreeLists = 14; 	(* number of free lists *)
	FreeListBarrier = 7;
	
	MaxCandidates = 1024;
	
	ProtOfs = 2*BlockSize + 16;	(*! p mod 32 = 16 ! *)
	SysOfs = 24;  	(*! p mod 16 = 8 ! *)
	ProtTypeBit* = 31;   (** flags in TypeDesc, low bits reserved for extLevel *)

TYPE
	FreeBlock = POINTER TO RECORD
				tag: ADDRESS;  (* = ADDRESSOF( size ) *)
				size: SIZE;
				next{UNTRACED}: FreeBlock;
			END;
	
	FreeList = RECORD 
				minSize: SIZE;  
				first{UNTRACED}: FreeBlock;
				last{UNTRACED}: FreeBlock
			END;
	
	ProcessQueue* = RECORD
		head*, tail*: ANY
	END;
			
	ProtRecBlock* = POINTER TO ProtRecBlockDesc;
	ProtRecBlockDesc* = RECORD 
		recSize-: SIZE;	(* needed by SizeOf(blk) in Sweep *)
		
		awaitingLock*:	ProcessQueue;	(* unused in UnixAos *)
		awaitingCond*: ProcessQueue;
		lockedBy*: ANY;	
		lock*: ANY;	(* used by Win32, unused for I386 and UnixAos *)
		
		mtx*: Unix.Mutex_t;			(* processes blocked awaiting lock (UnixAos only) *)
		enter*: Unix.Condition_t;	(* processes blocked awaiting lock (UnixAos only) *)
	END;

	RootObject* = OBJECT 
		PROCEDURE FindRoots*;	(** abstract *)
		BEGIN HALT( 301 ) END FindRoots;
	END RootObject;

	StaticTypeBlock* = POINTER TO StaticTypeDesc;
	StaticTypeDesc = RECORD
		recSize: SIZE;
		pointerOffsets* {UNTRACED}: PointerOffsets;
	END;

	PointerOffsets = POINTER TO ARRAY OF SIZE;
	
	CandBuffer = ARRAY MaxCandidates OF ADDRESS;
	
VAR
	freeLists: ARRAY MaxFreeLists + 1 OF FreeList;

	candidates, candbuf: CandBuffer;
	nofcand: LONGINT;
	
	deferred: ARRAY 1000 OF ADDRESS;
	noDeferred: LONGINT;
	
	heapSize, heapAvailable: SIZE;
	shrinkDisabled: BOOLEAN;

	thruput:  SIZE;
	GC* : PROCEDURE;
	InvokeGC* : PROCEDURE;
	collecting-: BOOLEAN;
	markDepth: LONGINT;
	
	saveSP*	: PROCEDURE;		(* save SP for usage in Objects.Process.FindRoots() *)
	
	(** Statistics. Will only be maintained if Stats = TRUE *)

	(** Memory allocation statistics *)
	Nnew- : LONGINT;			(** Number of times NewBlock has been called since system startup *)
	NnewBytes- : HUGEINT;		(** Number of bytes allocated by NewBlock since system startup *)

	(** Garbage collection statistics *)
	Ngc- : LONGINT;  (** Number of GC cycles since system startup *)

	(** Statistics considering the last GC cyle *)
	Nmark-, Nmarked-, NfinalizeAlive-, NfinalizeDead-: LONGINT;
	NgcCyclesMark-, NgcCyclesLastRun-, NgcCyclesMax-, NgcCyclesAllRuns- : HUGEINT;

	
	PROCEDURE EmptyProc;
	END EmptyProc;

	(* ----------------- object finalization ---------------------------*)


	PROCEDURE AddFinalizer*( obj: ANY;  n: FinalizerNode );
	VAR adr: ADDRESS;
	BEGIN
		n.objWeak := obj;  n.objStrong := NIL;  n.finalizerStrong := NIL;
		adr := S.VAL( ADDRESS, obj );
		IF ODD( adr DIV 8 ) THEN 	(* indirect tag *)
			S.GET( adr - AddrSize, adr );  
		ELSIF ODD( adr DIV 16 ) THEN  (* protected object *)
			adr := adr - ProtOfs 
		END; 
		n.markAdr := adr - AddrSize;
		Machine.Acquire( Machine.Heaps );
		n.nextFin := checkRoot;  checkRoot := n;
		Machine.Release( Machine.Heaps )
	END AddFinalizer;

	(* Check reachability of finalized objects. *)
	PROCEDURE CheckFinalizedObjects;
	VAR n, p, t: FinalizerNode;  tag: ADDRESS;

		PROCEDURE MarkDelegate( p: Finalizer );
		VAR pointer: ANY;
		BEGIN
			S.GET( ADDRESSOF( p ) + AddrSize, pointer );
			IF pointer # NIL THEN  Mark( pointer )  END
		END MarkDelegate;

	BEGIN
		n := checkRoot;
		WHILE n # NIL DO  (* move unmarked checked objects to finalize list *)
			S.GET( n.markAdr, tag );
			IF ~ODD( tag ) THEN	(* not marked *)
				IF n = checkRoot THEN  checkRoot := n.nextFin  ELSE  p.nextFin := n.nextFin  END;
				n.objStrong := n.objWeak;		(* anchor the object for finalization *)
				n.finalizerStrong := n.finalizer;	(* anchor the finalizer for finalization *)
				t := n.nextFin;  n.nextFin := finalizeRoot;  finalizeRoot := n;  n := t;
				IF Stats THEN DEC(NfinalizeAlive); INC(NfinalizeDead) END
			ELSE  p := n;  n := n.nextFin
			END
		END;

		(* now trace the weak references to keep finalized objects alive during this collection *)
		n := finalizeRoot;
		WHILE n # NIL DO
			MarkDelegate( n.finalizerStrong );
			Mark( n.objStrong );  n := n.nextFin
		END;

		n := checkRoot;
		WHILE n # NIL DO (* list of objects that had been marked before entering CheckFinalizedObjects *)
			(* we still have to mark the weak finalizers, as they might have not been marked before  *)
			MarkDelegate( n.finalizer );  n := n.nextFin
		END;
	END CheckFinalizedObjects;

	(** Return the next scheduled finalizer or NIL if none available.  Called by finalizer object in AosKernel. *)
	PROCEDURE GetFinalizer*( ): FinalizerNode;
	VAR n: FinalizerNode;
	BEGIN
		n := NIL;
		IF finalizeRoot # NIL THEN
			Machine.Acquire( Machine.Heaps );
			n := finalizeRoot;   (* take one finalizer *)
			IF n # NIL THEN
				finalizeRoot := n.nextFin;   n.nextFin := NIL;
				IF Stats THEN DEC(NfinalizeDead) END;
			END;
			Machine.Release( Machine.Heaps );
		END;
		RETURN n
	END GetFinalizer;

	(** Check finalizers registered in the specified module, which is about to be freed or shut down.
			Remove all finalizer procedures in this module from the finalizer lists so they won't be called any more. *)
	PROCEDURE CleanupModuleFinalizers*( codeAdr: ADDRESS; codeLen: SIZE;  CONST name: ARRAY OF CHAR );
	VAR n, p, t: FinalizerNode;  codeEnd: ADDRESS;  N1, N2: LONGINT;
	BEGIN
		codeEnd := codeAdr + codeLen;  N1 := 0; N2 := 0;
		Machine.Acquire( Machine.Heaps );
		n := checkRoot;
		WHILE n # NIL DO  (* iterate over checked list *)
			t := n;  n := n.nextFin;
			IF (codeAdr <= S.VAL( ADDRESS, t.finalizer )) & (S.VAL( ADDRESS, t.finalizer ) <= codeEnd ) THEN
				IF t = checkRoot THEN  checkRoot := t.nextFin  ELSE  p.nextFin := t.nextFin  END;
				IF Stats THEN DEC(NfinalizeAlive) END;
				INC( N1 )
			ELSE  
				p := t
			END
		END;
		(* also remove finalizers from list, so they won't be called *)
		n := finalizeRoot;
		WHILE n # NIL DO  (* iterate over finalized list *)
			t := n;  n := n.nextFin;
			IF (codeAdr <= S.VAL( ADDRESS, t.finalizer ) ) & (S.VAL( ADDRESS, t.finalizer ) <= codeEnd ) THEN
				IF t = finalizeRoot THEN  finalizeRoot := t.nextFin  ELSE  p.nextFin := t.nextFin  END;
				IF Stats THEN DEC(NfinalizeDead) END;
				INC( N2 )
			ELSE  
				p := t
			END
		END;
		Machine.Release( Machine.Heaps );
		IF (N1 # 0) OR (N2 # 0) THEN
			Machine.Acquire ( Machine.TraceOutput );
			Trace.String( name );  Trace.Char( " " );
			Trace.Int( N1, 1 );  Trace.String( " discarded finalizers, " );
			Trace.Int( N2, 1 );  Trace.StringLn( " pending finalizers" );
			Machine.Release ( Machine.TraceOutput );
		END
	END CleanupModuleFinalizers;
	
	
	
	(* Add a root object to the set of traversable objects. If in allocated heap then mark and traverse, if in Module Heap (Bootfile) then only traverse. *)
	PROCEDURE AddRootObject*( rootObject: RootObject );
	BEGIN
		IF rootObject = NIL THEN (* nothing *)
		(*
		ELSIF CheckPointer(SYSTEM.VAL(ADDRESS,rootObject)) THEN
			(* object in heap, must be fully marked and traversed *)
			Mark(rootObject)
		ELSE
			(* object in bootfile, traverse as root object only *)
			rootObject.nextRoot := rootList; rootList := rootObject;	(* link root list *)
		*)
		ELSE
			IF collecting THEN  Mark( rootObject )  END
		END;
	END AddRootObject;



	(* ------------------------- garbage collector ----------------------- *)


	PROCEDURE UnmarkedObject( ptr: ANY ): BOOLEAN; (* FALSE: alredy marked or sysblock *)
	VAR addr, taddr: ADDRESS;  tag: ADDRESS;  sysblock: BOOLEAN;
	BEGIN
		IF ptr = NIL THEN  RETURN FALSE  END;
		addr := S.VAL( ADDRESS, ptr );
		IF ~ValidPointer( addr ) THEN  RETURN FALSE  END;	
		
		sysblock := FALSE;  taddr := addr - AddrSize;
		IF ODD( addr DIV 8 ) THEN  (* sysblock *)
			taddr := taddr - SysOfs;  sysblock := TRUE
		ELSIF ODD( addr DIV 16 ) THEN  (* protected object *)
			taddr := taddr - ProtOfs;
		END;

		S.GET( taddr, tag );
		IF ODD( tag ) THEN
			(* already marked *) RETURN FALSE
		ELSE
			S.PUT( taddr, tag + 1 );   (* mark this block *)  INC( Nmarked );
			IF sysblock THEN   RETURN FALSE  END;
			IF ptr IS RootObject THEN  ptr(RootObject).FindRoots  END;	
			RETURN TRUE  
		END;
	END UnmarkedObject;

	PROCEDURE MarkRecordFields( rec: ADDRESS; sTB: StaticTypeBlock );
	VAR ptr: ANY; i, n: SIZE;  
	BEGIN
		n := LEN( sTB.pointerOffsets ); i := 0;
		WHILE i < n DO
			S.GET( rec + sTB.pointerOffsets[i], ptr );
			IF ptr # NIL THEN  Mark( ptr )  END;
			INC( i )
		END
	END MarkRecordFields;
	
	PROCEDURE Mark*( ptr: ANY );
	VAR 
		block, cur, lastElem, tag: ADDRESS;  
		sTB{UNTRACED}: StaticTypeBlock;
	BEGIN
		IF Stats THEN  INC(Nmark)  END;
		INC( markDepth );  
		
		IF UnmarkedObject( ptr ) THEN
			block := S.VAL( ADDRESS, ptr );
			S.GET( block - AddrSize, tag );
			sTB := S.VAL( StaticTypeBlock, tag DIV 4 * 4 );
			IF ODD( tag DIV 2 )THEN
				IF markDepth <= MaxMarkDepth - 10 THEN
					 S.GET( block, lastElem );
					 S.GET( block + 2*AddrSize, cur );   
					 REPEAT
						MarkRecordFields( cur, sTB );						
						INC( cur, sTB.recSize );
					UNTIL cur > lastElem
				ELSE
					deferred[noDeferred] := block;  INC( noDeferred );
				END;
			ELSE  
				IF markDepth <= MaxMarkDepth THEN
					MarkRecordFields( block, sTB )
				ELSE
					deferred[noDeferred] := block;  INC( noDeferred );
				END;	
			END;			
		END;
		DEC( markDepth );
		IF (markDepth <= 0) & (noDeferred > 0) THEN  MarkDeferred  END
	END Mark;

	PROCEDURE MarkDeferred;
	VAR 
		block, cur, lastElem, tag: ADDRESS;  
		sTB{UNTRACED}: StaticTypeBlock;
	BEGIN
		markDepth := 1;
		WHILE noDeferred > 0 DO
			DEC( noDeferred );  
			block := deferred[noDeferred];  
			S.GET( block - AddrSize, tag );
			sTB := S.VAL( StaticTypeBlock, tag DIV 4 * 4 );
			IF ODD( tag DIV 2 )THEN
				 S.GET( block, lastElem );
				 S.GET( block + 2*AddrSize, cur );   
				 REPEAT
					MarkRecordFields( cur, sTB );						
					INC( cur, sTB.recSize );
				UNTIL cur > lastElem
			ELSE  
				MarkRecordFields( block, sTB )
			END;			
		END;
	END MarkDeferred;


	PROCEDURE AppendFree( VAR freeList: FreeList; block: FreeBlock );
	BEGIN
		IF freeList.first = NIL THEN
			freeList.first := block;  freeList.last := block
		ELSE
			freeList.last.next := block;
			freeList.last := block;
		END;
		block.next := NIL
	END AppendFree;
	
	PROCEDURE InsertSorted( VAR freeList: FreeList; block: FreeBlock );
	VAR x: FreeBlock;
	BEGIN
		(* keep them ordered to avoid unnecessary splits *)
		(* this optimization has positive impact on heap utilization
			130 MB vs. 240 MB heap for compiling and linking a new system
			but it slows down heap allocation speed. 	*)
		x := freeList.first;
		IF (x = NIL) OR (x.size > block.size) THEN 
			block.next := x;
			freeList.first := block
		ELSE
			WHILE ( x.next # NIL) & (x.next.size < block.size) DO  x := x.next  END;
			block.next := x.next;
			x.next := block 
		END	
	END InsertSorted;
	
	PROCEDURE Recycle( blkAdr: ADDRESS; blkSize: SIZE );
	VAR i: LONGINT;  block: FreeBlock;
	BEGIN
	(*	ASSERT( blkSize MOD BlockSize = 0 );	*)
		block := S.VAL( FreeBlock, blkAdr );
		block.tag := blkAdr + AddrSize;
		block.size := blkSize - AddrSize;
		block.next := NIL;
		
		i := 0;
		WHILE (i < MaxFreeLists) & (freeLists[i+1].minSize < blkSize) DO  INC( i )  END;
		
		IF i < FreeListBarrier THEN	
			AppendFree( freeLists[i], block )
		ELSE
			InsertSorted( freeLists[i], block )
		END;	
		INC( heapAvailable, blkSize );
	END Recycle;
	
	
	PROCEDURE ClearFreeLists;
	VAR i, minSize: LONGINT;
	BEGIN
		minSize := BlockSize;
		FOR i := 0 TO MaxFreeLists DO  
			freeLists[i].minSize := minSize;
			freeLists[i].first := NIL;
			freeLists[i].last := NIL;
			IF i < FreeListBarrier THEN  INC( minSize, BlockSize )  ELSE  minSize := 2 * minSize  END
		END;
		heapAvailable := 0
	END ClearFreeLists;
	
	
	PROCEDURE ShowFreeLists( CONST msg: ARRAY OF CHAR );
	VAR i, n: LONGINT; m: SIZE;  b: FreeBlock;  bad: BOOLEAN;
	BEGIN
		Trace.Ln;
		Trace.String( "==== FreeLists " ); Trace.String( msg ); Trace.Ln;
		FOR i := 0 TO MaxFreeLists DO
			Trace.Int( i, 2 );  Trace.Int( freeLists[i].minSize, 6 );  Trace.String( ": " );
			b := freeLists[i].first;  n := 0;  m := 0;  bad := FALSE;
			IF i < FreeListBarrier THEN
				WHILE b # NIL DO  INC( n );  b := b.next END;
			ELSE
				WHILE b # NIL DO  
					INC( n );
					IF n < 20 THEN  
						Trace.Int( b.size, 1 );  Trace.Char( ',' );
						IF n MOD 8 = 0 THEN  Trace.Ln;  Trace.String( "          " )  END;  
					END;
					IF b.size < m THEN  bad := TRUE  ELSE  m := b.size  END;
					b := b.next  
				END;
				IF n > 0 THEN  Trace.String( "  largest=" );  Trace.Int( m, 0 )  END;
				IF bad THEN  Trace.String( ",  bad ordered" )  END
			END;
			Trace.String( " [" );  Trace.Int( n, 0 );  Trace.StringLn( "]" )
		END;
		Trace.Ln
	END ShowFreeLists;
	

	PROCEDURE Sweep;
	VAR
		block, freeBlock, endBlockAdr, tag: ADDRESS;  
		blockSize, freeSize: SIZE;
		memBlock, nextMemBlock: Machine.MemoryBlock;
	BEGIN
		ClearFreeLists;
		heapAvailable := 0; 

		memBlock := Machine.memBlockHead;  
		WHILE memBlock # NIL DO
			block := memBlock.beginBlockAdr;  endBlockAdr := memBlock.endBlockAdr;

			freeSize := 0;
			WHILE block < endBlockAdr DO
				blockSize := SizeOf( block );
				S.GET( block, tag );
				IF ~ODD( tag) THEN
					(* collect *)
					IF freeSize = 0 THEN  freeBlock := block  END;
					INC( freeSize, blockSize );
				ELSE
					S.PUT( block, tag - 1 );	(* remove mark bit *)
					IF freeSize > 0 THEN
						Recycle( freeBlock, freeSize );
						freeSize := 0
					END
				END;
				INC( block, blockSize );
			END;

			nextMemBlock := memBlock.next;
			
			IF (freeSize = endBlockAdr - memBlock.beginBlockAdr)  THEN
				(* whole block is free, unlink it*)
				IF shrinkDisabled THEN
					Recycle( freeBlock, freeSize ); (* last collected block: *)
				ELSE 
					Machine.FreeMemBlock( memBlock );
					heapSize := GetHeapSize()
				END
			ELSIF freeSize > 0 THEN
				Recycle( freeBlock, freeSize ); (* last collected block: *)
			END;
			
			memBlock := nextMemBlock;
		END;
	(*	ShowFreeLists( "after Sweep" )	*)
	END Sweep;


	PROCEDURE SizeOf( block: ADDRESS ): SIZE;
	VAR tag, lastElem: ADDRESS;  recSize, blockSize: SIZE;
	BEGIN
		S.GET( block, tag );
		S.GET( tag DIV 4 * 4, recSize );
		IF ODD( tag DIV 2 ) THEN
			S.GET( block + AddrSize, lastElem );
			blockSize := lastElem + recSize - block
		ELSE
			blockSize := recSize + AddrSize
		END;
		INC( blockSize, (-blockSize) MOD BlockSize );
		RETURN blockSize
	END SizeOf;
	
	
	PROCEDURE SortCandidates( nc: LONGINT );
	VAR i, j, h: LONGINT;  p: ADDRESS;
	BEGIN
		(* sort them in increasing order using shellsort *)
		h := 1;
		REPEAT  h := h*3 + 1  UNTIL h > nc;
		REPEAT
			h := h DIV 3;  i := h;
			WHILE i < nc DO
				p := candbuf[i];  j := i;
				WHILE (j >= h) & (candbuf[j - h] > p) DO  
					candbuf[j] := candbuf[j - h];  j := j - h  
				END;
				candbuf[j] := p;  INC( i )
			END
		UNTIL h = 1;
	END SortCandidates;
	
	

	PROCEDURE CheckCandidates;  
	VAR
		i, nc: LONGINT; mb: Machine.MemoryBlock;
		p, tag1, tag2, block: ADDRESS;
		blkSize: SIZE;
		
		PROCEDURE NextCandidate(): ADDRESS;
		VAR cand: ADDRESS;
		BEGIN
			IF i < nc THEN  cand := candbuf[i];  INC( i )  ELSE  cand := 0  END;
			RETURN cand
		END NextCandidate;
		
	BEGIN
		IF nofcand = 0 THEN  RETURN  END;
		
		candbuf := candidates;  nc := nofcand;  nofcand := 0;  
		SortCandidates( nc );

		i := 0;
		p := NextCandidate();  
		mb := Machine.memBlockHead;
		REPEAT
			IF (p < mb.endBlockAdr) & (candbuf[nc-1] > mb.beginBlockAdr) THEN	
				block := mb.beginBlockAdr;  
				blkSize := SizeOf( block );
				REPEAT
					IF p <= block + AddrSize THEN
						IF p = block + AddrSize THEN
							S.GET( block, tag1 );
							IF tag1 # p THEN  (* not a free block *) Mark( S.VAL( ANY, p ) )  END
						END;
						p := NextCandidate();  
					ELSIF p = block + AddrSize + SysOfs THEN  (* system block ? *)
						S.GET( block, tag1 );
						S.GET( p - AddrSize, tag2 );
						IF (tag2 = p - SysOfs) & (tag2 = tag1)  THEN
							(* really a sysblock *)  Mark( S.VAL( ANY, p ) );
						END;
						p := NextCandidate();  
					ELSIF (blkSize > AddrSize + ProtOfs) & (p = block + AddrSize + ProtOfs)  THEN  (* prot. obj. ? *)
						S.GET( block, tag1 );
						IF tag1 = block + AddrSize THEN  Mark( S.VAL( ANY, p ) )  END;
						p := NextCandidate();  
					ELSE
						block := block + blkSize;
						IF block < mb.endBlockAdr THEN  blkSize := SizeOf( block ) END;
					END;
				UNTIL (p = 0) OR (block >= mb.endBlockAdr) OR (p >= mb.endBlockAdr);
			END;	
			mb := mb.next;
		UNTIL (mb = NIL) OR (p = 0);
	END CheckCandidates;
	

	PROCEDURE AddCandidate*( p: ADDRESS );
	VAR tag0Addr, tag0, tag: ADDRESS;  i: LONGINT;
	BEGIN
		IF p MOD 32 = 0 THEN
			tag0Addr := p - AddrSize (* RecBlk, ArrBlk *)
		ELSIF p MOD 32 = 16 THEN
			tag0Addr := p - ProtOfs - AddrSize (* ProtObj *)
		ELSIF p MOD 16 = 8 THEN
			tag0Addr := p - SysOfs - AddrSize (* SysBlk *)
		ELSE  RETURN
		END;
		
		i := 0;
		WHILE (i < nofcand) & (candidates[i] # p) DO  INC( i )  END;
		IF i < nofcand THEN  (* double *) RETURN  END; 
		
		IF ValidAddress( tag0Addr ) THEN
			S.GET( tag0Addr, tag0 );
			IF ODD( tag0 ) THEN  RETURN  END;  (* already marked *)
			S.GET ( p - AddrSize, tag );
			IF ValidAddress( tag DIV 4 * 4 ) THEN
				candidates[nofcand] := p;  INC( nofcand );
				IF nofcand = MaxCandidates THEN  CheckCandidates  END
			END;
		END
	END AddCandidate;



	PROCEDURE CollectGarbage*( root: RootObject );
	VAR time1, time2 : HUGEINT; 
	BEGIN
		IF Stats THEN
			Nmark := 0; Nmarked := 0;
			INC( Ngc );
			time1 := Machine.GetTimer( );
		END;
		collecting := TRUE;  markDepth := 0;  noDeferred := 0;  nofcand := 0;
		
		Mark( root );
		REPEAT  CheckCandidates  UNTIL nofcand = 0;  
		CheckFinalizedObjects;
		Sweep;

		collecting := FALSE;  thruput := 0;
		IF Stats THEN
			time2 := Machine.GetTimer( );
			NgcCyclesLastRun := time2 - time1;
			IF NgcCyclesLastRun > NgcCyclesMax THEN  NgcCyclesMax := NgcCyclesLastRun  END;
			INC( NgcCyclesAllRuns, NgcCyclesLastRun );
			NgcCyclesMark := NgcCyclesLastRun
		END;
	END CollectGarbage;
	


	(* -------------------------- memory allocation ----------------------- *)

	PROCEDURE FindFreeBlock( size: SIZE ): FreeBlock;
	VAR prev, block: FreeBlock;  i: LONGINT;
	BEGIN
		i := 0;
		WHILE (i < MaxFreeLists) & (freeLists[i+1].minSize <= size)  DO  INC( i )  END;
		
		REPEAT
			block := freeLists[i].first;
			IF block # NIL THEN  
				IF block.size + AddrSize >= size THEN
					IF block = freeLists[i].last THEN  freeLists[i].first := NIL;  freeLists[i].last := NIL
					ELSE freeLists[i].first := block.next;  block.next := NIL
					END;
				ELSE  (* i = MaxFreeLists *)
					REPEAT  prev := block;  block := block.next
					UNTIL (block = NIL) OR (block.size + AddrSize >= size);
					IF block # NIL THEN  prev.next := block.next  END
				END
			END;
			INC( i )
		UNTIL (block # NIL) OR (i > MaxFreeLists);
		RETURN block
	END FindFreeBlock;
	
	
	PROCEDURE Collect;
	BEGIN
		thruput := 0;
		Machine.Acquire( Machine.GC );
		Machine.Release( Machine.Heaps );
		Machine.Release( Machine.GC );
		GC;
		Machine.Acquire( Machine.Heaps );
	END Collect;

	PROCEDURE GetBlock( size: SIZE ): ADDRESS;   (* size MOD B = 0 *)
	VAR 
		block: FreeBlock;  blkSize: SIZE;  blkAdr, adr2: ADDRESS;
	BEGIN 
		IF (thruput > ThruputBarrier) OR (heapAvailable < size) THEN  Collect END;
			
		REPEAT
			block := FindFreeBlock( size );
			IF block = NIL THEN
				IF thruput > 0 THEN  Collect
				ELSE	
				(*	ShowFreeLists( "befor ExpandHeap" );	*)
					Machine.ExpandHeap( 0, size, S.VAL( ADDRESS, block ), adr2 );
					IF block # NIL  THEN  
						heapSize := GetHeapSize();
					ELSE
						Trace.Ln;  
						Trace.String( "Heapspace exhausted" ); Trace.Ln;  
						Machine.Release( Machine.Heaps );
						HALT( 99 )
					END	
				END
			END
		UNTIL block # NIL;
		
		blkSize := block.size + AddrSize;
		blkAdr := S.VAL( ADDRESS, block );
		DEC( heapAvailable, blkSize );
		IF blkSize > size THEN  Recycle( blkAdr + size, blkSize - size )  END;
		
		INC( thruput, size );
		IF Stats THEN  INC(Nnew); INC(NnewBytes, size)  END;
		Machine.Fill32( blkAdr, size, 0 );
		IF saveSP # NIL THEN  saveSP  END;
		RETURN blkAdr
	END GetBlock;



	(** Private compiler interface. Do not use. *)
	PROCEDURE NewRec*( VAR p: ANY;  tag: ADDRESS; isRealtime: BOOLEAN );   (* implementation of NEW( ptr ) *)
	VAR size, recSize: SIZE;  ptr: ADDRESS;  typeInfoAdr: ADDRESS;  flags: SET;
	BEGIN
		S.GET( tag - AddrSize, typeInfoAdr );   
		S.GET( typeInfoAdr + FlagsOfs, flags );
		IF ProtTypeBit IN flags THEN  (* protected record *)
			NewProtRec( p, tag, isRealtime );  RETURN
		END;
		S.GET( tag, recSize );
		size := recSize + AddrSize;  INC( size, (-size) MOD BlockSize );
		
		Machine.Acquire( Machine.Heaps );
		ptr := GetBlock( size ) + AddrSize;
		S.PUT( ptr - AddrSize, tag );
		p := S.VAL( ANY, ptr );
		Machine.Release( Machine.Heaps )
	END NewRec;
	
	
	(** Private compiler interface. Do not use. *)
	PROCEDURE NewProtRec*( VAR p: ANY;  tag: ADDRESS; isRealtime: BOOLEAN );
	VAR recSize, size: SIZE;  ptr0, ptr: ADDRESS;
	BEGIN
		S.GET( tag, recSize );
		(* add space for tag and header and round up to BlockSize *)
		size := recSize + ProtOfs + AddrSize;  INC( size, (-size) MOD BlockSize );
		
		Machine.Acquire( Machine.Heaps );
		ptr0 := GetBlock( size ) + AddrSize;
		S.PUT( ptr0 - AddrSize, ptr0 );		(* set the tag used by Sweep *)
		S.PUT( ptr0, size - AddrSize );		(* size, needed by SizeOf(blk) in Sweep *)
		
		ptr := ptr0 + ProtOfs;				(* mod 32 = 16 ! *)
		S.PUT( ptr + HeapBlockOffset, ptr0 );
		S.PUT( ptr + TypeDescOffset, tag );	(* set the tag *)
				
		p := S.VAL( ANY, ptr );
		Machine.Release( Machine.Heaps );
	END NewProtRec;


	(** Private compiler interface. Do not use. *)
	PROCEDURE NewSys*( VAR p: ANY;  size: SIZE; isRealtime: BOOLEAN );   (* implementation of S.NEW(ptr, size) *)
	VAR ptr: ADDRESS;
	BEGIN
		size := size + AddrSize + SysOfs;  INC( size, (-size) MOD BlockSize );
		Machine.Acquire( Machine.Heaps );
		ptr := GetBlock( size ) + AddrSize;  
		S.PUT( ptr - AddrSize, ptr );		(* tag used by Sweep *)
		S.PUT( ptr, size - AddrSize );		(* size, needed by SizeOf(blk) in Sweep *)
		S.PUT( ptr + AddrSize, S.VAL( ADDRESS, -AddrSize ) );	
		
		S.PUT( ptr + SysOfs - AddrSize, ptr );	(* tag *)
		p := S.VAL( ANY, ptr + SysOfs );		(* mod 16 = 8 ! *)
		Machine.Release( Machine.Heaps )
	END NewSys;

	(** Private compiler interface. Do not use. *)
	PROCEDURE NewArr*( VAR p: ANY;  eltag: ADDRESS;  nofelem, nofdim: SIZE; isRealtime: BOOLEAN );
	VAR 
		sTB: StaticTypeBlock;
		arrSize, blkSize, dataOffset: SIZE;  ptr, firstElem: ADDRESS;  
	BEGIN	
		sTB := S.VAL( StaticTypeBlock, eltag );
		arrSize := nofelem*sTB.recSize;
		IF arrSize = 0 THEN
			NewSys( p, nofdim*4 + 3*AddrSize, isRealtime );
		ELSE
			dataOffset := 3*AddrSize + nofdim*AddrSize;
			INC( dataOffset, (-dataOffset) MOD ArrayAlignment );
			IF LEN( sTB.pointerOffsets^ ) = 0 THEN
				(* no pointers in element type *)
				NewSys( p, dataOffset + arrSize, isRealtime );
			ELSE
				blkSize := dataOffset + arrSize + AddrSize; INC( blkSize, (-blkSize) MOD BlockSize );
				Machine.Acquire( Machine.Heaps );
				ptr := GetBlock( blkSize ) + AddrSize;
				S.PUT( ptr - AddrSize, eltag + 2 (*ArrayBit*) );
				firstElem := ptr + dataOffset;
				S.PUT( ptr, firstElem + arrSize - sTB.recSize );  (* last elem *)
				(* ptr + 4 is reserved for mark phase *)
				S.PUT( ptr + 2*AddrSize, firstElem );
				p := S.VAL( ANY, ptr );
				Machine.Release( Machine.Heaps )
			END
		END;
	END NewArr;

	PROCEDURE FillStaticType* ( VAR staticTypeAddr: ADDRESS;
								   startAddr, typeInfoAdr: ADDRESS;
								   size, recSize: SIZE;
								   numPtrs, numSlots: LONGINT );
	VAR 
		p, offset: ADDRESS;  sTB {UNTRACED}: StaticTypeBlock;
	BEGIN
		Machine.Acquire( Machine.Heaps );
		
		Machine.Fill32( startAddr, size, 0 );	(* clear whole static type, size MOD AddrSize = 0 implicitly, see WriteType in PCOF.Mod *)
		S.PUT( startAddr, S.VAL( ADDRESS, -AddrSize ) );	(* sentinel *)

		(* methods and tags filled in later *)

		offset := AddrSize*(numSlots + 1 + 1);  (* #methods, max. no. of tags, method end marker (sentinel), pointer to type information*)
		p := startAddr + offset;
		S.PUT( p - AddrSize, typeInfoAdr ); 	(* pointer to typeInfo *)
		sTB := S.VAL( StaticTypeBlock, p );
		sTB.recSize := recSize;
		staticTypeAddr := p;
		
		(* create the pointer for the dynamic array of pointer offsets, the dynamic array of pointer offsets 
		    is stored in the static type descriptor, it has no header part *)
		INC( p, SIZEOF(StaticTypeDesc) );
		IF p MOD (2 * AddrSize) # 0 THEN  INC( p, AddrSize )  END;
		S.PUT( p + 3 * AddrSize, numPtrs ); (* internal structure of dynamic array without pointers: the first 3 fields are unused *)
		sTB.pointerOffsets := S.VAL( PointerOffsets, p ); (* the fourth field contains the dimension of the array *)

		(* ptrOfs filled in later *)

		Machine.Release( Machine.Heaps )
	END FillStaticType;



	(*------------------------------  misc  ----------------------------------------*)

	(** WriteType - Write a type name (for tracing only). *)
	PROCEDURE WriteType*( t: ADDRESS );		(* t is static type descriptor *)
	VAR m, a: ADDRESS; i: LONGINT;  ch: CHAR;  
	BEGIN
		S.GET( t - AddrSize, t );
		S.GET( t + 4*AddrSize, m );
		IF m # 0 THEN
			a := m + AddrSize;
			i := 0;  S.GET( a, ch );
			WHILE (ch >= '0') & (ch <= 'z') & (i < 32) DO
				Trace.Char( ch );
				INC( i );  S.GET( a + i, ch )
			END
		ELSE  Trace.String( "NIL" )
		END;
		Trace.Char( '.' );
		a := t + 5*AddrSize;  i := 0;  S.GET( a, ch );
		WHILE (ch >= '0') & (ch <= 'z') & (i < 32) DO
			Trace.Char( ch );
			INC( i );  S.GET( a + i, ch )
		END;
		IF i = 0 THEN  Trace.String( "-" )  END;	
	END WriteType;


	PROCEDURE ValidAddress*( p: ADDRESS ): BOOLEAN;
	VAR sb: Machine.MemoryBlock;
	BEGIN
		IF (p # 0 ) & (p MOD 4 = 0) THEN
			sb := Machine.memBlockHead;
			WHILE sb # NIL DO
				IF (sb.beginBlockAdr <= p) & (p <= sb.endBlockAdr) THEN  RETURN TRUE  END;
				sb := sb.next;
			END
		END;
		RETURN FALSE
	END ValidAddress;

	PROCEDURE ValidPointer( p: ADDRESS ): BOOLEAN;   (* check if p is a valid pointer into the Heap *)
	VAR tag: ADDRESS;  ok: BOOLEAN;
	BEGIN
		ok := FALSE;  tag := 0;
		IF (p MOD 8 = 0) & ValidAddress( p ) THEN
			IF p MOD 16 = 8 THEN  ok := TRUE (* subobject or sysblock *)
			ELSE
				S.GET( p - AddrSize, tag );
				ok := ValidAddress( tag DIV 4 * 4 ) 
			END
		END;
		IF ~ok THEN
			Trace.String( "illegal pointer value: " ); Trace.Hex( p, -8 );
			IF tag # 0 THEN  
				Trace.String( " (bad tag: " );  Trace.Hex( tag, -8 );  Trace.Char( ')' )  
			END;
			Trace.Ln
		END;
		RETURN ok
	END ValidPointer;
	

	(* Returns the size in bytes of the remaining free heap *)
	PROCEDURE Available( ): SIZE;
	VAR i: LONGINT;  avail: SIZE;  block: FreeBlock;
	BEGIN
		avail := 0;  i := 0;
		WHILE i <= MaxFreeLists DO
			block := freeLists[i].first;
			WHILE block # NIL  DO
				INC( avail, block.size + AddrSize );  block := block.next
			END;
			INC( i )
		END;
		RETURN avail
	END Available;
	

	(** Returns the total heap size of the Oberon system. *)
	PROCEDURE HeapSize*( ): SIZE;
	BEGIN
		RETURN heapSize;
	END HeapSize;
	
	(** none portable, only for debugging *)
	PROCEDURE InspectFreeLists*;
	BEGIN
		Machine.Acquire( Machine.Heaps );
		ShowFreeLists( "" );
		Machine.Release( Machine.Heaps );
	END InspectFreeLists;
	
	PROCEDURE GetHeapInfo*( VAR total, free, largest: SIZE );
	VAR i: LONGINT;  block: FreeBlock;
	BEGIN
		free := 0;  largest := 0;  i := 0;
		Machine.Acquire( Machine.Heaps );
		total := heapSize;
		WHILE i <= MaxFreeLists DO
			block := freeLists[i].first;
			WHILE block # NIL DO
				INC( free, block.size + AddrSize );  
				IF block.size > largest THEN  largest := block.size  END;
				block := block.next;
			END;
			INC( i )
		END;
		Machine.Release( Machine.Heaps );
	END GetHeapInfo;

	PROCEDURE Used*( ): SIZE;
	VAR used: SIZE;
	BEGIN
		Machine.Acquire( Machine.Heaps );
		used := heapSize - heapAvailable;
		Machine.Release( Machine.Heaps );
		RETURN used
	END Used;

	PROCEDURE GetHeapSize( ): SIZE;
	VAR heap: SIZE;  sb: Machine.MemoryBlock;
	BEGIN
		sb := Machine.memBlockHead;  heap := 0;
		WHILE sb # NIL DO  heap := heap + sb.size;  sb := sb.next  END;
		RETURN heap;
	END GetHeapSize;



	(*------------------ Initialization --------------------------------------------------*)

	
	(*
	(* for debugging the static linker output *)
	PROCEDURE BlockInfo( block: ADDRESS );
	VAR 
		lastElem: ADDRESS;  recSize, blockSize: SIZE;
		tag0, ttag, tag: ADDRESS;
	BEGIN
		S.GET( block, tag );
		tag0 := tag DIV 4 * 4 );
		S.GET( tag0, recSize );
		Trace.Hex( block, -8 );  Trace.Char( ' ' );  Trace.Hex( tag0, -8 ); Trace.Char( ' ' );
		IF ODD( tag DIV 2 ) THEN
			S.GET( block + AddrSize, lastElem );
			blockSize := lastElem + recSize - block;
			INC( blockSize, (-blockSize) MOD BlockSize );
			Trace.String( "array of " );  WriteType( tag0 )
		ELSE
			blockSize := recSize + AddrSize;
			INC( blockSize, (-blockSize) MOD BlockSize );
			IF tag0 # block + AddrSize THEN  
				WriteType( tag0 )
			ELSE
				S.GET( block + SysOfs, ttag );
				IF ttag = tag0 THEN  Trace.String( "sysblock" )
				ELSE
					S.GET( block + ProtOfs - AddrSize, ttag );
					IF ttag = tag0 THEN 
						Trace.String( "prot. " );
						S.GET( block + ProtOfs, ttag );  WriteType( ttag )
					ELSE
						Trace.String( "?" )
					END
				END
			END
		END;
		
		Trace.Char( ' ' );  Trace.Int( blockSize, 1 );  
		Trace.Ln
	END BlockInfo;
	*)
	
	PROCEDURE InitHeap;
	VAR adr2: ADDRESS;
		block, tag: ADDRESS;  frBlock:FreeBlock;
		n: LONGINT;
		str: ARRAY 32 OF CHAR;
	BEGIN
		n := 0;
		block := Machine.memBlockHead.beginBlockAdr;
		S.GET( block, tag );
		WHILE tag # 0 DO
		(*	IF n < 200 THEN  BlockInfo( block );  INC( n )  END;	*)
			INC( block, SizeOf( block ) );
			S.GET( block, tag );
		END;

		S.PUT( block, block + AddrSize );	(* tag *)
		S.PUT( block + AddrSize,  Machine.memBlockHead.endBlockAdr - block - AddrSize );	(* size *)
		S.PUT( block + AddrSize + SizeSize, S.VAL( ADDRESS, 0 ) );		(* next *)
	
		ClearFreeLists;
		freeLists[MaxFreeLists].first := S.VAL( FreeBlock, block );
		
		Machine.ExpandHeap( 0, 3*Machine.MemBlockSize - 2*BlockSize, S.VAL( ADDRESS, frBlock ), adr2 );
		IF frBlock # NIL  THEN  freeLists[MaxFreeLists].first.next := frBlock  END;

		heapSize := GetHeapSize();
		heapAvailable := Available();
		
		Machine.GetConfig( "DisableShrinkHeap", str );
		shrinkDisabled := str[0] = '1';
		IF shrinkDisabled THEN
			Trace.StringLn( "#### Heap shrinking disabled" );
		END
	END InitHeap;


	PROCEDURE Init;
	BEGIN
		IF Stats THEN
			Ngc := 0;
			Nmark := 0; Nmarked := 0; NfinalizeAlive := 0; NfinalizeDead := 0;
			NgcCyclesMark := 0; NgcCyclesLastRun := 0; NgcCyclesMax := 0; NgcCyclesAllRuns := 0;
		END;

		GC := EmptyProc;			(* no GC until EmptyProc gets replaced (in module Objects) *)
		nofcand := 0; 

		InitHeap;
	END Init;


BEGIN
	Init;
END Heaps.