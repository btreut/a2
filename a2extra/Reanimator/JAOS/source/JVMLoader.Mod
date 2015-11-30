(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMLoader;	(** PRK **)
(*
	Internalize a Class File
*)


IMPORT
		SYSTEM, AosFS, AosModules,
		AosProcessors,	(* trace/debugging only *)
		StringPool, PCM, PCT, PCBT, PCOM, 
		PCV,
		JC := JVMConsole, jjlObject, jjlString,
		JT := JVMTypes, JB := JVMBase, JS := JVMSystem, Refs := JVMRefs, JI := JVMInterfaces,
		JIS := jjiInputStream, FIS := jjiFileInputStream, FD := jjiFileDescriptor;


CONST
	(*Tracing Modes*)
		TraceFields = 1;
		TraceMethods = 2;
		TraceClasses = 3;
	Tracing = {TraceClasses};
	
	Debug = FALSE;
	
	CheckNative = FALSE;

	Trace = TRUE;

VAR
	debugInfo, warningInfo, infoInfo, errorInfo, failureInfo: JC.LoggingInfo;
	
TYPE
	ASyntheticInfo = POINTER TO RECORD (JB.AInfo) END;
	
VAR
	ConstParser: ARRAY 13 OF PROCEDURE (in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);

	loading*: LONGINT;	(* n of LoadCalls calls currently active; used by JVM.LoaderPlugin to avoid recursive calls *)
	
	dontTrap*: BOOLEAN;	(* no trap if a class is not found *)
	missingClass*: JT.StringBuffer;
	
	classStr, objStr, initStr: StringPool.Index;


	Ainterfaces, AinterfaceMethods, AlocalInterfaceMethods: LONGINT;
	
(* Helper Procedures *)

PROCEDURE Append(VAR to: ARRAY OF CHAR; str: ARRAY OF CHAR; from: LONGINT);
	VAR i: LONGINT;
BEGIN
	ASSERT(to[from] = 0X);
	i := -1;
	REPEAT
		INC(i); to[from+i] := str[i]
	UNTIL str[i] = 0X;
END Append;


(* NON PORTABLE FUNCTIONS *)

PROCEDURE ReadU8(in: JIS.InputStream; VAR u8: ARRAY OF SYSTEM.BYTE);
VAR read: LONGINT; tmp: ARRAY 8 OF CHAR;
BEGIN
	ASSERT(LEN(u8) = 8);
	read := in.readByteArray(tmp, 0, 8);
	ASSERT(read = 8);
	u8[0] := tmp[7];
	u8[1] := tmp[6];
	u8[2] := tmp[5];
	u8[3] := tmp[4];
	u8[4] := tmp[3];
	u8[5] := tmp[2];
	u8[6] := tmp[1];
	u8[7] := tmp[0];
END ReadU8;

PROCEDURE ReadU4(in: JIS.InputStream; VAR u4: ARRAY OF SYSTEM.BYTE);
VAR read: LONGINT; tmp: ARRAY 4 OF CHAR;
BEGIN
	ASSERT(LEN(u4) = 4);
	read := in.readByteArray(tmp, 0, 4);
	ASSERT(read = 4);
	u4[0] := tmp[3];
	u4[1] := tmp[2];
	u4[2] := tmp[1];
	u4[3] := tmp[0];
END ReadU4;

PROCEDURE ReadU2(in: JIS.InputStream; VAR u2: LONGINT);
VAR b2: ARRAY 2 OF CHAR;
	read: LONGINT;
BEGIN
	u2 := 0;
	read := in.readByteArray(b2, 0, 2);
	ASSERT(read = 2);
	(* do not sign extend it *)
	SYSTEM.MOVE(SYSTEM.ADR(b2[0]), SYSTEM.ADR(u2)+1, 1);
	SYSTEM.MOVE(SYSTEM.ADR(b2[1]), SYSTEM.ADR(u2), 1);
END ReadU2;

PROCEDURE ReadU1(in: JIS.InputStream; VAR u1: LONGINT);
VAR b: ARRAY 1 OF CHAR;
	read: LONGINT;
BEGIN
	u1 := 0;
	read := in.readByteArray(b, 0, 1); 
	(* do not sign extend it *)
	SYSTEM.MOVE(SYSTEM.ADR(b[0]), SYSTEM.ADR(u1), 1)
END ReadU1;

PROCEDURE ReadFlags(in: JIS.InputStream; VAR s: SET);
VAR tmp, i: LONGINT;
BEGIN
	ReadU2(in, tmp);
	i := 0; s := {};
	WHILE i < 16 DO
		IF ODD(tmp) THEN INCL(s, i)  END;
		tmp := tmp DIV 2; INC(i)
	END
END ReadFlags;

(* Common functions, very ofter used patterns *)

PROCEDURE ClassFormatError;
BEGIN
	INC(JB.AloadException);
	JB.Throw(JB.ThisClass0("java/lang/ClassFormatError", TRUE)); HALT(99)
END ClassFormatError;

(* ** Procedure Used to read and Check the Constant Pool Entries *************************************************)

PROCEDURE CReadUnicode(in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);
	VAR
		ch: CHAR;
		Info: JB.CUnicodeInfo;
		val,
		pos, j: LONGINT;
		tmp: ARRAY 16*1024 OF CHAR;
BEGIN
	IF c[i] = NIL THEN  NEW(Info); c[i] := Info  ELSE  Info := c[i](JB.CUnicodeInfo)  END;
	ReadU2(in, j); pos:=0;
	WHILE pos < j DO
		ReadU1(in, val);
		tmp[pos] := CHR(val); INC(pos);
		ASSERT(val # 0);
	END;
	tmp[pos] := 0X;
	StringPool.GetIndex(tmp, Info.index);
	JT.Utf8ToUnicode(tmp, pos, Info.str);
END CReadUnicode;

PROCEDURE CReadInteger(in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);
VAR Info: JB.CConstInfo; j: LONGINT;
BEGIN
	NEW(Info); ReadU4(in, j); Info.c := PCT.NewIntConst(j, PCT.Int32); c[i] := Info
END CReadInteger;

PROCEDURE CReadFloat(in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);
VAR Info: JB.CConstInfo; f: REAL;
BEGIN
	NEW(Info); ReadU4(in, f); Info.c := PCT.NewFloatConst(f, PCT.Float32); c[i] := Info
END CReadFloat;

PROCEDURE CReadLong(in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);
VAR Info: JB.CConstInfo; h: HUGEINT;
BEGIN
	NEW(Info); ReadU8(in, h); Info.c := PCT.NewInt64Const(h); c[i] := Info
END CReadLong;

PROCEDURE CReadDouble(in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);
VAR Info: JB.CConstInfo; f: LONGREAL;
BEGIN
	NEW(Info); ReadU8(in, f); Info.c := PCT.NewFloatConst(f, PCT.Float64); c[i] := Info
END CReadDouble;

PROCEDURE CReadClass(in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);
VAR Info: JB.CClassInfo; n: LONGINT; 
BEGIN
	IF c[i] = NIL THEN  NEW(Info); c[i] := Info  ELSE  Info := c[i](JB.CClassInfo)  END;
	ReadU2(in, n);
	IF c[n] = NIL THEN
		NEW(Info.index); c[n] := Info.index
	ELSE
		Info.index := c[n](JB.CUnicodeInfo)
	END
END CReadClass;

PROCEDURE CReadString(in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);
VAR Info: JB.CStringInfo; n:LONGINT;
BEGIN
	NEW(Info); c[i]:=Info;
	ReadU2(in, n); 
	IF c[n] = NIL THEN
		NEW(Info.index); c[n] := Info.index
	ELSE
		Info.index := c[n](JB.CUnicodeInfo)
	END;
END CReadString;

PROCEDURE CReadRef(in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);
VAR Info: JB.CRefInfo; n:LONGINT;
BEGIN
	NEW(Info); c[i]:=Info;
	ReadU2(in, n);
	IF c[n] = NIL THEN
		NEW(Info.cindex); c[n] := Info.cindex
	ELSE
		Info.cindex := c[n](JB.CClassInfo)
	END;
	ReadU2(in, n);
	IF c[n] = NIL THEN
		NEW(Info.ntindex); c[n] := Info.ntindex
	ELSE
		Info.ntindex := c[n](JB.CNameAndTypeInfo)
	END;
END CReadRef;

PROCEDURE CReadNameAndType(in: JIS.InputStream; c: JB.ConstPool; i: LONGINT);
VAR Info: JB.CNameAndTypeInfo; n: LONGINT;
BEGIN
	IF c[i] = NIL THEN  NEW(Info); c[i]:=Info  ELSE  Info := c[i](JB.CNameAndTypeInfo)  END;
	ReadU2(in, n);
	IF c[n] = NIL THEN
		NEW(Info.name); c[n] := Info.name
	ELSE
		Info.name := c[n](JB.CUnicodeInfo)
	END;
	ReadU2(in, n);
	IF c[n] = NIL THEN
		NEW(Info.type); c[n] := Info.type
	ELSE
		Info.type := c[n](JB.CUnicodeInfo)
	END
END CReadNameAndType;


PROCEDURE CompletePool(cf: JB.RefClass);
VAR c: JB.ConstPool; cinfo: JB.CInfo; class: JB.CClassInfo; ref: JB.CRefInfo; str: JB.CStringInfo; i: LONGINT;

BEGIN
	NEW(class); cf.constPool[0] := class; class.class := cf;
	i := 1; c := cf.constPool;
	WHILE i < LEN(c^) DO
		cinfo := c[i];
		CASE cinfo.tag OF
		| JB.CClass:
			 class := cinfo(JB.CClassInfo); 
			 
		| JB.CFieldref, JB.CMethodref, JB.CInterfaceMethodref:
			ref := cinfo(JB.CRefInfo);
			ref.ownclass := cf;
			ref.ref := NIL;
 		(*
			IF ref.tag = JB.CFieldref THEN (*JT.ParseType(ref.ntindex.type.str, ref.size, b)*)
			ELSE JT.ParseSignature(ref.ntindex.type.str, ref.parsize, ref.retsize, ref.retfp) END
		*)
		| JB.CString:
			str := cinfo(JB.CStringInfo);
			str.c := PCT.NewPtrConst(jjlString.MakeLiteral(str.index.str, LEN(str.index.str^)), PCT.Ptr)
		| JB.CLong, JB.CDouble: INC(i)
		ELSE	(*skip*)
		END;
		INC(i)
	END
END CompletePool;

PROCEDURE ReadConstPool(in: JIS.InputStream; VAR cp: JB.ConstPool);
VAR count, i, tag: LONGINT;
BEGIN
	ReadU2(in, count); NEW(cp, count);
	i := 1;
	WHILE i < count DO
		ReadU1(in, tag); ConstParser[tag](in, cp, i); cp[i].tag := tag;
		IF tag IN {JB.CLong, JB.CDouble} THEN INC(i, 2)  ELSE  INC(i)  END
	END
END ReadConstPool;

(* direct implemented interfaces *)
PROCEDURE ParseInterfaces(in: JIS.InputStream; c: JB.RefClass; VAR intf: ARRAY OF PCT.Interface);
VAR count, tag, i: LONGINT;
	cls: JB.Class;
BEGIN
	ReadU2(in, count);
	IF count > 0 THEN  NEW(c.interfaces, count); i := 0;
		WHILE i < count DO
			ReadU2(in, tag); 
			(* at this point, interfaces must be loaded *)
			cls := JB.ThisClass(c.constPool[tag](JB.CClassInfo).index.str, TRUE);
			c.interfaces[i]:= cls(JB.InterfaceClass);
			intf[i] := cls.type;
			INC(i)
		END
	END;
END ParseInterfaces;

PROCEDURE ParseFields(in: JIS.InputStream; c: JB.RefClass; interface: BOOLEAN);
VAR count, attrib, tag, i: LONGINT; huge: HUGEINT;  co: JB.ObjectClass;  body: Refs.Ref;  var: Refs.Var;  name: ARRAY 32 OF CHAR;
	type: PCT.Struct; vis: SET; idx0: StringPool.Index; res: LONGINT; str: JT.String;
	check: BOOLEAN; static, fld: PCT.Variable; t: PCT.RecScope; con: PCT.Const; const: PCT.Value;
	dummy: LONGINT;
	flags: SET; 
	jname: JB.CUnicodeInfo;
	x: ARRAY 256 OF CHAR;
	
	PROCEDURE FieldMismatch(idx: StringPool.Index; msg: ARRAY OF CHAR; fatal: BOOLEAN);
		VAR name: ARRAY 128 OF CHAR;
	BEGIN
		StringPool.GetString(idx, name);
		JC.String(failureInfo, c.obmod); JC.Char(failureInfo, "."); JC.String(failureInfo, name);
		JC.String(failureInfo, ": "); JC.String(failureInfo, msg); JC.Ln(failureInfo);
		IF fatal & ~JB.DontRun THEN JC.String(failureInfo, ": DontRun set!"); JC.Ln(failureInfo) END;
		JB.DontRun := JB.DontRun OR fatal
	END FieldMismatch;
	
	PROCEDURE PatchStaticOffsets(c: JB.RefClass);
		VAR adr, fp, i: LONGINT; o: PCT.Symbol; fld: PCT.Variable; name: JT.StringBuffer; scope: PCT.ModScope;
	BEGIN
		scope := c.native.scope;
		fld := c.moduleS.firstVar;
		WHILE fld # NIL DO
			StringPool.GetString(fld.name, name);
			JT.MakeIdent0(name, name);
			o := PCT.Find(scope, scope, StringPool.GetIndex1(name), PCT.structdeclared, FALSE);
			IF o = NIL THEN
				FieldMismatch(StringPool.GetIndex1(name), "no such static field in native module", TRUE)
			ELSE
				PCOM.FPrintObj(o, c.native); fp := o.sym(PCOM.Symbol).fp;
				i := 0;
				WHILE (i < c.stub.export.exports) & (fp # c.stub.export.dsc[i].fp) DO  INC(i)  END;
				IF i = c.stub.export.exports THEN
					FieldMismatch(fld.name, "fp mismatch", TRUE)
				ELSIF c.stub.export.dsc[i].adr >= 0 THEN
					FieldMismatch(fld.name, "not a variable", TRUE)
				ELSE
					adr := c.stub.export.dsc[i].adr;
					fld.adr(PCBT.Variable).offset := adr;
				END
			END;
			fld := fld.nextVar
		END
	END PatchStaticOffsets;
	
	PROCEDURE Assert(cond: BOOLEAN; idx: LONGINT);
		VAR str: ARRAY 256 OF CHAR; o: PCT.Symbol;
	BEGIN
		IF ~cond THEN
			StringPool.GetString(idx, str);
			JC.String(errorInfo, "Assert: ");
			JC.String(errorInfo, c.obmod); JC.Char(errorInfo, "."); JC.String(errorInfo, str); JC.Ln(errorInfo);
			o := c.moduleS.sorted;
			WHILE o # NIL DO
				StringPool.GetString(o.name, str); JC.String(errorInfo, str); JC.Ln(errorInfo);
				o := o.sorted
			END
		END
	END Assert;

BEGIN
	IF ~interface THEN  co := c(JB.ObjectClass)  END;	(*alias*)
	IF ~interface & (c.superClass # NIL) THEN
		JS.GetNofPtrs(c.superClass(JB.ObjectClass).typedesc, co.dynamicPtrFields)
	END;
	IF c.native # NIL THEN
		check := TRUE;
		t := GetType(c.native, c.obobj);
		fld := t.firstVar;
	END;
	ReadU2(in, count);
	i := 0;
	WHILE i < count DO
		ReadFlags(in, flags);
		ReadU2(in, tag);
		jname := c.constPool[tag](JB.CUnicodeInfo);
		ReadU2(in, tag);
		str := c.constPool[tag](JB.CUnicodeInfo).str; JT.ParseType(str, type);
		ReadU2(in, attrib); con := NIL;
		WHILE attrib > 0 DO	(* reading field attributes *)
			ReadU2(in, tag);	(*attribute name*)
			IF ~JT.Equal0(c.constPool[tag](JB.CUnicodeInfo).str, LEN(c.constPool[tag](JB.CUnicodeInfo).str), "ConstantValue") THEN
				ReadU4(in, tag);	(*size*)
				huge := in.skip(tag)
			ELSIF con = NIL THEN
				ReadU4(in, tag); ASSERT(tag = 2);	(* constantvalue attribute has always size 2 *)
				ReadU2(in, tag);
				con := c.constPool[tag](JB.CConstInfo).c
			ELSE HALT(99)	(*panic, more than one const-value*)
			END;
			DEC(attrib)
		END;	(* if attributes *)
		IF JB.AFPublic IN flags THEN vis := PCT.Public ELSIF JB.AFProtected IN flags THEN vis := PCT.Protected+PCT.Internal ELSE vis := PCT.Internal END;
		IF JB.AFStatic IN flags THEN
			IF con # NIL THEN
				IF check THEN
					JT.MakeIdent(jname.str, name); StringPool.GetIndex(name, idx0);
					const := c.native.scope.firstValue;
					WHILE (const # NIL) & (const.name # idx0) DO const := const.nextVal END;
					IF const = NIL THEN
						FieldMismatch(jname.index, "no const found in native module", TRUE)
					ELSE
						con := const.const	(*override value*)
					END
				END;
				ASSERT(JB.AFFinal IN flags);
				c.moduleS.CreateValue(jname.index, vis, con, res); ASSERT(res = PCT.Ok);
				con := NIL;
			ELSE
				c.moduleS.CreateVar(jname.index, vis, {}, type, res); Assert(res = PCT.Ok, jname.index); res := 0;
				IF PCT.IsPointer(type) THEN  INC(c.staticPtrFields)  END;
			END
		ELSE
			ASSERT(~interface);	(* an interface does not contain any dynamic fields, and no dynamic pointers *)
			IF check THEN
				JT.MakeIdent(jname.str, name); StringPool.GetIndex(name, idx0);
				IF (fld = NIL) OR (fld.name # idx0) THEN
					FieldMismatch(jname.index, "no field found in native module", TRUE)
				ELSIF ~TypeCompatible(fld.type , type) THEN
					FieldMismatch(jname.index, "invalid type in native module", FALSE);
					fld := fld.nextVar
				ELSE
					fld := fld.nextVar
				END;
			END;

			IF con # NIL THEN
				JC.String(warningInfo, "non-static final field"); JC.Ln(warningInfo);
				ASSERT(JB.AFFinal IN flags);
			END;
			c.typeS.CreateVar(jname.index, vis, {}, type, res); ASSERT(res = PCT.Ok);
			IF PCT.IsPointer(type) THEN  INC(co.dynamicPtrFields)  END;
		END;
		INC(i)
	END; (*while fields*)
	IF check THEN	(* additional fields from the native implementation *)
		WHILE fld # NIL DO
			c.typeS.CreateVar(fld.name, fld.vis, {}, fld.type, res);
			IF res # PCT.Ok THEN
				JC.String(failureInfo, "Error inserting native field "); JC.StrIdx(failureInfo, fld.name);
				JC.String(failureInfo, "  res = "); JC.Int(failureInfo, res, 0); JC.Ln(failureInfo);
				ASSERT(res = PCT.Ok);
			END;
			fld := fld.nextVar
		END;
	END;

	ASSERT(c.typeS.owner.size = NIL);

	PCT.ChangeState(c.typeS, PCT.structallocated, -2);
	PCT.ChangeState(c.moduleS, PCT.structallocated, -2);
	IF check THEN PatchStaticOffsets(c) END
END ParseFields;

PROCEDURE AllocateFields(c: JB.RefClass);
VAR sptr, dptr: LONGINT; p: PCT.Variable;
	state, own, own2: LONGINT; size: PTR;
BEGIN
	ASSERT(c.stub = NIL);
	IF c.moduleS.varCount > 0 THEN
		JS.CreateStaticData(c.ownModule, c.module.adr(PCBT.Module).locsize, c.staticPtrFields)
	END;
	IF c.staticPtrFields # 0 THEN
		sptr := 0;
		p := c.moduleS.firstVar;
		WHILE p # NIL DO
			IF PCT.IsPointer(p.type) THEN
				JS.PatchStaticPtr(c.ownModule, sptr, p.adr(PCBT.Variable).offset); INC(sptr)
			END;
			p := p.nextVar
		END;
		ASSERT(sptr = c.staticPtrFields, 500);
	END;
	IF ~(JB.AFInterface IN c.flags) THEN
		WITH c: JB.ObjectClass DO
			IF c.dynamicPtrFields # 0 THEN
				IF c.superClass = NIL THEN
					dptr := 0
				ELSE
					JS.GetNofPtrs(c.superClass(JB.ObjectClass).typedesc, dptr)
				END;
				p := c.typeS.firstVar;
				WHILE p # NIL DO
					IF PCT.IsPointer(p.type) THEN
						IF p.adr = NIL THEN
							state := c.typeS.state;
							own := c.typeS.ownerID;
							own2 := PCM.GetProcessID();
							size := c.typeS.owner.size;
						END;
						JS.PatchPtr(c.typedesc, dptr, p.adr(PCBT.Variable).offset); INC(dptr)
					END;
					p := p.nextVar
				END;
				ASSERT(dptr = c.dynamicPtrFields, 501);
			END
		END
	END
END AllocateFields;

(** LoadCode - Force loading the byte-code before compilation *)

PROCEDURE LoadCode*(c: JB.RefClass);
	VAR f: AosFS.File; r: AosFS.Rider; name: ARRAY 256 OF CHAR; i: LONGINT; code: JB.ACodeInfo;
BEGIN
	JT.JavaToOberonString(c.name, 0, LEN(c.name), name);
	Append(name, ".class", LEN(c.name));
	f := AosFS.Old(name);
	ASSERT(f # NIL);
	FOR i := 0 TO LEN(c.methods^)-1 DO
		code := c.methods[i].code;
		IF code # NIL THEN
			ASSERT(code.code = NIL);
			NEW(code.code, code.len);
			f.Set(r, code.pos);
			f.ReadBytes(r, code.code^, 0, code.len)
		END
	END
END LoadCode;

PROCEDURE ParseAttributes(in: JIS.InputStream; VAR root: JB.AInfo; con: JB.ConstPool; skip: BOOLEAN);
VAR  count, tag, len, i: LONGINT; str: JT.String;
	const: JB.AConstValueInfo; code: JB.ACodeInfo; source: JB.ASourceFileInfo;  inner: JB.AInnerInfo;
	exception: JB.AExceptionsInfo; line: JB.ALineNumberInfo; var: JB.ALocalVariableInfo;
	synth: ASyntheticInfo;
	ch: JT.Unicode;
	read: LONGINT; 
	dummy: HUGEINT;
	fis: FIS.FileInputStream;
BEGIN
	ReadU2(in, count);
	WHILE count > 0 DO
		ReadU2(in, tag); str := con[tag](JB.CUnicodeInfo).str;
		ReadU4(in, len);

		IF skip THEN (*JB.Warning("Skipping 2-nd level Attributes ", str);*)  ch := str[0];  str[0] := ORD(" ") END;

		IF JT.Equal0(str, LEN(str), "ConstantValue") THEN
			NEW(const); const.next := root; root := const;
			ReadU2(in, tag); const.const := con[tag];
		ELSIF JT.Equal0(str, LEN(str), "Code") THEN
			NEW(code); code.next := root; root := code;
			ReadU2(in, code.maxStack);  ReadU2(in, code.maxLocals);
			ReadU4(in, len);
			IF in IS FIS.FileInputStream THEN
				code.len := len;
				fis := in(FIS.FileInputStream);
				code.pos := SHORT(fis.fd.nativeGetFilePointer(fis.fd.nativeFd));
(*
				code.pos := FD.FileTable[fis.nativefd].file.Pos(FD.FileTable[fis.nativefd]);
*)
				dummy := fis.skip(len);
				ASSERT(dummy = len);
			ELSE
				NEW(code.code, len); 
				read := in.readByteArray(code.code^, 0, len);
			END;
			ReadU2(in, len);
			IF len # 0 THEN
				NEW(code.exceptions, len); i := 0;
				WHILE i < len DO
					ReadU2(in, code.exceptions[i].start); ReadU2(in, code.exceptions[i].end);
					ReadU2(in, code.exceptions[i].handler);
					ReadU2(in, tag);
					IF tag # 0 THEN 
						code.exceptions[i].ex := con[tag](JB.CClassInfo).index.str;
					ELSE
						code.exceptions[i].ex := NIL
					END;
					INC(i)
				END
			END;
			ParseAttributes(in, code.attributes, con, TRUE)
		ELSIF JT.Equal0(str, LEN(str), "SourceFile") THEN
			NEW(source); source.next := root; root := source;
			ReadU2(in, tag); source.sourcefile := con[tag](JB.CUnicodeInfo).str
		ELSIF JT.Equal0(str, LEN(str), "Exceptions") THEN
			NEW(exception); exception.next := root; root := exception;
			ReadU2(in, len); 
			IF len > 0 THEN
				NEW(exception.table, len); i := 0;
				WHILE i < len DO
					ReadU2(in, tag); 
					IF tag # 0 THEN exception.table[i] := con[tag](JB.CClassInfo) END;
					INC(i)
				END
			END
		ELSIF JT.Equal0(str, LEN(str), "LineNumberTable") THEN
			NEW(line); line.next := root; root := line;
			ReadU2(in, len);
			IF len > 0 THEN
				NEW(line.table, len); i := 0;
				WHILE i < len DO
					ReadU2(in, line.table[i].start); ReadU2(in, line.table[i].line); 
					INC(i)
				END
			END
		ELSIF JT.Equal0(str, LEN(str), "LocalVariableTable") THEN
			NEW(var); var.next := root; root := var;
			ReadU2(in, len); 
			IF len > 0 THEN
				NEW(var.table, len); i := 0;
				WHILE i < len DO
					ReadU2(in, var.table[i].start); ReadU2(in, var.table[i].length);
					ReadU2(in, tag); var.table[i].name := con[tag](JB.CUnicodeInfo).str;
					ReadU2(in, tag); var.table[i].descriptor := con[tag](JB.CUnicodeInfo).str;
					ReadU2(in, var.table[i].index);
					INC(i)
				END
			END
		ELSIF JT.Equal0(str, LEN(str), "Deprecated") THEN (* do nothing *)
		ELSIF JT.Equal0(str, LEN(str), "Synthetic") THEN (* do nothing *)
			NEW(synth); synth.next := root; root := synth
		ELSIF JT.Equal0(str, LEN(str), "InnerClasses") THEN (* do nothing *)
			NEW(inner); inner.next := root; root := inner;
			ReadU2(in, len);
			IF len > 0 THEN
				NEW(inner.table, len);
				i := 0;
				WHILE i < len DO
					ReadU2(in, inner.table[i].innerClass);
					ReadU2(in, inner.table[i].outerClass);
					ReadU2(in, inner.table[i].name);
					ReadFlags(in, inner.table[i].flags);

					JC.String(debugInfo, "Inner "); JC.Int(debugInfo, i, 0); JC.String(debugInfo, ": ");
					IF inner.table[i].innerClass = 0 THEN
						JC.String(debugInfo, "--")
					ELSE
						JC.Str(debugInfo, con[inner.table[i].innerClass](JB.CClassInfo).index.str)
					END;
					JC.String(debugInfo, " ~ ");
					IF inner.table[i].outerClass = 0 THEN
						JC.String(debugInfo, "--")
					ELSE
						JC.Str(debugInfo, con[inner.table[i].outerClass](JB.CClassInfo).index.str)
					END;
					JC.String(debugInfo, " ~ ");
					IF inner.table[i].name = 0 THEN
						JC.String(debugInfo, "--")
					ELSE
						tag := con[inner.table[i].name].tag;
						JC.Str(debugInfo, con[inner.table[i].name](JB.CUnicodeInfo).str)
					END;
					JC.Ln(debugInfo);

					INC(i)
				END
			END
		ELSE
			IF skip THEN  str[0] := ch
			ELSIF Trace THEN  JC.String(warningInfo, "Loader: Unknown Attribute "); JC.Str(warningInfo, str); JC.Ln(warningInfo)  END;
			WHILE len > 0 DO  ReadU1(in, tag); DEC(len)  END;
		END;
		DEC(count)
	END
END ParseAttributes;

(* search for a method number;  *)
PROCEDURE FindMethodNumber(c: JB.RefClass; mth: JB.Method): LONGINT;
VAR  i: LONGINT;
		cur: JB.RefClass;
		m: JB.Method;
BEGIN
	(* lookup in the superclasses for a method with same name, and signature *)
	cur:= c.superClass;
	WHILE cur # NIL DO
		FOR i := 0 TO LEN(cur.methods^)-1 DO
			m := JB.FindMethod(mth.name.value.p, mth.descriptor, cur.methods^, 0, LEN(cur.methods) -1);
			IF (m # NIL) & ~(JB.AFPrivate IN m.flags) THEN RETURN m.mno END
		END;
		cur := cur.superClass
	END;
	(* no implementation present so far *)

	(* INC(c.dynamicMethods); *)
	IF c.stub # NIL THEN (* an implementation might be present in the stub-module; we must use the same mno *)
		RETURN JS.GetMno(c.typedesc, mth.stubadr);
	END;

	RETURN -1
END FindMethodNumber;

PROCEDURE FindDuplicates(c: JB.RefClass; cur: LONGINT): LONGINT;
VAR static: BOOLEAN;  count, i: LONGINT;  p: JB.RefClass; cm, tm: JB.Method;
BEGIN
	cm := c.methods[cur];
	static := JB.AFStatic IN cm.flags;
	p := c;  i := cur;  count := -1;
	WHILE p # NIL DO
		WHILE i > 0 DO
			DEC(i);
			tm := p.methods[i];
			IF jjlString.EqualStrings(tm.name, cm.name) & 
				((JB.AFStatic IN tm.flags) = static) THEN
				IF JT.Equal(tm.descriptor, LEN(tm.descriptor), cm.descriptor, LEN(cm.descriptor)) THEN 		(* it's the same method *)
					(* marks overwrite *)
					IF ~(JB.AFStatic IN tm.flags) & (p # c) THEN
						cm.mno := tm.mno
					END;
					RETURN tm.try
				ELSE (* there is a method with same name but different signature *)
					IF ((p = c) (* same class and not overwritten *)
						&((JB.AFStatic IN tm.flags) OR (tm.mno < 0)))THEN 						  (* it does not overwrite anything *)
						 tm.try:= 1;
					END;
					RETURN 1														 
				END
			END
		END;
		p := p.superClass;
		IF (p # NIL) THEN  i := LEN(p.methods) END
	END;
	RETURN count+1
END FindDuplicates;

PROCEDURE ParseMethods(in: JIS.InputStream;  c: JB.RefClass;  VAR hasNative: BOOLEAN;  interface: BOOLEAN);
VAR count, tag, i, ptrsize: LONGINT; p: JB.AInfo; m: JB.Method;
	scope: PCT.ProcScope; rettype: PCT.Struct; vis: SET; idx: StringPool.Index; res: LONGINT;
	str: ARRAY 256 OF CHAR; par: PCT.Parameter;
BEGIN
	IF Debug THEN JC.String(debugInfo, ">ParseMth "); JC.String(debugInfo, c.obmod); AosProcessors.GlobalGC END;
	hasNative := FALSE;
	ptrsize := 4;
	ReadU2(in, count);
	NEW(c.methods, count); i := 0;
	WHILE i < count DO
		NEW(m); c.methods[i] := m;
		m.declaringClass := c;
		m.mno := -1;
		ReadFlags(in, m.flags);
		hasNative := hasNative OR (JB.AFNative IN m.flags);
		ReadU2(in, tag); m.name := jjlString.CreateString(c.constPool[tag](JB.CUnicodeInfo).str);
		idx := c.constPool[tag](JB.CUnicodeInfo).index;
		ReadU2(in, tag); m.descriptor := c.constPool[tag](JB.CUnicodeInfo).str;
		ParseAttributes(in, m.attributes, c.constPool, FALSE);
		p := m.attributes;
		WHILE (p#NIL)  & ~(p IS JB.ACodeInfo) DO p := p.next  END;
		IF p#NIL THEN
			m.code := p(JB.ACodeInfo)
		END;
		p := m.attributes;
		WHILE (p#NIL)  & ~(p IS ASyntheticInfo) DO p := p.next  END;
		IF p#NIL THEN
			JC.Str(infoInfo, m.name.value.p); JC.String(infoInfo, " is synthetic"); JC.Ln(infoInfo);
		END;
		NEW(scope); PCT.SetOwner(scope);
		IF JB.AFStatic IN m.flags THEN
			PCT.InitScope(scope, c.moduleS, {}, JT.ScopeIsImported)
		ELSE
			PCT.InitScope(scope, c.typeS, {}, JT.ScopeIsImported)
		END;
		JT.ParseSignature(m.descriptor, m.parsize, scope, rettype);
		m.try := FindDuplicates(c, i);
		IF interface OR (JB.AFPublic IN m.flags) THEN vis := PCT.Public ELSE vis := PCT.Internal END;
		
		IF JB.AFStatic IN m.flags THEN
			c.moduleS.CreateProc(idx, vis, {}, scope, rettype, res); ASSERT(res = PCT.Ok);
			m.p := c.moduleS.lastProc;
			c.moduleS.lastProc.info := m
		ELSE
			scope.CreatePar(PCT.Public, FALSE, PCT.SelfName, {}, c.type, res); ASSERT(res = PCT.Ok);	(*imported method, must define self*)
			IF idx = initStr THEN
				c.typeS.CreateProc(idx, vis, {PCT.NonVirtual}, scope, rettype, res)
			ELSE
				c.typeS.CreateProc(idx, vis, {}, scope, rettype, res)
			END;
			IF res # PCT.Ok THEN
				IF interface THEN
					res := 0;
					m.p := PCT.FindSameSignature(c.typeS, idx, scope.firstPar, TRUE);
					m.p.info := m
				ELSE
					HALT(99)
				END
			ELSE
				m.p := c.typeS.lastProc;
				c.typeS.lastProc.info := m
			END;
			INC(m.parsize, 4); 	(* implicit par SELF *)
		END;
		INC(i); 
	END;
	IF count > 0 THEN
		JB.SortMethods(c.methods^, 0, LEN(c.methods^)-1);
	END;
	IF Debug THEN JC.String(debugInfo, "<"); AosProcessors.GlobalGC; JC.Ln(debugInfo) END;
	PCT.ChangeState(c.typeS, PCT.modeavailable (*PCT.procdeclared*), -2);
	PCT.ChangeState(c.moduleS, PCT.procdeclared, -2)
END ParseMethods;

PROCEDURE CountMethods(c: JB.RefClass):LONGINT;
BEGIN
	c := c.superClass;
	IF c # NIL THEN RETURN c.dynamicMethods ELSE RETURN 0 END
END CountMethods;

PROCEDURE TypeCompatible(native, java: PCT.Struct): BOOLEAN;
BEGIN
	RETURN (native = java) OR
		(native.owner.name = java.owner.name) OR	(* classes *)
		((native = PCT.Int16) & (java = PCT.Char16)) OR	(* unicode *)
		((java.owner.name = classStr) & PCT.IsPointer(native)) OR	(* arrays *)
		((native.owner.name = objStr) & PCT.IsPointer(java))	(* uses object to break recursion *)
END TypeCompatible;

PROCEDURE MatchParameters(s0, s1: PCT.ProcScope): BOOLEAN;
	VAR p0, p1: PCT.Parameter; res: BOOLEAN;
		c: LONGINT;
BEGIN
	IF s0.parCount # s1.parCount THEN
		JC.String(debugInfo, "*");
		res := FALSE
	ELSE
		p0 := s0.firstPar; p1 := s1.firstPar;
		LOOP
			IF p0 = p1 THEN EXIT	(* both NIL *)
			ELSIF ~TypeCompatible(p0.type, p1.type) THEN JC.Int(debugInfo, c, 0); EXIT
			END;
			INC(c);
			p0 := p0.nextPar; p1 := p1.nextPar
		END;
		res := p0 = p1
	END;
	RETURN res
END MatchParameters;

PROCEDURE MatchProc(name: StringPool.Index; p, firstProc: PCT.Proc): PCT.Proc;
BEGIN
	LOOP
		IF firstProc = NIL THEN EXIT
		ELSIF (firstProc.name = name) & MatchParameters(firstProc.scope, p.scope) THEN EXIT
		END;
		IF firstProc.name = name THEN JC.String(debugInfo, "$") END;
		firstProc := firstProc.nextProc
	END;
	RETURN firstProc
END MatchProc;

PROCEDURE GetType(m: PCT.Module; name: ARRAY OF CHAR): PCT.RecScope;
	VAR o: PCT.Type; idx: StringPool.Index;
BEGIN
	StringPool.GetIndex(name, idx);
	o := m.scope.firstType;
	WHILE (o.name # idx) DO o := o.nextType END;
	RETURN o.type(PCT.Pointer).base(PCT.Record).scope
END GetType;

PROCEDURE AssignMethodNumbers(c: JB.RefClass);
VAR i, j, first: LONGINT;
		m: JB.Method;
	    refName, oberonName: JT.StringBuffer;
		ref: Refs.Ref;
		isStatic: BOOLEAN; idx: StringPool.Index;
		pars: ARRAY 8 OF PCT.Struct;
		p: PCT.Parameter;
		proc: PCT.Proc;
		nameMatch: BOOLEAN; reason: LONGINT;
		typeS: PCT.RecScope;
BEGIN first := 0;
	IF c.stub # NIL THEN
		IF CheckNative THEN
			ASSERT(c.native # NIL);
			typeS := GetType(c.native, c.obobj);
		END;
		JS.GetClass(c.stub, c.obobj, c.typedesc);
		FOR i := 0 TO LEN(c.methods^)-1 DO
			m := c.methods[i];
			isStatic := JB.AFStatic IN m.flags;
			JT.MakeMethodName(m.name.value.p, m.descriptor, m.try = 0, oberonName);
			JT.MakeRefName(c.obobj, oberonName, isStatic, refName);
			ref := Refs.FindRefForName(c.stub, refName);
(*			
			JC.String(debugInfo, "Loader: check native implementation of ");
			JC.String(debugInfo, refName);
			JC.Ln(debugInfo);
*)			
			IF ref = NIL THEN
				JC.String(failureInfo, "Loader: method not in stub "); JC.String(failureInfo, c.obmod); 
				JC.Char(failureInfo, "."); JC.String(failureInfo, refName); JC.Ln(failureInfo);
				IF ~JB.DontRun THEN JC.String(failureInfo, "DontRun set!"); JC.Ln(failureInfo) END;
				JB.DontRun := TRUE;
			ELSE
				m.stubadr := JS.GetCodeBase(c.stub) + ref.offset;
			END;
			IF CheckNative THEN
				StringPool.GetIndex(oberonName, idx);
				nameMatch := FALSE;
			END;
			IF isStatic THEN
				IF CheckNative THEN
					proc := MatchProc(idx, m.p, c.native.scope.firstProc);
					IF proc = NIL THEN
						JC.String(infoInfo, "Loader0: sm "); JC.String(infoInfo, c.obmod); JC.String(infoInfo, "."); 
						JC.String(infoInfo, oberonName); JC.Ln(infoInfo)
					END
				END
			ELSE
				IF CheckNative THEN
					proc := MatchProc(idx, m.p, typeS.firstProc);
					IF proc = NIL THEN
						JC.String(infoInfo, "Loader0: dm "); JC.String(infoInfo, c.obmod); 
						JC.String(infoInfo, "."); JC.String(infoInfo, oberonName); JC.Ln(infoInfo)
					END;
				END;
				IF m.mno = -1 THEN
					m.mno := FindMethodNumber(c, m);
				END;
				IF m.mno = -1 THEN 
					(* for classes with stubs a methodnumber must be present *)
					JC.String(failureInfo, "Loader: method not in stub "); JC.String(failureInfo, oberonName); JC.Ln(failureInfo);
					IF ~JB.DontRun THEN JC.String(failureInfo, "DontRun set!"); JC.Ln(failureInfo) END;
					JB.DontRun := TRUE;
				END;
				m.p.adr(PCBT.Method).mthNo := m.mno
			END
		END;
		c.dynamicMethods := JS.CountDynamics(c.typedesc)
	ELSE
		c.dynamicMethods := CountMethods(c);																	(* number of methods of the superclass *)
		FOR i := 0 TO LEN(c.methods^)-1 DO
			m := c.methods[i];
			IF ~(JB.AFStatic IN m.flags) THEN
				m.mno := FindMethodNumber(c, m); (* is this method overwritten *)
				IF (m.mno = -1)  THEN m.mno := c.dynamicMethods; 
					INC(c.dynamicMethods) 
				END;
				m.p.adr(PCBT.Method).mthNo := m.mno
			END
		END 
	END;
	IF TraceMethods IN Tracing THEN
		JC.String(infoInfo, "Loader: Method Trace "); JC.Str(infoInfo, c.name); JC.Ln(infoInfo);
		FOR i := 0 TO LEN(c.methods^)-1 DO
			JC.String(infoInfo, "    "); JC.Str(infoInfo, c.methods[i].name.value.p); JC.Str(infoInfo, c.methods[i].descriptor);
			JC.Int(infoInfo, c.methods[i].mno); JC.String(infoInfo, "  "); JC.Hex(infoInfo, c.methods[i].stubadr); JC.Ln(infoInfo);
		END
	END;
END AssignMethodNumbers;

(** FixReferences - Find reference to fields/methods in other classes (force loading if not present) *)

PROCEDURE FixReferences*(c: JB.RefClass);	(*fields/methods must be already read*)
	VAR i: LONGINT; r: JB.CRefInfo; d: JB.RefClass;  warning: BOOLEAN; msg: ARRAY 64 OF CHAR;
BEGIN
	warning := FALSE;
	FOR i := 1 TO LEN(c.constPool^)-1 DO
		IF c.constPool[i] = NIL THEN	(*second word of double/long constants, ignore*)
(*
		ELSIF (c.constPool[i].tag = JB.CClass) & (c.constPool[i](JB.CClassInfo).class = NIL) THEN
			c.constPool[i](JB.CClassInfo).class := JB.ThisClass(c.constPool[i](JB.CClassInfo).index.str, TRUE)
*)
		ELSIF c.constPool[i].tag = JB.CFieldref THEN
			r := c.constPool[i](JB.CRefInfo); 
			IF r.cindex.class = NIL THEN r.cindex.class := JB.ThisClass(r.cindex.index.str, TRUE) END;
			r.effectiveClass := r.cindex.class;
			r.obj := JB.GetField0(r.effectiveClass, r.ntindex.name.index);
			IF r.obj = NIL THEN
				warning := TRUE; msg := " unresolved reference to ";
			ELSIF r.cindex.class # r.effectiveClass THEN
				warning := TRUE; msg := " effective class changed ";
			END
		ELSIF c.constPool[i].tag IN {JB.CMethodref, JB.CInterfaceMethodref} THEN
			r := c.constPool[i](JB.CRefInfo); 
			IF r.cindex.class = NIL THEN r.cindex.class := JB.ThisClass(r.cindex.index.str, TRUE) END;

			IF ~(r.cindex.class IS JB.RefClass) THEN
				JC.String(errorInfo, "JVMLoader.FixReferences Error: ");
				JC.Str(errorInfo, c.name);
				JC.String(errorInfo, " invalid reference to ");
				JC.Str(errorInfo, r.cindex.index.str);
				JC.String(errorInfo, " for ");
				JC.Str(errorInfo, r.ntindex.name.str);
				JC.String(errorInfo, " / ");
				JC.Str(errorInfo, r.ntindex.type.str);
				JC.Ln(errorInfo);
			END;
			IF r.cindex.class IS JB.ArrayClass THEN
				d := jjlObject.class(JB.RefClass)
			ELSE
				d := r.cindex.class(JB.RefClass)
			END;
			r.ref := NIL;
			WHILE (d # NIL) & (r.ref = NIL) DO
			 	r.ref := JB.FindMethod(r.ntindex.name.str, r.ntindex.type.str, d.methods^ , 0, LEN(d.methods^)-1);
			 	d := d.superClass
			 END;
			warning := r.ref = NIL;
			msg := " unresolved reference to ";
		END;
		IF warning THEN
			JC.String(warningInfo, "JVM Warning: ");
			JC.Str(warningInfo, c.name);
			JC.String(warningInfo, msg);
			JC.QualId(warningInfo, r.cindex.index.str, r.ntindex.name.str);
			JC.Ln(warningInfo);
			warning := FALSE
		END
	END
END FixReferences;

(**  LoadClassByStream - Internalize a class file, register in the global class table *)

PROCEDURE LoadClassByStream*(in: JIS.InputStream): JB.Class;
VAR magic, minor, major, i, super, this, res: LONGINT; hasNative, isInterface: BOOLEAN;
	access: SET;
	cp: JB.ConstPool;
	c: JB.RefClass;
	superCls: JB.Class;
	scope: PCT.ModScope; mod: PCT.Module; name: ARRAY 256 OF CHAR;
	rscope: PCT.RecScope; superclass: PCT.Struct; o: PCT.Symbol; type: PCT.Pointer;
	intf: ARRAY 32 OF PCT.Interface; classname, modname, stubname: StringPool.Index;
	cache: BOOLEAN;

	PROCEDURE CompleteObjectClass;
	VAR co: JB.ObjectClass; res, size: LONGINT; msg: JT.StringBuffer;
	BEGIN
		co := c(JB.ObjectClass);
		c.stub := AosModules.ThisModule(c.obmod, res, msg);
		IF (c.stub # NIL) THEN
			cache := PCM.CacheImports IN PCM.parserOptions; INCL(PCM.parserOptions, PCM.CacheImports);
			StringPool.GetIndex(c.obmod, modname);
			PCT.Import(NIL, c.native, modname);
			IF ~cache THEN EXCL(PCM.parserOptions, PCM.CacheImports) END
		END;
		StringPool.GetIndex(c.obmod, stubname);
		ParseFields(in, co, FALSE);
		ParseMethods(in, co, hasNative, FALSE);
		ParseAttributes(in, co.attributes, c.constPool, FALSE);
		c.state := JB.Loaded;

		(* this is all what the loader really needs to do; the rest could be done before compiling *)
		AssignMethodNumbers(co); 			(* only for object classes *)
		c.native := NIL;	(* GC *)
		IF c.stub # NIL THEN
			JS.NewModule(co.ownModule, c.stub);		 
			IF co.typedesc = NIL THEN  JC.String(failureInfo, "JVM Error: Class not found in "); JC.String(failureInfo, c.obmod); JC.Ln(failureInfo); HALT(99) END
		ELSE
			IF hasNative THEN  JC.String(errorInfo, "Linker: no stub for "); JC.Str(errorInfo, c.name); JC.Ln(errorInfo)  END;
			JS.NewModule(co.ownModule, NIL);
			hasNative := FALSE;
			size := co.typeS.owner.size(PCBT.Size).size;
			IF c.superClass = NIL THEN
				JS.NewType(co.typedesc, NIL, size, co.dynamicPtrFields, 
									co.dynamicMethods, co.obobj, co.ownModule , TRUE)
			ELSE
				JS.NewType(co.typedesc, co.superClass.typedesc, size, co.dynamicPtrFields, 
									co.dynamicMethods, co.obobj, co.ownModule, TRUE)
			END;
			AllocateFields(co)							(* different for obejct and interface classes *)
		END;
		JT.MakeClassName(co.name, co.ownModule.name);
		FOR i := 0 TO LEN (co.fixsyscalls)-1 DO  co.fixsyscalls[i] := 0 END; (* does an interface need any system call ? *)
		ASSERT(co.typedesc#NIL);
		c.state := JB.Allocated
	END CompleteObjectClass;

	PROCEDURE CompleteInterfaceClass;
	VAR ci: JB.InterfaceClass;  res: LONGINT;  msg: JT.StringBuffer;  hasNative: BOOLEAN;
	BEGIN
		ci := c(JB.InterfaceClass);
		ci.stub := AosModules.ThisModule(ci.obmod, res, msg);
		ASSERT(ci.stub = NIL);	(*never checked or used*)
		ParseFields(in, ci, TRUE);
		ParseMethods(in, ci, hasNative, TRUE);
		ASSERT(~hasNative);
		(*ParseAttributes(c.attributes, c.constPool, FALSE);*)
		c.state := JB.Loaded;

		IF ci.stub # NIL THEN
			JS.GetClass(ci.stub, ci.obobj, ci.typedesc);
		ELSE
			JS.NewModule(ci.ownModule, NIL);
			(* interfaces consist only of a method record which is not subclassed;  *)
			JS.NewType(ci.typedesc, JI.td, 4*ci.typeS.procCount + 4, 1, 0, ci.obobj, NIL, FALSE);
			AllocateFields(ci)
		END; 
		JT.MakeClassName(ci.name, ci.ownModule.name);
		ASSERT(ci.typedesc # NIL);
		FOR i := 0 TO LEN (ci.fixsyscalls)-1 DO  ci.fixsyscalls[i] := 0 END; (* does an interface need any system call ? *)
		ci.state := JB.Allocated;
		INC(Ainterfaces);
		INC(AinterfaceMethods, ci.typeS.procCount);
		INC(AlocalInterfaceMethods, ci.typeS.procCount);
		IF ci.typeS.parent # NIL THEN
			DEC(AlocalInterfaceMethods, ci.typeS.parent.procCount)
		END;
	END CompleteInterfaceClass;

BEGIN
	ReadU4(in, magic);
	IF magic # 0CAFEBABEH THEN  ClassFormatError  END;
	ReadU2(in, minor); ReadU2(in, major);
	IF (major < 45) OR (major > 48) THEN  ClassFormatError  END;
	ReadConstPool(in, cp);
	(* with this change it is possible that there are different classes for primitive types, 
		array types, object types and interface types *)
	ReadFlags(in, access); ReadU2(in, this); ReadU2(in, super);
	isInterface := JB.AFInterface IN access;
	IF isInterface THEN
		 c := JB.CreateInterfaceClass(this, cp, access)
	ELSE
		c := JB.CreateObjectClass(this, cp, access)
	END;
	JT.MakeStubName(c.name, i, c.obmod, c.obobj);
	c.state := JB.Loading;
	CompletePool(c);
	superclass := PCT.NoType;
	IF super # 0 THEN
		INC(JB.AloadBase);
		superCls := JB.ThisClass(c.constPool[super](JB.CClassInfo).index.str, TRUE);
		c. superClass := superCls(JB.ObjectClass);
		c.extlev := c.superClass.extlev+1;
		superclass := superCls.type;
		IF isInterface THEN superclass := PCT.NoType END;
	END;
	(* it should be tested wether a superclass is present or not *)
	ParseInterfaces(in, c, intf);
	JT.JavaToOberonString(c.name, 0, LEN(c.name), name); StringPool.GetIndex(name, modname);
	JT.GetClassName(c.name, name); StringPool.GetIndex(name, classname);
	mod := PCT.Retrieve(JT.DB, modname);
	IF mod = NIL THEN
		JT.CreateClass(FALSE, modname, JT.class(*classname*), superclass, mod, type)
	END;
	IF mod # NIL THEN
		ASSERT(mod.scope.state = 0);
		c.module := mod;
		c.moduleS := mod.scope;
		mod.info := c;
		o := mod.scope.firstType; ASSERT(mod.scope.firstType.nextType = NIL);
		c.type := o.type(PCT.Pointer);
		c.type.owner.info := c;
		c.type.size := NIL;	(*force recomputation*)
		c.typeS := c.type.base(PCT.Record).scope;
		IF c.typeS.owner.size # NIL THEN
			JC.String(warningInfo, c.obmod); JC.String(warningInfo, "  already sized"); JC.Ln(warningInfo);
		END;
		c.typeS.owner.size := NIL;	(*force recomputation*)
		PCT.SetOwner(c.moduleS);
		PCT.SetOwner(c.typeS);
		PCT.InitRecord(c.typeS.owner, superclass, intf, c.typeS, JB.AFInterface IN c.flags, TRUE, TRUE, res);  ASSERT(res = PCT.Ok);
	END;
	(* until here it's alway the same procedure; now it diverges for interface classes and obejct classes *)
	IF isInterface THEN
		CompleteInterfaceClass
	ELSE
		CompleteObjectClass
	END;
(*
	in.close();
*)
	RETURN c
END LoadClassByStream;

PROCEDURE SetClass(m: PCT.Module);
	VAR c: JB.Class;	
BEGIN
	IF (m.info # NIL) THEN
		c := m.info(JB.Class);
		c.class := JB.javaLangClass
	END
END SetClass;

(**  LoadClassByName - Internalize a class file, register in the global class table *)

PROCEDURE LoadClassByName*(name: JT.String): JB.Class;
VAR fileName: ARRAY 256 OF CHAR; s: FIS.FileInputStream; c: JB.Class;

	PROCEDURE GetClassInputStream(VAR fname: ARRAY OF CHAR): FIS.FileInputStream;
	VAR f: AosFS.File; fis: FIS.FileInputStream; fd: FD.FileDescriptor;
	BEGIN
		fis := NIL;
		f := AosFS.Old(fname);
		IF f # NIL THEN
			NEW(fis);
			NEW(fis.fd);
			fis.fd.nativeFd := FD.Allocate(f, 0);
		ELSIF dontTrap THEN
			(*skip*)
		ELSIF fname = "java/lang/ClassNotFoundException.class" THEN
			HALT(99)
		ELSE
			JC.String(errorInfo, fname); JC.String(errorInfo, "  not found"); JC.Ln(errorInfo);
			jjlObject.Assert(FALSE, "java/lang/ClassNotFoundException", fname)
		END;
		RETURN fis
	END GetClassInputStream;

BEGIN
	IF TraceClasses IN Tracing THEN  JC.String(infoInfo, "Loader: TraceLoad "); JC.Str(infoInfo, name); JC.Ln(infoInfo)  END;
	INC(loading);
	JT.JavaToOberonString(name, 0, LEN(name), fileName);
	Append(fileName, ".class", LEN(name));
	s := GetClassInputStream(fileName);
	IF s # NIL THEN
		c := LoadClassByStream(s);
		FD.Release(SHORT(s.fd.nativeFd));
	ELSE
		JT.JavaToOberonString(name, 0, LEN(name), missingClass);
		JC.String(errorInfo, missingClass); JC.String(errorInfo, "  not found"); JC.Ln(errorInfo);
	END;
	DEC(loading);
	IF (c # NIL) & (fileName = "java/lang/Class.class") THEN
		JB.javaLangClass := c;
		PCT.Enumerate(JT.DB, SetClass);
	END;
	RETURN c
END LoadClassByName;

BEGIN
	classStr := StringPool.GetIndex1("Class");
	objStr := StringPool.GetIndex1("Object");
	initStr := StringPool.GetIndex1("<init>");
	loading := 0;
	ConstParser[JB.CUnicode] := CReadUnicode;
	ConstParser[JB.CInteger] := CReadInteger;
	ConstParser[JB.CFloat] := CReadFloat;
	ConstParser[JB.CLong] := CReadLong;
	ConstParser[JB.CDouble] := CReadDouble;
	ConstParser[JB.CClass] := CReadClass;
	ConstParser[JB.CString] := CReadString;
	ConstParser[JB.CFieldref] := CReadRef;
	ConstParser[JB.CMethodref] := CReadRef;
	ConstParser[JB.CInterfaceMethodref] := CReadRef;
	ConstParser[JB.CNameAndType] := CReadNameAndType;
	JB.loadClass := LoadClassByName;
	debugInfo.kind := JC.Debug; debugInfo.source := JC.Loader;
	warningInfo.kind := JC.Warning; debugInfo.source := JC.Loader;
	infoInfo.kind := JC.Info; infoInfo.source := JC.Loader;
	errorInfo.kind := JC.Error; errorInfo.source := JC.Loader;
	failureInfo.kind := JC.Failure; failureInfo.source := JC.Loader;
END JVMLoader.

(*
	11.01.04	prk	update to classpath 0.06
	30.07.03	prk	Logging functions, add kind and source; filtering support
	12.02.03	prk	Logging functions, use same interface as AosOut
	13.03.02	prk	set class field for instances of java/lang/Class
	23.11.01	prk	Class.getDeclaredFields, Class.getDeclaredMethods
	15.11.01	prk	use fields and vars from PCT instead of JB.Field
	09.11.01	prk	PushSelfTD removed
	23.10.01	prk	support for applets
	05.09.01	prk	deadlock fixed; was caused by allocating a class that used a field of a dummy class declared by another (previous) thread
	05.09.01	prk	make class loading and initializing more efficient
	27.08.01	prk	adapted to the changes in PCT
	22.08.01	prk	field.ptr removed
	21.08.01	prk	remove internal class-list, use PCT one instead
	20.08.01	prk	explicit support for zip archives removed, ZipFS used instead
	16.08.01	prk	take procedure information from PCT+PCBT
	03.08.01	prk	remove conversion from X.Y to X/Y
	02.08.01	prk	innerclasses attribute
	11.07.01	prk	(paco) support for fields and methods with same name in scope
	10.07.01	prk	switched to AosFS
	03.07.01	prk	access flags in PCT redesigned
	27.06.01	prk	StringPool cleaned up
	19.05.01	prk	use common symbol database
	22.05.01	prk	adapted to new AosActive interface
	21.05.01	prk	don't trap when a method/field is referenced, generate run-time exception
	09.05.01	prk	compiler: when call returns boolean, expand it to int
	25.04.01	prk	if no methods, use array of length 0 instead of NIL
	25.04.01	prk	if no fields, use array of length 0 instead of NIL
	04.04.01	prk	merge with classpath-0.00 release, prepare for update with 0.01, minimize differencies
	22.03.01	prk	JVMProprerties removed, archive list moved to Oberon.Text, loaded by JVMLoader
*)