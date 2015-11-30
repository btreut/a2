(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

(* grammar of reference section (new ref)*)
(*
	refs = 8CX BodyRef {ProcRef} .
	BodyRef = 0F8X offset name {Variable}
	ProcRef = 0F9X offset nofParams, RetType procLev slFlag name {Variable}.
	RetType = 0X|VarType|ArrayType|16X.
	Variable = VarMod (VarType|ArrayVar|RecordVar) offset name
	ArrayType = 12X|14X|15X.
	VarMod = 1X|3X.
	RecordVar = (16X|1DX) td.
	ArrayVar = 81X..8EX.
	VarType = 1X..0FX.
*)

MODULE JVMRefs;

IMPORT
	SYSTEM, AosModules,
	StringPool, PCT, PCBT;

TYPE 
	Ref* = POINTER TO RECORD
		refindex, reflen : LONGINT;
		name- : ARRAY 48 OF CHAR;
		offset- : LONGINT;
		var- : Var;
	END;
	
	ProcRef* = POINTER TO RECORD( Ref )
		nofParams- : LONGINT;
		retType-, procLev-, slFlag- : CHAR
	END;

	Var* = POINTER TO RECORD
		next- : Var;
		name- : ARRAY 32 OF CHAR;
		dim-, offset-, td-:LONGINT;
		value* : LONGINT; (* this does not make the thing bigger; here the 
										   value of the variable can be put  *) 
		mode-, type- : CHAR;							
	END;
	
VAR
	(* buffer for encoding reference section *)
	refs*: ARRAY 16*1024 OF CHAR;
	refsize*: LONGINT;
	

	PROCEDURE AddVar(body: Ref;  var: Var);
	BEGIN
		ASSERT( var # NIL );
		var.next := body.var; body.var := var;
	END AddVar;
	
	PROCEDURE GetRef*( VAR ref : Ref; VAR buffer : ARRAY OF CHAR; i : LONGINT ):LONGINT;		
		VAR len : LONGINT;
		       ch : CHAR;								      
		       proc : ProcRef;			       	

		(* this is taken from System.Mod *)
		PROCEDURE GetNum( VAR num : LONGINT);
		VAR x, shift : LONGINT; (* Bytes to shift *)					       	
		BEGIN
			shift := 0; x := 0; ch := buffer[i]; INC(i); 
			WHILE (i < len) & (ch >= 80X) DO
				INC(x, ASH( ORD(ch) - 128, shift));  INC(shift, 7);  ch := buffer[i];  INC(i);
			END;				
			num := ASH(ORD( ch ) MOD 64 - ORD( ch ) DIV 64*64, shift )+x;
			ch := buffer[i]
		END GetNum;

		PROCEDURE GetString( VAR str : ARRAY OF CHAR );
		VAR j, strlen : LONGINT;
		BEGIN
				strlen := LEN(str)-1; j := 0;
				WHILE (j < strlen) & (i < len) & ( buffer[i] # 0X) DO
					str[j] := buffer[i]; INC( j ); INC( i );
				END;
				str[j] := 0X;  INC(i); ch := buffer[i]; 
		END GetString;
			
		PROCEDURE GetVar( var : Var );							
		BEGIN
			IF i >= len THEN RETURN END;
			var.mode := buffer[i]; INC( i ); 				
			IF i >= len THEN RETURN END;
			var.type := buffer[i]; INC( i );				
			IF i >= len THEN RETURN END;
			ch := buffer[i]; 													
			IF (var.type > 80X) & (var.type < 8FX) THEN (* it's a kind of array *)
				GetNum( var.dim ) 
			ELSIF ( var.type = 16X) OR (var.type=1DX) THEN (* a record type *)
				GetNum( var.td )
			END;  
			GetNum(  var.offset ); GetString( var.name );																
		END GetVar;
		
		PROCEDURE GetBodyRef( body : Ref );
		VAR var : Var;
		BEGIN
			body.refindex := i-1; 
			IF i < len THEN
				ch := buffer[i];
				GetNum( body.offset ); GetString( body.name );
				WHILE  ( i < len ) & ( buffer[i] # 0F9X)  DO
					NEW( var );  GetVar( var ); AddVar(body, var )
				END
			END;
			body.reflen := i - body.refindex				
		END GetBodyRef;
			
		PROCEDURE GetProcRef( proc : ProcRef );
		VAR var : Var;
		BEGIN
			proc.refindex := i-1;
			IF i < len THEN ch := buffer[i];
				GetNum( proc.offset ); 
				GetNum( proc.nofParams ); 
				proc.retType := buffer[i]; INC( i );
				proc.procLev := buffer[i]; INC( i );
				proc.slFlag := buffer[i]; INC( i ); ch := buffer[i];
				GetString( proc.name );
				WHILE (i < len ) & (buffer[i]#0F9X) DO					
					NEW( var ); GetVar( var ); AddVar(proc, var );
				END
			END;
			proc.reflen := i - proc.refindex
		END GetProcRef;
					
	BEGIN			
		len := LEN( buffer );
		ASSERT((i >= len) OR (buffer[i] = 0F8X) OR (buffer[i] = 0F9X));
		WHILE (i < len) & (buffer[i] # 0F8X) & (buffer[i]#0F9X) DO INC( i ) END; 
		IF i < len THEN	
			ch := buffer[i]; INC( i );
			CASE ch OF
				0F8X : NEW( ref ); GetBodyRef( ref )
				|0F9X : NEW( proc );  GetProcRef( proc ); ref := proc
			END
		END;				
		RETURN i;		
	END GetRef;

	PROCEDURE FindRefForName*( mod : AosModules.Module; name : ARRAY  OF CHAR ):Ref;
	VAR ref : Ref;
		i, len : LONGINT;
	BEGIN
		len := LEN( mod.refs^); i := 0;
		i := GetRef( ref, mod.refs^, i );
		WHILE (i<len) & (ref.name # name) DO i := GetRef( ref, mod.refs^, i ) END;		
		IF ref.name#name THEN RETURN NIL
		ELSE RETURN ref END;
	END FindRefForName;
	
	PROCEDURE FindVar*(ref: Ref; name: ARRAY OF CHAR): Var;
	VAR p: Var;
	BEGIN
		p := ref.var;
		WHILE (p # NIL) & (p.name # name) DO  p := p.next  END;
		RETURN p
	END FindVar;
	
	(** finds ref for a absolute adress => SYSTEM.ADR(mod.code[0]) is first subtracted *)
	PROCEDURE FindRefForAdr*( mod: AosModules.Module; adr : LONGINT ):Ref;
	VAR ref1, ref2 : Ref;
		i, len : LONGINT;
	BEGIN
		len := LEN( mod.refs^); DEC( adr, SYSTEM.ADR(mod.code[0]));
		IF (adr < 0) OR (adr >= LEN( mod.code^)) THEN RETURN NIL END;
		i := GetRef( ref1, mod.refs^, i ); 
		WHILE (i<len) & ( ref1.offset <= adr ) DO ref2:= ref1; i := GetRef( ref1, mod.refs^, i ) END;		
		IF (ref2.offset <= adr) & (adr < ref1.offset) THEN RETURN ref2
		ELSE RETURN ref1 END;
	END FindRefForAdr;
	
	PROCEDURE NextRef*( mod : AosModules.Module; ref : Ref ):Ref;
	VAR i, len : LONGINT;
			next : Ref;
	BEGIN
		IF ref = NIL THEN i := 0
		ELSE i := ref.refindex+ref.reflen END;
		len := LEN( mod.refs^);
		IF i < len THEN i := GetRef( next, mod.refs^, i ); RETURN next
		ELSE RETURN NIL END
	END NextRef;
	
	PROCEDURE GetParamSize*( ref : Ref ):LONGINT;
	VAR var, last : Var;
	BEGIN
		var := ref.var; last := var;
		WHILE var # NIL DO
			IF var.offset > last.offset THEN last := var END;
			var := var.next
		END;
		IF (last = NIL) OR (last.offset < 0) THEN RETURN 0
		ELSIF (last.type >80X) & (last.type<8FX) THEN RETURN last.offset+last.dim*4 - 8
		ELSE RETURN last.offset-4 END
	END GetParamSize;
	
	PROCEDURE GetLocalSize*( ref : Ref ):LONGINT;
	VAR var, last : Var;
	BEGIN
		var := ref.var; last := var;
		WHILE var # NIL DO
			IF var.offset < last.offset THEN last := var END;
			var := var.next
		END;
		IF (last = NIL) OR (last.offset > 0) THEN RETURN 0
		ELSE RETURN -last.offset END		
	END GetLocalSize;

	
(** -------------- Reference section encoding ------------------ *)

PROCEDURE Write(ch: CHAR);
BEGIN  refs[refsize] := ch;  INC(refsize)
END Write;
	
PROCEDURE WriteNum(x: LONGINT);
BEGIN
	WHILE (x < - 64) OR (x > 63) DO Write(CHR(x MOD 128 + 128)); x := x DIV 128 END;
	Write(CHR(x MOD 128))
END WriteNum;

PROCEDURE WriteString(VAR str: ARRAY OF CHAR);
	VAR i: LONGINT;
BEGIN
	i := -1;
	REPEAT  INC(i);  Write(str[i])  UNTIL str[i] = 0X
END WriteString;

PROCEDURE WriteType(t: PCT.Struct);
BEGIN
	IF t = PCT.Bool THEN Write(2X)
	ELSIF t = PCT.Char8 THEN Write(3X)
	ELSIF t = PCT.Char16 THEN Write(5X)
	ELSIF t = PCT.Int8 THEN Write(4X)
	ELSIF t = PCT.Int16 THEN Write(5X)
	ELSIF t = PCT.Int32 THEN Write(6X)
	ELSIF t = PCT.Int64 THEN Write(10X)
	ELSIF t = PCT.Float32 THEN Write(7X)
	ELSIF t = PCT.Float64 THEN Write(8X)
	ELSE Write(0DX)
	END
END WriteType;


(* write the reference section; this information is required for the trap handling *)
PROCEDURE NewMethod*(name: ARRAY OF CHAR; p: PCT.Proc; offset, nofParams, nofLocals: LONGINT);
VAR retType: CHAR;	
BEGIN
	IF p.type = PCT.NoType THEN
		retType := 0X
	ELSIF p.type = PCT.Float32 THEN
		retType := 7X
	ELSIF p.type = PCT.Float64 THEN
		retType := 8X
	ELSIF p.type = PCT.Int64 THEN
		retType := 10X
	ELSE
		retType := 6X	(*int => references are returned the same way!!*)
	END;
	Write(0F9X);	
	WriteNum(offset); WriteNum(nofParams); Write(retType); 
	Write(0X); Write(0X); (* proclevel and static link flat *)
	WriteString(name);
	offset := 8;
	WHILE nofParams > 0 DO
		Write(1X);Write(6X);WriteNum(offset);Write("p"); Write(CHR(ORD("0")+nofParams-1)); Write(0X);
		DEC(nofParams); INC(offset, 4);
	END;
	offset := -(nofLocals*4);
	(* this information needs to be right for the exception handling *)
	WHILE nofLocals > 0 DO
		Write(1X);Write(6X);WriteNum(offset);Write("l"); Write(CHR(ORD("0")+nofLocals-1)); Write(0X);
		DEC(nofLocals); INC(offset, 4);
	END;	
END NewMethod;

PROCEDURE NewModule*(v: PCT.Variable; offset: LONGINT);
	VAR name: ARRAY 128 OF CHAR;
BEGIN
	refsize := 0;
	Write(0F8X); WriteNum(offset); Write("$"); Write("$"); Write(0X);
	WHILE (v # NIL) DO
		StringPool.GetString(v.name, name);
		Write(1X);	(* direct *)
		WriteType(v.type);
		WriteNum(v.adr(PCBT.Variable).offset);
		WriteString(name);
		v := v.nextVar;
	END;
END NewModule;



END JVMRefs.

System.Free Refs  ~
Refs.Test

(*
	16.08.01	prk	GetRef fixed, didn't correctly skip an entry
	16.08.01	prk	Remove use of Oberon modules, use only Aos ones
	29.05.01	prk	static fields: allocation corrected, make oberon compatible identifiers
*)