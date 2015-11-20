MODULE Visualizer; (** AUTHOR "staubesv"; PURPOSE "Generate class diagrams that can be visualized using graphviz"; *)
(**
 * This tool generates textual descriptions for class diagrams in the DOT language. These descriptions can be converted in to graphs (postscript, bitmaps,...)
 * using the freeware tool graphviz (www.graphviz.org).
 *
 * Usage:
 *
 *	Visualizer.Generate [options] filename {filename} ~
 *
 * Usage example:
 *
 *	Visualizer.Generate --size="A3" --mode=2 --file="graph.txt" WMComponents.Mod ~ generates the file graph.txt
 *
 * Options:
 *
 *	General:
 *
 *		-s / --size				A0, A1, ..., A10		paper size
 *		-l / --landscape							paper orientation = landscape (portrait otherwise)
 *		-f / --file				filename			output filename
 *		-o / --options			string				graph options for graphviz, e.g. --options='page = "A1"'
 *		-e / --exclude			string				Whitespace-separated list of modules to be excluded from graph
 *
 *	Visibilities:
 *
 *		-h / --hasA				none, public, all		If none, no hasA relations are shown. If public, only hasA relations that are established by
 *													public fields are shown. All hasA relations are shown when set this to 'all'
 *		-d / --dependencies	none, public, all		Also include types that are parameters of procedures?
 *		-t / --types				none, pubilc, all		Determines which type declarations are included
 *		-v / --variables			none, pubilc, all		Determines which variables/fields are included
 *		-p / --procedures		none, public, all		Determines which procedures are included
 *
 *	Mode:
 *
 *		-a / --all				Show all type declarations (otherwise objects, records and pointer to records only)
 *		-m / --mode			Processing mode:
 *								0: Simple. Only show information that is provided directly by parsed modules
 *								1: Recursive, depth = :, if a type information is not available by the parsed modules, parse the module
 *									that provides it and include it
 *								2: Recursive, depth = infinity: Do the same as for mode=1, but repeat this until all type information
 *									is available
 *
 * Status: BETA
 *)

IMPORT
	Streams, KernelLog, Commands, Options, Strings, Files, Texts, TextUtilities, Diagnostics, FoxScanner, ModuleParser;

CONST
	None = 0;
	Public = 1;
	All = 2;

	DefaultTypes = All;
	DefaultVariables = Public;
	DefaultProcedures = Public;
	DefaultHasA = Public;
	DefaultDependencies = None;

	DefaultOutputFilename = "graph.txt";

	DependsOnFactor = 0.1;
	HasAFactor = 0.3;

	NodeFontName = "Arial";
	NodeFontSize = 48;

	(* Generator states *)
	Initialized = 0;
	Running = 1;
	Stopped = 2;

	(* Generator modes *)
	Simple = 0; (* default *)
	Better = 1;
	Extreme = 2;

	(* ModuleEntry.flags *)
	AddSuperType = 0;
	Parsed = 1;
	ScannedSuperTypes = 2;

TYPE
	SizeString = ARRAY 16 OF CHAR;

	Entry = POINTER TO RECORD
		name : ARRAY 256 OF CHAR;
		isSetSuperClass : BOOLEAN;
		next : Entry;
	END;

	List = OBJECT
	VAR
		head : Entry;

		PROCEDURE Add(CONST name : ARRAY OF CHAR) : BOOLEAN;
		VAR entry : Entry;
		BEGIN {EXCLUSIVE}
			IF (Find(name) = NIL) THEN
				NEW(entry);
				COPY(name, entry.name);
				entry.isSetSuperClass := FALSE;
				entry.next := head.next;
				head.next := entry;
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Add;

		PROCEDURE SetSuperClass(CONST name : ARRAY OF CHAR);
		VAR entry : Entry;
		BEGIN {EXCLUSIVE}
			entry := Find(name);
			IF (entry # NIL) THEN
				entry.isSetSuperClass := TRUE;
			END;
		END SetSuperClass;

		PROCEDURE IsSetSuperClass(CONST name : ARRAY OF CHAR) : BOOLEAN;
		VAR entry : Entry;
		BEGIN {EXCLUSIVE}
			entry := Find(name);
			IF (entry # NIL) THEN
				RETURN entry.isSetSuperClass;
			ELSE
				RETURN TRUE;
			END;
		END IsSetSuperClass;

		PROCEDURE Find(CONST name : ARRAY OF CHAR) : Entry; (* private *)
		VAR entry : Entry;
		BEGIN
			entry := head.next;
			WHILE (entry # NIL) & (entry.name # name) DO entry := entry.next; END;
			RETURN entry;
		END Find;

		PROCEDURE &Init; (* private *)
		BEGIN
			NEW(head); head.name := ""; head.next := NIL;
		END Init;

	END List;

TYPE

	ModuleEntry = OBJECT
	VAR
		name : ARRAY 128 OF CHAR;
		module : ModuleParser.Module;
		flags : SET;
		next : ModuleEntry;

		PROCEDURE &Init(CONST name : ARRAY OF CHAR; module : ModuleParser.Module);
		BEGIN
			COPY(name, SELF.name);
			SELF.module := module;
			flags := {AddSuperType};
			next := NIL;
		END Init;

	END ModuleEntry;

	ModuleArray = POINTER TO ARRAY OF ModuleEntry;

	EnumeratorProc = PROCEDURE {DELEGATE} (entry : ModuleEntry; indent : LONGINT);

	ModuleList = OBJECT
	VAR
		head : ModuleEntry;
		nofEntries : LONGINT;

		PROCEDURE Add(CONST name : ARRAY OF CHAR; module : ModuleParser.Module) : BOOLEAN;
		VAR entry : ModuleEntry;
		BEGIN {EXCLUSIVE}
			IF (FindByNameX(name) = NIL) THEN
				NEW(entry, name, module);
				entry.next := head.next;
				head.next := entry;
				INC(nofEntries);
				RETURN TRUE;
			ELSE
				RETURN FALSE;
			END;
		END Add;

		PROCEDURE GetAll() : ModuleArray;
		VAR array : ModuleArray; entry : ModuleEntry; i : LONGINT;
		BEGIN {EXCLUSIVE}
			IF (nofEntries > 0) THEN
				NEW(array, nofEntries);
				entry := head.next;
				i := 0;
				WHILE (entry # NIL) DO
					array[i] := entry; INC(i);
					entry := entry.next;
				END;
			ELSE
				array := NIL;
			END;
			RETURN array;
		END GetAll;

		PROCEDURE Enumerate(proc : EnumeratorProc; indent : LONGINT);
		VAR array : ModuleArray; i : LONGINT;
		BEGIN
			array := GetAll();
			IF (array # NIL) THEN
				FOR i := 0 TO LEN(array)-1 DO
					IF (array[i] # NIL) THEN
						proc(array[i], indent);
					END;
				END;
			END;
		END Enumerate;

		PROCEDURE FindByName(CONST name : ARRAY OF CHAR) : ModuleEntry;
		BEGIN {EXCLUSIVE}
			RETURN FindByNameX(name);
		END FindByName;

		PROCEDURE FindByNameX(CONST name : ARRAY OF CHAR) : ModuleEntry;
		VAR entry : ModuleEntry;
		BEGIN
			entry := head.next;
			WHILE (entry # NIL) & (entry.name # name) DO entry := entry.next; END;
			RETURN entry;
		END FindByNameX;

		PROCEDURE InclFlag(CONST name : ARRAY OF CHAR; flag : LONGINT);
		VAR entry : ModuleEntry;
		BEGIN {EXCLUSIVE}
			entry := FindByNameX(name);
			IF (entry # NIL) THEN INCL(entry.flags, flag); END;
		END InclFlag;

		PROCEDURE ExclFlag(CONST name : ARRAY OF CHAR; flag : LONGINT);
		VAR entry : ModuleEntry;
		BEGIN {EXCLUSIVE}
			entry := FindByNameX(name);
			IF (entry # NIL) THEN EXCL(entry.flags, flag); END;
		END ExclFlag;

		PROCEDURE &Init;
		BEGIN
			NEW(head, "", NIL);
			nofEntries := 0;
		END Init;

	END ModuleList;

	Edge = POINTER TO RECORD
		from, to : ARRAY 128 OF CHAR;
		count : LONGINT;
		next : Edge;
	END;

	EdgeEnumerator = PROCEDURE {DELEGATE} (edge : Edge);

	EdgeList = OBJECT
	VAR
		head : Edge;

		PROCEDURE Add(CONST from, to : ARRAY OF CHAR);
		VAR edge : Edge;
		BEGIN
			edge := Find(from, to);
			IF (edge = NIL) THEN
				NEW(edge);
				COPY(from, edge.from);
				COPY(to, edge.to);
				edge.count := 1;
				edge.next := head.next;
				head.next := edge;
			ELSE
				INC(edge.count);
			END;
		END Add;

		PROCEDURE Find(CONST from, to : ARRAY OF CHAR) : Edge;
		VAR edge : Edge;
		BEGIN
			edge := head.next;
			WHILE (edge # NIL) & ((edge.from # from) OR (edge.to # to)) DO edge := edge.next; END;
			RETURN edge;
		END Find;

		PROCEDURE Enumerate(proc : EdgeEnumerator);
		VAR edge : Edge;
		BEGIN
			edge := head.next;
			WHILE (edge # NIL) DO
				proc(edge);
				edge := edge.next;
			END;
		END Enumerate;

		PROCEDURE &Init;
		BEGIN
			NEW(head); head.next := NIL;
		END Init;

	END EdgeList;
TYPE

	Generator = OBJECT
	VAR
		out : Streams.Writer;
		list : List;
		modules : ModuleList;

		types, variables, procedures, hasA, dependencies : LONGINT; (* Enumeration:  None | Public | All *)
		showAllTypes : BOOLEAN;
		mode : LONGINT;

		hasAEdges, dependsOnEdges : EdgeList;

		excludedModules : Strings.StringArray;

		state : LONGINT;

		PROCEDURE &Init(out : Streams.Writer); (* private *)
		BEGIN
			ASSERT(out # NIL);
			SELF.out := out;
			NEW(list);
			NEW(modules);
			NEW(hasAEdges); NEW(dependsOnEdges);
			state := Initialized;
			mode := Simple;
		END Init;

		PROCEDURE Visibility(identDef : ModuleParser.IdentDef);
		BEGIN
			ASSERT(identDef # NIL);
			IF (identDef.vis = ModuleParser.Public) THEN out.Char("+");
			ELSIF (identDef.vis = ModuleParser.PublicRO) THEN out.Char("-");
			END;
		END Visibility;

		PROCEDURE IsPublic(identDef : ModuleParser.IdentDef) :BOOLEAN;
		BEGIN
			ASSERT(identDef # NIL);
			RETURN (identDef.vis = ModuleParser.Public) OR (identDef.vis = ModuleParser.PublicRO);
		END IsPublic;

		PROCEDURE FormalPars(formalPars : ModuleParser.FormalPars);
		VAR module : ModuleParser.Module; fullname : ARRAY 256 OF CHAR; fpSection : ModuleParser.FPSection;  ident : ModuleParser.IdentList;
		BEGIN
			IF (formalPars # NIL) THEN
				fpSection := formalPars.fpSectionList;
				out.Char("(");
				WHILE (fpSection # NIL) DO
					IF (fpSection.var) THEN out.String("VAR "); END;
					IF (fpSection.const) THEN out.String("CONST "); END;
					ident := fpSection.identList;
					WHILE (ident # NIL) DO
						Type(fpSection.type);
						IF (ident.next # NIL) THEN
							out.Char(",");
							ident := ident.next (ModuleParser.IdentList);
						ELSE
							ident := NIL;
						END;
					END;
					IF (fpSection.next # NIL) THEN
						fpSection := fpSection.next (ModuleParser.FPSection);
						out.Char(",");
					ELSE
						fpSection := NIL;
					END;
				END;
				out.Char(")");
				module := formalPars.GetModule();
				IF (formalPars.returnType # NIL) THEN
					out.String(" : "); Type(formalPars.returnType);
				END;
			END;
		END FormalPars;

		PROCEDURE Array(array : ModuleParser.Array);
		BEGIN
			ASSERT(array # NIL);
			out.String("ARRAY ");
			IF ~array.open THEN
				out.String(array.len.name^); out.Char(" ");
			END;
			out.String("OF ");
			Type(array.base);
		END Array;

		PROCEDURE Type(type : ModuleParser.Type);
		VAR module : ModuleParser.Module; name : Strings.String; fullname : ARRAY 256 OF CHAR;
		BEGIN
			ASSERT(type # NIL);
			module := type.GetModule();
			IF (type.qualident # NIL) THEN
				FixTypeName(module, type.qualident.ident.name^, fullname);
				out.String(fullname);
			ELSIF (type.array # NIL) THEN
				Array(type.array);
			ELSIF (type.record # NIL) THEN
				name := GetTypeName(type);
				FixTypeName(module, name^, fullname);
				out.String(fullname);
			ELSIF (type.pointer # NIL) THEN
				out.String("POINTER TO "); Type(type.pointer.type);
			ELSIF (type.object # NIL) THEN
				FixTypeName(module, type.parent(ModuleParser.TypeDecl).identDef.ident.name^, fullname);
				out.String(fullname);
			ELSIF (type.procedure # NIL) THEN
				out.String("PROCEDURE ");
				IF (type.procedure.delegate) THEN out.String("[DELEGATE] "); END;
				FormalPars(type.procedure.formalPars);
			END;
		END Type;

		PROCEDURE Variable(identList : ModuleParser.IdentList; type : ModuleParser.Type);
		BEGIN
			ASSERT((identList # NIL) & (type # NIL));
			WHILE (identList # NIL) DO
				Visibility(identList.identDef); out.Char(" ");
				IF IsPublic(identList.identDef) OR (variables = All) THEN
					out.String(identList.identDef.ident.name^);
					out.String(" : ");
					Type(type);
					out.String("\l");
				END;
				IF (identList.next # NIL) THEN
					identList := identList.next (ModuleParser.IdentList);
				ELSE
					identList := NIL;
				END;
			END;
		END Variable;

		PROCEDURE VarDecl(varDecl : ModuleParser.VarDecl);
		BEGIN
			WHILE (varDecl # NIL) DO
				Variable(varDecl.identList, varDecl.type);
				IF (varDecl.next # NIL) THEN
					varDecl := varDecl.next (ModuleParser.VarDecl);
				ELSE
					varDecl := NIL;
				END;
			END;
		END VarDecl;

		PROCEDURE ProcHead(procHead : ModuleParser.ProcHead);
		BEGIN
			ASSERT(procHead # NIL);
			IF IsPublic(procHead.identDef) THEN out.String("+ "); END;
			IF (procHead.constructor) THEN out.String("& "); END;
			IF (procHead.inline) THEN out.String("[inline] "); END;
			out.String(procHead.identDef.ident.name^);
			FormalPars(procHead.formalPars);
			out.String("\l");
		END ProcHead;

		PROCEDURE ProcDecl(procDecl : ModuleParser.ProcDecl);
		BEGIN
			WHILE (procDecl # NIL) DO
				IF IsPublic(procDecl.head.identDef) OR (procedures = All) THEN
					ProcHead(procDecl.head);
				END;
				IF (procDecl.next # NIL) THEN
					procDecl := procDecl.next (ModuleParser.ProcDecl);
				ELSE
					procDecl := NIL;
				END;
			END;
		END ProcDecl;

		PROCEDURE FieldDecl(fieldDecl : ModuleParser.FieldDecl);
		BEGIN
			WHILE (fieldDecl # NIL) DO
				IF (fieldDecl.identList # NIL) & (fieldDecl.type # NIL) THEN
					Variable(fieldDecl.identList, fieldDecl.type);
				END;
				IF (fieldDecl.next # NIL) THEN
					fieldDecl := fieldDecl.next (ModuleParser.FieldDecl);
				ELSE
					fieldDecl := NIL;
				END;
			END;
		END FieldDecl;

		PROCEDURE TypeDecl(typeDecl : ModuleParser.TypeDecl; indent : LONGINT);
		BEGIN
			ASSERT(typeDecl # NIL);
			FixTypeDeclName(typeDecl);
			IF list.Add(typeDecl.identDef.ident.name^) THEN
				IF ((typeDecl.type.object # NIL) OR (typeDecl.type.record # NIL) OR ((typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.record # NIL))) & (IsPublic(typeDecl.identDef) OR (types = All)) THEN
					Indent(indent + 4); out.Char('"'); out.String(typeDecl.identDef.ident.name^);
					out.Char('"'); out.String(" ["); out.Ln;
					IF (typeDecl.type.object # NIL) & (ModuleParser.Active IN typeDecl.type.object.modifiers) THEN
						Indent(indent + 8); out.String('color = "red"'); out.Ln;
					END;
					Indent(indent + 8); out.String('label = "{'); out.String(typeDecl.identDef.ident.name^); Visibility(typeDecl.identDef);
					IF (procedures # None) OR (variables # None) THEN
						IF (typeDecl.type.object # NIL) THEN
							out.String("|");
							IF (typeDecl.type.object.declSeq # NIL) & (variables # None) THEN
								VarDecl(typeDecl.type.object.declSeq.varDecl);
							END;
							out.String("|");
							IF (typeDecl.type.object.declSeq # NIL) & (procedures # None) THEN
								ProcDecl(typeDecl.type.object.declSeq.procDecl);
							END;
						ELSIF (typeDecl.type.record # NIL) OR ((typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.record # NIL))  THEN
							out.String("|");
							IF (variables # None) THEN
								IF (typeDecl.type.record # NIL) THEN
									FieldDecl(typeDecl.type.record.fieldList);
								ELSE
									FieldDecl(typeDecl.type.pointer.type.record.fieldList);
								END;
							END;
						END;
					END;
					out.String('}"'); out.Ln;
					Indent(indent + 4); out.String("]"); out.Ln;
				ELSIF showAllTypes & ((types = All) OR IsPublic(typeDecl.identDef)) THEN
					Indent(indent + 4); out.Char('"'); out.String(typeDecl.identDef.ident.name^);
					out.Char('"'); out.String(" ["); out.Ln;
					Indent(indent + 8); out.String('color = blue'); out.Ln;
					Indent(indent + 8); out.String('label = "{'); out.String(typeDecl.identDef.ident.name^); Visibility(typeDecl.identDef);
					IF (typeDecl.type.qualident # NIL) THEN
						out.String("|"); out.String(typeDecl.type.qualident.ident.name^);
					ELSIF (typeDecl.type.array # NIL) THEN
						out.String("|"); Array(typeDecl.type.array);
					ELSIF (typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.array # NIL) THEN
						out.String("| POINTER TO "); Array(typeDecl.type.pointer.type.array);
					ELSIF (typeDecl.type.procedure # NIL) THEN
						out.String("| PROCEDURE ");
						IF (typeDecl.type.procedure.delegate) THEN out.String("[DELEGATE] "); END;
						FormalPars(typeDecl.type.procedure.formalPars);
					END;
 					out.String('}"'); out.Ln;
					Indent(indent + 4); out.String("]"); out.Ln;
				END;
			END;
		END TypeDecl;

		PROCEDURE Module(module : ModuleParser.Module; indent : LONGINT);
		BEGIN
			ASSERT(module # NIL);
			Indent(indent); out.String("subgraph cluster"); out.String(module.ident.name^); out.String(" {"); out.Ln;
			Indent(indent + 4); out.String('label = "'); out.String(module.ident.name^); out.String('"'); out.Ln;
			Indent(indent + 4); out.String('bgcolor = "grey96"'); out.Ln;
			Indent(indent + 4); out.String('margin = "2,2"'); out.Ln;
			GenerateNodes(module, indent + 4);
			GenerateModuleNode(module, indent + 4);
			Indent(indent); out.String("}"); out.Ln;
		END Module;

		PROCEDURE GenerateModuleNode(module : ModuleParser.Module; indent : LONGINT);
		BEGIN
			ASSERT(module # NIL);
			IF (module.declSeq # NIL) THEN
				Indent(indent + 4); out.Char('"'); out.String("Module"); out.String(module.ident.name^);
				out.Char('"'); out.String(" ["); out.Ln;
				Indent(indent + 8); out.String('label = "{'); out.String("MODULE "); out.String(module.ident.name^);
				out.String("|");
				IF (module.declSeq.varDecl # NIL) & (variables # None) THEN
					VarDecl(module.declSeq.varDecl);
				END;
				out.String("|");
				IF (module.declSeq.procDecl # NIL) & (procedures # None) THEN
					ProcDecl(module.declSeq.procDecl);
				END;
				out.String('}"'); out.Ln;
				Indent(indent + 4); out.String("]"); out.Ln;
			END;
		END GenerateModuleNode;

		PROCEDURE GenerateNodes(module : ModuleParser.Module; indent : LONGINT);
		VAR typeDecl : ModuleParser.TypeDecl;
		BEGIN
			ASSERT(module # NIL);
			IF (module.declSeq # NIL) & (module.declSeq.typeDecl # NIL) THEN
				typeDecl := module.declSeq.typeDecl;
				WHILE (typeDecl # NIL) DO
					TypeDecl(typeDecl, indent);
					IF (typeDecl.next # NIL) THEN
						typeDecl := typeDecl.next (ModuleParser.TypeDecl);
					ELSE
						typeDecl := NIL;
					END;
				END;
			END;
		END GenerateNodes;

		PROCEDURE AddEdge(CONST from, to : ARRAY OF CHAR; indent : LONGINT);
		BEGIN
			Indent(indent);
			out.Char('"'); out.String(from); out.String('" -> "'); out.String(to); out.Char('"'); out.Ln;
		END AddEdge;

		PROCEDURE GenerateHasAEdges(entry : ModuleEntry; indent : LONGINT);
		VAR
			typeDecl : ModuleParser.TypeDecl;

			PROCEDURE AtLeastOneIdentIsPublic(identList : ModuleParser.IdentList) : BOOLEAN;
			BEGIN
				WHILE (identList # NIL) & ~IsPublic(identList.identDef) DO
					IF (identList.next # NIL) THEN
						identList := identList.next (ModuleParser.IdentList);
					ELSE
						identList := NIL;
					END;
				END;
				RETURN identList # NIL;
			END AtLeastOneIdentIsPublic;

			PROCEDURE GetTargetNodeName(CONST name : ARRAY OF CHAR; entry : ModuleEntry) : Strings.String;
			VAR targetNodeName : Strings.String; typeDecl : ModuleParser.TypeDecl;
			BEGIN
				typeDecl := FindTypeDecl(name, entry);
				IF (typeDecl # NIL) & (typeDecl.type # NIL) & ((showAllTypes) OR
					((typeDecl.type.object # NIL) OR (typeDecl.type.record # NIL) OR ((typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.record # NIL))))
				THEN
					targetNodeName := GetTypeName(typeDecl.type);
				ELSE
					targetNodeName := NIL;
				END;
				RETURN targetNodeName
			END GetTargetNodeName;

			PROCEDURE GenerateObjectFieldEdges(object : ModuleParser.Object; entry : ModuleEntry);
			VAR varDecl : ModuleParser.VarDecl; name : Strings.String; fullname : ARRAY 128 OF CHAR;
			BEGIN
				ASSERT(object # NIL);
				IF (object.declSeq # NIL) THEN
					varDecl := typeDecl.type.object.declSeq.varDecl;
					WHILE (varDecl # NIL) DO
						IF (varDecl.type.qualident # NIL) & ((hasA = All) OR AtLeastOneIdentIsPublic(varDecl.identList)) THEN
							FixTypeName(entry.module, varDecl.type.qualident.ident.name^, fullname);
							name := GetTargetNodeName(fullname, entry);
							IF (name # NIL) THEN
								hasAEdges.Add(typeDecl.identDef.ident.name^, name^);
							ELSIF ~IsBasicType(varDecl.type.qualident.ident.name^) THEN
								KernelLog.String("Object type not found: "); KernelLog.String(fullname);
								KernelLog.Ln;
							END;
						END;
						IF (varDecl.next # NIL) THEN
							varDecl := varDecl.next (ModuleParser.VarDecl);
						ELSE
							varDecl := NIL;
						END;
					END;
				END;
			END GenerateObjectFieldEdges;

			PROCEDURE GenerateRecordFieldEdges(record : ModuleParser.Record; entry : ModuleEntry);
			VAR fieldDecl : ModuleParser.FieldDecl; name : Strings.String;
			BEGIN
				ASSERT(record # NIL);
				fieldDecl := record.fieldList;
				WHILE (fieldDecl # NIL) DO
					IF (fieldDecl.type # NIL) & (fieldDecl.type.qualident # NIL) & ((hasA = All) OR AtLeastOneIdentIsPublic(fieldDecl.identList)) THEN
						name := GetTargetNodeName(fieldDecl.type.qualident.ident.name^, entry);
						IF (name # NIL) THEN
							hasAEdges.Add(typeDecl.identDef.ident.name^, name^);
						ELSIF ~IsBasicType(fieldDecl.type.qualident.ident.name^) THEN
							KernelLog.String("Record type not found: "); KernelLog.String(fieldDecl.type.qualident.ident.name^);
							KernelLog.Ln;
						END;
					END;
					IF (fieldDecl.next # NIL) THEN
						fieldDecl := fieldDecl.next (ModuleParser.FieldDecl);
					ELSE
						fieldDecl := NIL;
					END;
				END;
			END GenerateRecordFieldEdges;

			PROCEDURE GenerateArrayBaseEdge(array : ModuleParser.Array; entry : ModuleEntry);
			VAR name : Strings.String;
			BEGIN
				IF (array.base.qualident # NIL) THEN
					name := GetTargetNodeName(array.base.qualident.ident.name^, entry);
					IF (name # NIL) THEN
						hasAEdges.Add(typeDecl.identDef.ident.name^, name^);
					ELSIF ~IsBasicType(array.base.qualident.ident.name^) THEN
						KernelLog.String("Array type not found: "); KernelLog.String(array.base.qualident.ident.name^);
						KernelLog.Ln;
					END;
				END;
			END GenerateArrayBaseEdge;

		BEGIN
			IF (entry.module # NIL) & (entry.module.declSeq # NIL) THEN
				typeDecl := entry.module.declSeq.typeDecl;
				WHILE (typeDecl # NIL) DO
					IF (typeDecl.type.object # NIL) THEN
						GenerateObjectFieldEdges(typeDecl.type.object, entry);
					ELSIF (typeDecl.type.record # NIL) THEN
						GenerateRecordFieldEdges(typeDecl.type.record, entry);
					ELSIF ((typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.record # NIL)) THEN
						GenerateRecordFieldEdges(typeDecl.type.pointer.type.record, entry);
					ELSIF showAllTypes THEN
						IF (typeDecl.type.array # NIL) THEN
							GenerateArrayBaseEdge(typeDecl.type.array, entry);
						ELSIF ((typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.array # NIL)) THEN
							GenerateArrayBaseEdge(typeDecl.type.pointer.type.array, entry);
						END;
					END;
					IF (typeDecl.next # NIL) THEN
						typeDecl := typeDecl.next (ModuleParser.TypeDecl);
					ELSE
						typeDecl := NIL;
					END;
				END;
			END;
		END GenerateHasAEdges;

		PROCEDURE GenerateDependsOnEdges(entry : ModuleEntry; indent : LONGINT);
		VAR typeDecl : ModuleParser.TypeDecl;

			PROCEDURE CheckProcedures(procDecl : ModuleParser.ProcDecl);
			VAR
				typeName : Strings.String; fpSection : ModuleParser.FPSection; td : ModuleParser.TypeDecl;
				fullname, temp : ARRAY 128 OF CHAR;
			BEGIN
				WHILE (procDecl # NIL) DO
					IF (procDecl.head.formalPars # NIL) THEN
						fpSection := procDecl.head.formalPars.fpSectionList;
						WHILE (fpSection # NIL) DO
							IF (fpSection.type.qualident # NIL) THEN
								IF ~IsBasicType(fpSection.type.qualident.ident.name^) THEN
									td := FindTypeDecl(fpSection.type.qualident.ident.name^, entry);
									IF (td # NIL) THEN
										FixTypeName(entry.module, fpSection.type.qualident.ident.name^, fullname);
										IF ~Strings.ContainsChar(fullname, ".", FALSE) THEN
											COPY(fullname, temp);
											COPY(entry.module.ident.name^, fullname);
											Strings.Append(fullname, "."); Strings.Append(fullname, temp);
										END;
										dependsOnEdges.Add(typeDecl.identDef.ident.name^, fullname);
									ELSE
										KernelLog.String("Type "); KernelLog.String(fpSection.type.qualident.ident.name^);
										KernelLog.String(" not found"); KernelLog.Ln;
									END;
								END;
							ELSE
								typeName := GetTypeName(fpSection.type);
								IF (typeName # NIL) THEN
									dependsOnEdges.Add(typeDecl.identDef.ident.name^, typeName^);
								END;
							END;
							IF (fpSection.next # NIL) THEN
								fpSection := fpSection.next (ModuleParser.FPSection);
							ELSE
								fpSection := NIL;
							END;
						END;
					END;
					IF (procDecl.next # NIL) THEN
						procDecl := procDecl.next (ModuleParser.ProcDecl);
					ELSE
						procDecl := NIL;
					END;
				END;
			END CheckProcedures;

		BEGIN
			IF (entry.module # NIL) & (entry.module.declSeq # NIL) THEN
				typeDecl := entry.module.declSeq.typeDecl;
				WHILE (typeDecl # NIL) DO
					IF (typeDecl.type.object # NIL) & (typeDecl.type.object.declSeq # NIL) THEN
						CheckProcedures(typeDecl.type.object.declSeq.procDecl);
					END;
					IF (typeDecl.next # NIL) THEN
						typeDecl := typeDecl.next (ModuleParser.TypeDecl);
					ELSE
						typeDecl := NIL;
					END;
				END;
			END;
		END GenerateDependsOnEdges;

		PROCEDURE GenerateEdges(entry : ModuleEntry; indent : LONGINT);
		VAR typeDecl : ModuleParser.TypeDecl; object : ModuleParser.Object; record : ModuleParser.Record; name, name2 : Strings.String;

			PROCEDURE GetRecordName(record : ModuleParser.Record) : Strings.String;
			BEGIN
				ASSERT(record # NIL);
				IF (record.parent.parent IS ModuleParser.TypeDecl) THEN
					RETURN record.parent.parent(ModuleParser.TypeDecl).identDef.ident.name;
				ELSE
					RETURN record.parent.parent.parent.parent(ModuleParser.TypeDecl).identDef.ident.name;
				END;
			END GetRecordName;

		BEGIN
			IF (entry.module # NIL) & (entry.module.declSeq # NIL) & (entry.module.declSeq.typeDecl # NIL) THEN
				typeDecl := entry.module.declSeq.typeDecl;
				WHILE (typeDecl # NIL) DO
					IF (typeDecl.type.record # NIL) OR ((typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.record # NIL))  THEN
						IF (typeDecl.type.record # NIL) THEN
							record := typeDecl.type.record;
						ELSE
							record := typeDecl.type.pointer.type.record;
						END;
						WHILE (record.superPtr # NIL) DO
							name := GetRecordName(record);
							IF ~list.IsSetSuperClass(name^) THEN
								list.SetSuperClass(name^);
								IF (record.superPtr.parent.parent IS ModuleParser.TypeDecl) THEN
									FixTypeDeclName(record.superPtr.parent.parent(ModuleParser.TypeDecl));
								ELSE
									FixTypeDeclName(record.superPtr.parent.parent.parent.parent(ModuleParser.TypeDecl));
								END;
								name2 := GetRecordName(record.superPtr);
								AddEdge(name^, name2^, indent);
							END;
							record := record.superPtr;
						END;
					ELSIF (typeDecl.type.object # NIL) THEN
						object := typeDecl.type.object;
						WHILE (object.superPtr # NIL) DO
							IF ~list.IsSetSuperClass(object.parent.parent(ModuleParser.TypeDecl).identDef.ident.name^) THEN
								list.SetSuperClass(object.parent.parent(ModuleParser.TypeDecl).identDef.ident.name^);
								FixTypeDeclName(object.superPtr.parent.parent(ModuleParser.TypeDecl));
								AddEdge(
									object.parent.parent(ModuleParser.TypeDecl).identDef.ident.name^,
									object.superPtr.parent.parent(ModuleParser.TypeDecl).identDef.ident.name^,
									indent
								);
							END;
							object := object.superPtr;
						END;
					END;
					IF (typeDecl.next # NIL) THEN
						typeDecl := typeDecl.next (ModuleParser.TypeDecl);
					ELSE
						typeDecl := NIL;
					END;
				END;
			END;
		END GenerateEdges;

		PROCEDURE AddSuperTypesSimple(entry : ModuleEntry; indent : LONGINT);
		VAR superClass : ModuleParser.Object; superRecord : ModuleParser.Record; typeDecl : ModuleParser.TypeDecl;
		BEGIN
			IF (AddSuperType IN entry.flags) & (entry.module # NIL) & (entry.module.declSeq # NIL) & (entry.module.declSeq.typeDecl # NIL) THEN
				typeDecl := entry.module.declSeq.typeDecl;
				WHILE (typeDecl # NIL) DO
					IF (typeDecl.type.object # NIL) THEN
						superClass := typeDecl.type.object.superPtr;
						WHILE (superClass # NIL) DO
							TypeDecl(superClass.parent.parent(ModuleParser.TypeDecl), indent);
							superClass := superClass.superPtr;
						END;
					ELSIF (typeDecl.type.record # NIL) OR ((typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.record # NIL))  THEN
						IF (typeDecl.type.record # NIL) THEN
							superRecord := typeDecl.type.record.superPtr;
						ELSE
							superRecord := typeDecl.type.pointer.type.record.superPtr;
						END;
						WHILE (superRecord # NIL) DO
							IF (superRecord.parent.parent IS ModuleParser.TypeDecl) THEN
								TypeDecl(superRecord.parent.parent(ModuleParser.TypeDecl), indent);
							ELSE
								TypeDecl(superRecord.parent.parent.parent.parent(ModuleParser.TypeDecl), indent);
							END;
							superRecord := superRecord.superPtr;
						END;
					END;
					IF (typeDecl.next # NIL) THEN
						typeDecl := typeDecl.next (ModuleParser.TypeDecl);
					ELSE
						typeDecl := NIL;
					END;
				END;
			END;
		END AddSuperTypesSimple;

		PROCEDURE AddSuperTypeModulesToList(entry : ModuleEntry; indent : LONGINT);
		VAR
			superClass : ModuleParser.Object; superRecord : ModuleParser.Record;
			typeDecl : ModuleParser.TypeDecl;
			module : ModuleParser.Module;
			moduleName, typeName : ARRAY 128 OF CHAR;
			ignore : BOOLEAN;
		BEGIN
			IF (AddSuperType IN entry.flags) & ~(ScannedSuperTypes IN entry.flags) & (entry.module # NIL) & (entry.module.declSeq # NIL) & (entry.module.declSeq.typeDecl # NIL) THEN
				typeDecl := entry.module.declSeq.typeDecl;
				WHILE (typeDecl # NIL) DO
					IF (typeDecl.type.object # NIL) THEN
						superClass := typeDecl.type.object.superPtr;
						WHILE (superClass # NIL) DO
							module := superClass.GetModule();
							IF (module # NIL)  & (module # entry.module) THEN
								IF ~IsExcluded(module.ident.name^) THEN
									ignore := modules.Add(module.ident.name^, NIL);
								END;
							ELSIF (superClass.parent.parent IS ModuleParser.TypeDecl) THEN
								ModuleParser.SplitName(superClass.parent.parent(ModuleParser.TypeDecl).identDef.ident.name^, moduleName, typeName);
								IF ~IsExcluded(moduleName) THEN
									ignore := modules.Add(moduleName, NIL);
								END;
							ELSE
								KernelLog.String("BOOM1: ");
								KernelLog.String(superClass.parent.parent(ModuleParser.TypeDecl).identDef.ident.name^); KernelLog.Ln;
							END;
							superClass := superClass.superPtr;
						END;
					ELSIF (typeDecl.type.record # NIL) OR ((typeDecl.type.pointer # NIL) & (typeDecl.type.pointer.type.record # NIL))  THEN
						IF (typeDecl.type.record # NIL) THEN
							superRecord := typeDecl.type.record.superPtr;
						ELSE
							superRecord := typeDecl.type.pointer.type.record.superPtr;
						END;
						WHILE (superRecord # NIL) DO
							module := superRecord.GetModule();
							IF (module # NIL) & (module # entry.module) THEN
								IF ~IsExcluded(module.ident.name^) THEN
									ignore := modules.Add(module.ident.name^, NIL);
								END;
							ELSIF (superRecord.parent.parent IS ModuleParser.TypeDecl) THEN
								ModuleParser.SplitName(superRecord.parent.parent(ModuleParser.TypeDecl).identDef.ident.name^, moduleName, typeName);
								IF ~IsExcluded(moduleName) THEN
									ignore := modules.Add(moduleName, NIL);
								END;
							ELSE
								KernelLog.String("BOOM2"); KernelLog.Ln;
							END;
							superRecord := superRecord.superPtr;
						END;
					END;
					IF (typeDecl.next # NIL) THEN
						typeDecl := typeDecl.next (ModuleParser.TypeDecl);
					ELSE
						typeDecl := NIL;
					END;
				END;
				modules.InclFlag(entry.module.ident.name^, ScannedSuperTypes);
			END;
		END AddSuperTypeModulesToList;

		PROCEDURE AddUsedTypeModulesToList(entry : ModuleEntry; ident : LONGINT);
		VAR
			typeDecl : ModuleParser.TypeDecl; varDecl : ModuleParser.VarDecl;
			moduleName, typeName : ARRAY 128 OF CHAR;
			fullname : ARRAY 256 OF CHAR;
			ignore : BOOLEAN;
		BEGIN
			IF (entry.module # NIL) & (entry.module.declSeq # NIL) THEN
				typeDecl := entry.module.declSeq.typeDecl;
				WHILE (typeDecl # NIL) DO
					IF (typeDecl.type.object # NIL) & (typeDecl.type.object.declSeq # NIL) THEN
						varDecl := typeDecl.type.object.declSeq.varDecl;
						WHILE (varDecl # NIL) DO
							IF (varDecl.type.qualident # NIL) THEN
								FixTypeName(entry.module, varDecl.type.qualident.ident.name^, fullname);
								ModuleParser.SplitName(fullname, moduleName, typeName);
								IF (moduleName # "") & (moduleName # entry.name) THEN
									IF ~IsExcluded(moduleName) THEN
										ignore := modules.Add(moduleName, NIL);
									END
								END;
							END;
							IF (varDecl.next # NIL) THEN
								varDecl := varDecl.next (ModuleParser.VarDecl);
							ELSE
								varDecl := NIL;
							END;
						END;
					END;
					IF (typeDecl.next # NIL) THEN
						typeDecl := typeDecl.next (ModuleParser.TypeDecl);
					ELSE
						typeDecl := NIL;
					END;
				END;
			END;
		END AddUsedTypeModulesToList;

		PROCEDURE AddDependeciesModulesToList(entry : ModuleEntry; ident : LONGINT);
		VAR
			typeDecl : ModuleParser.TypeDecl; procDecl : ModuleParser.ProcDecl;
			moduleName, typeName : ARRAY 128 OF CHAR;

			PROCEDURE CheckFPSection(fpSection : ModuleParser.FPSection);
			VAR type : ModuleParser.Type; ignore : BOOLEAN;
			BEGIN
				ASSERT((fpSection # NIL) & (fpSection.type # NIL));
				type := fpSection.type;
				IF (type.object # NIL) THEN
				ELSIF (type.record # NIL) THEN
				ELSIF (type.pointer # NIL) & (type.pointer.type.record # NIL) THEN
				ELSIF (type.qualident # NIL) & ~IsBasicType(type.qualident.ident.name^) THEN
					ModuleParser.SplitName(type.qualident.ident.name^, moduleName, typeName);
					IF (moduleName # "") & (moduleName # entry.module.ident.name^) THEN
						IF ~IsExcluded(moduleName) THEN
							ignore := modules.Add(moduleName, NIL);
						END;
					END;
				END;
			END CheckFPSection;

			PROCEDURE CheckProcDecl(entry : ModuleEntry; procDecl : ModuleParser.ProcDecl);
			VAR fpSection : ModuleParser.FPSection;
			BEGIN
				ASSERT((procDecl # NIL) & (procDecl.head # NIL));
				IF (procDecl.head.formalPars # NIL) & (procDecl.head.formalPars.fpSectionList # NIL) THEN
					fpSection := procDecl.head.formalPars.fpSectionList;
					WHILE (fpSection # NIL) DO
						CheckFPSection(fpSection);
						IF (fpSection.next # NIL) THEN
							fpSection := fpSection.next (ModuleParser.FPSection);
						ELSE
							fpSection := NIL;
						END;
					END;
				END;
			END CheckProcDecl;

		BEGIN
			ASSERT(entry # NIL);
			IF (entry.module # NIL) & (entry.module.declSeq # NIL) THEN
				typeDecl := entry.module.declSeq.typeDecl;
				WHILE (typeDecl # NIL) DO
					IF (typeDecl.type.object # NIL) & (typeDecl.type.object.declSeq # NIL) THEN
						procDecl := typeDecl.type.object.declSeq.procDecl;
						WHILE (procDecl # NIL) DO
							CheckProcDecl(entry, procDecl);
							IF (procDecl.next # NIL) THEN
								procDecl := procDecl.next (ModuleParser.ProcDecl);
							ELSE
								procDecl := NIL;
							END;
						END;
					END;
					IF (typeDecl.next # NIL) THEN
						typeDecl := typeDecl.next (ModuleParser.TypeDecl);
					ELSE
						typeDecl := NIL;
					END;
				END;
			END;
		END AddDependeciesModulesToList;

		PROCEDURE FindTypeDecl(CONST name : ARRAY OF CHAR; entry : ModuleEntry) : ModuleParser.TypeDecl;
		VAR
			moduleName, typeName, fullname : ARRAY 128 OF CHAR;
			e : ModuleEntry;
			typeDecl : ModuleParser.TypeDecl;
		BEGIN
			typeDecl := NIL;
			ModuleParser.SplitName(name, moduleName, typeName);
			IF ~IsBasicType(typeName) & (moduleName # "SYSTEM") THEN
				IF (moduleName = entry.name) OR (moduleName = "") THEN
					COPY(entry.module.ident.name^, fullname); Strings.Append(fullname, "."); Strings.Append(fullname, typeName);
					typeDecl := entry.module.FindTypeDecl(fullname);
				ELSE
					e := modules.FindByName(moduleName);
					IF (e # NIL) & (e.module # NIL) THEN
						FixTypeName(e.module, name, fullname);
						typeDecl := e.module.FindTypeDecl(fullname);
					END;
				END;
			END;
			RETURN typeDecl;
		END FindTypeDecl;

		PROCEDURE ParseModule(entry : ModuleEntry; ident : LONGINT);
		VAR filename : Files.FileName; file : Files.File;
		BEGIN
			IF (entry.name # "SYSTEM") & (entry.module = NIL) & ~(Parsed IN entry.flags) THEN
				COPY(entry.name, filename); Strings.Append(filename, ".Mod");
				file := Files.Old(filename);
				IF (file = NIL) THEN
					KernelLog.String("Visualizer: Cannot open file "); KernelLog.String(filename); KernelLog.String(", try I386.");
					KernelLog.String(filename); KernelLog.String(" ... ");
					filename := "I386."; Strings.Append(filename, entry.name); Strings.Append(filename, ".Mod");
					file := Files.Old(filename);
					IF (file # NIL) THEN
						KernelLog.String("found!");
					ELSE
						KernelLog.String("not found!, Trying Oberon."); KernelLog.String(entry.name); KernelLog.String(" ... ");
						filename := "Oberon."; Strings.Append(filename, entry.name); Strings.Append(filename, ".Mod");
						file := Files.Old(filename);
						IF (file # NIL) THEN
							KernelLog.String("found!");
						ELSE
							KernelLog.String("not found! Giving up...");
						END;
					END;
					KernelLog.Ln;
				END;
				IF (file # NIL) THEN
					ParseFile(filename, entry.module);
					modules.InclFlag(entry.name, Parsed);
					IF (entry.module # NIL) THEN
						Module(entry.module, 4);
					END;
				ELSE
					KernelLog.String("Visualizer: File "); KernelLog.String(filename); KernelLog.String(" not found - ignore!");
					KernelLog.Ln;
				END;
			END;
		END ParseModule;

		PROCEDURE AddTypes;
		VAR done : BOOLEAN; nofEntries : LONGINT;
		BEGIN
			IF (mode = Simple) THEN
				IF (hasA # None) THEN modules.Enumerate(AddUsedTypeModulesToList, 4); END;
				IF (dependencies # None) THEN modules.Enumerate(AddDependeciesModulesToList, 4); END;
				modules.Enumerate(AddSuperTypesSimple, 4);
			ELSIF (mode = Better) THEN
				modules.Enumerate(AddSuperTypeModulesToList, 4);
				IF (hasA # None) THEN modules.Enumerate(AddUsedTypeModulesToList, 4); END;
				IF (dependencies # None) THEN modules.Enumerate(AddDependeciesModulesToList, 4); END;
				modules.Enumerate(ParseModule, 0);
				modules.Enumerate(AddSuperTypesSimple, 4);
			ELSIF (mode = Extreme) THEN
				done := FALSE;
				WHILE ~done DO
					nofEntries := modules.nofEntries;
					modules.Enumerate(AddSuperTypeModulesToList, 4);
					IF (hasA # None) THEN modules.Enumerate(AddUsedTypeModulesToList, 4); END;
					IF (dependencies # None) THEN modules.Enumerate(AddDependeciesModulesToList, 4); END;
					modules.Enumerate(ParseModule, 0);
					done := nofEntries = modules.nofEntries;
				END;
				modules.Enumerate(AddSuperTypesSimple, 4);
			END;
		END AddTypes;

		PROCEDURE ProcessOptions(options : Options.Options);
		VAR string : ARRAY 512 OF CHAR; integer : LONGINT; sizeString : SizeString; i : LONGINT;
		BEGIN
			sizeString := "";
			IF options.GetString("size", string) THEN
				GetSizeString(string, sizeString);
			END;
			IF options.GetFlag("landscape")THEN
				Rotate(sizeString);
			END;
			IF (sizeString # "") THEN
				Indent(4); out.String('size = "'); out.String(sizeString); out.String('"'); out.Ln;
			END;
			IF options.GetInteger("mode", integer) THEN
				IF (0 <= integer) & (integer <= Extreme) THEN
					SELF.mode := integer;
				END;
			END;
			IF options.GetString("options", string) THEN
				Indent(4); out.String(string); out.Ln;
			END;
			IF options.GetFlag("all") THEN showAllTypes := TRUE; ELSE showAllTypes := FALSE; END;
			IF options.GetString("types", string) THEN
				types := GetMode(string);
			ELSE
				types := DefaultTypes;
			END;
			IF options.GetString("variables", string) THEN
				variables := GetMode(string);
			ELSE
				variables := DefaultVariables;
			END;
			IF options.GetString("procedures", string) THEN
				procedures := GetMode(string);
			ELSE
				procedures := DefaultProcedures;
			END;
			IF options.GetString("hasA", string) THEN
				hasA := GetMode(string);
			ELSE
				hasA := DefaultHasA;
			END;
			IF options.GetString("dependencies", string) THEN
				dependencies := GetMode(string);
			ELSE
				dependencies := DefaultDependencies;
			END;
			IF options.GetString("exclude", string) THEN
				excludedModules := Strings.Split(string, " ");
				FOR i := 0 TO LEN(excludedModules)-1 DO
					Strings.TrimWS(excludedModules[i]^);
				END;
			ELSE
				excludedModules := NIL;
			END;
		END ProcessOptions;

		PROCEDURE IsExcluded(CONST moduleName : ARRAY OF CHAR) : BOOLEAN;
		VAR i  : LONGINT;
		BEGIN
			IF (excludedModules # NIL) THEN
				FOR i := 0 TO LEN(excludedModules)-1 DO
					IF (moduleName = excludedModules[i]^) THEN RETURN TRUE; END;
				END;
			END;
			RETURN FALSE;
		END IsExcluded;

		PROCEDURE Open(options : Options.Options);
		BEGIN
			ASSERT(options # NIL);
			ASSERT(state = Initialized);
			state := Running;

			out.String("digraph TEST");  out.String(" {"); out.Ln;
			ProcessOptions(options);
			Indent(4); out.String('rankdir = "BT"'); out.Ln;
			Indent(4); out.String('ranksep = "0.5"'); out.Ln;
			Indent(4); out.String('ratio = "compress"'); out.Ln;
			Indent(4); out.String('remincross = "true"'); out.Ln;
			IF options.GetFlag("landscape") THEN
				Indent(4); out.String('orientation = "landscape"'); out.Ln;
			END;
			Indent(4); out.String("node ["); out.Ln;
			Indent(8); out.String('fontname = "'); out.String(NodeFontName); out.String('"'); out.Ln;
			Indent(8); out.String('fontsize = "'); out.Int(NodeFontSize, 0); out.String('"'); out.Ln;
			Indent(8); out.String('shape = "record"'); out.Ln;
			Indent(4); out.String("]"); out.Ln;
		END Open;

		PROCEDURE AddModule(module : ModuleParser.Module; indent : LONGINT);
		BEGIN
			ASSERT(module # NIL);
			ASSERT(state = Running);
			IF modules.Add(module.ident.name^, module) THEN
				modules.InclFlag(module.ident.name^, Parsed);
				Module(module, indent);
			END;
		END AddModule;

		PROCEDURE WriteHasAEdge(edge : Edge);
		BEGIN
			Indent(4);
			out.Char('"'); out.String(edge.from); out.String('" -> "'); out.String(edge.to); out.Char('"');
			out.String(" [weight = "); out.FloatFix(HasAFactor * edge.count, 4, 1, 0); out.String("]"); out.Ln;
		END WriteHasAEdge;

		PROCEDURE WriteDependsOnEdge(edge : Edge);
		BEGIN
			Indent(4);
			out.Char('"'); out.String(edge.from); out.String('" -> "'); out.String(edge.to); out.Char('"');
			out.String(" [weight = "); out.FloatFix(DependsOnFactor * edge.count, 4, 1, 0); out.String("]"); out.Ln;
		END WriteDependsOnEdge;

		PROCEDURE Close;
		VAR array : ModuleArray; i : LONGINT;
		BEGIN
			ASSERT(state = Running);

			AddTypes;

			KernelLog.String("Included modules: ");
			array := modules.GetAll();
			FOR i := 0 TO LEN(array)-1 DO
				KernelLog.String(array[i].name); KernelLog.String(" ");
			END;
			KernelLog.Ln;

			Indent(4); out.String("edge ["); out.Ln;
			Indent(8); out.String('arrowhead = "normal"'); out.Ln;
			Indent(8); out.String('arrowtail = "none"'); out.Ln;
			Indent(8); out.String('arrowsize = "4.0"'); out.Ln;
			Indent(8); out.String('penwidth = "5"'); out.Ln;
			Indent(8); out.String('color = "black"'); out.Ln;
			Indent(8); out.String('weight = 100'); out.Ln;
			Indent(4); out.String("]"); out.Ln;

			modules.Enumerate(GenerateEdges, 4);

			IF (hasA # None) THEN
				Indent(4); out.String("edge ["); out.Ln;
				Indent(8); out.String('arrowhead = "none"'); out.Ln;
				Indent(8); out.String('arrowtail = "diamond"'); out.Ln;
				Indent(8); out.String('arrowsize = "2.0"'); out.Ln;
				Indent(8); out.String('penwidth = "1"'); out.Ln;
				Indent(8); out.String('color = "blue"'); out.Ln;
				Indent(4); out.String("]"); out.Ln;

				modules.Enumerate(GenerateHasAEdges, 4);
				hasAEdges.Enumerate(WriteHasAEdge);
			END;

			IF (dependencies # None) THEN
				Indent(4); out.String("edge ["); out.Ln;
				Indent(8); out.String('arrowhead = "normal"'); out.Ln;
				Indent(8); out.String('arrowtail = "none"'); out.Ln;
				Indent(8); out.String('arrowsize = "2.0"'); out.Ln;
				Indent(8); out.String('penwidth = "1"'); out.Ln;
				Indent(8); out.String('color = "green"'); out.Ln;
				Indent(8); out.String('style = "dashed"'); out.Ln;
				Indent(4); out.String("]"); out.Ln;

				modules.Enumerate(GenerateDependsOnEdges, 4);
				dependsOnEdges.Enumerate(WriteDependsOnEdge);
			END;

			state := Stopped;
			out.String("}");
			out.Update;
		END Close;

		PROCEDURE Indent(indent : LONGINT); (* private *)
		BEGIN
			WHILE (indent > 0) DO out.Char(" "); DEC(indent); END;
		END Indent;

	END Generator;

PROCEDURE FixTypeName(module : ModuleParser.Module; CONST name : ARRAY OF CHAR; VAR fullname : ARRAY OF CHAR);
VAR modulename, importname, typename : ARRAY 256 OF CHAR;
BEGIN
	ModuleParser.SplitName(name, modulename, typename);
	IF (modulename # "") THEN (* replace import alias by module name *)
		IF (module # NIL) THEN
			FindImport(modulename, module, importname);
		ELSE
			importname := "";
		END;
		IF (modulename # importname) & (importname # "") THEN
			COPY(importname, fullname);
			Strings.Append(fullname, "."); Strings.Append(fullname, typename);
		ELSE
			COPY(name, fullname);
		END;
	ELSE
		COPY(name, fullname);
	END;
END FixTypeName;

PROCEDURE FixTypeDeclName(typeDecl : ModuleParser.TypeDecl);
VAR module : ModuleParser.Module; name, typeName : ARRAY 256 OF CHAR;
BEGIN
	ASSERT(typeDecl # NIL);
	IF ~Strings.ContainsChar(typeDecl.identDef.ident.name^, ".", FALSE) THEN
		module := typeDecl.GetModule();
		IF (module # NIL) THEN
			COPY(typeDecl.identDef.ident.name^, typeName);
			COPY(module.ident.name^, name);
			Strings.Append(name, ".");
			Strings.Append(name, typeName);
			typeDecl.identDef.ident.name := Strings.NewString(name);
		END;
	END;
END FixTypeDeclName;

PROCEDURE GetTypeName(node : ModuleParser.Node) : Strings.String;
VAR name : Strings.String;
BEGIN
	WHILE (node # NIL) & (node.parent # node) & ~(node IS ModuleParser.TypeDecl) DO node := node.parent; END;
	IF (node # NIL) & (node IS ModuleParser.TypeDecl) THEN
		name := node(ModuleParser.TypeDecl).identDef.ident.name;
	ELSE
		name := Strings.NewString("UnknownType");
	END;
	RETURN name;
END GetTypeName;

PROCEDURE IsBasicType(CONST string : ARRAY OF CHAR) : BOOLEAN;
BEGIN
	RETURN (string = "CHAR") OR (string = "ANY") OR (string = "BOOLEAN") OR (string = "SET")
		OR (string = "SHORTINT") OR (string = "INTEGER") OR (string = "LONGINT") OR (string = "HUGEINT")
		OR (string = "REAL") OR (string = "LONGREAL")
		OR (string = "ADDRESS") OR (string = "SIZE") OR (string = "SYSTEM.BYTE");
END IsBasicType;

PROCEDURE FindImport(CONST name : ARRAY OF CHAR; module : ModuleParser.Module; VAR importName : ARRAY OF CHAR);
VAR import : ModuleParser.Import;
BEGIN
	ASSERT(module # NIL);
	importName:= "";
	IF (name # "") THEN
		import := module.FindImport(name);
		IF (import # NIL) THEN
			IF (import.alias # NIL) THEN
				COPY(import.alias.name^, importName);
			ELSE
				COPY(import.ident.name^, importName);
			END;
		END;
	END;
END FindImport;

PROCEDURE Rotate(VAR size : SizeString);
VAR stringArray : Strings.StringArray;
BEGIN
	stringArray := Strings.Split(size, ",");
	IF (LEN(stringArray) = 2) THEN
		COPY(stringArray[1]^, size);
		Strings.Append(size, ",");
		Strings.Append(size, stringArray[0]^);
	END;
END Rotate;

PROCEDURE GetSizeString(CONST size : ARRAY OF CHAR; VAR sizeString : SizeString);
BEGIN
	IF (size = "A0") THEN sizeString := "33.1,46.8";
	ELSIF (size = "A1") THEN sizeString := "22.4,33.1";
	ELSIF (size = "A2") THEN sizeString := "16.5,23.4";
	ELSIF (size = "A3") THEN sizeString := "11.7,16.5";
	ELSIF (size = "A4") THEN sizeString := "8.3,11.7";
	ELSIF (size = "A5") THEN sizeString := "5.8,8.3";
	ELSIF (size = "A6") THEN sizeString := "4.1,5.8";
	ELSIF (size = "A7") THEN sizeString := "2.9,4.1";
	ELSIF (size = "A8") THEN sizeString := "2.05,2.9";
	ELSIF (size = "A9") THEN sizeString := "1.46,2.05";
	ELSIF (size = "A10") THEN sizeString := "1.02,1.46";
	ELSE
		COPY(size, sizeString);
	END;
END GetSizeString;

PROCEDURE ParseFile(CONST filename : ARRAY OF CHAR; VAR module : ModuleParser.Module);
VAR
	scanner : FoxScanner.Scanner;
	text :  Texts.Text;
	reader : TextUtilities.TextReader;
	diagnostics : Diagnostics.StreamDiagnostics;
	writer : Streams.Writer;
	format, res : LONGINT;
BEGIN
	module := NIL;
	NEW(text);
	TextUtilities.LoadAuto(text, filename, format, res);
	IF (res = 0) THEN
		NEW(writer, KernelLog.Send, 256);
		NEW(diagnostics, writer);
		NEW(reader, text);
		scanner := FoxScanner.NewScanner(filename, reader, 0, diagnostics);
		ModuleParser.Parse(scanner, module);
		IF (module # NIL) THEN
			ModuleParser.SetSuperTypes(module);
		END;
	END;
END ParseFile;

PROCEDURE GetMode(CONST string : ARRAY OF CHAR) : LONGINT;
VAR mode : LONGINT;
BEGIN
	ASSERT((string = "none") OR (string = "public") OR (string = "all"));
	IF (string = "none") THEN mode := None;
	ELSIF (string = "public") THEN mode := Public;
	ELSIF (string = "all") THEN mode := All;
	END;
	ASSERT((mode = None) OR (mode = Public) OR (mode = All));
	RETURN mode;
END GetMode;

PROCEDURE Generate*(context : Commands.Context); (** [options] moduleName {" " modulename} ~  *)
VAR
	moduleName, outputFilename : Files.FileName;
	module : ModuleParser.Module;
	file : Files.File;
	writer : Files.Writer;
	generator : Generator;
	options : Options.Options;

	PROCEDURE IsValid(CONST string : ARRAY OF CHAR) : BOOLEAN;
	BEGIN
		RETURN (string = "none") OR (string = "public") OR (string = "all");
	END IsValid;

	PROCEDURE CheckOptions(options : Options.Options; out : Streams.Writer) : BOOLEAN;
	VAR string : ARRAY 32 OF CHAR; integer : LONGINT; error : BOOLEAN;
	BEGIN
		ASSERT((options # NIL) & (out # NIL));
		error := FALSE;
		IF options.GetString("types", string) & ~IsValid(string) THEN
			out.String("Option argument wrong: -t / --types = 'none' | 'public' | 'all'"); out.Ln;
			error := TRUE;
		END;
		IF options.GetString("variables", string) & ~IsValid(string) THEN
			out.String("Option argument wrong: -v / --variables = 'none' | 'public' | 'all'"); out.Ln;
			error := TRUE;
		END;
		IF options.GetString("procedures", string) & ~IsValid(string) THEN
			out.String("Option argument wrong: -p / --procedures = 'none' | 'public' | 'all'"); out.Ln;
			error := TRUE;
		END;
		IF options.GetString("hasA", string) & ~IsValid(string) THEN
			out.String("Option argument wrong: -h / --hasA = 'none' | 'public' | 'all'"); out.Ln;
			error := TRUE;
		END;
		IF options.GetString("dependencies", string) & ~IsValid(string) THEN
			out.String("Option argument wrong: -d / --dependencies = 'none' | 'public' | 'all'"); out.Ln;
			error := TRUE;
		END;
		IF options.GetInteger("mode", integer) & (integer # Simple) & (integer # Better) & (integer # Extreme) THEN
			out.String("Option argument wrong: -m / --mode = 0 | 1 | 2"); out.Ln;
			error := TRUE;
		END;
		RETURN ~error;
	END CheckOptions;

BEGIN
	NEW(options);
	options.Add("a", "all", Options.Flag);
	options.Add("d", "dependencies", Options.String);
	options.Add("s", "size", Options.String);
	options.Add("f", "file", Options.String);
	options.Add("h", "hasA", Options.String);
	options.Add("l", "landscape", Options.Flag);
	options.Add("o", "options", Options.String);
	options.Add("m", "mode", Options.Integer);
	options.Add("t", "types", Options.String);
	options.Add("v", "variables", Options.String);
	options.Add("p", "procedures", Options.String);
	options.Add("e", "exclude", Options.String);

	IF options.Parse(context.arg, context.out) THEN
		IF CheckOptions(options, context.out) THEN
			IF ~options.GetString("file", outputFilename) THEN
				COPY(DefaultOutputFilename, outputFilename);
			END;
			file := Files.New(outputFilename);
			IF (file # NIL) THEN
				NEW(writer, file, 0);
				NEW(generator, writer);
				generator.Open(options);

				WHILE context.arg.GetString(moduleName) DO
					ParseFile(moduleName, module);
					IF (module # NIL) THEN
						generator.AddModule(module, 4);
						context.out.String("Added "); context.out.String(moduleName); context.out.Ln;
					ELSE
						context.out.String("Error: Could not parse module "); context.out.String(moduleName); context.out.Ln;
					END;
				END;

				generator.Close;
				Files.Register(file);
				context.out.String("Graph description written to "); context.out.String(outputFilename); context.out.Ln;
			ELSE
				context.out.String("Could not create file "); context.out.String(moduleName); context.out.Ln;
			END;
		END;
	END;
END Generate;

END Visualizer.

Visualizer.Generate PET.Mod ~

Visualizer.Generate -s="A3" -m=1 --landscape  WMWindowManager.Mod WindowManager.Mod  WMComponents.Mod WMStandardComponents.Mod ~

Visualizer.Generate -s="A3"  -l -o='ratio = "compress" '-m=1 Usbdi.Mod Usb.Mod UsbHcdi.Mod UsbEhci.Mod UsbHubDriver.Mod ~

Visualizer.Generate -s="A3"  -l -o='ratio = "compress" '-m=1 -v=all -p=all -h=all -a -d=all Usbdi.Mod Usb.Mod UsbHcdi.Mod UsbEhci.Mod UsbHubDriver.Mod ~

Visualizer.Generate -s="A3" -m=2 --landscape  WMWindowManager.Mod WindowManager.Mod  ~

Visualizer.Generate -s="A3" -o='page = "--landscape PCT.Mod ~

Visualizer.Generate   -s="A0"  -l -o='ratio = "fill" '-m=2 -v=public -p=public -h=all -a
	-e="WMFontManager Modules Kernel Raster CLUTs Machine Heaps Objects"
	XMLObjects.Mod XML.Mod WMMessages.Mod WMGraphics.Mod WMFontManager.Mod WindowManager.Mod WMWindowManager.Mod
	WMEvents.Mod WMProperties.Mod WMComponents.Mod  ~

Visualizer.Generate -s="A0" -l -o='ratio = "fill"' -m=2 -v=public -p=public -h=all -a
	-e="Modules"
	Oberon.Objects.Mod Oberon.Links.Mod Oberon.Attributes.Mod Oberon.Gadgets.Mod
~

Visualizer.Generate -a  -s="A0" -v=all --procedures=all --hasA=all -d=all --mode=0 Visualizer.Mod  ~

Visualizer.Generate -a  -s="A3" ratio="fill"' -v=none -p=none -h=all -m=2 -e="Modules Machine Heaps Objects Kernel Raster XMLObjects XML"  WMEvents.Mod WMProperties.Mod WMComponents.Mod WindowManager.Mod ~


Visualizer.Generate -a  -s="A3" -v=all -p=all -h=all -m=2 Trace.Mod I386.Machine.Mod Heaps.Mod Objects.Mod Modules.Mod Kernel.Mod  ~

Visualizer.Generate -a -s="A3" -v=all -p=all -m=1 WMWindowManager.Mod ~

SystemTools.Free Visualizer ~ Test.svg