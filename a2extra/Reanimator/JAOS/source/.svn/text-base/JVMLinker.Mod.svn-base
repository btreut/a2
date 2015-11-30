(* Jaos, Copyright 2003, Patrik Reali, ETH Zurich *)

MODULE JVMLinker;	(** PRK, rlaich**)


IMPORT
		SYSTEM, AosModules, 
		PCT, PCOM, PCBT,
		JC := JVMConsole, JS := JVMSystem, JT := JVMTypes, JB := JVMBase, JI := JVMInterfaces, JE := JVMExceptions, jjlThrowable;

CONST
	Trace = FALSE;
	TraceMethods = FALSE;
	
VAR
	UnimplProc: PROCEDURE;
	debugInfo, warningInfo, infoInfo, errorInfo, failureInfo: JC.LoggingInfo;

PROCEDURE Unimplemented;
BEGIN
	HALT(99)
END Unimplemented;

(* fixes list with relative adresses; 
	fix is the adress of target, pc the current position in the code array *)
PROCEDURE FixRelative(code, pc, fix: LONGINT);
VAR next: LONGINT;
BEGIN
	WHILE pc # 0 DO
		SYSTEM.GET(code+pc, next);
		next := next-10000H;
		SYSTEM.PUT(code+pc, fix - (code+pc+4));
		pc := next
	END
END FixRelative;


(* fixes list with absolute adresses *)
PROCEDURE FixAbsolute(code, pc, fix: LONGINT);
VAR next: LONGINT;
BEGIN
	WHILE pc # 0 DO
		SYSTEM.GET(code+pc, next);  next := next-10000H;
		SYSTEM.PUT(code+pc, fix);
		pc := next
	END
END FixAbsolute;

PROCEDURE AddExport(VAR exp: AosModules.ExportDesc; p: PCT.Symbol;  mod: PCT.Module; adr: LONGINT);
BEGIN
	PCOM.FPrintObj(p, mod);
	exp.fp := p.sym(PCOM.Symbol).fp; exp.adr := adr;
	exp.exports := 0; exp.dsc := NIL;
END AddExport;

PROCEDURE InModule(stub: JS.Module; adr: LONGINT): BOOLEAN;
	VAR base: LONGINT;
BEGIN
	base := SYSTEM.ADR(stub.code[0]);
	RETURN (adr >= base) & (adr < base + LEN(stub.code))
END InModule;

(* method.off = absolute entry address *)
(* patch calls to methods defined in class c *)

PROCEDURE PatchMethods(c: JB.RefClass; exp: AosModules.ExportArray; VAR pos: LONGINT);
VAR i, adr, jadr, nadr, t: LONGINT; interface, native: BOOLEAN; m: JB.Method;
	name: ARRAY 128 OF CHAR;
BEGIN
	jadr := JS.GetCodeBase(c.ownModule); (* base adress of the compiled java code *)
	native := c.stub # NIL;
	interface := JB.AFInterface IN c.flags; 
	IF TraceMethods THEN
		JC.Str(debugInfo, c.name); JC.Ln(debugInfo);
	END;
	IF c.superClass # NIL THEN
		ASSERT(c.superClass.state >= JB.Linked);
		FOR i := 0 TO c.superClass.dynamicMethods-1 DO
			t :=  JS.GetMethod(c.typedesc, i);
			IF ~native OR ~InModule(c.stub, t) THEN
				JS.PatchMethod(c.typedesc, i, JS.GetMethod(c.superClass.typedesc, i))
			END
		END
	END;
	IF native THEN nadr := JS.GetCodeBase(c.stub) END;
	FOR i := 0 TO LEN(c.methods)-1 DO
		m := c.methods[i];
		IF JB.AFStatic IN m.flags THEN (* static procedures *)
			IF native THEN 
				adr := m.stubadr;  																			  (* was already read by the loader *)
				IF (JB.AFNative IN m.flags) THEN
					m.offset := adr;
				ELSIF  ~JS.IsEmptyMethod(adr) THEN
					JC.String(warningInfo, "Linker: Oberon overrides "); JC.Str(warningInfo, c.name); JC.String(warningInfo, "."); JC.Str(warningInfo, m.name.value.p); JC.Ln(warningInfo);
					INCL(m.flags, JB.AFOverridden);
					m.offset := adr;
				ELSIF adr # 0 THEN
					(* java implementation is used *)
					INC(m.offset, jadr);
					JS.PatchStaticMethod(adr, m.offset); (* insert jump in the codearray *)
				END
			ELSE (* no stub module present *)
				IF (JB.AFNative IN m.flags) THEN
					JC.String(warningInfo, "Linker: unimplemented "); JC.Str(warningInfo, c.name); JC.String(warningInfo, "."); JC.Str(warningInfo, m.name.value.p); JC.Ln(warningInfo);
					m.offset := SYSTEM.VAL(LONGINT, UnimplProc) (* if no implementation, use Unimplemented *)
				ELSE
					INC(m.offset, jadr)
				END
			END;
			AddExport(exp[pos], m.p, c.module, m.offset -jadr);	(*entry point relative to code base*)
			INC(pos)

		ELSIF ~interface & ~(JB.AFAbstract IN m.flags) THEN	(* all non static *)
			adr := JS.GetMethod(c.typedesc, m.mno); (* adress of method *)
			IF native & InModule(c.stub, adr) & ((JB.AFNative IN m.flags) OR ~JS.IsEmptyMethod(adr)) THEN
				IF ~(JB.AFNative IN m.flags) THEN
					JC.String(warningInfo, "Linker: Oberon overrides "); JC.Str(warningInfo, c.name); JC.String(warningInfo, "."); JC.Str(warningInfo, m.name.value.p); JC.Ln(warningInfo);
					INCL(m.flags, JB.AFOverridden);
				END;
				m.offset := adr
			ELSIF (JB.AFNative IN m.flags) THEN
				JC.String(warningInfo, "Linker: unimplemented "); JC.Str(warningInfo, c.name); JC.String(warningInfo, "."); JC.Str(warningInfo, m.name.value.p); JC.Ln(warningInfo);
				m.offset := SYSTEM.VAL(LONGINT, UnimplProc);
				JS.PatchMethod(c.typedesc, m.mno, m.offset) (* Patch im Typedesriptor *)
			ELSE (* java implementation is used *)				 
				INC(m.offset, jadr);					
				JS.PatchMethod(c.typedesc, m.mno, m.offset);
				IF native THEN
					JS.PatchStaticMethod(adr, m.offset) (* insert jump in the codearray *)
				END
			END;
			IF TraceMethods THEN
				JC.String(debugInfo, "  "); JC.Int(debugInfo, m.mno); JC.String(debugInfo, "  ");
				JC.Str(debugInfo, m.name.value.p);
				JC.String(debugInfo, "  ");
				JC.String(debugInfo, "<call to PCDebug removed!>");
(*
				PCDebug.GetProcedure(m.offset, name);
				JC.String(name);
*)
				JC.Ln(debugInfo);
			END
		END
	END;
(*
	FOR i := 0 TO c.dynamicMethods-1 DO
		ASSERT(JS.GetMethod(c.typedesc, i) # 0)
	END
*)
END PatchMethods;

PROCEDURE ExportVars(mod: PCT.Module; exp: AosModules.ExportArray; VAR pos: LONGINT);
	VAR adr: LONGINT; var: PCT.Variable;
BEGIN
	var := mod.scope.firstVar;
	WHILE var # NIL DO
		adr := var.adr(PCBT.Variable).offset;
		AddExport(exp[pos], var, mod, adr);
		INC(pos);
		var := var.nextVar
	END;
END ExportVars;

PROCEDURE InitInterfaces(c: JB.RefClass);
VAR cc: JB.RefClass;

	PROCEDURE InitInterfaceMethods(int: JB.RefClass; vtbl: PTR);
		VAR adr, off, cnt: LONGINT; intm: PCT.Method; p: PCT.Proc;
	BEGIN
		JC.String(infoInfo, "Linker: new interface "); JC.Str(infoInfo, int.name); JC.String(infoInfo, "; "); JC.Str(infoInfo, c.name);
		ASSERT(~(JB.AFInterface IN c.flags));
		ASSERT(JB.AFInterface IN int.flags);
		adr := SYSTEM.VAL(LONGINT, vtbl)+4; (* the first field is tdesc *)
		intm := int.typeS.firstMeth;
		WHILE intm # NIL DO
			INC(cnt);
			p := PCT.FindSameSignature(c.typeS, intm.name, intm.scope.firstPar, TRUE);
			off := intm.adr(PCBT.Method).mthNo*4;
			SYSTEM.PUT(adr+off, p.info(JB.Method).offset);
			intm := intm.nextMeth
		END;
		JC.String(infoInfo, "  "); JC.Int(infoInfo, cnt, 0); JC.Ln(infoInfo)
	END InitInterfaceMethods;
	
	PROCEDURE Init(c, ic: JB.RefClass);
	VAR i: LONGINT;
	       ip: JI.VTable;
	BEGIN 
		IF ~(JB.AFAbstract IN c.flags) & (ic.interfaces#NIL) THEN i := 0;
	       WHILE i < LEN(ic.interfaces^) DO
	       	ip := JI.Lookup(c.typedesc.tag, ic.interfaces[i].typedesc.tag);
	       	IF ip = NIL THEN
		       	Init(c, ic.interfaces[i]);
		       	JS.NewRec(SYSTEM.VAL(PTR, ip), ic.interfaces[i].typedesc.tag); 
		       	InitInterfaceMethods(ic.interfaces[i], ip);
		       	ASSERT(JI.Insert(c.typedesc.tag, ic.interfaces[i].typedesc.tag, ip));
		       END;
	       	INC(i)
	       END
	    END
	END Init;
	       	
BEGIN
	cc := c;
	WHILE cc#NIL DO 
		Init(c, cc);
		cc := cc.superClass
	END
END InitInterfaces;

PROCEDURE InstallExceptionTable(c: JB.RefClass);
VAR i, j, base, min, max: LONGINT;
	h: JE.ExceptionHandler;
	m: JB.Method;
	str: JT.String; ptr: PTR;
BEGIN
	base := JS.GetCodeBase(c.ownModule); 
	FOR i := 0 TO LEN(c.methods^) - 1 DO
		IF (c.methods[i].code # NIL) &
			(c.methods[i].code.exceptions # NIL) THEN m := c.methods[i];
			min := MAX(LONGINT); max := 0;
			FOR j := 0 TO LEN(m.code.exceptions^)-1 DO			
				(* do it in this order to avoid sign problems *)
				IF m.code.exceptions[j].start < min THEN min := m.code.exceptions[j].start END; 				
				INC(m.code.exceptions[j].start, base);
				IF m.code.exceptions[j].end > max THEN max := m.code.exceptions[j].end END; 
				INC(m.code.exceptions[j].end, base); INC(m.code.exceptions[j].handler, base);
				m.code.exceptions[j].handlesIt := jjlThrowable.IHandleIt;
				IF (m.code.exceptions[j].ex # NIL)  THEN 
					str := SYSTEM.VAL(JT.String, m.code.exceptions[j].ex); 
					m.code.exceptions[j].ex := JB.ThisClass(str, TRUE) 
				END
			END;
			INC(min, base); INC(max, base);			
			JE.CreateHandler(h, min, max, m.code.exceptions, c.ownModule);
			JE.RegisterHandler(h);		
		END	
	END
END InstallExceptionTable;
		
PROCEDURE Link*(c: JB.RefClass);
VAR caddr, i, adr, pos: LONGINT; ref: JB.CRefInfo; exp, exp0: AosModules.ExportArray; name: JT.StringBuffer; m: JB.Method;
	(*f: JB.Field;*)
	fp: PCOM.Struct;
	
	PROCEDURE Type(str: ARRAY OF CHAR);
	BEGIN
		JC.String(infoInfo, "Linker: ");
		JC.String(infoInfo, str); JC.Str(infoInfo, ref.cindex.class.name); JC.String(infoInfo, "."); JC.Str(infoInfo, ref.ntindex.name.str);
		JC.String(infoInfo, " - "); JC.Str(infoInfo, ref.ownclass.name);
		JC.Ln(infoInfo)
	END Type;
	
BEGIN
(*
	IF JB.DontRun THEN RETURN END;
*)
	COPY(c.obobj, name);
	NEW(exp, c.module.scope.procCount+c.module.scope.varCount+1);
	adr := SYSTEM.ADR(c.typedesc.tag) - c.ownModule.sb;
	
	AddExport(exp[0], c.type.owner, c.module, adr);
	NEW(exp0, 2);
	fp := c.type.base.sym(PCOM.Struct);
	exp0[0].fp := fp.pbfp; exp0[0].adr := adr; exp0[0].exports := 0; exp0[0].dsc := NIL;
	exp0[1].fp := fp.pvfp; exp0[0].adr := adr; exp0[0].exports := 0; exp0[0].dsc := NIL;
	exp[0].dsc := exp0;
	exp[0].exports := 2;
	
	c.ownModule.export.adr := 0;
	c.ownModule.export.fp := 0;
	c.ownModule.export.dsc := exp;
	c.ownModule.export.exports := LEN(exp);
	pos := 1;	(* skip class *)
	PatchMethods(c, exp, pos); 	 (* Methoden adressen *)
	ExportVars(c.module, exp, pos);
	IF c IS JB.ObjectClass THEN
		InitInterfaces(c);		(* create new Method-Records for interfaces and initialize method entries *)
	END;
	InstallExceptionTable(c); (* Register handlers for all methods *)
	caddr := JS.GetCodeBase(c.ownModule);
	(* Fix SystemCalls *)
	FOR i := 0 TO LEN(JB.SysCalls)-1 DO
		IF c.fixsyscalls[i] # 0 THEN
			FixRelative(caddr, c.fixsyscalls[i], JB.SysCalls[i]);
			c.fixsyscalls[i] := 0
		END
	END;
	(* all fixpus are in one chain; this chain is now traversed*)
	ref := c.fixlist; c.fixlist := NIL(*JB.Sentinel*);
	WHILE ref # JB.Sentinel DO
		ASSERT((ref.ownclass = c) OR (ref.cindex.class = c));
		caddr := JS.GetCodeBase(ref.ownclass(JB.ObjectClass).ownModule);
		IF ref.fixup = 0 THEN
			(*skip, nothing to do*)
		ELSIF ref.tag = JB.CFieldref THEN
			HALT(99);
		ELSIF (ref.tag = JB.CMethodref) OR (ref.tag = JB.CInterfaceMethodref) THEN
			m := ref.ref(JB.Method);
			(* IF ref.ref = NIL THEN GetMthIndex(ref) END; *)
			IF JB.AFStatic IN m.flags THEN
				IF Trace THEN Type("Fix Static Method ") END;
				FixRelative(caddr, ref.fixup, m.offset)
			ELSE
				IF Trace THEN Type("Fix Method ") END;
				FixAbsolute(caddr, ref.fixup, JS.MethodOffset(m.mno))
			END
		ELSE
			HALT(99)
		END;
		ref := ref.next
	END
END Link;

BEGIN
	debugInfo.kind := JC.Debug; debugInfo.source := JC.Linker;
	warningInfo.kind := JC.Warning; debugInfo.source := JC.Linker;
	infoInfo.kind := JC.Info; infoInfo.source := JC.Linker;
	errorInfo.kind := JC.Error; errorInfo.source := JC.Linker;
	failureInfo.kind := JC.Failure; failureInfo.source := JC.Linker;
	UnimplProc := Unimplemented;
END JVMLinker.

(*
	30.07.03	prk	Logging functions, add kind and source; filtering support
	12.02.03	prk	Logging functions, use same interface as AosOut
	19.03.02	prk	trace informations improved
	21.11.01	prk	add static fields to the export structure
	15.11.01	prk	use fields and vars from PCT instead of JB.Field
	27.05.01	prk	Logging improved
	22.05.01	prk	Compile Base Class before its extensions. Inherit methods
	25.04.01	prk	if no methods, use array of length 0 instead of NIL
	25.04.01	prk	if no fields, use array of length 0 instead of NIL
	04.04.01	prk	merge with classpath-0.00 release, prepare for update with 0.01, minimize differencies
*)