
MODULE CryptoDES;	(** AUTHOR "G.F."; PUROSE "DES Cipher";	 *)

(* based on POLARSSL des.c *)


IMPORT S := SYSTEM, U := CryptoUtils, Ciphers := CryptoCiphers;

TYPE
	Sandbox = ARRAY 64 OF SET;
	BitSwap = ARRAY 16 OF SET;
VAR
	sb1-, sb2-, sb3-, sb4-, sb5-, sb6-, sb7-, sb8-: Sandbox;
	
	LHs, RHs: BitSwap;
	
TYPE 
	Cipher* = OBJECT (Ciphers.Cipher)
	VAR
		ske, skd: ARRAY 32 OF SET;  ki: LONGINT;
		ivx, ivy: SET;
	
		PROCEDURE InitKey*( CONST src: ARRAY OF CHAR;  keybits: LONGINT );
		VAR X, Y: SET;  i: LONGINT;
		BEGIN
			ASSERT( keybits = 64 );
			InitKey^( src, keybits );
			
			X := U.SetFromBufferBE( src, 0 );  Y := U.SetFromBufferBE( src, 4 );
			
			ComputeSubkeys( X, Y, ske, 0 );
			
			FOR i := 0 TO 31 BY 2 DO  
				skd[i] := ske[30 - i];  
				skd[i + 1] := ske[31 - i]
			END;
		END InitKey;
		
		
		PROCEDURE SetIV*( CONST src: ARRAY OF CHAR; mode: SHORTINT );
		BEGIN
			SetIV^( src, mode );   (* set mode *)
			ivx := U.SetFromBufferBE( src, 0 );  ivy := U.SetFromBufferBE( src, 4 )
		END SetIV;
		
		
		PROCEDURE  Encrypt* ( VAR buf: ARRAY OF CHAR; ofs, len: LONGINT );
		VAR i, r: LONGINT;   X, Y: SET;
		BEGIN
			ASSERT( isKeyInitialized & (mode IN {Ciphers.ECB, Ciphers.CBC}) );
			ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
			i := 0;
			WHILE i < len DO
				X := U.SetFromBufferBE( buf, ofs + i );  Y := U.SetFromBufferBE( buf, ofs + i + 4 );
				IF mode = Ciphers.CBC THEN  X := X / ivx;  Y := Y / ivy   END;
				IP( X, Y );  
				ki := 0;
				FOR r := 0 TO 7 DO  
					RoundE( Y, X );
					RoundE( X, Y );
				END;
				FP( Y, X );
				U.SetToBufferBE( Y, buf, ofs + i );   U.SetToBufferBE( X, buf, ofs + i + 4); 
				IF mode = Ciphers.CBC THEN  ivx := Y;  ivy := X  END;
				INC( i, blockSize )
			END
		END Encrypt;	
		
		
		PROCEDURE  Decrypt* ( VAR buf: ARRAY OF CHAR; ofs, len: LONGINT );
		VAR i, r: LONGINT;  X, Y: SET;  X0, Y0: SET;
		BEGIN
			ASSERT( isKeyInitialized );
			ASSERT( len MOD blockSize = 0 );   (* padding must have been added *)
			i := 0;
			WHILE i < len DO
				X := U.SetFromBufferBE( buf, ofs + i );  Y := U.SetFromBufferBE( buf, ofs + i + 4 );
				IF mode = Ciphers.CBC THEN  X0 := X;  Y0 := Y  END;
				IP( X, Y );  
				ki := 0;
				FOR r := 0 TO 7 DO  
					RoundD( Y, X );
					RoundD( X, Y );
				END;
				FP( Y, X );
				IF mode = Ciphers.CBC THEN  
					Y := Y / ivx;  X := X / ivy  ; 
					ivx := X0;  ivy := Y0  
				END;
				U.SetToBufferBE( Y, buf, ofs + i );   U.SetToBufferBE( X, buf, ofs + i + 4); 
				INC( i, blockSize )
			END
		END Decrypt;
		
		
		
		PROCEDURE RoundE*( VAR x, y: SET );
		VAR t: LONGINT;
		BEGIN
			t := S.VAL( LONGINT,  ske[ki] / x );  INC( ki );
			y := y / sb8[t MOD 40H] / sb6[t DIV 100H MOD 40H] / sb4[t DIV 10000H MOD 40H] / sb2[t DIV 1000000H MOD 40H];
			t := S.VAL( LONGINT,  ske[ki] / ROT( x, -4 ) );  INC( ki );
			y := y / sb7[t MOD 40H] / sb5[t DIV 100H MOD 40H] / sb3[t DIV 10000H MOD 40H] / sb1[t DIV 1000000H MOD 40H]
		END RoundE;
		
		PROCEDURE RoundD*( VAR x, y: SET );
		VAR t: LONGINT;
		BEGIN
			t := S.VAL( LONGINT,  skd[ki] / x );  INC( ki );
			y := y / sb8[t MOD 40H] / sb6[t DIV 100H MOD 40H] / sb4[t DIV 10000H MOD 40H] / sb2[t DIV 1000000H MOD 40H];
			t := S.VAL( LONGINT,  skd[ki] / ROT( x, -4 ) );  INC( ki );
			y := y / sb7[t MOD 40H] / sb5[t DIV 100H MOD 40H] / sb3[t DIV 10000H MOD 40H] / sb1[t DIV 1000000H MOD 40H]
		END RoundD;
		
		
		PROCEDURE & Init*;
		BEGIN
			SetNameAndBlocksize( "des", 8 );
		END Init;
	
	END Cipher;
	
	
	
	
	PROCEDURE NewCipher*( ): Ciphers.Cipher;
	VAR cipher: Cipher;
	BEGIN
		NEW( cipher );  RETURN cipher
	END NewCipher;
	
	
			
	PROCEDURE IP*( VAR x, y: SET );	(* initial permutation *)
	VAR t: SET;
	BEGIN
		t := (LSH( x,   -4 ) / y) * S.VAL( SET, 0F0F0F0FH );	y := y / t;  x := x / LSH( t, 4 );
		t := (LSH( x, -16 ) / y) * S.VAL( SET, 0000FFFFH );	y := y / t;  x := x / LSH( t, 16 );
		t := (LSH( y,   -2 ) / x) * S.VAL( SET, 33333333H );	x := x / t;  y := y / LSH( t, 2 );
		t := (LSH( y,   -8 ) / x) * S.VAL( SET, 00FF00FFH );	x := x / t;  y := y / LSH( t, 8 );
		y := ROT( y, 1 );
		t := (x / y) * S.VAL( SET, 0AAAAAAAAH );  y := y / t;  x := x / t; 
		x := ROT( x, 1 );			
	END IP;
		
	PROCEDURE FP*( VAR x, y: SET );	(* final permutation *)
	VAR t: SET;
	BEGIN
		x := ROT( x, -1 );
		t := (x / y) * S.VAL( SET, 0AAAAAAAAH );  x := x / t;  y := y / t;
		y := ROT( y, -1 );
		t := (LSH( y,   -8 ) / x) * S.VAL( SET, 00FF00FFH );	x := x / t;  y := y / LSH( t, 8 );
		t := (LSH( y,   -2 ) / x) * S.VAL( SET, 33333333H );	x := x / t;  y := y / LSH( t, 2 );
		t := (LSH( x, -16 ) / y) * S.VAL( SET, 0000FFFFH );	y := y / t;  x := x / LSH( t, 16 );
		t := (LSH( x,   -4 ) / y) * S.VAL( SET, 0F0F0F0FH );	y := y / t;  x := x / LSH( t, 4 );
	END FP;
	
	
	
	PROCEDURE ComputeSubkeys*( x, y: SET;  VAR sk: ARRAY OF SET; ofs: LONGINT );
	VAR t: SET; i: LONGINT;
		
		PROCEDURE sms( CONST LRHs: BitSwap;  x: SET; rs, ls: LONGINT ): SET;
		VAR i: LONGINT;
		BEGIN
			i := S.VAL( LONGINT, LSH( x, -rs ) ) MOD 16;
			RETURN LSH( LRHs[i], ls ) 
		END sms;
			
		PROCEDURE sm( b: SET; shift, mask: LONGINT ): SET;
		BEGIN
			RETURN LSH( b, shift ) * S.VAL( SET,  mask )
		END sm;
		
	BEGIN
		t := (LSH( y, -4 ) / x) * S.VAL( SET, 0F0F0F0FH );  x := x / t;  y := y / LSH( t, 4 );		
		t := (y / x) * S.VAL( SET, 10101010H ); x := x / t;  y := y / t;
			
		x := 
			sms( LHs, x, 0, 3 ) + sms( LHs, x, 8, 2 ) + sms( LHs, x, 16, 1 ) + sms( LHs, x, 24, 0 ) +
			sms( LHs, x, 5, 7 ) + sms( LHs, x, 13, 6 ) + sms( LHs, x, 21, 5 ) + sms( LHs, x, 29, 4 );
		y :=	
			sms( RHs, y, 1, 3 ) + sms( RHs, y, 9, 2 ) + sms( RHs, y, 17, 1 ) + sms( RHs, y, 25, 0 ) +
			sms( RHs, y, 4, 7 ) + sms( RHs, y, 12, 6 ) + sms( RHs, y, 20, 5 ) + sms( RHs, y, 28, 4 );

		FOR i := 0 TO 15 DO
			IF i IN {0, 1, 8, 15} THEN
				x := LSH( x, 1 ) + LSH( x, -27 );  y := LSH( y, 1 ) + LSH( y, -27 )
			ELSE
				x := LSH( x, 2 ) + LSH( x, -26 );  y := LSH( y, 2 ) + LSH( y, -26 )
			END;
					
			sk[ofs + 2*i] :=	
					sm( x, 4,		24000000H ) + sm( x, 28,	10000000H ) +
					sm( x, 14, 	08000000H ) + sm( x, 18,	02080000H ) +
					sm( x, 6,		01000000H ) + sm( x, 9,		00200000H ) +
				     sm( x, -1, 	00100000H ) + sm( x, 10,	00040000H ) +
					sm( x, 2,		00020000H ) + sm( x, -10,	00010000H ) +
					sm( y,-13,	00002000H ) + sm( y, -4,	00001000H ) +
					sm( y, 6,		00000800H ) + sm( y, -1,	00000400H ) +
					sm( y, -14,	00000200H ) + sm( y, 0,		00000100H ) +
					sm( y, -5,		00000020H ) + sm( y, -10,	00000010H ) +
					sm( y, -3,		00000008H ) + sm( y, -18,	00000004H ) +
					sm( y, -26,	00000002H ) + sm( y, -24,	00000001H );

	        	sk[ofs + 2*i + 1] :=   
	        			sm( x, 15,		20000000H ) + sm( x, 17,	10000000H ) +
					sm( x, 10,		08000000H ) + sm( x, 22,	04000000H ) +
					sm( x, -2,		02000000H ) + sm( x, 1,		01000000H ) +
					sm( x, 16,		00200000H ) + sm( x, 11,	00100000H ) +
					sm( x, 3,		00080000H ) + sm( x, -6,	00040000H ) +
					sm( x, 15,		00020000H ) + sm( x, -4,	00010000H ) +
					sm( y, -2,		00002000H ) + sm( y, 8,		00001000H ) +
					sm( y, -14,	00000808H ) + sm( y, -9,	00000400H ) +
					sm( y, 0,		00000200H ) + sm( y, 7,		00000100H ) +
					sm( y, -7,		00000020H ) + sm( y, -3,	00000011H ) +
					sm( y, 2,		00000004H ) + sm( y, -21,	00000002H );
		END
	END ComputeSubkeys;

	
	PROCEDURE InitializeSandboxes;
	VAR 
		buf: U.InitBuffer;
		
	
		PROCEDURE InitTable( VAR tab: ARRAY OF SET );
		VAR i: LONGINT; 
		BEGIN
			FOR i := 0 TO LEN( tab ) - 1 DO  tab[i] := buf.GetSet( )  END
		END InitTable;
	
	BEGIN
		NEW( buf, 1024 );
		buf.Add( "01010400 00000000 00010000 01010404 01010004 00010404 00000004 00010000 " );
		buf.Add( "00000400 01010400 01010404 00000400 01000404 01010004 01000000 00000004 " );
		buf.Add( "00000404 01000400 01000400 00010400 00010400 01010000 01010000 01000404 " );
		buf.Add( "00010004 01000004 01000004 00010004 00000000 00000404 00010404 01000000 " );
		buf.Add( "00010000 01010404 00000004 01010000 01010400 01000000 01000000 00000400 " );
		buf.Add( "01010004 00010000 00010400 01000004 00000400 00000004 01000404 00010404 " );
		buf.Add( "01010404 00010004 01010000 01000404 01000004 00000404 00010404 01010400 " );
		buf.Add( "00000404 01000400 01000400 00000000 00010004 00010400 00000000 01010004 " );
		InitTable( sb1 );

		buf.Init( 1024 );
		buf.Add( "80108020 80008000 00008000 00108020 00100000 00000020 80100020 80008020 " );
		buf.Add( "80000020 80108020 80108000 80000000 80008000 00100000 00000020 80100020 " );
		buf.Add( "00108000 00100020 80008020 00000000 80000000 00008000 00108020 80100000 " );
		buf.Add( "00100020 80000020 00000000 00108000 00008020 80108000 80100000 00008020 " );
		buf.Add( "00000000 00108020 80100020 00100000 80008020 80100000 80108000 00008000 " );
		buf.Add( "80100000 80008000 00000020 80108020 00108020 00000020 00008000 80000000 " );
		buf.Add( "00008020 80108000 00100000 80000020 00100020 80008020 80000020 00100020 " );
		buf.Add( "00108000 00000000 80008000 00008020 80000000 80100020 80108020 00108000 " );
		InitTable( sb2 );

		buf.Init( 1024 );
		buf.Add( "00000208 08020200 00000000 08020008 08000200 00000000 00020208 08000200 " );
		buf.Add( "00020008 08000008 08000008 00020000 08020208 00020008 08020000 00000208 " );
		buf.Add( "08000000 00000008 08020200 00000200 00020200 08020000 08020008 00020208 " );
		buf.Add( "08000208 00020200 00020000 08000208 00000008 08020208 00000200 08000000 " );
		buf.Add( "08020200 08000000 00020008 00000208 00020000 08020200 08000200 00000000 " );
		buf.Add( "00000200 00020008 08020208 08000200 08000008 00000200 00000000 08020008 " );
		buf.Add( "08000208 00020000 08000000 08020208 00000008 00020208 00020200 08000008 " );
		buf.Add( "08020000 08000208 00000208 08020000 00020208 00000008 08020008 00020200 " );
		InitTable( sb3 );

		buf.Init( 1024 );
		buf.Add( "00802001 00002081 00002081 00000080 00802080 00800081 00800001 00002001 " );
		buf.Add( "00000000 00802000 00802000 00802081 00000081 00000000 00800080 00800001 " );
		buf.Add( "00000001 00002000 00800000 00802001 00000080 00800000 00002001 00002080 " );
		buf.Add( "00800081 00000001 00002080 00800080 00002000 00802080 00802081 00000081 " );
		buf.Add( "00800080 00800001 00802000 00802081 00000081 00000000 00000000 00802000 " );
		buf.Add( "00002080 00800080 00800081 00000001 00802001 00002081 00002081 00000080 " );
		buf.Add( "00802081 00000081 00000001 00002000 00800001 00002001 00802080 00800081 " );
		buf.Add( "00002001 00002080 00800000 00802001 00000080 00800000 00002000 00802080 " );
		InitTable( sb4 );
	    
		buf.Init( 1024 );
		buf.Add( "00000100 02080100 02080000 42000100 00080000 00000100 40000000 02080000 " );
		buf.Add( "40080100 00080000 02000100 40080100 42000100 42080000 00080100 40000000 " );
		buf.Add( "02000000 40080000 40080000 00000000 40000100 42080100 42080100 02000100 " );
		buf.Add( "42080000 40000100 00000000 42000000 02080100 02000000 42000000 00080100 " );
		buf.Add( "00080000 42000100 00000100 02000000 40000000 02080000 42000100 40080100 " );
		buf.Add( "02000100 40000000 42080000 02080100 40080100 00000100 02000000 42080000 " );
		buf.Add( "42080100 00080100 42000000 42080100 02080000 00000000 40080000 42000000 " );
		buf.Add( "00080100 02000100 40000100 00080000 00000000 40080000 02080100 40000100 " );
		InitTable( sb5 );

		buf.Init( 1024 );
		buf.Add( "20000010 20400000 00004000 20404010 20400000 00000010 20404010 00400000 " );
		buf.Add( "20004000 00404010 00400000 20000010 00400010 20004000 20000000 00004010 " );
		buf.Add( "00000000 00400010 20004010 00004000 00404000 20004010 00000010 20400010 " );
		buf.Add( "20400010 00000000 00404010 20404000 00004010 00404000 20404000 20000000 " );
		buf.Add( "20004000 00000010 20400010 00404000 20404010 00400000 00004010 20000010 " );
		buf.Add( "00400000 20004000 20000000 00004010 20000010 20404010 00404000 20400000 " );
		buf.Add( "00404010 20404000 00000000 20400010 00000010 00004000 20400000 00404010 " );
		buf.Add( "00004000 00400010 20004010 00000000 20404000 20000000 00400010 20004010 " );
		InitTable( sb6 );

		buf.Init( 1024 );
		buf.Add( "00200000 04200002 04000802 00000000 00000800 04000802 00200802 04200800 " );
		buf.Add( "04200802 00200000 00000000 04000002 00000002 04000000 04200002 00000802 " );
		buf.Add( "04000800 00200802 00200002 04000800 04000002 04200000 04200800 00200002 " );
		buf.Add( "04200000 00000800 00000802 04200802 00200800 00000002 04000000 00200800 " );
		buf.Add( "04000000 00200800 00200000 04000802 04000802 04200002 04200002 00000002 " );
		buf.Add( "00200002 04000000 04000800 00200000 04200800 00000802 00200802 04200800 " );
		buf.Add( "00000802 04000002 04200802 04200000 00200800 00000000 00000002 04200802 " );
		buf.Add( "00000000 00200802 04200000 00000800 04000002 04000800 00000800 00200002 " );
		InitTable( sb7 );

		buf.Init( 1024 );
		buf.Add( "10001040 00001000 00040000 10041040 10000000 10001040 00000040 10000000 " );
		buf.Add( "00040040 10040000 10041040 00041000 10041000 00041040 00001000 00000040 " );
		buf.Add( "10040000 10000040 10001000 00001040 00041000 00040040 10040040 10041000 " );
		buf.Add( "00001040 00000000 00000000 10040040 10000040 10001000 00041040 00040000 " );
		buf.Add( "00041040 00040000 10041000 00001000 00000040 10040040 00001000 00041040 " );
		buf.Add( "10001000 00000040 10000040 10040000 10040040 10000000 00040000 10001040 " );
		buf.Add( "00000000 10041040 00040040 10000040 10040000 10001000 10001040 00000000 " );
		buf.Add( "10041040 00041000 00041000 00001040 00001040 00040040 10000000 10041000 " );
		InitTable( sb8 );
		
		buf.Init( 512 );
		buf.Add( "00000000 00000001 00000100 00000101 00010000 00010001 00010100 00010101 " );
		buf.Add( "01000000 01000001 01000100 01000101 01010000 01010001 01010100 01010101 " );
		InitTable( LHs );
		
		buf.Init( 512 );
		buf.Add( "00000000 01000000 00010000 01010000 00000100 01000100 00010100 01010100 " );
		buf.Add( "00000001 01000001 00010001 01010001 00000101 01000101 00010101 01010101 " );
		InitTable( RHs );
				
	END InitializeSandboxes;

BEGIN
	InitializeSandboxes
END CryptoDES.


SystemTools.Free CryptoTestCiphers CryptoDES ~

