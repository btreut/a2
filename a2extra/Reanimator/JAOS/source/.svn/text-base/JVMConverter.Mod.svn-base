(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

(* the intention of this module was to make the whole character set conversion here;
    This should be at a central place where it can be used by everybody;
    I think, this is a good idea. but if this module fit's the requirements?
    one must studie the unicode spec and think about this.
*)
MODULE JVMConverter;
	
IMPORT SYSTEM, Reals;

CONST
	UnicodeStr* = "UnicodeStr";
	ISOOberonStr* = "ISOOberonStr";
	
(*
	Everything marked as Strings.Mod is copied "as is" from Strings.Mod to avoid importing Oberon and
	keep Jaos a pure Aos application
*)
							
VAR
	(* from Strings.Mod *)
	ISOToOberon, OberonToISO: ARRAY 256 OF CHAR; (** Translation tables for iso-8859-1 to oberon ascii code. *)

TYPE
	Converter* =  OBJECT
		VAR
			next : Converter;
			name* : ARRAY 32 OF CHAR;
		
		PROCEDURE Encode*( ch :LONGINT; VAR len : SHORTINT ) : LONGINT;
		BEGIN END  Encode;
						
		PROCEDURE Decode*( ch : LONGINT; VAR len : SHORTINT ) : LONGINT;
		BEGIN END Decode;				
		
	END Converter;

(* encoding and decoding for Utf8 Encoding*)
	Utf8* = OBJECT ( Converter )	(* this is not yet used *)
	
		PROCEDURE Encode*( ch :LONGINT; VAR len : SHORTINT ) : LONGINT;
			VAR buffer1, buffer2 : LONGINT;			        
		BEGIN 
			IF (ch > 0) & (ch < 128) THEN len := 1; RETURN ch
			ELSIF (ch > 0) & (ch <= 07FFH ) THEN
				buffer1 := ch; buffer1 := SYSTEM.VAL( LONGINT,(SYSTEM.VAL( SET, buffer1 )*{0,1,2,3,4,5})); 
				buffer2 := ch; buffer2 := SYSTEM.VAL(LONGINT,(SYSTEM.VAL( SET, buffer2 ) *{6,7, 8, 9,10})); 
				buffer2 := buffer2 * 4; 
				len := 2;
				RETURN SHORT( SYSTEM.VAL(LONGINT,{15,14,7}+SYSTEM.VAL(SET,buffer2)+SYSTEM.VAL(SET,buffer1)))
			END
		END  Encode;
					
		PROCEDURE Decode*( ch : LONGINT; VAR len : SHORTINT ) :LONGINT;
		VAR buffer1, buffer2 : LONGINT;
				set : SET;
		BEGIN			
			IF (ch>0) & (ch<128) THEN len := 1; RETURN ch;
			ELSE 
				buffer1 := ch; set := SYSTEM.VAL( SET, buffer1 );
				IF ( {15,14,7} + set = set ) &  ( {13,6} * set = {})  THEN	
					buffer1 := SYSTEM.VAL( LONGINT, set * {0,1,2,3,4,5});  (* low order bytes *)
					buffer2 := SYSTEM.VAL( LONGINT, set * {8,9,10,11,12}); (* high order bytes *)
					buffer2 := buffer2 DIV 4;
					len := 2;
					RETURN SHORT(SYSTEM.VAL( LONGINT, SYSTEM.VAL(SET, buffer1)+SYSTEM.VAL( SET, buffer2 )))
				END;
			END;			
		END Decode;
															
	END Utf8;
	
(* oberon to iso encoding*)	
	IsoOberon* = OBJECT( Converter )
	
		PROCEDURE Encode*( ch :LONGINT; VAR len : SHORTINT ) : LONGINT;			
		BEGIN len := 1; 
		IF (ch <0) OR (ch>255) THEN ch := ORD("?") END;
		RETURN ORD(OberonToISO[ ch ]);
		END  Encode;
						
		PROCEDURE Decode*( ch : LONGINT; VAR len : SHORTINT ) : LONGINT;		
		BEGIN len := 1; 
		IF (ch <0) OR (ch>255) THEN ch := ORD("?") END;
		RETURN ORD(ISOToOberon[ ch ]);
		END Decode;		
		
	END IsoOberon;
		
VAR
	converter : Converter;
	uni : Utf8;
	io : IsoOberon;
	default* : Converter;
	
PROCEDURE Register*( c : Converter );
BEGIN			
	c.next := converter;
	converter := c;
END Register;	

PROCEDURE Find*( name : ARRAY OF CHAR ):Converter;
VAR cur : Converter;
BEGIN
	cur := converter;
	WHILE (cur # NIL) & (cur.name # name) DO cur := cur.next END;
	RETURN cur;
END Find;

	(** Functions from Strings.Mod. Use these to avoid importing an Oberon module *)
	
(** Append this to to. *)
	PROCEDURE Append*(VAR to(** in/out *): ARRAY OF CHAR; this: ARRAY OF CHAR);
		VAR i, j, l: LONGINT;
	BEGIN
		i := 0;
		WHILE to[i] # 0X DO
			INC(i)
		END;
		l := LEN(to)-1; j := 0;
		WHILE (i < l) & (this[j] # 0X) DO
			to[i] := this[j]; INC(i); INC(j)
		END;
		to[i] := 0X
	END Append;

(** Convert an integer into a string. *)
	PROCEDURE IntToStr*(val: LONGINT; VAR str: ARRAY OF CHAR);
		VAR
			i, j: LONGINT;
			digits: ARRAY 16 OF LONGINT;
	BEGIN
		IF val = MIN(LONGINT) THEN
			COPY("-2147483648", str);
			RETURN
		END;
		IF val < 0 THEN
			val := -val; str[0] := "-"; j := 1
		ELSE
			j := 0
		END;
		i := 0;
		REPEAT
			digits[i] := val MOD 10; INC(i); val := val DIV 10
		UNTIL val = 0;
		DEC(i);
		WHILE i >= 0 DO
			str[j] := CHR(digits[i]+ORD("0")); INC(j); DEC(i)
		END;
		str[j] := 0X
	END IntToStr;

(** Converts a real to a string. *)
PROCEDURE RealToStr*(x: LONGREAL; VAR s: ARRAY OF CHAR);
VAR e, h, l, n, len: LONGINT; i, j, pos: INTEGER; z: LONGREAL; d: ARRAY 16 OF CHAR;
	
	PROCEDURE Wr(ch: CHAR);
	BEGIN
		IF ch = 0X THEN HALT(42) END;
		IF pos < len THEN s[pos] := ch; INC(pos) END;
	END Wr;
	
BEGIN
	len := LEN(s)-1; pos := 0;
	e:= Reals.ExpoL(x);
	IF e = 2047 THEN
		Wr("N"); Wr("a"); Wr("N")
	ELSE
		n := 14;
		IF (x < 0) & (e # 0) THEN Wr("-"); x:= - x END;
		IF e = 0 THEN h:= 0; l:= 0 (* no denormals *)
    ELSE e:= (e - 1023) * 301029 DIV 1000000; (* ln(2)/ln(10) = 0.301029996 *)
      z:= Reals.Ten(e+1);
      IF x >= z THEN x:= x/z; INC(e) ELSE x:= x * Reals.Ten(-e) END;
      IF x >= 10 THEN x:= x * Reals.Ten(-1) + 0.5D0 / Reals.Ten(n); INC(e)
      ELSE x:= x + 0.5D0 / Reals.Ten(n);
        IF x >= 10 THEN x:= x * Reals.Ten(-1); INC(e) END
      END;
      x:= x * Reals.Ten(7); h:= ENTIER(x); x:= (x-h) * Reals.Ten(8); l:= ENTIER(x)
    END;
		i := 15; WHILE i > 7 DO d[i]:= CHR(l MOD 10 + ORD("0")); l:= l DIV 10; DEC(i) END;
		WHILE i >= 0 DO d[i]:= CHR(h MOD 10 + ORD("0")); h:= h DIV 10; DEC(i) END;
		IF ABS(e) > 8 THEN (* scientific notation *)
			j := 15; WHILE (j > 0) & (d[j] = "0") DO DEC(j) END;
			Wr(d[0]); IF j # 0 THEN Wr(".") END; i := 1; WHILE i <= j DO Wr(d[i]); INC(i) END;
			IF e < 0 THEN Wr("D"); Wr("-"); e:= - e ELSE Wr("D"); Wr("+") END;
			Wr(CHR(e DIV 100 + ORD("0"))); e:= e MOD 100;
			Wr(CHR(e DIV 10 + ORD("0"))); Wr(CHR(e MOD 10 + ORD("0")))
		ELSE
			IF e < 0 THEN (* leading zeros *)
				j := (* !15*) 14; WHILE (j > 0) & (d[j] = "0") DO DEC(j) END;
				Wr("0"); Wr("."); INC(e);
				WHILE e < 0 DO Wr("0"); INC(e) END;
				i := 0; WHILE i <= j DO Wr(d[i]); INC(i) END
			ELSE
				i := 0; WHILE (e >= 0) & (i < 16 ) DO Wr(d[i]); INC(i); DEC(e) END;
				IF i < 16 THEN
					Wr(".");
					WHILE i < (*16*) 15 DO Wr(d[i]); INC(i); END;
					WHILE s[pos - 1] = "0" DO DEC(pos) END;
					IF s[pos - 1] = "." THEN DEC(pos) END;
				END
			END
		END
	END;
	s[pos] := 0X
END RealToStr;

	PROCEDURE Init();
		VAR i: LONGINT;
	BEGIN
		FOR i := 0 TO 255 DO
			ISOToOberon[i] := CHR(i); OberonToISO[i] := CHR(i)
		END;
		ISOToOberon[8] := CHR(127);
		ISOToOberon[146] := CHR(39);
		ISOToOberon[160] := CHR(32);
		ISOToOberon[162] := CHR(99);
		ISOToOberon[166] := CHR(124);
		ISOToOberon[168] := CHR(34);
		ISOToOberon[169] := CHR(99);
		ISOToOberon[170] := CHR(97);
		ISOToOberon[171] := CHR(60);
		ISOToOberon[173] := CHR(45);
		ISOToOberon[174] := CHR(114);
		ISOToOberon[175] := CHR(45);
		ISOToOberon[176] := CHR(111);
		ISOToOberon[178] := CHR(50);
		ISOToOberon[179] := CHR(51);
		ISOToOberon[180] := CHR(39);
		ISOToOberon[183] := CHR(46);
		ISOToOberon[185] := CHR(49);
		ISOToOberon[186] := CHR(48);
		ISOToOberon[187] := CHR(62);
		ISOToOberon[192] := CHR(65);
		ISOToOberon[193] := CHR(65);
		ISOToOberon[194] := CHR(65);
		ISOToOberon[195] := CHR(65);
		ISOToOberon[196] := CHR(128); OberonToISO[128] := CHR(196);
		ISOToOberon[197] := CHR(65);
		ISOToOberon[198] := CHR(65);
		ISOToOberon[199] := CHR(67);
		ISOToOberon[200] := CHR(69);
		ISOToOberon[201] := CHR(69);
		ISOToOberon[202] := CHR(69);
		ISOToOberon[203] := CHR(69);
		ISOToOberon[204] := CHR(73);
		ISOToOberon[205] := CHR(73);
		ISOToOberon[206] := CHR(73);
		ISOToOberon[207] := CHR(73);
		ISOToOberon[208] := CHR(68);
		ISOToOberon[209] := CHR(78);
		ISOToOberon[210] := CHR(79);
		ISOToOberon[211] := CHR(79);
		ISOToOberon[212] := CHR(79);
		ISOToOberon[213] := CHR(79);
		ISOToOberon[214] := CHR(129); OberonToISO[129] := CHR(214);
		ISOToOberon[215] := CHR(42);
		ISOToOberon[216] := CHR(79);
		ISOToOberon[217] := CHR(85);
		ISOToOberon[218] := CHR(85);
		ISOToOberon[219] := CHR(85);
		ISOToOberon[220] := CHR(130); OberonToISO[130] := CHR(220);
		ISOToOberon[221] := CHR(89);
		ISOToOberon[222] := CHR(80);
		ISOToOberon[223] := CHR(150); OberonToISO[150] := CHR(223);
		ISOToOberon[224] := CHR(139); OberonToISO[139] := CHR(224);
		ISOToOberon[225] := CHR(148); OberonToISO[148] := CHR(225);
		ISOToOberon[226] := CHR(134); OberonToISO[134] := CHR(226);
		ISOToOberon[227] := CHR(97);
		ISOToOberon[228] := CHR(131); OberonToISO[131] := CHR(228);
		ISOToOberon[229] := CHR(97);
		ISOToOberon[230] := CHR(97);
		ISOToOberon[231] := CHR(147); OberonToISO[147] := CHR(231);
		ISOToOberon[232] := CHR(140); OberonToISO[140] := CHR(232);
		ISOToOberon[233] := CHR(144); OberonToISO[144] := CHR(233);
		ISOToOberon[234] := CHR(135); OberonToISO[135] := CHR(234);
		ISOToOberon[235] := CHR(145); OberonToISO[145] := CHR(235);
		ISOToOberon[236] := CHR(141); OberonToISO[141] := CHR(236);
		ISOToOberon[237] := CHR(105);
		ISOToOberon[238] := CHR(136); OberonToISO[136] := CHR(238);
		ISOToOberon[239] := CHR(146); OberonToISO[146] := CHR(239);
		ISOToOberon[240] := CHR(100);
		ISOToOberon[241] := CHR(149); OberonToISO[149] := CHR(241);
		ISOToOberon[242] := CHR(142); OberonToISO[142] := CHR(242);
		ISOToOberon[243] := CHR(111);
		ISOToOberon[244] := CHR(137); OberonToISO[137] := CHR(244);
		ISOToOberon[245] := CHR(111);
		ISOToOberon[246] := CHR(132); OberonToISO[132] := CHR(246);
		ISOToOberon[248] := CHR(111);
		ISOToOberon[249] := CHR(143); OberonToISO[143] := CHR(249);
		ISOToOberon[250] := CHR(117);
		ISOToOberon[251] := CHR(138); OberonToISO[138] := CHR(251);
		ISOToOberon[252] := CHR(133); OberonToISO[133] := CHR(252);
		ISOToOberon[253] := CHR(121);
		ISOToOberon[254] := CHR(112);
		ISOToOberon[255] := CHR(121);
	END Init;

BEGIN
	Init;
	NEW( uni ); uni.name := UnicodeStr; NEW( io ); io.name := ISOOberonStr; Register( io );
	Register( uni ); default := io;
END JVMConverter.