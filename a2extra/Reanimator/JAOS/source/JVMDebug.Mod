(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMDebug;	(** prk **)


IMPORT
		JC0 := JVMCompiler0, JOC := JVMOptCompiler,
		SYSTEM, 
		AosModules, 
		StringPool, PCT, PCBrowser, PCBT,
		Out, PCDebug,
		JT := JVMTypes, JB := JVMBase, JVM, JVMStubs, JS := JVMSystem, JI := JVMInterfaces,
		JVMCompiler, jjlObject, jjlString, JVMLoader,
		Decoder,
		Texts, Fonts, Oberon, Attributes, Strings;

CONST
	TVOID=0; (* nicht fverwendet, wird nur fnung *)
	TOBJECT=1; (* nicht fverwendet, wird nur fnung *)
	TARRAY=3; (* nicht fverwendet, wird nur fnung *) 
	TBOOLEAN=4;
	TCHAR=5;
	TFLOAT=6;
	TDOUBLE=7;
	TBYTE=8;
	TSHORT=9;
	TINT=10;
	TLONG=11;

TYPE
	OpCodeInfo=RECORD
		str: ARRAY 20 OF CHAR;
		args: ARRAY 10 OF CHAR;
	END;

VAR
	W: Texts.Writer;
	opcodes: ARRAY 256 OF OpCodeInfo;
	ATypes: ARRAY 12 OF ARRAY 32 OF CHAR;
	Const: ARRAY 13 OF ARRAY 32 OF CHAR;
	FlagString: ARRAY 32 OF ARRAY 32 OF CHAR;
	StateInfo: ARRAY 8, 16 OF CHAR;
	StateCount: ARRAY 8 OF LONGINT;
	Normal, Bold: Fonts.Font;
	
	temp, temp1: LONGINT;
	tempC: JB.RefClass;
	loaded, total: LONGINT;

PROCEDURE ToText(str: ARRAY OF CHAR; VAR W: Texts.Writer);
VAR t: Texts.Text;
BEGIN
	NEW(t); Texts.Open(t, ""); Texts.Append(t, W.buf);
	Oberon.OpenText(str, t ,640, 400);
END ToText;

PROCEDURE WriteFlags(s: SET);
VAR i: LONGINT;
BEGIN
	FOR i := 0 TO 31 DO
		IF i IN s THEN	Texts.WriteString(W, FlagString[i]); Texts.Write(W, " ")	END
	END
END WriteFlags;

PROCEDURE WriteUni(VAR W: Texts.Writer; uni: JT.String);
VAR  str: ARRAY 256 OF CHAR;
BEGIN
	IF uni # NIL THEN JT.JavaToOberonString(uni, 0, LEN(uni), str) END;
	Texts.WriteString(W, str)
END WriteUni;	
	
PROCEDURE Indent(VAR W:Texts.Writer;i: LONGINT);
BEGIN WHILE i > 0 DO Texts.Write(W, 9X); DEC(i) END
END Indent;

PROCEDURE WriteName(VAR W: Texts.Writer; i: StringPool.Index);
	VAR name: ARRAY 256 OF CHAR;
BEGIN
	StringPool.GetString(i, name);
	Texts.WriteString(W, name)
END WriteName;

PROCEDURE WriteType0(VAR W: Texts.Writer; t: PCT.Struct);
	VAR name: ARRAY 128 OF CHAR;
BEGIN
	PCT.GetTypeName(t, name);
	Texts.WriteString(W, name)
END WriteType0;

PROCEDURE WriteType(VAR W: Texts.Writer; s, n0, n: JT.String; VAR pos: LONGINT);
VAR  aCnt: LONGINT;
BEGIN
	aCnt := 0;
	WHILE CHR(s[pos]) = "[" DO  INC(aCnt); INC(pos)  END;
	CASE CHR(s[pos]) OF
	| "B": Texts.WriteString(W, "byte")
	| "C": Texts.WriteString(W, "char")
	| "D": Texts.WriteString(W, "double")
	| "F": Texts.WriteString(W, "float")
	| "I": Texts.WriteString(W, "int")
	| "J": Texts.WriteString(W, "long")
	| "L": INC(pos); REPEAT  Texts.Write(W, CHR(s[pos])); INC(pos) UNTIL CHR(s[pos]) = ";"
	| "S": Texts.WriteString(W, "short")
	| "V": Texts.WriteString(W, "void")
	| "Z": Texts.WriteString(W, "boolean")
	END;
	INC(pos); Texts.WriteString(W, "  "); 
	IF n0 # NIL THEN WriteUni(W, n0); Texts.Write(W, ".") END;
	WriteUni(W, n);
	WHILE aCnt > 0 DO  Texts.WriteString(W, "[]"); DEC(aCnt)  END 
END WriteType;

PROCEDURE WriteSignature(VAR W: Texts.Writer; sig, class, name: JT.String);
VAR	i: LONGINT;
BEGIN
	IF CHR(sig[0]) = "(" THEN 	(* procedure *)
		IF class # NIL THEN  WriteUni(W, class); Texts.Write(W, ".") END;
		WriteUni(W, name);
		i := 1; Texts.Write(W, "(");
		WHILE CHR(sig[i]) # ")" DO
			IF i # 1 THEN Texts.WriteString(W, "; ") END;
			WriteType(W, sig, NIL, NIL, i);
		END;
		Texts.Write(W, ")"); INC(i);
		IF CHR(sig[i]) # "V" THEN Texts.WriteString(W, ": "); WriteType(W, sig, NIL, NIL, i) END
	ELSE
		i := 0; WriteType(W, sig, class, name, i)
	END;
END WriteSignature;

PROCEDURE WriteField(VAR W: Texts.Writer; flags: SET; o: PCT.Symbol; verbose: BOOLEAN);
BEGIN
	Texts.Write(W, 9X);
	WriteFlags(flags+JB.VisibilityToFlag(o.vis));
	WriteType0(W, o.type);
	Texts.WriteString(W, " "); WriteName(W, o.name);
	IF verbose THEN
		Texts.WriteString(W, " @ ");
		IF o.adr # NIL THEN
			Texts.WriteInt(W, o.adr(PCBT.Variable).offset, 0)
		ELSE
			Texts.WriteString(W, "no addr")
		END;
	END;
	Texts.WriteLn(W);
END WriteField;

PROCEDURE WriteFields(VAR W: Texts.Writer; s: PCT.Scope; verbose: BOOLEAN);
	VAR static: BOOLEAN; var: PCT.Variable; val: PCT.Value; flags: SET;
BEGIN
	IF s IS PCT.ModScope THEN INCL(flags, JB.AFStatic) END;
	var := s.firstVar;
	WHILE var # NIL DO
		WriteField(W, flags, var, verbose); var := var.nextVar
	END;
	val := s.firstValue;
	WHILE val # NIL DO
		WriteField(W, flags+{JB.AFFinal}, val, verbose); val := val.nextVal
	END
END WriteFields;
(*
PROCEDURE WriteFields(VAR W: Texts.Writer; f: PCT.Variable; verbose: BOOLEAN);
	VAR fld: JB.Field;
BEGIN
	WHILE (f # NIL) & (f.info # NIL) DO
		fld := f.info(JB.Field);
		Texts.Write(W, 9X); Flags(fld.flags); WriteType0(W, f.type);
		Texts.WriteString(W, " "); WriteName(W, f.name);
		IF verbose THEN
			Texts.WriteString(W, " @ ");
			IF f.adr # NIL THEN
				Texts.WriteInt(W, f.adr(PCBT.Variable).offset, 0)
			ELSE
				Texts.WriteString(W, "no addr")
			END;
			Texts.WriteString(W, " Constval not available ");
(*
			IF fld.constval # NIL THEN  Texts.WriteString(W, " HAS ATTRIBUTES!!! ")  END
*)
		END;
		Texts.WriteLn(W);
		f := f.nextVar
	END
END WriteFields;
*)
PROCEDURE WriteMth(VAR W: Texts.Writer; m: JB.Method);
VAR i : LONGINT; ex: PTR; name: JT.StringBuffer;
BEGIN
	Texts.Write(W, 9X); WriteFlags(m.flags); WriteSignature(W, m.descriptor, NIL, m.name.value.p);
	Texts.WriteString(W, "  ["); Texts.WriteInt(W, m.mno, 0); 
	Texts.WriteString(W, " @ ");
	Texts.WriteHex(W, m.offset);
	Texts.WriteString(W, "]  ");
	Texts.WriteInt(W, m.parsize, 0); Texts.Write(W, "/"); 
	PCT.GetTypeName(m.p.type, name); Texts.WriteString(W, name);
	Texts.WriteLn(W);
	IF (m.code # NIL) & (m.code.exceptions#NIL) & (LEN(m.code.exceptions)>0) THEN
		Texts.Write(W, 9X); Texts.Write(W, 9X); Texts.WriteString(W, "Catchtable:"); Texts.WriteLn(W);
		FOR i := 0 TO LEN(m.code.exceptions)-1 DO			
			Texts.Write(W, 9X); Texts.Write(W, 9X); Texts.WriteString(W, "  "); 
			Texts.WriteString(W, " from: "); Texts.WriteHex(W, m.code.exceptions[i].start - m.offset);
			Texts.WriteString(W, " to: "); Texts.WriteHex(W, m.code.exceptions[i].end - m.offset);
			Texts.WriteString(W, " target: "); Texts.WriteHex(W, m.code.exceptions[i].handler - m.offset);
			Texts.WriteString(W, " Type: ");
			ex := m.code.exceptions[i].ex;
			IF ex = NIL THEN
				Texts.WriteString(W, "NIL")
			ELSIF ex IS JB.Class THEN
				WriteUni(W, ex(JB.Class).name)
			ELSE
				Texts.WriteString(W, "unknown")
			END;
			Texts.WriteLn(W);
		END
	END
END WriteMth;

PROCEDURE ConstPool(VAR W: Texts.Writer; cp: JB.ConstPool; idx: LONGINT; describe: BOOLEAN);
VAR cc: JB.Class; long: JB.Long; c: JB.CInfo;
BEGIN
	IF cp = NIL THEN
		Texts.WriteString(W, "cp["); Texts.WriteInt(W, idx, 0); Texts.Write(W, "]")
	ELSIF idx >= LEN(cp^) THEN
		Texts.WriteString(W, "cp["); Texts.WriteInt(W, idx, 0); Texts.WriteString(W, "]        (outside of constpool)")
	ELSE
		c := cp[idx];
		IF describe THEN  Texts.WriteString(W, Const[c.tag])  END;
		Texts.WriteString(W, "  ");
		CASE c.tag OF
		| JB.CUnicode:  WriteUni(W, c(JB.CUnicodeInfo).str);
		| JB.CInteger:  Texts.WriteInt(W, c(JB.CConstInfo).c.int, 0);
		| JB.CFloat:  Texts.WriteReal(W, SHORT(c(JB.CConstInfo).c.real), 0); Texts.WriteHex(W, SYSTEM.VAL(LONGINT, SHORT(c(JB.CConstInfo).c.real)));
		| JB.CLong:
				long := SYSTEM.VAL(JB.Long, c(JB.CConstInfo).c.long);
				Texts.WriteHex(W, long.h); Texts.WriteHex(W, long.l)
		| JB.CDouble:  Texts.WriteLongReal(W, c(JB.CConstInfo).c.real, 0);
				long := SYSTEM.VAL(JB.Long, c(JB.CConstInfo).c.real);
				Texts.WriteHex(W, long.h); Texts.WriteHex(W, long.l);
		| JB.CClass:  WriteUni(W, c(JB.CClassInfo).index.str);	(*not always cached*)
		| JB.CString:  WriteUni(W, c(JB.CStringInfo).index.str);	(*string is now jjlString.String *)
		| JB.CFieldref, JB.CMethodref, JB.CInterfaceMethodref:
				WITH c: JB.CRefInfo DO
					WriteSignature(W, c.ntindex.type.str, c.cindex.index.str, c.ntindex.name.str);	(*not cached if not compiled*)
				END
		| JB.CNameAndType:
				WriteUni(W, c(JB.CNameAndTypeInfo).name.str);
				Texts.WriteString(W, "  "); WriteUni(W, c(JB.CNameAndTypeInfo).type.str)
		END
	END
END ConstPool;

PROCEDURE Decode*(VAR W:Texts.Writer; class: JB.RefClass;
						map: JB.Map;
						VAR code: ARRAY OF CHAR; cindent: INTEGER);
VAR pc, i: LONGINT; oldcol: SHORTINT;

	PROCEDURE ReadBytes(n: INTEGER): LONGINT;
	VAR b: CHAR; i : LONGINT;
	BEGIN
		i:=0;
		WHILE n#0 DO
			b:=code[pc];INC(pc);
			i:=i*256+LONG(ORD(b));
			DEC(n);
		END;
		RETURN i;
	END ReadBytes;
	
	PROCEDURE DecodeOne;
	CONST detail = TRUE;
	VAR op: CHAR; oldpc, pad, default, high, low, npairs, 
		nargs, dummy, i, idx,opcode: LONGINT;
	BEGIN
		oldpc:=pc;
		op:=code[pc]; INC(pc); opcode:=ORD(op);
		Texts.WriteString(W, opcodes[ORD(op)].str); Texts.WriteString(W, " ");
		IF opcodes[ORD(op)].args = "B1" THEN
			Texts.WriteInt(W, SHORT(SHORT(ReadBytes(1))), 0);
		ELSIF opcodes[ORD(op)].args = "B2" THEN
			Texts.WriteInt(W, SHORT(ReadBytes(2)), 0);
		ELSIF opcodes[ORD(op)].args = "BB2" THEN
			Texts.WriteInt(W, SHORT(ReadBytes(2))+ oldpc, 0);
		ELSIF opcodes[ORD(op)].args = "I1" THEN
			idx:= ReadBytes(1); (* Log.Texts.WriteInt(W, idx); *)
			ConstPool(W, class.constPool, idx, FALSE);
		ELSIF opcodes[ORD(op)].args = "I2" THEN
			idx:=ReadBytes(2);
			IF detail THEN Texts.WriteString(W, " [");Texts.WriteInt(W, idx, 0); Texts.WriteString(W, "] ") END;
			ConstPool(W, class.constPool, idx, FALSE);
		ELSIF opcodes[ORD(op)].args = "V1" THEN
			 Texts.WriteInt(W, SHORT(ReadBytes(1)), 0);
		ELSIF opcodes[ORD(op)].args = "V2" THEN
			 Texts.WriteInt(W, SHORT(ReadBytes(2)), 0);
		ELSIF opcodes[ORD(op)].args = "TABLES" THEN
			WHILE (pc MOD 4) # 0 DO pad:=ReadBytes(1); IF pad#0 THEN HALT(96) END; END;
			default:=ReadBytes(4);  low:=ReadBytes(4); high:=ReadBytes(4);
			Texts.WriteString(W, " "); Texts.WriteInt(W, low, 0); 
			Texts.WriteString(W, " to "); Texts.WriteInt(W, high, 0);
			FOR i:=low TO high DO
				Texts.WriteLn(W);Indent(W,cindent+2); Texts.WriteString(W, "| "); Texts.WriteInt(W, i, 0);
				Texts.WriteString(W, " => "); Texts.WriteInt(W, oldpc+ReadBytes(4), 0);
			END;
			Texts.WriteLn(W); Indent(W,cindent+2); 
			Texts.WriteString(W, "| default => "); Texts.WriteInt(W, oldpc+default, 0);
		ELSIF opcodes[ORD(op)].args = "TABLEL" THEN
			WHILE (pc MOD 4) # 0 DO pad:=ReadBytes(1); IF pad#0 THEN HALT(96) END; END;
			default:=ReadBytes(4); npairs:=ReadBytes(4);
			Texts.WriteString(W, " #"); Texts.WriteInt(W, npairs, 0);
			FOR i:=1 TO npairs DO
				Texts.WriteLn(W);Indent(W,cindent+2); Texts.WriteString(W, "| "); Texts.WriteInt(W, ReadBytes(4), 0);
				Texts.WriteString(W, " => "); Texts.WriteInt(W, oldpc+ReadBytes(4), 0);
			END;
			Texts.WriteLn(W); Indent(W,cindent+2); Texts.WriteString(W, "| default => "); Texts.WriteInt(W, oldpc+default, 0);
		ELSIF opcodes[ORD(op)].args = "INTERFACE" THEN
			idx:= ReadBytes(2); (* Log.Texts.WriteInt(W, idx); *)
			ConstPool(W, class.constPool, idx, FALSE);
			nargs:=ReadBytes(1); Texts.WriteString(W, " #Args="); Texts.WriteInt(W, nargs, 0);
			dummy:=ReadBytes(1); 			
		ELSIF opcodes[ORD(op)].args = "NONE" THEN
			(* Do Nothing *)
		ELSIF opcodes[ORD(op)].args = "V1B1" THEN
			 Texts.WriteInt(W, SHORT(ReadBytes(1)), 0); Texts.WriteString(W, " ");
			 Texts.WriteInt(W, SHORT(SHORT(ReadBytes(1))), 0);
		ELSIF opcodes[ORD(op)].args = "I2B1" THEN
			idx:=ReadBytes(2); Texts.WriteString(W," dim#");
			Texts.WriteInt(W, SHORT(ReadBytes(1)), 0); Texts.WriteString(W,"  ");	 		
			ConstPool(W, class.constPool, idx, FALSE)
		ELSIF opcodes[ORD(op)].args = "A1" THEN
			Texts.WriteString(W, " "); Texts.WriteString(W, ATypes[ReadBytes(1)]); 	 		
		ELSE  Texts.WriteString(W, opcodes[ORD(op)].args); HALT(98);
		END;
		 Texts.WriteLn(W);
	END DecodeOne;	
BEGIN
	pc:=0;
	WHILE pc<LEN(code) DO
		FOR i := 1 TO cindent DO  Texts.Write(W, 9X)  END;
		Texts.WriteInt(W, pc, 3);  Texts.Write(W, 9X);
		IF map # NIL THEN Texts.WriteInt(W, map[pc], 3); Texts.Write(W, 9X) END;
		DecodeOne;
	END
END Decode;

PROCEDURE ClassFile*(c: JB.RefClass; showMap: BOOLEAN);
VAR i, dummy: LONGINT; code: JB.ACodeInfo; map: JB.Map;
BEGIN
	WriteUni(W, c.name);
	IF c.superClass # NIL THEN
		Texts.WriteString(W, "  ("); WriteUni(W, c.superClass.name); Texts.Write(W, ")")
	END;
	Texts.WriteLn(W); Texts.WriteLn(W);
	
	Texts.WriteString(W, "Flags:  "); WriteFlags(c.flags); Texts.WriteLn(W);
	IF c.constPool # NIL THEN
		i := 1;
		WHILE i < LEN(c.constPool^)-1 DO
			Texts.Write(W, 9X); Texts.WriteInt(W, i, 3); Texts.WriteString(W, ":  ");
			ConstPool(W, c.constPool, i, TRUE); Texts.WriteLn(W);
			IF c.constPool[i].tag IN {JB.CDouble, JB.CLong} THEN  INC(i)  END;
			INC(i);
		END
	ELSE
		Texts.WriteString(W, "    const pool not available");
	END;
	Texts.WriteLn(W);
	Texts.WriteString(W, "Interfaces:  ");
	IF c.interfaces # NIL THEN
		FOR i := 0 TO LEN(c.interfaces^)-1 DO
			WriteUni(W, c.interfaces[i].name); Texts.Write(W, " ")
		END
	ELSE Texts.WriteString(W, "--none--")
	END;
	Texts.WriteLn(W);
	Texts.WriteString(W, "Fields: "); Texts.WriteLn(W);
	WriteFields(W, c.moduleS, FALSE);
	WriteFields(W, c.typeS, FALSE);
	Texts.WriteLn(W);
	Texts.WriteString(W, "Methods"); 
	Texts.WriteLn(W);
	JVMCompiler.Init(c.moduleS);
	map := NIL;
	FOR i := 0 TO LEN(c.methods^)-1 DO
		Texts.Write(W, 9X); Texts.WriteInt(W, i, 3); Texts.Write(W, 9X);
		WriteFlags(c.methods[i].flags);
		WriteSignature(W, c.methods[i].descriptor, NIL, c.methods[i].name.value.p);
		Texts.WriteLn(W);
		code := c.methods[i].code;
		IF code # NIL THEN
			IF code.code = NIL THEN JVMLoader.LoadCode(c) END;
			IF showMap & (c.jit # -1) THEN JVM.JIT[c.jit].Compile(c, i, code, dummy, map) END;
			Decode(W, c, map, code.code^, 2);
			code.code := NIL
		END; Texts.WriteLn(W);
	END;
	Texts.WriteLn(W);
END ClassFile;


PROCEDURE GetName(VAR class, name: ARRAY OF CHAR; VAR opt: CHAR): BOOLEAN;
VAR S: Texts.Scanner; t: Texts.Text; beg, end, time, i, j: LONGINT;
BEGIN
	opt := 0X;
	IF Oberon.Par.text = NIL THEN RETURN FALSE END;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "\") THEN
		opt := S.nextCh;
		Texts.Scan(S); Texts.Scan(S)
	END;
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(t, beg, end, time);
		IF time # -1 THEN
			Texts.OpenScanner(S, t, beg); Texts.Scan(S)
		ELSE
			S.class := Texts.Inval
		END
	END;
	IF (S.class = Texts.Name) OR (S.class = Texts.String) THEN
		i := 0; WHILE (S.s[i] # 0X) & (S.s[i] # ".") DO  INC(i)  END;
		IF S.s[i] = "." THEN
			S.s[i] := 0X;
			j := -1;
			REPEAT
				INC(i); INC(j);
				name[j] := S.s[i]
			UNTIL name[j] = 0X
		ELSE
			S.s[i] := 0X; name[0] := 0X
		END;
		COPY(S.s, class);
		RETURN TRUE
	END;
	RETURN FALSE
END GetName;

PROCEDURE Get2Class(VAR class1, class2: ARRAY OF CHAR): BOOLEAN;
	VAR S: Texts.Scanner; t: Texts.Text; beg, end, time: LONGINT;
BEGIN
	IF Oberon.Par.text = NIL THEN RETURN FALSE END;
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		Oberon.GetSelection(t, beg, end, time);
		Texts.OpenScanner(S, t, beg); Texts.Scan(S)
	END;
	IF (S.class = Texts.Name) OR (S.class = Texts.String) THEN
		COPY(S.s, class1);
		Texts.Scan(S);
		IF (S.class = Texts.Name) OR (S.class = Texts.String) THEN
			COPY(S.s, class2); RETURN TRUE
		END
	END;
	RETURN FALSE
END Get2Class;

PROCEDURE PrintHashCode*;
VAR 
	S: Texts.Scanner; t: Texts.Text;
	descriptor : JT.String; name1 : ARRAY 32 OF CHAR; name2 : JT.StringBuffer;
	len, i, beg, end, time :LONGINT;
BEGIN
	IF Oberon.Par.text = NIL THEN RETURN END;
	Oberon.GetSelection(t, beg, end, time);
	Texts.OpenScanner(S, t, beg); Texts.Scan(S); 
	IF (S.class = Texts.String) THEN Strings.Append(name2, S.s) END;
	len := Strings.Length(name2);
	NEW(descriptor, len);
	FOR i := 0 TO len -1 DO descriptor[i] := ORD(name2[i]) END;
	JT.HashDescriptor(descriptor, name1);
	Texts.WriteString(W, name2); Texts.WriteString(W, "==>");Texts.WriteString(W, name1); Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf)	
END PrintHashCode;

PROCEDURE Dump*;	(**dump the contents of a class*)
VAR c: JB.Class; class, name: ARRAY 256 OF CHAR; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		c := JB.ThisClass0(class, TRUE);
		IF c IS JB.RefClass THEN
			ClassFile(c(JB.RefClass), opt # "n")
		ELSE
			Texts.WriteString(W, "Cannot dump "); Texts.WriteString(W, class); Texts.WriteLn(W)
		END;
		ToText("", W);
	END
END Dump;

PROCEDURE DumpCode*;	(**dump the compiler code of a class*)
VAR c: JB.Class;  oc : JB.ObjectClass; class, name: ARRAY 256 OF CHAR;  i, cadr: LONGINT; t: Texts.Text; m: JB.Method; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		c := JB.ThisClass0(class, TRUE);
		IF c IS JB.ObjectClass THEN
			oc := c(JB.ObjectClass);
			cadr := JS.GetCodeBase(oc.ownModule);
			Out.String("codebase : "); Out.Hex(cadr); Out.Ln;
			Decoder.nofPE := 0; NEW(Decoder.PE, LEN(oc.methods)+1);
			FOR i := 0 TO LEN(oc.methods^)-1 DO
				m := oc.methods[i];
				IF ~(JB.AFNative IN m.flags) & ~(JB.AFOverridden IN m.flags) THEN
					jjlString.ToOberon(m.name, Decoder.PE[Decoder.nofPE].name);
					Decoder.PE[Decoder.nofPE].point := m.offset - cadr;
					INC(Decoder.nofPE)
				END
			END;
			Decoder.PE[Decoder.nofPE].point := MAX(LONGINT);
			NEW(t); Texts.Open(t, "");
			Decoder.DecodeThis(t, oc.ownModule.code^);
			Oberon.OpenText(class, t, 600, 300)
		END
	END
END DumpCode;

(*
PROCEDURE HexDump*;
VAR f, g: Files.File; r, s: Files.Rider; len, l: LONGINT; t: Texts.Text; res: INTEGER; buf: ARRAY 1024 OF CHAR;
	class, name: ARRAY 256 OF CHAR; opt: CHAR;
	str : JT.String;
BEGIN
	IF GetName(class, name, opt) THEN
		JT.OberonToJavaString(class, str);
		f := JB.NameToFile(str); g := Files.New("Tmp");
		Files.Set(r, f, 0); Files.Set(s, g, 0);
		len := Files.Length(f);
		WHILE len > 0 DO
			IF len > 1024 THEN l := 1024 ELSE l := len END;
			Files.ReadBytes(r, buf, l); Files.WriteBytes(s, buf, l);
			DEC(len, l)
		END;
		Files.Register(g);
		Attributes.StrToTxt("Tmp", t);
		Oberon.Par.text := t; Oberon.Par.pos := 0;
		Oberon.Call("Hex.Open", Oberon.Par, TRUE, res);
		Files.Delete("Tmp", res)
	END
END HexDump;
*)
PROCEDURE EnumStubs(m: PCT.Module);
	VAR c: PTR;
BEGIN
	IF (m.info # NIL) & (m.info IS JB.RefClass) THEN
		c := m.info;
		WITH c: JB.RefClass DO
			IF c.stub # NIL THEN Texts.WriteString(W, c.stub.name); Texts.WriteLn(W) END
		END
	END
END EnumStubs;

PROCEDURE ShowStubs*;
BEGIN {EXCLUSIVE}
	PCT.Enumerate(JT.DB, EnumStubs);
	ToText("JVMDebug.ShowStubs", W)
END ShowStubs;

PROCEDURE EnumClasses(m: PCT.Module);
	VAR str: ARRAY 256 OF CHAR; state, i, count, count1: LONGINT; c: JB.Class;
BEGIN
	StringPool.GetString(m.name, str);
	Texts.WriteString(W, str);
	Texts.Write(W, 9X);
	IF m.info # NIL THEN
		c := m.info(JB.Class);
		state := c.state;
		INC(StateCount[state]);
		Texts.WriteString(W, StateInfo[state]);
		IF c IS JB.RefClass THEN
			WITH c: JB.RefClass DO
				IF c.methods # NIL THEN	(* when loader crashed, is not allocated *)
					FOR i := 0 TO LEN(c.methods)-1 DO
						IF c.methods[i].code = NIL THEN
						ELSIF c.methods[i].code.code = NIL THEN
							INC(count1, c.methods[i].code.len)
						ELSE
							INC(count, LEN(c.methods[i].code.code))
						END
					END;
					Texts.WriteInt(W, count, 8); Texts.WriteInt(W, count1, 8);
					INC(temp, count);
					INC(temp1, count1)
				END
			END
		END
	END;
	Texts.WriteLn(W)
END EnumClasses;

PROCEDURE ShowClasses*;
	VAR i: LONGINT;
BEGIN {EXCLUSIVE}
	temp := 0;
	PCT.Enumerate(JT.DB, EnumClasses);
	FOR i := 0 TO LEN(StateCount)-1 DO
		IF StateCount[i] > 0 THEN
			Texts.WriteString(W, StateInfo[i]);
			Texts.WriteString(W, ": ");
			Texts.WriteInt(W, StateCount[i], 0);
			Texts.WriteString(W, "  ");
			StateCount[i] := 0
		END
	END;
	Texts.WriteLn(W);
	Texts.WriteInt(W, temp, 8);
	Texts.WriteInt(W, temp1, 8);
	ToText("JVMDebug.ShowClasses", W)
END ShowClasses;

PROCEDURE Show*;	(**show the contents of a class*)
VAR class, name: ARRAY 256 OF CHAR; c: JB.Class; oc :JB.RefClass; ac: JB.ArrayClass; i: LONGINT; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		c := JB.ThisClass0(class, FALSE);
		IF c = NIL THEN  Texts.WriteString(W, class); Texts.WriteString(W, " not loaded"); Texts.WriteLn(W)
		ELSIF c.state < JB.Loaded THEN  Texts.WriteString(W, class); Texts.WriteString(W, " not loaded"); Texts.WriteLn(W)
		ELSIF c IS JB.PrimitiveClass THEN
			Texts.SetFont(W, Bold); Texts.WriteString(W, class); Texts.SetFont(W, Normal); Texts.WriteLn(W);
			Texts.WriteLn(W);
			Texts.WriteString(W, "Primitive Class"); Texts.WriteLn(W);
		ELSIF c IS JB.ArrayClass THEN
			ac := c(JB.ArrayClass);
			Texts.SetFont(W, Bold); Texts.WriteString(W, class); Texts.SetFont(W, Normal); Texts.WriteLn(W);
			Texts.WriteLn(W);
			Texts.WriteString(W, "Array Class"); Texts.WriteLn(W);
			WriteUni(W, ac.ctype.name);
			i := ac.dim;
			WHILE i > 0 DO
				Texts.WriteString(W, "[ ]"); DEC(i)
			END;
			Texts.WriteLn(W);
		ELSIF c IS JB.RefClass THEN
			oc := c(JB.RefClass);
			Texts.SetFont(W, Bold); Texts.WriteString(W, class); Texts.SetFont(W, Normal); Texts.WriteLn(W);
			Texts.WriteLn(W);
			IF oc.interfaces # NIL THEN
				Texts.WriteString(W, "Interfaces:"); Texts.WriteLn(W);
				FOR i := 0 TO LEN(oc.interfaces^)-1 DO
					Texts.Write(W, 9X); WriteUni(W, oc.interfaces[i].name); Texts.WriteLn(W)
				END
			END;
			Texts.WriteString(W, "Size:"); Texts.WriteLn(W);
			Texts.Write(W, 9X); Texts.WriteInt(W, oc.module.adr(PCBT.Module).locsize, 0);
			Texts.Write(W, "/"); Texts.WriteInt(W, oc.typeS.owner.size(PCBT.Size).size, 0);
			Texts.WriteLn(W);
			Texts.WriteString(W, "Fields:"); Texts.WriteLn(W);
			WriteFields(W, oc.typeS, TRUE);
			Texts.WriteString(W, "Methods :"); Texts.WriteLn(W);
			FOR i := 0 TO LEN(oc.methods^)-1 DO
				IF ~(JB.AFStatic IN oc.methods[i].flags) THEN  WriteMth(W, oc.methods[i])  END
			END;
			Texts.WriteString(W, "Static Fields:"); Texts.WriteLn(W);
			Texts.Write(W, 9X); Texts.WriteString(W, "SB = ");
			Texts.WriteHex(W, oc.ownModule.sb); Texts.WriteLn(W);
			WriteFields(W, oc.moduleS, TRUE);
			Texts.WriteString(W, "Static Methods:"); Texts.WriteLn(W);
			FOR i := 0 TO LEN(oc.methods^)-1 DO
				IF (JB.AFStatic IN oc.methods[i].flags) THEN  WriteMth(W, oc.methods[i])  END
			END
		END;
		ToText("JDebug.Show", W)
	END;
END Show;

PROCEDURE ShowTD*;	(**show the typedesc of a class*)
VAR class, name: ARRAY 256 OF CHAR; c: JB.Class; oc :JB.RefClass; ac: JB.ArrayClass; i, j, adr: LONGINT; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		c := JB.ThisClass0(class, FALSE);
		IF c = NIL THEN  Texts.WriteString(W, class); Texts.WriteString(W, " not loaded"); Texts.WriteLn(W)
		ELSIF c.state < JB.Loaded THEN  Texts.WriteString(W, class); Texts.WriteString(W, " not loaded"); Texts.WriteLn(W)
		ELSIF c IS JB.PrimitiveClass THEN
			Texts.SetFont(W, Bold); Texts.WriteString(W, class); Texts.SetFont(W, Normal); Texts.WriteLn(W);
			Texts.WriteLn(W);
			Texts.WriteString(W, "Primitive Class"); Texts.WriteLn(W);
		ELSIF c IS JB.ArrayClass THEN
			ac := c(JB.ArrayClass);
			Texts.SetFont(W, Bold); Texts.WriteString(W, class); Texts.SetFont(W, Normal); Texts.WriteLn(W);
			Texts.WriteLn(W);
			Texts.WriteString(W, "Array Class"); Texts.WriteLn(W);
			WriteUni(W, ac.ctype.name);
			i := ac.dim;
			WHILE i > 0 DO
				Texts.WriteString(W, "[ ]"); DEC(i)
			END;
			Texts.WriteLn(W);
		ELSIF c IS JB.RefClass THEN
			oc := c(JB.RefClass);
			Texts.SetFont(W, Bold); Texts.WriteString(W, class); Texts.SetFont(W, Normal); Texts.WriteLn(W);
			Texts.WriteLn(W);
			FOR i := 0 TO oc.dynamicMethods-1 DO
				Texts.WriteString(W, "Mth"); Texts.WriteInt(W, i, 0);
				Texts.WriteString(W, " @ ");
				adr := JS.GetMethod(oc.typedesc, i);
				Texts.WriteHex(W, adr);
				Texts.WriteString(W, "  -  "); 
				PCDebug.GetProcedure(adr, name);
				Texts.WriteString(W, name);
				Texts.WriteLn(W)
			END;
			Texts.WriteLn(W);
			Texts.WriteString(W, "size = "); Texts.WriteInt(W, oc.typedesc.tag.recSize, 0); Texts.WriteLn(W);
			j := 0; adr := SYSTEM.ADR(oc.typedesc.tag.ptrOfs0);
			REPEAT
				SYSTEM.GET(adr+4*j, i);
				Texts.WriteInt(W, j, 1); Texts.WriteString(W, "  ptrOff = "); Texts.WriteInt(W, i, 0); Texts.WriteLn(W);
				INC(j, 1)
			UNTIL i < 0
		END;
		ToText("JDebug.Show", W)
	END
END ShowTD;

PROCEDURE ShowIntf*;
	VAR cl1, cl2: JT.StringBuffer; c1, c2: JB.Class; vt: PTR;
	pc, i: LONGINT; name: ARRAY 128 OF CHAR;
BEGIN
	IF Get2Class(cl1, cl2) THEN
		c1 := JB.ThisClass0(cl1, FALSE);
		IF (c1 # NIL) & (c1 IS JB.ObjectClass) THEN
			c2 := JB.ThisClass0(cl2, FALSE);
			IF (c2 # NIL) & (c2 IS JB.InterfaceClass) THEN
				vt := JI.Lookup(c1(JB.ObjectClass).typedesc.tag, c2(JB.InterfaceClass).typedesc.tag);
				IF vt # NIL THEN
					FOR i := 1 TO c2(JB.InterfaceClass).typeS.procCount DO
						SYSTEM.GET(SYSTEM.VAL(LONGINT, vt)+4*i, pc);
						PCDebug.GetProcedure(pc, name);
						Texts.WriteString(W, "Mth"); Texts.WriteInt(W, i, 0);
						Texts.WriteString(W, " @ ");
						Texts.WriteHex(W, pc);
						Texts.WriteString(W, "  -  "); 
						Texts.WriteString(W, name);
						Texts.WriteLn(W)
					END;
					ToText("JVMDebug.ShowIntf", W)
				ELSE
					Out.String("interface not implemented")
				END
			ELSE
				Out.String(cl2); Out.String(" is no interface")
			END
		ELSE
			Out.String(cl1); Out.String(" is no class")
		END
	ELSE
		Out.String("invalid input")
	END;
	Out.Ln
END ShowIntf;

PROCEDURE Load*;
VAR class, name: ARRAY 256 OF CHAR; c: JB.Class; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		c := JB.ThisClass0(class, TRUE);
		IF class = "java/lang/Object" THEN jjlObject.class := c END
	END
END Load;

PROCEDURE ForceLoad(m: PCT.Module);
	VAR c: JB.Class; name: ARRAY 256 OF CHAR;
BEGIN
(*
	IF m.info = NIL THEN
		StringPool.GetString(m.name, name);
		c := JB.ThisClass0(name, TRUE);
		INC(temp)
	END
*)
	IF m.info # NIL THEN
		IF m.info IS JB.RefClass THEN
			JVMLoader.FixReferences(m.info(JB.RefClass))
		END
	END;
END ForceLoad;

PROCEDURE LoadAll*;
BEGIN
	PCT.Enumerate(JT.DB, ForceLoad)
END LoadAll;

PROCEDURE Compile*;
VAR class, name: ARRAY 256 OF CHAR; c: JB.Class; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		c := JB.ThisClass0(class, TRUE);
		JVM.CompileClass(c(JB.ObjectClass))
	END
END Compile;

PROCEDURE Initialize*;
VAR class, name: ARRAY 256 OF CHAR; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		JVM.CheckInitialized(JB.ThisClass0(class, TRUE))
	END
END Initialize;

PROCEDURE Stub*;
VAR class, name: ARRAY 256 OF CHAR; c: JB.Class; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		c := JB.ThisClass0(class, TRUE);
		JVMStubs.MakeStub(c(JB.ObjectClass))
	END
END Stub;

PROCEDURE Execute*;
VAR class, name: JT.StringBuffer; cf: JB.Class; oc : JB.ObjectClass;
VAR m : JB.Method; mName, desc : JT.String; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		cf := JB.ThisClass0(class, TRUE); oc := cf(JB.ObjectClass);
		JVM.CheckInitialized(cf(JB.ObjectClass));
		IF oc # NIL THEN
			
			JT.OberonToJavaString("main",mName); 
			JT.OberonToJavaString("([Ljava/lang/String;)V", desc);
			m := JB.FindMethod(mName, desc, oc.methods^, 0, LEN(oc.methods^) - 1);
			
			ASSERT(m # NIL);
(*
			Out.String("Calling .... "); Out.String(class); Out.Char("."); Out.String(name);
			Out.String("."); JT.OutString(m.name); JT.OutString(m.descriptor);  
			Out.String(" @ "); Out.Int(m.offset, 0); Out.Ln;
*)
			JS.Execute(m.offset);
		END;
	END;
END Execute;

	(** ExecuteApplet url code w h *)
PROCEDURE ExecuteApplet*;
	VAR S: Texts.Scanner; url, code: ARRAY 256 OF CHAR; w, h: LONGINT;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	ASSERT((S.class = Texts.String) OR (S.class = Texts.Name));
	COPY(S.s, url);
	Texts.Scan(S);
	ASSERT((S.class = Texts.String) OR (S.class = Texts.Name));
	COPY(S.s, code);
	Texts.Scan(S);
	ASSERT(S.class = Texts.Int);
	w := S.i;
	Texts.Scan(S);
	ASSERT(S.class = Texts.Int);
	h := S.i;
	JVM.ExecuteApplet(url, code, w, h);
END ExecuteApplet;

PROCEDURE LoadClasses(m: PCT.Module);
	VAR c: JB.Class; state: LONGINT; name: ARRAY 256 OF CHAR;
BEGIN
	IF m.info # NIL THEN
		c := m.info(JB.Class);
		StringPool.GetString(m.name, name);
		Out.String(name); Out.Int(c.state, 4); Out.Ln;
		c := JB.ThisClass0(name, TRUE);
		INC(loaded)
	END
END LoadClasses;

PROCEDURE TransitiveClosure*;
	VAR class, name: JT.StringBuffer; cf: JB.Class; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		cf := JB.ThisClass0(class, TRUE);
		REPEAT
			loaded := 0;
			PCT.Enumerate(JT.DB, LoadClasses);
		UNTIL loaded = 0;
		ShowClasses
	END;
END TransitiveClosure;

PROCEDURE EnumProc(m: PCT.Module);
	VAR name: ARRAY 256 OF CHAR;
BEGIN
	StringPool.GetString(m.name, name);
	Texts.WriteString(W, name); Texts.WriteLn(W);
END EnumProc;

PROCEDURE DumpInterfaces*;
VAR t: JI.VTable; name: ARRAY 32 OF CHAR; td: AosModules.TypeDesc; i: LONGINT;
BEGIN
	FOR i := 0 TO LEN(JI.InterfaceTable)-1 DO
		t := JI.InterfaceTable[i];
		IF t # NIL THEN
			SYSTEM.GET(SYSTEM.VAL(LONGINT, t) - 4, td);
			SYSTEM.GET(SYSTEM.VAL(LONGINT, td) - 4, td);
			Texts.WriteString(W, "  "); Texts.WriteString(W, td.name);
			Texts.WriteString(W, "(");
			SYSTEM.GET(SYSTEM.VAL(LONGINT, t.tdesc) - 4, td);
			Texts.WriteString(W, td.name); Texts.WriteString(W, ")");
			Texts.WriteLn(W)
		END
	END;
	ToText("Interfaces", W)
END DumpInterfaces;

PROCEDURE DumpDB*;	(** Dump the modules in PCT Database *)
BEGIN
	PCT.Enumerate(JT.DB, EnumProc);
	ToText("CommonDB", W)
END DumpDB;

PROCEDURE AltShow*;
VAR class, name: JT.StringBuffer; m: PCT.Module; n: StringPool.Index; t: Texts.Text; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		StringPool.GetIndex(class, n);
		m := PCT.Retrieve(JT.DB, n);
		PCBrowser.BrowseModule(t, m.scope, TRUE);
		Oberon.OpenText(class, t ,640, 400);	
	END
END AltShow;

(** ExtendersOf class - list all classes extending class *)

PROCEDURE Extends(m: PCT.Module);
	VAR c: JB.RefClass; str: ARRAY 128 OF CHAR;
BEGIN
	IF (m.info # NIL) & (m.info IS JB.RefClass) THEN
		c := m.info(JB.RefClass);
		IF c.superClass = tempC THEN
			StringPool.GetString(m.name, str);
			Texts.WriteString(W, str); Texts.WriteLn(W)
		END
	END;
END Extends;

PROCEDURE ExtendersOf*;
	VAR class, name: ARRAY 128 OF CHAR; m: PCT.Module; n: StringPool.Index; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		StringPool.GetIndex(class, n);
		m := PCT.Retrieve(JT.DB, n);
		IF m.info # NIL THEN
			tempC := m.info(JB.RefClass);
			PCT.Enumerate(JT.DB, Extends);
			ToText("ExtendersOf", W)
		END
	END
END ExtendersOf;
(*
PROCEDURE WhoUses*;
VAR class, name, str: ARRAY 256 OF CHAR; c, base: JB.Class;  ref: JB.CRefInfo;  clss: JB.CClassInfo;  
		i: LONGINT; findClass: BOOLEAN; T: Texts.Text; opt: CHAR;
BEGIN
	IF GetName(class, name, opt) THEN
		base := JB.ThisClass0(class, FALSE);
		c := JB.Classes;
		findClass := name = "";
		WHILE c # NIL DO
			IF c.constPool # NIL THEN
				i := LEN(c.constPool);
				REPEAT
					DEC(i);
					IF c.constPool[i] = NIL THEN	(*skip*)
					ELSIF findClass & (c.constPool[i].tag = JB.CClass) THEN
						clss := c.constPool[i](JB.CClassInfo);
						IF clss.class = base THEN
							JT.JavaToOberonString(c.name, str);
							Texts.WriteString(W, str); Texts.WriteLn(W);
							i := 0
						END
					ELSIF c.constPool[i].tag IN {JB.CFieldref, JB.CMethodref, JB.CInterfaceMethodref} THEN
						ref := c.constPool[i](JB.CRefInfo);
						IF (ref.class = base) & JT.Equal0(ref.name, name) THEN
							JT.JavaToOberonString(c.name, str);
							Texts.WriteString(W, str); Texts.WriteLn(W);
							i := 0
						END
					END
				UNTIL i <= 1
			END;
			c := c.next
		END;
		NEW(T); Texts.Open(T, "JDebug.WhoUses");
		Texts.Append(T, W.buf); Oberon.OpenText("", T, 640, 400)
	END
END WhoUses;
*)

PROCEDURE Init;
VAR i: LONGINT; T: Texts.Text; S: Texts.Scanner; s: ARRAY 32 OF CHAR;
BEGIN
	FOR i:=0 TO 256-1 DO
		opcodes[i].str:="ERROR: not defined"; opcodes[i].args:=""
	END;
	NEW(T); Texts.Open(T, "JVM.OpCodeInfo"); Texts.OpenScanner(S,T,0);
	IF T#NIL THEN
		WHILE ~S.eot DO
			Texts.Scan(S); COPY(S.s,s); Texts.Scan(S); Texts.Scan(S); i:=SHORT(S.i);
			COPY(s, opcodes[i].str); Texts.Scan(S); Texts.Scan(S); COPY(S.s,opcodes[i].args)
		END
	ELSE HALT(99)
	END;
	ATypes[TVOID]:="Void?";
	ATypes[TOBJECT]:="Object?";
	ATypes[TARRAY]:="Array?";
	ATypes[TBOOLEAN]:="Boolean";
	ATypes[TCHAR]:="Char";
	ATypes[TFLOAT]:="Float";
	ATypes[TDOUBLE]:="Double";
	ATypes[TBYTE]:="Byte";
	ATypes[TSHORT]:="Short";
	ATypes[TINT]:="Int";
	ATypes[TLONG]:="Long";
	
	Const[JB.CUnicode] := "Unicode";
	Const[JB.CInteger] := "Integer";
	Const[JB.CFloat] := "Float";
	Const[JB.CLong] := "Long";
	Const[JB.CDouble] := "Double";
	Const[JB.CClass] := "Class";
	Const[JB.CString] := "String";
	Const[JB.CFieldref] := "Fieldref";
	Const[JB.CMethodref] := "Methodref";
	Const[JB.CInterfaceMethodref] := "IntMethref";
	Const[JB.CNameAndType] := "NameAndType";
	
	FlagString[JB.AFPublic] := "PUBLIC"; 
	FlagString[JB.AFPrivate] := "PRIVATE"; 
	FlagString[JB.AFProtected] := "PROTECTED"; 
	FlagString[JB.AFStatic] := "STATIC"; 
	FlagString[JB.AFFinal] := "FINAL"; 
	FlagString[JB.AFSynchronized] := "SYNCHRONIZED"; 
	FlagString[JB.AFVolatile] := "VOLATILE"; 
	FlagString[JB.AFTransient] := "TRANSIENT"; 
	FlagString[JB.AFNative] := "NATIVE"; 
	FlagString[JB.AFInterface] := "INTERFACE"; 
	FlagString[JB.AFAbstract] := "ABSTRACT"; 
	
	StateInfo[JB.Loading] := "Loading";
	StateInfo[JB.Loaded] := "Loaded";
	StateInfo[JB.Allocated] := "Allocated";
	StateInfo[JB.Compiled] := "Compiled";
	StateInfo[JB.Linked] := "Linked";
	StateInfo[JB.Initialized] := "Initialized";
END Init;

PROCEDURE OnOff(msg: ARRAY OF CHAR;  VAR b: BOOLEAN);
VAR S: Attributes.Scanner;
BEGIN
	Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(S);  b := (S.class = Attributes.Name) & (S.s = "on");
	Out.String(msg);
	IF b THEN  Out.String("on")  ELSE  Out.String("off")  END;  Out.Ln;
END OnOff;

PROCEDURE Value(msg: ARRAY OF CHAR;  VAR v: LONGINT);
	VAR S: Attributes.Scanner;
BEGIN
	Attributes.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Attributes.Scan(S);
	v := S.i;
	Out.String(msg); Out.Int(v, 4); Out.Ln;
END Value;
(*
PROCEDURE GC*;
VAR  on: BOOLEAN;
BEGIN
	OnOff("GC is ", on);
	IF on THEN  Kernel.EnableGC()  ELSE  Kernel.DisableGC()  END
END GC;
*)
PROCEDURE Verbose*;
VAR  val: LONGINT;
BEGIN
	Value("Verbose is ", val);  JVM.Trace := SYSTEM.VAL(SET, val)	
END Verbose;

PROCEDURE TraceMethods*;
	VAR b: BOOLEAN;
BEGIN
(*
	IF JVMCompiler.TraceMethods THEN
*)
		OnOff("TraceMethods is ", b);
		JVM.traceMethods := b
(*
	ELSE
		Out.String("JVMCompiler.TraceMethods cannot be enabled!")
	END;
*)
END TraceMethods;

BEGIN	
	Texts.OpenWriter(W);
	Normal := Fonts.This("Syntax10.Scn.Fnt");
	Bold := Fonts.This("Syntax10b.Scn.Fnt");
	Init
END JVMDebug.

(*
	19.03.02	prk	export mapping information, allow compilation step to generate map
	19.03.02	prk	method call tracing
	19.03.02	prk	trace informations improved
	21.08.01	prk	remove internal class-list, use PCT one instead
	16.08.01	prk	take procedure information from PCT+PCBT
	27.06.01	prk	StringPool cleaned up
	25.04.01	prk	if no methods, use array of length 0 instead of NIL
	25.04.01	prk	if no fields, use array of length 0 instead of NIL
	04.04.01	prk	merge with classpath-0.00 release, prepare for update with 0.01, minimize differencies
	28.03.01	prk	Cleaned up and Fixed
*)