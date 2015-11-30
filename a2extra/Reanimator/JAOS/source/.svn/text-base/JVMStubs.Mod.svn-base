(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMStubs;	(** PRK **)
(*
	Create stubs for the native methods
*)


IMPORT
		StringPool, PCT,
		Texts, Oberon, Strings, JT := JVMTypes, JB := JVMBase, jjlString;

CONST
	(*module configuration*)
	ActiveOberon = TRUE;	
	Substitute = FALSE;
	
	(* Create a type alias with the same name as the class instead of using the qualified name *)
	UseClassNameAlias = FALSE;
	
	(*method type*)
	static = TRUE; dynamic = FALSE;
	
VAR
	W, ImportW, AliasW: Texts.Writer;
	thisclass: JB.ObjectClass;
	
	imports: ARRAY 32, 32 OF CHAR;
	nofImps: LONGINT;
	
	alias: ARRAY 64, 32 OF CHAR;
	nofAlias: LONGINT;
	
	i: LONGINT;
	Hex: ARRAY 16 OF CHAR;


PROCEDURE Import(name: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE (i < nofImps) & (imports[i] # name) DO  INC(i)  END;
	IF i = nofImps THEN
		COPY(name, imports[i]); INC(nofImps);
		IF nofImps # 1 THEN Texts.WriteString(ImportW, ", ") END;
		Texts.WriteString(ImportW, name)
	END;
END Import;

PROCEDURE WriteClass(mod, class: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	Import(mod);
	IF UseClassNameAlias THEN
		i := 0;
		WHILE (i < nofAlias) & (alias[i] # class) DO  INC(i)  END;
		IF i = nofAlias THEN
			COPY(class, alias[i]);  INC(nofAlias);
			IF nofAlias = 1 THEN  Texts.WriteString(AliasW, "TYPE");  Texts.WriteLn(AliasW)  END;
			Texts.Write(AliasW, 9X);
			Texts.WriteString(AliasW, class); Texts.WriteString(AliasW, " = ");
			Texts.WriteString(AliasW, mod); Texts.Write(AliasW, ".");  Texts.WriteString(AliasW, class);
			Texts.Write(AliasW, ";");  Texts.WriteLn(AliasW)
		END;
		Texts.WriteString(W, class)
	ELSE
		Texts.WriteString(W, mod); Texts.Write(W, ".");  Texts.WriteString(W, class)
	END
END WriteClass;

PROCEDURE Tab(c: LONGINT);
BEGIN
	WHILE c > 0 DO
		DEC(c); Texts.Write(W, 9X)
	END
END Tab;

PROCEDURE Class(str: JT.String; VAR pos: LONGINT; subs: BOOLEAN);
VAR mod, obj: ARRAY 32 OF CHAR;
BEGIN
	JT.MakeStubName(str, pos, mod, obj);
	IF subs THEN
		Texts.WriteString(W, "PTR")
	ELSE
		WriteClass(mod, obj)
	END
END Class;

PROCEDURE Const(con: PCT.Const);	(* taken from PCBrowser.Mod *)
	VAR	ch: CHAR; s: SET;  type: PCT.Struct; i: LONGINT;
BEGIN
	type := con.type;
	IF  con.type = PCT.Char8  THEN
		ch:=CHR(con.int);
		IF  (ch>=20X)&(ch<=7EX)  THEN  Texts.Write(W, 22X); Texts.Write(W, ch); Texts.Write(W, 22X)
		ELSE  Texts.Write(W, Hex[ORD(ch) DIV 16]); Texts.Write(W, Hex[ORD(ch) MOD 16]); Texts.Write(W, "X")
		END
	ELSIF  type = PCT.Int64  THEN
		FOR i := 15 TO 0 BY -1 DO
			Texts.Write(W, Hex[ SHORT(ASH(con.long, -i*4)) MOD 10H])
		END;
		Texts.WriteString(W, "H")
	ELSIF  PCT.IsCardinalType(type)  THEN
		Texts.WriteInt(W, con.int, 0)
	ELSIF  type = PCT.Float32 THEN
		Texts.WriteReal(W, SHORT(con.real), 0)
	ELSIF  type = PCT.Float64  THEN
		Texts.WriteLongReal(W, con.real, 0)
	ELSIF type = PCT.Bool THEN
		IF con.bool THEN  Texts.WriteString(W, "TRUE")  ELSE Texts.WriteString(W, "FALSE")  END
	ELSIF  type = PCT.String  THEN
		Texts.WriteString(W, "StringConst not implemented")
	ELSIF type = PCT.Set THEN
		Texts.Write(W, "{"); s := con.set; i := 0;
		WHILE i <= MAX(SET) DO
			IF i IN s THEN Texts.WriteInt(W, i, 0); EXCL(s, i); IF s # {} THEN Texts.WriteString(W, ", ") END END;
			INC(i)
		END;
		Texts.Write(W, "}")
	ELSE
		Texts.WriteString(W, "Unknown Const")
	END
END Const;

PROCEDURE Type(sig: JT.String; VAR pos: LONGINT);
VAR  count: LONGINT;
BEGIN
	IF sig[pos] = ORD("[") THEN
		WHILE sig[pos] = ORD("[") DO
			(*Texts.WriteString(W, "ARRAY OF ");*)
			INC(pos); INC(count);
		END;
		IF count > 1 THEN
			Texts.WriteString(W, "jjlObject.RefArray")
		ELSE
			CASE CHR(sig[pos]) OF
			| "L" : WriteClass("jjlObject", "RefArray");
				REPEAT  INC(pos)  UNTIL CHR(sig[pos]) = ";"
			| "B": WriteClass("jjlObject", "ByteArray")
			| "C": WriteClass("jjlObject", "CharArray");
			| "S": WriteClass("jjlObject", "ShortArray");
			| "I": WriteClass("jjlObject", "IntArray");
			| "F": WriteClass("jjlObject", "FloatArray");
			| "Z": WriteClass("jjlObject", "BoolArray");
			| "D": WriteClass("jjlObject", "DoubleArray");
			| "J": WriteClass("jjlObject", "LongArray");
			END
		END
	ELSE
		CASE CHR(sig[pos]) OF
		| "B": Texts.WriteString(W, "JT.Byte")
		| "C": Texts.WriteString(W, "JT.Unicode");
		| "S": Texts.WriteString(W, "JT.Short");
		| "I": Texts.WriteString(W, "JT.Int");
		| "F": Texts.WriteString(W, "JT.Float");
		| "Z": Texts.WriteString(W, "BOOLEAN");
		| "D": Texts.WriteString(W, "JT.Double");
		| "J": Texts.WriteString(W, "JT.Long");
		| "L": INC(pos); Class(sig, pos, Substitute)
		END
	END;
	INC(pos)
END Type;

PROCEDURE Type0(t: PCT.Struct);
	VAR mod, class: JT.StringBuffer; p: PCT.Symbol; scope: PCT.Scope;
BEGIN
	PCT.GetTypeName(t, class);
	IF ~(t IS PCT.Basic) THEN
		scope := t.owner.inScope;
		PCT.GetScopeName(scope, mod);
		IF scope # thisclass.module THEN
			WriteClass(mod, class)
		ELSE
			Texts.WriteString(W, class)
		END
	ELSE
		Texts.WriteString(W, class)
	END;
END Type0;

PROCEDURE OpenModule(VAR str, name: ARRAY OF CHAR);
BEGIN
	Texts.WriteString(W, "MODULE "); Texts.WriteString(W, name);
	Texts.Write(W, ";"); Texts.WriteLn(W);
	Tab(1); Texts.WriteString(W, "(*automatically generated stub for ");
	Texts.WriteString(W, str); Texts.WriteString(W, " *)");
	Texts.WriteLn(W); Texts.WriteLn(W);
	Tab(1); Texts.WriteString(W, "(*WARNING: DON'T CHANGE THE PROCEDURE NAMES*)");
	Texts.WriteLn(W); Texts.WriteLn(W);
END OpenModule;

PROCEDURE CloseModule(VAR name: ARRAY OF CHAR);
BEGIN
	Texts.WriteString(W, "END "); Texts.WriteString(W, name);
	Texts.Write(W, "."); Texts.WriteLn(W);
END CloseModule;

PROCEDURE OpenType(c: JB.ObjectClass);
VAR pos: LONGINT;
BEGIN
	Texts.WriteString(W, "TYPE"); Texts.WriteLn(W);
	Tab(1); Texts.WriteString(W, thisclass.obobj);  Texts.WriteString(W, "* = OBJECT ");
	IF c.superClass # NIL THEN
		pos := 0;
		Texts.Write(W, "("); Class(c.superClass.name, pos, FALSE); Texts.Write(W, ")")
	END;
	Texts.WriteLn(W);
END OpenType;

PROCEDURE CloseType;
BEGIN
	Tab(1); Texts.WriteString(W, "END "); Texts.WriteString(W, thisclass.obobj); 
	Texts.Write(W, ";"); Texts.WriteLn(W); Texts.WriteLn(W)
END CloseType;

PROCEDURE Methods(c: JB.ObjectClass; kind: BOOLEAN);
VAR i, pos, par, tabs: LONGINT; name: ARRAY 32 OF CHAR;  jname: ARRAY 256 OF CHAR;
BEGIN
	IF (kind = static) THEN tabs := 1 ELSE tabs := 2 END;
	FOR i := 0 TO LEN(c.methods^)-1 DO
		IF (kind = static) = (JB.AFStatic IN c.methods[i].flags) THEN
			JT.MakeMethodName(c.methods[i].name.value.p, c.methods[i].descriptor, c.methods[i].try = 0, name);
			Tab(tabs); 
			Texts.WriteString(W, "PROCEDURE ");
			Texts.WriteString(W, name);
			IF JB.AFPublic IN c.methods[i].flags THEN Texts.Write(W, "*") END;
			pos := 1; par := 0;
			ASSERT(c.methods[i].descriptor[0] = ORD("("));
			Texts.WriteString(W, "(");
			WHILE (c.methods[i].descriptor[pos] # ORD(")")) DO
				IF par # 0 THEN Texts.WriteString(W, "; ") END;
				Texts.Write(W, "p"); Texts.WriteInt(W, par, 0); INC(par);
				Texts.WriteString(W, ": "); Type(c.methods[i].descriptor, pos)
			END;
			Texts.WriteString(W, ")"); INC(pos);			
			IF c.methods[i].descriptor[pos] # ORD("V") THEN
				Texts.WriteString(W, ": "); Type(c.methods[i].descriptor, pos)
			END;
			Texts.Write(W, ";"); pos := 0;
			Texts.WriteString(W, "   (* "); 
			jjlString.ToOberon(c.methods[i].name, jname); Texts.WriteString(W, jname);
			JT.JavaToOberonString(c.methods[i].descriptor, 0, LEN(c.methods[i].descriptor), jname); Texts.WriteString(W, jname);
			Texts.WriteString(W, " *)"); Texts.WriteLn(W);
			Tab(tabs); Texts.WriteString(W, "BEGIN"); Tab(1);
			IF JB.AFNative IN c.methods[i].flags THEN
				Texts.WriteString(W, "(* put your implementation here *)"); Texts.WriteLn(W);
				Tab(tabs+1); Texts.WriteString(W, "HALT(99)")
			ELSE
				Texts.WriteString(W, "(* DON'T IMPLEMENT THIS METHOD *)")
			END;
			Texts.WriteLn(W);
			Tab(tabs); Texts.WriteString(W, "END "); Texts.WriteString(W, name); Texts.Write(W, ";");
			Texts.WriteLn(W); Texts.WriteLn(W)
		END
	END;
END Methods;

PROCEDURE Fields(s: PCT.Scope;  kind: BOOLEAN);
	VAR v: PCT.Value; p: PCT.Variable; name: JT.StringBuffer; tabs: LONGINT;
BEGIN
	IF kind = static THEN  tabs := 1 ELSE tabs := 3; Tab(2) END;
	Texts.WriteString(W, "CONST"); Texts.WriteLn(W);
	v := s.firstValue;
	WHILE v # NIL DO
		Tab(tabs);
		StringPool.GetString(v.name, name); JT.MakeIdent0(name, name);
		Texts.WriteString(W, name); Texts.WriteString(W, "* = ");
		Const(v.const);
		Texts.Write(W, ";"); Texts.WriteLn(W);
		v := v.nextVal
	END;
	Texts.WriteLn(W);
	Texts.WriteString(W, "VAR"); Texts.WriteLn(W);
	p := s.firstVar;
	WHILE p # NIL DO
		Tab(tabs);
		StringPool.GetString(p.name, name); JT.MakeIdent0(name, name);
		Texts.WriteString(W, name);
		IF PCT.PublicW IN p.vis THEN Texts.Write(W, "*") ELSE Texts.Write(W, "-") END;
		Texts.WriteString(W, ": ");
		Type0(p.type);
		Texts.Write(W, ";"); Texts.WriteLn(W);
		p := p.nextVar
	END;
	Texts.WriteLn(W)
END Fields;

PROCEDURE MakeStub*(c: JB.ObjectClass);
VAR str: ARRAY 256 OF CHAR; t: Texts.Text; m: PCT.Module;
BEGIN
	NEW(t); Texts.Open(t, "");
	JT.JavaToOberonString(c.name, 0, LEN(c.name), str);
	thisclass := c;
	m := c.module;
	OpenModule(str, c.obmod);
	Texts.Append(t, W.buf);
	nofImps := 0;  nofAlias := 0;
	Texts.WriteString(ImportW, "IMPORT   JT := "); Import("JVMTypes");
	IF c.typeS.varCount + c.dynamicMethods > 0 THEN
		OpenType(c);
		IF c.typeS.varCount > 0 THEN Fields(c.typeS, dynamic) END;
		IF (c.dynamicMethods > 0) THEN Methods(c, dynamic) END;
		CloseType
	END;
	IF m.scope.varCount > 0 THEN Fields(m.scope, static) END;
	IF m.scope.procCount > 0 THEN Methods(c, static) END;
	CloseModule(c.obmod);
	IF nofImps > 0 THEN	
		Texts.Write(ImportW, ";"); Texts.WriteLn(ImportW); Texts.WriteLn(ImportW);
		Texts.Append(t, ImportW.buf)
	END;
	IF nofAlias > 0 THEN	
		Texts.WriteLn(AliasW); Texts.WriteLn(AliasW);
		Texts.Append(t, AliasW.buf)
	END;
	Texts.Append(t, W.buf);
	COPY(c.obmod, str);
	Strings.Append(str, ".Mod");
	Oberon.OpenText(str, t, 640, 400);
	thisclass := NIL	(* GC *)
END MakeStub;

BEGIN
	Texts.OpenWriter(W);
	Texts.OpenWriter(ImportW);
	Texts.OpenWriter(AliasW);
	FOR i := 0 TO 9 DO  Hex[i]:=CHR(ORD("0")+i)  END;
	FOR i := 0 TO 5 DO  Hex[10+i]:=CHR(ORD("A")+i)  END;
END JVMStubs.

(*
	11.01.04	prk	update to classpath 0.06
	27.08.01	prk	adapted to the changes in PCT
	16.08.01	prk	use PCT variables instead of class.fields
	29.05.01	prk	static fields: allocation corrected, make oberon compatible identifiers
	14.05.01	prk	generate correct active oberon syntax
	25.04.01	prk	if no fields, use array of length 0 instead of NIL
	24.04.01	prk	JVMTypes interface cleanup
	04.04.01	prk	merge with classpath-0.00 release, prepare for update with 0.01, minimize differencies
	04.04.01	prk	use JVM prefix
*)