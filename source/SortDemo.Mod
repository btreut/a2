MODULE SortDemo;	(** AUTHOR "g.f."; PURPOSE sort demo *)

(* this is an A2-port of the SortDemo done by W.Weck in 1993 for Oberon V4 *)

IMPORT
	Raster, Random, WMRectangles, Strings, WMMessages,
	WM := WMWindowManager, WMComponents, WMStandardComponents,
	Log := KernelLog, Clock, Kernel, Machine;
	
CONST
	N = 120;  ElemSize = 5;
	MaxConcurrentSorters = 5;	(* assuming we have 6 processor cores *)
	WindowSize = N*ElemSize;
	
TYPE	
	SortData = POINTER TO ARRAY N OF LONGINT;

	ArrayView* =  OBJECT (WM.BufferWindow)		
	VAR
		cw: ControlWindow;
		white, grey, col1, yellow: Raster.Pixel;
		data: SortData;
		
		sortname: ARRAY 32 OF CHAR;
		random: Random.Generator;
		delay: LONGINT;
		concSorters: LONGINT;
		nofcomps, nofswaps: LONGINT; 
		
		
		PROCEDURE &New( win: ControlWindow );
		VAR d, t: LONGINT;
		BEGIN
			cw := win;
			Init( WindowSize, WindowSize, FALSE );
			manager := WM.GetDefaultManager();
			manager.Add( 40, 250, SELF, {WM.FlagFrame, WM.FlagClose, WM.FlagNoResizing} );
			SetTitle( Strings.NewString( "SortArray" ) );
			Raster.SetRGB( white, 255, 255, 255 );
			Raster.SetRGB( yellow, 255, 255, 0 );
			Raster.SetRGB( grey, 110, 110, 110 );
			Raster.SetRGB( col1, 210, 140, 75 );
			
			NEW( random );  Clock.Get( t, d );  random.InitSeed( t );
			delay := 16;
			
			NEW( data );  OrderData;
		END New;
		
		
		PROCEDURE Handle( VAR x: WMMessages.Message );
		BEGIN
			IF x.msgType = WMMessages.MsgClose THEN  cw.Close  ELSE  Handle^( x )  END
		END Handle;
		
		
		PROCEDURE InitSort;
		BEGIN
			nofcomps := 0;  nofswaps := 0
		END InitSort;
		
		PROCEDURE FinishSort;
		BEGIN
			Log.String( sortname );  Log.String( ": " ); 
			Log.Int( nofcomps, 1 );  Log.String( " compares, " );
			Log.Int( nofswaps, 1 );  Log.String( " swaps, " );
			Log.Ln;
		END FinishSort;
		
		
		PROCEDURE DrawElement( n: LONGINT );
		VAR mode: Raster.Mode;
			x, y, len: LONGINT;
		BEGIN
			len := data[n];
			x := ElemSize*n;  y := WindowSize - 1 - ElemSize*len;
			Raster.InitMode( mode, Raster.srcCopy );
			IF len < N THEN  Raster.Fill( img, x, 0, x+ElemSize, y, white, mode )  END;
			Raster.Fill( img, x, y+1, x+ElemSize, y+ElemSize+1, col1, mode );
			IF len > 1 THEN  
				Raster.Fill( img, x, y+ElemSize+1, x+1, WindowSize, white, mode );
				Raster.Fill( img, x+1, y+ElemSize+1, x+ElemSize-1, WindowSize, grey, mode );
				Raster.Fill( img, x+ElemSize-1, y+ElemSize+1, x+ElemSize, WindowSize, white, mode );
			END;
		END DrawElement;
		
		
		PROCEDURE Highlight( n: LONGINT );
		VAR mode: Raster.Mode;
			x, y, len: LONGINT;
		BEGIN
			len := data[n];
			x := ElemSize*n;  y := WindowSize - 1 - ElemSize*len;
			Raster.InitMode( mode, Raster.srcCopy );
			IF len > 1 THEN  
				Raster.Fill( img, x+1, y+ElemSize+1, x+ElemSize-1, WindowSize, yellow, mode )  
			END;
		END Highlight;
		
		PROCEDURE Clear( n: LONGINT );
		VAR mode: Raster.Mode;
			x, y, len: LONGINT;
		BEGIN
			len := data[n];
			x := ElemSize*n;  y := WindowSize - 1 - ElemSize*len;
			Raster.InitMode( mode, Raster.srcCopy );
			IF len > 1 THEN  
				Raster.Fill( img, x+1, y+ElemSize+1, x+ElemSize-1, WindowSize, grey, mode )  
			END;
		END Clear;
		
		
		PROCEDURE Update;
		BEGIN
			Invalidate( WMRectangles.MakeRect( 0, 0, GetWidth(), GetHeight() ) );
		END Update;
		
		PROCEDURE Randomize( n: LONGINT );
		VAR i, j, k: LONGINT;  t: Kernel.Timer;
		BEGIN
			NEW(t);
			FOR i := 1 TO n DO
				j := random.Dice( N );  k := random.Dice( N );
				Swap( j, k );
				IF i MOD 16 = 0 THEN  t.Sleep(10)  END;
			END
		END Randomize;
		
		
		PROCEDURE OrderData;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO N-1 DO  data[i] := i + 1;  DrawElement( i )  END;
			Update
		END OrderData;
		
		PROCEDURE RevOrderData;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO N-1 DO  data[i] := N - i;  DrawElement( i )  END;
			Update
		END RevOrderData;
		
		PROCEDURE BadOrder;	(* worst case for quicksort *)
		VAR i, m: LONGINT;
		BEGIN
			m := (N - 1) DIV 2;
			FOR i := 0 TO m-1 DO  data[i] := i + 1  END;
			data[m] := N;
			FOR i := m+1 TO N-1 DO  data[i] := i   END;
			
			FOR i := 0 TO N-1 DO  DrawElement( i )  END;
			Update
		END BadOrder;
		
		PROCEDURE Swap( i, j: LONGINT );
		VAR tmp: LONGINT;  t: Kernel.Timer;
		BEGIN
			IF i # j THEN
				tmp := data[i];  data[i] := data[j];  data[j] := tmp;
				DrawElement( i );  DrawElement( j );
				Update;
				IF delay # 0 THEN  NEW( t );  t.Sleep( delay )  END; 
				Machine.AtomicInc( nofswaps )
			END
		END Swap;
		
		PROCEDURE Less( i, j: LONGINT ): BOOLEAN;
		VAR t: Kernel.Timer;
		BEGIN
			IF delay # 0 THEN
				Highlight( i );  Highlight( j );  Update;  
				NEW( t );  t.Sleep( delay); 
				Clear( i ); Clear( j );  Update;
			END;
			Machine.AtomicInc( nofcomps );
			RETURN data[i] < data[j];
		END Less;
		
		PROCEDURE DecSpeed;
		BEGIN
			IF delay # 0 THEN  delay := 2*delay  ELSE  delay := 4 END;
			Log.String( "delay: " ); Log.Int( delay, 1 );  Log.Ln
		END DecSpeed;
		
		PROCEDURE IncSpeed;
		BEGIN
			IF delay > 4 THEN  delay := delay DIV 2   ELSE  delay := 0 END;
			Log.String( "delay: " ); Log.Int( delay, 1 );  Log.Ln
		END IncSpeed;
		
		
		PROCEDURE BubbleSort;
		VAR i, n, swaps: LONGINT; 
		BEGIN
			sortname := "BubbleSort";
			n := N - 2;
			REPEAT
				swaps := 0;  
				FOR i := 0 TO n DO
					IF Less( i + 1, i )  THEN  Swap( i, i + 1 );  INC( swaps )  END
				END;
				DEC( n )
			UNTIL swaps = 0;
		END BubbleSort;
		
		
		
		PROCEDURE SelectSort;
		VAR i, j, min: LONGINT;
		BEGIN
			sortname := "SelectSort";
			FOR i := 0 TO N-1 DO
				min := i;  j := i + 1;
				FOR j := i+1 TO N-1 DO
					IF Less( j, min ) THEN  min := j  END
				END;
				IF i # min THEN  Swap( i, min )  END
			END
		END SelectSort;
		
		
		
		PROCEDURE ShellSort;
		VAR i, j, h: LONGINT;
		BEGIN
			sortname := "ShellSort";
			i := 4;  h := 1;
			WHILE i < N DO  i := i*2;  h := h*2 + 1  END;
			WHILE h # 0 DO
				i := h;
				WHILE i < N DO
					j := i - h;
					WHILE (j >= 0) & Less( j + h, j ) DO  Swap( j, j + h );  j := j - h  END;
					INC( i )
				END;
				h := (h - 1) DIV 2
			END;
		END ShellSort;
		
	
				
		PROCEDURE QuickSort;
		BEGIN
			sortname := "QuickSort";
			Quick( 0, N-1, FALSE );
		END QuickSort;
		
	
		PROCEDURE ConcQuickSort;
		VAR t: Kernel.Timer;
		BEGIN
			sortname := "QuickSort";
			concSorters := 0;
			Quick( 0, N-1, TRUE );
			(* now wait until all concurrent activities have finished *)
			NEW( t );  WHILE concSorters > 0 DO  t.Sleep( 50 )  END
		END ConcQuickSort;
		
		PROCEDURE Quick( lo, hi: LONGINT; conc: BOOLEAN );
		VAR i, j, m: LONGINT;
			concurrentSorter: ConcurrentQuick;
		BEGIN
			IF lo < hi THEN
				i := lo;  j := hi;  m := (lo + hi) DIV 2;
				REPEAT
					WHILE Less( i, m ) DO  INC( i )  END;
					WHILE Less( m, j ) DO  DEC( j )  END;
					IF i <= j THEN
						IF m = i THEN  m := j
						ELSIF m = j THEN  m := i
						END;
						Swap( i, j );  INC( i );  DEC( j )
					END
				UNTIL i > j;
				IF conc & (concSorters < MaxConcurrentSorters) THEN  
					NEW( concurrentSorter, SELF, lo, j );  Quick( i, hi, conc )
				ELSE
					Quick( lo, j, conc );  Quick( i, hi, conc )
				END
			END;
		END Quick;
	
	
		PROCEDURE HeapSort;
		VAR l, r: LONGINT;
		
			PROCEDURE Sift( l, r: LONGINT );
			VAR i, j: LONGINT;
			BEGIN
				i := l;  j := 2*l + 1;
				IF (j + 1 < r) & Less( j, j + 1 ) THEN  INC( j )  END;
				WHILE (j < r) & ~Less( j, i ) DO
					Swap( i, j );
					i := j;  j := 2*j + 1;
					IF (j + 1 < r) & Less( j, j + 1 ) THEN  INC( j )  END
				END
			END Sift;
			
		BEGIN
			sortname := "HeapSort";
			r := N;  l := N DIV 2;
			WHILE l > 0 DO  DEC( l );  Sift( l, r )  END;
			WHILE r > 0 DO  DEC( r );  Swap( 0, r );  Sift( 0, r )  END;
		END HeapSort;
		
		
		
		PROCEDURE SmoothSort;  	(* W.Weck 21 Jan 93, SmoothSort due to E.W.Dijkstra, J.Gutknecht *)
		VAR q, r, p, b, c: LONGINT;  

			PROCEDURE up( VAR b, c: LONGINT );  
			VAR b1: LONGINT;  
			BEGIN  b1 := b;  b := b + c + 1;  c := b1 
			END up;  

			PROCEDURE down( VAR b, c: LONGINT );  
			VAR c1: LONGINT;  
			BEGIN  c1 := c;  c := b - c - 1;  b := c1 
			END down;  

			PROCEDURE sift( r, b, c: LONGINT );  
			VAR r1: LONGINT;  
			BEGIN 
				WHILE b >= 3 DO  r1 := r - b + c;  
					IF Less( r1, r - 1 ) THEN  r1 := r - 1;  down( b, c )  END;  
					IF Less( r, r1 ) THEN  Swap( r, r1 );  r := r1;  down( b, c )  ELSE  b := 1  END  
				END  
			END sift;  

			PROCEDURE trinkle( r, p, b, c: LONGINT );  
			VAR r1, r2: LONGINT;  
			BEGIN 
				WHILE p > 0 DO  
					WHILE ~ODD( p ) DO  p := p DIV 2;  up( b, c )  END;  
					r2 := r - b;  
					IF (p = 1) OR ~Less( r, r2 ) THEN  p := 0  
					ELSE  p := p - 1;  
						IF b = 1 THEN  Swap( r, r2 );  r := r2  
						ELSE  r1 := r - b + c;  
							IF Less( r1, r - 1 ) THEN  r1 := r - 1;  down( b, c );  p := p*2  END;  
							IF ~Less( r2, r1 ) THEN  Swap( r, r2 );  r := r2  ELSE  Swap( r, r1 );  r := r1;  down( b, c );  p := 0  END  
						END  
					END  
				END;  
				sift( r, b, c ) 
			END trinkle;  

			PROCEDURE semiTrinkle( r, p, b, c: LONGINT );  
			VAR r1: LONGINT;  
			BEGIN  r1 := r - c;  
				IF Less( r, r1 ) THEN  Swap( r, r1 );  trinkle( r1, p, b, c )  END  
			END semiTrinkle;  

		BEGIN 
			sortname := "SmoothSort";
			q := 1;  r := 0;  p := 1;  b := 1;  c := 1;  
			WHILE q # N DO  
				IF p MOD 8 = 3 (* p = ... 011 *) THEN  
					sift( r, b, c );  p := (p + 1) DIV 4;  up( b, c );  up( b, c ) (* b >= 3 *)
				ELSE  (* p = ... 01 *)
					IF (q + c) < N THEN  sift( r, b, c )  ELSE  trinkle( r, p, b, c )  END;  
					down( b, c );  p := p*2;  
					WHILE b # 1 DO  down( b, c );  p := p*2  END;  
					p := p + 1 
				END;  
				q := q + 1;  r := r + 1 
			END;  
			trinkle( r, p, b, c );  
			WHILE q # 1 DO  q := q - 1;  p := p - 1;  
				IF b = 1 THEN  r := r - 1;  
					WHILE ~ODD( p ) DO  p := p DIV 2;  up( b, c )  END  
				ELSE  (* b >= 3 *)  r := r - b + c;  
					IF p > 0 THEN  semiTrinkle( r, p, b, c )  END;  
					down( b, c );  p := p*2 + 1;  r := r + c;  semiTrinkle( r, p, b, c );  down( b, c );  p := p*2 + 1 
				END  
			END;  
		END SmoothSort;  
		
	END ArrayView;
	
	
	
	ConcurrentQuick = OBJECT
	VAR 
		lo, hi: LONGINT;  
		av: ArrayView;
			
		PROCEDURE &Init ( sdw: ArrayView;  low, high: LONGINT );
		BEGIN
			av := sdw;
			lo := low; hi := high; 
		END Init;
				
	BEGIN {ACTIVE}
		Machine.AtomicInc( av.concSorters );
		av.Quick( lo, hi, TRUE );
		Machine.AtomicDec( av.concSorters )
	END ConcurrentQuick;	
	
	
	SortProcedure = PROCEDURE {DELEGATE};
	
	Sorter = OBJECT
	VAR
		sort: SortProcedure;
		av: ArrayView;
		running, terminated: BOOLEAN;
		
		PROCEDURE &Init( win: ArrayView );
		BEGIN
			sort := NIL;  av := win;  
			running := FALSE;  terminated := FALSE
		END Init;
				
		PROCEDURE Start( proc: SortProcedure );
		BEGIN
			IF ~running THEN
				BEGIN {EXCLUSIVE}  sort := proc  END
			END
		END Start;
		
		PROCEDURE Terminate;
		BEGIN {EXCLUSIVE}
			terminated := TRUE
		END Terminate;
					
	BEGIN {ACTIVE}
		BEGIN {EXCLUSIVE}
			REPEAT
				AWAIT( (sort # NIL) OR terminated );
				IF ~terminated THEN
					running := TRUE;
					av.InitSort;  sort;  av.FinishSort;
					running := FALSE;
				END;
				sort := NIL
			UNTIL terminated
		END
	END Sorter;
	
	
	ControlWindow = OBJECT( WMComponents.FormWindow )
		VAR
			toolbar: WMStandardComponents.Panel;
			button : WMStandardComponents.Button;
			
			av: ArrayView;
			sorter: Sorter;
			

			PROCEDURE &New;
			VAR vc: WMComponents.VisualComponent;
			BEGIN
				vc := CreateForm();
				Init( vc.bounds.GetWidth(), vc.bounds.GetHeight(), FALSE );
				SetContent( vc );
				SetTitle( WM.NewString( "Sort Demo" ) );
				WM.DefaultAddWindow( SELF );
				NEW( av, SELF );
				NEW( sorter, av )
			END New;
			
			PROCEDURE Handle( VAR x: WMMessages.Message );
			BEGIN
				IF x.msgType = WMMessages.MsgClose THEN  Close  ELSE  Handle^( x )  END
			END Handle;
			
			PROCEDURE Close;
			BEGIN
				sorter.Terminate;  av.Close;  Close^
			END Close;


			PROCEDURE CreateForm( ): WMComponents.VisualComponent;
			VAR
				panel: WMStandardComponents.Panel;
				label : WMStandardComponents.Label;
			BEGIN
				NEW( panel );
					panel.bounds.SetWidth( 560 );
					panel.bounds.SetHeight( 60 );
					panel.fillColor.Set( LONGINT( 0FFFFFFFFH ) );
				
				
				NEW( toolbar );
					toolbar.bounds.SetHeight( 20 );
					toolbar.alignment.Set( WMComponents.AlignTop );
					toolbar.fillColor.Set( LONGINT( 0CCCCCCFFH ) );

				NEW( label );
					label.bounds.SetWidth( 80 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( " Array init: " );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);


				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " order " );
					button.onClick.Add( Order );
				toolbar.AddContent( button );
				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " rev. order " );
					button.onClick.Add( RevOrder );
				toolbar.AddContent( button );
				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " bad order " );
					button.onClick.Add( BadOrder );
				toolbar.AddContent( button );

				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " rand 10 " );
					button.onClick.Add( Rand10 );
				toolbar.AddContent( button );
				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " rand 100 " );
					button.onClick.Add( Rand100 );
				toolbar.AddContent( button );
				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " rand 200 " );
					button.onClick.Add( Rand200 );
				toolbar.AddContent( button );
				
				panel.AddContent( toolbar );	

				NEW( toolbar );
					toolbar.bounds.SetHeight( 20 );
					toolbar.alignment.Set( WMComponents.AlignTop );
					toolbar.fillColor.Set( LONGINT( 0CCCCCCFFH ) );

				NEW( label );
					label.bounds.SetWidth( 80 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( " Sorter: " );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);


				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Bubble " );
					button.onClick.Add( StartBubbleSort );
				toolbar.AddContent( button );
				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Select " );
					button.onClick.Add( StartSelectSort );
				toolbar.AddContent( button );
				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Shell " );
					button.onClick.Add( StartShellSort );
				toolbar.AddContent( button );

				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Quick " );
					button.onClick.Add( StartQuickSort );
				toolbar.AddContent( button );
				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Heap " );
					button.onClick.Add( StartHeapSort );
				toolbar.AddContent( button );
				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " Smooth " );
					button.onClick.Add( StartSmoothSort );
				toolbar.AddContent( button );
				
				panel.AddContent( toolbar );
				
				
				NEW( toolbar );
					toolbar.bounds.SetHeight( 20 );
					toolbar.alignment.Set( WMComponents.AlignTop );
					toolbar.fillColor.Set( LONGINT( 0CCCCCCFFH ) );

				NEW( label );
					label.bounds.SetWidth( 80 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.caption.SetAOC( " Speed: " );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);


				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " - " );
					button.onClick.Add( DecSpeed );
				toolbar.AddContent( button );
				
				
				NEW( button );
					button.bounds.SetWidth( 80 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " + " );
					button.onClick.Add( IncSpeed );
				toolbar.AddContent( button );
				
				NEW( label );
					label.bounds.SetWidth( 80 );
					label.alignment.Set( WMComponents.AlignLeft );
					label.textColor.Set( 0000000FFH );
				toolbar.AddContent(label);
				
				NEW( button );
					button.bounds.SetWidth( 160 );
					button.alignment.Set( WMComponents.AlignLeft );
					button.caption.SetAOC( " concurrent Quick " );
					button.onClick.Add( StartConcQuickSort );
				toolbar.AddContent( button );
				
				
				panel.AddContent( toolbar );
				
				RETURN panel
			END CreateForm;
			
			PROCEDURE Order( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.OrderData  END
			END Order;
			
			PROCEDURE RevOrder( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.RevOrderData  END
			END RevOrder;
			
			PROCEDURE BadOrder( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.BadOrder  END
			END BadOrder;
			
			
			PROCEDURE Rand10( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.Randomize( 10 )  END
			END Rand10;
			
			PROCEDURE Rand100( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.Randomize( 100 )  END
			END Rand100;
			
			PROCEDURE Rand200( sender, data: ANY );
			BEGIN
				IF ~ sorter.running THEN  av.Randomize( 200 )  END
			END Rand200;
			
			
			PROCEDURE IncSpeed( sender, data: ANY );
			BEGIN
				av.IncSpeed
			END IncSpeed;
			
			PROCEDURE DecSpeed( sender, data: ANY );
			BEGIN
				av.DecSpeed
			END DecSpeed;
			
		
			
			PROCEDURE StartBubbleSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.BubbleSort )
			END StartBubbleSort;
				
			
			PROCEDURE StartSelectSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.SelectSort )
			END StartSelectSort;
				
			
			PROCEDURE StartShellSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.ShellSort )
			END StartShellSort;
				
					
			PROCEDURE StartQuickSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.QuickSort )
			END StartQuickSort;
			
			
			PROCEDURE StartConcQuickSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.ConcQuickSort )
			END StartConcQuickSort;
			
			
			PROCEDURE StartHeapSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.HeapSort )
			END StartHeapSort;
				
			
			PROCEDURE StartSmoothSort( sender, data: ANY );
			BEGIN
				sorter.Start( av.SmoothSort )
			END StartSmoothSort;
				
	END ControlWindow;

	
		
VAR
	w: ControlWindow;

	PROCEDURE Open*;
	BEGIN
		IF w # NIL THEN  w.Close  END;
		NEW( w )
	END Open;


END SortDemo.

----------------------------------------------------

		SortDemo.Open

		SystemTools.Free SortDemo ~

