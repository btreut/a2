MODULE JVMTypes;	(** PRK **)

(*
	Definition and implementation of the UNICODE and LONG types for Java .
	Signature parsing
*)

IMPORT
		SYSTEM,
		AosOut,
		StringPool, PCM, PCT, 
(*
		PCB,	(* PCB needed to avoid trap in PCV *)
*)
		BIT, JS := JVMSystem, JVMConverter, Reals;

CONST
	NULL* = 0;		(** value for NULL pointer *)
	Tracing = {};
	
	ScopeIsImported* = FALSE;
	
TYPE
		(** Java Base Types*)
	Byte* = SHORTINT;  Short* = INTEGER;  Int* = LONGINT;
	Long* = HUGEINT;
	
	Float* = REAL;  Double* = LONGREAL;
	
	Unicode* = INTEGER;
	
		(** String -  a java string has a length and is not zero terminated *)
	String* = POINTER TO ARRAY OF Unicode;
	
	StringBuffer* = ARRAY 256 OF CHAR;

VAR
	Uni: JVMConverter.Converter;
	DB*: PCT.ModuleDB;
	
	jlobject, object, class*, array: StringPool.Index;	(*cached values*)

	
PROCEDURE CompareUniString*(a: String; al: LONGINT; b: String; bl: LONGINT):LONGINT;
VAR i,  ret, len: LONGINT;
BEGIN i := 0;	 
	IF al < bl THEN len := al; ret := -1
	ELSIF al > bl THEN  len := bl; ret := 1
	ELSE len := al; ret := 0 END;
	WHILE  (i<len) & (a[i]=b[i]) DO INC(i) END;
	IF (i = len)  THEN RETURN ret	
	ELSIF a[i] > b[i] THEN  RETURN 1
	ELSE  RETURN -1
	END;
END CompareUniString;


(* --------------------------------------------------- *)
(* Unicode handling *)

PROCEDURE Utf8ToUnicode*(VAR utf8: ARRAY OF CHAR; len: LONGINT;  VAR uni: String);
	VAR 
		pos, j: LONGINT;
		tmp: ARRAY 16*1024 OF Unicode; (* why this is so big? *)

	PROCEDURE GetChar(VAR ch: Unicode);
		VAR ch0, ch1, ch2: LONGINT;
	BEGIN
		ch1 := 0H;
		ch0 := ORD(utf8[j]); INC(j);
		IF ch0 < 80H THEN ch := SHORT(ch0)
		ELSE (* Unicode character *)
			IF ch0 >= 0C0H  (*1100 0000*)  THEN
				IF ch0 < 0E0H THEN (* 2-BYTE, 110X XXXX *)
					ch0 := BIT.LAND(ch0, 1FH);
					ch1 := ORD(utf8[j]); INC(j); ch1 := BIT.LAND(ch1, 3FH);
					ch := SHORT(SYSTEM.LSH(ch0, 6) + ch1)
				ELSIF ch0 < 0F0H THEN (* 3-BYTE 1110 0000*)
					ch0 := BIT.LAND(ch0, 0FH);
					ch1 := ORD(utf8[j]); INC(j); ch1 := BIT.LAND(ch1, 3FH);
					ch2 := ORD(utf8[j]); INC(j); ch2 := BIT.LAND(ch2, 3FH);
					ch := SHORT(SYSTEM.LSH(ch0, 12) + SYSTEM.LSH(ch1, 6) + ch2)
				ELSE
					HALT(99)
				END;
			ELSE
				HALT(99)
			END
		END
	END GetChar;
BEGIN
	j := 0; pos:=0;
	WHILE j < len  DO GetChar(tmp[pos]); INC(pos) END;
	NEW(uni, pos);
	IF pos > 0 THEN  SYSTEM.MOVE(SYSTEM.ADR(tmp[0]), SYSTEM.ADR(uni[0]), 2*pos)  END
END Utf8ToUnicode;

PROCEDURE OberonToJavaString*(str: ARRAY OF CHAR; VAR uni: String);
VAR i, len: LONGINT;
	bytes: SHORTINT;
BEGIN
	i := 0; len := LEN(str)-1;
	WHILE (str[i] # 0X) & (i < len) DO  INC(i)  END;
	NEW(uni, i);
	WHILE i > 0 DO  DEC(i); uni[i] := SHORT(Uni.Encode(ORD(str[i]), bytes))  END;
END OberonToJavaString;

PROCEDURE JavaToOberonString*(uni: String; off, len: LONGINT; VAR str: ARRAY OF CHAR);
VAR  i, code: LONGINT; bytes: SHORTINT;
BEGIN
	i := 0;
	IF uni # NIL THEN
		IF len >= LEN(str) THEN
			len := LEN(str)-1;
			AosOut.String("Warning: JVMTypes.JavaToOberonString: string truncated"); AosOut.Ln
		END;
		WHILE (i < len) DO			
			code := Uni.Decode(uni[i+off] , bytes);			
			IF (code > 0) & (bytes = 1) THEN str[i] := CHR(code);
			ELSE str[i] := 0FFX END;
			INC(i)
		END
	END;
	str[i] := 0X
END JavaToOberonString;

PROCEDURE JavaToIndex*(uni: String; off, len: LONGINT; VAR idx: StringPool.Index);
	VAR str: ARRAY 256 OF CHAR;
BEGIN
	JavaToOberonString(uni, off, len, str);
	StringPool.GetIndex(str, idx)
END JavaToIndex;

(** Equal - Check strings for equality; string len can differ from LEN *)

PROCEDURE Equal*(a: String; al: LONGINT; b: String; bl: LONGINT): BOOLEAN;
VAR i:LONGINT;
BEGIN
	ASSERT(al <= LEN(a^));
	ASSERT(bl <= LEN(b^));
	IF al # bl THEN
		RETURN FALSE
	ELSE
		i := 0;
		WHILE (i < al) & (a[i] = b[i]) DO  INC(i)  END;
		RETURN (i = al)
	END
END Equal;

PROCEDURE Equal0*(a: String; al: LONGINT; b: ARRAY OF CHAR): BOOLEAN;
VAR i:LONGINT;
BEGIN
	ASSERT(al <= LEN(a^));
	IF al # LEN(b)-1 THEN  RETURN FALSE
	ELSE
		i := 0;
		WHILE (i < al)  & (a[i] = ORD(b[i])) DO  INC(i)  END;
		RETURN (i = al) & (b[i] = 0X)
	END
END Equal0;

(** Substring - create a new string of len (end-begin+1) with chars [begin, end] *)

PROCEDURE Substring*(a: String; first, last: LONGINT): String;
	VAR res: String; i: LONGINT;
BEGIN
	ASSERT(first < last);
	ASSERT(LEN(a) > last);
	NEW(res, last-first+1);
	FOR i := first TO last DO res[i-first] := a[i] END;
	RETURN res
END Substring;

PROCEDURE SplitName(jstr: String; VAR pos: LONGINT; VAR  package, class, short: ARRAY OF CHAR);
	VAR i, j, k, last, len: LONGINT; ch, lastCh: CHAR;
BEGIN
	i := 0; j := 0; k := 1;
	last := 0; len := LEN(jstr^);
	lastCh := "/";
	short[0] := "j";
	LOOP
		ch := CHR(jstr[pos]);
		IF ch = ";" THEN
			EXIT
		ELSIF ch = "/" THEN
			last := i;
			j := 0;
		ELSE
			IF (lastCh = "/") & (k < LEN(short)-1) THEN short[k] := ch; INC(k) END;
			IF j < LEN(class)-1 THEN class[j] := ch; INC(j) END
		END;
		lastCh := ch;
		IF i < LEN(package)-1 THEN package[i] := ch; INC(i) END;
		INC(pos);
		IF pos = len THEN EXIT END;
	END;
	package[last] := 0X;
	class[j] := 0X;
	short[k-1] := 0X;
END SplitName;

(** GetClassName - Get the name of the class (strip the package away) *)

PROCEDURE GetClassName*(jstr: String;  VAR name: ARRAY OF CHAR);
VAR  pos: LONGINT;  pck, short: StringBuffer;
BEGIN
	pos := 0;
	SplitName(jstr, pos, pck, name, short);
END GetClassName;

(** MakeClassName - convert the class full name to an oberon name *)

PROCEDURE MakeClassName*(jstr: String;  VAR name: ARRAY OF CHAR);
VAR  pos: LONGINT;  package, class: StringBuffer;
BEGIN
	pos := 0;
	SplitName(jstr, pos, package, class, name);  JVMConverter.Append(name, class);
	name[0] := "_";
END MakeClassName;

(** MakeStubName - convert the class full name to stub name *)
(** post: pos = LEN(jst) OR jst[pos] = ";" *)

PROCEDURE MakeStubName*(jstr: String; VAR pos: LONGINT; VAR mod, obj: ARRAY OF CHAR);
	VAR pack: ARRAY 128 OF CHAR;
BEGIN
	SplitName(jstr, pos, pack, obj, mod);  JVMConverter.Append(mod, obj);
	IF pack = "java/lang" THEN
		IF obj = "Object" THEN
			COPY("jjlObject", mod); COPY("Object", obj)
		ELSIF (obj = "String") THEN 
			COPY("jjlString", mod); COPY("String", obj)
		ELSIF (obj = "Throwable") THEN 
			COPY("jjlThrowable", mod); COPY("Throwable", obj)
		ELSIF (obj = "Class") THEN 
			COPY("JVMBase", mod); COPY("Class", obj)
		ELSIF (obj = "Thread") THEN
			COPY("JVMThreads", mod); COPY("Thread", obj)
		ELSIF (obj = "System") THEN 
			COPY("jjlSystem", mod); COPY("System", obj)
		ELSIF (obj = "VMSystem") THEN 
			COPY("jjlVMSystem", mod); COPY("VMSystem", obj)
		ELSIF (obj = "VMClassLoader") THEN 
			COPY("jjlVMClassLoader", mod); COPY("VMClassLoader", obj)
		ELSIF (obj = "Number") THEN 
			COPY("jjlNumber", mod); COPY("Number", obj)
		ELSIF (obj = "Float") THEN 
			COPY("jjlFloat", mod); COPY("Float", obj)
		ELSIF (obj = "Double") THEN 
			COPY("jjlDouble", mod); COPY("Double", obj)
		ELSIF (obj = "Math") THEN 
			COPY("jjlMath", mod); COPY("Math", obj)
		ELSIF (obj = "VMSecurityManager") THEN 
			COPY("jjlVMSecurityManager", mod); COPY("VMSecurityManager", obj)
		ELSIF(obj = "Runtime") THEN 
			COPY("JVM",mod); COPY("Runtime", obj)
		ELSE
			COPY("Class", obj)
		END
	ELSIF pack = "java/io" THEN
		IF obj = "FileDescriptor" THEN
			COPY("jjiFileDescriptor", mod); COPY("FileDescriptor", obj)
		ELSIF obj = "File" THEN
			COPY("jjiFile", mod); COPY("File", obj)
		ELSIF obj = "InputStream" THEN
			COPY("jjiInputStream", mod); COPY("InputStream", obj)
		ELSIF obj = "OutputStream" THEN
			COPY("jjiOutputStream", mod); COPY("OutputStream", obj)
		ELSIF obj = "FileInputStream" THEN
			COPY("jjiFileInputStream", mod); COPY("FileInputStream", obj)
		ELSIF obj = "FileOutputStream" THEN
			COPY("jjiFileOutputStream", mod); COPY("FileOutputStream", obj)
		ELSE
			COPY("Class", obj)
		END
	ELSIF pack =  "java/nio" THEN
	ELSIF pack = "java/nio/channels" THEN
		IF obj = "FileChannel" THEN
			COPY("jjNio", mod); COPY("FileChannel", obj)
		ELSIF obj = "FileChannelImpl" THEN
			COPY("jjNio", mod); COPY("FileChannelImpl", obj)
		END
	ELSIF pack = "java/nio/channels/spi" THEN
		IF obj = "AbstractInterruptibleChannel" THEN
			COPY("jjNio", mod); COPY("AbstractInterruptibleChan", obj);
		END
	ELSIF pack = "java/lang/reflect" THEN
		IF (obj = "Method") THEN
			COPY("JVMBase", mod); COPY("Method", obj)
		ELSIF (obj = "Field") THEN
			COPY("JVMBase", mod); COPY("Field", obj)
		ELSIF (obj = "Constructor") THEN
			COPY("JVMBase", mod); COPY("Constructor", obj)
		ELSIF (obj = "AccessibleObject") THEN
			COPY("JVMBase", mod); COPY("AccessibleObject", obj)
		ELSE
			COPY("Class", obj)
		END
	ELSE
		COPY("Class", obj)
	END
END MakeStubName;


(** convert a java name to an oberon identifier *)

PROCEDURE CheckKeyword(VAR oberon: ARRAY OF CHAR);
BEGIN
	IF oberon = "TYPE" THEN	(*avoid conflicts with oberon keywords*)
		COPY("Type", oberon)
	ELSIF oberon = "SET" THEN
		COPY("Set", oberon)
	ELSIF oberon = "EXCL" THEN
		COPY("Excl", oberon)
	ELSIF oberon = "END" THEN
		COPY("End", oberon)
	END;
END CheckKeyword;

PROCEDURE MakeIdent0*(java: ARRAY OF CHAR; VAR oberon: ARRAY OF CHAR);
	VAR i, j, len: LONGINT; ch: CHAR;
BEGIN
	i := 0; j := 0; len:= LEN(java);
	WHILE (i < len) & (java[i] # 0X) & (j < 27) DO ch := java[i];
		IF ("A" <= ch) & (ch <= "Z") OR ("a" <= ch) & (ch <= "z") OR ("0" <= ch) & (ch <= "9") THEN oberon[j] := ch; INC(j); END;
		INC(i)
	END;
	oberon[j] := 0X;
	CheckKeyword(oberon)
END MakeIdent0;

PROCEDURE MakeIdent*(jstr: String;  VAR name: ARRAY OF CHAR);
VAR i, j, len: LONGINT; ch: CHAR;
BEGIN
	i := 0; j := 0; len:= LEN(jstr^);
	WHILE (i < len) & (j < 27) DO ch := CHR(jstr[i]);  
		IF ("A" <= ch) & (ch <= "Z") OR ("a" <= ch) & (ch <= "z") OR ("0" <= ch) & (ch <= "9") THEN name[j] := ch; INC(j); END;
		INC(i)
	END; name[j] := 0X;
	CheckKeyword(name)
END MakeIdent;

(** makes a hashcode out of the descriptor of a method *)
PROCEDURE HashDescriptor*(descriptor: String; VAR hashcode :ARRAY OF CHAR);
VAR i, val: LONGINT;
BEGIN
		(* a hash value for the descriptor is computed; 
		it is very unlikely that there a two identical values, since the values should be distributed from 0 to ~ 10000*)
	WHILE i < LEN(descriptor^) DO val := val * 2; val := BIT.LXOR(val, descriptor[i]); val := val MOD 9029; INC(i) END;
	JVMConverter.IntToStr(val, hashcode);
END HashDescriptor;

(** MakeMethodName - Make Oberon name for a Method. If method ~unique, append an hash value to the name *)

PROCEDURE MakeMethodName*(procName, descriptor: String;  unique: BOOLEAN;  VAR name: ARRAY OF CHAR);
VAR buffer: ARRAY 8 OF CHAR;
BEGIN
	MakeIdent(procName, name);
	IF ~unique THEN HashDescriptor(descriptor, buffer); JVMConverter.Append(name, buffer); END;		
END MakeMethodName; 

(** a type bound ref-name has the form class.method()
      a static ref name only name()
*)      
PROCEDURE MakeRefName*(className, procName: ARRAY OF CHAR; static: BOOLEAN; VAR refName: ARRAY OF CHAR);
BEGIN
	IF 1 IN Tracing THEN
		AosOut.String(" MakeRefName() "); 
		AosOut.String(className); AosOut.String("."); AosOut.String(procName); AosOut.Ln
	END;
	IF static THEN COPY(procName, refName)
	ELSE
		COPY(className, refName); JVMConverter.Append(refName, "."); 
		JVMConverter.Append(refName, procName)
	END 
END MakeRefName;

(* --------------------------------------------------- *)
(* Java Types handling *)

PROCEDURE MakeArrayName*(VAR name: String;  dim: LONGINT; base: String);
	VAR i: LONGINT;
BEGIN
	ASSERT(dim > 0);
	IF LEN(base) = 1 THEN	(* built-in *)
		NEW(name, dim+1);
		name[dim] := base[0];
	ELSE
		NEW(name, LEN(base)+2+dim);
		name[dim] := ORD("L");
		name[dim+LEN(base)+1] := ORD(";");
		FOR i := 0 TO LEN(base)-1 DO name[dim+1+i] := base[i] END;
	END;	
	WHILE dim > 0 DO DEC(dim); name[dim] := ORD("[") END
END MakeArrayName;

PROCEDURE CommitClass*(mod: PCT.ModScope; rec: PCT.RecScope);
BEGIN
	PCT.ChangeState(rec, PCT.modeavailable, -2);
	PCT.ChangeState(mod, PCT.procdeclared, -2);
END CommitClass;

PROCEDURE CreateClass*(placeholder: BOOLEAN; package, class: StringPool.Index; base: PCT.Struct; VAR mod: PCT.Module; VAR type: PCT.Pointer);
	VAR scope: PCT.ModScope; t: PCT.Type; mscope: PCT.ModScope; rscope: PCT.RecScope; intf: ARRAY 1 OF PCT.Interface; res: LONGINT;
	name: ARRAY 64 OF CHAR;
BEGIN
	ASSERT(PCT.Retrieve(DB, package) = NIL);
	NEW(mscope);
	PCT.SetOwner(mscope);
	PCT.InitScope(mscope, NIL, {PCT.Overloading}, ScopeIsImported);
	mod := PCT.NewModule(package, TRUE, {}, mscope);
(*
	mscope.CreateVar(PCT.SelfName, PCT.internal, {PCM.untraced}, PCT.Ptr, res); ASSERT(res = PCT.Ok);
*)
	NEW(rscope);
(*
	PCT.SetOwner(rscope);
*)
	IF placeholder THEN
		PCT.InitScope(rscope, mscope, {PCT.CanSkipAllocation}, ScopeIsImported);
	ELSE
		PCT.SetOwner(rscope);
		PCT.InitScope(rscope, mscope, {PCT.CanSkipAllocation, PCT.SuperclassAvailable}, ScopeIsImported);
	END;
	type := PCT.NewClass(base, intf, rscope, TRUE, res); ASSERT(res = PCT.Ok);
	mscope.CreateType(class, PCT.Public, type, res); ASSERT(res = PCT.Ok);
	PCT.Register(DB, mod);
END CreateClass;

PROCEDURE FindClass(package, clazz: StringPool.Index): PCT.Struct;
	VAR m: PCT.Module; o: PCT.Symbol; t: PCT.Struct; ptr: PCT.Pointer;
BEGIN
	m := PCT.Retrieve(DB, package);
	IF (m = NIL) THEN
		CreateClass(TRUE, package, clazz, PCT.NoType, m, ptr);
		t := ptr
	ELSE
		o := PCT.Find(NIL, m.scope, clazz, 0, TRUE);
		IF (o = NIL) THEN
			CreateClass(TRUE, package, clazz, PCT.NoType, m, ptr);
			t := ptr
		ELSE
			t := o.type
		END
	END;
	RETURN t
END FindClass;

PROCEDURE CreateArrayClass*(name: StringPool.Index; base: PCT.Struct; VAR mod: PCT.Module; VAR type: PCT.Pointer);
	VAR a: PCT.Array; p: PCT.Pointer; super: PCT.Struct; res: LONGINT; rs: PCT.RecScope;
BEGIN
	mod := PCT.Retrieve(DB, name);
	IF mod = NIL THEN
		NEW(a); NEW(p);
		PCT.InitOpenArray(a, base, res); ASSERT(res = PCT.Ok);
		PCT.InitPointer(p, a, res); ASSERT(res = PCT.Ok);
		super := FindClass(jlobject, class(*object*));
		CreateClass(FALSE, name, class, super, mod, type);
(*
		CreateClass(TRUE, name, class, super, mod, type);
*)
		rs := type.base(PCT.Record).scope;
		rs.CreateVar(array, PCT.Public, {}, p, res); ASSERT(res = PCT.Ok);
		CommitClass(mod.scope, rs);
	ELSE
		type := mod.scope.firstType.type(PCT.Pointer);
		ASSERT(type.owner.name = class);
	END
END CreateArrayClass;

PROCEDURE JavaToInternalType(desc: String; VAR pos: LONGINT;  VAR type: PCT.Struct);
	VAR mod: PCT.Module; i, j, dim, idx0, idx1: LONGINT; tmp, name, typename: ARRAY 256 OF CHAR; t: PCT.Symbol; ch: CHAR; ptr: PCT.Pointer;
BEGIN
	CASE CHR(desc[pos]) OF
	| "B":  type := PCT.Int8
	| "C":  type := PCT.Char16	(*Unicode*)
	| "D":  type := PCT.Float64
	| "F":  type := PCT.Float32
	| "I":  type := PCT.Int32
	| "J":  type := PCT.Int64
	| "S":  type := PCT.Int16
	| "V":  type := PCT.NoType
	| "Z":  type := PCT.Bool
	| "[":
			dim := 0;
			WHILE desc[pos+dim] = ORD("[") DO
				name[dim] := "["; INC(dim)
			END;
			IF desc[pos+dim] = ORD("L") THEN
				j := dim;	(*skip L *)
				WHILE desc[pos+j] # ORD(";") DO
					name[j] := CHR(desc[pos+j]);
					INC(j)
				END;
				name[j] := ";"; INC(j);
				name[j] := 0X; INC(j);
			ELSE
				name[dim] := CHR(desc[pos+dim]);
				name[dim+1] := 0X;
				j := dim+1;
			END;
			StringPool.GetIndex(name, idx0);
			mod := PCT.Retrieve(DB, idx0);
			IF mod = NIL THEN
				INC(pos);
				JavaToInternalType(desc, pos, type);	(*get base type*)
				CreateArrayClass(idx0, type, mod, ptr);
				type := ptr;
			ELSE
				INC(pos, j);
				type := mod.scope.firstType.type;	(* there's only one symbol in this class *)
				ASSERT(type # NIL);
				ASSERT(mod.scope.firstType.nextType = NIL);
			END
	| "L":
			INC(pos);	(*skip L*)
			i := 0; j := 0;
			WHILE desc[pos] # ORD(";") DO
				ch := CHR(desc[pos]);
				name[i] := ch;
				typename[j] := ch;
				IF ch = "/" THEN j := -1 END;
				INC(i); INC(j); INC(pos)
			END;
			name[i] := 0X;
			typename[j] := 0X;
			StringPool.GetIndex(name, idx0);
(*
			IF name[0] = "[" THEN
				idx1 := class
			ELSE
				StringPool.GetIndex(typename, idx1)
			END;
*)
			idx1 := class;
			type := FindClass(idx0, idx1)
	ELSE
		type := PCT.UndefType
	END;
	INC(pos)
END JavaToInternalType;

PROCEDURE ParseType*(desc: String; VAR type: PCT.Struct);
	VAR i: LONGINT;
BEGIN
	i := 0;
	JavaToInternalType(desc, i, type);
END ParseType;

PROCEDURE AllocateField*(VAR offset, size, sectionSize: LONGINT);
	VAR align: LONGINT;
BEGIN
	align := size;
	IF align > 4 THEN align := 4 END;
	INC(sectionSize, (-sectionSize) MOD align);	(*align*)
	offset := sectionSize; INC(sectionSize, size);
	ASSERT(offset >= 0);
END AllocateField;

PROCEDURE AllocateVar*(VAR offset, size ,sectionSize: LONGINT);
	VAR align: LONGINT;
BEGIN
	align := size;
	IF align > 4 THEN align := 4 END;
	INC(sectionSize, (-sectionSize) MOD align);	(*align*)
	INC(sectionSize, size);
	offset := -sectionSize;
END AllocateVar;

PROCEDURE ParseSignature*(sign: String; VAR parsize: LONGINT; scope: PCT.ProcScope; VAR rettype: PCT.Struct);
VAR i, j, count, idx, res: LONGINT; ch: CHAR; t: PCT.Struct; name: ARRAY 32 OF CHAR;
BEGIN
	i := 0; parsize := 0;
	IF CHR(sign[i]) = "(" THEN
		INC(i);
		WHILE CHR(sign[i]) # ")" DO
			j := i;
			ch := CHR(sign[i]);
			IF (ch = "L") OR (ch = "[") THEN
				INC(parsize, 4);
				WHILE CHR(sign[i]) = "[" DO  INC(i)  END;
				IF CHR(sign[i]) = "L" THEN
					WHILE CHR(sign[i]) # ";" DO INC(i) END;
					INC(i)
				ELSE
					INC(i)
				END
			ELSIF (ch = "D") OR (ch = "J") THEN
				INC(parsize, 8); INC(i)
			ELSE
				INC(parsize, 4); INC(i)
			END;
			JavaToInternalType(sign, j, t);
			name[0] := "p"; name[1] := CHR(ORD("0") + count); name[2] := 0X; INC(count);
			StringPool.GetIndex(name, idx);
			scope.CreatePar(PCT.Public, FALSE, idx, {}, t, res); ASSERT(res = PCT.Ok);
		END;
		INC(i)
	END;
	JavaToInternalType(sign, i, rettype)
END ParseSignature;

PROCEDURE BooleanToByteArray*(val: BOOLEAN; VAR buffer :ARRAY OF Byte; VAR len :LONGINT);
VAR str: ARRAY 32 OF CHAR; i: LONGINT;
BEGIN
	IF val THEN str := "true"; len := 4;
	ELSE str := "false"; len := 5 END;
	FOR i := 0 TO len-1 DO buffer[i] := SHORT(ORD(str[i])) END
END BooleanToByteArray;

(** Conversion from HUGEINT to byte array *)
PROCEDURE IntToByteArray*(val: HUGEINT; VAR buffer :ARRAY OF Byte; VAR len :LONGINT);
VAR neg: BOOLEAN; pos: LONGINT;
	tmp: ARRAY 256 OF CHAR;
	low, high, rem: LONGINT;		
	ten: HUGEINT;
BEGIN
	ten := 10; pos := LEN(tmp)-1;
	JS.GetLowHigh(val, low, high);
	IF (high = 80000000H) & (low = 0) THEN
		COPY("-9223372036854775808", tmp);
		len := 20;
		SYSTEM.MOVE(SYSTEM.ADR(tmp[0]) , SYSTEM.ADR(buffer[0]), len)
	ELSIF (high = 0) & (low = 0) THEN
		buffer[0] := SHORT(ORD("0"));
		len := 1
	ELSE
		neg := (high < 0);
		IF neg THEN val := -val; JS.GetLowHigh(val, low, high) END;	
		WHILE (high#0) OR (low # 0) DO
			rem := SHORT(JS.Mod( val, ten));
			tmp[pos] := CHR(ORD("0")+ rem); DEC(pos);
			val := JS.Div(val, ten);
			JS.GetLowHigh(val, low, high);
		END;
		IF neg THEN tmp[ pos ] :=  "-" ELSE INC(pos) END; 
		len := LEN(tmp)-pos;
		ASSERT(len > 0);
		SYSTEM.MOVE(SYSTEM.ADR(tmp[pos]) , SYSTEM.ADR(buffer[0]), len)
	END;
END IntToByteArray;

BEGIN
	PCT.InitDB(DB);
	jlobject := StringPool.GetIndex1("java/lang/Object");
	object := StringPool.GetIndex1("Object");
	array := StringPool.GetIndex1("array");
	class := StringPool.GetIndex1("Class");
	Uni := JVMConverter.Find(JVMConverter.ISOOberonStr);		
END JVMTypes.

(*
	11.01.04	prk	update to classpath 0.06
	19.03.02	prk	Delay allocation of record scopes (PCT.CanSkipAllocation flag)
	06.09.01	prk	crash in CreateArrayClass fixed. Mauve TestClass works
	05.09.01	prk	deadlock fixed; was caused by allocating a class that used a field of a dummy class declared by another (previous) thread
	27.08.01	prk	adapted to the changes in PCT
	22.08.01	prk	field.ptr removed
	21.08.01	prk	remove internal class-list, use PCT one instead
	20.08.01	prk	mapping java arrays to oberon
	16.08.01	prk	take procedure information from PCT+PCBT
	11.07.01	prk	(paco) support for fields and methods with same name in scope
	03.07.01	prk	access flags in PCT redesigned
	27.06.01	prk	StringPool cleaned up
	27.06.01	prk	use ProcScope.CreatePar
	19.05.01	prk	use common symbol database
	29.05.01	prk	static fields: allocation corrected, make oberon compatible identifiers
	27.05.01	prk	merge Thread.java with classpath 0.02
	18.05.01	prk	Emit warning when java class name gets truncated because too long
	09.05.01	prk	compiler: when call returns boolean, expand it to int
	24.04.01	prk	JVMTypes interface cleanup
	17.04.01	prk	JVMTypes cleanup
	06.04.01	prk	JVMTypes.MakeProcName removed
	04.04.01	prk	merge with classpath-0.00 release, prepare for update with 0.01, minimize differencies
	22.03.01	prk	JVMTypes.CLS* contants removed
*)