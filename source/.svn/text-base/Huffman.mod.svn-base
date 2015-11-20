module Huffman; (** AUTHOR GF; PURPOSE "files and streams compression"; *)

import Streams, Commands, Files, Strings;

const 
	BlockSize = 8*1024;
	HTag = 00FF00F1H ;
	
type 
	HuffmanNode = object 
		var 
			freq: longint;
			left, right: HuffmanNode;		(* both nil in case of leaf *)
			pattern: char;						
		
		procedure & Init( patt: char; f: longint );
		begin
			pattern := patt;  freq := f;  left := nil;  right := nil
		end Init;
		
		procedure AddChildren( l, r: HuffmanNode );
		begin
			left := l;  right := r;  freq := l.freq + r.freq
		end AddChildren;
			
	end HuffmanNode;
	
	
	HuffmanCode = object
		var 
			wsize, bitsize: longint;
			buffer: pointer to array of longint;
			lastval, lastbits: longint;
		
		procedure &Init;
		begin  
			new( buffer, BlockSize );
			Clear
		end Init;
		
		procedure Clear;
		begin
			wsize := 0;  lastval := 0;  lastbits := 0
		end Clear;
		
		
		procedure Append( const cbits: Codebits );
		var 
			bitsize, val, addval, addbits, shift: longint;
		begin
			bitsize := cbits.bitsize;  val := cbits.val;
			if lastbits + bitsize > 32 then
				addbits := 32 - lastbits;  shift := bitsize - addbits;
				addval := lsh( val, -shift );
				lastval := lsh( lastval, addbits ) + addval;
				dec( bitsize, addbits );  dec( val, lsh( addval, shift ) );
				buffer[wsize] := lastval;  inc( wsize );  lastval := 0;  lastbits := 0
			end;
			lastval := lsh( lastval, bitsize ) + val;  inc( lastbits, bitsize );
			if lastbits = 32 then
				buffer[wsize] := lastval;  inc( wsize );  lastval := 0;  lastbits := 0
			end
		end Append;
		
		
		procedure Write( w: Streams.Writer );
		var i: longint;
		begin
			bitsize := 32*wsize + lastbits;
			if lastbits > 0 then  
				buffer[wsize] := ash( lastval, 32 - lastbits );
				inc( wsize ); 
			end;
			
			w.RawLInt( bitsize );
			for i := 0 to wsize - 1 do  w.RawLInt( buffer[i] )  end;
			w.Update
		end Write;
		
		
		procedure Read( r: Streams.Reader );
		var i, n: longint;
		begin
			r.RawLInt( bitsize );  n := (bitsize + 31) div 32;
			for i := 0 to n - 1 do  r.RawLInt( buffer[i] )  end
		end Read;
		
		
		procedure Decode( tree: HuffmanNode;  w: Streams.Writer );
		var i, x: longint; n: HuffmanNode;
		begin
			i := 0;
			repeat
				n := tree; 
				repeat
					if i mod 32 = 0 then  x := buffer[i div 32]  end;
					if ash( x, i mod 32 ) < 0 then  n := n.left  else  n := n.right  end;
					inc( i )
				until n.left = nil;	(* leaf *)
				w.Char( n.pattern )
			until i >= bitsize;
			w.Update
		end Decode;
	
	end HuffmanCode;
	
		
	Codebits = record
		bitsize: longint;
		val: longint
	end;

	
	Pattern = record
		freq: longint;
		pattern: char
	end;
	
	PatternFrequencies = pointer to array of Pattern;		(* ordered by frequency *)
	
	
	
	procedure Encode*( r: Streams.Reader;  w: Streams.Writer );
	var 
		buffer: HuffmanCode;  i, chunk: longint;
		codeTable: array 256 of Codebits;
		pf: PatternFrequencies;
		plaintext: array BlockSize of char;
	begin 
		new( buffer );
		w.RawLInt( HTag );
		loop
			r.Bytes( plaintext, 0, BlockSize, chunk );
			if chunk < 1 then  exit  end;
			pf := CountPatterns( plaintext, chunk );
			WriteFrequencies( pf, w );
			InitCodeTable( codeTable, NewHuffmanTree( pf ) );
			buffer.Clear; 
			for i := 0 to chunk - 1 do  
				buffer.Append( codeTable[ord( plaintext[i] )] );
			end;
			buffer.Write( w );
		end
	end Encode;
	
		
	procedure Decode*( r: Streams.Reader;  w: Streams.Writer; var msg: array of char ): boolean;
	var 
		tree: HuffmanNode;
		buffer: HuffmanCode;
		tag: longint;
	begin 
		r.RawLInt( tag );
		if tag # HTag  then
			msg := "Huffman.Decode: bad input (compressed stream expected)"; 
			return false
		end;
		new( buffer );
		while r.Available( ) >= 11 do
			tree := NewHuffmanTree( ReadFrequencies( r ) );
			buffer.Clear;  
			buffer.Read( r );
			buffer.Decode( tree,  w )
		end;
		return true
	end Decode;
		
	
	procedure CountPatterns( const block: array of char; blksize: longint ): PatternFrequencies;
	var 
		i, n, start: longint;
		a: array 256 of Pattern;
		pf: PatternFrequencies;
		
			procedure Quicksort( low, high: longint );  
			var 
				i, j, m: longint;  tmp: Pattern;
			begin
				if low < high then
					i := low;  j := high;  m := (i + j) div 2;
					repeat
						while a[i].freq < a[m].freq do  inc( i )  end;
						while a[j].freq > a[m].freq do  dec( j )  end;
						if i <= j then
							if i = m then  m := j
							elsif j = m then  m := i
							end;
							tmp := a[i];  a[i] := a[j];  a[j] := tmp;
							inc( i );  dec( j )
						end;
					until i > j;
					Quicksort( low, j );  Quicksort( i, high )
				end
			end Quicksort;
	
	begin
		for i := 0 to 255 do   
			a[i].pattern := chr( i );  a[i].freq := 0
		end;
		i := 0;
		while i < blksize do  inc( a[ord( block[i] )].freq );  inc( i )  end;
		Quicksort( 0, 255 );
		i := 0;
		while a[i].freq = 0 do  inc( i )  end;	(* skip unused patterns *)
		n := 256 - i;  start := i;
		new( pf, n );
		for i := 0 to n - 1 do  pf[i] := a[start + i]  end;
		return pf
	end CountPatterns;
		
	
	
	procedure NewHuffmanTree( pf: PatternFrequencies ): HuffmanNode;
	var 
		i, start, top: longint;  n, n2: HuffmanNode;
		a: pointer to array of HuffmanNode;
	begin
		start := 0;  top := len( pf^ ) - 1;
		new( a, len( pf^ ) );
		for i := 0 to len( pf^ ) -1 do
			new( a[i], pf[i].pattern, pf[i].freq )
		end;
		if start = top then  
			(* the whole, probably last small block contains only one pattern *)
			new( n, 0X, 0 );  new( n2, 0X, 0 );  n.AddChildren( n2, a[start] );
			return n  
		end;
		while start < top do  
			new( n, 0X, 0 );  n.AddChildren( a[start], a[start+1] ); 
			i := start + 1;  
			while (i < top) & (a[i+1].freq < n.freq) do  a[i] := a[i+1];  inc( i )  end;
			a[i] := n;  
			inc( start );
		end;
		return a[start]
	end NewHuffmanTree;
	
	
	procedure InitCodeTable( var table: array of Codebits; huffmanTree: HuffmanNode );
	var 
		start: Codebits;
	
		procedure Traverse( node: HuffmanNode;  bits: Codebits );
		begin
			if node.left = nil then  (* leaf *)
				table[ord( node.pattern )] := bits;
			else
				inc( bits.bitsize );  
				bits.val := 2*bits.val;  Traverse( node.right, bits );	(* ..xxx0 *)
				bits.val := bits.val + 1;  Traverse( node.left, bits );	(* ..xxx1 *)
			end;
		end Traverse;
	
	begin
		start.bitsize := 0;  start.val := 0;
		Traverse( huffmanTree, start );
	end InitCodeTable;
	
	
	procedure ReadFrequencies( r: Streams.Reader ): PatternFrequencies;
	var
		i, n: longint; 
		pf: PatternFrequencies;
	begin
		r.RawNum( n );  
		new( pf, n );
		for i := 0 to n - 1 do
			r.RawNum( pf[i].freq );  r.Char( pf[i].pattern ); 
		end;
		return pf
	end ReadFrequencies;
	
	procedure WriteFrequencies( pf: PatternFrequencies; w: Streams.Writer );
	var i, n: longint;
	begin
		n := len( pf^ );
		w.RawNum( n );
		for i := 0 to n - 1 do 
			w.RawNum( pf[i].freq );  w.Char( pf[i].pattern );
		end;
	end WriteFrequencies;
	
	
	procedure EncodeFile*( c: Commands.Context );
	var
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2, name3: array 128 of char;
		res: longint;
	begin
		if c.arg.GetString( name1 ) then
			if ~c.arg.GetString( name2 ) then
				name2 := name1;
				Strings.Append( name2, ".hc" )
			end;
			if Files.Old( name2 ) # nil then
				name3 := name2;  Strings.Append( name3, ".Old" );
				Files.Rename( name2, name3, res )
			end;
			f1 := Files.Old( name1 );
			if f1 # nil then
				f2 := Files.New( name2 );
				Files.OpenReader( r, f1, 0 ); Files.OpenWriter( w, f2, 0 );
				Encode( r, w );
				w.Update;
				Files.Register( f2 )
			else
				c.error.String( "could not open file  " ); c.error.String( name1 ); c.error.Ln
			end
		else
			c.error.String( "usage: Huffman.EncodeFile filename [filename] ~ " ); c.error.Ln;
		end;
		c.error.Update
	end EncodeFile;
	
	
	procedure DecodeFile*( c: Commands.Context );
	var
		f1, f2: Files.File;
		r: Files.Reader;  w: Files.Writer;
		name1, name2, name3, msg: array 128 of char;
		l, res: longint;
	begin
		if c.arg.GetString( name1 ) then
			if ~c.arg.GetString( name2 ) then
				name2 := name1;
				l := Strings.Length( name2 );
				if (name2[l-3] = '.') & (name2[l-2] = 'h') & (name2[l-1] = 'c') then  name2[l-3] := 0X  
				else Strings.Append( name2, ".uncomp" )
				end;
				if Files.Old( name2 ) # nil then
					name3 := name2;  Strings.Append( name3, ".Old" );
					Files.Rename( name2, name3, res )
				end
			end;
			f1 := Files.Old( name1 );
			if f1 # nil then
				f2 := Files.New( name2 );
				Files.OpenReader( r, f1, 0 );	 Files.OpenWriter( w, f2, 0 );
				if Decode( r, w, msg ) then
					w.Update;
					Files.Register( f2 )	
				else
					c.error.String( msg ); c.error.Ln
				end
			else
				c.error.String( "could not open file  " ); c.error.String( name1 ); c.error.Ln
			end
		else
			c.error.String( "usage: Huffman.DecodeFile filename [filename] ~ " ); c.error.Ln;
		end;
		c.error.Update
	end DecodeFile;
	


end Huffman.


	Huffman.EncodeFile   Huffman.mod ~
	Huffman.EncodeFile   Huffman.Obj ~
	Huffman.EncodeFile   uebung01.pdf ~
	
	Huffman.DecodeFile   Huffman.mod.hc  TTT.mod ~
	Huffman.DecodeFile   Huffman.Obj.hc  TTT.Obj ~
	Huffman.DecodeFile   uebung01.pdf.hc  TTT.pdf ~
	
	SystemTools.Free Huffman ~
