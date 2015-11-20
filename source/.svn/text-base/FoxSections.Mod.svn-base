MODULE FoxSections; (** AUTHOR "fof"; PURPOSE "support for code sections and references"; *)

IMPORT SyntaxTree := FoxSyntaxTree,Streams,Global := FoxGlobal,Formats := FoxFormats, Basic := FoxBasic, Strings, ObjectFile;

CONST
	(* section categories *)
	InitCodeSection*=ObjectFile.InitCode;
	BodyCodeSection*=ObjectFile.BodyCode;
	CodeSection*=ObjectFile.Code;
	VarSection*=ObjectFile.Data;
	ConstSection*=ObjectFile.Const;
	InlineCodeSection*=10;
	UnknownSectionType *= 11;

	LineCommentStart*="; ";

	(* gensam *)
	UnknownSize* = -1;
	UndefinedFinalPosition* = -1;

TYPE
	Identifier*=ObjectFile.Identifier;
	SectionName*= ObjectFile.SegmentedName;

	Section*=OBJECT
	VAR
		name-: SectionName; (* name of this section (globally unique-name derived from symbol name) *)
		type-: SHORTINT; (* CodeSection, InlineCodeSection, VarSection or ConstSection *)
		priority-: INTEGER; (* priority of the section *)

		fixed-: BOOLEAN; (* whether the position of the section is fixed, as opposed to being restricted by an alignment *)
		positionOrAlignment-: LONGINT; (* the alignment OR the position *)
		fingerprint-: LONGINT; (* fingerprint of the corresponding syntax tree node *)
		bitsPerUnit-: LONGINT; (* the unit size given in bits *)

		(* for compatibility with old object file format *)
		symbol-: SyntaxTree.Symbol; (* corresponding symbol in AST *)
		offset-: LONGINT;
		isCaseTable*: BOOLEAN; (* necessary because old object file format cannot patch fixups in variable/constant area *)
		referenced-: BOOLEAN;

		(* for linking *)
		isReachable-: BOOLEAN;

		PROCEDURE & InitSection*(type: SHORTINT; priority: INTEGER; CONST n: ObjectFile.SegmentedName; symbol: SyntaxTree.Symbol);
		BEGIN
			name := n;
			SELF.symbol := symbol;
			SELF.type := type;
			SELF.priority := priority;
			offset := 0;
			referenced := TRUE;
			fixed := FALSE;
			positionOrAlignment := 1;
			fingerprint := 0;
			bitsPerUnit := UnknownSize;
			isCaseTable := FALSE;
		END InitSection;

		PROCEDURE IsCode*(): BOOLEAN;
		BEGIN
			RETURN type IN {CodeSection, InitCodeSection, BodyCodeSection};
		END IsCode;

		PROCEDURE SetReferenced*(ref: BOOLEAN);
		BEGIN referenced := ref;
		END SetReferenced;

		PROCEDURE SetOffset*(offset: LONGINT);
		BEGIN SELF.offset := offset;
		END SetOffset;

		PROCEDURE SetReachability*(isReachable: BOOLEAN);
		BEGIN SELF.isReachable := isReachable
		END SetReachability;

		PROCEDURE SetBitsPerUnit*(bitsPerUnit: LONGINT);
		BEGIN SELF.bitsPerUnit := bitsPerUnit
		END SetBitsPerUnit;

		PROCEDURE IsAligned*(): BOOLEAN;
		BEGIN RETURN ~fixed & (positionOrAlignment > 1)
		END IsAligned;

		PROCEDURE SetPositionOrAlignment*(isFixed: BOOLEAN; positionOrAlignment: LONGINT);
		BEGIN
			SELF.fixed := isFixed;
			SELF.positionOrAlignment := positionOrAlignment
		END SetPositionOrAlignment;

		PROCEDURE GetSize*(): LONGINT;
		BEGIN RETURN UnknownSize
		END GetSize;

		PROCEDURE SetFingerprint*(fingerprint: LONGINT);
		BEGIN SELF.fingerprint := fingerprint
		END SetFingerprint;

		(** change the type of a section **)
		PROCEDURE SetType*(type: SHORTINT);
		BEGIN SELF.type := type
		END SetType;

		PROCEDURE SetPriority*(priority: INTEGER);
		BEGIN SELF.priority := priority
		END SetPriority;

		PROCEDURE Dump*(w: Streams.Writer);
		BEGIN
			w.String(".");
			CASE type OF
			| CodeSection: w.String("code")
			| BodyCodeSection: w.String("bodycode")
			| InlineCodeSection: w.String("inlinecode")
			| VarSection: w.String("var");
			| ConstSection: w.String("const");
			| InitCodeSection: w.String("initcode");
			ELSE
				w.String("UNDEFINED")
			END;
			w.String(" ");
			DumpName(w);

			(* positional restrictions *)
			IF fixed THEN
				w.String(" fixed="); w.Int(positionOrAlignment, 0)
			ELSIF positionOrAlignment > 1 THEN
				w.String(" aligned="); w.Int(positionOrAlignment, 0)
			END;

			IF priority # 0 THEN w.String(" priority="); w.Int(priority,0) END;

			IF fingerprint # 0 THEN w.String(" fingerprint="); w.Int(fingerprint, 0) END;

			IF bitsPerUnit # UnknownSize THEN w.String(" unit="); w.Int(bitsPerUnit, 0) END;

			(* note: this information is actually redundant *)
			IF GetSize() # UnknownSize THEN w.String(" size="); w.Int(GetSize(), 0) END;

			w.Update
		END Dump;

		PROCEDURE DumpName*(w: Streams.Writer);
		BEGIN
			Basic.WriteSegmentedName(w,name);
		END DumpName;

	END Section;

	CommentStr* = POINTER TO ARRAY OF CHAR;
	Comment* = OBJECT
		VAR str-: CommentStr; strLen: LONGINT; pos-: LONGINT; nextComment-: Comment;

		PROCEDURE &Init*(pos: LONGINT);
		BEGIN
			SELF.pos := pos;
			NEW(str,32); strLen := 0;
			str[0] := 0X;
		END Init;

		PROCEDURE Append(CONST buf: ARRAY OF CHAR;  ofs, len: LONGINT);

			PROCEDURE Resize(newLen: LONGINT);
			VAR new: CommentStr; i: LONGINT;
			BEGIN
				NEW(new,newLen);
				FOR i := 0 TO strLen-1 DO
					new[i] := str[i]
				END;
				str := new
			END Resize;

		BEGIN
			INC(len,ofs);
			ASSERT(LEN(buf) >= len);
			WHILE (ofs < len) & (buf[ofs] # 0X) DO
				IF LEN(str) <= strLen THEN Resize(2*strLen) END;
				str[strLen] := buf[ofs];
				INC(ofs); INC(strLen);
			END;
			IF LEN(str) <= strLen THEN Resize(2*strLen) END;
			str[strLen] := 0X;
		END Append;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR i: LONGINT;ch: CHAR; newln: BOOLEAN;
		BEGIN
			IF w IS Basic.Writer THEN w(Basic.Writer).BeginComment; w(Basic.Writer).IncIndent; END;
			w.String("; ");
			i := 0; ch := str[i]; newln := FALSE;
			WHILE(ch#0X) DO
				IF (ch = 0DX) OR (ch = 0AX) THEN newln := TRUE
				ELSE
					IF newln THEN w.Ln; w.String(LineCommentStart); newln := FALSE;  END;
				 	w.Char(ch);
				 END;
				INC(i); ch := str[i];
			END;
			IF w IS Basic.Writer THEN w(Basic.Writer).EndComment; w(Basic.Writer).DecIndent;END;
			(*w.Update;*)
		END Dump;

	END Comment;

	GetPCProcedure=PROCEDURE{DELEGATE}(): LONGINT;

	CommentWriter*= OBJECT (Streams.Writer)
	VAR
		firstComment-,lastComment-: Comment; comments-: LONGINT;
		getPC: GetPCProcedure;

		PROCEDURE AppendToLine*( CONST buf: ARRAY OF CHAR;  ofs, len: LONGINT; propagate: BOOLEAN;  VAR res: LONGINT );
		VAR pos: LONGINT;
		BEGIN
			IF len = 0 THEN RETURN END;
			pos := getPC();
			IF lastComment = NIL THEN
				NEW(lastComment,pos); firstComment := lastComment;
			ELSIF (lastComment.pos # pos) THEN
				NEW(lastComment.nextComment,pos);
				lastComment := lastComment.nextComment;
			END;
			lastComment.Append(buf,ofs,len)
		END AppendToLine;

		PROCEDURE Ln;
		BEGIN
			Ln^;
			(*Update;*)
		END Ln;

		PROCEDURE Reset*;
		BEGIN
			firstComment := NIL; lastComment := NIL; comments := 0;
			Reset^;
		END Reset;

		PROCEDURE & InitCommentWriter*(getPC: GetPCProcedure);
		BEGIN
			SELF.getPC := getPC;
			InitWriter(AppendToLine,256);
			firstComment := NIL; lastComment := NIL; comments := 0;
		END InitCommentWriter;

	END CommentWriter;

	SectionLookup = OBJECT(Basic.HashTable); (* SyntaxTree.Symbol _> Symbol *)
	VAR

		PROCEDURE GetSection(symbol: SyntaxTree.Symbol):Section;
		VAR p: ANY;
		BEGIN
			p := Get(symbol);
			IF p # NIL THEN
				ASSERT(p(Section).symbol = symbol);
				RETURN p(Section);
			ELSE
				RETURN NIL
			END;
		END GetSection;

		PROCEDURE PutSection(symbol: SyntaxTree.Symbol; section: Section);
		BEGIN
			Put(symbol,section);
		END PutSection;

	END SectionLookup;

	SectionNameLookup = OBJECT(Basic.HashTableSegmentedName); (* SyntaxTree.Symbol _> Symbol *)

		PROCEDURE GetSection(CONST name: Basic.SegmentedName):Section;
		VAR p: ANY;
		BEGIN
			p := Get(name);
			IF p # NIL THEN RETURN p(Section) ELSE RETURN NIL END;
		END GetSection;

		PROCEDURE PutSection(CONST name:Basic.SegmentedName; section: Section);
		BEGIN
			Put(name, section);
		END PutSection;

	END SectionNameLookup;

	(** a list of sections
	note: a section may be part of multiple lists in this implementation
	**)
	SectionList* = OBJECT(Basic.List)
	VAR
		lookup: SectionLookup;
		lookupName: SectionNameLookup;

		PROCEDURE & InitListOfSections*;
		BEGIN
			NEW(lookup, 128);
			NEW(lookupName, 128);
			InitList(128) (* initializer of general list *)
		END InitListOfSections;

		PROCEDURE GetSection*(index: LONGINT): Section;
		VAR
			any: ANY;
		BEGIN
			any := Get(index);
			RETURN any(Section)
		END GetSection;

		PROCEDURE SetSection*(index: LONGINT; section: Section);
		BEGIN
			Set(index, section)
		END SetSection;

		(* note: this procedure cannot be called "Add" as it was the case in the old section list implementation *)
		PROCEDURE AddSection*(section: Section);
		BEGIN
			(* assert that the section is not already present *)
			ASSERT((FindBySymbol(section.symbol) = NIL) & (FindByName(section.name) = NIL));

			IF section.symbol # NIL THEN (* special case, may not be added to lookup list *)
				lookup.PutSection(section.symbol, section)
			END;
			IF section.name[0] >= 0 THEN
				lookupName.PutSection(section.name, section);
			END;
			Add(section)
		END AddSection;

		(** finds a section with a certain AST symbol **)
		PROCEDURE FindBySymbol*(CONST symbol: SyntaxTree.Symbol): Section;
		BEGIN
			IF symbol = NIL THEN
				RETURN NIL
			ELSE
				RETURN lookup.GetSection(symbol)
			END
		END FindBySymbol;

		(** finds a section with a certain name **)
		PROCEDURE FindByName*(CONST name: Basic.SegmentedName): Section;
		BEGIN
			RETURN lookupName.GetSection(name)
		END FindByName;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR
			i: LONGINT;
			section: Section;
		BEGIN
			FOR i := 0 TO Length() - 1 DO
				section := GetSection(i);
				section.Dump(w); w.Ln
			END;
		END Dump;
	END SectionList;

	NameEntry = POINTER TO RECORD
		name: SyntaxTree.IdentifierString;
	END;

	(* TODO: efficient implementation using hash table *)
	NameList* = OBJECT(Basic.List)
		PROCEDURE AddName*(CONST moduleName: ARRAY OF CHAR);
		VAR entry: NameEntry;
		BEGIN
			NEW(entry);
			COPY(moduleName, entry.name);
			Add(entry)
		END AddName;

		PROCEDURE GetName*(index: LONGINT): SyntaxTree.IdentifierString;
		VAR any: ANY;
		BEGIN
			any := Get(index);
			ASSERT(any IS NameEntry);
			RETURN any(NameEntry).name
		END GetName;

		PROCEDURE ContainsName*(name: SyntaxTree.IdentifierString): BOOLEAN;
		VAR i: LONGINT;
		BEGIN
			FOR i := 0 TO Length() - 1 DO
				IF name = GetName(i) THEN RETURN TRUE END
			END;
			RETURN FALSE
		END ContainsName;
	END NameList;

	(** output of (intermediate) code generation **)
	Module* = OBJECT (Formats.GeneratedModule)
	VAR
		allSections-: SectionList;
		importedSections-: SectionList; (* necessary for binary object file format, for reference to symbol *)

		platformName-: SyntaxTree.IdentifierString;
		imports-: NameList;

		PROCEDURE & Init*(module: SyntaxTree.Module; system: Global.System);
		BEGIN
			Init^(module,system);
			NEW(allSections);
			NEW(importedSections);
			NEW(imports, 128);
		END Init;

		(*
		PROCEDURE SetSections*(sections: SectionList);
		BEGIN SELF.allSections := sections
		END SetSections;
		*)

		PROCEDURE SetImports*(imports: NameList);
		BEGIN SELF.imports := imports
		END SetImports;

		PROCEDURE SetPlatformName*(CONST platformName: ARRAY OF CHAR);
		BEGIN COPY(platformName, SELF.platformName)
		END SetPlatformName;

		PROCEDURE Dump*(w: Streams.Writer);
		VAR
			dump: Basic.Writer;
			name: SyntaxTree.IdentifierString;
			i: LONGINT;
		BEGIN
			dump := Basic.GetWriter(w);

			(* dump module directive *)
			dump.String(".module ");
			dump.String(moduleName); dump.Ln;
			dump.Ln;

			(* dump platform directive *)
			IF platformName # "" THEN
				dump.String(".platform ");
				dump.String(platformName); dump.Ln;
				dump.Ln
			END;

			(* dump imports directive *)
			IF imports.Length() > 0 THEN
				dump.String(".imports ");
				FOR i := 0 TO imports.Length() - 1 DO
					IF i # 0 THEN dump.String(", ") END;
					name := imports.GetName(i);
					IF name = "" THEN
						dump.String("<import failed>")
					ELSE
						dump.String(name)
					END
				END;
				dump.Ln; dump.Ln
			END;

			(* dump all sections *)
			allSections.Dump(w)
		END Dump;

	END Module;

	PROCEDURE DumpFiltered*(w: Streams.Writer; module: Module; CONST filter: ARRAY OF CHAR);
	VAR
		i: LONGINT;
		section: Section;
		name: ObjectFile.SectionName;
	BEGIN
		FOR i := 0 TO module.allSections.Length() - 1 DO
			section := module.allSections.GetSection(i);
			ObjectFile.SegmentedNameToString(section.name,name);
			IF Strings.Match(filter, name) THEN section.Dump(w); w.Ln; END
		END
	END DumpFiltered;

	PROCEDURE NewCommentWriter*(getPC: GetPCProcedure): CommentWriter;
	VAR c: CommentWriter;
	BEGIN
		NEW(c,getPC); RETURN c
	END NewCommentWriter;

END FoxSections.
