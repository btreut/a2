(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMBase;	(** PRK, rl **)

IMPORT
		AosOut,
		SYSTEM, AosProcessors,
		StringPool, PCT, PCBT,
		jjlObject,  jjlString, JE := JVMExceptions, JC := JVMConsole,
		JT := JVMTypes, JS := JVMSystem, JI := JVMInterfaces;

(*
	References:
	[1]	The Java Virtual Machine Specification, Ed. 1
	
	Contains stubs for
	java/lang/Class
	java/lang/reflect/Field
	java/lang/reflect/Method
*)

CONST
	TraceForName = TRUE;


	tablesize* = 1021;

	(*Index into primitiveClass array cache*)
	VoidIdx = 0; ByteIdx = 1; CharIdx = 2; DoubleIdx = 3; FloatIdx = 4; IntIdx = 5; LongIdx = 6; ShortIdx = 7; BoolIdx = 8;

		(**ConstPool tags*)
	CUnicode*=1;  CInteger*=3;  CFloat*=4;  CLong*=5;  CDouble*=6;  CClass*=7;  CString*=8;
	CFieldref*=9;  CMethodref*=10;  CInterfaceMethodref*=11;  CNameAndType*=12;

		(**Access Flags*)
	AFPublic*=0;  AFPrivate*=1;  AFProtected*=2;  AFStatic*=3;  AFFinal*=4;
	AFSynchronized*=5;  AFSuper*=5; AFVolatile*=6;  AFTransient*=7;  AFNative*=8;
	AFInterface*=9;  AFAbstract*=10;

	AFOverridden* = 30;	(* method overridden by oberon implementation *)
	ToBeCompiled*=31;

		(**Attribute tags*)
	AConstValue* = 0;  ACode* = 1;  ASourceFile* = 2;  AExceptions* = 3;
	ALineNumberTable* = 4;  ALocalVariableTable* = 5;

		(** System Calls Numbers *)
	SCNew* = 0; SCNewArray* = 1; SCNewArrayA* = 2;
	SCThrow* = 3;
	SCCheckCast* = 4; SCInstanceOf* = 5;
	SCLock* =  6; SCUnlock* = 7; SCCheckInitialized* = 8; SCMultianewArray* = 9; SCILookup*=10;
	SCTrace* = 11;

	NOfSysCalls = 12;

		(**Class States*)
	Loading* = 1;  Loaded* = 2;  Allocated* = 3;   Compiled* = 4; Linked* = 5;  Initialized* = 6;

CONST
	serialVersionUID* = 3206093459760846163;

VAR
	debugInfo, warningInfo, infoInfo, errorInfo, failureInfo: JC.LoggingInfo;

TYPE
	(** Map - Conversion table *)
	Map* = POINTER TO ARRAY OF LONGINT;

	OString* = ARRAY 32 OF CHAR;
	
	(* aliases *)
	Object = jjlObject.Object;
	RefArray = jjlObject.RefArray;
	

	String = JT.String;
	JString = jjlString.String;

	Long* = RECORD  l*, h*: LONGINT  END;


		(**ConstPool*)
	CInfo* = POINTER TO CInfoDesc;
	CInfoDesc* = RECORD
		tag*: LONGINT;
	END;

	CUnicodeInfo*=POINTER TO CUnicodeInfoDesc;
	CUnicodeInfoDesc*=RECORD (CInfoDesc)
		str*: JT.String;	(* direct *)
		index*: LONGINT;	(*index into stringpool*)
	END;

	CClassInfo*=POINTER TO CClassInfoDesc;
	CClassInfoDesc*=RECORD (CInfoDesc)
		index*: CUnicodeInfo;	(* direct , class name as unicode string *)
		class*: Class;	(* set only if the class the current class is compiled and the ref class is used for a field or method *)
	END;

	CNameAndTypeInfo*=POINTER TO CNameAndTypeInfoDesc;
	CNameAndTypeInfoDesc*=RECORD (CInfoDesc)
		name*, type*: CUnicodeInfo;	(* direct *)
	END;

	CRefInfo* = POINTER TO CRefInfoDesc;	(* <- Fieldref / Methodref / IntMethref *)
	CRefInfoDesc* = RECORD (CInfoDesc)
		ownclass*: Class;	(* direct *)
		cindex*: CClassInfo;
		ntindex*: CNameAndTypeInfo;	(* direct *)
		obj*: PCT.Symbol;	(** variable/const/method *)
		effectiveClass*: Class;	(** FieldRef: class containing definition, may differ from cindex *)
		ref*: AccessibleObject;	(**method / field index*)
		fixup*: LONGINT;	(**fixup chain in code*)
		next*: CRefInfo;	(**linked list of refs to be fixed, anchored at class.fixups*) 

		(*size*: LONGINT; ptr*: BOOLEAN;	*)(**for fields only*)

	END;

	CConstInfo* = POINTER TO CConstInfoDesc;
	CConstInfoDesc* = RECORD (CInfoDesc)
		c*: PCT.Const
	END;

	CStringInfo*=POINTER TO CStringInfoDesc;
	CStringInfoDesc*=RECORD (CConstInfoDesc)	(*make extension, to avoid allocating twice*)
		index*: CUnicodeInfo;	(* direct *)
	END;
	
		(** Attributes *)
	AInfo* = POINTER TO AInfoDesc;
	AInfoDesc* = RECORD
		name*: String;
		next*: AInfo;		(*replaces AInfoList*)
	END;

	AConstValueInfo* = POINTER TO AConstValueInfoDesc;
	AConstValueInfoDesc* = RECORD (AInfoDesc)
		const*: CInfo;
	END;

	ASourceFileInfo* = POINTER TO ASourceFileInfoDesc;
	ASourceFileInfoDesc* = RECORD (AInfoDesc)
		sourcefile*: String;
	END;

	AExceptionsInfo* = POINTER TO AExceptionsInfoDesc;
	AExceptionsInfoDesc* = RECORD (AInfoDesc)
		table*: POINTER TO ARRAY OF CClassInfo
	END;

	ALineDesc* = RECORD start*, line*: LONGINT END;

	ALineNumberInfo* = POINTER TO ALineNumberInfoDesc;
	ALineNumberInfoDesc* = RECORD (AInfoDesc)
		table*: POINTER TO ARRAY OF ALineDesc
	END;

	ALocalVariableDesc* = RECORD
		start*, length*: LONGINT;
		name*, descriptor*: String;
		index*: LONGINT
	END;

	ALocalVariableInfo* = POINTER TO ALocalVariableInfoDesc;
	ALocalVariableInfoDesc* = RECORD (AInfoDesc)
		table*: POINTER TO ARRAY OF ALocalVariableDesc
	END;

	ACodeInfo* = POINTER TO ACodeInfoDesc;
	ACodeInfoDesc* = RECORD (AInfoDesc)
		maxStack*, maxLocals*: LONGINT;
		code*: POINTER TO ARRAY OF CHAR;
		exceptions*: JE.CatchTable;
		attributes*: AInfo;
		pos*, len*: LONGINT;
	END;
	
	AInnerDesc* = RECORD
		innerClass*, outerClass*, name*: LONGINT;
		flags*: SET;
	END;

	
	AInnerInfo* = POINTER TO AInnerInfoDesc;
	AInnerInfoDesc* = RECORD (AInfoDesc)
		table*: POINTER TO ARRAY OF AInnerDesc
	END;

	AccessibleObject* = OBJECT (Object)
	(*automatically generated stub for java/lang/reflect/AccessibleObject *)
		VAR
			flag-: BOOLEAN;

		PROCEDURE init();   (* <init>()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init;

		PROCEDURE finit();   (* finit$()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END finit;

		PROCEDURE isAccessible*(): BOOLEAN;   (* isAccessible()Z *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END isAccessible;

		PROCEDURE secureSetAccessible(p0: BOOLEAN);   (* secureSetAccessible(Z)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END secureSetAccessible;

		PROCEDURE setAccessible*(p0: BOOLEAN);   (* setAccessible(Z)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END setAccessible;

		PROCEDURE this();   (* this()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END this;

	END AccessibleObject;
	
	Field* = OBJECT(AccessibleObject)
		VAR
			(*fields defined in java/lang/reflect/Field*)
			declaringClass*: RefClass;
			name*: JString;
			slot-: LONGINT;	(* not used by Jaos *)

			type: Class;	(* on demand, cached: StructToClass(f.type) *)

			flags*:SET;
			offset*:LONGINT;	(* cached: f.adr(PCBT.Variable).offset *)
			size*: LONGINT;	(* cached: f.type.size(PCBT.Size).size *)

			f*: PCT.Symbol;	(** field information from PCT *)

		PROCEDURE init6498(p0: Class; p1: String; p2: JT.Int);   (* <init>(Ljava/lang/Class;Ljava/lang/String;I)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init6498;

		PROCEDURE equals*(p0: Object): BOOLEAN;   (* equals(Ljava/lang/Object;)Z *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END equals;

		(* Address - Address of the field value for obj; obj = NIL for static fields (they are unique) *)

		PROCEDURE Address(obj: Object): LONGINT;
		VAR adr: LONGINT;
		BEGIN
			IF AFStatic IN flags THEN
				adr := declaringClass.ownModule.sb
			ELSIF obj = NIL THEN
				Throw(ThisClass0("java/lang/NullPointerException", TRUE));
			ELSE
				adr := SYSTEM.VAL(LONGINT, obj)
			END;
			RETURN adr + offset
		END Address;

		PROCEDURE getDeclaringClass*(): Class;   (* getDeclaringClass()Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)	(*don't use before field is loaded, get class directly*)
		END getDeclaringClass;

		PROCEDURE getName*(): JString;   (* getName()Ljava/lang/String; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getName;

		PROCEDURE getModifiers*(): JT.Int;   (* getModifiers()I *)
		BEGIN
			RETURN SYSTEM.VAL(LONGINT, flags);
		END getModifiers;

		PROCEDURE get*(obj: Object): Object;   (* get(Ljava/lang/Object;)Ljava/lang/Object; *)
		VAR type: Class;  dest: Object;  wrapper: ObjectClass;  f: Field;  adr1: LONGINT;
		BEGIN
			type := getType();
			IF type.isPrimitive() THEN
				wrapper := GetWrapper0(SELF.f.type);
				dest := wrapper.newInstance();
				f := GetField(wrapper, valueIdx);
				ASSERT((f#NIL) & (f.f.type = SELF.f.type));
				SYSTEM.MOVE(Address(obj), f.Address(dest), size)
			ELSE
				SYSTEM.GET(Address(obj), dest)
			END;
			RETURN dest;
		END get;

		PROCEDURE getBoolean*(obj: Object): BOOLEAN;   (* getBoolean(Ljava/lang/Object;)Z *)
		VAR bool: BOOLEAN;
		BEGIN
			ASSERT(f.type = PCT.Bool);
			SYSTEM.GET(Address(obj), bool);
			RETURN bool
		END getBoolean;

		PROCEDURE getByte*(obj: Object): JT.Byte;   (* getByte(Ljava/lang/Object;)B *)
		VAR byte: JT.Byte;
		BEGIN
			ASSERT(f.type = PCT.Int8);
			SYSTEM.GET(Address(obj), byte);
			RETURN byte
		END getByte;

		PROCEDURE getChar*(obj: Object): JT.Unicode;   (* getChar(Ljava/lang/Object;)C *)
		VAR char: JT.Unicode;
		BEGIN
			ASSERT(f.type = PCT.Char16);
			SYSTEM.GET(Address(obj), char);
			RETURN char
		END getChar;

		PROCEDURE getDouble*(obj: Object): JT.Double;   (* getDouble(Ljava/lang/Object;)D *)
		VAR double: JT.Double;
		BEGIN
			ASSERT(f.type = PCT.Float64);
			SYSTEM.GET(Address(obj), double);
			RETURN double
		END getDouble;

		PROCEDURE getFloat*(obj: Object): JT.Float;   (* getFloat(Ljava/lang/Object;)F *)
		VAR val: JT.Float;
		BEGIN
			ASSERT(f.type = PCT.Float32);
			SYSTEM.GET(Address(obj), val);
			RETURN val
		END getFloat;

		PROCEDURE getInt*(obj: Object): JT.Int;   (* getInt(Ljava/lang/Object;)I *)
		VAR val: JT.Int;
		BEGIN
			ASSERT(f.type = PCT.Int32);
			SYSTEM.GET(Address(obj), val);
			RETURN val
		END getInt;

		PROCEDURE getLong*(obj: Object): JT.Long;   (* getLong(Ljava/lang/Object;)J *)
		VAR val: JT.Long;
		BEGIN
			ASSERT(f.type = PCT.Int64);
			SYSTEM.MOVE(Address(obj), SYSTEM.ADR(val), size);
			RETURN val
		END getLong;

		PROCEDURE getShort*(obj: Object): JT.Short;   (* getShort(Ljava/lang/Object;)S *)
		VAR val: JT.Short;
		BEGIN
			ASSERT(f.type = PCT.Int16);
			SYSTEM.GET(Address(obj), val);
			RETURN val
		END getShort;

		PROCEDURE getType*(): Class;   (* getType()Ljava/lang/Class; *)
		BEGIN 
			IF type = NIL THEN  type := StructToClass(f.type)  END;
			RETURN type
		END getType;

		PROCEDURE hashCode*(): JT.Int;   (* hashCode()I *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END hashCode;

		PROCEDURE set*(obj: Object; val: Object);   (* set(Ljava/lang/Object;Ljava/lang/Object;)V *)
		VAR type: Class; f: Field; o: Object; cls: Class; adr1: LONGINT;
		BEGIN
			type := getType();
			IF type.isPrimitive() THEN
				o := val.getClass(); cls := o(Class);
				f := GetField(cls, valueIdx);
				ASSERT((f # NIL) & (f.f.type = SELF.f.type));
				SYSTEM.MOVE(f.Address(val), Address(obj), size)
			ELSE
				SYSTEM.PUT(Address(obj), val)
			END 
		END set;

		PROCEDURE setBoolean*(obj: Object; p1: BOOLEAN);   (* setBoolean(Ljava/lang/Object;Z)V *)
		BEGIN
			ASSERT(f.type = PCT.Bool);
			SYSTEM.PUT(Address(obj), p1);
		END setBoolean;

		PROCEDURE setByte*(obj: Object; p1: JT.Byte);   (* setByte(Ljava/lang/Object;B)V *)
		BEGIN
			ASSERT(f.type = PCT.Int8);
			SYSTEM.PUT(Address(obj), p1);
		END setByte;

		PROCEDURE setChar*(obj: Object; p1: JT.Unicode);   (* setChar(Ljava/lang/Object;C)V *)
		BEGIN
			ASSERT(f.type = PCT.Char16);
			SYSTEM.PUT(Address(obj), p1);
		END setChar;

		PROCEDURE setDouble*(obj: Object; p1: JT.Double);   (* setDouble(Ljava/lang/Object;D)V *)
		BEGIN
			ASSERT(f.type = PCT.Float64);
			SYSTEM.PUT(Address(obj), p1);
		END setDouble;

		PROCEDURE setFloat*(obj: Object; p1: JT.Float);   (* setFloat(Ljava/lang/Object;F)V *)
		BEGIN
			ASSERT(f.type = PCT.Float32);
			SYSTEM.PUT(Address(obj), p1);
		END setFloat;

		PROCEDURE setInt*(obj: Object; p1: JT.Int);   (* setInt(Ljava/lang/Object;I)V *)
		BEGIN
			ASSERT(f.type = PCT.Int32);
			SYSTEM.PUT(Address(obj), p1);
		END setInt;

		PROCEDURE setLong*(obj: Object; p1: JT.Long);   (* setLong(Ljava/lang/Object;J)V *)
		BEGIN
			ASSERT(f.type = PCT.Int64);
			SYSTEM.MOVE(SYSTEM.ADR(p1), Address(obj), size);
		END setLong;

		PROCEDURE setShort*(obj: Object; p1: JT.Short);   (* setShort(Ljava/lang/Object;S)V *)
		BEGIN
			ASSERT(f.type = PCT.Int16);
			SYSTEM.PUT(Address(obj), p1);
		END setShort;

		PROCEDURE toString*(): Object;   (* toString()Ljava/lang/String; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END toString;

	END Field;

	Method* = OBJECT(AccessibleObject)
		VAR
			(*fields defined in java/lang/reflect/Method*)
			declaringClass*: RefClass;
			name*: JString;
			slot-: LONGINT;

			(*cached values*)
			returnType: Class;
			parameterTypes, exceptionTypes: jjlObject.RefArray;

			flags*:SET;
			descriptor*:String;
			offset*:LONGINT;
			attributes*: AInfo; 
			code*: ACodeInfo;	(**cached field*)
			mno*, parsize*: LONGINT;	(**meth number (in vtable); only for dynamic methods*)
			try*: LONGINT;  (** number of methods with same name but different signature BEFORE this one *)
			stubadr*: LONGINT;
			p*: PCT.Proc;	(*link to Paco structures*)

		PROCEDURE init6498(p0: Class; p1: String; p2: JT.Int);   (* <init>(Ljava/lang/Class;Ljava/lang/String;I)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init6498;

		PROCEDURE equals*(p0: Object): BOOLEAN;   (* equals(Ljava/lang/Object;)Z *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END equals;

		PROCEDURE getDeclaringClass*(): Class;   (* getDeclaringClass()Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaringClass;

		PROCEDURE getName*(): JString;   (* getName()Ljava/lang/String; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getName;

		PROCEDURE getModifiers*(): JT.Int;   (* getModifiers()I *)
		BEGIN
			RETURN SYSTEM.VAL(LONGINT, flags);
		END getModifiers;

		PROCEDURE getExceptionTypes*(): jjlObject.RefArray;   (* getExceptionTypes()[Ljava/lang/Class; *)
		VAR p: AInfo;
			ei: AExceptionsInfo;
			i, len: LONGINT;
		BEGIN
			IF exceptionTypes = NIL THEN
				p := attributes; NEW(exceptionTypes);
				WHILE (p # NIL) & ~(p IS AExceptionsInfo) DO p := p.next END;
				IF p # NIL THEN ei := p(AExceptionsInfo); len := LEN(ei.table); NEW(exceptionTypes.p, len);
					FOR i := 0 TO len - 1 DO 
						IF ei.table[i].class = NIL THEN ei.table[i].class := ThisClass(ei.table[i].index.str, TRUE) END;
						exceptionTypes.p[i] := ei.table[i].class
					END;
				ELSE NEW(exceptionTypes.p, 0)
				END
			END;
			RETURN exceptionTypes;
		END getExceptionTypes;

		PROCEDURE getParameterTypes*(): jjlObject.RefArray;   (* getParameterTypes()[Ljava/lang/Class; *)
		VAR p: ARRAY 256 OF Class;  i,j: LONGINT;
		BEGIN 
			IF parameterTypes = NIL THEN
				i := 0; j := 0;
				WHILE (i < LEN(descriptor)) & (CHR(descriptor[i]) #"(") DO INC(i) END;
				INC(i);
				WHILE CHR(descriptor[i])#")" DO
					p[j] := parseDescriptor(descriptor, i); INC(j);
					IF CHR(descriptor[i]) = ";" THEN INC(i) END
				END;
				NEW(parameterTypes); NEW(parameterTypes.p, j);
				FOR i := 0 TO j-1 DO  parameterTypes.p[i] := p[i]  END;
			END;
			RETURN parameterTypes
		END getParameterTypes;

		PROCEDURE getReturnType*(): Class;   (* getReturnType()Ljava/lang/Class; *)
		VAR i: LONGINT;
		BEGIN
			IF returnType = NIL THEN
				i := 0;
				WHILE (i < LEN(descriptor)) & (CHR(descriptor[i])#")") DO INC(i) END; (*find start of return descriptor *)
				INC(i);
				returnType := parseDescriptor(descriptor, i)
			END;
			RETURN returnType
		END getReturnType;

		PROCEDURE invoke*(obj: Object; args: jjlObject.RefArray): Object;   (* invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END invoke;

		PROCEDURE invokeNative*(obj: Object; args: jjlObject.RefArray; class: Class; slot: LONGINT): Object;   (* invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object; *)
		VAR  types: jjlObject.RefArray;
			adr, tos, td, i,j, len, edx, eax: LONGINT; 	(* dont change the order of edx/eax *)
			stack: ARRAY 256 OF LONGINT;
			f: Field; ret: Class; wrapper: ObjectClass;
			par, result: Object;
			index: INTEGER;
			retIsFP: BOOLEAN;
		BEGIN
(*
			ASSERT((args#NIL)&(args.p#NIL));
*)
			types := getParameterTypes();
(*
			len := LEN(args.p^);
*)
			len := LEN(types.p^);
			tos := 0; i := 0; j := 0;
			WHILE i < len DO																				(* prepare parameter for mehtod invokation *)
				par := args.p[i];
				IF types.p[i](Class).isPrimitive() THEN	(* primitive type, push value *)
					index := types.p[i](PrimitiveClass).short;
					wrapper := GetWrapper(index);
					adr := SYSTEM.VAL(LONGINT, par) + GetFieldOffset(wrapper, valueIdx);
					IF (index = ORD("J")) OR (index = ORD("D")) THEN	(* 8-byte primitive *)
						SYSTEM.GET(adr+0, stack[tos+1]);	(* stack has reversed order *)
						SYSTEM.GET(adr+4, stack[tos+0]);
						INC(tos, 2)
					ELSIF index = ORD("B") THEN
						stack[tos] := SYSTEM.GET8(adr);
						INC(tos)
					ELSIF index = ORD("S") THEN
						stack[tos] := SYSTEM.GET16(adr);
						INC(tos)
					ELSE
						stack[tos] := SYSTEM.GET32(adr);
						INC(tos)
					END
				ELSE
					stack[tos] := SYSTEM.VAL(LONGINT, par); INC(tos)
				END;
				INC(i)
			END;
			IF obj # NIL THEN																						  	(* not static *)
				stack[tos] := SYSTEM.VAL(LONGINT, obj);	(* self *)
				INC(tos)
			END;
			(* now push stackcontents and invoke the method *)
			retIsFP := (p.type = PCT.Float32) OR (p.type = PCT.Float64);
			JS.InvokeMethod(offset, SYSTEM.ADR(stack[0]), tos, retIsFP, eax, edx);
			ret := getReturnType();
			IF ret.isPrimitive() THEN																	(* collect return values *)
				index := ret(PrimitiveClass).short;
				IF index # ORD("V") THEN									  (* for void nothing must be done *)
					wrapper := GetWrapper(index);
					result := wrapper.newInstance();
					adr := SYSTEM.VAL(LONGINT, result) + GetFieldOffset(wrapper, valueIdx);
					CASE index OF
						| ORD("B"):	SYSTEM.PUT(adr, SYSTEM.VAL(JT.Byte, eax))
						| ORD("Z"):	SYSTEM.PUT(adr, SYSTEM.VAL(BOOLEAN, eax))
						| ORD("C"):	SYSTEM.PUT(adr, SYSTEM.VAL(JT.Unicode, eax))
						| ORD("S"):	SYSTEM.PUT(adr, SYSTEM.VAL(JT.Short, eax))
						| ORD("I"): 	SYSTEM.PUT(adr, eax)
						| ORD("J"):	 SYSTEM.PUT(adr, SYSTEM.VAL(HUGEINT, eax))	(* edx must follow eax in the local var space !!! *)
						| ORD("F"):	SYSTEM.PUT(adr, SYSTEM.VAL(JT.Float, eax))
						|ORD("D"):	SYSTEM.PUT(adr, SYSTEM.VAL(JT.Double, eax))
					END
				END
			ELSE
				result := SYSTEM.VAL(Object, eax)
			END;
			RETURN result
		END invokeNative;

		PROCEDURE toString*(): Object;   (* toString()Ljava/lang/String; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END toString;

		PROCEDURE hashCode*(): JT.Int;   (* hashCode()I *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END hashCode;

	END Method;

	
	Constructor* = OBJECT (AccessibleObject)
		VAR
			(* fields defined in classpath *)
			clazz-: Class;
			slot-: LONGINT;	(* contains p: PCT.Proc *)
			parameterTypes-: jjlObject.RefArray;	(* array of classes *)
			exceptionTypes-: jjlObject.RefArray;	(* array of classes *)

		PROCEDURE init164();   (* <init>()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init164;

		PROCEDURE init5379(p0: Class; p1: JT.Int);   (* <init>(Ljava/lang/Class;I)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init5379;

		PROCEDURE constructNative(args: jjlObject.RefArray; p1: Class; p2: JT.Int): Object;   (* constructNative([Ljava/lang/Object;Ljava/lang/Class;I)Ljava/lang/Object; *)
			VAR o, res: Object; p: PCT.Proc; m: Method;
		BEGIN	(* put your implementation here *)
			ASSERT(p1 = clazz, 500);
			ASSERT(p2 = slot, 501);
			o := NewInstance(p1(ObjectClass));
			p := SYSTEM.VAL(PCT.Proc, p2);
			m := p.info(Method);
			res := m.invokeNative(o, args, clazz, 0);
			RETURN o
		END constructNative;

		PROCEDURE equals*(p0: Object): BOOLEAN;   (* equals(Ljava/lang/Object;)Z *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END equals;

		PROCEDURE getDeclaringClass*(): Class;   (* getDeclaringClass()Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaringClass;

		PROCEDURE getExceptionTypes*(): jjlObject.RefArray;   (* getExceptionTypes()[Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
			HALT(99); 	(* not supported *)
		END getExceptionTypes;

		PROCEDURE getModifiers*(): JT.Int;   (* getModifiers()I *)
		BEGIN	(* put your implementation here *)
			HALT(99)
		END getModifiers;

		PROCEDURE getName*(): String;   (* getName()Ljava/lang/String; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getName;

		PROCEDURE getParameterTypes*(): jjlObject.RefArray;   (* getParameterTypes()[Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getParameterTypes;

		PROCEDURE hashCode*(): JT.Int;   (* hashCode()I *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END hashCode;

		PROCEDURE newInstance*(p0: jjlObject.RefArray): Object;   (* newInstance([Ljava/lang/Object;)Ljava/lang/Object; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END newInstance;

		PROCEDURE toString*(): Object;   (* toString()Ljava/lang/String; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END toString;

	END Constructor;


	ConstPool* = POINTER TO ARRAY OF CInfo;

	Class* = OBJECT(Object)
		VAR
			constructor-: PTR;
			vmClass-: PTR;
			pd-: Object;							 (* private ProtectionDomain pd *)
			signers-: jjlObject.RefArray;	(* private Object[] signers *)
			
			next-: Class;
			name*: JT.String;
			state*: SHORTINT;
			
			module*: PCT.Module;
			moduleS*: PCT.ModScope;	(*cached: module.scope*)
			type*: PCT.Pointer;	(* cached: moduleS.firstType.type *)
			typeS*: PCT.RecScope;	(*cached: type.base.scope*)
			native*: PCT.Module;	(** module implementing the native methods *)

			array*: Class;	(* array class of this class *)
			
(*
		PROCEDURE init();   (* <init>()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init;
*)
		PROCEDURE init7797(p0: PTR (*jjlVMClass.Class*));   (* <init>(Ljava/lang/VMClass;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END init7797;

		PROCEDURE finit();   (* finit$()V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END finit;

		PROCEDURE getMethodWithNameAndDesc0*(name, descriptor: ARRAY OF CHAR):Method;
		VAR n, d: JT.String;
		BEGIN
			JT.OberonToJavaString(name, n);
			JT.OberonToJavaString(descriptor, d);
			RETURN getMethodWithNameAndDesc(n, d);
		END getMethodWithNameAndDesc0;

		PROCEDURE getMethodWithNameAndDesc*(VAR name, descriptor: JT.String):Method;
		BEGIN 
			RETURN NIL;
		END getMethodWithNameAndDesc;
						 						 
		PROCEDURE memberAccessCheck(p0: JT.Int);   (* memberAccessCheck(I)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END memberAccessCheck;

		PROCEDURE this();   (* this()V *)		(* synthetic method, not present in source code *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END this;

		PROCEDURE toString*(): Object;   (* toString()Ljava/lang/String; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END toString;

		PROCEDURE newInstance*(): Object;   (* newInstance()Ljava/lang/Object; *)
		BEGIN
			JC.String(errorInfo, "New Instance NIL"); JC.Ln(errorInfo);
			RETURN NIL
		END newInstance;

		PROCEDURE isInstance*(p0: Object): BOOLEAN;   (* isInstance(Ljava/lang/Object;)Z *)
		BEGIN
			RETURN p0.class = SELF
		END isInstance;

		PROCEDURE isAssignableFrom*(p0: Class): BOOLEAN;   (* isAssignableFrom(Ljava/lang/Class;)Z *)
		BEGIN
			RETURN FALSE
		END isAssignableFrom;

		PROCEDURE isInterface*(): BOOLEAN;   (* isInterface()Z *)
		BEGIN RETURN FALSE
		END isInterface;

		PROCEDURE isArray*(): BOOLEAN;   (* isArray()Z *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END isArray;

		PROCEDURE isPrimitive*(): BOOLEAN;   (* isPrimitive()Z *)
		BEGIN
			RETURN FALSE
		END isPrimitive;

		PROCEDURE getName*(): jjlString.String;   (* getName()Ljava/lang/String; *)		 
		VAR str :JString; i:LONGINT;
				tmp: JT.String;
		BEGIN
			NEW(tmp, LEN(name));
			FOR i := 0 TO LEN(tmp^)-1 DO
				IF name[i] = ORD("/") THEN tmp[i] := ORD(".")
				ELSE  tmp[i] := name[i] END
			END;
			str := jjlString.CreateString(tmp);
			RETURN str
		END getName;

		PROCEDURE getPackage*(): Object;   (* getPackage()Ljava/lang/Package; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getPackage;

		PROCEDURE getProtectionDomain*(): Object(*ProtectionDomain*);   (* getProtectionDomain()Ljava/security/ProtectionDomain; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getProtectionDomain;

		PROCEDURE getClassLoader0*(): PTR;   (* getClassLoader()Ljava/lang/ClassLoader; *)
		BEGIN	(* put your implementation here *)
			JC.String(errorInfo, "Class.getClassLoader0 -> NIL"); JC.Ln(errorInfo);
			RETURN NIL
		END getClassLoader0;
		
		PROCEDURE getClassLoader*(): PTR;   (* getClassLoader()Ljava/lang/ClassLoader; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getClassLoader;

		PROCEDURE getSuperclass*(): Class;   (* getSuperclass()Ljava/lang/Class; *)
		BEGIN
			RETURN NIL	(* interface, Object, primitive; array and classes must override *)
		END getSuperclass;

		PROCEDURE getInterfaces*(): jjlObject.RefArray;   (* getInterfaces()[Ljava/lang/Class; *)
		BEGIN
			RETURN EmptyRefArray
		END getInterfaces;

		PROCEDURE getComponentType*(): Class;   (* getComponentType()Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getComponentType;

		PROCEDURE getModifiers*(): JT.Int;   (* getModifiers()I *)
		BEGIN	(* put your implementation here *)
			JC.String(failureInfo, "Class.getModifiers -> NIL"); JC.Ln(failureInfo);
			HALT(99)
		END getModifiers;

		PROCEDURE getSigners*(): jjlObject.RefArray;   (* getSigners()[Ljava/lang/Object; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getSigners;

		PROCEDURE setSigners(signers: jjlObject.RefArray);   (* setSigners([Ljava/lang/Object;)V *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END setSigners;

		PROCEDURE getDeclaringClass*(): Class;   (* getDeclaringClass()Ljava/lang/Class; *)
		BEGIN
			JC.String(errorInfo, "ObjectClass.getDeclaringClass not implemented"); JC.Ln(errorInfo);
			RETURN NIL
		END getDeclaringClass;

		PROCEDURE getClasses*(): jjlObject.RefArray;   (* getClasses()[Ljava/lang/Class; *)
		BEGIN
			RETURN EmptyRefArray
		END getClasses;

		PROCEDURE getFields*(): jjlObject.RefArray;   (* getFields()[Ljava/lang/reflect/Field; *)
			VAR list: jjlObject.RefArray; i: LONGINT; p: PCT.Variable; q: PCT.Value; rec: PCT.Record; c: RefClass;
		BEGIN
			ASSERT(state >= Loaded);
			IF ~fieldLoaded THEN
				Initialize("java/lang/reflect/Field");
				fieldLoaded := TRUE
			END;
			NEW(list);
			IF (moduleS # NIL) & (SELF IS RefClass) THEN
				c := SELF(RefClass);
				NEW(list.p, moduleS.varCount + moduleS.valueCount + typeS.totalVarCount);
				i := 0;
				p := moduleS.firstVar;
				WHILE p # NIL DO list.p[i] := GlobalToField(p, c); INC(i); p := p.nextVar END;
				q := moduleS.firstValue;
				WHILE q # NIL DO list.p[i] := ValueToField(q, c); INC(i); q := q.nextVal END;
				
				WHILE c # NIL DO
					p := c.typeS.firstVar;
					WHILE p # NIL DO list.p[i] := FieldToField(p, c); INC(i); p := p.nextVar END;
					ASSERT(c # c.superClass);
					c := c.superClass
				END
			ELSE
				NEW(list.p, 0)
			END;
			RETURN list
		END getFields;

		PROCEDURE getMethods*(): jjlObject.RefArray;   (* getMethods()[Ljava/lang/reflect/Method; *)
			VAR list: jjlObject.RefArray; p: PCT.Proc; buf: ARRAY 64 OF Method; count, i: LONGINT; rec: PCT.RecScope;
		BEGIN
			IF ~methodLoaded THEN
				Initialize("java/lang/reflect/Method");
				methodLoaded := TRUE
			END;
			NEW(list);
			count := 0;
			p := moduleS.firstProc;
			WHILE p # NIL DO
				IF PCT.PublicR IN p.vis THEN buf[count] := p.info(Method); INC(count) END;
				p := p.nextProc
			END;
			rec := typeS;
			WHILE rec # NIL DO
				p := rec.firstProc;
				WHILE p # NIL DO
					IF PCT.PublicR IN p.vis THEN buf[count] := p.info(Method); INC(count) END;
					p := p.nextProc
				END;
				IF rec.owner.brec # NIL THEN rec := rec.owner.brec.scope ELSE rec := NIL END
			END;
			NEW(list.p, count);
			FOR i := 0 TO count-1 DO list.p[i] := buf[i] END;
			RETURN list
		END getMethods;

		PROCEDURE getConstructors*(): jjlObject.RefArray;   (* getConstructors()[Ljava/lang/reflect/Constructor; *)
		BEGIN
			RETURN EmptyRefArray	(* overwrite otherwise *)
		END getConstructors;

		PROCEDURE getField*(name: JString): Field;   (* getField(Ljava/lang/String;)Ljava/lang/reflect/Field; *)
			VAR n: ARRAY 256 OF CHAR;
		BEGIN
			IF ~fieldLoaded THEN
				Initialize("java/lang/reflect/Field");
				fieldLoaded := TRUE
			END;
			jjlString.ToOberon(name, n);
			RETURN GetField(SELF, StringPool.GetIndex1(n));
		END getField;

		PROCEDURE getMethod*(name: JString; args: jjlObject.RefArray): Method;   (* getMethod(Ljava/lang/String;
																																		[Ljava/lang/Class;)Ljava/lang/reflect/Method; *)
		VAR paramstring: JT.String;
			    fname: JT.String;
				count: LONGINT;
				app: ARRAY 256 OF Method;

				PROCEDURE GetApp(p: RefClass; paramstring: JT.String);
					VAR i, j: LONGINT; m: Method;
				BEGIN
					WHILE p#NIL DO
						i := FindMethodWithSameParams(name, paramstring, p.methods^, 0, LEN(p.methods)-1);
						IF i > 0 THEN
							m := p.methods[i];
							app[count] := p.methods[i]; INC(count); j := i+1;
							WHILE (j < LEN(p.methods^)) &
										m.name.equals(p.methods[j].name) &
										JT.Equal(m.descriptor, LEN(m.descriptor), p.methods[j].descriptor, LEN(p.methods[j].descriptor)) DO
									app[count] := p.methods[j]; INC(count); INC(j)
							END
						END;
						p := p.superClass
					END
				END GetApp;

				PROCEDURE MostSpecific(methods: ARRAY OF Method; count: LONGINT):Method;
				VAR most: Method;
					i: LONGINT;
					cls1, cls2: Class;
				BEGIN
					most := methods[0]; i := 1;
					WHILE i < count DO
						IF (LessOREqual(most.declaringClass, methods[i].declaringClass)) THEN
							cls1 := most.getReturnType();
							cls2 := methods[i].getReturnType();
							IF LessOREqual(cls2, cls1) THEN most := methods[i] END;
						END; INC(i)
					END;
					RETURN most							   
				END MostSpecific;

		BEGIN
			IF ~methodLoaded THEN
				Initialize("java/lang/reflect/Method");
				methodLoaded := TRUE
			END;
			IF SELF IS RefClass THEN
				IF args = NIL THEN
					JT.OberonToJavaString("()", paramstring)
				ELSE
					paramstring := MakeParamString(args.p^)
				END;
				GetApp(SELF(RefClass), paramstring);
				IF count > 0 THEN RETURN MostSpecific(app, count) END
			END;
			RETURN NIL;
		END getMethod;

		PROCEDURE getConstructor*(args: jjlObject.RefArray): Constructor;   (* getConstructor([Ljava/lang/Class;)Ljava/lang/reflect/Constructor; *)
			VAR p: PCT.Proc; c: Constructor; signature: ARRAY 32 OF PCT.Struct;
		BEGIN
			c := NIL;
			IF typeS # NIL THEN
				ConvertSignature(args, signature);
				p := PCT.FindProcedure(NIL, typeS, StringPool.GetIndex1("<init>"), LEN(args.p), signature, TRUE, FALSE);	(*find only public methods*)
				IF p # NIL THEN
					ASSERT(PCT.PublicR IN p.vis);
					IF ~constructorLoaded THEN
						Initialize("java/lang/reflect/Constructor");
						constructorLoaded := TRUE
					END;
					NEW(c);
					c.clazz := SELF; c.slot := SYSTEM.VAL(LONGINT, p);
					c.parameterTypes := args;
				ELSE
					Throw(ThisClass0("java/lang/NoSuchMethodException", TRUE))
				END
			ELSE
				HALT(99)
			END;
			RETURN c
		END getConstructor;

		PROCEDURE getDeclaredClasses2375*(): jjlObject.RefArray;   (* getDeclaredClasses()[Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaredClasses2375;

		PROCEDURE getDeclaredClasses3167(p0: BOOLEAN): jjlObject.RefArray;   (* getDeclaredClasses(Z)[Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaredClasses3167;

		PROCEDURE getDeclaredFields3544*(): jjlObject.RefArray;   (* getDeclaredFields()[Ljava/lang/reflect/Field; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaredFields3544;

		PROCEDURE getDeclaredFields5147(p0: BOOLEAN): jjlObject.RefArray;   (* getDeclaredFields(Z)[Ljava/lang/reflect/Field; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaredFields5147;

		PROCEDURE getDeclaredMethods8941*(): jjlObject.RefArray;   (* getDeclaredMethods()[Ljava/lang/reflect/Method; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaredMethods8941;

		PROCEDURE getDeclaredMethods1578(p0: BOOLEAN): jjlObject.RefArray;   (* getDeclaredMethods(Z)[Ljava/lang/reflect/Method; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaredMethods1578;

		PROCEDURE getDeclaredConstructors2706*(): jjlObject.RefArray;   (* getDeclaredConstructors()[Ljava/lang/reflect/Constructor; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaredConstructors2706;

		PROCEDURE getDeclaredConstructors1538(p0: BOOLEAN): jjlObject.RefArray;   (* getDeclaredConstructors(Z)[Ljava/lang/reflect/Constructor; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END getDeclaredConstructors1538;

		PROCEDURE getDeclaredField*(p0: JString): Field;   (* getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field; *)
		BEGIN RETURN NIL
		END getDeclaredField;

		PROCEDURE getDeclaredMethod*(p0: JString; args: jjlObject.RefArray): Method;   (* getDeclaredMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method; *)
		BEGIN RETURN NIL
		END getDeclaredMethod;

		PROCEDURE getDeclaredConstructor*(args: jjlObject.RefArray): Object;   (* getDeclaredConstructor([Ljava/lang/Class;)Ljava/lang/reflect/Constructor; *)
		BEGIN RETURN NIL
		END getDeclaredConstructor;

		PROCEDURE getResourceAsStream*(p0: JString): Object;   (* getResourceAsStream(Ljava/lang/String;)Ljava/io/InputStream; *)
		BEGIN (* DON'T IMPLEMENT THIS METHOD *)
		END getResourceAsStream;

		PROCEDURE getResource*(name: JString): Object;   (* getResource(Ljava/lang/String;)Ljava/net/URL; *)
		BEGIN (* DON'T IMPLEMENT THIS METHOD *)
		END getResource;

		PROCEDURE desiredAssertionStatus*(): BOOLEAN;   (* desiredAssertionStatus()Z *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END desiredAssertionStatus;

		PROCEDURE internalGetClasses(): jjlObject.RefArray;   (* internalGetClasses()[Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END internalGetClasses;

		PROCEDURE internalGetField(p0: jjlString.String): Field;   (* internalGetField(Ljava/lang/String;)Ljava/lang/reflect/Field; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END internalGetField;

		PROCEDURE internalGetFields(): jjlObject.RefArray;   (* internalGetFields()[Ljava/lang/reflect/Field; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END internalGetFields;

		PROCEDURE internalGetMethod*(p0: jjlString.String; p1: jjlObject.RefArray): Method;   (* internalGetMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END internalGetMethod;

		PROCEDURE internalGetMethods(): jjlObject.RefArray;   (* internalGetMethods()[Ljava/lang/reflect/Method; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
		END internalGetMethods;
		
	END Class;

	PrimitiveClass* = OBJECT(Class)
		VAR
			index-:LONGINT;
			short-:INTEGER;

		PROCEDURE isPrimitive*():BOOLEAN;
		BEGIN RETURN TRUE
		END isPrimitive;

		PROCEDURE isAssignableFrom*(cls: Class):BOOLEAN;
		BEGIN
			RETURN cls = SELF
		END isAssignableFrom;

	END PrimitiveClass;

	ArrayClass* = OBJECT(Class)
		VAR
			dim-: LONGINT;
			ctype-: Class;

		PROCEDURE getComponentType*():Class;
		BEGIN
			RETURN ctype
		END getComponentType;

		PROCEDURE getSuperclass*(): Class;   (* getSuperclass()Ljava/lang/Class; *)
		BEGIN RETURN ThisClass0("java/lang/Object", FALSE)
		END getSuperclass;

		PROCEDURE getInterfaces*(): jjlObject.RefArray;   (* getInterfaces()[Ljava/lang/Class; *)
		VAR res: RefArray;
		BEGIN
			NEW(res); NEW(res.p, 2);
			res.p[0] := ThisClass0("java/lang/Cloneable", TRUE);
			res.p[1] := ThisClass0("java/io/Serializable", TRUE);
			RETURN res
		END getInterfaces;

		PROCEDURE isAssignableFrom*(cls: Class):BOOLEAN;
		BEGIN
			RETURN ((cls IS ArrayClass) & SELF.ctype.isAssignableFrom(cls(ArrayClass).ctype))
		END isAssignableFrom;

	END ArrayClass;

	RefClass* = OBJECT(Class) (* must not be instantiated *)
		VAR
			constPool*: ConstPool;
			extlev*: LONGINT;
			obmod*, obobj*: ARRAY 32 OF CHAR;	(** oberon names for module and object *)
			flags*: SET;
			superClass*: ObjectClass;
			stub*: JS.Module;
			ownModule*: JS.Module;
			fixlist*: CRefInfo;	(*fields/methods to be fixed when this class is linked*)
			fixsyscalls*: ARRAY NOfSysCalls OF LONGINT;	(*linked list in the code*)
			typedesc*: JS.Descriptor;
			interfaces*: POINTER TO ARRAY OF InterfaceClass;
			methods*: POINTER TO ARRAY OF Method;
			dynamicMethods*: LONGINT;		(** total count *)

			attributes*: AInfo;
			staticPtrFields*: LONGINT;	(** total count *)
			
			jit*: LONGINT;	(** jit used to compile class or -1 *)
			
		(** getMethodWithNameAndDesc - DEPRECATED, should use getMethod instead *)

		PROCEDURE getMethodWithNameAndDesc*(VAR name, descriptor: JT.String):Method;
		VAR m: Method;
				c: RefClass;
		BEGIN 
			c := SELF;
			REPEAT
				m := FindMethod(name, descriptor, c.methods^, 0, LEN(c.methods^)-1);
				c := c.superClass
			UNTIL (m # NIL) OR (c = NIL);
			RETURN m;
		END getMethodWithNameAndDesc;

		PROCEDURE getInterfaces*(): jjlObject.RefArray;   (* getInterfaces()[Ljava/lang/Class; *)
		VAR res: jjlObject.RefArray;  i: LONGINT;
		BEGIN
			NEW(res); NEW(res.p, LEN(interfaces));
			FOR i := 0 TO LEN(interfaces) - 1 DO res.p[i] := interfaces[i] END;
			RETURN res
		END getInterfaces;

		PROCEDURE getDeclaredFields*(): jjlObject.RefArray;   (* getDeclaredFields()[Ljava/lang/reflect/Field; *)
			VAR list: jjlObject.RefArray; i: LONGINT; p: PCT.Variable; q: PCT.Value; rec: PCT.Record;
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
			ASSERT(state >= Loaded);
			IF ~fieldLoaded THEN
				Initialize("java/lang/reflect/Field");
				fieldLoaded := TRUE
			END;
			NEW(list);
			IF (moduleS # NIL)  THEN
				NEW(list.p, moduleS.varCount + moduleS.valueCount + typeS.varCount);
				i := 0;
				p := moduleS.firstVar;
				WHILE p # NIL DO list.p[i] := GlobalToField(p, SELF); INC(i); p := p.nextVar END;
				q := moduleS.firstValue;
				WHILE q # NIL DO list.p[i] := ValueToField(q, SELF); INC(i); q := q.nextVal END;
				p := typeS.firstVar;
				WHILE p # NIL DO list.p[i] := FieldToField(p, SELF); INC(i); p := p.nextVar END;
			ELSE
				NEW(list.p, 0)
			END;
			RETURN list
		END getDeclaredFields;
		
		PROCEDURE getDeclaredField*(p0: JString): Field;   (* getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
			JC.String(failureInfo, "RefClass.getDeclaredField not implemented"); JC.Ln(failureInfo);
			HALT(99);
		END getDeclaredField;

		PROCEDURE getDeclaredMethods*(): jjlObject.RefArray;   (* getDeclaredMethods()[Ljava/lang/reflect/Method; *)
			VAR list: jjlObject.RefArray; p: PCT.Proc; i: LONGINT;
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
			IF ~methodLoaded THEN
				Initialize("java/lang/reflect/Method");
				methodLoaded := TRUE
			END;
			NEW(list);
			NEW(list.p, moduleS.procCount+typeS.procCount);
			i := 0;
			p := moduleS.firstProc;
			WHILE p # NIL DO list.p[i] := p.info(Method); INC(i); p := p.nextProc END;
			p := typeS.firstProc;
			WHILE p # NIL DO list.p[i] := p.info(Method); INC(i); p := p.nextProc END;
			RETURN list
		END getDeclaredMethods;

		PROCEDURE getDeclaredMethod*(p0: JString; p1: jjlObject.RefArray): Method;   (* getDeclaredMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method; *)
			VAR methods: jjlObject.RefArray; m: Method; i, ilen, j, jlen, p1len, k: LONGINT; pars: jjlObject.RefArray;
			
			PROCEDURE String(j: JString);
				VAR str: ARRAY 64 OF CHAR;
			BEGIN
				JT.JavaToOberonString(j.value.p, j.offset, j.count, str);
				AosOut.String(str)
			END String;
			
			PROCEDURE Obj(o: jjlObject.Object);
			BEGIN String(o(JString));
			END Obj;
			
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
			AosOut.String("getDeclaredMethod  "); String(p0);
			FOR j := 0 TO LEN(p1.p^)-1 DO Obj(p1.p[k].toString()); AosOut.String(", ")  END;
			AosOut.Ln;
			
			methods := getDeclaredMethods();
			i := 0; ilen := LEN(methods.p^);
			p1len := LEN(p1.p^);
			WHILE (i < ilen) DO
				m := methods.p[i](Method);
				AosOut.String("["); AosOut.Int(i, 0); AosOut.String("] "); String(m.name);
				
				IF m.name.equals(p0) THEN	(* same name *)
AosOut.String("1");
					pars := m.getParameterTypes();
AosOut.String("2");
					j := 0; jlen := LEN(pars.p^);
AosOut.String("3");
					IF jlen = p1len THEN
AosOut.String("4");
						
						WHILE (j < jlen) & pars.p[j].equals(p1.p[j]) DO  INC(j)  END;
AosOut.String("5");
						IF j = jlen THEN RETURN m END;
						
						AosOut.String(" failed on "); AosOut.Int(j, 0);
						Obj(pars.p[j].toString());
					END
				END;
				AosOut.Ln;
				INC(i)
			END;
			
			(*JC.String(errorInfo, "RefClass.getDeclaredMethod not implemented"); JC.Ln(errorInfo);*)
			RETURN NIL
		END getDeclaredMethod;

	END RefClass;

	InterfaceClass* = OBJECT(RefClass)

		PROCEDURE isInterface():BOOLEAN;
		BEGIN RETURN TRUE;
		END isInterface;

		(** rules for interfaces *)
		PROCEDURE isAssignableFrom*(cls: Class): BOOLEAN;   (* isAssignableFrom(Ljava/lang/Class;)Z *)
		VAR assignable: BOOLEAN;

			PROCEDURE IsSpecInterface(base, spec :InterfaceClass):BOOLEAN;
			VAR i: LONGINT;
					isa: BOOLEAN;
			BEGIN
				IF spec = base THEN RETURN TRUE
				ELSE
					isa := FALSE;
					IF (spec.interfaces # NIL) & (LEN(spec.interfaces)>0) THEN
						i := 0;
						WHILE (i < LEN(spec.interfaces)) & ~isa DO
							isa := IsSpecInterface(base, spec.interfaces[i]); INC(i)
						END
					END;
					RETURN isa
				END
			END IsSpecInterface;

		BEGIN
			(* interface classes do not use inheritance, so they must use the structure in Class *)
			assignable := FALSE;
			IF cls IS InterfaceClass THEN
				assignable := IsSpecInterface(SELF, cls(InterfaceClass))
			ELSIF cls IS ArrayClass THEN
				assignable := (SELF=ThisClass0("java/lang/Cloneable", TRUE))
			ELSIF cls IS ObjectClass THEN
				assignable := (JI.Lookup(cls(RefClass).typedesc.tag, SELF.typedesc.tag) # NIL)
			END;
			RETURN assignable
		END isAssignableFrom;

	END InterfaceClass;

	ObjectClass* = OBJECT (RefClass)
		 VAR
			dynamicPtrFields*: LONGINT;
			dummy: ARRAY NOfSysCalls OF LONGINT;	(*remove this, problem with Paco!*)
			curMethod: INTEGER; 	(* used in the initialisation of Methods by the bootloader *) 

		PROCEDURE newInstance*(): Object;   (* newInstance()Ljava/lang/Object; *)
		VAR inst: Object;
			m: Method;
		BEGIN
			JC.String(infoInfo, "New Instance "); JC.String(infoInfo, obmod); JC.Ln(infoInfo);
			inst := NewInstance(SELF);
			inst.class := SELF;
			m := getMethodWithNameAndDesc0("<init>", "()V");
			ASSERT((m#NIL)(* & ~(AFPrivate IN m.flags)*)); (* access is allowed *)
			inst.init;
			RETURN inst
		END newInstance;

		(** rules for object classes *)
		PROCEDURE isAssignableFrom*(cls: Class): BOOLEAN;   (* isAssignableFrom(Ljava/lang/Class;)Z *)
		VAR   adr, tag: LONGINT;
		BEGIN
			IF (cls IS ObjectClass) & (extlev > cls(ObjectClass).extlev) THEN RETURN FALSE
			ELSIF (cls IS ObjectClass) THEN (* cls is subclass of this class *)
				adr := SYSTEM.VAL(LONGINT, cls(ObjectClass).typedesc.tag);
				SYSTEM.GET(adr-8-4*extlev, tag);
				RETURN  tag=SYSTEM.VAL(LONGINT, typedesc.tag)
			ELSIF (cls IS InterfaceClass) OR (cls IS InterfaceClass) THEN	(* this class implements cls *)
				RETURN (jjlObject.class = SELF)
			ELSE 
				 RETURN FALSE
			END
		END isAssignableFrom;

		PROCEDURE getSuperclass*(): Class;   (* getSuperclass()Ljava/lang/Class; *)
		BEGIN RETURN superClass
		END getSuperclass;

		PROCEDURE getClasses*(): jjlObject.RefArray;   (* getClasses()[Ljava/lang/Class; *)
		BEGIN
			JC.String(errorInfo, "ObjectClass.getClasses not implemented"); JC.Ln(errorInfo);
			RETURN EmptyRefArray
		END getClasses;

		PROCEDURE getConstructors*():  jjlObject.RefArray;   (* getConstructors()[Ljava/lang/reflect/Constructor; *)
		BEGIN
			JC.String(errorInfo, "ObjectClass.getConstructors not implemented"); JC.Ln(errorInfo);
			RETURN EmptyRefArray
		END getConstructors;

		PROCEDURE getDeclaredClasses*(): jjlObject.RefArray;   (* getDeclaredClasses()[Ljava/lang/Class; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
			JC.String(errorInfo, "ObjectClass.getDeclaredClasses not implemented"); JC.Ln(errorInfo);
			RETURN EmptyRefArray
		END getDeclaredClasses;

		PROCEDURE getDeclaredConstructors*(): jjlObject.RefArray;   (* getDeclaredConstructors()[Ljava/lang/reflect/Constructor; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
			JC.String(errorInfo, "ObjectClass.getDeclaredConstructors not implemented"); JC.Ln(errorInfo);
			RETURN EmptyRefArray
		END getDeclaredConstructors;

		PROCEDURE getDeclaredConstructor*(p0: jjlObject.RefArray): Object;   (* getDeclaredConstructor([Ljava/lang/Class;)Ljava/lang/reflect/Constructor; *)
		BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
			JC.String(errorInfo, "ObjectClass.getDeclaredConstructor not implemented"); JC.Ln(errorInfo);
			RETURN NIL
		END getDeclaredConstructor;

	END ObjectClass;

VAR
	(* static fields for java/lang/Class *)
	unknownProtectionDomain-: Object(*ProtectionDomain*);	(* private final static ProtectionDomain unknownProtectionDomain *)

	(* static fields for java/lang/reflect/AccessibleObject *)
	classjavalangClass-: Class;
	classjavalangreflectAccessi-: Class;

		(** Class Handling *)
	primitiveClass: ARRAY 9 OF PrimitiveClass;	(*cached value*)

	loadClass*: PROCEDURE (name: JT.String): Class;
	Sentinel*: CRefInfo;

		(** System Calls *)
	SysCalls*: ARRAY NOfSysCalls OF LONGINT;

	Throw*: PROCEDURE (c: Class);
	NewInstance*: PROCEDURE(c: ObjectClass):Object;
	NewArray*:      PROCEDURE(dim, index: LONGINT):Object;
	NewArrayA*:    PROCEDURE(dim: LONGINT; ctype: Class): jjlObject.RefArray;
	MultianewArray*: PROCEDURE(ctype: Class; count: LONGINT):Object; 
	CheckInitialized*: PROCEDURE(c: Class);

	DontRun*: BOOLEAN;	(** loader or linker error, system invalid *)

	EmptyRefArray: RefArray;	(* cached value: RefArray of len 0 *)

		(* Internals *)
	AloadedClasses*,
	AloadStaticFld*,  AloadStaticMth*,
	AloadException*,
	AloadBase*: LONGINT;	(* debug counters *)

	constructorLoaded, fieldLoaded, methodLoaded, classLoaded: BOOLEAN;

	valueIdx: StringPool.Index;

	javaLangClass*: Class;	(** cached value *)

	(* static methods for java/lang.Class *)

	PROCEDURE clinit();   (* <clinit>()V *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END clinit;

	PROCEDURE matchMethod(p0: jjlObject.RefArray; p1: jjlString.String; p2: jjlObject.RefArray): Method;   (* matchMethod([Ljava/lang/reflect/Method;Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method; *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END matchMethod;

	PROCEDURE matchParameters(p0: jjlObject.RefArray; p1: jjlObject.RefArray): BOOLEAN;   (* matchParameters([Ljava/lang/Class;[Ljava/lang/Class;)Z *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END matchParameters;

	PROCEDURE forName1025*(className: JString): Class;   (* forName(Ljava/lang/String;)Ljava/lang/Class; *)
		VAR str: String; i: LONGINT; uni: JT.Unicode;
			
	BEGIN	(* put your implementation here *)
		IF ~classLoaded THEN
			Initialize("java/lang/Class");
			classLoaded := TRUE
		END;
		IF TraceForName THEN JC.String(infoInfo, "forName: ") END;
		IF className = NIL THEN Throw(ThisClass0("java/lang/ClassNotFoundException", TRUE)) END;
		NEW(str, className.count);
		FOR i := 0 TO className.count-1 DO
			uni := className.value.p[i];
			IF TraceForName THEN JC.Char(infoInfo, CHR(uni)) END;
			IF uni = ORD(".") THEN uni := ORD("/") END;
			str[i] := uni
		END;
		IF TraceForName THEN JC.Ln(infoInfo) END;
		RETURN ThisClass(str, TRUE);
	END forName1025;

	PROCEDURE forName2688*(p0: JString; p1: BOOLEAN; p2: Object): Class;   (* forName(Ljava/lang/String;ZLjava/lang/ClassLoader;)Ljava/lang/Class; *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END forName2688;

	(* static methods for java/lang/reflect/AccessibleObject *)
	PROCEDURE checkPermission();   (* checkPermission()V *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END checkPermission;

	PROCEDURE class(p0: String): Class;   (* class$(Ljava/lang/String;)Ljava/lang/Class; *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END class;

	PROCEDURE setAccessible*(p0: RefArray; p1: BOOLEAN);   (* setAccessible([Ljava/lang/reflect/AccessibleObject;Z)V *)
	BEGIN	(* DON'T IMPLEMENT THIS METHOD *)
	END setAccessible;



PROCEDURE FreeClass(m: PCT.Module);
BEGIN
	IF (m.info # NIL) & (m.info IS RefClass) THEN
		JS.FreeModule(m.info(RefClass).ownModule)
	END;
	PCT.Unregister(JT.DB, m.name)
END FreeClass;

PROCEDURE FreeAll*;
BEGIN PCT.Enumerate(JT.DB, FreeClass)
END FreeAll;

(* Common procedures, very often used patterns *)

PROCEDURE Abort*(str: ARRAY OF CHAR);
BEGIN
	HALT(99)
END Abort;

PROCEDURE Error*(str: ARRAY OF CHAR);
BEGIN
	HALT(99)
END Error;

(** Factory Methods for classes *)

PROCEDURE SetLinks(a: Class; m: PCT.Module; p: PCT.Pointer);
BEGIN
	ASSERT(a # NIL);
	ASSERT(m # NIL);
	ASSERT(p # NIL);
	a.module := m;
	a.moduleS := m.scope;
	m.info := a;
	a.type := p;
	a.typeS := p.base(PCT.Record).scope;
END SetLinks;

PROCEDURE CreatePrimitiveClass(i: LONGINT; name: ARRAY OF CHAR; index, short: LONGINT);
VAR c: PrimitiveClass; idx: StringPool.Index; mod: PCT.Module; ptr: PCT.Pointer;
BEGIN
	(* index: used by newarray (see [1], newarray, p.320) *)
	NEW(c);
	JT.OberonToJavaString(name, c.name);
	c.state := Initialized; c.index := index; c.short := SHORT(short);
	primitiveClass[i] := c;
	StringPool.GetIndex(name, idx);
	JT.CreateClass(FALSE, idx, idx, PCT.NoType, mod, ptr);
	SetLinks(c, mod, ptr);
	JT.CommitClass(c.moduleS, c.typeS);
END CreatePrimitiveClass;

PROCEDURE CreateArrayClass(name: String): ArrayClass;
	VAR base: Class; a: ArrayClass; str: String; i: LONGINT; idx: StringPool.Index; mod: PCT.Module; ptr: PCT.Pointer;
BEGIN
	base := NIL;
	IF LEN(name) <= 1 THEN
		Throw(ThisClass0("java/lang/ClassNotFoundException", TRUE))
	ELSE
		ASSERT(name[0] = ORD("["));
		CASE name[1] OF
		|ORD("B"): base := primitiveClass[ByteIdx] 
		|ORD("C"): base := primitiveClass[CharIdx]
		|ORD("D"): base := primitiveClass[DoubleIdx] 
		|ORD("F"): base := primitiveClass[FloatIdx] 
		|ORD("I"): base := primitiveClass[IntIdx] 
		|ORD("J"): base := primitiveClass[LongIdx] 
		|ORD("S"): base := primitiveClass[ShortIdx] 
		|ORD("Z"): base := primitiveClass[BoolIdx]
		|ORD("L"):
			ASSERT(name[LEN(name)-1] = ORD(";"));
			str := JT.Substring(name, 2, LEN(name)-2);
			base := ThisClass(str, TRUE)
		ELSE
			str := JT.Substring(name, 1, LEN(name)-1);
			base := ThisClass(str, TRUE)
		END
	END;
	ASSERT(base # NIL);	(* loader must throw ClassNotFoundException *)
	NEW(a);
	a.ctype := base;
	a.state := Allocated;
	a.name := name;
	i := 0;
	WHILE (i < LEN(name)) & (name[i] = ORD("[")) DO INC(a.dim); INC(i) END;
	JT.JavaToIndex(name, 0, LEN(name), idx);
	JT.CreateArrayClass(idx, base.type, mod, ptr);
	SetLinks(a, mod, ptr);
	RETURN a
END CreateArrayClass;


PROCEDURE InitRefClass(c: RefClass; this :LONGINT; cp: ConstPool; acc: SET);
BEGIN
	c.class := javaLangClass;
	c.flags := acc; c.constPool := cp;
	c.fixlist := Sentinel;
	c.name := c.constPool[this](CClassInfo).index.str;
	c.jit := -1;
END InitRefClass;

PROCEDURE CreateInterfaceClass*(this :LONGINT; cp: ConstPool; acc: SET):InterfaceClass;
VAR c: InterfaceClass;
	i: LONGINT;
BEGIN
	NEW(c); InitRefClass(c, this, cp, acc);
	RETURN c
END CreateInterfaceClass;


PROCEDURE CreateObjectClass*(this: LONGINT; cp: ConstPool; acc: SET):ObjectClass;
VAR c: ObjectClass;
BEGIN
	NEW(c); InitRefClass(c, this, cp, acc);
	c.staticPtrFields := 0;
	RETURN c
END CreateObjectClass;

(** ThisClass - Get a class  *)

PROCEDURE ThisClass*(str: String; load: BOOLEAN): Class;
VAR  p: Class; array: ArrayClass; mod: PCT.Module; str0: ARRAY 256 OF CHAR;
BEGIN
	JT.JavaToOberonString(str, 0, LEN(str), str0);
	mod := PCT.Retrieve(JT.DB, StringPool.GetIndex1(str0));
	IF (mod = NIL) OR (mod.info = NIL) THEN
		p := NIL;
		IF (str[0] = ORD("[")) THEN
			p := CreateArrayClass(str);
			INC(AloadedClasses);
		ELSIF load THEN
			INC(AloadedClasses);
			p := loadClass(str)
		END
	ELSE
		p := SYSTEM.VAL(Class, mod.info)
	END;
	RETURN p
END ThisClass;

PROCEDURE ThisClass0*(str: ARRAY OF CHAR; load: BOOLEAN): Class;
VAR  str0: JT.String;
BEGIN
	JT.OberonToJavaString(str, str0);
	RETURN ThisClass(str0, load)
END ThisClass0;

PROCEDURE LessOREqual*(cls1, cls2: Class):BOOLEAN;
VAR less: BOOLEAN;
	p1 :PrimitiveClass;
BEGIN
	less := FALSE;
	IF cls1.isPrimitive() & cls2.isPrimitive() THEN
		p1 := cls1(PrimitiveClass);
		CASE cls2(PrimitiveClass).short OF
			ORD("Z"): less :=  (p1.short = ORD("Z"))
			|ORD("B"): less := (p1.short = ORD("B"))
			|ORD("C"): less := (p1.short = ORD("C"))
			|ORD("S"): less := (p1.short = ORD("S")) OR (p1.short = ORD("B"))
			|ORD("I"): less := (p1.short = ORD("I")) OR (p1.short = ORD("C")) OR
							 	  (p1.short = ORD("S")) OR (p1.short = ORD("B"))
			|ORD("J"): less := (p1.short = ORD("J")) OR (p1.short = ORD("I")) OR (p1.short = ORD("S")) OR (p1.short = ORD("C")) OR
							 	  (p1.short = ORD("B")) 
			|ORD("F"): less := (p1.short = ORD("F")) OR (p1.short = ORD("J")) OR (p1.short = ORD("I")) OR
									(p1.short = ORD("S")) OR (p1.short = ORD("C")) OR (p1.short = ORD("B"))
			|ORD("D"): less := (p1.short = ORD("D")) OR (p1.short = ORD("F")) OR (p1.short = ORD("J")) OR (p1.short = ORD("I")) OR
									(p1.short = ORD("S")) OR (p1.short = ORD("C")) OR (p1.short = ORD("B"))
		END
	ELSE
		less := cls1.isAssignableFrom(cls2)
	END;
	RETURN less
END LessOREqual;

PROCEDURE StructToClass(t: PCT.Struct): Class;
	VAR c: Class; idx: LONGINT; name: ARRAY 256 OF CHAR;
BEGIN
	IF t IS PCT.Basic THEN
		IF t = PCT.Byte THEN idx := ByteIdx
		ELSIF t = PCT.Bool THEN idx := BoolIdx
		ELSIF t = PCT.Char16 THEN idx := CharIdx
		ELSIF t = PCT.Int16 THEN idx := ShortIdx
		ELSIF t = PCT.Int32 THEN idx := IntIdx
		ELSIF t = PCT.Int64 THEN idx := LongIdx
		ELSIF t = PCT.Float32 THEN idx := FloatIdx
		ELSIF t = PCT.Float64 THEN idx := DoubleIdx
		ELSE HALT(99)
		END;
		c := primitiveClass[idx]
	ELSIF t.owner.info = NIL THEN (* not loaded yet *)
			StringPool.GetString(t.owner.inScope.module.name, name);
			c := ThisClass0(name, TRUE)
	ELSE
		c  := t.owner.info(Class)
	END;
	RETURN c
END StructToClass;

PROCEDURE parseDescriptor(descriptor: String; VAR pos: LONGINT): Class;
VAR str: String; j, len: LONGINT; c: Class;
BEGIN
	CASE descriptor[pos] OF
		|ORD("B"): c := primitiveClass[ByteIdx]; INC(pos)
		|ORD("C"): c := primitiveClass[CharIdx]; INC(pos)
		|ORD("D"): c := primitiveClass[DoubleIdx]; INC(pos)
		|ORD("F"): c := primitiveClass[FloatIdx]; INC(pos)
		|ORD("I"):  c := primitiveClass[IntIdx]; INC(pos)
		|ORD("J"):  c := primitiveClass[LongIdx]; INC(pos)
		|ORD("S"):  c := primitiveClass[ShortIdx]; INC(pos)
		|ORD("Z"): c := primitiveClass[BoolIdx]; INC(pos)
		|ORD("V"): c := primitiveClass[VoidIdx]; INC(pos)
		|ORD("L"): (*reference*) INC(pos); j := pos; 
					  WHILE CHR(descriptor[j])#";" DO INC(j) END; len := j - pos;
					  NEW(str, len); SYSTEM.MOVE(SYSTEM.ADR(descriptor[pos]), SYSTEM.ADR(str[0]), len*2);
					  INC(pos, len+1);
					  c := ThisClass(str, TRUE)
		|ORD("["): (*array*)j := pos+1; c := parseDescriptor(descriptor, j); len := j-pos; 
					  NEW(str, len); SYSTEM.MOVE(SYSTEM.ADR(descriptor[pos]), SYSTEM.ADR(str[0]), len*2);
					  INC(pos, len);
					  c := ThisClass(str, TRUE)
	END;
	RETURN c
END parseDescriptor;

PROCEDURE GetWrapper(name: JT.Unicode):ObjectClass;
VAR cls: Class;
BEGIN
	CASE name OF
		ORD("B"): cls := ThisClass0("java/lang/Byte", TRUE);
		|ORD("Z"): cls := ThisClass0("java/lang/Boolean", TRUE);
		|ORD("C"): cls := ThisClass0("java/lang/Character", TRUE);
		|ORD("S"): cls := ThisClass0("java/lang/Short", TRUE);
		|ORD("I"): cls := ThisClass0("java/lang/Integer", TRUE);
		|ORD("J"):  cls := ThisClass0("java/lang/Long", TRUE);
		|ORD("F"): cls := ThisClass0("java/lang/Float", TRUE);
		|ORD("D"): cls := ThisClass0("java/lang/Double", TRUE);
		ELSE HALT(99)
	END;
	ASSERT(cls.state >= Compiled);
	RETURN cls(ObjectClass)
END GetWrapper;

PROCEDURE GetWrapper0(t: PCT.Struct): ObjectClass;
VAR cls: PrimitiveClass; idx: JT.Unicode;
BEGIN
	IF t = PCT.Byte THEN idx := ORD("B")
	ELSIF t = PCT.Bool THEN idx := ORD("Z")
	ELSIF t = PCT.Char16 THEN idx := ORD("C")
	ELSIF t = PCT.Int16 THEN idx := ORD("S")
	ELSIF t = PCT.Int32 THEN idx := ORD("I")
	ELSIF t = PCT.Int64 THEN idx := ORD("J")
	ELSIF t = PCT.Float32 THEN idx := ORD("F")
	ELSIF t = PCT.Float64 THEN idx := ORD("D")
	ELSE HALT(99)
	END;
	RETURN GetWrapper(idx)
END GetWrapper0;


PROCEDURE Cleanup*;
BEGIN
	FreeAll;
	AosProcessors.GlobalGC
END  Cleanup;

(** builds a descriptor from a list of parameter classes *)
PROCEDURE MakeParamString*(classes: ARRAY OF Object):JT.String;
VAR buffer: ARRAY 1024 OF JT.Unicode;
	i, pos: LONGINT;
	prim: PrimitiveClass; cls: Class;
	str: JT.String;
BEGIN
	i := 0; buffer[0] := ORD("("); pos := 1;
	WHILE i < LEN(classes) DO
		cls := classes[i](Class);
		IF cls.isPrimitive() THEN
			prim := cls(PrimitiveClass);
			buffer[pos]:= prim.short; INC(pos);
		ELSIF cls.isArray() THEN
			SYSTEM.MOVE(SYSTEM.ADR(cls.name[0]), SYSTEM.ADR(buffer[pos]), LEN(cls.name^)*2)
		ELSE
			buffer[pos] := ORD("L"); INC(pos);
			SYSTEM.MOVE(SYSTEM.ADR(cls.name[0]), SYSTEM.ADR(buffer[pos]), LEN(cls.name^)*2);
			INC(pos, LEN(cls.name^));
			buffer[pos] := ORD(";"); INC(pos)
		END; INC(i)
	END;
	buffer[pos] := ORD(")"); INC(pos); NEW(str, pos);
	SYSTEM.MOVE(SYSTEM.ADR(buffer[0]), SYSTEM.ADR(str[0]), pos*2);
	RETURN str
END MakeParamString;

(** compares two desriptors *)
PROCEDURE CompareParams*(param, b: JT.String):LONGINT;
	VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE (param[i] # ORD(")")) & (b[i]#ORD(")")) & (param[i]=b[i]) DO INC(i) END;
	IF b[i] = param[i] THEN RETURN 0
	ELSIF param[i] > b[i] THEN RETURN 1
	ELSE RETURN -1 
	END
END CompareParams;

PROCEDURE FindMethodWithSameParams(name: JString; params: JT.String; VAR methods: ARRAY OF Method; left, right: LONGINT):LONGINT;
VAR med, cmp1, cmp2: LONGINT;
	   
	   PROCEDURE First(index: LONGINT):LONGINT;
	   BEGIN	   
	   	 WHILE (index > 0) & jjlString.EqualStrings(methods[index].name, methods[index-1].name) & 
	   		(CompareParams(methods[index].descriptor, methods[index-1].descriptor) = 0) DO DEC(index)
	   	 END;	   		   
	   	RETURN index;
	   END First;
	   
BEGIN
	WHILE left <= right DO
		med := (left + right) DIV 2;
		cmp1 := jjlString.CompareStrings(name, methods[med].name); 
		IF cmp1 = 0 THEN 
			cmp2 := CompareParams(params, methods[med].descriptor); 
			IF cmp2 = 0 THEN RETURN First(med);
			ELSE cmp1 := cmp2 END
		END;
		IF cmp1 > 0 THEN left := med+1;
		ELSIF cmp1 < 0 THEN right := med - 1
		END
	END;
	IF left > right THEN RETURN -1 END;
END FindMethodWithSameParams;

(* BinSearch Methods *)
PROCEDURE FindMethod*(name, desc: JT.String; VAR methods: ARRAY OF Method; left, right: LONGINT): Method;
VAR med, cmp1, cmp2: LONGINT;
BEGIN
	WHILE left <= right DO
		med := (left + right) DIV 2;
		cmp1 := JT.CompareUniString(name, LEN(name), methods[med].name.value.p, methods[med].name.count); 
		IF cmp1 = 0 THEN 
			cmp2 := JT.CompareUniString(desc, LEN(desc), methods[med].descriptor, LEN(methods[med].descriptor)); 
			IF cmp2 = 0 THEN RETURN methods[med];
			ELSE cmp1 := cmp2 END
		END;
		IF cmp1 > 0 THEN left := med+1;
		ELSIF cmp1 < 0 THEN right := med - 1
		END
	END;
	IF left > right THEN RETURN NIL END;
END FindMethod;

(* Quicksort Methods*)
PROCEDURE SortMethods*(VAR methods :ARRAY OF Method; left, right :LONGINT);
VAR med, i, j, cmp1, cmp2 :LONGINT;
		name: JString;
		descriptor: JT.String;
		meth: Method;
BEGIN
	IF ((right- left) < 1) THEN RETURN END;
	med := (left + right) DIV 2;
	name := methods[med].name;
	descriptor := methods[med].descriptor;
	i := left; j := right;
	REPEAT
		LOOP
			cmp1 := jjlString.CompareStrings(name, methods[i].name);
			IF cmp1 < 0 THEN EXIT (* if greater then exit *)
			ELSIF cmp1 = 0 THEN
				cmp2 := JT.CompareUniString(descriptor, LEN(descriptor), methods[i].descriptor, LEN(methods[i].descriptor));
				IF cmp2 <= 0 THEN EXIT END (* if greater  or equal *)
			END;
			INC(i)
		END;
		LOOP
			cmp1 := jjlString.CompareStrings(name, methods[j].name);
			IF cmp1 > 0 THEN EXIT (* if less then exit *)
			ELSIF cmp1 = 0 THEN
				cmp2 := JT.CompareUniString(descriptor, LEN(descriptor), methods[j].descriptor, LEN(methods[j].descriptor));
				IF cmp2 >= 0 THEN EXIT END (* if less  or equal*)
			END;
			DEC(j)
		END;
		IF i <= j THEN meth := methods[i]; methods[i] := methods[j]; methods[j] := meth; DEC(j); INC(i) END (* swap *)
	UNTIL (i > j);
	IF left < j THEN	SortMethods(methods, left, j) END;
	IF i < right THEN SortMethods(methods, i, right) END;
END SortMethods;

(** VisibilityToFlag - convert PCT visibity to java a flag *)

PROCEDURE VisibilityToFlag*(vis: SET): SET;
	VAR res: SET;
BEGIN
	IF vis = PCT.Public THEN
		res := {AFPublic}
	ELSIF vis = PCT.Protected+PCT.Internal THEN
		res := {AFProtected}
	ELSIF vis = PCT.Internal THEN
		res := {}
	ELSIF vis = PCT.Internal+{PCT.PublicR} THEN
		(* Special case, when class has an oberon implementation *)
		res := {}
	ELSE
		HALT(99)
	END;
	RETURN res
END VisibilityToFlag;

(* ValueToField -  convert a PCT.Value to a java/lang/reflect/Field *)

PROCEDURE ValueToField(o: PCT.Value; class: RefClass): Field;
	VAR f: Field;
BEGIN
	IF o.info = NIL THEN
		NEW(f);
		f.declaringClass := class;
		f.name := jjlString.MakeLiteral0(o.name);
		f.flags := {AFFinal, AFStatic} + VisibilityToFlag(o.vis);
		f.size := o.type.size(PCBT.Size).size;
		f.f := o;
		o.info := f
	ELSE
		f := o.info(Field)
	END;
	RETURN f
END ValueToField;

(* FieldToField - convert a PCT.Field to a java/lang/reflect/Field *)

PROCEDURE FieldToField(o: PCT.Variable; class: RefClass): Field;
	VAR f: Field;
BEGIN
	IF o.info = NIL THEN
		NEW(f);
		f.declaringClass := class;
		f.name := jjlString.MakeLiteral0(o.name);
		f.flags := VisibilityToFlag(o.vis);
		f.offset := o.adr(PCBT.Variable).offset;
		f.size := o.type.size(PCBT.Size).size;
		f.f := o;
	ELSE
		f := o.info(Field)
	END;
	RETURN f
END FieldToField;

(* GlobalToField - convert a PCT.GlobalVar to a java/lang/reflect/Field *)

PROCEDURE GlobalToField(o: PCT.Variable; class: RefClass): Field;
	VAR f: Field;
BEGIN
	IF o.info = NIL THEN
		NEW(f);
		f.declaringClass := class;
		f.name := jjlString.MakeLiteral0(o.name);
		f.flags := {AFStatic} + VisibilityToFlag(o.vis);
		f.offset := o.adr(PCBT.Variable).offset;
		f.size := o.type.size(PCBT.Size).size;
		f.f := o;
	ELSE
		f := o.info(Field)
	END;
	RETURN f
END GlobalToField;

PROCEDURE ScopeLookup(s: PCT.Scope; name: StringPool.Index): PCT.Symbol;
	VAR v: PCT.Variable; val: PCT.Value;
BEGIN
	v := s.firstVar;
	WHILE (v # NIL) & (v.name # name) DO v := v.nextVar END;
	IF v # NIL THEN RETURN v END;
	val := s.firstValue;
	WHILE (val # NIL) & (val.name # name) DO val := val.nextVal END;
	RETURN val
END ScopeLookup;

PROCEDURE GetField0*(VAR c: Class; name: StringPool.Index): PCT.Symbol;
	VAR o: PCT.Symbol; cc: RefClass;
BEGIN
	WITH c: RefClass DO
		cc := c;
		REPEAT
			o := ScopeLookup(cc.moduleS, name);
			IF o = NIL THEN  o := ScopeLookup(cc.typeS, name)  END;
			c := cc;
			cc := c.superClass;
		UNTIL (cc = NIL) OR (o # NIL);
		RETURN o
	END
END GetField0;

PROCEDURE GetField(c: Class; name: StringPool.Index): Field;
	VAR cc: RefClass; o: PCT.Symbol; f: Field;
BEGIN
	WITH c: RefClass DO
		REPEAT
			o := ScopeLookup(c.moduleS, name);
			IF o = NIL THEN  o := ScopeLookup(c.typeS, name)  END;
			cc := c; c := c.superClass;
		UNTIL (c = NIL) OR (o # NIL)
	END;
	IF o # NIL THEN
		IF o.info # NIL THEN f := o.info(Field)
		ELSIF (o IS PCT.GlobalVar) THEN f := GlobalToField(o(PCT.GlobalVar), cc)
		ELSIF (o IS PCT.Field) THEN f := FieldToField(o(PCT.Field), cc)
		ELSIF (o IS PCT.Value) THEN f := ValueToField(o(PCT.Value), cc)
		END
	END;
	RETURN f
END GetField;

PROCEDURE GetFieldOffset*(c: Class; name: StringPool.Index): LONGINT;
	VAR off: LONGINT; v: PCT.Symbol;
BEGIN
	v := GetField0(c, name);
	off := v.adr(PCBT.Variable).offset;
	RETURN off
END GetFieldOffset;

PROCEDURE ConvertSignature(args: jjlObject.RefArray; VAR signature: ARRAY OF PCT.Struct);
	VAR i: LONGINT; class: Class;
BEGIN
	FOR i := 0 TO LEN(args.p)-1 DO
		class := args.p[i](Class);
		ASSERT(class.type # NIL);
		signature[i] := class.type
	END;
END ConvertSignature;

PROCEDURE Initialize(name: ARRAY OF CHAR);
BEGIN
	CheckInitialized(ThisClass0(name, TRUE))
END Initialize;

PROCEDURE Init;
BEGIN
	NEW(EmptyRefArray); NEW(EmptyRefArray.p, 0);
	JS.InstallTermHandler(Cleanup);
	valueIdx := StringPool.GetIndex1("value");
	NEW(Sentinel);
	constructorLoaded := FALSE;
	methodLoaded := FALSE;
	fieldLoaded := FALSE;
	classLoaded := FALSE;
	jjlObject.Initialize := Initialize;
	CreatePrimitiveClass(VoidIdx, "void", 0, ORD("V"));
	CreatePrimitiveClass(ByteIdx, "byte", 8, ORD("B"));
	CreatePrimitiveClass(CharIdx, "char", 5, ORD("C"));
	CreatePrimitiveClass(DoubleIdx, "double", 7, ORD("D"));
	CreatePrimitiveClass(FloatIdx, "float", 6, ORD("F"));
	CreatePrimitiveClass(IntIdx, "int", 10, ORD("I"));
	CreatePrimitiveClass(LongIdx, "long", 11, ORD("J"));
	CreatePrimitiveClass(ShortIdx, "short", 9, ORD("S"));
	CreatePrimitiveClass(BoolIdx, "boolean", 4, ORD("Z"));
	
	debugInfo.kind := JC.Debug; debugInfo.source := JC.Loader;
	warningInfo.kind := JC.Warning; debugInfo.source := JC.Loader;
	infoInfo.kind := JC.Info; infoInfo.source := JC.Loader;
	errorInfo.kind := JC.Error; errorInfo.source := JC.Loader;
	failureInfo.kind := JC.Failure; failureInfo.source := JC.Loader;
END Init;

BEGIN
	Init;
END JVMBase.

(*
	11.01.04	prk	update to classpath 0.06
	15.08.03	prk	getDeclaredMethods implemented
	31.07.03	prk	Logging functions, add kind and source; filtering support
	09.03.03	prk	cache array classes to avoid lookup (improve 202_jess)
	12.02.03	prk	Logging functions, use same interface as AosOut
	29.12.02	prk	update to classpath snapshot 28.12.02
	30.08.02	prk	bug in invoke, parameters where wrong (wrong address taken)
	25.04.02	prk	reorganization; unified compiler interface for creating plugins
	13.03.02	prk	set class field for instances of java/lang/Class
	11.03.02	prk	small fixes (args = NIL)
	16.02.02	prk	scope lookup sequence corrected (local static+dynamic first, instead of hierarchy first)
	11.02.02	prk	updated for classpath-0.03
	23.11.01	prk	Class.getDeclaredFields, Class.getDeclaredMethods
	15.11.01	prk	use fields and vars from PCT instead of JB.Field
	09.11.01	prk	PushSelfTD removed
	23.10.01	prk	support for applets
	22.10.01	prk	upgraded to latest classpath: AccessibleObject added
	18.09.01	prk	load Field, Method, and Class on demand only
	13.09.01	prk	native implementation of java/lang/reflect/Constructor
	06.09.01	prk	crash in CreateArrayClass fixed. Mauve TestClass works
	05.09.01	prk	deadlock fixed; was caused by allocating a class that used a field of a dummy class declared by another (previous) thread
	05.09.01	prk	make class loading and initializing more efficient
	22.08.01	prk	field.ptr removed
	21.08.01	prk	remove internal class-list, use PCT one instead
	16.08.01	prk	Remove use of Oberon modules, use only Aos ones
	16.08.01	prk	take procedure information from PCT+PCBT
	02.08.01	prk	innerclasses attribute
	19.05.01	prk	use common symbol database
	19.05.01	prk	use common symbol database
	22.05.01	prk	Class.getSuperclass, Class.getInterfaces
	16.05.01	prk	field value access cleaned up
	09.05.01	prk	compiler: when call returns boolean, expand it to int
	09.05.01	prk	removing unneeded oberon methods overwriting java methods
	08.05.01	prk	JVMSystem.PushSelfTD
	08.05.01	prk	InvokeMethod improved
	04.04.01	prk	merge with classpath-0.00 release, prepare for update with 0.01, minimize differencies
	26.03.01	prk	Adapted for Paco
	22.03.01	prk	JVMTypes.CLS* contants removed
	22.03.01	prk	cache primitive classes
	22.03.01	prk	CreatePrimitiveClasses removed, done during module initialization
*)