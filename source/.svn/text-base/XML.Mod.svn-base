MODULE XML; (** AUTHOR "swalthert"; PURPOSE "XML base"; *)

IMPORT
	Streams, Strings, UTF8Strings, Modules, DynamicStrings, Objects := XMLObjects, KernelLog;

CONST
	Ok* = 0;
	InvalidString* = 1;
	BufferError* = 2;

	Tab = DynamicStrings.Tab;
	Space = 20X;

TYPE

	String* = Strings.String;

TYPE

	Content* = OBJECT
	VAR
		pos: LONGINT;
		previous, next : Content;

		PROCEDURE &Init*;
		BEGIN
			pos := 0;
			previous := NIL; next := NIL;
		END Init;

		PROCEDURE GetPos*(): LONGINT;
		BEGIN
			RETURN pos
		END GetPos;

		PROCEDURE SetPos*(pos : LONGINT);
		BEGIN
			SELF.pos := pos
		END SetPos;

		(** write the content to stream w. level is the current hierarchy level. used for formatting *)
		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		END Write;

	END Content;

	NameContent* = OBJECT (Content)
	VAR
		name: String;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			name := StrNoName;
		END Init;

		PROCEDURE GetName*(): String;
		BEGIN
			RETURN name
		END GetName;

		PROCEDURE SetName*(CONST name: ARRAY OF CHAR);
		BEGIN
			SELF.name := NewString(name)
		END SetName;

		PROCEDURE SetNameAsString*(name : String);
		BEGIN
			IF (name # NIL) THEN
				SELF.name := name;
			ELSE
				SELF.name := StrNoName;
			END;
		END SetNameAsString;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		BEGIN
			w.String(name^)
		END Write;

	END NameContent;

	Container* = OBJECT (Content)
	VAR
		first, last : Content;
		nofContents : LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			first := NIL; last := NIL;
			nofContents := 0;
		END Init;

		PROCEDURE RemoveContent0(c: Content): BOOLEAN;
		VAR cur : Content;
		BEGIN
			(*ASSERT(c # NIL);*)
			IF c=NIL THEN RETURN FALSE END;(*PH 12/13*)
			IF (first # NIL) THEN
				IF (first = c) THEN
					IF (first.next # NIL) THEN first.next.previous := NIL; END;
					first := first.next;
					IF (last = c) THEN last := NIL; ASSERT(first = NIL); END;
					c.next := NIL; c.previous := NIL;
					RETURN TRUE
				ELSE
					cur := first;
					WHILE (cur.next # NIL) & (cur.next # c) DO cur := cur.next; END;
					IF (cur.next # NIL) THEN
						IF (cur.next.next # NIL) THEN cur.next.next.previous := cur; END;
						cur.next := cur.next.next;
						IF (last = c) THEN last := cur; ASSERT(cur.next = NIL); END;
						c.next := NIL; c.previous := NIL;
						RETURN TRUE
					END;
				END;
			END;
			RETURN FALSE
		END RemoveContent0;

		(* Move this after previous. If previous = NIL then move this to end *)
		PROCEDURE MoveContentAfter*(this, previous: Content);
		VAR current: Content;
		BEGIN{EXCLUSIVE}
			IF RemoveContent0(this) THEN
				IF (previous = NIL) OR (previous = last) THEN (* insert as last *)
					IF last = NIL THEN
						first := this; last := this
					ELSE
						last.next := this;
						this.previous := last;
						last := this;
					END;
				ELSE
					this.next := previous.next;
					this.next.previous := this;
					previous.next := this;
					this.previous := previous;
				END
			END;
		END MoveContentAfter;

		(* Move this before next. If next = NIL then move this to front *)
		PROCEDURE MoveContentBefore*(this, next: Content);
		VAR current: Content;
		BEGIN{EXCLUSIVE}
			IF RemoveContent0(this) THEN
				IF (next = NIL) OR (next = first) THEN (* insert as first *)
					IF first = NIL THEN
						first := this; last := this
					ELSE
						this.next := first;
						first.previous := this;
						first := this;
					END;
				ELSE
					next.previous.next := this;
					this.previous := next.previous;
					this.next := next;
					next.previous := this;
				END;
			END;
		END MoveContentBefore;

		PROCEDURE AddContent*(c: Content);
		BEGIN {EXCLUSIVE}
			ASSERT((c # NIL) & (c.next = NIL) & (c.previous = NIL)); (* may not be in more than one list! *)
			IF (first = NIL) THEN
				ASSERT(last = NIL);
				first := c; last := c;
			ELSE
				ASSERT(last # NIL);
				last.next := c;
				c.previous := last;
				last := c;
			END;
			ASSERT((first # NIL) & (last # NIL));
			INC(nofContents);
		END AddContent;

		PROCEDURE RemoveContent*(c: Content);
		VAR b: BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF RemoveContent0(c) THEN DEC(nofContents) END
		END RemoveContent;

		PROCEDURE GetContents*(): Objects.Enumerator;
		VAR c : Content; array : Objects.PTRArray; enumerator : Objects.ArrayEnumerator; i : LONGINT;
		BEGIN {EXCLUSIVE}
			NEW(array, nofContents);
			c := first;
			FOR i := 0 TO nofContents - 1 DO
				array[i] := c;
				c := c.next;
			END;
			NEW(enumerator, array);
			RETURN enumerator;
		END GetContents;

		PROCEDURE GetNumberOfContents*(): LONGINT;
		BEGIN
			RETURN nofContents;
		END GetNumberOfContents;

		PROCEDURE GetFirst*() : Content;
		BEGIN
			RETURN first;
		END GetFirst;

		PROCEDURE GetLast*() : Content;
		BEGIN
			RETURN last;
		END GetLast;

		PROCEDURE GetNext*(content : Content) : Content;
		BEGIN
			ASSERT(content # NIL);
			RETURN content.next;
		END GetNext;

		PROCEDURE GetPrevious*(content : Content) : Content;
		BEGIN
			ASSERT(content # NIL);
			RETURN content.previous;
		END GetPrevious;

	END Container;

TYPE

	Document* = OBJECT (Container)
	VAR
		xmldecl: XMLDecl;
		dtd: DocTypeDecl;
		root: Element;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			xmldecl := NIL;
			NEW(dtd);
			root := NIL;
		END Init;

		PROCEDURE GetXMLDecl*(): XMLDecl;
		BEGIN
			RETURN xmldecl
		END GetXMLDecl;

		PROCEDURE GetDocTypeDecl*(): DocTypeDecl;
		BEGIN
			RETURN dtd
		END GetDocTypeDecl;

		PROCEDURE GetRoot*(): Element;
		BEGIN
			RETURN root
		END GetRoot;

		PROCEDURE AddContent(c: Content);
		BEGIN
			IF (c IS XMLDecl) & (xmldecl = NIL) THEN xmldecl := c(XMLDecl)
			ELSIF (c IS DocTypeDecl) THEN dtd := c(DocTypeDecl)
			ELSIF (c IS Element) & (root = NIL) THEN root := c(Element); root.SetDocument(SELF)
			END;
			AddContent^(c)
		END AddContent;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR e: Objects.Enumerator; c: ANY;
		BEGIN
			e := GetContents();
			WHILE e.HasMoreElements() DO
				c := e.GetNext();
				c(Content).Write(w, context, level + 1)
			END
		END Write;

	END Document;

	TextDecl* = OBJECT (Content)
	VAR
		version, encoding: String;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			version := NIL; encoding := NIL;
		END Init;

		PROCEDURE GetVersion*(): String;
		BEGIN
			RETURN version
		END GetVersion;

		PROCEDURE SetVersion*(CONST version: ARRAY OF CHAR);
		BEGIN
			SELF.version := NewString(version)
		END SetVersion;

		PROCEDURE GetEncoding*(): String;
		BEGIN
			RETURN encoding
		END GetEncoding;

		PROCEDURE SetEncoding*(CONST encoding: ARRAY OF CHAR);
		BEGIN
			SELF.encoding := NewString(encoding)
		END SetEncoding;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		BEGIN
			w.String('<?xml version="'); w.String(version^);
			IF encoding # NIL THEN w.String('" encoding="'); w.String(encoding^) END;
			w.String('"?>'); NewLine(w, level)
		END Write;

	END TextDecl;

	XMLDecl* = OBJECT (TextDecl)
	VAR
		standalone: BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			standalone := FALSE;
		END Init;

		PROCEDURE IsStandalone*(): BOOLEAN;
		BEGIN
			RETURN standalone
		END IsStandalone;

		PROCEDURE SetStandalone*(standalone: BOOLEAN);
		BEGIN
			SELF.standalone := standalone
		END SetStandalone;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		BEGIN
			w.String('<?xml version="'); w.String(version^);
			IF encoding # NIL THEN w.String('" encoding="'); w.String(encoding^) END;
			w.String('" standalone="');
			IF standalone THEN w.String("yes") ELSE w.String("no") END;
			w.String('"?>'); NewLine(w, level)
		END Write;

	END XMLDecl;

	DocTypeDecl* = OBJECT (NameContent)
	VAR
		elementDecls, notationDecls, generalEntities, parameterEntities: Objects.Dictionary;
		allMarkupDecls: Objects.Collection;
		externalSubset: EntityDecl;

		PROCEDURE & Init*;
		VAR (* ed: EntityDecl; *) arrDict: Objects.ArrayDict; arrColl: Objects.ArrayCollection;
		BEGIN
			Init^;
			NEW(arrDict); elementDecls := arrDict;
			NEW(arrDict); notationDecls := arrDict;
			NEW(arrDict); generalEntities := arrDict;
			NEW(arrDict); parameterEntities := arrDict;
			NEW(arrColl); allMarkupDecls := arrColl;

			externalSubset := NIL;

			(* add predefined entities *)
(*			NEW(ed); NEW(ed.name, 3); ed.name[0] := 'l'; ed.name[1] := 't'; ed.name[2] := 0X;
			NEW(ed.value, 10); COPY("&#38;#60;", ed.value^); ed.type := GeneralEntity; AddMarkupDecl(ed);
			NEW(ed); NEW(ed.name, 3); ed.name[0] := 'g'; ed.name[1] := 't'; ed.name[2] := 0X;
			NEW(ed.value, 10); COPY("&#62;", ed.value^); ed.type := GeneralEntity; AddMarkupDecl(ed);
			NEW(ed); NEW(ed.name, 4); ed.name[0] := 'a'; ed.name[1] := 'm'; ed.name[2] := 'p'; ed.name[3] := 0X;
			NEW(ed.value, 10); COPY("&#38;#38;", ed.value^); ed.type := GeneralEntity; AddMarkupDecl(ed);
			NEW(ed); NEW(ed.name, 5); ed.name[0] := 'a'; ed.name[1] := 'p'; ed.name[2] := 'o'; ed.name[3] := 's'; ed.name[4] := 0X;
			NEW(ed.value, 10); COPY("&#39;", ed.value^); ed.type := GeneralEntity; AddMarkupDecl(ed);
			NEW(ed); NEW(ed.name, 5); ed.name[0] := 'q'; ed.name[1] := 'u'; ed.name[2] := 'o'; ed.name[3] := 't'; ed.name[4] := 0X;
			NEW(ed.value, 10); COPY("&#34;", ed.value^); ed.type := GeneralEntity; AddMarkupDecl(ed)
*)
		END Init;

		PROCEDURE AddMarkupDecl*(c: Content);
		BEGIN
			IF c IS ElementDecl THEN
				elementDecls.Add(c(ElementDecl).name^, c); allMarkupDecls.Add(c)
			ELSIF (c IS EntityDecl) & (c(EntityDecl).type = GeneralEntity) THEN
				generalEntities.Add(c(EntityDecl).name^, c); allMarkupDecls.Add(c)
			ELSIF (c IS EntityDecl) & (c(EntityDecl).type = ParameterEntity) THEN
				parameterEntities.Add(c(EntityDecl).name^, c); allMarkupDecls.Add(c)
			ELSIF c IS NotationDecl THEN
				notationDecls.Add(c(NotationDecl).name^, c); allMarkupDecls.Add(c)
			ELSIF (c IS ProcessingInstruction) OR (c IS Comment) THEN
				allMarkupDecls.Add(c)
			END
		END AddMarkupDecl;

		PROCEDURE GetElementDecl*(CONST name: ARRAY OF CHAR): ElementDecl;
		VAR p: ANY;
		BEGIN
			p := elementDecls.Get(name);
			IF p # NIL THEN RETURN p(ElementDecl)
			ELSE RETURN NIL
			END
		END GetElementDecl;

		PROCEDURE GetNotationDecl*(CONST name: ARRAY OF CHAR): NotationDecl;
		VAR p: ANY;
		BEGIN
			p := elementDecls.Get(name);
			IF p # NIL THEN RETURN p(NotationDecl)
			ELSE RETURN NIL
			END
		END GetNotationDecl;

		PROCEDURE GetEntityDecl*(CONST name: ARRAY OF CHAR; type: SHORTINT): EntityDecl;
		VAR p: ANY;
		BEGIN
			p := NIL;
			IF type = GeneralEntity THEN p := generalEntities.Get(name)
			ELSIF type = ParameterEntity THEN p := parameterEntities.Get(name)
			END;
			IF p # NIL THEN RETURN p(EntityDecl)
			ELSE RETURN NIL
			END
		END GetEntityDecl;

		PROCEDURE GetExternalSubset*(): EntityDecl;
		BEGIN
			RETURN externalSubset
		END GetExternalSubset;

		PROCEDURE SetExternalSubset*(externalSubset: EntityDecl);
		BEGIN
			SELF.externalSubset := externalSubset
		END SetExternalSubset;

		PROCEDURE Write*(w: Streams.Writer; context: ANY;  level : LONGINT);
		VAR e: Objects.Enumerator; p: ANY; s: String;
		BEGIN
			w.String("<!DOCTYPE "); w.String(name^);
			IF externalSubset # NIL THEN
				s := externalSubset.GetPublicId();
				IF s # NIL THEN
					w.String(' PUBLIC "'); w.String(s^); w.String('" "');
				ELSE
					w.String(' SYSTEM "')
				END;
				s := externalSubset.GetSystemId();
				w.String(s^); w.Char('"')
			END;
			e := allMarkupDecls.GetEnumerator();
			IF e.HasMoreElements() THEN
				w.String(" ["); NewLine(w, level + 1);
				WHILE e.HasMoreElements() DO
					p := e.GetNext(); p(Content).Write(w, context, level + 1)
				END;
				w.String("]")
			END;
			w.Char('>'); NewLine(w, level)
		END Write;

	END DocTypeDecl;

	NotationDecl* = OBJECT (NameContent)
	VAR
		systemId, publicId: String;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			systemId := NIL; publicId := NIL;
		END Init;

		PROCEDURE GetSystemId*(): String;
		BEGIN
			RETURN systemId
		END GetSystemId;

		PROCEDURE SetSystemId*(CONST systemId: ARRAY OF CHAR);
		BEGIN
			SELF.systemId := NewString(systemId)
		END SetSystemId;

		PROCEDURE GetPublicId*(): String;
		BEGIN
			RETURN publicId
		END GetPublicId;

		PROCEDURE SetPublicId*(CONST publicId: ARRAY OF CHAR);
		BEGIN
			SELF.publicId := NewString(publicId)
		END SetPublicId;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		BEGIN
			w.String("<!NOTATION "); w.String(name^);
			IF publicId # NIL THEN
				w.String(' PUBLIC "'); w.String(publicId^); w.String('" "');
				IF systemId # NIL THEN w.String(systemId^); w.Char('"') END
			ELSE
				w.String(' SYSTEM "'); w.String(systemId^); w.Char('"')
			END;
			w.Char('>'); NewLine(w, level)
		END Write;

	END NotationDecl;

CONST
	(** EntityDecl.SetType *)
	GeneralEntity* = 0;
	ParameterEntity* = 1;

TYPE
	EntityDecl* = OBJECT (NotationDecl)
	VAR
		value, notationName: String;
		type: SHORTINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			value := NIL; notationName := NIL;
			type := GeneralEntity;
		END Init;

		PROCEDURE GetType*(): SHORTINT;
		BEGIN
			RETURN type
		END GetType;

		PROCEDURE SetType*(type: SHORTINT);
		BEGIN
			SELF.type := type
		END SetType;

		PROCEDURE GetValue*(): String;
		BEGIN
			RETURN value
		END GetValue;

		PROCEDURE SetValue*(CONST value: ARRAY OF CHAR);
		BEGIN
			SELF.value := NewString(value)
		END SetValue;

		PROCEDURE GetNotationName*(): String;
		BEGIN
			RETURN notationName
		END GetNotationName;

		PROCEDURE SetNotationName*(CONST notationName: ARRAY OF CHAR);
		BEGIN
			SELF.notationName := NewString(notationName)
		END SetNotationName;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		BEGIN
			w.String("<!ENTITY ");
			IF type = ParameterEntity THEN w.String("% ") END;
			w.String(name^);
			IF value # NIL THEN
				w.String(' "'); w.String(value^); w.Char('"')
			ELSE
				IF publicId # NIL THEN
					w.String(' PUBLIC "'); w.String(publicId^); w.String('" "');
					IF systemId # NIL THEN w.String(systemId^); w.Char('"') END
				ELSE
					w.String(' SYSTEM "'); w.String(systemId^); w.Char('"')
				END;
				IF (type = GeneralEntity) & (notationName # NIL) THEN
					w.String(' NDATA '); w.String(notationName^)
				END
			END;
			w.Char('>'); NewLine(w, level)
		END Write;

	END EntityDecl;

CONST
	(** ElementDecl.SetContentType *)
	Any* = 0;	(** 'ANY' *)
	Empty* = 1;	(** 'EMPTY' *)
	ElementContent* = 2;	(** children *)
	MixedContent* = 3;	(** Mixed *)

TYPE
	ElementDecl* = OBJECT (NameContent)
	VAR
		contentType: SHORTINT;
		content: CollectionCP;	(* for contentType = Mixed or contentType = Element *)
		attributeDecls: Objects.Dictionary;

		PROCEDURE & Init*;
		VAR arrDict: Objects.ArrayDict;
		BEGIN
			Init^;
			contentType := Any;
			content := NIL;
			NEW(arrDict); attributeDecls := arrDict
		END Init;

		PROCEDURE GetContentType*(): SHORTINT;
		BEGIN
			RETURN contentType
		END GetContentType;

		PROCEDURE SetContentType*(contentType: SHORTINT);
		BEGIN
			SELF.contentType := contentType
		END SetContentType;

		PROCEDURE GetContent*(): CollectionCP;
		BEGIN
			RETURN content
		END GetContent;

		PROCEDURE SetContent*(lcp: CollectionCP);
		BEGIN
			content := lcp
		END SetContent;

		PROCEDURE GetAttributeDecl*(CONST name: ARRAY OF CHAR): AttributeDecl;
		VAR nc: ANY;
		BEGIN
			nc := attributeDecls.Get(name);
			IF nc # NIL THEN RETURN nc (AttributeDecl) ELSE RETURN NIL END
		END GetAttributeDecl;

		PROCEDURE GetAttributeDecls*(): Objects.Enumerator;
		BEGIN
			RETURN attributeDecls.GetEnumerator()
		END GetAttributeDecls;

		PROCEDURE AddAttributeDecl*(attributeDecl: AttributeDecl);
		BEGIN
			attributeDecls.Add(attributeDecl.name^, attributeDecl)
		END AddAttributeDecl;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR e: Objects.Enumerator; p: ANY;
		BEGIN
			w.String("<!ELEMENT "); w.String(name^); w.Char(Space);
			IF contentType = Empty THEN
				w.String("EMPTY")
			ELSIF contentType = Any THEN
				w.String("ANY")
			ELSIF content # NIL THEN
				content.Write(w, context, level + 1)
			END;
			w.Char('>'); NewLine(w, level);
			e := GetAttributeDecls();
			IF e.HasMoreElements() THEN
				w.String("<!ATTLIST "); w.String(name^); NewLine(w, level+1);
				WHILE e.HasMoreElements() DO
					p := e.GetNext(); p(Content).Write(w, context, level + 1)
				END;
				w.Char('>'); NewLine(w, level)
			END
		END Write;

	END ElementDecl;

CONST
	(** ContentParticle.SetOccurence *)
	ZeroOrOnce* = 0;	(** '?' *)
	ZeroOrMore* = 1;	(** '*' *)
	Once* = 2;	(** nothing *)
	OnceOrMore* = 3;	(** '+' *)

TYPE
	ContentParticle* = OBJECT (Content)
	VAR
		occurence: SHORTINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			occurence := ZeroOrOnce;
		END Init;

		PROCEDURE GetOccurence*(): SHORTINT;
		BEGIN
			RETURN occurence
		END GetOccurence;

		PROCEDURE SetOccurence*(occ: SHORTINT);
		BEGIN
			occurence := occ
		END SetOccurence;

		PROCEDURE GetOccurenceChar(): CHAR;
		BEGIN
			CASE occurence OF
			| ZeroOrOnce: RETURN '?'
			| ZeroOrMore: RETURN '*'
			| Once: RETURN 0X
			| OnceOrMore: RETURN '+'
			END
		END GetOccurenceChar;

	END ContentParticle;

	NameContentParticle* = OBJECT (ContentParticle)
	VAR
		name: String;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			name := NIL;
		END Init;

		PROCEDURE GetName*(): String;
		BEGIN
			RETURN name
		END GetName;

		PROCEDURE SetName*(CONST name: ARRAY OF CHAR);
		BEGIN
			SELF.name := NewString(name)
		END SetName;

		PROCEDURE SetNameAsString*(name : String);
		BEGIN
			SELF.name := name;
		END SetNameAsString;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR ch: CHAR;
		BEGIN
			w.String(name^);
			ch := GetOccurenceChar(); IF ch # 0X THEN w.Char(ch) END
		END Write;

	END NameContentParticle;

CONST
	(** CollectionCP.SetType *)
	Choice* = 1;
	Sequence* = 2;

TYPE
	CollectionCP* = OBJECT (ContentParticle)
	VAR
		children: Objects.Collection;
		type: SHORTINT;

		PROCEDURE & Init*;
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			Init^;
			NEW(arrColl); children := arrColl;
			type := 0;
		END Init;

		PROCEDURE GetType*(): SHORTINT;
		BEGIN
			RETURN type
		END GetType;

		PROCEDURE SetType*(type: SHORTINT);
		BEGIN
			SELF.type := type
		END SetType;

		PROCEDURE GetChildren*(): Objects.Enumerator;
		BEGIN
			RETURN children.GetEnumerator()
		END GetChildren;

		PROCEDURE AddChild*(cp: ContentParticle);
		BEGIN
			children.Add(cp)
		END AddChild;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR e: Objects.Enumerator; ch: CHAR; p: ANY;
		BEGIN
			e := GetChildren();
			p := e.GetNext();
			w.Char('(');
			p(Content).Write(w, context, level + 1);
			WHILE e.HasMoreElements() DO
				p := e.GetNext();
				IF type = Choice THEN w.String(" | ")
				ELSIF type = Sequence THEN w.String(", ")
				END;
				p(Content).Write(w, context, level + 1)
			END;
			w.Char(')');
			ch := GetOccurenceChar(); IF ch # 0X THEN w.Char(ch) END
		END Write;

	END CollectionCP;

CONST
	(** AttributeDecl.SetType *)
	CData* = 0;	(** CDATA *)
	Id* = 1;	(** ID *)
	IdRef* = 2;	(** IDREF *)
	IdRefs* = 3;	(** IDREFS *)
	Entity* = 4;	(** ENTITY *)
	Entities* = 5;	(** ENTITIES *)
	NmToken* = 6;	(** NMTOKEN *)
	NmTokens* = 7;	(** NMTOKENS *)
	Notation* = 8;	(** NOTATION *)
	Enumeration* = 9;	(** Enumeration *)

TYPE
	AttributeDecl* = OBJECT (NameContent)
	VAR
		defaultValue: String;
		type: SHORTINT;
		allowedValues: Objects.Dictionary;
		required: BOOLEAN;

		PROCEDURE &Init*;
		VAR arrDict: Objects.ArrayDict;
		BEGIN
			Init^;
			defaultValue := NIL;
			type := CData;
			NEW(arrDict); allowedValues := arrDict;
			required := FALSE;
		END Init;

		PROCEDURE GetDefaultValue*(): String;
		BEGIN
			RETURN defaultValue
		END GetDefaultValue;

		PROCEDURE SetDefaultValue*(CONST defaultValue: ARRAY OF CHAR);
		BEGIN
			SELF.defaultValue := NewString(defaultValue)
		END SetDefaultValue;

		PROCEDURE GetType*(): SHORTINT;
		BEGIN
			RETURN type
		END GetType;

		PROCEDURE SetType*(type: SHORTINT);
		BEGIN
			SELF.type := type
		END SetType;

		(** Collection of NameContents *)
		PROCEDURE GetAllowedValues*(): Objects.Enumerator;
		BEGIN
			RETURN allowedValues.GetEnumerator()
		END GetAllowedValues;

		PROCEDURE AddAllowedValue*(CONST value: ARRAY OF CHAR);
		VAR nameContent: NameContent;
		BEGIN
			NEW(nameContent); nameContent.SetName(value);
			allowedValues.Add(value, nameContent)
		END AddAllowedValue;

		PROCEDURE IsRequired*(): BOOLEAN;
		BEGIN
			RETURN required
		END IsRequired;

		PROCEDURE SetRequired*(required: BOOLEAN);
		BEGIN
			SELF.required := required
		END SetRequired;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR e: Objects.Enumerator; p: ANY;
		BEGIN
			w.String(name^); w.Char(Space);
			CASE type OF
			| CData: w.String("CDATA")
			| Id: w.String("ID")
			| IdRef: w.String("IDREF")
			| IdRefs: w.String("IDREFS")
			| Entity: w.String("ENTITY")
			| Entities: w.String("ENTITIES")
			| NmToken: w.String("NMTOKEN")
			| NmTokens: w.String("NMTOKENS")
			| Notation: w.String("NOTATION")
			| Enumeration:
			END;
			IF type # Enumeration THEN w.Char(Space) END;
			IF (type = Notation) OR (type = Enumeration) THEN
				w.Char('('); e := GetAllowedValues();
				p := e.GetNext(); p(Content).Write(w, context, level + 1);
				WHILE e.HasMoreElements() DO
					w.Char('|'); p := e.GetNext(); p(Content).Write(w, context, level + 1)
				END;
				w.String(") ")
			END;
			IF required THEN
				IF defaultValue = NIL THEN w.String('#REQUIRED')
				ELSE w.String('#FIXED "'); w.String(defaultValue^); w.String('"')
				END
			ELSE
				IF defaultValue = NIL THEN w.String('#IMPLIED')
				ELSE w.String('"'); w.String(defaultValue^); w.String('"')
				END
			END;
			NewLine(w, level)
		END Write;

	END AttributeDecl;

TYPE
	CharReference* = OBJECT (Content)
	VAR
		code: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			code := 0;
		END Init;

		PROCEDURE SetCode*(code: LONGINT);
		BEGIN
			SELF.code := code
		END SetCode;

		PROCEDURE GetCode*(): LONGINT;
		BEGIN
			RETURN code
		END GetCode;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR codeArray: ARRAY 16 OF CHAR; codeStr: String;
		BEGIN
			DynamicStrings.IntToStr(code, codeArray);
			codeStr := NewString(codeArray);
			w.String('&#'); w.String(codeStr^); w.Char(';')
		END Write;

	END CharReference;

TYPE
	EntityRef* = OBJECT (NameContent)
	VAR
		decl: EntityDecl;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			decl := NIL;
		END Init;

		PROCEDURE GetEntityDecl*(): EntityDecl;
		BEGIN
			RETURN decl
		END GetEntityDecl;

		PROCEDURE SetDocument(document: Document);
		VAR dtd: DocTypeDecl;
		BEGIN
			dtd := document.GetDocTypeDecl();
			IF dtd # NIL THEN
				decl := dtd.GetEntityDecl(name^, GeneralEntity)
			END
		END SetDocument;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		BEGIN
			w.Char('&'); w.String(name^); w.Char(';')
		END Write;

	END EntityRef;

TYPE
	InternalEntityRef* = OBJECT (EntityRef)

		PROCEDURE GetValue*(): String;
		BEGIN
			IF decl # NIL THEN RETURN decl.value
			ELSE RETURN NIL
			END
		END GetValue;

	END InternalEntityRef;

TYPE
	ExternalEntityRef* = OBJECT (EntityRef)
	VAR
		coll: Objects.Collection;
		textDecl: TextDecl;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			coll := NIL;
			textDecl := NIL;
		END Init;

		PROCEDURE GetTextDecl*(): TextDecl;
		BEGIN
			RETURN textDecl
		END GetTextDecl;

		PROCEDURE GetContents*(): Objects.Enumerator;
		BEGIN
			IF IsParsed() THEN RETURN coll.GetEnumerator()
			ELSE RETURN NIL
			END
		END GetContents;

		PROCEDURE AddContent*(c: Content);
		VAR arrColl: Objects.ArrayCollection;
		BEGIN
			IF coll = NIL THEN NEW(arrColl); coll := arrColl END;
			IF c IS TextDecl THEN
				textDecl := c(TextDecl)
			END;
			coll.Add(c)
		END AddContent;

		PROCEDURE IsParsed*(): BOOLEAN;
		BEGIN
			RETURN coll # NIL
		END IsParsed;

		PROCEDURE GetIdElement(CONST name, id: ARRAY OF CHAR): Element;
		VAR contents: Objects.Enumerator; p: ANY; retElement: Element;
		BEGIN
			retElement := NIL;
			IF IsParsed() THEN
				contents := GetContents();
				WHILE contents.HasMoreElements() & (retElement = NIL) DO
					p := contents.GetNext();
					IF p IS Element THEN
						retElement := p(Element).GetIdElement(name, id)
					ELSIF p IS ExternalEntityRef THEN
						retElement := p(ExternalEntityRef).GetIdElement(name, id)
					END
				END
			END;
			RETURN retElement
		END GetIdElement;

	END ExternalEntityRef;

TYPE
	Chars* = OBJECT (Content)

		PROCEDURE GetStr*(): String;
		BEGIN
			RETURN NIL
		END GetStr;

		PROCEDURE GetLength*(): LONGINT;
		BEGIN
			RETURN 0
		END GetLength;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR s: String;
		BEGIN
			s := GetStr(); w.String(s^)
		END Write;

	END Chars;

TYPE
	ArrayChars* = OBJECT (Chars)
	VAR
		str: String;
		len: LONGINT;

		PROCEDURE &Init*;
		BEGIN
			str := NIL;
			len := 0;
		END Init;

		PROCEDURE GetStr(): String;
		BEGIN
			RETURN str
		END GetStr;

		PROCEDURE GetLength(): LONGINT;
		BEGIN
			RETURN len
		END GetLength;

		PROCEDURE SetStr*(CONST str: ARRAY OF CHAR);
		BEGIN
			SELF.str := NewString(str);
			len := DynamicStrings.StringLength(str)
		END SetStr;

		PROCEDURE SetStrAsString*(str : String);
		BEGIN
			SELF.str := str;
			len := DynamicStrings.StringLength(str^)
		END SetStrAsString;

	END ArrayChars;

	Comment* = OBJECT (ArrayChars)

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		BEGIN
			NewLine(w, level-1); w.String("<!--"); Write^(w, context, level); w.String("-->"); NewLine(w, level)
		END Write;

	END Comment;

TYPE
	CDataSect* = OBJECT (ArrayChars)

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR s : String; i, j : LONGINT; buf : ARRAY 4 OF CHAR;
		BEGIN
			w.String("<![CDATA[");
			s := GetStr(); COPY("   ", buf);

			IF (LEN(s^) < 3) THEN
				w.String(s^);
			ELSE
				buf[1] := s^[0];
				buf[2] := s^[1]; i := 2;
				WHILE (i < LEN(s^)) DO
					buf[0] := buf[1];
					buf[1] := buf[2];
					buf[2] := s^[i];
					INC(i);
					IF (buf = "]]>") THEN
						w.String("]]]]><![CDATA[>");
						IF ((i+2) < LEN(s^)) THEN
							buf[1] := s^[i]; INC(i);
							buf[2] := s^[i]; INC(i);
						ELSE
							j := 0;
							WHILE (i < LEN(s^)) DO
								buf[j] := s^[i]; INC(i); INC(j);
							END;
							buf[j] := 0X;
						END;
					ELSIF (i < LEN(s^)) THEN w.Char(buf[0]); END;
				END;
				w.String(buf);
			END;

			w.String("]]>"); NewLine(w, level)

		END Write;

	END CDataSect;

TYPE
	ProcessingInstruction* = OBJECT (Content)
	VAR
		target, instruction: String;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			target := NIL; instruction := NIL;
		END Init;

		PROCEDURE GetTarget*(): String;
		BEGIN
			RETURN target
		END GetTarget;

		PROCEDURE SetTarget*(CONST target: ARRAY OF CHAR);
		BEGIN
			SELF.target := NewString(target)
		END SetTarget;

		PROCEDURE GetInstruction*(): String;
		BEGIN
			RETURN instruction
		END GetInstruction;

		PROCEDURE SetInstruction*(CONST instruction: ARRAY OF CHAR);
		BEGIN
			SELF.instruction := NewString(instruction)
		END SetInstruction;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		BEGIN
			w.String("<?"); w.String(target^); w.Char(Space);
			w.String(instruction^); w.String("?>"); NewLine(w, level)
		END Write;

	END ProcessingInstruction;

TYPE
	Attribute* = OBJECT (NameContent)
	VAR
		value, elementName: String;
		document: Document;
		decl: AttributeDecl;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			value := NIL; elementName := NIL;
			document := NIL;
			decl := NIL;
		END Init;

		PROCEDURE SetDocument(document: Document; elementName: String);
		VAR dtd: DocTypeDecl; elementDecl: ElementDecl;
		BEGIN
			SELF.document := document;
			SELF.elementName := elementName;
			dtd := document.GetDocTypeDecl();
			IF dtd # NIL THEN
				elementDecl := dtd.GetElementDecl(elementName^);
				IF elementDecl # NIL THEN
					decl := elementDecl.GetAttributeDecl(name^);
					IF (decl # NIL) & ((value = NIL) OR ~IsAllowedValue(value^)) THEN
						value := decl.defaultValue
					END
				END
			END
		END SetDocument;

		PROCEDURE IsAllowedValue*(CONST value: ARRAY OF CHAR): BOOLEAN;
		BEGIN
			IF decl = NIL THEN
				RETURN TRUE
			ELSE
				CASE decl.GetType() OF
				| CData: RETURN TRUE
				| Id: RETURN document.root.GetIdElement(elementName^, value) = NIL
				| IdRef: RETURN TRUE
				| IdRefs: RETURN TRUE
				| Entity: RETURN TRUE
				| Entities: RETURN TRUE
				| NmToken: RETURN TRUE
				| NmTokens: RETURN TRUE
				| Notation:
					RETURN decl.allowedValues.Get(value) # NIL
				| Enumeration:
					RETURN decl.allowedValues.Get(value) # NIL
				ELSE
				END
			END
		END IsAllowedValue;

		PROCEDURE GetValue*(): String;
		BEGIN
			RETURN value
		END GetValue;

		PROCEDURE SetValue*(CONST value: ARRAY OF CHAR);
		BEGIN
			IF IsAllowedValue(value) THEN
				SELF.value := NewString(value)
			END
		END SetValue;

		PROCEDURE SetValueAsString*(value : String);
		BEGIN
			ASSERT(value # NIL);
			IF IsAllowedValue(value^) THEN
				SELF.value := value;
			END;
		END SetValueAsString;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		BEGIN
			IF value = NIL THEN KernelLog.String("NIL attribute "); KernelLog.Ln; RETURN END;
			w.Char(Space); w.String(name^);
			IF Strings.ContainsChar(value^, '"', FALSE) THEN
				w.String("='"); w.String(value^); w.Char("'")
			ELSE
				w.String('="'); w.String(value^); w.Char('"')
			END;
		END Write;

	END Attribute;

	TraverseProc* = PROCEDURE  {DELEGATE} (c: Content; data: ANY);

TYPE

	Element* = OBJECT (Container)
	VAR
		root, parent : Element;
		name: String; (* { name # NIL } *)
		document: Document;
		attributes : Attribute;
		idAttribute: Attribute;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			root := NIL; parent := NIL;
			name := StrNoName;
			document := NIL; attributes := NIL;
			idAttribute := NIL;
		END Init;

		PROCEDURE AddContent*(content: Content);
		BEGIN
			ASSERT(content # NIL);
			AddContent^(content);
			IF (content IS Element) THEN
				WITH content: Element DO
					IF root # NIL THEN content.root := root ELSE content.root := SELF; END;
					content.parent := SELF;
				END;
			END;
		END AddContent;

		PROCEDURE RemoveContent*(content : Content);
		BEGIN
			(*ASSERT(content # NIL);*)
			IF content=NIL THEN RETURN END; (*PH 12/13: removing nothing is logically correct *)
			RemoveContent^(content);
			IF (content IS Element) THEN
				IF (content(Element).parent = SELF) THEN
					content(Element).parent := NIL;
					content(Element).root := NIL;
				END;
			END;
		END RemoveContent;

		PROCEDURE SetDocument(document: Document);
		VAR
			dtd: DocTypeDecl; elementDecl: ElementDecl;
			enum : Objects.Enumerator; c : Content; p: ANY; attribute: Attribute;
		BEGIN
			ASSERT(document # NIL);
			SELF.document := document;
			root := document.GetRoot();
			dtd := document.GetDocTypeDecl();
			IF dtd # NIL THEN
				elementDecl := dtd.GetElementDecl(name^);
				IF elementDecl # NIL THEN
					enum := elementDecl.GetAttributeDecls();
					WHILE enum.HasMoreElements() DO
						p := enum.GetNext();
						WITH p: AttributeDecl DO
							attribute := GetAttribute(p.name^);
							IF attribute # NIL THEN
								attribute.SetDocument(document, name);
							ELSE
								NEW(attribute);
								attribute.name := p.name;
								attribute.value := p.defaultValue;
								attribute.SetDocument(document, name);
								AddAttribute(attribute);
							END;
							IF p.type = Id THEN idAttribute := attribute END
						END
					END
				END
			END;
			c := GetFirst();
			WHILE (c # NIL) DO
				IF (c IS Element) THEN c(Element).SetDocument(document);
				ELSIF (c IS EntityRef) THEN c(EntityRef).SetDocument(document);
				END;
				c := GetNext(c);
			END;
		END SetDocument;

		PROCEDURE SetName*(CONST name: ARRAY OF CHAR);
		BEGIN
			SELF.name := NewString(name)
		END SetName;

		PROCEDURE SetNameAsString*(name : String);
		BEGIN
			ASSERT(name # NIL);
			SELF.name := name
		END SetNameAsString;

		PROCEDURE GetName*(): String;
		BEGIN
			ASSERT(name # NIL);
			RETURN name
		END GetName;

		PROCEDURE GetId*(): String;
		BEGIN
			IF idAttribute # NIL THEN RETURN idAttribute.value
			ELSE RETURN NIL
			END
		END GetId;

		PROCEDURE GetIdElement*(CONST name, id: ARRAY OF CHAR): Element;
		VAR contents: Objects.Enumerator; content: ANY; idString: String; retElement: Element;
		BEGIN
			retElement := NIL;
			IF SELF.name^ = name THEN
				idString := GetId();
				IF (idString # NIL) & (idString^ = id) THEN retElement := SELF END
			END;
			IF retElement = NIL THEN
				contents := GetContents();
				WHILE contents.HasMoreElements() & (retElement = NIL) DO
					content := contents.GetNext();
					IF content IS Element THEN
						retElement := content(Element).GetIdElement(name, id)
					ELSIF content IS ExternalEntityRef THEN
						retElement := content(ExternalEntityRef).GetIdElement(name, id)
					END
				END
			END;
			RETURN retElement
		END GetIdElement;

		PROCEDURE AddAttribute*(attribute : Attribute);
		VAR a : Attribute;
		BEGIN {EXCLUSIVE}
			ASSERT((attribute # NIL) & (attribute.next = NIL) & (attribute.name # NIL) & (attribute.name^ # ""));
			RemoveAttributeInternal(attribute.name^);
			IF (attributes = NIL) THEN
				attributes := attribute;
			ELSE
				a := attributes;
				WHILE (a.next # NIL) DO a := a.next (Attribute); END;
				a.next := attribute;
			END;
		END AddAttribute;

		PROCEDURE RemoveAttributeInternal(CONST name : ARRAY OF CHAR);
		VAR a : Attribute;
		BEGIN (* caller holds object lock *)
			IF (attributes # NIL) THEN
				IF (attributes.name^ = name) THEN
					IF (attributes.next = NIL) THEN attributes := NIL; ELSE attributes := attributes.next (Attribute); END;
				ELSE
					a := attributes;
					WHILE (a.next # NIL) & (a.next(Attribute).name^ # name) DO a := a.next (Attribute); END;
					IF (a.next # NIL) THEN
						a.next := a.next.next;
					END;
				END;
			END;
		END RemoveAttributeInternal;

		PROCEDURE RemoveAttribute*(CONST name: ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			RemoveAttributeInternal(name);
		END RemoveAttribute;

		PROCEDURE SetAttributeValue*(CONST name, value: ARRAY OF CHAR);
		VAR attribute: Attribute;
		BEGIN
			NEW(attribute); attribute.SetName(name); attribute.SetValue(value); AddAttribute(attribute)
		END SetAttributeValue;

		PROCEDURE GetAttribute*(CONST name: ARRAY OF CHAR): Attribute;
		VAR a : Attribute;
		BEGIN {EXCLUSIVE}
			a := attributes;
			WHILE (a # NIL) & (a.name^ # name) DO
				IF (a.next = NIL) THEN a := NIL; ELSE a := a.next (Attribute); END;
			END;
			RETURN a;
		END GetAttribute;

		PROCEDURE GetAttributeValue*(CONST name: ARRAY OF CHAR): String;
		VAR a : Attribute;
		BEGIN
			a := GetAttribute(name);
			IF (a # NIL) THEN
				RETURN a.GetValue();
			ELSE
				RETURN NIL;
			END;
		END GetAttributeValue;

		PROCEDURE GetAttributes*(): Objects.Enumerator;
		VAR a : Attribute; array : Objects.PTRArray; enumerator : Objects.ArrayEnumerator; i, nofAttributes : LONGINT;
		BEGIN {EXCLUSIVE}
			nofAttributes := 0;
			a := attributes;
			WHILE (a # NIL) DO
				INC(nofAttributes);
				IF (a.next # NIL) THEN a := a.next (Attribute); ELSE a := NIL; END;
			END;
			NEW(array, nofAttributes);
			a := attributes; i := 0;
			WHILE (a # NIL) DO
				array[i] := a; INC(i);
				IF (a.next # NIL) THEN a := a.next (Attribute); ELSE a := NIL; END;
			END;
			NEW(enumerator, array);
			RETURN enumerator;
		END GetAttributes;

		PROCEDURE HasAttribute*(CONST name : ARRAY OF CHAR) : BOOLEAN;
		BEGIN
			RETURN GetAttribute(name) # NIL;
		END HasAttribute;

		PROCEDURE GetRoot*(): Element;
		BEGIN
			RETURN root
		END GetRoot;

		PROCEDURE GetParent*(): Element;
		BEGIN
			RETURN parent
		END GetParent;

		PROCEDURE GetFirstChild*() : Element;
		VAR c : Content;
		BEGIN
			c := GetFirst();
			WHILE (c # NIL) & ~(c IS Element) DO
				c := GetNext(c);
			END;
			IF (c # NIL) THEN
				RETURN c(Element);
			ELSE
				RETURN NIL;
			END;
		END GetFirstChild;

		PROCEDURE GetNextSibling*(): Element;
		VAR c : Content;
		BEGIN
			c := next;
			WHILE (c # NIL) & ~(c IS Element) DO c := c.next; END;
			IF (c # NIL) THEN
				RETURN c(Element);
			ELSE
				RETURN NIL;
			END;
		END GetNextSibling;

		PROCEDURE GetPreviousSibling*() : Element;
		VAR c : Content;
		BEGIN
			c := previous;
			WHILE	(c # NIL) & ~(c IS Element) DO c := c.previous; END;
			IF (c # NIL) THEN
				RETURN c(Element);
			ELSE
				RETURN NIL;
			END;
		END GetPreviousSibling;

		PROCEDURE Traverse*(traverseProc: TraverseProc; data: ANY);
		VAR c : Content;
		BEGIN
			ASSERT(traverseProc # NIL);
			traverseProc(SELF, data);
			c := GetFirst();
			WHILE (c # NIL) DO
				IF (c IS Element) THEN c(Element).Traverse(traverseProc, data);
				ELSE traverseProc(c, data);
				END;
				c := GetNext(c);
			END;
		END Traverse;

		PROCEDURE WriteAttributes*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR a : Attribute;
		BEGIN {EXCLUSIVE}
			a := attributes;
			WHILE (a # NIL) DO
				a.Write(w, context, level + 1);
				IF (a.next # NIL) THEN
					a := a.next (Attribute);
				ELSE
					a := NIL;
				END;
			END;
		END WriteAttributes;

		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : LONGINT);
		VAR c : Content;
		BEGIN
			w.Char('<'); w.String(name^);
			WriteAttributes(w, context, level);
			c := GetFirst();
			IF (c = NIL) THEN w.String("/>")
			ELSE
				w.Char('>');
				IF ~(c IS ArrayChars)  THEN NewLine(w, level + 1) END;
				c.Write(w, context,  level + 1);
				WHILE (GetNext(c) # NIL) DO c := GetNext(c); NewLine(w, level + 1); c.Write(w, context, level + 1); END;
				IF ~(c IS ArrayChars)  THEN NewLine(w, level); END;
				w.String("</"); w.String(name^); w.Char('>');
			END;
		END Write;

	END Element;

TYPE

	GeneratorProcedure* = PROCEDURE(): Element;

	ElementEntry* = OBJECT
	VAR
		name- : ARRAY 32 OF CHAR;
		generator-: GeneratorProcedure;
		generatorModule-, generatorProcedure- : Modules.Name;

		PROCEDURE &Init*;
		BEGIN
			generator := NIL;
			COPY("", generatorModule); COPY("", generatorProcedure);
		END Init;

	END ElementEntry;

	ElementArray* = POINTER TO ARRAY OF ElementEntry;

TYPE

	ElementRegistry* = OBJECT
	VAR
		generators: Objects.Dictionary;
		timestamp : LONGINT;

		PROCEDURE  &Init*;
		VAR arrDict: Objects.ArrayDict;
		BEGIN
			NEW(arrDict); generators := arrDict;
			timestamp := 0;
		END Init;

		PROCEDURE RegisterElement*(CONST name: ARRAY OF CHAR; generator: GeneratorProcedure);
		VAR e: ElementEntry; p: ANY;
		BEGIN
			ASSERT(generator # NIL);
			p := generators.Get(name);
			IF p = NIL THEN
				NEW(e); COPY(name, e.name);  e.generator := generator; generators.Add(name, e)
			ELSE (* redefinition *)
				p(ElementEntry).generator := generator
			END;
			INC(timestamp);
		END RegisterElement;

		PROCEDURE RegisterElementByName*(CONST name: ARRAY OF CHAR; CONST generatorModule, generatorProcedure: Modules.Name);
		VAR e: ElementEntry; p: ANY;
		BEGIN
			ASSERT((generatorModule # "") & (generatorProcedure # ""));
			p := generators.Get(name);
			IF p = NIL THEN
				NEW(e);
				COPY(name, e.name);
				e.generatorModule := generatorModule;
				e.generatorProcedure := generatorProcedure;
				generators.Add(name, e)
			ELSE (* redefinition *)
				p(ElementEntry).generatorModule := generatorModule;
				p(ElementEntry).generatorProcedure := generatorProcedure;
			END;
			INC(timestamp);
		END RegisterElementByName;

		PROCEDURE UnregisterElement*(CONST name: ARRAY OF CHAR);
		BEGIN
			generators.Remove(name);
			INC(timestamp);
		END UnregisterElement;

		PROCEDURE InstantiateElement*(CONST name: ARRAY OF CHAR): Element;
		VAR element : Element; entry : ElementEntry; p: ANY; generator : GeneratorProcedure;
		BEGIN
			element := NIL;
			p := generators.Get(name);
			IF (p # NIL) THEN entry := p (ElementEntry); END;
			IF (entry # NIL) THEN
				IF entry.generator # NIL THEN
					element := entry.generator();
				ELSE
					GETPROCEDURE(entry.generatorModule, entry.generatorProcedure, generator);
					IF (generator # NIL) THEN
						element := generator();
					ELSE
						KernelLog.String("Warning: XML.ElementRegistry.InstantiateElement: Factory procedure ");
						KernelLog.String(entry.generatorModule); KernelLog.String("."); KernelLog.String(entry.generatorProcedure);
						KernelLog.String(" not found."); KernelLog.Ln;
					END
				END
			END;
			RETURN element;
		END InstantiateElement;

		(** fof, late time instantiation to be able to react on generator properties *)
		PROCEDURE InstantiateLate*(e: Element): Element;
		BEGIN
			RETURN e (* stub *)
		END InstantiateLate;

		PROCEDURE GetTimestamp*() : LONGINT;
		BEGIN
			RETURN timestamp;
		END GetTimestamp;

		PROCEDURE GetElements*() : ElementArray;
		VAR enumerator : Objects.Enumerator; nofElements, i : LONGINT; ptr : ANY; ea : ElementArray;
		BEGIN
			enumerator := generators.GetEnumerator();
			nofElements := 0;
			WHILE enumerator.HasMoreElements() DO INC(nofElements); ptr := enumerator.GetNext(); END;
			IF (nofElements = 0) THEN
				ea := NIL;
			ELSE
				NEW(ea, nofElements);
				enumerator.Reset;
				i := 0;
				WHILE (i < nofElements) & enumerator.HasMoreElements() DO
					ptr := enumerator.GetNext();
					IF (ptr # NIL) & (ptr IS ElementEntry) THEN
						ea[i] := ptr (ElementEntry);
					ELSE
						ea[i] := NIL;
					END;
					INC(i);
				END;
			END;
			RETURN ea;
		END GetElements;

	END ElementRegistry;

VAR
	StrNoName : Strings.String;

(**	Write an 0X-terminated UTF8 string to a stream (excl. 0X). XML special characters are escaped.
	Also works for ASCII strings. *)
PROCEDURE UTF8ToStream*(CONST string : ARRAY OF CHAR; w : Streams.Writer; VAR res : LONGINT);
VAR codeLength, stringLength, i : LONGINT; ch : CHAR;
BEGIN
	ASSERT(w # NIL);
	res := Ok;
	stringLength := LEN(string);
	i := 0;
	WHILE (res = Ok) & (i < stringLength) & (string[i] # 0X) DO
		ch := string[i];
		codeLength := ORD(UTF8Strings.CodeLength[ORD(ch)]);
		IF (codeLength = 1) THEN
			CASE ch OF
				|'&': w.String("&amp;");
				|'<': w.String("&lt;");
				|'>': w.String("&gt;");
				|'"': w.String("&quot;");
				|"'": w.String("&apos;");
			ELSE
				w.Char(ch);
			END;
		ELSIF (codeLength > 0) & (i + codeLength <= stringLength) THEN
			w.Bytes(string, i, codeLength);
		ELSE
			res := InvalidString;
		END;
		INC(i, codeLength);
	END;
	IF (i >= stringLength) OR (string[i] # 0X) THEN
		res := InvalidString;
	END;
END UTF8ToStream;

(**	Read an UTF8 string from a stream and undo escaping of XML special characters. If the string array is to small, the string
	will be truncated and an error will be reported. <string> is always a valid 0X-terminated string.
	Also works for ASCII strings. *)
PROCEDURE UTF8FromStream*(VAR string : ARRAY OF CHAR; r : Streams.Reader; VAR res : LONGINT);
VAR ch : CHAR;  escapeBuffer : ARRAY 8 OF CHAR; escaping : BOOLEAN; escapeIdx, codeLength, stringLength, i, len, actLen : LONGINT;

	PROCEDURE FlushEscapeBuffer;
	VAR j : LONGINT;
	BEGIN
		IF escaping THEN
			j := 0;
			WHILE (i < stringLength - 1) & (escapeBuffer[j] # 0X) DO
				string[i] := escapeBuffer[j];
				INC(i); INC(j);
			END;
			IF (escapeBuffer[j] # 0X) THEN res := BufferError; END;
			escaping := FALSE;
		END;
	END FlushEscapeBuffer;

	PROCEDURE CheckEscapeBuffer;
	BEGIN
		ASSERT(i < stringLength);
		IF (escapeIdx = 4) THEN
			IF (escapeBuffer = "&lt;") THEN string[i] := "<"; INC(i); escaping := FALSE;
			ELSIF (escapeBuffer = "&gt;") THEN string[i] := ">"; INC(i); escaping := FALSE;
			END;
		ELSIF (escapeIdx = 5) & (escapeBuffer = "&amp;") THEN
			string[i] := "&"; INC(i); escaping := FALSE;
		ELSIF (escapeIdx = 6) THEN
			IF (escapeBuffer = "&quot;") THEN string[i] := '"'; INC(i); escaping := FALSE;
			ELSIF (escapeBuffer = "&apos;") THEN string[i] := "'"; INC(i); escaping := FALSE;
			END;
		ELSIF (escapeIdx > 6) THEN
			FlushEscapeBuffer;
		END;
	END CheckEscapeBuffer;

BEGIN
	ASSERT((r # NIL) & (LEN(string) >= 1));
	res := Ok;
	escaping := FALSE;
	stringLength := LEN(string);
	i := 0;
	ch := r.Peek();
	WHILE (res = Ok) & (ch # 0X) & (i < stringLength - 1) DO
		codeLength := ORD(UTF8Strings.CodeLength[ORD(ch)]);
		IF (codeLength = 1) THEN
			ch := r.Get();
			IF (ch = "&") THEN
				FlushEscapeBuffer;
				escaping := TRUE;
				escapeBuffer[0] := ch;
				escapeBuffer[1] := 0X;
				escapeIdx := 1;
			ELSIF escaping THEN
				escapeBuffer[escapeIdx] := ch;
				escapeBuffer[escapeIdx + 1] := 0X;
				INC(escapeIdx);
				CheckEscapeBuffer;
			ELSE
				string[i] := ch;
				INC(i);
			END;
		ELSIF (codeLength > 0) THEN
			FlushEscapeBuffer;
			len := Strings.Min(codeLength, stringLength - 1 - i);
			IF (len > 0) THEN
				r.Bytes(string, i, len, actLen);
				IF (actLen # len) THEN
					res := InvalidString;
				ELSIF (len # codeLength) THEN
					res := BufferError;
				END;
				INC(i, actLen);
			ELSE
				res := BufferError;
			END;
		ELSE
			res := InvalidString;
		END;
		ch := r.Peek();
	END;
	string[i] := 0X;
END UTF8FromStream;

PROCEDURE NewLine(w : Streams.Writer; level : LONGINT);
BEGIN
	w.Ln; WHILE level > 0 DO w.Char(Tab); DEC(level) END
END NewLine;

PROCEDURE NewString(CONST value: ARRAY OF CHAR): String;
VAR s: String;
BEGIN
	NEW(s, DynamicStrings.StringLength(value) + 1);
	COPY(value, s^);
	RETURN s
END NewString;

BEGIN
	StrNoName := Strings.NewString("");
END XML.