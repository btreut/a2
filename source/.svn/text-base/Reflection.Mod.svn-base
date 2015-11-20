MODULE Reflection; (** AUTHOR "fof"; PURPOSE "tools for module, stack and process reflection"; *)

IMPORT Modules,Streams,Machine,Heaps,Objects,SYSTEM;

CONST
	ShowAllProcs = TRUE;
	MaxFrames = 128;
	MaxString = 64;
	MaxArray = 8;
	MaxCols = 70;
	Sep = "  ";
	SepLen = 2;

	LineDelay = 0; (* set this value to the number of cycles of an empty for loop that the reflection should wait after a new line
					 * useful for screen racing when no persistent trace medium is available
					 * no timer mechanism used because at low level tracing this may exactly not be available because IRQs do not work any more or so.
					 *)

TYPE
	Variable* = RECORD
		adr-: ADDRESS;
		type-, size-, n-, tdadr-: LONGINT
	END;

VAR
	modes: ARRAY 25 OF CHAR;

	(*
		Reference = {OldRef | ProcRef} .
		OldRef = 0F8X offset/n name/s {Variable} .
		ProcRef = 0F9X offset/n nofPars/n RetType procLev/1 slFlag/1 name/s {Variable} .
		RetType = 0X | Var | ArrayType | Record .
		ArrayType = 12X | 14X | 15X .	(* static array, dynamic array, open array *)
		Record = 16X .
		Variable = VarMode (Var | ArrayVar | RecordVar ) offset/n name/s .
		VarMode = 1X | 3X .	(* direct, indirect *)
		Var = 1X .. 0FX .	(* byte, boolean, char, shortint, integer, longint, real, longreal, set, ptr, proc, string *)
		ArrayVar = (81X .. 8EX) dim/n .	(* byte, boolean, char, shortint, integer, longint, real, longreal, set, ptr, proc *)
		RecordVar = (16X | 1DX) tdadr/n .	(* record, recordpointer *)
	*)

	(** Write a variable value.  The v parameter is a variable descriptor obtained with NextVar.  Parameter col is incremented with the (approximate) number of characters written. *)
	PROCEDURE WriteVar*(w: Streams.Writer; v: Variable; VAR col: LONGINT);
	VAR ch: CHAR;
	BEGIN
		IF v.type = 15 THEN
			w.Char(22X);
			LOOP
				IF (v.n = 0) OR (~CheckHeapAddress(v.adr)) THEN EXIT END;
				SYSTEM.GET(v.adr, ch);
				INC(v.adr);
				IF (ch < " ") OR (ch > "~") THEN EXIT END;
				w.Char(ch); INC(col); DEC(v.n)
			END;
			w.Char(22X); INC(col, 2);
			IF ch # 0X THEN w.Char("!") END
		ELSE
			WHILE v.n > 0 DO
				WriteSimpleVar(w, v.adr, v.type, v.tdadr, col);
				DEC(v.n); INC(v.adr, v.size);
				IF v.n > 0 THEN
					w.String(", "); INC(col, 2)
				END
			END
		END
	END WriteVar;

	PROCEDURE CheckHeapAddress(address: ADDRESS): BOOLEAN;
	BEGIN
		RETURN Machine.ValidHeapAddress(address);
	END CheckHeapAddress;

	(* Get a compressed refblk number. *)
	PROCEDURE GetNum( refs: Modules.Bytes;  VAR i, num: LONGINT );
	VAR
		n, s: LONGINT;  x: CHAR;
	BEGIN
		IF NewObjectFile(refs) THEN
			(* Copying byte by byte to avoid unaligned memory accesses on ARM *)
			SYSTEM.PUT8(ADDRESSOF(num), refs[i]);
			SYSTEM.PUT8(ADDRESSOF(num) + 1, refs[i + 1]);
			SYSTEM.PUT8(ADDRESSOF(num) + 2, refs[i + 2]);
			SYSTEM.PUT8(ADDRESSOF(num) + 3, refs[i + 3]);
			INC(i,4);
		ELSE
			s := 0;  n := 0;  x := refs[i];  INC( i );
			WHILE ORD( x ) >= 128 DO INC( n, ASH( ORD( x ) - 128, s ) );  INC( s, 7 );  x := refs[i];  INC( i ) END;
			num := n + ASH( ORD( x ) MOD 64 - ORD( x ) DIV 64 * 64, s )
		END;
	END GetNum;

	(** Step to the next variable in the refs block.  The name parameter returns empty if no more variables are found.  The attributes are returned in v.  Parameter refpos is modified.  *)
	PROCEDURE NextVar*(refs: Modules.Bytes; VAR refpos: LONGINT; base: ADDRESS; VAR name: ARRAY OF CHAR; VAR v: Variable);
	VAR x: Variable; j: LONGINT; ch, mode: CHAR;
	BEGIN
		name[0] := 0X;	(* empty name signals end or error *)
		IF refpos < LEN(refs^)-1 THEN
			mode := refs[refpos]; INC(refpos);
			IF (mode >= 1X) & (mode <= 3X) THEN	(* var *)
				x.type := ORD(refs[refpos]); INC(refpos);
				IF x.type > 80H THEN
					IF x.type = 83H THEN x.type := 15 ELSE DEC(x.type, 80H) END;
					GetNum(refs, refpos, x.n)
				ELSIF (x.type = 16H) OR (x.type = 1DH) THEN
					GetNum(refs, refpos, x.tdadr); x.n := 1
				ELSE
					IF x.type = 15 THEN x.n := MaxString (* best guess *) ELSE x.n := 1 END
				END;
				(* get address *)
				GetNum(refs, refpos, j);
				x.adr := base + j;	(* convert to absolute address *)
				IF x.n = 0 THEN	(* open array (only on stack, not global variable) *)
					SYSTEM.GET(x.adr+4, x.n)	(* real LEN from stack *)
				END;
				IF mode # 1X THEN SYSTEM.GET(x.adr, x.adr) END;	(* indirect *)
				(* get size *)
				CASE x.type OF
					1..4,15: x.size := 1
					|5: x.size := 2
					|6..7,9,13,14,29: x.size := 4
					|8, 16: x.size := 8
					|22: x.size := 0; ASSERT(x.n <= 1)
				ELSE x.size := -1
				END;
				IF x.size >= 0 THEN	(* ok, get name *)
					ch := refs[refpos]; INC(refpos); j := 0;
					WHILE ch # 0X DO
						IF j < LEN(name)-1 THEN name[j] := ch; INC(j) END;	(* truncate long names *)
						ch := refs[refpos]; INC(refpos)
					END;
					name[j] := 0X; v := x	(* non-empty name *)
				END
			END
		END
	END NextVar;

	(** Find the specified global variable and return its descriptor.  Returns TRUE iff the variable is found. *)
	PROCEDURE FindVar*(mod: Modules.Module; CONST name: ARRAY OF CHAR; VAR v: Variable): BOOLEAN;
	VAR refs: Modules.Bytes; refpos: LONGINT; base: ADDRESS; n: ARRAY 64 OF CHAR;
	BEGIN
		InitVar(mod, refs, refpos, base);
		IF refpos # -1 THEN
			LOOP
				NextVar(refs, refpos, base, n, v);
				IF n = "" THEN EXIT END;
				IF n = name THEN RETURN TRUE END
			END
		END;
		RETURN FALSE
	END FindVar;

	(** Find global variables of mod (which may be NIL) and return it in the refs, refpos and base parameters for use by NextVar.  If not found, refpos returns -1. *)
	PROCEDURE InitVar*(mod: Modules.Module; VAR refs: Modules.Bytes; VAR refpos: LONGINT; VAR base: ADDRESS);
	VAR ch: CHAR; startpc: ADDRESS;
	BEGIN
		refpos := -1;
		IF mod # NIL THEN
			refs := mod.refs; base := mod.sb;
			IF (refs # NIL) & (LEN(refs) # 0) THEN
				refpos := FindProc(refs, 0, startpc);
				IF refpos # -1 THEN
					ch := refs[refpos]; INC(refpos);
					WHILE ch # 0X DO ch := refs[refpos]; INC(refpos) END
				END
			END
		END
	END InitVar;

	PROCEDURE NewObjectFile(refs: Modules.Bytes): BOOLEAN;
	BEGIN
		RETURN (refs # NIL) & (LEN(refs) >0) & (refs[0]=0FFX);
	END NewObjectFile;

	(* Find a procedure in the reference block.  Return index of name, or -1 if not found. *)
	PROCEDURE FindProc(refs: Modules.Bytes; modpc: ADDRESS; VAR startpc: ADDRESS): LONGINT;
	VAR pos, len, t, tstart, tend, proc: LONGINT; ch: CHAR; newObjectFile, found: BOOLEAN;
	BEGIN
		IF (refs=NIL) OR (LEN(refs) = 0) THEN RETURN -1 END;
		newObjectFile := NewObjectFile(refs);
		proc := -1; pos := 0; len := LEN(refs^);
		IF newObjectFile THEN INC(pos) END;
		ch := refs[pos]; INC(pos); tstart := 0;
		found := FALSE;
		WHILE ~found & (pos < len) & ((ch = 0F8X) OR (ch = 0F9X)) DO	(* proc *)
			GetNum(refs, pos, tstart);	(* procedure offset *)
			IF newObjectFile THEN
				GetNum(refs,pos,tend);
				found := (tstart <=modpc) & (tend  > modpc)
			ELSE
				found := tstart > modpc
			END;
				IF ch = 0F9X THEN
					GetNum(refs, pos, t);	(* nofPars *)
					INC(pos, 3)	(* RetType, procLev, slFlag *);
					IF newObjectFile THEN INC(pos,6) END;
				END;
			IF ~found THEN (* not yet found -- remember startpc and position for next iteration *)
				startpc := tstart;
				proc := pos;	(* remember this position, just before the name *)
				REPEAT ch := refs[pos]; INC(pos) UNTIL ch = 0X;	(* pname *)
				IF pos < len THEN
					ch := refs[pos]; INC(pos);	(* 1X | 3X | 0F8X | 0F9X *)
					WHILE (pos < len) & (ch >= 1X) & (ch <= 3X) DO	(* var *)
						ch := refs[pos]; INC(pos);	(* type *)
						IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
							GetNum(refs, pos, t)	(* dim/tdadr *)
						END;
						GetNum(refs, pos, t);	(* vofs *)
						REPEAT ch := refs[pos]; INC(pos) UNTIL ch = 0X;	(* vname *)
						IF pos < len THEN ch := refs[pos]; INC(pos) END	(* 1X | 3X | 0F8X | 0F9X *)
					END
				END
			END;
		END;
		IF newObjectFile THEN
			IF found THEN
				startpc := tstart; proc := pos;
			ELSE proc := -1
			END;
		END;
		RETURN proc
	END FindProc;

	(* Find a procedure in the reference block.  Return index of name, or -1 if not found. *)
	PROCEDURE FindProcByName*(mod: Modules.Module; CONST name: ARRAY OF CHAR;  VAR from, to: ADDRESS): BOOLEAN;
	VAR i, namePos, m, t, tstart, tend: LONGINT; ch: CHAR; newObjectFile: BOOLEAN;
		refs: Modules.Bytes; success: BOOLEAN;
	BEGIN
		IF mod = NIL THEN RETURN FALSE END;
		refs := mod.refs;
		IF (refs=NIL) OR (LEN(refs) = 0) THEN RETURN FALSE END;
		newObjectFile := NewObjectFile(refs);
		i := 0; m := LEN(refs^);
		IF newObjectFile THEN INC(i) END;
		ch := refs[i]; INC(i); tstart := 0;
		success := FALSE;
		WHILE (i < m) & ((ch = 0F8X) OR (ch = 0F9X)) & ~success DO	(* proc *)
			GetNum(refs, i, tstart);	(* pofs *)
			IF newObjectFile THEN GetNum(refs,i,tend) END;
			IF ch = 0F9X THEN
				GetNum(refs, i, t);	(* nofPars *)
				INC(i, 3)	(* RetType, procLev, slFlag *);
				IF newObjectFile THEN INC(i,6) END;
			END;
			namePos := 0; success := TRUE;
			REPEAT ch := refs[i]; INC(i); success := success & (ch = name[namePos]); INC(namePos); UNTIL ch = 0X;	(* pname *)
			IF i < m THEN
				ch := refs[i]; INC(i);	(* 1X | 3X | 0F8X | 0F9X *)
				WHILE (i < m) & (ch >= 1X) & (ch <= 3X) DO	(* var *)
					ch := refs[i]; INC(i);	(* type *)
					IF (ch >= 81X) OR (ch = 16X) OR (ch = 1DX) THEN
						GetNum(refs, i, t)	(* dim/tdadr *)
					END;
					GetNum(refs, i, t);	(* vofs *)
					REPEAT ch := refs[i]; INC(i) UNTIL ch = 0X;	(* vname *)
					IF i < m THEN ch := refs[i]; INC(i) END	(* 1X | 3X | 0F8X | 0F9X *)
				END
			END;
		END;
		IF success & ~newObjectFile THEN
			IF (ch = 0F8X) OR (ch = 0F9X) THEN
				GetNum(refs, i, tend)
			ELSE
				tend :=LEN(mod.code);
			END;
			INC(tstart, ADDRESSOF(mod.code[0]));
			INC(tend, ADDRESSOF(mod.code[0]));
		END;
		from := tstart; to := tend;
		RETURN success
	END FindProcByName;

	PROCEDURE Wait(w: Streams.Writer);
	VAR i: LONGINT;
	BEGIN
		IF LineDelay > 0 THEN
			FOR i := 0 TO LineDelay DO END;
			w.Update
		END;
	END Wait;

	(* Display variables. *)
	PROCEDURE Variables(w: Streams.Writer; refs: Modules.Bytes; refpos: LONGINT; base: ADDRESS);
	VAR v: Variable; j, col: LONGINT; name: ARRAY 64 OF CHAR; etc: BOOLEAN;
	CONST dense = FALSE;
	BEGIN
		LOOP
			NextVar(refs, refpos, base, name, v);
			IF name[0] = 0X THEN EXIT END;
			(* write name *)
			IF (col # 0 ) & (v.n > 1) & (v.type # 15) THEN	(* Ln before array (except string) *)
				w.Ln; col := 0; Wait(w);
			END;
			w.String(Sep); w.String(name); w.Char("=");
			j := 0; WHILE name[j] # 0X DO INC(j) END;
			INC(col, SepLen+1+j);
				(* write variable *)
			IF (v.adr >= -4) & (v.adr < 4096) THEN	(* must be NIL VAR parameter *)
				w.String("NIL ("); w.Hex(v.adr, -8);
				w.Char(")"); INC(col, 14)
			ELSE
				etc := FALSE;
				IF v.type = 15 THEN
					IF v.n > MaxString THEN etc := TRUE; v.n := MaxString END
				ELSE
					IF v.n > MaxArray THEN etc := TRUE; v.n := MaxArray END
				END;
				WriteVar(w, v, col);	(* write value *)
				IF etc THEN w.String("..."); INC(col, 3) END;
				IF ~dense THEN
					w.Ln; col := 0; Wait(w);
				END;
			END;
			IF col > MaxCols THEN w.Ln; col := 0; Wait(w); END
		END;
		IF col # 0 THEN w.Ln; Wait(w) END
	END Variables;

	(** Write the state of the specified module. *)
	PROCEDURE ModuleState*(w: Streams.Writer; mod: Modules.Module);
	VAR refpos: LONGINT; base: ADDRESS; refs: Modules.Bytes;
	BEGIN
		InitVar(mod, refs, refpos, base);
		IF refpos # -1 THEN
			w.String("State "); w.String(mod.name); w.Char(":"); w.Ln; Wait(w);
			Variables(w, refs, refpos, base)
		END
	END ModuleState;

	(* Write the specified procedure name and returns parameters for use with NextVar and Variables. *)
	PROCEDURE WriteProc0(w: Streams.Writer; mod: Modules.Module; pc, fp: ADDRESS; VAR refs: Modules.Bytes;
			VAR refpos: LONGINT; VAR base: ADDRESS);
	VAR ch: CHAR; startpc: ADDRESS;
	BEGIN
		refpos := -1;
		IF mod = NIL THEN
			IF pc = 0 THEN w.String("NIL")
			ELSE
				w.String("Unknown PC="); w.Address(pc); w.Char("H")
			END;
			IF fp # -1 THEN
				w.String(" FP="); w.Address(fp); w.Char("H")
			END
		ELSE
			w.String(mod.name);
			IF ~NewObjectFile(mod.refs) THEN
				DEC(pc, ADDRESSOF(mod.code[0]));
			END;
			refs := mod.refs;
			IF (refs # NIL) & (LEN(refs) # 0) THEN
				refpos := FindProc(refs, pc, startpc);
				IF refpos # -1 THEN
					w.Char(".");
					ch := refs[refpos]; INC(refpos);
					IF ch = "$" THEN base := mod.sb ELSE base := fp END;	(* for variables *)
					WHILE ch # 0X DO w.Char(ch); ch := refs[refpos]; INC(refpos) END;
					w.Char(":"); w.Int(LONGINT(pc-startpc),1);
				END
			END;
			w.String(" pc="); w.Int(LONGINT(pc),1); w.String(" ["); w.Address (pc); w.String("H]");
			w.String(" = "); w.Int(LONGINT(startpc),1);  w.String(" + "); w.Int(LONGINT(pc-startpc),1);
			w.String(" crc="); w.Hex(mod.crc,-8);
			Wait(w);
		END
	END WriteProc0;

	(** Find procedure name and write it. *)
	PROCEDURE WriteProc*(w: Streams.Writer; pc: ADDRESS);
	VAR refs: Modules.Bytes; refpos: LONGINT; base: ADDRESS;
	BEGIN
		WriteProc0(w, Modules.ThisModuleByAdr0(pc), pc, -1, refs, refpos, base)
	END WriteProc;

	(* Returns the name of the procedure the pc is in. Searchs in m.refs *)
	PROCEDURE GetProcedureName*(pc: ADDRESS; VAR name: ARRAY OF CHAR; VAR startpc: ADDRESS);
	VAR
		methadr, i: LONGINT;
		ch: CHAR;
		m: Modules.Module;
	BEGIN
		m := Modules.ThisModuleByAdr0(pc);


		IF m # NIL THEN

			IF ~NewObjectFile(m.refs) THEN
				DEC(pc, ADDRESSOF(m.code[0]));
			END;

			methadr := FindProc(m.refs, pc, startpc);
			IF methadr # -1 THEN
				i := 0;
				ch := m.refs[methadr]; INC(methadr);
				WHILE ch # 0X DO
					name[i] := ch;
					ch := m.refs[methadr];
					INC(methadr);
					INC(i);
				END;
				IF ~NewObjectFile(m.refs) THEN
					INC(startpc, ADDRESSOF(m.code[0]));
				END;
			END;
			name[i] := 0X;
		ELSE
			name := "Unkown"; (* Better: name := "" *)
		END;
	END GetProcedureName;

	(* 	A simple introspection method, must be adapted if there are any changes to the
		refs section in a module. *)
	PROCEDURE GetVariableAdr*(pc, fp: ADDRESS;  CONST varname: ARRAY OF CHAR): ADDRESS;
	VAR
		m: Modules.Module;
		v: Variable;
		pos: LONGINT;
		base: ADDRESS;
		name: ARRAY 256 OF CHAR;
		ch: CHAR;
		startpc: ADDRESS;
	BEGIN
		pos := -1;
		m := Modules.ThisModuleByAdr0(pc);
		IF m # NIL THEN
			IF ~NewObjectFile(m.refs) THEN
				DEC(pc, ADDRESSOF(m.code[0]));
			END;
			pos := FindProc(m.refs, pc, startpc);

			IF pos # -1 THEN

				ch := m.refs[pos]; INC(pos);
				(* for variables *)
				IF ch = "$" THEN
					base := m.sb;
				ELSE
					base := fp;
				END;

				 (* Read the name *)
				WHILE ch # 0X DO ch := m.refs[pos]; INC(pos) END;

				NextVar(m.refs, pos, base, name, v);

				WHILE name[0] # 0X DO
					IF name = varname THEN
						RETURN v.adr;
					ELSE
						NextVar(m.refs, pos, base, name, v);
					END
				END
			END
		END;

		RETURN -1;

	END GetVariableAdr;

	(* "lock free" version of Modules.ThisTypeByAdr *)
	PROCEDURE ThisTypeByAdr(adr: ADDRESS; VAR m: Modules.Module; VAR t: Modules.TypeDesc);
	BEGIN
		IF adr # 0 THEN
			SYSTEM.GET (adr + Heaps.TypeDescOffset, adr);
			IF CheckHeapAddress(adr) THEN
				t := SYSTEM.VAL(Modules.TypeDesc, adr);
				m := t.mod;
			ELSE
				m := NIL; t := NIL
			END
		ELSE
			m := NIL; t := NIL
		END
	END ThisTypeByAdr;

	PROCEDURE WriteType*(w: Streams.Writer; adr: ADDRESS);
	VAR module: Modules.Module; typeDesc: Modules.TypeDesc;
	BEGIN
		IF CheckHeapAddress(adr) THEN
			ThisTypeByAdr(adr, module, typeDesc);
			IF module # NIL THEN
				w.String(module.name);
			ELSE
				w.String("NIL");  RETURN
			END;
			w.String(".");
			IF typeDesc # NIL THEN
				IF typeDesc.name = "" THEN
					w.String("ANONYMOUS")
				ELSE
					w.String(typeDesc.name);
				END;
			ELSE
				w.String("NIL");
			END;
		ELSE
			w.String("UNKNOWN");
		END;
	END WriteType;

	PROCEDURE WriteSimpleVar( w: Streams.Writer;  adr, type, tdadr: ADDRESS;  VAR col: LONGINT );
	VAR ch: CHAR;  sval: SHORTINT;  ival: INTEGER;  lval: LONGINT;  rval: REAL; xval: LONGREAL; hval : HUGEINT;
		address: ADDRESS; pos0: LONGINT;
	BEGIN
		pos0 := w.Pos();
		IF (adr # 0) OR (type = 22) THEN
			CASE type OF
			1, 3:  (* BYTE, CHAR *)
					SYSTEM.GET( adr, ch );
					IF (ch > " ") & (ch <= "~") THEN w.Char( ch ); ELSE w.Hex( ORD( ch ), -2 );  w.Char( "X" ) END;
			| 2:    (* BOOLEAN *)
					SYSTEM.GET( adr, ch );
					IF ch = 0X THEN w.String( "FALSE" )
					ELSIF ch = 1X THEN w.String( "TRUE" )
					ELSE w.Int( ORD( ch ), 1 );
					END;
			| 4:    (* SHORTINT *)
					SYSTEM.GET( adr, sval );
					w.Int( sval, 1 );
					IF sval > 0H THEN w.String(" ("); w.Hex(sval, -2); w.String("H)") END;
			| 5:    (* INTEGER *)
					SYSTEM.GET( adr, ival );
					w.Int( ival, 1 );
					IF ival > 0H THEN w.String(" (");w.Hex(ival,-4);w.Char("H");w.String(")"); END;
			| 6:    (* LONGINT *)
					SYSTEM.GET( adr, lval );
					w.Int( lval, 1 );
					IF lval > 0H THEN w.String( " (" );  w.Hex( lval,-8 );  w.String( "H)" );  END;
			| 7:     (* REAL *)
					SYSTEM.GET(adr,rval); SYSTEM.GET(adr,lval);
					w.Float(rval,15);
					IF lval > 0H THEN w.String(" ("); w.Hex(lval,-8);w.Char( "H" ); w.String(")"); END;
			| 8:      (* LONGREAL *)
					SYSTEM.GET(adr,xval);SYSTEM.GET(adr,hval);
					w.Float(xval,15);
					IF hval > 0H THEN  w.String( " (" );  w.Hex(hval,-16);  w.String( "H)" );  END;
			| 13,29: (* POINTER *)
					SYSTEM.GET( adr, address ); w.Address( address );  w.String( "H" );
					(* output type information, if available: *)
					w.String(" (");
					(* do a check if the address is in the heap range *)
					IF CheckHeapAddress(address) THEN
						SYSTEM.GET(address + Heaps.TypeDescOffset, address);
						WriteType(w,address);
					ELSE w.String("NIL");
					END;
					w.String(")");
			| 16:   (* HUGEINT *)
					SYSTEM.GET( adr , hval );
					w.Hex(hval,1);
					IF hval < 0 THEN w.String( "H (" ); w.Hex(hval,-16); w.String(")") END;
			| 9:    (* SET *)
					SYSTEM.GET( adr, lval );
					w.Set( SYSTEM.VAL( SET, lval ) );
			| 22:  (* RECORD *)
					w.String( "Rec@" );  w.Hex( tdadr, -8 );  w.Char( "H" );
			| 14:  (* PROC *)
					SYSTEM.GET( adr, lval );  WriteProc( w, lval );
			END;
		END;
		INC(col,w.Pos()-pos0);
	END WriteSimpleVar;

	(* Display call trackback. *)
	PROCEDURE StackTraceBack*(w: Streams.Writer; pc, bp: ADDRESS; stackhigh: ADDRESS; long, overflow: BOOLEAN);
	VAR count,refpos: LONGINT; stacklow: ADDRESS; base: ADDRESS; m: Modules.Module; refs: Modules.Bytes;
	BEGIN
		count := 0;	(* frame count *)
		stacklow := bp;
		REPEAT
			m := Modules.ThisModuleByAdr0(pc);
			IF (ShowAllProcs OR (m # NIL) OR (count = 0)) & (bp # 0) & (bp >= stacklow) & (bp <= stackhigh) THEN
				IF CheckHeapAddress( pc ) THEN
					WriteProc0(w, m, pc, bp, refs, refpos, base); w.Ln;Wait(w); w.Update;
					IF long & (~overflow OR (count > 0)) THEN	(* show variables *)
						IF refpos # -1 THEN Variables(w, refs, refpos, base) END;
						IF (m # NIL) & (base # m.sb) & (count = 0) THEN ModuleState(w, m) END
					END;
				ELSE
					w.String( "Unknown external procedure, pc = " );  w.Address( pc );  w.Ln; Wait(w);
				END;
				SYSTEM.GET(bp + SIZEOF(ADDRESS), pc);	(* return addr from stack *)
				SYSTEM.GET(bp, bp);	(* follow dynamic link *)
				INC(count)
			ELSE
				bp := 0
			END;
		UNTIL (bp = 0) OR (count = MaxFrames);
		IF bp # 0 THEN w.String("...") END
	END StackTraceBack;

	(** Write a process's state in one line. *)
	PROCEDURE WriteProcess*(w: Streams.Writer; p: Objects.Process);
	VAR adr: ADDRESS; mode: LONGINT; m: Modules.Module;
	BEGIN
		IF p # NIL THEN
			w.Int(p.id, 5);
			mode := p.mode;
			IF (mode >= Objects.Ready) & (mode <= Objects.Terminated) THEN
				adr := (mode-Objects.Ready)*4;
				FOR adr := adr TO adr+3 DO w.Char(modes[adr]) END
			ELSE
				w.Char(" "); w.Int(mode, 1)
			END;
			w.Int(p.procID, 2);
			w.Int(p.priority, 2);
			w.Update;
			w.Address (SYSTEM.VAL(ADDRESS, p.obj));
			IF p.obj # NIL THEN
				SYSTEM.GET(SYSTEM.VAL(ADDRESS, p.obj) - SIZEOF(ADDRESS), adr);
				w.Char(":"); WriteType(w, adr)
			END;
			w.Update;
			w.Char(" "); WriteProc(w, p.state.PC);
			IF p.mode = Objects.AwaitingLock THEN
				adr := SYSTEM.VAL(ADDRESS, p.waitingOn);
				w.Address (adr);
				w.Update;
				IF adr # 0 THEN	(* can be 0 when snapshot is taken *)
					SYSTEM.GET(adr - SIZEOF(ADDRESS), adr);
					IF adr = SYSTEM.TYPECODE(Modules.Module) THEN
						w.Char("-");
						m := SYSTEM.VAL(Modules.Module, adr);
						w.String(m.name)
					ELSE
						w.Char(":"); WriteType(w, adr)
					END;
					w.Update;
				END
			ELSIF p.mode = Objects.AwaitingCond THEN
				w.Char(" "); WriteProc(w, SYSTEM.VAL(ADDRESS, p.condition));
				w.Address (p.condFP)
			END;
			w.Char(" "); w.Set(p.flags)
		END
	END WriteProcess;

BEGIN
	modes := " rdy run awl awc awe rip";   (* 4 characters per mode from Objects.Ready to Objects.Terminated *)
END Reflection.
