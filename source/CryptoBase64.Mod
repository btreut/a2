
MODULE CryptoBase64;	 (** AUTHOR "g.f."; PURPOSE  "Base 64 encoding according to RFC1421"; *)

IMPORT Streams;

VAR
	etab: ARRAY 64 OF CHAR;
	dtab: ARRAY 128 OF INTEGER;


	PROCEDURE Encode*( CONST image: ARRAY OF CHAR; len: LONGINT;
						  		VAR b64: ARRAY OF CHAR );
	VAR
		group, i, ix, ox: LONGINT;
	BEGIN
		group := 0;  i := 0;  ix := 0;  ox := 0;
		WHILE ix < len DO
			group := group*100H + ORD( image[ix] );  INC( ix );  INC( i );
			IF i = 3 THEN  
				b64[ox] := etab[group DIV 40000H MOD 64];  
				b64[ox+1] := etab[group DIV 1000H MOD 64];  
				b64[ox+2] := etab[group DIV 40H MOD 64];  
				b64[ox+3] := etab[group MOD 64];  
				INC( ox, 4 );
				group := 0;
				i := 0 
			END;
		END;
		
		IF i > 0 THEN	(*encode rest *)
			IF i = 1 THEN  group := group*256  END;
			b64[ox] := etab[group DIV 400H MOD 64];  
			b64[ox+1] := etab[group DIV 10H MOD 64];  
			IF i = 1 THEN  b64[ox+2] := '='  ELSE  b64[ox+2] := etab[group*4 MOD 64]  END;
			b64[ox+3] := '=';  
			INC( ox, 4 );
		END;
		b64[ox] := 0X;
 	END Encode;


	(* returns image length, negative value = error! *)
	PROCEDURE Decode*( CONST b64: ARRAY OF CHAR;
								VAR image: ARRAY OF CHAR ): LONGINT;
	VAR
		i, d, code, group, ix, len: LONGINT;
		c: CHAR;
	BEGIN
		len := 0;  ix := 0;  group := 0;  i := 0;
		
		REPEAT  c := b64[ix];  INC( ix )  UNTIL (c > ' ') OR (c = 0X);
		code := dtab[ORD( c )]; 
		WHILE code >= 0 DO
			group := group*64 + code;  INC( i );
			IF i = 4 THEN  
				image[len] := CHR( group DIV 10000H MOD 100H );  INC( len );
				image[len] := CHR( group DIV 100H MOD 100H );  INC( len );
				image[len] := CHR( group MOD 100H );  INC( len );
				group := 0;  i := 0
			END;
			REPEAT  c := b64[ix];  INC( ix )  UNTIL (c > ' ') OR (c = 0X);
			code := dtab[ORD( c )]; 
		END;
					
		IF c = '=' THEN  (* decode rest *)
			IF i < 2 THEN  (* error *)  RETURN -1  END;
			group := group*64;  d := 1;  c := b64[ix];  
			IF c = '=' THEN  group := group*64;  d := 2  END;
			image[len] := CHR( group DIV 10000H );  INC( len );
			IF d = 1 THEN  image[len] := CHR( group DIV 100H MOD 100H );  INC( len )  END
		ELSIF i > 0 THEN  (* error *)  RETURN -1
		END;
		
		RETURN len
	END Decode;




 	PROCEDURE EncodeStream*( CONST image: ARRAY OF CHAR; len: LONGINT;
						   		  		w: Streams.Writer );
	VAR
		group, i, ix, ll: LONGINT;
	BEGIN
		group := 0;  i := 0; ix := 0;  ll := 0;
		WHILE ix < len DO
			group := group*100H + ORD( image[ix] );  INC( ix );  INC( i );
			IF i = 3 THEN  
				w.Char( etab[group DIV 40000H MOD 64] );
				w.Char( etab[group DIV 1000H MOD 64] );
				w.Char( etab[group DIV 40H MOD 64] );
				w.Char( etab[group MOD 64] );
				INC( ll, 4 );
				IF ll >= 72 THEN  w.Ln;  ll := 0  END;
				group := 0;
				i := 0  
			END;
		END;
		
		IF i > 0 THEN   (* encode rest *)
			IF i = 1 THEN  group := group*100H  END;
			w.Char( etab[group DIV 400H MOD 64] );  
			w.Char( etab[group DIV 10H MOD 64] );  
			IF i = 1 THEN  w.Char( '=' )  ELSE  w.Char( etab[group*4 MOD 64] )  END;
			w.Char( '=' );  
		END;
		w.Update
 	END EncodeStream;


	(* returns image length, negative value = error! *)
	PROCEDURE DecodeStream*( r: Streams.Reader;
										VAR image: ARRAY OF CHAR ): LONGINT;
	VAR
		i, rest, code, group, len: LONGINT;
		c: CHAR;
	BEGIN
		len := 0; group := 0;  i := 0;
		
		REPEAT  r.Char( c )  UNTIL (c > ' ') OR (c = 0X);
		code := dtab[ORD( c )]; 
		WHILE code >= 0 DO
			group := group*64 + code;  INC( i );
			IF i = 4 THEN  
				image[len] := CHR( group DIV 10000H MOD 100H );  INC( len );
				image[len] := CHR( group DIV 100H MOD 100H );  INC( len );
				image[len] := CHR( group MOD 100H );  INC( len );
				group := 0;  i := 0
			END;
			REPEAT  r.Char( c )  UNTIL (c > ' ') OR (c = 0X);
			code := dtab[ORD( c )];  
		END;
		
		IF c = '=' THEN   (* decode rest *)
			IF i < 2 THEN  (* error *)  RETURN -1  END;
			group := group*64;  rest := 2;  r.Char( c );  
			IF c = '=' THEN  group := group*64;  rest := 1  END;
			image[len] := CHR( group DIV 10000H );  INC( len );
			IF rest = 2 THEN  image[len] := CHR( group DIV 100H MOD 100H );  INC( len )  END
		ELSIF i > 0 THEN  (* error *)  RETURN -1
		END;
		
		RETURN len
	END DecodeStream;


	PROCEDURE InitTables;
	CONST
		letters = 26;  digits = 10;
	VAR 
		i, j: INTEGER;
	BEGIN
		j := 0;
		FOR i := 0 TO letters - 1 DO  etab[j] := CHR( i + ORD("A") );  INC( j )  END;
		FOR i := 0 TO letters - 1 DO  etab[j] := CHR( i + ORD("a") );  INC( j )  END;
		FOR i := 0 TO digits - 1 DO  etab[j] := CHR( i + ORD("0") );  INC( j )  END;
		etab[62] := "+";
		etab[63] := "/";
		FOR i := 0 TO 127 DO  dtab[i] := -1  END;
		FOR i := 0 TO 63 DO  dtab[ORD( etab[i] )] := i  END
	END InitTables;
	
	(*
	(* testing: expected behaviour:  "admin:1234"  =>  "YWRtaW46MTIzNA=="  =>  "admin:1234"*)
	PROCEDURE Test*( c: Commands.Context );
	VAR image, base64: ARRAY 80 OF CHAR;  len: LONGINT; r: Streams.StringReader;
	BEGIN
		c.out.String( 'admin:1234  =>  ' ); 
		image := 'admin:123456789';
		Encode( image, 10, base64 );
		c.out.String( base64 ); c.out.String( "  =>  " );
		len := Decode( base64, image );
		IF len > 0 THEN
			image[len] := 0X;
			c.out.String(image); c.out.Ln;
		END;
		
		c.out.String( 'admin:1234  =>  ' );
		EncodeStream( 'admin:123456789', 10, c.out );  c.out.String( "  =>  " );
		NEW( r, 80 );  r.Set( base64 );
		len := DecodeStream( r, image );  
		IF len > 0 THEN  
			image[len] := 0X;
			c.out.String( image ); c.out.Ln
		END
	END Test;
	*)
	

BEGIN
	InitTables();
END CryptoBase64.

	
	
	CryptoBase64.Test ~

	SystemTools.Free CryptoBase64 ~
