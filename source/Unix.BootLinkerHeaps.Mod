(* ETH Oberon, Copyright 2000 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE BootLinkerHeaps;   (** AUTHOR "G.F." ; PURPOSE "UnixAos bootlinker"; *)

(* based on Oberon for Windows bootlinker (MH) and  MIPS bootlinker (RC) *)


IMPORT S := SYSTEM, Streams;

CONST	
	AddrSize = SIZEOF( ADDRESS );
	SizeSize = SIZEOF( SIZE );

	BootHeapSize* = 2*1024*1024;  MaxReloc = 10000;  

	NilVal* = 0;		
	BlockSize* = 32;	(* must be a mutiple of 32 *)
	ProtOfs = 2*BlockSize + 16;
	ArrayAlignment = 8;
	HeapBlockOffset = - 2*AddrSize;
	TypeDescOffset = -AddrSize;
	
	ProtTypeBit* = 31;   (* flags in TypeDesc, low bits reserved for extLevel *)
	
	FlagsOfs = AddrSize * 3;			(* flags offset in TypeDesc *)
	
TYPE	
	RootObject* = OBJECT 
		PROCEDURE FindRoots*;	(** abstract *)
		BEGIN HALT( 301 ) END FindRoots;
	END RootObject;
	
	StaticTypeBlock*= POINTER TO StaticTypeDesc;
	StaticTypeDesc = RECORD
		recSize: SIZE;
		pointerOffsets* {UNTRACED}: PointerOffsets;
	END;

	PointerOffsets = POINTER TO ARRAY OF SIZE;
		
	
VAR
	error: Streams.Writer;
	

	heapAdr-	: ADDRESS;
	beginFree-	: ADDRESS;

	relocAddr-: ARRAY MaxReloc OF ADDRESS;
	numRelocations-: LONGINT;





	PROCEDURE Error( CONST str: ARRAY OF CHAR );
	BEGIN
		error.Ln;
		error.String( "Error: " );  error.String( str );  
		error.Ln; 
	END Error;
	
	
	

	PROCEDURE Relocate*( adr: ADDRESS );
	VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO numRelocations - 1 DO
			IF relocAddr[i] = adr THEN
				Error( "same ptr location marked twice for fixing, ignored" );	
				RETURN
			END
		END;
		IF numRelocations # -1 THEN
			IF numRelocations < MaxReloc THEN  relocAddr[numRelocations] := adr;  INC( numRelocations )
			ELSE  Error( "Too many relocations" );  numRelocations := -1
			END
		END
	END Relocate;
	
	
	PROCEDURE ClearMem( a: ADDRESS; len: SIZE );
	VAR  top: ADDRESS;
	BEGIN
		top := a + len;
		WHILE (a MOD 4 # 0) & (a < top) DO  S.PUT( a, S.VAL( SHORTINT, 0 ) );  INC( a )  END;
		WHILE a <= top - 4 DO  S.PUT( a, S.VAL( LONGINT, 0 ) );  INC( a, 4 )  END;
		WHILE a < top DO  S.PUT( a, S.VAL( SHORTINT, 0 ) );  INC( a )  END;
	END ClearMem;


	PROCEDURE NewBlock( size: SIZE ): ADDRESS;   (* size MOD B = 0 *)
	VAR rsize, rest: SIZE;  ptr, restptr: ADDRESS;
	BEGIN
		ptr := beginFree;
		ASSERT( ptr MOD BlockSize = BlockSize - AddrSize );
		S.GET( ptr + AddrSize, rsize );
		IF rsize + AddrSize < size  THEN  
			Error( "Pseudo-heap too small" );  HALT( 99 )  
		END;
		rest := rsize + AddrSize - size;
		IF rest > 0 THEN  (* >= B >= 16 *)
			restptr := ptr + size;
			S.PUT( restptr, restptr + AddrSize );
			S.PUT( restptr + AddrSize, rest - AddrSize );
			S.PUT( restptr + 2*AddrSize, 0 );
			beginFree := restptr
		ELSE
			beginFree := 0
		END;
		RETURN ptr
	END NewBlock;


	PROCEDURE NewSys*( VAR p: ANY;  size: SIZE );   (* implementation of SYSTEM.NEW(ptr, size) *)
	VAR adr: ADDRESS;
	BEGIN
		INC( size, AddrSize + 24 );  INC( size, (-size) MOD BlockSize );
		adr := NewBlock( size ) + AddrSize;
		ClearMem( adr, size - AddrSize );
		S.PUT( adr - AddrSize, adr );				Relocate( adr - AddrSize );
		S.PUT( adr, size - AddrSize );
		S.PUT( adr + SizeSize, S.VAL( SIZE, -AddrSize ) );
		S.PUT( adr + 24 - AddrSize, adr );		Relocate( adr + 24 - AddrSize );
		p := S.VAL( ANY, adr + 24 );
	END NewSys;


	PROCEDURE NewRec*( VAR p: ANY;  tag: ADDRESS );   (* implementation of NEW( ptr ) *)
	VAR adr: ADDRESS;  typ: ADDRESS;  flags: SET; size: SIZE;
	BEGIN
		S.GET( tag - AddrSize, typ );   (* will be replaced by direct compiler call of NewProtObj *)
		S.GET( typ + FlagsOfs, flags );
		IF ProtTypeBit IN flags THEN  (* protected record *)
			NewProtRec( S.VAL( ANY, p ), tag );
		ELSE
			S.GET( tag, size );
			INC( size, AddrSize ); INC( size, (-size) MOD BlockSize );
			adr := NewBlock( size ) + AddrSize;
			S.PUT( adr - AddrSize, tag );			Relocate( adr - AddrSize );
			ClearMem( adr, size - AddrSize );
			p := S.VAL( ANY, adr )
		END
	END NewRec;


	PROCEDURE NewProtRec*( VAR p: ANY;  tag: ADDRESS );
	VAR recSize, blockSize: SIZE;  adr, ptr: ADDRESS;
	BEGIN
		S.GET( tag, recSize );
		(* add space for tag and header and round up to BlockSize *)
		blockSize := recSize + ProtOfs + AddrSize;  INC( blockSize, (-blockSize) MOD BlockSize );
		adr := NewBlock( blockSize ) + AddrSize;
		ClearMem( adr, blockSize - AddrSize );   (* clear everything *)
		S.PUT( adr - AddrSize, adr );				Relocate( adr - AddrSize );
		S.PUT( adr, blockSize - AddrSize );		(* size *)
		
		ptr := adr + ProtOfs;
		S.PUT( ptr + HeapBlockOffset, adr );		Relocate( ptr + HeapBlockOffset );
		S.PUT( ptr + TypeDescOffset, tag );		Relocate( ptr + TypeDescOffset );
		
		p := S.VAL( ANY, ptr );
	END NewProtRec;
	
	
	PROCEDURE ArraySize*( numElems: LONGINT; elemSize: SIZE; numDims: LONGINT ): SIZE;
	VAR arrSize, dataOffs: SIZE;
	BEGIN
		arrSize := numElems * elemSize;
		dataOffs := 3*AddrSize + numDims*AddrSize;  INC( dataOffs, (-dataOffs) MOD ArrayAlignment ); 
		RETURN dataOffs + arrSize
	END ArraySize;


	PROCEDURE NewArr*( VAR ptr: ANY; eltag: ADDRESS;  nofelem, nofdim: LONGINT );
	(* implementation of NEW(ptr, dim0,  ...) *)
	VAR 
		blockSize, elSize, arrSize, dataOffs: SIZE;  firstElem, adr: ADDRESS;
	BEGIN
		ASSERT( (nofdim = 1) & (nofelem > 0) );   (* bootloader limit *)
		S.GET( eltag, elSize );
		arrSize := nofelem*elSize;	
		dataOffs := 3*AddrSize + nofdim*AddrSize;  INC( dataOffs, (-dataOffs) MOD ArrayAlignment );  
		
		blockSize := AddrSize + dataOffs + arrSize;  INC( blockSize, (-blockSize) MOD BlockSize );
		adr := NewBlock( blockSize ) + AddrSize;
		
		S.PUT( adr - AddrSize, eltag + 2 (*ArrayBit*) );	Relocate( adr - AddrSize );
		ClearMem( adr, blockSize - AddrSize );
		firstElem := adr + dataOffs;
		S.PUT( adr, firstElem + arrSize - elSize );			Relocate( adr );
			(*  adr + 1*AddrSize is reserved for mark phase (old non recursive Mark) *)
		S.PUT( adr + 2*AddrSize, firstElem );				Relocate( adr + 2*AddrSize );
		S.PUT( adr + 3*AddrSize, nofelem );		(* dimension 0 *)
				
		ptr := S.VAL( ANY, adr )
	END NewArr;
	


	PROCEDURE FillStaticType*( VAR staticTypeAddr: ADDRESS;
								startAddr, typeInfoAdr: ADDRESS;
								size, recSize: SIZE;
								numPtrs, numSlots: LONGINT );
	VAR 
		p, offset: ADDRESS;  sTB {UNTRACED}: StaticTypeBlock;
	BEGIN
		ClearMem( startAddr, size );	(* clear whole static type, size MOD AddressSize = 0 implicitly, see WriteType in PCOF.Mod *)
		S.PUT( startAddr, S.VAL( ADDRESS, -AddrSize ) );	(* sentinel *)

		(* methods and tags filled in later *)
		
		offset := AddrSize*(numSlots + 1 + 1);  (* #methods, max. no. of tags, method end marker (sentinel), pointer to type information*)
		p := startAddr + offset;
		S.PUT( p - AddrSize, typeInfoAdr ); 	(* pointer to typeInfo *) Relocate( p - AddrSize );
		sTB := S.VAL( StaticTypeBlock, p );
		sTB.recSize := recSize;
		staticTypeAddr := p;
		
		(* create the pointer for the dynamic array of pointer offsets, the dynamic array of pointer offsets 
		    is stored in the static type descriptor, it has no header part *)
		INC( p, SIZEOF(StaticTypeDesc) );
		IF p MOD (2 * AddrSize) # 0 THEN  INC( p, AddrSize )  END;
		S.PUT( p + 3 * AddrSize, numPtrs ); (* internal structure of dynamic array without pointers: the first 3 fields are unused *)
		sTB.pointerOffsets := S.VAL( PointerOffsets, p ); (* the fourth field contains the dimension of the array *)
		Relocate( ADDRESSOF( sTB.pointerOffsets ) )

		(* ptrOfs filled in later *)

	END FillStaticType;
	
	



	PROCEDURE Initialize*( w: Streams.Writer );
	VAR heap, firstBlock: ADDRESS;  i: LONGINT;  size: SIZE;
	BEGIN
		error := w;
		
		S.NEW( S.VAL( ANY, heap ), BootHeapSize );
		
		FOR i := 0 TO MaxReloc -1 DO  relocAddr[i] := 0  END;
		numRelocations := 0;

		heapAdr := heap + (-heap) MOD BlockSize;
		firstBlock := heapAdr + BlockSize - AddrSize;
		size := heap + BootHeapSize - firstBlock;  DEC( size, size MOD BlockSize );
		S.PUT( firstBlock, firstBlock + AddrSize );
		S.PUT( firstBlock + AddrSize, size - AddrSize );
		S.PUT( firstBlock + 2*AddrSize, ADDRESS( 0 ) );
		beginFree := firstBlock ;
	END Initialize;



END BootLinkerHeaps.




